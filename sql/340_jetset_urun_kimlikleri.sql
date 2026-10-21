-- ============================================================================
-- 340 · MAĞAZA ÜRÜN KİMLİKLERİ: ll_kahya_* → ll_jetset_*   (21 Ekim 2026)
--
-- Plan adı Jetset oldu (SQL 337); mağaza ürünleri henüz HİÇBİR mağazada oluşturulmadı (Gökberk 6a'da).
-- App Store'da bir ürün kimliği bir kez açılınca değiştirilemez — "kahya" kalıcı olmasın diye kimlikler
-- şimdi değişiyor. Plan kodu (plan_type 'kahya') İÇ kod olarak kalır; kullanıcı ve mağaza görmez.
--   Apple : ll_jetset_aylik · ll_jetset_yillik
--   Google: abonelik ll_jetset (temel planlar: aylik, yillik) → RevenueCat "ll_jetset:aylik" bildirir,
--           sunucu ve uygulama bunu "ll_jetset_aylik"e çevirir (SQL 332 kuralı).
-- Eski ll_kahya_* satırları pasif kalır (yanlışlıkla açılan bir ürün olursa yine tanınsın diye silinmez).
-- Supabase SQL Editor'de tek parça; tekrar koşulabilir. Doğrulama: üç satır tamam = true.
-- ============================================================================
insert into public.iap_urunleri (urun_kodu, tur, paket_kod, plan, donem, aktif) values
  ('ll_jetset_aylik',  'abonelik', null, 'kahya', 'aylik',  true),
  ('ll_jetset_yillik', 'abonelik', null, 'kahya', 'yillik', true)
on conflict (urun_kodu) do update
  set tur = excluded.tur, paket_kod = excluded.paket_kod, plan = excluded.plan, donem = excluded.donem, aktif = true;

update public.iap_urunleri set aktif = false where urun_kodu in ('ll_kahya_aylik', 'll_kahya_yillik');

select 'jetset aylik -> kahya planı' as kontrol,
       exists (select 1 from iap_urunleri where urun_kodu = 'll_jetset_aylik' and plan = 'kahya' and donem = 'aylik' and aktif) as tamam
union all select 'jetset yillik -> kahya planı',
       exists (select 1 from iap_urunleri where urun_kodu = 'll_jetset_yillik' and plan = 'kahya' and donem = 'yillik' and aktif)
union all select 'eski kahya urunleri pasif',
       not exists (select 1 from iap_urunleri where urun_kodu like 'll_kahya_%' and aktif);
-- Beklenen: üç satır tamam = true.
