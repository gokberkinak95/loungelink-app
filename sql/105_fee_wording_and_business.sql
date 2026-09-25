-- ============================================================
-- LoungeLink · 105_fee_wording_and_business.sql
-- GENISLETILMIS SENARYOLARIN CIKARDIGI UC KUSUR
--
-- ⚠️ Uygulamayi ETKILER (metin + veri). Sema degisikligi YOK.
--
-- 14 senaryoyu gercek PostgreSQL'de kosunca uc sey daha cikti.
-- Ikisi CELISKILI METIN, biri EKSIK MODEL.
--
-- ------------------------------------------------------------
-- 🔴 KUSUR 1: "ucretli" ile "hakkin yok" ayni cumleyle anlatiliyor
-- ------------------------------------------------------------
-- TK Classic'te durum sudur: kart sahibi salona UCRET ODEYEREK girer,
-- ama bu ODEME ONA MISAFIR HAKKI KAZANDIRMAZ. 104'te ekledigim baslik
-- her iki durumu da "X kartiyla misafir goturemezsin" diye yaziyordu;
-- oysa policy 'paid' donuyordu. Kullanici "ucretli" rozetiyle
-- "goturemezsin" cumlesini yan yana goruyordu.
--
-- Iki durum AYRI cumle ister:
--   guest_allowance = 0 ve paid_entry YOK   -> misafir GIREMEZ
--   guest_allowance = 0 ama paid_entry VAR  -> misafir ucret odeyip girer
--
-- ------------------------------------------------------------
-- 🔴 KUSUR 2: KAYNAKSIZ UCRET RAKAMI
-- ------------------------------------------------------------
-- 086'da LoungeKey icin `typical_guest_fee = 32 USD` yazmisim. Bunun
-- bir kaynagi YOK: LoungeKey ucreti KARTI VEREN BANKAYA gore degisiyor
-- (TEB'de baska, Yapi Kredi'de baska) ve tek bir rakam vermek yanlis
-- beklenti yaratir. Priority Pass'te de ayni durum: ucret uyelik
-- planina gore degisir.
--
-- Kendi kuralim: "yanlis rakam, rakamsizliktan kotudur." Kart aglarinda
-- rakam KALDIRILIYOR; yerine "tutari kartini veren bankadan teyit et"
-- notu kaliyor. Havayolu/isletmeci ucretleri (Pegasus 49/63 EUR,
-- Primeclass 27 EUR) RESMI TARIFEDEN geldigi icin DURUYOR.
--
-- ------------------------------------------------------------
-- 🔴 KUSUR 3: BUSINESS BILETI MODELLENMEMIS
-- ------------------------------------------------------------
-- BUSINESS_TICKET programinin hicbir kabul satiri yoktu; business
-- bileti olan host "kural dogrulanmadi" genel uyarisina dusuyordu.
-- Oysa THY Tablo-1/2'nin son satiri net: KART TIPI OLMADAN Business
-- Class yolcu salona GIRER ama MISAFIR/AILE HAKKI YOKTUR.
-- Bilinmiyor demek, bilinen bir seyi saklamaktir.
-- ============================================================

-- ---- KUSUR 2: kaynaksiz rakamlari kaldir ----
update lounge_programs
   set typical_guest_fee = null,
       guest_fee_currency = null,
       notes = coalesce(notes,'') || ' [105] Tek bir misafir ucreti rakami KALDIRILDI: '
            || 'kart aglarinda ucret karti veren kuruma ve uyelik planina gore degisir; '
            || 'kaynaksiz rakam yanlis beklenti yaratir.'
 where code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS');

update lounge_venue_acceptance a
   set guest_fee_amount = null, guest_fee_currency = null,
       guest_fee_note = 'Ucret kisi basi ve ziyaret basina; misafir de UYENIN KARTINDAN '
                     || 'tahsil edilir. Tutar karti veren kuruma ve uyelik planina gore '
                     || 'degisir — kartini veren bankadan teyit et.'
  from lounge_programs p
 where a.program_id = p.id and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS');

-- ---- KUSUR 3: Business bileti ----
update lounge_programs
   set guest_default = 'not_allowed',
       guest_included_count = 0,
       guest_flight_coupling = 'same_carrier',
       entitlement_model = 'ticket_class',
       coverage_status = 'verified',
       enforcement = 'warn',
       checked_at = current_date,
       source_url = 'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
       notes = 'THY Tablo-1/2 son satir: kart tipi OLMADAN Business Class yolcu salona '
            || 'girer ama MISAFIR/AILE HAKKI YOKTUR. Misafir goturmek icin M&S kart '
            || 'tipine (Elite ve ustu) ihtiyac var. Istisna: Star Alliance FIRST '
            || 'yolcusu bir misafir goturebilir.'
 where code = 'BUSINESS_TICKET';

insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'not_allowed', 0, 'same_carrier', 'warn',
       'Business Class bileti salona giris hakki verir ama MISAFIR HAKKI VERMEZ. '
       || 'Misafir goturmek icin Miles&Smiles Elite ve ustu bir kart gerekir.',
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
       current_date
  from lounge_venues v, lounge_programs p
 where p.code = 'BUSINESS_TICKET' and v.active
   and lower(v.name) like '%turkish airlines%'
on conflict (venue_id, program_id) do update set
  guest_policy = 'not_allowed', guest_included_count = 0,
  conditions = excluded.conditions, checked_at = excluded.checked_at;


-- ============================================================
-- KUSUR 1: ucretli / hakkin yok ayrimi
-- ============================================================
create or replace function public.lounge_access_decision_v3(
  p_avail_id     uuid,
  p_guest_flight text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d          jsonb;
  v_av       availabilities%rowtype;
  v_ent      host_entitlements%rowtype;
  v_prog_id  uuid;
  v_rule     lounge_guest_rules%rowtype;
  v_venue_id uuid;
  v_needs_tier boolean := false;
  v_extra    text[] := '{}';
  v_sev      text;
  v_policy   text;
  v_count    smallint;
  v_payer    text;
  v_stay     numeric;
  v_entry    numeric;
  v_dur      numeric;
  v_dep      timestamptz;
  v_head     text;
begin
  d := public.lounge_access_decision_v2(p_avail_id, p_guest_flight);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;

  v_venue_id := public.resolve_venue_for_availability(p_avail_id);
  v_prog_id  := nullif(d ->> 'program_id','')::uuid;
  v_sev      := coalesce(d ->> 'severity','info');
  v_policy   := d ->> 'guest_policy';
  v_count    := coalesce((d ->> 'guest_included_count')::smallint, 0);
  v_stay     := nullif(d ->> 'max_stay_hours','')::numeric;
  v_entry    := nullif(d ->> 'earliest_entry_hours','')::numeric;

  select he.* into v_ent from host_entitlements he
   where he.user_id = v_av.host_id
     and (v_prog_id is null or he.program_id = v_prog_id)
   order by he.verified desc, he.self_reported_at desc nulls last limit 1;

  -- ---------- KART TİPİ ----------
  if v_prog_id is not null then
    v_needs_tier := public.program_needs_tier(v_prog_id);
  end if;

  if v_needs_tier and coalesce(v_ent.tier,'') = '' then
    -- 🔴 EN ÖNEMLİ DAVRANIŞ: tier bilinmiyorsa EN İYİ İHTİMALİ VARSAYMA.
    -- Eskiden motor ilk kurali seciyordu (cogu zaman Elite Plus) ve
    -- Classic Plus'li host'a "misafir hakkin var" diyordu.
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || ('Kart tipini bilmiyoruz. Bu programda misafir hakkı KART TİPİNE göre değişiyor '
                       || '(ör. Classic Plus''ta misafir hakkı YOK). Profil → Lounge Erişim''den kart tipini seç.')::text;
  elsif v_needs_tier then
    select r.* into v_rule
      from lounge_guest_rules r
     where r.program_id = v_prog_id
       and r.card_tier = v_ent.tier
       and (r.venue_id is null or r.venue_id = v_venue_id)
       and (r.effective_from is null or r.effective_from <= current_date)
       and (r.effective_to   is null or r.effective_to   >= current_date)
     order by (r.venue_id is not null) desc, r.created_at
     limit 1;

    if v_rule.id is not null then
      -- Kural, salon kabulunun UZERINE yazar: salon "1 misafir" dese de
      -- Classic Plus'in hakki yoksa hak YOKTUR.
      if v_rule.blocked_reason is not null then
        v_sev := 'block'; v_policy := 'not_allowed'; v_count := 0;
        v_extra := v_extra || v_rule.blocked_reason;
      elsif v_rule.guest_allowance = 0 and v_policy = 'included' then
        v_policy := case when v_rule.paid_entry_allowed then 'paid' else 'not_allowed' end;
        v_count  := 0;
        v_sev    := case when v_policy = 'not_allowed' then 'block' else 'warn' end;
        v_extra  := v_extra || format('Kart tipin (%s): bu kartla misafir hakkı yok.',
                                      coalesce(v_ent.tier,'?'));
        -- 🔴 104: BASLIK DA DEGISMELI. Eskiden yalniz severity ve policy
        -- degisiyordu; baslik salon kabulunden gelen "Misafir hakkın var
        -- (1 kişi)" olarak KALIYORDU. Kullanici "engellendi" rozetiyle
        -- "hakkın var" cumlesini yan yana goruyordu. Celiskili bir ekran,
        -- yanlis ekrandan daha kotudur: hangisine inanacagini bilemez.
        -- 🔴 105: IKI DURUM AYRI CUMLE ISTER.
        -- 'paid': misafir GIREBILIR ama ucret oder. 'not_allowed': giremez.
        -- 104'te ikisini de "goturemezsin" diye yazmistim; kullanici
        -- "ucretli" rozetiyle "goturemezsin" cumlesini yan yana goruyordu.
        v_head := case when v_policy = 'paid'
          then format('%s kartında misafir hakkı yok — misafirin ücret ödeyerek girebilir',
                      coalesce(v_ent.tier, 'Bu kart'))
          else format('%s kartıyla misafir götüremezsin',
                      coalesce(v_ent.tier, 'Bu')) end;
      else
        v_count := least(v_count, greatest(v_rule.guest_allowance, 0));
        if v_rule.family_allowed then
          v_extra := v_extra || ('Aile hakkın da var (eş + 25 yaşından gün almamış çocuklar) — '
                             || 'ama aile hakkı, tanışmak için gelen bir misafirin yerine geçmez.')::text;
        end if;
      end if;
      v_entry := coalesce(v_rule.earliest_entry_hours, v_entry);
      if v_rule.notes is not null then v_extra := v_extra || v_rule.notes; end if;
    end if;
  end if;

  -- ---------- KİM ÖDÜYOR ----------
  if v_policy = 'paid' then
    select coalesce(a.fee_payer, p.fee_payer, 'unknown') into v_payer
      from lounge_programs p
      left join lounge_venue_acceptance a
        on a.program_id = p.id and a.venue_id = v_venue_id
     where p.id = v_prog_id;
    v_extra := v_extra || coalesce(
      public.rule_notice(case v_payer
        when 'member_card'   then 'fee_note_member_card'
        when 'guest_at_door' then 'fee_note_guest_at_door'
        else 'rule_notice_generic' end), '');

    -- 🔴 105: BASLIK DA "KIM ODUYOR"A UYMALI.
    -- 086'nin basligi her ucretli durumda "kapida tahsil edilir" diyordu.
    -- Priority Pass / LoungeKey / DragonPass'te ucret KAPIDA MISAFIRDEN
    -- DEGIL, HOST'UN KARTINDAN cekiliyor. Misafire "kapida odeyeceksin"
    -- demek, ona ait olmayan bir maliyeti ustlendirmek olur; host'a da
    -- kendi odeyecegini gizler. Iki taraf da yanlis bilgilenirdi.
    if v_head is null then
      v_head := case v_payer
        when 'member_card'   then 'Misafir girişi ücretli — ücret host''un kartından çekilir'
        when 'guest_at_door' then coalesce(d ->> 'headline', 'Misafir girişi kapıda ücretli')
        else 'Misafir girişi ücretli olabilir — koşulları teyit edin' end;
    end if;
  end if;

  -- ---------- SAAT KONTROLLERİ ----------
  v_dur := extract(epoch from (v_av.time_to - v_av.time_from)) / 3600.0;
  if v_stay is not null and v_dur > v_stay + 0.25 then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || format(
      'İlanın %s saatlik ama bu salonda kalış ~%s saatle sınırlı. Süreyi kısaltmayı düşün.',
      trim(to_char(v_dur,'FM990.0')), trim(to_char(v_stay,'FM990.0')));
  end if;

  if v_entry is not null and coalesce(v_av.flight_number,'') <> '' then
    select fc.scheduled_departure into v_dep
      from flight_cache fc
     where upper(replace(fc.flight_no,' ','')) = upper(replace(v_av.flight_number,' ',''))
       and fc.flight_date = v_av.avail_date;
    if v_dep is not null then
      if (v_av.avail_date + v_av.time_from) < (v_dep - make_interval(mins => (v_entry*60)::int)) then
        v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
        v_extra := v_extra || format(
          'Salona en erken kalkıştan %s saat önce girilebiliyor; ilanın bundan erken başlıyor.',
          trim(to_char(v_entry,'FM990.0')));
      end if;
    else
      v_extra := v_extra || format(
        'Salona en erken kalkıştan %s saat önce girilebiliyor — uçuş saatini doğrulayamadığımız için kontrol edilemedi.',
        trim(to_char(v_entry,'FM990.0')));
    end if;
  end if;

  -- ---------- SLOT × MİSAFİR HAKKI ----------
  if v_policy = 'included' and v_count > 0 and coalesce(v_av.slots,1) > v_count then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || format(
      'İlanında %s kişilik yer var ama bu hakla en fazla %s misafir sokabilirsin.',
      v_av.slots, v_count);
  end if;

  return d || jsonb_build_object(
    'severity', v_sev,
    'headline', coalesce(v_head, d ->> 'headline'),
    'guest_policy', v_policy,
    'guest_included_count', v_count,
    'host_tier', v_ent.tier,
    'tier_required', v_needs_tier,
    'fee_payer', v_payer,
    'listing_hours', round(v_dur, 1),
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra, ' ')));
end $$;
grant execute on function public.lounge_access_decision_v3(uuid, text) to authenticated;

select '105 OK - ucret metni ayristi, kaynaksiz rakam kaldirildi, business bileti modellendi' as sonuc;
