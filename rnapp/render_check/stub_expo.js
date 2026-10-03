// expo-* ve AsyncStorage taklidi
const React = require("react");
module.exports = new Proxy({
  expoConfig: { extra: {} },
  manifest: { extra: {} },
  StatusBar: () => null,
  // 4 Ekim 2026: bellek içi (globalThis.__ASYNC). Varsayılan boş — eski testler
  // aynı davranışı görür; yönlendirme testi "tanıtım görüldü" bayrağını kurabilir.
  default: {
    getItem: async (k) => { const s = globalThis.__ASYNC || {}; return k in s ? s[k] : null; },
    setItem: async (k, v) => { (globalThis.__ASYNC = globalThis.__ASYNC || {})[k] = String(v); },
    removeItem: async (k) => { if (globalThis.__ASYNC) delete globalThis.__ASYNC[k]; },
  },
  getItem: async (k) => { const s = globalThis.__ASYNC || {}; return k in s ? s[k] : null; },
  setItem: async (k, v) => { (globalThis.__ASYNC = globalThis.__ASYNC || {})[k] = String(v); },
  removeItem: async (k) => { if (globalThis.__ASYNC) delete globalThis.__ASYNC[k]; },
  useFonts: () => [true],
  // 🔴 v3.4 — `expo-font` TAKLİDİ SADECE `useFonts` BİLİYORDU.
  // İkon katmanı (`@expo/vector-icons` → `createIconSet`) `Font.isLoaded`,
  // `Font.loadAsync` ve `processFontFamily` çağırıyor; Proxy'nin
  // "bilinmeyen anahtar → () => null" kuralı `isLoaded`ı da null döndüren
  // bir fonksiyona çeviriyordu ve kütüphane onu bir FONKSİYON değil DEĞER
  // sanıp çöküyordu.
  //
  // 🆕 SINIF: "HER ŞEYE `null` DÖNDÜREN BİR TAKLİT, EKSİK OLDUĞUNU
  // SÖYLEMEZ — SESSİZCE YANLIŞ CEVAP VERİR."
  //
  // `isLoaded: true`: font build'e gömülü (app.json · expo-font eklentisi),
  // yani gerçekte de ilk kareden itibaren yüklü. Taklit gerçeği izliyor.
  isLoaded: () => true,
  isLoading: () => false,
  loadAsync: async () => {},
  unloadAsync: async () => {},
  processFontFamily: (f) => f,
  getLoadedFonts: () => [],
  isAvailableAsync: async () => false,
  maybeCompleteAuthSession: () => {},
  openAuthSessionAsync: async () => ({ type: "cancel" }),
  createURL: (p) => "loungelink://" + p,
  // v1.84: derin baglanti taklidi GERCEGI taklit etmeli (v1.80 dersi:
  // taklit gercekten daha yetenekli olursa hata testten kacar).
  // Senaryo verisi: globalThis.__INITIAL_URL
  getInitialURL: async () => (globalThis.__INITIAL_URL || null),
  addEventListener: () => ({ remove: () => {} }),
  randomUUID: () => "test-uuid",
  digestStringAsync: async () => "hash",
  CryptoDigestAlgorithm: { SHA256: "SHA256" },
  AppleAuthenticationScope: { FULL_NAME: 1, EMAIL: 2 },
  signInAsync: async () => ({}),
  requestPermissionsAsync: async () => ({ granted: false }),
  launchImageLibraryAsync: async () => ({ canceled: true }),
  setNotificationHandler: () => {},
}, { get: (o, k) => (k in o ? o[k] : (() => null)) });
