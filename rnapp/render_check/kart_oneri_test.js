#!/usr/bin/env node
/**
 * render_check/kart_oneri_test.js
 *
 * ============================================================
 * NE KANITLAR: SQL 216'nın app ucu ("HANGİ KARTIMI KULLANAYIM?")
 * HostAvailability ekranında GERÇEKTEN ÇİZİLİYOR mu — ve İKİ HALİ de
 * çalışıyor mu:
 *
 *   A) ÖNERİ VAR   → `hangi_kartimi_kullanayim` {known:true, oneri:{...}}
 *                    döner; kutuda kartın adı, kart tipi, misafir hakkı
 *                    ve uçuş şartı yazmalı.
 *   B) ÖNERİ YOK   → {known:false, oneri:null, neden:"..."} döner;
 *                    kutuda SUNUCUNUN cümlesi yazmalı ("henüz kart
 *                    beyan etmemişsin"). Boş kutu ya da hiç kutu YANLIŞ.
 *   C) KARŞILAŞTIRMA TABLOSU → "tamamını gör" satırına basınca
 *                    `salon_misafir_karsilastirmasi` çağrılmalı ve
 *                    satırlar çizilmeli.
 *   D) RPC DÜŞERSE → 42501 dönen `hangi_kartimi_kullanayim` ekranı
 *                    ÇÖKERTMEMELİ, kutu hiç çizilmemeli, form ayakta
 *                    kalmalı.
 *
 * NEDEN GEREKLİ: mount_test.js bu ekranı SABİT boş veriyle mount
 * ediyor. O koşulda `lounges.maybeSingle()` null döner, `venue_id`
 * bulunamaz ve kutu HİÇ ÇİZİLMEZ — yani mevcut testler bu özelliğin
 * varlığını da yokluğunu da göremez. Mevcut yeşil, kanıt değil.
 *
 * NASIL SÜRÜLÜYOR: kutu ancak havalimanı + salon seçilince çıkıyor.
 * Testte gerçek seçicilerin (`AirportPicker`, `LoungePicker`) onSelect
 * prop'u çağrılıyor — yani kullanıcının yaptığı iki dokunuşun aynısı.
 */
const { S, D, mount, settle, setCfg, renderer } = require("./harness");

const t = D.tr;
const VENUE = "aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa";
const LOUNGE = "bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb";
const session = { user: { id: "00000000-0000-4000-8000-000000000001" } };

const LOUNGES = [{ id: LOUNGE, name: "iGA Lounge — Dış Hat", display_name: "iGA Lounge — Dış Hat",
                   terminal: "", access_types: ["card"], scope: "international",
                   accepts_guests: true, note: null, section: null }];

const HINT = { severity: "warn", confidence: "verified",
               headline: "Misafirin için ücret ödeyebilirsin.",
               detail: "Bu salonda misafir girişi ücretlidir." };

const ONERI_VAR = {
  known: true, kart_sayim: 3, salondaki_kaynak: 7,
  oneri: {
    program: "TK_MS", program_adi: "Turkish Airlines Miles&Smiles", kart_tipi: "ELPL",
    tasiyici: "TK", misafir_hakki: "Ucretsiz misafir hakki var", ucretsiz_adet: 1,
    aile_dahil: true, ucret: "—", ucusa_bagli: "Misafir AYNI UCUSTA olmali",
    azami_saat: 3, uyari: null, kaynak: "https://www.turkishairlines.com",
  },
};

const ONERI_YOK = {
  known: false, oneri: null, kart_sayim: 0, salondaki_kaynak: 7,
  neden: "Henuz bir erisim kaynagi (kart/statu) beyan etmemissin. " +
         "Profil › Lounge Erisim Kurulumu'ndan ekleyince burasi dolar.",
};

const TABLO = [
  { program: "TK_MS", program_adi: "Turkish Airlines Miles&Smiles", kart_tipi: "ELPL",
    bende_var: true, misafir_hakki: "Ucretsiz misafir hakki var" },
  { program: "PRIORITY_PASS", program_adi: "Priority Pass", kart_tipi: null,
    bende_var: false, misafir_hakki: "Misafir alinabilir ama UCRETLI" },
  { program: "DRAGONPASS", program_adi: "DragonPass", kart_tipi: null,
    bende_var: false, misafir_hakki: "Misafir ALINAMAZ" },
];

