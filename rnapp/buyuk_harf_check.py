#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
buyuk_harf_check.py — TÜRKÇE BÜYÜK HARF. NOKTASIZ I NÖBETÇİSİ.

🔴 NEDEN VAR — AYNI HATAYI İKİNCİ KEZ YAPTIM VE ARADAN DOKUZ GÜN GEÇTİ.

3 Eylül'de `ui.js`in içine şunu yazmışım:

    🔴 `textTransform: "uppercase"` JS'in yerel-bağımsız toUpperCase'ini
       kullanır: "Selin" → "SELIN" (noktasız I). Türkçe büyük harf `BUYUK` ile.

12 Eylül gecesi geçiş kartını yazarken `textTransform: "uppercase"`
kullandım ve cüzdan ekranında birebir aynı kusur çıktı:

        GÜVENILIR HOST        (olması gereken: GÜVENİLİR HOST)
        KREDI                 (olması gereken: KREDİ)

Sonra ölçtüm: üründe bu kalıptan **14 tane** vardı ve hepsi çeviri
sözlüğünden ya da veritabanından gelen METNİ büyütüyordu. Yani kusur
benim yeni kartımda değil, ÜRÜNÜN TAMAMINDAYDI — ve bunu hiçbir
nöbetçi ölçmüyordu.

Türkçede "i"nin büyüğü "İ", "ı"nın büyüğü "I". `String.toUpperCase()`
yerel bilmez; `toLocaleUpperCase("tr-TR")` bilir. `i18n.js`teki `BUYUK`
tam olarak bunu yapıyor ve dile göre doğru olanı seçiyor (İngilizce
arayüzde düz `toUpperCase`).

Bu, bir yazım hatası değil bir MARKA kusuru: ürün Türkiye'de bir
havalimanı ürünü ve büyük harfli etiketler ekranın en görünür
yerlerinde (rozetler, kart etiketleri, bant üstbilgisi).

🆕 SINIF: "BİR DERSİ BİR DOSYANIN İÇİNE YORUM OLARAK YAZMAK O DERSİ
KORUMAZ — YORUM YALNIZ ONU OKUYANI UYARIR, NÖBETÇİ İSE YAZMAYANI DA."

NE ÖLÇÜYOR: kaynakta `textTransform: "uppercase"` geçen her yer.
Tavan 0. Doğrusu her zaman aynı: stilden kaldır, metni `BUYUK(...)`
ile sar.

⚠️ YORUMLAR SAYILMIYOR. Bu dosyanın kendisi ve `ui.js`teki 3 Eylül
dersi ifadeyi YORUM içinde geçiriyor; bir nöbetçinin kendi
açıklamasını ihlal sayması, `taklit_yuzey_check.py`de bir kez
yaşadığım yanlış alarmın aynısı olurdu.
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
KAYNAK = ["App.js"] + ["src/" + f for f in sorted(os.listdir(os.path.join(KOK, "src")))
                       if f.endswith(".js")]
TAVAN = 0


def _yorumsuz(s):
    s = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), s, flags=re.S)
    s = re.sub(r"(?m)^\s*//.*$", "", s)
    return s


def main():
    print("=" * 72)
    print("TÜRKÇE BÜYÜK HARF — `textTransform: \"uppercase\"` noktasız I üretir")
    print("=" * 72)
    bulgu = []
    for f in KAYNAK:
        s = _yorumsuz(open(os.path.join(KOK, f), encoding="utf-8").read())
        for m in re.finditer(r'textTransform:\s*"uppercase"', s):
            bulgu.append((f, s[:m.start()].count("\n") + 1))

    # Karşı ölçüm: `BUYUK(` kaç yerde kullanılıyor — kalıbın gerçekten
    # yerini aldığını göstermek için (sıfır ihlal + sıfır BUYUK, kalıbın
    # hiç kullanılmadığı anlamına da gelebilirdi).
    kullanim = 0
    for f in KAYNAK:
        kullanim += len(re.findall(r"\bBUYUK\(", _yorumsuz(
            open(os.path.join(KOK, f), encoding="utf-8").read())))

    print("  BUYUK(...) çağrısı        : %d yerde" % kullanim)
    print("  textTransform uppercase   : %d  (tavan %d)" % (len(bulgu), TAVAN))
    for f, satir in bulgu:
        print("     ✗ %s:%d" % (f, satir))

    if len(bulgu) > TAVAN:
        print("\n🔴 Stilden kaldır, metni `BUYUK(...)` ile sar.")
        print("   'Güvenilir' → toUpperCase: GÜVENILIR · BUYUK: GÜVENİLİR")
        return 1
    print("\n✓ Büyük harf her yerde Türkçe kurallarıyla üretiliyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
