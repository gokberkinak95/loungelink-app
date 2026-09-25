// ============================================================
// LoungeLink · render_check/yoga_duzen.js
//
// NE YAPAR: react-test-renderer'ın ürettiği GERÇEK ağacı alır,
// React Native'in KENDİ düzen motoruna (Yoga) verir ve her düğümün
// gerçek genişliğini/yüksekliğini hesaplar. Metin düğümleri için
// ölçüm fonksiyonu GERÇEK ttf ilerleme genişliklerini kullanır.
//
// NEDEN VAR: bugüne kadar "taşma var mı?" sorusuna GÖZLE cevap
// veriyordum. Gözle 40 ekranda 900 etikete bakılmaz; nitekim
// bakmadım ve kullanıcı cihazda gördü. Bir kutunun içine bir metnin
// sığıp sığmadığı bir GÖRÜŞ değil, iki sayının karşılaştırmasıdır.
//
// ⚠️ NE DEĞİLDİR: bu bir cihaz değil. Yoga aynı motor, fontlar aynı
// dosyalar, ama iOS/Android metin çizicisinin kendi yuvarlamaları
// burada yok. Yani bu kapı "kesin doğru piksel" demiyor; "bu metin
// bu kutuya SIĞMIYOR" diyor — ve sığmama, yuvarlama hatasıyla
// açıklanamayacak kadar büyük olduğunda gerçektir. Eşik bu yüzden
// var (TOLERANS).
// ============================================================
const fs = require("fs");
const path = require("path");

const METRIK = JSON.parse(
  fs.readFileSync(path.join(__dirname, "font_metrik.json"), "utf8")
);

// typography.js'in KENDİ kuralı — burada kopyalanmıyor, aynen taşınıyor.
// (Değişirse ikisi ayrışır; o yüzden aşağıdaki test bunu doğruluyor.)
const SANS = {
  400: "PlusJakartaSans-Regular",
  500: "PlusJakartaSans-Medium",
  600: "PlusJakartaSans-SemiBold",
  700: "PlusJakartaSans-Bold",
};
function sansFor(weight) {
  const w =
    weight === "bold" ? 700 : weight === "normal" ? 400 : weight == null ? 400 : parseInt(weight, 10);
  if (!Number.isFinite(w)) return SANS[400];
  if (w >= 700) return SANS[700];
  if (w >= 600) return SANS[600];
  if (w >= 500) return SANS[500];
  return SANS[400];
}

// ── metin genişliği ─────────────────────────────────────────
// RN letterSpacing'i HER karakterden SONRA ekler (sondaki dahil).
// Kerning yok sayılıyor → ölçüm üst sınırdır (bkz. tasma_metrik.py).
const eksikAile = new Set();
function metinGenisligi(s, aile, punto, ls) {
  const f = METRIK[aile];
  if (!f) {
    eksikAile.add(aile);
    return s.length * punto * 0.6 + (ls || 0) * s.length;
  }
  let t = 0;
  for (const c of s) t += f.adv[c] != null ? f.adv[c] : f.notdef;
  return (t / f.upem) * punto + (ls || 0) * s.length;
}

function aileCoz(st) {
  if (st.fontFamily) return st.fontFamily;
  return sansFor(st.fontWeight);
}

// En uzun BÖLÜNEMEZ parça: satır kaydırma bunu daha fazla daraltamaz.
// numberOfLines===1 ise bölünemez parça metnin TAMAMIDIR.
function bolunemez(metin, tekSatir) {
  if (tekSatir) return [metin];
  // RN kelimeyi boşluk ve tire üzerinden kırar.
  return metin.split(/(?<=[\s /–—-])/).map((s) => s.trimEnd()).filter(Boolean);
}

// ── ağaç düzleştirme ────────────────────────────────────────
function stilDuz(s) {
  if (!s) return {};
  if (Array.isArray(s)) return s.reduce((a, x) => Object.assign(a, stilDuz(x)), {});
  return Object.assign({}, s);
}

function metinTopla(n) {
  if (n == null || n === false) return "";
  if (typeof n === "string") return n;
  if (typeof n === "number") return String(n);
  if (Array.isArray(n)) return n.map(metinTopla).join("");
  if (n.children) return metinTopla(n.children);
  return "";
}

