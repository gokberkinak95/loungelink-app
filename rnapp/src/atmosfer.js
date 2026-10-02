import React, { useEffect, useRef, useState } from "react";
import { View, Image, Dimensions, Animated, Easing } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { C , temaModu } from "./theme";
import { Katman } from "./katman";
import { useAzHareket } from "./hareket";

// ============================================================================
// ATMOSFER KATMANI  (26 Ağustos 2026 · v3.1)
//
// 🔴 NEDEN VAR
// Gökberk: "her sayfada bir background olsun — kullanıcıyı rahatsız etmeyecek,
// kullanılabilirliği etkilemeyecek, temamıza uygun."
//
// Doğru istek. Ama ÖLÇTÜM ve doğrudan uygulaması okunmuyordu: referans
// görselleri zemin yapıp üstüne app'in metin renklerini koyduğumda gövde
// metni piksellerin %0–16'sında WCAG AA geçiyordu. Beyaz metin bile
// %86–93'te kalıyor ve EN KÖTÜ NOKTASI 1.30:1 — yani pencerenin parlayan
// kenarından geçen bir satır tamamen kayboluyor.
//
// Ortalama kontrast diye bir ölçü yoktur. Bir metnin okunabilirliğini
// en kötü noktası belirler.
//
// 🆕 SINIF: "BİR ZEMİNİN ORTALAMA KONTRASTI İYİ OLABİLİR VE O ZEMİNDEKİ
// METİN YİNE DE OKUNMAZ — ÇÜNKÜ KULLANICI ORTALAMAYA BAKMAZ, EN KÖTÜ
// NOKTADAN GEÇEN SATIRA BAKAR."
//
// ÇÖZÜM: atmosferi kaldırmak değil, YERİNİ DEĞİŞTİRMEK. İki katman var ve
// ikisi de metnin ALTINDA değil ARKASINDA duruyor.
//
//   ┌─ tur="an"  ─ Splash, tanıtım, buluşma anı, kutlama (5 ekran)
//   │              Tam ekran görsel + ÖLÇÜLMÜŞ perde. Metin iri, beyaz,
//   │              az. Perde `hazirla_atmosfer.py` tarafından görselin
//   │              İÇİNE pişiriliyor — çalışma anında gradyan yok.
//   │
//   └─ tur="is"  ─ Keşif, kural kartları, cüzdan, sohbet, form (25 ekran)
//                  Fotoğraf YOK. Ufuk + bulut + irtifa çizgisi, %9
//                  yoğunlukta, düz View'lardan çiziliyor → 0 KB.
//                  Kartlar opak (C.surface) olduğu için metin dokuya
//                  HİÇ değmiyor: kontrast oranları değişmiyor.
//
// ⚠️ BAĞIMLILIK EKLEMEDİM. `expo-linear-gradient` kurulu değil ve bu iş
// için kurmaya değmez: "an" katmanının perdesi zaten görselin içinde,
// "iş" katmanı ise %9'da — 12 bantlık bir yığın orada gradyandan ayırt
// edilemez. Yeni bir yerel bağımlılık, yeni bir build kırılma noktasıdır.
// ============================================================================

const { width: EKRAN_W } = Dimensions.get("window");

// Kullanıcı "Sade görünüm"ü açtıysa hiç çizme.
const ANAHTAR = "ll_sade_gorunum";
let SADE = false;
const dinleyiciler = new Set();

export async function sadeGorunumYukle() {
  try { SADE = (await AsyncStorage.getItem(ANAHTAR)) === "1"; } catch (e) { SADE = false; }
  dinleyiciler.forEach(f => { try { f(); } catch (e) {} });
  return SADE;
}
export async function sadeGorunumYaz(deger) {
  SADE = !!deger;
  try { await AsyncStorage.setItem(ANAHTAR, SADE ? "1" : "0"); } catch (e) {}
  dinleyiciler.forEach(f => { try { f(); } catch (e) {} });
}
export function sadeGorunumMu() { return SADE; }
export function sadeDinle(fn) { dinleyiciler.add(fn); return () => dinleyiciler.delete(fn); }

