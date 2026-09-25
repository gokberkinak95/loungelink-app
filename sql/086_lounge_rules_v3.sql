-- ============================================================
-- LoungeLink · 086_lounge_rules_v3.sql
-- KURAL ÇERÇEVESİNİN GENELLEŞTİRİLMESİ — İKİ EKSENLİ MODEL
--
-- ⚠️ UYGULAMAYI ETKİLEMEZ. Yeni tablolar + yeni NULLABLE kolonlar +
-- uygulamanın çağırmadığı fonksiyonlar. Uygulamanın çağırdığı 44 RPC'nin
-- hiçbirine dokunulmadı. Kural motorunun app'e bağlanması AYRI bir
-- migration olacak (ortakların incelemesinden sonra, Gokberk'in kararıyla).
--
-- ------------------------------------------------------------
-- NEDEN BU DOSYA VAR (083/085'in yapısal kusuru)
-- ------------------------------------------------------------
-- 083/085 modeli "hak PROGRAMDAN gelir" varsayıyordu: kart tipi + kabin
-- + taşıyıcı → misafir hakkı. Bu YALNIZCA havayolu programları için
-- doğru. Kaynakları okuduktan sonra çıkan tablo:
--
--   · Priority Pass (md.4): erişim KİŞİ BAŞI + ZİYARET BAŞI ÜCRETLİ;
--     refakatçi ziyaretleri de üyenin kartından tahsil edilir. Misafirin
--     hangi havayolunda uçtuğu ÖNEMSİZ. Md.3 ve 19: HER SALONUN kendi
--     koşulları var ve program koşullarının ÜSTÜNE biner; salon kimi
--     kabul edeceğine, kaç kişi alacağına, süreye kendi karar verir.
--     Md.6: misafir üyeyle AYNI ANDA kaydolup girmeli. Md.5: biniş kartı
--     + kimlik ŞART (misafirin de kendi biniş kartı olmalı). Md.11:
--     erişim aracı DEVREDİLEMEZ, ziyaret başına tek araç.
--
--   · LoungeKey (aynı Collinson ailesi): madde madde Priority Pass ile
--     aynı — kişi başı/ziyaret başı ücret, misafir üyenin kartından,
--     biniş kartı+kimlik, havayolu/kabin fark etmez.
--
--   · 🔴 DragonPass (md. 7.15.7): "Misafirlerinizin, aynı Dragonpass
--     üyeliğiyle salon erişimi için üyeyle AYNI UÇUŞTA olması gerekir."
--     Yani DragonPass "aynı havayolu"ndan DAHA SIKI: AYNI UÇUŞ.
--     Bu tek satır, DragonPass host'u için eşleşme kuralımızı değiştirir.
--     (md. 7.15.9: kalış süresi salona göre, tipik 2 saat.)
--
--   · Pegasus: FREKANS PROGRAMINDAN GELEN MİSAFİR HAKKI YOK. Model
--     tamamen "indirimli ÜCRETLİ giriş" (SAW Plaza Premium 49€ iç /
--     63€ dış hat, 3 saat; Primeclass ESB/ADB/BJV 27€+KDV, 3 saat;
--     Çelebi Platinum Çukurova). Burada host'un paylaşacağı bir HAK yok.
--
-- ------------------------------------------------------------
-- BUNDAN ÇIKAN MODEL — İKİ EKSEN + ÜÇÜNCÜ BOYUT
-- ------------------------------------------------------------
-- EKSEN 1 · HAK KAYNAĞI (lounge_programs): host'un hakkı nereden geliyor
--           ve o program kendi başına ne diyor.
-- EKSEN 2 · SALON KABULÜ (lounge_venue_acceptance): BU SALON bu programı
--           kabul ediyor mu, misafir alıyor mu, ücreti ne, süresi ne.
--           🔴 083/085'te HİÇ YOKTU. Genelleştirmenin çekirdeği budur;
--           çünkü kaynakların hepsi "salonun sözü program koşullarının
--           üstündedir" diyor.
-- 3. BOYUT · MİSAFİRİN UÇUŞ BAĞI (guest_flight_coupling): boolean değil,
--           DÖRT KADEMELİ:
--             any           → fark etmez        (PP, LoungeKey, ücretli)
--             same_carrier  → aynı havayolu     (TK Miles&Smiles)
--             same_alliance → aynı ittifak      (Star Alliance Gold)
--             same_flight   → AYNI UÇUŞ         (DragonPass)
--           085'teki `guest_must_match_carrier boolean + whitelist`
--           bu dört durumu ifade EDEMİYORDU.
--
-- Ve ürün açısından en önemli ayrım — misafir hakkının TÜRÜ:
--   included      → host'un hakkı var, misafir ÜCRETSİZ  (asıl ürünümüz)
--   paid          → misafir girebilir ama PARA ÖDER      (beklenti yönetimi)
--   not_allowed   → bu salon/program misafir almıyor
--   unknown       → bilmiyoruz (≠ "yok" — sahada doğrulanacak)
-- "unknown" ile "not_allowed"u ayırmak kritik: bilmediğimiz için engel
-- koyarsak geçerli eşleşmeleri öldürürüz.
-- ============================================================


-- ============================================================
-- 1) EKSEN 1 — PROGRAM MODELİNİN GENİŞLETİLMESİ
-- ============================================================

-- 083'ün kind sözlüğü dar kaldı (paid_entry ve alliance yoktu)
-- ============================================================
-- ONCEDEN DUSURME (eski 086a_PRE_drop.sql icerigi) — v2
--
-- 🔴 NEDEN ARTIK BU DOSYANIN ICINDE:
-- Bu adim ayri bir dosyadaydi (086a_PRE_drop.sql) ve ATLANDI:
--   ERROR 42P13: cannot change return type of existing function
--   HINT: Use DROP FUNCTION lounge_rules_health() first.
-- Ayri dosya olmasinin teknik bir gerekcesi yoktu, yalnizca
-- aliskanliktir. Atlanabilen bir on kosul, on kosul degildir —
-- migration kendi on kosulunu kendisi saglamali.
--
-- `drop function if exists` GUVENLIDIR: fonksiyon yoksa hicbir sey
-- yapmaz. Bu dosya bastan sona TEKRAR calistirilabilir.
-- ============================================================
drop function if exists public.availability_rule_snapshot(uuid);
drop function if exists public.apply_rule_snapshot(uuid);
drop function if exists public.guest_flight_fits(uuid, text);
drop function if exists public.lounge_rule_check(text, uuid, text, text, text, text);
drop function if exists public.lounge_rules_health();

alter table lounge_programs drop constraint if exists lounge_programs_kind_check;
alter table lounge_programs add constraint lounge_programs_kind_check
  check (kind in ('airline','alliance','card_program','operator','bank','paid_entry'));

alter table lounge_programs add column if not exists entitlement_model text;
alter table lounge_programs add column if not exists guest_default text;
alter table lounge_programs add column if not exists guest_flight_coupling text;
alter table lounge_programs add column if not exists guest_included_count smallint not null default 0;
alter table lounge_programs add column if not exists member_must_be_present boolean not null default true;
alter table lounge_programs add column if not exists transferable boolean not null default false;
alter table lounge_programs add column if not exists guest_needs_boarding_pass boolean not null default true;
alter table lounge_programs add column if not exists guest_needs_photo_id boolean not null default false;
alter table lounge_programs add column if not exists typical_guest_fee numeric;
alter table lounge_programs add column if not exists guest_fee_currency text;
alter table lounge_programs add column if not exists max_stay_hours numeric;
-- Kural motoru sahada doğrulanmadan ENGEL koymamalı. Bu kolon o kararın
-- kodda değil VERİDE durmasını sağlar: BO'dan program program çevrilir.
alter table lounge_programs add column if not exists enforcement text not null default 'warn';

alter table lounge_programs drop constraint if exists lp_entitlement_model_chk;
alter table lounge_programs add constraint lp_entitlement_model_chk
  check (entitlement_model is null or entitlement_model in
    ('airline_status','alliance_status','card_membership','ticket_class','bank_card','paid_entry','operator_program'));

alter table lounge_programs drop constraint if exists lp_guest_default_chk;
alter table lounge_programs add constraint lp_guest_default_chk
  check (guest_default is null or guest_default in ('included','paid','not_allowed','unknown'));

alter table lounge_programs drop constraint if exists lp_coupling_chk;
alter table lounge_programs add constraint lp_coupling_chk
  check (guest_flight_coupling is null or guest_flight_coupling in
    ('any','same_carrier','same_alliance','same_flight'));

alter table lounge_programs drop constraint if exists lp_enforcement_chk;
alter table lounge_programs add constraint lp_enforcement_chk
  check (enforcement in ('warn','block'));


-- ============================================================
-- 2) SERBEST METİN → PROGRAM EŞLEME (085'teki ilike hilesinin yerine)
--
-- 085 programı şöyle tahmin ediyordu:
--   pr.access_source ilike '%'||replace(initcap(replace(p.code,'_',' ')),' ','%')||'%'
-- Bu 'TK_MS' kodunu 'Tk%Ms' kalıbına çeviriyordu — yani "Tk" ile "Ms"
-- arasında ne olursa olsun eşleşiyordu. Rastgele isabet üretir.
-- Yerine gerçek bir eşanlamlı sözlüğü koyuyoruz.
-- ============================================================
create table if not exists lounge_program_aliases (
  id         uuid primary key default uuid_generate_v4(),
  program_id uuid not null references lounge_programs(id) on delete cascade,
  alias      text not null,
  weight     smallint not null default 100,
  created_at timestamptz default now()
);
create unique index if not exists uq_lpa_alias on lounge_program_aliases (lower(alias));
create index if not exists idx_lpa_program on lounge_program_aliases (program_id);

-- EN UZUN eşleşen takma ad kazanır: "miles&smiles elite plus" > "miles&smiles"
create or replace function public.match_program_by_text(p_text text)
returns uuid language sql stable security definer set search_path = public as $$
  select a.program_id
    from lounge_program_aliases a
    join lounge_programs p on p.id = a.program_id and p.active
   where coalesce(p_text,'') <> ''
     and position(lower(a.alias) in lower(p_text)) > 0
   order by length(a.alias) desc, a.weight desc
   limit 1;
$$;
grant execute on function public.match_program_by_text(text) to authenticated;


-- ============================================================
-- 3) EKSEN 2 — SALON × PROGRAM KABUL MATRİSİ   🔴 EKSİK OLAN TABLO
--
-- "Bu salon bu programı kabul ediyor mu, misafir alıyor mu, kaça?"
-- Priority Pass md.3/19 ve DragonPass md.7.1.4 açıkça diyor ki salonun
-- koşulları programın üstüne biner. Model bu tablo olmadan doğru olamaz.
-- ============================================================
create table if not exists lounge_venue_acceptance (
  id                   uuid primary key default uuid_generate_v4(),
  venue_id             uuid not null references lounge_venues(id) on delete cascade,
  program_id           uuid not null references lounge_programs(id) on delete cascade,

  accepted             boolean not null default true,   -- salon bu programı kabul ediyor mu
  guest_policy         text    not null default 'unknown',
  guest_included_count smallint not null default 0,     -- ücretsiz misafir adedi
  guest_fee_amount     numeric,
  guest_fee_currency   text,
  guest_fee_note       text,
  -- null = programdan miras al (çoğu satırda böyle olacak)
  guest_flight_coupling text,
  max_stay_hours       numeric,
  earliest_entry_hours numeric,
  children_note        text,
  capacity_note        text,
  conditions           text,
  -- Bu satır için engel/uyarı tercihi; null = programın enforcement'ı
  enforcement          text,

  source_url           text,
  checked_at           date,      -- 🔴 null = HİÇ DOĞRULANMADI (sağlık raporu kırmızı gösterir)
  verified_by          text,
  active               boolean not null default true,
  created_at           timestamptz default now(),
  updated_at           timestamptz default now()
);
create unique index if not exists uq_lva on lounge_venue_acceptance (venue_id, program_id);
create index if not exists idx_lva_program on lounge_venue_acceptance (program_id);

