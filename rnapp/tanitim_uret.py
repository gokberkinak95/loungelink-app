#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tanitim_uret.py — INSTAGRAM VE WEBSITE TANITIM GÖRSELLERİ.

🔴 NEDEN VAR
`ekran_uret.py` ürünün ekranlarını çiziyor. Bu dosya o ekranları
PAZARLAMA çerçevesine yerleştiriyor: telefon kasası, fotoğraflı zemin,
başlık, ve "+1" teması.

🔴 "WE FIND YOUR PERFECT +1" HAKKINDA — AÇIKÇA
Gökberk bu cümleyi çok beğendi ve haklı. Ama o cümle RAKİBİN
(Lounge Surf) sitesinde duruyor. Aynısını kullanmak marka olarak bizi
onların ikinci sürümü yapar; hukuken de slogan koruması (TR: 6769 s.
SMK; US: common-law + USPTO) altına girebilir. Ben avukat değilim ve
bu kararı veremem — ama riski görünmez kılmak da işim değil.

Aldığım yol: ÇERÇEVEYİ alıyoruz ("+1"), CÜMLEYİ kendimiz yazıyoruz.
Kendi cümlemiz daha güçlü bir şey söylüyor:

    onlar : "We find your perfect +1"       → bir VAAT
    biz   : "Kartında bir kişilik yer var." → bir GERÇEK

Vaat tartışılır; gerçek tartışılmaz. Bütün cümleler
`tanitim_metinleri.json`da kayıtlı ve `tanitim_check.py` her birinin
rakibin cümlelerinden farklı olduğunu ÖLÇÜYOR.

🆕 SINIF: "BEĞENİLEN BİR RAKİP CÜMLESİNİ KOPYALAMA — ONU NEDEN
İŞE YARADIĞINA KADAR SÖK, ÇERÇEVEYİ AL, İDDİAYI KENDİ ÜRÜNÜNDEN ÜRET."

ÇIKTILAR
  tanitim/ig_*.png       1080×1350 (Instagram 4:5)
  tanitim/story_*.png    1080×1920 (Story / Reels kapağı)
  tanitim/web_hero.png   2400×1350 (site kahraman alanı)
  tanitim/web_raf.png    2400×1000 (site telefon rafı)
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from mockup import BOLD, REG, SEMI, SERIF, rgb  # noqa: E402
from mockup import f as _f  # noqa: E402
from tema_oku import palet  # noqa: E402

EKRANLAR = os.path.join(KOK, "ekranlar_render")
CIKTI = os.path.join(KOK, "tanitim")
METIN = json.load(open(os.path.join(KOK, "tanitim_metinleri.json"),
                       encoding="utf-8"))
C = dict(palet("C"))
KOYU = dict(palet("C"))
KOYU.update(palet("KOYU"))
FONTD = os.path.join(KOK, "assets", "fonts")


def ft(ad, px):
    """Tanıtım tuvalinde punto PİKSEL — `mockup.f` 3× ölçekliyor."""
    from PIL import ImageFont
    return ImageFont.truetype(os.path.join(FONTD, ad), int(px))


# 🔴 "+1'in kim olacak?" BAŞLIĞI "+ı'in" DİYE OKUNUYORDU.
# Cormorant Garamond varsayılan olarak ESKİ STİL RAKAM (oldstyle figures)
# kullanıyor: "1" x-yüksekliğinde, noktasız "ı" gibi duruyor. Ürün
# ekranlarında bu FAİKÎ doğru — uygulama da aynı fontu aynı ayarla
# kullanıyor, o yüzden orada dokunmuyorum. Ama pazarlama başlığı ürünün
# metni değil; orada `lnum` (lining figures) açıyorum.
#
# 🆕 SINIF: "SERİF BİR BAŞLIK FONTUNDA RAKAM VARSA, RAKAM STİLİNİ
# ÖLÇMEDEN KULLANMA — ESKİ STİL RAKAMLAR MARKA CÜMLESİNİ BAŞKA BİR
# KELİMEYE ÇEVİREBİLİR."
OZ = ["lnum"]


def uzunluk(d, s, font):
    return d.textlength(s, font=font, features=OZ)


def sig(d, s, ad, px, en, alt=14):
    while px > alt and uzunluk(d, s, ft(ad, px)) > en:
        px -= 1
    return ft(ad, px)