// ---------------------------------------------------------------------------
// İŞ EKRANI DOKUSU
//
// Üç öge, hepsi paletten:
//   · ufuk bandı   — ekranı yatay olarak ikiye bölen sıcak bir kuşak
//   · iki bulut    — yumuşak, düşük opaklıkta beyaz kütleler
//   · irtifa grid'i— 30px'te bir çok soluk yatay çizgi
//
// Ufuk yüksekliği ekranın KONUSUNU izler: keşifte alçak (yerdesin),
// uçuş/buluşma bağlamında yüksek. Süs değil, sessiz bir durum bildirimi.
// ---------------------------------------------------------------------------

// 🔴 YOĞUNLUK TEK YERDE. Ekranlar kendi opaklığını seçemez; seçebilseydi
// "tek ekran için uydurulan değer" sınıfına 25 yeni kapı açardık.
export const DOKU_YOGUNLUK = 0.09;   // Gökberk'in seçimi (26 Ağu) — açık tema

// 🔴 RENKLER ARTIK PALETTEN. Önceki hâlde "#E39B6B" ve C.surface bu dosyaya
// GÖMÜLÜYDÜ ve koyu temada gövde metnini 12.74 → 4.37'ye düşürüyordu
// (ÖLÇÜM: doku_check.py). Bir bileşen renk seçtiği an temayı çatallar.
// Koyu tema mı? `C.bg` tema değiştiğinde yeniden kurulduğu için tek
// güvenilir ölçüt zeminin parlaklığı — tema modunu ikinci bir yerde
// tekrar tanımlamıyoruz.
function koyuMu() {
  const h = String((C && C.bg) || "#FFFFFF").replace("#", "");
  if (h.length < 6) return false;
  const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 128;
}

// ═══════════════════════════════════════════════════════════════════════
// 🔴 v3.4 — ÜÇ ÇİZİM BİLEŞENİ KALDIRILDI (Ufuk · Bulut · IrtifaGrid)
//
// Gökberk (28 Ağu): "iç sayfalarda arka plandaki tırtıklı görünüm sanki
// ekranda bir sorun var havası yaratıyor."
//
// Kusuru doğru gördü ve sebebi RENK DEĞİLDİ. Bu üç bileşen ekran başına
// 42 `View` çiziyordu ve 39'unun KENARI KESKİNDİ:
//   · IrtifaGrid → 30 dp aralıkla 25 adet 1 dp çizgi
//   · Ufuk       → 14 basamaklı bant merdiveni (gradyan sanılıyordu)
//   · Bulut ×3
//
// 1 dp, Gökberk'in cihazında ~2.75 fiziksel piksel. Kesirli olduğu için
// çizgiler dönüşümlü olarak 3 px ve 2 px çiziliyor; eşit aralıklı olduğu
// için de ekranın piksel ızgarasıyla MOİRE üretiyorlar. Gördüğü titreşim
// buydu — bir renk kusuru değil, bir rasterleştirme kusuru.
//
// 🆕 SINIF: "SERT KENARLI VE EŞİT ARALIKLI HER DESEN PİKSEL IZGARASIYLA
// GİRİŞİM YAPAR — DOKU İSTİYORSAN KENARI OLMAYAN BİR ŞEY ÇİZ."
//
// Yerine: `zemin_uret.py` ile PALETTEN üretilmiş, dither'lanmış, ufuk
// parıltılı tek bir PNG (234 bayt). `resizeMode="stretch"` ile geriliyor;
// ara pikselleri GPU karıştırdığı için hiçbir ölçekte basamak oluşmuyor.
//
// PERFORMANS (bu ekranın kendi kazancı, ölçülebilir):
//   ekran başına 42 native View → 1 Image.
//   Bu bileşen HER `Sayfa`'nın ilk çocuğu; yani kazanç her ekranda.
//
// ⚠️ KONTRAST YENİDEN ÖLÇÜLDÜ, TAHMİN EDİLMEDİ. `zemin_uret.py` gradyanın
// HER SATIRINDA dört mürekkebi ölçüyor ve en kötüsü AA'yı geçmezse dosyayı
// hiç yazmıyor. Ölçüm (açık tema): ink 14.23 · body 8.88 · mutedAA 5.29 ·
// dimAA 4.80. Eski dokuda mutedAA 5.02 idi — yani yeni zemin biraz DAHA
// okunur.
// ═══════════════════════════════════════════════════════════════════════
const ZEMIN_ACIK = require("../assets/zemin-acik.png");
// 4 Eylül — TASARIM BİREBİR: koyu zemin DÜZ `bg`; yalnız `Ekran.doku`nun ufuk
// kuşağı (boyun %20'si, sıcak %7 üçgen). brand/build_doku.py üretir.
// ═══════════════════════════════════════════════════════════════════════
// AMBİYANS — GÜNÜN SAATİNE GÖRE UFUK  (12 Eylül · gece)
//
// 🔴 NEDEN PALET DEĞİL DE BU KATMAN
// Gökberk'in vizyon maddesi "günün saatine göre ortam teması". İlk akla
// gelen paleti kaydırmaktı; yapmadım ve sebebi tahmin değil: palet 87
// jeton ve ~40 ölçülmüş kontrast oranı demek. Saate bağlanan bir palet,
// günün yarısında ÖLÇÜLMEMİŞ bir ürün demektir.
//
// Değişen tek şey ufuk kuşağının tonu ve şiddeti. Dört kuşağın dördü de
// `doku_check.py` tarafından SATIR SATIR ölçülüyor; en kötü nokta şafak
// kuşağının 122. satırında `dimAA` ile 4.78 (AA eşiği 4.50).
//
// ⚠️ RENDER BELİRLENİMİ. Saate bağlı bir zemin, ekran görüntüsü
// karşılaştıran 89 kapıyı belirsiz kılardı: aynı testi 03:00'te ve
// 14:00'te koşmak iki farklı sonuç verirdi. `globalThis.__LL_AMBIYANS`
// kuşağı sabitler; sahne ve mount testleri onu "aksam"a çiviliyor.
// 🆕 SINIF: "ÜRÜNE ZAMAN SOKTUĞUN AN TESTLERİNE DE BİR SAAT SOKMUŞ
// OLURSUN — ZAMANI DIŞARIDAN SABİTLENEBİLİR YAPMAZSAN, YEŞİL IŞIĞIN
// ANLAMI GÜNÜN SAATİNE BAĞLI HÂLE GELİR."
// ═══════════════════════════════════════════════════════════════════════
const DOKU = {
  safak:  require("../assets/zemin-doku-safak.png"),
  gunduz: require("../assets/zemin-doku-gunduz.png"),
  aksam:  require("../assets/zemin-doku-koyu.png"),
  gece:   require("../assets/zemin-doku-gece.png"),
};

