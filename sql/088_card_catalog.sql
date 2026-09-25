-- ============================================================
-- LoungeLink · 088_card_catalog.sql
-- KREDİ KARTI KATALOĞU (Türkiye) + KOŞUL/KAMPANYA BOYUTU
--
-- ⚠️ UYGULAMAYI ETKİLEMEZ. Yeni nullable kolonlar + veri.
--
-- ------------------------------------------------------------
-- 🔴 087'DEN SONRA ÇIKAN DÖRDÜNCÜ BULGU
-- ------------------------------------------------------------
-- 087'de kartın hakkını "kota" olarak modelledik (15/yıl, 4/ay…).
-- Katalogu genişletirken bunun da yetmediği ortaya çıktı:
--
--   "Çoğu kartta erişim sınırsız değil, KOŞULLUDUR. Bazı kartlarda giriş
--    hakkı KAMPANYA TARİHİNE, bazılarında MÜŞTERİ SEGMENTİNE, bazılarında
--    YILLIK KULLANIM ADEDİNE bağlıdır."
--   "Asgari harcama şartı: bazı bankalar lounge hakkını belirli bir aylık
--    harcama şartına bağlayabiliyor."
--   TEB: müşterinin bankadaki varlığına göre Standart / Plus / Premium /
--    Ultra paketi belirleniyor ve hak buna göre değişiyor.
--
-- Yani bir kartın lounge hakkı, kartın SABİT bir özelliği DEĞİL;
-- zamana, müşteri segmentine ve harcamaya bağlı bir KAMPANYADIR.
--
-- BUNUN ÜRÜNE SONUCU (ve bence bu turun en dürüst tespiti):
-- 🔴 KREDİ KARTLARI KONUSUNDA ASLA OTORİTE OLAMAYIZ.
--    Havayolu ve kart-programı (PP/DragonPass) koşullarını okuyup kesin
--    konuşabiliriz — onlar tek bir yayıncının tek bir metnidir. Ama
--    "Garanti Miles&Smiles Privé'nin bu ayki lounge hakkı" 20 bankanın
--    yüzlerce kampanya sayfasında yaşıyor ve üç ayda bir değişiyor.
--    Bunu senkron tutmaya çalışmak, tutulamayacak bir söz vermektir.
--
-- DOĞRU TASARIM ÜÇ AYAKLI:
--   1. Bildiğimiz kadarını VARSAYILAN olarak veririz (bu tablo),
--   2. Host'a KENDİ kalan hakkını sorarız ve bankanın kendi sayfasına
--      derin bağlantı veririz (issuer.self_check_url),
--   3. Kapıda ne olduğunu saha raporlarıyla toplarız (087 §5).
-- Yani kart tarafında iddiamız "biliyoruz" değil, "hatırlatıyoruz".
-- ============================================================


-- ============================================================
-- 1) KOŞUL/KAMPANYA BOYUTU
-- ============================================================
alter table lounge_card_products add column if not exists segment        text;
alter table lounge_card_products add column if not exists condition_type text;
alter table lounge_card_products add column if not exists condition_note text;
alter table lounge_card_products add column if not exists min_spend_note text;
alter table lounge_card_products add column if not exists valid_from     date;
alter table lounge_card_products add column if not exists valid_to       date;
alter table lounge_card_products add column if not exists confidence     text;

alter table lounge_card_products drop constraint if exists lcp_condition_chk;
alter table lounge_card_products add constraint lcp_condition_chk
  check (condition_type is null or condition_type in
    ('none','segment','min_spend','campaign','tier_and_spend','unknown'));

alter table lounge_card_products drop constraint if exists lcp_confidence_chk;
alter table lounge_card_products add constraint lcp_confidence_chk
  check (confidence is null or confidence in ('verified','secondary','assumed','unknown'));

-- Bankanın kendi "kalan hakkım" sayfası. Host'a gösterilecek tek dürüst
-- cevap bu: biz tahmin ederiz, kesin bilgi bankasındadır.
alter table lounge_issuers add column if not exists self_check_url text;
alter table lounge_issuers add column if not exists self_check_note text;

-- Kampanya süresi geçmiş kartı kullanmayalım
create or replace function public.card_product_active_now(p_card_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select cp.active
     and (cp.valid_from is null or cp.valid_from <= current_date)
     and (cp.valid_to   is null or cp.valid_to   >= current_date)
    from lounge_card_products cp where cp.id = p_card_id;
$$;
grant execute on function public.card_product_active_now(uuid) to authenticated;


-- ============================================================
-- 2) İHRAÇÇILAR — genişletilmiş
-- ============================================================
insert into lounge_issuers (code, name, kind) values
  ('ZIRAAT','Ziraat Bankası','bank'),
  ('VAKIF','VakıfBank','bank'),
  ('HALK','Halkbank','bank'),
  ('KUVEYT','Kuveyt Türk','bank'),
  ('ING','ING Türkiye','bank'),
  ('HSBC','HSBC Türkiye','bank'),
  ('ALBARAKA','Albaraka Türk','bank'),
  ('SEKER','Şekerbank','bank'),
  ('ODEA','Odeabank','bank'),
  ('ENPARA','Enpara','bank'),
  ('DINERS','Diners Club','fintech')
