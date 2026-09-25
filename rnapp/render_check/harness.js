// ============================================================
// render_check/harness.js — YAPILANDIRILABİLİR MOUNT KOŞUCUSU
//
// NEDEN VAR: mount_test.js ekranları SABİT (çoğunlukla boş) veriyle
// mount ediyor. Bu, "ekran açılıyor mu"yu kanıtlar ama "şu veriyle şu
// kutu çıkıyor mu"yu kanıtlayamaz. SQL 216 kutusu tam olarak öyle bir
// şey: ancak `hangi_kartimi_kullanayim` bir nesne döndürünce çiziliyor
// ve iki AYRI hali var (öneri var / öneri yok).
//
// Bu dosya aynı stub katmanını kurar ama her senaryo için RPC ve tablo
// yanıtlarını AYRI AYRI verdirir. Hiçbir kaynak dosyaya dokunmaz.
// ============================================================
const path = require("path");
const Module = require("module");
const React = require("react");

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi

const babelRegister = require("@babel/register").default || require("@babel/register");
babelRegister({
  presets: [
    require.resolve("babel-preset-expo"),
    [require.resolve("@babel/preset-env"), { targets: { node: "current" }, modules: "commonjs" }],
  ],
  extensions: [".js", ".jsx"],
  // 🔴 v2.84 — BU SATIR WINDOWS'TA ASLA ESLESMIYORDU.
  // Eski hali: only: [/rnapp\/(src|App\.js)/]
  // Regex `rnapp/` diye DUZ EGIK CIZGI istiyor. Windows'ta Node yollari
  // `C:\rnapp\src\i18n.js` seklinde, yani TERS egik cizgiyle verir →
  // eslesme olmaz → Babel dosyayi hic donusturmez → Node onu ESM sanip
  // "Cannot find module .../src/supabase" ile patlar. Gokberk'in
  // ekraninda 19 Agustos'ta gorulen hata tam olarak buydu.
  // Artik yol REGEX degil, ll_paths'ten gelen GERCEK klasor.
  only: [APP],
  cache: false,
});

// ---- AsyncStorage: gerçek davranışa yakın bellek içi sürüm ----
const memStore = {};
const AsyncStorageStub = {
  default: {
    getItem: async (k) => (k in memStore ? memStore[k] : null),
    setItem: async (k, v) => { memStore[k] = String(v); },
    removeItem: async (k) => { delete memStore[k]; },
    multiRemove: async () => {},
  },
};

const STUBS = {
  "expo-constants": { default: { expoConfig: { extra: {} } } },
  "expo-font": { useFonts: () => [true, null], loadAsync: async () => {} },
  "expo-notifications": {
    getPermissionsAsync: async () => ({ status: "granted" }),
    requestPermissionsAsync: async () => ({ status: "granted" }),
    getExpoPushTokenAsync: async () => ({ data: "ExponentPushToken[test]" }),
    setNotificationHandler: () => {},
    addNotificationResponseReceivedListener: () => ({ remove() {} }),
    AndroidImportance: { HIGH: 4 },
    setNotificationChannelAsync: async () => {},
  },
  // v2.98 — `src/push.js` `expo-device` de kullaniyor. Taklidi EKLENMEDIGI
  // icin harness gercek TS kaynagini yuklemeye calisti ve DUSTU. Bir tasiyici
  // (harness), uygulamanin GERCEK bagimlilik listesini yansitmadigi anda
  // olcmeyi birakip yalniz kendi dunyasini olcer.
  "expo-device": { isDevice: true, brand: "test", modelName: "test" },
  "expo-linking": { createURL: () => "loungelink://", addEventListener: () => ({ remove() {} }), getInitialURL: async () => null },
  "expo-image-picker": { launchImageLibraryAsync: async () => ({ canceled: true }) },
  "expo-clipboard": { setStringAsync: async () => {} },
  "expo-status-bar": { StatusBar: () => null },
  "expo-web-browser": { openAuthSessionAsync: async () => ({ type: "cancel" }), maybeCompleteAuthSession: () => {} },
  "expo-apple-authentication": { isAvailableAsync: async () => false, signInAsync: async () => ({}) },
  "expo-crypto": { digestStringAsync: async () => "hash", randomUUID: () => "00000000-0000-4000-8000-000000000000" },
  "expo-device": { isDevice: true, modelName: "test" },
  "@react-native-async-storage/async-storage": AsyncStorageStub,
  "@react-native-community/datetimepicker": { default: () => null },
};

