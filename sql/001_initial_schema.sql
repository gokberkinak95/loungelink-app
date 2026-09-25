-- ============================================================
-- LoungeLink Production Database Schema
-- Supabase / PostgreSQL
-- Teknik Gereksinimler v1 baz alınarak
-- ============================================================

-- UUID extension
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. USERS & AUTH
-- ============================================================

create type user_role as enum ('host', 'guest', 'admin');
create type user_gender as enum ('female', 'male', 'other', 'prefer_not_to_say');
create type plan_type as enum ('explorer', 'traveler', 'frequent');
create type profile_visibility as enum ('Everyone', 'Trusted+', 'Connections');

create table users (
  id            uuid primary key default uuid_generate_v4(),
  email         text unique not null,
  phone         text,
  phone_e164    text,                          -- +905xxxxxxxxx format
  role          user_role not null default 'guest',
  gender        user_gender,
  password_hash text not null,
  plan          plan_type not null default 'explorer',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  last_seen_at  timestamptz,
  deleted_at    timestamptz                    -- soft delete
);

create index idx_users_email on users(email);
create index idx_users_phone on users(phone_e164) where phone_e164 is not null;

-- ============================================================
-- 2. PROFILES
-- ============================================================

create table profiles (
  user_id                 uuid primary key references users(id) on delete cascade,
  name                    text not null,
  profession              text,
  bio                     text,
  languages               text[] default '{}',
  linkedin_url            text,
  linkedin_verified       boolean default false,
  photo_url               text,
  photo_connections_only  boolean default false,
  profile_visibility      profile_visibility default 'Trusted+',
  show_on_discovery       boolean default true,
  women_safety_mode       boolean default false,
  location_sharing        boolean default false,
  updated_at              timestamptz default now()
);

-- ============================================================
-- 3. VERIFICATIONS
-- ============================================================

create table verifications (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references users(id) on delete cascade,
  email_verified  boolean default false,
  email_verified_at timestamptz,
  phone_verified  boolean default false,
  phone_verified_at timestamptz,
  id_verified     boolean default false,
  id_verified_at  timestamptz,
  id_provider     text,                        -- 'onfido' | 'veriff' | 'sumsub'
  id_provider_ref text,                        -- provider'ın check id'si
  linkedin_verified boolean default false,
  updated_at      timestamptz default now(),
  unique(user_id)
);

-- ============================================================
-- 4. TRUST SCORES
-- ============================================================

create table trust_scores (
  user_id       uuid primary key references users(id) on delete cascade,
  score         integer not null default 0 check (score >= 0 and score <= 100),
  components    jsonb default '{}',            -- {email:10, phone:10, id:20, ...}
  badge         text,                          -- 'Basic Verified' | 'Trusted Host' | ...
  updated_at    timestamptz default now()
);

-- Trust score hesaplama fonksiyonu (trigger ile çalışır)
create or replace function compute_trust_badge(score integer) returns text as $$
begin
  return case
    when score >= 90 then 'Elite Host'
    when score >= 75 then 'Trusted Host'
    when score >= 60 then 'Verified Host'
    when score >= 45 then 'Basic Verified'
    else 'Unverified'
  end;
end;
$$ language plpgsql immutable;

-- ============================================================
-- 5. AIRPORTS & LOUNGES (referans veri)
-- ============================================================

create table airports (
  code  char(3) primary key,                  -- IATA kodu: IST, LHR, JFK
  name  text not null,
  city  text,
  country text,
  timezone text
);

create table lounges (
  id            uuid primary key default uuid_generate_v4(),
  airport_code  char(3) not null references airports(code),
  name          text not null,
  terminal      text,
  access_types  text[] default '{}',          -- ['Priority Pass', 'LoungeKey', ...]
  active        boolean default true
);

create index idx_lounges_airport on lounges(airport_code);

-- ============================================================
-- 6. VISITS / TRIPS
-- ============================================================

