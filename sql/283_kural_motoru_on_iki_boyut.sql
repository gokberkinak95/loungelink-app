-- ============================================================
-- LoungeLink · sql/283_kural_motoru_on_iki_boyut.sql
-- 2 Eylül 2026
--
-- 🔴 MOTORUN HİÇ SORMADIĞI BOYUTLAR — ŞİMDİ SORUYOR
--
--   3. geçiş karnesi 12 boyut saydı. Şemayı yeniden okuyunca gerçek
--   tablo şöyle çıktı: kolonların ÇOĞU VARDI (max_stay_hours, fee_payer,
--   member_must_be_present, guest_needs_boarding_pass, venue.scope,
--   cabin_class, quota_total/used, capacity_hint, children_note…) ama
--   karar fonksiyonu bunların çoğunu OKUMUYOR, okuduğunu da yalnız
--   "not" olarak yapıştırıyordu. Eksik olan veri değil, SORU idi.
--
--   Gökberk'in şartı: "mevcut kural tablolarımızı bozmaması lazım."
--   Bu dosya HİÇBİR mevcut kolonu değiştirmez, hiçbir satırı silmez,
--   hiçbir check'i daraltmaz. Yalnız EKLER (nullable kolon) ve OKUR.
--
--   Boyut → nerede cevaplanıyor:
--    1 ziyaret başına misafir sayısı   visits.party_size (YENİ) × guest_included_count
--    2 çocuk                           visits.child_ages (YENİ) × children_policy (YENİ, nullable)
--    3 doluluk reddi                   kapida_retler(kapasite_dolu) son 60 gün, aynı saat bandı
--    4 aynı gün / aynı uçuş bağı       coupling zaten var; "aynı gün" satırı açıkça yazılıyor
--    5 ücreti kim öder                 fee_payer (VARDI, okunmuyordu)
--    6 azami kalış                     max_stay_hours × misafirin pencere süresi
--    7 iç hat / dış hat                venue.scope × misafirin varış ülkesi (airports.country)
--    8 kalkış / varış salonu           lounge_venues.serves (YENİ, nullable) × visits.purpose
--    9 host yanında kalmalı            member_must_be_present (VARDI; satır zaten vardı)
--   10 biniş kartı aynı gün            misafirin uçuşu kayıtlı + tarih = ilan tarihi
--   11 bilet sınıfı şartı              entitlement_model='ticket_class' × avail.cabin_class
--   12 host'un dönem kotası            host_entitlements.quota_* (VARDI; hiç TÜKETİLMİYORDU → trigger)
--
--   Karar: lounge_access_decision_v6 = v5 + bu 12 boyut. v5 DOKUNULMADAN
--   kalır (geri uyumluluk; eski çağıranlar aynı cevabı alır). Sunucu
--   kapısı (create_request_impl_preflag) ve ekran kapısı (pregate,
--   kural_kosullari) ÜÇÜ DE v6'ya geçer: ekranın gördüğü ile sunucunun
--   uyguladığı aynı fonksiyondan çıkar.
--
-- 🆕 SINIF: "VERİSİ OLAN AMA SORUSU OLMAYAN KOLON, YOK HÜKMÜNDEDİR."
-- ============================================================

-- ── 0 · Additive kolonlar ─────────────────────────────────────────
alter table visits add column if not exists party_size smallint not null default 1;
alter table visits add column if not exists child_ages smallint[];
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'visits_party_size_chk') then
    alter table visits add constraint visits_party_size_chk check (party_size between 1 and 6);
  end if;
end $$;
comment on column visits.party_size is
  'Salona girmek isteyen kişi sayısı (misafirin kendisi dahil). Kural motoru bunu '
  'guest_included_count ile karşılaştırır (283/1).';
comment on column visits.child_ages is
  'Yanındaki çocukların yaşları (party_size içinde sayılır). Boş = çocuk yok (283/2).';

