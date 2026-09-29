// ============================================================
// LoungeLink · EKRAN RENDER KOŞUCUSU
//
// NE YAPAR: her ekranı GERÇEKTEN mount eder (react-test-renderer), veri
// çekmesini bekler, render ağacındaki tüm metinleri toplar ve senaryo başına
// "beklenen metin var mı / çöktü mü" raporu üretir.
//
// NE YAPMAZ: piksel/görsel doğrulama yapmaz (cihaz yok). Yani "buton yerinde
// mi, rengi doğru mu" sorusunu YANITLAMAZ; "ekran açılıyor mu, doğru durumda
// doğru metin/aksiyon çıkıyor mu" sorusunu yanıtlar.
// ============================================================
const path = require("path");
const Module = require("module");
const React = require("react");

const RN_STUB = path.join(__dirname, "stub_rn.js");
const SB_STUB = path.join(__dirname, "stub_supabase.js");
const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi

// --- modül yönlendirme: react-native ve expo-* taklitlere gitsin ---
const REACT_MAIN   = require.resolve("react");
const REACT_JSX    = require.resolve("react/jsx-runtime");
const REACT_JSXDEV = require.resolve("react/jsx-dev-runtime");
const origResolve = Module._resolveFilename;
// 🔴 `__DEV__` METRO'NUN TANIMLADIĞI BİR GLOBAL. Node'da yok ve
// `@expo/vector-icons` onu okuyor — testler "ReferenceError: __DEV__ is
// not defined" ile çöküyordu. Bu bir ürün hatası DEĞİL, taklidin eksiği.
// `false` seçildi: üretim davranışını test ediyoruz, geliştirme uyarılarını
// değil.
if (typeof global.__DEV__ === "undefined") global.__DEV__ = false;

Module._resolveFilename = function (request, parent, ...rest) {
  // TEK REACT KOPYASI ŞART (aksi halde "Invalid hook call")
  if (request === "react") return REACT_MAIN;
  if (request === "react/jsx-runtime") return REACT_JSX;
  if (request === "react/jsx-dev-runtime") return REACT_JSXDEV;
  if (request === "react-native") return RN_STUB;
  // 🔴 v3.4 — ikon kütüphanesi taklidi; gerekçe mount_test.js'te.
  if (request.startsWith("@expo/vector-icons")) return path.join(__dirname, "stub_ikon.js");
  if (request.startsWith("expo-") || request === "expo-status-bar" || request === "expo") return path.join(__dirname, "stub_expo.js");
  if (request === "@react-native-async-storage/async-storage") return path.join(__dirname, "stub_expo.js");
  // v1.84: varlik (png/ttf) require'lari Node'da patlar -> sayisal taklit
  if (/\.(png|jpe?g|gif|webp|svg|ttf|otf)$/i.test(request)) return path.join(__dirname, "stub_asset.js");
  if (request === "@react-native-community/datetimepicker") return path.join(__dirname, "stub_datetimepicker.js");
  if (parent && /rnapp/.test(parent.filename || "") && /(^|\/)supabase$/.test(request.replace(/\.js$/, "")))
    return SB_STUB;
  if (request.endsWith("/supabase") || request === "./supabase") return SB_STUB;
  return origResolve.call(this, request, parent, ...rest);
};

(require("@babel/register").default || require("@babel/register"))({
  presets: [["@babel/preset-env", { targets: { node: "current" } }], ["@babel/preset-react", { runtime: "automatic" }]],
  extensions: [".js", ".jsx"],
  only: [APP, __dirname],
  cache: false,
});

const TestRenderer = require("react-test-renderer");
const { D, fmtLongDate } = require(path.join(APP, "src/i18n.js"));
const S = require(path.join(APP, "src/screens.js"));

const t = D.tr;
const UID = "11111111-1111-4111-8111-111111111111";
const OTHER = "22222222-2222-4222-8222-222222222222";
const session = { user: { id: UID, email: "host@test.local" } };

function collectText(node, out = []) {
  if (node == null) return out;
  if (typeof node === "string" || typeof node === "number") { out.push(String(node)); return out; }
  if (Array.isArray(node)) { node.forEach(n => collectText(n, out)); return out; }
  if (node.children) collectText(node.children, out);
  return out;
}

async function renderScreen(name, element) {
  let tree = null, err = null;
  try {
    await TestRenderer.act(async () => { tree = TestRenderer.create(element); });
    // veri çekimi (setState) için birkaç mikro-tur
    for (let i = 0; i < 6; i++) await TestRenderer.act(async () => { await Promise.resolve(); });
  } catch (e) { err = e; }
  if (err) return { name, ok: false, err: String(err.message || err).split("\n")[0], texts: [] };
  const json = tree.toJSON();
  const texts = collectText(json).map(s => s.trim()).filter(Boolean);
  return { name, ok: true, texts, tree };
}

// 29 Eylül · v6.3 — durum satırları artık büyük harf (kaş stili). Kontrol ANLAMI
// ölçer, harf biçimini değil: Türkçe büyük harfe çevirip karşılaştırır. Olumsuz
// kontroller ("X YAZMIYOR") bu yüzden daha sıkı: büyük yazılsa da yakalanır.
function has(texts, needle) {
  const n = String(needle).toLocaleUpperCase("tr");
  return texts.some(x => String(x).toLocaleUpperCase("tr").includes(n));
}

module.exports = { renderScreen, has, t, S, session, UID, OTHER, React, TestRenderer, APP, path, fmtLongDate };
