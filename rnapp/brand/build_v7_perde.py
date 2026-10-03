# v7 perde gradyanlari - RENGI GOMULU (tintColor'a bagli degil).
# Neden: react-native-web tintColor'i SVG filtresiyle uyguluyor ve filtre kimlikleri
# kayiyor (olculdu: katman #tint-5'e bakiyor, sayfada yok -> Chrome katmani hic cizmiyor;
# #tint-6 yanlis renkte). Acilis ekraninin sis/fildisi gecisi bu yuzden gorunmuyordu.
# Ciktilar (4x512, ust opak -> alt saydam; ters cevirmek icin *_alt surumleri):
#   assets/v7_gece_ust.png   #1A2B4C  ust opak
#   assets/v7_sis_alt.png    #E6EBF0  alt opak
#   assets/v7_fildisi_alt.png #F9F8F6 alt opak
import os
from PIL import Image

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(KOK, "assets")

def yap(ad, renk, alttan):
    w, h = 4, 512
    im = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / (h - 1)
        a = round(255 * (t if alttan else 1 - t))
        for x in range(w):
            im.putpixel((x, y), renk + (a,))
    im.save(os.path.join(A, ad))
    print(ad)

yap("v7_gece_ust.png", (26, 43, 76), False)
yap("v7_sis_alt.png", (230, 235, 240), True)
yap("v7_fildisi_alt.png", (249, 248, 246), True)
yap("v7_isik_ust.png", (255, 255, 255), False)

# Kanat isaretinin renkli surumleri (alfa ayni, renk gomulu)
k = Image.open(os.path.join(A, "mark-kanat.png")).convert("RGBA")
for ad, renk in (("mark-kanat-sampanya.png", (212, 195, 163)), ("mark-kanat-bronz.png", (138, 114, 71))):
    yeni = Image.new("RGBA", k.size, renk + (0,))
    yeni.putalpha(k.getchannel("A"))
    yeni.save(os.path.join(A, ad))
    print(ad)

# Isik bulutlari (K9) - renk gomulu; web'de tintColor filtresi kayiyordu
b = Image.open(os.path.join(A, "isik_bulutu.png")).convert("RGBA")
for ad, renk in (("isik_bulutu_sampanya.png", (212, 195, 163)), ("isik_bulutu_gok.png", (159, 179, 203))):
    yeni = Image.new("RGBA", b.size, renk + (0,))
    yeni.putalpha(b.getchannel("A"))
    yeni.save(os.path.join(A, ad))
    print(ad)

# Tanitim perdesi (v7): sicak siyah yerine gece mavisi, alt opak
yap("v7_gece_alt.png", (13, 27, 42), True)

# Acilis perdesi (tek parca, A tuvali duraklari): renk + alfa birlikte enterpole edilir.
# Neden tek parca: yuzde yukseklikli serit katmanlar web'de guvenilir cizilmedi
# (olculdu: %74-%90 fildisi rampasi hic cizilmemis, Giris yap'in ustunde sert cizgi).
DURAK = [(0.00, (26, 43, 76), 0.82), (0.40, (26, 43, 76), 0.50), (0.56, (40, 58, 92), 0.44),
         (0.74, (230, 235, 240), 0.92), (0.90, (249, 248, 246), 1.00), (1.00, (249, 248, 246), 1.00)]
h = 1024
im = Image.new("RGBA", (8, h))
for y in range(h):
    t = y / (h - 1)
    for i in range(len(DURAK) - 1):
        t0, c0, a0 = DURAK[i]; t1, c1, a1 = DURAK[i + 1]
        if t0 <= t <= t1:
            u = (t - t0) / max(1e-6, t1 - t0)
            u = u * u * (3 - 2 * u)   # yumusak gecis (smoothstep): duraklarda kirik yok
            c = tuple(round(c0[k] + (c1[k] - c0[k]) * u) for k in range(3))
            a = round(255 * (a0 + (a1 - a0) * u))
            for x in range(8):
                im.putpixel((x, y), c + (a,))
            break
im.save(os.path.join(A, "v7_acilis_perde.png"))
print("v7_acilis_perde.png")

# Bildirim kucuk ikonu (Android): BEYAZ siluet, saydam zemin, 96x96 — kanat (v7 marka isareti).
k = Image.open(os.path.join(A, "mark-kanat.png")).convert("RGBA")
alfa = k.getchannel("A")
bbox = alfa.getbbox()
alfa = alfa.crop(bbox)
w, h = alfa.size
olcek = 80 / max(w, h)
alfa = alfa.resize((max(1, round(w * olcek)), max(1, round(h * olcek))), Image.LANCZOS)
ikon = Image.new("RGBA", (96, 96), (255, 255, 255, 0))
beyaz = Image.new("RGBA", alfa.size, (255, 255, 255, 255)); beyaz.putalpha(alfa)
ikon.alpha_composite(beyaz, ((96 - alfa.width) // 2, (96 - alfa.height) // 2))
ikon.save(os.path.join(A, "notification-icon.png"))
print("notification-icon.png")

# altin_v7.png: sampanya dugme gradyani (Btn / sikke / secili cip ortak malzemesi).
# Ust #E6DAC4 (goldBtnUst) -> alt #C4AF88 (goldBtn2), 4x512 dogrusal; orta nokta #D4C3A3.
# (Sevkiyattaki dosyayla kanal basina en fazla 3/255 fark; 3 Ekim olculdu.)
g = Image.new("RGB", (4, 512))
for y in range(512):
    t = y / 511.0
    c = tuple(int(round(a + (b - a) * t)) for a, b in zip((0xE6, 0xDA, 0xC4), (0xC4, 0xAF, 0x88)))
    for x in range(4):
        g.putpixel((x, y), c)
g.save(os.path.join(A, "altin_v7.png"))
print("altin_v7.png")
