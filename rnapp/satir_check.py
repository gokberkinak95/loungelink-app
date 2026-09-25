# -*- coding: utf-8 -*-
"""
LoungeLink · satir_check.py  —  55. DENETİM
İNİCİ HARF KIRPILMASI (ğ ç ş y p g) — SATIR YÜKSEKLİĞİ KAPISI

🔴 NEDEN VAR — GÖKBERK ÖLÇTÜ, BEN ÖLÇMEMİŞTİM (12 Eylül, md.5)
"bağlantılarım başlığı headerda kesik gibi alttan (bunu app genelinde
kontrol et başlığın alttan kesik olması)"

Doğruydu. Bant başlığı `fontSize: 40 / lineHeight: 42` ile çiziliyordu;
bu oran (1.04) tasarımın CSS'inden BİREBİR alınmıştı. Tarayıcıda 1.04
kırpmaz — inici harf satır kutusundan taşar ve yine çizilir. React
Native'de ve `numberOfLines` ile KLAMPLANMIŞ bir kutuda ise taşan kısım
KESİLİR. Aynı sayı, iki motorda iki farklı şey.

NASIL ÖLÇÜYOR — VARSAYIMSIZ
  · Fontların kendi tablolarından (assets/fonts/*.ttf, fonttools) hhea
    ascender/descender ve TÜRKÇE inici harflerin (ğ ç ş ı y p g) gerçek
    ymin/ymax değerleri okunur. Sayılar burada sabit YAZILMAZ.
  · Satır kutusunda taban çizgisi:  (L − (A+D))/2 + A
    Tabanın altında kalan yer:      L/2 − (A−D)/2
    Kırpılmama koşulu:              L ≥ 2·|ymin| + A − D
                                    L ≥ 2·ymax  − A + D
  · Yalnız KLAMPLI metinler denetlenir (`numberOfLines`, `<GolgeliMetin
    satir=`), çünkü kırpma yalnız orada olur. Klampsız metinde inici harf
    taşar ama görünür.

🆕 SINIF: "TASARIMDAN ALINAN BİR SAYI, ALINDIĞI MOTORUN KURALIYLA
BİRLİKTE GELİR."
"""
import os, re, sys, glob

TAVAN = 0   # tek bir kırpılan başlık bile kabul edilmez

# ── 1 · font metrikleri ────────────────────────────────────────────────
try:
    from fontTools.ttLib import TTFont
    from fontTools.pens.boundsPen import BoundsPen
except ImportError:
    print("satir_check: fonttools yok — pip install fonttools")
    sys.exit(0)

TURKCE_INICI = "ğçşypgjqĞÇŞİÖÜ"

def olc(yol):
    f = TTFont(yol)
    upm = f["head"].unitsPerEm
    A = f["hhea"].ascent / upm
    D = -f["hhea"].descent / upm
    cmap, gs = f.getBestCmap(), f.getGlyphSet()
    ymin, ymax = 0.0, 0.0
    for ch in TURKCE_INICI:
        gn = cmap.get(ord(ch))
        if not gn:
            continue
        bp = BoundsPen(gs)
        gs[gn].draw(bp)
        if bp.bounds:
            ymin = min(ymin, bp.bounds[1] / upm)
            ymax = max(ymax, bp.bounds[3] / upm)
    return max(2 * abs(ymin) + A - D, 2 * ymax - A + D)

AILE_DOSYA = {
    "sans":  "assets/fonts/PlusJakartaSans-Bold.ttf",
    "serif": "assets/fonts/CormorantGaramond-Bold.ttf",
    "mono":  "assets/fonts/JetBrainsMono-SemiBold.ttf",
}
ORAN = {a: round(olc(p), 3) for a, p in AILE_DOSYA.items() if os.path.exists(p)}

# ── 2 · theme.js'teki SATIR_ORAN tablosu bu ölçümle aynı mı? ───────────
tema = open("src/theme.js", encoding="utf-8").read()
m = re.search(r"SATIR_ORAN\s*=\s*\{([^}]*)\}", tema)
beyan = {}
if m:
    for k, v in re.findall(r"(\w+):\s*([\d.]+)", m.group(1)):
        beyan[k] = float(v)

# ── 3 · punto ölçeği ───────────────────────────────────────────────────
FS = {}
for ad, deg in re.findall(r"(\w+):\s*\{\s*fontSize:\s*([\d.]+)", tema):
    FS[ad] = float(deg)

