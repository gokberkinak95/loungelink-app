-- ============================================================
-- LoungeLink · 157_decision_uses_resolver.sql
-- KARAR ZİNCİRİ ÇÖZÜMLEYİCİYE BAĞLANIR (147'nin niyeti UYGULANIR)
--
-- ⚠️ Uygulamayı ETKİLER (app'in çağırdığı karar fonksiyonu + rehber RPC).
--
-- ------------------------------------------------------------
-- 🔴 156'NIN 12/12'Sİ MOTORU KANITLADI, KABLOYU DEĞİL
-- ------------------------------------------------------------
-- mixed_case_check resolve_guest_rule'ü test etti ve geçti. Ama app
-- resolve'u DOĞRUDAN çağırmıyor — lounge_access_decision /
-- request_precheck / guide_lounges çağırıyor. Zinciri uçtan uca
-- sorgulayınca ÜÇ gerçek kusur çıktı (hepsi ölçüldü):
--
-- 1. KARAR FONKSİYONU TİER-KÖRÜYDÜ. host_entitlements'tan yalnız
--    program_id çekiyor, he.tier'ı HİÇ okumuyordu. Kural sorgusunda
--    card_tier filtresi yoktu ama sıralamada `(card_tier is not null)
--    desc` VARDI — yani host'un tipine bakmadan EN SPESİFİK tier
--    satırını seçiyordu. Ölçüm: CLPL host + IST dış hat ilanı →
--    karar `fits: true` + genel program metni döndü. 086'daki sınıfın
--    devamı: "imzası doğru görünen ama parametreyi kullanmayan fonksiyon".
--
-- 2. STAR ALLIANCE ÇEVİRİSİ YOKTU. Sorgu `r.carrier = v_av.carrier`
--    diye düz karşılaştırıyordu; LH ilanında `carrier='STAR_ALLIANCE'`
--    satırları ASLA eşleşmez. 146'nın Star Alliance kuralları karar
--    zincirinde ERİŞİLEMEZ durumdaydı — veri doğruydu, kablo kopuktu.
--
-- 3. 🔴 guide_lounges İKİ AŞIRI YÜKLEME halinde yaşıyordu (143'ün
--    3 parametrelisi + 147'nin 5 parametrelisi; 147 eskiyi DROP
--    etmemiş). App 3 adlandırılmış parametreyle çağırıyor — bu çağrı
--    HER İKİ imzaya da uyar → PostgREST canlıda "Could not choose the
--    best candidate function" döner → app `.catch(() => setRows([]))`
--    ile yutar → REHBER EKRANI SESSİZCE BOŞ. Yerel testte görünmez
--    çünkü psql'de belirsizlik yok; bu, yalnız PostgREST katmanında
--    patlayan bir hata sınıfı.
--
-- ÇÖZÜM İLKESİ: 147 "üç yer ayrı ayrı çözümlüyor, tek kaynak olsun"
-- demişti ama karar fonksiyonuna hiç bağlanmamıştı — niyet yazılmış,
-- kablo çekilmemişti. Bu dosya karar fonksiyonunun kural bölümünü
-- resolve_guest_rule'e DEVREDER: Star Alliance çevirisi, venue_scope,
-- tier eşleşmesi ve 156'nın tüm düzeltmeleri karar zincirine tek
-- yerden akar.
-- ============================================================

-- ---- 1) resolve_guest_rule: kararın ihtiyaç duyduğu alanlar ----
-- Karar fonksiyonu blocked_reason / whitelist / entry_hours kullanıyor;
-- resolve bunları döndürmüyordu. jsonb dönüşe ALAN EKLEMEK geriye
-- uyumludur; imza yine aynı (aşırı yükleme riski yok).
-- Sıralamaya 103 dersiyle uyumlu tek ek: EŞİT özgüllükte engel satırı
-- kazanır (engel hiçbir zaman daha özel bir kuralı ezmez — en sonda).
create or replace function public.resolve_guest_rule(
  p_program_id uuid,
  p_venue_id   uuid    default null,
  p_tier       text    default null,
  p_carrier    text    default null,
  p_cabin      text    default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r lounge_guest_rules%rowtype; p lounge_programs%rowtype;
        v_alliance text; v_eff text; v_scope text;
begin
  select * into p from lounge_programs where id = p_program_id;
  if not found then return jsonb_build_object('found', false); end if;

  select c.alliance into v_alliance from carriers c where c.code = p_carrier;
  v_eff := case
    when p_carrier is null then null
    when p_carrier = 'TK' then 'TK'
    when p_carrier = 'VF' then 'VF'
    when v_alliance = 'star_alliance' then 'STAR_ALLIANCE'
    else p_carrier end;

  if p_venue_id is not null then
    select case
             when coalesce(a.country,'') not in ('','TR','Türkiye','Turkiye','Turkey') then 'abroad'
             when v.scope in ('domestic','international') then v.scope
             else null end
      into v_scope
      from lounge_venues v join airports a on a.code = v.airport_code
     where v.id = p_venue_id;
  end if;

  select * into r from lounge_guest_rules x
   where x.program_id = p_program_id
     and (x.venue_id is null or x.venue_id = p_venue_id)
     and (x.venue_scope is null or x.venue_scope = v_scope)
     and (x.card_tier is null or x.card_tier = p_tier)
     and (x.carrier is null or x.carrier = v_eff)
     and (x.cabin_class is null or x.cabin_class = p_cabin)
     and (x.effective_to is null or x.effective_to >= current_date)
   order by
     coalesce(x.venue_id = p_venue_id, false) desc,
     coalesce(x.card_tier = p_tier, false) desc,
     coalesce(x.carrier = v_eff, false) desc,
     coalesce(x.venue_scope = v_scope, false) desc,
     coalesce(x.cabin_class = p_cabin, false) desc,
     -- 🔴 103 dersi korunur: engel yalnız EŞİT özgüllükte belirleyici.
     coalesce(x.blocked_reason is not null, false) desc,
     x.created_at desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'found', false, 'program', p.name,
      'guest_allowance', case p.guest_default when 'included' then coalesce(p.guest_included_count,1) else 0 end,
      'family_allowed', false,
      'note', 'Bu kart tipi için özel kural bulunamadı; program varsayılanı uygulandı.');
  end if;

  return jsonb_build_object(
    'found', true,
    'program', p.name,
    'tier', public.card_tier_label(r.card_tier),
    'tier_code', r.card_tier,
    'carrier_scope', r.carrier,
    'venue_scope', r.venue_scope,
    'guest_allowance', coalesce(r.guest_allowance, 0),
    'family_allowed', coalesce(r.family_allowed, false),
    'paid_entry_allowed', coalesce(r.paid_entry_allowed, false),
    'same_flight_required', coalesce(r.guest_must_match_carrier, false),
    'blocked_reason', r.blocked_reason,
    'whitelist', case when r.guest_carrier_whitelist is not null
                      then to_jsonb(r.guest_carrier_whitelist) end,
    'entry_hours', r.earliest_entry_hours,
    'member_fee', nullif(r.member_entry_fee,''),
    'guest_fee', nullif(r.guest_entry_fee,''),
    'note', r.notes,
    'headline', case
      when r.blocked_reason is not null then r.blocked_reason
      when coalesce(r.guest_allowance,0) > 0 and coalesce(r.family_allowed,false)
        then 'Ailen veya bir misafir götürebilirsin'
      when coalesce(r.guest_allowance,0) > 0
        then coalesce(r.guest_allowance,0)::text || ' misafir götürebilirsin'
      when coalesce(r.paid_entry_allowed,false)
        then 'Ücret ödeyerek girersin — misafir hakkın yok'
      else 'Girebilirsin ama misafir götüremezsin' end);
end $$;

-- ---- 2) KARAR FONKSİYONU: kural bölümü çözümleyiciye devredilir ----
-- 🔴 103'ün gövdesi BAZ ALINDI (okundu, kopyalandı); yalnız (a) tier
-- artık host_entitlements'tan okunuyor (b) 2. blok resolve_guest_rule
-- çağrısına devredildi (c) dönüşe family_allowed / member_fee / tier
-- eklendi. Salon×program kabulü (1. eksen), uçuş bağı kontrolü,
-- derecelendirme ve notlar 103'teki gibi.
create or replace function public.lounge_access_decision(
  p_avail_id     uuid,
  p_guest_flight text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_av        availabilities%rowtype;
  v_venue     lounge_venues%rowtype;
  v_prog      lounge_programs%rowtype;
  v_acc       lounge_venue_acceptance%rowtype;
  v_venue_id  uuid;
  v_prog_id   uuid;
  v_tier      text;
  v_rj        jsonb;
  v_wl        text[];
  v_family    boolean := false;
  v_policy    text;
  v_coupling  text;
  v_included  smallint := 0;
  v_fee       numeric;
  v_cur       text;
  v_fee_note  text;
  v_stay      numeric;
  v_entry     numeric;
  v_enforce   text;
  v_src       text;
  v_host_car  text;
  v_g_car     text;
  v_fits      boolean := true;
  v_sev       text := 'ok';
  v_head      text;
  v_detail    text := '';
  v_notes     text[] := '{}';
  v_checked   date;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then
    return jsonb_build_object('known', false, 'severity', 'unknown',
                              'headline', 'İlan bulunamadı.');
  end if;

  v_venue_id := public.resolve_venue_for_availability(p_avail_id);
  if v_venue_id is not null then
    select * into v_venue from lounge_venues where id = v_venue_id;
  end if;

  -- ---- PROGRAM SEÇİMİ (103 ile aynı öncelik) ----
  v_prog_id := v_av.program_id;

  if v_prog_id is null and v_venue_id is not null then
    select he.program_id into v_prog_id
      from host_entitlements he
      join lounge_venue_acceptance a2
        on a2.program_id = he.program_id and a2.venue_id = v_venue_id
       and a2.accepted and a2.active
     where he.user_id = v_av.host_id
     order by coalesce(a2.guest_policy = 'included', false) desc,
              coalesce(a2.guest_policy = 'paid', false) desc,
              he.verified desc
     limit 1;
  end if;

  if v_prog_id is null then
    select he.program_id into v_prog_id
      from host_entitlements he where he.user_id = v_av.host_id
     order by he.verified desc limit 1;
  end if;

  if v_prog_id is null then
    v_prog_id := public.match_program_by_text(
      array_to_string(coalesce(v_av.access_sources, '{}'::text[]), ' '));
  end if;

  if v_prog_id is null then
    select public.match_program_by_text(pr.access_source) into v_prog_id
      from profiles pr where pr.user_id = v_av.host_id;
  end if;

  if v_prog_id is not null then
    select * into v_prog from lounge_programs where id = v_prog_id;
    -- 🔴 YENİ: host'un bu programdaki KART TİPİ. Eski gövde bunu hiç
    -- okumuyordu — kararın tier-körlüğünün kökü buydu.
    select he.tier into v_tier
      from host_entitlements he
     where he.user_id = v_av.host_id and he.program_id = v_prog_id
     order by he.verified desc, he.self_reported_at desc nulls last
     limit 1;
  end if;

  -- ---- 1) SALON × PROGRAM KABULÜ (103 ile aynı) ----
  if v_venue_id is not null and v_prog_id is not null then
    select * into v_acc from lounge_venue_acceptance
     where venue_id = v_venue_id and program_id = v_prog_id and active;
  end if;

  if v_acc.id is not null then
    v_src      := 'venue';
    v_checked  := v_acc.checked_at;
    if not v_acc.accepted then
      return jsonb_build_object(
        'known', true, 'severity', 'block', 'guest_policy', 'not_allowed',
        'venue_id', v_venue_id, 'program', v_prog.code, 'source', 'venue',
        'headline', format('%s bu salonda geçerli değil.', coalesce(v_prog.name,'Bu program')),
        'detail', coalesce(v_acc.conditions, 'Salon bu programı kabul etmiyor; host başka bir salon seçmeli.'));
    end if;
    v_policy   := v_acc.guest_policy;
    v_included := v_acc.guest_included_count;
    v_coupling := v_acc.guest_flight_coupling;
    v_fee      := v_acc.guest_fee_amount;
    v_cur      := v_acc.guest_fee_currency;
    v_fee_note := v_acc.guest_fee_note;
    v_stay     := v_acc.max_stay_hours;
    v_entry    := v_acc.earliest_entry_hours;
    v_enforce  := coalesce(v_acc.enforcement, v_prog.enforcement, 'warn');
    if v_acc.conditions is not null then v_notes := v_notes || v_acc.conditions; end if;
    if v_acc.children_note is not null then v_notes := v_notes || v_acc.children_note; end if;
  end if;

  -- ---- 2) KURAL EKSENİ — ARTIK TEK KAYNAKTAN ----
  -- 🔴 ESKİ HALİ kendi sorgusunu yazıyordu ve üç kusuru vardı:
  -- tier filtresi yok, STAR_ALLIANCE çevirisi yok, venue_scope yok.
  -- resolve_guest_rule üçünü de tek yerden getirir; 156'nın CLPL
  -- iç/dış ayrımı ve Tablo-5 rejimi karara buradan akar.
  if v_prog_id is not null then
    v_rj := public.resolve_guest_rule(v_prog_id, v_venue_id, v_tier, v_av.carrier, null);

    if (v_rj ->> 'blocked_reason') is not null then
      return jsonb_build_object(
        'known', true, 'severity', 'block', 'guest_policy', 'not_allowed',
        'venue_id', v_venue_id, 'program', v_prog.code, 'source', 'rule',
        'tier', v_tier,
        'headline', v_rj ->> 'blocked_reason',
        'detail', coalesce(v_rj ->> 'note', ''));
    end if;

    if coalesce((v_rj ->> 'found')::boolean, false) then
      v_family := coalesce((v_rj ->> 'family_allowed')::boolean, false);

      -- 🔴 İLK KOŞUDA YAKALANAN KUSUR: kabul ekseni (salon×program)
      -- "misafir dahil" deyince, tier kuralı hiç konuşamıyordu —
      -- CLPL host'a bile source=venue'dan included dönüyordu. Kabul
      -- satırı kart TİPİNİ bilemez; TIER-SPESİFİK kural daha özgül
      -- bilgidir ve misafir POLİTİKASINDA kabulü EZER. Salonun
      -- operasyonel bilgileri (ücret/kalış/giriş penceresi) kabulden
      -- gelmeye devam eder.
      --
      -- 🔴 İKİNCİ DÜZELTME: paid_entry_allowed HOST'un ücretli girişi
      -- demektir, misafirin değil. Eski çeviri bunu guest_policy='paid'
      -- yapıyordu — iki ayrı kavramı karıştırıyordu. Misafir sayısı
      -- 0 ise misafir politikası not_allowed'dır; host'un ücretli
      -- girişi member_fee/notta anlatılır.
      if (v_rj ->> 'tier_code') is not null and (v_rj ->> 'tier_code') = v_tier then
        v_policy   := case when coalesce((v_rj ->> 'guest_allowance')::int,0) > 0
                           then 'included' else 'not_allowed' end;
        v_included := coalesce((v_rj ->> 'guest_allowance')::int, 0);
        v_src      := 'rule';
      elsif v_policy is null then
        v_policy := case
          when coalesce((v_rj ->> 'guest_allowance')::int,0) > 0 then 'included'
          else 'not_allowed' end;
        v_included := coalesce((v_rj ->> 'guest_allowance')::int, 0);
        v_src := coalesce(v_src, 'rule');
      end if;
      if v_coupling is null then
        -- 🔴 jsonb_build_object, SQL NULL'u JSON 'null' SKALERİNE çevirir;
        -- jsonb_array_elements_text('null') "cannot extract elements from
        -- a scalar" ile patlar. Önce tip kontrolü ŞART.
        if jsonb_typeof(v_rj -> 'whitelist') = 'array' then
          select array(select jsonb_array_elements_text(v_rj -> 'whitelist')) into v_wl;
        end if;
        v_coupling := case
          when v_wl is not null and array_length(v_wl,1) > 1 then 'same_alliance'
          when coalesce((v_rj ->> 'same_flight_required')::boolean,false) then 'same_carrier'
          else null end;
      end if;
      v_entry := coalesce(v_entry, (v_rj ->> 'entry_hours')::numeric);
      if (v_rj ->> 'note') is not null then v_notes := v_notes || (v_rj ->> 'note'); end if;
    end if;
  end if;

  -- ---- 3) PROGRAM VARSAYILANI (103 ile aynı) ----
  if v_prog_id is not null then
    v_policy   := coalesce(v_policy, v_prog.guest_default, 'unknown');
    v_coupling := coalesce(v_coupling, v_prog.guest_flight_coupling, 'any');
    if v_policy = 'included' and v_included = 0 then
      v_included := v_prog.guest_included_count;
    end if;
    v_fee      := coalesce(v_fee, v_prog.typical_guest_fee);
    v_cur      := coalesce(v_cur, v_prog.guest_fee_currency);
    v_stay     := coalesce(v_stay, v_prog.max_stay_hours);
    v_enforce  := coalesce(v_enforce, v_prog.enforcement, 'warn');
    v_src      := coalesce(v_src, 'program');
    v_checked  := coalesce(v_checked, v_prog.checked_at);
  else
    return jsonb_build_object(
      'known', false, 'severity', 'unknown', 'guest_policy', 'unknown',
      'venue_id', v_venue_id, 'source', 'none',
      'headline', 'Bu ilanın lounge programı belirlenemedi.',
      'detail', 'Host hangi hakla giriyor bilinmiyor; giriş koşullarını kapıda teyit edin.');
  end if;

  -- ---- UÇUŞ BAĞI KONTROLÜ (103 ile aynı; whitelist v_wl'den) ----
  v_host_car := upper(coalesce(v_av.carrier,
                    substring(coalesce(v_av.flight_number,'') from '^[A-Za-z]+')));
  v_g_car    := upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+'));

  if v_coupling = 'same_flight' then
    if coalesce(p_guest_flight,'') = '' or coalesce(v_av.flight_number,'') = '' then
      v_fits := null;
      v_notes := v_notes || ('Bu programda misafirin host ile AYNI UÇUŞTA olması gerekiyor; uçuş numarası girilmeden doğrulanamaz.')::text;
    elsif upper(replace(p_guest_flight,' ','')) <> upper(replace(v_av.flight_number,' ','')) then
      v_fits := false;
      v_notes := v_notes || format('Bu program yalnız aynı uçuştaki misafiri kabul ediyor (host: %s, misafir: %s).',
                                   v_av.flight_number, p_guest_flight);
    end if;

  elsif v_coupling = 'same_carrier' then
    if v_g_car = '' or v_host_car = '' then
      v_fits := null;
      v_notes := v_notes || format('Misafirin de %s seferinde uçuyor olması gerekiyor; uçuş numarası eklenirse kontrol edilir.',
                                   coalesce(nullif(v_host_car,''),'aynı havayolu'));
    elsif v_g_car <> v_host_car then
      v_fits := false;
      v_notes := v_notes || format('Bu salon yalnızca %s seferinde uçan misafirleri kabul ediyor; uçuşun %s.',
                                   v_host_car, p_guest_flight);
    end if;

  elsif v_coupling = 'same_alliance' then
    if v_g_car = '' then
      v_fits := null;
      v_notes := v_notes || ('Misafirin ittifak üyesi bir havayolunda uçması gerekiyor; uçuş numarası eklenirse kontrol edilir.')::text;
    elsif v_wl is not null and not (v_g_car = any(v_wl)) then
      v_fits := false;
      v_notes := v_notes || format('Misafirin taşıyıcısı (%s) bu salonun kabul listesinde değil.', v_g_car);
    end if;
  end if;

  -- ---- SONUCU DERECELENDİR (103 ile aynı) ----
  if v_policy = 'not_allowed' then
    v_sev  := 'block';
    v_head := 'Bu salon/hak birleşiminde misafir alınamıyor.';
  elsif v_fits is false then
    v_sev  := case when v_enforce = 'block' then 'block' else 'warn' end;
    v_head := 'Misafirin uçuşu bu salonun kuralına uymuyor.';
  elsif v_policy = 'unknown' then
    v_sev  := 'warn';
    v_head := 'Bu salonun misafir kuralı henüz doğrulanmadı.';
  elsif v_policy = 'paid' then
    v_sev  := 'warn';
    v_head := case when v_fee is not null
                   then format('Misafir girişi ücretli: yaklaşık %s %s (kapıda tahsil edilir).',
                               trim(to_char(v_fee,'FM999990.00')), coalesce(v_cur,''))
                   else 'Misafir girişi ücretli olabilir (kapıda tahsil edilir).' end;
  elsif v_fits is null then
    v_sev  := 'info';
    v_head := 'Uçuş bilgisi eksik — giriş koşulu kapıda teyit edilmeli.';
  else
    v_sev  := 'ok';
    v_head := case when v_included > 0
                   then format('Misafir hakkı var (%s kişi), ek ücret yok.', v_included)
                   else 'Misafir kabul ediliyor.' end;
  end if;

  if v_checked is null then
    v_notes := v_notes || ('Bu kural henüz resmî kaynaktan doğrulanmadı.')::text;
  elsif v_checked < current_date - 90 then
    v_notes := v_notes || format('Kural %s tarihinde doğrulandı — güncelliğini yitirmiş olabilir.', v_checked);
  end if;

  if v_prog.member_must_be_present then
    v_notes := v_notes || ('Host giriş anında yanında olmalı; erişim hakkı ödünç verilemez.')::text;
  end if;
  if v_prog.guest_needs_boarding_pass then
    v_notes := v_notes || ('Misafirin kendi biniş kartı ve kimliği gerekir.')::text;
  end if;
  if v_stay is not null then
    v_notes := v_notes || format('Salonda kalış süresi yaklaşık %s saatle sınırlı.', trim(to_char(v_stay,'FM990.0')));
  end if;
  if v_entry is not null then
    v_notes := v_notes || format('Girişe en erken kalkıştan %s saat önce başlanabilir.', trim(to_char(v_entry,'FM990.0')));
  end if;

  v_detail := array_to_string(v_notes, ' ');

  return jsonb_build_object(
    'known', true,
    'severity', v_sev,
    'fits', v_fits,
    'guest_policy', v_policy,
    'guest_included_count', v_included,
    'family_allowed', v_family,
    'tier', v_tier,
    'member_fee', v_rj ->> 'member_fee',
    'flight_coupling', v_coupling,
    'guest_fee_amount', v_fee,
    'guest_fee_currency', v_cur,
    'guest_fee_note', v_fee_note,
    'max_stay_hours', v_stay,
    'earliest_entry_hours', v_entry,
    'program', v_prog.code,
    'program_id', v_prog.id,
    'program_name', v_prog.name,
    'entitlement_model', v_prog.entitlement_model,
    'venue_id', v_venue_id,
    'venue_name', v_venue.name,
    'source', v_src,
    'enforcement', v_enforce,
    'checked_at', v_checked,
    'headline', v_head,
    'detail', v_detail
  );
end $$;

-- ---- 3) 🔴 guide_lounges ÇİFT YÜKLEMESİ KAPANIR ----
-- 143'ün 3 parametrelisi düşürülür; 147'nin 5 parametrelisi kalır.
-- App'in 3 adlandırılmış parametreli çağrısı, kalan tek imzaya
-- varsayılanlarla bağlanır — app'te değişiklik GEREKMEZ.
drop function if exists public.guide_lounges(text, text, text);

