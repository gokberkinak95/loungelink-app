#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ps1_check.py — PowerShell betikleri Windows PowerShell 5.1'de AYRIŞIYOR mu?

🔴 NEDEN VAR — 23 Eylül. `KUR.ps1` Gökberk'in makinesinde hiç çalışmadı:
"'<' operator is reserved", "Unexpected token 'build'" … (11 hata).
Sebep: dosya BOM'suz UTF-8'di; Windows PowerShell 5.1 BOM'suz dosyayı
Windows-1252 okur. Uzun tirenin (—) son baytı 0x94 orada SAĞ ÇİFT TIRNAK
ve PowerShell onu dize sonu sayar. PowerShell 7 dosyayı UTF-8 okuduğu için
yerelde hiçbir şey görünmedi.
Kural: kök klasördeki her .ps1 dosyası YALNIZ ASCII. (BOM eklemek de
çözerdi, ama bir editör BOM'u sessizce silebilir; ASCII'yi silemez.)
🆕 SINIF: "BİR BETİĞİ YAZDIĞIN MAKİNEDE DEĞİL, KOŞACAĞI KABUKTA SINA."
"""
import glob, os, sys
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dosyalar = sorted(glob.glob(os.path.join(KOK, "*.ps1")))
print("=" * 70)
print("PS1 DENETİMİ — Windows PowerShell 5.1 bu betikleri okuyabilir mi?")
print("=" * 70)
bulgu = []
for f in dosyalar:
    b = open(f, "rb").read()
    for n, satir in enumerate(b.split(b"\n"), 1):
        if any(x > 127 for x in satir):
            bulgu.append((os.path.basename(f), n, satir.decode("utf-8", "replace").strip()[:70]))
print("  taranan .ps1 : %d" % len(dosyalar))
for f, n, s in bulgu[:15]:
    print("  ✗ %s:%d  ASCII dışı karakter: %s" % (f, n, s))
if not dosyalar:
    print("  (kök klasörde .ps1 yok — denetlenecek betik yok)")
if not bulgu:
    print("  ✓ bütün satırlar ASCII — 5.1'in Windows-1252 okuması güvenli")
print("\nSONUC  bulgu=%d  tavan=0" % len(bulgu))
sys.exit(1 if bulgu else 0)
