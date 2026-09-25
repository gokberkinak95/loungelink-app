-- ============================================================
-- LoungeLink · 107_missing_airports.sql
-- 🔴 KURAL MATRISI HAVADA DURUYORDU: HAVALIMANLARI YOKTU
--
-- ⚠️ Uygulamayi ETKILER (veri).
--
-- ------------------------------------------------------------
-- NASIL BULUNDU
-- ------------------------------------------------------------
-- 18 senaryoyu gercek PostgreSQL'de kosarken kural16 (Dalaman) hic
-- gorunmedi. Sebebini arayinca: `airports` tablosunda yalnizca
-- IST, SAW, ADB, AYT, ESB varmis.
--
-- Bunun etkisi bir senaryodan cok daha buyuk. 097 ve 099'daki salon
-- eklemeleri sunu diyor:
--     where exists (select 1 from airports a where a.code = v.ap)
-- Yani havalimani yoksa SALON DA OLUSMUYOR — sessizce. Sonuc:
--   · AJet'in 12 gecerli havalimanindan 9'unun salonu HIC YARATILMADI
--   · Kart aglarinin (PP/LoungeKey/DragonPass) 9 havalimanindan
--     DLM, BJV, COV, DIY icin kabul satirlari HIC OLUSMADI
-- Kural matrisini titizlikle kurmustum ama ALTINDA ZEMIN YOKTU.
-- Host o havalimanini seciyor, lounge listesi bos geliyor, kural
-- motoru hicbir zaman devreye girmiyor.
--
-- Bu, "kural dogru mu" sorusundan once gelen bir soru: "kural
-- uygulanacak yer var mi?"
-- ============================================================

insert into airports (code, name, city, country, timezone) values
  ('DLM','Dalaman Havalimanı','Dalaman','TR','Europe/Istanbul'),
  ('BJV','Milas-Bodrum Havalimanı','Bodrum','TR','Europe/Istanbul'),
  ('COV','Çukurova Uluslararası Havalimanı','Mersin','TR','Europe/Istanbul'),
  ('DIY','Diyarbakır Havalimanı','Diyarbakır','TR','Europe/Istanbul'),
  ('ASR','Kayseri Erkilet Havalimanı','Kayseri','TR','Europe/Istanbul'),
  ('GZT','Gaziantep Oğuzeli Havalimanı','Gaziantep','TR','Europe/Istanbul'),
  ('HTY','Hatay Havalimanı','Hatay','TR','Europe/Istanbul'),
  ('TZX','Trabzon Havalimanı','Trabzon','TR','Europe/Istanbul'),
  ('RZV','Rize-Artvin Havalimanı','Rize','TR','Europe/Istanbul'),
  ('ADA','Adana Şakirpaşa Havalimanı','Adana','TR','Europe/Istanbul')
on conflict (code) do nothing;

-- ---- AJet'in gecerli oldugu havalimanlarinda TK CIP salonu ----
insert into lounge_venues (airport_code, name, terminal, operator, scope, venue_kind, notes)
select a.code, 'Turkish Airlines CIP Lounge', 'Ic Hat', 'THY', 'domestic', 'lounge',
       'THY ve AJet seferlerinde M&S kart sahiplerine acik ic hat CIP salonu.'
  from airports a
 where a.code in ('DLM','COV','ASR','GZT','HTY','TZX','RZV','DIY','ADA')
   and not exists (select 1 from lounge_venues v
                    where v.airport_code = a.code
                      and lower(v.name) like '%turkish airlines%')
on conflict (airport_code, name, coalesce(section, '')) do nothing;

-- ---- Kart aglarinin salonlari (dizinlerden okunan liste) ----
with v(ap, nm, term, op, pp, lk, dp) as (values
  ('BJV','Primeclass Lounge','Dış Hat','TAV', true , true , true ),
  ('BJV','Primeclass Lounge','İç Hat','TAV',  true , true , true ),
  ('DLM','CIP Lounge','Dış Hat (T2)','TAV',   true , true , true ),
  ('DLM','CIP Lounge','İç Hat (T2)','TAV',    true , true , null ),
  ('DLM','DLM Lounge','Terminal 2','—',       null , null , true ),
  ('DIY','CIP Lounge','Terminal','TAV',       true , true , true ),
  ('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi', true, true, true),
  ('COV','Çelebi Platinum Lounge','İç Hat','Çelebi',  true, true, true)
)
insert into lounge_venues (airport_code, name, terminal, operator, venue_kind, scope, notes)
select v.ap, v.nm || ' — ' || v.term, v.term, v.op, 'lounge',
       case when v.term ilike '%İç%' then 'domestic'
            when v.term ilike '%Dış%' then 'international' else 'both' end,
       '107: havalimani eksik oldugu icin 099''da olusturulamamisti.'
  from v where exists (select 1 from airports a where a.code = v.ap)
on conflict (airport_code, name, coalesce(section, '')) do nothing;

-- Katalog
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, true, v.id
  from lounge_venues v
 where v.venue_kind = 'lounge' and v.legacy_lounge_id is null
   and v.section is null and v.section_of is null
   and not exists (select 1 from lounges l where l.venue_id = v.id);
