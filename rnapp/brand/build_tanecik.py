#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_tanecik.py — EKRANIN ÜSTÜNE SERİLEN GÖRÜNMEZ GREN (dither).

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK md.3:
"iç ekranların ortasında tırtıklı halde geçiş tonu var, ayrıca header
alanındaki görseller de tırtıklı gibi. Daha önce konuştuğumuz gibi
tırtıklı görünümler app geneli olmamalı çünkü bozuk görüntü hissiyatı
yaratıyor."

ÖLÇÜM (gerçek sahne görüntüsü, 41_bildirim_bos, @3x):
  ufuk kuşağı 11 → 24 arasında yalnız **14 ayrı ton** taşıyor
  her ton ekranda **5.3 pt** genişliğinde DÜZ bir şerit kaplıyor (maks 6.7)
  komşu piksel gürültüsü σ = 0.14  → yani şeritlerin kenarı tertemiz
Göz, düz bir alanda 1/255'lik bir basamağı bile KENAR olarak görür
(Mach bandı). Sorun ne fotoğrafta ne de gradyanda: **8 bit, koyu zeminde
yumuşak bir geçişe yetmiyor.**

`build_perde.py` (12 Eylül, sabah) aynı kusuru KATMAN SAYISINI artırarak
çözmüştü — 24 View yerine 512 satırlık PNG. O çözüm perde için işe
yaradı çünkü perdenin genliği büyüktü (0→255). Burada genlik 13; kaç
katman koyarsan koy 8 bit 13'ten fazla ton üretemez.

ÇÖZÜM — DITHER. Ekranın üstüne ±1 tonluk, göze görünmeyen bir gren
serilir; basamak sınırları rastgele piksellere dağılır ve şerit kaybolur.

ÖLÇÜM (aynı sahne, gerçek tarayıcı çıktısı, alfa 1/255):
  düz şerit genişliği  5.3 pt → **1.3 pt**
  komşu piksel σ        0.14 → **0.50**  (1 tondan KÜÇÜK — gren görünmez)
  zemin ortalaması      11.0 → 10.19     (-0.8 ton, görme eşiğinin altında)

DOZ SEÇİMİ — VE BİR DÜZELTME. Simülasyonda α = 0.008 (alfa 2/255)
çıkmıştı; gerçek tarayıcıda ölçtüm, fazla geldi (σ 1.83). Simülasyonun
bilmediği şey: tarayıcı yarı saydam kaplamayı yuvarlarken zaten ±1 ton
üretiyor, yani işin yarısını kendisi yapıyor. Alfa 1/255 hem şeridi
dağıtıyor hem greni ölçüm eşiğinin altında tutuyor.
🆕 SINIF: "SİMÜLASYON DOZU SEÇER, ÖLÇÜM DOZU ONAYLAR."

GREN BOYU: PNG 128×128 ve `resizeMode="repeat"` ile DP boyunda döşeniyor
→ 3x bir cihazda her gren tanesi 3×3 aygıt pikseli = 1 pt. Tek tek
görülmeyecek kadar küçük, bilgiyi taşıyacak kadar büyük.

🆕 SINIF: "BİR GEÇİŞ 8 BİTE SIĞMIYORSA ÇÖZÜM DAHA ÇOK KATMAN DEĞİL,
GÜRÜLTÜDÜR — BASAMAĞI YOK EDEMEZSİN, YALNIZ KENARINI DAĞITABİLİRSİN."
"""
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image                     # noqa: E402
import numpy as np                        # noqa: E402

BOY = 128          # döşeme kenarı (DP)
ALFA = 1           # 2/255 = 0.00784  — ölçülen doz
TOHUM = 20260912   # aynı dosya her koşuda birebir aynı çıksın


def uret(yol=None):
    yol = yol or os.path.join(KOK, "assets", "tanecik.png")
    rng = np.random.default_rng(TOHUM)
    n = rng.integers(0, 2, size=(BOY, BOY), dtype=np.uint8) * 255
    a = np.zeros((BOY, BOY, 4), dtype=np.uint8)
    a[..., 0] = a[..., 1] = a[..., 2] = n
    a[..., 3] = ALFA
    im = Image.fromarray(a, "RGBA")
    im.save(yol, optimize=True)
    return yol, im.size, os.path.getsize(yol)


if __name__ == "__main__":
    y, b, k = uret()
    print("%s  %s  %.1f KB  alfa=%d/255" % (os.path.basename(y), b, k / 1024, ALFA))
