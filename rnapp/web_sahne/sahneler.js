// web_sahne/sahneler.js — SAHNE → OTURUM. Veri yerel Postgres'ten (pg_kopru)
// gelir; burada yalnız "kim olarak bakıyoruz" ve köprü adresi kurulur.
// Ekran içi gezinme (sekmeye dokunma, karta dokunma) cek.py'de gerçek
// tıklamalarla yapılır — uygulamanın kendi yolundan.
const KISI = {
  gokberk: { id: "a1b2c3d4-0000-4000-8000-00000000000a", email: "gokberk@sahne.loungelink.test" },
  selin:   { id: "a1b2c3d4-0000-4000-8000-00000000000f", email: "selin@sahne.loungelink.test" },
  kaan:    { id: "a1b2c3d4-0000-4000-8000-000000000010", email: "kaan@sahne.loungelink.test" },
  deniz:   { id: "a1b2c3d4-0000-4000-8000-00000000000d", email: "deniz@sahne.loungelink.test" },
  // SEED6 test hesapları (sql/SEED6_TEST_DUNYASI.sql) — ana sayfa akış denetimi
  host1:   { id: "33330001-0000-4000-8000-000000000001", email: "host1@seed.loungelink.test" },
  guest1:  { id: "33330003-0000-4000-8000-000000000003", email: "guest1@seed.loungelink.test" },
  // 12 Eylül · gece — DURUM kapsamı için iki kişi (bkz. sahne_seed.sql)
  yeni:    { id: "a1b2c3d4-0000-4000-8000-000000000015", email: "yeni@sahne.loungelink.test" },
  hazir:   { id: "a1b2c3d4-0000-4000-8000-000000000016", email: "hazir@sahne.loungelink.test" },
  bos:     { id: "a1b2c3d4-0000-4000-8000-000000000017", email: "bos@sahne.loungelink.test" },
  // 13 Eylül · Not2 — BOŞ HOST. Planım'ın boş hâli host tarafında hiç
  // çekilmemişti; üç boş kişinin üçü de misafirdi (bkz. sahne_seed.sql).
  boshost: { id: "a1b2c3d4-0000-4000-8000-000000000018", email: "boshost@sahne.loungelink.test" },
  // 1 Ekim — SEED8 + SEED9 akış dünyası (sql/SEED9_AKIS_GENIS.sql): her durumdan veri
  nehir:   { id: "88880000-0000-4000-8000-000000000001", email: "akis.host@seed.loungelink.test" },
  arda:    { id: "88880000-0000-4000-8000-000000000011", email: "akis.misafir@seed.loungelink.test" },
  // 4 Ekim 2026 — uçtan uca akış testi (akis_e2e.py) için uç durum kişileri
  tuna:    { id: "88880000-0000-4000-8000-000000000002", email: "akis.host2@seed.loungelink.test" },
  selen:   { id: "88880000-0000-4000-8000-000000000003", email: "akis.host3@seed.loungelink.test" },
  bora:    { id: "88880000-0000-4000-8000-000000000012", email: "akis.misafir2@seed.loungelink.test" },
  cem:     { id: "88880000-0000-4000-8000-000000000013", email: "akis.misafir3@seed.loungelink.test" },
  duru:    { id: "88880000-0000-4000-8000-000000000014", email: "akis.misafir4@seed.loungelink.test" },
  ela:     { id: "88880000-0000-4000-8000-000000000021", email: "akis.kural@seed.loungelink.test" },
  can:     { id: "88880000-0000-4000-8000-000000000022", email: "akis.kredisiz@seed.loungelink.test" },
  mina:    { id: "88880000-0000-4000-8000-000000000023", email: "akis.dogrulanmamis@seed.loungelink.test" },
  mert:    { id: "a1b2c3d4-0000-4000-8000-00000000000e", email: "mert@sahne.loungelink.test" },
  ece:     { id: "a1b2c3d4-0000-4000-8000-000000000011", email: "ece@sahne.loungelink.test" },
};

export function sahneKur(ad, q) {
  globalThis.__CFG = { rpc: {}, tables: {} };
  globalThis.__KOPRU = q.get("kopru") || "http://127.0.0.1:8765";
  const kim = q.get("kim") || "";
  const k = KISI[kim];
  globalThis.__SESSION = k ? { user: { id: k.id, email: k.email, app_metadata: { provider: "email" } }, access_token: "sahne" } : null;
  globalThis.__ONAY_ACIK = q.get("onay") === "acik";   // 4 Ekim 2026: e-posta doğrulaması açık kayıt
  // 🔴 12 Eylül · gece — AMBİYANS SABİTLENİYOR. `Atmosfer`in ufuk kuşağı
  // artık günün saatine bağlı; sahne görüntüleri saate bağlı olamaz.
  // `?an=safak|gunduz|aksam|gece` ile dört kuşak da çekilebiliyor.
  globalThis.__LL_AMBIYANS = q.get("an") || "aksam";
  // `?bozuk=ad1,ad2` — o RPC/tablo çağrıları ağ hatası döndürür (arıza sahneleri)
  globalThis.__BOZUK = (q.get("bozuk") || "").split(",").map(x => x.trim()).filter(Boolean);
  try {
    // dil ve tanıtım bayrağı: sahne her açılışta temiz başlar
    window.localStorage.clear();
    window.localStorage.setItem("ll_lang", q.get("dil") || "tr");
    if (k) window.localStorage.setItem("ll_onb", "1");
  } catch (e) {}
}
