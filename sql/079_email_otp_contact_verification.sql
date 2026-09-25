-- ============================================================
-- LoungeLink · 079_email_otp_contact_verification.sql
--
-- AMAÇ: SMS maliyeti olmadan GERÇEK doğrulama. Bugüne kadar telefon OTP'si
-- "demo bypass" (kod 0000) ile açıktı — yani doğrulama aslında YOKTU.
--
-- KARAR (maliyetsiz yol):
--   · Doğrulama kapısı artık "DOĞRULANMIŞ İLETİŞİM" = telefon VEYA e-posta.
--   · E-posta doğrulama kodunu SUPABASE AUTH'un kendisi gönderir
--     (signInWithOtp/verifyOtp) — ek servis, ek ücret, ek kod YOK.
--     Uygulama kodu doğrulattıktan sonra bu dosyadaki
--     verify_email_contact() çağrılır ve işaret DB'ye yazılır.
--   · Telefon OTP altyapısı DURUYOR; SMS sağlayıcısı geldiği gün tek
--     satırla devreye girer.
--   · otp_demo_bypass KAPATILIYOR (artık gerek yok — sahte doğrulama son).
--
-- Ayrıca 078'in "tek yazıcı" kuralı verify_otp'a da uygulanır.
-- İdempotent.
-- ============================================================

-- ---------- 1) E-posta doğrulama alanı ----------
alter table verifications add column if not exists email_verified boolean default false;
alter table verifications add column if not exists email_verified_at timestamptz;

-- Zaten e-postasını onaylamış olanları geriye dönük işaretle
update verifications v set email_verified = true, email_verified_at = coalesce(v.email_verified_at, now())
  from auth.users au
 where au.id = v.user_id and au.email_confirmed_at is not null and coalesce(v.email_verified,false) = false;


-- ---------- 2) Tek kaynak: doğrulanmış iletişim ----------
create or replace function public.is_contact_verified(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(bool_or(phone_verified) or bool_or(email_verified), false)
    from verifications where user_id = p_user
$$;
grant execute on function public.is_contact_verified(uuid) to authenticated;


-- ---------- 3) E-posta doğrulamasını işaretle ----------
-- Uygulama akışı: supabase.auth.signInWithOtp({email}) → kullanıcı koda girer
-- → supabase.auth.verifyOtp(...) → BAŞARILIYSA bu fonksiyon çağrılır.
-- Fonksiyon kendi başına da güvenli: auth.users.email_confirmed_at'e bakar,
-- yani istemci "doğruladım" diye yalan söyleyemez.
create or replace function public.verify_email_contact()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_conf timestamptz; v_email text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select email_confirmed_at, email into v_conf, v_email from auth.users where id = v_uid;
  if v_conf is null then raise exception 'email_not_confirmed'; end if;

  insert into verifications (user_id, email_verified, email_verified_at)
  values (v_uid, true, now())
  on conflict (user_id) do update set email_verified = true, email_verified_at = now();

  perform public.recompute_trust(v_uid);
  return jsonb_build_object('ok', true, 'email', v_email);
end $$;
grant execute on function public.verify_email_contact() to authenticated;


-- ---------- 4) Demo bypass KAPATILIYOR ----------
update beta_settings set value = 'false'::jsonb where key = 'otp_demo_bypass';


