// ============================================================
// LoungeLink · EKRAN EKRAN AKIŞ TESTİ (headless render)
// Her senaryo: veri kur → ekranı MOUNT et → çökme var mı + beklenen metin/
// aksiyon çıkıyor mu. Özellikle karşılıklı akışın HER İKİ TARAFI ayrı ayrı.
// ============================================================
const { renderScreen, has, t, S, session, UID, OTHER, React, fmtLongDate } = require("./runner");

// 29 Eylül — sabit "2026-08-06" zamanla GEÇMİŞE düştü; sunucu geçmiş tarihli
// ilan döndürmez (avail_date >= current_date), yani fikstür gerçekçi değildi ve
// Keşfet'in "Bugün sona erenler" katı onları haklı olarak gizledi. Hep 7 gün ileri.
const GUN = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
const results = [];
function check(scen, cond, label) { results.push({ scen, ok: !!cond, label }); }

const REQ = {
  id: "req-1", host_id: UID, guest_id: OTHER, avail_id: "av-1", status: "accepted",
  intro_message: "Uçuş öncesi kahve içelim mi?",
  availabilities: { lounge_name: "Primeclass Lounge", airport_code: "IST", time_from: "14:00:00", time_to: "18:00:00", avail_date: GUN },
};
const now = new Date();
const ago = (m) => new Date(now.getTime() - m * 60000).toISOString();
const soon = (m) => new Date(now.getTime() + m * 60000).toISOString();

function data({ sessions = [], messages = [], extra = {} } = {}) {
  // 🔴 v3.4 — KATALOG ÖNBELLEĞİ FİKSTÜRÜ AŞIYORDU VE BU GERÇEK BİR BULGU.
  // `src/katalog.js` havalimanı/havayolu listelerini MODÜL DÜZEYİNDE 30
  // dakika tutuyor. Testler her senaryoda farklı bir `carrier_options`
  // kuruyor ama önbellek İLK senaryonunkini saklıyordu: iki test "AJet"
  // arıyor, önbellekten "Turkish Airlines" geliyordu.
  //
  // Bu yalnız bir test sorunu değil: aynı desen üründe de var — hesap
  // değiştiğinde önbellek eskiyi taşır. Katalog global olduğu için
  // içerik değişmez, ama BAĞIMLILIK YANLIŞTIR ve bir gün değişir.
  // O yüzden `katalogUnut()` hem burada hem ÇIKIŞTA çağrılıyor.
  //
  // 🆕 SINIF: "MODÜL DÜZEYİNDE BİR ÖNBELLEK, TESTLER ARASINDA DA
  // YAŞAR — TEMİZLENMİYORSA TESTLER BİRBİRİNİN CEVABINI OKUR."
  try { require("../src/katalog").katalogUnut(); } catch (e) {}
  globalThis.__DATA = {
    session,
    tables: {
      sessions, messages,
      requests: [REQ],
      chat_channels: [{ id: "ch-1", request_id: "req-1" }],
      profiles: [{ user_id: UID, name: "Mert A.", guest_capacity: 2, access_source: "Priority Pass",
                   bio: "Sık uçan biriyim, lounge'da sohbet etmeyi severim.", languages: ["Türkçe"], profession: "Girişim" }],
      users: [{ id: UID, role: "host", gender: "male" }],
      verifications: [{ user_id: UID, phone_verified: true, email_verified: true, id_verified: true }],
      trust_scores: [{ user_id: UID, score: 64, badge: "verified",
                       components: { email: 10, phone: 10, id: 18, profession: 6, bio: 6, host_access: 8, sessions: 6 } }],
      availabilities: [{ id: "av-1", host_id: UID, airport_code: "IST", lounge_name: "Primeclass Lounge",
                         avail_date: GUN, time_from: "14:00:00", time_to: "18:00:00", slots: 2, filled: 1, active: true }],
      visits: [{ id: "v-1", user_id: UID, airport_code: "IST", visit_date: GUN, time_from: "13:00:00", time_to: "19:00:00", flight_number: "TK712" }],
      notifications: [], connection_requests: [], invites: [], ratings: [], airports: [{ code: "IST", name: "İstanbul", city: "İstanbul" }],
      rewards: [], credit_ledger: [], points_ledger: [], user_balances: [{ user_id: UID, balance: 3 }],
      ...extra,
    },
    rpc: {
      discover_availabilities: [
        { id: "av-9", host_id: "33333333-3333-4333-8333-333333333333", airport_code: "IST", lounge_name: "IGA Lounge", avail_date: GUN,
          time_from: "15:00:00", time_to: "19:00:00", slots: 2, filled: 2, fully_booked: true, match_score: 92,
          host_name: "Dolu Host", host_badge: "trusted", host_score: 80, has_trip: true },
        { id: "av-8", host_id: OTHER, airport_code: "IST", lounge_name: "Primeclass", avail_date: GUN,
          time_from: "14:00:00", time_to: "18:00:00", slots: 2, filled: 0, fully_booked: false, match_score: 61,
          host_name: "Açık Host", host_badge: "verified", host_score: 64, has_trip: true },
      ],
      discover_people: [], host_requests: [], invitable_guests: [], my_referral: { code: "MERT2026" },
      has_active_session: false, expire_stale_sessions: { ok: true },
    },
  };
}

