-- ============================================================
-- LoungeLink · 099_card_networks_venue_level.sql
-- KART AĞLARI — SALON DÜZEYİNDE, ÜÇ RESMÎ DİZİNDEN
--
-- ⚠️ Uygulamayı ETKİLER (veri). 098'in kart ağı satırlarını DEĞİŞTİRİR.
--
-- ------------------------------------------------------------
-- 🔴 098'DEKİ FAZLA GENELLEME
-- ------------------------------------------------------------
-- 098'de "üç ağ da aynı 9 havalimanında" diye HAVALİMANI düzeyinde
-- yazmıştım. Doğruydu ama YETERSİZDİ: üç ağ aynı havalimanında
-- FARKLI SALONLARI kabul ediyor.
--
-- En net örnek Antalya:
--   Priority Pass -> CIP Lounge Domestic (T3) · Comfort Lounge (Dış T2)
--   LoungeKey     -> Elite Lounge (Dış T1) · CIP Lounge (Dış T2) · CIP Lounge (İç)
--   DragonPass    -> CIP Lounge · FTA Comfort Lounge
-- Üçü de "AYT'de var" ama üçü de farklı kapıdan giriyor. Havalimanı
-- düzeyinde yazsaydım, LoungeKey'li bir host Comfort Lounge'ı seçip
-- kapıda çevrilirdi.
--
-- Kaynakta GÖRÜLMEYEN her hücre 'unknown' kalır ve genel uyarıya düşer —
-- "dizinde yok" ile "kabul etmiyor" AYRI şeylerdir.
--
-- ------------------------------------------------------------
-- SALON MU, HİZMET Mİ?
-- ------------------------------------------------------------
-- Dizinlerde XpresSpa, iGA Sleepod, iGA Shower gibi kalemler de
-- "lounge" başlığı altında listeleniyor. Bunlar BULUŞULACAK YER
-- DEĞİL: spa, uyku kapsülü, duş. LoungeLink'in çekirdek eylemi iki
-- kişinin oturup tanışması olduğu için bunlar salon kataloğuna GİRMEZ
-- (host ilan açarken göremez), ama kural ekseninde kayıtlı kalır.
-- ============================================================

alter table lounge_venues add column if not exists venue_kind text;
alter table lounge_venues drop constraint if exists lv_kind_chk;
alter table lounge_venues add constraint lv_kind_chk
  check (venue_kind is null or venue_kind in ('lounge','sleep','spa','shower','fasttrack'));
comment on column lounge_venues.venue_kind is
  'lounge = bulusulabilecek salon (katalogda gorunur). sleep/spa/shower = ek hizmet.';

-- 🔴 YARDIMCI TABLO YOK.
-- Once `create temp table` denedim: Supabase SQL Editor ifadeleri ayri
-- baglantilarda calistirabildigi icin "42P01 relation _v does not exist"
-- verdi. Sonra GERCEK tabloya cevirdim; ayni hatayi verdi.
-- Kok cozum: ifadeler arasi bagimliligi TAMAMEN kaldirmak. Liste artik
-- her ifadenin ICINDE bir CTE olarak duruyor. Tekrar ama guvenli:
-- hicbir ifade bir oncekinin yan etkisine bagli degil, dosya bastan
-- sona tekrar calistirilabilir.