-- ---------- 5) verify_otp: güveni elle yazmaz (078 kuralı) ----------
CREATE OR REPLACE FUNCTION public.verify_otp(p_phone text, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := auth.uid();
  v_row    otp_tokens%rowtype;
  v_ok     boolean := false;
  v_demo   boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- Demo kısayolu yalnızca ayar açıkken geçerli (lansmanda kapatılacak)
  select coalesce((value)::text = 'true', false) into v_demo
    from beta_settings where key = 'otp_demo_bypass';

  if v_demo and p_code = '0000' then
    v_ok := true;
  else
    -- DOĞRU KOLONLAR: phone_e164 + used_at (send_otp ile aynı)
    select * into v_row from otp_tokens
     where user_id = v_uid
       and phone_e164 = p_phone
       and used_at is null
       and expires_at > now()
     order by created_at desc
     limit 1
     for update;

    if not found then
      raise exception 'invalid_code';       -- süresi dolmuş ya da hiç yok
    end if;

    -- KABA-KUVVET KORUMASI (009'dan geri getirildi)
    if coalesce(v_row.attempts, 0) >= 5 then
      raise exception 'too_many_attempts';
    end if;

    if v_row.code_hash = crypt(p_code, v_row.code_hash) then
      v_ok := true;
      update otp_tokens set used_at = now() where id = v_row.id;
    else
      -- Yanlış kod → deneme sayacını artır, sonra hata ver
      update otp_tokens set attempts = coalesce(attempts,0) + 1 where id = v_row.id;
      raise exception 'invalid_code';
    end if;
  end if;

  if not v_ok then raise exception 'invalid_code'; end if;

  -- Telefonu kullanıcıya yaz — HER İKİ kolon da (phone_in_use phone_e164 okuyor)
  update users set phone = p_phone, phone_e164 = p_phone where id = v_uid;

  insert into verifications (user_id, phone_verified, phone_verified_at)
  values (v_uid, true, now())
  on conflict (user_id) do update
    set phone_verified = true, phone_verified_at = now();

  -- §16: telefon doğrulama +10 (yalnızca bir kez)
  perform public.recompute_trust(v_uid);   -- 078/079: tek yazıcı

  return jsonb_build_object('ok', true);
end $function$;
grant execute on function public.verify_otp(text, text) to authenticated;

-- ---------- 6) KAPILAR: telefon → doğrulanmış iletişim ----------
CREATE OR REPLACE FUNCTION public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_cap int; v_ok boolean; v_id uuid; v_conflict boolean;
  v_vis availability_visibility; v_min_trust smallint := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if p_slots > v_cap then raise exception 'slots_exceed_capacity'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;

  -- 033: örtüşen saatte bekleyen/kabul edilmiş guest isteğin varsa ilan açamazsın
  select exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = p_date
       and a.time_from < p_to and p_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'guest_same_slot'; end if;

  -- 040: MVP'nin all/trusted/hidden -> enum + eşik
  case lower(coalesce(p_visibility,'all'))
    when 'all'         then v_vis := 'Public';      v_min_trust := 0;
    when 'trusted'     then v_vis := 'Public';      v_min_trust := 55;
    when 'hidden'      then v_vis := 'Hidden';      v_min_trust := 0;
    when 'connections' then v_vis := 'Connections'; v_min_trust := 0;
    else raise exception 'bad_visibility';
  end case;

  insert into availabilities (
    host_id, lounge_id, airport_code, avail_date, time_from, time_to,
    slots, filled, active, visibility, flight_number, min_trust
  )
  values (
    v_uid, p_lounge_id, p_airport, p_date, p_from, p_to,
    p_slots, 0, true, v_vis, nullif(trim(p_flight),''), v_min_trust
  )
  returning id into v_id;

  -- 055: ilan açmak = host olmak (rol)
  update users set role = 'host' where id = v_uid and role <> 'host';

  -- YENİ (074): ilan açmak = APP HOST'U olmak (görünürlük).
  -- Sıra önemli: is_staff hâlâ true iken profil düzeltilir (işaret olarak
  -- kullanılıyor), SONRA bayrak temizlenir. Kullanıcının kendi kapattığı
  -- show_on_discovery'ye (staff değilse) dokunulmaz.
  update profiles p set show_on_discovery = true
   where p.user_id = v_uid
     and p.show_on_discovery = false
     and exists (select 1 from users u where u.id = v_uid and u.is_staff = true);
  update users set is_staff = false where id = v_uid and is_staff = true;

  -- 056: ARZ-TALEP EŞLEŞTİRME — eşleşen misafirlere "host geldi" bildirimi
  -- (SELECT içindeki literal enum'a OTOMATİK çevrilmez -> 071 cast'i korunur)
  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  select distinct vs.user_id, 'requests'::notif_category,
         'Havalimanında host var! ✦',
         'Seni bekleyen bir host ' || p_airport || ' için ilan açtı. Hemen başvur.',
         v_id, 'availability'
    from visits vs
    join users gu on gu.id = vs.user_id
   where vs.airport_code = p_airport
     and vs.visit_date = p_date
     and vs.time_from < p_to and p_from < vs.time_to
     and vs.user_id <> v_uid
     and coalesce(gu.is_staff,false) = false
     and gu.deleted_at is null;

  return jsonb_build_object('ok', true, 'id', v_id, 'visibility', v_vis, 'min_trust', v_min_trust);
end $function$;

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

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

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

CREATE OR REPLACE FUNCTION public.send_connection(p_to uuid, p_intent text, p_intro text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_ok boolean; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_to = v_uid then raise exception 'self_connect_blocked'; end if;

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

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
end $function$;

CREATE OR REPLACE FUNCTION public.send_invite(p_guest uuid, p_avail_id uuid, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_ok boolean; v_id uuid; v_av availabilities%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

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
end $function$;

grant execute on function public.create_request(uuid, text, text, text) to authenticated;
grant execute on function public.create_availability(uuid, text, date, time, time, integer, text, text) to authenticated;
grant execute on function public.send_invite(uuid, uuid, text) to authenticated;
grant execute on function public.send_connection(uuid, text, text) to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
-- (1) true dönmeli: kapılar artık iletişim doğrulamasına bakıyor
select bool_and(prosrc ilike '%is_contact_verified%') as "kapilar_guncel"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'
   and p.proname in ('create_request','create_availability','send_invite','send_connection');

-- (2) false dönmeli: demo bypass kapalı
select (value)::text = 'true' as "demo_bypass_hala_acik" from beta_settings where key='otp_demo_bypass';

-- (3) true dönmeli: e-posta doğrulama fonksiyonu var
select exists (select 1 from pg_proc where proname='verify_email_contact') as "email_dogrulama_var";

select '079 OK - dogrulama kapisi telefon VEYA e-posta, demo bypass kapatildi' as sonuc;
