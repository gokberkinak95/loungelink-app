#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_parilti.py — GEÇİŞ KARTININ PARILTI ŞERİDİ (tek RGBA PNG).

🔴 NEDEN VAR — 12 EYLÜL · GECE
Gökberk'in vizyon listesi: "VIP geçiş kartı, telefonu eğince üzerinde
ışık gezinsin — elinde metal bir kart varmış gibi."

Fizik: cilalı bir yüzeyde gördüğün şey ışık kaynağının kendisi değil,
onun DAR ve YUMUŞAK bir yansımasıdır. Bu yüzden şerit ne düz bir
dikdörtgen (o "bir şey geçti" der, "parladı" demez) ne de ekranın
yarısı kadar geniş bir bulut (o sis olur). Gauss profili, tepe
noktasında %100, iki yanda hızla sönen.

⚠️ DOSYA YALNIZ ALFA TAŞIR. RGB'si beyaz; gerçek şiddet çağrı yerindeki
`opacity` ile veriliyor. Sebebi `build_dikey.py`dekiyle aynı ders:
rengi dosyaya gömersen palet değiştiğinde dosya yalan söylemeye başlar.

⚠️ NEDEN PNG, NEDEN GRADYAN KÜTÜPHANESİ DEĞİL: bu projede gradyan
kütüphanesi YOK ve eklemedim (bkz. atmosfer.js). 20 View'lık bant
yığınları alt piksel yuvarlamasıyla 1px boşluk bırakıyor — düğmelerdeki
"çizgi" şikâyetinin ölçülmüş sebebi tam olarak buydu.

🆕 SINIF: "PARILTI BİR RENK DEĞİL BİR PROFİLDİR — YANLIŞ PROFİL, DOĞRU
RENKLE DE UCUZ GÖRÜNÜR."
"""
import math
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image                                          # noqa: E402

GEN = 256          # şeridin eni (yatay rampa)
YUK = 4            # dikeyde sabit → `stretch` ile uzatılıyor
SIGMA = 0.17       # Gauss yarıçapı (0–1 normalize)


def uret(yol=None):
    yol = yol or os.path.join(KOK, "assets", "parilti.png")
    im = Image.new("RGBA", (GEN, YUK))
    pik = im.load()
    for x in range(GEN):
        t = x / (GEN - 1) - 0.5
        a = int(round(255 * math.exp(-(t * t) / (2 * SIGMA * SIGMA))))
        for y in range(YUK):
            pik[x, y] = (255, 255, 255, a)
    im.save(yol, optimize=True)
    return yol, im.size


if __name__ == "__main__":
    print(uret())
