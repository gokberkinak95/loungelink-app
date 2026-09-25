#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
glif_check.py — "BU İŞARET CİHAZDA ÇİZİLEBİLİYOR MU?"

🔴 NASIL BULUNDU
İç sayfaya uyarı ikonu olarak "◆" ve bilgi ikonu olarak "ⓘ" yazdım.
Basınca ikisi de BOŞ KARE çıktı. Ölçtüm: Archivo ailesinde bu iki
karakter yok. Yani "ikon koydum" derken hiçbir şey koymamışım.

Sonra asıl soruyu sordum: uygulamanın KENDİSİ kaç tane böyle karakter
kullanıyor? Tarayınca 24 tanesi çıktı — ✓ ✕ ★ ⚠ ✈ ⏳ ◈ ▾ dahil.

⚠️ DÜRÜSTLÜK NOTU — BU BİR RİSK LİSTESİDİR, HATA LİSTESİ DEĞİL.
İki ayrı durum var ve karıştırmak yanlış alarm üretir:

  · EMOJİ (U+1F300 ve üstü, bazı U+26xx/U+27xx):
    Cihazın SİSTEM EMOJİ FONTUNDAN çizilir, bizim paketlediğimiz
    fontlardan değil. Bunlar sorun DEĞİL ve burada sayılmaz.

  · EMOJİ OLMAYAN SEMBOL (✓ ✕ ★ ⌚ gibi):
    Metin fontundan çizilir. `fontFamily` verilmişse ve o fontta glif
    yoksa iOS genelde sistem fontuna düşer; Android'de bu düşüş her
    zaman olmaz ve TOFU KUTUSU çıkar. Yani "kesin bozuk" değil,
    "cihaza göre değişir" — ve tasarımda cihaza göre değişen şey
    kabul edilemez.

🆕 SINIF: "BİR KARAKTERİ EKRANDA GÖRÜYOR OLMAK, KULLANICININ DA
GÖRECEĞİ ANLAMINA GELMEZ — GLİF FONTTA VAR MI, ÖLÇÜLÜR."

