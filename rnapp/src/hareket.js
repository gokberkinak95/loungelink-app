// ============================================================================
// LoungeLink · hareket.js — HAREKET DİLİ (v6.2 · 28 Eylül)
//
// Gökberk onayı (önizleme "LoungeLink Hareket Dili"):
//   K3 terminal radarı · K4 şart şart mühür · K5 kapı aralanır ·
//   K7 kalkış halkası · K8 takımyıldız puanı   → UYGULA
//   K2 yükleyici → mevcut kanat PNG'siyle (ui.js · MarkaYukleyici)
//   K9 canlı zemin → YALNIZ arka plan hareketi (atmosfer.js)
//   K6 → yapılmadı (bozuk bir durum sanılabilir) · K1 → yalnız öneri
//
// İLKELER
//   · Yeni native paket YOK: hepsi RN `Animated` + `View`. react-native-svg
//     eklemek bir bağımlılık ve bir test yükü demekti; bu şekiller onsuz
//     çiziliyor.
//   · Renk ve yazı yalnız tema jetonlarından (C · FS · F · MONO).
//   · "Hareketi azalt" açıksa her bileşen DURAĞAN son karesini çizer.
//   · Döngüler yalnız ekran açıkken döner; unmount'ta durur.
// ============================================================================
import React, { useEffect, useRef, useState } from "react";
import { AccessibilityInfo, Animated, Easing, Image, Platform, Text, TouchableOpacity, View } from "react-native";
import { ARA, C, FS, R, SP, TAP, temaModu } from "./theme";
import { MONO } from "./typography";
import { Ikon } from "./ikon";
import { BUYUK } from "./i18n";

// ---------------------------------------------------------------- erişim
export function useAzHareket() {
  const [az, setAz] = useState(false);
  useEffect(() => {
    let canli = true;
    const A = AccessibilityInfo;
    try {
      if (A && typeof A.isReduceMotionEnabled === "function") {
        A.isReduceMotionEnabled().then((v) => { if (canli) setAz(!!v); }).catch(() => {});
      }
    } catch (e) { /* stub/web: hareket açık kalır */ }
    let abone = null;
    try {
      if (A && typeof A.addEventListener === "function") {
        abone = A.addEventListener("reduceMotionChanged", (v) => setAz(!!v));
      }
    } catch (e) { abone = null; }
    return () => { canli = false; if (abone && abone.remove) abone.remove(); };
  }, []);
  return az;
}

// Hafif dokunsal geri bildirim — web'de ve paket yoksa sessizce yok.
export function dokun(tur = "hafif") {
  if (Platform.OS === "web") return;
  try {
    const H = require("expo-haptics");
    if (tur === "secim" && H.selectionAsync) H.selectionAsync();
    else if (H.impactAsync) H.impactAsync(H.ImpactFeedbackStyle ? H.ImpactFeedbackStyle.Light : undefined);
  } catch (e) { /* titreşim yoksa hareket yine tamam */ }
}

function dongu(anim) {
  const d = Animated.loop(anim);
  d.start();
  return () => d.stop();
}

// ======================================================================
// K3 · TERMİNAL RADARI — Keşfet yüklenirken "arıyoruz" anlatır.
// Nokta konumları TEMSİLÎ: gerçek konum göstermez (gizlilik sözü).
// ======================================================================
const RADAR_NOKTA = [
  { aci: -38, r: 0.72, altin: true },
  { aci: 128, r: 0.58 },
  { aci: 62, r: 0.86 },
  { aci: 205, r: 0.44 },
  { aci: -112, r: 0.9 },
];

