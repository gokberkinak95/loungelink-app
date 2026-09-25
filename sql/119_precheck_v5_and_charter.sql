-- ============================================================
-- LoungeLink · 119_precheck_v5_and_charter.sql
-- KAPILAR v5'E BAGLANIYOR + CHARTER'IN KART AGI ISTISNASI
--
-- ⚠️ Uygulamayi ETKILER.
--
-- ------------------------------------------------------------
-- 🔴 GOKBERK'IN SORUSU: "charter ucusu olan biri LoungeKey /
--    PriorityPass / DragonPass ile lounge kullanabilir mi?"
-- ------------------------------------------------------------
-- EVET, KULLANABILIR. Ve bu ayrim onemli:
--
--   · THY/AJet charter yasagi HAVAYOLUNUN kuralidir: "charter seferde
--     bilet sinifi ne olursa olsun salon kullanim hakki yoktur."
--     Yani ucus HAKKI vermez.
--   · Priority Pass / LoungeKey / DragonPass ise UYELIGE dayanir.
--     Uyelik ucusa degil KISIYE baglidir; hangi seferle uctugun
--     onemli degil, gecerli bir binis kartin olmasi yeter.
--
-- Onceki halde charter'i KOSULSUZ engel yapmistim — kart agi
-- kaynakli bir ilani da blokluyordu. Bu, havayolunun kuralini
-- kart agina uygulamak demekti: yanlis kaynaktan yanlis sonuc.
--
-- Ayrica Gokberk cihazda "charter ucusu olan biri ilana basvurabildi"
-- dedi. Sebep: charter bayragi ILANDA (host'ta) tutuluyor, MISAFIRDE
-- degil. Misafirin charter olmasi da onemli — cunku misafir de o
-- salona girecek. Iki tarafi da soruyoruz artik.
-- ============================================================

alter table visits add column if not exists is_charter boolean;
comment on column visits.is_charter is
  'Misafirin seferi charter mi. THY/AJet salonlarinda charter yolcusu '
  'MISAFIR OLARAK da kabul edilmez; kart agi salonlarinda ONEMSIZDIR.';

create or replace function public.set_visit_charter(p_visit_id uuid, p_is_charter boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if (select user_id from visits where id = p_visit_id) <> auth.uid() then
    raise exception 'not_owner';
  end if;
  update visits set is_charter = p_is_charter where id = p_visit_id;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.set_visit_charter(uuid, boolean) to authenticated;

-- charter_note: KART AGI ISTISNASI
create or replace function public.charter_note(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a availabilities%rowtype; v_model text; v_guest_charter boolean;
begin
  select * into a from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('blocked', false, 'note', null); end if;

  select p.entitlement_model into v_model
    from lounge_venue_acceptance lva
    join lounge_programs p on p.id = lva.program_id
    join lounge_venues v on v.id = lva.venue_id
    left join lounges l on l.venue_id = v.id
   where l.id = a.lounge_id and lva.active
   order by coalesce(p.entitlement_model = 'airline_status', false) desc limit 1;

  select v.is_charter into v_guest_charter
    from visits v where v.user_id = auth.uid()
      and v.airport_code = a.airport_code and v.visit_date = a.avail_date
    order by v.created_at desc limit 1;

  -- 🔴 KART AGI / ISLETMECI SALONU: charter ONEMSIZ.
  -- Uyelik KISIYE baglidir, ucusa degil. Havayolunun charter yasagini
  -- buraya uygulamak, yanlis kaynaktan kural cikarmak olurdu.
  if v_model is not null and v_model <> 'airline_status' then
    if coalesce(a.is_charter,false) or coalesce(v_guest_charter,false) then
      return jsonb_build_object('blocked', false,
        'note', 'Seferlerden biri charter. Bu salona giris HAVAYOLU statusune degil '
             || 'UYELIGE bagli oldugu icin charter olmasi sorun degildir — gecerli '
             || 'binis karti yeterlidir.');
    end if;
    return jsonb_build_object('blocked', false, 'note', null);
  end if;

  -- Havayolu salonu: charter HAK VERMEZ (iki taraf icin de)
  if coalesce(a.is_charter,false) then
    return jsonb_build_object('blocked', true,
      'note', 'Host''un seferi CHARTER. Havayolu salonlarinda charter seferde bilet '
           || 'sinifi ya da statu karti ne olursa olsun salon kullanim hakki yoktur. '
           || 'Istisna: charter anlasmasi yapan acente yolcularina salon hakki satin '
           || 'almissa gecerlidir.');
  end if;
  if coalesce(v_guest_charter,false) then
    return jsonb_build_object('blocked', true,
      'note', 'SENIN seferin charter. Havayolu salonlarinda charter yolcusu misafir '
           || 'olarak da kabul edilmez. Kart agi (Priority Pass / LoungeKey / '
           || 'DragonPass) kaynakli bir ilan ararsan giris mumkun olabilir.');
  end if;
  if a.is_charter is null then
    return jsonb_build_object('blocked', false,
      'note', 'Seferin tarifeli mi charter mi belirtilmemis. Charter seferde havayolu '
           || 'salonu hakki olmaz — emin degilsen biletini kontrol et.');
  end if;
  return jsonb_build_object('blocked', false, 'note', null);
end $$;
grant execute on function public.charter_note(uuid) to authenticated;

-- request_precheck: v5 + tasiyici + charter
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_bal int; v_qnote text; v_cnote text;
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

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor', 'credit_cost', 0,
      'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',
      'detail', trim(both ' ' from public.rule_notice('card_notice_guest')
                  || ' ' || coalesce(v_qnote,'') || ' ' || coalesce(v_cnote,'')));
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' or (d ->> 'carrier_ok') = 'false'
       or (d -> 'charter')::text = 'true' then
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
    'carrier_ok', d -> 'carrier_ok',
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit, 'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', d ->> 'headline',
    'detail', trim(both ' ' from coalesce(d ->> 'detail','')
                || ' ' || coalesce(v_qnote,'') || ' ' || coalesce(v_cnote,'')));
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;

select '119 OK - charter kart aginda serbest, tasiyici precheck''te' as sonuc;
