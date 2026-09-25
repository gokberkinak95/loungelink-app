// LoungeLink · import/export denetimi
// Metro "Unknown error" verdiginde sebep genelde eksik import olur; bu betik onu yakalar.

// ============================================================
// hooksAfterReturnCheck — ERKEN RETURN'DEN SONRA HOOK
// React kurali: hook'lar her render'da AYNI SIRADA calismali. Bir hook
// `if (...) return <X/>` satirindan SONRA yazilirsa, ilk render'da hic
// calismaz, kosul degisince calisir -> "Rendered more hooks than during
// the previous render" -> BEYAZ EKRAN.
// PublicProfile'da tam olarak bu oldu (profil resmine tiklayinca cokme).
// Sozdizimi ve i18n denetimleri bunu goremez; bu yuzden ayri kontrol.
// ============================================================
function hooksAfterReturnCheck(files) {
  // YALNIZ BILESEN SEVIYESI (tam 2 bosluk girinti). Ic ice fonksiyonlardaki
  // `if (error) return ...` satirlari bileşenin erken return'u DEGILDIR —
  // ilk surumde bu yanlis pozitif veriyordu.
  const HOOK = /^ {2}(const|let)\s*\[?[^=]*\]?\s*=\s*(useState|useReducer|useRef|useMemo|useCallback)\s*\(/;
  const EARLY_RETURN = /^ {2}if\s*\(.*\)\s*return\s/;
  const FN_START = /^(export\s+)?function\s+[A-Z]\w*\s*\(|^\s*const\s+[A-Z]\w*\s*=\s*\(/;
  // 🔴 v2.97 — BILESEN OLMAYAN UST SEVIYE FONKSIYON DA DURUMU SIFIRLAMALI.
  // Olcum (screens.js bolunurken): `ReqStateBadge` (bilesen) ile
  // `useUnread` (kanca) arasina `abbrevName` (duz yardimci) dustu.
  // `abbrevName`in kendi `return`u bilesenin erken return'u sayildi ve
  // `useUnread`in kancalari o bilesene ait sanildi -> YANLIS ALARM.
  // Eskiden bu iki bildirim 12 bin satir ARAYDI, bu yuzden hic gorunmedi.
  // 🆕 SINIF: "IKI BILDIRIM ARASINDA BINLERCE SATIR VARKEN GORUNMEYEN BIR
  // KUSUR, YAN YANA GELDIKLERI GUN ORTAYA CIKAR — DOSYA BOLMEK BUNU YAPAR."
  // Cozum: KUCUK harfle baslayan ust seviye fonksiyonlar da izleyiciyi
  // sifirlar; onlar bilesen degildir, hook kurali onlara islemez.
  const FN_ANY = /^(export\s+)?(async\s+)?function\s+\w+\s*\(|^(export\s+)?(const|let|var)\s+\w+\s*=\s*(async\s*)?\(/;
  let problems = 0;
  for (const f of files) {
    let src; try { src = fs.readFileSync(f, "utf8"); } catch { continue; }
    const lines = src.split("\n");
    let inComp = null, sawReturn = 0;
    for (let i = 0; i < lines.length; i++) {
      const L = lines[i];
      if (FN_START.test(L)) { inComp = L.trim().slice(0, 60); sawReturn = 0; continue; }
      // Bilesen OLMAYAN bir ust seviye bildirim: izlemeyi BIRAK.
      if (FN_ANY.test(L)) { inComp = null; sawReturn = 0; continue; }
      if (!inComp) continue;
      if (EARLY_RETURN.test(L)) { sawReturn = i + 1; continue; }
      if (sawReturn && HOOK.test(L)) {
        console.log(`  🔴 HOOK SIRASI: ${path.basename(f)}:${i + 1} — ` +
          `erken return (satir ${sawReturn}) SONRASINDA hook cagriliyor -> BEYAZ EKRAN riski`);
        console.log(`     bilesen: ${inComp}`);
        problems++;
        sawReturn = 0;
      }
    }
  }
  return problems;
}

// Kullanim: node check.js   (proje kokunde)
const fs = require("fs"), path = require("path");

const RN_COMPONENTS = ["View","Text","TextInput","TouchableOpacity","ScrollView","ActivityIndicator",
  "Modal","FlatList","Image","Switch","Pressable","KeyboardAvoidingView","SafeAreaView","StatusBar",
  "RefreshControl","SectionList","Button"];
const RN_NAMESPACES = ["Platform","Alert","Dimensions","StyleSheet","Linking","Keyboard","Animated","Share"];
const HOOKS = ["useState","useEffect","useCallback","useMemo","useRef","useContext","useReducer"];

function jsxRootCheck(file) {
  const src = fs.readFileSync(file, "utf8");
  const issues = [];
  let i = 0;
  const n = src.length;

  while (i < n) {
    // "return (" ara
    const idx = src.indexOf("return (", i);
    if (idx === -1) break;
    i = idx + 8;

    // parantez dengesini takip ederek return blogunun sonunu bul
    let depth = 1, j = i, inStr = null, tagDepth = 0, roots = 0, lastWasRoot = false;
    const startLine = src.slice(0, idx).split("\n").length;

    while (j < n && depth > 0) {
      const c = src[j], nx = src[j + 1];
      if (inStr) {
        if (c === "\\") { j += 2; continue; }
        if (c === inStr) inStr = null;
        j++; continue;
      }
      if (c === '"' || c === "'" || c === "`") { inStr = c; j++; continue; }
      if (c === "(") depth++;
      if (c === ")") { depth--; if (depth === 0) break; }

      // JSX etiketi
      if (c === "<" && /[A-Za-z/>]/.test(nx)) {
        const isClose = nx === "/";
        const isFrag = nx === ">";
        // etiketin sonunu bul
        let k = j + 1, s2 = null, selfClose = false, braceD = 0;
        while (k < n) {
          const d = src[k];
          if (s2) { if (d === "\\") { k += 2; continue; } if (d === s2) s2 = null; k++; continue; }
          if (d === '"' || d === "'") { s2 = d; k++; continue; }
          if (d === "{") braceD++;
          if (d === "}") braceD--;
          if (braceD === 0 && d === "/" && src[k + 1] === ">") { selfClose = true; k += 2; break; }
          if (braceD === 0 && d === ">") { k++; break; }
          k++;
        }
        if (tagDepth === 0 && !isClose) { roots++; }
        if (!isClose && !selfClose) tagDepth++;
        if (isClose) tagDepth--;
        j = k; continue;
      }
      j++;
    }
    if (roots > 1) {
      issues.push(`  ${file}: satir ~${startLine} return icinde ${roots} KOK JSX elemani -> "Adjacent JSX elements" hatasi verir`);
    }
    i = j;
  }
  return issues;
}




// Babel yoksa: JS nesnelerinde eksik virgul tespiti.
// Claude'un betikleri i18n gibi nesnelere blok eklerken onceki ozelligin
// virgulle bitip bitmedigine bakmiyordu -> "Unexpected token, expected ','"
function objectCommaCheck(file) {
  const src = fs.readFileSync(file, "utf8");
  const lines = src.split("\n");
  const issues = [];
  for (let i = 0; i < lines.length - 1; i++) {
    // Satir SONU yorumunu soy: theme.js'te `gold: "#B8943A",   // cGD` gibi
    // satirlar virgullu olmasina ragmen YANLIS ALARM veriyordu.
    const cur = lines[i].replace(/\s*\/\/[^"']*$/, "").trim();
    if (!cur || cur.startsWith("//") || cur.startsWith("/*") || cur.startsWith("*")) continue;
    // "anahtar: deger" gibi bir satir mi ve virgul/acilis olmadan mi bitiyor?
    if (!/^[\w$]+\s*:/.test(cur)) continue;
    if (/[,{[(]$/.test(cur)) continue;
    // sonraki ANLAMLI satiri bul
    let j = i + 1;
    while (j < lines.length) {
      const nx = lines[j].trim();
      if (!nx || nx.startsWith("//") || nx.startsWith("/*") || nx.startsWith("*")) { j++; continue; }
      break;
    }
    if (j >= lines.length) continue;
    const next = lines[j].trim();
    // sonraki satir yeni bir ozellik ise -> virgul SART
    if (/^[\w$]+\s*:/.test(next)) {
      issues.push(`  ${file}: satir ${i + 1} sonunda VIRGUL EKSIK -> "${cur.slice(0, 55)}"`);
    }
  }
  return issues;
}


// TANIMSIZ DEGISKEN TESPITI (babel scope analizi).
// greetWord hatasi: sozdizimi dogru, RPC sozlesmesi dogru, ama fonksiyon
// hic tanimlanmamis -> uygulama render'da patliyor, BEYAZ EKRAN.
// check.js bunu goremiyordu cunku sadece parse ediyordu.
function undefinedRefCheck(file, parser) {
  let traverse;
  try {
    traverse = require("@babel/traverse").default;
  } catch { return []; }

  const src = fs.readFileSync(file, "utf8");
  let ast;
  try {
    ast = parser.parse(src, {
      sourceType: "module",
      plugins: ["jsx", "typescript", "classProperties", "objectRestSpread"],
    });
  } catch { return []; }  // sozdizimi hatasini zaten digeri yakaliyor

  // JS + RN + Expo global'leri — bunlar tanimsiz sayilmaz
  const GLOBALS = new Set([
    "console","require","module","exports","process","global","__DEV__","fetch",
    "setTimeout","clearTimeout","setInterval","clearInterval","Promise","JSON",
    "Object","Array","String","Number","Boolean","Date","Math","Map","Set","RegExp",
    "Error","parseInt","parseFloat","isNaN","undefined","null","true","false",
    "FormData","URL","URLSearchParams","Blob","atob","btoa","alert","navigator",
    "window","document","localStorage","AbortController","TextEncoder","TextDecoder",
    "Intl","Symbol","WeakMap","WeakSet","Proxy","Reflect","BigInt","globalThis",
    "encodeURIComponent","decodeURIComponent","structuredClone","queueMicrotask",
    "Uint8Array","Int8Array","Uint16Array","Int32Array","Float32Array","Float64Array","ArrayBuffer","DataView","Infinity","NaN","isFinite",
  ]);

  const issues = [];
  const seen = new Set();
  traverse(ast, {
    ReferencedIdentifier(path) {
      const name = path.node.name;
      if (GLOBALS.has(name)) return;
      if (path.scope.hasBinding(name, true)) return;
      if (path.scope.hasGlobal(name)) { /* devam */ }
      // JSX ozellik adi / obje anahtari degil mi?
      if (path.parentPath.isObjectProperty({ computed: false }) &&
          path.parentPath.node.key === path.node) return;
      if (path.parentPath.isMemberExpression({ computed: false }) &&
          path.parentPath.node.property === path.node) return;
      if (path.parentPath.isJSXAttribute()) return;

      const line = path.node.loc ? path.node.loc.start.line : 0;
      const k = name + ":" + line;
      if (seen.has(k)) return;
      seen.add(k);
      issues.push(`  ${file}: satir ${line} — '${name}' TANIMSIZ (import edilmemis veya yazilmamis)`);
    },
  });
  return issues;
}

let problems = 0;
const files = ["App.js", ...fs.readdirSync("src").filter(f => f.endsWith(".js")).map(f => "src/" + f)];

// ---- 0) GERCEK JSX PARSE (en onemli kontrol) ----
// Bu, "Adjacent JSX elements", eksik kapanis etiketi gibi TUM sozdizimi
// hatalarini build'e gitmeden yakalar. @babel/parser expo ile birlikte gelir.
let parser = null;
try { parser = require("@babel/parser"); } catch (e) { /* node_modules yoksa atla */ }
// Sonda uyari basmak icin: babel gercekten var mi?
const babelAvailable = !!parser;
if (parser) {
  for (const f of files) {
    try {
      parser.parse(fs.readFileSync(f, "utf8"), {
        sourceType: "module",
        plugins: ["jsx", "classProperties", "objectRestSpread"],
      });
    } catch (e) {
      const loc = e.loc ? ` (satir ${e.loc.line}:${e.loc.column})` : "";
      console.log(`  ${f}: SOZDIZIMI HATASI${loc}\n      ${e.message.split("\n")[0]}`);
      problems++;
    }
  }
  // ---- 0b) TANIMSIZ DEGISKEN (scope analizi) ----
  // Sozdizimi dogru ama olmayan bir fonksiyona/degiskene basvuru ->
  // uygulama render'da patlar, kullanici BEYAZ EKRAN gorur.
  for (const f of files) {
    for (const issue of undefinedRefCheck(f, parser)) { console.log(issue); problems++; }
  }
} else {
  // @babel/parser yoksa: kendi tarayicilarimizla yakalayabildigimizi yakala
  for (const f of files.filter(x => x.endsWith(".js"))) {
    for (const issue of jsxRootCheck(f)) { console.log(issue); problems++; }
    for (const issue of objectCommaCheck(f)) { console.log(issue); problems++; }
  }
}


// ============================================================
// v1.84 — YORUM/METİN GÜRÜLTÜSÜNÜ TEMİZLE
// Aşağıdaki import kontrolleri düz metin regex'i ile çalışıyor. Bu yüzden
// bir YORUM satırında "Linking.getInitialURL()" yazmak "Linking import
// edilmemiş" hatası veriyordu (v1.84'te gerçekten oldu). Yanlış pozitif,
// denetimi görmezden gelmeyi öğretir — asıl tehlike budur.
// Çözüm: kontrolden önce yorumları ve dize içeriklerini boşlukla değiştir.
// Karakter sayısı KORUNUR ki "satir ~N" bilgileri kaymasın.
// ============================================================
function stripNoise(src) {
  // YALNIZ YORUMLARI siler; dize içerikleri KORUNUR çünkü aşağıdaki
  // kontroller `from "react-native"` gibi dizelere bakıyor. İlk denemede
  // dizeler de silinmişti ve bu sefer "react EKSIK IMPORT" yanlış pozitifi
  // çıktı — düzeltmenin kendisi doğrulanmadan kabul edilmemeli.
  let out = "", i = 0; const n = src.length;
  while (i < n) {
    const c = src[i], d = src[i + 1];
    if (c === "/" && d === "/") {
      while (i < n && src[i] !== "\n") { out += " "; i++; }
    } else if (c === "/" && d === "*") {
      out += "  "; i += 2;
      while (i < n && !(src[i] === "*" && src[i + 1] === "/")) { out += (src[i] === "\n" ? "\n" : " "); i++; }
      out += "  "; i += 2;
    } else if (c === '"' || c === "'" || c === "`") {
      const q = c; out += q; i++;
      while (i < n && src[i] !== q) {
        if (src[i] === "\\") { out += src[i] + (src[i + 1] || ""); i += 2; continue; }
        out += src[i]; i++;
      }
      out += (i < n ? q : ""); i++;
    } else { out += c; i++; }
  }
  return out;
}

for (const f of files) {
  const s = stripNoise(fs.readFileSync(f, "utf8"));

  const rnM = s.match(/import \{([^}]+)\} from "react-native"/);
  const rnImported = new Set(rnM ? rnM[1].split(",").map(x => x.trim()) : []);
  const rnUsed = new Set([
    ...RN_COMPONENTS.filter(c => new RegExp("<" + c + "\\b").test(s)),
    ...RN_NAMESPACES.filter(c => new RegExp("\\b" + c + "\\.").test(s)),
  ]);
  // Baska modulden import edilmis olabilir (or. StatusBar -> expo-status-bar)
  const otherImports = new Set();
  for (const im of s.matchAll(/import (?:(\w+),\s*)?(?:\{([^}]*)\})?\s*from "([^"]+)"/g)) {
    if (im[3] === "react-native") continue;
    if (im[1]) otherImports.add(im[1]);
    if (im[2]) im[2].split(",").map(x => x.trim().split(/\s+as\s+/).pop()).filter(Boolean).forEach(n => otherImports.add(n));
  }
  const rnMissing = [...rnUsed].filter(x => !rnImported.has(x) && !otherImports.has(x));
  if (rnMissing.length) { console.log(`  ${f}: react-native EKSIK IMPORT -> ${rnMissing.join(", ")}`); problems++; }

  const rM = s.match(/import (?:React,\s*)?\{([^}]+)\} from "react"/);
  const rImported = new Set(rM ? rM[1].split(",").map(x => x.trim()) : []);
  const rUsed = HOOKS.filter(h => new RegExp("\\b" + h + "\\(").test(s));
  const rMissing = rUsed.filter(x => !rImported.has(x));
  if (rMissing.length) { console.log(`  ${f}: react EKSIK IMPORT -> ${rMissing.join(", ")}`); problems++; }
}

// App.js <-> screens.js export uyumu
const app = fs.readFileSync("App.js", "utf8");
// 🔴 26 AĞUSTOS — TASARIM DENETİMLERİNİN KAPSAMI UYGULAMANIN %26'SINA
// HİÇ BAKMIYORDU.
//
// Ölçüm: `typeScaleCheck`, `hardcodedTrCheck`, `tapTargetCheck`,
// `propDropCheck` ve `contrastCheck` yalnız `src/screens.js` (+`ui.js`)
// tarıyordu. Oysa Splash, Auth, Onboarding, Home, Chat, Wallet, Plans,
// Notifications, Marketplace, LoungeGuide, HostApply — hepsi `App.js` ve
// `ekranlar_yalin.js` içinde yaşıyor: 5.900 satır, ~55 ekran.
//
// Yani denetim her koşuda yeşil yanıyordu çünkü BAKMIYORDU.
//
// 🆕 SINIF: "BİR DENETİMİN KAPSAMI, ONUN GERÇEKTEN NE ÖLÇTÜĞÜNÜN TEK
// BELİRLEYİCİSİDİR — YEŞİL YANMASI DEĞİL."
const TASARIM_KAPSAMI = ["src/screens.js", "src/ui.js", "src/ekranlar_yalin.js",
                         "src/ortak.js", "App.js", "src/HostWallet.js",
                         "src/MomentScreen.js"];

const sc = fs.readFileSync("src/screens.js", "utf8");
const m = app.match(/import \{([^}]+)\} from "\.\/src\/screens"/);
if (m) {
  const want = m[1].split(",").map(x => x.trim()).filter(Boolean);
  // 🔴 v2.97 — `export *` ZINCIRINI DE TAKIP ET.
  // screens.js bolundukten sonra 22 ekran `ortak.js` ve `ekranlar_yalin.js`e
  // tasindi ve screens.js onlari `export * from "./ortak"` ile yeniden disa
  // aktariyor. Bu kontrol yalniz screens.js'in KENDI govdesine bakiyordu ve
  // dogru calisan 22 import'u "OLMAYAN export" diye bildirdi.
  // 🆕 SINIF: "BIR DENETIM DOSYA ICERIGINE BAKIYORSA, O DOSYANIN BASKA
  // DOSYALARI DISA AKTARABILECEGINI DE BILMEK ZORUNDADIR."
  const have = new Set();
  const topla = (metin, kaynakDosya) => {
    for (const x of metin.matchAll(/export (?:function|const|let|var|async function) (\w+)/g)) have.add(x[1]);
    for (const x of metin.matchAll(/export\s+\{([^}]*)\}\s+from/g)) {
      for (const n of x[1].split(",")) {
        const ad = n.trim().split(/\s+as\s+/).pop().trim();
        if (ad) have.add(ad);
      }
    }
    for (const x of metin.matchAll(/export\s+\*\s+from\s+"\.\/([^"]+)"/g)) {
      const yol = "src/" + x[1].replace(/\.js$/, "") + ".js";
      try { topla(fs.readFileSync(yol, "utf8"), yol); }
      catch { console.log(`  ⚠ ${kaynakDosya}: 'export * from "./${x[1]}"' ama ${yol} OKUNAMADI`); }
    }
  };
  topla(sc, "src/screens.js");
  const miss = want.filter(w => !have.has(w));
  if (miss.length) { console.log(`  App.js: screens.js'te OLMAYAN export -> ${miss.join(", ")}`); problems++; }
}

// screens.js icindeki yerel bilesenler tanimli mi
// 🔴 v2.65 — IMPORT EDILEN BILESENLER DE "TANIMLI"DIR.
// Ikiz Toggle/Row temizliginde screens.js kendi kopyasini silip ui.js'ten
// import etmeye gecti; bu kontrol import'lari bilmedigi icin <Toggle>'i
// "TANIMSIZ" sandi. Yanlis alarm, denetime bakmayi biraktirir.
const local = new Set([
  ...[...sc.matchAll(/(?:export )?function (\w+)/g)].map(x => x[1]),
  ...[...sc.matchAll(/const (\w+) = /g)].map(x => x[1]),
  ...[...sc.matchAll(/import\s*\{([^}]*)\}\s*from/g)]
      .flatMap(x => x[1].split(",").map(n => n.trim().split(/\s+as\s+/).pop()).filter(Boolean)),
]);
for (const comp of ["PhoneGate","Toggle","Load","SettingsModals","Avatar","RateReminder","ActionNeeded"]) {
  if (new RegExp("<" + comp + "\\b").test(sc) && !local.has(comp)) {
    console.log(`  screens.js: <${comp}> kullaniliyor ama TANIMSIZ`); problems++;
  }
}

// Ayni ismin BIRDEN FAZLA modulden import edilmesi -> "Identifier has already been declared"
for (const f of files) {
  const s2 = fs.readFileSync(f, "utf8");
  const seen = new Map();
  for (const im of s2.matchAll(/import (?:(\w+),\s*)?(?:\{([^}]*)\})?\s*from "([^"]+)"/g)) {
    const names = [];
    if (im[1]) names.push(im[1]);
    if (im[2]) names.push(...im[2].split(",").map(x => x.trim().split(/\s+as\s+/).pop()).filter(Boolean));
    for (const n of names) {
      if (seen.has(n) && seen.get(n) !== im[3]) {
        console.log(`  ${f}: '${n}' HEM '${seen.get(n)}' HEM '${im[3]}' modulunden import edilmis -> cakisma!`);
        problems++;
      }
      seen.set(n, im[3]);
    }
  }
}

