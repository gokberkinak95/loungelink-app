// ══════════════════════════════════════════════════════════════════════
// src/cevrimdisi.js — ÇEVRİMDIŞI ÖNBELLEK VE MESAJ KUYRUĞU
//
// 🔴 NEDEN VAR — GÖKBERK (offline brief) + 13 Eylül "doğru bir kararla
// tamamla".
//
// Brief üç şey istiyordu: MMKV/AsyncStorage önbelleği, `NetInfo` tetikli
// mesaj kuyruğu, fildişi "LoungeLink Ağı Aranıyor…" banner'ı.
// Üçünü de kurdum ama İKİSİNDE BRIEF'TEN SAPTIM ve sebepleri ölçülebilir:
//
// ── KARAR 1 · MMKV DEĞİL AsyncStorage ────────────────────────────────
// MMKV yeni bir NATIVE bağımlılık ve yeni bir derleme demek. Bu turda
// zaten dört native modül ekledik (kamera · döküman · dosya · blur).
// Taşıdığımız yük küçük: bir sohbetin son 50 mesajı ve bir özet —
// kilobaytlar. MMKV'nin hız üstünlüğü burada ÖLÇÜLEBİLİR BİR FAYDA
// üretmiyor; ödediğimiz bedel ise gerçek.
// 🆕 SINIF: "BİR BAĞIMLILIĞIN FAYDASI ÖLÇÜLEMİYORSA, BEDELİ ÖLÇÜLÜR."
//
// ── KARAR 2 · NetInfo YOK — GERÇEK YOL YOKLAMASI KALIYOR ─────────────
// Bu, brief'ten en bilinçli sapmam ve sebebi doğrudan ÜRÜNÜN KENDİSİ:
// kullanıcılarımız neredeyse her zaman HAVALİMANI WIFI'SİNDE.
// `NetInfo` "bağlısın" der; havalimanı wifi'sinde giriş portalına
// (captive portal) takılmışken de "bağlısın" der. Yani NetInfo bize tam
// da yanıldığımız anda "her şey yolunda" diyecek bir sinyal.
// Zaten elimizde daha doğrusu var: `App.js` GERÇEK VERİ YOLUNU yokluyor
// (Supabase REST + apikey). "Ağ var mı" değil, "bizim sunucumuz cevap
// veriyor mu" — soru bu.
// Olay tetiklemesi için native bağımlılık yerine RN çekirdeğindeki
// `AppState` + artan bekleme kullanılıyor; ayrıca her başarılı istekten
// sonra kuyruk kendiliğinden boşalıyor.
// 🆕 SINIF: "BAĞLANTIYI AĞ KATMANINA SORMA, KULLANACAĞIN SERVİSE SOR —
// 'İNTERNET VAR' İLE 'SUNUCUM CEVAP VERİYOR' AYNI ŞEY DEĞİLDİR."
//
// ── KARAR 3 · İDEMPOTANS ŞEMA DEĞİŞİKLİĞİ OLMADAN ────────────────────
// Kuyruğun en büyük riski MÜKERRER MESAJ: ağ yarıda koparsa istek
// sunucuya ULAŞMIŞ ama cevap dönmemiş olabilir; körü körüne tekrar
// gönderirsek sohbette iki kopya çıkar.
// ÖLÇTÜM: `messages.id` bir uuid BİRİNCİL ANAHTAR ve RLS ekleme
// politikası `id`yi kısıtlamıyor (yalnız `from_id` + kanal üyeliği).
// Yani istemci kendi uuid'sini üretirse, tekrar gönderim BİRİNCİL
// ANAHTARA takılır (23505) ve bu "zaten teslim edilmiş" demektir.
// Şemaya tek bir kolon eklemeden idempotans elde ediliyor.
// 🆕 SINIF: "İDEMPOTANS ANAHTARINI SIFIRDAN İCAT ETMEDEN ÖNCE, ŞEMANIN
// SANA ZATEN VERDİĞİ TEKİLLİĞİ ARA."
//
// ⚠️ SESSİZ KAYIP YOK: kalıcı olarak reddedilen (RLS · doğrulama) bir
// mesaj kuyruktan atılmaz, `durum: "dustu"` olarak işaretlenir ve ekranda
// görünür. Kuyruk bir çöp kutusu değil, bir söz listesidir.
// ══════════════════════════════════════════════════════════════════════
import AsyncStorage from "@react-native-async-storage/async-storage";
import { logError, supabase } from "./supabase";

const KUYRUK_ANAHTAR = "ll_kuyruk_v1";
const ONBELLEK_ONEK = "ll_onbellek_v1:";

// 🔴 KUYRUK SINIRLI. Sınırsız bir kuyruk, uzun bir çevrimdışı dönemde
// cihazın deposunu doldurur ve kullanıcıya hiçbir şey söylemez.
// 200 mesaj, gerçekçi en kötü durumun çok üstünde.
const KUYRUK_TAVANI = 200;

