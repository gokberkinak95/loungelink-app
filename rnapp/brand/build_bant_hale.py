#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_bant_hale.py — bandın iki halesi (radial-gradient) tek RGBA PNG.

Tasarım (`.ust.mesh`):
  radial-gradient(120% 92% at 82% -14%, altın .30 → 0)
  radial-gradient(112% 88% at  8%   6%, mavi  .20 → 0)

Hale kutuya ORANLI tanımlı (cx/cy/rx/ry yüzde) → PNG bandın boyuna
`resizeMode="stretch"` ile gerilince her yükseklikte BİREBİR aynı formül.
RN'de radial-gradient yok; 14 halkalı `Hale` yaklaşımı ölçüldü: yarıçapı
yarım (çap = 1.2·G iken tasarımda yarıçap 1.2·G), daire (tasarımda elips)
ve doğrusal olmayan düşüş → bant tasarımdan %35 daha koyuydu.

Çıktı: assets/bant_hale.png (1080×574 · BANT_ORAN) — mockup.radyal ile
AYNI fonksiyondan, yani önizlemeyle aynı piksel.
"""
import os, sys
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image
import mockup

def uret(yol=os.path.join(KOK, "assets", "bant_hale.png"), g=1080):
    yb = int(round(g * mockup.BANT_ORAN))
    P = mockup.Ekran().P
    kat = Image.new("RGBA", (g, yb), (0, 0, 0, 0))
    kat.alpha_composite(mockup.radyal((g, yb), P["gold"], 0.82, -0.14, 1.20, 0.92, 0.30))
    kat.alpha_composite(mockup.radyal((g, yb), P.get("purple", "#7FA8E8"), 0.08, 0.06, 1.12, 0.88, 0.20))
    kat.save(yol, optimize=True)
    return yol, kat.size

if __name__ == "__main__":
    print(uret())
