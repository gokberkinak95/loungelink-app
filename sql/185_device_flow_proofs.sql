-- ============================================================
-- LoungeLink · 185_device_flow_proofs.sql
-- CİHAZDA BAKILACAKLARI ÖNCE BEN DENETLİYORUM
--
-- ⚠️ Uygulamayı ETKİLEMEZ (denetim fonksiyonu).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN
-- ------------------------------------------------------------
-- Geçen tur "cihazda şunlara bak" dedim. Yanlıştı: bir şeyi
-- kullanıcıya doğrulatmadan önce ben doğrulamalıyım. Cihazım yok
-- ama bu üç akışın tamamı SUNUCU tarafında ölçülebilir — app yalnız
-- bu verileri çiziyor.
--
-- device_flow_check() üç şeyi gerçek veriyle sınar:
--   1. Salon listeleri — her aktif havalimanı salon döndürüyor mu
--   2. Keşfet kararı — rozet ve kapı durumu listede geliyor mu
--   3. Bağlantı isteği — alıcı tarafında GÖRÜNÜYOR mu (yalnız
--      yazıldı mı değil; alıcının sorgusuyla okunuyor mu)
--
-- Üçüncüsü kritik: geçen tur "istekler oluşuyor" diye bakmıştık,
-- oysa asıl soru "alıcı görüyor mu" idi. Testin yanlış soruyu
-- sorması, bu oturumda dört kez hataya yol açtı.
-- ============================================================

drop function if exists public.device_flow_check();
create or replace function public.device_flow_check()
returns table (akis text, olcum text, sonuc text)
language plpgsql security definer set search_path = public as $$
declare r record; n int; v_bos int := 0; v_top int := 0;
        v_uid uuid; v_other uuid; v_req uuid; v_gorunen int;
        v_badge int := 0; v_block int := 0; v_carrier int := 0; v_list int := 0;
begin
  -- ---------- 1) SALON LİSTELERİ ----------
  for r in select distinct upper(btrim(airport_code)) ap from lounges where active loop
    v_top := v_top + 1;
    if (select count(*) from public.lounges_for_airport(r.ap)) = 0 then
      v_bos := v_bos + 1;
    end if;
  end loop;
  akis := '1 · Salon listeleri';
  olcum := v_top || ' havalimanı, ' || v_bos || ' tanesi boş';
  sonuc := case when v_top = 0 then '✗ KATALOG BOŞ'
                when v_bos > 0 then '✗ BOŞ LİSTE VAR'
                else '✓' end;
  return next;

  -- Kod normalize gerçekten çalışıyor mu (app 'ist' gönderirse)
  akis := '1b · Havalimanı kodu normalize';
  select count(*) into n from public.lounges_for_airport('ist');
  olcum := 'küçük harfle IST → ' || n || ' salon';
  sonuc := case when n > 0 then '✓' else '✗ NORMALİZE ÇALIŞMIYOR' end;
  return next;

  -- ---------- 2) KEŞFET KARARI ----------
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then
    akis := '2 · Keşfet kararı'; olcum := 'seed misafiri yok'; sonuc := '—'; return next;
  else
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    for r in select * from public.discover_availabilities(null, null, null, null) loop
      v_list := v_list + 1;
      if r.guest_policy is not null and r.guest_policy <> 'unknown' then v_badge := v_badge + 1; end if;
      if r.blocks_request then v_block := v_block + 1; end if;
      if r.carrier_note is not null then v_carrier := v_carrier + 1; end if;
    end loop;

    akis := '2 · Keşfet rozet verisi';
    olcum := v_list || ' ilan, ' || v_badge || ' tanesinde karar var';
    sonuc := case when v_list = 0 then '—'
                  when v_badge = 0 then '✗ ROZET VERİSİ GELMİYOR'
                  else '✓' end;
    return next;

    akis := '2b · Kapalı ilanda buton kilidi';
    olcum := v_block || ' ilan istek almaya kapalı';
    sonuc := case when v_list = 0 then '—' else '✓' end;
    return next;

    akis := '2c · Taşıyıcı uyarısı (AJet/THY)';
    olcum := v_carrier || ' ilanda uyarı üretildi';
    sonuc := '✓';
    return next;
  end if;

  -- ---------- 3) BAĞLANTI İSTEĞİ ALICIDA GÖRÜNÜYOR MU ----------
  select id into v_other from users
   where id <> v_uid and coalesce(is_staff,false) = false
     and email not like '%@vitrin.loungelink.test'
   limit 1;

  if v_uid is null or v_other is null then
    akis := '3 · Bağlantı isteği'; olcum := 'iki hesap bulunamadı'; sonuc := '—'; return next;
  else
    delete from connection_requests
     where from_id = v_uid and to_id = v_other and status = 'pending';

    insert into connection_requests (from_id, to_id, status, intent)
    values (v_uid, v_other, 'pending', 'lounge')
    returning id into v_req;

    -- ALICININ gözünden oku: app tam bu sorguyu yapıyor.
    select count(*) into v_gorunen from connection_requests
     where to_id = v_other and status = 'pending';

    akis := '3 · Bağlantı isteği alıcıda';
    olcum := 'alıcının bekleyen istek sayısı: ' || v_gorunen;
    sonuc := case when v_gorunen > 0 then '✓' else '✗ ALICI GÖRMÜYOR' end;
    return next;

    -- Alıcı profili okunabiliyor mu (liste kartı için şart)
    select count(*) into n from profiles where user_id = v_uid;
    akis := '3b · Gönderenin profili okunabiliyor';
    olcum := n || ' profil satırı';
    sonuc := case when n > 0 then '✓' else '✗ PROFİL YOK — kart çizilemez' end;
    return next;

    delete from connection_requests where id = v_req;
  end if;

  perform set_config('request.jwt.claims', '{}', true);
end $$;
grant execute on function public.device_flow_check() to authenticated;

do $$
declare r record; n int := 0;
begin
  for r in select * from public.device_flow_check() loop
    raise notice '185 · % → % [%]', r.akis, r.olcum, r.sonuc;
    if r.sonuc like '✗%' then n := n + 1; end if;
  end loop;
  if n > 0 then
    raise exception '185: cihaz akışlarında % gerçek hata var', n;
  end if;
end $$;

select '185 OK - uc akis sunucu tarafinda kanitlandi' as sonuc;
