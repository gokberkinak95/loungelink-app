-- ============================================================
-- LoungeLink · 071_fix_create_availability_enum.sql
--
-- 🔴 ILAN ACILAMIYOR — kesin teshis (Gokberk Expo Go ile ham hatayi yakaladi):
--     column "category" is of type notif_category but expression is of type text
--
-- SEBEP: create_availability, ilan acilinca eslesen misafirlere bildirim
-- yaziyor. O INSERT bir SELECT'ten besleniyor ve SELECT icindeki 'requests'
-- literali TEXT olarak turetiliyor; PostgreSQL bunu enum'a OTOMATIK CEVIRMIYOR.
-- (VALUES icinde otomatik cevirir, SELECT icinde CEVIRMEZ — fark burada.)
--
-- NEDEN SIMDI CIKTI: hata yalnizca ESLESEN MISAFIR VARSA tetikleniyor.
-- INSERT...SELECT hic satir dondurmezse hata olusmuyor. Yani bos uygulamada
-- calisiyordu; seyahat/kullanici verisi gelince kirildi.
--
-- BU DOSYA KENDI KENDINE YETER: create_availability'nin CALISAN, cast'li
-- tam surumunu yeniden tanimlar. Eski dosyalari aramana gerek yok.
-- (Ayni duzeltme 056'da da var; bu dosya onun garanti tekrari.)
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$;

grant execute on function public.create_availability(uuid, text, date, time, time, integer, text, text) to authenticated;

-- DOGRULAMA (true donmeli)
select (prosrc ilike '%::notif_category%') as "cast_eklendi"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='create_availability';

select '071 OK - create_availability enum cast ile yeniden tanimlandi, ilan acilabilir' as sonuc;
