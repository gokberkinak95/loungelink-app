// ============================================================
// tur.js — 19 Ekim · "?" İLE SAYFA TURLARI (Gökberk onayı: önizleme v9)
//
// Her sayfanın üst çubuğunda küçük bir "?" (TurDugmesi). Dokununca o sayfanın turu açılır:
// 1. adım sayfanın genel "nasıl çalışır" özeti, sonraki adımlar sayfadaki öğeleri tek tek
// vurgular. Alt kısımda adım göstergesi (dokunulmaz), "Geç", "Devam et", son adımda "Anladım".
//
// Hedefler: sayfalar öğelerine `{...turHedef("kesfet_uyum")}` yayar. Tur açılınca kayıtlı her
// hedef ekrandaki gerçek konumundan ölçülür (measureInWindow). Ekranda olmayan hedefin adımı
// ATLANIR ve sayaç kendini ayarlar (ör. tek uçuşta "uçuş çipleri" adımı yok).
//
// Kalıcılık: ana sayfa turu ilk girişte bir kez kendiliğinden açılır; "?"in yanındaki
// "Nasıl çalışır?" etiketi ve küçük nokta "?"e ilk dokunuşa kadar görünür.
// ============================================================
import React, { useEffect, useRef, useState } from "react";
import { AccessibilityInfo, Animated, Modal, Pressable, Text, TouchableOpacity, View, useWindowDimensions } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { ARA, C, F, FS, R, SP, TAP, TUR } from "./theme";
import { useAzHareket } from "./hareket";

// ---------------------------------------------------------------- hedef kaydı
const _hedefler = {};          // id -> bileşen örneği
export function turHedef(id) {
  return { ref: (el) => { if (el) _hedefler[id] = el; else delete _hedefler[id]; }, collapsable: false };
}
function olc(id) {
  return new Promise((coz) => {
    const el = _hedefler[id];
    if (!el || typeof el.measureInWindow !== "function") return coz(null);
    try {
      el.measureInWindow((x, y, w, h) => coz(w > 0 && h > 0 ? { x, y, w, h } : null));
    } catch (e) { coz(null); }
    setTimeout(() => coz(null), 400);
  });
}

// ---------------------------------------------------------------- açma olayı
const _dinleyici = new Set();
const _soruDinleyici = new Set();
let _soruTiklandi = null;
export function turAc(sayfa) {
  // Bir tur bir kez açıldıysa (kendiliğinden ya da "?" ile) kullanıcı "?"in ne olduğunu gördü:
  // etiket ve nokta kalkar.
  if (!_soruTiklandi) {
    _soruTiklandi = true;
    try { AsyncStorage.setItem(ANAHTAR_SORU, "1"); } catch (e) {}
    _soruDinleyici.forEach((f) => f());
  }
  _dinleyici.forEach((f) => f(sayfa));
}
const ANAHTAR_SORU = "ll_tur_soru_tiklandi";
const anahtarSayfa = (s) => "ll_tur_goruldu_" + s;

// Ana sayfa turunu ilk girişte bir kez aç (çağıran: Main, açılış sahnesinden sonra)
export async function ilkTuruAc(sayfa = "ana") {
  try {
    if (await AsyncStorage.getItem(anahtarSayfa(sayfa))) return false;
  } catch (e) { return false; }
  turAc(sayfa);
  return true;
}
export async function turGoruldu(sayfa = "ana") {
  try { return !!(await AsyncStorage.getItem(anahtarSayfa(sayfa))); } catch (e) { return true; }
}

