#!/usr/bin/env node
/**
 * LoungeLink · render_check/giris_kapisi_test.js   (26 Ağustos 2026'da doğdu)
 *
 * ════════════════════════════════════════════════════════════════════
 * 🔴 NEDEN VAR — KAPSAMIN EN BÜYÜK DELİĞİ BURASIYDI
 * ════════════════════════════════════════════════════════════════════
 *
 * `mount_test.js` 25 ekran mount ediyor. Hiçbiri OTURUM AÇMADAN ÖNCEKİ
 * ekran değil: Splash, Onboarding, Auth(login), Auth(register).
 *
 * Yani kullanıcının GÖRDÜĞÜ İLK ÜÇ EKRAN hiç render edilmemişti — ve
 * ilk izlenimi belirleyen tam olarak orası.
 *
 * Ama bu dosya mount ile YETİNMİYOR. Mount "çökmüyor" der; oysa giriş
 * kapısındaki hatalar çökme değil SESSİZ YANLIŞ DAVRANIŞTIR:
 * düğmeye basılır, hiçbir şey olmaz. Onun için burada DOKUNUYORUZ:
 * ağaçtaki gerçek onPress'leri çağırıyor, sonra ekranın ne çizdiğine
 * bakıyoruz.
 *
 * 🆕 SINIF: "MOUNT ETMEK, EKRANIN ÇALIŞTIĞINI DEĞİL, AÇILDIĞINI
 * KANITLAR. KAPI EKRANLARINDA HATA AÇILMAMAK DEĞİL, BASINCA
 * OLMAMAKTIR."
 */
const path = require("path");
const React = require("react");
const Module = require("module");

const APP = require("./ll_paths").APP;
const babelRegister = require("@babel/register").default || require("@babel/register");
babelRegister({
  presets: [
    require.resolve("babel-preset-expo"),
    [require.resolve("@babel/preset-env"), { targets: { node: "current" }, modules: "commonjs" }],
  ],
  extensions: [".js", ".jsx"],
  only: [APP],
  cache: false,
});

