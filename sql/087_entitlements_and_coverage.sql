-- ============================================================
-- LoungeLink · 087_entitlements_and_coverage.sql
-- KART/BANKA KATMANI · TÜKENEN KOTA MODELİ · SAHA GERİ BİLDİRİM DÖNGÜSÜ
--
-- ⚠️ UYGULAMAYI ETKİLEMEZ. Yeni tablolar + nullable kolonlar + app'in
-- çağırmadığı fonksiyonlar. (087a_PRE_drop 086'nın karar fonksiyonunu düşürür.)
--
-- ------------------------------------------------------------
-- NEDEN: 086 iki ekseni kurdu (program × salon). Kredi kartı tarafına
-- bakınca ÜÇÜNCÜ bir eksenin tamamen eksik olduğu ortaya çıktı.
-- ------------------------------------------------------------
--
-- 🔴 BULGU 1 — MİSAFİR HAKKI BİR SAYI DEĞİL, TÜKENEN BİR KOTADIR.
--   · QNB Private: yılda 15 kullanım; **misafirin girişleri de aynı 15'ten
--     düşüyor**; 15 aşılırsa kişi başı 35 USD.
--   · TEB Infinite (LoungeKey): ayda en fazla 4 karekod, bunun **en fazla
--     2'si misafir için**; yıl sonunda kullanılmayan aktif karekodlar
--     ertesi yılın hakkından düşüyor.
--   · Wings Elite (Akbank×Pegasus): yılda 8 giriş, her seferinde 2 kişi.
--   · Yapı Kredi Crystal: ayda 2 → yılda 24.
--   Bizim modelimiz "guest_included_count = 1" diyordu ve bu SONSUZA KADAR
--   doğru sayılıyordu. Kotası bitmiş bir host misafir kabul ederse, misafir
--   kapıda 35 USD faturayla karşılaşır. Güveni bir kerede bitiren olay tam
--   olarak budur ve bizim hatamız olur.
--
-- 🔴 BULGU 2 — BAZI PROGRAMLAR MİSAFİRİN **RESMİ ADINI ÖNCEDEN** İSTİYOR.
--   TEB: karekod misafirin ad/soyadıyla ÖNCEDEN oluşturuluyor ve
--   "oluşturulan karekoda ait ad/soyad bilgisi DEĞİŞTİRİLEMEZ".
--   Bunun akışa üç etkisi var ve üçü de bugün üründe YOK:
--     (a) Kabul anında host'un misafirin tam adını öğrenmesi gerekir —
--         oysa uygulama her yerde "Elif K." diye maskeliyor.
--     (b) Geç iptal bu host için kartından hak YAKAR; iptal cezası
--         diğerleriyle aynı olamaz.
--     (c) Misafir değişikliği imkânsız — slot devri yapılamaz.
--
-- 🔴 BULGU 3 — "KREDİ KARTI AVANTAJI" HİÇBİR ZAMAN BAŞLI BAŞINA PROGRAM
--   DEĞİLDİR. Her zaman altında Priority Pass / LoungeKey / DragonPass ya
--   da bankanın kendi ağı vardır. Uygulamanın "Lounge Erişim Kurulumu"
--   ekranında "Kredi Kartı Avantajı" ve "Banka / Özel Bankacılık" tek başına
--   seçenek olarak duruyor → kural motoru bu host için ASLA doğru karar
--   veremez. Araya KART ÜRÜNÜ katmanı gerekiyor.
--
-- 🔴 BULGU 4 — KURALINI BİLMEDİĞİMİZ SAĞLAYICI HEP OLACAK.
--   Türkiye'de bile onlarca kart ürünü, Turkcell Platinum gibi telko
--   programları, bankaların kendi salonları var. "Bilmiyorsak engelleriz"
--   ürünü öldürür; "bilmiyorsak susarız" kullanıcıyı kapıda yalnız bırakır.
--   ÜÇÜNCÜ YOL: bilmediğimizi AÇIKÇA söyleyip akışı sürdürmek + her
--   tamamlanan oturumdan tek soruyla veri toplamak (§5).
-- ============================================================


-- ============================================================
-- 1) İHRAÇÇI KATMANI — banka / telko / havayolu
-- ============================================================
create table if not exists lounge_issuers (
  id       uuid primary key default uuid_generate_v4(),
  code     text not null unique,
  name     text not null,
  kind     text not null default 'bank',
  country  text default 'TR',
  active   boolean not null default true,
  created_at timestamptz default now()
);
-- ============================================================
-- ONCEDEN DUSURME (eski 087a_PRE_drop.sql icerigi) — v2
--
-- 🔴 NEDEN ARTIK BU DOSYANIN ICINDE:
-- Bu adim ayri bir dosyadaydi (087a_PRE_drop.sql) ve ATLANDI:
--   ERROR 42P13: cannot change return type of existing function
--   HINT: Use DROP FUNCTION lounge_rules_health() first.
-- Ayri dosya olmasinin teknik bir gerekcesi yoktu, yalnizca
-- aliskanliktir. Atlanabilen bir on kosul, on kosul degildir —
-- migration kendi on kosulunu kendisi saglamali.
--
-- `drop function if exists` GUVENLIDIR: fonksiyon yoksa hicbir sey
-- yapmaz. Bu dosya bastan sona TEKRAR calistirilabilir.
-- ============================================================
drop function if exists public.entitlement_health();
drop function if exists public.lounge_access_decision_v2(uuid, text);
drop function if exists public.entitlement_remaining(uuid);
drop function if exists public.pending_field_report(uuid);

