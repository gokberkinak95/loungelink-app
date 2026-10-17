# v8 ACILIS - "bulutlarin arasindan" sahnesinin gorselleri (src/acilis.js). 17 Ekim.
# Onayli onizleme v3 ile AYNI sekiller (ayni tohumlar, ayni oranlar); cozunurluk 1.5x ve
# hesap kayan noktada: bulaniklik scipy ile float'ta, sonra ucgen dagilimli +-1 LSB
# titresim (dither) ile 8 bite iner. Koyu lacivert uzerinde basamak/bant olusmaz.
# Kullanim:  python brand/build_acilis.py
import os, random
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(KOK, "assets")
RNG = np.random.default_rng(17)


def titresim(shape):
    return RNG.random(shape) - RNG.random(shape)


def kaydet(dizi, ad, mod):
    Image.fromarray(np.clip(np.round(dizi), 0, 255).astype(np.uint8), mod).save(os.path.join(A, ad), optimize=True)
    print("ok", ad, os.path.getsize(os.path.join(A, ad)) // 1024, "KB")


def bulut(ad, renk, tohum, alfa=255, olcek=1.5):
    # onizlemedeki banka(900, 1050): 10 ust tepe + 9 ara tepe + govde; kenarlar yumusak
    w0, h0 = 900, 1050
    w, h = int(w0 * olcek), int(h0 * olcek)
    random.seed(tohum)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    adim = w0 / 9
    for i in range(10):
        r = random.uniform(w0 * 0.08, w0 * 0.12); x = i * adim + random.uniform(-adim * 0.3, adim * 0.3); y = random.uniform(h0 * 0.3, h0 * 0.4)
        d.ellipse([(x - r * 1.3) * olcek, (y - r) * olcek, (x + r * 1.3) * olcek, (y + r) * olcek], fill=alfa)
    for i in range(9):
        r = random.uniform(w0 * 0.06, w0 * 0.09); x = (i + 0.5) * adim; y = random.uniform(h0 * 0.36, h0 * 0.44)
        d.ellipse([(x - r * 1.3) * olcek, (y - r) * olcek, (x + r * 1.3) * olcek, (y + r) * olcek], fill=alfa)
    d.rectangle([0, int(h * 0.42), w, h], fill=alfa)
    a = np.asarray(m, dtype=np.float64)
    a = gaussian_filter(a, sigma=w0 * 0.03 * olcek)   # PIL GaussianBlur(r) yaricapi = sigma
    yx = np.minimum(np.arange(w), np.arange(w)[::-1]) / (w * 0.1)
    yy = np.arange(h) / (h * 0.1)
    a *= np.clip(yx, 0, 1)[None, :] * np.clip(yy, 0, 1)[:, None]
    a = a + titresim(a.shape)
    rgb = np.broadcast_to(np.array(renk, dtype=np.float64), (h, w, 3))
    kaydet(np.dstack([rgb, a]), ad, "RGBA")


def gok():
    H, W = 866, 400
    D = [(0, (14, 26, 54)), (0.55, (26, 43, 76)), (1, (43, 65, 112))]
    t = np.linspace(0, 1, H)
    img = np.zeros((H, W, 3))
    for c in range(3):
        img[:, :, c] = np.interp(t, [p for p, _ in D], [k[c] for _, k in D])[:, None]
    kaydet(img + titresim((H, W, 1)), "acilis_gok.png", "RGB")


def isik():
    N = 1024
    y, x = np.mgrid[0:N, 0:N]
    r = np.hypot(x - N / 2 + 0.5, y - N / 2 + 0.5) / (N / 2)
    a = np.where(r <= 0.3, 0.75 + (0.35 - 0.75) * (r / 0.3), np.where(r <= 0.65, 0.35 * (1 - (r - 0.3) / 0.35), 0))
    u = np.clip(r / 0.3, 0, 1)
    R = np.where(r <= 0.3, 246 + (214 - 246) * u, 214)
    G = np.where(r <= 0.3, 226 + (195 - 226) * u, 195)
    B = np.where(r <= 0.3, 190 + (163 - 190) * u, 163)
    kaydet(np.dstack([R, G, B, a * 255 + titresim(a.shape)]), "acilis_isik.png", "RGBA")


def kanat_bulanik():
    # mark-kanat.png + her yanda 160px pay; float bulaniklik (onizlemedeki 14px CSS blur karsiligi)
    k = Image.open(os.path.join(A, "mark-kanat.png")).convert("RGBA")
    P = 160
    a = np.zeros((k.height + 2 * P, k.width + 2 * P))
    a[P:P + k.height, P:P + k.width] = np.asarray(k.getchannel("A"), dtype=np.float64)
    a = np.minimum(255, gaussian_filter(a, sigma=70) * 1.6) + titresim(a.shape)
    rgb = np.broadcast_to(np.array((250, 238, 220), dtype=np.float64), a.shape + (3,))
    kaydet(np.dstack([rgb, a]), "acilis_kanat_bulanik.png", "RGBA")


if __name__ == "__main__":
    bulut("acilis_bulut_on.png", (240, 242, 248), 21)
    bulut("acilis_bulut_orta.png", (196, 207, 228), 22, 245)
    bulut("acilis_bulut_arka.png", (132, 152, 190), 23, 235)
    gok()
    isik()
    kanat_bulanik()
