#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tema_koyu_turet.py — 39 EKSİK KOYU TOKENİ *ÖLÇEREK* TÜRETİR.

🔴 NEDEN VAR
Koyu tema anahtarını kurmadan önce ölçtüm: `C` paletinde 55 renk var,
`KOYU`da 19. Kodda kullanılan ama koyu karşılığı OLMAYAN 39 token,
toplam 1270 çağrı yeri. Anahtarı bugün koysaydım, koyu sayfada AÇIK
TEMA renkleriyle çizilen 1270 nokta olurdu — beyaz kart, açık tint,
koyu mürekkep. Yani anahtar çalışırdı, tema çalışmazdı.

🆕 SINIF: "BİR ANAHTARI, ANAHTARLADIĞI ŞEY TAM DEĞİLKEN KOYMAK,
ÖZELLİK DEĞİL ARIZA EKLEMEKTİR."

NASIL TÜRETİR — uydurmuyor, ÇÖZÜYOR:
Her token için ROLÜ koddan ölçüldü (backgroundColor mi, color mı,
borderColor mı). Sonra rolüne göre bir HEDEF ORAN konuldu ve o oranı
tutturan açıklık ikili aramayla BULUNDU. Ton (hue) ve doygunluk
açık temadan korunuyor — çünkü `teal` koyu temada da teal olmalı,
yoksa aynı ürün olmaz.

  · zemin (*Bg / *Tint / card / bgAlt / warmBlock)
        → koyu, tonlu; yüzeyden ayırt edilir (≥1.12:1) ve üstündeki
          açık mürekkep 4.5:1'i geçer
  · mürekkep (*Ink / muted / dim)
        → açık; KENDİ tonlu zemininde ≥4.5:1, kartta da ≥4.5:1
  · sinyal (gold / teal / green / purple / amber …)
        → hem metin (≥4.5:1 kartta) hem kenarlık (≥3:1) olarak kullanılıyor;
          metin eşiği bağlayıcı olan
  · kenarlık (goldLine / coolLine / warmGray)
        → yalnız çizgi: 3:1 yeter, fazlası gürültü
