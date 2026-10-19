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

module.exports = ({ config }) => firebaseEkle(geriTusuEski(iosPlist(hazirla(config))));

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
