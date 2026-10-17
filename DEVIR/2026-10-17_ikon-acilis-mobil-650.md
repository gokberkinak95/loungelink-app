# DEVIR — 17 Ekim 2026 · app 6.5.0 · site 0.70.3 · BO 1.98.0

## Ne değişti

### Uygulama ikonu: kemersiz "Hale" (Gökberk seçimi: B)
- Yeni üretici: `rnapp/brand/build_ikon_hale.py` (tek kaynak). Gece mavisi zemin, kendi ışığını
  saçan fildişi kanat, mavi + şampanya hale. Koyu degradelerde bant olmasın diye ±1 LSB titresim.
- Çıktılar: `rnapp/assets/{icon,adaptive-icon,monochrome-icon,favicon,splash}.png`,
  `website/app/{icon,apple-icon}.png`, `website/public/{icon,favicon}.png`,
  `backoffice/public/{icon,favicon}.png`, `rnapp/magaza/cikti/play/icon-512.png`.
- Eski kemerli dosyalar: `_arsiv/ikon_kemer_20261017/`.
- Uygulama içi: yükleyici (`ui.js` Load) ve an ekranı (`MomentScreen.js`) kemer yerine kanat.
- `marka_check.py` artık `build_ikon_hale.py`'yi denetliyor (eski `build_brand.py` cairo
  istediği için bu makinede hiç çalışmıyordu). Sonuç: üretici = sevkiyat, birebir.

### Açılış: "bulutların arasından" (önizleme v3 onaylı)
- `rnapp/src/acilis.js` (AcilisSahnesi), App kökünde AppInner'ın üstünde. ~3,6 sn.
  Sis dağılır → bulutlar paralaksla açılır → ışık doğar → uçak netleşerek ışığın ortasına
  oturur → LOUNGELINK harf harf → slogan → önce uçak/yazı, sonra gökyüzü söner.
- Dokununca atlanır; "hareketi azalt" açıksa hemen çekilir; görseller yüklenmeden başlamaz
  (en çok 500 ms bekler); web'de yalnız `?acilis=1` ile çizilir (e2e ve sahne çekimi etkilenmez).
- Yerel açılış: `app.json` splash zemini `#DCE3EF` (sis), görsel saydam. Sahne bu kareden başlar.
- Görsel üretici: `rnapp/brand/build_acilis.py` (float bulanıklık + titresim, onaylı şekillerle
  birebir; 1,5x çözünürlük). Renkler `theme.js` › `ACILIS`.
- Web doğrulaması: 8 kare, sayfa hatası 0; çıkışta çift uçak görüntüsü giderildi.

### Site (0.70.2 → 0.70.3) ve mobil
- Ölçüm: tüm sayfalar 320/360/390 px'te yatay taşma 0.
- Düzeltildi: güven bölümünde ortadaki ekran kalkan kartının içine giriyordu (tek sütunda
  34 px üst pay); rehber sayaç etiketleri ("HAVALİMANI") kutuya sığıyor; `html, body
  { overflow-x: clip }` güvencesi.
- Yasal metin 2026-10-17 (aşağıda).
- `components/PlanKartlari.jsx` ve `lib/content.js`'teki YEREL değişiklikler ESKİ modele göre
  (Kâhya 16, ₺249,99): COMMIT EDİLMEDİ. Son modele göre yeniden yapılacak (önce önizleme).

### BO (1.97.1 → 1.98.0)
- Yeni ikon; "Tanış Kaçağı" ekranı (`/manage/kacak-gostergesi`, SQL 334 ister; yoksa
  "SQL 334 henüz çalıştırılmamış" der).

### Uygulama diğer
- Uzak bayraklar artık yalnız KAPATABİLİR (`runtime.js` bayrak): Apple 2.3.1(a) "gizli özellik /
  uzaktan yapılandırma" reddine karşı. İnceleme ortamı algılayan hiçbir kod yok (tarandı).
- Maliyet koruması: periyodik sorgular (sohbet 8 sn, oturum 8 sn, gelen kutusu 12/15/30 sn,
  2 dk) uygulama arka plandayken istek atmıyor (`supabase.js` › `onPlanda`).