TAVAN: mevcut sayı dondurulur. Yeni bir riskli sembol eklemek denetimi
kırmızıya boyar; var olanları temizlemek tavanı düşürür.
"""
import glob
import os
import re
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    print("fontTools kurulu değil — glif denetimi atlandı (pip install fonttools)")
    sys.exit(0)

KOK = os.path.dirname(os.path.abspath(__file__))
# 🔴 TAVAN 22 → 0. Sembolleri kullanım yerlerinde düzeltmek yerine
# EKSİĞİN KENDİSİNİ giderdik: 22 glif `brand/build_simgeler.py` ile
# çizilip paketlediğimiz altı fonta eklendi. 160 çağrı yerinin hiçbiri
# değişmedi. Bu tavan artık 0 ve 0 kalmalı — yeni bir sembol eklenirse
# ya fonta çizilecek ya da kullanılmayacak.
TAVAN = 0


def emoji_mi(o):
    """Sistem emoji fontundan çizilenler. Kapsam kasten GENİŞ: yanlış
    alarm vermektense birkaç sembolü gözden kaçırmayı tercih ederim —
    çünkü bu denetim her koşuda çalışacak."""
    return (0x1F000 <= o <= 0x1FAFF or 0x1F004 == o
            or 0x2600 <= o <= 0x27BF and o in EMOJI_PRESENTASYON)


# U+2600–27BF aralığında VARSAYILAN OLARAK emoji çizilenler (Unicode
# Emoji_Presentation=Yes). Diğerleri metin glifi olarak çizilir.
EMOJI_PRESENTASYON = {
    0x2614, 0x2615, 0x2648, 0x2649, 0x264A, 0x264B, 0x264C, 0x264D, 0x264E,
    0x264F, 0x2650, 0x2651, 0x2652, 0x2653, 0x267F, 0x2693, 0x26A1, 0x26AA,
    0x26AB, 0x26BD, 0x26BE, 0x26C4, 0x26C5, 0x26CE, 0x26D4, 0x26EA, 0x26F2,
    0x26F3, 0x26F5, 0x26FA, 0x26FD, 0x2705, 0x270A, 0x270B, 0x2728, 0x274C,
    0x274E, 0x2753, 0x2754, 0x2755, 0x2757, 0x2795, 0x2796, 0x2797, 0x27B0,
    0x27BF,
}


def fontlar():
    kapsam = {}
    for p in sorted(glob.glob(os.path.join(KOK, "assets", "fonts", "*.[to]tf"))):
        try:
            t = TTFont(p)
        except Exception:
            continue
        c = set()
        for tb in t["cmap"].tables:
            c |= set(tb.cmap.keys())
        kapsam[os.path.basename(p)] = c
    return kapsam


def kaynak_semboller():
    """Dize sabitlerinde geçen, ASCII dışı, noktalama olmayan karakterler."""
    # Türkçe harfler ve tipografik noktalama hariç.
    # U+FE0F "variation selector-16" GÖRÜNMEZ bir işaretçidir: kendinden
    # önceki karakterin emoji biçiminde çizilmesini söyler, kendi bir glif
    # değildir. Onu "riskli glif" saymak, olmayan bir kusuru bildirmekti.
    HARIC = set("İıŞşĞğÜüÖöÇç…–—‘’“”·•₺\ufe0f")
    bulundu = {}
    for p in glob.glob(os.path.join(KOK, "src", "*.js")) + [os.path.join(KOK, "App.js")]:
        g = open(p, encoding="utf-8").read()
        # 🔴 BU TARAYICI YALNIZ DİZE LİTERALLERİNE BAKIYORDU VE KÖR NOKTASI
        # BUGÜN ORTAYA ÇIKTI: sohbetin gönder düğmesi `<Text>➤</Text>` idi —
        # yani bir JSX METİN DÜĞÜMÜ, dize değil. `➤` (U+27A4) paketlenen
        # altı fontun HİÇBİRİNDE yok; Android'de tofu kutusu çıkabilirdi.
        # Denetim aylarca "riskli glif 0" dedi çünkü BAKMADIĞI bir yerdeydi.
        #
        # Ancak bir kod değiştirici o metni `label="➤"` biçimine çevirince
        # görünür oldu. Yani kusuru bulan şey denetim değil, tesadüftü.
        #
        # 🆕 SINIF: "BİR DENETİMİN 'SIFIR' DEMESİ, BAKTIĞI YERDE SIFIR
        # DEMEKTİR — NEREYE BAKMADIĞINI YAZMIYORSAN, SIFIR BİR İDDİA
        # DEĞİL BİR YANILSAMADIR."
        #
        # Artık JSX metin düğümleri de taranıyor: `>metin<` arası.
        for m in re.finditer(r'"([^"\\\n]*)"|\'([^\'\\\n]*)\'|`([^`\\\n]*)`'
                             r'|>([^<>{}\n]{1,120})<', g):
            # 🔴 REGEX'E DÖRDÜNCÜ GRUBU EKLEDİM AMA BURAYA EKLEMEDİM.
            # Mutasyon testi bunu anında yakaladı: JSX metin düğümüne
            # riskli bir glif koydum, denetim yine "0" dedi. Yani
            # tarayıcı artık DOĞRU YERE bakıyordu ama okuduğunu
            # KULLANMIYORDU — kör noktayı kapatırken yeni bir kör nokta
            # açmışım.
            #
            # 🆕 SINIF: "BİR TARAYICIYA YENİ BİR YAKALAMA GRUBU EKLERKEN,
            # ONU OKUYAN SATIRI DA GÜNCELLE — YOKSA KAPSAMI GENİŞLETMİŞ
            # GİBİ YAPIP AYNI KALIRSIN."
            s = m.group(1) or m.group(2) or m.group(3) or m.group(4) or ""
            for ch in s:
                o = ord(ch)
                if o > 0x2000 and ch not in HARIC:
                    bulundu.setdefault(ch, set()).add(os.path.basename(p))
    return bulundu


def main():
    kap = fontlar()
    if not kap:
        print("font bulunamadı — denetim atlandı")
        return 0
    hepsi = set().union(*kap.values())
    riskli, emoji_sayisi = [], 0
    for ch, yerler in sorted(kaynak_semboller().items()):
        o = ord(ch)
        if emoji_mi(o):
            emoji_sayisi += 1
            continue
        if o not in hepsi:
            riskli.append((ch, o, sorted(yerler)))

    print("=" * 72)
    print("GLİF DENETİMİ — paketlenen fontlarda olmayan metin sembolleri")
    print("=" * 72)
    print("  font        : %d  (%s)" % (len(kap), ", ".join(sorted(kap))[:60]))
    print("  emoji       : %d — sistem emoji fontundan çizilir, sayılmaz" % emoji_sayisi)
    print("  riskli glif : %d  (tavan %d)" % (len(riskli), TAVAN))
    if riskli:
        print()
        for ch, o, yerler in riskli:
            print("  · U+%04X  %s   %s" % (o, ch, ", ".join(yerler)[:56]))
    print()
    if len(riskli) > TAVAN:
        print("🔴 TAVAN AŞILDI — yeni bir riskli sembol eklendi.")
        print("   Android'de özel fontla glif düşüşü garanti değildir: tofu kutusu")
        print("   çıkabilir. Karakter yerine ŞEKİL çiz (daire + ASCII harf) ya da")
        print("   glifi olan bir ikon fontu paketle.")
        return 1
    if len(riskli) < TAVAN:
        print("✓ Riskli glif sayısı düştü (%d < %d) — TAVAN'ı %d yap."
              % (len(riskli), TAVAN, len(riskli)))
        return 0
    print("✓ Riskli glif sayısı tavanda — yeni risk eklenmedi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
