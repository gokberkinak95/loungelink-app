#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tema_kaynak_check.py — "theme.js'i kendi başına okuma" kuralının NÖBETÇİSİ.

🔴 NEDEN VAR
Aynı kapsam-ayrıştırma hatasını BEŞ ayrı araçta yaptım. Dördüncüsünden
sonra dersi yazdım — ve beşincisini yaptım. Yazılı ders, bir sonraki
betiği yazarken aklıma gelmedi; çünkü ders bir YORUM'du, bir KAPI değil.

Bu dosya o kapıyı koyuyor: bir araç theme.js'i kendi regex'iyle okumaya
kalkarsa denetim kırmızıya döner ve `tema_oku`ya yönlendirir.

🆕 SINIF: "TEKRAR EDEN BİR HATAYI YORUMLA DEĞİL, TEKRARI ÖLÇEN BİR
NÖBETÇİYLE DURDURURSUN."

MUAF OLANLAR
  · tema_oku.py — ayrıştırmanın kendisi burada yaşıyor
  · bu dosya    — deseni aramak için deseni yazmak zorunda
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
MUAF = {"tema_oku.py", "tema_kaynak_check.py"}

# theme.js'i açıp içinden renk çekmeye çalışan her betik.
ACAN = re.compile(r"""open\(\s*[^)]*theme\.js""")
HEX_TARA = re.compile(r"#\[0-9A-Fa-f\]\{6\}")


def taranacak():
    yollar = []
    for kok in (KOK, os.path.join(os.path.dirname(KOK), "ui_onerisi")):
        if not os.path.isdir(kok):
            continue
        for ad in sorted(os.listdir(kok)):
            if ad.endswith(".py") and ad not in MUAF:
                yollar.append(os.path.join(kok, ad))
    return yollar


def main():
    ihlal = []
    bakilan = 0
    for p in taranacak():
        try:
            g = open(p, encoding="utf-8").read()
        except Exception:
            continue
        bakilan += 1
        acar = bool(ACAN.search(g))
        tarar = bool(HEX_TARA.search(g))
        kullanir = "tema_oku" in g
        # theme.js'i AÇIP içinde hex ARAYAN ama tek okuyucuyu KULLANMAYAN
        if acar and tarar and not kullanir:
            ihlal.append((os.path.relpath(p, os.path.dirname(KOK)),
                          "theme.js'i kendi regex'iyle okuyor"))

    print("=" * 72)
    print("TEMA KAYNAK DENETİMİ — theme.js'i kaç araç kendi başına okuyor?")
    print("=" * 72)
    print("  taranan betik : %d" % bakilan)
    print("  muaf          : %s" % ", ".join(sorted(MUAF)))
    if ihlal:
        print()
        for yol, sebep in ihlal:
            print("  ✗ %-34s %s" % (yol, sebep))
        print()
        print("🔴 Bu araçlar `tema_oku.palet()` kullanmalı. İki palet (C / KOYU)")
        print("   yan yana duruyor; düz metin taraması ikisini karıştırır ve")
        print("   denetim SESSİZCE yanlış cevap verir — beş kez oldu.")
        return 1
    print("  ✓ theme.js'i kendi başına ayrıştıran araç yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
