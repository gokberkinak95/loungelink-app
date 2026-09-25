#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tanitim_host.py — YEDİ FARKLI GÖNDERİ BİÇİMİ · ÖZELLİKLE HOST İÇİN.

🔴 NEDEN AYRI BİR DOSYA VE NEDEN YEDİ BİÇİM
`tanitim_uret.py` tek bir kalıp üretiyordu: üstte başlık, altta telefon.
Beş gönderi ürettiğinde beşi de birbirine benziyor ve akışta kaydırılıp
geçiliyor. Instagram'da bir markanın en pahalı hatası, gönderilerinin
BİRBİRİNE benzemesidir — çünkü ikinci gönderiden sonra göz "bunu
gördüm" der ve durmaz.

🆕 SINIF: "TEK KALIPLA ÜRETİLEN BİR İÇERİK DİZİSİ, İKİNCİ GÖNDERİDEN
SONRA GÖRÜNMEZ OLUR — BİÇİM ÇEŞİTLİLİĞİ SÜSLEME DEĞİL, ERİŞİMDİR."

🔴 VE ASIL MESELE: HOST
Ürünün dar boğazı host. Misafir zaten istekli — kapıda bekliyor,
salona girmek istiyor. Host'un ise HİÇBİR ACİL İHTİYACI YOK: o zaten
içeride. Bu yüzden host içeriği misafir içeriğinden farklı çalışmak
zorunda:

    misafire  → FIRSAT anlatılır  ("içeri girebilirsin")
    host'a    → KAYIP + KONTROL + KADEME anlatılır

Host'un üç itirazı var ve her birine ayrı bir gönderi yazıldı:
  1 · "Bana ne kazandırır?"        → ig_h1_kayip · ig_h3_merdiven
  2 · "Yanıma kimi alacağım?"      → ig_h2_kontrol · ig_h6_gizlilik
  3 · "Bu yasal mı, hakkımı mı satıyorum?" → ig_h5_hukuk

