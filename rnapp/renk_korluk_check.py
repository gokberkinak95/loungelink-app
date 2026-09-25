#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
renk_korluk_check.py — BİRİNCİL VE TEHLİKE DÜĞMESİ RENK KÖRÜ BİR GÖZDE
DE AYRI MI? — HER İKİ TEMADA.

🔴 NEDEN VAR
v3.1'de ölçtüm: canlıdaki birincil (#846A2A) ile tehlike (#B0243C)
düğmesi arasındaki fark, dötanop bir kullanıcı için ΔE = 8.0'dı.
ΔE < 15 pratikte "aynı renk" demektir. Yani "Uçuşunu yaz" ile "İlanı
sil" ayırt edilemiyordu. Bu estetik değil GÜVENLİK sorunu: geri
alınamaz eylem, ana eylemden ayrılamıyor.

Düzelttim (#A11450 → ΔE 28.3) — ama ölçümü BİR BETİĞE YAZMADIM.
Bugün koyu tema düğmelerini yeniden türetirken aynı soruyu yeniden
sormam gerekti ve elimde çalıştırılacak bir şey yoktu.

🆕 SINIF: "BİR ANALİZİ BETİĞE ÇEVİRMEDİYSEN, ONU YAPMADIN — SADECE
BİR KEZ BAKTIN. İKİNCİ KEZ SORULDUĞUNDA YENİDEN YAPMAK ZORUNDA
KALDIĞIN HER ÖLÇÜM, ASLINDA KAYBEDİLMİŞ BİR ÖLÇÜMDÜR."

YÖNTEM
  · Viénot-Brettel-Mollon (1999) LMS izdüşümü ile protanopi ve
    dötanopi benzetimi
  · CIELAB ΔE76 — eşik 25 (ΔE 15 "ayırt edilebilir"in sınırı;
    güvenlik amaçlı bir ayrım için iki katı marj isteniyor)
  · Açık VE koyu palet ayrı ayrı — koyu temada aynı ikilinin ΔE'si
    farklı çıkar, çünkü iki renk de değişti

TAVAN: eşiğin altında kalan çift sayısı 0.
"""
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import hex_rgb, palet                                # noqa: E402

TAVAN = 0

# ── İKİ EŞİK, ÇÜNKÜ İKİ AYRI İŞ ─────────────────────────────────────
# 🔴 TEK EŞİKLE BAŞLADIM (25) VE DENETİM HAKLI ÇIKTI AMA ÇÖZÜM YANLIŞ
# OLURDU. `greenInk ↔ redInk` koyu temada ΔE 5.7 çıktı — gerçek ve ciddi.
# Ama 25'e çıkarmanın tek yolu, hata metnini AÇIK PEMBEYE (#F0D1DB)
# çevirmekti. O renk hata gibi görünmüyor: renk körü olmayan herkes
# için alarm sinyalini zayıflatıyor, renk körü için de yalnız 6 ΔE
# kazandırıyordu.
#
# Ayrım: DÜĞMEDE renk hızlı ayırt edicidir (etiket kısa, karar anlıktır).
# METİNDE ise renk hiçbir zaman TEK kanal değildir — yanında zaten
# kelime var ("Onaylandı" / "Hata"), yani WCAG 1.4.1 metin tarafında
# kelimeyle sağlanıyor. Metin çiftlerinde eşik 15 + AÇIKLIK farkı şartı.
#
# 🆕 SINIF: "BİR EŞİĞİ HER YERE AYNI KOYARSAN, EN SIKI OLDUĞU YERDE
# ÜRÜNÜ BOZARSIN — EŞİK, RENGİN TEK KANAL OLUP OLMADIĞINA GÖRE
# DEĞİŞİR."
ESIK_DUGME = 25.0
ESIK_MUREKKEP = 15.0
# 🔴 BİR ADIM FAZLA GİTTİM VE DENETİM YALAN SÖYLEDİ.
# Eşiğin yanına "ayrıca ΔL* ≥ 12 olsun" diye ikinci bir şart koymuştum.
# Sonuç: `tealInk ↔ purpleInk` çifti dikromazi ΔE 79.6 ile — yani
# fazlasıyla ayırt edilebilirken — SADECE açıklıkları yakın diye
# ✗ aldı. Oysa dikromazi ΔE'si zaten Lab uzayında ölçülüyor; açıklık
# farkı ONUN İÇİNDE. İki kez saymışım.
#
# 🆕 SINIF: "BİR EŞİĞİN YANINA 'BİR DE ŞU OLSUN' DİYE EKLEDİĞİN ŞART,
# BAŞARISIZLIK BİÇİMİNDEN TÜRETİLMEDİYSE YALNIZ YANLIŞ ALARM ÜRETİR."
#
# ΔL* artık RAPORLANIYOR (renk körüne kalan ikinci ipucu olarak
# bilgilendirici), ama TAVANA GİRMİYOR.

CIFT = [
    ("goldBtn", "dangerBtn", "dugme", "ana eylem ↔ geri alınamaz eylem"),
    ("goldBtn", "tealBtn", "dugme", "birincil ↔ seyahat eylemi"),
    ("greenInk", "redInk", "murekkep", "başarı ↔ hata metni"),
    ("tealInk", "purpleInk", "murekkep", "Seyahatler ↔ Tanış — gezinme dili"),
]


def _dogrusal(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb_lms(h):
    r, g, b = [_dogrusal(x) for x in hex_rgb(h)]
    return (17.8824 * r + 43.5161 * g + 4.11935 * b,
            3.45565 * r + 27.1554 * g + 3.86714 * b,
            0.0299566 * r + 0.184309 * g + 1.46709 * b)


def lms_rgb(l, m, s):
    r = 0.080944 * l - 0.130504 * m + 0.116721 * s
    g = -0.0102485 * l + 0.0540194 * m - 0.113615 * s
    b = -0.000365294 * l - 0.00412163 * m + 0.693513 * s
    return [max(0.0, min(1.0, x)) for x in (r, g, b)]


def benzet(h, tur):
    """Viénot-Brettel-Mollon dikromazi izdüşümü."""
    l, m, s = rgb_lms(h)
    if tur == "protanopi":       # L konisi yok
        l = 2.02344 * m - 2.52581 * s
    else:                        # dötanopi — M konisi yok
        m = 0.494207 * l + 1.24827 * s
    return lms_rgb(l, m, s)


def lab(rgb_dogrusal):
    r, g, b = rgb_dogrusal
    x = 0.4124 * r + 0.3576 * g + 0.1805 * b
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = 0.0193 * r + 0.1192 * g + 0.9505 * b
    x, y, z = x / 0.95047, y / 1.0, z / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def dE(a, b):
    la, lb = lab(a), lab(b)
    return sum((x - y) ** 2 for x, y in zip(la, lb)) ** 0.5


def main():
    kotu = []
    print("=" * 78)
    print("RENK KÖRLÜĞÜ AYRIM DENETİMİ — ΔE76 · düğme ≥%.0f · mürekkep ≥%.0f"
          % (ESIK_DUGME, ESIK_MUREKKEP))
    print("=" * 78)
    for kapsam, ad in (("C", "AÇIK"), ("KOYU", "KOYU")):
        P = palet(kapsam)
        if kapsam == "KOYU":
            # Koyu palet eksik anahtarları açık paletten devralır —
            # üründe de öyle çalışıyor (temaUygula geri düşer).
            T = dict(palet("C"))
            T.update(P)
            P = T
        print("\n  ── %s TEMA ──" % ad)
        for a, b, tur, sebep in CIFT:
            if a not in P or b not in P:
                print("    ? %s / %s palette yok" % (a, b))
                continue
            en = min(dE(benzet(P[a], t), benzet(P[b], t))
                     for t in ("protanopi", "dotanopi"))
            ham_a = [_dogrusal(x) for x in hex_rgb(P[a])]
            ham_b = [_dogrusal(x) for x in hex_rgb(P[b])]
            tam = dE(ham_a, ham_b)
            dL = abs(lab(ham_a)[0] - lab(ham_b)[0])
            esik = ESIK_DUGME if tur == "dugme" else ESIK_MUREKKEP
            ok = en >= esik
            if not ok:
                kotu.append((ad, a, b, en))
            print("    %s %-9s ↔ %-10s ΔE %5.1f · dikromazi %5.1f (≥%.0f) · ΔL* %4.1f  %s"
                  % ("✓" if ok else "✗", a, b, tam, en, esik, dL, sebep))
    print()
    print("  eşiğin altında: %d  (tavan %d)" % (len(kotu), TAVAN))
    if len(kotu) > TAVAN:
        print("\n🔴 İki düğmenin AYRI RENKTE olması yetmez — renk körü bir gözde")
        print("   de ayrı kaldığını ölçmediysen, ayrı değiller.")
        return 1
    print("\n✓ Ayrım gereken her çift, iki dikromazi hâlinde de ayrı kalıyor.")
    print("  ⚠️ Bu denetim RENGİ ölçer, tek başına yeterli değildir: kritik")
    print("     eylemler ayrıca metin ve konumla da ayrışmalı (WCAG 1.4.1).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
