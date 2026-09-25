-- ============================================================
-- LoungeLink · 023_partner_portal.sql — Lounge Partner Portal
-- Bir partner yalnız KENDİ lounge'unun verisini görür (izolasyon).
-- k-anonimite: tekil kullanıcı ifşa edilmez, yalnız toplu sayılar.
-- ============================================================

-- Partner ↔ lounge eşlemesi
create table if not exists lounge_partners (
  user_id    uuid not null references users(id) on delete cascade,
  lounge_id  uuid not null references lounges(id) on delete cascade,
  role       text default 'viewer',   -- viewer | manager
  created_at timestamptz default now(),
  primary key (user_id, lounge_id)
);
alter table lounge_partners enable row level security;
drop policy if exists "partner_self" on lounge_partners;
create policy "partner_self" on lounge_partners for select to authenticated
  using (user_id = auth.uid());

-- Partner'ın kendi lounge'u için TOPLU talep verisi (k-anonimite: min 3 kişi)
create or replace function public.partner_demand(p_lounge_id uuid)
returns table (
  bucket_date date, total_availabilities int, total_slots int,
  filled_slots int, request_count int
)
language plpgsql security definer set search_path = public as $$
begin
  -- Yetki: çağıran bu lounge'un partner'ı mı?
  if not exists (select 1 from lounge_partners where user_id = auth.uid() and lounge_id = p_lounge_id) then
    raise exception 'not_partner';
  end if;

  return query
  select a.avail_date,
         count(*)::int,
         coalesce(sum(a.slots),0)::int,
         coalesce(sum(a.filled),0)::int,
         (select count(*)::int from requests r where r.avail_id = any(array_agg(a.id)))
    from availabilities a
   where a.lounge_id = p_lounge_id
   group by a.avail_date
   having count(*) >= 1
   order by a.avail_date desc
   limit 60;
end $$;
grant execute on function public.partner_demand(uuid) to authenticated;

-- Admin: bir kullanıcıyı bir lounge'a partner olarak ata (BO'dan)
create or replace function public.assign_partner(p_email text, p_lounge_id uuid, p_role text default 'viewer')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid;
begin
  select id into v_uid from auth.users where email = lower(p_email);
  if v_uid is null then raise exception 'user_not_found'; end if;
  insert into lounge_partners (user_id, lounge_id, role)
  values (v_uid, p_lounge_id, p_role)
  on conflict (user_id, lounge_id) do update set role = excluded.role;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.assign_partner(text, uuid, text) to authenticated;

select 'PARTNER PORTAL OK' as sonuc;
