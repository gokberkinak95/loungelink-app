-- =====================================================================
-- 036 · HOST BAŞVURUSU + admin profil düzenleme
-- Bağımlılık: 035'ten SONRA. Önce 036a_PRE_drop çalıştır.
--
-- NEDEN: Guest olarak kaydolan biri sonradan lounge hakkı edinebilir
-- (kredi kartı yükseltmesi, yeni iş, statü). Şu an rolünü değiştirmenin
-- HİÇBİR yolu yok — bize yazması gerekiyor. Bu, arz tarafını büyütmenin
-- en ucuz kanalını kapatıyordu: zaten uygulamada olan, güvenini kurmuş,
-- ürünü anlamış insanlar.
--
-- NEDEN OTOMATİK DEĞİL: host olmak "ben lounge hakkım var" demekle
-- olmuyor — bu beyan, platformun tüm güven vaadinin dayandığı temel.
-- Yanlış beyan = guest havaalanına gider, içeri giremez, ürün ölür.
-- O yüzden insan onayı şart (§16 trust mimarisi).
-- =====================================================================

create table if not exists host_applications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  access_source text not null,            -- Priority Pass, LoungeKey, ...
  guest_capacity int  not null,           -- 1 | 2 | 3+
  note          text,                     -- kullanıcının açıklaması (140 kar.)
  status        text not null default 'pending',   -- pending | approved | rejected
  reviewed_by   text,
  reviewed_at   timestamptz,
  review_note   text,
  created_at    timestamptz not null default now()
);

create index if not exists idx_host_app_status on host_applications(status, created_at desc);
-- Aynı anda tek bekleyen başvuru
create unique index if not exists uq_host_app_pending
  on host_applications(user_id) where status = 'pending';

alter table host_applications enable row level security;
drop policy if exists host_app_own_read on host_applications;
create policy host_app_own_read on host_applications for select using (user_id = auth.uid());

-- ---------- Kullanıcı: başvuru gönder ----------
create or replace function public.apply_for_host(
  p_access_source text, p_guest_capacity int, p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_role user_role; v_ok boolean; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select role into v_role from users where id = v_uid;
  if v_role = 'host' then raise exception 'already_host'; end if;

  -- Telefon doğrulaması şart (§16 — beyan sahibi ulaşılabilir olmalı)
  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok, false) then raise exception 'phone_not_verified'; end if;

  if coalesce(trim(p_access_source),'') = '' then raise exception 'access_source_required'; end if;
  if p_guest_capacity is null or p_guest_capacity < 1 then raise exception 'capacity_required'; end if;

  if exists (select 1 from host_applications where user_id = v_uid and status = 'pending') then
    raise exception 'application_pending';
  end if;

  insert into host_applications (user_id, access_source, guest_capacity, note)
  values (v_uid, p_access_source, p_guest_capacity, left(coalesce(p_note,''), 140))
  returning id into v_id;

  insert into notifications (user_id, category, title, body)
  values (v_uid, 'system', 'Başvurun alındı ✦',
          'Host başvurun incelemeye alındı. Sonucu bildirimle ileteceğiz.');

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
grant execute on function public.apply_for_host(text, int, text) to authenticated;

-- ---------- Kullanıcı: kendi başvurumun durumu ----------
create or replace function public.my_host_application()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_a host_applications%rowtype; v_role user_role;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select role into v_role from users where id = v_uid;
  if v_role = 'host' then return jsonb_build_object('is_host', true); end if;

  select * into v_a from host_applications
   where user_id = v_uid order by created_at desc limit 1;

  if not found then return jsonb_build_object('is_host', false, 'status', 'none'); end if;

  return jsonb_build_object(
    'is_host', false,
    'status', v_a.status,
    'access_source', v_a.access_source,
    'guest_capacity', v_a.guest_capacity,
    'review_note', v_a.review_note,
    'created_at', v_a.created_at
  );
end $$;
grant execute on function public.my_host_application() to authenticated;

-- ---------- Admin: başvuruyu onayla / reddet ----------
create or replace function public.review_host_application(
  p_id uuid, p_approve boolean, p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_a host_applications%rowtype;
begin
  select * into v_a from host_applications where id = p_id for update;
  if not found then raise exception 'application_not_found'; end if;
  if v_a.status <> 'pending' then raise exception 'already_reviewed'; end if;

  update host_applications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_at = now(), review_note = p_note
   where id = p_id;

  if p_approve then
    -- Rolü host yap + beyanı profile işle
    update users set role = 'host' where id = v_a.user_id;
    update profiles
       set access_source = v_a.access_source,
           guest_capacity = v_a.guest_capacity
     where user_id = v_a.user_id;

    -- Trust: host erişim kaynağı beyanı (§16) — 033'teki recompute_trust yeniden hesaplar
    perform recompute_trust(v_a.user_id);
    perform recompute_badge(v_a.user_id);

    insert into notifications (user_id, category, title, body)
    values (v_a.user_id, 'system', 'Host başvurun onaylandı ✦',
            'Artık lounge ilanı açabilirsin. Hosting sekmesinden ilk ilanını oluştur.');
  else
    insert into notifications (user_id, category, title, body)
    values (v_a.user_id, 'system', 'Host başvurun sonuçlandı',
            coalesce(nullif(p_note,''), 'Başvurun bu sefer onaylanmadı. Detay için destek ile iletişime geçebilirsin.'));
  end if;

  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.review_host_application(uuid, boolean, text) to authenticated;

-- ---------- Admin: kullanıcı profilini düzenle ----------
-- BO'da "Detay" salt okunurdu; düzenleme yoktu. Destek talebinde
-- (yanlış yazılmış isim, uygunsuz bio) elle müdahale gerekiyor.
create or replace function public.admin_update_profile(p_user uuid, p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update profiles set
    name               = coalesce(p_patch->>'name', name),
    profession         = coalesce(p_patch->>'profession', profession),
    bio                = coalesce(p_patch->>'bio', bio),
    linkedin_url       = coalesce(p_patch->>'linkedin_url', linkedin_url),
    access_source      = coalesce(p_patch->>'access_source', access_source),
    guest_capacity     = coalesce((p_patch->>'guest_capacity')::int, guest_capacity),
    profile_visibility = coalesce((p_patch->>'profile_visibility')::profile_visibility, profile_visibility),
    women_safety_mode  = coalesce((p_patch->>'women_safety_mode')::boolean, women_safety_mode),
    location_sharing   = coalesce((p_patch->>'location_sharing')::boolean, location_sharing),
    show_on_discovery  = coalesce((p_patch->>'show_on_discovery')::boolean, show_on_discovery),
    updated_at         = now()
  where user_id = p_user;

  if p_patch ? 'linkedin_verified' then
    update profiles set linkedin_verified = (p_patch->>'linkedin_verified')::boolean where user_id = p_user;
  end if;

  perform recompute_trust(p_user);
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.admin_update_profile(uuid, jsonb) to authenticated;

select 'HOST APPLICATIONS OK' as sonuc;
