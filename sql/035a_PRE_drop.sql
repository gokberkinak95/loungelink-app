-- =====================================================================
-- 035a · ÖN-TEMİZLİK — 035'ten ÖNCE çalıştır
-- upsert_admin'e p_must_change eklendi → imza değişti → eskisi silinmeli
-- =====================================================================
drop function if exists public.upsert_admin(text, text, jsonb, text) cascade;
drop function if exists public.upsert_admin(text, text, jsonb, text, boolean) cascade;
drop function if exists public.upsert_admin(text, text, text[], text) cascade;
drop function if exists public.needs_password_change(uuid) cascade;
drop function if exists public.mark_password_changed() cascade;

select 'PRE-DROP 035a OK — simdi 035 calistir' as sonuc;
