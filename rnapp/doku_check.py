#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
doku_check.py — İÇ EKRAN ZEMİNİNİN OKUNURLUĞA BEDELİ  (v3.4'te YENİDEN YAZILDI)

============================================================================
🔴 BU DOSYA NEDEN YENİDEN YAZILDI — KENDİ HATAM
v3.4'te zemin, çizilen 42 View'dan (`Ufuk` + `Bulut` + `IrtifaGrid`) tek bir
PNG'ye geçti. Bu nöbetçinin ESKİ hâli hâlâ `theme.js`'teki `C.doku`
değerlerini okuyup ONLARDAN bir zemin hesaplıyordu — yani artık var olmayan
bir sistemi ölçüyor, ve ✓ veriyordu.

Bu, bir nöbetçinin yapabileceği EN KÖTÜ şeydir: yanlış cevap vermek değil,
DOĞRU CEVABI ARTIK OLMAYAN BİR SORUYA vermek. Yeşil yanıyor, kimse bakmıyor,
ve ölçülmediğini kimse fark etmiyor.

🆕 SINIF: "BİR SİSTEMİ DEĞİŞTİRDİĞİNDE ONU ÖLÇEN NÖBETÇİYİ DE DEĞİŞTİRMEZSEN,
ELİNDE BİR KORUMA DEĞİL BİR YANILSAMA KALIR — VE YANILSAMA KORUMASIZLIKTAN
DAHA TEHLİKELİDİR, ÇÜNKÜ BAKMAYI BIRAKIRSIN."
============================================================================

NE ÖLÇÜYOR: `assets/zemin-*.png` dosyalarının GERÇEK piksellerini. Üretim
betiğinin (`zemin_uret.py`) hesabını değil — diskteki dosyayı. İkisi ayrı
şeydir: betik doğru hesaplayıp yanlış dosya yazmış olabilir, ya da dosya
elle değiştirilmiş olabilir.

Üç soru:
  1) Dosya var mı ve paletle uyumlu mu (üst pikseli sayfa zemini mi)?
  2) HER SATIRDA dört mürekkep AA'yı geçiyor mu? (en kötü nokta, ortalama değil)
  3) Ardışık satırlar arasında SIÇRAMA var mı? — "tırtıklı" kusurunun
     sayısal tanımı budur: komşu satırlar arasındaki fark 1 seviyeden
     büyükse göz onu KENAR olarak görür.
