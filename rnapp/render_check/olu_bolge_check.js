#!/usr/bin/env node
/**
 * render_check/olu_bolge_check.js
 *
 * ============================================================================
 * ÖLÜ BÖLGE DENETİMİ — TANIMINDAN ÖNCE KULLANILAN `const`/`let`
 *
 * 🔴 NEDEN VAR — 19 EYLÜL, KENDİ YAZDIĞIM HATA
 *
 * `App.js`in `Main` bileşenine bir `useEffect` ekledim ve bağımlılık
 * listesine, 100 satır AŞAĞIDA tanımlı bir `const` yazdım:
 *
 *     }, [session?.user?.id, setRoleState, reload]);   // ← satır 906
 *     ...
 *     const [reload, setReload] = useState(0);         // ← satır 1013
 *
 * Sonuç, gerçek tarayıcıda:
 *     ReferenceError: Cannot access 'reload' before initialization
 *         at Main (...)
 * Yani oturum açtıktan SONRAKİ her ekran beyaz kaldı. 53 sahnenin 30'u.
 *
 * ÜÇ KAPI BUNU GÖRMEDİ VE ÜÇÜ DE HAKLIYDI:
 *   · `check.js`       → sözdizimi kusursuz; bu bir ÇALIŞMA ANI hatası
 *   · `mount_test.js`  → ekranları tek tek mount ediyor, KABUĞU değil
 *   · `app_boot_test`  → `Main`i çiziyor AMA yakalayamıyor:
 *                        `@babel/register` + preset-env (node: current)
 *                        blok kapsamını dönüştürünce ölü bölge KAYBOLUYOR;
 *                        değişken `undefined` oluyor ve hata atmıyor.
 *                        (Mutasyonla ölçtüm: hatayı geri koydum, kapı
 *                         yeşil yandı. Isırmayan bir kapı kapı değildir.)
 *
 * Yakalayan tek şey `web_sahne` oldu — ama o zincirin EN SONUNDA koşuyor:
 * bundle + 53 sahne ≈ 20 dakika.
 *
 * 🆕 SINIF: "BİR HATAYI YAKALAYAN EN UCUZ KAPIYI BUL VE ONU ORAYA TAŞI —
 * 20 DAKİKADA YAKALANAN BİR ÇÖKME 20 SANİYEDE YAKALANABİLİYORSA, KAPI
 * YANLIŞ YERDEDİR."
 *
 * NE ÖLÇÜYOR
 *   Her fonksiyon gövdesinde, `const`/`let` ile tanımlanan bir adın
 *   TANIMINDAN ÖNCEKİ bir ifadede kullanılıp kullanılmadığı.
 *
 * NEYİ ÖLÇMÜYOR — ve neden (yanlış alarmı önlemek için):
 *   · İÇ İÇE FONKSİYON GÖVDELERİ. `function f(){ return reload; }` bir
 *     `const reload`tan önce yazılabilir ve GÜVENLİDİR: gövde çağrıldığında
 *     tanım çoktan yapılmıştır. O yüzden iç fonksiyonlara İNMİYORUZ.
 *   · TEK İSTİSNA: kanca bağımlılık listeleri (`useEffect(fn, [ ... ])`).
 *     O dizi render sırasında, tam o satırda değerlendirilir — iç fonksiyon
 *     değildir. Bu yüzden oraya AYRICA bakıyoruz.
 *   · `var` ölü bölge üretmez (hoist edilir, `undefined` olur); dışarıda.
 *
 * TAVAN 0.
 * ============================================================================
 */
const fs = require("fs");
const path = require("path");
const { parse } = require("@babel/parser");

const KOK = path.dirname(__dirname);
const TAVAN = 0;
const KANCALAR = new Set(["useEffect", "useLayoutEffect", "useMemo", "useCallback", "useImperativeHandle"]);

