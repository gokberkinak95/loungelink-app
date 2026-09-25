-- ============================================================
-- LoungeLink · 048_promo_campaigns.sql   (ÖNCE 048a çalıştır)
--
-- Gokberk'in üç isteği:
-- 1) KATILIMLI KAMPANYA: duyuruda "Kampanyalar'dan katıl" denir;
--    kullanıcı app'te Katıl'a basar; katılım BO'da log olarak düşer,
--    gereği elle yapılır. (notification_campaigns = duyuru; bu AYRI:
--    katılım toplayan kampanya.)
-- 2) PROMOSYON KODU: BO'da kod tanımlanır (puan/kredi), kullanıcı
--    app'te girer, ödül sunucu tarafında yazılır.
-- 3) REFERANS GİRİŞİ: 🔴 apply_referral (028) VAR ama app HİÇBİR
--    YERDEN çağırmıyordu — kod üretiliyor, girecek yer yoktu.
--    App v1.26 kayıt adım 1'e opsiyonel alan ekliyor; burada yalnız
--    BO görünürlüğü için referral log görünümü ekleniyor.
-- ============================================================

-- ---------- 1) KATILIMLI KAMPANYALAR ----------
create table if not exists promo_campaigns (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  ends_at     date,                      -- null = süresiz
  active      boolean default true,
  created_by  uuid references users(id),
  created_at  timestamptz default now()
);
alter table promo_campaigns enable row level security;
drop policy if exists "campaigns_read" on promo_campaigns;
create policy "campaigns_read" on promo_campaigns
  for select to authenticated using (active and (ends_at is null or ends_at >= current_date));

create table if not exists campaign_participations (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references promo_campaigns(id),
  user_id     uuid not null references users(id),
  created_at  timestamptz default now(),
  unique (campaign_id, user_id)          -- bir kampanyaya bir kez katılım
);
alter table campaign_participations enable row level security;
drop policy if exists "part_own_read" on campaign_participations;
create policy "part_own_read" on campaign_participations
  for select to authenticated using (user_id = auth.uid());

-- Aktif kampanyalar + benim katılım durumum
create or replace function public.active_campaigns()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'title', c.title, 'description', c.description,
    'ends_at', c.ends_at,
    'joined', exists (select 1 from campaign_participations cp
                      where cp.campaign_id = c.id and cp.user_id = auth.uid())
  ) order by c.created_at desc), '[]'::jsonb)
  from promo_campaigns c
  where c.active and (c.ends_at is null or c.ends_at >= current_date);
$$;
grant execute on function public.active_campaigns() to authenticated;

create or replace function public.join_campaign(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_title text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select title into v_title from promo_campaigns
   where id = p_id and active and (ends_at is null or ends_at >= current_date);
  if v_title is null then raise exception 'campaign_not_found_or_ended'; end if;
  insert into campaign_participations (campaign_id, user_id) values (p_id, v_uid)
    on conflict (campaign_id, user_id) do nothing;
  -- BO'ya log: denetim kaydına düşer (aktör = kullanıcı)
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.campaign_join', 'promo_campaigns', p_id,
          jsonb_build_object('user_id', v_uid, 'campaign', v_title));
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.join_campaign(uuid) to authenticated;

create or replace function public.admin_create_campaign(
  p_title text, p_description text, p_ends date, p_admin uuid
) returns uuid language sql security definer set search_path = public as $$
  insert into promo_campaigns (title, description, ends_at, created_by)
  values (p_title, p_description, p_ends, p_admin) returning id;
$$;
revoke execute on function public.admin_create_campaign(text, text, date, uuid) from public, anon, authenticated;

-- ---------- 2) PROMOSYON KODLARI ----------
create table if not exists promo_codes (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  reward_type text not null check (reward_type in ('points','credits')),
  amount      int  not null check (amount > 0),
  max_uses    int,                       -- null = sınırsız
  used_count  int  default 0,
  expires_at  date,
  active      boolean default true,
  created_by  uuid references users(id),
  created_at  timestamptz default now()
);
alter table promo_codes enable row level security;   -- SELECT policy YOK: kod listesi görünmez, yalnız RPC ile denenir

create table if not exists promo_redemptions (
  id         uuid primary key default gen_random_uuid(),
  code_id    uuid not null references promo_codes(id),
  user_id    uuid not null references users(id),
  created_at timestamptz default now(),
  unique (code_id, user_id)              -- kişi başı bir kez
);
alter table promo_redemptions enable row level security;
drop policy if exists "redeem_own_read" on promo_redemptions;
create policy "redeem_own_read" on promo_redemptions
  for select to authenticated using (user_id = auth.uid());

create or replace function public.redeem_promo_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid; v_type text; v_amount int; v_max int; v_used int; v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select id, reward_type, amount, max_uses, used_count
    into v_id, v_type, v_amount, v_max, v_used
    from promo_codes
   where upper(code) = upper(trim(p_code)) and active
     and (expires_at is null or expires_at >= current_date)
   for update;
  if v_id is null then raise exception 'invalid_or_expired_code'; end if;
  if v_max is not null and v_used >= v_max then raise exception 'code_limit_reached'; end if;
  if exists (select 1 from promo_redemptions where code_id = v_id and user_id = v_uid) then
    raise exception 'code_already_used';
  end if;

  insert into promo_redemptions (code_id, user_id) values (v_id, v_uid);
  update promo_codes set used_count = used_count + 1 where id = v_id;

  if v_type = 'points' then
    insert into points_ledger (user_id, delta, reason, ref_id)
    values (v_uid, v_amount, 'promo_code', v_id);
  else
    select coalesce((select balance_after from credit_ledger
                     where user_id = v_uid order by created_at desc limit 1), 0) into v_bal;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_uid, v_amount, 'promo_code', v_id, v_bal + v_amount);
  end if;

  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.promo_redeem', 'promo_codes', v_id,
          jsonb_build_object('user_id', v_uid, 'reward', v_type, 'amount', v_amount));

  return jsonb_build_object('ok', true, 'reward_type', v_type, 'amount', v_amount);
end $$;
grant execute on function public.redeem_promo_code(text) to authenticated;

create or replace function public.admin_create_promo_code(
  p_code text, p_type text, p_amount int, p_max int, p_expires date, p_admin uuid
) returns uuid language sql security definer set search_path = public as $$
  insert into promo_codes (code, reward_type, amount, max_uses, expires_at, created_by)
  values (upper(trim(p_code)), p_type, p_amount, p_max, p_expires, p_admin) returning id;
$$;
revoke execute on function public.admin_create_promo_code(text, text, int, int, date, uuid) from public, anon, authenticated;

-- ---------- 3) REFERANS LOG'U (BO görünürlüğü) ----------
-- apply_referral (028) zaten profiles.referred_by yazıyor + audit'e bir şey
-- yazmıyordu. BO "kim kimin refiyle geldi" listesini şu view'dan okur:
create or replace view referral_log as
  select p.user_id            as joined_user,
         p.name               as joined_name,
         u.email              as joined_email,
         p.referred_by        as referrer_user,
         rp.name              as referrer_name,
         ru.email             as referrer_email,
         u.created_at         as joined_at
    from profiles p
    join users u  on u.id  = p.user_id
    join profiles rp on rp.user_id = p.referred_by
    join users ru on ru.id = p.referred_by
   where p.referred_by is not null;
-- view; RLS tabanı users/profiles. BO service_role ile okur.

select '048 OK — katılımlı kampanya + promosyon kodu + referans log' as sonuc;
