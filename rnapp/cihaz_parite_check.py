#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cihaz_parite_check.py — RENDER İLE CİHAZ ARASINDAKİ İKİ SESSİZ FARK.

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK: "app'i yüklediğimde farklı bir ekran,
buton yapısı, text fontu, başlık, yerleşim vs karşılaşmak istemiyorum."

Web sahnesi (Chromium + react-native-web) geometriyi, rengi ve fontu
kaynaktan alıyor; ama iki şeyi ALAMIYOR ve ikisi de bu hafta ısırdı:

── 1 · GÖLGE İKİ PLATFORMDA İKİ AYRI ÖZELLİK ───────────────────────
   iOS  : shadowColor + shadowOpacity + shadowRadius + shadowOffset
   Android : elevation  (tek sayı; renk/yarıçap yok sayılır)
   Web  : box-shadow (shadow* okunur, elevation okunmaz)
Yani `elevation` yazmayı unutan bir stil, web'de ve iOS'ta gölgeli
görünür, ANDROID'DE DÜMDÜZ olur. Render buna kör: web `shadow*`u çiziyor.

── 2 · BİTİŞİK YÜZDE KATMANLARI ────────────────────────────────────
Düğme çizgisi tam olarak buydu: yan yana dizilen `top: i*X%` +
`height: X%` katmanlar cihaz pikseline yuvarlanınca aralarında 1px
BOŞLUK bırakıyor. Web'de de olur, cihazda da; ama ölçeğe göre farklı
yerde. Çözümü kalıbı yasaklamak: yüzdeyle dizilmiş bitişik katman
yerine tek bir gerilmiş görsel.

🆕 SINIF: "İKİ PLATFORMDA İKİ AYRI ADI OLAN HER ÖZELLİK, BİR TANESİ
YAZILDIĞINDA 'YAZILMIŞ' SAYILIR — VE DİĞER PLATFORMDA SESSİZCE YOKTUR."
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
DOSYALAR = ["App.js"] + ["src/" + f for f in sorted(os.listdir(os.path.join(KOK, "src")))
                         if f.endswith(".js")]

TAVAN_GOLGE = 0
TAVAN_YUZDE = 0

# Gerekçeli istisnalar — her biri neden muaf olduğunu söylüyor.
GOLGE_MUAF = {
    "golgeKapali": "gölgeyi KAPATAN stil — `shadowOpacity: 0` ve `elevation: 0` birlikte",
    "GOLGE_KATMAN": "metin gölgesi (`textShadow`) — elevation diye bir karşılığı yok",
    "temaYenidenKur": "tema yeniden kurucusu — `elevation` taşıyan NESNELERİ güncelliyor, yeni nesne kurmuyor",
}


def golge_pariteleri():
    """`shadow*` yazıp `elevation` yazmayan (veya tersi) stil nesneleri."""
    kotu = []
    for f in DOSYALAR:
        yol = os.path.join(KOK, f)
        s = open(yol, encoding="utf-8").read()
        # Stil nesnesi kabaca: `{ ... }` içinde shadowOpacity ya da elevation geçen blok
        for m in re.finditer(r"\{[^{}]*(?:shadowOpacity|elevation)[^{}]*\}", s):
            blok = m.group(0)
            if any(k in blok for k in GOLGE_MUAF):
                continue
            # Yeniden kurucu blokları: `ELEV.card.shadowColor = ...` gibi
            # ATAMA yapıyorlar, yeni bir stil nesnesi kurmuyorlar.
            if re.search(r"(ELEV|BTN)\.\w+\.shadow", blok):
                continue
            golge = "shadowOpacity" in blok
            elev = "elevation" in blok
            if golge == elev:
                continue
            # `shadowOpacity: 0` + elevation yok → gölge zaten kapalı, sorun değil
            if golge and re.search(r"shadowOpacity:\s*0\b", blok):
                continue
            if elev and re.search(r"elevation:\s*0\b", blok):
                continue
            satir = s[:m.start()].count("\n") + 1
            kotu.append((f, satir, "yalnız shadow*" if golge else "yalnız elevation",
                         blok.replace("\n", " ")[:88]))
    return kotu


def yuzde_yiginlari():
    """`top: `${...}%`` + `height: `${...}%`` ikilisini AYNI stilde kuran yerler.

    Bu kalıp bir döngü içinde bitişik katman üretiyorsa alt piksel
    yuvarlaması boşluk bırakır. Tek katman (döngüsüz) zararsız; o yüzden
    yalnız `Array.from` / `.map(` yakınındakiler sayılıyor."""
    kotu = []
    for f in DOSYALAR:
        yol = os.path.join(KOK, f)
        s = open(yol, encoding="utf-8").read()
        for m in re.finditer(r"top:\s*`\$\{[^`]*\}%`", s):
            pencere = s[max(0, m.start() - 900):m.start() + 400]
            if "height: `${" not in pencere:
                continue
            if "Array.from" not in pencere and ".map(" not in pencere:
                continue
            satir = s[:m.start()].count("\n") + 1
            kotu.append((f, satir))
    return kotu


def main():
    print("=" * 74)
    print("CİHAZ PARİTE DENETİMİ — render'ın göremediği iki fark")
    print("=" * 74)
    g = golge_pariteleri()
    y = yuzde_yiginlari()

    print("\n  1 · GÖLGE — iOS `shadow*` ↔ Android `elevation`")
    if g:
        for f, satir, tur, blok in g:
            print("     ✗ %s:%d  (%s)" % (f, satir, tur))
            print("        %s" % blok)
        print("     → ikisini birlikte yaz; `ELEV`/`BTN.golge` jetonları zaten öyle.")
    else:
        print("     ✓ gölge yazan her stil iki platformu da yazıyor")

    print("\n  2 · BİTİŞİK YÜZDE KATMANI — alt piksel boşluğu üretir")
    if y:
        for f, satir in y:
            print("     ✗ %s:%d" % (f, satir))
        print("     → gerilmiş tek görsel kullan (bkz. assets/perde.png · altin.png)")
    else:
        print("     ✓ döngüyle dizilmiş yüzde katmanı yok")

    kotu = (len(g) > TAVAN_GOLGE) + (len(y) > TAVAN_YUZDE)
    if kotu:
        print("\n🔴 Render bu farkları göstermez; cihaz gösterir.")
        return 1
    print("\n✓ İki platform arasında sessiz fark üreten kalıp yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
