-- ============================================================
-- LoungeLink · 029_bo_requirements.sql — EK-2 Admin Panel gereksinimleri
-- 1) disputes (İtiraz Merkezi) · 2) feature_flags · 3) i18n · 4) kampanyalar
-- 5) partner day-pass/kural kartı/hakediş · 6) gölge kısıt · 7) kupon stok
-- 8) kural motoru eşikleri · 9) k-anonimite >= 5 düzeltmesi
-- ============================================================

-- ---------- 1) İTİRAZ MERKEZİ (disputes) ----------
-- 24s escrow penceresinde oturum itirazı. Karar: refund | capture | partial
do $$ begin
  create type dispute_status as enum ('open','resolved','rejected');
exception when duplicate_object then null; end $$;

create table if not exists disputes (
  id             uuid primary key default gen_random_uuid(),
  session_id     uuid references sessions(id) on delete cascade,
  request_id     uuid references requests(id) on delete cascade,
  opener_id      uuid not null references users(id) on delete cascade,
  reason         text not null,          -- no_show | rule_violation | misrepresentation | other
  detail         text,
  status         dispute_status not null default 'open',
  decision       text,                   -- refund | capture | partial
  decided_by     uuid references users(id),
  decided_at     timestamptz,
  created_at     timestamptz default now()
);
create index if not exists disputes_status_idx on disputes (status, created_at desc);
alter table disputes enable row level security;

-- Kullanıcı kendi itirazını açar/görür
drop policy if exists "disputes_own" on disputes;
create policy "disputes_own" on disputes for select to authenticated using (opener_id = auth.uid());
drop policy if exists "disputes_insert" on disputes;
create policy "disputes_insert" on disputes for insert to authenticated with check (opener_id = auth.uid());

-- İtiraz aç (24 saat penceresi)
create or replace function public.open_dispute(p_session uuid, p_reason text, p_detail text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_s from sessions where id = p_session;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if v_r.guest_id <> v_uid and v_r.host_id <> v_uid then raise exception 'not_participant'; end if;
  -- 24 saatlik pencere
  if coalesce(v_s.completed_at, v_s.started_at) < now() - interval '24 hours' then
    raise exception 'dispute_window_closed';
  end if;
  if exists (select 1 from disputes where session_id = p_session and status = 'open') then
    raise exception 'dispute_already_open';
  end if;

  insert into disputes (session_id, request_id, opener_id, reason, detail)
  values (p_session, v_s.request_id, v_uid, p_reason, p_detail);
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.open_dispute(uuid, text, text) to authenticated;

-- Admin karar verir: kredi iade / kapama / kısmi
create or replace function public.resolve_dispute(
  p_dispute uuid, p_decision text, p_admin uuid
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_d disputes%rowtype; v_r requests%rowtype; v_bal int;
begin
  select * into v_d from disputes where id = p_dispute for update;
  if not found then raise exception 'dispute_not_found'; end if;
  if v_d.status <> 'open' then raise exception 'already_decided'; end if;
  select * into v_r from requests where id = v_d.request_id;

  if p_decision = 'refund' then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, 1, 'dispute_refund', v_r.id, v_bal + 1);
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_r.guest_id, 'system', 'İtirazın sonuçlandı', 'Kredin iade edildi.', 'dispute', p_dispute);
  elsif p_decision = 'partial' then
    -- kısmi: puan telafisi (kredi iade yok)
    insert into points_ledger (user_id, delta, reason) values (v_r.guest_id, 250, 'dispute_partial');
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_r.guest_id, 'system', 'İtirazın sonuçlandı', 'Kısmi telafi uygulandı.', 'dispute', p_dispute);
  else -- capture: kredi host lehine kapanır, iade yok
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_d.opener_id, 'system', 'İtirazın sonuçlandı', 'İtiraz reddedildi.', 'dispute', p_dispute);
  end if;

  update disputes set status = case when p_decision='capture' then 'rejected' else 'resolved' end,
    decision = p_decision, decided_by = p_admin, decided_at = now() where id = p_dispute;
  return jsonb_build_object('ok', true, 'decision', p_decision);
