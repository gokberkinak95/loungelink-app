-- ============================================================================
-- 320 · İSTEK GÖNDERİMİ: EŞLEŞME PUANI DARALTILMIŞ OKUNUR  (4 Ekim 2026)
--
-- ÖLÇÜM (yük testi · ll_yuk): create_request başarılı çağrı 350-530 ms; bunun
-- ~430 ms'si create_request_impl_preflag'in kayıt için eşleşme puanını almak
-- üzere havalimanının bütün keşif listesini (discover_availabilities: erişim
-- kararı katmanı dahil, 9.600 karar çağrısı / 12 istek) kurmasıydı.
-- 🔴 DOĞRULUK: liste 100 ilanla sınırlı → hedef ilan ilk 100'de değilse
-- requests.match_score SESSİZCE 40 (varsayılan) yazılıyordu.
-- DÜZELTME: base (aynı puan formülü), havalimanı + tarih ile daraltılmış, sınırsız.
-- EK: discover_availabilities_prerank'te erişim kararı ilan başına 8 kez koşuyordu
--     (satır içine alınan CTE) → `as materialized` ile bir kez.
-- Gövde CANLI tanımın üstüne eklendi. Supabase SQL Editor: tekrar koşulabilir.
-- ÖNKOŞUL: 317 (ll.kesif_limit desteği).
-- ============================================================================

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
end $function$;

-- ── KEŞFET: erişim kararı ilan başına BİR kez ─────────────────────────────
CREATE OR REPLACE FUNCTION public.discover_availabilities_prerank(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text, host_gender text, host_langs text[], guest_policy text, guest_allowance integer, family_allowed boolean, decision_note text, blocks_request boolean, block_reason text, carrier_note text, same_sector boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_prof text;
begin
  select lower(btrim(p.profession)) into v_prof
    from profiles p where p.user_id = v_uid;

  return query
  with base as (
    select d.* from public.discover_availabilities_base(p_airport, p_sector, p_flight, p_date) d
  -- 320 · MATERIALIZED: CTE tek yerde kullanıldığı için planlayıcı onu satır içine
  -- alıyor ve `e.dec ->> …` her geçtiğinde (8 yer) lounge_access_decision YENİDEN
  -- koşuyordu — ilan başına 8 karar. Ölçüldü: 100 ilan → 800 karar çağrısı.
  ), enriched as materialized (
    select b.*,
           public.lounge_access_decision(b.id, b.flight_number) as dec,
           (select a.carrier from availabilities a where a.id = b.id) as av_carrier,
           -- 🔴 195: TAŞIYICI ARTIK ÖNBELLEKTEN. Eskiden yalnız uçuş
           -- numarasının öneki okunuyordu; kod paylaşımlı uçuşta bu
           -- YANLIŞ havayolunu verir ve kullanıcı "aynı havayolundayız"
           -- sanıp kapıda geri çevrilir.
           (select public.flight_carrier_resolve(v.flight_number, v.visit_date) ->> 'carrier'
              from visits v
             where v.user_id = v_uid and v.airport_code = b.airport_code
               and v.visit_date = b.avail_date
               and coalesce(v.flight_number,'') <> ''
             limit 1) as my_carrier
      from base b
  )
  select e.id, e.host_id, e.airport_code, e.lounge_name, e.avail_date,
         e.time_from, e.time_to, e.flight_number, e.slots, e.filled,
         e.host_name, e.host_badge, e.host_score, e.host_profession,
         e.host_photo, e.match_score, e.same_flight, e.has_trip,
         e.is_featured, e.fully_booked, e.visibility,
         e.host_gender, e.host_langs,
         coalesce(e.dec ->> 'guest_policy', 'unknown'),
         coalesce((e.dec ->> 'guest_allowance')::int, 0),
         coalesce((e.dec ->> 'family_allowed')::boolean, false),
         nullif(e.dec ->> 'headline', ''),
         coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots)
           or (coalesce(e.dec ->> 'guest_policy','') = 'not_allowed')
           or (coalesce(e.dec ->> 'severity','') = 'block'),
         case
           when coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots) then 'fully_booked'
           when coalesce(e.dec ->> 'guest_policy','') = 'not_allowed' then 'guests_not_allowed'
           when coalesce(e.dec ->> 'severity','') = 'block' then 'blocked_by_rule'
           else null end,
         case
           when e.av_carrier is null or e.my_carrier is null then null
           when e.av_carrier = e.my_carrier then null
           when e.av_carrier in ('TK') and e.my_carrier in ('VF','AJ')
             then 'Bu ilan THY seferinde; senin biletin AJet. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           when e.av_carrier in ('VF','AJ') and e.my_carrier = 'TK'
             then 'Bu ilan AJet seferinde; senin biletin THY. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           else null end,
         -- 🔴 195: AYNI SEKTÖR. "Bilmiyorum" ile "hayır" ayrılır:
         -- iki taraftan biri mesleğini yazmamışsa NULL döner (rozet
         -- gösterilmez), false demek "farklı sektör" demektir.
         case
           when v_prof is null or v_prof = '' then null
           when e.host_profession is null or btrim(e.host_profession) = '' then null
           else lower(btrim(e.host_profession)) = v_prof
                or lower(btrim(e.host_profession)) like '%' || v_prof || '%'
                or v_prof like '%' || lower(btrim(e.host_profession)) || '%'
         end
    from enriched e;
end $function$;

select 'preflag daraltilmis puan' as kontrol,
       position('320 · Eşleşme puanı' in pg_get_functiondef('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure)) > 0 as tamam
union all
select 'kesif karari bir kez',
       position('enriched as materialized' in pg_get_functiondef('public.discover_availabilities_prerank(text,text,text,date)'::regprocedure)) > 0;
-- Beklenen: iki satır da tamam = true.