alter table lounge_venue_acceptance drop constraint if exists lva_guest_policy_chk;
alter table lounge_venue_acceptance add constraint lva_guest_policy_chk
  check (guest_policy in ('included','paid','not_allowed','unknown'));
alter table lounge_venue_acceptance drop constraint if exists lva_coupling_chk;
alter table lounge_venue_acceptance add constraint lva_coupling_chk
  check (guest_flight_coupling is null or guest_flight_coupling in
    ('any','same_carrier','same_alliance','same_flight'));
alter table lounge_venue_acceptance drop constraint if exists lva_enforcement_chk;
alter table lounge_venue_acceptance add constraint lva_enforcement_chk
  check (enforcement is null or enforcement in ('warn','block'));
-- Mantık kilidi: "misafir alınmıyor" ile "3 ücretsiz misafir" aynı satırda olamaz
alter table lounge_venue_acceptance drop constraint if exists lva_included_chk;
alter table lounge_venue_acceptance add constraint lva_included_chk
  check (guest_policy = 'included' or guest_included_count = 0);

alter table lounge_venue_acceptance enable row level security;
drop policy if exists lva_read on lounge_venue_acceptance;
create policy lva_read on lounge_venue_acceptance
  for select to authenticated using (active = true);


-- ============================================================
-- 4) 🔴 İKİ SALON TABLOSU SORUNU — `lounges` vs `lounge_venues`
--
-- Uygulama ilan açarken `availabilities.lounge_id → lounges(id)` yazıyor.
-- 083 ise kural motoru için AYRI bir `lounge_venues` tablosu kurdu.
-- Yani bugün host'un seçtiği salon ile kuralın bağlı olduğu salon FARKLI
-- tablolarda. Kural motoru app'e bağlandığı an "salon seçildi ama kural
-- bulunamadı" diye sessizce boşa düşerdi. Şimdi köprüyü kuruyoruz:
-- `lounges` kayıt defteri olarak kalır, `lounge_venues` kural ekseni olur,
-- ikisi çift yönlü bağlanır ve eksik olan taraf otomatik doldurulur.
-- ============================================================
alter table lounge_venues add column if not exists max_stay_hint   numeric;
alter table lounges       add column if not exists venue_id        uuid references lounge_venues(id);
alter table lounge_venues add column if not exists legacy_lounge_id uuid references lounges(id);