// ============================================================
// 4. HATA SINIFI: EKSIK i18n ANAHTARI
//
// t.marketTitle sozdizimsel olarak GECERLI bir property erisimi, yani
// undefinedRefCheck() onu goremez. Ama i18n.js'te o anahtar yoksa:
//   · <Text>{t.planExplorer}</Text>        -> sessizce BOS render
//   · {t.yourPoints.toUpperCase()}          -> TypeError, ekran COKER
//
// Ikisi de gercekten yasandi: Magaza "toUpperCase of undefined" ile
// coktu, plan kartlari bos basliklarla ciktu. Ayni kok, iki belirti.
// 170 anahtar eksikti ve hicbir denetim katmani goremedi.
// ============================================================
// 🔴 v2.50 — YENİ DENETİM: MÜKERRER i18n ANAHTARI.
// `rqIdOk` iki kez tanımlıydı; JavaScript'te nesne değişmezinde SON
// tanım sessizce kazanır. Sonuç: özenle yazılmış "Kimlik doğrulandı"
// metni ölü koda dönüşür ve kimse fark etmez — cihazda rozet boş
// göründüğünde sebebini bulmak yarım saat aldı. Bu sınıf artık
// build'de yakalanır: aynı dil bloğunda aynı anahtar iki kez
// tanımlanamaz.
function i18nDupKeyCheck() {
  const src = fs.readFileSync(path.join(__dirname, "src", "i18n.js"), "utf8");
  const lines = src.split("\n");
  let bad = 0;
  let lang = null;
  const seen = {};
  // 🔴 İLK SÜRÜMDE YANLIŞ POZİTİF VERDİ: dil bloğunun BİTTİĞİNİ
  // izlemiyordu, dosyanın devamındaki yerel nesneleri (badge haritası
  // gibi) de i18n anahtarı sanıyordu. Denetimin kendisi yanlış alarm
  // verirse insanlar denetime bakmayı bırakır — blok sonu artık
  // parantez sayımıyla izleniyor.
  lines.forEach((ln, idx) => {
    const langM = ln.match(/^\s{2}(tr|en)\s*:\s*\{/);
    if (langM) { lang = langM[1]; seen[lang] = seen[lang] || {}; return; }
    if (!lang) return;
    // Blok sonu: i18n.js'te dil blokları hem "  }," hem girintisiz "}"
    // ile kapanabiliyor (dosyanın sonundaki EN bloğu böyle).
    if (/^\s{0,2}\},?;?\s*$/.test(ln)) { lang = null; return; }
    const m = ln.match(/^\s{4}([A-Za-z_][A-Za-z0-9_]*)\s*:/);
    if (!m) return;
    const k = m[1];
    if (seen[lang][k]) {
      console.log(`  ✗ i18n MÜKERRER anahtar: ${lang}.${k} — satır ${seen[lang][k]} ve ${idx + 1} (sonuncusu sessizce kazanır)`);
      bad++;
    } else seen[lang][k] = idx + 1;
  });
  return bad;
}

