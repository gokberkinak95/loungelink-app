-- ============================================================
-- LoungeLink · 098_full_rule_matrix.sql
-- KURAL MATRİSİNİN TAMAMI — BİRİNCİL KAYNAKLARDAN
--
-- ⚠️ Uygulamayı ETKİLER (veri). Şema değişikliği YOK.
-- 🔴 096/097'nin bazı satırlarını DÜZELTİR — aşağıda tek tek yazılı.
--
-- ------------------------------------------------------------
-- KAYNAKLAR (hepsi resmî, hepsi okundu)
--   THY  : turkishairlines.com/lounge/kurallar-ve-kosullar (Tablo 1-5 + ücret tarifesi)
--   AJet : ajet.com/kurumsal/kurallar-ve-kosullar/cip-lounge (ücret tablosu + kurallar)
--   PP   : prioritypass.com/tr-TR/lounges/turkey  (9 havalimanı)
--   LK   : loungekey.com lounge-finder ?countrycode=TUR (9 havalimanı)
--   DP   : dragonpass.com/explore/country/turkey/TR (9 havalimanı, 8 şehir)
--
-- 🔴 ÜÇ KART AĞI DA AYNI 9 HAVALİMANINDA:
--    IST · SAW · ESB · ADB · AYT · BJV · DLM · COV · DIY
--    (Bu, üçünün kendi salon dizinlerinden birebir doğrulandı.)
--
-- ------------------------------------------------------------
-- 🔴 097'DE YAPTIĞIM İKİ HATA
-- ------------------------------------------------------------
-- 1) "AJet SAW'da geçersiz" dedim. AJet'in kendi ücret tablosunda SAW VAR;
--    ama satır "-" ve dipnot şöyle: SAW'daki Turkish Airlines CIP Lounge
--    3 Nisan'dan itibaren GEÇİCİ OLARAK HİZMET DIŞI. Doğru model
--    "hak yok" değil, "salon şu an kapalı" — ikisi farklı şeydir ve
--    salon açılınca kural kendiliğinden doğru olmalı.
-- 2) Kart tipi kırılımını eksik kurmuştum. Gerçek tablo dokuz kart tipi
--    (ELPL, Elite, M&S EC, CLPL, Classic, SAG, PLM, CORP, M&S US CC) ve
--    salon BÖLÜMÜ ile değişiyor.
--
-- ------------------------------------------------------------
-- 🔴 EN KRİTİK İKİ MADDE — ÇAPRAZ MİSAFİR YASAĞI
-- ------------------------------------------------------------
-- THY md.17: "THY seferinde seyahat eden yolcu, SADECE THY seferinde
--   seyahat eden yolcuyu misafir olarak salona davet edebilir. AJet
--   seferinde seyahat eden yolcuyu misafir olarak DAVET EDEMEZ."
-- AJet: "...misafir yolcunun da AJet seferiyle seyahat etmesi
--   gerekmektedir. AJet yolcusunun misafiri THY seferinde ise salona
--   ücretsiz girişi KABUL EDİLMEMEKTEDİR."
--
-- Yani TK ve AJet BİRBİRİNİN YERİNE GEÇMEZ. Eşleştirmede taşıyıcı
-- kodu birebir tutmalı: TK host → TK misafir, AJ host → AJ misafir.
-- Bu, kapıda geri çevrilmenin en olası sebeplerinden biri.
-- ============================================================


