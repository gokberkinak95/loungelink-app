// ============================================================
// ÖDÜL MAĞAZASI · erken erişim · plana göre indirim · vitrin  (6.9.0 · SQL 338)
//
// Gökberk (20 Ekim): "indirimli puanı çektiğinden emin ol. 2700 gösterip 3000 çekmesin."
//   → Ekrandaki her sayı SUNUCUDAN (odul_magazasi): `fiyat` kullanıcının kendi fiyatı,
//     `plan_fiyatlari` ücretli planların fiyatı, `erken`/`alabilir`/`vitrin` durumları.
//     Uygulama hiçbir fiyatı hesaplamaz; alırken gösterdiği fiyatı `p_beklenen` olarak yollar,
//     sunucu farklı hesaplarsa 'odul_fiyati_degisti' döner (sessizce başka puan düşmez).
//   → Saat sunucudan: `simdi` ile cihaz saati arasındaki fark sayaçta düzeltilir.
//   → İndirim oranı 0/boşsa sunucu `plan_fiyatlari`nı boş, `fiyat`ı liste fiyatı döner:
//     şerit, üstü çizili fiyat ve "Jetset'te …" satırı kendiliğinden çıkmaz.
// ============================================================
import { useEffect, useRef, useState } from "react";
import { Animated, Text, View } from "react-native";
import { ARA, C, F, FS, R, SP, ODUL } from "./theme";
import { MONO } from "./typography";
import { GeceKarti } from "./hareket";
import { Ikon } from "./ikon";
import { Btn } from "./ui";

// ---- Türkçe ekler (plan adları sunucudan gelir; ek sesli uyuma göre) ----
const KALIN = "aıou", INCE = "eiöü", SERT = "fstkçşhp";
function sonSesli(s) { for (let i = s.length - 1; i >= 0; i--) { const c = s[i].toLocaleLowerCase("tr"); if ((KALIN + INCE).includes(c)) return c; } return "e"; }
export function bulunmaEki(ad) {            // Jetset → Jetset'te · Sık Uçan → Sık Uçan'da
  const son = String(ad).slice(-1).toLocaleLowerCase("tr");
  const d = SERT.includes(son) ? "t" : "d";
  return `${ad}'${d}${KALIN.includes(sonSesli(ad)) ? "a" : "e"}`;
}
export function yonelmeEki(ad) {            // Jetset → Jetset'e · Sık Uçan → Sık Uçan'a
  const son = String(ad).slice(-1).toLocaleLowerCase("tr");
  const kalin = KALIN.includes(sonSesli(ad));
  const ses = (KALIN + INCE).includes(son);
  return `${ad}'${ses ? "y" : ""}${kalin ? "a" : "e"}`;
}
const planAdi = (p, en) => (en ? (p.ad_en || p.ad) : p.ad) || p.plan;
const sayi = (n, en) => Number(n || 0).toLocaleString(en ? "en-US" : "tr-TR");

// "Sık Uçan ve Jetset" (TR) · "Frequent Flyer and Jetset" (EN)
function liste(adlar, en) {
  if (adlar.length <= 1) return adlar[0] || "";
  return adlar.slice(0, -1).join(", ") + (en ? " and " : " ve ") + adlar[adlar.length - 1];
}

// ---- metinler ----
export function bantMetni(t, m, en) {
  if (!m) return null;
  if (m.ucretli && m.benim_yuzde > 0) {
    const ben = (m.indirimli_planlar || []).find(p => p.plan === m.plan);
    return String(t.odulBantBenim).replace("{plan}", ben ? planAdi(ben, en) : "").replace("{n}", String(m.benim_yuzde));
  }
  if (!m.ucretli && (m.indirimli_planlar || []).length) {
    const parca = m.indirimli_planlar.map(p => en ? `${p.yuzde}% off on ${planAdi(p, en)}` : `${bulunmaEki(planAdi(p, en))} %${p.yuzde}`);
    return String(t.odulBantDiger).replace("{liste}", parca.join(", "));
  }
  return null;
}
export function erkenRozeti(t, m, rw, en) {
  if (rw.alabilir) return t.odulErken;
  const adlar = (m?.ucretli_planlar || []).map(p => planAdi(p, en));
  if (!adlar.length) return t.odulErken;
  if (en) return String(t.odulErkenPlanlara).replace("{liste}", liste(adlar, true));
  const l = liste(adlar, false);
  const son = adlar[adlar.length - 1];
  return String(t.odulErkenPlanlara).replace("{liste}", l.slice(0, l.length - son.length) + yonelmeEki(son));
}
// Yolcu'nun kartındaki alt satır: en iyi (en düşük) plan fiyatı ya da hepsi
function enIyiPlan(rw) {
  const l = (rw.plan_fiyatlari || []).filter(p => p.fiyat < rw.cost_points);
  return l.length ? l.reduce((a, b) => (b.fiyat < a.fiyat ? b : a)) : null;
}
export function planFiyatSatiri(rw, en, hepsi) {
  const l = (rw.plan_fiyatlari || []).filter(p => p.fiyat < rw.cost_points);
  if (!l.length) return null;
  if (hepsi) return l.map(p => `${planAdi(p, en)} ${sayi(p.fiyat, en)}`).join(" · ");
  const b = enIyiPlan(rw);
  return en ? `${sayi(b.fiyat, true)} on ${planAdi(b, true)}` : `${bulunmaEki(planAdi(b, false))} ${sayi(b.fiyat, false)}`;
}