// ---- Native taklitler (mount_test ile aynı sınırlar) ----
let ASYNC_STORE = {};
const STUBS = {
  "expo-constants": { default: { expoConfig: { extra: {}, version: "2.99.0" } } },
  // 🔴 ÜÇÜNCÜ KEZ AYNI EKSİK. `@expo/vector-icons` → `createIconSet`
  // içeride `Font.isLoaded(...)` çağırıyor; stub'da o anahtar yoksa
  // `undefined` dönüyor ve `<Icon>` ÇÖKÜYOR. Yani çalışan kod, EKSİK
  // TAKLİT yüzünden bozuk görünüyor.
  //
  // 🆕 SINIF: "BİR TAKLİDİ EKSİK BIRAKMAK, TESTİ ZAYIFLATMAZ —
  // YANLIŞ YERİ SUÇLAYAN BİR TEST ÜRETİR, Kİ O DAHA PAHALIDIR."
  "expo-font": {
    useFonts: () => [true, null], loadAsync: async () => {},
    isLoaded: () => true, isLoading: () => false, loadedNativeFonts: [],
  },
  "expo-notifications": {
    getPermissionsAsync: async () => ({ status: "granted" }),
    requestPermissionsAsync: async () => ({ status: "granted" }),
    getExpoPushTokenAsync: async () => ({ data: "ExponentPushToken[test]" }),
    setNotificationHandler: () => {}, AndroidImportance: { HIGH: 4 },
    addNotificationResponseReceivedListener: () => ({ remove() {} }),
    setNotificationChannelAsync: async () => {},
  },
  "expo-device": { isDevice: true, brand: "test", modelName: "test" },
  "expo-linking": { createURL: () => "loungelink://", addEventListener: () => ({ remove() {} }), getInitialURL: async () => null },
  "expo-image-picker": { launchImageLibraryAsync: async () => ({ canceled: true }) },
  "expo-clipboard": { setStringAsync: async () => {} },
  "expo-status-bar": { StatusBar: () => null },
  "expo-web-browser": { openAuthSessionAsync: async () => ({ type: "cancel" }), maybeCompleteAuthSession: () => {} },
  "expo-apple-authentication": {
    isAvailableAsync: async () => false,
    signInAsync: async () => ({ identityToken: "x" }),
    AppleAuthenticationScope: { FULL_NAME: 1, EMAIL: 2 },
  },
  "expo-crypto": { digestStringAsync: async () => "hash", CryptoDigestAlgorithm: { SHA256: "SHA-256" } },
  // 🔴 `__esModule: true` ŞART. Babel'in `_interopRequireDefault`u,
  // bayrağı olmayan bir CommonJS nesnesini `{ default: nesne }` diye
  // SARAR; App.js'teki `import AsyncStorage from ...` o zaman
  // `{default:{...}}` alır ve `AsyncStorage.getItem` UNDEFINED olur.
  // App.js'te çağrı `try/catch` içinde olduğu için hata YUTULUYOR ve
  // "ll_onb hep boş" gibi görünüyordu: test, uygulamada olmayan bir
  // kusur RAPOR ETTİ. (mount_test'in taklidinde de aynı eksik var ama
  // orada bu yol hiç çalışmıyor.)
  "@react-native-async-storage/async-storage": {
    __esModule: true,
    default: {
      getItem: async (k) => (k in ASYNC_STORE ? ASYNC_STORE[k] : null),
      setItem: async (k, v) => { ASYNC_STORE[k] = String(v); },
      removeItem: async (k) => { delete ASYNC_STORE[k]; },
    },
  },
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
    // 12 Eylül · akşam — ÜÇÜNCÜ TAKLİT, AYNI DERS. `FotoSahne` artık
    // `Animated.Image` çiziyor (kadraj animasyonu) ve `Value.interpolate`
    // çağırıyor; ikisi de burada yoktu. Bu dosyadaki taklit üçünün en
    // dar olanıydı — "bu testin ihtiyacı kadar" diye bırakmıştım ve
    // ürünün ihtiyacı değişince kırıldı.
    if (k === "Animated") return {
      View: h("View"), Text: h("Text"), Image: h("Image"), ScrollView: h("ScrollView"),
      timing: () => ({ start: (cb) => cb && cb() }),
      stagger: () => ({ start: (cb) => cb && cb() }),
      delay: () => ({ start: (cb) => cb && cb() }),
      sequence: () => ({ start: (cb) => cb && cb() }),
      parallel: () => ({ start: (cb) => cb && cb() }),
      loop: () => ({ start: () => {}, stop: () => {} }),
      event: () => () => {},
      Value: function () {
        this.setValue = () => {};
        this.interpolate = () => 0;
        this.addListener = () => "1";
        this.removeListener = () => {};
      },
    };
    if (k === "PanResponder") return { create: (cfg) => ({ panHandlers: {} }) };
    if (k === "Easing") return {
      linear: (x) => x, ease: (x) => x, cubic: (x) => x, quad: (x) => x,
      out: (f) => (f || ((x) => x)), in: (f) => (f || ((x) => x)),
      inOut: (f) => (f || ((x) => x)), bezier: () => ((x) => x), back: (x) => x,
    };
    if (k === "Appearance") return { getColorScheme: () => "light", addChangeListener: () => ({ remove() {} }) };
    if (k === "__esModule") return true;
    if (k === "default") return undefined;
    return h(String(k));
  },
});

// 🔴 İKON KÜTÜPHANESİ SINIRI — `mount_test.js` ile AYNI gerekçe.
// Bu dosya `@expo/vector-icons`u taklit etmiyordu; gerçek kütüphane
// koşuyor, `__DEV__` gibi Metro'nun enjekte ettiği küresellere uzanıyor
// ve `<Icon>` çöküyordu. Yani hata giriş akışında DEĞİL, harness'ta.
//
// Aynı hatayı bu projede DÖRDÜNCÜ kez yaşıyorum ve deseni artık
// yazıyorum: her test dosyası KENDİ taklit setini taşıyor, biri
// düzeltilince diğerleri geride kalıyor.
//
// 🆕 SINIF: "TAKLİT SETLERİ ÇOĞALDIKÇA, DÜZELTİLEN TAKLİT DEĞİL
// DÜZELTİLMEYEN TAKLİT BELİRLEYİCİ OLUR."
//
// Kaybedilen (glif gerçekten çiziliyor mu) sorusunun nöbetçisi ayrı:
// `ikon_check.py` haritadaki her adı Ionicons'un gerçek glyphmap'inde
// arıyor.
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
if (typeof global.__DEV__ === "undefined") global.__DEV__ = false;

