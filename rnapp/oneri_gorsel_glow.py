#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneri_gorsel_glow.py — "MODERN GLOW & SOFT GEOMETRY" ÖNİZLEMESİ.

⚠️ BU BİR ÖNERİDİR, UYGULAMA DEĞİL. Kod geçici olarak değiştirildi,
sahneler ÇEKİLDİ, sonra kaynak `_yedek_glow_20260912/`den geri alındı ve
52 kapı yeniden yeşil çıktı. Ekrandaki her piksel gerçek React ağacından,
gerçek veriden ve gerçek RLS'ten geliyor — çizim değil.

ÖNCE  : /tmp/once   (v5.4.0, üretimdeki hâl)
SONRA : /tmp/glow   (önerilen hâl)
"""
import os

from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/claude/teslim"
ONCE, SONRA = "/tmp/once", "/tmp/glow"
FD = os.path.join(KOK, "assets", "fonts")

f = lambda a, b: ImageFont.truetype(os.path.join(FD, a), b)
R = lambda b: f("PlusJakartaSans-Regular.ttf", b)
M = lambda b: f("PlusJakartaSans-Medium.ttf", b)
B = lambda b: f("PlusJakartaSans-Bold.ttf", b)
MO = lambda b: f("JetBrainsMono-Medium.ttf", b)
SR = lambda b: f("CormorantGaramond-SemiBold.ttf", b)

ZEMIN = (11, 10, 11)
INK = (244, 239, 230)
DIM = (150, 140, 128)
ALT = (201, 182, 147)
IYI = (157, 187, 166)
KOTU = (217, 147, 139)


def yaz(d, xy, s, fnt, renk=INK, orta=False):
    if orta:
        xy = (xy[0] - d.textlength(s, font=fnt) / 2, xy[1])
    d.text(xy, s, font=fnt, fill=renk)


def cerceve(d, kutu, renk=(64, 58, 51)):
    d.rectangle(kutu, outline=renk, width=1)


EKRANLAR = [
    ("02_kesfet", "KEŞFET", "kart çizgisiz · karar rozeti çerçevesiz · ↗ oku"),
    ("14_seyahatler", "PLANIM", "kart çizgisiz · 20pt iç boşluk · 14pt ritim"),
    ("09b_profil_misafir", "PROFİL", "şerit → asimetrik bento (%58/%38)"),
    ("21_cuzdan", "CÜZDAN", "geçiş kartı + çizgisiz liste"),
    ("06_sohbet", "SOHBET", "misafir mat şampanya · host dumanlı cam"),
    ("16_giris", "GİRİŞ", "çizgisiz giriş alanı · 16 köşe · ortam ışığı"),
    ("15_tanitim", "TANITIM", "asimetrik ortam ışığı (tepe %11)"),
    ("11_ana_misafir", "ANA SAYFA", "sekme çubuğunda çizgi yok"),
    ("03_kural", "KURAL MOTORU", "hüküm satırları çizgisiz"),
]


def ab_sayfa():
    s = 3
    ornek = Image.open(os.path.join(ONCE, EKRANLAR[0][0] + ".png"))
    tw, th = ornek.width // s, ornek.height // s
    kol = 3                      # her hücrede ÖNCE|SONRA çifti
    cift_w = tw * 2 + 14
    bosl, bas, alt = 34, 150, 96
    sat = (len(EKRANLAR) + kol - 1) // kol
    W = bosl + kol * (cift_w + bosl)
    H = bas + sat * (th + alt) + bosl
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (bosl, 28), "MODERN GLOW & SOFT GEOMETRY — ÖNERİ", B(38))
    yaz(d, (bosl, 78), "sol: v5.4.0 (üretimdeki hâl)   ·   sağ: öneri   —   gerçek render, "
                       "gerçek veri; kod geri alındı, 52 kapı yeşil", R(21), DIM)
    for i, (ad, et, nt) in enumerate(EKRANLAR):
        x = bosl + (i % kol) * (cift_w + bosl)
        y = bas + (i // kol) * (th + alt)
        for j, kok in enumerate((ONCE, SONRA)):
            p = os.path.join(kok, ad + ".png")
            if not os.path.exists(p):
                continue
            gx = x + j * (tw + 14)
            im.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (gx, y))
            cerceve(d, (gx, y, gx + tw, y + th), (90, 82, 72) if j else (48, 44, 40))
            yaz(d, (gx + tw / 2, y + th + 8), "ÖNCE" if j == 0 else "SONRA",
                MO(16), DIM if j == 0 else ALT, orta=True)
        yaz(d, (x + cift_w / 2, y + th + 34), et, B(23), INK, orta=True)
        yaz(d, (x + cift_w / 2, y + th + 62), nt, R(17), DIM, orta=True)
    im.save(os.path.join(OUT, "GLOW_ONERI_ab.jpg"), quality=88)
    print("GLOW_ONERI_ab.jpg", im.size)


# ── Detay levhası: kart · balon · bento · giriş alanı ────────────────
DETAY = [
    ("KEŞFET KARTI", "02_kesfet", (40, 700, 1130, 1480), (40, 640, 1130, 1420),
     ["kenarlık YOK — ayrışma 1px üst ışık + 14pt boşluk",
      "karar rozeti hap DEĞİL: ikon + fildişi metin, 24pt boşlukla ayrı",
      "eylem düğmesi kalktı, yerine ↗ (sağ ALT — sağ üst dolu, ölçüldü)",
      "iç boşluk 16 → 20, kartlar arası 12 → 14"]),
    ("SOHBET BALONU", "06_sohbet", (40, 440, 1130, 1220), (40, 440, 1130, 1220),
     ["misafir: mat şampanya #B49B70 dolgu · mürekkep #17120B = 6.97:1",
      "host: dumanlı cam rgba(20,18,17,0.55) → #100E0E · gövde 12.59:1",
      "saat mürekkebi %66 iken 3.74:1 (AA ALTI) → %80 · 5.07:1",
      "⚠️ uzun sohbette şampanya yüzey alanı büyüyor — ölçülmesi gereken risk"]),
    ("PROFİL BENTO", "09b_profil_misafir", (40, 660, 1130, 1180), (40, 660, 1130, 1180),
     ["şerit → %58/%38 asimetrik dört kutu, 16 köşe",
      "tek kutu fildişi (%4.5), komşusu şampanya (%5.5) sızdırıyor",
      "goldText 10.66:1 · mutedAA 6.91:1 — ikisi de rahat AA üstü",
      "kutuların kendi kenarlığı yok; her birinde 1px üst ışık"]),
    ("GİRİŞ ALANI", "16_giris", (40, 1180, 1130, 1700), (40, 1180, 1130, 1700),
     ["çizgi yok; zemin obsidyenden bir ton açık (bgAlt #1B1816)",
      "köşe 12 → 16 · metin 15.42:1 · yer tutucu 4.75:1",
      "odak parıltısı KODDA var, durağan karede görünmez (fildişi %12)",
      "⚠️ sensörsüz kanıt: odak halkası yalnız cihazda doğrulanabilir"]),
]


def detay_levhasi():
    W = 1720
    satir_h = 470
    H = 150 + len(DETAY) * satir_h + 40
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (46, 28), "ELEMAN BAZLI — NE DEĞİŞTİ, NEYİ ÖLÇTÜM", B(38))
    yaz(d, (46, 78), "her satırda solda ÖNCE, ortada SONRA, sağda ölçüm", R(21), DIM)
    y = 150
    for et, ad, ko, ks, notlar in DETAY:
        yaz(d, (46, y), et, B(25), ALT)
        gy = y + 36
        hh = satir_h - 110
        for j, (kok, kutu) in enumerate(((ONCE, ko), (SONRA, ks))):
            p = os.path.join(kok, ad + ".png")
            if not os.path.exists(p):
                continue
            g = Image.open(p).convert("RGB").crop(kutu)
            gw = int(g.width * hh / g.height)
            im.paste(g.resize((gw, hh), Image.LANCZOS), (46 + j * (gw + 20), gy))
            cerceve(d, (46 + j * (gw + 20), gy, 46 + j * (gw + 20) + gw, gy + hh),
                    (90, 82, 72) if j else (48, 44, 40))
            yaz(d, (46 + j * (gw + 20) + gw / 2, gy + hh + 6),
                "ÖNCE" if j == 0 else "SONRA", MO(15), DIM if j == 0 else ALT, orta=True)
        for k, satir in enumerate(notlar):
            renk = KOTU if satir.startswith("⚠️") else DIM
            yaz(d, (1100, gy + 10 + k * 34), satir, R(18), renk)
        y += satir_h
    im.save(os.path.join(OUT, "GLOW_ONERI_detay.jpg"), quality=90)
    print("GLOW_ONERI_detay.jpg", im.size)


if __name__ == "__main__":
    ab_sayfa()
    detay_levhasi()