export function TerminalRadari({ boy = 220, etiket, dugum }) {
  const az = useAzHareket();
  const nabiz = useRef([0, 1, 2].map(() => new Animated.Value(0))).current;
  const tarama = useRef(new Animated.Value(0)).current;
  const noktalar = useRef(RADAR_NOKTA.map(() => new Animated.Value(az ? 1 : 0))).current;

  useEffect(() => {
    if (az) { noktalar.forEach((n) => n.setValue(1)); return undefined; }
    const durdur = [];
    nabiz.forEach((v, i) => {
      durdur.push(dongu(Animated.sequence([
        Animated.delay(i * 1200),
        Animated.timing(v, { toValue: 1, duration: 3600, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
        Animated.timing(v, { toValue: 0, duration: 0, useNativeDriver: true }),
      ])));
    });
    durdur.push(dongu(Animated.timing(tarama, { toValue: 1, duration: 6000, easing: Easing.linear, useNativeDriver: true })));
    noktalar.forEach((v, i) => {
      durdur.push(dongu(Animated.sequence([
        Animated.delay(300 + i * 1000),
        Animated.timing(v, { toValue: 1, duration: 500, useNativeDriver: true }),
        Animated.delay(3800),
        Animated.timing(v, { toValue: 0, duration: 700, useNativeDriver: true }),
        Animated.delay(Math.max(0, 1000 - i * 200)),
      ])));
    });
    return () => durdur.forEach((f) => f());
  }, [az]);

  const yari = boy / 2;
  const halka = (cap, ek) => ({
    position: "absolute", left: yari - cap / 2, top: yari - cap / 2,
    width: cap, height: cap, borderRadius: R.full, borderWidth: 1, ...ek,
  });
  return (
    <View style={{ alignItems: "center" }} accessible accessibilityRole="progressbar"
      accessibilityLabel={etiket || ""}>
      <View style={{ width: boy, height: boy }}>
        {[1, 0.66, 0.33].map((k) => (
          <View key={k} style={halka(boy * k, { borderColor: C.line })} />
        ))}
        {!az && nabiz.map((v, i) => (
          <Animated.View key={i} pointerEvents="none" style={[halka(boy, { borderColor: C.goldLine || C.gold }), {
            opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0.7, 0] }),
            transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.15, 1] }) }],
          }]} />
        ))}
        {!az && (
          <Animated.View pointerEvents="none" style={{
            position: "absolute", left: 0, top: 0, width: boy, height: boy,
            transform: [{ rotate: tarama.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] }) }],
          }}>
            <View style={{ position: "absolute", left: yari - 0.5, top: 0, width: 1, height: yari,
                           backgroundColor: C.gold, opacity: 0.35 }} />
          </Animated.View>
        )}
        {RADAR_NOKTA.map((n, i) => {
          const rad = (n.aci * Math.PI) / 180;
          const cap = n.altin ? 9 : 6;
          return (
            <Animated.View key={i} style={{
              position: "absolute",
              left: yari + Math.cos(rad) * yari * n.r - cap / 2,
              top: yari + Math.sin(rad) * yari * n.r - cap / 2,
              width: cap, height: cap, borderRadius: R.full,
              backgroundColor: n.altin ? C.gold : C.mutedAA || C.mut,
              opacity: noktalar[i],
            }} />
          );
        })}
        <View style={{ position: "absolute", left: yari - 5, top: yari - 5, width: 10, height: 10,
                       borderRadius: R.full, backgroundColor: C.ink }} />
      </View>
      {!!dugum && (
        <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, letterSpacing: 1.4, color: C.goldText,
                       marginTop: ARA[18] }}>{BUYUK(dugum)}</Text>
      )}
      {!!etiket && (
        <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[6], textAlign: "center" }}>{etiket}</Text>
      )}
    </View>
  );
}

// ======================================================================
// K4 · ONAY DAMGASI — kural kartındaki bütün şartlar tuttuğunda.
// Çağıran `Muhur` ile sarar (iniş + titreşim zaten orada).
// ======================================================================
export function OnayDamgasi({ t }) {
  return (
    <View style={{ width: 84, height: 84, borderRadius: R.full, borderWidth: 1.5,
                   borderColor: C.ink, alignItems: "center", justifyContent: "center",
                   transform: [{ rotate: "-8deg" }], opacity: 0.92 }}>
      <View style={{ position: "absolute", left: 5, top: 5, right: 5, bottom: 5, borderRadius: R.full,
                     borderWidth: 1, borderColor: C.line2 || C.line, borderStyle: "dashed" }} />
      <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2, color: C.ink }}>
        {BUYUK(t.ruleSealOk || "Onaylı")}
      </Text>
      <Text style={{ fontFamily: MONO[500], fontSize: FS.micro, color: C.goldText, marginTop: 2 }}>
        {BUYUK(t.ruleSealAll || "")}
      </Text>
    </View>
  );
}

