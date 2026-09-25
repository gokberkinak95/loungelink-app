#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · tema_check.py   (26 Ağustos 2026'da doğdu)

════════════════════════════════════════════════════════════════════════
🔴 NEDEN VAR — GÖKBERK GÖZÜYLE GÖRDÜ, HİÇBİR DENETİM GÖRMEDİ
════════════════════════════════════════════════════════════════════════

Gökberk keşif kartının ekran görüntüsünü işaretleyip "başlıklar, rozetler,
metinler temayla uyumlu durmuyor" dedi. Ölçtüm, haklıydı — ama gördüğü şey
"tema" değil, ÜÇ ÖLÇÜLEBİLİR KUSURDU:

  1. Rozet metinlerinin DÖRDÜ DE WCAG AA'nın altındaydı.
     En kötüsü `cost` (ÜCRETLİ) 2.52:1 — yani KURAL MOTORUNUN CEVABI,
     ürünün tek farkı. `palette_check.py` renklerin PALETTEN gelmesini
     denetliyordu; PALETTEN GELİP DE OKUNMAYAN bir rengi göremiyordu.

  2. 33 farklı `borderRadius`. Tipografi ölçeğe, boşluklar 4'ün katına
     bağlıydı; köşeler hiçbir şeye bağlı değildi. Denetlenmeyen tek
     boyut, serbestçe kayan boyut çıktı.

  3. Metnin %75'i `fontWeight: 700`. Her şey kalınsa hiçbir şey kalın
     değildir — vurgu anlamını yitirmiş.

🆕 SINIF: "BİR DÜZELTME KATMANI KURDUKTAN SONRA YAZILAN HER YENİ BİLEŞEN,
O KATMANI ATLAMAYA ADAYDIR. KATMANI KURMAK YETMEZ — SONRAKİLERİ ONA
BAĞLAYAN BİR NÖBETÇİ GEREKİR."

