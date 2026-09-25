#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
jeton_bant_check.py

============================================================================
JETONUN KENDİSİ PALETİN İÇİNDE Mİ?

🔴 NEDEN VAR — 20 EYLÜL

`tema_sizinti_check.py` şunu soruyor: "bu renk `theme.js`ten mi geliyor?"
Bütün uygulama yeşil yanıyordu — 0 sızıntı, tavan 0.

Sonra sahneleri ÇEKİP ÖLÇTÜM ve şunu buldum:

    06b_sohbet_tanis.png   155.992 piksel  #B6A7C5  hue 310°  (LAVANTA)
    20_ayarlar.png          12.557 piksel  #2D4962  hue 262°  (LACİVERT)

Yani ekranın en büyük renk bloğu, terk ettiğimiz menekşe/lacivert
dünyadandı. Sızıntı kapısı bunu göremezdi, çünkü **sızıntı yoktu**:
iki renk de `theme.js`te düzgünce jetonlaşmıştı. `KOYU.purple`
(#B7A8C6) ve `KOYU.gokMavi` (#2E4A63).

Kapı doğru soruyu soruyordu ama YARIM soruyordu:
  · "renk jetondan mı geliyor?"  → EVET
  · "jetonun KENDİSİ palette mi?" → HİÇ SORULMUYORDU

🆕 SINIF: "BİR RENGİN JETONLAŞMIŞ OLMASI ONU SİSTEME SOKMAZ — JETON
DOSYASI BİR PALET DEĞİL BİR LİSTEDİR; LİSTEYE YANLIŞ RENGİ YAZARSAN
SIZINTI DENETİMİ SENİ ONAYLAR."

── KURAL (Obsidyen Protokol v6.0.0) ────────────────────────────────────

Her KOYU jetonu şu üçünden BİRİ olmalı:

  1. NÖTR        C* ≤ 8      (obsidyen, fildişi, gri kademeleri)
  2. SICAK BANT  hue 45-120° ve C* ≤ 28   (şampanya ailesi · marka 86°)
  3. SİNYAL      aşağıdaki listede AÇIKÇA yazılı ve C* ≤ 45.2

SİNYAL listesi kısa ve gerekçeli olmak ZORUNDA. Bir rengi "sinyal" diye
listeye eklemek, onu sistemin dışına çıkarma izni vermektir; izin
yazılıysa karar olur, yazılı değilse kaçış olur.

⚠️ NEDEN SİNYALLERİN DE KROMA TAVANI VAR: sinyal renkleri sistemin
dışında DURUR ama sistemin üstüne ÇIKMAZ. Tavan olmazsa "sinyal"
etiketi, doygun her rengi içeri sokan bir kapı olur.

⚠️ VE TAVAN NEDEN TAM 45: BU SAYIYI BEN SEÇMEDİM. İlk yazımda 22
yazmıştım — kendi uydurduğum bir sayı — ve kapı, sistemin KENDİ
kararlarıyla kavga etti: `amberInk` 3 Eylül'de ölçülerek 65.9'dan
45.1'e indirilmişti, yani 45 bu projenin bir sinyale verdiği en yüksek
kroma. Tavanı oraya koymak, var olan bir kararı yasa yapmaktır;
22'ye koymak ise o kararı hiç okumadan üstüne yazmak olurdu.

🆕 SINIF: "BİR TAVANI KENDİ SEZGİNDEN SEÇME — PROJENİN ZATEN VERDİĞİ
EN UÇ KARARI BUL VE TAVANI ORAYA KOY; YOKSA KAPI SİSTEMİ DEĞİL SENİ
SAVUNUR." (Tavanı MEVCUT DURUMA göre ayarlamakla karıştırma: o,
"şu an ne varsa doğrudur" demektir. Burada ölçülen ve gerekçesi
yazılmış TEK bir kararı temel alıyoruz.)

