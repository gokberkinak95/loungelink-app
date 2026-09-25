-- ============================================================
-- LoungeLink · 017_marketplace.sql — Marketplace + LoungePuan harcama
-- Katalog + puan düşme + kupon üretimi gerçek; ödül teslimi demo (beta'da
-- gerçek tedarikçiye bağlanır). Puan bakiyesi points_ledger toplamıdır.
-- ============================================================

-- 1) Ödül kataloğu
create table if not exists rewards (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  subtitle    text,
  category    text,                 -- lounge | miles | hotel | esim | insurance
  cost_points int not null,
  active      boolean default true,
  sort_order  int default 0
);
alter table rewards enable row level security;
drop policy if exists "rewards_read" on rewards;
create policy "rewards_read" on rewards for select to authenticated using (active = true);

-- 2) Kullanımlar (redemption) — üretilen kupon kodu burada
create table if not exists redemptions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references users(id) on delete cascade,
  reward_id    uuid not null references rewards(id),
  cost_points  int not null,
  voucher_code text not null,
  created_at   timestamptz default now()
);
alter table redemptions enable row level security;
drop policy if exists "redemptions_own" on redemptions;
create policy "redemptions_own" on redemptions for select to authenticated
  using (user_id = auth.uid());

-- 3) Ödül al: puan yeter mi kontrol + düş + kupon üret (atomik)
create or replace function public.redeem_reward(p_reward_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_reward rewards%rowtype; v_bal int; v_code text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_reward from rewards where id = p_reward_id and active;
  if not found then raise exception 'reward_not_found'; end if;

  select coalesce(sum(delta),0) into v_bal from points_ledger where user_id = v_uid;
  if v_bal < v_reward.cost_points then raise exception 'insufficient_points'; end if;

  -- Demo kupon kodu: LL-XXXXXX
  v_code := 'LL-' || upper(substr(md5(random()::text), 1, 6));

  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -v_reward.cost_points, 'reward_redeem', p_reward_id);

  insert into redemptions (user_id, reward_id, cost_points, voucher_code)
  values (v_uid, p_reward_id, v_reward.cost_points, v_code);

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'system', 'Ödül alındı 🎁', v_reward.title || ' · kupon: ' || v_code, 'reward');

  return jsonb_build_object('ok', true, 'voucher', v_code, 'balance', v_bal - v_reward.cost_points);
end $$;
grant execute on function public.redeem_reward(uuid) to authenticated;

-- 4) Katalog seed (demo ödüller)
insert into rewards (title, subtitle, category, cost_points, sort_order) values
  ('Priority Pass Misafir Kartı', '1 misafir · 60+ ülke', 'lounge', 5000, 1),
  ('DragonPass Günlük Kart', '1 günlük lounge erişimi', 'lounge', 4000, 2),
  ('Türk Hava Yolları 500 Mil', 'Miles&Smiles', 'miles', 2500, 3),
  ('Booking.com 25$ Kredi', 'Her konaklama', 'hotel', 3000, 4),
  ('Airalo eSIM 3GB', 'Küresel veri', 'esim', 1500, 5),
  ('SafetyWing 1 Ay', 'Seyahat sigortası', 'insurance', 3500, 6)
on conflict do nothing;

select 'MARKETPLACE OK' as sonuc;
