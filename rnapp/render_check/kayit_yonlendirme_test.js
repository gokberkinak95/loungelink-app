// ============================================================================
// KAYIT / GİRİŞ YÖNLENDİRMESİ — App.js'in KENDİSİ, oturum olaylarıyla
//
// 4 Ekim 2026 (Gökberk: "signup yaptıktan sonra tanıtım sayfaları gelmişti;
// login/signup yapınca doğru sayfaya yönlendirdiğinden emin ol").
//
// `giris_kapisi_test` ekranları TEK TEK sınıyor (Splash'in `go` çağrısı,
// Auth'un sunucuya giden verisi). Bu dosya aradaki boşluğu ölçer: App.js'in
// ekran durum makinesi oturum açıldığında / kapandığında NEREYE gidiyor?
//   · tanıtımdan, girişten ya da kayıttan oturum açılırsa → ana sayfa
//   · ana sayfadan çıkış → açılış ekranı (tanıtım DEĞİL)
//   · tanıtım görülmüşse "Başla" → doğrudan kayıt
//   · sosyal (Google/Apple) hesap, onay yoksa → rol + onay tamamlama ekranı
//   · e-posta hesabı → tamamlama ekranı ASLA (v1.81'in yanlış alarmı)
// Oturum olayı stub_supabase'in yakaladığı geri çağrıyla üretilir.
// ============================================================================
const { React, TestRenderer, t } = require("./runner");
const path = require("path");
const App = require(path.join(require("./ll_paths").APP, "App.js")).default;

const UID = "11111111-1111-4111-8111-111111111111";
const sonuc = [];
const ol = (ad, kosul, not) => sonuc.push([ad, !!kosul, not || ""]);

function metinler(tree) {
  const out = [];
  const gez = (n) => {
    if (n == null) return;
    if (typeof n === "string" || typeof n === "number") { out.push(String(n)); return; }
    if (Array.isArray(n)) { n.forEach(gez); return; }
    if (n.children) gez(n.children);
  };
  gez(tree.toJSON());
  return out.join(" | ");
}
function bas(tree, parca) {
  const hepsi = tree.root.findAll((n) => n.props && typeof n.props.onPress === "function", { deep: true });
  let en = null, enKisa = Infinity;
  for (const d of hepsi) {
    const m = (() => { const o = []; const g = (x) => { if (x == null) return; if (typeof x === "string") o.push(x); else if (x.children) x.children.forEach(g); }; g(d); return o.join(" "); })();
    if (m.indexOf(parca) >= 0 && m.length < enKisa) { en = d; enKisa = m.length; }
  }
  return en ? en.props.onPress : null;
}
async function tur(n = 8) { for (let i = 0; i < n; i++) await TestRenderer.act(async () => { await new Promise((r) => setTimeout(r, 0)); }); }
async function kur(veri, depo) {
  globalThis.__DATA = veri;
  globalThis.__ASYNC = depo || {};
  globalThis.__AUTHCB = null;
  let tree;
  await TestRenderer.act(async () => { tree = TestRenderer.create(React.createElement(App)); });
  await tur();
  return tree;
}
async function oturumAc(sess) {
  await TestRenderer.act(async () => { globalThis.__DATA.session = sess; globalThis.__AUTHCB && globalThis.__AUTHCB("SIGNED_IN", sess); });
  await tur();
}
async function oturumKapat() {
  await TestRenderer.act(async () => { globalThis.__DATA.session = null; globalThis.__AUTHCB && globalThis.__AUTHCB("SIGNED_OUT", null); });
  await tur();
}
const anaSayfaMi = (m) => m.indexOf(t.navHome) >= 0;
const acilisMi = (m) => m.indexOf(t.start) >= 0 && m.indexOf(t.haveAcc) >= 0;
// Tanıtımın kendine özgü izi: ilk slaydın başlığı ("Devam" başka ekranlarda da geçer).
const TANITIM_IZI = String(((t.onbSlides || [])[0] || {}).title || "@@").split("\n")[0];
// Başlık kelime kelime ayrı düğümlerde çizilir: ayırıcıları atıp birleştirerek bak.
const tanitimMi = (m) => m.replace(/\s*\|\s*/g, " ").replace(/\s+/g, " ").indexOf(TANITIM_IZI) >= 0;

