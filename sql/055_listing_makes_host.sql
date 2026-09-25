-- ============================================================
-- LoungeLink · 055_listing_makes_host.sql
--
-- 🔴 KÖK (Gokberk: "açık host ilanı var ama Host Bul/Keşfet boş"):
-- discover_availabilities kapısı: hu.role='host' OR onaylı host başvurusu.
-- create_availability ilan açıyordu ama users.role'ü GÜNCELLEMİYORDU. Üstelik
-- BO v1.20 staff hesabının rolünü 'admin' yaptı → Gokberk'in hesabı 'admin',
-- host değil → kendi ilanı bile keşif kapısından geçemiyordu.
--
-- Bu dosya: (1) create_availability artık ilan açan kişiyi role='host' yapıyor,
-- (2) hâlihazırda aktif ilanı olan ama host olmayan hesapları toplu düzeltir.
-- ============================================================

create or replace function public.create_availability(
  p_lounge_id uuid, p_airport text, p_date date, p_from time, p_to time, p_slots int,
  p_flight text default null, p_visibility text default 'all'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_cap int; v_ok boolean; v_id uuid; v_conflict boolean;
  v_vis availability_visibility; v_min_trust smallint := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if p_slots > v_cap then raise exception 'slots_exceed_capacity'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;

  -- 033: örtüşen saatte bekleyen/kabul edilmiş guest isteğin varsa ilan açamazsın
  select exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = p_date
       and a.time_from < p_to and p_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'guest_same_slot'; end if;

  -- YENİ (040): MVP'nin all/trusted/hidden -> enum + eşik
  case lower(coalesce(p_visibility,'all'))
    when 'all'         then v_vis := 'Public';      v_min_trust := 0;
    when 'trusted'     then v_vis := 'Public';      v_min_trust := 55;
    when 'hidden'      then v_vis := 'Hidden';      v_min_trust := 0;
    when 'connections' then v_vis := 'Connections'; v_min_trust := 0;
    else raise exception 'bad_visibility';
  end case;

  insert into availabilities (
    host_id, lounge_id, airport_code, avail_date, time_from, time_to,
    slots, filled, active, visibility, flight_number, min_trust
  )
  values (
    v_uid, p_lounge_id, p_airport, p_date, p_from, p_to,
    p_slots, 0, true, v_vis, nullif(trim(p_flight),''), v_min_trust
  )
  returning id into v_id;

  -- YENİ (055): ilan açmak = host olmak. Rol 'guest'/'admin' ise 'host' yap ki
  -- discover_availabilities'in hu.role='host' kapısından geçsin. (admin: BO'dan
  -- açılan hesap test host'u da olabilir — ilan açınca app'te host olur.)
  update users set role = 'host' where id = v_uid and role <> 'host';

  return jsonb_build_object('ok', true, 'id', v_id, 'visibility', v_vis, 'min_trust', v_min_trust);
end $$;

-- (2) Mevcut durum düzeltmesi: aktif ilanı olan herkes host olmalı
update users u set role = 'host'
where u.role <> 'host'
  and exists (select 1 from availabilities a where a.host_id = u.id and a.active = true);

select '055 OK — ilan açan host olur + mevcut ilan sahipleri host yapıldı' as sonuc;
