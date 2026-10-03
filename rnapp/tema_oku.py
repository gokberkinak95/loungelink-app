#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tema_oku.py — theme.js'i OKUYAN TEK YER.

============================================================================
🔴 NEDEN BU DOSYA VAR — BEŞ KEZ AYNI HATA
============================================================================
`theme.js` iki paleti yan yana taşıyor: açık tema `C` (çoğu değeri
`C.x = "#..."` biçiminde ATANIYOR) ve koyu tema `KOYU` (değerleri nesne
İÇİNDE `x: "#..."` biçiminde). Bir rengi "dosyada ara" diye okuyan her
araç, ikisini karıştırma riski taşıyor.

Ve karıştırdım. Aynı ayrıştırma hatasını sırasıyla:
   1 · tema_check.py      → "kart 1.13:1" diye olmayan bir kusur bildirdi
   2 · check.js           → kontrast haritasını KOYU ile kirletti
   3 · ic_sayfa_son.py    → yanlış zemin çizdi
   4 · dugmeler.py        → yanlış düğme rengi bastı
   5 · (26 Ağu) doku ölçüm betiği → `mutedAA` 5.66 yerine 2.26 okudu

Dördüncüsünden sonra şunu yazmıştım:
   "AYNI AYRIŞTIRMA HATASINI ÜÇ FARKLI ARAÇTA YAPIYORSAN, SORUN ARAÇLARDA
    DEĞİL — O AYRIŞTIRMANIN TEK BİR YERDE OLMAMASINDADIR."
...ve sonra beşincisini yaptım. Dersi YAZMAK, dersi UYGULAMAK değildir.

🆕 SINIF: "BİR DERSİ YAZIP ONU KODA DÖNÜŞTÜRMEZSEN, O DERS BİR NOT'TUR —
BİR KORUMA DEĞİL. KORUMA, TEKRARI İMKÂNSIZ KILAN ŞEYDİR."