alter table lounge_issuers drop constraint if exists li_kind_chk;
alter table lounge_issuers add constraint li_kind_chk
  check (kind in ('bank','telco','airline','fintech','other'));

alter table lounge_issuers enable row level security;
drop policy if exists li_read on lounge_issuers;
create policy li_read on lounge_issuers for select to authenticated using (active);


-- ============================================================
-- 2) KART ÜRÜNÜ KATALOĞU — "Kredi Kartı Avantajı"nın altını doldurur
--
-- Host artık "kredi kartım var" demekle kalmaz; HANGİ KART olduğunu seçer,
-- biz de o kartın hangi programa bağlandığını, kaç hakkı olduğunu ve
-- misafirin kotadan düşüp düşmediğini BİLİRİZ.
-- ============================================================
create table if not exists lounge_card_products (
  id            uuid primary key default uuid_generate_v4(),
  issuer_id     uuid not null references lounge_issuers(id) on delete cascade,
  name          text not null,                     -- 'Infinite', 'Private', 'Crystal'
  program_id    uuid references lounge_programs(id), -- altında yatan ağ
  extra_program_ids uuid[],                        -- QNB gibi ikinci ağı olanlar

  -- KOTA
  quota_total   smallint,                          -- 15 · 8 · 24 · 4
  quota_period  text,                              -- 'year' | 'month' | 'unlimited'
  -- 🔴 QNB: misafirin girişi de aynı kotadan düşer. TK M&S: düşmez.
  guest_consumes_quota boolean not null default true,
  guest_quota_cap smallint,                        -- TEB: aylık 4'ün en fazla 2'si misafir
  guest_fee_after_quota numeric,                   -- QNB: 35
  guest_fee_currency text,

  -- ÖNCEDEN ÜRETİLEN GEÇİŞ (TEB karekod modeli)
  requires_preissued_pass     boolean not null default false,
  pass_needs_guest_legal_name boolean not null default false,
  pass_change_allowed         boolean not null default true,

  conditions  text,
  source_url  text,
  checked_at  date,
  active      boolean not null default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create unique index if not exists uq_lcp on lounge_card_products (issuer_id, lower(name));
create index if not exists idx_lcp_program on lounge_card_products (program_id);

alter table lounge_card_products drop constraint if exists lcp_period_chk;
alter table lounge_card_products add constraint lcp_period_chk
  check (quota_period is null or quota_period in ('year','month','unlimited'));
-- Mantık kilidi: adı değiştirilemeyen bir geçiş, önceden üretiliyor demektir
alter table lounge_card_products drop constraint if exists lcp_pass_chk;
alter table lounge_card_products add constraint lcp_pass_chk
  check (pass_change_allowed or requires_preissued_pass);

alter table lounge_card_products enable row level security;
drop policy if exists lcp_read on lounge_card_products;
create policy lcp_read on lounge_card_products for select to authenticated using (active);


-- ============================================================
-- 3) HOST'UN HAKKINA KOTA DURUMU EKLENİR
-- ============================================================
alter table host_entitlements add column if not exists card_product_id   uuid references lounge_card_products(id);
alter table host_entitlements add column if not exists quota_total       smallint;
alter table host_entitlements add column if not exists quota_period      text;
alter table host_entitlements add column if not exists quota_used        smallint not null default 0;
alter table host_entitlements add column if not exists quota_period_start date;
alter table host_entitlements add column if not exists self_reported_at  timestamptz;

