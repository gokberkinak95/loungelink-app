-- ============================================================
-- LoungeLink · 127_ist_tk_from_iga.sql
-- IST THY SALONLARI: iGA'NIN KENDI SAYFASINDAN
--
-- ⚠️ Uygulamayi ETKILER (kural mantigi). KAYNAK: istairport.com
-- (havalimani isletmecisinin kendi sayfasi — BIRINCIL).
--
-- ------------------------------------------------------------
-- 🔴 IKI CELISKI BULDUM — VE IKISI DE TERS YONDE YANLISTI
-- ------------------------------------------------------------
-- Bugune kadar TK'nin butun kart tiplerine `same_carrier` yazmistim:
-- "misafir de THY'de ucmali". iGA sayfasi ikisini de duzeltiyor:
--
-- 1) ELITE / ELITE PLUS — BENIM KURALIM FAZLA SIKIYDI
--    Dipnot aynen: "Turk Hava Yollari ucuslarinda M&S Elite ve Elite
--    Plus kartli yolcularin misafirleri FARKLI BIR STAR ALLIANCE
--    ucusunda yolculuk yapacak olsalar dahi THY ozel yolcu salonlarini
--    kullanmaya devam edebilirler."
--    Yani misafir ayni ucusta OLMAK ZORUNDA DEGIL, hatta ayni
--    havayolunda bile degil — Star Alliance yetiyor.
--    Benim kuralim gecerli bir misafiri REDDEDIYORDU.
--
-- 2) STAR ALLIANCE GOLD — BENIM KURALIM FAZLA GEVSEKTI
--    Dipnot: "03 Mayis 2021'den itibaren Star Alliance kural degisikligi
--    geregi, Gold kartli yolcu ve misafirlerin artik AYNI UCAKTA
--    seyahat etmeleri gerekmektedir."
--    Yani SAG icin same_carrier YETMEZ, AYNI UCUS sart.
--    Benim kuralim gecersiz bir misafiri KABUL EDIYORDU.
--
-- Ilki kullaniciyi haksiz yere engelliyordu, ikincisi kapida
-- geri cevrilmeye gonderiyordu. Ikincisi daha pahali.
--
-- 🔴 AJET DEGISMIYOR: AJet Star Alliance uyesi DEGIL. THY md.17'nin
-- capraz misafir yasagi aynen gecerli — bu kaynak onu cürütmüyor,
-- aksine mekanizmasini acikliyor (ittifak uyeligi belirleyici).
-- ============================================================

-- ELITE / ELITE PLUS / ELITE CORPORATE: ittifak yeter
update lounge_guest_rules r
   set guest_must_match_carrier = false,
       notes = coalesce(r.notes,'')
            || ' [127] iGA/istairport.com: misafir FARKLI BIR STAR ALLIANCE ucusunda '
            || 'olsa dahi THY salonunu kullanabilir. Ayni ucus ya da ayni havayolu '
            || 'SART DEGIL; Star Alliance uyeligi yeterli. (AJet Star Alliance uyesi '
            || 'DEGILDIR — capraz misafir yasagi surer.)'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS'
   and r.card_tier in ('ELPL','ELITE','MS_EC')
   and r.venue_id is null
   and coalesce(r.notes,'') not like '%[127]%';

-- STAR ALLIANCE GOLD: ayni UCAK sart
update lounge_guest_rules r
   set guest_must_match_carrier = true,
       notes = coalesce(r.notes,'')
            || ' [127] 03.05.2021 Star Alliance kural degisikligi: Gold kartli yolcu ve '
            || 'MISAFIRLERI AYNI UCAKTA seyahat etmek ZORUNDADIR. Bu, Elite/Elite Plus''tan '
            || 'DAHA SIKI bir kuraldir — Gold misafirini ayri ucusa bindiremezsin.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS'
   and r.card_tier = 'SAG' and r.venue_id is null
   and coalesce(r.notes,'') not like '%[127]%';

-- Program duzeyinde kuplaj: SAG icin same_flight, digerleri same_alliance
update lounge_venue_acceptance a
   set guest_flight_coupling = 'same_alliance',
       conditions = coalesce(a.conditions,'')
                 || ' [127] Elite/Elite Plus misafiri Star Alliance uyesi BASKA bir '
                 || 'havayolunda, hatta farkli bir ucusta olabilir. Star Alliance Gold '
                 || 'icin ise misafirin AYNI UCAKTA olmasi zorunludur.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'TK_MS' and v.airport_code = 'IST' and v.active
   and coalesce(a.conditions,'') not like '%[127]%';

