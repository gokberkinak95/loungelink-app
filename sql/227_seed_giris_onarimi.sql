-- ============================================================================
-- LoungeLink · 227_seed_giris_onarimi.sql                  (20 Ağustos 2026)
--
-- SEED HESAPLARIYLA GİRİŞ YAPILAMIYORDU — BENİM HATAM
--
-- Gökberk: "bu hesaplar ve şifre ile login olmaya çalıştığımda app'de
-- e-posta veya şifre hatalı alıyorum."
--
-- 🔴 KÖK SEBEP: Supabase'de bir kullanıcının ŞİFREYLE GİRİŞ YAPABİLMESİ
-- için üç şey gerekir; SEED3 yalnız birincisini yapıyordu.
--
--   1) auth.users.encrypted_password  → bcrypt hash        ✅ vardı
--   2) auth.users'ın GoTrue alanları  → aud, role,
--      instance_id, raw_app_meta_data ve SEKİZ token kolonu ('' olmalı,
--      NULL değil — GoTrue bunları Go'da `string`e okur, NULL'da patlar)
--                                                            ❌ YOKTU
--   3) auth.identities satırı (provider='email')             ❌ YOKTU
--
-- GoTrue v2'den beri şifreli giriş KİMLİK SATIRINI arar. O satır yoksa
-- şifre doğru olsa bile "Invalid login credentials" döner. Gökberk'in
-- gördüğü mesaj tam olarak buydu.
--
-- 🔴 EN CAN SIKICI TARAFI: DOĞRUSUNU ZATEN YAZMIŞIM.
-- `SEED_KURAL_SENARYOLARI.sql` (birinci seed) üçünü de yapıyor —
-- GoTrue alanları için ayrı bir update, identities için ayrı bir blok.
-- SEED3'ü yazarken oradan değil, SEED2'den kopyalamışım; SEED2 de
-- eksikmiş. Dosyanın içindeki yorum bile "şifre kurgusu birinci
-- seed'den kopyalanıyor" diyor — ama kopyalanan yalnız HASH'ti,
-- KABLOLAMA değil.
--
-- 🆕 SINIF: **"KOPYALARKEN NEYİ KOPYALADIĞINI SÖYLEMEK, KOPYALADIĞINI
-- KANITLAMAZ."** Yorum "birinci seed'den alındı" diyordu ve bu cümle
-- doğru olduğu için kimse (ben dahil) eksik olanı aramadı.
--
-- 🔴 HARNESS BUNU NEDEN YAKALAMADI — dürüst cevap:
-- `pg_run.py` Supabase'i TAKLİT ediyor: `auth.users` elle kurulmuş bir
-- tablo, `auth.identities` boş bir tablo, GoTrue ise HİÇ YOK. Yani
-- "bu hesapla giriş yapılabiliyor mu" sorusu harness'te SORULAMIYOR.
-- 255 dosya temiz derken bu sınıfı hiç ölçmemiştim. Aşağıdaki nöbetçi
-- ölçebileceğim kadarını ölçüyor (hash doğrulaması + alanlar + kimlik
-- satırı); gerçek GoTrue girişini yalnız sen doğrulayabilirsin.
--
-- BU DOSYA TÜM SEED HESAPLARINI ONARIR — host1..guest2 dahil, birinci
-- ve ikinci seed'inkiler dahil. Şifre hepsinde: Seed1234!
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- 1) ŞİFRE — hepsine yeniden yazılır, koşulsuz
--
-- Eski kurgu `where encrypted_password is null` diyordu; yani bir kez
-- yanlış bir hash yazıldıysa bir daha DÜZELTİLEMİYORDU. Onarım dosyası
-- koşullu olamaz.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_sql text;
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where p.proname = 'crypt' and n.nspname = 'extensions') then
    v_sql := 'update auth.users set encrypted_password = '
             || 'extensions.crypt($1, extensions.gen_salt(''bf'')) '
             || 'where email like ''%@seed.loungelink.test''';
  elsif exists (select 1 from pg_proc where proname = 'crypt') then
    v_sql := 'update auth.users set encrypted_password = crypt($1, gen_salt(''bf'')) '
             || 'where email like ''%@seed.loungelink.test''';
  else
    raise exception '227: pgcrypto YOK — sifre yazilamaz. Supabase Dashboard -> '
                    'Database -> Extensions -> pgcrypto ac, sonra 227''yi tekrar calistir.';
  end if;
  execute v_sql using 'Seed1234!';
  raise notice '227: sifre yazildi (Seed1234!) — % hesap',
    (select count(*) from auth.users where email like '%@seed.loungelink.test');
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 2) GoTrue ALANLARI — yalnız GERÇEKTEN VAR OLAN kolonlara yazılır
--
-- 🔴 Birinci seed bu kolonları DÜZ yazıyor (`is_sso_user = ...`). Supabase
-- sürümleri arasında bu kolonların bir kısmı olmayabilir ve o zaman
-- dosya 42703 ile patlar. Burada kolon listesi `information_schema`'dan
-- OKUNUYOR: olmayan kolona yazmaya çalışmıyoruz.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_set text := '';
  v_kolon text;
  -- token kolonlari: GoTrue bunlari Go'da `string` olarak okur.
  -- NULL geldiginde giris akisi patlar; bos dizgi olmalari SART.
  v_bos_dizgi text[] := array[
    'confirmation_token','recovery_token','email_change',
    'email_change_token_new','email_change_token_current',
    'phone_change','phone_change_token','reauthentication_token'];
