-- ============================================================
-- LoungeLink · 125_saw_plaza_partners.sql
-- SAW PLAZA PREMIUM: ANLASMALI KURUMLAR (BIRINCIL KAYNAK)
--
-- ⚠️ Uygulamayi ETKILER (yeni tablo + veri).
--
-- KAYNAK: sabihagokcen.aero — Plaza Premium Lounge sayfasi,
-- "ANLASMALI KURUMLAR" bolumu. Site bot korumasi nedeniyle
-- okunamiyordu; Gokberk telefondan girip ekran goruntusu gonderdi.
-- Havalimaninin KENDI sayfasi oldugu icin BIRINCIL kaynak sayilir.
--
-- ------------------------------------------------------------
-- 🔴 ONEMLI: IC HAT VE DIS HAT LISTELERI FARKLI
-- ------------------------------------------------------------
-- Ayni salon adi, ayni isletmeci — ama anlasma listeleri ayni DEGIL:
--   · Koopbank YALNIZ dis hatta
--   · Dufry YALNIZ dis hatta
--   · Ic hatta tek havayolu var (Pegasus); dis hatta DOKUZ havayolu
-- "SAW Plaza Premium'da su kart gecer" demek bu yuzden yetersiz;
-- HANGI TERMINALDE oldugu belirleyici.
--
-- ------------------------------------------------------------
-- 🔴 NEYI BILDIGIMIZI, NEYI BILMEDIGIMIZI AYIRIYORUZ
-- ------------------------------------------------------------
-- Sayfa ANLASMANIN VARLIGINI soyluyor ("Denizbank"), KOSULLARINI
-- soylemiyor: kac hak, misafir var mi, ucretsiz mi indirimli mi.
-- Ustelik sayfanin kendi dipnotu da bunu yaziyor:
--   "Anlasmali kurumlar araciligiyla hizmetlerden faydalanma
--    kosullari degisiklik gosterebilir."
--
-- O yuzden VARLIK 'verified', KOSULLAR 'unknown'. Ikisini tek bir
-- "dogrulandi" etiketiyle karistirmak, bilmedigimizi biliyormus gibi
-- gostermek olur — kart kataloğunda bu hatayi bir kez yapmistik.
-- ============================================================

create table if not exists lounge_venue_partners (
  id           uuid primary key default gen_random_uuid(),
  venue_id     uuid not null references lounge_venues(id) on delete cascade,
  scope        text not null check (scope in ('domestic','international','both')),
  partner_kind text not null check (partner_kind in ('bank','airline','global','corporate')),
  partner_name text not null,
  program_id   uuid references lounge_programs(id),
  terms_known  boolean not null default false,
  note         text,
  source_url   text,
  checked_at   date,
  active       boolean not null default true,
  created_at   timestamptz default now(),
  unique (venue_id, scope, partner_kind, partner_name)
);
comment on table lounge_venue_partners is
  'Bir salona hangi kurumlarla girilebildigi. VARLIK dogrulanmis olabilir '
  'ama KOSULLAR (adet, misafir, ucret) genellikle bilinmez — terms_known.';

create index if not exists ix_lvp_venue on lounge_venue_partners (venue_id, scope);

-- ---- IC HATLAR ----
with v as (
  select id from lounge_venues
   where airport_code = 'SAW' and active
     and lower(name) like '%plaza premium%'
     and coalesce(scope,'both') in ('domestic','both')
   order by (coalesce(scope,'') = 'domestic') desc limit 1
)
insert into lounge_venue_partners
  (venue_id, scope, partner_kind, partner_name, program_id, terms_known, note, source_url, checked_at)
select v.id, 'domestic', p.kind, p.nm,
       (select id from lounge_programs where code = p.pcode),
       false,
       'Anlaşmanın VARLIĞI havalimanının kendi sayfasından doğrulandı; '
       || 'KOŞULLARI (adet, misafir hakkı, ücretsiz mi indirimli mi) sayfada YAZMIYOR. '
       || 'Sayfanın kendi dipnotu: koşullar değişiklik gösterebilir.',
       'https://www.sabihagokcen.aero/', current_date
  from v, (values
    ('bank','Denizbank', null), ('bank','Garanti BBVA', null),
    ('bank','Kuveyt Türk', null), ('bank','QNB Türkiye', null),
    ('bank','Türkiye İş Bankası', null), ('bank','Vakıfbank', null),
    ('airline','Pegasus','PGS_PAID'),
    ('global','American Express Global', null), ('global','Capital One', null),
    ('global','Dragon Pass','DRAGONPASS'), ('global','DreamFolks', null),
    ('global','Everylounge (REG)', null), ('global','GetYourGuide', null),
    ('global','Lounge Key','LOUNGEKEY'), ('global','OnPass', null),
    ('global','Priority Pass','PRIORITY_PASS'),
    ('corporate','Akustik More', null), ('corporate','My Clause', null),
    ('corporate','Papara', null), ('corporate','ST Pass Türkiye', null)
  ) as p(kind, nm, pcode)
on conflict (venue_id, scope, partner_kind, partner_name) do nothing;

