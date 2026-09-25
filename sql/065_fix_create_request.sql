-- ============================================================
-- LoungeLink · 065_fix_create_request.sql
--
-- 🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu.
--
-- BULGU 1: create_request var olmayan bir kolona yaziyor.
--   `insert into requests (... request_type ...)` diyor ama tablodaki kolon
--   adi `type`. SONUC: MISAFIR HIC ISTEK GONDEREMIYOR
--   ("column request_type of relation requests does not exist").
--
-- BULGU 2: Kavram karisikligi. requests.type bir ENUM (request_type):
--   yalnizca 'standard' | 'direct_invite' degerlerini alir ve istegin NASIL
--   olustugunu anlatir (normal basvuru mu, davet mi).
--   Ama v1.47'de MVP paritesi icin eklenen "Istek Turu" secimi
--   (lounge / airport / coffee / route) BULUSMANIN AMACI'ni anlatir -
--   tamamen farkli bir kavram. Ikisi ayni kolona sikistirilmisti.
--   COZUM: requests.purpose (text) eklendi; type='standard' sabit kaldi.
-- ============================================================

alter table requests add column if not exists purpose text;

CREATE OR REPLACE FUNCTION public.create_request(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if p_idem is not null then
    select id into v_req_id from requests where idempotency_key = p_idem;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;
  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  -- YENİ (033): aynı gün + örtüşen saatte kendi AKTİF host ilanın varsa başvuramazsın
  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  -- REQUEST KAPISI: trip zorunlu (rolden bağımsız — host da trip eklemeli)
  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'), left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $function$;

grant execute on function public.create_request(uuid, text, text, text) to authenticated;

-- DOGRULAMA (ucu de true donmeli)
select
  (prosrc ilike '%status, type, purpose%')      as "dogru_kolon_adi",
  (prosrc ilike '%standard%request_type%')      as "enum_cast_var",
  (prosrc not ilike '%request_type, intro%')    as "eski_kolon_kalmadi"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='create_request';

select '065 OK - create_request dogru kolona yaziyor, purpose ayri kolonda' as sonuc;