// ---- sayaç: sunucu saatine göre; 0'a varınca bir kez onBitti ----
export function kalanYazi(ms, t) {
  const s = Math.max(0, Math.floor(ms / 1000));
  const g = Math.floor(s / 86400), sa = Math.floor((s % 86400) / 3600), dk = Math.floor((s % 3600) / 60), sn = s % 60;
  const iki = (n) => String(n).padStart(2, "0");
  return { bas: `${g > 0 ? String(t.odulGun).replace("{n}", String(g)) + " " : ""}${iki(sa)}:${iki(dk)}`, sn: `:${iki(sn)}` };
}
export function useGeriSayim(bitisIso, fark, onBitti) {
  const [simdi, setSimdi] = useState(() => Date.now() + (fark || 0));
  const bitti = useRef(false);
  useEffect(() => {
    bitti.current = false;
    if (!bitisIso) return undefined;
    const id = setInterval(() => {
      const n = Date.now() + (fark || 0);
      setSimdi(n);
      if (!bitti.current && n >= new Date(bitisIso).getTime()) { bitti.current = true; onBitti && onBitti(); }
    }, 1000);
    return () => clearInterval(id);
  }, [bitisIso, fark]);
  return bitisIso ? Math.max(0, new Date(bitisIso).getTime() - simdi) : 0;
}

function NefesSaniye({ metin, stil }) {
  const a = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    const d = Animated.loop(Animated.sequence([
      Animated.timing(a, { toValue: 0.35, duration: 1000, useNativeDriver: true }),
      Animated.timing(a, { toValue: 1, duration: 1000, useNativeDriver: true }),
    ]));
    d.start(); return () => d.stop();
  }, [a]);
  return <Animated.Text style={[stil, { opacity: a }]}>{metin}</Animated.Text>;
}

// ---- vitrin kartı (gece kartı) ----
export function VitrinKarti({ t, m, rw, en, fark, sahip, bakiye, mesgul, onAl, onPlanlar, onYenile }) {
  const kalan = useGeriSayim(rw.erken && !rw.alabilir ? rw.erken_bitis : null, fark, onYenile);
  const indirimli = rw.fiyat < rw.cost_points;
  const yetmez = bakiye < rw.fiyat;
  const altSatir = !m?.ucretli ? planFiyatSatiri(rw, en, true) : null;
  const k = rw.erken && !rw.alabilir ? kalanYazi(kalan, t) : null;
  return (
    <GeceKarti stil={{ marginBottom: SP[4] }}>
      <View style={{ paddingHorizontal: ARA[4] }}>
        <Text style={{ fontSize: FS.micro, letterSpacing: 2, color: C.foto.dugum }}>{t.odulYeni}</Text>
        {rw.erken && (
          <View style={{ alignSelf: "flex-start", maxWidth: "100%", flexDirection: "row", alignItems: "center",
                         borderWidth: 1, borderColor: ODUL.rozetCizgi, borderRadius: R.md,
                         paddingVertical: ARA[4], paddingHorizontal: ARA[10], marginTop: ARA[10], marginBottom: ARA[4] }}>
            <Ikon ad={rw.alabilir ? "yildizParlak" : "saat"} boy={12} renk={C.foto.bag} stil={{ marginRight: ARA[6] }} />
            <Text style={{ flexShrink: 1, fontSize: FS.micro + 0.5, lineHeight: Math.round((FS.micro + 0.5) * 1.35), color: C.foto.bag }}>
              {erkenRozeti(t, m, rw, en)}</Text>
          </View>
        )}
        <Text style={{ fontFamily: F.serifGosterim, fontSize: FS.title + 2, color: C.foto.marka, marginTop: ARA[10] }}>{rw.title}</Text>
        {!!rw.subtitle && <Text style={{ fontSize: FS.sm, color: C.gokMavi, marginTop: ARA[2] }}>{rw.subtitle}</Text>}
        {!!rw.featured_note && <Text style={{ fontSize: FS.sm, color: C.foto.dugum, marginTop: ARA[4] }}>{rw.featured_note}</Text>}
        {k && (
          <View style={{ flexDirection: "row", alignItems: "baseline", marginTop: ARA[8] }}>
            <Text style={{ fontFamily: MONO[500], fontSize: FS.sm, color: C.foto.bag }}>
              {String(t.odulSanaAcilis).replace("{sure}", k.bas)}</Text>
            <NefesSaniye metin={k.sn} stil={{ fontFamily: MONO[500], fontSize: FS.sm, color: C.foto.dugum }} />
          </View>
        )}
        <View style={{ flexDirection: "row", alignItems: "flex-end", marginTop: ARA[14] }}>
          <View style={{ flex: 1, minWidth: 0, marginRight: ARA[10] }}>
            <View style={{ flexDirection: "row", alignItems: "baseline", flexWrap: "wrap" }}>
              {indirimli && <Text style={{ fontFamily: MONO[500], fontSize: FS.sm, color: C.gokMavi, textDecorationLine: "line-through", marginRight: ARA[6] }}>{sayi(rw.cost_points, en)}</Text>}
              <Text style={{ fontFamily: MONO[600], fontSize: FS.lg, color: C.foto.dugum }}>{sayi(rw.fiyat, en)} {t.points}</Text>
            </View>
            {!!altSatir && <Text style={{ fontSize: FS.micro + 0.5, color: C.gokMavi, marginTop: ARA[2] }}>{altSatir}</Text>}
          </View>
          {!rw.alabilir ? (
            <Btn v="ust" sm label={t.odulPlanlariGor} onPress={onPlanlar} style={{ flexShrink: 0 }} />
          ) : sahip ? (
            <Text style={{ flexShrink: 0, fontSize: FS.sm, color: C.foto.bag }}>{t.shopOwned || t.redeemed}</Text>
          ) : (
            <Btn v={yetmez ? "ust" : "gold"} sm disabled={yetmez || mesgul} busy={mesgul} onPress={onAl}
              label={yetmez ? (t.shopShort || t.notEnoughPoints) : (t.shopRedeem || t.redeem)} style={{ flexShrink: 0 }} />
          )}
        </View>
      </View>
    </GeceKarti>
  );
}

