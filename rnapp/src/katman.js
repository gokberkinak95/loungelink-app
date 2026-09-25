import React from "react";
import { View, Image, Animated, StyleSheet } from "react-native";

// ════════════════════════════════════════════════════════════════════════════
// 🔴 18 EYLÜL — `Katman`: ANDROID'DE `pointerEvents="none"` YALNIZ `View`DE
//                ÇALIŞIR. BÜTÜN UYGULAMAYI ÖLDÜREN HATA BUYDU.
//
// BELİRTİ (Gökberk, 3 tur): "app açıldığında hiçbir buton çalışmıyor. Splash
// açılıyor ama ne Başla, ne Giriş yap, ne Önce dene, ne dil düğmesi."
// localhost:8081 ÇALIŞIYORDU. logcat'te JS hatası yok, çökme yok.
//
// ÖLÇÜM — react-native 0.76.9'un KENDİ kaynağında, üç dosya:
//
//   1) uimanager/TouchTargetHelper.java:309-311
//        PointerEvents pointerEvents =
//            view instanceof ReactPointerEventsView
//                ? ((ReactPointerEventsView) view).getPointerEvents()
//                : PointerEvents.AUTO;          ← ARAYÜZÜ UYGULAMAYAN HER
//                                                 GÖRÜNÜM "AUTO" SAYILIYOR
//   2) `ReactPointerEventsView` uygulayan TEK sınıf:
//        views/view/ReactViewGroup.java        (grep: 1 dosya)
//      `pointerEvents` prop'unu tanıyan TEK üç yönetici:
//        ReactViewManager · ReactScrollViewManager · ReactHorizontalScrollViewManager
//   3) views/image/ReactImageView.kt → `GenericDraweeView`ten türüyor;
//      dosyada "pointerEvents" kelimesi 0 kez geçiyor.
//
// Yani `<Image pointerEvents="none">` Android'de SESSİZCE YOK SAYILIYOR.
// react-native-web'de ise doğrudan CSS `pointer-events:none`a çevriliyor —
// web'in çalışıp cihazın çalışmamasının sebebi TAM OLARAK BU.
//
// ÖLDÜREN YER: App.js kökü
//     <View style={{flex:1}}>
//       <AppInner />
//       <Tanecik />        ← tam ekran <Image>, SON çocuk
//     </View>
// TouchTargetHelper.java:216 çocukları SONDAN BAŞA tarıyor. Yani ekranın
// herhangi bir yerine yapılan HER dokunuş önce grene çarpıyor, gren de
// "AUTO" sayıldığı için hedef oluyor ve orada bitiyor. Splash'e özel bir
// hata değildi: uygulamanın TAMAMI dokunulamaz durumdaydı, kullanıcı
// splash'i geçemediği için başka yerde göremedi.
//
// ÇÖZÜM: katmanı `pointerEvents="none"` taşıyan bir `View` ile sarmak.
// `View` → `ReactViewGroup` → arayüzü uyguluyor → TouchTargetHelper.java:324
// "This view and its children can't be the target" dalına giriyor ve ALT
// AĞACIN TAMAMI dokunmaya kapanıyor. Ölçülmüş kod yolu, tahmin değil.
//
// STİL BÖLÜNMESİ — görsel çıktı birebir aynı kalsın diye:
//   · KUTU özellikleri (position/inset/width/height/margin/zIndex) SARMALA
//   · görsel özellikler (opacity/transform/mixBlendMode...) GÖRSELE
// Sarmal, görselin eski kutusunun birebir aynısı oluyor; görsel de sarmalı
// %100 dolduruyor. Yüzdeler eskiden de ebeveynin içerik kutusuna çözülüyordu,
// şimdi de öyle — yani 14 Eylül'deki "altın gradyan sağ uca gitmiyor" sınıfı
// geri gelmiyor.
//
// 🆕 SINIF: "BİR PROP'UN JSX'TE YAZILI OLMASI, O PLATFORMDA OKUNDUĞU ANLAMINA
// GELMEZ — HANGİ YERLİ SINIFIN OKUDUĞUNU ÖLÇMEDEN 'GEÇİRGEN' DEME."
//
// Bu sınıfın geri gelmemesi için kapı: `gecirgen_check.py` (tavan 0).
// ════════════════════════════════════════════════════════════════════════════
const KATMAN_KUTU = new Set([
  "position", "top", "left", "right", "bottom", "start", "end",
  "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
  "margin", "marginTop", "marginBottom", "marginLeft", "marginRight",
  "marginHorizontal", "marginVertical", "zIndex",
]);

export function Katman({ style, anim = false, ...gorselProps }) {
  const duz = StyleSheet.flatten(style) || {};
  const kutu = {};
  const gorsel = {};
  for (const k of Object.keys(duz)) {
    (KATMAN_KUTU.has(k) ? kutu : gorsel)[k] = duz[k];
  }
  const Sarmal = anim ? Animated.View : View;
  const Gorsel = anim ? Animated.Image : Image;
  return (
    <Sarmal pointerEvents="none" style={kutu}>
      <Gorsel {...gorselProps} style={[{ width: "100%", height: "100%" }, gorsel]} />
    </Sarmal>
  );
}
