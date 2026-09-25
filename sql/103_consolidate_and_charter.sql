-- ============================================================
-- LoungeLink · 103_consolidate_and_charter.sql
-- KURAL MOTORUNUN İLK GERÇEK SINAVINDA ÇIKAN İKİ KUSUR
--
-- ⚠️ Uygulamayı ETKİLER (veri + karar mantığı).
--
-- Bu iki kusuru, bu ortama gerçek PostgreSQL kurup 122 migration'ı
-- baştan sona çalıştırıp seed senaryolarını sorgulayınca buldum
-- (rnapp/pg_run.py). Statik denetimlerin hiçbiri göremezdi: ikisi de
-- SÖZDİZİMİ DOĞRU, VERİSİ YANLIŞ.
--
-- ------------------------------------------------------------
-- 🔴 KUSUR 1: HER THY İLANI "CHARTER" SANILIP ENGELLENİYOR
-- ------------------------------------------------------------
-- 085, lounge_guest_rules'a bir satır eklemiş:
--   blocked_reason = 'Charter (tarifesiz) seferlerde bilet sınıfı ne
--                     olursa olsun salon kullanımı yok.'
-- Ama o satırın "bu ilan charter mı?" diye soracak bir koşulu YOK —
-- charter bilgisi (availabilities.is_charter) ancak 101'de geldi.
--
-- Üstüne 086'nın karar motoru şöyle sıralıyordu:
--     order by (venue_id is not null) desc,
--              (blocked_reason is not null) desc,   <-- 🔴 İKİNCİ SIRADA
--              (carrier is not null) desc,
--              (card_tier is not null) desc
-- Yani GENEL bir engel, ÖZEL bir kuralı eziyordu. Sonuç: Elite Plus
-- kartlı, tarifeli TK uçuşu olan bir host bile "charter" diye
-- engelleniyordu. Seed senaryolarında kural1, kural2, kural3, kural8
-- ve kural9'un hepsi aynı sebeple bloklandı.
--
-- İKİ DÜZELTME:
--   a) Koşulsuz charter engelini lounge_guest_rules'tan KALDIR.
--      Charter artık 101'in charter_note()'u ile ele alınıyor ve o,
--      availabilities.is_charter'a bakıyor — yani gerçekten charter
--      olan ilanı engelliyor, hepsini değil.
--   b) Sıralamayı düzelt: ÖZGÜLLÜK her zaman genel engelin ÜSTÜNDE.
--      Genel bir yasak, kendisinden daha özel bir kuralı ezmemeli.
-- ============================================================

-- (a) Kosulsuz charter engelini kaldir
update lounge_guest_rules
   set effective_to = current_date - 1,
       notes = coalesce(notes,'') || ' [103] Kosulsuz charter engeli KALDIRILDI: '
            || 'bu satirin "ilan charter mi" diye soracak bir kosulu yoktu ve '
            || 'TUM THY ilanlarini engelliyordu. Charter artik charter_note() '
            || 'ile availabilities.is_charter uzerinden degerlendiriliyor.'
 where blocked_reason ilike '%charter%'
   and venue_id is null and card_tier is null;