def sar(d, s, font, en):
    satirlar, cur = [], ""
    for w in s.split(" "):
        deneme = (cur + " " + w).strip()
        if uzunluk(d, deneme, font) > en and cur:
            satirlar.append(cur)
            cur = w
        else:
            cur = deneme
    if cur:
        satirlar.append(cur)
    return satirlar


# ── ZEMİN ──────────────────────────────────────────────────────────
def zemin(g, y, koyuluk=0.42, sol_perde=0.52):
    """
    Fotoğraflı sıcak zemin — sitedeki `body::before` + `body::after`
    ile AYNI mantık: aynı fotoğraf, üstüne gece perdesi. Pazarlama
    görseli ile site aynı yerden besleniyor, o yüzden aynı görünüyor.

    🔴 İLK SÜRÜMDE PERDEYİ 0.68 KOYDUM VE FOTOĞRAF TAMAMEN KAYBOLDU —
    geriye düz kahverengi bir tuval kaldı. "Lounge Surf tarzı fotoğraflı
    zemin" istenmişti; ürettiğim şey fotoğrafsız bir zemindi.
    Sebep: perdeyi METNİN OKUNURLUĞU için koymuştum ve tüm tuvale
    uygulamıştım. Oysa metin yalnız SOL ÜSTTE. Perde artık iki parça:
    ince bir genel perde + metnin altında YÖNLÜ bir perde.

    🆕 SINIF: "OKUNURLUK İÇİN KONAN PERDEYİ TÜM TUVALE UYGULAMA —
    KORUMAN GEREKEN ŞEY METNİN ALTI, RESMİN TAMAMI DEĞİL."
    """
    foto = Image.open(os.path.join(KOK, "assets", "bant.jpg")).convert("RGBA")
    oran = max(g / foto.size[0], y / foto.size[1])
    foto = foto.resize((int(foto.size[0] * oran) + 1,
                        int(foto.size[1] * oran) + 1), Image.LANCZOS)
    sx = (foto.size[0] - g) // 2
    sy = int((foto.size[1] - y) * 0.42)
    im = foto.crop((sx, sy, sx + g, sy + y)).convert("RGBA")
    im.alpha_composite(Image.new("RGBA", (g, y),
                                 rgb(KOYU["bg"]) + (int(255 * koyuluk),)))
    # metnin altındaki yönlü perde: sol-üstte güçlü, sağ-altta yok
    if sol_perde:
        kat = Image.new("RGBA", (g, y), (0, 0, 0, 0))
        dk = ImageDraw.Draw(kat)
        z = rgb(KOYU["bg"])
        adim = max(1, g // 160)
        for x0 in range(0, g, adim):
            tt = min(1.0, (x0 / (g * 0.72)))
            dk.rectangle([x0, 0, x0 + adim, y],
                         fill=z + (int(255 * sol_perde * (1 - tt) ** 1.25),))
        im.alpha_composite(kat)
    return im


# ── TELEFON KASASI ─────────────────────────────────────────────────
def telefon(ekran_ad, gen, egim=0):
    """
    Ekranı bir cihaz kasasına oturtur: koyu çerçeve, ince altın kenar,
    yumuşak gölge. Kasa oranı gerçek ekran oranından türetiliyor.
    """
    ek = Image.open(os.path.join(EKRANLAR, ekran_ad + ".png")).convert("RGBA")
    oran = gen / ek.size[0]
    yuk = int(ek.size[1] * oran)
    ek = ek.resize((gen, yuk), Image.LANCZOS)
    kalin = max(6, int(gen * 0.028))
    r = int(gen * 0.115)
    kg, ky = gen + 2 * kalin, yuk + 2 * kalin
    kasa = Image.new("RGBA", (kg, ky), (0, 0, 0, 0))
    ImageDraw.Draw(kasa).rounded_rectangle([0, 0, kg - 1, ky - 1], r + kalin,
                                           fill=(18, 14, 12, 255),
                                           outline=rgb(KOYU["goldLine"]) + (170,),
                                           width=max(1, kalin // 4))
    maske = Image.new("L", (gen, yuk), 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, gen - 1, yuk - 1], r, fill=255)
    kasa.paste(ek, (kalin, kalin), maske)
    if egim:
        kasa = kasa.rotate(egim, resample=Image.BICUBIC, expand=True)
    # gölge
    pad = int(gen * 0.16)
    tuval = Image.new("RGBA", (kasa.size[0] + 2 * pad, kasa.size[1] + 2 * pad),
                      (0, 0, 0, 0))
    golge = Image.new("RGBA", tuval.size, (0, 0, 0, 0))
    golge.paste(Image.new("RGBA", kasa.size, (8, 5, 4, 150)),
                (pad, pad + int(gen * 0.03)), kasa.split()[3])
    tuval.alpha_composite(golge.filter(ImageFilter.GaussianBlur(pad * 0.42)))
    tuval.alpha_composite(kasa, (pad, pad))
    return tuval


def marka(im, x, y, boy=34, renk="#F6E4C4"):
    d = ImageDraw.Draw(im)
    mark = Image.open(os.path.join(KOK, "assets", "mark-light.png")).convert("RGBA")
    mark.thumbnail((boy, boy), Image.LANCZOS)
    im.alpha_composite(mark, (int(x), int(y - boy * 0.08)))
    d.text((x + boy + 12, y + boy * 0.16), "LOUNGELINK", features=OZ,
           font=ft(BOLD, int(boy * 0.52)), fill=rgb(renk) + (255,))


# ── ÖLÇÜM KİPİ ─────────────────────────────────────────────────────
# 🔴 FOTOĞRAF ÜSTÜNE YAZILAN METNİN KONTRASTI, MÜREKKEP ÇİZİLDİKTEN
# SONRA ÖLÇÜLEMEZ: ölçtüğün şey mürekkebin kendisi olur. Zemin,
# MÜREKKEP KONMADAN ÖNCE ölçülmeli — ve gölge katmanları zeminin
# parçasıdır, çünkü onlar da mürekkepten önce çiziliyor.
# `MURKEPSIZ = True` iken `golgeli` gölgeleri çizer, mürekkebi çizmez
# ve yazının kutusunu `KUTULAR`a kaydeder. `tanitim_check.py` bu kipte
# üretip her kutunun EN AÇIK pikselini bulur.
MURKEPSIZ = False
KUTULAR = []


def golgeli(im, xy, s, font, renk):
    x, yy = xy
    if MURKEPSIZ:
        d0 = ImageDraw.Draw(im)
        w = uzunluk(d0, s, font)
        KUTULAR.append((int(x), int(yy), s, font, renk))
    # 🔴 GÖLGE YARIÇAPI SABİTTİ (26/12/4 px) VE BU, BÜYÜK BAŞLIK İÇİN
    # AYARLANMIŞTI. 30 px'lik kural satırlarında aynı gölge, harfin
    # altındaki parlak gün batımını örtmeye yetmiyordu: ölçüm 2.44:1
    # dedi (AA 4.5). Gölge, korumaya çalıştığı harfle ORANTILI olmalı.
    #
    # 🆕 SINIF: "OKUNURLUK İÇİN KONAN GÖLGEYİ PİKSELLE DEĞİL, PUNTOYLA
    # ÖLÇEKLE — BÜYÜK BAŞLIKTA YETEN GÖLGE KÜÇÜK METİNDE YETMEZ."
    b = font.size
    for kat_r, alfa, dy in ((0.34, 0.86, 0.055), (0.15, 0.96, 0.028),
                            (0.05, 1.0, 0.012)):
        kat = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(kat).text((x, yy + b * dy), s, font=font, features=OZ,
                                 fill=(10, 6, 6, int(255 * alfa)))
        im.alpha_composite(kat.filter(ImageFilter.GaussianBlur(max(1.2, b * kat_r / 4.0))))
    if not MURKEPSIZ:
        ImageDraw.Draw(im).text((x, yy), s, font=font, features=OZ,
                                fill=rgb(renk) + (255,))


# ══════════════════════════════════════════════════════════════════
# INSTAGRAM GÖNDERİSİ 1080×1350
# ══════════════════════════════════════════════════════════════════
def ig(gonderi, dil="tr"):
    """
    🔴 İLK YERLEŞİMDE TELEFON BAŞLIĞIN ÜSTÜNE BİNDİ ve "Kartında bir
    kişilik yer var." yarıda kesildi — pazarlama görselinin TEK işi olan
    cümle okunmuyordu. Sebep: telefonu sabit bir orana koyup metnin ne
    kadar yer kapladığını ölçmemiştim. Artık metin önce yazılıyor,
    telefon KALAN yere oturuyor.
    """
    G, Y = 1080, 1350
    im = zemin(G, Y, 0.40, 0.46)
    d = ImageDraw.Draw(im)
    KN = 76
    EN = G - 2 * KN
    c = METIN["cumleler"][gonderi["cumle"]]
    a = METIN["cumleler"][gonderi["alt"]]

    marka(im, KN, 62, 40)

    bf = sig(d, c[dil], SERIF, 100, EN, alt=54)
    yy = 168
    for s in sar(d, c[dil], bf, EN):
        golgeli(im, (KN, yy), s, bf, "#FFFDF9")
        yy += int(bf.size * 1.02)
    yy += 14

    af = sig(d, a[dil], REG, 36, EN, alt=22)
    for s in sar(d, a[dil], af, EN):
        golgeli(im, (KN, yy), s, af, "#E9D9C2")
        yy += int(af.size * 1.34)

    # kural gönderisinde motorun cevabı — ölçülebilir, doğrulanmış iddia
    if gonderi["cumle"] == "kural":
        yy += 26
        rf = ft(SEMI, 30)
        for ad, deger, ok in (("Priority Pass", "havayolu şartı yok", True),
                              ("LoungeKey", "havayolu şartı yok", True),
                              ("DragonPass", "AYNI UÇUŞ şartı", False)):
            renk = "#8FE3BC" if ok else "#F7A8BA"
            golgeli(im, (KN, yy), ad, rf, "#FFFDF9")
            w = uzunluk(d, deger, rf)
            golgeli(im, (G - KN - w, yy), deger, rf, renk)
            yy += 50
        yy += 4

    # telefon KALAN yere; alttan taşması bilinçli (cihaz kadraja giriyor)
    kalan = Y - yy - 96
    gen = min(int(G * 0.56), max(300, int(kalan * 0.62)))
    tel = telefon(gonderi["ekran"], gen)
    im.alpha_composite(tel, (int(G * 0.58) - tel.size[0] // 2,
                             min(yy + 24, Y - int(tel.size[1] * 0.72))))

    golgeli(im, (KN, Y - 76), "loungelink.app", ft(SEMI, 28), "#D8C6AB")
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# STORY 1080×1920
# ══════════════════════════════════════════════════════════════════
def story(gonderi, dil="tr"):
    G, Y = 1080, 1920
    im = zemin(G, Y, 0.40, 0.44)
    d = ImageDraw.Draw(im)
    KN = 84
    c = METIN["cumleler"][gonderi["cumle"]]
    marka(im, KN, 120, 44)
    bf = sig(d, c[dil], SERIF, 108, G - 2 * KN, alt=56)
    yy = 250
    for s in sar(d, c[dil], bf, G - 2 * KN):
        golgeli(im, (KN, yy), s, bf, "#FFFDF9")
        yy += int(bf.size * 1.02)
    a = METIN["cumleler"][gonderi["alt"]]
    af = sig(d, a[dil], REG, 38, G - 2 * KN, alt=24)
    for s in sar(d, a[dil], af, G - 2 * KN):
        golgeli(im, (KN, yy + 20), s, af, "#E9D9C2")
        yy += int(af.size * 1.34)
    tel = telefon(gonderi["ekran"], int(G * 0.62))
    im.alpha_composite(tel, ((G - tel.size[0]) // 2, Y - tel.size[1] + int(Y * 0.07)))
    return im.convert("RGB")


# ══════════════════════════════════════════════════════════════════
# WEBSITE KAHRAMAN ALANI
# ══════════════════════════════════════════════════════════════════
def web_hero(dil="tr"):
    # 🔴 31 AĞU — PERDE KOYULAŞTIRILDI (0.38 → 0.46).
    # Cümleler sitenin diline çevrilince alt satır uzadı ve fotoğrafın
    # DAHA AÇIK bir bölgesine denk geldi; kontrast 4.30'a düştü ve kapı
    # haklı olarak kırmızı yandı.
    #
    # İki seçenek vardı: cümleyi fotoğrafa göre kısaltmak ya da zemini
    # metnin taşıyabileceği hâle getirmek. Birincisi metni fotoğrafın
    # esiri yapar — bir sonraki cümlede aynı sorun geri gelir.
    #
    # 🆕 SINIF: "METNİ ZEMİNE UYDURMA, ZEMİNİ METNİN TAŞIYABİLECEĞİ
    # HÂLE GETİR — YOKSA HER YENİ CÜMLE AYNI PAZARLIĞI YENİDEN YAPAR."
    G, Y = 2400, 1350
    im = zemin(G, Y, 0.46, 0.60)
    d = ImageDraw.Draw(im)
    KN = 150
    c = METIN["cumleler"]["kanca"]
    s2 = METIN["cumleler"]["site"]
    marka(im, KN, 110, 46)
    bf = sig(d, c[dil], SERIF, 122, G * 0.50, alt=64)
    yy = 240
    for s in sar(d, c[dil], bf, G * 0.50):
        golgeli(im, (KN, yy), s, bf, "#FFFDF9")
        yy += int(bf.size * 1.03)
    af = sig(d, s2[dil], SEMI, 44, G * 0.48, alt=28)
    # 🔴 ALT SATIR ALTINDI VE FOTOĞRAFIN ÜSTÜNDE AA TUTMUYORDU (4.37).
    # Altın, KOYU mesh üstünde 6.68:1 veriyor (uygulamada ölçüldü) ama
    # burada zemin sıcak ve parlak bir fotoğraf — aynı renk aynı işi
    # yapmıyor. Hiyerarşiyi zaten üstteki serif başlık taşıyor; bu satır
    # rengini değil BOYUTUNU ve konumunu kullanabilir.
    #
    # 🆕 SINIF: "BİR VURGU RENGİ, ÖLÇÜLDÜĞÜ ZEMİNDE VURGUDUR — BAŞKA BİR
    # ZEMİNDE YALNIZCA DAHA ZOR OKUNAN BİR RENKTİR."
    golgeli(im, (KN, yy + 26), s2[dil], af, "#F3E8D4")
    u = METIN["cumleler"]["urun"]
    uf = sig(d, u[dil], REG, 34, G * 0.46, alt=22)
    yy2 = yy + 26 + int(af.size * 1.5)
    for s in sar(d, u[dil], uf, G * 0.46):
        golgeli(im, (KN, yy2), s, uf, "#C9B79C")
        yy2 += int(uf.size * 1.36)

    for ad, gen, xk, yk, eg in (("03_kural", 480, 0.545, 0.20, -6),
                                ("02_kesfet", 560, 0.735, 0.11, 4)):
        tel = telefon(ad, gen, egim=eg)
        im.alpha_composite(tel, (int(G * xk) - tel.size[0] // 2, int(Y * yk)))
    return im.convert("RGB")


def web_raf():
    """Site telefon rafı — beş ekran yan yana, hafif yay."""
    G, Y = 2400, 1000
    im = zemin(G, Y, 0.46, 0.30)
    adlar = ["05_tanis", "03_kural", "02_kesfet", "06_sohbet", "09_profil"]
    n = len(adlar)
    for i, ad in enumerate(adlar):
        orta = (i - (n - 1) / 2.0)
        gen = int(340 * (1.0 - abs(orta) * 0.06))
        tel = telefon(ad, gen, egim=-orta * 3.2)
        x = int(G * (0.5 + orta * 0.185)) - tel.size[0] // 2
        y = int(Y * 0.12 + abs(orta) * Y * 0.030)
        im.alpha_composite(tel, (x, y))
    return im.convert("RGB")


def main():
    os.makedirs(CIKTI, exist_ok=True)
    n = 0
    for g in METIN["gonderiler"]:
        for dil in ("tr", "en"):
            ek = "" if dil == "tr" else "_en"
            yol = os.path.join(CIKTI, g["ad"] + ek + ".png")
            ig(g, dil).save(yol, quality=95)
            print("  ✓ %-22s %dx%d" % (os.path.basename(yol), 1080, 1350))
            n += 1
    for g in METIN["gonderiler"][:2]:
        yol = os.path.join(CIKTI, "story_" + g["ad"][3:] + ".png")
        story(g).save(yol)
        print("  ✓ %-22s 1080x1920" % os.path.basename(yol))
        n += 1
    for ad, fn in (("web_hero", web_hero), ("web_raf", web_raf)):
        yol = os.path.join(CIKTI, ad + ".png")
        fn().save(yol)
        print("  ✓ %-22s %s" % (os.path.basename(yol), Image.open(yol).size))
        n += 1
    yol = os.path.join(CIKTI, "web_hero_en.png")
    web_hero("en").save(yol)
    print("  ✓ %-22s" % os.path.basename(yol))
    n += 1
    print("\n%d tanıtım görseli → %s" % (n, CIKTI))
    return 0


if __name__ == "__main__":
    sys.exit(main())
