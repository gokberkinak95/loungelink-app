// ============================================================
// LoungeLink · Sosyal kimlik doğrulama (v1.74)
//
// TASARIM KARARI — neden bu yol:
//  • Google: Supabase'in OAuth akışı + sistem tarayıcısı (expo-web-browser).
//    Google, uygulama içine gömülü WebView'da oturum açmayı YASAKLIYOR
//    (disallowed_useragent hatası), bu yüzden openAuthSessionAsync ile
//    sistem tarayıcısı kullanılır. Ek native modül gerekmez, aynı kod
//    Android ve iOS'ta çalışır.
//  • Apple: iOS'ta expo-apple-authentication ile NATIVE düğme. App Store
//    kuralı: başka bir sosyal giriş sunuyorsan (Google) "Sign in with Apple"
//    sunmak ZORUNLU. Native akış, tarayıcı akışından daha hızlı ve
//    Apple'ın tasarım kurallarına uyar. Android'de aynı düğme Supabase'in
//    web OAuth akışıyla (sistem tarayıcısı) çalışır — tasarım 16 tek.
//
// ⚠️ SUNUCU TARAFI KURULUM (Supabase Dashboard → Authentication → Providers)
// bu kod çalışmadan önce bir kez yapılmalı:
//   1) Google: Google Cloud'da OAuth istemcisi (Web + Android + iOS) aç,
//      Client ID/Secret'ı Supabase'e gir. Yetkili yönlendirme adresi:
//      https://<proje>.supabase.co/auth/v1/callback
//   2) Apple: Apple Developer'da Service ID + Key oluştur, Supabase'e gir.
//   3) Supabase → URL Configuration → Redirect URLs listesine ekle:
//      loungelink://auth-callback
// Kurulum yapılmadan düğmeye basılırsa kullanıcıya anlaşılır hata gösterilir.
// ============================================================

import * as WebBrowser from "expo-web-browser";
import * as ExpoLinking from "expo-linking";
import * as AppleAuthentication from "expo-apple-authentication";
import * as Crypto from "expo-crypto";
import { Platform } from "react-native";
import { supabase, logError } from "./supabase";

WebBrowser.maybeCompleteAuthSession();

export const REDIRECT_URL = ExpoLinking.createURL("auth-callback");
// Şifre sıfırlama maili UYGULAMAYA dönmeli (backoffice'e değil — oraya
// yalnız admin girebiliyor). Supabase Redirect URLs listesine eklenmeli.
export const RESET_REDIRECT = ExpoLinking.createURL("reset-password");

// 4 Eylül — onaylanan tasarım 16'da Apple düğmesi VAR ve tasarım tek
// (platforma göre ayrılmıyor). Android'de Apple hesabı beklentisi düşük
// ama sıfır değil (iPhone'dan Android'e geçen, iCloud e-postasıyla kayıt
// olmuş kullanıcı); Supabase'in Apple sağlayıcısı web OAuth ile Android'de
// de çalışır (Service ID + Key kurulumu aynı). iOS'ta native akış kalır.
export async function appleAvailable() {
  // 🔴 22 EYLÜL — ANDROID'DE APPLE DÜĞMESİ KALKTI (Gökberk: "androidde
  // apple olmamalı sonuçta"). Önceki hâl Android'de `true` dönüyordu ve
  // düğmeyi web OAuth'a yönlendiriyordu; bu ancak Supabase'de Apple
  // sağlayıcısı (Service ID + Key) kuruluysa çalışır. Kurulu değilken
  // düğme kullanıcıyı çıkmaza götürüyordu — ve kurulu olsa bile Android
  // kullanıcısına Apple girişi teklif etmek alışılmış değil.
  // 🆕 SINIF: "BİR GİRİŞ YÖNTEMİNİ, ARKASINDAKİ KURULUMUN VARLIĞINI
  // ÖLÇMEDEN GÖSTERMEK, KULLANICIYA ÇALIŞMAYAN BİR KAPI AÇMAKTIR."
  if (Platform.OS !== "ios") return false;
  try { return await AppleAuthentication.isAvailableAsync(); } catch (e) { return false; }
}

