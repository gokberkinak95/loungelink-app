-- LoungeLink · 025_role_on_signup.sql — Kayıtta rol seçimi (MVP paritesi)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare g user_gender; n text; r user_role;
begin
  begin g := (new.raw_user_meta_data->>'gender')::user_gender; exception when others then g := null; end;
  begin r := coalesce((new.raw_user_meta_data->>'role')::user_role, 'guest'); exception when others then r := 'guest'; end;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  insert into public.users (id, email, role, gender, password_hash)
  values (new.id, new.email, r, g, 'supabase-auth') on conflict (id) do nothing;
  insert into public.profiles (user_id, name) values (new.id, n) on conflict (user_id) do nothing;
  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now()) on conflict (user_id) do nothing;
  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New') on conflict (user_id) do nothing;
  insert into public.credit_ledger (user_id, delta, reason, balance_after)
  values (new.id, 2, 'signup_grant', 2);
  return new;
end $$;
select 'ROLE ON SIGNUP OK' as sonuc;
