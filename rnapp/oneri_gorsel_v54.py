#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneri_gorsel_v54.py — v5.4.0 yenilik, ambiyans ve hareket görselleri.

Üretilenler (hepsi /home/claude/teslim altına):
  TUM_EKRANLAR_v5.4.0.jpg   — çekilen 39 sahnenin tamamı
  v54_yenilikler.png        — FIDS şeridi · geçiş kartı · canlı durum
  v54_ambiyans.jpg          — aynı ekran, günün dört kuşağı
  v54_hareket_seritleri.jpg — dört hareketin kare kare film şeridi
"""
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/claude/teslim"
YENI = os.path.join(KOK, "web_sahne", "out")
HRK = os.path.join(YENI, "hareket")
AMB = os.path.join(YENI, "ambiyans")
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
IYI = (157, 187, 166)


def yaz(d, xy, s, fnt, renk=INK, orta=False):
    if orta:
        xy = (xy[0] - d.textlength(s, font=fnt) / 2, xy[1])
    d.text(xy, s, font=fnt, fill=renk)


def cerceve(d, kutu, renk=(70, 64, 56)):
    d.rectangle(kutu, outline=renk, width=1)


# ══════════════════════════════════════════════════════════════════════
# 1 · YENİLİKLER — üç yüzey, kırpılmış ve büyütülmüş
# ══════════════════════════════════════════════════════════════════════
def yenilikler():
    sohbet = Image.open(os.path.join(YENI, "06_sohbet.png")).convert("RGB")
    cuzdan = Image.open(os.path.join(YENI, "21_cuzdan.png")).convert("RGB")
    canli = Image.open(os.path.join(YENI, "35_canli_durum.png")).convert("RGB")

    serit = sohbet.crop((40, 200, 1130, 360))                 # FIDS şeridi
    serit = serit.resize((serit.width, serit.height), Image.LANCZOS)
    kart = cuzdan.crop((50, 370, 1120, 880))                  # geçiş kartı
    cn = canli.crop((0, 260, 1170, 1700)).resize((585, 720), Image.LANCZOS)

    W, H = 1560, 1840
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 32), "v5.4.0 — VİZYON LİSTESİNDEN KALAN ÜÇ MADDE", B(34))
    yaz(d, (50, 78), "hepsi senin listenden; hepsi ölçülerek yapıldı", R(20), DIM)

    y = 140
    yaz(d, (50, y), "1 · SOHBETTE SPLIT-FLAP (FIDS) ŞERİDİ", B(24), ALT)
    yaz(d, (50, y + 34), "kalkışa kalan süre artık bir havalimanı panosu: her rakam kendi "
                         "yaprağında, 260 ms'de dönüyor", R(19), DIM)
    sw = min(1400, serit.width)
    sh = int(serit.height * sw / serit.width)
    im.paste(serit.resize((sw, sh), Image.LANCZOS), (50, y + 74))
    cerceve(d, (50, y + 74, 50 + sw, y + 74 + sh))
    yaz(d, (50, y + 74 + sh + 10),
        "dört yüzey: sabit üst (yeni) · sabit alt (eski) · düşen kapak · inen kapak",
        MO(17), DIM)

    y = 420
    yaz(d, (50, y), "2 · CÜZDANDA GEÇİŞ KARTI — EĞİME TEPKİ VEREN YÜZEY", B(24), ALT)
    yaz(d, (50, y + 34), "eski hâli ortalanmış bir etiketti (BAKİYE / 1240 / kredi); "
                         "artık kimlik taşıyan tek bir kart", R(19), DIM)
    kw = 720
    kh = int(kart.height * kw / kart.width)
    im.paste(kart.resize((kw, kh), Image.LANCZOS), (50, y + 74))
    cerceve(d, (50, y + 74, 50 + kw, y + 74 + kh))
    for i, s in enumerate([
            "· jiroskop (DeviceMotion) parıltının",
            "  YERİNİ sürüyor — kart dönmüyor",
            "· sensör yoksa açılışta tek süpürme;",
            "  ölü bir yüzey bırakmıyoruz",
            "· 3–4°'lik rotateY denendi ve bırakıldı:",
            "  metnin kenarını yumuşatıyor",
            "· üyelik no kullanıcı kimliğinden türüyor",
            "  — yeni sütun açılmadı",
            "· parıltı profili Gauss; düz şerit",
            "  'bir şey geçti' der, 'parladı' demez"]):
        yaz(d, (810, y + 84 + i * 32), s, R(18), DIM)

    y = 940
    yaz(d, (50, y), "3 · CANLI DURUM — GEREKÇELİ TEK BOŞLUK KAPANDI", B(24), ALT)
    yaz(d, (50, y + 34), "tohum dünyasına aktif oturum eklendi; ekran artık gerçek "
                         "veriyle ve kullanıcının kendi yolundan çekiliyor", R(19), DIM)
    im.paste(cn, (50, y + 74))
    cerceve(d, (50, y + 74, 50 + cn.width, y + 74 + cn.height))
    for i, s in enumerate([
            "Sohbet → yeşil canlı-durum şeridi → Canlı Durum",
            "",
            "Bu ekran iki turdur 'mount kapsamında' yeşil yanıyordu.",
            "İlk kez ÇEKİLİNCE bir kusur çıktı: 'Oturuma Git' düğmesi",
            "sağ kenardan 14 pt taşıyordu (width:100% + marginHorizontal).",
            "Mount taşmayı ölçmez; ancak gerçek sahne ölçer.",
            "",
            "İkinci kusur: '✓ Paylaşıldı' glifi metnin içindeydi ve",
            "yapışık çıkıyordu — onay işareti ayrı bir sütuna alındı.",
            "",
            "Her ikisi de düzeltildi ve nöbetçiye yazıldı",
            "(dugme_check.py · tam genişlik + yatay boşluk = taşma)."]):
        yaz(d, (680, y + 80 + i * 32), s, R(18), DIM if i else INK)

    im.save(os.path.join(OUT, "v54_yenilikler.png"))
    print("v54_yenilikler.png", im.size)


# ══════════════════════════════════════════════════════════════════════
# 2 · AMBİYANS — aynı ekran, dört kuşak
# ══════════════════════════════════════════════════════════════════════
def ambiyans():
    adlar = [("safak", "ŞAFAK · 05–09", "amber %8.5"),
             ("gunduz", "GÜNDÜZ · 09–17", "mutedAA %5.0"),
             ("aksam", "AKŞAM · 17–22", "sicak %7.0"),
             ("gece", "GECE · 22–05", "purple %5.5")]
    parcalar, ham = [], {}
    for ad, _, _ in adlar:
        p = os.path.join(AMB, "11_ana_misafir_%s.png" % ad)
        g = Image.open(p).convert("RGB")
        ham[ad] = np.asarray(g, dtype=np.int16)
        parcalar.append(g.resize((g.width // 3, g.height // 3), Image.LANCZOS))

    tw, th = parcalar[0].size
    W = 60 + 4 * tw + 3 * 30 + 60
    H = 150 + th + 246
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 32), "v5.4.0 — GÜNÜN SAATİNE GÖRE AMBİYANS", B(34))
    yaz(d, (50, 78), "değişen tek şey ufuk kuşağının tonu ve şiddeti — palet DEĞİL "
                     "(paleti saate bağlamak, ürünü günün yarısında ölçülmemiş kılardı)",
        R(19), DIM)
    for i, (ad, et, alt) in enumerate(adlar):
        x = 60 + i * (tw + 30)
        im.paste(parcalar[i], (x, 150))
        cerceve(d, (x, 150, x + tw, 150 + th))
        yaz(d, (x + tw / 2, 150 + th + 12), et, B(20), INK, orta=True)
        yaz(d, (x + tw / 2, 150 + th + 40), alt, MO(17), ALT, orta=True)

    y = 150 + th + 78
    yaz(d, (60, y), "ÖLÇÜM — kuşaklar arası piksel farkı (aynı ekran, aynı veri):", M(19), INK)
    satir = 0
    for i in range(4):
        for j in range(i + 1, 4):
            a, b = adlar[i][0], adlar[j][0]
            fark = np.abs(ham[a] - ham[b])
            yaz(d, (60 + (satir % 2) * 590, y + 30 + (satir // 2) * 28),
                "%-7s ↔ %-7s  en büyük %2d/255 · %6d piksel"
                % (a, b, int(fark.max()), int((fark.max(axis=2) > 2).sum())), MO(16), DIM)
            satir += 1
    yaz(d, (60, y + 136),
        "Kasıtlı olarak eşikte: doku_check.py dört dosyanın HER SATIRINDA dört mürekkebi "
        "ölçüyor; en kötü nokta şafakta dimAA 4.78 (AA 4.50).", R(18), IYI)
    im.save(os.path.join(OUT, "v54_ambiyans.jpg"), quality=90)
    print("v54_ambiyans.jpg", im.size)


# ══════════════════════════════════════════════════════════════════════
# 3 · HAREKET ŞERİTLERİ
# ══════════════════════════════════════════════════════════════════════
HAREKET = [
    ("parallax", "TANITIM · KADRAJ KAYMASI", None),
    ("muhur", "KURAL MOTORU · MÜHÜR", None),
    ("yaprak", "SOHBET · YAPRAK PANOSU", (20, 50, 320, 140)),
    ("parilti", "CÜZDAN · KART PARILTISI", (10, 120, 380, 300)),
]


def hareket():
    satirlar = []
    for ad, et, kutu in HAREKET:
        dosya = sorted((x for x in os.listdir(HRK) if x.startswith(ad + "_") and x.endswith(".png")),
                       key=lambda x: int(x.split("_")[1].split(".")[0]))
        if not dosya:
            continue
        kareler, farklar, t0, onc = [], [], None, None
        for x in dosya:
            t = int(x.split("_")[1].split(".")[0])
            t0 = t if t0 is None else t0
            g = Image.open(os.path.join(HRK, x)).convert("RGB")
            if kutu:
                g = g.crop(kutu)
            a = np.asarray(g, dtype=np.int16)
            farklar.append(None if onc is None else int((np.abs(a - onc).max(axis=2) > 8).sum()))
            onc = a
            kareler.append((t - t0, g))
        # 🔴 EN ÇOK 6 KARE — VE HANGİ 6'SI ÖLÇÜMLE SEÇİLİYOR.
        # `yaprak` 10 kare çekiyor çünkü yaprak saniyede bir kendiliğinden
        # dönüyor ve hangi saniyeye denk geleceğini bilemem. Şeride
        # hepsini koymak 10.000 piksel genişlik demekti; ilk 6'sını
        # koymak ise HAREKETİN OLMADIĞI 6 kareyi koymak olurdu.
        # Toplam farkı en büyük olan ardışık 6'lı pencere seçiliyor.
        if len(kareler) > 6:
            en, bas = -1, 0
            for i in range(len(kareler) - 5):
                t = sum(x or 0 for x in farklar[i + 1:i + 6])
                if t > en:
                    en, bas = t, i
            kareler = kareler[bas:bas + 6]
            farklar = [None] + farklar[bas + 1:bas + 6]
        satirlar.append((et, kareler, farklar))

    kh = 300
    genisler = []
    for et, kareler, _ in satirlar:
        g0 = kareler[0][1]
        genisler.append(int(g0.width * kh / g0.height))
    W = 60 + max(len(k) * (g + 12) for (_, k, _), g in zip(satirlar, genisler)) + 40
    H = 140 + len(satirlar) * (kh + 92)
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (50, 32), "v5.4.0 — HAREKET, KARE KARE", B(34))
    yaz(d, (50, 78), "durağan karede görünmeyen her şey burada; sayı = bir önceki kareye "
                     "göre değişen piksel (video → ffmpeg → piksel farkı)", R(19), DIM)
    y = 140
    for (et, kareler, farklar), gw in zip(satirlar, genisler):
        yaz(d, (50, y), et, B(22), ALT)
        for i, (t, g) in enumerate(kareler):
            x = 50 + i * (gw + 12)
            im.paste(g.resize((gw, kh), Image.LANCZOS), (x, y + 32))
            cerceve(d, (x, y + 32, x + gw, y + 32 + kh))
            yaz(d, (x + gw / 2, y + 36 + kh), "+%d ms" % t, MO(15), DIM, orta=True)
            if farklar[i] is not None:
                yaz(d, (x + gw / 2, y + 56 + kh), "%d px" % farklar[i], MO(15),
                    IYI if farklar[i] else DIM, orta=True)
        y += kh + 92
    im.save(os.path.join(OUT, "v54_hareket_seritleri.jpg"), quality=88)
    print("v54_hareket_seritleri.jpg", im.size)


# ══════════════════════════════════════════════════════════════════════
# 4 · TÜM EKRANLAR
# ══════════════════════════════════════════════════════════════════════
def sahne_sirasi():
    """Sıra `cek.py`nin kendi sırası — elle ikinci bir liste tutmak,
    bir gün ikisinden birinin eksik kalması demektir."""
    s = open(os.path.join(KOK, "web_sahne", "cek.py"), encoding="utf-8").read()
    bas = s.index("SAHNELER = {")
    son = s.index("\n}", bas)
    return re.findall(r'^\s*"([^"]+)":\s*\(', s[bas:son], re.M)


def tum_ekranlar():
    adlar = [a for a in sahne_sirasi() if os.path.exists(os.path.join(YENI, a + ".png"))]
    s = 4
    ornek = Image.open(os.path.join(YENI, adlar[0] + ".png"))
    tw, th = ornek.width // s, ornek.height // s
    kol, bas, bosl, alt = 8, 118, 24, 38
    sat = (len(adlar) + kol - 1) // kol
    W = kol * tw + (kol + 1) * bosl
    H = bas + sat * (th + alt) + bosl
    im = Image.new("RGB", (W, H), ZEMIN)
    d = ImageDraw.Draw(im)
    yaz(d, (bosl, 30), "LOUNGELINK · v5.8.0 — ÇEKİLEN %d SAHNENİN TAMAMI" % len(adlar), B(34))
    yaz(d, (bosl, 76), "gerçek React ağacı · gerçek veri · gerçek RLS · 0 hata · "
                       "ekranlar + DURUMLARI · Gökberk'in 12 Eylül listesi uygulandı (katlanır kartlar · boş durum · tanecik · taşma · başlık kırpılması · ikon boşluğu)", R(20), DIM)
    for i, ad in enumerate(adlar):
        x = bosl + (i % kol) * (tw + bosl)
        y = bas + (i // kol) * (th + alt)
        im.paste(Image.open(os.path.join(YENI, ad + ".png")).convert("RGB")
                 .resize((tw, th), Image.LANCZOS), (x, y))
        yaz(d, (x + tw / 2, y + th + 8), ad, M(17), INK, orta=True)
    # 🔴 12 EYLÜL (Gökberk md.3) — LEVHA ARTIK JPEG DEĞİL.
    # Ölçtüm: q=84 JPEG, koyu gradyanlarda ortalama 1.27 ton hata ve 8x8
    # blok izi bırakıyor; ufuk kuşağının TOPLAM genliği 13 ton. Yani
    # sıkıştırma gürültüsü, ölçtüğümüz şeyin %10'u kadar. Tasarımı
    # değerlendirdiğimiz görselin kendisi kusur üretmemeli.
    im.save(os.path.join(OUT, "TUM_EKRANLAR_v5.8.0.png"), optimize=True)
    print("TUM_EKRANLAR_v5.8.0.png", im.size, "·", len(adlar), "sahne")


if __name__ == "__main__":
    yenilikler()
    ambiyans()
    hareket()
    tum_ekranlar()