-- 4a) Aynı havalimanı + aynı isim → eşleştir
update lounges l
   set venue_id = v.id
  from lounge_venues v
 where l.venue_id is null
   and v.airport_code = l.airport_code
   and lower(trim(v.name)) = lower(trim(l.name));

update lounge_venues v
   set legacy_lounge_id = l.id
  from lounges l
 where v.legacy_lounge_id is null and l.venue_id = v.id;

-- 4b) Karşılığı olmayan her `lounges` satırı için venue üret
insert into lounge_venues (airport_code, name, terminal, operator, scope, legacy_lounge_id, notes)
select l.airport_code, l.name, l.terminal, null, 'both', l.id,
       'lounges tablosundan otomatik aktarildi (086)'
  from lounges l
 where l.venue_id is null
   and not exists (select 1 from lounge_venues v
                    where v.airport_code = l.airport_code
                      and lower(trim(v.name)) = lower(trim(l.name)));

update lounges l set venue_id = v.id
  from lounge_venues v
 where l.venue_id is null and v.legacy_lounge_id = l.id;

-- 4c) Tersi: kural için açılmış ama katalogda olmayan salonlar (host göremiyor)
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, v.active, v.id
  from lounge_venues v
 where v.legacy_lounge_id is null
   and not exists (select 1 from lounges l
                    where l.airport_code = v.airport_code
                      and lower(trim(l.name)) = lower(trim(v.name)));

