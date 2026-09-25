// ============================================================
// LoungeLink · render_check/ll_paths.js
//
// 🔴 NEDEN VAR — AYNI HATANIN JS TARAFI, BİR YIL SONRA.
//
// `ll_paths.py` v1.94'te tam olarak bu sorunu Python denetimleri için
// çözmüştü: yollar `/home/claude/rnapp` diye SABİT yazılıydı ve
// Gokberk'in makinesinde (C:\rnapp) hiçbiri mevcut değildi.
//
// Ama düzeltme YALNIZ PYTHON TARAFINA yapıldı. JS tarafındaki on dosya
// (`runner.js`, `harness.js`, beş `audit_*.js`, `app_boot_test.js`,
// `deeplink_test.js`) sabit yolu taşımaya devam etti. Sonuç, 19
// Ağustos'ta Gokberk'in ekranında görüldü:
//
//     Error: Cannot find module '\home\claude\rnapp\src\i18n.js'
//
// Yani `npm run render` onun makinesinde HİÇ ÇALIŞMAMIŞ. Ben her
// teslimde "render → 0 · 16 ekran" yazdım; o sayı BENİM kabımdan
// geliyordu, onun makinesinden değil.
//
// 🆕 SINIF: **"BİR DERSİN BİR DİLDE ÖĞRENİLMESİ, DİĞERİNDE
// ÖĞRENİLDİĞİ ANLAMINA GELMEZ."** Aynı kusurun ikinci kopyası,
// düzeltilen kopyanın gölgesinde görünmez olur.
//
// Çözüm ll_paths.py ile aynı: yol, betiğin KENDİ konumundan türetilir.
// render_check/ her zaman rnapp/ içindedir; bir üst klasör app kökü.
// Ortam değişkeniyle ezilebilir: LL_APP_DIR.
// ============================================================
const path = require("path");
const fs = require("fs");

const APP = process.env.LL_APP_DIR || path.resolve(__dirname, "..");

// 🔴 GÜRÜLTÜLÜ ÖL: yol yanlışsa "0 ekran, temiz" demek yerine dur.
// ll_paths.py'nin en önemli kuralı buydu ve JS tarafında da geçerli:
// bir şey denetleyemeyen denetim asla yeşil yanmamalı.
if (!fs.existsSync(path.join(APP, "App.js"))) {
  console.error(
    `🔴 render_check: app kökü bulunamadı → ${APP}\n` +
    `   Beklenen: ${path.join(APP, "App.js")}\n` +
    `   render_check/ klasörü rnapp/ içinde olmalı. Farklı bir yerdeyse:\n` +
    `   PowerShell:  $env:LL_APP_DIR = "C:\\rnapp"`
  );
  process.exit(1);
}

const PARENT = path.dirname(APP);

function bo() {
  for (const c of [
    process.env.LL_BO_DIR,
    path.join(PARENT, "backoffice"),
    path.join(PARENT, "loungelink-backoffice"),
  ]) {
    if (c && fs.existsSync(c)) return c;
  }
  return null;
}

module.exports = { APP, PARENT, bo };
