-- ============================================================
-- LoungeLink · 081a_PRE_drop.sql   (081'DEN ÖNCE ÇALIŞTIR)
-- pending_ratings'in dönüş tablosu değişiyor (request_id, other_id eklendi).
-- PostgreSQL RETURN TABLE yapısını CREATE OR REPLACE ile değiştirmeye izin
-- vermez (42P13) — önce DROP gerekir.
-- ============================================================
drop function if exists public.pending_ratings();
select '081a OK - eski pending_ratings dusuruldu, simdi 081 calistir' as sonuc;