// ── Yoga kurulumu ───────────────────────────────────────────
let Y = null, E = null;
async function yogaYukle() {
  if (Y) return;
  // 🔴 `import()` BABEL'DEN SAKLANIYOR. `runner.js` babel-register
  // kuruyor; babel bu ifadeyi `require()`a çevirirse yoga'nın ESM
  // grafiği CJS gibi yüklenmeye çalışılır ve "exports is not defined"
  // ile patlar. `new Function` gövdesi babel'in göremediği bir yer.
  const mod = await new Function('return import("yoga-layout")')();
  Y = mod.default;
  // 🔴 SABİTLER DÜZ İSİMLE GELMİYOR — `mod.FLEX_DIRECTION_ROW`
  // UNDEFINED. yoga-layout 3.x onları ENUM NESNESİ olarak veriyor:
  // `FlexDirection.Row`, `Edge.All`, `Align.Center`…
  //
  // İlk sürümde düz isimleri kullandım; hepsi `undefined` geldi,
  // `setFlexDirection(undefined)` sessizce yok sayıldı ve motor HER
  // SATIRI SÜTUN gibi dizdi. Yine de makul görünen sayılar üretti ve
  // ben o sayılardan sonuç çıkardım.
  //
  // 🆕 SINIF: "BİR ÖLÇÜM ALETİ, CEVABINI BİLDİĞİM BİR ŞEYLE
  // KALİBRE EDİLMEDEN OKUNAMAZ — BOZUK BİR ALET DE SAYI VERİR."
  E = {
    FLEX_DIRECTION_ROW: mod.FlexDirection.Row,
    FLEX_DIRECTION_ROW_REVERSE: mod.FlexDirection.RowReverse,
    FLEX_DIRECTION_COLUMN: mod.FlexDirection.Column,
    FLEX_DIRECTION_COLUMN_REVERSE: mod.FlexDirection.ColumnReverse,
    ALIGN_FLEX_START: mod.Align.FlexStart, ALIGN_FLEX_END: mod.Align.FlexEnd,
    ALIGN_CENTER: mod.Align.Center, ALIGN_STRETCH: mod.Align.Stretch,
    ALIGN_BASELINE: mod.Align.Baseline,
    JUSTIFY_FLEX_START: mod.Justify.FlexStart, JUSTIFY_FLEX_END: mod.Justify.FlexEnd,
    JUSTIFY_CENTER: mod.Justify.Center, JUSTIFY_SPACE_BETWEEN: mod.Justify.SpaceBetween,
    JUSTIFY_SPACE_AROUND: mod.Justify.SpaceAround, JUSTIFY_SPACE_EVENLY: mod.Justify.SpaceEvenly,
    EDGE_ALL: mod.Edge.All, EDGE_TOP: mod.Edge.Top, EDGE_BOTTOM: mod.Edge.Bottom,
    EDGE_LEFT: mod.Edge.Left, EDGE_RIGHT: mod.Edge.Right,
    GUTTER_ALL: mod.Gutter.All, GUTTER_COLUMN: mod.Gutter.Column, GUTTER_ROW: mod.Gutter.Row,
    DIRECTION_LTR: mod.Direction.LTR,
    MEASURE_MODE_UNDEFINED: mod.MeasureMode.Undefined,
    MEASURE_MODE_EXACTLY: mod.MeasureMode.Exactly,
    MEASURE_MODE_AT_MOST: mod.MeasureMode.AtMost,
    POSITION_TYPE_ABSOLUTE: mod.PositionType.Absolute,
    WRAP_WRAP: mod.Wrap.Wrap,
  };
  for (const [k, v] of Object.entries(E)) {
    if (v === undefined) throw new Error("yoga sabiti çözülemedi: " + k);
  }
}

