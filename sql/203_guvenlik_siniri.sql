-- ============================================================
-- 203 · GÜVENLİK SINIRI — "kim neyi çağırabilir" ARTIK VERİ
-- 17 Ağustos 2026
--
-- 🔴 BU DOSYA BİR TAHMİNLE DEĞİL, BİR ÖLÇÜMLE DOĞDU.
--
-- Denetimde iddia edildi: "admin fonksiyonları herkese açık".
-- İddiayı DOĞRULAMADAN yazmadım; canlı harness'te ÇALIŞTIRDIM.
-- Aynen şu komutlar, aynen şu çıktılar:
--
--   set role authenticated;
--   select upsert_admin('kural1@seed.loungelink.test','super_admin','["all"]');
--     → {"ok": true, "user_id": "11110001-0000-4000-8000-000000000001"}
--   select assign_partner('kural1@seed.loungelink.test', <lounge>, 'manager');
--     → {"ok": true}
--   reset role; select role, permissions from admin_roles;
--     → super_admin | ["all"]
--
-- Yani: uygulamaya kayıt olan HERHANGİ BİR KİŞİ, tek bir RPC
-- çağrısıyla süper yönetici olabiliyordu. Kredi verebilir, kullanıcı
-- silebilir, e-posta değiştirebilir, kampanya gönderebilirdi.
-- Bu tahmin değil; yukarıdaki üç satır kanıt.
--
-- 🔴 AYNI DENETİMİN İKİ İDDİASI YANLIŞ ÇIKTI — ölçtüğüm için biliyorum:
--   (a) "save_host_access ON CONFLICT hedefi yok" → `uq_he` indeksi VAR,
--       fonksiyon üç kez çağrıldı, tek satır kaldı, aynı id döndü.
--   (b) "authenticated availabilities tablosuna UPDATE yapabiliyor" →
--       authenticated'ın RLS politikası olmayan HİÇBİR tabloda yazma
--       hakkı yok (sorgu 0 satır döndü).
--   Ölçmeden yazsaydım iki gereksiz "düzeltme" ekleyecektim.
--
-- ⚠️ UYGULAMAYI ETKİLEMEZ. Uygulamanın çağırdığı 82 fonksiyona
-- DOKUNULMUYOR. Yalnız uygulamanın ASLA çağırmadığı fonksiyonlar
-- kapatılıyor. app ∩ BO kesişimi ÖLÇÜLDÜ: sıfır. Sınır temiz.
--
-- ⚠️ BO'YU DA ETKİLEMEZ. BO `SUPABASE_SECRET_KEY` (service_role) ile
-- bağlanıyor (backoffice/lib/supabase.js:17) — o role açıkça grant
-- veriliyor.
--
-- 🔴 GİZLİ BAĞIMLILIK KONTROLÜ (revoke'tan ÖNCE yapıldı):
-- RLS politikalarında ve view tanımlarında public fonksiyon çağrısı
-- var mı diye kataloğa soruldu → İKİSİ DE 0 SATIR. Eğer bir politika
-- `is_blocked_pair(...)` çağırsaydı ve ondan execute'u alsaydım,
-- kullanıcı kendi satırını bile okuyamaz hale gelirdi. Sessiz kilit
-- olurdu; hata da vermezdi.
-- ============================================================


-- ============================================================
-- 1) YÜZEY ARTIK VERİ — "hangi fonksiyon istemciye açık" bir tablo
-- ============================================================
-- NEDEN TABLO: bugüne kadar sınır ADLANDIRMA GELENEĞİNE dayanıyordu
-- ("admin_" ile başlayan yönetici işidir). Gelenek denetlenemez:
-- `assign_partner`, `review_host_application`, `send_campaign`,
-- `resolve_dispute` hiçbiri "admin_" ile başlamıyordu ve dördü de
-- herkese açıktı. Sınır bir TABLO olursa, yeni bir fonksiyon
-- eklendiğinde varsayılan KAPALI olur ve denetim onu yakalar.
create table if not exists rpc_client_surface (
  fn_name    text primary key,
  client     text not null check (client in ('app','public_web')),
  note       text,
  added_at   timestamptz not null default now()
);