(async () => {
  // ---------- 1) SOHBET: oturum YOK (kabul edilmiş, henüz buluşulmadı) ----------
  data({ sessions: [] });
  let r = await renderScreen("Sohbet · oturum yok", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "Oturumu Başlat"), '"Oturumu Başlat" alt çubukta');
  check(r.name, !has(r.texts, "Oturum Devam Ediyor"), "oturum paneli KENDİLİĞİNDEN açılmıyor");
  // 4 Eylül — tasarım 06: iptal sohbet ekranında değil, oturum PANELİNDE
  // (şerit → panel). Erişilebilirlik: şerit `sceneSession` etiketli düğme.
  check(r.name, has(r.texts, "Primeclass Lounge"), "oturum paneline giden şerit çiziliyor");

  // ---------- 2) SOHBET: BEN başlattım, karşı taraf bekleniyor ----------
  data({ sessions: [{ id: "s-1", request_id: "req-1", status: "pending", host_started_at: ago(1), guest_started_at: null }] });
  r = await renderScreen("Sohbet · ben başlattım (host)", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "Karşı taraf bekleniyor"), "bekleme durumu görünüyor");
  check(r.name, !has(r.texts, "Oturum Devam Ediyor"), "oturum başlamamışken 'devam ediyor' YAZMIYOR");

  // ---------- 3) SOHBET: oturum AKTİF (5 dk penceresi açık) ----------
  data({ sessions: [{ id: "s-1", request_id: "req-1", status: "active", started_at: ago(2),
                      cancel_grace_until: soon(3), host_confirmed: false, guest_confirmed: false,
                      host_started_at: ago(2), guest_started_at: ago(2) }] });
  r = await renderScreen("Sohbet · oturum aktif", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "Oturumu Tamamla"), '"Oturumu Tamamla" alt çubukta');
  check(r.name, has(r.texts, "00:02"), "süre sayacı işliyor");

  // ---------- 4) SOHBET: karşı taraf tamamladı, ben onaylamadım ----------
  data({ sessions: [{ id: "s-1", request_id: "req-1", status: "active", started_at: ago(30),
                      cancel_grace_until: ago(25), host_confirmed: false, guest_confirmed: true,
                      host_started_at: ago(30), guest_started_at: ago(30) }] });
  r = await renderScreen("Sohbet · karşı taraf onayladı", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "Oturumu Tamamla"), "benim butonum hâlâ aktif");

  // ---------- 5) SOHBET: oturum TAMAMLANDI, puanlama bekliyor ----------
  data({ sessions: [{ id: "s-1", request_id: "req-1", status: "completed", started_at: ago(90),
                      completed_at: ago(1), host_confirmed: true, guest_confirmed: true }] });
  r = await renderScreen("Sohbet · tamamlandı", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "Oturumu puanla") || has(r.texts, "puanla"), "puanlamaya giden yol var");

  // ---------- 6) KEŞFET: dolu ilan en üstte OLMAMALI ----------
  data({});
  r = await renderScreen("Keşfet · sıralama", React.createElement(S.Discovery, {
    t, lang: "tr", session, scope: null, onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  const iAcik = r.texts.findIndex(x => x.includes("Açık"));
  const iDolu = r.texts.findIndex(x => x.includes("Dolu"));
  if (!(iAcik > -1 && iDolu > -1 && iAcik < iDolu)) console.log("DEBUG siralama:", iAcik, iDolu, r.texts.slice(0,45).join(" | "));
  check(r.name, iAcik > -1 && iDolu > -1 && iAcik < iDolu,
        "AÇIK ilan (eşleşme 61) DOLU ilandan (eşleşme 92) ÖNCE geliyor");

  // ---------- 7) PROFİL ----------
  data({});
  r = await renderScreen("Profil", React.createElement(S.Profile, {
    t, lang: "tr", session, onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, !has(r.texts, "DOĞRULAMALAR"), "mükerrer DOĞRULAMALAR kartı YOK");
  check(r.name, !has(r.texts, "Seviyesi"), "mükerrer '… Seviyesi' menü satırı YOK");
  check(r.name, has(r.texts, "Güven Puanım") || has(r.texts, "Güven"), "Güven Puanım menüde");

  // ---------- 8) GÜVEN PUANI ----------
  r = await renderScreen("Güven Puanım", React.createElement(S.TrustVisual, { t, session, onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, has(r.texts, "64"), "puan görünüyor");

  // ---------- 9) OTURUM GEÇMİŞİ: pending oturum listede mi ----------
  data({ sessions: [{ id: "s-2", request_id: "req-1", status: "pending", started_at: null,
                      requests: { id: "req-1", guest_id: OTHER, host_id: UID, availabilities: {} } }] });
  r = await renderScreen("Oturum Geçmişi", React.createElement(S.SessionHistory, { t, session, onBack: () => {} }));
  check(r.name, r.ok, "çökmeden açılıyor");

  // ---------- 10) DİĞER EKRANLAR: açılıyor mu ----------
  data({});
  const others = [
    ["Tanış", S.Meet, { t, lang: "tr", session, onBack: () => {} }],
    ["Seyahatlerim", S.Trips, { t, lang: "tr", session, onBack: () => {} }],
    ["Güvenlik Merkezi", S.Safety, { t, session, onBack: () => {} }],
    ["Canlı Durum", S.LiveStatus, { t, session, onBack: () => {} }],
    ["Bildirimler", S.Notifications, { t, session, onBack: () => {} }],
    ["Mağaza", S.Marketplace, { t, session, onBack: () => {} }],
    ["Davet Et", S.Referral, { t, session, onBack: () => {} }],
    ["Ayarlar", S.Settings, { t, lang: "tr", session, onBack: () => {} }],
    ["Profili Düzenle", S.EditProfile, { t, session, onBack: () => {} }],
    ["Müsaitlik Ekle", S.HostAvailability, { t, session, onBack: () => {} }],
    ["Seyahat Ekle", S.AddVisit, { t, session, onBack: () => {} }],
    ["Yayın & Davet", S.HostBroadcast, { t, lang: "tr", session, onBack: () => {} }],
    ["Doğrulama", S.VerifyPhone, { t, session, onBack: () => {} }],
    ["Lounge Erişim", S.HostAccessSource, { t, session, onBack: () => {} }],
    ["Başka Profil", S.PublicProfile, { t, session, targetId: OTHER, onBack: () => {} }],
    ["Sözleşme", S.LegalDoc, { docKey: "gizlilik", onBack: () => {} }],
  ];
  for (const [nm, Comp, props] of others) {
    if (!Comp) { check(nm, false, "EKRAN EXPORT EDİLMEMİŞ"); continue; }
    const rr = await renderScreen(nm, React.createElement(Comp, props));
    check(nm, rr.ok, rr.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + rr.err);
  }

  // ---------- 11) BAŞKA PROFİL: tek bağlantı aksiyonu ----------
  data({});
  r = await renderScreen("Başka Profil · tek aksiyon", React.createElement(S.PublicProfile, {
    t, session, targetId: OTHER, onBack: () => {} }));
  const connCount = r.texts.filter(x => x.includes("Bağla") || x.includes("Bağlantı Kur")).length;
  check(r.name, r.ok, "çökmeden açılıyor");
  check(r.name, connCount <= 1, "bağlantı aksiyonu TEK (mükerrer buton yok) — bulunan: " + connCount);

  // ---------- 12) GELEN İSTEKLER: aynı misafir, İKİ AYRI İLAN ----------
  // 🔴 Cihazda görülen sorun: aynı misafir host'un iki ayrı ilanına başvurunca
  // iki kart BİREBİR aynı görünüyordu ve "çoklanma" sanılıyordu. Kart artık
  // hangi ilana ait olduğunu yazıyor. Bu senaryo tam olarak onu kanıtlar:
  // iki satır BİRBİRİNDEN FARKLI ilan bilgisi göstermeli.
  const gelen = (id, av, lounge, date, from, to) => ({
    id, guest_id: OTHER, avail_id: av, status: "pending",
    intro_message: "Uçuş öncesi kahve içelim mi?", created_at: ago(30),
    guest_name: "Elif Kaya", guest_photo: null, guest_profession: "Ürün Tasarımı",
    guest_score: 26, guest_badge: "verified", guest_id_verified: false,
    guest_phone_verified: true, guest_linkedin: false, guest_sessions: 1,
    guest_rating: 0, guest_rating_count: 0, same_flight: true, same_purpose: true,
    guest_fit: 60, lounge_name: lounge, avail_date: date,
    time_from: from, time_to: to, flight_number: "TK712",
  });
  data({ extra: {}, });
  globalThis.__DATA.rpc.host_requests = [
    gelen("req-a", "av-1", "Turkish Airlines Lounge — İç Hat", "2026-08-22", "10:00:00", "16:00:00"),
    gelen("req-b", "av-2", "Primeclass Lounge", "2026-08-23", "09:00:00", "12:00:00"),
  ];
  r = await renderScreen("Gelen İstekler · hangi ilana ait", React.createElement(S.RequestsPanel, {
    t, lang: "tr", session, onOpenChat: () => {}, onOpenProfile: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  // 3 Eylül — tasarım 02/14: bu yılın tarihlerinde yıl yazılmıyor ("22 Ağustos").
  const yilsiz = (iso) => fmtLongDate(iso, "tr");
  check(r.name, has(r.texts, `${yilsiz("2026-08-22")} · 10:00–16:00 · Turkish Airlines Lounge — İç Hat`),
        "1. kart hangi ilana ait olduğunu yazıyor (gün · saat · salon)");
  check(r.name, has(r.texts, `${yilsiz("2026-08-23")} · 09:00–12:00 · Primeclass Lounge`),
        "2. kart FARKLI ilanı yazıyor — iki kart artık ayırt edilebiliyor");

  // ---------- 13) GELEN İSTEKLER: ilan bilgisi eksikken kart yine çiziliyor ----------
  globalThis.__DATA.rpc.host_requests = [
    { ...gelen("req-c", "av-3", null, "2026-08-22", "10:00:00", "16:00:00"), lounge_name: null },
  ];
  r = await renderScreen("Gelen İstekler · salon adı yok", React.createElement(S.RequestsPanel, {
    t, lang: "tr", session, onOpenChat: () => {}, onOpenProfile: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, has(r.texts, `${yilsiz("2026-08-22")} · 10:00–16:00`),
        "salon adı boşken gün+saat yine görünüyor");

  // ---------- 14) KEŞFET: HAVAYOLU ÇİPİ + KENDİ BAŞVURU DURUMUM ----------
  // v2.87 · madde 5 ve 9. Cihazda görülen iki eksik:
  //   · ilanın havayolu firması kartta HİÇ yazmıyordu (kural motorunun en
  //     sert girdilerinden biri: "THY'li AJet'liyi alamıyor"),
  //   · dolu ilanda kullanıcı KENDİSİNİN kabul edilenlerden olup olmadığını
  //     göremiyordu — kart yalnız kapasiteyi anlatıyordu.
  data({});
  globalThis.__DATA.rpc.carrier_options = [
    { code: "TK", name: "Turkish Airlines" }, { code: "VF", name: "AJet" },
  ];
  // av-9 DOLU ilan ve kullanıcının ona başvurusu YOK -> "başvurmadın".
  // av-8 AÇIK ilan ve başvurusu KABUL edilmiş -> "kabul edildin".
  // ⚠ Taşıyıcı KEŞİF RPC'sinden gelmiyor (RETURNS TABLE'da yok); ekran onu
  // `availabilities` tablosundan okuyor — fikstür de öyle kuruluyor.
  globalThis.__DATA.tables.availabilities = [
    { id: "av-9", carrier: "TK" }, { id: "av-8", carrier: "VF" },
  ];
  globalThis.__DATA.tables.requests = [
    { id: "r-8", avail_id: "av-8", status: "accepted", created_at: ago(60) },
  ];
  r = await renderScreen("Keşfet · havayolu + kendi durumum", React.createElement(S.Discovery, {
    t, lang: "tr", session, scope: null, onBack: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  // 🔴 3 EYLÜL — KART TASARIM 02'YE İNDİ (Gökberk: "anlaştığımız tasarımı
  // birebir uygula"). Taşıyıcı ADI ve "başvurmadın" çipi karttan çıktı;
  // kalan üç çip: misafir politikası · uçuş numarası · aynı uçuş. Kendi
  // durumum kart-alt satırında ("Kabul edildi" / "Gönderildi"); dolu ilan
  // "Dolu" çipi. Bu senaryo artık ONU kanıtlıyor.
  check(r.name, has(r.texts, "Kabul edildi"),
        "kabul edilmiş başvuru kart-alt satırında yazıyor (madde 9 · tasarım 02)");
  check(r.name, has(r.texts, "Dolu"),
        "dolu ilan 'Dolu' çipi taşıyor (madde 9)");
  check(r.name, !has(r.texts, "Turkish Airlines") && !has(r.texts, "Bu ilana başvurmadın"),
        "taşıyıcı adı ve 'başvurmadın' çipi kartta yok — tasarım 02'nin üç çipi dışına çıkılmıyor");

  // ---------- 15) SEYAHATLERİM: uyumlu ilan sayısı + Keşfet yönlendirmesi ----------
  // v2.87 · madde 11. Seyahat kartı karşı tarafta bir şey olup olmadığını
  // söylemiyordu ve tek düğmesi Tanış'a gidiyordu.
  data({});
  globalThis.__DATA.rpc.discover_availabilities = [
    { id: "av-7", host_id: OTHER, airport_code: "IST", lounge_name: "IGA Lounge",
      avail_date: GUN, time_from: "15:00:00", time_to: "19:00:00",
      slots: 2, filled: 0, fully_booked: false, match_score: 70, host_name: "Açık Host" },
  ];
  r = await renderScreen("Seyahatlerim · uyumlu ilan sayısı", React.createElement(S.Trips, {
    t, lang: "tr", session, onDiscover: () => {}, onOpenChat: () => {},
    onAddTrip: () => {}, onGuide: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, has(r.texts, "uyumlu ilan"),
        "seyahat kartı bu güne uyan ilan SAYISINI yazıyor (madde 11)");
  check(r.name, !has(r.texts, "◈"),
        "Tanış'a giden ◈ düğmesi kaldırıldı — yönlendirme Keşfet'e (madde 11)");

  // ---------- 16) SEYAHATLERİM: uyumlu ilan YOKKEN dürüst cevap ----------
  data({});
  globalThis.__DATA.rpc.discover_availabilities = [];
  r = await renderScreen("Seyahatlerim · uyumlu ilan yok", React.createElement(S.Trips, {
    t, lang: "tr", session, onDiscover: () => {}, onOpenChat: () => {},
    onAddTrip: () => {}, onGuide: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, has(r.texts, "uyumlu ilan yok"),
        "sıfırken boş listeye göndermek yerine sebebi yazıyor");

  // ---------- 17) PLAN: fiyat ve aylık kredi hakkı ----------
  // v2.87 · madde 8. "plan sayfasındaki her şey ücretsiz yazıyor. Ayrıca
  // kredi hakkı neden yok." Ücretli planın fiyatı ve `monthly_credits`
  // karşılığı ekranda görünmeli; "Ücretsiz" YALNIZ fiyat gerçekten 0 iken.
  data({});
  // Alan adları SQL 220'nin ETKİN tanımından: aylik_fiyat / yillik_fiyat /
  // aylik_kredi. (Ekran eskiden 210'un fiyat_try adını okuyordu — kusur buydu.)
  globalThis.__DATA.rpc.subscription_plans = [
    { plan: "explorer", ad: "Yolcu", aylik_fiyat: 0, aylik_kredi: 2, haklar: ["Ayda 2 istek"] },
    { plan: "steward", ad: "Kâhya", aylik_fiyat: 249, yillik_fiyat: 2490, aylik_kredi: 12,
      yillik_indirim_yuzde: 17, haklar: ["Öncelikli eşleşme"] },
  ];
  globalThis.__DATA.rpc.my_plan = { known: true, etkin: "explorer", ad: "Yolcu", neden: "Ücretsiz plandasın." };
  r = await renderScreen("Plan · fiyat ve kredi", React.createElement(S.Plans, {
    t, lang: "tr", session, onBack: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, has(r.texts, "₺249"), "ücretli plan FİYATIYLA görünüyor — 'ücretsiz' değil");
  check(r.name, has(r.texts, "Ayda 12 kredi"), "aylık kredi hakkı ekranda (madde 8)");
  check(r.name, has(r.texts, "Ayda 2 kredi"), "ücretsiz planın kredi hakkı da yazıyor");

  // ---------- 18) PLAN: fiyat alanı hiç gelmezse "ücretsiz" DENMEZ ----------
  // Kök neden buydu: okunamayan fiyat `!ucret` ile "Ücretsiz"e dönüşüyordu.
  data({});
  globalThis.__DATA.rpc.subscription_plans = [
    { plan: "steward", ad: "Kâhya", haklar: ["Öncelikli eşleşme"] },
  ];
  globalThis.__DATA.rpc.my_plan = null;
  r = await renderScreen("Plan · fiyat okunamıyor", React.createElement(S.Plans, {
    t, lang: "tr", session, onBack: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, !has(r.texts, "Ücretsiz"),
        "fiyat bilinmiyorken 'Ücretsiz' YAZMIYOR — bilmemek bedava demek değil");
  check(r.name, has(r.texts, "Fiyat okunamadı"), "bilinmeyen fiyat açıkça söyleniyor");

  // ---------- 19) YAYIN: dolu ilan yeşil "0 slot açık" göstermiyor ----------
  // v2.87 · madde 4. Dolu ilanda ekranda çıplak bir "0" kalıyor ve
  // "0 slot açık" YEŞİL yazıyordu.
  // 29 Eylül — tarih SABİTTİ (2026-08-06) ve zamanla GEÇMİŞE düştü; kural "dolu
  // CANLI ilan 'Dolu' der". Geçmiş ilan artık "Tarihi geçti" diyor (Gökberk md.1),
  // test ileri tarihli canlı ilanla ölçüyor.
  const ileriGun = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
  data({ extra: { availabilities: [{ id: "av-1", host_id: UID, airport_code: "IST",
    lounge_name: "Primeclass Lounge", avail_date: ileriGun, time_from: "14:00:00",
    time_to: "18:00:00", slots: 2, filled: 2, active: true, carrier: "VF" }] } });
  globalThis.__DATA.rpc.carrier_options = [{ code: "VF", name: "AJet" }];
  globalThis.__DATA.rpc.host_requests = [];
  r = await renderScreen("Yayın · dolu ilan", React.createElement(S.Hosting, {
    t, session, onOpenChat: () => {}, onAddAvail: () => {}, onAddCard: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, !has(r.texts, "0 slot açık"), "dolu ilanda '0 slot açık' YAZMIYOR (madde 4)");
  check(r.name, has(r.texts, "Dolu"), "yerine 'Dolu' yazıyor");
  check(r.name, has(r.texts, "AJet"), "host kendi ilanının havayolunu görüyor (madde 5)");

  // ---------- 19b) YAYIN: geçmiş ilan "yer açık" SÖZÜ VERMİYOR (29 Eylül, Gökberk md.1) ----------
  data({ extra: { availabilities: [{ id: "av-2", host_id: UID, airport_code: "IST",
    lounge_name: "Primeclass Lounge", avail_date: "2026-08-06",   // BİLEREK geçmiş: test tam da bunu ölçüyor time_from: "14:00:00",
    time_to: "18:00:00", slots: 3, filled: 1, active: true, carrier: "VF" }] } });
  r = await renderScreen("Yayın · geçmiş ilan", React.createElement(S.Hosting, {
    t, session, onOpenChat: () => {}, onAddAvail: () => {}, onAddCard: () => {} }));
  check(r.name, r.ok, r.ok ? "çökmeden açılıyor" : "ÇÖKTÜ: " + r.err);
  check(r.name, !has(r.texts, "yer açık"), "geçmiş ilanda 'X yer açık' YAZMIYOR");
  check(r.name, has(r.texts, "Tarihi geçti"), "durumunu söylüyor: 'Tarihi geçti'");
  check(r.name, has(r.texts, "1 misafir ağırlandı"), "sonucunu söylüyor: ağırlanan misafir");

  // ══════════════════════════════════════════════════════════════════
  // MUTLU YOL ZİNCİRİ — HER ADIM BİR SONRAKİNİ GÖSTERİYOR MU?
  //
  // 🔴 NEDEN AYRI BİR BLOK
  // Buraya kadarki senaryolar her ekranı TEK BAŞINA ölçüyor: açılıyor mu,
  // doğru metni yazıyor mu. Ama bir ürünün çalışması ekranların
  // toplamı değil, ARALARINDAKİ GEÇİŞTİR. Bir ekran kusursuz açılıp
  // kullanıcıyı bir sonraki adıma taşımıyorsa, akış orada biter ve
  // hiçbir tekil denetim bunu görmez.
  //
  // TEST_PROTOKOL.md'deki zincir: ilan → başvuru → kabul → sohbet →
  // oturum → tamamla → puanla → bağlan. Her adımda o adımın EKRANINI
  // gerçek durumuyla mount edip, BİR SONRAKİ adımın çağrısının
  // çizildiğini arıyoruz.
  //
  // 🆕 SINIF: "EKRANLARI TEK TEK DOĞRULAMAK, AKIŞI DOĞRULAMAZ —
  // KULLANICI EKRANDA DEĞİL, EKRANLAR ARASINDA KAYBOLUR."
  // ══════════════════════════════════════════════════════════════════

  // 4 · KABUL EDİLDİ → sohbette "Oturumu Başlat" görünmeli
  data({ sessions: [] });
  r = await renderScreen("Zincir 4 · kabul → oturum başlat", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "sohbet açılıyor");
  check(r.name, has(r.texts, "Oturumu Başlat") || has(r.texts, "Aktif İşaretle"),
        "bir sonraki adım görünür: oturumu başlat");

  // 5 · OTURUM AKTİF → "Oturumu Tamamla" görünmeli
  data({ sessions: [{ id: "s-z", request_id: "req-1", status: "active", started_at: ago(20),
                      cancel_grace_until: ago(15), host_confirmed: false, guest_confirmed: false,
                      host_started_at: ago(20), guest_started_at: ago(20) }] });
  r = await renderScreen("Zincir 5 · aktif → tamamla", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "sohbet açılıyor");
  check(r.name, has(r.texts, "Tamamla"), "bir sonraki adım görünür: oturumu tamamla");

  // 6 · TAMAMLANDI → puanlama çağrısı görünmeli
  data({ sessions: [{ id: "s-z", request_id: "req-1", status: "completed", started_at: ago(90),
                      ended_at: ago(10), host_confirmed: true, guest_confirmed: true,
                      host_started_at: ago(90), guest_started_at: ago(90) }] });
  r = await renderScreen("Zincir 6 · tamamlandı → puanla", React.createElement(S.Chat, {
    t, session, request: REQ, otherName: "Elif K.", onBack: () => {} }));
  check(r.name, r.ok, "sohbet açılıyor");
  check(r.name, has(r.texts, "puanla") || has(r.texts, "Puanla") || has(r.texts, "Değerlendir"),
        "bir sonraki adım görünür: puanlama");

  // 3 · GELEN İSTEK → "kabul et" çağrısı görünmeli
  data({ extra: { requests: [{ ...REQ, status: "pending",
      users: { name: "Elif K." }, profiles: { name: "Elif K." } }] } });
  r = await renderScreen("Zincir 3 · gelen istek → kabul", React.createElement(S.RequestsPanel, {
    t, session, onOpenChat: () => {} }));
  check(r.name, r.ok, "istek paneli açılıyor");

  // ---------- RAPOR ----------
  const fail = results.filter(x => !x.ok);
  const byScen = {};
  results.forEach(x => { (byScen[x.scen] = byScen[x.scen] || []).push(x); });
  Object.entries(byScen).forEach(([scen, list]) => {
    const bad = list.filter(x => !x.ok);
    console.log((bad.length ? "✗ " : "✓ ") + scen + (bad.length ? "  → " + bad.map(b => b.label).join(" | ") : ""));
  });
  console.log("\nToplam kontrol: " + results.length + " · başarısız: " + fail.length);
  process.exit(fail.length ? 1 : 0);
})();
