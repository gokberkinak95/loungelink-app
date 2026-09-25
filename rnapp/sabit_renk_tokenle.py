#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sabit_renk_tokenle.py — SATIR İÇİNE GÖMÜLÜ RENKLERİ TOKENE ÇEVİRİR.

🔴 NEDEN VAR — KOYU TEMA BUNU GÖRÜNÜR YAPTI
Tema anahtarını kurarken ölçtüm: `theme.js` dışında 157 yerde renk
DOĞRUDAN yazılmış, 33 ayrı değer. Bunların her biri, tema değiştiğinde
DEĞİŞMEYECEK bir piksel demek. Açık temada kimse fark etmiyordu çünkü
değerler zaten açık temanın değerleriydi.

En çarpıcı örnek tek bir ekranda duruyordu: `#FFF4E5` zemin +
`#E8A33D` kenar + `#8A5A00` metin — 33 kullanımlık eksiksiz bir uyarı
paleti, paletin DIŞINDA. Palette zaten `amberBg` · `amber` · `amberInk`
vardı; bu üçlü onların elle yeniden yazılmış hâliydi.

🆕 SINIF: "BİR TEMA ANAHTARI KURMAK, TEMANIN NEREDE DELİK OLDUĞUNU DA
GÖSTERİR — ÇÜNKÜ DEĞİŞMEYEN HER PİKSEL BİR DELİKTİR."

