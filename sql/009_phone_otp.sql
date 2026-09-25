-- ============================================================
-- LoungeLink · 009_phone_otp.sql — Telefon OTP doğrulama (demo mod)
-- Demo modda kod SMS ile gitmez; RPC kodu döndürür, uygulama gösterir.
-- Gerçek SMS'e geçince: send_otp içindeki return'den 'demo_code' çıkarılır,
-- yerine Netgsm/Twilio çağrısı (Edge Function) eklenir. Doğrulama aynı kalır.
-- ============================================================

create extension if not exists pgcrypto;

-- 1) KOD GÖNDER: 6 haneli kod üret, hash'le sakla, demo modda kodu döndür
create or replace function public.send_otp(p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_code text;
  v_recent int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_phone !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'bad_phone_format'; end if;

  -- Hız sınırı: son 1 dakikada 1 kod
  select count(*) into v_recent from otp_tokens
   where user_id = v_uid and created_at > now() - interval '1 minute';
  if v_recent >= 1 then raise exception 'too_many_requests'; end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

  -- Eski kullanılmamış kodları geçersiz kıl
  update otp_tokens set used_at = now()
   where user_id = v_uid and used_at is null and purpose = 'phone_verify';

  insert into otp_tokens (user_id, phone_e164, code_hash, purpose, expires_at)
  values (v_uid, p_phone, crypt(v_code, gen_salt('bf')), 'phone_verify', now() + interval '5 minutes');

  -- DEMO: kodu döndür. Gerçek modda bu satır kaldırılır, SMS gönderilir.
  return jsonb_build_object('ok', true, 'demo_code', v_code, 'expires_in', 300);
end $$;

-- 2) KOD DOĞRULA: eşleşirse verifications.phone_verified = true + güven puanı +15
create or replace function public.verify_otp(p_phone text, p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_tok otp_tokens%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_tok from otp_tokens
   where user_id = v_uid and phone_e164 = p_phone and purpose = 'phone_verify'
     and used_at is null and expires_at > now()
   order by created_at desc limit 1
   for update;

  if not found then raise exception 'code_expired_or_missing'; end if;
  if v_tok.attempts >= 5 then raise exception 'too_many_attempts'; end if;

  if crypt(p_code, v_tok.code_hash) <> v_tok.code_hash then
    update otp_tokens set attempts = attempts + 1 where id = v_tok.id;
    raise exception 'wrong_code';
  end if;

  update otp_tokens set used_at = now() where id = v_tok.id;

  update users set phone_e164 = p_phone where id = v_uid;
  update verifications set phone_verified = true, phone_verified_at = now(), updated_at = now()
   where user_id = v_uid;

  -- Güven puanı: telefon doğrulaması +15 (idempotent — components anahtarıyla)
  update trust_scores set
    score = least(100, score + case when (components->>'phone') is null then 15 else 0 end),
    components = components || '{"phone":15}'::jsonb,
    badge = case when score + 15 >= 30 then 'Verified' else badge end,
    updated_at = now()
  where user_id = v_uid;

  return jsonb_build_object('ok', true, 'phone_verified', true);
end $$;

grant execute on function public.send_otp(text) to authenticated;
grant execute on function public.verify_otp(text, text) to authenticated;

-- 3) İstek göndermek için telefon doğrulaması zorunlu olsun (güven bariyeri)
--    create_request'e tek satır ekliyoruz: doğrulanmamış guest istek atamaz.
create or replace function public.create_request(
  p_avail_id uuid, p_intro text default null, p_idem text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_avail availabilities%rowtype;
  v_bal integer; v_req requests%rowtype; v_visit uuid; v_phone boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select phone_verified into v_phone from verifications where user_id = v_uid;
  if not coalesce(v_phone, false) then raise exception 'phone_not_verified'; end if;

  select * into v_avail from availabilities where id = p_avail_id and active for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_avail.host_id = v_uid then raise exception 'own_listing'; end if;
  if v_avail.filled >= v_avail.slots then raise exception 'no_slots_available'; end if;
  if exists (select 1 from requests where guest_id = v_uid and avail_id = p_avail_id
             and status in ('pending','accepted')) then raise exception 'duplicate_request'; end if;

  select id into v_visit from visits
   where user_id = v_uid and airport_code = v_avail.airport_code
     and visit_date = v_avail.avail_date
     and time_from < v_avail.time_to and time_to > v_avail.time_from limit 1;
  if v_visit is null then raise exception 'no_matching_trip'; end if;

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
grant execute on function public.create_request(uuid, text, text) to authenticated;

select 'PHONE OTP OK' as sonuc;
