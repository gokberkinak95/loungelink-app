-- ============================================================
-- LoungeLink · 104_tier_rules_program_level.sql
-- KART TİPİ KURALLARI SALONA DEĞİL PROGRAMA AİT
--
-- ⚠️ Uygulamayı ETKİLER (veri). Şema değişikliği YOK.
--
-- ------------------------------------------------------------
-- 🔴 TASARIM HATASI
-- ------------------------------------------------------------
-- 098'de THY'nin kart tipi tablosunu HER SALON İÇİN AYRI satır olarak
-- yazdım: 9 kart tipi × 15 salon = 134 satır. Karar motoru ise şöyle
-- arıyor:
--     (r.venue_id is null or r.venue_id = v_venue_id)
-- 103 mükerrer salonları birleştirince kurallar PASİF salonlarda kaldı
-- ve hiçbiri eşleşmedi. Sonuç: Classic Plus'lı host'a "misafir hakkın
-- var" deniyordu — kapatmaya çalıştığımız asıl hata geri gelmişti.
--
-- Asıl mesele kopyalama değil MODELLEME: "Classic Plus'ın misafir hakkı
-- yoktur" cümlesi bir SALON olgusu değil, PROGRAM olgusudur. THY'nin
-- Tablo-1 ve Tablo-2'si de salon salon değil, salon TÜRÜ bazında yazılı.
-- Salona bağlamak hem 134 satır üretti hem kırılgan bir join yarattı.
--
-- DOĞRUSU:
--   · Kart tipi kuralları PROGRAM düzeyinde (venue_id = null) — tek set.
--   · Yalnız GERÇEKTEN salona özgü olan istisna salona bağlı kalır:
--     IST dış hat BUSINESS bölümünde kart tipi ne olursa olsun misafir
--     hakkı yoktur (THY Tablo-3).
-- Böylece salon birleştirme, yeniden adlandırma ya da yeni salon
-- eklenmesi kuralları ETKİLEMEZ.
-- ============================================================

-- 1) Salona bagli kopyalari kapat (silme — gecmis kalsin)
update lounge_guest_rules r
   set effective_to = current_date - 1,
       notes = coalesce(r.notes,'') || ' [104] Salon bazli kopya kapatildi; '
            || 'kart tipi kurallari artik PROGRAM duzeyinde tutuluyor.'
  from lounge_programs p
 where r.program_id = p.id
   and p.code in ('TK_MS','AJET_MS')
   and r.card_tier is not null
   and r.venue_id is not null
   and (r.effective_to is null or r.effective_to >= current_date);

-- 2) PROGRAM duzeyinde tek set (THY Tablo-1/2 + dipnotlar)
delete from lounge_guest_rules r using lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS'
   and r.venue_id is null and r.card_tier is not null;

insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, paid_entry_allowed, paid_entry_price_note,
   notes, effective_from, effective_to)
select p.id, null, 'TK', t.tier, t.allow, t.family, true, t.paid, t.price, t.note,
       date '2026-06-01', date '2026-12-31'
  from lounge_programs p, (values
    ('ELPL',     1::smallint, true,  false, null::text,
     'Elite Plus: ic ve dis hatta AILE VEYA BIR MISAFIR. Aile = es + 25 yasindan gun almamis cocuklar; salona hak sahibiyle BIRLIKTE girmeleri sart.'),
    ('ELITE',    1::smallint, true,  false, null,
     'Elite: ic ve dis hatta aile veya bir misafir.'),
    ('MS_EC',    1::smallint, true,  false, null,
     'Miles&Smiles Elite Corporate: aile veya bir misafir. Dis hatta Star Alliance MARKALI salonlara giremez, yalniz anlasmali salonlar.'),
    ('CLPL',     0::smallint, false, false, null,
     'Classic Plus: IC HAT salonuna Ekonomi''de bile UCRETSIZ girer ama MISAFIR/AILE HAKKI YOKTUR.'),
    ('CLASSIC',  0::smallint, false, true,
     'Ic hat: IST 3.000 TL · AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL · Dis hat 50 USD',
     'Classic: ucretli giris. Ucret odemek misafir hakki DOGURMAZ.'),
    ('SAG',      1::smallint, false, false, null,
     'Star Alliance Gold: BIR misafir, AILE HAKKI YOK.'),
    ('PLM',      1::smallint, false, false, null,
     'Miles & More: BIR misafir.'),
    ('CORP',     1::smallint, false, false, null,
     'Corporate Club: BIR misafir. Ic hat kullanimi icin ayni gun baglantili dis hat sarti ve ucuslarin AYNI BILET uzerinde olmasi gerekir.'),
    ('MS_US_CC', 0::smallint, false, false, null,
     'Miles&Smiles ABD Kredi Karti: MISAFIR HAKKI YOK. Dalaman ve Diyarbakir haric ucretsiz giris; uyelik kartla eslestirilmis olmali.')
  ) as t(tier, allow, family, paid, price, note)
 where p.code = 'TK_MS';

