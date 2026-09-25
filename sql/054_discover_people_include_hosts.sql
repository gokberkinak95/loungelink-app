-- ============================================================
-- LoungeLink · 054_discover_people_include_hosts.sql  (ÖNCE 054a çalıştır)
--
-- SORUN (Gokberk): Tanış>Keşfet'te host'un açtığı ilan görünmüyordu; ayrıca
-- host'lara "İstek" butonu (ilanına başvuru) hiç çıkmıyordu. MVP'de Keşfet
-- herkesi gösterir; kişinin AKTİF İLANI varsa yanında İstek butonu belirir.
--
-- KÖK: discover_people yalnız `visits` (seyahat) üzerinden kişi buluyordu —
-- trip'i olmayan ama ilanı olan host DIŞARIDA kalıyordu, ve is_hosting bilgisi
-- hiç dönmüyordu. Bu dosya gövdeyi 049'dan alıp 3 şey ekler:
--   (1) hosting CTE — aktif+açık-slotlu+eşiksiz ilanı olanlar
--   (2) trip VEYA ilan olan Keşfet'te görünür
--   (3) is_hosting / host_avail_id / host_slots_left / host_airport döner
-- Dönüş tablosu değiştiği için 054a'daki DROP şarttır (42P13 önlemi).
-- ============================================================

create or replace function public.discover_people(
  p_airport text default null, p_date date default null
)
returns table (
  user_id uuid, name text, profession text, bio text, badge text, score int,
  rel text, photo text, purpose text, same_purpose boolean, airport text,
  is_hosting boolean, host_avail_id uuid, host_slots_left int, host_airport text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_my_purpose text; v_my_airport text; v_my_date date;
  v_from time; v_to time;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  -- Kendi aktif seyahatim: amaç + havalimanı + zaman aralığı
  select v.purpose, v.airport_code::text, v.visit_date, v.time_from, v.time_to
    into v_my_purpose, v_my_airport, v_my_date, v_from, v_to
    from visits v
   where v.user_id = v_uid
     and (p_airport is null or v.airport_code = p_airport)
     and (p_date is null or v.visit_date = p_date)
     and v.visit_date >= current_date
   order by v.visit_date, v.time_from
   limit 1;

  -- Filtrelenecek havalimanı: parametre > kendi seyahatim
  v_my_airport := coalesce(p_airport, v_my_airport);
  v_my_date := coalesce(p_date, v_my_date);

  return query
  with theirs as (
    select distinct on (v.user_id)
           v.user_id, v.purpose, v.airport_code::text as ap, v.visit_date, v.time_from, v.time_to
      from visits v
     where v.visit_date >= current_date
       and (v_my_airport is null or v.airport_code = v_my_airport)
       and (v_my_date is null or v.visit_date = v_my_date)
       -- zaman örtüşmesi: ikimiz de oradayken
       and (v_from is null or (v.time_from < v_to and v_from < v.time_to))
     order by v.user_id, v.visit_date, v.time_from
  ),
  -- YENİ (054): aktif ilanı olan host'lar — trip'i olmasa da Keşfet'te çıkar,
  -- ve İstek butonu için ilan bilgisi döner. En yakın açık slotlu ilan seçilir.
  hosting as (
    select distinct on (a.host_id)
           a.host_id, a.id as avail_id, a.airport_code::text as ap,
           greatest(0, a.slots - coalesce(a.filled,0)) as slots_left
      from availabilities a
     where a.active = true
       and a.avail_date >= current_date
       and a.visibility <> 'Hidden'
       and coalesce(a.min_trust,0) = 0                       -- beta: eşiksiz görünür
       and greatest(0, a.slots - coalesce(a.filled,0)) > 0   -- yalnız açık slotlu
       and (v_my_airport is null or a.airport_code = v_my_airport)
       and (v_my_date is null or a.avail_date = v_my_date)
     order by a.host_id, a.avail_date, a.time_from
  )
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false) = false
                or coalesce(cr.status::text,'') = 'accepted'
              ) then p.photo_url else null end as photo,
         th.purpose,
         (v_my_purpose is not null and th.purpose is not null
          and th.purpose = v_my_purpose) as same_purpose,
         coalesce(th.ap, ho.ap) as airport,
         (ho.host_id is not null) as is_hosting,
         ho.avail_id as host_avail_id,
         ho.slots_left as host_slots_left,
         ho.ap as host_airport
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    left join connection_requests cr on
      (cr.from_id = v_uid and cr.to_id = p.user_id) or (cr.from_id = p.user_id and cr.to_id = v_uid)
    -- YENİ (044): havalimanı filtresi GERÇEKTEN uygulanıyor.
    -- v_my_airport null ise (seyahatim yok, filtre de yok) herkesi göster —
    -- 024'teki eski davranış korunur, yoksa liste bomboş kalırdı.
    left join theirs th on th.user_id = p.user_id
    left join hosting ho on ho.host_id = p.user_id
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and public.is_visible(p.user_id)                  -- YENİ (044): staff + gölge kısıt
     and (v_my_airport is null or th.user_id is not null or ho.host_id is not null)
     and (not (v_female and v_safe) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode,false)
          or (v_female and exists (select 1 from verifications v where v.user_id=v_uid and v.phone_verified)))
          -- 049/#20: kadinin baslattigi etkilesim istisnasi (yukaridakiyle ayni kural)
          or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid)
          or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.availability_id
                     where r9.guest_id = p.user_id and a9.host_id = v_uid)
          or exists (select 1 from invites i9 where i9.host_id = p.user_id and i9.guest_id = v_uid)
   order by (v_my_purpose is not null and th.purpose = v_my_purpose) desc nulls last,
            ts.score desc nulls last
   limit 60;
end $$;

select '054 OK — discover_people artik ilani olan hostlari da donduruyor (is_hosting)' as sonuc;
