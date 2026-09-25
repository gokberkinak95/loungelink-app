-- LoungeLink · 003_admin_roles.sql — Backoffice yetki tablosu
create table if not exists admin_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('super_admin','ops','trust_safety','finance','partner_manager')),
  created_at timestamptz default now()
);
alter table admin_roles enable row level security;
drop policy if exists "read own admin role" on admin_roles;
create policy "read own admin role" on admin_roles
  for select to authenticated using (auth.uid() = user_id);

-- Kendini super_admin yap
insert into admin_roles (user_id, role)
select id, 'super_admin' from auth.users where email = 'gokberkinak95@gmail.com'
on conflict (user_id) do update set role = 'super_admin';

select u.email, a.role from admin_roles a join auth.users u on u.id = a.user_id;
