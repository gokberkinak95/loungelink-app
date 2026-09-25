-- ============================================================
-- LoungeLink · 106_channel_fees_and_bank_deals.sql
-- UC ACIK KAPATILIYOR
--
-- ⚠️ Uygulamayi ETKILER (veri + metin). Sema degisikligi YOK.
--
-- ------------------------------------------------------------
-- 🔴 ACIK 1: AYNI SALONUN IKI FARKLI UCRETI VAR, BEN TEK RAKAM YAZDIM
-- ------------------------------------------------------------
-- SAW Plaza Premium icin Pegasus'un kendi sayfasindan 63 EUR kodladim.
-- Havalimani/ucuncu taraf kaynaklari ise KAPIDA girisi ~45 EUR diyor.
-- Ikisi de dogru olabilir cunku KANAL farkli:
--   · Pegasus uzerinden (bilet satin alirken/sonrasinda) satin alma
--   · Kapida walk-up giris
-- Ben kanali belirtmeden tek rakam yazdim. Misafir kapida "63 degil
-- 45'mis" derse, dogru rakami vermis olsak bile GUVEN kaybederiz.
-- Cozum: rakami degil, KANALI anlat. Tek bir sayiya bagli kalma.
-- ------------------------------------------------------------
update lounge_venue_acceptance a
   set guest_fee_note =
       'Ucret KANALA gore degisir: havayolu uzerinden onceden satin alindiginda '
    || 'ile kapida walk-up giriste farkli tarifeler uygulanabiliyor (SAW''da '
    || 'yaklasik 45-63 EUR araligi bildiriliyor). Kesin tutari GIRISTEN ONCE '
    || 'salondan ya da havayolundan teyit edin.',
       conditions = coalesce(a.conditions,'')
    || ' [106] Tek bir rakam yerine ARALIK ve KANAL yazildi: ayni salonun '
    || 'onceden satin alma ve kapida giris tarifeleri farkli olabiliyor.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'PGS_PAID' and a.guest_policy = 'paid';


-- ============================================================
-- 🔴 ACIK 2: BANKA KARTI ANLASMALARI KATALOGDA YOKTU
-- ------------------------------------------------------------
-- Sabiha Gokcen ve IST'te salonlara KART BAZLI anlasmalarla giriliyor
-- ve bunlarin hicbiri katalogda yoktu. Hepsi 'Kredi Karti Avantaji'
-- kovasina dusup genel uyari aliyordu — akis calisiyordu ama BILGI
-- eksikti. Host "Garanti Prive'im var" dedigi anda ona salonu ve
-- misafir hakkini soyleyebilmeliyiz.
--
-- 🔴 HEPSI confidence='secondary' VE checked_at=NULL.
-- Kaynaklar bankalarin kampanya sayfalari ve ucuncu taraf rehberler;
-- BIRINCIL kart sozlesmesi degil. Kampanyalar uc ayda bir degisiyor.
-- Bu satirlar kapsami artirir, GUVENI ARTIRMAZ — ayrim korunuyor ve
-- saglik raporunda kirmizi gorunurler.
-- ============================================================
insert into lounge_issuers (code, name, kind) values
  ('PRIVIA','Denizbank Privia','bank'),
  ('ING_TR','ING Türkiye','bank')
on conflict (code) do nothing;

insert into lounge_card_products
  (issuer_id, name, program_id, segment, quota_total, quota_period,
   guest_consumes_quota, guest_quota_total, guest_quota_period,
   condition_type, condition_note, conditions, confidence, source_url, checked_at)
