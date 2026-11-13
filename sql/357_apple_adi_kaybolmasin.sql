-- ============================================================================
-- 357 · APPLE İLE GİRENİN ADI KAYBOLMASIN  (13 Kasım 2026)
--
-- BULGU (Gökberk, Tanış): Apple ile giren bir kullanıcı "k8n7fdvv2c" diye görünüyor
-- (e-postası k8n7fdvv2c@privaterelay.appleid.com — "E-postamı gizle"). Bir başkası da
-- "ardaeyuboglu" (ardaeyuboglu@icloud.com).
--
-- KÖK (ölçüldü, kod):
--   · Apple adı YALNIZ İLK GİRİŞTE ve yalnız cihaza verir; kimlik jetonunda ad yoktur →
--     auth.users.raw_user_meta_data'da ad yok.
--   · handle_new_user adı bulamayınca e-postanın @ öncesini yazıyor: "k8n7fdvv2c".
--   · Uygulama (social.js) Apple'ın verdiği adı profile YALNIZ ad boşsa ya da '@' içeriyorsa
--     yazıyor. Ad "k8n7fdvv2c" (dolu, @ yok) → gerçek ad HİÇ YAZILMIYOR ve Apple bir daha vermiyor.
--
-- DÜZELTME (APP SÜRÜMÜ GEREKMEZ — 1.0.1 zaten adı yazmaya hazır, yalnız boş bulması lazım):
--   §1 profiles'a BEFORE INSERT tetikleyicisi: kayıt Apple'dan geliyor, ad bilgisi yok ve ad
--      e-postadan türetilmişse ad BOŞ ('') açılır → uygulama Apple'ın verdiği adı yazar.
--      handle_new_user'a (6 dosyada tanımlı) DOKUNULMAZ.
--   §2 Güvenlik ağı (her 10 dk): Apple adı hiç vermediyse (kullanıcı adı silip paylaştıysa)
--      10 dakikadan eski boş ad doldurulur: gizli Apple adresinde 'Gezgin', diğerlerinde
--      e-postanın @ öncesi (eski davranış). Kullanıcı Profil'den değiştirebilir.
--   §0 ÖLÇÜM: e-postadan türetilmiş adla duran gerçek kullanıcılar (salt okunur liste).
--   Mevcut hesaplara DOKUNULMAZ: Apple onların adını bir daha vermez; düzeltme kullanıcının
--   kendisinde (Profil › düzenle). Bildirim göndermek ayrı karar (Gökberk).
--
-- KOŞMA: SQL Editor → tamamı → Run. Tekrar koşulabilir. Son tablo sonuçtur.
-- ============================================================================

-- §1 · Apple kaydında adı boş aç (uygulama gerçek adı yazsın)
create or replace function public.trg_apple_adi_bos_ac()
returns trigger language plpgsql security definer set search_path = public as $ab357$
declare v_email text; v_saglayici text; v_meta jsonb;
begin
  select au.email, au.raw_app_meta_data->>'provider', coalesce(au.raw_user_meta_data, '{}'::jsonb)
    into v_email, v_saglayici, v_meta
    from auth.users au where au.id = new.user_id;
  if v_saglayici = 'apple'
     and coalesce(nullif(trim(v_meta->>'name'), ''), nullif(trim(v_meta->>'full_name'), '')) is null
     and v_email is not null
     and new.name = split_part(v_email, '@', 1) then
    new.name := '';
  end if;
  return new;
end $ab357$;

drop trigger if exists apple_adi_bos_ac on profiles;
create trigger apple_adi_bos_ac before insert on profiles
  for each row execute function public.trg_apple_adi_bos_ac();

-- §2 · güvenlik ağı: 10 dakikadır boş kalan ad
create or replace function public.bos_adlari_doldur()
returns int language plpgsql security definer set search_path = public as $bd357$
declare n int;
begin
  if auth.uid() is not null then raise exception 'not_authorized'; end if;
  update profiles p
     set name = case when u.email ilike '%@privaterelay.appleid.com' or coalesce(u.email, '') = ''
                     then 'Gezgin' else split_part(u.email, '@', 1) end
    from users u
   where u.id = p.user_id
     and btrim(coalesce(p.name, '')) = ''
     and u.created_at < now() - interval '10 minutes';
  get diagnostics n = row_count;
  return n;
end $bd357$;
revoke all on function public.bos_adlari_doldur() from public, anon, authenticated;

do $c357$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-bos-ad-doldur') then
      perform cron.unschedule('ll-bos-ad-doldur');
    end if;
    perform cron.schedule('ll-bos-ad-doldur', '*/10 * * * *', 'select public.bos_adlari_doldur()');
  end if;
end $c357$;

-- yardımcı: cron şeması olmayan ortamda da düşmeden sorar
create or replace function public.cron_isi_var_mi_357(p_ad text)
returns text language plpgsql security definer set search_path = public as $cv357$
declare v boolean;
begin
  if to_regclass('cron.job') is null then return 'cron yok'; end if;
  execute 'select exists (select 1 from cron.job where jobname = $1)' into v using p_ad;
  return v::text;
end $cv357$;
revoke all on function public.cron_isi_var_mi_357(text) from public, anon, authenticated;

-- §3 · SONUÇ: tetikleyici + iş kurulu mu, ve e-postadan türetilmiş adla duran gerçek hesaplar
select 'tetikleyici_kurulu' as kontrol,
       exists (select 1 from pg_trigger where tgname = 'apple_adi_bos_ac' and not tgisinternal)::text as deger
union all
select 'zamanli_is_kurulu', public.cron_isi_var_mi_357('ll-bos-ad-doldur')
union all
select 'eposta_adli_gercek_hesap: ' || coalesce(au.raw_app_meta_data->>'provider', '?'), count(*)::text
  from profiles p join users u on u.id = p.user_id join auth.users au on au.id = u.id
 where p.name = split_part(u.email, '@', 1)
   and not public.seed_test_hesabi(u.email)
   and not coalesce(u.is_staff, false)
   and u.deleted_at is null
 group by au.raw_app_meta_data->>'provider';
