#!/usr/bin/env node
/**
 * render_check/audit_metin.js — METİN DENETİMİ (yalnız okur)
 *
 * DÖRT ÖLÇÜM:
 *  1) TÜRKÇE BÜYÜK HARF: ekranda `.toUpperCase()` ile büyütülen etiketler.
 *     JavaScript'in `toUpperCase()`i Türkçe bilmez: "i" → "I" yapar, "İ"
 *     yapmaz. "Hangi kartını" → "HANGİ KARTINI" çıkar. Bu, MARKA
 *     KALİTESİ meselesi: kullanıcı yanlış yazılmış Türkçe görür.
 *  2) TR SÖZLÜĞÜNDE İNGİLİZCE: `D.tr` içindeki değer, `D.en` içindeki
 *     değerle AYNI mı? Aynıysa ya çevrilmemiş ya da (kod/simge gibi)
 *     çevrilmesi gerekmiyor. Ayrıca TR değerinde Türkçe'de olmayan
 *     İngilizce kalıp var mı diye bakılır.
 *  3) TR SÖZLÜĞÜNDE OLUP EN'DE OLMAYAN (ve tersi) anahtarlar: dil
 *     değiştirince `undefined` basılan yerler.
 *  4) KOD İÇİNE GÖMÜLÜ KULLANICI METNİ: JSX <Text> içinde doğrudan
 *     yazılmış Türkçe/İngilizce dize — dil değişse de değişmez.
 */
const fs = require("fs");
const path = require("path");
const parser = require("@babel/parser");
const { D } = require("./harness");   // harness stub'ları kurar; i18n.js böyle yüklenebiliyor

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const tr = D.tr, en = D.en;
let sorun = 0;

// ---------------------------------------------------------------
// 1) TÜRKÇE BÜYÜK HARF
// ---------------------------------------------------------------
console.log("=".repeat(72));
console.log("1) TÜRKÇE BÜYÜK HARF — .toUpperCase() Türkçe 'i'yi bozuyor mu?");
console.log("=".repeat(72));

// Ekranda .toUpperCase() ile büyütülen i18n anahtarlarını KAYNAKTAN çıkar.
const src = {};
for (const f of ["App.js", ...fs.readdirSync(path.join(APP, "src")).filter(x => x.endsWith(".js")).map(x => "src/" + x)])
  src[f] = fs.readFileSync(path.join(APP, f), "utf8");

const upKeys = new Set();
const upSites = [];
for (const [f, code] of Object.entries(src)) {
  code.split("\n").forEach((ln, i) => {
    if (!ln.includes("toUpperCase()")) return;
    // charAt(0).toUpperCase() = baş harf rozeti, Türkçe sorunu yok ("?"/isim)
    if (/charAt\(\s*0\s*\)\s*\.toUpperCase/.test(ln)) return;
    // onChangeText/x.toUpperCase = kullanıcı girdisi (uçuş kodu), latin
    if (/onChangeText|startsWith|flight|Flight/.test(ln)) return;
    upSites.push({ f, line: i + 1, text: ln.trim().slice(0, 110) });
    for (const m of ln.matchAll(/\bt\.([A-Za-z0-9_]+)/g)) upKeys.add(m[1]);
  });
}
console.log(`Görüntü metnini büyüten satır: ${upSites.length} · içinde geçen i18n anahtarı: ${upKeys.size}`);

const upBad = [];
for (const k of [...upKeys].sort()) {
  const v = tr[k];
  if (typeof v !== "string") continue;
  const js = v.toUpperCase(), trU = v.toLocaleUpperCase("tr-TR");
  if (js !== trU) upBad.push({ k, v, js, trU });
}
if (!upBad.length) console.log("✓ Büyütülen i18n etiketlerinde Türkçe kaybı yok.");
else {
  sorun += upBad.length;
  console.log(`\n🔴 ${upBad.length} etiket YANLIŞ büyüyor:`);
  upBad.forEach(b => console.log(`  t.${b.k}\n      "${b.v}"\n      ekranda : "${b.js}"\n      olmalı  : "${b.trU}"`));
}
console.log("\nBüyütme yapan satırlar:");
upSites.forEach(s => console.log(`  ${s.f}:${s.line}  ${s.text}`));

