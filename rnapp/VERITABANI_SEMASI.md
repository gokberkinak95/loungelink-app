# LoungeLink — VERİTABANI ŞEMASI

_SQL 001–085 uygulanmış NİHAİ hal · 49 tablo · 6 view · 14 enum · 152 fonksiyon_

Bu belge elle yazılmadı: tüm migration'lar yerel PostgreSQL 16'da sırayla
çalıştırıldı ve şema doğrudan veritabanından çıkarıldı. Yani gerçekten
Supabase'de oluşacak hâlin birebir aynısı.

İlgili dosyalar: `ON_KONTROL_kisitlar.sql` (migration öncesi veri taraması),
`E2E_KARSILIKLI_SUPABASE.sql` (uçtan uca akış testi).

## ENUM TİPLERİ

- **availability_visibility**: Public, Connections, Hidden
- **connection_status**: pending, accepted, declined, blocked
- **dispute_status**: open, resolved, rejected
- **notif_category**: requests, sessions, invites, connections, system, safety, credits, ratings
- **plan_type**: explorer, traveler, frequent
- **profile_visibility**: Everyone, Trusted+, Connections
- **report_status**: open, reviewing, resolved, dismissed
- **report_type**: harassment, fraud, fake_profile, off_platform_payment, other
- **request_status**: pending, accepted, declined, cancelled, expired, completed
- **request_type**: standard, direct_invite
- **session_status**: pending, active, completed, cancelled, expired
- **subscription_status**: active, cancelled, past_due, trialing
- **user_gender**: female, male, other, prefer_not_to_say
- **user_role**: host, guest, admin

## TABLOLAR

### admin_roles  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `user_id` | uuid | — | — |
| `role` | text | — | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `permissions` | jsonb | ✓ | '[]'::jsonb |
| `display_name` | text | ✓ | — |
| `created_by` | uuid | ✓ | — |
| `must_change_password` | boolean | — | false |

**Kısıtlar:**
- `admin_roles_role_check` — CHECK ((role = ANY (ARRAY['super_admin'::text, 'ops'::text, 'trust_safety'::text, 'finance'::text, 'partner_manager'::text])))
- `admin_roles_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
- `admin_roles_pkey` — PRIMARY KEY (user_id)

**RLS politikaları:**
- `read own admin role`: (auth.uid() = user_id)

### airports  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `code` | character(3) | — | — |
| `name` | text | — | — |
| `city` | text | ✓ | — |
| `country` | text | ✓ | — |
| `timezone` | text | ✓ | — |

**Kısıtlar:**
- `airports_pkey` — PRIMARY KEY (code)

**RLS politikaları:**
- `airports_read`: true

### app_errors  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | ✓ | — |
| `platform` | text | ✓ | — |
| `app_version` | text | ✓ | — |
| `screen` | text | ✓ | — |
| `code` | text | ✓ | — |
| `message` | text | — | — |
| `context` | jsonb | ✓ | — |
| `created_at` | timestamp with time zone | — | now() |

**Kısıtlar:**
- `app_errors_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
- `app_errors_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `app_errors_insert_own`: -

### audit_log  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | bigint | — | nextval('audit_log_id_seq'::regclass) |
| `actor_id` | uuid | ✓ | — |
| `action` | text | — | — |
| `entity_type` | text | ✓ | — |
| `entity_id` | uuid | ✓ | — |
| `before_data` | jsonb | ✓ | — |
| `after_data` | jsonb | ✓ | — |
| `ip_address` | inet | ✓ | — |
| `user_agent` | text | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `audit_log_actor_id_fkey` — FOREIGN KEY (actor_id) REFERENCES users(id)
- `audit_log_pkey` — PRIMARY KEY (id)

### availabilities  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `host_id` | uuid | — | — |
| `airport_code` | character(3) | — | — |
| `lounge_id` | uuid | ✓ | — |
| `lounge_name` | text | ✓ | — |
| `avail_date` | date | — | — |
| `time_from` | time without time zone | — | — |
| `time_to` | time without time zone | — | — |
| `slots` | smallint | — | 1 |
| `filled` | smallint | — | 0 |
| `visibility` | USER-DEFINED | ✓ | 'Public'::availability_visibility |
| `flight_number` | text | ✓ | — |
| `access_sources` | ARRAY | ✓ | '{}'::text[] |
| `active` | boolean | ✓ | true |
| `created_at` | timestamp with time zone | ✓ | now() |
| `updated_at` | timestamp with time zone | ✓ | now() |
| `featured_until` | timestamp with time zone | ✓ | — |
| `min_trust` | smallint | — | 0 |
| `program_id` | uuid | ✓ | — |
| `venue_id` | uuid | ✓ | — |
| `carrier` | text | ✓ | — |
| `guest_carrier_required` | ARRAY | ✓ | — |
| `rule_entry_hours` | numeric | ✓ | — |
| `rule_note` | text | ✓ | — |

**Kısıtlar:**
- `availabilities_check` — CHECK ((filled <= slots))
- `availabilities_check1` — CHECK ((time_from < time_to))
- `availabilities_min_trust_check` — CHECK (((min_trust >= 0) AND (min_trust <= 100)))
- `availabilities_slots_check` — CHECK (((slots >= 1) AND (slots <= 6)))
- `availabilities_airport_code_fkey` — FOREIGN KEY (airport_code) REFERENCES airports(code)
- `availabilities_host_id_fkey` — FOREIGN KEY (host_id) REFERENCES users(id) ON DELETE CASCADE
- `availabilities_lounge_id_fkey` — FOREIGN KEY (lounge_id) REFERENCES lounges(id)
- `availabilities_program_id_fkey` — FOREIGN KEY (program_id) REFERENCES lounge_programs(id)
- `availabilities_venue_id_fkey` — FOREIGN KEY (venue_id) REFERENCES lounge_venues(id)
- `availabilities_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `avail_host_write`: (auth.uid() = host_id)
- `avail_public_read`: ((visibility = 'Public'::availability_visibility) AND (active = true))

