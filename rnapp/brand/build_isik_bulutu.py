# -*- coding: utf-8 -*-
"""
brand/build_isik_bulutu.py — v6.2 (K9 canlı zemin · K5 kapı ışığı)

Beyaz, yumuşak radial ışık bulutu: yalnız ALFA taşır, rengi `tintColor`
verir (atmosfer.js: altın + gece mavisi · MomentScreen: altın).
Gauss düşüşü + ±1.6 birimlik sabit tohumlu titreşim (dither): bulut
ekranda gerilince 8-bit alfa basamakları bant (tırtık) olarak görünmesin
diye — gren_check.py bunu ölçer.

Kullanım:  python brand/build_isik_bulutu.py   → assets/isik_bulutu.png
"""
import os
import numpy as np
from PIL import Image

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 512
y, x = np.mgrid[0:N, 0:N]
c = (N - 1) / 2
r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (N / 2)
a = np.clip(np.exp(-(r ** 2) / 0.18), 0, 1) * 255
a = a + np.random.default_rng(7).uniform(-1.6, 1.6, a.shape)
a = np.clip(a, 0, 255).astype(np.uint8)
im = np.zeros((N, N, 4), np.uint8)
im[..., 0:3] = 255
im[..., 3] = a
yol = os.path.join(KOK, "assets", "isik_bulutu.png")
Image.fromarray(im, "RGBA").save(yol, optimize=True)
print("yazildi:", yol)