-- ============================================================
-- 1) SALONLAR — bölüm ayrımıyla
-- IST hem iç hem dış hatta İKİ BÖLÜMDEN oluşuyor ve misafir hakkı
-- bölüme göre değişiyor. Bölüm ayrı satır olmazsa kural yanlış uygulanır.
-- ============================================================
insert into lounge_venues (airport_code, name, terminal, section, operator, scope, notes)
select * from (values
  ('IST','Turkish Airlines Lounge — Dış Hat','Dis Hat','business','THY','international',
   'Business Class yolcular kart tipinden BAGIMSIZ girer. MISAFIR/AILE HAKKI YOK — '
   || 'misafir getirilecekse Miles&Smiles bolumune girilmeli.'),
  ('IST','Turkish Airlines Lounge — Dış Hat','Dis Hat','miles_smiles','THY','international',
   'Ekonomi bileti + ELPL/Elite/SAG/PLM/CORP/M&S EC/M&S ABD Kredi Karti bu bolume girer.'),
  ('IST','Turkish Airlines Lounge — İç Hat','Ic Hat','business','THY','domestic',
   'Iki bolumlu istasyon: Business Class ve ELPL kartlilar business bolumune girer.'),
  ('IST','Turkish Airlines Lounge — İç Hat','Ic Hat','miles_smiles','THY','domestic',
   'Ekonomi seyahat eden Elite, CLPL, SAG, PLM, CORP kartlilar ve ucret/mil karsiligi '
   || 'girenler bu bolume girer.'),
  ('SAW','Turkish Airlines CIP Lounge — İç Hat','Ic Hat',null,'THY','domestic',
   'AJet ic hat CIP salonu. Giris penceresi SAW''a OZEL: baslangic noktasi SAW ise en erken '
   || '3 saat, baglantili ucus ise en erken 4 saat once. Not: AJet sayfasinda gecmiste bir '
   || 'yenileme donemi duyurulmustu; GECICI operasyonel durumlar KURALA GOMULMEZ, gerekirse '
   || 'BO''dan salon pasife alinir.')
) as v(airport_code,name,terminal,section,operator,scope,notes)
where exists (select 1 from airports a where a.code = v.airport_code)
on conflict do nothing;

-- Bölgesel iç hat CIP salonları (THY/AJet ortak kullanım)
insert into lounge_venues (airport_code, name, terminal, operator, scope, notes)
select a.code, 'Turkish Airlines CIP Lounge', 'Ic Hat', 'THY', 'domestic',
       'THY ve AJet seferlerinde M&S kart sahiplerine acik ic hat CIP salonu.'
  from airports a
 where a.code in ('AYT','ADB','BJV','DLM','ESB','COV','ASR','GZT','HTY','TZX','RZV','DIY')
   and not exists (select 1 from lounge_venues v
                    where v.airport_code = a.code and lower(v.name) like '%turkish airlines%')
on conflict do nothing;

-- Katalog eşitle (host ilan açarken salonu seçebilsin)
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3),
       v.name || case when v.section is not null then ' (' || v.section || ')' else '' end,
       v.terminal, v.active, v.id
  from lounge_venues v
 where v.legacy_lounge_id is null
   and not exists (select 1 from lounges l where l.venue_id = v.id);
update lounge_venues v set legacy_lounge_id = l.id
  from lounges l where v.legacy_lounge_id is null and l.venue_id = v.id;


-- ============================================================
-- 2) THY — KART TİPİ × BÖLÜM MATRİSİ  (Tablo 1-5)
--
-- Aile tanımı (dipnot): hak sahibiyle BİRLİKTE seyahat eden eş ve
-- 25 yaşından gün almamış çocuklar; salona hak sahibiyle birlikte
-- girme zorunluluğu var.
-- ============================================================
delete from lounge_guest_rules r
 using lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS' and r.carrier = 'TK';

insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, cabin_class, guest_allowance, family_allowed,
   guest_must_match_carrier, earliest_entry_hours, paid_entry_allowed, paid_entry_price_note,
   blocked_reason, notes, effective_from, effective_to)