BİÇİMLER
  soz      — yalnız tipografi, telefon yok. En yüksek duraklatma oranı.
  ekran    — cümle + tek telefon (tanitim_uret'teki kalıbın host hâli)
  merdiven — kademe merdiveni (Yolcu · Ev Sahibi · Kâhya · Konsiyerj)
  binis    — biniş kartı motifi; ürünün kendi dünyasından bir nesne
  sss      — soru/cevap kartı, itiraz karşılama
  karusel  — 1/3 · 2/3 · 3/3 numaralı eğitim serisi
  ucadim   — üç telefon tek karede, akış anlatımı
  rakam    — sayı kartı

🔴 HER RAKAM ÜRÜNDEN OKUNDU, UYDURULMADI:
  kademeler        → SQL 206 (Yolcu 0 · Ev Sahibi 1 · Kâhya 5 · Konsiyerj 15)
  üst plan hediyesi→ SQL 236 (2 ağırlama → 30 gün)
  500 LoungePuan / 1 kredi → website SSS "Host neden birini içeri alsın?"
  284 salon · 222 havalimanı · 118 ülke → website lounges-data.js
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
import tanitim_uret as TU                                          # noqa: E402
from mockup import BOLD, MED, REG, SEMI, SERIF, rgb                # noqa: E402

G, Y = 1080, 1350
KN = 76
CIKTI = TU.CIKTI
M = TU.METIN
KOYU = TU.KOYU
R = {"ok": "#8FE3BC", "block": "#F7A8BA", "cost": "#E8C87A", "info": "#DDD6CD"}

# ── ÜRÜNDEN OKUNAN OLGULAR ─────────────────────────────────────────
KADEMELER = [("Yolcu", 0, "Henüz kimseyi ağırlamadın"),
             ("Ev Sahibi", 1, "Keşifte önüne geçiyorsun"),
             ("Kâhya", 5, "Ek görünürlük + belirgin öncelik"),
             ("Konsiyerj", 15, "Kendi isteklerin kredi harcamıyor")]
RAKAMLAR = [("284", "salon"), ("222", "havalimanı"),
            ("118", "ülke"), ("105", "kural sayfası")]


def ft(ad, px):
    return TU.ft(ad, px)


def yeni(koyuluk=0.40, sol=0.46, g=G, y=Y):
    return TU.zemin(g, y, koyuluk, sol)


def golge(im, xy, s, font, renk):
    TU.golgeli(im, xy, s, font, renk)


def yaz_blok(im, d, metin, ad, px, en, x, y, renk, satir_carp=1.04, alt=20):
    font = TU.sig(d, metin, ad, px, en, alt=alt)
    for s in TU.sar(d, metin, font, en):
        golge(im, (x, y), s, font, renk)
        y += int(font.size * satir_carp)
    return y


def kunye(im, y=None, ust_sag=False):
    """
    🔴 İLK SÜRÜMDE KÜNYE HEP SOL ALTTAYDI VE ÜÇ GÖNDERİDE TELEFONUN
    ALTINDA KALDI. Alt kenara taşan bir telefon o köşeyi kaplıyor;
    oraya yazılan her şey yarı görünür oluyor.

    🆕 SINIF: "SABİT BİR KÖŞEYE YERLEŞTİRİLEN İMZA, O KÖŞEYİ BAŞKA
    BİR ÖĞE İŞGAL ETTİĞİNDE İMZA OLMAKTAN ÇIKAR — YERLEŞİMİ DÜZENE
    SOR, KÖŞEYE DEĞİL."
    """
    s = "loungelink.app"
    if ust_sag:
        d = ImageDraw.Draw(im)
        w = TU.uzunluk(d, s, ft(SEMI, 26))
        golge(im, (G - KN - w, 74), s, ft(SEMI, 26), "#D8C6AB")
        return
    golge(im, (KN, (y or Y - 76)), s, ft(SEMI, 28), "#D8C6AB")


# ══════════════════════════════════════════════════════════════════
# 1 · SÖZ KARTI — yalnız tipografi
#
# 🔴 NEDEN TELEFONSUZ BİR GÖNDERİ
# Akışta kaydıran göz, ekran görüntüsünü "reklam" diye tanır ve geçer.
# Yalnız cümleden oluşan bir kare ise OKUNUR — çünkü okunacak başka
# bir şey yoktur. Host'un en soğuk itirazını (kayıp) burada söylüyoruz.
# ══════════════════════════════════════════════════════════════════
def soz_karti(gon, dil="tr"):
    im = yeni(0.52, 0.30)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 84, 42)
    c = M["cumleler"][gon["cumle"]][dil]
    a = M["cumleler"][gon["alt"]][dil]
    # 🔴 METİN ORTADA DURUYORDU VE ALT ÜÇTE BİR BOŞ KALIYORDU. Fotoğraf
    # üstte nefes alsın, söz aşağıda AĞIRLIK yapsın: blok alta yaslandı.
    # Yükseklik önce ÖLÇÜLÜYOR, sonra yerleştiriliyor — "gözüne göre"
    # bir sabit koymak, metin uzayınca taşar.
    fb = TU.sig(d, c, SERIF, 118, G - 2 * KN, alt=64)
    fa = TU.sig(d, a, REG, 40, G - 2 * KN, alt=26)
    nb = len(TU.sar(d, c, fb, G - 2 * KN))
    na = len(TU.sar(d, a, fa, G - 2 * KN))
    yuk = nb * int(fb.size * 1.0) + 60 + na * int(fa.size * 1.34)
    bas = Y - 190 - yuk
    yy = yaz_blok(im, d, c, SERIF, 118, G - 2 * KN, KN, bas, "#FFFDF9", 1.0, alt=64)
    ImageDraw.Draw(im).rectangle([KN, yy + 40, KN + 120, yy + 43],
                                 fill=rgb(KOYU["gold"]) + (235,))
    yaz_blok(im, d, a, REG, 40, G - 2 * KN, KN, yy + 74, "#E4D6BF", 1.34, alt=26)
    kunye(im)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 2 · EKRAN KARTI — cümle + tek telefon (host sürümü)
