-- ============================================================
-- LoungeLink · 059_discover_everyone_request_gate.sql   (ÖNCE 059a çalıştır)
--
-- KARAR (Gokberk, App 4): Keşfet'te HERKES birbirini görebilmeli — havalimanı/
-- tarih kısıtı listeyi boşaltıyordu (az yoğunlukta kimse kimseyi görmüyordu).
-- Artık:
--   • Keşfet varsayılan olarak TÜM app kullanıcılarını gösterir (filtre opsiyonel).
--   • Kadın-güvenlik modu yapısı AYNEN korunur (bozulmadı).
--   • Host'un aktif ilanı varsa yanında "İstek" butonu için bilgi döner.
--   • İSTEK butonu şu üç şart sağlanınca AKTİF olur (can_request=true):
--       (1) o kişinin aktif+açık-slotlu ilanı var,
--       (2) ben telefonumu doğrulamışım,
--       (3) onunla AYNI havalimanı + AYNI tarih + saat penceresi ±1 saat
--           örtüşüyor (ilan saatine göre from-1s .. to+1s).
--     Aksi halde buton pasif + neden (req_reason) döner:
--       'phone'   → telefon doğrulaması gerekli
--       'trip'    → aynı yer/saatte seyahatin yok
--       'noslot'  → uygun ilan yok / slot dolu
--
-- Dönüş tablosu 054'e göre 2 kolon büyür (can_request, req_reason) → 059a DROP şart.
-- ============================================================

create or replace function public.discover_people(
  p_airport text default null, p_date date default null
)
returns table (
  user_id uuid, name text, profession text, bio text, badge text, score int,
  rel text, photo text, purpose text, same_purpose boolean, airport text,
  is_hosting boolean, host_avail_id uuid, host_slots_left int, host_airport text,
  can_request boolean, req_reason text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_phone_ok boolean;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select coalesce(bool_or(v.phone_verified), false) into v_phone_ok
    from verifications v where v.user_id = v_uid;

  return query
  with
  -- Karşı tarafın en yakın aktif+açık-slotlu ilanı (İstek butonu bilgisi)
  hosting as (
    select distinct on (a.host_id)
           a.host_id, a.id as avail_id, a.airport_code::text as ap,
           a.avail_date, a.time_from, a.time_to,
           greatest(0, a.slots - coalesce(a.filled,0)) as slots_left
      from availabilities a
     where a.active = true
       and a.avail_date >= current_date
       and a.visibility <> 'Hidden'
       and coalesce(a.min_trust,0) = 0
       and greatest(0, a.slots - coalesce(a.filled,0)) > 0
       and (p_airport is null or a.airport_code = p_airport)
       and (p_date is null or a.avail_date = p_date)
     order by a.host_id, a.avail_date, a.time_from
  ),
  -- Benim seyahatlerim — İstek kapısı için (aynı yer/tarih/±1s örtüşme)
  mine as (
    select v.airport_code::text as ap, v.visit_date, v.time_from, v.time_to
      from visits v
     where v.user_id = v_uid and v.visit_date >= current_date
  )
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false) = false
                or coalesce(cr.status::text,'') = 'accepted'
              ) then p.photo_url else null end as photo,
         null::text as purpose,
         false as same_purpose,
         ho.ap as airport,
         (ho.host_id is not null) as is_hosting,
         ho.avail_id as host_avail_id,
         ho.slots_left as host_slots_left,
         ho.ap as host_airport,
         -- can_request: üç şart birden
         (ho.host_id is not null
          and v_phone_ok
          and exists (
            select 1 from mine m
             where m.ap = ho.ap
               and m.visit_date = ho.avail_date
               -- saat penceresi ±1 saat (ilan from-1s .. to+1s ile örtüşme)
               and m.time_from < (ho.time_to + interval '1 hour')
               and (ho.time_from - interval '1 hour') < m.time_to
          )) as can_request,
         -- req_reason: neden pasif (öncelik: ilan yok > telefon > seyahat)
         case
           when ho.host_id is null then 'noslot'
           when not v_phone_ok then 'phone'
           when not exists (
             select 1 from mine m
              where m.ap = ho.ap and m.visit_date = ho.avail_date
                and m.time_from < (ho.time_to + interval '1 hour')
                and (ho.time_from - interval '1 hour') < m.time_to
           ) then 'trip'
           else null
         end as req_reason
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    left join connection_requests cr on
      (cr.from_id = v_uid and cr.to_id = p.user_id) or (cr.from_id = p.user_id and cr.to_id = v_uid)
    left join hosting ho on ho.host_id = p.user_id
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and public.is_visible(p.user_id)
     -- KADIN GÜVENLİK — 049 kuralı AYNEN korunur:
     and (not (v_female and v_safe) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode,false)
          or (v_female and v_phone_ok)
          or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid)
          or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                     where r9.guest_id = p.user_id and a9.host_id = v_uid)
          or exists (select 1 from invites i9 where i9.host_id = p.user_id and i9.guest_id = v_uid))
   order by (ho.host_id is not null) desc,          -- ilanı olanlar üstte
            ts.score desc nulls last
   limit 100;
end $$;

select '059 OK — Kesfet herkesi gosteriyor, Istek butonu telefon+ayni yer/tarih/+-1s ile aktif' as sonuc;