select p.id, v.id, 'TK', t.tier, t.cabin, t.allow, t.family, true, null, t.paid, t.price,
       t.blocked, t.note, date '2026-06-01', date '2026-12-31'
  from lounge_programs p
  cross join lateral (
    select * from (values
      -- --- TABLO 1: İÇ HAT (bölüm ayrımı olan istasyonlarda M&S bölümü) ---
      ('ELPL',        null::text, 1::smallint, true,  false, null::text, null::text,
       'Ic hat: aile VEYA bir misafir. Iki bolumlu istasyonlarda ELPL business bolumune girer.'),
      ('ELITE',       null, 1::smallint, true,  false, null, null,
       'Ic hat: aile VEYA bir misafir. Ekonomi seyahat ederse M&S bolumu.'),
      ('MS_EC',       null, 1::smallint, true,  false, null, null, 'M&S Elite Corporate: aile VEYA bir misafir.'),
      ('CLPL',        null, 0::smallint, false, false, null, null,
       'Classic Plus: IC HAT salonuna UCRETSIZ girer (Ekonomi''de bile) ama MISAFIR/AILE HAKKI YOK.'),
      ('CLASSIC',     null, 0::smallint, false, true,
       'Ic hat: IST 3.000 TL · AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL. '
       || 'Dis hat (Vnukovo) 50 USD.', null,
       'Classic: ucretli giris. Ucret odeyen yolcunun misafir hakki dogmaz.'),
      ('SAG',         null, 1::smallint, false, false, null, null, 'Star Alliance Gold: BIR misafir, aile hakki YOK.'),
      ('PLM',         null, 1::smallint, false, false, null, null, 'Miles&More: BIR misafir.'),
      ('CORP',        null, 1::smallint, false, false, null, null,
       'Corporate Club: BIR misafir. Ic hat icin ayni gun baglantili dis hat sarti ve ucuslarin '
       || 'AYNI BILET uzerinde olmasi gerekir.'),
      ('MS_US_CC',    null, 0::smallint, false, false, null, null,
       'M&S ABD Kredi Karti: misafir hakki YOK. Dalaman ve Diyarbakir haric ucretsiz giris. '
       || 'M&S uyeligi kartla eslestirilmis olmali.'),
      -- --- Kartsız Business Class ---
      -- 🔴 DUZELTME: kolon 'Business' degil 'business' kabul ediyor.
      -- 083'teki kisit: cabin_class in ('economy','business','first').
      -- Buyuk harfle yazinca 23514 check constraint hatasi veriyordu.
      (null,          'business', 0::smallint, false, false, null, null,
       'Kart tipi olmadan Business Class: salona girer ama MISAFIR/AILE HAKKI YOK.')
    ) as x(tier, cabin, allow, family, paid, price, blocked, note)
  ) as t
  join lounge_venues v on v.active
   and (lower(v.name) like '%turkish airlines%')
 where p.code = 'TK_MS'
   -- IST dış hat BUSINESS bölümü ayrı ele alınıyor (aşağıda)
   and coalesce(v.section,'') <> 'business';

-- --- TABLO 3: IST DIŞ HAT **BUSINESS BÖLÜMÜ** — MİSAFİR HAKKI YOK ---
-- Kart tipi ne olursa olsun. Misafir getirilecekse M&S bölümüne girilmeli.
insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, blocked_reason, notes, effective_from)
select p.id, v.id, 'TK', null, 0, false, true,
       'Bu bolumde misafir/aile hakki yok',
       'IST dis hat Lounge BUSINESS bolumu: Business Class yolcular kart tipinden bagimsiz '
       || 'girer ama MISAFIR/AILE HAKKI YOKTUR. Misafir getirilecekse Lounge Miles&Smiles '
       || 'bolumune girilmelidir. (Star Alliance FIRST yolcusu istisna: bir misafir.)',
       current_date
  from lounge_programs p, lounge_venues v
 where p.code = 'TK_MS' and v.section = 'business' and v.airport_code = 'IST'
   and lower(v.name) like '%turkish airlines%' and lower(coalesce(v.terminal,'')) like '%dis%';


-- ============================================================
-- 3) THY SALONLARI × PROGRAM KABULÜ
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true,
       case when v.section = 'business' then 'not_allowed' else 'included' end,
       case when v.section = 'business' then 0 else 1 end,
       'same_carrier',
       case when v.section = 'business' then 'block' else 'warn' end,
       case when v.section = 'business'
            then 'Business bolumunde misafir/aile hakki YOK. Misafir getirilecekse '
                 || 'Miles&Smiles bolumu secilmeli.'
            else 'Misafir hakki KART TIPINE bagli: ELPL/Elite/M&S EC aile veya 1 misafir · '
                 || 'SAG/PLM/CORP 1 misafir · Classic Plus ve Classic MISAFIR HAKKI YOK. '
                 || '🔴 Misafir de TK seferinde ucmali — AJet yolcusu misafir olarak KABUL EDILMEZ (md.17).' end,
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/', current_date
  from lounge_venues v join lounge_programs p on p.code = 'TK_MS'
 where v.active and lower(v.name) like '%turkish airlines%'
on conflict (venue_id, program_id) do update set
  guest_policy = excluded.guest_policy, guest_included_count = excluded.guest_included_count,
  guest_flight_coupling = 'same_carrier', enforcement = excluded.enforcement,
  conditions = excluded.conditions, source_url = excluded.source_url,
  checked_at = excluded.checked_at;