comment on table rpc_client_surface is
  'Istemci (anon/authenticated) anahtariyla cagrilmasina IZIN VERILEN RPC listesi. Burada olmayan her public fonksiyon yalniz service_role tarafindan cagrilabilir. Kaynak: rnapp/src + App.js icindeki supabase.rpc("...") cagrilarinin taranmasi.';

-- Uygulamanın GERÇEKTEN çağırdığı 82 ad (grep ile çıkarıldı, elle
-- yazılmadı — elle yazsaydım biri eksik kalır ve canlıda 42501 olurdu).
insert into rpc_client_surface (fn_name, client, note) values
  ('access_source_summary','app',null),
  ('active_campaigns','app',null),
  ('alternatives_for','app',null),
  ('amenities_for','app',null),
  ('apply_for_host','app',null),
  ('apply_referral','app',null),
  ('cancel_session','app',null),
  ('card_advice_for_lounge','app',null),
  ('card_product_options','app',null),
  ('card_tier_options','app',null),
  ('carrier_options','app',null),
  ('change_phone','app',null),
  ('change_plan','app',null),
  ('claim_founding_host','app',null),
  ('confirm_session','app',null),
  ('create_availability','app',null),
  ('create_report','app',null),
  ('create_request','app',null),
  ('defer_rating','app',null),
  ('delete_my_account','app',null),
  ('discover_availabilities','app',null),
  ('discover_people','app',null),
  ('discovery_rule_badges','app',null),
  ('expire_stale_sessions','app','bakim ama uygulama da cagiriyor'),
  ('flight_info','app',null),
  ('founding_host_status','app',null),
  ('grant_consents','app',null),
  ('guide_airports','app',null),
  ('guide_hosts_today','app',null),
  ('guide_lounges','app',null),
  ('guide_programs','app',null),
  ('home_connections','app',null),
  ('host_requests','app',null),
  ('host_unused_rights','app',null),
  ('invitable_guests','app',null),
  ('join_campaign','app',null),
  ('log_client_error','app',null),
  ('lounge_hint_for_host','app',null),
  ('lounge_radar_count','app',null),
  ('lounge_radar_people','app',null),
  ('lounges_for_airport','app',null),
  ('mark_email_verified','app','bu dosyada KANITA baglandi'),
  ('my_access_cards','app',null),
  ('my_host_access','app',null),
  ('my_host_application','app',null),
  ('my_referral','app',null),
  ('my_sent_requests','app',null),
  ('pending_actions','app',null),
  ('pending_field_report','app',null),
  ('pending_ratings','app',null),
  ('phone_in_use','app',null),
  ('plan_options','app',null),
  ('rate_session','app',null),
  ('redeem_promo_code','app',null),
  ('redeem_reward','app',null),
  ('remove_host_card','app',null),
  ('request_precheck','app',null),
  ('respond_connection','app',null),
  ('respond_request','app',null),
  ('save_host_access','app',null),
  ('save_host_card','app',null),
  ('save_push_token','app',null),
  ('send_connection','app',null),
  ('send_invite','app',null),
  ('send_otp','app','demo_code bu dosyada kapiya alindi'),
  ('set_availability_cabin','app',null),
  ('set_availability_carrier','app',null),
  ('set_availability_charter','app',null),
  ('set_card_bank_coverage','app',null),
  ('set_featured','app',null),
  ('share_session_status','app',null),
  ('sos_alert','app',null),
  ('start_session_request','app',null),
  ('submit_field_report','app',null),
  ('travel_style_options','app',null),
  ('trip_fit_note','app',null),
  ('unrated_sessions','app',null),
  ('venue_partners','app',null),
  ('venue_price_list','app',null),
  ('verify_email_contact','app',null),
  ('verify_otp','app',null),
  ('waiting_demand','app',null)
