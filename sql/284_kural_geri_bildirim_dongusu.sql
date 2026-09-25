-- ============================================================
-- LoungeLink · sql/284_kural_geri_bildirim_dongusu.sql
-- 2 Eylül 2026
--
-- 🔴 KAPI REDDİ MOTORA GERİ DÖNMÜYORDU
--
--   Elimizde iki geri bildirim kanalı ZATEN vardı:
--     · kapida_giremedim()   → kapida_retler (5 sebep, kredi iadesi)
--     · submit_field_report() → lounge_field_reports (+rollup sayaçları)
--   İkisi de yalnız "kayda" düşüyordu. Kural satırı bunlardan haberdar
--   olmuyor, BO'da kimse kuyruk görmüyor, karar fonksiyonu "bu kural
--   geçen hafta kapıda 3 kez tutmadı" demiyordu.
--
--   Gökberk'in şartı: kural verisi onun ilettiği kaynaklardan geliyor,
--   otomatik denetlenemez; döngü MEVCUT KURAL TABLOLARINI BOZMAMALI.
--   Bu yüzden:
--     · Şüphe YAN TABLODA yaşar (kural_supheleri). lounge_guest_rules,
--       lounge_programs, lounge_venue_acceptance satırlarına hiçbir
--       tetikleyici yazmaz.
--     · Karar fonksiyonu yan tabloyu OKUR ve uyarır — kuralı DEĞİŞTİRMEZ.
--     · Kuralı değiştiren tek şey BO'da bir İNSAN kararıdır
--       (bo_kural_suphe_karar). O karar da yalnız checked_at/verified_by
--       gibi doğrulama METAVERİSİNE dokunur; kural içeriğini BO'nun
--       mevcut düzenleme ekranı değiştirir.
--
-- 🆕 SINIF: "GERİ BİLDİRİM VERİYİ DEĞİŞTİRMEZ, VERİYE SORU SORAR —
-- CEVABI İNSAN VERİR."
-- ============================================================