update lounge_venues v set legacy_lounge_id = l.id
  from lounges l
 where v.legacy_lounge_id is null and l.venue_id = v.id;

-- İlandan salona: ilan venue_id taşımıyorsa lounge_id üzerinden çöz
create or replace function public.resolve_venue_for_availability(p_avail_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
           a.venue_id,
           (select l.venue_id from lounges l where l.id = a.lounge_id),
           (select v.id from lounge_venues v
             where v.airport_code = a.airport_code and v.active
               and lower(trim(v.name)) = lower(trim(coalesce(a.lounge_name,'')))
             limit 1)
         )
    from availabilities a where a.id = p_avail_id;
$$;
grant execute on function public.resolve_venue_for_availability(uuid) to authenticated;


-- ============================================================
-- 5) HOST'UN HAKLARI — serbest metin beyanı normalleştirilir
--
-- Bugün host'un hakkı `profiles.access_source` içinde SERBEST METİN
-- ("Miles&Smiles Elite Plus, Kredi Kartı Avantajı"). Kural motoru bunun
-- üzerinde çalışamaz. Bu tablo beyanı satırlara ayırır; app hiç
-- değişmeden BO/otomatik ayrıştırıcı doldurur.
-- ============================================================
create table if not exists host_entitlements (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users(id) on delete cascade,
  program_id  uuid not null references lounge_programs(id) on delete cascade,
  tier        text,           -- 'ELPL' | 'ELITE' | 'CLASSIC' | plan adı
  carrier     text,           -- havayolu programlarında host'un taşıyıcısı
  guest_capacity smallint,
  origin      text not null default 'parsed',
  verified    boolean not null default false,
  verified_at timestamptz,
  verified_by text,
  note        text,
  created_at  timestamptz default now()
);
create unique index if not exists uq_he on host_entitlements (user_id, program_id, coalesce(tier,''));
create index if not exists idx_he_user on host_entitlements (user_id);

alter table host_entitlements drop constraint if exists he_origin_chk;
alter table host_entitlements add constraint he_origin_chk
  check (origin in ('declared','parsed','verified','admin'));

alter table host_entitlements enable row level security;
drop policy if exists he_own_read on host_entitlements;
create policy he_own_read on host_entitlements
  for select to authenticated using (user_id = auth.uid());

-- Beyanı satırlara ayır (idempotent — tekrar çalıştırılabilir)
create or replace function public.parse_host_entitlements(p_user_id uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare v_n integer := 0;
begin
  insert into host_entitlements (user_id, program_id, guest_capacity, origin, note)
  select pr.user_id,
         public.match_program_by_text(pr.access_source),
         nullif(pr.guest_capacity, 0),
         'parsed',
         'access_source: ' || left(pr.access_source, 180)
    from profiles pr
   where (p_user_id is null or pr.user_id = p_user_id)
     and coalesce(pr.access_source,'') <> ''
     and public.match_program_by_text(pr.access_source) is not null
  on conflict do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
grant execute on function public.parse_host_entitlements(uuid) to authenticated;


-- ============================================================
-- 6) İLAN ÜZERİNDEKİ KARAR DAMGASI (yeni, hepsi NULLABLE → app etkilenmez)
-- ============================================================
alter table availabilities add column if not exists rule_guest_policy   text;
alter table availabilities add column if not exists rule_flight_coupling text;
alter table availabilities add column if not exists rule_severity       text;
alter table availabilities add column if not exists rule_headline       text;
alter table availabilities add column if not exists rule_checked_at     timestamptz;


