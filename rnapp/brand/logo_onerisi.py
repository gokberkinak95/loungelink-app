#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
logo_onerisi.py — YALNIZ ÖNERİ. HİÇBİR YERE UYGULANMIYOR.

⚠️ Gökberk: "logoyu benden teyit almadan sakın uygulama."
Bu betik `brand/logo_onerisi.png` üretir ve BAŞKA HİÇBİR ŞEYE
dokunmaz. `assets/mark-*.png`, `icon.png`, `splash.png` — hiçbiri
değişmiyor. Onay gelirse `build_brand.py`ye taşınır.

────────────────────────────────────────────────────────────────
NEDEN YENİ BİR İŞARET ÖNERİYORUM

Bugünkü işaret bir KANAT/SWOOSH. Sorunu güzellik değil, SAHİPLİK:
havacılıkta swoosh jenerik bir jesttir — Türk Hava Yolları'ndan
Emirates'e onlarca marka onu kullanır. Bir yolcu onu gördüğünde
"havacılık" der, "LoungeLink" demez.

Bu turda ürünün kendi görsel dili netleşti ve üç işaret ortaya çıktı:

  · RADAR   — "çevrende kim var" · Keşfet sekmesinin işareti
  · KALKAN  — "doğrulanmış" · güvenin tek görünür kanıtı
  · EŞİK    — iki kişi arasında açılan kapı · ürünün asıl vaadi

Üçü de ÜRÜNÜN İÇİNDEN çıktı. Bir logo bu üçünden birine yaslanırsa
marka, ürünle aynı şeyi söyler.

🆕 SINIF: "BİR LOGO, ÜRÜNÜN ZATEN KULLANDIĞI BİR İŞARETTEN
TÜRETİLİRSE 'MARKA' DEĞİL 'İMZA' OLUR — VE İMZA TAKLİT EDİLEMEZ."
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FD = os.path.join(HERE, "..", "assets", "fonts")
CIKTI = os.path.join(HERE, "logo_onerisi.png")

GECE = (16, 14, 18)
ALTIN = (224, 190, 122)
ALTIND = (195, 155, 76)
TEAL = (59, 212, 180)
BULUT = (246, 241, 232)
SESSIZ = (167, 155, 138)


def f(ad, px):
    return ImageFont.truetype(os.path.join(FD, ad), px)


def yay(d, cx, cy, r, a0, a1, w, renk):
    d.arc([cx - r, cy - r, cx + r, cy + r], a0, a1, fill=renk, width=w)


# ── A · RADAR-ANAHTAR ────────────────────────────────────────────
# Radar işaretinin merkez halkası bir ANAHTAR DELİĞİNE dönüşüyor.
# Söylediği: "sinyal + erişim". Ürünün iki yarısı tek işarette.
def a_radar_anahtar(d, cx, cy, s, renk=ALTIN):
    w = max(2, int(s * 0.085))
    for r in (s * 0.42, s * 0.26):
        yay(d, cx, cy, r, 268, 362, w, renk)
        yay(d, cx, cy, r, 88, 182, w, renk)
    # anahtar deliği: halka + aşağı inen ince yarık
    rr = s * 0.115
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=renk, width=w)
    d.rectangle([cx - w * 0.55, cy + rr * 0.5, cx + w * 0.55, cy + rr * 2.1],
                fill=renk)


# ── B · EŞİK ─────────────────────────────────────────────────────
# İki dikey çizgi bir KAPI ARALIĞI kuruyor; solu altın (host),
# sağı teal (misafir). Aralarındaki nokta, açılan geçit.
# Söylediği: "kapı iki kişi arasında açılır".
def b_esik(d, cx, cy, s):
    w = max(3, int(s * 0.10))
    h = s * 0.78
    ara = s * 0.30
    d.rounded_rectangle([cx - ara - w, cy - h / 2, cx - ara, cy + h / 2],
                        w / 2, fill=ALTIN)
    d.rounded_rectangle([cx + ara, cy - h / 2, cx + ara + w, cy + h / 2],
                        w / 2, fill=TEAL)
    # eşiğin kendisi: iki sütunu birleştiren ince alt çizgi + merkez nokta
    d.rounded_rectangle([cx - ara - w, cy + h / 2 - w, cx + ara + w, cy + h / 2],
                        w / 2, fill=(120, 108, 96))
    rr = s * 0.085
    d.ellipse([cx - rr, cy - rr * 0.2, cx + rr, cy + rr * 1.8], fill=BULUT)