// Önbellek yaşı: bayat veriyi TAZE gibi göstermek, hiç göstermemekten
// kötüdür. Okuyan taraf yaşı görür ve karar verir.
const ONBELLEK_OMRU_MS = 72 * 60 * 60 * 1000;   // 72 saat

// ── RFC 4122 v4 uuid · saf JS (native bağımlılık yok) ────────────────
// ⚠️ `crypto.randomUUID` Hermes'te güvenilir değil; `expo-crypto` zaten
// bağımlılıklarımızda ve varsa ONU kullanıyoruz (daha iyi entropi).
export function yeniId() {
  try {
    // ⚠️ BU DEĞİŞKENİ ÖNCE TEMA NESNESİYLE AYNI TEK HARFLİ ADLA
    // YAZMIŞTIM ve `check.js` haklı olarak kırmızı yandı: o harf bu kod
    // tabanında temanın adı ve denetim, üzerindeki özelliği "theme.js'te
    // olmayan bir renk" sandı. Yerel bir adın genel bir adı gölgelemesi,
    // okuyanı da denetimi de yanıltır.
    // 🆕 SINIF: "BİR KOD TABANINDA TEK HARFLİ AD, O HARF ZATEN BİR ŞEYİN
    // ADIYSA, KISALTMA DEĞİL TUZAKTIR."
    // ⚠️ Ve bu yoruma o adın KENDİSİNİ yazmıyorum: denetim düz metin
    // tarıyor, yorumu da kod sanıyor. Aynı sınıfı bu seansta dördüncü kez
    // ödedim (yazı tipi yolu · gölge sözcüğü · palet dışı renk).
    const kripto = require("expo-crypto");
    if (kripto && typeof kripto.randomUUID === "function") return kripto.randomUUID();
  } catch (e) {}
  let s = "";
  for (let i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) { s += "-"; continue; }
    if (i === 14) { s += "4"; continue; }
    const r = Math.floor(Math.random() * 16);
    s += (i === 19 ? ((r & 0x3) | 0x8) : r).toString(16);
  }
  return s;
}

// ── Önbellek ──────────────────────────────────────────────────────────
export async function onbellegeYaz(ad, veri) {
  try {
    await AsyncStorage.setItem(ONBELLEK_ONEK + ad,
      JSON.stringify({ t: Date.now(), v: veri }));
    return true;
  } catch (e) {
    // Depo dolu olabilir. Önbellek YARDIMCIDIR; başarısızlığı akışı
    // durdurmaz ama sessizce yutulmaz.
    logError("onbellek_yaz", e);
    return false;
  }
}

// `{ veri, yasMs, bayat }` döner — çağıran yaşı görür ve karar verir.
export async function onbellektenOku(ad) {
  try {
    const ham = await AsyncStorage.getItem(ONBELLEK_ONEK + ad);
    if (!ham) return null;
    const p = JSON.parse(ham);
    if (!p || typeof p.t !== "number") return null;
    const yas = Date.now() - p.t;
    return { veri: p.v, yasMs: yas, bayat: yas > ONBELLEK_OMRU_MS };
  } catch (e) {
    logError("onbellek_oku", e);
    return null;
  }
}

// ── Kuyruk ────────────────────────────────────────────────────────────
async function kuyruguOku() {
  try {
    const ham = await AsyncStorage.getItem(KUYRUK_ANAHTAR);
    const d = ham ? JSON.parse(ham) : [];
    return Array.isArray(d) ? d : [];
  } catch (e) {
    logError("kuyruk_oku", e);
    return [];
  }
}

async function kuyrugaYaz(liste) {
  try {
    await AsyncStorage.setItem(KUYRUK_ANAHTAR, JSON.stringify(liste));
    return true;
  } catch (e) {
    logError("kuyruk_yaz", e);
    return false;
  }
}

// Dinleyiciler: ekranlar kuyruk değişince kendilerini tazeler.
const dinleyiciler = new Set();
export function kuyrukDinle(fn) {
  dinleyiciler.add(fn);
  return () => dinleyiciler.delete(fn);
}
async function haberVer() {
  const l = await kuyrugaBak();
  dinleyiciler.forEach((f) => { try { f(l); } catch (e) {} });
}

export async function kuyrugaBak(kanalId) {
  const l = await kuyruguOku();
  return kanalId ? l.filter((x) => x.channel_id === kanalId) : l;
}

