#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kose_olcek.py — `borderRadius` değerlerini R ölçeğine oturtur.

🔴 ÖLÇÜM
460 `borderRadius` kullanımının 293'ü ölçek dışıydı (10·14·20·26·32·999).
Kullanılan değerler 2'den 32'ye kadar 14 farklı sayı — yani ölçek yok,
her ekran kendi köşesini uyduruyor. Yeni zemin yumuşak; birbirine yakın
ama eşit olmayan köşeler, göz onları yan yana gördüğünde "özensiz"
olarak okunuyor.

⚠️ EN BÜYÜK TUZAK: DAİRELER.
    width: 32, height: 32, borderRadius: 16
Burada 16 keyfi bir değer DEĞİL, yarıçapın ta kendisi. 14'e yuvarlamak
daireyi bozar — avatar, nokta, rozet hepsi köşeli olur. Bu yüzden
yarıçap, yakınındaki genişlik/yüksekliğin YARISINA eşitse DOKUNULMUYOR.

🆕 SINIF: "BİR DEĞERİ ÖLÇEĞE OTURTMADAN ÖNCE, O DEĞERİN BİR TERCİH Mİ
YOKSA BİR HESAP SONUCU MU OLDUĞUNU AYIR — HESAP SONUÇLARI ÖLÇEĞE
UYMAK ZORUNDA DEĞİLDİR."

EŞLEME (ölçek adımları arasındaki en yakın komşu değil, ROL koruyan):
    ≤ 5   → dokunma   (ilerleme çubuğu / saç teli — zaten tam yuvarlak)
    6–11  → 10        (küçük çip, ikon kutusu)
    12–16 → 14        (kart içi blok, giriş alanı)
    17–23 → 20        (düğme)
    24–29 → 26        (kart)
    ≥ 30  → 32        (büyük yüzey)
    999   → 999       (hap)
"""
import datetime
import os
import re
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
YEDEK = os.path.join(KOK, "_yedek_kose",
                     datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
DOSYA = ["src/screens.js", "src/ekranlar_ana.js", "src/ekranlar_yalin.js",
         "src/ortak.js", "src/ui.js", "src/HostWallet.js", "src/MomentScreen.js",
         "src/ErrorBoundary.js", "src/Pickers.js", "src/FlightField.js",
         "src/legal.js", "App.js"]


def maske(g):
    m = [True] * len(g)
    i = 0
    while i < len(g):
        if g.startswith("/*", i):
            j = g.find("*/", i + 2)
            j = len(g) if j < 0 else j + 2
            for k in range(i, j):
                m[k] = False
            i = j
            continue
        if g.startswith("//", i):
            j = g.find("\n", i)
            j = len(g) if j < 0 else j
            for k in range(i, j):
                m[k] = False
            i = j
            continue
        i += 1
    return m


def esle(r):
    if r <= 5 or r == 999:
        return None                 # dokunma
    if r <= 11:
        return 10
    if r <= 16:
        return 14
    if r <= 23:
        return 20
    if r <= 29:
        return 26
    return 32


def daire_mi(g, konum, r):
    """Yarıçap, yakındaki genişlik/yüksekliğin yarısı mı?"""
    pen = g[max(0, konum - 220):konum + 220]
    for m in re.finditer(r"\b(?:width|height|size):\s*(\d+(?:\.\d+)?)", pen):
        if abs(float(m.group(1)) / 2 - r) < 0.51:
            return True
    return False


def denetle():
    """
    🔴 DÜZELTMEK YETMEZ, TAVAN GEREKİR. 293 köşeyi ölçeğe getirdim; hiçbir
    şey yeni bir 11 ya da 13 yazılmasını engellemiyor. Bir borcu ödemek,
    borcun tekrar birikmesini önlemez.

    Ölçek dışı ama MEŞRU olanlar sayılmaz:
      · daireler (yarıçap = boyutun yarısı)
      · ≤5 (ince çubuk — zaten tam yuvarlak)
      · 999 (hap)
    """
    disi = []
    for rel in DOSYA:
        yol = os.path.join(KOK, rel)
        if not os.path.exists(yol):
            continue
        g = open(yol, encoding="utf-8").read()
        msk = maske(g)
        for m in re.finditer(r"borderRadius:\s*(\d+(?:\.\d+)?)", g):
            if not msk[m.start()]:
                continue
            r = float(m.group(1))
            if r in (10, 14, 20, 26, 32, 999) or r <= 5:
                continue
            if daire_mi(g, m.start(), r):
                continue
            disi.append((os.path.basename(rel), g[:m.start()].count("\n") + 1, r))
    print("=" * 68)
    print("KÖŞE ÖLÇEĞİ DENETİMİ — R: 10 · 14 · 20 · 26 · 32 · 999")
    print("=" * 68)
    print("  ölçek dışı (daire ve ince çubuk hariç): %d  (tavan %d)"
          % (len(disi), TAVAN))
    for ad, s, r in disi[:20]:
        print("    ✗ %s:%d  borderRadius: %g" % (ad, s, r))
    if len(disi) > TAVAN:
        print("\n🔴 `python kose_olcek.py` çalıştır ya da ölçeğe uygun bir değer seç.")
        return 1
    print("\n✓ Ölçek dışı köşe borcu tavanda ya da altında.")
    return 0


TAVAN = 0


def main():
    if "--denetle" in sys.argv:
        return denetle()
    os.makedirs(YEDEK, exist_ok=True)
    degisen, korunan, atlanan = 0, 0, 0
    for rel in DOSYA:
        yol = os.path.join(KOK, rel)
        if not os.path.exists(yol):
            continue
        g = open(yol, encoding="utf-8").read()
        msk = maske(g)
        duzelt = []
        for m in re.finditer(r"borderRadius:\s*(\d+(?:\.\d+)?)", g):
            if not msk[m.start()]:
                continue
            r = float(m.group(1))
            yeni = esle(r)
            if yeni is None:
                atlanan += 1
                continue
            if daire_mi(g, m.start(), r):
                korunan += 1
                continue
            if abs(yeni - r) < 0.01:
                continue
            duzelt.append((m.start(), m.end(), "borderRadius: %d" % yeni))
        if duzelt:
            shutil.copy2(yol, os.path.join(YEDEK, os.path.basename(rel)))
            for a, b, y in reversed(duzelt):
                g = g[:a] + y + g[b:]
            open(yol, "w", encoding="utf-8").write(g)
            print("  ✓ %-26s %3d köşe ölçeğe geldi" % (rel, len(duzelt)))
            degisen += len(duzelt)
    print("\n%d değiştirildi · %d daire korundu · %d ölçek dışı ama muaf (≤5 / 999)"
          % (degisen, korunan, atlanan))
    print("yedek: %s" % YEDEK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