- `eas.json` appleTeamId = D57RLX67QJ. Eksik: `appleId` (e-posta) ve `ascAppId`.
- Yasal metin (app + site + BO aynı): plan kredisi devretmez; paket ve ağırlama kredisi
  süresiz; Yolcu kayıtta 1 kredi; haftalık bağlantı sınırı (3 / 15 / sınırsız).
- Ölü i18n anahtarları silindi: planMonthlyCredits(Why), planOpenReq, planConnWeek,
  planConnUnlimited (avantajlar zaten DB'den geliyor).
- Mağaza görselleri: İstek Gönder başlığındaki beyaz şerit çekim zamanlamasıydı (modal
  animasyonu yarıda yakalanıyordu); bekleme 900 → 2000 ms, yeniden üretildi.

## Sürümler
- app 6.5.0 · versionCode 288 · buildNumber 282
- site 0.70.3 · BO 1.98.0

## Supabase'de çalıştırılacak SQL (sırayla; `sql/SQL_SIRA.txt` ile aynı)
330 → 331 → 332 → 333 → **334** (hangisi koşulmadıysa oradan).
334 = SON MODEL (16 Ekim'deki tarif geçersiz): Yolcu kayıtta 1 kredi / aylık yok · Sık Uçan
₺99,99 · 3 kredi · Kâhya ₺199,99 · 7 kredi · paketler 1/3/5 = ₺79,99/199,99/299,99 · plan
kredisi devretmez · haftalık bağlantı hakkı · Tanış kaçağı göstergesi · küfür süzgeci.

## Testler (sayılarla)
- app `npm run verify`: **77/77 temiz** (ilk koşu 9 kırmızıydı: açılış ham renkleri → `ACILIS`
  jetonu, telif defteri, marka üreticisi, paritede tek başına elevation, palet muafiyeti,
  ölü metin 5, BO ekransız fonksiyon, test taklitlerinde `Animated.multiply`, bayat dokunma
  makbuzu → hepsi kapatıldı).
- akış e2e (`web_sahne/akis_e2e.py`): **192/192 akış kontrolü**, toplam 234 ✓ / 0 ✗.
- sahne çekimi + dokunma yolu: düşen adım **0**. 3 sahnede (05b, 32, 17_kayit) betik adımı
  zaman aşımı var: 6.4.0'daki çekimle BİREBİR aynı, bu turda oluşmadı (ayrı ele alınmalı).
  Bu yüzden bağlantı sayfasındaki yeni "haftalık hak" satırı sahne çekiminde görünmüyor;
  sunucu tarafı yerel PG'de t334b 7/7 ile doğrulandı (16. istek reddediliyor).
- marka_check: üretici = sevkiyat birebir; ikon opak 1024×1024.
- açılış web doğrulaması: 8 kare, sayfa hatası 0.
- site: `node verify.js` 7/7 · build ✓ · mobil taşma 320/360/390 px'te 0.
- BO: `node check.js` ✓ · build ✓.

## Açık kalanlar / Gökberk'ten beklenenler
1. **Android hedef API 36 (KARAR):** Play 31 Ağu 2026'dan beri yeni uygulama/güncellemede
   targetSdk 36 istiyor; build 35 hedefliyor (Expo SDK 52). Seçenekler: (a) Play Console'dan
   1 Kasım'a kadar uzatma iste + Expo SDK 54'e geçiş (kalıcı, kapsamlı iş, cihazda test ister);
   (b) yalnız uzatma. Öneri: uzatmayı hemen iste, SDK 54 geçişini ayrı oturumda yap.
2. App Store Connect: vergi formu (W-8BEN), DSA "not trader" + 27 AB ülkesini kaldır, banka,
   Paid Apps = Active. Adreste posta kodu 16018 → 06810 düzelttir.
3. `eas.json` için Apple hesabı e-postası + ascAppId.
4. Site plan kartları (son model) önizleme → onay → uygula.
5. Supabase spend cap açık mı kontrol et; Vercel Pro'ya geçilirse Spend Management.
6. Play kapalı test: 12 testçi ilk gün eklensin; veri güvenliği formu koda göre.

## APK
- Android önizleme APK 6.5.0 (288): https://expo.dev/artifacts/eas/zXWQvHVHfA_7ivMnlixNOHD1CCzMV_Uk1i2Kt7IpHjg.apk
