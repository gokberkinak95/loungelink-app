// web_sahne/Galeri.js — SENARYO SEÇİCİ. `?sahne=ad` okur, fikstürü kurar,
// GERÇEK App'i çizer. Bu dosya yalnız LL_SAHNE=1 web export'unda App.js
// yerine geçer (metro.config.js). Cihazda hiç yüklenmez.
//
// Web'de fontlar `expo-font` eklentisiyle GÖMÜLMEZ (o yalnız iOS/Android
// derlemesine girer); burada `loadAsync` ile aynı aile adlarıyla
// yükleniyor ki ekran cihazdaki fontla çizilsin. Aile adları
// `src/typography.js` ve `theme.js`teki adlarla BİREBİR aynı olmak
// zorunda — aksi hâlde web sahnesi sistem fontuyla çizer ve cihazı
// yansıtmaz.
import React, { useEffect, useState } from "react";
import { View, Text } from "react-native";
import * as Font from "expo-font";
import App from "../App";
import { sahneKur } from "./sahneler";
import MomentScreen from "../src/MomentScreen";
import { TerminalRadari, TakimyildizPuan, OnayDamgasi, SessizPano, KalkisHalkasi, GeceKarti } from "../src/hareket";
import { C, FS } from "../src/theme";
import { Sayfa, MarkaYukleyici, Tanecik } from "../src/ui";
import { D as TR } from "../src/i18n";

const q = new URLSearchParams(typeof window !== "undefined" ? window.location.search : "");
const SAHNE = q.get("sahne") || "karsilama";
sahneKur(SAHNE, q);

const FONTLAR = {
  "CormorantGaramond-Light": require("../assets/fonts/CormorantGaramond-Light.ttf"),
  "CormorantGaramond-SemiBold": require("../assets/fonts/CormorantGaramond-SemiBold.ttf"),
  "CormorantGaramond-Bold": require("../assets/fonts/CormorantGaramond-Bold.ttf"),
  "Archivo-Regular": require("../assets/fonts/Archivo-Regular.ttf"),
  "Archivo-Medium": require("../assets/fonts/Archivo-Medium.ttf"),
  "Archivo-SemiBold": require("../assets/fonts/Archivo-SemiBold.ttf"),
  "Archivo-Bold": require("../assets/fonts/Archivo-Bold.ttf"),
  "PlusJakartaSans-Regular": require("../assets/fonts/PlusJakartaSans-Regular.ttf"),
  "PlusJakartaSans-Medium": require("../assets/fonts/PlusJakartaSans-Medium.ttf"),
  "PlusJakartaSans-SemiBold": require("../assets/fonts/PlusJakartaSans-SemiBold.ttf"),
  "PlusJakartaSans-Bold": require("../assets/fonts/PlusJakartaSans-Bold.ttf"),
  "JetBrainsMono-Medium": require("../assets/fonts/JetBrainsMono-Medium.ttf"),
  "JetBrainsMono-SemiBold": require("../assets/fonts/JetBrainsMono-SemiBold.ttf"),
};

export default function Galeri() {
  const [hazir, setHazir] = useState(false);
  useEffect(() => {
    Font.loadAsync(FONTLAR)
      .catch((e) => console.warn("font yüklenemedi", String(e)))
      .then(() => setHazir(true));
  }, []);
  useEffect(() => {
    if (!hazir) return;
    const t = setTimeout(() => {
      if (typeof window !== "undefined") {
        // Sahne betiği varsa (sekme tıklama vb.) onu koşturur, sonra hazır der.
        const p = (typeof globalThis.__SAHNE_SONRA === "function") ? globalThis.__SAHNE_SONRA() : null;
        Promise.resolve(p).then(() => { window.__LL_HAZIR = true; });
      }
    }, 1800);
    return () => clearTimeout(t);
  }, [hazir]);
  if (!hazir) return <View style={{ flex: 1, backgroundColor: "#F9F8F6" }} />;
  // v6.2 — HAREKET VİTRİNİ: onaylı hareket bileşenlerini gerçek fontlarla,
  // tek başına çizer (K3 · K5 · K8 · K2). Yalnız web sahnesinde; uygulamaya girmez.
  if (SAHNE.endsWith("vitrin_kapi")) {
    return <MomentScreen t={TR.tr || {}} kind="matched" dugum="Eşleştiniz" title="Deniz K. seni salona alıyor"
      subtitle="TAV Primeclass · 14:20–16:40" ikiz={["G", "D"]}
      primary={{ label: "Sohbeti aç", onPress: () => {} }} secondary={{ label: "Şimdi değil", onPress: () => {} }} />;
  }
  if (SAHNE.endsWith("vitrin_radar")) {
    return (<Sayfa><View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <TerminalRadari etiket="Terminalindeki host'lar aranıyor" dugum="IST" />
    </View><Tanecik /></Sayfa>);
  }
  if (SAHNE.endsWith("vitrin_puan")) {
    // v7.2 (Gökberk 3 Ekim): K8'in altında yükleyici kanadı yoktu — vitrinden çıktı (K2 kendi sahnesinde).
    // Takımyıldız uygulamadaki gibi GECE KARTINDA.
    return (<Sayfa><View style={{ flex: 1, justifyContent: "center", paddingHorizontal: 22 }}>
      <GeceKarti>
        <TakimyildizPuan deger={5} onDegis={() => {}} boy={36} gece />
        <Text style={{ fontFamily: "CormorantGaramond-SemiBold", fontStyle: "italic", fontSize: 22, color: "#F9F8F6", textAlign: "center", marginTop: 10 }}>Harika bir sohbetti.</Text>
      </GeceKarti>
    </View></Sayfa>);
  }
  // v7.2 — hareket vitrininin geri kalanı (K2 · K4 · K6 · K7 · K9). Gökberk 3 Ekim:
  // "sadece 3 hareket dili vermişsin; diğerleri nerede?" Her biri tek başına, temanın renkleriyle.
  if (SAHNE.endsWith("vitrin_yukleyici")) {
    return (<Sayfa><View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <MarkaYukleyici boy={150} />
    </View></Sayfa>);
  }
  if (SAHNE.endsWith("vitrin_damga")) {
    return (<Sayfa><View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <OnayDamgasi t={TR.tr || {}} />
    </View></Sayfa>);
  }
  if (SAHNE.endsWith("vitrin_pano")) {
    return (<Sayfa><View style={{ flex: 1, justifyContent: "center", paddingHorizontal: 40 }}>
      <SessizPano baslik="GELEN İSTEKLER" durum="BEKLEYEN İSTEK YOK" />
    </View></Sayfa>);
  }
  if (SAHNE.endsWith("vitrin_kalkis")) {
    const simdi = Date.now();
    return (<Sayfa><View style={{ flex: 1, alignItems: "center", justifyContent: "center", gap: 44 }}>
      <KalkisHalkasi t={TR.tr || {}} baslangic={simdi + 42 * 60000} bitis={simdi + 162 * 60000} />
      <KalkisHalkasi t={TR.tr || {}} baslangic={simdi - 110 * 60000} bitis={simdi + 9 * 60000} />
    </View></Sayfa>);
  }
  if (SAHNE.endsWith("vitrin_zemin")) {
    return (<Sayfa><View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <Text style={{ fontSize: FS.xs, letterSpacing: 4, color: C.mut }}>LOUNGELINK</Text>
    </View><Tanecik /></Sayfa>);
  }
  return <App />;
}
