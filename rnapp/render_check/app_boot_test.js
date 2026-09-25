// App.js'in KENDİSİNİ mount eden test — v1.80'deki beyaz ekran hatası
// (rpc(...).catch) tam olarak burada patlıyordu; ekran testleri App.js'i hiç
// mount etmediği için kaçmıştı.
const { renderScreen, React } = require("./runner");
const path = require("path");
const App = require(path.join(require("./ll_paths").APP, "App.js")).default;

(async () => {
  globalThis.__DATA = {
    session: { user: { id: "11111111-1111-4111-8111-111111111111", email: "a@b.c" } },
    tables: { airports: [{ code: "IST" }], users: [], profiles: [], verifications: [], trust_scores: [],
              availabilities: [], requests: [], sessions: [], notifications: [], visits: [], consents: [{ id: 1 }] },
    rpc: { has_active_session: false, expire_stale_sessions: { ok: true } },
  };
  const r = await renderScreen("App (giriş yapılmış)", React.createElement(App));
  console.log(r.ok ? "✓ App açılıyor — beyaz ekran yok" : "✗ App ÇÖKTÜ: " + r.err);
  if (!r.ok) process.exit(1);

  // ══════════════════════════════════════════════════════════════════════
  // 🔴 19 EYLÜL — SEKME KABUĞU (`Main`) HİÇBİR TESTTE RENDER EDİLMİYORDU.
  //
  // Bugün `Main`in içine bir `useEffect` ekledim ve bağımlılık listesine
  // 100 satır AŞAĞIDA tanımlı bir `const` yazdım. Sonuç:
  //     ReferenceError: Cannot access 'reload' before initialization
  //         at Main (...)
  // Yani uygulamanın oturum açtıktan SONRAKİ her ekranı beyaz kalıyordu.
  //
  // Üç kapı bunu GÖRMEDİ ve üçü de haklıydı:
  //   · `mount_test.js`  → ekranları TEK TEK mount ediyor, kabuğu değil
  //   · `app_boot_test`  → oturum var ama `Main` render edilmeden önce
  //                        boot/onboarding dalında duruyordu
  //   · `check.js`       → sözdizimi doğru, ölü bölge çalışma anı hatası
  // Yakalayan `web_sahne` oldu — 30 sahnede aynı çökme. Ama o zincirin
  // EN SONUNDA koşuyor (bundle + 53 sahne ≈ 20 dakika).
  //
  // 🆕 SINIF: "BİR HATAYI YAKALAYAN EN UCUZ KAPIYI BUL VE ONU ORAYA TAŞI —
  // 20 DAKİKADA YAKALANAN BİR ÇÖKME, 20 SANİYEDE YAKALANABİLİYORSA KAPI
  // YANLIŞ YERDEDİR."
  //
  // Bu blok kabuğu GERÇEKTEN çizdiriyor: rol "host", oturum var, sözleşme
  // tamam — yani `Main` dalına giren en dar veri.
  // ══════════════════════════════════════════════════════════════════════
  const UID = "11111111-1111-4111-8111-111111111111";
  globalThis.__DATA = {
    session: { user: { id: UID, email: "a@b.c" } },
    tables: {
      airports: [{ code: "IST", city: "İstanbul" }],
      users: [{ id: UID, role: "host" }],
      profiles: [{ user_id: UID, name: "Host", access_source: "card", guest_capacity: 2 }],
      verifications: [], trust_scores: [{ user_id: UID, score: 70 }],
      availabilities: [], requests: [], sessions: [], notifications: [], visits: [],
      consents: [{ id: 1 }], connection_requests: [], chat_channels: [], messages: [],
    },
    rpc: {
      has_active_session: false,
      expire_stale_sessions: { ok: true },
      ana_sayfa_akisi: { sohbet: 0, istek: 0, davet: 0, soru: 0, baglanti: 0, ilan: 0 },
      pending_actions: [], home_connections: [], sorularim: [],
      my_availabilities: [], host_requests: [], my_sent_requests: [],
      pending_ratings: [], bekleyen_hikaye_daveti: [],
    },
  };
  const m = await renderScreen("Main (sekme kabuğu · host)", React.createElement(App));
  console.log(m.ok
    ? "✓ Sekme kabuğu çiziliyor — ölü bölge / tanımsız değişken yok"
    : "✗ SEKME KABUĞU ÇÖKTÜ: " + m.err);
  process.exit(m.ok ? 0 : 1);
})();