-- (b) Karar motorunda siralama: OZGULLUK once
drop function if exists public.lounge_access_decision(uuid, text);

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
  v_rule      lounge_guest_rules%rowtype;
  v_venue_id  uuid;
  v_prog_id   uuid;
  v_policy    text;
  v_coupling  text;
  v_included  smallint := 0;
  v_fee       numeric;
  v_cur       text;
  v_fee_note  text;
  v_stay      numeric;
  v_entry     numeric;
  v_enforce   text;
  v_src       text;          -- kararın hangi eksenden geldiği
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

  -- ---- PROGRAM SEÇİMİ ----------------------------------------------
  -- Öncelik: ilanda seçilmiş > host'un SALONUN KABUL ETTİĞİ bir hakkı >
  -- ilanın erişim kaynağı metni > profil beyanı.
  -- Ortadaki adım iki eksenin kesişimi: host'un üç hakkı varsa, bu
  -- salonda geçerli OLANI seçeriz.
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
  end if;

  -- ---- 1) SALON × PROGRAM KABULÜ -----------------------------------
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

  -- ---- 2) PROGRAM × KOŞUL KURALI (kart tipi / kabin) ----------------
  -- Yalnız salon ekseninin boş bıraktığı alanları doldurur.
  if v_prog_id is not null then
    select r.* into v_rule
      from lounge_guest_rules r
     where r.program_id = v_prog_id
       and (r.venue_id is null or r.venue_id = v_venue_id)
       and (r.carrier is null or r.carrier = coalesce(v_av.carrier, r.carrier))
       and (r.effective_from is null or r.effective_from <= current_date)
       and (r.effective_to   is null or r.effective_to   >= current_date)
     -- 🔴 103: SIRALAMA DUZELTILDI. Eskiden `blocked_reason is not null`
     -- IKINCI siradaydi ve GENEL bir engel, OZEL bir kurali eziyordu:
     -- kosulsuz charter satiri tum THY ilanlarini blokluyordu.
     -- Dogru sira: once salon, sonra tasiyici, sonra kart tipi (yani
     -- OZGULLUK), engel ancak esit ozgullukte belirleyici olsun.
     order by (r.venue_id is not null) desc,
              (r.carrier is not null) desc,
              (r.card_tier is not null) desc,
              (r.blocked_reason is not null) desc,
              r.created_at
     limit 1;

    if v_rule.id is not null then
      if v_rule.blocked_reason is not null then
        return jsonb_build_object(
          'known', true, 'severity', 'block', 'guest_policy', 'not_allowed',
          'venue_id', v_venue_id, 'program', v_prog.code, 'source', 'rule',
          'headline', v_rule.blocked_reason,
          'detail', coalesce(v_rule.notes, ''));
      end if;
      if v_policy is null then
        v_policy   := case when v_rule.guest_allowance > 0 then 'included'
                           when v_rule.paid_entry_allowed then 'paid'
                           else 'not_allowed' end;
        v_included := v_rule.guest_allowance;
        v_src      := coalesce(v_src, 'rule');
      end if;
      if v_coupling is null then
        v_coupling := case
          when v_rule.guest_carrier_whitelist is not null
               and array_length(v_rule.guest_carrier_whitelist,1) > 1 then 'same_alliance'
          when v_rule.guest_must_match_carrier then 'same_carrier'
          else null end;
      end if;
      v_entry := coalesce(v_entry, v_rule.earliest_entry_hours);
      if v_rule.notes is not null then v_notes := v_notes || v_rule.notes; end if;
    end if;
  end if;

  -- ---- 3) PROGRAM VARSAYILANI --------------------------------------
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
    -- ---- 4) BİLİNMİYOR ---------------------------------------------
    return jsonb_build_object(
      'known', false, 'severity', 'unknown', 'guest_policy', 'unknown',
      'venue_id', v_venue_id, 'source', 'none',
      'headline', 'Bu ilanın lounge programı belirlenemedi.',
      'detail', 'Host hangi hakla giriyor bilinmiyor; giriş koşullarını kapıda teyit edin.');
  end if;

  -- ---- UÇUŞ BAĞI KONTROLÜ ------------------------------------------
  v_host_car := upper(coalesce(v_av.carrier,
                    substring(coalesce(v_av.flight_number,'') from '^[A-Za-z]+')));
  v_g_car    := upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+'));

  if v_coupling = 'same_flight' then
    if coalesce(p_guest_flight,'') = '' or coalesce(v_av.flight_number,'') = '' then
      v_fits := null;   -- doğrulanamıyor
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
    elsif v_rule.guest_carrier_whitelist is not null
          and not (v_g_car = any(v_rule.guest_carrier_whitelist)) then
      v_fits := false;
      v_notes := v_notes || format('Misafirin taşıyıcısı (%s) bu salonun kabul listesinde değil.', v_g_car);
    end if;
  end if;

  -- ---- SONUCU DERECELENDİR -----------------------------------------
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

  -- Bayat kural, bilgiyi zayıflatır ama engel değildir
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
grant execute on function public.lounge_access_decision(uuid, text) to authenticated;


-- ============================================================
-- 🔴 KUSUR 2: AYNI SALON ÜÇ KUŞAK, DÖRT ADLA KATALOGDA
-- ------------------------------------------------------------
-- IST'te tek bir Turkish Airlines salonu için 15 kabul satırı vardı:
--   'Turkish Airlines Lounge Business'                  (086)
--   'Turkish Airlines Lounge — Dis Hat (Business)'      (086, ASCII yazim)
--   'Turkish Airlines Lounge — Dış Hat (Business)'      (098, Turkce yazim)
--   'Turkish Airlines Lounge — Dış Hat' + section       (098 bolum)
--   'Turkish Airlines Lounge — Dış Hat' (ust kayit)     (101)
--
-- Her turda ADLANDIRMAYI degistirdim ama ESKIYI TEMIZLEMEDIM. Sonuc:
-- host ayni salonu dort farkli adla goruyor ve HANGISINI SECTIGINE GORE
-- FARKLI CEVAP aliyor. Kural motoru dogru calissa bile, yanlis satira
-- bagli bir ilan yanlis karar uretir.
--
-- BIRLESTIRME MANTIGI:
--   · Ad normalize edilir: Turkce/ASCII farki, '(Business)' /
--     '(Miles&Smiles)' ekleri, cizgi ve bosluk farklari silinir.
--   · Ayni (havalimani, normalize ad, bolum) grubunda TEK kanonik satir
--     secilir: en cok kabul satiri olan, esitlikte en yeni.
--   · Digerlerinin kabul satirlari kanonige TASINIR (kanonikte o program
--     yoksa), ilanlar ve katalog kayitlari kanonige YONLENDIRILIR.
--   · Mukerrerler SILINMEZ, PASIFE ALINIR — gecmis kaybolmasin.
-- ============================================================

