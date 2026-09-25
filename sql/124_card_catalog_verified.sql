-- ============================================================
-- LoungeLink · 124_card_catalog_verified.sql
-- KART KATALOGU: BIRINCIL KAYNAKTAN DOGRULAMA
--
-- ⚠️ Uygulamayi ETKILER (veri + guven derecesi).
--
-- ------------------------------------------------------------
-- 🔴 ILKE: KAYNAK TURUNU KARISTIRMA
-- ------------------------------------------------------------
--   'verified'  = BANKANIN KENDI SITESINDEN, kosullariyla birlikte
--   'secondary' = karsilastirma sitesi / haber / rehber
--   'unknown'   = hicbir kaynak yok
--
-- Karsilastirma siteleri hizli bilgi verir ama KAMPANYA DILI kullanir
-- ("yilda 5 kez!") ve istisnalari yazmaz. Bankanin kendi sayfasi ise
-- sinirlari da yazar — ve kapida onemli olan sinirlardir.
--
-- ------------------------------------------------------------
-- 🔴 QNB'DEN OGRENDIGIM KRITIK NUANS
-- ------------------------------------------------------------
-- qnb.com.tr/private/.../lounge-ayricaliklari aynen soyle diyor:
--   "Private kredi karti sahibi musterinin beraberinde getirecegi
--    misafirlerin hizmetlerden ucretsiz olarak yararlanmasi da
--    15 defalik hakkin ICINDE sayilmaktadir."
--
-- Yani misafir AYRI bir havuzdan degil, AYNI havuzdan dusuyor.
-- 15 hakli bir kart, esiyle giden birine 7 SEYAHAT eder. Bu, bizim
-- `guest_consumes_quota` alanimizin tam olarak var olma sebebi —
-- ve bugune kadar hicbir kartta true isaretlenmemisti.
--
-- Ziraat'in ekran goruntulerinde ise TERSI vardi: misafir icin AYRI
-- 4'luk havuz. Iki banka, iki farkli model. Tek bir "misafir hakki"
-- kavramiyla ikisini birden anlatmak MUMKUN DEGIL — o yuzden iki
-- ayri alan tutuyoruz.
-- ============================================================

-- ============================================================
-- 🔴 SEMA GENISLETME: 'visit' DONEMI
-- Akbank Wings "HER GIRISTE 1 misafir" diyor. Bu ne yillik ne aylik
-- bir kota — ZIYARET BASINA bir hak. Mevcut kisit yalniz
-- ('year','month','unlimited') kabul ediyordu ve 124 bu yuzden 23514
-- verdi.
--
-- Kolay yol: Wings'i 'year' diye yazip gecmekti. Ama o zaman "yilda 1
-- misafir" demis olurduk — kartin sundugu seyin BESTE BIRI. Semaya
-- uymayan gercegi semaya uydurmak, veriyi bozmaktir; sema genisler.
-- ============================================================
alter table lounge_card_products drop constraint if exists lcp_gq_period_chk;
alter table lounge_card_products add constraint lcp_gq_period_chk
  check (guest_quota_period is null
         or guest_quota_period in ('year','month','visit','unlimited'));

alter table lounge_card_products drop constraint if exists lcp_q_period_chk;
alter table lounge_card_products add constraint lcp_q_period_chk
  check (quota_period is null
         or quota_period in ('year','month','visit','unlimited'));

insert into lounge_issuers (code, name, kind) values
  ('QNB','QNB','bank'), ('AKBANK','Akbank','bank'),
  ('YKB','Yapı Kredi','bank'), ('KUVEYT','Kuveyt Türk','bank')
on conflict (code) do nothing;

-- ---- DOGRULANMIS: bankanin kendi sayfasindan ----
insert into lounge_card_products
  (issuer_id, name, program_id, segment, quota_total, quota_period,
   guest_consumes_quota, guest_quota_total, guest_quota_period,
   condition_type, condition_note, conditions, confidence, source_url, checked_at)
select i.id, 'Private Kredi Kartı',
       (select id from lounge_programs where code = 'LOUNGEKEY'),
       'Private Bankacılık', 15, 'year',
       -- 🔴 MISAFIR AYNI HAVUZDAN DUSUYOR
       true, null, null,
       'segment', 'QNB Private bankacılık müşterisi olmak gerekir.',
       'Yılda 15 kullanım (1 Ocak–31 Aralık 2026). MİSAFİRLER DE AYNI 15 HAKTAN '
       || 'düşer — eşinle gidersen 7 seyahat eder. 15 aşılırsa kişi başı 35 USD. '
       || 'Her geçiş için karta 1 USD geçici bloke konur (takip amaçlı, 5 iş gününde '
       || 'çözülür). Yurt içinde IST, ESB, ADB, BJV, AYT ve DLM''de geçerli. '
       || 'LoungeKey üyelik formuna ad-soyad BÜYÜK HARF ve İngilizce karakterle yazılmalı.',
       'verified', 'https://www.qnb.com.tr/private/private-ayricaliklar/private-seyahat/lounge-ayricaliklari',
       current_date
  from lounge_issuers i where i.code = 'QNB'
