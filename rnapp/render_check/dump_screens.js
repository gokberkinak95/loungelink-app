// Canlı uygulamanın ekranlarını mount edip GÖRÜNEN METİNLERİ dosyaya yazar.
// Amaç: MVP ekran görüntülerinin OCR metniyle otomatik karşılaştırmak.
const fs = require("fs");
const { renderScreen, t, S, session, UID, OTHER, React } = require("./runner");

const OUT = "/tmp/live_texts";
fs.mkdirSync(OUT, { recursive: true });

const REQ = {
  id: "req-1", host_id: UID, guest_id: OTHER, avail_id: "av-1", status: "accepted",
  intro_message: "Uçuş öncesi kahve içelim mi?",
  availabilities: { lounge_name: "Primeclass Lounge", airport_code: "IST", time_from: "14:00:00", time_to: "18:00:00", avail_date: "2026-08-06" },
};
const ago = (m) => new Date(Date.now() - m * 60000).toISOString();
const soon = (m) => new Date(Date.now() + m * 60000).toISOString();

function baseData(over = {}) {
  globalThis.__DATA = {
    session,
    tables: {
      requests: [REQ],
      chat_channels: [{ id: "ch-1", request_id: "req-1" }],
      messages: [{ id: "m1", channel_id: "ch-1", from_id: OTHER, body: "Merhaba!", created_at: ago(5) }],
      sessions: [],
      profiles: [{ user_id: UID, name: "Mert A.", guest_capacity: 2, access_source: "Priority Pass",
        bio: "Sık uçan biriyim, lounge'da sohbet etmeyi severim.", languages: ["Türkçe", "İngilizce"],
        profession: "Girişim Kurucusu", show_on_discovery: true, women_safety_mode: false }],
      users: [{ id: UID, role: "host", gender: "male", phone: "+905551112233" }],
      verifications: [{ user_id: UID, phone_verified: true, email_verified: true, id_verified: true }],
      trust_scores: [{ user_id: UID, score: 64, badge: "verified",
        components: { email: 10, phone: 10, id: 18, profession: 6, bio: 6, host_access: 8, sessions: 6 } }],
      availabilities: [{ id: "av-1", host_id: UID, airport_code: "IST", lounge_name: "Primeclass Lounge",
        avail_date: "2026-08-06", time_from: "14:00:00", time_to: "18:00:00", slots: 2, filled: 1, active: true }],
      visits: [{ id: "v-1", user_id: UID, airport_code: "IST", visit_date: "2026-08-06",
        time_from: "13:00:00", time_to: "19:00:00", flight_number: "TK712", purpose: "business" }],
      airports: [{ code: "IST", name: "İstanbul Havalimanı", city: "İstanbul" },
                 { code: "SAW", name: "Sabiha Gökçen", city: "İstanbul" }],
      rewards: [{ id: "r1", title: "Priority Pass Misafir Kartı", subtitle: "1 misafir · 60+ ülke",
                  category: "lounge", cost_points: 1500, active: true, sort_order: 1 }],
      notifications: [{ id: "n1", user_id: UID, category: "requests", title: "İstek kabul edildi! 🎉",
                        body: "Sohbet açıldı.", read: false, created_at: ago(10) }],
      connection_requests: [], invites: [], ratings: [], credit_ledger: [], points_ledger: [],
      user_balances: [{ user_id: UID, balance: 3 }], lounges: [], consents: [], subscriptions: [],
      ...over,
    },
    rpc: {
      discover_availabilities: [
        { id: "av-8", host_id: "aaa", airport_code: "IST", lounge_name: "Primeclass", avail_date: "2026-08-06",
          time_from: "14:00:00", time_to: "18:00:00", slots: 2, filled: 0, fully_booked: false, match_score: 74,
          host_name: "Burak K.", host_badge: "trusted", host_score: 72, has_trip: true, host_profession: "Yatırım Bankacılığı" },
      ],
      discover_people: [
        { user_id: "bbb", name: "Ayse D.", profession: "Yazılım Mühendisliği", badge: "verified", score: 56,
          rel: "none", airport: "IST", visit_date: "2026-08-06", flight_number: "TK712", same_flight: true,
          is_hosting: false, can_request: false, req_reason: "noslot" },
      ],
      host_requests: [{ id: "req-9", guest_id: OTHER, guest_name: "Ayse D.", guest_profession: "Yazılım Mühendisliği",
        guest_score: 44, guest_id_verified: true, guest_phone_verified: true, same_flight: true, same_purpose: true,
        flight_number: "TK712", intro_message: "Uçuş öncesi kahve içmek isterim.", status: "pending", match_score: 70,
        guest_sessions: 0, guest_rating_count: 0, avail_id: "av-1" }],
      invitable_guests: [{ guest_id: OTHER, name: "Elif K.", profession: "Fintech", sessions_count: 6, invite_status: "none" }],
      my_referral: { code: "MERT2026" }, has_active_session: false, expire_stale_sessions: { ok: true },
      recompute_trust: 64,
    },
  };
}

