#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
koyu_check.py — KOYU TEMANIN DELİĞİ VAR MI?

🔴 NEDEN VAR
Koyu tema anahtarını kurmadan önce ölçtüm: `C` paletinde 55 renk vardı,
`KOYU`da 19. Kodda kullanılan ama koyu karşılığı OLMAYAN 39 token —
toplam 1270 çağrı yeri. Anahtar o gün konsaydı, koyu sayfada AÇIK TEMA
renkleriyle çizilen 1270 nokta olurdu: beyaz kart, açık tint, koyu
mürekkep. Anahtar çalışırdı, tema çalışmazdı.

Boşluğu doldurmak bir kereliktir; boşluğun TEKRAR AÇILMASINI önlemek
bu dosyanın işi. Yarın `C.yeniRenk` eklenip koyu karşılığı yazılmazsa,
o token koyu temada sessizce açık tema değerine düşer — ve kimse
görmez, çünkü açık temada her şey doğru görünür.

🆕 SINIF: "İKİ TEMALI BİR ÜRÜNDE, TEK TEMADA ÇALIŞAN BİR DEĞİŞİKLİK
'ÇALIŞIYOR' SAYILMAZ — İKİNCİ TEMA HER ZAMAN SESSİZ BOZULAN TARAFTIR."

ÜÇ SORU:
  1 · Kodda kullanılan her `C.x`in bir `KOYU.x`i var mı? (ya da
      gerekçeli "iki temada aynı" listesinde mi)
  2 · Gece yüzeylerinde (`C.gece`) kullanılan her mürekkep, İKİ temada
      da AA geçiyor mu?
  3 · `C`den değer KOPYALAYAN yapılar (`S`, `st`, `ACCENT`, `BTN`,
      `C.yuzey`) tema değişince yeniden kuruluyor mu?

TAVAN 0.
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import oran, palet                                   # noqa: E402

TAVAN = 0
DOSYA = sorted(glob.glob(os.path.join(KOK, "src", "*.js"))) + [os.path.join(KOK, "App.js")]

# İki temada AYNI kalması DOĞRU olanlar — her biri gerekçeli.
# Gerekçesiz muafiyet muafiyet değil, görmezden gelmedir.
AYNI = {
    "foto": "fotoğrafın üstündeki mürekkep — zemini tema değil görsel",
    "btnUstIsik": "düğmenin 1px üst ışığı — iki temada da beyaz %34",
    "badge": "KOYU.badge ayrı tanımlı (nesne)",
    "badgeInk": "KOYU.badgeInk ayrı tanımlı (nesne)",
    "badgeToneFor": "fonksiyon, renk değil",
    "yuzey": "türetilmiş tablo — `kurYuzey()` tema değişince yeniden kurar",
    "doku": "KOYU.doku ayrı tanımlı (nesne)",
    "line": "KOYU.line ayrı tanımlı",
    "warmLine": "KOYU.warmLine ayrı tanımlı (rgba)",
    "tealLine": "KOYU.tealLine ayrı tanımlı (rgba)",
    "purpleLine": "KOYU.purpleLine ayrı tanımlı (rgba)",
    "hataLine": "KOYU.hataLine ayrı tanımlı (rgba)",
    "perde": "KOYU.perde ayrı tanımlı (rgba)",
    "sicak": "KOYU.sicak ayrı tanımlı",
    "sicakGuc": "sayı, renk değil",
}