// ---- liste kartının erken erişim + fiyat parçaları (kartın kendisi Marketplace'te) ----
export function MiniErken({ t, rw, fark, onYenile }) {
  const kalan = useGeriSayim(rw.erken && !rw.alabilir ? rw.erken_bitis : null, fark, onYenile);
  if (!rw.erken) return null;
  return (
    <View style={{ marginBottom: ARA[6] }}>
      <View style={{ alignSelf: "flex-start", maxWidth: "100%", backgroundColor: C.goldBg, borderRadius: R.sm,
                     paddingVertical: ARA[2], paddingHorizontal: ARA[8] }}>
        <Text style={{ fontSize: FS.micro, color: C.goldText }}>{t.odulErken}</Text>
      </View>
      {!rw.alabilir && (
        <Text style={{ fontFamily: MONO[500], fontSize: FS.micro, color: C.goldText, marginTop: ARA[4] }}>
          {String(t.odulSanaKisa).replace("{sure}", kalanYazi(kalan, t).bas)}</Text>
      )}
    </View>
  );
}
export function MiniFiyat({ t, m, rw, en }) {
  const indirimli = rw.fiyat < rw.cost_points;
  const alt = !m?.ucretli ? planFiyatSatiri(rw, en, false) : null;
  return (
    <View style={{ flexShrink: 1, minWidth: 0 }}>
      <View style={{ flexDirection: "row", alignItems: "baseline", flexWrap: "wrap" }}>
        {indirimli && <Text style={{ fontFamily: MONO[500], fontSize: FS.micro, color: C.dim, textDecorationLine: "line-through", marginRight: ARA[4] }}>{sayi(rw.cost_points, en)}</Text>}
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.gold }}>{sayi(rw.fiyat, en)} {t.points}</Text>
      </View>
      {!!alt && <Text style={{ fontSize: FS.micro, color: C.mut, marginTop: ARA[2] }}>{alt}</Text>}
    </View>
  );
}

export function IndirimBandi({ metin, benim }) {
  if (!metin) return null;
  return (
    <View style={{ flexDirection: "row", alignItems: "flex-start", backgroundColor: C.bgAlt, borderRadius: R.md,
                   paddingVertical: ARA[8], paddingHorizontal: ARA[12], marginBottom: SP[3] }}>
      <Ikon ad={benim ? "tamam" : "puan"} boy={14} renk={C.goldText} stil={{ marginRight: ARA[8], marginTop: 1 }} />
      <Text style={{ flex: 1, minWidth: 0, fontSize: FS.xs, lineHeight: Math.round(FS.xs * 1.45), color: C.body }}>{metin}</Text>
    </View>
  );
}
