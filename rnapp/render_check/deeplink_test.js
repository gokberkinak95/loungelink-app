// ============================================================
// LoungeLink · render_check/deeplink_test.js   (v1.84)
//
// NE DOĞRULAR: şifre sıfırlama bağlantısının UYGULAMAYA DÖNDÜĞÜNDE
// gerçekten "Yeni şifre belirle" ekranını açtığını.
//
// NEDEN GEREKLİ: v1.83'te bu akış "yazılmış" görünüyordu ama çalışmıyordu.
// `PASSWORD_RECOVERY` olayı React Native'de hiç gelmediği için hiçbir şey
// olmuyordu — ve HİÇBİR TEST bunu görmüyordu, çünkü hiçbir test uygulamayı
// bir DERİN BAĞLANTIYLA açmıyordu. Test yoksa "yazdım" demek yetmiyor.
// ============================================================
const { renderScreen, has, React } = require("./runner");
const path = require("path");
const { parseAuthParams, isAuthUrl } = require(path.join(require("./ll_paths").APP, "src/deeplink.js"));

let pass = 0, fail = 0;
function check(name, cond) {
  if (cond) { pass++; console.log("✓ " + name); }
  else { fail++; console.log("✗ " + name); }
}

// ---------- 1) AYRIŞTIRICI ----------
const frag = parseAuthParams(
  "loungelink://reset-password#access_token=AAA&refresh_token=BBB&type=recovery&expires_in=3600");
check("adres parçasından access_token okunuyor", frag.access_token === "AAA");
check("adres parçasından refresh_token okunuyor", frag.refresh_token === "BBB");
check("type=recovery okunuyor", frag.type === "recovery");

const q = parseAuthParams("loungelink://auth-callback?code=XYZ123");
check("sorgu dizesinden code okunuyor", q.code === "XYZ123");

const both = parseAuthParams("loungelink://reset-password?foo=1#token_hash=HHH&type=recovery");
check("? ve # birlikte gelince ikisi de okunuyor", both.foo === "1" && both.token_hash === "HHH");

const errp = parseAuthParams(
  "loungelink://reset-password#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid");
check("hata parametreleri okunuyor", errp.error_code === "otp_expired");
check("+ işareti boşluğa çevriliyor", errp.error_description.indexOf("Email link") === 0);

check("auth adresi tanınıyor", isAuthUrl("loungelink://reset-password#access_token=A&refresh_token=B"));
check("düz derin bağlantı auth sayılmıyor", !isAuthUrl("loungelink://profile/123"));
check("boş adres çökmüyor", !isAuthUrl(undefined) && Object.keys(parseAuthParams(null)).length === 0);

// ---------- 2) UÇTAN UCA: bağlantı → şifre belirleme ekranı ----------
(async () => {
  const App = require(path.join(require("./ll_paths").APP, "App.js")).default;

  // Oturum YOK (kullanıcı şifresini unuttu, çıkışta) ve uygulama
  // sıfırlama bağlantısıyla açılıyor.
  globalThis.__DATA = {
    session: null,
    tables: { airports: [{ code: "IST" }] },
    rpc: {},
  };
  globalThis.__INITIAL_URL =
    "loungelink://reset-password#access_token=AAA&refresh_token=BBB&type=recovery";

  const r = await renderScreen("App (sıfırlama bağlantısıyla açılış)", React.createElement(App));
  check("bağlantıyla açılışta uygulama çökmüyor", r.ok);
  check("ŞİFRE BELİRLEME EKRANI AÇILIYOR", r.ok && has(r.texts, "Yeni şifre belirle"));

  // Karşılaştırma: bağlantı YOKKEN o ekran ÇIKMAMALI (yanlış pozitif kontrolü)
  globalThis.__INITIAL_URL = null;
  const r2 = await renderScreen("App (normal açılış)", React.createElement(App));
  check("bağlantı yokken şifre ekranı ÇIKMIYOR", r2.ok && !has(r2.texts, "Yeni şifre belirle"));

  console.log(`\nToplam kontrol: ${pass + fail} · başarısız: ${fail}`);
  process.exit(fail ? 1 : 0);
})();
