// expo-* ve AsyncStorage taklidi
const React = require("react");
module.exports = new Proxy({
  expoConfig: { extra: {} },
  manifest: { extra: {} },
  StatusBar: () => null,
  default: { getItem: async () => null, setItem: async () => {}, removeItem: async () => {} },
  getItem: async () => null, setItem: async () => {}, removeItem: async () => {},
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
