#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tanitim_check.py — TANITIM GÖRSELLERİ DENETİMİ.

🔴 NEDEN VAR — ÜÇ AYRI RİSK, ÜÇ AYRI ÖLÇÜM

1 · RAKİBİN CÜMLESİ. Gökberk "We find your perfect +1"i çok beğendi.
    Ben çerçeveyi alıp cümleyi kendimiz yazdık. Ama bu bir KARAR ve
    kararlar kayar: yarın biri "daha iyiydi" deyip rakibin cümlesini
    yapıştırabilir. Bu denetim her pazarlama cümlesini rakibin kayıtlı
    cümleleriyle karşılaştırır — birebir eşleşme ya da çok yüksek
    benzerlik 🔴.

2 · FOTOĞRAF ÜSTÜNDE OKUNURLUK. Bant üstü beyaz metnin kontrastı
    ORTALAMA zeminde değil, EN AÇIK PİKSELDE ölçülür. Uçak penceresinden
    giren gün batımı, bir harfin altında 220 parlaklığa çıkabilir ve o
    tek harf kaybolur. Ölçüm `MURKEPSIZ` kipinde yapılır: gölgeler
    çizilir, mürekkep çizilmez — yani gerçekten ZEMİN ölçülür.

3 · KULLANILMAYAN CÜMLE. `tanitim_metinleri.json`a yazılıp hiçbir
    görselde kullanılmayan cümle, "yazdım demek ki yayında" yanılsaması
    üretir.

🆕 SINIF: "PAZARLAMA VARLIKLARI DA ÜRÜNDÜR — ÖLÇÜLMEYEN BİR SLOGAN,
ÖLÇÜLMEYEN BİR KOD KADAR RİSKLİDİR."