// ======================================================================
// K7 · KALKIŞ HALKASI — mevcut Güven halkasıyla (TrustRing) AYNI dil:
// noktalı çember. Dolan kısım altın; son 15 dakikada kehribar.
// ======================================================================
const HALKA_NOKTA = 48;
function ikiHane(n) { return String(Math.max(0, n)).padStart(2, "0"); }

export function KalkisHalkasi({ t, baslangic, bitis, boy = 176, metinRengi }) {
  const az = useAzHareket();
  const [simdi, setSimdi] = useState(Date.now());
  const nefes = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    const iv = setInterval(() => setSimdi(Date.now()), 1000);
    return () => clearInterval(iv);
  }, []);
  useEffect(() => {
    if (az) return undefined;
    return dongu(Animated.sequence([
      Animated.timing(nefes, { toValue: 0.45, duration: 500, useNativeDriver: true }),
      Animated.timing(nefes, { toValue: 1, duration: 500, useNativeDriver: true }),
    ]));
  }, [az]);

  if (!baslangic || !bitis || bitis <= baslangic) return null;
  const toplam = bitis - baslangic;
  const gecen = Math.min(toplam, Math.max(0, simdi - baslangic));
  const oran = gecen / toplam;
  // v6.3 · PANO K7 (Gökberk notu) — pencere henüz başlamadıysa BAŞLANGICA
  // sayar ("Buluşmaya"); başladıysa BİTİŞE ("Oturumun bitimine").
  const once = simdi < baslangic;
  const etiket = once ? (t.ringToStart || t.fidsLeft || "") : (t.ringLeft || "");
  const kalanSn = Math.max(0, Math.round(((once ? baslangic : bitis) - simdi) / 1000));
  const kisa = !once && kalanSn < 15 * 60;
  const renk = kisa ? C.amber : C.gold;
  const dolu = Math.round(oran * HALKA_NOKTA);
  const yari = boy / 2, rr = yari - 8;
  const sa = Math.floor(kalanSn / 3600), dk = Math.floor((kalanSn % 3600) / 60), sn = kalanSn % 60;
  return (
    <View style={{ alignItems: "center" }} accessible accessibilityRole="timer"
      accessibilityLabel={`${etiket} ${ikiHane(sa)}:${ikiHane(dk)}`}>
      <View style={{ width: boy, height: boy, alignItems: "center", justifyContent: "center" }}>
        {Array.from({ length: HALKA_NOKTA }).map((_, i) => {
          const aci = (i / HALKA_NOKTA) * 2 * Math.PI - Math.PI / 2;
          const on = i < dolu;
          const bas = i === dolu;
          const cap = bas ? 9 : on ? 6 : 4;
          return (
            <View key={i} style={{
              position: "absolute", left: yari + rr * Math.cos(aci) - cap / 2,
              top: yari + rr * Math.sin(aci) - cap / 2, width: cap, height: cap,
              borderRadius: R.full, backgroundColor: bas ? (metinRengi || C.ink) : on ? renk : (metinRengi ? "rgba(247,243,236,0.18)" : C.line),
            }} />
          );
        })}
        <View style={{ flexDirection: "row", alignItems: "flex-end" }}>
          <Text style={{ fontFamily: MONO[500], fontSize: FS.bant, color: metinRengi || C.ink, lineHeight: FS.bant * 1.2 }}>
            {ikiHane(sa)}:{ikiHane(dk)}
          </Text>
          <Animated.Text style={{ fontFamily: MONO[500], fontSize: FS.sm, color: renk, marginLeft: 2,
                                  marginBottom: 6, opacity: az ? 1 : nefes }}>:{ikiHane(sn)}</Animated.Text>
        </View>
        <Text style={{ fontSize: FS.micro, letterSpacing: 2, color: C.mut, marginTop: 2 }}>
          {BUYUK(etiket)}
        </Text>
      </View>
    </View>
  );
}

