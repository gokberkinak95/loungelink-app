-- ============================================================================
-- LoungeLink · 228_odul_katalogu_takas_kapaniyor.sql       (21 Ağustos 2026)
--
-- ÖDÜL KATALOĞU, SİTENİN KENDİ SÖZÜNÜ ÇÜRÜTÜYORDU
--
-- 🔴 NASIL ÇIKTI: Gökberk siteye "host'lara mağazadan ve ödüllerden hiç
-- bahsetmemişiz" dedi. Siteye yazmadan önce ödülleri ÖLÇTÜM — ve
-- katalogda site metninin AÇIKÇA vermediğimizi söylediği iki ürünü
-- buldum:
--
--   017_marketplace.sql:66  ('Priority Pass Misafir Kartı', 'lounge', 5000)
--   017_marketplace.sql:67  ('DragonPass Günlük Kart',      'lounge', 4000)
--
-- Oysa `website/lib/content.js` içindeki HOST_WHY kartı v0.18'den beri
-- şunu yazıyor:
--
--     "Lounge erişimi ödül olarak verilmez — hak paylaşımı takasa
--      dönüşmesin diye."
--
-- Ve o satırın üstündeki yorum sebebini de yazmış:
--     misafir kredi verir → host'a geçer → host onu lounge erişimine
--     çevirir. Bu, SSS'nin "programlar erişim hakkının devrini
--     yasaklar" dediği şeyin operasyonel tanımıdır.
--
-- Yani sitede kapattığımız döngü veritabanında AÇIK duruyordu. Beta'da
-- ilk 5000 puanını biriktiren host, mağazadan bir Priority Pass misafir
-- kartı alacaktı — kendi misafir hakkını paylaştığı için.
--
-- 🆕 SINIF: **"BİR KURALI METİNDE YAZMAK, ONU SİSTEMDE UYGULAMAK
-- DEĞİLDİR."** v0.18'de metni düzelttim, kataloğu düzeltmedim; ikisi
-- 100+ gün boyunca birbirini yalanladı ve hiçbir nöbetçi bakmıyordu.
-- Bu dosya hem veriyi düzeltiyor hem de nöbetçiyi kuruyor.
--
-- ⚠️ SİLMİYORUM, PASİFE ALIYORUM. `redemptions.reward_id` bu satırlara
-- yabancı anahtarla bağlı: silmek, o ödülü almış birinin geçmişini
-- koparır. `active=false` mağazadan kaldırır (RLS zaten
-- `using (active = true)`), geçmişi bırakır.
--
-- KATALOG 8 ÜRÜNDE KALIYOR. İki lounge ürününün yerine MEVCUT
-- tedarikçilerin üst basamakları geliyor — yeni bir marka uydurmuyorum,
-- fiyat noktalarını da koruyorum (4000 ve bir üst basamak 5000).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Lounge erişimi ödüllerini mağazadan kaldır
-- ----------------------------------------------------------------------------
-- Kategoriye göre gidiyorum, isme göre değil: yarın "Lounge Key Günlük"
-- eklenirse isim listesi ıskalar, kategori ıskalamaz.
update rewards
   set active = false,
       is_featured = false
 where coalesce(category,'') = 'lounge'
   and coalesce(active, true);

-- ----------------------------------------------------------------------------
-- 2) Boşalan iki basamağı doldur
-- ----------------------------------------------------------------------------
-- 🔴 `on conflict do nothing` BURADA ÇALIŞMAZ — ve 017 ile 022 de aynı
-- hatayı taşıyor. `rewards.title` üzerinde BENZERSİZ İNDEKS YOK; çatışma
-- olmayınca `on conflict` hiç devreye girmez ve dosya ikinci kez
-- koşulduğunda katalog ÇİFTLENİR.
--
-- ÖLÇTÜM — ayrı bir boş Postgres'te, iki yazımı yan yana koşturarak:
--     eski yazım (on conflict do nothing) : 1. koşu 8 → 2. koşu 10 ✗
--     yeni yazım (where not exists)       : 1/2/3. koşu 8 → 8 → 8 ✓
--     kısıt mutasyonu: aktif lounge ödülü eklemeyi denedim →
--       ERROR: violates check constraint "rewards_no_lounge_barter_chk" ✓
--
-- Bu çiftlenmeyi harness YAKALAMADI, çünkü ilk nöbetçim `>= 8` diye
-- soruyordu ve 10 da >= 8'dir.
-- 🆕 SINIF: **"BİR NÖBETÇİ, YALNIZCA SORDUĞU SORU KADAR İYİDİR."**
-- Nöbetçi artık TAM SAYI soruyor (fazlası da arızadır) ve ayrıca aynı
-- başlığın aktif katalogda iki kez bulunup bulunmadığına bakıyor.
--
-- ⚠️ 017 ve 022 de aynı yazımı taşıyor; onlara DOKUNMUYORUM (eski bir
-- migration'ın davranışını değiştirmek bu projede üç kez geri geldi).
-- Bunun yerine aşağıdaki toplama adımı, o dosyaların geçmişte bıraktığı
-- kopyaları pasife alıyor.
insert into rewards (title, subtitle, category, cost_points, sort_order)
select v.title, v.subtitle, v.category, v.cost_points, v.sort_order
  from (values
    ('Airalo eSIM 10GB',      'Küresel veri',  'esim',  4000, 9),
    ('Booking.com 50$ Kredi', 'Her konaklama', 'hotel', 5000, 10)
  ) as v(title, subtitle, category, cost_points, sort_order)
 where not exists (select 1 from rewards r where r.title = v.title);

-- Aynı hatanın geçmişte bıraktığı çiftleri de topla: 017/022 birden
-- çok kez koşulduysa katalogda kopyalar duruyor olabilir. En eskisini
-- tut (redemptions ona bağlı olabilir), sonrakileri pasife al.
update rewards r set active = false, is_featured = false
 where coalesce(r.active, true)
   and exists (
     select 1 from rewards r2
      where r2.title = r.title and r2.ctid < r.ctid
        and coalesce(r2.active, true));

-- ----------------------------------------------------------------------------
-- 3) KALICI KORUMA — bir daha lounge ödülü eklenemesin
-- ----------------------------------------------------------------------------
-- 🔴 Bunu bir CHECK ile yapıyorum, bir yorum satırıyla değil. v0.18'de
-- yorum yazdım; yorum 100 gün boyunca kimseyi durdurmadı.
-- Pasif satırlar geçebilsin diye koşul `active` üzerinden kuruluyor:
-- geçmişteki iki kayıt kalır, yeni bir AKTİF lounge ödülü giremez.
alter table rewards drop constraint if exists rewards_no_lounge_barter_chk;
alter table rewards add constraint rewards_no_lounge_barter_chk
  check (coalesce(category,'') <> 'lounge' or coalesce(active, true) = false);

