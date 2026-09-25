-- ============================================================
-- LoungeLink · 048a_PRE_drop.sql — 048'den ÖNCE çalıştır
-- 048 yeni fonksiyonlar tanımlar; yalnız apply_referral'in dönüş
-- gövdesi zenginleşiyor (imza aynı) — drop gerekmez. Bu dosya
-- ileride 048 tekrar düzenlenirse overload birikmesin diye
-- yeni fonksiyonların olası eski sürümlerini temizler.
-- ============================================================
drop function if exists public.active_campaigns();
drop function if exists public.join_campaign(uuid);
drop function if exists public.redeem_promo_code(text);
drop function if exists public.admin_create_campaign(text, text, date, uuid);
drop function if exists public.admin_create_promo_code(text, text, int, int, date, uuid);
select '048a OK' as sonuc;