function dosyalar() {
  const cik = [];
  const atla = new Set(["node_modules", ".git", "android", "ios", ".expo", "web_sahne", "render_check",
                        "assets", "brand", "tasarim_kaynak", "ekranlar_oneri", "dist", "dist_dbg"]);
  (function gez(d) {
    for (const ad of fs.readdirSync(d)) {
      if (atla.has(ad)) continue;
      const p = path.join(d, ad);
      const st = fs.statSync(p);
      if (st.isDirectory()) gez(p);
      else if (ad.endsWith(".js")) cik.push(p);
    }
  })(KOK);
  return cik.sort();
}

// Bir düğümden `const`/`let` ile bağlanan adları topla (desen ayrıştırma dahil).
function baglananlar(dugum, cik) {
  if (!dugum || typeof dugum !== "object") return;
  switch (dugum.type) {
    case "Identifier": cik.add(dugum.name); return;
    case "ObjectPattern": dugum.properties.forEach(p => baglananlar(p.value || p.argument, cik)); return;
    case "ArrayPattern": dugum.elements.forEach(e => e && baglananlar(e, cik)); return;
    case "AssignmentPattern": baglananlar(dugum.left, cik); return;
    case "RestElement": baglananlar(dugum.argument, cik); return;
    default: return;
  }
}

const FONKSIYON = new Set(["FunctionDeclaration", "FunctionExpression", "ArrowFunctionExpression",
                           "ObjectMethod", "ClassMethod"]);

/**
 * ⚠️ KAPSAM BİLEREK DAR: YALNIZ KANCA BAĞIMLILIK DİZİLERİ.
 *
 * İlk yazımda "gövdede tanımından önce kullanılan her ad" diye geniş
 * tuttum ve 14 bulgu verdi — ONDÖRDÜ DE YANLIŞ ALARMDI:
 *     src/ekranlar_ana.js:2014 'uid'  → `async function openCompanionChat`
 *                                       gövdesinin İÇİNDE; o gövde render
 *                                       sırasında çalışmaz, çağrıldığında
 *                                       çalışır ve tanım çoktan yapılmıştır.
 *     src/screens.js:1154 'id'        → `onConfirm={async () => { const id … }}`
 *                                       yani bir JSX olay işleyicisinin içi.
 * Yani "önce kullanılıyor" görünen her şey ölü bölge DEĞİL; ölü bölge
 * yalnız RENDER ANINDA değerlendirilen ifadelerde oluşur.
 *
 * Kanca bağımlılık dizisi tam olarak öyle bir ifadedir: `useEffect`in
 * ikinci argümanı, çağrının yapıldığı satırda, render sırasında
 * değerlendirilir. Benim hatam da oradaydı.
 *
 * 🆕 SINIF: "BİR NÖBETÇİYİ GENİŞ TUTUP YANLIŞ ALARM ÜRETMEK, ONU DAR
 * TUTUP BİR SINIFI KAÇIRMAKTAN DAHA PAHALIDIR — GÜRÜLTÜLÜ NÖBETÇİ
 * KAPATILIR, DAR NÖBETÇİ YAŞAR."
 */
function kancaBagimliliklari(dugum, cik) {
  if (!dugum || typeof dugum !== "object") return;
  if (Array.isArray(dugum)) { dugum.forEach(d => kancaBagimliliklari(d, cik)); return; }
  if (!dugum.type) return;
  if (dugum.type === "CallExpression" && dugum.callee && dugum.callee.type === "Identifier"
      && KANCALAR.has(dugum.callee.name)) {
    const deps = dugum.arguments[dugum.arguments.length - 1];
    if (deps && deps.type === "ArrayExpression") {
      deps.elements.forEach(el => {
        // `a?.b?.c` → yalnız `a` bir referanstır.
        let n = el;
        while (n && (n.type === "MemberExpression" || n.type === "OptionalMemberExpression")) n = n.object;
        if (n && n.type === "Identifier") cik.add(n.name);
      });
    }
    // Kancanın GÖVDESİ render anında çalışmaz; içine inmiyoruz — ama
    // gövdede başka bir kanca olamaz (kancalar iç içe yazılamaz).
    return;
  }
  for (const k of Object.keys(dugum)) {
    if (k === "loc" || k === "start" || k === "end") continue;
    const v = dugum[k];
    if (v && typeof v === "object") kancaBagimliliklari(v, cik);
  }
}