Bu dosya o nöbetçi. Renk paletten geliyor diye geçmiyor: OKUNUYOR MU
diye soruyor.
"""
import os
import re
import tema_oku
import sys
import colorsys

ROOT = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------- yardımcı
def kod_govdesi(s):
    """Yorumları ele. Bu projede bir ölçüm yorumları kod sayınca koca bir
    mimari sonuç yanlış çıkmıştı; aynı tuzağa iki kez düşmeyelim."""
    s = re.sub(r"/\*[\s\S]*?\*/", " ", s)
    s = re.sub(r"(^|[^:])//[^\n]*", r"\1 ", s)
    return s


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _L(p):
    return 0.2126 * _lin(p[0]) + 0.7152 * _lin(p[1]) + 0.0722 * _lin(p[2])


def oran(a, b):
    la, lb = _L(a), _L(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hx(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ustune(src, a, dst):
    return tuple(round(src[i] * a + dst[i] * (1 - a)) for i in range(3))


def rgba_coz(s):
    m = re.match(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)", s.strip())
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3))), float(m.group(4))


# ---------------------------------------------------------------- 1 · ROZET
SURFACE = hx("FFFDF9")   # C.surface — kart
BLOK    = hx("F4F1E9")   # C.surfaceAlt — kart içi blok
ESIK    = 4.5            # rozet metni 8–10,5px → KÜÇÜK METİN


def rozet_denetimi():
    """C.badge'in her tonunda metin, iki zeminde de AA geçiyor mu?

    🔴 Bu denetim, rozetlerin dördü de AA'nın altındayken doğdu. En
    kötüsü `cost` (ÜCRETLİ) 2.52:1'di — yani KURAL MOTORUNUN CEVABI,
    ürünün tek farkı, okunmuyordu. `palette_check.py` renklerin
    PALETTEN gelmesini denetliyordu; paletten gelip de OKUNMAYAN bir
    rengi göremiyordu.

    Rozetin zemini yarı saydam (`rgba(...,0.10)`), yani gerçek zemin
    kartın kendisiyle KARIŞMIŞ hâli. `ustune()` o karışımı hesaplıyor;
    doğrudan rgba'yı okumak yanlış zemin ölçmek olurdu.
    """
    src = open(os.path.join(ROOT, "src", "theme.js"), encoding="utf-8").read()
    govde = kod_govdesi(src)
    mi = re.search(r"C\.badgeInk\s*=\s*\{(.*?)\n\};", govde, re.S)
    mb = re.search(r"C\.badge\s*=\s*\{(.*?)\n\};", govde, re.S)
    if not mi or not mb:
        return [("C.badge / C.badgeInk okunamadı — rozet denetimi körleşti",)]
    murekkep = dict(re.findall(r'(\w+)\s*:\s*"(#[0-9A-Fa-f]{6})"', mi.group(1)))
    zeminler = dict(re.findall(r'(\w+)\s*:\s*\{[^}]*?bg:\s*"(rgba\([^"]+\))"',
                               mb.group(1)))
    ihlal = []
    for ton, renk in murekkep.items():
        rg = zeminler.get(ton)
        if not rg:
            continue
        coz = rgba_coz(rg)
        if not coz:
            continue
        (r, gg, bb), alfa = coz
        for zad, zem in (("kart", SURFACE), ("blok", BLOK)):
            gercek = ustune((r, gg, bb), alfa, zem)
            o = oran(hx(renk), gercek)
            if o < ESIK:
                ihlal.append(("rozet '%s' %s zemininde %.2f:1 (gereken %.1f)"
                              % (ton, zad, o, ESIK),))
    return ihlal


# ---------------------------------------------------------------- 2 · KÖŞE
# Ölçek: R = 10 · 14 · 20 · 26 · 32 · 999. Ölçek dışı DEĞER sayısı
# tavanlanıyor (kullanım sayısı değil): amaç "kaç yerde" değil, "kaç
# ayrı karar" olduğunu sınırlamak.
KOSE_TAVAN = 20
KOSE_DOSYA = ("src", "App.js")
OLCEK = {10, 14, 20, 26, 32, 999}


def kose_denetimi():
    """Ölçek dışı `borderRadius` DEĞERLERİ ve kaç kez kullanıldıkları."""
    from collections import Counter
    say = Counter()
    dosyalar = []
    for kok in KOSE_DOSYA:
        yol = os.path.join(ROOT, kok)
        if os.path.isdir(yol):
            dosyalar += [os.path.join(yol, f) for f in sorted(os.listdir(yol))
                         if f.endswith(".js")]
        elif os.path.exists(yol):
            dosyalar.append(yol)
    for p in dosyalar:
        govde = kod_govdesi(open(p, encoding="utf-8").read())
        for m in re.finditer(r"borderRadius:\s*(\d+(?:\.\d+)?)", govde):
            v = float(m.group(1))
            if v in OLCEK or v <= 5:
                continue
            say[v] += 1
        # R ölçeğinden gelen adlandırılmış kullanımlar (R.md gibi) ölçek içi
    return dict(say)


# ------------------------------------------------------------ 3 · KALINLIK
# "Her şey kalınsa hiçbir şey kalın değildir." Borç tavanı; sıfır hedef
# değil — bu bir ORAN denetimi, ihlal denetimi değil.
# 🔴 v3.6 — 74 → 65. İki şey aynı anda oldu:
#
# (a) Ölü bileşenler arşive alınınca PAYDA küçüldü ve oran %74'ün bir
#     tık üstüne çıktı. Yani tavan, ölü kodu da sayan bir paydaya göre
#     ayarlanmıştı. Bu, `yuzey_check.py`de bir saat önce yaptığım
#     hatanın kardeşi: ORAN TABANLI ÇIRÇIR, PAYDA DEĞİŞTİĞİNDE ANLAMINI
#     DEĞİŞTİRİR.
#
# (b) Tavanı yükseltmek yerine BORCU ÖDEDİM: en küçük iki tipografi
#     basamağında (FS.xs 10.5 · FS.micro 9) eyebrow OLMAYAN 51 metin
#     700'den 600'e indi. Archivo-SemiBold gerçek bir dosya, yani bu
#     sentezlenmiş değil ÇİZİLEN bir ağırlık.
#
#     Kazanç hiyerarşi: artık üç basamak var (400 gövde · 600 destek ·
#     700 başlık). Önce iki vardı ve dipnotlar başlıkla aynı sesle
#     bağırıyordu.
#
# 🆕 SINIF: "ORAN TABANLI BİR ÇIRÇIRDA PAYDA KÜÇÜLÜNCE TAVANI YÜKSELTMEK,
# ÖLÇÜMÜ SUSTURMAKTIR — DOĞRU HAMLE PAYI DÜŞÜRMEKTİR."
KALIN_TAVAN_YUZDE = 65


def kalinlik_denetimi():
    """Kalın (600/700/bold) yazı bildirimi / tüm fontWeight bildirimi."""
    kalin = toplam = 0
    for kok in KOSE_DOSYA:
        yol = os.path.join(ROOT, kok)
        dosyalar = ([os.path.join(yol, f) for f in sorted(os.listdir(yol))
                     if f.endswith(".js")] if os.path.isdir(yol)
                    else ([yol] if os.path.exists(yol) else []))
        for p in dosyalar:
            govde = kod_govdesi(open(p, encoding="utf-8").read())
            for m in re.finditer(r'fontWeight:\s*"(\w+)"', govde):
                toplam += 1
                # 🔴 YENİDEN YAZARKEN `600`Ü DE KALIN SAYDIM VE ORAN
                # %76'DAN %99'A FIRLADI. Eski ölçüm elimde olmasa
                # "borç patlamış" derdim. `600` yarı-kalın: vurgu
                # hiyerarşisinde ORTA basamak, kalının kendisi değil —
                # onu kalın saymak, denetimin ölçtüğü şeyi değiştirir.
                # Yeni sayı (407/537 = %76) eski ölçümle (406/535 = %76)
                # birebir örtüştü: yeniden yazımın DOĞRULAMASI bu oldu.
                #
                # 🆕 SINIF: "SİLİNMİŞ BİR ÖLÇÜMÜ YENİDEN YAZARKEN, ESKİ
                # SAYIYI TUTTURAMIYORSAN AYNI ŞEYİ ÖLÇMÜYORSUN —
                # 'YAKLAŞIK AYNI' DİYE BİR DOĞRULAMA YOKTUR."
                if m.group(1) in ("700", "800", "900", "bold"):
                    kalin += 1
    return kalin, toplam


# ---------------------------------------------------------------- 4 · YÜZEY
def yuzey_denetimi():
    """`kurYuzey()` tablosundaki her zemin+metin çifti, İKİ TEMADA da
    eşiğini tutuyor mu?

    🔴 v3.2 · BU FONKSİYONU BİR KOD DEĞİŞTİRİCİYLE YENİDEN YAZARKEN
    DOSYANIN ÜÇTE BİRİNİ SİLDİM. `g.index(satır)` ile hesapladığım
    başlangıç noktası, aynı satırın DAHA ÖNCEKİ bir kopyasına denk
    geldi (`src = open(...)` üç fonksiyonda da aynıydı) ve aradaki
    `rozet_denetimi` · `kose_denetimi` · `kalinlik_denetimi` yok oldu.
    Yedeği yoktu; üçü de yeniden yazıldı ve tavanları yeniden ölçüldü.

    🆕 SINIF: "BİR METNİ KONUMLA KESECEKSEN, KONUMU BENZERSİZ BİR
    İMDEN AL — 'İLK EŞLEŞME' BİR KONUM DEĞİL, BİR TAHMİNDİR."
    """
    src = open(os.path.join(ROOT, "src", "theme.js"), encoding="utf-8").read()
    govde = kod_govdesi(src)
    # 🔴 v3.2 — TABLO ARTIK BİR FONKSİYONUN İÇİNDE.
    # `C.yuzey` düz bir nesne değil, `kurYuzey()`in dönüşü: tema
    # değiştiğinde yeniden kurulabilmesi için. Ayrıştırıcı bunu
    # bilmiyordu ve "tablo yok — denetim körleşti" dedi. Doğru davranış:
    # körleştiğini SÖYLEMEK (sessizce geçmemek). Sonra ayrıştırıcı
    # düzeltildi.
    blok = re.search(r"function kurYuzey\(\)\s*\{(.*?)\n\}", govde, re.S)
    if not blok:
        blok = re.search(r"C\.yuzey\s*=\s*\{(.*?)\n\};", govde, re.S)
    if not blok:
        return [("C.yuzey tablosu yok — yüzey denetimi körleşti",)], 0

    # ── PALET ÇÖZÜMÜ — KAPSAM FARKINDA ──────────────────────────────
    # 🔴 26 AĞUSTOS · İKİNCİ KIRILMA. theme.js'e KOYU tema paleti
    # eklendiği an bu denetim yanlış sonuç verdi: ayrıştırıcı dosyadaki
    # HER `ad: "#hex"` satırını topluyordu ve KOYU'nun anahtarları
    # C'ninkilerin ÜSTÜNE yazıyordu.
    #
    # 🆕 SINIF: "DÜZ METİN TARAYAN BİR AYRIŞTIRICI, DOSYAYA İKİNCİ BİR
    # NESNE EKLENDİĞİ GÜN SESSİZCE YANLIŞ CEVAP VERMEYE BAŞLAR."
    # Ayrıştırma tek dosyada: `tema_oku.palet`.
    palet = tema_oku.palet("C")
    palet_koyu = tema_oku.palet("KOYU")

    # Fonksiyon içindeki yerel sabitler (`const btnMetin = "#FFFFFF";`)
    yerel = dict(re.findall(r'const\s+(\w+)\s*=\s*"(#[0-9A-Fa-f]{3,8})"', blok.group(1)))

    def coz(ifade, pl):
        ifade = ifade.strip().strip(",")
        if ifade.startswith('"'):
            return ifade.strip('"')
        if ifade in yerel:
            return yerel[ifade]
        return pl.get(ifade.split(".")[-1])

    satir = re.findall(
        r"(\w+)\s*:\s*\{\s*zemin:\s*([^,]+),\s*metin:\s*([^,]+),\s*tur:\s*\"(\w+)\"",
        blok.group(1))
    if not satir:
        return [("C.yuzey içinde hiç satır okunamadı — ayrıştırıcı bozuk",)], 0

    # ── İKİ TEMA, AYNI TABLO, AYRI PALET ────────────────────────────
    # 🔴 ÖNCEKİ HÂLDE KOYU TEMA İÇİN AYRI BİR EŞLEME TABLOSU (`koyu_esler`)
    # ELLE YAZILIYDI ve 21 yüzeyden yalnız 11'ini kapsıyordu. Yani koyu
    # temanın yarısı hiç ölçülmüyordu — üstelik denetim "koyu tema
    # denetlendi" diyordu. Artık AYNI tablo iki palette çözülüyor:
    # eksik eşleme diye bir şey kalmıyor.
    #
    # 🆕 SINIF: "İKİNCİ BİR TEMAYI ELLE YAZILMIŞ BİR EŞLEME TABLOSUYLA
    # DENETLERSEN, DENETİMİN KAPSAMI TABLONUN UZUNLUĞU KADARDIR —
    # ÜRÜNÜN KADAR DEĞİL."
    ihlal = []
    sayi = 0
    for etiket, pl in (("", palet), ("KOYU ", {**palet, **palet_koyu})):
        if not pl:
            ihlal.append(("%spalet okunamadı — o tema hiç denetlenmiyor" % etiket,))
            continue
        for ad, z, m, tur in satir:
            zc, mc = coz(z, pl), coz(m, pl)
            if not zc or not mc:
                ihlal.append(("%syüzey '%s': renk çözülemedi (%s / %s)"
                              % (etiket, ad, z, m),))
                continue
            if not zc.startswith("#") or not mc.startswith("#"):
                continue          # rgba — altındaki gerçek zemin bilinmiyor
            esik = 4.5 if tur == "metin" else 3.0
            o = oran(hx(zc), hx(mc))
            sayi += 1
            if o < esik:
                ihlal.append(("%syüzey '%s' %.2f:1 (gereken %s) — zemin %s · metin %s"
                              % (etiket, ad, o, esik, zc, mc),))

    # ── KOYU ROZETLER ───────────────────────────────────────────────
    mk = re.search(r"KOYU\.badgeInk\s*=\s*\{(.*?)\n\};", govde, re.S)
    if mk:
        # 🔴 11 EYLÜL — BU SÖZLÜK BİR KOPYAYDI VE ESKİMİŞTİ.
        # Rozet zeminleri `KOYU.badge[ton].bg` içinde rgba() olarak yazılı;
        # burada ikinci bir kopya (eski mürekkep değerleri) elle tutuluyordu.
        # `badgeInk` 11 Eylül'de değişince denetim YENİ mürekkebi ESKİ zemine
        # karşı ölçtü ve olmayan bir ihlal raporladı.
        # 🆕 SINIF: "BİR DENETİM, ÖLÇTÜĞÜ DEĞERİN KOPYASINI KENDİ İÇİNDE
        # TUTUYORSA, ÖLÇTÜĞÜ ŞEY ÜRÜN DEĞİL KENDİ HAFIZASIDIR."
        kart = hx(palet_koyu.get("surface", "#251E22"))
        mbg = re.search(r"KOYU\.badge\s*=\s*\{(.*?)\n\};", govde, re.S)
        zeminler = {}
        if mbg:
            for ton2, r2, g2, b2, a2 in re.findall(
                    r"(\w+)\s*:\s*\{[^}]*?bg:\s*\"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)\"",
                    mbg.group(1)):
                zeminler[ton2] = ustune((int(r2), int(g2), int(b2)), float(a2), kart)
        if not zeminler:
            ihlal.append(("KOYU.badge zeminleri okunamadı — rozet ölçümü körleşti",))
        for ton, renk in re.findall(r"(\w+)\s*:\s*\"(#[0-9A-Fa-f]{6})\"", mk.group(1)):
            if ton not in zeminler:
                continue
            zem = zeminler[ton]
            o = oran(hx(renk), zem)
            sayi += 1
            if o < 4.5:
                ihlal.append(("KOYU rozet '%s' %.2f:1 — metin %s" % (ton, o, renk),))
    else:
        ihlal.append(("KOYU.badgeInk yok — koyu temada rozetler ölçülemedi",))
    return ihlal, sayi


# ---------------------------------------------------------------- ana
def main():
    print("=" * 72)
    print("TEMA DENETİMİ — renk paletten geliyor diye OKUNUYOR demek değildir")
    print("=" * 72)
    sorun = 0

    # 1
    rz = rozet_denetimi()
    if rz:
        for (msg,) in rz:
            print(f"  ✗ {msg}")
        print(f"\n  {len(rz)} rozet ihlali. Rozet metni KÜÇÜK METİNDİR: eşik 4,5:1.")
        print("  Rengi değiştirme — AÇIKLIĞINI düşür. Ton ve doygunluk korunursa")
        print("  rengin anlamı (yeşil=hakkın var) aynı kalır, yalnız okunur olur.")
        sorun += 1
    else:
        print("  ✓ rozet tonlarının hepsi kart ve blok zemininde AA geçiyor")

    # 2
    ks = kose_denetimi()
    if len(ks) > KOSE_TAVAN:
        print(f"\n  ✗ KÖŞE: {len(ks)} ölçek dışı değer (tavan {KOSE_TAVAN})")
        for v, n in sorted(ks.items(), key=lambda x: -x[1])[:8]:
            print(f"      borderRadius: {v:g}  — {n} kez")
        print("  Yeni köşe gerekiyorsa src/theme.js'teki R ölçeğine EKLE.")
        sorun += 1
    else:
        toplam = sum(ks.values())
        print(f"  ✓ köşe borcu büyümedi ({len(ks)} ölçek dışı değer / "
              f"{toplam} kullanım · tavan {KOSE_TAVAN})")
        if len(ks) < KOSE_TAVAN:
            print(f"      ↓ borç azaldı — tema_check.py'de KOSE_TAVAN = {len(ks)} yap")

    # 4
    sonuc = yuzey_denetimi()
    if isinstance(sonuc, list):
        for (msg,) in sonuc:
            print(f"  ✗ {msg}")
        sorun += 1
    else:
        yz, adet = sonuc
        if yz:
            for (msg,) in yz:
                print(f"  ✗ {msg}")
            print("\n  Yeni bir düğme/kutu eklerken C.yuzey'e satır ekle —")
            print("  eklemezsen denetim değil, KULLANICI bulur.")
            sorun += 1
        else:
            print(f"  ✓ {adet} yüzeyin hepsi (zemin+metin) eşiğini tutuyor")

    # 3
    kalin, toplam = kalinlik_denetimi()
    yuzde = (100 * kalin / toplam) if toplam else 0
    if yuzde > KALIN_TAVAN_YUZDE:
        print(f"\n  ✗ KALINLIK: metnin %{yuzde:.0f}'i kalın "
              f"(tavan %{KALIN_TAVAN_YUZDE}) — {kalin}/{toplam}")
        print("  Her şey kalınsa hiçbir şey kalın değildir.")
        sorun += 1
    else:
        print(f"  ✓ kalınlık borcu büyümedi (%{yuzde:.0f} · {kalin}/{toplam} "
              f"· tavan %{KALIN_TAVAN_YUZDE})")
        if yuzde < KALIN_TAVAN_YUZDE - 1:
            print(f"      ↓ borç azaldı — KALIN_TAVAN_YUZDE = {int(yuzde)+1} yap")

    print()
    if sorun:
        print(f"✗ {sorun} tema sorunu.")
        return 1
    print("✓ tema denetimi temiz")
    return 0


if __name__ == "__main__":
    sys.exit(main())
