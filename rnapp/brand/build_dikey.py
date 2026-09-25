#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_dikey.py — dikey alfa rampası, TEK RGBA PNG (tintColor ile).

🔴 NEDEN VAR — 12 EYLÜL · PARİTE TURU
`cihaz_parite_check.py` aynı kalıbın İKİ KOPYASINI daha buldu:
    src/ui.js:1388         `FotoBant` mesh tabanı   (18 bant)
    src/MomentScreen.js:148 "an" ekranı mesh tabanı (18 bant)

Perdeyi ve düğmeyi tek PNG'ye çevirdim, bu ikisini ATLADIM — tam da
30 Ağustos'ta yazdığım "bir kalıbı düzelttiğinde kopyalarını ara"
dersinin üçüncü ve dördüncü kopyası. Bu sefer onları nöbetçi buldu,
ben değil; yani ders artık bir betiğe yazılı.

TEK DOSYA, İKİ KULLANICI: rampanın RGB'si önemsiz — `Image`in
`tintColor`u rengi çağrı yerinden alıyor, PNG yalnız ALFA taşıyor.
Böylece `meshUst` ve `meshUst2` aynı dosyayı paylaşıyor ve palet
değişince ikisi de kendiliğinden değişiyor.

Rampa DOĞRUSAL, çünkü değiştirdiği yığın da doğrusaldı
(`opacity: 1 - t`). Şeklini değiştirmek bir tasarım kararı olurdu;
burada yapılan iş yalnız "aynı şeyi dikişsiz çizmek".

🆕 SINIF: "AYNI İŞİ YAPAN İKİ KATMANI TEK DOSYAYA İNDİRİRKEN RENGİ
DOSYAYA GÖMME — RENK ÇAĞRI YERİNİN, DOSYA YALNIZ BİÇİMİN SAHİBİDİR."
"""
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image                                          # noqa: E402

YUK = 512
GEN = 4


def uret(yol=None):
    yol = yol or os.path.join(KOK, "assets", "dikey.png")
    im = Image.new("RGBA", (GEN, YUK))
    pik = im.load()
    for y in range(YUK):
        a = int(round((1 - y / (YUK - 1)) * 255))     # üstte opak, altta saydam
        for x in range(GEN):
            pik[x, y] = (255, 255, 255, a)
    im.save(yol, optimize=True)
    return yol, im.size


if __name__ == "__main__":
    print(uret())
