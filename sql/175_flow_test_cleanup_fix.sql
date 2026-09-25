-- ============================================================
-- LoungeLink · 175_flow_test_cleanup_fix.sql
-- E'NİN SON KIRMIZISI: TESTİN KENDİSİ ÇÖKÜYORDU
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yalnız test fonksiyonu).
--
-- ------------------------------------------------------------
-- 🔴 NE OLDU
-- ------------------------------------------------------------
-- 174 sonrası B yeşile döndü ama E hâlâ 4/5 veriyordu. Bende 5/5
-- çıkıyordu çünkü sandbox'ta ne DOLU ne PASİF ilan vardı; o iki
-- senaryo "—" ile atlanıyordu. Gökberk'in verisinde ikisi de var,
-- yani testin o dalları CANLIDA İLK KEZ çalıştı ve iki kusur çıktı:
--
-- 1. TEMİZLİK YABANCI ANAHTARA TAKILIYOR
--    Bir istek kabul edilince `chat_channels` o isteğe bağlanıyor.
--    Test sonunda `delete from requests` yapınca FK ihlali:
--      "violates foreign key constraint chat_channels_request_id_fkey"
--    Bu, fonksiyonun tamamını düşürüyor — sonraki senaryolar hiç
--    koşmuyor. Yani "1 başarısız" aslında "test çöktü" demekti.
--
-- 2. "DOLU İLAN" KURULUMU GÜVENİLMEZ
--    Test, filled >= slots olan hazır bir ilan arıyordu. Ama `filled`
--    TÜRETİLMİŞ bir değer: requests tablosuna her dokunuşta trigger
--    onu accepted+completed SAYARAK yeniden hesaplıyor. Elle
--    doldurulmuş bir sayaç, testin ilk insert'inde sıfırlanıyor ve
--    ilan aslında dolu olmuyor → kabul geçiyor → yanlış sonuç.
--    Doğrusu: doluluğu GERÇEKTEN kurmak (slot kadar kabul yaratmak).
--
-- Ders (üçüncü kez): test verisini kurarken ürünün kendi
-- mekanizmasını kullan. Yan yoldan kurulan durum, ürün onu ilk
-- fırsatta düzeltir ve test yanlış şeyi ölçer.
-- ============================================================

