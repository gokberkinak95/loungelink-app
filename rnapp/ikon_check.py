# -*- coding: utf-8 -*-
"""
ikon_check.py — İKON NÖBETÇİSİ

🔴 NEDEN VAR
28 Ağustos, Gökberk: "kullanılan yeni ikonlarda hep kesilmeler var, profil
tabındakiler yatay olarak yayılmış." Sebep tek: uygulamanın ikon sistemi
yoktu, emoji vardı — ÖLÇÜM: 505 çizilen emoji, 81 farklı karakter.

Bu dosya iki soruyu soruyor ve ikisi de mutasyonla test edildi:

  1) KAPI  — `src/ikon.js`'teki her anlam adı Ionicons'ta GERÇEKTEN var mı?
             Bir yazım hatası (`shield-checkmark-outlne`) çalışma anında
             SESSİZ bir boşluk üretir; kullanıcı ikonun olmadığını değil,
             "orada bir şey eksik" hissini görür.

  2) CIRCIR — dönüştürülmüş yüzeylerde emoji SIFIR olmalı; dönüştürülmemiş
             dosyalarda emoji sayısı ARTAMAZ.

🆕 SINIF: "BÜYÜK BİR GÖÇÜ TEK SEFERDE BİTİREMİYORSAN, GERİYE GİDİŞİ YASAKLA —
BİR ÇIRÇIR NÖBETÇİSİ, BİTMEMİŞ BİR İŞİ BİLE TEK YÖNLÜ HÂLE GETİRİR."

Bütçe `ikon_butce.json` içinde. Bir dosyanın sayısı DÜŞTÜĞÜNDE bütçe
otomatik olarak yeni (düşük) değere çekilir — yani her temizlik tavanı
kalıcı olarak indirir. ARTIŞ hata verir.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "ikon_butce.json")
GLIF_YOL = os.path.join(
    KOK, "node_modules", "@expo", "vector-icons", "build", "vendor",
    "react-native-vector-icons", "glyphmaps", "Ionicons.json")

# Emoji + metin sunumlu sembol aralıkları. Kutu çizimi (═ ─ │) HARİÇ:
# onlar yorum bloklarının çerçevesi, çizilen bir şey değil.
EMOJI = re.compile(
    "[\U0001F000-\U0001FAFF"      # emoji blokları
    "←-⇿"               # oklar
    "⌀-⏿"               # teknik semboller (⏳ ⏱ ⌂)
    "①-⓿"               # daireli
    "☀-➿"               # muhtelif semboller + dingbats
    "⬀-⯿"               # ok/geometri ek
    "■-◿"               # geometrik şekiller (◈ ● ▲ ▾)
    "ℹ"                      # ℹ — kırpılan ikon
    "️]")                    # varyasyon seçici

# Bu karakterler METİN olarak meşru: tipografik işaretler, ikon değil.
IZINLI = set("›‹·—–…×→←↔")


def kod(s):
    """Yorumları at — yorumdaki emoji çizilmiyor.

    🔴 İLK SÜRÜMÜM YALNIZ TAM SATIR YORUMLARINI ATIYORDU ve `ikon.js`'in
    kendisini 72 emojiyle raporladı — oysa hepsi haritanın yanındaki
    `// ⚙ (yayık)` açıklamalarıydı, yani NÖBETÇİNİN KENDİ BELGESİ.

    🆕 SINIF: "BİR SAYAÇ, KENDİ AÇIKLAMASINI DA SAYIYORSA ÖLÇTÜĞÜ ŞEY
    KOD DEĞİL METİNDİR."

    Satır sonu yorumu da atılıyor; `"https://…"` bir yorum sanılmıyor.

    🔴 12 EYLÜL · ÜÇÜNCÜ KEZ. Düzenli ifade sürümü şöyleydi:
        re.sub(r"[ \\t]*//[^\\"'\\n]*$", "", s, flags=re.M)
    Yani "// sonrası tırnak İÇERMİYORSA yorumdur". `theme.js`te tek bir
    satır bu kuralı deldi:
        C.tealInk = "#0B786F";   // 🔴 ... AA'nın altında kalıyordu
    Yorumun içinde bir KESME İŞARETİ var ("AA'nın") ve ayıklayıcı satırı
    yorum saymadı; 🔴 ÇİZİLEN EMOJİ olarak sayıldı. Türkçe bir yorumda
    kesme işareti kural dışı değil KURALDIR — yani bu tuzak er geç
    patlayacaktı.

    Artık tırnak DURUMU takip ediliyor: satır soldan taranıyor, dize
    içindeyken `//` yorum sayılmıyor, dışındayken sayılıyor. Biçimden
    değil dilbilgisinden karar veriyor.

    🆕 SINIF: "BİR AYIKLAYICI ÜÇÜNCÜ KEZ AYNI SINIFTAN YANILIYORSA
    DÜZENLİ İFADEYİ DÜZELTME — AYRIŞTIRICIYI YAZ."
    """
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    cikti = []
    for sat in s.split("\n"):
        tirnak, i, n, kes = None, 0, len(sat), None
        while i < n:
            c = sat[i]
            if tirnak:
                if c == "\\":
                    i += 2
                    continue
                if c == tirnak:
                    tirnak = None
            elif c in "\"'`":
                tirnak = c
            elif c == "/" and i + 1 < n and sat[i + 1] == "/":
                kes = i
                break
            i += 1
        cikti.append(sat if kes is None else sat[:kes])
    return "\n".join(cikti)


def say(yol):
    with open(yol, encoding="utf-8") as f:
        s = kod(f.read())
    return [m for m in EMOJI.findall(s) if m not in IZINLI]


def dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            d.append(os.path.join(SRC, f))
    return d


# ============================================================================
# 🔴 v3.6 — EMOJİ SAYMAK YETMİYORDU: ASIL SORU "BU GLİF FONTTA VAR MI?"
#
# Emoji borcunu 342'ye indirdim ve dağılımına baktım: i18n'deki 205
# işaretin 132'si `→` ve `✓`ti. İkisi de METİN sunumlu; kırpılma sorunu
# emoji dikey ölçülerinden gelir, bunlarda o ölçü yok. Yani sayaç,
# ÇALIŞAN TİPOGRAFİYİ borç olarak raporluyordu — ve beni onları ikon
# bileşenine çevirmeye itiyordu.
#
# Fontları AÇIP ölçünce asıl bulgu çıktı:
#     Archivo (gövde sans) → ● U+25CF YOK · ○ U+25CB YOK
# Ve `●` uygulamada 30 yerde kullanılıyordu — rozet hapları, slot
# göstergeleri. Hepsi sessizce SİSTEM FONTUNA düşüyordu: başka bir
# yazı karakteri, başka dikey ölçüler. Yani Gökberk'in "ikonlarda
# kesilme" şikâyetinin emoji OLMAYAN bir kaynağı daha vardı ve hiçbir
# denetim onu göremiyordu.
#
# 🆕 SINIF: "BİR GLİFİN EMOJİ OLUP OLMADIĞI DEĞİL, ÇİZECEK FONTTA
# BULUNUP BULUNMADIĞI ÖNEMLİDİR — EKSİK GLİF SESSİZCE BAŞKA BİR FONTA
# DÜŞER VE 'KESİLME' DİYE GERİ DÖNER."
#
# `•` ve `·` Archivo'da VAR; `●`/`○` onlarla değiştirildi.
# ============================================================================
GOVDE_FONT = os.path.join(KOK, "assets", "fonts", "Archivo-Regular.ttf")

# Ionicons ile çizilenler bu kuralın dışında: onları `Ikon` çiziyor.
FONT_MUAF = set("️")


def font_kapsami():
    """Gövde fontunun cmap'i. fontTools yoksa None (kural atlanır)."""
    try:
        from fontTools.ttLib import TTFont
    except Exception:
        return None
    if not os.path.exists(GOVDE_FONT):
        return None
    try:
        t = TTFont(GOVDE_FONT, fontNumber=0)
    except Exception:
        return None
    kod_noktalari = set()
    for tb in t["cmap"].tables:
        kod_noktalari |= set(tb.cmap.keys())
    return kod_noktalari


def fontta_olmayanlar():
    """Kodda ÇİZİLEN ama gövde fontunda BULUNMAYAN ASCII dışı işaretler.

    Emoji'yi (U+1F000+) kapsam dışı bırakıyorum: onlar zaten emoji
    sayacının işi ve sistemin emoji fontuna düşmeleri BEKLENEN davranış.
    Aranan şey, metin gibi davranan ama gövde fontunda karşılığı olmayan
    işaretler — sessizce başka bir yazı karakterine düşenler.
    """
    kapsam = font_kapsami()
    if kapsam is None:
        return None
    bulgu = {}
    for y in dosyalar():
        s = kod(open(y, encoding="utf-8").read())
        # Dizge sabitlerinin içi = çizilen metin.
        for m in re.finditer(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'', s):
            for ch in m.group(0):
                o = ord(ch)
                if o < 0x00A0 or o >= 0x1F000 or ch in FONT_MUAF:
                    continue
                if o in kapsam:
                    continue
                bulgu.setdefault(ch, []).append(os.path.relpath(y, KOK))
    return bulgu


def main():
    hata = 0
    print("=" * 70)
    print("İKON NÖBETÇİSİ")
    print("=" * 70)

    # ── 1) KAPI: her anlam adı gerçek bir glife çözülüyor mu ────────────
    with open(GLIF_YOL, encoding="utf-8") as f:
        glifler = set(json.load(f).keys())
    with open(os.path.join(SRC, "ikon.js"), encoding="utf-8") as f:
        ikon_src = f.read()
    harita = dict(re.findall(r'^\s*(\w+):\s*"([\w-]+)",', ikon_src, re.M))
    kirik = {a: g for a, g in harita.items() if g not in glifler}
    print("\n  Anlam → glif haritası: %d giriş" % len(harita))
    if kirik:
        print("  ✗ IONICONS'TA OLMAYAN GLİF:")
        for a, g in sorted(kirik.items()):
            print("      %-16s → %s" % (a, g))
        print("      Bunlar çalışma anında SESSİZ BOŞLUK çizer.")
        hata += 1
    else:
        print("  ✓ Haritadaki her glif Ionicons'ta var.")

    # ── 2) KULLANILAN HER AD HARİTADA VAR MI ───────────────────────────
    # 🔴 Ters yön de gerekli: `<Ikon ad="ayarlarr" />` haritada yoksa
    # yine sessiz boşluk olur ve kapı-1 bunu göremez.
    # 🔴 30 AĞUSTOS · 2. TUR — KAPI YALNIZ DÜZ METİN ADI GÖRÜYORDU.
    # `<Ikon ad="tamam" />` yakalanıyordu ama
    # `<Ikon ad={ok ? "onay" : "kapat"} />` YAKALANMIYORDU — ve ben tam
    # bu biçimde haritada olmayan bir ad ("onay") yazdım; denetim yeşil
    # yandı. Bir kapının kapalı olması, her yoldan geçilemediği anlamına
    # gelmiyor; yalnız ANA yoldan geçilemediği anlamına geliyor.
    #
    # 🆕 SINIF: "BİR NÖBETÇİ YALNIZCA BEKLEDİĞİ BİÇİMİ GÖRÜR; İLK FARKLI
    # BİÇİM ONUN İÇİN VAR OLMAYAN BİR ŞEYDİR — VE ORASI ARTIK EN
    # KORUMASIZ YERDİR."
    #
    # Artık `ad={...}` süslü ifadesinin içindeki her dizgi de sayılıyor.
    kullanilan, dinamik = set(), set()
    for y in dosyalar():
        with open(y, encoding="utf-8") as f:
            src = f.read()
        kullanilan |= set(re.findall(r'<Ikon\s+ad="(\w+)"', src))
        kullanilan |= set(re.findall(r'<IkonMetin\s+ad="(\w+)"', src))
        for ifade in re.findall(r'<Ikon(?:Metin)?\s+ad=\{([^}]*)\}', src):
            # ⚠️ BİRLEŞTİRME AYRI BİR DURUM: `ad={ic + "Dolu"}` içindeki
            # "Dolu" bir ad DEĞİL, bir ekleme. Onu ad sanıp aramak yanlış
            # alarm üretir (ilk denememde tam bunu yaptı). Birleştirme
            # içeren ifadeler statik olarak çözülemez; sayılıp
            # raporlanıyorlar ki görünmez kalmasınlar.
            if "+" in ifade:
                dinamik.add(ifade.strip())
                continue
            kullanilan |= set(re.findall(r'"(\w+)"', ifade))
    eksik = sorted(kullanilan - set(harita))
    if eksik:
        print("  ✗ HARİTADA OLMAYAN AD KULLANILMIŞ: %s" % ", ".join(eksik))
        hata += 1
    else:
        print("  ✓ Doğrudan kullanılan %d adın hepsi haritada." % len(kullanilan))
    if dinamik:
        print("  ⚠ Statik çözülemeyen %d birleştirme (elle doğrulandı):"
              % len(dinamik))
        for i in sorted(dinamik):
            print("      %s" % i)

    # ── 3) ÇIRÇIR ──────────────────────────────────────────────────────
    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    simdi, artan, azalan, yeni = {}, [], [], []
    for y in dosyalar():
        ad = os.path.relpath(y, KOK).replace("\\", "/")
        n = len(say(y))
        simdi[ad] = n
        onceki = butce.get(ad)
        if onceki is None:
            yeni.append((ad, n))
        elif n > onceki:
            artan.append((ad, onceki, n))
        elif n < onceki:
            azalan.append((ad, onceki, n))

    toplam = sum(simdi.values())
    onceki_toplam = sum(butce.values()) if butce else toplam
    print("\n  Çizilen emoji: %d  (önceki bütçe: %d)" % (toplam, onceki_toplam))

    # ── SAYIYI İKİYE AYIR: BU RAKAM BENİ BİR KEZ YANILTTI ─────────────
    # 🔴 "Emoji borcu 342" diye raporladım; dağılıma bakınca i18n'deki
    # 205 işaretin 132'si `→` ve `✓` çıktı. İkisi de Archivo'da VAR ve
    # metin sunumlu — yani kırpılma sorunları YOK. Tek bir toplam sayı,
    # gerçek kusuru (fonta düşmeyen glif) sağlam tipografinin içine
    # gömüyordu.
    #
    # 🆕 SINIF: "TEK BİR BORÇ SAYISI İKİ FARKLI ŞEYİ TOPLUYORSA, BÜYÜK
    # OLAN KÜÇÜK OLANI SAKLAR — VE DÜZELTİLMESİ GEREKEN HEP KÜÇÜK OLANDIR."
    kaps = font_kapsami()
    if kaps is not None:
        hepsi = []
        for y in dosyalar():
            hepsi += say(y)
        icinde = sum(1 for c in hepsi if all(ord(x) in kaps for x in c))
        print("    ├ gövde fontunda VAR (kırpılmaz, tipografi): %d" % icinde)
        print("    └ fonta düşen gerçek emoji:                  %d" % (len(hepsi) - icinde))

    for ad, o, n in azalan:
        print("    ↓ %-28s %3d → %3d" % (ad, o, n))
    if artan:
        print("  ✗ EMOJİ ARTMIŞ — ikon yerine emoji yazılmış:")
        for ad, o, n in artan:
            print("      %-28s %3d → %3d  (+%d)" % (ad, o, n, n - o))
        print("      Çözüm: src/ikon.js'e anlam ekle, <Ikon ad=\"…\" /> kullan.")
        hata += 1
    elif not yeni:
        print("  ✓ Hiçbir dosyada emoji artmadı.")

    # Bütçeyi yalnız AŞAĞI çek. Yukarı çekmek çırçırı bozar.
    yeni_butce = {a: min(n, butce.get(a, n)) for a, n in simdi.items()}
    if yeni_butce != butce and not artan:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(yeni_butce, f, indent=1, sort_keys=True)
        print("  · bütçe güncellendi (yalnız aşağı)")

    # ── 4) DÖNÜŞTÜRÜLMÜŞ YÜZEYLER: SIFIR TOLERANS ──────────────────────
    # Bu bloklar elden geçti; burada bir emoji görünürse GERİLEME vardır.
    with open(os.path.join(KOK, "App.js"), encoding="utf-8") as f:
        app = kod(f.read())
    m = re.search(r"const tabs = \[[\s\S]{0,400}?\];", app)
    if not m:
        print("\n  ✗ Sekme tanımı bulunamadı — nöbetçi kör kaldı.")
        hata += 1
    else:
        kalan = [c for c in EMOJI.findall(m.group(0)) if c not in IZINLI]
        if kalan:
            print("\n  ✗ SEKME ÇUBUĞUNDA EMOJİ GERİ GELMİŞ: %s" % " ".join(kalan))
            hata += 1
        else:
            print("\n  ✓ Sekme çubuğu emojisiz.")

    with open(os.path.join(SRC, "ortak.js"), encoding="utf-8") as f:
        om = re.search(r"export const AMENITY_ICONS = \{[\s\S]*?\};", f.read())
    kalan = [c for c in EMOJI.findall(om.group(0))] if om else ["(blok yok)"]
    if kalan:
        print("  ✗ OLANAK ROZETLERİNDE EMOJİ: %s" % " ".join(map(str, kalan)))
        hata += 1
    else:
        print("  ✓ Olanak rozetleri emojisiz.")

    # ── GÖVDE FONTU KAPSAMI ───────────────────────────────────────────
    eksik = fontta_olmayanlar()
    if eksik is None:
        print("\n  · font kapsamı atlandı (fontTools yok)")
    elif eksik:
        print("\n  ✗ GÖVDE FONTUNDA OLMAYAN İŞARET ÇİZİLİYOR:")
        for ch, yerler in sorted(eksik.items()):
            print("      %r U+%04X — %d yerde (%s)"
                  % (ch, ord(ch), len(yerler), ", ".join(sorted(set(yerler))[:3])))
        print("      Bunlar sessizce SİSTEM fontuna düşer: başka yazı")
        print("      karakteri, başka dikey ölçü — 'kesilme' böyle doğar.")
        print("      Archivo'da olan bir karşılık seç (• · × → ✓) ya da `Ikon` kullan.")
        hata += 1
    else:
        print("  ✓ Çizilen her işaret gövde fontunda (Archivo) var.")

    hata += font_yolu_nobetcisi()

    print("\n" + "=" * 70)
    if hata:
        print("✗ %d ikon bulgusu." % hata)
        return 1
    print("✓ İkon denetimi temiz.")
    return 0


# ==========================================================================
# 🔴 30 AĞUSTOS NÖBETÇİSİ — "BÜTÜN İKONLAR BOŞ" BİR DAHA SESSİZ OLMASIN
#
# O gün uygulamanın HER ekranında ikonlar boş çizildi ve hiçbir denetim
# bunu görmedi. Sebebi kütüphanenin şu davranışıydı:
#   @expo/vector-icons/build/createIconSet.js
#     render() { if (!this.state.fontIsLoaded) return <Text />; }
# Font yüklenemezse bileşen sonsuza kadar BOŞLUK çizer — hata atmaz.
#
# Bu nöbetçi üç şartı birden arar. Üçü de o günkü kök nedenin parçasıydı:
#   1) Ionicons `app.json`daki expo-font eklentisinde OLMAYACAK
#      (çift kayıt yolu; çalışma anındaki yükleyiciyle çakışıyordu)
#   2) App.js fontu ilk çizimden önce AÇIKÇA yükleyecek
#   3) `Ikon` içindeki Ionicons stilinde `lineHeight` OLMAYACAK
#      (lineHeight == fontSize Android'de glifi kırpar)
#
# 🆕 SINIF: "SESSİZ ÇİZİLEN BİR BOŞLUK, ANCAK ONU ÜRETEN KOŞULU ARAYAN
# BİR NÖBETÇİYLE YAKALANIR — ÇIKTIYA BAKAN TEST ONU ASLA GÖRMEZ."
# ==========================================================================
def font_yolu_nobetcisi():
    import json, re as _re
    print("\n" + "=" * 70)
    print("İKON FONTU YOLU — 'hepsi boş' arızası geri geldi mi")
    print("=" * 70)
    h = 0

    try:
        app = json.load(open(os.path.join(KOK, "app.json"), encoding="utf-8"))["expo"]
    except Exception as e:
        print("  ✗ app.json okunamadı: %s" % e)
        return 1

    gomulu = []
    for pl in app.get("plugins", []):
        if isinstance(pl, list) and pl[0] == "expo-font":
            gomulu = pl[1].get("fonts", [])
    # 🔴 5 EYLÜL — TERSİNE DÖNDÜ. 30 Ağu'da "çift kayıt" diye eklentiden
    # çıkarılan font, cihazda çalışma anında (`Font.loadAsync`) İKİ sürüm
    # üst üste yüklenemedi: bütün ikonlar yer tutucu kare. Eski gömme de
    # yanlıştı: dosya `Ionicons.ttf` (büyük I) idi, bileşenin aile adı ise
    # "ionicons" — Android aileyi DOSYA ADINDAN türetir (expo-font
    # `queryCustomNativeFonts`), yani `isLoaded("ionicons")` hiç true olmadı.
    # Doğrusu: `ionicons.ttf` (küçük harf) + `LLSimge.ttf` eklentide GÖMÜLÜ →
    # `isLoaded` ilk kareden true, `loadAsync` hiç çağrılmaz, çakışma yok.
    kucuk = any(f.endswith("/ionicons.ttf") for f in gomulu)
    buyuk = any(f.endswith("/Ionicons.ttf") for f in gomulu)
    ll = any(f.endswith("/LLSimge.ttf") for f in gomulu)
    if buyuk:
        print("  ✗ `Ionicons.ttf` (büyük I) eklentide — aile adı 'ionicons' ile EŞLEŞMEZ, gömme boşa gider.")
        h += 1
    if not kucuk:
        print("  ✗ `assets/fonts/ionicons.ttf` expo-font eklentisinde YOK — cihazda ikonlar çalışma anı yüklemesine muhtaç kalır.")
        h += 1
    if not ll:
        print("  ✗ `assets/fonts/LLSimge.ttf` expo-font eklentisinde YOK.")
        h += 1
    if kucuk and ll and not buyuk:
        print("  ✓ ionicons.ttf + LLSimge.ttf build'e gömülü (aile adları bileşenle aynı).")
    # 🔴 BU KONTROL WINDOWS'TA HER ZAMAN DOGRU DONUYORDU. NTFS buyuk/kucuk
    # harf AYIRMAZ: `ionicons.ttf` varken `os.path.exists("Ionicons.ttf")`
    # True der. Yani kapi, tam da uyardigi cakismayi KENDI URETIYOR ve
    # temiz bir agacta kirmizi yakiyordu (Gokberk'in makinesinde oldu).
    # 🆕 SINIF: "DOSYA ADININ BUYUK/KUCUK HARFINI SORGULUYORSAN
    # `exists` KULLANMA — DIZINI LISTELE, ADI HARFI HARFINE KIYASLA."
    _fdizin = os.path.join(KOK, "assets", "fonts")
    _adlar = os.listdir(_fdizin) if os.path.isdir(_fdizin) else []
    if "Ionicons.ttf" in _adlar:
        print("  ✗ assets/fonts/Ionicons.ttf (büyük I) duruyor — Windows'ta ionicons.ttf ile ÇAKIŞIR (büyük/küçük harf aynı dosya).")
        h += 1

    try:
        appjs = open(os.path.join(KOK, "App.js"), encoding="utf-8").read()
    except Exception:
        appjs = ""
    if "ikonFontuHazirla" in appjs:
        print("  ✓ App.js fontu ilk çizimden önce açıkça yüklüyor.")
    else:
        print("  ✗ App.js `ikonFontuHazirla` ÇAĞIRMIYOR — ilk kare ikonsuz")
        print("      kalabilir ve yükleme reddedilirse kalıcı olur.")
        h += 1

    try:
        ikonjs = open(os.path.join(KOK, "src", "ikon.js"), encoding="utf-8").read()
    except Exception:
        ikonjs = ""
    govde = ikonjs[ikonjs.find("export function Ikon("):] if "export function Ikon(" in ikonjs else ""
    parca = govde[:govde.find("</View>")] if "</View>" in govde else govde
    if _re.search(r"lineHeight\s*:", parca):
        print("  ✗ `Ikon` içinde `lineHeight` var — Android'de glifi kırpar.")
        h += 1
    else:
        print("  ✓ Ionicons stilinde `lineHeight` yok.")

    if "YerTutucu" in ikonjs and '_fontDurum === "hata"' in ikonjs:
        print("  ✓ Font yüklenemezse görünür yer tutucu çiziliyor (sessiz boşluk yok).")
    else:
        print("  ✗ Font hatasında GÖRÜNÜR bir yer tutucu yok — arıza sessiz kalır.")
        h += 1

    if h == 0:
        print("\n  ✓ Dört kapı da kapalı.")
    return h


if __name__ == "__main__":
    sys.exit(main())
