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
module.exports = ({ config }) => {
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
};