def sayi(ifade):
    x = ifade.strip()
    m = re.fullmatch(r"(\d+(?:\.\d+)?)", x)
    if m: return float(m.group(1))
    m = re.fullmatch(r"SATIR\(FS\.(\w+)(?:\s*,\s*\"(\w+)\")?\)", x)
    if m and m.group(1) in FS:
        a = m.group(2) or "sans"
        return FS[m.group(1)] * ORAN.get(a, 1.29)      # tanım gereği yeterli
    m = re.fullmatch(r"Math\.round\(FS\.(\w+)\s*\*\s*(\d+(?:\.\d+)?)\)", x)
    if m and m.group(1) in FS: return round(FS[m.group(1)] * float(m.group(2)))
    m = re.fullmatch(r"FS\.(\w+)\s*\*\s*(\d+(?:\.\d+)?)", x)
    if m and m.group(1) in FS: return FS[m.group(1)] * float(m.group(2))
    m = re.fullmatch(r"FS\.(\w+)", x)
    if m and m.group(1) in FS: return FS[m.group(1)]
    m = re.fullmatch(r"SATIR\(FS\.(\w+)\s*\+\s*(\d+)\)", x)
    if m and m.group(1) in FS: return (FS[m.group(1)] + float(m.group(2))) * ORAN["sans"]
    m = re.fullmatch(r"FS\.(\w+)\s*\+\s*(\d+(?:\.\d+)?)", x)
    if m and m.group(1) in FS: return FS[m.group(1)] + float(m.group(2))
    m = re.fullmatch(r"FS\.(\w+)\s*-\s*(\d+(?:\.\d+)?)", x)
    if m and m.group(1) in FS: return FS[m.group(1)] - float(m.group(2))
    return None

# ── 4 · klamplı metinlerin style bloklarını çıkar ──────────────────────
KLAMP = re.compile(r"numberOfLines=\{[^}]*\}|<GolgeliMetin\s+satir=")

def style_blogu(s, i):
    """i konumundan sonraki ilk `style={{ ... }}` bloğunu, süslü parantez
    sayarak döndürür. Başka bir `<` etiketine girerse vazgeçer."""
    j = s.find("style={{", i)
    if j < 0 or j - i > 400: return None
    if "<" in s[i + 1:j].replace("numberOfLines", ""):
        # araya başka bir etiket girdiyse bu style o etikete aittir
        if re.search(r"<[A-Za-z]", s[i + 1:j]): return None
    k = j + len("style={{"); derinlik = 1
    while k < len(s) and derinlik:
        if s[k] == "{": derinlik += 1
        elif s[k] == "}": derinlik -= 1
        k += 1
    return s[j:k]

bulgu = []
for kok, _, dosyalar in os.walk("src"):
    for d in sorted(dosyalar):
        if not d.endswith(".js"): continue
        yol = os.path.join(kok, d)
        s = open(yol, encoding="utf-8").read()
        for m in KLAMP.finditer(s):
            blok = style_blogu(s, m.start())
            if not blok: continue
            mfs = re.search(r"fontSize:\s*([^,}\n]+)", blok)
            mlh = re.search(r"lineHeight:\s*([^,}\n]+)", blok)
            if not mfs or not mlh: continue       # lineHeight yoksa font doğalını kullanır
            fs, lh = sayi(mfs.group(1)), sayi(mlh.group(1))
            if fs is None or lh is None: continue
            aile = "serif" if "serifGosterim" in blok or "F.serif" in blok else "sans"
            esik = ORAN.get(aile, 1.29)
            if lh / fs < esik - 1e-9:
                satir = s[:m.start()].count("\n") + 1
                bulgu.append((yol, satir, aile, fs, lh, round(lh / fs, 3), int(fs * esik + 0.999)))

# ── 5 · rapor ─────────────────────────────────────────────────────────
print("satir_check · ölçülen kırpılma eşikleri (fonttools):")
for a, v in ORAN.items():
    b = beyan.get(a)
    isaret = "✓" if b is not None and abs(b - v) < 0.006 else "✗"
    print(f"  {isaret} {a:6} gereken {v:.3f} em · theme.js SATIR_ORAN = {b}")

sapan = [a for a, v in ORAN.items() if beyan.get(a) is None or abs(beyan[a] - v) >= 0.006]
if sapan:
    print(f"  ✗ theme.js SATIR_ORAN ölçümle uyuşmuyor: {sapan}")

if bulgu:
    print(f"\n✗ KLAMPLI METİNDE İNİCİ HARF KIRPILIYOR — {len(bulgu)} yer:")
    for y, n, a, fs, lh, o, g in bulgu:
        print(f"   {y}:{n}  {a} fs={fs} lh={lh} (oran {o}) → en az {g} olmalı")
else:
    print("\n✓ klamplı metinlerin tamamında inici harf sığıyor")

hata = len(bulgu) + len(sapan)
if hata > TAVAN:
    sys.exit(1)
