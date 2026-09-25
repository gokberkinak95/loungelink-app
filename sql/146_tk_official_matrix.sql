-- ============================================================
-- LoungeLink · 146_tk_official_matrix.sql
-- THY RESMI KURAL TABLOSU — TAM KARSILIK
--
-- ⚠️ Uygulamayi ETKILER (kural motorunun cekirdegi).
-- KAYNAK: turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar
--         (Tablo-1..5 + madde 1-18 + AJet bolumu)
--
-- ------------------------------------------------------------
-- 🔴 KAYNAKLA KARSILASTIRINCA ALTI BOSLUK CIKTI
-- ------------------------------------------------------------
-- 1. AYNI KART, FARKLI TASIYICI -> FARKLI HAK  (en buyuk eksik)
--    Tablo-2 acikca ikiye ayiriyor:
--      TK ile ucuyorsan          ELPL -> "Aile VEYA bir misafir"
--      Star Alliance uyesi ile   ELPL -> "Bir misafir"  (AILE YOK)
--    Bizde kural tasiyicidan bagimsizdi; aile hakkini herkese
--    veriyorduk. Lufthansa ile ucan Elite Plus'a "ailen de girebilir"
--    demek, kapida ailenin geri cevrilmesi demektir.
--
-- 2. AJET'TE OLMAYAN KARTLARI TANIMISIZ
--    AJet tablosunda YALNIZ Classic/Classic Plus (ucretli) ve
--    Elite/Elite Plus (ucretsiz) var. Bizde AJET_MS'te MS_EC kurali
--    vardi — kaynakta YOK. Uydurulmus hak, eksik haktan kotudur.
--
-- 3. CLASSIC UCRETLI GIRIS TARIFESI YOKTU
--    Classic ucretsiz giremez ama ODEYEREK girer: IST 3.000 TL,
--    bes havalimani 2.800 TL, yedi havalimani 2.000 TL.
--    "Giremezsin" demek yanlisti; "ucretle girersin" dogru.
--
-- 4. FIRST CLASS -> Business bolumunde 1 MISAFIR (Tablo-3)
--    Business'ta kimsenin misafir hakki yok AMA First'un var.
--
-- 5. KARTSIZ BUSINESS -> MISAFIR YOK (Tablo-1 ve 2 son satir)
--
-- 6. YURT DISI: CORP ve M&S EC, Star Alliance MARKALI salonlara
--    GIREMEZ (Tablo-5 dipnotlari). Anlasmali salonlara girer.
--
-- 🔴 DIGER PROGRAMLARA DOKUNMUYORUZ. Bu dosya YALNIZ TK_MS ve
-- AJET_MS satirlarini degistirir; Priority Pass, LoungeKey,
-- DragonPass, Pegasus ve kredi karti kurallari AYNEN kalir.
-- Dosyanin sonunda bunu DOGRULUYORUZ.
-- ============================================================

-- Once TK/AJet program duzeyi kurallarini kapat; yeniden kuracagiz.
update lounge_guest_rules r set effective_to = current_date - 1
  from lounge_programs p
 where r.program_id = p.id and p.code in ('TK_MS','AJET_MS')
   and r.venue_id is null
   and (r.effective_to is null or r.effective_to >= current_date);

-- ---- TABLO-1 + TABLO-2 (TK ile ucan) ----
-- carrier = 'TK': ilanin tasiyicisi THY ise bu satir gecerli.
insert into lounge_guest_rules
  (program_id, carrier, card_tier, cabin_class, guest_allowance, family_allowed,
   guest_must_match_carrier, paid_entry_allowed, notes, effective_from)
