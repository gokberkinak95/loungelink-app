-- ============================================================
-- LoungeLink · 100_tier_fee_and_time.sql
-- KARAR MOTORUNUN ÜÇ BOŞLUĞU
--
-- ⚠️ Uygulamayı ETKİLER. Şema: yeni nullable kolonlar + fonksiyon güncellemesi.
--
-- Kendi denetimimde bulduğum, veriyi toplayıp KARARA SOKMADIĞIM üç şey:
--
-- 🔴 1. KART TİPİ HİÇ ÇALIŞMIYORDU
--    İki migration boyunca THY'nin dokuz kart tipini ve AJet'in beş
--    kademesini işledim. Ama karar motorunda `card_tier` YALNIZCA
--    SIRALAMA kriteriydi ((r.card_tier is not null) desc), FİLTRE değil.
--    Üstelik `host_entitlements.tier` hiç doldurulmuyordu.
--    Sonuç: Classic Plus'lı host (MİSAFİR HAKKI YOK) ile Elite Plus'lı
--    host AYNI cevabı alıyordu. Kapıda çevrilmenin en olası sebebi buydu.
--
-- 🔴 2. "KİM ÖDÜYOR" YANLIŞ YAZILMIŞTI
--    Priority Pass md.4 ve LoungeKey aynı: "misafir ziyaretleri de
--    ÜYENİN KARTINDAN tahsil edilir." Yani parayı HOST öder, misafir
--    kapıda bir şey ödemez. Benim metinlerim "misafir kapıda ücret
--    öder" diyordu — Pegasus/Plaza Premium ücretli girişi için doğru,
--    kart ağları için YANLIŞ. İkisi farklı ve tek kalıba sokmuşum.
--
-- 🔴 3. SAAT KURALLARI SAKLANIYOR AMA KONTROL EDİLMİYORDU
--    max_stay_hours ve earliest_entry_hours 13 yerde geçiyordu, hepsi
--    GÖSTERİM. DragonPass'te (~2 saat) 5 saatlik ilan açılabiliyordu.
-- ============================================================


-- ============================================================
-- 1) KİM ÖDÜYOR
-- ============================================================
alter table lounge_programs        add column if not exists fee_payer text;
alter table lounge_venue_acceptance add column if not exists fee_payer text;

alter table lounge_programs drop constraint if exists lp_fee_payer_chk;
alter table lounge_programs add constraint lp_fee_payer_chk
  check (fee_payer is null or fee_payer in ('member_card','guest_at_door','unknown'));
alter table lounge_venue_acceptance drop constraint if exists lva_fee_payer_chk;
alter table lounge_venue_acceptance add constraint lva_fee_payer_chk
  check (fee_payer is null or fee_payer in ('member_card','guest_at_door','unknown'));

comment on column lounge_programs.fee_payer is
  'member_card  = misafir ucreti HOST''un kartindan cekilir (PP/LoungeKey/DragonPass). '
  'guest_at_door = misafir kapida kendisi oder (Pegasus/Plaza Premium/Primeclass ucretli giris).';

update lounge_programs set fee_payer = 'member_card'
 where code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS');
update lounge_programs set fee_payer = 'guest_at_door'
 where code in ('PGS_PAID','PLAZA_PREMIUM','PRIMECLASS','IGA_LOUNGE');
update lounge_programs set fee_payer = 'guest_at_door'
 where fee_payer is null and guest_default = 'paid';

update lounge_venue_acceptance a set fee_payer = p.fee_payer
  from lounge_programs p
 where a.program_id = p.id and a.fee_payer is null and p.fee_payer is not null;

-- Kullanıcıya gösterilen metinler
insert into beta_settings (key, value) values
 ('fee_note_member_card', to_jsonb(
   'Bu programda misafir ucreti KAPIDA MISAFIRDEN DEGIL, host''un kartindan tahsil '
   || 'edilir. Yani misafirin cebinden para cikmaz ama host odeme yapar — buluşmadan '
   || 'once bunu aranizda konusun.'::text)),
 ('fee_note_guest_at_door', to_jsonb(
   'Bu salonda misafir girisi kapida odenir. Tutari buluşmadan once teyit edin; '
   || 'kapida surpriz yasanmasin.'::text))
on conflict (key) do update set value = excluded.value;


-- ============================================================
-- 2) HOST'UN KART TİPİ
-- ============================================================
-- host_entitlements.tier zaten var; save_host_access artik dolduruyor.
drop function if exists public.save_host_access(text[], smallint, boolean, smallint, text, smallint, uuid);