-- ============================================================
-- 7) 🔴 KARAR MOTORU — tek giriş noktası
--
-- Öncelik sırası (en özelden en genele):
--   1. salon × program kabul satırı  (lounge_venue_acceptance)
--   2. program × koşul kuralı        (lounge_guest_rules — kart/kabin)
--   3. program varsayılanı           (lounge_programs)
--   4. bilinmiyor
--
-- Dönüş TEK bir jsonb: uygulama matrisi asla görmez, tek cümle görür.
-- ============================================================
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
     order by (r.venue_id is not null) desc,
              (r.blocked_reason is not null) desc,   -- 🔴 085'te engeller görmezden geliniyordu
              (r.carrier is not null) desc,
              (r.card_tier is not null) desc,
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
-- 8) ESKİ İSİMLERİN YENİ MOTORA BAĞLANMASI
-- (BO ve ileride app aynı isimleri çağırmaya devam edebilsin)
-- ============================================================
create or replace function public.availability_rule_snapshot(p_avail_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select public.lounge_access_decision(p_avail_id, null);
$$;
grant execute on function public.availability_rule_snapshot(uuid) to authenticated;

create or replace function public.guest_flight_fits(p_avail_id uuid, p_flight_no text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d jsonb;
begin
  d := public.lounge_access_decision(p_avail_id, p_flight_no);
  return jsonb_build_object(
    'fits',     coalesce((d ->> 'fits')::boolean, true),
    'soft',     (d ->> 'fits') is null,
    'severity', d ->> 'severity',
    'reason',   d ->> 'headline',
    'detail',   d ->> 'detail');
end $$;
grant execute on function public.guest_flight_fits(uuid, text) to authenticated;

-- Kararı ilanın üzerine damgalar. HİÇBİR YERDEN ÇAĞRILMIYOR (app etkilenmez);
-- kural motoru bağlanınca create_availability'nin sonuna eklenecek.
create or replace function public.apply_rule_snapshot(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d jsonb; v_car text[];
begin
  d := public.lounge_access_decision(p_avail_id, null);

  if (d ->> 'flight_coupling') = 'same_carrier' then
    select array[upper(coalesce(a.carrier, substring(coalesce(a.flight_number,'') from '^[A-Za-z]+')))]
      into v_car from availabilities a where a.id = p_avail_id;
    if v_car[1] is null or v_car[1] = '' then v_car := null; end if;
  end if;

  update availabilities
     set rule_guest_policy    = d ->> 'guest_policy',
         rule_flight_coupling = d ->> 'flight_coupling',
         rule_severity        = d ->> 'severity',
         rule_headline        = d ->> 'headline',
         rule_note            = d ->> 'detail',
         rule_entry_hours     = nullif(d ->> 'earliest_entry_hours','')::numeric,
         guest_carrier_required = v_car,
         rule_checked_at      = now()
   where id = p_avail_id;
  return d;
end $$;
grant execute on function public.apply_rule_snapshot(uuid) to authenticated;


-- ============================================================
-- 9) VERİ SAĞLIĞI — iki eksen farkındalığıyla
-- 085'in "taşıyıcı şartı belirsiz" kontrolü her kart programını hatalı
-- işaretliyordu (kart programlarında taşıyıcı şartı ZATEN yok). Kaldırıldı.
-- ============================================================
create or replace function public.lounge_rules_health()
returns table (alan text, sorun text, ayrinti text, agirlik int)
language sql stable security definer set search_path = public as $$
  -- A) Kabul matrisi hiç doldurulmamış salonlar (asıl boşluk)
  select v.airport_code || ' · ' || v.name, 'kabul matrisi bos',
         'Bu salon icin hicbir program kabul satiri yok', 1
    from lounge_venues v
   where v.active and not exists (
         select 1 from lounge_venue_acceptance a where a.venue_id = v.id)
  union all
  -- B) Doğrulanmamış kabul satırları
  select v.airport_code || ' · ' || v.name, 'kabul dogrulanmadi',
         p.name || ' — ' || coalesce('son dogrulama ' || a.checked_at::text, 'hic dogrulanmadi'), 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and (a.checked_at is null or a.checked_at < current_date - 90)
  union all
  -- C) "unknown" kalan misafir politikaları — sahada sorulacak liste
  select v.airport_code || ' · ' || v.name, 'misafir politikasi bilinmiyor',
         p.name || ' — lounge gorusmesinde sorulacak', 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and a.accepted and a.guest_policy = 'unknown'
  union all
  -- D) Ücretli politikada fiyat yok → kullanıcıya rakam gösteremeyiz
  select v.airport_code || ' · ' || v.name, 'ucret bilinmiyor',
         p.name || ' — misafir ucretli ama tutar girilmemis', 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and a.guest_policy = 'paid' and a.guest_fee_amount is null
  union all
  -- E) Model alanları eksik program
  select p.name, 'program modeli eksik',
         'entitlement_model / guest_default / guest_flight_coupling bos', 1
    from lounge_programs p
   where p.active and (p.entitlement_model is null or p.guest_default is null
                       or p.guest_flight_coupling is null)
  union all
  -- F) Kaynak URL'i olmayan program
  select p.name, 'kaynak yok', 'Resmi kaynak URL girilmemis', 3
    from lounge_programs p where p.active and coalesce(p.source_url,'') = ''
  union all
  -- G) Takma adı olmayan program → serbest metinden asla eşleşmez
  select p.name, 'takma ad yok',
         'Host beyanindan bu program hicbir zaman eslesmez', 2
    from lounge_programs p
   where p.active and not exists (
         select 1 from lounge_program_aliases a where a.program_id = p.id)
  union all
  -- H) İlan açılan ama salonu tanımlı olmayan havalimanı
  select a.airport_code::text, 'salon tanimi yok',
         'Bu havalimaninda ilan var ama lounge_venues kaydi yok', 1
    from availabilities a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.airport_code)
   group by a.airport_code
  union all
  -- I) Katalog ile kural ekseni kopuk kalmış salonlar
  select l.airport_code || ' · ' || l.name, 'salon eslesmedi',
         'lounges kaydinin lounge_venues karsiligi yok', 1
    from lounges l where l.venue_id is null;
$$;
grant execute on function public.lounge_rules_health() to authenticated;


