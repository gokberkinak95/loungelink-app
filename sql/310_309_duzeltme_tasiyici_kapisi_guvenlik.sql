-- ============================================================================
-- 310 · 309 DÜZELTMELERİ (Gökberk, 30 Eylül) + TAŞIYICI KAPISI SUNUCUDA + GÜVENLİK SIKILAŞTIRMASI
--
-- A) SAW THY CIP (iç hat) salon seçicide GERİ açık. Gökberk: "şimdilik açık olsun — açılmış
--    olabilir, her türlü açılacak." 309 onu seçiciden çekmişti.
-- B) THY dışı TR salonlarında Miles&Smiles: 309 "geçmez" yazmıştı; bu DOĞRULANMIŞ bir bilgi
--    değildi (THY'nin TR dış hat uçuşlarında statü sahiplerini hangi anlaşmalı salona aldığı
--    resmî tabloda yok; ör. ADB dış hatta tek salon Primeclass). Doğrulayamadığımız yerde
--    engellemiyoruz: satırlar ÖNCEKİ hâline döner → misafir "kural doğrulanmadı · kapıda teyit
--    et" görür ve başvurabilir. (Miles&Smiles = THY + AJet'in statü programı; kuralları yalnız
--    THY/AJet salonları ve THY'nin anlaşmalı salonları için tanımlı.)
-- C) Taşıyıcı uyuşmazlığı SUNUCUDA da kesin engel (create_request + ön kontrol birlikte).
--    Keşfet rozeti zaten engelliyordu; doğrudan API çağrısı geçebiliyordu.
-- D) Güvenlik: istemcinin HİÇ çağırmadığı 21 iç yardımcı fonksiyon oturum açmış her
--    kullanıcıya açıktı (ör. verification_state, best_access_for_user, card_self_check,
--    etkin_plan başkasının kullanıcı kimliğiyle çağrılıp veri okuyabiliyordu). EXECUTE yalnız
--    service_role'e; bu fonksiyonları çağıran bütün fonksiyonlar SECURITY DEFINER (ölçüldü:
--    politika / görünüm / invoker çağıran YOK), yani uygulama akışı etkilenmez.
-- E) Profil fotoğrafı: "yalnız bağlantılarım görsün" diyen kullanıcının fotoğrafı tahmin
--    edilebilir adresten (<uid>/avatar.jpg) açılabiliyordu ve klasörler herkese listeleniyordu.
--    App 6.2.5 rastgele dosya adı kullanır; burada listeleme yalnız sahibine kalır.
--
-- Supabase SQL Editor: tamamını yapıştır, çalıştır. 309'dan SONRA. Tekrar koşulabilir.
-- ============================================================================

-- ── A) SAW THY CIP seçicide açık ────────────────────────────────────────────
update lounges set active = true
 where venue_id = (select id from lounge_venues where airport_code = 'SAW' and name = 'Turkish Airlines CIP Lounge — İç Hat' limit 1)
   and not active
   and name = 'Turkish Airlines CIP Lounge — İç Hat';

update lounge_venues
   set notes = trim(replace(coalesce(notes,''), ' · 309: 3 Nisan 2026''dan beri GEÇİCİ HİZMET DIŞI (AJet kural tablosu). Açılınca lounges.active = true.', '')
                    || ' · 310: AJet tablosu 3 Nisan''dan beri geçici kapalı diyor; Gökberk kararıyla açık tutuluyor.')
 where airport_code = 'SAW' and name = 'Turkish Airlines CIP Lounge — İç Hat'
   and coalesce(notes,'') not like '%310:%';

-- ── B) THY dışı salonlarda M&S: "geçmez" → önceki "doğrulanmadı" ────────────
update lounge_venue_acceptance
   set accepted = true, guest_policy = 'unknown', is_placeholder = true,
       conditions = 'Miles&Smiles (THY/AJet statüsü) bu salonda geçerli mi DOĞRULANMADI — kapıda teyit edilmeli.',
       verified_by = null, updated_at = now()
 where conditions like 'Miles&Smiles statüsü bu salonda geçmez%';

