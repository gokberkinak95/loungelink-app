-- ============================================================
-- LoungeLink · 074_host_always_visible.sql
--
-- ÜRÜN KARARI (Gokberk, 23 Tem): "İlan açan TÜM host'ların ilanı
-- görünmeli." 041'in getirdiği ekip-hesabı gizlemesi (is_staff=true
-- keşiften elenir + profili show_on_discovery=false açılır) BO'dan
-- açılan test host'larını ve admin hesaplarını da yakalıyordu; ilan
-- açsalar bile keşifte hiç görünmüyorlardı.
--
-- YENİ KURAL: İLAN AÇMAK = APP HOST'U OLMAK (tam anlamıyla).
-- 055 zaten rolü 'host' yapıyordu ama 041 bayraklarını unutmuştu.
-- Artık create_availability ilan açıldığı anda:
--   • users.is_staff -> false  (ekip gizlemesi kalkar)
--   • profiles.show_on_discovery -> true  (YALNIZCA sistemin ekip
--     hesabına bastığı gizlemeyse; kullanıcının Ayarlar'dan KENDİ
--     kapattığı keşif tercihi staff değilse KORUNUR)
-- İlan açmayan gerçek ekip üyeleri (destek, partner) gizli kalmaya
-- devam eder — 041'in amacı bozulmaz.
--
-- BU DOSYA KENDİ KENDİNE YETER: create_availability'nin 071'deki
-- ÇALIŞAN tam sürümünü (enum cast dahil her etkisiyle) yeniden
-- tanımlar + mevcut görünmez ilanlar için geriye dönük onarım yapar.
-- Dönüş tipi değişmiyor -> PRE_drop gerekmez.
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

  -- 040: MVP'nin all/trusted/hidden -> enum + eşik
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

  -- 055: ilan açmak = host olmak (rol)
  update users set role = 'host' where id = v_uid and role <> 'host';

  -- YENİ (074): ilan açmak = APP HOST'U olmak (görünürlük).
  -- Sıra önemli: is_staff hâlâ true iken profil düzeltilir (işaret olarak
  -- kullanılıyor), SONRA bayrak temizlenir. Kullanıcının kendi kapattığı
  -- show_on_discovery'ye (staff değilse) dokunulmaz.
  update profiles p set show_on_discovery = true
   where p.user_id = v_uid
     and p.show_on_discovery = false
     and exists (select 1 from users u where u.id = v_uid and u.is_staff = true);
  update users set is_staff = false where id = v_uid and is_staff = true;

  -- 056: ARZ-TALEP EŞLEŞTİRME — eşleşen misafirlere "host geldi" bildirimi
  -- (SELECT içindeki literal enum'a OTOMATİK çevrilmez -> 071 cast'i korunur)
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


-- ---- GERİYE DÖNÜK ONARIM: zaten ilan açmış ekip hesapları ----
-- Aktif+gelecek tarihli ilanı olan her is_staff hesabı app host'una
-- çevrilir; ilanları anında keşfe düşer. (Sıra: önce profil, sonra bayrak.)
update profiles p set show_on_discovery = true
  from users u
 where u.id = p.user_id
   and u.is_staff = true
   and p.show_on_discovery = false
   and exists (select 1 from availabilities a
                where a.host_id = u.id and a.active = true
                  and a.avail_date >= current_date);

update users u set is_staff = false
 where u.is_staff = true
   and exists (select 1 from availabilities a
                where a.host_id = u.id and a.active = true
                  and a.avail_date >= current_date);


-- ---- DOĞRULAMA ----
-- (1) true dönmeli: yeni kural fonksiyonda
select (prosrc ilike '%is_staff = false where id = v_uid%') as "kural_074_var",
       (prosrc ilike '%::notif_category%')                  as "cast_071_korundu"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='create_availability';

-- (2) 0 dönmeli: aktif ilanı olup hâlâ gizli host kalmamalı
select count(*) as "gorunmez_ilanli_host_kaldi"
  from availabilities a
  join users u on u.id = a.host_id
  left join profiles p on p.user_id = a.host_id
 where a.active = true and a.avail_date >= current_date
   and (u.is_staff = true or p.show_on_discovery = false);

select '074 OK - ilan acan herkes kesifte gorunur; mevcut gizli ilanlar onarildi' as sonuc;