const origResolve = Module._resolveFilename;
Module._resolveFilename = function (req, ...rest) {
  if (STUBS[req]) return "STUB:" + req;
  // Splash marka logosunu `require("./assets/icon.png")` ile ceker.
  // Metro bunu bir kaynak kimligine cevirir; Node .png'yi JS sanip
  // "Invalid or unexpected token" der. (runner.js'te ayni tuzak vardi.)
  if (/\.(png|jpe?g|gif|webp|svg|ttf|otf)$/i.test(req)) {
    return path.join(__dirname, "stub_asset.js");
  }
  return origResolve.call(this, req, ...rest);
};
const origLoad = Module._load;
Module._load = function (req, ...rest) {
  if (STUBS[req]) return STUBS[req];
  return origLoad.call(this, req, ...rest);
};

// ---- Supabase taklidi: ÇAĞRILARI KAYDEDER ----
// Bu dosyanın asıl ölçüm aleti bu: "kayıt ol"a basınca sunucuya NE
// gitti? Hiçbir şey gitmediyse düğme çalışmıyor demektir ve bunu
// yalnız çağrı kaydı gösterir.
const CAGRILAR = [];
let SIGNUP_SONUC = { data: { user: { id: "u1" }, session: { user: { id: "u1" } } }, error: null };
let SIGNIN_SONUC = { data: {}, error: null };
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
      rpc: (fn, args) => { CAGRILAR.push(["rpc:" + fn, args]); return Promise.resolve({ data: null, error: null }); },
      auth: {
        getSession: async () => ({ data: { session: null } }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
        signOut: async () => { CAGRILAR.push(["signOut", null]); return {}; },
        signUp: async (a) => { CAGRILAR.push(["signUp", a]); return SIGNUP_SONUC; },
        signInWithPassword: async (a) => { CAGRILAR.push(["signIn", a]); return SIGNIN_SONUC; },
        resetPasswordForEmail: async (e, o) => { CAGRILAR.push(["reset", e]); return { error: null }; },
        resend: async (a) => { CAGRILAR.push(["resend", a]); return { error: null }; },
      },
      channel: () => ({ on: () => ({ subscribe: () => ({}) }), subscribe: () => ({}) }),
      removeChannel: () => {},
    },
    logError: () => {}, setAppVersion: () => {},
    SUPABASE_URL: "https://test.supabase.co",
  },
};

const renderer = require("react-test-renderer");
const { D } = require("../src/i18n");
const A = require("../App.js");
const t = D.tr;