⚠️ MUAF OLANLAR fotoğraf perdeleri: `rgba(10,6,6,…)` gibi değerler
FOTOĞRAFIN üstünde duruyor. Onların zemini tema değil görsel; iki
temada da aynı kalmaları DOĞRU. Muafiyet gerekçesiyle yazılı.
"""
import datetime
import glob
import re
import os
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import oran, palet                                   # noqa: E402

# (sabit değer, token, gerekçe)
ESLEME = [
    ('"#FFF4E5"', "C.amberBg", "uyarı kutusu zemini — palette zaten vardı"),
    ('"#8A5A00"', "C.amberInk", "uyarı metni"),
    ('"#E8A33D"', "C.amber", "uyarı kutusu kenarı"),
    ('"#FDECEA"', "C.hataBg", "hata kutusu zemini (üç ayrı tonu vardı)"),
    ('"#FDECEC"', "C.hataBg", "hata kutusu zemini"),
    ('"#FBEAE9"', "C.hataBg", "hata kutusu zemini"),
    ('"#F2C9C9"', "C.hataLine", "hata kutusu kenarı"),
    ('"#9B2C2C"', "C.redInk", "hata metni — C.redInk'in ta kendisi"),
    ('"#FFFDF9"', "C.surface", "kart yüzeyi"),
    ('"#E2F1EE"', "C.tealTint2", "olumlu kutu zemini"),
    ('"#E9F6F3"', "C.tealTint", "olumlu kutu zemini, açık ton"),
    ('"#B8943A"', "C.gold", "bildirim vurgu rengi"),
    ('"#1A1F2E"', "C.ink", "🔴 ESKİ LACİVERT PALETTEN KALMA — v2.31'de "
                           "kaldırılan renk bir düğme metninde yaşıyordu"),
    ('"rgba(255,255,255,0.34)"', "C.btnUstIsik", "düğme üst ışığı — token vardı"),
    ('"rgba(26,31,46,0.55)"', "C.perde", "modal perdesi — eski lacivert"),
    ('"rgba(20,24,35,0.55)"', "C.perde", "modal perdesi — eski lacivert"),
]

# Gerekçeli muafiyet: zemini TEMA değil FOTOĞRAF olan perdeler.
MUAF_ONEK = ("rgba(10,6,6", "rgba(18,12,12", "rgba(20,14,10", "rgba(0,0,0",
             "rgba(184,148,58,0.08)")

DOSYA = sorted(glob.glob(os.path.join(KOK, "src", "*.js"))) + [os.path.join(KOK, "App.js")]


def main():
    P = palet("C")
    print("=" * 74)
    print("SABİT RENKLERİ TOKENE ÇEVİRME")
    print("=" * 74)
    # Önce ÖLÇ: token gerçekten aynı işi görüyor mu?
    print("\n  değişimden önce kontrast doğrulaması:")
    for a, b, c in (("#8A5A00", "#FFF4E5", "uyarı"), ("#9B2C2C", "#FDECEC", "hata")):
        print("    sabit  %s / %s  %.2f:1" % (a, b, oran(a, b)))
    print("    token  C.amberInk / C.amberBg  %.2f:1" % oran(P["amberInk"], P["amberBg"]))
    print("    token  C.redInk   / C.hataBg   %.2f:1" % oran(P["redInk"], P["hataBg"]))

    ye = os.path.join(KOK, "_yedek_sabitrenk",
                      datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(ye, exist_ok=True)
    toplam = {}
    for p in DOSYA:
        if p.endswith("theme.js") or not os.path.exists(p):
            continue
        g = open(p, encoding="utf-8").read()
        ham = g
        for sabit, token, _ in ESLEME:
            n = g.count(sabit)
            if not n:
                continue
            g = g.replace(sabit, token)
            toplam[token] = toplam.get(token, 0) + n
        if g != ham:
            # 🔴 İLK ÇALIŞTIRMADA `push.js`E `C.gold` YAZDIM VE O DOSYA
            # `C`Yİ HİÇ İÇE AKTARMIYORDU — yani kod, çalıştığı anda
            # `C is not defined` ile patlayacaktı. Bir kod değiştiricinin
            # "değeri değiştirdim" demesi yetmez; yazdığı ismin O DOSYADA
            # tanımlı olduğunu da bilmesi gerekir.
            #
            # 🆕 SINIF: "BİR KOD DEĞİŞTİRİCİ METİN DEĞİL KOD YAZAR —
            # YAZDIĞI İSMİN O DOSYADA TANIMLI OLUP OLMADIĞINI SORMUYORSA
            # METİN YAZIYOR DEMEKTİR."
            if "C." in "".join(t for _, t, _ in ESLEME) and \
               "from \"./theme\"" not in g and "from \"./src/theme\"" not in g:
                print("  🔴 %s: `C` içe aktarılmamış — atlandı" % os.path.basename(p))
                continue
            # 🔴 İKİNCİ TUZAK, AYNI SINIFTAN: `color="#8A5A00"` bir JSX
            # ÖZNİTELİĞİYDİ. Düz metin değişimi onu `color=C.amberInk`
            # yaptı — JSX'te öznitelik ya tırnaklı metin ya süslü
            # parantez ister, ikisi de değil. App.js sözdizimi hatası
            # verdi (1245:41). Aynı ders iki kez, iki kılıkta: içe
            # aktarma ve söz dizimi.
            #
            # 🆕 SINIF: "BİR DEĞERİ TIRNAK İÇİNDEN ÇIKARIP İFADEYE
            # ÇEVİRİYORSAN, O DEĞERİN BULUNDUĞU BAĞLAM DA DEĞİŞMİŞ
            # OLABİLİR — JSX'TE TIRNAK VE SÜSLÜ PARANTEZ AYNI ŞEY DEĞİL."
            g = re.sub(r"(\s\w+)=(C\.\w+)", r"\1={\2}", g)
            shutil.copy2(p, os.path.join(ye, os.path.basename(p)))
            open(p, "w", encoding="utf-8").write(g)
            print("  ✓ %s" % os.path.basename(p))
    print("\n  %d kullanım tokene geçti:" % sum(toplam.values()))
    for t, n in sorted(toplam.items(), key=lambda x: -x[1]):
        print("    %-16s ×%d" % (t, n))
    print("\n  muaf (fotoğraf perdesi — zemini tema değil görsel):")
    for m in MUAF_ONEK:
        print("    %s…" % m)
    print("\n  yedek: %s" % ye)
    return 0


if __name__ == "__main__":
    sys.exit(main())
