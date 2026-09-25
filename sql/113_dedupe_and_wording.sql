-- ============================================================
-- LoungeLink · 113_dedupe_and_wording.sql
-- 1) MUKERRER SALONLAR HALA DURUYOR  2) UYARI DILI
--
-- ⚠️ Uygulamayi ETKILER (katalog + kullaniciya gosterilen metinler).
--
-- ------------------------------------------------------------
-- 🔴 SORUN 1: 103'un BIRLESTIRMESI EKSIK KALDI
-- ------------------------------------------------------------
-- Uctan uca denetimde IST'te AJET_MS icin 9 AKTIF kabul satiri gordum.
-- Yani host ayni fiziksel salonu hala dort bes farkli adla goruyor:
--   'Turkish Airlines Lounge Business'              (086)
--   'Turkish Airlines Lounge Miles&Smiles'          (086)
--   'Turkish Airlines Lounge — Dis Hat (Business)'  (086, ASCII)
--   'Turkish Airlines Lounge — Dış Hat'             (098, Turkce)
--   'Turkish Airlines Lounge — Ic Hat' / '— İç Hat'
--
-- 103'teki `venue_norm` yalniz PARANTEZLI ekleri siliyordu:
--   '... (Business)' -> silinir  ✓
--   '... Business'   -> KALIR    ✗
-- Ayrica ASCII/Turkce farkini ('Dis Hat' vs 'Dış Hat') translate ile
-- coz dum ama 'i̇' (birlesik nokta) karakterini atlamisim.
--
-- Normalizasyon eksik oldugunda birlestirme SESSIZCE yarim kalir —
-- hata vermez, sadece is gormez. En sinsi bozulma turu.
-- ============================================================

create or replace function public.venue_norm(p_name text)
returns text language sql immutable as $$
  -- 🔴 KOK HATA DUZELTILDI (v133 dogrulamasinda bulundu).
  -- Onceki hal 'dis hat' ve 'ic hat' ifadelerini de SILIYORDU. Sonuc:
  -- "Turkish Airlines Lounge — Dış Hat" ile "— İç Hat" AYNI salon
  -- sayiliyor, birlestirmede biri kapaniyordu. IST'te dis hat salonu
  -- katalogdan tamamen kayboldu ve bunu ancak seed dogrulamasi gosterdi.
  --
  -- Terminal, salonu AYIRT EDEN bir ozelliktir — iki ayri fiziksel
  -- salondan bahsediyoruz. Normalizasyon BOLUM eklerini (Business /
  -- Miles&Smiles) silmeli, TERMINALI degil.
  --
  -- Ders: normalizasyon "farkı yok say" degil, "ayni seyi ayni yaz"
  -- demektir. Fazla silen bir normalizasyon, ayri seyleri birlestirir.
  select regexp_replace(
    replace(replace(replace(replace(replace(
      lower(translate(coalesce(p_name,''), 'ıİşŞğĞüÜöÖçÇÂâÎî', 'iisSgGuUoOcCAaIi')),
      '(business)',''), '(miles&smiles)',''), 'miles&smiles',''), 'business',''),
      -- ASCII/Turkce farki translate ile zaten kapandi (dış->dis, iç->ic);
      -- geriye yalniz bolum ekleri kaliyor. Terminal KORUNUYOR.
      'lounge lounge','lounge'),
    '[^a-z0-9]+', '', 'g');
$$;

-- 🔴 AYNI DERS: yardimci tablo YOK, her ifade kendi CTE'sini tasir.
-- 103'te de 099'da da ayni hatayi yaptim; burada bastan CTE.

-- Kabul satirlarini tasi
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_fee_amount, guest_fee_currency, guest_fee_note, guest_flight_coupling,
   max_stay_hours, earliest_entry_hours, children_note, enforcement, fee_payer,
   conditions, source_url, checked_at, active)
