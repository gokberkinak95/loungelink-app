import "react-native-url-polyfill/auto";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient } from "@supabase/supabase-js";
import { Platform } from "react-native";
import Constants from "expo-constants";

// 🔴 v1.83 — ANAHTAR ROTASYONU KOLAYLIĞI
// Adres ve YAYINLANABİLİR anahtar artık app.json → expo.extra üzerinden de
// okunabiliyor. Anahtarı döndürdüğünde tek yerde (app.json) değiştirmen
// yeterli; kod dosyasına dokunmaya gerek yok. app.json'da yoksa aşağıdaki
// varsayılan kullanılır (mevcut davranış korunur).
// NOT: bu anahtar zaten İSTEMCİDE bulunmak zorunda olan "publishable" anahtar;
// asıl gizli olan SUPABASE_SECRET_KEY yalnızca backoffice sunucusunda durur.
const extra = (Constants?.expoConfig?.extra) || (Constants?.manifest?.extra) || {};
const SUPABASE_URL = extra.supabaseUrl || "https://wgprynisnriyblccxuhq.supabase.co";
const SUPABASE_KEY = extra.supabaseAnonKey || "sb_publishable_UDlDQ7369xubMMYeuZRzNQ_jvY4Kfv9";

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_KEY,
  {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      // React Native'de adresten oturum okuma YOK (o tarayıcıya özgü).
      // Gelen bağlantıyı src/deeplink.js elle çözer — v1.84.
      detectSessionInUrl: false,
      // 🔴 v1.84 — BİLİNÇLİ KARAR: implicit akış.
      // PKCE'de doğrulayıcı (code_verifier) YALNIZCA isteği başlatan
      // cihazın deposunda durur. Şifre sıfırlama bağlantısı e-postadan
      // açıldığında sık sık BAŞKA bir yerde açılır (masaüstü tarayıcı,
      // e-posta uygulamasının içindeki tarayıcı). Orada PKCE kodu
      // takas EDİLEMEZ ve kullanıcı yine çıkmaz sokağa düşer.
      // Implicit akışta jeton adresin kendisinde geldiği için hem
      // uygulama hem backoffice köprüsü (/sifre-sifirla) işini yapabilir.
      // Kütüphane varsayılanı ileride değişirse diye AÇIKÇA yazıldı.
      flowType: "implicit",
    },
  }
);

// ============================================================
// Üretim hata kaydı (SQL 063).
// Amaç: uygulamada bir şey kırılırsa BUNU KULLANICIDAN ÖĞRENMEK ZORUNDA
// KALMAMAK. Bugüne kadar sessizce kırık kalan hatalar (host kabul edememesi,
// slot sayacı) tam olarak görünürlük olmadığı için aylarca fark edilmedi.
//
// Kurallar:
//  • ASLA throw etmez, ASLA await beklenmesi gerekmez — akışı bozmaz.
//  • Kişisel veri göndermez; yalnız ekran adı + hata mesajı + sürüm.
// ============================================================
let __appVersion = "";
export function setAppVersion(v) { __appVersion = v || ""; }

export function logError(screen, err, code) {
  try {
    const message = typeof err === "string" ? err : (err?.message || String(err || "?"));
    supabase.rpc("log_client_error", {
      p_screen: String(screen || "?").slice(0, 80),
      p_message: message.slice(0, 500),
      p_code: code ? String(code).slice(0, 60) : null,
      p_version: __appVersion,
      p_platform: Platform.OS,
      p_context: null,
    }).then(() => {}, () => {});   // sessiz: log yazamamak sorun değil
  } catch (e) { /* yut */ }
}
