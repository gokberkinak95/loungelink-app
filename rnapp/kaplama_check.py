#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kaplama_check.py — "TAMAMINI KAPLAYAN" KATMAN GERÇEKTEN TAMAMINI KAPLIYOR MU?

🔴 NEDEN VAR — 14 EYLÜL · GÖKBERK'İN CİHAZ EKRAN GÖRÜNTÜSÜ
Altın düğmenin gradyanı sağ ucuna kadar gitmiyordu; son ~36pt'de çıplak
taban rengi kalıyor ve ekranda sert bir dikey çizgi görünüyordu. Ekran
görüntüsünün piksellerinden ölçüldü (1080×2312 · 2.98x):

    düğme   x  88…992   (904px)
    gradyan x  88…888   (800px)      eksik 104px
    ebeveynin paddingHorizontal'i 18pt × 2 = 107px   ← birebir

SEBEP: katman `left:0, top:0, width:"100%", height:"100%"` ile kuruluydu.
`left` KENARLIK kutusuna, `%100` ise İÇERİK kutusuna göre çözülüyor. İkisi
aynı kutuyu ölçmediği için katman, ebeveynin yatay dolgusu kadar dar kalır.
Dolgusu olmayan bir kapta fark sıfırdır — bu yüzden hiçbir denetimde,
hiçbir render testinde, hiçbir web sahnesinde görünmedi. Yalnız dolgulu
kaplarda ve yalnız cihazda çıktı.

🆕 SINIF: **"BİR KATMANI 'TAMAMINI KAPLASIN' DİYE KURUYORSAN YÜZDEYLE
DEĞİL KARŞIT KENARLA SABİTLE — `%100` HANGİ KUTUYU ÖLÇTÜĞÜNÜ SÖYLEMEZ,
`right:0` SÖYLER."**

NE DENETLİYOR: `position:"absolute"` + `left:0`/`top:0` + `width:"100%"`
ya da `height:"100%"` taşıyan, ama karşıt kenarı (`right:0`/`bottom:0`)
VERMEYEN katmanlar.

MUAFİYET: hemen üstünde `⚠️` ile başlayan bir gerekçe yorumu olan katman
(FotoBant'ın iki görseli böyle: kapları dolgusuz ve web'de `Image` kendi
piksel boyunu aldığı için yüzde BİLEREK veriliyor).

TAVAN: 0 — bu borç kapandı, yeniden açılamaz.
"""
import os, re, sys

KOK = os.path.dirname(os.path.abspath(__file__))
DOSYALAR = ["App.js"] + [os.path.join("src", f) for f in sorted(os.listdir(os.path.join(KOK, "src")))
                         if f.endswith(".js")]

STIL = re.compile(r'style=\{\{([^{}]*)\}\}')

bulgu = []
for bag in DOSYALAR:
    yol = os.path.join(KOK, bag)
    if not os.path.isfile(yol):
        continue
    s = open(yol, encoding="utf-8", errors="replace").read()
    for m in STIL.finditer(s):
        blok = m.group(1)
        if 'position: "absolute"' not in blok:
            continue
        yuzde_g = 'width: "100%"' in blok
        yuzde_y = 'height: "100%"' in blok
        if not (yuzde_g or yuzde_y):
            continue
        eksik = []
        if yuzde_g and "right: 0" not in blok and "left: 0" in blok:
            eksik.append("right: 0")
        if yuzde_y and "bottom: 0" not in blok and "top: 0" in blok:
            eksik.append("bottom: 0")
        if not eksik:
            continue
        # MUAFİYET: hemen üstteki 6 satırda ⚠️ ile başlayan gerekçe
        onceki = s[max(0, m.start() - 600):m.start()]
        if "⚠️" in onceki.split("{/*")[-1] or "⚠️" in onceki[-400:]:
            continue
        satir = s[:m.start()].count("\n") + 1
        bulgu.append((bag, satir, ", ".join(eksik), re.sub(r"\s+", " ", blok)[:90]))

TAVAN = 0
print("=" * 74)
print("KAPLAMA DENETİMİ — 'tamamını kaplayan' katman gerçekten kaplıyor mu?")
print("=" * 74)
print(f"  taranan dosya : {len(DOSYALAR)}")
print(f"  eksik kenarlı katman : {len(bulgu)}  (tavan {TAVAN})")
for bag, satir, eksik, blok in bulgu[:12]:
    print(f"    ✗ {bag}:{satir}  «{eksik}» YOK  →  {blok}")

if len(bulgu) > TAVAN:
    print()
    print("  Bir katman kabının tamamını kaplayacaksa karşıt kenarla sabitlenir:")
    print("      position: 'absolute', left: 0, top: 0, right: 0, bottom: 0")
    print("  `width: '100%'` ebeveynin İÇERİK kutusunu ölçer; ebeveynin dolgusu")
    print("  varsa katman o kadar dar kalır ve kenarda çıplak zemin görünür.")
    sys.exit(1)

print()
print("✓ Kaplayan her katman karşıt kenarla sabitlenmiş.")
print("  ⚠ Bu kapı KAYNAĞI ölçer. Gerçek kaplama cihazda görülür —")
print("    bu hata zaten oradan, bir ekran görüntüsünün piksellerinden çıktı.")