TAVAN 0.
"""
import difflib
import json
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)

ESIK_BENZERLIK = 0.80      # rakibin cümlesine bu kadar benzeme = 🔴
ESIK_KONTRAST = 4.5        # WCAG 1.4.3 gövde metni


def main():
    from PIL import Image, ImageDraw
    from tema_oku import hex_rgb, oran
    import tanitim_uret as TU

    M = json.load(open(os.path.join(KOK, "tanitim_metinleri.json"),
                       encoding="utf-8"))
    kotu = []
    print("=" * 78)
    print("TANITIM GÖRSELİ DENETİMİ")
    print("=" * 78)

    # ── 1 · RAKİBİN CÜMLESİ ────────────────────────────────────────
    print("\n  1 · RAKİBİN CÜMLESİNİ KOPYALADIK MI")
    rakip = [r.strip().lower().rstrip(".") for r in M["rakip_cumleleri"]]
    for ad, c in M["cumleler"].items():
        for dil in ("tr", "en"):
            s = c[dil].strip().lower().rstrip(".")
            for r in rakip:
                b = difflib.SequenceMatcher(None, s, r).ratio()
                if b >= ESIK_BENZERLIK:
                    kotu.append("'%s' (%s) rakibin '%s' cümlesine %%%d benziyor"
                                % (c[dil], ad, r, b * 100))
                    print("    ✗ %-10s %s  ←  rakip %%%d" % (ad, c[dil], b * 100))
    en_yakin = max(
        (difflib.SequenceMatcher(None, c[d].lower().rstrip("."), r).ratio(), c[d], r)
        for c in M["cumleler"].values() for d in ("tr", "en") for r in rakip)
    print("      kayıtlı cümle : %d · rakip cümlesi : %d · en yakın benzerlik : %%%d"
          % (len(M["cumleler"]) * 2, len(rakip), en_yakin[0] * 100))
    print("      en yakın çift : %r  ↔  %r" % (en_yakin[1], en_yakin[2]))
    if en_yakin[0] < ESIK_BENZERLIK:
        print("    ✓ hiçbir cümlemiz rakibin cümlesiyle karışmıyor")

    # ── 2 · KULLANILMAYAN CÜMLE ────────────────────────────────────
    print("\n  2 · HER CÜMLE BİR GÖRSELDE KULLANILIYOR MU")
    kullanilan = set()
    for g in (M["gonderiler"] + M["gonderiler_host"]
              + M["gonderiler_karusel"] + M["gonderiler_genel"]):
        kullanilan.add(g["cumle"])
        kullanilan.add(g["alt"])
    kullanilan |= {"kanca", "site", "urun"}      # web_hero
    bos = [k for k in M["cumleler"] if k not in kullanilan]
    print("      kayıtlı : %d · kullanılan : %d · kullanılmayan : %d"
          % (len(M["cumleler"]), len(kullanilan & set(M["cumleler"])), len(bos)))
    for k in bos:
        kotu.append("'%s' cümlesi hiçbir görselde kullanılmıyor" % k)
        print("    ✗ %s — kayıtta var, görselde yok" % k)
    if not bos:
        print("    ✓ kayıtlı her cümlenin bir yeri var")

    # ── 3 · ÇIKTI ──────────────────────────────────────────────────
    print("\n  3 · ÇIKTI")
    bekle = []
    for g in M["gonderiler"]:
        bekle += [(g["ad"] + ".png", 1080, 1350), (g["ad"] + "_en.png", 1080, 1350)]
    for g in M["gonderiler"][:2]:
        bekle.append(("story_" + g["ad"][3:] + ".png", 1080, 1920))
    bekle += [("web_hero.png", 2400, 1350), ("web_hero_en.png", 2400, 1350),
              ("web_raf.png", 2400, 1000)]
    # v0.42 — host / eğitim gönderileri
    import tanitim_host as TH
    for g in M["gonderiler_host"] + M["gonderiler_genel"]:
        bekle.append((g["ad"] + ".png", 1080, 1350))
        if g["ad"] in TH.EN_LISTESI:
            bekle.append((g["ad"] + "_en.png", 1080, 1350))
    for g in M["gonderiler_karusel"]:
        bekle.append((g["ad"] + ".png", 1080, 1350))
    for ad, w, h in bekle:
        y = os.path.join(TU.CIKTI, ad)
        if not os.path.exists(y):
            kotu.append("%s yok" % ad)
            print("    ✗ %-24s yok" % ad)
            continue
        gw, gh = Image.open(y).size
        ok = (gw, gh) == (w, h)
        if not ok:
            kotu.append("%s ölçüsü %dx%d (beklenen %dx%d)" % (ad, gw, gh, w, h))
        print("    %s %-24s %dx%d" % ("✓" if ok else "✗", ad, gw, gh))

    # ── 4 · FOTOĞRAF ÜSTÜ METİN KONTRASTI (EN KÖTÜ PİKSEL) ─────────
    print("\n  4 · FOTOĞRAF ÜSTÜ METİN — EN KÖTÜ PİKSEL")
    # 🔴 `tanitim_host.py`nin bütün biçimleri metni `TU.golgeli`den
    # geçiriyor — yani ölçüm kipi orada da geçerli. Yeni bir dosya
    # yazarken ölçüm yolunu ATLAMAK, o dosyayı denetimsiz bırakırdı.
    TU.MURKEPSIZ = True
    en_kotu_genel = (99.0, "")
    olculen = 0
    isler = ([("ig:" + g["ad"], lambda g=g: TU.ig(g, "tr")) for g in M["gonderiler"]]
             + [("ig_en:" + g["ad"], lambda g=g: TU.ig(g, "en")) for g in M["gonderiler"]]
             + [("story:" + g["ad"], lambda g=g: TU.story(g)) for g in M["gonderiler"][:2]]
             + [("web_hero", lambda: TU.web_hero("tr")),
                ("web_hero_en", lambda: TU.web_hero("en"))]
             + [("host:" + g["ad"], lambda g=g: TH.BICIM[g["tip"]](g, "tr"))
                for g in M["gonderiler_host"] + M["gonderiler_genel"]]
             + [("karusel:" + g["ad"],
                 lambda g=g, k=k: TH.karusel_slayti(g, k + 1, len(M["gonderiler_karusel"])))
                for k, g in enumerate(M["gonderiler_karusel"])])
    for ad, fn in isler:
        TU.KUTULAR.clear()
        im = fn().convert("RGB")
        px = im.load()
        for x0, y0, s, font, murekkep in TU.KUTULAR:
            # 🔴 İLK ÖLÇÜMÜM YAZININ KUTUSUNU (dikdörtgen) TARIYORDU ve
            # web_hero'da 1.02:1 dedi — çünkü kutunun sağ ucu, metnin
            # BİTTİĞİ yerden sonra duran beyaz telefon ekranına giriyordu.
            # Harfin altında olmayan bir piksel, o harfin zemini değildir.
            # Artık yalnız GLİFİN kapladığı pikseller ölçülüyor.
            #
            # 🆕 SINIF: "METNİN ZEMİNİNİ KUTUSUYLA ÖLÇME — HARFİN
            # MASKESİYLE ÖLÇ; KUTU, YAZININ OLMADIĞI YERİ DE KAPSAR."
            maske = Image.new("L", im.size, 0)
            ImageDraw.Draw(maske).text((x0, y0), s, font=font,
                                       features=TU.OZ, fill=255)
            kutu = maske.getbbox()
            if not kutu:
                continue
            mpx = maske.load()
            en_acik, ep = None, -1
            for yy in range(kutu[1], kutu[3]):
                for xx in range(kutu[0], kutu[2]):
                    if mpx[xx, yy] < 140:
                        continue
                    r, gg, b = px[xx, yy]
                    p = 0.2126 * r + 0.7152 * gg + 0.0722 * b
                    if p > ep:
                        ep, en_acik = p, (r, gg, b)
            if en_acik is None:
                continue
            ornek = s[:28]
            o = oran(hex_rgb(murekkep), en_acik)
            olculen += 1
            if o < en_kotu_genel[0]:
                en_kotu_genel = (o, "%s · %r · zemin #%02X%02X%02X"
                                 % (ad, ornek, *en_acik))
            if o < ESIK_KONTRAST:
                kotu.append("%s · %r → %.2f:1 (en açık zemin #%02X%02X%02X)"
                            % (ad, ornek, o, *en_acik))
    TU.MURKEPSIZ = False
    print("      ölçülen metin kutusu : %d · en kötü : %.2f:1" %
          (olculen, en_kotu_genel[0]))
    print("      en kötü yer : %s" % en_kotu_genel[1])
    if en_kotu_genel[0] >= ESIK_CONTRAST_YAZ():
        print("    ✓ her metin, altındaki EN AÇIK pikselde bile AA geçiyor")

    print()
    if kotu:
        print("🔴 %d BULGU." % len(kotu))
        for k in kotu[:20]:
            print("   · %s" % k)
        if len(kotu) > 20:
            print("   · … %d bulgu daha" % (len(kotu) - 20))
        return 1
    print("✓ Cümleler bizim · hepsi kullanımda · %d görsel · en kötü kontrast %.2f:1"
          % (len(bekle), en_kotu_genel[0]))
    return 0


def ESIK_CONTRAST_YAZ():
    return ESIK_KONTRAST


if __name__ == "__main__":
    sys.exit(main())
