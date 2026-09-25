#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
telif_check.py — UYGULAMADA DAĞITILAN HER GÖRSELİN LİSANSI BELLİ Mİ?

🔴 NEDEN VAR
`ui_onerisi/pencere.jpg` aylardır tasarım klasöründeydi ve orada durduğu
sürece kimseye dağıtılmıyordu. Bugün `assets/bant.jpg` olarak uygulamaya
girdi — yani artık APK'nın içinde, her kullanıcının telefonunda.

Bir varlığı tasarım klasöründen ürüne taşımak, onu bir REFERANSTAN bir
YÜKÜMLÜLÜĞE çevirir. Ve yükümlülükler not defterinde değil denetimde
durmalı; not defterindeki unutulur.

🆕 SINIF: "AÇIK BİR YÜKÜMLÜLÜK VARKEN YEŞİL YANAN BİR DENETİM ZİNCİRİ
YALAN SÖYLER — ONU KIRMIZI TUTMAK, HATIRLATMANIN TEK GÜVENİLİR BİÇİMİDİR."

NE YAPAR
  · assets/ altındaki her görseli listeler
  · TELIF.md tablosunda karşılığını arar
  · tabloda olmayan → 🔴 (bilinmeyen varlık, hiç düşünülmemiş)
  · tabloda "BELİRSİZ" → 🔴 (biliniyor ama çözülmemiş)
  · ikisi de yoksa yeşil

Bu denetim, çözülene kadar KIRMIZI KALIR ve bu bir kusur değil işlevdir.
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(KOK, "assets")
DEFTER = os.path.join(ASSETS, "TELIF.md")
UZANTI = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".ttf", ".otf")


def defter():
    if not os.path.exists(DEFTER):
        return None
    kayit = {}
    for satir in open(DEFTER, encoding="utf-8"):
        m = re.match(r"\s*\|\s*`([^`]+)`\s*\|([^|]*)\|([^|]*)\|([^|]*)\|", satir)
        if m:
            ad, kaynak, lisans, durum = (x.strip() for x in m.groups())
            kayit[ad] = {"kaynak": kaynak, "lisans": lisans, "durum": durum}
    return kayit


def varliklar():
    out = []
    for kok, _d, dosyalar in os.walk(ASSETS):
        for d in dosyalar:
            if d.lower().endswith(UZANTI):
                rel = os.path.relpath(os.path.join(kok, d), ASSETS).replace(os.sep, "/")
                out.append(rel)
    return sorted(out)


def eslesir(ad, anahtarlar):
    """`fonts/Archivo-Bold.ttf` → `fonts/Archivo-*.ttf` kalıbıyla eşleşir."""
    if ad in anahtarlar:
        return ad
    for k in anahtarlar:
        if "*" in k:
            desen = "^" + re.escape(k).replace(r"\*", ".*") + "$"
            if re.match(desen, ad):
                return k
    return None


def main():
    kayit = defter()
    if kayit is None:
        print("🔴 assets/TELIF.md YOK — hangi görselin lisansı var bilinmiyor.")
        return 1
    bilinmeyen, acik, kabul, tamam = [], [], [], 0
    for ad in varliklar():
        k = eslesir(ad, kayit.keys())
        if not k:
            bilinmeyen.append(ad)
            continue
        d = kayit[k]
        durum = d["durum"].upper()
        if "KABUL EDİLDİ" in durum:
            # 🔴 ÜÇÜNCÜ DURUM: KABUL EDİLMİŞ RİSK.
            # İlk hâlde iki durum vardı — net ya da açık. Gökberk bant
            # fotoğrafının riskini bilerek kabul edince ikisi de doğru
            # olmadı: "net" değil (lisans hâlâ bilinmiyor), "açık" da
            # değil (karar verildi). Bu maddeyi denetimden ÇIKARMAK ise
            # en kötüsü olurdu — kabul edilmiş bir risk, unutulmuş bir
            # riskten yalnızca kayıtla ayrılır.
            #
            # 🆕 SINIF: "BİR RİSKİ KABUL ETMEK ONU SİLMEK DEĞİLDİR —
            # DENETİMDEN ÇIKARILAN RİSK, KARAR VERİLMİŞ DEĞİL UNUTULMUŞ
            # SAYILIR."
            kabul.append((ad, d["durum"]))
        elif "BELİRSİZ" in d["lisans"].upper() or "AÇIK" in durum:
            acik.append((ad, d["kaynak"]))
        else:
            tamam += 1

    print("=" * 72)
    print("TELİF DENETİMİ — uygulamada dağıtılan görsellerin lisansı")
    print("=" * 72)
    print("  varlık        : %d" % (tamam + len(acik) + len(kabul) + len(bilinmeyen)))
    print("  lisansı net   : %d" % tamam)
    print("  kabul edilmiş risk: %d" % len(kabul))
    print("  AÇIK madde    : %d" % len(acik))
    print("  deftere hiç girmemiş: %d" % len(bilinmeyen))
    for ad in bilinmeyen:
        print("    🔴 %-28s TELIF.md'de yok — kaynağı hiç sorulmamış" % ad)
    for ad, durum in kabul:
        print("    ⚠️  %-28s %s" % (ad, durum[:52]))
    for ad, kaynak in acik:
        print("    🔴 %-28s %s" % (ad, kaynak[:44]))
    print()
    if bilinmeyen or acik:
        print("🔴 Mağazaya çıkmadan çözülmesi gerekiyor. Seçenekler assets/TELIF.md'de.")
        print("   Bu denetim ÇÖZÜLENE KADAR kırmızı kalacak — bilinçli.")
        return 1
    if kabul:
        print("⚠️  %d kabul edilmiş risk var — engellemiyor ama listede duruyor." % len(kabul))
        print("   Lisanslı eşdeğerler assets/TELIF.md'de hazır; fikir değişirse")
        print("   tek yapılacak iş görseli değiştirip kırpmayı yeniden aramak.")
        return 0
    print("✓ Dağıtılan her görselin lisansı defterde net.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
