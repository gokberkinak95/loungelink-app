-- ============================================================
-- 214 · MİSAFİR HAKKI KAYNAĞA GÖRE DEĞİŞİR
-- 17 Ağustos 2026
--
-- 🔴 GÖKBERK'İN CÜMLESİ, BU DOSYANIN TAMAMININ SEBEBİ:
--   "Aynı IST'deki lounge'a hem THY statüsü ile hem LoungeKey ile hem
--    Priority Pass ile hem de DragonPass ile girebiliyor olabilirsin.
--    Sadece yanındaki misafir hakkı (ücretli mi ücretsiz mi ya da içeri
--    birini alamıyor musun gibi) KULLANDIĞIN KAYNAĞA GÖRE DEĞİŞEBİLİR.
--    Bu tarz caseleri göz ardı etme."
--
-- Bu, LoungeLink'in TEK cümlesinin ta kendisi. Ürün "bu salona girer
-- misin" sorusunu değil, "MİSAFİRİNLE girer misin, ne kadara" sorusunu
-- cevaplıyor. Salon aynı, cevap kaynağa göre başka.
--
-- ÖLÇÜM (bu turda gelen kaynaklar):
--   · kural tabloları.xlsx içindeki DOKUZ sayfa — sayfalarda hücre
--     yok, 109 GÖMÜLÜ EKRAN GÖRÜNTÜSÜ var (openpyxl boş sanıyordu;
--     dosyayı zip olarak açıp `xl/media`dan çıkardım).
--       thy kural tablosu ....... 7 görsel  (Tablo-1…Tablo-5)
--       miles&smiles ............ 1 görsel
--       a jet ................... 6 görsel
--       pegasus lounge .......... 5 görsel
--       prioritypass ........... 22 görsel  (Kullanım Koşulları, md. 1-94)
--       dragonpass ............. 27 görsel  (Terms & Conditions)
--   · üç ağın Türkiye salon listeleri (29 ekran görüntüsü)
--
-- NE ÖĞRENDİM — ve neyi ÖĞRENEMEDİM:
--   ✔ THY/AJet misafir hakkı kart tipine göre TABLO HÂLİNDE var.
--   ✔ Pegasus'ta misafir hakkı YOK; herkes kişi başı ödüyor, fiyatlar
--     kuruş kuruş yazılı.
--   ✔ PP ve DragonPass'te de misafir hakkı YOK: her ziyaret kişi başı
--     ücretli. DragonPass ayrıca misafiri AYNI UÇUŞA bağlıyor.
--   ✘ PP ve DragonPass'in misafir ÜCRETİ ne kadar — KAYNAKTA YOK.
--     Katalogda 30 EUR ve 36 EUR yazıyordu; ikisinin de dayanağı bu
--     kaynakta YOK. Aşağıda ne yaptığımı yazdım.
-- ============================================================


-- ============================================================
-- (1) UYDURULMUŞ İKİ FİYAT — GERİ ÇEKİLİYOR
-- ============================================================
-- 🔴 Katalogda `lounge_programs.typical_guest_fee` şöyleydi:
--       PRIORITY_PASS → 30 EUR   (source_url: .../membership)
--       DRAGONPASS    → 36 EUR   (source_url: .../plans)
-- Her iki ağın da KENDİ sözleşmesini baştan sona okudum (22 + 27
-- ekran görüntüsü). İkisinde de misafir ücreti tutarı GEÇMİYOR.
-- Bulunan tek para rakamları: PP'de 10 GBP/EUR/USD posta ücreti,
-- DragonPass'te 100 USD sorumluluk tavanı ve %20 gece limuzin farkı.
-- Hiçbiri misafir ücreti değil.
--
-- Üstelik iki sözleşme de fiyatın SÖZLEŞMEDE OLMADIĞINI açıkça yazıyor:
--   PP md.4  : "…Priority Pass veya ödeme kartı sağlayıcısı … tarafından
--               BİLDİRİLEN ORANLAR ve koşullar uyarınca … borçlandırılacaktır."
--   DP 7.15.8: "Dragonpass may amend the Lounge visit charges from time
--               to time … the latest charges listed on the Dragonpass App
--               … shall at all times prevail."
--
-- Yani ücret KARTI VEREN BANKAYA ve plana göre değişiyor. Tek bir sayı
-- yazmak, kullanıcıya kapıda yanlış tutar söylemektir. Sayıyı
-- siliyorum; yerine "değişkendir, bankandan teyit et" cümlesi koyuyorum.
-- Bir sayıyı bilmemek, yanlış sayı yazmaktan iyidir.
update lounge_programs
   set typical_guest_fee   = null,
       guest_fee_currency  = null,
       -- ⚠️ `lounge_programs`ta `guest_fee_note` ya da `conditions` sutunu YOK
       -- (kolonlar: guest_default, guest_flight_coupling, guest_included_count,
       -- member_must_be_present, transferable, guest_needs_boarding_pass,
       -- guest_needs_photo_id, typical_guest_fee, guest_fee_currency,
       -- max_stay_hours, enforcement, fee_payer, notes). Serbest metin `notes`e
       -- yazilir. Sutun adi uydurmanin bedeli 42703 — bu turda ikinci kez.
       notes = coalesce(notes || ' · ', '')
            || '214: katalogdaki tipik misafir ucreti (PP 30 EUR / DragonPass 36 EUR) KAYNAKSIZDI; agin kendi sozlesmesinde tutar gecmiyor, geri cekildi. '
            || 'Misafir ucreti kisi basi ve ziyaret basinadir; TUTAR KARTI VEREN KURUMA ve uyelik planina gore degisir '
            || '(PP md.4 / DragonPass 7.15.8). Guncel tutar agin uygulamasinda ve banka sozlesmendedir.'
 where code in ('PRIORITY_PASS','DRAGONPASS');


-- ============================================================
-- (2) ÜÇ AĞIN MİSAFİR KURALI — SÖZLEŞMEDEN
-- ============================================================
-- Program ekseni: salon bazlı bir istisna yoksa bu geçerli.
--
-- PRIORITY PASS — md.4: "Dinlenme Salonu ve Mağaza ziyaretleri KİŞİ
-- BAŞI ve ZİYARET BAŞI ücrete tabidir. Uygulanabilir olduğunda (Program
-- üyelik planına bağlı olarak), REFAKATÇİ KONUKLAR tarafından yapılan
-- ziyaretler de dahil olmak üzere bu tür tüm ziyaretler … Müşterinin
-- ödeme kartından borçlandırılacaktır."
-- md.6: "Konukların, Müşteri ile AYNI ANDA kaydolması ve … girmesi
-- gerekir."  → misafir ayrı saatte giremiyor ama AYNI UÇUŞ şartı YOK.
-- md.7: "kendi Program üyeliğine sahip olabilecek konuklardan ücret
-- alınmamasını sağlamak her bir Müşterinin sorumluluğundadır."
update lounge_programs
   set guest_default          = 'paid',
       guest_included_count   = 0,
       guest_flight_coupling  = 'any',
       fee_payer              = 'member_card',
       member_must_be_present = true,   -- md.6: konuklar uyeyle AYNI ANDA kaydolmali
       notes = coalesce(notes || ' · ', '')
            || 'Misafir ucretlidir ve ucret UYENIN KARTINDAN tahsil edilir. Misafirin uyeyle AYNI ANDA giris yapmasi gerekir '
            || '(PP md.6). Misafirin kendi Priority Pass uyeligi varsa ayrica ucret alinmaz (md.7). '
            || 'Cocuk politikasi salondan salona degisir (md.13), tek bir yas siniri yoktur.',
       source_url = 'https://www.prioritypass.com/tr/kullanim-kosullari',
       checked_at = date '2026-03-26'   -- sozlesmenin kendi yururluk tarihi (md.2)
 where code = 'PRIORITY_PASS';