-- ── C) Taşıyıcı kapısı: sunucu + ön kontrol birlikte ────────────────────────
CREATE OR REPLACE FUNCTION public.create_request_impl_preflag(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean; v_cost int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1: yasakli/silinmis hesap yazamaz

  if p_idem is not null then
    select id into v_req_id from requests
     where idempotency_key = p_idem and guest_id = v_uid;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;

  if public.is_blocked_pair(v_uid, v_av.host_id) then
    raise exception 'blocked_pair';
  end if;

  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  declare v_dec jsonb;
  begin
    -- 281/R2: karar ARTIK v5 ve MİSAFİRİN KENDİ UÇUŞUYLA veriliyor.
    -- Uçuş, ilanla çakışan seyahat kaydından okunuyor (v_has_trip zaten
    -- birinin varlığını kanıtladı). Ekranın gördüğü kararla sunucunun
    -- uyguladığı karar aynı fonksiyondan çıkıyor — iki motor değil, bir.
    declare v_gf text; v_gc text; v_gvid uuid;
    begin
      select v.flight_number, v.carrier_code, v.id into v_gf, v_gc, v_gvid
        from visits v
       where v.user_id = v_uid
         and v.airport_code = v_av.airport_code
         and v.visit_date = v_av.avail_date
         and v.time_from < v_av.time_to and v_av.time_from < v.time_to
       order by (v.flight_number is not null) desc, v.created_at desc
       limit 1;
      v_dec := public.lounge_access_decision_v6(p_avail_id, v_gf, v_gc, v_gvid);   -- 283: on iki boyut
    end;
    if (v_dec ->> 'block_code') is not null then
      raise exception '%', (v_dec ->> 'block_code');   -- 283: party_too_big / scope_mismatch / quota_exhausted / cabin_required / children_not_allowed
    end if;
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
    -- Havayolu şartı KESİN (enforcement=block) ve misafirin uçuşu
    -- uymuyorsa istek SUNUCUDA durur — onay kutusuyla geçilemez.
    -- 310: taşıyıcı uyuşmazlığı KESİN engel (Keşfet rozeti ile AYNI kural: program bilinir ve
    -- banka kartı değilse). Eskiden yalnız enforcement=block satırlarda duruyordu; THY/AJet
    -- satırlarının çoğu 'warn' olduğundan uygulamayı atlayan doğrudan çağrı geçebiliyordu.
    if (v_dec ->> 'carrier_ok') = 'false' and (v_dec ->> 'program_id') is not null
       and coalesce(v_dec ->> 'entitlement_model', '') <> 'bank_card' then
      raise exception 'guest_carrier_mismatch';
    end if;
  end;

  -- 🔴 207: BEDEL ARTIK MERTEBEDEN OKUNUYOR, sabit -1 değil.
  v_cost := public.request_credit_cost(v_uid, p_avail_id);

  -- 299/B2: bakiye ARTIK KILITLI okunuyor (kullanici basina).
  perform pg_advisory_xact_lock(hashtextextended('kredi:' || v_uid::text, 0));
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < v_cost then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'),
          left(coalesce(p_intro,''),120), coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  -- Bedel 0 ise defter satırı YİNE DE yazılır: "bu istek Konsiyerj
  -- ayrıcalığıyla ücretsizdi" bilgisi kaybolmamalı.
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (v_uid, -v_cost,
          case when v_cost = 0 then 'request_free_tier' else 'request_hold' end,
          v_req_id, v_bal - v_cost,
          case when v_cost = 0 then (case when public.request_credit_cost(v_uid) = 0
            then 'Konsiyerj ayricaligi: istek kredi harcamadi'
            else 'Soguk ag: bu havalimaninda yeterli host yok, istek kredi harcamadi' end) end);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id, 'kredi_bedeli', v_cost);
end $function$;

