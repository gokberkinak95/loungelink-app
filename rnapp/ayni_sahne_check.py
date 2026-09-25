#!/usr/bin/env python3
"""
ayni_sahne_check.py

============================================================================
İKİZ SAHNE DENETİMİ — İKİ SAHNE BİREBİR AYNI GÖRÜNTÜYÜ KAYDETTİ Mİ?

🔴 NEDEN VAR — 19 EYLÜL

53 sahne çekiliyordu ve hepsi yeşil yanıyordu. md5'leri aldım:

    a3857667…  06b_sohbet_tanis.png
    a3857667…  13_baglantilar.png          ← BİREBİR AYNI
    e4f3ab1b…  18_ana_host1.png
    e4f3ab1b…  19_ana_guest1.png           ← BİREBİR AYNI

Yani galeri 53 sahne gösteriyor ama 51 ekran ölçüyordu. İki farklı
sebep, tek belirti:

  · `06b` — ikinci adımı (`dokun_a11y "Ece Y."`) 4 sn'de zaman aşımına
    uğruyordu; bağlantı satırında dokunulabilir olan isim değil
    "Sohbeti Aç" düğmesiydi. Adım düşünce sahne Tanış ekranında kaldı
    ve `13`ün görüntüsünü ikinci kez kaydetti.

  · `18/19` — SEED6'nın iki hesabı veritabanında YOKTU (`pg_run.py`
    yalnız numaralı migration'ları koşuyor). Oturum var, veri yok →
    uygulama ikisini de "Host Kurulumu" sihirbazına düşürdü.

İKİSİNİ DE BİR ŞEY YAKALAMADI, ÇÜNKÜ HER SAHNE KENDİ BAŞINA BAKILDIĞINDA
KUSURSUZDU. Kusur ancak sahneler BİRBİRİYLE kıyaslanınca görünüyor.

🆕 SINIF: "BİR ÖLÇÜM TAKIMINI TEK TEK DOĞRULAMAK YETMEZ — İKİ ÖLÇÜM
BİREBİR AYNI SONUCU VERİYORSA EN AZ BİRİ ÖLÇMÜYORDUR."

NE ÖLÇÜYOR
  `web_sahne/out/*.png` dosyalarının md5'leri. İki sahne aynı md5'i
  veriyorsa en az biri amaçladığı ekranı göstermiyordur.

NEYİ ÖLÇMÜYOR
  "Benzer" görüntüleri. Yalnız BİREBİR aynı olanı. Eşik gürültüsüz
  olsun diye kasıtlı: piksel farkı toleransı, ilk yanlış alarmda
  kapatılan bir kapı üretir.

TAVAN 0.
============================================================================
"""
import os
import sys
import hashlib
import collections

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(KOK, "web_sahne", "out")
TAVAN = 0


def main():
    if not os.path.isdir(OUT):
        print("✗ web_sahne/out yok — sahneler hiç çekilmemiş.")
        print("  ÇÖZÜM: python3 web_sahne/cek.py")
        sys.exit(1)

    pngler = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    if not pngler:
        print("✗ web_sahne/out içinde hiç .png yok — sahneler çekilmemiş.")
        sys.exit(1)

    ozet = collections.defaultdict(list)
    for f in pngler:
        h = hashlib.md5(open(os.path.join(OUT, f), "rb").read()).hexdigest()
        ozet[h].append(f)

    ikizler = {h: v for h, v in ozet.items() if len(v) > 1}

    print("=" * 74)
    print("İKİZ SAHNE — iki sahne birebir aynı görüntüyü mü kaydetti?")
    print("=" * 74)
    print("  sahne görüntüsü : %d" % len(pngler))
    print("  ayrık görüntü   : %d" % len(ozet))
    print("")

    if ikizler:
        toplam = sum(len(v) for v in ikizler.values())
        print("  ✗ %d sahne, %d ayrı ikiz kümesinde — bunların en az yarısı" %
              (toplam, len(ikizler)))
        print("    amaçladığı ekranı GÖSTERMİYOR:")
        for h, v in sorted(ikizler.items(), key=lambda kv: kv[1][0]):
            print("        %s  ←  %s" % (h[:8], " = ".join(v)))
        print("")
        print("  BAKILACAK İKİ ŞEY:")
        print("    1) O sahnelerin .json dosyasındaki `errors` alanı —")
        print("       düşen bir adım varsa sahne önceki ekranda kalmıştır.")
        print("    2) Sahne kişisinin verisi var mı — veri yoksa uygulama")
        print("       herkesi aynı boş/kurulum ekranına düşürür.")
    else:
        print("  ✓ her sahne kendi görüntüsünü kaydetmiş")

    print("")
    print("SONUC  ikiz=%d  tavan=%d" % (len(ikizler), TAVAN))
    sys.exit(1 if len(ikizler) > TAVAN else 0)


main()
