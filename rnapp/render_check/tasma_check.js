// ============================================================
// LoungeLink · render_check/tasma_check.js
//
// UYGULAMA GENELİ TAŞMA KAPISI
//
// Her ekranı GERÇEK veriyle mount eder → React Native'in kendi düzen
// motoruna (Yoga) verir → her `<Text>`in kutusunu hesaplar → o metnin
// GERÇEK ttf genişliğiyle karşılaştırır.
//
// 🔴 BU KAPI NEDEN YAZILDI: 30 Ağustos'ta cihaz ekran görüntüsünde
// "LOUNGEPUAN" etiketi ayracı aşıyordu. Ben bir tur önce tam o etikete
// `adjustsFontSizeToFit` eklemiş ve "taşma çözüldü" demiştim.
// Ekran görüntüsünü ölçtüm: etiket 9pt değil ~13.7pt çiziliyordu —
// yani eklediğim özellik metni KÜÇÜLTMEMİŞ, ~1.5 kat BÜYÜTMÜŞ.
//
// 🆕 SINIF: "HİÇ RENDER EDİLDİĞİNİ GÖRMEDİĞİM BİR ÖZELLİK BİR ÇÖZÜM
// DEĞİL BİR VARSAYIMDIR — VE YANLIŞ YÖNE ÇALIŞAN BİR VARSAYIM,
// DÜZELTTİĞİNİ SANDIĞIN HATAYI BÜYÜTEREK GERİ GETİRİR."
//
// EŞİKLER
//   TOLERANS  : 0.5pt — kerning yok sayıldığı için ölçüm üst sınırdır;
//               bu kadarlık fark yuvarlamayla açıklanabilir.
//   CIHAZLAR  : en dar yaygın cihaz (320pt · iPhone SE 1) ve tasarımın
//               referans genişliği (390pt). Dar cihazda geçen, geniş
//               cihazda da geçer; tersi doğru değildir.
// ============================================================
const fs = require("fs");
const path = require("path");
const { renderScreen, t, S, session, UID, OTHER, React } = require("./runner");
const { olc } = require("./yoga_duzen");

const TOLERANS = 0.5;
const CIHAZLAR = [
  { ad: "SE 320", en: 320, boy: 568 },
  { ad: "Ref 390", en: 390, boy: 844 },
];
const BUTCE = path.join(__dirname, "..", "tasma_butce.json");

const ago = (m) => new Date(Date.now() - m * 60000).toISOString();

const REQ = {
  id: "req-1", host_id: UID, guest_id: OTHER, avail_id: "av-1", status: "accepted",
  intro_message: "Uçuş öncesi kahve içelim mi?",
  availabilities: { lounge_name: "Primeclass Lounge", airport_code: "IST",
                    time_from: "14:00:00", time_to: "18:00:00", avail_date: "2026-08-06" },
};