// Sınırlar havalimanının günü: şafak ilk dalga, gündüz düz, akşam altın
// saat, gece apron. Yerel saat — yolcunun bulunduğu saat, uçuşunki değil.
export function ambiyansKusagi(saat) {
  const s = saat == null
    ? (globalThis.__LL_AMBIYANS || (new Date()).getHours())
    : saat;
  if (typeof s === "string") return DOKU[s] ? s : "aksam";
  if (s >= 5 && s < 9) return "safak";
  if (s >= 9 && s < 17) return "gunduz";
  if (s >= 17 && s < 22) return "aksam";
  return "gece";
}
const DOKU_KOYU = DOKU.aksam;

// ---------------------------------------------------------------------------
// ANA BİLEŞEN
//
// Kullanımı: ekranın en dış View'ının İLK çocuğu olarak konur.
//   <View style={{ flex: 1 }}>
//     <Atmosfer tur="is" ufuk={54} />
//     ... ekran içeriği ...
//   </View>
// ---------------------------------------------------------------------------
// ======================================================================
// v6.2 (K9 · Gökberk onayı: "yalnız arka plandaki hareketi getir, başka
// bir şeyi değiştirme") — CANLI ZEMİN.
// İki yumuşak ışık bulutu (altın + `C.purple` — an ekranının ikinci halesiyle AYNI ton; palete yeni renk girmedi) gövde bölgesinde çok yavaş
// kayıyor. Başlık bandı, kartlar, renkler ve yerleşim AYNEN; bu katman
// yalnız zeminin arkasında ve dokunuş almıyor. Bulutlar ekranın alt %60'ında
// duruyor: foto bantların ÜSTÜNE çıkmıyor. Varlık titreşimli (dither)
// üretildi — gren_check'in bant kuralını bozmaz.
// "Hareketi azalt" → bulutlar DURAĞAN; sade mod → hiç yok (üstte döner).
// ======================================================================
// 🔴 28 EYLÜL (Gökberk: "K9'daki ışık hareketini göremiyorum") — KOD
// OKUNDU: katman çiziliyordu ama (1) ekranın alt %60'ı ana sayfada
// neredeyse tamamen kartlarla kaplı, bulutlar yalnız aralardan
// görünüyordu; (2) opaklık %9/%12 koyu zeminde ayırt edilmiyordu;
// (3) onaylı K9'un "arada toz zerreleri yükseliyor" parçası HİÇ
// YAZILMAMIŞTI. Gökberk'in onayıyla: alan bandın altından (%22) başlar,
// opaklık %16/%20, altı toz zerresi eklendi. Bant ve kartlar AYNEN.
const ZERRE = [
  { x: 0.12, gec: 0,     boy: 3, ton: "gold" },
  { x: 0.31, gec: 4200,  boy: 2, ton: "ink"  },
  { x: 0.52, gec: 8100,  boy: 3, ton: "gold" },
  { x: 0.68, gec: 1900,  boy: 2, ton: "ink"  },
  { x: 0.83, gec: 6300,  boy: 3, ton: "gold" },
  { x: 0.44, gec: 10200, boy: 2, ton: "ink"  },
];
function TozZerresi({ x, gec, boy, ton, G, Y }) {
  const az = useAzHareket();
  const p = useRef(new Animated.Value(az ? 0.5 : 0)).current;
  useEffect(() => {
    if (az) { p.setValue(0.5); return undefined; }
    const d = Animated.sequence([
      Animated.delay(gec),
      Animated.loop(Animated.timing(p, { toValue: 1, duration: 12000, easing: Easing.linear, useNativeDriver: true })),
    ]);
    d.start();
    return () => d.stop();
  }, [az]);
  return (
    <Animated.View style={{
      position: "absolute", left: G * x, bottom: 0, width: boy, height: boy, borderRadius: boy,
      // v7: zerreler şampanya (yapısal ton) — bronz metin rengi ışık gibi görünmüyordu.
      backgroundColor: ton === "gold" ? (temaModu() === "v7" ? C.goldBtn : C.gold) : C.ink,
      opacity: az ? 0.35 : p.interpolate({ inputRange: [0, 0.2, 0.75, 1], outputRange: [0, 0.7, 0.45, 0] }),
      transform: [{ translateY: p.interpolate({ inputRange: [0, 1], outputRange: [0, -Y * 0.85] }) }],
    }} />
  );
}