function baseCfg(kartOneri, tablo) {
  return {
    rpc: {
      lounges_for_airport: LOUNGES,
      carrier_options: [{ code: "TK", name: "Türk Hava Yolları", alliance: "star_alliance" }],
      lounge_hint_for_host: HINT,
      venue_partners: [],
      hangi_kartimi_kullanayim: kartOneri,
      salon_misafir_karsilastirmasi: tablo === undefined ? TABLO : tablo,
    },
    tables: {
      airports: [{ code: "IST", name: "İstanbul Havalimanı", city: "İstanbul" }],
      verifications: [{ phone_verified: true }],
      users: [{ is_staff: false }],
      profiles: [{ guest_capacity: 2, show_on_discovery: true }],
      // 🔴 KUTUNUN KAPISI BU SATIR. `lounges.venue_id` yoksa öneri RPC'si
      // hiç çağrılmaz. mount_test'te tam olarak bu boştu.
      lounges: [{ venue_id: VENUE }],
    },
  };
}

// Kullanıcının iki dokunuşu: havalimanı seç, sonra salon seç.
async function seLounge(m) {
  await renderer.act(async () => {
    m.tree.root.findByType(S.AirportPicker).props.onSelect("IST");
  });
  await settle();
  await renderer.act(async () => {
    m.tree.root.findByType(S.LoungePicker).props.onSelect(LOUNGE);
  });
  await settle();
}

const results = [];
function chk(ad, kosul, kanit) {
  results.push({ ad, ok: !!kosul, kanit });
  console.log(`  ${kosul ? "✓" : "✗"} ${ad}${kanit ? "  → " + kanit : ""}`);
}

process.on("unhandledRejection", (e) => { console.log("  ! yakalanmamis reddetme: " + e); });