// Aynı hata sözlüğün TAMAMINDA olsa nasıl görünürdü (risk büyüklüğü)
const trAll = Object.entries(tr).filter(([, v]) => typeof v === "string");
const riskli = trAll.filter(([, v]) => v.toUpperCase() !== v.toLocaleUpperCase("tr-TR"));
console.log(`\nÖlçek: TR sözlüğündeki ${trAll.length} metnin ${riskli.length} tanesi ` +
            `.toUpperCase() ile bozulur (bugün yalnız yukarıdakiler ekranda büyütülüyor).`);

// ---------------------------------------------------------------
// 2) + 3) SÖZLÜK BÜTÜNLÜĞÜ
// ---------------------------------------------------------------
console.log("\n" + "=".repeat(72));
console.log("2) SÖZLÜK — TR/EN eksik anahtar ve çevrilmemiş metin");
console.log("=".repeat(72));
const trK = new Set(Object.keys(tr)), enK = new Set(Object.keys(en));
const trOnly = [...trK].filter(k => !enK.has(k));
const enOnly = [...enK].filter(k => !trK.has(k));
console.log(`TR anahtar: ${trK.size} · EN anahtar: ${enK.size}`);
if (trOnly.length) { sorun += trOnly.length; console.log(`🔴 EN'de OLMAYAN ${trOnly.length}: ${trOnly.slice(0, 30).join(", ")}`); }
else console.log("✓ TR'deki her anahtar EN'de de var.");
if (enOnly.length) { sorun += enOnly.length; console.log(`🔴 TR'de OLMAYAN ${enOnly.length}: ${enOnly.slice(0, 30).join(", ")}`); }
else console.log("✓ EN'deki her anahtar TR'de de var.");

// TR değeri EN değeriyle birebir aynı olanlar
const ayni = [];
for (const k of trK) {
  if (!enK.has(k)) continue;
  const a = tr[k], b = en[k];
  if (typeof a !== "string" || typeof b !== "string") continue;
  if (a !== b) continue;
  // Simge/kod/sayı/marka: çeviri beklenmiyor
  if (a.length < 3) continue;
  if (!/[A-Za-zçğıöşüÇĞİÖŞÜ]/.test(a)) continue;
  ayni.push({ k, v: a });
}
console.log(`\nTR = EN olan ${ayni.length} anahtar (marka/kısaltma olanlar normal):`);
ayni.slice(0, 60).forEach(x => console.log(`  ${x.k.padEnd(26)} "${x.v.slice(0, 60)}"`));
if (ayni.length > 60) console.log(`  … ve ${ayni.length - 60} tane daha`);

// ---------------------------------------------------------------
// 4) KOD İÇİNE GÖMÜLÜ KULLANICI METNİ
// ---------------------------------------------------------------
console.log("\n" + "=".repeat(72));
console.log("4) SÖZLÜK DIŞI METİN — JSX içinde doğrudan yazılmış kullanıcı metni");
console.log("=".repeat(72));
console.log("(dil değiştirilse bile bu metinler DEĞİŞMEZ)");

const gomulu = [];

