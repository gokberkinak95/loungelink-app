// ══════════════════════════════════════════════════════════════════════
// src/bcbp.js — IATA BİNİŞ KARTI BARKODU (Res. 792) AYRIŞTIRICISI
//
// 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (v5.9.0 biniş kartı briefi)
// "Çözülen barkod metninin yalnızca ilk 3 karakterini (Kalkış
//  Havalimanı: IST, AYT vb.) kırpacak ve ilandaki kalkış yeriyle
//  eşleştirecek."
//
// ⚠️ NİYET DOĞRU, OFSET YANLIŞTI — VE ÖLÇTÜM:
// BCBP zorunlu bloğu SABİT KONUMLU ve kalkış havalimanı 31. karakterde
// başlıyor. Gerçek bir dize:
//
//   M1INAK/GOKBERK        EABC123 ISTAYTTK 1979 256Y012A0042 100
//   ^^                    ^       ^  ^  ^   ^    ^  ^^   ^    ^
//   ||                    |       |  |  |   |    |  ||   |    +- alan boyu
//   ||                    |       |  |  |   |    |  ||   +------ check-in sirasi
//   ||                    |       |  |  |   |    |  |+---------- koltuk
//   ||                    |       |  |  |   |    |  +----------- kabin kodu
//   ||                    |       |  |  |   |    +-------------- ucus tarihi (Julian)
//   ||                    |       |  |  |   +------------------- ucus no
//   ||                    |       |  |  +----------------------- tasiyici
//   ||                    |       |  +-------------------------- VARIS
//   ||                    |       +----------------------------- KALKIS  (31-33)
//   ||                    +------------------------------------- PNR (24-30)
//   |+---------------------------------------------------------- bacak sayisi
//   +----------------------------------------------------------- format kodu (M)
//
// İlk 3 karakter `M1I` — format kodu + bacak sayısı + soyadın ilk harfi.
// `M1I` ≠ `IST` → brief olduğu gibi uygulansaydı doğrulama %100
// başarısız olurdu; yani "sahte rota uyuşmazlığını engelle" niyeti tam
// tersini üretirdi.
//
// 🆕 SINIF: "SABİT KONUMLU BİR FORMATI 'BAŞTAN N KARAKTER' DİYE OKUMAK
// AYRIŞTIRMA DEĞİL TAHMİNDİR — KONUM SPESİFİKASYONDAN GELİR, GÖZDEN
// DEĞİL."
//
// ⚠️ AĞ YOK. Bu dosya hiçbir şey indirmez, hiçbir şey göndermez.
// Ayrıştırma tamamen cihazda, saf JS ile yapılır.
// ══════════════════════════════════════════════════════════════════════

// ── Sabit konumlar (0 tabanlı dilim sınırları) ────────────────────────
// Spesifikasyondaki 1 tabanlı konumların karşılığı; tek yerde tanımlı.
export const ALAN = {
  formatKodu:    [0, 1],     // 1
  bacakSayisi:   [1, 2],     // 2
  yolcuAdi:      [2, 22],    // 3-22
  eBilet:        [22, 23],   // 23
  pnr:           [23, 30],   // 24-30
  kalkis:        [30, 33],   // 31-33  ← briefteki "ilk 3 karakter" BURASI
  varis:         [33, 36],   // 34-36  ← okunur, KULLANILMAZ, saklanmaz
  tasiyici:      [36, 39],   // 37-39
  ucusNo:        [39, 44],   // 40-44
  ucusGunu:      [44, 47],   // 45-47  (Julian — YIL YOK)
  kabinKodu:     [47, 48],   // 48
  koltuk:        [48, 52],   // 49-52
  checkinSira:   [52, 57],   // 53-57
  yolcuDurumu:   [57, 58],   // 58
  degiskenBoy:   [58, 60],   // 59-60 (hex)
};

const ZORUNLU_BOY = 60;

// ── Türkçe katlama ────────────────────────────────────────────────────
// 🔴 BCBP ADI ASCII: "GÖKBERK İNAK" barkodda `INAK/GOKBERK`.
// Türkçe büyütme kuralı (i→İ) uygulanırsa "GÖKBERK" ile "GOKBERK"
// ASLA eşleşmez. Bu tam olarak `tr_baslik` hatasının sınıfı:
// 🆕 "BİR ARAMA-DEĞİŞTİRMEDE ARANAN DİZGİ KAYNAĞIN KURALLARIYLA,
// YAZILAN DİZGİ HEDEFİN KURALLARIYLA ÜRETİLİR."
// Barkod ASCII olduğu için KIYAS DA ASCII kurallarıyla yapılır.
const KATLA = { ç: "c", Ç: "c", ğ: "g", Ğ: "g", ı: "i", I: "i", İ: "i", i: "i",
                ö: "o", Ö: "o", ş: "s", Ş: "s", ü: "u", Ü: "u", â: "a", Â: "a",
                î: "i", Î: "i", û: "u", Û: "u" };

