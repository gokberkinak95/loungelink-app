// ============================================================
// LoungeLink · src/typography.js  (v2.73)
//
// SANS-SERIF ARTIK BİZİM — sistem varsayılanı değil
//
// 🔴 SORUN NEYDİ: `theme.js` içinde `sans: undefined` yazıyordu. Bunun
// anlamı şu: iOS'ta SF Pro, Android'de Roboto. Yani uygulama iki
// platformda İKİ FARKLI RİTİMDE okunuyordu ve ikisi de sistem
// varsayılanıydı — yani hiçbir karakteri yoktu. Bir ürünün gövde
// yazısı, o ürünün sesidir; ödünç bir sesle konuşuyorduk.
//
// SEÇİM: Archivo (SIL OFL, Omnibus-Type). Gerekçe biçimsel değil
// İŞLEVSEL: bu uygulama saat, tarih, uçuş numarası, kalan gün, slot
// sayısı dolu bir uygulama. Archivo'nun rakamları hem dar hem net —
// havalimanı tabelası soyundan gelir. Yüksek kontrastlı Cormorant
// Garamond (başlıklar) ile düşük kontrastlı bir grotesk (gövde)
// klasik bir editoryal eşleşmedir.
//
// TÜRKÇE KONTROLÜ ÖNCE YAPILDI, sonra gömüldü:
//   ğ Ğ ş Ş ı İ ç Ç ö Ö ü Ü â î û  → dört ağırlıkta da EKSİK YOK
// Bir fontu kontrol etmeden gömmek, Türkçe bir üründe kutuları
// tofu'ya çevirmenin en kısa yoludur.
//
// ============================================================
// 🔴 REACT NATIVE TUZAĞI — BU DOSYANIN ASIL VAR OLMA SEBEBİ
// ============================================================
// RN, ÖZEL fontlarda ağırlık SENTEZLEMEZ. Yani:
//     fontFamily: "Archivo-Regular", fontWeight: "700"
// Android'de KALIN GÖRÜNMEZ — sessizce normal kalır.
//
// Uygulamada 300'den fazla yerde `fontWeight: "600"/"700"` var ve
// hiçbirinde `fontFamily` yok (bugüne kadar sistem fontu kullanıldığı
// için ağırlıklar kendiliğinden çalışıyordu). O 300 satırı tek tek
// düzenlemek hem imkânsız hem de yeni yazılan her satırda tekrar
// unutulacak bir iş.
//
// Bu yüzden eşleme TEK YERDE ve OTOMATİK: `Text` ve `TextInput`
// render'ları bir kez sarmalanıyor, çözülmüş `fontWeight` okunuyor ve
// doğru Archivo ailesi enjekte ediliyor.
//
// ⚠️ AÇIKÇA `fontFamily` YAZAN HİÇBİR STİLE DOKUNULMAZ. Serif
// başlıklar (F.serif) olduğu gibi kalır — kural: "elle seçilmiş olan
// her zaman kazanır".
//
// ⚠️ Dosya adları PostScript adlarıyla BİREBİR aynı tutuldu
// (`Archivo-SemiBold.ttf` ↔ `Archivo-SemiBold`). Sebep: iOS ailesini
// PostScript adından, Android dosya adından çözüyor. İkisi ayrışırsa
// font bir platformda sessizce düşer ve bunu ancak cihazda görürsün.
// ============================================================
import React, { useState } from "react";
import { Text, TextInput, StyleSheet } from "react-native";

// 🔴 30 AĞUSTOS — GECE SİSTEMİ: GÖVDE AİLESİ PLUS JAKARTA SANS.
// Bu tablo uygulamadaki HER `<Text>`in ailesini belirliyor (aşağıdaki
// `sansUygula` render'ı sarmalıyor). Tek yerden değişiyor — 40 ekranda
// tek tek `fontFamily` aramak gerekmedi.
//
// ⚠️ `theme.js`teki `F.sans*` ile AYNI değerleri taşımalı. İki yerde iki
// farklı aile, uygulamanın yarısını başka fontla çizer.
export const SANS = {
  400: "PlusJakartaSans-Regular",
  500: "PlusJakartaSans-Medium",
  600: "PlusJakartaSans-SemiBold",
  700: "PlusJakartaSans-Bold",
};

// 🔴 SAYILAR İÇİN AYRI AİLE — ve bu estetik değil MEKANİK bir karar.
// Geri sayım (`02:41:08`), uyum yüzdesi, kredi, saat. Orantılı bir fontta
// rakamların genişliği farklıdır: `1` dar, `0` geniş. Saniyede bir
// değişen bir sayaç bu yüzden her tik'te SATIRI KAYDIRIR.
//
// Kullanımı: `style={{ fontFamily: MONO[500] }}` — `sansUygula` elle
// seçilmiş aileye dokunmuyor (yukarıdaki `if (d.fontFamily) return el`).
//
// 🆕 SINIF: "DEĞİŞEN BİR SAYIYI ORANTILI BİR FONTLA ÇİZERSEN, SAYIYI
// DEĞİL SATIRI ANİMASYONA ALIRSIN."
export const MONO = {
  500: "JetBrainsMono-Medium",
  600: "JetBrainsMono-SemiBold",
};

