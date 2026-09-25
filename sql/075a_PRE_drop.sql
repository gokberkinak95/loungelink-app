-- ============================================================
-- LoungeLink · 075a_PRE_drop.sql   (075'TEN ÖNCE ÇALIŞTIR)
-- invitable_guests'in dönüş tablosu değişiyor (profession, sessions_count
-- eklendi). PostgreSQL RETURN TABLE yapısını CREATE OR REPLACE ile
-- değiştirmeye izin vermez (42P13) — önce DROP gerekir.
-- ============================================================
drop function if exists public.invitable_guests(uuid);
select '075a OK - eski invitable_guests dusuruldu, simdi 075 calistir' as sonuc;
