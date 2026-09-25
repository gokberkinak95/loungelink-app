// ============================================================
// LoungeLink · render_check/yoga_kalibre.js
//
// ÖLÇÜM ALETİNİN KALİBRASYONU — cevabını ELLE hesaplayabildiğim
// düzenleri motora verir ve motorun aynı sayıyı bulmasını ister.
//
// 🔴 NEDEN VAR: `yoga_duzen.js`in ilk sürümünde bütün Yoga sabitleri
// `undefined` geliyordu (`FLEX_DIRECTION_ROW` yerine
// `FlexDirection.Row` olması gerekiyormuş). Motor hiç hata vermedi,
// her satırı sütun sandı ve YİNE DE makul görünen sayılar üretti.
// O sayılara bakıp "şu metin taşıyor" diye rapor yazdım.
//
// 🆕 SINIF: "BİR ÖLÇÜM ALETİ, CEVABINI ÖNCEDEN BİLDİĞİM BİR ŞEYLE
// KALİBRE EDİLMEDEN OKUNAMAZ — BOZUK BİR ALET DE SAYI VERİR, VE
// SAYININ MAKUL GÖRÜNMESİ DOĞRULUĞUNUN DELİLİ DEĞİLDİR."
//
// Bu dosya `verify.js` içinde `tasma_check.js`ten ÖNCE çalışır:
// aleti okumadan önce kalibre et.
// ============================================================
require("./runner");           // babel-register + RN taklitleri
const { olc, metinGenisligi } = require("./yoga_duzen");

const V = (style, children) => ({ type: "View", props: { style }, children });
const T = (style, s, props = {}) => ({ type: "Text", props: { style, ...props }, children: [s] });

const sonuc = [];
function bekle(ad, olculen, beklenen, tol = 0.75) {
  const ok = Math.abs(olculen - beklenen) <= tol;
  sonuc.push({ ad, ok, olculen: +olculen.toFixed(2), beklenen });
}

(async () => {
  // ── 1 · satır yönü + flex:1 eşit dağıtım ─────────────────
  // 390 − 22×2 (dış) − 14×2 (iç) − 1 (ayraç) = 315 → 3'e bölünür
  {
    const agac = V({ flex: 1, paddingHorizontal: 22 }, [
      V({ flexDirection: "row", paddingHorizontal: 14 }, [
        V({ flex: 1 }, [T({ fontSize: 9 }, "A")]),
        V({ width: 1 }),
        V({ flex: 1 }, [T({ fontSize: 9 }, "B")]),
        V({ flex: 1 }, [T({ fontSize: 9 }, "C")]),
      ]),
    ]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("satır · flex:1 üçe eşit böler", bulgular[0].genislik, (390 - 44 - 28 - 1) / 3);
  }

  // ── 2 · sütun varsayılanı (yön verilmezse alt alta) ──────
  {
    const agac = V({ width: 200 }, [
      V({}, [T({ fontSize: 10 }, "X")]),
      V({}, [T({ fontSize: 10 }, "Y")]),
    ]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("sütun · çocuk tam genişlik alır", bulgular[0].genislik, 200);
  }

  // ── 3 · padding metnin kutusundan düşülür ────────────────
  {
    const agac = V({ width: 200, padding: 25 }, [T({ fontSize: 10 }, "Z")]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("padding · 200 − 25×2 = 150", bulgular[0].genislik, 150);
  }

  // ── 4 · gap ──────────────────────────────────────────────
  {
    const agac = V({ width: 300, flexDirection: "row", gap: 20 }, [
      V({ flex: 1 }, [T({ fontSize: 10 }, "A")]),
      V({ flex: 1 }, [T({ fontSize: 10 }, "B")]),
    ]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("gap · (300 − 20) / 2 = 140", bulgular[0].genislik, 140);
  }

  // ── 5 · borderWidth de kutudan düşer ─────────────────────
  {
    const agac = V({ width: 100, borderWidth: 10 }, [T({ fontSize: 10 }, "Q")]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("border · 100 − 10×2 = 80", bulgular[0].genislik, 80);
  }

  // ── 6 · ScrollView contentContainerStyle padding'i sayılır ─
  {
    const agac = V({ width: 300 }, [
      { type: "ScrollView", props: { style: { flex: 1 }, contentContainerStyle: { padding: 40 } },
        children: [T({ fontSize: 10 }, "S")] },
    ]);
    const { bulgular } = await olc(agac, 390, 844);
    bekle("ScrollView · içerik kabı padding 40 → 220", bulgular[0].genislik, 220);
  }

  // ── 7 · textTransform ölçümden ÖNCE uygulanır ────────────
  {
    const kucuk = metinGenisligi("loungepuan", "PlusJakartaSans-SemiBold", 9, 1.3);
    const buyuk = metinGenisligi("LOUNGEPUAN", "PlusJakartaSans-SemiBold", 9, 1.3);
    const agac = V({ width: 400 }, [
      T({ fontSize: 9, fontWeight: "600", letterSpacing: 1.3, textTransform: "uppercase" }, "LoungePuan"),
    ]);
    const { bulgular } = await olc(agac, 400, 844);
    bekle("textTransform · BÜYÜK harf ölçülür", bulgular[0].gerekli, buyuk);
    sonuc.push({ ad: `  (küçük ${kucuk.toFixed(1)}pt · büyük ${buyuk.toFixed(1)}pt — ` +
                     `fark ${(buyuk - kucuk).toFixed(1)}pt)`, ok: true, bilgi: true });
  }

  // ── 8 · font ölçümü gerçek ttf'ten geliyor mu ────────────
  // JetBrains Mono SABİT GENİŞLİKTİR: 3 karakter = 3 × tek karakter.
  {
    const bir = metinGenisligi("0", "JetBrainsMono-SemiBold", 16, 0);
    const uc = metinGenisligi("000", "JetBrainsMono-SemiBold", 16, 0);
    bekle("mono · 3 karakter = 3 × 1 karakter", uc, bir * 3, 0.01);
  }

  // ── 9 · fontWeight → aile eşlemesi typography.js ile aynı ─
  {
    const { sansFor } = require("./yoga_duzen");
    const tip = require("../src/typography.js");
    let hepsi = true;
    for (const w of ["400", "500", "600", "700", "bold", "normal", undefined, 550]) {
      if (sansFor(w) !== tip.sansFor(w)) hepsi = false;
    }
    sonuc.push({ ad: "aile eşlemesi · typography.js ile birebir", ok: hepsi,
                 olculen: hepsi ? "aynı" : "AYRIŞTI", beklenen: "aynı" });
  }

  // ── rapor ────────────────────────────────────────────────
  console.log("── ÖLÇÜM ALETİ KALİBRASYONU ────────────────────────");
  let kirik = 0;
  for (const s of sonuc) {
    if (s.bilgi) { console.log("     " + s.ad); continue; }
    if (!s.ok) kirik++;
    console.log(`  ${s.ok ? "✓" : "✗"} ${s.ad}` +
                (s.ok ? "" : `  → ölçülen ${s.olculen}, beklenen ${s.beklenen}`));
  }
  if (kirik) {
    console.log(`\n✗ ${kirik} kalibrasyon başarısız — TAŞMA ÖLÇÜMÜ OKUNMAZ.`);
    process.exit(1);
  }
  console.log(`\n✓ ${sonuc.filter((s) => !s.bilgi).length} kalibrasyonun hepsi geçti — alet okunabilir.`);
})().catch((e) => { console.error("KALİBRASYON ÇÖKTÜ:", e); process.exit(1); });
