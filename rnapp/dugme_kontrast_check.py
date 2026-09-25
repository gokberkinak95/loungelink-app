#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dugme_kontrast_check.py

============================================================================
DÜĞME KONTRAST DENETİMİ — ARAMA TABLOSUNDAKİ RENK ÇİFTLERİ

🔴 NEDEN VAR — 20 EYLÜL

`src/ui.js` düğme varyantlarını bir arama tablosunda tutuyor:

    const BTN = {
      gold: { bg: C.goldBtn, fg: "#fff", bd: C.goldBtn },
      ...
    };

`gold` varyantı koyu temada `#B49B70` zemine BEYAZ metin yazıyordu:
**2.67:1**. Gereken 4.5. Ve bu, uygulamanın en çok basılan düğmesi —
"Kaydet ve Devam", "Galeriden seç", her altın birincil eylem.

Doğru jeton zaten vardı (`KOYU.onGold = "#17120B"`, oran 6.97:1); çağrı
yeri onu atlamıştı. `rose` de aynı kusurdaydı (3.12:1).

66 kapının hiçbiri bunu görmedi ve hepsi haklıydı:
`yuzey_kontrast_check.py` SATIR İÇİ stil nesnelerini tarıyor. Burası bir
arama tablosu — `bg` ile `fg` aynı süslü parantezin içinde ama bir stil
nesnesi değil, o yüzden desene hiç düşmüyordu.

🆕 SINIF: "BİR DENETİM STİL NESNELERİNİ TARIYORSA, RENGİ STİL NESNESİ
OLMAYAN BİR YERDE TUTAN HER TABLO O DENETİMİN KÖR NOKTASIDIR."

NE ÖLÇÜYOR
  `{ bg: <renk>, fg: <renk> }` biçimindeki her kaydı — hangi dosyada
  olursa olsun. Jetonlar `theme.js`in KOYU paletinden çözülür (uygulama
  `temaUygula("koyu")` ile açılıyor).

NEYİ ÖLÇMÜYOR
  Alfa ekli renkleri (`C.goldBtn + "20"`) ve `transparent` zeminleri —
  onların gerçek zemini çağrı yerinde belli olur.

TAVAN 0 · AA eşiği 4.5
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
TEMA = os.path.join(KOK, "src", "theme.js")
TAVAN = 0
AA = 4.5


def jetonlar():
    """KOYU paleti (ACIK'tan miras alınanlar dahil) → {ad: #RRGGBB}"""
    s = open(TEMA, encoding="utf-8").read()
    d = {}
    # 1) ACIK/taban değerler: `ad: "#RRGGBB",`
    for m in re.finditer(r'^\s{2}(\w+):\s*"(#[0-9A-Fa-f]{6})"', s, re.M):
        d.setdefault(m.group(1), m.group(2))
    # 2) `C.ad = "#RRGGBB"`
    for m in re.finditer(r'^C\.(\w+)\s*=\s*"(#[0-9A-Fa-f]{6})"', s, re.M):
        d[m.group(1)] = m.group(2)
    # 3) KOYU ÜSTÜN GELİR — uygulama koyu temayla açılıyor
    koyu = s[s.index("export const KOYU"):]
    for m in re.finditer(r'^\s{2}(\w+):\s*"(#[0-9A-Fa-f]{6})"', koyu, re.M):
        d[m.group(1)] = m.group(2)
    for m in re.finditer(r'^KOYU\.(\w+)\s*=\s*"(#[0-9A-Fa-f]{6})"', s, re.M):
        d[m.group(1)] = m.group(2)
    # 4) ⚠️ TAKMA ADLAR: `KOYU.bgAlt = KOYU.surfaceAlt;`
    #    İlk yazımda bunu okumuyordum ve `bgAlt` açık temanın #F0EDE6'sına
    #    düşüyordu — kapı koyu temada var olmayan bir beyaz zemin uydurup
    #    `muted` varyantını kırmızı yaktı. Yani BİR YANLIŞ ALARM.
    #    Gürültülü nöbetçi kapatılır; o yüzden düzeltildi, gevşetilmedi.
    for _ in range(4):          # zincirli takma adlar için birkaç tur
        for m in re.finditer(r'^KOYU\.(\w+)\s*=\s*KOYU\.(\w+)\s*;', s, re.M):
            hedef = d.get(m.group(2))
            if hedef:
                d[m.group(1)] = hedef
    return d