# ══════════════════════════════════════════════════════════════════
def ekran_karti(gon, dil="tr"):
    im = yeni(0.40, 0.48)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 62, 40)
    c = M["cumleler"][gon["cumle"]][dil]
    a = M["cumleler"][gon["alt"]][dil]
    yy = yaz_blok(im, d, c, SERIF, 100, G - 2 * KN, KN, 168, "#FFFDF9", 1.02, alt=54)
    yy = yaz_blok(im, d, a, REG, 38, G - 2 * KN, KN, yy + 20, "#E9D9C2", 1.34, alt=24)
    tel = TU.telefon(gon["ekran"], int(G * 0.54))
    im.alpha_composite(tel, (int(G * 0.58) - tel.size[0] // 2,
                             min(yy + 20, Y - int(tel.size[1] * 0.70))))
    kunye(im, ust_sag=True)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 3 · MERDİVEN — kademeler
#
# 🔴 BİR MERDİVENİ YALNIZCA ÜZERİNDE DURANLARA GÖSTERİRSEN, KİMSE İLK
# BASAMAĞA ÇIKMAZ. Bu ders üründe öğrenildi (host kademeleri host
# olmayana görünmüyordu); pazarlamada da aynı: merdiveni HOST OLMAYANA
# göstermek gerekiyor.
# ══════════════════════════════════════════════════════════════════
def merdiven_karti(gon, dil="tr"):
    im = yeni(0.54, 0.26)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 74, 40)
    c = M["cumleler"][gon["cumle"]][dil]
    yy = yaz_blok(im, d, c, SERIF, 96, G - 2 * KN, KN, 190, "#FFFDF9", 1.0, alt=54)

    y0 = yy + 76
    adim = 158
    for k, (ad, n, aciklama) in enumerate(KADEMELER):
        yb = y0 + k * adim
        etkin = k == len(KADEMELER) - 1
        # basamak çubuğu — yükseldikçe uzuyor: merdiven GÖRÜNÜYOR
        en = int(180 + k * 168)
        renk = rgb(KOYU["gold"]) if etkin else rgb(KOYU["goldLine"])
        kat = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(kat).rounded_rectangle(
            [KN, yb + 62, KN + en, yb + 70], 4,
            fill=renk + (255 if etkin else 150,))
        im.alpha_composite(kat)
        golge(im, (KN, yb), ad, ft(BOLD, 44 if etkin else 38),
              "#FFFDF9" if etkin else "#E4D6BF")
        s = ("%d ağırlama" % n) if n else "başlangıç"
        w = d.textlength(s, font=ft(SEMI, 26))
        golge(im, (G - KN - w, yb + 12), s, ft(SEMI, 26),
              KOYU["gold"] if etkin else "#B8AC98")
        golge(im, (KN, yb + 96), aciklama, ft(REG, 25), "#C9B79C")

    a = M["cumleler"][gon["alt"]][dil]
    yaz_blok(im, d, a, SEMI, 34, G - 2 * KN, KN, y0 + len(KADEMELER) * adim + 22,
             KOYU["gold"], 1.3, alt=24)
    kunye(im)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 4 · BİNİŞ KARTI — ürünün kendi dünyasından bir nesne