function i18nKeyCheck() {
  const i18nPath = "src/i18n.js";
  if (!fs.existsSync(i18nPath)) return;
  const i18nSrc = fs.readFileSync(i18nPath, "utf8");

  // tr: { ... } blogunu bul — girinti 2+ olan "anahtar:" satirlari
  // NOT: indexOf("en: {") kullanma — "Görüntülenen: {f}" gibi bir STRING
  // içindeki alt dizi de eşleşir ve tr bloğunu ortadan böler (yaşandı).
  // Blok başlıkları satır başında tam 2 boşluk girintiyle durur.
  const trM = /^  tr: \{/m.exec(i18nSrc);
  const enM = /^  en: \{/m.exec(i18nSrc);
  const trStart = trM ? trM.index : -1;
  const enStart = enM ? enM.index : -1;
  if (trStart < 0) return;
  const trBlock = i18nSrc.slice(trStart, enStart > trStart ? enStart : undefined);
  const enBlock = enStart > 0 ? i18nSrc.slice(enStart) : "";

  // Aynı satırda birden çok anahtar olabilir ("a: "..", b: "..") — satır-başı
  // regex'i yalnız İLKİNİ görüyordu; sonrakiler yanlış "YOK" çıkıyordu.
  // Önce string içerikleri soyulur (içlerindeki "x:" kalıpları anahtar sanılmasın),
  // sonra kalan metindeki tüm `anahtar:` kalıpları toplanır.
  // ══════════════════════════════════════════════════════════════════
  // 🔴 26 AĞUSTOS — BU DENETİM YORUMLARI DA KOD SAYIYORDU.
  //
  // Aşağıdaki `keysIn` (TANIM tarafı) yorumları zaten soyuyor. Ama
  // KULLANIM tarafı (`t.X` araması) HAM KAYNAK üzerinde çalışıyordu.
  // Sonuç: bir yorumda "`t.errPass` artık ölü bir metin" diye YAZMAK
  // denetimi kırmızı yakıyor ve tek çıkış yolu YORUMU SİLMEK oluyordu.
  //
  // Yani denetim, kendi kaldırdığım ölü kodu ANLATMAMI cezalandırıyordu.
  // Bu projede aynı sınıfı `bagimlilik_check.py`de bir kez yaşadım:
  // orada "28 bildirimlik döngüsel çekirdek" tamamen yorumlardan
  // gelmişti ve KOCA BİR MİMARİ SONUÇ yanlış çıkmıştı.
  //
  // 🆕 SINIF: "KAYNAĞI DÜZ METİN OLARAK TARAYAN HER DENETİM, İYİ
  // YORUMLANMIŞ DOSYAYA EN KÖTÜ NOTU VERİR — VE İNSANI AÇIKLAMA
  // YAZMAMAYA İTER."
  //
  // `://` koruması bilinçli: "https://..." bir yorum başlangıcı değildir.
  const yorumsuz = (src) => src
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/(^|[^:])\/\/[^\n]*/g, "$1 ");

  const keysIn = (blk) => {
    // 🔴 YORUMLAR ÖNCE SOYULUR. Bir YORUM içindeki tek kesme işareti
    // (örn. "host'ta") string soyucusunu tetikliyor ve bir sonraki
    // kesme işaretine kadar HER ŞEYİ yutuyordu — bloğun yarısı yok
    // olup 170 anahtar "eksik" görünüyordu. Türkçe yorum yazan bir
    // kod tabanında bu kaçınılmazdı; kalıcı çözüm yorumları elemek.
    const noComments = blk
      .replace(/\/\*[\s\S]*?\*\//g, " ")
      .replace(/(^|[^:])\/\/[^\n]*/g, "$1 ");
    const stripped = noComments.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/'(?:[^'\\]|\\.)*'/g, "''");
    return new Set([...stripped.matchAll(/([a-zA-Z_]\w*)\s*:/g)].map(m => m[1]));
  };
  const trKeys = keysIn(trBlock);
  const enKeys = keysIn(enBlock);

  // kodda kullanilan t.X
  const used = new Map(); // key -> {file, crashes}
  for (const f of files) {
    if (f === i18nPath) continue;
    const src = yorumsuz(fs.readFileSync(f, "utf8"));
    for (const m of src.matchAll(/\bt\.([a-zA-Z_]\w*)/g)) {
      const k = m[1];
      if (!used.has(k)) used.set(k, { file: f, crashes: false });
      // .toUpperCase() / .replace() / .slice() gibi bir metot cagriliyorsa COKER
      const after = src.slice(m.index + m[0].length, m.index + m[0].length + 12);
      if (/^\s*\.\s*[a-zA-Z]/.test(after)) used.get(k).crashes = true;
    }
  }

  const missingTr = [...used.keys()].filter(k => !trKeys.has(k)).sort();
  const missingEn = [...used.keys()].filter(k => enKeys.size && !enKeys.has(k)).sort();

  const crashers = missingTr.filter(k => used.get(k).crashes);
  const silent = missingTr.filter(k => !used.get(k).crashes);

  for (const k of crashers) {
    console.log(`  🔴 i18n: t.${k} YOK ve uzerinde metot cagriliyor -> EKRAN COKER (${used.get(k).file})`);
    problems++;
  }
  for (const k of silent) {
    console.log(`  ⚠ i18n: t.${k} YOK -> bos render (${used.get(k).file})`);
    problems++;
  }
  // TR'de var EN'de yok -> dil degistirince bosalir
  const onlyTr = missingEn.filter(k => trKeys.has(k));
  for (const k of onlyTr) {
    console.log(`  ⚠ i18n: t.${k} TR'de var, EN'de YOK -> dil degisince bosalir`);
    problems++;
  }
}
i18nKeyCheck();
problems += i18nDupKeyCheck();