-- ---- 4) KARAR ZİNCİRİ TESTİ ----
-- 🔴 SEED hostlarına dayanır; SEED'in SONUNDA koşulur (bu dosyada
-- yalnız TANIMLANIR — 157 SEED'den önce çalışır, hostlar henüz yok).
-- Her senaryonun BEKLENEN sonucu koda yazılı.
drop function if exists public.decision_chain_check();
create or replace function public.decision_chain_check()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare d jsonb; v_av uuid;
begin
  -- CLPL + IST dış hat: misafir alınamaz (156'nın kuralı KARARA aktı mı?)
  select a.id into v_av from availabilities a join users u on u.id=a.host_id
   where u.email='kural2@seed.loungelink.test'
   order by a.avail_date, a.time_from, a.id limit 1;
  if v_av is null then
    senaryo:='SEED yüklenmemiş'; beklenen:='-'; gercek:='-'; sonuc:='atlandı'; return next; return;
  end if;
  d := public.lounge_access_decision(v_av, 'TK714');
  senaryo := 'CLPL host, IST DIŞ hat: misafir ALINAMAZ + tier kararda';
  beklenen := 'not_allowed · tier=CLPL';
  gercek := coalesce(d->>'guest_policy','?') || ' · tier=' || coalesce(d->>'tier','YOK');
  sonuc := case when d->>'guest_policy'='not_allowed' and d->>'tier'='CLPL'
                then '✓' else '✗ UYUŞMUYOR' end;
  return next;

  -- ELPL + TK dış hat: aile hakkı kararda görünür
  select a.id into v_av from availabilities a join users u on u.id=a.host_id
   where u.email='kural1@seed.loungelink.test'
   order by a.avail_date, a.time_from, a.id limit 1;
  d := public.lounge_access_decision(v_av, 'TK712');
  senaryo := 'ELPL host, TK dış hat: 1 misafir + AİLE kararda';
  beklenen := 'included 1 · family=true';
  gercek := coalesce(d->>'guest_policy','?')||' '||coalesce(d->>'guest_included_count','?')
         || ' · family=' || coalesce(d->>'family_allowed','?');
  sonuc := case when d->>'guest_policy'='included'
                 and (d->>'guest_included_count')::int=1
                 and (d->>'family_allowed')::boolean
                then '✓' else '✗ UYUŞMUYOR' end;
  return next;

  -- ELPL + LH ilanı: Star Alliance satırı ARTIK erişilebilir → aile YOK
  select a.id into v_av from availabilities a join users u on u.id=a.host_id
   where u.email='kural10@seed.loungelink.test'
   order by a.avail_date, a.time_from, a.id limit 1;
  d := public.lounge_access_decision(v_av, 'LH1302');
  senaryo := 'Star Gold host, LH ilanı: misafir var, karar bilinir';
  beklenen := 'included 1';
  gercek := coalesce(d->>'guest_policy','?')||' '||coalesce(d->>'guest_included_count','?');
  sonuc := case when d->>'guest_policy'='included'
                 and coalesce((d->>'guest_included_count')::int,0)>=1
                then '✓' else '✗ UYUŞMUYOR' end;
  return next;

  -- CLASSIC: ücretli giriş yolu, misafir yok
  select a.id into v_av from availabilities a join users u on u.id=a.host_id
   where u.email='kural11@seed.loungelink.test'
   order by a.avail_date, a.time_from, a.id limit 1;
  if v_av is not null then
    d := public.lounge_access_decision(v_av, null);
    senaryo := 'CLASSIC host: misafir alınamaz (ücretli kendi girişi notta)';
    beklenen := 'not_allowed';
    gercek := coalesce(d->>'guest_policy','?');
    sonuc := case when d->>'guest_policy'='not_allowed' then '✓' else '✗ UYUŞMUYOR' end;
    return next;
  end if;

  -- guide_lounges: tek aşırı yükleme kaldı mı? (PostgREST belirsizliği ölçümü)
  senaryo := 'guide_lounges TEK imza (PostgREST belirsizliği yok)';
  beklenen := '1';
  select count(*)::text into gercek from pg_proc
   where proname='guide_lounges' and pronamespace='public'::regnamespace;
  sonuc := case when gercek='1' then '✓' else '✗ UYUŞMUYOR' end;
  return next;
end $$;
grant execute on function public.decision_chain_check() to authenticated;

select '157 OK - karar zinciri cozumleyiciye baglandi' as sonuc;