// ---- Ağaçta gezinme yardımcıları ----
//
// 🔴 İLK YAZIMDA BU BÖLÜM YANLIŞTI VE TESTİ YALANCI YAPTI.
// `tree.toJSON()` üzerinden metin okuyup onPress arıyordum. Ama bu
// dosyadaki RN taklidi bileşenleri `h(tag)` ile üretiyor ve
// `React.createElement(tag, null, children)` diyor — yani PROP'LARI
// DÜŞÜRÜYOR. Sonuç: çizilen JSON ağacında hiçbir düğümde `onPress`
// yok; test "hiçbir düğme bağlı değil" diye 19 kırmızı verdi.
//
// Uygulamada hata yoktu; ÖLÇÜM ALETİ BOZUKTU. Bu, bu projede
// defalarca yazdığım sınıfın bir örneği daha:
// 🆕 SINIF: "BİR ÖLÇÜM ALETİ, ÖLÇTÜĞÜ ŞEYİN SÖZLEŞMESİNİ BOZAN BİR
// TAKLİT ÜZERİNE KURULMUŞSA, ÖLÇTÜĞÜ TEK ŞEY KENDİSİDİR."
//
// Doğrusu: prop'lar `ReactTestInstance` üzerinde DURUYOR. Ağaçta
// instance'lar üzerinden geziyoruz.
function metinAl(inst) {
  if (inst == null) return "";
  if (typeof inst === "string" || typeof inst === "number") return String(inst);
  let out = "";
  const ch = inst.children;
  if (Array.isArray(ch)) for (const c of ch) out += " " + metinAl(c);
  return out;
}
// Ağaçtaki her `Ikon` bileşeninin `ad` prop'unu toplar. Onay kutusu
// gibi DURUM taşıyan ikonlarda testin tek dürüst ölçüsü budur.
function ikonAdlari(tree) {
  const out = [];
  // ⚠️ YALNIZ `children` — `props.children` DE gezilirse her düğüm iki
  // kez sayılır. İlk yazımda ikisini de gezdim ve sayaç 7 yerine 78
  // dedi: iddia (değişiyor mu) doğruydu ama SAYI yalandı. Doğru sonuç
  // veren yanlış ölçüm, yanlış sonuç veren ölçümden daha tehlikelidir —
  // çünkü kimse ona bakmaz.
  // ⚠️ `toJSON()` YETMEZ: o yalnız HOST bileşenlerini (View/Text) verir;
  // `Ikon` bir React bileşeni ve `ad` prop'u JSON'da hiç görünmez.
  // İlk iki denemem tam bu yüzden yanlış sayı verdi (78, sonra 0).
  // Doğru yer `tree.root`: orada bileşen ağacı, propslarıyla duruyor.
  //
  // 🆕 SINIF: "BİR AĞACI GEZERKEN HANGİ AĞACI GEZDİĞİNİ BİL — RENDER
  // ÇIKTISI İLE BİLEŞEN AĞACI AYNI ŞEY DEĞİLDİR VE BİRİNDE OLAN
  // ÖTEKİNDE YOKTUR."
  try {
    tree.root.findAll(n => n.props && typeof n.props.ad === "string", { deep: true })
      .forEach(n => out.push(n.props.ad));
  } catch (e) { /* ağaç sökülmüşse sessiz geç */ }
  return out;
}

function duzMetin(tree) {
  return metinAl(tree.root);
}
function basilabilirler(tree) {
  return tree.root.findAll(
    (n) => n.props && typeof n.props.onPress === "function", { deep: true });
}
function metneGoreBas(tree, arananParca) {
  if (!arananParca) return null;
  const hepsi = basilabilirler(tree);
  // EN İÇTEKİ eşleşme doğru düğmedir: dıştaki kapsayıcı da aynı metni
  // içerir ama onun onPress'i (varsa) başka bir işe bakar.
  let en = null, enKisa = Infinity;
  for (const d of hepsi) {
    const m = metinAl(d);
    if (m && m.indexOf(arananParca) >= 0 && m.length < enKisa) { en = d; enKisa = m.length; }
  }
  return en ? en.props.onPress : null;
}
// 🔴 ReactTestInstance REFERANSLARI YENIDEN RENDER'DA BAYATLAR.
// Ilk yazimda alanlari bir kez bulup saklamistim; ilk `setState`ten
// sonra "Unable to find node on an unmounted component" ile coktu.
function alanlar(tree) {
  return tree.root.findAll(
    (n) => n.props && typeof n.props.onChangeText === "function", { deep: true });
}
function alanaYaz(tree, i, deger) {
  const a = alanlar(tree);
  if (a.length > i) a[i].props.onChangeText(deger);
  return a.length;
}

const sonuc = [];
function ol(ad, kosul, aciklama) {
  sonuc.push([ad, !!kosul, aciklama || ""]);
}

async function bekle(fn) {
  await renderer.act(async () => {
    await fn();
    for (let k = 0; k < 8; k++) await Promise.resolve();
    await new Promise((r) => setTimeout(r, 0));
  });
}

