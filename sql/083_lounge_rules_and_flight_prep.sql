-- ============================================================
-- LoungeLink · 083_lounge_rules_and_flight_prep.sql
--
-- ⚠️ BU DOSYA UYGULAMAYI ETKİLEMEZ. Yalnızca yeni tablolar ve okuma
-- fonksiyonları ekler; mevcut hiçbir fonksiyonu, kapıyı veya akışı
-- DEĞİŞTİRMEZ. Amaç: BO'dan kural girmeye başlayabilmek ve uçuş verisi
-- entegrasyonuna hazır olmak. Kural motorunun akışlara BAĞLANMASI ayrı bir
-- migration olacak (Gokberk "hazırız" dediğinde).
--
-- Kaynak: THY resmi lounge kural sayfası (1 Haz – 31 Ara 2026 dönemi),
-- AJet CIP koşulları, Sabiha Gökçen Plaza Premium bilgileri.
-- ============================================================


-- ============================================================
-- 1) LOUNGE PROGRAMLARI — hakkı VEREN taraf
-- ============================================================
create table if not exists lounge_programs (
  id            uuid primary key default uuid_generate_v4(),
  code          text unique not null,          -- 'TK_MS', 'AJET_MS', 'PRIORITY_PASS'
  name          text not null,
  kind          text not null check (kind in ('airline','card_program','operator','bank')),
  source_url    text,                          -- kuralın alındığı resmi sayfa
  rules_version text,                          -- '2026-06-01 → 2026-12-31'
  checked_at    date,                          -- 🔴 kurallar değişir; bayat kural tehlikeli
  notes         text,
  active        boolean default true,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ============================================================
-- 2) SALONLAR — fiziksel mekân, terminal ve BÖLÜM
-- Bölüm kritik: IST dış hatta Business bölümünde misafir hakkı YOK,
-- aynı yolcu M&S bölümüne girerse hakkı VAR.
-- ============================================================
create table if not exists lounge_venues (
  id             uuid primary key default uuid_generate_v4(),
  airport_code   text not null references airports(code),
  name           text not null,
  terminal       text,
  section        text,                          -- 'business' | 'miles_smiles' | null
  operator       text,                          -- 'THY' | 'Plaza Premium' | 'IGA'
  scope          text check (scope in ('domestic','international','both')),
  opens_at       time, closes_at time,
  capacity_hint  int,
  notes          text,
  active         boolean default true,
  created_at     timestamptz default now()
);
-- NOT: ifade içeren benzersizlik kısıtı tablo içinde tanımlanamaz (PostgreSQL);
-- ayrı bir UNIQUE INDEX olarak kuruluyor.
create unique index if not exists uq_lounge_venue
  on lounge_venues (airport_code, name, coalesce(section, ''));

-- ============================================================
-- 3) MİSAFİR HAKKI KURALLARI — koşul → sonuç matrisi
-- ============================================================
create table if not exists lounge_guest_rules (
  id                uuid primary key default uuid_generate_v4(),
  program_id        uuid not null references lounge_programs(id) on delete cascade,
  venue_id          uuid references lounge_venues(id) on delete cascade,  -- null = programın tüm salonları
  -- KOŞULLAR (null = fark etmez)
  carrier           text,       -- 'TK' | 'AJET' | 'STAR_ALLIANCE'
  card_tier         text,       -- 'ELPL' | 'ELITE' | 'CLPL' | 'CLASSIC' | 'CORP' | 'MS_EC'
  cabin_class       text check (cabin_class in ('economy','business','first')),
  -- SONUÇ
  guest_allowance          smallint not null default 0 check (guest_allowance between 0 and 6),
  family_allowed           boolean default false,
  guest_must_match_carrier boolean default false,   -- 🔴 THY md.17
  guest_carrier_whitelist  text[],
  earliest_entry_hours     numeric,                 -- uçuştan en erken kaç saat önce
  paid_entry_allowed       boolean default false,
  paid_entry_price_note    text,
  blocked_reason           text,                    -- 'charter' gibi mutlak engeller
  notes                    text,
  effective_from    date, effective_to date,
  created_at        timestamptz default now()
);

create index if not exists idx_lgr_program on lounge_guest_rules(program_id);
create index if not exists idx_lgr_venue   on lounge_guest_rules(venue_id);

-- İlanın hangi program/salon/taşıyıcı ile açıldığı (ŞİMDİLİK OPSİYONEL —
-- uygulama bu alanları doldurmuyor, kural motoru açılınca dolduracak)
alter table availabilities add column if not exists program_id uuid references lounge_programs(id);
alter table availabilities add column if not exists venue_id   uuid references lounge_venues(id);
alter table availabilities add column if not exists carrier    text;