-- LOUNGEKEY — Collinson'un banka markali surumu. Kendi kosullar
-- sayfasini bu turda GORMEDIM; ama LoungeKey'in DIY salon detay sayfasi
-- misafir icin sart yaziyor:
--   "Tum Kart Sahiplerinin VE KONUKLARIN, dinlenme salonunu
--    kullanabilmek icin AYNI GUN icin seyahat onayi bulunan bir BINIS
--    KARTI gostermeleri gerekmektedir."
-- Bu, LoungeLink icin somut bir kural: misafirin kendi ayni gun binis
-- karti olmali. Ucret tarafinda kaynak gormedim → 'paid' varsayimini
-- SURDURUYORUM ama bunu kaynak olarak degil VARSAYIM olarak isaretliyorum.
update lounge_programs
   set guest_default         = 'paid',
       guest_included_count  = 0,
       guest_flight_coupling = 'any',
       fee_payer             = 'member_card',
       guest_needs_boarding_pass = true,   -- DIY salon kosullari: konuklarin da ayni gun binis karti
       notes = coalesce(notes || ' · ', '')
            || 'Misafirin KENDI ayni gun binis karti olmalidir (LoungeKey salon kosullari). Ucret kisi basi ve ziyaret basinadir; '
            || 'tutar karti veren bankaya gore degisir. DIKKAT: ucretsiz OLMADIGI bilgisi Collinson genel kurgusundan geliyor, '
            || 'LoungeKey''in kendi kosullar sayfasi bu turda okunmadi — banka sozlesmenden teyit et.',
       source_url = 'https://www.loungekey.com/tr/lounge-finder',
       checked_at = date '2026-08-07'
 where code = 'LOUNGEKEY';

-- DRAGONPASS — 🔴 BU AĞIN KURALI LOUNGELINK İÇİN ÖZEL OLARAK ÖNEMLİ.
-- 7.15.7: "Your guests are required to be on the SAME FLIGHT as the
--          Dragonpass Member to enjoy Lounge access using the same
--          Dragonpass Membership."
-- Yani DragonPass'li bir host, BAŞKA UÇUŞA binecek bir misafiri kendi
-- üyeliğiyle içeri alamaz. LoungeLink'te host ve misafir ÇOĞU ZAMAN
-- FARKLI UÇUŞTADIR — bu kural, eşleşmeyi kapıda bozan türden.
-- Bu yüzden `same_flight` yalnız veri değil, kullanıcıya GÖSTERİLMESİ
-- gereken bir uyarı.
-- 7.15.18(g): "You may pre-book up to 5 (five) guests, INCLUDING
--              YOURSELF." → en fazla 4 misafir.
-- 7.15.9: "Lounge maximum stay time varies … (usually 2 [two] hours)".
update lounge_programs
   set guest_default         = 'paid',
       guest_included_count  = 0,
       guest_flight_coupling = 'same_flight',
       fee_payer             = 'member_card',
       max_stay_hours        = 2,
       member_must_be_present = true,   -- 7.15.18-c: uye orada olmali
       notes = coalesce(notes || ' · ', '')
            || 'DIKKAT: DragonPass misafirin UYEYLE AYNI UCUSTA olmasini sart kosuyor (7.15.7). Farkli ucusa binecek bir misafiri '
            || 'DragonPass uyeliginle iceri alamazsin. En fazla 5 kisi (kendin dahil) — yani 4 misafir (7.15.18-g). '
            || 'Her kisi ayri ucretlendirilir; tutar agin uygulamasinda yazar (7.15.8). Azami kalis salondan salona degisir, '
            || 'tipik olarak 2 saat (7.15.9).',
       source_url = 'https://www.dragonpass.com/terms-of-use',
       checked_at = date '2026-03-27'   -- "Last updated: 27/03/2026"
 where code = 'DRAGONPASS';

-- Salon satırlarına da işlensin (program varsayılanı yalnız boşluğu
-- doldurur; salon satırı doluysa o kazanır — bu yüzden ikisi de doğru olmalı).
update lounge_venue_acceptance a
   set guest_policy          = 'paid',
       guest_included_count  = 0,
       guest_fee_amount      = null,          -- kaynakta tutar yok
       guest_fee_currency    = null,
       guest_flight_coupling = case when p.code = 'DRAGONPASS' then 'same_flight' else 'any' end,
       fee_payer             = 'member_card',
       max_stay_hours        = case when p.code = 'DRAGONPASS' then 2 else a.max_stay_hours end,
       guest_fee_note        = 'Misafir ucretlidir; tutar karti veren kuruma ve plana gore degisir. Agin kendi sozlesmesinde tutar yazmiyor.',
       children_note         = case
         when p.code = 'DRAGONPASS' then 'Bazi salonlar belirli yasin altindaki cocuklardan ucret almaz; karari SALON verir (DragonPass 7.15.18-g).'
         else 'Cocuk kabulu ve ucreti salondan salona degisir; tek bir yas siniri yoktur (PP md.13).' end,
       updated_at            = now()
  from lounge_programs p
 where p.id = a.program_id
   and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   and a.accepted and a.active;

-- LoungeKey'in DIY salonundaki İKİ SOMUT SAYI — kaynağı olan tek satır.
-- "Maksimum kalis suresi 3 saattir." · "6 yasindan kucuk cocuklar ucretsiz"
update lounge_venue_acceptance a
   set max_stay_hours = 3,
       children_note  = '6 yasindan kucuk cocuklar ucretsiz kabul edilmektedir (LoungeKey salon kosullari).',
       conditions     = coalesce(a.conditions || ' · ', '')
                     || 'Kara tarafi: salon ana terminal binasinin YANINDA ayri bir binadadir, disaridan ayri bir kapidan girilir. Yalnizca ic hat ucuslari.',
       source_url     = 'https://www.loungekey.com/tr/lounge-finder',
       updated_at     = now()
  from lounge_programs p, lounge_venues v
 where p.id = a.program_id and v.id = a.venue_id
   and p.code = 'LOUNGEKEY' and v.airport_code = 'DIY';


-- ============================================================
-- (3) PEGASUS — MİSAFİR HAKKI YOK, FİYATLAR KURUŞU KURUŞUNA VAR
-- ============================================================
-- Pegasus sayfalarinda kart/statu kademesi HIC YOK. "Misafir hakki"
-- diye bir kavram da yok: giren herkes kisi basi oduyor.
--   "Plaza Premium Lounge / Ic Hatlar : 49 Euro"
--   "Plaza Premium Lounge / Dis Hatlar : 63 Euro"
--   "Ic Hat Celebi Platinum Lounge = 1260 TL (KDV Dahil)"
--   "Dis Hat Celebi Platinum Lounge = 49,5 EUR (KDV Dahil)"
--   "Ayrica yetiskin yaninda gelen 6 yasina kadar olan cocuklardan
--    ucret alinmayacaktir."
--   "Lounge kullanim suresi 3 saat ile sinirlidir."
update lounge_programs
   set guest_default         = 'paid',
       guest_included_count  = 0,
       fee_payer             = 'guest_at_door',
       max_stay_hours        = 3,
       guest_needs_boarding_pass = true,
       notes = coalesce(notes || ' · ', '')
            || 'Pegasus''ta misafir HAKKI yoktur: giren herkes kisi basi oder ve odeme KAPIDA yapilir (binis kartini gostererek). '
            || 'Ucret ic hat / dis hat ve salona gore degisir. 6 yasina kadar cocuklardan ucret alinmaz (Plaza Premium ve Celebi); '
            || 'Primeclass/HelloSky salonlarinda bu sinir 0-2 yastir. Kullanim suresi 3 saat.',
       source_url = 'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge',
       checked_at = date '2026-08-07'
 where code = 'PGS_PAID';

