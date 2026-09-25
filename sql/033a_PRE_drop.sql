-- =====================================================================
-- 033a · ÖN-TEMİZLİK — 033'ten ÖNCE çalıştır
--
-- NEDEN: "create or replace function" imza veya dönüş tipi değişince
-- eskiyi SİLMEZ → 42P13 hatası, ya da sessizce overload birikir →
-- PostgREST "Could not choose the best candidate function" der.
-- Bu dosya 033'ün dokunacağı fonksiyonların eski sürümlerini siler.
--
-- GÜVENLİ: hepsi "if exists" — yoksa hata vermez.
-- 033 zaten hepsini yeniden oluşturur.
-- =====================================================================

-- recompute_badge: 032'de returns text, ara sürümde void denendi → temizle
drop function if exists public.recompute_badge(uuid) cascade;

-- create_request: 007(3 param) / 009 / 026(4 param) overload'ları
drop function if exists public.create_request(uuid, text, text) cascade;
drop function if exists public.create_request(uuid, text, text, text) cascade;

-- create_availability: eski imzalar
drop function if exists public.create_availability(uuid, text, date, time, time, int) cascade;
drop function if exists public.create_availability(uuid, text, date, time without time zone, time without time zone, int) cascade;

-- trust: yeni fonksiyonlar, eski sürüm varsa temizle
drop function if exists public.recompute_trust(uuid) cascade;
drop function if exists public.trg_profile_trust() cascade;
drop function if exists public.trg_profile_trust_v() cascade;

-- beta kredi fonksiyonları
drop function if exists public.grant_signup_credits(uuid) cascade;
drop function if exists public.admin_credit_adjust(uuid, int, text) cascade;
drop function if exists public.admin_bulk_credit(int, text, text) cascade;

select 'PRE-DROP 033a OK — simdi 033 calistir' as sonuc;
