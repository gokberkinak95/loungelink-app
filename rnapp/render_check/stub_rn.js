// react-native'in başsız (headless) taklidi. Amaç: LoungeLink ekranlarını
// gerçekten MOUNT edip render ağacını gezmek. Bileşenler basit "host" öğeleri
// olarak döner; react-test-renderer bunları ağaçta düğüm olarak gösterir.
const React = require("react");

const host = (name) => {
  const C = ({ children, ...props }) => React.createElement(name, props, children);
  C.displayName = name;
  return C;
};

const View = host("View");
const Text = host("Text");
const TextInput = host("TextInput");
const Image = host("Image");
const ScrollView = host("ScrollView");
const ActivityIndicator = host("ActivityIndicator");
const Switch = host("Switch");
const Modal = ({ visible = true, children, ...p }) =>
  visible ? React.createElement("Modal", p, children) : null;

// TouchableOpacity: onPress'i çağırabilmek için props'u ağaçta tutuyoruz
const TouchableOpacity = ({ children, ...props }) =>
  React.createElement("TouchableOpacity", props, children);
const Pressable = TouchableOpacity;

const FlatList = ({ data = [], renderItem, ListEmptyComponent, keyExtractor, ...p }) =>
  React.createElement("FlatList", p,
    (data && data.length)
      ? data.map((item, index) => React.createElement(
          "Row", { key: keyExtractor ? keyExtractor(item, index) : index }, renderItem({ item, index })))
      : (typeof ListEmptyComponent === "function" ? React.createElement(ListEmptyComponent) : ListEmptyComponent || null));

const KeyboardAvoidingView = ({ children, ...p }) => React.createElement("KAV", p, children);
const SafeAreaView = ({ children, ...p }) => React.createElement("SafeArea", p, children);

const Easing = {
  // 🔴 v2.52 — Easing stub'da YOKTU; MomentScreen'in Easing.out(Easing.cubic)
  // çağrısı render testinde çöktü. Stub'ın eksikliği ürün hatası gibi
  // görünür — doğrusu stub'ı gerçeğe yaklaştırmaktır. Test animasyonun
  // eğrisini değil, çağrılabilirliğini doğrular.
  linear: (x) => x, ease: (x) => x, quad: (x) => x, cubic: (x) => x,
  out: (fn) => (fn || ((x) => x)), in: (fn) => (fn || ((x) => x)),
  inOut: (fn) => (fn || ((x) => x)), bezier: () => ((x) => x),
};

module.exports = {
  Easing,
  View, Text, TextInput, Image, ScrollView, ActivityIndicator, Switch, Modal,
  TouchableOpacity, Pressable, FlatList, KeyboardAvoidingView, SafeAreaView,
  StyleSheet: { create: (o) => o, flatten: (o) => o, hairlineWidth: 1, absoluteFill: {} },
  Platform: { OS: "android", select: (o) => (o.android !== undefined ? o.android : o.default) },
  Dimensions: { get: () => ({ width: 390, height: 844 }) },
  BackHandler: { addEventListener: () => ({ remove() {} }), removeEventListener: () => {} },
  AppState: { addEventListener: () => ({ remove() {} }), currentState: "active" },
  Linking: { openURL: async () => true, canOpenURL: async () => true },
  Share: { share: async () => ({ action: "sharedAction" }) },
  Alert: { alert: () => {} },
  Clipboard: { setString: () => {} },
  Keyboard: { dismiss: () => {} },
  RefreshControl: host("RefreshControl"),
  StatusBar: { currentHeight: 24, setBarStyle: () => {} },
  // 🔴 v3.4 — `NativeModules` STUB'DA YOKTU VE BU BİR ÜRÜN HATASI GİBİ
  // GÖRÜNDÜ. İkon katmanını (`@expo/vector-icons`) bağladığımda render
  // testleri şu satırda çöktü:
  //     NativeModules.RNVectorIconsManager   → "Cannot read ... of undefined"
  // Gerçek cihazda `NativeModules` VAR ve o alan yalnız `undefined`;
  // yani kod doğru, EKSİK OLAN TAKLİTTİ. Stub'ı gerçeğe yaklaştırmak,
  // testi ürünün etrafından dolaştırmaktan her zaman iyidir.
  //
  // 🆕 SINIF: "TAKLİT EKSİKSE TEST ÜRÜNÜ SUÇLAR — VE O SUÇLAMAYA
  // İNANIRSAN, ÇALIŞAN KODU 'DÜZELTMEYE' BAŞLARSIN."
  NativeModules: {},
  requireNativeComponent: (ad) => host(ad),
  UIManager: { getViewManagerConfig: () => null },
  processColor: (c) => c,
  I18nManager: { isRTL: false },
  // v2.52: Animated stub'ı gerçek API yüzeyine yaklaştırıldı — sequence,
  // parallel, spring ve stop() eksikti; her yeni animasyon kullanımında
  // testin çökmesi ürün hatası sanılıyordu.
  // 🔴 12 EYLÜL — `event` ve `ScrollView` EKSİKTİ VE TEST BUNU "ÜRÜN
  // ÇÖKTÜ" DİYE RAPORLADI. Daralan bant `Animated.event` + `Animated.
  // ScrollView` kullanıyor; ikisi de stub'da yoktu, Keşfet açılamadı.
  // Stub'ın işi gerçek yüzeyi TAKLİT etmek; eksik bir yüzey, olmayan
  // bir ürün hatası üretir.
  // 🆕 SINIF: "BİR SAHTE NESNE GERÇEĞİNİN YÜZEYİNİ TAM KAPSAMIYORSA,
  // TESTİN BULDUĞU HATA ÜRÜNÜN DEĞİL SAHTENİN HATASIDIR."
  // 12 Eylül · 3. tur — tanıtım kaydırmayla geçiyor (`PanResponder`).
  PanResponder: { create: () => ({ panHandlers: {} }) },
  Animated: {
    View: host("AnimatedView"), Text: host("AnimatedText"), Image: host("AnimatedImage"),
    ScrollView: host("AnimatedScrollView"),
    event: () => () => {},
    Value: function () { return { setValue() {}, interpolate: () => 0 }; },
    timing: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
    spring: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
    sequence: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
    parallel: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
    loop: () => ({ start: () => {}, stop: () => {} }),
    stagger: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
    delay: () => ({ start: (cb) => cb && cb({ finished: true }), stop: () => {} }),
  },
  // (Easing yukarıda tanımlı — burada İKİNCİ kez tanımlıydı ve
  //  eksik sürüm sessizce kazanıyordu; i18n mükerrer anahtar hatasının
  //  bu dosyadaki kardeşi.)
};