on conflict (fn_name) do nothing;


-- ============================================================
-- 2) SINIRI UYGULA
-- ============================================================
-- 🔴 revoke ... from public YETMEZ. Supabase `anon` ve `authenticated`
-- rollerine ŞEMA ÜZERİNDEN toplu grant veriyor olabilir; o grant
-- PUBLIC'ten bağımsızdır. Bu yüzden ÜÇÜNDEN DE alıyorum.
-- service_role'a AÇIKÇA veriyorum: "zaten her şeyi yapabiliyor"
-- varsayımı bir varsayımdır, veri değil.
create or replace function public.apply_rpc_surface()
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_hedef text[];
  v_ad    text[] := '{}';
  i       int;
  v_kilit int := 0;
begin
  -- 🔴 ÖNCE TOPLA, SONRA DEĞİŞTİR. `for r in select ...` bir imleçtir;
  -- döngü sürerken revoke yapmak, imlecin okuduğu koşulu
  -- (`has_function_privilege`) altından çeker. Klasik "iterate ederken
  -- mutate etme" hatası: sonuç sessizce EKSİK kalır, hata VERMEZ.
  -- Bu yüzden tam liste önce diziye alınıyor.
  select array_agg(format('%I(%s)', proname, args) order by proname),
         array_agg(proname order by proname)
    into v_hedef, v_ad
    from (
      select p.proname::text as proname,
             pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.prokind = 'f'
         and not exists (select 1 from rpc_client_surface s where s.fn_name = p.proname)
         and (
           has_function_privilege('authenticated', p.oid, 'EXECUTE')
           or has_function_privilege('anon', p.oid, 'EXECUTE')
         )
    ) topla;

  if v_hedef is null then
    return jsonb_build_object('kilitlenen', 0, 'ornekler', '[]'::jsonb);
  end if;

  for i in 1 .. array_length(v_hedef, 1) loop
    execute 'revoke all on function public.' || v_hedef[i] || ' from public, anon, authenticated';
    execute 'grant execute on function public.' || v_hedef[i] || ' to service_role';
    v_kilit := v_kilit + 1;
  end loop;

  return jsonb_build_object('kilitlenen', v_kilit, 'ornekler', to_jsonb(v_ad[1:12]));
end $fn$;

comment on function public.apply_rpc_surface() is
  'rpc_client_surface disinda kalan her public fonksiyonu istemci rollerinden alir, service_role a verir. Yeni migration sonrasi tekrar calistirilabilir (idempotent).';

-- ⚠️ ÇAĞRI BURADA DEĞİL, DOSYANIN SONUNDA. İlk yazışımda buraya
-- koymuştum ve 3. nöbetçi patladı: bu satırdan SONRA oluşturulan
-- `rpc_surface_violations` kendisi açık kalmıştı. Nöbetçi kendi
-- yazarını yakaladı — sınırın işe yaradığının ilk kanıtı bu oldu.
-- KURAL: `apply_rpc_surface()` her zaman, fonksiyon oluşturan her
-- migration'ın EN SONUNDA çağrılır.


