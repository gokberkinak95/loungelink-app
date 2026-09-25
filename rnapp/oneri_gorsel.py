#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneri_gorsel.py — 12 Eylül premium önerisinin görselleri (GEÇİCİ)."""
import os
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/claude/teslim"
SAHNE = os.path.join(KOK, "web_sahne", "out", "oniz")
FD = os.path.join(KOK, "assets", "fonts")


def f(ad, boy):
    return ImageFont.truetype(os.path.join(FD, ad), boy)


R = lambda b: f("PlusJakartaSans-Regular.ttf", b)
M = lambda b: f("PlusJakartaSans-Medium.ttf", b)
B = lambda b: f("PlusJakartaSans-Bold.ttf", b)
MO = lambda b: f("JetBrainsMono-Medium.ttf", b)
SE = lambda b: f("CormorantGaramond-SemiBold.ttf", b)

ZEMIN = (11, 10, 11)
INK = (244, 239, 230)
DIM = (155, 145, 132)


def yaz(d, xy, s, fnt, renk=INK, orta=False):
    if orta:
        w = d.textlength(s, font=fnt)
        xy = (xy[0] - w / 2, xy[1])
    d.text(xy, s, font=fnt, fill=renk)


# ══════════════════════════════════════════════════════════════════
# 1 · PALET TAHTASI
# ══════════════════════════════════════════════════════════════════
def palet():
    W, H = 1820, 1080
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (60, 48), "LOUNGELINK · PREMIUM PALET ÖNERİSİ", B(30))
    yaz(d, (60, 92), "her jeton ölçüldü — L* · C* (kroma = 'çiğlik') · WCAG kontrast · dikromazi ΔE",
        R(20), DIM)

    def blok(x, y, baslik, satirlar, gen=760):
        yaz(d, (x, y), baslik, B(22), (201, 182, 147))
        yy = y + 40
        for ad, eski, yeni, not_ in satirlar:
            d.rounded_rectangle([x, yy, x + 78, yy + 46], 8, fill=eski)
            d.rounded_rectangle([x + 86, yy, x + 164, yy + 46], 8, fill=yeni)
            yaz(d, (x + 180, yy + 1), ad, M(19), INK)
            yaz(d, (x + 180, yy + 24), "%s  →  %s" % (eski, yeni), MO(15), (170, 160, 146))
            yaz(d, (x + 420, yy + 12), not_, R(16), DIM)
            yy += 60
        return yy

    y1 = blok(60, 160, "1 · ALTIN — çiğ sarı → mat şampanya", [
        ("Birincil düğme dolgusu", "#EBCD92", "#D9C8A6", "C* 33.3 → 16.4 · ışık aynı"),
        ("Marka altını / ikon", "#D1B56D", "#C9B693", "C* 40.2 → 20.4 · L* 74.6 → 74.8"),
        ("Altın metin", "#E0BE7A", "#D6C3A0", "aynı L*, yarı kroma"),
        ("Düğme gradyan alt ucu", "#C39B4C", "#B49B70", "ipeksi geçiş · sarı→kahve yok"),
        ("Altın tonlu zemin", "#2C2514", "#241F16", "sayfa ile ΔE 4.1"),
    ])

    y2 = blok(60, y1 + 40, "2 · ZEMİN — mor siyah → obsidyen", [
        ("Sayfa", "#100E12", "#0B0A0B", "hue 308° (mor) → 324° · C* 2.33 → 0.51"),
        ("Kart / yüzey", "#1C1820", "#141211", "katman farkı ΔE 6.24 → 3.02"),
        ("Blok / ikinci yüzey", "#241F28", "#1B1816", "ΔE 3.69 → 3.12"),
        ("Tel (hairline)", "#262222", "#23201D", "sıcak nötr — fotoğrafla erir"),
    ])

    y3 = blok(900, 160, "3 · NEON YOK — durum renkleri", [
        ("Canlı / turkuaz", "#12CDBC", "#9DBBA6", "C* 45.3 → 20 · 'fintech' hissi biter"),
        ("Karar: misafir ücretsiz", "#6FD9A8", "#EDE7DB", "fildişi — C* 44.5 → 6.5"),
        ("Karar: ücretli", "#FAA542", "#D9A45E", "C* 65.9 → 45.1"),
        ("Karar: girilmez", "#F2605D", "#C97E76", "C* 64.0 → 32.7"),
        ("İnsan çipi (mor)", "#C6AAF7", "#B7A8C6", "C* düşük — mor 'uygulama' değil 'kişi'"),
        ("Yıkıcı eylem", "#8E2E33", "#7E3A3C", "bağırmaz, kesinleşir"),
    ])

    yaz(d, (900, y3 + 24), "UYUM YÜZDESİ: HUE RAMPASI DEĞİL IŞIK RAMPASI", B(20), (201, 182, 147))
    ramp = [(">= 85", "#EDE7DB"), ("65–84", "#C9B693"), ("<= 64", "#A99D8C"), ("kapalı", "#8E8373")]
    xx = 900
    for et, h in ramp:
        d.rounded_rectangle([xx, y3 + 62, xx + 150, y3 + 112], 8, fill=h)
        yaz(d, (xx + 75, y3 + 76), et, B(20), (16, 14, 13), orta=True)
        yaz(d, (xx + 75, y3 + 120), h, MO(15), DIM, orta=True)
        xx += 166
    yaz(d, (900, y3 + 152),
        "Renk körü bir gözde yeşil→altın→gri sırası kayboluyordu; ışık sırası kaybolmaz.",
        R(17), DIM)

    yaz(d, (900, y3 + 210), "KARAR ÜÇLÜSÜ RENK KÖRÜ GÖZDE (ΔE76, eşik 25)", B(20), (201, 182, 147))
    tablo = [
        ("", "normal", "dötanopi", "protanopi"),
        ("bugün  yeşil / amber / kırmızı", "47.0", "29.8", "31.1"),
        ("öneri  fildişi/kehribar/gül", "33.2", "28.4", "32.0"),
        ("reddedilen  zümrüt/kehribar/gül", "33.2", "12.4  X", "10.5  X"),
    ]
    yy = y3 + 250
    for i, sat in enumerate(tablo):
        fnt = M(17) if i == 0 else R(17)
        renk = DIM if i == 0 else (INK if i < 3 else (201, 126, 118))
        yaz(d, (900, yy), sat[0], fnt, renk)
        for j, v in enumerate(sat[1:]):
            yaz(d, (1400 + j * 138, yy), v, MO(16), renk)
        yy += 32
    yaz(d, (900, yy + 10),
        "Yeşili zümrüde indirirsek 'girilmez' ile 'ücretsiz' renk körü gözde aynılaşıyor.",
        R(17), (201, 126, 118))
    yaz(d, (900, yy + 36), "Bu yüzden mat zümrüt DEĞİL fildişi öneriyorum.", M(17), INK)

    yaz(d, (60, H - 54), "ölçüm: rnapp/palet_oneri.py · WCAG 2.1 · CIELAB ΔE76 · Viénot-Brettel dikromazi",
        R(16), (110, 103, 95))
    im.save(os.path.join(OUT, "oneri_01_palet.png"))
    print("oneri_01_palet.png")