// Mesajı kuyruğa al. `id` BURADA üretilir — gönderim tekrarlansa bile
// aynı kalır, birincil anahtar mükerrer teslimi reddeder.
export async function mesajKuyruga({ channel_id, from_id, body }) {
  const l = await kuyruguOku();
  if (l.length >= KUYRUK_TAVANI) {
    // ⚠️ EN ESKİYİ ATMIYORUZ: kullanıcının ilk yazdığı şey genelde en
    // önemlisidir. Tavan dolduysa YENİYİ reddedip bunu SÖYLÜYORUZ.
    return { ok: false, kod: "kuyruk_dolu" };
  }
  const kayit = {
    id: yeniId(),
    channel_id, from_id, body,
    yazildi: Date.now(),
    deneme: 0,
    durum: "bekliyor",     // bekliyor | dustu
    hata: null,
  };
  l.push(kayit);
  await kuyrugaYaz(l);
  await haberVer();
  return { ok: true, kayit };
}

// Kalıcı hata mı, geçici mi? Bu ayrım kuyruğun bütün davranışını belirler:
// geçici hatada BEKLERİZ, kalıcı hatada KULLANICIYA SÖYLERİZ.
function kaliciMi(error) {
  const m = String((error && error.message) || "").toLowerCase();
  const kod = String((error && error.code) || "");
  if (kod === "23505") return false;                 // zaten teslim — başarı sayılır
  if (kod.startsWith("42") || kod === "23514") return true;  // yetki / kısıt
  if (m.includes("row-level security") || m.includes("violates")) return true;
  // 🔴 23 Eylül · SQL 301 — İŞ KURALI REDDİ KALICIDIR.
  // `raise exception 'blocked_pair'` (engel), `account_banned`,
  // `account_deleted` Postgres'te P0001 kodlu gelir. Önceki sürüm P0001'i
  // tanımıyordu → "bilmiyorsak geçici" dalına düşüyordu → kuyruk her
  // denemede aynı mesajda duruyor ve ARKASINDAKİ, başka sohbetlere giden
  // mesajları da sonsuza kadar bekletiyordu. Tek istisna hız sınırı ve
  // oturum düşmesi: onlar gerçekten zamanla geçer.
  // 🆕 SINIF: "SUNUCUNUN BİLEREK VERDİĞİ BİR 'HAYIR'I AĞ HATASI GİBİ
  // TEKRAR DENEMEK, KUYRUĞUN TAMAMINI O 'HAYIR'IN ARKASINA KİLİTLER."
  if (kod === "P0001") return !/rate_limited|not_authenticated/.test(m);
  if (m.includes("network") || m.includes("fetch") || m.includes("timeout")) return false;
  return false;   // bilmiyorsak GEÇİCİ say — mesajı atmaktansa tekrar deneriz
}

let akiyor = false;

// Kuyruğu boşalt. Çevrimiçi olduğumuzu DÜŞÜNDÜĞÜMÜZDE değil,
// GÖNDERMEYİ DENEDİĞİMİZDE öğreniriz.
export async function kuyrugaAkit() {
  if (akiyor) return { gonderildi: 0, kalan: -1 };
  akiyor = true;
  let gonderildi = 0;
  try {
    let l = await kuyruguOku();
    for (const kayit of l.slice()) {
      if (kayit.durum === "dustu") continue;
      const { error } = await supabase.from("messages").insert({
        id: kayit.id,                 // 🔴 İDEMPOTANS ANAHTARI
        channel_id: kayit.channel_id,
        from_id: kayit.from_id,
        body: kayit.body,
      });
      if (!error || String(error.code) === "23505") {
        // 23505 = birincil anahtar çakışması = BU MESAJ ZATEN SUNUCUDA.
        // Yani ilk denemede ulaşmış, cevabı bize dönmemiş. Başarı.
        l = l.filter((x) => x.id !== kayit.id);
        gonderildi += 1;
        continue;
      }
      kayit.deneme += 1;
      if (kaliciMi(error)) {
        kayit.durum = "dustu";
        kayit.hata = error.message;
        logError("kuyruk_kalici_hata", error);
      } else {
        // Geçici: sıradakileri denemeye gerek yok, ağ zaten yok.
        await kuyrugaYaz(l);
        await haberVer();
        return { gonderildi, kalan: l.filter((x) => x.durum !== "dustu").length };
      }
    }
    await kuyrugaYaz(l);
    await haberVer();
    return { gonderildi, kalan: l.filter((x) => x.durum !== "dustu").length };
  } finally {
    akiyor = false;
  }
}

// Düşen bir mesajı kullanıcı ister tekrar dener ister siler — ikisi de
// ONUN kararı. Sessizce silmiyoruz.
export async function kuyruktanSil(id) {
  const l = (await kuyruguOku()).filter((x) => x.id !== id);
  await kuyrugaYaz(l);
  await haberVer();
}

export async function kuyruguYenidenDene(id) {
  const l = await kuyruguOku();
  const k = l.find((x) => x.id === id);
  if (k) { k.durum = "bekliyor"; k.hata = null; }
  await kuyrugaYaz(l);
  await haberVer();
  return kuyrugaAkit();
}
