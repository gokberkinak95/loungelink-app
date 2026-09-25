-- ============================================================
-- LoungeLink · 087a_PRE_drop.sql        (087'DEN HEMEN ÖNCE ÇALIŞTIR)
-- 087, entitlement_health() ve lounge_access_decision_v2()'yi TANIMLAR;
-- ayrıca 086'nın lounge_access_decision'ının dönüş içeriğine program_id
-- ekler. İmza değişmediği için create or replace yeter, ama tekrar
-- çalıştırmalarda eski aşırı yüklemeler kalmasın diye temizleniyor.
-- ============================================================
drop function if exists public.entitlement_health();
drop function if exists public.lounge_access_decision_v2(uuid, text);
drop function if exists public.entitlement_remaining(uuid);
drop function if exists public.pending_field_report(uuid);
select '087a OK - simdi 087 calistirilabilir' as sonuc;