create or replace function public.venue_norm(p_name text)
returns text language sql immutable as $$
  select regexp_replace(
           regexp_replace(
             lower(translate(coalesce(p_name,''),
                             'ıİşŞğĞüÜöÖçÇ', 'iisSgGuUoOcC')),
             '\s*\((business|miles&smiles|ic hat|dis hat)\)\s*', ' ', 'gi'),
           '[^a-z0-9]+', '', 'g');
$$;

-- 🔴 YARDIMCI TABLO YOK.
-- Once temp table, sonra GERCEK tablo denedim; Supabase SQL Editor
-- ifadeleri ayri calistirdigi icin ikisi de "relation does not exist"
-- verdi. 099'da ayni dersi almistim ama 103'e uygulamamisim.
-- Kok cozum: ifadeler arasi bagimliligi TAMAMEN kaldirmak. Kanonik
-- salon listesi artik her ifadenin ICINDE bir CTE. Tekrar var ama
-- hicbir ifade oncekinin yan etkisine bagli degil.

-- Kabul satirlarini kanonige tasi (kanonikte o program YOKSA)
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_fee_amount, guest_fee_currency, guest_fee_note, guest_flight_coupling,
   max_stay_hours, earliest_entry_hours, children_note, enforcement,
   conditions, source_url, checked_at, active)
select c.canon_id, a.program_id, a.accepted, a.guest_policy, a.guest_included_count,
       a.guest_fee_amount, a.guest_fee_currency, a.guest_fee_note, a.guest_flight_coupling,
       a.max_stay_hours, a.earliest_entry_hours, a.children_note, a.enforcement,
       a.conditions, a.source_url, a.checked_at, a.active
  from _ll_canon c
  join lounge_venue_acceptance a on a.venue_id = c.id
 where not exists (select 1 from lounge_venue_acceptance x
                    where x.venue_id = c.canon_id and x.program_id = a.program_id)
on conflict (venue_id, program_id) do nothing;

-- 🔴 KART TIPI KURALLARINI DA TASI.
-- Ilk yazimda yalniz kabul satirlarini tasidim; lounge_guest_rules'un
-- venue_id'si pasife alinan mukerrer salonda kaldi. Karar motoru
--   (r.venue_id is null or r.venue_id = v_venue_id)
-- diye ariyor; kural bulunamayinca KART TIPI KAPISI HIC CALISMIYORDU.
-- Sonuc: Classic Plus'li host'a "misafir hakkin var" deniyordu — yani
-- kapatmaya calistigimiz asil hata geri geliyordu.
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_guest_rules r set venue_id = c.canon_id
  from _ll_canon c
 where r.venue_id = c.id
   and not exists (select 1 from lounge_guest_rules x
                    where x.program_id = r.program_id
                      and x.venue_id = c.canon_id
                      and coalesce(x.card_tier,'') = coalesce(r.card_tier,''));

-- Kanonikte ayni kural zaten varsa mukerrer satiri suresiz kapat
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_guest_rules r set effective_to = current_date - 1
  from _ll_canon c
 where r.venue_id = c.id;

-- Katalog ve ilanlari kanonige yonlendir
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounges l set venue_id = c.canon_id
  from _ll_canon c where l.venue_id = c.id;

-- 🔴 UPDATE ... FROM icinde, guncellenen tabloya (a) FROM tarafindan
-- JOIN ile baglanilamaz. Ilk yazimda `join lounges lo on lo.id = a.lounge_id`
-- diyordum: PostgreSQL "invalid reference to FROM-clause entry" verdi.
-- Dogru bicim: iliskiyi WHERE'de kur, JOIN'i FROM icinde tut.
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update availabilities a
   set lounge_id = k.legacy_lounge_id
  from _ll_canon c
  join lounge_venues k on k.id = c.canon_id
  join lounge_venues d on d.id = c.id
 where a.lounge_id = d.legacy_lounge_id
   and k.legacy_lounge_id is not null
   and k.legacy_lounge_id <> a.lounge_id;

-- Mukerrerleri pasife al (SILME — gecmis kalsin)
with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_venue_acceptance a set active = false
  from _ll_canon c where a.venue_id = c.id;

with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounges l set active = false
  from lounge_venues v join _ll_canon c on c.id = v.id
 where l.venue_id = v.id;

with _ll_canon as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             order by v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (select count(*) from lounge_venue_acceptance a where a.venue_id = lv.id) as n_acc
          from lounge_venues lv
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_venues v set active = false,
       notes = coalesce(v.notes,'') || ' [103] Mukerrer kayit — kanonik salona birlestirildi.'
  from _ll_canon c where v.id = c.id;



-- ============================================================
-- DOGRULAMA
-- ============================================================
select v.airport_code, v.name, coalesce(v.section,'-') as bolum, v.active,
       count(a.*) filter (where a.active) as aktif_kabul
  from lounge_venues v
  left join lounge_venue_acceptance a on a.venue_id = v.id
 where v.airport_code = 'IST'
 group by v.airport_code, v.name, v.section, v.active
 order by v.active desc, v.name;

select count(*) filter (where active) as aktif_salon,
       count(*) filter (where not active) as pasif_mukerrer
  from lounge_venues;

select '103 OK - charter engeli kosula baglandi, mukerrer salonlar birlestirildi' as sonuc;