-- AJet (AJet ucus tarifesi + kendi kurallari)
delete from lounge_guest_rules r using lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r.venue_id is null and r.card_tier is not null;

insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, earliest_entry_hours, paid_entry_allowed,
   paid_entry_price_note, notes, effective_from, effective_to)
select p.id, null, 'AJ', t.tier, t.allow, t.family, true, 2, t.paid, t.price, t.note,
       date '2026-06-01', date '2026-12-31'
  from lounge_programs p, (values
    ('ELPL',    1::smallint, true,  false, null::text,
     'Elite Plus: UCRETSIZ, aile veya bir misafir. Misafir de AJet seferinde ucmali — THY yolcusu misafir olarak kabul EDILMEZ.'),
    ('ELITE',   1::smallint, true,  false, null,
     'Elite: UCRETSIZ, aile veya bir misafir. Misafir de AJet seferinde olmali.'),
    ('MS_EC',   1::smallint, true,  false, null,
     'Elite Corporate: UCRETSIZ, aile veya bir misafir.'),
    ('CLPL',    0::smallint, false, true,
     'AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL',
     'Classic Plus: MISAFIR/AILE HAKKI YOK. Beraberindeki her misafir ve 2-12 yas cocuk icin tablodaki ucretin %50''si alinir.'),
    ('CLASSIC', 0::smallint, false, true,
     'AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL',
     'Classic: ucretli giris, misafir hakki yok.')
  ) as t(tier, allow, family, paid, price, note)
 where p.code = 'AJET_MS';

-- 3) GERCEKTEN SALONA OZGU ISTISNA: IST dis hat BUSINESS bolumu
-- (THY Tablo-3: Business Class yolcu kart tipinden BAGIMSIZ girer ama
--  misafir/aile hakki YOKTUR; misafir getirecekse M&S bolumune girmeli.)
delete from lounge_guest_rules r
 using lounge_programs p, lounge_venues v
 where r.program_id = p.id and r.venue_id = v.id
   and p.code = 'TK_MS' and v.section = 'business' and r.card_tier is null;

insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, blocked_reason, notes, effective_from)
select p.id, v.id, 'TK', null, 0, false, true,
       'Bu bolumde misafir/aile hakki yok',
       'IST dis hat Lounge BUSINESS bolumu: Business Class yolcular kart tipinden '
       || 'bagimsiz girer ama misafir/aile hakki YOKTUR. Misafir getirilecekse '
       || 'Lounge Miles&Smiles bolumune girilmelidir. (Star Alliance FIRST istisna: bir misafir.)',
       current_date
  from lounge_programs p, lounge_venues v
 where p.code = 'TK_MS' and v.active and v.section = 'business'
   and v.airport_code = 'IST' and lower(coalesce(v.terminal,'')) like '%dis%';

-- ============================================================
-- DOGRULAMA
-- ============================================================
select p.code, coalesce(r.card_tier,'(salon kurali)') as kart,
       r.guest_allowance, r.family_allowed, r.paid_entry_allowed,
       case when r.venue_id is null then 'PROGRAM' else 'salon' end as kapsam
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code in ('TK_MS','AJET_MS')
   and (r.effective_to is null or r.effective_to >= current_date)
 order by p.code, r.card_tier nulls last;

select '104 OK - kart tipi kurallari PROGRAM duzeyine tasindi' as sonuc;


-- ============================================================
-- 4) KARAR METNI: kart tipi engeli BASLIGI da degistirsin
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
        v_head := format('%s kartıyla misafir götüremezsin',
                         coalesce(v_ent.tier, 'Bu'));
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