comment on constraint rewards_no_lounge_barter_chk on rewards is
  'Lounge erisimi ODUL OLARAK verilemez: misafir hakkini paylasan kisiye '
  'misafir hakki odul vermek dongulyu kapatir ve iliskiyi acik bir takasa '
  'cevirir. Programlarin kurallari erisim hakkinin devrini yasaklar.';

-- ----------------------------------------------------------------------------
-- 4) NÖBETÇİ — iddiayı ölç, ölçemediğini söyle
-- ----------------------------------------------------------------------------
do $n228$
declare
  v_lounge_aktif int;
  v_toplam       int;
  v_kisit        int;
  v_cift         int;
  v_min          int;
  v_max          int;
begin
  select count(*) into v_lounge_aktif
    from rewards where coalesce(category,'')='lounge' and coalesce(active,true);

  select count(*), min(cost_points), max(cost_points)
    into v_toplam, v_min, v_max
    from rewards where coalesce(active,true);

  select count(*) into v_kisit
    from pg_constraint where conname = 'rewards_no_lounge_barter_chk';

  if v_lounge_aktif <> 0 then
    raise exception '228 NOBETCI: hala % aktif lounge odulu var — takas dongusu acik.', v_lounge_aktif;
  end if;
  if v_kisit <> 1 then
    raise exception '228 NOBETCI: rewards_no_lounge_barter_chk kurulmadi.';
  end if;
  -- TAM SAYI soruyorum, ">=" değil: fazlası da bir arızadır (çiftlenme).
  -- 🔴 23 AGUSTOS DUZELTMESI: burada `v_toplam <> 8` yaziyordu. 244
  -- katalogu MALIYETE gore yeniden fiyatlayip ulasilamayan odulleri
  -- vitrinden cikardi (8 → 6) ve bu nobetci, DOGRU olan degisikligi
  -- hata sandi. Iki nobetci birbirini yalanladi.
  --
  -- Ayni sinifi daha once e2e testinde yasadim: bir testin icine URUN
  -- KARARINI sabit yazmak, o karari degistiren herkesi yalanci cikarir.
  --
  -- Bu dosyanin ASIL derdi CIFTLENME idi (`on conflict do nothing`
  -- olmadan tekrar kosunca katalog cogaliyordu). O kontrol asagida
  -- zaten var ve sayidan bagimsiz. Buradaki kontrol artik yalnizca
  -- "vitrin bosalmasin" tabani.
  if v_toplam < 3 then
    raise exception '228 NOBETCI: katalogda yalniz % aktif odul var — vitrin bosalmis.', v_toplam;
  end if;

  select count(*) into v_cift from (
    select title from rewards where coalesce(active,true)
     group by title having count(*) > 1) z;
  if v_cift <> 0 then
    raise exception '228 NOBETCI: % odul basligi aktif katalogda birden fazla kez var.', v_cift;
  end if;

  raise notice '228 OK · aktif odul: % · puan araligi: %-% · aktif lounge odulu: 0 · kisit: kurulu',
    v_toplam, v_min, v_max;

  -- 🔴 ÖLÇEMEDİĞİM: bu ödüllerin tedarikçi tarafında GERÇEKTEN
  -- karşılığı olup olmadığı. `redeem_reward()` kupon kodu üretiyor ama
  -- teslimi beta'da manuel. Katalog dürüst; teslim zinciri değil.
  raise notice '228 OLCULMEDI: odul teslimi hala manuel (redeem_reward kupon uretir, tedarikci bagli degil).';
end $n228$;

select 'ODUL KATALOGU TAKAS-GUVENLI' as sonuc,
       (select count(*) from rewards where coalesce(active,true)) as aktif_odul,
       (select count(*) from rewards where coalesce(category,'')='lounge' and coalesce(active,true)) as aktif_lounge_odulu;
