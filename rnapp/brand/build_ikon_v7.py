# v7 AVIATION LIGHT - uygulama ikonu, adaptive, monochrome, favicon, splash.
# cairosvg bu makinede calismiyor -> mevcut katmanlardan (mark-kemer*, mark-kanat) PIL ile.
# Kemer: sampanya (#E6DAC4 -> #D4C3A3 -> #C4AF88). Pencere ici: gece mavisi -> safak
# (uygulamadaki bandin aynisi). Kanat: fildisi. Zemin: gece mavisi.
# Kullanim:  python brand/build_ikon_v7.py [cikti_klasoru]   (varsayilan: assets/)
import os, sys
from PIL import Image, ImageChops, ImageFilter

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(KOK, "assets")
OUT = sys.argv[1] if len(sys.argv) > 1 else A
os.makedirs(OUT, exist_ok=True)

GECE, GECE2, INK = (26, 43, 76), (34, 54, 92), (13, 27, 42)
SIS, GOK = (230, 235, 240), (159, 179, 203)
SAMP_UST, SAMP, SAMP_ALT = (230, 218, 196), (212, 195, 163), (196, 175, 136)
FILDISI = (249, 248, 246)
AMBER = (226, 135, 67)


def dikey(w, h, duraklar):
    """duraklar: [(0..1, (r,g,b)), ...] -> RGB dikey gradyan"""
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(duraklar) - 1):
            t0, c0 = duraklar[i]; t1, c1 = duraklar[i + 1]
            if t0 <= t <= t1:
                u = (t - t0) / max(1e-6, t1 - t0)
                col.putpixel((0, y), tuple(round(c0[k] + (c1[k] - c0[k]) * u) for k in range(3)))
                break
    return col.resize((w, h))


def katmanlar():
    kemer = Image.open(os.path.join(A, "mark-kemer.png")).convert("RGBA")
    ink = Image.open(os.path.join(A, "mark-kemer-ink.png")).convert("RGBA")
    # olculdu: ink varyantinda halka opak (a~250), kanat yari saydam (a 65-150);
    # kemer.png'de ic zemin a=229-242, tabanin altindaki golge a=64 (disarida birakilir).
    # 2x calisma cozunurlugu + yumusak rampalar: 512'lik maskeyi esiklemek ikonda merdiven yapiyordu
    S2 = (1024, 1024)
    kemer = kemer.resize(S2, Image.LANCZOS); ink = ink.resize(S2, Image.LANCZOS)
    halka = ink.getchannel("A").point(lambda v: 0 if v < 170 else min(255, (v - 170) * 4))
    halka_genis = halka.point(lambda v: 255 if v > 20 else 0).filter(ImageFilter.MaxFilter(9))
    a_tum = kemer.getchannel("A").point(lambda v: 0 if v < 150 else min(255, (v - 150) * 4))
    # ic = halkanin ICINDE kalan bolge (merkezden flood fill). a_tum - halka farki kemer.png'nin
    # dis kenarindaki koyu konturu da ic sayiyordu (olculdu: kemerin disinda 2px koyu cizgi).
    from PIL import ImageDraw
    sinir = halka.point(lambda v: 255 if v > 60 else 0)
    dolgu = sinir.copy()
    ImageDraw.floodfill(dolgu, (512, 560), 128)
    ic = dolgu.point(lambda v: 255 if v == 128 else 0)
    # ic, halkanin ALTINA tasar: kenarda ince koyu kontur kalmasin
    ic = ic.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(1))
    # kanat: kemer.png'de parlak AMA halka olmayan pikseller (yumusak kenarli)
    KL = kemer.convert("L")
    kanat = KL.point(lambda v: 0 if v < 70 else min(255, int((v - 70) * 1.6)))
    kanat = ImageChops.subtract(kanat, halka_genis)
    kanat = ImageChops.multiply(kanat, ic)  # yalniz pencerenin icinde (kemer dis parlakligi sizmasin)
    return halka, ic, kanat