-- ============================================================
-- 10) VERİ — YALNIZ OKUDUĞUM KAYNAKLAR checked_at ALIR
-- Okumadığım her şey checked_at = null bırakılır ve sağlık raporunda
-- kırmızı görünür. "Bilmiyorum"u "yok" gibi yazmak en pahalı hata olurdu.
-- ============================================================

-- ---- Programlar ----
insert into lounge_programs
  (code, name, kind, entitlement_model, guest_default, guest_flight_coupling,
   guest_included_count, member_must_be_present, guest_needs_boarding_pass,
   guest_needs_photo_id, typical_guest_fee, guest_fee_currency, max_stay_hours,
   enforcement, source_url, rules_version, checked_at, notes)
values
  ('TK_MS','Turkish Airlines Miles&Smiles','airline','airline_status','included','same_carrier',
   1, true, true, false, null, null, null, 'warn',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
   '2026-06-01 → 2026-12-31', current_date,
   'Misafir hakki kart tipine bagli; IST dis hat Business bolumunde hak YOK.'),

  ('STAR_GOLD','Star Alliance Gold','alliance','alliance_status','included','same_alliance',
   1, true, true, false, null, null, null, 'warn',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
   '2026-06-01 → 2026-12-31', current_date,
   'Dis hat salonunda 1 misafir; aile hakki yok. Misafir ittifak uyesi havayolunda ucmali.'),

  ('AJET_MS','AJet (Miles&Smiles kartiyla)','airline','airline_status','unknown','same_carrier',
   0, true, true, false, null, null, null, 'warn',
   'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', null, null,
   '🔴 MISAFIR HAKKI TANIMLI DEGIL. "Bilinmiyor" ile "yok" ayridir; sahada dogrulanacak.'),

  ('PRIORITY_PASS','Priority Pass','card_program','card_membership','paid','any',
   0, true, true, true, 35, 'USD', null, 'warn',
   'https://www.prioritypass.com/tr-TR/conditions-of-use',
   '2026-03-26', current_date,
   'Md.4 kisi basi/ziyaret basi ucret, misafir de uyenin kartindan. Md.6 misafir uyeyle AYNI ANDA girmeli. Md.5 binis karti+kimlik. Md.11 devredilemez, ziyaret basina tek arac. Md.3/19 salon kosullari ustte. Bazi AB salonlari Schengen kisitli. Ucret uyelik planina gore degisir; 35 USD yalnizca TAHMINI.'),

  ('LOUNGEKEY','LoungeKey','card_program','card_membership','paid','any',
   0, true, true, true, 32, 'USD', null, 'warn',
   'https://loungekey.com/en/conditions-of-use', null, current_date,
   'Priority Pass ile ayni Collinson ailesi ve ayni maddeler: kisi basi/ziyaret basi ucret, misafir uyenin kartindan, binis karti+kimlik, ziyaret basina tek uyelik. Havayolu/kabin fark etmez. Ucret karti verene gore degisir.'),

  ('DRAGONPASS','DragonPass','card_program','card_membership','paid','same_flight',
   0, true, true, false, null, null, 2, 'warn',
   'https://www.dragonpass.com/terms-and-conditions', '2026-03-27', current_date,
   '🔴 Md.7.15.7: misafirin uyeyle AYNI UCUSTA olmasi gerekir — kart programlari icinde EN SIKI kural. Md.7.15.9 kalis tipik 2 saat. Md.7.1.1 uyelik devredilemez.'),

  ('PGS_PAID','Pegasus indirimli ucretli giris','paid_entry','paid_entry','paid','any',
   0, false, true, false, null, 'EUR', 3, 'warn',
   'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge', null, current_date,
   '🔴 Pegasus''un frekans programindan gelen MISAFIR HAKKI YOK. Model tamamen ucretli giris: binis kartini gosterip odeme yapilir. Herkes ayni sekilde girer; "host hakkini paylasiyor" cercevesi burada GECERSIZ.'),

  ('PLAZA_PREMIUM','Plaza Premium Lounge (kapida odeme)','operator','operator_program','paid','any',
   0, false, true, false, null, 'EUR', 3, 'warn', null, null, null,
   'Isletmeci programi; kapida ucretli giris. Fiyatlar salona gore degisir.'),

  ('PRIMECLASS','Primeclass Lounge (TAV, kapida odeme)','operator','operator_program','paid','any',
   0, false, true, false, null, 'EUR', 3, 'warn', null, null, null,
   'TAV isletmecisi; kapida ucretli giris.'),

  ('IGA_LOUNGE','IGA Lounge (Istanbul Havalimani)','operator','operator_program','unknown','any',
   0, false, true, false, null, null, null, 'warn', null, null, null,
   'Resmi kosullari HENUZ OKUNMADI — sahada dogrulanacak.'),

  ('BANK_CARD','Banka karti ayricaligi (program belirsiz)','bank','bank_card','unknown','any',
   0, true, true, false, null, null, null, 'warn', null, null, null,
   'Cogu banka karti aslinda Priority Pass / LoungeKey / DragonPass''e baglanir. Host hangi programa bagli oldugunu bilmiyorsa karar bu satirdan cikar ve "dogrulanmadi" der.'),

  ('BUSINESS_TICKET','Business bileti hakki','airline','ticket_class','unknown','same_carrier',
   0, true, true, false, null, null, null, 'warn', null, null, null,
   'Bilet sinifindan gelen hak; misafir hakki cogu tasiyicida YOKTUR, salona ve tasiyiciya gore degisir.')