begin
  foreach v_kolon in array v_bos_dizgi loop
    if exists (select 1 from information_schema.columns
                where table_schema='auth' and table_name='users' and column_name=v_kolon) then
      v_set := v_set || format('%I = coalesce(%I, ''''), ', v_kolon, v_kolon);
    end if;
  end loop;

  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='users' and column_name='instance_id') then
    v_set := v_set || 'instance_id = coalesce(instance_id, ''00000000-0000-0000-0000-000000000000''::uuid), ';
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='users' and column_name='is_sso_user') then
    v_set := v_set || 'is_sso_user = coalesce(is_sso_user, false), ';
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='users' and column_name='raw_user_meta_data') then
    v_set := v_set || 'raw_user_meta_data = coalesce(raw_user_meta_data, ''{}''::jsonb), ';
  end if;

  v_set := v_set
    || 'aud = coalesce(aud, ''authenticated''), '
    || 'role = coalesce(role, ''authenticated''), '
    || 'email_confirmed_at = coalesce(email_confirmed_at, now()), '
    || 'created_at = coalesce(created_at, now()), '
    || 'updated_at = now(), '
    || 'raw_app_meta_data = coalesce(raw_app_meta_data, ''{"provider":"email","providers":["email"]}''::jsonb)';

  execute 'update auth.users set ' || v_set
          || ' where email like ''%@seed.loungelink.test''';
  raise notice '227: GoTrue alanlari dolduruldu';
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 3) KİMLİK SATIRI — asıl eksik olan buydu
--
-- GoTrue v2 şifreli girişte `auth.identities` içinde provider='email'
-- satırı arar. Yoksa şifre DOĞRU olsa bile "Invalid login credentials".
-- ════════════════════════════════════════════════════════════════════════
do $$
declare v_n int;
begin
  if not exists (select 1 from information_schema.tables
                  where table_schema='auth' and table_name='identities') then
    raise notice '227: auth.identities tablosu yok — atlaniyor';
    return;
  end if;

  insert into auth.identities (user_id, provider_id, identity_data, provider,
                               last_sign_in_at, created_at, updated_at)
  select u.id, u.id::text,
         jsonb_build_object('sub', u.id::text, 'email', u.email,
                            'email_verified', true, 'phone_verified', false),
         'email', now(), now(), now()
    from auth.users u
   where u.email like '%@seed.loungelink.test'
     and not exists (select 1 from auth.identities i
                      where i.user_id = u.id and i.provider = 'email');
  get diagnostics v_n = row_count;
  raise notice '227: % eksik kimlik satiri olusturuldu', v_n;
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ — "yazdım" demek yetmez, DOĞRULANIR
--
-- Üç şeyi ayrı ayrı ölçer ve biri bile tutmazsa DURUR:
--   (a) hash gerçekten 'Seed1234!' ile doğrulanıyor mu (bcrypt round-trip)
--   (b) aud/role dolu mu
--   (c) kimlik satırı var mı
--
-- (a) en önemlisi: `encrypted_password` dolu olmak, ŞİFRENİN DOĞRU
-- olduğunu göstermez. Eski kurgu hash'i başka bir hesaptan kopyalıyordu;
-- o hesabın şifresi farklı olsaydı hepsi sessizce yanlış olurdu.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_kripto text;
  v_kotu text := '';
  r record;
  v_ok boolean;
  v_n int;
