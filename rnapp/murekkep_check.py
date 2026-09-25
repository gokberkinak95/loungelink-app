# -*- coding: utf-8 -*-
"""
murekkep_check.py — SİNYAL RENGİ MÜREKKEP OLARAK KULLANILIYOR MU?

============================================================================
🔴 NEDEN VAR
`theme.js` v3.1'de şu ölçüm yapılmış ve yazılmış:

    C.gold   + beyaz  → 2.86   (22 yer)
    C.goldBg + C.gold → 2.65   ( 3 yer)
    C.tealBg + C.teal → 3.50
    C.redBg  + C.red  → 4.30

Sebep tek cümleyle orada duruyor: "ekranlar SİNYAL rengini (C.gold, C.teal,
C.red) MÜREKKEP olarak kullanıyor. Sinyal rengi bir işaret rengidir;
okunmak için ayarlanmamıştır."

Ve okunur mürekkepler ÜRETİLMİŞ: `C.goldText`, `C.tealInk`, `C.redInk`,
`C.purpleInk`, `C.greenInk`, `C.amberInk` — hepsi ölçülmüş.

AMA DÜZELTME `Btn`E YAPILMIŞ, ÇAĞRI YERLERİNE YAPILMAMIŞTI. 28 Ağustos'ta
saydım: **38 yerde** hâlâ sinyal rengi, bir tint zeminin üstünde mürekkep
olarak duruyordu.

🆕 SINIF: "BİR ÖLÇÜMÜ YAPIP DÜZELTMEYİ TEK BİR BİLEŞENE UYGULARSAN, AYNI
HATA ÇAĞRI YERLERİNDE YAŞAMAYA DEVAM EDER — VE ARTIK 'ÇÖZÜLDÜ' DİYE
ANILDIĞI İÇİN KİMSE BAKMAZ."

NE ÖLÇÜYOR: `color: C.<sinyal>` kullanımı, yakınında (aynı JSX ağacında,
520 karakter geriye) bir TINT zemin varsa. Mevcut borç dondurulur; ARTIŞ
build'i düşürür.

⚠️ SINIRI: bu bir YAKINLIK ölçümüdür, gerçek bir DOM ağacı değil. Yanlış
pozitif üretebilir. O yüzden mutlak bir tavan değil ÇIRÇIR: bugünkü sayı
tavan, artış hata.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "murekkep_butce.json")

sys.path.insert(0, KOK)
import tema_oku as T   # noqa: E402

SINYAL = ["gold", "teal", "red", "purple", "green", "amber"]
OKUNUR = {"gold": "goldText", "teal": "tealInk", "red": "redInk",
          "purple": "purpleInk", "green": "greenInk", "amber": "amberInk"}


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


def main():
    print("=" * 70)
    print("MÜREKKEP DENETİMİ — sinyal rengi tint zeminde mürekkep mi?")
    print("=" * 70)

    p = T.palet("C")
    tint = [k for k in p if k.endswith(("Bg", "Tint", "Tint2", "Soft"))] + ["hataBg"]

    dosyalar = [os.path.join(KOK, "App.js")] + [
        os.path.join(SRC, f) for f in sorted(os.listdir(SRC))
        if f.endswith(".js") and f not in ("theme.js", "i18n.js")]

    simdi = {}
    for y in dosyalar:
        with open(y, encoding="utf-8") as f:
            s = kod(f.read())
        n = 0
        for sn in SINYAL:
            for m in re.finditer(r"color:\s*C\." + sn + r"\b(?!\w)", s):
                if any(("C." + t) in s[max(0, m.start() - 520):m.start()] for t in tint):
                    n += 1
        if n:
            simdi[os.path.relpath(y, KOK).replace("\\", "/")] = n

    toplam = sum(simdi.values())
    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)
    onceki = sum(butce.values()) if butce else None

    print("\n  Okunur mürekkep karşılıkları (theme.js'te ölçülü):")
    for sn, mk in OKUNUR.items():
        print("    C.%-7s → C.%s" % (sn, mk))

    print("\n  Sinyal-mürekkep-tint çifti: %d%s"
          % (toplam, "" if onceki is None else "  (bütçe: %d)" % onceki))
    for ad, n in sorted(simdi.items(), key=lambda x: -x[1]):
        print("    %-28s %3d" % (ad, n))

    hata = 0
    artan = [(a, butce[a], n) for a, n in simdi.items() if a in butce and n > butce[a]]
    yeni = [(a, n) for a, n in simdi.items() if a not in butce]
    if artan or (onceki is not None and toplam > onceki):
        print("\n  ✗ SİNYAL RENGİ MÜREKKEP OLARAK ARTMIŞ:")
        for a, o, n in artan:
            print("      %-26s %3d → %3d" % (a, o, n))
        for a, n in yeni:
            print("      %-26s yeni: %d" % (a, n))
        print("      Okunur karşılığını kullan (yukarıdaki tablo).")
        hata = 1
    elif onceki is not None:
        print("  ✓ Artış yok%s." % ("" if toplam == onceki else " (borç %d → %d)" % (onceki, toplam)))

    if not hata and (onceki is None or toplam < onceki):
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(simdi, f, indent=1, sort_keys=True)
        print("  · bütçe güncellendi (yalnız aşağı)")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Mürekkep bulgusu.")
        return 1
    print("✓ Mürekkep denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
