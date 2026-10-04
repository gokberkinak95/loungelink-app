// ============================================================================
// SOSYAL GİRİŞ (Google / Apple) — src/social.js'in KENDİSİ · 4 Ekim 2026
//
// Gökberk: "Google ve Apple ile signup/login akışları doğru çalışıyor ve doğru
// yönlendiriyor mu? Çıkış yapıp tekrar Google ile devam et'e basınca hesap seçimi?"
//   · Google OAuth isteği prompt=select_account taşır (çıkıştan sonra sessizce SON
//     hesaba girilmez; birden çok hesabı olan kayıt olduğu hesabı seçer)
//   · Apple isteği bu parametreyi taşımaz (Apple kendi seçicisini gösterir)
//   · sunucu girişi reddederse (silme süreci / yasak → "User is banned") hata
//     adresten okunur, genel "oauth_no_token"a düşmez
//   · kullanıcı vazgeçerse "cancelled" (hata gibi gösterilmez)
//   · PKCE ?code= dönüşü oturuma çevrilir
// ============================================================================
require("./runner");
const path = require("path");
const APP = require("./ll_paths").APP;
const { supabase } = require("./stub_supabase");   // social.js "./supabase"ı bu taklide çözer (runner)
const WebBrowser = require("expo-web-browser");
const social = require(path.join(APP, "src", "social.js"));

const sonuc = [];
const ol = (ad, kosul, not) => sonuc.push([ad, !!kosul, not || ""]);

(async () => {
  let son = null;
  supabase.auth.signInWithOAuth = async (arg) => { son = arg; return { data: { url: "https://example.test/oauth" }, error: null }; };
  let degis = null;
  supabase.auth.exchangeCodeForSession = async (c) => { degis = c; return { error: null }; };

  WebBrowser.openAuthSessionAsync = async () => ({ type: "cancel" });
  let r = await social.signInWithGoogle();
  ol("Google isteği prompt=select_account taşır (hesap seçici her seferinde)",
     son && son.provider === "google" && son.options && son.options.queryParams && son.options.queryParams.prompt === "select_account",
     JSON.stringify(son && son.options));
  ol("Vazgeçmek 'cancelled' döner (hata gösterilmez)", r && r.code === "cancelled", JSON.stringify(r));

  WebBrowser.openAuthSessionAsync = async () => ({ type: "success", url: "loungelink://auth-callback?code=abc123" });
  r = await social.signInWithGoogle();
  ol("PKCE dönüşü (?code=) oturuma çevrilir", r && r.ok && degis === "abc123", JSON.stringify(r));

  WebBrowser.openAuthSessionAsync = async () => ({ type: "success",
    url: "loungelink://auth-callback#error=access_denied&error_code=user_banned&error_description=User+is+banned" });
  r = await social.signInWithGoogle();
  ol("Sunucu reddi (User is banned) adresten okunur → uygulama 'hesap kapatıldı' der", r && !r.ok && /banned/i.test(r.code || ""), JSON.stringify(r));

  son = null;
  WebBrowser.openAuthSessionAsync = async () => ({ type: "cancel" });
  await social.signInWithApple();   // Android/test: tarayıcı akışı
  ol("Apple (tarayıcı akışı) prompt parametresi TAŞIMAZ", son && son.provider === "apple" && !(son.options && son.options.queryParams),
     JSON.stringify(son && son.options));

  const gecen = sonuc.filter((x) => x[1]).length;
  console.log("=".repeat(70) + "\nSOSYAL GİRİŞ TESTİ — Google / Apple\n" + "=".repeat(70));
  sonuc.forEach(([ad, ok, not]) => console.log(`  ${ok ? "✓" : "✗"} ${ad}${ok ? "" : "  — " + not}`));
  console.log(`\n${gecen}/${sonuc.length} sosyal giriş kontrolü geçti`);
  process.exit(gecen === sonuc.length ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(1); });