// ======================================================================
// K8 · TAKIMYILDIZ PUANI — yıldızlar sırayla parlar, aralarında ince bir
// hat belirir. Dokunmatik alan ve ekran okuyucu (radio) korunur.
// ======================================================================
const YILDIZ_DY = [10, -6, 4, -10, 2];

// v7.2 (Gökberk 3 Ekim: "takımyıldız alanı arka plana yenik düşebiliyor, yıldızlar arasındaki
// çizgi temaya göre görünüm sorunu yaratabilir") — fildişi zeminde %55 bronz bir hat görünmüyor;
// takımyıldız GECEYE aittir. `gece`: yıldızlar şampanya (seçili hafif ışımalı), seçilmemiş
// fildişi %45 kontur, hat şampanya %80 ve 1.5pt. Gece kartı: `GeceKarti`.
export function GeceKarti({ children, stil }) {
  const TOZ = [[0.08, 0.22, 2], [0.18, 0.70, 1.5], [0.30, 0.12, 1.5], [0.44, 0.84, 2], [0.62, 0.18, 1.5],
               [0.74, 0.64, 2], [0.86, 0.30, 1.5], [0.93, 0.80, 1.5], [0.52, 0.48, 1], [0.24, 0.46, 1]];
  return (
    // 4. tur (Gokberk: "laciverti header'a uygun, biraz daha soft"): bandin gece mavisi
    // (#1A2B4C) %90 — fildisi sayfa hafifce sizar; ustte koyulasan tul, altta safak sisi izi.
    <View style={[{ borderRadius: R.lg + 4, overflow: "hidden", backgroundColor: C.gece + "E6",
                    paddingVertical: ARA[22], paddingHorizontal: ARA[14],
                    shadowColor: C.golgeRenk, shadowOpacity: 0.10, shadowRadius: 18, shadowOffset: { width: 0, height: 8 } }, stil]}>
      <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0, top: 0, height: "60%", opacity: 0.35 }}>
        <Image source={require("../assets/v7_gece_ust.png")} resizeMode="stretch" style={{ width: "100%", height: "100%" }} />
      </View>
      <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: "55%", opacity: 0.16 }}>
        <Image source={require("../assets/v7_sis_alt.png")} resizeMode="stretch" style={{ width: "100%", height: "100%" }} />
      </View>
      {TOZ.map(([x, y, b], i) => (
        <View key={i} pointerEvents="none" style={{ position: "absolute", left: `${x * 100}%`, top: `${y * 100}%`,
          width: b, height: b, borderRadius: R.full, backgroundColor: "rgba(249,248,246,0.55)" }} />
      ))}
      {children}
    </View>
  );
}

