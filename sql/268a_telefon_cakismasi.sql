-- ============================================================================
-- 268a — AYNI NUMARAYI TAŞIYAN HESAPLAR: GÖR VE ÇÖZ   (29 Ağustos 2026)
--
-- ⚠️ YALNIZCA 268 "DURDU" DERSE GEREKİR. Önce §A'yı çalıştır, tabloya bak,
--    sonra §B'yi (yorumdan çıkararak) çalıştır.
--
-- ----------------------------------------------------------------------------
-- 🔴 NEDEN AYRI BİR DOSYA
--
-- 268 bir hesabın numarasını SİLECEK karar veremez. "Hangisi gerçek
-- kullanıcı?" sorusunun cevabı veritabanında değil, senin bilgindedir.
-- Bir göç dosyasının bu kararı tek başına vermesi, sessizce birinin
-- iletişim bilgisini silmesi olurdu.
--
-- 🆕 SINIF: "VERİYİ GÖÇ DOSYASI SİLMEZ — GÖÇ DOSYASI KARARI MÜMKÜN KILAR,
-- KARARI İNSAN VERİR."
--
-- ⚠️ ÖNCE ŞUNU BİL: 268'in v2'si GEÇERSİZ FORMATLI numaraları zaten
-- `NULL`a düşürdü (ör. `90555000000` — 11 hane, geçerli TR numarası 12
-- hane olmalı). Yani buraya kadar gelen çakışmalar GERÇEK numaralardır:
-- iki hesap sahiden aynı hattı yazmış.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- §A — ÖNCE BAK: kim, hangi numarayı, ne zamandan beri taşıyor
--
-- Karar için gereken her şey burada: hesabın yaşı, doğrulanmış mı,
-- ilanı/talebi var mı, son hareketi ne zaman.
-- `oneri` sütunu bir TAVSİYEDİR — otomatik uygulanmaz.
-- ════════════════════════════════════════════════════════════════════════
with cakisan as (
  select phone_kanonik
    from users
   where deleted_at is null and phone_kanonik is not null
   group by 1 having count(*) > 1
),
detay as (
  select
    u.phone_kanonik,
    u.id,
    u.email,
    u.role,
    u.created_at,
    coalesce(v.phone_verified, false)                                   as tel_dogrulanmis,
    coalesce(v.email_verified, false)                                   as eposta_dogrulanmis,
    (select count(*) from availabilities a where a.host_id = u.id)      as ilan,
    (select count(*) from requests r
      where r.guest_id = u.id or r.host_id = u.id)                      as talep,
    (select max(s.started_at) from sessions s
       join requests r2 on r2.id = s.request_id
      where r2.guest_id = u.id or r2.host_id = u.id)                    as son_oturum,
    -- SIRALAMA KURALI (tavsiyenin dayanağı):
    --   1) telefonu DOĞRULANMIŞ olan kazanır — kanıtı olan taraf
    --   2) sonra hareketi olan (ilan/talep) kazanır
    --   3) sonra ESKİ hesap kazanır
    row_number() over (
      partition by u.phone_kanonik
      order by coalesce(v.phone_verified, false) desc,
               ((select count(*) from availabilities a2 where a2.host_id = u.id)
              + (select count(*) from requests r3
                  where r3.guest_id = u.id or r3.host_id = u.id)) desc,
               u.created_at asc
    )                                                                   as sira
  from users u
  join cakisan c on c.phone_kanonik = u.phone_kanonik
  left join verifications v on v.user_id = u.id
 where u.deleted_at is null
)
select
  phone_kanonik                       as "numara",
  sira                                as "#",
  case when sira = 1 then '✅ NUMARAYI TUTSUN'
       else            '⬜ numarası boşaltılacak' end as "öneri",
  email                               as "e-posta",
  role                                as "rol",
  tel_dogrulanmis                     as "tel ✓",
  eposta_dogrulanmis                  as "e-posta ✓",
  ilan                                as "ilan",
  talep                               as "talep",
  created_at::date                    as "kayıt",
  son_oturum::date                    as "son oturum",
  id                                  as "hesap id"
from detay
order by phone_kanonik, sira;


