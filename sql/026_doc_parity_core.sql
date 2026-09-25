-- ============================================================
-- LoungeLink · 026_doc_parity_core.sql
-- v15 dokümantasyonu P0 uyumu:
--  1) Sözleşme kabulü (consents) — 5 madde, kayıtta zorunlu
--  2) Session başlatma YALNIZ host (§7.5, §15)
--  3) Request kapısı: trip gate sunucuda (§8.3, TG §3.2)
--  4) Telefon gating tüm noktalarda (§6)
--  5) Çift request DB engeli + idempotency (TG §3.3)
--  6) Expired ilan sorgu düzeyinde dışlama (v14)
--  7) Slot limiti host kapasitesine bağlı (§4)
-- ============================================================

-- ---------- 1) CONSENTS ----------
-- 5 madde: lounge satış yasağı, platform dışı ödeme yasağı, topluluk kuralları,
-- havalimanı/havayolu kuralları, T&C + gizlilik
create or replace function public.grant_consents(p_types text[], p_version text default 'v15')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); t text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  foreach t in array p_types loop
    insert into consents (user_id, type, version, granted_at)
    values (v_uid, t, p_version, now())
    on conflict do nothing;
  end loop;
  return jsonb_build_object('ok', true, 'count', array_length(p_types,1));
end $$;
grant execute on function public.grant_consents(text[], text) to authenticated;

-- ---------- 2) HOST KAPASİTE BEYANI ----------
alter table profiles add column if not exists guest_capacity int;      -- 1 | 2 (null = beyan yok)
alter table profiles add column if not exists access_source text;      -- Priority Pass, LoungeKey, ...
alter table profiles add column if not exists location_sharing boolean default false;

-- ---------- 3) IDEMPOTENCY + ÇİFT REQUEST ENGELİ ----------
alter table requests add column if not exists idempotency_key text;
create unique index if not exists requests_idem_uniq
  on requests (idempotency_key) where idempotency_key is not null;
-- Aynı guest aynı ilana aktif statüde tek request
create unique index if not exists requests_guest_avail_active_uniq
  on requests (guest_id, avail_id) where status in ('pending','accepted');

-- ---------- 4) MÜSAİTLİK YAYINLAMA: telefon gating + kapasite limiti ----------
create or replace function public.publish_availability(
  p_airport text, p_lounge_id uuid, p_lounge_name text, p_date date,
  p_from time, p_to time, p_slots int, p_flight text default null,
  p_visibility text default 'Public'
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_ok boolean; v_cap int; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- §6: telefon doğrulaması zorunlu
  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  -- §4: slot limiti beyan edilen kapasiteyi aşamaz
  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_declared'; end if;
  if p_slots > v_cap then raise exception 'slots_exceed_capacity'; end if;
  if p_to <= p_from then raise exception 'invalid_time_range'; end if;

  insert into availabilities (host_id, airport_code, lounge_id, lounge_name, avail_date,
                              time_from, time_to, slots, filled, flight_number, visibility, active)
  values (v_uid, p_airport, p_lounge_id, p_lounge_name, p_date, p_from, p_to, p_slots, 0,
          nullif(p_flight,''), p_visibility, true)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
grant execute on function public.publish_availability(text, uuid, text, date, time, time, int, text, text) to authenticated;

-- ---------- 5) REQUEST KAPISI (trip gate) + escrow ----------
create or replace function public.create_request(
  p_avail_id uuid, p_type text default 'lounge', p_intro text default null,
  p_idem text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- idempotency: aynı anahtarla ikinci çağrı mevcut kaydı döner
  if p_idem is not null then
    select id into v_req_id from requests where idempotency_key = p_idem;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  -- §6: telefon gating
  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  -- satır kilidi (TG §3.2: eşzamanlı iki request son slotu alamaz)
  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;
  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  -- v14: expired ilan
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  -- v14 REQUEST KAPISI: aynı havalimanı + gün + örtüşen saat trip'i olmalı
  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  -- escrow: 1 kredi hold
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', p_type, left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $$;
grant execute on function public.create_request(uuid, text, text, text) to authenticated;

-- ---------- 6) SESSION BAŞLATMA: YALNIZ HOST (§7.5, §15) ----------
create or replace function public.start_session(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_req requests%rowtype; v_sess_id uuid; v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_req from requests where id = p_request_id;
  if not found then raise exception 'request_not_found'; end if;
  if v_req.status <> 'accepted' then raise exception 'request_not_accepted'; end if;

  -- DOKÜMAN §7.5: yalnız HOST başlatabilir
  if v_req.host_id <> v_uid then raise exception 'only_host_can_start'; end if;

  select id into v_sess_id from sessions where request_id = p_request_id;
  if v_sess_id is not null then return jsonb_build_object('ok', true, 'id', v_sess_id, 'existing', true); end if;

  insert into sessions (request_id, status, started_at)
  values (p_request_id, 'active', now()) returning id into v_sess_id;

  -- escrow capture: hold edilen kredi onaylanır (defterde kapama satırı)
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_req.guest_id, 0, 'request_capture', p_request_id, v_bal);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_req.guest_id, 'sessions', 'Oturum başladı ✓',
          'Host oturumu başlattı.', 'session', v_sess_id);

  return jsonb_build_object('ok', true, 'id', v_sess_id);
