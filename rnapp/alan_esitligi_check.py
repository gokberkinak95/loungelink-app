#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""alan_esitligi_check.py — YARATMA FORMU ile DÜZENLEME FORMU AYNI MI?

🔴 NEDEN VAR (24 Agustos 2026, Gokberk madde 14):
   "ilan duzenle sayfasindaki alanlarin, musaitlik ekle sayfasindaki
    alanlar ile birebir ayni olmasi lazim."

   Olctum ve fark buyuktu:
     Musaitlik Ekle (HostAvailability) : havalimani · salon · havayolu ·
       kabin · charter · tarih · saat · ucus · slot · gorunurluk
     Ilan Duzenle  (EditAvailability)  : tarih · saat · slot · ucus
   Yani host bir ilani ACARKEN sordugumuz sorularin YARISINI DUZENLERKEN
   soramiyordu — ve eksik olanlar (havayolu, kabin, charter) tam olarak
   KURAL MOTORUNUN karar girdileri. Tasiyicisi yanlis girilmis bir ilan
   duzeltilemiyordu; tek care silip yeniden acmakti, o da bekleyen
   basvurulari cope atiyordu.

   SEBEP YAPISAL: iki form AYRI yazildi. Yeni alanlar her zaman YARATMA
   tarafina eklenir (once orasi yazilir), duzenleme tarafi geride kalir.

🆕 SINIF: "BİR NESNEYİ YARATAN FORM İLE DÜZENLEYEN FORM AYRI YAZILIRSA,
DÜZENLEME FORMU HER ZAMAN GERİDE KALIR."

   Alanlari elle esitlemek bu turu cozer, SINIFI cozmez: bir sonraki
   ozellikte yine ayrilirlar. Bu nobetci sinifi kapatiyor.

NASIL OLCUYOR:
   Iki bilesenin govdesinden ALAN IMLERI cikariliyor. Bir alan imi =
   ekranda o alanin varligini kanitlayan tek bir kod izi (bilesen adi ya
   da i18n etiketi). Metin benzerligine degil, ALANIN VARLIGINA bakiyor.

   ⚠️ KAPSAM DURUSTLUGU: bu denetim "iki ekranda ayni alan VAR mi" diye
   sorar; "ayni gorunuyor mu" diye SORMAZ. Gorsel esitlik bu denetimin
   kapsaminda degil ve oyle oldugunu iddia etmiyorum.