alter table host_entitlements drop constraint if exists he_quota_period_chk;
alter table host_entitlements add constraint he_quota_period_chk
  check (quota_period is null or quota_period in ('year','month','unlimited'));
alter table host_entitlements drop constraint if exists he_quota_used_chk;
alter table host_entitlements add constraint he_quota_used_chk check (quota_used >= 0);

-- Kalan hak. Beyana dayalıdır — doğrulanamaz, ama GÖRÜNÜR olması bile
-- host'un "bu ay hakkım bitti" demesini sağlar. Bugün soracak yer yok.
create or replace function public.entitlement_remaining(p_entitlement_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e host_entitlements%rowtype; v_start date; v_left int;
begin
  select * into e from host_entitlements where id = p_entitlement_id;
  if not found or e.quota_total is null or e.quota_period = 'unlimited' then
    return jsonb_build_object('known', false, 'unlimited', e.quota_period = 'unlimited');
  end if;
  v_start := coalesce(e.quota_period_start,
                      case when e.quota_period = 'month' then date_trunc('month', current_date)::date
                           else date_trunc('year', current_date)::date end);
  -- Dönem devrettiyse sayaç mantıken sıfırlanmış sayılır (yazmıyoruz, okuyoruz)
  if (e.quota_period = 'month' and v_start < date_trunc('month', current_date)::date)
     or (e.quota_period = 'year' and v_start < date_trunc('year', current_date)::date) then
    v_left := e.quota_total;
  else
    v_left := greatest(e.quota_total - e.quota_used, 0);
  end if;
  return jsonb_build_object(
    'known', true, 'unlimited', false,
    'total', e.quota_total, 'used', e.quota_used, 'left', v_left,
    'period', e.quota_period, 'period_start', v_start,
    'stale', e.self_reported_at is null or e.self_reported_at < now() - interval '60 days');
end $$;
grant execute on function public.entitlement_remaining(uuid) to authenticated;


-- ============================================================
-- 4) KAPSAMA GÜVENİ — "biliyoruz" ile "varsayıyoruz" ayrılır
-- ============================================================
alter table lounge_programs        add column if not exists coverage_status text;
alter table lounge_venue_acceptance add column if not exists field_reports_ok  smallint not null default 0;
alter table lounge_venue_acceptance add column if not exists field_reports_bad smallint not null default 0;

alter table lounge_programs drop constraint if exists lp_coverage_chk;
alter table lounge_programs add constraint lp_coverage_chk
  check (coverage_status is null or coverage_status in ('verified','partial','unknown'));

-- Bilinmeyen durumda kullanıcıya gösterilecek GENEL uyarı metni.
-- Kodda sabit değil, BO'dan değiştirilebilsin diye ayarlarda duruyor.
insert into beta_settings (key, value)
values ('lounge_generic_notice', to_jsonb(
  'Bu salonun misafir kurallarını henüz doğrulamadık. Girişte host''un yanında olman, '
  'kendi biniş kartın ve kimliğinle gitmen gerekiyor; misafir girişi ücretli olabilir. '
  'Buluşmadan önce host''a hakkının misafir kapsayıp kapsamadığını sor.'::text))
on conflict (key) do nothing;