const ISIK_BULUTU = require("../assets/isik_bulutu.png");
function IsikBulutlari() {
  const az = useAzHareket();
  const v = useRef(new Animated.Value(0)).current;
  const w = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (az) return undefined;
    const a = Animated.loop(Animated.sequence([
      Animated.timing(v, { toValue: 1, duration: 18000, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
      Animated.timing(v, { toValue: 0, duration: 18000, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
    ]));
    const b = Animated.loop(Animated.sequence([
      Animated.timing(w, { toValue: 1, duration: 24000, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
      Animated.timing(w, { toValue: 0, duration: 24000, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
    ]));
    a.start(); b.start();
    return () => { a.stop(); b.stop(); };
  }, [az]);
  const { width: G, height: H } = Dimensions.get("window");
  const Y = H * 0.78; // katmanın yüksekliği (%22 → alt)
  return (
    <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0, top: "22%", bottom: 0, overflow: "hidden" }}>
      {/* v7: bulutlar ŞAFAK — şampanya + gökyüzü sisi; altın+mor fildişini beje boyuyordu. */}
      <Animated.Image source={ISIK_BULUTU} resizeMode="stretch" tintColor={temaModu() === "v7" ? C.goldBtn : C.gold}
        style={{ position: "absolute", width: G * 1.3, height: G * 1.3, right: -G * 0.45, top: -G * 0.1,
                 opacity: temaModu() === "v7" ? 0.07 : 0.16,
                 transform: [{ translateX: v.interpolate({ inputRange: [0, 1], outputRange: [0, -G * 0.18] }) },
                             { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [0, G * 0.12] }) }] }} />
      <Animated.Image source={ISIK_BULUTU} resizeMode="stretch" tintColor={temaModu() === "v7" ? C.gokMavi : C.purple}
        style={{ position: "absolute", width: G * 1.4, height: G * 1.4, left: -G * 0.55, bottom: -G * 0.35,
                 opacity: temaModu() === "v7" ? 0.16 : 0.2,
                 transform: [{ translateX: w.interpolate({ inputRange: [0, 1], outputRange: [0, G * 0.2] }) },
                             { translateY: w.interpolate({ inputRange: [0, 1], outputRange: [0, -G * 0.15] }) }] }} />
      {ZERRE.map((z, i) => <TozZerresi key={i} {...z} G={G} Y={Y} />)}
      {/* 29 Eylul (Gokberk md.3) - SAYFA ALT KENARDA ZEMINE SONER.
          Olculdu (03/00/05/10.jpg): mor-altin bulut sayfanin sol altinda
          RGB 36-44'e cikiyor, alttaki sekme seridi 11 - cubuk bulutu keskin
          bir cizgiyle kesiyor, "siyah dikdortgen" hissi buradan. Cubuga
          dokunmadan: son 64 pt'de 16 kademe, bulut ve zerre zemin rengine
          (C.bg = seridin rengi) iner. Kademe basina fark < 3/255: bant gorunmez. */}
      {ALT_SONUM.map((o, i) => (
        <View key={"s" + i} style={{ position: "absolute", left: 0, right: 0, height: 4,
                                     bottom: (ALT_SONUM.length - 1 - i) * 4,
                                     backgroundColor: C.bg, opacity: o }} />
      ))}
    </View>
  );
}
const ALT_SONUM = Array.from({ length: 16 }, (_, i) => Math.pow((i + 1) / 16, 1.6));

export function Atmosfer({ tur = "is", ufuk = 58, kaynak, yogunluk }) {
  const [, tazele] = useState(0);
  useEffect(() => sadeDinle(() => tazele(v => v + 1)), []);
  if (SADE) return null;

  // ── "AN" KATMANI ──────────────────────────────────────────────────
  // Perde görselin İÇİNDE pişmiş durumda (bkz. hazirla_atmosfer.py).
  // Çalışma anında karartma yapmıyoruz: yapsaydık perde iki kez
  // uygulanır ve ölçtüğümüz oran artık geçerli olmazdı.
  if (tur === "an") {
    if (!kaynak) {
      // Görsel verilmediyse ÇİZİLMİŞ gün batımı — 0 KB, telifsiz.
      // Varsayılan bu: mağazaya lisanssız fotoğrafla gidilmez.
      return <CizilmisGunBatimi />;
    }
    return (
      <Katman source={kaynak} resizeMode="cover"
        style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
                 width: "100%", height: "100%" }} />
    );
  }

  // ── "İŞ" KATMANI — TEK GÖRSEL ─────────────────────────────────────
  // `ufuk` parametresi artık ÇİZİMİ değil, görselin dikey KAYMASINI
  // etkiliyor: ekranın konusu "yerde"yse (keşif) parıltı biraz aşağıda,
  // uçuş bağlamındaysa yukarıda kalıyor. Fark ölçülebilir ama fark
  // edilmez — zaten amacı bu.
  if (koyuMu()) {
    // kuşağın merkezi `ufuk` (%). Tasarım: y0 = %46 → merkez %56 (varsayılan);
    // sohbet %20 → 30, giriş/kayıt %34 → 44, tanıtım/kural %30 → 40.
    const ust = Math.max(0, Math.min(80, (Number(ufuk) || 56) - 10));
    return (
      <>
        <Katman
          source={DOKU[ambiyansKusagi()] || DOKU_KOYU}
          resizeMode="stretch"
          fadeDuration={0}
          style={{ position: "absolute", top: `${ust}%`, left: 0, right: 0, height: "20%", width: "100%" }}
        />
        <IsikBulutlari />
      </>
    );
  }
  return (
    <Katman
      source={ZEMIN_ACIK}
      resizeMode="stretch"
      fadeDuration={0}
      style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
               width: "100%", height: "100%" }}
    />
  );
}

