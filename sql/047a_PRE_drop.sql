-- ============================================================
-- LoungeLink · 047a_PRE_drop.sql — 047'den ÖNCE çalıştır
-- send_campaign'e p_user_ids parametresi ekleniyor. create or replace
-- imza değişince ESKİ sürümü DÜŞÜRMEZ → overload birikir → PostgREST
-- "could not choose the best candidate function". Bu yüzden önce drop.
-- ============================================================
drop function if exists public.send_campaign(text, text, jsonb, uuid);
select '047a OK — eski send_campaign düşürüldü' as sonuc;