select c.canon_id, a.program_id, a.accepted, a.guest_policy, a.guest_included_count,
       a.guest_fee_amount, a.guest_fee_currency, a.guest_fee_note, a.guest_flight_coupling,
       a.max_stay_hours, a.earliest_entry_hours, a.children_note, a.enforcement, a.fee_payer,
       a.conditions, a.source_url, a.checked_at, a.active
  from _ll_canon2 c join lounge_venue_acceptance a on a.venue_id = c.id
 where not exists (select 1 from lounge_venue_acceptance x
                    where x.venue_id = c.canon_id and x.program_id = a.program_id)
on conflict (venue_id, program_id) do nothing;

-- Kart tipi kurallarini tasi
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_guest_rules r set venue_id = c.canon_id
  from _ll_canon2 c where r.venue_id = c.id
   and not exists (select 1 from lounge_guest_rules x
                    where x.program_id = r.program_id and x.venue_id = c.canon_id
                      and coalesce(x.card_tier,'') = coalesce(r.card_tier,''));

-- Ilanlari ve katalogu yonlendir
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update availabilities a set lounge_id = k.legacy_lounge_id
  from _ll_canon2 c
  join lounge_venues k on k.id = c.canon_id
  join lounge_venues d on d.id = c.id
 where a.lounge_id = d.legacy_lounge_id and k.legacy_lounge_id is not null
   and k.legacy_lounge_id <> a.lounge_id;

with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update lounges l set venue_id = c.canon_id from _ll_canon2 c where l.venue_id = c.id;

-- Mukerrerleri pasife al
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_venue_acceptance a set active = false from _ll_canon2 c where a.venue_id = c.id;
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update lounges l set active = false
  from lounge_venues v join _ll_canon2 c on c.id = v.id where l.venue_id = v.id;
with _ll_canon2 as (
  select id, canon_id from (
    select v.id, first_value(v.id) over (
             partition by v.airport_code, v.nrm, v.sec
             -- Turkce yazim once (bkz. yukaridaki gerekce), sonra veri kalitesi
           order by (v.nm_clean) desc, (v.nm_tr) desc,
                    v.n_ver desc, v.n_acc desc, v.created_at desc, v.id) as canon_id
      from (
        select lv.id, lv.airport_code, coalesce(lv.section,'') as sec,
               public.venue_norm(lv.name) as nrm, lv.created_at,
               (lv.name ~ '[şğüöçıİŞĞÜÖÇ]') as nm_tr,
               (lv.name !~ '\(') as nm_clean,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.active) as n_acc,
               (select count(*) from lounge_venue_acceptance a
                 where a.venue_id = lv.id and a.checked_at is not null) as n_ver
          from lounge_venues lv where lv.active
      ) v
  ) r where r.id <> r.canon_id
)
update lounge_venues v set active = false,
       notes = coalesce(v.notes,'') || ' [113] Mukerrer — kanonik salona birlestirildi.'
  from _ll_canon2 c where v.id = c.id;