CREATE OR REPLACE FUNCTION public.request_precheck_pregate(p_avail_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_tut int := 1; v_bal int; v_qnote text; v_cnote text;
  v_tier text; v_head text; v_key text; v_detail text; v_more text;
begin
  -- 🔴 192-seyahat: SUNUCU KAPISININ AYNISI. create_request
  -- (007:41) ayni havalimani + AYNI TARIH icin seyahat arar.
  -- Precheck bunu hic sormuyordu; ekran "gonderebilirsin" deyip
  -- sunucu ham "no_matching_trip" firlatiyordu.
  if not exists (
       select 1 from visits v
        join availabilities a2 on a2.id = p_avail_id
       where v.user_id = auth.uid()
         and v.airport_code = a2.airport_code
         and v.visit_date  = a2.avail_date)
  then
    return jsonb_build_object(
      'can_request', false, 'kind', 'trip_gate', 'severity', 'block',
      'headline', 'Bu tarihte o havalimanında seyahatin yok',
      'detail', 'Bu ilan ' || (select to_char(a3.avail_date, 'DD.MM.YYYY')
                    || ' tarihinde ' || a3.airport_code
                    from availabilities a3 where a3.id = p_avail_id)
                 || '. O gün için bir seyahat ekle, ilan hemen başvurulabilir olsun.',
      'fix_action', 'add_trip',
      'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);
  end if;

  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;

  select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))
    into v_flight, v_carrier
    from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v6(p_avail_id, v_flight, v_carrier,
         (select v.id from visits v where v.user_id = v_uid and v.airport_code = v_av.airport_code and v.visit_date = v_av.avail_date order by (coalesce(v.flight_number,'') <> '') desc, v.created_at desc limit 1));   -- 283
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;
  v_credit := public.paid_guest_credit(p_avail_id);
  v_tut := coalesce(public.request_credit_cost(auth.uid(), p_avail_id), 1);
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  v_qnote := public.guest_quota_note(v_av.host_id);
  v_cnote := public.card_confidence_note(v_av.host_id);
  v_tier  := public.card_tier_label(d ->> 'host_tier');

  v_head := case
    when coalesce((d ->> 'charter'),'false') = 'true' then public.rule_notice('head_charter')
    when (d ->> 'carrier_ok') = 'false' then public.rule_notice('head_carrier_bad')
    when (d ->> 'guest_policy') = 'not_allowed' and v_tier is not null
      then replace(public.rule_notice('head_tier_no_guest'), '{tier}', v_tier)
    when (d ->> 'guest_policy') = 'paid' and v_tier is not null
      then replace(public.rule_notice('head_tier_paid'), '{tier}', v_tier)
    when (d ->> 'guest_policy') = 'paid' and (d ->> 'fee_payer') = 'member_card'
      then public.rule_notice('head_fee_member')
    when (d ->> 'guest_policy') = 'paid' then public.rule_notice('head_fee_door')
    when (d ->> 'confidence') in ('unknown','assumed') then public.rule_notice('head_unverified')
    else d ->> 'headline' end;

  -- 🔴 DETAY: KAPIDA ISE YARAYACAK TEK CUMLE.
  -- Onceligi kullanicinin GERI CEVRILME riskine gore veriyoruz:
  -- engel sebebi > ucret > kota > kart guveni. En kritik olan basa.
  v_key := case
    when coalesce((d ->> 'charter'),'false') = 'true' then 'charter'
    when (d ->> 'carrier_ok') = 'false' then 'carrier'
    when (d ->> 'guest_policy') = 'not_allowed' then 'noguest'
    when (d ->> 'guest_policy') = 'paid' then 'paid'
    else 'generic' end;

  v_detail := public.clip_text(case v_key
    when 'charter' then 'Charter seferde havayolu salonu hakkı yoktur.'
    when 'carrier' then 'Bu salon misafirin host ile aynı havayolunda uçmasını istiyor.'
    when 'noguest' then 'Host girebiliyor ama yanında misafir götüremiyor.'
    when 'paid'    then case (d ->> 'fee_payer')
                          when 'member_card' then 'Ücret host''un kartından çekilir.'
                          else 'Misafir girişi kapıda ücretlidir.' end
    else coalesce(d ->> 'detail', public.rule_notice('rule_notice_generic')) end, 140);

  -- 🔴 GERISI SILINMIYOR, ⓘ ARKASINA GIDIYOR. Kural eksiksiz aktarilir;
  -- yalniz HEPSI AYNI ANDA gosterilmez.
  v_more := public.clip_text(
    trim(both ' ' from concat_ws(' ',
      nullif(d ->> 'detail',''), nullif(v_qnote,''), nullif(v_cnote,''),
      nullif(d ->> 'source_conflict',''))), 400);

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object(/* 192-kapi: kredi karti dali da SUNUCU KAPISINA uyar.
        159'un create_request_impl'i guest_policy='not_allowed' ya da
        severity=block olan ilanda 'guests_not_allowed' firlatiyor;
        ekran bunu bilmeden 'gonderebilirsin' diyordu. */
      'can_request',
        not (coalesce(d ->> 'guest_policy','') = 'not_allowed'
             or (coalesce(d ->> 'severity','') = 'block'
                 and coalesce(d ->> 'fits','') <> 'false')),
      'needs_ack', true, 'kind','card_generic',
      /* 192-karar: erken donus de kararin politikasini TASIR.
         Eskiden bu dal guest_policy'yi hic dondurmuyordu ve
         kesif "misafir kabul etmiyor" derken istek ekrani susuyordu. */
      'guest_policy', d ->> 'guest_policy',
      'guest_allowance', coalesce((d ->> 'guest_included_count')::int, 0),
      'severity_src', d ->> 'severity',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'credit_cost', 0,
      'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
      'detail', public.clip_text(public.rule_notice('card_notice_guest'), 140),
      'more', v_more);
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'block_code') is not null or (d ->> 'enforcement') = 'block' or (d ->> 'carrier_ok') = 'false'
       or coalesce((d ->> 'charter'),'false') = 'true' then
      v_can := false;
    else v_ack := true; end if;
  -- 310: sunucu kapısıyla AYNI — taşıyıcı uyuşmazlığında ön kontrol de "başvuramazsın" der.
  elsif (d ->> 'carrier_ok') = 'false' and (d ->> 'program_id') is not null
        and coalesce(d ->> 'entitlement_model', '') <> 'bank_card' then v_can := false;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;
  if v_qnote is not null or v_cnote is not null then v_ack := true; end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule', 'block_code', d ->> 'block_code',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
    'carrier_ok', d -> 'carrier_ok', 'host_tier_label', v_tier,
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit,
    /* 187-kredi: misafirin cebinden cikan TOPLAM. Ekranda tek
       kutuda gosterilmeli: escrow + aktarim. */
    'credit_hold', v_tut,
    'credit_total', v_tut + coalesce(v_credit, 0), 'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', public.clip_text(v_head, 70),
    'detail', v_detail,
    'more', v_more);