#
# 🔴 NEDEN İŞE YARAR
# Marka çerçevesi ne kadar somut bir NESNEYE tutunursa o kadar akılda
# kalır. "+1" soyut; biniş kartı üzerindeki "+1" somut. Üstelik biniş
# kartı zaten yolcunun elinde tuttuğu şey — tanıma maliyeti sıfır.
#
# ⚠️ SAHTE BELGE DEĞİL: üzerinde bir havayolu adı, gerçek bir uçuş
# numarası ya da PNR yok. Marka nesnesi, taklit değil.
# ══════════════════════════════════════════════════════════════════
def binis_karti(gon, dil="tr"):
    im = yeni(0.58, 0.24)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 76, 42)
    c = M["cumleler"][gon["cumle"]][dil]
    yaz_blok(im, d, c, SERIF, 92, G - 2 * KN, KN, 180, "#FFFDF9", 1.0, alt=52)

    # kart gövdesi
    kx, ky, kg, kyk = KN, 470, G - 2 * KN, 560
    kart = Image.new("RGBA", (kg, kyk), (0, 0, 0, 0))
    kd = ImageDraw.Draw(kart)
    kd.rounded_rectangle([0, 0, kg - 1, kyk - 1], 26,
                         fill=rgb("#FBF7EF") + (250,),
                         outline=rgb(KOYU["goldLine"]) + (255,), width=2)
    # kopma çizgisi + iki kertik (biniş kartının imzası)
    ayirac_x = int(kg * 0.66)
    for yy in range(24, kyk - 24, 22):
        kd.line([ayirac_x, yy, ayirac_x, yy + 11], fill=rgb("#C9BCA0") + (255,), width=2)
    kd.ellipse([ayirac_x - 16, -16, ayirac_x + 16, 16], fill=rgb(KOYU["bg"]) + (255,))
    kd.ellipse([ayirac_x - 16, kyk - 16, ayirac_x + 16, kyk + 16], fill=rgb(KOYU["bg"]) + (255,))

    ic = 40
    kd.text((ic, 34), "LOUNGELINK", font=ft(BOLD, 24), features=TU.OZ,
            fill=rgb("#7F6523") + (255,))
    kd.text((ic, 74), "LOUNGE OTURUM KARTI", font=ft(SEMI, 19), features=TU.OZ,
            fill=rgb("#8C7F68") + (255,))
    # 🔴 "MİSAFİR · +1" SATIRI SAĞ KOÇANDAKİ DEV "+1" İLE AYNI ŞEYİ
    # SÖYLÜYORDU. Bir kareye aynı işareti iki kez koymak ikisini de
    # zayıflatır — koçandaki büyük "+1" tek kalınca vurgu oluyor.
    satirlar = [("HOST", "SELİN B."), ("SALON", "TAV PRIMECLASS · IST"),
                ("AKTARMA", "3 SAAT 20 DK"), ("KURAL", "DOĞRULANDI")]
    yy = 150
    for etiket, deger in satirlar:
        kd.text((ic, yy), etiket, font=ft(SEMI, 18), features=TU.OZ,
                fill=rgb("#9A8C74") + (255,))
        buyuk = False
        kd.text((ic, yy + 26), deger, font=ft(BOLD, 46 if buyuk else 30),
                features=TU.OZ,
                fill=rgb("#7F6523" if buyuk else "#251E17") + (255,))
        yy += 92
    # sağ koçan
    kd.text((ayirac_x + 34, 60), "KOÇAN", font=ft(SEMI, 18), features=TU.OZ,
            fill=rgb("#9A8C74") + (255,))
    kd.text((ayirac_x + 34, 92), "+1", font=ft(BOLD, 92), features=TU.OZ,
            fill=rgb("#B8943A") + (255,))
    kd.text((ayirac_x + 34, 214), "KOLTUK", font=ft(SEMI, 18), features=TU.OZ,
            fill=rgb("#9A8C74") + (255,))
    kd.text((ayirac_x + 34, 242), "BOŞ\nDEĞİL", font=ft(BOLD, 34), features=TU.OZ,
            fill=rgb("#251E17") + (255,))
    # barkod yerine ritmik çizgiler (sahte kod basmıyoruz)
    bx = ayirac_x + 34
    for i, w in enumerate([3, 6, 2, 8, 3, 3, 7, 2, 5, 3, 6, 2, 4, 8, 3]):
        kd.rectangle([bx, 400, bx + w, 470], fill=rgb("#3A3128") + (255,))
        bx += w + 7

    gol = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gol.paste(Image.new("RGBA", kart.size, (8, 5, 4, 150)), (kx, ky + 18),
              kart.split()[3])
    im.alpha_composite(gol.filter(ImageFilter.GaussianBlur(26)))
    im.alpha_composite(kart, (kx, ky))

    a = M["cumleler"][gon["alt"]][dil]
    yaz_blok(im, d, a, REG, 36, G - 2 * KN, KN, ky + kyk + 46, "#E4D6BF", 1.3, alt=24)
    kunye(im)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 5 · SSS KARTI — itiraz karşılama