"""
import os
import re
import sys
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "src" / "screens.js"

# Alan imleri: (alan adi, o alani kanitlayan desen)
# Desenler BILESEN ADI ya da i18n ANAHTARI — ikisi de "bu alan ekranda"
# demenin en dogrudan yolu.
ALANLAR = [
    ("havalimani",  r"AirportPicker|t\.airport\b"),
    ("salon",       r"LoungePicker"),
    ("havayolu",    r"CarrierPicker"),
    ("kabin",       r"t\.cabinTitle"),
    ("charter",     r"t\.charterQ"),
    ("tarih",       r"DateInput"),
    ("saat",        r"TimeInput"),
    ("ucus",        r"FlightField"),
    ("kontenjan",   r"t\.haGuestSlots"),
    ("gorunurluk",  r"t\.haVisibility|visOpts\("),
    ("guven_esigi", r"t\.minTrustLabel"),
    ("vaat_kutusu", r"<PromiseBox"),
]

# Bilerek TEK TARAFTA olanlar — her birinin gerekcesi var.
TEK_TARAFLI = {
    # alan : (hangi ekranda yok, gerekce)
}


def govde(metin: str, ad: str):
    """`export function <ad>(` ile bir sonraki `\\nexport function` arasi."""
    m = re.search(r"export function " + ad + r"\s*\(", metin)
    if not m:
        return None
    son = metin.find("\nexport function ", m.end())
    return metin[m.start(): son if son > 0 else len(metin)]


# ══════════════════════════════════════════════════════════════════════════
# 🔴 v3.4 — BU NOBETCI BIR CIFTE KORDU VE HATA TAM ORADA YASADI.
#
# Gokberk (28 Agu): "seyahat duzenle ekrani seyahat ekle ile birebir ayni
# olmali ki istedigim alani duzenleyebileyim."
#
# Bu dosya ILAN cifti icin yazilmisti ve gorevini yapiyordu. Ama SEYAHAT
# cifti hic olculmuyordu: `AddVisit` screens.js'te, `EditTrip`
# ekranlar_yalin.js'teydi ve bu betik YALNIZ screens.js'i okuyordu.
#
# Sonuc: kod tabani dersi yaziyordu ("ayri yazilan duzenleme formu her
# zaman geride kalir"), nobetcisi de vardi — ve ders yalnizca nobetcinin
# BAKTIGI dosyada geceriydi. Seyahat duzenleme dort duz metin kutusu
# olarak kaldi ve VARIS alani hic cizilmedi.
#
# 🆕 SINIF: "BIR DERSIN NOBETCISINI TEK BIR ORNEGE BAGLARSAN, AYNI HATA
# IKINCI ORNEKTE SESSIZCE YASAR — NOBETCI DERSI DEGIL DOSYAYI KORUR."
#
# Simdi iki sey degisti:
#   1) Betik BUTUN src/*.js dosyalarini okuyor (ciftler ayri dosyalarda
#      olabilir).
#   2) Seyahat cifti icin AYRI bir kural var — ama o cift artik TEK
#      BILESEN kullaniyor (`SeyahatFormu`), yani karsilastirilacak iki
#      kopya YOK. Nobetci bunu dogruluyor: iki ekran da ayni bileseni
#      cagirmiyorsa DUSUYOR.
#
# 🆕 SINIF: "IKI FORMUN ALANLARINI KARSILASTIRMAKTANSA IKI FORMUN AYNI
# BILESEN OLMASINI ZORUNLU KILMAK DAHA GUCLU BIR KORUMADIR - ILKI FARKI
# BULUR, IKINCISI FARKI IMKANSIZ KILAR."
def seyahat_cifti() -> int:
    import glob
    kok = SRC.parent
    hepsi = {}
    for y in sorted(glob.glob(str(kok / "*.js"))):
        with open(y, encoding="utf-8", errors="ignore") as f:
            hepsi[y] = f.read()

    def bul(ad):
        for y, m in hepsi.items():
            g = govde(m, ad)
            if g:
                return y, g
        return None, None

    print("\n" + "=" * 72)
    print("ALAN ESITLIGI — 'seyahat ekle' ile 'seyahat duzenle'")
    print("=" * 72)

    yF, formu = bul("SeyahatFormu")
    yA, ekle = bul("AddVisit")
    yD, duzenle = bul("EditTrip")

    if formu is None:
        print("  ✗ Paylasilan `SeyahatFormu` bileseni YOK.")
        print("    Iki ekran ayri yazilmis demektir; duzenleme formu geride kalir.")
        return 1
    if ekle is None or duzenle is None:
        print("  ✗ AddVisit / EditTrip bulunamadi — denetim kendi kendine bos kostu.")
        return 2

    hata = 0
    for ad, g, y in (("AddVisit", ekle, yA), ("EditTrip", duzenle, yD)):
        if "<SeyahatFormu" not in g:
            print("  ✗ %s paylasilan formu KULLANMIYOR (%s)" % (ad, os.path.basename(y)))
            print("    Kendi alanlarini yaziyorsa er ya da gec digerinden ayrisir.")
            hata = 1
        else:
            print("  ✓ %-9s → <SeyahatFormu>  (%s)" % (ad, os.path.basename(y)))

    # Formun icinde gercekten butun alanlar var mi? Bilesen olmasi, alanin
    # cizildigini kanitlamaz.
    ALAN = [
        ("havalimani", r"<AirportPicker[^>]*value=\{f\.airport\}"),
        ("varis",      r"<AirportPicker[^>]*value=\{f\.destination\}"),
        ("tarih",      r"<DateInput"),
        ("saatler",    r"<TimeInput"),
        ("havayolu",   r"<CarrierPicker"),
        ("ucus",       r"<FlightField"),
        ("amac",       r"PURPOSES\.map"),
    ]
    eksik = [a for a, d in ALAN if not re.search(d, formu, re.S)]
    if eksik:
        print("  ✗ Paylasilan formda EKSIK alan: %s" % ", ".join(eksik))
        hata = 1
    else:
        print("  ✓ Paylasilan formda 7 alanin hepsi var.")

    # 🔴 VARIS ALANI OZEL OLARAK SORULUYOR: eski hatada deger form
    # durumunda TUTULUYOR ve sunucuya GONDERILIYOR ama EKRANDA
    # CIZILMIYORDU. Yani "gonderiliyor" testi gecerdi, "gorunuyor" testi
    # gecmezdi. Ikisini de soruyoruz.
    if "p_destination" not in duzenle:
        print("  ✗ EditTrip `p_destination` gondermiyor.")
        hata = 1
    if not re.search(r"<AirportPicker[^>]*value=\{f\.destination\}", formu, re.S):
        print("  ✗ VARIS alani formda CIZILMIYOR (deger gonderiliyor olsa bile).")
        hata = 1

    # Sunucu tarafi: formda amac varsa `update_visit` onu yazabilmeli.
    sql = SRC.parent.parent.parent / "sql" / "262_seyahat_duzenle_tam.sql"
    if not sql.exists():
        print("  ✗ sql/262_seyahat_duzenle_tam.sql YOK — `p_purpose` sunucuda yazilamaz.")
        print("    Formda gorunup sunucuda yazilamayan alan, bos alandan kotudur.")
        hata = 1
    elif "p_purpose" not in sql.read_text(encoding="utf-8", errors="ignore"):
        print("  ✗ 262'de `p_purpose` yok.")
        hata = 1
    else:
        print("  ✓ Sunucu `p_purpose` yaziyor (SQL 262).")

    return hata


def main() -> int:
    print("=" * 72)
    print("ALAN ESITLIGI DENETIMI — 'musaitlik ekle' ile 'ilan duzenle'")
    print("=" * 72)

    if not SRC.exists():
        print("✗ src/screens.js bulunamadi — denetim KOSMADI (sessiz gecmiyor).")
        return 2
    metin = SRC.read_text(encoding="utf-8", errors="ignore")

    ekle = govde(metin, "HostAvailability")
    duzenle = govde(metin, "EditAvailability")
    if ekle is None or duzenle is None:
        # 🔴 BOS KOSMA = SESSIZ YESIL. Bileseni bulamadiysak bu bir bulgu
        # degil, denetimin kendi arizasidir.
        print("✗ HostAvailability / EditAvailability bulunamadi — denetim kendi kendine bos kostu.")
        return 2

    eksikler = []
    ortak = 0
    for ad, desen in ALANLAR:
        a = re.search(desen, ekle) is not None
        b = re.search(desen, duzenle) is not None
        if a and b:
            ortak += 1
            continue
        if ad in TEK_TARAFLI:
            continue
        eksikler.append((ad,
                         "Musaitlik Ekle" if not a else "Ilan Duzenle",
                         desen))

    print(f"  olculen alan   : {len(ALANLAR)}")
    print(f"  iki ekranda da : {ortak}")

    if eksikler:
        print()
        print(f"  ✗ {len(eksikler)} alan YALNIZ BIR EKRANDA var:")
        for ad, eksik_ekran, desen in eksikler:
            print(f"      {ad:14s} → '{eksik_ekran}' ekraninda YOK   (desen: {desen})")
        print()
        print("  Ya eksik ekrana ekle, ya alan_esitligi_check.py > TEK_TARAFLI")
        print("  icine GEREKCESIYLE yaz. Gerekcesiz istisna yok.")
        return 1

    print("  ✓ iki form ayni alanlari soruyor")
    # 🔴 SEYAHAT CIFTI DE BURADA. Iki cift ayri ayri raporlaniyor ama
    # cikis kodu TEK: biri duserse denetim duser.
    return seyahat_cifti()


if __name__ == "__main__":
    sys.exit(main())