-- Testin ürettiği kayıtları BAĞIMLILIK SIRASIYLA siler. Doğrudan
-- `delete from requests` yabancı anahtara takılıp testi düşürüyordu.
create or replace function public.flow_test_cleanup(p_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_ids is null or array_length(p_ids, 1) is null then return; end if;
  delete from messages m using chat_channels c
   where m.channel_id = c.id and c.request_id = any(p_ids);
  delete from chat_channels where request_id = any(p_ids);
  delete from ratings r using sessions s
   where r.session_id = s.id and s.request_id = any(p_ids);
  delete from sessions where request_id = any(p_ids);
  delete from requests where id = any(p_ids);
exception when others then
  -- Temizlik testi ASLA düşürmemeli: eksik silinen kayıt bir sonraki
  -- koşuda görülür, ama çöken bir test hiçbir şey ölçmez.
  null;
end $$;

drop function if exists public.flow_gate_test();
create or replace function public.flow_gate_test()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql security definer set search_path = public as $$
declare v_av uuid; v_host uuid; v_guest uuid; v_g2 uuid; v_r uuid; v_err text;
        v_ap text; v_date date; v_t1 time; v_t2 time; v_visit uuid;
        v_slots int; v_made uuid[] := '{}'; v_i int; v_base int;
begin
  select id into v_guest from users where email like 'kmisafir1%' limit 1;
  select id into v_g2 from users where email like 'kmisafir2%' limit 1;
  if v_guest is null then
    senaryo := 'Akış testleri'; beklenen := 'seed misafiri';
    gercek := 'kmisafir1 yok'; sonuc := '—'; return next; return;
  end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);

  -- ---- 1) MİSAFİR KABUL ETMEYEN İLANA İSTEK ----
  senaryo := 'Misafir kabul etmeyen ilana istek gönderilemez';
  beklenen := 'guests_not_allowed';
  select a.id, a.airport_code, a.avail_date, a.time_from, a.time_to
    into v_av, v_ap, v_date, v_t1, v_t2
    from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'not_allowed'
   limit 1;
  if v_av is null then gercek := 'senaryo verisi yok'; sonuc := '—';
  else
    insert into visits (user_id, airport_code, visit_date, time_from, time_to)
    values (v_guest, v_ap, v_date, v_t1, v_t2) returning id into v_visit;
    begin
      perform public.create_request(v_av, 'lounge', 'test', null);
      gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%guests_not_allowed%' then '✓' else '✗ BAŞKA SEBEPLE' end;
    end;
    perform public.flow_test_cleanup(array(select id from requests
       where avail_id = v_av and guest_id = v_guest));
    delete from visits where id = v_visit;
  end if;
  return next;

  -- ---- 2) DOLU İLANA KABUL ----
  -- Doluluk GERÇEKTEN kurulur: slot sayısı kadar kabul edilmiş istek
  -- yaratılır, sayacı trigger kendisi hesaplar.
  senaryo := 'Kapasitesi dolu ilana kabul verilemez';
  beklenen := 'fully_booked';
  -- 🔴 TEK SLOTLU ilan seçilir: iki slotlu bir ilanda hem doluluğu
  -- kurmak hem de fazladan bir bekleyen istek eklemek için ÜÇ ayrı
  -- misafir gerekir; elimizde iki seed misafiri var ve aynı kişi
  -- aynı ilana iki kez istek atamaz (uq indeks). Tek slot, tek kabul,
  -- tek bekleyen: senaryo aynı, kurulum güvenli.
  select a.id, a.host_id, a.slots into v_av, v_host, v_slots
    from availabilities a
   where a.active and a.slots = 1
     and a.host_id is distinct from v_guest and a.host_id is distinct from v_g2
     and not exists (select 1 from requests r
                      where r.avail_id = a.id and r.guest_id in (v_guest, v_g2))
   limit 1;
  if v_av is null then gercek := 'uygun ilan yok'; sonuc := '—';
  else
    -- Doluluk gerçekten kurulur: tek slot, tek kabul.
    insert into requests (avail_id, guest_id, host_id, status)
    values (v_av, v_guest, v_host, 'accepted') returning id into v_r;
    v_made := v_made || v_r;

    -- Sonra BAŞKA bir misafir sıraya girer; kabul edilememeli.
    if v_g2 is null then
      gercek := 'ikinci seed misafiri yok'; sonuc := '—';
      perform public.flow_test_cleanup(v_made); v_made := '{}';
      return next;
    end if;
    insert into requests (avail_id, guest_id, host_id, status)
    values (v_av, v_g2, v_host, 'pending') returning id into v_r;
    v_made := v_made || v_r;

    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
      perform public.respond_request(v_r, 'accept');
      gercek := 'KABUL EDİLDİ (filled=' ||
                (select coalesce(filled,0)::text from availabilities where id = v_av) || ')';
      sonuc := '✗ KAPASİTE AŞILDI';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%fully_booked%' then '✓' else '✗ BAŞKA SEBEPLE' end;
    end;
    perform public.flow_test_cleanup(v_made);
    v_made := '{}';
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
  end if;
  return next;

  -- ---- 3) İPTAL SONRASI SLOT GERİ AÇILIR ----
  senaryo := 'Kabul iptal edilince slot geri açılır';
  beklenen := 'filled bir azalır';
  select a.id, a.host_id into v_av, v_host from availabilities a
   where a.active and a.slots - coalesce(a.filled,0) >= 1 limit 1;
  if v_av is null then gercek := 'boş ilan yok'; sonuc := '—';
  else
    select coalesce(filled,0) into v_base from availabilities where id = v_av;
    insert into requests (avail_id, guest_id, host_id, status)
         values (v_av, v_guest, v_host, 'accepted') returning id into v_r;
    update requests set status = 'cancelled' where id = v_r;
    gercek := 'filled = ' || (select coalesce(filled,0)::text from availabilities where id = v_av);
    sonuc := case when (select coalesce(filled,0) from availabilities where id = v_av) = v_base
                  then '✓' else '✗ SLOT GERİ AÇILMADI' end;
    perform public.flow_test_cleanup(array[v_r]);
  end if;
  return next;

  -- ---- 4) KENDİ İLANINA İSTEK ----
  senaryo := 'Host kendi ilanına istek gönderemez';
  beklenen := 'engellenir';
  select a.id, a.host_id into v_av, v_host from availabilities a where a.active limit 1;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
    perform public.create_request(v_av, 'lounge', 'test', null);
    gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
    perform public.flow_test_cleanup(array(select id from requests
       where avail_id = v_av and guest_id = v_host));
  exception when others then
    gercek := left(SQLERRM, 40); sonuc := '✓';
  end;
  return next;

  -- ---- 5) PASİF İLANA İSTEK ----
  senaryo := 'Kapatılmış ilana istek gönderilemez';
  beklenen := 'engellenir';
  select a.id into v_av from availabilities a where not a.active limit 1;
  if v_av is null then gercek := 'pasif ilan yok'; sonuc := '—';
  else
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
      perform public.create_request(v_av, 'lounge', 'test', null);
      gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
      perform public.flow_test_cleanup(array(select id from requests
         where avail_id = v_av and guest_id = v_guest));
    exception when others then
      gercek := left(SQLERRM, 40); sonuc := '✓';
    end;
  end if;
  return next;

  perform set_config('request.jwt.claims', '{}', true);
end $$;
grant execute on function public.flow_gate_test() to authenticated;

do $$
declare n int;
begin
  select count(*) into n from public.flow_gate_test() where sonuc like '✗%';
  raise notice '175: akış kapıları — % başarısız', n;
end $$;

select '175 OK - akis testi temizligi ve doluluk kurulumu duzeltildi' as sonuc;
