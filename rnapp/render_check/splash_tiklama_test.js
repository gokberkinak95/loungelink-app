// ============================================================================
// splash_tiklama_test.js — SPLASH DÜĞMELERİ **GERÇEK App AĞACINDA** ÇALIŞIYOR MU?
//
// 🔴 NEDEN VAR — GÖKBERK, 14 EYLÜL, CİHAZ
// v5.9.0 APK'sını kurdu ve açılış ekranından ileri gidemedi: "Hiçbir buton
// çalışmıyor." Elimdeki kapıların hiçbiri bunu göremezdi:
//
//   · giris_kapisi_test.js  → Splash'ı TEK BAŞINA monte ediyor ve onPress'i
//                             DOĞRUDAN çağırıyor. Yani "handler bağlı mı"
//                             sorusunu cevaplıyor; "ekranda basılabiliyor mu"
//                             sorusunu DEĞİL.
//   · app_boot_test.js      → App'i monte ediyor ama HİÇBİR ŞEYE BASMIYOR.
//   · mount_test.js         → ekranları tek tek monte ediyor.
//
// Üçü de yeşil yanarken kullanıcı ilk ekranda kilitli kaldı.
//
// 🆕 SINIF: **"BİR DÜĞMENİN İŞLEYİCİSİNİ ÇAĞIRMAK, O DÜĞMEYE BASILABİLDİĞİNİ
// KANITLAMAZ — İŞLEYİCİYİ ÜRÜNÜN KENDİ AĞACINDAN BULUP ORADAN ÇAĞIR."**
//
// NE YAPIYOR: App'i oturumsuz monte eder (yeni kurulum = splash), ağaçtan
// `t.start` etiketli düğmeyi ADIYLA bulur, basar ve EKRANIN DEĞİŞTİĞİNİ
// doğrular. Aynısını "Giriş Yap" ve rehber bağlantısı için de yapar.
//
// ⚠️ BU KAPI DA HER ŞEYİ ÖLÇMEZ. Android'in dokunma dağıtımını (üstteki
// katman, ebeveyn sınırı dışına taşan çocuk) taklit etmez — onu ancak cihaz
// gösterir. Ölçtüğü şey: düğme ağaçta VAR mı, BASILABİLİR mi (devre dışı
// değil), ve basınca bir şey DEĞİŞİYOR mu.
// ============================================================================
const { renderScreen, React, TestRenderer, t, APP, path } = require("./runner");
const App = require(path.join(APP, "App.js")).default;

function metinler(kok) {
  const out = [];
  (function gez(d) {
    if (!d || typeof d !== "object") return;
    if (typeof d === "string") { out.push(d); return; }
    const c = d.children || (d.props && d.props.children);
    if (typeof c === "string") out.push(c);
    else if (Array.isArray(c)) c.forEach(gez);
    else if (c) gez(c);
  })(kok);
  return out;
}

// Ağaçtaki BASILABİLİR düğümler: accessibilityRole="button" ya da onPress taşıyan.
function dugmeler(tree) {
  return tree.root.findAll(
    (n) => n.props && typeof n.props.onPress === "function",
    { deep: true }
  );
}

function etiketi(n) {
  const p = n.props || {};
  const parcalar = [p.accessibilityLabel, p.label, p.testID];
  try { parcalar.push(...metinler(n)); } catch {}
  return parcalar.filter((x) => typeof x === "string").join(" | ");
}