"""
import os
import sys

from PIL import Image

from tema_oku import hex_rgb, oran, palet   # 🔴 TEK OKUYUCU

KOK = os.path.dirname(os.path.abspath(__file__))
AA = 4.5
ROLLER = [("başlık", "ink"), ("gövde", "body"), ("ikincil", "mutedAA"), ("soluk", "dimAA")]

# Ardışık satır farkı bu değeri aşarsa göz kenar görür.
# 1 = dither'ın kendi ±1'i; 2 ve üstü gerçek bir basamaktır.
SICRAMA_TAVANI = 2


def olc(ad, kapsam, etiket):
    yol = os.path.join(KOK, "assets", ad)
    print("\n%s  ·  %s" % (etiket, ad))
    if not os.path.exists(yol):
        print("  ✗ DOSYA YOK. `python3 zemin_uret.py` çalıştırılmamış.")
        return 1

    p = palet(kapsam)
    im = Image.open(yol).convert("RGB")
    en, boy = im.size
    px = im.load()
    orta = en // 2
    satir = [px[orta, y] for y in range(boy)]

    # ── 1) PALETLE UYUM ────────────────────────────────────────────────
    # Üst piksel sayfa zemini olmalı; değilse gradyan paletin dışına
    # kaymış demektir (ya palet değişmiş ve betik koşulmamış, ya da
    # dosya elle üretilmiş).
    bekle = hex_rgb(p["bg"])
    ust = satir[0]
    sapma = max(abs(ust[i] - bekle[i]) for i in range(3))
    if sapma > 2:
        print("  ✗ Üst piksel %s, palet zemini %s — zemin PALETİN DIŞINDA."
              % ("#%02X%02X%02X" % ust, p["bg"]))
        print("     `python3 zemin_uret.py` ile yeniden üret.")
        return 1
    print("  ✓ Üst piksel palet zeminiyle aynı (%s)" % p["bg"])

    # ── 2) HER SATIRDA KONTRAST ────────────────────────────────────────
    hata = 0
    print("  %-10s %8s %8s" % ("rol", "en kötü", "satır"))
    for etiket_rol, anahtar in ROLLER:
        if not p.get(anahtar):
            continue
        m = hex_rgb(p[anahtar])
        enk, nerede = 99.0, 0
        for y, renk in enumerate(satir):
            o = oran(renk, m)
            if o < enk:
                enk, nerede = o, y
        im_ok = "✓" if enk >= AA else "✗"
        print("  %-10s %8.2f %8s  %s" % (etiket_rol, enk, "%d/%d" % (nerede, boy), im_ok))
        if enk < AA:
            hata = 1

    # ── 3) SIÇRAMA — "TIRTIKLI" KUSURUNUN SAYISAL TANIMI ───────────────
    # 🔴 ASIL ŞİKÂYET BUYDU. Eski zeminde 1 dp'lik çizgiler ve 14
    # basamaklı bir bant vardı; komşu satırlar arasında büyük sıçramalar
    # oluyordu. Bu ölçüm o kusurun geri gelmesini imkânsız kılıyor.
    en_buyuk, yeri = 0, 0
    for y in range(1, boy):
        d = max(abs(satir[y][i] - satir[y - 1][i]) for i in range(3))
        if d > en_buyuk:
            en_buyuk, yeri = d, y
    im_ok = "✓" if en_buyuk <= SICRAMA_TAVANI else "✗"
    print("  %-10s %8d %8s  %s  (tavan %d)"
          % ("sıçrama", en_buyuk, "%d/%d" % (yeri, boy), im_ok, SICRAMA_TAVANI))
    if en_buyuk > SICRAMA_TAVANI:
        print("     ✗ Komşu satırlar arasında %d seviyelik fark var — göz bunu"
              % en_buyuk)
        print("       KENAR olarak görür. 'Tırtıklı görünüm' tam olarak budur.")
        hata = 1
    return hata


def main():
    print("=" * 70)
    print("İÇ EKRAN ZEMİNİ — diskteki PNG ölçülüyor (hesap değil, dosya)")
    print("=" * 70)
    h = olc("zemin-acik.png", "C", "AÇIK TEMA")
    h += olc("zemin-koyu.png", "KOYU", "KOYU TEMA")

    # ══════════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — BU DÖRT DOSYA HİÇ ÖLÇÜLMEMİŞTİ.
    #
    # Ambiyans kuşaklarını eklerken fark ettim: koyu temada ekranda
    # gerçekten ÇİZİLEN doku `zemin-koyu.png` DEĞİL, `Atmosfer`in
    # `DOKU_KOYU` dediği `zemin-doku-koyu.png`. Bu nöbetçi ise ötekini
    # ölçüyordu. Yani yeşil yanan ölçüm, EKRANDA OLMAYAN bir dosyaya
    # aitti — doğrusu: v3.4'te dosya değişti, nöbetçi değişmedi.
    #
    # Bu, tam olarak bu dosyanın en tepesinde yazan hatanın kendisi.
    # Dersi yazmış, sonra aynı sınıftan bir hatayı bir kez daha
    # yapmışım. Yazıyorum ki üçüncüsü olmasın.
    #
    # 🆕 SINIF: "BİR DERSİ DOSYANIN BAŞINA YAZMAK ONU UYGULAMAK DEĞİLDİR
    # — DERS ANCAK BİR ÖLÇÜM SATIRINA DÖNÜŞTÜĞÜNDE KORUR."
    # ══════════════════════════════════════════════════════════════════
    for dosya, etiket in (("zemin-doku-safak.png",  "AMBİYANS · ŞAFAK"),
                          ("zemin-doku-gunduz.png", "AMBİYANS · GÜNDÜZ"),
                          ("zemin-doku-koyu.png",   "AMBİYANS · AKŞAM"),
                          ("zemin-doku-gece.png",   "AMBİYANS · GECE")):
        h += olc(dosya, "KOYU", etiket)

    # ── 4) ESKİ SİSTEM GERİ GELMİŞ Mİ ─────────────────────────────────
    # `atmosfer.js` yeniden çizim bileşenleri kazanırsa bu nöbetçi yine
    # olmayan bir şeyi ölçmeye başlar. Onu da burada yakalıyoruz.
    with open(os.path.join(KOK, "src", "atmosfer.js"), encoding="utf-8") as f:
        a = f.read()
    geri = [x for x in ("function Ufuk", "function IrtifaGrid", "function Bulut") if x in a]
    print("")
    if geri:
        print("  ✗ ESKİ ÇİZİM BİLEŞENLERİ GERİ GELMİŞ: %s" % ", ".join(geri))
        print("    Bu nöbetçi PNG'yi ölçüyor; çizilen doku ölçüm DIŞINDA kalır.")
        h += 1
    else:
        print("  ✓ Zemin tek bir görsel — çizilen doku bileşeni yok.")

    print("\n" + "=" * 70)
    if h:
        print("✗ %d zemin bulgusu." % h)
        return 1
    print("✓ Zemin: her satırda AA geçiliyor ve hiçbir yerde kenar yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