alter table lounge_venue_acceptance add column if not exists children_policy text;
alter table lounge_venue_acceptance add column if not exists child_age_limit smallint;
alter table lounge_programs         add column if not exists children_policy text;
alter table lounge_programs         add column if not exists child_age_limit smallint;
alter table lounge_venues           add column if not exists serves text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'lva_children_policy_chk') then
    alter table lounge_venue_acceptance add constraint lva_children_policy_chk
      check (children_policy is null or children_policy in ('allowed','not_allowed','age_limit','free_under'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'lp_children_policy_chk') then
    alter table lounge_programs add constraint lp_children_policy_chk
      check (children_policy is null or children_policy in ('allowed','not_allowed','age_limit','free_under'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'lv_serves_chk') then
    alter table lounge_venues add constraint lv_serves_chk
      check (serves is null or serves in ('departure','arrival','both'));
  end if;
end $$;
comment on column lounge_venue_acceptance.children_policy is
  'allowed · not_allowed · age_limit (child_age_limit ALTI giremez) · free_under (child_age_limit altı '
  'misafir hakkından SAYILMAZ). NULL = bilinmiyor; motor "bilinmiyor" der, uydurmaz (283/2).';
comment on column lounge_venues.serves is
  'departure · arrival · both. NULL = bilinmiyor. Varış salonu kalkış yolcusunu almaz (283/8).';

-- ── 1 · Yardımcılar ───────────────────────────────────────────────
-- Uçuşun hattı: varış ülkesi Türkiye ise iç hat. Bilinmiyorsa NULL.
create or replace function public.ucus_hatti(p_origin text, p_dest text)
returns text language sql stable set search_path = public as $$
  select case
    when p_dest is null or btrim(p_dest) = '' then null
    when (select a.country from airports a where a.code = p_dest) is null then null
    when (select a.country from airports a where a.code = p_dest) in ('Türkiye','Turkiye','TR','Turkey')
     and coalesce((select a.country from airports a where a.code = p_origin), 'Türkiye')
         in ('Türkiye','Turkiye','TR','Turkey')
      then 'domestic'
    else 'international' end
$$;

-- Aynı salonda, ilan saatinin ±2 saatinde, son 60 günde doluluk reddi sayısı.
create or replace function public.doluluk_reddi_sayisi(p_avail_id uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int
    from kapida_retler k
    join availabilities a on a.id = p_avail_id
    left join sessions s on s.id = k.session_id
    left join requests r on r.id = s.request_id
    left join availabilities a2 on a2.id = r.avail_id
   where k.sebep = 'kapasite_dolu'
     and k.created_at > now() - interval '60 days'
     and (k.lounge_id = a.lounge_id
          or (a.venue_id is not null and a2.venue_id = a.venue_id))
     and (a2.time_from is null
          or abs(extract(epoch from (a2.time_from - a.time_from))) <= 2*3600)
$$;

-- Host'un bu ilandaki programda kalan dönem hakkı. {known, left, total, period}
create or replace function public.host_kota_durumu(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_av availabilities%rowtype; v_he host_entitlements%rowtype; v_prog uuid;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('known', false); end if;
  v_prog := v_av.program_id;
  if v_prog is null then
    v_prog := nullif(public.lounge_access_decision_prebase(p_avail_id) ->> 'program_id','')::uuid;
  end if;
  if v_prog is null then return jsonb_build_object('known', false); end if;
  select * into v_he from host_entitlements
   where user_id = v_av.host_id and program_id = v_prog
   order by verified desc, self_reported_at desc nulls last limit 1;
  if not found then return jsonb_build_object('known', false); end if;
  return public.entitlement_remaining(v_he.id) || jsonb_build_object('entitlement_id', v_he.id);
end $$;

-- ── 2 · v6: v5 + on iki boyut ─────────────────────────────────────
create or replace function public.lounge_access_decision_v6(
  p_avail_id uuid, p_guest_flight text default null, p_guest_carrier text default null,
  p_guest_visit_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
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
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_notes, ' ')));
end $$;
revoke all on function public.lounge_access_decision_v6(uuid,text,text,uuid) from public, anon;
grant execute on function public.lounge_access_decision_v6(uuid,text,text,uuid) to authenticated;

-- ── 3 · kural_kosullari: aynı imza, on beş satır ──────────────────
-- Ekran satırları sırayla çizer: önce KAPI satırları, sonra NOTLAR.
drop function if exists public.kural_kosullari(uuid);
create function public.kural_kosullari(p_avail_id uuid)
returns table(sira int, kod text, metin text, durum text, agirlik text)
language plpgsql stable security definer set search_path = public as $$
declare
  d jsonb; v_av availabilities%rowtype; v_vis visits%rowtype; v_prog lounge_programs%rowtype;
  v_flight text; v_uyum boolean; v_n int; v_i int := 0;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return; end if;

  -- Misafirin ilanla çakışan seyahati (uçuşlu olan önce)
  select * into v_vis from visits v
   where v.user_id = auth.uid() and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
   order by (coalesce(v.flight_number,'') <> '') desc, v.created_at desc
   limit 1;
  v_flight := nullif(v_vis.flight_number, '');

  d := public.lounge_access_decision_v6(p_avail_id, v_flight,
         coalesce(v_vis.carrier_code, public.guest_carrier_for(p_avail_id)), v_vis.id);
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
  if coalesce(d ->> 'flight_coupling','any') in ('any','none') and (d ->> 'carrier_known') is null then
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
      durum := case when v_uyum then 'ok' when coalesce(v_flight,'') = '' then 'bilinmiyor' else 'yok' end;
      metin := case when v_uyum then 'Aynı uçuş şartı sağlanıyor'
                    when coalesce(v_flight,'') = '' then 'Aynı uçuş şartı var · uçuşunu gir'
                    else 'Aynı uçuş şartı sağlanmıyor' end;
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

  -- 16 · biniş kartı & kimlik gerekli
  if v_prog.id is not null and coalesce(v_prog.guest_needs_boarding_pass, false) then
    v_i := v_i + 1; sira := v_i; kod := 'belge'; agirlik := 'not'; durum := 'ok';
    metin := 'Kendi biniş kartın ve kimliğin gerekir';
    return next;
  end if;
end $$;
revoke all on function public.kural_kosullari(uuid) from public, anon;
grant execute on function public.kural_kosullari(uuid) to authenticated;

-- ── 4 · Sunucu kapısı ve ekran kapısı v6'ya ───────────────────────
-- 🔴 İLK SÜRÜM BU İKİ FONKSİYONU pg_get_functiondef + replace İLE
-- YAMALIYORDU ve Gökberk'in Supabase'inde "283: request_precheck_pregate
-- kalibi bulunamadi" ile durdu: canlı gövdenin metni yereldekiyle
-- birebir aynı değil (252 §4b'nin dinamik yaması iki ortamda farklı iz
-- bırakmış). Metne bağımlı yama, metin farklıysa yama değildir.
-- Şimdi iki fonksiyon da AÇIK ve TAM tanımla yazılıyor: 280/281/282'nin
-- tüm değişiklikleri (tek kapıdan iade, hesap kapısı, misafir taşıyıcı)
-- gövdede aynen duruyor; tek fark v5 → v6 + block_code.
-- 🆕 SINIF: "CANLI GÖVDEYİ METİN OLARAK YAMALAMA — DURUMU TAMAMEN YAZ;
-- YAMA ORTAMA BAĞLIDIR, TANIM DEĞİLDİR."
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
    if (v_dec ->> 'carrier_ok') = 'false' and (v_dec ->> 'enforcement') = 'block' then
      raise exception 'guest_carrier_mismatch';
    end if;
  end;

  -- 🔴 207: BEDEL ARTIK MERTEBEDEN OKUNUYOR, sabit -1 değil.
  v_cost := public.request_credit_cost(v_uid, p_avail_id);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < v_cost then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

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

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id, 'kredi_bedeli', v_cost);
end $function$;

CREATE OR REPLACE FUNCTION public.request_precheck_pregate(p_avail_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text; v_carrier text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_tut int := 1; v_bal int; v_qnote text; v_cnote text;
  v_tier text; v_head text; v_key text; v_detail text; v_more text;
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
         and v.visit_date  = a2.avail_date)
  then
    return jsonb_build_object(
      'can_request', false, 'kind', 'trip_gate', 'severity', 'block',
      'headline', 'Bu tarihte o havalimanında seyahatin yok',
      'detail', 'Bu ilan ' || (select to_char(a3.avail_date, 'DD.MM.YYYY')
                    || ' tarihinde ' || a3.airport_code
                    from availabilities a3 where a3.id = p_avail_id)
                 || '. O gün için bir seyahat ekle, ilan hemen başvurulabilir olsun.',
      'fix_action', 'add_trip',
      'credit_cost', 0, 'credit_hold', 0, 'credit_total', 0);
  end if;

  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;

  select v.flight_number, coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))
    into v_flight, v_carrier
    from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v6(p_avail_id, v_flight, v_carrier,
         (select v.id from visits v where v.user_id = v_uid and v.airport_code = v_av.airport_code and v.visit_date = v_av.avail_date order by (coalesce(v.flight_number,'') <> '') desc, v.created_at desc limit 1));   -- 283
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

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object(/* 192-kapi: kredi karti dali da SUNUCU KAPISINA uyar.
        159'un create_request_impl'i guest_policy='not_allowed' ya da
        severity=block olan ilanda 'guests_not_allowed' firlatiyor;
        ekran bunu bilmeden 'gonderebilirsin' diyordu. */
      'can_request',
        not (coalesce(d ->> 'guest_policy','') = 'not_allowed'
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
       or coalesce((d ->> 'charter'),'false') = 'true' then
      v_can := false;
    else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;
  if v_qnote is not null or v_cnote is not null then v_ack := true; end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule', 'block_code', d ->> 'block_code',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
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
end $function$;

do $$
begin
  if pg_get_functiondef('public.create_request_impl_preflag'::regproc) not like '%lounge_access_decision_v6%' then
    raise exception '283: create_request_impl_preflag v6 degil'; end if;
  if pg_get_functiondef('public.request_precheck_pregate'::regproc) not like '%block_code%' then
    raise exception '283: request_precheck_pregate block_code dondurmuyor'; end if;
  raise notice '283: create_request_impl_preflag + request_precheck_pregate v6 (acik tanim)';
end $$;

-- ── 5 · Kota TÜKETİMİ: tamamlanan oturum host'un dönem hakkını düşer ─
-- quota_used bugüne kadar yalnız host'un ELİYLE yazdığı sayıydı; hiçbir
-- oturum onu ilerletmiyordu. "Hakkım 8, 3'ü kullanıldı" beyanı ilk
-- oturumdan sonra yalan oluyordu.
create or replace function public.trg_kota_tuket()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_req requests%rowtype; v_av availabilities%rowtype; v_prog uuid; v_he host_entitlements%rowtype;
        v_start date; v_party int;
begin
  if new.status <> 'completed' or old.status = 'completed' then return new; end if;
  select * into v_req from requests where id = new.request_id;
  select * into v_av from availabilities where id = v_req.avail_id;
  v_prog := v_av.program_id;
  if v_prog is null then
    v_prog := nullif(public.lounge_access_decision_prebase(v_av.id) ->> 'program_id','')::uuid;
  end if;
  if v_prog is null then return new; end if;
  select * into v_he from host_entitlements
   where user_id = v_req.host_id and program_id = v_prog
   order by verified desc, self_reported_at desc nulls last limit 1;
  if not found or v_he.quota_total is null or v_he.quota_period = 'unlimited' then return new; end if;
  select coalesce(v.party_size,1) into v_party from visits v where v.id = v_req.visit_id;
  v_party := coalesce(v_party, 1);
  v_start := coalesce(v_he.quota_period_start,
             case when v_he.quota_period = 'month' then date_trunc('month', current_date)::date
                  else date_trunc('year', current_date)::date end);
  if (v_he.quota_period = 'month' and v_start < date_trunc('month', current_date)::date)
     or (v_he.quota_period = 'year' and v_start < date_trunc('year', current_date)::date) then
    update host_entitlements set quota_used = least(v_party, quota_total),
           quota_period_start = case when v_he.quota_period = 'month' then date_trunc('month', current_date)::date
                                     else date_trunc('year', current_date)::date end
     where id = v_he.id;
  else
    update host_entitlements set quota_used = least(quota_used + v_party, quota_total) where id = v_he.id;
  end if;
  return new;
end $$;
drop trigger if exists trg_kota_tuket on sessions;
create trigger trg_kota_tuket after update of status on sessions
  for each row execute function public.trg_kota_tuket();

-- ── 6 · Seyahat formu: kişi sayısı + çocuk yaşları ────────────────
create or replace function public.set_visit_party(p_visit_id uuid, p_kisi int, p_cocuk_yas int[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_kisi is null or p_kisi < 1 or p_kisi > 6 then raise exception 'party_size_invalid'; end if;
  if p_cocuk_yas is not null and (array_length(p_cocuk_yas,1) >= p_kisi
     or exists (select 1 from unnest(p_cocuk_yas) x where x < 0 or x > 17)) then
    raise exception 'child_ages_invalid';
  end if;
  update visits set party_size = p_kisi, child_ages = nullif(p_cocuk_yas::smallint[], '{}'::smallint[])
   where id = p_visit_id and user_id = v_uid;
  if not found then raise exception 'visit_not_found'; end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.set_visit_party(uuid,int,int[]) from public, anon;
grant execute on function public.set_visit_party(uuid,int,int[]) to authenticated;

-- seyahat_ekle: iki yeni isteğe bağlı parametre (eski çağrılar aynen çalışır).
-- 🔴 Dinamik yama DEĞİL, açık tanım: sözleşme denetimi (contract_check.py)
-- imzayı SQL dosyasından okur; regexp ile üretilen imzayı göremezdi.
-- Gövde 250'deki ile aynı + son satırda kişi/çocuk yazımı.
drop function if exists public.seyahat_ekle(text,date,time,time,text,text,text,text);
drop function if exists public.seyahat_ekle(text,date,time,time,text,text,text,text,integer,integer[]);
create or replace function public.seyahat_ekle(
  p_airport text, p_date date, p_from time, p_to time,
  p_destination text default null, p_flight text default null,
  p_purpose text default null, p_carrier text default null,
  p_kisi integer default 1, p_cocuk_yas integer[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1
  if p_airport is null or btrim(p_airport) = '' then raise exception 'airport_required'; end if;
  if p_date is null then raise exception 'date_required'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;
  if p_from is null or p_to is null or p_from >= p_to then raise exception 'invalid_time_range'; end if;
  if not exists (select 1 from airports where code = upper(btrim(p_airport))::char(3)) then
    raise exception 'unknown_airport';
  end if;
  if p_kisi is null or p_kisi < 1 or p_kisi > 6 then raise exception 'party_size_invalid'; end if;
  if p_cocuk_yas is not null and (array_length(p_cocuk_yas,1) >= p_kisi
     or exists (select 1 from unnest(p_cocuk_yas) x where x < 0 or x > 17)) then
    raise exception 'child_ages_invalid';
  end if;
  if exists (select 1 from visits v
              where v.user_id = v_uid and v.airport_code = upper(btrim(p_airport))::char(3)
                and v.visit_date = p_date
                and v.time_from < p_to and p_from < v.time_to) then
    raise exception 'ayni_saatte_seyahatin_var';
  end if;

  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number,
                      party_size, child_ages)
  values (v_uid, upper(btrim(p_airport))::char(3),
          nullif(upper(btrim(coalesce(p_destination,''))),'')::char(3),
          p_date, p_from, p_to, nullif(btrim(coalesce(p_flight,'')),''),
          p_kisi, nullif(p_cocuk_yas::smallint[], '{}'::smallint[]))
  returning id into v_id;

  if p_purpose is not null then perform public.set_visit_purpose(v_id, p_purpose); end if;
  if p_carrier is not null then perform public.set_visit_carrier(v_id, p_carrier); end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
revoke all on function public.seyahat_ekle(text,date,time,time,text,text,text,text,integer,integer[]) from public, anon;
grant execute on function public.seyahat_ekle(text,date,time,time,text,text,text,text,integer,integer[]) to authenticated;

-- ── 7 · my_visits çıktısına party alanları (select * ise otomatik) ──
-- my_visits `select *`/row döndürüyorsa yeni kolonlar kendiliğinden gelir;
-- değilse ELLE BAK notu. Nöbetçi aşağıda kontrol eder.

-- ── NÖBETÇİLER ──────────────────────────────────────────────────
do $$
declare v jsonb; v_n int; v_av uuid; v_def text;
begin
  if not exists (select 1 from information_schema.columns where table_name='visits' and column_name='party_size') then
    raise exception '283: visits.party_size yok'; end if;
  if pg_get_functiondef('public.create_request_impl_preflag'::regproc) not like '%lounge_access_decision_v6%' then
    raise exception '283: create_request v6 degil'; end if;
  if pg_get_functiondef('public.request_precheck_pregate'::regproc) not like '%block_code%' then
    raise exception '283: pregate block_code dondurmuyor'; end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_kota_tuket') then
    raise exception '283: kota trigger yok'; end if;
  select id into v_av from availabilities where active order by created_at desc limit 1;
  if v_av is not null then
    v := public.lounge_access_decision_v6(v_av);
    if (v ->> 'engine') <> 'v6' then raise exception '283: v6 kendini imzalamiyor'; end if;
    if v ->> 'severity' is null then raise exception '283: v6 severity bos'; end if;
    -- v5 ile çelişmez: v6 severity, v5 severity'den DAHA HAFİF olamaz
    if (public.lounge_access_decision_v5(v_av) ->> 'severity') = 'block' and (v ->> 'severity') <> 'block' then
      raise exception '283: v6 v5''in engelini kaldirdi'; end if;
  end if;
  -- kural_kosullari en az 6 satır (5 kapı + biniş kartı) döndürmeli
  if v_av is not null then
    select count(*) into v_n from public.kural_kosullari(v_av);
    if v_n < 6 then raise exception '283: kural_kosullari % satir (>=6 bekleniyor)', v_n; end if;
  end if;
  select pg_get_functiondef('public.my_visits'::regproc) into v_def;
  if v_def not like '%select *%' and v_def not like '%party_size%' and v_def not like '%row_to_json%' and v_def not like '%to_jsonb(v%' then
    raise notice '283: my_visits party_size dondurmuyor olabilir — ekran seyahat satirini ayrica okur';
  end if;
  raise notice '283 NOBETCI OK: v6 on iki boyut · kural_kosullari % satir · kapilar v6 · kota tuketimi', v_n;
end $$;
