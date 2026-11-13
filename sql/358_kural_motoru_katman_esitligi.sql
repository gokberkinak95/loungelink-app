-- ============================================================================
-- 358 · KURAL MOTORU: EKRAN, ÖN KONTROL VE SUNUCU AYNI KARARI VERSİN  (13 Kasım 2026)
--
-- ÖLÇÜM (render_check/kural_motoru_tam_e2e.py · tam SEED dünyası · 3 misafir × 74 ilan ×
-- 10 seyahat varyantı = 2.960 kombinasyon). Resmî tablolardan üretilen 480 vakanın hepsi
-- doğru; ama katmanlar arasında üç tutarsızlık bulundu:
--
--   K1 · SUNUCU ÖN KONTROLDEN GEVŞEK (24 kombinasyon): ön kontrol "kesin kural" (enforcement=
--        block) ve charter durumunda "başvuramazsın" diyor, sunucu bunları sormuyordu. Örnek:
--        yalnız TK seferindeki misafiri alan M&S salonuna Pegasus yolcusu — uygulama engelliyor,
--        doğrudan API çağrısı geçiyordu. Ayrıca taşıyıcı çözümü farklıydı (sunucu yalnız
--        carrier_code, ön kontrol uçuş numarasından da çıkarıyor) ve ön kontrol seyahati saat
--        çakışmasına bakmadan seçiyordu.
--   K2 · KART İYİMSER (390): rozet (discovery_rule_badges) eski motorla (v5) karar veriyordu;
--        kişi sayısı, iç/dış hat, çocuk, kota, kabin boyutları karta yansımıyordu → kart
--        "İstek gönder" açık, gönderme ekranında red.
--   K3 · GÖRÜNMEYEN İLANA İSTEK (84): Keşfet host rolü/onaylı başvuru, gölge kısıt, kadın
--        güvenlik modu, gizli/bağlantılara özel ilanı süzüyor; sunucu bunları sormuyordu.
--
-- DÜZELTME (APP SÜRÜMÜ GEREKMEZ — uygulama bu alanları zaten okuyor):
--   §1 ilan_misafire_acik_mi(ilan, misafir): Keşfet'in host/ilan süzgecinin AYNISI.
--   §2 create_request_impl_preflag: §1 kapısı + enforcement/charter kapısı + aynı taşıyıcı çözümü.
--   §3 request_precheck_pregate: §1 kapısı + seyahat seçimi sunucuyla aynı (saat çakışması).
--   §4 discovery_rule_badges: v6 + aynı seyahat; seyahate bağlı kesin engel kartı da kapatır.
--   §5 rozet metinleri (yeni anahtarlar; mevcutlara dokunulmaz).
--   §6 kural_kosullari: aynı seyahat seçimi + kesin uçuş kuralında satır 'yok' (eskiden 'bilinmiyor').
--   Yeni hata kodu YOK (charter/kesin kural → guests_not_allowed / guest_carrier_mismatch).
--
-- KOŞMA: SQL Editor → tamamı → Run. Tekrar koşulabilir. Son tablo: hepsi tamam = true.
-- ============================================================================

-- §1 · Keşfet ile aynı görünürlük süzgeci (ilan bu misafire açık mı?)
create or replace function public.ilan_misafire_acik_mi(p_av uuid, p_guest uuid)
returns boolean language sql stable security definer set search_path = public as $ia358$
  select exists (
    select 1
      from availabilities a
      join users hu on hu.id = a.host_id
      left join profiles p on p.user_id = a.host_id
     where a.id = p_av
       and hu.banned_at is null and hu.deleted_at is null
       and (hu.role = 'host'
            or exists (select 1 from host_applications ha where ha.user_id = a.host_id and ha.status = 'approved'))
       and (not coalesce(hu.is_staff, false)
            or coalesce((select x.is_staff from users x where x.id = p_guest), false))
       and not coalesce(hu.shadow_limited and (hu.restricted_until is null or hu.restricted_until > now()), false)
       and (not coalesce(p.women_safety_mode, false)
            or (coalesce((select g.gender = 'female' from users g where g.id = p_guest), false)
                and exists (select 1 from verifications vv where vv.user_id = p_guest and vv.phone_verified))
            or exists (select 1 from connection_requests c9 where c9.from_id = a.host_id and c9.to_id = p_guest)
            or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                        where r9.guest_id = a.host_id and a9.host_id = p_guest)
            or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = p_guest))
       and coalesce(a.visibility::text, 'Public') <> 'Hidden'
       and (coalesce(a.visibility::text, 'Public') <> 'Connections'
            or exists (select 1 from connection_requests cr where cr.status = 'accepted'
                        and ((cr.from_id = p_guest and cr.to_id = a.host_id)
                          or (cr.from_id = a.host_id and cr.to_id = p_guest)))));
