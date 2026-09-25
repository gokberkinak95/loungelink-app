-- ============================================================================
-- LoungeLink · 187a_PRE_asiri_yukleme_temizligi.sql      (18 Agustos 2026)
--
-- 🔴 NE ICIN VAR
-- 187'nin sonundaki bekci sunu diyor:
--     ERROR: 187: 1 fonksiyonda asiri yukleme kalintisi var
-- Bekci ayni anda `raise warning` ile HANGI fonksiyon oldugunu da yaziyor,
-- ama Supabase SQL Editor uyarilari gostermiyor — yalniz hatayi. Yani
-- bekci dogru calisiyor, sadece SESSIZ.
--
-- Sebep: bu veritabani turlar boyunca birikti. Gecmis bir turda bir
-- fonksiyon FARKLI bir arguman listesiyle olusturuldu, sonraki turda
-- imza degisti ve `create or replace` ESKISINI SILMEZ — PostgreSQL onu
-- AYRI bir fonksiyon sayar. Sonuc iki imza. PostgREST bu durumda
-- "could not choose a best candidate function" diyip app'i kirar; 187
-- tam da bunu onlemek icin durduruyor.
--
-- Sifirdan kurulan bir veritabaninda bu durum OLUSMAZ: 001-187'yi bos bir
-- PostgreSQL'de bastan sona calistirdim (208 dosya) ve cift imzali
-- fonksiyon SIFIR cikti. Yani bu bir kaynak hatasi degil, BIRIKMIS DURUM.
--
-- 🔴 NASIL CALISIR — TAHMIN YOK, REFERANS VAR
-- Asagidaki liste, 001-187 sirasiyla temiz kurulan bir veritabanindan
-- OLCULEREK alindi: 218 fonksiyonun ad + arguman imzasi. Bu dosya:
--   1. Yalniz BIRDEN COK imzasi olan adlara dokunur.
--   2. O adin referanstaki imzasini KORUR.
--   3. Referansta OLMAYAN imzalari duşurur.
--   4. Referansta hic bulunmayan bir ad gorurse DOKUNMAZ, uyarir.
-- Hicbir sey "muhtemelen fazladir" diye silinmez.
--
-- KULLANIM: 187'den ONCE calistir. Sonra 187 normal gecer.
-- ============================================================================

do $temizlik$
declare
  r        record;
  f        record;
  v_dusen  int := 0;
  v_uyari  int := 0;
  v_grup   int := 0;