update lounge_venues v set legacy_lounge_id = l.id
  from lounges l where v.legacy_lounge_id is null and l.venue_id = v.id;

-- ---- AJet kabulu (097 ile ayni kural) ----
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, earliest_entry_hours, enforcement, conditions,
   source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_carrier', 2, 'warn',
       'Elite / Elite Plus / Elite Corporate: UCRETSIZ, aile VEYA bir misafir. '
       || 'Classic ve Classic Plus: ucretli giris, misafir hakki YOK. '
       || 'Misafirin de AJet seferinde ucmasi SART.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', current_date
  from lounge_venues v join lounge_programs p on p.code = 'AJET_MS'
 where v.active and lower(v.name) like '%turkish airlines%'
   and v.airport_code in ('DLM','COV','ASR','GZT','HTY','TZX','RZV','DIY','ADA')
on conflict (venue_id, program_id) do nothing;

-- ---- THY kabulu ----
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1, 'same_carrier', 'warn',
       'Misafir hakki KART TIPINE bagli (Elite ve ustu 1 misafir/aile; '
       || 'Classic Plus ve Classic hak YOK). Misafir de TK seferinde ucmali.',
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
       current_date
  from lounge_venues v join lounge_programs p on p.code = 'TK_MS'
 where v.active and lower(v.name) like '%turkish airlines%'
   and v.airport_code in ('DLM','COV','ASR','GZT','HTY','TZX','RZV','DIY','ADA')
on conflict (venue_id, program_id) do nothing;

-- ---- Kart aglari kabulu ----
with v(ap, nm, pp, lk, dp) as (values
  ('BJV','Primeclass Lounge — Dış Hat', true , true , true ),
  ('BJV','Primeclass Lounge — İç Hat',  true , true , true ),
  ('DLM','CIP Lounge — Dış Hat (T2)',   true , true , true ),
  ('DLM','CIP Lounge — İç Hat (T2)',    true , true , null ),
  ('DLM','DLM Lounge — Terminal 2',     null , null , true ),
  ('DIY','CIP Lounge — Terminal',       true , true , true ),
  ('COV','Çelebi Platinum Lounge — Dış Hat', true, true, true),
  ('COV','Çelebi Platinum Lounge — İç Hat',  true, true, true)
)
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, guest_fee_note, max_stay_hours, enforcement,
   conditions, source_url, checked_at)
select lv.id, p.id, true, 'paid', 0,
       case when p.code = 'DRAGONPASS' then 'same_flight' else 'any' end,
       'Ucret kisi basi ve ziyaret basina; misafir de UYENIN KARTINDAN tahsil edilir. '
       || 'Tutar karti veren kuruma gore degisir.',
       case when v.ap = 'DIY' then 3 when p.code = 'DRAGONPASS' then 2 end,
       'warn',
       case when p.code = 'DRAGONPASS'
            then 'DragonPass: misafirin uyeyle AYNI UCUSTA olmasi gerekir.'
            else 'Misafirin uctugu havayolu onemsiz; kendi binis karti ve kimligi gerekir.' end,
       case p.code
         when 'PRIORITY_PASS' then 'https://www.prioritypass.com/tr-TR/lounges/turkey'
         when 'LOUNGEKEY'     then 'https://www.loungekey.com/tr/lounge-finder/country?countrycode=TUR'
         else 'https://www.dragonpass.com/explore/country/turkey/TR' end,
       current_date
  from v
  join lounge_venues lv on lv.airport_code = v.ap and lv.name = v.nm
  join lounge_programs p on (p.code='PRIORITY_PASS' and v.pp)
                         or (p.code='LOUNGEKEY' and v.lk)
                         or (p.code='DRAGONPASS' and v.dp)
on conflict (venue_id, program_id) do nothing;

-- ---- Isletmeci programi kendi salonunda gecerlidir ----
-- Plaza Premium / Primeclass kendi salonlarinda kabul edilir; bunu
-- 'unknown' birakmak, bilinen bir seyi saklamakti.
update lounge_venue_acceptance a
   set guest_policy = 'paid', fee_payer = 'guest_at_door',
       conditions = 'Isletmecinin kendi salonu: giris ucretli, misafir kapida oder. '
                 || 'Tutar kanala gore degisir (onceden satin alma / walk-up).',
       checked_at = current_date
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and a.guest_policy = 'unknown'
   and ((p.code = 'PLAZA_PREMIUM' and lower(v.name) like '%plaza premium%')
     or (p.code = 'PRIMECLASS'    and lower(v.name) like '%primeclass%'));

-- ============================================================
-- DOGRULAMA
-- ============================================================
select a.code, count(distinct v.id) as salon,
       count(*) filter (where lva.active) as kabul_satiri
  from airports a
  left join lounge_venues v on v.airport_code = a.code and v.active
  left join lounge_venue_acceptance lva on lva.venue_id = v.id
 group by a.code order by a.code;

select '107 OK - eksik havalimanlari ve salonlari eklendi' as sonuc;
