-- ============================================================================
-- 354 · GİZLİ İNCELEME VİTRİNİ   (12 Kasım 2026 · 1.0.1 incelemesi)
--
-- NEDEN: 351 (10 Kasım) bütün fikstür hesaplarını sildi; canlıda bugün AÇIK İLAN 0.
-- Apple incelemecisi (inceleme@loungelink.co) Keşfet'i boş görür, "İstek gönder"
-- akışını deneyemez → Guideline 2.1 reddi riski.
--
-- GERÇEK KULLANICI BU VERİYİ GÖRMEZ (Gökberk'in şartı, 12 Kasım):
--   · Hesaplar @vitrin.loungelink.test → seed_test_hesabi() = true.
--   · `test_hesaplarini_gizle` bayrağı (301, varsayılan AÇIK) açıkken bu hesaplar ve
--     ilanları yalnız test_gorunurlugu listesindekilere görünür: discover_availabilities,
--     kesfet_ozeti, discover_people, kisi_ara, lounge_radar_people, guide_hosts_today,
--     havalimani_nabzi, is_visible.
--   · SIZINTI KAPATILDI: trg_talep_haber_ver (247) yeni ilan açılınca o havalimanı/tarih
--     için "haber ver" diyen herkese bildirim atıyordu — test host'un ilanı için de.
--     Artık gizli test hesabının ilanı için bildirim GİTMEZ (§1).
--   · Vitrin host'ları giriş yapamaz (şifresiz auth kaydı), kimseye mesaj/istek atmaz.
--
--   · İlan tablosu doğrudan okunduğunda da (API) gizli test host'unun ilanı artık
--     gerçek kullanıcıya satır vermez (§2, RLS avail_public_read).
--
-- NE KURAR: 2 vitrin host (Priority Pass · Miles&Smiles Elite Plus), IST'de 2 ilan
-- (bugün+2, bugün+3) + inceleme hesabına 1. ilanla EŞLEŞEN seyahat (istek göndermek
-- eşleşen seyahat ister: no_matching_trip — yerel testte ölçüldü).
-- Her gece 03:40 `ll-inceleme-vitrin`: bugüne gelen vitrin ilanı ileri kayar, inceleme
-- seyahati 1. ilanın tarihine hizalanır (inceleme günler sürse de akış açık kalır).
-- İncelemeci istek atarsa: kimse cevaplamaz, 72 saatte kredi kendiliğinden iade.
--
-- KALDIRMAK (yayın onaylandıktan sonra, isteğe bağlı): dosyanın sonundaki blok.
-- Tekrar koşulabilir. Son sorgu tek satır: ilk dört sütun true, son sütun 0.
-- ============================================================================

-- 1 · Sızıntı kapatma: gizli test hesabının ilanı "haber ver" bildirimi tetiklemez
create or replace function public.trg_talep_haber_ver()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_ara int := coalesce((select (value #>> '{}')::int from beta_settings
                          where key='talep_bildirim_ara_saat'), 12);
  v_n int := 0;
  r record;
begin
  if not coalesce(new.active, true) then return new; end if;
  if coalesce(new.visibility::text, 'Public') <> 'Public' then return new; end if;
  -- 354: gerçek kullanıcıdan gizlenen test/vitrin host'unun ilanı için kimseye haber verme.
  if public.test_hesabi_gizli_mi(new.host_id) then return new; end if;

  for r in
    select t.id, t.user_id from talep_kayitlari t
     where t.aktif
       and t.airport_code = new.airport_code
       and new.avail_date between t.tarih_bas and t.tarih_bit
       and t.user_id <> new.host_id
       and (t.son_bildirim_at is null
            or t.son_bildirim_at < now() - make_interval(hours => v_ara))
  loop
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (r.user_id, 'system',
            'Beklediğin gün için ilan açıldı',
            format('%s · %s — haber ver dediğin aralıkta yeni bir ilan var.',
                   new.airport_code, to_char(new.avail_date, 'DD.MM.YYYY')),
            'availability', new.id);
    update talep_kayitlari set son_bildirim_at = now() where id = r.id;
    v_n := v_n + 1;
  end loop;

  if v_n > 0 then
    raise notice 'talep haberi: % kisiye gonderildi', v_n;
  end if;
  return new;
end $f$;

-- 2 · İlan tablosu doğrudan okunduğunda gizli test host'unun ilanı gerçek kullanıcıya görünmesin
drop policy if exists avail_public_read on availabilities;
create policy avail_public_read on availabilities
  for select to authenticated
  using (visibility = 'Public'::availability_visibility and active = true
         and not public.test_hesabi_gizli_mi(host_id));

-- 2b · Gizli test host'una gerçek kullanıcı İSTEK / BAĞLANTI gönderemesin.
-- Uygulamada zaten göremiyor; bu, ilan kimliğini bilip API'ye doğrudan yazan biri için
-- (yerel testte ölçüldü: doğrulanmış gerçek hesap, kimliği bilerek istek atabiliyordu).
-- auth.uid() boşsa (SQL Editor, cron, servis) dokunmaz; test/staff/inceleme hesapları geçer.
create or replace function public.trg_gizli_test_hedefi()
returns trigger language plpgsql security definer set search_path = public as $g354$
begin
  if auth.uid() is null then return new; end if;
  -- İç içe IF: plpgsql AND'i kısa devre etmez; requests satırında new.to_id YOK.
  if tg_table_name = 'requests' then
    if public.test_hesabi_gizli_mi(new.host_id) then raise exception 'availability_not_found'; end if;
  elsif tg_table_name = 'connection_requests' then
    if public.test_hesabi_gizli_mi(new.to_id) then raise exception 'user_not_found'; end if;
  end if;
  return new;
end $g354$;
drop trigger if exists trg_gizli_test_hedefi on requests;
create trigger trg_gizli_test_hedefi before insert on requests
  for each row execute function public.trg_gizli_test_hedefi();
drop trigger if exists trg_gizli_test_hedefi on connection_requests;
create trigger trg_gizli_test_hedefi before insert on connection_requests
  for each row execute function public.trg_gizli_test_hedefi();

-- 3 · Vitrin host'ları + ilanlar + inceleme hesabının görünürlüğü
do $v354$
declare
  r record; v_uid uuid; v_pid uuid; v_lounge uuid; v_ins int := 0;
begin
  -- Gizleme bayrağı kapalıysa DUR: vitrin gerçek kullanıcıya görünürdü.
  if not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true) then
    raise exception '354: test_hesaplarini_gizle KAPALI - vitrin gercek kullaniciya gorunur, durduruldu';
  end if;

  for r in
    select * from (values
      ('a354a354-0000-4000-8000-000000000001'::uuid, 'host1@vitrin.loungelink.test', 'Elif K.', 'Ürün Tasarımcısı',
       'Sık uçuyorum, aktarmalarda lounge''da sohbet etmeyi severim.', 'PRIORITY_PASS', 'PP_PRESTIGE', 2, '10:00', '13:30', 'TK1979', 'TK', 2, 'iGA Lounge — Dış Hat'),
      ('a354a354-0000-4000-8000-000000000002'::uuid, 'host2@vitrin.loungelink.test', 'Mert A.', 'Girişim Kurucusu',
       'Haftada iki uçuş, çoğu IST aktarmalı. Yeni insanlarla tanışmayı severim.', 'TK_MS', 'ELPL', 3, '14:00', '17:00', 'TK1823', 'TK', 1, 'Turkish Airlines Lounge — Dış Hat (Miles&Smiles)')
    ) as x(id, email, ad, meslek, bio, prog, tier, gun, t1, t2, ucus, tasiyici, slot, salon)
  loop
    v_uid := r.id;
    if not exists (select 1 from users where id = v_uid) then
      insert into auth.users (id, email) values (v_uid, r.email);   -- 004 köprüsü users/profiles/verifications kurar
    end if;
    if not exists (select 1 from users where id = v_uid) then
      raise exception '354: % icin users satiri olusmadi (004 koprusu)', r.email;
    end if;

    update users set role = 'host' where id = v_uid;
    update profiles
       set name = r.ad, profession = r.meslek, bio = r.bio,
           languages = array['Türkçe','İngilizce'], show_on_discovery = true
     where user_id = v_uid;

    insert into verifications (user_id, email_verified, email_verified_at, phone_verified, phone_verified_at, phone_verified_method)
    values (v_uid, true, now(), true, now(), 'manual')
    on conflict (user_id) do update set email_verified = true, phone_verified = true;

    select id into v_pid from lounge_programs where code = r.prog;
    if v_pid is not null
       and not exists (select 1 from host_entitlements e where e.user_id = v_uid and e.program_id = v_pid) then
      insert into host_entitlements (user_id, program_id, tier, verified) values (v_uid, v_pid, r.tier, true);
    end if;

    -- DIŞ HAT salonu: inceleme seyahati IST→LHR (dış hat). İç hat salonu seçilirse kural
    -- motoru scope_mismatch der ve istek gönderilemez (yerel testte ölçüldü).
    select l.id into v_lounge from lounges l join lounge_venues v on v.id = l.venue_id and v.active
     where l.active and l.airport_code = 'IST'
     order by coalesce(l.name = r.salon, false) desc, coalesce(v.scope in ('international', 'both'), false) desc, length(l.name), l.id
     limit 1;

    if not exists (select 1 from availabilities a where a.host_id = v_uid and a.active and a.avail_date >= current_date) then
      insert into availabilities
        (host_id, lounge_id, lounge_name, airport_code, avail_date, time_from, time_to,
         slots, filled, flight_number, carrier, visibility, active, program_id)
      values (v_uid, v_lounge, (select name from lounges where id = v_lounge), 'IST', current_date + r.gun, r.t1::time, r.t2::time,
              r.slot, 0, r.ucus, r.tasiyici, 'Public'::availability_visibility, true, v_pid);
      v_ins := v_ins + 1;
    end if;
  end loop;

  -- İnceleme hesabı vitrin hesaplarını görsün (333'te eklenmişti; 351 sonrası garanti)
  insert into test_gorunurlugu (user_id, ekleyen)
  select u.id, '354 · inceleme vitrini' from users u where lower(u.email) = 'inceleme@loungelink.co'
  on conflict (user_id) do nothing;

  raise notice '354: % yeni vitrin ilani acildi', v_ins;
end $v354$;

-- 4 · Gece hizalayıcı: vitrin ilanları ileride kalsın, inceleme seyahati 1. ilanla eşleşsin
create or replace function public.inceleme_vitrin_tazele()
returns jsonb language plpgsql security definer set search_path = public as $ivt$
declare
  r record; v_inc uuid; v_tarih date; v_ilan int := 0; v_sey text := 'yok';
begin
  if auth.uid() is not null then raise exception 'not_authorized'; end if;
  for r in
    select a.id, u.email from availabilities a join users u on u.id = a.host_id
     where u.email like '%@vitrin.loungelink.test' and a.active and a.avail_date <= current_date
  loop
    begin
      update availabilities
         set avail_date = current_date + case when r.email like 'host2@%' then 3 else 2 end
       where id = r.id;
      v_ilan := v_ilan + 1;
    exception when others then null;   -- kabul edilmiş başvurulu ilan: dokunma
    end;
  end loop;

  select id into v_inc from users where lower(email) = 'inceleme@loungelink.co';
  select a.avail_date into v_tarih from availabilities a
   where a.host_id = 'a354a354-0000-4000-8000-000000000001'::uuid and a.active
     and a.avail_date >= current_date
   order by a.avail_date limit 1;
  if v_inc is null or v_tarih is null then
    return jsonb_build_object('ok', true, 'ilan', v_ilan, 'seyahat', 'hedef yok');
  end if;

  begin
    if exists (select 1 from visits where user_id = v_inc and flight_number = 'TK1979') then
      update visits set visit_date = v_tarih, airport_code = 'IST', time_from = '09:30', time_to = '14:00'
       where user_id = v_inc and flight_number = 'TK1979' and visit_date <> v_tarih;
      v_sey := 'hizalandi';
    else
      insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number)
      values (v_inc, 'IST', 'LHR', v_tarih, '09:30', '14:00', 'TK1979');
      v_sey := 'eklendi';
    end if;
  exception when others then
    v_sey := 'atlandi: ' || sqlerrm;
  end;
  return jsonb_build_object('ok', true, 'ilan', v_ilan, 'seyahat', v_sey, 'tarih', v_tarih);
end $ivt$;
revoke execute on function public.inceleme_vitrin_tazele() from public, anon, authenticated;

select public.inceleme_vitrin_tazele() as ilk_hizalama;

do $c354$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-inceleme-vitrin') then
      perform cron.unschedule('ll-inceleme-vitrin');
    end if;
    perform cron.schedule('ll-inceleme-vitrin', '40 3 * * *', 'select public.inceleme_vitrin_tazele()');
    raise notice '354: pg_cron isi kuruldu - ll-inceleme-vitrin, her gece 03:40.';
  else
    raise notice '354: pg_cron yok - is kurulmadi.';
  end if;
end $c354$;

-- 5 · DOĞRULAMA (tek satır; ilk dört true, son sütun 0 olmalı)
select
  coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true) as gizleme_acik,
  (select count(*) from availabilities a join users u on u.id = a.host_id
    where u.email like '%@vitrin.loungelink.test' and a.active and a.avail_date >= current_date) >= 2 as vitrin_ilan_hazir,
  exists (select 1 from test_gorunurlugu g join users u on u.id = g.user_id
           where lower(u.email) = 'inceleme@loungelink.co') as inceleme_goruyor,
  exists (select 1 from visits v join users u on u.id = v.user_id
           where lower(u.email) = 'inceleme@loungelink.co' and v.visit_date >= current_date) as inceleme_seyahati_var,
  (select count(*) from test_gorunurlugu g join users u on u.id = g.user_id
    where lower(u.email) not in ('inceleme@loungelink.co')
      and not public.seed_test_hesabi(u.email)) as gorebilen_diger_gercek_hesap_sayisi;

-- ── KALDIRMAK İSTERSEN (ayrı çalıştır) ──────────────────────────────────────
-- select cron.unschedule('ll-inceleme-vitrin');
-- select public.temizlik_derin_sil('public.users', $$email like '%@vitrin.loungelink.test'$$);
-- delete from auth.users where email like '%@vitrin.loungelink.test';
