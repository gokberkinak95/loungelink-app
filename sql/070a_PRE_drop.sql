-- ============================================================
-- LoungeLink · 070a_PRE_drop.sql   (070'DEN ÖNCE ÇALIŞTIR)
-- discover_people'in donus tablosu degisiyor (visit_date, flight_number,
-- same_flight eklendi). PostgreSQL RETURN TABLE yapisini CREATE OR REPLACE
-- ile degistirmeye izin vermez (42P13) - once DROP gerekir.
-- ============================================================
drop function if exists public.discover_people(text, date);
select '070a OK - eski discover_people dusuruldu, simdi 070 calistir' as sonuc;