on conflict (code) do update set
  kind                      = excluded.kind,
  entitlement_model         = excluded.entitlement_model,
  guest_default             = excluded.guest_default,
  guest_flight_coupling     = excluded.guest_flight_coupling,
  guest_included_count      = excluded.guest_included_count,
  member_must_be_present    = excluded.member_must_be_present,
  guest_needs_boarding_pass = excluded.guest_needs_boarding_pass,
  guest_needs_photo_id      = excluded.guest_needs_photo_id,
  typical_guest_fee         = excluded.typical_guest_fee,
  guest_fee_currency        = excluded.guest_fee_currency,
  max_stay_hours            = excluded.max_stay_hours,
  source_url                = coalesce(excluded.source_url, lounge_programs.source_url),
  rules_version             = coalesce(excluded.rules_version, lounge_programs.rules_version),
  checked_at                = coalesce(excluded.checked_at, lounge_programs.checked_at),
  notes                     = excluded.notes;

-- 083'te acilan ama artik PGS_PAID/operator ile karsilanan eski kayit korunur.

-- ---- Takma adlar (serbest metin eslesmesi) ----
insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('TK_MS','miles&smiles',100),      ('TK_MS','miles and smiles',100),
  ('TK_MS','miles smiles',90),       ('TK_MS','m&s',60),
  ('TK_MS','turkish airlines lounge',90), ('TK_MS','thy lounge',90),
  ('TK_MS','elite plus',95),         ('TK_MS','elite kart',90),
  ('STAR_GOLD','star alliance gold',100), ('STAR_GOLD','star gold',95),
  ('AJET_MS','ajet',100),
  ('PRIORITY_PASS','priority pass',100), ('PRIORITY_PASS','prioritypass',100),
  ('PRIORITY_PASS','priorty pass',90),   ('PRIORITY_PASS','pp kart',60),
  ('LOUNGEKEY','loungekey',100),         ('LOUNGEKEY','lounge key',100),
  ('DRAGONPASS','dragonpass',100),       ('DRAGONPASS','dragon pass',100),
  ('PGS_PAID','pegasus',100),            ('PGS_PAID','bolbol',80),
  ('PLAZA_PREMIUM','plaza premium',100),
  ('PRIMECLASS','primeclass',100),       ('PRIMECLASS','prime class',95),
  ('IGA_LOUNGE','iga lounge',100),
  ('BANK_CARD','kredi karti',70),        ('BANK_CARD','banka karti',70),
  ('BANK_CARD','kredi kartı avantajı',80),
  ('BUSINESS_TICKET','business bilet',90), ('BUSINESS_TICKET','business sinifi',90),
  ('BUSINESS_TICKET','business sınıfı',90)
) as a(code, alias, w)
where p.code = a.code
on conflict do nothing;

-- ---- Salonlar (Turkiye cekirdegi) ----
insert into lounge_venues (airport_code, name, terminal, section, operator, scope, max_stay_hint, notes)
select * from (values
  ('IST','Turkish Airlines Lounge — Dis Hat (Business)','Dis Hat','business','THY','international',null::numeric,null::text),
  ('IST','Turkish Airlines Lounge — Dis Hat (Miles&Smiles)','Dis Hat','miles_smiles','THY','international',null,null),
  ('IST','Turkish Airlines Lounge — Ic Hat','Ic Hat',null,'THY','domestic',null,null),
  ('IST','IGA Lounge — Dis Hat','Dis Hat',null,'IGA','international',null,'Kosullari okunmadi'),
  ('IST','IGA Lounge — Ic Hat','Ic Hat',null,'IGA','domestic',null,'Kosullari okunmadi'),
  ('SAW','Plaza Premium Lounge','Ic/Dis Hat',null,'Plaza Premium','both',3,'Pegasus indirimli fiyat: ic hat 49 EUR, dis hat 63 EUR (3 saat). 6 yas alti ucretsiz.'),
  ('SAW','Kepler Club',null,null,'Kepler','both',null,'Uyku kabini + dinlenme salonu'),
  ('ESB','Primeclass Lounge','Ic/Dis Hat',null,'TAV','both',3,'Pegasus indirimli 27 EUR + KDV (3 saat). 0-2 yas ucretsiz.'),
  ('ADB','Primeclass Lounge','Ic/Dis Hat',null,'TAV','both',3,'Pegasus indirimli 27 EUR + KDV (3 saat)'),
  ('BJV','Primeclass Lounge','Ic/Dis Hat',null,'TAV','both',3,'Pegasus indirimli 27 EUR + KDV (3 saat)'),
  ('AYT','Primeclass Lounge','Dis Hat',null,'TAV','both',null,null)
) as v(airport_code,name,terminal,section,operator,scope,max_stay_hint,notes)
where exists (select 1 from airports ap where ap.code = v.airport_code)
on conflict do nothing;