// ---------------------------------------------------------------- "?" düğmesi
export function TurDugmesi({ t, sayfa, etiketli = false }) {
  const [tiklandi, setTiklandi] = useState(_soruTiklandi);
  useEffect(() => {
    let canli = true;
    if (_soruTiklandi === null) {
      AsyncStorage.getItem(ANAHTAR_SORU).then((v) => { _soruTiklandi = v === "1"; if (canli) setTiklandi(_soruTiklandi); })
        .catch(() => { _soruTiklandi = true; if (canli) setTiklandi(true); });
    }
    const f = () => canli && setTiklandi(true);
    _soruDinleyici.add(f);
    return () => { canli = false; _soruDinleyici.delete(f); };
  }, []);
  const bas = () => turAc(sayfa);
  const yeni = tiklandi === false;
  return (
    <View>
      <TouchableOpacity accessibilityRole="button" accessibilityLabel={t.turNasil} hitSlop={TAP.slop} onPress={bas}
        style={{ width: 38, height: 38, borderRadius: R.full, alignItems: "center", justifyContent: "center",
                 backgroundColor: TUR.camZemin, borderWidth: 1, borderColor: TUR.camKenar }}>
        <Text allowFontScaling={false} style={{ color: C.foto.baslik, fontSize: 16, fontWeight: "700" }}>?</Text>
      </TouchableOpacity>
      {yeni && (
        <View pointerEvents="none" style={{ position: "absolute", right: 1, top: 1, width: 9, height: 9, borderRadius: R.full,
                                            backgroundColor: C.amberMikro || C.amber, borderWidth: 2, borderColor: TUR.noktaKenar }} />
      )}
      {yeni && etiketli && (
        /* 30 Ekim — mutlak konumlu balon 38 pt'lik düğmenin genişliğine sıkışıyordu (taşma ölçümü: 61.5 pt gerekiyor, 18 var;
           CI app-ci 20 Ekim'den beri bu yüzden kırmızı). Genişlik içerikten bağımsız sabitlendi. */
        <View pointerEvents="none" style={{ position: "absolute", top: 44, right: -6, width: 124, alignItems: "flex-end", backgroundColor: C.card, borderRadius: R.sm,
                                            paddingHorizontal: ARA[10], paddingVertical: ARA[6], shadowColor: "#000", shadowOpacity: 0.22,
                                            shadowRadius: 8, shadowOffset: { width: 0, height: 4 }, elevation: 6 }}>
          <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.xs, fontWeight: "700" }}>{t.turNasil}</Text>
        </View>
      )}
    </View>
  );
}