### beta_settings  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `key` | text | — | — |
| `value` | jsonb | — | — |
| `updated_at` | timestamp with time zone | — | now() |
| `updated_by` | text | ✓ | — |

**Kısıtlar:**
- `beta_settings_pkey` — PRIMARY KEY (key)

### blocks  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `blocker` | uuid | — | — |
| `blocked` | uuid | — | — |
| `created_at` | timestamp with time zone | — | now() |

**Kısıtlar:**
- `blocks_blocked_fkey` — FOREIGN KEY (blocked) REFERENCES users(id) ON DELETE CASCADE
- `blocks_blocker_fkey` — FOREIGN KEY (blocker) REFERENCES users(id) ON DELETE CASCADE
- `blocks_pkey` — PRIMARY KEY (blocker, blocked)

**RLS politikaları:**
- `blocks_own`: (blocker = auth.uid())

### campaign_participations  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `campaign_id` | uuid | — | — |
| `user_id` | uuid | — | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `campaign_participations_campaign_id_fkey` — FOREIGN KEY (campaign_id) REFERENCES promo_campaigns(id)
- `campaign_participations_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `campaign_participations_pkey` — PRIMARY KEY (id)
- `campaign_participations_campaign_id_user_id_key` — UNIQUE (campaign_id, user_id)

**RLS politikaları:**
- `part_own_read`: (user_id = auth.uid())

### chat_channels  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `request_id` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `connection_id` | uuid | ✓ | — |
| `kind` | text | ✓ | 'lounge'::text |

**Kısıtlar:**
- `chat_channels_connection_id_fkey` — FOREIGN KEY (connection_id) REFERENCES connection_requests(id) ON DELETE CASCADE
- `chat_channels_request_id_fkey` — FOREIGN KEY (request_id) REFERENCES requests(id)
- `chat_channels_pkey` — PRIMARY KEY (id)
- `chat_channels_request_id_key` — UNIQUE (request_id)

**RLS politikaları:**
- `chan_parties`: (EXISTS ( SELECT 1
- `chat_companion_read`: ((connection_id IS NULL) OR (EXISTS ( SELECT 1

### connection_requests  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `from_id` | uuid | — | — |
| `to_id` | uuid | — | — |
| `intent` | text | ✓ | — |
| `intro` | text | ✓ | — |
| `status` | USER-DEFINED | ✓ | 'pending'::connection_status |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `connection_requests_check` — CHECK ((from_id <> to_id))
- `connection_requests_from_id_fkey` — FOREIGN KEY (from_id) REFERENCES users(id)
- `connection_requests_to_id_fkey` — FOREIGN KEY (to_id) REFERENCES users(id)
- `connection_requests_pkey` — PRIMARY KEY (id)
- `connection_requests_from_id_to_id_key` — UNIQUE (from_id, to_id)

**RLS politikaları:**
- `conn_own_read`: ((from_id = auth.uid()) OR (to_id = auth.uid()))

### consents  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `type` | text | — | — |
| `version` | text | — | — |
| `granted_at` | timestamp with time zone | ✓ | now() |
| `ip_address` | inet | ✓ | — |
| `user_agent` | text | ✓ | — |

**Kısıtlar:**
- `consents_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `consents_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `consents_select_own`: (user_id = auth.uid())

### credit_ledger  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `delta` | integer | — | — |
| `reason` | text | — | — |
| `ref_id` | uuid | ✓ | — |
| `balance_after` | integer | — | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `note` | text | ✓ | — |

**Kısıtlar:**
- `credit_ledger_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `credit_ledger_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `credit_own`: (auth.uid() = user_id)

### deletion_requests  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `email` | text | — | — |
| `note` | text | ✓ | — |
| `source` | text | ✓ | 'web'::text |
| `status` | text | — | 'pending'::text |
| `matched_user_id` | uuid | ✓ | — |
| `handled_by` | uuid | ✓ | — |
| `handled_at` | timestamp with time zone | ✓ | — |
| `resolution` | text | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `deletion_requests_status_check` — CHECK ((status = ANY (ARRAY['pending'::text, 'verified'::text, 'done'::text, 'rejected'::text])))
- `deletion_requests_handled_by_fkey` — FOREIGN KEY (handled_by) REFERENCES users(id)
- `deletion_requests_matched_user_id_fkey` — FOREIGN KEY (matched_user_id) REFERENCES users(id)
- `deletion_requests_pkey` — PRIMARY KEY (id)

### disputes  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `session_id` | uuid | ✓ | — |
| `request_id` | uuid | ✓ | — |
| `opener_id` | uuid | — | — |
| `reason` | text | — | — |
| `detail` | text | ✓ | — |
| `status` | USER-DEFINED | — | 'open'::dispute_status |
| `decision` | text | ✓ | — |
| `decided_by` | uuid | ✓ | — |
| `decided_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `disputes_decided_by_fkey` — FOREIGN KEY (decided_by) REFERENCES users(id)
- `disputes_opener_id_fkey` — FOREIGN KEY (opener_id) REFERENCES users(id) ON DELETE CASCADE
- `disputes_request_id_fkey` — FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE
- `disputes_session_id_fkey` — FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
- `disputes_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `disputes_insert`: -
- `disputes_own`: (opener_id = auth.uid())

### feature_flags  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `key` | text | — | — |
| `enabled` | boolean | — | false |
| `rollout_pct` | integer | — | 100 |
| `description` | text | ✓ | — |
| `updated_by` | uuid | ✓ | — |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `feature_flags_rollout_pct_check` — CHECK (((rollout_pct >= 0) AND (rollout_pct <= 100)))
- `feature_flags_updated_by_fkey` — FOREIGN KEY (updated_by) REFERENCES users(id)
- `feature_flags_pkey` — PRIMARY KEY (key)

**RLS politikaları:**
- `flags_read`: true

### flight_cache  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `flight_no` | text | — | — |
| `flight_date` | date | — | — |
| `departure_iata` | text | ✓ | — |
| `arrival_iata` | text | ✓ | — |
| `scheduled_departure` | timestamp with time zone | ✓ | — |
| `scheduled_arrival` | timestamp with time zone | ✓ | — |
| `terminal` | text | ✓ | — |
| `gate` | text | ✓ | — |
| `status` | text | ✓ | — |
| `raw` | jsonb | ✓ | — |
| `source` | text | ✓ | 'aviationstack'::text |
| `fetched_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `flight_cache_pkey` — PRIMARY KEY (flight_no, flight_date)

