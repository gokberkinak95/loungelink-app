# DEVIR — 15 Ekim 2026 · mağaza hazırlığı (iOS + RevenueCat + bireysel yasal) · app 6.4.0

Gökberk: Apple Developer + Google Play (BİREYSEL) hesapları, Cloudflare'dan loungelink.co,
RevenueCat entegrasyonu; iOS'u ortaya çıkar; ret yememek için her şeyi ayarla; KVKK metinleri bireysel.

**Rehber (adım adım, işaretlenebilir):** https://claude.ai/artifact/DRgmDDYaZeHkcYCcWx8oWS

## Sürümler
- App **6.4.0** · versionCode **286** · iOS buildNumber **280** (yeni native paketler: react-native-purchases 10.13.1, react-native-safe-area-context 4.12.0)
- BO **1.97.0** (yeni `/api/revenuecat`) · site **0.70.1** (yasal metin + hesap-sil)

## Değişenler
**Ödeme (RevenueCat)**
- `rnapp/src/odeme.js` (yeni): yapılandırma, giriş/çıkış (RevenueCat kullanıcısı = Supabase uid), teklifler, satın alma, geri yükleme, abonelik yönetimi, webhook'u bekleme.
  - `app.json extra.revenuecat.{ios,android}` boşken modül KAPALI: eski davranış korunur.
- `App.js`: oturum açılınca `odemeGiris`, çıkışta `odemeCikis`.
- `ekranlar_yalin.js`:
  - Plans: mağaza fiyatı, satın alma, abonelik açıklaması (iOS/Android ayrı), Koşullar/Gizlilik bağlantıları, Geri yükle, Aboneliği yönet.
  - Wallet: paketlerde mağaza fiyatı + Satın al.
- BO `app/api/revenuecat/route.js` + `middleware.js` istisnası (yalnız POST, gizli anahtar sabit zamanlı karşılaştırılır).
- BO `app/manage/satin-almalar` (yeni, menü: Satın Almalar · finans): RevenueCat olayları ve sonuçları.
  - Ortam değişkeni: `REVENUECAT_WEBHOOK_AUTH`.
- SQL 332:
  - `iap_urunleri` (ürün→paket/plan eşlemesi), `abonelikler`, `rc_olaylari` (tekil), `rc_olay_isle` (yalnız service_role), `aboneligim()`, `bo_rc_olaylari()`.
  - **Hata düzeltmesi:** `plan_kredisi_yerlestir` text = plan_type hatasını yutuyordu → aylık plan kredisi hiç verilmiyordu.
- Ürün kimlikleri:
  - `ll_kredi_1/3/6`;
  - `ll_sik_ucan_aylik/yillik`, `ll_kahya_aylik/yillik`;
  - Google: `ll_sik_ucan:aylik` biçimi `':'→'_'` ile aynı koda iner.

**iOS hazırlığı**
- `TOPPAD` iOS'ta sabit 48 yerine cihazın güvenli alanı (Dynamic Island 54–59pt). Yeni `ALTPAD` (ev göstergesi).
  - Alt çubuk, iki sohbetin girdi çubuğu, iki alt sayfa ve biniş kartı vizörü bu payı alıyor.
- `KlavyeKabi` + `useKlavyeAcik` (ui.js): tam ekran katman ve girdi taşıyan 5 Modal iOS'ta klavyeden kaçıyor.
  - Önce iOS'ta klavye girdiyi örtüyordu; Android değişmedi.
- Apple ile giriş: resmi `AppleAuthenticationButton` (logosuz özel düğme 4.8/HIG reddi sebebiydi). Yalnız iOS'ta görünür.
- `app.json`:
  - `ios.privacyManifests` (UserDefaults CA92.1, FileTimestamp C617.1, SystemBootTime 35F9.1, DiskSpace E174.1);
  - `expo-sensors` plugin + hareket izni metni (Pedometer → ITMS-90683 yükleme reddi);
  - `extra.revenuecat`.
- `eas.json`: production iOS image; submit.ios (REPLACE_ alanları Team ID / ASC App ID gelince dolacak); submit.android (play-service-account.json, internal, draft).

**Yasal (bireysel)**
- `rnapp/src/legal.js` (→ BO `lib/legal.js`, site `lib/legal-source.js` kopyalandı, üçü aynı):
  - veri sorumlusu Gökberk İnak (gerçek kişi);
  - satın alma ve abonelik maddeleri, cayma hakkı istisnası, Apple standart EULA bağlantısı;
  - hizmet sağlayıcılar (Supabase, Expo, Apple, Google, RevenueCat, Resend, Cloudflare, Vercel) ve yurt dışı aktarım;
  - kimlik belgesi/selfie, sıfır tolerans + 24 saat inceleme, 14 günlük silme süreci.
  - LEGAL_VERSION 2026-10-15.