end $$;

-- ---------- 2) FEATURE FLAGS ----------
create table if not exists feature_flags (
  key         text primary key,
  enabled     boolean not null default false,
  rollout_pct int not null default 100 check (rollout_pct between 0 and 100),
  description text,
  updated_by  uuid references users(id),
  updated_at  timestamptz default now()
);
alter table feature_flags enable row level security;
drop policy if exists "flags_read" on feature_flags;
create policy "flags_read" on feature_flags for select to authenticated using (true);

insert into feature_flags (key, enabled, rollout_pct, description) values
  ('delay_mode',      false, 100, 'Gecikme modu (LiveStatus canlı uçuş takibi)'),
  ('partner_channel', false, 100, 'Partner day-pass kanalı'),
  ('b2b',             false, 100, 'B2B kurumsal hesaplar'),
  ('marketplace',     true,  100, 'LoungePoints marketplace'),
  ('referral',        true,  100, 'Arkadaş daveti')
on conflict (key) do nothing;

-- Kullanıcı bazlı flag kontrolü (kademeli açılım: uid hash % 100 < pct)
create or replace function public.flag_enabled(p_key text)
returns boolean language sql security definer set search_path = public as $$
  select coalesce((
    select f.enabled and (
      f.rollout_pct >= 100 or
      (abs(hashtext(coalesce(auth.uid()::text,'anon'))) % 100) < f.rollout_pct
    ) from feature_flags f where f.key = p_key
  ), false);
$$;
grant execute on function public.flag_enabled(text) to authenticated;

-- ---------- 3) i18n YÖNETİMİ ----------
create table if not exists i18n_strings (
  key        text not null,
  lang       text not null check (lang in ('tr','en')),
  value      text,
  updated_at timestamptz default now(),
  primary key (key, lang)
);
alter table i18n_strings enable row level security;
drop policy if exists "i18n_read" on i18n_strings;
create policy "i18n_read" on i18n_strings for select to authenticated using (true);

-- Eksik çeviri raporu
create or replace view i18n_missing as
  select k.key,
         max(case when s.lang='tr' then s.value end) as tr,
         max(case when s.lang='en' then s.value end) as en
    from (select distinct key from i18n_strings) k
    left join i18n_strings s on s.key = k.key
   group by k.key
  having max(case when s.lang='tr' then s.value end) is null
      or max(case when s.lang='en' then s.value end) is null;

-- ---------- 4) BİLDİRİM KAMPANYALARI (segment) ----------
create table if not exists notification_campaigns (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text,
  segment      jsonb default '{}'::jsonb,   -- {airport, plan, role, min_trust}
  sent_count   int default 0,
  created_by   uuid references users(id),
  created_at   timestamptz default now()
);
alter table notification_campaigns enable row level security;

