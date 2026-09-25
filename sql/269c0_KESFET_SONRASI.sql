-- ============================================================================
-- 269c-0 — KAPAT'TAN SONRA KEŞFET'TE NE KALACAK?   (SALT OKUNUR)
--
-- 🔴 NEDEN BUNU SORMAK GEREKİYOR
-- 269c1 şunu söyledi: Keşfet'te görünen 25 ilanın hepsi test hesaplarına ait.
-- `269c2_KAPAT` onları gizleyecek. Doğru iş — ama şu soru cevapsız kalıyor:
--
--     GİZLEDİKTEN SONRA KEŞFET'TE KAÇ GERÇEK İLAN KALACAK?
--
-- Cevap 0 ise, temizlik "yanlış bir şeyi düzeltmek" değil, "ürünün boş
-- olduğunu görünür yapmak"tır. İkisi de yapılmalı, ama ikincisini BİLEREK
-- yapmak gerekir — uygulamayı açan biri boş bir Keşfet görecek.
--
-- 🆕 SINIF: "BİR TEMİZLİK, TEMİZLENEN ŞEYİN NEYİ GİZLEDİĞİNİ DE AÇIĞA
-- ÇIKARIR — SAHTE VERİ SİLİNMEDEN ÖNCE, ONUN ALTINDA NE OLDUĞU BİLİNMELİ."
--
-- ⚠️ Bu bir "yapma" uyarısı DEĞİL. Sahte host'ları canlıda tutmanın
-- savunulabilir tarafı yok: gerçek bir kullanıcı onlara başvurursa cevap
-- alamaz. Sadece sonucu önceden bil.
-- ============================================================================

with test as (
  select id from users
   where deleted_at is null
     and (email like '%@vitrin.loungelink.test'
       or email like '%@seed.loungelink.test'
       or email like '%@e2e.test')
),
d as (select * from public.discover_availabilities())
select
  (select count(*) from d)                                             as "şu an Keşfet'te ilan",
  (select count(*) from d where host_id in (select id from test))      as "bunlardan sahte",
  (select count(*) from d where host_id not in (select id from test))  as "KAPAT SONRASI KALACAK",
  (select count(distinct host_id) from d
    where host_id not in (select id from test))                        as "gerçek host sayısı",
  (select count(*) from users u
    where u.deleted_at is null and u.id not in (select id from test))  as "toplam gerçek hesap";