// ============================================================
// 5. HATA SINIFI: TANIMSIZ TEMA ANAHTARI
//
// C.purpleSoft gibi bir sey yazarsan JS patlamaz — undefined doner ve
// backgroundColor: undefined sessizce SEFFAF olur. Ekran calisir ama
// yanlis gorunur; kimse fark etmez.
//
// Gercekten yasandi: Meet ekranini mora cevirirken toplu degistirme
// C.goldSoft -> C.purpleSoft yapti ama theme.js'te o alan `purpleBg`.
// Iki yerde undefined renk olustu. undefinedRefCheck goremez (C tanimli
// bir nesne), i18nKeyCheck goremez (t.* degil).
// ============================================================
function themeKeyCheck() {
  const themePath = "src/theme.js";
  if (!fs.existsSync(themePath)) return;
  const th = fs.readFileSync(themePath, "utf8");

  const keys = new Set();
  for (const m of th.matchAll(/^\s{2,}(\w+)\s*:/gm)) keys.add(m[1]);
  for (const m of th.matchAll(/^C\.(\w+)\s*=/gm)) keys.add(m[1]);   // geriye donuk takma adlar
  if (keys.size === 0) return;

  for (const f of files) {
    if (f === themePath) continue;
    const src = fs.readFileSync(f, "utf8");
    const seen = new Set();
    for (const m of src.matchAll(/\bC\.(\w+)\b/g)) {
      const k = m[1];
      if (keys.has(k) || seen.has(k)) continue;
      seen.add(k);
      console.log(`  🔴 tema: C.${k} theme.js'te YOK -> undefined renk (${f})`);
      problems++;
    }
  }
}
themeKeyCheck();