create table visits (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references users(id) on delete cascade,
  airport_code  char(3) not null references airports(code),
  destination   char(3),                      -- varış havalimanı
  visit_date    date not null,
  time_from     time not null,
  time_to       time not null,
  flight_number text,
  flight_verified boolean default false,
  created_at    timestamptz default now(),
  check (time_from < time_to)
);

create index idx_visits_user on visits(user_id);
create index idx_visits_airport_date on visits(airport_code, visit_date);

-- ============================================================
-- 7. AVAILABILITIES (host ilanları)
-- ============================================================

create type availability_visibility as enum ('Public', 'Connections', 'Hidden');

create table availabilities (
  id            uuid primary key default uuid_generate_v4(),
  host_id       uuid not null references users(id) on delete cascade,
  airport_code  char(3) not null references airports(code),
  lounge_id     uuid references lounges(id),
  lounge_name   text,                         -- serbest metin fallback
  avail_date    date not null,
  time_from     time not null,
  time_to       time not null,
  slots         smallint not null default 1 check (slots between 1 and 6),
  filled        smallint not null default 0,
  visibility    availability_visibility default 'Public',
  flight_number text,
  access_sources text[] default '{}',         -- ['Priority Pass', 'LoungeKey']
  active        boolean default true,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  check (filled <= slots),
  check (time_from < time_to)
);

create index idx_avail_airport_date on availabilities(airport_code, avail_date) where active = true;
create index idx_avail_host on availabilities(host_id);

-- ============================================================
-- 8. REQUESTS
-- ============================================================

create type request_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'expired');
create type request_type as enum ('standard', 'direct_invite');

create table requests (
  id              uuid primary key default uuid_generate_v4(),
  guest_id        uuid not null references users(id),
  host_id         uuid not null references users(id),
  avail_id        uuid not null references availabilities(id),
  visit_id        uuid references visits(id),        -- gate için guest'in trip'i
  status          request_status not null default 'pending',
  type            request_type default 'standard',
  intro_message   text,
  match_score     integer,
  idempotency_key text unique,                        -- çift gönderim engeli
  responded_at    timestamptz,
  created_at      timestamptz default now(),
  -- Host kendi ilanına başvuramaz
  check (guest_id != host_id)
);

-- Aktif request'lerde (guest, avail) tekil olmalı
create unique index idx_requests_unique_active
  on requests(guest_id, avail_id)
  where status in ('pending', 'accepted');

create index idx_requests_host on requests(host_id, status);
create index idx_requests_guest on requests(guest_id, status);
create index idx_requests_avail on requests(avail_id);

-- ============================================================
-- 9. SESSIONS
-- ============================================================

create type session_status as enum ('active', 'completed', 'cancelled');

create table sessions (
  id              uuid primary key default uuid_generate_v4(),
  request_id      uuid not null unique references requests(id),
  status          session_status default 'active',
  started_at      timestamptz default now(),
  completed_at    timestamptz,
  host_confirmed  boolean default false,
  guest_confirmed boolean default false,
  cancelled_by    uuid references users(id),
  cancel_reason   text
);

create index idx_sessions_request on sessions(request_id);

-- ============================================================
-- 10. RATINGS
-- ============================================================

create table ratings (
  id          uuid primary key default uuid_generate_v4(),
  session_id  uuid not null references sessions(id),
  rater_id    uuid not null references users(id),
  rated_id    uuid not null references users(id),
  score       smallint not null check (score between 1 and 5),
  comment     text,
  created_at  timestamptz default now(),
  -- Her session'da her yön için bir puan
  unique(session_id, rater_id)
);

-- ============================================================
-- 11. MESSAGING
-- ============================================================

create table chat_channels (
  id          uuid primary key default uuid_generate_v4(),
  request_id  uuid unique references requests(id),
  created_at  timestamptz default now()
);

create table messages (
  id          uuid primary key default uuid_generate_v4(),
  channel_id  uuid not null references chat_channels(id),
  from_id     uuid not null references users(id),
  body        text not null,
  flagged     boolean default false,          -- moderasyon
  flag_reason text,
  read_at     timestamptz,
  created_at  timestamptz default now()
);

