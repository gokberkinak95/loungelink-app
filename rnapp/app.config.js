// ============================================================================
// app.config.js — `app.json`ı OKUR, EKSİK DOSYALARA GÖRE DÜZELTİR
//
// 🔴 NEDEN VAR
// `app.json` içinde `android.googleServicesFile: "./google-services.json"`
// yazıyor ama o dosya repoda YOK — Firebase hesabı Gökberk'te. EAS build
// uzakta `prebuild` koşarken bu dosyayı arıyor ve BULAMAYINCA build ~5
// dakika sonra düşüyor. Yani push bildirimi için konmuş bir satır,
// bildirimle hiç ilgisi olmayan bir APK'nın da alınmasını engelliyor.
//
// 🆕 SINIF: "HENÜZ ELDE OLMAYAN BİR VARLIĞA YAPILAN ZORUNLU ATIF, O
// VARLIKLA İLGİSİ OLMAYAN İŞLERİ DE DURDURUR — ATFI KOŞULLU YAP."
//
// Expo önce `app.json`ı okur, sonra onu bu dosyaya `config` olarak verir.
// Burada tek bir şey yapıyoruz: dosya diskte yoksa alanı düşürüyoruz.
// Dosyayı klasöre koyduğun an — hiçbir şeyi değiştirmeden — geri geliyor.
//
// ⚠️ DÜŞTÜĞÜNDE NE OLMUYOR: Android push bildirimi. Uygulamanın geri
// kalanı çalışıyor. Uyarı build günlüğüne AÇIKÇA yazılıyor ki
// "bildirimler neden gelmiyor" sorusu bir gizem olmasın.
// ============================================================================
const fs = require("fs");
const path = require("path");

// 3 Ekim — EAS'TA DOSYA YOLU. `google-services.json` .gitignore'da ve git kökü C:\LoungeLink:
// EAS yüklemesi ignore'lu dosyayı TAŞIMAZ (yerelde dursa bile uzakta yok sayılır). Bu yüzden
// EAS "file" tipi ortam değişkeni `GOOGLE_SERVICES_JSON` (eas env:create … --type file) önce okunur;
// EAS onu build makinesinde geçici bir dosyaya yazar ve yolunu bu değişkene koyar.
// 18 Ekim — ANDROID 16 (hedef API 36) GERİ TUŞU. Google Play 31 Ağustos 2026'dan beri hedef 36
// istiyor. Hedef 36 olan uygulamada Android 16, "tahmini geri" yüzünden Activity.onBackPressed'i
// ÇAĞIRMAZ; RN 0.76'nın ReactActivity'si geri tuşunu tam oradan alıyor (node_modules'ta ölçüldü:
// ReactActivity.java:98). Sonuç: BackHandler hiç çalışmaz, geri tuşu uygulamayı kapatır.
// Google'ın geçiş bayrağı: <application android:enableOnBackInvokedCallback="false">.
// RN, OnBackPressedCallback'e geçince (Expo SDK 54+) bu satır kaldırılır.
const { withAndroidManifest } = require("expo/config-plugins");
function geriTusuEski(config) {
  return withAndroidManifest(config, (c) => {
    const app = c.modResults.manifest.application && c.modResults.manifest.application[0];
    if (app) app.$["android:enableOnBackInvokedCallback"] = "false";
    return c;
  });
}

// 18 Ekim — FIREBASE (telefon SMS doğrulaması, SQL 335). Yapılandırma dosyası olan platformda
// eklentiler eklenir; iOS'ta Firebase pod'ları statik framework ister. Dosya yoksa hiçbiri eklenmez
// ve react-native.config.js yerel kodu o platformda bağlamaz (ikisi aynı kararı verir).
function iosPlist(config) {
  const easYol = process.env.GOOGLE_SERVICE_INFO_PLIST;
  const yerel = path.join(__dirname, "GoogleService-Info.plist");
  const yol = easYol && fs.existsSync(easYol) ? easYol : (fs.existsSync(yerel) ? "./GoogleService-Info.plist" : null);
  if (yol) { config.ios = config.ios || {}; config.ios.googleServicesFile = yol; }
  return config;
}
function firebaseEkle(config) {
  const platform = process.env.EAS_BUILD_PLATFORM;
  const androidOk = !!(config.android && config.android.googleServicesFile);
  const iosOk = !!(config.ios && config.ios.googleServicesFile);
  const hazir = platform === "android" ? androidOk : platform === "ios" ? iosOk : (androidOk || iosOk);
  // 31 Ekim: uygulama Firebase'in o platformda bağlı olup olmadığını buradan okur (telefon.js).
  // iOS'ta plist yokken JS `require("@react-native-firebase/auth")` yerel modülü arıyor ve
  // try/catch DIŞINDA fırlatıyordu → girişten hemen sonra uygulama kapanıyordu.
  config.extra = { ...(config.extra || {}), firebase: { android: androidOk, ios: iosOk } };
  if (!hazir) return config;
  config.plugins = [...(config.plugins || []), "@react-native-firebase/app", "@react-native-firebase/auth"];
  if (iosOk) {
    config.plugins = config.plugins.map((p) => {
      if (Array.isArray(p) && p[0] === "expo-build-properties") {
        const ayar = { ...(p[1] || {}) };
        ayar.ios = { ...(ayar.ios || {}), useFrameworks: "static" };
        return [p[0], ayar];
      }
      return p;
    });
  }
  return config;
}

