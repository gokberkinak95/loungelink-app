-- ============================================================================
-- 309 · KURAL TABLOSU DENETİMİ (30 Eylül) + İLANIN ERİŞİM KAYNAĞI
--
-- Kaynak: Gökberk'in "kural tabloları.xlsx" (THY yurtiçi/yurtdışı/anlaşmalı
-- salonlar, THY + M&S + AJet + Pegasus + Priority Pass + DragonPass kuralları)
-- ve "lounge (2).zip" (PP / LoungeKey / DragonPass'in Türkiye salon listeleri).
-- Salon × program tablomuz bu kaynaklarla tek tek karşılaştırıldı. Bulunanlar:
--
--  A) THY'NİN KENDİ SALONLARI "YER TUTUCU" DURUYORDU → misafire "doğrulayamadık"
--     IST iç hat (Business) ayrı bir kayıt gibi duruyordu; THY'nin sayfasında iç
--     hat TEK salon ("Miles&Smiles ve Business Lounge"). AYT dış hat (FTA CIP) ve
--     BJV iç hat THY'nin resmî salon listesinde; M&S satırı "bilinmiyor"du.
--  B) SAW THY CIP (iç hat) 3 Nisan'dan beri GEÇİCİ HİZMET DIŞI (AJet tablosu).
--     Seçicide duruyordu: host ilan açabiliyor, misafir kapıda kalıyordu.
--  C) THY OLMAYAN salonlarda (Primeclass, Plaza, Çelebi, CIP Lounge, Kepler…)
--     M&S satırı "bilinmiyor" yer tutucusuydu. THY'nin Türkiye'deki M&S erişimi
--     yalnız kendi salonlarında; anlaşmalı listede bu salonlar yok → GEÇMEZ.
--  D) EKSİK KABULLER: SAW Kepler Club (Priority Pass listesinde + Pegasus
--     indirimli), COV Çelebi iç hat (Pegasus 1260 TL), AYT CIP iç hat T3
--     (DragonPass listesinde).
--  E) Rakamsız "uçuş numarası" ("TK" gibi — havayolu öneki) kayıtları temizlenir.
--  F) YENİ: set_availability_program — host ilanın erişim kaynağını AÇIKÇA seçer
--     (İlan ekle 1. adım). Kural motoru misafire kararı bu programa göre verir.
--
-- Supabase SQL Editor: tamamını yapıştır, çalıştır. Tekrar koşulabilir.
-- ============================================================================

-- ⚠️ Kimlikler (uuid) kurulumdan kuruluma farklı: salonlar HER YERDE havalimanı + adla bulunur.
--    Bulunamayan salon için ifade 0 satır etkiler, hata vermez.

-- ── A) THY'nin kendi salonları: yer tutucu → gerçek kabul ──────────────────
-- A1 · IST iç hat (Business) yer tutucusu: tek salonun (İç Hat) kopyası.
--      Salon seçiciden çekilir; eski ilanları varsa venue'ları asıl kayda taşınır.
update availabilities set venue_id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat' and active limit 1)
 where venue_id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat (Business)' limit 1);

update lounges set active = false
 where venue_id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat (Business)' limit 1) and active;

update lounge_venues set active = false,
       notes = trim(coalesce(notes,'') || ' · 309: THY IST iç hat tek salon (M&S ve Business birlikte); bu kayıt kopyaydı.')
 where id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat (Business)' limit 1) and active;

update lounge_venue_acceptance set active = false
 where venue_id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat (Business)' limit 1) and active;

-- A2 · AYT dış hat (FTA CIP) ve BJV iç hat: THY'nin resmî salonları → M&S kabul.
update lounge_venue_acceptance a
   set accepted = true, guest_policy = 'included', is_placeholder = false,
       guest_flight_coupling = 'same_carrier',
       conditions = 'THY resmî salonu. Misafir hakkı statüye göre (ELPL/Elite/EC/SAG/PLM: aile veya 1 misafir; Classic Plus: misafir yok). Misafir de THY seferinde olmalı.',
       checked_at = date '2026-09-30', verified_by = 'kural tabloları.xlsx (THY)', updated_at = now()
  from lounge_programs p
 where p.id = a.program_id and p.code = 'TK_MS'
   and a.venue_id in ((select id from lounge_venues where airport_code = 'AYT' and name = 'Antalya Havalimanı dış hatlar özel yolcu salonu (FTA CIP Salonları)' limit 1),   -- AYT dış hat FTA CIP
                      (select id from lounge_venues where airport_code = 'BJV' and name = 'Milas-Bodrum Havalimanı iç hatlar özel yolcu salonu' limit 1));  -- BJV iç hat

