-- ============================================================
-- LoungeLink · 018_subscriptions.sql — Abonelik planları
-- Plan seçimi + yükseltme gerçek; ödeme (Google Play Billing) beta'da bağlanır.
-- Şimdilik demo onayla plan değişir. Kredi limiti plana göre.
-- ============================================================

-- Plan özellik kataloğu (istemci gösterimi + kredi limiti)
create table if not exists plan_catalog (
  plan            plan_type primary key,
  monthly_credits int not null,
  price_try       int not null,
  perks           jsonb default '[]'::jsonb,
  sort_order      int
);
alter table plan_catalog enable row level security;
drop policy if exists "plan_catalog_read" on plan_catalog;
create policy "plan_catalog_read" on plan_catalog for select to authenticated using (true);

insert into plan_catalog (plan, monthly_credits, price_try, perks, sort_order) values
  ('explorer', 2, 0,
    '["Aylık 2 kredi","Temel keşif","Uygulama içi sohbet"]'::jsonb, 1),
  ('traveler', 8, 149,
    '["Aylık 8 kredi","Öncelikli eşleşme","Genişletilmiş keşif filtreleri","Doğrulanmış rozet önceliği"]'::jsonb, 2),
  ('frequent', 20, 349,
    '["Aylık 20 kredi","En üst sıralama","Tüm filtreler + gelişmiş analiz","Öncelikli destek","Erken erişim özellikleri"]'::jsonb, 3)
on conflict (plan) do update set
  monthly_credits = excluded.monthly_credits, price_try = excluded.price_try,
  perks = excluded.perks, sort_order = excluded.sort_order;

-- Plan değiştir (demo: ödeme onayı simüle; yükseltmede kredi farkını ver)
create or replace function public.change_plan(p_plan plan_type)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_current plan_type;
  v_new_credits int; v_old_credits int; v_diff int; v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select plan into v_current from users where id = v_uid;
  if v_current = p_plan then raise exception 'already_on_plan'; end if;

  select monthly_credits into v_new_credits from plan_catalog where plan = p_plan;
  select monthly_credits into v_old_credits from plan_catalog where plan = v_current;

  -- users.plan güncelle
  update users set plan = p_plan where id = v_uid;

  -- subscriptions kaydı (demo — stripe alanları boş)
  insert into subscriptions (user_id, plan, status, renews_at)
  values (v_uid, p_plan, 'active', now() + interval '30 days')
  on conflict (user_id) do update set plan = p_plan, status = 'active',
    renews_at = now() + interval '30 days', cancelled_at = null;

  -- Yükseltmede kredi farkını hemen ver (demo davranışı)
  v_diff := v_new_credits - v_old_credits;
  if v_diff > 0 then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
    insert into credit_ledger (user_id, delta, reason, balance_after)
    values (v_uid, v_diff, 'plan_upgrade', v_bal + v_diff);
  end if;

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'system', 'Plan güncellendi 🎉',
    'Yeni planın: ' || p_plan || (case when v_diff>0 then ' · +'||v_diff||' kredi' else '' end), 'plan');

  return jsonb_build_object('ok', true, 'plan', p_plan, 'credits_added', greatest(v_diff,0));
end $$;
grant execute on function public.change_plan(plan_type) to authenticated;

select 'SUBSCRIPTIONS OK' as sonuc;
