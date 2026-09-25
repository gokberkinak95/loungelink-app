// ============================================================
// zaman.js — CİHAZIN DUVAR TAKVİMİ (25 Eylül · v5.14.1)
//
// 🔴 NEDEN VAR: istemci "bugün"ü `new Date().toISOString().slice(0, 10)`
// ile hesaplıyordu. `toISOString` UTC'dir: İstanbul'da (UTC+3) 00:00–03:00
// arasında "bugün" DÜN çıkıyordu — Keşfet dünün ilanlarını "bugün"
// diye listeliyor, yeni seyahat dünün tarihiyle açılıyordu. Aynı hata
// `new Date(y, m, 1).toISOString()` ile ay başını bir önceki ayın son
// gününe kaydırıyordu.
//
// SQL tarafı bu sınıfı 292'de `yerel_gun` ile kapattı; istemci aynı
// dersi almamıştı. `zaman_dilimi_check.py` yalnız SQL'e bakıyor.
//
// 🆕 SINIF: "BİR TARİH DİZESİ ÜRETEN HER SATIR, HANGİ TAKVİMİN GÜNÜNÜ
// SÖYLEDİĞİNİ DE SÖYLEMELİDİR — ISO DİZESİ YEREL GÜN DEĞİLDİR."
// ============================================================

const iki = (n) => (n < 10 ? "0" : "") + n;

// Yerel takvime göre "YYYY-MM-DD" (visit_date / avail_date ile aynı biçim).
export function yerelGun(d = new Date()) {
  return `${d.getFullYear()}-${iki(d.getMonth() + 1)}-${iki(d.getDate())}`;
}
