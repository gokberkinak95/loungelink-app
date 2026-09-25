// @expo/vector-icons taklidi — başsız testler için.
// Gerekçe: mount_test.js içindeki uzun not. Özet: bu kütüphane bir FONT
// yükleyip glif çizer; Node'da font motoru yok. `src/ikon.js` (bizim kod)
// tam olarak koşuyor; glif adlarının geçerliliğini `ikon_check.py`
// Ionicons'un gerçek glyphmap'inde ayrıca doğruluyor.
const React = require("react");
const Ikon = ({ name, size, color }) =>
  React.createElement("Ionicons", { name, size, color }, null);
Ikon.displayName = "Ionicons";
module.exports = Ikon;
module.exports.default = Ikon;
module.exports.Ionicons = Ikon;
// 🔴 31 AĞUSTOS · 8. TUR — `createIconSet` TAKLİTTE YOKTU VE BÜTÜN
// KAPILAR AÇILIŞTA DÜŞTÜ.
// `src/ikon.js` artık ikinci bir aile kuruyor (kendi radar glifimiz,
// `assets/fonts/LLSimge.ttf`) ve bunun için `createIconSet`i çağırıyor.
// Taklitte olmayınca `TypeError: createIconSet is not a function` —
// yani `npm run render`ın SEKİZ kapısı da tek satırda kırıldı.
//
// İyi haber: bu kırılma GÜRÜLTÜLÜ oldu. Taklit "eksik olanı sessizce
// undefined döndüren" bir yapı olsaydı, ikon fabrikası `undefined`
// olur, testler geçer ve hata ancak CİHAZDA görülürdü.
//
// 🆕 SINIF: "BİR TAKLİT, TAKLİT ETTİĞİ KÜTÜPHANENİN YALNIZ BUGÜN
// KULLANILAN YÜZEYİNİ KAPSAR — ÜRÜNE YENİ BİR ÇAĞRI EKLERKEN TAKLİDİ
// DE BÜYÜT."
module.exports.createIconSet = (glyphMap, aile, font) => {
  const S = ({ name, size, color }) =>
    React.createElement(aile || "LLSimge", { name, size, color }, null);
  S.displayName = aile || "LLSimge";
  // Ürün `loadFont`u varsa çağırıyor; taklit onu sunar ve hemen çözer.
  S.loadFont = async () => true;
  S.glyphMap = glyphMap;
  S.font = font;
  return S;
};
module.exports.__esModule = true;
