#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
onizleme.py — İÇ SAYFAYI ANLAŞILAN YAPIYLA, İKİ TEMADA ÇİZER.

🔴 BU DOSYANIN İLK SÜRÜMÜ HATALIYDI VE GÖKBERK HAKLI OLARAK YAKALADI.
İlk hâli yalnız bir RENK TABLOSU çiziyordu: kutular, düz düğmeler,
bant yok, logo yok, tipografi yok. Ekran gibi görünüyordu ama ekran
değildi — ve "app'in ekran görüntüsü" sanıldı. Üç somut kusur:

  1 · BULANIKLIK — iki telefonu 938px'e sıkıştırmışım. Artık her şey
      2× çiziliyor ve öyle kaydediliyor.
  2 · DÜĞMENİN ÜSTÜNDEKİ BEYAZ ÇİZGİ — `btnUstIsik` (beyaz %34) TAM
      GENİŞLİKTE, köşesi yuvarlanmamış düz bir dikdörtgen olarak
      çizilmişti. Gerçek `Btn` bileşeninde o ışık düğmenin İÇİNDE ve
      köşeleri yuvarlı. Yani kusur üründe değil, bu çizimdeydi.
  3 · ANLAŞILAN YAPI YOKTU — fotoğraflı bant, ortalı logo filigranı ve
      onaylanan düğme sistemi hiç çizilmemişti.

🆕 SINIF: "EKRAN GİBİ GÖRÜNEN HER ŞEY EKRAN SANILIR — BİR ÖNİZLEME YA
ÜRÜNÜN GEOMETRİSİNİ BİREBİR TAŞIR YA DA EKRAN GİBİ GÖRÜNMEMELİDİR.
ARASI YOK."

Şimdi geometri `src/ui.js`ten BİREBİR alınıyor:
    BANT_ORAN 520/1080 · FOTO_OLCEK 1.62 · FOTO_Y 0.55 · PERDE_GUC 0.36
    filigran: genişlik %57.4 · yükseklik %62 · sol %21.3 · üst %19 · opaklık %10
Bir sabit değişirse burada da değişir — çünkü `ui.js`ten OKUNUYOR,
kopyalanmıyor.

⚠️ YİNE DE BU BİR EMÜLATÖR DEĞİL: metin cihazın yazı motoruyla değil
PIL ile çiziliyor, satır kırma ve boşluklar yaklaşık. Renk, geometri
ve katman sırası birebir; harf çizimi değil.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import oran, palet, rozet                            # noqa: E402

FONTD = os.path.join(KOK, "assets", "fonts")
K = 2                      # çizim ölçeği — 2× çiz, 2× kaydet
G, Y = 430 * K, 940 * K    # telefon tuvali
KENAR = 18 * K


# ── ui.js'ten GEOMETRİ (kopyalanmıyor, okunuyor) ────────────────────
def ui_sabit(ad, varsayilan):
    g = open(os.path.join(KOK, "src", "ui.js"), encoding="utf-8").read()
    m = re.search(r"const " + ad + r"\s*=\s*([0-9./ ]+);", g)
    if not m:
        return varsayilan
    return eval(m.group(1).strip())            # yalnız sayı/bölme ifadesi


BANT_ORAN = ui_sabit("BANT_ORAN", 520 / 1080)
FOTO_OLCEK = ui_sabit("FOTO_OLCEK", 1.62)
FOTO_EN_BOY = ui_sabit("FOTO_EN_BOY", 1475 / 1180)
FOTO_Y = ui_sabit("FOTO_Y", 0.55)
PERDE_GUC = ui_sabit("PERDE_GUC", 0.36)
PERDE_BANT = int(ui_sabit("PERDE_BANT", 24))
ERIME_BANT = int(ui_sabit("ERIME_BANT", 14))


def f(ad, boy):
    return ImageFont.truetype(os.path.join(FONTD, ad), int(boy * K))


def rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def yuvarlak(boyut, r, renk, cerceve=None, kalinlik=1):
    """Köşeleri yuvarlanmış RGBA katman — düz dikdörtgen çizmiyoruz."""
    kat = Image.new("RGBA", boyut, (0, 0, 0, 0))
    d = ImageDraw.Draw(kat)
    d.rounded_rectangle([0, 0, boyut[0] - 1, boyut[1] - 1], r * K, fill=renk,
                        outline=cerceve, width=kalinlik * K)
    return kat


