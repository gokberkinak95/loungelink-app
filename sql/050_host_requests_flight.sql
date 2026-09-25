-- ============================================================
-- LoungeLink · 050_host_requests_flight.sql   (ÖNCE 050a çalıştır)
-- #26: Gelen İstekler kartı misafirin UÇUŞ bilgisini göstermeli
-- (yoksa app "Uçuş belirtilmedi" yazar). host_requests'in dönüş
-- tablosuna flight_number eklendi — gövde 046'dan programatik alındı,
-- yalnız bu kolon eklendi. Dönüş tablosu değiştiği için 050a'daki
-- drop ŞART (create or replace dönüş tipini değiştiremez, 42P13).
-- ============================================================

create or replace function public.host_requests()
returns table (
  id uuid, guest_id uuid, avail_id uuid, status text, intro_message text,
  created_at timestamptz,
  guest_name text, guest_photo text, guest_profession text,
  guest_score int, guest_badge text, guest_id_verified boolean,
  guest_phone_verified boolean, guest_linkedin boolean,
  guest_sessions int, guest_rating numeric, guest_rating_count int,
  same_flight boolean, same_purpose boolean, guest_fit int,
  lounge_name text, avail_date date, time_from time, time_to time, flight_number text
)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with base as (
    select r.id, r.guest_id, r.avail_id, r.status::text as st, r.intro_message, r.created_at,
           a.lounge_name, a.avail_date, a.time_from, a.time_to,
           a.flight_number as host_flight, a.airport_code,
           p.name as gname, p.profession as gprof, p.bio as gbio,
           p.photo_url, coalesce(p.photo_connections_only,false) as photo_priv,
           p.linkedin_url, p.linkedin_verified,
           coalesce(ts.score,0) as gscore, ts.badge as gbadge,
           coalesce(v.id_verified,false) as gid,
           coalesce(v.phone_verified,false) as gphone,
           (select count(*)::int from sessions s2 join requests r2 on r2.id = s2.request_id
             where s2.status='completed' and (r2.guest_id = r.guest_id or r2.host_id = r.guest_id)) as gsessions,
           (select avg(score)::numeric from ratings where rated_id = r.guest_id) as grating,
           (select count(*)::int from ratings where rated_id = r.guest_id) as grating_n,
           -- misafirin ayni havalimani/zamandaki seyahati
           (select vs.flight_number from visits vs
             where vs.user_id = r.guest_id and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date
               and vs.time_from < a.time_to and a.time_from < vs.time_to
             limit 1) as gflight,
           (select vs.purpose from visits vs
             where vs.user_id = r.guest_id and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date
               and vs.time_from < a.time_to and a.time_from < vs.time_to
             limit 1) as gpurpose,
           -- host'un kendi seyahat amaci (ayni amac karsilastirmasi icin)
           (select vs.purpose from visits vs
             where vs.user_id = v_uid and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date limit 1) as hpurpose,
           (select p2.profession from profiles p2 where p2.user_id = v_uid) as hprof
      from requests r
      join availabilities a on a.id = r.avail_id
      join profiles p on p.user_id = r.guest_id
      left join trust_scores ts on ts.user_id = r.guest_id
      left join verifications v on v.user_id = r.guest_id
     where r.host_id = v_uid
       and r.status in ('pending','accepted')
  )
  select b.id, b.guest_id, b.avail_id, b.st, b.intro_message, b.created_at,
         b.gname,
         case when b.photo_url is not null and (
                b.photo_priv = false
                or exists (select 1 from connection_requests cr where cr.status='accepted'
                           and ((cr.from_id=v_uid and cr.to_id=b.guest_id)
                             or (cr.from_id=b.guest_id and cr.to_id=v_uid)))
              ) then b.photo_url else null end,
         b.gprof, b.gscore, b.gbadge, b.gid, b.gphone,
         (b.linkedin_url is not null and b.linkedin_url <> ''),
         b.gsessions, b.grating, b.grating_n,
         (b.gflight is not null and b.host_flight is not null
          and upper(b.gflight) = upper(b.host_flight)) as same_flight,
         (b.gpurpose is not null and b.hpurpose is not null
          and b.gpurpose = b.hpurpose) as same_purpose,
         -- guest_fit: MISAFIRIN BU ILANA uyumu (30-99)
         least(99, greatest(30,
           30
           + (case when b.gscore >= 70 then 18 when b.gscore >= 50 then 10 else 0 end)
           + (case when b.gid then 14 else 0 end)
           + (case when b.gphone then 6 else 0 end)
           + (case when b.gflight is not null and b.host_flight is not null
                    and upper(b.gflight) = upper(b.host_flight) then 12 else 0 end)
           + (case when b.gpurpose is not null and b.hpurpose is not null
                    and b.gpurpose = b.hpurpose then 8 else 0 end)
           + (case when b.hprof is not null and b.gprof is not null
                    and (b.gprof ilike '%'||b.hprof||'%' or b.hprof ilike '%'||b.gprof||'%') then 8 else 0 end)
           + (case when b.gsessions >= 3 then 8 when b.gsessions >= 1 then 4 else 0 end)
           + (case when coalesce(b.grating_n,0) >= 3 and b.grating >= 4.5 then 8
                   when coalesce(b.grating_n,0) >= 3 and b.grating >= 4.0 then 4 else 0 end)
           + (case when length(coalesce(b.gbio,'')) >= 40 then 4 else 0 end)
         ))::int as guest_fit,
         b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.gflight as flight_number                                     -- 050/#26: misafirin uçuşu
  from base b
  order by coalesce(b.st = 'pending', false) desc, guest_fit desc, b.created_at desc;
end $$;

select '050 OK — host_requests + flight_number' as sonuc;