-- ============================================================
-- 3) KALICI DENETİM — sınır bir daha sessizce açılmasın
-- ============================================================
-- Yeni bir migration `create function` yazıp grant verirse, bu
-- fonksiyon onu görür. pg_run.py bunu her koşuda çağırıyor.
create or replace function public.rpc_surface_violations()
returns table (fn_name text, arglist text, neden text)
language sql stable security definer set search_path = public as $fn$
  -- (a) yüzeyde OLMAYAN ama istemciye AÇIK olan
  select p.proname::text,
         pg_get_function_identity_arguments(p.oid)::text,
         'yuzeyde yok ama istemciye acik'::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
     and not exists (select 1 from rpc_client_surface s where s.fn_name = p.proname)
     and (has_function_privilege('authenticated', p.oid, 'EXECUTE')
          or has_function_privilege('anon', p.oid, 'EXECUTE'))
  union all
  -- (b) yüzeyde OLAN ama artık VAR OLMAYAN (uygulama 404 alır)
  select s.fn_name, ''::text, 'yuzeyde yazili ama fonksiyon YOK'::text
    from rpc_client_surface s
   where not exists (
     select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = s.fn_name)
  union all
  -- (c) yüzeyde OLAN ama istemci ÇAĞIRAMAYAN (sessiz 42501)
  select s.fn_name, ''::text, 'yuzeyde yazili ama istemci CAGIRAMIYOR'::text
    from rpc_client_surface s
   where exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname='public' and p.proname = s.fn_name)
     and not exists (
       select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname='public' and p.proname = s.fn_name
          and has_function_privilege('authenticated', p.oid, 'EXECUTE'));
$fn$;

grant execute on function public.rpc_surface_violations() to service_role;


-- ============================================================
-- 4) mark_email_verified — KANITSIZ DOĞRULAMA KAPANDI
-- ============================================================
-- 🔴 ÖLÇÜM: harness'te oturum açmış bir kullanıcı olarak çağırdım:
--     select mark_email_verified();          → {"ok": true}
--     select is_contact_verified(<uid>);     → t
-- Yani e-postasını hiç açmamış biri, tek çağrıyla `create_availability`
-- kapısını (`contact_not_verified`) açabiliyordu. Host olmanın TEK
-- doğrulama şartıydı bu.
--
-- Doğru yol zaten VARDI: `verify_email_contact()` auth.users içindeki
-- `email_confirmed_at`e bakıyor. Uygulama İKİSİNİ DE çağırıyor
-- (screens.js:2864 ve 2871) — ikincisi yalnız yedek. O yüzden imzayı
-- KORUYUP gövdeyi kanıta bağlıyorum: uygulamanın tek satırı değişmiyor,
-- saldırı yüzeyi kapanıyor.
create or replace function public.mark_email_verified()
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_uid uuid := auth.uid(); v_conf timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- KANIT: Supabase e-postayı gerçekten onayladı mı?
  select email_confirmed_at into v_conf from auth.users where id = v_uid;
  if v_conf is null then raise exception 'email_not_confirmed'; end if;

  insert into verifications (user_id, email_verified, email_verified_at)
  values (v_uid, true, now())
  on conflict (user_id) do update
    set email_verified = true, email_verified_at = now();
  perform public.recompute_trust(v_uid);
  return jsonb_build_object('ok', true);
end $fn$;


-- ============================================================
-- 5) send_otp — demo kodu ARTIK BİR KAPININ ARKASINDA
-- ============================================================
-- Fonksiyon üretilen 6 haneli kodu cevapta DÖNDÜRÜYORDU
-- (`'demo_code', v_code`). Beta'da SMS sağlayıcısı yokken bu
-- BİLİNÇLİ bir tercihti; sorun, canlıya çıkarken bunu hatırlamanın
-- İNSAN HAFIZASINA bırakılmış olması. Artık bir ayar:
-- `beta_settings.otp_demo_mode`. SMS bağlandığı gün BO'dan 'no'
-- yapılır, deploy gerekmez — 202'deki AJet anahtarıyla aynı desen.
-- ⚠️ `beta_settings` yalnız (key, value, updated_at, updated_by) taşır.
-- İlk yazışımda `note` kolonu varsaydım ve harness 42703 verdi. Aynı
-- sınıf ondördüncü kez: ŞEMAYI OKUMADAN KOLON ADI UYDURMA. Açıklama
-- artık burada, kodun yanında duruyor:
--   yes → send_otp üretilen kodu cevapta döndürür (SMS sağlayıcısı
--         bağlanana kadar telefon doğrulaması başka türlü test edilemez)
--   no  → döndürmez. SMS sağlayıcısı bağlandığı gün BO'dan 'no' yapılır.
insert into beta_settings (key, value)
values ('otp_demo_mode', to_jsonb('yes'::text))
on conflict (key) do nothing;