-- Star Alliance Gold: dış hat salonunda 1 misafir, AİLE YOK
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_alliance', 'warn',
       'Star Alliance Gold: BIR misafir, aile hakki YOK. Misafirin ittifak uyesi bir '
       || 'havayolunda ucmasi gerekir. IST dis hat BUSINESS bolumunde hak yok.',
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/', current_date
  from lounge_venues v join lounge_programs p on p.code = 'STAR_GOLD'
 where v.active and lower(v.name) like '%turkish airlines%'
   and coalesce(v.section,'') <> 'business'
on conflict (venue_id, program_id) do update set
  guest_policy = 'included', guest_included_count = 1,
  guest_flight_coupling = 'same_alliance',
  conditions = excluded.conditions, checked_at = excluded.checked_at;


-- ============================================================
-- 4) AJET — 097'DEKİ İKİ HATA DÜZELTİLİYOR
--
-- AJet ücret tablosu (1 Haz – 31 Ara 2026):
--   Classic / Classic Plus / kartsız:
--     AYT · ADB · BJV · DLM · ESB → 2.800 TL
--     COV · ASR · GZT · HTY · TZX · RZV · DIY → 2.000 TL
--     SAW → "-"  (salon GEÇİCİ OLARAK KAPALI)
--   Elite / Elite Plus / Elite Corporate → ÜCRETSİZ
--
-- Misafir: Elite/ELPL'de aile VEYA bir misafir. Classic Plus'ta
-- MİSAFİR/AİLE HAKKI YOK (AJet sayfası açıkça yazıyor).
-- 🔴 Misafir de AJet seferinde uçmalı; THY yolcusu misafir OLAMAZ.
--
-- Giriş penceresi: SAW hariç en erken 2 saat önce. SAW iç hat:
-- başlangıç noktası SAW ise 3 saat, bağlantılıysa 4 saat.
-- ============================================================
delete from lounge_venue_acceptance a
 using lounge_programs p where a.program_id = p.id and p.code = 'AJET_MS';

-- 4a) Geçerli iç hat salonları
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, earliest_entry_hours, children_note, enforcement,
   conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_carrier', 2,
       '0-2 yas ucretsiz. Ucret odeyen yolcu 0-6 yas AILE cocuklarini ucretsiz sokabilir; '
       || '7-12 yas aile cocugu %50; aile olmayan 3-12 yas %50.',
       'warn',
       'Elite / Elite Plus / Elite Corporate: UCRETSIZ, aile VEYA bir misafir. '
       || 'Classic ve Classic Plus: UCRETLI giris (' ||
       case when v.airport_code in ('AYT','ADB','BJV','DLM','ESB') then '2.800 TL' else '2.000 TL' end
       || ') ve MISAFIR/AILE HAKKI YOK. '
       || '🔴 Misafirin de AJet seferinde ucmasi SART — THY seferindeki yolcu misafir olarak '
       || 'kabul edilmez. Salona en erken kalkistan 2 saat once girilebilir.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', current_date
  from lounge_venues v join lounge_programs p on p.code = 'AJET_MS'
 where v.active
   and v.airport_code in ('AYT','ADB','BJV','DLM','ESB','COV','ASR','GZT','HTY','TZX','RZV','DIY')
   and lower(v.name) like '%turkish airlines%';

