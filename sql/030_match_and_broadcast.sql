-- ============================================================
-- LoungeLink · 030_match_and_broadcast.sql
-- 1) 11-FAKTÖRLÜ MATCH SCORE (§13 doküman birebir)
-- 2) HostBroadcast: Featured Placement (200 puan/24s) + Direct Invite
-- 3) Trip rozeti + tarih filtresi + expired gizleme (v14/v15)
-- ============================================================

-- ---------- 1) FEATURED PLACEMENT ----------
alter table availabilities add column if not exists featured_until timestamptz;

create or replace function public.set_featured(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_pts int; v_host uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select host_id into v_host from availabilities where id = p_avail_id;
  if v_host is null then raise exception 'availability_not_found'; end if;
  if v_host <> v_uid then raise exception 'not_owner'; end if;

  select coalesce(sum(delta),0) into v_pts from points_ledger where user_id = v_uid;
  if v_pts < 200 then raise exception 'insufficient_points'; end if;

  update availabilities set featured_until = now() + interval '24 hours' where id = p_avail_id;
  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -200, 'featured_placement', p_avail_id);

  return jsonb_build_object('ok', true, 'until', now() + interval '24 hours');
end $$;
grant execute on function public.set_featured(uuid) to authenticated;

-- ---------- 2) DIRECT INVITE (yalnız geçmiş misafir — soğuk davet yasak) ----------
alter table invites add column if not exists avail_id uuid references availabilities(id) on delete cascade;
alter table invites add column if not exists note text;
alter table invites add column if not exists responded_at timestamptz;

-- Davet edilebilir misafirler: tamamlanmış oturum + kabul edilmiş request geçmişi
create or replace function public.invitable_guests(p_avail_id uuid)
returns table (guest_id uuid, name text, photo text, last_seen date, invite_status text)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return query
  select distinct r.guest_id, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false
              then p.photo_url else null end,
         max(a.avail_date) over (partition by r.guest_id),
         coalesce((select i.status::text from invites i
                    where i.guest_id = r.guest_id and i.avail_id = p_avail_id limit 1), 'none')
    from requests r
    join availabilities a on a.id = r.avail_id
    join profiles p on p.user_id = r.guest_id
   where a.host_id = v_uid and r.status in ('accepted','completed');
end $$;
grant execute on function public.invitable_guests(uuid) to authenticated;

create or replace function public.send_invite(p_guest uuid, p_avail_id uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_ok boolean; v_id uuid; v_av availabilities%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id;
  if v_av.host_id <> v_uid then raise exception 'not_owner'; end if;
  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;

  -- soğuk davet yasak: geçmiş misafir olmalı
  if not exists (
    select 1 from requests r join availabilities a on a.id = r.avail_id
     where a.host_id = v_uid and r.guest_id = p_guest and r.status in ('accepted','completed')
  ) then raise exception 'cold_invite_blocked'; end if;

  insert into invites (host_id, guest_id, avail_id, note, status)
  values (v_uid, p_guest, p_avail_id, left(coalesce(p_note,''),140), 'pending')
  returning id into v_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_guest, 'requests', 'Lounge daveti ✦',
          coalesce(v_av.lounge_name, v_av.airport_code) || ' · ' || left(coalesce(p_note,''),80), 'invite', v_id);

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
grant execute on function public.send_invite(uuid, uuid, text) to authenticated;

