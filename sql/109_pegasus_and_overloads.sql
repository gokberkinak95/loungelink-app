-- ============================================================
-- LoungeLink · 109_pegasus_and_overloads.sql
-- PEGASUS MISAFIR POLITIKASI + ASIRI YUKLEME TEMIZLIGI
--
-- ⚠️ Uygulamayi ETKILER (veri + fonksiyon temizligi).
--
-- ------------------------------------------------------------
-- 1) PEGASUS: "MISAFIR HAKKI" YOK, KISI BASI INDIRIM VAR
-- ------------------------------------------------------------
-- flypgs.com/lounge okundu. Onemli olan sey fiyat degil MODEL:
-- Pegasus'ta misafir kavrami YOKTUR. Herkes KENDI adina, kisi basi
-- oder; Pegasus'un yaptigi indirimli tarife sunmaktir. Ve indirimin
-- sarti net: "lounge girisinde PEGASUS BINIS KARTINI gostererek
-- odeme yapmak".
--
-- 🔴 BUNUN KURAL SONUCU: misafir Pegasus'ta UCMUYORSA indirimli
-- tarifeden yararlanamaz — tam ucret oder ya da hic giremez. Yani
-- coupling 'any' DEGIL 'same_carrier'. Onceki halde 'any' yazsaydim,
-- THY ile ucan bir misafire "63 EUR oder girersin" derdik; kapida
-- "sizin biniz kartiniz Pegasus degil" cevabini alirdi.
--
-- RESMI TARIFE (KDV dahil, 3 saat):
--   SAW Plaza Premium  : Ic Hat 49 EUR · Dis Hat 63 EUR
--   Primeclass BJV/ADB/ESB : 27 EUR + KDV
--   COV Celebi Platinum: Ic Hat 1.260 TL · Dis Hat 49,5 EUR
-- COCUK: Plaza Premium ve Celebi'de 6 yasina kadar UCRETSIZ,
--        Primeclass'ta 0-2 yas ucretsiz. (Ayni sirket degil, ayni
--        kural degil — tek cumleye indirgemedik.)
-- ============================================================

update lounge_programs
   set guest_default = 'paid',
       guest_included_count = 0,
       guest_flight_coupling = 'same_carrier',
       fee_payer = 'guest_at_door',
       max_stay_hours = 3,
       coverage_status = 'verified',
       checked_at = current_date,
       source_url = 'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge',
       notes = 'Pegasus''ta MISAFIR HAKKI YOK: herkes kisi basi oder, Pegasus indirimli '
            || 'tarife sunar. Indirim icin GIRISTE PEGASUS BINIS KARTI gosterilmeli — '
            || 'misafir Pegasus''ta ucmuyorsa bu tarifeden yararlanamaz. Kalis 3 saat.'
 where code = 'PGS_PAID';

-- Salon bazli tarife
-- 🔴 ISME GORE ESLESTIRME TUTMADI: salon adlari 099'da terminal ekiyle
-- degisti ve Turkce karakterli 'i̇ç' birlesik/ayrik yazilabiliyor.
-- Daha da kotusu: desen tutmayinca program duzeyindeki 63 EUR
-- LONDRA'daki Plaza Premium'a bile yazildi. Isim yerine HAVALIMANI +
-- ISLETMECI + KAPSAM ile eslestiriyoruz — bunlar yazima bagli degil.
-- 🔴 UPDATE YETMEZ, UPSERT GEREKIR.
-- BJV ve COV salonlari 107'de eklendi; 096'nin otomatik doldurmasi
-- ONLARDAN ONCE calismisti, yani o salonlarda PGS_PAID kabul satiri
-- HIC YOKTU. Sadece UPDATE yazinca "guncellenecek satir yok" diye
-- sessizce geciyordu — 107'de ogrendigimiz sessiz-atlama deseninin
-- aynisi. Var olani guncelle, olmayani OLUSTUR.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_fee_amount, guest_fee_currency, guest_flight_coupling, fee_payer,
   max_stay_hours, children_note, guest_fee_note, enforcement, conditions,
   source_url, checked_at)
