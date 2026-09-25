#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gorsel_palet_check.py

============================================================================
GÖRSEL PALET DENETİMİ — FOTOĞRAFLAR DA PALETİN PARÇASIDIR

🔴 NEDEN VAR — 20 EYLÜL

`theme.js` 1700 satır boyunca her rengi ölçüp gerekçelendiriyor. Ama
uygulamanın GÖRSELLERİ o denetimin tamamen dışındaydı. Ölçtüm:

    assets/bant.jpg   C* p95 36.6 · hue 41°
    marka altını      C*     20.1 · hue 86°

Fotoğrafın en parlak %5'i, markanın BİLEREK reddettiği kromada
(theme.js: "çiğ altın sarısı lüks algısını ucuzlatır", C* 40.2 → 20.4).
Ve bu dosya üç yerde birden duruyor: splash, iç ekran başlıkları,
MomentScreen. Yani sapma kullanıcının gördüğü İLK karede başlıyor ve
uygulamanın içinde devam ediyor.

🆕 SINIF: "BİR PALETİ JETONLARLA KORUYORSAN, O PALETİN İÇİNDEKİ
FOTOĞRAFLAR PALETİN DIŞINDA KALIR — VE KULLANICI ÖNCE ONLARI GÖRÜR."

── İKİNCİ HATA SINIFI: ALFA KÖRLÜĞÜ ────────────────────────────────────

İlk ölçümümde `bant_hale.png`i "hue 306° · mor" diye raporladım ve
YANLIŞTI. Alfa kanalını yok sayıp bütün pikselleri saydım; tamamen
saydam pikselin RGB'si çöp veridir ve medyanı zehirledi. Maskeli doğru
değer hue 83° — dosya zaten uyumluydu. Az kalsın DOĞRU bir varlığı
"düzeltiyordum".

🆕 SINIF: "SAYDAM PİKSELİN RENGİ YOKTUR AMA BİR SAYISI VARDIR — MASKESİZ
ÖLÇÜM O SAYIYI GERÇEK SANIR."

Bu kapı alfa maskesini ZORUNLU kullanır.

NE ÖLÇÜYOR
  `src/` içinde `require("../assets/…")` ile çağrılan her görselin
  alfa-maskeli kroma ve hue değerini.

NEYİ ÖLÇMÜYOR
  · Nötr varlıkları (p95 C* ≤ 8) — onların hue'su yoktur.
  · AÇIK TEMAYA ait varlıkları — gerekçeleri MUAF listesinde yazılı.

TAVAN 0
============================================================================
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from skimage import color

KOK = os.path.dirname(os.path.abspath(__file__))
TAVAN = 0

MARKA_HUE = 86.0          # #D6C3A0
KROMA_TAVAN = 28.0        # marka 20.1 + fotoğraf payı
HUE_TAVAN = 30.0          # derece
NOTR_ESIK = 8.0           # bunun altında hue anlamsız
ALFA_ESIK = 0.10          # maskesiz ölçüm YASAK — bkz. başlık

# ⚠️ MUAF — her satırın gerekçesi var, "şimdilik" yok.
MUAF = {
    # ⚠️ GEREKÇE DÜZELTİLDİ (20 Eylül). Önce "açık tema ayrı bir dünya"
    # demiştim. Yanlış: `src/tema_tercih.js` → `SECENEKLER = ["koyu"]`.
    # Üründe AÇIK TEMA YOK; "gece sistemi bir seçenek değil, ürünün
    # kimliği". Yani bu üç varlık ULAŞILAMAZ — ürüne hiç sızamazlar.
    # Muafiyet duruyor ama sebebi "başka bir dünya" değil, "ölü kod".
    "altin_acik.png": "açık tema gradyanı — şampanya kararı KOYU bloğa ait",
    "mark-gold.png":  "açık tema markası — koyu temada mark-light.png kullanılır",
    "zemin-acik.png": "açık tema zemini",
}