export function asciiKatla(s) {
  let out = "";
  for (const ch of String(s || "")) out += (KATLA[ch] !== undefined ? KATLA[ch] : ch);
  // ASCII kuralıyla büyüt — Türkçe kuralıyla DEĞİL
  return out.toUpperCase().replace(/[^A-Z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
}

// ── Julian gün → tarih (YIL ÇIKARIMI) ─────────────────────────────────
// 🔴 BARKODDA YIL YOK. Uçuş tarihi alanı 3 hane, yalnız yılın kaçıncı
// günü. IATA'nın kendi kılavuzu yıl hanesini yalnız "biniş kartı basım
// tarihi" (koşullu, 4 hane) alanında taşıyor.
// Naif çıkarım ("bu yıl") yılbaşında 365 gün yanılır:
//   31 Aralık'ta basılmış 1 Ocak uçuşu (001) → bu yıl 1 Ocak (YANLIŞ)
// Doğrusu: ÜÇ ADAY (geçen/bu/gelecek yıl) arasından BUGÜNE EN YAKIN
// olanı seçmek. Artık yıl 366 da böyle kendiliğinden çözülür.
export function julianTarih(gun, bugun) {
  const g = parseInt(gun, 10);
  if (!Number.isFinite(g) || g < 1 || g > 366) return null;
  const ref = bugun instanceof Date ? bugun : new Date();
  const y0 = ref.getFullYear();
  let enIyi = null, enYakin = Infinity;
  for (const y of [y0 - 1, y0, y0 + 1]) {
    // Ocak 1 + (g-1) gün — artık yılda 366 geçerli, değilse taşar ve elenir
    const d = new Date(y, 0, g);
    if (d.getFullYear() !== y) continue;          // 366 · artık olmayan yıl
    const fark = Math.abs(d.getTime() - ref.getTime());
    if (fark < enYakin) { enYakin = fark; enIyi = d; }
  }
  return enIyi;
}

export function ymd(d) {
  if (!d) return null;
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// ── Ayrıştırıcı ───────────────────────────────────────────────────────
// Dönen nesne ya `{ ok: true, ... }` ya `{ ok: false, kod }`.
// ⚠️ SESSİZ YANLIŞ DÖNMEZ: emin olamadığı her durumda AÇIKÇA reddeder.
// Yarı doğru bir ayrıştırma, hiç ayrıştırmamaktan tehlikelidir — çünkü
// ürün ona güvenip kullanıcıyı yanlış yönlendirir.
export function bcbpCoz(ham, bugun) {
  const s = String(ham || "");
  if (s.length < ZORUNLU_BOY) return { ok: false, kod: "bcbp_kisa" };
  const al = ([a, b]) => s.slice(a, b);

  const fmt = al(ALAN.formatKodu);
  if (fmt !== "M" && fmt !== "E") return { ok: false, kod: "bcbp_degil" };

  const bacak = parseInt(al(ALAN.bacakSayisi), 10);
  if (!Number.isFinite(bacak) || bacak < 1 || bacak > 4) return { ok: false, kod: "bcbp_degil" };

  const kalkis = al(ALAN.kalkis).trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(kalkis)) return { ok: false, kod: "bcbp_havalimani_okunmadi" };

  const varis = al(ALAN.varis).trim().toUpperCase();   // OKUNUR, KULLANILMAZ

  const tarih = julianTarih(al(ALAN.ucusGunu), bugun);
  if (!tarih) return { ok: false, kod: "bcbp_tarih_okunmadi" };

  const tasiyici = al(ALAN.tasiyici).trim().toUpperCase();
  const ucusNo = al(ALAN.ucusNo).trim().replace(/^0+/, "");
  const kabin = al(ALAN.kabinKodu).trim().toUpperCase();
  const adHam = al(ALAN.yolcuAdi).trim();
  const [soyad, ad] = adHam.split("/");

  return {
    ok: true,
    kalkis,
    ucusTarihi: ymd(tarih),
    tasiyici: tasiyici || null,
    ucusNo: ucusNo || null,
    ucusKodu: tasiyici && ucusNo ? tasiyici + ucusNo : null,
    kabinKodu: kabin || null,
    soyad: asciiKatla(soyad || ""),
    ad: asciiKatla(ad || ""),
    // 🔴 PNR SUNUCUYA GİTMEZ. Burada yalnız ÇİFTE KULLANIM karması için
    // duruyor; `pnr` alanı bilerek DÖNDÜRÜLMÜYOR (bkz. analiz §7:
    // PNR + soyadı ikilisi birçok havayolunda rezervasyon değiştirme
    // anahtarıdır — ham dizeyi saklamak, görseli yüklemekten kötüdür).
    _pnrKarmaGirdisi: (al(ALAN.pnr).trim() + "|" + asciiKatla(soyad || "") + "|" + ymd(tarih)),
    // varış bilerek dışarı verilmiyor; iş kuralımız varış istemiyor.
    _varisAtildi: varis || null,
  };
}

// ── Ham metinden BCBP dizesini bul ────────────────────────────────────
// PDF metin katmanında ya da QR/Aztec yükünde BCBP dizesi başka metnin
// arasında olabilir. Kalıp: M/E + bacak + 58 karakter daha.
export function bcbpBul(metin) {
  const s = String(metin || "");
  const kalip = /[ME]\d[A-Z0-9 \/.\-]{58,}/g;
  let m;
  while ((m = kalip.exec(s)) !== null) {
    const aday = bcbpCoz(m[0]);
    if (aday.ok) return m[0];
  }
  return null;
}

// ── KURAL MOTORU: ne SERT, ne YUMUŞAK eşleşir ─────────────────────────
// SERT  → eşleşmezse doğrulama GEÇMEZ (kalkış · tarih)
// YUMUŞAK → uyarır, engellemez (uçuş no · ad)
// BİLGİ  → yalnız gösterir, karar vermez (kabin)
export function kuralUyum(coz, ilan, bugun) {
  if (!coz || !coz.ok) return { gecti: false, kod: coz ? coz.kod : "bcbp_degil" };
  const sonuc = { gecti: true, sert: [], yumusak: [], bilgi: [] };

  // SERT 1 — KALKIŞ HAVALİMANI (briefteki "rota kırpma", doğru ofsetle)
  const ilanKalkis = String(ilan && ilan.airport_code || "").trim().toUpperCase();
  if (ilanKalkis && coz.kalkis !== ilanKalkis) {
    sonuc.gecti = false;
    sonuc.sert.push({ kod: "havalimani_uyusmuyor", bilet: coz.kalkis, ilan: ilanKalkis });
  }

  // SERT 2 — UÇUŞ TARİHİ
  const ilanTarih = String(ilan && ilan.avail_date || "").slice(0, 10);
  if (ilanTarih && coz.ucusTarihi !== ilanTarih) {
    sonuc.gecti = false;
    sonuc.sert.push({ kod: "tarih_uyusmuyor", bilet: coz.ucusTarihi, ilan: ilanTarih });
  }

  // YUMUŞAK 1 — UÇUŞ NUMARASI
  // ⚠️ ASLA SERT OLAMAZ: kod paylaşımlı uçuşta bilette yazan havayolu ile
  // uçağı uçuran farklıdır (bkz. src/FlightField.js:21).
  const ilanUcus = String(ilan && ilan.flight_number || "").replace(/\s+/g, "").toUpperCase();
  if (ilanUcus && coz.ucusKodu && ilanUcus !== coz.ucusKodu) {
    sonuc.yumusak.push({ kod: "ucus_farkli", bilet: coz.ucusKodu, ilan: ilanUcus });
  }

  // YUMUŞAK 2 — YOLCU ADI (ASCII katlamalı; bkz. asciiKatla)
  const profilAd = asciiKatla(ilan && ilan.guest_name || "");
  if (profilAd && (coz.soyad || coz.ad)) {
    const biletAd = (coz.soyad + " " + coz.ad).trim();
    const parcali = profilAd.split(" ").filter(Boolean);
    const tutan = parcali.filter((p) => p.length > 2 && biletAd.includes(p)).length;
    if (tutan === 0) sonuc.yumusak.push({ kod: "ad_uyusmuyor", bilet: biletAd, profil: profilAd });
  }

  // BİLGİ — KABİN KODU. Harf→sınıf eşlemesi HAVAYOLUNA GÖRE DEĞİŞİR;
  // bu yüzden karar vermez, yalnız gösterir. (F/J/C/D genelde ön kabin.)
  if (coz.kabinKodu) {
    sonuc.bilgi.push({ kod: "kabin", deger: coz.kabinKodu,
                       onKabin: "FJCDIZ".includes(coz.kabinKodu) });
  }
  return sonuc;
}
