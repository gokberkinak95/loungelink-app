#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
erisim_check.py — EKRAN OKUYUCUDA ADI OLMAYAN DOKUNULABİLİR ALAN VAR MI?

🔴 NEDEN VAR — VE KENDİ RAPORUMDAKİ HATA
Yedi rollü denetimde "dokunulabilir alanların dörtte üçünün ekran
okuyucuda adı yok" yazdım ve %27 rakamı verdim. Gökberk haklı olarak
"bu bir sorun sanırım, çözdün mü?" diye sordu.

Ölçümü DOĞRU yapınca rakam çürüdü:

    ham `grep -c TouchableOpacity`  →  471   ← yorumları, kapanış
                                              etiketlerini, dizeleri
                                              de sayıyordu
    gerçek açılış etiketi           →  231
    açıkça etiketli                 →   73
    İÇİNDE <Text> olan              →  143   ← React Native adı
                                              ÇOCUK METİNDEN türetir;
                                              bunlar BOZUK DEĞİL
    gerçekten adsız                 →   15

Yani bildirdiğim sorun 345 değil 15'ti. Yanlış olan ürün değil, benim
sayma yöntemimdi — ve o rakamı bir KARNEYE yazdım.

🆕 SINIF: "BİR ORANI SUNMADAN ÖNCE PAYDASINI SAY — `grep -c` BİR
ÖLÇÜM DEĞİL, BİR TAHMİNDİR."

NE ÖLÇER: bir dokunulabilir alanın ekran okuyucuda adı var mı.
Ad üç yoldan gelebilir ve üçü de kabul ediliyor:
  1) `accessibilityLabel` / `a11yLabel`
  2) çocuk `<Text>` (RN adı ondan türetir)
  3) `label=` prop'u alan kendi bileşenlerimiz (`Btn`, `IkonMetin`)

⚠️ NE ÖLÇMEZ: adın DOĞRU olduğunu. "Düğme" diye etiketlenmiş bir
düğme bu kapıdan geçer. Kapı yalnız SESSİZLİĞİ yakalar.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
BUTCE = os.path.join(KOK, "erisim_butce.json")
DOKUNULABILIR = ("TouchableOpacity", "TouchableHighlight", "Pressable",
                 "TouchableWithoutFeedback")


def dosyalar():
    yol = [os.path.join(KOK, "App.js")]
    src = os.path.join(KOK, "src")
    yol += [os.path.join(src, f) for f in sorted(os.listdir(src))
            if f.endswith(".js")]
    return [y for y in yol if os.path.exists(y)]


def kod(s):
    """Yorumları at — bir yorumdaki `accessibilityLabel` kanıt değildir."""
    s = re.sub(r"/\*[\s\S]*?\*/", " ", s)
    s = re.sub(r"^\s*//.*$", " ", s, flags=re.M)
    return s


def acilis_sonu(s, i):
    """Açılış etiketinin `>` konumu (süslü parantez derinliği sayılarak)."""
    d = 0
    while i < len(s):
        c = s[i]
        if c == "{":
            d += 1
        elif c == "}":
            d -= 1
        elif c == ">" and d == 0:
            return i
        i += 1
    return len(s)


def bul(yol):
    ham = open(yol, encoding="utf-8").read()
    s = kod(ham)
    adsiz = []
    for ad in DOKUNULABILIR:
        for m in re.finditer(r"<" + ad + r"\b", s):
            son = acilis_sonu(s, m.end())
            acilis = s[m.start():son]
            if "accessibilityLabel" in acilis or "a11yLabel" in acilis:
                continue
            kapanis = s.find("</%s>" % ad, son)
            govde = s[son:kapanis] if kapanis > 0 else s[son:son + 900]
            # RN adı çocuk metinden türetir; `IkonMetin`/`Btn` de metin taşır
            if ("<Text" in govde or "IkonMetin" in govde
                    or re.search(r"\blabel=", govde) or "{body}" in govde):
                continue
            adsiz.append(s[:m.start()].count("\n") + 1)
    return adsiz


def main():
    print("── ERİŞİLEBİLİRLİK: ADSIZ DOKUNULABİLİR ALAN ───────")
    tabanlar = {}
    if os.path.exists(BUTCE):
        try:
            tabanlar = json.load(open(BUTCE, encoding="utf-8"))
        except Exception:
            pass
    yeni, kirik, toplam = {}, 0, 0
    for y in dosyalar():
        a = bul(y)
        ad = os.path.basename(y)
        if a:
            yeni[ad] = len(a)
        toplam += len(a)
        tavan = tabanlar.get(ad)
        if tavan is None:
            continue
        if len(a) > tavan:
            kirik += 1
            print("  ✗ %-24s %d → %d  satır: %s"
                  % (ad, tavan, len(a), ", ".join(map(str, a[:8]))))
        elif len(a) < tavan:
            print("  ↓ %-24s %d → %d (tavan indi)" % (ad, tavan, len(a)))

    # Tavan yalnız DÜŞER — düzelen borç geri açılamaz.
    birlesik = dict(tabanlar)
    for ad, n in yeni.items():
        birlesik[ad] = min(birlesik.get(ad, n), n)
    for ad in list(birlesik):
        if ad not in yeni:
            birlesik[ad] = 0
    json.dump(birlesik, open(BUTCE, "w", encoding="utf-8"),
              ensure_ascii=False, indent=2, sort_keys=True)

    print("  adsız dokunulabilir alan: %d" % toplam)
    if kirik:
        print("\n✗ %d dosyada adsız alan ARTTI." % kirik)
        print("  `accessibilityLabel` ekle ya da içine bir <Text> koy.")
        return 1
    print("✓ Adsız alan hiçbir dosyada artmadı.")
    print("  ⚠ Bu kapı adın DOĞRU olduğunu ölçmez — yalnız var olduğunu.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
