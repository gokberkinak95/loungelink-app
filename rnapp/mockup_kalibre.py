#!/usr/bin/env python3
# ============================================================
# LoungeLink · mockup_kalibre.py
#
# AYNANIN KALİBRASYONU — `genislik()` ile `metin()` AYNI SAYIYI
# veriyor mu? Cevabını önceden bildiğim çizimlerle ölçülür.
#
# 🔴 NEDEN VAR — ÜÇ KEZ AYNI SINIF HATA:
#   1. tur: `genislik()` harf aralığını hiç saymıyordu.
#   2. tur: saydı ama `textlength(s) + aralik*(n-1)` ile; oysa çizim
#           karakter karakter ilerliyor (kerning kaybı). %33 fark.
#   3. tur: formül düzeldi ama BİRİM ayrıştı — `metin()` `aralik*K`
#           çarpıyordu, `genislik()` çarpmıyordu. 3 KAT fark.
#
# Üçünü de Gökberk ekranda gördü, ben denetimde göremedim. Çünkü
# denetimlerim ÜRÜNÜ ölçüyordu; ölçüm aletini kimse ölçmüyordu.
#
# 🆕 SINIF: "AYNI SINIF HATANIN ÜÇÜNCÜ TEKRARI ARTIK BİR HATA DEĞİL,
# EKSİK BİR KAPIDIR — VE KAPI, ÜRÜNE DEĞİL ALETE KONULMALIDIR."
#
# YÖNTEM: metni gerçekten ÇİZ, sonra mürekkebin sağ ucunu piksel
# olarak ölç ve `genislik()`in dediğiyle karşılaştır. Tahmin yok.
# ============================================================
import os, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mockup import Ekran, f, K, SEMI, BOLD, REG, MONO_SEMI, MONO_MED, SERIF_SEMI  # noqa

# (metin, font dosyası, punto, harf aralığı [NOKTA])
ORNEKLER = [
    ("LOUNGEPUAN", SEMI, 9.5, 1.3),
    ("KREDİ",      SEMI, 9.5, 1.3),
    ("GÜVEN",      SEMI, 9.5, 1.3),
    ("LOUNGELINK", BOLD, 10.5, 4.6),
    ("İYİ GÜNLER", BOLD, 10.5, 2.4),
    ("SOHBET",     SEMI, 9.0, 1.1),
    ("Deniz K.",   BOLD, 16, 0),
    ("200",        MONO_SEMI, 19, 0),
    ("02:41:08",   MONO_MED, 12, 0),
    ("D",          SERIF_SEMI, 20, 0),
]
# Mürekkep ölçümü yan boşlukları (side bearing) İÇERMEZ; ilerleme
# genişliği içerir. Bu yüzden ölçülen mürekkep her zaman biraz DAR
# çıkar. Eşik bunu karşılar; 3 katlık bir birim hatasını karşılamaz.
TOLERANS_ORAN = 0.14


def ink_genisligi(metin, font_ad, punto, aralik):
    """Metni boş bir tuvale çizer ve mürekkebin gerçek genişliğini
    piksel olarak döndürür."""
    e = Ekran()
    W, H = e.im.size
    e.im = Image.new("RGB", (W, H), (0, 0, 0))
    e._cizim = None
    ft = f(font_ad, punto)
    e.metin((40, 200), metin, ft, "#FFFFFF", aralik=aralik)
    a = np.asarray(e.im.convert("L")).astype(int)
    band = a[150:300, :]
    kolon = band.max(axis=0) > 40
    xs = np.where(kolon)[0]
    if not len(xs):
        return None
    return float(xs.max() - 40 + 1)   # sol pen konumundan sağ mürekkep ucuna


def main():
    print("── AYNA KALİBRASYONU (çizim ↔ ölçüm) ───────────────")
    e = Ekran()
    kirik = 0
    for metin, fad, punto, aralik in ORNEKLER:
        ft = f(fad, punto)
        olculen = e.genislik(metin, ft, aralik=aralik)
        cizilen = ink_genisligi(metin, fad, punto, aralik)
        if cizilen is None:
            print(f"  ✗ {metin!r}: hiç mürekkep çıkmadı")
            kirik += 1
            continue
        fark = abs(olculen := olculen) and abs(cizilen - olculen) / max(olculen, 1)
        ok = cizilen <= olculen * (1 + 0.02) and fark <= TOLERANS_ORAN
        if not ok:
            kirik += 1
        print(f"  {'✓' if ok else '✗'} {metin:<12} ölçüm {olculen:7.1f}px · "
              f"çizim {cizilen:7.1f}px · fark %{fark*100:4.1f}"
              + ("" if ok else "   ← ÇİZİM ÖLÇÜMÜ AŞIYOR"))
    print()
    if kirik:
        print(f"✗ {kirik} örnekte çizim ile ölçüm ayrışıyor.")
        print("  Bu hâlde taşma kapısı (`enfazla=`) YANILIR: sığmayan bir")
        print("  metni sığıyor sanar. Önizlemenin hiçbir ölçüsü okunamaz.")
        return 1
    print(f"✓ {len(ORNEKLER)} örneğin hepsinde çizim ölçümü aşmıyor "
          f"(tolerans %{TOLERANS_ORAN*100:.0f}).")
    print("  ⚠ Mürekkep ölçümü yan boşlukları saymaz — bu yüzden çizimin")
    print("    ölçümden BİRAZ DAR çıkması normaldir, geniş çıkması değil.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
