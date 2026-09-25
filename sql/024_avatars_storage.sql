-- ============================================================
-- LoungeLink · 024_avatars_storage.sql — Profil fotoğrafı depolama
-- MVP paritesi: photo + photo_connections_only (bağlantı öncesi gizleme)
-- ============================================================

-- Public bucket (okuma açık; gizleme mantığı uygulama+RPC katmanında)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Herkes okuyabilir (URL bilinse de gizleme kararı sorgu katmanında verilir)
drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects for select
  using (bucket_id = 'avatars');

-- Kullanıcı yalnız kendi klasörüne yazar: <uid>/avatar.jpg
drop policy if exists "avatars_own_write" on storage.objects;
create policy "avatars_own_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_own_update" on storage.objects;
create policy "avatars_own_update" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_own_delete" on storage.objects;
create policy "avatars_own_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Keşif RPC'si: foto gizleme kuralını sunucuda uygula.
-- photo_connections_only=true ise, bağlantı yoksa photo_url NULL döner.
create or replace function public.discover_availabilities(
  p_airport text default null, p_sector text default null, p_flight text default null
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, host_photo text, match_score int, same_flight boolean, has_trip boolean
)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, ts.score as hs, p.profession as hp,
      case when p.photo_url is not null and (
             coalesce(p.photo_connections_only,false) = false
             or exists (select 1 from connection_requests cr where cr.status='accepted'
                        and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
           ) then p.photo_url else null end as photo,
      exists (select 1 from visits v where v.user_id=v_uid and v.airport_code=a.airport_code
              and v.visit_date=a.avail_date and v.time_from < a.time_to and v.time_to > a.time_from) as has_trip,
      exists (select 1 from visits v where v.user_id=v_uid and v.flight_number is not null
              and a.flight_number is not null and upper(v.flight_number)=upper(a.flight_number)) as same_flight
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    where a.active=true and a.visibility='Public'
      and coalesce(p.show_on_discovery,true)=true
      and (p_airport is null or a.airport_code=p_airport)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not (v_female and v_safe) or hu.gender='female')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications v where v.user_id=v_uid and v.phone_verified)))
  )
  -- 🔴 CAST'LER SART (18 Agu 2026, hata sinifi 24).
  -- `availabilities.airport_code` CHAR(3), `slots`/`filled` SMALLINT;
  -- ust tarafta `returns table (... airport_code text, slots int,
  -- filled int ...)` yaziyor. PostgreSQL `returns table` sozlesmesinde
  -- GENISLETME YAPMAZ (olculdu: integer<-smallint bile 42804 verir) ve
  -- bu hata SATIR YOKKEN CIKMAZ — bos veritabaninda migration temiz
  -- gorunur, veri varken ILK SATIRDA patlar. Gokberk canlida bunu
  -- 186'da iki kez yasadi; ayni kusur bu dosyada da duruyordu.
  select b.id, b.host_id, b.airport_code::text, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots::int, b.filled::int, b.hn, b.hb, b.hs, b.hp, b.photo,
         least(100,
           (case when b.same_flight then 40 else 0 end)
           + (case when b.has_trip then 20 else 0 end)
           + least(25, coalesce(b.hs,0)/4)
           + greatest(0, 15 - (abs(b.avail_date - current_date))::int)
         )::int as match_score,
         b.same_flight, b.has_trip
  from base b
  order by match_score desc, b.avail_date, b.time_from
  limit 100;
end $$;
grant execute on function public.discover_availabilities(text, text, text) to authenticated;

-- discover_people: aynı foto gizleme kuralı
create or replace function public.discover_people(p_airport text default null)
returns table (user_id uuid, name text, profession text, bio text, badge text, score int, rel text, photo text)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  return query
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false) = false
                or coalesce(cr.status::text,'') = 'accepted'
              ) then p.photo_url else null end as photo
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    left join connection_requests cr on
      (cr.from_id = v_uid and cr.to_id = p.user_id) or (cr.from_id = p.user_id and cr.to_id = v_uid)
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and (not (v_female and v_safe) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode,false)
          or (v_female and exists (select 1 from verifications v where v.user_id=v_uid and v.phone_verified)))
   order by ts.score desc nulls last
   limit 60;
end $$;
grant execute on function public.discover_people(text) to authenticated;

select 'AVATARS + PHOTO PRIVACY OK' as sonuc;