# ══════════════════════════════════════════════════════════════════
# 2 · EKRAN A/B
# ══════════════════════════════════════════════════════════════════
def ekranlar():
    ciftler = [("kesfet", "Keşfet"), ("kural", "Kural motoru"), ("ana", "Ana sayfa"),
               ("profil", "Profil"), ("tanis", "Tanış"), ("onb", "Tanıtım 5")]
    s = 3
    ornek = Image.open(os.path.join(SAHNE, "kesfet_a.png"))
    tw, th = ornek.width // s, ornek.height // s
    bas, ara, dip = 96, 26, 60
    W = len(ciftler) * (tw * 2 + ara + 46) + 40
    H = bas + th + dip
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (40, 30), "BUGÜN  ·  ÖNERİ   —   gerçek render, gerçek veri, aynı ağaç", B(30))
    x = 40
    for ad, et in ciftler:
        for i, k in enumerate(["a", "b"]):
            p = os.path.join(SAHNE, "%s_%s.png" % (ad, k))
            im.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS),
                     (x + i * (tw + ara), bas))
        yaz(d, (x + tw + ara / 2, bas + th + 14), et, M(22), INK, orta=True)
        yaz(d, (x + tw / 2, bas - 30), "bugün", R(18), (130, 122, 112), orta=True)
        yaz(d, (x + tw + ara + tw / 2, bas - 30), "öneri", R(18), (201, 182, 147), orta=True)
        x += tw * 2 + ara + 46
    im.save(os.path.join(OUT, "oneri_02_ekranlar_ab.jpg"), quality=88)
    print("oneri_02_ekranlar_ab.jpg", im.size)


