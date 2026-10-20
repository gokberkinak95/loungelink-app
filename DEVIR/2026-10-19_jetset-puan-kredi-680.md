# DEVIR · 19 Ekim 2026 · Jetset, plana göre puan/kredi, kuruluş fiyatı, kabulde geri çekme — app 6.8.0

Gökberk'in kararları (19 Ekim):
- Aynı uçuş için bir istek kabul edilince diğerleri kendiliğinden geri çekilir, iadeler eksiksiz.
- "İstek" yerine "başvur" dili (aynı anda N host'a başvur).
- LoungePuan herkesin KENDİ planına göre: Yolcu 100 · Sık Uçan 250 · Jetset 500 (host ve misafir).
- Ağırlama kredisi: Sık Uçan 1 · Jetset 1 (2 değil) · Yolcu yalnız İLK ağırlamada 1 (bir kez).
- Hediye Sık Uçan ayı: 3 ağırlamada (2 değil) — 30 günlük pencere.
- Ödül fiyatları: Amazon ₺500 = 2000, THY 1000 mil = 8000, diğerleri aynı mantıkla.
- Plan detayında buluşma başına puan görünsün. Host'u ücretli plana çekme özellikleri (yalnız kimlikli
  misafir, ilan görüntülenmesi, öne çıkarma "daha çok misafir").
- Üst plan adı **Jetset** (ürün kimlikleri `ll_kahya_*` AYNI). Host basamağı Kâhya → **Kaptan**.
- Kuruluş fiyatı: 31 Mart 2027'ye kadar abone olan, kesintisiz sürdükçe aynı fiyattan yenilenir.

## Değişen dosyalar
### SQL (Supabase'de henüz koşulmadı)
- `sql/336_kabulde_digerleri_geri_cek.sql` — `kabulde_digerlerini_geri_cek(p_kabul)`; `respond_request` kabul
  satırından hemen sonra çağırır. Aynı misafir + aynı havalimanı + aynı gün bekleyen istekler `cancelled`,
  bekleyen oturumlar kapanır, her biri `istek_kredisi_iade(id,'request_cancel_refund')` (idempotent, miktarı
  `tutulan_kredi` belirler), host'lara ve misafire bildirim. Doğrulama 3 satır.
- `sql/337_jetset_puan_kredi_kurulus.sql` — plan_catalog `agirlama_puani` / `agirlama_kredisi`; Jetset adı ve
  yeni perks TR/EN; `etkin_plan_ic` (service_role), `plan_agirlama_puani`; `confirm_session` plana göre puan;
  `host_credit_settle` plana göre kredi (Yolcu ilk ağırlama), tavanlar ve halka koruması aynen;
  `host_free_upgrade_sessions = 3`, 30 gün penceresi, `plan_hediyelerini_bitir` köprü bildirimi;
  ödül fiyatları; `kurulus_fiyat_bitis = 2027-03-31`, `kurulus_fiyati()`; `subscription_plans` yeni alanlar;
  `availabilities.yalniz_kimlikli` + tetikleyiciler + `ilan_yalniz_kimlikli_ayarla`; `ilan_gorunumleri`,
  `ilan_gorunum_yaz`, `ilan_gorunum_istatistigi`; host_tiers kahya → Kaptan. Doğrulama 11 satır.
- `sql/334_...` yalnız perks metni "başvur" (337 zaten üzerine yazar).
- `sql/SQL_SIRA.txt` (9. tur), `sql/KURULUM_TABLOSU.sql` (371, 372 elle; `tablo_uret.py` KOŞMA).

### App 6.8.0 (versionCode 292, buildNumber 286)
- `src/i18n.js` — Kâhya/Concierge → Jetset (0 kalan), Kaptan; kazanç metinleri plana göre; tur plan satırlarında
  buluşma başına puan; kuruluş rozeti/notu; yalnız kimlikli ve görüntülenme metinleri; errMap
  `ilan_yalniz_kimlikli`, `plan_gerekli`.
- `src/legal.js` (+ BO ve site kopyası) LEGAL_VERSION 2026-10-19.
- `src/ekranlar_yalin.js` Planlar: kuruluş rozeti + not (tarih sunucudan).
- `src/screens.js` İlanlarım: görüntülenme satırı (ücretsizde kilit ipucu) + "Yalnız kimliği doğrulanmış
  misafirler" anahtarı.
- `src/ekranlar_ana.js` Keşfet: `ilan_gorunum_yaz`; yalnız kimlikli ilan rozeti (kartta ve istek ekranında;
  kolon yoksa sessizce gizli).