create or replace function public.save_host_access(
  p_sources            text[]   default null,
  p_guest_capacity     smallint default null,
  p_guest_fee_expected boolean  default null,
  p_quota_total        smallint default null,
  p_quota_period       text     default null,
  p_quota_used         smallint default null,
  p_card_product_id    uuid     default null,
  p_card_tier          text     default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_txt  text;
  v_prog uuid;
  v_card lounge_card_products%rowtype;
  v_ent  uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_quota_period is not null and p_quota_period not in ('year','month','unlimited') then
    raise exception 'invalid_quota_period';
  end if;
  if p_quota_total is not null and p_quota_used is not null and p_quota_used > p_quota_total then
    raise exception 'quota_used_exceeds_total';
  end if;

  v_txt := nullif(array_to_string(coalesce(p_sources, '{}'::text[]), ', '), '');

  update profiles
     set access_source      = coalesce(v_txt, access_source),
         guest_capacity     = coalesce(p_guest_capacity, guest_capacity),
         guest_fee_expected = coalesce(p_guest_fee_expected, guest_fee_expected),
         updated_at         = now()
   where user_id = v_uid;

  if p_card_product_id is not null then
    select * into v_card from lounge_card_products where id = p_card_product_id and active;
    if found then v_prog := v_card.program_id; end if;
  end if;
  if v_prog is null then
    v_prog := public.match_program_by_text(coalesce(v_txt,
                (select access_source from profiles where user_id = v_uid)));
  end if;

  if v_prog is not null then
    -- 🔴 Ayni program icin FARKLI tier'da eski satir varsa temizle:
    -- benzersiz indeks (user, program, coalesce(tier,'')) oldugu icin
    -- tier degisince ikinci satir olusur ve karar motoru eskisini secebilir.
    delete from host_entitlements
     where user_id = v_uid and program_id = v_prog
       and coalesce(tier,'') is distinct from coalesce(p_card_tier,'');

    insert into host_entitlements
      (user_id, program_id, tier, card_product_id, guest_capacity, origin, note,
       quota_total, quota_period, quota_used, self_reported_at)
    values
      (v_uid, v_prog, p_card_tier, p_card_product_id, p_guest_capacity, 'declared',
       'save_host_access',
       coalesce(p_quota_total, v_card.quota_total),
       coalesce(p_quota_period, v_card.quota_period),
       coalesce(p_quota_used, 0), now())
    on conflict (user_id, program_id, coalesce(tier,''))
    do update set
      card_product_id  = coalesce(excluded.card_product_id, host_entitlements.card_product_id),
      guest_capacity   = coalesce(excluded.guest_capacity, host_entitlements.guest_capacity),
      quota_total      = coalesce(excluded.quota_total, host_entitlements.quota_total),
      quota_period     = coalesce(excluded.quota_period, host_entitlements.quota_period),
      quota_used       = coalesce(excluded.quota_used, host_entitlements.quota_used),
      self_reported_at = now(), origin = 'declared'
    returning id into v_ent;
  end if;

  return jsonb_build_object('ok', true, 'program_id', v_prog, 'tier', p_card_tier,
    'entitlement_id', v_ent,
    'quota', case when v_ent is null then null else public.entitlement_remaining(v_ent) end);
end $$;
grant execute on function public.save_host_access(text[], smallint, boolean, smallint, text, smallint, uuid, text) to authenticated;

-- Ekranda gosterilecek kart tipi listesi (programa gore)
create or replace function public.card_tier_options(p_program_code text)
returns table (tier text, label text, guest_allowance smallint, family_allowed boolean, note text)
language sql stable security definer set search_path = public as $$
  select r.card_tier,
         case r.card_tier
           when 'ELPL'     then 'Elite Plus'
           when 'ELITE'    then 'Elite'
           when 'MS_EC'    then 'Miles&Smiles Elite Corporate'
           when 'CLPL'     then 'Classic Plus'
           when 'CLASSIC'  then 'Classic'
           when 'SAG'      then 'Star Alliance Gold'
           when 'PLM'      then 'Miles & More'
           when 'CORP'     then 'Corporate Club'
           when 'MS_US_CC' then 'Miles&Smiles ABD Kredi Kartı'
           else r.card_tier end,
         r.guest_allowance, r.family_allowed, r.notes
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = p_program_code and r.card_tier is not null
     and (r.effective_to is null or r.effective_to >= current_date)
   group by r.card_tier, r.guest_allowance, r.family_allowed, r.notes
   order by r.guest_allowance desc, r.card_tier;
$$;
grant execute on function public.card_tier_options(text) to authenticated;

-- Yalniz TIER'A BAGLI programlar icin sor (kart aglarinda tier yok)
create or replace function public.program_needs_tier(p_program_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from lounge_guest_rules r
                  where r.program_id = p_program_id and r.card_tier is not null
                    and (r.effective_to is null or r.effective_to >= current_date));
$$;
grant execute on function public.program_needs_tier(uuid) to authenticated;


-- ============================================================
-- 3) KARAR MOTORU — tier filtresi + saat kontrolu + kim oduyor
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
    'guest_policy', v_policy,
    'guest_included_count', v_count,
    'host_tier', v_ent.tier,
    'tier_required', v_needs_tier,
    'fee_payer', v_payer,
    'listing_hours', round(v_dur, 1),
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra, ' ')));
end $$;
grant execute on function public.lounge_access_decision_v3(uuid, text) to authenticated;