# ══════════════════════════════════════════════════════════════════
# 3 · PERDE (tırtıklı geçiş)
# ══════════════════════════════════════════════════════════════════
def perde():
    y0, y1 = 620, 1960
    kes = lambda p: Image.open(os.path.join(SAHNE, p)).convert("RGB").crop((0, y0, 1170, y1))
    a, b = kes("perde_a.png"), kes("perde_b.png")
    s = 2
    tw, th = a.width // s, a.height // s
    W, H = tw * 2 + 150, th + 250
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 34), "ONBOARDING PERDESİ — 'tırtıklı görünüm'ün sebebi ve çözümü", B(30))
    yaz(d, (50, 76), "aynı sahne, aynı fotoğraf, tek fark: perdenin nasıl çizildiği", R(19), DIM)
    im.paste(a.resize((tw, th), Image.LANCZOS), (50, 130))
    im.paste(b.resize((tw, th), Image.LANCZOS), (tw + 100, 130))
    yaz(d, (50, 130 + th + 16), "BUGÜN — üst üste 24 View", M(22), INK)
    yaz(d, (50, 130 + th + 48),
        "bant sınırlarında 16 geçişin 13'ü gözle görülür\nortalama sıçrama 7.11/255 · en büyük 11.88",
        MO(17), (201, 126, 118))
    yaz(d, (tw + 100, 130 + th + 16), "ÖNERİ — tek gerilmiş PNG (512 adım)", M(22), INK)
    yaz(d, (tw + 100, 130 + th + 48),
        "görünür sıçrama 0/16\nortalama 0.85/255 · en büyük 2.39  (görme eşiği ~3)",
        MO(17), (157, 187, 166))
    yaz(d, (50, H - 52),
        "yeni bağımlılık YOK — assets/perde.png, resizeMode=\"stretch\" · ölçüm: gerçek render'ın piksel profili",
        R(17), (110, 103, 95))
    im.save(os.path.join(OUT, "oneri_03_perde.png"))
    print("oneri_03_perde.png", im.size)


# ══════════════════════════════════════════════════════════════════
# 4 · TANITIM 5 KART ZEMİNİ
# ══════════════════════════════════════════════════════════════════
def kart():
    y0, y1 = 1350, 2100
    kes = lambda p: Image.open(os.path.join(SAHNE, p)).convert("RGB").crop((0, y0, 1170, y1))
    ims = [kes("kart_a.png"), kes("kart_b.png"), kes("kart_c.png")]
    s = 2
    tw, th = ims[0].width // s, ims[0].height // s
    W, H = tw * 3 + 160, th + 300
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (40, 30), "TANITIM 5 — kartın zemini fotoğrafla uyuşmuyor", B(30))
    yaz(d, (40, 72), "üç aday, hepsi gerçek render; altındaki sayılar kartın EN PARLAK yerinde ölçüldü", R(19), DIM)
    etiket = [
        ("A · BUGÜN  opak #1C1820",
         "fotoğrafın önünde kesik bir levha\nüst etiket 4.90:1 · kanıt 6.41:1  (hepsi AA)", (201, 126, 118)),
        ("B · ÖNERİ  dumanlı cam %55",
         "zemin #382927 · üst etiket 3.88:1 (AA altı) · kanıt 5.08:1 (AA)\n→ küçük etiket dim→mutedAA olursa 5.08:1", (157, 187, 166)),
        ("C · çerçevesiz, altın çizgi",
         "zemin #433133 · üst etiket 3.41:1 · kanıt 4.46:1 — ikisi de AA altı\nzarif ama okunurluk AA'nın altına düşüyor", (201, 126, 118)),
    ]
    for i, (imm, (b1, b2, renk)) in enumerate(zip(ims, etiket)):
        x = 40 + i * (tw + 40)
        im.paste(imm.resize((tw, th), Image.LANCZOS), (x, 120))
        yaz(d, (x, 120 + th + 18), b1, M(21), INK)
        yaz(d, (x, 120 + th + 50), b2, MO(16), renk)
    yaz(d, (40, H - 52), "önerim: B + küçük etiketin mürekkebi bir basamak açılsın", M(20), (201, 182, 147))
    im.save(os.path.join(OUT, "oneri_04_tanitim_kart.png"))
    print("oneri_04_tanitim_kart.png", im.size)


if __name__ == "__main__":
    palet(); ekranlar(); perde(); kart()
