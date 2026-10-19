// ============================================================
// serit.js — 19 Ekim · UYGULAMA İÇİ BİLDİRİM ŞERİDİ (Gökberk onayı: önizleme v9)
//
// Uygulama açıkken gelen mesaj, onay ve hatırlatmalar üstten ince bir kartla görünür.
// · 4 saniye sonra kendiliğinden çekilir; parmak üstündeyken bekler; yukarı itince kapanır.
// · Dokununca ilgili ekran açılır (hedefi sunucu söyler: bildirim_hedefi · aynı tablo
//   telefon bildirimi ve bildirim listesiyle ortak). Hedefsiz bildirim Bildirimler'i açar.
// · Kart görünürken yenisi gelirse tek kartta toplanır ("3 yeni bildirim").
// · Kullanıcı o sohbetin içindeyse o sohbetin mesajı için kart çıkmaz.
// · Uygulama açıkken telefonun kendi bildirim şeridi gösterilmez (push.js) — çift bildirim yok.
// ============================================================
import React, { useEffect, useRef, useState } from "react";
import { Animated, Easing, PanResponder, Text, TouchableOpacity, View } from "react-native";
import { ARA, C, F, FS, R, TAP } from "./theme";
import { TOPPAD } from "./ui";
import { Ikon } from "./ikon";
import { dokun, useAzHareket } from "./hareket";

const _dinleyici = new Set();
const _gorulen = new Set();
export function seritGoster(b) {
  if (!b || !b.id || _gorulen.has(b.id)) return;
  _gorulen.add(b.id);
  _dinleyici.forEach((f) => f(b));
}
globalThis.__LL_SERIT_AKTIF = false;   // push.js okur: true iken telefonun kendi şeridi gösterilmez

// b: { id, baslik, metin, tur: "mesaj" | "onay" | "hatirlatma" | "genel", kisi?: string }
export function BildirimSeridi({ t, onAc, onToplu }) {
  const az = useAzHareket();
  const [kart, setKart] = useState(null);      // { ilk, sayi, ids }
  const y = useRef(new Animated.Value(-140)).current;
  const zaman = useRef(null);
  const bekle = useRef(false);

  useEffect(() => {
    globalThis.__LL_SERIT_AKTIF = true;
    const f = (b) => {
      setKart((k) => (k ? { ilk: k.ilk, sayi: k.sayi + 1, ids: [...k.ids, b.id] } : { ilk: b, sayi: 1, ids: [b.id] }));
      if (b.tur === "mesaj" || b.tur === "onay") { try { dokun("hafif"); } catch (e) {} }
    };
    _dinleyici.add(f);
    return () => { _dinleyici.delete(f); globalThis.__LL_SERIT_AKTIF = false; };
  }, []);

  const kapat = () => {
    if (zaman.current) clearTimeout(zaman.current);
    Animated.timing(y, { toValue: -140, duration: az ? 1 : 200, easing: Easing.in(Easing.quad), useNativeDriver: true })
      .start(() => setKart(null));
  };
  const kur = () => {
    if (zaman.current) clearTimeout(zaman.current);
    if (globalThis.__SERIT_SAHNE) return;   // yalnız web sahne çekimi: kart çekim için açık kalır
    zaman.current = setTimeout(() => { if (!bekle.current) kapat(); }, 4000);
  };

  useEffect(() => {
    if (!kart) return;
    Animated.timing(y, { toValue: 0, duration: az ? 1 : 260, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    kur();
  }, [kart]);

  const pan = useRef(PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dy) > 6,
    onPanResponderGrant: () => { bekle.current = true; },
    onPanResponderMove: (_, g) => { if (g.dy < 0) y.setValue(g.dy); },
    onPanResponderRelease: (_, g) => {
      bekle.current = false;
      if (g.dy < -24) kapat();
      else { Animated.spring(y, { toValue: 0, useNativeDriver: true }).start(); kur(); }
    },
  })).current;

  if (!kart) return null;
  const b = kart.ilk;
  const toplu = kart.sayi > 1;
  const ikon = toplu ? { zemin: C.goldSoft, ic: <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm }}>{kart.sayi}</Text> }
    : b.tur === "mesaj" ? { zemin: C.warmBlock2, ic: <Text style={{ fontFamily: F.serifGosterim, color: C.ink, fontSize: 15 }}>{String(b.kisi || b.baslik || "?").trim().charAt(0).toLocaleUpperCase("tr-TR")}</Text> }
    : b.tur === "onay" ? { zemin: C.greenBg, ic: <Ikon ad="tamam" boy={15} renk={C.greenInk || C.green} /> }
    : b.tur === "hatirlatma" ? { zemin: C.amberBg, ic: <Ikon ad="saat" boy={15} renk={C.amberInk} /> }
    : { zemin: C.goldSoft, ic: <Ikon ad="bildirim" boy={15} renk={C.goldText} /> };
  const baslik = toplu ? String(t.seritYeni).replace("{n}", String(kart.sayi)) : b.baslik;
  const metin = toplu ? b.baslik : b.metin;

  return (
    <Animated.View {...pan.panHandlers} accessibilityLiveRegion="polite"
      style={{ position: "absolute", left: ARA[10], right: ARA[10], top: TOPPAD + ARA[6], zIndex: 120, elevation: 20,
               transform: [{ translateY: y }] }}>
      <TouchableOpacity activeOpacity={0.9} hitSlop={TAP.slop} accessibilityRole="button" accessibilityLabel={`${baslik}. ${metin || ""}`}
        onPressIn={() => { bekle.current = true; }} onPressOut={() => { bekle.current = false; kur(); }}
        onPress={() => { const k = kart; kapat(); if (k.sayi > 1) onToplu && onToplu(); else onAc && onAc(k.ilk); }}
        style={{ flexDirection: "row", alignItems: "center", gap: ARA[10], backgroundColor: C.card, borderRadius: R.lg,
                 paddingVertical: ARA[8], paddingHorizontal: ARA[12], shadowColor: "#000", shadowOpacity: 0.22,
                 shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, borderWidth: 1, borderColor: C.line }}>
        <View style={{ width: 30, height: 30, borderRadius: R.full, backgroundColor: ikon.zemin, alignItems: "center", justifyContent: "center" }}>
          {ikon.ic}
        </View>
        <View style={{ flex: 1, minWidth: 0 }}>
          <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{baslik}</Text>
          {!!metin && <Text numberOfLines={1} style={{ color: C.body, fontSize: FS.xs, marginTop: 1 }}>{metin}</Text>}
        </View>
        <TouchableOpacity accessibilityRole="button" accessibilityLabel={t.seritKapat} hitSlop={TAP.slop} onPress={kapat}>
          <Ikon ad="kapat" boy={13} renk={C.mut} />
        </TouchableOpacity>
      </TouchableOpacity>
    </Animated.View>
  );
}
