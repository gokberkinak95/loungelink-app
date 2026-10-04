-- ============================================================================
-- 315 · BO RAPOR FONKSİYONLARI UYGULAMA KULLANICISINA KAPALI  (4 Ekim 2026)
--
-- 🔴 BULGU (uçtan uca test · be_yetki_tarama.py): BO'nun yalnız SERVİS ROLÜYLE
-- (sbAdmin) çağırdığı 15 rapor fonksiyonu `authenticated` rolüne de açıktı ve
-- gövdelerinde yönetici kapısı yoktu. Hepsi SECURITY DEFINER (RLS'i aşar).
-- Sonuç: giriş yapmış HERHANGİ bir uygulama kullanıcısı kendi telefonundan
-- BO'nun iç raporlarını okuyabiliyordu — ölçüldü (Gökberk hesabıyla):
--   host_credit_stats      → kredi ekonomisi, istek/kabul/oturum dönüşümü
--   odul_surdurulebilirlik → "ödül maliyeti abonelik gelirini aşıyor" iç notu
--   venue_review_list      → salon kopya şüphesi kuyruğu (iç notlar)
--   entitlement_health     → kart ürünü doğrulama açıkları
--
-- DÜZELTME: EXECUTE yalnız service_role'de kalır. BO bu fonksiyonları zaten
-- yalnız sbAdmin() (service_role) ile çağırıyor (be_bo_istemci.py ile ölçüldü),
-- yani BO'da hiçbir ekran değişmez.
--
-- Partner portalının oturumla çağırdığı beş fonksiyon (partner_payout,
-- venue_gate_report, venue_price_position, venue_program_mix,
-- venue_rule_compliance) BU DOSYADA DEĞİL: gövdeleri partner yetkisini
-- denetliyor — yetkisiz kullanıcıya boş sonuç + "yetkiniz yok" döndükleri
-- ölçüldü.
--
-- Ek temizlik: baglanti_kaldir anonime açıktı (gövde not_authenticated ile
-- duruyordu — zararsız) · anon hakkı da geri alındı.
--
-- Supabase SQL Editor: her ifade ayrı işlemde koşar; dosya tekrar koşulabilir.
-- ============================================================================

do $$
declare
  f record;
  adlar text[] := array[
    'cabin_rule_reach', 'cns_bekleyenler', 'cns_kapsam_haritasi', 'entitlement_health',
    'esik_etkisi', 'flight_quota_report', 'host_credit_stats', 'lounge_rules_health',
    'match_program_by_text', 'odul_surdurulebilirlik', 'rule_full_report', 'rule_full_report_v2',
    'rules_expiring', 'venue_duplicate_suspects', 'venue_review_list'];
  n int := 0;
begin
  for f in
    select p.oid::regprocedure as imza
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public' and p.proname = any(adlar)
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.imza);
    execute format('grant execute on function %s to service_role', f.imza);
    n := n + 1;
  end loop;
  raise notice '315: % rapor fonksiyonu yalniz service_role', n;
end $$;

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as imza
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public' and p.proname = 'baglanti_kaldir'
  loop
    execute format('revoke execute on function %s from public, anon', f.imza);
    execute format('grant execute on function %s to authenticated, service_role', f.imza);
  end loop;
end $$;

-- ── DOĞRULAMA (Editor'de sonuç tablosu olarak görünür) ──────────────────────
select p.proname as fonksiyon,
       has_function_privilege('authenticated', p.oid, 'execute') as kullanici_cagirabilir,
       has_function_privilege('anon', p.oid, 'execute')          as anonim_cagirabilir,
       has_function_privilege('service_role', p.oid, 'execute')  as bo_cagirabilir
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
 where ns.nspname = 'public'
   and p.proname in ('cabin_rule_reach','cns_bekleyenler','cns_kapsam_haritasi','entitlement_health',
                     'esik_etkisi','flight_quota_report','host_credit_stats','lounge_rules_health',
                     'match_program_by_text','odul_surdurulebilirlik','rule_full_report','rule_full_report_v2',
                     'rules_expiring','venue_duplicate_suspects','venue_review_list','baglanti_kaldir')
 order by 1;
-- Beklenen: 15 rapor satırında kullanici_cagirabilir=false, anonim_cagirabilir=false, bo_cagirabilir=true;
--           baglanti_kaldir: kullanici=true, anonim=false.