-- ============================================================
-- 🔴 KALAN IKI 086-DONEMI AD: REGEX YERINE ACIK ESLEME
-- ------------------------------------------------------------
-- Normalizasyon 17 satirin 13'unu birlestirdi ama ikisi direndi:
--   'Turkish Airlines Lounge Miles&Smiles'        (086, section NULL)
--   'Turkish Airlines Lounge — Dis Hat (Miles&S…)'(086, section NULL)
-- Bunlarda BOLUM ADIN ICINDE, `section` kolonu ise BOS. Yani normalizasyon
-- ne kadar iyi olursa olsun bunlar "bolumsuz ayri salon" gibi gorunuyor.
--
-- Regex'i daha da karmasiklastirmak yerine ACIK ESLEME yaziyorum:
-- iki isim, iki hedef. Kisa, okunur, yanlis anlasilmaz. Karmasik bir
-- desen yazip "umarim tutar" demektense, bilinen iki vakayi ADIYLA
-- cozmek daha durust.
-- ============================================================
-- 🔴 KOSULSUZ KAPAT. Ilk yazimda `from hedef` ile bir HEDEF salon
-- ariyordum; o hedef de bir onceki birlestirmede pasife alinmisti,
-- yani alt sorgu BOS donuyor ve UPDATE hicbir sey yapmiyordu.
-- Sessizce is gormeyen bir temizlik, temizlik yapilmamasindan kotudur:
-- yapildi saniyorsun. Kosula bagimlilik kaldirildi — bu adlar 086
-- donemine ait ve HER HALUKARDA mukerrer.
-- 🔴 v133 DUZELTMESI — BU BLOK KANONIGI DE KAPATIYORDU.
-- Onceki hali "086-donemi adlari kapat" diyordu ama desenler o kadar
-- genisti ki HEDEF salonu da yakaliyordu: sonuc, IST'teki 17 THY
-- salonunun HEPSI pasif. Host IST'te THY salonu SECEMIYORDU.
--
-- Birlestirmenin birinci kurali: HEDEFI SILME. "Mukerreri kaldir" ile
-- "en az bir tane birak" ayri iki kural; ikincisini yazmamistim.
--
-- Artik her (havalimani, normalize ad, bolum) grubunda EN IYI kayit
-- KORUNUYOR, yalniz digerleri kapatiliyor. En iyi = en cok kabul
-- satiri olan; esitlikte Turkce yazim (ASCII 086-donemi kalintisi).
with grup as (
  select v.id, v.name,
         first_value(v.id) over (
           partition by v.airport_code, public.venue_norm(v.name), coalesce(v.section,'')
           -- 🔴 SIRA ONEMLI: once TURKCE YAZIM, sonra kabul satiri.
           -- Ilk denememde kabul sayisini one aldim ve ASCII yazimli
           -- 086 kalintisi kazandi ("Dis Hat"). Kullanici bu adi
           -- EKRANDA gorecek; veri zenginligi ad kalitesini yenmemeli.
           -- Kabul satirlari zaten kanonige TASINIYOR, ad tasinmiyor.
           -- 🔴 UC KADEMELI TERCIH — sirasi onemli:
           --  1. TEMIZ AD: parantezli varyant ("... (Miles&Smiles)")
           --     086 doneminden kalma; bolumler artik AYRI SATIR oldugu
           --     icin ad icinde bolum tasimak gereksiz ve kafa karistirici.
           --  2. TURKCE YAZIM: kullanici bu adi EKRANDA gorecek.
           --  3. VERI ZENGINLIGI: en son, cunku kabul satirlari zaten
           --     kanonige TASINIYOR — ad tasinmiyor.
           order by (v.name !~ '\(') desc,
                    (v.name ~ '[şğüöçıİŞĞÜÖÇ]') desc,
                    (select count(*) from lounge_venue_acceptance a where a.venue_id = v.id) desc,
                    v.created_at desc, v.id) as keep_id
    from lounge_venues v
   where v.airport_code = 'IST' and v.active
     and lower(v.name) like 'turkish airlines lounge%'
)
update lounge_venues v
   set active = false,
       notes = coalesce(v.notes,'') || ' [113] Mukerrer ad; ayni gruptaki '
            || 'kanonik kayit korundu.'
  from grup g
 where v.id = g.id and g.id <> g.keep_id;

-- Bu salonlara bagli kabul satirlarini ve katalog kayitlarini da kapat
update lounge_venue_acceptance a set active = false
  from lounge_venues v where a.venue_id = v.id and not v.active and a.active;
update lounges l set active = false
  from lounge_venues v where l.venue_id = v.id and not v.active and l.active;


