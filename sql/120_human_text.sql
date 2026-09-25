-- ============================================================
-- LoungeLink · 120_human_text.sql
-- KULLANICI KOD OKUMAK ZORUNDA DEGIL
--
-- ⚠️ Uygulamayi ETKILER (metinler).
--
-- ------------------------------------------------------------
-- 🔴 "CLPL KARTI NE?" — GOKBERK HAKLI, BEN KOD GOSTERMISIM
-- ------------------------------------------------------------
-- Istek ekraninda basligim soyle cikiyordu:
--     "CLPL kartıyla misafir götüremezsin"
-- CLPL bizim VERITABANI KODUMUZ. Kullanici bunu bilmek zorunda degil,
-- bilmesi de gerekmiyor — kartinin uzerinde "Classic Plus" yaziyor.
-- Kendi ic kodumuzu kullaniciya gostermek, ona bizim veri modelimizi
-- ogrenme yuku bindirmektir.
--
-- ------------------------------------------------------------
-- 🔴 UYARI METNI COK UZUN
-- ------------------------------------------------------------
-- Detay alani her katmanin notunu ARKA ARKAYA ekliyordu: kural notu +
-- kota notu + kart guven notu + tasiyici notu + ucret notu. Sonuc
-- 400+ karakterlik bir duvar. Kullanici uzun metni OKUMAZ, atlar —
-- ve icinde gercekten onemli olan cumle de atlanmis olur.
--
-- Yeni yapi: BASLIK tek cumle, DETAY en fazla iki cumle, gerisi
-- rozete dokununca acilan aciklamada. Az soyleyip okunmak,
-- cok soyleyip atlanmaktan iyidir.
-- ============================================================

create or replace function public.card_tier_label(p_tier text)
returns text language sql immutable as $$
  select case upper(coalesce(p_tier,''))
    when 'ELPL'     then 'Elite Plus'
    when 'ELITE'    then 'Elite'
    when 'MS_EC'    then 'Elite Corporate'
    when 'CLPL'     then 'Classic Plus'
    when 'CLASSIC'  then 'Classic'
    when 'SAG'      then 'Star Alliance Gold'
    when 'PLM'      then 'Miles & More'
    when 'CORP'     then 'Corporate Club'
    when 'MS_US_CC' then 'Miles&Smiles ABD Kredi Kartı'
    when ''         then null
    else p_tier end;
$$;
grant execute on function public.card_tier_label(text) to authenticated;

-- Kisa ve insanca basliklar
insert into beta_settings (key, value) values
 ('head_tier_no_guest',  to_jsonb('{tier} kartında misafir hakkı yok'::text)),
 ('head_tier_paid',      to_jsonb('{tier} kartında misafir ücretli girer'::text)),
 ('head_carrier_bad',    to_jsonb('Farklı havayolu — bu salon aynı havayolunu istiyor'::text)),
 ('head_charter',        to_jsonb('Charter seferde salon hakkı yok'::text)),
 ('head_fee_member',     to_jsonb('Misafir girişi ücretli — host ödüyor'::text)),
 ('head_fee_door',       to_jsonb('Misafir girişi kapıda ücretli'::text)),
 ('head_unverified',     to_jsonb('Bu salonun kuralı doğrulanmadı'::text))
on conflict (key) do update set value = excluded.value;

-- 🔴 DETAYI KISALT: en fazla iki cumle, gerisi rozette.
create or replace function public.short_detail(p_parts text[], p_max int default 2)
returns text language sql immutable as $$
  -- Parcalari sirayla alir, ILK p_max cumleyi dondurur. Onem sirasi
  -- cagiran taraftadir: en kritik not basa yazilir.
  select nullif(trim(both ' ' from array_to_string(
           (select array_agg(x) from (
              select unnest(p_parts) as x limit p_max
            ) t where x is not null and trim(x) <> ''), ' ')), '');
$$;
grant execute on function public.short_detail(text[], int) to authenticated;

create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_bal int; v_qnote text; v_cnote text;
  v_tier text; v_head text; v_detail text; v_more text;
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

  -- 🔴 BASLIGI KOD DEGIL INSAN DILI KURAR.
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

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor', 'credit_cost', 0,
      'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
      'detail', public.short_detail(array[public.rule_notice('card_notice_guest')], 1),
      'more', public.short_detail(array[v_qnote, v_cnote], 3));
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

  -- En kritik not BASA: engel sebebi > ucret > kota > kart guveni
  v_detail := public.short_detail(array[d ->> 'detail'], 1);
  v_more   := public.short_detail(array[v_qnote, v_cnote, d ->> 'detail'], 4);

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
    'carrier_ok', d -> 'carrier_ok',
    'host_tier_label', v_tier,
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit, 'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', v_head,
    'detail', v_detail,
    'more', v_more);
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;

-- Host ipucu da kod degil ad gostersin
update lounge_guest_rules set notes = replace(notes, 'CLPL', 'Classic Plus')
 where notes like '%CLPL%';

select '120 OK - kod yerine kart adi, kisa baslik + detay, uzun metin rozette' as sonuc;
