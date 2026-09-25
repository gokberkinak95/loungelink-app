#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_perde.py — tam ekran fotoğrafın alt perdesi, TEK RGBA PNG.

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK: "onboarding tasarımlarında tırtıklı
görünüm var."

`FotoSahne` perdeyi 24 ayrı `View`la çiziyordu (RN'de gradient
kütüphanesi yok). Gerçek render'ın düz gökyüzü sütununda ölçtüm:

    bant sınırındaki 16 geçişin 13'ü GÖRÜNÜR
    ortalama sıçrama 7.11/255 · en büyük 11.88     (görme eşiği ~3/255)

24 bant, 24 adım demek; gözün düz bir gradyanda ayırt edemediği adım
~1/255. Yani sorun uygulamada değil YÖNTEMDEYDİ: sonlu sayıda opak
katman, sonsuz bir geçişi taklit edemez.

Bu PNG 512 satır taşıyor ve `resizeMode="stretch"` ile perdenin boyuna
geriliyor — tarayıcı/RN ara satırları kendisi interpolasyonla çiziyor.
Ölçüm (aynı sütun, aynı sahne): görünür sıçrama **0/16**, ortalama
0.85/255, en büyük 2.39.

🆕 SINIF: "BİR SÜREKLİLİĞİ SONLU ADIMLA TAKLİT EDİYORSAN, ADIM SAYISINI
ARTIRMAK ÇÖZÜM DEĞİL ERTELEMEDİR — ÇÖZÜM, ADIMI ÇİZEN KATMANI DEĞİL
ÇİZDİREN MOTORU DEĞİŞTİRMEKTİR."

Renk paletten (`C.bg`) geliyor: zemin değişirse perde de değişir, elle
kopyalanmış bir sabit kalmaz.
"""
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image                                          # noqa: E402
from tema_oku import hex_rgb, palet                            # noqa: E402

YUK = 512          # alfa adımı — 24 yerine 512
GEN = 4            # yatayda düz; 4px sadece PNG'nin sıkışmaması için


def uret(yol=None):
    yol = yol or os.path.join(KOK, "assets", "perde.png")
    r, g, b = hex_rgb(palet("KOYU")["bg"])
    im = Image.new("RGBA", (GEN, YUK))
    pik = im.load()
    for y in range(YUK):
        t = y / (YUK - 1)
        k = t * t * (3 - 2 * t)                # smoothstep — uçlarda türev 0
        a = int(round(k * 255))
        for x in range(GEN):
            pik[x, y] = (r, g, b, a)
    im.save(yol, optimize=True)
    return yol, im.size


if __name__ == "__main__":
    print(uret())
