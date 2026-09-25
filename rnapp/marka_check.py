#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
marka_check.py — "MARKA ÜRETİCİSİ GERÇEKTEN MARKAYI ÜRETİYOR MU?"

============================================================================
🔴 NASIL DOĞDU
`brand/build_brand.py`nin başlığında yıllardır şu satır duruyordu:

    "MARKA VARLIKLARINI ÜRETEN TEK KAYNAK — her şeyi yeniden üretir."

Doğrulamak için çalıştırdım ve UYGULAMANIN İKONU DEĞİŞTİ. Betik bir
harita iğnesi çiziyordu; sevkiyattaki bütün varlıklar ise bir kanat
taşıyor. Yani o satır bir belge değil bir dilekti — ve tehlikeliydi:
ona güvenip betiği çalıştıran biri markayı sessizce değiştirirdi.

🆕 SINIF: "BİR ÜRETİCİNİN ÇIKTISINI SEVKİYATLA KARŞILAŞTIRMIYORSAN,
'TEK KAYNAK' YAZISI BİR İDDİADIR — VE İDDİALAR ZAMANLA YANLIŞ OLUR."

NE YAPAR
  1 · `build_brand.py`yi GEÇİCİ bir klasöre çalıştırır (sevkiyata dokunmaz)
  2 · üretilen her dosyayı `assets/` içindekiyle piksel piksel karşılaştırır
  3 · fark varsa hangi dosya ve ne kadar, onu söyler

Ayrıca iki mağaza kuralını da ölçer — ikisi de gerçek ret sebebi:
  · icon.png SAYDAM OLAMAZ (Apple HIG). Sevkiyattaki dosya saydamdı ve
    düzleştirilince köşeleri siyah çıkıyordu; bu denetim onu yakalar.
  · adaptive-icon.png OPAK olmalı (Android maskeliyor).

SINIRI: piksel karşılaştırması "marka doğru mu" demez, "üretici ile
sevkiyat aynı mı" der. Doğru marka kararı insanın; bu denetim yalnız
ikisinin AYRIŞMASINI engelliyor.
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops

KOK = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(KOK, "assets")
URETICI = os.path.join(KOK, "brand", "build_brand.py")
TUREYEN = ["icon.png", "adaptive-icon.png", "monochrome-icon.png",
           "notification-icon.png", "favicon.png", "splash.png"]
# `mark-*.png` KAYNAKTIR, türev değil — karşılaştırmaya girmez.


def fark(a_yol, b_yol):
    a = Image.open(a_yol).convert("RGBA")
    b = Image.open(b_yol).convert("RGBA")
    if a.size != b.size:
        return "boyut %s ≠ %s" % (a.size, b.size)
    d = ImageChops.difference(a, b)
    # 🔴 `d.getbbox()` YALNIZ ALFA KANALINA BAKIYOR (Pillow 9.2+ varsayılanı
    # `alpha_only=True`). Fark görüntüsünün alfası her yerde |255-255| = 0
    # olduğu için `getbbox()` daima None döndü ve nöbetçi HER FARKI
    # "fark yok" diye rapor etti.
    #
    # Mutasyon testi olmasaydı bu asla görülmezdi: markayı tamamen
    # değiştirdim, denetim yeşil kaldı. Merkez pikselleri elle basınca
    # (188,153,70) ve (255,255,255) çıktı — yani fark ORADAYDI, ölçüm
    # onu görmüyordu.
    #
    # 🆕 SINIF: "BİR KÜTÜPHANE ÇAĞRISININ VARSAYILANINI OKUMADIYSAN,
    # ÖLÇTÜĞÜNÜ SANDIĞIN ŞEYİ DEĞİL ONUN VARSAYDIĞI ŞEYİ ÖLÇÜYORSUN."
    kutu = d.convert("RGB").getbbox()
    if kutu is None:
        return None
    # ne kadar farklı — ortalama mutlak fark
    hist = d.convert("L").histogram()
    toplam = sum(i * n for i, n in enumerate(hist))
    ort = toplam / (a.width * a.height)
    return "piksel farkı var (ortalama %.1f/255)" % ort


def main():
    if not os.path.exists(URETICI):
        print("🔴 brand/build_brand.py yok")
        return 1
    gecici = tempfile.mkdtemp(prefix="ll_marka_")
    try:
        # 🔴 14 EYLUL · WINDOWS: uretec `UnicodeEncodeError` ile coktu.
        # Sebep uretecin ISINDE degil CIKTISINDA: Windows konsolu cp1254
        # ve uretec basligi "→" iceriyor. Alt surec, ebeveynin konsol
        # kodlamasini devraliyor. Projede ASCII disi karakter basan 196
        # betik var; her birini ASCII'ye cevirmek yanlis cozum olurdu —
        # dogru cozum alt sureci UTF-8 ile baslatmak.
        # 🆕 SINIF: "ALT SURECIN KODLAMASINI VARSAYMA, VER — AKSI HALDE
        # ARACIN TASINABILIRLIGI CALISTIGI KONSOLA BAGLI KALIR."
        cevre = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
        r = subprocess.run([sys.executable, URETICI, gecici],
                           capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=cevre)
        if r.returncode != 0:
            print("🔴 üretici çöktü:\n" + (r.stderr or "")[-600:])
            return 1

        print("=" * 72)
        print("MARKA DENETİMİ — üretici çıktısı sevkiyatla aynı mı?")
        print("=" * 72)
        ayrik = []
        for ad in TUREYEN:
            s, u = os.path.join(ASSETS, ad), os.path.join(gecici, ad)
            if not os.path.exists(u):
                ayrik.append((ad, "üretici bu dosyayı ÜRETMİYOR"))
                continue
            if not os.path.exists(s):
                ayrik.append((ad, "sevkiyatta YOK"))
                continue
            f = fark(s, u)
            if f:
                ayrik.append((ad, f))
        print("  türeyen varlık : %d" % len(TUREYEN))
        print("  ayrışan        : %d" % len(ayrik))
        for ad, ne in ayrik:
            print("    🔴 %-24s %s" % (ad, ne))

        # ---- mağaza kuralları ----
        print()
        kural = []
        ikon = Image.open(os.path.join(ASSETS, "icon.png")).convert("RGBA")
        if ikon.getchannel("A").getextrema()[0] < 255:
            kural.append("icon.png SAYDAM — Apple HIG ikonda alfa kabul etmez; "
                         "düzleştirilince köşeler siyah çıkar")
        if ikon.size != (1024, 1024):
            kural.append("icon.png %s — 1024×1024 olmalı" % (ikon.size,))
        ad_ikon = Image.open(os.path.join(ASSETS, "adaptive-icon.png")).convert("RGBA")
        if ad_ikon.getchannel("A").getextrema()[0] < 255:
            kural.append("adaptive-icon.png saydam — Android maskeleme için opak olmalı")
        print("  mağaza kuralı  : %d ihlal" % len(kural))
        for k in kural:
            print("    🔴 " + k)
        print()
        if ayrik or kural:
            print("🔴 `python brand/build_brand.py` çalıştırmak markayı DEĞİŞTİRİR.")
            print("   Ya üreticiyi sevkiyata uydur, ya sevkiyatı üreticiden yenile.")
            return 1
        print("✓ Üretici ile sevkiyat birebir aynı — 'tek kaynak' iddiası doğru.")
        print("✓ İkon mağaza kurallarını geçiyor (opak · 1024×1024).")
        return 0
    finally:
        shutil.rmtree(gecici, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
