-- =====================================================================
-- 038 · SQL DURUM TABLOSU — hangi dosya çalıştı, hangisi çalışmadı?
--
-- Hiçbir şeyi DEĞİŞTİRMEZ, sadece okur. İstediğin zaman çalıştırabilirsin.
-- Her dosyanın veritabanında bıraktığı "iz" aranır (tablo, view, fonksiyon,
-- politika veya veri). İz varsa dosya çalışmıştır.
--
-- PRE_drop dosyaları listede YOK — onlar yalnızca DROP yapar, iz bırakmazlar.
-- Onları eşlik ettikleri dosyadan hemen önce çalıştır:
--   024a→024 · 026a→026 · 033a→033 · 035a→035 · 036a→036
-- =====================================================================
select * from (values
  ( 1, '001_initial_schema.sql', 'tablo', 'otp_tokens',
     case when to_regclass('public.otp_tokens') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 2, '002_seed_reference.sql', 'veri', 'airports satiri var mi',
     case when (select count(*) from airports) > 0
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 3, '003_admin_roles.sql', 'tablo', 'admin_roles',
     case when to_regclass('public.admin_roles') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 4, '004_auth_bridge.sql', 'fonksiyon', 'handle_new_user',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handle_new_user')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 5, '005_reference_read.sql', 'policy', 'lounges_read_all',
     case when exists (select 1 from pg_policies where tablename='lounges')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 6, '006_discovery_read.sql', 'policy', 'profiles_read_auth',
     case when exists (select 1 from pg_policies where policyname='profiles_read_auth')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 7, '007_request_engine.sql', 'fonksiyon', 'respond_request',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='respond_request')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 8, '008_chat_sessions.sql', 'fonksiyon', 'rate_session',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='rate_session')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  ( 9, '009_phone_otp.sql', 'fonksiyon', 'create_request',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_request')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (10, '010_profile_write.sql', 'policy', 'profiles_self_update',
     case when exists (select 1 from pg_policies where policyname='profiles_self_update')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (11, '011_notifications.sql', 'policy', 'notif_own_read',
     case when exists (select 1 from pg_policies where policyname='notif_own_read')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (12, '012_women_safety.sql', 'fonksiyon', 'discover_availabilities',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_availabilities')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (13, '013_push_tokens.sql', 'tablo', 'push_tokens',
     case when to_regclass('public.push_tokens') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (14, '014_push_trigger.sql', 'fonksiyon', 'notify_push',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='notify_push')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (15, '015_connections.sql', 'fonksiyon', 'discover_people',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_people')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (16, '016_match_score.sql', 'fonksiyon', 'discover_availabilities',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_availabilities')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (17, '017_marketplace.sql', 'tablo', 'redemptions',
     case when to_regclass('public.redemptions') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (18, '018_subscriptions.sql', 'tablo', 'plan_catalog',
     case when to_regclass('public.plan_catalog') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (19, '019_admin_management.sql', 'fonksiyon', 'admin_adjust_points',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='admin_adjust_points')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (20, '020_rbac.sql', 'fonksiyon', 'remove_admin',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='remove_admin')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (21, '021_moderation_tools.sql', 'fonksiyon', 'admin_set_trust',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='admin_set_trust')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (22, '022_rewards_parity.sql', 'veri', '8+ odul var mi',
     case when (select count(*) from rewards) >= 8
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (23, '023_partner_portal.sql', 'tablo', 'lounge_partners',
     case when to_regclass('public.lounge_partners') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (24, '024_avatars_storage.sql', 'fonksiyon', 'discover_people',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_people')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (25, '025_role_on_signup.sql', 'fonksiyon', 'handle_new_user',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handle_new_user')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (26, '026_doc_parity_core.sql', 'fonksiyon', 'change_phone',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='change_phone')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (27, '027_companion_chat.sql', 'fonksiyon', 'my_connections',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='my_connections')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (28, '028_referral.sql', 'fonksiyon', 'apply_referral',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='apply_referral')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (29, '029_bo_requirements.sql', 'tablo', 'rule_thresholds',
     case when to_regclass('public.rule_thresholds') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (30, '030_match_and_broadcast.sql', 'fonksiyon', 'discover_availabilities',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_availabilities')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (31, '031_cleanup_overloads.sql', 'temizlik', 'overload yok (turetilmis)',
     case when not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_request','discover_availabilities','discover_people','respond_connection') group by p.proname having count(*) > 1)
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (32, '032_p2_flows.sql', 'view', 'report_sla',
     case when to_regclass('public.report_sla') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (33, '033_beta_credits_dualrole_radar.sql', 'tablo', 'beta_settings',
     case when to_regclass('public.beta_settings') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (34, '034_lounge_radar.sql', 'tablo', 'blocks',
     case when to_regclass('public.blocks') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (35, '035_password_flow.sql', 'fonksiyon', 'upsert_admin',
     case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='upsert_admin')
          then '✓ CALISTI' else '❌ CALISMADI' end),
  (36, '036_host_applications.sql', 'tablo', 'host_applications',
     case when to_regclass('public.host_applications') is not null
          then '✓ CALISTI' else '❌ CALISMADI' end)
) as t("#", "dosya", "iz turu", "aranan iz", "durum");
