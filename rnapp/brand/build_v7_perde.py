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
