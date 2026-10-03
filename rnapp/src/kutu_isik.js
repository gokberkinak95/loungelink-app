// ══════════════════════════════════════════════════════════════════════
// v7.2 · IŞIKLI BİLGİ KUTUSU (3 Ekim · Gökberk: "info alanı arka planla neredeyse aynı
// tonda — çevresine gölge mi eklesek? Uygun görürsen diğer info / uyarı alanlarında da uygula")
//
// Uygulamada 107 bilgi/uyarı kutusu var; zeminleri anlamsal tintler (amberBg, tealBg,
// greenBg, goldSoft, goldBg, hataBg, redBg, tealTint…). Fildişi tuvalde (#F9F8F6) bu
// tintler zeminle neredeyse aynı tonda. Tek tek düzenlense biri mutlaka unutulurdu —
// `sansUygula` / `isikliGiris` ile AYNI karar: kural kabukta, bir kez.
//
// Kural (yalnız v7): zemini bu tintlerden biri OLAN, köşesi ≥10 ve iç payı ≥10 olan
// bir View → lacivert ortam gölgesi (%7 · 18pt) + üst kenarda 1px ışık.
// Hariç: genişliği sabit olanlar (ikon daireleri), küçük rozetler (pay < 10).
// Android: tintler OPAK → elevation güvenli (yarı saydam yüzey sorunu burada yok).
// ══════════════════════════════════════════════════════════════════════
import { View, Platform } from "react-native";
import { C, temaModu } from "./theme";

let _anahtar = null, _tintler = null;
function tintler() {
  if (_anahtar === C.amberBg && _tintler) return _tintler;
  _anahtar = C.amberBg;
  _tintler = new Set([C.amberBg, C.tealBg, C.tealTint, C.tealTint2, C.greenBg, C.goldSoft,
                      C.goldBg, C.hataBg, C.redBg].filter(Boolean));
  return _tintler;
}

// Sığ birleştirme: StyleSheet.flatten'dan ucuz; yalnız bakacağımız anahtarları toplar.
function topla(st, o) {
  if (!st) return o;
  if (Array.isArray(st)) { for (let i = 0; i < st.length; i++) topla(st[i], o); return o; }
  if (typeof st !== "object") return o;
  for (const k of ["backgroundColor", "borderRadius", "padding", "paddingVertical",
                   "paddingHorizontal", "paddingTop", "width", "shadowOpacity", "borderWidth", "borderColor"]) {
    if (st[k] !== undefined) o[k] = st[k];
  }
  return o;
}

const ISIK = Platform.OS === "android"
  ? { elevation: 2, borderTopWidth: 1, borderTopColor: "rgba(255,255,255,0.9)" }
  : { shadowColor: "#0D1B2A", shadowOpacity: 0.07, shadowRadius: 18, shadowOffset: { width: 0, height: 6 },
      borderTopWidth: 1, borderTopColor: "rgba(255,255,255,0.9)" };

// 4 Ekim (Gökberk: "plan sayfasında seçili planın çerçevesinin üstü yok") — üst ışık kenarı,
// BİLİNÇLİ çerçevesi olan kutunun üst çizgisini eziyordu. Çerçeveli kutu yalnız gölge alır.
const GOLGE = Platform.OS === "android" ? { elevation: 2 }
  : { shadowColor: "#0D1B2A", shadowOpacity: 0.07, shadowRadius: 18, shadowOffset: { width: 0, height: 6 } };
function isikliMi(style) {
  const o = topla(style, {});
  if (!o.backgroundColor || !tintler().has(o.backgroundColor)) return null;
  if (o.width !== undefined) return null;
  if (o.shadowOpacity !== undefined) return null;   // kendi gölgesini seçmiş
  if (!(o.borderRadius >= 10)) return null;
  const pay = Math.max(o.padding || 0, o.paddingVertical || 0, o.paddingHorizontal || 0, o.paddingTop || 0);
  if (pay < 10) return null;
  const cerceveli = (o.borderWidth || 0) > 0 && o.borderColor && o.borderColor !== "transparent"
                    && !/rgba\([^)]*,\s*0\)$/.test(String(o.borderColor));
  return cerceveli ? GOLGE : ISIK;
}

export function bilgiKutusuUygula() {
  const B = View;
  if (!B || typeof B.render !== "function" || B.__llKutu) return false;
  const eski = B.render;
  B.__llKutu = true;
  B.render = function (props, ...rest) {
    const ek = props && props.style && temaModu() === "v7" ? isikliMi(props.style) : null;
    if (ek) return eski.call(this, { ...props, style: [props.style, ek] }, ...rest);
    return eski.call(this, props, ...rest);
  };
  return true;
}