**RLS politikaları:**
- `fc_read`: true

### host_applications  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `user_id` | uuid | — | — |
| `access_source` | text | — | — |
| `guest_capacity` | integer | — | — |
| `note` | text | ✓ | — |
| `status` | text | — | 'pending'::text |
| `reviewed_by` | text | ✓ | — |
| `reviewed_at` | timestamp with time zone | ✓ | — |
| `review_note` | text | ✓ | — |
| `created_at` | timestamp with time zone | — | now() |

**Kısıtlar:**
- `host_applications_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `host_applications_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `host_app_own_read`: (user_id = auth.uid())

### i18n_strings  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `key` | text | — | — |
| `lang` | text | — | — |
| `value` | text | ✓ | — |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `i18n_strings_lang_check` — CHECK ((lang = ANY (ARRAY['tr'::text, 'en'::text])))
- `i18n_strings_pkey` — PRIMARY KEY (key, lang)

**RLS politikaları:**
- `i18n_read`: true

### invites  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `host_id` | uuid | — | — |
| `guest_id` | uuid | — | — |
| `avail_id` | uuid | ✓ | — |
| `note` | text | ✓ | — |
| `status` | USER-DEFINED | ✓ | 'pending'::connection_status |
| `created_at` | timestamp with time zone | ✓ | now() |
| `responded_at` | timestamp with time zone | ✓ | — |

**Kısıtlar:**
- `invites_avail_id_fkey` — FOREIGN KEY (avail_id) REFERENCES availabilities(id)
- `invites_guest_id_fkey` — FOREIGN KEY (guest_id) REFERENCES users(id)
- `invites_host_id_fkey` — FOREIGN KEY (host_id) REFERENCES users(id)
- `invites_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `invites_select_party`: ((host_id = auth.uid()) OR (guest_id = auth.uid()))

### lounge_guest_rules  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `program_id` | uuid | — | — |
| `venue_id` | uuid | ✓ | — |
| `carrier` | text | ✓ | — |
| `card_tier` | text | ✓ | — |
| `cabin_class` | text | ✓ | — |
| `guest_allowance` | smallint | — | 0 |
| `family_allowed` | boolean | ✓ | false |
| `guest_must_match_carrier` | boolean | ✓ | false |
| `guest_carrier_whitelist` | ARRAY | ✓ | — |
| `earliest_entry_hours` | numeric | ✓ | — |
| `paid_entry_allowed` | boolean | ✓ | false |
| `paid_entry_price_note` | text | ✓ | — |
| `blocked_reason` | text | ✓ | — |
| `notes` | text | ✓ | — |
| `effective_from` | date | ✓ | — |
| `effective_to` | date | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `lounge_guest_rules_cabin_class_check` — CHECK ((cabin_class = ANY (ARRAY['economy'::text, 'business'::text, 'first'::text])))
- `lounge_guest_rules_guest_allowance_check` — CHECK (((guest_allowance >= 0) AND (guest_allowance <= 6)))
- `lounge_guest_rules_program_id_fkey` — FOREIGN KEY (program_id) REFERENCES lounge_programs(id) ON DELETE CASCADE
- `lounge_guest_rules_venue_id_fkey` — FOREIGN KEY (venue_id) REFERENCES lounge_venues(id) ON DELETE CASCADE
- `lounge_guest_rules_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `lgr_read`: true

### lounge_offers  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `lounge_id` | uuid | — | — |
| `offer_date` | date | — | — |
| `time_from` | time without time zone | — | — |
| `time_to` | time without time zone | — | — |
| `price_try` | integer | — | — |
| `quota` | integer | — | 0 |
| `sold` | integer | — | 0 |
| `status` | text | — | 'pending'::text |
| `approved_by` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `lounge_offers_check` — CHECK ((sold <= quota))
- `lounge_offers_approved_by_fkey` — FOREIGN KEY (approved_by) REFERENCES users(id)
- `lounge_offers_lounge_id_fkey` — FOREIGN KEY (lounge_id) REFERENCES lounges(id) ON DELETE CASCADE
- `lounge_offers_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `offers_partner_rw`: (EXISTS ( SELECT 1
- `offers_public_read`: ((status = 'approved'::text) AND (offer_date >= CURRENT_DATE))

### lounge_partners  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `user_id` | uuid | — | — |
| `lounge_id` | uuid | — | — |
| `role` | text | ✓ | 'viewer'::text |
| `created_at` | timestamp with time zone | ✓ | now() |
| `must_change_password` | boolean | — | false |

**Kısıtlar:**
- `lounge_partners_lounge_id_fkey` — FOREIGN KEY (lounge_id) REFERENCES lounges(id) ON DELETE CASCADE
- `lounge_partners_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `lounge_partners_pkey` — PRIMARY KEY (user_id, lounge_id)

