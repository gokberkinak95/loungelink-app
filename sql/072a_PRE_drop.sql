-- ============================================================
-- LoungeLink · 072a_PRE_drop.sql   (072'DEN ONCE CALISTIR)
-- discover_availabilities'in donus tablosu degisiyor (host_gender, host_langs).
-- PostgreSQL RETURN TABLE yapisini CREATE OR REPLACE ile degistirmeye izin
-- vermez (42P13) - once DROP gerekir.
-- ============================================================
drop function if exists public.discover_availabilities(text, text, text, date);
select '072a OK - eski discover_availabilities dusuruldu, simdi 072 calistir' as sonuc;
