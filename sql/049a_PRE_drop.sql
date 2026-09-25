-- ============================================================
-- LoungeLink · 049a_PRE_drop.sql — 049'dan ÖNCE çalıştır
-- discover_* imzaları AYNI (drop şart değil) ama ileride tekrar
-- düzenlenirse birikme olmasın diye yeni fonksiyonların olası eski
-- sürümleri temizlenir.
-- ============================================================
drop function if exists public.phone_in_use(text);
drop function if exists public.delete_my_account();
select '049a OK' as sonuc;