// 30 Ekim — İLK iOS BUILD'İ DÜŞTÜ: EAS'ın güncel Xcode'u (image: latest) 15.0 altındaki hedefleri hata sayıyor;
// AsyncStorage (13.4) ve RevenueCat / PurchasesHybridCommon (13.0) pod'larının kaynak paketleri kendi hedeflerini
// taşıyor ve expo-build-properties'in deploymentTarget'ı (15.1) onlara inmiyor. Podfile post_install'da 15.1'in
// altındaki BÜTÜN pod hedefleri 15.1'e çekilir. (ölçüm: build d75a9691 xcode günlüğü, "ARCHIVE FAILED")
// 30 Ekim (2) — ikinci iOS build: fmt consteval hatası (Xcode 26.4+). Aynı post_install'da base.h yaması.
const { withDangerousMod } = require("expo/config-plugins");
function podHedefi(config) {
  return withDangerousMod(config, ["ios", async (c) => {
    const yol = path.join(c.modRequest.platformProjectRoot, "Podfile");
    if (!fs.existsSync(yol)) return c;
    let s = fs.readFileSync(yol, "utf8");
    if (s.includes("LL_POD_HEDEFI")) return c;
    const kanca = "post_install do |installer|";
    if (!s.includes(kanca)) return c;
    s = s.replace(kanca, kanca + `
    # LL_POD_HEDEFI - Xcode rejects deployment targets below 15.0 (app.config.js podHedefi)
    installer.pods_project.targets.each do |t|
      t.build_configurations.each do |bc|
        v = bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
        bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.1' if v.nil? || v.to_f < 15.1
      end
    end
    # LL_FMT_CONSTEVAL - Xcode 26.4+ (Apple clang 21) rejects fmt 11.0.2 consteval path
    # (fmtlib/fmt#4740). -DFMT_USE_CONSTEVAL=0 is not enough: base.h redefines the macro.
    fmt_base = File.join(installer.sandbox.root.to_s, 'fmt', 'include', 'fmt', 'base.h')
    if File.exist?(fmt_base)
      icerik = File.read(fmt_base)
      yeni = icerik.gsub('define FMT_USE_CONSTEVAL 1', 'define FMT_USE_CONSTEVAL 0')
      if yeni != icerik
        File.chmod(0644, fmt_base)
        File.write(fmt_base, yeni)
        Pod::UI.puts "[LoungeLink] fmt: FMT_USE_CONSTEVAL 0"
      else
        Pod::UI.warn "[LoungeLink] fmt base.h kalibi bulunamadi; consteval yamasi uygulanmadi"
      end
    end`);
    fs.writeFileSync(yol, s);
    return c;
  }]);
}

module.exports = ({ config }) => podHedefi(firebaseEkle(geriTusuEski(iosPlist(hazirla(config)))));

function hazirla(config) {
  const easYol = process.env.GOOGLE_SERVICES_JSON;
  if (easYol && fs.existsSync(easYol) && config.android) {
    config.android.googleServicesFile = easYol;
    return config;
  }
  const yol = path.join(__dirname, "google-services.json");
  const varMi = fs.existsSync(yol);

  if (!varMi && config.android && config.android.googleServicesFile) {
    delete config.android.googleServicesFile;
    console.log(
      "\n⚠️  google-services.json YOK → app.config.js `googleServicesFile`" +
      "\n    alanını düşürdü. Build devam ediyor, ANDROID PUSH ÇALIŞMAYACAK." +
      "\n    Firebase'den indirip bu klasöre koyduğunda kendiliğinden geri gelir.\n"
    );
  }
  return config;
}