-- 4b) SAW — AÇIK VE KURALA GÖRE ÇALIŞIR
--
-- 🔴 ÖNCEKİ SÜRÜMDE HATA: SAW'ı "salon kapalı" diye modellemiştim.
-- Bu YANLIŞTI ve iki sebeple:
--   1. Kapanma GEÇİCİ ve OPERASYONEL bir durum; kural tablosuna gömülürse
--      salon açıldığında veri sessizce yanlış kalır ve kimse fark etmez.
--      Geçici durumlar için doğru araç BO'dan salonu pasife almaktır.
--   2. AJet'in kendi sayfası SAW için ÖZEL GİRİŞ PENCERESİ tanımlıyor
--      (başlangıç noktası SAW ise 3 saat, bağlantılı uçuş ise 4 saat).
--      İşlemeyen bir salon için böyle bir kural yazılmaz.
--
-- Ücret tablosundaki "-" ise "hak yok" demek DEĞİL: dipnot, SAW'dan ve
-- yetkili acentelerden yalnız SAW salonu için CIP satışı yapılabildiğini
-- söylüyor. Elite/Elite Plus sütunu SAW dahil ÜCRETSİZ.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, earliest_entry_hours, children_note, enforcement,
   conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_carrier', 3,
       '0-2 yas ucretsiz. Ucret odeyen yolcu 0-6 yas AILE cocuklarini ucretsiz sokabilir; '
       || '7-12 yas aile cocugu %50; aile olmayan 3-12 yas %50.',
       'warn',
       'Elite / Elite Plus / Elite Corporate: UCRETSIZ, aile VEYA bir misafir. '
       || '🔴 Misafirin de AJet seferinde ucmasi SART — THY seferindeki yolcu misafir olarak '
       || 'kabul edilmez. GIRIS PENCERESI SAW''A OZEL: baslangic noktasi SAW ise en erken '
       || '3 saat, baglantili ucus ise en erken 4 saat once. CIP satisi yalniz SAW salonu '
       || 'icin yapilabilir.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', current_date
  from lounge_venues v join lounge_programs p on p.code = 'AJET_MS'
 where v.active and v.airport_code = 'SAW' and lower(v.name) like '%turkish airlines%';

-- 4c) IST — AJet ücret/hak tablosunda YOK
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count, enforcement,
   conditions, source_url, checked_at)
select v.id, p.id, true, 'not_allowed', 0, 'block',
       'AJet seferinde M&S lounge erisimi tablosunda ISTANBUL HAVALIMANI YOK. '
       || 'AJet ucusunda Elite/Elite Plus karti IST''te lounge hakki vermez.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', current_date
  from lounge_venues v join lounge_programs p on p.code = 'AJET_MS'
 where v.active and v.airport_code = 'IST' and lower(v.name) like '%turkish airlines%';

-- AJet kart tipi kırılımı
delete from lounge_guest_rules r using lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS';
insert into lounge_guest_rules
  (program_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, earliest_entry_hours, paid_entry_allowed,
   paid_entry_price_note, notes, effective_from, effective_to)
select p.id, 'AJ', t.tier, t.allow, t.family, true, 2, t.paid, t.price, t.note,
       date '2026-06-01', date '2026-12-31'
  from lounge_programs p, (values
    ('ELPL',    1::smallint, true,  false, null::text, 'Elite Plus: UCRETSIZ, aile VEYA bir misafir.'),
    ('ELITE',   1::smallint, true,  false, null,       'Elite: UCRETSIZ, aile VEYA bir misafir.'),
    ('MS_EC',   1::smallint, true,  false, null,       'Elite Corporate: UCRETSIZ, aile VEYA bir misafir.'),
    ('CLPL',    0::smallint, false, true,
     'AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL',
     'Classic Plus: MISAFIR/AILE HAKKI YOK. Beraberindeki her misafir ve 2-12 yas cocuk icin '
     || 'tablodaki ucretin %50''si alinir.'),
    ('CLASSIC', 0::smallint, false, true,
     'AYT/ADB/BJV/DLM/ESB 2.800 TL · COV/ASR/GZT/HTY/TZX/RZV/DIY 2.000 TL',
     'Classic: ucretli giris, misafir hakki yok.')
  ) as t(tier, allow, family, paid, price, note)
 where p.code = 'AJET_MS';

update lounge_programs
   set notes = 'AJet seferinde Elite/Elite Plus/Elite Corporate: UCRETSIZ + aile VEYA 1 misafir. '
            || 'Classic/Classic Plus: ucretli, misafir hakki YOK. 🔴 Misafir de AJet seferinde '
            || 'ucmali (THY yolcusu misafir olamaz). IST tabloda YOK. SAW GECERLI. '
            || 'Giris: SAW haric en erken 2 saat once.'
 where code = 'AJET_MS';