begin
  v_kripto := case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                                 where p.proname='crypt' and n.nspname='extensions')
                   then 'extensions.crypt' else 'crypt' end;

  for r in select id, email, encrypted_password, aud, role
             from auth.users where email like '%@seed.loungelink.test' order by email
  loop
    -- (a) bcrypt round-trip
    execute format('select ($1 = %s($2, $1))', v_kripto)
      into v_ok using r.encrypted_password, 'Seed1234!';
    if not coalesce(v_ok, false) then
      v_kotu := v_kotu || r.email || '(sifre-dogrulanmadi) ';
      continue;
    end if;
    -- (b) GoTrue alanlari
    if coalesce(r.aud,'') <> 'authenticated' or coalesce(r.role,'') <> 'authenticated' then
      v_kotu := v_kotu || r.email || '(aud/role-eksik) ';
      continue;
    end if;
    -- (c) kimlik satiri
    if exists (select 1 from information_schema.tables
                where table_schema='auth' and table_name='identities')
       and not exists (select 1 from auth.identities i
                        where i.user_id = r.id and i.provider = 'email') then
      v_kotu := v_kotu || r.email || '(kimlik-satiri-yok) ';
    end if;
  end loop;

  if v_kotu <> '' then
    raise exception '227: SU HESAPLARLA GIRIS YAPILAMAZ -> %', v_kotu;
  end if;

  -- 🔴 HİÇBİR ŞEY ÖLÇMEYEN NÖBETÇİ YEŞİL YANMAMALI.
  -- Temiz kurulumda 227, SEED dosyalarından ÖNCE çalışır; o anda ortada
  -- tek bir seed hesabı yoktur ve döngü sıfır kez döner. "Hepsi hazır"
  -- demek o durumda YALAN olurdu. Sayıyı söylüyoruz.
  select count(*) into v_n from auth.users where email like '%@seed.loungelink.test';
  if v_n = 0 then
    raise notice '227: ORTADA SEED HESABI YOK — olcum YAPILMADI. '
                 'Bu dosyayi SEED''lerden SONRA calistir (asil kullanimi budur).';
  else
    raise notice '227: % seed hesabinin hepsi giris icin hazir (sifre + alanlar + kimlik)', v_n;
  end if;
end $$;


-- Ekrana özet: hangi hesap, hangi rol, kimlik satırı var mı.
select u.email,
       (select r2.role from public.users r2 where r2.id = u.id) as app_rolu,
       (u.aud = 'authenticated' and u.role = 'authenticated')   as gotrue_alanlari,
       exists (select 1 from auth.identities i
                where i.user_id = u.id and i.provider = 'email') as kimlik_satiri
  from auth.users u
 where u.email like '%@seed.loungelink.test'
 order by u.email;

select '227 OK — sifre Seed1234! · butun seed hesaplari giris yapabilir' as sonuc;