on conflict (code) do nothing;

update lounge_issuers set
  self_check_note = 'Kalan lounge hakkı ve güncel koşullar bankanın kendi uygulamasında/sayfasında görünür.'
 where self_check_note is null;


-- ============================================================
-- 3) KART KATALOĞU
--
-- ⚠️ confidence='secondary' → karşılaştırma sitelerinden derlendi,
--    bankanın RESMİ sayfasından doğrulanmadı. checked_at BİLEREK null.
--    'unknown' → hak olduğunu biliyoruz, koşulunu bilmiyoruz.
--    Sağlık raporu hepsini kırmızı gösterecek; doğru davranış budur.
-- ============================================================
insert into lounge_card_products
  (issuer_id, name, program_id, segment, quota_total, quota_period,
   guest_consumes_quota, guest_quota_cap, guest_fee_after_quota, guest_fee_currency,
   requires_preissued_pass, pass_needs_guest_legal_name, pass_change_allowed,
   condition_type, condition_note, conditions, confidence, source_url, checked_at)
select i.id, c.name,
       (select p.id from lounge_programs p where p.code = c.pcode),
       c.seg, c.qt, c.qp, c.gcq, c.gcap, c.fee, c.cur,
       c.pre, c.legal, c.chg, c.ctype, c.cnote, c.cond, c.conf, c.url, null
  from lounge_issuers i
  join (values
    -- ---- TEB: varlık segmentine göre paket ----
    ('TEB','Infinite Ultra','PRIORITY_PASS','Ultra', null::smallint,'month', true, 2::smallint, null::numeric, null::text,
     true, true, false, 'segment',
     'Paket (Standart/Plus/Premium/Ultra) bankadaki varlığa göre belirleniyor; hak pakete gore degisir.',
     'Aylik en fazla 4 karekod, en fazla 2''si misafir. Karekod misafir adiyla ONCEDEN uretilir ve DEGISTIRILEMEZ.',
     'secondary','https://www.teb.com.tr/kart-dunyasi-ucretsiz-lounge-hizmeti/'),
    ('TEB','Infinite Premium','LOUNGEKEY','Premium', 4,'month', true, 2, null, null,
     true, true, false, 'segment',
     'Varlik 5-10 mn TL araligi.','Aylik 4 karekod, 2''si misafir.','secondary',
     'https://www.teb.com.tr/kart-dunyasi-ucretsiz-lounge-hizmeti/'),

    -- ---- Ziraat: en cömert misafir hakkı ----
    ('ZIRAAT','Prestij Plus','PRIORITY_PASS',null, 8,'year', false, 4, null, null,
     false, false, true, 'unknown',
     'Yilda 8 kullanim, 4 misafir hakki.','Harcamalarin Ziraat POS''undan gecme sarti mil icin gecerli; lounge sarti DOGRULANMADI.',
     'secondary','https://ucuzaucak.net/en-cok-mil-puan-kazandiran-kredi-kartlari/'),
    ('ZIRAAT','Prestij Plus Elite','PRIORITY_PASS',null, 30,'year', false, 4, null, null,
     false, false, true, 'unknown',
     'Yilda 30 kullanim, 4 misafir hakki — katalogdaki en yuksek limit.', null,
     'secondary','https://ucuzaucak.net/en-cok-mil-puan-kazandiran-kredi-kartlari/'),

    -- ---- Garanti BBVA ----
    ('GARANTI','Miles&Smiles Privé','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'segment',
     'Ozel bankacilik segmenti; hak karttan karta degisiyor.',
     'Primeclass / Plaza Premium erisimi bildiriliyor; adet ve misafir hakki DOGRULANMADI.',
     'secondary','https://www.airhelp.com/tr/blog/lounge-hizmeti-veren-kredi-kartlari/'),
    ('GARANTI','Miles&Smiles Özel Bankacılık','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'segment', 'Ozel bankacilik musterilerine acik.',
     '1 misafir ucretsiz agirlanabildigi ve kalan hakkin uygulamadan takip edilebildigi bildiriliyor — DOGRULANMADI.',
     'secondary','https://www.airhelp.com/tr/blog/lounge-hizmeti-veren-kredi-kartlari/'),
    ('GARANTI','Shop&Fly','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Lounge hakki olup olmadigi karta/kampanyaya bagli.',
     null,'unknown',null),

    -- ---- İş Bankası ----
    ('ISBANK','Maximiles Black','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Lounge erisimi mil kazanimiyla birlestiriliyor; adet DOGRULANMADI.',
     null,'secondary','https://hizligecis.com/blog/ucretsiz-havalimani-lounge-kredi-karti-kampanyalari'),
    ('ISBANK','Maximiles','IGA_LOUNGE',null, null,null, true, null, null, null,
     false, false, true, 'campaign',
     'Maximiles kartlarda lounge genel ve otomatik UCRETSIZ DEGIL; IST IGA Lounge''larda kampanya kapsaminda INDIRIMLI giris.',
     null,'secondary','https://www.hesapkurdu.com/kredi-karti/rehber/ucretsiz-lounge-veren-kredi-kartlari'),

    -- ---- Yapı Kredi ----
    ('YKB','World Elite','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Hak karta ve kampanyaya bagli.',null,'unknown',null),

    -- ---- Diğer bankalar: hak var, koşul bilinmiyor ----
    ('VAKIF','Platinum Plus Metal','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Lounge hakki bildiriliyor, kosul DOGRULANMADI.',null,'unknown',null),
    ('HALK','Parafly','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Seyahat karti; lounge kosulu DOGRULANMADI.',null,'unknown',null),
    ('KUVEYT','Miles&Smiles Kuveyt Türk','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown',null,null,'unknown',null),
    ('QNB','Miles&Smiles QNB','LOUNGEKEY',null, null,null, true, null, null, null,
     false, false, true, 'unknown',null,null,'unknown',null),
    ('DENIZ','Adios','PRIORITY_PASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown','Seyahat karti; lounge kosulu DOGRULANMADI.',null,'unknown',null),
    ('DINERS','Diners Club','DRAGONPASS',null, null,null, true, null, null, null,
     false, false, true, 'unknown',
     'Diners Club''in kendi lounge agi + ortak programlar; Turkiye kapsami DOGRULANMADI.',null,'unknown',null),
    ('AMEX','Metal The Platinum','PRIORITY_PASS',null, null,'unlimited', true, null, null, null,
     false, false, true, 'unknown',null,null,'unknown',null)
  ) as c(icode,name,pcode,seg,qt,qp,gcq,gcap,fee,cur,pre,legal,chg,ctype,cnote,cond,conf,url)
    on c.icode = i.code
