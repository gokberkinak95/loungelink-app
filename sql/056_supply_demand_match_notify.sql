-- ============================================================
-- LoungeLink · 056_supply_demand_match_notify.sql  (055'i GÜNCELLER)
--
-- BÜYÜME MOTORU (#3/#8/#2/#1): arz-talep eşleştirme bildirimi.
-- Sorun: bir host ilan açtığında, o havalimanında zaten seyahati olan (yani
-- TALEP eden) guest'ler bunu bilmiyordu — Host Bul'a tekrar bakmaları gerekiyordu.
-- Çözüm: create_availability artık ilan açılır açılmaz, aynı havalimanı+tarih+
-- çakışan saatte seyahati olan tüm guest'lere "host geldi, başvur" bildirimi atar.
-- Bu, soğuk-başlangıcı kıran çift yönlü eşleştirmenin ARZ→TALEP yönü.
-- (TALEP→ARZ yönü — yeni host'a "seni bekleyenler var" — app tarafında
-- ilan-açma ekranında gösteriliyor; ayrıca Büyüme sayfası bunu operasyonel verir.)
--
-- 055'in tüm davranışını korur (role='host' promo + backfill), üstüne bildirim ekler.
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

  -- YENİ (056): ARZ-TALEP EŞLEŞTİRME. Bu ilan, aynı havalimanı+tarih+çakışan
  -- saatte seyahati olan guest'lerin talebini karşılıyor. Onlara "host geldi"
  -- bildirimi gönder (#8/#2/#1 büyüme motoru). Kendine ve staff'a gönderme.
  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  select distinct vs.user_id, 'requests'::notif_category,
         'Havalimanında host var! ✦',
         'Seni bekleyen bir host ' || p_airport || ' için ilan açtı. Hemen başvur.',
         v_id, 'availability'
    from visits vs
    join users gu on gu.id = vs.user_id
   where vs.airport_code = p_airport
     and vs.visit_date = p_date
     and vs.time_from < p_to and p_from < vs.time_to
     and vs.user_id <> v_uid
     and coalesce(gu.is_staff,false) = false
     and gu.deleted_at is null;

  return jsonb_build_object('ok', true, 'id', v_id, 'visibility', v_vis, 'min_trust', v_min_trust);
end $$;

-- 055'teki backfill'i tekrar çalıştırmaya gerek yok (idempotent değil ama zararsız);
-- yalnız fonksiyon güncellemesi yeterli. Yine de güvenli tarafta kalalım:
update users u set role = 'host'
where u.role <> 'host'
  and exists (select 1 from availabilities a where a.host_id = u.id and a.active = true);

select '056 OK — ilan açılınca eşleşen guest''lere host-geldi bildirimi gider' as sonuc;