async function calis() {
  console.log("=".repeat(70));
  console.log("GİRİŞ KAPISI TESTİ — splash · tanıtım · giriş · kayıt");
  console.log("=".repeat(70));

  // ══════════════════════════════════════════════════════════════
  // 1) SPLASH açılıyor mu, iki düğmesi de bir yere gidiyor mu
  // ══════════════════════════════════════════════════════════════
  {
    let gidilen = [];
    let tree;
    await bekle(async () => {
      tree = renderer.create(React.createElement(A.Splash, {
        t, lang: "tr", toggleLang: () => {}, go: (s) => gidilen.push(s),
      }));
    });
    const metin = duzMetin(tree);
    // 🔴 30 Ağu — test "LoungeLink" arıyordu; splash artık uygulamanın geri
    // kalanıyla aynı çizimi kullanıyor: "LOUNGELINK" (büyük harf, harf
    // aralıklı). Marka ÇİZİLİYOR, sadece doğru şekilde. Test büyük/küçük
    // harfe duyarsız hâle getirildi ki bir daha marka BİÇİMİ değişince
    // "marka yok" demesin — asıl sorduğu şey markanın VARLIĞI.
    ol("splash render", metin.toLowerCase().indexOf("loungelink") >= 0, "marka adı çizildi");
    ol("splash · TR metni", metin.indexOf(t.start) >= 0, "'" + t.start + "' düğmesi var");

    // "Başla" → tanıtım (ll_onb yok)
    ASYNC_STORE = {};
    const basla = metneGoreBas(tree, t.start);
    ol("splash · Başla düğmesi bağlı", typeof basla === "function");
    if (basla) await bekle(async () => { await basla(); });
    ol("splash · Başla → tanıtım", gidilen[gidilen.length - 1] === "onboarding",
      "gidilen: " + JSON.stringify(gidilen));

    // "Başla" ikinci kez (tanıtım görülmüş) → kayıt
    ASYNC_STORE = { ll_onb: "1" };
    if (basla) await bekle(async () => { await basla(); });
    ol("splash · tanıtım görülmüşse → kayıt", gidilen[gidilen.length - 1] === "register",
      "gidilen: " + JSON.stringify(gidilen));

    const giris = metneGoreBas(tree, t.haveAcc);
    ol("splash · 'hesabım var' bağlı", typeof giris === "function");
    if (giris) await bekle(async () => { await giris(); });
    ol("splash · 'hesabım var' → giriş", gidilen[gidilen.length - 1] === "login");

    await bekle(async () => tree.unmount());
  }

  // ══════════════════════════════════════════════════════════════
  // 2) TANITIM — her adım FARKLI bir şey göstermeli ve BİTMELİ
  //    (v2.50/v2.65/v2.66'da üç kez kırılan yer tam burasıydı)
  // ══════════════════════════════════════════════════════════════
  {
    let bitti = false;
    let tree;
    await bekle(async () => {
      tree = renderer.create(React.createElement(A.Onboarding, { t, onDone: () => { bitti = true; } }));
    });
    const gorulen = [];
    const adet = (t.onbSlides || []).length;
    ol("tanıtım · slayt var", adet > 0, adet + " slayt");

    for (let i = 0; i < adet + 2; i++) {
      const m = duzMetin(tree);
      gorulen.push(m.slice(0, 400));
      const ileri = metneGoreBas(tree, i < adet - 1 ? t.onbNext : t.onbStart);
      if (!ileri) break;
      await bekle(async () => { await ileri(); });
      if (bitti) break;
    }
    const benzersiz = new Set(gorulen);
    ol("tanıtım · adımlar birbirinden farklı", benzersiz.size === gorulen.length,
      gorulen.length + " adım, " + benzersiz.size + " farklı");
    ol("tanıtım · sonunda BİTİYOR", bitti, "onDone çağrıldı mı");
    await bekle(async () => tree.unmount());
  }

  // ══════════════════════════════════════════════════════════════
  // 3) GİRİŞ — boş formla basınca ne oluyor, hata görünüyor mu
  // ══════════════════════════════════════════════════════════════
  {
    CAGRILAR.length = 0;
    let tree;
    await bekle(async () => {
      tree = renderer.create(React.createElement(A.Auth, {
        mode: "login", t, lang: "tr", toggleLang: () => {}, go: () => {},
      }));
    });
    const m0 = duzMetin(tree);
    ol("giriş · render", m0.indexOf(t.doLogin) >= 0);
    ol("giriş · sosyal düğmeler", m0.indexOf(t.continueWithGoogle) >= 0);
    ol("giriş · şifremi unuttum var", m0.indexOf(t.forgotLink) >= 0);
    // 4 Eylül — tasarım 16: girişte "Hesabın yok mu?" satırı yok; kayıt yolu
    // karşılama ekranındaki "Başla". Burada YOKLUĞU doğrulanır.
    ol("giriş · kayıt bağlantısı yok (tasarım 16)", m0.indexOf(t.register) < 0);

    // BOŞ formla "Giriş yap"
    const gir = metneGoreBas(tree, t.doLogin);
    if (gir) await bekle(async () => { await gir(); });
    const bosCagri = CAGRILAR.filter(c => c[0] === "signIn");
    const m1 = duzMetin(tree);
    // 🔴 Boş e-posta/şifreyle sunucuya gitmek: gereksiz istek + ham hata
    ol("giriş · boş form sunucuya GİTMEMELİ", bosCagri.length === 0,
      bosCagri.length + " kez signIn çağrıldı");
    ol("giriş · boş formda kullanıcıya bir şey söylenmeli",
      m1.indexOf(t.errFill) >= 0 || m1.indexOf(t.emailInvalid) >= 0,
      "ekranda hata metni var mı");

    await bekle(async () => tree.unmount());
  }

  // ══════════════════════════════════════════════════════════════
  // 4) KAYIT — sihirbazı UÇTAN UCA yürü
  // ══════════════════════════════════════════════════════════════
  {
    CAGRILAR.length = 0;
    let tree;
    await bekle(async () => {
      tree = renderer.create(React.createElement(A.Auth, {
        mode: "register", t, lang: "tr", toggleLang: () => {}, go: () => {},
      }));
    });

    // --- ADIM 1: eksik formla "İleri" ---
    const ileri1 = metneGoreBas(tree, t.next);
    ol("kayıt · adım 1 'İleri' bağlı", typeof ileri1 === "function");
    if (ileri1) await bekle(async () => { await ileri1(); });
    const m1 = duzMetin(tree);
    ol("kayıt · boş formda hata GÖRÜNÜYOR", m1.indexOf(t.errFill) >= 0,
      "'" + t.errFill + "' ekranda mı");
    ol("kayıt · boş formda adım 2'ye GEÇMEMELİ", m1.indexOf(t.roleHost) < 0);

    // --- alanları doldur ---
    const alanSayisi = alanlar(tree).length;
    ol("kayıt · adım 1 alan sayısı", alanSayisi >= 4, alanSayisi + " metin alanı");
    await bekle(async () => { alanaYaz(tree, 0, "Gökberk"); });
    await bekle(async () => { alanaYaz(tree, 1, "g@example.com"); });
    await bekle(async () => { alanaYaz(tree, 2, "+905551112233"); });
    await bekle(async () => { alanaYaz(tree, 3, "1234567"); });   // 7 hane — KISA
    const ileri1b = metneGoreBas(tree, t.next);
    if (ileri1b) await bekle(async () => { await ileri1b(); });
    const m1b = duzMetin(tree);
    ol("kayıt · kısa şifrede uyarı GÖRÜNÜYOR", m1b.indexOf(t.pwMin) >= 0,
      "'" + t.pwMin + "' ekranda mı");

    // düzgün şifre
    await bekle(async () => { alanaYaz(tree, 3, "Sifre12345"); });
    const ileri1c = metneGoreBas(tree, t.next);
    if (ileri1c) await bekle(async () => { await ileri1c(); });
    const m2 = duzMetin(tree);
    ol("kayıt · adım 2'ye geçildi", m2.indexOf(t.roleHost) >= 0);

    // --- ADIM 2: rol seç ---
    const rolSec = metneGoreBas(tree, t.roleGuest);
    ol("kayıt · rol kartı basılabilir", typeof rolSec === "function");
    if (rolSec) await bekle(async () => { await rolSec(); });
    const ileri2 = metneGoreBas(tree, t.next);
    if (ileri2) await bekle(async () => { await ileri2(); });
    const m3 = duzMetin(tree);
    ol("kayıt · adım 3'e geçildi", m3.indexOf(t.consentAll) >= 0);

    // --- ADIM 3: "TÜMÜNÜ KABUL ET" ---
    // 🔴 BU TESTİN ASIL SEBEBİ. Tümünü kabul kutucuğu, ekranda duran
    // TÜM onay kutularını işaretlemeli. Biri işaretsiz kalıyorsa hem
    // kullanıcı hem hukuk yanlış bilgilendirilmiş olur.
    const hepsi = metneGoreBas(tree, t.consentAll);
    ol("kayıt · 'tümünü kabul et' bağlı", typeof hepsi === "function");
    if (hepsi) await bekle(async () => { await hepsi(); });
    // 🔴 30 AĞUSTOS · 3. TUR — ONAY KUTULARI ARTIK KARAKTER DEĞİL İKON.
    // Bu test `☑`/`☐` karakterlerini SAYIYORDU ve o karakterler
    // vektöre çevrildiğinde test sessizce değil GÜRÜLTÜYLE kırıldı —
    // "önce 0 işaretli, sonra 0". Doğru davranış buydu: testin
    // ölçtüğü şey (kutu gerçekten değişiyor mu) hâlâ ölçülmeli,
    // yalnız ÖLÇÜ ARACI değişmeli.
    //
    // 🆕 SINIF: "BİR TESTİ ARAYÜZÜN GÖRÜNEN KARAKTERİNE BAĞLARSAN,
    // ARAYÜZ GÜZELLEŞTİĞİNDE TEST KIRILIR — DAVRANIŞA BAĞLA, ÇİZİME
    // DEĞİL."
    //
    // Artık ikonun ADI sayılıyor: `kutuDolu` / `kutuBos`.
    const m4 = ikonAdlari(tree);
    const isaretli = m4.filter(a => a === "kutuDolu").length;
    const isaretsiz = m4.filter(a => a === "kutuBos").length;
    const kutuSayisi = 6;   // c1..c5 + c6Age
    ol("kayıt · tümünü kabul → HİÇ boş kutu kalmamalı", isaretsiz === 0,
      isaretli + " işaretli, " + isaretsiz + " işaretsiz (beklenen: " + (kutuSayisi + 1) + " / 0)");

    // 18+ kutusunu tek tek kapatıp açabiliyor muyuz?
    const yasKutusu = metneGoreBas(tree, String(t.c6Age || "").slice(0, 24));
    ol("kayıt · 18+ kutusu basılabilir", typeof yasKutusu === "function");
    if (yasKutusu) {
      const once = ikonAdlari(tree).filter(a => a === "kutuDolu").length;
      await bekle(async () => { await yasKutusu(); });
      const sonra = ikonAdlari(tree).filter(a => a === "kutuDolu").length;
      ol("kayıt · 18+ kutusu GERÇEKTEN değişiyor", once !== sonra,
        "önce " + once + " işaretli, sonra " + sonra);
      await bekle(async () => { await yasKutusu(); });   // geri aç
    }

    // --- KAYIT OL ---
    CAGRILAR.length = 0;
    const kaydol = metneGoreBas(tree, t.register);
    ol("kayıt · 'Kayıt ol' bağlı", typeof kaydol === "function");
    if (kaydol) await bekle(async () => { await kaydol(); });
    const signUp = CAGRILAR.find(c => c[0] === "signUp");
    ol("kayıt · signUp çağrıldı", !!signUp);
    if (signUp) {
      const d = (signUp[1] && signUp[1].options && signUp[1].options.data) || {};
      ol("kayıt · ad sunucuya gitti", d.name === "Gökberk", JSON.stringify(d));
      ol("kayıt · rol sunucuya gitti", d.role === "guest");
      ol("kayıt · telefon sunucuya gitti", !!d.phone, "phone=" + d.phone);
    }
    // Telefon: kayıtta soruluyorsa BİR YERE yazılmalı.
    const tel = CAGRILAR.find(c => c[0] === "rpc:declare_phone");
    ol("kayıt · telefon SUNUCUYA YAZILDI (declare_phone)", !!tel,
      tel ? JSON.stringify(tel[1]) : "çağrılmadı — sorulan numara kayboluyor");
    const onay = CAGRILAR.find(c => c[0] === "rpc:grant_consents");
    ol("kayıt · onaylar kaydedildi (grant_consents)", !!onay);
    if (onay) {
      const tipler = (onay[1] && onay[1].p_types) || [];
      ol("kayıt · 18+ onayı kayda gitti", tipler.indexOf("age_18") >= 0, JSON.stringify(tipler));
    }

    await bekle(async () => tree.unmount());
  }

  // ══════════════════════════════════════════════════════════════
  // 5) KAYIT · E-POSTA DOĞRULAMASI AÇIKSA (Supabase varsayılanı)
  //    signUp oturum DÖNDÜRMEZ. Ekran ne yapıyor?
  // ══════════════════════════════════════════════════════════════
  {
    SIGNUP_SONUC = { data: { user: { id: "u1" }, session: null }, error: null };
    CAGRILAR.length = 0;
    let tree;
    await bekle(async () => {
      tree = renderer.create(React.createElement(A.Auth, {
        mode: "register", t, lang: "tr", toggleLang: () => {}, go: () => {},
      }));
    });
    await bekle(async () => { alanaYaz(tree, 0, "Gökberk"); });
    await bekle(async () => { alanaYaz(tree, 1, "g@example.com"); });
    await bekle(async () => { alanaYaz(tree, 3, "Sifre12345"); });
    let b = metneGoreBas(tree, t.next); if (b) await bekle(async () => { await b(); });
    b = metneGoreBas(tree, t.roleGuest); if (b) await bekle(async () => { await b(); });
    b = metneGoreBas(tree, t.next); if (b) await bekle(async () => { await b(); });
    b = metneGoreBas(tree, t.consentAll); if (b) await bekle(async () => { await b(); });
    b = metneGoreBas(tree, t.register); if (b) await bekle(async () => { await b(); });

    const son = duzMetin(tree);
    // 🔴 Oturum yoksa `onAuthStateChange` HİÇ tetiklenmez. Ekran hâlâ
    // kayıt formundaysa ve kullanıcıya hiçbir şey söylemiyorsa, kayıt
    // BAŞARILI olmasına rağmen kullanıcı dönen bir çarkta kalır.
    const bilgiVar = son.indexOf(t.verifySentTitle || "@@yok@@") >= 0;
    ol("kayıt · doğrulama e-postası varsa kullanıcıya SÖYLENİYOR", bilgiVar,
      bilgiVar ? "" : "ekranda doğrulama bilgisi yok — kullanıcı dönen çarkta kalıyor");
    await bekle(async () => tree.unmount());
    SIGNUP_SONUC = { data: { user: { id: "u1" }, session: { user: { id: "u1" } } }, error: null };
  }

  // ---- RAPOR ----
  console.log("");
  let ok = 0;
  for (const [ad, gecti, not] of sonuc) {
    console.log(`  ${gecti ? "✓" : "✗"} ${ad}${not ? "  — " + not : ""}`);
    if (gecti) ok++;
  }
  console.log("");
  console.log(`${ok}/${sonuc.length} kontrol geçti`);
  if (ok < sonuc.length) {
    console.log("");
    console.log("KIRMIZI OLANLAR — kullanıcının GÖRDÜĞÜ İLK EKRANLARDA:");
    for (const [ad, gecti, not] of sonuc) if (!gecti) console.log(`   ✗ ${ad} — ${not}`);
    process.exit(1);
  }
}

process.on("unhandledRejection", (e) => { console.log("  ! yakalanmamış: " + String(e && e.message).slice(0, 90)); });
calis().catch((e) => { console.log("HARNESS ÇÖKTÜ: " + (e && e.stack)); process.exit(1); });