end $function$;

-- ── D) İç yardımcılar istemciye kapalı ─────────────────────────────────────
revoke execute on function public.best_access_for_user(p_user_id uuid, p_venue_id uuid, p_carrier text, p_flight text) from public, anon, authenticated;
grant execute on function public.best_access_for_user(p_user_id uuid, p_venue_id uuid, p_carrier text, p_flight text) to service_role;
revoke execute on function public.card_confidence_note(p_user_id uuid) from public, anon, authenticated;
grant execute on function public.card_confidence_note(p_user_id uuid) to service_role;
revoke execute on function public.card_self_check(p_user_id uuid) from public, anon, authenticated;
grant execute on function public.card_self_check(p_user_id uuid) to service_role;
revoke execute on function public.entry_window_relevant(p_avail_id uuid, p_user_id uuid) from public, anon, authenticated;
grant execute on function public.entry_window_relevant(p_avail_id uuid, p_user_id uuid) to service_role;
revoke execute on function public.etkin_plan(p_user uuid) from public, anon, authenticated;
grant execute on function public.etkin_plan(p_user uuid) to service_role;
revoke execute on function public.guest_quota_note(p_host_id uuid) from public, anon, authenticated;
grant execute on function public.guest_quota_note(p_host_id uuid) to service_role;
revoke execute on function public.hesap_kapisi(p_uid uuid) from public, anon, authenticated;
grant execute on function public.hesap_kapisi(p_uid uuid) to service_role;
revoke execute on function public.host_declares_paid_guest(p_host uuid) from public, anon, authenticated;
grant execute on function public.host_declares_paid_guest(p_host uuid) to service_role;
revoke execute on function public.host_feature_hours(p_host uuid) from public, anon, authenticated;
grant execute on function public.host_feature_hours(p_host uuid) to service_role;
revoke execute on function public.host_rank_bonus(p_host uuid) from public, anon, authenticated;
grant execute on function public.host_rank_bonus(p_host uuid) to service_role;
revoke execute on function public.is_contact_verified(p_user uuid) from public, anon, authenticated;
grant execute on function public.is_contact_verified(p_user uuid) to service_role;
revoke execute on function public.kesin_ulasilamaz(p_user uuid) from public, anon, authenticated;
grant execute on function public.kesin_ulasilamaz(p_user uuid) to service_role;
revoke execute on function public.lounge_access_decision_v6(p_avail_id uuid, p_guest_flight text, p_guest_carrier text, p_guest_visit_id uuid) from public, anon, authenticated;
grant execute on function public.lounge_access_decision_v6(p_avail_id uuid, p_guest_flight text, p_guest_carrier text, p_guest_visit_id uuid) to service_role;
revoke execute on function public.partner_gate(p_user uuid, p_lounge uuid) from public, anon, authenticated;
grant execute on function public.partner_gate(p_user uuid, p_lounge uuid) to service_role;
revoke execute on function public.partner_gate_preflag(p_user uuid, p_lounge uuid) from public, anon, authenticated;
grant execute on function public.partner_gate_preflag(p_user uuid, p_lounge uuid) to service_role;
revoke execute on function public.partner_lounges(p_user uuid) from public, anon, authenticated;
grant execute on function public.partner_lounges(p_user uuid) to service_role;
revoke execute on function public.pick_host_program(p_host uuid, p_venue_id uuid) from public, anon, authenticated;
grant execute on function public.pick_host_program(p_host uuid, p_venue_id uuid) to service_role;
revoke execute on function public.request_credit_cost(p_user uuid, p_avail uuid) from public, anon, authenticated;
grant execute on function public.request_credit_cost(p_user uuid, p_avail uuid) to service_role;
revoke execute on function public.request_credit_cost_ham(p_user uuid, p_avail uuid) from public, anon, authenticated;
grant execute on function public.request_credit_cost_ham(p_user uuid, p_avail uuid) to service_role;
revoke execute on function public.ulasilabilir_mi(p_user uuid) from public, anon, authenticated;
grant execute on function public.ulasilabilir_mi(p_user uuid) to service_role;
revoke execute on function public.verification_state(p_user uuid) from public, anon, authenticated;
grant execute on function public.verification_state(p_user uuid) to service_role;