-- ── B) SAW THY CIP iç hat — geçici hizmet dışı ─────────────────────────────
-- Venue AKTİF kalır (eski ilanların kural kararı çözülsün); yalnız seçiciden çekilir.
update lounges set active = false
 where venue_id = (select id from lounge_venues where airport_code = 'SAW' and name = 'Turkish Airlines CIP Lounge — İç Hat' limit 1) and active;

update lounge_venues
   set notes = trim(coalesce(notes,'') || ' · 309: 3 Nisan 2026''dan beri GEÇİCİ HİZMET DIŞI (AJet kural tablosu). Açılınca lounges.active = true.')
 where id = (select id from lounge_venues where airport_code = 'SAW' and name = 'Turkish Airlines CIP Lounge — İç Hat' limit 1)
   and coalesce(notes,'') not like '%GEÇİCİ HİZMET DIŞI%';

-- ── C) THY olmayan salonlarda M&S yer tutucusu → geçmez ────────────────────
update lounge_venue_acceptance a
   set accepted = false, guest_policy = 'not_allowed', is_placeholder = false,
       conditions = 'Miles&Smiles statüsü bu salonda geçmez: THY''nin Türkiye''deki statü erişimi yalnız kendi salonlarında (kural tabloları, THY anlaşmalı salon listesi).',
       checked_at = date '2026-09-30', verified_by = 'kural tabloları.xlsx (THY)', updated_at = now()
  from lounge_programs p, lounge_venues v
 where p.id = a.program_id and p.code = 'TK_MS'
   and v.id = a.venue_id and v.active
   and a.is_placeholder
   and v.airport_code in (select code from airports where country ilike 't%rk%' or country = 'TR')
   and v.name not ilike '%turkish airlines%'
   and v.name not ilike '%özel yolcu salonu%';

-- ── D) Eksik kabuller (aynı programın mevcut bir satırı şablon alınır) ─────
-- D1 · SAW Kepler Club — Priority Pass. PP'nin SAW sayfası 4 tesis sayıyor, Kepler dahil (lounge(2).zip;
--      214'ün notu da aynısını söylüyor). Satır vardı ama pasifti → yeniden açılır.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count, guest_fee_amount, guest_fee_currency,
   guest_fee_note, guest_flight_coupling, max_stay_hours, earliest_entry_hours, conditions, enforcement,
   source_url, checked_at, verified_by, active, fee_payer, is_placeholder)
select k.id, t.program_id, true, t.guest_policy, t.guest_included_count,
       t.guest_fee_amount, t.guest_fee_currency, t.guest_fee_note, t.guest_flight_coupling, t.max_stay_hours,
       t.earliest_entry_hours, t.conditions, t.enforcement, t.source_url, date '2026-09-30',
       'lounge(2).zip · Priority Pass SAW', true, t.fee_payer, false
  from lounge_venues k, lounge_venue_acceptance t join lounge_programs p on p.id = t.program_id
 where k.airport_code = 'SAW' and k.name = 'Kepler Club — Dış Hat' and k.active
   and p.code = 'PRIORITY_PASS' and t.active and t.accepted and not coalesce(t.is_placeholder,false)
   and t.venue_id = (select id from lounge_venues where name = 'Plaza Premium Lounge — Marmara — Dış Hat' and airport_code = 'SAW' limit 1)
on conflict (venue_id, program_id) do update
   set active = true, accepted = true, is_placeholder = false,
       guest_policy = excluded.guest_policy, guest_fee_amount = excluded.guest_fee_amount,
       guest_fee_currency = excluded.guest_fee_currency, guest_flight_coupling = excluded.guest_flight_coupling,
       conditions = excluded.conditions, checked_at = excluded.checked_at, verified_by = excluded.verified_by,
       fee_payer = excluded.fee_payer, updated_at = now();

-- D2 · AYT CIP Lounge iç hat (T3) — DragonPass. 28 Eylül'de "kaynak belirsiz" diye kapatılmıştı
--      (DP sayfası terminal yazmıyor). Çözüldü: DP'nin "CIP Lounge" kartındaki fotoğraf, PP'nin
--      "CIP Lounge Domestic · Domestic Terminal 3" kartındaki fotoğrafla AYNI (lounge(2).zip).
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count, guest_fee_amount, guest_fee_currency,
   guest_fee_note, guest_flight_coupling, max_stay_hours, earliest_entry_hours, conditions, enforcement,
   source_url, checked_at, verified_by, active, fee_payer, is_placeholder)
select v.id, t.program_id, true, t.guest_policy, t.guest_included_count,
       t.guest_fee_amount, t.guest_fee_currency, t.guest_fee_note, t.guest_flight_coupling, t.max_stay_hours,
       t.earliest_entry_hours, t.conditions, t.enforcement, t.source_url, date '2026-09-30',
       'lounge(2).zip · DragonPass AYT', true, t.fee_payer, false
  from lounge_venues v, lounge_venue_acceptance t join lounge_programs p on p.id = t.program_id
 where v.airport_code = 'AYT' and v.name = 'CIP Lounge — İç Hat (T3)' and v.active
   and p.code = 'DRAGONPASS' and t.active and t.accepted and not coalesce(t.is_placeholder,false)
   and t.venue_id = (select id from lounge_venues where name = 'Comfort Lounge — Dış Hat (T2)' and airport_code = 'AYT' limit 1)
