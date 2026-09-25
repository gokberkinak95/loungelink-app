-- ============================================================
-- LoungeLink · 016_match_score.sql — Eşleşme skoru + keşif filtreleri
-- discover_availabilities'i skorlu + filtreli sürümle değiştirir.
-- Skor bileşenleri (0-100):
--   +40 aynı uçuş no (en güçlü sinyal — "Same Flight")
--   +20 çağıranın o havalimanı+tarihte örtüşen seyahati var (gidebilir)
--   +25 host güven puanı (score/4, max 25)
--   +15 tarih yakınlığı (7 gün içi tam, uzadıkça azalır)
-- ============================================================

create or replace function public.discover_availabilities(
  p_airport   text default null,
  p_sector    text default null,   -- ileride sektör filtresi (profsession)
  p_flight    text default null    -- uçuş no filtresi
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, match_score int, same_flight boolean, has_trip boolean
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, ts.score as hs, p.profession as hp,
      -- çağıranın bu slotla örtüşen seyahati var mı + uçuş eşleşmesi
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
         b.flight_number, b.slots::int, b.filled::int, b.hn, b.hb, b.hs, b.hp,
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

select 'MATCH SCORE OK' as sonuc;
