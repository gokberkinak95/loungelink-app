-- ============================================================
-- LoungeLink · 058_fix_stale_staff_roles.sql
--
-- SORUN: BO v1.20 düzeltmesinden ÖNCE Ekip&Yetkiler'den açılan hesaplar
-- users.role = 'guest' olarak yazılmıştı (o zamanki kod öyleydi). Düzeltmeden
-- sonra kod 'admin' yazıyor ama ESKİ hesaplar hâlâ 'guest'/'host' görünüyor →
-- Kullanıcılar sayfasında yanlış rol, KYC kuyruğunda gereksiz görünme.
--
-- ÖRNEK (screenshot): Mustafa Emre Alimoğlu → Ekip'te super_admin ama
-- Kullanıcılar'da 'guest', KYC'de onay bekliyor.
--
-- ÇÖZÜM: is_staff=true olan HER hesabın users.role'ünü 'admin' yap. Bu hesaplar
-- app kullanıcısı değil; rolleri panel rolüdür (admin_roles tablosunda tutulur),
-- users.role sadece 'admin' olmalı ki app sorgularında/görünümlerde tutarlı olsun.
-- ============================================================

update users
set role = 'admin'
where is_staff = true
  and role <> 'admin';

-- Kaç satır düzeldi, göster
select count(*) as duzeltilen_ekip_hesabi
from users
where is_staff = true and role = 'admin';

-- Doğrulama: hâlâ yanlış rolde ekip hesabı kaldı mı? (0 dönmeli)
select id, email, role, is_staff
from users
where is_staff = true and role <> 'admin';

select '058 OK — tum ekip hesaplari role=admin, app gorunumlerinde tutarli' as sonuc;
