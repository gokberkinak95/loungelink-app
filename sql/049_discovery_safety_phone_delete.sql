-- ============================================================
-- LoungeLink · 049_discovery_safety_phone_delete.sql  (ÖNCE 049a)
--
-- Excel maddeleri:
-- #2  İlan görünmüyor: hu.role='host' katıydı — rolü guest kalmış ama
--     host başvurusu ONAYLI kullanıcının ilanı kimseye listelenmiyordu.
-- #20 Kadın güvenlik modu: kural netleşti — mod açık kadını erkekler
--     GÖREMEZ; ama kadın o erkeğe kendi iradesiyle dokunduysa (bağlantı
--     isteği / ilanına başvuru / davet) O ERKEK onu görebilir. İki
--     discover fonksiyonuna da aynı istisna eklendi; gövdeler 041/044'ten
--     programatik alınıp yalnız bu satırlar eklendi.
-- #5  phone_in_use: kayıt öncesi telefon çakışma kontrolü (anon erişir,
--     yalnız VAR/YOK döner — numara sızdırmaz).
-- #22 delete_my_account: hesap silme talebi — deleted_at yazar, denetim
--     kaydına app.account_delete düşer (BO'da takip edilir).
-- ============================================================

create or replace function public.discover_availabilities(
  p_airport text default null, p_sector text default null, p_flight text default null,
  p_date date default null
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, host_photo text, match_score int,
  same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean,
  visibility text
)
language plpgsql security definer set search_path = public as $$
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
           or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.availability_id
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
  select b.id, b.host_id, b.airport_code, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots, b.filled, b.hn, b.hb, b.hs, b.hp, b.photo,
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
end $$;

create or replace function public.discover_people(
  p_airport text default null, p_date date default null
)
returns table (
  user_id uuid, name text, profession text, bio text, badge text, score int,
  rel text, photo text, purpose text, same_purpose boolean, airport text
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
         th.ap as airport
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    left join connection_requests cr on
      (cr.from_id = v_uid and cr.to_id = p.user_id) or (cr.from_id = p.user_id and cr.to_id = v_uid)
    -- YENİ (044): havalimanı filtresi GERÇEKTEN uygulanıyor.
    -- v_my_airport null ise (seyahatim yok, filtre de yok) herkesi göster —
    -- 024'teki eski davranış korunur, yoksa liste bomboş kalırdı.
    left join theirs th on th.user_id = p.user_id
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and public.is_visible(p.user_id)                  -- YENİ (044): staff + gölge kısıt
     and (v_my_airport is null or th.user_id is not null)
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

-- ---------- #5: telefon kullanımda mı (kayıt validasyonu) ----------
-- 🔴 DÜZELTME (Gokberk'in çalıştırmasında 42703): telefon profiles'ta DEĞİL,
-- users.phone / users.phone_e164'te duruyor (001 satır 23-24). Okumadan-yazma
-- sınıfı ihlali — kolon doğrulanmadan yazılmıştı.
create or replace function public.phone_in_use(p_phone text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from users u
    where u.deleted_at is null
      and length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) >= 10
      and (
        regexp_replace(coalesce(u.phone,''), '\D', '', 'g')
          = regexp_replace(coalesce(p_phone,''), '\D', '', 'g')
        or regexp_replace(coalesce(u.phone_e164,''), '\D', '', 'g')
          = regexp_replace(coalesce(p_phone,''), '\D', '', 'g')
      )
  );
$$;
grant execute on function public.phone_in_use(text) to anon, authenticated;

-- ---------- #22: hesap silme talebi ----------
create or replace function public.delete_my_account()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update users set deleted_at = now() where id = v_uid and deleted_at is null;
  update availabilities set active = false where host_id = v_uid;
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.account_delete', 'users', v_uid, jsonb_build_object('requested_by','user'));
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.delete_my_account() to authenticated;

-- ---------- #23: kampanyada "Katıl butonu" yönetimi ----------
alter table promo_campaigns add column if not exists joinable boolean default true;

create or replace function public.active_campaigns()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'title', c.title, 'description', c.description,
    'ends_at', c.ends_at, 'joinable', coalesce(c.joinable, true),
    'joined', exists (select 1 from campaign_participations cp
                      where cp.campaign_id = c.id and cp.user_id = auth.uid())
  ) order by c.created_at desc), '[]'::jsonb)
  from promo_campaigns c
  where c.active and (c.ends_at is null or c.ends_at >= current_date);
$$;
grant execute on function public.active_campaigns() to authenticated;

create or replace function public.join_campaign(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_title text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select title into v_title from promo_campaigns
   where id = p_id and active and coalesce(joinable, true)          -- 049/#23
     and (ends_at is null or ends_at >= current_date);
  if v_title is null then raise exception 'campaign_not_found_or_ended'; end if;
  insert into campaign_participations (campaign_id, user_id) values (p_id, v_uid)
    on conflict (campaign_id, user_id) do nothing;
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.campaign_join', 'promo_campaigns', p_id,
          jsonb_build_object('user_id', v_uid, 'campaign', v_title));
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.join_campaign(uuid) to authenticated;

select '049 OK — #2 rol, #20 kadın güvenlik istisnası, #5 telefon, #22 silme, #23 katıl bayrağı' as sonuc;
