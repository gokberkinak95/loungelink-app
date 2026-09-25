-- ============================================================
-- LoungeLink · 112_blocks_in_discovery.sql
-- 🔴 GUVENLIK ACIGI: ENGELLENEN KULLANICI ILANI GORMEYE DEVAM EDIYOR
--
-- ⚠️ Uygulamayi ETKILER (kesif sonuclari daralir).
--
-- ------------------------------------------------------------
-- NASIL BULUNDU
-- ------------------------------------------------------------
-- Mutlu yol disindaki akislari test etmek icin yazdigim
-- edge_flows_e2e.py ilk kosusunda yakaladi:
--   host, bir kullaniciyi ENGELLEDI
--   engellenen kullanici host'un ilanini HALA GORUYOR (1 sonuc)
--
-- `blocks` tablosu 034'ten beri var, engelleme kaydi olusuyor —
-- ama `discover_availabilities` bu tabloya HIC BAKMIYOR. Yani
-- engelleme dugmesi bir HIS veriyor, bir SONUC vermiyordu.
--
-- Bu, guvenlik ozelliklerinin en tehlikeli bozulma bicimi:
-- kullanici korunduguna INANIYOR ama korunmuyor. Hic engelleme
-- ozelligi olmamasi, calismayan bir engelleme ozelliginden
-- DAHA DURUSTTUR — cunku o zaman kullanici baska onlem alir.
--
-- IKI YONLU OLMALI:
--   · A, B'yi engellediyse B, A'nin ilanini gormemeli
--   · A, B'yi engellediyse A da B'nin ilanini gormemeli
-- Tek yonlu yaparsak engelleyen kisi karsi tarafi gormeye devam
-- eder; bu da rahatsizligin surmesi demektir.
-- ============================================================

create or replace function public.is_blocked_pair(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks b
     where (b.blocker = p_a and b.blocked = p_b)
        or (b.blocker = p_b and b.blocked = p_a));
$$;
grant execute on function public.is_blocked_pair(uuid, uuid) to authenticated;


-- ============================================================
-- KESIF: ENGELLENEN CIFT BIRBIRINI GORMEZ
-- ============================================================
drop function if exists public.discover_availabilities(text, text, text, date);
CREATE OR REPLACE FUNCTION public.discover_availabilities(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text, host_gender text, host_langs text[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_langs text[]; v_prof text; v_sessions int; v_rated int; v_my_trust int;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false), pr.languages, pr.profession
    into v_female, v_safe, v_langs, v_prof
    from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status='completed' and (r.guest_id=v_uid or r.host_id=v_uid);
  select count(*) into v_rated from ratings where rater_id = v_uid;
  select coalesce(score,0) into v_my_trust from trust_scores where user_id = v_uid;
  v_my_trust := coalesce(v_my_trust, 0);

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, coalesce(ts.score,0) as hs, p.profession as hp,
      p.languages as hlangs, hu.gender as hgender,
      case when p.photo_url is not null and (
             coalesce(p.photo_connections_only,false) = false
             or exists (select 1 from connection_requests cr where cr.status='accepted'
                        and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
           ) then p.photo_url else null end as photo,
      coalesce(v.id_verified,false) as hid,
      (p.linkedin_url is not null and p.linkedin_url <> '') as hlinked,   -- 040 düzeltmesi
      (select count(*) from sessions s2 join requests r2 on r2.id=s2.request_id
        where s2.status='completed' and r2.host_id=a.host_id) as hsessions,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.airport_code=a.airport_code
              and vs.visit_date=a.avail_date and vs.time_from < a.time_to and a.time_from < vs.time_to) as has_trip,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.flight_number is not null
              and a.flight_number is not null and upper(vs.flight_number)=upper(a.flight_number)) as same_flight,
      (a.featured_until is not null and a.featured_until > now()) as featured
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    left join verifications v on v.user_id=a.host_id
    where a.active=true
      and (hu.role = 'host'
           or exists (select 1 from host_applications ha           -- 049/#2: onayli
                      where ha.user_id = a.host_id and ha.status = 'approved'))
      and coalesce(hu.is_staff,false) = false                -- YENİ (041)
      and a.avail_date >= current_date
      and coalesce(p.show_on_discovery,true)=true
      and public.is_visible(a.host_id)
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))
           -- 049/#20: kadin KENDISI etkilesim baslattiysa o erkek onu gorebilir:
           -- (a) izleyiciye baglanti istegi gonderdiyse, (b) izleyicinin ilanina
           -- basvurduysa, (c) izleyiciyi slotuna davet ettiyse
           or exists (select 1 from connection_requests c9 where c9.from_id = a.host_id and c9.to_id = v_uid)
           or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                      where r9.guest_id = a.host_id and a9.host_id = v_uid)
           or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = v_uid)
      -- 040: görünürlük — host ne seçtiyse o geçerli
      and (
        a.host_id = v_uid
        or (
          coalesce(a.visibility,'Public') <> 'Hidden'
          and (
            coalesce(a.visibility,'Public') <> 'Connections'
            or exists (select 1 from connection_requests cr where cr.status='accepted'
                       and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
          )
          and v_my_trust >= coalesce(a.min_trust,0)
        )
      )
  )
  select b.id, b.host_id, b.airport_code::text, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots::int, b.filled::int, b.hn, b.hb, b.hs, b.hp, b.photo,
         least(99,
           40
           + (case when b.hs >= 70 then 18 when b.hs >= 55 then 10 else 0 end)
           + (case when b.hid then 14 else 0 end)
           + (case when b.same_flight then 14 else 0 end)
           + (case when v_prof is not null and b.hp is not null
                    and (b.hp ilike '%'||v_prof||'%' or v_prof ilike '%'||b.hp||'%') then 12 else 0 end)
           + (case when v_female and b.hgender = 'female' then 10 else 0 end)
           + (case when b.hsessions >= 3 then 8 else 0 end)
           + (case when b.hlinked then 6 else 0 end)
           + (case when v_langs is not null and b.hlangs is not null and (v_langs && b.hlangs) then 5 else 0 end)
           + (case when v_rated > 0 then 4 else 0 end)
           + (case when b.has_trip then 10 else 0 end)
         )::int as match_score,
         b.same_flight, b.has_trip, b.featured, (b.filled >= b.slots) as fully_booked,
         coalesce(b.visibility,'Public')::text as visibility,
         b.hgender::text as host_gender,
         b.hlangs as host_langs
  from base b
  -- 🔴 112: ENGELLEME FILTRESI. Bu satir YOKTU. `blocks` tablosu 034'ten
  -- beri var ve engelleme kaydi olusuyordu, ama kesif ona HIC bakmiyordu:
  -- engellenen kullanici host'un ilanini gormeye ve BASVURMAYA devam
  -- ediyordu. Guvenlik ozelliginin en tehlikeli bozulma bicimi budur —
  -- kullanici korunduguna INANIR ama korunmaz.
  -- Iki yonlu: kim kimi engellemis olursa olsun, o cift birbirini gormez.
  where not public.is_blocked_pair(b.host_id, auth.uid())
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $function$;
grant execute on function public.discover_availabilities(text, text, text, date) to authenticated;

select '112 OK - engelleme artik kesifte de gecerli' as sonuc;
