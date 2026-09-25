#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
koyu_doldur.py — türetilen KOYU tokenlerini `theme.js`e YAZAR.

`tema_koyu_turet.py` ölçer ve önerir; bu betik yazar. İkisi ayrı, çünkü
ölçüm tekrarlanabilir olmalı: değerleri elle kopyalasaydım, yarın bir
eşiği değiştirdiğimde palet ölçümden sessizce ayrılırdı.

🆕 SINIF: "ÖLÇÜMÜN SONUCUNU ELLE KOPYALARSAN, ÖLÇÜM İLE KOD ARASINDA
YENİ BİR SAPMA KAYNAĞI AÇMIŞSIN DEMEKTİR."

Blok `// <<< KOYU-TURETILDI` ve `// KOYU-TURETILDI >>>` arasına yazılır;
tekrar çalıştırıldığında o blok DEĞİŞTİRİLİR, yenisi eklenmez.
"""
import datetime
import os
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_koyu_turet import (BG, YUZ, YUZ2, K, MUREKKEP, NOTR, SINYAL,  # noqa: E402
                             TONLU, oran, uret)

YOL = os.path.join(KOK, "src", "theme.js")
BAS = "// <<< KOYU-TURETILDI — koyu_doldur.py yazar, ELLE DÜZENLEME"
SON = "// KOYU-TURETILDI >>>"

# Rolü olmayan / iki temada AYNI kalan tokenler — ve NEDEN aynı kaldıkları.
# Gerekçesiz "aynı kalsın" yok: her satır bir karar.
AYNI = {
    "foto": "fotoğrafın üstündeki mürekkep — zemin fotoğraf, tema değil",
    "btnUstIsik": "düğmenin 1px üst ışığı — iki temada da beyaz %34",
    "badgeToneFor": "fonksiyon, renk değil",
    "line": "KOYU.line ayrı tanımlı",
}


def blok():
    Y = uret()
    s = [BAS,
         "// %d token · her biri ölçülerek türetildi (bkz. tema_koyu_turet.py)"
         % len(Y),
         "// sayfa %s · kart %s · blok %s" % (BG, YUZ, YUZ2), ""]

    s.append("// ── TONLU ZEMİN — sayfadan ayrışan koyu bloklar ──")
    for ad in sorted(TONLU):
        s.append('KOYU.%-11s = "%s";   // sayfa %.2f:1 · kart %.2f:1'
                 % (ad, Y[ad], oran(Y[ad], BG), oran(Y[ad], YUZ)))
    s.append("")
    s.append("// ── NÖTR ZEMİN — sıcak gri bloklar (ton taşımaz) ──")
    for ad in sorted(NOTR):
        s.append('KOYU.%-11s = "%s";   // sayfa %.2f:1'
                 % (ad, Y[ad], oran(Y[ad], BG)))
    s.append("")
    s.append("// ── DOĞRUDAN EŞLEME ──")
    for ad, kay in (("card", "surface"), ("bgAlt", "surfaceAlt"),
                    ("muted", "mutedAA"), ("dim", "dimAA"),
                    ("mut", "mutedAA"), ("paper", "bg"), ("goldSoft", "goldBg"),
                    ("hataBg", "redBg")):
        s.append("KOYU.%-11s = KOYU.%s;" % (ad, kay))
    s.append("")
    s.append("// ── MÜREKKEP — kendi tonlu zemininde ölçüldü ──")
    for ad, zem in sorted(MUREKKEP.items()):
        z = Y[zem] if zem else YUZ
        s.append('KOYU.%-11s = "%s";   // %s %.2f:1 · kart %.2f:1'
                 % (ad, Y[ad], zem or "kart", oran(Y[ad], z), oran(Y[ad], YUZ)))
    s.append('KOYU.%-11s = "%s";   // gece %.2f:1 · kart %.2f:1'
             % ("purpleUst", Y["purpleUst"], oran(Y["purpleUst"], Y["gece"]),
                oran(Y["purpleUst"], YUZ)))
    s.append("")
    s.append("// 🔴 KOYU TEMADA HATA MÜREKKEBİ TÜRETİMDEN GELDİĞİ GİBİ KALAMADI.")
    s.append("// Türetim yalnız KONTRASTA bakar; `renk_korluk_check.py` ikinci bir")
    s.append("// soru sordu: dötanop bir gözde `greenInk` ile `redInk` ayrı mı?")
    s.append("// Ölçüm: ΔE 5.7 — yani hata metni ile başarı metni AYNI RENK.")
    s.append("// Aynı ton ailesinde, daha AÇIK bir değer ΔE'yi 23.4'e çıkarıyor.")
    s.append("// (Açık temada aynı çift 21.0 ile zaten geçiyordu.)")
    s.append("//")
    s.append("// 🔴 BU DEĞERİ İKİ KEZ SEÇTİM. İlki (#FFADC6) ESKİ yüzey")
    s.append("// merdivenine göre çözülmüştü; merdiven sıcak tona taşınıp")
    s.append("// yükseltilince ΔE 18.9'dan 15.7'ye düştü — eşiğin 0.7 üstünde,")
    s.append("// yani tesadüfen geçiyordu. Bir zemin değişince ONUN ÜSTÜNDEKİ")
    s.append("// her kararın yeniden çözülmesi gerekiyor; 'zaten geçmişti'")
    s.append("// diye bırakılan her değer bir sonraki değişimde sessizce düşer.")
    s.append("//")
    s.append("// 🆕 SINIF: \"BİR EŞİĞİ KIL PAYI GEÇEN DEĞER, GEÇMİŞ DEĞİL")
    s.append("// ERTELENMİŞTİR — MARJI OLMAYAN ÖLÇÜM BİR SONRAKİ DEĞİŞİKLİKTE")
    s.append("// KIRMIZIYA DÖNER.\"")
    s.append("// Doygunluk %100'de tutuldu: hata rengi soluklaşırsa alarm")
    s.append("// sinyalini kaybeder — kazanılan erişilebilirlik, kaybedilen")
    s.append("// aciliyetten büyük olmalı.")
    s.append('KOYU.redInk      = "#FFD1E2";   // dikromazi ΔE 23.4 · en kötü zemin 6.94:1')
    s.append("")
    s.append("// ── SİNYAL — metin ve kenarlık; bağlayıcı eşik metin ──")
    for ad in SINYAL:
        en = min(oran(Y[ad], z) for z in (YUZ, YUZ2, BG, Y["gece"]))
        s.append('KOYU.%-11s = "%s";   // en kötü zemin %.2f:1' % (ad, Y[ad], en))
    s.append("")
    s.append("// ── GECE YÜZEYİ — çevresinden KOYU olan kasıtlı ada ──")
    s.append('KOYU.%-11s = "%s";   // sayfa %.2f:1 (çukur)'
             % ("gece", Y["gece"], oran(Y["gece"], BG)))
    s.append("")
    s.append("// ── KENARLIK · DÜĞME · MARKA ──")
    for ad in ("goldLine", "warmGray2"):
        s.append('KOYU.%-11s = "%s";   // kart %.2f:1' % (ad, Y[ad], oran(Y[ad], YUZ)))
    # amberBtn · dangerBtn · dangerBtn2 · goldBtn2 artık KOYU literalinde:
    # beyaz mürekkepli düğme ailesi tek yerde durmalı ki gradyanın iki ucu
    # birbirinden ayrı dosyada yaşamasın.
    s.append('KOYU.%-11s = "%s";   // Apple HIG: koyu zeminde BEYAZ düğme'
             % ("brandApple", Y["brandApple"]))
    s.append('KOYU.%-11s = "%s";' % ("brandAppleInk", Y["brandAppleInk"]))
    s.append('KOYU.%-11s = "%s";   // Google\'ın kendi koyu tema mavisi'
             % ("brandGoogle", Y["brandGoogle"]))
    s.append("")
    s.append("// ── YARI SAYDAM ÇİZGİLER — koyu zeminde %16 opaklık kaybolur.")
    s.append("// Ölçtüm: rgba(184,148,58,0.16) koyu sayfada 1.06:1 — yok gibi.")
    s.append("// Koyu temada aynı ton, daha yüksek opaklıkla yazılıyor.")
    s.append('KOYU.warmLine   = "rgba(216,179,106,0.22)";')
    s.append('KOYU.hataLine   = "rgba(255,173,198,0.34)";')
    s.append("// Koyu temada modal perdesi daha DERİN olmalı: %55 siyah, koyu bir")
    s.append("// sayfanın üstünde yalnız 1.4:1 fark yaratıyor — modal 'öne çıkmıyor'.")
    s.append('KOYU.perde      = "rgba(0,0,0,0.72)";')
    s.append('KOYU.tealLine   = "rgba(79,197,182,0.42)";')
    s.append('KOYU.purpleLine = "rgba(169,125,243,0.42)";')
    s.append("")
    s.append("// ── ROZET TİNTİ — `info` açık temada rgba(26,31,46,0.05):")
    s.append("// koyu sayfada tamamen görünmez. Koyu temada mürekkep tarafına")
    s.append("// dönüyor; diğer dördü zaten renkli, opaklıkları artırıldı.")
    s.append("KOYU.badge = {")
    for ad, rgb in (("ok", "111,217,168"), ("cost", "232,200,122"),
                    ("unknown", "182,188,200"), ("block", "247,155,175"),
                    ("info", "244,239,232")):
        s.append('  %-8s { fg: KOYU.badgeInk.%s, bg: "rgba(%s,0.13)", bd: "rgba(%s,0.30)" },'
                 % (ad + ":", ad, rgb, rgb))
    s.append("};")
    s.append("")
    s.append("// ── GÖLGE — koyu temada gölge SİYAH ve daha derin olmalı;")
    s.append("// #1A1F2E gibi mavi-gri bir gölge koyu zeminde MOR bir hale bırakır.")
    s.append('KOYU.golgeRenk = "#000000";')
    s.append("KOYU.golgeCarp = 2.4;   // opaklık çarpanı")
    s.append("")
    s.append("// İKİ TEMADA AYNI KALANLAR — ve neden:")
    for ad, sebep in sorted(AYNI.items()):
        s.append("//   %-13s %s" % (ad, sebep))
    s.append(SON)
    return "\n".join(s)


def main():
    g = open(YOL, encoding="utf-8").read()
    yeni = blok()
    if BAS in g:
        a = g.index(BAS)
        b = g.index(SON, a) + len(SON)
        g = g[:a] + yeni + g[b:]
    else:
        g = g.rstrip() + "\n\n" + yeni + "\n"
    ye = os.path.join(KOK, "_yedek_koyu",
                      datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(ye, exist_ok=True)
    shutil.copy2(YOL, os.path.join(ye, "theme.js"))
    open(YOL, "w", encoding="utf-8").write(g)
    print("✓ theme.js güncellendi · %d satır KOYU bloğu" % yeni.count("\n"))
    print("  yedek: %s" % ye)
    return 0


if __name__ == "__main__":
    sys.exit(main())