const HIZALA = {
  "flex-start": () => E.ALIGN_FLEX_START,
  "flex-end": () => E.ALIGN_FLEX_END,
  center: () => E.ALIGN_CENTER,
  stretch: () => E.ALIGN_STRETCH,
  baseline: () => E.ALIGN_BASELINE,
};
const DAGIT = {
  "flex-start": () => E.JUSTIFY_FLEX_START,
  "flex-end": () => E.JUSTIFY_FLEX_END,
  center: () => E.JUSTIFY_CENTER,
  "space-between": () => E.JUSTIFY_SPACE_BETWEEN,
  "space-around": () => E.JUSTIFY_SPACE_AROUND,
  "space-evenly": () => E.JUSTIFY_SPACE_EVENLY,
};

function sayi(v) {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function stiliUygula(node, st) {
  const yon = st.flexDirection || "column";
  node.setFlexDirection(
    yon === "row" ? E.FLEX_DIRECTION_ROW
      : yon === "row-reverse" ? E.FLEX_DIRECTION_ROW_REVERSE
      : yon === "column-reverse" ? E.FLEX_DIRECTION_COLUMN_REVERSE
      : E.FLEX_DIRECTION_COLUMN
  );
  if (st.flexWrap === "wrap") node.setFlexWrap(E.WRAP_WRAP);

  if (sayi(st.flex) != null) {
    // RN: flex:N → grow N, shrink 1, basis 0
    node.setFlexGrow(st.flex > 0 ? st.flex : 0);
    node.setFlexShrink(st.flex > 0 ? 1 : st.flex < 0 ? 1 : 0);
    if (st.flex > 0) node.setFlexBasis(0);
  }
  if (sayi(st.flexGrow) != null) node.setFlexGrow(st.flexGrow);
  if (sayi(st.flexShrink) != null) node.setFlexShrink(st.flexShrink);
  if (sayi(st.flexBasis) != null) node.setFlexBasis(st.flexBasis);

  const boyut = (ad, set, setPct) => {
    const v = st[ad];
    if (typeof v === "number") set(v);
    else if (typeof v === "string" && v.endsWith("%")) setPct(parseFloat(v));
  };
  boyut("width", (v) => node.setWidth(v), (v) => node.setWidthPercent(v));
  boyut("height", (v) => node.setHeight(v), (v) => node.setHeightPercent(v));
  boyut("minWidth", (v) => node.setMinWidth(v), (v) => node.setMinWidthPercent(v));
  boyut("minHeight", (v) => node.setMinHeight(v), (v) => node.setMinHeightPercent(v));
  boyut("maxWidth", (v) => node.setMaxWidth(v), (v) => node.setMaxWidthPercent(v));
  boyut("maxHeight", (v) => node.setMaxHeight(v), (v) => node.setMaxHeightPercent(v));

  const KEN = {
    padding: [E.EDGE_ALL], paddingTop: [E.EDGE_TOP], paddingBottom: [E.EDGE_BOTTOM],
    paddingLeft: [E.EDGE_LEFT], paddingRight: [E.EDGE_RIGHT],
    paddingHorizontal: [E.EDGE_LEFT, E.EDGE_RIGHT],
    paddingVertical: [E.EDGE_TOP, E.EDGE_BOTTOM],
  };
  for (const [ad, kenarlar] of Object.entries(KEN)) {
    const v = sayi(st[ad]);
    if (v != null) for (const k of kenarlar) node.setPadding(k, v);
  }
  const MAR = {
    margin: [E.EDGE_ALL], marginTop: [E.EDGE_TOP], marginBottom: [E.EDGE_BOTTOM],
    marginLeft: [E.EDGE_LEFT], marginRight: [E.EDGE_RIGHT],
    marginHorizontal: [E.EDGE_LEFT, E.EDGE_RIGHT],
    marginVertical: [E.EDGE_TOP, E.EDGE_BOTTOM],
  };
  for (const [ad, kenarlar] of Object.entries(MAR)) {
    const v = st[ad];
    if (v === "auto") { for (const k of kenarlar) node.setMarginAuto(k); continue; }
    if (sayi(v) != null) for (const k of kenarlar) node.setMargin(k, v);
  }
  const bw = sayi(st.borderWidth);
  if (bw != null) node.setBorder(E.EDGE_ALL, bw);
  for (const [ad, k] of [["borderTopWidth", E.EDGE_TOP], ["borderBottomWidth", E.EDGE_BOTTOM],
                          ["borderLeftWidth", E.EDGE_LEFT], ["borderRightWidth", E.EDGE_RIGHT]]) {
    const v = sayi(st[ad]); if (v != null) node.setBorder(k, v);
  }

  if (st.alignItems && HIZALA[st.alignItems]) node.setAlignItems(HIZALA[st.alignItems]());
  if (st.alignSelf && HIZALA[st.alignSelf]) node.setAlignSelf(HIZALA[st.alignSelf]());
  if (st.alignContent && HIZALA[st.alignContent]) node.setAlignContent(HIZALA[st.alignContent]());
  if (st.justifyContent && DAGIT[st.justifyContent]) node.setJustifyContent(DAGIT[st.justifyContent]());

  const g = sayi(st.gap); if (g != null) node.setGap(E.GUTTER_ALL, g);
  const cg = sayi(st.columnGap); if (cg != null) node.setGap(E.GUTTER_COLUMN, cg);
  const rg = sayi(st.rowGap); if (rg != null) node.setGap(E.GUTTER_ROW, rg);

  if (st.position === "absolute") {
    node.setPositionType(E.POSITION_TYPE_ABSOLUTE);
    for (const [ad, k] of [["top", E.EDGE_TOP], ["bottom", E.EDGE_BOTTOM],
                            ["left", E.EDGE_LEFT], ["right", E.EDGE_RIGHT]]) {
      const v = st[ad];
      if (typeof v === "number") node.setPosition(k, v);
      else if (typeof v === "string" && v.endsWith("%")) node.setPositionPercent(k, parseFloat(v));
    }
  }
  const ar = sayi(st.aspectRatio); if (ar != null) node.setAspectRatio(ar);
}

// Metin düğümü mü? react-test-renderer host tipleri: "Text" | "View" | ...
function metinMi(tip) { return tip === "Text" || tip === "TextInput" || tip === "RCTText"; }

// ── ağaçtan Yoga ağacına ────────────────────────────────────
// dondur: her Text düğümü için { metin, punto, aile, ls, tekSatir, node,
//         kucult (adjustsFontSizeToFit), yol }
function agacKur(dugum, ebeveynYoga, metinler, yol, kalitim) {
  if (dugum == null || typeof dugum === "boolean") return;
  if (typeof dugum === "string" || typeof dugum === "number") return;
  if (Array.isArray(dugum)) {
    dugum.forEach((c, i) => agacKur(c, ebeveynYoga, metinler, yol, kalitim));
    return;
  }
  const tip = dugum.type;
  const props = dugum.props || {};
  const st = stilDuz(props.style);
  const y = Y.Node.create();
  stiliUygula(y, st);

  const yeniYol = yol + "/" + tip;

  if (metinMi(tip)) {
    // 🔴 `textTransform` ÖLÇÜMDEN ÖNCE UYGULANMALI.
    // İlk sürümde uygulamıyordum: "LoungePuan" 10 küçük harfle ölçülüp
    // sığıyor görünüyordu; ekranda ise "LOUNGEPUAN" çiziliyor ve BÜYÜK
    // HARFLER DAHA GENİŞ. Yani kapı, cihazda gözle görülen taşmayı
    // "sorun yok" diye geçiyordu.
    //
    // 🆕 SINIF: "BİR ÖLÇÜM KAPISI, ÖLÇTÜĞÜ ŞEYİN EKRANA GİDEN SON
    // HÂLİNİ ALMIYORSA, ÖLÇTÜĞÜNÜ SANDIĞI ŞEYİ HİÇ ÖLÇMEZ."
    //
    // ⚠️ Türkçe yerel: "i" → "İ" (İngilizce "I" değil). i18n.js'in
    // `BUYUK`u da tr-TR kullanıyor; ikisi ayrışırsa ölçüm kayar.
    const ham = metinTopla(dugum.children);
    const metin =
      st.textTransform === "uppercase" ? ham.toLocaleUpperCase("tr-TR")
      : st.textTransform === "lowercase" ? ham.toLocaleLowerCase("tr-TR")
      : st.textTransform === "capitalize"
        ? ham.replace(/(^|\s)(\S)/g, (_, a, b) => a + b.toLocaleUpperCase("tr-TR"))
      : ham;
    const punto = sayi(st.fontSize) != null ? st.fontSize : 14;
    const aile = aileCoz(st);
    const ls = sayi(st.letterSpacing) || 0;
    const nl = props.numberOfLines;
    const tekSatir = nl === 1;
    const parcalar = metin ? bolunemez(metin, tekSatir) : [];
    const gerekli = parcalar.length
      ? Math.max(...parcalar.map((p) => metinGenisligi(p, aile, punto, ls)))
      : 0;
    const satirY = sayi(st.lineHeight) != null ? st.lineHeight : Math.round(punto * 1.3);

    y.setMeasureFunc((genislik, wm) => {
      const tam = metin ? metinGenisligi(metin, aile, punto, ls) : 0;
      const kul = wm === E.MEASURE_MODE_UNDEFINED ? tam : Math.min(tam, genislik);
      const satir = tekSatir || !genislik || genislik <= 0
        ? 1
        : Math.max(1, Math.ceil(tam / Math.max(genislik, 1)));
      const nSatir = nl > 0 ? Math.min(satir, nl) : satir;
      return { width: Math.max(kul, 0), height: nSatir * satirY };
    });

    if (metin.trim()) {
      metinler.push({ metin, punto, aile, ls, tekSatir, gerekli, node: y,
                      kucult: !!props.adjustsFontSizeToFit, yol: yeniYol,
                      a11y: props.accessibilityLabel || null });
    }
    ebeveynYoga.insertChild(y, ebeveynYoga.getChildCount());
    return;
  }

  // Image / diğer yaprak: ölçüsü stilden gelir; çocuk yoksa ölçüm gerekmez
  ebeveynYoga.insertChild(y, ebeveynYoga.getChildCount());

  // 🔴 ScrollView/FlatList'in İÇERİK KABI AYRI BİR KUTUDUR.
  // `contentContainerStyle` çoğunlukla padding taşır; onu yok sayarsam
  // metnin kutusunu OLDUĞUNDAN GENİŞ ölçerim ve gerçek bir taşmayı
  // "sığıyor" diye geçerim. Kapının kendisi yanlış ölçerse, kapı değil
  // süs olur.
  let ana = y;
  if ((tip === "ScrollView" || tip === "FlatList") && props.contentContainerStyle) {
    const ic = Y.Node.create();
    stiliUygula(ic, stilDuz(props.contentContainerStyle));
    // dikey liste: içerik kabı genişlikte esner
    ic.setAlignSelf(E.ALIGN_STRETCH);
    y.insertChild(ic, 0);
    ana = ic;
  }

  const cocuklar = dugum.children;
  if (cocuklar) {
    (Array.isArray(cocuklar) ? cocuklar : [cocuklar]).forEach((c) =>
      agacKur(c, ana, metinler, yeniYol, kalitim)
    );
  }
}

function mutlakKonum(node) {
  let x = 0, n = node;
  while (n) { const l = n.getComputedLayout(); x += l.left; n = n.getParent && n.getParent(); }
  return x;
}

// ── ana giriş ───────────────────────────────────────────────
// json: tree.toJSON() · en: cihaz genişliği (pt) · boy: cihaz yüksekliği
async function olc(json, en = 390, boy = 844) {
  await yogaYukle();
  const kok = Y.Node.create();
  kok.setWidth(en);
  kok.setHeight(boy);
  const metinler = [];
  agacKur(json, kok, metinler, "", {});
  kok.calculateLayout(en, boy, E.DIRECTION_LTR);

  const bulgular = [];
  for (const m of metinler) {
    const l = m.node.getComputedLayout();
    const genislik = l.width;
    const p = m.node.getParent && m.node.getParent();
    const pl = p ? p.getComputedLayout() : null;
    // içerik genişliği = düğümün kendi genişliği (padding'i yok, Text'te
    // padding varsa Yoga zaten düşüyor)
    const fark = m.gerekli - genislik;
    bulgular.push({ ...m, genislik, fark, node: undefined });
  }
  kok.freeRecursive();
  return { bulgular, eksikAile: [...eksikAile] };
}

module.exports = { olc, metinGenisligi, sansFor, METRIK };