async function run() {
  console.log("=".repeat(72));
  console.log('"HANGİ KARTIMI KULLANAYIM" KUTUSU (SQL 216) — GERÇEKTEN ÇİZİLİYOR MU?');
  console.log("=".repeat(72));

  // ---------- A) ÖNERİ VAR ----------
  console.log("\n--- A) Host'un kartı var: öneri çıkmalı");
  setCfg(baseCfg(ONERI_VAR));
  let m = await mount(S.HostAvailability, { t, session, onBack: () => {}, onDone: () => {}, onVerify: () => {} });
  chk("A0. Ekran mount oldu (çökme yok)", !!m.tree.toJSON());
  await seLounge(m);
  let tx = m.texts().join(" | ");
  // 🔴 v2.78 — TEST BOZUK ÇIKTIYI BEKLİYORDU.
  // Beklenti `toUpperCase()` ile kuruluyordu; ekran da öyle yazıyordu,
  // yani test yeşildi ve İKİSİ DE YANLIŞTI: "HANGI KARTINI". Ekran
  // `toLocaleUpperCase("tr-TR")`e geçince test kırmızı yandı — doğru
  // davranış. Beklenti de Türkçeleştirildi; test artık ekranın DOĞRU
  // olmasını istiyor, AYNI olmasını değil.
  chk("A1. Kutu başlığı çizildi", tx.includes(t.whichCardTitle.toLocaleUpperCase("tr-TR")),
      t.whichCardTitle.toLocaleUpperCase("tr-TR"));
  chk("A2. Önerilen kartın adı + tipi yazıyor",
      tx.includes("Turkish Airlines Miles&Smiles") && tx.includes("ELPL"),
      "Turkish Airlines Miles&Smiles · ELPL");
  chk("A3. Misafir hakkı cümlesi sunucudan geldiği gibi yazıyor",
      tx.includes("Ucretsiz misafir hakki var"), "Ucretsiz misafir hakki var");
  chk("A4. Aile eki çizildi", tx.includes("(aile de dahil)"), "(aile de dahil)");
  chk("A5. Uçuş şartı çizildi", tx.includes("Misafir AYNI UCUSTA olmali"),
      "— Misafir AYNI UCUSTA olmali");
  chk("A6. 'tamamını gör' satırı doğru sayıyla",
      tx.includes(t.whichCardAll.replace("{n}", "7")), t.whichCardAll.replace("{n}", "7"));
  chk("A7. RPC doğru parametreyle çağrıldı",
      globalThis.__CALLS.some(c => c.kind === "rpc" && c.fn === "hangi_kartimi_kullanayim" &&
                                   c.args && c.args.p_venue === VENUE),
      "hangi_kartimi_kullanayim({p_venue: " + VENUE.slice(0, 8) + "…})");

  // ---------- C) KARŞILAŞTIRMA TABLOSU ----------
  console.log("\n--- C) 'Tamamını gör' → karşılaştırma tablosu");
  const link = m.tree.root.findAll(n =>
    n.props && typeof n.props.onPress === "function" &&
    JSON.stringify(collectProps(n)).includes(t.whichCardAll.replace("{n}", "7")));
  chk("C0. 'tamamını gör' düğmesi bulundu", link.length > 0, link.length + " aday");
  if (link.length) {
    await renderer.act(async () => { await link[link.length - 1].props.onPress(); });
    await settle();
    tx = m.texts().join(" | ");
    chk("C1. Karşılaştırma RPC'si çağrıldı",
        globalThis.__CALLS.some(c => c.kind === "rpc" && c.fn === "salon_misafir_karsilastirmasi"),
        "salon_misafir_karsilastirmasi");
    chk("C2. Tablo satırları çizildi (3 program)",
        tx.includes("Priority Pass") && tx.includes("DragonPass") && tx.includes("Misafir ALINAMAZ"),
        "Priority Pass · DragonPass · Misafir ALINAMAZ");
    chk("C3. Bağlantı metni 'Listeyi gizle'ye döndü", tx.includes(t.whichCardHide), t.whichCardHide);
  }
  await m.unmount();

  // ---------- B) ÖNERİ YOK ----------
  console.log("\n--- B) Host hiç kart beyan etmemiş: sunucunun gerekçesi çıkmalı");
  setCfg(baseCfg(ONERI_YOK));
  m = await mount(S.HostAvailability, { t, session, onBack: () => {}, onDone: () => {}, onVerify: () => {} });
  await seLounge(m);
  tx = m.texts().join(" | ");
  chk("B1. Kutu YİNE çizildi (öneri yokken de kutu var)",
      tx.includes(t.whichCardTitle.toLocaleUpperCase("tr-TR")), t.whichCardTitle.toLocaleUpperCase("tr-TR"));
  chk("B2. Sunucunun gerekçe cümlesi yazıyor",
      tx.includes("Henuz bir erisim kaynagi"), ONERI_YOK.neden.slice(0, 52) + "…");
  chk("B3. Kutu BOŞ değil (undefined metin sızmıyor)",
      !tx.includes("undefined"), "metinlerde 'undefined' yok");
  chk("B4. Yanlışlıkla öneri gövdesi çizilmedi",
      !tx.includes("Turkish Airlines Miles&Smiles"), "öneri satırı yok");
  await m.unmount();

  // ---------- D) RPC DÜŞERSE ----------
  console.log("\n--- D) RPC 42501 dönerse: kutu çıkmaz, ekran ÇÖKMEZ");
  setCfg(baseCfg({ __error: "permission denied for function hangi_kartimi_kullanayim", __code: "42501" }));
  m = await mount(S.HostAvailability, { t, session, onBack: () => {}, onDone: () => {}, onVerify: () => {} });
  await seLounge(m);
  tx = m.texts().join(" | ");
  chk("D1. Ekran ayakta (beyaz ekran yok)", !!m.tree.toJSON() && tx.length > 50,
      tx.length + " karakter metin çizildi");
  chk("D2. Kutu çizilmedi (yanlış veri gösterilmiyor)",
      !tx.includes(t.whichCardTitle.toLocaleUpperCase("tr-TR")), "kutu yok");
  chk("D3. Formun geri kalanı duruyor (Yayınla düğmesi)",
      tx.includes(t.publish), t.publish);
  chk("D4. Kural kutusu (lounge_hint_for_host) hâlâ çalışıyor",
      tx.includes(HINT.headline), HINT.headline);
  await m.unmount();

  const bad = results.filter(r => !r.ok);
  console.log("\n" + "-".repeat(72));
  console.log(`Toplam kontrol: ${results.length} · başarısız: ${bad.length}`);
  if (bad.length) {
    console.log("\n🔴 BAŞARISIZ:");
    bad.forEach(b => console.log("  ✗ " + b.ad));
  }
  process.exit(bad.length ? 1 : 0);
}

// Bir düğümün altındaki metinleri prop olarak toplamak için yardımcı
function collectProps(node) {
  const out = [];
  (function walk(n) {
    if (n == null) return;
    if (typeof n === "string" || typeof n === "number") { out.push(String(n)); return; }
    if (Array.isArray(n)) { n.forEach(walk); return; }
    if (n.props && n.props.children !== undefined) walk(n.props.children);
    if (n.children) walk(n.children);
  })(node);
  return out;
}

run().catch(e => { console.log("🔴 TEST KOŞUCUSU ÇÖKTÜ: " + (e && e.stack || e)); process.exit(1); });