TAVAN 0.
============================================================================
"""
import os
import re
import sys

import numpy as np
from skimage import color

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
import tema_oku                                            # noqa: E402
TAVAN = 0

NOTR_C = 8.0
BANT_ALT, BANT_UST = 45.0, 120.0
BANT_C = 28.0
# ⚠️ 45.2, 45.0 DEĞİL. Tavanı `amberInk`in ÖLÇÜLEN değerinden (C* 45.1)
# aldık; 45.0 yazınca kapı, tavanı doğuran kararın KENDİSİNİ ihlal saydı
# ve dört jeton "45.1 > 45" diye kırmızı yandı. Bir tavanı bir ölçümden
# türetiyorsan, o ölçümü İÇERMEK zorundasın.
SINYAL_C = 45.2

# ── SİNYAL JETONLARI — gerekçesi yazılı olmayan sinyal yoktur ─────────
# Bunlar bandın DIŞINDA durmasına izin verilen, sayılı jetonlardır.
# Her biri bir DURUM bildirir; marka rengi değildir ve marka rengiyle
# karıştırılmamaları TAM OLARAK bandın dışında olmalarının sebebidir.
SINYAL = {
    # ── GÜVEN / DOĞRULANMIŞ ────────────────────────────────────────────
    "teal":      "güven / doğrulanmış — 'iyi durum' bildirir; altınla karışmamalı",
    "tealInk":   "teal metni",
    "tealBg":    "teal yüzeyi",
    "tealTint":  "teal en hafif yüzey",
    "tealTint2": "teal en hafif yüzeyin ikinci kademesi",
    "tealLine":  "teal kenar",
    "tealBtn":   "teal düğme zemini — beyaz metinle 4.63:1 ölçüldü",
    # ── BAŞARI ────────────────────────────────────────────────────────
    # ⚠️ `green` KOYU'da fildişine çevrildi (1460); geriye yüzey/düğme
    # kaldı. İkisi de 'tamamlandı' bildirir ve teal'den ayrı durur.
    "green":     "başarı — 'tamamlandı'",
    "greenInk":  "başarı metni",
    "greenBg":   "başarı yüzeyi",
    "greenBtn":  "başarı düğme zemini — beyaz metinle 4.63:1 ölçüldü",
    "greenLine": "başarı kenarı",
    # ── UYARI ─────────────────────────────────────────────────────────
    "amber":     "uyarı — 'dikkat' bildirir; sarı-turuncu evrensel uyarı rengi",
    "amberInk":  "amber metni",
    "amberBg":   "amber yüzeyi",
    "amberBtn":  "amber düğme zemini",
    "amberLine": "amber kenar",
    # ── TEHLİKE / HATA ────────────────────────────────────────────────
    "red":         "tehlike / iptal — 'geri alınamaz' bildirir",
    "redInk":      "hata metni",
    "redBg":       "kırmızı yüzeyi",
    "redLine":     "kırmızı kenar",
    "redBtn":      "yıkıcı eylem düğmesi",
    "danger":      "tehlike eşanlamlısı",
    "dangerBtn":   "yıkıcı eylem düğmesi",
    "dangerBtn2":  "yıkıcı eylem düğmesinin gradyan alt ucu",
    "hataBg":      "hata yüzeyi",
    "hataLine":    "hata kenarı",
}

# ── MARKA ZORUNLULUĞU — kroma tavanı YOK, çünkü rengi biz seçmiyoruz ──
# Üçüncü tarafın marka kılavuzu bu değerleri ŞART KOŞUYOR. Değiştirmek
# mağaza reddi ya da marka ihlali demek. Bunları "sinyal" saymak yanlış
# olurdu: sinyal bizim kararımızdır, bu değil.
ZORUNLU = {
    "brandApple":    "Apple Sign In siyah düğme zemini — Apple HIG şart koşuyor",
    "brandAppleInk": "Apple/Google beyaz düğme metni",
    "brandGoogle":   "Google marka mavisi — Google marka kılavuzu şart koşuyor",
}

# ══════════════════════════════════════════════════════════════════════
# 🔴 20 EYLÜL — BU KAPI ÖNCE KENDİ AYRIŞTIRICISINI YAZMIŞTI.
#
# `theme.js`i kendi regex'imle okudum ve `tema_kaynak_check.py` kırmızı
# yandı: "theme.js'i kendi regex'iyle okuyor". Kural doğru — bu dosyada
# iki palet yan yana ve ayrı ayrıştırmak beş kez yanlış cevap üretmiş.
#
# AMA TAŞIRKEN İKİSİNİ KARŞILAŞTIRDIM VE FARKLI CEVAP VERDİLER:
#     tema_oku.palet("KOYU")["purpleBg"]  →  #281D40 (MENEKŞE)
#     benim ayrıştırıcım                   →  goldBg  (ALTIN)
# Haklı olan benimkiydi. `tema_oku` takma adları YALNIZ jeton daha önce
# görülmemişse uyguluyordu; `KOYU.purpleBg = KOYU.goldBg;` (3 Eylül,
# satır 1589) kendisinden ÖNCE gelen bir hex tarafından yeniliyordu.
# Beş jeton 17 gündür yanlış okunuyordu ve TÜM kapılar o değeri
# ölçüyordu. `tema_oku.py` düzeltildi (sıralı çözüm, son atama kazanır).
#
# 🆕 SINIF: "TEK KAYNAĞA TAŞIMADAN ÖNCE İKİ OKUYUCUYU KARŞILAŞTIR —
# FARK VARSA HANGİSİNİN DOĞRU OLDUĞUNU ÖLÇ; TAŞIMA, SESSİZCE YANLIŞ
# OLANIN ÜSTÜNE YERLEŞMENİN EN KOLAY YOLUDUR."
#
# ⚠️ Alfa: `tema_oku.palet()` rgba jetonlarını paletin KENDİ `bg`sine
# düzleştirerek döndürüyor — yani "ekranda görünen renk" ölçülüyor,
# ham rgba değil. Bu turda `bant_hale.png`de alfayı saymayıp "306°
# magenta" dediğim hatanın kapatıldığı yer.
# ══════════════════════════════════════════════════════════════════════


def olc(hx):
    h = hx.lstrip("#")
    rgb = np.array([[[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]]])
    l = color.rgb2lab(rgb)[0, 0]
    C = float(np.hypot(l[1], l[2]))
    H = float((np.degrees(np.arctan2(l[2], l[1])) + 360) % 360)
    return float(l[0]), C, H


def main():
    print("=" * 74)
    print("JETON BANDI — theme.js'teki rengin KENDİSİ palette mi?")
    print("=" * 74)
    print("  nötr C* ≤ %.0f · sıcak bant %.0f-%.0f° C* ≤ %.0f · sinyal C* ≤ %.0f"
          % (NOTR_C, BANT_ALT, BANT_UST, BANT_C, SINYAL_C))
    print("")

    jeton = tema_oku.palet("KOYU")
    satirlar = tema_oku.tema_satirlari("KOYU")
    bulgular = []
    sinyal_sayisi = 0
    zorunlu_sayisi = 0

    for ad in sorted(jeton):
        hx = jeton[ad]
        satir = satirlar.get(ad, 0)
        L, C, H = olc(hx)
        if C <= NOTR_C:
            continue                                  # nötr — her zaman serbest
        if ad in ZORUNLU:
            zorunlu_sayisi += 1
            continue
        if ad in SINYAL:
            sinyal_sayisi += 1
            if C > SINYAL_C:
                bulgular.append((ad, satir, hx, L, C, H,
                                 "sinyal ama C* %.1f > %.0f" % (C, SINYAL_C)))
            continue
        if BANT_ALT <= H <= BANT_UST:
            if C > BANT_C:
                bulgular.append((ad, satir, hx, L, C, H,
                                 "bandın içinde ama C* %.1f > %.0f" % (C, BANT_C)))
            continue
        bulgular.append((ad, satir, hx, L, C, H,
                         "hue %.0f° bandın DIŞINDA ve sinyal listesinde yok" % H))

    print("  ölçülen jeton  : %d" % len(jeton))
    print("  sinyal (izinli): %d" % sinyal_sayisi)
    print("  marka zorunlu  : %d  (kroma tavanı yok — rengi biz seçmiyoruz)" % zorunlu_sayisi)
    print("")

    if bulgular:
        print("  ✗ %d jeton sistemin dışında:" % len(bulgular))
        for ad, satir, hx, L, C, H, ne in bulgular:
            print("      theme.js:%-5d %-14s %s  L*%5.1f C*%5.1f hue %3.0f°"
                  % (satir, ad, hx, L, C, H))
            print("          %s" % ne)
        print("")
        print("  ÇÖZÜM — İKİSİNDEN BİRİ, ÜÇÜNCÜSÜ YOK:")
        print("    a) rengi L* KORUYARAK 86°'ye çevir (aydınlık ilişkisi bozulmaz,")
        print("       okunurluk aynı kalır — yalnız hue döner), ya da")
        print("    b) SİNYAL sözlüğüne GEREKÇESİYLE ekle.")
        print("    Gerekçesiz eklemek kapıyı susturur, sistemi genişletmez.")
    else:
        print("  ✓ her jeton ya nötr, ya sıcak bantta, ya da gerekçeli sinyal")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    return 1 if len(bulgular) > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
