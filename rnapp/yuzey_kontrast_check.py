#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
yuzey_kontrast_check.py — KAYNAKTAKİ HER RENKLİ YÜZEYİN METNİ OKUNUYOR MU?

🔴 NEDEN VAR — `tema_check.py`İN KÖR NOKTASI
`tema_check.py` `theme.js`te BİLDİRİLEN 19 yüzeyi ölçüyor. Ama ekranların
çoğu yüzeyini bildirmiyor: satır içinde `backgroundColor: C.gold` +
`color: "#fff"` yazıp geçiyor. O yüzeyler hiçbir denetimde yoktu.

Ölçtüm: 50 dokunulabilirde oran AA'nın altındaydı. En kötüsü 2.65:1.
Ve bunların 22'si `C.gold` + beyaz — yani `Btn` bileşeninde v2.65'te
düzelttiğim hatanın kopyası, 22 ayrı yerde yaşamaya devam ediyordu.

🆕 SINIF: "BİR HATAYI BİLEŞENDE DÜZELTMEK, O HATANIN KOPYALARINI
DÜZELTMEZ — KOPYALARI ARAMADIYSAN İŞ YARIM KALMIŞTIR."

NE ÖLÇER: kaynakta aynı bileşen bloğunda geçen `backgroundColor: C.x` ve
`color: C.y | "#hex"` çiftlerini bulur, gerçek oranı hesaplar.

SINIRI — ve bu önemli:
  · Yalnız AYNI blokta yan yana duran çiftleri görür. Zemin bir üst
    View'da, metin iç View'daysa göremez.
  · Yarı saydam (rgba) zeminleri atlar — altındaki gerçek zemini bilemez.
  · Yani bu denetim "hepsi temiz" DEMEZ, "gördüklerim temiz" der.
    Kanıtladığından fazlasını iddia etmemek testin kendisi kadar önemli.

TAVAN 0: yeni bir AA ihlali eklemek denetimi kırmızıya boyar.
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import oran, palet                                   # noqa: E402

TAVAN = 0
ESIK = 4.5

# 🔴 GEREKÇELİ MUAFİYET — ve gerekçesiz muafiyet olmaz.
# Bu iki blokta dış View `C.card` zeminli, ama beyaz metin İÇERİDEKİ mor
# gönder düğmesinin üstünde duruyor. Gerçek oran 5.70:1 (C.purple + beyaz).
# Nöbetçi iç içe bileşeni ayırt edemiyor; bu onun bilinen sınırı, kodun
# kusuru değil. Muafiyet dosya+satır değil KALIP olarak yazıldı ki satır
# numarası kaydığında sessizce genişlemesin.
#
# 🆕 SINIF: "BİR MUAFİYET, NEYİ MUAF TUTTUĞUNU YAZMIYORSA MUAFİYET DEĞİL
# GÖRMEZDEN GELMEDİR."
MUAF = [
    ("C.card", '"#fff"', "beyaz metin iç mor düğmenin üstünde — gerçek oran 5.70:1"),
]          # WCAG 1.4.3 gövde metni
BILESEN = ("TouchableOpacity", "View", "Text", "Pressable")


def yorumsuz(g):
    """
    🔴 SATIR NUMARALARI YANLIŞTI. İlk hâlde blok yorumları TAMAMEN
    siliniyordu; her silinen satır, rapordaki numarayı bir kaydırıyordu.
    Denetim "ekranlar_ana.js:2177" dedi, oraya baktım, orada öyle bir
    kod yoktu.

    Yanlış yeri gösteren bir nöbetçi, olmayan nöbetçiden kötüdür: insanı
    doğru yerden uzaklaştırır. Blok yorumları artık AYNI SAYIDA satır
    sonu bırakarak siliniyor.

    🆕 SINIF: "BİR ARACIN BULDUĞU KADAR, BULDUĞU YERİ DOĞRU SÖYLEMESİ DE
    ÖLÇÜMÜN PARÇASIDIR."
    """
    g = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), g, flags=re.S)
    return "\n".join(re.sub(r"//.*$", "", s) for s in g.split("\n"))


def coz(P, ifade):
    if ifade.startswith("C."):
        return P.get(ifade[2:])
    if ifade.startswith('"#') or ifade.startswith("'#"):
        h = ifade.strip("\"'")
        if len(h) == 4:
            h = "#" + "".join(c * 2 for c in h[1:])
        return h if len(h) == 7 else None
    return None


def stil_nesneleri(g):
    """`style={{ ... }}` içindeki TEK stil nesnesini döndürür (iç içe süslüyü sayar)."""
    for m in re.finditer(r"style=\{\{", g):
        d, k = 2, m.end()
        while k < len(g) and d > 0:
            if g[k] == "{":
                d += 1
            elif g[k] == "}":
                d -= 1
            k += 1
        yield m.start(), g[m.end():k - 2]