-- Davet yanıtı: kabul → accepted request + slot dolar + chat açılır (§12 v7)
create or replace function public.respond_invite(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_i invites%rowtype; v_av availabilities%rowtype;
        v_req uuid; v_chan uuid; v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_i from invites where id = p_id for update;
  if not found then raise exception 'invite_not_found'; end if;
  if v_i.guest_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_i.status <> 'pending' then raise exception 'already_responded'; end if;

  update invites set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = now() where id = p_id;

  if p_accept then
    select * into v_av from availabilities where id = v_i.avail_id for update;
    if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;

    -- kredi: davet kabulünde escrow (guest'ten 1 kredi)
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
    if v_bal < 1 then raise exception 'insufficient_credits'; end if;

    insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score)
    values (v_uid, v_i.host_id, v_i.avail_id, 'accepted', 'direct_invite', v_i.note, 60)
    returning id into v_req;

    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_uid, -1, 'invite_hold', v_req, v_bal - 1);

    update availabilities set filled = filled + 1 where id = v_i.avail_id;

    insert into chat_channels (request_id, kind) values (v_req, 'lounge') returning id into v_chan;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin kabul edildi ✓', 'Sohbet açıldı.', 'request', v_req);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin yanıtlandı', 'Davet reddedildi.', 'invite', p_id);
  end if;

  return jsonb_build_object('ok', true, 'accepted', p_accept, 'request_id', v_req);
end $$;
grant execute on function public.respond_invite(uuid, boolean) to authenticated;

-- Bekleyen davetler (ACTION NEEDED kartı için)
create or replace function public.pending_actions()
returns table (kind text, id uuid, title text, subtitle text, note text, from_name text, from_photo text)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  -- gelen lounge davetleri
  select 'invite'::text, i.id,
         coalesce(a.lounge_name, a.airport_code),
         a.airport_code || ' · ' || a.avail_date::text,
         i.note, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false then p.photo_url else null end
    from invites i
    join availabilities a on a.id = i.avail_id
    join profiles p on p.user_id = i.host_id
   where i.guest_id = v_uid and i.status = 'pending'
  union all
  -- gelen bağlantı istekleri
  select 'connection'::text, cr.id, p.name, coalesce(cr.intent,'connect'), cr.intro, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false then p.photo_url else null end
    from connection_requests cr
    join profiles p on p.user_id = cr.from_id
   where cr.to_id = v_uid and cr.status = 'pending';
end $$;
grant execute on function public.pending_actions() to authenticated;

-- ---------- 3) 11-FAKTÖRLÜ MATCH SCORE (§13) ----------
-- Taban +40 · Trust>=70 +18 / 55-69 +10 · ID +14 · Aynı uçuş +14 · Aynı sektör +12
-- Kadın+kadın +10 · 3+ oturum +8 · LinkedIn +6 · Dil +5 · Puanlama geçmişi +4
-- Trip örtüşmesi +10 · MAX 99
create or replace function public.discover_availabilities(
  p_airport text default null, p_sector text default null, p_flight text default null,
  p_date date default null
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, host_photo text, match_score int,
  same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_langs text[]; v_prof text; v_sessions int; v_rated int;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false), pr.languages, pr.profession
    into v_female, v_safe, v_langs, v_prof
    from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status='completed' and (r.guest_id=v_uid or r.host_id=v_uid);
  select count(*) into v_rated from ratings where rater_id = v_uid;

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
      (p.linkedin is not null and p.linkedin <> '') as hlinked,
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
      and hu.role = 'host'
      and a.avail_date >= current_date                       -- v14: expired gizle
      and coalesce(p.show_on_discovery,true)=true
      and public.is_visible(a.host_id)                       -- gölge kısıt
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)          -- v14: tarih filtresi
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')   -- v7: içerir-eşleşme
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))
  )
  select b.id, b.host_id, b.airport_code, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots, b.filled, b.hn, b.hb, b.hs, b.hp, b.photo,
         least(99,
           40                                                              -- taban
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
           + (case when b.has_trip then 10 else 0 end)                     -- v14: trip örtüşmesi
         )::int as match_score,
         b.same_flight, b.has_trip, b.featured, (b.filled >= b.slots) as fully_booked
  from base b
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $$;
grant execute on function public.discover_availabilities(text, text, text, date) to authenticated;

select 'MATCH 11-FACTOR + BROADCAST OK' as sonuc;