-- Salon bazlı Pegasus ücretleri — YALNIZ kaynakta yazan salonlara.
do $$
declare r record; v_n int := 0;
begin
  for r in select * from (values
      ('SAW','plaza',        'domestic',      49.0::numeric, 'EUR', 'Plaza Premium Lounge / Ic Hatlar : 49 Euro'),
      ('SAW','plaza-marmara','international', 63.0,   'EUR',  'Plaza Premium Lounge / Dis Hatlar : 63 Euro'),
      ('SAW','plaza-bosphorus','international',63.0,  'EUR',  'Plaza Premium Lounge / Dis Hatlar : 63 Euro'),
      ('COV','celebi-platinum','domestic',    1260.0, 'TRY',  'Ic Hat Celebi Platinum Lounge = 1260 TL (KDV Dahil)'),
      ('COV','celebi-platinum','international',49.5,  'EUR',  'Dis Hat Celebi Platinum Lounge = 49,5 EUR (KDV Dahil)'),
      ('ADB','primeclass',   null::text,      27.0,   'EUR',  'Primeclass/HelloSky: 27 EUR + KDV'),
      ('ESB','primeclass',   null,            27.0,   'EUR',  'Primeclass/HelloSky: 27 EUR + KDV'),
      ('BJV','primeclass',   null,            27.0,   'EUR',  'Primeclass/HelloSky: 27 EUR + KDV')
    -- ⚠️ Takma ad listesinde TIP YAZILMAZ: `as t(ap text, ...)` sozdizimi
    -- hatasi verir (42601). Tip bildirimi yalniz json_to_record gibi
    -- kayit donduren fonksiyonlarda gecerlidir. Tipler VALUES icinde
    -- cast ile veriliyor.
    ) as t(ap, marka, kapsam, ucret, para, alinti)
  loop
    update lounge_venue_acceptance a
       set guest_fee_amount   = r.ucret,
           guest_fee_currency = r.para,
           guest_fee_note     = 'Pegasus yolcusuna ozel indirimli fiyat: ' || r.alinti
                             || '. Misafir HAKKI degildir — misafir de ayni tutari kapida oder.',
           max_stay_hours     = 3,
           children_note      = case when r.marka = 'primeclass'
                                     then '0-2 yas arasi cocuk misafirlerden ucret alinmamaktadir.'
                                     else 'Yetiskin yaninda gelen 6 yasina kadar cocuklardan ucret alinmaz.' end,
           source_url         = 'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge',
           checked_at         = date '2026-08-07',
           updated_at         = now()
      from lounge_programs p, lounge_venues v
     where p.id = a.program_id and v.id = a.venue_id
       and p.code = 'PGS_PAID'
       and v.airport_code = r.ap
       and public.cns_brand(v.name) = r.marka
       and (r.kapsam is null or coalesce(v.scope,'both') in (r.kapsam,'both'))
       and a.accepted and a.active;
    v_n := v_n + 1;
  end loop;
  raise notice '214: Pegasus fiyati % kural satiri icin islendi', v_n;
end $$;


-- ============================================================
-- (4) THY / AJET — MİSAFİR HAKKI KART TİPİNE GÖRE (Tablo-1…Tablo-5)
-- ============================================================
-- Kural motorunun kart tipi ekseni `lounge_guest_rules`ta zaten var.
-- Bu bölüm ONU DEĞİŞTİRMİYOR; kaynakta bulunan ve katalogda EKSİK olan
-- iki şeyi ekliyor:
--   (a) TAŞIYICI BAĞI — 266 TK_MS satırında `guest_flight_coupling` BOŞ.
--   (b) İki somut salon istisnası.

-- (a) 🔴 "17. THY seferinde seyahat eden yolcu, SADECE THY seferinde
--     seyahat eden yolcuyu misafir olarak salona davet edebilir.
--     AJet seferinde seyahat eden yolcuyu misafir olarak davet EDEMEZ."
--     Ve aynasi: "AJet seferinde seyahat eden yolcunun misafiri, THY
--     seferinde seyahat eden yolcu ise; salona ucretsiz girisi kabul
--     edilmemektedir."
--
-- LoungeLink icin bu, kapida reddedilmenin en olasi sebeplerinden biri:
-- host THY ile ucuyor, misafir AJet ile — ikisi de "ayni havalimani,
-- ayni saat" diye eslesiyor ama kart hakki gecmiyor. Veride 266 satirda
-- bu bag BOSTU, yani motor "any" varsayiyordu.
update lounge_venue_acceptance a
   set guest_flight_coupling = 'same_carrier',
       conditions = coalesce(a.conditions || ' · ', '')
                 || 'Misafirin AYNI HAVAYOLUYLA seyahat etmesi gerekir: THY yolcusu yalnizca THY yolcusunu, AJet yolcusu yalnizca AJet '
                 || 'yolcusunu misafir edebilir. Capraz davet kapida ucretsiz kabul edilmez.',
       updated_at = now()
  from lounge_programs p
 where p.id = a.program_id
   and p.code in ('TK_MS','AJET_MS')
   and a.accepted and a.active
   and a.guest_flight_coupling is null;

-- (b1) DALAMAN ve DİYARBAKIR — THY markalı OLMAYAN CIP salonları
-- "M&S Elite Corporate Card sahibi yolcular … Turkiye icinde Dalaman ve
--  Diyarbakir Havalimanlarindaki Turkish Airlines Lounge OLMAYAN CIP
--  salonlarindan ise SADECE 1 MISAFIR davetlileri olacak sekilde
--  faydalanabilir."
-- "Dalaman ve Diyarbakir Havalimanlarindaki Ozel Yolcu Salonlari HARIC
--  olmak uzere ucretsiz"  (M&S U.S. Kredi Karti)
update lounge_venue_acceptance a
   set conditions = coalesce(a.conditions || ' · ', '')
                 || 'DALAMAN/DIYARBAKIR ISTISNASI: bu salon Turkish Airlines Lounge markali DEGILDIR. Miles&Smiles Elite Corporate kart '
                 || 'sahibi burada AILE hakkini kullanamaz, yalnizca 1 MISAFIR goturebilir. Miles&Smiles ABD Kredi Karti bu iki '
                 || 'havalimaninda gecerli DEGILDIR.',
       enforcement = 'warn',
       source_url  = coalesce(a.source_url, 'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'),
       updated_at  = now()
  from lounge_programs p, lounge_venues v
 where p.id = a.program_id and v.id = a.venue_id
   and p.code = 'TK_MS'
   and v.airport_code in ('DLM','DIY')
   and v.name not ilike '%turkish airlines%'
   and a.accepted and a.active;

-- (b2) İSTANBUL DIŞ HAT — Business bölümünde misafir hakkı YOK
-- "Lounge Business bolumune girişte MISAFIR/AILE HAKKI BULUNMADIGINDAN,
--  uygun kart tipine sahip Business Class yolcular … Lounge Miles&Smiles
--  bolumune girmelidir."
-- Bu, ürünün en somut yönlendirme cümlelerinden biri: host'u DOĞRU
-- BÖLÜME göndermezsek misafir kapıda kalır.
update lounge_venue_acceptance a
   set guest_policy = 'not_allowed',
       guest_included_count = 0,
       enforcement  = 'block',
       conditions   = coalesce(a.conditions || ' · ', '')
                   || 'ISTANBUL DIS HAT · BUSINESS BOLUMU: bu bolumde misafir/aile hakki YOKTUR. Misafirinle girmek istiyorsan '
                   || 'Turkish Airlines Lounge MILES&SMILES bolumune gitmelisin — kart tipinin verdigi misafir hakki orada gecerlidir.',
       source_url   = 'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
       updated_at   = now()
  from lounge_programs p, lounge_venues v
 where p.id = a.program_id and v.id = a.venue_id
   and v.airport_code = 'IST'
   and v.name ilike '%dış hat%' and v.name ilike '%business%'
   and p.code in ('TK_MS','BUSINESS_TICKET','STAR_GOLD')
   and a.accepted and a.active;