on conflict do nothing;

-- 087'de girilen kartlara da güven derecesi ver
update lounge_card_products set confidence = 'secondary'
 where confidence is null and source_url is not null;
update lounge_card_products set confidence = 'unknown'
 where confidence is null;

-- Kart adları da serbest metinden eşleşebilsin
insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('PRIORITY_PASS','prestij plus',88), ('PRIORITY_PASS','maximiles',85),
  ('PRIORITY_PASS','world elite',82),  ('PRIORITY_PASS','shop&fly',80),
  ('PRIORITY_PASS','parafly',80),      ('PRIORITY_PASS','adios kart',80),
  ('PRIORITY_PASS','infinite ultra',92),
  ('DRAGONPASS','diners club',90),     ('DRAGONPASS','diners',80)
) as a(code, alias, w)
where p.code = a.code
on conflict do nothing;


-- ============================================================
-- 4) 🔴 HOST'A "KENDİ HAKKINI TEYİT ET" ÇIKTISI
-- Kart tarafında verebileceğimiz en dürüst cevap bu.
-- ============================================================
create or replace function public.card_self_check(p_user_id uuid default null)
returns table (kart text, banka text, tahmini_hak text, teyit_notu text, kaynak text)
language sql stable security definer set search_path = public as $$
  select cp.name,
         i.name,
         case
           when cp.quota_period = 'unlimited' then 'sinirsiz (karta gore)'
           when cp.quota_total is null        then 'adet bilinmiyor'
           else cp.quota_total || ' / ' || cp.quota_period
         end,
         case cp.confidence
           when 'verified'  then 'Resmi kaynaktan dogrulandi.'
           when 'secondary' then 'Karsilastirma kaynaklarindan derlendi — bankandan teyit et.'
           else 'Bu kartin kosulunu bilmiyoruz — lutfen bankandan teyit et.'
         end ||
         case when cp.condition_type in ('segment','min_spend','campaign','tier_and_spend')
              then ' ' || coalesce(cp.condition_note,'Hak segmente/kampanyaya bagli olabilir.')
              else '' end,
         coalesce(cp.source_url, i.self_check_url, '')
    from host_entitlements he
    join lounge_card_products cp on cp.id = he.card_product_id
    join lounge_issuers i on i.id = cp.issuer_id
   where he.user_id = coalesce(p_user_id, auth.uid());
$$;
grant execute on function public.card_self_check(uuid) to authenticated;


-- ============================================================
-- 5) DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_issuers)                                    as ihraccilar,
       (select count(*) from lounge_card_products)                              as kart_urunleri,
       (select count(*) from lounge_card_products where confidence='verified')  as dogrulanmis,
       (select count(*) from lounge_card_products where confidence='secondary') as ikincil_kaynak,
       (select count(*) from lounge_card_products where confidence='unknown')   as bilinmeyen;

select i.name as banka, cp.name as kart, p.code as ag,
       coalesce(cp.quota_total::text,'?') || '/' || coalesce(cp.quota_period,'?') as kota,
       cp.guest_consumes_quota as misafir_kotadan_duser,
       cp.condition_type, cp.confidence
  from lounge_card_products cp
  join lounge_issuers i on i.id = cp.issuer_id
  left join lounge_programs p on p.id = cp.program_id
 order by cp.confidence, i.name, cp.name;

select * from public.entitlement_health() order by agirlik, alan limit 60;

select '088 OK - kart katalogu + kosul/kampanya boyutu, app ETKILENMEDI' as sonuc;
