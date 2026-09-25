-- ============================================================
-- LoungeLink · 050a_PRE_drop.sql — 050'den ÖNCE çalıştır
-- host_requests'in DÖNÜŞ TABLOSU değişiyor (flight_number eklendi).
-- create or replace dönüş tipini değiştiremez → önce drop (42P13 önlemi).
-- ============================================================
drop function if exists public.host_requests();
select '050a OK' as sonuc;