$ia358$;
revoke all on function public.ilan_misafire_acik_mi(uuid, uuid) from public, anon, authenticated;
grant execute on function public.ilan_misafire_acik_mi(uuid, uuid) to service_role;

-- §2 · sunucu kapısı
CREATE OR REPLACE FUNCTION public.create_request_impl_preflag(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $cr358$
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
  -- 358 · (engel kontrolünden SONRA: engelli çift kendi sebebini görür) Keşfet'te bu misafire görünmeyen ilana istek yok (host rolü, gölge kısıt,
  -- kadın güvenlik modu, gizli / yalnız bağlantılara açık ilan). Keşfet ile AYNI süzgeç.
  if not public.ilan_misafire_acik_mi(p_avail_id, v_uid) then raise exception 'availability_not_found'; end if;

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
      select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number)), v.id   -- 358: ön kontrolle aynı taşıyıcı çözümü
        into v_gf, v_gc, v_gvid
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
    -- 358 · ÖN KONTROLLE AYNI KAPI: kesin kural (enforcement=block) ya da charter sefer.
    -- Eskiden yalnız ön kontrol soruyordu: uygulama engelliyor, doğrudan çağrı geçiyordu
    -- (ör. yalnız TK seferindeki misafiri alan salona Pegasus yolcusunun isteği).
    if (v_dec ->> 'severity') = 'block'
       and ((v_dec ->> 'enforcement') = 'block' or coalesce(v_dec ->> 'charter', 'false') = 'true') then
      raise exception '%', case when coalesce(v_dec ->> 'charter', 'false') <> 'true' and (v_dec ->> 'fits') = 'false'
                                then 'guest_carrier_mismatch' else 'guests_not_allowed' end;
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

  -- 320 · Eşleşme puanı yalnız KAYIT için okunuyor. Eskiden havalimanının TÜM
  -- keşif listesi (erişim kararı katmanıyla, ilan başına ~8 karar) kuruluyordu:
  -- ölçek dünyasında istek başına ~430 ms; ve liste 100 ilanla sınırlı olduğu için
  -- hedef ilk 100'de değilse puan SESSİZCE 40 yazılıyordu. Prerank puanı değiştirmez
  -- (base'ten aynen geçer) → base, havalimanı + TARİH ile daraltılmış, sınırsız.
  -- (100000 = sınır kalksın ama sayım kipi (>100000) açılmasın.)
  perform set_config('ll.kesif_limit', '100000', true);
  select match_score into v_score
    from discover_availabilities_base(v_av.airport_code, null, null, v_av.avail_date)
   where id = p_avail_id limit 1;
  perform set_config('ll.kesif_limit', '', true);

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

  perform public.bildir(v_av.host_id, 'requests',
    public.kisa_ad(v_uid) || ' ilanına başvurdu ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || ' — kabul ya da reddet; yanıt bekleyen istekler İstek ekranında.',
    public.kisa_ad(v_uid) || ' applied to your listing ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || ' — accept or decline in Requests.',
    'request', v_req_id); -- 313_bildirim

  return jsonb_build_object('ok', true, 'id', v_req_id, 'kredi_bedeli', v_cost);
end $cr358$;

-- §3 · ön kontrol (gönderme ekranı)
CREATE OR REPLACE FUNCTION public.request_precheck_pregate(p_avail_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $pc358$

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
         and v.visit_date  = a2.avail_date
         -- 358 · sunucu kapısıyla AYNI: saatler de çakışmalı (no_matching_trip)
         and v.time_from < a2.time_to and a2.time_from < v.time_to)

  then

    return jsonb_build_object(

      'can_request', false, 'kind', 'trip_gate', 'severity', 'block',

      'headline', 'Bu ilanın saatinde o havalimanında seyahatin yok',

      'detail', 'Bu ilan ' || (select to_char(a3.avail_date, 'DD.MM.YYYY')

                    || ' tarihinde ' || a3.airport_code

                    from availabilities a3 where a3.id = p_avail_id)

                 || '. O gün için bir seyahat ekle, ilan hemen başvurulabilir olsun.',

      'fix_action', 'add_trip',

      'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);

  end if;



  select * into v_av from availabilities where id = p_avail_id;

  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;
  -- 358 · sunucu kapısıyla AYNI görünürlük süzgeci
  if not public.ilan_misafire_acik_mi(p_avail_id, v_uid) then
    return jsonb_build_object('can_request', false, 'gate', 'availability_not_found', 'kind', 'gate',
                              'severity', 'block', 'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);
  end if;



  select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))

    into v_flight, v_carrier

    from visits v

   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and v.time_from < v_av.time_to and v_av.time_from < v.time_to   -- 358: sunucuyla aynı seyahat
   order by (v.flight_number is not null) desc, v.created_at desc limit 1;



  d := public.lounge_access_decision_v6(p_avail_id, v_flight, v_carrier,

         (select v.id from visits v where v.user_id = v_uid and v.airport_code = v_av.airport_code and v.visit_date = v_av.avail_date and v.time_from < v_av.time_to and v_av.time_from < v.time_to order by (v.flight_number is not null) desc, v.created_at desc limit 1));   -- 283

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

end $pc358$;

-- §4 · Keşfet rozeti (kartın İstek gönder kararı)
CREATE OR REPLACE FUNCTION public.discovery_rule_badges(p_ids uuid[])
 RETURNS TABLE(avail_id uuid, severity text, label text, info text, detail text, same_flight_match boolean, blocks_request boolean, sort_boost integer, can_ask_host boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $bd358$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text;
  v_boost int; v_same boolean; v_block boolean; v_prog lounge_programs%rowtype;
  v_carrier text; v_vid uuid; v_kod text;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    -- 358 · rozet SUNUCUNUN kararıyla aynı: v6 + ilanla saatleri çakışan seyahat (kişi sayısı,
    -- hat, çocuk, kota, kabin, kalış dahil). Eskiden v5'ti: kart "İstek gönder" der, sunucu reddederdi.
    v_flight := null; v_carrier := null; v_vid := null;
    select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number)), v.id
      into v_flight, v_carrier, v_vid
      from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date
       and v.time_from < r.time_to and r.time_from < v.time_to
     order by (v.flight_number is not null) desc, v.created_at desc limit 1;

    d := public.lounge_access_decision_v6(avail_id, v_flight, coalesce(v_carrier, public.guest_carrier_for(avail_id)), v_vid);
    select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_block := coalesce((d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block', false)
               or coalesce((d ->> 'carrier_ok') = 'false', false)
               or coalesce((d ->> 'charter') = 'true', false);
    if v_prog.id is null or v_prog.entitlement_model = 'bank_card' then
      v_block := false;
    end if;

    -- 358 · seyahate bağlı kesin engel (sunucu da reddeder): kart da kapalı
    v_kod := d ->> 'block_code';
    if v_kod is not null then v_block := true; end if;

    v_boost := 0;
    -- 304: engelin SEBEBİ ayrı anahtar — farklı havayolu "misafir hakkı yok" değildir.
    if v_kod is not null then
      v_key := case v_kod when 'scope_mismatch' then 'rule_scope' when 'party_too_big' then 'rule_party'
                          when 'children_not_allowed' then 'rule_child' when 'quota_exhausted' then 'rule_quota'
                          when 'cabin_required' then 'rule_cabin' else 'flight_bad' end;
      v_boost := -1000;
    elsif v_block and coalesce((d ->> 'carrier_ok') = 'false', false) then
                                                     v_key := 'carrier_bad';   v_boost := -1000;
    elsif v_block and coalesce((d ->> 'charter') = 'true', false) then
                                                     v_key := 'charter_block'; v_boost := -1000;
    elsif v_block then                               v_key := 'guest_none';  v_boost := -1000;
    elsif v_same then                                v_key := 'same_flight'; v_boost := 100;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_key := 'guest_none_soft'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
    end if;

    -- 219 kapı hizası korunuyor
    if (d ->> 'guest_policy') = 'not_allowed' then
      v_block := true;
    end if;

    b := case when v_key is null then null else public.badge_text(v_key) end;

    severity := coalesce(d ->> 'severity','info');
    label    := b ->> 'label';
    info     := b ->> 'info';
    detail   := d ->> 'headline';
    same_flight_match := v_same;
    blocks_request := v_block;
    sort_boost := v_boost;
    can_ask_host := public.kural_sorusu_uygun_mu(avail_id);
    return next;
  end loop;
end $bd358$;

-- §6 · kural satırları (salon kuralları ekranı): aynı seyahat + kesin uçuş kuralı 'yok' olarak
CREATE OR REPLACE FUNCTION public.kural_kosullari(p_avail_id uuid)
 RETURNS TABLE(sira integer, kod text, metin text, durum text, agirlik text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $kk358$
declare
  d jsonb; v_av availabilities%rowtype; v_vis visits%rowtype; v_prog lounge_programs%rowtype;
  v_flight text; v_uyum boolean; v_n int; v_i int := 0;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return; end if;

  -- Misafirin ilanla çakışan seyahati (uçuşlu olan önce)
  select * into v_vis from visits v
   where v.user_id = auth.uid() and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and v.time_from < v_av.time_to and v_av.time_from < v.time_to   -- 358: sunucuyla aynı seyahat
   order by (v.flight_number is not null) desc, v.created_at desc
   limit 1;
  v_flight := nullif(v_vis.flight_number, '');

  d := public.lounge_access_decision_v6(p_avail_id, v_flight,
         coalesce(v_vis.carrier_code, public.carrier_from_flight(v_vis.flight_number), public.guest_carrier_for(p_avail_id)), v_vis.id);   -- 358
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

  -- ── KAPI SATIRLARI ────────────────────────────────────────────
  -- 1 · misafir hakkı
  v_n := nullif(d ->> 'guest_included_count','')::int;
  v_i := v_i + 1; sira := v_i; kod := 'misafir_hakki'; agirlik := 'kapi';
  if (d ->> 'guest_policy') = 'included' then
    durum := 'ok';
    metin := case when coalesce(v_n,0) > 0 then format('Misafir hakkı var · %s kişilik', v_n) else 'Misafir hakkı var' end;
  elsif (d ->> 'guest_policy') = 'paid' then
    durum := 'ok'; agirlik := 'not';
    metin := coalesce(nullif(d ->> 'guest_fee_note',''), 'Misafir ücretli girer');
  elsif (d ->> 'guest_policy') = 'not_allowed' then
    durum := 'yok'; metin := 'Bu kart misafir almıyor';
  else
    durum := 'bilinmiyor'; metin := 'Misafir hakkı doğrulanmadı';
  end if;
  return next;

  -- 2 · havayolu şartı
  v_i := v_i + 1; sira := v_i; kod := 'havayolu'; agirlik := 'kapi';
  -- 358 · kesin kural misafirin uçuşunu reddediyorsa (sunucu da reddeder) satır "bilinmiyor" değil "yok"
  if (d ->> 'fits') = 'false' and (d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block'
     and (d ->> 'block_code') is null then
    durum := 'yok';
    metin := format('Uçuşun bu salonun havayolu kuralına uymuyor · %s', coalesce(upper(v_flight), '?'));
  elsif coalesce(d ->> 'flight_coupling','any') in ('any','none') and (d ->> 'carrier_known') is null then
    durum := 'ok'; agirlik := 'not'; metin := 'Havayolu şartı yok';
  elsif (d ->> 'carrier_known') is null or (d ->> 'carrier_known') = 'false' then
    durum := 'bilinmiyor'; metin := 'Havayolu şartı bilinmiyor · uçuşunu gir';
  elsif (d ->> 'carrier_ok') = 'true' then
    durum := 'ok';
    metin := case when coalesce(d ->> 'host_carrier','') <> ''
                  then format('Aynı havayolu · %s', upper(d ->> 'host_carrier')) else 'Havayolu şartı sağlanıyor' end;
  else
    durum := 'yok';
    metin := format('Havayolu şartı tutmuyor · %s ↔ %s', upper(coalesce(d ->> 'host_carrier','?')), upper(coalesce(d ->> 'guest_carrier','?')));
  end if;
  return next;

  -- 3 · uçuş bağı
  v_i := v_i + 1; sira := v_i; kod := 'ucus_bagi'; agirlik := 'kapi';
  if coalesce(d ->> 'flight_coupling','none') in ('none','any') then
    durum := 'ok'; agirlik := 'not'; metin := 'Uçuş birlikteliği şartı yok';
  else
    v_uyum := coalesce(v_flight,'') <> '' and coalesce(v_av.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(v_av.flight_number,' ',''));
    if (d ->> 'flight_coupling') = 'same_flight' then
      durum := case when v_uyum then 'ok' when coalesce(v_flight,'') = '' then 'bilinmiyor' else 'yok' end;
      metin := case when v_uyum then 'Aynı uçuş şartı sağlanıyor'
                    when coalesce(v_flight,'') = '' then 'Aynı uçuş şartı var · uçuşunu gir'
                    else 'Aynı uçuş şartı sağlanmıyor' end;
    else
      durum := 'bilinmiyor'; metin := 'Birlikte varış gerekir · kapıda beraber olun';
    end if;
  end if;
  return next;

  -- 4 · kişi sayısı (283/1)
  v_i := v_i + 1; sira := v_i; kod := 'kisi_sayisi'; agirlik := 'kapi';
  if (d ->> 'party_ok') = 'true' then
    durum := 'ok';
    metin := case when (d ->> 'party_size')::int > 1
                  then format('%s kişi · hak yetiyor', d ->> 'party_size') else 'Tek kişi · hak yetiyor' end;
  elsif (d ->> 'party_ok') = 'false' then
    durum := 'yok'; metin := format('%s kişisin, hak %s kişilik', d ->> 'party_size', d ->> 'party_limit');
  else
    durum := 'bilinmiyor'; metin := 'Kişi sayısı şartı doğrulanamadı';
  end if;
  return next;

  -- 5 · iç hat / dış hat (283/7)
  v_i := v_i + 1; sira := v_i; kod := 'hat'; agirlik := 'kapi';
  if (d ->> 'scope_ok') = 'true' then
    durum := 'ok'; agirlik := 'not';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'İç hatlar salonu · uçuşun iç hat'
                                         when 'international' then 'Dış hatlar salonu · uçuşun dış hat'
                                         else 'Salon her iki hatta da açık' end;
  elsif (d ->> 'scope_ok') = 'false' then
    durum := 'yok';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'Salon iç hatta, uçuşun dış hat' else 'Salon dış hatta, uçuşun iç hat' end;
  else
    durum := 'bilinmiyor';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'İç hatlar salonu · varış noktanı gir'
                                         else 'Dış hatlar salonu · varış noktanı gir' end;
  end if;
  return next;

  -- 6 · host kotası (283/12) — yalnız biliniyorsa
  if coalesce((d #>> '{quota,known}')::boolean, false) then
    v_i := v_i + 1; sira := v_i; kod := 'host_kotasi'; agirlik := 'kapi';
    if (d ->> 'quota_ok') = 'true' then
      durum := 'ok'; metin := format('Host''un bu dönem %s hakkı kaldı', d #>> '{quota,left}');
    else
      durum := 'yok'; metin := format('Host''un dönem hakkı bitmiş · %s/%s', d #>> '{quota,used}', d #>> '{quota,total}');
    end if;
    return next;
  end if;

  -- 7 · bilet sınıfı (283/11) — yalnız bilet sınıfı programında
  if (d ->> 'cabin_required') = 'true' then
    v_i := v_i + 1; sira := v_i; kod := 'bilet_sinifi'; agirlik := 'kapi';
    if (d ->> 'cabin_ok') = 'true' then durum := 'ok'; metin := format('Host %s uçuyor · hak geçerli', upper(d ->> 'host_cabin'));
    elsif (d ->> 'cabin_ok') = 'false' then durum := 'yok'; metin := 'Host ekonomi uçuyor · bilet sınıfı hakkı yok';
    else durum := 'bilinmiyor'; metin := 'Host''un kabin sınıfı bilinmiyor'; end if;
    return next;
  end if;

  -- 8 · çocuk (283/2) — yalnız çocuk varsa
  if (d ->> 'has_child') = 'true' then
    v_i := v_i + 1; sira := v_i; kod := 'cocuk'; agirlik := 'kapi';
    if (d ->> 'children_ok') = 'true' then
      durum := 'ok';
      metin := case when (d ->> 'children_policy') = 'free_under'
                    then format('%s yaş altı haktan sayılmıyor', d ->> 'child_age_limit') else 'Çocuk misafir kabul ediliyor' end;
    elsif (d ->> 'children_ok') = 'false' then
      durum := 'yok';
      metin := case when (d ->> 'children_policy') = 'age_limit'
                    then format('%s yaş altı alınmıyor', d ->> 'child_age_limit') else 'Salon çocuk misafir almıyor' end;
    else durum := 'bilinmiyor'; metin := 'Çocuk kuralı doğrulanmadı · kapıda sor'; end if;
    return next;
  end if;

  -- 9 · varış salonu (283/8) — yalnız salon tek yönlüyse
  if (d ->> 'serves') in ('arrival') then
    v_i := v_i + 1; sira := v_i; kod := 'varis_salonu'; agirlik := 'kapi';
    if (d ->> 'serves_ok') = 'true' then durum := 'ok'; metin := 'Varış salonu · aktarma yolcususun';
    else durum := 'yok'; metin := 'Varış salonu · kalkış öncesi giriş yok'; end if;
    return next;
  end if;

  -- 10 · host yanında (283/9)
  if v_prog.id is not null and coalesce(v_prog.member_must_be_present, false) then
    v_i := v_i + 1; sira := v_i; kod := 'host_yaninda'; agirlik := 'kapi'; durum := 'ok';
    metin := 'Host giriş anında yanında olmalı';
    return next;
  end if;

  -- ── NOTLAR ────────────────────────────────────────────────────
  -- 11 · aynı gün + biniş kartı (283/10)
  v_i := v_i + 1; sira := v_i; kod := 'binis_karti'; agirlik := 'not';
  if (d ->> 'boarding_pass_ok') = 'true' then durum := 'ok'; metin := format('Biniş kartın aynı gün · %s', upper(v_flight));
  elsif (d ->> 'boarding_pass_ok') = 'false' then durum := 'yok'; metin := 'Biniş kartının tarihi ilanla uyuşmuyor';
  else durum := 'yok'; metin := 'Uçuş numarası doğrulanmadı'; end if;
  return next;

  -- 12 · ücret (283/5) — yalnız ücretli politikada
  if (d ->> 'guest_policy') = 'paid' then
    v_i := v_i + 1; sira := v_i; kod := 'ucret'; agirlik := 'not';
    if (d ->> 'fee_payer') = 'member_card' then durum := 'ok'; metin := 'Ücreti host''un kartı karşılıyor';
    elsif (d ->> 'fee_payer') = 'guest_at_door' then
      durum := 'ok';
      metin := case when nullif(d ->> 'guest_fee_amount','') is not null
                    then format('Kapıda ödersin · ~%s %s', trim(to_char((d ->> 'guest_fee_amount')::numeric,'FM999990')), coalesce(d ->> 'guest_fee_currency',''))
                    else 'Ücreti kapıda misafir öder' end;
    else durum := 'bilinmiyor'; metin := 'Ücreti kimin ödediği doğrulanmadı'; end if;
    return next;
  end if;

  -- 13 · kalış süresi (283/6)
  if nullif(d ->> 'max_stay_hours','') is not null then
    v_i := v_i + 1; sira := v_i; kod := 'kalis'; agirlik := 'not';
    if (d ->> 'stay_ok') = 'false' then
      durum := 'yok'; metin := format('Kalış sınırı %s saat · planın %s saat',
                                       trim(to_char((d ->> 'max_stay_hours')::numeric,'FM990.0')),
                                       trim(to_char((d ->> 'planned_hours')::numeric,'FM990.0')));
    else
      durum := 'ok'; metin := format('Kalış sınırı %s saat', trim(to_char((d ->> 'max_stay_hours')::numeric,'FM990.0')));
    end if;
    return next;
  end if;

  -- 14 · doluluk (283/3) — yalnız kayıt varsa
  if coalesce((d ->> 'capacity_refusals_60d')::int, 0) > 0 then
    v_i := v_i + 1; sira := v_i; kod := 'doluluk'; agirlik := 'not';
    durum := case when (d ->> 'capacity_refusals_60d')::int >= 2 then 'yok' else 'ok' end;
    metin := format('Bu saatlerde %s kez doluluk reddi (60 gün)', d ->> 'capacity_refusals_60d');
    return next;
  end if;

  -- 15 · kabin (bilet sınıfı programı değilse yalnız not)
  if (d ->> 'cabin_required') <> 'true' and coalesce(v_av.cabin_class,'') <> '' then
    v_i := v_i + 1; sira := v_i; kod := 'kabin'; agirlik := 'not'; durum := 'ok';
    metin := format('Host kabini · %s', upper(v_av.cabin_class));
    return next;
  end if;

  -- 284 · kural güncelliği (not)
  if (d -> 'freshness') is not null then
    v_i := v_i + 1; sira := v_i; kod := 'guncellik'; agirlik := 'not';
    if (d #>> '{freshness,durum}') = 'supheli' then
      durum := 'yok'; metin := format('Kural kapıda %s kez tutmadı · doğrulanıyor', d #>> '{freshness,acik_suphe}');
    elsif (d #>> '{freshness,durum}') = 'dogrulandi' then
      durum := 'ok'; metin := case when (d #>> '{freshness,gun}') is null then 'Kural kapıda doğrulandı'
                                    else format('Kural %s gün önce doğrulandı', d #>> '{freshness,gun}') end;
    elsif (d #>> '{freshness,durum}') = 'eski' then
      durum := 'bilinmiyor'; metin := format('Kural %s gün önce doğrulandı · eskimiş olabilir', d #>> '{freshness,gun}');
    else durum := 'bilinmiyor'; metin := 'Kural henüz kapıda doğrulanmadı'; end if;
    return next;
  end if;

  -- 16 · biniş kartı & kimlik gerekli
  if v_prog.id is not null and coalesce(v_prog.guest_needs_boarding_pass, false) then
    v_i := v_i + 1; sira := v_i; kod := 'belge'; agirlik := 'not'; durum := 'ok';
    metin := 'Kendi biniş kartın ve kimliğin gerekir';
    return next;
  end if;
end $kk358$;

-- §5 · rozet metinleri: seyahate bağlı kesin engeller (mevcut anahtarlar korunur)
update beta_settings
   set value = jsonb_build_object(
         'rule_scope', jsonb_build_object('label', 'Hattın uymuyor',
            'info', 'Bu salon yalnız diğer hattın yolcularını alıyor. Seyahatindeki varış noktasını kontrol et.'),
         'rule_party', jsonb_build_object('label', 'Kişi sayısı fazla',
            'info', 'Host''un misafir hakkı seyahatindeki kişi sayısına yetmiyor.'),
         'rule_child', jsonb_build_object('label', 'Çocuk kuralı uymuyor',
            'info', 'Bu salon seyahatindeki çocukların yaşını kabul etmiyor.'),
         'rule_quota', jsonb_build_object('label', 'Host''un hakkı doldu',
            'info', 'Host''un bu dönemki misafir hakkı bitmiş.'),
         'rule_cabin', jsonb_build_object('label', 'Bilet sınıfı uymuyor',
            'info', 'Bu salon misafir girişini yalnız business ya da first bileti olan host''la kabul ediyor.')
       ) || value
 where key = 'badge_labels';

-- DOĞRULAMA
select 'gorunurluk suzgeci var' as kontrol,
       exists (select 1 from pg_proc where proname = 'ilan_misafire_acik_mi') as tamam
union all
select 'sunucu: gorunurluk + enforcement/charter kapisi',
       position('358 · ÖN KONTROLLE AYNI KAPI' in pg_get_functiondef('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure)) > 0
       and position('ilan_misafire_acik_mi' in pg_get_functiondef('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure)) > 0
union all
select 'on kontrol: ayni seyahat + gorunurluk',
       position('358: sunucuyla aynı seyahat' in pg_get_functiondef('public.request_precheck_pregate(uuid)'::regprocedure)) > 0
union all
select 'rozet: v6',
       position('lounge_access_decision_v6' in pg_get_functiondef('public.discovery_rule_badges(uuid[])'::regprocedure)) > 0
union all
select 'kural satirlari: ayni seyahat',
       position('358: sunucuyla aynı seyahat' in pg_get_functiondef('public.kural_kosullari(uuid)'::regprocedure)) > 0
union all
select 'rozet metinleri',
       (select value ? 'rule_party' and value ? 'rule_scope' from beta_settings where key = 'badge_labels');