-- ── 1 · Yan tablo ──────────────────────────────────────────────────
create table if not exists kural_supheleri (
  id            uuid primary key default gen_random_uuid(),
  venue_id      uuid references lounge_venues(id) on delete cascade,
  program_id    uuid references lounge_programs(id) on delete cascade,
  acceptance_id uuid references lounge_venue_acceptance(id) on delete set null,
  kaynak        text not null check (kaynak in ('kapida_ret','saha_raporu','kullanici','bo')),
  session_id    uuid references sessions(id) on delete set null,
  bildiren_id   uuid references users(id) on delete set null,
  sebep         text not null check (sebep in ('kural_tutmadi','belge_istendi','kapasite_dolu','ucret_istendi','diger')),
  aciklama      text,
  durum         text not null default 'acik' check (durum in ('acik','dogrulandi','guncellendi','reddedildi')),
  karar_veren   text,
  karar_not     text,
  karar_at      timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists ix_kural_suphe_acik on kural_supheleri (venue_id, program_id) where durum = 'acik';
create index if not exists ix_kural_suphe_created on kural_supheleri (created_at desc);
alter table kural_supheleri enable row level security;
-- İstemci OKUMAZ: bu bir operasyon kuyruğu. Yazma yalnız definer fonksiyonlardan.
revoke all on kural_supheleri from anon, authenticated;
comment on table kural_supheleri is
  'Kapı reddi / saha raporu → kural satırı hakkında ŞÜPHE. Kural tablolarına dokunmaz; '
  'karar fonksiyonu okur ve uyarır, BO insan kararıyla kapatır (284).';

-- ── 2 · Salon×program çözümleyici (oturumdan) ────────────────────
create or replace function public.oturum_kural_hedefi(p_session_id uuid)
returns table(venue_id uuid, program_id uuid, acceptance_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare v_req requests%rowtype; v_av availabilities%rowtype; d jsonb;
begin
  select * into v_req from requests r join sessions s on s.request_id = r.id where s.id = p_session_id;
  if not found then return; end if;
  select * into v_av from availabilities where id = v_req.avail_id;
  d := public.lounge_access_decision_prebase(v_av.id);
  venue_id   := coalesce(nullif(d ->> 'venue_id','')::uuid, v_av.venue_id,
                         (select l.venue_id from lounges l where l.id = v_av.lounge_id));
  program_id := coalesce(nullif(d ->> 'program_id','')::uuid, v_av.program_id);
  select a.id into acceptance_id from lounge_venue_acceptance a
   where a.venue_id = oturum_kural_hedefi.venue_id and a.program_id = oturum_kural_hedefi.program_id and a.active
   limit 1;
  return next;
end $$;

-- ── 3 · Kapı reddi → şüphe ────────────────────────────────────────
create or replace function public.trg_kapida_ret_suphe()
returns trigger language plpgsql security definer set search_path = public as $$
declare h record;
begin
  if new.sebep not in ('kural_tutmadi','belge_istendi','kapasite_dolu') then return new; end if;
  select * into h from public.oturum_kural_hedefi(new.session_id);
  if h.venue_id is null and h.program_id is null then return new; end if;
  insert into kural_supheleri (venue_id, program_id, acceptance_id, kaynak, session_id, bildiren_id, sebep, aciklama)
  values (h.venue_id, h.program_id, h.acceptance_id, 'kapida_ret', new.session_id, new.guest_id, new.sebep, new.aciklama);
  return new;
end $$;
drop trigger if exists trg_kapida_ret_suphe on kapida_retler;
create trigger trg_kapida_ret_suphe after insert on kapida_retler
  for each row execute function public.trg_kapida_ret_suphe();

-- ── 4 · Saha raporu (reddedildi / ücret istendi) → şüphe ─────────
create or replace function public.trg_saha_raporu_suphe()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_sebep text; h record;
begin
  v_sebep := case
    when new.outcome = 'refused' or new.guest_accepted is false then 'kural_tutmadi'
    when new.outcome = 'admitted_paid' and coalesce(new.fee_charged,false) then 'ucret_istendi'
    else null end;
  if v_sebep is null then return new; end if;
  -- Aynı oturum için kapı reddi zaten şüphe açtıysa ikinci kayıt açma
  if new.session_id is not null and exists (select 1 from kural_supheleri where session_id = new.session_id and durum = 'acik') then
    return new;
  end if;
  if new.session_id is not null then
    select * into h from public.oturum_kural_hedefi(new.session_id);
  end if;
  insert into kural_supheleri (venue_id, program_id, acceptance_id, kaynak, session_id, bildiren_id, sebep, aciklama)
  values (coalesce(h.venue_id, new.venue_id), coalesce(h.program_id, new.program_id), h.acceptance_id,
          'saha_raporu', new.session_id, new.reporter_id, v_sebep, new.note);
  return new;
end $$;
drop trigger if exists trg_saha_raporu_suphe on lounge_field_reports;
create trigger trg_saha_raporu_suphe after insert on lounge_field_reports
  for each row execute function public.trg_saha_raporu_suphe();

-- ── 5 · Kural güncelliği (okur, yazmaz) ──────────────────────────
create or replace function public.kural_guncelligi(p_venue_id uuid, p_program_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_checked date; v_acik int; v_ok int; v_bad int; v_son timestamptz; v_durum text; v_gun int;
begin
  select a.checked_at into v_checked from lounge_venue_acceptance a
   where a.venue_id = p_venue_id and a.program_id = p_program_id and a.active limit 1;
  if v_checked is null then
    select p.checked_at into v_checked from lounge_programs p where p.id = p_program_id;
  end if;
  select count(*) filter (where durum = 'acik' and created_at > now() - interval '90 days'),
         max(created_at) filter (where durum = 'acik')
    into v_acik, v_son
    from kural_supheleri where venue_id = p_venue_id and program_id = p_program_id;
  select count(*) filter (where outcome = 'admitted_free' and created_at > now() - interval '90 days'),
         count(*) filter (where outcome in ('refused','admitted_paid') and created_at > now() - interval '90 days')
    into v_ok, v_bad
    from lounge_field_reports where venue_id = p_venue_id and program_id = p_program_id;
  -- Son insan doğrulaması da checked_at'e sayılır (BO kararı)
  select greatest(v_checked, max(karar_at)::date) into v_checked
    from kural_supheleri where venue_id = p_venue_id and program_id = p_program_id
     and durum in ('dogrulandi','guncellendi');
  v_durum := case
    when coalesce(v_acik,0) >= 1 then 'supheli'
    when v_checked is null and coalesce(v_ok,0) = 0 then 'bilinmiyor'
    when v_checked is null or (v_checked < current_date - 90 and coalesce(v_ok,0) = 0) then 'eski'
    else 'dogrulandi' end;
  v_gun := case when v_checked is null then null else current_date - v_checked end;
  return jsonb_build_object('durum', v_durum, 'checked_at', v_checked, 'gun', v_gun,
                            'acik_suphe', coalesce(v_acik,0), 'son_suphe', v_son,
                            'ok_90', coalesce(v_ok,0), 'bad_90', coalesce(v_bad,0));
end $$;

-- ── 6 · Karar fonksiyonu güncelliği OKUR ─────────────────────────
-- 🔴 İlk sürüm 283'ün yazdığı gövdeyi pg_get_functiondef + replace ile
-- yamalıyordu. 283'te aynı sınıf hata Gökberk'in Supabase'inde durdu
-- ("kalibi bulunamadi"); 284/9 da aynı şekilde durdu. Metin yaması
-- ortama bağlıdır; TANIM değildir. İki fonksiyon burada TAM yazılıyor
-- (283'teki gövde + güncellik satırı). `kural_kosullari` aynı imza.
-- 🆕 SINIF: "CANLI GÖVDEYİ METİN OLARAK YAMALAMA — DURUMU TAMAMEN YAZ."
CREATE OR REPLACE FUNCTION public.lounge_access_decision_v6(p_avail_id uuid, p_guest_flight text DEFAULT NULL::text, p_guest_carrier text DEFAULT NULL::text, p_guest_visit_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.kural_kosullari(p_avail_id uuid)
 RETURNS TABLE(sira integer, kod text, metin text, durum text, agirlik text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$;

do $$
begin
  if pg_get_functiondef('public.lounge_access_decision_v6'::regproc) not like '%kural_guncelligi%' then raise exception '284: v6 guncellik okumuyor'; end if;
  if pg_get_functiondef('public.kural_kosullari'::regproc) not like '%guncellik%' then raise exception '284: kural_kosullari guncellik satiri yok'; end if;
  raise notice '284: v6 + kural_kosullari guncellik (acik tanim)';
end $$;

-- ── 7 · BO kuyruğu ───────────────────────────────────────────────
create or replace function public.bo_kural_suphe_kuyrugu(p_durum text default 'acik', p_limit int default 200)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select jsonb_agg(x order by (x->>'acik')::int desc, x->>'son' desc) into v from (
    select jsonb_build_object(
      'venue_id', k.venue_id, 'salon', v.name, 'airport', v.airport_code, 'terminal', v.terminal,
      'program_id', k.program_id, 'program', p.name, 'program_code', p.code,
      'acceptance_id', min(k.acceptance_id::text),
      'guest_policy', max(a.guest_policy), 'checked_at', max(a.checked_at), 'source_url', max(coalesce(a.source_url, p.source_url)),
      'acik', count(*) filter (where k.durum = 'acik'),
      'toplam', count(*),
      'sebepler', (select jsonb_object_agg(s, n) from (select sebep s, count(*) n from kural_supheleri k2
                     where k2.venue_id is not distinct from k.venue_id and k2.program_id is not distinct from k.program_id
                       and (p_durum is null or k2.durum = p_durum) group by sebep) t),
      'son', max(k.created_at),
      'kayitlar', (select jsonb_agg(jsonb_build_object('id', k3.id, 'kaynak', k3.kaynak, 'sebep', k3.sebep,
                     'aciklama', k3.aciklama, 'durum', k3.durum, 'created_at', k3.created_at,
                     'session_id', k3.session_id, 'karar_not', k3.karar_not, 'karar_veren', k3.karar_veren)
                     order by k3.created_at desc)
                   from (select * from kural_supheleri k4
                          where k4.venue_id is not distinct from k.venue_id and k4.program_id is not distinct from k.program_id
                            and (p_durum is null or k4.durum = p_durum)
                          order by created_at desc limit 20) k3),
      'guncellik', case when k.venue_id is not null and k.program_id is not null
                        then public.kural_guncelligi(k.venue_id, k.program_id) end) as x
    from kural_supheleri k
    left join lounge_venues v on v.id = k.venue_id
    left join lounge_programs p on p.id = k.program_id
    left join lounge_venue_acceptance a on a.venue_id = k.venue_id and a.program_id = k.program_id and a.active
    where (p_durum is null or k.durum = p_durum)
    group by k.venue_id, v.name, v.airport_code, v.terminal, k.program_id, p.name, p.code
    limit greatest(coalesce(p_limit,200),1)) t;
  return coalesce(v, '[]'::jsonb);
end $$;

-- Karar: şüpheyi kapat. 'dogrulandi' = kural doğru, kapı hata yaptı (checked_at bugüne).
-- 'guncellendi' = kural düzeltildi (BO'nun kural ekranından; burada yalnız damga).
-- 'reddedildi' = bildirim geçersiz. Yalnız METAVERİ yazar.
create or replace function public.bo_kural_suphe_karar(p_venue_id uuid, p_program_id uuid, p_durum text, p_not text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_n int; v_email text;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_durum not in ('dogrulandi','guncellendi','reddedildi') then raise exception 'gecersiz_durum'; end if;
  select email into v_email from users where id = auth.uid();
  update kural_supheleri
     set durum = p_durum, karar_not = nullif(btrim(coalesce(p_not,'')),''),
         karar_veren = coalesce(v_email, 'admin'), karar_at = now()
   where venue_id is not distinct from p_venue_id and program_id is not distinct from p_program_id and durum = 'acik';
  get diagnostics v_n = row_count;
  if p_durum in ('dogrulandi','guncellendi') and p_venue_id is not null and p_program_id is not null then
    -- Doğrulama METAVERİSİ: içerik değil, tarih ve imza.
    update lounge_venue_acceptance
       set checked_at = current_date, verified_by = coalesce(v_email,'admin'), updated_at = now()
     where venue_id = p_venue_id and program_id = p_program_id and active;
  end if;
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('rule.suspicion.' || p_durum, 'lounge_venue_acceptance',
          coalesce(p_venue_id, '00000000-0000-0000-0000-000000000000'::uuid),
          jsonb_build_object('venue_id', p_venue_id, 'program_id', p_program_id, 'kapatilan', v_n, 'not', p_not));
  return jsonb_build_object('ok', true, 'kapatilan', v_n);
end $$;

-- Bilinmeyen kabul satırları — TALEBE göre sıralı (boyut 12).
-- 346 satırı masa başında dolduramayız; en çok istek gören salon önce.
create or replace function public.bo_kural_bilinmeyenler(p_limit int default 100)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select jsonb_agg(x order by (x->>'talep')::int desc, x->>'salon') into v from (
    select jsonb_build_object(
      'acceptance_id', a.id, 'venue_id', a.venue_id, 'program_id', a.program_id,
      'salon', v.name, 'airport', v.airport_code, 'program', p.name, 'program_code', p.code,
      'guest_policy', a.guest_policy, 'checked_at', a.checked_at, 'source_url', coalesce(a.source_url, p.source_url),
      'talep', (select count(*) from availabilities av where av.venue_id = a.venue_id and av.created_at > now() - interval '90 days')
             + (select count(*) from visits vi where vi.airport_code = v.airport_code and vi.created_at > now() - interval '90 days')
             + 5 * (select count(*) from host_entitlements he where he.program_id = a.program_id)) as x
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
    where a.active and (a.guest_policy = 'unknown' or a.checked_at is null)
    limit greatest(coalesce(p_limit,100),1)) t;
  return coalesce(v, '[]'::jsonb);
end $$;

revoke all on function public.bo_kural_suphe_kuyrugu(text,int) from public, anon, authenticated;
revoke all on function public.bo_kural_suphe_karar(uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.bo_kural_bilinmeyenler(int) from public, anon, authenticated;
grant execute on function public.bo_kural_suphe_kuyrugu(text,int) to service_role;
grant execute on function public.bo_kural_suphe_karar(uuid,uuid,text,text) to service_role;
grant execute on function public.bo_kural_bilinmeyenler(int) to service_role;

-- ── 8 · Anlaşmazlık: uygulama hiç açmıyordu → BO sayfası ölüydü ──
-- open_dispute vardı; ekranda düğmesi yoktu. Ekran 4.15'te ekleniyor.
-- Burada: açılan anlaşmazlık BO'ya bildirim ve 24 saat penceresi
-- kapida_ret ile aynı beta_settings anahtarını okusun.
create or replace function public.open_dispute(p_session uuid, p_reason text, p_detail text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype; v_saat int; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  if coalesce(p_reason,'') not in ('gelmedi','kapida_ret','ucret','davranis','kredi','diger') then
    raise exception 'dispute_reason_invalid';
  end if;
  select * into v_s from sessions where id = p_session;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if v_r.guest_id <> v_uid and v_r.host_id <> v_uid then raise exception 'not_participant'; end if;
  v_saat := coalesce((select (value #>> '{}')::int from beta_settings where key = 'kapida_ret_saat'), 24) * 3;
  if coalesce(v_s.completed_at, v_s.started_at) < now() - make_interval(hours => v_saat) then
    raise exception 'dispute_window_closed';
  end if;
  if exists (select 1 from disputes where session_id = p_session and status = 'open') then
    raise exception 'dispute_already_open';
  end if;
  insert into disputes (session_id, request_id, opener_id, reason, detail)
  values (p_session, v_s.request_id, v_uid, p_reason, left(nullif(btrim(coalesce(p_detail,'')),''), 600))
  returning id into v_id;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_uid, 'system', 'Bildirimin alındı', 'Ekibimiz 48 saat içinde inceleyip sana yazacak.', 'session', p_session);
  return jsonb_build_object('ok', true, 'id', v_id, 'sla_saat', 48);
end $$;

-- ── NÖBETÇİLER ──────────────────────────────────────────────────
do $$
declare v_n int;
begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_kapida_ret_suphe') then raise exception '284: kapida ret trigger yok'; end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_saha_raporu_suphe') then raise exception '284: saha raporu trigger yok'; end if;
  if pg_get_functiondef('public.lounge_access_decision_v6'::regproc) not like '%kural_guncelligi%' then raise exception '284: v6 guncellik okumuyor'; end if;
  if pg_get_functiondef('public.kural_kosullari'::regproc) not like '%guncellik%' then raise exception '284: kural_kosullari guncellik satiri yok'; end if;
  if has_table_privilege('authenticated', 'kural_supheleri', 'select') then raise exception '284: kural_supheleri istemciye acik'; end if;
  if has_function_privilege('authenticated', 'public.bo_kural_suphe_karar(uuid,uuid,text,text)', 'execute') then raise exception '284: bo karar authenticated''a acik'; end if;
  select count(*) into v_n from pg_trigger where tgrelid in ('lounge_guest_rules'::regclass,'lounge_programs'::regclass,'lounge_venue_acceptance'::regclass)
    and tgname like '%suphe%';
  if v_n > 0 then raise exception '284: kural tablolarina tetikleyici takilmis (%)', v_n; end if;
  raise notice '284 NOBETCI OK: suphe yan tabloda · v6 uyariyor · BO kuyruk+karar · kural tablolari dokunulmadi';
end $$;

-- ── 9 · resolve_dispute: iade TEK KAPIDAN (280'in istek_kredisi_iade'si) ──
-- Eski gövde koşulsuz +1 yazıyordu: kapıda ret iadesi zaten verilmişse
-- İKİNCİ iade; bedelsiz istekte YOKTAN kredi (K1'in aynısı, başka kapıdan).
-- İki fonksiyon da AÇIK tanımla (280'in gövdesi + dispute_refund sebebi).
CREATE OR REPLACE FUNCTION public.istek_kredisi_iade(p_req uuid, p_reason text, p_ref uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_r      requests%rowtype;
  v_tutulan int;
  v_bal    int;
  v_thanks record;
  v_iade   int := 0;
begin
  select * into v_r from requests where id = p_req;
  if not found then return 0; end if;

  -- İDEMPOTENT: bu istek için herhangi bir iade zaten yazılmışsa DUR.
  -- Sebep adı ne olursa olsun — beş farklı yol beş farklı ad kullanıyor.
  if exists (select 1 from credit_ledger
              where ref_id = p_req
                and reason in ('request_refund','request_cancel_refund',
                               'session_cancel_refund','expired_refund',
                               'no_show_refund','request_stale_refund',
                               'kapida_ret_iade','dispute_refund')) then
    return 0;
  end if;

  -- Ne tutulduysa o iade edilir. Tutma kaydı İKİ ADLA yazılıyor:
  -- `request_hold` (bedel>0) ve `request_free_tier` (bedel 0, delta 0).
  -- 🔴 İlk yazımda yalnız `request_hold` arıyordum; bedelsiz istekte
  -- kayıt bulunamayınca "eski dönem, 1 varsay" dalına düşüp K1'i
  -- AYNEN yeniden üretiyordu. Kendi testim (t1) yakaladı: 3 → 4.
  -- Tutma kaydı HİÇ yoksa (gerçekten eski kayıt) 1 varsayılır.
  select -min(delta) into v_tutulan
    from credit_ledger
   where ref_id = p_req and reason in ('request_hold','request_free_tier');
  v_tutulan := greatest(0, coalesce(v_tutulan, 1));

  if v_tutulan > 0 then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, v_tutulan, p_reason, coalesce(p_ref, p_req), v_bal + v_tutulan);
    v_iade := v_tutulan;
  else
    -- Bedel 0'dı: iade YOK ama iz bırak — idempotency bu satıra bakıyor
    -- ve "0 iade edildi" de bir karardır, sessizlik değil.
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, 0, p_reason, coalesce(p_ref, p_req), v_bal);
  end if;

  -- K3 · ücretli misafir teşekkür kredisi geri alınır (varsa, bir kez)
  for v_thanks in
    select * from credit_ledger
     where reason = 'paid_guest_thanks:' || p_req::text
  loop
    if not exists (select 1 from credit_ledger
                    where reason = 'paid_guest_thanks_reversal:' || p_req::text
                      and user_id = v_thanks.user_id) then
      select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_thanks.user_id;
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_thanks.user_id, -v_thanks.delta,
              'paid_guest_thanks_reversal:' || p_req::text, p_req, v_bal - v_thanks.delta);
    end if;
  end loop;

  return v_iade;
end $function$;

CREATE OR REPLACE FUNCTION public.resolve_dispute(p_dispute uuid, p_decision text, p_admin uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_d disputes%rowtype; v_r requests%rowtype; v_bal int;
begin
  select * into v_d from disputes where id = p_dispute for update;
  if not found then raise exception 'dispute_not_found'; end if;
  if v_d.status <> 'open' then raise exception 'already_decided'; end if;
  select * into v_r from requests where id = v_d.request_id;

  if p_decision = 'refund' then
    perform public.istek_kredisi_iade(v_r.id, 'dispute_refund', p_dispute);   -- 284/9: idempotent, tutulan kadar
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_r.guest_id, 'system', 'İtirazın sonuçlandı', 'Kredin iade edildi.', 'dispute', p_dispute);
  elsif p_decision = 'partial' then
    -- kısmi: puan telafisi (kredi iade yok)
    insert into points_ledger (user_id, delta, reason) values (v_r.guest_id, 250, 'dispute_partial');
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_r.guest_id, 'system', 'İtirazın sonuçlandı', 'Kısmi telafi uygulandı.', 'dispute', p_dispute);
  else -- capture: kredi host lehine kapanır, iade yok
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_d.opener_id, 'system', 'İtirazın sonuçlandı', 'İtiraz reddedildi.', 'dispute', p_dispute);
  end if;

  update disputes set status = case when p_decision='capture' then 'rejected' else 'resolved' end,
    decision = p_decision, decided_by = p_admin, decided_at = now() where id = p_dispute;
  return jsonb_build_object('ok', true, 'decision', p_decision);
end $function$;

do $$
begin
  if pg_get_functiondef('public.resolve_dispute'::regproc) not like '%istek_kredisi_iade%' then raise exception '284: resolve_dispute yamali degil'; end if;
  raise notice '284/9 NOBETCI OK: dispute iadesi tek kapidan';
end $$;
