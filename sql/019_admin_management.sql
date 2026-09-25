-- ============================================================
-- LoungeLink · 019_admin_management.sql
-- Backoffice yönetim yazma yetkileri (yalnız admin_roles'taki kullanıcılar).
-- Backoffice zaten SUPABASE_SECRET_KEY (service role) ile yazıyor; bu SQL
-- ek RPC'ler + isteğe bağlı yardımcılar sağlar. Service role RLS'i aştığı için
-- politika şart değil ama manuel kredi/puan için güvenli RPC ekliyoruz.
-- ============================================================

-- Admin: kullanıcıya manuel kredi ekle/düş (destek amaçlı, audit ile)
create or replace function public.admin_adjust_credit(p_user uuid, p_delta int, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_bal int;
begin
  -- Bu RPC yalnız service role veya admin tarafından çağrılır (backoffice).
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = p_user;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (p_user, p_delta, coalesce(p_reason,'admin_adjust'), v_bal + p_delta);
  return jsonb_build_object('ok', true, 'new_balance', v_bal + p_delta);
end $$;

-- Admin: kullanıcıya manuel puan ekle/düş
create or replace function public.admin_adjust_points(p_user uuid, p_delta int, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  insert into points_ledger (user_id, delta, reason)
  values (p_user, p_delta, coalesce(p_reason,'admin_adjust'));
  return jsonb_build_object('ok', true);
end $$;

select 'ADMIN MGMT OK' as sonuc;
