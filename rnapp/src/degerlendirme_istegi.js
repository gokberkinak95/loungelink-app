// 12 Kasım 2026 (1.0.1) — MAĞAZA DEĞERLENDİRME İSTEĞİ.
// Ne zaman: kullanıcı bir buluşmayı 4 ya da 5 yıldızla puanladıktan hemen sonra (mutlu an).
// Sıklık: cihazda en fazla 120 günde bir. Apple da yılda 3 gösterimle sınırlıyor; istek
// gösterilmezse hiçbir şey olmaz, kullanıcıya hata çıkmaz. Web'de / modül yoksa sessizce geçer.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";

const ANAHTAR = "ll_magaza_degerlendirme_son";
const ARA_MS = 120 * 24 * 3600 * 1000;

export async function magazaDegerlendirmesiIste(yildiz) {
  try {
    if (Platform.OS === "web" || !(yildiz >= 4)) return;
    const son = Number(await AsyncStorage.getItem(ANAHTAR)) || 0;
    if (Date.now() - son < ARA_MS) return;
    const m = require("expo-store-review");
    const SR = m && (m.default || m);
    if (!SR || !(await SR.hasAction())) return;
    await AsyncStorage.setItem(ANAHTAR, String(Date.now()));
    setTimeout(() => { SR.requestReview().catch(() => {}); }, 1500);
  } catch (e) { /* değerlendirme isteği isteğe bağlı: düşerse akış etkilenmez */ }
}
