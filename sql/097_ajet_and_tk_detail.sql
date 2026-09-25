-- ============================================================
-- LoungeLink · 097_ajet_and_tk_detail.sql
-- AJET KURALI ÇÖZÜLDÜ + THY KART TİPİ AYRINTISI
--
-- ⚠️ Uygulamayı ETKİLER (veri seviyesinde): AJet host'ları artık doğru
-- karar alıyor. Şema değişikliği YOK.
--
-- ------------------------------------------------------------
-- 🔴 "AJet bilinmiyor kalacak" YANLIŞTI — Gokberk haklıydı.
--
-- ajet.com/cip-lounge sayfası istemci tarafında çiziliyor (HTML boş
-- geliyor), o yüzden doğrudan okunamadı. Ama kural AJet'te değil,
-- THY'DE yayınlanıyor — çünkü hakkı veren program Miles&Smiles:
--   turkishairlines.com → Miles&Smiles → Fırsatlar ve Ayrıcalıklar, not [23]
--   turkishairlines.com → Lounge Kuralları ve Koşulları (AJet bölümü)
-- Kaynağı doğru yerde aramamıştım.
--
-- ------------------------------------------------------------
-- ÇIKAN KURAL (resmî, not [23] birebir)
-- ------------------------------------------------------------
-- "AJet uçuşlarında Elite ve Elite Plus üyeler, aile bireyleriyle
--  (eş ve çocuklar) VEYA BİR MİSAFİRLE birlikte belirlenen salonlara
--  girebilir."
--
-- 🔴 GEÇERLİ HAVALİMANLARI SAYILIDIR:
--    Antalya · İzmir Adnan Menderes · Milas-Bodrum · Dalaman ·
--    Ankara Esenboğa · Mersin-Adana · Kayseri · Gaziantep · Hatay ·
--    Trabzon · Rize-Artvin · Diyarbakır
--
-- 🔴🔴 IST VE SAW BU LİSTEDE YOK.
-- Yani AJet ile uçan bir Elite Plus host, İSTANBUL'DA misafir
-- SOKAMAZ. Bu tam da kapıda geri çevrilmeye yol açacak türden bir
-- kuraldır ve bizim en yoğun havalimanımızı ilgilendiriyor.
-- Bilinmiyor bırakmak, burada "yanlış bilmek" kadar zararlı olurdu.
--
-- ÜCRETLİ GİRİŞ (Elite olmayan AJet yolcusu, THY lounge fiyat tablosu):
--    SAW 1200 TL · ESB 1200 TL · AYT/ADB/DLM 1350 TL · BJV 1450 TL
--    ADA/ASR/GZT/HTY/TZX/RZV/DIY 1000 TL
--    2 yaş altı bebek ücretsiz. Ücret ödeyen yolcu 0-6 yaş AİLE
--    çocuklarını ücretsiz sokabilir. 7-12 yaş aile çocuğu %50;
--    aile olmayan 3-12 yaş TAM ücret.
--    M&S üyesi olmayanlar dijital kart oluşturmak zorunda.
-- ============================================================


-- ============================================================
-- 1) AJET'İN GEÇERLİ OLDUĞU HAVALİMANLARINDA SALONLAR
-- (Yoksa oluştur; varsa dokunma.)
-- ============================================================
insert into lounge_venues (airport_code, name, terminal, operator, scope, notes)
select a.code, 'Turkish Airlines Lounge', 'Ic Hat', 'THY', 'domestic',
       'AJet uculariyla M&S Elite/Elite Plus erisimi bu havalimaninda GECERLI (not 23).'
  from airports a
 where a.code in ('AYT','ADB','BJV','DLM','ESB','ADA','ASR','GZT','HTY','TZX','RZV','DIY')
   and not exists (select 1 from lounge_venues v
                    where v.airport_code = a.code and lower(v.name) like '%turkish airlines%')
on conflict do nothing;

-- lounges katalogu da dolsun ki host ilan acarken salonu SECEBILSIN
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, true, v.id
  from lounge_venues v
 where v.legacy_lounge_id is null
   and not exists (select 1 from lounges l
                    where l.airport_code = v.airport_code
                      and lower(trim(l.name)) = lower(trim(v.name)));
update lounge_venues v set legacy_lounge_id = l.id
  from lounges l
 where v.legacy_lounge_id is null and l.venue_id = v.id;


-- ============================================================
-- 2) AJET × SALON — GEÇERLİ HAVALİMANLARI: MİSAFİR HAKKI VAR
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, children_note, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_carrier',
       '2 yas alti bebek ucretsiz. Ucret odeyen yolcu 0-6 yas AILE cocuklarini '
       || 'ucretsiz sokabilir; 7-12 yas aile cocugu %50, aile olmayan 3-12 yas TAM ucret.',
       'warn',
       'Elite / Elite Plus, AJet seferinde: aile (es + cocuklar) VEYA BIR MISAFIR. '
       || 'Misafirin de AJet seferinde ucuyor olmasi gerekir.',
       'https://www.turkishairlines.com/tr-tr/miles-and-smiles/mil-uygulamalari/firsatlar-ve-ayricaliklar/',
       current_date
  from lounge_venues v
  join lounge_programs p on p.code = 'AJET_MS'
 where v.active
   and v.airport_code in ('AYT','ADB','BJV','DLM','ESB','ADA','ASR','GZT','HTY','TZX','RZV','DIY')
on conflict (venue_id, program_id) do update set
  accepted = true, guest_policy = 'included', guest_included_count = 1,
  guest_flight_coupling = 'same_carrier',
  conditions = excluded.conditions, children_note = excluded.children_note,
  source_url = excluded.source_url, checked_at = excluded.checked_at;