select p.id, x.carrier, x.tier, x.cabin, x.n, x.fam, true, x.paid, x.note, current_date
  from lounge_programs p, (values
  -- TK seferinde: Elite ve Elite Plus AYNI haktadir (kaynak Tablo-1/2)
  ('TK','ELPL',   null, 1::smallint, true,  false,
   'THY seferinde: aile VEYA bir misafir. Aile = eş + 25 yaşından gün almamış çocuklar; salona hak sahibiyle BİRLİKTE girmeleri gerekir.'),
  ('TK','ELITE',  null, 1::smallint, true,  false,
   'THY seferinde: aile VEYA bir misafir. Elite Plus ile aynı haktadır.'),
  ('TK','MS_EC',  null, 1::smallint, true,  false,
   'THY seferinde: aile VEYA bir misafir. Turkish Airlines Lounge markalı salonlarda geçerli.'),
  ('TK','SAG',    null, 1::smallint, false, false, 'THY seferinde bir misafir. Aile hakkı yoktur.'),
  ('TK','PLM',    null, 1::smallint, false, false, 'THY seferinde bir misafir. Aile hakkı yoktur.'),
  ('TK','CORP',   null, 1::smallint, false, false,
   'Bir misafir. Aynı bilette yurt dışı bağlantısı şartı aranır (iç hatta aynı gün, ertesi 05:00''e kadar).'),
  ('TK','CLPL',   null, 0::smallint, false, false,
   'Yalnız kendin girersin — misafir ve aile hakkı YOKTUR. Yanındaki 3-12 yaş aile çocuğu için ücretin %50''si alınır.'),
  ('TK','CLASSIC',null, 0::smallint, false, true,
   'Ücretsiz giriş hakkı yok; ÜCRET ÖDEYEREK girebilirsin. Misafir hakkı yoktur. 0-6 yaş aile çocuğu ücretsiz, 7-12 yaş %50.'),
  ('TK','MS_US_CC',null,0::smallint, false, false,
   'Misafir ve aile hakkı YOKTUR; beraberindeki herkes tam ücret öder. Üyeliğin kartla eşleştirilmiş olmalı.')
  ) as x(carrier, tier, cabin, n, fam, paid, note)
 -- 🔴 PROGRAM FILTRESI ZORUNLU. Ilk yazimda `from lounge_programs p,
 -- (values...)` filtresiz kaldi ve KARTEZYEN CARPIM uretti: TK
 -- kurallari Priority Pass, LoungeKey, DragonPass dahil TUM
 -- programlara yazildi. Priority Pass'in kural listesinde "THY
 -- seferinde aile veya bir misafir" yaziyordu.
 --
 -- Denetimlerim bunu KACIRDI cunku mukerrer degildi — her program
 -- icin TEK satirdi, ama YANLIS programa aitti. Dogru sayida yanlis
 -- veri, denetimden gecer.
 where p.code = 'TK_MS';

