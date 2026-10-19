# DEVIR — 18 Ekim 2026 · app 6.5.1 · site 0.70.4 · BO 1.98.1

## Ne değişti

### Android hedef API 36 (Google Play kuralı, 31 Ağu 2026'dan beri zorunlu)
- `rnapp/app.json` › expo-build-properties: `targetSdkVersion` 35 → **36** (compileSdk 35 kaldı:
  RN 0.76'nın AGP 8.6'sı SDK 36 ile derlemeyi desteklemiyor; hedef sürüm derlemeden bağımsız).
- Ölçülen iki Android 16 riski kapatıldı:
  1. **Geri tuşu:** hedef 36'da Android 16 `onBackPressed`'i çağırmıyor; RN 0.76 geri tuşunu
     tam oradan alıyor (`ReactActivity.java:98`). `app.config.js` manifeste
     `android:enableOnBackInvokedCallback="false"` yazıyor (introspect ile doğrulandı).
  2. **Alt gezinti çubuğu:** Android 15-16 kenardan kenara çiziyor; `ALTPAD` Android'de sabit
     0'dı → sekme çubuğu gezinti çubuğunun altında kalabilirdi. Artık cihazın safe-area ölçüsü.
- Expo SDK 54'e geçiş YAPILMADI (gerek kalmadı). Play süre uzatması İSTEMEYE GEREK YOK.

### Site 0.70.4
- Plan kartları son model: başta "Ayda N lounge girişi · giriş başına ≈ ₺X", altında
  uygulama kataloğuyla birebir avantajlar; ana sayfada da TAM kart (`ozet` kaldırıldı); altta
  kredi kuralı + paket fiyatları + devretmeme. Cormorant'ın eski stil "1"i "ı" gibi okunuyordu
  → `lining-nums`.
- /ayricaliklar "Erken erişime katıl" üst boşluğu (32 px). SSS "Ücretli mi?" son model.
  Host kazanç tablosunda "Sık Uçan · Aylık 6 kredi" → 3.
- İkonlar titresimli üretimle yenilendi (site + BO).

### App 6.5.1
- Hedef API 36 + geri tuşu + alt güvenli alan (yukarıda).
- Herkese açık profil: görünürlük kararı sunucunun `profil_gorunur_mu` kuralından (eşik 40).
  Uygulama 55 diyordu → Tanış'ta görünen kişinin profili boş açılabiliyordu.
- Sahne: 17_kayit (e-posta yer tutucusu "ad@ornek.com" olmuştu), 05b + 32 (sahne tohumu yalnız 3
  kişinin güven puanını geri yazıyordu; Kaan 64 → 32'ye düşüp "Güvenilir üyeler"e açık
  profilleri göremiyordu), yeni 32b_baglanti_hakki sahnesi ("Bu hafta 3/3 bağlantı isteği
  hakkın kaldı." görünüyor), `supabase_sahte.js` `onPlanda`.

## SQL
Yeni SQL yok. Bekleyen: 330 → 331 → 332 → 333 → 334 (`sql/SQL_SIRA.txt`).

## Testler (sayılarla)
- app `npm run verify`: ilk koşu 2 kırmızı (bayat dokunma makbuzu + 1 yeni sıralı ağ turu) → ağ turu
  `Promise.all`'a alındı, makbuz sahne koşusuyla yenilendi.
- sahne çekimi: hata=0 (bilerek arıza sahneleri hariç); 17_kayit · 05b · 32 · yeni 32b temiz.
  Dokunma yolu düşen adım 0.
- akış e2e: **193/193**.
- site: verify 7/7 · build ✓ · plan kartları 375 ve 1280 px'te yatay taşma 0.
- BO: check ✓ · build ✓.
- Android yapılandırma (introspect): targetSdk 36 · compileSdk 35 · manifest geri tuşu bayrağı.

## APK
- Android önizleme APK 6.5.1 (289): https://expo.dev/artifacts/eas/82Klok6D_fEl2rGqEwfYjGmz57iTc37xZhLNAName7s.apk

## Telefon doğrulama önerisi (onay bekliyor)
https://claude.ai/artifact/WSHDf9qARJtv5PtjbKMq5u — Firebase Telefon Doğrulama (günde 10 SMS
ücretsiz), panel API'de jeton doğrulama, eşik 40 → 25 önerisi, 6 ekran.

## Açık kalanlar / Gökberk'ten beklenenler
1. **Yeni kullanıcı Tanış'ta neredeyse kimseyi göremiyor (KARAR):** profillerin varsayılan
   görünürlüğü "Güvenilir üyeler" (Trusted+) ve görmek için güven puanı ≥ 40 gerekiyor. Yeni
   kayıt olan kullanıcının puanı ölçüldü: yalnız e-posta 16, e-posta + telefon 26 (ikisi de < 40). Yayın gününde
   herkes yeni olacağı için Tanış boş görünür. Seçenekler: (a) varsayılanı "Herkes" yap,
   (b) eşiği "telefonu doğrulanmış" seviyesine indir, (c) olduğu gibi kalsın.
2. Uygulama içi bildirim şeridi (uygulama açıkken gelen mesaj/onay için üstten kayan kart):
   tasarım önizlemesi hazırlanacak → onay → uygula.
3. İlk kullanım rehberi (sekmelerin ne işe yaradığı, kredi/LoungePuan/güven açıklaması):
   önizleme → onay → uygula.