-- ════════════════════════════════════════════════════════════════════════
-- §B — ÇÖZ  (yukarıdaki tabloyu ONAYLADIKTAN SONRA yorumdan çıkar)
--
-- 🔴 NE YAPIYOR: her çakışan numara için §A'nın 1 numaralı satırındaki
-- hesap numarayı TUTAR; diğerlerinin numarası boşaltılır.
--
-- ⚠️ "Boşaltmak" = `phone`, `phone_e164`, `phone_kanonik` → NULL ve
-- `verifications.phone_verified` → false. Hesap SİLİNMEZ, e-postasıyla
-- girmeye devam eder; yalnız numarası kalkar ve güven puanından telefon
-- bileşeni düşer (çünkü artık doğrulanmış bir hattı yok — bu doğrudur).
--
-- ⚠️ VE HER SİLİNEN NUMARA KAYDA GEÇER. Bir kullanıcı "numaram neden
-- silindi" diye sorarsa cevabı `telefon_cakisma_kaydi` tablosunda durur.
-- 🆕 SINIF: "GERİ ALINAMAZ BİR TEMİZLİK, NE SİLDİĞİNİ YAZMADAN
-- YAPILMAMALIDIR — KAYIT, KARARIN KENDİSİ KADAR ÖNEMLİDİR."
-- ════════════════════════════════════════════════════════════════════════

/*  ↓↓↓ ONAYLADIYSAN BU BLOĞU YORUMDAN ÇIKAR ↓↓↓

begin;

create table if not exists telefon_cakisma_kaydi (
  user_id        uuid primary key,
  silinen_phone  text,
  kanonik        text,
  kazanan_id     uuid,
  sebep          text not null,
  yapildi_at     timestamptz not null default now()
);

with cakisan as (
  select phone_kanonik from users
   where deleted_at is null and phone_kanonik is not null
   group by 1 having count(*) > 1
),
sirali as (
  select u.id, u.phone, u.phone_kanonik,
    row_number() over (
      partition by u.phone_kanonik
      order by coalesce(v.phone_verified,false) desc,
               ((select count(*) from availabilities a2 where a2.host_id=u.id)
              + (select count(*) from requests r3 where r3.guest_id=u.id or r3.host_id=u.id)) desc,
               u.created_at asc
    ) as sira
  from users u
  join cakisan c on c.phone_kanonik = u.phone_kanonik
  left join verifications v on v.user_id = u.id
 where u.deleted_at is null
),
kazanan as (select phone_kanonik, id from sirali where sira = 1)
insert into telefon_cakisma_kaydi (user_id, silinen_phone, kanonik, kazanan_id, sebep)
select s.id, s.phone, s.phone_kanonik, k.id,
       '268a: ayni numarayi tasiyan hesaplardan biri; dogrulama/hareket/yas sirasina gore kazanan k.id'
  from sirali s join kazanan k on k.phone_kanonik = s.phone_kanonik
 where s.sira > 1
on conflict (user_id) do nothing;

update users u
   set phone = null, phone_e164 = null, phone_kanonik = null
  from telefon_cakisma_kaydi t
 where t.user_id = u.id and u.phone_kanonik is not null;

update verifications v
   set phone_verified = false, phone_verified_at = null
  from telefon_cakisma_kaydi t
 where t.user_id = v.user_id;

-- Telefon bileşeni düştü; puan gerçeğe dönsün.
select public.recompute_trust(user_id) from telefon_cakisma_kaydi;

-- NÖBETÇİ: 268 artık geçebiliyor mu?
do $nb268a$
declare v_kalan int;
begin
  select count(*) into v_kalan from (
    select phone_kanonik from users
     where deleted_at is null and phone_kanonik is not null
     group by 1 having count(*) > 1
  ) x;
  if v_kalan > 0 then
    raise exception '268a NOBETCI: % numara HALA cakisiyor.', v_kalan;
  end if;
  raise notice '268a NOBETCI OK: cakisma kalmadi, 268 calistirilabilir. (% kayit)',
    (select count(*) from telefon_cakisma_kaydi);
end $nb268a$;

commit;

select t.user_id as "numarası boşaltılan", u.email as "e-posta",
       t.silinen_phone as "silinen numara", t.kanonik as "kanonik",
       t.kazanan_id as "numarayı tutan hesap"
  from telefon_cakisma_kaydi t join users u on u.id = t.user_id
 order by t.yapildi_at desc;

    ↑↑↑ ONAYLADIYSAN BU BLOĞU YORUMDAN ÇIKAR ↑↑↑  */