-- ============================================================
-- 5) 🔴 SAHA GERİ BİLDİRİM DÖNGÜSÜ — kural verisi kendi kendini onarır
--
-- Bugün "bilinmiyor" hücrelerini kapatmanın tek yolu Gokberk'in tek tek
-- lounge görüşmesi yapması. Oysa her tamamlanan oturum zaten kapıda ne
-- olduğunu BİLEN iki kişi üretiyor. Oturum sonunda TEK SORU sorulursa
-- kapsama verisi ürünün kendi kullanımıyla büyür.
--
--   "Kapıda sorun yaşadınız mı?"
--     ✅ Sorunsuz girdik, ücret alınmadı
--     💳 Girdik ama misafir ücret ödedi  → tutar?
--     ⛔ Misafir içeri alınmadı          → sebep?
--
-- Bu aynı zamanda bir DOLANDIRICILIK sinyali: "girdik" diyen ama hiç
-- girmemiş oturumlar burada ayrışır.
-- ============================================================
create table if not exists lounge_field_reports (
  id          uuid primary key default uuid_generate_v4(),
  reporter_id uuid not null references users(id) on delete cascade,
  session_id  uuid references sessions(id) on delete set null,
  venue_id    uuid references lounge_venues(id) on delete set null,
  program_id  uuid references lounge_programs(id) on delete set null,
  outcome     text not null,
  fee_paid    numeric,
  fee_currency text,
  note        text,
  reviewed    boolean not null default false,
  reviewed_by text,
  created_at  timestamptz default now()
);
alter table lounge_field_reports drop constraint if exists lfr_outcome_chk;
alter table lounge_field_reports add constraint lfr_outcome_chk
  check (outcome in ('admitted_free','admitted_paid','refused','not_attempted'));
create index if not exists idx_lfr_venue on lounge_field_reports (venue_id, program_id);
-- Oturum başına tek rapor (aynı kişiden)
create unique index if not exists uq_lfr_session on lounge_field_reports (session_id, reporter_id)
  where session_id is not null;

alter table lounge_field_reports enable row level security;
drop policy if exists lfr_own on lounge_field_reports;
create policy lfr_own on lounge_field_reports
  for select to authenticated using (reporter_id = auth.uid());
drop policy if exists lfr_insert on lounge_field_reports;
create policy lfr_insert on lounge_field_reports
  for insert to authenticated with check (reporter_id = auth.uid());

-- Rapor geldikçe kabul satırının sayaçlarını günceller.
-- 🔴 KURALI OTOMATİK DEĞİŞTİRMEZ. Sayaçları büyütür, insan karar verir.
-- Otomatik değiştirseydi tek bir yanlış/kötü niyetli rapor kuralı bozardı.
create or replace function public.trg_field_report_rollup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.venue_id is null or new.program_id is null then return new; end if;
  update lounge_venue_acceptance
     set field_reports_ok  = field_reports_ok  + (case when new.outcome = 'admitted_free' then 1 else 0 end),
         field_reports_bad = field_reports_bad + (case when new.outcome in ('admitted_paid','refused') then 1 else 0 end),
         updated_at = now()
   where venue_id = new.venue_id and program_id = new.program_id;
  return new;
end $$;
drop trigger if exists trg_lfr_rollup on lounge_field_reports;
create trigger trg_lfr_rollup after insert on lounge_field_reports
  for each row execute function public.trg_field_report_rollup();

-- Oturum bittikten sonra soru sorulacak mı? (app ileride buna bakacak)
create or replace function public.pending_field_report(p_user_id uuid default null)
returns table (session_id uuid, venue_id uuid, program_id uuid, venue_name text, lounge_date date)
language sql stable security definer set search_path = public as $$
  select s.id, public.resolve_venue_for_availability(a.id), a.program_id, v.name, a.avail_date
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
    left join lounge_venues v on v.id = public.resolve_venue_for_availability(a.id)
   where s.status = 'completed'
     and s.completed_at > now() - interval '7 days'   -- sessions'ta updated_at YOK (sema teyit edildi)
     and (r.guest_id = coalesce(p_user_id, auth.uid()) or r.host_id = coalesce(p_user_id, auth.uid()))
     and not exists (select 1 from lounge_field_reports f
                      where f.session_id = s.id
                        and f.reporter_id = coalesce(p_user_id, auth.uid()));
$$;
grant execute on function public.pending_field_report(uuid) to authenticated;


