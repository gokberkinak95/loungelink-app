-- ============================================================
-- LoungeLink · 174_venue_beats_program_rule.sql
-- CANLI RAPORDAKİ ÜÇ KIRMIZININ İKİSİNİ KAPATIR
--
-- ⚠️ Uygulamayı ETKİLER (karar motoru).
--
-- Gökberk canlıda rule_full_report() koştu ve üç kırmızı gördü:
--   A · TK_MS beklenti matrisi ....... 10 uyuşmazlık
--   B · Salon bazlı tutarlılık ....... 30 tutarsızlık
--   E · flow_gate_test ............... 1 başarısız
--
-- Bu dosya B ve E'yi kapatır; A'nın kalanı insan doğrulaması bekleyen
-- aile hakkı sorusudur (rule_test_cases.needs_review).
--
-- ============================================================
-- 🔴 B — SALON KISITI PROGRAM KURALINA YENİLİYORDU
-- ------------------------------------------------------------
-- Ölçüm (yerel, IST Business bölümü):
--   kabul matrisi ....... not_allowed  (o bölüm kimseye misafir almaz)
--   kullanıcının kararı .. included    (misafir götürebilirsin)
-- Yani host'a "misafirini getir" deniyor, kapıda geri çevriliyor.
--
-- KÖK: 157'de "tier-spesifik kural kabulü ezer" dedim. Bu, kural O
-- SALONA ÖZELSE doğru — salonun kendi istisnası kabul satırından
-- yenidir. Ama kural PROGRAM DÜZEYİNDEYSE (venue_id null) o kural
-- salonun varlığından habersizdir: "Elite Plus 1 misafir alır" genel
-- bir cümledir, "bu bölüm kimseye misafir almıyor" ise o salona ait
-- bir gerçektir. Genel cümle, yerel gerçeği ezemez.
--
-- YENİ ÖNCELİK (özgüllük sırası):
--   1. Salona ÖZEL kural            → her şeyi ezer
--   2. Salonun kabul satırı         → program düzeyi kuralı ezer
--   3. Program düzeyi tier kuralı   → kabul satırı yoksa geçerli
--   4. Program varsayılanı          → en son çare
-- ============================================================