-- 🔴 ON CONFLICT DO UPDATE ayni komutta ayni satiri IKI KEZ etkileyemez.
-- SAW icin listede iki satir var (ic hat 49 / dis hat 63) ve
-- `scope in (t.kapsam,'both')` esnekligi yuzunden scope'u 'both' olan
-- bir salon HER IKISINE de esliyordu -> ayni (venue,program) cifti iki
-- kez uretiliyordu. `distinct on` ile salon basina TEK satir birakiyoruz
-- ve TAM eslesmeyi (scope = kapsam) tercih ediyoruz.
select distinct on (v.id, p.id)
       v.id, p.id, true, 'paid', 0, t.tutar, t.birim, 'same_carrier',
       'guest_at_door', 3, t.cocuk,
       'Pegasus yolcularina ozel indirimli tarife. Indirim icin giriste PEGASUS '
       || 'BINIS KARTI gosterilmeli; misafirin de Pegasus''ta ucuyor olmasi gerekir.',
       'warn',
       'Kisi basi odeme — misafir hakki yoktur. Kalis 3 saatle sinirli.',
       'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge',
       current_date
  from lounge_programs p, lounge_venues v,
       (values
  ('SAW','Plaza Premium','domestic',       49.0, 'EUR', '6 yasina kadar ucretsiz'),
  ('SAW','Plaza Premium','international',  63.0, 'EUR', '6 yasina kadar ucretsiz'),
  ('BJV','TAV','both',                     27.0, 'EUR', '0-2 yas ucretsiz'),
  ('ADB','TAV','both',                     27.0, 'EUR', '0-2 yas ucretsiz'),
  ('ESB','TAV','both',                     27.0, 'EUR', '0-2 yas ucretsiz'),
  ('COV','Çelebi','international',         49.5, 'EUR', '6 yasina kadar ucretsiz')
       ) as t(ap, op, kapsam, tutar, birim, cocuk)
 where p.code = 'PGS_PAID' and v.active
   and v.airport_code = t.ap
   -- 🔴 operator ALANI BOS OLABILIR: 086'nin ilk salonlarinda doldurulmamis,
   -- 103 birlestirmesinden sonra kanonik satirda da bos kaldi. Yalniz
   -- operator'e bakinca hicbir satir eslesmiyordu ve upsert sessizce
   -- hicbir sey yapmiyordu. ADI da kontrol ediyoruz — ikisinden biri tutsun.
   and (lower(coalesce(v.operator,'')) like '%' || lower(t.op) || '%'
        or lower(v.name) like '%' || lower(t.op) || '%')
   and (t.kapsam = 'both' or coalesce(v.scope,'both') in (t.kapsam,'both'))
 order by v.id, p.id, (coalesce(v.scope,'both') = t.kapsam) desc, t.tutar desc
on conflict (venue_id, program_id) do update set
  guest_policy = 'paid', guest_included_count = 0,
  guest_fee_amount = excluded.guest_fee_amount,
  guest_fee_currency = excluded.guest_fee_currency,
  guest_flight_coupling = 'same_carrier', fee_payer = 'guest_at_door',
  max_stay_hours = 3, children_note = excluded.children_note,
  guest_fee_note = excluded.guest_fee_note, conditions = excluded.conditions,
  source_url = excluded.source_url, checked_at = excluded.checked_at;

-- COV ic hat TL tarifesi (tek TL fiyat; para birimi ayrimi onemli)
update lounge_venue_acceptance a
   set guest_fee_amount = 1260, guest_fee_currency = 'TRY'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id and p.code = 'PGS_PAID'
   and v.airport_code = 'COV' and coalesce(v.scope,'') = 'domestic';


-- Turkiye disindaki salonlarda Pegasus tarifesi GECERLI DEGIL.
-- Program duzeyindeki guncelleme LHR'ye de 63 EUR yazmisti.
update lounge_venue_acceptance a
   set guest_fee_amount = null, guest_fee_currency = null,
       conditions = coalesce(a.conditions,'') || ' [109] Pegasus tarifesi yalniz '
                 || 'resmi listedeki salonlarda gecerli; bu salon listede yok.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id and p.code = 'PGS_PAID'
   and v.airport_code not in ('SAW','BJV','ADB','ESB','COV');

-- ============================================================
-- 2) ASIRI YUKLEME TEMIZLIGI
-- ------------------------------------------------------------
-- returns_check uc fonksiyonun IKI SURUMUNUN birden durdugunu
-- soyluyordu: imzalari farkli oldugu icin PostgreSQL hata vermeden
-- ikisini de tutuyor. Ama PostgREST bir gun "Could not choose the
-- best candidate function" diyebilir ve o gun HANGI cagrinin
-- bozuldugunu bulmak cok zor olur.
--
-- Eski imzalari dusuruyoruz. Etkin surumler:
--   discover_availabilities(text,text,text,date)  — 072
--   respond_connection(uuid,text)                 — 027
-- ============================================================
-- 🔴 HANGI SURUM ETKIN? Once BAKTIM, sonra dusurdum.
-- Ilk yazimda `respond_connection(uuid, boolean)`u dusurmustum; oysa
-- ETKIN olan O. 015 eski (uuid,text), 027 yeni (uuid,boolean) ve app
-- boolean cagiriyor. Yanlisini dusurseydim BAGLANTI KABUL/RED AKISI
-- TAMAMEN KIRILIRDI ve bunu ancak kullanici fark ederdi.
-- Ders: "eski surumu dusur" derken hangisinin eski oldugunu
-- DOSYA NUMARASINDAN degil, IMZADAN ve app'in cagrisindan dogrula.
drop function if exists public.discover_availabilities(text, text, text);
drop function if exists public.respond_connection(uuid, text);

select p.proname, pg_get_function_identity_arguments(p.oid) as imza
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('discover_availabilities','respond_connection','create_availability')
 order by 1, 2;

select '109 OK - Pegasus modeli duzeltildi, asiri yuklemeler temizlendi' as sonuc;