# `C`den değer kopyalayan ve bu yüzden yeniden kurulması ZORUNLU yapılar.
KURULMALI = [
    ("src/theme.js", "ACCENT.trip", "renk dili (ACCENT)"),
    ("src/theme.js", "ELEV.card.shadowColor", "yükseklik gölgeleri"),
    ("src/theme.js", "BTN.golge.shadowColor", "düğme gölgesi"),
    ("src/theme.js", "Object.assign(C.yuzey", "yüzey denetim tablosu"),
    ("src/ortak.js", "Object.assign(S,", "ortak stiller"),
    ("App.js", "Object.assign(st,", "App.js StyleSheet"),
    # 🔴 BU SATIR SONRADAN EKLENDİ ÇÜNKÜ LİSTEYİ ELLE YAZMIŞTIM VE
    # `ui.js`teki `BTN` tablosunu ATLAMIŞTIM — yani koyu temada bütün
    # düğmeler açık tema zeminiyle çizilirdi ve nöbetçi "✓" derdi.
    ("src/ui.js", "BTN.gold.bg", "düğme varyant tablosu (ui.js)"),
]


def kod_maskesi(g):
    m = [True] * len(g)
    i = 0
    while i < len(g):
        if g.startswith("/*", i):
            j = g.find("*/", i + 2)
            j = len(g) if j < 0 else j + 2
            for k in range(i, j):
                m[k] = False
            i = j
            continue
        if g.startswith("//", i):
            j = g.find("\n", i)
            j = len(g) if j < 0 else j
            for k in range(i, j):
                m[k] = False
            i = j
            continue
        i += 1
    return m


def kullanilan():
    """Kodda geçen `C.x` tokenleri ve kaç kez."""
    say = {}
    for p in DOSYA:
        if p.endswith("theme.js") or not os.path.exists(p):
            continue
        g = open(p, encoding="utf-8").read()
        msk = kod_maskesi(g)
        for m in re.finditer(r"\bC\.(\w+)", g):
            if not msk[m.start()]:
                continue
            say[m.group(1)] = say.get(m.group(1), 0) + 1
    return say


def gece_murekkepleri():
    """`backgroundColor: C.gece` bloklarında geçen metin renkleri."""
    bulunan = []
    for p in DOSYA:
        if p.endswith("theme.js") or not os.path.exists(p):
            continue
        g = open(p, encoding="utf-8").read()
        for m in re.finditer(r"backgroundColor: C\.gece\b", g):
            pen = g[m.start():m.start() + 1400]
            for mm in re.finditer(r'color:\s*(C\.\w+|"#[0-9A-Fa-f]{3,8}")', pen):
                bulunan.append((os.path.basename(p),
                                g[:m.start()].count("\n") + 1, mm.group(1)))
    return bulunan


def coz(P, ifade):
    if ifade.startswith("C."):
        return P.get(ifade[2:])
    h = ifade.strip("\"'")
    if len(h) == 4:
        h = "#" + "".join(c * 2 for c in h[1:])
    return h if h.startswith("#") and len(h) == 7 else None