const MAIN_VERI = (user, consents) => ({
  session: null,
  tables: {
    airports: [{ code: "IST", city: "İstanbul" }], users: [{ id: UID, role: "guest" }],
    profiles: [{ user_id: UID, name: "Deneme" }], verifications: [], trust_scores: [{ user_id: UID, score: 10 }],
    availabilities: [], requests: [], sessions: [], notifications: [], visits: [],
    consents: consents, connection_requests: [], chat_channels: [], messages: [],
  },
  rpc: {
    has_active_session: false, expire_stale_sessions: { ok: true },
    ana_sayfa_akisi: { sohbet: 0, istek: 0, davet: 0, soru: 0, baglanti: 0, ilan: 0 },
    pending_actions: [], home_connections: [], sorularim: [], my_availabilities: [],
    host_requests: [], my_sent_requests: [], pending_ratings: [], bekleyen_hikaye_daveti: [],
  },
  _user: user,
});
const EPOSTA = { id: UID, email: "yeni@ornek.com", app_metadata: { provider: "email" } };
const GOOGLE = { id: UID, email: "yeni@gmail.com", app_metadata: { provider: "google" } };

(async () => {
  // 1) Oturumsuz açılış → açılış ekranı
  let tree = await kur(MAIN_VERI(EPOSTA, [{ type: "terms_privacy" }]));
  let m = metinler(tree);
  ol("oturumsuz açılış → açılış ekranı", acilisMi(m), acilisMi(m) ? "" : m.slice(0, 160));

  // 2) Başla → tanıtım (ilk kez); tanıtımdayken oturum açılırsa → ana sayfa
  let b = bas(tree, t.start); if (b) await TestRenderer.act(async () => { await b(); }); await tur();
  m = metinler(tree);
  ol("ilk kez 'Başla' → tanıtım", tanitimMi(m), m.slice(0, 160));
  await oturumAc({ user: EPOSTA });
  m = metinler(tree);
  ol("tanıtımdayken oturum açıldı → ANA SAYFA (tanıtım değil)", anaSayfaMi(m) && !tanitimMi(m), m.slice(0, 160));

  // 3) Ana sayfadan çıkış → açılış ekranı, tanıtım değil
  await oturumKapat();
  m = metinler(tree);
  ol("çıkış → açılış ekranı (tanıtım DEĞİL)", acilisMi(m) && !tanitimMi(m), m.slice(0, 160));

  // 4) Giriş Yap → giriş formu → oturum → ana sayfa
  b = bas(tree, t.haveAcc); if (b) await TestRenderer.act(async () => { await b(); }); await tur();
  m = metinler(tree);
  const girisFormu = m.indexOf(t.welcomeBack) >= 0 || m.indexOf(t.login) >= 0;
  ol("'Giriş Yap' → giriş formu", girisFormu, m.slice(0, 160));
  await oturumAc({ user: EPOSTA });
  m = metinler(tree);
  ol("girişte oturum açıldı → ANA SAYFA", anaSayfaMi(m), m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 5) Tanıtım görülmüşse 'Başla' → doğrudan KAYIT; kayıtta oturum → ana sayfa
  tree = await kur(MAIN_VERI(EPOSTA, [{ type: "terms_privacy" }]), { ll_onb: "1" });
  b = bas(tree, t.start); if (b) await TestRenderer.act(async () => { await b(); }); await tur();
  m = metinler(tree);
  const kayitFormu = m.indexOf(t.register) >= 0 && !tanitimMi(m);
  ol("tanıtım görülmüşse 'Başla' → kayıt formu (tanıtım tekrar YOK)", kayitFormu, m.slice(0, 160));
  await oturumAc({ user: EPOSTA });
  m = metinler(tree);
  ol("kayıtta oturum açıldı → ANA SAYFA (tanıtım değil)", anaSayfaMi(m) && !tanitimMi(m), m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 6) Oturum açıkken soğuk açılış → doğrudan ana sayfa
  const v6 = MAIN_VERI(EPOSTA, [{ type: "terms_privacy" }]); v6.session = { user: EPOSTA };
  tree = await kur(v6);
  m = metinler(tree);
  ol("oturum varken açılış → ANA SAYFA", anaSayfaMi(m) && !acilisMi(m), m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 7) Sosyal (Google) hesap, onay kaydı YOK → rol + onay tamamlama ekranı
  const v7 = MAIN_VERI(GOOGLE, []); v7.session = { user: GOOGLE };
  tree = await kur(v7);
  m = metinler(tree);
  const tamamlama = m.indexOf(t.onbCompleteTitle) >= 0 && m.indexOf(t.roleHost) >= 0 && m.indexOf(t.roleGuest) >= 0;
  ol("Google ile ilk giriş (onay yok) → ROL + ONAY tamamlama ekranı", tamamlama, m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 8) Sosyal hesap, onay VAR → tamamlama yok, ana sayfa
  const v8 = MAIN_VERI(GOOGLE, [{ type: "terms_privacy" }]); v8.session = { user: GOOGLE };
  tree = await kur(v8);
  m = metinler(tree);
  ol("Google hesabı (onaylı) → ana sayfa, tamamlama YOK", anaSayfaMi(m) && m.indexOf(t.onbCompleteTitle) < 0, m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 9) E-posta hesabı, onay kaydı bulunmasa bile → tamamlama ASLA (v1.81)
  const v9 = MAIN_VERI(EPOSTA, []); v9.session = { user: EPOSTA };
  tree = await kur(v9);
  m = metinler(tree);
  ol("e-posta hesabı → tamamlama ekranı ÇIKMAZ (v1.81)", m.indexOf(t.onbCompleteTitle) < 0, m.slice(0, 160));
  await TestRenderer.act(async () => tree.unmount());

  // 10) E-posta doğrulamalı kayıtta bekleyen onay · telefon · davet kodu:
  //     AYNI e-postayla ilk açılışta yazılır, bayrak kalkar.
  const BEK = JSON.stringify({ email: "yeni@ornek.com", onay: ["terms_privacy", "age_18"], tel: "+905551112233", ref: "ABC123" });
  globalThis.__RPC_LOG = [];
  const v10 = MAIN_VERI(EPOSTA, [{ type: "terms_privacy" }]); v10.session = { user: EPOSTA };
  tree = await kur(v10, { ll_kayit_bekliyor: BEK });
  const adlar = globalThis.__RPC_LOG.map((c) => c[0]);
  ol("doğrulamalı kayıt → ilk girişte onaylar yazıldı", adlar.indexOf("grant_consents") >= 0, adlar.join(","));
  ol("doğrulamalı kayıt → ilk girişte telefon yazıldı", adlar.indexOf("declare_phone") >= 0);
  ol("doğrulamalı kayıt → ilk girişte davet kodu uygulandı", adlar.indexOf("apply_referral") >= 0);
  ol("bekleyen kayıt bayrağı kalktı", !("ll_kayit_bekliyor" in (globalThis.__ASYNC || {})));
  await TestRenderer.act(async () => tree.unmount());

  // 11) Aynı cihazda BAŞKA hesapla giriş → bekleyen veri o hesaba YAZILMAZ
  globalThis.__RPC_LOG = [];
  const BASKA = { id: UID, email: "baska@ornek.com", app_metadata: { provider: "email" } };
  const v11 = MAIN_VERI(BASKA, [{ type: "terms_privacy" }]); v11.session = { user: BASKA };
  tree = await kur(v11, { ll_kayit_bekliyor: BEK });
  const adlar2 = globalThis.__RPC_LOG.map((c) => c[0]);
  ol("başka hesapla giriş → bekleyen onay/telefon/kod YAZILMADI",
     adlar2.indexOf("declare_phone") < 0 && adlar2.indexOf("apply_referral") < 0, adlar2.join(","));
  ol("başka hesapla giriş → bayrak korunur (asıl sahibi için)", "ll_kayit_bekliyor" in (globalThis.__ASYNC || {}));
  await TestRenderer.act(async () => tree.unmount());
  globalThis.__RPC_LOG = null;

  console.log("");
  let ok = 0;
  for (const [ad, g, not] of sonuc) { console.log(`  ${g ? "✓" : "✗"} ${ad}${!g && not ? "  — " + not : ""}`); if (g) ok++; }
  console.log(`\n${ok}/${sonuc.length} yönlendirme kontrolü geçti`);
  process.exit(ok === sonuc.length ? 0 : 1);
})().catch((e) => { console.log("TEST ÇÖKTÜ: " + (e && e.stack)); process.exit(1); });