-- Segmentli gönderim
create or replace function public.send_campaign(
  p_title text, p_body text, p_segment jsonb, p_admin uuid
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_n int := 0;
begin
  insert into notification_campaigns (title, body, segment, created_by)
  values (p_title, p_body, coalesce(p_segment,'{}'::jsonb), p_admin) returning id into v_cid;

  with target as (
    select u.id from users u
    left join profiles p on p.user_id = u.id
    left join trust_scores ts on ts.user_id = u.id
    where u.deleted_at is null
      and (p_segment->>'role' is null or u.role::text = p_segment->>'role')
      and (p_segment->>'plan' is null or u.plan::text = p_segment->>'plan')
      and (p_segment->>'min_trust' is null or coalesce(ts.score,0) >= (p_segment->>'min_trust')::int)
      and (p_segment->>'airport' is null or exists (
            select 1 from visits v where v.user_id = u.id and v.airport_code = p_segment->>'airport'
          ))
  ), ins as (
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    select id, 'system'::notif_category, p_title, p_body, 'campaign', v_cid from target
    returning 1
  )
  select count(*) into v_n from ins;

  update notification_campaigns set sent_count = v_n where id = v_cid;
  return jsonb_build_object('ok', true, 'sent', v_n, 'campaign_id', v_cid);
end $$;

-- ---------- 5) PARTNER: day-pass, kural kartı, hakediş ----------
create table if not exists lounge_offers (
  id           uuid primary key default gen_random_uuid(),
  lounge_id    uuid not null references lounges(id) on delete cascade,
  offer_date   date not null,
  time_from    time not null,
  time_to      time not null,
  price_try    int not null,
  quota        int not null default 0,
  sold         int not null default 0,
  status       text not null default 'pending',  -- pending | approved | rejected | expired
  approved_by  uuid references users(id),
  created_at   timestamptz default now(),
  check (sold <= quota)
);
alter table lounge_offers enable row level security;
drop policy if exists "offers_partner_rw" on lounge_offers;
create policy "offers_partner_rw" on lounge_offers for all to authenticated
using (exists (select 1 from lounge_partners lp where lp.user_id = auth.uid() and lp.lounge_id = lounge_offers.lounge_id))
with check (exists (select 1 from lounge_partners lp where lp.user_id = auth.uid() and lp.lounge_id = lounge_offers.lounge_id));
-- Onaylı teklifler tüm kullanıcılara görünür (keşifte "Partner Lounge Fırsatı")
drop policy if exists "offers_public_read" on lounge_offers;
create policy "offers_public_read" on lounge_offers for select to authenticated
using (status = 'approved' and offer_date >= current_date);

create table if not exists partner_rule_cards (
  lounge_id    uuid primary key references lounges(id) on delete cascade,
  rules        jsonb not null default '{}'::jsonb,  -- {dress_code, guest_limit, max_duration, notes}
  status       text not null default 'draft',       -- draft | pending | approved
  approved_by  uuid references users(id),
  published_at timestamptz,
  updated_at   timestamptz default now()
);
alter table partner_rule_cards enable row level security;
drop policy if exists "rules_partner_rw" on partner_rule_cards;
create policy "rules_partner_rw" on partner_rule_cards for all to authenticated
using (exists (select 1 from lounge_partners lp where lp.user_id = auth.uid() and lp.lounge_id = partner_rule_cards.lounge_id))
with check (exists (select 1 from lounge_partners lp where lp.user_id = auth.uid() and lp.lounge_id = partner_rule_cards.lounge_id));
drop policy if exists "rules_public_read" on partner_rule_cards;
create policy "rules_public_read" on partner_rule_cards for select to authenticated
using (status = 'approved');

-- Hakediş: dönemsel day-pass geliri + komisyon
create or replace function public.partner_payout(p_lounge_id uuid, p_from date, p_to date)
returns table (period_from date, period_to date, sold int, gross_try int, commission_try int, net_try int)
language plpgsql security definer set search_path = public as $$
declare v_rate numeric := 0.15;  -- %15 komisyon (sözleşmeye göre BO'dan yönetilir)
begin
  if not exists (select 1 from lounge_partners where user_id = auth.uid() and lounge_id = p_lounge_id)
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_partner';
  end if;
  return query
  select p_from, p_to,
         coalesce(sum(o.sold),0)::int,
         coalesce(sum(o.sold * o.price_try),0)::int,
         round(coalesce(sum(o.sold * o.price_try),0) * v_rate)::int,
         (coalesce(sum(o.sold * o.price_try),0) - round(coalesce(sum(o.sold * o.price_try),0) * v_rate))::int
    from lounge_offers o
   where o.lounge_id = p_lounge_id and o.offer_date between p_from and p_to and o.status = 'approved';
end $$;
grant execute on function public.partner_payout(uuid, date, date) to authenticated;

-- ---------- 6) GÖLGE KISIT (shadow ban) + kural motoru ----------
alter table users add column if not exists shadow_limited boolean default false;
alter table users add column if not exists restricted_until timestamptz;

create table if not exists rule_thresholds (
  key        text primary key,
  value      int not null,
  description text
);
insert into rule_thresholds (key, value, description) values
  ('max_active_requests', 5,  'Bir guest aynı anda en fazla kaç açık istek'),
  ('no_show_limit',       2,  'Kaç no-show sonrası otomatik kısıt'),
  ('report_threshold',    3,  'Kaç şikayet sonrası otomatik kısıt'),
  ('restrict_days',       7,  'Otomatik kısıt süresi (gün)')
