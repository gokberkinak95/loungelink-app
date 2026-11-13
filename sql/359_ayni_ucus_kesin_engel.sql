-- ============================================================================
-- 359 · AYNI UÇUŞ ŞARTI: FARKLI UÇUŞ KESİNSE ENGEL, DEĞİLSE UYARI + ONAY  (13 Kasım 2026)
--
-- KARAR (Gökberk, 13 Kasım): "iki uçuş numarası da biliniyor ve farklıysa kesin engel;
-- uçuş numarası girilmemişse eskisi gibi uyarı + onay."
--
-- KURAL: DragonPass md.7.15.7 — misafir üyeyle AYNI UÇUŞTA olmalı. Veride yalnız DragonPass
-- bu şartı taşıyor (34 salon satırı). Salon satırları 'warn' idi; o 'warn' salonun KİMLİĞİ
-- belirsiz diye konmuştu (214 §7), uçuş şartı için değil. Sonuç: farklı uçuştaki misafir
-- onay kutusunu işaretleyip istek atabiliyordu (358 testinde 63 kombinasyon), kapıda dönerdi.
--
-- NE ZAMAN KESİN ENGEL (ayni_ucus_durumu = 'farkli'):
--   · iki numara da var, yazım farkı ayıklandıktan sonra farklı VE
--   · aynı havayolu (TK1985 ↔ TK2000: kesin iki ayrı sefer) YA DA uçuş önbelleği iki seferin
--     de işleten uçuşunu biliyor ve farklı.
-- NE ZAMAN UYARI + ONAY:
--   · misafirin ya da host'un uçuş numarası yok ('eksik')
--   · havayolları farklı ve önbellek bilmiyor ('belirsiz'): kod paylaşımlı AYNI sefer olabilir
--     (bilette LH6543, uçağı TK1985). Bunu engellemek "başvurabileceği ilana başvuramama" olurdu.
-- YAZIM FARKI: TK01985 = TK 1985 = tk1985 → aynı uçuş (eskiden uyarı veriyordu).
--
-- KATMANLAR (hepsi tek karardan okur — kart, ön kontrol, kural satırı, sunucu aynı şeyi der):
--   §1 ucus_no_norm · ucus_tasiyici · ayni_ucus_durumu (yeni yardımcılar)
--   §2 lounge_access_decision_v6: 'same_flight_state' + 'same_flight_block'
--   §3 create_request_impl_preflag: kesin engelde 'blocked_by_rule' (uygulamada TR/EN karşılığı VAR)
--   §4 request_precheck_pregate: başlık + ilk cümle aynı uçuş şartını söyler; belirsizse onay şart
--   §5 discovery_rule_badges: kesin engelde kart kapalı + sebep; belirsizse "Aynı uçuş şartı" bilgisi
--   §6 kural_kosullari: 'yok' yalnız kesin farklı uçuşta; belirsiz/eksik 'bilinmiyor'
--   §7 metinler (TR + EN, public.metin)
--   §8 bilgi: bekleyen isteklerden kaçı kesin farklı uçuşta (DEĞİŞTİRMEZ)
-- APP SÜRÜMÜ GEREKMEZ: uygulama başlık/açıklama/rozet metnini sunucudan okuyor; yeni hata kodu YOK.
--
-- KOŞMA: SQL Editor → tamamı → Run. Tekrar koşulabilir. Son tablo: hepsi tamam = true.
-- ============================================================================