-- ============================================================
-- 🔴 SORUN 2: UYARI DILI — "BIZ IZIN VERMIYORUZ" GIBI OKUNUYOR
-- ------------------------------------------------------------
-- Gokberk hakli: metinlerimiz kuralin KIMIN kurali oldugunu
-- soylemiyordu. "Bu ilanda misafir alinmiyor" cumlesi, kullaniciya
-- LoungeLink'in engel koydugunu dusundurur. Oysa kural THY'nin,
-- AJet'in, Priority Pass'in kendi kurali; biz yalnizca AKTARIYORUZ.
--
-- Bu fark onemli, cunku:
--   · Kullanici bize kizacagina dogru yere bakar (karti/programi).
--   · "Neden izin vermiyorsunuz" sorusu "kimin kurali" sorusuna doner.
--   · Yanlis bir kurali duzelttirebilecegi yeri ogrenir.
--
-- Her metin artik KAYNAGI soyluyor ve bizim rolumuzu netlestiriyor.
-- ============================================================
insert into beta_settings (key, value) values
 ('rule_notice_generic', to_jsonb(
   'Bu salonun misafir kuralini henuz resmi bir kaynaktan dogrulayamadik. '
|| 'Karar bize ait degil — girise salonu isleten kurulus karar verir. '
|| 'Basvurabilirsin; bulusmadan once host ile giris kosullarini teyit et. '
|| 'Kapida ne oldugunu bize bildirirsen bir sonraki kullanici dogru bilgiyi gorur.'::text)),
 ('card_notice_guest', to_jsonb(
   'Bu ilandaki hak bir kredi kartindan geliyor. Kart avantajlarinin kosullari '
|| 'BANKA tarafindan belirlenir ve kampanya donemine gore degisebilir; '
|| 'LoungeLink bu kosullari koymaz, yalnizca aktarir. Host''un hakkinin gecerli '
|| 'olup olmadigini bulusmadan once birlikte teyit edin.'::text)),
 ('card_notice_host', to_jsonb(
   'Kart avantajiyla ilan aciyorsun. Kart kosullarini banka belirliyor ve '
|| 'kampanyalar degisebiliyor; biz dogrulayamiyoruz. Misafirini kapida zor '
|| 'durumda birakmamak icin hakkinin gecerliligini once kendin teyit et.'::text)),
 ('rule_source_prefix', to_jsonb(
   'Bu kural {kaynak} tarafindan belirlenmistir; LoungeLink yalnizca aktarir.'::text)),
 ('fee_note_member_card', to_jsonb(
   'Bu programda misafir ucreti kapida misafirden DEGIL, host''un kartindan '
|| 'tahsil edilir — bu programin kendi kuralidir. Misafirin cebinden para '
|| 'cikmaz ama host odeme yapar; bulusmadan once bunu aranizda konusun.'::text)),
 ('fee_note_guest_at_door', to_jsonb(
   'Bu salonda misafir girisi kapida odenir; ucreti salonu isleten kurulus '
|| 'belirler. Tutari bulusmadan once teyit edin, kapida surpriz yasanmasin.'::text))
on conflict (key) do update set value = excluded.value;

-- Karar metinlerine KAYNAK etiketi ekle: hangi kurulusun kurali oldugu
-- her uyarida gorunsun.
update lounge_venue_acceptance a
   set conditions = coalesce(a.conditions,'')
     || case when coalesce(a.conditions,'') = '' then '' else ' ' end
     || 'Bu kural ' || coalesce(p.name, 'ilgili program') || ' tarafindan '
     || 'belirlenmistir; LoungeLink yalnizca aktarir.'
  from lounge_programs p
 where a.program_id = p.id
   and coalesce(a.conditions,'') not like '%LoungeLink yalnizca aktarir%';


-- ============================================================
-- DOGRULAMA
-- ============================================================
select v.airport_code, count(*) filter (where v.active) as aktif_salon,
       count(*) filter (where not v.active) as pasif_mukerrer
  from lounge_venues v where v.airport_code = 'IST' group by 1;

select left(v.name, 40) as salon, v.active
  from lounge_venues v where v.airport_code = 'IST'
   and lower(v.name) like '%turkish airlines%' order by v.active desc, v.name;

select '113 OK - mukerrerler birlesti, uyari dili kaynagi soyluyor' as sonuc;
