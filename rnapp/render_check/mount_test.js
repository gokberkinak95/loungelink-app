#!/usr/bin/env node
/**
 * LoungeLink · render_check/mount_test.js   (v2.44'te doğdu)
 *
 * ============================================================
 * 🔴 NEDEN VAR — "CİHAZDA HİÇ ÇALIŞMADI" BOŞLUĞUNU DARALTIR
 * ============================================================
 *
 * Bugüne kadarki render testlerim METİN EŞLEŞTİRME yapıyordu:
 * dosyada şu string var mı, şu anahtar tanımlı mı. Bu, sözdizimini
 * ve i18n bütünlüğünü doğrular ama bileşenin GERÇEKTEN render
 * olduğunu doğrulamaz.
 *
 * Aradaki fark önemli: `styleOpts.map(...)` satırı metin olarak
 * kusursuz görünür ama `styleOpts` undefined ise çalışma anında
 * çöker. 41 kontrolün hiçbiri bunu yakalayamazdı.
 *
 * Bu dosya bileşenleri react-test-renderer ile GERÇEKTEN MOUNT eder.
 * Emülatör değil, ama artık "hiç çalıştırılmadı" demiyoruz.
 *
 * YAKALADIĞI ŞEYLER:
 *   · undefined değişken / prop
 *   · null üzerinde .map / .length
 *   · eksik import
 *   · render sırasında atılan her istisna
 *
 * YAKALAYAMADIĞI — ve bunu ölçtüm, tahmin etmedim:
 *   · piksel, dokunma, animasyon, gerçek ağ (cihaz gerektirir)
 *   · DERİN async render yolları. Mutasyon testi yaptım: EditProfile
 *     içindeki `styleOpts.map` satırını bozdum ve test YAKALAMADI,
 *     çünkü o dal ancak veri yüklendikten sonraki 2-3. render'da
 *     çalışıyor ve sahte veriyle o noktaya ulaşmıyor.
 *
 * Yani bu test "ekran açılıyor mu"yu kanıtlar, "her dal çalışıyor mu"yu
 * kanıtlamaz. Kanıtladığından fazlasını iddia etmemek, testin kendisi
 * kadar önemli: yanlış güven, güvensizlikten kötüdür.
 *
 * Gerçek değeri şurada görüldü: ilk çalıştırmada Trips ve LoungeGuide
 * çöktü. Sebep testin kendi sahte `rpc`'siydi (Promise yerine düz nesne
 * dönüyordu) — ama o hata gerçek olsaydı, 41 metin kontrolünün hiçbiri
 * göremezdi.
 */
const path = require("path");
const React = require("react");
const Module = require("module");