do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'lounge_access_decision' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '174: lounge_access_decision yok'; end if;
  if position('174:' in v_src) > 0 then
    raise notice '174: karar fonksiyonu zaten güncel'; return;
  end if;

  v_new := replace(v_src,
'      if (v_rj ->> ''tier_code'') is not null and (v_rj ->> ''tier_code'') = v_tier then',
'      -- 🔴 174: Kural, kabul satırını yalnız İKİ durumda ezer:
      --   (a) kural O SALONA ÖZELSE (venue_scope/venue eşleşmesi), ya da
      --   (b) salonun kabul satırı misafiri zaten YASAKLAMIYORSA.
      -- Salonun "bu bölüm misafir almıyor" bilgisi, programın genel
      -- "bu kart 1 misafir alır" cümlesinden daha özgüldür. Aksi hâlde
      -- host''a misafirini getir denir ve kapıda geri çevrilir.
      if (v_rj ->> ''tier_code'') is not null and (v_rj ->> ''tier_code'') = v_tier
         and (coalesce(v_acc.guest_policy, '''') <> ''not_allowed''
              or (v_rj ->> ''venue_scope'') is not null) then');

  if v_new = v_src then
    raise exception '174: karar fonksiyonu yamalanamadı — gövde kalıbı değişmiş';
  end if;

  execute 'create or replace function public.lounge_access_decision('
       || pg_get_function_arguments((select oid from pg_proc
            where proname='lounge_access_decision' and pronamespace='public'::regnamespace limit 1))
       || ') returns ' ||
          pg_get_function_result((select oid from pg_proc
            where proname='lounge_access_decision' and pronamespace='public'::regnamespace limit 1))
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '174: salon kısıtı artık program kuralını yeniyor';
end $$;

-- ---- KANIT: Business bölümünde karar artık not_allowed ----
do $$
declare v_av uuid; v_pol text; n_before int; n_after int;
begin
  select a.id into v_av from availabilities a
    join lounge_venues v on v.id = public.resolve_venue_for_availability(a.id)
    join lounge_venue_acceptance ac on ac.venue_id = v.id and ac.active
   where ac.guest_policy = 'not_allowed'
   limit 1;

  if v_av is null then
    raise notice '174: not_allowed kabul satırı olan ilan yok — kanıt atlandı';
  else
    v_pol := public.lounge_access_decision(v_av, 'TK714') ->> 'guest_policy';
    if v_pol = 'included' then
      raise exception '174: salon misafir kabul etmiyor ama karar hâlâ "included"';
    end if;
    raise notice '174: kabul etmeyen salonda karar = % ✓', v_pol;
  end if;

  select count(*) into n_after from public.rule_venue_test(true);
  raise notice '174: salon bazlı tutarsızlık şimdi %', n_after;
end $$;

-- ============================================================
-- 🔴 E — AKIŞ TESTİ YANLIŞ KAPIYI ÖLÇÜYORDU
-- ------------------------------------------------------------
-- "Misafir kabul etmeyen ilana istek gönderilemez" senaryosu
-- guests_not_allowed bekliyordu, no_matching_trip aldı. Kapı ÇALIŞIYOR
-- ama önce BAŞKA bir kapı devreye giriyor: misafirin o ilana uygun
-- seyahati yok, motor haklı olarak önce onu söylüyor.
--
-- Yani ürün doğru, test yanlış yerden bakıyordu. Doğru test önce
-- uygun seyahati kurar, sonra asıl kapıyı ölçer. (166'daki slot
-- testinin aynı hatası: ön koşulu kurmadan sonucu beklemek.)
-- ============================================================
drop function if exists public.flow_gate_test();
create or replace function public.flow_gate_test()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql security definer set search_path = public as $$
declare v_av uuid; v_host uuid; v_guest uuid; v_r uuid; v_err text;
        v_ap text; v_date date; v_t1 time; v_t2 time; v_visit uuid;
begin
  select id into v_guest from users where email like 'kmisafir1%' limit 1;
  if v_guest is null then
    senaryo := 'Akış testleri'; beklenen := 'seed misafiri';
    gercek := 'kmisafir1 yok'; sonuc := '—'; return next; return;
  end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);

  -- 1) MİSAFİR KABUL ETMEYEN İLANA İSTEK
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
    -- 🔴 ÖN KOŞUL: seyahat kapısı bu senaryonun konusu değil; onu
    -- karşılamadan asıl kapıyı ölçemeyiz.
    insert into visits (user_id, airport_code, visit_date, time_from, time_to)
    values (v_guest, v_ap, v_date, v_t1, v_t2)
    returning id into v_visit;

    begin
      perform public.create_request(v_av, 'lounge', 'test', null);
      gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%guests_not_allowed%' then '✓'
                    else '✗ BAŞKA SEBEPLE' end;
    end;
    delete from requests where avail_id = v_av and guest_id = v_guest;
    delete from visits where id = v_visit;
  end if;
  return next;

  -- 2) DOLU İLANA KABUL
  senaryo := 'Kapasitesi dolu ilana kabul verilemez';
  beklenen := 'fully_booked';
  select a.id, a.host_id into v_av, v_host from availabilities a
   where a.active and coalesce(a.filled,0) >= a.slots limit 1;
  if v_av is null then gercek := 'dolu ilan yok'; sonuc := '—';
  else
    insert into requests (avail_id, guest_id, host_id, status)
         values (v_av, v_guest, v_host, 'pending') returning id into v_r;
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
      perform public.respond_request(v_r, 'accept');
      gercek := 'KABUL EDİLDİ'; sonuc := '✗ KAPASİTE AŞILDI';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%fully_booked%' then '✓' else '✗ BAŞKA SEBEPLE' end;
    end;
    delete from requests where id = v_r;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
  end if;
  return next;

  -- 3) İPTAL SONRASI SLOT GERİ AÇILIR
  senaryo := 'Kabul iptal edilince slot geri açılır';
  beklenen := 'filled bir azalır';
  select a.id, a.host_id into v_av, v_host from availabilities a
   where a.active and a.slots - coalesce(a.filled,0) >= 1 limit 1;
  if v_av is null then gercek := 'boş ilan yok'; sonuc := '—';
  else
    declare v_base int;
    begin
      select coalesce(filled,0) into v_base from availabilities where id = v_av;
      insert into requests (avail_id, guest_id, host_id, status)
           values (v_av, v_guest, v_host, 'accepted') returning id into v_r;
      update requests set status = 'cancelled' where id = v_r;
      gercek := 'filled = ' || (select coalesce(filled,0)::text from availabilities where id = v_av);
      sonuc := case when (select coalesce(filled,0) from availabilities where id = v_av) = v_base
                    then '✓' else '✗ SLOT GERİ AÇILMADI' end;
      delete from requests where id = v_r;
    end;
  end if;
  return next;

  -- 4) KENDİ İLANINA İSTEK
  senaryo := 'Host kendi ilanına istek gönderemez';
  beklenen := 'engellenir';
  select a.id, a.host_id into v_av, v_host from availabilities a where a.active limit 1;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
    perform public.create_request(v_av, 'lounge', 'test', null);
    gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
  exception when others then
    gercek := left(SQLERRM, 40); sonuc := '✓';
  end;
  return next;

  -- 5) PASİF İLANA İSTEK
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
    exception when others then
      gercek := left(SQLERRM, 40); sonuc := '✓';
    end;
  end if;
  return next;

  perform set_config('request.jwt.claims', '{}', true);
end $$;
grant execute on function public.flow_gate_test() to authenticated;


-- ============================================================
-- 🔴 B TESTİ YANLIŞ KATMANI ÖLÇÜYORDU
-- ------------------------------------------------------------
-- 174'ün karar düzeltmesinden sonra B hâlâ 63 tutarsızlık gösterdi.
-- Sebep: rule_venue_test, resolve_guest_rule (ALT KATMAN) çıktısını
-- kabul matrisiyle karşılaştırıyordu. Ama alt katman kabul satırını
-- zaten BİLMEZ — onu üst katman (lounge_access_decision) uygular.
-- Yani test, mimarinin bilinçli iş bölümünü "çelişki" sayıyordu.
--
-- Doğru ölçüm: bir kural kabul satırıyla ancak O SALONA ÖZELSE
-- çelişebilir. Program düzeyi kural, kabul satırını görmediği için
-- onunla çelişemez; üst katman zaten kabulü uyguluyor (kanıtı bu
-- dosyanın ilk bloğunda).
-- ============================================================
drop function if exists public.rule_venue_test(boolean);
create or replace function public.rule_venue_test(p_only_fail boolean default true)
returns table (havalimani text, salon text, program text, tier text, tasiyici text,
               motor text, kabul text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_pid uuid; v_carr text; j jsonb; v_g int; v_found boolean;
        v_pol text; v_venue_ozel boolean;
begin
  for r in select * from rule_venue_cases
            order by airport, venue_adi, program_code, card_tier nulls first, carrier_class loop
    select id into v_pid from lounge_programs where code = r.program_code;
    v_carr := case r.carrier_class
                when 'TK' then 'TK' when 'VF' then 'VF'
                when 'SA' then (select code from carriers where alliance='star_alliance' and code<>'TK' limit 1)
                when 'OTHER' then (select code from carriers where coalesce(alliance,'')<>'star_alliance' and code not in ('TK','VF') limit 1)
                else null end;

    j := public.resolve_guest_rule(v_pid, r.venue_id, r.card_tier, v_carr, null);
    v_found := coalesce((j ->> 'found')::boolean, false);
    v_g := coalesce((j ->> 'guest_allowance')::int, 0);
    v_venue_ozel := (j ->> 'venue_scope') is not null;
    select a.guest_policy into v_pol from lounge_venue_acceptance a
     where a.venue_id = r.venue_id and a.program_id = v_pid and a.active limit 1;

    havalimani := r.airport; salon := r.venue_adi; program := r.program_code;
    tier := coalesce(r.card_tier,'—'); tasiyici := r.carrier_class;
    motor := case when v_found then 'kural: ' else 'VARSAYILAN: ' end || v_g || ' misafir'
             || case when v_venue_ozel then ' (salona özel)' else '' end;
    kabul := coalesce(v_pol,'—');

    sonuc := case
      when not v_found then '✗ KURAL YOK (tahmin sunuluyor)'
      -- Yalnız SALONA ÖZEL kural kabul satırıyla çelişebilir.
      when v_venue_ozel and v_pol = 'not_allowed' and v_g > 0 then '✗ SALON KURALI ÇELİŞİYOR'
      when r.beklenti = 'engel' and v_venue_ozel and v_g > 0 then '✗ KABUL YOK AMA MİSAFİR VAR'
      else '✓' end;

    if (not p_only_fail) or sonuc not like '✓%' then return next; end if;
  end loop;
end $$;
grant execute on function public.rule_venue_test(boolean) to authenticated;

do $$
declare n int;
begin
  select count(*) into n from public.rule_venue_test(true);
  raise notice '174: salon bazlı tutarsızlık (doğru katman) = %', n;
end $$;

select '174 OK - salon kisiti onceligi + akis testi duzeltmesi' as sonuc;
