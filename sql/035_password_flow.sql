-- =====================================================================
-- 035 · Şifre akışı — ilk girişte zorunlu değişiklik
-- Bağımlılık: 034'ten SONRA. Önce 035a_PRE_drop çalıştır.
--
-- KARAR: Sabit şifre (LoungeLink123! gibi) KULLANILMADI.
-- Sebep: deseni bilen biri, sen hesabı açtıktan sonra sahibi ilk
-- girişini yapmadan önce içeri girebilir. Lounge partneri e-postayı
-- 2 gün sonra okursa pencere 2 gün açık kalır. Rastgele şifre admin
-- için zahmet değil (kopyala-yapıştır) ama saldırgan için tahmin
-- edilemez. Fikrin asıl değerli kısmı — ilk girişte zorunlu
-- değiştirme — aynen uygulandı.
--
-- NOT: 020'deki upsert_admin imzası KORUNUR:
--   p_permissions = jsonb (text[] DEĞİL)
--   auth.users'tan okur (users değil)
--   role::text (enum cast YOK)
-- Yalnızca p_must_change parametresi eklenir.
-- =====================================================================

-- Geçici şifreyle açılan hesaplar işaretlenir
alter table admin_roles      add column if not exists must_change_password boolean not null default false;
alter table lounge_partners  add column if not exists must_change_password boolean not null default false;

-- Kullanıcı şifresini değiştirmek zorunda mı?
create or replace function public.needs_password_change(p_user uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select must_change_password from admin_roles where user_id = coalesce(p_user, auth.uid())),
    (select bool_or(must_change_password) from lounge_partners where user_id = coalesce(p_user, auth.uid())),
    false
  );
$$;
grant execute on function public.needs_password_change(uuid) to authenticated;

-- Şifre değiştirildi → bayrağı indir
create or replace function public.mark_password_changed()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update admin_roles      set must_change_password = false where user_id = v_uid;
  update lounge_partners  set must_change_password = false where user_id = v_uid;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.mark_password_changed() to authenticated;

-- upsert_admin: 020'nin sözleşmesi + p_must_change
create or replace function public.upsert_admin(
  p_email text, p_role text, p_permissions jsonb, p_display_name text default null,
  p_must_change boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid;
begin
  select id into v_uid from auth.users where email = lower(p_email);
  if v_uid is null then raise exception 'user_not_found'; end if;

  insert into admin_roles (user_id, role, permissions, display_name, must_change_password)
  values (v_uid, p_role::text, coalesce(p_permissions,'[]'::jsonb), p_display_name, p_must_change)
  on conflict (user_id) do update set
    role = excluded.role, permissions = excluded.permissions,
    display_name = coalesce(excluded.display_name, admin_roles.display_name),
    must_change_password = excluded.must_change_password;
  return jsonb_build_object('ok', true, 'user_id', v_uid);
end $$;
grant execute on function public.upsert_admin(text, text, jsonb, text, boolean) to authenticated;

select 'PASSWORD FLOW OK' as sonuc;
