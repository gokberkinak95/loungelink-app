#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_bant_derece.py — `assets/bant.jpg` için MARKA RENK DERECELENDİRMESİ.

🔴 NEDEN VAR — 20 EYLÜL

`bant.jpg` uygulamanın TEK fotoğrafı ve üç yerde birden duruyor:
    · `FotoSahne`  (ui.js:1183)  → splash / karşılama
    · `FotoBant`   (ui.js:1495)  → İÇ EKRAN BAŞLIKLARI
    · `MomentScreen.js:153`
Yani "splash'in tonu" ile "header görseli" aynı dosya; biri düzelince
ikisi birden düzeliyor.

ÖLÇÜM (yerel):
    bant.jpg        C* ort 15.8 · p95 36.6 · baskın hue 41°
    marka altını    C* 20.1                · hue 86°

İki sayı önemli. Fotoğrafın en parlak %5'i **C* 36.6**'da — yani markanın
BİLEREK reddettiği kromada. `theme.js` altını 40.2'den 20.4'e indirirken
gerekçesini yazmış: "çiğ altın sarısı lüks algısını ucuzlatır."
Fotoğraf o kararın dışında kalmış. Hue de 45° sapmış (mercan ↔ şampanya).

── NEDEN TEK TİP HUE ÇEKİMİ DEĞİL ──────────────────────────────────────

İlk denemede bütün pikselleri şampanyaya çektim ve GÖKYÜZÜ de döndü.
Oysa alacakaranlık gökyüzünün serin olması DOĞRU — sorun mercan kabin.
Maske yalnız sıcak pikselleri (hue 330..75) hedefe çekiyor; serin
pikseller hue'sunu koruyor ama kroması kısılıyor, yani geri çekiliyor.

🆕 SINIF: "BİR FOTOĞRAFI MARKAYA UYDURURKEN TÜM PİKSELLERİ AYNI YÖNE
ÇEKME — FOTOĞRAFIN DOĞRU OLAN KISMINI DA BOZARSIN."

── DOKUNULMAYAN DOSYA: bant_hale.png ───────────────────────────────────

Bu dosyayı "hue 306° · mor" diye raporlamıştım ve YANLIŞTI. O ölçümü
alfa kanalını yok sayarak yaptım; tamamen saydam piksellerin RGB'si çöp
veridir ve medyanı zehirledi. Alfa maskesiyle (alpha>0.10) doğru değer:
**hue 83° · C* p95 28.0** — yani zaten marka altınında. Dosya sağlam,
derecelendirilmiyor.

🆕 SINIF: "ALFALI BİR GÖRSELDE RENK ÖLÇERKEN MASKEYİ UNUTMA — SAYDAM
PİKSELİN RENGİ YOKTUR, AMA BİR SAYISI VARDIR VE O SAYI ORTALAMAYI BOZAR."

Kullanım:
    python brand/build_bant_derece.py            # önizleme + ölçüm, YAZMAZ
    python brand/build_bant_derece.py --uygula   # assets/'e yazar, eskisini arşivler
"""
import os
import shutil
import sys
from datetime import date

import numpy as np
from PIL import Image
from skimage import color

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KAYNAK = os.path.join(KOK, "assets", "bant.jpg")
ARSIV = os.path.join(KOK, "assets", "arsiv_gorsel")

# Hedefler — `theme.js` KOYU paletinden
MARKA_HUE = 86.0          # #D6C3A0'ın hue'su
SICAK_MRK, SICAK_YARI = 22.5, 52.5   # 330..75 · sıcak maske merkezi/yarıçapı
SICAK_CEK = 0.78          # sıcak pikselleri hedefe çekme oranı
SOGUK_KROMA = 0.45        # serin pikselleri geri çekme (hue KORUNUR)
SICAK_P95 = 24.0          # sıcak pikselin %95 kroması — marka 20.1'in hemen üstü


def olc(rgb):
    lab = color.rgb2lab(rgb)
    C = np.hypot(lab[:, :, 1], lab[:, :, 2])
    H = (np.degrees(np.arctan2(lab[:, :, 2], lab[:, :, 1])) + 360) % 360
    return lab, C, H


def ozet(C, H, maske=None):
    c = C if maske is None else C[maske]
    h = H if maske is None else H[maske]
    hs = np.median(h[c > 12]) if (c > 12).any() else float("nan")
    return c.mean(), float(np.percentile(c, 95)), hs


def derecelendir(rgb):
    lab, C, H = olc(rgb)
    d = np.abs(((H - SICAK_MRK + 180) % 360) - 180)
    sicak = np.clip(1 - (d - SICAK_YARI) / 25.0, 0, 1)      # yumuşak kenarlı maske
    fark = ((MARKA_HUE - H + 180) % 360) - 180
    H2 = (H + fark * SICAK_CEK * sicak) % 360
    sec = sicak > 0.5
    k = SICAK_P95 / np.percentile(C[sec], 95) if sec.any() else 1.0
    C2 = C * (sicak * k + (1 - sicak) * SOGUK_KROMA)
    r = np.radians(H2)
    lab2 = lab.copy()
    lab2[:, :, 1] = C2 * np.cos(r)
    lab2[:, :, 2] = C2 * np.sin(r)
    return np.clip(color.lab2rgb(lab2), 0, 1)


def main():
    uygula = "--uygula" in sys.argv
    if not os.path.exists(KAYNAK):
        print("🔴 %s yok." % KAYNAK)
        return 1

    rgb = np.asarray(Image.open(KAYNAK).convert("RGB"), float) / 255
    _l, C0, H0 = olc(rgb)
    out = derecelendir(rgb)
    _l2, C1, H1 = olc(out)

    print("=" * 74)
    print("BANT DERECELENDİRME — splash + iç ekran başlıkları (aynı dosya)")
    print("=" * 74)
    print("  ÖNCE   C* ort %5.1f · p95 %5.1f · hue %3.0f°" % ozet(C0, H0))
    print("  SONRA  C* ort %5.1f · p95 %5.1f · hue %3.0f°" % ozet(C1, H1))
    print("  HEDEF  marka altını · C* 20.1 · hue 86°")
    print("")

    im = Image.fromarray((out * 255).astype(np.uint8))
    if not uygula:
        yol = "/tmp/bant_derece_onizleme.jpg"
        im.save(yol, quality=92, optimize=True)
        print("  · ÖNİZLEME yazıldı: %s" % yol)
        print("  · `--uygula` verilmedi — assets/ DEĞİŞMEDİ.")
        return 0

    os.makedirs(ARSIV, exist_ok=True)
    hedef_arsiv = os.path.join(ARSIV, "bant_%s.jpg" % date.today().isoformat())
    if not os.path.exists(hedef_arsiv):
        shutil.copy2(KAYNAK, hedef_arsiv)
        print("  ✓ eski dosya ARŞİVLENDİ: assets/arsiv_gorsel/%s"
              % os.path.basename(hedef_arsiv))
    else:
        print("  · arşivde zaten var: %s" % os.path.basename(hedef_arsiv))
    im.save(KAYNAK, quality=93, optimize=True)
    print("  ✓ assets/bant.jpg derecelendirildi")
    print("")
    print("  ⚠️ `bant_hale.png` DOKUNULMADI — alfa maskesiyle ölçümü hue 83°,")
    print("     yani zaten marka altınında. (Önceki '306° mor' raporum")
    print("     saydam pikselleri sayan HATALI bir ölçümdü.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