// Ağırlık → aile. Ara değerler en yakın GÖMÜLÜ ağırlığa yuvarlanır;
// olmayan bir ağırlığı istemek, RN'de sessiz bir geri düşüştür.
export function sansFor(weight) {
  const w = weight === "bold" ? 700
          : weight === "normal" ? 400
          : weight == null ? 400
          : parseInt(weight, 10);
  if (!Number.isFinite(w)) return SANS[400];
  if (w >= 700) return SANS[700];
  if (w >= 600) return SANS[600];
  if (w >= 500) return SANS[500];
  return SANS[400];
}

let _uygulandi = false;

export function sansUygula() {
  if (_uygulandi) return;
  _uygulandi = true;

  const yama = (Bilesen, ad) => {
    // 🔴 SAVUNMA: RN sürümleri arasında `Text.render` her zaman
    // bulunmayabilir (forwardRef iç yapısı değişebilir). Bulunamazsa
    // SESSİZCE geçiyoruz — uygulama sistem fontuyla açılır, çöker
    // değil. Tipografi bir zenginleştirmedir; açılış kapısı değil.
    if (!Bilesen || typeof Bilesen.render !== "function") return false;
    if (Bilesen.__llSans) return true;
    const eski = Bilesen.render;
    Bilesen.__llSans = true;
    // 🔴 3 EYLÜL — YAMA ARTIK RENDER'DAN ÖNCE, PROPS ÜZERİNDE.
    // Eski hâli render SONUCUNU klonluyordu. Cihazda çalışıyordu ama
    // web sahnesinde (react-native-web) render çıktısı zaten bir DOM
    // öğesi olduğu için stil dizisi yutuluyor ve gövde Arial çıkıyordu;
    // yani sahne cihazı yansıtmıyordu. Props'u render'a girmeden
    // düzeltmek iki platformda da aynı sonucu verir — ve daha ucuz:
    // her Text için bir `cloneElement` daha yapılmıyor.
    Bilesen.render = function (props, ...rest) {
      const d = StyleSheet.flatten(props && props.style) || {};
      // Elle seçilmiş font (serif başlıklar) DOKUNULMAZ.
      if (d.fontFamily) return eski.call(this, props, ...rest);
      const yeni = { ...props, style: [{ fontFamily: sansFor(d.fontWeight) }, props.style] };
      return eski.call(this, yeni, ...rest);
    };
    return true;
  };

  const a = yama(Text, "Text");
  const b = yama(TextInput, "TextInput");
  isikliGiris(TextInput);
  return a || b;
}


// ══════════════════════════════════════════════════════════════════════
// v6.0.0 · IŞIKLI GİRİŞ — çizgisiz alan, odakta fildişi parıltı
// Giriş alanlarının kenar çizgisi kalktı (v6 katmanı `C.line` şeffaf).
// Alanın "şu an yazıyorsun" hâlini çizgi değil IŞIK söylüyor: odaklanınca
// arkasından fildişi bir hale (gölge %14, 18pt yarıçap) ve zemin bir tık
// aydınlanıyor. 50+ ekrandaki her `TextInput` bunu kendiliğinden alır —
// tek tek çağrı yerine yazılsaydı biri mutlaka unutulurdu.
// Hook kullanımı güvenli: yamalanan `render`, TextInput'un KENDİ forwardRef
// bileşeninin çizimi içinde çağrılıyor; sıra her çizimde aynı.
// ══════════════════════════════════════════════════════════════════════
function isikliGiris(Bilesen) {
  if (!Bilesen || typeof Bilesen.render !== "function" || Bilesen.__llIsik) return;
  const eski = Bilesen.render;
  Bilesen.__llIsik = true;
  Bilesen.render = function (props, ...rest) {
    const [odak, setOdak] = useState(false);
    if (!props || props.__isiksiz) return eski.call(this, props, ...rest);
    const yeni = {
      ...props,
      onFocus: (e) => { setOdak(true); props.onFocus && props.onFocus(e); },
      onBlur: (e) => { setOdak(false); props.onBlur && props.onBlur(e); },
      style: [props.style, odak ? odakIsik() : null],
    };
    return eski.call(this, yeni, ...rest);
  };
}
const ODAK_ISIK = {
  shadowColor: "#EDE7DB", shadowOpacity: 0.14, shadowRadius: 18,
  shadowOffset: { width: 0, height: 0 },
  backgroundColor: "#181614",
};
// v7 (Gökberk 3 Ekim: "Tanış'ta arama alanında siyah bant") — koyu temanın odak zemini
// (#181614) açık temada kapkara bir kutu çiziyordu. v7 odağı: beyaz zemin + %8 amber ışıma.
// theme.js'e import yok (döngü riski): tema modu çağrı anında okunur.
const ODAK_ISIK_V7 = {
  shadowColor: "#E28743", shadowOpacity: 0.08, shadowRadius: 18,
  shadowOffset: { width: 0, height: 0 },
  backgroundColor: "#FFFFFF",
  outlineWidth: 0,   // web: tarayicinin siyah odak cercevesi (cihazda anlamsiz, zararsiz)
};
function odakIsik() {
  try { return require("./theme").temaModu() === "v7" ? ODAK_ISIK_V7 : ODAK_ISIK; } catch (e) { return ODAK_ISIK; }
}