-- ============================================================
-- 6) KARAR MOTORU v3.1 — güven derecesi + kota + kimlik şartı
-- 086'nın lounge_access_decision'ı korunur, üstüne üç şey eklenir.
-- ============================================================
create or replace function public.lounge_access_decision_v2(
  p_avail_id     uuid,
  p_guest_flight text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d          jsonb;
  v_av       availabilities%rowtype;
  v_ent      host_entitlements%rowtype;
  v_card     lounge_card_products%rowtype;
  v_acc      lounge_venue_acceptance%rowtype;
  v_venue_id uuid;
  v_quota    jsonb;
  v_conf     text := 'unknown';
  v_extra    text[] := '{}';
  v_sev      text;
begin
  d := public.lounge_access_decision(p_avail_id, p_guest_flight);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;
  v_venue_id := public.resolve_venue_for_availability(p_avail_id);
  v_sev := d ->> 'severity';

  -- ---- GÜVEN DERECESİ ----------------------------------------------
  if v_venue_id is not null then
    select * into v_acc from lounge_venue_acceptance
     where venue_id = v_venue_id and program_id = (d ->> 'program_id')::uuid;
  end if;
  if (d ->> 'known')::boolean is not true then
    v_conf := 'unknown';
  elsif (d ->> 'checked_at') is not null and (d ->> 'checked_at')::date >= current_date - 90 then
    v_conf := 'verified';
  elsif coalesce(v_acc.field_reports_ok, 0) + coalesce(v_acc.field_reports_bad, 0) >= 3 then
    v_conf := 'reported';        -- sahadan geldi, resmî kaynaktan değil
  elsif (d ->> 'guest_policy') = 'unknown' then
    v_conf := 'unknown';
  else
    v_conf := 'assumed';         -- program varsayılanından türetildi
  end if;

  -- ---- HOST'UN KOTASI ----------------------------------------------
  select he.* into v_ent
    from host_entitlements he
   where he.user_id = v_av.host_id
     and (he.program_id = (d ->> 'program_id')::uuid or (d ->> 'program_id') is null)
   order by he.verified desc, he.created_at
   limit 1;

  if v_ent.id is not null then
    v_quota := public.entitlement_remaining(v_ent.id);
    if v_ent.card_product_id is not null then
      select * into v_card from lounge_card_products where id = v_ent.card_product_id;
    end if;

    if (v_quota ->> 'known')::boolean and (v_quota ->> 'left')::int = 0 then
      -- 🔴 Kotası bitmiş host: misafir kapıda ücret öder. Engel DEĞİL,
      -- ama misafire söylenmeden istek gönderilmemeli.
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
      v_extra := v_extra || format(
        'Host''un bu dönemdeki ücretsiz giriş hakkı tükenmiş görünüyor (%s/%s). Misafir girişi ücretli olabilir.',
        (v_quota ->> 'used'), (v_quota ->> 'total'));
    elsif (v_quota ->> 'known')::boolean and (v_quota ->> 'left')::int <= 2 then
      v_extra := v_extra || format('Host''un kalan ücretsiz giriş hakkı: %s.', (v_quota ->> 'left'));
    end if;

    if (v_quota ->> 'stale')::boolean then
      v_extra := v_extra || ('Bu hak bilgisi host''un beyanı ve bir süredir güncellenmedi.')::text;
    end if;

    if coalesce(v_card.guest_consumes_quota, false) then
      v_extra := v_extra || ('Bu kartta misafirin girişi de host''un kendi hakkından düşüyor.')::text;
    end if;

    -- ---- ÖNCEDEN ÜRETİLEN GEÇİŞ (TEB karekod modeli) ----------------
    if coalesce(v_card.requires_preissued_pass, false) then
      v_extra := v_extra || ('Host girişi ÖNCEDEN oluşturmak zorunda.')::text;
      if coalesce(v_card.pass_needs_guest_legal_name, false) then
        v_extra := v_extra || ('Bunun için misafirin ad-soyadını kabul aşamasında host''la paylaşması gerekiyor.')::text;
      end if;
      if not coalesce(v_card.pass_change_allowed, true) then
        v_extra := v_extra || ('Oluşturulan geçiş DEĞİŞTİRİLEMİYOR: geç iptal host''un hakkını yakar.')::text;
      end if;
    end if;
  end if;

  -- ---- BİLİNMEYEN DURUM: SUSMA, SÖYLE ------------------------------
  if v_conf = 'unknown' then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || coalesce(
      (select value #>> '{}' from beta_settings where key = 'lounge_generic_notice'),
      'Bu salonun misafir kurallarını henüz doğrulamadık; koşulları kapıda teyit edin.');
  end if;

  return d
    || jsonb_build_object(
         'confidence', v_conf,
         'severity',   v_sev,
         'quota',      v_quota,
         'card_product', v_card.name,
         'requires_preissued_pass', coalesce(v_card.requires_preissued_pass, false),
         'needs_guest_legal_name',  coalesce(v_card.pass_needs_guest_legal_name, false),
         'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra, ' ')));
end $$;
grant execute on function public.lounge_access_decision_v2(uuid, text) to authenticated;


-- ============================================================
-- 7) VERİ — Türkiye kart ürünleri
-- ⚠️ HEPSİ İKİNCİL KAYNAKTAN. checked_at BİLEREK NULL bırakıldı:
-- banka kampanya koşulları sık değişiyor ve bunlar resmî sayfadan
-- tek tek doğrulanana kadar "doğrulanmış" sayılmamalı. BO sağlık
-- raporu bunları kırmızı gösterecek — doğru davranış budur.
-- ============================================================
insert into lounge_issuers (code, name, kind) values
  ('TEB','Türk Ekonomi Bankası','bank'),
  ('QNB','QNB Türkiye','bank'),
  ('AKBANK','Akbank','bank'),
  ('YKB','Yapı Kredi','bank'),
  ('DENIZ','DenizBank','bank'),
  ('GARANTI','Garanti BBVA','bank'),
  ('ISBANK','Türkiye İş Bankası','bank'),
  ('AMEX','American Express','fintech'),
  ('TURKCELL','Turkcell','telco')
on conflict (code) do nothing;

insert into lounge_card_products
  (issuer_id, name, program_id, quota_total, quota_period,
   guest_consumes_quota, guest_quota_cap, guest_fee_after_quota, guest_fee_currency,
   requires_preissued_pass, pass_needs_guest_legal_name, pass_change_allowed,
   conditions, source_url, checked_at)
select i.id, c.name,
       (select p.id from lounge_programs p where p.code = c.pcode),
       c.qt, c.qp, c.gcq, c.gcap, c.fee, c.cur, c.pre, c.legal, c.chg, c.cond, c.url, null
  from lounge_issuers i
  join (values
    ('TEB','Infinite','LOUNGEKEY', 4::smallint,'month', true, 2::smallint, null::numeric, null::text,
     true, true, false,
     'Aylik en fazla 4 karekod, en fazla 2''si misafir icin. Karekod misafirin ad/soyadiyla ONCEDEN olusturulur ve DEGISTIRILEMEZ. Kullanilmayan aktif karekodlar sonraki yilin hakkindan duser.',
     'https://www.teb.com.tr/kart-dunyasi-ucretsiz-lounge-hizmeti/'),

    ('QNB','Private','LOUNGEKEY', 15,'year', true, null, 35, 'USD',
     false, false, true,
     'Yilda 15 kullanim; MISAFIRIN girisleri de ayni 15''ten duser. 15 asilirsa kisi basi 35 USD. Her gecis icin 1 USD gecici bloke. IGA Lounge erisimi de var.',
     'https://www.qnb.com.tr/private/private-ayricaliklar/private-seyahat/lounge-ayricaliklari'),

    ('AKBANK','Wings Elite','PRIORITY_PASS', 8,'year', false, null, null, null,
     false, false, true,
     'Yilda 8 giris, her seferinde 2 kisi (misafir dahil). Pegasus is birligi.', null),

    ('YKB','Crystal','PRIORITY_PASS', 24,'year', true, null, null, null,
     false, false, true,
     'Ayda 2 kullanim (yilda 24''e kadar). Misafir kosullari DOGRULANMADI.', null),

    ('DENIZ','Black','PRIORITY_PASS', null, null, true, null, null, null,
     false, false, true,
     'Lounge erisimi var; kullanim adedi/misafir hakki/ucretlendirme karta ve kampanya donemine gore DEGISIYOR. Bankadan teyit sart.', null),

    ('AMEX','Platinum','PRIORITY_PASS', null,'unlimited', true, null, null, null,
     false, false, true,
     'Centurion Lounge agi + Priority Pass. Misafir kosullari kart surumune gore degisir.', null),

    ('TURKCELL','Platinum','BANK_CARD', null, null, true, null, null, null,
     false, false, true,
     'Kart degil telko programi; anlasmali lounge''larda INDIRIM saglar, ucretsiz giris DEGIL.', null)
  ) as c(icode, name, pcode, qt, qp, gcq, gcap, fee, cur, pre, legal, chg, cond, url)
    on c.icode = i.code
on conflict do nothing;

-- Kart ürünü olan programlar için takma ad genişletmesi
insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('LOUNGEKEY','teb infinite',95), ('LOUNGEKEY','qnb private',95),
  ('PRIORITY_PASS','wings elite',95), ('PRIORITY_PASS','amex platinum',95),
  ('PRIORITY_PASS','american express',85), ('PRIORITY_PASS','crystal kart',80),
  ('BANK_CARD','turkcell platinum',90), ('BANK_CARD','ozel bankacilik',70),
  ('BANK_CARD','private banking',70)
) as a(code, alias, w)
where p.code = a.code
on conflict do nothing;

-- Kapsama durumu işaretle: neyi bildiğimizi neyi bilmediğimizi AÇIKÇA yaz
update lounge_programs set coverage_status = 'verified'
 where code in ('TK_MS','PRIORITY_PASS','DRAGONPASS','PGS_PAID');
update lounge_programs set coverage_status = 'partial'
 where code in ('STAR_GOLD','LOUNGEKEY','PLAZA_PREMIUM','PRIMECLASS');
update lounge_programs set coverage_status = 'unknown'
 where code in ('AJET_MS','IGA_LOUNGE','BANK_CARD','BUSINESS_TICKET');


-- ============================================================
-- 8) SAĞLIK RAPORU — kart katmanı da denetlenir
-- ============================================================
create or replace function public.entitlement_health()
returns table (alan text, sorun text, ayrinti text, agirlik int)
language sql stable security definer set search_path = public as $$
  select i.name || ' · ' || cp.name, 'kart urunu dogrulanmadi',
         coalesce('son dogrulama ' || cp.checked_at::text, 'hic dogrulanmadi') ||
         ' — banka kampanya kosullari sik degisir', 1
    from lounge_card_products cp join lounge_issuers i on i.id = cp.issuer_id
   where cp.active and (cp.checked_at is null or cp.checked_at < current_date - 180)
  union all
  select i.name || ' · ' || cp.name, 'altyapi programi bos',
         'Bu kartin hangi aga (PP/LoungeKey/DragonPass) bagli oldugu girilmemis', 1
    from lounge_card_products cp join lounge_issuers i on i.id = cp.issuer_id
   where cp.active and cp.program_id is null
  union all
  select i.name || ' · ' || cp.name, 'kota bilinmiyor',
         'quota_total bos — host''a kalan hakki gosteremeyiz', 2
    from lounge_card_products cp join lounge_issuers i on i.id = cp.issuer_id
   where cp.active and cp.quota_total is null and coalesce(cp.quota_period,'') <> 'unlimited'
  union all
  select p.name, 'kapsama bilinmiyor',
         'coverage_status = unknown — kullaniciya genel uyari gosterilecek', 2
    from lounge_programs p where p.active and coalesce(p.coverage_status,'unknown') = 'unknown'
  union all
  select v.airport_code || ' · ' || v.name, 'saha raporlari kuralla celisiyor',
         format('%s olumlu / %s olumsuz rapor — kural "%s" diyor, gozden gecir',
                a.field_reports_ok, a.field_reports_bad, a.guest_policy), 1
    from lounge_venue_acceptance a join lounge_venues v on v.id = a.venue_id
   where a.field_reports_bad >= 2 and a.guest_policy = 'included'
  union all
  select coalesce(pr.name, 'kullanici'), 'hak beyani bayat',
         'Host''un kota beyani 60 gunden eski — kalan hak yanlis olabilir', 3
    from host_entitlements he left join profiles pr on pr.user_id = he.user_id
   where he.quota_total is not null
     and (he.self_reported_at is null or he.self_reported_at < now() - interval '60 days');
$$;
grant execute on function public.entitlement_health() to authenticated;


-- ============================================================
-- 9) DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_issuers)        as ihraccilar,
       (select count(*) from lounge_card_products)  as kart_urunleri,
       (select count(*) from lounge_card_products where program_id is null) as programsiz_kart,
       (select count(*) from lounge_programs where coverage_status = 'unknown') as bilinmeyen_program;

select i.name, cp.name, p.code as ag, cp.quota_total, cp.quota_period,
       cp.guest_consumes_quota, cp.requires_preissued_pass
  from lounge_card_products cp
  join lounge_issuers i on i.id = cp.issuer_id
  left join lounge_programs p on p.id = cp.program_id
 order by i.name;

select * from public.entitlement_health() order by agirlik, alan limit 40;

select '087 OK - kart/kota/saha-raporu katmani kuruldu, app ETKILENMEDI' as sonuc;
