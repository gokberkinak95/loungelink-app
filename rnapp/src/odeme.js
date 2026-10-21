// ============================================================
// ÖDEME · RevenueCat sarmalayıcısı (15 Ekim 2026 · SQL 332)
//
// Uygulama krediyi / planı KENDİSİ YAZMAZ. Akış:
//   satinAl(paket) → App Store / Google Play → RevenueCat
//   → webhook → BO /api/revenuecat → rc_olay_isle → kredi / plan
// Bu yüzden satın almadan sonra bakiye / plan SUNUCUDAN okunarak beklenir
// (bekleKredi / beklePlan). Mağazanın "başarılı" demesi, kredinin yüklendiği
// anlamına gelmez; kullanıcıya yalnız sunucunun gördüğünü söylüyoruz.
//
// Anahtarlar app.json → expo.extra.revenuecat.{ios,android}. Boşsa ya da web'deysek
// (sahne testleri) modül KAPALI: odemeVar() false döner, ekranlar eski davranışı korur.
// ============================================================
import { Platform, Linking } from "react-native";
import Constants from "expo-constants";
import { logError, supabase } from "./supabase";

let P = null;
let hazir = false;
let kurulum = null;
let girisYapan = null;

function anahtar() {
  const rc = (Constants.expoConfig && Constants.expoConfig.extra && Constants.expoConfig.extra.revenuecat) || {};
  if (Platform.OS === "ios") return rc.ios || "";
  if (Platform.OS === "android") return rc.android || "";
  return "";
}

export function odemeVar() {
  return Platform.OS !== "web" && !!anahtar();
}

async function kur() {
  if (hazir) return true;
  if (!odemeVar()) return false;
  if (!kurulum) {
    kurulum = (async () => {
      try {
        P = require("react-native-purchases").default;
        P.configure({ apiKey: anahtar() });
        hazir = true;
      } catch (e) {
        hazir = false;
      }
      return hazir;
    })();
  }
  return kurulum;
}

// Mağaza kimliği: Google "ll_sik_ucan:aylik" → "ll_sik_ucan_aylik" (sunucuyla aynı kural).
export function urunKodu(id) {
  return String(id || "").replace(":", "_");
}

// Oturum açılınca RevenueCat kullanıcısı = Supabase kullanıcısı. Webhook bu kimlikle gelir.
export async function odemeGiris(uid) {
  if (!uid || girisYapan === uid) return;
  if (!(await kur())) return;
  try { await P.logIn(uid); girisYapan = uid; } catch (e) { /* bir sonraki açılışta yeniden denenir */ }
}

export async function odemeCikis() {
  if (!hazir || !girisYapan) return;
  girisYapan = null;
  try { await P.logOut(); } catch (e) { /* anonim kullanıcıda logOut hata verir; önemsiz */ }
}

async function teklifler() {
  if (!(await kur())) return null;
  try { return await P.getOfferings(); } catch (e) { return null; }
}

function tumPaketler(o) {
  if (!o) return [];
  const hepsi = [];
  const gor = new Set();
  const ekle = (p) => {
    const id = p && p.product && p.product.identifier;
    if (id && !gor.has(id)) { gor.add(id); hepsi.push(p); }
  };
  Object.values(o.all || {}).forEach(of => (of.availablePackages || []).forEach(ekle));
  if (o.current) (o.current.availablePackages || []).forEach(ekle);
  return hepsi;
}

// Kredi paketleri: { "ll_kredi_3": { kredi: 3, fiyat: "₺99,99", paket } }
export async function krediPaketleri() {
  const o = await teklifler();
  const sonuc = {};
  tumPaketler(o).forEach(p => {
    const kod = urunKodu(p.product.identifier);
    const m = /^ll_kredi_(\d+)$/.exec(kod);
    if (m) sonuc[kod] = { kredi: Number(m[1]), fiyat: p.product.priceString, paket: p };
  });
  return sonuc;
}

// Abonelikler: { sik_ucan: { aylik: {fiyat, paket}, yillik: {...} }, kahya: {...} }
export async function abonelikPaketleri() {
  const o = await teklifler();
  const sonuc = {};
  tumPaketler(o).forEach(p => {
    const kod = urunKodu(p.product.identifier);
    // 21 Ekim (SQL 340) — mağaza kimliği ll_jetset_*; uygulamanın plan kodu iç kod "kahya" kalır.
    // Eski ll_kahya_* de tanınır (mağazada açılmadı; savunma için).
    const m = /^ll_(sik_ucan|kahya|jetset)_(aylik|yillik)$/.exec(kod);
    if (!m) return;
    const plan = m[1] === "jetset" ? "kahya" : m[1];
    sonuc[plan] = sonuc[plan] || {};
    sonuc[plan][m[2]] = { fiyat: p.product.priceString, paket: p };
  });
  return sonuc;
}

// { ok } · { iptal } · { bekliyor } (Google'da onay bekleyen ödeme) · { hata }
export async function satinAl(paket) {
  if (!(await kur()) || !paket) return { hata: true };
  try {
    await P.purchasePackage(paket);
    return { ok: true };
  } catch (e) {
    if (e && e.userCancelled) return { iptal: true };
    const kod = String((e && e.code) || "");
    if (kod.includes("PAYMENT_PENDING") || kod === "20") return { bekliyor: true };
    if (kod.includes("PRODUCT_ALREADY_PURCHASED") || kod === "6") return { zatenVar: true };
    return { hata: true };
  }
}

export async function geriYukle() {
  if (!(await kur())) return false;
  try { await P.restorePurchases(); return true; } catch (e) { return false; }
}

export function abonelikYonet() {
  const url = Platform.OS === "ios"
    ? "https://apps.apple.com/account/subscriptions"
    : "https://play.google.com/store/account/subscriptions?package=com.loungelink.app";
  Linking.openURL(url).catch(() => {});
}

const bekle = (ms) => new Promise(r => setTimeout(r, ms));

// Webhook gelene kadar bakiyeyi izler. Döner: yeni bakiye (arttıysa) ya da null (süre doldu).
export async function bekleKredi(uid, onceki, sureMs = 30000) {
  const son = Date.now() + sureMs;
  while (Date.now() < son) {
    await bekle(2000);
    const { data, error } = await supabase.from("user_balances").select("credits").eq("user_id", uid).maybeSingle();
    if (error) { logError("bekleKredi", error); continue; }
    const b = data ? Number(data.credits) : null;
    if (b != null && onceki != null && b > onceki) return b;
  }
  return null;
}

// Webhook gelene kadar satın alınan planı izler. Döner: true (plan yansıdı) / false.
export async function beklePlan(plan, sureMs = 30000) {
  const son = Date.now() + sureMs;
  while (Date.now() < son) {
    await bekle(2000);
    const { data, error } = await supabase.rpc("my_plan");
    if (error) { logError("beklePlan", error); continue; }
    if (data && data.satin_alinan === plan) return true;
  }
  return false;
}