export function TakimyildizPuan({ deger = 0, onDegis, boy = 34, gece = false }) {
  const az = useAzHareket();
  const parla = useRef([0, 1, 2, 3, 4].map(() => new Animated.Value(0))).current;
  const hat = useRef([0, 1, 2, 3].map(() => new Animated.Value(0))).current;

  useEffect(() => {
    parla.forEach((v, i) => v.setValue(i < deger && az ? 1 : 0));
    hat.forEach((v, i) => v.setValue(i < deger - 1 && az ? 1 : 0));
    if (az || !deger) return undefined;
    const adimlar = [];
    for (let i = 0; i < deger; i++) {
      adimlar.push(Animated.sequence([
        Animated.delay(i * 120),
        Animated.spring(parla[i], { toValue: 1, friction: 5, tension: 140, useNativeDriver: true }),
      ]));
      if (i > 0) {
        adimlar.push(Animated.sequence([
          Animated.delay(i * 120 + 80),
          Animated.timing(hat[i - 1], { toValue: 1, duration: 320, useNativeDriver: true }),
        ]));
      }
    }
    const a = Animated.parallel(adimlar);
    a.start();
    return () => a.stop();
  }, [deger, az]);

  const hucre = boy + SP[3];
  const merkez = (i) => ({ x: i * hucre + hucre / 2, y: 22 + YILDIZ_DY[i] + boy / 2 });
  return (
    <View style={{ alignSelf: "center", width: hucre * 5, height: boy + 44 }}>
      {[0, 1, 2, 3].map((i) => {
        const a = merkez(i), b = merkez(i + 1);
        const dx = b.x - a.x, dy = b.y - a.y;
        const uz = Math.sqrt(dx * dx + dy * dy);
        const aci = Math.atan2(dy, dx);
        return (
          <Animated.View key={i} pointerEvents="none" style={{
            position: "absolute", left: (a.x + b.x) / 2 - uz / 2, top: (a.y + b.y) / 2 - 0.5,
            width: uz, height: gece ? 1.5 : 1, backgroundColor: gece ? C.goldBtn : C.gold,
            opacity: hat[i].interpolate({ inputRange: [0, 1], outputRange: [0, gece ? 0.8 : 0.55] }),
            transform: [{ rotate: `${aci}rad` }],
          }} />
        );
      })}
      {[1, 2, 3, 4, 5].map((n, i) => {
        const secili = n <= deger;
        const s = parla[i];
        return (
          <TouchableOpacity key={n} hitSlop={TAP.slop} activeOpacity={0.8}
            onPress={() => { dokun("secim"); onDegis && onDegis(n); }}
            accessibilityRole="radio" accessibilityState={{ selected: deger === n }}
            accessibilityLabel={String(n)}
            style={{ position: "absolute", left: i * hucre + SP[3] / 2, top: 22 + YILDIZ_DY[i],
                     width: boy, height: boy, alignItems: "center", justifyContent: "center" }}>
            <Animated.View style={[{
              transform: [{ scale: secili ? s.interpolate({ inputRange: [0, 0.6, 1], outputRange: [0.8, 1.25, 1] }) : 1 }],
              opacity: secili ? s.interpolate({ inputRange: [0, 1], outputRange: [0.35, 1] }) : 1,
            }, gece && secili ? { shadowColor: C.goldBtn, shadowOpacity: 0.7, shadowRadius: 8, shadowOffset: { width: 0, height: 0 } } : null]}>
              <Ikon ad={secili ? "degerlendirmeDolu" : "degerlendirme"} boy={boy}
                renk={secili ? (gece ? C.goldBtn : C.gold) : (gece ? "rgba(249,248,246,0.45)" : C.dimAA)} />
            </Animated.View>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

// ---------------------------------------------------------------- K1′ açılışa ışık
// Gökberk (28 Eylül): "açılış ekranı güzel olmuş … tanıtım ekranlarındaki
// görsel kısımları kaybetmek istemem … sadece açılış ekranını uygula."
// YALNIZ Splash'te (App.js) çağrılır; tanıtım/giriş/kayıt FotoSahne'si aynen.
// Kanat YERİNDEN OYNAMAZ. Kanat kutusunun içine, kanadın ARKASINA üç katman:
//   1. iz    — sol alttan kanadın KUYRUK UCUNA kadar çizilen ince ışık (7 sn)
//   2. cam   — camın üstünden çapraz geçen yumuşak parıltı (9 sn)
//   3. zerre — pencerede yükselip sönen dört toz zerresi (10 sn)
// Renk: C.foto.marka (fildişi) — fotoğrafın üstündeki mevcut mürekkep.
const ISIK = require("../assets/isik_bulutu.png");
const ZERRELER = [[-0.25, 1.0, 0.0], [0.4, 1.25, 0.3], [0.75, 0.7, 0.6], [0.1, 1.6, 0.8]];
// Döngü değeri v (0→1) için faz kaydırmalı anahtar kareler: yerel = (v + faz) mod 1.
// İç içe interpolate yerine TEK interpolate — sıçrama noktası iki kareyle.
function fazli(faz, ins, outs) {
  const deger = (u) => {
    for (let k = 1; k < ins.length; k++) {
      if (u <= ins[k]) { const a = (u - ins[k - 1]) / (ins[k] - ins[k - 1]); return outs[k - 1] + a * (outs[k] - outs[k - 1]); }
    }
    return outs[outs.length - 1];
  };
  const kes = 1 - faz;
  const noktalar = [[0, deger(faz)], [1, deger((1 + faz) % 1 || (faz ? faz : 1))]];
  ins.forEach((x) => { const v = (x - faz + 1) % 1; if (v > 0 && v < 1 && Math.abs(v - kes) > 1e-6) noktalar.push([v, deger(x)]); });
  if (faz > 0) { noktalar.push([kes - 0.0005, deger(1)]); noktalar.push([kes, deger(0)]); }
  noktalar.sort((a, b) => a[0] - b[0]);
  return { inputRange: noktalar.map((n) => n[0]), outputRange: noktalar.map((n) => n[1]) };
}
export function AcilisIsigi({ g, y }) {
  const az = useAzHareket();
  const iz = useRef(new Animated.Value(0)).current;
  const cam = useRef(new Animated.Value(0)).current;
  const zer = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (az) return undefined;
    const d = [
      Animated.loop(Animated.timing(iz, { toValue: 1, duration: 7000, easing: Easing.bezier(0.45, 0, 0.2, 1), useNativeDriver: true })),
      Animated.loop(Animated.timing(cam, { toValue: 1, duration: 9000, easing: Easing.inOut(Easing.sin), useNativeDriver: true })),
      Animated.loop(Animated.timing(zer, { toValue: 1, duration: 10000, easing: Easing.linear, useNativeDriver: true })),
    ];
    d.forEach((a) => a.start());
    return () => d.forEach((a) => a.stop());
  }, [az, iz, cam, zer]);
  if (az) return null;
  const renk = C.foto.marka;
  const L = g * 1.3, ACI = 34;
  const cs = Math.cos(ACI * Math.PI / 180), sn = Math.sin(ACI * Math.PI / 180);
  const kx = g * 0.02, ky = y * 0.96;           // kuyruk ucu
  const PARCA = 14;
  return (
    <View pointerEvents="none" style={{ position: "absolute", left: 0, top: 0, width: g, height: y }}>
      {/* 2 · cam parıltısı */}
      <Animated.Image source={ISIK} resizeMode="stretch" tintColor={renk}
        style={{ position: "absolute", width: g * 1.4, height: g * 3.4,
                 left: g / 2 - g * 0.7, top: y / 2 - g * 1.7,
                 opacity: cam.interpolate({ inputRange: [0, 0.35, 0.6, 1], outputRange: [0, 0.14, 0, 0] }),
                 transform: [
                   { translateX: cam.interpolate({ inputRange: [0, 0.6, 1], outputRange: [-g * 1.1, g * 1.3, g * 1.3] }) },
                   { translateY: cam.interpolate({ inputRange: [0, 0.6, 1], outputRange: [g * 1.1, -g * 1.3, -g * 1.3] }) },
                   { rotate: "35deg" },
                 ] }} />
      {/* 1 · iz: kuyruk ucunda biter, sol alta uzanır */}
      <Animated.View style={{ position: "absolute", width: L, height: 2, overflow: "hidden",
                              left: kx - (L / 2) * cs - L / 2, top: ky + (L / 2) * sn - 1,
                              opacity: iz.interpolate({ inputRange: [0, 0.12, 0.6, 1], outputRange: [0, 0.9, 0.8, 0] }),
                              transform: [{ rotate: `-${ACI}deg` }] }}>
        <Animated.View style={{ flexDirection: "row", width: L, height: 2,
                                transform: [{ translateX: iz.interpolate({ inputRange: [0, 0.6, 1], outputRange: [-L, 0, 0] }) }] }}>
          {Array.from({ length: PARCA }).map((_, i) => (
            <View key={i} style={{ width: L / PARCA, height: 1.3, alignSelf: "center",
                                   backgroundColor: renk, opacity: Math.pow((i + 1) / PARCA, 1.6) }} />
          ))}
        </Animated.View>
      </Animated.View>
      {/* 3 · toz zerreleri */}
      {ZERRELER.map(([ox, oy, faz], i) => (
        <Animated.View key={i} style={{ position: "absolute", width: 2.4, height: 2.4, borderRadius: R.full,
                                         backgroundColor: renk, left: g / 2 + ox * g, top: y / 2 + oy * g,
                                         opacity: zer.interpolate(fazli(faz, [0, 0.25, 1], [0, 0.7, 0])),
                                         transform: [{ translateY: zer.interpolate(fazli(faz, [0, 1], [12, -g * 0.9])) }] }} />
      ))}
    </View>
  );
}

// ============================================================================
// K6 · SESSİZ PANO — boş durumlar (istek · davet · sohbet · soru)
// 28 Eylül · Gökberk: "K6'yı da yapalım". Onaylı önizleme: boş ekran bir
// kalkış panosu; satırlar tire, arada bir hücre döner (4 sn döngü, dönüş
// ~50 ms), köşede tek altın ışık yanıp söner. Dört boş durumda AYNI dil,
// yalnız başlık/durum satırı değişir. Metin ve düğme BosDurum'un kendisi.
// "Hareketi azalt" → durağan pano, ışık sabit.
// ============================================================================
const PANO_HUCRE = [
  { oran: 40, yazi: "— —",     gec: 0 },
  { oran: 86, yazi: "— — — —", gec: 250 },
  { oran: 70, yazi: "— : —",   gec: 500 },
];
function PanoHucresi({ oran, yazi, gec }) {
  const az = useAzHareket();
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (az) return undefined;
    const d = Animated.sequence([
      Animated.delay(gec),
      Animated.loop(Animated.timing(v, { toValue: 1, duration: 4000, easing: Easing.linear, useNativeDriver: true })),
    ]);
    d.start();
    return () => d.stop();
  }, [az]);
  return (
    <Animated.View style={{
      flex: oran, height: 24, borderRadius: R.onay, backgroundColor: C.bgAlt,
      alignItems: "center", justifyContent: "center",
      opacity: az ? 1 : v.interpolate({ inputRange: [0, 0.7, 0.71, 0.725, 1], outputRange: [1, 1, 0.2, 1, 1] }),
    }}>
      <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, color: C.ink, letterSpacing: 0.5 }}>{yazi}</Text>
    </Animated.View>
  );
}

