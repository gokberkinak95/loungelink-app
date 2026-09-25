#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gecirgen_check.py — `pointerEvents="none"` YAZMAK, ANDROID'DE GEÇİRGEN
                    OLDUĞU ANLAMINA GELMEZ.

🔴 NEDEN VAR — 18 EYLÜL, ÜÇ TURLUK HATANIN KÖKÜ

Gökberk üç tur boyunca aynı şeyi söyledi: "app açıldığında hiçbir buton
çalışmıyor. Splash açılıyor ama ne Başla, ne Giriş yap, ne Önce dene, ne
dil düğmesi." localhost:8081'de ÇALIŞIYORDU. logcat'te JS hatası yok,
AndroidRuntime çökmesi yok. Yeni mimari, New Architecture, expo-dev-client
— hepsi elendi, çünkü hiçbiri ÖLÇÜLMÜŞ bir sebep değildi.

Sebep react-native 0.76.9'un kendi kaynağındaydı:

  1) uimanager/TouchTargetHelper.java:309-311
       PointerEvents pointerEvents =
           view instanceof ReactPointerEventsView
               ? ((ReactPointerEventsView) view).getPointerEvents()
               : PointerEvents.AUTO;

     Arayüzü uygulamayan her görünüm "AUTO" sayılıyor — yani prop yazılı
     olsa bile dokunmayı YUTUYOR.

  2) `ReactPointerEventsView` uygulayan TEK sınıf:
       views/view/ReactViewGroup.java
     `pointerEvents` prop'unu tanıyan TEK üç yönetici:
       ReactViewManager · ReactScrollViewManager · ReactHorizontalScrollViewManager

  3) views/image/ReactImageView.kt `GenericDraweeView`ten türüyor ve
     dosyada "pointerEvents" kelimesi 0 kez geçiyor.

react-native-web ise prop'u doğrudan CSS `pointer-events:none`a çeviriyor.
Web'in çalışıp cihazın çalışmamasının sebebi tam olarak bu fark.

ÖLDÜREN YER App.js kökündeydi: tam ekran `<Image>` (gren dokusu) kökün SON
çocuğuydu ve TouchTargetHelper.java:216 çocukları SONDAN BAŞA tarıyor.
Ekranın herhangi bir yerine yapılan her dokunuş önce grene çarpıyor,
"AUTO" sayıldığı için hedef oluyor ve orada bitiyordu.

🆕 SINIF: "BİR PROP'UN JSX'TE YAZILI OLMASI, O PLATFORMDA OKUNDUĞU ANLAMINA
GELMEZ — HANGİ YERLİ SINIFIN OKUDUĞUNU ÖLÇMEDEN 'GEÇİRGEN' DEME."