-- ============================================================
-- 4) KURAL SORGUSU — motor bağlanınca kullanılacak, şimdi yalnız BO okur
-- "Bu host, bu misafiri bu salona alabilir mi?"
-- ============================================================
create or replace function public.lounge_rule_check(
  p_program_code text,
  p_venue_id     uuid,
  p_carrier      text,
  p_card_tier    text,
  p_cabin        text,
  p_guest_flight text default null      -- misafirin uçuş no'su ('TK712')
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_r lounge_guest_rules%rowtype; v_guest_carrier text; v_warns text[] := '{}';
begin
  select r.* into v_r
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = p_program_code
     and (r.venue_id is null or r.venue_id = p_venue_id)
     and (r.carrier is null or r.carrier = p_carrier)
     and (r.card_tier is null or r.card_tier = p_card_tier)
     and (r.cabin_class is null or r.cabin_class = p_cabin)
     and (r.effective_from is null or r.effective_from <= current_date)
     and (r.effective_to is null or r.effective_to >= current_date)
   order by (r.venue_id is not null) desc,      -- salona özel kural genel kuralı ezer
            (r.card_tier is not null) desc,
            (r.cabin_class is not null) desc
   limit 1;

  if not found then
    return jsonb_build_object('known', false,
      'message', 'Bu program/salon için kayıtlı kural yok — kapıda teyit et.');
  end if;

  if v_r.blocked_reason is not null then
    return jsonb_build_object('known', true, 'allowed', false,
      'reason', v_r.blocked_reason, 'guest_allowance', 0);
  end if;

  -- misafirin taşıyıcısı uçuş numarasının harf önekinden çıkarılır (TK712 → TK)
  v_guest_carrier := upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+'));

  if v_r.guest_must_match_carrier and v_guest_carrier <> '' and v_guest_carrier <> p_carrier then
    v_warns := v_warns || format('Bu salonun kuralı: misafir de %s seferinde uçmalı (misafirin uçuşu %s).',
                                 p_carrier, p_guest_flight);
  end if;
  if v_r.guest_carrier_whitelist is not null and array_length(v_r.guest_carrier_whitelist,1) > 0
     and v_guest_carrier <> '' and not (v_guest_carrier = any(v_r.guest_carrier_whitelist)) then
    v_warns := v_warns || format('Misafirin taşıyıcısı (%s) bu salonun kabul listesinde değil.', v_guest_carrier);
  end if;
  if v_r.guest_allowance = 0 then
    v_warns := v_warns || ('Bu kart/kabin birleşiminde misafir hakkı bulunmuyor.')::text;
  end if;

  return jsonb_build_object(
    'known', true,
    'allowed', (v_r.guest_allowance > 0 and coalesce(array_length(v_warns,1),0) = 0),
    'guest_allowance', v_r.guest_allowance,
    'family_allowed', v_r.family_allowed,
    'earliest_entry_hours', v_r.earliest_entry_hours,
    'paid_entry_allowed', v_r.paid_entry_allowed,
    'warnings', to_jsonb(v_warns),
    'notes', v_r.notes
  );
end $$;
grant execute on function public.lounge_rule_check(text, uuid, text, text, text, text) to authenticated;

-- RLS: kurallar herkese OKUNUR (uygulama ileride gösterecek), yazma yalnız servis
alter table lounge_programs    enable row level security;
alter table lounge_venues      enable row level security;
alter table lounge_guest_rules enable row level security;
drop policy if exists lp_read on lounge_programs;
create policy lp_read on lounge_programs for select to authenticated using (active = true);
drop policy if exists lv_read on lounge_venues;
create policy lv_read on lounge_venues for select to authenticated using (active = true);
drop policy if exists lgr_read on lounge_guest_rules;
create policy lgr_read on lounge_guest_rules for select to authenticated using (true);


-- ============================================================
-- 5) İLK VERİ — THY resmi sayfasından (5 Ağu 2026'da okundu)
-- ============================================================
insert into lounge_programs (code, name, kind, source_url, rules_version, checked_at) values
 ('TK_MS','Turkish Airlines Miles&Smiles','airline',
  'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
  '2026-06-01 → 2026-12-31', current_date),
 ('AJET_MS','AJet (Miles&Smiles kartıyla)','airline',
  'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
  '2026-06-01 → 2026-12-31', current_date),
 ('PRIORITY_PASS','Priority Pass','card_program', null, null, null),
 ('DRAGONPASS','DragonPass','card_program', null, null, null),
 ('LOUNGEKEY','LoungeKey','card_program', null, null, null)
on conflict (code) do nothing;

insert into lounge_venues (airport_code, name, terminal, section, operator, scope) values
 ('IST','Turkish Airlines Lounge — Dış Hat (Business)','Dış Hat','business','THY','international'),
 ('IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','Dış Hat','miles_smiles','THY','international'),
 ('IST','Turkish Airlines Lounge — İç Hat','İç Hat',null,'THY','domestic'),
 ('SAW','Plaza Premium Lounge',null,null,'Plaza Premium','both')
on conflict do nothing;

-- THY kuralları (özet — matris BO'dan genişletilecek)
insert into lounge_guest_rules
 (program_id, venue_id, carrier, card_tier, cabin_class, guest_allowance, family_allowed,
  guest_must_match_carrier, guest_carrier_whitelist, earliest_entry_hours, paid_entry_allowed, notes)
select p.id, null, 'TK', t.tier, null, t.allow, t.fam, true, array['TK'], null, false, t.note
  from lounge_programs p,
       (values ('ELPL',1,true, 'Elite Plus: aile veya bir misafir'),
               ('ELITE',1,true,'Elite: aile veya bir misafir'),
               ('MS_EC',1,true,'Elite Corporate: aile VEYA 1 misafir'),
               ('CORP',1,false,'Corporate Club: aynı bilette dış hat bağlantısı şartı'),
               ('CLPL',0,false,'Classic Plus: misafir hakkı yok'),
               ('CLASSIC',0,false,'Classic: misafir hakkı yok, ücretli giriş mümkün')
       ) as t(tier, allow, fam, note)
 where p.code = 'TK_MS'
 on conflict do nothing;

-- IST dış hat BUSINESS bölümü: misafir hakkı YOK (salona özel kural, geneli ezer)
insert into lounge_guest_rules
 (program_id, venue_id, carrier, card_tier, cabin_class, guest_allowance, family_allowed, notes)
select p.id, v.id, 'TK', null, 'business', 0, false,
       'IST dış hat Business bölümünde misafir/aile hakkı yok; misafir getirilecekse Miles&Smiles bölümüne girilmeli'
  from lounge_programs p, lounge_venues v
 where p.code = 'TK_MS' and v.airport_code='IST' and v.section='business'
 on conflict do nothing;


-- ============================================================
-- 6) UÇUŞ VERİSİ HAZIRLIĞI (AviationStack vb.) — app'e YANSIMAZ
-- Alanlar boş kaldığı sürece hiçbir ekran değişmez.
-- ============================================================
alter table visits add column if not exists flight_verified     boolean default false;
alter table visits add column if not exists scheduled_departure timestamptz;
alter table visits add column if not exists scheduled_arrival   timestamptz;
alter table visits add column if not exists terminal            text;
alter table visits add column if not exists flight_source       text;   -- 'aviationstack' | 'manual'
alter table visits add column if not exists flight_checked_at   timestamptz;

-- Sağlayıcı kotasını korumak için ÖNBELLEK: aynı uçuş/gün bir kez sorgulanır
create table if not exists flight_cache (
  flight_no      text not null,
  flight_date    date not null,
  departure_iata text, arrival_iata text,
  scheduled_departure timestamptz, scheduled_arrival timestamptz,
  terminal text, gate text, status text,
  raw jsonb,
  source text default 'aviationstack',
  fetched_at timestamptz default now(),
  primary key (flight_no, flight_date)
);
alter table flight_cache enable row level security;
drop policy if exists fc_read on flight_cache;
create policy fc_read on flight_cache for select to authenticated using (true);

-- Uygulama/BO bunu çağırır; önbellekte varsa oradan döner (kota korunur).
-- Önbellekte yoksa 'miss' döner — dolduran taraf BO/edge function olacak.
create or replace function public.flight_lookup(p_flight_no text, p_date date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v flight_cache%rowtype;
begin
  select * into v from flight_cache
   where upper(flight_no) = upper(trim(p_flight_no)) and flight_date = p_date;
  if not found then
    return jsonb_build_object('hit', false);
  end if;
  return jsonb_build_object('hit', true,
    'scheduled_departure', v.scheduled_departure, 'terminal', v.terminal,
    'status', v.status, 'source', v.source, 'fetched_at', v.fetched_at);
end $$;
grant execute on function public.flight_lookup(text, date) to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_programs)    as programlar,
       (select count(*) from lounge_venues)      as salonlar,
       (select count(*) from lounge_guest_rules) as kurallar;

-- Örnek: TK Elite Plus, misafirin uçuşu AJet → UYARI dönmeli
select public.lounge_rule_check('TK_MS', null, 'TK', 'ELPL', 'economy', 'AJ1234') as ajet_misafir_uyarisi;
-- Aynı kişi, misafir TK ile uçuyorsa → izin
select public.lounge_rule_check('TK_MS', null, 'TK', 'ELPL', 'economy', 'TK712') as tk_misafir_uygun;

select '083 OK - lounge kural tablolari + ucus verisi altyapisi kuruldu (uygulama ETKILENMEDI)' as sonuc;