-- ============================================================
-- 5b) 🔴 BEKLENMEDİK BULGU — TELEFON DOĞRULAMA CANLIDA HİÇ ÇALIŞMIYOR
-- ============================================================
-- Nöbetçiyi yazarken harness `gen_salt(unknown) does not exist` dedi.
-- İlk refleksim "harness eksik" demekti. ÖLÇTÜM, öyle değilmiş:
--
--   select extname, nspname from pg_extension e
--     join pg_namespace n on n.oid = e.extnamespace;
--   → pgcrypto | extensions
--
-- pgcrypto `extensions` şemasında (Supabase'in varsayılanı, harness de
-- aynısını taklit ediyor). Ama iki fonksiyonun tanımında
-- `SET search_path TO 'public'` yazıyor ve bu, veritabanının
-- `"$user", public, extensions` yolunu EZİYOR. Yani `crypt` ve
-- `gen_salt` çözülemiyor:
--
--   send_otp   → 42883, kod hiç üretilemiyor
--   verify_otp → 42883, kod hiç doğrulanamıyor
--
-- Bunu kimse fark etmemiş çünkü beta'da doğrulama kapısı e-postadan
-- geçiyor (`is_contact_verified` = telefon VEYA e-posta) ve telefon
-- yolu hiç kullanılmamış. SMS sağlayıcısı bağlandığı gün akış ilk
-- çağrıda patlardı.
--
-- DERS (yeni hata sınıfı): `SET search_path` bir güvenlik önlemidir
-- ama aynı zamanda bir KISITLAMADIR — eklenti şemasını dışarıda
-- bırakırsa fonksiyon çalışmaz. Güvenli hâli `public, extensions`.
alter function public.verify_otp(text, text) set search_path = public, extensions;

create or replace function public.send_otp(p_phone text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $fn$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_recent int;
  v_demo boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_phone !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'bad_phone_format'; end if;

  select count(*) into v_recent from otp_tokens
   where user_id = v_uid and created_at > now() - interval '1 minute';
  if v_recent >= 1 then raise exception 'too_many_requests'; end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

  update otp_tokens set used_at = now()
   where user_id = v_uid and used_at is null and purpose = 'phone_verify';

  insert into otp_tokens (user_id, phone_e164, code_hash, purpose, expires_at)
  values (v_uid, p_phone, crypt(v_code, gen_salt('bf')), 'phone_verify', now() + interval '5 minutes');

  select coalesce(value #>> '{}', 'yes') = 'yes' into v_demo
    from beta_settings where key = 'otp_demo_mode';

  return jsonb_build_object('ok', true, 'expires_in', 300)
       || case when coalesce(v_demo, true)
               then jsonb_build_object('demo_code', v_code)
               else '{}'::jsonb end;
end $fn$;


-- ============================================================
-- 6) SINIRI ŞİMDİ UYGULA — bu dosyanın ürettiği fonksiyonlar dahil
-- ============================================================
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '203: % fonksiyon istemciye kapatildi. Ornek: %',
    v ->> 'kilitlenen', v ->> 'ornekler';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) SALDIRIYI TEKRAR DENE — artık DÜŞMELİ
-- Bu, dosyanın var oluş sebebinin kanıtı. Geçmesi değil, ARTIK
-- PATLAMASI beklenen bir çağrı.
do $$
declare v_hata text := '';
begin
  set local role authenticated;
  begin
    perform public.upsert_admin('kural1@seed.loungelink.test','super_admin','["all"]'::jsonb);
    v_hata := 'upsert_admin HALA CAGRILABILIYOR';
  exception when insufficient_privilege then null;
            when others then
              if sqlerrm not like '%permission denied%' then
                v_hata := 'upsert_admin beklenmeyen hata: ' || sqlerrm;
              end if;
  end;
  reset role;
  if v_hata <> '' then raise exception '203: %', v_hata; end if;
  raise notice '203: siradan kullanici artik upsert_admin cagiramiyor (kanit: yetki hatasi)';