-- (b3) CHARTER SEFERİ — statü kartı olsa bile salon hakkı yok
-- "16. Charter seferde seyahat eden yolcunun Business Class bileti veya
--      statu karti olsa dahi, salon kullanim hakki bulunmaz."
insert into beta_settings (key, value)
values ('charter_lounge_hakki', '"no"')
on conflict (key) do update set value = excluded.value;


-- ============================================================
-- (5) İNCELEME KUYRUĞUNDAKİ 8 SALON — KARARA BAĞLANIYOR
-- ============================================================
-- 211 bu sekizini "kaynaksiz birlestirme yapmam" diyerek kuyruğa
-- almıştı. Bu turda gelen kaynaklarla altısı KARARA BAĞLANABİLİYOR.
-- Kural aynı: birleştirme yalnız İKİ BAĞIMSIZ KAYNAK aynı sayıyı
-- söylüyorsa. Ama artık elimde üç ağın TAM SAYIM'ı var:
--   PP    IST 8 deneyim · SAW 4 · AYT 2 · ESB 2 · ADB 2 · BJV 2 · DLM 2 · DIY 1 · COV 2
--   LK    IST 8 kart    · SAW 4 · AYT 3 · ESB 2 · ADB 2 · BJV 2 · DLM 2 · DIY 1 · COV 2
--   DP    IST 5 lounge  · SAW 4 · AYT 2 · ESB 2 · ADB 2 · BJV 2 · DLM 2 · DIY 1 · COV 2
-- Sayaçlar ağların KENDİ sayfa başlığından okundu ve kart sayısıyla
-- birebir uyuştu (carousel iki ekran görüntüsüyle sonuna kadar sayıldı).

-- (5a) AYT · "Antalya Airport CIP Lounge" (scope=both, terminal="T1 International")
-- LoungeKey AYT'de terminal başlıklarıyla listeliyor:
--     Dis Hatlar Terminali 1 → ELITE LOUNGE
--     Dis Hatlar Terminali 2 → CIP Lounge (Dis Hatlar)
--     Ic Hatlar Terminali    → CIP Lounge (Ic Hatlar)
-- Priority Pass AYT'de: CIP Lounge Domestic (Domestic Terminal 3) +
--                       Comfort Lounge (International Terminal 2)
-- İKİ BAĞIMSIZ KAYNAK da AYT T1 dış hatta ELITE LOUNGE diyor; ikisi de
-- T1'de bir CIP salonu listelemiyor. Bu kayıt Elite'in eski adı.
do $$
declare v_eski uuid; v_hedef uuid;
begin
  select id into v_eski  from lounge_venues where active and airport_code='AYT' and name='Antalya Airport CIP Lounge';
  select id into v_hedef from lounge_venues where active and airport_code='AYT' and name='Elite Lounge — Dış Hat (T1)';
  if v_eski is not null and v_hedef is not null then
    perform public.cns_merge_venue(v_eski, v_hedef,
      'LoungeKey AYT T1 dis hatta ELITE LOUNGE listeliyor; PP de T1''de CIP listelemiyor. Terminal jetonu (T1) ve kapsam ayni.');
    update venue_review_queue set durum='birlestirildi', karar_at=now() where venue_id=v_eski;
    raise notice '214: AYT "Antalya Airport CIP Lounge" → "Elite Lounge — Dis Hat (T1)"';
  end if;
end $$;

-- (5b) AYT · "Antalya Havalimanı dış hatlar özel yolcu salonu (FTA CIP Salonları)"
-- Bu bir ODA DEĞİL. THY kural tablosunun ŞEMSİYE ifadesi: "ucus
-- operasyonunun yapildigi terminaldeki FTA CIP salonlari". Katalogda
-- artık kesin odalar var (Elite T1, CIP T2, Comfort T2, CIP T3).
-- Host'a seçim ekranında gösterilirse "hangi oda" belirsiz kalır.
-- SİLMİYORUM — THY kural satırı ona bağlı. ŞEMSİYE olarak işaretliyorum
-- ve host seçiminden düşürüyorum.
alter table lounge_venues add column if not exists is_umbrella boolean not null default false;
comment on column lounge_venues.is_umbrella is
  '214: bu kayit fiziksel bir ODA degil, kural tablosundaki semsiye ifade. Host secim ekraninda gosterilmez, kart agi eslestirmesine girmez.';

update lounge_venues
   set is_umbrella = true,
       notes = coalesce(notes || ' · ', '')
            || '214: SEMSIYE KAYIT. THY kural tablosunun "ucus operasyonunun yapildigi terminaldeki FTA CIP salonlari" ifadesi. '
            || 'Fiziksel oda degil; AYT''nin kesin odalari ayri kayitlarda (Elite T1, CIP T2, Comfort T2, CIP T3).'
 where active and airport_code='AYT'
   and name like 'Antalya Havalimanı dış hatlar özel yolcu salonu%';
update venue_review_queue q set durum='kapali', karar_at=now()
  from lounge_venues v where v.id=q.venue_id and v.is_umbrella;

-- (5c) IST · SAW · AYT "Primeclass Lounge" — ÜÇ AĞ DA LİSTELEMİYOR
-- IST: PP 8 deneyimin hepsi iGA/XpresSpa; LK 8 kartin hepsi iGA/XpresSpa;
--      DP 5 lounge'un hepsi iGA. Primeclass YOK.
-- SAW: uc agin ucu de 4 tesis sayiyor: Kepler + 3 Plaza Premium. Primeclass YOK.
-- AYT: PP 2, LK 3, DP 2 — hicbirinde Primeclass YOK.
-- Ayrica Pegasus'un KENDI Primeclass fiyat listesi yalnizca
-- BJV / ADB / ESB (+ yurt disi) diyor; IST, SAW, AYT yok.
--
-- Yani DORT BAGIMSIZ KAYNAK bu uc havalimanini tam sayiyor ve hicbiri
-- Primeclass gormuyor. Primeclass TAV markasidir; IST iGA, SAW ISG
-- isletmesidir. Bu kayitlar buyuk olasilikla Ataturk donemi artigi.
-- SILMIYORUM — pasife aliyorum ve sebebini yaziyorum.
do $$
declare r record; v_n int := 0;
begin
  for r in select v.id, v.airport_code, v.name from lounge_venues v
            where v.active and v.airport_code in ('IST','SAW','AYT')
              and public.cns_brand(v.name) = 'primeclass'
  loop
    update lounge_venue_acceptance set accepted=false, active=false,
           guest_fee_note = coalesce(guest_fee_note || ' · ','')
             || '214: salon dort bagimsiz kaynakta listelenmiyor; kabul satiri geri cekildi.'
     where venue_id = r.id;
    update lounge_venues
       set active = false,
           name = name || ' (214 kaynaksız → pasif)',
           notes = coalesce(notes || ' · ','')
             || format('214: %s havalimanini PP/LoungeKey/DragonPass TAM SAYIYOR ve ucu de Primeclass listelemiyor; '
                     || 'Pegasus''un kendi Primeclass fiyat listesi de yalniz BJV/ADB/ESB diyor. Primeclass TAV markasi, '
                     || 'bu havalimani baska isletmede. Buyuk olasilikla Ataturk donemi artigi — SILINMEDI, pasife alindi.', r.airport_code)
     where id = r.id;
    update venue_review_queue set durum='kapali', karar_at=now() where venue_id = r.id;
    v_n := v_n + 1;
  end loop;
  raise notice '214: % kaynaksiz Primeclass kaydi pasife alindi (IST/SAW/AYT)', v_n;
