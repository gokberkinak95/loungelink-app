-- ============================================================
-- LoungeLink · 053_unstaff_founder_and_diag.sql
--
-- SORUN (Gokberk'in BO ekran görüntüsü): açtığı ilanlar keşifte
-- "✕ host staff" veriyor → kimse (guest de host da) göremiyor.
-- KÖK: hesap Ekip & Yetkiler'den açıldığı için users.is_staff=true;
-- SQL 041 staff host'ların ilanlarını keşiften DIŞLIYOR (doğru davranış).
-- Ama kurucu hem admin hem de TEST HOST'u — bu yüzden kendi hesabını
-- staff olmaktan çıkarması gerekiyor ki gerçek host gibi test edebilsin.
--
-- Bu dosya: (a) kurucunun staff bayrağını kaldırır, (b) hangi
-- hesaplar staff onu listeler ki yanlışlıkla dışlanan başka host var mı gör.
-- ============================================================

-- (a) Kurucuyu app'te gerçek kullanıcı yap (BO erişimi admin_roles'tan gelir,
--     is_staff'a BAĞLI DEĞİL — yetkiler ayrı tabloda, kaybolmaz).
update users
set is_staff = false
where email = 'gokberkinak95@gmail.com';

-- (b) TANI: kim staff? (admin_roles'ta olan ama app'te de görünmesi gerekenler)
select u.email, u.role, u.is_staff,
       (ar.user_id is not null) as bo_yetkisi_var,
       ar.role as bo_rol
from users u
left join admin_roles ar on ar.user_id = u.id
where u.is_staff = true
order by u.created_at;

select '053 OK — kurucu is_staff=false, staff listesi yukarıda' as sonuc;
