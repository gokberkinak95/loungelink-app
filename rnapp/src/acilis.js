// ============================================================
// acilis.js — 17 Ekim · BULUTLARIN ARASINDAN (Gökberk onayı: önizleme v3)
//
// Telefonun yerel açılış ekranı düz sis rengidir (#DCE3EF, app.json splash). Uygulama
// çizilince bu sahne TAM O KAREDEN başlar: sis dağılır, bulutlar paralaksla açılır
// (üst bulut yukarı, alttaki üç katman farklı hızlarda inip ufukta durur), arkadan
// şampanya ışık doğar, uçak bulanıktan netleşerek ışığın ortasına oturur, LOUNGELINK
// harf harf belirir, slogan açılır, sahne kararıp altındaki uygulamayı gösterir.
//
// Kurallar:
// · Uygulamayı BEKLETMEZ: AppInner altta çizilmeye ve veri yüklemeye devam eder.
// · Dokununca atlanır. "Hareketi azalt" açıksa sahne hemen çekilir.
// · Web'de (e2e + mağaza görseli çekimi) hiç çizilmez: sahneleri ve testleri kaydırmasın.
// · Bütün hareket native driver'da (transform + opacity); `top` animasyonu yok.
// · Önizleme ile aynı ölçüler: ekran oranları (W, H) üzerinden.
// ============================================================
import React, { useEffect, useRef, useState } from "react";
import { Animated, Easing, Image, Pressable, useWindowDimensions } from "react-native";
import { ACILIS, F } from "./theme";
import { useAzHareket } from "./hareket";

const BULUT_ON = require("../assets/acilis_bulut_on.png");
const BULUT_ORTA = require("../assets/acilis_bulut_orta.png");
const BULUT_ARKA = require("../assets/acilis_bulut_arka.png");
const GOK = require("../assets/acilis_gok.png");
const ISIK = require("../assets/acilis_isik.png");
const KANAT = require("../assets/mark-kanat.png");
const KANAT_BULANIK = require("../assets/acilis_kanat_bulanik.png");   // mark-kanat + her yanda 160px pay

const HARFLER = "LOUNGELINK".split("");
const YUMUSAK = Easing.bezier(0.55, 0, 0.2, 1);
const SUZUL = Easing.bezier(0.2, 0.7, 0.3, 1);