const h = (tag) => {
  const C = ({ children }) => React.createElement(tag, null, children ?? null);
  C.displayName = tag;
  return C;
};
STUBS["react-native"] = new Proxy({}, {
  get(_, k) {
    if (k === "StyleSheet") return { create: (o) => o, flatten: (o) => o, hairlineWidth: 1, absoluteFill: {} };
    if (k === "Platform") return { OS: "android", select: (o) => o.android ?? o.default };
    if (k === "Dimensions") return { get: () => ({ width: 390, height: 844 }) };
    if (k === "Alert") return { alert: () => {} };
    if (k === "Keyboard") return { dismiss: () => {}, addListener: () => ({ remove() {} }) };
    if (k === "BackHandler") return { addEventListener: () => ({ remove() {} }) };
    if (k === "Linking") return { openURL: async () => {}, addEventListener: () => ({ remove() {} }), getInitialURL: async () => null };
    if (k === "Animated") return { View: h("View"), Text: h("Text"), timing: () => ({ start: (cb) => cb && cb() }), Value: function () { this.setValue = () => {}; } };
    if (k === "Appearance") return { getColorScheme: () => "light", addChangeListener: () => ({ remove() {} }) };
    // 🔴 BU SATIR BİR ÖLÇÜMLE EKLENDİ, TAHMİNLE DEĞİL.
    // İlk koşuda App.js mount edilirken ErrorBoundary devreye girdi ve
    // logError("crash") şunu yazdı:
    //     "_reactNative.AppState.addEventListener is not a function"
    // Sebep UYGULAMA DEĞİL, BU DOSYAYDI: Proxy `AppState`i de bir React
    // bileşenine çeviriyordu (App.js:240 onu bir modül gibi kullanıyor).
    // Testin sahtesi, taklit ettiği şeyin sözleşmesine uymazsa test
    // yalan söyler — burada "uygulama çöküyor" diye yalan söyleyecekti.
    if (k === "AppState") return { currentState: "active", addEventListener: () => ({ remove() {} }) };
    if (k === "PixelRatio") return { get: () => 2, getFontScale: () => 1, roundToNearestPixel: (x) => x };
    if (k === "InteractionManager") return { runAfterInteractions: (f) => { f && f(); return { cancel() {} }; } };
    if (k === "I18nManager") return { isRTL: false };
    if (k === "Share") return { share: async () => ({ action: "dismissedAction" }) };
    if (k === "Vibration") return { vibrate: () => {} };
    if (k === "NativeModules") return {};
    if (k === "__esModule") return true;
    if (k === "default") return undefined;
    return h(String(k));
  },
});

const origResolve = Module._resolveFilename;
Module._resolveFilename = function (req, ...rest) {
  if (STUBS[req]) return "STUB:" + req;
  return origResolve.call(this, req, ...rest);
};
const origLoad = Module._load;
Module._load = function (req, ...rest) {
  if (STUBS[req]) return STUBS[req];
  return origLoad.call(this, req, ...rest);
};

// ============================================================
// SUPABASE TAKLİDİ — senaryo başına yapılandırılır
//
// globalThis.__CFG = {
//   rpc:    { fn: value | { __error: "mesaj" } | (args) => value },
//   tables: { tablo: [satır,...] | { __error: "mesaj" } },
// }
// Ayrıca her çağrı globalThis.__CALLS içine kaydedilir: testin
// "gerçekten çağrıldı mı"yı da ölçebilmesi için.
// ============================================================
globalThis.__CFG = { rpc: {}, tables: {} };
globalThis.__CALLS = [];

function cfgTable(name) {
  const c = globalThis.__CFG.tables || {};
  return name in c ? c[name] : [];
}

