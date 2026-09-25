-- ============================================================
-- LoungeLink · 024a_PRE_drop_old_discovery.sql
-- ⚠ 024'TEN **ÖNCE** ÇALIŞTIR
--
-- NEDEN: 024, discover_availabilities ve discover_people'a "photo" kolonu
-- ekliyor → fonksiyonun DÖNÜŞ TİPİ değişiyor. Postgres, mevcut bir
-- fonksiyonun dönüş tipini "create or replace" ile değiştirmeye izin vermez:
--   ERROR 42P13: cannot change return type of existing function
--   HINT: Use DROP FUNCTION ... first
--
-- ÇÖZÜM: eski sürümleri düşür. Sonra 024'ü çalıştır.
-- Bu dosya idempotenttir (fonksiyon yoksa sessiz geçer).
-- ============================================================

-- Eski keşif fonksiyonlarının TÜM imzaları
drop function if exists public.discover_availabilities(text);
drop function if exists public.discover_availabilities(text, text);
drop function if exists public.discover_availabilities(text, text, text);
drop function if exists public.discover_availabilities(text, text, text, date);

drop function if exists public.discover_people(text);
drop function if exists public.discover_people(text, text);

-- Doğrulama: geriye hiç kalmamalı (bos sonuc = dogru)
select p.proname, pg_get_function_identity_arguments(p.oid) as imza
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('discover_availabilities','discover_people');

-- Bos dondu mu? Simdi 024'u calistir.
