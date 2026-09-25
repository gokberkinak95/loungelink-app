-- ============================================================
-- LoungeLink · 134_tier_label_everywhere.sql
-- KART KODU HALA BIR YERDE SIZIYOR
--
-- ⚠️ Uygulamayi ETKILER (metin).
--
-- 🔴 120'DE YARIM DUZELTMISIM.
-- "CLPL kartı ne?" sorusunu 120'de cozdugumu saniyordum: precheck'e
-- `card_tier_label()` ekledim ve istek ekraninda "Classic Plus" yaziyor.
-- Ama KARAR MOTORUNUN kendi basligi (104'te yazilan) hala HAM KODU
-- kullaniyor — ve kesif ROZETLERI o basligi gosteriyor.
--
-- Yani kullanici ayni bilgiyi iki ekranda iki farkli dilde goruyor:
-- kesifte "CLPL", istek ekraninda "Classic Plus". Ic kodun bir ekrandan
-- silinmesi yetmez; SIZDIGI HER YERDEN silinmeli.
--
-- Ders: bir metni duzeltirken "baska nerede uretiliyor" diye sormak.
-- Tek cikis noktasini duzeltip isi bitmis saymak, yarim duzeltmedir.
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
        -- 🔴 134: HAM KOD DEGIL INSAN DILI. `v_ent.tier` bizim veritabani
        -- kodumuz (CLPL, ELPL...); kullanicinin kartinin uzerinde
        -- "Classic Plus" yaziyor. 120'de precheck'i duzeltmistim ama
        -- BURAYI atlamistim — ve kesif ROZETLERI bu basligi gosteriyor.
        -- Ic kodun bir ekrandan silinmesi yetmez; SIZDIGI HER YERDEN
        -- silinmeli. "Baska nerede uretiliyor" diye sormayi atlamisim.
        v_head := case when v_policy = 'paid'
          then format('%s kartında misafir hakkı yok — misafirin ücret ödeyerek girebilir',
                      coalesce(public.card_tier_label(v_ent.tier), 'Bu kart'))
          else format('%s kartıyla misafir götüremezsin',
                      coalesce(public.card_tier_label(v_ent.tier), 'Bu kart')) end;
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

select '134 OK - kart kodu her yerden temizlendi' as sonuc;