on conflict (key) do nothing;
alter table rule_thresholds enable row level security;

-- Kural motoru: şikayet eşiği aşılınca otomatik kısıt
create or replace function public.apply_rule_engine(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_reports int; v_thr int; v_days int; v_acted text := 'none';
begin
  select value into v_thr from rule_thresholds where key = 'report_threshold';
  select value into v_days from rule_thresholds where key = 'restrict_days';
  select count(*) into v_reports from reports where target_id = p_user and status = 'open';
  if v_reports >= coalesce(v_thr,3) then
    update users set shadow_limited = true,
      restricted_until = now() + make_interval(days => coalesce(v_days,7))
    where id = p_user;
    v_acted := 'shadow_limited';
  end if;
  return jsonb_build_object('ok', true, 'action', v_acted, 'open_reports', v_reports);
end $$;

-- Gölge kısıt keşifte görünürlüğü düşürür
create or replace function public.is_visible(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not coalesce((select shadow_limited and (restricted_until is null or restricted_until > now())
                       from users where id = p_user), false);
$$;

-- ---------- 7) KUPON STOK YÖNETİMİ ----------
alter table rewards add column if not exists stock int;              -- null = sınırsız
alter table rewards add column if not exists supplier text;
alter table rewards add column if not exists supplier_cost_try int;

create or replace function public.redeem_reward(p_reward_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_r rewards%rowtype; v_pts int; v_code text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_r from rewards where id = p_reward_id for update;
  if not found or not v_r.active then raise exception 'reward_unavailable'; end if;
  if v_r.stock is not null and v_r.stock <= 0 then raise exception 'out_of_stock'; end if;

  select coalesce(sum(delta),0) into v_pts from points_ledger where user_id = v_uid;
  if v_pts < v_r.cost_points then raise exception 'insufficient_points'; end if;

  v_code := 'LL-' || upper(substr(md5(random()::text), 1, 6));
  insert into redemptions (user_id, reward_id, cost_points, voucher_code)
  values (v_uid, p_reward_id, v_r.cost_points, v_code);
  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -v_r.cost_points, 'reward_redeem', p_reward_id);
  if v_r.stock is not null then
    update rewards set stock = stock - 1 where id = p_reward_id;
  end if;

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'system', 'Ödül alındı 🎁', v_r.title || ' · Kupon: ' || v_code, 'reward');
  return jsonb_build_object('ok', true, 'code', v_code);
end $$;
grant execute on function public.redeem_reward(uuid) to authenticated;

-- ---------- 8) k-ANONİMİTE >= 5 DÜZELTMESİ (EK-2 §3.1) ----------
create or replace function public.partner_demand(p_lounge_id uuid)
returns table (
  bucket_date date, total_availabilities int, total_slots int,
  filled_slots int, request_count int
)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from lounge_partners where user_id = auth.uid() and lounge_id = p_lounge_id)
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_partner';
  end if;

  return query
  with agg as (
    select a.avail_date as d,
           count(*)::int as n_av,
           coalesce(sum(a.slots),0)::int as n_slots,
           coalesce(sum(a.filled),0)::int as n_filled,
           (select count(*)::int from requests r where r.avail_id in (select id from availabilities x where x.lounge_id = p_lounge_id and x.avail_date = a.avail_date)) as n_req,
           count(distinct a.host_id)::int as n_hosts
      from availabilities a
     where a.lounge_id = p_lounge_id
     group by a.avail_date
  )
  select d, n_av, n_slots, n_filled, n_req
    from agg
   where n_hosts >= 5      -- EK-2: k-anonimite >= 5, 5'ten az kullanıcılı hücre gösterilmez
   order by d desc
   limit 60;
end $$;
grant execute on function public.partner_demand(uuid) to authenticated;

select 'BO REQUIREMENTS OK' as sonuc;