// ---------------------------------------------------------------- adımlar
// her adım: { hedef?: id, etk, baslik, metin } · genel adım: { genel: true, etk, baslik, maddeler: [[b, a], ...] }
// son adım isteğe bağlı `eylem: { etiket, git }` taşır (ör. Cüzdan → Planlar).
export function turAdimlari(t, sayfa, rol) {
  const host = rol === "host";
  const T = (k) => t[k] || "";
  switch (sayfa) {
    case "ana": return [
      host
        ? { genel: true, etk: T("turAnaHostEtk"), baslik: T("turAnaHostBas"), maddeler: [[T("turAnaH1b"), T("turAnaH1a")], [T("turAnaH2b"), T("turAnaH2a")], [T("turAnaH3b"), T("turAnaH3a")]] }
        : { genel: true, etk: T("turAnaEtk"), baslik: T("turAnaBas"), maddeler: [[T("turAna1b"), T("turAna1a")], [T("turAna2b"), T("turAna2a")], [T("turAna3b"), T("turAna3a")]] },
      { hedef: "tab_disc", etk: T("turKesfetEtk"), baslik: T("turKesfetBas"), metin: T("turKesfetMet") },
      { hedef: "ana_kredi", etk: T("turKrediEtk"), baslik: T("turKrediBas"), metin: host ? T("turKrediMetHost") : T("turKrediMet") },
      { hedef: "tab_trips", etk: T("turPlanimEtk"), baslik: T("turPlanimBas"), metin: T("turPlanimMet") },
      { hedef: "tab_meet", etk: T("turTanisEtk"), baslik: T("turTanisBas"), metin: T("turTanisMet") },
    ];
    case "kesfet": return [
      { genel: true, etk: T("turKfEtk"), baslik: T("turKfBas"), maddeler: [[T("turKf1b"), T("turKf1a")], [T("turKf2b"), T("turKf2a")], [T("turKf3b"), T("turKf3a")]] },
      { hedef: "kesfet_cipler", etk: T("turKfCipEtk"), baslik: T("turKfCipBas"), metin: T("turKfCipMet") },
      { hedef: "kesfet_uyum", etk: T("turKfUyumEtk"), baslik: T("turKfUyumBas"), metin: T("turKfUyumMet") },
      { hedef: "kesfet_istek", etk: T("turKfIstekEtk"), baslik: T("turKfIstekBas"), metin: T("turKfIstekMet") },
    ];
    case "planim": return host ? [
      { genel: true, etk: T("turPhEtk"), baslik: T("turPhBas"), maddeler: [[T("turPh1b"), T("turPh1a")], [T("turPh2b"), T("turPh2a")], [T("turPh3b"), T("turPh3a")]] },
      { hedef: "planim_sekme", etk: T("turPhSekEtk"), baslik: T("turPhSekBas"), metin: T("turPhSekMet") },
      { hedef: "ilan_ozet", etk: T("turPhOzEtk"), baslik: T("turPhOzBas"), metin: T("turPhOzMet") },
      { hedef: "ilan_ekle", etk: T("turPhEkEtk"), baslik: T("turPhEkBas"), metin: T("turPhEkMet") },
      { hedef: "ilan_basvuru", etk: T("turPhBaEtk"), baslik: T("turPhBaBas"), metin: T("turPhBaMet") },
      { hedef: "seyahat_kart", etk: T("turPmKartEtk"), baslik: T("turPmKartBas"), metin: T("turPmKartMet") },
    ] : [
      { genel: true, etk: T("turPmEtk"), baslik: T("turPmBas"), maddeler: [[T("turPm1b"), T("turPm1a")], [T("turPm2b"), T("turPm2a")], [T("turPm3b"), T("turPm3a")]] },
      { hedef: "seyahat_kart", etk: T("turPmKartEtk"), baslik: T("turPmKartBas"), metin: T("turPmKartMet") },
      { hedef: "seyahat_uyumlu", etk: T("turPmUyEtk"), baslik: T("turPmUyBas"), metin: T("turPmUyMet") },
      { hedef: "seyahat_hostbul", etk: T("turPmHbEtk"), baslik: T("turPmHbBas"), metin: T("turPmHbMet") },
    ];
    case "tanis": return [
      { genel: true, etk: T("turTnEtk"), baslik: T("turTnBas"), maddeler: [[T("turTn1b"), T("turTn1a")], [T("turTn2b"), T("turTn2a")], [T("turTn3b"), T("turTn3a")]] },
      { hedef: "tanis_sekme", etk: T("turTnSekEtk"), baslik: T("turTnSekBas"), metin: T("turTnSekMet") },
      { hedef: "tanis_suzgec", etk: T("turTnSuzEtk"), baslik: T("turTnSuzBas"), metin: T("turTnSuzMet") },
      { hedef: "tanis_kisi", etk: T("turTnKisiEtk"), baslik: T("turTnKisiBas"), metin: T("turTnKisiMet") },
    ];
    case "cuzdan": return [
      { genel: true, etk: T("turCzEtk"), baslik: T("turCzBas"), maddeler: [[T("turCz1b"), T("turCz1a")], [T("turCz2b"), T("turCz2a")], [T("turCz3b"), T("turCz3a")]] },
      { hedef: "cuzdan_bakiye", etk: T("turCzBkEtk"), baslik: T("turCzBkBas"), metin: T("turCzBkMet") },
      { hedef: "cuzdan_paket", etk: T("turCzPkEtk"), baslik: T("turCzPkBas"), metin: T("turCzPkMet") },
      { planlar: true, etk: T("turCzPlEtk"), baslik: T("turCzPlBas"), eylem: { etiket: T("turCzPlGor"), git: "planlar" } },
    ];
    case "kural": return [
      { genel: true, etk: T("turKrEtk"), baslik: T("turKrBas"), maddeler: [[T("turKr1b"), T("turKr1a")], [T("turKr2b"), T("turKr2a")], [T("turKr3b"), T("turKr3a")]] },
      { hedef: "kural_ozet", etk: T("turKrOzEtk"), baslik: T("turKrOzBas"), metin: T("turKrOzMet") },
      { hedef: "kural_sart", etk: T("turKrSaEtk"), baslik: T("turKrSaBas"), metin: T("turKrSaMet") },
      { hedef: "kural_sorun", etk: T("turKrSoEtk"), baslik: T("turKrSoBas"), metin: T("turKrSoMet") },
    ];
    default: return [];
  }
}