on conflict (venue_id, program_id) do update
   set active = true, accepted = true, is_placeholder = false,
       guest_policy = excluded.guest_policy, guest_fee_amount = excluded.guest_fee_amount,
       guest_fee_currency = excluded.guest_fee_currency, guest_flight_coupling = excluded.guest_flight_coupling,
       conditions = excluded.conditions, checked_at = excluded.checked_at, verified_by = excluded.verified_by,
       fee_payer = excluded.fee_payer, updated_at = now();

-- D3 · Pegasus indirimli ücretli giriş: SAW Kepler (tutar yazılmamış) · COV Çelebi iç hat 1260 TL
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_fee_amount, guest_fee_currency, guest_fee_note,
   guest_flight_coupling, max_stay_hours, conditions, checked_at, verified_by, active, fee_payer, is_placeholder)
select v.id, p.id, true, 'paid', x.tutar, x.para, x.notu, 'same_carrier', 3,
       'Pegasus yolcusuna indirimli ücretli giriş (Pegasus salon sayfası).',
       date '2026-09-30', 'kural tabloları.xlsx (Pegasus)', true, 'guest_at_door', false
  from (values ('SAW', 'Kepler Club — Dış Hat', null::numeric, null::text, 'Pegasus yolcusuna indirimli; tutar salonda'),
               ('COV', 'Çelebi Platinum Lounge — İç Hat', 1260::numeric, 'TRY', 'KDV dahil, 3 saat')) x(ap, ad, tutar, para, notu)
  join lounge_venues v on v.airport_code = x.ap and v.name = x.ad and v.active
  cross join lounge_programs p
 where p.code = 'PGS_PAID'
on conflict (venue_id, program_id) do nothing;

-- ── E) Rakamsız "uçuş numarası" ────────────────────────────────────────────
update visits set flight_number = null
 where flight_number is not null and flight_number !~ '[0-9]';
update availabilities set flight_number = null
 where flight_number is not null and flight_number !~ '[0-9]';

-- ── F) İlanın erişim kaynağı: host açıkça seçer ─────────────────────────────
create or replace function public.set_availability_program(p_avail_id uuid, p_program text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_uid uuid := auth.uid(); v_pid uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from availabilities where id = p_avail_id and host_id = v_uid) then
    raise exception 'availability_not_found';
  end if;
  select id into v_pid from lounge_programs where code = upper(btrim(coalesce(p_program,'')));
  if v_pid is null then raise exception 'program_not_found'; end if;
  -- Beyan edilmemiş bir hakkı ilana yazmak kuralı kandırmak olur.
  if not exists (select 1 from host_entitlements where user_id = v_uid and program_id = v_pid) then
    raise exception 'program_not_declared';
  end if;
  update availabilities set program_id = v_pid, program_source = 'beyan' where id = p_avail_id;
  return jsonb_build_object('ok', true, 'program', upper(btrim(p_program)));
end $fn$;
revoke all on function public.set_availability_program(uuid, text) from public, anon;
grant execute on function public.set_availability_program(uuid, text) to authenticated;

insert into rpc_client_surface (fn_name, client, note)
values ('set_availability_program', 'app', 'İlan ekle 1. adım: host ilanın erişim kaynağını seçer (309).')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

-- ── Doğrulama ───────────────────────────────────────────────────────────────
do $$
declare v_ph int; v_saw int; v_ist int; v_d int;
begin
  select count(*) into v_ph
    from lounge_venue_acceptance a join lounge_programs p on p.id = a.program_id
    join lounge_venues v on v.id = a.venue_id
   where p.code = 'TK_MS' and a.active and a.is_placeholder and v.active
     and v.airport_code in (select code from airports where country ilike 't%rk%' or country = 'TR');
  select count(*) into v_saw from lounges where venue_id = (select id from lounge_venues where airport_code = 'SAW' and name = 'Turkish Airlines CIP Lounge — İç Hat' limit 1) and active;
  select count(*) into v_ist from lounges where venue_id = (select id from lounge_venues where airport_code = 'IST' and name = 'Turkish Airlines Lounge — İç Hat (Business)' limit 1) and active;
  select count(*) into v_d from lounge_venue_acceptance where verified_by like 'lounge(2).zip%' or verified_by = 'kural tabloları.xlsx (Pegasus)';
  raise notice '309: TR M&S yer tutucu kalan=% · SAW THY CIP seçicide=% · IST iç hat kopya seçicide=% · eklenen kabul=%',
    v_ph, v_saw, v_ist, v_d;
end $$;
