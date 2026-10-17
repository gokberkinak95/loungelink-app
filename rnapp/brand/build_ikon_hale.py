# v8 HALE - kemersiz ucak ikonu (17 Ekim, Gokberk secimi: B "Hale").
# Gece mavisi zeminde kendi isigini sacan fildisi kanat; arkasinda mavi + sampanya hale
# (Riley tarzi yumusak bulanik isik). Kemerli v7 ikonu: _arsiv/ikon_kemer_20261017/.
# Ciktilar:
#   rnapp/assets: icon.png (1024, RGB), adaptive-icon.png, monochrome-icon.png, favicon.png
#   website: app/icon.png + app/apple-icon.png (256), public/icon.png (1024), public/favicon.png (64)
#   backoffice: public/icon.png (1024), public/favicon.png (64)
# Kullanim:  python brand/build_ikon_hale.py              -> sevkiyata (assets + website + backoffice) yazar
#            python brand/build_ikon_hale.py <klasor>     -> yalniz app varliklari o klasore (marka_check)
#            python brand/build_ikon_hale.py --yalniz-onizleme <klasor>
import os, sys
from PIL import Image, ImageDraw, ImageFilter

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))     # rnapp
PROJE = os.path.dirname(KOK)
A = os.path.join(KOK, "assets")
S = 1024
KREM = (250, 238, 220)
SAMP = (214, 195, 163)
BEYAZ_SICAK = (255, 248, 236)

KANAT = Image.open(os.path.join(A, "mark-kanat.png")).convert("RGBA").getchannel("A")


def gradyan(ust, alt):
    col = Image.new("RGB", (1, S))
    for y in range(S):
        t = y / (S - 1)
        col.putpixel((0, y), tuple(int(ust[i] + (alt[i] - ust[i]) * t) for i in range(3)))
    return col.resize((S, S)).convert("RGBA")


def hale(merkez, yaricap, renk, alfa):
    g = Image.new("RGBA", (S, S), renk + (0,))
    m = Image.new("L", (S, S), 0)
    x, y = merkez
    ImageDraw.Draw(m).ellipse([x - yaricap, y - yaricap, x + yaricap, y + yaricap], fill=alfa)
    g.putalpha(m.filter(ImageFilter.GaussianBlur(yaricap * 0.6)))
    return g


def kanat_maske(genislik, kalin, dy):
    # ince kanat kucuk boyda (29-40 px) kaybolmasin diye MaxFilter ile kalinlastirilir
    m = KANAT.resize((genislik, int(genislik * KANAT.height / KANAT.width)), Image.LANCZOS)
    if kalin:
        m = m.filter(ImageFilter.MaxFilter(kalin))
    tuval = Image.new("L", (S, S), 0)
    tuval.paste(m, (int(S / 2 - m.width / 2), int(S / 2 - m.height / 2) + dy))
    return tuval


def renkli(m, renk, alfa=1.0, blur=0):
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    if alfa < 1:
        m = m.point(lambda v: int(v * alfa))
    im = Image.new("RGBA", (S, S), renk + (0,))
    im.putalpha(m)
    return im


def ikon(olcek=1.0):
    """olcek: kanat + hale boyu (1.0 = App Store ikonu; adaptive icin kucultulur)."""
    k = olcek
    c = S / 2
    im = gradyan((18, 30, 58), (6, 10, 24))
    im.alpha_composite(hale((c - 92 * k, c + 88 * k), 330 * k, (60, 105, 175), 170))
    im.alpha_composite(hale((c + 128 * k, c - 82 * k), 230 * k, (214, 180, 130), 120))
    m = kanat_maske(int(800 * k), max(3, int(11 * k) | 1), int(20 * k))
    im.alpha_composite(renkli(m, (150, 185, 235), 0.55, 90 * k))
    im.alpha_composite(renkli(m, SAMP, 0.8, 38 * k))
    im.alpha_composite(renkli(m, KREM, 0.95, 14 * k))
    im.alpha_composite(renkli(m, BEYAZ_SICAK, 1, 3.5 * k))
    # Koyu degrade + hale 8 bitte basamak (bant) yapar; ucgen dagilimli +-1 LSB titresim
    # bantlari kirar. Tohum sabit -> her calisma ayni dosyayi uretir (marka_check birebir).
    import numpy as np
    rng = np.random.default_rng(int(olcek * 1000))
    d = np.asarray(im.convert("RGB"), dtype=np.float64)
    d = d + (rng.random(d.shape[:2] + (1,)) - rng.random(d.shape[:2] + (1,)))
    return Image.fromarray(np.clip(np.round(d), 0, 255).astype(np.uint8), "RGB")


def monokrom():
    # Android 13+ temali ikon: yalniz kanat, beyaz, saydam zemin, guvenli dairenin icinde
    m = kanat_maske(560, 9, 14)
    im = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    im.putalpha(m)
    return im


def acilis_yerel():
    # Yerel acilis ekrani: SAYDAM. Zemin app.json splash.backgroundColor = sis (#DCE3EF);
    # bulutlardan cikis hareketi (src/acilis.js) tam bu sis karesinden baslar.
    return Image.new("RGBA", (1284, 1284), (0, 0, 0, 0))


def main():
    hedef = None
    if len(sys.argv) == 2 and not sys.argv[1].startswith("--"):
        # marka_check: yalniz app varliklari, duz adlarla
        d = sys.argv[1]
        os.makedirs(d, exist_ok=True)
        ikon(1.0).save(os.path.join(d, "icon.png"))
        ikon(0.66).save(os.path.join(d, "adaptive-icon.png"))
        monokrom().save(os.path.join(d, "monochrome-icon.png"))
        ikon(1.0).resize((64, 64), Image.LANCZOS).save(os.path.join(d, "favicon.png"))
        acilis_yerel().save(os.path.join(d, "splash.png"))
        print("ok ->", d)
        return
    if len(sys.argv) > 2 and sys.argv[1] == "--yalniz-onizleme":
        hedef = sys.argv[2]
        os.makedirs(hedef, exist_ok=True)
    I = ikon(1.0)
    AD = ikon(0.66)         # adaptive: Android maskesi kenarlari keser, kanat guvenli %66 dairede kalir
    MO = monokrom()
    yaz = []
    def kaydet(im, yol, boy=None):
        if boy:
            im = im.resize((boy, boy), Image.LANCZOS)
        if hedef:
            yol = os.path.join(hedef, os.path.relpath(yol, PROJE).replace(os.sep, "__"))
        im.save(yol)
        yaz.append((yol, im.size))
    kaydet(I, os.path.join(A, "icon.png"))
    kaydet(AD, os.path.join(A, "adaptive-icon.png"))
    kaydet(MO, os.path.join(A, "monochrome-icon.png"))
    kaydet(I, os.path.join(A, "favicon.png"), 64)
    kaydet(acilis_yerel(), os.path.join(A, "splash.png"))
    W = os.path.join(PROJE, "website")
    kaydet(I, os.path.join(W, "app", "icon.png"), 256)
    kaydet(I, os.path.join(W, "app", "apple-icon.png"), 256)
    kaydet(I, os.path.join(W, "public", "icon.png"))
    kaydet(I, os.path.join(W, "public", "favicon.png"), 64)
    B = os.path.join(PROJE, "backoffice")
    kaydet(I, os.path.join(B, "public", "icon.png"))
    kaydet(I, os.path.join(B, "public", "favicon.png"), 64)
    for y, s in yaz:
        print("ok", s, os.path.relpath(y, PROJE))


if __name__ == "__main__":
    main()