- `deleteAccountBody` (TR/EN) gerçek davranışa göre (14 gün, mağaza aboneliği uyarısı); site `/hesap-sil` aynı.
- BO `/hesap-sil`: `kvkk@loungelink.app` → `kvkk@loungelink.co`.
- "Beta" metinleri kaldırıldı (Apple 2.2):
  - i18n: `e_insufficient_credits`, `walletBetaNote`, `walletRequestOzet`, `ledBetaSignup`;
  - SQL 333: `request_credit_topup` cümleleri.

**Aylık plan kredisinin yan etkileri (332 düzeltmesi sonrası ölçüldü)**
- Kredi artık gerçekten veriliyor: her kullanıcı ayın ilk açılışında planının payını alır (Yolcu 1, Sık Uçan 6, Kâhya 12).
- Bildirim kategorisi `system` → `credits`: dokununca Cüzdan açılır; önce hedefsizdi.
- Ana sayfa bakiyesi yüklemeden sonra `bakiyeTazele` ile yeniden okunur.
  - `reload` KULLANILMADI: bütün sekmeleri yeniden kurup açılıştaki dokunuşu bozuyordu.
- App: `plan_kredisi_yerlestir`'in RPC hatası ve içeride yuttuğu `ok:false` artık `logError`'a düşüyor.

**İnceleme hesabı** — SQL 333 `inceleme_hesabi_hazirla(email)`: doğrulanmış, 10 kredi, `test_gorunurlugu` (vitrini görür).

## Supabase'de çalıştırılacak (sırayla)
1. 330 (çalıştırılmadıysa) · 2. 331 (çalıştırılmadıysa) · 3. **332** · 4. **333**
5. Uygulamada inceleme@loungelink.co ile kayıt olduktan sonra: `select public.inceleme_hesabi_hazirla('inceleme@loungelink.co');`

## Koşulan testler
- SQL 332 senaryo testi **15/15**:
  - kredi, tekrar olay, tekrar makbuz;
  - Google abonelik + aylık kredi; yenileme kapalı; yükseltme + eski bitiş; bitiş;
  - iade, bakiye 0'da iade, takma ad;
  - kullanıcı/ürün yok, TEST, defter, istemci yetkisi.
- SQL 333: tanımsız e-posta / hazırla / tekrar (idempotent) ✓.
- Web sahne e2e tam regresyon (13 bölüm): ilk koşu **188/192**.
  - 4 kırmızının hepsi aylık kredi düzeltmesinin görünür kıldığı şeylerdi (şerit bakiyesi, kredisiz test varsayımı, 208, bildirim hedefi).
  - Düzeltildi; ana + kesfet + ekranlar yeniden koşuldu: **49/49** → toplam **192/192**.
- check.js temiz · render 39/39 · be: yetki 0 bulgu, TR+EN eksik 0.
- verify:
  - ham kod: yeni `olay_kimligi_bos` errMap'e eklendi;
  - ölü metin: `continueWithApple` Apple düğmesinin bekleme etiketi oldu;
  - yüzey: `bo_rc_olaylari` → BO ekranı yazıldı;
  - dokunma makbuzu: sahne yeniden koşuldu (düşen adım 0, makbuz güncel);
  - marka_check: cairo yok (ortam).
- BO check + build ✓ (`/api/revenuecat`, `/manage/satin-almalar`). Site verify 7/7 + build ✓.
  - Ekran görüntüleri 6.3.1'de; 6.4.0 gösterilen ekranları değiştirmediği için SURUM.json `kabul_edildi: true` ve gerekçesi yazıldı.
  - Yeni çekim Gökberk onayına bağlı.

## Gökberk'ten beklenen
- Rehberdeki hesaplar.
- Bana iletilecekler: **Apple Team ID**, **App Store Connect Apple ID (ascAppId)**, **RevenueCat public anahtarları** (`appl_…`, `goog_…`).
- Play hesabı açılınca haber: production AAB'yi alırım.
- İlk iOS build'ini Gökberk başlatmalı (Apple 2FA etkileşimli): `npx eas build --platform ios --profile production`.

## Ölçülen açıklar (rehberde)
- EAS'ta **hiç ortam değişkeni yok** → `GOOGLE_SERVICES_JSON` yok → Android build'lerinde push hiç yapılandırılmamış. Firebase adımları rehber §10.
- Supabase yerleşik e-postası ekip dışına göndermiyor → Resend + özel SMTP rehber §2 (yayından önce zorunlu).
- Yasal metindeki adres "İstanbul, Türkiye — APA GIZ PLAZA" korunuyor (Gökberk'in önceki tercihi); bireysel yapıda değiştirmek isterse tek satır.