-- ============================================================
-- 4) APP KAPILARI v3'e BAĞLANIYOR (imza degismiyor)
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.request_precheck(uuid);
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline', 'İlan bulunamadı.'); end if;

  select v.flight_number into v_flight from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date and coalesce(v.flight_number,'') <> ''
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v3(p_avail_id, v_flight);
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind', 'card_generic',
      'severity','warn', 'source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'detail', public.rule_notice('card_notice_guest'));
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' then v_can := false; else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'guest_fee_amount', d -> 'guest_fee_amount',
    'guest_fee_currency', d ->> 'guest_fee_currency',
    'headline', d ->> 'headline', 'detail', d ->> 'detail');
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;


-- ============================================================
-- 4b) HOST BİLGİ KUTUSU da kart tipini bilmeli
-- Host tarafı, tier eksikliğinin EN ÇOK önem taşıdığı yer: ilan
-- açarken "misafir hakkın var" demek, Classic Plus'lı bir host için
-- yanlış vaat olur.
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.lounge_hint_for_host(uuid);
create or replace function public.lounge_hint_for_host(p_lounge_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_venue_id uuid; v_venue lounge_venues%rowtype;
  v_prog lounge_programs%rowtype; v_acc lounge_venue_acceptance%rowtype;
  v_ent host_entitlements%rowtype; v_rule lounge_guest_rules%rowtype;
  v_src text; v_sev text := 'info'; v_head text; v_notes text[] := '{}';
  v_count smallint := 0; v_needs_tier boolean := false;
begin
  if v_uid is null then return jsonb_build_object('severity','info'); end if;

  select l.venue_id into v_venue_id from lounges l where l.id = p_lounge_id;
  if v_venue_id is not null then select * into v_venue from lounge_venues where id = v_venue_id; end if;

  select he.* into v_ent from host_entitlements he
   where he.user_id = v_uid order by he.verified desc, he.self_reported_at desc nulls last limit 1;
  if v_ent.program_id is not null then
    select * into v_prog from lounge_programs where id = v_ent.program_id;
  else
    select pr.access_source into v_src from profiles pr where pr.user_id = v_uid;
    select * into v_prog from lounge_programs where id = public.match_program_by_text(v_src);
  end if;

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('severity','warn','kind','card_generic',
      'venue_name', v_venue.name, 'headline','Kart avantajıyla açılan ilan',
      'detail', public.rule_notice('card_notice_host'));
  end if;

  if v_venue_id is not null then
    select * into v_acc from lounge_venue_acceptance
     where venue_id = v_venue_id and program_id = v_prog.id and active;
  end if;

  if v_acc.id is null then
    return jsonb_build_object('severity','warn','kind','unknown',
      'venue_name', v_venue.name, 'program_name', v_prog.name,
      'headline', format('%s bu salonda doğrulanmadı', v_prog.name),
      'detail', public.rule_notice('rule_notice_generic'));
  end if;

  if not v_acc.accepted or v_acc.guest_policy = 'not_allowed' then
    return jsonb_build_object('severity','block','kind','not_allowed',
      'venue_name', v_venue.name, 'program_name', v_prog.name,
      'headline','Bu salonda misafir alamazsın',
      'detail', coalesce(v_acc.conditions,'Bu salon/hak birleşiminde misafir hakkı yok.'));
  end if;

  v_count := v_acc.guest_included_count;
  v_needs_tier := public.program_needs_tier(v_prog.id);

  -- 🔴 KART TİPİ KAPISI
  if v_needs_tier and coalesce(v_ent.tier,'') = '' then
    v_sev := 'warn';
    v_head := 'Kart tipini belirtmen gerekiyor';
    v_notes := v_notes || format('%s''ta misafir hakkı KART TİPİNE göre değişiyor: Elite ve Elite Plus''ta '
      || 'aile veya bir misafir, Classic Plus''ta MİSAFİR HAKKI YOK. Doğru bilgiyi gösterebilmemiz için '
      || 'Lounge Erişim ekranından kart tipini seç.', v_prog.name);
  elsif v_needs_tier then
    select r.* into v_rule from lounge_guest_rules r
     where r.program_id = v_prog.id and r.card_tier = v_ent.tier
       and (r.venue_id is null or r.venue_id = v_venue_id)
       and (r.effective_to is null or r.effective_to >= current_date)
     order by (r.venue_id is not null) desc, r.created_at limit 1;
    if v_rule.id is not null and v_rule.guest_allowance = 0 then
      return jsonb_build_object('severity','block','kind','tier_no_guest',
        'venue_name', v_venue.name, 'program_name', v_prog.name, 'host_tier', v_ent.tier,
        'headline','Kart tipinde misafir hakkı yok',
        'detail', coalesce(v_rule.notes,'') || ' Bu kartla salona girebilirsin ama yanında misafir götüremezsin.');
    elsif v_rule.id is not null then
      v_count := least(v_count, v_rule.guest_allowance);
    end if;
  end if;

  if v_head is null then
    if v_acc.guest_policy = 'paid' then
      v_sev := 'warn';
      v_head := 'Misafir girişi ücretli';
      v_notes := v_notes || public.rule_notice(
        case coalesce(v_acc.fee_payer, v_prog.fee_payer,'unknown')
          when 'member_card' then 'fee_note_member_card'
          when 'guest_at_door' then 'fee_note_guest_at_door'
          else 'rule_notice_generic' end);
    elsif v_acc.guest_policy = 'unknown' then
      v_sev := 'warn'; v_head := 'Bu salonun misafir kuralı doğrulanmadı';
      v_notes := v_notes || public.rule_notice('rule_notice_generic');
    else
      v_sev := 'ok';
      v_head := case when v_count > 0
        then format('Misafir hakkın var — %s kişi, ek ücret yok', v_count)
        else 'Misafir kabul ediliyor' end;
    end if;
  end if;

  case coalesce(v_acc.guest_flight_coupling, v_prog.guest_flight_coupling, 'any')
    when 'same_flight'  then v_notes := v_notes || ('Misafirin SENİNLE AYNI UÇUŞTA olmalı — ilanına uçuş numaranı ekle.')::text;
    when 'same_carrier' then v_notes := v_notes || ('Misafirin de aynı havayolunda uçuyor olmalı.')::text;
    when 'same_alliance' then v_notes := v_notes || ('Misafirin ittifak üyesi bir havayolunda uçuyor olmalı.')::text;
    else null;
  end case;
  if v_acc.max_stay_hours is not null then
    v_notes := v_notes || format('Salonda kalış ~%s saatle sınırlı.', trim(to_char(v_acc.max_stay_hours,'FM990.0')));
  end if;

  return jsonb_build_object('severity', v_sev, 'kind','rule',
    'venue_name', v_venue.name, 'program_name', v_prog.name, 'host_tier', v_ent.tier,
    'guest_policy', v_acc.guest_policy, 'guest_included_count', v_count,
    'fee_payer', coalesce(v_acc.fee_payer, v_prog.fee_payer),
    'headline', v_head, 'detail', array_to_string(v_notes,' '));
end $$;
grant execute on function public.lounge_hint_for_host(uuid) to authenticated;


-- ============================================================
-- 5) KENDİ İLKEMİ ÇİĞNEDİĞİM YER — THY × kart ağı block -> warn
--
-- 099'da "dizinde yok ≠ kabul etmiyor" dedim. Ama 098'de THY salonlari
-- icin tam tersini yaptim: kart dizinlerinde gormedigim icin 'block'
-- yazdim, yoklugu kanit saydim. Muhtemelen dogru ama kanitim
-- "gormedim"den ibaret — engel degil uyari olmali.
-- ============================================================
update lounge_venue_acceptance a
   set enforcement = 'warn',
       conditions = 'Turkish Airlines ozel yolcu salonlari havayolu programina baglidir ve '
                 || 'Priority Pass / LoungeKey / DragonPass dizinlerinde YER ALMIYOR. Girisin '
                 || 'kabul edilmemesi cok olasi — bu havalimanindaki isletmeci salonlarini '
                 || '(IGA / Plaza Premium / Primeclass / Celebi) sec. Yine de denemek istersen '
                 || 'kapida teyit et.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   and lower(v.name) like '%turkish airlines%';


-- ============================================================
-- 6) DOGRULAMA
-- ============================================================
select p.code, count(*) filter (where r.card_tier is not null) as tier_kurali,
       p.fee_payer
  from lounge_programs p left join lounge_guest_rules r on r.program_id = p.id
 where p.active group by p.code, p.fee_payer order by p.code;

select * from public.card_tier_options('TK_MS');

select '100 OK - kart tipi FILTRE oldu, kim oduyor ayrildi, saat kurallari kontrol ediliyor' as sonuc;