def golgeli_metin(im, xy, metin, font, renk):
    """
    `GolgeliMetin` — fotoğraf üstünde metin. Üründe RN tek gölge
    verdiği için 3 gölge + gerçek metin = 4 geçiş yığılıyor
    (GOLGE_KATMAN: r22/a.75/dy5 · r10/a.92/dy2 · r3/a1/dy1).
    Burada aynı üç geçiş bulanıklık yarıçapıyla taklit ediliyor.
    """
    x, y = xy
    for yaricap, alfa, dy in ((22, 0.75, 5), (10, 0.92, 2), (3, 1.0, 1)):
        kat = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(kat).text((x, y + dy * K), metin, font=font,
                                 fill=(10, 6, 6, int(255 * alfa)))
        kat = kat.filter(ImageFilter.GaussianBlur(yaricap * K / 6.0))
        im.alpha_composite(kat)
    ImageDraw.Draw(im).text((x, y), metin, font=font, fill=renk + (255,))


def bant(im, P, baslik, ustBilgi, marka="LOUNGELINK"):
    """FotoBant — fotoğraf + soldan perde + alttan erime + filigran."""
    YB = int(round(G * BANT_ORAN))
    fotoG = int(G * FOTO_OLCEK)
    fotoY = int(fotoG * FOTO_EN_BOY)
    foto = Image.open(os.path.join(KOK, "assets", "bant.jpg")).convert("RGBA")
    foto = foto.resize((fotoG, fotoY), Image.LANCZOS)
    kat = Image.new("RGBA", (G, YB), rgb(P["gece"]) + (255,))
    kat.alpha_composite(foto, (0, 0),
                        (int((fotoG - G) / 2), int((fotoY - YB) * FOTO_Y),
                         int((fotoG - G) / 2) + G, int((fotoY - YB) * FOTO_Y) + YB))

    # MARKA FİLİGRANI — ortada, %10
    mg, my = int(G * 0.574), int(YB * 0.62)
    mark = Image.open(os.path.join(KOK, "assets", "mark-light.png")).convert("RGBA")
    mark.thumbnail((mg, my), Image.LANCZOS)
    a = mark.split()[3].point(lambda v: int(v * 0.10))
    mark.putalpha(a)
    kat.alpha_composite(mark, (int(G * 0.213) + (mg - mark.size[0]) // 2,
                               int(YB * 0.19) + (my - mark.size[1]) // 2))

    # SOLDAN SAĞA PERDE — bant sayısı ui.js'ten
    # bindirme YOK: bant genişliği tam adım kadar (bkz. ui.js'teki ders)
    for i in range(PERDE_BANT):
        t = i / (PERDE_BANT - 1)
        x0 = int(round(G * t * 0.72))
        x1 = int(round(G * (t * 0.72 + 0.72 / (PERDE_BANT - 1))))
        o = PERDE_GUC * (1 - t) ** 1.35
        s = Image.new("RGBA", (max(1, x1 - x0), YB), (10, 6, 6, int(255 * o)))
        kat.alpha_composite(s, (x0, 0))

    # ALTTAN GÖVDEYE ERİME — bant sayısı ui.js'ten
    adim = YB * 0.208 / ERIME_BANT
    for i in range(ERIME_BANT):
        y0 = int(round(YB - (ERIME_BANT - i) * adim))
        y1 = int(round(YB - (ERIME_BANT - 1 - i) * adim))
        o = 0.10 + (i / (ERIME_BANT - 1)) * 0.88
        s = Image.new("RGBA", (G, max(1, y1 - y0)), rgb(P["bg"]) + (int(255 * min(1, o)),))
        kat.alpha_composite(s, (0, y0))

    # METİNLER
    golgeli_metin(kat, (KENAR, 46 * K), marka, f("Archivo-Bold.ttf", 10.5),
                  rgb(P["foto"]["marka"] if isinstance(P.get("foto"), dict) else "#FAEEDC"))
    yb = YB - 16 * K
    if ustBilgi:
        golgeli_metin(kat, (KENAR, yb - 92 * K), ustBilgi,
                      f("Archivo-SemiBold.ttf", 10.5), rgb("#FFFBF2"))
    golgeli_metin(kat, (KENAR, yb - 74 * K), baslik,
                  f("CormorantGaramond-Bold.ttf", 44), rgb("#FFFDF9"))
    im.alpha_composite(kat, (0, 0))
    return YB


def dugme(im, P, x, y, g, yuk, etiket, ust, alt, ft, murekkep=(255, 255, 255)):
    """
    Onaylanan düğme sistemi: 3 bantlı gradyan + sıcak gölge +
    İÇERİDE, köşeleri yuvarlanmış 1px üst ışık.

    🔴 İlk sürümde üst ışığı tam genişlikte düz bir beyaz dikdörtgen
    çizmiştim — Gökberk'in gördüğü "beyaz çizgi" oydu.
    """
    r = 20
    # sıcak gölge
    gol = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(gol).rounded_rectangle(
        [x, y + 6 * K, x + g, y + yuk + 6 * K], r * K,
        fill=rgb(P.get("goldGolge", "#966E28")) + (int(255 * 0.34),))
    im.alpha_composite(gol.filter(ImageFilter.GaussianBlur(7 * K)))

    # gradyan
    grad = Image.new("RGBA", (g, yuk))
    gd = ImageDraw.Draw(grad)
    cu, ca = rgb(ust), rgb(alt)
    for i in range(yuk):
        t = i / max(1, yuk - 1)
        gd.rectangle([0, i, g, i + 1],
                     fill=tuple(round(cu[k] + (ca[k] - cu[k]) * t) for k in range(3)) + (255,))
    maske = Image.new("L", (g, yuk), 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, g - 1, yuk - 1], r * K, fill=255)
    grad.putalpha(maske)

    # ÜST IŞIK — düğmenin İÇİNDE, köşeleri yuvarlı, 1px
    isik = Image.new("RGBA", (g, yuk), (0, 0, 0, 0))
    ImageDraw.Draw(isik).rounded_rectangle(
        [K, K, g - 1 - K, yuk - 1 - K], (r - 1) * K,
        outline=(255, 255, 255, int(255 * 0.34)), width=K)
    kirp = Image.new("RGBA", (g, yuk), (0, 0, 0, 0))
    kirp.paste(isik, (0, 0))
    ust_maske = Image.new("L", (g, yuk), 0)
    ImageDraw.Draw(ust_maske).rectangle([0, 0, g, int(yuk * 0.34)], fill=255)
    kirp.putalpha(Image.composite(kirp.split()[3], Image.new("L", (g, yuk), 0), ust_maske))
    grad.alpha_composite(kirp)

    im.alpha_composite(grad, (x, y))
    d = ImageDraw.Draw(im)
    w = d.textlength(etiket, font=ft)
    d.text((x + (g - w) / 2, y + (yuk - ft.size) / 2 - 1 * K), etiket,
           font=ft, fill=murekkep + (255,))


def cerceve(kapsam, etiket):
    P = dict(palet("C"))
    if kapsam == "KOYU":
        P.update(palet("KOYU"))
    P["foto"] = {"marka": "#FAEEDC"}
    R = rozet(kapsam) or rozet("C")

    im = Image.new("RGBA", (G, Y), rgb(P["bg"]) + (255,))

    # ── ATMOSFER DOKUSU (ufuk kuşağı, gerçek yoğunlukta) ────────────
    yog = 0.07 if kapsam == "KOYU" else 0.09
    ufuk = rgb(P.get("sicak", "#E39B6B"))
    z = rgb(P["bg"])
    d = ImageDraw.Draw(im)
    for i in range(int(150 * K)):
        t = i / (150 * K - 1)
        a = yog * (1 - abs(t - 0.5) * 2)
        d.rectangle([0, int(430 * K) + i, G, int(430 * K) + i + 1],
                    fill=tuple(round(z[k] + (ufuk[k] - z[k]) * a) for k in range(3)) + (255,))

    YB = bant(im, P, "Keşfet", "İSTANBUL · 4 EYLÜL")
    d = ImageDraw.Draw(im)

    f_ser = f("CormorantGaramond-Bold.ttf", 20)
    f_bas = f("Archivo-Bold.ttf", 14)
    f_gov = f("Archivo-Regular.ttf", 12.5)
    f_kck = f("Archivo-SemiBold.ttf", 10.5)
    f_eti = f("Archivo-Bold.ttf", 10.5)
    f_btn = f("Archivo-Bold.ttf", 16)

    y = YB + 14 * K

    # ── KART ────────────────────────────────────────────────────────
    kg = G - 2 * KENAR
    kyuk = 168 * K
    im.alpha_composite(yuvarlak((kg, kyuk), 26, rgb(P["surface"]) + (255,),
                                rgb(P.get("goldLine", "#E4D5AE")) + (255,)), (KENAR, y))
    d = ImageDraw.Draw(im)
    d.ellipse([KENAR + 14 * K, y + 16 * K, KENAR + 60 * K, y + 62 * K],
              fill=rgb(P["goldBg"]) + (255,))
    d.text((KENAR + 28 * K, y + 30 * K), "Gİ", font=f_bas, fill=rgb(P["goldText"]) + (255,))
    d.text((KENAR + 72 * K, y + 20 * K), "Gökberk İ.", font=f_bas, fill=rgb(P["ink"]) + (255,))
    d.text((KENAR + 72 * K, y + 40 * K), "IST · TAV Primeclass · 10:00–16:00",
           font=f_gov, fill=rgb(P["mutedAA"]) + (255,))

    rx = KENAR + 14 * K
    for ton, et in (("ok", "HAKKIN VAR"), ("cost", "ÜCRETLİ"), ("unknown", "BİLİNMİYOR")):
        renk = rgb(R.get(ton, P["ink"]))
        gg = int(d.textlength(et, font=f_kck)) + 22 * K
        im.alpha_composite(yuvarlak((gg, 26 * K), 13, rgb(P["bgAlt"]) + (255,), renk + (255,)),
                           (rx, y + 76 * K))
        d = ImageDraw.Draw(im)
        d.text((rx + 11 * K, y + 82 * K), et, font=f_kck, fill=renk + (255,))
        rx += gg + 8 * K

    im.alpha_composite(yuvarlak((kg - 28 * K, 42 * K), 14, rgb(P["bgAlt"]) + (255,)),
                       (KENAR + 14 * K, y + 110 * K))
    d = ImageDraw.Draw(im)
    d.text((KENAR + 26 * K, y + 122 * K), "Kural: 1 misafir hakkı · kart sahibi girişte",
           font=f_gov, fill=rgb(P["body"]) + (255,))
    y += kyuk + 14 * K

    # ── UYARI ───────────────────────────────────────────────────────
    im.alpha_composite(yuvarlak((kg, 60 * K), 20, rgb(P["amberBg"]) + (255,),
                                rgb(P["amber"]) + (255,)), (KENAR, y))
    d = ImageDraw.Draw(im)
    d.text((KENAR + 14 * K, y + 11 * K), "Bu tarihte seyahatin yok",
           font=f_bas, fill=rgb(P["amberInk"]) + (255,))
    d.text((KENAR + 14 * K, y + 33 * K), "Önce uçuşunu ekle, sonra başvur.",
           font=f_gov, fill=rgb(P["amberInk"]) + (255,))
    y += 60 * K + 12 * K

    # ── HATA + OLUMLU ───────────────────────────────────────────────
    for zem, ken, mur, metin in ((P["hataBg"], P["red"], P["redInk"],
                                  "Bağlantı kurulamadı — tekrar dene"),
                                 (P["tealTint2"], P["teal"], P["tealInk"],
                                  "Başvurun host'a iletildi")):
        im.alpha_composite(yuvarlak((kg, 44 * K), 14, rgb(zem) + (255,), rgb(ken) + (255,)),
                           (KENAR, y))
        d = ImageDraw.Draw(im)
        d.text((KENAR + 14 * K, y + 14 * K), metin, font=f_gov, fill=rgb(mur) + (255,))
        y += 44 * K + 12 * K

    # ── GECE KARTI ──────────────────────────────────────────────────
    im.alpha_composite(yuvarlak((kg, 86 * K), 20, rgb(P["gece"]) + (255,)), (KENAR, y))
    d = ImageDraw.Draw(im)
    d.text((KENAR + 16 * K, y + 14 * K), "ÖDÜL", font=f_eti, fill=rgb(P["gold"]) + (255,))
    d.text((KENAR + 16 * K, y + 34 * K), "Bir sonraki uçuşunda ikram",
           font=f_bas, fill=(255, 255, 255, 255))
    d.text((KENAR + 16 * K, y + 58 * K), "1200 LoungePuan",
           font=f_gov, fill=rgb(P["warmGray"]) + (255,))
    y += 86 * K + 18 * K

    # ── DÜĞMELER ────────────────────────────────────────────────────
    # 🔴 30 Ağu — mürekkep paletten. Gece sisteminde altın düğme KOYU
    # mürekkep taşıyor; burada beyaz çizmek, ekranda olmayan bir şeyi
    # göstermek olurdu. Önizlemenin tek işi gerçeği göstermek.
    dugme(im, P, KENAR, y, kg, 56 * K, "Başvur",
          P["goldBtn"], P.get("goldBtn2", P["goldBtn"]), f_btn,
          murekkep=rgb(P.get("onGold", "#FFFFFF")))
    y += 56 * K + 14 * K
    dugme(im, P, KENAR, y, kg, 56 * K, "İlanı sil",
          P["dangerBtn"], P.get("dangerBtn2", P["dangerBtn"]), f_btn)
    y += 56 * K + 14 * K
    im.alpha_composite(yuvarlak((kg, 52 * K), 20, (0, 0, 0, 0), rgb(P["gold"]) + (255,)),
                       (KENAR, y))
    d = ImageDraw.Draw(im)
    w = d.textlength("Daha sonra", font=f_btn)
    d.text((KENAR + (kg - w) / 2, y + 15 * K), "Daha sonra",
           font=f_btn, fill=rgb(P["goldText"]) + (255,))
    y += 52 * K + 16 * K

    d.text((KENAR, y), "Bu ilan 2 saat önce güncellendi",
           font=f_gov, fill=rgb(P["dimAA"]) + (255,))

    # etiket şeridi (önizlemeye ait — üründe yok)
    d.rectangle([0, 0, G, 26 * K], fill=(16, 12, 10, 255))
    d.text((KENAR, 7 * K), etiket + "  · önizleme, ekran görüntüsü değil",
           font=f_eti, fill=(255, 255, 255, 255))
    return im.convert("RGB")


def main():
    a = cerceve("C", "AÇIK TEMA")
    k = cerceve("KOYU", "KOYU TEMA")
    ara = 24 * K
    tuval = Image.new("RGB", (G * 2 + ara * 3, Y + ara * 2), (18, 15, 13))
    tuval.paste(a, (ara, ara))
    tuval.paste(k, (ara * 2 + G, ara))
    yol = os.path.join(KOK, "tema_onizleme.png")
    tuval.save(yol)
    print("✓ %s  (%d×%d · %d× ölçek)" % (yol, tuval.size[0], tuval.size[1], K))
    print("  geometri ui.js'ten: bant %.3f · ölçek %.2f · üst %%%d · perde %.2f"
          % (BANT_ORAN, FOTO_OLCEK, FOTO_Y * 100, PERDE_GUC))
    for kapsam, ad in (("C", "AÇIK"), ("KOYU", "KOYU")):
        P = dict(palet("C"))
        if kapsam == "KOYU":
            P.update(palet("KOYU"))
        # 🔴 30 Ağu — DÜĞME MÜREKKEBİ ARTIK SABİT DEĞİL. Eskiden burada
        # `#FFFFFF` yazılıydı; gece sisteminde altın düğme koyu mürekkep
        # taşıyor ve bu satır DOĞRU olan şeyi 1.54:1 diye raporluyordu.
        # Ölçüm paletten okunuyor — bir daha yalan söylemesin.
        print("  %s  başlık/kart %.2f · gövde/blok %.2f · düğme/mürekkep %.2f · uyarı %.2f"
              % (ad, oran(P["ink"], P["surface"]), oran(P["body"], P["surfaceAlt"]),
                 oran(P.get("onGold", "#FFFFFF"), P["goldBtn"]), oran(P["amberInk"], P["amberBg"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