**RLS politikaları:**
- `partner_self`: (user_id = auth.uid())

### lounge_programs  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `code` | text | — | — |
| `name` | text | — | — |
| `kind` | text | — | — |
| `source_url` | text | ✓ | — |
| `rules_version` | text | ✓ | — |
| `checked_at` | date | ✓ | — |
| `notes` | text | ✓ | — |
| `active` | boolean | ✓ | true |
| `created_at` | timestamp with time zone | ✓ | now() |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `lounge_programs_kind_check` — CHECK ((kind = ANY (ARRAY['airline'::text, 'card_program'::text, 'operator'::text, 'bank'::text])))
- `lounge_programs_pkey` — PRIMARY KEY (id)
- `lounge_programs_code_key` — UNIQUE (code)

**RLS politikaları:**
- `lp_read`: (active = true)

### lounge_venues  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `airport_code` | text | — | — |
| `name` | text | — | — |
| `terminal` | text | ✓ | — |
| `section` | text | ✓ | — |
| `operator` | text | ✓ | — |
| `scope` | text | ✓ | — |
| `opens_at` | time without time zone | ✓ | — |
| `closes_at` | time without time zone | ✓ | — |
| `capacity_hint` | integer | ✓ | — |
| `notes` | text | ✓ | — |
| `active` | boolean | ✓ | true |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `lounge_venues_scope_check` — CHECK ((scope = ANY (ARRAY['domestic'::text, 'international'::text, 'both'::text])))
- `lounge_venues_airport_code_fkey` — FOREIGN KEY (airport_code) REFERENCES airports(code)
- `lounge_venues_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `lv_read`: (active = true)

### lounges  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `airport_code` | character(3) | — | — |
| `name` | text | — | — |
| `terminal` | text | ✓ | — |
| `access_types` | ARRAY | ✓ | '{}'::text[] |
| `active` | boolean | ✓ | true |

**Kısıtlar:**
- `lounges_airport_code_fkey` — FOREIGN KEY (airport_code) REFERENCES airports(code)
- `lounges_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `lounges_read`: (active = true)