def isaret(boy, renkli=True):
    """boy x boy RGBA: kemer + pencere ici + kanat (zemin saydam)."""
    halka, ic, kanat = katmanlar()
    s = 1024
    # saydam piksellerin RGB'si sampanya: LANCZOS olcekleme siyahi kenara sizdirmasin
    out = Image.new("RGBA", (s, s), SAMP + (0,))
    # pencere ici: gece -> gok -> safak sisi -> ince amber ufuk
    bx = ic.getbbox()
    # kanat pencerenin %47-68'inde: o kusak hala gece-mavisi (fildisi kanat 6:1 okunur),
    # safak ve sis yalniz alt ucte -> "geceden safaga" pencere.
    H = lambda f: (bx[1] + (bx[3] - bx[1]) * f) / s
    pen = dikey(s, s, [(0, INK), (H(0), INK), (H(0.40), GECE), (H(0.72), (74, 98, 138)),
                       (H(0.86), GOK), (H(0.94), SIS), (H(0.985), (238, 214, 190)), (1, (238, 214, 190))])
    out.paste(pen, (0, 0), ic)
    kanat_renk = Image.new("RGB", (s, s), FILDISI)
    out.paste(kanat_renk, (0, 0), kanat)
    hb = halka.getbbox()
    sam = dikey(s, s, [(0, SAMP_UST), (hb[1] / s, SAMP_UST), ((hb[1] + hb[3]) / 2 / s, SAMP),
                       (hb[3] / s, SAMP_ALT), (1, SAMP_ALT)])
    out.paste(sam, (0, 0), halka)
    if boy != s:
        out = out.resize((boy, boy), Image.LANCZOS)
    return out


def zemin(boy):
    z = dikey(boy, boy, [(0, GECE2), (0.55, GECE), (1, INK)]).convert("RGBA")
    # sag ustten sampanya hale (%10)
    hale = Image.new("L", (boy, boy), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(hale)
    r = int(boy * 0.62)
    d.ellipse((boy * 0.78 - r, -boy * 0.18 - r, boy * 0.78 + r, -boy * 0.18 + r), fill=26)
    hale = hale.filter(ImageFilter.GaussianBlur(boy * 0.12))
    z.paste(Image.new("RGB", (boy, boy), SAMP), (0, 0), hale)
    return z


def yerlestir(taban, isr, olcek, dy=0):
    boy = taban.width
    w = int(boy * olcek)
    m = isr.resize((w, w), Image.LANCZOS)
    kat = Image.new("RGBA", taban.size, (0, 0, 0, 0))
    kat.paste(m, ((boy - w) // 2, (boy - w) // 2 + dy), m)
    taban.alpha_composite(kat)
    return taban


def main():
    I = isaret(1024)  # isaret tuvali: kemer genisligi tuvalin 324/512'si
    # ikon: kemer genisligi isaret tuvalinin 324/512'si -> ikonda ~690/1024 (eski ikonla ayni oran)
    ikon = yerlestir(zemin(1024), I, 1024 * 0.672 / 324 * 512 / 1024, dy=8)
    ikon.convert("RGB").save(os.path.join(OUT, "icon.png"))
    # adaptive: Android guvenli daire %66 -> isaret daha kucuk
    ad = yerlestir(zemin(1024), I, 1024 * 0.44 / 324 * 512 / 1024, dy=6)
    ad.convert("RGB").save(os.path.join(OUT, "adaptive-icon.png"))
    # monochrome: yalniz kemer + kanat beyaz, saydam zemin
    halka, ic, kanat = katmanlar()
    mono = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    mono.putalpha(ImageChops.lighter(halka, kanat))
    mono = mono.resize((int(1024 * 0.44 / 324 * 512), int(1024 * 0.44 / 324 * 512)), Image.LANCZOS)
    mtab = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mtab.alpha_composite(mono, ((1024 - mono.width) // 2, (1024 - mono.height) // 2 + 6))
    mtab.save(os.path.join(OUT, "monochrome-icon.png"))
    # favicon
    ikon.convert("RGB").resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "favicon.png"))
    # yerel acilis (splash): saydam zeminde isaret, arka plan app.json -> #1A2B4C
    sp = Image.new("RGBA", (1284, 1284), (0, 0, 0, 0))
    yerlestir(sp, I, 1284 * 0.30 / 324 * 512 / 1284)
    sp.save(os.path.join(OUT, "splash.png"))
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
