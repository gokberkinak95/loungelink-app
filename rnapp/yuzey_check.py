# -*- coding: utf-8 -*-
"""
yuzey_check.py — KARTLAR AYNI DÜZLEMDE Mİ?

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "görsel olarak etkileyici miyiz? arka planlar,
butonlar, başlıklar, fontlar, ikonlar, rozetler..."

Ölçtüm. Ekranda İKİ TÜR KART var ve ikisi aynı ekranda yan yana duruyor:

    S.card            → C.surface + kenarlık + `ELEV.card` (gölge var)
    elle yazılmış kart → C.card/C.surface + kenarlık + GÖLGE YOK

Tek tek bakınca ikisi de doğru. Yan yana gelince kullanıcı GÖLGELİ olanı
kâğıt, gölgesizi de zemine ÇİZİLMİŞ bir çerçeve gibi okur. Yani ürün
z-ekseninde iki farklı fizik kuralı çalıştırıyor. "Etkileyici değil" hissi
çoğu zaman renkten değil, bu tutarsızlıktan gelir: göz, malzemenin ne
olduğuna karar veremez.

🆕 SINIF: "BİR ARAYÜZDE İKİ FARKLI YÜKSELTİ KURALI VARSA, KULLANICI DAHA
GÜZEL OLANI DEĞİL, İKİSİNİ BİRDEN GÜVENİLMEZ OLARAK OKUR."

NE ÖLÇÜYOR
Kart YÜZEYİ olan ama yükselti taşımayan satır içi stiller:
  backgroundColor: C.card|C.surface  +  borderWidth  +  borderRadius
ve aynı stil bloğunda ne `ELEV`, ne `shadow`, ne `elevation` var.

⚠️ ÇIRÇIR: mevcut borç `yuzey_butce.json`da. Azalınca tavan iner;
ARTARSA build düşer.

⚠️ NEYİ SAYMIYORUM (bilerek):
  · Tint/uyarı kutuları (C.goldBg, C.tealBg, C.hataBg…): bunlar KART değil
    VURGU alanıdır; düz olmaları doğrudur.
  · `S.card` kullanan her yer — zaten yükseltili.
  · Tam ekran/konteyner yüzeyleri (`flex: 1` aynı blokta).
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "yuzey_butce.json")

# Kart yüzeyi sayılan zeminler. Tint'ler BİLEREK dışarıda.
YUZEY = ("C.card", "C.surface")
YUKSELTI = ("ELEV.", "shadow", "elevation")


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


def dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            d.append(os.path.join(SRC, f))
    return d


def _blok(s, i):
    """`{` konumundan başlayıp eşleşen `}`e kadar olan stil bloğu."""
    derinlik = 0
    for j in range(i, min(len(s), i + 4000)):
        if s[j] == "{":
            derinlik += 1
        elif s[j] == "}":
            derinlik -= 1
            if derinlik == 0:
                return s[i:j + 1]
    return s[i:i + 4000]


def bulgular(yol):
    """(gölgesiz satırlar, TOPLAM kart yüzeyi sayısı) döndürür.

    🔴 PAYDAYI DA SAYIYORUM. İlk sürümde yalnız BULGULARI sayıyordum ve
    "ölçüm sıfırsa desen bozulmuştur" diye bir koruma koymuştum. 49'un
    hepsi düzelince o koruma yeşil yerine kırmızı yandı: sıfır bulgu
    GERÇEKTİ, koruma yanlıştı.

    🆕 SINIF: "'SIFIR BULGU ŞÜPHELİDİR' KORUMASI, PAYDAYI SAYMADAN
    KURULURSA BAŞARIYI DA ARIZA GİBİ RAPORLAR."

    Ayrım tek soruyla çözülüyor: ortada hâlâ KART var mı? Varsa ve
    hiçbiri gölgesiz değilse iş bitmiştir; hiç kart yoksa desen bozuktur.
    """
    with open(yol, encoding="utf-8") as f:
        s = kod(f.read())
    out, kart = [], 0
    for m in re.finditer(r"backgroundColor:\s*(C\.card|C\.surface)\b", s):
        # Bu atamayı içeren en yakın açılış süslü parantezini bul.
        bas = s.rfind("{", 0, m.start())
        if bas < 0:
            continue
        blok = _blok(s, bas)
        if m.group(0) not in blok:
            continue
        if "borderWidth" not in blok or "borderRadius" not in blok:
            continue          # kart değil; düz bir yüzey
        if "flex: 1" in blok or "flex:1" in blok:
            continue          # konteyner, kart değil
        # 🔴 30 AĞUSTOS · 2. TUR — HAP, KART DEĞİLDİR.
        #
        # Gece sisteminde çip (`S.chip`) tasarımdaki `.cip` oldu: hap
        # yarıçapı, ince kenar, GÖLGESİZ. Bu denetim onu kart sandı ve
        # haklı olarak "gölgesiz kart arttı" dedi — çünkü kalıbı
        # "zemin + kenar + yarıçap" idi ve hap da üçünü taşıyor.
        #
        # Ama gölgenin işi bir yüzeyi SAYFADAN AYIRMAK. Bir hap zaten
        # satır içinde, bir cümlenin parçası gibi duruyor; ona gölge
        # vermek onu havaya kaldırır ve kartla aynı ağırlığa çıkarır.
        # `R.full` (tam yuvarlak) bir kartın yarıçapı değildir: kartlar
        # R.sm/md/lg kullanıyor. Yani şeklin kendisi, öğenin ne
        # olduğunu söylüyor.
        #
        # 🆕 SINIF: "BİR DENETİM KALIBI ÖĞENİN NE OLDUĞUNU DEĞİL NEYE
        # BENZEDİĞİNİ ÖLÇÜYORSA, ONA BENZEYEN HER ŞEYİ AYNI KURALA TABİ
        # TUTAR — VE İLK İSTİSNADA YANLIŞ ALARM VERİR."
        if "borderRadius: R.full" in blok or "borderRadius:R.full" in blok:
            continue          # hap/daire — satır içi öğe, kart değil
        # 🔴 31 AĞUSTOS · 9. TUR — YAZMA KUTUSU DA KART DEĞİL.
        #
        # Sohbetin yazma alanı tasarımdaki `.yazma`ya çevrildi: kenar,
        # yarıçap, yüzey zemini — üçü de var, yani bu kalıba giriyor.
        # Ama tasarımda `box-shadow` YOK ve olmaması bir eksik değil bir
        # KARAR: bir giriş alanı sayfadan yükselmez, sayfaya GÖMÜLÜR.
        # Gölge "bu bir nesne, üstünde duruyor" der; giriş alanı ise
        # "buraya yaz" der — ters yönler.
        #
        # Kanıtı yapının kendisinde arıyoruz (yorumda değil): blokta bir
        # `TextInput` varsa bu bir kart değil, bir formdur.
        #
        # 🆕 SINIF: "BİR İSTİSNAYI ADLA DEĞİL YAPIYLA TANI — 'ŞU DOSYADAKİ
        # ŞU SATIR' DİYE YAZILAN HER MUAFİYET, BİR SONRAKİ DÜZENLEMEDE YA
        # KAYBOLUR YA DA GERÇEK BİR KUSURU ÖRTER."
        # ⚠️ `blok` YALNIZ STİL NESNESİDİR, ÇOCUKLARI DEĞİL.
        # İlk denememde `"TextInput" in blok` yazdım ve hiçbir şey
        # değişmedi: `_blok()` `{`den eşleşen `}`e kadar okuyor, yani
        # elimizde stil sözlüğü var — `<TextInput>` ondan SONRA geliyor.
        # Yapıyı stilin içinde aramak, yapının orada olmadığı bir yerde
        # aramaktı.
        #
        # 🆕 SINIF: "BİR İSTİSNAYI YAPIYLA TANIYACAKSAN, ELİNDEKİ
        # PARÇANIN O YAPIYI GERÇEKTEN İÇERDİĞİNİ ÖNCE DOĞRULA."
        #
        # Doğrusu: stilin BİTTİĞİ yerden sonraki kısa pencereye bak.
        kuyruk = s[bas + len(blok): bas + len(blok) + 400]
        if "<TextInput" in kuyruk:
            continue          # giriş alanı — gömülür, yükselmez
        kart += 1
        if any(k in blok for k in YUKSELTI):
            continue          # zaten yükseltili
        out.append(s[:m.start()].count("\n") + 1)
    return out, kart


def main():
    print("=" * 70)
    print("YÜZEY DENETİMİ — kartlar aynı z-düzleminde mi?")
    print("=" * 70)

    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    simdi, artan, kart_toplam = {}, [], 0
    for y in dosyalar():
        ad = os.path.relpath(y, KOK).replace("\\", "/")
        satirlar, kart = bulgular(y)
        kart_toplam += kart
        n = len(satirlar)
        if n:
            simdi[ad] = n
        onceki = butce.get(ad)
        if onceki is not None and n > onceki:
            artan.append((ad, onceki, n))

    toplam = sum(simdi.values())
    print("\n  Kart yüzeyi (toplam): %d" % kart_toplam)
    print("  Gölgesiz olan:        %d  (bütçe: %d)"
          % (toplam, sum(butce.values()) if butce else toplam))
    for ad, n in sorted(simdi.items(), key=lambda x: -x[1]):
        print("    %-28s %3d" % (ad, n))

    # 🔴 SIFIR ÖLÇÜM = SIFIR BULGU DEĞİLDİR. `dal_prop_check.py`de bu
    # tuzağa düştüm: desen bozulunca denetim sıfır bulgu bulup YEŞİL
    # yanmıştı. Kartların tamamen bitmesi beklenen bir durum değil —
    # bütçe varken ölçüm sıfırsa desen bozulmuştur.
    if kart_toplam == 0:
        print("\n  ✗ HİÇ KART YÜZEYİ BULUNAMADI — desen bozulmuş, denetim kör.")
        return 1
    if toplam == 0:
        print("  ✓ %d kart yüzeyinin HEPSİ aynı z-düzleminde." % kart_toplam)

    hata = 0
    if artan:
        print("\n  ✗ GÖLGESİZ KART ARTMIŞ:")
        for ad, o, n in artan:
            print("      %-26s %3d → %3d  (+%d)" % (ad, o, n, n - o))
        print("      `S.card` kullan ya da stile `...ELEV.card` ekle.")
        hata = 1
    elif butce:
        print("  ✓ Hiçbir dosyada gölgesiz kart artmadı.")

    yeni = {a: min(n, butce.get(a, n)) for a, n in simdi.items()}
    for a in butce:
        if a not in yeni:
            yeni[a] = 0
    if yeni != butce and not artan:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(yeni, f, indent=1, sort_keys=True)
        print("  · bütçe güncellendi (yalnız aşağı)")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Yüzey bulgusu var.")
        return 1
    print("✓ Yüzey denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
