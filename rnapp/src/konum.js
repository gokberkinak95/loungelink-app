// ============================================================================
// konum.js — "Bulunduğum havalimanı" (23 Ekim, 1.0)
// ----------------------------------------------------------------------------
// KURALLAR
// · İzin penceresi YALNIZ kullanıcı düğmeye bastığında açılır (push.js ile aynı ilke:
//   ömür boyu bir kez sorulabilen soruyu, değeri anlaşılmadan sormak soruyu harcamaktır).
// · Yalnız ön plan izni; arka plan konumu app.json'da kapalı ve Android'de engelli.
// · Konum TELEFONDAN ÇIKMAZ: en yakın havalimanı burada hesaplanır, sunucuya hiçbir
//   koordinat gitmez, saklanmaz (App Privacy: "konum toplanmıyor" doğru kalır).
// · Düşük doğruluk yeter (havalimanı km ölçeğinde); önce son bilinen konum denenir.
// ============================================================================
import * as Location from "expo-location";
import { Linking } from "react-native";
import { HAVALIMANI_KONUM } from "./havalimani_konum";
import { logError } from "./supabase";

// Havalimanı alanı içindeyken bile terminal–pist arası 5–8 km olabilir; 25 km şehir
// merkezinden "havalimanındayım" demeyi engeller ama terminal otoparkını kaçırmaz.
export const KONUM_ESIK_KM = 25;

function km(a, b) {
  const R = 6371, rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(b[0] - a[0]), dLon = rad(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Saf hesap (test edilebilir): konuma en yakın, listede OLAN havalimanı.
export function enYakini(nokta, kodlar) {
  let en = null;
  for (const kod of kodlar) {
    const k = HAVALIMANI_KONUM[kod];
    if (!k) continue;
    const d = km(nokta, k);
    if (!en || d < en.km) en = { kod, km: d };
  }
  return en;
}

// Dönüş: { durum: "bulundu" | "uzak" | "reddedildi" | "kapali" | "hata", kod?, km?, tekrar? }
export async function bulundugumHavalimani(kodlar) {
  try {
    let izin = await Location.getForegroundPermissionsAsync();
    if (izin.status !== "granted" && izin.canAskAgain !== false) {
      izin = await Location.requestForegroundPermissionsAsync();
    }
    if (izin.status !== "granted") return { durum: "reddedildi", tekrar: izin.canAskAgain !== false };
    if (!(await Location.hasServicesEnabledAsync())) return { durum: "kapali" };
    let p = await Location.getLastKnownPositionAsync({ maxAge: 10 * 60 * 1000, requiredAccuracy: 5000 });
    // Kapalı alanda (terminal) ilk konum gecikebilir; 12 sn'de gelmezse "okunamadı" — düğme sonsuza dek
    // "Konumun okunuyor…" demesin.
    if (!p) p = await Promise.race([
      Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Low }),
      new Promise((_, ret) => setTimeout(() => ret(new Error("konum_zaman_asimi")), 12000)),
    ]);
    const en = enYakini([p.coords.latitude, p.coords.longitude], kodlar);
    if (!en || en.km > KONUM_ESIK_KM) return { durum: "uzak" };
    return { durum: "bulundu", kod: en.kod, km: Math.max(1, Math.round(en.km)) };
  } catch (e) {
    logError("konum_havalimani", e);
    return { durum: "hata" };
  }
}

export function konumAyarlariniAc() {
  return Linking.openSettings && Linking.openSettings().catch(() => {});
}
