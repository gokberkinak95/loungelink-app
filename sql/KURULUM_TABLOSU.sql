-- ============================================================================
-- LoungeLink · KURULUM_TABLOSU.sql        (2026-11-09 uretildi · 392 dosya · son: 348)
--
-- "HANGİ SQL'LERİ ÇALIŞTIRDIM?" — TEK SORGU, TAM LİSTE
--
-- Gökberk: "bana şu ana kadar hangi sql'leri çalıştırdığımı görebildiğim
-- bir sql kodu verir misin? Çalıştırdığım çalıştırmadığım tüm sql'leri
-- versin bana tabloda çalışıyor çalışmıyor diye."
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE DÜRÜST OLMAM GEREKEN ŞEY: BU PROJEDE MİGRATION DEFTERİ YOK
-- ════════════════════════════════════════════════════════════════════════
-- Dosyalar SQL Editor'e elle yapıştırılıyor ve hangisinin koştuğunu
-- söyleyen HİÇBİR KAYIT tutulmamış. Yani "çalıştı mı?" sorusunun cevabını
-- ancak dosyanın BIRAKTIĞI İZDEN çıkarabiliyorum.
--
-- 🔴 VE BAZI DOSYALAR İZ BIRAKMIYOR. Yalnızca daha önce tanımlanmış bir
-- fonksiyonu yeniden yazan dosya, veritabanında ayırt edilebilir bir şey
-- bırakmayabilir. Bunları "ÇALIŞMADI" diye işaretlemek YALAN olurdu.
--
-- 🆕 SINIF: **"TESPİT EDİLEMEYEN ŞEYİ 'YOK' DİYE RAPORLAMAK, ÖLÇMEDEN
-- TEŞHİS VERMEKTİR."** Tabloda üçüncü bir durum var: **BİLİNMİYOR**.
--
-- ÖLÇÜM: 383 dosyanın 30 tanesi için ayırt edici imza
-- bulundu (%8). Kalan 353 tanesi BİLİNMİYOR olarak
-- raporlanıyor.
--
-- ════════════════════════════════════════════════════════════════════════
-- 13 EYLÜL · BU TABLONUN İKİ KEZ YALAN SÖYLEDİĞİ YER KAPATILDI
-- ════════════════════════════════════════════════════════════════════════
-- 22 Ağustos sürümü bir imzayı "TAM KURULU veritabanında ayakta kalıyor
-- mu" diye seçiyordu. Bu YETMİYOR. 285'e kadar kurulu bir veritabanında
-- denedim ve ÜÇ DOSYA "koştu" dedi — üçü de kurulu değildi:
--   · 286 → izi `discover_people_prebfilter`; o fonksiyon zaten vardı.
--   · 287 → izi `my_plan` gövdesindeki bir satır; eski gövdede de vardı.
--   · 290 → izi "notlarda Türkçe harf var"; öncesinde de 91 satırda vardı.
-- Bir tablonun yapabileceği EN KÖTÜ hata budur: KURULMAMIŞ bir dosyaya
-- "kuruldu" demek. Sen o dosyayı atlarsın, hata günler sonra başka bir
-- yerden çıkar.
--
-- 🆕 SINIF: "BİR İZİN YENİ OLDUĞUNA KAYNAK KODA BAKARAK KARAR VERMEK
-- ÇIKARIMDIR; İZ OLDUĞUNU ANCAK DOSYADAN ÖNCE YOK, SONRA VAR OLDUĞUNU
-- ÖLÇEREK BİLİRSİN."
--
-- Artık her imza 330 dosya TEK TEK kurulurken ÜÇ NOKTADA ölçülüyor:
--     ÖNCE  → yok olmalı   ·  SONRA → var olmalı  ·  SON → hâlâ var olmalı
-- Üçünü birden geçmeyen aday imza sayılmıyor. Bu eleme 222 sahte adayı
-- düşürdü.
--
-- VE BU TABLO ÜÇ DURUMDA SINANDI (`tablo_sina.py`):
--   A · tam kurulu (330 dosya + 6 seed) → 0 «KOSMADI»   ✓
--   B · 285'e kadar kurulu              → 286..294'ün DOKUZU da «KOSMADI»,
--                                         «BURADAN DEVAM ET» = 286        ✓
--   C · bomboş veritabanı               → patlamadan 001'den başlatıyor   ✓
--
-- ════════════════════════════════════════════════════════════════════════
-- NASIL OKUNUR
-- ════════════════════════════════════════════════════════════════════════
--   ✅ KOSTU      → izi veritabanında bulundu
--   ❌ KOSMADI    → izi aranmalıydı, YOK. Bu dosyayı çalıştır.
--   ⬜ BILINMIYOR → ayırt edici iz bırakmıyor; sırası gereği koşmuş olmalı
--
-- 🔴 ASIL BAKACAĞIN SATIR EN ÜSTTE: `>>> BURADAN DEVAM ET <<<`
-- Migration'lar SIRALIDIR. İlk ❌'in olduğu yerden itibaren dosyaları
-- sırayla çalıştır.
--
-- ⚠️ BU DOSYA HİÇBİR ŞEYİ DEĞİŞTİRMEZ — tek yaptığı okumak ve bir
-- DEFTER kurmak (aşağıda). Kaç kez çalıştırırsan çalıştır zararsız.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) BUNDAN SONRASI İÇİN GERÇEK DEFTER
-- ----------------------------------------------------------------------------
-- 🔴 Yukarıdaki tahmin işini bir daha yapmak zorunda kalmayalım diye.
-- Bu tablo bugünden itibaren gerçeği tutar; imza tahmini yalnız GEÇMİŞ
-- için gerekli.
create table if not exists schema_migrations (
  dosya       text primary key,
  kosuldu_at  timestamptz not null default now(),
  kaynak      text default 'tespit'      -- tespit | beyan | dosya
);

