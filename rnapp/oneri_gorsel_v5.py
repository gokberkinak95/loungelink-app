#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneri_gorsel_v5.py — v5.0.0 premium turunun teslim görselleri."""
import os
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/claude/teslim"
YENI = os.path.join(KOK, "web_sahne", "out")            # v5.0.0 (bugünkü kod)
ESKI = os.path.join(KOK, "web_sahne", "out", "oniz")    # v4.16.0 karşılaştırma çekimleri
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


def yaz(d, xy, s, fnt, renk=INK, orta=False):
    if orta:
        xy = (xy[0] - d.textlength(s, font=fnt) / 2, xy[1])
    d.text(xy, s, font=fnt, fill=renk)


# ── 1 · TÜM EKRANLAR ────────────────────────────────────────────────
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
    yaz(d, (bosl, 30), "LOUNGELINK · v5.0.0 — 23 EKRANIN TAMAMI", B(34))
    yaz(d, (bosl, 74), "gerçek React ağacı · gerçek veri · gerçek RLS · obsidyen + şampanya paleti", R(20), DIM)
    for i, (ad, et) in enumerate(SAHNE):
        x = bosl + (i % kol) * (tw + bosl)
        y = bas + (i // kol) * (th + alt)
        p = os.path.join(YENI, ad + ".png")
        if not os.path.exists(p):
            continue
        im.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y))
        yaz(d, (x + tw / 2, y + th + 10), et, M(18), INK, orta=True)
    im.save(os.path.join(OUT, "TUM_EKRANLAR_v5.0.0.jpg"), quality=86)
    print("TUM_EKRANLAR_v5.0.0.jpg", im.size)


# ── 2 · ÖNCE / SONRA ────────────────────────────────────────────────
def once_sonra():
    ciftler = [("kesfet_a", "02_kesfet", "Keşfet"), ("kural_a", "03_kural", "Kural motoru"),
               ("ana_a", "11_ana_misafir", "Ana sayfa"), ("profil_a", "09_profil", "Profil"),
               ("tanis_a", "05_tanis", "Tanış"), ("onb_a", "15c_tanitim_kart", "Tanıtım 5")]
    s = 3
    ornek = Image.open(os.path.join(ESKI, "kesfet_a.png"))
    tw, th = ornek.width // s, ornek.height // s
    bas, ara, dip = 104, 24, 62
    W = len(ciftler) * (tw * 2 + ara + 48) + 40
    H = bas + th + dip
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (40, 28), "v4.16.0  ·  v5.0.0    —    aynı ağaç, aynı veri, aynı sahne", B(32))
    yaz(d, (40, 72), "tek değişen: tasarım sistemi", R(19), DIM)
    x = 40
    for a, b, et in ciftler:
        im.paste(Image.open(os.path.join(ESKI, a + ".png")).convert("RGB").resize((tw, th), Image.LANCZOS), (x, bas))
        im.paste(Image.open(os.path.join(YENI, b + ".png")).convert("RGB").resize((tw, th), Image.LANCZOS),
                 (x + tw + ara, bas))
        yaz(d, (x + tw + ara / 2, bas + th + 14), et, M(22), INK, orta=True)
        yaz(d, (x + tw / 2, bas - 28), "önce", R(18), (125, 117, 108), orta=True)
        yaz(d, (x + tw + ara + tw / 2, bas - 28), "sonra", R(18), ALT, orta=True)
        x += tw * 2 + ara + 48
    im.save(os.path.join(OUT, "v5_once_sonra.jpg"), quality=88)
    print("v5_once_sonra.jpg", im.size)


# ── 3 · DARALAN BANT ────────────────────────────────────────────────
def daralan():
    ims = [Image.open(os.path.join(ESKI, "bant%d.png" % i)).convert("RGB") for i in range(3)]
    s = 2
    tw, th = ims[0].width // s, ims[0].height // s
    W, H = tw * 3 + 160, th + 300
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (40, 30), "DARALAN ÜST BANT — 199pt → 84pt", B(32))
    yaz(d, (40, 74), "aynı ekran, üç kaydırma konumu · gerçek render (390×844)", R(19), DIM)
    et = [("kaydırma 0", "bant tam boy · 198.7pt\nkaydırılabilir pencere 535pt (%63.4)", DIM),
          ("kaydırma 70", "bant yukarı kayıyor, içerik sönüyor\nkompakt çubuk belirmeye başladı", DIM),
          ("kaydırma 220", "bant 84pt · serif ad + eylem kaldı\npencere 650pt (%77) — +115pt = +%21.5", (157, 187, 166))]
    for i, (imm, (b1, b2, renk)) in enumerate(zip(ims, et)):
        x = 40 + i * (tw + 40)
        im.paste(imm.resize((tw, th), Image.LANCZOS), (x, 120))
        yaz(d, (x, 120 + th + 18), b1, M(21), INK)
        yaz(d, (x, 120 + th + 50), b2, MO(16), renk)
    yaz(d, (40, H - 54),
        "Animated + useNativeDriver · yükseklik değil KONUM anime ediliyor (height native driver'a girmez)",
        R(17), (108, 101, 93))
    im.save(os.path.join(OUT, "v5_daralan_bant.png"))
    print("v5_daralan_bant.png", im.size)


# ── 4 · PERDE ───────────────────────────────────────────────────────
def perde():
    y0, y1 = 620, 1960
    a = Image.open(os.path.join(ESKI, "perde_a.png")).convert("RGB").crop((0, y0, 1170, y1))
    b = Image.open(os.path.join(YENI, "15_tanitim.png")).convert("RGB").crop((0, y0, 1170, y1))
    s = 2
    tw, th = a.width // s, a.height // s
    W, H = tw * 2 + 150, th + 250
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 32), "ONBOARDING PERDESİ — 'tırtıklı görünüm' kapandı", B(32))
    yaz(d, (50, 76), "aynı sahne, aynı fotoğraf; tek fark perdenin nasıl çizildiği", R(19), DIM)
    im.paste(a.resize((tw, th), Image.LANCZOS), (50, 130))
    im.paste(b.resize((tw, th), Image.LANCZOS), (tw + 100, 130))
    yaz(d, (50, 130 + th + 16), "v4.16.0 — üst üste 24 View", M(22), INK)
    yaz(d, (50, 130 + th + 48),
        "16 bant sınırının 13'ü gözle görülür\normalama 7.11/255 · en büyük 11.88", MO(17), (217, 147, 139))
    yaz(d, (tw + 100, 130 + th + 16), "v5.0.0 — tek gerilmiş PNG (512 adım)", M(22), INK)
    yaz(d, (tw + 100, 130 + th + 48),
        "görünür sıçrama 0/16\normalama 0.86/255 · en büyük 2.47   (eşik ~3)", MO(17), (157, 187, 166))
    yaz(d, (50, H - 54),
        "assets/perde.png · brand/build_perde.py (paletten üretiliyor) · yeni bağımlılık yok",
        R(17), (108, 101, 93))
    im.save(os.path.join(OUT, "v5_perde.png"))
    print("v5_perde.png", im.size)


if __name__ == "__main__":
    tum_ekranlar(); once_sonra(); daralan(); perde()
