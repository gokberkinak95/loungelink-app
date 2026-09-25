// ============================================================
// runtime.js — v2.77
// SUNUCUDAN GELEN İKİ ŞEY: BAYRAKLAR ve METİN DÜZELTMELERİ
//
// 🔴 NEDEN VAR — ÖLÇÜMLE BULUNDU:
// BO'da iki ekran vardı ve ikisi de kullanıcıya bir SÖZ veriyordu:
//   /manage/flags      → "sorun çıkarsa anında kaparsın"
//   /manage/i18n       → "metni buradan değiştirirsin, anında yansır"
// Üç kod tabanında grep attım: `feature_flags` tablosunu okuyan tek
// fonksiyonun (`flag_enabled`) SIFIR çağıranı vardı; `i18n_strings`i
// okuyan tek şey aynı ekranın kendi görünümüydü. Yani iki söz de
// tutulmuyordu. Düğmeler dönüyor, hiçbir şey olmuyordu.
//
// SQL 212 sunucu tarafını bağladı (`client_flags`, `i18n_overrides`).
// Bu dosya uygulama tarafını bağlıyor.
//
// TASARIM KARARI — SÖZLÜK YERİNDE KALIYOR:
// `src/i18n.js` 2744 satırlık derli sözlük. Onu sunucuya taşımıyorum;
// çevrimdışı ilk açılış ve ilk boya hızı ondan geliyor. Sunucudan
// yalnız DEĞİŞTİRİLMİŞ anahtarlar geliyor ve üstüne biniyor. Ağ
// yoksa uygulama eskisi gibi çalışır — sadece düzeltme gecikir.
// ============================================================
import AsyncStorage from "@react-native-async-storage/async-storage";
import { supabase, logError } from "./supabase";
import { D } from "./i18n";

const ANAHTAR_BAYRAK = "ll_flags_v1";
const ANAHTAR_METIN  = "ll_i18n_v1";

// Varsayılanlar: sunucuya HİÇ ulaşılamadığında ne olacağı.
// ⚠️ Kural: kill switch varsayılanı AÇIK olmalı (ağ yokluğu pazarı
// kapatmasın), riskli/yarım özelliklerin varsayılanı KAPALI olmalı
// (ağ yokluğu ödeme akışını AÇMASIN).
const VARSAYILAN = {
  marketplace: true,
  referral: true,
  partner_channel: true,
  delay_mode: false,
  day_pass: false,
  b2b: false,
};

let _bayraklar = { ...VARSAYILAN };
let _ustKatman = { tr: {}, en: {} };
const _dinleyiciler = new Set();

export function bayrak(ad) {
  return _bayraklar[ad] === undefined ? !!VARSAYILAN[ad] : !!_bayraklar[ad];
}
export function tumBayraklar() { return { ..._bayraklar }; }

// Metin sözlüğü: derli sözlük + sunucu düzeltmeleri.
// 🔴 `D[lang]` NESNESİNİ MUTASYONA UĞRATMIYORUM. İlk denememde
// `Object.assign(D[lang], ust)` yazacaktım; o, modül seviyesindeki
// sabiti kalıcı olarak kirletir ve dil değiştirip geri dönünce eski
// metin bir daha gelmez. Yeni nesne döndürmek tek doğru yol.
export function sozluk(lang) {
  const taban = D[lang] || D.tr || {};
  const ust = _ustKatman[lang];
  if (!ust || Object.keys(ust).length === 0) return taban;
  return { ...taban, ...ust };
}

export function runtimeDinle(fn) {
  _dinleyiciler.add(fn);
  return () => _dinleyiciler.delete(fn);
}
function duyur() { _dinleyiciler.forEach(f => { try { f(); } catch (e) {} }); }

// Önce önbellekten oku (uygulama açılışı ağ beklemesin), sonra tazele.
export async function runtimeYukle() {
  try {
    const [b, m] = await Promise.all([
      AsyncStorage.getItem(ANAHTAR_BAYRAK),
      AsyncStorage.getItem(ANAHTAR_METIN),
    ]);
    if (b) _bayraklar = { ...VARSAYILAN, ...JSON.parse(b) };
    if (m) _ustKatman = { tr: {}, en: {}, ...JSON.parse(m) };
  } catch (e) {}
  duyur();
  runtimeTazele();   // bilerek await edilmiyor: açılışı bloklamaz
}

export async function runtimeTazele() {
  try {
    const { data, error } = await supabase.rpc("client_flags");
    if (error) throw error;
    if (data && typeof data === "object") {
      _bayraklar = { ...VARSAYILAN, ...data };
      await AsyncStorage.setItem(ANAHTAR_BAYRAK, JSON.stringify(data));
    }
  } catch (e) {
    // Sessiz DEĞİL: hata kaydına yazılır. Bayrak çekilemiyorsa acil
    // kapatma düğmesi de çalışmıyor demektir; bunu bilmek isteriz.
    logError("client_flags", e);
  }

  try {
    const { data, error } = await supabase.rpc("i18n_overrides", { p_lang: null });
    if (error) throw error;
    const yeni = { tr: {}, en: {} };
    (data || []).forEach(r => {
      const dil = r.dil || r.lang;
      const k = r.anahtar || r.key;
      const v = r.metin || r.value;
      if (dil && k && v) { if (!yeni[dil]) yeni[dil] = {}; yeni[dil][k] = v; }
    });
    _ustKatman = yeni;
    await AsyncStorage.setItem(ANAHTAR_METIN, JSON.stringify(yeni));
  } catch (e) {
    logError("i18n_overrides", e);
  }
  duyur();
}