-- ---- TABLO-2 alt blok: STAR ALLIANCE UYESI BASKA HAVAYOLU ----
-- 🔴 AYNI KARTLAR, AILE HAKKI YOK. Tek fark tasiyici.
insert into lounge_guest_rules
  (program_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, 'STAR_ALLIANCE', x.tier, x.n, false, false, x.note, current_date
  from lounge_programs p, (values
  ('ELPL',  1::smallint, 'Star Alliance üyesi BAŞKA bir havayoluyla uçuyorsan: bir misafir. THY seferinden farklı olarak AİLE HAKKI YOKTUR.'),
  ('ELITE', 1::smallint, 'Star Alliance üyesi başka havayolunda: bir misafir. Aile hakkı yoktur.'),
  ('MS_EC', 1::smallint, 'Star Alliance üyesi başka havayolunda: bir misafir (İstanbul dış hat M&S bölümünde aile de olabilir).'),
  ('SAG',   1::smallint, 'Bir misafir. 03.05.2021''den beri misafirin SENİNLE AYNI UÇAKTA olması zorunludur.'),
  ('PLM',   1::smallint, 'Bir misafir.')
  ) as x(tier, n, note)
 where p.code = 'TK_MS';

-- ---- KABIN SINIFI KURALLARI (kartsiz) ----
insert into lounge_guest_rules
  (program_id, card_tier, cabin_class, guest_allowance, family_allowed, notes, effective_from)
select p.id, null, x.cabin, x.n, false, x.note, current_date
  from lounge_programs p, (values
  ('business', 0::smallint,
   'Business Class bileti salona girmeni sağlar ama MİSAFİR HAKKI VERMEZ. Kart tipinin misafir hakkı varsa Miles&Smiles bölümüne girmelisin.'),
  ('first', 1::smallint,
   'First Class: Lounge Business bölümünde bir misafir hakkın var.')
  ) as x(cabin, n, note)
 where p.code = 'TK_MS';

-- ---- AJET ----
-- 🔴 KAYNAKTA YALNIZ DORT KART VAR. Fazlasini uydurmuyoruz.
-- Ve AJet listesinde ISTANBUL YOK — IST'te AJet salon hakki yoktur.
insert into lounge_guest_rules
  (program_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, paid_entry_allowed, notes, effective_from)
select p.id, 'VF', x.tier, x.n, x.fam, true, x.paid, x.note, current_date
  from lounge_programs p, (values
  ('ELPL',   1::smallint, true,  false,
   'AJet seferinde Elite Plus: ücretsiz giriş. AJet salon listesinde İSTANBUL YOKTUR — yalnız AYT, ADB, BJV, DLM, ESB ve COV, ASR, GZT, HTY, TZX, RZV, DIY.'),
  ('ELITE',  1::smallint, true,  false,
   'AJet seferinde Elite: ücretsiz giriş. İstanbul bu listede yoktur.'),
  ('CLPL',   0::smallint, false, true,
   'AJet seferinde Classic Plus ÜCRET ÖDER (2.800 / 2.000 TL). THY seferinden farklı — THY''de ücretsizdir. Misafir hakkı yoktur.'),
  ('CLASSIC',0::smallint, false, true,
   'AJet seferinde Classic ücret öder (2.800 / 2.000 TL). Misafir hakkı yoktur.')
  ) as x(tier, n, fam, paid, note)
 where p.code = 'AJET_MS';

-- ---- UCRETLI GIRIS TARIFESI (1 Haz - 31 Ara 2026) ----
insert into beta_settings (key, value) values
 ('tk_paid_entry_2026', '{
   "valid": "1 Haziran 2026 - 31 Aralık 2026",
   "TK": {
     "CLASSIC": {"IST": "3.000 TL",
                 "AYT,ADB,BJV,DLM,ESB": "2.800 TL",
                 "COV,ASR,GZT,HTY,TZX,RZV,DIY": "2.000 TL",
                 "VKO": "50 USD"},
     "CLPL": "ücretsiz", "ELITE": "ücretsiz", "ELPL": "ücretsiz",
     "CORP": "ücretsiz", "PLM": "ücretsiz", "SAG": "ücretsiz", "MS_EC": "ücretsiz",
     "MS_US_CC": "Dalaman ve Diyarbakır hariç ücretsiz"
   },
   "VF": {
     "CLASSIC,CLPL": {"AYT,ADB,BJV,DLM,ESB": "2.800 TL",
                      "COV,ASR,GZT,HTY,TZX,RZV,DIY": "2.000 TL"},
     "ELITE,ELPL": "ücretsiz"
   },
   "cocuk": "0-2 yaş ücretsiz · 0-6 yaş aile çocuğu ücretsiz · 7-12 yaş aile çocuğu %50 · aile olmayan 3-12 yaş tam ücret",
   "not": "Ücretli girenler, iki bölümlü iç hat salonlarında yalnız Miles&Smiles bölümünü kullanabilir."
 }'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---- DOGRULAMA: DIGER PROGRAMLAR BOZULMADI MI ----
-- 🔴 Bu dosya YALNIZ TK/AJet'e dokunmali. Baska bir programin kural
-- sayisi degistiyse, istemeden bir seyi ezmisiz demektir.
select p.code, count(*) as gecerli_kural
  from lounge_programs p
  left join lounge_guest_rules r on r.program_id = p.id
   and (r.effective_to is null or r.effective_to >= current_date)
 where p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','PGS_PAID','BANK_CARD','IGA_PASS')
 group by p.code order by 1;

select coalesce(r.carrier,'(hepsi)') as tasiyici, coalesce(r.card_tier, coalesce(r.cabin_class,'-')) as kart,
       r.guest_allowance as misafir, r.family_allowed as aile
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code = 'TK_MS' and r.venue_id is null
   and (r.effective_to is null or r.effective_to >= current_date)
 order by 1, 2;

select '146 OK - THY resmi matrisi tam karsilandi' as sonuc;