end $$;

-- (5c-2) 🔴 SALONU PASİFE ALMAK, O SALONDAKİ İLANLARI ÖKSÜZ BIRAKIR
-- Bunu yukarıdaki blok çalıştıktan SONRA ölçtüm ve gördüm: pasife
-- alınan üç Primeclass kaydına bağlı ilanlar duruyordu ve
-- `pick_host_program` onlar için null dönüyordu — yani host'un ilanı
-- sessizce "programsız" hâle gelmişti.
--
-- ÜRÜN KARŞILIĞI: host bir ilan açmış, ilan ekranında duruyor, ama
-- artık hiçbir misafir eşleşmesi üretmiyor ve host bunu HİÇ ÖĞRENMİYOR.
-- Katalog temizliği yaparken kullanıcının açtığı ilanı sessizce
-- öldürmek, bu projede en pahalı hata sınıfının (sessiz atlama) canlı
-- kullanıcıya yansıyan biçimi.
--
-- KURAL: bir salon pasife alınıyorsa, ona bağlı ilan ya TAŞINIR ya da
-- KAPATILIR VE HOST'A HABER VERİLİR. Sessiz üçüncü seçenek yok.
do $$
declare r record; v_yeni uuid; v_tasindi int := 0; v_kapandi int := 0;
begin
  for r in
    select a.id, a.host_id, a.lounge_id, a.airport_code, a.avail_date, v.name salon_adi, v.airport_code ap
      from availabilities a
      join lounges l on l.id = a.lounge_id
      join lounge_venues v on v.id = l.venue_id
     where a.active and not v.active
  loop
    -- Aynı havalimanında aynı markadan AKTİF bir salon var mı?
    select l2.id into v_yeni
      from lounges l2 join lounge_venues v2 on v2.id = l2.venue_id
     where l2.active and v2.active and not v2.is_umbrella
       and v2.airport_code = r.ap
       and public.cns_brand(v2.name) = public.cns_brand(r.salon_adi)
     order by v2.id limit 1;

    if v_yeni is not null then
      update availabilities set lounge_id = v_yeni where id = r.id;
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.host_id, 'system', 'İlanın başka bir salona taşındı',
              format('%s kaydı katalogdan kaldırıldı (kaynaklarda listelenmiyor). İlanın aynı havalimanındaki geçerli salona taşındı.', r.salon_adi),
              'availability', r.id);
      v_tasindi := v_tasindi + 1;
    else
      update availabilities set active = false where id = r.id;
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.host_id, 'system', 'İlanın kapatıldı — salon katalogdan kaldırıldı',
              format('"%s" salonu Priority Pass, LoungeKey ve DragonPass''in kendi Türkiye listelerinde YER ALMIYOR; '
                  || 'Pegasus''un fiyat listesinde de yok. Yanlış yere misafir göndermemek için kaydı pasife aldık ve '
                  || 'ilanını kapattık. Aynı havalimanında başka bir salonda ilan açabilirsin.', r.salon_adi),
              'availability', r.id);
      v_kapandi := v_kapandi + 1;
    end if;
  end loop;
  raise notice '214: pasif salona bagli ilan → % tasindi, % kapatildi (host''a bildirim yazildi)', v_tasindi, v_kapandi;
end $$;


-- (5d) ESB "Anatolia Lounge" ve SAW "Aeroport Lounge"
-- Bu ikisi icin karar FARKLI olmali. Bir salonun kart agi anlasmasi
-- olmamasi, salonun YOK oldugu anlamina gelmez — bu ayrimi 211'de de
-- yazmistim ve hala dogru. Ama KAYNAKSIZ KABUL SATIRI baska bir sey:
-- ikisinde de TK_MS ve PGS_PAID kabul satiri var, oysa
--   · THY kural tablolari kendi salonlarini sayiyor, ikisi de yok,
--   · Pegasus'un kendi fiyat listesi ikisini de icermiyor.
-- Salonu birakiyorum, KAYNAKSIZ IDDIAYI geri cekiyorum.
update lounge_venue_acceptance a
   set accepted = false, active = false,
       guest_fee_note = coalesce(a.guest_fee_note || ' · ','')
         || '214: ne THY kural tablosunda ne Pegasus fiyat listesinde bu salon geciyor; kaynaksiz kabul satiri geri cekildi. '
         || 'Salon kaydi DURUYOR — anlasma yoklugu salonun yoklugu degildir.',
       updated_at = now()
  from lounge_venues v, lounge_programs p
 where v.id = a.venue_id and p.id = a.program_id
   and v.active
   and ((v.airport_code='ESB' and v.name='Anatolia Lounge')
     or (v.airport_code='SAW' and v.name='Aeroport Lounge'))
   and p.code in ('TK_MS','PGS_PAID')
   and a.accepted and a.active;
update venue_review_queue q set durum='ayri_salon', karar_at=now(),
       gerekce = gerekce || ' · 214 KARARI: salon kaydi korunuyor (anlasma yoklugu salonun yoklugu degildir), '
                         || 'ama kaynaksiz TK_MS/PGS_PAID kabul satirlari geri cekildi.'
  from lounge_venues v
 where v.id = q.venue_id
   and ((v.airport_code='ESB' and v.name='Anatolia Lounge') or (v.airport_code='SAW' and v.name='Aeroport Lounge'));

-- (5e) DLM "DLM Lounge — Terminal 2" — AYRI SALON, kanitli.
-- DragonPass Dalaman sayfasi IKI AYRI kart gosteriyor: "CIP Lounge" ve
-- "DLM Lounge". Ayni sayfada ayri kart = ayri tesis.
update venue_review_queue q set durum='ayri_salon', karar_at=now(),
       gerekce = gerekce || ' · 214 KARARI: DragonPass Dalaman sayfasi "CIP Lounge" ve "DLM Lounge"u AYRI KART olarak gosteriyor. Ayri salon.'
  from lounge_venues v where v.id=q.venue_id and v.airport_code='DLM' and v.name like 'DLM Lounge%';