end $$;
grant execute on function public.start_session(uuid) to authenticated;

-- ---------- 7) TELEFON GATING: bağlantı isteği (§6) ----------
create or replace function public.send_connection(p_to uuid, p_intent text, p_intro text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_ok boolean; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_to = v_uid then raise exception 'self_connect_blocked'; end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  if exists (select 1 from connection_requests
              where ((from_id=v_uid and to_id=p_to) or (from_id=p_to and to_id=v_uid))
                and status in ('pending','accepted')) then
    raise exception 'connection_exists';
  end if;

  insert into connection_requests (from_id, to_id, intent, intro, status)
  values (v_uid, p_to, coalesce(p_intent,'connect'), left(coalesce(p_intro,''),140), 'pending')
  returning id into v_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_to, 'connections', 'Yeni bağlantı isteği ◈',
          'Bir yolcu seninle bağlantı kurmak istiyor.', 'connection', v_id);

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
grant execute on function public.send_connection(uuid, text, text) to authenticated;

-- ---------- 8) TRUST: telefon doğrulama +10 (§6, doküman değeri) ----------
create or replace function public.verify_otp(p_phone text, p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_row otp_tokens%rowtype; v_ok boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- demo: 0000 her zaman geçerli (§6)
  if p_code = '0000' then
    v_ok := true;
  else
    select * into v_row from otp_tokens
     where user_id = v_uid and phone = p_phone and consumed_at is null
       and expires_at > now() order by created_at desc limit 1;
    if found and v_row.code_hash = crypt(p_code, v_row.code_hash) then
      v_ok := true;
      update otp_tokens set used_at = now() where id = v_row.id;
    end if;
  end if;

  if not v_ok then raise exception 'invalid_code'; end if;

  update users set phone = p_phone where id = v_uid;
  update verifications set phone_verified = true, phone_verified_at = now() where user_id = v_uid;

  -- §16: telefon doğrulama +10
  update trust_scores
     set score = least(100, score + 10),
         components = coalesce(components,'{}'::jsonb) || '{"phone":10}'::jsonb,
         updated_at = now()
   where user_id = v_uid and not (coalesce(components,'{}'::jsonb) ? 'phone');

  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.verify_otp(text, text) to authenticated;

-- ---------- 9) TELEFON DEĞİŞİNCE yeniden doğrulama (§6, §22) ----------
create or replace function public.change_phone(p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update users set phone = p_phone where id = v_uid;
  update verifications set phone_verified = false, phone_verified_at = null where user_id = v_uid;
  update trust_scores
     set score = greatest(0, score - 10),
         components = coalesce(components,'{}'::jsonb) - 'phone'
   where user_id = v_uid and (coalesce(components,'{}'::jsonb) ? 'phone');
  return jsonb_build_object('ok', true, 'reverify_required', true);
end $$;
grant execute on function public.change_phone(text) to authenticated;

select 'DOC PARITY CORE OK' as sonuc;