-- ----------------------------------------------------------------------------
-- 2) İMZA OKUYUCU
-- ----------------------------------------------------------------------------
-- Her imza tipi için tek bir kontrol. `exception when others then false`
-- BİLEREK: erken bir dosya koşmadıysa aradığımız TABLO bile yoktur ve
-- sorgu patlar — patlaması gereken şey rapor değil, o dosyanın kendisi.
create or replace function public.kurulum_imzasi_var(p_tip text, p_ad text)
returns boolean language plpgsql stable security definer set search_path = public as $kiv$
declare v boolean := false; a text; b text;
begin
  if coalesce(p_tip,'') = '' then return null; end if;
  a := split_part(p_ad, '.', 1);
  b := split_part(p_ad, '.', 2);
  begin
    case p_tip
      when 'tablo' then
        v := to_regclass('public.' || p_ad) is not null;
      when 'tip' then
        v := exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace
                      where n.nspname='public' and t.typname = p_ad);
      when 'enum_degeri' then
        v := exists (select 1 from pg_type t join pg_enum e on e.enumtypid=t.oid
                      where t.typname = a and e.enumlabel = b);
      when 'kolon' then
        v := exists (select 1 from information_schema.columns
                      where table_schema='public' and table_name = a and column_name = b);
      when 'kisit' then
        v := exists (select 1 from pg_constraint where conname = p_ad);
      when 'indeks' then
        v := exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                      where n.nspname='public' and c.relkind='i' and c.relname = p_ad);
      when 'politika' then
        -- 🔴 `schemaname='public'` KOŞULU 024'Ü GÖRÜNMEZ YAPIYORDU: onun
        -- politikaları `storage.objects` üzerinde. Politika adı zaten
        -- tablo başına benzersiz; şemayı şart koşmak kanıt eklemiyor,
        -- yalnız kapsamı daraltıyordu.
        v := exists (select 1 from pg_policies
                      where tablename = split_part(p_ad,'|',1)
                        and policyname = split_part(p_ad,'|',2));
        if not v then   -- `on storage.objects` yazımında tablo adı `objects`
          v := exists (select 1 from pg_policies
                        where policyname = split_part(p_ad,'|',2)
                          and schemaname = split_part(p_ad,'|',1));
        end if;
      when 'tetikleyici' then
        v := exists (select 1 from pg_trigger where tgname = p_ad and not tgisinternal);
      when 'ayar' then
        v := exists (select 1 from beta_settings where key = p_ad);
      when 'ayar_deger' then
        v := exists (select 1 from beta_settings
                      where key = split_part(p_ad,'=',1)
                        and (value #>> '{}') = split_part(p_ad,'=',2));
      when 'rpc_yuzeyi' then
        v := exists (select 1 from rpc_client_surface where fn_name = p_ad);
      when 'fonksiyon' then
        v := exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.proname = p_ad);
      when 'govde' then
        -- 🔴 ÖNCE `like '%…%'` İDİ. LIKE'ta `_` TEK KARAKTER JOKERİDİR ve
        -- bizim izlerimiz `trust_scores ts`, `min_trust` gibi alt çizgi
        -- dolu kod parçaları. Yani iz, olduğundan GEVŞEK eşleşiyordu.
        -- 🆕 SINIF: "JOKER İÇEREN BİR EŞLEŞME, KANIT DEĞİL BENZERLİKTİR."
        v := exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.proname = split_part(p_ad,'|',1)
                        and strpos(p.prosrc, split_part(p_ad,'|',2)) > 0);
      when 'desen_yok' then
        -- Biçim: `tablo|kolon|regex` — desen KALMAMIŞ olmalı.
        -- 🔴 290'IN İZİ BUYDU VE İLK SEÇTİĞİM OLUMLU DESEN SAHTEYDİ:
        -- "notlarda Türkçe harf var" dedim; 290'dan ÖNCE de 91 satırda
        -- vardı (ölçüm: 91/262). 290'ın gerçekten yaptığı şey ASCII'ye
        -- düşmüş biçimleri BİTİRMEK: `UCRETSIZ` 17 satırdan 0'a iniyor.
        -- 🆕 SINIF: "BİR DOSYA BİR ŞEYİ SİLİYORSA, İZİ O ŞEYİN VARLIĞI
        -- DEĞİL YOKLUĞUDUR — OLUMLU İZ ARAMAK YANLIŞ YERE BAKMAKTIR."
        -- 🔴 `split_part(p_ad,'|',3)` DESENİ KESİYORDU. Ayraç `|`, regex
        -- alternasyonu da `|` — «(UCRETSIZ|YURTDISI|ANLASMALI)» deseni
        -- «(UCRETSIZ» olarak okunuyordu ve 290 kurulu olduğu hâlde
        -- "koşmadı" görünüyordu. (Aynı sınıf `satir` tipinde de bir kez
        -- ödenmişti: `tablo.kolon=deger` ayrıştırması.)
        -- 🆕 SINIF: "AYRAÇ, AYIRDIĞI VERİNİN ALFABESİNDE GEÇİYORSA
        -- AYRAÇ DEĞİL TUZAKTIR — SON PARÇAYI BÖLME, GERİ KALANI AL."
        execute format('select not exists (select 1 from public.%I where %I ~ %L)',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2),
                       substr(p_ad, strpos(p_ad,'|')
                                    + strpos(substr(p_ad, strpos(p_ad,'|')+1), '|') + 1)) into v;
      when 'desen' then
        -- Biçim: `tablo|kolon|regex`. Şemayı değil VERİYİ onaran dosyalar
        -- için (290: not metinlerindeki Türkçe harfler geri konuyor).
        -- Ayraç-güvenli: son parça bölünmez (bkz. `desen_yok` notu).
        execute format('select exists (select 1 from public.%I where %I ~ %L)',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2),
                       substr(p_ad, strpos(p_ad,'|')
                                    + strpos(substr(p_ad, strpos(p_ad,'|')+1), '|') + 1)) into v;
      when 'satir' then
        -- 🔴 Biçim: `tablo.kolon=deger`. İlk yazımda `a`/`b`yi noktadan
        -- ayırıp `b`yi kolon sandım — ama `b` hâlâ `kolon=deger`
        -- taşıyordu ve sorgu boş dönüyordu. Tam kurulu veritabanında
        -- "KOSMADI" diyen yanlış negatiflerden biri buydu.
        execute format('select exists (select 1 from public.%I where %I::text = %L)',
                       split_part(p_ad, '.', 1),
                       split_part(split_part(p_ad, '.', 2), '=', 1),
                       split_part(p_ad, '=', 2)) into v;
      when 'sayi' then
        -- Biçim: `tablo|kosul|asgari`. SEED4 gibi "satır SAYISI artıyor"
        -- diye anlaşılan dosyalar için: tek bir ad aramak yetmez.
        execute format('select (select count(*) from public.%I where %s) >= %s',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2), split_part(p_ad,'|',3)) into v;
      when 'kural_notu' then
        -- 🔴 290 NOTLARI TÜRKÇELEŞTİRDİ VE İZLERİ BİÇİM DEĞİŞTİRDİ:
        -- «IC HAT» → «İÇ HAT». Not aynı satır, aynı anlam — ama `=`
        -- tutmuyordu. İki taraf da ASCII'ye katlanarak karşılaştırılıyor.
        -- 🆕 SINIF: "VERİYİ İZ SAYIYORSAN, O VERİNİN BİÇİMİNİ SONRADAN
        -- DEĞİŞTİREN HER DOSYA SENİN İZİNİ DE SİLER."
        execute format(
          'select exists (select 1 from public.%I'
          ' where translate(notes, %L, %L) = translate(%L, %L, %L))',
          split_part(p_ad,'|',1),
          'çğıöşüÇĞİÖŞÜ', 'cgiosuCGIOSU',
          split_part(p_ad,'|',2),
          'çğıöşüÇĞİÖŞÜ', 'cgiosuCGIOSU') into v;
      else
        v := null;
    end case;
  exception when others then
    -- Tablo/kolon henüz yoksa "iz yok" demektir — hata değil, cevap.
    v := false;
  end;
  return v;
end $kiv$;

-- `satir` tipinde ad biçimi `tablo.kolon=deger`; yukarıdaki split_part
-- zinciri onu ayırıyor. Ayrı bir yardımcı yazmak yerine tek yerde
-- tutuluyor ki iki kopya bayatlamasın.

