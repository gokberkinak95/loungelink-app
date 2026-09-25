#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
taklit_yuzey_check.py — RENDER TAKLİTLERİ ÜRÜNÜN KULLANDIĞI YÜZEYİ
KAPSIYOR MU?

🔴 NEDEN VAR — BU HAFTA AYNI HATAYI DÖRT KEZ YEDİM.

    Animated.event        → "BİLEŞEN ÇÖKTÜ" (Keşfet, Profil)
    Animated.ScrollView   → "BİLEŞEN ÇÖKTÜ" (aynı gün)
    Animated.stagger      → "BİLEŞEN ÇÖKTÜ" (tanıtım)
    PanResponder.create   → "BİLEŞEN ÇÖKTÜ" (tanıtım, kaydırma)

Dördünde de kod DOĞRUYDU; taklit eksikti. Ve dördünde de testin verdiği
mesaj "ürün bozuk" diyordu. `mount_test.js`in içinde v3.4'te yazdığım
ders zaten duruyordu — okumuştum, uygulamamıştım.

Bir dersi üçüncü kez tekrar ediyorsan o ders bir yorum değil bir
BETİK olmalı. Bu dosya o betik: üründe çağrılan her `Animated.*`,
`PanResponder.*` ve `Platform.*` üyesini toplar, üç taklidin
(`stub_rn.js`, `mount_test.js`, `giris_kapisi_test.js`) hepsinde var mı
diye bakar.

🆕 SINIF: "AYNI HATAYI ÜÇÜNCÜ KEZ YAPIYORSAN EKSİK OLAN DİKKAT DEĞİL
NÖBETÇİDİR — TEKRARLANAN HER HATA, YAZILMAMIŞ BİR TESTİN İMZASIDIR."
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
URUN = ["App.js"] + ["src/" + f for f in sorted(os.listdir(os.path.join(KOK, "src")))
                     if f.endswith(".js")]
TAKLITLER = ["render_check/stub_rn.js",
             "render_check/mount_test.js",
             "render_check/giris_kapisi_test.js"]

# Hangi ad alanlarını izliyoruz
IZLENEN = ("Animated", "PanResponder", "Easing")

TAVAN = 0

# Taklit gerektirmeyen üyeler — gerekçeli.
MUAF = {
    "Animated.Value": "her taklitte zaten var; ayrıca `new` ile çağrılıyor, üye erişimi değil",
}


def _yorumsuz(s):
    """Yorumları çıkar. 🔴 İlk sürümde çıkarmıyordum ve `Easing.back`
    yalnız bir YORUMDA geçtiği için ("`Easing.out(Easing.back)` DEĞİL…")
    taklitlerden eksik sayıldı. Bir nöbetçinin yanlış alarmı, yokluğu
    kadar zararlıdır: birkaç kez olur ve artık kimse bakmaz."""
    s = re.sub(r"/\*.*?\*/", " ", s, flags=re.S)
    s = re.sub(r"(?m)^\s*//.*$", " ", s)
    s = re.sub(r"(?<![:\w])//[^\n]*", " ", s)
    return s


def urun_yuzeyi():
    kullanilan = set()
    for f in URUN:
        s = _yorumsuz(open(os.path.join(KOK, f), encoding="utf-8").read())
        for ns in IZLENEN:
            for m in re.finditer(r"\b" + ns + r"\.([A-Za-z_][A-Za-z0-9_]*)", s):
                kullanilan.add(ns + "." + m.group(1))
    return kullanilan


def taklit_yuzeyi(yol):
    s = open(os.path.join(KOK, yol), encoding="utf-8").read()
    var = set()
    for ns in IZLENEN:
        # `if (k === "Animated") return { ... }`  ya da  `Animated: { ... }`
        # Üç yazım da geçerli: `k === "X") return {`, `X: {`, `const X = {`
        for m in re.finditer(r'(?:k === "' + ns + r'"\)\s*return\s*|'
                             + ns + r':\s*|const\s+' + ns + r'\s*=\s*)\{', s):
            i = m.end() - 1
            derinlik, j = 0, i
            while j < len(s):
                if s[j] == "{":
                    derinlik += 1
                elif s[j] == "}":
                    derinlik -= 1
                    if derinlik == 0:
                        break
                j += 1
            blok = s[i:j]
            for uye in re.findall(r"(?:^|\s|,)([A-Za-z_][A-Za-z0-9_]*)\s*:", blok):
                var.add(ns + "." + uye)
    return var


def main():
    print("=" * 74)
    print("TAKLİT YÜZEYİ DENETİMİ — sahte nesne gerçeğini kapsıyor mu?")
    print("=" * 74)
    urun = {u for u in urun_yuzeyi() if u not in MUAF}
    print("  üründe çağrılan üye : %d" % len(urun))
    for u in sorted(urun):
        print("     %s" % u)

    kotu = []
    print()
    for t in TAKLITLER:
        var = taklit_yuzeyi(t)
        eksik = sorted(urun - var)
        if eksik:
            kotu.append((t, eksik))
            print("  ✗ %-38s eksik: %s" % (t.split("/")[-1], ", ".join(eksik)))
        else:
            print("  ✓ %-38s tam" % t.split("/")[-1])

    if len(kotu) > TAVAN:
        print("\n🔴 Eksik taklit, ÇALIŞAN kodu suçlayan bir tanıktır.")
        print("   Bu hafta dört kez oldu; bir daha olmasın diye bu kapı var.")
        return 1
    print("\n✓ Üç taklit de ürünün kullandığı yüzeyi kapsıyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
