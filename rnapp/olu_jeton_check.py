#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
olu_jeton_check.py

============================================================================
ÖLÜ JETON ATAMASI — AYNI JETONA BİRDEN FAZLA DEĞER

🔴 NEDEN VAR — 20 EYLÜL · BENİ YANILTTIĞI İÇİN

`theme.js` `KOYU.gold`u ÜÇ KEZ atıyor:

    satır  806   gold:       "#D6C3A0"
    satır 1371   KOYU.gold = "#D0B268"
    satır 1444   KOYU.gold = "#C9B693"   ← geçerli olan

JavaScript son atamayı alır. Ama ben nesne literalini okuyup `#D6C3A0`
gördüm ve bütün bir analizi onun üstüne kurdum: Gökberk'e "sevk edilen
altın #D6C3A0, brief'in önerdiği #C9B693 kontrastı 11.46'dan 9.97'ye
düşürür, reddediyorum" dedim. **Oysa app zaten #C9B693 taşıyordu** —
yani brief'in değeri ile sevk edilen değer AYNIYDI.

Dahası: siteyi "bir altın geride" sanıp `--gold`u değiştirdim. Site
DOĞRUYDU (app'ten türetiliyor) ve ben onu app'ten UZAKLAŞTIRDIM.
Sitenin kendi denetimi beni yakaladı.

Ölçtüm: 96 KOYU jetonunun **21'i** birden fazla kez atanıyor, 36 ölü
atama var. Her biri, dosyayı okuyan bir insanı (ya da bir aracı) yanlış
değere inandırabilir.

🆕 SINIF: "BİR JETONA İKİNCİ KEZ DEĞER ATADIĞINDA, BİRİNCİSİ SİLİNMEZ —
DOSYADA KALIR VE ONU OKUYAN HERKESİ YANILTIR. ÖLÜ DEĞER, YANLIŞ DEĞERDEN
TEHLİKELİDİR: YANLIŞ DEĞER HATA VERİR, ÖLÜ DEĞER İKNA EDER."

── NEDEN SİLMİYORUZ ────────────────────────────────────────────────────

Bu projenin kuralı: eski dosya/karar silinmez, arşivlenir. Ölü atamaların
yanındaki yorumlar gerçek bir tarih taşıyor ("v3.2 · iki ölçülebilir
kusur buldum…"). Silmek o tarihi silmek olurdu.

Onun yerine her ölü atama `⛔ ÖLÜ ATAMA — geçerli değer satır N` ile
İŞARETLENİYOR. Tarih duruyor, tuzak görünür oluyor.

NE ÖLÇÜYOR
  `KOYU` nesne literali + `KOYU.x = …` atamaları. Bir jeton birden fazla
  kez atanıyorsa, SONUNCU dışındaki her satırda ⛔ işareti aranır.

NEYİ ÖLÇMÜYOR
  ACIK paleti — uygulamada açık tema yok (`SECENEKLER = ["koyu"]`),
  o yüzden oradaki ölü atama kullanıcıya ulaşmıyor.

TAVAN 0 · işaretsiz ölü atama.
============================================================================
"""
import collections
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
TEMA = os.path.join(KOK, "src", "theme.js")
TAVAN = 0
ISARET = "⛔"


def kodsuz(g):
    g = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), g, flags=re.S)
    return [re.sub(r"//.*$", "", x) for x in g.split("\n")]


def main():
    if not os.path.exists(TEMA):
        print("✗ src/theme.js bulunamadı.")
        sys.exit(1)
    ham = open(TEMA, encoding="utf-8").read()
    satirlar = ham.split("\n")
    ks = kodsuz(ham)

    try:
        koyu_bas = next(i for i, x in enumerate(ks) if "export const KOYU" in x)
        koyu_son = next(i for i in range(koyu_bas, len(ks)) if ks[i].strip() == "};")
    except StopIteration:
        print("✗ `export const KOYU` bloğu bulunamadı — ayrıştırıcı körleşmiş.")
        sys.exit(1)

    say = collections.defaultdict(list)
    for i in range(koyu_bas, koyu_son):
        m = re.match(r'^\s{2}(\w+):\s*("(?:[^"]*)"|[\w.]+)', ks[i])
        if m:
            say[m.group(1)].append(i)
    for i, x in enumerate(ks):
        m = re.match(r'^KOYU\.(\w+)\s*=\s*("(?:[^"]*)"|[\w.]+)\s*;', x)
        if m:
            say[m.group(1)].append(i)

    coklu = {k: sorted(v) for k, v in say.items() if len(v) > 1}
    isaretsiz = []
    olu_toplam = 0
    for k, v in coklu.items():
        for i in v[:-1]:
            olu_toplam += 1
            if ISARET not in satirlar[i]:
                isaretsiz.append((k, i + 1, satirlar[i].strip()[:56], v[-1] + 1))

    print("=" * 74)
    print("ÖLÜ JETON — aynı jetona birden fazla değer (KOYU paleti)")
    print("=" * 74)
    print("  KOYU jetonu          : %d" % len(say))
    print("  birden fazla atanan  : %d" % len(coklu))
    print("  ölü atama            : %d  (hepsi işaretli olmalı)" % olu_toplam)
    print("  İŞARETSİZ            : %d  (tavan %d)" % (len(isaretsiz), TAVAN))
    print("")
    if isaretsiz:
        print("  ✗ Bu satırlar bir sonraki okuyanı yanıltır:")
        for k, satir, metin, gecerli in isaretsiz:
            print("      theme.js:%-5d %-58s → geçerli: satır %d" % (satir, metin, gecerli))
        print("")
        print("  ÇÖZÜM: satırın sonuna şunu ekle (SİLME — tarihi koru):")
        print("      // ⛔ ÖLÜ ATAMA — geçerli değer satır N")
    else:
        print("  ✓ her ölü atama işaretli — dosyayı okuyan yanılmaz")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(isaretsiz), TAVAN))
    sys.exit(1 if len(isaretsiz) > TAVAN else 0)


main()