// 🔴 ÖNEMLİ AYRIM — İLK ÖLÇÜM YANILTICIYDI.
// `{t.crashTitle || "Bir şeyler ters gitti"}` bir SÖZLÜK DIŞI METİN
// DEĞİLDİR: anahtar sözlükte var (TR ve EN'de), dize yalnız yedek.
// İlk koşuda ErrorBoundary ve LoadFail "ihlal" olarak çıktı; oysa
// ikisi de doğru yazılmış. Yedek olanları AYIRIYORUM — ayırmadan
// verilen sayı, gerçek sorunu 48'in içinde gizler.
// Yedek sayılma koşulu: dize bir `||` / `??` ifadesinin SAĞ tarafında
// ve SOL tarafında bir `t.<anahtar>` (ya da `s.<anahtar>`) var.
const yedekIsaret = new WeakSet();
function isaretle(ast) {
  (function walk(n, parent) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { n.forEach(x => walk(x, parent)); return; }
    if (!n.type) return;
    if (n.type === "LogicalExpression" && (n.operator === "||" || n.operator === "??")) {
      const sol = JSON.stringify(n.left).match(/"name":"(t|s|D)"/) ||
                  /MemberExpression/.test(n.left.type);
      if (sol) {
        (function mark(x) {
          if (!x || typeof x !== "object") return;
          if (Array.isArray(x)) { x.forEach(mark); return; }
          if (x.type === "StringLiteral") yedekIsaret.add(x);
          if (x.type === "LogicalExpression" || x.type === "ConditionalExpression")
            for (const k of ["left","right","test","consequent","alternate"]) mark(x[k]);
        })(n.right);
      }
    }
    for (const k of Object.keys(n)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(n[k], n);
    }
  })(ast, null);
}
function yedekMi(n) { return yedekIsaret.has(n); }
for (const [f, code] of Object.entries(src)) {
  if (f === "src/i18n.js" || f === "src/legal.js") continue;   // sözlüğün kendisi
  let ast;
  try { ast = parser.parse(code, { sourceType: "module", plugins: ["jsx"] }); }
  catch (e) { console.log(`PARSE HATASI ${f}: ${e.message}`); continue; }
  isaretle(ast);
  (function walk(n, inText) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { n.forEach(x => walk(x, inText)); return; }
    if (!n.type) return;
    let now = inText;
    if (n.type === "JSXElement") {
      const nm = n.openingElement.name.name;
      now = (nm === "Text" || nm === "Head") ? true : inText;
    }
    if (now && n.type === "JSXText") {
      const s = n.value.trim();
      if (s.length >= 3 && /[A-Za-zçğıöşüÇĞİÖŞÜ]{3}/.test(s))
        gomulu.push({ f, line: n.loc.start.line, s: s.slice(0, 70), yedek: false });
    }
    if (now && n.type === "StringLiteral" && n.loc) {
      const s = n.value.trim();
      // yalnız JSX ifade kabında (yani ekrana basılan) olanlar
      if (s.length >= 4 && /\s/.test(s) && /[A-Za-zçğıöşüÇĞİÖŞÜ]{3}/.test(s) &&
          !/^https?:|^[a-z_]+$|^\d/.test(s))
        gomulu.push({ f, line: n.loc.start.line, s: s.slice(0, 70), yedek: yedekMi(n) });
    }
    for (const k of Object.keys(n)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(n[k], now);
    }
  })(ast, false);
}
// Aynı satır birden çok kez sayılmasın
const seen = new Set();
const uniq = gomulu.filter(g => { const k = g.f + ":" + g.line + g.s; if (seen.has(k)) return false; seen.add(k); return true; });
const yedekler = uniq.filter(g => g.yedek);
const gercek   = uniq.filter(g => !g.yedek);
console.log(`Bulunan toplam: ${uniq.length}`);
console.log(`  ~ ${yedekler.length} tanesi \`t.anahtar || "yedek"\` kalıbı — SORUN DEĞİL (anahtar sözlükte var)`);
console.log(`  🔴 ${gercek.length} tanesi GERÇEK sabit metin — dil değişse de Türkçe kalır\n`);
const byFile = {};
gercek.forEach(g => (byFile[g.f] = byFile[g.f] || []).push(g));
for (const f of Object.keys(byFile).sort()) {
  console.log(`\n  ${f} (${byFile[f].length}):`);
  byFile[f].slice(0, 40).forEach(g => console.log(`    ${f}:${g.line}  "${g.s}"`));
  if (byFile[f].length > 40) console.log(`    … ve ${byFile[f].length - 40} tane daha`);
}

console.log("\n" + "-".repeat(72));
console.log(`Kesin ihlal (büyük harf + eksik anahtar): ${sorun}`);
console.log("Diğer iki bölüm KARAR GEREKTİRİR: her gömülü metin hata değildir,");
console.log("ama dil değiştiren kullanıcı onları Türkçe görmeye devam eder.");