Bu dosyadan sonra bir aracın tek başına theme.js'i regex'le okuması
`tema_kaynak_check.py` tarafından kırmızıya boyanır.
============================================================================
"""
import os
import re

KOK = os.path.dirname(os.path.abspath(__file__))
TEMA = os.path.join(KOK, "src", "theme.js")

_HEX = r"\"(#[0-9A-Fa-f]{6})\""
# 🔴 30 AĞUSTOS — `rgba(...)` YAZAN HER TOKEN AYRIŞTIRICIYA GÖRÜNMEZDİ.
#
# Gece paletinde ayırıcılar rgba: `line: "rgba(232,214,182,0.10)"`,
# `line2: "…0.17"`. `_HEX` yalnız `#rrggbb` arıyordu, yani bu iki token
# `palet()` çıktısında HİÇ YOKTU. Sonucu üç yerde ödedik:
#   · önizleme üreticisi kenarlıkları BAŞKA bir renkle (goldLine) çiziyordu
#   · yüzey/kontrast nöbetçileri bu tokenleri hiç ölçmedi
#   · `KeyError: 'line'` — hatanın kendisi bir kusur değil, kusurun İLK
#     kez sesli çıkması oldu
#
# 🆕 SINIF: **"BİR AYRIŞTIRICININ GÖRMEDİĞİ TOKEN, DENETİMİN DE
# GÖRMEDİĞİ TOKENDİR — VE SESSİZCE ATLANAN HER ŞEY, ATLANDIĞI SÜRECE
# DOĞRU SANILIR."**
#
# rgba, opak zemine göre düzleştiriliyor: nöbetçiler ve çizim araçları
# opak bir renk bekliyor. Zemin, paletin kendi `bg`si.
_RGBA = r"\"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)\""


def _duzlestir(r, g, b, a, zemin):
    zr, zg, zb = (int(zemin[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02X%02X%02X" % tuple(
        round(k * a + z * (1 - a)) for k, z in ((r, zr), (g, zg), (b, zb)))


def _kaynak(yol=None):
    return open(yol or TEMA, encoding="utf-8").read()


def palet(kapsam="C", yol=None):
    """
    Tek bir paletin renklerini döndürür.

    kapsam="C"    → açık tema
    kapsam="KOYU" → koyu tema

    İki biçim de toplanır ama YALNIZ o kapsama ait olanlar:
      · `export const <kapsam> = { ad: "#..." }`  (nesne içi)
      · `<kapsam>.ad = "#..."`                    (sonradan atama)

    Nesne gövdesi, `\\n};` ile SINIRLANIR — yani `C`nin bloğu biterken
    durur ve `KOYU`nun bloğuna taşmaz. Beş kez kaybettiğim şey buydu.
    """
    kapsam = _ESLER.get(kapsam, kapsam)      # ACIK → C (bkz. _ESLER notu)
    g = _kaynak(yol)
    if kapsam == "V7":
        return _v7(g)
    p, _s = _coz(g, kapsam)
    return p


# ══════════════════════════════════════════════════════════════════════
# V7 (Aviation Light · 2 Ekim 2026) — `V7` de bir literal değil:
#     for (const k of Object.keys(KOYU)) V7[k] = _v7Kopya(KOYU[k]);
#     const V7_TUVAL = "#F9F8F6", V7_INK = "#0D1B2A", ...
#     Object.assign(V7, { bg: V7_TUVAL, ink: V7_INK, card: "#FFFFFF", ... });
# Taban KOYU'nun kopyası, üstüne `Object.assign` bloğu; değer hex, rgba
# ya da `V7_*` sabiti olabilir. YALNIZ V7 için; C/KOYU ayrıştırması hiç
# değişmez. `Platform.OS === "x" ? A : B` üçlüleri iOS/web dalı (B) ile okunur.
# ══════════════════════════════════════════════════════════════════════
_V7_DEGER = (r'(?:Platform\.OS === "\w+" \? [^:]+? : )?'
             r'("#[0-9A-Fa-f]{6}"|"rgba\([^)]*\)"|V7_[A-Z_]+)')


def _v7(g):
    p = dict(_coz(g, "KOYU")[0])
    sabit = {}
    for mm in re.finditer(r"\b(V7_[A-Z_]+)\s*=\s*(\"#[0-9A-Fa-f]{6}\"|\"rgba\([^)]*\)\")", g):
        sabit[mm.group(1)] = mm.group(2)
    m = re.search(r"Object\.assign\(V7,\s*\{(.*?)\n\}\);", g, re.S)
    if not m:
        return p

    def coz(v):
        v = sabit.get(v, v)
        if v.startswith('"#'):
            return v.strip('"')
        r = re.match(r'"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)"', v)
        return r.groups() if r else None

    sira = [(mm.group(1), coz(mm.group(2)))
            for mm in re.finditer(r"(\w+)\s*:\s*" + _V7_DEGER, m.group(1))]
    zemin = next((c for a, c in sira if a == "bg" and isinstance(c, str)), "#FFFFFF")
    for ad, c in sira:
        if isinstance(c, str):
            p[ad] = c
        elif c:
            p[ad] = _duzlestir(int(c[0]), int(c[1]), int(c[2]), float(c[3]), zemin)
    return p


# ══════════════════════════════════════════════════════════════════════
# 🔴 20 EYLÜL — YEDİNCİ TEKRAR. VE BU SEFER HATA TEK-KAYNAĞIN KENDİSİNDEYDİ.
#
# `jeton_bant_check.py`i yazarken kendi ayrıştırıcımı kullanmıştım;
# `tema_kaynak_check.py` haklı olarak kırmızı yandı ("theme.js'i kendi
# regex'iyle okuyor"). Buraya taşırken KARŞILAŞTIRDIM ve ikisi FARKLI
# cevap verdi:
#
#     tema_oku.palet("KOYU")["purpleBg"]  →  #281D40   (MENEKŞE)
#     gerçek                               →  goldBg    (ALTIN)
#
# Sebep bu fonksiyonun kendi yapısındaydı. Atamalar üç GRUP hâlinde,
# SIRAYLA değil TÜRE GÖRE işleniyordu:
#     1) nesne literali        p.update(...)
#     2) `KOYU.x = "#hex"`     p.update(...)     ← son hex kazanır
#     3) `KOYU.x = KOYU.y;`    if ad not in p    ← ZATEN VARSA ATLANIR
#
# Yani 3 Eylül'de yazılan `KOYU.purpleBg = KOYU.goldBg;` (satır 1589),
# satır 1315'teki eski hex tarafından YENİLİYORDU — dosyada SONRA
# gelmesine rağmen. Beş jeton (purple · purpleBg · purpleInk ·
# purpleUst · purpleLine) bu yüzden 17 gündür YANLIŞ okunuyordu ve
# bunu okuyan HER kapı — kontrast nöbetçileri dâhil — o yanlış değeri
# ölçüyordu.
#
# JavaScript'te kural tek: SON ATAMA KAZANIR. Ayrıştırıcı da öyle
# okumalı. Artık üç biçim de tek bir SIRALI taramada, dosyadaki
# konumlarına göre uygulanıyor.
#
# 🆕 SINIF: "AYRIŞTIRMAYI TEK YERE TOPLAMAK, O TEK YERİN DOĞRU OLDUĞUNU
# GÖSTERMEZ — TEK KAYNAK YANLIŞSA ARTIK HERKES AYNI ŞEKİLDE YANILIR,
# VE FARKLI ARAÇLARIN FARKLI CEVAP VERMESİ GİBİ BİR UYARI DA KALMAZ."
#
# (Bu hatayı bulduran şey, ikinci bir ayrıştırıcının farklı cevap
# vermesiydi. Yani tek-kaynak kuralı doğru, ama tek kaynağa da bir
# KARŞILAŞTIRMA borçluyuz — `tema_satirlari` altındaki öz sınama.)
# ══════════════════════════════════════════════════════════════════════
def _coz(g, kapsam):
    """
    (değerler, satırlar) — dosyadaki SIRAYA göre çözülmüş palet.

    `değerler[ad]` son geçerli renk · `satırlar[ad]` o atamanın satırı.
    """
    olaylar = []                       # (konum, ad, tur, veri)
    m = re.search(r"export const " + kapsam + r"\s*=\s*\{(.*?)\n\};", g, re.S)
    if m:
        ic, ofs = m.group(1), m.start(1)
        for mm in re.finditer(r"(\w+)\s*:\s*" + _HEX, ic):
            olaylar.append((ofs + mm.start(), mm.group(1), "hex", mm.group(2)))
        for mm in re.finditer(r"(\w+)\s*:\s*" + _RGBA, ic):
            olaylar.append((ofs + mm.start(), mm.group(1), "rgba", mm.groups()[1:]))
    for mm in re.finditer(kapsam + r"\.(\w+)\s*=\s*" + _HEX, g):
        olaylar.append((mm.start(), mm.group(1), "hex", mm.group(2)))
    for mm in re.finditer(kapsam + r"\.(\w+)\s*=\s*" + _RGBA, g):
        olaylar.append((mm.start(), mm.group(1), "rgba", mm.groups()[1:]))
    for mm in re.finditer(kapsam + r"\.(\w+)\s*=\s*" + kapsam + r"\.(\w+)\s*;", g):
        olaylar.append((mm.start(), mm.group(1), "takma", mm.group(2)))
    olaylar.sort(key=lambda o: o[0])

    # ⚠️ ZEMİN İKİ TURDA: rgba düzleştirmesi `bg`ye ihtiyaç duyuyor ama
    # `bg` de bir atama. Önce hex'lerden bg'yi buluyoruz, sonra sıralı
    # tarama yapıyoruz. (bg hiç rgba olmadı; olsaydı bu varsayım
    # kırılırdı ve o zaman da burada patlaması doğru olurdu.)
    on = {a: d for _k, a, t, d in olaylar if t == "hex"}
    zemin = on.get("bg") or ("#100E12" if kapsam == "KOYU" else "#FFFFFF")

    p, satir = {}, {}
    for konum, ad, tur, veri in olaylar:
        if tur == "hex":
            p[ad] = veri
        elif tur == "rgba":
            r_, g_, b_, a_ = veri
            p[ad] = _duzlestir(int(r_), int(g_), int(b_), float(a_), zemin)
        else:                                   # takma ad
            if veri in p:
                p[ad] = p[veri]
            else:
                continue                        # hedefi yoksa uydurma
        satir[ad] = g.count("\n", 0, konum) + 1
    return p, satir


def tema_satirlari(kapsam="KOYU", yol=None):
    """Her jetonun GEÇERLİ atamasının satır numarası (bulgu göstermek için)."""
    return _coz(_kaynak(yol), _ESLER.get(kapsam, kapsam))[1]


# ══════════════════════════════════════════════════════════════════════
# `ACIK` — AÇIK TEMA, VE NEDEN GÖRÜNMÜYORDU (12 Eylül · kapsam turu)
#
# 🔴 GÖKBERK SORDU, ÖLÇTÜM VE KÖR NOKTA ÇIKTI:
#     tema_oku.palet("ACIK")  →  0 anahtar
# Yani 48 kapının HİÇBİRİ açık temayı görmüyordu. Ayarlar'dan açık
# temaya geçen bir kullanıcının gördüğü hiçbir renk ölçülmemişti.
#
# Sebep yapısal: `theme.js`te `ACIK` bir LİTERAL DEĞİL, çalışma anında
# üretilen bir kopya:
#     const ACIK = {}; for (const k of Object.keys(C)) ACIK[k] = _kopya(C[k]);
# Ayrıştırıcı `export const ACIK = { ... }` arıyordu; öyle bir blok yok.
# Yani kapı "açık temada ihlal yok" demiyordu — "açık tema diye bir şey
# görmüyorum" diyordu, ve ikisi ekranda aynı görünüyor.
#
# Doğrusu: `ACIK`, tüm atamalar bittikten SONRA alınmış bir `C`
# anlık görüntüsü. Dolayısıyla `palet("ACIK") == palet("C")` — ve bunu
# bir takma ad olarak yazmak, kopyalamaktan doğru: `C` değişirse
# `ACIK` da değişir.
#
# 🆕 SINIF: "BİR ÖLÇÜM ARACININ 'İHLAL YOK' DEMESİ İLE 'BAKMADIM'
# DEMESİ EKRANDA AYNI GÖRÜNÜR — HER KAPSAMIN KAÇ JETON GÖRDÜĞÜNÜ DE
# YAZDIRMADAN O KAPIYA GÜVENME."
# ══════════════════════════════════════════════════════════════════════
_ESLER = {"ACIK": "C"}


def rozet(kapsam="C", yol=None):
    """
    Rozet tonları da iki kapsamda: `C.badgeInk` ve `KOYU.badgeInk`.
    Ayrı bir yapı oldukları için ayrı bir okuyucu — ama yine TEK yerde.
    """
    g = _kaynak(yol)
    kapsam = _ESLER.get(kapsam, kapsam)
    m = re.search(kapsam + r"\.badgeInk\s*=\s*\{(.*?)\n\};", g, re.S)
    if not m:
        return {}
    return dict(re.findall(r"(\w+)\s*:\s*" + _HEX, m.group(1)))


def paletler(yol=None):
    """Her iki paleti tek çağrıda: {"C": {...}, "KOYU": {...}}
    (`ACIK` = `C`; ayrı anahtar vermiyorum ki kapılar aynı paleti iki kez
    ölçüp "iki tema da temiz" diye yanlış bir güven üretmesin.)"""
    return {"C": palet("C", yol), "KOYU": palet("KOYU", yol)}


# --------------------------------------------------------------------------
# RENK MATEMATİĞİ — bu da tek yerde. Dört araçta dört kopyası vardı.
# --------------------------------------------------------------------------
def hex_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def parlaklik(p):
    if isinstance(p, str):
        p = hex_rgb(p)
    return 0.2126 * _lin(p[0]) + 0.7152 * _lin(p[1]) + 0.0722 * _lin(p[2])


def oran(a, b):
    la, lb = parlaklik(a), parlaklik(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def uzerine(zemin, ust, alfa):
    """Yarı saydam bir katmanın altındaki GERÇEK zemini üretir."""
    if isinstance(zemin, str):
        zemin = hex_rgb(zemin)
    if isinstance(ust, str):
        ust = hex_rgb(ust)
    a = max(0.0, min(1.0, alfa))
    return tuple(round(zemin[i] * (1 - a) + ust[i] * a) for i in range(3))


if __name__ == "__main__":
    ps = paletler()
    print("C   : %d renk" % len(ps["C"]))
    print("KOYU: %d renk" % len(ps["KOYU"]))
    for ad in ("ink", "body", "mutedAA", "dimAA", "goldText", "bg", "surface"):
        print("  %-10s açık %-9s koyu %-9s"
              % (ad, ps["C"].get(ad, "—"), ps["KOYU"].get(ad, "—")))