### messages  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `channel_id` | uuid | — | — |
| `from_id` | uuid | — | — |
| `body` | text | — | — |
| `flagged` | boolean | ✓ | false |
| `flag_reason` | text | ✓ | — |
| `read_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `messages_channel_id_fkey` — FOREIGN KEY (channel_id) REFERENCES chat_channels(id)
- `messages_from_id_fkey` — FOREIGN KEY (from_id) REFERENCES users(id)
- `messages_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `messages_companion_rw`: (EXISTS ( SELECT 1
- `messages_parties`: (EXISTS ( SELECT 1
- `msg_read`: (EXISTS ( SELECT 1
- `msg_write`: -

### notification_campaigns  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `title` | text | — | — |
| `body` | text | ✓ | — |
| `segment` | jsonb | ✓ | '{}'::jsonb |
| `sent_count` | integer | ✓ | 0 |
| `created_by` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `notification_campaigns_created_by_fkey` — FOREIGN KEY (created_by) REFERENCES users(id)
- `notification_campaigns_pkey` — PRIMARY KEY (id)

### notifications  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `category` | USER-DEFINED | — | — |
| `title` | text | — | — |
| `body` | text | ✓ | — |
| `icon` | text | ✓ | — |
| `color` | text | ✓ | — |
| `ref_id` | uuid | ✓ | — |
| `ref_type` | text | ✓ | — |
| `read` | boolean | ✓ | false |
| `read_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `notifications_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `notifications_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `notif_own`: (auth.uid() = user_id)
- `notif_own_read`: (user_id = auth.uid())
- `notif_own_update`: (user_id = auth.uid())

### otp_tokens  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | ✓ | — |
| `phone_e164` | text | ✓ | — |
| `code_hash` | text | — | — |
| `purpose` | text | ✓ | 'phone_verify'::text |
| `attempts` | smallint | ✓ | 0 |
| `expires_at` | timestamp with time zone | — | — |
| `used_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `otp_tokens_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `otp_tokens_pkey` — PRIMARY KEY (id)

### partner_rule_cards  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `lounge_id` | uuid | — | — |
| `rules` | jsonb | — | '{}'::jsonb |
| `status` | text | — | 'draft'::text |
| `approved_by` | uuid | ✓ | — |
| `published_at` | timestamp with time zone | ✓ | — |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `partner_rule_cards_approved_by_fkey` — FOREIGN KEY (approved_by) REFERENCES users(id)
- `partner_rule_cards_lounge_id_fkey` — FOREIGN KEY (lounge_id) REFERENCES lounges(id) ON DELETE CASCADE
- `partner_rule_cards_pkey` — PRIMARY KEY (lounge_id)

**RLS politikaları:**
- `rules_partner_rw`: (EXISTS ( SELECT 1
- `rules_public_read`: (status = 'approved'::text)

### plan_catalog  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `plan` | USER-DEFINED | — | — |
| `monthly_credits` | integer | — | — |
| `price_try` | integer | — | — |
| `perks` | jsonb | ✓ | '[]'::jsonb |
| `sort_order` | integer | ✓ | — |

**Kısıtlar:**
- `plan_catalog_pkey` — PRIMARY KEY (plan)

**RLS politikaları:**
- `plan_catalog_read`: true

### points_ledger  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `delta` | integer | — | — |
| `reason` | text | — | — |
| `ref_id` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `points_ledger_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `points_ledger_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `points_own`: (auth.uid() = user_id)

### profiles  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `user_id` | uuid | — | — |
| `name` | text | — | — |
| `profession` | text | ✓ | — |
| `bio` | text | ✓ | — |
| `languages` | ARRAY | ✓ | '{}'::text[] |
| `linkedin_url` | text | ✓ | — |
| `linkedin_verified` | boolean | ✓ | false |
| `photo_url` | text | ✓ | — |
| `photo_connections_only` | boolean | ✓ | false |
| `profile_visibility` | USER-DEFINED | ✓ | 'Trusted+'::profile_visibility |
| `show_on_discovery` | boolean | ✓ | true |
| `women_safety_mode` | boolean | ✓ | false |
| `location_sharing` | boolean | ✓ | false |
| `updated_at` | timestamp with time zone | ✓ | now() |
| `guest_capacity` | integer | ✓ | — |
| `access_source` | text | ✓ | — |
| `referral_code` | text | ✓ | — |
| `referred_by` | uuid | ✓ | — |

**Kısıtlar:**
- `profiles_referred_by_fkey` — FOREIGN KEY (referred_by) REFERENCES users(id)
- `profiles_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `profiles_pkey` — PRIMARY KEY (user_id)

**RLS politikaları:**
- `profiles_own`: (auth.uid() = user_id)
- `profiles_read_auth`: true
- `profiles_self_update`: (user_id = auth.uid())

### promo_campaigns  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `title` | text | — | — |
| `description` | text | ✓ | — |
| `ends_at` | date | ✓ | — |
| `active` | boolean | ✓ | true |
| `created_by` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `joinable` | boolean | ✓ | true |

**Kısıtlar:**
- `promo_campaigns_created_by_fkey` — FOREIGN KEY (created_by) REFERENCES users(id)
- `promo_campaigns_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `campaigns_read`: (active AND ((ends_at IS NULL) OR (ends_at >= CURRENT_DATE)))

### promo_codes  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `code` | text | — | — |
| `reward_type` | text | — | — |
| `amount` | integer | — | — |
| `max_uses` | integer | ✓ | — |
| `used_count` | integer | ✓ | 0 |
| `expires_at` | date | ✓ | — |
| `active` | boolean | ✓ | true |
| `created_by` | uuid | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `promo_codes_amount_check` — CHECK ((amount > 0))
- `promo_codes_reward_type_check` — CHECK ((reward_type = ANY (ARRAY['points'::text, 'credits'::text])))
- `promo_codes_created_by_fkey` — FOREIGN KEY (created_by) REFERENCES users(id)
- `promo_codes_pkey` — PRIMARY KEY (id)
- `promo_codes_code_key` — UNIQUE (code)

### promo_redemptions  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | gen_random_uuid() |
| `code_id` | uuid | — | — |
| `user_id` | uuid | — | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `promo_redemptions_code_id_fkey` — FOREIGN KEY (code_id) REFERENCES promo_codes(id)
- `promo_redemptions_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `promo_redemptions_pkey` — PRIMARY KEY (id)
- `promo_redemptions_code_id_user_id_key` — UNIQUE (code_id, user_id)

**RLS politikaları:**
- `redeem_own_read`: (user_id = auth.uid())

### push_tokens  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `user_id` | uuid | — | — |
| `token` | text | — | — |
| `platform` | text | ✓ | 'android'::text |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `push_tokens_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `push_tokens_pkey` — PRIMARY KEY (user_id, token)

**RLS politikaları:**
- `push_own`: (user_id = auth.uid())

### ratings  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `session_id` | uuid | — | — |
| `rater_id` | uuid | — | — |
| `rated_id` | uuid | — | — |
| `score` | smallint | — | — |
| `comment` | text | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `ratings_score_check` — CHECK (((score >= 1) AND (score <= 5)))
- `ratings_rated_id_fkey` — FOREIGN KEY (rated_id) REFERENCES users(id)
- `ratings_rater_id_fkey` — FOREIGN KEY (rater_id) REFERENCES users(id)
- `ratings_session_id_fkey` — FOREIGN KEY (session_id) REFERENCES sessions(id)
- `ratings_pkey` — PRIMARY KEY (id)
- `ratings_session_id_rater_id_key` — UNIQUE (session_id, rater_id)

**RLS politikaları:**
- `ratings_visible`: ((rater_id = auth.uid()) OR (rated_id = auth.uid()))

### redemptions  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `reward_id` | uuid | — | — |
| `cost_points` | integer | — | — |
| `voucher_code` | text | — | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `redemptions_reward_id_fkey` — FOREIGN KEY (reward_id) REFERENCES rewards(id)
- `redemptions_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `redemptions_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `redemptions_own`: (user_id = auth.uid())

### reports  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `reporter_id` | uuid | — | — |
| `target_id` | uuid | — | — |
| `session_id` | uuid | ✓ | — |
| `type` | USER-DEFINED | — | — |
| `description` | text | ✓ | — |
| `status` | USER-DEFINED | ✓ | 'open'::report_status |
| `resolved_by` | uuid | ✓ | — |
| `resolution` | text | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `updated_at` | timestamp with time zone | ✓ | now() |
| `is_urgent` | boolean | — | false |

**Kısıtlar:**
- `reports_reporter_id_fkey` — FOREIGN KEY (reporter_id) REFERENCES users(id)
- `reports_resolved_by_fkey` — FOREIGN KEY (resolved_by) REFERENCES users(id)
- `reports_session_id_fkey` — FOREIGN KEY (session_id) REFERENCES sessions(id)
- `reports_target_id_fkey` — FOREIGN KEY (target_id) REFERENCES users(id)
- `reports_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `reports_select_own`: (reporter_id = auth.uid())

### requests  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `guest_id` | uuid | — | — |
| `host_id` | uuid | — | — |
| `avail_id` | uuid | — | — |
| `visit_id` | uuid | ✓ | — |
| `status` | USER-DEFINED | — | 'pending'::request_status |
| `type` | USER-DEFINED | ✓ | 'standard'::request_type |
| `intro_message` | text | ✓ | — |
| `match_score` | integer | ✓ | — |
| `idempotency_key` | text | ✓ | — |
| `responded_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |
| `purpose` | text | ✓ | — |

**Kısıtlar:**
- `requests_check` — CHECK ((guest_id <> host_id))
- `requests_avail_id_fkey` — FOREIGN KEY (avail_id) REFERENCES availabilities(id)
- `requests_guest_id_fkey` — FOREIGN KEY (guest_id) REFERENCES users(id)
- `requests_host_id_fkey` — FOREIGN KEY (host_id) REFERENCES users(id)
- `requests_visit_id_fkey` — FOREIGN KEY (visit_id) REFERENCES visits(id)
- `requests_pkey` — PRIMARY KEY (id)
- `requests_idempotency_key_key` — UNIQUE (idempotency_key)

**RLS politikaları:**
- `requests_parties`: ((auth.uid() = guest_id) OR (auth.uid() = host_id))

### rewards  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `title` | text | — | — |
| `subtitle` | text | ✓ | — |
| `category` | text | ✓ | — |
| `cost_points` | integer | — | — |
| `active` | boolean | ✓ | true |
| `sort_order` | integer | ✓ | 0 |
| `stock` | integer | ✓ | — |
| `supplier` | text | ✓ | — |
| `supplier_cost_try` | integer | ✓ | — |

**Kısıtlar:**
- `rewards_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `rewards_read`: (active = true)

### rule_thresholds  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `key` | text | — | — |
| `value` | integer | — | — |
| `description` | text | ✓ | — |

**Kısıtlar:**
- `rule_thresholds_pkey` — PRIMARY KEY (key)

### sessions  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `request_id` | uuid | — | — |
| `status` | USER-DEFINED | ✓ | 'active'::session_status |
| `started_at` | timestamp with time zone | ✓ | now() |
| `completed_at` | timestamp with time zone | ✓ | — |
| `host_confirmed` | boolean | ✓ | false |
| `guest_confirmed` | boolean | ✓ | false |
| `cancelled_by` | uuid | ✓ | — |
| `cancel_reason` | text | ✓ | — |
| `rate_deferred_by` | ARRAY | ✓ | — |
| `host_status` | text | ✓ | — |
| `host_status_ts` | timestamp with time zone | ✓ | — |
| `guest_status` | text | ✓ | — |
| `guest_status_ts` | timestamp with time zone | ✓ | — |
| `host_started_at` | timestamp with time zone | ✓ | — |
| `guest_started_at` | timestamp with time zone | ✓ | — |
| `cancel_grace_until` | timestamp with time zone | ✓ | — |
| `no_show_user_id` | uuid | ✓ | — |

**Kısıtlar:**
- `sessions_cancelled_by_fkey` — FOREIGN KEY (cancelled_by) REFERENCES users(id)
- `sessions_no_show_user_id_fkey` — FOREIGN KEY (no_show_user_id) REFERENCES users(id)
- `sessions_request_id_fkey` — FOREIGN KEY (request_id) REFERENCES requests(id)
- `sessions_pkey` — PRIMARY KEY (id)
- `sessions_request_id_key` — UNIQUE (request_id)

**RLS politikaları:**
- `sess_parties`: (EXISTS ( SELECT 1

### subscriptions  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `plan` | USER-DEFINED | — | — |
| `status` | USER-DEFINED | ✓ | 'active'::subscription_status |
| `stripe_sub_id` | text | ✓ | — |
| `stripe_cus_id` | text | ✓ | — |
| `renews_at` | timestamp with time zone | ✓ | — |
| `cancelled_at` | timestamp with time zone | ✓ | — |
| `created_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `subscriptions_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id)
- `subscriptions_pkey` — PRIMARY KEY (id)
- `subscriptions_stripe_sub_id_key` — UNIQUE (stripe_sub_id)
- `subscriptions_user_id_key` — UNIQUE (user_id)

**RLS politikaları:**
- `subs_select_own`: (user_id = auth.uid())

### trust_scores  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `user_id` | uuid | — | — |
| `score` | integer | — | 0 |
| `components` | jsonb | ✓ | '{}'::jsonb |
| `badge` | text | ✓ | — |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `trust_scores_score_check` — CHECK (((score >= 0) AND (score <= 100)))
- `trust_scores_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `trust_scores_pkey` — PRIMARY KEY (user_id)

**RLS politikaları:**
- `trust_read_auth`: true

### users  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `email` | text | — | — |
| `phone` | text | ✓ | — |
| `phone_e164` | text | ✓ | — |
| `phone_kanonik` | text | ✓ | — |
| `role` | USER-DEFINED | — | 'guest'::user_role |
| `gender` | USER-DEFINED | ✓ | — |
| `password_hash` | text | — | 'supabase-auth'::text |
| `plan` | USER-DEFINED | — | 'explorer'::plan_type |
| `created_at` | timestamp with time zone | — | now() |
| `updated_at` | timestamp with time zone | — | now() |
| `last_seen_at` | timestamp with time zone | ✓ | — |
| `deleted_at` | timestamp with time zone | ✓ | — |
| `shadow_limited` | boolean | ✓ | false |
| `restricted_until` | timestamp with time zone | ✓ | — |
| `is_staff` | boolean | — | false |

**Kısıtlar:**
- `users_pkey` — PRIMARY KEY (id)
- `users_email_key` — UNIQUE (email)

**RLS politikaları:**
- `users_own`: (auth.uid() = id)

### verifications  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `email_verified` | boolean | ✓ | false |
| `email_verified_at` | timestamp with time zone | ✓ | — |
| `phone_verified` | boolean | ✓ | false |
| `phone_verified_at` | timestamp with time zone | ✓ | — |
| `id_verified` | boolean | ✓ | false |
| `id_verified_at` | timestamp with time zone | ✓ | — |
| `id_provider` | text | ✓ | — |
| `id_provider_ref` | text | ✓ | — |
| `linkedin_verified` | boolean | ✓ | false |
| `updated_at` | timestamp with time zone | ✓ | now() |

**Kısıtlar:**
- `verifications_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `verifications_pkey` — PRIMARY KEY (id)
- `verifications_user_id_key` — UNIQUE (user_id)

**RLS politikaları:**
- `verif_own`: (auth.uid() = user_id)

### visits  ⚠ RLS kapalı

| kolon | tip | null | varsayılan |
|---|---|---|---|
| `id` | uuid | — | uuid_generate_v4() |
| `user_id` | uuid | — | — |
| `airport_code` | character(3) | — | — |
| `destination` | character(3) | ✓ | — |
| `visit_date` | date | — | — |
| `time_from` | time without time zone | — | — |
| `time_to` | time without time zone | — | — |
| `flight_number` | text | ✓ | — |
| `flight_verified` | boolean | ✓ | false |
| `created_at` | timestamp with time zone | ✓ | now() |
| `purpose` | text | ✓ | — |
| `scheduled_departure` | timestamp with time zone | ✓ | — |
| `scheduled_arrival` | timestamp with time zone | ✓ | — |
| `terminal` | text | ✓ | — |
| `flight_source` | text | ✓ | — |
| `flight_checked_at` | timestamp with time zone | ✓ | — |

**Kısıtlar:**
- `visits_check` — CHECK ((time_from < time_to))
- `visits_purpose_check` — CHECK (((purpose IS NULL) OR (purpose = ANY (ARRAY['business'::text, 'conference'::text, 'leisure'::text, 'connecting'::text, 'event'::text]))))
- `visits_airport_code_fkey` — FOREIGN KEY (airport_code) REFERENCES airports(code)
- `visits_user_id_fkey` — FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
- `visits_pkey` — PRIMARY KEY (id)

**RLS politikaları:**
- `visits_own`: (auth.uid() = user_id)

## VIEW'LER

- `i18n_missing`
- `referral_log`
- `report_sla`
- `stale_requests`
- `suspicious_availabilities`
- `user_balances`

## FONKSİYONLAR (RPC'ler dahil)

- `active_campaigns()`
- `admin_adjust_credit(p_user uuid, p_delta integer, p_reason text)`
- `admin_adjust_points(p_user uuid, p_delta integer, p_reason text)`
- `admin_bulk_credit(p_delta integer, p_note text, p_role text)`
- `admin_create_campaign(p_title text, p_description text, p_ends date, p_admin uuid)`
- `admin_create_promo_code(p_code text, p_type text, p_amount integer, p_max integer, p_expires date, p_admin uui`
- `admin_credit_adjust(p_user uuid, p_delta integer, p_note text)`
- `admin_delete_availability(p_id uuid, p_hard boolean, p_reason text)`
- `admin_delete_visit(p_id uuid)`
- `admin_has_permission(p_user uuid, p_module text)`
- `admin_list_visits(p_airport text, p_from date, p_limit integer)`
- `admin_purge_test_data(p_before date, p_dry_run boolean)`
- `admin_set_email(p_user uuid, p_email text)`
- `admin_set_phone(p_user uuid, p_phone text)`
- `admin_set_trust(p_user uuid, p_score integer, p_badge text)`
- `admin_set_verification(p_user uuid, p_field text, p_value boolean)`
- `admin_update_profile(p_user uuid, p_patch jsonb)`
- `apply_for_host(p_access_source text, p_guest_capacity integer, p_note text)`
- `apply_referral(p_code text)`
- `apply_rule_engine(p_user uuid)`
- `apply_rule_snapshot(p_avail_id uuid)`
- `armor(bytea)`
- `armor(bytea, text[], text[])`
- `assign_partner(p_email text, p_lounge_id uuid, p_role text)`
- `availability_rule_snapshot(p_avail_id uuid)`
- `bo_error_summary(p_days integer)`
- `cancel_availability(p_id uuid)`
- `cancel_request(p_request_id uuid, p_reason text)`
- `cancel_session(p_session_id uuid, p_reason text)`
- `change_phone(p_phone text)`
- `change_plan(p_plan plan_type)`
- `compute_trust_badge(score integer)`
- `confirm_session(p_session_id uuid)`
- `create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time wi`
- `create_report(p_target uuid, p_type text, p_description text, p_session uuid)`
- `create_request(p_avail_id uuid, p_type text, p_intro text, p_idem text)`
- `crypt(text, text)`
- `dearmor(text)`
- `decrypt(bytea, bytea, text)`
- `decrypt_iv(bytea, bytea, bytea, text)`
- `defer_rating(p_session uuid)`
- `delete_my_account()`
- `digest(bytea, text)`
- `digest(text, text)`
- `discover_availabilities(p_airport text, p_sector text, p_flight text, p_date date)`
- `discover_people(p_airport text, p_date date)`
- `encrypt(bytea, bytea, text)`
- `encrypt_iv(bytea, bytea, bytea, text)`
- `expire_stale_sessions()`
- `flag_enabled(p_key text)`
- `flight_lookup(p_flight_no text, p_date date)`
- `gen_random_bytes(integer)`
- `gen_random_uuid()`
- `gen_salt(text)`
- `gen_salt(text, integer)`
- `grant_consents(p_types text[], p_version text)`
- `grant_signup_credits(p_user uuid)`
- `guest_flight_fits(p_avail_id uuid, p_flight_no text)`
- `handle_new_user()`
- `has_active_session()`
- `hmac(bytea, bytea, text)`
- `hmac(text, text, text)`
- `host_requests()`
- `invitable_guests(p_avail_id uuid)`
- `is_contact_verified(p_user uuid)`
- `is_visible(p_user uuid)`
- `join_campaign(p_id uuid)`
- `log_client_error(p_screen text, p_message text, p_code text, p_version text, p_platform text, p_context jsonb)`
- `lounge_radar_count()`
- `lounge_radar_people()`
- `lounge_rule_check(p_program_code text, p_venue_id uuid, p_carrier text, p_card_tier text, p_cabin text, p_gues`
- `lounge_rules_health()`
- `mark_password_changed()`
- `match_deletion_requests()`
- `my_availabilities()`
- `my_connections()`
- `my_host_application()`
- `my_referral()`
- `my_reports()`
- `my_visits()`
- `needs_password_change(p_user uuid)`
- `open_dispute(p_session uuid, p_reason text, p_detail text)`
- `partner_demand(p_lounge_id uuid)`
- `partner_payout(p_lounge_id uuid, p_from date, p_to date)`
- `pending_actions()`
- `pending_ratings()`
- `pgp_armor_headers(text, OUT key text, OUT value text)`
- `pgp_key_id(bytea)`
- `pgp_pub_decrypt(bytea, bytea)`
- `pgp_pub_decrypt(bytea, bytea, text)`
- `pgp_pub_decrypt(bytea, bytea, text, text)`
- `pgp_pub_decrypt_bytea(bytea, bytea)`
- `pgp_pub_decrypt_bytea(bytea, bytea, text)`
- `pgp_pub_decrypt_bytea(bytea, bytea, text, text)`
- `pgp_pub_encrypt(text, bytea)`
- `pgp_pub_encrypt(text, bytea, text)`
- `pgp_pub_encrypt_bytea(bytea, bytea)`
- `pgp_pub_encrypt_bytea(bytea, bytea, text)`
- `pgp_sym_decrypt(bytea, text)`
- `pgp_sym_decrypt(bytea, text, text)`
- `pgp_sym_decrypt_bytea(bytea, text)`
- `pgp_sym_decrypt_bytea(bytea, text, text)`
- `pgp_sym_encrypt(text, text)`
- `pgp_sym_encrypt(text, text, text)`
- `pgp_sym_encrypt_bytea(bytea, text)`
- `pgp_sym_encrypt_bytea(bytea, text, text)`
- `phone_in_use(p_phone text)`
- `publish_availability(p_airport text, p_lounge_id uuid, p_lounge_name text, p_date date, p_from time without ti`
- `rate_session(p_session_id uuid, p_score integer, p_comment text)`
- `recompute_badge(p_user uuid)`
- `recompute_trust(p_user uuid)`
- `redeem_promo_code(p_code text)`
- `redeem_reward(p_reward_id uuid)`
- `remove_admin(p_user uuid)`
- `remove_rating(p_rating_id uuid)`
- `resolve_dispute(p_dispute uuid, p_decision text, p_admin uuid)`
- `resolve_report(p_report_id uuid, p_status text, p_resolution text, p_resolver uuid)`
- `respond_connection(p_id uuid, p_accept boolean)`
- `respond_invite(p_id uuid, p_accept boolean)`
- `respond_request(p_request_id uuid, p_action text)`
- `review_host_application(p_id uuid, p_approve boolean, p_note text)`
- `rl_guard()`
- `rl_limit(p_key text, p_default integer)`
- `save_push_token(p_token text, p_platform text)`
- `send_campaign(p_title text, p_body text, p_segment jsonb, p_admin uuid, p_user_ids uuid[])`
- `send_connection(p_to uuid, p_intent text, p_intro text)`
- `send_invite(p_guest uuid, p_avail_id uuid, p_note text)`
- `send_otp(p_phone text)`
- `set_featured(p_avail_id uuid)`
- `share_session_status(p_session_id uuid, p_status text)`
- `sos_alert(p_note text)`
- `start_session(p_request_id uuid)`
- `start_session_request(p_request_id uuid)`
- `sync_availability_filled()`
- `trg_profile_trust()`
- `trg_profile_trust_v()`
- `trg_session_completed()`
- `unrated_sessions()`
- `upsert_admin(p_email text, p_role text, p_permissions jsonb, p_display_name text, p_must_change boolean)`
- `uuid_generate_v1()`
- `uuid_generate_v1mc()`
- `uuid_generate_v3(namespace uuid, name text)`
- `uuid_generate_v4()`
- `uuid_generate_v5(namespace uuid, name text)`
- `uuid_nil()`
- `uuid_ns_dns()`
- `uuid_ns_oid()`
- `uuid_ns_url()`
- `uuid_ns_x500()`
- `verify_email_contact()`
- `verify_otp(p_phone text, p_code text)`
- `waiting_demand(p_airport text, p_date date)`
