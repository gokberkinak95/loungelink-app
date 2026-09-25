#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/karsilastir.py — SOL: onaylanan tasarım (ekranlar_render) · SAĞ: gerçek render (web_sahne/out).
Çıktı: web_sahne/out/_karsilastirma.png (ve tek tek _cift_<ad>.png)
"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
TASARIM = os.path.join(KOK, "..", "ekranlar_render")
OUT = os.path.join(KOK, "out")
FONT = "/home/claude/rnapp/assets/fonts/PlusJakartaSans-SemiBold.ttf"

def yukle(yol, y):
    im = Image.open(yol).convert("RGB")
    g = int(im.size[0] * y / im.size[1])
    return im.resize((g, y), Image.LANCZOS)

def main(secim):
    Y = 844
    ciftler = []
    for png in sorted(glob.glob(os.path.join(OUT, "[0-9][0-9]_*.png"))):
        ad = os.path.basename(png)[:-4]
        if secim and ad not in secim: continue
        t = os.path.join(TASARIM, ad + ".png")
        if not os.path.exists(t): continue
        ciftler.append((ad, yukle(t, Y), yukle(png, Y)))
    if not ciftler: return
    ft = ImageFont.truetype(FONT, 14)
    ARA, UST = 24, 34
    gen = sum(a.size[0] + b.size[0] + 8 for _, a, b in ciftler) + ARA * (len(ciftler) + 1)
    sayfa = Image.new("RGB", (gen, Y + UST + 16), (24, 22, 28))
    d = ImageDraw.Draw(sayfa)
    x = ARA
    for ad, a, b in ciftler:
        d.text((x, 10), ad + "  ·  SOL tasarım · SAĞ gerçek render", font=ft, fill=(230, 220, 200))
        sayfa.paste(a, (x, UST)); x += a.size[0] + 8
        sayfa.paste(b, (x, UST)); x += b.size[0] + ARA
        cift = Image.new("RGB", (a.size[0] + b.size[0] + 8, Y), (24, 22, 28))
        cift.paste(a, (0, 0)); cift.paste(b, (a.size[0] + 8, 0))
        cift.save(os.path.join(OUT, "_cift_" + ad + ".png"))
    sayfa.save(os.path.join(OUT, "_karsilastirma.png"))
    print("→", os.path.join(OUT, "_karsilastirma.png"), len(ciftler), "çift")

if __name__ == "__main__":
    main(set(sys.argv[1:]))