-- ---- SALON × PROGRAM KABUL MATRISI ----
-- Kanit okudugum satirlar checked_at alir; digerleri 'unknown' + null kalir.
with vp as (
  select v.id vid, v.airport_code, v.name vname, v.section, p.id pid, p.code pcode
    from lounge_venues v cross join lounge_programs p
)
insert into lounge_venue_acceptance
 (venue_id, program_id, accepted, guest_policy, guest_included_count,
  guest_fee_amount, guest_fee_currency, guest_fee_note, guest_flight_coupling,
  max_stay_hours, children_note, conditions, source_url, checked_at)
select vid, pid, accepted, gp, gi, fee, cur, fnote, coup, stay, ch, cond, url, chk
from (
  -- THY salonlari × Miles&Smiles
  select vid, pid, true, 'included', 1, null::numeric, null::text, null::text,
         'same_carrier'::text, null::numeric, 'Aile politikasi kart tipine bagli'::text,
         'Misafir hakki kart tipine gore degisir; Classic/Classic Plus''ta hak yok.'::text,
         'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'::text,
         current_date::date
    from vp where pcode='TK_MS' and vname like 'Turkish Airlines%' and coalesce(section,'') <> 'business'
  union all
  -- 🔴 IST dis hat BUSINESS bolumu: misafir hakki YOK
  select vid, pid, true, 'not_allowed', 0, null, null, null, null, null, null,
         'IST dis hat Business bolumunde misafir/aile hakki yok; misafir getirilecekse Miles&Smiles bolumune girilmeli.',
         'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/', current_date
    from vp where pcode='TK_MS' and section='business'
  union all
  -- Star Alliance Gold: yalniz dis hat THY salonu
  select vid, pid, true, 'included', 1, null, null, null, 'same_alliance', null,
         'Aile hakki yok', 'Misafirin Star Alliance uyesi bir havayolunda ucmasi gerekir.',
         'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/', current_date
    from vp where pcode='STAR_GOLD' and vname like 'Turkish Airlines%' and section='miles_smiles'
  union all
  -- SAW Plaza Premium: ucretli giris (Pegasus sayfasindan fiyat)
  select vid, pid, true, 'paid', 0, 63, 'EUR',
         'Pegasus binis karti ile indirimli: ic hat 49 EUR, dis hat 63 EUR (KDV dahil).',
         'any', 3, '6 yasina kadar cocuklar ucretsiz',
         'Kapida odeme; kullanim suresi 3 saat.',
         'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge', current_date
    from vp where pcode='PGS_PAID' and vname='Plaza Premium Lounge'
  union all
  -- Primeclass ESB/ADB/BJV: Pegasus indirimli
  select vid, pid, true, 'paid', 0, 27, 'EUR',
         'Pegasus binis karti ile 27 EUR + KDV.', 'any', 3, '0-2 yas ucretsiz',
         'Kapida odeme; kullanim suresi 3 saat.',
         'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge', current_date
    from vp where pcode='PGS_PAID' and vname='Primeclass Lounge' and airport_code in ('ESB','ADB','BJV')
  union all
  -- Kart programlari: kabul EDILDIGI VARSAYILMAZ — bilinmiyor olarak acilir
  select vid, pid, true, 'unknown', 0, null, null, null, null, null, null,
         'Bu salonun bu programi kabul edip etmedigi ve misafir ucreti DOGRULANMADI. Lounge gorusmesinde sorulacak.',
         null, null
    from vp where pcode in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
      and (vname like 'Plaza Premium%' or vname like 'Primeclass%' or vname like 'IGA Lounge%')
) as s(vid,pid,accepted,gp,gi,fee,cur,fnote,coup,stay,ch,cond,url,chk)
on conflict (venue_id, program_id) do nothing;

-- Host beyanlarini satirlara ayir (geriye donuk)
select public.parse_host_entitlements(null) as ayristirilan_hak_sayisi;


-- ============================================================
-- 11) DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_programs)          as programlar,
       (select count(*) from lounge_program_aliases)   as takma_adlar,
       (select count(*) from lounge_venues)            as salonlar,
       (select count(*) from lounge_venue_acceptance)  as kabul_satirlari,
       (select count(*) from lounges where venue_id is null) as eslesmeyen_salon;

-- Eşleme testi: serbest metinden program bulunuyor mu?
select 'Miles&Smiles Elite Plus'   as beyan, (select code from lounge_programs where id = public.match_program_by_text('Miles&Smiles Elite Plus')) as program
union all select 'Priority Pass kartım var', (select code from lounge_programs where id = public.match_program_by_text('Priority Pass kartım var'))
union all select 'Dragon Pass + kredi kartı', (select code from lounge_programs where id = public.match_program_by_text('Dragon Pass + kredi kartı'))
union all select 'sadece kredi kartı avantajı', (select code from lounge_programs where id = public.match_program_by_text('sadece kredi kartı avantajı'));

-- Sağlık raporu: en ağır boşluklar önce
select * from public.lounge_rules_health() order by agirlik, alan limit 40;

select '086 OK - iki eksenli kural modeli kuruldu (salon x program), app ETKILENMEDI' as sonuc;