-- §7 önce: metinler (fonksiyonlar bunları okur)
insert into beta_settings (key, value) values
  ('ayni_ucus_baslik_farkli',            to_jsonb('Aynı uçuşta değilsiniz'::text)),
  ('ayni_ucus_baslik_farkli_en',         to_jsonb('You''re not on the same flight'::text)),
  ('ayni_ucus_baslik_belirsiz',          to_jsonb('Uçuş numaralarınız farklı'::text)),
  ('ayni_ucus_baslik_belirsiz_en',       to_jsonb('Your flight numbers differ'::text)),
  ('ayni_ucus_baslik_eksik',             to_jsonb('Bu salonda aynı uçuş şartı var'::text)),
  ('ayni_ucus_baslik_eksik_en',          to_jsonb('This lounge requires the same flight'::text)),
  ('ayni_ucus_detay_farkli',             to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Host {h}, sen {g} ile uçuyorsun; kapıda reddedilirdin.'::text)),
  ('ayni_ucus_detay_farkli_en',          to_jsonb('This lounge only admits guests on the host''s flight. The host flies {h}, you fly {g}; you''d be refused at the door.'::text)),
  ('ayni_ucus_detay_belirsiz',           to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Numaralar farklı ({h}/{g}); kod paylaşımlı aynı sefer değilse dönersin.'::text)),
  ('ayni_ucus_detay_belirsiz_en',        to_jsonb('This lounge only admits guests on the host''s flight. Numbers differ ({h}/{g}); unless it''s one codeshare flight, you''ll be refused.'::text)),
  ('ayni_ucus_detay_misafir_ucussuz',    to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Seyahatine uçuş numaranı ekle; farklı uçuştaysan kapıda dönersin.'::text)),
  ('ayni_ucus_detay_misafir_ucussuz_en', to_jsonb('This lounge only admits guests on the host''s flight. Add your flight number to your trip; on another flight you''ll be refused.'::text)),
  ('ayni_ucus_detay_host_ucussuz',       to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Host uçuşunu girmedi; aynı uçuşta değilseniz kapıda dönersin.'::text)),
  ('ayni_ucus_detay_host_ucussuz_en',    to_jsonb('This lounge only admits guests on the host''s flight. The host hasn''t added a flight; if it isn''t yours, you''ll be refused.'::text)),
  ('rozet_rule_same_flight',             to_jsonb('Aynı uçuşta değilsiniz'::text)),
  ('rozet_rule_same_flight_en',          to_jsonb('Not on the same flight'::text)),
  ('rozet_rule_same_flight_bilgi',       to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Seyahatindeki uçuş numarası host''unkinden farklı.'::text)),
  ('rozet_rule_same_flight_bilgi_en',    to_jsonb('This lounge only admits guests on the host''s flight. The flight on your trip differs from the host''s.'::text)),
  ('rozet_same_flight_check',            to_jsonb('Aynı uçuş şartı'::text)),
  ('rozet_same_flight_check_en',         to_jsonb('Same-flight rule'::text)),
  ('rozet_same_flight_check_bilgi',      to_jsonb('Bu salon misafiri yalnız host''la aynı uçuştaysa alıyor. Uçuş numaranı seyahatine ekle; farklı uçuştaysan kapıda dönersin.'::text)),
  ('rozet_same_flight_check_bilgi_en',   to_jsonb('This lounge only admits guests on the host''s flight. Add your flight number to your trip; on another flight you''ll be refused.'::text))
on conflict (key) do update set value = excluded.value;

-- §1 · yardımcılar
create or replace function public.ucus_no_norm(p text)
returns text language plpgsql immutable set search_path = public as $un359$
declare x text := upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')); m text[];
begin
  if x = '' then return null; end if;
  m := regexp_match(x, '^([A-Z0-9]{2})([0-9]{1,5})([A-Z]?)$');
  if m is null then return x; end if;
  return m[1] || coalesce(nullif(ltrim(m[2], '0'), ''), '0') || m[3];
end $un359$;

create or replace function public.ucus_tasiyici(p text)
returns text language sql immutable set search_path = public as $ut359$
  select (regexp_match(upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')),
                       '^([A-Z0-9]{2})[0-9]{1,5}[A-Z]?$'))[1];
$ut359$;

-- 'ayni' | 'farkli' (kesin) | 'belirsiz' (havayolları farklı, kod paylaşımı olabilir) | 'eksik'
create or replace function public.ayni_ucus_durumu(p_host text, p_guest text, p_date date default null)
returns text language plpgsql stable security definer set search_path = public as $au359$
declare h text := public.ucus_no_norm(p_host); g text := public.ucus_no_norm(p_guest);
  h_op text; g_op text;
begin
  if h is null or g is null then return 'eksik'; end if;
  if h = g then return 'ayni'; end if;
  -- önbellek: kod paylaşımlı seferde 'codeshared' işleten uçuşu taşır; yoksa sefer kendisidir
  select public.ucus_no_norm(coalesce(nullif(fc.codeshared ->> 'flight_iata', ''), fc.flight_no)) into h_op
    from flight_cache fc
   where public.ucus_no_norm(fc.flight_no) = h and (p_date is null or fc.flight_date = p_date)
   order by fc.flight_date desc limit 1;
  select public.ucus_no_norm(coalesce(nullif(fc.codeshared ->> 'flight_iata', ''), fc.flight_no)) into g_op
    from flight_cache fc
   where public.ucus_no_norm(fc.flight_no) = g and (p_date is null or fc.flight_date = p_date)
   order by fc.flight_date desc limit 1;
  if coalesce(h_op, h) = coalesce(g_op, g) then return 'ayni'; end if;
  if h_op is not null and g_op is not null then return 'farkli'; end if;
  -- aynı havayolunun iki numarası aynı sefer olamaz (kod paylaşımı eşitliği yukarıda soruldu);
  -- önbellekte yalnız biri olsa da kesin farklıdır
  if public.ucus_tasiyici(h) is not null and public.ucus_tasiyici(h) = public.ucus_tasiyici(g) then
    return 'farkli';
  end if;
  return 'belirsiz';
end $au359$;
grant execute on function public.ayni_ucus_durumu(text, text, date) to authenticated;

-- §2 · karar (284'ün gövdesi + 13. boyut)
CREATE OR REPLACE FUNCTION public.lounge_access_decision_v6(p_avail_id uuid, p_guest_flight text DEFAULT NULL::text, p_guest_carrier text DEFAULT NULL::text, p_guest_visit_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $v6359$
declare
  d jsonb; v_av availabilities%rowtype; v_vis visits%rowtype; v_venue lounge_venues%rowtype;
  v_prog lounge_programs%rowtype; v_acc lounge_venue_acceptance%rowtype;
  v_sev text; v_block text; v_notes text[] := '{}';
  v_party int; v_limit int; v_party_ok boolean;
  v_child_pol text; v_child_lim int; v_child_ok boolean; v_has_child boolean; v_min_child int;
  v_scope text; v_side text; v_scope_ok boolean;
  v_serves text; v_serves_ok boolean;
  v_fee_payer text;
  v_stay numeric; v_win numeric; v_stay_ok boolean;
  v_cap int;
  v_cabin_ok boolean; v_cabin_req boolean := false;
  v_kota jsonb; v_kota_ok boolean;
  v_flight_ok boolean; v_same_day boolean;
  v_su text; v_su_kesin boolean := false;   -- 359 · aynı uçuş
begin
  d := public.lounge_access_decision_v5(p_avail_id, p_guest_flight, p_guest_carrier);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;
  if p_guest_visit_id is not null then
    select * into v_vis from visits where id = p_guest_visit_id;
  end if;
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;
  if (d ->> 'venue_id') is not null then
    select * into v_venue from lounge_venues where id = (d ->> 'venue_id')::uuid;
    if v_prog.id is not null then
      select * into v_acc from lounge_venue_acceptance
       where venue_id = v_venue.id and program_id = v_prog.id and active;
    end if;
  end if;
  v_sev := coalesce(d ->> 'severity', 'info');

  -- 1 · KİŞİ SAYISI. Misafir 1 kişi sayar; visits.party_size yoksa 1.
  v_party := coalesce(v_vis.party_size, 1);
  v_limit := nullif(d ->> 'guest_included_count','')::int;
  if (d ->> 'guest_policy') = 'included' then
    v_party_ok := v_limit is null or v_party <= greatest(v_limit, 1);
    if v_party_ok is false then
      v_block := coalesce(v_block, 'party_too_big');
      v_notes := v_notes || format('Bu hak %s misafir alıyor, sen %s kişisin.', v_limit, v_party);
    end if;
  elsif (d ->> 'guest_policy') = 'paid' then
    v_party_ok := true;   -- ücretli: kişi başı ödenir, kapı kapanmaz
  else
    v_party_ok := null;
  end if;

  -- 2 · ÇOCUK. Politika NULL ise bilinmiyor; uydurmuyoruz.
  v_has_child := v_vis.child_ages is not null and array_length(v_vis.child_ages,1) > 0;
  v_child_pol := coalesce(v_acc.children_policy, v_prog.children_policy);
  v_child_lim := coalesce(v_acc.child_age_limit, v_prog.child_age_limit);
  if v_has_child then
    select min(x) into v_min_child from unnest(v_vis.child_ages) x;
    if v_child_pol is null then v_child_ok := null;
    elsif v_child_pol = 'allowed' then v_child_ok := true;
    elsif v_child_pol = 'not_allowed' then v_child_ok := false;
    elsif v_child_pol = 'age_limit' then v_child_ok := v_child_lim is null or v_min_child >= v_child_lim;
    else v_child_ok := true;  -- free_under: girer, üstelik haktan sayılmaz
    end if;
    if v_child_ok is false then
      v_block := 'children_not_allowed';   -- kişi sayısından ÖNCE gelir: çocuk hiç giremiyorsa sayı anlamsız
      v_notes := v_notes || (case when v_child_pol = 'age_limit'
        then format('Bu salon %s yaş altını almıyor.', v_child_lim)
        else 'Bu salon çocuk misafir almıyor.' end)::text;
    end if;
    -- free_under: küçük çocuklar kişi sayısından düşer
    if v_child_pol = 'free_under' and v_child_lim is not null and v_party_ok is false then
      if v_party - (select count(*) from unnest(v_vis.child_ages) x where x < v_child_lim)
         <= greatest(coalesce(v_limit,0),1) then
        v_party_ok := true; v_block := null;
        v_notes := array_remove(v_notes, v_notes[array_length(v_notes,1)]);
      end if;
    end if;
  end if;

  -- 7 · İÇ HAT / DIŞ HAT. Dış hat salonu pasaport kontrolünün ARKASINDA;
  -- iç hat yolcusu fiziksel olarak ulaşamaz. Bu bir kural değil, duvar.
  v_scope := coalesce(v_venue.scope, 'both');
  v_side  := public.ucus_hatti(v_av.airport_code, v_vis.destination);
  if v_venue.id is null or v_scope = 'both' or v_side is null then
    v_scope_ok := case when v_venue.id is null or v_scope = 'both' then true else null end;
  else
    v_scope_ok := (v_scope = v_side);
    if not v_scope_ok then
      v_block := coalesce(v_block, 'scope_mismatch');
      v_notes := v_notes || (case when v_side = 'domestic'
        then 'Salon dış hatlar tarafında; iç hat uçuşuyla oraya geçilemez.'
        else 'Salon iç hatlar tarafında; dış hat uçuşuyla oraya geçilemez.' end)::text;
    end if;
  end if;

  -- 8 · KALKIŞ / VARIŞ SALONU
  v_serves := v_venue.serves;
  if v_serves is null or v_serves = 'both' then v_serves_ok := case when v_serves = 'both' then true else null end;
  else
    v_serves_ok := case when v_serves = 'arrival' then coalesce(v_vis.purpose,'') = 'connecting' else true end;
    if v_serves_ok is false then
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
      v_notes := v_notes || ('Bu bir varış salonu; kalkış öncesi giriş yok.')::text;
    end if;
  end if;

  -- 5 · ÜCRETİ KİM ÖDER (yalnız ücretli politikada anlamlı)
  v_fee_payer := coalesce(v_acc.fee_payer, v_prog.fee_payer);

  -- 6 · AZAMİ KALIŞ × misafirin planladığı pencere
  v_stay := nullif(d ->> 'max_stay_hours','')::numeric;
  if v_stay is not null and v_vis.id is not null then
    v_win := extract(epoch from (v_vis.time_to - v_vis.time_from)) / 3600.0;
    v_stay_ok := v_win <= v_stay + 0.01;
    if not v_stay_ok then
      v_notes := v_notes || format('Planladığın %s saat, salonun %s saatlik sınırını aşıyor; çıkıp yeniden girmek gerekebilir.',
                                   trim(to_char(v_win,'FM990.0')), trim(to_char(v_stay,'FM990.0')));
    end if;
  end if;

  -- 3 · DOLULUK: son 60 günde aynı saat bandında kapasite reddi
  v_cap := public.doluluk_reddi_sayisi(p_avail_id);
  if v_cap >= 2 then
    v_sev := case when v_sev in ('block') then v_sev else 'warn' end;
    v_notes := v_notes || format('Bu salon bu saatlerde son 60 günde %s kez doluluk nedeniyle misafir almadı.', v_cap);
  end if;

  -- 11 · BİLET SINIFI ŞARTI: bilet sınıfından doğan hak, business/first ister
  if v_prog.entitlement_model = 'ticket_class' then
    v_cabin_req := true;
    v_cabin_ok := case when v_av.cabin_class is null then null
                       else v_av.cabin_class in ('business','first') end;
    if v_cabin_ok is false then
      v_block := coalesce(v_block, 'cabin_required');
      v_notes := v_notes || ('Bu hak bilet sınıfından geliyor; host ekonomi uçuyorsa salon hakkı yok.')::text;
    end if;
  end if;

  -- 12 · HOST'UN DÖNEM KOTASI
  v_kota := public.host_kota_durumu(p_avail_id);
  if coalesce((v_kota ->> 'known')::boolean, false) then
    v_kota_ok := coalesce((v_kota ->> 'left')::int, 1) >= v_party;
    if not v_kota_ok then
      v_block := coalesce(v_block, 'quota_exhausted');
      v_notes := v_notes || format('Host''un bu dönem misafir hakkı bitmiş (%s/%s).',
                                   v_kota ->> 'used', v_kota ->> 'total');
    end if;
  end if;

  -- 10 · BİNİŞ KARTI AYNI GÜN: misafirin uçuşu kayıtlı ve tarih ilanla aynı
  v_same_day := v_vis.id is not null and v_vis.visit_date = v_av.avail_date;
  v_flight_ok := case when v_vis.id is null then null
                      when coalesce(v_vis.flight_number,'') = '' then null
                      else v_same_day end;

  -- 284: kural güncelliği — şüpheli kural en az UYARI, hiçbir şeyi değiştirmez
  declare v_g jsonb;
  begin
    if v_venue.id is not null and v_prog.id is not null then
      v_g := public.kural_guncelligi(v_venue.id, v_prog.id);
      if (v_g ->> 'durum') = 'supheli' then
        v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
        v_notes := v_notes || format('Bu kural son 90 günde kapıda %s kez tutmadı — doğrulanıyor.', v_g ->> 'acik_suphe');
      elsif (v_g ->> 'durum') = 'eski' then
        v_notes := v_notes || ('Bu kural 90 günden eski ve yakın zamanda kapıda doğrulanmadı.')::text;
      end if;
      d := d || jsonb_build_object('freshness', v_g);
    end if;
  end;
  -- 13 · 359 · AYNI UÇUŞ (DragonPass md.7.15.7: misafir üyeyle AYNI UÇUŞTA olmalı).
  -- Kesin engel YALNIZ iki uçuş da biliniyor ve farklı olduğu KESİNSE: aynı havayolu, farklı
  -- numara (TK1985 ↔ TK2000) ya da önbellek iki seferin işletenini de biliyor ve farklı.
  -- Numara yoksa ya da havayolları farklıysa (kod paylaşımlı aynı sefer olabilir): eskisi
  -- gibi uyarı + onay. Yazım farkı (TK01985 = TK1985) uymazlık sayılmaz.
  if coalesce(d ->> 'flight_coupling', '') = 'same_flight' then
    v_su := public.ayni_ucus_durumu(v_av.flight_number, p_guest_flight, v_av.avail_date);
    if v_su = 'farkli' and coalesce(d ->> 'guest_policy', '') <> 'not_allowed' then
      v_su_kesin := true;
      v_sev := 'block';
    elsif v_su = 'ayni' and (d ->> 'fits') = 'false' then
      d := d || jsonb_build_object('fits', true,
             'detail', btrim(replace(coalesce(d ->> 'detail', ''),
               format('Bu program yalnız aynı uçuştaki misafiri kabul ediyor (host: %s, misafir: %s).',
                      v_av.flight_number, p_guest_flight), '')));
      if v_sev = 'block' and coalesce(d ->> 'guest_policy', '') <> 'not_allowed'
         and coalesce(d ->> 'charter', 'false') <> 'true' and coalesce(d ->> 'carrier_ok', '') <> 'false' then
        v_sev := 'warn';
      end if;
    end if;
  end if;

  if v_block is not null then v_sev := 'block'; end if;

  return d || jsonb_build_object(
    'engine', 'v6',
    'severity', v_sev,
    'block_code', v_block,
    'party_size', v_party, 'party_limit', v_limit, 'party_ok', v_party_ok,
    'has_child', v_has_child, 'children_policy', v_child_pol, 'child_age_limit', v_child_lim, 'children_ok', v_child_ok,
    'venue_scope', v_scope, 'guest_side', v_side, 'scope_ok', v_scope_ok,
    'serves', v_serves, 'serves_ok', v_serves_ok,
    'fee_payer', v_fee_payer,
    'stay_ok', v_stay_ok, 'planned_hours', v_win,
    'capacity_refusals_60d', v_cap,
    'cabin_required', v_cabin_req, 'cabin_ok', v_cabin_ok, 'host_cabin', v_av.cabin_class,
    'quota', v_kota, 'quota_ok', v_kota_ok,
    'same_day', v_same_day, 'boarding_pass_ok', v_flight_ok,
    'same_flight_state', v_su, 'same_flight_block', v_su_kesin,   -- 359
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_notes, ' ')));
end $v6359$;

-- §3 · sunucu kapısı
CREATE OR REPLACE FUNCTION public.create_request_impl_preflag(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $cr359$
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
  -- 358 · (engel kontrolünden SONRA: engelli çift kendi sebebini görür) Keşfet'te bu misafire görünmeyen ilana istek yok (host rolü, gölge kısıt,
  -- kadın güvenlik modu, gizli / yalnız bağlantılara açık ilan). Keşfet ile AYNI süzgeç.
  if not public.ilan_misafire_acik_mi(p_avail_id, v_uid) then raise exception 'availability_not_found'; end if;

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
      select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number)), v.id   -- 358: ön kontrolle aynı taşıyıcı çözümü
        into v_gf, v_gc, v_gvid
        from visits v
       where v.user_id = v_uid
         and v.airport_code = v_av.airport_code
         and v.visit_date = v_av.avail_date
         and v.time_from < v_av.time_to and v_av.time_from < v.time_to
       order by (v.flight_number is not null) desc, v.created_at desc
       limit 1;
      v_dec := public.lounge_access_decision_v6(p_avail_id, v_gf, v_gc, v_gvid);   -- 283: on iki boyut
    end;
    -- 359 · aynı uçuş şartı kesin tutmuyor (iki uçuş biliniyor ve farklı): istek sunucuda durur.
    -- Uygulamada karşılığı olan kod (yeni sürüm gerekmez).
    if coalesce((v_dec ->> 'same_flight_block')::boolean, false) then
      raise exception 'blocked_by_rule';
    end if;
    if (v_dec ->> 'block_code') is not null then
      raise exception '%', (v_dec ->> 'block_code');   -- 283: party_too_big / scope_mismatch / quota_exhausted / cabin_required / children_not_allowed
    end if;
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
    -- 358 · ÖN KONTROLLE AYNI KAPI: kesin kural (enforcement=block) ya da charter sefer.
    -- Eskiden yalnız ön kontrol soruyordu: uygulama engelliyor, doğrudan çağrı geçiyordu
    -- (ör. yalnız TK seferindeki misafiri alan salona Pegasus yolcusunun isteği).
    if (v_dec ->> 'severity') = 'block'
       and ((v_dec ->> 'enforcement') = 'block' or coalesce(v_dec ->> 'charter', 'false') = 'true') then
      raise exception '%', case when coalesce(v_dec ->> 'charter', 'false') <> 'true' and (v_dec ->> 'fits') = 'false'
                                then 'guest_carrier_mismatch' else 'guests_not_allowed' end;
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
end $cr359$;

-- §4 · ön kontrol
CREATE OR REPLACE FUNCTION public.request_precheck_pregate(p_avail_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $pc359$

declare

  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;

  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;

  v_credit int; v_tut int := 1; v_bal int; v_qnote text; v_cnote text;

  v_tier text; v_head text; v_key text; v_detail text; v_more text;
  v_su text;   -- 359

begin

  -- 🔴 192-seyahat: SUNUCU KAPISININ AYNISI. create_request

  -- (007:41) ayni havalimani + AYNI TARIH icin seyahat arar.

  -- Precheck bunu hic sormuyordu; ekran "gonderebilirsin" deyip

  -- sunucu ham "no_matching_trip" firlatiyordu.

  if not exists (

       select 1 from visits v

        join availabilities a2 on a2.id = p_avail_id

       where v.user_id = auth.uid()
         and v.airport_code = a2.airport_code
         and v.visit_date  = a2.avail_date
         -- 358 · sunucu kapısıyla AYNI: saatler de çakışmalı (no_matching_trip)
         and v.time_from < a2.time_to and a2.time_from < v.time_to)

  then

    return jsonb_build_object(

      'can_request', false, 'kind', 'trip_gate', 'severity', 'block',

      'headline', 'Bu ilanın saatinde o havalimanında seyahatin yok',

      'detail', 'Bu ilan ' || (select to_char(a3.avail_date, 'DD.MM.YYYY')

                    || ' tarihinde ' || a3.airport_code

                    from availabilities a3 where a3.id = p_avail_id)

                 || '. O gün için bir seyahat ekle, ilan hemen başvurulabilir olsun.',

      'fix_action', 'add_trip',

      'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);

  end if;



  select * into v_av from availabilities where id = p_avail_id;

  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;
  -- 358 · sunucu kapısıyla AYNI görünürlük süzgeci
  if not public.ilan_misafire_acik_mi(p_avail_id, v_uid) then
    return jsonb_build_object('can_request', false, 'gate', 'availability_not_found', 'kind', 'gate',
                              'severity', 'block', 'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);
  end if;



  select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))

    into v_flight, v_carrier

    from visits v

   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and v.time_from < v_av.time_to and v_av.time_from < v.time_to   -- 358: sunucuyla aynı seyahat
   order by (v.flight_number is not null) desc, v.created_at desc limit 1;



  d := public.lounge_access_decision_v6(p_avail_id, v_flight, v_carrier,

         (select v.id from visits v where v.user_id = v_uid and v.airport_code = v_av.airport_code and v.visit_date = v_av.avail_date and v.time_from < v_av.time_to and v_av.time_from < v.time_to order by (v.flight_number is not null) desc, v.created_at desc limit 1));   -- 283

  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

  v_credit := public.paid_guest_credit(p_avail_id);

  v_tut := coalesce(public.request_credit_cost(auth.uid(), p_avail_id), 1);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;

  v_qnote := public.guest_quota_note(v_av.host_id);

  v_cnote := public.card_confidence_note(v_av.host_id);

  v_tier  := public.card_tier_label(d ->> 'host_tier');



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



  -- 🔴 DETAY: KAPIDA ISE YARAYACAK TEK CUMLE.

  -- Onceligi kullanicinin GERI CEVRILME riskine gore veriyoruz:

  -- engel sebebi > ucret > kota > kart guveni. En kritik olan basa.

  v_key := case

    when coalesce((d ->> 'charter'),'false') = 'true' then 'charter'

    when (d ->> 'carrier_ok') = 'false' then 'carrier'

    when (d ->> 'guest_policy') = 'not_allowed' then 'noguest'

    when (d ->> 'guest_policy') = 'paid' then 'paid'

    else 'generic' end;



  v_detail := public.clip_text(case v_key

    when 'charter' then 'Charter seferde havayolu salonu hakkı yoktur.'

    when 'carrier' then 'Bu salon misafirin host ile aynı havayolunda uçmasını istiyor.'

    when 'noguest' then 'Host girebiliyor ama yanında misafir götüremiyor.'

    when 'paid'    then case (d ->> 'fee_payer')

                          when 'member_card' then 'Ücret host''un kartından çekilir.'

                          else 'Misafir girişi kapıda ücretlidir.' end

    else coalesce(d ->> 'detail', public.rule_notice('rule_notice_generic')) end, 140);



  -- 🔴 GERISI SILINMIYOR, ⓘ ARKASINA GIDIYOR. Kural eksiksiz aktarilir;

  -- yalniz HEPSI AYNI ANDA gosterilmez.

  v_more := public.clip_text(

    trim(both ' ' from concat_ws(' ',

      nullif(d ->> 'detail',''), nullif(v_qnote,''), nullif(v_cnote,''),

      nullif(d ->> 'source_conflict',''))), 400);



  -- 359 · AYNI UÇUŞ ŞARTI ekranın İLK cümlesi: kesin engelse sebebi, belirsizse uyarısı.
  -- Ücret cümlesi kaybolmaz, ⓘ arkasına (more) geçer. Metinler TR/EN (public.metin).
  v_su := d ->> 'same_flight_state';
  if coalesce(d ->> 'flight_coupling', '') = 'same_flight' and coalesce(v_su, 'ayni') <> 'ayni'
     and (d ->> 'block_code') is null and coalesce(d ->> 'charter', 'false') <> 'true'
     and coalesce(d ->> 'guest_policy', '') <> 'not_allowed' and coalesce(d ->> 'carrier_ok', '') <> 'false' then
    v_more := public.clip_text(trim(both ' ' from concat_ws(' ', nullif(v_detail, ''), v_more)), 400);
    v_head := case v_su when 'farkli' then public.metin('ayni_ucus_baslik_farkli')
                        when 'belirsiz' then public.metin('ayni_ucus_baslik_belirsiz')
                        else public.metin('ayni_ucus_baslik_eksik') end;
    v_detail := public.clip_text(replace(replace(case
                    when v_su = 'farkli' then public.metin('ayni_ucus_detay_farkli')
                    when v_su = 'belirsiz' then public.metin('ayni_ucus_detay_belirsiz')
                    when coalesce(v_flight, '') = '' then public.metin('ayni_ucus_detay_misafir_ucussuz')
                    else public.metin('ayni_ucus_detay_host_ucussuz') end,
                  '{h}', upper(coalesce(v_av.flight_number, ''))), '{g}', upper(coalesce(v_flight, ''))), 140);
  end if;

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then

    return jsonb_build_object(/* 192-kapi: kredi karti dali da SUNUCU KAPISINA uyar.

        159'un create_request_impl'i guest_policy='not_allowed' ya da

        severity=block olan ilanda 'guests_not_allowed' firlatiyor;

        ekran bunu bilmeden 'gonderebilirsin' diyordu. */

      'can_request',

        not (coalesce(d ->> 'guest_policy','') = 'not_allowed'
             or coalesce((d ->> 'same_flight_block')::boolean, false)   -- 359: kart dalı da sunucuyla aynı

             or (coalesce(d ->> 'severity','') = 'block'

                 and coalesce(d ->> 'fits','') <> 'false')),

      'needs_ack', true, 'kind','card_generic',

      /* 192-karar: erken donus de kararin politikasini TASIR.

         Eskiden bu dal guest_policy'yi hic dondurmuyordu ve

         kesif "misafir kabul etmiyor" derken istek ekrani susuyordu. */

      'guest_policy', d ->> 'guest_policy',

      'guest_allowance', coalesce((d ->> 'guest_included_count')::int, 0),

      'severity_src', d ->> 'severity',

      'severity','warn','source_label','Kredi kartı avantajı',

      'headline','Bu ilandaki hak kredi kartından geliyor',

      'credit_cost', 0,

      'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',

      'detail', public.clip_text(public.rule_notice('card_notice_guest'), 140),

      'more', v_more);

  end if;



  if (d ->> 'severity') = 'block' then

    if (d ->> 'block_code') is not null or (d ->> 'enforcement') = 'block' or (d ->> 'carrier_ok') = 'false'
       or coalesce((d ->> 'same_flight_block')::boolean, false)   -- 359

       or coalesce((d ->> 'charter'),'false') = 'true' then

      v_can := false;

    else v_ack := true; end if;

  -- 310: sunucu kapısıyla AYNI — taşıyıcı uyuşmazlığında ön kontrol de "başvuramazsın" der.
  elsif (d ->> 'carrier_ok') = 'false' and (d ->> 'program_id') is not null
        and coalesce(d ->> 'entitlement_model', '') <> 'bank_card' then v_can := false;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;

  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;

  end if;

  if v_qnote is not null or v_cnote is not null then v_ack := true; end if;
  -- 359 · aynı uçuş doğrulanamadıysa (numara yok / havayolları farklı) onay kutusu şart
  if v_can and coalesce(d ->> 'flight_coupling', '') = 'same_flight' and v_su in ('eksik', 'belirsiz') then v_ack := true; end if;



  return jsonb_build_object(

    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule', 'block_code', d ->> 'block_code',

    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',

    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',

    'flight_coupling', d ->> 'flight_coupling', 'same_flight_state', v_su,   -- 359

    'host_carrier', d ->> 'host_carrier', 'guest_carrier', d ->> 'guest_carrier',

    'carrier_ok', d -> 'carrier_ok', 'host_tier_label', v_tier,

    'source_label', coalesce(v_prog.name,'Lounge hakkı'),

    'credit_cost', v_credit,

    /* 187-kredi: misafirin cebinden cikan TOPLAM. Ekranda tek

       kutuda gosterilmeli: escrow + aktarim. */

    'credit_hold', v_tut,

    'credit_total', v_tut + coalesce(v_credit, 0), 'credit_balance', v_bal,

    'credit_note', case when v_credit > 0

      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,

    'headline', public.clip_text(v_head, 70),

    'detail', v_detail,

    'more', v_more);

end $pc359$;

-- §5 · Keşfet rozeti
CREATE OR REPLACE FUNCTION public.discovery_rule_badges(p_ids uuid[])
 RETURNS TABLE(avail_id uuid, severity text, label text, info text, detail text, same_flight_match boolean, blocks_request boolean, sort_boost integer, can_ask_host boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $bd359$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text;
  v_boost int; v_same boolean; v_block boolean; v_prog lounge_programs%rowtype;
  v_carrier text; v_vid uuid; v_kod text; v_su text; v_sfb boolean;   -- 359
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    -- 358 · rozet SUNUCUNUN kararıyla aynı: v6 + ilanla saatleri çakışan seyahat (kişi sayısı,
    -- hat, çocuk, kota, kabin, kalış dahil). Eskiden v5'ti: kart "İstek gönder" der, sunucu reddederdi.
    v_flight := null; v_carrier := null; v_vid := null;
    select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number)), v.id
      into v_flight, v_carrier, v_vid
      from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date
       and v.time_from < r.time_to and r.time_from < v.time_to
     order by (v.flight_number is not null) desc, v.created_at desc limit 1;

    d := public.lounge_access_decision_v6(avail_id, v_flight, coalesce(v_carrier, public.guest_carrier_for(avail_id)), v_vid);
    select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_block := coalesce((d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block', false)
               or coalesce((d ->> 'carrier_ok') = 'false', false)
               or coalesce((d ->> 'charter') = 'true', false);
    if v_prog.id is null or v_prog.entitlement_model = 'bank_card' then
      v_block := false;
    end if;

    -- 358 · seyahate bağlı kesin engel (sunucu da reddeder): kart da kapalı
    v_kod := d ->> 'block_code';
    if v_kod is not null then v_block := true; end if;
    -- 359 · aynı uçuş kesin tutmuyorsa kart da kapalı (sunucu reddeder)
    v_su := d ->> 'same_flight_state';
    v_sfb := coalesce((d ->> 'same_flight_block')::boolean, false);
    if v_sfb then v_block := true; end if;
    v_same := coalesce(v_same, false) or coalesce(v_su = 'ayni', false);

    v_boost := 0;
    -- 304: engelin SEBEBİ ayrı anahtar — farklı havayolu "misafir hakkı yok" değildir.
    if v_kod is not null then
      v_key := case v_kod when 'scope_mismatch' then 'rule_scope' when 'party_too_big' then 'rule_party'
                          when 'children_not_allowed' then 'rule_child' when 'quota_exhausted' then 'rule_quota'
                          when 'cabin_required' then 'rule_cabin' else 'flight_bad' end;
      v_boost := -1000;
    elsif v_sfb then                                 v_key := 'rule_same_flight'; v_boost := -1000;   -- 359
    elsif v_block and coalesce((d ->> 'carrier_ok') = 'false', false) then
                                                     v_key := 'carrier_bad';   v_boost := -1000;
    elsif v_block and coalesce((d ->> 'charter') = 'true', false) then
                                                     v_key := 'charter_block'; v_boost := -1000;
    elsif v_block then                               v_key := 'guest_none';  v_boost := -1000;
    elsif v_same then                                v_key := 'same_flight'; v_boost := 100;
    elsif coalesce(d ->> 'flight_coupling', '') = 'same_flight' and v_su in ('eksik', 'belirsiz') then   -- 359
      v_key := 'same_flight_check'; v_boost := case when v_su = 'belirsiz' then -100 else -20 end;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_key := 'guest_none_soft'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
    end if;

    -- 219 kapı hizası korunuyor
    if (d ->> 'guest_policy') = 'not_allowed' then
      v_block := true;
    end if;

    b := case when v_key is null then null
              -- 359 · yeni anahtarlar TR/EN metin tablosundan
              when v_key = 'rule_same_flight'
                then jsonb_build_object('label', public.metin('rozet_rule_same_flight'), 'info', public.metin('rozet_rule_same_flight_bilgi'))
              when v_key = 'same_flight_check'
                then jsonb_build_object('label', public.metin('rozet_same_flight_check'), 'info', public.metin('rozet_same_flight_check_bilgi'))
              else public.badge_text(v_key) end;

    severity := coalesce(d ->> 'severity','info');
    label    := b ->> 'label';
    info     := b ->> 'info';
    detail   := d ->> 'headline';
    same_flight_match := v_same;
    blocks_request := v_block;
    sort_boost := v_boost;
    can_ask_host := public.kural_sorusu_uygun_mu(avail_id);
    return next;
  end loop;
end $bd359$;

-- §6 · kural satırları
CREATE OR REPLACE FUNCTION public.kural_kosullari(p_avail_id uuid)
 RETURNS TABLE(sira integer, kod text, metin text, durum text, agirlik text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $kk359$
declare
  d jsonb; v_av availabilities%rowtype; v_vis visits%rowtype; v_prog lounge_programs%rowtype;
  v_flight text; v_uyum boolean; v_n int; v_i int := 0; v_su text;   -- 359
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return; end if;

  -- Misafirin ilanla çakışan seyahati (uçuşlu olan önce)
  select * into v_vis from visits v
   where v.user_id = auth.uid() and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and v.time_from < v_av.time_to and v_av.time_from < v.time_to   -- 358: sunucuyla aynı seyahat
   order by (v.flight_number is not null) desc, v.created_at desc
   limit 1;
  v_flight := nullif(v_vis.flight_number, '');

  d := public.lounge_access_decision_v6(p_avail_id, v_flight,
         coalesce(v_vis.carrier_code, public.carrier_from_flight(v_vis.flight_number), public.guest_carrier_for(p_avail_id)), v_vis.id);   -- 358
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

  -- ── KAPI SATIRLARI ────────────────────────────────────────────
  -- 1 · misafir hakkı
  v_n := nullif(d ->> 'guest_included_count','')::int;
  v_i := v_i + 1; sira := v_i; kod := 'misafir_hakki'; agirlik := 'kapi';
  if (d ->> 'guest_policy') = 'included' then
    durum := 'ok';
    metin := case when coalesce(v_n,0) > 0 then format('Misafir hakkı var · %s kişilik', v_n) else 'Misafir hakkı var' end;
  elsif (d ->> 'guest_policy') = 'paid' then
    durum := 'ok'; agirlik := 'not';
    metin := coalesce(nullif(d ->> 'guest_fee_note',''), 'Misafir ücretli girer');
  elsif (d ->> 'guest_policy') = 'not_allowed' then
    durum := 'yok'; metin := 'Bu kart misafir almıyor';
  else
    durum := 'bilinmiyor'; metin := 'Misafir hakkı doğrulanmadı';
  end if;
  return next;

  -- 2 · havayolu şartı
  v_i := v_i + 1; sira := v_i; kod := 'havayolu'; agirlik := 'kapi';
  -- 358 · kesin kural misafirin uçuşunu reddediyorsa (sunucu da reddeder) satır "bilinmiyor" değil "yok"
  if (d ->> 'fits') = 'false' and (d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block'
     and (d ->> 'block_code') is null and coalesce(d ->> 'flight_coupling', '') <> 'same_flight' then   -- 359: aynı uçuş kendi satırında
    durum := 'yok';
    metin := format('Uçuşun bu salonun havayolu kuralına uymuyor · %s', coalesce(upper(v_flight), '?'));
  elsif coalesce(d ->> 'flight_coupling','any') in ('any','none') and (d ->> 'carrier_known') is null then
    durum := 'ok'; agirlik := 'not'; metin := 'Havayolu şartı yok';
  elsif (d ->> 'carrier_known') is null or (d ->> 'carrier_known') = 'false' then
    durum := 'bilinmiyor'; metin := 'Havayolu şartı bilinmiyor · uçuşunu gir';
  elsif (d ->> 'carrier_ok') = 'true' then
    durum := 'ok';
    metin := case when coalesce(d ->> 'host_carrier','') <> ''
                  then format('Aynı havayolu · %s', upper(d ->> 'host_carrier')) else 'Havayolu şartı sağlanıyor' end;
  else
    durum := 'yok';
    metin := format('Havayolu şartı tutmuyor · %s ↔ %s', upper(coalesce(d ->> 'host_carrier','?')), upper(coalesce(d ->> 'guest_carrier','?')));
  end if;
  return next;

  -- 3 · uçuş bağı
  v_i := v_i + 1; sira := v_i; kod := 'ucus_bagi'; agirlik := 'kapi';
  if coalesce(d ->> 'flight_coupling','none') in ('none','any') then
    durum := 'ok'; agirlik := 'not'; metin := 'Uçuş birlikteliği şartı yok';
  else
    v_uyum := coalesce(v_flight,'') <> '' and coalesce(v_av.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(v_av.flight_number,' ',''));
    if (d ->> 'flight_coupling') = 'same_flight' then
      -- 359 · satır motorun kararıyla aynı: 'yok' yalnız kesin farklı uçuşta (sunucu da reddeder)
      v_su := coalesce(d ->> 'same_flight_state', 'eksik');
      durum := case v_su when 'ayni' then 'ok' when 'farkli' then 'yok' else 'bilinmiyor' end;
      metin := case
        when v_su = 'ayni' then 'Aynı uçuş şartı sağlanıyor'
        when v_su = 'farkli' then format('Aynı uçuşta değilsiniz · host %s, sen %s', upper(v_av.flight_number), upper(v_flight))
        when v_su = 'belirsiz' then format('Uçuş numaraları farklı · %s / %s · kod paylaşımlı aynı sefer mi, kontrol et',
                                           upper(v_av.flight_number), upper(v_flight))
        when coalesce(v_flight, '') = '' then 'Aynı uçuş şartı var · uçuşunu gir'
        else 'Aynı uçuş şartı var · host uçuşunu girmedi' end;
    else
      durum := 'bilinmiyor'; metin := 'Birlikte varış gerekir · kapıda beraber olun';
    end if;
  end if;
  return next;

  -- 4 · kişi sayısı (283/1)
  v_i := v_i + 1; sira := v_i; kod := 'kisi_sayisi'; agirlik := 'kapi';
  if (d ->> 'party_ok') = 'true' then
    durum := 'ok';
    metin := case when (d ->> 'party_size')::int > 1
                  then format('%s kişi · hak yetiyor', d ->> 'party_size') else 'Tek kişi · hak yetiyor' end;
  elsif (d ->> 'party_ok') = 'false' then
    durum := 'yok'; metin := format('%s kişisin, hak %s kişilik', d ->> 'party_size', d ->> 'party_limit');
  else
    durum := 'bilinmiyor'; metin := 'Kişi sayısı şartı doğrulanamadı';
  end if;
  return next;

  -- 5 · iç hat / dış hat (283/7)
  v_i := v_i + 1; sira := v_i; kod := 'hat'; agirlik := 'kapi';
  if (d ->> 'scope_ok') = 'true' then
    durum := 'ok'; agirlik := 'not';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'İç hatlar salonu · uçuşun iç hat'
                                         when 'international' then 'Dış hatlar salonu · uçuşun dış hat'
                                         else 'Salon her iki hatta da açık' end;
  elsif (d ->> 'scope_ok') = 'false' then
    durum := 'yok';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'Salon iç hatta, uçuşun dış hat' else 'Salon dış hatta, uçuşun iç hat' end;
  else
    durum := 'bilinmiyor';
    metin := case (d ->> 'venue_scope') when 'domestic' then 'İç hatlar salonu · varış noktanı gir'
                                         else 'Dış hatlar salonu · varış noktanı gir' end;
  end if;
  return next;

  -- 6 · host kotası (283/12) — yalnız biliniyorsa
  if coalesce((d #>> '{quota,known}')::boolean, false) then
    v_i := v_i + 1; sira := v_i; kod := 'host_kotasi'; agirlik := 'kapi';
    if (d ->> 'quota_ok') = 'true' then
      durum := 'ok'; metin := format('Host''un bu dönem %s hakkı kaldı', d #>> '{quota,left}');
    else
      durum := 'yok'; metin := format('Host''un dönem hakkı bitmiş · %s/%s', d #>> '{quota,used}', d #>> '{quota,total}');
    end if;
    return next;
  end if;

  -- 7 · bilet sınıfı (283/11) — yalnız bilet sınıfı programında
  if (d ->> 'cabin_required') = 'true' then
    v_i := v_i + 1; sira := v_i; kod := 'bilet_sinifi'; agirlik := 'kapi';
    if (d ->> 'cabin_ok') = 'true' then durum := 'ok'; metin := format('Host %s uçuyor · hak geçerli', upper(d ->> 'host_cabin'));
    elsif (d ->> 'cabin_ok') = 'false' then durum := 'yok'; metin := 'Host ekonomi uçuyor · bilet sınıfı hakkı yok';
    else durum := 'bilinmiyor'; metin := 'Host''un kabin sınıfı bilinmiyor'; end if;
    return next;
  end if;

  -- 8 · çocuk (283/2) — yalnız çocuk varsa
  if (d ->> 'has_child') = 'true' then
    v_i := v_i + 1; sira := v_i; kod := 'cocuk'; agirlik := 'kapi';
    if (d ->> 'children_ok') = 'true' then
      durum := 'ok';
      metin := case when (d ->> 'children_policy') = 'free_under'
                    then format('%s yaş altı haktan sayılmıyor', d ->> 'child_age_limit') else 'Çocuk misafir kabul ediliyor' end;
    elsif (d ->> 'children_ok') = 'false' then
      durum := 'yok';
      metin := case when (d ->> 'children_policy') = 'age_limit'
                    then format('%s yaş altı alınmıyor', d ->> 'child_age_limit') else 'Salon çocuk misafir almıyor' end;
    else durum := 'bilinmiyor'; metin := 'Çocuk kuralı doğrulanmadı · kapıda sor'; end if;
    return next;
  end if;

  -- 9 · varış salonu (283/8) — yalnız salon tek yönlüyse
  if (d ->> 'serves') in ('arrival') then
    v_i := v_i + 1; sira := v_i; kod := 'varis_salonu'; agirlik := 'kapi';
    if (d ->> 'serves_ok') = 'true' then durum := 'ok'; metin := 'Varış salonu · aktarma yolcususun';
    else durum := 'yok'; metin := 'Varış salonu · kalkış öncesi giriş yok'; end if;
    return next;
  end if;

  -- 10 · host yanında (283/9)
  if v_prog.id is not null and coalesce(v_prog.member_must_be_present, false) then
    v_i := v_i + 1; sira := v_i; kod := 'host_yaninda'; agirlik := 'kapi'; durum := 'ok';
    metin := 'Host giriş anında yanında olmalı';
    return next;
  end if;

  -- ── NOTLAR ────────────────────────────────────────────────────
  -- 11 · aynı gün + biniş kartı (283/10)
  v_i := v_i + 1; sira := v_i; kod := 'binis_karti'; agirlik := 'not';
  if (d ->> 'boarding_pass_ok') = 'true' then durum := 'ok'; metin := format('Biniş kartın aynı gün · %s', upper(v_flight));
  elsif (d ->> 'boarding_pass_ok') = 'false' then durum := 'yok'; metin := 'Biniş kartının tarihi ilanla uyuşmuyor';
  else durum := 'yok'; metin := 'Uçuş numarası doğrulanmadı'; end if;
  return next;

  -- 12 · ücret (283/5) — yalnız ücretli politikada
  if (d ->> 'guest_policy') = 'paid' then
    v_i := v_i + 1; sira := v_i; kod := 'ucret'; agirlik := 'not';
    if (d ->> 'fee_payer') = 'member_card' then durum := 'ok'; metin := 'Ücreti host''un kartı karşılıyor';
    elsif (d ->> 'fee_payer') = 'guest_at_door' then
      durum := 'ok';
      metin := case when nullif(d ->> 'guest_fee_amount','') is not null
                    then format('Kapıda ödersin · ~%s %s', trim(to_char((d ->> 'guest_fee_amount')::numeric,'FM999990')), coalesce(d ->> 'guest_fee_currency',''))
                    else 'Ücreti kapıda misafir öder' end;
    else durum := 'bilinmiyor'; metin := 'Ücreti kimin ödediği doğrulanmadı'; end if;
    return next;
  end if;

  -- 13 · kalış süresi (283/6)
  if nullif(d ->> 'max_stay_hours','') is not null then
    v_i := v_i + 1; sira := v_i; kod := 'kalis'; agirlik := 'not';
    if (d ->> 'stay_ok') = 'false' then
      durum := 'yok'; metin := format('Kalış sınırı %s saat · planın %s saat',
                                       trim(to_char((d ->> 'max_stay_hours')::numeric,'FM990.0')),
                                       trim(to_char((d ->> 'planned_hours')::numeric,'FM990.0')));
    else
      durum := 'ok'; metin := format('Kalış sınırı %s saat', trim(to_char((d ->> 'max_stay_hours')::numeric,'FM990.0')));
    end if;
    return next;
  end if;

  -- 14 · doluluk (283/3) — yalnız kayıt varsa
  if coalesce((d ->> 'capacity_refusals_60d')::int, 0) > 0 then
    v_i := v_i + 1; sira := v_i; kod := 'doluluk'; agirlik := 'not';
    durum := case when (d ->> 'capacity_refusals_60d')::int >= 2 then 'yok' else 'ok' end;
    metin := format('Bu saatlerde %s kez doluluk reddi (60 gün)', d ->> 'capacity_refusals_60d');
    return next;
  end if;

  -- 15 · kabin (bilet sınıfı programı değilse yalnız not)
  if (d ->> 'cabin_required') <> 'true' and coalesce(v_av.cabin_class,'') <> '' then
    v_i := v_i + 1; sira := v_i; kod := 'kabin'; agirlik := 'not'; durum := 'ok';
    metin := format('Host kabini · %s', upper(v_av.cabin_class));
    return next;
  end if;

  -- 284 · kural güncelliği (not)
  if (d -> 'freshness') is not null then
    v_i := v_i + 1; sira := v_i; kod := 'guncellik'; agirlik := 'not';
    if (d #>> '{freshness,durum}') = 'supheli' then
      durum := 'yok'; metin := format('Kural kapıda %s kez tutmadı · doğrulanıyor', d #>> '{freshness,acik_suphe}');
    elsif (d #>> '{freshness,durum}') = 'dogrulandi' then
      durum := 'ok'; metin := case when (d #>> '{freshness,gun}') is null then 'Kural kapıda doğrulandı'
                                    else format('Kural %s gün önce doğrulandı', d #>> '{freshness,gun}') end;
    elsif (d #>> '{freshness,durum}') = 'eski' then
      durum := 'bilinmiyor'; metin := format('Kural %s gün önce doğrulandı · eskimiş olabilir', d #>> '{freshness,gun}');
    else durum := 'bilinmiyor'; metin := 'Kural henüz kapıda doğrulanmadı'; end if;
    return next;
  end if;

  -- 16 · biniş kartı & kimlik gerekli
  if v_prog.id is not null and coalesce(v_prog.guest_needs_boarding_pass, false) then
    v_i := v_i + 1; sira := v_i; kod := 'belge'; agirlik := 'not'; durum := 'ok';
    metin := 'Kendi biniş kartın ve kimliğin gerekir';
    return next;
  end if;
end $kk359$;

-- §8 · BİLGİ: bekleyen isteklerden kaçı artık kesin farklı uçuşta (değiştirilmez; host kabul edebilir)
create schema if not exists tezgah;
create table if not exists tezgah.ayni_ucus_359 (avail_id uuid, request_id uuid, host_flight text, guest_flight text,
  durum text, olculdu timestamptz default now());
delete from tezgah.ayni_ucus_359;
insert into tezgah.ayni_ucus_359 (avail_id, request_id, host_flight, guest_flight, durum)
select r.avail_id, r.id, a.flight_number, v.flight_number,
       public.ayni_ucus_durumu(a.flight_number, v.flight_number, a.avail_date)
  from requests r
  join availabilities a on a.id = r.avail_id
  left join lateral (select v.flight_number from visits v
                      where v.user_id = r.guest_id and v.airport_code = a.airport_code and v.visit_date = a.avail_date
                        and v.time_from < a.time_to and a.time_from < v.time_to
                      order by (v.flight_number is not null) desc, v.created_at desc limit 1) v on true
 where r.status = 'pending'
   and coalesce(public.lounge_access_decision_v6(r.avail_id, v.flight_number, null, null) ->> 'flight_coupling', '') = 'same_flight';

-- DOĞRULAMA
select 'yardimci: yazim farki ayni ucus' as kontrol,
       public.ayni_ucus_durumu('TK01985', 'tk 1985') = 'ayni' as tamam
union all
select 'yardimci: ayni havayolu farkli numara kesin', public.ayni_ucus_durumu('TK1985', 'TK2000') = 'farkli'
union all
select 'yardimci: farkli havayolu belirsiz (kod paylasimi)', public.ayni_ucus_durumu('TK1985', 'PC2010') = 'belirsiz'
union all
select 'yardimci: numara yoksa eksik', public.ayni_ucus_durumu('TK1985', null) = 'eksik'
union all
select 'karar: v6 ayni ucus alanlari',
       position('same_flight_block' in pg_get_functiondef('public.lounge_access_decision_v6(uuid,text,text,uuid)'::regprocedure)) > 0
union all
select 'sunucu: kesin engel',
       position('359 · aynı uçuş' in pg_get_functiondef('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure)) > 0
union all
select 'on kontrol: ayni ucus metni',
       position('ayni_ucus_baslik_farkli' in pg_get_functiondef('public.request_precheck_pregate(uuid)'::regprocedure)) > 0
union all
select 'rozet: ayni ucus',
       position('rule_same_flight' in pg_get_functiondef('public.discovery_rule_badges(uuid[])'::regprocedure)) > 0
union all
select 'kural satiri: ayni ucus',
       position('same_flight_state' in pg_get_functiondef('public.kural_kosullari(uuid)'::regprocedure)) > 0
union all
select 'metinler TR+EN (22)',
       (select count(*) = 22 from beta_settings
         where key like 'ayni\_ucus\_%' or key like 'rozet\_rule\_same\_flight%' or key like 'rozet\_same\_flight\_check%')
union all
select 'bilgi: bekleyen istek, kesin farkli ucus = ' || (select count(*) from tezgah.ayni_ucus_359 where durum = 'farkli'), true;