# ── C · İKİ YAY ──────────────────────────────────────────────────
# Radarın iki yayı birbirine DÖNÜK: iki kişi, karşılıklı sinyal.
# Ortada kalan boşluk bir "L" okutuyor (LoungeLink) ve aynı zamanda
# bir kapı aralığı. Söylediği: "karşılıklılık".
def c_iki_yay(d, cx, cy, s):
    w = max(3, int(s * 0.105))
    yay(d, cx - s * 0.16, cy, s * 0.40, 300, 60, w, ALTIN)
    yay(d, cx + s * 0.16, cy, s * 0.40, 120, 240, w, TEAL)
    rr = s * 0.07
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=BULUT)


YONLER = [
    ("A · RADAR-ANAHTAR", a_radar_anahtar,
     "Sinyal + erişim. Keşfet sekmesinin işaretiyle AYNI kök —",
     "uygulamayı açan kişi logoyu zaten tanıyor olacak."),
    ("B · EŞİK", lambda d, x, y, s: b_esik(d, x, y, s),
     "Host altın, misafir teal, aralarında açılan kapı.",
     "Ürünün tek cümlesinin resmi. En anlatıcı, en az soyut."),
    ("C · İKİ YAY", lambda d, x, y, s: c_iki_yay(d, x, y, s),
     "Karşılıklı sinyal. Negatif boşlukta bir 'L' ve bir kapı.",
     "En sade; küçük boyutta (16px favicon) en dayanıklısı."),
]


def main():
    W, H = 1500, 420 * len(YONLER) + 180
    im = Image.new("RGB", (W, H), GECE)
    d = ImageDraw.Draw(im)
    b = f("PlusJakartaSans-Bold.ttf", 30)
    sm = f("PlusJakartaSans-SemiBold.ttf", 19)
    rg = f("PlusJakartaSans-Regular.ttf", 18)
    mk = f("PlusJakartaSans-Bold.ttf", 26)

    d.text((60, 46), "LOGO ÖNERİSİ — UYGULANMADI, ONAY BEKLİYOR", font=b,
           fill=ALTIN)
    d.text((60, 92),
           "Üçü de ürünün İÇİNDEN çıkan işaretler: radar (Keşfet), kalkan (doğrulama), eşik (kapı).",
           font=rg, fill=SESSIZ)
    d.text((60, 118),
           "Bugünkü swoosh havacılıkta jenerik — 'havacılık' der, 'LoungeLink' demez.",
           font=rg, fill=SESSIZ)

    for i, (ad, ciz, s1, s2) in enumerate(YONLER):
        y0 = 180 + i * 420
        d.rounded_rectangle([46, y0, W - 46, y0 + 380], 20,
                            outline=(58, 52, 46), width=2)
        # büyük · gece zemin
        ciz(d, 190, y0 + 150, 150)
        # orta · altın zeminde koyu (tersine çevrilebilir mi?)
        d.rounded_rectangle([330, y0 + 70, 490, y0 + 230], 34, fill=ALTIND)
        kucuk = Image.new("RGB", (160, 160), ALTIND)
        kd = ImageDraw.Draw(kucuk)
        if i == 0:
            a_radar_anahtar(kd, 80, 80, 62, renk=(23, 16, 9))
        elif i == 1:
            b_esik(kd, 80, 80, 62)
        else:
            c_iki_yay(kd, 80, 80, 62)
        im.paste(kucuk, (330, y0 + 70))
        d.rounded_rectangle([330, y0 + 70, 490, y0 + 230], 34,
                            outline=(58, 52, 46), width=0)
        # küçük · 40px ve 20px dayanıklılık testi
        for j, boy in enumerate((44, 22)):
            ciz(d, 560 + j * 90, y0 + 150, boy)
        d.text((560, y0 + 210), "44px", font=rg, fill=SESSIZ)
        d.text((648, y0 + 210), "22px", font=rg, fill=SESSIZ)

        # kilitleme (lockup)
        ciz(d, 790, y0 + 118, 46)
        d.text((840, y0 + 104), "L O U N G E L I N K", font=mk, fill=BULUT)

        d.text((790, y0 + 186), ad, font=b, fill=ALTIN)
        d.text((790, y0 + 232), s1, font=sm, fill=BULUT)
        d.text((790, y0 + 262), s2, font=rg, fill=SESSIZ)

    im.save(CIKTI)
    print("✓ %s  %s" % (os.path.relpath(CIKTI, HERE), im.size))
    print("  ⚠ HİÇBİR ÜRÜN DOSYASI DEĞİŞMEDİ — bu yalnız bir öneri sayfası.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
