#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dokunma_check.py — HER DOKUNULABİLİR ÖGE PARMAKLA VURULABİLİR Mİ?

🔴 NEDEN VAR
WCAG 2.5.5 dokunma hedefi için 44×44pt ister. Uygulamada 327
`TouchableOpacity` var ve ölçtüm: 23'ünde ne `hitSlop` ne `minHeight`
ne de bunları taşıyan ortak bir stil vardı.

Bunların çoğu iri kartlardı (yani pratikte sorun değildi) ama üçü
gerçekten küçüktü — ve hangisinin küçük olduğunu KOD OKUYARAK bilemezsin,
çünkü yükseklik çalışma anında belli oluyor. O yüzden kural biçimsel:
her dokunulabilir ya hitSlop taşır ya minHeight ya da ikisini taşıyan
bir ortak stil kullanır.

`hitSlop` yalnız dokunma alanını GENİŞLETİR — yerleşimi, boyutu, hiçbir
görseli değiştirmez. Yani bu düzeltmenin görsel riski sıfır.

🆕 SINIF: "BİR KURALI 'ÇOĞU DURUMDA ZATEN SAĞLANIYOR' DİYE ATLAMA —
HANGİSİNİN SAĞLAMADIĞINI KOD OKUYARAK BİLEMEDİĞİN İÇİN KURAL BİÇİMSEL
OLMAK ZORUNDA."

MUAF: `activeOpacity={1}` taşıyan tam ekran perdeler — dokunma alanı
zaten bütün ekran.

TAVAN 0.
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
TAVAN = 0
KORUYAN = ("hitSlop", "TAP.minHeight", "minHeight", "TAP.slop",
           "S.chip", "S.btn", "S.pickBtn")
MUAF_KALIP = ("activeOpacity={1}",)


def kod_maskesi(g):
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
        if g[i] in "\"'`":
            q = g[i]
            i += 1
            while i < len(g) and g[i] != q:
                if g[i] == "\\":
                    i += 1
                i += 1
        i += 1
    return m


def etiket_sonu(g, i, msk):
    """
    🔴 YORUMDAKİ KESME İŞARETİ TARAYICIYI YUTTU.
    Bir `onPress` gövdesinin içindeki yorumda "Host'un" yazıyordu. Kesme
    işaretini DİZE BAŞLANGICI sandım, tarayıcı dosyanın sonuna kadar
    "dize içindeyim" diye ilerledi ve etiketin sonunu hiç bulamadı.
    Sonuç: `hitSlop` TAŞIYAN bir düğme "korumasız" diye raporlandı.

    Yani yanlış alarm, kodun değil TARAYICIMIN kusuruydu — ve bu tam
    olarak bugün defalarca düştüğüm tuzak: naif tarama.

    🆕 SINIF: "KAYNAK KODU TARARKEN YORUMLARI ATLAMAK BİR OPSİYON DEĞİL
    ÖN KOŞULDUR — İNSAN DİLİ, KODUN NOKTALAMA KURALLARINA UYMAZ."

    Çözüm: karakterin kod mu yorum mu olduğunu zaten bilen MASKEYİ
    tarayıcıya da vermek.
    """
    d, j, q = 0, i, None
    while j < len(g):
        if not msk[j]:            # yorum — hiç bakma
            j += 1
            continue
        c = g[j]
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "{":
            d += 1
        elif c == "}":
            d -= 1
        elif c == ">" and d == 0:
            return j
        j += 1
    return -1


def main():
    toplam, muaf, acik = 0, 0, []
    for p in sorted(glob.glob(os.path.join(KOK, "src", "*.js"))) + [os.path.join(KOK, "App.js")]:
        if not os.path.exists(p):
            continue
        g = open(p, encoding="utf-8").read()
        msk = kod_maskesi(g)
        for m in re.finditer(r"<TouchableOpacity\b", g):
            if not msk[m.start()]:
                continue
            j = etiket_sonu(g, m.start(), msk)
            e = g[m.start():j + 1] if j > 0 else g[m.start():m.start() + 400]
            toplam += 1
            if any(k in e for k in MUAF_KALIP):
                muaf += 1
                continue
            if any(k in e for k in KORUYAN):
                continue
            acik.append((os.path.basename(p), g[:m.start()].count("\n") + 1,
                         re.sub(r"\s+", " ", e)[:70]))
    print("=" * 72)
    print("DOKUNMA HEDEFİ DENETİMİ — WCAG 2.5.5 (44×44pt)")
    print("=" * 72)
    print("  dokunulabilir : %d" % toplam)
    print("  muaf (perde)  : %d" % muaf)
    print("  KORUMASIZ     : %d  (tavan %d)" % (len(acik), TAVAN))
    for ad, s, e in acik:
        print("    ✗ %s:%d\n        %s" % (ad, s, e))
    print()
    if len(acik) > TAVAN:
        print("🔴 Her dokunulabilir `hitSlop={TAP.slop}` ya da `minHeight: TAP.minHeight`")
        print("   taşımalı. hitSlop yerleşimi değiştirmez, yalnız alanı genişletir.")
        return 1
    print("✓ Her dokunulabilir ögenin dokunma alanı korunuyor.")
    print("  ⚠️ Bu BİÇİMSEL bir denetim: 'hitSlop var' der, 'gerçek alan 44pt' demez.")
    print("     Gerçek ölçüm cihazda yapılır.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
