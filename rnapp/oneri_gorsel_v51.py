#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneri_gorsel_v51.py — v5.2.0 düzeltme ve yenilik görselleri."""
import os
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/claude/teslim"
YENI = os.path.join(KOK, "web_sahne", "out")
SCR = "/tmp/claude-0/-home-claude/44c7d9d7-31fd-5659-8fd6-d3411a6d7cac/scratchpad"
FD = os.path.join(KOK, "assets", "fonts")

f = lambda a, b: ImageFont.truetype(os.path.join(FD, a), b)
R = lambda b: f("PlusJakartaSans-Regular.ttf", b)
M = lambda b: f("PlusJakartaSans-Medium.ttf", b)
B = lambda b: f("PlusJakartaSans-Bold.ttf", b)
MO = lambda b: f("JetBrainsMono-Medium.ttf", b)

ZEMIN = (11, 10, 11)
INK = (244, 239, 230)
DIM = (150, 140, 128)
ALT = (201, 182, 147)
KOTU = (217, 147, 139)
IYI = (157, 187, 166)


def yaz(d, xy, s, fnt, renk=INK, orta=False):
    if orta:
        xy = (xy[0] - d.textlength(s, font=fnt) / 2, xy[1])
    d.text(xy, s, font=fnt, fill=renk)


def duzeltmeler():
    once_b = Image.open(os.path.join(SCR, "dugme.png")).convert("RGB")
    sonra_b = Image.open(os.path.join(SCR, "dugme3.png")).convert("RGB")
    once_a = Image.open(os.path.join(SCR, "alt.png")).convert("RGB")
    sonra_a = Image.open(os.path.join(YENI, "15_tanitim.png")).convert("RGB") \
        .crop((0, 2050, 1170, 2532)).resize((585, 241), Image.LANCZOS)

    W, H = 1500, 1180
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 34), "v5.2.0 — İŞARETLEDİĞİN İKİ KUSUR", B(34))
    yaz(d, (50, 80), "ikisi de benim kendi değişikliklerimin yan etkisiydi; ikisi de ölçüldü", R(20), DIM)

    # ── 1 · düğme çizgisi
    yaz(d, (50, 150), "1 · \"TÜM BUTONLARDA BİR ÇİZGİ OLUŞMUŞ\"", B(24), ALT)
    yb = 195
    for i, (imm, et) in enumerate([(once_b, "ÖNCE"), (sonra_b, "SONRA")]):
        x = 50 + i * 720
        w = 660
        h = int(imm.height * w / imm.width)
        im.paste(imm.resize((w, h), Image.LANCZOS), (x, yb))
        yaz(d, (x, yb + h + 8), et, M(19), DIM)
    yaz(d, (50, yb + 150),
        "Sebep bir FAZLALIK değil bir EKSİKLİK: gradyan 20 ayrı View'dı ve yüzdeler\n"
        "cihaz pikseline yuvarlanınca bazı sınırlarda 1px boşluk kalıp düğmenin\n"
        "çıplak taban rengi görünüyordu. Yarıçapı 12'den hapa çıkarınca ortaya çıktı.",
        R(19), INK)
    yaz(d, (50, yb + 250),
        "düğme içinde en büyük dikey sıçrama:  46.89/255  →  5.86/255\n"
        "(kalan 5.86, bilerek konan 1px üst ışığın kendisi)",
        MO(19), IYI)
    yaz(d, (50, yb + 310), "çözüm: assets/altin.png — üç duraklı, 512 satır, tek Image", R(18), DIM)

    # ── 2 · alttaki gri alan
    y2 = 640
    yaz(d, (50, y2), "2 · \"ALTTAKİ GRİ ALAN UYUMSUZ VE DİKKAT ÇEKİCİ\"", B(24), ALT)
    yb2 = y2 + 45
    for i, (imm, et) in enumerate([(once_a, "ÖNCE"), (sonra_a, "SONRA")]):
        x = 50 + i * 720
        w = 660
        h = int(imm.height * w / imm.width)
        im.paste(imm.resize((w, h), Image.LANCZOS), (x, yb2))
        yaz(d, (x, yb2 + h + 8), et, M(19), DIM)
    yaz(d, (50, yb2 + 310),
        "Perdenin GÜCÜ değil BOYU eksikti: `bottom:0` verilmiş bir Image kendi içsel\n"
        "boyunu (512px) tercih edip kısıtı yok sayıyor — perde 715pt'de bitiyordu,\n"
        "altındaki ~130pt'de fotoğrafın soğuk kabin mavisi çıplak duruyordu.",
        R(19), INK)
    yaz(d, (50, yb2 + 410),
        "ekranın dibi:   #1D1E29  ΔE 11.63 · hue 289° · C* 8.01\n"
        "          →     #0B0A0B  ΔE  0.00 · hue 324° · C* 0.51   (sayfanın kendisi)",
        MO(19), IYI)
    im.save(os.path.join(OUT, "v51_duzeltmeler.png"))
    print("v51_duzeltmeler.png", im.size)


SAHNE = [
    ("01_splash", "Açılış"), ("15_tanitim", "Tanıtım 1"), ("15b_tanitim3", "Tanıtım 3"),
    ("15c_tanitim_kart", "Tanıtım 5 · kural motoru"), ("16_giris", "Giriş"), ("17_kayit", "Kayıt"),
    ("11_ana_misafir", "Ana sayfa · misafir"), ("12_ana_host", "Ana sayfa · host"),
    ("18_ana_host1", "Ana sayfa · host (aksiyon)"), ("19_ana_guest1", "Ana sayfa · misafir (aksiyon)"),
    ("02_kesfet", "Keşfet"), ("03_kural", "Kural motoru"),
    ("05_tanis", "Tanış"), ("05b_baglanti_kur", "Tanış · bağlantı"),
    ("13_baglantilar", "Bağlantılarım"), ("06_sohbet", "Sohbet"), ("06b_sohbet_tanis", "Sohbet · tanış"),
    ("14_seyahatler", "Planım · seyahatler"), ("14b_seyahatler_host", "Planım · host"),
    ("12b_ilanlarim", "Planım · ilanlarım"),
    ("09_profil", "Profil · host"), ("09b_profil_misafir", "Profil · misafir"),
    ("10_bildirim", "Bildirimler"),
]


def tum_ekranlar():
    s = 4
    ornek = Image.open(os.path.join(YENI, SAHNE[0][0] + ".png"))
    tw, th = ornek.width // s, ornek.height // s
    kol, bas, bosl, alt = 6, 108, 26, 40
    sat = (len(SAHNE) + kol - 1) // kol
    W = kol * tw + (kol + 1) * bosl
    H = bas + sat * (th + alt) + bosl
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (bosl, 30), "LOUNGELINK · v5.2.0 — 23 EKRANIN TAMAMI", B(34))
    yaz(d, (bosl, 74), "gerçek React ağacı · gerçek veri · gerçek RLS · obsidyen + şampanya", R(20), DIM)
    for i, (ad, et) in enumerate(SAHNE):
        x = bosl + (i % kol) * (tw + bosl)
        y = bas + (i // kol) * (th + alt)
        p = os.path.join(YENI, ad + ".png")
        if not os.path.exists(p):
            continue
        im.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y))
        yaz(d, (x + tw / 2, y + th + 10), et, M(18), INK, orta=True)
    im.save(os.path.join(OUT, "TUM_EKRANLAR_v5.2.0.jpg"), quality=86)
    print("TUM_EKRANLAR_v5.2.0.jpg", im.size)


if __name__ == "__main__":
    duzeltmeler(); tum_ekranlar()