function tableResult(name) {
  const v = cfgTable(name);
  if (v && v.__error) return { data: null, error: { message: v.__error, code: v.__code || "42501" }, count: null };
  return { data: v, error: null, count: Array.isArray(v) ? v.length : null };
}

function makeQuery(table) {
  globalThis.__CALLS.push({ kind: "from", table });
  const q = {};
  ["select", "eq", "neq", "in", "gte", "lte", "gt", "lt", "or", "is", "order", "limit",
   "range", "not", "filter", "contains", "ilike", "like", "update", "insert", "upsert",
   "delete", "match", "single_"].forEach(m => { q[m] = () => q; });
  q.maybeSingle = async () => {
    const r = tableResult(table);
    return { data: r.error ? null : (Array.isArray(r.data) ? (r.data[0] ?? null) : r.data), error: r.error };
  };
  q.single = q.maybeSingle;
  q.then = (res, rej) => Promise.resolve(tableResult(table)).then(res, rej);
  return q;
}

// 🔴 GERÇEK supabase-js `rpc()` bir PostgrestFilterBuilder döndürür:
// `then` VARDIR, `catch`/`finally` YOKTUR. Stub aynı sınırı taşır ki
// `.rpc(...).catch(...)` yazan kod testte de patlasın (v1.79 dersi).
function makeRpc(fn, args) {
  globalThis.__CALLS.push({ kind: "rpc", fn, args });
  const c = globalThis.__CFG.rpc || {};
  let v = (fn in c) ? c[fn] : undefined;
  if (typeof v === "function") v = v(args);
  const result = (v === undefined) ? { data: null, error: null }
    : (v && v.__error) ? { data: null, error: { message: v.__error, code: v.__code || "42501" } }
    : { data: v, error: null };
  return {
    then: (res, rej) => Promise.resolve(result).then(res, rej),
    select: function () { return this; },
    single: async () => result,
    maybeSingle: async () => result,
  };
}

require.cache[require.resolve("../src/supabase.js")] = {
  id: "supabase", filename: "supabase", loaded: true,
  exports: {
    supabase: {
      from: makeQuery,
      rpc: makeRpc,
      storage: { from: () => ({ upload: async () => ({ error: null }), getPublicUrl: () => ({ data: { publicUrl: "x" } }) }) },
      auth: {
        getSession: async () => ({ data: { session: globalThis.__SESSION || null } }),
        getUser: async () => ({ data: { user: (globalThis.__SESSION || {}).user || null } }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
        signOut: async () => ({}),
      },
      channel: () => ({ on: function () { return this; }, subscribe: function () { return this; } }),
      removeChannel: () => {},
    },
    logError: (...a) => { globalThis.__CALLS.push({ kind: "logError", a }); },
    setAppVersion: () => {},
    SUPABASE_URL: "https://test.supabase.co",
  },
};

const renderer = require("react-test-renderer");
const { D } = require("../src/i18n");
const S = require("../src/screens");

async function settle(n = 12) {
  await renderer.act(async () => {
    for (let k = 0; k < n; k++) await Promise.resolve();
    await new Promise(r => setTimeout(r, 0));
  });
}

function collect(node, out = []) {
  if (node == null) return out;
  if (typeof node === "string" || typeof node === "number") { out.push(String(node)); return out; }
  if (Array.isArray(node)) { node.forEach(n => collect(n, out)); return out; }
  if (node.children) collect(node.children, out);
  return out;
}

async function mount(Comp, props) {
  let tree;
  await renderer.act(async () => {
    tree = renderer.create(React.createElement(Comp, props));
    for (let k = 0; k < 8; k++) await Promise.resolve();
    await new Promise(r => setTimeout(r, 0));
  });
  await settle();
  return {
    tree,
    texts: () => collect(tree.toJSON()).map(s => s.trim()).filter(Boolean),
    unmount: async () => { await renderer.act(async () => tree.unmount()); },
  };
}

function setCfg(cfg) {
  globalThis.__CFG = { rpc: cfg.rpc || {}, tables: cfg.tables || {} };
  globalThis.__CALLS = [];
}

module.exports = { React, renderer, S, D, mount, settle, collect, setCfg, memStore, APP, path };