-- ============================================================
-- (6) SAW PLAZA PREMIUM MÜKERRERİ — ÇÖZÜLDÜ
-- ============================================================
-- 211'de DragonPass'in iki "Marmara" karti (ad sirasi farkli) tek
-- salona cakisiyordu ve mukerrer olarak isaretlenmisti.
-- Bu turda sayimla cozuldu:
--   DragonPass SAW sayac: "4 lounges" · kartlar: Kepler Club +
--     Plaza Premium Marmara Lounge + Plaza Premium Lounge Marmara +
--     Plaza Premium Lounge   → 4 kart, sayacla birebir.
--   PP SAW  : "4 Deneyimler" → Marmara(int) + Bosphorus(int) + Plaza Premium(dom) + Kepler(int)
--   LoungeKey SAW: Kepler(dis) + Bosphorus(dis) + Marmara(dis) + Plaza Premium(ic)
-- IKI BAGIMSIZ KAYNAK SAW'da UC Plaza Premium odasi sayiyor
-- (Bosphorus, Marmara, ic hat). DragonPass da UC Plaza karti gosteriyor.
-- Yani DragonPass'in iki "Marmara" kartindan biri aslinda BOSPHORUS —
-- ag kendi kartini yanlis adlandirmis (ayni sayfada mukerrer tanim
-- yazan bir ag: DragonPass sozlesmesinde 2.1.4 ve 2.1.5 ayni tanimi
-- iki kez veriyor; veri hijyeni boyle).
--
-- SAYI DENKLIGI: 3 Plaza karti ↔ 3 Plaza odasi. Ucunu de isaretliyorum.
do $$
declare v_bos uuid; v_mar uuid; v_ic uuid; v_dp uuid; v_hedef uuid; v_n int := 0;
begin
  select id into v_dp  from lounge_programs where code='DRAGONPASS';
  select id into v_bos from lounge_venues where active and airport_code='SAW' and name ilike '%bosphorus%';
  select id into v_mar from lounge_venues where active and airport_code='SAW' and name ilike '%marmara%';
  select id into v_ic  from lounge_venues where active and airport_code='SAW' and name='Plaza Premium Lounge — İç Hat';
  if v_dp is null then raise exception '214: DRAGONPASS programi yok'; end if;

  -- ⚠️ Donguyu KENDI kaynak degiskeni uzerinde donmuyorum. Ilk yazimda
  -- `foreach v_bos in array array[v_bos, v_mar, v_ic]` yazmistim: dizi
  -- bir kez degerlense de yineleyici v_bos'u eziyor ve gövde artik
  -- "Bosphorus" degil "o anki eleman" oluyor. Calisir ama okuyan yanilir.
  foreach v_hedef in array array[v_bos, v_mar, v_ic] loop
    if v_hedef is null then continue; end if;
    insert into lounge_venue_acceptance
      (venue_id, program_id, accepted, guest_policy, guest_included_count, guest_flight_coupling,
       fee_payer, max_stay_hours, source_url, checked_at, active, is_placeholder, conditions)
    values (v_hedef, v_dp, true, 'paid', 0, 'same_flight', 'member_card', 2,
            'https://www.dragonpass.com/airport-lounges', date '2026-08-07', true, false,
            'DragonPass Sabiha Gokcen sayfasi "4 lounges" diyor ve UC Plaza Premium karti gosteriyor; PP ile LoungeKey de SAW''da '
         || 'UC Plaza Premium odasi sayiyor (Bosphorus, Marmara, ic hat). Sayi denkligiyle ucu de kapsamda.')
    on conflict (venue_id, program_id) do update set
      accepted = true, active = true, is_placeholder = false,
      guest_policy = 'paid', guest_flight_coupling = 'same_flight',
      source_url = excluded.source_url, checked_at = excluded.checked_at,
      conditions = excluded.conditions, updated_at = now();
    v_n := v_n + 1;
  end loop;

  update card_network_source
     set match_note = replace(coalesce(match_note,''), 'MUKERRER', 'COZULDU (214: sayi denkligi)')
   where network='DRAGONPASS' and airport='SAW';
  raise notice '214: SAW Plaza Premium — DragonPass % odaya baglandi (mukerrer cozuldu)', v_n;
end $$;


-- ============================================================
-- (7) BEKLEYEN İKİ DRAGONPASS SATIRI — ÜÇÜNCÜ YOL
-- ============================================================
-- DRAGONPASS · AYT · "CIP Lounge"  → katalogda CIP T2(dis) + CIP T3(ic)
-- DRAGONPASS · DLM · "CIP Lounge"  → katalogda CIP T2(dis) + CIP T2(ic)
-- DragonPass sayfalari terminal de kapsam da YAZMIYOR ve sayaci
-- ("2 lounges") kartlarla birebir tutuyor — yani ag gercekten TEK bir
-- CIP odasi tasiyor, hangisi oldugunu soylemiyor.
--
-- UC SECENEK VARDI:
--   (a) ikisini de kabul yaz  → biri FAZLA IDDIA, misafir kapida doner
--   (b) ikisini de bos birak  → gercek bir kapsami URUNDEN SILER
--   (c) ikisini de kabul yaz AMA "hangisi belirsiz" uyarisiyla
-- (a) ve (b) ikisi de kullaniciya yalan soyluyor. (c) kaynagin
-- SOYLEDIGI kadarini soyluyor: "DragonPass burada bir CIP salonu
-- kapsiyor, hangisi oldugunu kendisi yazmiyor — kapida teyit et."
-- `enforcement='warn'` bu cumleyi karar ciktisina tasiyor.
do $$
declare r record; v_dp uuid; v_n int := 0;
begin
  select id into v_dp from lounge_programs where code='DRAGONPASS';
  for r in
    select v.id, v.airport_code, v.name
      from lounge_venues v
     where v.active and not v.is_umbrella
       and v.airport_code in ('AYT','DLM')
       and public.cns_brand(v.name) = 'cip'
       and coalesce(v.venue_kind,'lounge') = 'lounge'
  loop
    insert into lounge_venue_acceptance
      (venue_id, program_id, accepted, guest_policy, guest_included_count, guest_flight_coupling,
       fee_payer, max_stay_hours, enforcement, source_url, checked_at, active, is_placeholder, conditions)
    values (r.id, v_dp, true, 'paid', 0, 'same_flight', 'member_card', 2, 'warn',
            'https://www.dragonpass.com/airport-lounges', date '2026-08-07', true, false,
            format('KAYNAK BELIRSIZ: DragonPass %s sayfasinda TEK bir "CIP Lounge" karti var ve terminal/ic-dis hat bilgisi YAZMIYOR. '
                || 'Katalogda bu markadan iki oda var; hangisinin kapsandigi kaynaktan okunamiyor. Gitmeden once DragonPass '
                || 'uygulamasindan salonu dogrula.', r.airport_code))
    on conflict (venue_id, program_id) do update set
      enforcement = 'warn', conditions = excluded.conditions,
      source_url = excluded.source_url, checked_at = excluded.checked_at, updated_at = now();
    v_n := v_n + 1;
  end loop;

  update card_network_source
     set venue_id = (select v.id from lounge_venues v
                      where v.active and not v.is_umbrella and v.airport_code = card_network_source.airport
                        and public.cns_brand(v.name)='cip' and coalesce(v.venue_kind,'lounge')='lounge'
                      order by v.scope, v.id limit 1),
         match_note = 'K6 kaynak belirsiz — iki oda da uyarili kapsamda'
   where network='DRAGONPASS' and airport in ('AYT','DLM') and venue_id is null;
  raise notice '214: bekleyen DragonPass CIP satirlari uyarili kapsama alindi (% oda)', v_n;
end $$;


-- ============================================================
-- (8) ÖLÜ TETİKLEYİCİ FONKSİYONU — pg_run''un son uyarisi
-- ============================================================
-- `founding_badge_sync()` 162'de yazildi ama baglama blogu
-- `if to_regclass('public.founding_hosts') is not null` kosuluna sarili
-- ve o tablo HIC VAR OLMADI → tetikleyici sessizce kurulmadi.
-- Bugun zararsiz, cunku `claim_founding_host` `profiles.founding_host_no`u
-- zaten kendisi yaziyor. Yani fonksiyon OLU KOD.
-- Silmiyorum (bu projede silme yasak); ADINI ve aciklamasini degistirip
-- "kullanilmiyor" diye isaretliyorum ki nobetci dogru sinifta saysin.
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='founding_badge_sync')
     and not exists (select 1 from pg_trigger where tgfoid = 'public.founding_badge_sync'::regproc)
  then
    comment on function public.founding_badge_sync() is
      '214 · KULLANILMIYOR. 162 bu fonksiyonu yazdi ama tetikleyiciyi `founding_hosts` tablosu varsa diye sarmisti; o tablo hic '
      'olusmadi. Kurucu rozet numarasini `claim_founding_host` dogrudan `profiles.founding_host_no`ya yaziyor. Silinmedi: '
      'ileride founding_hosts tablosu acilirsa hazir duruyor.';
    raise notice '214: founding_badge_sync olu kod olarak etiketlendi';
  end if;
