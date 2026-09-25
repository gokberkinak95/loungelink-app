// ============================================================
// LoungeLink · src/deeplink.js  (v1.84)
//
// 🔴 ŞİFRE SIFIRLAMANIN GERÇEK KÖK NEDENİ
//
// v1.83'te `resetPasswordForEmail`in redirectTo'su `loungelink://reset-password`
// yapıldı ve App.js'e `PASSWORD_RECOVERY` olayını dinleyen bir satır kondu.
// Ama o olay UYGULAMADA HİÇ TETİKLENMEZ:
//
//   supabase-js oturumu adresten ancak `detectSessionInUrl: true` iken
//   okur ve bu özellik SADECE TARAYICIDA çalışır (window.location'a bakar).
//   src/supabase.js'te — doğru olarak — `detectSessionInUrl: false` yazıyor.
//   React Native'de gelen adresi okumak UYGULAMANIN İŞİDİR: Linking ile
//   yakala, jetonu ayrıştır, setSession/verifyOtp çağır.
//
//   Uygulamada ne `Linking.getInitialURL()` ne de `Linking.addEventListener("url")`
//   vardı. Yani bağlantı uygulamayı açsa bile hiçbir şey olmuyordu:
//   kullanıcı splash ekranında kalıyordu.
//
// İKİNCİ NEDEN (Gokberk'in gördüğü asıl davranış — mailin Vercel'e gitmesi):
//   Supabase, `redirectTo` adresi **Redirect URLs beyaz listesinde yoksa**
//   onu SESSİZCE yok sayar ve **Site URL**'e düşer. Site URL şu an
//   backoffice/Vercel adresi → mail oraya gidiyor. Bu bir kod hatası değil,
//   sunucu ayarı; ama biz koda ayara BAĞIMLI OLMAYAN bir çıkış yolu koyduk:
//   backoffice'teki `/sifre-sifirla` köprüsü jetonu yakalayıp uygulamaya
//   geri fırlatıyor, uygulama yoksa aynı sayfada şifre belirletiyor.
//   Yani ayar yanlışken bile kullanıcı çıkmaz sokağa düşmüyor.
//
// Bu dosya gelen HER auth adresini tek yerde çözer. Desteklenen biçimler:
//   · #access_token=...&refresh_token=...&type=recovery   (implicit — bizim akış)
//   · ?code=...                                           (PKCE / OAuth dönüşü)
//   · ?token_hash=...&type=recovery                       (yeni e-posta şablonu)
//   · ?error=...&error_code=...&error_description=...     (süresi dolmuş bağlantı)
// ============================================================

import { supabase } from "./supabase";

// Hem '#' hem '?' parçalarını tek sözlükte toplar. Supabase bazen ikisini
// birden kullanır (…/reset-password?foo=1#access_token=…), o yüzden ayrı ayrı
// bakmak yerine hepsini birleştiriyoruz.
export function parseAuthParams(url) {
  const out = {};
  const s = String(url || "");
  const idx = Math.min(
    ...[s.indexOf("?"), s.indexOf("#")].filter((i) => i >= 0).concat([s.length])
  );
  const tail = idx >= s.length ? "" : s.slice(idx + 1);
  for (const chunk of tail.split(/[#?]/)) {
    for (const kv of chunk.split("&")) {
      if (!kv) continue;
      const i = kv.indexOf("=");
      if (i <= 0) continue;
      try {
        out[decodeURIComponent(kv.slice(0, i))] =
          decodeURIComponent(kv.slice(i + 1).replace(/\+/g, " "));
      } catch (e) { /* bozuk kodlama: o parametreyi atla */ }
    }
  }
  return out;
}

// Adreste auth ile ilgili bir şey var mı? (Rastgele derin bağlantılarda
// boşuna Supabase çağrısı yapmayalım.)
export function isAuthUrl(url) {
  const p = parseAuthParams(url);
  return !!(p.access_token || p.code || p.token_hash || p.error || p.error_code);
}

// Dönüş: { ok, type, message }
//   type: 'recovery' | 'signup' | 'magiclink' | 'oauth' | null
//   ok=false ise message KULLANICIYA GÖSTERİLEBİLİR bir metindir.
export async function applyAuthUrl(url, t) {
  const p = parseAuthParams(url);
  const type = p.type || (p.code ? "oauth" : null);
  const tr = t || {};

  // 1) Sunucu hata döndürdüyse (en sık: bağlantının süresi dolmuş)
  if (p.error || p.error_code) {
    const code = String(p.error_code || p.error || "");
    const expired = /expired|otp_expired|invalid/i.test(code + " " + (p.error_description || ""));
    return {
      ok: false,
      type,
      message: expired
        ? (tr.dlExpired || "Bağlantının süresi dolmuş. Lütfen yeni bir sıfırlama bağlantısı iste.")
        : (p.error_description || tr.dlFailed || "Bağlantı doğrulanamadı."),
    };
  }

  try {
    // 2) implicit akış — jetonlar adres parçasında
    if (p.access_token && p.refresh_token) {
      const { error } = await supabase.auth.setSession({
        access_token: p.access_token,
        refresh_token: p.refresh_token,
      });
      if (error) return { ok: false, type, message: error.message };
      return { ok: true, type: type || "recovery" };
    }

    // 3) yeni e-posta şablonu — token_hash + type
    if (p.token_hash && p.type) {
      const { error } = await supabase.auth.verifyOtp({
        token_hash: p.token_hash,
        type: p.type,
      });
      if (error) return { ok: false, type, message: error.message };
      return { ok: true, type: p.type };
    }

    // 4) PKCE / OAuth dönüşü
    if (p.code) {
      const { error } = await supabase.auth.exchangeCodeForSession(p.code);
      if (error) return { ok: false, type, message: error.message };
      return { ok: true, type: type || "oauth" };
    }
  } catch (e) {
    return { ok: false, type, message: String(e && e.message ? e.message : e) };
  }

  return { ok: false, type: null, message: null };  // auth adresi değil — sessiz geç
}