function govdeyiDenetle(govde, dosyaAdi, bulgular) {
  if (!govde || !Array.isArray(govde.body)) return;
  // 1) Bu gövdede `const`/`let` ile tanımlanan her adın SATIRI.
  const tanim = new Map();
  govde.body.forEach(st => {
    if (st.type === "VariableDeclaration" && (st.kind === "const" || st.kind === "let")) {
      st.declarations.forEach(d => {
        const adlar = new Set();
        baglananlar(d.id, adlar);
        adlar.forEach(a => { if (!tanim.has(a)) tanim.set(a, st.loc.start.line); });
      });
    }
  });
  if (tanim.size === 0) return;

  // 2) Sırayla yürü; bir kanca bağımlılık dizisinde HENÜZ TANIMLANMAMIŞ
  //    bir ad geçiyorsa bu, cihazda kesin bir çökmedir.
  const tanimli = new Set();
  govde.body.forEach(st => {
    const kullanilan = new Set();
    kancaBagimliliklari(st, kullanilan);
    kullanilan.forEach(ad => {
      if (tanim.has(ad) && !tanimli.has(ad)) {
        bulgular.push({ dosya: dosyaAdi, ad, kullanim: st.loc.start.line, tanim: tanim.get(ad) });
      }
    });
    if (st.type === "VariableDeclaration" && (st.kind === "const" || st.kind === "let")) {
      st.declarations.forEach(d => { const s2 = new Set(); baglananlar(d.id, s2); s2.forEach(a => tanimli.add(a)); });
    }
  });
}

function main() {
  const bulgular = [];
  let fnSayisi = 0;
  for (const p of dosyalar()) {
    const ad = path.relative(KOK, p).split(path.sep).join("/");
    let agac;
    try {
      agac = parse(fs.readFileSync(p, "utf8"), { sourceType: "module", plugins: ["jsx"] });
    } catch (e) { continue; }
    (function gez(d) {
      if (!d || typeof d !== "object") return;
      if (Array.isArray(d)) { d.forEach(gez); return; }
      if (FONKSIYON.has(d.type) && d.body && d.body.type === "BlockStatement") {
        fnSayisi++;
        govdeyiDenetle(d.body, ad, bulgular);
      }
      for (const k of Object.keys(d)) {
        if (k === "loc") continue;
        const v = d[k];
        if (v && typeof v === "object") gez(v);
      }
    })(agac.program);
  }

  console.log("=".repeat(74));
  console.log("ÖLÜ BÖLGE — kanca bağımlılığında, tanımından ÖNCE kullanılan `const`/`let`");
  console.log("=".repeat(74));
  console.log(`  taranan fonksiyon gövdesi : ${fnSayisi}`);
  console.log("");
  if (bulgular.length) {
    console.log(`  ✗ ${bulgular.length} ölü bölge kullanımı — bunlar CİHAZDA "Cannot access`);
    console.log(`    'X' before initialization" ile ÇÖKER, beyaz ekran bırakır:`);
    for (const b of bulgular) {
      console.log(`        ${b.dosya}:${b.kullanim}  '${b.ad}' kullanılıyor — tanımı satır ${b.tanim}`);
    }
    console.log("");
    console.log("  ÇÖZÜM: tanımı kullanımın ÜSTÜNE taşı (ya da ayrı bir state kullan).");
  } else {
    console.log("  ✓ kanca bağımlılıklarında ölü bölge yok");
  }
  console.log("");
  console.log(`SONUC  bulgu=${bulgular.length}  tavan=${TAVAN}`);
  process.exit(bulgular.length > TAVAN ? 1 : 0);
}

main();