-- ============================================================
-- 5) KART AĞLARI — ÜÇÜ DE AYNI 9 HAVALİMANINDA
-- (PP · LoungeKey · DragonPass kendi salon dizinlerinden doğrulandı)
--
-- Salon bazında hangi salonun kabul ettiği ayrı bir iddia; burada
-- HAVALİMANI düzeyinde kanıt var. Bu yüzden o havalimanlarındaki
-- işletmeci salonlarına (IGA, Plaza Premium, Primeclass) yazıyoruz;
-- havayolu salonlarına YAZMIYORUZ (THY salonu kart ağı kabul etmez).
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, guest_fee_note, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'paid', 0,
       case when p.code = 'DRAGONPASS' then 'same_flight' else 'any' end,
       'Ucret kisi basi ve ziyaret basina; misafir de uyenin kartindan tahsil edilir. '
       || 'Tutar uyelik planina ve salona gore degisir.',
       'warn',
       case when p.code = 'DRAGONPASS'
            then '🔴 DragonPass md.7.15.7: misafirin uyeyle AYNI UCUSTA olmasi gerekir. '
                 || 'Kalis tipik 2 saat. Uyelik devredilemez.'
            else 'Misafirin uctugu havayolu ONEMSIZ. Misafir uyeyle AYNI ANDA kaydolup girmeli; '
                 || 'kendi binis karti ve kimligi gerekir. Erisim araci devredilemez, '
                 || 'ziyaret basina tek arac.' end,
       case p.code
         when 'PRIORITY_PASS' then 'https://www.prioritypass.com/tr-TR/lounges/turkey'
         when 'LOUNGEKEY'     then 'https://www.loungekey.com/tr/lounge-finder/country?countrycode=TUR'
         else 'https://www.dragonpass.com/explore/country/turkey/TR' end,
       current_date
  from lounge_venues v
  join lounge_programs p on p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
 where v.active
   and v.airport_code in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','COV','DIY')
   -- yalnız işletmeci salonları; havayolu salonu kart ağı kabul etmez
   and (lower(v.name) like '%iga%' or lower(v.name) like '%plaza premium%'
        or lower(v.name) like '%primeclass%' or lower(v.name) like '%cip lounge%'
        or lower(v.name) like '%kepler%')
   and lower(v.name) not like '%turkish airlines%'
on conflict (venue_id, program_id) do update set
  accepted = true, guest_policy = 'paid',
  guest_flight_coupling = excluded.guest_flight_coupling,
  conditions = excluded.conditions, guest_fee_note = excluded.guest_fee_note,
  source_url = excluded.source_url, checked_at = excluded.checked_at;

-- 🔴 THY salonları kart ağlarını KABUL ETMEZ — açıkça yaz
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   enforcement, conditions, checked_at)
select v.id, p.id, false, 'not_allowed', 0, 'block',
       'Turkish Airlines ozel yolcu salonlari havayolu programina baglidir; Priority Pass / '
       || 'LoungeKey / DragonPass ile giris kabul edilmez. Bu havalimanindaki isletmeci '
       || 'salonlarini (IGA / Plaza Premium / Primeclass) sec.',
       current_date
  from lounge_venues v
  join lounge_programs p on p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
 where v.active and lower(v.name) like '%turkish airlines%'
on conflict (venue_id, program_id) do update set
  accepted = false, guest_policy = 'not_allowed', enforcement = 'block',
  conditions = excluded.conditions, checked_at = excluded.checked_at;

update lounge_programs set coverage_status = 'verified', checked_at = current_date
 where code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','TK_MS','AJET_MS','STAR_GOLD','PGS_PAID');


-- ============================================================
-- 6) DOĞRULAMA
-- ============================================================
select v.airport_code, v.name, coalesce(v.section,'-') as bolum, p.code,
       a.guest_policy, a.guest_flight_coupling, a.enforcement,
       case when a.checked_at is null then 'varsayim' else 'dogrulandi' end as kaynak
  from lounge_venue_acceptance a
  join lounge_venues v on v.id = a.venue_id
  join lounge_programs p on p.id = a.program_id
 order by v.airport_code, v.name, p.code;

select p.code, r.card_tier, r.guest_allowance, r.family_allowed, r.paid_entry_allowed, r.notes
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code in ('TK_MS','AJET_MS') and r.card_tier is not null
 order by p.code, r.card_tier;

select
  (select count(*) from lounge_venue_acceptance where checked_at is not null) as dogrulanmis_hucre,
  (select count(*) from lounge_venue_acceptance where checked_at is null)     as varsayim_hucre,
  (select count(*) from lounge_venue_acceptance where guest_policy='unknown') as genel_uyari_cikacak;

select '098 OK - THY/AJet/PP/LoungeKey/DragonPass matrisi birincil kaynaklardan kuruldu' as sonuc;