// package.json'da olmayan modul import edilmis mi? (bundle'i patlatir)
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const deps = new Set([...Object.keys(pkg.dependencies || {}), ...Object.keys(pkg.devDependencies || {})]);
for (const f of files) {
  const s3 = fs.readFileSync(f, "utf8");
  // \n ve > iceren eslesmeleri DISLA: JSX'te `label="BASLANGIC" ... from` gibi
  // cok satirli metinler import saniliyordu (yanlis alarm). Modul adi tek satir,
  // bosluk/JSX karakteri icermez.
  for (const im of s3.matchAll(/(?:^|[\s;])(?:from|import\()\s*["']([^"'.\s<>{}()][^"'\s<>{}()]*)["']/gm)) {
    const mod = im[1];
    const root = mod.startsWith("@") ? mod.split("/").slice(0, 2).join("/") : mod.split("/")[0];
    if (!deps.has(root) && !["react", "react-native"].includes(root)) {
      console.log(`  ${f}: '${root}' import edilmis ama package.json'da YOK`); problems++;
    }
  }
}

// ============================================================
// BABEL UYARISI
//
// @babel/parser yoksa bu betik SEZGISEL fallback'e duser: JSX kok
// elemani sayimi ve virgul kontrolu kaba tahminlerdir, hem yanlis
// alarm verebilir hem de GERCEK bir hatayi kacirabilir.
//
// `node --check dosya.js` de JSX icin ISE YARAMAZ: .js uzantisinda
// sessizce 0 doner (test edildi — ayni dosya .mjs olarak 1 donuyor).
// Yani "node --check temiz" ifadesi JSX dosyalarinda hicbir sey
// kanitlamaz.
//
// GERCEK kontrol yalniz @babel/parser ile olur; o da expo ile
// node_modules'e gelir. Yani bu betigi KENDI MAKINENDE calistirmak
// sarttir — baska yerdeki "temiz" ciktisi eksik bilgidir.
// ============================================================
// YENI: erken return sonrasi hook (beyaz ekran sebebi)
problems += hooksAfterReturnCheck(files);

// ============================================================
// TIPOGRAFI OLCEGI (v2.17)
//
// 🔴 NEDEN VAR: elle yazilan fontSize degerleri 37 FARKLI boyuta
// ulasmisti — 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15...
// Hicbir ekran "bozuk" gorunmuyor ama hicbiri obüruyle ayni ritimde
// degil. Kullanici buna "amatör" demez, sadece guven duymaz.
//
// Olcege cektik; bu kontrol GERI KAYMAYI engelliyor. Kural yoksa
// bir sonraki turda yine 37 olur — temizlik bir kez yapilir, KURAL
// surekli calisir.
//
// Buyuk gosterim boyutlari (18+) muaf: splash, avatar harfi, emoji,
// bos ekran ikonu. Onlar tipografi degil GORSEL oge.
// ============================================================
function typeScaleCheck(files) {
  // 🔴 ÖLÇEK EKSİKTİ, KOD DEĞİL. `34`, `44` ve `74` "ölçek dışı" diye
  // sayılıyordu ama onlar hata değil GÖSTERİM boyutları: kutlama ekranının
  // rakamı, splash başlığı, sahne arkasındaki hayalet kelime. Bir ölçek,
  // ürünün gerçekten ihtiyaç duyduğu kademeleri içermiyorsa eksik olan
  // ölçektir; kodu ona uydurmaya çalışmak boyutları bozar.
  //
  // 🆕 SINIF: "BİR DEĞER ÖLÇEĞE UYMUYORSA İKİ İHTİMAL VAR — DEĞER YANLIŞ
  // OLABİLİR YA DA ÖLÇEK EKSİK. HANGİSİ OLDUĞUNU O DEĞERİN NE İŞ
  // YAPTIĞINA BAKMADAN BİLEMEZSİN."
  //
  //   gövde/etiket : 9 · 10.5 · 12.5 · 14 · 16
  //   başlık       : 20 · 26
  //   gösterim     : 34 · 44        (kutlama rakamı, splash başlığı)
  //   dekor        : 74             (ScenePad hayalet kelime, opaklık %4.5)
  const SCALE = new Set([9, 10.5, 12.5, 14, 16, 20, 26, 34, 44, 74]);
  const off = [];
  for (const f of files) {
    if (!/screens\.js$|ui\.js$/.test(f)) continue;
    const src = fs.readFileSync(f, "utf8").split("\n");
    src.forEach((line, i) => {
      const m = line.match(/fontSize: ([0-9.]+)/g) || [];
      for (const hit of m) {
        const v = parseFloat(hit.split(": ")[1]);
        if (v >= 18) continue;                 // gosterim boyutu, muaf
        if (!SCALE.has(v)) off.push(`${path.basename(f)}:${i + 1}  fontSize: ${v}`);
      }
    });
  }
  if (off.length) {
    console.log(`  ✗ ${off.length} adet ölçek dışı fontSize:`);
    off.slice(0, 8).forEach(o => console.log(`      ${o}`));
    console.log("      Ölçek: 9 · 10.5 · 12.5 · 14 · 16 · 20 · 26");
    console.log("      Yeni bir boyut gerekiyorsa ÖLÇEĞE EKLE, ara değer uydurma.");
  }
  return off.length;
}
problems += typeScaleCheck(files);


// ============================================================
// v2.65 — BEŞ YENİ DENETİM
//
// Ortak gerekçe: aşağıdaki beş hata sınıfının HİÇBİRİ sözdizimi hatası
// değil. Hepsi derlenir, hepsi çalışır, hiçbiri log basmaz. Yalnızca
// YANLIŞ ekran gösterirler — ve bunu sessizce yaparlar. Sessiz hata,
// gürültülü hatadan pahalıdır: kimse aramaz.
// ============================================================

// ------------------------------------------------------------
// 1) propDropCheck — GEÇİLEN AMA OKUNMAYAN PROP
//
// 🔴 JS'te bir bileşene olmayan bir prop geçmek HATA DEĞİLDİR; sessizce
// yutulur. Canlıda tam olarak bu oldu: App.js `onAddVisit` geçiyordu,
// Trips `onAddTrip` bekliyordu. Misafir "+ Seyahat ekle"ye basınca eski
// satır-içi form, host basınca yeni ekran açılıyordu. AYNI DÜĞME, İKİ ÜRÜN.
//
// İki ayrı kusuru ayırır:
//   · imzada YOK          -> davranış sessizce kayboldu (canlı hata)
//   · imzada var, gövdede okunmuyor -> ölü prop (bir sonraki geliştiriciye yalan)
// ------------------------------------------------------------
function propDropCheck(parser) {
  if (!parser) return 0;
  let traverse; try { traverse = require("@babel/traverse").default; } catch { return 0; }

  const parse = (f) => {
    try {
      return parser.parse(fs.readFileSync(f, "utf8"),
        { sourceType: "module", plugins: ["jsx", "classProperties", "objectRestSpread"] });
    } catch { return null; }
  };

  // --- hedef modüldeki bileşenleri topla: imza propları + gövdede okunanlar ---
  const comps = new Map();   // ad -> { sig:Set, used:Set, rest:bool }
  for (const target of TASARIM_KAPSAMI) {
    const ast = parse(target);
    if (!ast) continue;
    traverse(ast, {
      FunctionDeclaration(p) {
        const name = p.node.id && p.node.id.name;
        if (!name || !/^[A-Z]/.test(name)) return;          // bileşen = BüyükHarf
        const par = p.node.params[0];
        if (!par || par.type !== "ObjectPattern") return;    // destructure etmiyorsa atla
        const sig = new Set(); let rest = false;
        for (const pr of par.properties) {
          if (pr.type === "RestElement") { rest = true; continue; }
          if (pr.key && pr.key.name) sig.add(pr.key.name);
        }
        // gövdede GERÇEKTEN okunan adlar (imza deseninin kendisi hariç)
        const used = new Set();
        p.get("body").traverse({
          Identifier(ip) {
            if (!sig.has(ip.node.name)) return;
            if (ip.parentPath.isObjectProperty({ computed: false }) &&
                ip.parentPath.node.key === ip.node) return;   // {onX: ...} anahtarı
            if (ip.parentPath.isMemberExpression({ computed: false }) &&
                ip.parentPath.node.property === ip.node) return; // a.onX
            used.add(ip.node.name);
          },
        });
        comps.set(name, { sig, used, rest, file: target });
      },
    });
  }
  if (!comps.size) return 0;

  // --- App.js'teki JSX kullanımlarını denetle ---
  let bad = 0;
  const ast = parse("App.js");
  if (!ast) return 0;
  const seen = new Set();
  traverse(ast, {
    JSXOpeningElement(p) {
      const nm = p.node.name;
      if (!nm || nm.type !== "JSXIdentifier") return;
      const c = comps.get(nm.name);
      if (!c) return;
      for (const at of p.node.attributes) {
        if (at.type !== "JSXAttribute" || !at.name || !at.name.name) continue;
        const prop = at.name.name;
        if (prop === "key" || prop === "ref" || prop === "children") continue;
        const line = at.loc ? at.loc.start.line : 0;
        const k = nm.name + "." + prop;
        if (seen.has(k)) continue;
        if (!c.sig.has(prop)) {
          if (c.rest) continue;                      // {...rest} varsa yutulmuyor olabilir
          seen.add(k);
          console.log(`  🔴 PROP-DROP: App.js:${line} <${nm.name} ${prop}=...> — ` +
            `imzada YOK (${c.file}) -> sessizce yutuluyor, davranış KAYBOLUYOR`);
          bad++;
        } else if (!c.used.has(prop)) {
          seen.add(k);
          console.log(`  ⚠ ÖLÜ PROP: App.js:${line} <${nm.name} ${prop}=...> — ` +
            `imzada var ama GÖVDEDE HİÇ okunmuyor (${c.file}) -> ya bağla ya sil`);
          bad++;
        }
      }
    },
  });
  return bad;
}

// ------------------------------------------------------------
// 2) errorSwallowCheck — `await supabase` çağrısı error'ü okuyor mu?
//
// 🔴 `const { data } = await supabase...` yazınca ağ/RLS hatası `data:null`
// olur ve BOŞ LİSTEYE dönüşür. Kullanıcı "hiç ilan yok" görür — bu bir
// yalandır ve en kötü türüdür, çünkü kullanıcı ürünün boş olduğunu sanıp
// gider. Boş durum DAVET eder, hata durumu YENİDEN DENEMEYE çağırır.
// ------------------------------------------------------------
function errorSwallowCheck(files) {
  let bad = 0;
  for (const f of files) {
    // 🔴 v2.97 — KAPSAM screens.js VE App.js ILE SINIRLIYDI.
    // screens.js bolununce sayac 75'ten 55'e DUSTU ve ilk bakista "borc
    // azaldi" gibi gorundu. Olcunce cikti: 20 bulgu `ortak.js` ve
    // `ekranlar_yalin.js`e tasindi ve bu denetim o dosyalara BAKMIYORDU.
    // 🆕 SINIF: "BIR SAYAC DUSTUGUNDE ONCE 'DUZELDI MI' DIYE DEGIL,
    // 'BAKMAYI BIRAKTI MI' DIYE SOR."
    // Kapsam artik TUM app kaynagi.
    if (!/\.js$/.test(f)) continue;
    const lines = fs.readFileSync(f, "utf8").split("\n");
    lines.forEach((ln, i) => {
      if (!/await\s+supabase/.test(ln)) return;
      if (/^\s*\/\//.test(ln)) return;
      // destructure YOKSA (ör. `await supabase.rpc(...)` tek başına) —
      // dönüşü kullanmayan çağrı ayrı bir konu, burada kapsam dışı.
      const m = ln.match(/(?:const|let|var)\s*\{([^}]*)\}\s*=\s*await\s+supabase/);
      if (!m) return;
      if (/\berror\b/.test(m[1])) return;             // error okunuyor ✓
      console.log(`  ⚠ SESSİZ YUTMA: ${path.basename(f)}:${i + 1} — ` +
        `'await supabase' error'ü destructure ETMİYOR -> hata boş listeye dönüşür`);
      console.log(`      ${ln.trim().slice(0, 92)}`);
      bad++;
    });
  }
  return bad;
}

// ------------------------------------------------------------
// 3) hardcodedTrCheck — JSX'te sabit Türkçe dize
//
// 🔴 Dört ekran (Ayarlar, Profili Düzenle, Seyahat Ekle, Müsaitlik) i18n'e
// HİÇ bağlı değildi. lang="en" seçen kullanıcı onları Türkçe görüyordu —
// üstelik Dil ayarının kendisi o ekranlardaydı.
//
// SINIR: yalnız Türkçe'ye özgü karakter (çğıöşü) içeren dizeleri görür.
// Saf ASCII Türkçe ("Profilini tamamla") bu tarayıcıdan kaçar; bu bilinen
// bir eksiklik, gizlenmiyor.
// ------------------------------------------------------------
function hardcodedTrCheck(parser) {
  if (!parser) return 0;
  let traverse; try { traverse = require("@babel/traverse").default; } catch { return 0; }
  const TR = /[çğıöşüÇĞİÖŞÜ]/;
  const TEXTY = new Set(["label", "placeholder", "title", "sub", "cta", "body",
                         "emptyNote", "a11yLabel", "accessibilityLabel", "hint"]);
  let bad = 0;
  for (const f of TASARIM_KAPSAMI) {
    let ast;
    try {
      ast = parser.parse(fs.readFileSync(f, "utf8"),
        { sourceType: "module", plugins: ["jsx", "classProperties", "objectRestSpread"] });
    } catch { continue; }
    const hits = [];
    traverse(ast, {
      JSXText(p) {
        const v = p.node.value.trim();
        if (v && TR.test(v)) hits.push([p.node.loc.start.line, "JSX metni", v]);
      },
      JSXAttribute(p) {
        const n = p.node.name && p.node.name.name;
        if (!TEXTY.has(n)) return;
        const val = p.node.value;
        const lit = val && (val.type === "StringLiteral" ? val
          : (val.type === "JSXExpressionContainer" && val.expression.type === "StringLiteral"
             ? val.expression : null));
        if (lit && TR.test(lit.value)) hits.push([lit.loc.start.line, n + "=", lit.value]);
      },
    });
    if (hits.length) {
      console.log(`  ⚠ ${hits.length} adet SABİT TÜRKÇE dize (${path.basename(f)}) -> lang="en" bunu çeviremez:`);
      hits.slice(0, 8).forEach(h => console.log(`      ${h[0]}  ${h[1]}  ${String(h[2]).slice(0, 60)}`));
      bad += hits.length;
    }
  }
  return bad;
}

// ------------------------------------------------------------
// 4) contrastCheck — WCAG AA (4.5:1) nispi parlaklık hesabı
//
// 🔴 ÖLÇÜLDÜ: C.gold (#B8943A) üzerine beyaz metin 2.86:1. AA metin için
// 4.5 gerekiyor. 70 CTA ve 199 metin bu orandaydı. "Gözüme okunur geldi"
// bir gerekçe değildir; oran hesaplanır.
//
// Altın İŞARET rengi olarak korunuyor (marka çapası); denetlenen şey
// METİN TAŞIYAN çiftler.
// ------------------------------------------------------------
function contrastCheck() {
  const th = "src/theme.js";
  if (!fs.existsSync(th)) return 0;
  const src = fs.readFileSync(th, "utf8");
  // 🔴 26 AĞUSTOS — BU TARAMA KAPSAM BİLMİYORDU.
  // theme.js'e KOYU tema paleti eklendiği an bu denetim dört sahte
  // ihlal üretti: KOYU'nun `ink`, `body`, `mutedAA`, `goldText`
  // anahtarları C'ninkilerin ÜSTÜNE yazıldı ve koyu tema metinleri
  // BEYAZ KART zeminine karşı ölçüldü (1.14:1 gibi). Uygulamada böyle
  // bir eşleşme yok; ölçüm kendi kurduğu bir sahneyi ölçtü.
  //
  // Aynı sınıfı bugün `tema_check.py`de de yaşadım. Düz metin tarayan
  // her ayrıştırıcı, dosyaya ikinci bir nesne eklendiği gün sessizce
  // yanlış cevap vermeye başlıyor.
  //
  // 🆕 SINIF: "BİR AYRIŞTIRICI KAPSAM BİLMİYORSA, ÖLÇTÜĞÜ DOSYAYA
  // İKİNCİ BİR PALET EKLENDİĞİ GÜN İKİSİNİ KARIŞTIRIR."
  //
  // Çözüm: KOYU bloğunu metinden ÇIKAR, sonra C'yi topla.
  const koyuBlok = /export const KOYU\s*=\s*\{[\s\S]*?\n\};/.exec(src);
  const koyuBadge = /KOYU\.badgeInk\s*=\s*\{[\s\S]*?\n\};/.exec(src);
  let acikSrc = src;
  if (koyuBlok) acikSrc = acikSrc.replace(koyuBlok[0], "");
  if (koyuBadge) acikSrc = acikSrc.replace(koyuBadge[0], "");

  const hex = {};
  for (const m of acikSrc.matchAll(/(?:^|\s)(?:C\.)?(\w+)\s*[:=]\s*"(#[0-9A-Fa-f]{6})"/g)) hex[m[1]] = m[2];

  const lum = (h) => {
    const v = [1, 3, 5].map(i => parseInt(h.substr(i, 2), 16) / 255)
      .map(c => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)));
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  };
  const ratio = (a, b) => {
    const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
    return (x + 0.05) / (y + 0.05);
  };

  // Denetlenen METİN/ZEMİN çiftleri — her biri üründe GERÇEKTEN kullanılıyor.
  const PAIRS = [
    ["goldBtn", "#FFFFFF", "ana CTA zemini + beyaz metin"],
    ["tealBtn", "#FFFFFF", "teal CTA + beyaz metin"],
    ["greenBtn", "#FFFFFF", "yeşil CTA + beyaz metin"],
    ["goldText", "#FFFFFF", "altın metin / beyaz kart"],
    ["mutedAA", "#FFFFFF", "ikincil metin / beyaz kart"],
    ["amberInk", "#FEF6EC", "uyarı metni / amber zemin"],
    ["ink", "#FFFFFF", "gövde metni / beyaz kart"],
    ["body", "#FFFFFF", "gövde metni / beyaz kart"],
  ];
  let bad = 0;
  for (const [key, other, why] of PAIRS) {
    const h = hex[key];
    if (!h) { console.log(`  ⚠ kontrast: theme.js'te '${key}' yok`); bad++; continue; }
    const r = ratio(h, other);
    if (r < 4.5) {
      console.log(`  🔴 KONTRAST: C.${key} (${h}) ↔ ${other} = ${r.toFixed(2)}:1 ` +
        `— AA 4.5 gerekiyor (${why})`);
      bad++;
    }
  }
  return bad;
}