export function SessizPano({ baslik, durum }) {
  const az = useAzHareket();
  const isik = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (az) return undefined;
    const d = Animated.loop(Animated.sequence([
      Animated.timing(isik, { toValue: 1, duration: 1200, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
      Animated.timing(isik, { toValue: 0, duration: 1200, easing: Easing.inOut(Easing.sin), useNativeDriver: true }),
    ]));
    d.start();
    return () => d.stop();
  }, [az]);
  const satir = (k) => (
    <View key={k} style={{ flexDirection: "row", gap: SP[2], marginTop: k ? SP[2] : 0 }}>
      {PANO_HUCRE.map((h, i) => <PanoHucresi key={i} {...h} gec={h.gec + k * 250} />)}
    </View>
  );
  return (
    <View accessible accessibilityLabel={durum}
      style={[{ alignSelf: "stretch", borderRadius: R.sm, borderWidth: 1, borderColor: C.line,
               backgroundColor: C.bg, padding: ARA[14], marginBottom: SP[4] },
               // v7.2 (Gökberk 4. tur: "gelen istekler boş görünüm kartı kayboluyor") — beyaz pano,
               // köşe 20, lacivert %6 gölge, üst ışık; çizgi yok.
               temaModu() === "v7" ? { backgroundColor: C.card, borderWidth: 0, borderRadius: R.lg,
                 borderTopWidth: 1, borderTopColor: "rgba(255,255,255,1)",
                 shadowColor: C.golgeRenk, shadowOpacity: 0.06, shadowRadius: 16, shadowOffset: { width: 0, height: 6 }, elevation: 2 } : null]}>
      <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: SP[3] }}>
        <Text style={{ fontSize: FS.xs, color: C.muted, letterSpacing: 2 }}>{baslik}</Text>
        <Animated.View style={{ width: 6, height: 6, borderRadius: R.full, backgroundColor: C.gold,
                                opacity: az ? 1 : isik.interpolate({ inputRange: [0, 1], outputRange: [0.25, 1] }) }} />
      </View>
      {satir(0)}
      {satir(1)}
      <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, color: C.goldText, letterSpacing: 1.5,
                     textAlign: "center", marginTop: SP[4] }}>{durum}</Text>
    </View>
  );
}