-- ── E) Profil fotoğrafı klasörü başkasına listelenmez ──────────────────────
-- Kova herkese açık (fotoğraf URL'si yetkili görüntüleyene RPC'den gelir); ama "avatars_read"
-- politikası HERKESİN her klasörü LİSTELEMESİNE izin veriyordu → 6.2.5'in rastgele dosya adı
-- listeyle bulunabilirdi. Açık kovada /object/public/ adresi RLS'e bakmaz; mevcut fotoğraflar
-- görünmeye devam eder. Listeleme/indirme artık yalnız sahibine.
drop policy if exists "avatars_read" on storage.objects;
drop policy if exists "avatars_own_read" on storage.objects;
create policy "avatars_own_read" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ── Doğrulama ───────────────────────────────────────────────────────────────
do $$
declare v_acik int; v_saw int; v_mz int;
begin
  select count(*) into v_acik from pg_proc
   where pronamespace = 'public'::regnamespace
     and proname = any(array['best_access_for_user','card_confidence_note','card_self_check','entry_window_relevant','etkin_plan','guest_quota_note','hesap_kapisi','host_declares_paid_guest','host_feature_hours','host_rank_bonus','is_contact_verified','kesin_ulasilamaz','lounge_access_decision_v6','partner_gate','partner_gate_preflag','partner_lounges','pick_host_program','request_credit_cost','request_credit_cost_ham','ulasilabilir_mi','verification_state'])
     and has_function_privilege('authenticated', oid, 'EXECUTE');
  select count(*) into v_saw from lounges l join lounge_venues v on v.id = l.venue_id
   where v.airport_code = 'SAW' and v.name = 'Turkish Airlines CIP Lounge — İç Hat' and l.active;
  select count(*) into v_mz from lounge_venue_acceptance where conditions like 'Miles&Smiles statüsü bu salonda geçmez%';
  raise notice '310: iç yardımcı istemciye açık=% (beklenen 0) · SAW THY CIP seçicide=% (beklenen 1) · "geçmez" satırı=% (beklenen 0)',
    v_acik, v_saw, v_mz;
end $$;
