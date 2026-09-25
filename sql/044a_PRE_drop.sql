-- ============================================================
-- 044a — 044'TEN ÖNCE ÇALIŞTIR
--
-- 044 discover_people'ın dönüş tablosuna kolon ekliyor (purpose,
-- same_purpose, airport). "create or replace" dönüş tipi değişince
-- 42P13 "cannot change return type" verir → düşürmek şart.
-- ============================================================
drop function if exists public.discover_people(text);
drop function if exists public.discover_people(text, date);
