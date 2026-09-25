#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tasarim_vs_app.py — TASARIM ↔ UYGULAMA KARŞILAŞTIRMA SAYFASI

🔴 NEDEN AYRI BİR DOSYA (ve neden bugün oldu)
Bu karşılaştırma bugüne kadar her turda ELDEN üretiliyordu: bir Python
parçası yazılıyor, iki görsel yan yana konuyor, dosya gönderiliyor,
betik kayboluyordu. Sonuç: her tur kadraj, ölçek ve eşleşme LİSTESİ
biraz farklı çıkıyordu — yani Gökberk her turda BAŞKA bir karşılaştırma
görüyordu ve "geçen sefer düzelmiş miydi?" sorusunun cevabı yoktu.

🆕 SINIF: "KARŞILAŞTIRMA ARACI DA ÜRÜNÜN PARÇASIDIR — HER TURDA
YENİDEN YAZILAN BİR ÖLÇÜ ALETİ, İKİ TURUN SONUCUNU KIYASLANAMAZ YAPAR."

Eşleşmeler ELLE yazılı, çünkü iki ad uzayı arasında otomatik köprü yok;
ama listeye girmeyen her tasarım referansı RAPORLANIYOR (aşağıda), yani
liste sessizce eskimiyor.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(KOK, "tasarim_kaynak", "ref")
APP = os.path.join(KOK, "ekranlar_render")
FONT = os.path.join(KOK, "assets", "fonts", "PlusJakartaSans-SemiBold.ttf")
CIKTI = os.path.join(os.path.dirname(KOK), "teslim", "tasarim_vs_app.png")

# (tasarım referansı, uygulama önizlemesi, başlık)
CIFTLER = [
    ("00_kesfet.png",  "02_kesfet.png",      "Keşfet"),
    ("01_ana.png",     "11_ana_misafir.png", "Ana sayfa"),
    ("02_kural.png",   "03_kural.png",       "Kural kararı"),
    ("03_eslesme.png", "04_eslesme.png",     "Eşleşme anı"),
    ("04_sohbet.png",  "06_sohbet.png",      "Sohbet"),
]

BOY = 900          # her kare bu yüksekliğe ölçekleniyor
BOS = 16
ETI = 34
UST = 46


def main():
    eksik = []
    for a, b, _ in CIFTLER:
        if not os.path.exists(os.path.join(REF, a)):
            eksik.append("tasarim_kaynak/ref/" + a)
        if not os.path.exists(os.path.join(APP, b)):
            eksik.append("ekranlar_render/" + b)
    if eksik:
        print("✗ eksik kare:\n  " + "\n  ".join(eksik))
        print("  Önce `python ekran_uret.py` (ve gerekiyorsa tasarim_render.py).")
        return 1

    # Listeye girmemiş referanslar — sessizce eskimesin.
    kullanilan = {a for a, _, _ in CIFTLER}
    disarida = [f for f in sorted(os.listdir(REF))
                if f.endswith(".png") and f not in kullanilan]
    if disarida:
        print("  ⓘ %d tasarım referansı karşılaştırmada yok: %s"
              % (len(disarida), ", ".join(disarida)))

    kareler = []
    for a, b, ad in CIFTLER:
        for yol, etiket in ((os.path.join(REF, a), "tasarım"),
                            (os.path.join(APP, b), "uygulama")):
            im = Image.open(yol).convert("RGB")
            im = im.resize((int(im.width * BOY / im.height), BOY), Image.LANCZOS)
            kareler.append((im, "%s · %s" % (ad, etiket), etiket == "tasarım"))

    W = sum(i.width for i, _, _ in kareler) + BOS * (len(kareler) + 1)
    H = UST + BOY + ETI + BOS
    tuval = Image.new("RGB", (W, H), (12, 10, 14))
    d = ImageDraw.Draw(tuval)
    try:
        ft = ImageFont.truetype(FONT, 17)
        fb = ImageFont.truetype(FONT, 15)
    except Exception:
        ft = fb = ImageFont.load_default()

    surum = "?"
    try:
        import json
        surum = json.load(open(os.path.join(KOK, "app.json"),
                               encoding="utf-8"))["expo"]["version"]
    except Exception:
        pass
    d.text((BOS, 14),
           "LoungeLink v%s · her çiftte SOL: onaylanan tasarım (tarayıcıda çizildi) "
           "· SAĞ: uygulama önizlemesi (kaynaktan render)" % surum,
           font=ft, fill=(224, 190, 122))

    x = BOS
    for im, etiket, tasarim_mi in kareler:
        tuval.paste(im, (x, UST))
        # Tasarım kareleri altın, uygulama kareleri nötr etiketli:
        # hangisinin hangisi olduğu, kadraj benzeşince gözle ayrılmıyor.
        d.text((x, UST + BOY + 8), etiket, font=fb,
               fill=(224, 190, 122) if tasarim_mi else (190, 185, 180))
        x += im.width + BOS

    os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
    tuval.save(CIKTI)
    print("✓ %d çift → %s  %s" % (len(CIFTLER), CIKTI, tuval.size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
