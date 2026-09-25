-- LoungeLink · 004_auth_bridge.sql
-- Supabase Auth kaydını uygulama tablolarına köprüler.

-- Eski tasarımdan kalan zorunlu alanı yumuşat (şifreyi artık Supabase Auth tutuyor)
alter table public.users alter column password_hash set default 'supabase-auth';

-- Yeni auth kullanıcısı -> users + profiles + verifications + trust_scores + 2 hoş geldin kredisi
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  g user_gender;
  n text;
begin
  begin
    g := (new.raw_user_meta_data->>'gender')::user_gender;
  exception when others then
    g := null;
  end;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  insert into public.users (id, email, role, gender, password_hash)
  values (new.id, new.email, 'guest', g, 'supabase-auth')
  on conflict (id) do nothing;

  insert into public.profiles (user_id, name) values (new.id, n)
  on conflict (user_id) do nothing;

  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now())
  on conflict (user_id) do nothing;

  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New')
  on conflict (user_id) do nothing;

  insert into public.credit_ledger (user_id, delta, reason, balance_after)
  values (new.id, 2, 'signup_grant', 2);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Mevcut auth kullanıcılarını (sen) geriye dönük köprüle
insert into public.users (id, email, role, password_hash)
select id, email, 'guest', 'supabase-auth' from auth.users
on conflict (id) do nothing;

insert into public.profiles (user_id, name)
select id, split_part(email, '@', 1) from auth.users
on conflict (user_id) do nothing;

insert into public.verifications (user_id, email_verified, email_verified_at)
select id, true, now() from auth.users
on conflict (user_id) do nothing;

insert into public.trust_scores (user_id, score, components, badge)
select id, 10, '{"email":10}'::jsonb, 'New' from auth.users
on conflict (user_id) do nothing;

select u.email, p.name, t.score from public.users u
join public.profiles p on p.user_id = u.id
join public.trust_scores t on t.user_id = u.id;