// ---------------------------------------------------------------------------
// ÇİZİLMİŞ GÜN BATIMI — "an" katmanının telifsiz varsayılanı
//
// 🔴 NEDEN VARSAYILAN BU: Gökberk'in gönderdiği referanslar Pinterest ve
// Dribbble'dan; onları uygulamaya koyamam — lisansları bize ait değil ve
// mağaza incelemesinde telifsiz görsel gerçek bir ret sebebidir.
//
// Bu yüzden varsayılan ÇİZİM: aynı sahne (yükseklikten gün batımı),
// paletten üretiliyor, 0 KB, her cihazda birebir aynı, telif riski yok.
// Gökberk lisanslı bir fotoğraf verdiği gün `hazirla_atmosfer.py` onu
// ölçüp hazırlıyor ve `kaynak` olarak buraya giriyor.
// ---------------------------------------------------------------------------
// 🔴 20 EYLÜL — RAMPA ŞAMPANYAYA ÇEKİLDİ (Obsidyen Protokol · karar 2).
//
// Eski rampa ham bir mercan gün batımıydı: kroma **48**'e kadar çıkıyor,
// hue 340°-71° arasında geziniyordu. `theme.js` şampanya kararını
// verirken gerekçesini yazmış — "çiğ altın sarısı lüks algısını
// ucuzlatır", C* 40.2 → 20.4 — ama o karar JETONLARA uygulanmış,
// bu çizime uygulanmamıştı. Yani uygulamanın en büyük renkli yüzeyi
// paletin dışındaydı.
//
// ⚠️ PARLAKLIK YAPISI AYNEN KORUNDU. Her durağın L* değeri birebir
// eski değerinde (10.7 · 15.0 · 21.2 · 30.4 · 40.4 · 50.9 · 61.6 ·
// 70.1 · 78.0 · 83.6). Değişen yalnız kroma (≤17) ve hue (59-84°).
// Gün batımının DRAMI parlaklık rampasından gelir, doygunluktan değil;
// doygunluğu kısmak sahneyi öldürmez, ucuzluğu öldürür.
//
// Hedef, derecelendirilmiş `bant.jpg` ile aynı yer: ikisi birbirinin
// yerine geçebilmeli (biri fotoğraf, biri telifsiz varsayılan).
//
// 🆕 SINIF: "BİR PALET KARARINI JETONLARA UYGULAYIP ÇİZİMLERE
// UYGULAMAZSAN, EN BÜYÜK YÜZEYİN KARARIN DIŞINDA KALIR."
const GOK = [
  "#231B16", "#302319", "#403020", "#57442E", "#6F5C44",
  "#89765D", "#A69277", "#BCA88D", "#D2BEA1", "#E1CEB0",
];

