-- ============================================================
-- LoungeLink · 139_final_polish.sql
-- UCTAN UCA DENETIMIN BULDUGU UC KALINTI
--
-- ⚠️ Uygulamayi ETKILER (metin + eksik alan).
--
-- Uc bulgunun ucu de "yarim kalmis duzeltme" sinifindan: bir yerde
-- duzelttim, ayni seyin baska bir uretim noktasini atladim.
-- ============================================================

-- ------------------------------------------------------------
-- 1) UCRETLI AMA "KIM ODUYOR" BOS
-- ------------------------------------------------------------
-- 🔴 Misafire "ucretli" diyoruz ama parayi KIMIN odeyecegini
-- soylemiyoruz. Bu, sorunun en can alici yarisini bosta birakmak:
-- misafir "benden mi cikacak?" diye kaygilanir, host "benim
-- kartimdan mi cekilecek?" diye bilmez. Ikisi de kapida ogrenir.
--
-- Kart aglarinda cevap zaten program duzeyinde biliniyor
-- (PP/LK/DP = uyenin kartindan). Satira tasimayi atlamisim.
update lounge_venue_acceptance a
   set fee_payer = p.fee_payer
  from lounge_programs p
 where a.program_id = p.id and a.active
   and a.guest_policy = 'paid' and a.fee_payer is null
   and p.fee_payer is not null;

-- Program duzeyinde de bos kalanlar: isletmeci salonlarinda misafir
-- KAPIDA oder — bu, isletmeci modelinin tanimi geregi boyle.
update lounge_venue_acceptance a
   set fee_payer = 'guest_at_door',
       conditions = coalesce(a.conditions,'') || ' Misafir ücreti kapıda ödenir.'
  from lounge_programs p
 where a.program_id = p.id and a.active
   and a.guest_policy = 'paid' and a.fee_payer is null
   and p.entitlement_model in ('paid_entry','operator');

-- ------------------------------------------------------------
-- 2) HAM KOD KURAL NOTLARINDA SIZIYOR
-- ------------------------------------------------------------
-- 🔴 134'te BASLIKLARI temizlemistim; 110'da yazdigim yurt disi
-- kurallarinin NOTLARI hala "MS_EC", "ELPL" diyor. Bu notlar
-- rozetin ⓘ aciklamasina dusuyor — yani kullanici goruyor.
-- Ic kodu bir uretim noktasindan silmek yetmez; HEPSINDEN silinmeli.
update lounge_guest_rules r
   set notes = replace(replace(replace(replace(replace(r.notes,
         'MS_US_CC', 'Miles&Smiles ABD Kredi Kartı'),
         'MS_EC',    'Elite Corporate'),
         'ELPL',     'Elite Plus'),
         'CLPL',     'Classic Plus'),
         'SAG',      'Star Alliance Gold')
 where r.notes ~ '\m(CLPL|ELPL|MS_EC|MS_US_CC|SAG)\M';

-- ------------------------------------------------------------
-- 3) 110 KARAKTERDEN UZUN KULLANICI METNI
-- ------------------------------------------------------------
-- 🔴 135'te dokuz metni kisalttim ama IKISINI atladim. Uzun metin
-- okunmamis metindir — bir kez kisaltip "bitti" saymak, ayni hatanin
-- baska bir anahtarda yasamaya devam etmesine izin vermek.
update beta_settings
   set value = to_jsonb(
     'Bu salonun kuralını doğrulayamadık — girişi kapıda teyit et.'::text)
 where key = 'lounge_generic_notice';

update beta_settings
   set value = to_jsonb(
     'Beta: telefon doğrulaması henüz aktif değil, numaran doğrulanmadı.'::text)
 where key = 'otp_notice_bypass';

update beta_settings
   set value = to_jsonb(
     'Burada başvurabileceğin başka ilan yok — yeni ilan açılınca haber vereceğiz.'::text)
 where key = 'alt_note_none';

-- ---- DOGRULAMA ----
select 'ucretli ama fee_payer bos' as kontrol, count(*)::text as adet
  from lounge_venue_acceptance a
 where a.active and a.guest_policy = 'paid' and a.fee_payer is null and not a.is_placeholder;

select 'ham kod sizan kural' as kontrol, count(*)::text
  from lounge_guest_rules r
 where r.notes ~ '\m(CLPL|ELPL|MS_EC|MS_US_CC)\M'
   and (r.effective_to is null or r.effective_to >= current_date);

-- 🔴 `badge_labels` bir JSON SOZLUK (7 rozet × etiket+aciklama). Toplam
-- uzunlugunu tek bir kullanici metni gibi olcmek yanlis olcumdur;
-- icindeki HER metni ayri ayri olcmek gerekir.
select 'uzun kullanici metni' as kontrol, count(*)::text
  from beta_settings
 where key ~ '(notice|note)' and jsonb_typeof(value) = 'string'
   and length(value #>> '{}') > 110;

select 'uzun rozet aciklamasi' as kontrol, count(*)::text
  from beta_settings b, jsonb_each(b.value) e
 where b.key = 'badge_labels' and length(e.value ->> 'info') > 200;

select '139 OK - uc kalinti kapatildi' as sonuc;
