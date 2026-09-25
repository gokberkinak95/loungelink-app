-- ============================================================
-- LoungeLink · 007_request_engine.sql — İstek + Escrow motoru
-- Tüm fonksiyonlar auth.uid() ile yetkilendirir; istemciye güvenilmez.
-- ============================================================

-- 1) İSTEK OLUŞTUR (guest): slot kilidi + kredi hold + duplicate engel — atomik
create or replace function public.create_request(
  p_avail_id uuid,
  p_intro    text default null,
  p_idem     text default null
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_avail  availabilities%rowtype;
  v_bal    integer;
  v_req    requests%rowtype;
  v_visit  uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_avail from availabilities where id = p_avail_id and active for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_avail.host_id = v_uid then raise exception 'own_listing'; end if;
  if v_avail.filled >= v_avail.slots then raise exception 'no_slots_available'; end if;

  -- Duplicate: aynı ilana aktif istek varsa engelle
  if exists (select 1 from requests
             where guest_id = v_uid and avail_id = p_avail_id
               and status in ('pending','accepted')) then
    raise exception 'duplicate_request';
  end if;

  -- Trip gate: aynı havalimanı+tarih, saatler örtüşen seyahat şart
  select id into v_visit from visits
   where user_id = v_uid and airport_code = v_avail.airport_code
     and visit_date = v_avail.avail_date
     and time_from < v_avail.time_to and time_to > v_avail.time_from
   limit 1;
  if v_visit is null then raise exception 'no_matching_trip'; end if;

  -- Kredi kontrolü + hold
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  insert into requests (guest_id, host_id, avail_id, visit_id, intro_message, idempotency_key)
  values (v_uid, v_avail.host_id, p_avail_id, v_visit, left(p_intro,120), p_idem)
  returning * into v_req;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req.id, v_bal - 1);

  update availabilities set filled = filled + 1, updated_at = now() where id = p_avail_id;

  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  values (v_avail.host_id, 'request', 'Yeni istek', 'Bir misafir slotuna istek gönderdi.', v_req.id, 'request');

  return jsonb_build_object('ok', true, 'request_id', v_req.id, 'balance', v_bal - 1);
end $$;

-- 2) YANIT (host: accept/decline) ve İPTAL (guest) — iade mantığı ortak
create or replace function public.respond_request(
  p_request_id uuid,
  p_action     text  -- 'accept' | 'decline' | 'cancel'
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_bal  integer;
  v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;

  if p_action = 'accept' then
    if v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if v_req.status <> 'pending' then raise exception 'not_pending'; end if;
    update requests set status='accepted', responded_at=now() where id = v_req.id;
    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_req.guest_id, 'request', 'İstek kabul edildi! 🎉', 'Sohbet açıldı.', v_req.id, 'request');
    return jsonb_build_object('ok', true, 'channel_id', v_chan);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;

    -- Kredi iadesi + slot iadesi
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'request_refund', v_req.id, v_bal + 1);
    update availabilities set filled = greatest(filled - 1, 0), updated_at = now()
     where id = v_req.avail_id;

    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (case when p_action='decline' then v_req.guest_id else v_req.host_id end,
            'request',
            case when p_action='decline' then 'İstek reddedildi' else 'İstek iptal edildi' end,
            'Kredi anında iade edildi.', v_req.id, 'request');
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown_action';
end $$;

grant execute on function public.create_request(uuid, text, text) to authenticated;
grant execute on function public.respond_request(uuid, text) to authenticated;

-- 3) Guest'in istek atarken ilan sahibini görebilmesi zaten profiles_read_auth ile açık.
--    Chat kanalları: taraflar okuyabilsin (mesajlaşma UI'ı Sprint 2'de)
alter table chat_channels enable row level security;
drop policy if exists "chan_parties" on chat_channels;
create policy "chan_parties" on chat_channels for select using (
  exists (select 1 from requests r where r.id = request_id
          and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
);

select 'REQUEST ENGINE OK' as sonuc;