-- ----------------------------------------------------------------------------
-- 3) DEFTERİ TESPİTLE DOLDUR (yalnız eksik olanları; var olanı ezmez)
-- ----------------------------------------------------------------------------
insert into schema_migrations (dosya, kaynak)
select z.dosya, 'tespit'
  from (
    values
  (1, '001_initial_schema.sql', '', ''),
  (2, '002_seed_reference.sql', '', ''),
  (3, '003_admin_roles.sql', '', ''),
  (4, '004_auth_bridge.sql', '', ''),
  (5, '005_reference_read.sql', '', ''),
  (6, '006_discovery_read.sql', '', ''),
  (7, '007_request_engine.sql', '', ''),
  (8, '008_chat_sessions.sql', '', ''),
  (9, '009_phone_otp.sql', '', ''),
  (10, '010_profile_write.sql', '', ''),
  (11, '011_notifications.sql', '', ''),
  (12, '012_women_safety.sql', '', ''),
  (13, '013_push_tokens.sql', '', ''),
  (14, '014_push_trigger.sql', '', ''),
  (15, '015_connections.sql', '', ''),
  (16, '016_match_score.sql', '', ''),
  (17, '017_marketplace.sql', '', ''),
  (18, '018_subscriptions.sql', '', ''),
  (19, '019_admin_management.sql', '', ''),
  (20, '020_rbac.sql', '', ''),
  (21, '021_moderation_tools.sql', '', ''),
  (22, '022_rewards_parity.sql', '', ''),
  (23, '023_partner_portal.sql', '', ''),
  (24, '024a_PRE_drop_old_discovery.sql', 'eslikci', '024_avatars_storage.sql'),
  (25, '024_avatars_storage.sql', '', ''),
  (26, '025_role_on_signup.sql', '', ''),
  (27, '026a_PRE_drop.sql', 'eslikci', '026_doc_parity_core.sql'),
  (28, '026_doc_parity_core.sql', '', ''),
  (29, '027_companion_chat.sql', '', ''),
  (30, '028_referral.sql', '', ''),
  (31, '029_bo_requirements.sql', '', ''),
  (32, '030_match_and_broadcast.sql', '', ''),
  (33, '031_cleanup_overloads.sql', '', ''),
  (34, '032_p2_flows.sql', '', ''),
  (35, '033a_PRE_drop.sql', 'eslikci', '033_beta_credits_dualrole_radar.sql'),
  (36, '033_beta_credits_dualrole_radar.sql', '', ''),
  (37, '034_lounge_radar.sql', '', ''),
  (38, '035a_PRE_drop.sql', 'eslikci', '035_password_flow.sql'),
  (39, '035_password_flow.sql', '', ''),
  (40, '036a_PRE_drop.sql', 'eslikci', '036_host_applications.sql'),
  (41, '036_host_applications.sql', '', ''),
  (42, '037a_PRE_drop.sql', 'eslikci', '037_admin_verifications.sql'),
  (43, '037_admin_verifications.sql', '', ''),
  (44, '038_SQL_DURUM.sql', '', ''),
  (45, '039_DOGRULAMA.sql', '', ''),
  (46, '040a_PRE_drop.sql', 'eslikci', '040_visibility_and_discovery_fix.sql'),
  (47, '040_visibility_and_discovery_fix.sql', '', ''),
  (48, '041_staff_accounts_excluded.sql', '', ''),
  (49, '042_reports_and_sos.sql', '', ''),
  (50, '043_admin_data_cleanup.sql', '', ''),
  (51, '044a_PRE_drop.sql', 'eslikci', '044_trip_purpose_and_people_fix.sql'),
  (52, '044_trip_purpose_and_people_fix.sql', '', ''),
  (53, '045_admin_edit_email_phone.sql', '', ''),
  (54, '046a_PRE_drop.sql', 'eslikci', '046_trust_and_host_visibility.sql'),
  (55, '046_trust_and_host_visibility.sql', '', ''),
  (56, '047a_PRE_drop.sql', 'eslikci', '047_campaign_targets.sql'),
  (57, '047_campaign_targets.sql', '', ''),
  (58, '048a_PRE_drop.sql', 'eslikci', '048_promo_campaigns.sql'),
  (59, '048_promo_campaigns.sql', '', ''),
  (60, '049a_PRE_drop.sql', 'eslikci', '049_discovery_safety_phone_delete.sql'),
  (61, '049_discovery_safety_phone_delete.sql', '', ''),
  (62, '050a_PRE_drop.sql', 'eslikci', '050_host_requests_flight.sql'),
  (63, '050_host_requests_flight.sql', '', ''),
  (64, '051_beta_visibility_reset_and_diagnoz.sql', '', ''),
  (65, '052_session_live_status.sql', '', ''),
  (66, '053_unstaff_founder_and_diag.sql', '', ''),
  (67, '054a_PRE_drop.sql', 'eslikci', '054_discover_people_include_hosts.sql'),
  (68, '054_discover_people_include_hosts.sql', '', ''),
  (69, '055_listing_makes_host.sql', '', ''),
  (70, '056_supply_demand_match_notify.sql', '', ''),
  (71, '057_waiting_demand_rpc.sql', '', ''),
  (72, '058_fix_stale_staff_roles.sql', '', ''),
  (73, '059a_PRE_drop.sql', 'eslikci', '059_discover_everyone_request_gate.sql'),
  (74, '059_discover_everyone_request_gate.sql', '', ''),
  (75, '060_security_hardening.sql', '', ''),
  (76, '061_fix_respond_request_and_slots.sql', '', ''),
  (77, '062_fix_verify_otp.sql', '', ''),
  (78, '063_error_logging.sql', '', ''),
  (79, '064_fix_overloads_and_discovery.sql', '', ''),
  (80, '065_fix_create_request.sql', '', ''),
  (81, '066_request_status_completed.sql', '', ''),
  (82, '067_fix_confirm_session_enum.sql', '', ''),
  (83, '068_fix_rate_session.sql', '', ''),
  (84, '069_fix_respond_connection_cast.sql', '', ''),
  (85, '070a_PRE_drop.sql', 'eslikci', '070_discover_people_trip_data.sql'),
  (86, '070_discover_people_trip_data.sql', '', ''),
  (87, '071_fix_create_availability_enum.sql', '', ''),
  (88, '072a_PRE_drop.sql', 'eslikci', '072_discover_availabilities_gender_langs.sql'),
  (89, '072_discover_availabilities_gender_langs.sql', '', ''),
  (90, '073_fix_seed_login.sql', '', ''),
  (91, '074_host_always_visible.sql', '', ''),
  (92, '075a_PRE_drop.sql', 'eslikci', '075_invitable_guests_detail.sql'),
  (93, '075_invitable_guests_detail.sql', '', ''),
  (94, '076_rewards_mvp_prices.sql', '', ''),
  (95, '077_session_autostart_intro_slots.sql', '', ''),
  (96, '078_trust_single_writer.sql', '', ''),
  (97, '079_email_otp_contact_verification.sql', '', ''),
  (98, '080_session_lifecycle.sql', '', ''),
  (99, '081a_PRE_drop.sql', 'eslikci', '081_pending_ratings_link.sql'),
  (100, '081_pending_ratings_link.sql', '', ''),
  (101, '082_rate_limiting.sql', '', ''),
  (102, '083_lounge_rules_and_flight_prep.sql', '', ''),
  (103, '084_deletion_requests.sql', '', ''),
  (104, '085_lounge_rules_v2.sql', '', ''),
  (105, '086a_PRE_drop.sql', 'eslikci', '086_lounge_rules_v3.sql'),
  (106, '086_lounge_rules_v3.sql', '', ''),
  (107, '087a_PRE_drop.sql', 'eslikci', '087_entitlements_and_coverage.sql'),
  (108, '087_entitlements_and_coverage.sql', '', ''),
  (109, '088_card_catalog.sql', '', ''),
  (110, '089_missing_columns.sql', '', ''),
  (111, '090_rules_to_app.sql', '', ''),
  (112, '091_flight_quota.sql', '', ''),
  (113, '092_host_access_declaration.sql', '', ''),
  (114, '093_reward_featured.sql', '', ''),
  (115, '094_admin_erasure.sql', '', ''),
  (116, '095_close_the_loop.sql', '', ''),
  (117, '096_rule_autofill.sql', '', ''),
  (118, '097_ajet_and_tk_detail.sql', '', ''),
  (119, '098_full_rule_matrix.sql', '', ''),
  (120, '099_card_networks_venue_level.sql', '', ''),
  (121, '100_tier_fee_and_time.sql', '', ''),
  (122, '101_sections_charter_expiry.sql', '', ''),
  (123, '102_badge_wording.sql', '', ''),
  (124, '103_consolidate_and_charter.sql', '', ''),
  (125, '104_tier_rules_program_level.sql', '', ''),
  (126, '105_fee_wording_and_business.sql', '', ''),
  (127, '106_channel_fees_and_bank_deals.sql', '', ''),
  (128, '107_missing_airports.sql', '', ''),
  (129, '108_paid_guest_settlement.sql', '', ''),
  (130, '109_pegasus_and_overloads.sql', '', ''),
  (131, '110_family_abroad.sql', '', ''),
  (132, '111_push_direct_expo.sql', '', ''),
  (133, '112_blocks_in_discovery.sql', '', ''),
  (134, '113_dedupe_and_wording.sql', '', ''),
  (135, '114_card_confidence_visible.sql', '', ''),
  (136, '115_quota_who_says.sql', '', ''),
  (137, '116_badges_gate_and_sort.sql', '', ''),
  (138, '117_carrier_field.sql', '', ''),
  (139, '118_carrier_in_rules.sql', '', ''),
  (140, '119_precheck_v5_and_charter.sql', '', ''),
  (141, '120_human_text.sql', '', ''),
  (142, '121_source_summary.sql', '', ''),
  (143, '122_what_can_i_do.sql', '', ''),
  (144, '123_overload_cleanup.sql', '', ''),
  (145, '124_card_catalog_verified.sql', '', ''),
  (146, '125_saw_plaza_partners.sql', '', ''),
  (147, '126_partners_visible.sql', '', ''),
  (148, '127_ist_tk_from_iga.sql', '', ''),
  (149, '128_iga_lounge_and_conflicts.sql', '', ''),
  (150, '129_conflict_surfaced.sql', '', ''),
  (151, '130_amenities.sql', '', ''),
  (152, '131_card_advisor.sql', '', ''),
  (153, '132_travel_style.sql', '', ''),
  (154, '133_catalog_dedupe.sql', '', ''),
  (155, '134_tier_label_everywhere.sql', '', ''),
  (156, '135_short_and_honest.sql', '', ''),
  (157, '136_otp_honesty.sql', '', ''),
  (158, '137_placeholder_vs_data.sql', '', ''),
  (159, '138_email_otp.sql', '', ''),
  (160, '139_final_polish.sql', '', ''),
  (161, '140_rls_and_ratelimit.sql', '', ''),
  (162, '141_deletion_flow_check.sql', '', ''),
  (163, '142_short_detail_hard.sql', '', ''),
  (164, '143_lounge_guide.sql', '', ''),
  (165, '144_guide_fixes.sql', '', ''),
  (166, '145_null_sort_guard.sql', '', ''),
  (167, '146_tk_official_matrix.sql', '', ''),
  (168, '147_tier_resolver.sql', '', ''),
  (169, '148_rule_matrix_test.sql', '', ''),
  (170, '149_multi_entitlement.sql', '', ''),
  (171, '150_network_rules_and_guard.sql', '', ''),
  (172, '151_deterministic_program_pick.sql', '', ''),
  (173, '152_field_reports_loop.sql', '', ''),
  (174, '153_host_motivation.sql', '', ''),
  (175, '154_membership_tiers.sql', '', ''),
  (176, '155_member_cost_visible.sql', '', ''),
  (177, '156_official_alignment_and_scope.sql', '', ''),
  (178, '157_decision_uses_resolver.sql', '', ''),
  (179, '158_device_findings.sql', '', ''),
  (180, '159_grants_home_flows_request_gate.sql', '', ''),
  (181, '160_catalog_name_dedupe.sql', '', ''),
  (182, '161_venue_merge_and_catalog_truth.sql', '', ''),
  (183, '162_source_truth_and_founder_badge.sql', '', ''),
  (184, '163_unknown_carrier_and_coverage_audit.sql', '', ''),
  (185, '164_business_ticket_and_operator_rules.sql', '', ''),
  (186, '165_prebeta_security.sql', '', ''),
  (187, '166_slot_integrity_and_flow_tests.sql', '', ''),
  (188, '167_rule_expectation_matrix.sql', '', ''),
  (189, '168_carrier_gap_and_paid_entry.sql', '', ''),
  (190, '169_slot_counter_repair.sql', '', ''),
  (191, '170_resolution_order_fix.sql', '', ''),
  (192, '171_full_matrix_and_report.sql', '', ''),
  (193, '172_resolver_full_definition.sql', '', ''),
  (194, '173_showcase_data.sql', '', ''),
  (195, '174_venue_beats_program_rule.sql', '', ''),
  (196, '175_flow_test_cleanup_fix.sql', '', ''),
  (197, '176_flow_test_rate_limit.sql', '', ''),
  (198, '177_official_table_reconciliation.sql', '', ''),
  (199, '178_expectations_single_source.sql', '', ''),
  (200, '179_flow_test_skip_semantics.sql', '', ''),
  (201, '180_flow_test_future_availability.sql', '', ''),
  (202, '181_credit_model_rebalance.sql', '', ''),
  (203, '182_discover_carries_decision.sql', '', ''),
  (204, '183_lounges_rpc_and_grants.sql', '', ''),
  (205, '184_ms_status_language.sql', '', ''),
  (206, '185_device_flow_proofs.sql', '', ''),
  (207, '186_context_for_cards.sql', '', ''),
  (208, '187a_PRE_asiri_yukleme_temizligi.sql', 'eslikci', '187_kanitlanmis_kusurlar.sql'),
  (209, '187_kanitlanmis_kusurlar.sql', '', ''),
  (210, '188_salon_envanteri.sql', '', ''),
  (211, '189_coklu_hak_ve_kaynak_hizalama.sql', '', ''),
  (212, '190_salon_tekillestirme_ve_bolum.sql', '', ''),
  (213, '191_kaynak_celiskileri_ve_bosluklar.sql', '', ''),
  (214, '192a_PRE_charter_tabanda.sql', '', ''),
  (215, '192_on_kontrol_kapi_hizalama.sql', '', ''),
  (216, '193_kart_etiketi_ve_kabin_yazma.sql', '', ''),
  (217, '194_bekleme_listesi.sql', '', ''),
  (218, '195_ucus_alanlari_ve_kod_paylasimi.sql', '', ''),
  (219, '196_plan_ucretleri_ve_celiski_kapanisi.sql', '', ''),
  (220, '197_seyahatin_ucus_bilgisi_dolsun.sql', '', ''),
  (221, '198_thy_ajet_ms_yeniden_dogrulama.sql', '', ''),
  (222, '199_ucus_saati_terminal_ve_katalog.sql', '', ''),
  (223, '200_ulke_sozlugu_tekillestirme.sql', '', ''),
  (224, '201_banka_karti_tek_cerceve.sql', '', ''),
  (225, '202_saat_dilimi_ajet_anahtari_pencere.sql', '', ''),
  (226, '203_guvenlik_siniri.sql', '', ''),
  (227, '204_blok_eylem_sinirinda.sql', '', ''),
  (228, '205_bo_adresi_kendini_kaydeder.sql', '', ''),
  (229, '206_host_motoru.sql', '', ''),
  (230, '207_kopruler_ve_verilen_sozler.sql', '', ''),
  (231, '208_donem_devri_ve_kalibrasyon.sql', '', ''),
  (232, '209_saglayici_modulu.sql', '', ''),
  (233, '210a_PRE_plan_enum.sql', '', ''),
  (234, '210b_PRE_push_dayanikli.sql', '', ''),
  (235, '210_abonelik_push_ve_kapsam.sql', '', ''),
  (236, '211_kart_aglari_kaynaktan.sql', '', ''),
  (237, '212_yonetilen_ayarlar_gercekten_okunuyor.sql', '', ''),
  (238, '213_saglayici_kurumsal_katman.sql', '', ''),
  (239, '214a_PRE_ic_hat_salonlari.sql', 'eslikci', '214_misafir_hakki_kaynaktan.sql'),
  (240, '214_misafir_hakki_kaynaktan.sql', '', ''),
  (241, '215_saglayici_veri_yollari.sql', '', ''),
  (242, '216_hangi_kartimi_kullanayim.sql', '', ''),
  (243, '217_misafir_ucreti_geri.sql', '', ''),
  (244, '218_radar_olu_kolonlar.sql', '', ''),
  (245, '219_kredi_ve_ucret_dili.sql', '', ''),
  (246, '220_plan_katalogu_ve_dil.sql', '', ''),
  (247, '221_hosta_sor.sql', '', ''),
  (248, '222_ucretli_misafir_geri.sql', '', ''),
  (249, '223_sinirlar_dogruyu_soylesin.sql', '', ''),
  (250, '224_borclar_ve_ilan_neden_yok.sql', '', ''),
  (251, '225_planin_sozu_tutulsun.sql', '', ''),
  (252, '226_zamanlanmis_isler.sql', '', ''),
  (253, '227_seed_giris_onarimi.sql', '', ''),
  (254, '228_odul_katalogu_takas_kapaniyor.sql', '', ''),
  (255, '229_odul_teslim_sozu.sql', '', ''),
  (256, '230_host_hikayeleri.sql', '', ''),
  (257, '231_kurucu_cember_sayaci.sql', '', ''),
  (258, '232_rol_kapisi_ve_cuzdan_sizintisi.sql', '', ''),
  (259, '233_statu_listesi_tekillesiyor.sql', '', ''),
  (260, '234_aktif_oturum_kendini_anlatsin.sql', '', ''),
  (261, '235_sordugunu_gorebilmeli.sql', '', ''),
  (262, '236_ust_plan_bir_ay_ucretsiz.sql', '', ''),
  (263, '237_ilan_ve_seyahat_duzenlenebilsin.sql', '', ''),
  (264, '238_cuzdan_ve_soru_dili.sql', '', ''),
  (265, '239_soru_hangi_ilana_ait.sql', '', ''),
  (266, '240_kural_kapida_degil_odada.sql', '', ''),
  (267, '241_supabase_varsayilani_kapatiliyor.sql', '', ''),
  (268, '242_gorunumler_arka_kapi.sql', '', ''),
  (269, '243_one_cikarma_gercekten_calissin.sql', '', ''),
  (270, '244_odul_ekonomisi.sql', '', ''),
  (271, '245_vitrin_gokberkin_listesi.sql', '', ''),
  (272, '246_ekonomi_ayari.sql', '', ''),
  (273, '247_haber_ver.sql', '', ''),
  (274, '248_duzenleme_baglanti_degerlendirme.sql', '', ''),
  (275, '249_is_modeli_ve_soguk_ag.sql', '', ''),
  (276, '250_yaptirim_huni_dil_ve_kapilar.sql', '', ''),
  (277, '251_cron_nobeti_ve_kahya_ayricaligi.sql', '', ''),
  (278, '252_ulasilabilirlik_ve_push_izni.sql', '', ''),
  (279, '253_guvenlik_kapanisi.sql', '', ''),
  (280, '254_urun_bosluklari.sql', '', ''),
  (281, '255_magaza_sartlari.sql', '', ''),
  (282, '256_kredi_satisi_ve_kapida_iade.sql', '', ''),
  (283, '257_push_makbuzlari.sql', '', ''),
  (284, '258_olmayan_kolonlar.sql', '', ''),
  (285, '259_bo_performans_indeksleri.sql', '', ''),
  (286, '260_bo_sunucu_tarafi_toplamlar.sql', '', ''),
  (287, '261_rol_kapisi.sql', '', ''),
  (288, '261a_rol_uyumlama.sql', '', ''),
  (289, '262_seyahat_duzenle_tam.sql', '', ''),
  (290, '263_ana_sayfa_akisi.sql', '', ''),
  (291, '264_push_ve_api_saglik_raporu.sql', '', ''),
  (292, '265_api_yuzeyi_kapanisi.sql', '', ''),
  (293, '266_eksik_bildirimler.sql', '', ''),
  (294, '267_ilan_tablosu_anon_sizintisi.sql', '', ''),
  (295, '268_telefon_tekilligi.sql', '', ''),
  (296, '268a_telefon_cakismasi.sql', '', ''),
  (297, '269_dogrulama_zinciri.sql', '', ''),
  (298, '269a_DOGRULAMA_KONTROL.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (299, '269b_AYNA_FARKI.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (300, '270_test_verisi_gorunur.sql', '', ''),
  (301, '270a_GORUNURLUK.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (302, '270b_NEDEN_SIZIYOR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (303, '270c_KARAR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (304, '270d_HANGI_KATMAN.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (305, '270e_BASE_YAPISI.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (306, '271_kesfet_son_kapi.sql', '', ''),
  (307, '272_parantez_bypassi.sql', '', ''),
  (308, '273_SEED_KAPSAMI.sql', '', ''),
  (309, '274_istek_tavani_kilidi.sql', '', ''),
  (310, '275_kural_kosullari.sql', '', ''),
  (311, '276_push_kanallari.sql', '', ''),
  (312, '277_baglanti_kaldir.sql', '', ''),
  (313, '278_push_kanali_enum.sql', '', ''),
  (314, '279_sogu_baslangic.sql', '', ''),
  (315, '280_kredi_ve_durum_kilidi.sql', '', ''),
  (316, '281_kural_motoru_kapida_dogru.sql', '', ''),
  (317, '282_ban_ve_kvkk_silme.sql', '', ''),
  (318, '283_kural_motoru_on_iki_boyut.sql', '', ''),
  (319, '284_kural_geri_bildirim_dongusu.sql', '', ''),
  (320, '285_kyc_belge_ve_karar.sql', '', ''),
  (321, '286_tanis_cift_satir.sql', '', ''),
  (322, '287_planim_enum_metin_karsilastirma.sql', '', ''),
  (323, '288_guven_esigi_kolonu.sql', '', ''),
  (324, '289_davet_kabulu_mevcut_istek.sql', '', ''),
  (325, '290_kural_notlari_turkce.sql', '', ''),
  (326, '291_ilan_kaldirma_zorlu.sql', '', ''),
  (327, '292_zaman_dilimi_yerel_an.sql', '', ''),
  (328, '293_davet_cift_onay_ve_ilan_geri_cekme.sql', '', ''),
  (329, '294_binis_karti_dogrulama.sql', '', ''),
  (330, '295_ilanin_ikinci_hayati_ve_sayaclar.sql', '', ''),
  (331, '296_hikaye_daveti_erteleme.sql', '', ''),
  (332, '297_yetki_kapilari.sql', '', ''),
  (333, '298_supurge_kisiti_ve_asim_dedektoru.sql', '', ''),
  (334, '299_kredi_kilidi_supurge_sahibi_ve_iade_tutari.sql', '', ''),
  (335, '300_uctan_uca_denetim.sql', '', ''),
  (336, '301_guven_ve_akis_tamamlama.sql', '', ''),
  (337, '302_test_hesaplarini_gorenler.sql', '', ''),
  (338, '303_ertelenen_puan_ana_sayfadan_duser.sql', '', ''),
  (339, '304_kesfet_engelinin_gercek_sebebi.sql', '', ''),
  (340, '305_erisim_kaynagi_etiketleri.sql', '', ''),
  (341, '306_kural_notlari_turkce_tamam.sql', '', ''),
  (342, '307_zarafet_atlama_siniri.sql', '', ''),
  (343, '308_bo_atlama_uyarisi.sql', '', ''),
  (344, '309_kural_tablosu_denetimi_ve_ilan_erisimi.sql', '', ''),
  (345, '310_309_duzeltme_tasiyici_kapisi_guvenlik.sql', '', ''),
  (346, '311_kesfet_ozeti_tek_kaynak.sql', '', ''),
  (347, '312_soru_ilan_bagi_gercekten.sql', '', ''),
  (348, '313_akis_durum_makinesi_bildirim_soru.sql', '', ''),
  (349, '314_soru_yazili_yanit_ve_baglanti.sql', '', ''),
  (350, '315_bo_rapor_fonksiyonlari_kullaniciya_kapali.sql', '', ''),
  (351, '316_bayat_istek_supurgede.sql', '', ''),
  (352, '317_kesfet_olcek.sql', '', ''),
  (353, '318_ana_sayfa_akisi_olcek.sql', '', ''),
  (354, '319_tanis_gorunurluk_olcek.sql', '', ''),
  (355, '320_istek_puani_daraltilmis.sql', '', ''),
  (356, '321_erisim_karari_kart_secimi_belirli.sql', '', ''),
  (357, '322_hesap_silme_calisir_ve_acik_isleri_kapatir.sql', '', ''),
  (358, '323_ilan_ac_saat_ve_kontenjan_kapisi.sql', '', ''),
  (359, '324_tanis_silinmis_yasakli_suzgeci.sql', '', ''),
  (360, '325_seyahat_cakismasi_farkli_havalimani.sql', '', ''),
  (361, '326_kisi_ara_aday_siniri.sql', '', ''),
  (362, '327_tanis_profil_gorunurlugu.sql', '', ''),
  (363, '328_host_tek_yol_bo_onayli_basvuru.sql', '', ''),
  (364, '329_silinen_hesap_14_gun_anonim.sql', '', ''),
  (365, '330_bo_hesabi_geri_al.sql', '', ''),
  (366, '331_soru_kendi_kaydinda.sql', '', ''),
  (367, '332_revenuecat_satin_alma.sql', '', ''),
  (368, '333_magaza_inceleme_hesabi.sql', '', ''),
  (369, '334_ekonomi_ve_icerik_suzgeci.sql', '', ''),
  (370, '335_telefon_firebase_dogrulama.sql', '', ''),
  (371, '336_kabulde_digerleri_geri_cek.sql', '', ''),
  (372, '337_jetset_puan_kredi_kurulus.sql', '', ''),
  (373, '338_odul_erken_erisim_plan_indirimi.sql', '', ''),
  (374, '339_odul_marka_adlari.sql', '', ''),
  (375, '340_jetset_urun_kimlikleri.sql', '', ''),
  (376, '341_ilan_basvurusu_dili.sql', '', ''),
  (377, '342_oturum_baslatma_penceresi.sql', '', ''),
  (378, '343_olmayan_salonlari_gizle.sql', '', ''),
  (379, '344_ucus_onbellegi_temizligi.sql', '', ''),
  (380, '345_kyc_kapanisi_dogrulanmis_profil_kvkk.sql', '', ''),
  (381, '346_esb_primeclass_birlestir.sql', '', ''),
  (382, '347_guvenlik_fraud_kapanisi.sql', '', ''),
  (383, '348_canli_esitleme.sql', '', ''),
  (901, 'SEED_KURAL_SENARYOLARI.sql', 'satir', 'users.email=kmisafir1@seed.loungelink.test'),
  (902, 'SEED2_KAYNAK_SENARYOLARI.sql', 'satir', 'users.email=kaynak1@seed.loungelink.test'),
  (903, 'SEED3_UCTAN_UCA.sql', 'satir', 'users.email=host1@seed.loungelink.test'),
  (904, 'SEED4_KURAL_VITRINI.sql', 'sayi', 'availabilities|host_id in (select id from users where email = ''host1@seed.loungelink.test'')|10'),
  (905, 'SEED5_BASVURU_AKISLARI.sql', 'satir', 'users.email=guest3@seed.loungelink.test'),
  (906, 'SEED6_TEST_DUNYASI.sql', 'satir', 'users.email=deniz@sahne.loungelink.test'),
  (907, 'SEED7_TEZGAH.sql', 'sayi', 'invites|status = ''accepted''|1'),
  (908, 'SEED8_AKIS_TEZGAHI.sql', 'satir', 'users.email=akis.host@seed.loungelink.test'),
  (909, 'SEED9_AKIS_GENIS.sql', 'satir', 'users.email=akis.host3@seed.loungelink.test')
  ) as z(sira, dosya, tip, ad)
 where public.kurulum_imzasi_var(z.tip, z.ad) is true
on conflict (dosya) do nothing;

-- ----------------------------------------------------------------------------
-- 4) TEK SORGU · TEK TABLO
-- ----------------------------------------------------------------------------
with imza(sira, dosya, tip, ad) as (
  values
  (1, '001_initial_schema.sql', '', ''),
  (2, '002_seed_reference.sql', '', ''),
  (3, '003_admin_roles.sql', '', ''),
  (4, '004_auth_bridge.sql', '', ''),
  (5, '005_reference_read.sql', '', ''),
  (6, '006_discovery_read.sql', '', ''),
  (7, '007_request_engine.sql', '', ''),
  (8, '008_chat_sessions.sql', '', ''),
  (9, '009_phone_otp.sql', '', ''),
  (10, '010_profile_write.sql', '', ''),
  (11, '011_notifications.sql', '', ''),
  (12, '012_women_safety.sql', '', ''),
  (13, '013_push_tokens.sql', '', ''),
  (14, '014_push_trigger.sql', '', ''),
  (15, '015_connections.sql', '', ''),
  (16, '016_match_score.sql', '', ''),
  (17, '017_marketplace.sql', '', ''),
  (18, '018_subscriptions.sql', '', ''),
  (19, '019_admin_management.sql', '', ''),
  (20, '020_rbac.sql', '', ''),
  (21, '021_moderation_tools.sql', '', ''),
  (22, '022_rewards_parity.sql', '', ''),
  (23, '023_partner_portal.sql', '', ''),
  (24, '024a_PRE_drop_old_discovery.sql', 'eslikci', '024_avatars_storage.sql'),
  (25, '024_avatars_storage.sql', '', ''),
  (26, '025_role_on_signup.sql', '', ''),
  (27, '026a_PRE_drop.sql', 'eslikci', '026_doc_parity_core.sql'),
  (28, '026_doc_parity_core.sql', '', ''),
  (29, '027_companion_chat.sql', '', ''),
  (30, '028_referral.sql', '', ''),
  (31, '029_bo_requirements.sql', '', ''),
  (32, '030_match_and_broadcast.sql', '', ''),
  (33, '031_cleanup_overloads.sql', '', ''),
  (34, '032_p2_flows.sql', '', ''),
  (35, '033a_PRE_drop.sql', 'eslikci', '033_beta_credits_dualrole_radar.sql'),
  (36, '033_beta_credits_dualrole_radar.sql', '', ''),
  (37, '034_lounge_radar.sql', '', ''),
  (38, '035a_PRE_drop.sql', 'eslikci', '035_password_flow.sql'),
  (39, '035_password_flow.sql', '', ''),
  (40, '036a_PRE_drop.sql', 'eslikci', '036_host_applications.sql'),
  (41, '036_host_applications.sql', '', ''),
  (42, '037a_PRE_drop.sql', 'eslikci', '037_admin_verifications.sql'),
  (43, '037_admin_verifications.sql', '', ''),
  (44, '038_SQL_DURUM.sql', '', ''),
  (45, '039_DOGRULAMA.sql', '', ''),
  (46, '040a_PRE_drop.sql', 'eslikci', '040_visibility_and_discovery_fix.sql'),
  (47, '040_visibility_and_discovery_fix.sql', '', ''),
  (48, '041_staff_accounts_excluded.sql', '', ''),
  (49, '042_reports_and_sos.sql', '', ''),
  (50, '043_admin_data_cleanup.sql', '', ''),
  (51, '044a_PRE_drop.sql', 'eslikci', '044_trip_purpose_and_people_fix.sql'),
  (52, '044_trip_purpose_and_people_fix.sql', '', ''),
  (53, '045_admin_edit_email_phone.sql', '', ''),
  (54, '046a_PRE_drop.sql', 'eslikci', '046_trust_and_host_visibility.sql'),
  (55, '046_trust_and_host_visibility.sql', '', ''),
  (56, '047a_PRE_drop.sql', 'eslikci', '047_campaign_targets.sql'),
  (57, '047_campaign_targets.sql', '', ''),
  (58, '048a_PRE_drop.sql', 'eslikci', '048_promo_campaigns.sql'),
  (59, '048_promo_campaigns.sql', '', ''),
  (60, '049a_PRE_drop.sql', 'eslikci', '049_discovery_safety_phone_delete.sql'),
  (61, '049_discovery_safety_phone_delete.sql', '', ''),
  (62, '050a_PRE_drop.sql', 'eslikci', '050_host_requests_flight.sql'),
  (63, '050_host_requests_flight.sql', '', ''),
  (64, '051_beta_visibility_reset_and_diagnoz.sql', '', ''),
  (65, '052_session_live_status.sql', '', ''),
  (66, '053_unstaff_founder_and_diag.sql', '', ''),
  (67, '054a_PRE_drop.sql', 'eslikci', '054_discover_people_include_hosts.sql'),
  (68, '054_discover_people_include_hosts.sql', '', ''),
  (69, '055_listing_makes_host.sql', '', ''),
  (70, '056_supply_demand_match_notify.sql', '', ''),
  (71, '057_waiting_demand_rpc.sql', '', ''),
  (72, '058_fix_stale_staff_roles.sql', '', ''),
  (73, '059a_PRE_drop.sql', 'eslikci', '059_discover_everyone_request_gate.sql'),
  (74, '059_discover_everyone_request_gate.sql', '', ''),
  (75, '060_security_hardening.sql', '', ''),
  (76, '061_fix_respond_request_and_slots.sql', '', ''),
  (77, '062_fix_verify_otp.sql', '', ''),
  (78, '063_error_logging.sql', '', ''),
  (79, '064_fix_overloads_and_discovery.sql', '', ''),
  (80, '065_fix_create_request.sql', '', ''),
  (81, '066_request_status_completed.sql', '', ''),
  (82, '067_fix_confirm_session_enum.sql', '', ''),
  (83, '068_fix_rate_session.sql', '', ''),
  (84, '069_fix_respond_connection_cast.sql', '', ''),
  (85, '070a_PRE_drop.sql', 'eslikci', '070_discover_people_trip_data.sql'),
  (86, '070_discover_people_trip_data.sql', '', ''),
  (87, '071_fix_create_availability_enum.sql', '', ''),
  (88, '072a_PRE_drop.sql', 'eslikci', '072_discover_availabilities_gender_langs.sql'),
  (89, '072_discover_availabilities_gender_langs.sql', '', ''),
  (90, '073_fix_seed_login.sql', '', ''),
  (91, '074_host_always_visible.sql', '', ''),
  (92, '075a_PRE_drop.sql', 'eslikci', '075_invitable_guests_detail.sql'),
  (93, '075_invitable_guests_detail.sql', '', ''),
  (94, '076_rewards_mvp_prices.sql', '', ''),
  (95, '077_session_autostart_intro_slots.sql', '', ''),
  (96, '078_trust_single_writer.sql', '', ''),
  (97, '079_email_otp_contact_verification.sql', '', ''),
  (98, '080_session_lifecycle.sql', '', ''),
  (99, '081a_PRE_drop.sql', 'eslikci', '081_pending_ratings_link.sql'),
  (100, '081_pending_ratings_link.sql', '', ''),
  (101, '082_rate_limiting.sql', '', ''),
  (102, '083_lounge_rules_and_flight_prep.sql', '', ''),
  (103, '084_deletion_requests.sql', '', ''),
  (104, '085_lounge_rules_v2.sql', '', ''),
  (105, '086a_PRE_drop.sql', 'eslikci', '086_lounge_rules_v3.sql'),
  (106, '086_lounge_rules_v3.sql', '', ''),
  (107, '087a_PRE_drop.sql', 'eslikci', '087_entitlements_and_coverage.sql'),
  (108, '087_entitlements_and_coverage.sql', '', ''),
  (109, '088_card_catalog.sql', '', ''),
  (110, '089_missing_columns.sql', '', ''),
  (111, '090_rules_to_app.sql', '', ''),
  (112, '091_flight_quota.sql', '', ''),
  (113, '092_host_access_declaration.sql', '', ''),
  (114, '093_reward_featured.sql', '', ''),
  (115, '094_admin_erasure.sql', '', ''),
  (116, '095_close_the_loop.sql', '', ''),
  (117, '096_rule_autofill.sql', '', ''),
  (118, '097_ajet_and_tk_detail.sql', '', ''),
  (119, '098_full_rule_matrix.sql', '', ''),
  (120, '099_card_networks_venue_level.sql', '', ''),
  (121, '100_tier_fee_and_time.sql', '', ''),
  (122, '101_sections_charter_expiry.sql', '', ''),
  (123, '102_badge_wording.sql', '', ''),
  (124, '103_consolidate_and_charter.sql', '', ''),
  (125, '104_tier_rules_program_level.sql', '', ''),
  (126, '105_fee_wording_and_business.sql', '', ''),
  (127, '106_channel_fees_and_bank_deals.sql', '', ''),
  (128, '107_missing_airports.sql', '', ''),
  (129, '108_paid_guest_settlement.sql', '', ''),
  (130, '109_pegasus_and_overloads.sql', '', ''),
  (131, '110_family_abroad.sql', '', ''),
  (132, '111_push_direct_expo.sql', '', ''),
  (133, '112_blocks_in_discovery.sql', '', ''),
  (134, '113_dedupe_and_wording.sql', '', ''),
  (135, '114_card_confidence_visible.sql', '', ''),
  (136, '115_quota_who_says.sql', '', ''),
  (137, '116_badges_gate_and_sort.sql', '', ''),
  (138, '117_carrier_field.sql', '', ''),
  (139, '118_carrier_in_rules.sql', '', ''),
  (140, '119_precheck_v5_and_charter.sql', '', ''),
  (141, '120_human_text.sql', '', ''),
  (142, '121_source_summary.sql', '', ''),
  (143, '122_what_can_i_do.sql', '', ''),
  (144, '123_overload_cleanup.sql', '', ''),
  (145, '124_card_catalog_verified.sql', '', ''),
  (146, '125_saw_plaza_partners.sql', '', ''),
  (147, '126_partners_visible.sql', '', ''),
  (148, '127_ist_tk_from_iga.sql', '', ''),
  (149, '128_iga_lounge_and_conflicts.sql', '', ''),
  (150, '129_conflict_surfaced.sql', '', ''),
  (151, '130_amenities.sql', '', ''),
  (152, '131_card_advisor.sql', '', ''),
  (153, '132_travel_style.sql', '', ''),
  (154, '133_catalog_dedupe.sql', '', ''),
  (155, '134_tier_label_everywhere.sql', '', ''),
  (156, '135_short_and_honest.sql', '', ''),
  (157, '136_otp_honesty.sql', '', ''),
  (158, '137_placeholder_vs_data.sql', '', ''),
  (159, '138_email_otp.sql', '', ''),
  (160, '139_final_polish.sql', '', ''),
  (161, '140_rls_and_ratelimit.sql', '', ''),
  (162, '141_deletion_flow_check.sql', '', ''),
  (163, '142_short_detail_hard.sql', '', ''),
  (164, '143_lounge_guide.sql', '', ''),
  (165, '144_guide_fixes.sql', '', ''),
  (166, '145_null_sort_guard.sql', '', ''),
  (167, '146_tk_official_matrix.sql', '', ''),
  (168, '147_tier_resolver.sql', '', ''),
  (169, '148_rule_matrix_test.sql', '', ''),
  (170, '149_multi_entitlement.sql', '', ''),
  (171, '150_network_rules_and_guard.sql', '', ''),
  (172, '151_deterministic_program_pick.sql', '', ''),
  (173, '152_field_reports_loop.sql', '', ''),
  (174, '153_host_motivation.sql', '', ''),
  (175, '154_membership_tiers.sql', '', ''),
  (176, '155_member_cost_visible.sql', '', ''),
  (177, '156_official_alignment_and_scope.sql', '', ''),
  (178, '157_decision_uses_resolver.sql', '', ''),
  (179, '158_device_findings.sql', '', ''),
  (180, '159_grants_home_flows_request_gate.sql', '', ''),
  (181, '160_catalog_name_dedupe.sql', '', ''),
  (182, '161_venue_merge_and_catalog_truth.sql', '', ''),
  (183, '162_source_truth_and_founder_badge.sql', '', ''),
  (184, '163_unknown_carrier_and_coverage_audit.sql', '', ''),
  (185, '164_business_ticket_and_operator_rules.sql', '', ''),
  (186, '165_prebeta_security.sql', '', ''),
  (187, '166_slot_integrity_and_flow_tests.sql', '', ''),
  (188, '167_rule_expectation_matrix.sql', '', ''),
  (189, '168_carrier_gap_and_paid_entry.sql', '', ''),
  (190, '169_slot_counter_repair.sql', '', ''),
  (191, '170_resolution_order_fix.sql', '', ''),
  (192, '171_full_matrix_and_report.sql', '', ''),
  (193, '172_resolver_full_definition.sql', '', ''),
  (194, '173_showcase_data.sql', '', ''),
  (195, '174_venue_beats_program_rule.sql', '', ''),
  (196, '175_flow_test_cleanup_fix.sql', '', ''),
  (197, '176_flow_test_rate_limit.sql', '', ''),
  (198, '177_official_table_reconciliation.sql', '', ''),
  (199, '178_expectations_single_source.sql', '', ''),
  (200, '179_flow_test_skip_semantics.sql', '', ''),
  (201, '180_flow_test_future_availability.sql', '', ''),
  (202, '181_credit_model_rebalance.sql', '', ''),
  (203, '182_discover_carries_decision.sql', '', ''),
  (204, '183_lounges_rpc_and_grants.sql', '', ''),
  (205, '184_ms_status_language.sql', '', ''),
  (206, '185_device_flow_proofs.sql', '', ''),
  (207, '186_context_for_cards.sql', '', ''),
  (208, '187a_PRE_asiri_yukleme_temizligi.sql', 'eslikci', '187_kanitlanmis_kusurlar.sql'),
  (209, '187_kanitlanmis_kusurlar.sql', '', ''),
  (210, '188_salon_envanteri.sql', '', ''),
  (211, '189_coklu_hak_ve_kaynak_hizalama.sql', '', ''),
  (212, '190_salon_tekillestirme_ve_bolum.sql', '', ''),
  (213, '191_kaynak_celiskileri_ve_bosluklar.sql', '', ''),
  (214, '192a_PRE_charter_tabanda.sql', '', ''),
  (215, '192_on_kontrol_kapi_hizalama.sql', '', ''),
  (216, '193_kart_etiketi_ve_kabin_yazma.sql', '', ''),
  (217, '194_bekleme_listesi.sql', '', ''),
  (218, '195_ucus_alanlari_ve_kod_paylasimi.sql', '', ''),
  (219, '196_plan_ucretleri_ve_celiski_kapanisi.sql', '', ''),
  (220, '197_seyahatin_ucus_bilgisi_dolsun.sql', '', ''),
  (221, '198_thy_ajet_ms_yeniden_dogrulama.sql', '', ''),
  (222, '199_ucus_saati_terminal_ve_katalog.sql', '', ''),
  (223, '200_ulke_sozlugu_tekillestirme.sql', '', ''),
  (224, '201_banka_karti_tek_cerceve.sql', '', ''),
  (225, '202_saat_dilimi_ajet_anahtari_pencere.sql', '', ''),
  (226, '203_guvenlik_siniri.sql', '', ''),
  (227, '204_blok_eylem_sinirinda.sql', '', ''),
  (228, '205_bo_adresi_kendini_kaydeder.sql', '', ''),
  (229, '206_host_motoru.sql', '', ''),
  (230, '207_kopruler_ve_verilen_sozler.sql', '', ''),
  (231, '208_donem_devri_ve_kalibrasyon.sql', '', ''),
  (232, '209_saglayici_modulu.sql', '', ''),
  (233, '210a_PRE_plan_enum.sql', '', ''),
  (234, '210b_PRE_push_dayanikli.sql', '', ''),
  (235, '210_abonelik_push_ve_kapsam.sql', '', ''),
  (236, '211_kart_aglari_kaynaktan.sql', '', ''),
  (237, '212_yonetilen_ayarlar_gercekten_okunuyor.sql', '', ''),
  (238, '213_saglayici_kurumsal_katman.sql', '', ''),
  (239, '214a_PRE_ic_hat_salonlari.sql', 'eslikci', '214_misafir_hakki_kaynaktan.sql'),
  (240, '214_misafir_hakki_kaynaktan.sql', '', ''),
  (241, '215_saglayici_veri_yollari.sql', '', ''),
  (242, '216_hangi_kartimi_kullanayim.sql', '', ''),
  (243, '217_misafir_ucreti_geri.sql', '', ''),
  (244, '218_radar_olu_kolonlar.sql', '', ''),
  (245, '219_kredi_ve_ucret_dili.sql', '', ''),
  (246, '220_plan_katalogu_ve_dil.sql', '', ''),
  (247, '221_hosta_sor.sql', '', ''),
  (248, '222_ucretli_misafir_geri.sql', '', ''),
  (249, '223_sinirlar_dogruyu_soylesin.sql', '', ''),
  (250, '224_borclar_ve_ilan_neden_yok.sql', '', ''),
  (251, '225_planin_sozu_tutulsun.sql', '', ''),
  (252, '226_zamanlanmis_isler.sql', '', ''),
  (253, '227_seed_giris_onarimi.sql', '', ''),
  (254, '228_odul_katalogu_takas_kapaniyor.sql', '', ''),
  (255, '229_odul_teslim_sozu.sql', '', ''),
  (256, '230_host_hikayeleri.sql', '', ''),
  (257, '231_kurucu_cember_sayaci.sql', '', ''),
  (258, '232_rol_kapisi_ve_cuzdan_sizintisi.sql', '', ''),
  (259, '233_statu_listesi_tekillesiyor.sql', '', ''),
  (260, '234_aktif_oturum_kendini_anlatsin.sql', '', ''),
  (261, '235_sordugunu_gorebilmeli.sql', '', ''),
  (262, '236_ust_plan_bir_ay_ucretsiz.sql', '', ''),
  (263, '237_ilan_ve_seyahat_duzenlenebilsin.sql', '', ''),
  (264, '238_cuzdan_ve_soru_dili.sql', '', ''),
  (265, '239_soru_hangi_ilana_ait.sql', '', ''),
  (266, '240_kural_kapida_degil_odada.sql', '', ''),
  (267, '241_supabase_varsayilani_kapatiliyor.sql', '', ''),
  (268, '242_gorunumler_arka_kapi.sql', '', ''),
  (269, '243_one_cikarma_gercekten_calissin.sql', '', ''),
  (270, '244_odul_ekonomisi.sql', '', ''),
  (271, '245_vitrin_gokberkin_listesi.sql', '', ''),
  (272, '246_ekonomi_ayari.sql', '', ''),
  (273, '247_haber_ver.sql', '', ''),
  (274, '248_duzenleme_baglanti_degerlendirme.sql', '', ''),
  (275, '249_is_modeli_ve_soguk_ag.sql', '', ''),
  (276, '250_yaptirim_huni_dil_ve_kapilar.sql', '', ''),
  (277, '251_cron_nobeti_ve_kahya_ayricaligi.sql', '', ''),
  (278, '252_ulasilabilirlik_ve_push_izni.sql', '', ''),
  (279, '253_guvenlik_kapanisi.sql', '', ''),
  (280, '254_urun_bosluklari.sql', '', ''),
  (281, '255_magaza_sartlari.sql', '', ''),
  (282, '256_kredi_satisi_ve_kapida_iade.sql', '', ''),
  (283, '257_push_makbuzlari.sql', '', ''),
  (284, '258_olmayan_kolonlar.sql', '', ''),
  (285, '259_bo_performans_indeksleri.sql', '', ''),
  (286, '260_bo_sunucu_tarafi_toplamlar.sql', '', ''),
  (287, '261_rol_kapisi.sql', '', ''),
  (288, '261a_rol_uyumlama.sql', '', ''),
  (289, '262_seyahat_duzenle_tam.sql', '', ''),
  (290, '263_ana_sayfa_akisi.sql', '', ''),
  (291, '264_push_ve_api_saglik_raporu.sql', '', ''),
  (292, '265_api_yuzeyi_kapanisi.sql', '', ''),
  (293, '266_eksik_bildirimler.sql', '', ''),
  (294, '267_ilan_tablosu_anon_sizintisi.sql', '', ''),
  (295, '268_telefon_tekilligi.sql', '', ''),
  (296, '268a_telefon_cakismasi.sql', '', ''),
  (297, '269_dogrulama_zinciri.sql', '', ''),
  (298, '269a_DOGRULAMA_KONTROL.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (299, '269b_AYNA_FARKI.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (300, '270_test_verisi_gorunur.sql', '', ''),
  (301, '270a_GORUNURLUK.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (302, '270b_NEDEN_SIZIYOR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (303, '270c_KARAR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (304, '270d_HANGI_KATMAN.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (305, '270e_BASE_YAPISI.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (306, '271_kesfet_son_kapi.sql', '', ''),
  (307, '272_parantez_bypassi.sql', '', ''),
  (308, '273_SEED_KAPSAMI.sql', '', ''),
  (309, '274_istek_tavani_kilidi.sql', '', ''),
  (310, '275_kural_kosullari.sql', '', ''),
  (311, '276_push_kanallari.sql', '', ''),
  (312, '277_baglanti_kaldir.sql', '', ''),
  (313, '278_push_kanali_enum.sql', '', ''),
  (314, '279_sogu_baslangic.sql', '', ''),
  (315, '280_kredi_ve_durum_kilidi.sql', '', ''),
  (316, '281_kural_motoru_kapida_dogru.sql', '', ''),
  (317, '282_ban_ve_kvkk_silme.sql', '', ''),
  (318, '283_kural_motoru_on_iki_boyut.sql', '', ''),
  (319, '284_kural_geri_bildirim_dongusu.sql', '', ''),
  (320, '285_kyc_belge_ve_karar.sql', '', ''),
  (321, '286_tanis_cift_satir.sql', '', ''),
  (322, '287_planim_enum_metin_karsilastirma.sql', '', ''),
  (323, '288_guven_esigi_kolonu.sql', '', ''),
  (324, '289_davet_kabulu_mevcut_istek.sql', '', ''),
  (325, '290_kural_notlari_turkce.sql', '', ''),
  (326, '291_ilan_kaldirma_zorlu.sql', '', ''),
  (327, '292_zaman_dilimi_yerel_an.sql', '', ''),
  (328, '293_davet_cift_onay_ve_ilan_geri_cekme.sql', '', ''),
  (329, '294_binis_karti_dogrulama.sql', '', ''),
  (330, '295_ilanin_ikinci_hayati_ve_sayaclar.sql', '', ''),
  (331, '296_hikaye_daveti_erteleme.sql', '', ''),
  (332, '297_yetki_kapilari.sql', '', ''),
  (333, '298_supurge_kisiti_ve_asim_dedektoru.sql', '', ''),
  (334, '299_kredi_kilidi_supurge_sahibi_ve_iade_tutari.sql', '', ''),
  (335, '300_uctan_uca_denetim.sql', '', ''),
  (336, '301_guven_ve_akis_tamamlama.sql', '', ''),
  (337, '302_test_hesaplarini_gorenler.sql', '', ''),
  (338, '303_ertelenen_puan_ana_sayfadan_duser.sql', '', ''),
  (339, '304_kesfet_engelinin_gercek_sebebi.sql', '', ''),
  (340, '305_erisim_kaynagi_etiketleri.sql', '', ''),
  (341, '306_kural_notlari_turkce_tamam.sql', '', ''),
  (342, '307_zarafet_atlama_siniri.sql', '', ''),
  (343, '308_bo_atlama_uyarisi.sql', '', ''),
  (344, '309_kural_tablosu_denetimi_ve_ilan_erisimi.sql', '', ''),
  (345, '310_309_duzeltme_tasiyici_kapisi_guvenlik.sql', '', ''),
  (346, '311_kesfet_ozeti_tek_kaynak.sql', '', ''),
  (347, '312_soru_ilan_bagi_gercekten.sql', '', ''),
  (348, '313_akis_durum_makinesi_bildirim_soru.sql', '', ''),
  (349, '314_soru_yazili_yanit_ve_baglanti.sql', '', ''),
  (350, '315_bo_rapor_fonksiyonlari_kullaniciya_kapali.sql', '', ''),
  (351, '316_bayat_istek_supurgede.sql', '', ''),
  (352, '317_kesfet_olcek.sql', '', ''),
  (353, '318_ana_sayfa_akisi_olcek.sql', '', ''),
  (354, '319_tanis_gorunurluk_olcek.sql', '', ''),
  (355, '320_istek_puani_daraltilmis.sql', '', ''),
  (356, '321_erisim_karari_kart_secimi_belirli.sql', '', ''),
  (357, '322_hesap_silme_calisir_ve_acik_isleri_kapatir.sql', '', ''),
  (358, '323_ilan_ac_saat_ve_kontenjan_kapisi.sql', '', ''),
  (359, '324_tanis_silinmis_yasakli_suzgeci.sql', '', ''),
  (360, '325_seyahat_cakismasi_farkli_havalimani.sql', '', ''),
  (361, '326_kisi_ara_aday_siniri.sql', '', ''),
  (362, '327_tanis_profil_gorunurlugu.sql', '', ''),
  (363, '328_host_tek_yol_bo_onayli_basvuru.sql', '', ''),
  (364, '329_silinen_hesap_14_gun_anonim.sql', '', ''),
  (365, '330_bo_hesabi_geri_al.sql', '', ''),
  (366, '331_soru_kendi_kaydinda.sql', '', ''),
  (367, '332_revenuecat_satin_alma.sql', '', ''),
  (368, '333_magaza_inceleme_hesabi.sql', '', ''),
  (369, '334_ekonomi_ve_icerik_suzgeci.sql', '', ''),
  (370, '335_telefon_firebase_dogrulama.sql', '', ''),
  (371, '336_kabulde_digerleri_geri_cek.sql', '', ''),
  (372, '337_jetset_puan_kredi_kurulus.sql', '', ''),
  (373, '338_odul_erken_erisim_plan_indirimi.sql', '', ''),
  (374, '339_odul_marka_adlari.sql', '', ''),
  (375, '340_jetset_urun_kimlikleri.sql', '', ''),
  (376, '341_ilan_basvurusu_dili.sql', '', ''),
  (377, '342_oturum_baslatma_penceresi.sql', '', ''),
  (378, '343_olmayan_salonlari_gizle.sql', '', ''),
  (379, '344_ucus_onbellegi_temizligi.sql', '', ''),
  (380, '345_kyc_kapanisi_dogrulanmis_profil_kvkk.sql', '', ''),
  (381, '346_esb_primeclass_birlestir.sql', '', ''),
  (382, '347_guvenlik_fraud_kapanisi.sql', '', ''),
  (383, '348_canli_esitleme.sql', '', ''),
  (901, 'SEED_KURAL_SENARYOLARI.sql', 'satir', 'users.email=kmisafir1@seed.loungelink.test'),
  (902, 'SEED2_KAYNAK_SENARYOLARI.sql', 'satir', 'users.email=kaynak1@seed.loungelink.test'),
  (903, 'SEED3_UCTAN_UCA.sql', 'satir', 'users.email=host1@seed.loungelink.test'),
  (904, 'SEED4_KURAL_VITRINI.sql', 'sayi', 'availabilities|host_id in (select id from users where email = ''host1@seed.loungelink.test'')|10'),
  (905, 'SEED5_BASVURU_AKISLARI.sql', 'satir', 'users.email=guest3@seed.loungelink.test'),
  (906, 'SEED6_TEST_DUNYASI.sql', 'satir', 'users.email=deniz@sahne.loungelink.test'),
  (907, 'SEED7_TEZGAH.sql', 'sayi', 'invites|status = ''accepted''|1'),
  (908, 'SEED8_AKIS_TEZGAHI.sql', 'satir', 'users.email=akis.host@seed.loungelink.test'),
  (909, 'SEED9_AKIS_GENIS.sql', 'satir', 'users.email=akis.host3@seed.loungelink.test')
),
ham as (
  select i.sira, i.dosya, i.tip, i.ad,
         case when i.tip = 'eslikci' then null
              else public.kurulum_imzasi_var(i.tip, i.ad) end as var
    from imza i
),
-- 🔴 `PRE_drop` dosyaları iz BIRAKMAZ, çünkü işleri SİLMEK. Ama her biri
-- bir sonraki ana dosyanın ön koşuludur (024a olmadan 024 → 42P13). Yani
-- 024 koştuysa 024a da koşmuştur. Uydurmuyoruz, EŞİTLİYORUZ.
cozum as (
  select h.sira, h.dosya, h.tip, h.ad,
         case when h.tip = 'eslikci'
              then (select h2.var from ham h2 where h2.dosya = h.ad)
              else h.var end as var
    from ham h
),
ham_etiket as (
  select c.*,
         case
           -- 🔵 EN GÜÇLÜ KANIT: dosya KENDİSİ deftere yazmış (SQL 253'ten
           -- itibaren her migration bunu yapıyor). Tespite gerek yok.
           when exists (select 1 from schema_migrations m
                         where m.dosya = c.dosya and coalesce(m.kaynak,'') <> 'tespit')
                then '✅ KOSTU'
           when c.var is true then '✅ KOSTU'
           when c.var is false then '❌ KOSMADI'
           else '⬜ BILINMIYOR' end as durum
    from cozum c
),
-- 🔴 SIRALI ÇIKARIM — BU BİR ÖLÇÜM DEĞİL, ÇIKARIMDIR VE ÖYLE İŞARETLENİR.
--
-- Migration'lar sırayla çalıştırılır ve çoğu bir öncekine bağlıdır.
-- Bir dosya ayırt edici iz bırakmıyorsa (BİLİNMİYOR) ama KENDİSİNDEN
-- SONRAKİ bir dosyanın koştuğu ÖLÇÜLDÜYSE, o dosya da koşmuş olmalıdır —
-- aksi hâlde sonraki dosya hata verirdi.
--
-- Bu ayrım önemli: "bilinmiyor" 57 dosyaydı ve zincirin ortasındaki bir
-- boşluk "en son nerede kaldım?" sorusunu cevapsız bırakıyordu. Çıkarım
-- o boşlukları kapatıyor ama İDDİA olarak değil, ayrı bir etiketle.
--
-- 🆕 SINIF: "BİR ÇIKARIMI ÖLÇÜMLE AYNI ETİKETLE SUNMAK, ÖLÇÜMÜN
-- İTİBARINI ÇIKARIMA ÖDÜNÇ VERMEKTİR."
son_olculen as (
  select max(sira) as s from ham_etiket where durum = '✅ KOSTU' and sira < 900
),
etiketli as (
  select h.sira, h.dosya, h.tip, h.ad,
         case when h.durum = '⬜ BILINMIYOR'
                   and h.sira < coalesce((select s from son_olculen), -1)
              then '🟩 KOSTU (sirali cikarim)'
              else h.durum end as durum
    from ham_etiket h
),
-- Kaldığın yer: KOSMADI işaretli EN KÜÇÜK sıra.
ilk_eksik as (
  select min(sira) as s from etiketli where durum = '❌ KOSMADI'
),
son_kosan as (
  select max(sira) as s from etiketli where durum like '✅%' or durum like '🟩%'
)
select * from (
  -- ÖZET SATIRLARI (sıra 0 ve negatif → en üstte)
  select -3 as sira,
         '>>> BURADAN DEVAM ET <<<' as dosya,
         coalesce((select e.dosya from etiketli e, ilk_eksik f where e.sira = f.s),
                  'EKSIK YOK — hepsi kurulu görünüyor') as durum,
         '' as tip, '' as imza
  union all
  select -2, '>>> EN SON KOSAN <<<',
         coalesce((select e.dosya from etiketli e, son_kosan g where e.sira = g.s), '-'),
         '', ''
  union all
  select -1, '>>> OZET <<<',
         (select count(*) filter (where durum='✅ KOSTU')::text || ' olculdu · '
               || count(*) filter (where durum like '🟩%')::text || ' sirali cikarim · '
               || count(*) filter (where durum='❌ KOSMADI')::text || ' KOSMADI · '
               || count(*) filter (where durum='⬜ BILINMIYOR')::text || ' hala bilinmiyor · '
               || count(*)::text || ' toplam'
            from etiketli),
         '', ''
  union all
  select 0, '>>> NOT <<<',
         '✅ = olculdu (iz bulundu) · 🟩 = iz yok ama SONRASI kurulu oldugu icin kosmus olmali (CIKARIM) · ⬜ = hala bilinmiyor (yalniz zincirin SONUNDA kalir) · ❌ = izi ARANDI, YOK. Ilk ❌ ten itibaren sirayla calistir.',
         '', ''
  union all
  select e.sira, e.dosya, e.durum, e.tip, e.ad from etiketli e
) t
order by sira;