def main():
    C = palet("C")
    K = palet("KOYU")
    kullanim = kullanilan()
    print("=" * 76)
    print("KOYU TEMA BÜTÜNLÜK DENETİMİ")
    print("=" * 76)

    # ── 1 · EKSİK TOKEN ─────────────────────────────────────────────
    eksik = []
    for tok, n in sorted(kullanim.items(), key=lambda x: -x[1]):
        if tok in AYNI or tok in K:
            continue
        if tok not in C:
            continue          # C'de de yok — palet denetiminin işi
        eksik.append((tok, n))
    print("\n  1 · TOKEN KAPSAMI")
    print("      kodda kullanılan C tokeni : %d" % len(kullanim))
    print("      KOYU karşılığı olan       : %d" % sum(
        1 for t in kullanim if t in K))
    print("      gerekçeli 'iki temada aynı': %d" % sum(
        1 for t in kullanim if t in AYNI))
    print("      KARŞILIĞI YOK             : %d  (tavan %d)" % (len(eksik), TAVAN))
    for tok, n in eksik[:15]:
        print("        ✗ C.%-14s %d çağrı yeri — koyu temada AÇIK tema rengi çizilir"
              % (tok, n))

    # ── 2 · GECE YÜZEYİ ─────────────────────────────────────────────
    print("\n  2 · GECE YÜZEYİ MÜREKKEPLERİ (iki temada da AA)")
    gece_hata = []
    murekkepler = gece_murekkepleri()
    for tema, P in (("AÇIK", C), ("KOYU", {**C, **K})):
        zem = P.get("gece")
        for ad, satir, ifade in murekkepler:
            renk = coz(P, ifade)
            if not renk or not zem:
                continue
            o = oran(renk, zem)
            if o < 4.5:
                gece_hata.append((tema, ad, satir, ifade, o))
    print("      ölçülen mürekkep : %d (× 2 tema)" % len(murekkepler))
    print("      AA altında       : %d  (tavan %d)" % (len(gece_hata), TAVAN))
    for tema, ad, s, ifade, o in gece_hata:
        print("        ✗ %s %s:%d  %s  %.2f:1" % (tema, ad, s, ifade, o))

    # ── 3 · YENİDEN KURULAN YAPILAR ─────────────────────────────────
    print("\n  3 · `C`DEN DEĞER KOPYALAYAN YAPILAR YENİDEN KURULUYOR MU")
    kurulmayan = []
    for rel, im, ad in KURULMALI:
        yol = os.path.join(KOK, rel)
        g = open(yol, encoding="utf-8").read() if os.path.exists(yol) else ""
        # 🔴 BU DENETİM MUTASYON TESTİNİ GEÇEMEDİ.
        # `Object.assign(S, y);` satırını YORUMA ALDIM — yani ortak
        # stiller tema değişince artık yeniden kurulmuyordu — ve denetim
        # "✓" dedi. Sebebi tanıdık: metni ARIYORDUM, kodu değil.
        # Yorum satırı da o metni içeriyor.
        #
        # Aynı ders bu projede üçüncü kez: yorumları maskelemeyen her
        # tarayıcı, er ya da geç yorumu kod sayar. Fark şu ki bu sefer
        # ürünü değil DENETİMİ yanıltıyordu — ve yanlış "✓" veren bir
        # nöbetçi, olmayan nöbetçiden kötüdür.
        #
        # 🆕 SINIF: "BİR NÖBETÇİYİ YAZDIKTAN SONRA ONU BOZMAYI DENE —
        # BOZAMIYORSAN NÖBETÇİ DEĞİL, SÜSTÜR."
        msk = kod_maskesi(g)
        g = "".join(c if msk[i] else " " for i, c in enumerate(g))
        # `temaYenidenKur(...)` gövdesinin içinde geçmeli
        icinde = False
        for m in re.finditer(r"temaYenidenKur\(\(\) => \{", g):
            d, k = 1, m.end()
            while k < len(g) and d > 0:
                if g[k] == "{":
                    d += 1
                elif g[k] == "}":
                    d -= 1
                k += 1
            if im in g[m.end():k]:
                icinde = True
                break
        print("      %s %-26s %s" % ("✓" if icinde else "✗", ad, rel))
        if not icinde:
            kurulmayan.append(ad)

    toplam = len(eksik) + len(gece_hata) + len(kurulmayan)
    print()
    if toplam > TAVAN:
        print("🔴 %d sorun. Koyu tema, ölçülmediği yerde çalışmaz." % toplam)
        if eksik:
            print("   Eksik token için: `python koyu_doldur.py` (ölçerek türetir)")
        if kurulmayan:
            print("   Yeniden kurulmayan yapı: `temaYenidenKur(() => {...})` ile kaydet.")
        return 1
    print("✓ Koyu tema bütün: token kapsamı tam, gece yüzeyleri okunur,")
    print("  değer kopyalayan her yapı tema değişince yeniden kuruluyor.")
    print("  ⚠️ Bu denetim KAYNAĞI ölçer. Gerçek görünüm cihazda doğrulanır —")
    print("     `render_check/mount_test.js` koyu temada da mount ediyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