-- ---- DIS HATLAR ----
-- 🔴 Koopbank ve Dufry YALNIZ burada; havayolu listesi dokuz kat genis.
with v as (
  select id from lounge_venues
   where airport_code = 'SAW' and active
     and lower(name) like '%plaza premium%'
     and coalesce(scope,'both') in ('international','both')
   order by (coalesce(scope,'') = 'international') desc limit 1
)
insert into lounge_venue_partners
  (venue_id, scope, partner_kind, partner_name, program_id, terms_known, note, source_url, checked_at)
select v.id, 'international', p.kind, p.nm,
       (select id from lounge_programs where code = p.pcode),
       false,
       'Anlaşmanın VARLIĞI havalimanının kendi sayfasından doğrulandı; KOŞULLARI yazmıyor.',
       'https://www.sabihagokcen.aero/', current_date
  from v, (values
    ('bank','Denizbank', null), ('bank','Garanti BBVA', null),
    ('bank','Koopbank', null), ('bank','Kuveyt Türk', null),
    ('bank','QNB Türkiye', null), ('bank','Türkiye İş Bankası', null),
    ('bank','Vakıfbank', null),
    ('airline','Azal Airways', null), ('airline','British Airways', null),
    ('airline','Fly Dubai', null), ('airline','Kuwait Airways', null),
    ('airline','Nile Air', null), ('airline','Pegasus','PGS_PAID'),
    ('airline','Qatar Airways', null), ('airline','Royal Air Maroc', null),
    ('airline','Smartwings', null),
    ('global','American Express Global', null), ('global','Capital One', null),
    ('global','Dragon Pass','DRAGONPASS'), ('global','DreamFolks', null),
    ('global','Everylounge (REG)', null), ('global','GetYourGuide', null),
    ('global','Lounge Key','LOUNGEKEY'), ('global','OnPass', null),
    ('global','Priority Pass','PRIORITY_PASS'),
    ('corporate','Akustik More', null), ('corporate','Dufry', null),
    ('corporate','My Clause', null), ('corporate','Papara', null),
    ('corporate','ST Pass Türkiye', null)
  ) as p(kind, nm, pcode)
on conflict (venue_id, scope, partner_kind, partner_name) do nothing;

-- ---- Eksik global programlari kataloga ekle ----
-- 🔴 Bes yeni ag ogrendik. Host "DreamFolks" yazdiginda bugune kadar
-- hicbir seye eslesmiyordu; artik en azindan TANINIYOR ve genel
-- uyariya dusuyor. Tanimadigimiz bir adi tanimak, ilk adimdir.
insert into lounge_programs
  (code, name, kind, entitlement_model, guest_default, guest_flight_coupling,
   enforcement, coverage_status, notes, source_url)
values
  ('DREAMFOLKS','DreamFolks','card_program','card_membership','unknown','any',
   'warn','unknown',
   'SAW Plaza Premium anlasma listesinde var. Kosullari DOGRULANMADI.',
   'https://www.sabihagokcen.aero/'),
  ('ONPASS','OnPass','card_program','card_membership','unknown','any',
   'warn','unknown','SAW Plaza Premium anlasma listesinde var. Kosullari DOGRULANMADI.',
   'https://www.sabihagokcen.aero/'),
  ('EVERYLOUNGE','Everylounge (REG)','card_program','card_membership','unknown','any',
   'warn','unknown','SAW Plaza Premium anlasma listesinde var. Kosullari DOGRULANMADI.',
   'https://www.sabihagokcen.aero/'),
  ('AMEX_GLOBAL','American Express Global','card_program','bank_card','unknown','any',
   'warn','unknown','SAW Plaza Premium anlasma listesinde var. Kart tipine gore degisir.',
   'https://www.sabihagokcen.aero/'),
  ('ST_PASS','ST Pass Türkiye','operator','paid_entry','unknown','any',
   'warn','unknown','SAW Plaza Premium kurumsal anlasma listesinde var.',
   'https://www.sabihagokcen.aero/')
on conflict (code) do nothing;

insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('DREAMFOLKS','dreamfolks',95), ('DREAMFOLKS','dream folks',90),
  ('ONPASS','onpass',95),         ('EVERYLOUNGE','everylounge',95),
  ('AMEX_GLOBAL','american express',88), ('AMEX_GLOBAL','amex',85),
  ('ST_PASS','st pass',92)
) as a(code, alias, w) where p.code = a.code
on conflict do nothing;

-- ---- Plaza Premium HAVAYOLU GOZETMIYOR ----
-- Sayfa aynen: "seyahat veya havayolu gozetmeksizin tum misafirlerine"
update lounge_programs
   set guest_flight_coupling = 'any',
       coverage_status = 'verified', checked_at = current_date,
       source_url = 'https://www.sabihagokcen.aero/',
       notes = coalesce(notes,'') || ' [125] Havalimani sayfasi: "seyahat veya HAVAYOLU '
            || 'GOZETMEKSIZIN tum misafirlerine" — bu salonda ayni-havayolu sarti YOK.'
 where code = 'PLAZA_PREMIUM';

-- ---- DOGRULAMA ----
select p.scope, p.partner_kind, count(*) as kurum
  from lounge_venue_partners p group by 1,2 order by 1,2;

select p.partner_name, p.scope
  from lounge_venue_partners p
 where p.partner_name in ('Koopbank','Dufry')
 order by p.partner_name;

select '125 OK - SAW Plaza Premium anlasmalari birincil kaynaktan girildi' as sonuc;