function CizilmisGunBatimi() {
  const bantlar = [];
  const N = 34;
  for (let i = 0; i < N; i++) {
    const t = i / (N - 1);
    // gökyüzü: koyudan sıcağa; ufkun altında tekrar koyulaşıyor (bulut denizi)
    const ufukta = t > 0.62;
    const k = ufukta
      ? Math.max(0, 9 - Math.round(((t - 0.62) / 0.38) * 9))
      : Math.round((t / 0.62) * 9);
    bantlar.push(
      <View key={i} pointerEvents="none" style={{
        position: "absolute", left: 0, right: 0,
        top: `${t * 100}%`, height: `${100 / N + 0.5}%`,
        backgroundColor: GOK[Math.max(0, Math.min(9, k))],
      }} />
    );
  }
  return (
    <View pointerEvents="none" style={{
      position: "absolute", top: 0, left: 0, right: 0, bottom: 0, overflow: "hidden",
      backgroundColor: GOK[0],
    }}>
      {bantlar}
      {/* ÖLÇÜLMÜŞ PERDE — metnin oturduğu üst ve alt bölge.
          Oranlar hazirla_atmosfer.py ile doğrulandı: üstte 4.61:1,
          altta 4.68:1 (beyaz metin, en kötü nokta). */}
      <View pointerEvents="none" style={{
        position: "absolute", top: 0, left: 0, right: 0, height: "34%",
        backgroundColor: "rgba(20,14,10,0.42)" }} />
      <View pointerEvents="none" style={{
        position: "absolute", top: "34%", left: 0, right: 0, height: "8%",
        backgroundColor: "rgba(20,14,10,0.21)" }} />
      <View pointerEvents="none" style={{
        position: "absolute", bottom: 0, left: 0, right: 0, height: "26%",
        backgroundColor: "rgba(20,14,10,0.46)" }} />
      <View pointerEvents="none" style={{
        position: "absolute", bottom: "26%", left: 0, right: 0, height: "8%",
        backgroundColor: "rgba(20,14,10,0.23)" }} />
    </View>
  );
}

// "an" ekranlarında metin bu renklerle yazılır — perde onlara göre ölçüldü.
export const AN = {
  metin: C.surface,
  metinSoluk: "rgba(255,253,249,0.90)",
  etiket: "rgba(255,253,249,0.72)",
};
