-- ============================================================================
-- LoungeLink · KURULUM_TABLOSU.sql        (2026-09-23 uretildi · 345 dosya · son: 302)
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
-- ÖLÇÜM: 337 dosyanın 288 tanesi için ayırt edici imza
-- bulundu (%85). Kalan 49 tanesi BİLİNMİYOR olarak
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
  (1, '001_initial_schema.sql', 'indeks', 'idx_otp_phone'),
  (2, '002_seed_reference.sql', 'satir', 'lounges.name=Primeclass Lounge'),
  (3, '003_admin_roles.sql', 'tablo', 'admin_roles'),
  (4, '004_auth_bridge.sql', 'tetikleyici', 'on_auth_user_created'),
  (5, '005_reference_read.sql', 'politika', 'lounges|lounges_read'),
  (6, '006_discovery_read.sql', 'politika', 'profiles|profiles_read_auth'),
  (7, '007_request_engine.sql', 'fonksiyon', 'create_request'),
  (8, '008_chat_sessions.sql', 'politika', 'messages|msg_read'),
  (9, '009_phone_otp.sql', 'fonksiyon', 'send_otp'),
  (10, '010_profile_write.sql', 'politika', 'profiles|profiles_self_update'),
  (11, '011_notifications.sql', 'politika', 'notifications|notif_own_read'),
  (12, '012_women_safety.sql', 'fonksiyon', 'discover_availabilities'),
  (13, '013_push_tokens.sql', 'tablo', 'push_tokens'),
  (14, '014_push_trigger.sql', 'tetikleyici', 'on_notification_created'),
  (15, '015_connections.sql', 'politika', 'connection_requests|conn_own_read'),
  (16, '016_match_score.sql', '', ''),
  (17, '017_marketplace.sql', 'tablo', 'rewards'),
  (18, '018_subscriptions.sql', 'tablo', 'plan_catalog'),
  (19, '019_admin_management.sql', 'fonksiyon', 'admin_adjust_credit'),
  (20, '020_rbac.sql', 'kolon', 'admin_roles.created_by'),
  (21, '021_moderation_tools.sql', 'fonksiyon', 'remove_rating'),
  (22, '022_rewards_parity.sql', 'satir', 'rewards.title=Emirates Skywards 750 Mil'),
  (23, '023_partner_portal.sql', 'tablo', 'lounge_partners'),
  (24, '024a_PRE_drop_old_discovery.sql', 'eslikci', '024_avatars_storage.sql'),
  (25, '024_avatars_storage.sql', 'politika', 'storage|avatars_read'),
  (26, '025_role_on_signup.sql', 'govde', 'handle_new_user|); exception when others then r :='),
  (27, '026a_PRE_drop.sql', 'eslikci', '026_doc_parity_core.sql'),
  (28, '026_doc_parity_core.sql', 'kolon', 'profiles.access_source'),
  (29, '027_companion_chat.sql', 'kolon', 'chat_channels.kind'),
  (30, '028_referral.sql', 'kolon', 'profiles.referred_by'),
  (31, '029_bo_requirements.sql', 'kolon', 'rewards.stock'),
  (32, '030_match_and_broadcast.sql', 'kolon', 'invites.responded_at'),
  (33, '031_cleanup_overloads.sql', '', ''),
  (34, '032_p2_flows.sql', 'kolon', 'sessions.rate_deferred_by'),
  (35, '033a_PRE_drop.sql', 'eslikci', '033_beta_credits_dualrole_radar.sql'),
  (36, '033_beta_credits_dualrole_radar.sql', 'kolon', 'credit_ledger.note'),
  (37, '034_lounge_radar.sql', 'tablo', 'blocks'),
  (38, '035a_PRE_drop.sql', 'eslikci', '035_password_flow.sql'),
  (39, '035_password_flow.sql', 'kolon', 'admin_roles.must_change_password'),
  (40, '036a_PRE_drop.sql', 'eslikci', '036_host_applications.sql'),
  (41, '036_host_applications.sql', 'indeks', 'idx_host_app_status'),
  (42, '037a_PRE_drop.sql', 'eslikci', '037_admin_verifications.sql'),
  (43, '037_admin_verifications.sql', 'fonksiyon', 'admin_set_verification'),
  (44, '038_SQL_DURUM.sql', '', ''),
  (45, '039_DOGRULAMA.sql', '', ''),
  (46, '040a_PRE_drop.sql', 'eslikci', '040_visibility_and_discovery_fix.sql'),
  (47, '040_visibility_and_discovery_fix.sql', 'kolon', 'availabilities.min_trust'),
  (48, '041_staff_accounts_excluded.sql', 'kolon', 'users.is_staff'),
  (49, '042_reports_and_sos.sql', 'kolon', 'reports.is_urgent'),
  (50, '043_admin_data_cleanup.sql', 'fonksiyon', 'admin_list_visits'),
  (51, '044a_PRE_drop.sql', 'eslikci', '044_trip_purpose_and_people_fix.sql'),
  (52, '044_trip_purpose_and_people_fix.sql', 'kolon', 'visits.purpose'),
  (53, '045_admin_edit_email_phone.sql', 'fonksiyon', 'admin_set_email'),
  (54, '046a_PRE_drop.sql', 'eslikci', '046_trust_and_host_visibility.sql'),
  (55, '046_trust_and_host_visibility.sql', 'fonksiyon', 'host_requests'),
  (56, '047a_PRE_drop.sql', 'eslikci', '047_campaign_targets.sql'),
  (57, '047_campaign_targets.sql', 'govde', 'send_campaign|and u.deleted_at is null'),
  (58, '048a_PRE_drop.sql', 'eslikci', '048_promo_campaigns.sql'),
  (59, '048_promo_campaigns.sql', 'tablo', 'promo_codes'),
  (60, '049a_PRE_drop.sql', 'eslikci', '049_discovery_safety_phone_delete.sql'),
  (61, '049_discovery_safety_phone_delete.sql', 'kolon', 'promo_campaigns.joinable'),
  (62, '050a_PRE_drop.sql', 'eslikci', '050_host_requests_flight.sql'),
  (63, '050_host_requests_flight.sql', 'govde', 'host_requests|b.gflight as flight_number'),
  (64, '051_beta_visibility_reset_and_diagnoz.sql', '', ''),
  (65, '052_session_live_status.sql', 'kolon', 'sessions.host_status'),
  (66, '053_unstaff_founder_and_diag.sql', '', ''),
  (67, '054a_PRE_drop.sql', 'eslikci', '054_discover_people_include_hosts.sql'),
  (68, '054_discover_people_include_hosts.sql', '', ''),
  (69, '055_listing_makes_host.sql', '', ''),
  (70, '056_supply_demand_match_notify.sql', '', ''),
  (71, '057_waiting_demand_rpc.sql', 'fonksiyon', 'waiting_demand'),
  (72, '058_fix_stale_staff_roles.sql', '', ''),
  (73, '059a_PRE_drop.sql', 'eslikci', '059_discover_everyone_request_gate.sql'),
  (74, '059_discover_everyone_request_gate.sql', '', ''),
  (75, '060_security_hardening.sql', 'politika', 'reports|reports_select_own'),
  (76, '061_fix_respond_request_and_slots.sql', 'indeks', 'idx_conn_to'),
  (77, '062_fix_verify_otp.sql', 'ayar', 'otp_demo_bypass'),
  (78, '063_error_logging.sql', 'indeks', 'idx_app_errors_time'),
  (79, '064_fix_overloads_and_discovery.sql', '', ''),
  (80, '065_fix_create_request.sql', 'kolon', 'requests.purpose'),
  (81, '066_request_status_completed.sql', 'enum_degeri', 'request_status.completed'),
  (82, '067_fix_confirm_session_enum.sql', '', ''),
  (83, '068_fix_rate_session.sql', '', ''),
  (84, '069_fix_respond_connection_cast.sql', 'govde', 'respond_connection|on conflict (connection_id) where connection_id is not null do nothing'),
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
  (95, '077_session_autostart_intro_slots.sql', 'tetikleyici', 'trg_requests_sync_filled'),
  (96, '078_trust_single_writer.sql', 'govde', 'compute_trust_badge|else ''basic'' end'),
  (97, '079_email_otp_contact_verification.sql', 'fonksiyon', 'is_contact_verified'),
  (98, '080_session_lifecycle.sql', 'enum_degeri', 'session_status.pending'),
  (99, '081a_PRE_drop.sql', 'eslikci', '081_pending_ratings_link.sql'),
  (100, '081_pending_ratings_link.sql', 'fonksiyon', 'unrated_sessions'),
  (101, '082_rate_limiting.sql', 'tetikleyici', 'trg_rl_visits'),
  (102, '083_lounge_rules_and_flight_prep.sql', 'kolon', 'visits.terminal'),
  (103, '084_deletion_requests.sql', 'indeks', 'idx_delreq_status'),
  (104, '085_lounge_rules_v2.sql', 'kolon', 'availabilities.rule_note'),
  (105, '086a_PRE_drop.sql', 'eslikci', '086_lounge_rules_v3.sql'),
  (106, '086_lounge_rules_v3.sql', 'kolon', 'lounges.venue_id'),
  (107, '087a_PRE_drop.sql', 'eslikci', '087_entitlements_and_coverage.sql'),
  (108, '087_entitlements_and_coverage.sql', 'kolon', 'host_entitlements.quota_used'),
  (109, '088_card_catalog.sql', 'kolon', 'lounge_card_products.segment'),
  (110, '089_missing_columns.sql', '', ''),
  (111, '090_rules_to_app.sql', 'kolon', 'lounge_card_products.guest_quota_total'),
  (112, '091_flight_quota.sql', 'kisit', 'ffl_outcome_chk'),
  (113, '092_host_access_declaration.sql', 'kolon', 'profiles.guest_fee_expected'),
  (114, '093_reward_featured.sql', 'kolon', 'rewards.is_featured'),
  (115, '094_admin_erasure.sql', 'kolon', 'users.anonymized_at'),
  (116, '095_close_the_loop.sql', 'fonksiyon', 'submit_field_report'),
  (117, '096_rule_autofill.sql', 'fonksiyon', 'autofill_venue_acceptance'),
  (118, '097_ajet_and_tk_detail.sql', '', ''),
  (119, '098_full_rule_matrix.sql', '', ''),
  (120, '099_card_networks_venue_level.sql', 'kolon', 'lounge_venues.venue_kind'),
  (121, '100_tier_fee_and_time.sql', 'kolon', 'lounge_programs.fee_payer'),
  (122, '101_sections_charter_expiry.sql', 'kolon', 'lounge_venues.section_of'),
  (123, '102_badge_wording.sql', 'ayar', 'badge_labels'),
  (124, '103_consolidate_and_charter.sql', 'fonksiyon', 'venue_norm'),
  (125, '104_tier_rules_program_level.sql', 'govde', 'lounge_access_decision_v3|, coalesce(v_head, d ->>'),
  (126, '105_fee_wording_and_business.sql', 'govde', 'lounge_access_decision_v3|Misafir girişi ücretli — ücret host'),
  (127, '106_channel_fees_and_bank_deals.sql', '', ''),
  (128, '107_missing_airports.sql', 'satir', 'airports.code=DLM'),
  (129, '108_paid_guest_settlement.sql', 'indeks', 'uq_field_report_once'),
  (130, '109_pegasus_and_overloads.sql', '', ''),
  (131, '110_family_abroad.sql', '', ''),
  (132, '111_push_direct_expo.sql', 'kolon', 'push_tokens.active'),
  (133, '112_blocks_in_discovery.sql', 'fonksiyon', 'is_blocked_pair'),
  (134, '113_dedupe_and_wording.sql', 'govde', 'venue_norm|ıİşŞğĞüÜöÖçÇÂâÎî'),
  (135, '114_card_confidence_visible.sql', 'fonksiyon', 'card_confidence_note'),
  (136, '115_quota_who_says.sql', 'ayar', 'quota_note_host'),
  (137, '116_badges_gate_and_sort.sql', 'govde', 'discovery_rule_badges|v_block := false;'),
  (138, '117_carrier_field.sql', 'kolon', 'visits.carrier_code'),
  (139, '118_carrier_in_rules.sql', 'fonksiyon', 'carrier_match'),
  (140, '119_precheck_v5_and_charter.sql', 'kolon', 'visits.is_charter'),
  (141, '120_human_text.sql', 'ayar', 'head_charter'),
  (142, '121_source_summary.sql', 'fonksiyon', 'access_source_summary'),
  (143, '122_what_can_i_do.sql', 'ayar', 'alt_note_some'),
  (144, '123_overload_cleanup.sql', '', ''),
  (145, '124_card_catalog_verified.sql', 'kisit', 'lcp_q_period_chk'),
  (146, '125_saw_plaza_partners.sql', 'indeks', 'ix_lvp_venue'),
  (147, '126_partners_visible.sql', 'fonksiyon', 'venue_partners'),
  (148, '127_ist_tk_from_iga.sql', '', ''),
  (149, '128_iga_lounge_and_conflicts.sql', 'kolon', 'lounge_venue_acceptance.source_conflict'),
  (150, '129_conflict_surfaced.sql', 'govde', 'lounge_access_decision_v5|if v_conf is not null then'),
  (151, '130_amenities.sql', 'kolon', 'lounge_venues.amenities'),
  (152, '131_card_advisor.sql', 'ayar', 'advice_intro'),
  (153, '132_travel_style.sql', 'kolon', 'profiles.travel_style'),
  (154, '133_catalog_dedupe.sql', '', ''),
  (155, '134_tier_label_everywhere.sql', 'govde', 'lounge_access_decision_v3|coalesce(public.card_tier_label(v_ent.tier), ''Bu kart''))'),
  (156, '135_short_and_honest.sql', 'govde', 'discovery_rule_badges|v_key := ''guest_none_soft''; v_boost := -200;'),
  (157, '136_otp_honesty.sql', 'kolon', 'verifications.phone_verified_method'),
  (158, '137_placeholder_vs_data.sql', 'kolon', 'lounge_venue_acceptance.is_placeholder'),
  (159, '138_email_otp.sql', 'ayar', 'otp_notice_email'),
  (160, '139_final_polish.sql', '', ''),
  (161, '140_rls_and_ratelimit.sql', 'tablo', 'rate_limits'),
  (162, '141_deletion_flow_check.sql', 'fonksiyon', 'request_account_deletion'),
  (163, '142_short_detail_hard.sql', 'fonksiyon', 'clip_text'),
  (164, '143_lounge_guide.sql', 'fonksiyon', 'guide_lounges'),
  (165, '144_guide_fixes.sql', 'govde', 'guide_lounges|then v.name || '' — Business'''),
  (166, '145_null_sort_guard.sql', 'govde', 'card_product_options|cp.quota_total, cp.quota_period, cp.conditions,'),
  (167, '146_tk_official_matrix.sql', 'ayar', 'tk_paid_entry_2026'),
  (168, '147_tier_resolver.sql', 'fonksiyon', 'resolve_guest_rule'),
  (169, '148_rule_matrix_test.sql', 'fonksiyon', 'rule_matrix_check'),
  (170, '149_multi_entitlement.sql', 'fonksiyon', 'best_entitlement'),
  (171, '150_network_rules_and_guard.sql', 'fonksiyon', 'rule_contamination_check'),
  (172, '151_deterministic_program_pick.sql', 'fonksiyon', 'pick_host_program'),
  (173, '152_field_reports_loop.sql', 'kolon', 'lounge_field_reports.entered'),
  (174, '153_host_motivation.sql', 'kolon', 'profiles.founding_host_no'),
  (175, '154_membership_tiers.sql', 'kolon', 'lounge_guest_rules.guest_entry_fee'),
  (176, '155_member_cost_visible.sql', 'fonksiyon', 'guide_cost'),
  (177, '156_official_alignment_and_scope.sql', 'kolon', 'lounge_guest_rules.venue_scope'),
  (178, '157_decision_uses_resolver.sql', 'fonksiyon', 'decision_chain_check'),
  (179, '158_device_findings.sql', 'govde', 'guide_lounges|(exists (select 1 from lounge_venue_acceptance ac'),
  (180, '159_grants_home_flows_request_gate.sql', 'kolon', 'connection_requests.responded_at'),
  (181, '160_catalog_name_dedupe.sql', '', ''),
  (182, '161_venue_merge_and_catalog_truth.sql', '', ''),
  (183, '162_source_truth_and_founder_badge.sql', 'fonksiyon', 'founding_badge_sync'),
  (184, '163_unknown_carrier_and_coverage_audit.sql', 'fonksiyon', 'rule_coverage_audit'),
  (185, '164_business_ticket_and_operator_rules.sql', 'govde', 'rule_coverage_audit|Hiç kuralı olmayan aktif program'),
  (186, '165_prebeta_security.sql', 'tetikleyici', 'trg_guard_otp_bypass'),
  (187, '166_slot_integrity_and_flow_tests.sql', 'fonksiyon', 'flow_gate_test'),
  (188, '167_rule_expectation_matrix.sql', 'indeks', 'uq_rule_test_case'),
  (189, '168_carrier_gap_and_paid_entry.sql', 'kural_notu', 'lounge_guest_rules|Bu kart tipinin hiçbir taşıyıcıda ve hiçbir kapsamda misafir hakkı yoktur.'),
  (190, '169_slot_counter_repair.sql', '', ''),
  (191, '170_resolution_order_fix.sql', '', ''),
  (192, '171_full_matrix_and_report.sql', 'kolon', 'rule_test_cases.needs_review'),
  (193, '172_resolver_full_definition.sql', 'govde', 'resolve_guest_rule|and (p_tier is null or x.card_tier is null)'),
  (194, '173_showcase_data.sql', '', ''),
  (195, '174_venue_beats_program_rule.sql', 'govde', 'rule_venue_test|✗ SALON KURALI ÇELİŞİYOR'),
  (196, '175_flow_test_cleanup_fix.sql', 'fonksiyon', 'flow_test_cleanup'),
  (197, '176_flow_test_rate_limit.sql', 'govde', 'rl_guard|if coalesce(current_setting(''ll.test_mode'', true), '''') = ''on'' then'),
  (198, '177_official_table_reconciliation.sql', 'govde', 'rule_matrix_test|(ac.id is not null) desc, v.id'),
  (199, '178_expectations_single_source.sql', 'fonksiyon', 'rebuild_rule_test_cases'),
  (200, '179_flow_test_skip_semantics.sql', 'fonksiyon', 'flow_env_block'),
  (201, '180_flow_test_future_availability.sql', 'govde', 'flow_env_block|''%self_request%'','),
  (202, '181_credit_model_rebalance.sql', 'ayar_deger', 'host_door_bonus_points=50'),
  (203, '182_discover_carries_decision.sql', 'fonksiyon', 'discover_availabilities_base'),
  (204, '183_lounges_rpc_and_grants.sql', 'fonksiyon', 'lounges_for_airport'),
  (205, '184_ms_status_language.sql', 'govde', 'card_tier_label|Miles&Smiles Amex'),
  (206, '185_device_flow_proofs.sql', 'fonksiyon', 'device_flow_check'),
  (207, '186_context_for_cards.sql', 'fonksiyon', 'my_sent_requests'),
  (208, '187a_PRE_asiri_yukleme_temizligi.sql', 'eslikci', '187_kanitlanmis_kusurlar.sql'),
  (209, '187_kanitlanmis_kusurlar.sql', 'fonksiyon', 'rpc_smoke_test'),
  (210, '188_salon_envanteri.sql', '', ''),
  (211, '189_coklu_hak_ve_kaynak_hizalama.sql', 'fonksiyon', 'best_access_for_user'),
  (212, '190_salon_tekillestirme_ve_bolum.sql', 'fonksiyon', 'brand_key'),
  (213, '191_kaynak_celiskileri_ve_bosluklar.sql', 'kolon', 'availabilities.cabin_class'),
  (214, '192a_PRE_charter_tabanda.sql', '', ''),
  (215, '192_on_kontrol_kapi_hizalama.sql', 'govde', 'request_precheck|Bu ilana misafir alınamıyor'),
  (216, '193_kart_etiketi_ve_kabin_yazma.sql', 'fonksiyon', 'save_host_card'),
  (217, '194_bekleme_listesi.sql', 'kisit', 'wl_role_chk'),
  (218, '195_ucus_alanlari_ve_kod_paylasimi.sql', 'kolon', 'flight_cache.airline'),
  (219, '196_plan_ucretleri_ve_celiski_kapanisi.sql', 'indeks', 'uq_venue_prices'),
  (220, '197_seyahatin_ucus_bilgisi_dolsun.sql', 'tetikleyici', 'trg_visit_flight_ins'),
  (221, '198_thy_ajet_ms_yeniden_dogrulama.sql', 'indeks', 'uq_entry_tariff'),
  (222, '199_ucus_saati_terminal_ve_katalog.sql', 'tetikleyici', 'trg_venue_catalog_ins'),
  (223, '200_ulke_sozlugu_tekillestirme.sql', 'tablo', 'country_aliases'),
  (224, '201_banka_karti_tek_cerceve.sql', 'kolon', 'host_entitlements.bank_covers_fee'),
  (225, '202_saat_dilimi_ajet_anahtari_pencere.sql', 'tetikleyici', 'trg_ajet_intl'),
  (226, '203_guvenlik_siniri.sql', 'tablo', 'rpc_client_surface'),
  (227, '204_blok_eylem_sinirinda.sql', 'tetikleyici', 'trg_blok_gecmis'),
  (228, '205_bo_adresi_kendini_kaydeder.sql', 'ayar', 'backoffice_url'),
  (229, '206_host_motoru.sql', 'tablo', 'host_tiers'),
  (230, '207_kopruler_ve_verilen_sozler.sql', 'kolon', 'host_tiers.one_cikar_saat'),
  (231, '208_donem_devri_ve_kalibrasyon.sql', 'indeks', 'idx_credit_requests_status'),
  (232, '209_saglayici_modulu.sql', 'ayar_deger', 'partner_k_threshold=5'),
  (233, '210a_PRE_plan_enum.sql', 'enum_degeri', 'plan_type.yolcu'),
  (234, '210b_PRE_push_dayanikli.sql', '', ''),
  (235, '210_abonelik_push_ve_kapsam.sql', 'kolon', 'plan_catalog.ad'),
  (236, '211_kart_aglari_kaynaktan.sql', 'kolon', 'card_network_source.kart_no'),
  (237, '212_yonetilen_ayarlar_gercekten_okunuyor.sql', 'kolon', 'i18n_strings.note'),
  (238, '213_saglayici_kurumsal_katman.sql', 'rpc_yuzeyi', 'venue_no_show'),
  (239, '214a_PRE_ic_hat_salonlari.sql', 'eslikci', '214_misafir_hakki_kaynaktan.sql'),
  (240, '214_misafir_hakki_kaynaktan.sql', 'kolon', 'lounge_venues.is_umbrella'),
  (241, '215_saglayici_veri_yollari.sql', 'kolon', 'availabilities.program_source'),
  (242, '216_hangi_kartimi_kullanayim.sql', 'rpc_yuzeyi', 'hangi_kartimi_kullanayim'),
  (243, '217_misafir_ucreti_geri.sql', 'kolon', 'lounge_guest_rules.yillik_para'),
  (244, '218_radar_olu_kolonlar.sql', 'govde', 'lounge_radar_people|or (c.to_id=v_uid and c.from_id=pe.uid)'),
  (245, '219_kredi_ve_ucret_dili.sql', 'ayar_deger', 'paid_guest_credits=1'),
  (246, '220_plan_katalogu_ve_dil.sql', 'kolon', 'plan_catalog.ad_en'),
  (247, '221_hosta_sor.sql', 'ayar', 'err_rule_ask_daily_limit'),
  (248, '222_ucretli_misafir_geri.sql', 'govde', 'lounge_access_decision|,            case when coalesce(d ->>'),
  (249, '223_sinirlar_dogruyu_soylesin.sql', 'ayar', 'err_rate_limited'),
  (250, '224_borclar_ve_ilan_neden_yok.sql', 'rpc_yuzeyi', 'ucus_kotam'),
  (251, '225_planin_sozu_tutulsun.sql', 'rpc_yuzeyi', 'plan_kredisi_yerlestir'),
  (252, '226_zamanlanmis_isler.sql', '', ''),
  (253, '227_seed_giris_onarimi.sql', '', ''),
  (254, '228_odul_katalogu_takas_kapaniyor.sql', 'kisit', 'rewards_no_lounge_barter_chk'),
  (255, '229_odul_teslim_sozu.sql', 'kolon', 'redemptions.durum'),
  (256, '230_host_hikayeleri.sql', 'kisit', 'hs_yayin_riza_chk'),
  (257, '231_kurucu_cember_sayaci.sql', 'ayar_deger', 'kurucu_kontenjan=100'),
  (258, '232_rol_kapisi_ve_cuzdan_sizintisi.sql', 'kolon', 'users.role_source'),
  (259, '233_statu_listesi_tekillesiyor.sql', 'govde', 'card_tier_options|r.notes nulls last;'),
  (260, '234_aktif_oturum_kendini_anlatsin.sql', 'rpc_yuzeyi', 'aktif_oturum_detay'),
  (261, '235_sordugunu_gorebilmeli.sql', 'tetikleyici', 'trg_cr_soru_izi'),
  (262, '236_ust_plan_bir_ay_ucretsiz.sql', 'indeks', 'uq_plan_grants_aktif'),
  (263, '237_ilan_ve_seyahat_duzenlenebilsin.sql', 'tetikleyici', 'trg_avail_kapatma_kapisi'),
  (264, '238_cuzdan_ve_soru_dili.sql', 'tetikleyici', 'trg_cr_soru_metni'),
  (265, '239_soru_hangi_ilana_ait.sql', 'kolon', 'connection_requests.avail_id'),
  (266, '240_kural_kapida_degil_odada.sql', 'tetikleyici', 'trg_visit_sozlesme'),
  (267, '241_supabase_varsayilani_kapatiliyor.sql', 'tablo', 'client_write_allowlist'),
  (268, '242_gorunumler_arka_kapi.sql', '', ''),
  (269, '243_one_cikarma_gercekten_calissin.sql', 'ayar_deger', 'one_cikan_esz_tavan_host=1'),
  (270, '244_odul_ekonomisi.sql', 'kolon', 'rewards.maliyet_turu'),
  (271, '245_vitrin_gokberkin_listesi.sql', 'kolon', 'rewards.zarar_gerekce'),
  (272, '246_ekonomi_ayari.sql', 'kolon', 'plan_catalog.acik_istek_tavani'),
  (273, '247_haber_ver.sql', 'indeks', 'talep_kayit_arama'),
  (274, '248_duzenleme_baglanti_degerlendirme.sql', 'tablo', 'kredi_paketleri'),
  (275, '249_is_modeli_ve_soguk_ag.sql', 'kolon', 'requests.decision_note'),
  (276, '250_yaptirim_huni_dil_ve_kapilar.sql', 'kolon', 'profiles.dil'),
  (277, '251_cron_nobeti_ve_kahya_ayricaligi.sql', 'kolon', 'host_tiers.sinirsiz_kural_sorusu'),
  (278, '252_ulasilabilirlik_ve_push_izni.sql', 'kisit', 'push_izin_durum_kapisi'),
  (279, '253_guvenlik_kapanisi.sql', 'tablo', 'user_contact'),
  (280, '254_urun_bosluklari.sql', 'tablo', 'notification_prefs'),
  (281, '255_magaza_sartlari.sql', 'tetikleyici', 'trg_sohbet_suzgeci'),
  (282, '256_kredi_satisi_ve_kapida_iade.sql', 'kisit', 'kapida_ret_sebep'),
  (283, '257_push_makbuzlari.sql', 'indeks', 'push_gonderim_bekleyen'),
  (284, '258_olmayan_kolonlar.sql', 'kolon', 'points_ledger.balance_after'),
  (285, '259_bo_performans_indeksleri.sql', 'indeks', 'ix_visits_date'),
  (286, '260_bo_sunucu_tarafi_toplamlar.sql', 'fonksiyon', 'bo_finance_ozet'),
  (287, '261_rol_kapisi.sql', 'fonksiyon', 'ilan_acabilir_miyim'),
  (288, '261a_rol_uyumlama.sql', 'tablo', 'rol_uyumlama_kaydi'),
  (289, '262_seyahat_duzenle_tam.sql', 'govde', 'update_visit|''purpose'', v_v.purpose),'),
  (290, '263_ana_sayfa_akisi.sql', 'fonksiyon', 'ana_sayfa_akisi'),
  (291, '264_push_ve_api_saglik_raporu.sql', '', ''),
  (292, '265_api_yuzeyi_kapanisi.sql', 'indeks', 'uq_delreq_bekleyen'),
  (293, '266_eksik_bildirimler.sql', 'tablo', 'push_ceviri'),
  (294, '267_ilan_tablosu_anon_sizintisi.sql', '', ''),
  (295, '268_telefon_tekilligi.sql', 'kolon', 'users.phone_kanonik'),
  (296, '268a_telefon_cakismasi.sql', '', ''),
  (297, '269_dogrulama_zinciri.sql', 'tetikleyici', 'on_auth_email_confirmed'),
  (298, '269a_DOGRULAMA_KONTROL.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (299, '269b_AYNA_FARKI.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (300, '270_test_verisi_gorunur.sql', 'fonksiyon', 'test_verisi_tazele'),
  (301, '270a_GORUNURLUK.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (302, '270b_NEDEN_SIZIYOR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (303, '270c_KARAR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (304, '270d_HANGI_KATMAN.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (305, '270e_BASE_YAPISI.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (306, '271_kesfet_son_kapi.sql', '', ''),
  (307, '272_parantez_bypassi.sql', '', ''),
  (308, '273_SEED_KAPSAMI.sql', '', ''),
  (309, '274_istek_tavani_kilidi.sql', 'fonksiyon', 'cron_isi_var'),
  (310, '275_kural_kosullari.sql', 'fonksiyon', 'kural_kart_adi'),
  (311, '276_push_kanallari.sql', 'fonksiyon', 'push_kanali'),
  (312, '277_baglanti_kaldir.sql', 'kolon', 'chat_channels.active'),
  (313, '278_push_kanali_enum.sql', 'govde', 'push_kanali|select public.push_kanali(p_category::text)'),
  (314, '279_sogu_baslangic.sql', 'fonksiyon', 'sogu_baslangic_ozeti'),
  (315, '280_kredi_ve_durum_kilidi.sql', 'kolon', 'sessions.cancel_note'),
  (316, '281_kural_motoru_kapida_dogru.sql', '', ''),
  (317, '282_ban_ve_kvkk_silme.sql', 'kolon', 'users.banned_at'),
  (318, '283_kural_motoru_on_iki_boyut.sql', 'kolon', 'visits.party_size'),
  (319, '284_kural_geri_bildirim_dongusu.sql', 'indeks', 'ix_kural_suphe_acik'),
  (320, '285_kyc_belge_ve_karar.sql', 'kolon', 'verifications.id_status'),
  (321, '286_tanis_cift_satir.sql', 'govde', 'discover_people_prebfilter|c.created_at desc'),
  (322, '287_planim_enum_metin_karsilastirma.sql', 'govde', 'my_plan|''ucretsiz_yukseltme'', (v_g.id is not null and v_etkin::text <> v_satin),'),
  (323, '288_guven_esigi_kolonu.sql', 'govde', 'ilan_guven_esigi_yaz|where coalesce(ts.score, 0) >= p_esik));'),
  (324, '289_davet_kabulu_mevcut_istek.sql', 'govde', 'respond_invite|v_req := v_mevcut.id;'),
  (325, '290_kural_notlari_turkce.sql', 'desen_yok', 'lounge_guest_rules|notes|(UCRETSIZ|YURTDISI|ANLASMALI)'),
  (326, '291_ilan_kaldirma_zorlu.sql', 'govde', 'cancel_availability|İlan geri çekildi'),
  (327, '292_zaman_dilimi_yerel_an.sql', 'fonksiyon', 'yerel_an'),
  (328, '293_davet_cift_onay_ve_ilan_geri_cekme.sql', 'govde', 'respond_invite|insert into sessions (request_id, status)'),
  (329, '294_binis_karti_dogrulama.sql', 'indeks', 'idx_sv_user'),
  (330, '295_ilanin_ikinci_hayati_ve_sayaclar.sql', 'fonksiyon', 'ilani_yeniden_yayinla'),
  (331, '296_hikaye_daveti_erteleme.sql', 'tablo', 'hikaye_ertelemeleri'),
  (332, '297_yetki_kapilari.sql', 'fonksiyon', 'yonetici_kapisi'),
  (333, '298_supurge_kisiti_ve_asim_dedektoru.sql', 'tablo', 'supurge_damgasi'),
  (334, '299_kredi_kilidi_supurge_sahibi_ve_iade_tutari.sql', 'kolon', 'supurge_damgasi.kaynak'),
  (335, '300_uctan_uca_denetim.sql', 'indeks', 'idx_messages_from'),
  (336, '301_guven_ve_akis_tamamlama.sql', 'kolon', 'blocks.sebep'),
  (337, '302_test_hesaplarini_gorenler.sql', 'tablo', 'test_gorunurlugu'),
  (901, 'SEED_KURAL_SENARYOLARI.sql', 'satir', 'users.email=kmisafir1@seed.loungelink.test'),
  (902, 'SEED2_KAYNAK_SENARYOLARI.sql', 'satir', 'users.email=kaynak1@seed.loungelink.test'),
  (903, 'SEED3_UCTAN_UCA.sql', 'satir', 'users.email=host1@seed.loungelink.test'),
  (904, 'SEED4_KURAL_VITRINI.sql', 'sayi', 'availabilities|host_id in (select id from users where email = ''host1@seed.loungelink.test'')|10'),
  (905, 'SEED5_BASVURU_AKISLARI.sql', 'satir', 'users.email=guest3@seed.loungelink.test'),
  (906, 'SEED6_TEST_DUNYASI.sql', 'satir', 'users.email=deniz@sahne.loungelink.test'),
  (907, 'SEED7_TEZGAH.sql', 'sayi', 'invites|status = ''accepted''|1'),
  (908, 'SEED8_AKIS_TEZGAHI.sql', 'satir', 'users.email=akis.host@seed.loungelink.test')
  ) as z(sira, dosya, tip, ad)
 where public.kurulum_imzasi_var(z.tip, z.ad) is true
on conflict (dosya) do nothing;

-- ----------------------------------------------------------------------------
-- 4) TEK SORGU · TEK TABLO
-- ----------------------------------------------------------------------------
with imza(sira, dosya, tip, ad) as (
  values
  (1, '001_initial_schema.sql', 'indeks', 'idx_otp_phone'),
  (2, '002_seed_reference.sql', 'satir', 'lounges.name=Primeclass Lounge'),
  (3, '003_admin_roles.sql', 'tablo', 'admin_roles'),
  (4, '004_auth_bridge.sql', 'tetikleyici', 'on_auth_user_created'),
  (5, '005_reference_read.sql', 'politika', 'lounges|lounges_read'),
  (6, '006_discovery_read.sql', 'politika', 'profiles|profiles_read_auth'),
  (7, '007_request_engine.sql', 'fonksiyon', 'create_request'),
  (8, '008_chat_sessions.sql', 'politika', 'messages|msg_read'),
  (9, '009_phone_otp.sql', 'fonksiyon', 'send_otp'),
  (10, '010_profile_write.sql', 'politika', 'profiles|profiles_self_update'),
  (11, '011_notifications.sql', 'politika', 'notifications|notif_own_read'),
  (12, '012_women_safety.sql', 'fonksiyon', 'discover_availabilities'),
  (13, '013_push_tokens.sql', 'tablo', 'push_tokens'),
  (14, '014_push_trigger.sql', 'tetikleyici', 'on_notification_created'),
  (15, '015_connections.sql', 'politika', 'connection_requests|conn_own_read'),
  (16, '016_match_score.sql', '', ''),
  (17, '017_marketplace.sql', 'tablo', 'rewards'),
  (18, '018_subscriptions.sql', 'tablo', 'plan_catalog'),
  (19, '019_admin_management.sql', 'fonksiyon', 'admin_adjust_credit'),
  (20, '020_rbac.sql', 'kolon', 'admin_roles.created_by'),
  (21, '021_moderation_tools.sql', 'fonksiyon', 'remove_rating'),
  (22, '022_rewards_parity.sql', 'satir', 'rewards.title=Emirates Skywards 750 Mil'),
  (23, '023_partner_portal.sql', 'tablo', 'lounge_partners'),
  (24, '024a_PRE_drop_old_discovery.sql', 'eslikci', '024_avatars_storage.sql'),
  (25, '024_avatars_storage.sql', 'politika', 'storage|avatars_read'),
  (26, '025_role_on_signup.sql', 'govde', 'handle_new_user|); exception when others then r :='),
  (27, '026a_PRE_drop.sql', 'eslikci', '026_doc_parity_core.sql'),
  (28, '026_doc_parity_core.sql', 'kolon', 'profiles.access_source'),
  (29, '027_companion_chat.sql', 'kolon', 'chat_channels.kind'),
  (30, '028_referral.sql', 'kolon', 'profiles.referred_by'),
  (31, '029_bo_requirements.sql', 'kolon', 'rewards.stock'),
  (32, '030_match_and_broadcast.sql', 'kolon', 'invites.responded_at'),
  (33, '031_cleanup_overloads.sql', '', ''),
  (34, '032_p2_flows.sql', 'kolon', 'sessions.rate_deferred_by'),
  (35, '033a_PRE_drop.sql', 'eslikci', '033_beta_credits_dualrole_radar.sql'),
  (36, '033_beta_credits_dualrole_radar.sql', 'kolon', 'credit_ledger.note'),
  (37, '034_lounge_radar.sql', 'tablo', 'blocks'),
  (38, '035a_PRE_drop.sql', 'eslikci', '035_password_flow.sql'),
  (39, '035_password_flow.sql', 'kolon', 'admin_roles.must_change_password'),
  (40, '036a_PRE_drop.sql', 'eslikci', '036_host_applications.sql'),
  (41, '036_host_applications.sql', 'indeks', 'idx_host_app_status'),
  (42, '037a_PRE_drop.sql', 'eslikci', '037_admin_verifications.sql'),
  (43, '037_admin_verifications.sql', 'fonksiyon', 'admin_set_verification'),
  (44, '038_SQL_DURUM.sql', '', ''),
  (45, '039_DOGRULAMA.sql', '', ''),
  (46, '040a_PRE_drop.sql', 'eslikci', '040_visibility_and_discovery_fix.sql'),
  (47, '040_visibility_and_discovery_fix.sql', 'kolon', 'availabilities.min_trust'),
  (48, '041_staff_accounts_excluded.sql', 'kolon', 'users.is_staff'),
  (49, '042_reports_and_sos.sql', 'kolon', 'reports.is_urgent'),
  (50, '043_admin_data_cleanup.sql', 'fonksiyon', 'admin_list_visits'),
  (51, '044a_PRE_drop.sql', 'eslikci', '044_trip_purpose_and_people_fix.sql'),
  (52, '044_trip_purpose_and_people_fix.sql', 'kolon', 'visits.purpose'),
  (53, '045_admin_edit_email_phone.sql', 'fonksiyon', 'admin_set_email'),
  (54, '046a_PRE_drop.sql', 'eslikci', '046_trust_and_host_visibility.sql'),
  (55, '046_trust_and_host_visibility.sql', 'fonksiyon', 'host_requests'),
  (56, '047a_PRE_drop.sql', 'eslikci', '047_campaign_targets.sql'),
  (57, '047_campaign_targets.sql', 'govde', 'send_campaign|and u.deleted_at is null'),
  (58, '048a_PRE_drop.sql', 'eslikci', '048_promo_campaigns.sql'),
  (59, '048_promo_campaigns.sql', 'tablo', 'promo_codes'),
  (60, '049a_PRE_drop.sql', 'eslikci', '049_discovery_safety_phone_delete.sql'),
  (61, '049_discovery_safety_phone_delete.sql', 'kolon', 'promo_campaigns.joinable'),
  (62, '050a_PRE_drop.sql', 'eslikci', '050_host_requests_flight.sql'),
  (63, '050_host_requests_flight.sql', 'govde', 'host_requests|b.gflight as flight_number'),
  (64, '051_beta_visibility_reset_and_diagnoz.sql', '', ''),
  (65, '052_session_live_status.sql', 'kolon', 'sessions.host_status'),
  (66, '053_unstaff_founder_and_diag.sql', '', ''),
  (67, '054a_PRE_drop.sql', 'eslikci', '054_discover_people_include_hosts.sql'),
  (68, '054_discover_people_include_hosts.sql', '', ''),
  (69, '055_listing_makes_host.sql', '', ''),
  (70, '056_supply_demand_match_notify.sql', '', ''),
  (71, '057_waiting_demand_rpc.sql', 'fonksiyon', 'waiting_demand'),
  (72, '058_fix_stale_staff_roles.sql', '', ''),
  (73, '059a_PRE_drop.sql', 'eslikci', '059_discover_everyone_request_gate.sql'),
  (74, '059_discover_everyone_request_gate.sql', '', ''),
  (75, '060_security_hardening.sql', 'politika', 'reports|reports_select_own'),
  (76, '061_fix_respond_request_and_slots.sql', 'indeks', 'idx_conn_to'),
  (77, '062_fix_verify_otp.sql', 'ayar', 'otp_demo_bypass'),
  (78, '063_error_logging.sql', 'indeks', 'idx_app_errors_time'),
  (79, '064_fix_overloads_and_discovery.sql', '', ''),
  (80, '065_fix_create_request.sql', 'kolon', 'requests.purpose'),
  (81, '066_request_status_completed.sql', 'enum_degeri', 'request_status.completed'),
  (82, '067_fix_confirm_session_enum.sql', '', ''),
  (83, '068_fix_rate_session.sql', '', ''),
  (84, '069_fix_respond_connection_cast.sql', 'govde', 'respond_connection|on conflict (connection_id) where connection_id is not null do nothing'),
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
  (95, '077_session_autostart_intro_slots.sql', 'tetikleyici', 'trg_requests_sync_filled'),
  (96, '078_trust_single_writer.sql', 'govde', 'compute_trust_badge|else ''basic'' end'),
  (97, '079_email_otp_contact_verification.sql', 'fonksiyon', 'is_contact_verified'),
  (98, '080_session_lifecycle.sql', 'enum_degeri', 'session_status.pending'),
  (99, '081a_PRE_drop.sql', 'eslikci', '081_pending_ratings_link.sql'),
  (100, '081_pending_ratings_link.sql', 'fonksiyon', 'unrated_sessions'),
  (101, '082_rate_limiting.sql', 'tetikleyici', 'trg_rl_visits'),
  (102, '083_lounge_rules_and_flight_prep.sql', 'kolon', 'visits.terminal'),
  (103, '084_deletion_requests.sql', 'indeks', 'idx_delreq_status'),
  (104, '085_lounge_rules_v2.sql', 'kolon', 'availabilities.rule_note'),
  (105, '086a_PRE_drop.sql', 'eslikci', '086_lounge_rules_v3.sql'),
  (106, '086_lounge_rules_v3.sql', 'kolon', 'lounges.venue_id'),
  (107, '087a_PRE_drop.sql', 'eslikci', '087_entitlements_and_coverage.sql'),
  (108, '087_entitlements_and_coverage.sql', 'kolon', 'host_entitlements.quota_used'),
  (109, '088_card_catalog.sql', 'kolon', 'lounge_card_products.segment'),
  (110, '089_missing_columns.sql', '', ''),
  (111, '090_rules_to_app.sql', 'kolon', 'lounge_card_products.guest_quota_total'),
  (112, '091_flight_quota.sql', 'kisit', 'ffl_outcome_chk'),
  (113, '092_host_access_declaration.sql', 'kolon', 'profiles.guest_fee_expected'),
  (114, '093_reward_featured.sql', 'kolon', 'rewards.is_featured'),
  (115, '094_admin_erasure.sql', 'kolon', 'users.anonymized_at'),
  (116, '095_close_the_loop.sql', 'fonksiyon', 'submit_field_report'),
  (117, '096_rule_autofill.sql', 'fonksiyon', 'autofill_venue_acceptance'),
  (118, '097_ajet_and_tk_detail.sql', '', ''),
  (119, '098_full_rule_matrix.sql', '', ''),
  (120, '099_card_networks_venue_level.sql', 'kolon', 'lounge_venues.venue_kind'),
  (121, '100_tier_fee_and_time.sql', 'kolon', 'lounge_programs.fee_payer'),
  (122, '101_sections_charter_expiry.sql', 'kolon', 'lounge_venues.section_of'),
  (123, '102_badge_wording.sql', 'ayar', 'badge_labels'),
  (124, '103_consolidate_and_charter.sql', 'fonksiyon', 'venue_norm'),
  (125, '104_tier_rules_program_level.sql', 'govde', 'lounge_access_decision_v3|, coalesce(v_head, d ->>'),
  (126, '105_fee_wording_and_business.sql', 'govde', 'lounge_access_decision_v3|Misafir girişi ücretli — ücret host'),
  (127, '106_channel_fees_and_bank_deals.sql', '', ''),
  (128, '107_missing_airports.sql', 'satir', 'airports.code=DLM'),
  (129, '108_paid_guest_settlement.sql', 'indeks', 'uq_field_report_once'),
  (130, '109_pegasus_and_overloads.sql', '', ''),
  (131, '110_family_abroad.sql', '', ''),
  (132, '111_push_direct_expo.sql', 'kolon', 'push_tokens.active'),
  (133, '112_blocks_in_discovery.sql', 'fonksiyon', 'is_blocked_pair'),
  (134, '113_dedupe_and_wording.sql', 'govde', 'venue_norm|ıİşŞğĞüÜöÖçÇÂâÎî'),
  (135, '114_card_confidence_visible.sql', 'fonksiyon', 'card_confidence_note'),
  (136, '115_quota_who_says.sql', 'ayar', 'quota_note_host'),
  (137, '116_badges_gate_and_sort.sql', 'govde', 'discovery_rule_badges|v_block := false;'),
  (138, '117_carrier_field.sql', 'kolon', 'visits.carrier_code'),
  (139, '118_carrier_in_rules.sql', 'fonksiyon', 'carrier_match'),
  (140, '119_precheck_v5_and_charter.sql', 'kolon', 'visits.is_charter'),
  (141, '120_human_text.sql', 'ayar', 'head_charter'),
  (142, '121_source_summary.sql', 'fonksiyon', 'access_source_summary'),
  (143, '122_what_can_i_do.sql', 'ayar', 'alt_note_some'),
  (144, '123_overload_cleanup.sql', '', ''),
  (145, '124_card_catalog_verified.sql', 'kisit', 'lcp_q_period_chk'),
  (146, '125_saw_plaza_partners.sql', 'indeks', 'ix_lvp_venue'),
  (147, '126_partners_visible.sql', 'fonksiyon', 'venue_partners'),
  (148, '127_ist_tk_from_iga.sql', '', ''),
  (149, '128_iga_lounge_and_conflicts.sql', 'kolon', 'lounge_venue_acceptance.source_conflict'),
  (150, '129_conflict_surfaced.sql', 'govde', 'lounge_access_decision_v5|if v_conf is not null then'),
  (151, '130_amenities.sql', 'kolon', 'lounge_venues.amenities'),
  (152, '131_card_advisor.sql', 'ayar', 'advice_intro'),
  (153, '132_travel_style.sql', 'kolon', 'profiles.travel_style'),
  (154, '133_catalog_dedupe.sql', '', ''),
  (155, '134_tier_label_everywhere.sql', 'govde', 'lounge_access_decision_v3|coalesce(public.card_tier_label(v_ent.tier), ''Bu kart''))'),
  (156, '135_short_and_honest.sql', 'govde', 'discovery_rule_badges|v_key := ''guest_none_soft''; v_boost := -200;'),
  (157, '136_otp_honesty.sql', 'kolon', 'verifications.phone_verified_method'),
  (158, '137_placeholder_vs_data.sql', 'kolon', 'lounge_venue_acceptance.is_placeholder'),
  (159, '138_email_otp.sql', 'ayar', 'otp_notice_email'),
  (160, '139_final_polish.sql', '', ''),
  (161, '140_rls_and_ratelimit.sql', 'tablo', 'rate_limits'),
  (162, '141_deletion_flow_check.sql', 'fonksiyon', 'request_account_deletion'),
  (163, '142_short_detail_hard.sql', 'fonksiyon', 'clip_text'),
  (164, '143_lounge_guide.sql', 'fonksiyon', 'guide_lounges'),
  (165, '144_guide_fixes.sql', 'govde', 'guide_lounges|then v.name || '' — Business'''),
  (166, '145_null_sort_guard.sql', 'govde', 'card_product_options|cp.quota_total, cp.quota_period, cp.conditions,'),
  (167, '146_tk_official_matrix.sql', 'ayar', 'tk_paid_entry_2026'),
  (168, '147_tier_resolver.sql', 'fonksiyon', 'resolve_guest_rule'),
  (169, '148_rule_matrix_test.sql', 'fonksiyon', 'rule_matrix_check'),
  (170, '149_multi_entitlement.sql', 'fonksiyon', 'best_entitlement'),
  (171, '150_network_rules_and_guard.sql', 'fonksiyon', 'rule_contamination_check'),
  (172, '151_deterministic_program_pick.sql', 'fonksiyon', 'pick_host_program'),
  (173, '152_field_reports_loop.sql', 'kolon', 'lounge_field_reports.entered'),
  (174, '153_host_motivation.sql', 'kolon', 'profiles.founding_host_no'),
  (175, '154_membership_tiers.sql', 'kolon', 'lounge_guest_rules.guest_entry_fee'),
  (176, '155_member_cost_visible.sql', 'fonksiyon', 'guide_cost'),
  (177, '156_official_alignment_and_scope.sql', 'kolon', 'lounge_guest_rules.venue_scope'),
  (178, '157_decision_uses_resolver.sql', 'fonksiyon', 'decision_chain_check'),
  (179, '158_device_findings.sql', 'govde', 'guide_lounges|(exists (select 1 from lounge_venue_acceptance ac'),
  (180, '159_grants_home_flows_request_gate.sql', 'kolon', 'connection_requests.responded_at'),
  (181, '160_catalog_name_dedupe.sql', '', ''),
  (182, '161_venue_merge_and_catalog_truth.sql', '', ''),
  (183, '162_source_truth_and_founder_badge.sql', 'fonksiyon', 'founding_badge_sync'),
  (184, '163_unknown_carrier_and_coverage_audit.sql', 'fonksiyon', 'rule_coverage_audit'),
  (185, '164_business_ticket_and_operator_rules.sql', 'govde', 'rule_coverage_audit|Hiç kuralı olmayan aktif program'),
  (186, '165_prebeta_security.sql', 'tetikleyici', 'trg_guard_otp_bypass'),
  (187, '166_slot_integrity_and_flow_tests.sql', 'fonksiyon', 'flow_gate_test'),
  (188, '167_rule_expectation_matrix.sql', 'indeks', 'uq_rule_test_case'),
  (189, '168_carrier_gap_and_paid_entry.sql', 'kural_notu', 'lounge_guest_rules|Bu kart tipinin hiçbir taşıyıcıda ve hiçbir kapsamda misafir hakkı yoktur.'),
  (190, '169_slot_counter_repair.sql', '', ''),
  (191, '170_resolution_order_fix.sql', '', ''),
  (192, '171_full_matrix_and_report.sql', 'kolon', 'rule_test_cases.needs_review'),
  (193, '172_resolver_full_definition.sql', 'govde', 'resolve_guest_rule|and (p_tier is null or x.card_tier is null)'),
  (194, '173_showcase_data.sql', '', ''),
  (195, '174_venue_beats_program_rule.sql', 'govde', 'rule_venue_test|✗ SALON KURALI ÇELİŞİYOR'),
  (196, '175_flow_test_cleanup_fix.sql', 'fonksiyon', 'flow_test_cleanup'),
  (197, '176_flow_test_rate_limit.sql', 'govde', 'rl_guard|if coalesce(current_setting(''ll.test_mode'', true), '''') = ''on'' then'),
  (198, '177_official_table_reconciliation.sql', 'govde', 'rule_matrix_test|(ac.id is not null) desc, v.id'),
  (199, '178_expectations_single_source.sql', 'fonksiyon', 'rebuild_rule_test_cases'),
  (200, '179_flow_test_skip_semantics.sql', 'fonksiyon', 'flow_env_block'),
  (201, '180_flow_test_future_availability.sql', 'govde', 'flow_env_block|''%self_request%'','),
  (202, '181_credit_model_rebalance.sql', 'ayar_deger', 'host_door_bonus_points=50'),
  (203, '182_discover_carries_decision.sql', 'fonksiyon', 'discover_availabilities_base'),
  (204, '183_lounges_rpc_and_grants.sql', 'fonksiyon', 'lounges_for_airport'),
  (205, '184_ms_status_language.sql', 'govde', 'card_tier_label|Miles&Smiles Amex'),
  (206, '185_device_flow_proofs.sql', 'fonksiyon', 'device_flow_check'),
  (207, '186_context_for_cards.sql', 'fonksiyon', 'my_sent_requests'),
  (208, '187a_PRE_asiri_yukleme_temizligi.sql', 'eslikci', '187_kanitlanmis_kusurlar.sql'),
  (209, '187_kanitlanmis_kusurlar.sql', 'fonksiyon', 'rpc_smoke_test'),
  (210, '188_salon_envanteri.sql', '', ''),
  (211, '189_coklu_hak_ve_kaynak_hizalama.sql', 'fonksiyon', 'best_access_for_user'),
  (212, '190_salon_tekillestirme_ve_bolum.sql', 'fonksiyon', 'brand_key'),
  (213, '191_kaynak_celiskileri_ve_bosluklar.sql', 'kolon', 'availabilities.cabin_class'),
  (214, '192a_PRE_charter_tabanda.sql', '', ''),
  (215, '192_on_kontrol_kapi_hizalama.sql', 'govde', 'request_precheck|Bu ilana misafir alınamıyor'),
  (216, '193_kart_etiketi_ve_kabin_yazma.sql', 'fonksiyon', 'save_host_card'),
  (217, '194_bekleme_listesi.sql', 'kisit', 'wl_role_chk'),
  (218, '195_ucus_alanlari_ve_kod_paylasimi.sql', 'kolon', 'flight_cache.airline'),
  (219, '196_plan_ucretleri_ve_celiski_kapanisi.sql', 'indeks', 'uq_venue_prices'),
  (220, '197_seyahatin_ucus_bilgisi_dolsun.sql', 'tetikleyici', 'trg_visit_flight_ins'),
  (221, '198_thy_ajet_ms_yeniden_dogrulama.sql', 'indeks', 'uq_entry_tariff'),
  (222, '199_ucus_saati_terminal_ve_katalog.sql', 'tetikleyici', 'trg_venue_catalog_ins'),
  (223, '200_ulke_sozlugu_tekillestirme.sql', 'tablo', 'country_aliases'),
  (224, '201_banka_karti_tek_cerceve.sql', 'kolon', 'host_entitlements.bank_covers_fee'),
  (225, '202_saat_dilimi_ajet_anahtari_pencere.sql', 'tetikleyici', 'trg_ajet_intl'),
  (226, '203_guvenlik_siniri.sql', 'tablo', 'rpc_client_surface'),
  (227, '204_blok_eylem_sinirinda.sql', 'tetikleyici', 'trg_blok_gecmis'),
  (228, '205_bo_adresi_kendini_kaydeder.sql', 'ayar', 'backoffice_url'),
  (229, '206_host_motoru.sql', 'tablo', 'host_tiers'),
  (230, '207_kopruler_ve_verilen_sozler.sql', 'kolon', 'host_tiers.one_cikar_saat'),
  (231, '208_donem_devri_ve_kalibrasyon.sql', 'indeks', 'idx_credit_requests_status'),
  (232, '209_saglayici_modulu.sql', 'ayar_deger', 'partner_k_threshold=5'),
  (233, '210a_PRE_plan_enum.sql', 'enum_degeri', 'plan_type.yolcu'),
  (234, '210b_PRE_push_dayanikli.sql', '', ''),
  (235, '210_abonelik_push_ve_kapsam.sql', 'kolon', 'plan_catalog.ad'),
  (236, '211_kart_aglari_kaynaktan.sql', 'kolon', 'card_network_source.kart_no'),
  (237, '212_yonetilen_ayarlar_gercekten_okunuyor.sql', 'kolon', 'i18n_strings.note'),
  (238, '213_saglayici_kurumsal_katman.sql', 'rpc_yuzeyi', 'venue_no_show'),
  (239, '214a_PRE_ic_hat_salonlari.sql', 'eslikci', '214_misafir_hakki_kaynaktan.sql'),
  (240, '214_misafir_hakki_kaynaktan.sql', 'kolon', 'lounge_venues.is_umbrella'),
  (241, '215_saglayici_veri_yollari.sql', 'kolon', 'availabilities.program_source'),
  (242, '216_hangi_kartimi_kullanayim.sql', 'rpc_yuzeyi', 'hangi_kartimi_kullanayim'),
  (243, '217_misafir_ucreti_geri.sql', 'kolon', 'lounge_guest_rules.yillik_para'),
  (244, '218_radar_olu_kolonlar.sql', 'govde', 'lounge_radar_people|or (c.to_id=v_uid and c.from_id=pe.uid)'),
  (245, '219_kredi_ve_ucret_dili.sql', 'ayar_deger', 'paid_guest_credits=1'),
  (246, '220_plan_katalogu_ve_dil.sql', 'kolon', 'plan_catalog.ad_en'),
  (247, '221_hosta_sor.sql', 'ayar', 'err_rule_ask_daily_limit'),
  (248, '222_ucretli_misafir_geri.sql', 'govde', 'lounge_access_decision|,            case when coalesce(d ->>'),
  (249, '223_sinirlar_dogruyu_soylesin.sql', 'ayar', 'err_rate_limited'),
  (250, '224_borclar_ve_ilan_neden_yok.sql', 'rpc_yuzeyi', 'ucus_kotam'),
  (251, '225_planin_sozu_tutulsun.sql', 'rpc_yuzeyi', 'plan_kredisi_yerlestir'),
  (252, '226_zamanlanmis_isler.sql', '', ''),
  (253, '227_seed_giris_onarimi.sql', '', ''),
  (254, '228_odul_katalogu_takas_kapaniyor.sql', 'kisit', 'rewards_no_lounge_barter_chk'),
  (255, '229_odul_teslim_sozu.sql', 'kolon', 'redemptions.durum'),
  (256, '230_host_hikayeleri.sql', 'kisit', 'hs_yayin_riza_chk'),
  (257, '231_kurucu_cember_sayaci.sql', 'ayar_deger', 'kurucu_kontenjan=100'),
  (258, '232_rol_kapisi_ve_cuzdan_sizintisi.sql', 'kolon', 'users.role_source'),
  (259, '233_statu_listesi_tekillesiyor.sql', 'govde', 'card_tier_options|r.notes nulls last;'),
  (260, '234_aktif_oturum_kendini_anlatsin.sql', 'rpc_yuzeyi', 'aktif_oturum_detay'),
  (261, '235_sordugunu_gorebilmeli.sql', 'tetikleyici', 'trg_cr_soru_izi'),
  (262, '236_ust_plan_bir_ay_ucretsiz.sql', 'indeks', 'uq_plan_grants_aktif'),
  (263, '237_ilan_ve_seyahat_duzenlenebilsin.sql', 'tetikleyici', 'trg_avail_kapatma_kapisi'),
  (264, '238_cuzdan_ve_soru_dili.sql', 'tetikleyici', 'trg_cr_soru_metni'),
  (265, '239_soru_hangi_ilana_ait.sql', 'kolon', 'connection_requests.avail_id'),
  (266, '240_kural_kapida_degil_odada.sql', 'tetikleyici', 'trg_visit_sozlesme'),
  (267, '241_supabase_varsayilani_kapatiliyor.sql', 'tablo', 'client_write_allowlist'),
  (268, '242_gorunumler_arka_kapi.sql', '', ''),
  (269, '243_one_cikarma_gercekten_calissin.sql', 'ayar_deger', 'one_cikan_esz_tavan_host=1'),
  (270, '244_odul_ekonomisi.sql', 'kolon', 'rewards.maliyet_turu'),
  (271, '245_vitrin_gokberkin_listesi.sql', 'kolon', 'rewards.zarar_gerekce'),
  (272, '246_ekonomi_ayari.sql', 'kolon', 'plan_catalog.acik_istek_tavani'),
  (273, '247_haber_ver.sql', 'indeks', 'talep_kayit_arama'),
  (274, '248_duzenleme_baglanti_degerlendirme.sql', 'tablo', 'kredi_paketleri'),
  (275, '249_is_modeli_ve_soguk_ag.sql', 'kolon', 'requests.decision_note'),
  (276, '250_yaptirim_huni_dil_ve_kapilar.sql', 'kolon', 'profiles.dil'),
  (277, '251_cron_nobeti_ve_kahya_ayricaligi.sql', 'kolon', 'host_tiers.sinirsiz_kural_sorusu'),
  (278, '252_ulasilabilirlik_ve_push_izni.sql', 'kisit', 'push_izin_durum_kapisi'),
  (279, '253_guvenlik_kapanisi.sql', 'tablo', 'user_contact'),
  (280, '254_urun_bosluklari.sql', 'tablo', 'notification_prefs'),
  (281, '255_magaza_sartlari.sql', 'tetikleyici', 'trg_sohbet_suzgeci'),
  (282, '256_kredi_satisi_ve_kapida_iade.sql', 'kisit', 'kapida_ret_sebep'),
  (283, '257_push_makbuzlari.sql', 'indeks', 'push_gonderim_bekleyen'),
  (284, '258_olmayan_kolonlar.sql', 'kolon', 'points_ledger.balance_after'),
  (285, '259_bo_performans_indeksleri.sql', 'indeks', 'ix_visits_date'),
  (286, '260_bo_sunucu_tarafi_toplamlar.sql', 'fonksiyon', 'bo_finance_ozet'),
  (287, '261_rol_kapisi.sql', 'fonksiyon', 'ilan_acabilir_miyim'),
  (288, '261a_rol_uyumlama.sql', 'tablo', 'rol_uyumlama_kaydi'),
  (289, '262_seyahat_duzenle_tam.sql', 'govde', 'update_visit|''purpose'', v_v.purpose),'),
  (290, '263_ana_sayfa_akisi.sql', 'fonksiyon', 'ana_sayfa_akisi'),
  (291, '264_push_ve_api_saglik_raporu.sql', '', ''),
  (292, '265_api_yuzeyi_kapanisi.sql', 'indeks', 'uq_delreq_bekleyen'),
  (293, '266_eksik_bildirimler.sql', 'tablo', 'push_ceviri'),
  (294, '267_ilan_tablosu_anon_sizintisi.sql', '', ''),
  (295, '268_telefon_tekilligi.sql', 'kolon', 'users.phone_kanonik'),
  (296, '268a_telefon_cakismasi.sql', '', ''),
  (297, '269_dogrulama_zinciri.sql', 'tetikleyici', 'on_auth_email_confirmed'),
  (298, '269a_DOGRULAMA_KONTROL.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (299, '269b_AYNA_FARKI.sql', 'eslikci', '269_dogrulama_zinciri.sql'),
  (300, '270_test_verisi_gorunur.sql', 'fonksiyon', 'test_verisi_tazele'),
  (301, '270a_GORUNURLUK.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (302, '270b_NEDEN_SIZIYOR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (303, '270c_KARAR.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (304, '270d_HANGI_KATMAN.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (305, '270e_BASE_YAPISI.sql', 'eslikci', '270_test_verisi_gorunur.sql'),
  (306, '271_kesfet_son_kapi.sql', '', ''),
  (307, '272_parantez_bypassi.sql', '', ''),
  (308, '273_SEED_KAPSAMI.sql', '', ''),
  (309, '274_istek_tavani_kilidi.sql', 'fonksiyon', 'cron_isi_var'),
  (310, '275_kural_kosullari.sql', 'fonksiyon', 'kural_kart_adi'),
  (311, '276_push_kanallari.sql', 'fonksiyon', 'push_kanali'),
  (312, '277_baglanti_kaldir.sql', 'kolon', 'chat_channels.active'),
  (313, '278_push_kanali_enum.sql', 'govde', 'push_kanali|select public.push_kanali(p_category::text)'),
  (314, '279_sogu_baslangic.sql', 'fonksiyon', 'sogu_baslangic_ozeti'),
  (315, '280_kredi_ve_durum_kilidi.sql', 'kolon', 'sessions.cancel_note'),
  (316, '281_kural_motoru_kapida_dogru.sql', '', ''),
  (317, '282_ban_ve_kvkk_silme.sql', 'kolon', 'users.banned_at'),
  (318, '283_kural_motoru_on_iki_boyut.sql', 'kolon', 'visits.party_size'),
  (319, '284_kural_geri_bildirim_dongusu.sql', 'indeks', 'ix_kural_suphe_acik'),
  (320, '285_kyc_belge_ve_karar.sql', 'kolon', 'verifications.id_status'),
  (321, '286_tanis_cift_satir.sql', 'govde', 'discover_people_prebfilter|c.created_at desc'),
  (322, '287_planim_enum_metin_karsilastirma.sql', 'govde', 'my_plan|''ucretsiz_yukseltme'', (v_g.id is not null and v_etkin::text <> v_satin),'),
  (323, '288_guven_esigi_kolonu.sql', 'govde', 'ilan_guven_esigi_yaz|where coalesce(ts.score, 0) >= p_esik));'),
  (324, '289_davet_kabulu_mevcut_istek.sql', 'govde', 'respond_invite|v_req := v_mevcut.id;'),
  (325, '290_kural_notlari_turkce.sql', 'desen_yok', 'lounge_guest_rules|notes|(UCRETSIZ|YURTDISI|ANLASMALI)'),
  (326, '291_ilan_kaldirma_zorlu.sql', 'govde', 'cancel_availability|İlan geri çekildi'),
  (327, '292_zaman_dilimi_yerel_an.sql', 'fonksiyon', 'yerel_an'),
  (328, '293_davet_cift_onay_ve_ilan_geri_cekme.sql', 'govde', 'respond_invite|insert into sessions (request_id, status)'),
  (329, '294_binis_karti_dogrulama.sql', 'indeks', 'idx_sv_user'),
  (330, '295_ilanin_ikinci_hayati_ve_sayaclar.sql', 'fonksiyon', 'ilani_yeniden_yayinla'),
  (331, '296_hikaye_daveti_erteleme.sql', 'tablo', 'hikaye_ertelemeleri'),
  (332, '297_yetki_kapilari.sql', 'fonksiyon', 'yonetici_kapisi'),
  (333, '298_supurge_kisiti_ve_asim_dedektoru.sql', 'tablo', 'supurge_damgasi'),
  (334, '299_kredi_kilidi_supurge_sahibi_ve_iade_tutari.sql', 'kolon', 'supurge_damgasi.kaynak'),
  (335, '300_uctan_uca_denetim.sql', 'indeks', 'idx_messages_from'),
  (336, '301_guven_ve_akis_tamamlama.sql', 'kolon', 'blocks.sebep'),
  (337, '302_test_hesaplarini_gorenler.sql', 'tablo', 'test_gorunurlugu'),
  (901, 'SEED_KURAL_SENARYOLARI.sql', 'satir', 'users.email=kmisafir1@seed.loungelink.test'),
  (902, 'SEED2_KAYNAK_SENARYOLARI.sql', 'satir', 'users.email=kaynak1@seed.loungelink.test'),
  (903, 'SEED3_UCTAN_UCA.sql', 'satir', 'users.email=host1@seed.loungelink.test'),
  (904, 'SEED4_KURAL_VITRINI.sql', 'sayi', 'availabilities|host_id in (select id from users where email = ''host1@seed.loungelink.test'')|10'),
  (905, 'SEED5_BASVURU_AKISLARI.sql', 'satir', 'users.email=guest3@seed.loungelink.test'),
  (906, 'SEED6_TEST_DUNYASI.sql', 'satir', 'users.email=deniz@sahne.loungelink.test'),
  (907, 'SEED7_TEZGAH.sql', 'sayi', 'invites|status = ''accepted''|1'),
  (908, 'SEED8_AKIS_TEZGAHI.sql', 'satir', 'users.email=akis.host@seed.loungelink.test')
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
