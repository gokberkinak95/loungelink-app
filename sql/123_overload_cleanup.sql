-- ============================================================
-- LoungeLink · 123_overload_cleanup.sql
-- ASIRI YUKLEMELERI TEMIZLE — AMA ONCE HANGISININ ETKIN OLDUGUNU DOGRULA
--
-- ⚠️ Uygulamayi ETKILER (fonksiyon silme).
--
-- ------------------------------------------------------------
-- NEDEN
-- ------------------------------------------------------------
-- returns_check bes fonksiyonun IKI SURUMUNUN birden durdugunu
-- soyluyor. PostgreSQL imzalar farkli oldugu icin hata vermez, ikisini
-- de tutar. Ama PostgREST bir gun "Could not choose the best candidate
-- function" der — ve o gun HANGI cagrinin bozuldugunu bulmak cok zordur.
--
-- 🔴 109'DA BU ISI YAPARKEN AZ KALSIN AKISI KIRIYORDUM:
-- respond_connection'in "eskisini" dusurecektim, dosya numarasina
-- bakip 027'yi yeni sandim — DOGRUYDU ama imzayi ters okuyup
-- (uuid, boolean) olani dusurmustum. Oysa app TAM ONU cagiriyor.
--
-- Bu yuzden bu dosyada her silme icin ONCE APP'IN CAGRISI yazili.
-- Kaynak dosya numarasi degil, GERCEK KULLANIM belirler.
-- ============================================================

-- app: rpc("discover_availabilities", { p_airport, p_sector, p_flight, p_date })
-- ETKIN: (text, text, text, date)  ·  ESKI: (text, text, text)
drop function if exists public.discover_availabilities(text, text, text);

-- app: rpc("respond_connection", { p_id, p_accept: true })  -> boolean
-- ETKIN: (uuid, boolean)  ·  ESKI: (uuid, text)
drop function if exists public.respond_connection(uuid, text);

-- app: rpc("pending_ratings")  -> parametresiz
-- Parametreli eski surumu varsa dusur.
drop function if exists public.pending_ratings(uuid);

-- app: rpc("card_product_options")  -> parametresiz
drop function if exists public.card_product_options(text);

-- ---- DOGRULAMA: her fonksiyondan GERIYE TEK IMZA kalmali ----
select p.proname,
       count(*) as imza_sayisi,
       string_agg(pg_get_function_identity_arguments(p.oid), ' | ') as imzalar
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('discover_availabilities','respond_connection',
                     'pending_ratings','card_product_options','create_availability')
 group by p.proname order by 2 desc, 1;

select '123 OK - asiri yuklemeler temizlendi (app cagrilari korundu)' as sonuc;