create index idx_messages_channel on messages(channel_id, created_at desc);

-- ============================================================
-- 12. NOTIFICATIONS
-- ============================================================

create type notif_category as enum (
  'requests', 'sessions', 'invites', 'connections',
  'system', 'safety', 'credits', 'ratings'
);

create table notifications (
  id        uuid primary key default uuid_generate_v4(),
  user_id   uuid not null references users(id) on delete cascade,
  category  notif_category not null,
  title     text not null,
  body      text,
  icon      text,
  color     text,
  ref_id    uuid,                             -- ilgili entity id'si
  ref_type  text,                             -- 'request' | 'session' | ...
  read      boolean default false,
  read_at   timestamptz,
  created_at timestamptz default now()
);

create index idx_notif_user on notifications(user_id, read, created_at desc);

-- ============================================================
-- 13. SOCIAL GRAPH — Connections & Invites
-- ============================================================

create type connection_status as enum ('pending', 'accepted', 'declined', 'blocked');

create table connection_requests (
  id          uuid primary key default uuid_generate_v4(),
  from_id     uuid not null references users(id),
  to_id       uuid not null references users(id),
  intent      text,
  intro       text,
  status      connection_status default 'pending',
  created_at  timestamptz default now(),
  check (from_id != to_id),
  unique(from_id, to_id)
);

create table invites (
  id          uuid primary key default uuid_generate_v4(),
  host_id     uuid not null references users(id),
  guest_id    uuid not null references users(id),
  avail_id    uuid references availabilities(id),
  note        text,
  status      connection_status default 'pending',
  created_at  timestamptz default now()
);

-- ============================================================
-- 14. CREDITS & POINTS LEDGER (çift-girişli)
-- ============================================================

create table credit_ledger (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references users(id),
  delta         integer not null,             -- pozitif = ekle, negatif = çıkar
  reason        text not null,               -- 'request_hold' | 'refund' | 'purchase' | ...
  ref_id        uuid,                         -- ilgili request/session id
  balance_after integer not null,
  created_at    timestamptz default now()
);

create index idx_credit_user on credit_ledger(user_id, created_at desc);

create table points_ledger (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users(id),
  delta       integer not null,
  reason      text not null,
  ref_id      uuid,
  created_at  timestamptz default now()
);

create index idx_points_user on points_ledger(user_id, created_at desc);

-- Kullanıcının güncel bakiyesini tutan view
create view user_balances as
select
  u.id as user_id,
  coalesce((select sum(delta) from credit_ledger where user_id = u.id), 0) as credits,
  coalesce((select sum(delta) from points_ledger where user_id = u.id), 0) as points
from users u;

-- ============================================================
-- 15. SUBSCRIPTIONS
-- ============================================================

create type subscription_status as enum ('active', 'cancelled', 'past_due', 'trialing');

create table subscriptions (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid unique not null references users(id),
  plan            plan_type not null,
  status          subscription_status default 'active',
  stripe_sub_id   text unique,
  stripe_cus_id   text,
  renews_at       timestamptz,
  cancelled_at    timestamptz,
  created_at      timestamptz default now()
);

-- ============================================================
-- 16. SAFETY — Reports & Disputes
-- ============================================================

create type report_type as enum ('harassment', 'fraud', 'fake_profile', 'off_platform_payment', 'other');
create type report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