end $$;


-- ============================================================
-- (9) HOST SEÇİMİ ŞEMSİYE KAYIT GÖRMESİN
-- ============================================================
-- `is_umbrella` sadece bir bayrak olarak kalirsa hicbir sey degismez
-- (hata sinifi 18: tanimli olmak cagrilmak degildir). Katalog gorunumu
-- ve kart agi eslestirmesi ikisi de bunu OKUMALI.
create or replace function public.cns_adaylar(
  p_airport text, p_brand text, p_kind text, p_scopes text[])
returns uuid[] language sql stable as $fn$
  select coalesce(array_agg(v.id order by coalesce(v.scope,'both'), v.id), '{}'::uuid[])
    from lounge_venues v
   where v.active
     and not v.is_umbrella                     -- 214
     and v.airport_code = p_airport
     and public.cns_brand(v.name) = p_brand
     and coalesce(v.venue_kind,'lounge') = p_kind
     and (p_scopes is null or coalesce(v.scope,'both') = any (p_scopes));
$fn$;

create or replace function public.venue_duplicate_suspects()
returns table (havalimani text, marka text, kapsam text, adet int, adlar text)
language sql stable security definer set search_path = public as $fn$
  select v.airport_code::text, public.cns_brand(v.name), coalesce(v.scope,'both')::text,
         count(*)::int, string_agg(v.name, ' | ' order by v.name)
    from lounge_venues v
   where v.active and coalesce(v.venue_kind,'lounge') = 'lounge'
     and not v.is_umbrella                     -- 214: semsiye kayit mukerrer degildir
   group by v.airport_code, public.cns_brand(v.name), coalesce(v.scope,'both')
  having count(*) > 1;
$fn$;
grant execute on function public.venue_duplicate_suspects() to service_role;

-- Kural motorunun okuduğu kart-ağı görünümü de şemsiyeyi atlasın.
-- ⚠️ SÜTUN EKLİYORUM (`belirsiz`) → `create or replace` YETMEZ:
--     "cannot change return type of existing function"
-- `returns table(...)` OUT parametre satır tipidir; tipi değiştiren her
-- fonksiyonun önüne DROP gerekir. Bu kural `returns_check.py` ile zaten
-- denetleniyordu; ben yine unuttum ve harness yakaladı — nöbetçinin
-- işini yapması tam olarak bu.
drop function if exists public.cns_kapsam_haritasi();
create or replace function public.cns_kapsam_haritasi()
returns table (havalimani text, salon text, tesis_tipi text, kapsam text, aglar text, belirsiz boolean)
language sql stable security definer set search_path = public as $fn$
  select v.airport_code::text, v.name, coalesce(v.venue_kind,'lounge')::text,
         coalesce(v.scope,'both')::text, string_agg(p.code, ', ' order by p.code),
         bool_or(a.enforcement = 'warn' and a.conditions ilike '%KAYNAK BELIRSIZ%')
    from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
    join lounge_venues   v on v.id = a.venue_id
   where a.accepted and a.active and not v.is_umbrella
     and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   group by 1,2,3,4
   order by 1,2;
$fn$;
grant execute on function public.cns_kapsam_haritasi() to service_role;


-- ============================================================
-- (10) MİSAFİR HAKKI KARŞILAŞTIRMA — ÜRÜNÜN ASIL CEVABI
-- ============================================================
-- 🔴 GÖKBERK'İN SORDUĞU ŞEY BU: aynı salona farklı kaynaklarla
-- girilebiliyorsa, MİSAFİR HAKKI hangi kaynakta ne oluyor?
-- Bu fonksiyon bir salon için TÜM kaynakları yan yana koyuyor.
-- Host'un ekranında "hangi kartını kullanmalısın" cevabı budur.
create or replace function public.salon_misafir_karsilastirmasi(p_venue uuid)
returns table (
  program        text,
  program_adi    text,
  misafir_hakki  text,
  ucretsiz_adet  int,
  ucret          text,
  ucusa_bagli    text,
  azami_saat     numeric,
  uyari          text,
  kaynak         text,
  kontrol        date
) language sql stable security definer set search_path = public as $fn$
  select p.code, p.name,
         case coalesce(a.guest_policy, p.guest_default)
           when 'included'    then 'Ucretsiz misafir hakki var'
           when 'paid'        then 'Misafir alinabilir ama UCRETLI'
           when 'not_allowed' then 'Misafir ALINAMAZ'
           else 'Bilinmiyor' end,
         coalesce(a.guest_included_count, p.guest_included_count, 0),
         case
           when a.guest_fee_amount is not null
             then a.guest_fee_amount::text || ' ' || coalesce(a.guest_fee_currency,'')
           when coalesce(a.guest_policy, p.guest_default) = 'paid'
             then 'Tutar degisken — karti veren kurumdan teyit et'
           else '—' end,
         case coalesce(a.guest_flight_coupling, p.guest_flight_coupling, 'any')
           when 'same_flight'   then 'Misafir AYNI UCUSTA olmali'
           when 'same_carrier'  then 'Misafir AYNI HAVAYOLUYLA ucmali'
           when 'same_alliance' then 'Misafir ayni ittifak havayoluyla ucmali'
           else 'Ucus sarti yok' end,
         coalesce(a.max_stay_hours, p.max_stay_hours),
         nullif(btrim(coalesce(a.conditions,'') || ' ' || coalesce(a.children_note,'')), ''),
         coalesce(a.source_url, p.source_url),
         coalesce(a.checked_at, p.checked_at)
    from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
   where a.venue_id = p_venue and a.accepted and a.active
   order by
     case coalesce(a.guest_policy, p.guest_default)
       when 'included' then 1 when 'paid' then 2 when 'not_allowed' then 3 else 4 end,
     p.code;
$fn$;
grant execute on function public.salon_misafir_karsilastirmasi(uuid) to authenticated, service_role;

insert into rpc_client_surface (fn_name, client, note) values
  ('salon_misafir_karsilastirmasi', 'app',
   'Bir salonda hangi kaynakla girilirse misafir hakki ne olur — host''un "hangi kartimi kullanayim" sorusunun cevabi.')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) ÜÇ AĞDA DA MİSAFİR "ÜCRETSİZ" GÖRÜNMEMELİ
-- Kaynak acik: PP, LoungeKey ve DragonPass'te misafir HAKKI yok.
-- Bir gun biri bunu 'included' yaparsa, urun kullaniciya olmayan bir
-- hak vaat eder ve misafir kapida odemek zorunda kalir.
do $$
declare v_n int; v_l text;
begin
  select count(*), string_agg(p.code || '/' || v.name, ', ')
    into v_n, v_l
    from lounge_venue_acceptance a
    join lounge_programs p on p.id=a.program_id
    join lounge_venues v on v.id=a.venue_id
   where p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
     and a.accepted and a.active
     and (a.guest_policy = 'included' or a.guest_included_count > 0);
  if v_n > 0 then
    raise exception '214: % kart agi satirinda misafir UCRETSIZ gorunuyor — kaynak boyle demiyor: %', v_n, left(v_l,300);
  end if;
  raise notice '214: uc agda da misafir ucretli (kaynakla uyumlu)';
end $$;

-- 2) UYDURULMUŞ FİYAT GERİ GELDİ Mİ
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_programs
   where code in ('PRIORITY_PASS','DRAGONPASS') and typical_guest_fee is not null;
  if v_n > 0 then
    raise exception '214: PP/DragonPass icin kaynaksiz misafir ucreti yeniden yazilmis (% program)', v_n;
  end if;
  raise notice '214: kaynaksiz misafir ucreti yok';
end $$;

