#!/usr/bin/env node
/**
 * LoungeLink · render_check/dil_varsayilan_test.js   (20 Kasım 2026 · 1.0.2)
 *
 * NEDEN VAR: Google Play testçi raporu md.2 — uygulama telefon dili ne olursa olsun Türkçe açılıyordu.
 * 1.0.2: dil seçilmediyse YENİ kurulumda telefonun dili (tr → tr, diğer → en). AMA 1.0.2'den önce
 * uygulamayı kullanmış biri (tanıtımı geçmiş / oturum açmış) Türkçe görüyordu; güncellemeyle birden
 * İngilizceye dönmemeli. Bu test getLang + cihazDili'ni kaynaktan çıkarıp bellek içi depoyla koşturur.
 */
const fs = require("fs");
const path = require("path");
const src = fs.readFileSync(path.join(__dirname, "..", "src", "i18n.js"), "utf8");

const cihaz = src.match(/export function cihazDili\(\) \{[\s\S]*?\n\}/);
const gl = src.match(/export async function getLang\(\) \{[\s\S]*?\n\}/);
let ok = 0, bad = 0;
const chk = (ad, kosul, ek) => { if (kosul) { ok++; console.log("  ✓ " + ad); } else { bad++; console.log("  ✗ " + ad + (ek !== undefined ? "  → " + JSON.stringify(ek) : "")); } };
chk("cihazDili ve getLang kaynakta bulundu", !!cihaz && !!gl);
if (!cihaz || !gl) { console.log(`\nSON: ${ok} gecti · ${bad} dustu`); process.exit(1); }

function kur(depo, locale, depoPatlar) {
  const mem = { ...depo };
  const AsyncStorage = {
    getItem: async (k) => { if (depoPatlar) throw new Error("x"); return k in mem ? mem[k] : null; },
    setItem: async (k, v) => { mem[k] = v; },
    getAllKeys: async () => Object.keys(mem),
  };
  const Intl = { DateTimeFormat: () => ({ resolvedOptions: () => ({ locale }) }) };
  const govde = (cihaz[0] + "\n" + gl[0]).replace(/export /g, "");
  const f = new Function("AsyncStorage", "Intl", govde + "\nreturn { cihazDili, getLang };");
  return { ...f(AsyncStorage, Intl), mem };
}

(async () => {
  const OTURUM = "sb-wgprynisnriyblccxuhq-auth-token";
  const S = [
    ["yeni kurulum · telefon İngilizce → en", {}, "en-US", "en"],
    ["yeni kurulum · telefon Türkçe → tr", {}, "tr-TR", "tr"],
    ["yeni kurulum · telefon Almanca → en", {}, "de-DE", "en"],
    ["yeni kurulum · dil okunamıyor → tr", {}, "", "tr"],
    ["seçilmiş dil (en) korunur · telefon Türkçe", { ll_lang: "en" }, "tr-TR", "en"],
    ["seçilmiş dil (tr) korunur · telefon İngilizce", { ll_lang: "tr" }, "en-US", "tr"],
    ["ESKİ kullanıcı (tanıtımı geçmiş) · telefon İngilizce → tr kalır", { ll_onb: "1" }, "en-GB", "tr"],
    ["ESKİ kullanıcı (oturumu var) · telefon İngilizce → tr kalır", { [OTURUM]: "{}" }, "en-US", "tr"],
  ];
  for (const [ad, depo, loc, bek] of S) {
    const k = kur(depo, loc);
    const d = await k.getLang();
    chk(ad, d === bek, { d, bek });
  }
  const k = kur({ ll_onb: "1" }, "en-US");
  await k.getLang();
  chk("eski kullanıcıya 'tr' bir kez kaydedilir (sonraki açılış da tr)", k.mem.ll_lang === "tr", k.mem);
  const k2 = kur({}, "en-US");
  await k2.getLang();
  chk("yeni kurulumda telefon dili KAYDEDİLMEZ (kullanıcı seçene kadar telefonu izler)", !("ll_lang" in k2.mem), k2.mem);
  const k3 = kur({}, "en-US", true);
  chk("depo okunamazsa eski davranış: tr", (await k3.getLang()) === "tr");
  console.log(`\nSON: ${ok} gecti · ${bad} dustu`);
  process.exit(bad ? 1 : 0);
})();
