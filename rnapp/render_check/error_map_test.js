#!/usr/bin/env node
/**
 * LoungeLink · render_check/error_map_test.js   (v2.38'de doğdu)
 *
 * 🔴 NEDEN VAR
 *
 * Bağlantı koptuğunda Supabase istemcisi "Network request failed" gibi
 * bir hata fırlatıyor. Biz bunu bilinmeyen hata sayıp kullanıcıya
 * "Bir hata oluştu" diyorduk.
 *
 * Fark kullanıcı açısından büyük: "bir hata oluştu" = uygulama bozuk,
 * tekrar denemenin anlamı yok. Doğru mesaj "internetin gitti, tekrar
 * dene" — kullanıcı NE YAPACAĞINI bilir.
 *
 * Bu dosya mapErr'i GERÇEK hata metinleriyle sınar. İlk yazdığımda
 * fonksiyonu izole çalıştırmıştım ve `logError` tanımsız diye patladı —
 * yani testin kendisi hatalıydı, kod değil. Şimdi bağımlılıklar da
 * sağlanıyor.
 */
const fs = require("fs");
const path = require("path");

const SRC = path.join(__dirname, "..", "src", "i18n.js");
const src = fs.readFileSync(SRC, "utf8");

const m = src.match(/export function mapErr\(t, msg\) \{[\s\S]*?\n\}/);
if (!m) {
  console.log("✗ mapErr bulunamadı — i18n.js değişmiş olabilir");
  process.exit(1);
}

// mapErr içinde kullanılan yardımcılar: izole çalıştırırken sağlanmalı.
const body = m[0]
  .replace("export function mapErr(t, msg) {", "")
  .replace(/\n\}$/, "");
const mapErr = new Function("t", "msg", "logError", body + "\nreturn undefined;");
const noop = () => {};

const t = {
  errGeneric: "Bir hata oluştu.",
  errOffline: "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.",
  errSession: "Oturumun sona ermiş. Tekrar giriş yapman gerekiyor.",
  errMap: {
    self_request_blocked: "Kendi ilanına başvuramazsın.",
    rate_limited_request: "Çok fazla istek gönderdin.",
  },
};

const cases = [
  // --- AĞ: kullanıcı tekrar deneyebilir, bunu SÖYLEMELİYİZ ---
  ["Network request failed", t.errOffline],
  ["TypeError: Failed to fetch", t.errOffline],
  ["FetchError: request to https://x.supabase.co timed out", t.errOffline],
  ["NetworkError when attempting to fetch resource.", t.errOffline],
  ["connect ETIMEDOUT 1.2.3.4:443", t.errOffline],
  ["getaddrinfo ENOTFOUND x.supabase.co", t.errOffline],

  // --- OTURUM: "çıkış mı yaptım?" şaşkınlığını önle ---
  ["JWT expired", t.errSession],
  ["Invalid Refresh Token: Already Used", t.errSession],

  // --- BİLİNEN İŞ KURALLARI: olduğu gibi çevrilmeli ---
  ["self_request_blocked", "Kendi ilanına başvuramazsın."],
  ["rate_limited_request", "Çok fazla istek gönderdin."],

  // --- BİLİNMEYEN: genel mesaj (ham Postgres metni kullanıcıya gitmemeli) ---
  ["ERROR: relation \"x\" does not exist", t.errGeneric],
  ["", t.errGeneric],
];

let ok = 0;
const bad = [];
for (const [input, expected] of cases) {
  let got;
  try {
    got = mapErr(t, input, noop);
  } catch (e) {
    got = "İSTİSNA: " + e.message;
  }
  if (got === expected) {
    ok++;
  } else {
    bad.push([input, expected, got]);
  }
}

console.log("=".repeat(66));
console.log("HATA ÇEVİRİSİ DENETİMİ — ağ hatası 'bir hata oluştu' demek değil");
console.log("=".repeat(66));

for (const [inp, exp, got] of bad) {
  console.log(`  ✗ ${JSON.stringify(inp).slice(0, 46)}`);
  console.log(`      beklenen: ${String(exp).slice(0, 52)}`);
  console.log(`      gelen   : ${String(got).slice(0, 52)}`);
}

console.log(`\nToplam kontrol: ${cases.length} · başarısız: ${bad.length}`);
process.exit(bad.length ? 1 : 0);