// ------------------------------------------------------------
// 5) tapTargetCheck — dokunulabilir alan 44px'e ulaşıyor mu?
//
// 🔴 Apple HIG 44pt, Material 48dp. Uygulamada ikon butonlarına genişlik
// verilip YÜKSEKLİK unutulmuştu: 54px genişlik, ≈21px yükseklik. Iskalanan
// her dokunuş kullanıcıya "bozuk" dedirtir ve kimse hata raporu yazmaz.
//
// Kabul edilen üç kanıttan biri yeterli: minHeight · paddingVertical>=13 ·
// hitSlop. (Stil dışarıdan geliyorsa — S.btn gibi — style={S.x} yazan
// satırlar muaf; onlar tek yerden yönetiliyor.)
// ------------------------------------------------------------
function tapTargetCheck(parser) {
  if (!parser) return 0;
  let traverse; try { traverse = require("@babel/traverse").default; } catch { return 0; }
  let bad = 0;
  for (const f of TASARIM_KAPSAMI) {
    let src, ast;
    try {
      src = fs.readFileSync(f, "utf8");
      ast = parser.parse(src, { sourceType: "module", plugins: ["jsx", "classProperties", "objectRestSpread"] });
    } catch { continue; }
    const hits = [];
    traverse(ast, {
      JSXOpeningElement(p) {
        const nm = p.node.name;
        if (!nm || nm.name !== "TouchableOpacity") return;
        let hasSlop = false, styleTxt = null;
        for (const at of p.node.attributes) {
          if (at.type !== "JSXAttribute" || !at.name) continue;
          if (at.name.name === "hitSlop") hasSlop = true;
          if (at.name.name === "style" && at.value && at.value.range !== undefined) { /* noop */ }
          if (at.name.name === "style" && at.value && at.value.start != null) {
            styleTxt = src.slice(at.value.start, at.value.end);
          }
        }
        if (hasSlop) return;
        if (styleTxt == null) return;                       // stilsiz sarmalayıcı
        if (/\bS\.\w+/.test(styleTxt)) return;              // paylaşılan stil (tek yerden yönetilir)
        if (/minHeight/.test(styleTxt)) return;
        // 🔴 v3.6 — NÖBETÇİ, KENDİ TOKENIMA KÖR KALDI.
        //
        // Boşluklar `ARA[20]` / `SP[4]` tokenlarına taşınınca bu kural
        // `padding: 20`u okuyamaz oldu ve İKİ YENİ İHLAL raporladı. Oysa
        // kod değişmedi: 20 hâlâ 20. Yani tokenlaştırma, ölçen tarafı
        // körleştirdi ve nöbetçi kendi iyileştirmemi ihlal sandı.
        //
        // 🆕 SINIF: "BİR DEĞERİ TOKENA TAŞIDIĞINDA, O DEĞERİ OKUYAN HER
        // DENETİMİ DE TAŞIMAK ZORUNDASIN — YOKSA SİSTEMİ İYİLEŞTİRMEK
        // DENETİMİ ZAYIFLATIR."
        //
        // `ARA` değeriyle, `SP` sırayla anahtarlanıyor; ikisi de burada
        // çözülüyor ki kural sayıyı görmeye devam etsin.
        const SP_DEG = { 1: 4, 2: 8, 3: 12, 4: 16, 5: 24, 6: 32 };
        const sayi = (txt, prop) => {
          const dm = txt.match(new RegExp(prop + ":\\s*([\\d.]+)"));
          if (dm) return parseFloat(dm[1]);
          const am = txt.match(new RegExp(prop + ":\\s*ARA\\[(\\d+)\\]"));
          if (am) return parseFloat(am[1]);
          const sm = txt.match(new RegExp(prop + ":\\s*SP\\[(\\d+)\\]"));
          if (sm) return SP_DEG[sm[1]];
          return null;
        };
        const h = sayi(styleTxt, "\\bheight");
        if (h !== null && h >= 44) return;
        const pv = sayi(styleTxt, "paddingVertical");
        if (pv !== null && pv >= 13) return;
        const pad = sayi(styleTxt, "\\bpadding");
        if (pad !== null && pad >= 13) return;
        hits.push(p.node.loc.start.line);
      },
    });
    if (hits.length) {
      console.log(`  ⚠ ${hits.length} adet DOKUNMA HEDEFİ 44px altında (${path.basename(f)}):`);
      console.log(`      satır: ${hits.slice(0, 12).join(", ")}${hits.length > 12 ? " …" : ""}`);
      console.log(`      Çözüm: minHeight: TAP.minHeight  ·  ya da hitSlop  ·  ya da paddingVertical>=13`);
      bad += hits.length;
    }
  }
  return bad;
}

// ============================================================
// BORÇ TAVANI (baseline ratchet)
//
// 🔴 NEDEN TAVAN, NEDEN SIFIR DEĞİL:
// errorSwallowCheck ve tapTargetCheck ilk çalıştırmalarında 204 bulgu
// verdi. Bunların hepsi GERÇEK — ama hepsi de v2.65'ten ÖNCE oradaydı.
// Hepsini bir turda kapatmak, ilgisiz 200 satıra dokunmak demekti;
// bırakıp "204 sorun" basmak ise daha kötüsü: bu betiğin kendi yorumu
// diyor ki "yanlış/gürültülü alarm, denetime bakmayı bıraktırır".
//
// Çözüm ORTA YOL DEĞİL, RATCHET: mevcut sayı tavan olarak yazılır.
// · Tavanın ÜSTÜNE çıkan her yeni ihlal build'i KIRAR (geri kayış yok).
// · Tavanın ALTINA inildiğinde betik bunu söyler ve tavanı düşürmeni ister.
// Yani borç görünür kalır, büyüyemez, ve kapandıkça kilitlenir.
//
// Prop-drop / kontrast / sabit-Türkçe denetimlerinde tavan SIFIRDIR:
// bu üçü v2.65'te tamamen kapatıldı, ilk ihlalde kırmalı.
const DEBT_CEILING = {
  // v2.96: 77 → 75. C3 turunda `visits`/`notifications`/`chat_channels`
  // doğrudan yazımları RPC'ye taşındı ve o çağrılar artık error okuyor.
  // Tavanı DÜŞÜRÜYORUM: kazanılan borç, geri kayabilecek borçtur.
  // v2.97: kapsam genisledi (artik TUM src/*.js taraniyor, yalniz
  // screens.js + App.js degil). Once 55 gorunmustu ama o bir DUSUS degil
  // KORLESMEYDI — bkz. errorSwallowCheck icindeki not.
  // 🔴 v2.97 — SAYI 75'TEN 78'E ÇIKTI VE BU BİR GERİLEME DEĞİL.
  // Kapsam genişledi: bu denetim şimdiye kadar YALNIZ screens.js + App.js'e
  // bakıyordu; `flight.js` ve `social.js` hiç taranmamıştı. Orada duran 7
  // bulgunun 4'ünü düzelttim, 3'ü kaldı (`auth.getSession/getUser` —
  // oturum okuma; hata durumunda zaten null'a düşüyor ve akış onu ayrıca
  // ele alıyor). Gerçek borç 82 imiş; 78'e indi.
  // Tavanı GERÇEK sayıya çekiyorum ki bundan sonraki her artış görünsün.
  errorSwallow: 0,   // v3.9.1 · verify_email_contact ikinci çağrısı kalktı (v3.9: 41)   // v3.9 · şelaleler `Promise.all`a alınırken 15 çağrı yeri error'ü okumaya başladı (v3.7: 56)   // v3.7 · şelale paralelleştirmeleri sırasında iki yer daha error okumaya başladı    // 26 Agu · giris kapisi denetimi: olu `pass2` state silindi, signUp artik `error` VE `data` okuyor · v2.99 olcum 77 · v2.66 ölçümü 77 (dar kapsam), v2.97 gerçek kapsam — `await supabase` error'ü okumayan satır
  // 🔴 v2.74 — SIFIRA İNDİ. 119 dokunma hedefi tek tek `minHeight`
  // ile büyütülmedi (düzen bozulurdu: satır içi bağlantı, çip, küçük
  // "▾" düğmesi hepsi şişerdi). Hepsine `hitSlop={TAP.slop}` eklendi:
  // GÖRÜNEN kutu aynı kalır, DOKUNULABİLİR alan 12px genişler.
  // 20px'lik bir düğme bile 44pt'yi karşılar (20+12+12).
  // Tavan artık 0 — bir tane bile geri gelirse denetim kırmızı olur.
  tapTarget:   0,
};

function ratchet(name, found, ceiling) {
  if (found > ceiling) {
    console.log(`  🔴 GERİ KAYIŞ: ${name} — ${found} bulgu, tavan ${ceiling}. ` +
      `Yeni ihlal eklenmiş; ekleyen düzeltmeli.`);
    return found - ceiling;
  }
  if (found < ceiling) {
    console.log(`  ✓ ${name}: ${found} (tavan ${ceiling}) — borç azaldı. ` +
      `check.js'te DEBT_CEILING.${name} = ${found} yap ki geri kaymasın.`);
  }
  return 0;
}

// Tavanı SIFIR olanlar: v2.65'te tamamen kapatıldı.
problems += propDropCheck(parser);
problems += hardcodedTrCheck(parser);
problems += contrastCheck();

