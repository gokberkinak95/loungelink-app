-- ============================================================
-- LoungeLink · 059a_PRE_drop.sql   (059'DAN ÖNCE ÇALIŞTIR)
--
-- discover_people'ın dönüş tablosu değişiyor (can_request, req_reason eklendi).
-- PostgreSQL var olan bir fonksiyonun RETURN TABLE yapısını CREATE OR REPLACE
-- ile değiştirmene izin vermez (hata 42P13). Önce DROP gerekir.
-- ============================================================

drop function if exists public.discover_people(text, date);

select '059a OK — eski discover_people dusuruldu, simdi 059 calistir' as sonuc;