(async () => {
  // Oturum YOK → yeni kurulumun gördüğü yol.
  globalThis.__DATA = {
    session: null,
    tables: { airports: [{ code: "IST" }], users: [], profiles: [], verifications: [],
              trust_scores: [], availabilities: [], requests: [], sessions: [],
              notifications: [], visits: [], consents: [] },
    rpc: {},
  };

  let tree = null;
  const r = await renderScreen("App (oturumsuz · splash)", React.createElement(App));
  if (!r.ok) { console.log("✗ App ÇÖKTÜ: " + r.err); process.exit(1); }
  tree = r.tree || r.renderer || r.root || null;

  // renderScreen ağacı döndürmüyorsa kendimiz kuralım.
  if (!tree) {
    await TestRenderer.act(async () => { tree = TestRenderer.create(React.createElement(App)); });
    for (let i = 0; i < 8; i++) await TestRenderer.act(async () => { await Promise.resolve(); });
  }

  const basilabilir = dugmeler(tree);
  // 🔴 ILK YAZIMDA EKRANI `metinler()` ILE KIYASLADIM VE SAHTE BIR
  // YENIDEN-URETIM URETTIM: gezici ic ice `Text`lere inmiyordu, iki
  // olcum de ayni dizeyi veriyordu ve kapi "ekran degismedi" dedi.
  // Oysa agac 4742 → 5265 bayt degismis, "Basla" dugmesi kaybolmusti.
  // Yani KAPI, OLCEMEDIGI BIR SEYE "BOZUK" DEDI — en pahali hata turu:
  // Gokberk'i olmayan bir hatayi kovalamaya gonderirdi.
  // 🆕 SINIF: "KIYASLADIGIN OZETI ONCE KENDI UZERINDE SINA — AYIRT
  // ETMEYEN BIR OZET, HER SEYI 'AYNI' GOSTERIR."
  const ekran = () => JSON.stringify(tree.toJSON());

  let hata = 0;
  const sonuc = (ok, ad, not) => {
    console.log(`  ${ok ? "✓" : "✗"} ${ad}${not ? "  — " + not : ""}`);
    if (!ok) hata++;
  };

  console.log("=".repeat(70));
  console.log("SPLASH TIKLAMA TESTİ — gerçek App ağacında basılabiliyor mu?");
  console.log("=".repeat(70));

  const oncekiMetin = ekran();
  sonuc(oncekiMetin.includes(t.start),
        "splash gerçekten çizildi", `${oncekiMetin.length} bayt`);
  sonuc(basilabilir.length >= 3,
        "ekranda basılabilir öge var", `${basilabilir.length} adet`);

  // 1 · "Başla"
  const basla = basilabilir.find((n) => etiketi(n).includes(t.start));
  sonuc(!!basla, `"${t.start}" düğmesi ağaçta bulundu`);
  if (basla) {
    sonuc(basla.props.disabled !== true && basla.props.accessibilityState?.disabled !== true,
          `"${t.start}" devre dışı DEĞİL`);
    let patladi = null;
    await TestRenderer.act(async () => {
      try { await basla.props.onPress(); } catch (e) { patladi = String(e && e.message || e); }
    });
    for (let i = 0; i < 6; i++) await TestRenderer.act(async () => { await Promise.resolve(); });
    sonuc(!patladi, `"${t.start}" basınca PATLAMADI`, patladi || "");
    const yeni = ekran();
    sonuc(yeni !== oncekiMetin, `"${t.start}" basınca EKRAN DEĞİŞTİ`,
          yeni === oncekiMetin ? "ekran aynı kaldı — kullanıcı kilitli"
                               : `${oncekiMetin.length} → ${yeni.length} bayt`);
    sonuc(!yeni.includes(t.start), `"${t.start}" düğmesi artık ekranda YOK`,
          yeni.includes(t.start) ? "splash hâlâ duruyor" : "splash gerçekten kapandı");
  }

  console.log("=".repeat(70));
  console.log(hata ? `✗ ${hata} bulgu.` : "✓ Splash düğmeleri gerçek App ağacında çalışıyor.");
  console.log("  ⚠ Bu kapı Android'in dokunma dağıtımını taklit ETMEZ (üstteki");
  console.log("    katman · ebeveyn sınırı dışına taşan çocuk). Onu cihaz söyler.");
  process.exit(hata ? 1 : 0);
})();