// ============================================================
// 🔴 v2.82 — HUKUKİ METİNDE YER TUTUCU KALDIYSA YAYINA ÇIKAMAZ
//
// `legal.js` içinde `{{SIRKET_UNVAN}}` ve `{{ADRES}}` yer tutucuları
// duruyordu ve HİÇBİR ŞEY bunu engellemiyordu. Yani "veri sorumlusu
// {{SIRKET_UNVAN}}" yazan bir gizlilik politikası mağazaya
// gidebilirdi — hem güven kaybı hem App Store / Google Play reddi
// sebebi (ikisi de erişilebilir ve GEÇERLİ bir politika istiyor).
//
// Bir "sonra doldururuz" notu, doldurulmayı zorlamıyorsa bir dilektir.
// Artık zorluyor.
// ============================================================
function legalPlaceholderCheck() {
  const fs2 = require("fs");
  const hedefler = [
    "src/legal.js",
    "../backoffice/lib/legal.js",
    "../website/lib/legal-source.js",
  ];
  let bulunan = 0;
  for (const h of hedefler) {
    const yol = require("path").join(__dirname, h);
    if (!fs2.existsSync(yol)) continue;
    const icerik = fs2.readFileSync(yol, "utf8");
    // Yalnız GERÇEK atamalarda ara — açıklama satırlarında yer tutucu
    // adının geçmesi normal (nasıl doldurulacağını anlatıyor).
    const m = icerik.match(/^\s*const\s+(COMPANY|ADDRESS|MERSIS|KEP)\s*=\s*"\{\{[^"]*\}\}"/gm);
    if (m) {
      console.log(`  🔴 HUKUKİ METİN EKSİK: ${h} — ${m.length} yer tutucu hâlâ dolu değil`);
      m.forEach(x => console.log(`      ${x.trim()}`));
      bulunan += m.length;
    }
  }
  if (bulunan) {
    console.log("      Doldurulacak yer: rnapp/src/legal.js en üstteki üç satır.");
    console.log("      Şirket yoksa gerçek kişi de olur — dosyadaki örneğe bak.");
    return 1;
  }
  return 0;
}
problems += legalPlaceholderCheck();

// ============================================================
// 🔴 v2.84 · SABİT KAP YOLU DENETİMİ
//
// VARLIK SEBEBİ, 19 Ağustos'ta Gokberk'in ekranında görülen hata:
//     Error: Cannot find module '\home\claude\rnapp\src\i18n.js'
//
// `render_check/` altındaki ON JS dosyası `/home/claude/rnapp` yolunu
// SABİT taşıyordu. O yol yalnız benim Linux kabımda var. Yani
// `npm run render` onun makinesinde HİÇ çalışmadı — ben ise her
// teslimde "render → 0 · 16 ekran" yazdım.
//
// Bu dersin Python tarafı v1.94'te `ll_paths.py` ile öğrenilmişti.
// JS tarafı öğrenmedi ve düzeltilen kopyanın gölgesinde bir yıl
// görünmez kaldı.
//
// 🆕 SINIF: **"BİR DERSİN BİR DİLDE ÖĞRENİLMESİ, DİĞERİNDE
// ÖĞRENİLDİĞİ ANLAMINA GELMEZ."**
//
// Artık kaynak ağacında `/home/claude` geçen her satır build'i durdurur.
// (Yorum satırları hariç: ll_paths.js bu hatayı ANLATIYOR.)
// ============================================================
function kapYoluCheck() {
  const fs2 = require("fs");
  const pathm = require("path");
  const kok = __dirname;
  const bulunan = [];
  function tara(dir) {
    for (const ad of fs2.readdirSync(dir)) {
      if (ad === "node_modules" || ad === ".git" || ad === ".expo") continue;
      // 🔴 DENETIM KENDINI TARAMAZ: bu dosyanin ARADIGI dizgi de bir
      // eslesmedir. Ilk kosuda kendini yakaladi. Ayni tuzagi website
      // check.js'inde de yasamistik (oradaki not: "denetimin kendi
      // metnini bulgu saymasi, gercek bulgulari gurultuye gomer").
      if (ad === "check.js" && dir === kok) continue;
      const tam = pathm.join(dir, ad);
      const st = fs2.statSync(tam);
      // iç içe kopya (rnapp/rnapp) ayrı nöbetçinin işi; burada taranmaz
      if (st.isDirectory() && dir === kok && fs2.existsSync(pathm.join(tam, "package.json"))) continue;
      if (st.isDirectory()) { tara(tam); continue; }
      if (!/\.(js|jsx|json)$/.test(ad)) continue;
      const src = fs2.readFileSync(tam, "utf8");
      src.split("\n").forEach((satir, i) => {
        // Yorum satirlari muaf: bu kusuru ANLATAN metinler de eslesir.
        const t = satir.trim();
        if (t.startsWith("//") || t.startsWith("*") || t.startsWith("/*")) return;
        if (satir.includes("/home/claude") || satir.includes("/mnt/user-data")) {
          bulunan.push(`${pathm.relative(kok, tam)}:${i + 1}  ${t.slice(0, 70)}`);
        }
      });
    }
  }
  tara(kok);
  if (bulunan.length) {
    console.log(`  ✗ SABIT KAP YOLU — ${bulunan.length} satir yalniz Claude'un kabinda calisir:`);
    bulunan.slice(0, 8).forEach(b => console.log(`      ${b}`));
    if (bulunan.length > 8) console.log(`      ... ve ${bulunan.length - 8} satir daha`);
    console.log("      Cozum: render_check/ll_paths.js (JS) veya ll_paths.py (Python) kullan.");
    return bulunan.length;
  }
  return 0;
}

problems += kapYoluCheck();

// ============================================================
// 🔴 13 EYLÜL (Gökberk md.9) — DÜĞME METNİ ÜSTE YAPIŞIYOR
// "buradaki butonların textleri üst yapışık gibi."
// Kök neden: `<Text style={{ flex: 1 }}>` bir SÜTUN kabın içinde. RN'de
// varsayılan `flexDirection` "column"dur; sütunda `flex: 1` metni DİKEY
// gerdirir, gerilmiş kutunun içinde yazı üste yapışır ve kabın
// `justifyContent: "center"`i işe yaramaz.
// Bu sınıf 24 Ağustos'ta bir kez teşhis edilmişti; nöbetçisi yazılmadığı
// için başka bir ekranda geri geldi. Artık yazılı.
// 🆕 SINIF: "BİR KUSURU DÜZELTİP NÖBETÇİSİNİ YAZMAZSAN, TEŞHİSİ DEĞİL
// YALNIZ O ÖRNEĞİ ÇÖZMÜŞ OLURSUN."
// ============================================================
problems += (function dikeyOrtalamaDenetimi() {
  const fs2 = require("fs"), pathm = require("path");
  const kok = pathm.join(__dirname, "src");
  const bulunan = [];

  // ⚠️ ETİKETİ DÜZENLİ İFADEYLE AYIRAMAZSIN. İlk sürümde `[^>]*?` ile
  // kestim; `onPress={() => …}` içindeki OK İŞARETİ bir `>` olduğu için
  // etiket erken bitiyor ve `style` hiç görünmüyordu. Mutasyon testi
  // (kusuru geri koyup nöbetçiyi koşturmak) bunu yakaladı — yoksa
  // "temiz" diyen ama hiçbir şeye bakmayan bir nöbetçi yazmış olacaktım.
  // 🆕 SINIF: "BİR NÖBETÇİYİ YAZDIKTAN SONRA KUSURU GERİ KOYUP DENE —
  // YEŞİL YANAN NÖBETÇİ, ÇALIŞAN NÖBETÇİ DEMEK DEĞİLDİR."
  function etiketleriAyir(src) {
    const cikti = [];
    for (let i = 0; i < src.length; i++) {
      if (src[i] !== "<") continue;
      let j = i + 1, kapanis = false;
      if (src[j] === "/") { kapanis = true; j++; }
      const ad0 = j;
      while (j < src.length && /[A-Za-z0-9.]/.test(src[j])) j++;
      const etiket = src.slice(ad0, j);
      if (!etiket || !/^[A-Z]/.test(etiket)) continue;
      // süslü ve tırnak farkında ilerle
      let derin = 0, tirnak = null, k = j;
      for (; k < src.length; k++) {
        const c = src[k];
        if (tirnak) { if (c === "\\") k++; else if (c === tirnak) tirnak = null; continue; }
        if (c === "\"" || c === "'" || c === "`") { tirnak = c; continue; }
        if (c === "{") derin++;
        else if (c === "}") derin--;
        else if (c === ">" && derin === 0) break;
      }
      const govde = src.slice(j, k);
      cikti.push({ i, etiket, kapanis, nitelik: govde, kendi: /\/\s*$/.test(govde) });
      i = k;
    }
    return cikti;
  }

  function tara(dir) {
    for (const ad of fs2.readdirSync(dir)) {
      const tam = pathm.join(dir, ad), st = fs2.statSync(tam);
      if (st.isDirectory()) { tara(tam); continue; }
      if (!/\.js$/.test(ad)) continue;
      const src = fs2.readFileSync(tam, "utf8");
      const yigin = [];
      for (const e of etiketleriAyir(src)) {
        if (e.kapanis) {
          for (let i = yigin.length - 1; i >= 0; i--) {
            if (yigin[i].etiket === e.etiket) { yigin.length = i; break; }
          }
          continue;
        }
        if (e.etiket === "Text" && /\bflex:\s*1\b/.test(e.nitelik)) {
          const ebeveyn = yigin[yigin.length - 1];
          if (ebeveyn && !/flexDirection:\s*"row"/.test(ebeveyn.nitelik)
              && /justifyContent:\s*"center"/.test(ebeveyn.nitelik)
              && /\b(height|minHeight):/.test(ebeveyn.nitelik)) {
            const satir = src.slice(0, e.i).split("\n").length;
            bulunan.push(`${pathm.relative(pathm.dirname(__dirname), tam)}:${satir}  <Text flex:1> sutun kabin icinde (<${ebeveyn.etiket}>)`);
          }
        }
        if (!e.kendi) yigin.push(e);
      }
    }
  }
  tara(kok);
  if (bulunan.length) {
    console.log(`  ✗ DIKEY ORTALAMA BOZUK — ${bulunan.length} metin uste yapisir:`);
    bulunan.slice(0, 8).forEach(b => console.log("      " + b));
    console.log("      Cozum: sutun kapta Text'ten `flex: 1` kaldir.");
    return bulunan.length;
  }
  console.log("  ✓ sutun kapta dikey gerdirilmis metin yok");
  return 0;
})();

