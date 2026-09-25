// ============================================================
// metro.config.js — LL_SAHNE=1 iken WEB SAHNESİ için modül yönlendirme.
//
// 🔴 NEDEN VAR: 3 Eylül'de cihaz ekran görüntüleri ile "önizleme"
// arasındaki fark ölçüldü — önizleme PIL ile ÇİZİLİYORDU, uygulama
// kaynağından RENDER edilmiyordu. Çift LOUNGELINK, düz bant, 5 kutulu
// Akışım hiç görülmedi. Artık önizleme GERÇEK React ağacından geliyor:
// react-native-web + Chromium (web_sahne/). Bu dosya yalnız o modda
// (LL_SAHNE=1) iki şeyi değiştirir:
//   · src/supabase.js → web_sahne/supabase_sahte.js (fikstürlü taklit)
//   · App.js          → web_sahne/Galeri.js (senaryo seçici; App'i sarar)
// LL_SAHNE yoksa bu dosya Expo'nun varsayılanının AYNISIDIR — EAS build
// ve `expo start` hiçbir şey fark etmez.
// ============================================================
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const config = getDefaultConfig(__dirname);

if (process.env.LL_SAHNE === "1") {
  const KOK = __dirname;
  const YONLENDIR = {
    [path.join(KOK, "src", "supabase.js")]: path.join(KOK, "web_sahne", "supabase_sahte.js"),
    [path.join(KOK, "App.js")]: path.join(KOK, "web_sahne", "Galeri.js"),
  };
  const asil = config.resolver.resolveRequest;
  config.resolver.resolveRequest = (context, moduleName, platform) => {
    // Galeri ve taklit dosyalarının KENDİ importları yönlendirilmez
    // (Galeri gerçek App'i, taklit gerçek supabase'i bilerek çağırmaz).
    const SAHTE = {
      "@react-native-community/datetimepicker": "datetimepicker_sahte.js",
      "expo-notifications": "notifications_sahte.js",
      "expo-device": "device_sahte.js",
    };
    if (SAHTE[moduleName]) {
      return { type: "sourceFile", filePath: path.join(KOK, "web_sahne", SAHTE[moduleName]) };
    }
    const r = asil
      ? asil(context, moduleName, platform)
      : context.resolveRequest(context, moduleName, platform);
    if (r && r.type === "sourceFile" && YONLENDIR[r.filePath]
        && !String(context.originModulePath || "").includes(path.sep + "web_sahne" + path.sep)) {
      return { type: "sourceFile", filePath: YONLENDIR[r.filePath] };
    }
    return r;
  };
}

module.exports = config;
