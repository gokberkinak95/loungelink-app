#!/usr/bin/env node
// ============================================================
// LoungeLink · pyrun.js — Python yorumlayıcısını BULUR, varsaymaz.
//
// 🔴 NEDEN VAR (19 Ağustos 2026, Gokberk'in ekranı):
//
//     > npm run verify
//     Python was not found; run without arguments to install from the
//     Microsoft Store, or disable this shortcut from Settings > Apps >
//     Advanced app settings > App execution aliases.
//
// `package.json` on bir denetimi `python ...` ile, birini `python3 ...`
// ile çağırıyordu. İkisi de BENİM Linux kabımda çalışıyor. Windows'ta:
//   · `python`  → kurulu değilse Microsoft Store kısayoluna düşer
//   · `python3` → aynı kısayol
//   · `py`      → resmî Python Launcher (python.org kurulumuyla gelir)
// Yani `npm run verify` onun makinesinde HİÇ çalışmamış olabilir ve ben
// her teslimde "verify → çıkış 0, 7 sn" yazdım. O sayı BENİM kabımdan
// geliyordu.
//
// 🆕 SINIF: **"KOMUT ADI BİR YORUMLAYICI DEĞİL, BİR TAHMİNDİR."**
// `ll_paths.py`'nin (yol) ve `ll_paths.js`'in (yol, JS tarafı) yaptığı
// şeyin üçüncüsü: çalıştırılabilir dosya da ortama göre değişir.
//
// Bu betik sırayla dener ve BULDUĞUNU SÖYLER. Hiçbiri yoksa, Store
// kısayolunun anlamsız mesajı yerine ne yapılacağını yazar.
// ============================================================
const { spawnSync } = require("child_process");

const ADAYLAR = [
  ["py", ["-3"]],      // Windows Python Launcher — python.org kurulumu
  ["python3", []],
  ["python", []],
];

function calisir(cmd, onEk) {
  // 🔴 "var mı" sorusu `--version` ile ölçülür, dosya arayarak değil:
  // Microsoft Store kısayolu GERÇEK bir dosyadır ama Python değildir;
  // `--version` çağrısında 9009 döner ya da hiçbir şey basmaz.
  const r = spawnSync(cmd, [...onEk, "--version"], { encoding: "utf8" });
  if (r.error || r.status !== 0) return null;
  const s = ((r.stdout || "") + (r.stderr || "")).trim();
  return /^Python 3\./.test(s) ? s : null;
}

let secilen = null;
let surum = null;
for (const [cmd, onEk] of ADAYLAR) {
  const v = calisir(cmd, onEk);
  if (v) { secilen = [cmd, onEk]; surum = v; break; }
}

if (!secilen) {
  console.error(
    "\n🔴 PYTHON BULUNAMADI — denetimler çalıştırılamıyor.\n" +
    "\n   Denenen: py -3 · python3 · python  (üçü de Python 3 döndürmedi)\n" +
    "\n   NE YAPMALI (bir kez, ~3 dakika):\n" +
    "     EN KOLAYI (Windows 10/11, tek satir):\n" +
    "        winget install Python.Python.3.12\n" +
    "     PATH'i kendisi ayarlar. Sonra PowerShell'i KAPAT, yeniden ac.\n" +
    "\n     winget yoksa elle:\n" +
    "     1) https://www.python.org/downloads/  adresinden Python 3 kur\n" +
    "     2) Kurulumun ilk ekranında **Add python.exe to PATH** kutusunu İŞARETLE\n" +
    "     3) PowerShell'i KAPAT, yeniden aç\n" +
    "     4) Doğrula:   py -3 --version\n" +
    "\n   Windows'ta `python` yazınca çıkan Microsoft Store ekranı bir\n" +
    "   Python kurulumu DEĞİLDİR; o bir kısayol. Settings > Apps >\n" +
    "   Advanced app settings > App execution aliases altından\n" +
    "   kapatabilirsin.\n" +
    "\n   🔴 BUILD ALMANI ENGELLEMEZ — bu satiri duzeltiyorum.\n" +
    "   Onceki surumde burada 'bu adim atlanamaz' yaziyordu ve bu YANLISTI:\n" +
    "   olctum, `npx expo export` Python'suz da cikis 0 veriyor. Yani APK/IPA\n" +
    "   alabilirsin. Python'un tuttugu yer YALNIZ denetimler:\n" +
    "     · npm run verify → 11 denetim\n" +
    "     · npm run e2e    → 5 uctan uca test (gercek PostgreSQL, 26 senaryo)\n" +
    "\n   SIMDILIK DEVAM ETMEK ICIN:  npm run verify:js   (Node denetimleri,\n" +
    "   her ortamda calisir). Magazaya gonderMEDEN once Python'u kurmani\n" +
    "   yine de oneririm — is mantigini olcen tek otomatik kapi o 26 senaryo.\n"
  );
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length === 0) {
  console.log(`pyrun: ${secilen[0]} ${secilen[1].join(" ")} → ${surum}`);
  process.exit(0);
}

const r = spawnSync(secilen[0], [...secilen[1], ...args], { stdio: "inherit" });
process.exit(r.status === null ? 1 : r.status);