// 🔴 FİKSTÜR EN UZUN GERÇEK DEĞERLERİ TAŞIR.
// Kısa bir isimle ("Ali") test edersem hiçbir şey taşmaz ve kapı
// yalan söyler. Buradaki değerler ürünün İZİN VERDİĞİ uzunluklardır:
// 6 haneli LoungePuan, uzun salon adı, uzun meslek, uzun havalimanı.
function veri(over = {}) {
  globalThis.__DATA = {
    session,
    tables: {
      requests: [REQ],
      chat_channels: [{ id: "ch-1", request_id: "req-1" }],
      messages: [{ id: "m1", channel_id: "ch-1", from_id: OTHER,
                   body: "Merhaba, güvenlikten yeni çıktım.", created_at: ago(5) }],
      sessions: [],
      profiles: [{ user_id: UID, name: "Gökberk İnak", guest_capacity: 2,
                   access_source: "Priority Pass",
                   bio: "Sık uçan biriyim, lounge'da sohbet etmeyi severim.",
                   languages: ["Türkçe", "İngilizce"],
                   profession: "Yatırım Bankacılığı", show_on_discovery: true }],
      users: [{ id: UID, role: "host", gender: "male", phone: "+905551112233" }],
      verifications: [{ user_id: UID, phone_verified: true, email_verified: true, id_verified: true }],
      trust_scores: [{ user_id: UID, score: 144, badge: "verified",
                       components: { email: 10, phone: 10, id: 18, profession: 6,
                                     bio: 6, host_access: 8, sessions: 6 } }],
      availabilities: [{ id: "av-1", host_id: UID, airport_code: "IST",
                         lounge_name: "Turkish Airlines Business Lounge",
                         avail_date: "2026-08-06", time_from: "14:00:00",
                         time_to: "18:00:00", slots: 2, filled: 1, active: true }],
      visits: [{ id: "v-1", user_id: UID, airport_code: "IST", visit_date: "2026-08-06",
                 time_from: "13:00:00", time_to: "19:00:00", flight_number: "TK712",
                 purpose: "business" }],
      airports: [{ code: "IST", name: "İstanbul Havalimanı", city: "İstanbul" },
                 { code: "SAW", name: "Sabiha Gökçen Havalimanı", city: "İstanbul" }],
      rewards: [{ id: "r1", title: "Priority Pass Misafir Kartı",
                  subtitle: "1 misafir · 60+ ülke", category: "lounge",
                  cost_points: 15000, active: true, sort_order: 1 }],
      notifications: [{ id: "n1", user_id: UID, category: "requests",
                        title: "İstek kabul edildi", body: "Sohbet açıldı.",
                        read: false, created_at: ago(10) }],
      connection_requests: [], invites: [], ratings: [], credit_ledger: [],
      points_ledger: [], user_balances: [{ user_id: UID, balance: 144 }],
      lounges: [], consents: [], subscriptions: [],
      ...over,
    },
    rpc: {
      discover_availabilities: [
        { id: "av-8", host_id: "aaa", airport_code: "IST",
          lounge_name: "Turkish Airlines Business Lounge", avail_date: "2026-08-06",
          time_from: "14:00:00", time_to: "18:00:00", slots: 2, filled: 0,
          fully_booked: false, match_score: 74, host_name: "Gökberk İnak",
          host_badge: "trusted", host_score: 72, has_trip: true,
          host_profession: "Yatırım Bankacılığı" },
      ],
      discover_people: [
        { user_id: "bbb", name: "Ayşegül Demirtaş", profession: "Yazılım Mühendisliği",
          badge: "verified", score: 56, rel: "none", airport: "IST",
          visit_date: "2026-08-06", flight_number: "TK712", same_flight: true,
          is_hosting: false, can_request: false, req_reason: "noslot" },
      ],
      host_requests: [{ id: "req-9", guest_id: OTHER, guest_name: "Ayşegül Demirtaş",
        guest_profession: "Yazılım Mühendisliği", guest_score: 44,
        guest_id_verified: true, guest_phone_verified: true, same_flight: true,
        same_purpose: true, flight_number: "TK712",
        intro_message: "Uçuş öncesi kahve içmek isterim.", status: "pending",
        match_score: 70, guest_sessions: 0, guest_rating_count: 0, avail_id: "av-1" }],
      invitable_guests: [{ guest_id: OTHER, name: "Ayşegül Demirtaş",
                           profession: "Fintech", sessions_count: 6, invite_status: "none" }],
      my_referral: { code: "GOKBERK2026" }, has_active_session: false,
      expire_stale_sessions: { ok: true }, recompute_trust: 144,
      kural_kosullari: [], lounge_access_decision_v5: null,
      // 🔴 BOŞ DÖNEN EKRAN, ÖLÇÜLMÜŞ EKRAN DEĞİLDİR.
      // İlk çalıştırmada 8 gömülü kart `null` döndü ve kapı bunu
      // "sorun yok" saydı. Veri yoksa kart hiç çizilmez — yani en
      // kalabalık bileşenler tam da ölçümün dışında kalır.
      //
      // 🆕 SINIF: "VERİSİ OLMAYAN BİR BİLEŞEN HATASIZ DEĞİL,
      // GÖRÜNMEZDİR — VE GÖRÜNMEYEN BİR ŞEY DENETLENMİŞ SAYILMAZ."
      ana_sayfa_akisi: { sohbet: 3, istek: 12, davet: 2, soru: 24, ilan: 5 },
      bekleyen_islemler: [{ tur: "rate", id: "s-1", baslik: "Oturumu değerlendir" }],
      lounge_radar: { airport: "IST", lounge_name: "Turkish Airlines Business Lounge",
                      kisi: 4, durum: "acik" },
      baglanti_istekleri: [{ id: "c-1", from_id: OTHER, name: "Ayşegül Demirtaş",
                             profession: "Yazılım Mühendisliği", score: 44 }],
      ulasilabilirlik: { durum: "acik", metin: "Bugün Esenboğa'dasın" },
    },
  };
}

