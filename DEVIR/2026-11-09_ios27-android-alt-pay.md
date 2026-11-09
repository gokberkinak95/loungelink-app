# 9 Kasım 2026 — iOS 27 açılış çökmesi, Android alt pay ve açılış sahnesi

## Ne değişti
- `rnapp/eas.json`: iOS imajı `latest` → `macos-tahoe-26.5-xcode-26.6` (production + preview-device).
  KÖK (çökme raporu LoungeLink-2026-11-09-110640.ips): `latest` = Xcode 27.1 / iOS 27.1 SDK.
  iOS 27 SDK ile derlenen ve UIScene yaşam döngüsüne geçmemiş uygulamayı iOS 27.2 açılışta
  durduruyor (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`, EXC_BREAKPOINT).
  294/295/299 hep Xcode 27.1 ile derlenmişti. RN 0.76 / Expo 52 UIScene desteklemiyor.
  **YAPILACAK (2027 baharından önce):** Apple iOS 27 SDK'yı zorunlu kılmadan Expo SDK yükseltmesi
  + UIScene. O güne kadar `image` "latest"e ÇEVRİLMEZ.
- `rnapp/src/ui.js`: `ALTPAD` Android'de pencerenin gezinti çubuğuyla gerçek örtüşmesi
  (kenardan kenara olmayan pencerede ilk ölçü 48dp bildiriyordu → sekme çubuğu yukarıda kalıyordu).
- `rnapp/src/acilis.js`: sahne tam kök (`bottom: 0` + onLayout ölçüsü; Android pencere yüksekliği
  durum çubuğunu saymıyordu) + Android `elevation: 1000` (Başla düğmesi bulutların üstünde çiziliyordu).
- `rnapp/src/supabase.js` `logError(screen, err, code, context)`; `rnapp/src/i18n.js` mapErr
  TypeError sınıfında çağıran yığınını `context.yigin`e yazar. Android'deki 3 "undefined is not a function"
  kaydı `@example.com` test hesaplarından (kodda geçmiyor; muhtemelen Google'ın otomatik inceleme robotu).

## Sürümler
- app 1.0.0 · iOS buildNumber **300** · Android versionCode **307**.
- iOS 300 ad hoc (2c92ec1a) Gökberk'in iPhone'unda (iOS 27.2) açıldı, sorun yok.
- iOS 300 production (e1ecb22c) + auto-submit App Store Connect'e.
- Android 307 (db809501) + auto-submit Play dahili test taslağı.
- 294–299 iOS / 301–306 Android kullanılmayacak.

## SQL
- Yeni SQL yok. 349 canlıda koştu (3/3 true). İnceleme hesabı hazır (10 kredi, doğrulandı).
- Bekleyen: DENETIM_TAM'ı 349 sonrası yeniden koşmak.

## Testler
- `node check.js` temiz (iki kez). Render/e2e bu turda koşulmadı (değişiklikler yalnız yerel cihaz davranışı).

## Açık / Gökberk'ten
- App Store: build 300'ü seç, gönder. Play: 307'yi dahili testte yayınla, kapalı teste 12 kullanıcı × 14 gün.
- Expo bu ayın $45 kredisini doldurdu; sonraki build'ler ücretli (iOS $2, Android $1). Mağaza onayı sonrası
  ücretsiz plana geçiş önerildi.
