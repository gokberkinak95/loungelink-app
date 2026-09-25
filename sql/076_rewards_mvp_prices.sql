-- ============================================================
-- LoungeLink · 076_rewards_mvp_prices.sql
--
-- MVP "Mağaza" ekranındaki puan fiyatları ile canlı DB'deki fiyatlar
-- TUTMUYORDU (parite turu, Parti 6 bulgusu):
--
--   Ödül                          MVP        Canlı (022'ye kadar)
--   Priority Pass Misafir Kartı   1.500      5.000
--   DragonPass Günlük Kart        3.000      4.000
--   Türk Hava Yolları 500 Mil     1.000      2.500
--   Booking.com 25$ Kredi         2.500      3.000
--   SafetyWing 1 Ay               2.000      3.500
--   Airalo eSIM 3GB               1.000      1.500
--   Emirates Skywards 750 Mil     1.200      1.200  (aynı)
--   Marriott Bonvoy 20$ Kredi     1.200      1.200  (aynı)
--
-- Bu dosya fiyatları MVP'ye eşitler (istenen: birebir parite).
--
-- ⚠️ EKONOMİ UYARISI (Gokberk'in kararı gereken yer):
-- Oturum başına host 500 / misafir 200 puan kazanıyor. MVP fiyatlarıyla
-- Priority Pass misafir kartı = 3 host oturumu. Henüz HİÇBİR tedarikçi
-- anlaşması yok; kupon kodu üretilirse yükümlülük GERÇEK olur.
-- Öneri: anlaşmalar imzalanana kadar ödülleri active=false tut
-- (aşağıdaki blok yorumda — kararı sen ver, ben tek satır açarım).
-- ============================================================

update rewards set cost_points = 1500 where title = 'Priority Pass Misafir Kartı';
update rewards set cost_points = 3000 where title = 'DragonPass Günlük Kart';
update rewards set cost_points = 1000 where title = 'Türk Hava Yolları 500 Mil';
update rewards set cost_points = 2500 where title = 'Booking.com 25$ Kredi';
update rewards set cost_points = 2000 where title = 'SafetyWing 1 Ay';
update rewards set cost_points = 1000 where title = 'Airalo eSIM 3GB';
update rewards set cost_points = 1200 where title = 'Emirates Skywards 750 Mil';
update rewards set cost_points = 1200 where title = 'Marriott Bonvoy 20$ Kredi';

-- MVP sırası: Priority Pass · Booking · THY · Airalo · SafetyWing ·
-- DragonPass · Emirates · Marriott (2 sütunlu grid soldan sağa)
update rewards set sort_order = 1 where title = 'Priority Pass Misafir Kartı';
update rewards set sort_order = 2 where title = 'Booking.com 25$ Kredi';
update rewards set sort_order = 3 where title = 'Türk Hava Yolları 500 Mil';
update rewards set sort_order = 4 where title = 'Airalo eSIM 3GB';
update rewards set sort_order = 5 where title = 'SafetyWing 1 Ay';
update rewards set sort_order = 6 where title = 'DragonPass Günlük Kart';
update rewards set sort_order = 7 where title = 'Emirates Skywards 750 Mil';
update rewards set sort_order = 8 where title = 'Marriott Bonvoy 20$ Kredi';

-- Tedarikçi anlaşması gelene kadar kullanımı kapatmak istersen (KAPALI):
-- update rewards set active = false;

-- DOĞRULAMA — 8 satır, MVP fiyatlarıyla
select title, cost_points, sort_order, active
  from rewards order by sort_order;

select '076 OK - magaza fiyatlari MVP ile esitlendi' as sonuc;
