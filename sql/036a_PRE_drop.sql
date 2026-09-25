-- =====================================================================
-- 036a · ÖN-TEMİZLİK — 036'dan ÖNCE çalıştır
-- Yeni fonksiyonlar ama dönüş tipi/imza değişirse 42P13 vermesin.
-- =====================================================================
drop function if exists public.apply_for_host(text, int, text) cascade;
drop function if exists public.my_host_application() cascade;
drop function if exists public.review_host_application(uuid, boolean, text) cascade;
drop function if exists public.admin_update_profile(uuid, jsonb) cascade;

select 'PRE-DROP 036a OK — simdi 036 calistir' as sonuc;