on conflict do nothing;

-- ---- IKINCIL: karsilastirma kaynaklari, DOGRULANMADI ----
insert into lounge_card_products
  (issuer_id, name, program_id, segment, quota_total, quota_period,
   guest_consumes_quota, guest_quota_total, guest_quota_period,
   condition_type, condition_note, conditions, confidence, source_url, checked_at)
select i.id, c.nm,
       (select id from lounge_programs where code = c.pcode),
       c.seg, c.qt, c.qp, c.gc, c.gq, c.gqp, c.ctype, c.cnote, c.cond,
       'secondary', c.url, null
  from lounge_issuers i
  join (values
    ('AKBANK','Wings Elite','PRIORITY_PASS','Wings', 5::smallint,'year',
     false, 1::smallint,'visit','none', null,
     'Yılda 5 ücretsiz giriş, HER GİRİŞTE 1 misafir ücretsiz bildiriliyor. '
     || 'LoungeMe uygulamasından üyelik açmak gerekiyor. DOĞRULANMADI.',
     'https://www.akbank.com/'),
    ('YKB','Crystal','PRIORITY_PASS','Crystal', 2::smallint,'month',
     false, null::smallint, null,'none', null,
     'Ayda 2 giriş (yılda 24''e kadar) bildiriliyor. Misafir hakkı BELİRSİZ — '
     || 'çoğu kartta misafir ek ücretli. DOĞRULANMADI.',
     'https://www.yapikredi.com.tr/'),
    ('TEB','Infinite Ultra','PRIORITY_PASS','Infinite', null::smallint, null,
     false, null::smallint, null,'segment','TEB Özel/Infinite segmenti.',
     'Priority Pass ağı üzerinden geniş kapsam bildiriliyor. Adet ve misafir '
     || 'hakkı DOĞRULANMADI.',
     'https://www.teb.com.tr/'),
    ('KUVEYT','Özel Bankacılık','LOUNGEKEY','Özel Bankacılık', null::smallint, null,
     false, null::smallint, null,'segment','Özel bankacılık müşterisi olmak gerekir.',
     'LoungeKey ağı üzerinden ücretsiz kullanım bildiriliyor. Adet ve misafir '
     || 'hakkı DOĞRULANMADI.',
     'https://www.kuveytturk.com.tr/'),
    ('ISBANK','Maximiles / Maximiles Black','PRIORITY_PASS', null, null::smallint, null,
     false, null::smallint, null,'tier_and_spend',
     'Bankadaki varlık birikimi 8 milyon TL ve üzeri.',
     '🔴 OTOMATİK ÜCRETSİZ DEĞİL: IST İGA Lounge''larında İNDİRİMLİ giriş. '
     || 'Varlık eşiğini aşan müşterilerde indirim oranı yükseliyor. '
     || 'Misafir için ayrı ücret çıkar. DOĞRULANMADI.',
     'https://www.maximum.com.tr/')
  ) as c(icode, nm, pcode, seg, qt, qp, gc, gq, gqp, ctype, cnote, cond, url)
    on c.icode = i.code
on conflict do nothing;

-- 🔴 ZIRAAT: misafir AYRI havuzdan (ekran goruntulerinden).
-- QNB'nin tersi model; ikisini ayni alanla anlatmak mumkun degil.
update lounge_card_products cp
   set guest_consumes_quota = false,
       conditions = coalesce(cp.conditions,'')
                 || ' NOT: Misafir hakkı AYRI havuzdan düşer (QNB Private''ın tersine, '
                 || 'orada misafir aynı havuzu tüketir).'
  from lounge_issuers i
 where cp.issuer_id = i.id and i.code = 'ZIRAAT'
   and coalesce(cp.conditions,'') not like '%AYRI havuzdan%';

-- ---- DOGRULAMA ----
select cp.confidence, count(*) as kart,
       count(*) filter (where cp.checked_at is not null) as tarihli
  from lounge_card_products cp group by 1 order by 2 desc;

select i.name, cp.name, cp.confidence,
       coalesce(cp.quota_total::text,'-') as hak,
       cp.guest_consumes_quota as misafir_ayni_havuzdan
  from lounge_card_products cp join lounge_issuers i on i.id = cp.issuer_id
 where cp.confidence = 'verified' order by i.name;

select '124 OK - kart katalogu kaynak turune gore ayrildi' as sonuc;