-- ---- IST IC HAT: kimler girer (iGA listesi) ----
-- 🔴 CLASSIC PLUS IC HAT SALONUNA GIRER. Bunu 104'te dogru yazmistim
-- (misafir hakki 0) ama GIRIS hakkini hic belirtmemistim. "Misafir
-- goturemezsin" ile "giremezsin" ayni sey degil; host kendi girisini
-- yapabiliyorsa ilan acmasinda bir sakinca yok.
update lounge_venue_acceptance a
   set conditions = coalesce(a.conditions,'')
     || ' [127] IST IC HAT — iGA listesi: (1) Business Class TUM yolcular, '
     || '(2) Economy''de Miles&Smiles CLASSIC PLUS uyeleri [GIRER ama MISAFIR YOK], '
     || '(3) Economy''de Elite/Elite Plus [1 misafir VEYA aile: es ve cocuklar], '
     || '(4) ayni gun baglantili DIS HAT seferi olan Corporate Club Turkiye uyeleri '
     || '[1 misafir], (5) Economy''de Star Alliance Gold [1 misafir, AYNI UCAK]. '
     || 'Yalnizca YURT ICI ucuslar kabul edilir.',
       source_url = 'https://www.istairport.com/ucuslar/havalimani-rehberleri/giden-yolcu-rehberi/hizmetler/ozel-yolcu-hizmetleri/lounge',
       checked_at = current_date
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'TK_MS' and v.airport_code = 'IST'
   and coalesce(v.scope,'') = 'domestic' and v.active
   and coalesce(a.conditions,'') not like '%[127] IST IC HAT%';

-- ---- IST DIS HAT M&S: aile kurali NET ----
-- 🔴 "Es ve cocuklarin salona uye yolcularla BIRLIKTE girmesi gerekir,
-- 25 yas uzeri cocuklar salonu UCRETLI kullanabilmektedir."
-- Aile hakkini "sinirsiz misafir" gibi okumak yaygin bir yanilgi;
-- iki sinir da net: BIRLIKTE girme ve 25 yas.
update lounge_venue_acceptance a
   set children_note = 'Aile = es + 25 yasindan gun almamis cocuklar. Es ve cocuklarin '
                    || 'salona UYE YOLCUYLA BIRLIKTE girmesi gerekir; ayri giremezler. '
                    || '25 yas uzeri cocuklar salonu UCRETLI kullanabilir.',
       conditions = coalesce(a.conditions,'')
     || ' [127] IST DIS HAT M&S — iGA listesi: THY Business; Elite/Elite Plus + EKSTRA 1 '
     || 'misafir; Elite/Elite Plus + ailesi; Star Alliance Gold THY Economy yolcusu + 1 '
     || 'misafir; Corporate Club uyesi THY yolcusu; Star Alliance uyesi DIGER havayollariyla '
     || 'Economy''de ucan M&S Elite/Elite Plus + 1 misafir; ayni sekilde Star Alliance Gold '
     || '+ 1 misafir.',
       source_url = 'https://www.istairport.com/ucuslar/havalimani-rehberleri/giden-yolcu-rehberi/hizmetler/ozel-yolcu-hizmetleri/lounge',
       checked_at = current_date
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'TK_MS' and v.airport_code = 'IST'
   and coalesce(v.section,'') = 'miles_smiles' and v.active
   and coalesce(a.conditions,'') not like '%[127] IST DIS HAT%';

-- ---- IST DIS HAT BUSINESS: misafir YOK, ama Star Alliance Business de girer ----
update lounge_venue_acceptance a
   set guest_policy = 'not_allowed', guest_included_count = 0,
       conditions = 'IST dis hat Lounge BUSINESS bolumu — iGA listesi: yalnizca "Turkish '
     || 'Airlines VEYA Star Alliance uyesi hava yollarinin Business Class yolculari". '
     || 'Liste MISAFIR ICERMIYOR: bu bolumde misafir/aile hakki YOKTUR. Misafir '
     || 'goturecek yolcu Lounge Miles&Smiles bolumune girmelidir.',
       source_url = 'https://www.istairport.com/ucuslar/havalimani-rehberleri/giden-yolcu-rehberi/hizmetler/ozel-yolcu-hizmetleri/lounge',
       checked_at = current_date
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'TK_MS' and v.airport_code = 'IST'
   and coalesce(v.section,'') = 'business' and v.active;

-- ---- DOGRULAMA ----
select r.card_tier, r.guest_allowance, r.family_allowed,
       r.guest_must_match_carrier as ayni_ucus_sart,
       coalesce(r.notes,'') like '%[127]%' as guncellendi
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code = 'TK_MS' and r.venue_id is null
   and r.card_tier in ('ELPL','ELITE','MS_EC','SAG','CLPL')
 order by r.card_tier;

select '127 OK - iGA kaynagi: Elite ittifak yeter, SAG ayni ucak sart' as sonuc;