### BO 1.100.0 (main'e gönderildi)
- Planlar: ağırlama puanı / kredisi, açık istek tavanı, haftalık bağlantı alanları.
- Motor ayarları: `host_credit_per_session` kaldırıldı; "Fiyat" grubu `kurulus_fiyat_bitis` (tarih).
- Plan hediyeleri "son 30 gün içinde 3 kişi"; Kaçak göstergesi ve ödül ekonomisi Jetset.

### Site 0.71.0 (site-v7 ve main'e gönderildi)
- `PlanKartlari.jsx` Jetset, puan/kredi/host premium satırları, kuruluş rozeti (tarih geçince kalkar),
  kabulde geri çekme cümlesi.
- `HostEarn.jsx` plan seçmeli hesaplayıcı (Yolcu/Sık Uçan/Jetset), yeni ödül fiyatları, Kaptan.
- `lib/content.js` SSS ve host avantajları; `app/page.jsx`, `app/ayricaliklar/page.jsx`.

## Testler (sayılarla)
- SQL 336 yerel senaryo 9/9 · doğrulama 3/3.
- SQL 337 yerel doğrulama 11/11 · senaryo t337 18/18 (son düzenlemeden sonra yeniden koşuldu).
- app `node check.js` temiz · `npm run verify`: tek kırmızı ortam (bu kabukta Python cairosvg yok, ürün kusuru değil); dokunma makbuzu sahne koşusuyla tazelendi
- sahne + dokunma yolu: 110 sahne, hata 0 (arıza sahneleri 42/43/44/49 bilerek bozuk) · dokunma yolu düşen 0
- akış e2e: ilk koşu 209/211: 2 düşen SQL 336'nın yeni kuralından (kabulde aynı günkü diğer istek geri çekilir → tek kart kalınca test kartı okuyamıyordu); `akis_e2e_b2_ana.py` istek_red düzeltildi, ana 17/17. Tam koşu 210/211: tek düşen giriş/çıkış zamanlaması, tek başına 18/18. Not: e2e için PATH'e pgserver/pginstall/bin eklenmeli (yoksa 'psql bulunamadı', tohum atılmaz).
- BO `node check.js` temiz · `npm run build` başarılı.
- site `node verify.js` 7/7 temiz · `node check.js` temiz (61 dosya, 19 sayfa) · `npm run build` başarılı ·
  375 px'te yatay taşma yok (scrollWidth 375), hesaplayıcı üç planda doğru sayılar.

## APK
- Android önizleme APK 6.8.0 (292): https://expo.dev/artifacts/eas/zfgwLgZtW_AzhqUV6v38vq_H_EEwNTplEdYWaIhOK7Y.apk (EAS Starter planına geçildi, 19 Ekim)

## Açık / Gökberk'ten
1. SQL: 335 (koşulmadıysa) → 336 → 337.
2. Ödül ekonomisi kararı (aşağıda) — Jetset–Jetset buluşması 1000 puan ≈ ₺250 Amazon değeri.
3. Konsiyerj basamağı (15 ağırlama) `istek_bedava`: host'un kendi istekleri kredisiz → plan satışını eritir.
4. Mağaza: Jetset görünen adları; kuruluş fiyatı için ileride "preserve price / legacy price" (rehber 6d, 7).
5. Firebase 10/10b, RevenueCat anahtarları, eas.json appleId + ascAppId.

## Ek · 20 Ekim (Gökberk kararları)
- **Konsiyerj basamağı kaldırıldı** (15 ağırlamada kendi istekleri kredisizdi → plan satışını eritiyordu).
  SQL 337 §1c `delete from host_tiers where code='konsiyerj'`; en üst basamak Kaptan. 337 doğrulaması
  artık **12 satır** (yerel 12/12, t337 18/18, `request_credit_cost` = 1).
- Site 0.71.1 (basamak şeridi 3 sütun, SSS), BO 1.100.1: kullanıcı "Planı Ata" listesi yalnız gerçek planlar
  (Yolcu / Sık Uçan / Jetset); eskiden `evsahibi`/`konsiyerj` basamak kodları vardı → atama hata veriyordu.
- App: `hwRankInfo` metni (Kaptan'da biter) — yalnız metin, bir sonraki derlemeyle gider (6.8.0 APK'da eski metin).
- Ödül ekonomisi: kullanıcı devamlılığı için şimdilik SINIR YOK (ayda 4 buluşma / 90 günde 1 önerileri reddedildi);
  her şey ayarlandıktan sonra puan/para dengesine birlikte bakılacak.
