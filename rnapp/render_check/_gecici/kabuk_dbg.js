const { renderScreen, React } = require("../runner");
const path = require("path");
const App = require(path.join(require("../ll_paths").APP, "App.js")).default;
const renderer = require("react-test-renderer");
(async () => {
  const UID = "11111111-1111-4111-8111-111111111111";
  globalThis.__DATA = {
    session: { user: { id: UID, email: "a@b.c" } },
    tables: { airports: [{ code: "IST", city: "İstanbul" }], users: [{ id: UID, role: "host" }],
      profiles: [{ user_id: UID, name: "Host", access_source: "card", guest_capacity: 2 }],
      verifications: [], trust_scores: [{ user_id: UID, score: 70 }], availabilities: [],
      requests: [], sessions: [], notifications: [], visits: [], consents: [{ id: 1 }],
      connection_requests: [], chat_channels: [], messages: [] },
    rpc: { has_active_session: false, expire_stale_sessions: { ok: true },
      ana_sayfa_akisi: { sohbet:0,istek:0,davet:0,soru:0,baglanti:0,ilan:0 },
      pending_actions: [], home_connections: [], sorularim: [] },
  };
  const r = await renderScreen("dbg", React.createElement(App));
  console.log("ok:", r.ok, "err:", r.err);
  console.log("metin:", (r.texts||[]).slice(0,25).join(" | ").slice(0,500));
  process.exit(0);
})();
