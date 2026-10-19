// ============================================================================
// react-native.config.js — 18 Ekim · Firebase yerel kodu YALNIZ yapılandırma varsa bağlanır.
//
// @react-native-firebase/* paketleri node_modules'ta durduğu için RN autolinking onları her
// build'e otomatik bağlar. Ama Firebase yapılandırma dosyası olmadan:
//   · iOS: Firebase pod'ları statik framework ister ve GoogleService-Info.plist olmadan uygulama
//     açılışta Firebase'i kuramaz → build düşer ya da açılışta çöker.
//   · Android: google-services.json olmadan Firebase başlatılamaz.
// Bu yüzden dosya (ya da EAS "file" ortam değişkeni) yoksa o platformda bağlanmaz; uygulama
// src/telefon.js'teki `telefonHazir()` ile Firebase'in yokluğunu görür ve eski e-posta yoluna düşer.
// Aynı karar app.config.js'te (eklentiler + iOS statik framework) verilir: ikisi birlikte değişir.
// ============================================================================
const fs = require("fs");
const path = require("path");
const var_ = (env, yerel) => {
  const y = process.env[env];
  if (y && fs.existsSync(y)) return true;
  return fs.existsSync(path.join(__dirname, yerel));
};
const androidHazir = var_("GOOGLE_SERVICES_JSON", "google-services.json");
const iosHazir = var_("GOOGLE_SERVICE_INFO_PLIST", "GoogleService-Info.plist");
const platformlar = {
  ...(androidHazir ? {} : { android: null }),
  ...(iosHazir ? {} : { ios: null }),
};
module.exports = {
  dependencies: {
    "@react-native-firebase/app": { platforms: platformlar },
    "@react-native-firebase/auth": { platforms: platformlar },
  },
};