def varliklar():
    """src/ içinde require edilen assets/ yolları."""
    bul = set()
    for d, kl, do in os.walk(os.path.join(KOK, "src")):
        kl[:] = [k for k in kl if k not in {"__pycache__"}]
        for f in do:
            if not f.endswith(".js"):
                continue
            g = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
            for m in re.finditer(r'require\(\s*"\.\./assets/([^"]+)"\s*\)', g):
                # Yalnız görseller — `assets/fonts/*.ttf` de bu desene uyuyor
                # ve PIL onu açamayıp kapıyı çökertiyordu. Bir denetim,
                # ölçemediği bir şeye rastladığında çökmemeli; ATLAMALI.
                if os.path.splitext(m.group(1))[1].lower() in (
                        ".png", ".jpg", ".jpeg", ".webp"):
                    bul.add(m.group(1))
    return sorted(bul)


def olc(yol):
    im = Image.open(yol)
    a = np.asarray(im.convert("RGBA"), float) / 255.0
    alfa = a[:, :, 3]
    maske = alfa > ALFA_ESIK
    if maske.sum() < 50:
        return None
    lab = color.rgb2lab(a[:, :, :3])
    C = np.hypot(lab[:, :, 1], lab[:, :, 2])[maske]
    H = ((np.degrees(np.arctan2(lab[:, :, 2], lab[:, :, 1])) + 360) % 360)[maske]
    p95 = float(np.percentile(C, 95))
    hs = float(np.median(H[C > 12])) if (C > 12).any() else None
    return C.mean(), p95, hs


def main():
    vs = varliklar()
    if not vs:
        print("✗ src/ içinde hiç assets/ require'ı bulunamadı — ayrıştırıcı körleşmiş.")
        sys.exit(1)

    bulgular, olculen, muaf_n, notr_n = [], 0, 0, 0
    satirlar = []
    for v in vs:
        yol = os.path.join(KOK, "assets", v)
        if not os.path.exists(yol):
            bulgular.append((v, "dosya YOK", "", ""))
            continue
        if os.path.basename(v) in MUAF:
            muaf_n += 1
            continue
        m = olc(yol)
        if m is None:
            continue
        ort, p95, hs = m
        olculen += 1
        if p95 <= NOTR_ESIK:
            notr_n += 1
            satirlar.append((v, ort, p95, None, "nötr"))
            continue
        sapma = abs(((hs - MARKA_HUE + 180) % 360) - 180) if hs is not None else 0.0
        kusur = []
        if p95 > KROMA_TAVAN:
            kusur.append("kroma %.1f > %.1f" % (p95, KROMA_TAVAN))
        if hs is not None and sapma > HUE_TAVAN:
            kusur.append("hue %.0f° · markadan %.0f° sapma" % (hs, sapma))
        satirlar.append((v, ort, p95, hs, "✗ " + " · ".join(kusur) if kusur else "uyumlu"))
        if kusur:
            bulgular.append((v, " · ".join(kusur), "%.1f" % p95, "%.0f°" % (hs or 0)))

    print("=" * 74)
    print("GÖRSEL PALETİ — alfa maskeli kroma/hue (marka: C* 20.1 · hue 86°)")
    print("=" * 74)
    print("  ölçülen varlık : %d   (nötr %d · muaf %d)" % (olculen, notr_n, muaf_n))
    print("")
    for v, ort, p95, hs, durum in satirlar:
        print("    %-22s C* ort %5.1f · p95 %5.1f · hue %-5s  %s"
              % (v, ort, p95, ("%.0f°" % hs) if hs else "—", durum))
    print("")
    if bulgular:
        print("  ✗ %d varlık paletin dışında:" % len(bulgular))
        for v, ne, _p, _h in bulgular:
            print("      %s — %s" % (v, ne))
        print("")
        print("  ÇÖZÜM: `python brand/build_bant_derece.py --uygula` gibi bir")
        print("  derecelendirme yaz — fotoğrafı DEĞİŞTİRME, tonunu markaya çek.")
    else:
        print("  ✓ her görsel markanın kroma ve hue sınırları içinde")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    sys.exit(1 if len(bulgular) > TAVAN else 0)


main()
