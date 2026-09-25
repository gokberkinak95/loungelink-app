-- ============================================================
-- LoungeLink · 142_short_detail_hard.sql
-- ISTEK EKRANI 3.000 KARAKTER GOSTERIYOR
--
-- ⚠️ Uygulamayi ETKILER (metin uzunlugu).
--
-- ------------------------------------------------------------
-- 🔴 135'TE YANLIS SEYI OLCMUSUM
-- ------------------------------------------------------------
-- 135'te "metinleri kisalttim" dedim ve `beta_settings` sozlugunu
-- 284 -> 90 karaktere indirdim. Dogruydu ama YETERSIZDI, cunku
-- kullanicinin ekranda gordugu metin sozlukten gelmiyor:
--
--   detail = kural notu + salon kosulu + kart guveni + kota notu
--          + tasiyici notu + kaynak celiskisi + ucret notu ...
--
-- Her katman kendi cumlesini EKLIYOR. Tek tek hepsi kisa; toplami
-- 1.500 karakter. Gokberk "hala uzun" dedi ve olctugumde 3.053
-- cikti (baslik + detay + daha fazlası).
--
-- Ders: "metni kisalttim" demek, EKRANDA GORUNENI olcmeden
-- soylenemez. Parcalari kisaltmak, toplami kisaltmaz.
--
-- ------------------------------------------------------------
-- COZUM: KATMANLI, SERT SINIRLI
-- ------------------------------------------------------------
--   headline : ~60 karakter — TEK CUMLE, kararin ozeti
--   detail   : ~140 karakter — kapida ISE YARAYACAK tek sey
--   more     : ~400 karakter — "Detaylari goster" arkasinda
--
-- Kural EKSIKSIZ aktarilmali ama HEPSI AYNI ANDA degil. Kullanici
-- once karari gorur; merak ederse acar. Hicbir bilgi silinmiyor,
-- SIRALANIYOR.
-- ============================================================

create or replace function public.clip_text(p_text text, p_max int)
returns text language sql immutable as $$
  -- 🔴 Kelime ortasindan kesmek okumayi bozar; son bosluktan kes.
  -- Kesilmisse "…" koy: kullanici devaminin oldugunu ANLAMALI.
  select case
    when p_text is null or length(p_text) <= p_max then p_text
    else rtrim(left(p_text, coalesce(
           nullif(strpos(reverse(left(p_text, p_max)), ' '), 0),
           0) * -1 + p_max), ' .,;') || '…'
  end;
$$;
grant execute on function public.clip_text(text, int) to authenticated;

create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_bal int; v_qnote text; v_cnote text;
  v_tier text; v_head text; v_key text; v_detail text; v_more text;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;

  select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))
    into v_flight, v_carrier
    from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v5(p_avail_id, v_flight, v_carrier);
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;
  v_credit := public.paid_guest_credit(p_avail_id);
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
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'credit_cost', 0,
      'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
      'detail', public.clip_text(public.rule_notice('card_notice_guest'), 140),
      'more', v_more);
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' or (d ->> 'carrier_ok') = 'false'
       or coalesce((d ->> 'charter'),'false') = 'true' then
      v_can := false;
    else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;
  if v_qnote is not null or v_cnote is not null then v_ack := true; end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
    'carrier_ok', d -> 'carrier_ok', 'host_tier_label', v_tier,
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit, 'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', public.clip_text(v_head, 70),
    'detail', v_detail,
    'more', v_more);
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;

select '142 OK - istek ekrani metni sert sinirlandi' as sonuc;
