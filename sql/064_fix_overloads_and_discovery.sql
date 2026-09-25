-- ============================================================
-- LoungeLink · 064_fix_overloads_and_discovery.sql
--
-- 🔴🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu (statik analiz goremezdi).
-- Claude yerel bir PostgreSQL kurup 78 migration'i uyguladi ve uctan uca
-- akisi CALISTIRDI. Uc ayri kirik ortaya cikti:
--
-- 1) discover_people() "is not unique"
--    Iki surum birikmis: (p_airport text) ve (p_airport text, p_date date).
--    Ikisinin de tum parametreleri varsayilanli, parametresiz cagri BELIRSIZ.
--    Uygulama Tanis ekraninda tam olarak boyle cagiriyor.
--    SONUC: TANIS EKRANI HIC VERI YUKLEYEMIYOR. "Kimse yok" gorunmesinin
--    sebebi filtre degil, HATA.
--
-- 2) discover_availabilities ayni sekilde iki surum (3 ve 4 parametreli).
--    create_request bunu 3 argumanla cagiriyor, BELIRSIZ.
--    SONUC: MISAFIR HIC ISTEK GONDEREMIYOR.
--
-- 3) discover_availabilities govdesinde r9.availability_id yaziyor ama
--    requests tablosundaki kolon avail_id.
--    SONUC: HOST BUL EKRANI "column does not exist" hatasi veriyor.
--
-- Bu uc kirik + daha once bulunan respond_request(enum) ve slot sayaci ile
-- birlikte cekirdek dongunun HER adimi kirikti.
-- ============================================================

-- ---------- 1) Eskimis asiri yuklemeleri dusur ----------
drop function if exists public.discover_availabilities(text, text, text);
drop function if exists public.discover_people(text);

-- ---------- 2) discover_availabilities: avail_id + TIP duzeltmeleri ----------
-- 4) EK BULGU (yine calistirarak): donus tipi uyusmazligi.
--    availabilities.airport_code = char(3) ama RETURNS TABLE text diyor;
--    slots/filled = smallint ama integer deniyor. PostgreSQL bunu
--    "structure of query does not match function result type" ile reddediyor.
--    SONUC: duzeltilmezse Host Bul ekrani yine calismazdi. ::text / ::int eklendi.
CREATE OR REPLACE FUNCTION public.discover_availabilities(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text)
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
         coalesce(b.visibility,'Public')::text as visibility
  from base b
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $function$;

grant execute on function public.discover_availabilities(text, text, text, date) to authenticated;
grant execute on function public.discover_people(text, date) to authenticated;

-- ---------- 3) DOGRULAMA: asiri yukleme kalmadi mi? (her satir 1 donmeli) ----------
select p.proname, count(*) as surum
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('discover_people','discover_availabilities')
group by p.proname;

select '064 OK - asiri yuklemeler temizlendi, discover_availabilities avail_id duzeltildi' as sonuc;