// --- SİSTEM TARAYICISIYLA OAUTH (Google her yerde · Apple Android'de) ----
// Dönüş: { ok: true } | { ok: false, code: "<hata kodu>" }
// İptal ayrı bir kod döner ki ekranda hata gibi gösterilmesin.
export async function signInWithGoogle() { return tarayiciOAuth("google"); }

async function tarayiciOAuth(provider) {
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
      // 4 Ekim 2026 — Google: hesap seçici HER SEFERİNDE. Çıkış yapınca sistem tarayıcısındaki
      // Google oturumu kalıyordu; "Google ile devam et" sessizce SON hesaba giriyordu — birden
      // çok Google hesabı olan kişi kayıt olduğu hesabı seçemiyordu.
      options: { redirectTo: REDIRECT_URL, skipBrowserRedirect: true,
                 ...(provider === "google" ? { queryParams: { prompt: "select_account" } } : {}) },
    });
    if (error) return { ok: false, code: error.message };
    if (!data?.url) return { ok: false, code: "oauth_no_url" };

    const res = await WebBrowser.openAuthSessionAsync(data.url, REDIRECT_URL);
    if (res.type !== "success" || !res.url) return { ok: false, code: "cancelled" };

    // Supabase geri dönüşte ya ?code= (PKCE) ya da #access_token= gönderir.
    const url = res.url;
    // 4 Ekim 2026 — sunucu girişi REDDETTİYSE (ör. silme sürecindeki / yasaklı hesap: "User is
    // banned") hata adresin içinde gelir; eskiden "oauth_no_token" diye genel hataya düşüyordu.
    const hataAciklama = /[?&#]error_description=([^&]+)/.exec(url)?.[1];
    if (hataAciklama) return { ok: false, code: decodeURIComponent(hataAciklama.replace(/\+/g, " ")) };
    const code = /[?&]code=([^&]+)/.exec(url)?.[1];
    if (code) {
      const { error: e2 } = await supabase.auth.exchangeCodeForSession(decodeURIComponent(code));
      if (e2) return { ok: false, code: e2.message };
      return { ok: true };
    }
    const at = /[#&]access_token=([^&]+)/.exec(url)?.[1];
    const rt = /[#&]refresh_token=([^&]+)/.exec(url)?.[1];
    if (at && rt) {
      const { error: e3 } = await supabase.auth.setSession({
        access_token: decodeURIComponent(at), refresh_token: decodeURIComponent(rt),
      });
      if (e3) return { ok: false, code: e3.message };
      return { ok: true };
    }
    return { ok: false, code: "oauth_no_token" };
  } catch (e) {
    return { ok: false, code: String(e?.message || e) };
  }
}

// --- APPLE (iOS native · Android sistem tarayıcısı) -------------
export async function signInWithApple() {
  if (Platform.OS !== "ios") return tarayiciOAuth("apple");
  try {
    // nonce: Apple'ın döndürdüğü kimlik jetonunun bu isteğe ait olduğunu
    // kanıtlar (yeniden oynatma saldırısına karşı). Apple'a hash'i,
    // Supabase'e ham hali verilir.
    const rawNonce = Crypto.randomUUID();
    const hashedNonce = await Crypto.digestStringAsync(
      Crypto.CryptoDigestAlgorithm.SHA256, rawNonce
    );
    const cred = await AppleAuthentication.signInAsync({
      requestedScopes: [
        AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
        AppleAuthentication.AppleAuthenticationScope.EMAIL,
      ],
      nonce: hashedNonce,
    });
    if (!cred?.identityToken) return { ok: false, code: "apple_no_token" };

    const { error } = await supabase.auth.signInWithIdToken({
      provider: "apple", token: cred.identityToken, nonce: rawNonce,
    });
    if (error) return { ok: false, code: error.message };

    // Apple ADI YALNIZCA İLK GİRİŞTE verir — kaçırılırsa bir daha gelmez.
    // Bu yüzden hemen profile yazılır (profil boşsa).
    const full = [cred.fullName?.givenName, cred.fullName?.familyName].filter(Boolean).join(" ").trim();
    if (full) {
      const { data: u, error: hata1 } = await supabase.auth.getUser();
      if (hata1) logError("social.js:113", hata1);
      const uid = u?.user?.id;
      if (uid) {
        const { data: p, error: eP } = await supabase.from("profiles").select("name").eq("user_id", uid).maybeSingle();
  if (eP) logError("social_profile", eP);
        if (!p?.name || p.name.includes("@")) {
          await supabase.from("profiles").update({ name: full }).eq("user_id", uid);
        }
      }
    }
    return { ok: true };
  } catch (e) {
    const msg = String(e?.code || e?.message || e);
    if (msg.includes("ERR_REQUEST_CANCELED") || msg.includes("canceled")) return { ok: false, code: "cancelled" };
    return { ok: false, code: msg };
  }
}

// --- ONBOARDING DURUMU ----------------------------------------
// Sosyal girişte kayıt sihirbazı ATLANIR; rol, cinsiyet ve sözleşme onayları
// alınmamış olur. Burası "bu kullanıcının tamamlaması gereken adım var mı?"
// sorusunun TEK cevabıdır — hem sosyal hem klasik giriş sonrası çağrılır.
export async function needsOnboarding(uid) {
  // 🔴 v1.81 (Gokberk 3/3.1): bu ekran KLASİK GİRİŞTE ÇIKMAMALI. Önceki sürüm
  // "consents kaydı yoksa" diye bakıyordu; eski hesaplarda ve onay kaydı
  // farklı sürümle yazılmış kullanıcılarda bu koşul doğru çıkıyor ve normal
  // giriş sonrası "Son bir adım" ekranı açılıyordu.
  //
  // Doğru kural: tamamlama YALNIZCA sosyal kimlikle (Google/Apple) gelip
  // kayıt sihirbazını hiç görmemiş kullanıcı için gerekir. Ölçüt:
  //   · oturum sağlayıcısı e-posta DEĞİL (app_metadata.provider)
  //   · VE kullanım şartları onayı yok (rol ölçütü işe yaramıyordu — aşağıda)
  // İkisi birden yoksa ekran açılmaz.
  if (!uid) return false;
  try {
    const { data: au, error: hata2 } = await supabase.auth.getUser();
    if (hata2) logError("social.js:149", hata2);
    const provider = au?.user?.app_metadata?.provider || "email";
    if (provider === "email") return false;          // klasik kayıt → sihirbaz zaten çalıştı

    // 🔴 4 Ekim 2026 — "ROL YOK" ÖLÇÜTÜ HİÇBİR ZAMAN DOĞRU OLMUYORDU.
    // Kayıt tetikleyicisi (`handle_new_user`) rolü `coalesce(meta.role, 'guest')`
    // ile yazar: sosyal kimlikle gelen herkes `guest` doğar, `users.role` asla
    // boş kalmaz. Bu yüzden tamamlama ekranı hiç açılmıyordu — Google/Apple
    // ile gelen kullanıcı ROL SEÇMEDEN misafir oluyor ve SÖZLEŞME ONAYI hiç
    // alınmıyordu (KVKK kanıtı yok).
    // Doğru ölçüt sihirbazın kendi izi: kullanım şartları onayı (terms_privacy).
    // Sosyal hesapta bu kayıt yoksa sihirbaz hiç görülmemiştir. Klasik (e-posta)
    // giriş bu fonksiyonun yukarısında döndüğü için v1.81'in yanlış alarmı geri gelmez.
    const { data: on, error: eOn } = await supabase.from("consents")
      .select("type").eq("user_id", uid).eq("type", "terms_privacy").limit(1);
    if (eOn) { logError("social_onay", eOn); return false; }
    return !(on && on.length);                        // sosyal + onay yok → tamamlama gerekir
  } catch (e) {
    return false;   // şüphede kalırsak kullanıcıyı ASLA kilitleme
  }
}
