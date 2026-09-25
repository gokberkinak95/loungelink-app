-- 037a · ÖN-TEMİZLİK — 037_admin_verifications'tan ÖNCE çalıştır
drop function if exists public.admin_set_verification(uuid, text, boolean) cascade;
select 'PRE-DROP 037a OK' as sonuc;
