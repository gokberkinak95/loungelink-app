# -*- coding: utf-8 -*-
"""
token_check.py — TASARIM SİSTEMİ NE KADAR BAĞLI?

============================================================================
🔴 NEDEN VAR — DENETİMDE ÖLÇÜLDÜ, TAHMİN DEĞİL
28 Ağustos denetimi tek cümleyle şunu söyledi: "bu, ihlal edilen bir sistem
değil; hiç bağlanmamış bir sistem." Sayılar:

    yarıçap : 424 ham değer  ·   6 kez `R.*`      → %1 benimseme
    tipo    : 1117 ham       ·  43 kez `T.*`      → %4
    boşluk  : 1782 ham       ·  53 kez `SP[n]`    → %3

Bir tasarım sistemi %3 bağlıysa, o sistem bir DOSYADIR — bir dil değil.
Ve dosyada duran bir sistem, ekranda hiçbir şeyi tutarlı yapmaz.

🆕 SINIF: "BİR TASARIM SİSTEMİ İHLAL EDİLDİĞİ İÇİN DEĞİL, HİÇ BAĞLANMADIĞI
İÇİN ÇALIŞMAZ — VE İKİSİ DIŞARIDAN AYNI GÖRÜNÜR."

NE ÖLÇÜYOR: token kullanımı / (token + ham) oranı. Oran DÜŞERSE build
düşer. Yani her yeni ekran sistemi biraz daha bağlamak zorunda; ham değer
eklemek serbest ama ORANI bozmadan.

⚠️ NEDEN MUTLAK SAYI DEĞİL ORAN: mutlak bir tavan, dosya büyüdükçe
kendiliğinden ihlal edilir ve yükseltilir. Oran, büyümeyi cezalandırmaz —
yalnız SEYRELMEYİ cezalandırır.

🆕 SINIF: "BİR BORCU MUTLAK SAYIYLA SINIRLARSAN BÜYÜME ONU KIRAR VE TAVAN
YÜKSELİR — ORANLA SINIRLARSAN BÜYÜME ONU KIRAMAZ."
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "token_butce.json")

# theme.js ölçeğin KENDİSİ; i18n.js metin taşır — ikisi de sayıma girmez.
HARIC = {"theme.js", "i18n.js"}


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


def dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js") and f not in HARIC:
            d.append(os.path.join(SRC, f))
    return d


OLCUM = [
    ("yarıçap", r"borderRadius:\s*\d", r"borderRadius:\s*R\.\w+"),
    ("tipografi", r"fontSize:\s*\d", r"\.\.\.T\.\w+|fontSize:\s*FS\.\w+"),
    ("boşluk", r"(?:padding|margin)(?:Top|Bottom|Left|Right|Horizontal|Vertical)?:\s*\d",
     r"(?:padding|margin)(?:Top|Bottom|Left|Right|Horizontal|Vertical)?:\s*SP\["),
    ("vurgu mürekkebi", r'color:\s*"#(?:fff|FFF|ffffff|FFFFFF)"', r"color:\s*C\.onAccent"),
]


def main():
    print("=" * 70)
    print("TOKEN BENİMSEME — tasarım sistemi ne kadar bağlı?")
    print("=" * 70)

    metin = ""
    for y in dosyalar():
        with open(y, encoding="utf-8") as f:
            metin += kod(f.read()) + "\n"

    simdi = {}
    print("\n  %-18s %8s %8s %8s" % ("ölçü", "token", "ham", "oran"))
    for ad, ham_re, tok_re in OLCUM:
        ham = len(re.findall(ham_re, metin))
        tok = len(re.findall(tok_re, metin))
        # `borderRadius: R.x` deseni `borderRadius:\s*\d`e takılmaz; toplam
        # = ikisinin toplamı.
        oran = round(100.0 * tok / max(1, tok + ham), 1)
        simdi[ad] = oran
        print("  %-18s %8d %8d %7.1f%%" % (ad, tok, ham, oran))

    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    hata = 0
    if butce:
        print("")
        for ad, oran in simdi.items():
            onceki = butce.get(ad)
            if onceki is None:
                continue
            # 0.5 puanlık ölçüm gürültüsüne tolerans; altı hata.
            if oran < onceki - 0.5:
                print("  ✗ %s benimsemesi DÜŞTÜ: %%%.1f → %%%.1f" % (ad, onceki, oran))
                print("     Yeni kod ham değer ekliyor. Token kullan:")
                print("     R.xs/sm/md/lg/xl/full · T.xs/sm/base/lg/title/display/hero/bant/micro")
                print("     SP[1..6] · C.onAccent")
                hata = 1
            elif oran > onceki + 0.5:
                print("  ✓ %s benimsemesi arttı: %%%.1f → %%%.1f" % (ad, onceki, oran))
        if not hata:
            print("  ✓ Hiçbir ölçüde benimseme düşmedi.")

    if not hata:
        yeni = {ad: max(oran, butce.get(ad, 0)) for ad, oran in simdi.items()}
        if yeni != butce:
            with open(BUTCE_YOL, "w", encoding="utf-8") as f:
                json.dump(yeni, f, indent=1, sort_keys=True)
            print("  · bütçe güncellendi (yalnız yukarı)")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Token benimsemesi geriledi.")
        return 1
    print("✓ Token denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