// ---------------------------------------------------------------- katman
export function TurKatmani({ t, rol, onGit }) {
  const { width: W, height: H } = useWindowDimensions();
  const az = useAzHareket();
  const [sayfa, setSayfa] = useState(null);
  const [adimlar, setAdimlar] = useState([]);
  const [i, setI] = useState(0);
  const gor = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const ac = async (s) => {
      const ham = turAdimlari(t, s, rol);
      const olculen = [];
      for (const a of ham) {
        if (a.hedef) { const r = await olc(a.hedef); if (r) olculen.push({ ...a, r }); }
        else olculen.push(a);
      }
      if (!olculen.length) return;
      setAdimlar(olculen); setI(0); setSayfa(s);
      try { AsyncStorage.setItem(anahtarSayfa(s), "1"); } catch (e) {}
    };
    _dinleyici.add(ac);
    return () => { _dinleyici.delete(ac); };
  }, [t, rol]);

  useEffect(() => {
    if (!sayfa) return;
    gor.setValue(0);
    Animated.timing(gor, { toValue: 1, duration: az ? 1 : 180, useNativeDriver: true }).start();
    const a = adimlar[i];
    if (a) { try { AccessibilityInfo.announceForAccessibility(`${i + 1}/${adimlar.length}. ${a.baslik}`); } catch (e) {} }
  }, [sayfa, i]);

  if (!sayfa || !adimlar.length) return null;
  const a = adimlar[i];
  const son = i === adimlar.length - 1;
  const kapat = () => { setSayfa(null); setAdimlar([]); };
  const ileri = () => { if (son) kapat(); else setI(i + 1); };

  const ped = 4;
  const r = a.r;
  const ustte = r ? (r.y + r.h / 2 > H * 0.55) : false;
  const kartStil = r
    ? (ustte ? { bottom: H - r.y + ped + 12 } : { top: r.y + r.h + ped + 12 })
    : { top: H * 0.16 };
  const okX = r ? Math.max(ARA[22], Math.min(W - ARA[22] - 14, r.x + r.w / 2 - 7)) - ARA[12] : 0;

  const gosterge = (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }} accessibilityElementsHidden importantForAccessibility="no">
      {adimlar.map((_, k) => (
        <View key={k} style={{ width: k === i ? 14 : 6, height: 6, borderRadius: R.full, backgroundColor: k === i ? C.gold : C.line }} />
      ))}
      <Text style={{ color: C.mut, fontSize: FS.xs, fontWeight: "600", marginLeft: 4 }}>{i + 1}/{adimlar.length}</Text>
    </View>
  );
  const altSatir = (
    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: ARA[12] }}>
      {gosterge}
      <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[12] }}>
        {!son && (
          <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={kapat}>
            <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.turGec}</Text>
          </TouchableOpacity>
        )}
        {son && a.eylem && (
          <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={kapat}>
            <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.turAnladim}</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop}
          onPress={() => { if (son && a.eylem) { kapat(); onGit && onGit(a.eylem.git); } else ileri(); }}
          style={{ backgroundColor: C.goldBtn || C.gold, borderRadius: R.full, paddingHorizontal: ARA[14], paddingVertical: ARA[8] }}>
          <Text style={{ color: C.onGold || C.ink, fontWeight: "700", fontSize: FS.sm }}>
            {son ? (a.eylem ? a.eylem.etiket : t.turAnladim) : t.turDevam}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const kart = { position: "absolute", left: ARA[12], right: ARA[12], backgroundColor: C.card, borderRadius: R.lg,
                 padding: ARA[14], shadowColor: "#000", shadowOpacity: 0.3, shadowRadius: 16, shadowOffset: { width: 0, height: 8 }, elevation: 12 };
  const etk = <Text style={{ color: C.goldText, fontSize: FS.micro, fontWeight: "700", letterSpacing: 1.6 }}>{a.etk}</Text>;
  const bas = (b) => <Text style={{ fontFamily: F.serifGosterim, fontSize: 21, color: C.ink, marginTop: ARA[2], marginBottom: ARA[6] }}>{b}</Text>;

  return (
    <Modal visible transparent animationType="none" onRequestClose={kapat} statusBarTranslucent>
      <Animated.View style={{ flex: 1, opacity: gor }}>
        <Pressable accessibilityRole="button" accessibilityLabel={t.turGec} onPress={kapat}
          style={{ position: "absolute", left: 0, top: 0, width: W, height: H, backgroundColor: TUR.karartma }} />
        {r && (
          <View pointerEvents="none" style={{ position: "absolute", left: r.x - ped, top: r.y - ped, width: r.w + ped * 2, height: r.h + ped * 2,
                                              borderRadius: Math.min(R.lg, (r.h + ped * 2) / 2), borderWidth: 2, borderColor: TUR.halka }} />
        )}
        <View style={[kart, kartStil]} accessibilityViewIsModal>
          {r && (
            <View pointerEvents="none" style={{ position: "absolute", left: okX, width: 14, height: 14, backgroundColor: C.card,
                                                transform: [{ rotate: "45deg" }], ...(ustte ? { bottom: -7 } : { top: -7 }) }} />
          )}
          {etk}
          {bas(a.baslik)}
          {a.genel ? (
            a.maddeler.map(([b, m], k) => (
              <View key={k} style={{ flexDirection: "row", gap: ARA[10], paddingVertical: ARA[8], borderTopWidth: k ? 1 : 0, borderColor: C.line }}>
                <View style={{ width: 22, height: 22, borderRadius: R.full, borderWidth: 1.5, borderColor: C.line, alignItems: "center", justifyContent: "center" }}>
                  <Text style={{ color: C.body, fontSize: FS.xs, fontWeight: "700" }}>{k + 1}</Text>
                </View>
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{b}</Text>
                  <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 16, marginTop: ARA[2] }}>{m}</Text>
                </View>
              </View>
            ))
          ) : a.planlar ? (
            [[t.turPlYolcuAd, t.turPlYolcuFiyat, t.turPlYolcu], [t.turPlSikAd, t.turPlSikFiyat, t.turPlSik], [t.turPlKahyaAd, t.turPlKahyaFiyat, t.turPlKahya]].map(([ad, fiyat, alt], k) => (
              <View key={ad} style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: ARA[6],
                                      borderRadius: R.sm, padding: ARA[10], borderWidth: k === 1 ? 1.5 : 1, borderColor: k === 1 ? C.gold : C.line }}>
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{ad}</Text>
                  <Text style={{ color: C.mut, fontSize: FS.xs }}>{alt}</Text>
                </View>
                <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{fiyat}</Text>
              </View>
            )).concat([<Text key="not" style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[8] }}>{t.planNoRollover}</Text>])
          ) : (
            <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 19 }}>{a.metin}</Text>
          )}
          {altSatir}
        </View>
      </Animated.View>
    </Modal>
  );
}