KURAL
  `pointerEvents` YALNIZ şu etiketlerde durabilir:
      View · Animated.View · ScrollView · Animated.ScrollView ·
      TouchableOpacity/Highlight/WithoutFeedback (kendi View'ini üretir) ·
      Pressable · Modal
  `Image`, `Animated.Image`, `ImageBackground`, `Text`, `Animated.Text`,
  `TextInput` üzerinde YASAK. Bunlar `Katman` (src/katman.js) ile ya da
  `pointerEvents="none"` taşıyan bir `View` sarmalıyla yazılır.

═══════════════════════════════════════════════════════════════════════
🔴 İKİNCİ ÖLÇÜ — 20 EYLÜL, MUTASYON TESTİNİN BULDUĞU DELİK

`web_sahne/dokunma_yolu_test.py`i mutasyon testine soktum: splash'e tam
ekran, `pointerEvents` TAŞIMAYAN dekoratif bir `<Image>` koydum — yani
ekranı öldüren orijinal hatanın birebir şekli. Test YEŞİL kaldı.

Sebebini DOM'da ölçtüm: react-native-web `Image`i `pointer-events:none`
ve `z-index:-1` ile basıyor. Yani o katman TARAYICIDA HİÇBİR ZAMAN
dokunma almıyor. Android'de ise `ReactImageView` `ReactPointerEventsView`
uygulamadığı için AUTO sayılıp dokunmayı YUTUYOR.

Sonuç: bu hata sınıfı web sahnesinde YAPISAL OLARAK GÖRÜNMEZ. Tarayıcıda
koşan hiçbir test onu yakalayamaz — yakalamasının tek yolu kaynakta
görmektir, yani burası.

Ve bu kapının BİRİNCİ ölçüsü de onu görmüyordu: birinci ölçü prop'u
YAZILMIŞ `Image`leri arıyor; prop'u tamamen SİLMEK bulguyu yok ediyordu.
Yani "düzeltme" diye prop'u silmek kapıyı susturuyor, hatayı değil.

🆕 SINIF: "BİR KAPI 'YANLIŞ YAZILMIŞ PROP'U ARIYORSA, PROP'U SİLMEK ONU
SUSTURUR — ASIL SORULACAK ŞEY PROP'UN ŞEKLİ DEĞİL, KATMANIN DOKUNMA
ALANINI KAPLAYIP KAPLAMADIĞIDIR."

İKİNCİ KURAL: mutlak konumlu ve tam ekranı kaplayan bir `Image` /
`ImageBackground`, `pointerEvents` taşısa da taşımasa da yasaktır.
Doğrusu: `pointerEvents="none"` taşıyan bir `<View>` ile sarmak (View o
prop'u Android'de gerçekten okur) ya da `src/katman.js`teki `Katman`.

TAVAN 0 (iki ölçü de).
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
TAVAN = 0

ATLA = {"node_modules", ".git", "android", "ios", ".expo", "assets",
        "brand", "tasarim_kaynak", "web_sahne", "render_check", "ekranlar_oneri"}

# Android'de `pointerEvents`i OKUYAN yerli sınıflar (ölçüldü, bkz. başlık).
SERBEST = {
    "View", "Animated.View", "SafeAreaView", "KeyboardAvoidingView",
    "ScrollView", "Animated.ScrollView", "FlatList", "SectionList",
    "TouchableOpacity", "TouchableHighlight", "TouchableWithoutFeedback",
    "Pressable", "Modal",
}
# Okumayan, bu yüzden YASAK olanlar.
YASAK = {
    "Image", "Animated.Image", "ImageBackground", "Animated.ImageBackground",
    "Text", "Animated.Text", "TextInput", "Animated.TextInput",
}

ETIKET = re.compile(r"<(Animated\.[A-Za-z]+|[A-Z][A-Za-z0-9_]*)\b")

# İkinci ölçü: mutlak konumlu tam ekran görsel katmanı.
GORSEL = {"Image", "Animated.Image", "ImageBackground", "Animated.ImageBackground"}
MUTLAK = re.compile(r"position\s*:\s*[\"']absolute[\"']")
ABSFILL = re.compile(r"StyleSheet\.absoluteFill(?:Object)?")
KENAR = re.compile(r"\b(left|right|top|bottom)\s*:\s*0\b")


def tam_ekran_mi(govde):
    """
    Dokunma alanını kaplıyor mu? İki kabul:
      · `StyleSheet.absoluteFill` / `absoluteFillObject`
      · `position:"absolute"` + en az ÜÇ kenar 0
    Üç kenar şartı, köşeye yapışmış küçük bir rozeti (iki kenar) eler;
    üç kenar 0 olan bir katman her zaman ekranın bir ŞERİDİNİ baştan
    başa kaplar ve altındaki her düğmeyi gömer.
    """
    if ABSFILL.search(govde):
        return "StyleSheet.absoluteFill"
    if MUTLAK.search(govde):
        kenarlar = {m.group(1) for m in KENAR.finditer(govde)}
        if len(kenarlar) >= 3:
            return "absolute + " + "/".join(sorted(kenarlar)) + ":0"
    return None


def yorumlari_sil(src):
    """
    JSX yorumları da `pointerEvents` kelimesini taşıyabiliyor (bu dosyadaki
    açıklamalar gibi). Yorumu silmezsek kapı kendi belgesini ihlal sanar.
    Silerken SATIR SAYISI korunuyor — bulgu satırı doğru kalsın diye.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in src[i:j]))
            i = j
        elif src[i] in "\"'`":
            q = src[i]
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == q:
                    j += 1
                    break
                j += 1
            out.append(src[i:j])
            i = j
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def etiket_govdesi(src, bas):
    """Etiketin `>` ya da `/>` ile biten açılış gövdesini döndürür."""
    j = bas
    süslü = 0
    n = len(src)
    while j < n:
        c = src[j]
        if c == "{":
            süslü += 1
        elif c == "}":
            süslü -= 1
        elif c == ">" and süslü == 0:
            return src[bas:j + 1]
        j += 1
    return src[bas:]


def main():
    bulgular = []
    ortu = []
    bilinmeyen = set()
    for dirpath, dirs, files in os.walk(KOK):
        dirs[:] = [d for d in dirs if d not in ATLA]
        for f in sorted(files):
            if not f.endswith(".js"):
                continue
            p = os.path.join(dirpath, f)
            ad = os.path.relpath(p, KOK).replace(os.sep, "/")
            ham = open(p, encoding="utf-8").read()
            src = yorumlari_sil(ham)
            for m in ETIKET.finditer(src):
                etiket = m.group(1)
                govde = etiket_govdesi(src, m.start())
                satir = src[:m.start()].count("\n") + 1

                # ── İKİNCİ ÖLÇÜ: tam ekran görsel katmanı ──────────────
                if etiket in GORSEL:
                    neden = tam_ekran_mi(govde)
                    if neden:
                        ortu.append((ad, satir, etiket, neden))

                if "pointerEvents" not in govde:
                    continue
                if etiket in YASAK:
                    bulgular.append((ad, satir, etiket))
                elif etiket not in SERBEST:
                    # Kendi bileşenimiz: prop'u nereye verdiğini kapı
                    # bilemez. Uyarı olarak listelenir, tavana sayılmaz.
                    bilinmeyen.add((ad, satir, etiket))

    print("gecirgen_check · `pointerEvents` YALNIZ View/ScrollView ailesinde okunur (Android)")
    print("  ölçüm: TouchTargetHelper.java:309-311 · ReactImageView.kt'de 0 geçiş")
    print()
    if bilinmeyen:
        print(f"  bilgi · kendi bileşenimize verilen {len(bilinmeyen)} `pointerEvents`"
              " (tavana sayılmaz, bileşen içinde View'e inmeli):")
        for ad, satir, et in sorted(bilinmeyen)[:12]:
            print(f"        {ad}:{satir}  <{et}>")
        print()
    if bulgular:
        print(f"  ✗ {len(bulgular)} YASAK kullanım — bunlar cihazda SESSİZCE yok sayılır:")
        for ad, satir, et in bulgular:
            print(f"        {ad}:{satir}  <{et} pointerEvents=…>")
        print()
        print("  ÇÖZÜM: `Katman` (src/katman.js) kullan ya da öğeyi")
        print("         `pointerEvents=\"none\"` taşıyan bir <View> ile sar.")
    else:
        print("  ✓ 0 yasak kullanım (1. ölçü — prop'un yeri)")

    print()
    print("  2. ölçü · mutlak konumlu TAM EKRAN görsel katmanı")
    print("    (web'de görünmez: RNW `Image`i pointer-events:none basar;")
    print("     Android'de AUTO sayılır ve altındaki her düğmeyi gömer)")
    if ortu:
        print(f"  ✗ {len(ortu)} tam ekran görsel katmanı:")
        for ad, satir, et, neden in ortu:
            print(f"        {ad}:{satir}  <{et}>  {neden}")
        print()
        print("  ÇÖZÜM: görseli `pointerEvents=\"none\"` taşıyan bir <View> ile")
        print("         sar — View o prop'u Android'de GERÇEKTEN okur.")
    else:
        print("  ✓ 0 tam ekran görsel katmanı")

    toplam = len(bulgular) + len(ortu)
    print()
    print(f"SONUC  bulgu={toplam}  tavan={TAVAN}")
    return 1 if toplam > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