end $$;

-- 2) UYGULAMANIN YÜZEYİ BOZULMADI MI — 82 adın hepsi hâlâ çağrılabilir mi?
do $$
declare v_eksik text[];
begin
  select array_agg(fn_name || ' (' || neden || ')')
    into v_eksik
    from public.rpc_surface_violations()
   where neden <> 'yuzeyde yok ama istemciye acik';
  if v_eksik is not null then
    raise exception '203: uygulama yuzeyi BOZULDU → %', v_eksik;
  end if;
  raise notice '203: uygulamanin 82 RPC adinin hepsi hala cagrilabilir';
end $$;

-- 3) SINIR GERÇEKTEN KAPANDI MI — hiç ihlal kalmadı mı?
do $$
declare v_n int; v_ornek text;
begin
  select count(*), string_agg(fn_name, ', ' order by fn_name)
    into v_n, v_ornek
    from (select fn_name from public.rpc_surface_violations()
           where neden = 'yuzeyde yok ama istemciye acik' limit 20) q;
  if coalesce(v_n,0) > 0 then
    raise exception '203: % fonksiyon HALA istemciye acik → %', v_n, v_ornek;
  end if;
  raise notice '203: yuzey disinda istemciye acik fonksiyon KALMADI';
end $$;

-- 4) MUTASYON — denetim gerçekten yakalıyor mu, yoksa hep 0 mı dönüyor?
-- 🔴 Bu nöbetçi olmadan 3. nöbetçi HİÇBİR ŞEY kanıtlamaz: bozuk bir
-- `rpc_surface_violations` de her zaman boş döner ve yeşil görünürdü.
-- 199'da tam bunu yapmıştım (rule_contamination_check hep 0 dönüyordu).
do $$
declare v_n int;
begin
  grant execute on function public.upsert_admin(text,text,jsonb,text,boolean) to authenticated;
  select count(*) into v_n from public.rpc_surface_violations()
   where fn_name = 'upsert_admin' and neden = 'yuzeyde yok ama istemciye acik';
  revoke all on function public.upsert_admin(text,text,jsonb,text,boolean) from public, anon, authenticated;
  if v_n <> 1 then
    raise exception '203: sinir kasitli acildi ama denetim GORMEDI — denetim sahte';
  end if;
  raise notice '203: denetim mutasyonu yakaladi (kasitli acilan grant gorulda ve geri alindi)';
end $$;

-- 5) mark_email_verified ARTIK KANIT İSTİYOR
do $$
declare v_uid uuid; v_gecti boolean := false; v_eski timestamptz; v_geri boolean := false;
begin
  select id into v_uid from auth.users where email_confirmed_at is null limit 1;
  if v_uid is null then
    -- Seed'de onaysız kullanıcı yoksa geçici olarak birini onaysız yapıp
    -- 🔴 MUTLAKA GERİ ALIYORUM. Bir nöbetçi, kanıtladığı şey uğruna veriyi
    -- kalıcı bozarsa sonraki dosyalar yanlış zeminde çalışır.
    select id, email_confirmed_at into v_uid, v_eski from auth.users limit 1;
    if v_uid is null then raise notice '203: kullanici yok — atlandi'; return; end if;
    update auth.users set email_confirmed_at = null where id = v_uid;
    v_geri := true;
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  begin
    perform public.mark_email_verified();
    v_gecti := true;
  exception when others then
    if sqlerrm <> 'email_not_confirmed' then raise; end if;
  end;
  perform set_config('request.jwt.claims', '', true);
  if v_geri then
    update auth.users set email_confirmed_at = v_eski where id = v_uid;
  end if;

  if v_gecti then
    raise exception '203: e-postasi ONAYLANMAMIS kullanici mark_email_verified ile kapiyi acti';
  end if;
  raise notice '203: kanitsiz e-posta dogrulamasi kapandi (email_not_confirmed)';