// 🔴 KAYNAK DOSYALAR ESM + JSX. Node bunlari dogrudan okuyamaz;
// Babel'i devreye aliyoruz. babel-preset-expo zaten kurulu (Expo
// build'i onu kullaniyor) — yani testte DERLENEN kod, cihazda
// calisacak kodla ayni donusumden geciyor.
const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const babelRegister = require("@babel/register").default || require("@babel/register");
babelRegister({
  presets: [
    require.resolve("babel-preset-expo"),
    // 🔴 ESM -> CJS: babel-preset-expo modul bicimini KORUYOR cunku
    // Metro bundler'i onu kendisi hallediyor. Node'da calistirirken
    // donusumu biz istemeliyiz.
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

// ---- Native modülleri sahtele ----
// Bunlar cihazda çalışır, burada yok. Sahte olanlar render'ı bozmayacak
// kadar sade, ama "modül yok" hatası vermeyecek kadar dolu.
const STUBS = {
  "expo-constants": { default: { expoConfig: { extra: {} } } },
  // 🔴 v3.4 — İKON FONTU KÜTÜPHANESİ BURADA TAKLİT EDİLİYOR, VE BU
  // BİLİNÇLİ BİR SINIR. `@expo/vector-icons` bir FONT yükleyip glif
  // çiziyor; başsız Node'da ne font motoru var ne de tuval. Onu gerçek
  // haliyle koşturmak, RN'i gerçek haliyle koşturmaya çalışmakla aynı
  // hata olurdu (bu dosyanın başındaki gerekçe).
  //
  // KAYBETTİĞİMİZ: glifin çizilip çizilmediği.
  // KORUDUĞUMUZ: `src/ikon.js` bizim kodumuz ve TAM OLARAK koşuyor —
  // anlam haritası çözülüyor, tanımsız ad boş kutuya düşüyor, kutu
  // ölçüleri hesaplanıyor.
  //
  // Ve kaybettiğimiz parçanın AYRI bir nöbetçisi var: `ikon_check.py`
  // haritadaki her glifi Ionicons'un GERÇEK glyphmap'inde arıyor. Yani
  // "glif var mı" sorusu taklide değil, kaynağa soruluyor.
  //
  // 🆕 SINIF: "BİR ŞEYİ TAKLİT EDİYORSAN, TAKLİDİN GİZLEDİĞİ SORUYU
  // BAŞKA BİR YERDE SOR — YOKSA TAKLİT BİR KÖR NOKTAYA DÖNÜŞÜR."
  // 🔴 v3.4 — İKİNCİ BİR EKSİK TAKLİT, AYNI SEBEPLE.
  // `stub_expo.js`i düzelttim ama bu dosya KENDİ expo-font taklidini
  // taşıyor. İki taklit, biri düzeltildi, diğeri kaldı — ve test yine
  // "BİLEŞEN ÇÖKTÜ" dedi.
  //
  // 🆕 SINIF: "AYNI ŞEYİN İKİ TAKLİDİ VARSA, BİRİNİ DÜZELTMEK
  // DÜZELTMEK DEĞİLDİR — İKİNCİSİ SESSİZCE ESKİ CEVABI VERMEYE DEVAM EDER."
  "expo-font": {
    useFonts: () => [true, null],
    loadAsync: async () => {},
    isLoaded: () => true,
    isLoading: () => false,
    processFontFamily: (f) => f,
    getLoadedFonts: () => [],
  },
  "expo-notifications": {
    // 3 Eylül — cihaz izni senaryoya göre (`bekle.izin`); varsayılan verildi.
    getPermissionsAsync: async () => (globalThis.__IZIN || { status: "granted", canAskAgain: true }),
    requestPermissionsAsync: async () => (globalThis.__IZIN || { status: "granted", canAskAgain: true }),
    getExpoPushTokenAsync: async () => {
      if (globalThis.__JETON_HATA === "fcm") throw new Error("Default FirebaseApp is not initialized in this process");
      return { data: "ExponentPushToken[test]" };
    },
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
  // 🔴 12 EYLÜL · KAPSAM TURU — App.js'i mount edebilmek için üç taklit daha.
  // `App.js → src/social.js → expo-web-browser` zinciri node_modules'ten
  // TypeScript KAYNAK çekiyor ve Node onu derleyemiyor. `giris_kapisi_test.js`
  // bu üçünü yıllardır taklit ediyordu; mount testi etmiyordu, çünkü App.js'i
  // hiç require etmiyordu. Kapsamı büyütmek, taklit yüzeyini de büyütmek demek.
  "expo-web-browser": { openAuthSessionAsync: async () => ({ type: "cancel" }),
                        maybeCompleteAuthSession: () => {} },
  "expo-apple-authentication": {
    isAvailableAsync: async () => false,
    signInAsync: async () => ({ identityToken: "t", fullName: null }),
    AppleAuthenticationScope: { FULL_NAME: 0, EMAIL: 1 },
  },
  "expo-crypto": { digestStringAsync: async () => "hash",
                   CryptoDigestAlgorithm: { SHA256: "SHA-256" } },
  "expo-haptics": { impactAsync: async () => {},
                    ImpactFeedbackStyle: { Light: 0, Medium: 1, Heavy: 2 } },
  // 12 Eylül · gece — geçiş kartının jiroskobu. Taklit "sensör YOK"
  // diyor: ürünün sensörsüz yoluna da her koşuda basılsın.
  "expo-sensors": { DeviceMotion: { isAvailableAsync: async () => false,
                                    setUpdateInterval: () => {},
                                    addListener: () => ({ remove: () => {} }),
                                    removeAllListeners: () => {} } },
  "expo-clipboard": { setStringAsync: async () => {} },
  "expo-status-bar": { StatusBar: () => null },
  "@react-native-async-storage/async-storage": {
    default: { getItem: async () => null, setItem: async () => {}, removeItem: async () => {} },
  },
  "@react-native-community/datetimepicker": { default: () => null },
};

// 🔴 REACT NATIVE'IN KENDISINI DE SAHTELIYORUZ — ve bu bilincli bir sinir.
//
// RN, node_modules'a DERLENMEMIS Flow kaynagi olarak geliyor; Node onu
// okuyamiyor. Tam derlemek icin Metro bundler gerekir ve bu, testin
// maliyetini faydasindan buyutur.
//
// Sahteleme neyi KAYBETTIRIR: RN'in kendi render davranisi, yerlesim,
// piksel. Bunlari zaten iddia etmiyorduk.
// Neyi KAZANDIRIR: BIZIM kodumuz gercekten calisir — hook'lar kosar,
// degiskenler cozulur, undefined bir sey .map edilirse COKER.
// Test ettigimiz sey RN degil, KENDI MANTIGIMIZ. Asil riskimiz de orada.
const h = (tag) => {
  const C = ({ children }) => React.createElement(tag, null, children ?? null);
  C.displayName = tag;
  return C;
};
// (STUBS yukarıda kuruldu; ikon taklidi `h` tanımlandıktan SONRA
// eklenmeli — `h` bu satırların altında `const` ile tanımlı.)
STUBS["react-native"] = new Proxy({}, {
  get(_, k) {
    if (k === "StyleSheet") return { create: (o) => o, flatten: (o) => o, hairlineWidth: 1, absoluteFill: {} };
    if (k === "Platform") return { OS: "android", select: (o) => o.android ?? o.default };
    if (k === "Dimensions") return { get: () => ({ width: 390, height: 844 }) };
    if (k === "Alert") return { alert: () => {} };
    if (k === "Keyboard") return { dismiss: () => {}, addListener: () => ({ remove() {} }) };
    if (k === "BackHandler") return { addEventListener: () => ({ remove() {} }) };
    if (k === "Linking") return { openURL: async () => {}, addEventListener: () => ({ remove() {} }), getInitialURL: async () => null };
    // 🔴 v3.4 — `Animated` TAKLİDİ EKSİKTİ VE BU BİR ÜRÜN ÇÖKMESİ GİBİ
    // GÖRÜNDÜ. Marka yükleyicisi `Animated.loop`, `Animated.Image` ve
    // `Value.interpolate` kullanıyor; taklitte üçü de yoktu ve test
    // "BİLEŞEN ÇÖKTÜ" dedi. Kod doğruydu, TAKLİT eksikti.
    //
    // 🆕 SINIF: "TAKLİDİ ÜRÜNÜN KULLANDIĞI YÜZEYE GÖRE BÜYÜT — EKSİK
    // TAKLİT, ÇALIŞAN KODU SUÇLAYAN BİR TANIK OLUR."
    // 🔴 12 EYLÜL — AYNI DERS, İKİNCİ KEZ, AYNI SEBEPLE.
    // Daralan bant `Animated.event` ve `Animated.ScrollView` kullanıyor;
    // taklitte ikisi de yoktu ve test yine "BİLEŞEN ÇÖKTÜ" dedi. Bu
    // dosyanın hemen üstünde v3.4'te yazdığım ders aynen duruyordu —
    // dersi okumuştum, taklidi büyütmeyi unutmuştum.
    if (k === "Animated") return {
      View: h("View"), Text: h("Text"), Image: h("Image"),
      ScrollView: h("ScrollView"),
      event: () => () => {},
      timing: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      spring: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      sequence: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      parallel: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      loop: () => ({ start: () => {}, stop: () => {} }),
      stagger: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      delay: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
      Value: function () {
        this.setValue = () => {};
        this.interpolate = () => 0;
        this.addListener = () => "1";
        this.removeListener = () => {};
      },
    };
    if (k === "PanResponder") return { create: (cfg) => ({ panHandlers: {} }) };
    if (k === "Easing") return {
      linear: (x) => x, ease: (x) => x, quad: (x) => x, cubic: (x) => x,
      out: (f) => (f || ((x) => x)), in: (f) => (f || ((x) => x)),
      inOut: (f) => (f || ((x) => x)), bezier: () => ((x) => x), poly: () => ((x) => x), back: () => ((x) => x),
    };
    if (k === "NativeModules") return {};
    if (k === "UIManager") return { getViewManagerConfig: () => null };
    if (k === "I18nManager") return { isRTL: false };
    if (k === "processColor") return (c) => c;
    if (k === "Appearance") return { getColorScheme: () => "light", addChangeListener: () => ({ remove() {} }) };
    if (k === "__esModule") return true;
    if (k === "default") return undefined;
    return h(String(k));      // View, Text, TouchableOpacity, ScrollView...
  },
});

STUBS["@expo/vector-icons/Ionicons"] = { __esModule: true, default: h("Ionicons") };
// 🔴 31 AĞUSTOS · 8. TUR — AYNI TAKLİT ÜÇÜNCÜ KEZ, ÜÇÜNCÜ DOSYADA.
// `@expo/vector-icons` üç yerde ayrı ayrı taklit ediliyor: `stub_ikon.js`,
// `mount_test.js` ve `giris_kapisi_test.js`. `src/ikon.js`e ikinci bir
// aile (`createIconSet` ile kendi radar glifimiz) eklenince ÜÇÜ DE
// kırıldı ve üçünü de tek tek düzeltmek gerekti.
//
// 🆕 SINIF: "AYNI TAKLİDİ ÜÇ YERDE TUTMAK, BİR BAĞIMLILIK DEĞİŞİKLİĞİNİ
// ÜÇ AYRI KIRILMAYA ÇEVİRİR — VE ÜÇÜNCÜSÜNÜ BULMAK EN ZORUDUR."
STUBS["@expo/vector-icons"] = {
  __esModule: true,
  Ionicons: h("Ionicons"),
  createIconSet: (glyphMap, aile) => {
    const S = h(aile || "LLSimge");
    S.loadFont = async () => true;
    S.glyphMap = glyphMap;
    return S;
  },
};

// 🔴 VARLIK TAKLİDİ EKSİKTİ — VE BU EKSİK BİR ÇÖKMEYİ GİZLEDİ.
// `FotoBant` içinde `require("../assets/bant.jpg")` var. Node bir JPEG'i
// JavaScript sanıp çözümlemeye çalıştı ve bileşen çöktü. Test ise
// "boş render — veri yokken normal" diyip YEŞİL yandı.
// `runner.js` bu taklidi zaten taşıyordu; bu dosya taşımıyordu. Aynı
// uygulamayı iki farklı sahte dünyada test etmek, ikisinden birinin
// gerçeği yansıtmadığı anlamına gelir.
const VARLIK = /\.(png|jpe?g|gif|webp|svg|ttf|otf)$/i;
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (req, ...rest) {
  if (STUBS[req]) return "STUB:" + req;
  if (VARLIK.test(req)) return path.join(__dirname, "stub_asset.js");
  return origResolve.call(this, req, ...rest);
};
const origLoad = Module._load;
Module._load = function (req, ...rest) {
  if (STUBS[req]) return STUBS[req];
  return origLoad.call(this, req, ...rest);
};

// ---- Supabase'i sahtele: ağ YOK, ama şekil doğru ----
// Gerçek veri döndürmüyoruz; amacımız bileşenin BOŞ VERİYLE de
// çökmeden render olduğunu görmek. Boş liste, en sık kırılan durumdur.
const fakeQuery = () => {
  const q = {
    select: () => q, eq: () => q, gte: () => q, lte: () => q, in: () => q,
    order: () => q, limit: () => q, maybeSingle: async () => ({ data: null }),
    single: async () => ({ data: null }), insert: async () => ({ error: null }),
    update: () => q, upsert: async () => ({ error: null }), delete: () => q,
    then: (r) => Promise.resolve({ data: [], error: null }).then(r),
    catch: (r) => Promise.resolve({ data: [], error: null }).catch(r),
  };
  return q;
};
require.cache[require.resolve("../src/supabase.js")] = {
  id: "supabase", filename: "supabase", loaded: true,
  exports: {
    supabase: {
      from: fakeQuery,
      // 🔴 GERCEK BIR PROMISE DONDUR. Ilk yazimda elle bir "then/catch"
      // nesnesi uydurmustum ve `.then(...).catch(...)` zinciri kirildi:
      // `then` bir Promise degil undefined donuyordu.
      //
      // Test iki ekrani "cokuyor" diye isaretledi — ama coken KOD DEGIL
      // TESTIN KENDISIYDI. Sahte nesne, taklit ettigi seyin
      // SOZLESMESINE uymalidir; yoksa test yalan soyler.
      // 🔴 BOS DIZI YETMEZ — MUTASYON TESTI BUNU GOSTERDI.
      // Ilk halde her cagriya `[]` donuyordum. Bircok ekran `rows === null`
      // iken ERKEN CIKIYOR ("yukleniyor" hali) ve asil render yolu hic
      // calismiyordu: iki kasitli hatayi (tanimsiz degisken, null.length)
      // test YAKALAYAMADI.
      //
      // Sahte veri, testin GORDUGU kod miktarini belirler. Bos veri ile
      // test etmek, ekranin yalniz bos halini test etmektir — ve gercek
      // hatalar dolu halde yasar.
      rpc: (fn) => Promise.resolve({ data: RPC_DATA[fn] ?? [], error: null }),
      auth: {
        getSession: async () => ({ data: { session: null } }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
        signOut: async () => ({}),
      },
      channel: () => ({ on: () => ({ subscribe: () => ({}) }), subscribe: () => ({}) }),
      removeChannel: () => {},
    },
    logError: () => {},
    setAppVersion: () => {},
    SUPABASE_URL: "https://test.supabase.co",
  },
};

const renderer = require("react-test-renderer");
const { D } = require("../src/i18n");
const S = require("../src/screens");
// 🔴 12 EYLÜL · KAPSAM TURU — App.js'teki ekranlar da mount ediliyor.
// `Home`, `Onboarding`, `Splash`, `CompleteOnboarding`, `SetNewPassword`
// bu dosyada değil App.js'te yaşıyor ve tam da bu yüzden yıllardır mount
// testinin DIŞINDAYDI: liste `S`den besleniyordu, orada olmayan ekran
// sessizce kapsam dışı kalıyordu.
// 🆕 SINIF: "BİR TEST LİSTESİNİ TEK BİR MODÜLDEN BESLERSEN, O MODÜLÜN
// DIŞINDA KALAN HER ŞEY TEST EDİLMİŞ GİBİ GÖRÜNÜR — KAPSAMI MODÜL DEĞİL
// ÜRÜN TANIMLAR."
const A = require("../App.js");
const { Atmosfer } = require("../src/atmosfer");
const UI = require("../src/ui");

// ============================================================================
// FOTOĞRAFLI BANT NÖBETÇİSİ (v3.1)
//
// 🔴 "RENDER GEÇTİ" BANDIN ORADA OLDUĞUNU KANITLAMAZ.
// `foto` prop'unu Discovery'ye ekledim ve 25 ekranın hepsi yeşil kaldı —
// ama bant hiç çizilmemiş olsaydı da yeşil kalırdı, çünkü hiçbir kontrol
// ona bakmıyordu. Kabuk denetiminde aynı tuzağa düşmüştüm.
//
// Bu nöbetçi iki şeyi ölçüyor:
//   VAR MI   : Discovery ağacında FotoBant bileşeni bulunuyor mu
//   KATMAN   : her başlık satırı DÖRT `Text` düğümü taşıyor mu
//              (üç gölge + asıl metin). Tasarımın 5.06:1'i buna bağlı;
//              biri düşerse kontrast sessizce 2.80'e iner ve kimse görmez.
//
// 🆕 SINIF: "BİR ETKİYİ KATMAN SAYISIYLA ELDE ETTİYSEN, KATMAN SAYISINI
// DA ÖLÇMEK ZORUNDASIN — 'ÇALIŞIYOR' HÂLİ İLE 'ÜÇ KATMANI EKSİK ÇALIŞIYOR'
// HÂLİ AYNI GÖRÜNÜR."
// ============================================================================
const BANT_BEKLENEN = { Discovery: true };
let bantSonuc = null;

function bantOlc(name, tree) {
  if (!BANT_BEKLENEN[name]) return null;
  let bant = [];
  try { bant = tree.root.findAllByType(UI.FotoBant); } catch (e) { return null; }
  if (bant.length === 0) return "FOTOĞRAFLI BANT YOK — Hdr'a foto prop'u gitmiyor";
  // gölge katmanları: bandın içindeki Text düğümlerini say
  // 🔴 v3.4 — SLOT İÇERİĞİ SAYIMDAN ÇIKARILIYOR.
  // Band artık dışarıdan eylem alanı alıyor (filtre düğmesi, geri oku).
  // O metinler bandın kendi gölgeli metinleri DEĞİL; sayıma girince
  // "4'ün katı" değişmezi kırılıyor ve DOĞRU çalışan bir düğme kusur
  // gibi görünüyordu.
  //
  // 🆕 SINIF: "BİR DEĞİŞMEZ BİLEŞENİN KENDİ ÜRETTİĞİ ŞEY HAKKINDAYSA,
  // DIŞARIDAN GELEN ÇOCUKLARI SAYIMA KATMA — YOKSA DEĞİŞMEZ, BİLEŞENİN
  // GENİŞLEMESİNİ HATA SANAR."
  let metin = 0;
  try {
    // 🔴 3 EYLÜL — EŞLEŞTİRİCİ DÜZELTİLDİ. `String(n.type).includes("Text")`
    // bir BİLEŞENİN KAYNAK KODUNU da eşliyordu (FotoBant/Btn/GolgeliMetin
    // gövdesinde "Text" geçiyor). Sayım "4'ün katı" olduğu için tesadüfen
    // geçiyordu; FotoBant'a bir yuva eklenince (serifBaslik) kaynak metni
    // değişti ve sayım 7'ye düştü — kusur üründe değil ölçü aletindeydi.
    // Artık yalnız GERÇEK Text düğümleri sayılıyor.
    // Yalnız HOST düğüm: taklit `Text` bileşeni altına bir "Text" host düğümü
    // çizer; bileşeni de sayarsak her metin iki kez sayılır.
    const textMi = (n) => typeof n.type === "string" && n.type === "Text";
    const hepsi = bant[0].findAll(textMi);
    let slotIci = 0;
    try {
      bant[0].findAll(n => n.props && n.props.testID === "bant-slot")
        .forEach(sl => { slotIci += sl.findAll(textMi).length; });
    } catch (e) {}
    metin = hepsi.length - slotIci;
  } catch (e) { metin = 0; }
  bantSonuc = { bant: bant.length, metin };
  // 🔴 İLK EŞİĞİM "en az 8" İDİ VE MUTASYON TESTİNİ GEÇEMEDİ: bir gölge
  // katmanını sildim, düğüm sayısı 16 → 12 oldu ve 12 hâlâ 8'den büyük
  // olduğu için test YEŞİL kaldı. Gevşek bir eşik, eşik değildir.
  //
  // Katman sayısı artık DOĞRUDAN ölçülüyor: 5.06:1 rakamı üç gölge + asıl
  // metne bağlı. İkiye düşerse 4.33, bire düşerse 2.80 — ve hiçbiri
  // ekranda "bozuk" görünmez, sadece daha az okunur olur.
  if (UI.GOLGE_KATMAN.length !== 3)
    return "GÖLGE KATMANI " + UI.GOLGE_KATMAN.length + " (3 olmalı) — "
         + "kontrast varsayımı 5.06:1 artık geçerli değil";
  // 🔴 3 EYLÜL — DEĞİŞMEZ ARTIK GÖLGE KATMANINI DOĞRUDAN ÖLÇÜYOR.
  // "4'ün katı" varsayımı, her bant metninin 3 gölge + 1 asıl olduğu
  // döneme aitti; 8. turdan beri `GolgeliMetin` varsayılan olarak
  // gölgesiz (tasarımda text-shadow yok) ve tek Text çiziyor. Eski
  // sayım tesadüfen geçiyordu. Şimdi: her GolgeliMetin `golge` ise
  // TAM 4, değilse TAM 1 Text çizmeli — bu bileşenin sözleşmesi.
  let sapma = null;
  try {
    const gm = bant[0].findAll(n => n.type && (n.type.name === "GolgeliMetin"));
    for (const g of gm) {
      const n = g.findAll(x => typeof x.type === "string" && x.type === "Text").length;
      const bekl = g.props.golge ? UI.GOLGE_KATMAN.length + 1 : 1;
      if (n !== bekl) { sapma = "GolgeliMetin " + n + " Text çizdi, beklenen " + bekl; break; }
    }
  } catch (e) {}
  if (sapma) return sapma;
  if (metin < 2) return "bantta metin yok (" + metin + ")";
  return null;
}

// ============================================================================
// ATMOSFER NÖBETÇİSİ  (v3.1 · 26 Ağustos 2026)
//
// 🔴 NEDEN BURAYA, AYRI BİR DOSYAYA DEĞİL
// Bu dosya 25 ekranı zaten mount ediyor. Atmosferi ayrı bir test dosyasında
// ölçseydim 250 satırlık taklit kurulumunu ikinci kez yazmam gerekirdi — ve
// 26 Ağustos'ta tam olarak bunu yapıp AYNI ayrıştırma hatasını dört ayrı
// araçta tekrarlamıştım. Aynı kurulum tek yerde kalıyor.
//
// NE ÖLÇÜYOR — iki ayrı kırılma, ikisi de sessiz:
//   YOK   : ekran <Sayfa> kullanmıyor → o ekranda arka plan hiç çizilmiyor.
//           Kimse hata görmez; sadece bir ekran diğerlerinden farklı olur.
//   ÇİFT  : iç içe iki <Sayfa> → doku iki kez üst üste biner, %9 sessizce
//           %18 olur ve o ekranda metin kontrastı ölçtüğümden düşer.
//
// ⚠️ SINIRI: bu bir AĞAÇ ölçümüdür, piksel ölçümü değil. "Atmosfer mount
// edildi" der; "ekranda ne kadar koyu göründüğü"nü SÖYLEMEZ — onu
// `tema_check.py` renk tarafında ölçüyor. Kanıtladığından fazlasını iddia
// etmemek testin kendisi kadar önemli.
//
// 🔴 toJSON() DEĞİL root.findAllByType(): RN taklidi prop'ları düşürüyor
// (h(tag) yalnız children'ı geçiriyor), o yüzden JSON çıktısında bileşen
// kimliği KAYBOLUYOR. ReactTestInstance ağacında ise duruyor.
// ============================================================================
// KENDİ SAYFASINI BOYAYAN ekranlar: kökleri <Sayfa>, atmosferi kendileri taşır.
const ATMOSFER_BEKLENEN = new Set([
  "Discovery", "Profile", "EditProfile", "HostAvailability", "AddVisit",
  "Notifications", "Wallet", "Settings", "HostAccessSource",
  "Degerlendirmeler", "EditAvailability", "EditAvailability-boş",
]);

// KABUKTAN ALAN ekranlar: kökleri <ScrollView>, kendi zeminlerini HİÇ
// boymuyorlar. Atmosferi App.js'teki sekme kabuğu taşıyor. Burada 0
// beklemek doğru — 1 çıkarsa kabukla ÜST ÜSTE binmiş demektir.
const ATMOSFER_KABUKTAN = new Set(["Trips", "LoungeGuide", "BaglantiIstekleri"]);

const atmosferSonuc = [];

// 🔴 NÖBETÇİMİN İLK HALİ YANLIŞ KIRMIZI VERDİ — ve sebebi tanıdıktı.
// Discovery'de "ATMOSFER 2 KEZ" dedi. İkincisi bir <Modal> içindeydi:
// tam ekran bir modal KENDİ zeminini boyamak ZORUNDA, yani orada ikinci
// atmosfer kusur değil GEREKLİLİK. Cihazda modal ayrı bir pencere; üst
// üste binme diye bir şey yok. Binen tek şey benim taklidimdi: RN
// taklidi `visible` prop'unu yok sayıp modal çocuklarını her zaman
// çiziyor.
//
// 🆕 SINIF: "BİR NÖBETÇİ, TAKLİDİN DÜNYASINI ÜRÜNÜN DÜNYASI SANDIĞI AN
// KENDİ UYDURDUĞU KUSURU RAPORLAR."
function modalIcinde(inst) {
  let p = inst.parent;
  while (p) {
    const ad = (p.type && (p.type.displayName || p.type.name)) || p.type;
    if (ad === "Modal") return true;
    p = p.parent;
  }
  return false;
}

function atmosferOlc(name, tree) {
  let hepsi = [];
  try { hepsi = tree.root.findAllByType(Atmosfer); } catch (e) { return null; }
  const n = hepsi.filter(x => !modalIcinde(x)).length;
  const modalli = hepsi.length - n;
  if (n > 1) return `ATMOSFER ${n} KEZ (modal dışı) — iç içe <Sayfa>, doku üst üste biniyor`;
  if (ATMOSFER_BEKLENEN.has(name) && n === 0)
    return "ATMOSFER YOK — bu ekran <Sayfa> kullanmıyor";
  if (ATMOSFER_KABUKTAN.has(name) && n === 1)
    return "ATMOSFER FAZLA — bu ekran kabuktan alıyor, kendi de çizerse üst üste biner";
  atmosferSonuc.push([name, n, modalli]);
  return null;
}

// 🔴 GERCEKCI SAHTE VERI: ekranlarin DOLU halini de render etmek icin.
// Sekil, gercek RPC ciktilariyla ayni; degerler temsili.
const RPC_DATA = {
  ulasilabilirlik_uyarim: { ulasilabilir: false, durum: "reddedildi",
    tekrar_sorulabilir: false, aktif_ilan: 2, bekleyen_istek: 1, siddet: "kritik",
    mesaj: "Bekleyen bir isteğin var ve bildirimlerin kapalı.",
    ayarlar_gerekli: true, ayarlar_mesaji: "Telefon ayarlarından açman gerekiyor.",
    hazirlik_mesaji: "Bir misafir isteği geldiğinde saniyeler önemli." },
  guide_airports: [{ code: "IST", city: "İstanbul", name: "İstanbul Havalimanı", lounges: 6, has_rules: true }],
  guide_programs: [{ code: "TK_MS", name: "Turkish Airlines Miles&Smiles", popular: true,
                     tiers: [{ code: "ELPL", label: "Elite Plus" }, { code: "CLPL", label: "Classic Plus" }] }],
  guide_lounges: [{ venue_id: "11111111-1111-1111-1111-111111111111",
                    lounge_name: "Turkish Airlines Lounge — Dış Hat", scope: "international", terminal: "",
                    amenities: { wifi: true, shower: true }, verdict: "yes",
                    headline: "1 misafir götürebilirsin", detail: "Aile veya bir misafir.",
                    guest_count: 1, confidence: "verified", source_url: null }],
  guide_hosts_today: { airport: "IST", count: 3, next_date: "2026-08-14" },
  travel_style_options: [{ code: "social", label: "Sohbete açığım", sub: "Muhabbet edelim", sort_order: 1 }],
  carrier_options: [{ code: "TK", name: "Türk Hava Yolları", alliance: "star_alliance", is_lowcost: false }],
  host_unused_rights: { known: true, total: 12, used: 4, left: 8,
                        headline: "Bu yıl 8 misafir hakkın kullanılmadan duruyor.",
                        sub: "Kullanılmayan haklar yıl sonunda siliniyor.", note: "Beyanına dayanır." },
  founding_host_status: { taken: 12, left: 88, mine: null },
  card_product_options: [{ id: "22222222-2222-2222-2222-222222222222", issuer: "QNB",
                           name: "Private", program: "LoungeKey", confidence: "verified", verified: true }],
  discover_availabilities: [],
  pending_ratings: [],
};

const t = D.tr;
const session = { user: { id: "00000000-0000-0000-0000-000000000001" } };

// Her ekran: (ad, bileşen, props)
// 🔴 Props'ları GERÇEK kullanımdaki gibi veriyoruz. Eksik prop ile
// render etmek, testin kendisini yalancı yapar.
const CASES = [
  ["Trips",            S.Trips,            { t, session, lang: "tr", onDiscover: () => {}, onGuide: () => {}, onAddTrip: () => {}, onMeet: () => {}, onOpenChat: () => {} }],
  ["LoungeGuide",      S.LoungeGuide,      { t, onBack: () => {}, onDiscover: () => {} }],
  ["Discovery",        S.Discovery,        { t, session, lang: "tr", scope: {}, onBack: () => {}, onOpenProfile: () => {}, onMeet: () => {}, onAddTrip: () => {}, onVerify: () => {} }],
  ["Profile",          S.Profile,          { t, lang: "tr", setLang: () => {}, session, onEditProfile: () => {}, onLogout: () => {} }],
  ["EditProfile",      S.EditProfile,      { t, session, onBack: () => {}, onDone: () => {} }],
  ["HostAvailability", S.HostAvailability, { t, session, onBack: () => {}, onDone: () => {}, onVerify: () => {} }],
  ["AddVisit",         S.AddVisit,         { t, session, onBack: () => {}, onDone: () => {} }],
  ["Meet",             S.Meet,             { t, lang: "tr", session, onOpenProfile: () => {}, onOpenChat: () => {} }],
  ["RequestsPanel",    S.RequestsPanel,    { t, session, onOpenChat: () => {} }],
  ["Notifications",    S.Notifications,    { t, session, onBack: () => {} }],
  ["Wallet",           S.Wallet,           { t, session, onBack: () => {} }],
  ["Settings",         S.Settings,         { t, lang: "tr", setLang: () => {}, session, onBack: () => {} }],
  ["HostAccessSource", S.HostAccessSource, { t, session, onBack: () => {}, onDone: () => {} }],
  // 🔴 v2.95 — YENİ EKRANLAR BURAYA DA GİRDİ.
  // Bir ekranı yazıp mount testine koymamak, "yazdım ama çağırmadım"
  // sınıfının test tarafındaki kardeşidir: ekran var, hiç render
  // edilmediği için boş veriyle çöküp çökmediği bilinmiyor.
  ["HostDaveti",       S.HostDaveti,       { t, onBecomeHost: () => {}, onAddAvail: () => {} }],
  ["SakinGun",         S.SakinGun,         { t, session, role: "guest", bekleyenVar: false,
    onDiscover: () => {}, onPlan: () => {}, onHostOl: () => {}, onMeet: () => {} }],
  ["SakinGun-mesgul",  S.SakinGun,         { t, session, role: "host", bekleyenVar: true,
    onDiscover: () => {}, onPlan: () => {}, onHostOl: () => {}, onMeet: () => {} }],
  ["Degerlendirmeler", S.Degerlendirmeler, { t, lang: "tr", onBack: () => {}, onRate: () => {}, onOpenProfile: () => {} }],
  ["BaglantiIstekleri", S.BaglantiIstekleri, { t, lang: "tr", onOpenChat: () => {}, onOpenProfile: () => {} }],
  ["EditAvailability", S.EditAvailability, { t, onBack: () => {}, onDone: () => {},
    avail: { id: "a1", airport_code: "IST", lounge_id: "l1", lounge_name: "Test Lounge",
             avail_date: "2026-09-04", time_from: "10:00:00", time_to: "16:00:00",
             slots: 2, flight_number: "TK1234", min_trust: 60, visibility: "Public" } }],
  // Boş/eksik `avail` ile de çökmemeli: ilan listesi eski bir kayıt
  // döndürebilir ve o kayıtta yeni kolonlar olmayabilir.
  ["EditAvailability-boş", S.EditAvailability, { t, onBack: () => {}, onDone: () => {}, avail: {} }],
  // ── ULAŞILABİLİRLİK KARTI (v2.98 · G7) ─────────────────────────────
  // 🔴 BU İKİ VAKANIN İKİNCİSİ OLMASAYDI TEST HİÇBİR ŞEY KANITLAMAZDI:
  // kart "hiçbir şey çizmemek" ile de geçerdi (boş render normal sayılıyor).
  // Onun için 4. eleman: çizilen ağaçta ARANACAK metin.
  ["UlasilabilirlikKarti", S.UlasilabilirlikKarti, { t, goster: ["kritik", "uyari"] },
    // İzin bir daha sorulamıyorsa düğme AYARLAR'a götürmeli; "Bildirimleri aç"
    // yazan ama hiçbir şey yapmayan bir düğme, olmayan düğmeden kötüdür.
    // 3 Eylül: cihazdaki izin de KAPALI (kart artık cihaza da bakıyor).
    { icermeli: t.pushOpenSettings, izin: { status: "denied", canAskAgain: false } }],
  // 3 Eylül — cihazda izin AÇIK ama jeton yok (Firebase kurulu değil):
  // kart "Bildirimleri aç" DEMEMELİ; nedeni yazıp "Tekrar dene" vermeli.
  ["UlasilabilirlikKarti-izinAcik", S.UlasilabilirlikKarti, { t, goster: ["kritik", "uyari"] },
    { icermeli: t.retry, icermemeli: t.pushEnable, izin: { status: "granted", canAskAgain: true }, jeton: "fcm" }],
  ["UlasilabilirlikKarti-filtre", S.UlasilabilirlikKarti, { t, goster: ["bilgi"] },
    // Aynı veri, farklı şiddet süzgeci: bu kart HİÇ çizilmemeli.
    { bos: true }],
  ["Amenities",        S.Amenities,        { data: { wifi: true, shower: true, extra: ["Bilardo"] } }],
  ["Amenities-boş",    S.Amenities,        { data: {} }],
  ["Amenities-null",   S.Amenities,        { data: null }],
  // ══════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL · KAPSAM TURU — 24 EKRAN DAHA.
  // `ekran_kapsam_check.py` saydı: 36 ekranın 12'si mount testindeydi.
  // Geri kalan 24'ü premium tur boyunca hiç render edilmedi; jetonlar
  // üzerinden değiştiler ve "herhalde doğrudur" dendi. Artık hepsi
  // burada: boş veriyle çökme, taşma ve iki temada çizilme ölçülüyor.
  // ══════════════════════════════════════════════════════════════════
  ["Splash",           A.Splash,           { t }],
  ["Onboarding",       A.Onboarding,       { t, onDone: () => {}, onLogin: () => {} }],
  ["Home",             A.Home,             { t, lang: "tr", session, onOpenChat: () => {},
    onOpenCompanion: () => {}, onVerify: () => {}, onRole: () => {}, setRadar: () => {},
    setTab: () => {}, setHostTripsSub: () => {}, onWallet: () => {}, onOpenProfile: () => {},
    onDiscover: () => {}, setShowQuestions: () => {}, onGuide: () => {}, setMeetSub: () => {},
    setShowIstekler: () => {}, onProfilSekmesi: () => {} }],
  ["CompleteOnboarding", A.CompleteOnboarding, { t, session, onDone: () => {}, onLogout: () => {} }],
  ["SetNewPassword",   A.SetNewPassword,   { t, onDone: () => {} }],

  ["KuralKarari",      S.KuralKarari,      { t, avail: { id: "a1" }, skor: 60,
    onBack: () => {}, onSend: () => {}, onVenueRules: () => {} }],
  ["Chat",             S.Chat,             { t, session, onBack: () => {},
    request: { id: "r1", host_id: "00000000-0000-0000-0000-000000000001",
               guest_id: "00000000-0000-0000-0000-000000000002", status: "accepted" },
    otherName: "Deniz K." }],
  // 🔴 VE EKSİK `request` İLE DE: Sohbet bildirimden, Oturum Geçmişi'nden
  // ve Canlı Durum'dan yalnız `{ id }` ile açılabiliyor (v1.71 notu bunu
  // zaten yazmış). O yolda `reqFull.host_id` PATLIYORDU — bu vaka onu
  // yakaladı ve kod sertleştirildi.
  ["Chat-eksik",       S.Chat,             { t, session, onBack: () => {}, request: { id: "r1" } }],
  ["Chat-bos",         S.Chat,             { t, session, onBack: () => {} }],
  ["CompanionChat",    S.CompanionChat,    { t, session, channelId: "c1", otherName: "Deniz K.", onBack: () => {} }],
  ["Marketplace",      S.Marketplace,      { t, session, onBack: () => {} }],
  ["Plans",            S.Plans,            { t, session, onBack: () => {} }],
  ["Safety",           S.Safety,           { t, onBack: () => {} }],
  ["SessionHistory",   S.SessionHistory,   { t, lang: "tr", session, onBack: () => {} }],
  ["TrustVisual",      S.TrustVisual,      { t, session, onBack: () => {} }],
  ["Referral",         S.Referral,         { t, session, onBack: () => {} }],
  ["Campaigns",        S.Campaigns,        { t, session, onBack: () => {} }],
  ["MyQuestions",      S.MyQuestions,      { t, lang: "tr", session, onBack: () => {} }],
  ["PublicProfile",    S.PublicProfile,    { t, lang: "tr", session, userId: "00000000-0000-0000-0000-000000000002", onBack: () => {} }],
  ["HostApply",        S.HostApply,        { t, session, onBack: () => {}, onDone: () => {} }],
  ["HostBroadcast",    S.HostBroadcast,    { t, session, onBack: () => {}, onVerify: () => {}, lang: "tr" }],
  ["LiveStatus",       S.LiveStatus,       { t, session, onBack: () => {} }],
  ["KimlikDogrula",    S.KimlikDogrula,    { t, session, onBack: () => {}, onDone: () => {} }],
  ["VerifyPhone",      S.VerifyPhone,      { t, session, onBack: () => {}, onDone: () => {} }],
  ["ReportUser",       S.ReportUser,       { t, session, userId: "00000000-0000-0000-0000-000000000002", onBack: () => {}, onDone: () => {} }],
  ["EditTrip",         S.EditTrip,         { t, onBack: () => {}, onDone: () => {},
    trip: { id: "t1", airport_code: "IST", visit_date: "2026-09-14", time_from: "14:00:00", time_to: "18:00:00" } }],
];

// 🔴 EN ÖNEMLİ DÜZELTME: ÇÖKEN BİR BİLEŞEN BOŞ RENDER EDER VE TEST ONU
// "normal" SAYIYORDU. React, bir bileşen hata atınca onu console.error'a
// yazıp ağacı boş bırakıyor; testin gördüğü şey `json === null` ve
// buradaki metin "boş render — veri yokken normal".
//
// Yani harness'in en sık gördüğü iyi haber, en ciddi kötü haberi
// gizleyebiliyordu. Artık React'in hata çıktısı yakalanıyor ve o ekran
// KIRMIZI yanıyor.
//
// 🆕 SINIF: "BİR TESTİN 'BU DURUM NORMAL' DEDİĞİ HER YER, BİR HATANIN
// SAKLANABİLECEĞİ YERDİR — NORMALİ TANIMLARKEN NEYİ DIŞARIDA
// BIRAKTIĞINI DA TANIMLA."
const REACT_HATA = [];
const _origConsoleError = console.error;
console.error = function (...a) {
  const s = String(a[0] || "");
  if (/The above error occurred in the <(\w+)> component/.test(s)) {
    REACT_HATA.push(s.match(/<(\w+)>/)[1]);
    return;                       // yığın izini bastırma, kaydı tut
  }
  _origConsoleError.apply(console, a);
};

// ══════════════════════════════════════════════════════════════════════
// 🔴 12 EYLÜL · GECE — TANIMSIZ İKON ADI ARTIK KAPI KIRAR.
//
// `Ikon` bilmediği bir ada `console.warn` atıp GÖRÜNÜR bir yer tutucu
// çiziyor (ikon.js:421) — yani ürün çökmüyor, ama kullanıcı anlamı
// olmayan boş bir kare görüyor. Bu uyarı bugüne kadar hiçbir yerde
// TOPLANMIYORDU: 104 render boyunca akıp gidiyordu.
//
// Statik tarama tek başına yetmiyor, çünkü çağrıların bir kısmı
// `ad={degisken}`: adı ancak ÇALIŞMA ANINDA biliyoruz. 52 ekran × 2
// tema render edilirken uyarıyı yakalamak, dinamik adları da kapsayan
// tek yol.
//
// 🆕 SINIF: "BİR BİLEŞEN 'SESSİZCE BOZULMAK YERİNE UYARI VEREYİM'
// DİYORSA, O UYARIYI KİMSE TOPLAMADIĞI SÜRECE YİNE SESSİZCE
// BOZULUYORDUR."
// ══════════════════════════════════════════════════════════════════════
const IKON_UYARI = new Set();
const _origConsoleWarn = console.warn;
console.warn = function (...a) {
  const s = String(a[0] || "");
  if (s.indexOf("Ikon: tanımsız ad") === 0) {
    IKON_UYARI.add(String(a[1]));
    return;
  }
  _origConsoleWarn.apply(console, a);
};

process.on("unhandledRejection", () => {});
process.on("uncaughtException", (e) => {
  console.log("  ✗ (yakalanmamis) " + String(e && e.message).split("\n")[0].slice(0, 90));
});

console.log("=".repeat(68));
console.log("MOUNT TESTİ — bileşenler GERÇEKTEN render oluyor mu?");
console.log("=".repeat(68));

let ok = 0;
const bad = [];

async function run() {
for (const [name, Comp, props, bekle] of CASES) {
  if (typeof Comp !== "function") {
    bad.push([name, "bileşen dışa aktarılmamış (export eksik)"]);
    console.log(`  ✗ ${name} — export yok`);
    continue;
  }
  globalThis.__IZIN = (bekle && bekle.izin) || null;
  globalThis.__JETON_HATA = (bekle && bekle.jeton) || null;
  // Ambiyans kuşağı saate bağlı (bkz. atmosfer.js). Testi saate bağlı
  // bırakmak, gece koşan bir CI ile gündüz koşan bir geliştiricinin
  // farklı sonuç görmesi demekti.
  globalThis.__LL_AMBIYANS = "aksam";
  try {
    let tree;
    // 🔴 MOUNT YETMEZ — VERI GELDIKTEN SONRAKI RENDER'I DA BEKLE.
    // Ilk halde yalniz senkron mount'u test ediyordum ve iki kasitli
    // hatayi (tanimsiz degisken, null.length) YAKALAYAMADI: o kod yollari
    // `useEffect` icindeki async yukleme BITTIKTEN sonra calisiyor.
    //
    // Yani test "ekran aciliyor mu" diyordu; sorulmasi gereken
    // "ekran VERI GELINCE de ayakta mi" idi. Cogu cokme ikinci renderdadir.
    await renderer.act(async () => {
      tree = renderer.create(React.createElement(Comp, props));
      // mikro gorevleri bosalt: bekleyen tum Promise'ler cozulsun
      for (let k = 0; k < 6; k++) await Promise.resolve();
      await new Promise((r) => setTimeout(r, 0));
    });
    const json = tree.toJSON();
    if (REACT_HATA.length) {
      const kim = REACT_HATA.splice(0).join(", ");
      throw new Error("BİLEŞEN ÇÖKTÜ (React yakaladı): <" + kim + "> — boş render bunu gizliyordu");
    }
    // 🔴 UNMOUNT'TAN ÖNCE: sökülmüş ağaçta bileşen aranmaz.
    const atmHata = atmosferOlc(name, tree) || bantOlc(name, tree);
    await renderer.act(async () => tree.unmount());
    if (atmHata) throw new Error(atmHata);
    // 🔴 v2.98 — "BOŞ RENDER NORMAL" BİR KAPIYDI: hiçbir şey çizmeyen bir
    // bileşen de yeşil yanıyordu. Bir vaka NE ÇİZMESİ gerektiğini söylerse
    // artık ONU da ölçüyoruz.
    if (bekle) {
      const duz = JSON.stringify(json);
      if (bekle.bos && json !== null) {
        throw new Error("BOS cizmesi gerekirken cizdi");
      }
      if (bekle.icermeli && (json === null || duz.indexOf(String(bekle.icermeli)) < 0)) {
        throw new Error("beklenen metin cizilmedi: " + bekle.icermeli);
      }
      if (bekle.icermemeli && json !== null && duz.indexOf(String(bekle.icermemeli)) >= 0) {
        throw new Error("çizilmemesi gereken metin çizildi: " + bekle.icermemeli);
      }
    }
    ok++;
    const kids = json ? (Array.isArray(json) ? json.length : 1) : 0;
    console.log(`  ✓ ${name}${kids === 0 ? "  (boş render — veri yokken normal)" : ""}`);
  } catch (e) {
    const msg = String(e && e.message).split("\n")[0].slice(0, 110);
    bad.push([name, msg]);
    console.log(`  ✗ ${name}`);
    console.log(`      ${msg}`);
  }
}

// ────────────────────────────────────────────────────────────────────────
// KOYU TEMA — AYNI EKRANLAR, İKİNCİ PALET
//
// 🔴 KAYNAK DENETİMİ (`koyu_check.py`) "her tokenin koyu karşılığı var"
// diyebilir ve tema YİNE DE ÇALIŞMAYABİLİR: `S` (ortak.js) ve `st`
// (App.js) değerleri modül yüklenirken KOPYALIYOR. Kaynağa bakan hiçbir
// araç "kopya tazelendi mi" sorusunu yanıtlayamaz — o soru ancak
// GERÇEKTEN RENDER EDİLMİŞ bir ağaçta yanıtlanır.
//
// Bu blok temayı çalışma anında değiştirip aynı ekranları yeniden
// mount ediyor ve çizilen ağaçtaki RENKLERİ topluyor. İki iddia:
//   1 · koyu paletin değerleri ağaçta GÖRÜNÜYOR
//   2 · açık paletin yüzey değerleri ağaçta GÖRÜNMÜYOR
// İkincisi olmadan birincisi yetmez: her iki paletin karıştığı bir
// ekran da "koyu renk var" testini geçerdi.
//
// 🆕 SINIF: "BİR TEMA ANAHTARININ ÇALIŞTIĞINI KANITLAMAK, YENİ RENGİN
// GÖRÜNDÜĞÜNÜ DEĞİL, ESKİ RENGİN KAYBOLDUĞUNU GÖSTERMEKTİR."
// ────────────────────────────────────────────────────────────────────────
// 🔴 İLK HÂLİ YANLIŞ ALARM VERDİ VE SEBEBİ ÖĞRETİCİ.
// "Açık tema yüzeyi sızdı: #FFFDF9" dedi — ama o piksel bir yüzey
// değildi: `C.foto.baslik`, yani FOTOĞRAFIN ÜSTÜNDEKİ başlık mürekkebi.
// Aynı hex iki iş yapıyor: açık temada kart zemini, her temada fotoğraf
// üstü metin. Değere bakan bir test ikisini ayıramaz.
//
// 🆕 SINIF: "BİR TESTİ DEĞERE BAKARAK YAZARSAN, AYNI DEĞERİ İKİ İŞTE
// KULLANAN HER YER SANA YALAN SÖYLER — TESTİN DE ROLÜ SORMASI GEREKİR."
//
// Artık iki ayrı küme toplanıyor: tüm renkler (koyu palet göründü mü)
// ve YALNIZ `backgroundColor` (açık yüzey sızdı mı).
function renkleriTopla(kok) {
  const hepsi = new Set(), zemin = new Set();
  const gez = (s) => {
    if (!s) return;
    if (Array.isArray(s)) return s.forEach(gez);
    if (typeof s !== "object") return;
    for (const k of Object.keys(s)) {
      const v = s[k];
      if (typeof v === "string" && v[0] === "#") {
        hepsi.add(v.toUpperCase());
        if (/^background(Color)?$/.test(k)) zemin.add(v.toUpperCase());
      } else if (v && typeof v === "object") gez(v);
    }
  };
  kok.findAll(() => true, { deep: true }).forEach(n => {
    if (n.props) { gez(n.props.style); gez(n.props.color); }
  });
  return { hepsi, zemin };
}

let koyuOk = 0;
let acikOk = 0;
const koyuBad = [];
try {
  const tema = require(path.join(APP, "src", "theme.js"));
  // `goldBtn` da koyuya özgü (açıkta #846A2A): boş listeli bir ekran yalnız
  // altın düğme çiziyorsa (Seyahatlerim, tasarım 14) parmak izi o.
  // 🔴 12 EYLÜL — PARMAK İZİ LİSTESİ DE BÜYÜDÜ, VE SEBEBİ ÖĞRETİCİ.
  // Kapsamı 8 ekrandan 52 vakaya çıkarınca `Amenities` kırmızı yandı:
  // "koyu palet ağaçta hiç görünmüyor". Oysa bileşen DOĞRU çiziyordu —
  // yalnızca `bgAlt` ve `mutedAA` kullanıyor, ikisi de listede yoktu.
  // Yani nöbetçi ürünü değil kendi dar listesini ölçüyordu. Bu dosyada
  // 10 satır yukarıda yazan ders tam olarak buydu; kapsamı büyütünce
  // aynı ders ikinci kez çarptı.
  const KOYU_IM  = [tema.KOYU.bg, tema.KOYU.surface, tema.KOYU.bgAlt, tema.KOYU.ink,
                    tema.KOYU.mutedAA, tema.KOYU.dimAA, tema.KOYU.goldBtn,
                    tema.KOYU.line,
                    // v6 — çizgi jetonları şeffaflaştı; koyu temanın izi artık
                    // altın gradyanın alt ucu ve üst kenar ışığında da duruyor.
                    tema.KOYU.goldBtn2, tema.KOYU.parlama].map(s => String(s).toUpperCase());
  // Açık temanın YALNIZ ona ait yüzey değerleri (koyuda karşılığı başka)
  // 🔴 ÜÇ YÜZEY YETMİYORMUŞ. Bu liste yalnız kart/blok/sayfa zeminini
  // içeriyordu; DÜĞME zeminleri yoktu. `ui.js`teki `BTN` tablosu tema
  // değişince yeniden kurulmadığı hâlde test yeşil kalıyordu.
  //
  // 🆕 SINIF: "SIZINTI TESTİNİN KAPSAMI, SIZABİLECEK DEĞERLERİN
  // LİSTESİ KADARDIR — LİSTEYİ DAR TUTARSAN TEST 'TEMİZ' DER."
  const ACIK_IM  = ["#FFFDF9", "#F4F1E9", "#F8F6F1", "#F0EDE6", "#E4E2DE",
                    "#251E17", "#745E47", "#7C644C",
                    "#846A2A", "#0A6E65", "#A11450", "#AB5E05"];
  // 🔴 12 EYLÜL · KAPSAM TURU — SEKİZ EKRAN DEĞİL, HEPSİ.
  // Bu liste elle seçilmiş SEKİZ ekrandı ve geri kalan 44'ü koyu temada
  // hiç render edilmiyordu. Daha kötüsü: AÇIK tema HİÇBİR ekranda
  // render edilmiyordu — `temaUygula("acik")` en sonda çağrılıyor ve
  // ondan sonra hiçbir şey çizilmiyordu. Yani "iki tema da çalışıyor"
  // iddiasının test tarafındaki karşılığı yoktu.
  // 🆕 SINIF: "BİR KAPSAMI 'TEMSİLİ ÖRNEKLE' DARALTTIĞINDA, ÖRNEĞE
  // GİRMEYEN HER ŞEY TEST EDİLMİŞ GİBİ GÖRÜNÜR — TEMSİL, KAPSAM DEĞİLDİR."
  const KOYU_VAKA = CASES;

  tema.temaUygula("koyu");
  if (tema.temaModu() !== "koyu") throw new Error("temaUygula çağrıldı ama TEMA_MOD değişmedi");
  // `S` ve `st` gerçekten tazelendi mi? (kaynak değil, DEĞER kontrolü)
  const S = require(path.join(APP, "src", "ortak.js")).S;
  if (String(S.card.backgroundColor).toUpperCase() !== tema.KOYU.surface.toUpperCase()) {
    koyuBad.push(["ortak.js S", "S.card zemini koyu palete geçmedi: " + S.card.backgroundColor]);
  }

  for (const [name, Comp, props, bekle] of KOYU_VAKA) {
    try {
      let tree;
      await renderer.act(async () => {
        tree = renderer.create(React.createElement(Comp, props));
        for (let k = 0; k < 6; k++) await Promise.resolve();
        await new Promise((r) => setTimeout(r, 0));
      });
      if (REACT_HATA.length) {
        const kim = REACT_HATA.splice(0).join(", ");
        throw new Error("KOYU TEMADA ÇÖKTÜ: <" + kim + ">");
      }
      const { hepsi, zemin } = renkleriTopla(tree.root);
      const renkler = hepsi;
      await renderer.act(async () => tree.unmount());
      const koyuVar = KOYU_IM.some(c => hepsi.has(c));
      const acikSizan = ACIK_IM.filter(c => zemin.has(c));
      if (!koyuVar && hepsi.size > 0) {
        throw new Error("koyu palet ağaçta hiç görünmüyor (" + hepsi.size + " renk çizildi)");
      }
      if (acikSizan.length) {
        throw new Error("AÇIK tema yüzeyi koyu temada sızdı: " + acikSizan.join(" · "));
      }
      koyuOk++;
      console.log(`  ✓ [koyu] ${name}${renkler.size === 0 ? "  (boş render)" : "  " + renkler.size + " renk"}`);
    } catch (e) {
      const msg = String(e && e.message).split("\n")[0].slice(0, 110);
      koyuBad.push([name + " [koyu]", msg]);
      console.log(`  ✗ [koyu] ${name}`);
      console.log(`      ${msg}`);
    }
  }
  tema.temaUygula("acik");
  // Geri dönüş de bir iddia: tek yönlü çalışan bir anahtar, anahtar değildir.
  if (String(S.card.backgroundColor).toUpperCase() !== "#FFFDF9") {
    koyuBad.push(["ortak.js S", "açık temaya dönünce S.card geri gelmedi: " + S.card.backgroundColor]);
    console.log("  ✗ [koyu→açık] S.card geri dönmedi: " + S.card.backgroundColor);
  }

  // ── AÇIK TEMA GEÇİŞİ — simetrik ve tam ────────────────────────────
  // Ayarlar'da tema anahtarı var; kullanıcı açık temaya geçebiliyor.
  // O yolda hiçbir ekran hiç render edilmemişti.
  console.log("");
  for (const [name, Comp, props] of CASES) {
    try {
      let tree;
      await renderer.act(async () => {
        tree = renderer.create(React.createElement(Comp, props));
        for (let k = 0; k < 6; k++) await Promise.resolve();
        await new Promise((r) => setTimeout(r, 0));
      });
      if (REACT_HATA.length) {
        const kim = REACT_HATA.splice(0).join(", ");
        throw new Error("AÇIK TEMADA ÇÖKTÜ: <" + kim + ">");
      }
      const { hepsi, zemin } = renkleriTopla(tree.root);
      await renderer.act(async () => tree.unmount());
      const koyuSizan = KOYU_IM.filter(c => zemin.has(c));
      if (koyuSizan.length) {
        throw new Error("KOYU tema yüzeyi açık temada sızdı: " + koyuSizan.join(" · "));
      }
      acikOk++;
      console.log(`  ✓ [açık] ${name}${hepsi.size === 0 ? "  (boş render)" : "  " + hepsi.size + " renk"}`);
    } catch (e) {
      const msg = String(e && e.message).split("\n")[0].slice(0, 110);
      koyuBad.push([name + " [açık]", msg]);
      console.log(`  ✗ [açık] ${name}`);
      console.log(`      ${msg}`);
    }
  }
} catch (e) {
  koyuBad.push(["koyu tema", String(e && e.message).slice(0, 110)]);
  console.log("  ✗ [koyu] kurulum: " + String(e && e.message).split("\n")[0].slice(0, 110));
}
console.log(`Koyu tema · ${koyuOk} ekran · Açık tema · ${acikOk} ekran · başarısız ${koyuBad.length}`);
bad.push(...koyuBad);

// ────────────────────────────────────────────────────────────────────────
// KABUK DENETİMİ — KAYNAK ÜZERİNDEN, ÇÜNKÜ RENDER TARAFI BUNU GÖREMİYOR
//
// 🔴 MUTASYON TESTİ BU KONTROLÜ DOĞURDU. Sekme kabuğundaki <Sayfa>'yı
// bilerek geri aldım ve test YEŞİL KALDI. Sebep: `Main` dışa aktarılmıyor,
// yani mount testi onu hiç render etmiyor. "kabuktan alan 3/3" satırı o
// hâliyle hiçbir şey kanıtlamıyordu — üç ekranın 0 atmosferi olduğunu
// söylüyordu ki kabuk boş olsa da doğru olurdu.
//
// 🆕 SINIF: "BİR TESTİN YEŞİLİ, ÖLÇTÜĞÜ ŞEYİ BOZDUĞUNDA KIRMIZIYA DÖNMÜYORSA
// ÖLÇÜM DEĞİL SÜSTÜR."
//
// Render edemediğim için KAYNAĞI ölçüyorum ve bunu böyle söylüyorum:
// bu satır "kabuk atmosferi çiziyor" demez, "kabuk <Sayfa> ile sarılmış"
// der. İkisi arasındaki farkı gizlemek, testin kendisini yalancı yapar.
let kabukOk = false, kabukNot = "";
try {
  const fs = require("fs");
  const kaynak = fs.readFileSync(path.join(__dirname, "..", "App.js"), "utf8");
  const i = kaynak.indexOf("function Main(");
  const govde = i < 0 ? "" : kaynak.slice(i, i + 60000);
  const r = govde.indexOf("\n  return (");
  // 🔴 PENCERE 400 KARAKTERDİ VE HEPSİ YORUMDU → süzgeçten boş çıktı,
  // test yine yanlış kırmızı verdi. Pencere, önündeki AÇIKLAMADAN uzun olmalı.
  const sonra = r < 0 ? "" : govde.slice(r + 11, r + 3000).trimStart();
  // yorum satırlarını atla, ilk gerçek etiketi bul
  // yorumlar satır satır atılır: tek bir "^(//...\n\s*)+" tekrarı, araya
  // giren boş satırda kopuyordu ve testin kendisi yanlış kırmızı verdi.
  const ilk = sonra.split("\n").map(s => s.trim())
    .filter(s => s && !s.startsWith("//")).join("\n").slice(0, 12);
  kabukOk = ilk.startsWith("<Sayfa");
  kabukNot = kabukOk ? "" : ("ilk etiket: " + JSON.stringify(ilk));
} catch (e) { kabukNot = String(e.message).slice(0, 60); }
if (!kabukOk) {
  bad.push(["Main (sekme kabuğu)", "KÖKÜ <Sayfa> DEĞİL — üç sekme ekranı atmosfersiz kalır · " + kabukNot]);
  console.log("  ✗ Main (sekme kabuğu) — kökü <Sayfa> değil · " + kabukNot);
} else {
  console.log("  ✓ Main (sekme kabuğu) — kökü <Sayfa> (kaynak denetimi)");
}

const atmVar = atmosferSonuc.filter(([ad, n]) => n === 1 && ATMOSFER_BEKLENEN.has(ad)).length;
const kabuk = atmosferSonuc.filter(([ad, n]) => n === 0 && ATMOSFER_KABUKTAN.has(ad)).length;
const modalToplam = atmosferSonuc.reduce((a, [, , m]) => a + m, 0);
console.log(`\nAtmosfer · kendi taşıyan ${atmVar}/${ATMOSFER_BEKLENEN.size}`
  + ` · kabuktan alan ${kabuk}/${ATMOSFER_KABUKTAN.size}`
  + ` · modal içinde ${modalToplam} (ayrı pencere, doğru)`
  + ` · üst üste binen 0`);
if (bantSonuc) console.log(`Fotoğraflı bant · ${bantSonuc.bant} bant · ${bantSonuc.metin} Text düğümü (gölge katmanları dahil)`);
console.log(`İkon · 104 render boyunca tanımsız ad: ${IKON_UYARI.size}`);
if (IKON_UYARI.size) {
  for (const ad of IKON_UYARI) console.log(`  ✗ Ikon ad="${ad}" — ikon.js'te yok, boş kare çiziliyor`);
}
console.log(`Toplam ekran: ${CASES.length} · başarısız: ${bad.length}`);
if (bad.length) {
  console.log("\n🔴 Bu ekranlar CİHAZDA da çökerdi — metin denetimi bunu göremezdi.");
}
process.exit(bad.length || IKON_UYARI.size ? 1 : 0);
}

run();
