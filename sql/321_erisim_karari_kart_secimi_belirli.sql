-- ============================================================================
-- 321 · ERİŞİM KARARI: KART SEÇİMİ BELİRLİ  (4 Ekim 2026)
--
-- BULGU (uçtan uca test · Keşfet): ilanda program seçilmemişse ve salonda o
-- kartlar için kabul tanımı yoksa lounge_access_decision_prebase host'un kartını
-- `order by verified desc limit 1` ile seçiyordu. Birden çok doğrulanmış kartta
-- sonuç SATIR SIRASINA bağlıydı: Tuna'nın IST ilanları aynı gün içinde önce
-- "Misafir ücretsiz · İstek gönder", sonra "Misafir alınmıyor · Başvuru kapalı"
-- gösterdi; istek kapısı (create_request) aynı kararı kullandığı için başvuru da
-- bir açılıp bir kapanıyordu.
-- DÜZELTME: eşitlikte belirli sıra — kademesi bilinen kart, sonra host'un ilk
-- eklediği kart, sonra program_id. Gövde CANLI tanımın üstüne eklendi.
-- Supabase SQL Editor: tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.lounge_access_decision_prebase(p_avail_id uuid, p_guest_flight text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
              he.verified desc,
              -- 321 · eşitlikte BELİRLİ seçim (aşağıdaki nota bak)
              (he.tier is not null) desc, he.created_at, he.program_id
     limit 1;
  end if;

  if v_prog_id is null then
    select he.program_id into v_prog_id
      from host_entitlements he where he.user_id = v_av.host_id
     -- 🔴 321 · BU SATIR KEYFİ SEÇİYORDU. Salonda kabul tanımı olmayan ilanda host'un
     -- birden çok doğrulanmış kartı varsa `order by verified desc limit 1` satır sırasına
     -- kalıyordu: aynı ilan bir sorguda "Misafir ücretsiz" (TK_MS · ELPL), bir sonrakinde
     -- "Misafir alınmıyor" (Priority Pass) çıktı — uçtan uca testte ölçüldü (Tuna · IST).
     -- Rozet, istek kapısı ve kapıdaki karar aynı ilan için DEĞİŞEBİLİYORDU.
     -- Artık belirli: kademesi (tier) bilinen kart > host'un ilk eklediği kart > program_id.
     order by he.verified desc, (he.tier is not null) desc, he.created_at, he.program_id limit 1;
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
     order by he.verified desc, he.self_reported_at desc nulls last, (he.tier is not null) desc, he.created_at, he.id
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
    v_rj := public.resolve_guest_rule(v_prog_id, v_venue_id, v_tier, v_av.carrier,
       /* 191-kabin: ilanin kabini. Bos ise null gider ve davranis
          bugunkuyle AYNI kalir — geriye tam uyumlu. */
       (select a2.cabin_class from availabilities a2 where a2.id = p_avail_id));

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
      -- 🔴 174: Kural, kabul satırını yalnız İKİ durumda ezer:
      --   (a) kural O SALONA ÖZELSE (venue_scope/venue eşleşmesi), ya da
      --   (b) salonun kabul satırı misafiri zaten YASAKLAMIYORSA.
      -- Salonun "bu bölüm misafir almıyor" bilgisi, programın genel
      -- "bu kart 1 misafir alır" cümlesinden daha özgüldür. Aksi hâlde
      -- host'a misafirini getir denir ve kapıda geri çevrilir.
      if (v_rj ->> 'tier_code') is not null and (v_rj ->> 'tier_code') = v_tier
         and (coalesce(v_acc.guest_policy, '') <> 'not_allowed'
              or (v_rj ->> 'venue_scope') is not null) then
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
  v_host_car := coalesce(upper(coalesce(v_av.carrier,
                    substring(coalesce(v_av.flight_number,'') from '^[A-Za-z]+'))), '');
  -- 281/R1: substring eşleşmezse NULL döner ve `= ''` karşılaştırması
  -- FALSE olur → "bilinmiyor" dalı hiç çalışmaz, fits TRUE kalırdı.
  v_g_car    := coalesce(upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+')), '');

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
end $function$;

select 'kart secimi belirli' as kontrol,
       position('(he.tier is not null) desc, he.created_at, he.program_id limit 1' in
                pg_get_functiondef('public.lounge_access_decision_prebase(uuid,text)'::regprocedure)) > 0 as tamam;
-- Beklenen: tamam = true.
