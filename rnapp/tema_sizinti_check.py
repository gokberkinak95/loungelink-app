#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tema_sizinti_check.py

============================================================================
TEMA SIZINTISI — PALETİN DIŞINDAN GELEN RENK

🔴 NEDEN VAR — 20 EYLÜL

`theme.js` 1700 satır boyunca her rengi ölçüp gerekçelendiriyor. Ama
jeton sistemini KULLANMAK zorunlu değildi. Taradım ve iki sınıf sızıntı
buldum — ikisi de sessiz, ikisi de gözle fark edilmez:

  1 · SOĞUK TON.  `#2E3647` → hue **277°** (menekşe-mavi).
      Obsidyen sistemi 73-88° arası SICAK bir bant. `theme.js` bu hatayı
      bir kez düzeltmiş ("eski `ink` 225° maviydi") ama çağrı yerlerinden
      biri eski dünyada kalmış.

  2 · ÇİĞ ALTIN.  `rgba(224,190,122,…)` → #E0BE7A · **C* 38.9**.
      Şampanya kararı tam da bunu reddetti: "çiğ altın sarısı lüks
      algısını ucuzlatır", C* 40.2 → 20.4. Değer iki ekranda yaşıyordu.

🆕 SINIF: "BİR PALETİ JETONLAŞTIRMAK YETMEZ — JETONU ATLAMAYI DA
İMKÂNSIZ KIL. ATLANABİLEN BİR JETON, BİR SÜRE SONRA ATLANIR."

NE ÖLÇÜYOR
  `src/` ve `App.js` içindeki HER sabit renk değerini (hex ve rgba).
  Her birini Lab'a çevirip iki soruyu sorar:
    · hue sıcak bandın (45°-120°) dışında mı?   → soğuk sızıntı
    · kroma marka tavanını (C* 28) aşıyor mu?   → çiğ renk

NEYİ ÖLÇMÜYOR — ve neden
  · `theme.js`in kendisi: paletin tanımlandığı yer orası.
  · NÖTR renkler (C* ≤ 6): siyah, beyaz, gri perdeler. Bunların hue'su
    yoktur ve sistemin her yerinde meşrudur.
  · Yorum satırları: tasarım CSS'ini alıntılayan yorumlar var; bir
    nöbetçinin kendi açıklamasını bulgu sayması daha önce yaşandı.

TAVAN 0. İlk koşuşta 12 bulgu vardı; hepsi gerçek sızıntı çıktı ve
jetonlaştırıldı (bkz. TAVAN tanımının yanındaki not).
============================================================================
"""
import os
import re
import sys

import numpy as np
from skimage import color as _renk

KOK = os.path.dirname(os.path.abspath(__file__))

SICAK_ALT, SICAK_UST = 45.0, 120.0     # sistemin sıcak bandı
KROMA_TAVAN = 28.0                     # marka 20.1 + pay
NOTR_ESIK = 6.0                        # bunun altında hue anlamsız

# TAVAN 0.
# İlk koşuşta 12 bulgu vardı ve tavanı oraya kalibre etmiştim — "mevcut
# hâli kabul et, artışı yakala" mantığıyla. Sonra hepsine tek tek baktım
# ve ONİKİSİ DE GERÇEK SIZINTIYDI: `atmosfer.js`in 10 duraklı gün batımı
# rampası (kroma 48'e kadar), ham amber çizgi, açık temanın altını.
# Hepsi jetonlaştırıldı → 0.
#
# 🆕 SINIF: "BİR TAVANI MEVCUT HÂLE KALİBRE ETMEK, O HÂLİ DOĞRU
# SAYMAKTIR. ÖNCE HER BULGUYA BAK — TAVAN ANCAK BAKTIKTAN SONRA KONUR."
#
# Semantik renkler (uyarı kırmızısı, teal) paletin parçası ama sıcak
# bandın dışında olmak ZORUNDA. Onlar JETONDAN geliyor; bu kapı yalnız
# SABİT YAZILMIŞ değerleri sayar, o yüzden 0 sürdürülebilir bir tavan.
TAVAN = 0

HEX = re.compile(r'"#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})"')
RGBA = re.compile(r'"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)"')

ATLA_KLASOR = {"node_modules", ".git", "android", "ios", ".expo", "web_sahne",
               "assets", "brand", "tasarim_kaynak", "ekranlar_oneri", "dist",
               "dist_dbg", "render_check", "ekranlar_render", "__pycache__"}
ATLA_DOSYA = {"theme.js"}


def lch(r, g, b):
    a = np.array([[[r / 255.0, g / 255.0, b / 255.0]]])
    L, A, B = _renk.rgb2lab(a)[0, 0]
    return float(L), float(np.hypot(A, B)), float((np.degrees(np.arctan2(B, A)) + 360) % 360)


def kod(g):
    """Yorumları boşlukla değiştir — satır numarası korunur."""
    g = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), g, flags=re.S)
    return "\n".join(re.sub(r"//.*$", "", s) for s in g.split("\n"))


def main():
    bulgular = []
    taranan = 0
    for d, kl, do in os.walk(KOK):
        kl[:] = [k for k in kl if k not in ATLA_KLASOR]
        for f in do:
            if not f.endswith(".js") or f in ATLA_DOSYA:
                continue
            if f.startswith("check") or f.endswith("_check.js") or f == "verify.js":
                continue
            p = os.path.join(d, f)
            g = kod(open(p, encoding="utf-8", errors="replace").read())
            rel = os.path.relpath(p, KOK).replace(os.sep, "/")
            for i, satir in enumerate(g.split("\n"), 1):
                adaylar = []
                for m in HEX.finditer(satir):
                    h = m.group(1)
                    if len(h) == 3:
                        h = "".join(c * 2 for c in h)
                    adaylar.append((m.group(0), tuple(int(h[k:k + 2], 16) for k in (0, 2, 4))))
                for m in RGBA.finditer(satir):
                    adaylar.append((m.group(0), (int(m.group(1)), int(m.group(2)), int(m.group(3)))))
                for ham, (r, gg, b) in adaylar:
                    taranan += 1
                    _L, C, H = lch(r, gg, b)
                    if C <= NOTR_ESIK:
                        continue
                    if C > KROMA_TAVAN:
                        bulgular.append((rel, i, ham, "kroma C* %.1f > %.1f (çiğ renk)" % (C, KROMA_TAVAN)))
                    elif not (SICAK_ALT <= H <= SICAK_UST):
                        bulgular.append((rel, i, ham, "hue %.0f° sıcak bandın (%.0f-%.0f) dışında"
                                         % (H, SICAK_ALT, SICAK_UST)))

    print("=" * 74)
    print("TEMA SIZINTISI — theme.js dışında sabit yazılmış renk")
    print("=" * 74)
    print("  taranan sabit renk : %d" % taranan)
    print("  sistem dışı        : %d  (tavan %d)" % (len(bulgular), TAVAN))
    print("")
    for rel, i, ham, ne in sorted(bulgular):
        print("    %-34s %s  — %s" % ("%s:%d" % (rel, i), ham, ne))
    print("")
    if len(bulgular) > TAVAN:
        print("  ✗ SIZINTI ARTTI. Yeni bir renk paletin dışından girmiş.")
        print("    ÇÖZÜM: değeri `theme.js`e jeton olarak ekle ve buradan çağır.")
        print("    Obsidyen sistemi 45-120° sıcak banttır; şampanya C* 20.1.")
    else:
        print("  ✓ sızıntı sayısı tavanın altında — yeni sistem dışı renk yok")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    sys.exit(1 if len(bulgular) > TAVAN else 0)


main()
