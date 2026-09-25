-- ============================================================
-- LoungeLink · 020_rbac.sql — Rol Bazlı Erişim (RBAC)
-- admin_roles'a modül izinleri ekler. Her admin hangi modüllere
-- erişebileceğini checkbox'larla belirlenir. super_admin her şeye erişir.
-- ============================================================

-- Modül izinleri: jsonb dizi (ör. ["users","finance","moderation"])
alter table admin_roles add column if not exists permissions jsonb default '[]'::jsonb;
alter table admin_roles add column if not exists display_name text;
alter table admin_roles add column if not exists created_by uuid;

-- Mevcut super_admin'e tüm izinleri ver
update admin_roles
   set permissions = '["users","finance","moderation","catalog","analytics","team","content","comms"]'::jsonb
 where role = 'super_admin';

-- Yardımcı: bir kullanıcının belirli bir modüle erişimi var mı?
-- super_admin her zaman true. Diğerleri permissions dizisine bakılır.
create or replace function public.admin_has_permission(p_user uuid, p_module text)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from admin_roles
     where user_id = p_user
       and (role = 'super_admin' or permissions ? p_module)
  );
$$;

-- Admin ekle/güncelle (yalnız super_admin çağırmalı — BO tarafında kontrol edilir)
create or replace function public.upsert_admin(
  p_email text, p_role text, p_permissions jsonb, p_display_name text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid;
begin
  select id into v_uid from auth.users where email = lower(p_email);
  if v_uid is null then raise exception 'user_not_found'; end if;

  insert into admin_roles (user_id, role, permissions, display_name)
  values (v_uid, p_role::text, coalesce(p_permissions,'[]'::jsonb), p_display_name)
  on conflict (user_id) do update set
    role = excluded.role, permissions = excluded.permissions,
    display_name = coalesce(excluded.display_name, admin_roles.display_name);
  return jsonb_build_object('ok', true, 'user_id', v_uid);
end $$;

-- Admin yetkisini kaldır
create or replace function public.remove_admin(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  delete from admin_roles where user_id = p_user;
  return jsonb_build_object('ok', true);
end $$;

select 'RBAC OK' as sonuc,
  (select permissions from admin_roles where role='super_admin' limit 1) as super_admin_perms;