select i.id, c.name,
       (select id from lounge_programs where code = c.pcode),
       c.seg, c.qt, c.qp, false, c.gq, c.gqp, c.ctype, c.cnote, c.cond,
       'secondary', c.url, null
  from lounge_issuers i
  join (values
    ('GARANTI','Miles&Smiles Privé — Plaza Premium','PLAZA_PREMIUM','Özel Bankacılık',
     null::smallint,null::text, null::smallint,null::text,'segment',
     'Ozel bankacilik segmenti.',
     'SAW ic ve dis hat Plaza Premium salonlarinda gecerli oldugu bildiriliyor; '
     || 'havayolu ve bilet sinifi gozetilmiyor. Misafir hakki DOGRULANMADI.',
     'https://www.milesandsmilesgarantibbva.com/'),
    ('ING_TR','ING Özel Bankacılık Kredi Kartı','PLAZA_PREMIUM','Özel Bankacılık',
     null,null, null,null,'segment','Ozel bankacilik musterilerine acik.',
     'SAW ic ve dis hat Plaza Premium salonlarinda gecerli oldugu bildiriliyor. '
     || 'Adet ve misafir hakki DOGRULANMADI.',
     'https://www.ing.com.tr/'),
    ('VAKIF','Milplus Platinum','PLAZA_PREMIUM',null,
     null,null, null,null,'unknown',null,
     'SAW ic ve dis hat Plaza Premium salonlarinda gecerli oldugu bildiriliyor.',
     'https://www.vakifbank.com.tr/'),
    ('ALBARAKA','Özel Bankacılık / Platinum','PLAZA_PREMIUM',null,
     null,null, null,null,'unknown',null,
     'SAW Plaza Premium salonlarinda gecerli oldugu bildiriliyor.',
     'https://www.albaraka.com.tr/'),
    ('TEB','Özel World Elite / Infinite — Kepler Club','LOUNGEKEY','Özel',
     null,null, 1::smallint,'month','segment',
     'TEB Ozel segmenti.',
     'SAW DIS HAT Kepler Club salonunda gecerli oldugu bildiriliyor. Yurt icinde '
     || 'BIR MISAFIRLE ucretsiz giris bildiriliyor — DOGRULANMADI.',
     'https://www.teb.com.tr/'),
    ('ISBANK','Bireysel Maximum — SAW indirimli','PLAZA_PREMIUM',null,
     null,null, null,null,'campaign',
     'Kampanya donemi: 22.04.2025 - 30.04.2026.',
     'UCRETSIZ DEGIL: Plaza Premium tarifesi uzerinden INDIRIMLI giris. Odeme '
     || 'Iscep uzerinden yapilip QR ile giriliyor. Misafir icin ayri ucret cikar.',
     'https://www.maximum.com.tr/'),
    ('PRIVIA','Privia Black','PLAZA_PREMIUM','Varlık 10 mn TL+',
     1,'month', 1::smallint,'month','tier_and_spend',
     'Bankadaki varlik birikimi 10 milyon TL ve uzeri sarti.',
     'SAW ic ve dis hat Plaza Premium: AYDA 1 KEZ, yaninda 1 MISAFIR ile. '
     || 'Islem basina ve aylik en fazla belirli bir tutara kadar indirim. '
     || 'Ek kart sahipleri de yararlanabiliyor.',
     'https://www.privia.com.tr/')
  ) as c(icode,name,pcode,seg,qt,qp,gq,gqp,ctype,cnote,cond,url)
    on c.icode = i.code
on conflict do nothing;

-- Bu kartlarin isimleri host beyanindan eslessin
insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('PLAZA_PREMIUM','plaza premium',95), ('PLAZA_PREMIUM','privia',88),
  ('PLAZA_PREMIUM','milplus',85),       ('PLAZA_PREMIUM','albaraka ozel',85),
  ('PLAZA_PREMIUM','ing ozel',85),      ('PLAZA_PREMIUM','miles&smiles prive',90),
  ('LOUNGEKEY','teb ozel',88),          ('LOUNGEKEY','kepler club',85)
) as a(code, alias, w) where p.code = a.code
on conflict do nothing;

-- Plaza Premium artik "kismen" degil: SAW'da kanit var
update lounge_programs
   set coverage_status = 'partial',
       notes = coalesce(notes,'') || ' [106] SAW ic ve dis hat salonlarina bircok banka '
            || 'kartiyla giriliyor (Garanti Prive, ING Ozel, Vakif Milplus, Albaraka, '
            || 'Privia Black, Is Bankasi indirimli). Kart urunleri katalogda ama '
            || 'DOGRULANMADI — kampanyalar uc ayda bir degisiyor.'
 where code = 'PLAZA_PREMIUM';


-- ============================================================
-- DOGRULAMA
-- ============================================================
select i.name as banka, cp.name as kart, p.code as ag, cp.confidence,
       coalesce(cp.guest_quota_total::text,'-') as misafir_havuzu
  from lounge_card_products cp
  join lounge_issuers i on i.id = cp.issuer_id
  left join lounge_programs p on p.id = cp.program_id
 where cp.confidence = 'secondary' and cp.checked_at is null
 order by i.name, cp.name;

select count(*) as toplam_kart,
       count(*) filter (where confidence = 'verified') as dogrulanmis,
       count(*) filter (where confidence = 'secondary') as ikincil,
       count(*) filter (where confidence = 'unknown') as bilinmeyen
  from lounge_card_products;

select '106 OK - Pegasus ucreti kanala baglandi, 7 banka anlasmasi kataloga girdi' as sonuc;