# ══════════════════════════════════════════════════════════════════
def sss_karti(gon, dil="tr"):
    im = yeni(0.56, 0.28)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 78, 42)
    soru = ("Hakkımı satmış olmuyor muyum?" if dil == "tr"
            else "Am I selling my access?")
    golge(im, (KN, 210), "SORU" if dil == "tr" else "QUESTION",
          ft(BOLD, 22), KOYU["gold"])
    yy = yaz_blok(im, d, soru, SERIF, 74, G - 2 * KN, KN, 250, "#E8DAC2", 1.02, alt=44)

    ImageDraw.Draw(im).rectangle([KN, yy + 44, G - KN, yy + 46],
                                 fill=rgb(KOYU["goldLine"]) + (120,))
    golge(im, (KN, yy + 84), "CEVAP" if dil == "tr" else "ANSWER",
          ft(BOLD, 22), KOYU["gold"])
    c = M["cumleler"][gon["cumle"]][dil]
    a = M["cumleler"][gon["alt"]][dil]
    yy2 = yaz_blok(im, d, c, SERIF, 96, G - 2 * KN, KN, yy + 124, "#FFFDF9", 1.0, alt=54)
    yaz_blok(im, d, a, REG, 36, G - 2 * KN, KN, yy2 + 28, "#E4D6BF", 1.34, alt=24)
    kunye(im)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 6 · KARUSEL SLAYTI — numaralı eğitim serisi
# ══════════════════════════════════════════════════════════════════
KARUSEL_GOVDE = {
    "kural_1": [("Havayolu şartı", "yok", True),
                ("Kabin şartı", "yok", True),
                ("Aynı terminal", "yeter", True)],
    "kural_2": [("Havayolu şartı", "yok", True),
                ("Aynı uçuş şartı", "VAR", False),
                ("md. 7.15.7", "misafir seninle uçmalı", False)],
    "kural_3": [("Rakip", "üçünü tek kutuda topluyor", False),
                ("Biz", "her kartı ayrı okuyoruz", True),
                ("Bedeli", "kapıda geri çevrilen misafir", False)],
}