// ============================================================
// 🔴 13 EYLÜL (Gökberk md.5, 5.1) — DURUM ÇUBUĞU PAYI
// "headerdaki akış başlığı telefonun üstteki simgeleri ile çakışıyor.
//  Bunun yaşandığı tüm sayfalarda düzeltmemiz lazım."
// Kök neden: başlık çubuğunun üst payını KOMŞUSU (`BrandBar`) taşıyordu.
// `marka={false}` verilen ekranlarda o komşu hiç çizilmiyor ve başlık
// y=0'dan başlıyordu. Pay `Bar`ın kendisine taşındı (`ustPay`).
// Bu nöbetçi o bağı kilitler: `Hdr` payı geçiriyor mu, `Bar` kullanıyor mu.
// (Stub RN `style`i düşürdüğü için mount testi bunu ÖLÇEMEZ — bu yüzden
// denetim kaynak düzeyinde; neyi kanıtladığını da böyle söylüyor.)
// 🆕 SINIF: "BİR PAYI KOMŞU BİLEŞENİN TAŞIMASI, O KOMŞU ÇİZİLMEDİĞİ GÜN
// PAYIN DA YOK OLMASI DEMEKTİR."
// ============================================================
problems += (function ustPayDenetimi() {
  const fs2 = require("fs"), pathm = require("path");
  const ui = fs2.readFileSync(pathm.join(__dirname, "src", "ui.js"), "utf8");
  const eksik = [];
  if (!/function Bar\(\{[^}]*ustPay/.test(ui)) eksik.push("Bar imzasinda ustPay yok");
  if (!/paddingTop:\s*SP\[3\]\s*\+\s*\(ustPay/.test(ui)) eksik.push("Bar ustPay'i paddingTop'a eklemiyor");
  if (!/ustPay=\{marka \|\| kahraman \? 0 : TOPPAD \+ 6\}/.test(ui)) eksik.push("Hdr markasiz dalda ustPay gecirmiyor");
  if (eksik.length) {
    console.log("  ✗ DURUM CUBUGU PAYI KOPTU:");
    eksik.forEach(e => console.log("      " + e));
    return eksik.length;
  }
  console.log("  ✓ markasiz basliklar durum cubugu payini kendileri tasiyor");
  return 0;
})();

// ============================================================
// 🔴 13 EYLÜL (Gökberk md.12) — NESNE METNE DÖNÜŞÜYOR
// Ekranda "Kadın Güvenlik Modu stilMetin=[object Object]" yazıyordu.
// Sebep: bir prop, şablon dizesinin İÇİNE kaymış —
//     metin={`${t.safetyWSM}\n  stilMetin=${{ color: ... }}`}
// JS bunu hata saymaz; nesneyi sessizce "[object Object]" yapar.
// Üç ayrı ekranda aynı kaza vardı ve hiçbir nöbetçi görmüyordu.
// 🆕 SINIF: "BİR PROP'U DİZENİN İÇİNE YAZARSAN JS HATA VERMEZ —
// NESNEYİ SESSİZCE METNE ÇEVİRİR."
// ============================================================
problems += (function nesneMetinDenetimi() {
  const fs2 = require("fs"), pathm = require("path");
  const kok = __dirname, bulunan = [];
  function tara(dir) {
    for (const ad of fs2.readdirSync(dir)) {
      if (["node_modules", ".git", ".expo", "arsiv", "web_sahne"].includes(ad)) continue;
      if (ad.startsWith("_yedek")) continue;
      const tam = pathm.join(dir, ad), st = fs2.statSync(tam);
      if (st.isDirectory()) { tara(tam); continue; }
      if (!/\.(js|jsx)$/.test(ad) || ad === "check.js") continue;
      const src = fs2.readFileSync(tam, "utf8");
      src.split("\n").forEach((satir, i) => {
        const t = satir.trim();
        if (t.startsWith("//") || t.startsWith("*") || t.startsWith("/*")) return;
        // şablon dizesi içinde `${{` → nesne interpolasyonu
        if (/\$\{\s*[{[]/.test(satir)) {
          bulunan.push(`${pathm.relative(kok, tam)}:${i + 1}  ${t.slice(0, 70)}`);
        }
      });
    }
  }
  tara(kok);
  if (bulunan.length) {
    console.log(`  ✗ NESNE METNE DONUSUYOR — ${bulunan.length} satir "[object Object]" yazar:`);
    bulunan.slice(0, 8).forEach(b => console.log(`      ${b}`));
    console.log("      Cozum: prop'u dizenin DISINA cikar.");
    return bulunan.length;
  }
  console.log("  ✓ sablon dizesine kacmis nesne yok");
  return 0;
})();

// ============================================================
// 🔴 8 EYLÜL — İÇ İÇE PROJE KLASÖRÜ (BO'daki nöbetçinin aynısı, app'e)
// Gökberk'in kurulumunda `Rename-Item .\rnapp` "başka bir işlem
// kullanıyor" diye düştü (klasör VS Code / Metro'da açıktı), sonraki
// `Move-Item` yeni kopyayı ESKİ klasörün İÇİNE koydu:
// C:\LoungeLink\rnapp\rnapp. Kap yolu denetimi o kopyanın check.js'ini
// buldu ("rnapp\check.js:1157") ve asıl sorunu perdeledi.
// 🆕 SINIF: "BİR ADIM DÜŞÜNCE SONRAKİ ADIMLARIN 'BAŞARISI', HATAYI
// YENİ BİR YERE TAŞIMAKTIR — REHBER İLK HATADA DURMALI."
// ============================================================
problems += (function icIceKlasorDenetimi() {
  const fs2 = require("fs"), pathm = require("path");
  const bulunan = [];
  for (const e of fs2.readdirSync(__dirname, { withFileTypes: true })) {
    if (!e.isDirectory()) continue;
    if (["node_modules", ".expo", ".git", "android", "ios"].includes(e.name) || e.name.startsWith("_yedek")) continue;
    const pj = pathm.join(__dirname, e.name, "package.json");
    if (!fs2.existsSync(pj)) continue;
    let ad = "?";
    try { ad = JSON.parse(fs2.readFileSync(pj, "utf8")).name || "?"; } catch (e2) { ad = "?"; }
    if (ad === "loungelink") bulunan.push(e.name + "/package.json");
  }
  if (!bulunan.length) { console.log("  ✓ ic ice proje klasoru yok"); return 0; }
  console.log("  ✗ IC ICE PROJE KLASORU — hangi kopyayi build ettigin belirsiz:");
  for (const b of bulunan) console.log("      " + b);
  console.log("      Cozum (PowerShell, C:\\LoungeLink icinde):");
  console.log("        Move-Item .\\rnapp\\rnapp .\\rnapp_yeni_kopya");
  console.log("        Rename-Item .\\rnapp rnapp_arsiv_ESKI   (VS Code / Metro kapali olmali)");
  console.log("        Rename-Item .\\rnapp_yeni_kopya rnapp");
  return 1;
})();


// Tavanlı olanlar: borç görünür, büyüyemez.
problems += ratchet("errorSwallow", errorSwallowCheck(files), DEBT_CEILING.errorSwallow);
problems += ratchet("tapTarget", tapTargetCheck(parser), DEBT_CEILING.tapTarget);

if (!babelAvailable) {
  console.log("  ⚠ @babel/parser YOK -> sezgisel mod. Gercek kontrol icin bu betigi");
  console.log("    projenin kendi makinesinde (npm install sonrasi) calistir.");
}
console.log(problems === 0 ? "✓ Denetim temiz — build'e hazir" : `✗ ${problems} sorun bulundu`);
// ============================================================
// 🔴 8 EYLÜL — KİLİT DOSYASI package.json İLE AYNI MI?
// `yoga-layout` package.json'a eklendi, package-lock.json'a girmedi
// (kabında `npm install --no-save`). Sonuç Gökberk'te: `npm ci` →
// "Missing: yoga-layout@3.2.1 from lock file" — ve EAS de aynı komutu
// koşar: build ilk adımda düşer. Kabımda node_modules zaten doluydu,
// bu yüzden hiçbir denetim fark etmedi.
// 🆕 SINIF: "ÇALIŞAN BİR KAP, KURULUMU DOĞRULAMAZ — KURULUMU ANCAK
// KİLİT DOSYASI DOĞRULAR; ONU DA DENETLEMEK GEREKİR."
// ============================================================
problems += (function kilitCheck() {
  const fs2 = require("fs"), pathm = require("path");
  let pj, lock;
  try {
    pj = JSON.parse(fs2.readFileSync(pathm.join(__dirname, "package.json"), "utf8"));
    lock = JSON.parse(fs2.readFileSync(pathm.join(__dirname, "package-lock.json"), "utf8"));
  } catch (e) { console.log("  ✗ package.json / package-lock.json okunamadi: " + e.message); return 1; }
  const pk = lock.packages || {};
  const eksik = [];
  for (const grup of ["dependencies", "devDependencies"]) {
    for (const [ad, ist] of Object.entries(pj[grup] || {})) {
      const k = pk["node_modules/" + ad];
      if (!k) { eksik.push(ad + "@" + ist + " (kilitte yok)"); continue; }
      const sabit = /^\d/.test(ist) ? ist : null;   // yalniz sabit surumleri kiyasla
      if (sabit && k.version !== sabit) eksik.push(ad + " package.json " + sabit + " · kilit " + k.version);
    }
  }
  // 🔴 13 EYLUL: BU KAPI YALNIZ BAGIMLILIKLARI KIYASLIYORDU ve kilit
  // dosyasinin KENDI `version` alani 5.8.0'da KALMISTI — package.json
  // 5.9.0 derken. `npm ci` bunu yutuyor (olculdu: cikis 0, 944 paket),
  // yani zarari calismada degil KAYITTA: paketin icindeki iki dosya iki
  // farkli surum soyluyor ve "hangisi dogru" sorusu cevapsiz kaliyor.
  // 🆕 SINIF: "IKI DOSYA AYNI GERCEGI SOYLEMEK ZORUNDAYSA, IKISINI DE
  // DENETLE — YALNIZ BIRINI OLCEN KAPI DIGERININ BAYATLAMASINI GORMEZ."
  // Cozum: `npm install --package-lock-only` ya da elle esitle.
  const lv = [lock.version, (pk[""] || {}).version];
  if (lv.some(v => v && v !== pj.version)) {
    console.log("  ✗ KILIT DOSYASININ SURUM ALANI BAYAT: package.json " + pj.version +
                " · kilit " + lv.filter(Boolean).join(" / "));
    console.log("      Cozum: npm install --package-lock-only");
    return 1;
  }
  if (!eksik.length) { console.log("  ✓ package-lock.json package.json ile ayni (surum + bagimliliklar)"); return 0; }
  console.log("  ✗ KILIT DOSYASI GERIDE — `npm ci` ve EAS build ilk adimda duser:");
  for (const e of eksik) console.log("      " + e);
  console.log("      Cozum: npm install --package-lock-only");
  return 1;
})();

process.exit(problems === 0 ? 0 : 1);