export function AcilisSahnesi({ slogan, onBitti }) {
  const { width: W, height: H } = useWindowDimensions();
  const az = useAzHareket();
  const sis = useRef(new Animated.Value(0)).current;
  const bulut = useRef(new Animated.Value(0)).current;
  const ust = useRef(new Animated.Value(0)).current;
  const isik = useRef(new Animated.Value(0)).current;
  const ucak = useRef(new Animated.Value(0)).current;
  const harf = useRef(HARFLER.map(() => new Animated.Value(0))).current;
  const slg = useRef(new Animated.Value(0)).current;
  const cik = useRef(new Animated.Value(1)).current;
  const icerik = useRef(new Animated.Value(1)).current;   // çıkışta önce uçak + yazı söner (çift görüntü olmasın)
  const bitti = useRef(false);
  const akis = useRef(null);
  // Görseller çözülmeden hareket başlarsa uçak/bulut geç belirir (web ölçümü: 2,1 sn'de uçak
  // hâlâ yoktu). Beş katman yüklenince ya da en geç 500 ms sonra başlar.
  const [hazir, setHazir] = useState(false);
  const yuklenen = useRef(0);
  const yuklendi = () => { yuklenen.current += 1; if (yuklenen.current >= 5) setHazir(true); };
  useEffect(() => { const z = setTimeout(() => setHazir(true), 500); return () => clearTimeout(z); }, []);

  const kapat = (sure) => {
    if (bitti.current) return;
    bitti.current = true;
    if (akis.current) akis.current.stop();
    // İki adım: 1) uçak, ışık ve yazı söner  2) gökyüzü açılır. Tek adımda söndürünce karşılama
    // ekranındaki uçakla üst üste binip "çift uçak" görüntüsü veriyordu (web çekimi, 17 Ekim).
    Animated.sequence([
      Animated.timing(icerik, { toValue: 0, duration: Math.round(sure * 0.4), easing: Easing.in(Easing.quad), useNativeDriver: true }),
      Animated.timing(cik, { toValue: 0, duration: Math.round(sure * 0.7), easing: Easing.in(Easing.quad), useNativeDriver: true }),
    ]).start(() => onBitti && onBitti());
  };

  useEffect(() => {
    if (az) { kapat(200); return undefined; }
    if (!hazir) return undefined;
    const t = (v, sure, gecikme, easing) => Animated.timing(v, { toValue: 1, duration: sure, delay: gecikme, easing, useNativeDriver: true });
    akis.current = Animated.parallel([
      t(sis, 1100, 100, Easing.out(Easing.quad)),
      t(bulut, 2400, 150, YUMUSAK),
      t(ust, 2000, 150, YUMUSAK),
      t(isik, 2600, 0, Easing.out(Easing.quad)),
      t(ucak, 3400, 0, Easing.linear),
      ...harf.map((v, i) => t(v, 700, 1300 + i * 70, SUZUL)),
      t(slg, 800, 2050, Easing.out(Easing.quad)),
    ]);
    akis.current.start();
    const zaman = setTimeout(() => kapat(600), 3050);
    return () => clearTimeout(zaman);
  }, [az, hazir]);

  // --- geometri (önizlemedeki yüzdeler) ---
  const bW = W * 1.7, bH = H * 0.92, bL = -W * 0.35;
  const katman = (kaynak, bas, son, ters, yukle) => (
    <Animated.Image source={kaynak} onLoad={yukle} resizeMode="stretch"
      style={{ position: "absolute", width: bW, height: bH, left: bL, top: H * bas,
               transform: [
                 { translateY: (ters ? ust : bulut).interpolate({ inputRange: [0, 1], outputRange: [0, H * (son - bas)] }) },
                 ...(ters ? [{ scaleY: -1 }] : []),
               ] }} />
  );
  const pw = W * 0.52, ph = pw * 504 / 1024;
  const px = W * 0.515 - pw / 2, py = H * 0.465 - ph / 2;   // kütle merkezi ışığın merkezine (0.5W, 0.44H)
  const PAY = 160 / 1024 * pw;
  const ucakHareket = [
    { translateY: ucak.interpolate({ inputRange: [0, 0.25, 0.4, 0.5, 0.6, 1], outputRange: [ph * 0.2, ph * 0.2, ph * 0.07, ph * 0.02, 0, 0] }) },
    { scale: ucak.interpolate({ inputRange: [0, 0.25, 0.4, 0.5, 0.6, 1], outputRange: [0.8, 0.8, 0.93, 0.98, 1, 1] }) },
  ];
  const isikR = W * 0.6;

  return (
    <Animated.View style={{ position: "absolute", left: 0, top: 0, width: W, height: H, zIndex: 9999, opacity: cik }}
      accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Pressable style={{ flex: 1, overflow: "hidden", backgroundColor: ACILIS.gece }} onPress={() => kapat(250)}>
        <Image source={GOK} onLoad={yuklendi} resizeMode="stretch" style={{ position: "absolute", left: 0, top: 0, width: W, height: H }} />
        <Animated.Image source={ISIK} onLoad={yuklendi} resizeMode="stretch"
          style={{ position: "absolute", width: isikR * 2, height: isikR * 2, left: W / 2 - isikR, top: H * 0.44 - isikR,
                   opacity: Animated.multiply(icerik, isik.interpolate({ inputRange: [0, 0.45, 1], outputRange: [0, 1, 0.85] })),
                   transform: [{ scale: isik.interpolate({ inputRange: [0, 1], outputRange: [0.5, 1] }) }] }} />
        {katman(BULUT_ARKA, 0.14, 0.60)}
        <Animated.Image source={KANAT_BULANIK} onLoad={yuklendi} resizeMode="stretch"
          style={{ position: "absolute", width: pw + 2 * PAY, height: ph + 2 * PAY, left: px - PAY, top: py - PAY,
                   opacity: Animated.multiply(icerik, ucak.interpolate({ inputRange: [0, 0.25, 0.4, 0.6, 1], outputRange: [0, 0, 0.9, 0, 0] })),
                   transform: ucakHareket }} />
        <Animated.Image source={KANAT} onLoad={yuklendi} resizeMode="stretch"
          style={{ position: "absolute", width: pw, height: ph, left: px, top: py,
                   opacity: Animated.multiply(icerik, ucak.interpolate({ inputRange: [0, 0.32, 0.6, 1], outputRange: [0, 0, 1, 1] })),
                   transform: ucakHareket }} />
        {katman(BULUT_ORTA, 0.22, 0.69)}
        {katman(BULUT_ON, 0.31, 0.79, false, yuklendi)}
        {katman(BULUT_ON, -0.36, -1.0, true)}
        <Animated.View pointerEvents="none"
          style={{ position: "absolute", left: 0, top: 0, width: W, height: H, backgroundColor: ACILIS.sis,
                   opacity: sis.interpolate({ inputRange: [0, 1], outputRange: [0.9, 0] }) }} />
        <Animated.View style={{ position: "absolute", left: 0, right: 0, top: H * 0.57, flexDirection: "row", justifyContent: "center", paddingLeft: 6, opacity: icerik }}>
          {HARFLER.map((h, i) => (
            <Animated.Text key={i} allowFontScaling={false}
              style={{ color: ACILIS.krem, fontSize: 15, fontWeight: "600", letterSpacing: 6.3,
                       opacity: harf[i], transform: [{ translateY: harf[i].interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }] }}>
              {h}
            </Animated.Text>
          ))}
        </Animated.View>
        {!!slogan && (
          <Animated.Text allowFontScaling={false}
            style={{ position: "absolute", left: 0, right: 0, top: H * 0.615, textAlign: "center",
                     fontFamily: F.serifGosterim, fontSize: 19, color: ACILIS.altin, opacity: Animated.multiply(icerik, slg) }}>
            {slogan}
          </Animated.Text>
        )}
      </Pressable>
    </Animated.View>
  );
}