async function dump(file, name, el) {
  const r = await renderScreen(name, el);
  const body = r.ok ? r.texts.join("\n") : "ÇÖKTÜ: " + r.err;
  fs.writeFileSync(`${OUT}/${file}.txt`, body);
  console.log((r.ok ? "✓ " : "✗ ") + name + " → " + file + ".txt (" + (r.ok ? r.texts.length + " metin" : r.err) + ")");
}

(async () => {
  baseData();
  await dump("kesfet", "Keşfet", React.createElement(S.Discovery, { t, lang: "tr", session, scope: null, onBack: () => {} }));
  await dump("tanis", "Tanış", React.createElement(S.Meet, { t, lang: "tr", session, onBack: () => {} }));
  await dump("seyahatlerim", "Seyahatlerim", React.createElement(S.Trips, { t, lang: "tr", session, onBack: () => {} }));
  await dump("profil", "Profil", React.createElement(S.Profile, { t, lang: "tr", session, onBack: () => {} }));
  await dump("guven", "Güven Puanım", React.createElement(S.TrustVisual, { t, session, onBack: () => {} }));
  await dump("guvenlik", "Güvenlik Merkezi", React.createElement(S.Safety, { t, session, onBack: () => {} }));
  await dump("magaza", "Mağaza", React.createElement(S.Marketplace, { t, session, onBack: () => {} }));
  await dump("davet", "Davet Et", React.createElement(S.Referral, { t, session, onBack: () => {} }));
  await dump("bildirimler", "Bildirimler", React.createElement(S.Notifications, { t, session, onBack: () => {} }));
  await dump("gecmis", "Oturum Geçmişi", React.createElement(S.SessionHistory, { t, session, onBack: () => {} }));
  await dump("musaitlik", "Müsaitlik Ekle", React.createElement(S.HostAvailability, { t, session, onBack: () => {} }));
  await dump("seyahat_ekle", "Seyahat Ekle", React.createElement(S.AddVisit, { t, session, onBack: () => {} }));
  await dump("yayin_davet", "Yayın & Davet", React.createElement(S.HostBroadcast, { t, lang: "tr", session, onBack: () => {} }));
  await dump("erisim", "Lounge Erişim Kurulumu", React.createElement(S.HostAccessSource, { t, session, onBack: () => {} }));
  await dump("duzenle", "Profili Düzenle", React.createElement(S.EditProfile, { t, session, onBack: () => {} }));
  await dump("dogrulama", "Doğrulama", React.createElement(S.VerifyPhone, { t, session, onBack: () => {} }));
  await dump("ayarlar", "Ayarlar", React.createElement(S.Settings, { t, lang: "tr", session, onBack: () => {} }));
  await dump("baska_profil", "Başka Profil", React.createElement(S.PublicProfile, { t, session, targetId: OTHER, onBack: () => {} }));

  // sohbet durumları
  await dump("sohbet_bekliyor", "Sohbet · oturum yok",
    React.createElement(S.Chat, { t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  baseData({ sessions: [{ id: "s1", request_id: "req-1", status: "active", started_at: ago(16),
    cancel_grace_until: soon(2), host_confirmed: false, guest_confirmed: false, host_started_at: ago(16), guest_started_at: ago(16) }] });
  await dump("sohbet_aktif", "Sohbet · aktif",
    React.createElement(S.Chat, { t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  baseData({ sessions: [{ id: "s1", request_id: "req-1", status: "completed", started_at: ago(90),
    completed_at: ago(2), host_confirmed: true, guest_confirmed: true }] });
  await dump("sohbet_tamam", "Sohbet · tamamlandı",
    React.createElement(S.Chat, { t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  baseData();
  await dump("canli_durum", "Canlı Durum", React.createElement(S.LiveStatus, { t, session, onBack: () => {} }));
  console.log("\nÇıktı: " + OUT);
})();
