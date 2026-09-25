#!/usr/bin/env node
/**
 * render_check/runtime_fallback_test.js
 *
 * ============================================================
 * NE KANITLAR: SQL 212'nin app ucu (`src/runtime.js` — `client_flags`
 * ve `i18n_overrides`) SUNUCUYA ULAŞILAMADIĞINDA uygulamayı KIRMIYOR.
 *
 * Neden tam olarak burası riskli:
 *   · `runtimeYukle()` App.js'in İLK effect'inde, oturum açılmadan
 *     ÖNCE çalışıyor (App.js:59). Orada atılan bir istisna ilk boyayı
 *     alır — beyaz ekran.
 *   · `t` artık `D[lang]` değil `sozluk(lang)` (App.js:55). Eğer
 *     `sozluk()` üst katman bozukken `undefined` dönerse EKRANDAKİ
 *     HER METİN kaybolur.
 *   · Bayraklar `bayrak("referral")` gibi yerlerde EKRAN AÇIP KAPATIYOR
 *     (screens.js:5397). Sunucu yoksa "kapalı" varsayılırsa, ağı olmayan
 *     kullanıcının yarısı ürünü göremez.
 *
 * ÖLÇÜLEN DÖRT DURUM:
 *   A) İKİ RPC DE 42501 döner   → varsayılanlara düşülür, log YAZILIR
 *   B) İKİ RPC DE AĞ HATASI atar → aynı
 *   C) App.js baştan sona mount → beyaz ekran YOK, metinler Türkçe
 *   D) Bozuk/çöp veri dönerse   → çökmez, varsayılan korunur
 *
 * NOT: `runtime.js` bir TEKİLdir (modül düzeyinde durum tutar). Bu
 * yüzden sıra önemli: önce başarısız durumlar, en sonda başarılı
 * durum ölçülüyor ki bir öncekinin kalıntısı sonrakini yanıltmasın.
 */
const { S, D, mount, settle, setCfg, React, renderer, memStore } = require("./harness");

const results = [];
function chk(ad, kosul, kanit) {
  results.push({ ad, ok: !!kosul });
  console.log(`  ${kosul ? "✓" : "✗"} ${ad}${kanit !== undefined ? "  → " + kanit : ""}`);
}

const RT = require("../src/runtime");
const t = D.tr;

// runtime.js'in VARSAYILANLARI (dosyadan okunan sözleşme)
const BEKLENEN_VARSAYILAN = {
  marketplace: true, referral: true, partner_channel: true,
  delay_mode: false, day_pass: false, b2b: false,
};

process.on("unhandledRejection", (e) => {
  console.log("  🔴 YAKALANMAMIŞ REDDETME (bu tek başına bir hatadır): " + e);
  results.push({ ad: "yakalanmamış reddetme", ok: false });
});