"""
import colorsys
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import hex_rgb, oran, palet, parlaklik            # noqa: E402

C = palet("C")
K = palet("KOYU")
BG, YUZ, YUZ2 = K["bg"], K["surface"], K["surfaceAlt"]


def hsl(h):
    r, g, b = [x / 255 for x in hex_rgb(h)]
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return hh, ss, ll


def hexle(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), s)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def coz(kaynak, zemin, hedef, s_carp=1.0, s_tavan=None, yon="acik"):
    """
    Kaynağın TONUNU koruyarak, `zemin` üzerinde `hedef` oranı tutturan
    açıklığı ikili aramayla bulur.

    yon="acik"  → mürekkep/sinyal: zeminden AÇIK tarafa
    yon="koyu"  → zemin: sayfadan bir tık AÇIK ama hâlâ koyu
    """
    h, s, _ = hsl(kaynak)
    s = min(s * s_carp, 1.0)
    if s_tavan is not None:
        s = min(s, s_tavan)
    if yon == "derin":
        # zeminden KOYU tarafa: açıklık düştükçe oran artar (ters yön)
        alt, ust = 0.0, hsl(zemin)[2]
        for _ in range(60):
            orta = (alt + ust) / 2
            if oran(hexle(h, s, orta), zemin) < hedef:
                ust = orta
            else:
                alt = orta
        return hexle(h, s, alt)
    alt = hsl(zemin)[2] if yon == "koyu" else 0.0
    ust = 1.0
    for _ in range(60):
        orta = (alt + ust) / 2
        o = oran(hexle(h, s, orta), zemin)
        if o < hedef:
            alt = orta
        else:
            ust = orta
    return hexle(h, s, ust)


def rapor(ad, deger, olcumler):
    par = " · ".join("%s %.2f:1" % (k, v) for k, v in olcumler)
    bayrak = "✓"
    for k, v in olcumler:
        if k.startswith("!") and v < 4.5:
            bayrak = "🔴"
    print("  %-14s %s   %s %s" % (ad, deger, par, bayrak))


# ═══════════════════════════════════════════════════════════════════
# TÜRETİM TABLOSU
# ═══════════════════════════════════════════════════════════════════
# ── TONLU ZEMİN — sayfadan 1.45:1 ayrılan koyu bloklar.
# Bu, gözün "ayrı bir kutu" diyebildiği en küçük fark. Daha fazlası
# koyu temada kutuyu yüzdürür, daha azı kaybeder.
#
# Doygunluk 3 katına çıkıyor, %38'de tavanlanıyor: açık temanın tinti
# neredeyse beyaz (doygunluk düşük ama açıklık çok yüksek); aynı
# doygunluğu koyuda kullanınca ton TAMAMEN kayboluyor — ölçtüm,
# #1B1A18 ile #1A1B18 farkı yok. Tavan da gerekli: üstü "renkli kutu"
# olur, "tonlu zemin" değil.
# 🔴 HEDEFLER SAYFAYA DEĞİL, MERDİVENE GÖRE. Bu bloklar kartın İÇİNDE
# duruyor; sayfadan 1.45 ayrılan bir tint, sayfadan 1.32 ayrılan bir
# kartın üstünde neredeyse görünmez. Yeni merdiven:
#     sayfa 1.00 → kart 1.32 → blok/tint 1.62 → gece 1.95
# 🔴 30 AĞUSTOS — HEDEFLER GECE SİSTEMİNİN MERDİVENİNE GÖRE DÜŞÜRÜLDÜ.
#
# Eski merdiven: sayfa 1.00 → kart 1.32 → tint 1.62
# Gece merdiveni: sayfa 1.00 → kart 1.10 → blok 1.19
#
# Yani 1.62 hedefi yeni kartın 1.47 KATI parlaklıkta bir blok üretiyordu.
# Önizlemede sonucu görüldü: uyarı kutusu hardal, hata kutusu tuğla —
# koyu bir arayüzün ortasında orta tonlu renkli dikdörtgenler.
#
# Gece sisteminde tonlu zemin BİR İPUCUDUR, bir blok değil: rengi KENAR
# ÇİZGİSİ ve METİN taşır, zemin yalnız aidiyeti gösterir.
#
# 🆕 SINIF: **"TÜRETİLMİŞ BİR DEĞERİN HEDEFİ, TÜRETİLDİĞİ MERDİVENE
# BAĞLIDIR — MERDİVENİ DEĞİŞTİRİP HEDEFİ BIRAKIRSAN, FORMÜL DOĞRU
# ÇALIŞARAK YANLIŞ SONUÇ ÜRETİR."**
TONLU = {
    "goldBg": 1.26, "goldTint": 1.18, "amberBg": 1.26, "greenBg": 1.26,
    "tealBg": 1.26, "tealTint": 1.18, "tealTint2": 1.22, "redBg": 1.26,
    "purpleBg": 1.26,
}
Z_SAT, Z_TAVAN = 3.0, 0.38

# ── NÖTR ZEMİN — açık temada bunlar sıcak GRİ (ton var ama anlamı yok).
# 🔴 İLK TÜRETİMDE HATA YAPTIM: doygunluğu 3 katına çıkaran kuralı
# bunlara da uyguladım ve `warmBlock` #352E18 çıktı — hardal sarısı bir
# kutu. Açık temada gözle görülemeyen bir ton, koyuda üç katına
# çıkarılınca RENK oluyor.
#
# 🆕 SINIF: "BİR DÖNÜŞÜM KURALINI BÜTÜN TOKENLERE UYGULAMADAN ÖNCE,
# HANGİLERİNİN 'TONLU' HANGİLERİNİN 'NÖTR' OLDUĞUNU AYIR — AYNI
# İŞLEMİN İKİSİNDE AYRI SONUCU VAR."
#
# Nötrler yüzey ailesinin kendi tonunu (koyu tema kabin sıcaklığı)
# kullanıyor, kendi tonlarını değil.
NOTR = {"warmBlock": 1.14, "warmBlock2": 1.22, "warmBlock3": 1.30}

# ── MÜREKKEP — her biri KENDİ tonlu zemininde + kart + blok + sayfada
# ayrı ölçülüyor; bağlayıcı olan en kötüsü.
MUREKKEP = {
    "goldInk": "goldBg", "amberInk": "amberBg", "greenInk": "greenBg",
    "tealInk": "tealBg", "purpleInk": "purpleBg", "redInk": "redBg",
    "inkSoft": None, "warmGray": None, "coolLine": None,
}
# ── SİNYAL — hem metin hem kenarlık. Bağlayıcı eşik metin.
SINYAL = ["gold", "amber", "green", "teal", "purple", "goldDeep"]


def uret():
    Y = {}
    # ── GECE YÜZEYİ (yeni token) — ÖNCE HESAPLANIR ─────────────────
    # 🔴 KODDA 7 YERDE `backgroundColor: C.ink` VAR: ödül kartı, radar
    # kartı, toast, Moment ekranı, splash zemini. Bunlar "mürekkep"
    # değil, KASITLI KOYU YÜZEYLER — açık temanın içinde bir gece adası.
    # Koyu temada `C.ink` açık bir renge dönüyor; anahtar konulsaydı bu
    # 7 yüzey bembeyaz olur, üstlerindeki beyaz metin kaybolurdu.
    #
    # 🆕 SINIF: "BİR TOKENİN İKİ İŞTE KULLANILMASI, TEMA DEĞİŞTİĞİNDE
    # İKİSİNDEN BİRİNİN BOZULACAĞI ANLAMINA GELİR — ROL AYRIŞMADIYSA
    # TOKEN AYRIŞMAMIŞTIR."
    #
    # 🔴 İKİ KEZ YANLIŞ YÖNE GİTTİM, İKİSİ DE ÖĞRETİCİ:
    #   1· Önce geceyi sayfadan AÇIK yaptım (#41343B) — altı sinyal rengi
    #      birden AA'nın altına düştü, çünkü gece artık en açık zemindi
    #      ve ben sinyalleri onu HESABA KATMADAN çözmüştüm.
    #   2· Sonra "ilişkiyi koru, çevresinden koyu olsun" deyip aşağı
    #      çevirdim; sonuç SAF SİYAH ve sayfayla arasında 1.14:1 çıktı.
    #      Sebep ölçülebilir: sayfa zemini #181316 zaten L=0.0070 —
    #      siyahın bile sayfayla oranı en fazla 1.14. Yani "daha koyu"
    #      diye bir yer YOK.
    #
    # 🆕 SINIF: "BİR YÖNDE HAREKET ETMEYE KARAR VERMEDEN ÖNCE O YÖNDE
    # NE KADAR YER OLDUĞUNU ÖLÇ — KOYU TEMADA 'DAHA KOYU' BİTMİŞ BİR
    # KAYNAKTIR."
    #
    # Doğrusu: koyu temada yükseklik AÇIKLIKLA anlatılır (kabul görmüş
    # koyu tema modeli). Gece, en yüksek kademedeki SICAK yüzey oluyor —
    # ve en açık zemin olduğu için bütün mürekkep/sinyaller ONUN üstünde
    # de ölçülüyor.
    Y["gece"] = coz(C["ink"], BG, 1.95, s_carp=1.0, s_tavan=0.20, yon="koyu")

    for ad, hedef in TONLU.items():
        Y[ad] = coz(C[ad], BG, hedef, s_carp=Z_SAT, s_tavan=Z_TAVAN, yon="koyu")
    for ad, hedef in NOTR.items():
        Y[ad] = coz(YUZ, BG, hedef, s_carp=1.0, yon="koyu")

    # ── DOĞRUDAN EŞLEME — türetmeye gerek yok, karşılığı zaten var.
    # Açık temada da `muted` ile `mutedAA` aynı değer; koyuda da öyle
    # olmalı ki iki ad iki renk anlamına gelmesin.
    Y["card"] = YUZ
    Y["bgAlt"] = YUZ2
    Y["muted"] = K["mutedAA"]
    Y["dim"] = K["dimAA"]

    for ad, zem in MUREKKEP.items():
        zeminler = ([Y[zem]] if zem else []) + [Y["gece"], YUZ, YUZ2, BG]
        kaynak = K["red"] if ad == "redInk" else C[ad]   # kırmızı ailesi KOYU.red tonunda kalsın
        Y[ad] = max((coz(kaynak, z, 4.9) for z in zeminler), key=parlaklik)
    for ad in SINYAL:
        Y[ad] = max((coz(C[ad], z, 4.9) for z in (Y["gece"], YUZ, YUZ2, BG)),
                    key=parlaklik)

    # ── KENARLIK — 3:1 yeter (WCAG 1.4.11 anlamlı grafik); fazlası gürültü
    Y["goldLine"] = coz(C["goldLine"], YUZ, 3.0, s_carp=1.6, s_tavan=0.45)
    Y["warmGray2"] = coz(YUZ, YUZ, 3.0, s_carp=1.0)

    # ── DÜĞME ZEMİNLERİ BURADA TÜRETİLMİYOR ─────────────────────────
    # Beyaz mürekkepli düğme ailesi (goldBtn · goldBtn2 · tealBtn ·
    # amberBtn · dangerBtn · dangerBtn2) `theme.js`teki KOYU literalinde
    # tek blok hâlinde duruyor. Burada da türetseydim gradyanın iki ucu
    # iki ayrı dosyada yaşardı — ve bu betiğin ilk sürümünde tam olarak
    # o oldu: `goldBtnInk` beyaza dönünce "beyaz üstünde 6:1" araması
    # `amberBtn`i BEYAZ diye çözdü. Anlamsız bir sonuç, sessizce.
    #
    # 🆕 SINIF: "BİR AİLENİN BAZI ÜYELERİNİ TÜRETİP BAZILARINI ELLE
    # YAZARSAN, ELLE YAZILANI DEĞİŞTİRDİĞİN GÜN TÜRETİLEN SESSİZCE
    # SAÇMALAR."

    # ── MARKA — Apple koyu zeminde BEYAZ düğme ister (HIG "Sign in with
    # Apple" siyah/beyaz/çerçeveli üçlüsü). Google mavisi marka rengi,
    # değiştirilemez; Google'ın KENDİ koyu tema tonu #8AB4F8 kullanılıyor.
    Y["brandApple"] = "#FFFFFF"
    Y["brandAppleInk"] = "#000000"
    Y["brandGoogle"] = "#8AB4F8"
    # purpleUst gece yüzeyinde duruyor — orada ölçülüyor
    # purpleUst, purple'ın BİR ÜST kademesi — açık temada da öyle.
    # 4.9 hedefiyle ikisi aynı değere düşüyordu (#A97DF3); iki kademe
    # tek kademeye iniyordu. Hedef 6.2'ye çıkarıldı ki ilişki dursun.
    Y["purpleUst"] = max((coz(C["purpleUst"], z, 6.2)
                          for z in (Y["gece"], YUZ, YUZ2, BG)), key=parlaklik)
    return Y


if __name__ == "__main__":
    print("=" * 78)
    print("KOYU TEMA TÜRETİMİ — her token ölçülerek")
    print("=" * 78)
    Y = uret()
    kotu = 0
    print("\n── ZEMİN (sayfadan / karttan ayrışma) ───────────────────")
    for ad in sorted(TONLU) + sorted(NOTR) + ["card", "bgAlt", "gece"]:
        print("  %-12s %s  sayfa %.2f:1 · kart %.2f:1" %
              (ad, Y[ad], oran(Y[ad], BG), oran(Y[ad], YUZ)))
    print("\n── MÜREKKEP (kendi zemini + kart + blok + sayfa) ────────")
    # `muted`/`dim` kart ölçeğinin tokenleri; gece yüzeyinde KULLANILMIYOR
    # (ölçtüm: gece bloklarındaki mürekkepler purpleUst · warmGray ·
    # coolLine · gold · beyaz). Gece eşiğini onlara dayatmak `dimAA`yı
    # `mutedAA`nın üstüne çıkarır, yani üç kademeli metin hiyerarşisini
    # İKİYE indirirdi. Kural yerine NÖBETÇİ konuldu: `gece_check.py`
    # gece bloklarında geçen her rengi ölçer, tavan 0.
    #
    # 🆕 SINIF: "BİR EŞİĞİ KULLANILMAYAN BİR DURUMA DAYATMA — ÖDEDİĞİN
    # BEDEL GERÇEK, ÖNLEDİĞİN SORUN HAYALİ OLUR. YERİNE, O DURUMUN
    # GERÇEKTEN OLUŞUP OLUŞMADIĞINI ÖLÇEN BİR NÖBETÇİ KOY."
    GECE_MUAF = ("muted", "dim")
    for ad, zem in sorted(MUREKKEP.items()) + [("muted", None), ("dim", None),
                                               ("purpleUst", None)]:
        zs = [("gece", Y["gece"]), ("kart", YUZ), ("blok", YUZ2), ("sayfa", BG)]
        if zem:
            zs = [("tint", Y[zem])] + zs
        o = [(k, oran(Y[ad], z)) for k, z in zs]
        en = min(v for k, v in o if not (ad in GECE_MUAF and k == "gece"))
        kotu += en < 4.5
        print("  %-12s %s  %s  %s%s" % (ad, Y[ad],
              " · ".join("%s %.2f" % kv for kv in o),
              "✓" if en >= 4.5 else "🔴",
              "  (gece muaf — orada kullanılmıyor)" if ad in GECE_MUAF else ""))
    print("\n── SİNYAL (metin olarak, en kötü zeminde) ───────────────")
    for ad in SINYAL:
        o = min(oran(Y[ad], z) for z in (YUZ, YUZ2, BG, Y["gece"]))
        kotu += o < 4.5
        print("  %-12s %s  %.2f:1 %s" % (ad, Y[ad], o, "✓" if o >= 4.5 else "🔴"))
    print("\n── KENARLIK (3:1) · DÜĞME · MARKA ───────────────────────")
    for ad in ("goldLine", "warmGray2"):
        print("  %-12s %s  kart %.2f:1" % (ad, Y[ad], oran(Y[ad], YUZ)))
    print("  düğme ailesi  theme.js KOYU literalinde (beyaz mürekkep) — burada türetilmiyor")
    print("  %-12s %s · ink %s → %.2f:1" % ("brandApple", Y["brandApple"],
          Y["brandAppleInk"], oran(Y["brandAppleInk"], Y["brandApple"])))
    print("  %-12s %s  kart %.2f:1" % ("brandGoogle", Y["brandGoogle"],
          oran(Y["brandGoogle"], YUZ)))
    print("\n%d token türetildi · AA altında %d" % (len(Y), kotu))