-- 3) DRAGONPASS AYNI UÇUŞ ŞARTI KARARA YANSIYOR MU (mutasyon)
-- 🔴 Bu, "tanimli olmak cagrilmak degildir" dersinin uygulamasi.
-- Veriyi yazmak yetmez: kullanicinin gordugu KARAR ciktisinda bu sartin
-- gorunmesi lazim. Karari gercekten cagirip iciine bakiyorum.
do $$
declare v_v uuid; v_dec jsonb; v_dp uuid;
begin
  select id into v_dp from lounge_programs where code='DRAGONPASS';
  select a.venue_id into v_v from lounge_venue_acceptance a
   where a.program_id = v_dp and a.accepted and a.active limit 1;
  if v_v is null then raise exception '214: DragonPass kabul satiri yok — sinanamadi'; end if;

  v_dec := public.resolve_guest_rule(v_dp, v_v, null, null, null);
  if (v_dec ->> 'guest_flight_coupling') is distinct from 'same_flight'
     and (v_dec ->> 'coupling') is distinct from 'same_flight'
     and coalesce(v_dec::text,'') not ilike '%same_flight%' then
    raise exception '214: DragonPass karari AYNI UCUS sartini tasimiyor → %', left(v_dec::text, 400);
  end if;
  raise notice '214: DragonPass karari "ayni ucus" sartini tasiyor';
end $$;

-- 4) İSTANBUL DIŞ HAT BUSINESS — MİSAFİR ENGELİ KARARA YANSIYOR MU
do $$
declare v_v uuid; v_p uuid; v_dec jsonb;
begin
  select id into v_v from lounge_venues
   where active and airport_code='IST' and name ilike '%dış hat%' and name ilike '%business%' limit 1;
  select id into v_p from lounge_programs where code='TK_MS';
  if v_v is null then raise notice '214: IST dis hat business salonu yok — atlandi'; return; end if;

  v_dec := public.resolve_guest_rule(v_p, v_v, 'elite_plus', 'TK', 'business');
  if (v_dec ->> 'guest_policy') <> 'not_allowed' then
    raise exception '214: IST dis hat Business bolumunde misafir HALA serbest gorunuyor → %', left(v_dec::text,400);
  end if;
  raise notice '214: IST dis hat Business — misafir engeli karara yansiyor';
end $$;

-- 5) ŞEMSİYE KAYIT KART AĞI EŞLEŞTİRMESİNE GİRMİYOR (mutasyon)
do $$
declare a1 uuid[]; a2 uuid[]; v_id uuid;
begin
  select id into v_id from lounge_venues where active and is_umbrella limit 1;
  if v_id is null then raise notice '214: semsiye kayit yok — atlandi'; return; end if;
  a1 := public.cns_adaylar('AYT','cip','lounge', null);
  update lounge_venues set is_umbrella = false where id = v_id;
  a2 := public.cns_adaylar('AYT','cip','lounge', null);
  update lounge_venues set is_umbrella = true where id = v_id;
  if coalesce(array_length(a2,1),0) <= coalesce(array_length(a1,1),0) then
    raise exception '214: semsiye bayragi eslestirmeyi ETKILEMIYOR (% vs %) — bayrak okunmuyor',
      coalesce(array_length(a1,1),0), coalesce(array_length(a2,1),0);
  end if;
  raise notice '214: semsiye kayit eslestirmeden dusuyor (% → % aday)',
    coalesce(array_length(a2,1),0), coalesce(array_length(a1,1),0);
end $$;

-- 6) KARŞILAŞTIRMA FONKSİYONU GERÇEK VERİ ÜRETİYOR MU
-- Uc ayri kaynakla girilebilen bir salon bulup misafir haklarinin
-- GERCEKTEN farkli ciktigini gosteriyorum — dosyanin tezi bu.
do $$
declare v_v uuid; v_n int; v_farkli int; v_ad text;
begin
  select a.venue_id, v.name into v_v, v_ad
    from lounge_venue_acceptance a join lounge_venues v on v.id=a.venue_id
   where a.accepted and a.active
   group by a.venue_id, v.name having count(*) >= 3
   order by count(*) desc limit 1;
  if v_v is null then raise exception '214: uc kaynakli salon bulunamadi'; end if;

  select count(*), count(distinct misafir_hakki) into v_n, v_farkli
    from public.salon_misafir_karsilastirmasi(v_v);
  if v_n = 0 then raise exception '214: karsilastirma bos dondu'; end if;
  raise notice '214: "%" salonunda % kaynak var, misafir hakki % farkli deger aliyor', v_ad, v_n, v_farkli;
end $$;

-- 7) İNCELEME KUYRUĞU KAPANDI MI
do $$
declare v_acik int; v_l text;
begin
  select count(*), string_agg(salon, ', ') into v_acik, v_l
    from public.venue_review_list() where durum = 'acik';
  if v_acik > 0 then
    raise exception '214: inceleme kuyrugunda hala % acik kayit var: %', v_acik, left(coalesce(v_l,''),300);
  end if;
  raise notice '214: inceleme kuyrugunun tamami karara baglandi';
end $$;

-- 8) BEKLEYEN KAYNAK SATIRI KALMADI MI
-- 🔴 BU NÖBETÇİ HAKLI VE GEVŞETİLMEYECEK: 214 misafir kurallarını bu
-- satırlardan yazıyor. Eşleşmemiş satır = o salonda o kart ağı için
-- kural YOK = host'a "kartın burada geçer mi" sorusuna cevap veremeyiz.
--
-- AMA MESAJI DEĞİŞTİ (18 Ağustos 2026). Eskiden yalnız ad listeliyordu:
--     "hala 11 eslesmeyen kaynak satiri var: LOUNGEKEY/ADB/Primeclass..."
-- Bu, neyin neden eşleşmediğini SÖYLEMİYOR ve teşhis için ayrı bir
-- sorgu turu gerektiriyor. Bugün üç kez bunu yaşadık: Supabase SQL
-- Editor `raise notice`/`warning` göstermiyor, o yüzden bilgi hata
-- mesajının İÇİNDE olmak zorunda.
--
-- Artık her satır için kaynağın ne dediğini ve katalogda ne bulduğunu
-- yan yana yazıyor — sebep doğrudan okunuyor (en sık: kapsam uyuşmazlığı).
do $$
declare v_n int; v_l text;
begin
  select count(*) into v_n from card_network_source where venue_id is null;
  if v_n > 0 then
    select string_agg(satir, E' ||| ' order by satir) into v_l from (
      select format('%s/%s "%s" [kaynak kapsam=%s tip=%s term=%s] → adaylar: %s',
               s.network, s.airport, s.venue_name,
               coalesce(s.scope,'?'), coalesce(s.tesis_tipi,'?'),
               coalesce(s.terminal,'-'),
               coalesce((select string_agg(v.name || ' {kapsam=' || coalesce(v.scope,'-')
                                           || ' tip=' || coalesce(v.venue_kind,'-')
                                           || ' term=' || coalesce(v.terminal,'-') || '}', ' , ')
                           from lounge_venues v
                          where v.active and v.airport_code = s.airport
                            and public.cns_brand(v.name) = public.cns_brand(s.venue_name)),
                        'ADAY YOK — salon katalogda hic bulunamadi')) as satir
        from card_network_source s where s.venue_id is null) x;
    raise exception '214: % eslesmeyen kaynak satiri: %', v_n, left(coalesce(v_l,''), 2000);
  end if;
  raise notice '214: kaynak satirlarinin TAMAMI bir salona baglandi';
end $$;

-- SINIR EN SONDA (bu dosyada 4 fonksiyon yeniden yaratildi).
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '214: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '214 OK - misafir hakki kaynaga gore, inceleme kuyrugu kapandi' as sonuc;
