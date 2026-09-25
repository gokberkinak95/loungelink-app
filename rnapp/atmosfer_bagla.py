#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
atmosfer_bagla.py — 38 ekran kökünü <Sayfa> ile değiştirir.

🔴 NEDEN BETİK, NEDEN ELLE DEĞİL
38 yerde aynı iki satırlık düzenleme var. Elle yapsam iki şey olurdu:
  · birini atlardım ve o ekran atmosfersiz kalırdı (kimse fark etmezdi)
  · kapanış </View>'u yanlış eşleştirirdim ve ağaç sessizce bozulurdu

Bu yüzden eşleştirme SAYILIYOR, gözle bakılmıyor: açılış etiketinden
itibaren <View ... > ve </View> derinliği izlenir, kendi kendine kapanan
<View ... /> sayılmaz. Derinlik sıfıra dönen ilk </View> köke aittir.

YEDEK: hiçbir dosya silinmiyor, üzerine yazmadan önce _yedek_atmosfer/
altına tarihli kopya alınır.
"""
import os, re, shutil, sys, datetime

KOK = os.path.dirname(os.path.abspath(__file__))
YEDEK = os.path.join(KOK, "_yedek_atmosfer",
                     datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))

HEDEFLER = ["src/ekranlar_ana.js", "src/ekranlar_yalin.js", "src/screens.js",
            "src/ortak.js", "App.js"]

# Yalnız EKRAN KÖKÜ kalıbı. Yaprak/kart/sayfa-içi bloklar (borderRadius,
# padding taşıyanlar) bilerek dışarıda: onlar opak kalmalı.
ACIK = re.compile(r"<View style=\{\{ flex: 1, backgroundColor: C\.(paper|bg) \}\}>")


def kapanis_bul(metin, bas):
    """`bas` bir <View ...> açılışının bittiği indeks. Eşleşen </View>'u döndür."""
    derinlik = 1
    i = bas
    n = len(metin)
    while i < n:
        if metin.startswith("</View>", i):
            derinlik -= 1
            if derinlik == 0:
                return i
            i += 7
            continue
        if metin.startswith("<View", i):
            # kendi kendine kapanıyor mu? etiketin sonuna kadar bak
            j, tirnak = i + 5, None
            while j < n:
                c = metin[j]
                if tirnak:
                    if c == tirnak:
                        tirnak = None
                elif c in "\"'":
                    tirnak = c
                elif c == ">":
                    break
                j += 1
            if j > i and metin[j - 1] == "/":
                i = j + 1          # <View ... /> — derinliğe girmez
            else:
                derinlik += 1
                i = j + 1
            continue
        i += 1
    return -1


def import_ekle(metin):
    """`Sayfa`yı mevcut ./ui (veya ./src/ui) import satırına ekler."""
    if re.search(r"\bSayfa\b[^\n]*from \"\./(src/)?ui\"", metin):
        return metin, "zaten var"
    m = re.search(r"import \{([^}]*)\} from \"(\./(?:src/)?ui)\";", metin)
    if not m:
        return metin, None
    icerik = m.group(1)
    yeni = "import {" + icerik.rstrip() + ", Sayfa } from \"" + m.group(2) + "\";"
    return metin[:m.start()] + yeni + metin[m.end():], "eklendi"


def main():
    os.makedirs(YEDEK, exist_ok=True)
    toplam, hata = 0, 0
    for rel in HEDEFLER:
        p = os.path.join(KOK, rel)
        metin = open(p, encoding="utf-8").read()
        ham = metin
        sayac = 0
        while True:
            m = ACIK.search(metin)
            if not m:
                break
            k = kapanis_bul(metin, m.end())
            if k < 0:
                print("  ✗ %s: kapanış bulunamadı (offset %d)" % (rel, m.start()))
                hata += 1
                break
            metin = metin[:k] + "</Sayfa>" + metin[k + 7:]
            metin = metin[:m.start()] + "<Sayfa>" + metin[m.end():]
            sayac += 1
        if sayac:
            metin, imp = import_ekle(metin)
            if imp is None:
                print("  ✗ %s: ui import satırı bulunamadı — Sayfa eklenemedi" % rel)
                hata += 1
                continue
            shutil.copy2(p, os.path.join(YEDEK, os.path.basename(rel)))
            open(p, "w", encoding="utf-8").write(metin)
            print("  ✓ %-26s %2d kök  ·  import %s" % (rel, sayac, imp))
            toplam += sayac
        else:
            print("  · %-26s  değişiklik yok" % rel)
    print("\ntoplam %d ekran kökü <Sayfa> oldu · yedek: %s" % (toplam, YEDEK))
    return 1 if hata else 0


if __name__ == "__main__":
    sys.exit(main())