def coz(ifade, jt):
    ifade = ifade.strip()
    m = re.fullmatch(r'"(#[0-9A-Fa-f]{6})"', ifade)
    if m:
        return m.group(1)
    m = re.fullmatch(r'"#([0-9A-Fa-f]{3})"', ifade)
    if m:
        h = m.group(1)
        return "#" + "".join(c * 2 for c in h)
    m = re.fullmatch(r"C\.(\w+)", ifade)
    if m:
        return jt.get(m.group(1))
    # `C.onGold || "#fff"` → soldaki jeton varsa o
    m = re.match(r"C\.(\w+)\s*\|\|", ifade)
    if m and m.group(1) in jt:
        return jt[m.group(1)]
    return None


def lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def parlaklik(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def oran(a, b):
    la, lb = parlaklik(a), parlaklik(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


KAYIT = re.compile(
    r"(\w+)\s*:\s*\{[^{}]*?\bbg\s*:\s*([^,}]+?)\s*,[^{}]*?\bfg\s*:\s*([^,}]+?)\s*[,}]",
    re.S)


def main():
    jt = jetonlar()
    if "goldBtn" not in jt:
        print("✗ theme.js'ten jeton okunamadı — ayrıştırıcı körleşmiş olabilir.")
        sys.exit(1)

    atla = {"node_modules", ".git", "android", "ios", ".expo", "web_sahne",
            "assets", "brand", "tasarim_kaynak", "ekranlar_oneri", "dist",
            "dist_dbg", "render_check", "ekranlar_render"}
    bulgular, olculen, atlanan = [], 0, 0
    for d, kl, do in os.walk(KOK):
        kl[:] = [k for k in kl if k not in atla]
        for f in do:
            if not f.endswith(".js") or f.startswith("check"):
                continue
            p = os.path.join(d, f)
            g = open(p, encoding="utf-8", errors="replace").read()
            g = re.sub(r"//.*$", "", g, flags=re.M)
            for m in KAYIT.finditer(g):
                ad, bgi, fgi = m.group(1), m.group(2), m.group(3)
                bg, fg = coz(bgi, jt), coz(fgi, jt)
                if bg is None or fg is None:
                    atlanan += 1
                    continue
                olculen += 1
                v = oran(fg, bg)
                if v < AA:
                    satir = g[:m.start()].count("\n") + 1
                    bulgular.append((os.path.relpath(p, KOK).replace(os.sep, "/"),
                                     satir, ad, bg, fg, v))

    print("=" * 74)
    print("DÜĞME KONTRASTI — arama tablosundaki { bg, fg } çiftleri")
    print("=" * 74)
    print("  ölçülen çift : %d" % olculen)
    print("  atlanan      : %d  (alfa ekli / transparent / çözülemeyen)" % atlanan)
    print("")
    if bulgular:
        print("  ✗ %d düğme varyantı AA altında (gereken %.1f):" % (len(bulgular), AA))
        for dosya, satir, ad, bg, fg, v in bulgular:
            print("      %s:%d  `%s`  %s üstünde %s = %.2f" % (dosya, satir, ad, bg, fg, v))
        print("")
        print("  ÇÖZÜM: sabit renk yerine jetonu kullan. Koyu temada altın")
        print("  zeminin mürekkebi `C.onGold` (#17120B) — beyaz DEĞİL.")
    else:
        print("  ✓ her düğme varyantı AA'yı geçiyor")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    sys.exit(1 if len(bulgular) > TAVAN else 0)


main()
