# -*- coding: utf-8 -*-
"""
LoungeLink · gren_check.py  —  57. DENETİM
TIRTIKLI GEÇİŞ (banding) — ÇEKİLEN SAHNENİN PİKSELLERİNDEN

🔴 NEDEN VAR — VE NEDEN `doku_check.py` YETMEDİ (12 Eylül, Gökberk md.3)
"iç ekranların ortasında tırtıklı halde geçiş tonu var, ayrıca header
alanındaki görseller de tırtıklı gibi."

`doku_check.py` bu kusuru zaten arıyordu ve GEÇİYORDU. Çünkü yanlış
soruyu soruyordu: "dosyadaki komşu satırlar arasında 1'den büyük sıçrama
var mı?" Yok — dosya 256 satır ve her adım 1 ton. Ama o dosya ekranda
GERİLİYOR: 14 ayrı ton 169 pt'ye yayılınca her ton 5.3 pt'lik DÜZ bir
şerit oluyor ve göz o şeridin kenarını KENAR olarak görüyor.

🆕 SINIF: "BİR NÖBETÇİ GEÇİYOR AMA KUSUR GÖRÜNÜYORSA, NÖBETÇİ YANLIŞ
DEĞİL YANLIŞ YERDE DURUYORDUR — DOSYAYI DEĞİL EKRANI ÖLÇ."

NE ÖLÇÜYOR: her sahnenin PNG'sinde, içerik olmayan (düşük kontrastlı)
sütunlar boyunca "plato" uzunluğu — ton değişmeden kaç piksel gidiliyor.
Plato ne kadar uzunsa şerit o kadar geniş, yani o kadar görünür.

EŞİK: 3.0 pt. Ölçüm: grensiz hâlde medyan plato 5.3 pt (maks 6.7),
`assets/tanecik.png` serildikten sonra 1.3 pt.
"""
import os, sys, glob

TAVAN_PT = 3.0
OLCEK = 3          # sahneler @3x çekiliyor

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("gren_check: Pillow/numpy yok")
    sys.exit(0)

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(KOK, "web_sahne", "out")

# Ölçüm yalnız ZEMİNİ olan koyu tema sahnelerinde anlamlı; metin ve kart
# kenarları plato ölçümünü bozar, o yüzden düşük tepe genlikli sütunlar
# seçiliyor.
def plato(dosya):
    a = np.asarray(Image.open(dosya).convert("RGB")).astype(float)[..., 0]
    H, W = a.shape
    y0, y1 = int(H * 0.45), int(H * 0.92)      # bant ve sekme çubuğu dışarıda
    en_uzun, sutun = 0, None
    for x in range(60, W - 60, 40):
        s = a[y0:y1, x]
        # ⚠️ İÇERİK ELENMELİ. İlk sürümde eşik 40'tı ve kart kenarı olan
        # sütunlar da ölçüme giriyordu: üç sahne haksız yere kırmızıya
        # döndü (03_kural, 05b, 32 — ölçtüm: o sütunlarda yatay komşu
        # σ = 4.7 / 12.3 / 18.0, yani orada gradyan değil METİN var).
        # Gradyanın kendisi YATAYDA düzdür: komşu piksel σ'sı < 1.5.
        if s.max() - s.min() > 25:
            continue
        pencere = a[y0:y1, max(0, x - 30):x + 30]
        if pencere.std(axis=1).mean() > 1.5:
            continue
        # 🔴 26 EYLÜL — YALNIZ BANT ADIMLARI SAYILIR. Bir gradyan şeridi
        # komşu tona 1–2 birimle geçer; kart kenarı 10+ birim sıçrar.
        # 03_kural'da x=900 sütununda TOPLAM 3 değişim vardı ve ikisi kart
        # alt kenarıydı (23→35→10): "medyan plato" düz kart yüzeyinin
        # boyunu ölçüyordu, şeridi değil (numpy bu makinede ilk kez
        # kurulunca ortaya çıktı).
        # 🆕 SINIF: "BİR ŞERİDİ ÖLÇERKEN KENARI DA ADIM SAYARSAN, DÜZ
        # BİR YÜZEYİ TIRTIKLI SANIRSIN."
        fark = np.diff(np.round(s))
        deg = np.where((fark != 0) & (np.abs(fark) <= 2))[0]
        if len(deg) < 3:
            continue                            # tamamen düz: gradyan yok
        m = float(np.median(np.diff(deg)))
        if m > en_uzun:
            en_uzun, sutun = m, x
    return en_uzun, sutun


dosyalar = sorted(glob.glob(os.path.join(OUT, "*.png")))
dosyalar = [d for d in dosyalar if not os.path.basename(d).startswith("_")]
if not dosyalar:
    print("gren_check: web_sahne/out boş — önce `python3 web_sahne/cek.py`")
    sys.exit(0)

kotu, olculen, en_kotu = [], 0, (0, "")
for d in dosyalar:
    p, x = plato(d)
    if not p:
        continue
    olculen += 1
    pt = p / OLCEK
    if pt > en_kotu[0]:
        en_kotu = (pt, os.path.basename(d)[:-4])
    if pt > TAVAN_PT:
        kotu.append((os.path.basename(d)[:-4], round(pt, 2), x))

print(f"gren_check · gradyanı ölçülebilen sahne: {olculen} · tavan {TAVAN_PT} pt")
print(f"  en geniş düz şerit: {en_kotu[0]:.2f} pt ({en_kotu[1]})")
if kotu:
    print(f"\n✗ TIRTIKLI GEÇİŞ — {len(kotu)} sahnede şerit {TAVAN_PT} pt'yi aşıyor:")
    for ad, pt, x in kotu:
        print(f"   {ad:24} düz şerit {pt} pt (sütun x={x})")
    sys.exit(1)
print("  ✓ hiçbir sahnede göz kenar görecek genişlikte düz şerit yok")