end $$;

-- 6) send_otp demo kapısı GERÇEKTEN anahtarla çalışıyor mu (mutasyon)
do $$
declare v_uid uuid; v jsonb; v_eski text;
begin
  select id into v_uid from auth.users limit 1;
  if v_uid is null then raise notice '203: kullanici yok — atlandi'; return; end if;
  select value #>> '{}' into v_eski from beta_settings where key = 'otp_demo_mode';

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  delete from otp_tokens where user_id = v_uid;
  update beta_settings set value = to_jsonb('yes'::text) where key = 'otp_demo_mode';
  v := public.send_otp('+905551112233');
  if v ->> 'demo_code' is null then
    raise exception '203: demo acikken kod DONMEDI → %', v;
  end if;

  delete from otp_tokens where user_id = v_uid;
  update beta_settings set value = to_jsonb('no'::text) where key = 'otp_demo_mode';
  v := public.send_otp('+905551112233');
  if v ? 'demo_code' then
    raise exception '203: demo KAPALIYKEN kod hala donuyor → %', v;
  end if;

  delete from otp_tokens where user_id = v_uid;
  update beta_settings set value = to_jsonb(coalesce(v_eski,'yes')) where key = 'otp_demo_mode';
  perform set_config('request.jwt.claims', '', true);
  raise notice '203: otp_demo_mode anahtari GERCEKTEN calisiyor (kod acikken var, kapaliyken yok)';
end $$;

-- 7) TELEFON DOĞRULAMA ZİNCİRİ UÇTAN UCA — kod üret, kodu doğrula
-- 🔴 6. nöbetçi send_otp'un ÇALIŞTIĞINI kanıtlıyor; bu nöbetçi
-- verify_otp'un da aynı kodu KABUL ETTİĞİNİ kanıtlıyor. İkisi ayrı
-- fonksiyon, ayrı search_path — birini düzeltip diğerini unutmak tam
-- da bu hatanın ortaya çıkış biçimiydi.
do $$
declare v_uid uuid; v jsonb; v_kod text; v_son jsonb; v_eski text;
        v_tel text; v_tel2 text; v_dog boolean;
begin
  select id into v_uid from auth.users limit 1;
  if v_uid is null then raise notice '203: kullanici yok — atlandi'; return; end if;
  select value #>> '{}' into v_eski from beta_settings where key = 'otp_demo_mode';
  -- Nöbetçi seed'i BOZMAZ: telefon ve doğrulama işareti geri yazılır.
  select phone, phone_e164 into v_tel, v_tel2 from users where id = v_uid;
  select phone_verified into v_dog from verifications where user_id = v_uid;
  update beta_settings set value = to_jsonb('yes'::text) where key = 'otp_demo_mode';

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  delete from otp_tokens where user_id = v_uid;
  v := public.send_otp('+905559998877');
  v_kod := v ->> 'demo_code';
  if v_kod is null then raise exception '203: send_otp kod uretmedi → %', v; end if;

  v_son := public.verify_otp('+905559998877', v_kod);
  if coalesce(v_son ->> 'ok','') <> 'true' then
    raise exception '203: verify_otp dogru kodu REDDETTI → %', v_son;
  end if;

  delete from otp_tokens where user_id = v_uid;
  update beta_settings set value = to_jsonb(coalesce(v_eski,'yes')) where key = 'otp_demo_mode';
  update users set phone = v_tel, phone_e164 = v_tel2 where id = v_uid;
  update verifications set phone_verified = coalesce(v_dog,false) where user_id = v_uid;
  perform set_config('request.jwt.claims', '', true);
  raise notice '203: telefon dogrulama zinciri UCTAN UCA calisiyor (uret → dogrula)';
end $$;

select '203 OK - sinir veri oldu, ayricalik yukselmesi kapandi, dogrulama kanita baglandi' as sonuc;