// 🔴 KAPSAM ÜRÜNDEN TÜRETİLİYOR, ELLE YAZILMIYOR.
// `src/screens.js` + akış modülleri neyi dışa veriyorsa o denetlenir.
// Elle yazılmış bir liste, ürünün değil benim hafızamın sınırında kalır
// — ve unutulan her ekran, hiç denetlenmediği hâlde denetlenmiş sayılır.
// Uygulamanın KENDİ `import { … } from "./src/screens"` satırı okunuyor.
// `src/screens.js`in tüm dışa verdikleri DEĞİL — çünkü orada ekran
// olmayan yardımcılar da var (`ilanDurumu`, `isoOf`, `intentLabel`…).
// App.js'in içeri aldığı isim = ürünün ekran olarak SAYDIĞI şey.
function ekranlar() {
  const kaynak = fs.readFileSync(path.join(__dirname, "..", "App.js"), "utf8");
  const m = kaynak.match(/import\s*\{([^}]+)\}\s*from\s*["']\.\/src\/screens["']/);
  if (!m) {
    console.log("✗ App.js içinde `from \"./src/screens\"` import'u bulunamadı —");
    console.log("  kapsam türetilemiyor. Kapı elle yazılmış listeye DÜŞMEZ.");
    process.exit(1);
  }
  const adlar = m[1].split(",").map((s) => s.trim().split(/\s+as\s+/)[0].trim()).filter(Boolean);
  const liste = [];
  const yok = [];
  for (const ad of adlar) {
    if (/^use[A-Z]/.test(ad)) continue;           // hook, ekran değil
    const B = S[ad];
    if (typeof B !== "function") { yok.push(ad); continue; }
    liste.push([ad, B]);
  }

  // 🔴 ANA SAYFA, SPLASH, TANITIM, GİRİŞ VE KAYIT `App.js` İÇİNDE.
  // `src/screens.js`ten geçen liste bunları HİÇ görmüyordu — yani
  // kullanıcının en çok baktığı ekran (ana sayfa cüzdan şeridi) ve
  // ilk gördüğü üç ekran ölçüm dışıydı. Tam da cihazda taşan yerler.
  //
  // 🆕 SINIF: "BİR KAPININ KAPSAMI, ÜRÜNÜN DOSYA DÜZENİNE GÖRE
  // ŞEKİLLENİYORSA, EN ÇOK BAKILAN EKRAN EN AZ DENETLENEN EKRAN OLUR."
  let APPMOD = null;
  try { APPMOD = require(path.join(__dirname, "..", "App.js")); } catch (e) {
    console.log("   ⚠ App.js yüklenemedi: " + String(e.message).split("\n")[0]);
  }
  if (APPMOD) {
    // İKİ dışa verme biçimi de okunuyor: satır içi `export function X`
    // ve dosya sonundaki `export { A, B, C }`. Yalnız birini okusaydım
    // diğer biçimdeki ekranlar sessizce kapsam dışında kalırdı.
    const appAdlari = new Set();
    for (const em of kaynak.matchAll(/^export function ([A-Z]\w*)\s*\(/gm)) appAdlari.add(em[1]);
    for (const em of kaynak.matchAll(/^export\s*\{([^}]+)\}\s*;?\s*$/gm)) {
      for (const p of em[1].split(",")) {
        const ad = p.trim().split(/\s+as\s+/).pop().trim();
        if (/^[A-Z]/.test(ad)) appAdlari.add(ad);
      }
    }
    for (const ad of appAdlari) {
      if (typeof APPMOD[ad] === "function") liste.push(["App:" + ad, APPMOD[ad]]);
      else yok.push("App:" + ad);
    }
  }

  if (yok.length) console.log(`   ⚠ ${yok.length} isim çözülemedi: ${yok.join(", ")}`);
  return liste.sort((a, b) => a[0].localeCompare(b[0]));
}

// Gömülü kartlar veri yoksa `null` döner. Bu bayraklar onları AÇAR —
// yoksa kapı "ölçtüm" der ama ekranın yarısı hiç çizilmemiştir.
const NOP = () => {};
function PROPS() {
  return {
    t, lang: "tr", session, avail: null, mode: "login",
    embedded: true, hepAcik: true, goster: true, yalnizGelen: false,
    // Chat `request.host_id` okuyor; prop'suz mount edilemiyordu.
    request: REQ, otherName: "Ayşegül Demirtaş", openPanel: null,
    scope: null, focusAvailId: null, refresh: 0, tazele: 0, rol: "host",
    onBack: NOP, onDone: NOP, onClose: NOP, onOpen: NOP, onRefresh: NOP,
    onOpenChat: NOP, onOpenProfile: NOP, onOpenCompanion: NOP, onDiscover: NOP,
    onAddTrip: NOP, onEditTrip: NOP, onGuide: NOP, onAddAvail: NOP, onAddCard: NOP,
    onEditAvail: NOP, onFocusDone: NOP, onManagePlan: NOP, onSafety: NOP,
    onTrust: NOP, onHistory: NOP, onReferral: NOP, onRatings: NOP, onLogout: NOP,
    onWallet: NOP, onShop: NOP, onSettings: NOP, onEditProfile: NOP,
    onCampaigns: NOP, onBell: NOP, onBroadcast: NOP, onVerify: NOP, onRate: NOP,
    onRole: NOP, setRadar: NOP, setTab: NOP, setHostTripsSub: NOP,
    setShowQuestions: NOP, setMeetSub: NOP, setShowIstekler: NOP,
    onSohbetler: NOP, onIstekler: NOP, onDavetler: NOP, onSorular: NOP,
    onIlanlar: NOP, go: NOP, toggleLang: NOP, setLang: NOP, setLangGlobal: NOP,
    navigate: NOP, suggest: null,
  };
}

(async () => {
  const bulgular = [];
  const cokenler = [];
  const bosalanlar = [];
  let olculenMetin = 0, olculenEkran = 0;

  for (const [ad, Bilesen] of ekranlar()) {
    veri();
    let r;
    try {
      r = await renderScreen(ad, React.createElement(Bilesen, PROPS()));
    } catch (e) { cokenler.push([ad, String(e.message || e).split("\n")[0]]); continue; }
    if (!r.ok) { cokenler.push([ad, r.err]); continue; }

    const json = r.tree.toJSON();
    if (!json) { bosalanlar.push(ad); continue; }
    olculenEkran++;

    for (const cihaz of CIHAZLAR) {
      const { bulgular: b } = await olc(json, cihaz.en, cihaz.boy);
      olculenMetin += b.length;
      if (process.env.TASMA_DOKUM === ad) {
        console.log(`\n── DÖKÜM · ${ad} · ${cihaz.ad} ──`);
        for (const x of b) {
          console.log(`  ${x.gerekli.toFixed(1).padStart(7)} / ${x.genislik.toFixed(1).padStart(7)}` +
                      `  @${x.punto}${x.tekSatir ? " ·1sat" : "     "}  "${x.metin.slice(0, 40)}"`);
        }
      }
      for (const m of b) {
        if (m.fark > TOLERANS) {
          bulgular.push({ ekran: ad, cihaz: cihaz.ad, metin: m.metin,
                          gerekli: +m.gerekli.toFixed(1), kutu: +m.genislik.toFixed(1),
                          fark: +m.fark.toFixed(1), punto: m.punto, tekSatir: m.tekSatir,
                          kucult: m.kucult });
        }
      }
    }
  }

  // ── rapor ────────────────────────────────────────────────
  // Aynı metin iki cihazda da taşıyorsa tek satır: en kötü olan.
  const tekil = new Map();
  for (const b of bulgular) {
    const k = b.ekran + "|" + b.metin;
    if (!tekil.has(k) || tekil.get(k).fark < b.fark) tekil.set(k, b);
  }
  const liste = [...tekil.values()].sort((a, b) => b.fark - a.fark);

  console.log("── TAŞMA ÖLÇÜMÜ ────────────────────────────────────");
  console.log(`   ${olculenEkran} ekran · ${olculenMetin} metin ölçümü · ` +
              `${CIHAZLAR.map((c) => c.ad).join(" + ")}`);
  if (cokenler.length) {
    console.log(`   ⚠ ${cokenler.length} ekran mount edilemedi (ölçülmedi):`);
    for (const [ad, e] of cokenler.slice(0, 8)) console.log(`     · ${ad} — ${e}`);
  }
  if (bosalanlar.length) console.log(`   ⚠ ${bosalanlar.length} ekran boş döndü: ${bosalanlar.join(", ")}`);

  if (liste.length) {
    console.log(`\n   ✗ ${liste.length} TAŞMA:`);
    for (const b of liste.slice(0, 40)) {
      const et = b.kucult ? " [adjustsFontSizeToFit]" : b.tekSatir ? " [tek satır]" : "";
      console.log(`     · ${b.ekran} · "${b.metin.slice(0, 44)}" ` +
                  `${b.gerekli}pt gerekiyor, ${b.kutu}pt var (${b.fark}pt taşma)` +
                  ` @${b.punto}pt${et} · ${b.cihaz}`);
    }
    if (liste.length > 40) console.log(`     … ve ${liste.length - 40} tane daha`);
  }

  // ── bütçe (tavan yalnız DÜŞER) ───────────────────────────
  let butce = { tavan: null };
  try { butce = JSON.parse(fs.readFileSync(BUTCE, "utf8")); } catch (e) {}
  const tavan = butce.tavan;
  if (tavan == null) {
    fs.writeFileSync(BUTCE, JSON.stringify({ tavan: liste.length,
      not: "Taşma sayısı tavanı. YALNIZ DÜŞER — yükseltmek bir gerileme kaydıdır." }, null, 2));
    console.log(`\n   → tavan ${liste.length} olarak kaydedildi.`);
    process.exit(liste.length === 0 ? 0 : 1);
  }
  if (liste.length > tavan) {
    console.log(`\n✗ TAŞMA ARTTI: tavan ${tavan}, şimdi ${liste.length}.`);
    process.exit(1);
  }
  if (liste.length < tavan) {
    fs.writeFileSync(BUTCE, JSON.stringify({ tavan: liste.length,
      not: "Taşma sayısı tavanı. YALNIZ DÜŞER — yükseltmek bir gerileme kaydıdır." }, null, 2));
    console.log(`\n   ↓ tavan ${tavan} → ${liste.length} indirildi.`);
  }
  console.log(liste.length === 0
    ? "\n✓ Hiçbir metin kutusunu aşmıyor (320pt ve 390pt)."
    : `\n✓ Taşma tavanı korundu (${liste.length}).`);
  process.exit(0);
})().catch((e) => { console.error("KAPI ÇÖKTÜ:", e); process.exit(1); });