def karusel_slayti(gon, sira, toplam, dil="tr"):
    im = yeni(0.50, 0.34)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 72, 40)
    # sayaç — serinin devamı olduğunu söyler, kaydırmayı davet eder
    s = "%d/%d" % (sira, toplam)
    w = d.textlength(s, font=ft(BOLD, 30))
    golge(im, (G - KN - w, 78), s, ft(BOLD, 30), KOYU["gold"])

    golge(im, (KN, 196), "KURAL MOTORU" if dil == "tr" else "RULE ENGINE",
          ft(BOLD, 22), KOYU["gold"])
    c = M["cumleler"][gon["cumle"]][dil]
    yy = yaz_blok(im, d, c, SERIF, 104, G - 2 * KN, KN, 236, "#FFFDF9", 1.0, alt=56)

    # 🔴 OLGU SATIRLARI BAŞLIĞIN HEMEN ALTINDAYDI; karenin alt yarısı
    # bomboş kalıyordu. Üstte söz, altta kanıt — arada fotoğraf nefes
    # alıyor. Alt üçte bir, akışta parmağın durduğu yerdir.
    # 🔴 SON SLAYTTA TELEFON SAĞ ALTTA DURUYOR VE SAĞA HİZALI DEĞERLERİ
    # ÖRTÜYORDU: "üçünü tek kutuda topluyor" okunmuyordu. Sağ sınır
    # artık telefonun BAŞLADIĞI yer — sabit bir kenar boşluğu değil.
    #
    # 🆕 SINIF: "SAĞA HİZALAMA, SAĞDA NE OLDUĞUNU BİLMİYORSAN HİZALAMA
    # DEĞİL TEMENNİDİR."
    son = sira == toplam
    # telefonun GÖRÜNEN sol kenarı: bileşke x + gölge dolgusu.
    # (0.52 denedim, 22px örtüştü — dolguyu hesaba katmamıştım.)
    sag = int(G * 0.45) if son else G - KN
    yy = Y - 470
    for etiket, deger, olumlu in KARUSEL_GOVDE[gon["cumle"]]:
        renk = R["ok"] if olumlu else R["block"]
        d.ellipse([KN, yy + 14, KN + 16, yy + 30], fill=rgb(renk) + (255,))
        golge(im, (KN + 34, yy), etiket, ft(SEMI, 34), "#FFFDF9")
        df = TU.sig(d, deger, SEMI, 34, sag - KN - 130, alt=22)
        w = TU.uzunluk(d, deger, df)
        golge(im, (sag - w, yy + (34 - df.size) // 2), deger, df, renk)
        yy += 66

    if sira < toplam:
        ipucu = "kaydır →" if dil == "tr" else "swipe →"
        w = d.textlength(ipucu, font=ft(SEMI, 28))
        golge(im, (G - KN - w, Y - 76), ipucu, ft(SEMI, 28), KOYU["gold"])
        kunye(im)
    else:
        tel = TU.telefon(gon["ekran"], int(G * 0.40))
        im.alpha_composite(tel, (int(G * 0.70) - tel.size[0] // 2,
                                 Y - int(tel.size[1] * 0.62)))
        kunye(im, ust_sag=True)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 7 · ÜÇ ADIM — üç telefon tek karede
# ══════════════════════════════════════════════════════════════════
ADIMLAR = [("01", "Keşfet", "02_kesfet"),
           ("02", "Eşleş", "04_eslesme"),
           ("03", "Oturum", "07_oturum")]


def uc_adim(gon, dil="tr"):
    im = yeni(0.46, 0.34)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 72, 40)
    c = M["cumleler"][gon["cumle"]][dil]
    yy = yaz_blok(im, d, c, SERIF, 100, G - 2 * KN, KN, 178, "#FFFDF9", 1.0, alt=54)
    a = M["cumleler"][gon["alt"]][dil]
    yaz_blok(im, d, a, REG, 34, G - 2 * KN, KN, yy + 14, "#E9D9C2", 1.3, alt=22)

    gen = int(G * 0.255)
    ust = 620
    for k, (no, ad, ekran) in enumerate(ADIMLAR):
        tel = TU.telefon(ekran, gen, egim=(k - 1) * 5)
        x = int(G * (0.19 + k * 0.31)) - tel.size[0] // 2
        yk = ust + (0 if k == 1 else 26)
        im.alpha_composite(tel, (x, yk))
        cx = int(G * (0.19 + k * 0.31))
        w = d.textlength(no, font=ft(BOLD, 30))
        golge(im, (cx - w / 2, ust - 62), no, ft(BOLD, 30), KOYU["gold"])
        w = d.textlength(ad, font=ft(SEMI, 27))
        golge(im, (cx - w / 2, ust - 24), ad, ft(SEMI, 27), "#F0E6D8")
    kunye(im, ust_sag=True)
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# 8 · RAKAM KARTI
# ══════════════════════════════════════════════════════════════════
def rakam_karti(gon, dil="tr"):
    im = yeni(0.56, 0.26)
    d = ImageDraw.Draw(im)
    TU.marka(im, KN, 78, 42)
    c = M["cumleler"][gon["cumle"]][dil]
    yy = yaz_blok(im, d, c, SERIF, 104, G - 2 * KN, KN, 210, "#FFFDF9", 1.0, alt=56)

    y0 = yy + 90
    gk, yk = (G - 2 * KN - 28) // 2, 250
    for k, (sayi, etiket) in enumerate(RAKAMLAR):
        cx = KN + (k % 2) * (gk + 28)
        cy = y0 + (k // 2) * (yk + 28)
        kat = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(kat).rounded_rectangle(
            # 🔴 KUTU ZEMİNİ AÇIK BİR PERDEYDİ (255,253,249,16) VE
            # ÜSTÜNDEKİ ALTIN RAKAMIN KONTRASTINI DÜŞÜRÜYORDU: nöbetçi
            # 4.17:1 ölçtü. Açık mürekkebin altına açık perde koymak,
            # okunurluğu artırmaz — AZALTIR. Perde KOYU olmalı.
            #
            # 🆕 SINIF: "MÜREKKEP AÇIKSA ZEMİNİ AÇMA — PERDENİN YÖNÜ,
            # MÜREKKEBİN YÖNÜNÜN TERSİ OLMAK ZORUNDADIR."
            [cx, cy, cx + gk, cy + yk], 24,
            fill=(12, 8, 6, 132), outline=rgb(KOYU["goldLine"]) + (170,), width=2)
        im.alpha_composite(kat)
        w = d.textlength(sayi, font=ft(SERIF, 104))
        golge(im, (cx + (gk - w) / 2, cy + 44), sayi, ft(SERIF, 104), KOYU["gold"])
        w = d.textlength(etiket, font=ft(SEMI, 30))
        golge(im, (cx + (gk - w) / 2, cy + 176), etiket, ft(SEMI, 30), "#E4D6BF")

    a = M["cumleler"][gon["alt"]][dil]
    yaz_blok(im, d, a, REG, 32, G - 2 * KN, KN, y0 + 2 * (yk + 28) + 18,
             "#C9B79C", 1.3, alt=22)
    kunye(im)
    return im.convert("RGB")


BICIM = {"soz": soz_karti, "ekran": ekran_karti, "merdiven": merdiven_karti,
         "binis": binis_karti, "sss": sss_karti, "ucadim": uc_adim,
         "rakam": rakam_karti}

# EN üretilecek gönderiler: hepsini iki dilde üretmek 40 dosya demek ve
# çoğu kullanılmayacak. Pazar TR; EN yalnız en güçlü dördü için.
EN_LISTESI = {"ig_h1_kayip", "ig_h3_merdiven", "ig_h4_binis", "ig_g2_rakam"}


def main():
    os.makedirs(CIKTI, exist_ok=True)
    n = 0
    for gon in M["gonderiler_host"] + M["gonderiler_genel"]:
        for dil in (("tr", "en") if gon["ad"] in EN_LISTESI else ("tr",)):
            ek = "" if dil == "tr" else "_en"
            yol = os.path.join(CIKTI, gon["ad"] + ek + ".png")
            BICIM[gon["tip"]](gon, dil).save(yol, quality=95)
            print("  ✓ %-24s %-9s 1080x1350" % (os.path.basename(yol), gon["tip"]))
            n += 1
    kar = M["gonderiler_karusel"]
    for k, gon in enumerate(kar):
        yol = os.path.join(CIKTI, gon["ad"] + ".png")
        karusel_slayti(gon, k + 1, len(kar)).save(yol, quality=95)
        print("  ✓ %-24s %-9s 1080x1350 (%d/%d)"
              % (os.path.basename(yol), "karusel", k + 1, len(kar)))
        n += 1
    print("\n%d host/eğitim görseli → %s" % (n, CIKTI))
    return 0


if __name__ == "__main__":
    sys.exit(main())