-- 1) SALONLARI YARAT
-- 🔴 DUZELTME: lounge_venues''un benzersiz indeksi
--   (airport_code, name, coalesce(section,''))
-- TERMINALI ICERMIYOR. IST''te "iGA Lounge" hem dis hem ic hat icin
-- ayni ad + ayni (bos) bolumle yaziliyordu ve 23505 veriyordu.
-- Ayni tuzak ESB/ADB/BJV Primeclass, DLM/AYT CIP, COV Celebi icin de vardi.
--
-- Terminali `section`a koymak COZUM DEGIL: 101, bolumu olan her satiri
-- ALT BOLUM sayip katalogdan gizliyor — dis hat salonu gorunmez olurdu.
-- Dogru yer AD: "iGA Lounge — Dış Hat". `terminal` kolonu da kaliyor.
with _v(ap, nm, term, op, kind, pp, lk, dp, note) as (values
('IST','iGA Lounge','Dış Hat','IGA','lounge',            true , true , true , null),
('IST','iGA Lounge','İç Hat','IGA','lounge',             true , true , null , 'DragonPass dizini terminal ayrimi yapmiyor; ic hat DOGRULANMADI.'),
('IST','iGA Pop-up Lounge','Dış Hat','IGA','lounge',     true , true , true , null),
('IST','iGA Sleepod','Dış Hat','IGA','sleep',            true , true , true , 'Uyku kapsulu — bulusma yeri degil.'),
('IST','iGA Shower','Dış Hat','IGA','shower',            null , null , true , 'Dus — bulusma yeri degil.'),
('IST','XpresSpa','Dış Hat','XpresSpa','spa',            true , true , null , 'Spa — bulusma yeri degil.'),
('SAW','Kepler Club','Dış Hat','Kepler','lounge',                          true , true , true , null),
('SAW','Plaza Premium Bosphorus Lounge','Dış Hat','Plaza Premium','lounge', true , true , null , 'DragonPass dizininde bu isim GORULMEDI.'),
('SAW','Plaza Premium Lounge — Marmara','Dış Hat','Plaza Premium','lounge', true , true , true , null),
('SAW','Plaza Premium Lounge','İç Hat','Plaza Premium','lounge',            true , true , true , null),
('ESB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ESB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('ADB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ADB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('BJV','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('BJV','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('AYT','CIP Lounge','İç Hat (T3)','TAV','lounge',        true , true , true , null),
('AYT','CIP Lounge','Dış Hat (T2)','TAV','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('AYT','Comfort Lounge','Dış Hat (T2)','FTA','lounge',   true , null , true , 'PP "Comfort Lounge", DragonPass "FTA Comfort Lounge". LoungeKey dizininde YOK.'),
('AYT','Elite Lounge','Dış Hat (T1)','-','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('DLM','CIP Lounge','Dış Hat (T2)','TAV','lounge',       true , true , true , null),
('DLM','CIP Lounge','İç Hat (T2)','TAV','lounge',        true , true , null , 'DragonPass terminal ayrimi yapmiyor.'),
('DLM','DLM Lounge','Terminal 2','-','lounge',           null , null , true , 'Yalniz DragonPass dizininde.'),
('DIY','CIP Lounge','Terminal','TAV','lounge',           true , true , true ,
 'LoungeKey kosullari: maksimum kalis 3 saat; kart sahibi VE MISAFIRLERIN ayni gun seyahat onayli binis karti gostermesi gerekir; 6 yas alti ucretsiz.'),
('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi','lounge', true , true , true , 'DragonPass "Platinum Lounge (International)".'),
('COV','Çelebi Platinum Lounge','İç Hat','Çelebi','lounge',  true , true , true , 'DragonPass "Platinum Lounge (Domestic)".')
)
insert into lounge_venues (airport_code, name, terminal, operator, venue_kind, scope, notes)
select v.ap,
       v.nm || case when v.term is not null then ' — ' || v.term else '' end,
       v.term, v.op, v.kind,
       case when v.term ilike '%İç%' then 'domestic'
            when v.term ilike '%Dış%' then 'international' else 'both' end,
       v.note
  from _v v
 where exists (select 1 from airports a where a.code = v.ap)
   and not exists (select 1 from lounge_venues x
                    where x.airport_code = v.ap
                      and lower(trim(x.name)) = lower(trim(
                            v.nm || case when v.term is not null then ' — ' || v.term else '' end))
                      and x.section is null)
-- 🔴 Ikinci emniyet: koruma kosulu ne kadar dogru yazilirsa yazilsin,
-- KISITIN kendisi son sozu soyler. `on conflict` ile dosya tekrar
-- calistirilabilir hale geliyor (099'da bir kez 23505 aldik).
on conflict (airport_code, name, coalesce(section, '')) do nothing;

with _v(ap, nm, term, op, kind, pp, lk, dp, note) as (values
('IST','iGA Lounge','Dış Hat','IGA','lounge',            true , true , true , null),
('IST','iGA Lounge','İç Hat','IGA','lounge',             true , true , null , 'DragonPass dizini terminal ayrimi yapmiyor; ic hat DOGRULANMADI.'),
('IST','iGA Pop-up Lounge','Dış Hat','IGA','lounge',     true , true , true , null),
('IST','iGA Sleepod','Dış Hat','IGA','sleep',            true , true , true , 'Uyku kapsulu — bulusma yeri degil.'),
('IST','iGA Shower','Dış Hat','IGA','shower',            null , null , true , 'Dus — bulusma yeri degil.'),
('IST','XpresSpa','Dış Hat','XpresSpa','spa',            true , true , null , 'Spa — bulusma yeri degil.'),
('SAW','Kepler Club','Dış Hat','Kepler','lounge',                          true , true , true , null),
('SAW','Plaza Premium Bosphorus Lounge','Dış Hat','Plaza Premium','lounge', true , true , null , 'DragonPass dizininde bu isim GORULMEDI.'),
('SAW','Plaza Premium Lounge — Marmara','Dış Hat','Plaza Premium','lounge', true , true , true , null),
('SAW','Plaza Premium Lounge','İç Hat','Plaza Premium','lounge',            true , true , true , null),
('ESB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ESB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('ADB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ADB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('BJV','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('BJV','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('AYT','CIP Lounge','İç Hat (T3)','TAV','lounge',        true , true , true , null),
('AYT','CIP Lounge','Dış Hat (T2)','TAV','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('AYT','Comfort Lounge','Dış Hat (T2)','FTA','lounge',   true , null , true , 'PP "Comfort Lounge", DragonPass "FTA Comfort Lounge". LoungeKey dizininde YOK.'),
('AYT','Elite Lounge','Dış Hat (T1)','-','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('DLM','CIP Lounge','Dış Hat (T2)','TAV','lounge',       true , true , true , null),
('DLM','CIP Lounge','İç Hat (T2)','TAV','lounge',        true , true , null , 'DragonPass terminal ayrimi yapmiyor.'),
('DLM','DLM Lounge','Terminal 2','-','lounge',           null , null , true , 'Yalniz DragonPass dizininde.'),
('DIY','CIP Lounge','Terminal','TAV','lounge',           true , true , true ,
 'LoungeKey kosullari: maksimum kalis 3 saat; kart sahibi VE MISAFIRLERIN ayni gun seyahat onayli binis karti gostermesi gerekir; 6 yas alti ucretsiz.'),
('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi','lounge', true , true , true , 'DragonPass "Platinum Lounge (International)".'),
('COV','Çelebi Platinum Lounge','İç Hat','Çelebi','lounge',  true , true , true , 'DragonPass "Platinum Lounge (Domestic)".')
)
update lounge_venues x set venue_kind = v.kind
  from _v v
 where x.airport_code = v.ap
   and lower(trim(x.name)) = lower(trim(
         v.nm || case when v.term is not null then ' — ' || v.term else '' end))
   and x.venue_kind is distinct from v.kind;

update lounge_venues set venue_kind = 'lounge' where venue_kind is null;

-- 2) KATALOG: yalniz 'lounge' turu host'a gosterilir
-- Ad zaten terminali tasiyor; katalogda TEKRAR eklemiyoruz
-- ("iGA Lounge — Dış Hat — Dış Hat" olurdu).
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, true, v.id
  from lounge_venues v
 where v.venue_kind = 'lounge' and v.legacy_lounge_id is null
   and not exists (select 1 from lounges l where l.venue_id = v.id);
update lounge_venues v set legacy_lounge_id = l.id
  from lounges l where v.legacy_lounge_id is null and l.venue_id = v.id;

update lounges l set active = false
  from lounge_venues v
 where l.venue_id = v.id and v.venue_kind <> 'lounge' and l.active;

-- 3) KART AGI x SALON
delete from lounge_venue_acceptance a
 using lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   and lower(v.name) not like '%turkish airlines%';

with _v(ap, nm, term, op, kind, pp, lk, dp, note) as (values
('IST','iGA Lounge','Dış Hat','IGA','lounge',            true , true , true , null),
('IST','iGA Lounge','İç Hat','IGA','lounge',             true , true , null , 'DragonPass dizini terminal ayrimi yapmiyor; ic hat DOGRULANMADI.'),
('IST','iGA Pop-up Lounge','Dış Hat','IGA','lounge',     true , true , true , null),
('IST','iGA Sleepod','Dış Hat','IGA','sleep',            true , true , true , 'Uyku kapsulu — bulusma yeri degil.'),
('IST','iGA Shower','Dış Hat','IGA','shower',            null , null , true , 'Dus — bulusma yeri degil.'),
('IST','XpresSpa','Dış Hat','XpresSpa','spa',            true , true , null , 'Spa — bulusma yeri degil.'),
('SAW','Kepler Club','Dış Hat','Kepler','lounge',                          true , true , true , null),
('SAW','Plaza Premium Bosphorus Lounge','Dış Hat','Plaza Premium','lounge', true , true , null , 'DragonPass dizininde bu isim GORULMEDI.'),
('SAW','Plaza Premium Lounge — Marmara','Dış Hat','Plaza Premium','lounge', true , true , true , null),
('SAW','Plaza Premium Lounge','İç Hat','Plaza Premium','lounge',            true , true , true , null),
('ESB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ESB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('ADB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ADB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('BJV','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('BJV','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('AYT','CIP Lounge','İç Hat (T3)','TAV','lounge',        true , true , true , null),
('AYT','CIP Lounge','Dış Hat (T2)','TAV','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('AYT','Comfort Lounge','Dış Hat (T2)','FTA','lounge',   true , null , true , 'PP "Comfort Lounge", DragonPass "FTA Comfort Lounge". LoungeKey dizininde YOK.'),
('AYT','Elite Lounge','Dış Hat (T1)','-','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('DLM','CIP Lounge','Dış Hat (T2)','TAV','lounge',       true , true , true , null),
('DLM','CIP Lounge','İç Hat (T2)','TAV','lounge',        true , true , null , 'DragonPass terminal ayrimi yapmiyor.'),
('DLM','DLM Lounge','Terminal 2','-','lounge',           null , null , true , 'Yalniz DragonPass dizininde.'),
('DIY','CIP Lounge','Terminal','TAV','lounge',           true , true , true ,
 'LoungeKey kosullari: maksimum kalis 3 saat; kart sahibi VE MISAFIRLERIN ayni gun seyahat onayli binis karti gostermesi gerekir; 6 yas alti ucretsiz.'),
('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi','lounge', true , true , true , 'DragonPass "Platinum Lounge (International)".'),
('COV','Çelebi Platinum Lounge','İç Hat','Çelebi','lounge',  true , true , true , 'DragonPass "Platinum Lounge (Domestic)".')
)
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, guest_fee_note, max_stay_hours, children_note,
   enforcement, conditions, source_url, checked_at)
select lv.id, p.id, true, 'paid', 0,
       case when p.code = 'DRAGONPASS' then 'same_flight' else 'any' end,
       'Ucret kisi basi ve ziyaret basina; misafir de uyenin kartindan tahsil edilir. Tutar uyelik planina ve salona gore degisir.',
       case when v.ap = 'DIY' then 3 when p.code = 'DRAGONPASS' then 2 end,
       case when v.ap = 'DIY' then '6 yas alti ucretsiz.' end,
       'warn',
       case when p.code = 'DRAGONPASS'
            then 'DragonPass md.7.15.7: misafirin uyeyle AYNI UCUSTA olmasi gerekir. Uyelik devredilemez, kalis tipik 2 saat.'
            else 'Misafirin uctugu havayolu ONEMSIZ. Misafir uyeyle AYNI ANDA kaydolup girmeli; kendi binis karti (ayni gun seyahat onayli) ve kimligi gerekir. Erisim araci devredilemez.' end
       || coalesce(' ' || v.note, ''),
       case p.code
         when 'PRIORITY_PASS' then 'https://www.prioritypass.com/tr-TR/lounges/turkey'
         when 'LOUNGEKEY'     then 'https://www.loungekey.com/tr/lounge-finder/country?countrycode=TUR'
         else 'https://www.dragonpass.com/explore/country/turkey/TR' end,
       current_date
  from _v v
  join lounge_venues lv
    on lv.airport_code = v.ap
   and lower(trim(lv.name)) = lower(trim(
         v.nm || case when v.term is not null then ' — ' || v.term else '' end))
  join lounge_programs p
    on (p.code = 'PRIORITY_PASS' and v.pp)
    or (p.code = 'LOUNGEKEY'     and v.lk)
    or (p.code = 'DRAGONPASS'    and v.dp)
on conflict (venue_id, program_id) do update set
  accepted = true, guest_policy = 'paid',
  guest_flight_coupling = excluded.guest_flight_coupling,
  conditions = excluded.conditions, source_url = excluded.source_url,
  checked_at = excluded.checked_at;

-- Dizinde GORULMEYEN hucreler: "kabul etmiyor" DEGIL, "bilinmiyor"
with _v(ap, nm, term, op, kind, pp, lk, dp, note) as (values
('IST','iGA Lounge','Dış Hat','IGA','lounge',            true , true , true , null),
('IST','iGA Lounge','İç Hat','IGA','lounge',             true , true , null , 'DragonPass dizini terminal ayrimi yapmiyor; ic hat DOGRULANMADI.'),
('IST','iGA Pop-up Lounge','Dış Hat','IGA','lounge',     true , true , true , null),
('IST','iGA Sleepod','Dış Hat','IGA','sleep',            true , true , true , 'Uyku kapsulu — bulusma yeri degil.'),
('IST','iGA Shower','Dış Hat','IGA','shower',            null , null , true , 'Dus — bulusma yeri degil.'),
('IST','XpresSpa','Dış Hat','XpresSpa','spa',            true , true , null , 'Spa — bulusma yeri degil.'),
('SAW','Kepler Club','Dış Hat','Kepler','lounge',                          true , true , true , null),
('SAW','Plaza Premium Bosphorus Lounge','Dış Hat','Plaza Premium','lounge', true , true , null , 'DragonPass dizininde bu isim GORULMEDI.'),
('SAW','Plaza Premium Lounge — Marmara','Dış Hat','Plaza Premium','lounge', true , true , true , null),
('SAW','Plaza Premium Lounge','İç Hat','Plaza Premium','lounge',            true , true , true , null),
('ESB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ESB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('ADB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ADB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('BJV','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('BJV','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('AYT','CIP Lounge','İç Hat (T3)','TAV','lounge',        true , true , true , null),
('AYT','CIP Lounge','Dış Hat (T2)','TAV','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('AYT','Comfort Lounge','Dış Hat (T2)','FTA','lounge',   true , null , true , 'PP "Comfort Lounge", DragonPass "FTA Comfort Lounge". LoungeKey dizininde YOK.'),
('AYT','Elite Lounge','Dış Hat (T1)','-','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('DLM','CIP Lounge','Dış Hat (T2)','TAV','lounge',       true , true , true , null),
('DLM','CIP Lounge','İç Hat (T2)','TAV','lounge',        true , true , null , 'DragonPass terminal ayrimi yapmiyor.'),
('DLM','DLM Lounge','Terminal 2','-','lounge',           null , null , true , 'Yalniz DragonPass dizininde.'),
('DIY','CIP Lounge','Terminal','TAV','lounge',           true , true , true ,
 'LoungeKey kosullari: maksimum kalis 3 saat; kart sahibi VE MISAFIRLERIN ayni gun seyahat onayli binis karti gostermesi gerekir; 6 yas alti ucretsiz.'),
('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi','lounge', true , true , true , 'DragonPass "Platinum Lounge (International)".'),
('COV','Çelebi Platinum Lounge','İç Hat','Çelebi','lounge',  true , true , true , 'DragonPass "Platinum Lounge (Domestic)".')
)
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   enforcement, conditions, checked_at)
select lv.id, p.id, true, 'unknown', 0, 'warn',
       'Bu salon ' || p.name || ' resmi dizininde GORULMEDI. Bu, kabul etmedigi anlamina GELMEZ — dizin eksik ya da yeni eklenmis olabilir. Girisi kapida teyit et.',
       null
  from _v v
  join lounge_venues lv
    on lv.airport_code = v.ap
   and lower(trim(lv.name)) = lower(trim(
         v.nm || case when v.term is not null then ' — ' || v.term else '' end))
  join lounge_programs p
    on (p.code = 'PRIORITY_PASS' and v.pp is null)
    or (p.code = 'LOUNGEKEY'     and v.lk is null)
    or (p.code = 'DRAGONPASS'    and v.dp is null)
on conflict (venue_id, program_id) do nothing;

with _v(ap, nm, term, op, kind, pp, lk, dp, note) as (values
('IST','iGA Lounge','Dış Hat','IGA','lounge',            true , true , true , null),
('IST','iGA Lounge','İç Hat','IGA','lounge',             true , true , null , 'DragonPass dizini terminal ayrimi yapmiyor; ic hat DOGRULANMADI.'),
('IST','iGA Pop-up Lounge','Dış Hat','IGA','lounge',     true , true , true , null),
('IST','iGA Sleepod','Dış Hat','IGA','sleep',            true , true , true , 'Uyku kapsulu — bulusma yeri degil.'),
('IST','iGA Shower','Dış Hat','IGA','shower',            null , null , true , 'Dus — bulusma yeri degil.'),
('IST','XpresSpa','Dış Hat','XpresSpa','spa',            true , true , null , 'Spa — bulusma yeri degil.'),
('SAW','Kepler Club','Dış Hat','Kepler','lounge',                          true , true , true , null),
('SAW','Plaza Premium Bosphorus Lounge','Dış Hat','Plaza Premium','lounge', true , true , null , 'DragonPass dizininde bu isim GORULMEDI.'),
('SAW','Plaza Premium Lounge — Marmara','Dış Hat','Plaza Premium','lounge', true , true , true , null),
('SAW','Plaza Premium Lounge','İç Hat','Plaza Premium','lounge',            true , true , true , null),
('ESB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ESB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('ADB','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('ADB','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('BJV','Primeclass Lounge','Dış Hat','TAV','lounge',     true , true , true , null),
('BJV','Primeclass Lounge','İç Hat','TAV','lounge',      true , true , true , null),
('AYT','CIP Lounge','İç Hat (T3)','TAV','lounge',        true , true , true , null),
('AYT','CIP Lounge','Dış Hat (T2)','TAV','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('AYT','Comfort Lounge','Dış Hat (T2)','FTA','lounge',   true , null , true , 'PP "Comfort Lounge", DragonPass "FTA Comfort Lounge". LoungeKey dizininde YOK.'),
('AYT','Elite Lounge','Dış Hat (T1)','-','lounge',       null , true , null , 'Yalniz LoungeKey dizininde.'),
('DLM','CIP Lounge','Dış Hat (T2)','TAV','lounge',       true , true , true , null),
('DLM','CIP Lounge','İç Hat (T2)','TAV','lounge',        true , true , null , 'DragonPass terminal ayrimi yapmiyor.'),
('DLM','DLM Lounge','Terminal 2','-','lounge',           null , null , true , 'Yalniz DragonPass dizininde.'),
('DIY','CIP Lounge','Terminal','TAV','lounge',           true , true , true ,
 'LoungeKey kosullari: maksimum kalis 3 saat; kart sahibi VE MISAFIRLERIN ayni gun seyahat onayli binis karti gostermesi gerekir; 6 yas alti ucretsiz.'),
('COV','Çelebi Platinum Lounge','Dış Hat','Çelebi','lounge', true , true , true , 'DragonPass "Platinum Lounge (International)".'),
('COV','Çelebi Platinum Lounge','İç Hat','Çelebi','lounge',  true , true , true , 'DragonPass "Platinum Lounge (Domestic)".')
)

-- 4) DOGRULAMA
select v.airport_code, v.name, coalesce(v.terminal,'-') as terminal, v.venue_kind,
       max(case when p.code='PRIORITY_PASS' then a.guest_policy end) as priority_pass,
       max(case when p.code='LOUNGEKEY'     then a.guest_policy end) as loungekey,
       max(case when p.code='DRAGONPASS'    then a.guest_policy end) as dragonpass
  from lounge_venues v
  left join lounge_venue_acceptance a on a.venue_id = v.id
  left join lounge_programs p on p.id = a.program_id
 where v.airport_code in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','DIY','COV')
 group by v.airport_code, v.name, v.terminal, v.venue_kind
 order by v.airport_code, v.name, v.terminal;

select venue_kind, count(*) as salon,
       count(*) filter (where legacy_lounge_id is not null) as katalogda
  from lounge_venues group by venue_kind order by 1;

select '099 OK - kart aglari SALON duzeyinde islendi; ek hizmetler katalog disi' as sonuc;