async function run() {
  console.log("=".repeat(72));
  console.log("client_flags / i18n_overrides DÜŞTÜĞÜNDE UYGULAMA AYAKTA MI? (SQL 212)");
  console.log("=".repeat(72));

  // ---------- A) İKİ RPC DE 42501 ----------
  console.log("\n--- A) İki RPC de 42501 (izin yok) dönüyor");
  Object.keys(memStore).forEach(k => delete memStore[k]);   // önbellek boş: ilk açılış
  setCfg({
    rpc: {
      client_flags:   { __error: "permission denied for function client_flags", __code: "42501" },
      i18n_overrides: { __error: "permission denied for function i18n_overrides", __code: "42501" },
    },
    tables: {},
  });
  let patladi = null;
  try { await RT.runtimeYukle(); await RT.runtimeTazele(); }
  catch (e) { patladi = e; }
  chk("A1. runtimeYukle/Tazele istisna ATMADI", !patladi, patladi ? String(patladi.message) : "temiz");

  const b = RT.tumBayraklar();
  const esit = Object.entries(BEKLENEN_VARSAYILAN).every(([k, v]) => b[k] === v);
  chk("A2. Bayraklar VARSAYILANA düştü", esit, JSON.stringify(b));
  chk("A3. Kill-switch'ler AÇIK kaldı (ağ yokluğu pazarı kapatmıyor)",
      RT.bayrak("marketplace") === true && RT.bayrak("referral") === true &&
      RT.bayrak("partner_channel") === true, "marketplace/referral/partner_channel = true");
  chk("A4. Riskli özellikler KAPALI kaldı (ağ yokluğu ödeme akışını açmıyor)",
      RT.bayrak("day_pass") === false && RT.bayrak("b2b") === false &&
      RT.bayrak("delay_mode") === false, "day_pass/b2b/delay_mode = false");
  chk("A5. Bilinmeyen bayrak sorulunca çökmüyor",
      RT.bayrak("boyle_bir_bayrak_yok") === false, "false");

  const sz = RT.sozluk("tr");
  chk("A6. sozluk('tr') derli sözlüğü döndürdü (metinler kaybolmadı)",
      sz && typeof sz === "object" && sz.navHome === D.tr.navHome && Object.keys(sz).length > 1000,
      Object.keys(sz || {}).length + " anahtar · navHome=\"" + (sz && sz.navHome) + "\"");
  chk("A7. sozluk('en') de sağlam", RT.sozluk("en").navHome === D.en.navHome,
      "\"" + RT.sozluk("en").navHome + "\"");
  chk("A8. Bilinmeyen dil istenirse TR'ye düşüyor (undefined DEĞİL)",
      RT.sozluk("de") && RT.sozluk("de").navHome === D.tr.navHome, "tr yedeği");

  // 🔴 SESSİZ DEĞİL Mİ? runtime.js'in kendi yorumu "hata kaydına yazılır"
  // diyor. Söz tutuluyor mu diye ÖLÇÜYORUM — yorum kanıt değildir.
  const loglar = globalThis.__CALLS.filter(c => c.kind === "logError").map(c => c.a[0]);
  chk("A9. İKİ hata da logError'a yazıldı (sessiz yutma yok)",
      loglar.includes("client_flags") && loglar.includes("i18n_overrides"),
      JSON.stringify(loglar));

  // ---------- B) AĞ HATASI (istisna atılıyor) ----------
  console.log("\n--- B) RPC ağ hatası atıyor (offline)");
  setCfg({
    rpc: {
      client_flags:   () => { throw new Error("Network request failed"); },
      i18n_overrides: () => { throw new Error("Network request failed"); },
    },
    tables: {},
  });
  patladi = null;
  try { await RT.runtimeTazele(); } catch (e) { patladi = e; }
  chk("B1. runtimeTazele ağ hatasını YUTTU (çökme yok)", !patladi,
      patladi ? String(patladi.message) : "temiz");
  chk("B2. Bayraklar hâlâ varsayılan",
      Object.entries(BEKLENEN_VARSAYILAN).every(([k, v]) => RT.bayrak(k) === v), "değişmedi");
  chk("B3. Sözlük hâlâ dolu", Object.keys(RT.sozluk("tr")).length > 1000,
      Object.keys(RT.sozluk("tr")).length + " anahtar");

  // ---------- D) ÇÖP VERİ ----------
  console.log("\n--- D) Sunucu ÇÖP döndürüyor (tip sözleşmesi bozuk)");
  // Çöp veri GELMEDEN ÖNCEKİ anahtar sayısı — kıyas noktası bu.
  const ONCEKI_ANAHTAR = Object.keys(D.tr).length;
  setCfg({
    rpc: {
      client_flags: "bu bir nesne degil",                   // jsonb yerine metin
      i18n_overrides: [{ hicbir: "sey" }, null, "cop"],     // beklenen alanlar yok
    },
    tables: {},
  });
  patladi = null;
  try { await RT.runtimeTazele(); } catch (e) { patladi = e; }
  chk("D1. Çöp veri istisna ATMADI", !patladi, patladi ? String(patladi.message) : "temiz");
  chk("D2. Bayraklar bozulmadı (metin gelince nesne sanılmadı)",
      RT.bayrak("marketplace") === true && RT.bayrak("day_pass") === false,
      JSON.stringify(RT.tumBayraklar()));
  chk("D3. Sözlük bozulmadı (çöp satırlar üst katmana yazılmadı)",
      RT.sozluk("tr").navHome === D.tr.navHome && !("hicbir" in RT.sozluk("tr")),
      "\"" + RT.sozluk("tr").navHome + "\"");
  chk("D4. Derli sözlük MUTASYONA UĞRAMADI (D.tr hâlâ temiz)",
      // v2.78 — SABİT SAYI YERİNE DEĞİŞMEZLİK. Test "1136 anahtar" diye
      // sabit bir sayı bekliyordu; sözlüğe yeni metin eklenince (24 anahtar)
      // kırmızı yandı. Oysa testin SORDUĞU şey "sözlük büyüdü mü" değil,
      // "üst katman derli sözlüğü KİRLETTİ mi". Doğru ölçüm: çağrı
      // öncesi/sonrası anahtar sayısı AYNI kalmalı — sayının kendisi
      // ne olursa olsun.
      D.tr.navHome === RT.sozluk("tr").navHome && Object.keys(D.tr).length === ONCEKI_ANAHTAR,
      Object.keys(D.tr).length + " anahtar");

  // ---------- C) TÜM UYGULAMA MOUNT ----------
  console.log("\n--- C) App.js baştan sona mount: beyaz ekran var mı?");
  Object.keys(memStore).forEach(k => delete memStore[k]);
  const UID = "11111111-1111-4111-8111-111111111111";
  globalThis.__SESSION = { user: { id: UID, email: "host@test.local" } };
  setCfg({
    rpc: {
      client_flags:   { __error: "permission denied for function client_flags", __code: "42501" },
      i18n_overrides: { __error: "permission denied for function i18n_overrides", __code: "42501" },
      has_active_session: false,
      expire_stale_sessions: { ok: true },
    },
    tables: {
      airports: [{ code: "IST", name: "İstanbul Havalimanı", city: "İstanbul" }],
      users: [{ id: UID, role: "guest", is_staff: false }],
      profiles: [{ user_id: UID, access_source: "card", show_on_discovery: true }],
      verifications: [{ phone_verified: true }],
      // 🔴 SATIR EKSİKSİZ OLMALI — ÖLÇÜMLE ÖĞRENİLDİ.
      // İlk denemede `visits: [{ id: "v1" }]` yazmıştım ve ekranda
      //   "Seyahatine en uygun ilanlar üstte: undefined · undefined"
      // çıktı (screens.js:9668 — `trip &&` nesnenin VARLIĞINI kontrol
      // ediyor, ALANLARINI değil). Bunu "hata" diye raporlamadan önce
      // şemaya baktım:
      //   visits.airport_code  NOT NULL
      //   visits.visit_date    NOT NULL
      // Yani CANLIDA bu satır asla yarım gelemez; hata TESTİN
      // KURGUSUNDAYDI. Eksik sahte veriyle bulunan "hata", hata değildir.
      visits: [{ id: "v1", airport_code: "IST", visit_date: "2026-09-01" }],
      trust_scores: [], availabilities: [], requests: [], sessions: [],
      notifications: [], consents: [{ id: 1 }],
    },
  });
  const App = require("../App.js").default;
  let m = null, hata = null;
  try { m = await mount(App, {}); } catch (e) { hata = e; }
  chk("C1. App mount oldu (istisna yok)", !hata, hata ? String(hata.message).split("\n")[0] : "temiz");
  if (m) {
    const json = m.tree.toJSON();
    const tx = m.texts();
    chk("C2. Ekranda gerçek içerik var (BEYAZ EKRAN DEĞİL)",
        !!json && tx.length > 0, tx.length + " metin düğümü");
    chk("C3. Metinler Türkçe sözlükten geliyor (undefined basılmıyor)",
        !tx.some(x => x === "undefined" || x.includes("undefined")),
        tx.slice(0, 6).join(" · ").slice(0, 80));
    chk("C4. Sekme çubuğu çizildi (gezinme ayakta)",
        tx.includes(D.tr.navHome) && tx.includes(D.tr.navProfile),
        `"${D.tr.navHome}" · "${D.tr.navProfile}"`);
    const loglar2 = globalThis.__CALLS.filter(c => c.kind === "logError").map(c => c.a[0]);
    chk("C5. Açılışta iki RPC de denendi ve hataları kaydedildi",
        globalThis.__CALLS.some(c => c.kind === "rpc" && c.fn === "client_flags") &&
        globalThis.__CALLS.some(c => c.kind === "rpc" && c.fn === "i18n_overrides"),
        "çağrıldı; log=" + JSON.stringify([...new Set(loglar2)]));
    await m.unmount();
  }

  // ---------- E) NEGATİF KONTROL ----------
  // Test gerçekten bir şey ölçüyor mu? Sunucu ÇALIŞIRSA değerler
  // gerçekten DEĞİŞMELİ. Değişmiyorsa yukarıdaki "varsayılan" yeşilleri
  // anlamsızdır (her koşulda yeşil yanan test, test değildir).
  console.log("\n--- E) NEGATİF KONTROL: sunucu çalışırsa değerler DEĞİŞİYOR mu?");
  setCfg({
    rpc: {
      client_flags: { marketplace: false, day_pass: true },
      i18n_overrides: [{ dil: "tr", anahtar: "navHome", metin: "ANA ÜS" }],
    },
    tables: {},
  });
  await RT.runtimeTazele();
  chk("E1. Sunucu bayrağı VARSAYILANI EZDİ", RT.bayrak("marketplace") === false,
      "marketplace: true → " + RT.bayrak("marketplace"));
  chk("E2. Riskli bayrak sunucudan AÇILABİLDİ", RT.bayrak("day_pass") === true,
      "day_pass: false → " + RT.bayrak("day_pass"));
  chk("E3. Metin düzeltmesi sözlüğe BİNDİ", RT.sozluk("tr").navHome === "ANA ÜS",
      "\"" + D.tr.navHome + "\" → \"" + RT.sozluk("tr").navHome + "\"");
  chk("E4. Derli sözlük yine de kirlenmedi (D.tr korundu)",
      D.tr.navHome !== "ANA ÜS", "D.tr.navHome = \"" + D.tr.navHome + "\"");
  chk("E5. Ezilmeyen anahtarlar derli sözlükten gelmeye devam ediyor",
      RT.sozluk("tr").navProfile === D.tr.navProfile, "\"" + RT.sozluk("tr").navProfile + "\"");

  const bad = results.filter(r => !r.ok);
  console.log("\n" + "-".repeat(72));
  console.log(`Toplam kontrol: ${results.length} · başarısız: ${bad.length}`);
  if (bad.length) { console.log("\n🔴 BAŞARISIZ:"); bad.forEach(x => console.log("  ✗ " + x.ad)); }
  process.exit(bad.length ? 1 : 0);
}

run().catch(e => { console.log("🔴 TEST KOŞUCUSU ÇÖKTÜ: " + (e && e.stack || e)); process.exit(1); });
