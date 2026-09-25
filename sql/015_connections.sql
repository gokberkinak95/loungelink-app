-- ============================================================
-- LoungeLink · 015_connections.sql — Tanış / Havalimanı Yol Arkadaşı Ağı
-- Lounge erişimi GEREKTİRMEZ, kredi harcamaz, karşılıklı onayla çalışır.
-- Bağlantılar connection_requests tablosunda status ile tutulur.
-- ============================================================

-- RLS: kendi gönderdiğin/aldığın bağlantı isteklerini gör
alter table connection_requests enable row level security;
drop policy if exists "conn_own_read" on connection_requests;
create policy "conn_own_read" on connection_requests for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());

-- 1) Bağlantı isteği gönder (doğrulanmış telefon şart — spam bariyeri)
create or replace function public.send_connection(p_to uuid, p_intent text default null, p_intro text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_phone boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_to = v_uid then raise exception 'self_connection'; end if;
  select phone_verified into v_phone from verifications where user_id = v_uid;
  if not coalesce(v_phone, false) then raise exception 'phone_not_verified'; end if;

  -- Zaten bağlantı/istek var mı? (her iki yön)
  if exists (select 1 from connection_requests
             where (from_id = v_uid and to_id = p_to) or (from_id = p_to and to_id = v_uid)) then
    raise exception 'already_exists';
  end if;

  insert into connection_requests (from_id, to_id, intent, intro, status)
  values (v_uid, p_to, p_intent, left(p_intro,150), 'pending');

  insert into notifications (user_id, category, title, body, ref_type)
  values (p_to, 'connection', 'Yeni bağlantı isteği', 'Biri seninle tanışmak istiyor.', 'connection');
  return jsonb_build_object('ok', true);
end $$;

-- 2) İsteğe yanıt ver (accept / decline)
create or replace function public.respond_connection(p_req_id uuid, p_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_req connection_requests%rowtype;
begin
  select * into v_req from connection_requests where id = p_req_id for update;
  if not found or v_req.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_req.status <> 'pending' then raise exception 'not_pending'; end if;

  update connection_requests
     set status = case when p_action = 'accept' then 'accepted' else 'declined' end::connection_status
   where id = p_req_id;

  if p_action = 'accept' then
    insert into notifications (user_id, category, title, body, ref_type)
    values (v_req.from_id, 'connection', 'Bağlantı kabul edildi! 🤝', 'Artık bağlantısınız.', 'connection');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- 3) Tanış listesi: keşfedilebilir kullanıcılar (kendisi + zaten bağlantı olanlar hariç)
--    Kadın güvenlik modu burada da geçerli (çift yönlü).
create or replace function public.discover_people(p_airport text default null)
returns table (user_id uuid, name text, profession text, bio text, badge text, score int, rel text)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  return query
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel
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

grant execute on function public.send_connection(uuid, text, text) to authenticated;
grant execute on function public.respond_connection(uuid, text) to authenticated;
grant execute on function public.discover_people(text) to authenticated;

select 'CONNECTIONS OK' as sonuc;
