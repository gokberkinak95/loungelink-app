#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_altin.py — birincil düğmenin şampanya gradyanı, TEK PNG.

🔴 NEDEN VAR — 12 EYLÜL · AKŞAM, GÖKBERK: "başla, devam et, giriş yap vs
gibi tüm butonlarda bir çizgi oluşmuş."

Sebebi buldum ve beklediğimden ilginç çıktı. Düğme gradyanı 20 ayrı
`View` ile çiziliyordu; her bandın üstü `(i*100)/20 %`, yüksekliği
`100/20 %`. Kâğıt üstünde bindirme SIFIR — tam da 30 Ağustos'ta
"bindirme yeni bir çizgi üretir" diye düzelttiğim şey.

Ama tarayıcı/RN bu yüzdeleri CİHAZ PİKSELİNE yuvarlıyor ve bazı
sınırlarda **1 piksellik BOŞLUK** kalıyor. Gerçek render'da ölçtüm
(düğmenin metinsiz sol bölgesi, x 66–110pt):

    +10.7pt  bandın rengi   ← band 4'ün altı
    +11.0pt  ÇIPLAK ZEMİN   ← BOŞLUK (düğmenin kendi taban rengi)
    +12.0pt  bandın rengi   ← band 5'in üstü

Yani çizgi bir "fazlalık" değil bir EKSİKLİK: üç piksir boyunca düğmenin
kendi taban rengi görünüyor. Bindirme sıfırken çizgi üretmiyor sandığım
şey, yuvarlama yüzünden çizgi üretiyormuş.

🆕 SINIF: "SIFIR BİNDİRME DE BİR VARSAYIMDIR — ALT PİKSEL YUVARLAMASI
VARKEN 'TAM OTURUR' DİYE BİR ŞEY YOKTUR; BİTİŞİK ÇİZİLEN HER KATMAN
YA BİNDİRİR YA BOŞLUK BIRAKIR."

Çözüm perdeyle aynı: 512 satırlık tek opak PNG, `resizeMode="stretch"`.
Sıfır sınır, sıfır yuvarlama, 20 View yerine 1 Image.

Üç durak paletten okunuyor (`goldBtnUst → goldBtn → goldBtn2`), yani
şampanya değişirse düğme de değişir.
"""
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image                                          # noqa: E402
from tema_oku import hex_rgb, palet                            # noqa: E402

YUK = 512
GEN = 4
ORTA = 0.52          # gövde durağının yeri — "ipeksi" olan uzun orta bölge


def _karistir(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ════════════════════════════════════════════════════════════════════
# 🔴 18 EYLÜL — TEK PNG İKİ TEMAYA YETMİYORDU. ÖLÇÜLDÜ.
#
# Gökberk (md.5): "şampanya rengi tüm butonlarda sol tarafında bi
# sarılık var gibi. Tüm butonlarda kontrolü yap."
#
# Kontrol ettim ve görselin KENDİSİ temiz çıktı: `altin.png` 4×512,
# gradyan DİKEY, yatayda üç sütun da birebir aynı (210,192,157). Yani
# `resizeMode="stretch"` sol kenarda farklı bir ton üretemez.
#
# Ama gerçek render'ı iki temada ölçünce şu çıktı:
#
#     tema   düğme zemini   metin      çizilen gradyan
#     açık   #6E5620        #FFFFFF    #E2D4B8 → #B49B70   ← KOYU PALET
#     koyu   #B49B70        #17120B    #E2D4B8 → #B49B70
#
# Bu dosya gradyanı HER ZAMAN `palet("KOYU")`den üretiyordu. Yani AÇIK
# temada, açık temanın kendi altını (#8D712D → #6E5620) hiç çizilmiyor;
# onun yerine koyu temanın şampanyası çiziliyor ve üstüne BEYAZ metin
# basılıyor:
#
#     #FFFFFF / #D9C8A6 = 1.65:1      (WCAG AA: 4.5)
#     #FFFFFF / #E2D4B8 = 1.46:1
#
# Yani açık temada birincil düğmenin yazısı okunmuyor — ve düğmenin
# altındaki taban (#6E5620, doymuş zeytin-sarı) hapın kavisinde
# şampanyanın altından sızıyor. "Sarılık" diye okunan şey bu.
#
# 🆕 SINIF: "BİR PALETTEN ÜRETİLEN GÖRSEL BİR VARLIKTIR, BİR JETON
# DEĞİL — TEMA DEĞİŞTİĞİNDE JETON YENİDEN HESAPLANIR, GÖRSEL DURUR."
#
# Artık iki PNG var: `altin.png` (koyu) ve `altin_acik.png` (açık).
# Açık temanın uçları beyaz metinle 4.63:1 ve 6.97:1 — ikisi de AA.
# ════════════════════════════════════════════════════════════════════
def uret(yol=None, tema="KOYU"):
    ad = "altin.png" if tema == "KOYU" else "altin_acik.png"
    yol = yol or os.path.join(KOK, "assets", ad)
    K = palet(tema)
    ust = hex_rgb(K.get("goldBtnUst") or K["goldBtn"])
    orta = hex_rgb(K["goldBtn"])
    alt = hex_rgb(K["goldBtn2"])
    im = Image.new("RGB", (GEN, YUK))
    pik = im.load()
    for y in range(YUK):
        t = y / (YUK - 1)
        # smoothstep her iki parçada ayrı — durakta kırılma olmasın
        if t <= ORTA:
            u = t / ORTA
            c = _karistir(ust, orta, u * u * (3 - 2 * u))
        else:
            u = (t - ORTA) / (1 - ORTA)
            c = _karistir(orta, alt, u * u * (3 - 2 * u))
        for x in range(GEN):
            pik[x, y] = c
    im.save(yol, optimize=True)
    return yol, im.size


if __name__ == "__main__":
    print(uret("", "KOYU") if False else uret(None, "KOYU"))
    print(uret(None, "ACIK"))