create table reports (
  id            uuid primary key default uuid_generate_v4(),
  reporter_id   uuid not null references users(id),
  target_id     uuid not null references users(id),
  session_id    uuid references sessions(id),
  type          report_type not null,
  description   text,
  status        report_status default 'open',
  resolved_by   uuid references users(id),
  resolution    text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ============================================================
-- 17. CONSENTS (KVKK / GDPR)
-- ============================================================

create table consents (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users(id),
  type        text not null,                  -- 'tos' | 'privacy' | 'lounge_rules' | ...
  version     text not null,
  granted_at  timestamptz default now(),
  ip_address  inet,
  user_agent  text
);

create index idx_consents_user on consents(user_id, type);

-- ============================================================
-- 18. AUDIT LOG (değişmez)
-- ============================================================

create table audit_log (
  id          bigserial primary key,
  actor_id    uuid references users(id),
  action      text not null,                  -- 'user.register' | 'request.accept' | ...
  entity_type text,
  entity_id   uuid,
  before_data jsonb,
  after_data  jsonb,
  ip_address  inet,
  user_agent  text,
  created_at  timestamptz default now()
);

create index idx_audit_actor on audit_log(actor_id, created_at desc);
create index idx_audit_entity on audit_log(entity_type, entity_id);

-- ============================================================
-- 19. OTP TOKENS
-- ============================================================

create table otp_tokens (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references users(id),
  phone_e164  text,
  code_hash   text not null,                  -- bcrypt hash of code
  purpose     text default 'phone_verify',
  attempts    smallint default 0,
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz default now()
);

create index idx_otp_phone on otp_tokens(phone_e164, expires_at) where used_at is null;

-- ============================================================
-- 20. SEED DATA — Airports
-- ============================================================

insert into airports (code, name, city, country, timezone) values
  ('IST', 'İstanbul Havalimanı', 'İstanbul', 'TR', 'Europe/Istanbul'),
  ('SAW', 'Sabiha Gökçen', 'İstanbul', 'TR', 'Europe/Istanbul'),
  ('ESB', 'Esenboğa', 'Ankara', 'TR', 'Europe/Istanbul'),
  ('ADB', 'Adnan Menderes', 'İzmir', 'TR', 'Europe/Istanbul'),
  ('LHR', 'Heathrow', 'Londra', 'GB', 'Europe/London'),
  ('CDG', 'Charles de Gaulle', 'Paris', 'FR', 'Europe/Paris'),
  ('FRA', 'Frankfurt', 'Frankfurt', 'DE', 'Europe/Berlin'),
  ('DXB', 'Dubai International', 'Dubai', 'AE', 'Asia/Dubai'),
  ('JFK', 'John F. Kennedy', 'New York', 'US', 'America/New_York'),
  ('SIN', 'Changi', 'Singapur', 'SG', 'Asia/Singapore')
on conflict do nothing;

-- ============================================================
-- ROW LEVEL SECURITY (Supabase)
-- ============================================================

alter table users enable row level security;
alter table profiles enable row level security;
alter table verifications enable row level security;
alter table trust_scores enable row level security;
alter table visits enable row level security;
alter table availabilities enable row level security;
alter table requests enable row level security;
alter table sessions enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
alter table credit_ledger enable row level security;
alter table points_ledger enable row level security;

-- Kullanıcı sadece kendi datasını okuyabilir
create policy "users_own" on users for all using (auth.uid() = id);
create policy "profiles_own" on profiles for all using (auth.uid() = user_id);
create policy "verif_own" on verifications for all using (auth.uid() = user_id);
create policy "visits_own" on visits for all using (auth.uid() = user_id);
create policy "notif_own" on notifications for all using (auth.uid() = user_id);
create policy "credit_own" on credit_ledger for select using (auth.uid() = user_id);
create policy "points_own" on points_ledger for select using (auth.uid() = user_id);

-- Availabilities: public olanları herkes görebilir
create policy "avail_public_read" on availabilities
  for select using (visibility = 'Public' and active = true);
create policy "avail_host_write" on availabilities
  for all using (auth.uid() = host_id);

-- Requests: guest veya host görebilir
create policy "requests_parties" on requests
  for select using (auth.uid() = guest_id or auth.uid() = host_id);

-- Messages: kanal tarafları görebilir
create policy "messages_parties" on messages
  for select using (
    exists (
      select 1 from chat_channels cc
      join requests r on r.id = cc.request_id
      where cc.id = channel_id
      and (r.guest_id = auth.uid() or r.host_id = auth.uid())
    )
  );