-- ============================================================
-- 3) 🔴 IST VE SAW — AJET İLE MİSAFİR HAKKI YOK
--
-- En yoğun iki havalimanımız. Burayı 'unknown' bırakmak, host'un
-- misafiriyle kapıya gidip geri çevrilmesi demekti.
-- enforcement='block': bu satır GERÇEKTEN engeller, çünkü kaynak
-- resmî ve liste kapalı uçlu değil (sayılı havalimanı listesi).
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'not_allowed', 0, 'block',
       'AJet seferinde Miles&Smiles lounge erisimi YALNIZCA sayili havalimanlarinda '
       || 'gecerli (Antalya, Izmir, Bodrum, Dalaman, Esenboga, Adana, Kayseri, Gaziantep, '
       || 'Hatay, Trabzon, Rize, Diyarbakir). ISTANBUL BU LISTEDE YOK — AJet ucusunda '
       || 'Elite/Elite Plus karti burada lounge hakki vermez. Ucretli giris ayri deger'
       || 'lendirilir.',
       'https://www.turkishairlines.com/tr-tr/miles-and-smiles/mil-uygulamalari/firsatlar-ve-ayricaliklar/',
       current_date
  from lounge_venues v
  join lounge_programs p on p.code = 'AJET_MS'
 where v.active and v.airport_code in ('IST','SAW')
on conflict (venue_id, program_id) do update set
  guest_policy = 'not_allowed', guest_included_count = 0, enforcement = 'block',
  conditions = excluded.conditions, source_url = excluded.source_url,
  checked_at = excluded.checked_at;


-- ============================================================
-- 4) AJET PROGRAM MODELİ GÜNCELLENDİ (086'da "tanimli degil" idi)
-- ============================================================
update lounge_programs
   set guest_default = 'included',
       guest_included_count = 1,
       guest_flight_coupling = 'same_carrier',
       entitlement_model = 'airline_status',
       coverage_status = 'verified',
       enforcement = 'warn',
       rules_version = 'not 23 · 2026',
       checked_at = current_date,
       source_url = 'https://www.turkishairlines.com/tr-tr/miles-and-smiles/mil-uygulamalari/firsatlar-ve-ayricaliklar/',
       notes = 'AJet seferinde Elite/Elite Plus: aile VEYA 1 misafir. GECERLI HAVALIMANLARI '
            || 'SAYILI — IST ve SAW DAHIL DEGIL. Elite olmayan icin ucretli giris '
            || '(SAW/ESB 1200 TL, AYT/ADB/DLM 1350 TL, BJV 1450 TL, diger 1000 TL).'
 where code = 'AJET_MS';


-- ============================================================
-- 5) THY KART TİPİ AYRINTISI (resmî S.S.S. + lounge koşulları)
--
-- · Classic Plus: IC HAT seferlerinde Economy'de bile TK Lounge'a
--   girebilir — ama MISAFIR HAKKI YOK.
-- · Elite / Elite Plus: hem ic hem dis hatta BIR MISAFIR.
-- · Corporate Club: kartta yazan ulkedeki ortaklik salonu + Turkiye
--   ic/dis hat salonlari; Turkiye'de duzenlenmis kart yalnız Turkiye.
-- 086 bunlari program duzeyinde tutuyordu; kart tipi kirilimi
-- lounge_guest_rules'a yaziliyor ki karar motoru dogru satiri secsin.
-- ============================================================
insert into lounge_guest_rules
  -- Kolon adi `cabin_class`, `cabin` DEGIL (sema dokumunden teyit edildi).
  (program_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, 'TK', t.tier, t.allow, t.family, true, t.note, current_date
  from lounge_programs p,
       (values
         ('CLASSIC',      0::smallint, false, 'Classic: TK Lounge erisimi yok.'),
         ('CLASSIC_PLUS', 0::smallint, false,
          'Classic Plus: IC HAT seferlerinde Economy''de bile girebilir, MISAFIR HAKKI YOK.'),
         ('ELITE',        1::smallint, true,
          'Elite: ic ve dis hatta 1 misafir. Yurtdisinda Star Alliance Gold salonlari da 1 misafirle.'),
         ('ELITE_PLUS',   1::smallint, true,
          'Elite Plus: ic ve dis hatta 1 misafir VEYA aile (es + 25 yas alti cocuklar).'),
         ('CORP',         1::smallint, false,
          'Corporate Club: kartta yazan ulkedeki ortaklik salonu + Turkiye salonlari.')
       ) as t(tier, allow, family, note)
 where p.code = 'TK_MS'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.card_tier = t.tier and r.carrier = 'TK');


-- ============================================================
-- 6) DOĞRULAMA
-- ============================================================
select v.airport_code, v.name, a.guest_policy, a.enforcement,
       case when a.checked_at is null then 'varsayim' else 'dogrulandi' end as kaynak
  from lounge_venue_acceptance a
  join lounge_venues v on v.id = a.venue_id
  join lounge_programs p on p.id = a.program_id
 where p.code = 'AJET_MS'
 order by a.guest_policy, v.airport_code;

-- 🔴 DUZELTME: kolonlar NITELENMEMISTI. `notes` hem lounge_guest_rules'ta
-- hem lounge_programs'ta var; join'de cıplak yazilinca PostgreSQL
-- "42702 column reference notes is ambiguous" veriyor. Ayni tuzak
-- `active`, `name`, `checked_at`, `source_url` icin de gecerli —
-- JOIN'li her dogrulama sorgusunda kolonlar takma adla yazilmali.
select r.card_tier, r.guest_allowance, r.family_allowed, r.notes
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code = 'TK_MS' and r.card_tier is not null order by r.card_tier;

select '097 OK - AJet kurali resmi kaynaktan cozuldu; IST/SAW ENGELLI' as sonuc;