begin
  create temp table _ref_imza (ad text, args text) on commit drop;
  insert into _ref_imza (ad, args) values
    ('access_source_summary', 'p_source text'),
    ('active_campaigns', ''),
    ('admin_adjust_credit', 'p_user uuid, p_delta integer, p_reason text'),
    ('admin_adjust_points', 'p_user uuid, p_delta integer, p_reason text'),
    ('admin_anonymize_user', 'p_user_id uuid, p_admin text, p_reason text'),
    ('admin_bulk_credit', 'p_delta integer, p_note text, p_role text'),
    ('admin_create_campaign', 'p_title text, p_description text, p_ends date, p_admin uuid'),
    ('admin_create_promo_code', 'p_code text, p_type text, p_amount integer, p_max integer, p_expires date, p_admin uuid'),
    ('admin_credit_adjust', 'p_user uuid, p_delta integer, p_note text'),
    ('admin_delete_availability', 'p_id uuid, p_hard boolean, p_reason text'),
    ('admin_delete_visit', 'p_id uuid'),
    ('admin_has_permission', 'p_user uuid, p_module text'),
    ('admin_list_visits', 'p_airport text, p_from date, p_limit integer'),
    ('admin_purge_test_data', 'p_before date, p_dry_run boolean'),
    ('admin_set_email', 'p_user uuid, p_email text'),
    ('admin_set_phone', 'p_user uuid, p_phone text'),
    ('admin_set_trust', 'p_user uuid, p_score integer, p_badge text'),
    ('admin_set_verification', 'p_user uuid, p_field text, p_value boolean'),
    ('admin_update_profile', 'p_user uuid, p_patch jsonb'),
    ('alternatives_for', 'p_avail_id uuid'),
    ('amenities_for', 'p_ids uuid[]'),
    ('anonymized_users', ''),
    ('apply_field_consensus', ''),
    ('apply_for_host', 'p_access_source text, p_guest_capacity integer, p_note text'),
    ('apply_referral', 'p_code text'),
    ('apply_rule_engine', 'p_user uuid'),
    ('apply_rule_snapshot', 'p_avail_id uuid'),
    ('assign_partner', 'p_email text, p_lounge_id uuid, p_role text'),
    ('autofill_venue_acceptance', 'p_venue_id uuid, p_dry_run boolean'),
    ('availability_rule_snapshot', 'p_avail_id uuid'),
    ('badge_text', 'p_key text'),
    ('best_entitlement', 'p_venue_id uuid, p_program_codes text[], p_tier text, p_carrier text, p_cabin text'),
    ('bo_error_summary', 'p_days integer'),
    ('cancel_availability', 'p_id uuid'),
    ('cancel_request', 'p_request_id uuid, p_reason text'),
    ('cancel_session', 'p_session_id uuid, p_reason text'),
    ('card_advice_for_airport', 'p_airport text'),
    ('card_advice_for_lounge', 'p_lounge_id uuid'),
    ('card_confidence_note', 'p_user_id uuid'),
    ('card_product_active_now', 'p_card_id uuid'),
    ('card_product_options', ''),
    ('card_self_check', 'p_user_id uuid'),
    ('card_tier_label', 'p_tier text'),
    ('card_tier_options', 'p_program_code text'),
    ('carrier_from_flight', 'p_flight text'),
    ('carrier_match', 'p_host_carrier text, p_guest_carrier text, p_coupling text'),
    ('carrier_options', ''),
    ('change_phone', 'p_phone text'),
    ('change_plan', 'p_plan plan_type'),
    ('charter_note', 'p_avail_id uuid'),
    ('claim_founding_host', ''),
    ('clip_text', 'p_text text, p_max integer'),
    ('compute_trust_badge', 'score integer'),
    ('confirm_session', 'p_session_id uuid'),
    ('create_availability', 'p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text'),
    ('create_report', 'p_target uuid, p_type text, p_description text, p_session uuid'),
    ('create_request_impl', 'p_avail_id uuid, p_type text, p_intro text, p_idem text'),
    ('create_request', 'p_avail_id uuid, p_type text, p_intro text, p_idem text'),
    ('decision_chain_check', ''),
    ('declare_phone', 'p_phone text'),
    ('defer_rating', 'p_session uuid'),
    ('delete_my_account', ''),
    ('determinism_check', ''),
    ('device_flow_check', ''),
    ('disable_push_token', 'p_token text'),
    ('discover_availabilities_base', 'p_airport text, p_sector text, p_flight text, p_date date'),
    ('discover_availabilities', 'p_airport text, p_sector text, p_flight text, p_date date'),
    ('discover_people', 'p_airport text, p_date date'),
    ('discovery_rule_badges', 'p_ids uuid[]'),
    ('entitlement_health', ''),
    ('entitlement_remaining', 'p_entitlement_id uuid'),
    ('entry_cost_note', 'p_program_id uuid, p_tier text'),
    ('expire_stale_sessions', ''),
    ('field_consensus', 'p_venue_id uuid, p_program_id uuid'),
    ('flag_enabled', 'p_key text'),
    ('flight_fetch_allow', 'p_user_id uuid, p_flight text, p_day date'),
    ('flight_info', 'p_flight_no text, p_date date'),
    ('flight_lookup', 'p_flight_no text, p_date date'),
    ('flight_quota_report', ''),
    ('flow_env_block', 'p_err text'),
    ('flow_gate_test', ''),
    ('flow_test_cleanup', 'p_ids uuid[]'),
    ('founding_badge_sync', ''),
    ('founding_host_status', ''),
    ('grant_consents', 'p_types text[], p_version text'),
    ('grant_signup_credits', 'p_user uuid'),
    ('guard_otp_bypass', ''),
    ('guest_carrier_for', 'p_avail_id uuid'),
    ('guest_flight_fits', 'p_avail_id uuid, p_flight_no text'),
    ('guest_quota_note', 'p_host_id uuid'),
    ('guide_airports', ''),
    ('guide_cost', 'p_program_code text, p_tier text'),
    ('guide_hosts_today', 'p_airport text, p_date date'),
    ('guide_lounges', 'p_airport text, p_program_code text, p_tier text, p_carrier text, p_cabin text'),
    ('guide_programs', ''),
    ('handle_new_user', ''),
    ('has_active_session', ''),
    ('home_connections', ''),
    ('host_declares_paid_guest', 'p_host uuid'),
    ('host_requests', ''),
    ('host_unused_rights', 'p_user uuid'),
    ('invitable_guests', 'p_avail_id uuid'),
    ('is_blocked_pair', 'p_a uuid, p_b uuid'),
    ('is_contact_verified', 'p_user uuid'),
    ('is_visible', 'p_user uuid'),
    ('join_campaign', 'p_id uuid'),
    ('log_client_error', 'p_screen text, p_message text, p_code text, p_version text, p_platform text, p_context jsonb'),
    ('lounge_access_decision_v2', 'p_avail_id uuid, p_guest_flight text'),
    ('lounge_access_decision_v3', 'p_avail_id uuid, p_guest_flight text'),
    ('lounge_access_decision_v4', 'p_avail_id uuid, p_guest_flight text'),
    ('lounge_access_decision_v5', 'p_avail_id uuid, p_guest_flight text, p_guest_carrier text'),
    ('lounge_access_decision', 'p_avail_id uuid, p_guest_flight text'),
    ('lounge_hint_for_host', 'p_lounge_id uuid'),
    ('lounge_radar_count', ''),
    ('lounge_radar_people', ''),
    ('lounge_rules_health', ''),
    ('lounges_for_airport', 'p_airport text'),
    ('mark_email_verified', ''),
    ('mark_password_changed', ''),
    ('match_deletion_requests', ''),
    ('match_program_by_text', 'p_text text'),
    ('mixed_case_check', ''),
    ('multi_entitlement_check', ''),
    ('my_availabilities', ''),
    ('my_connections', ''),
    ('my_host_access', ''),
    ('my_host_application', ''),
    ('my_quota_line', ''),
    ('my_referral', ''),
    ('my_reports', ''),
    ('my_sent_requests', ''),
    ('my_visits', ''),
    ('needs_password_change', 'p_user uuid'),
    ('notify_push', ''),
    ('open_dispute', 'p_session uuid, p_reason text, p_detail text'),
    ('otp_attempt_ok', ''),
    ('paid_guest_credit', 'p_avail_id uuid'),
    ('parse_host_entitlements', 'p_user_id uuid'),
    ('partner_demand', 'p_lounge_id uuid'),
    ('partner_payout', 'p_lounge_id uuid, p_from date, p_to date'),
    ('pending_actions', ''),
    ('pending_field_report', 'p_user_id uuid'),
    ('pending_ratings', ''),
    ('phone_in_use', 'p_phone text'),
    ('pick_host_program', 'p_host uuid, p_venue_id uuid'),
    ('program_needs_tier', 'p_program_id uuid'),
    ('prune_rate_limits', ''),
    ('publish_availability', 'p_airport text, p_lounge_id uuid, p_lounge_name text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text'),
    ('rate_ok', 'p_action text, p_limit integer, p_hours integer'),
    ('rate_session', 'p_session_id uuid, p_score integer, p_comment text'),
    ('rebuild_rule_test_cases', ''),
    ('recompute_badge', 'p_user uuid'),
    ('recompute_trust', 'p_user uuid'),
    ('redeem_promo_code', 'p_code text'),
    ('redeem_reward', 'p_reward_id uuid'),
    ('remove_admin', 'p_user uuid'),
    ('remove_rating', 'p_rating_id uuid'),
    ('request_account_deletion', 'p_email text, p_reason text'),
    ('request_precheck', 'p_avail_id uuid'),
    ('resolve_dispute', 'p_dispute uuid, p_decision text, p_admin uuid'),
    ('resolve_guest_rule', 'p_program_id uuid, p_venue_id uuid, p_tier text, p_carrier text, p_cabin text'),
    ('resolve_report', 'p_report_id uuid, p_status text, p_resolution text, p_resolver uuid'),
    ('resolve_venue_for_availability', 'p_avail_id uuid'),
    ('respond_connection', 'p_id uuid, p_accept boolean'),
    ('respond_invite', 'p_id uuid, p_accept boolean'),
    ('respond_request', 'p_request_id uuid, p_action text'),
    ('review_host_application', 'p_id uuid, p_approve boolean, p_note text'),
    ('rl_guard', ''),
    ('rl_limit', 'p_key text, p_default integer'),
    ('rpc_smoke_test', ''),
    ('rule_contamination_check', ''),
    ('rule_coverage_audit', ''),
    ('rule_full_report_v2', ''),
    ('rule_full_report', ''),
    ('rule_matrix_check', ''),
    ('rule_matrix_summary', ''),
    ('rule_matrix_test', 'p_only_fail boolean'),
    ('rule_notice', 'p_key text'),
    ('rule_venue_test', 'p_only_fail boolean'),
    ('rules_expiring', 'p_days integer'),
    ('save_host_access', 'p_sources text[], p_guest_capacity smallint, p_guest_fee_expected boolean, p_quota_total smallint, p_quota_period text, p_quota_used smallint, p_card_product_id uuid, p_card_tier text'),
    ('save_push_token', 'p_token text, p_platform text'),
    ('send_campaign', 'p_title text, p_body text, p_segment jsonb, p_admin uuid, p_user_ids uuid[]'),
    ('send_connection', 'p_to uuid, p_intent text, p_intro text'),
    ('send_invite', 'p_guest uuid, p_avail_id uuid, p_note text'),
    ('send_otp', 'p_phone text'),
    ('set_availability_carrier', 'p_avail_id uuid, p_carrier text'),
    ('set_availability_charter', 'p_avail_id uuid, p_is_charter boolean'),
    ('set_featured_reward', 'p_reward_id uuid'),
    ('set_featured', 'p_avail_id uuid'),
    ('set_visit_carrier', 'p_visit_id uuid, p_carrier text'),
    ('set_visit_charter', 'p_visit_id uuid, p_is_charter boolean'),
    ('share_session_status', 'p_session_id uuid, p_status text'),
    ('short_detail', 'p_parts text[], p_max integer'),
    ('sos_alert', 'p_note text'),
    ('start_session_request', 'p_request_id uuid'),
    ('start_session', 'p_request_id uuid'),
    ('style_fit', 'p_a text, p_b text'),
    ('style_note', 'p_a text, p_b text'),
    ('submit_field_report', 'p_session_id uuid, p_entered boolean, p_guest_accepted boolean, p_fee_charged boolean, p_fee_amount text, p_quota_left text, p_note text'),
    ('sync_availability_filled', ''),
    ('travel_style_options', ''),
    ('trg_field_report_rollup', ''),
    ('trg_profile_trust_v', ''),
    ('trg_profile_trust', ''),
    ('trg_session_completed', ''),
    ('trg_settle_paid_guest', ''),
    ('unrated_sessions', ''),
    ('upsert_admin', 'p_email text, p_role text, p_permissions jsonb, p_display_name text, p_must_change boolean'),
    ('uuid_generate_v4', ''),
    ('venue_amenities', 'p_lounge_id uuid'),
    ('venue_norm', 'p_name text'),
    ('venue_partner_count', 'p_lounge_id uuid'),
    ('venue_partners', 'p_lounge_id uuid'),
    ('verification_state', 'p_user uuid'),
    ('verify_email_contact', ''),
    ('verify_otp', 'p_phone text, p_code text'),
    ('waiting_demand', 'p_airport text, p_date date');

  for r in
    select p.proname as ad, count(*) as c
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
     group by p.proname
    having count(*) > 1
    order by p.proname
  loop
    v_grup := v_grup + 1;

    if not exists (select 1 from _ref_imza x where x.ad = r.ad) then
      -- 🔴 BILMEDIGIM BIR AD. Silmek yerine SOYLE. Bu dosyanin en
      --    tehlikeli davranisi, tanimadigi bir seyi "fazlalik" saymak olurdu.
      raise warning '187a: % adinin % imzasi var ama bu ad referansta YOK — DOKUNMUYORUM. Elle bak.',
        r.ad, r.c;
      v_uyari := v_uyari + 1;
      continue;
    end if;

    raise notice '187a: % — % imza bulundu, referansa gore ayikliyorum', r.ad, r.c;

    for f in
      select p.oid::regprocedure as imza,
             pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.prokind = 'f' and p.proname = r.ad
    loop
      if exists (select 1 from _ref_imza x where x.ad = r.ad and x.args = f.args) then
        raise notice '187a:   KORUNDU  %', f.imza;
      else
        raise notice '187a:   DUSURULDU %', f.imza;
        -- RESTRICT (varsayilan): bir sey buna BAGLIYSA hata versin.
        -- CASCADE yazsaydim, bagimli bir view/fonksiyon sessizce silinir
        -- ve kayip ancak app kirildiginda fark edilirdi.
        execute 'drop function ' || f.imza::text;
        v_dusen := v_dusen + 1;
      end if;
    end loop;
  end loop;

  if v_grup = 0 then
    raise notice '187a: cift imzali fonksiyon YOK — yapacak is yok';
  else
    raise notice '187a: % adda % fazla imza dusuruldu (% ad dokunulmadan birakildi)',
      v_grup, v_dusen, v_uyari;
  end if;

  if v_uyari > 0 then
    raise exception '187a: % fonksiyon referansta yok, elle karar gerekiyor (yukaridaki WARNING satirlarina bak; Supabase gostermiyorsa bu dosyayi psql ile calistir)', v_uyari;
  end if;
end
$temizlik$;

-- ── DOGRULAMA: 187'nin bekcisiyle AYNI sorgu ─────────────────────────
do $dogrula$
declare v_kalan int;
begin
  select count(*) into v_kalan from (
    select p.proname from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
     group by p.proname having count(*) > 1) t;
  if v_kalan > 0 then
    raise exception '187a: hala % adda cift imza var — 187 yine duracak', v_kalan;
  end if;
  raise notice '187a: temiz ✓ artik 187 calistirilabilir';
end
$dogrula$;
