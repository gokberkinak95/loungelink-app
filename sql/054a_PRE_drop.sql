-- 054a — 054'ten ÖNCE. discover_people dönüş tablosu değişiyor → önce drop.
drop function if exists public.discover_people(text, date);
drop function if exists public.discover_people(text);
select '054a OK' as sonuc;