4. Push kontrolü: Supabase › Database › Extensions › **pg_net** açık mı; expo.dev › proje ›
   Credentials › Android › **FCM V1 service account key** yüklü mü; iOS push anahtarı ilk iOS
   build'inde EAS'ın sorusuna "evet" ile oluşur.
5. `eas.json`: Apple hesabı e-postası (`appleId`) + `ascAppId` (App Store Connect › uygulama ›
   App Information › Apple ID: 10 haneli SAYI; Team ID D57RLX67QJ ayrı bir şey).
6. App Store Connect iş ayarları (vergi, DSA, banka, posta kodu) ve SQL'ler — Gökberk yapacak.


---

# EK (18 Ekim, ikinci yarı) — telefon doğrulama · app 6.6.0 · BO 1.99.0

## Gökberk onayları
- Telefon doğrulama akışı (önizleme https://claude.ai/artifact/WSHDf9qARJtv5PtjbKMq5u): "gayet iyi".
  Firebase + eşik 25 dahil.
- Uygulama içi bildirim şeridi ve ilk kullanım ipuçları: önizleme hazırlandı
  (https://claude.ai/artifact/AutU7VdeomJ6ZSYRh8YTHm) — ONAY BEKLİYOR, uygulanmadı.

## Ne değişti
- **SQL 335** `335_telefon_firebase_dogrulama.sql`: `telefon_gonderim_izni` (yalnız TR cep,
  kullanıcı/numara başına günde 3, 60 sn kilit), `telefon_dogrulandi_yaz` (yalnız service_role),
  numara değişince doğrulamayı düşüren tetikleyici, `dogrulama_kanali.firebase_hazir`, eşik 40 → 25.
  Kanal KAPALI başlar (`beta_settings.telefon_kanali`). Yerel test **10/10**.
- **BO 1.99.0** `/api/telefon-dogrula`: Supabase oturum jetonu + Google imzalı Firebase jetonu
  (issuer/audience = `beta_settings.firebase_proje_id`, giriş yöntemi phone, 10 dk) → RPC.
  Middleware'de yalnız bu yol + POST açık. Yerel deneme: jetonsuz 401, sahte jeton 401, GET → login.
- **App 6.6.0**: `src/telefon.js` (TelefonDogrulamaSayfasi: numara · onay · kod · başarı),
  "Telefonu Doğrula" ekranı Firebase açıkken "Doğrulamalarım" (e-posta/telefon/kimlik satırları),
  numarası kayıtlı ama doğrulanmamış kullanıcıya bir kez teklif (yeni hesapta "son adım").
  @react-native-firebase/app + auth 21.14.0: YALNIZ yapılandırma dosyası varsa bağlanır
  (`react-native.config.js` + `app.config.js`; iOS'ta o zaman statik framework). Dosya yoksa
  build bugünkü gibi; uygulama e-posta yoluna düşer. Web'de taklit (`web_sahne/firebase_sahte.js`).
  Yeni sahneler: 93_tel_onay · 93b_tel_kod · 93c_tel_basari · 93d_tel_numara.
- Rehber: 10b (Firebase SMS adımları + kanalı açan iki SQL satırı), push kontrolleri (pg_net, FCM V1),
  "Yayından önce: hesap ve hukuk" (Supabase Pro, Vercel Pro, VERBİS, İYS), SQL listesine 334 + 335.

## 19 Ekim ekleri
- **Bildirim yönlendirmesi ölçüldü** (yerel DB, 21 tür): ilan kapandı, sistem kategorisindeki kredi,
  plan değişikliği ve kaçırılan fırsat özeti hiçbir yere gitmiyordu → SQL 335 §6b `bildirim_hedefi`
  (plan/ilan · cüzdan · planlar · keşfet) + App.js `bildirimeGit` (planlar, kesfet). Ölçüm sonrası
  hedefsiz kalan yalnız genel duyuru (şeritte Bildirimler sayfasını açacak).
- Önizleme v3 (bildirim şeridi + ilk kullanım): ince şerit (4 sn, parmak üstündeyken bekler, yukarı
  it = kapat, dokun = ilgili ekran), ipuçları karartılmış katmanda, "Nasıl çalışır?" ana sayfada
  DÜĞME (kendiliğinden açılmaz). Onay bekliyor.
- Kurulum tablosu: 315-335 elle eklenmiş satırlar korunarak 335 eklendi (tablo_uret.py elle
  eklenenleri siliyor — koşma). `tablo_sina.py` 16:09'da bir SQL dosyasında takıldı, durduruldu.

## Gökberk'ten beklenen
1. Rehber 10 ve 10b → "Firebase tamam" → Firebase'li build → iki SQL satırı ile kanal açılır.
2. SQL: 330 → … → 334 → **335**.
3. Bildirim şeridi + ilk kullanım önizlemesine onay.

## APK 6.6.0 ve testler (19 Ekim)
- Android önizleme APK 6.6.0 (290): https://expo.dev/artifacts/eas/BGsbUcP354ppc3FcA2oqejMZOpEiGtgP3MImigM_dUY.apk
- sahne çekimi: hata=0 (arıza sahneleri hariç) · dokunma yolu düşen 0 · akış e2e **197/197**.
- Önizleme v5 (bildirim şeridi + ilk kullanım + Keşfet uçuş çipleri) onay bekliyor: https://claude.ai/artifact/AutU7VdeomJ6ZSYRh8YTHm