def main():
    """
    🔴 İLK HÂLİM İKİ SINIF YANLIŞ ALARM ÜRETTİ ve ikisi de öğretici:

      1 · İÇ İÇE BİLEŞEN — dış View'da `backgroundColor: C.card`, iç
          TouchableOpacity'de `C.purple` zeminli beyaz metin. Aynı BLOKTA
          oldukları için eşleştirdim ve "1.00:1" dedim. Oysa o metin
          kartın üstünde değil, mor düğmenin üstünde duruyor.

      2 · ALFA EKLİ RENK — `backgroundColor: C.goldBtn + "20"` yani %12
          saydamlık. `C.goldBtn` diye okudum, `+ "20"`yi görmedim ve
          koyu bir zemin sandım. Gerçek zemin açık bir tint.

    İkisinin ortak dersi aynı: bir çifti "yakın duruyorlar" diye
    eşleştirmek, ölçüm değil TAHMİNDİR.

    🆕 SINIF: "İKİ DEĞERİN AYNI DOSYADA YAKIN DURMASI, AYNI YÜZEYDE
    DURDUKLARI ANLAMINA GELMEZ."

    Artık iki ayrı güven düzeyi var:
      KESİN    — zemin ve metin AYNI stil nesnesinde. Tavan buna uygulanır.
      ŞÜPHELİ  — aynı blokta ama ayrı nesnelerde. Raporlanır, KIRMIZI YAPMAZ;
                 insan gözü gerekiyor ve bunu böyle söylemek dürüstlük.
    """
    P = palet("C")
    kesin, supheli = [], []
    bakilan = 0
    for p in sorted(glob.glob(os.path.join(KOK, "src", "*.js"))) + [os.path.join(KOK, "App.js")]:
        if not os.path.exists(p):
            continue
        ham = open(p, encoding="utf-8").read()
        g = yorumsuz(ham)
        ad = os.path.basename(p)

        # ── KESİN: aynı stil nesnesi ───────────────────────────────────
        for konum, nesne in stil_nesneleri(g):
            zm = re.search(r"backgroundColor:\s*([^,\n]+)", nesne)
            mt = re.search(r"\bcolor:\s*([^,\n}]+)", nesne)
            if not zm or not mt:
                continue
            zi, mi = zm.group(1).strip(), mt.group(1).strip()
            if "+" in zi or "+" in mi:          # alfa ekli — gerçek zemin bilinmiyor
                continue
            zem, met = coz(P, zi), coz(P, mi)
            if not zem or not met:
                continue
            bakilan += 1
            o = oran(met, zem)
            if o < ESIK:
                kesin.append((ad, g[:konum].count("\n") + 1, zi, mi, o))

        # ── ŞÜPHELİ: aynı blok, ayrı nesneler ─────────────────────────
        for bs in BILESEN:
            for m in re.finditer(r"<" + bs + r"(.{0,600}?)</" + bs + r">", g, re.S):
                blok = m.group(0)
                if blok.count("style=") < 2:
                    continue
                zm = re.search(r"backgroundColor:\s*(C\.\w+)(?!\s*\+)", blok)
                mt = re.search(r"\bcolor:\s*(C\.\w+|\"#[0-9A-Fa-f]{3,6}\")(?!\s*\+)", blok)
                if not zm or not mt:
                    continue
                zem, met = coz(P, zm.group(1)), coz(P, mt.group(1))
                if not zem or not met:
                    continue
                o = oran(met, zem)
                if o < ESIK:
                    if any(z == zm.group(1) and mm == mt.group(1) for z, mm, _ in MUAF):
                        continue
                    supheli.append((ad, g[:m.start()].count("\n") + 1,
                                    zm.group(1), mt.group(1), o))

    print("=" * 74)
    print("YÜZEY KONTRAST DENETİMİ — satır içi renk çiftleri")
    print("=" * 74)
    print("  KESİN ölçüm (aynı stil nesnesi) : %d çift · AA altında %d  (tavan %d)"
          % (bakilan, len(kesin), TAVAN))
    for a, s, z, mm, o in sorted(kesin, key=lambda x: x[4]):
        print("    ✗ %-24s %-16s + %-16s %5.2f:1" % (a + ":" + str(s), z, mm, o))
    print()
    print("  ŞÜPHELİ (aynı blok, ayrı nesne) : %d — göz gerekiyor, kırmızı YAPMAZ"
          % len(supheli))
    for z, mm, sebep in MUAF:
        print("  muaf: %s + %s — %s" % (z, mm, sebep))
    for a, s, z, mm, o in sorted(supheli, key=lambda x: x[4])[:8]:
        print("    · %-24s %-16s + %-16s %5.2f:1" % (a + ":" + str(s), z, mm, o))
    if len(supheli) > 8:
        print("    · … %d tane daha" % (len(supheli) - 8))
    print()
    if len(kesin) > TAVAN:
        print("🔴 TAVAN AŞILDI. Sinyal rengini mürekkep olarak kullanma:")
        print("   zemin  → C.goldBtn · C.tealBtn · C.greenBtn · C.amberBtn · C.dangerBtn")
        print("   mürekkep → C.goldText · C.redInk · C.greenInk · C.tealInk · C.amberInk")
        print("            · C.purpleInk · C.mutedAA · C.dimAA")
        return 1
    print("✓ Aynı stil nesnesindeki her renk çifti AA'yı geçiyor (%d çift)." % bakilan)
    print("  ⚠️ Zemini dış View'da olan metinler KESİN listeye girmez;")
    print("     onlar şüpheli listede ve elle bakılmalı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
