# -*- coding: utf-8 -*-
"""
olu_metin_check.py — YAZILMIŞ AMA HİÇBİR YERDE ÇİZİLMEYEN METİN

============================================================================
🔴 NEDEN VAR
Bu projede aynı sınıf **beş kez** yaşandı ve her seferinde ürün bir şeyi
kaybetti:

  · `t.pills` (splash güven işaretleri)  → yazıldı, çevrildi, çizilmedi
  · `MyQuestions` ekranı                 → yazıldı, RPC canlı, açılmadı
  · `foundingLeft` (kıtlık)              → yalnız profil düzenlemede
  · `waitingDemand` (bekleyen talep)     → hiçbir dosyada geçmiyordu
  · `navDisc` ("Keşfet")                 → iki dilde yazılı, sekme yok

Beşi de "unutulmuş" değil: yazılırken KULLANILACAĞI varsayılmış, sonra
o kullanım hiç yazılmamış. Ve hiçbir denetim bunu görmüyordu, çünkü
`check.js` yalnız TERS yönü soruyor: "kodda kullanılan anahtar i18n'de
var mı?" Bu dosya eksik olan yönü soruyor: **"i18n'de olan anahtar
kodda kullanılıyor mu?"**

🆕 SINIF: "BİR METİN DENETİMİ YALNIZ 'EKSİK ANAHTAR' ARIYORSA, YAZILIP
HİÇ GÖSTERİLMEYEN METNİ ASLA GÖREMEZ — VE O METİN, EKSİK OLANDAN DAHA
PAHALIDIR ÇÜNKÜ İŞ YAPILMIŞ VE TESLİM EDİLMEMİŞTİR."

============================================================================
⚠️ YANLIŞ POZİTİFLER — BURADA ÖLÇÜM İKİ KEZ YANILDI

İlk sürümüm 271 "ölü" anahtar buldu. Neredeyse hepsi CANLIYDI:

 1. **Dinamik erişim.** `t[key]` deseni her yerde var:
        setErr(t["e_" + sunucuKodu] || mapErr(t, ...))
        profOpts = (t) => PROF_KEYS.map(k => t[k])
    Yani `e_*` ve `epProf*` anahtarları hiç `t.e_own_listing` diye
    yazılmadan kullanılıyor. Düz metin araması bunları göremez.

 2. **İç içe nesne anahtarları.** `onbSlides` dizisinin içindeki
    `{icon, title, body}` alanları da "anahtar:" kalıbına uyuyor ve
    üst düzey i18n anahtarı sanılıyordu.

Bu yüzden ölçüm YALNIZ üst düzey anahtarlara (tam 4 boşluk girinti)
bakıyor ve üç ayrı kullanım kanalını birden kabul ediyor:
`t.X` · `t["X"]` · kaynakta çıplak `"X"` dizgesi.

🆕 SINIF: "DİNAMİK ERİŞİMİ OLAN BİR TABLODA 'KULLANILMIYOR' DEMEK, ÖNCE
O DİNAMİK KANALLARI SAYMAYI GEREKTİRİR — YOKSA DENETİM, ÇALIŞAN KODU
SİLMENİ ÖNERİR."

⚠️ ÇIRÇIR: `olu_metin_butce.json`. Azalınca tavan iner; ARTARSA build
düşer — yani bundan sonra "yaz ve çizme" build'i kırar.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
I18N = os.path.join(SRC, "i18n.js")
BUTCE_YOL = os.path.join(KOK, "olu_metin_butce.json")

# Yapısal anahtarlar: metin değil, i18n tablosunun kendi iskeleti.
YAPISAL = {"tr", "en", "errMap"}


def yorumsuz(s):
    s = re.sub(r"/\*[\s\S]*?\*/", " ", s)
    s = re.sub(r"(^|[^:])//[^\n]*", r"\1 ", s)
    return s


def ust_duzey_anahtarlar(blok):
    """Tam 4 boşluk girintili satırlardaki TÜM üst düzey anahtarlar.

    İç içe nesnelerin (onbSlides içindeki `title`/`body`/`icon`) daha
    derin girintisi var; 4 boşluk kuralı onları dışarıda tutuyor.

    🔴 12 EYLÜL · GECE — BU NÖBETÇİNİN 66 ANAHTARLIK KÖR NOKTASI VARDI.

    Desen `^    (\w+):` idi: SATIR BAŞINDAKİ anahtarı görüyor, aynı
    satırdaki ikinciyi görmüyordu. Sözlükte bunlardan çok var:

        walletBalance: "BAKİYE", walletCredits: "kredi",
                                 └── nöbetçi bunu HİÇ saymıyordu

    Ölçtüm: satır başı 1296 anahtar, gerçekte 1362 → **66 anahtar
    (%4.8) hiç denetlenmiyordu.** Ve ikisi gerçekten kaybolmuştu:
    `walletBalance` ("BAKİYE") ve `walletCreditsMeans` ("{n} misafir
    isteği gönderebilirsin"), v5.4.0'da cüzdan kartını yazarken
    düşmüşler. Nöbetçi yeşil yanıyordu çünkü o anahtarları hiç
    tanımıyordu.

    Artık satır, süslü parantez/köşeli parantez/tırnak derinliği
    izlenerek taranıyor: derinlik 0'daki her `anahtar:` sayılıyor,
    satır içi nesnelerin içindekiler sayılmıyor.

    🆕 SINIF: "BİR NÖBETÇİNİN KAPSAMINI ÖLÇMEDİYSEN, ONUN YEŞİL IŞIĞI
    'KUSUR YOK' DEĞİL 'BAKTIĞIM YERDE KUSUR YOK' DEMEKTİR — VE NEREYE
    BAKTIĞINI BİLMİYORSAN İKİSİ AYNI ŞEY DEĞİLDİR."
    """
    out = []
    for satir in yorucmsuz_satirlar(blok):
        derin, i, n = 0, 0, len(satir)
        while i < n:
            c = satir[i]
            if c in "\"'":
                q = c
                i += 1
                while i < n and satir[i] != q:
                    i += 2 if satir[i] == "\\" else 1
            elif c in "{[":
                derin += 1
            elif c in "}]":
                derin -= 1
            elif derin == 0 and (c.isalpha() or c == "_"):
                j = i
                while j < n and (satir[j].isalnum() or satir[j] == "_"):
                    j += 1
                k = j
                while k < n and satir[k] == " ":
                    k += 1
                if k < n and satir[k] == ":":
                    out.append(satir[i:j])
                i = j - 1
            i += 1
    return out


def yorucmsuz_satirlar(blok):
    """Üst düzey girinti satırları (yorumlar çıkarılmış).

    🔴 İKİNCİ KÖR NOKTA — VE İLKİNDEN BÜYÜĞÜ.
    Kuralı "tam 4 boşluk" sanıyordum. Sözlüğü saydım:

        2 boşluk :   48 satır   ← nöbetçi HİÇ görmüyordu
        4 boşluk : 1295 satır
        6 boşluk :   12 satır   ← iç içe nesne (onbSlides), doğru dışarıda
        8 boşluk :    3 satır   ← aynı

    `walletBalance` tam da o 48'in içindeydi. Yani ilk düzeltmem
    (satır içi ikinci anahtar) doğruydu ama yetmiyordu: anahtar zaten
    hiç OKUNMAYAN bir satırdaydı.

    🆕 SINIF: "BİR KÖR NOKTAYI DÜZELTİRKEN 'ŞİMDİ TAM' DEME — KAPSAMI
    YİNE ÖLÇ. İKİNCİ KÖR NOKTA, BİRİNCİYİ DÜZELTMİŞ OLMANIN VERDİĞİ
    RAHATLIĞIN İÇİNDE SAKLANIR."
    """
    out = []
    for l in yorumsuz(blok).split("\n"):
        bosluk = len(l) - len(l.lstrip(" "))
        if l.strip() and bosluk in (2, 4):
            out.append(l)
    return out


def main():
    print("=" * 70)
    print("ÖLÜ METİN DENETİMİ — yazılmış ama hiç çizilmeyen i18n anahtarı")
    print("=" * 70)

    ham = open(I18N, encoding="utf-8").read()
    trM = re.search(r"^  tr: \{", ham, re.M)
    enM = re.search(r"^  en: \{", ham, re.M)
    if not trM or not enM:
        print("  ✗ tr/en blokları bulunamadı — denetim kör.")
        return 1
    tr_blok = ham[trM.start():enM.start()]
    anahtarlar = [k for k in ust_duzey_anahtarlar(tr_blok) if k not in YAPISAL]

    if not anahtarlar:
        print("  ✗ HİÇ ANAHTAR ÇÖZÜLEMEDİ — desen bozulmuş, denetim kör.")
        return 1

    # ── KULLANIM: üç kanal birden ──────────────────────────────────
    kaynaklar = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            kaynaklar.append(os.path.join(SRC, f))

    nokta, koseli, dizge = set(), set(), set()
    for y in kaynaklar:
        s = yorumsuz(open(y, encoding="utf-8").read())
        if os.path.basename(y) == "i18n.js":
            # Tablonun KENDİSİNDE tanım satırlarını kullanım sayma;
            # yalnız gerçek erişimlere bak.
            s = yorumsuz(ham[enM.end():]) + "\n" + "\n".join(
                l for l in s.split("\n") if re.search(r"\bt\.[a-zA-Z_]", l))
        # 23 Eylül — `t?.x` (isteğe bağlı zincir) de erişimdir; Pickers/
        # FlightField anahtarları bu yüzden "ölü" görünüyordu.
        nokta |= set(re.findall(r"\bt\??\.([a-zA-Z_]\w*)", s))
        koseli |= set(re.findall(r"""\bt\[\s*["']([a-zA-Z_]\w*)["']\s*\]""", s))
        dizge |= set(re.findall(r"""["']([a-zA-Z_]\w{3,})["']""", s))

    # `t["e_" + kod]` gibi ÖNEK birleştirmeler: öneki topla, o önekle
    # başlayan her anahtarı canlı say. `e_own_listing` bu kanaldan geliyor.
    onekler = set()
    for y in kaynaklar:
        s = yorumsuz(open(y, encoding="utf-8").read())
        for m in re.finditer(r"""["']([a-z]\w*_)["']\s*\+""", s):
            onekler.add(m.group(1))

    def canli(k):
        if k in nokta or k in koseli or k in dizge:
            return True
        return any(k.startswith(o) for o in onekler)

    olu = sorted(k for k in anahtarlar if not canli(k))

    # 🔴 ÜÇÜNCÜ KANAL GEVŞEK VE BUNU YAZIYORUM.
    # `dizge` kanalı kaynakta geçen HER 4+ harfli tırnaklı diziyi
    # "kullanım" sayıyor — `t["x"]` kalıbını yakalamak için gerekli,
    # ama yan etkisi var: sözlükteki `credits` anahtarı, alakasız bir
    # yerdeki `"credits"` dizgesi yüzünden CANLI görünüyordu. Oysa
    # hiçbir ekranda çizilmiyordu (v5.5.0'da silindi).
    # Kanalı kapatmıyorum (gerçek kullanımları var), ama yalnız ONDAN
    # canlı görünenleri AYRI listeliyorum: kırmızı yakmaz, görünür olur.
    # 🆕 SINIF: "BİR DENETİMİN GEVŞEK KANALINI KAPATAMIYORSAN EN
    # AZINDAN GÖRÜNÜR KIL — SESSİZ BİR GEVŞEKLİK, OLMAYAN BİR
    # DENETİMDEN DAHA TEHLİKELİDİR."
    supheli = sorted(k for k in anahtarlar
                     if k not in olu and k not in nokta and k not in koseli
                     and not any(k.startswith(o) for o in onekler))

    print("\n  Üst düzey TR anahtarı: %d" % len(anahtarlar))
    print("  Dinamik önek kanalı:   %s" % (", ".join(sorted(onekler)) or "—"))
    print("  ÖLÜ (hiç çizilmeyen):  %d" % len(olu))
    for k in olu:
        print("      %s" % k)
    print("  ŞÜPHELİ (yalnız gevşek dizge kanalıyla canlı): %d" % len(supheli))
    for k in supheli[:20]:
        print("      · %s" % k)
    if len(supheli) > 20:
        print("      · … +%d tane daha" % (len(supheli) - 20))

    butce = None
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f).get("olu")

    hata = 0
    if butce is not None and len(olu) > butce:
        print("\n  ✗ ÖLÜ METİN ARTMIŞ: %d → %d" % (butce, len(olu)))
        print("    Bir anahtar yazdıysan onu ÇİZ; çizmeyeceksen yazma.")
        hata = 1
    elif butce is not None:
        print("\n  ✓ Ölü metin artmadı (bütçe: %d)." % butce)

    if not hata and (butce is None or len(olu) < butce):
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump({"olu": len(olu)}, f, indent=1)
        print("  · bütçe güncellendi (yalnız aşağı)")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Ölü metin bulgusu var.")
        return 1
    print("✓ Ölü metin denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
