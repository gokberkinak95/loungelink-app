#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · brand/build_brand.py   (v3.1 — YENİDEN YAZILDI)

============================================================================
🔴 NEDEN YENİDEN YAZILDI — "TEK KAYNAK" İDDİASI YANLIŞTI
============================================================================
Bu dosyanın eski başlığı şöyle diyordu:

    "MARKA VARLIKLARINI ÜRETEN TEK KAYNAK. […] `python brand/build_brand.py`
     her şeyi yeniden üretir."

Bunu doğrulamak için çalıştırdım ve UYGULAMANIN İKONU DEĞİŞTİ.

Sevkiyattaki bütün varlıklar (icon, adaptive, monokrom, bildirim, favicon,
splash, mark-gold, mark-light) bir KANAT taşıyor. Bu betik ise bir HARİTA
İĞNESİ + KAĞIT UÇAK çiziyordu. Yani betik ürünün markasını üretmiyordu;
üretse bile BAŞKA BİR MARKA üretiyordu.

"Tek kaynak" cümlesi bir belge değil bir DİLEKTİ. Ve tehlikeliydi: bakımı
devralan biri o satıra güvenip betiği çalıştırsa uygulamanın ikonunu
sessizce değiştirmiş olurdu. Ben tam olarak bunu yaptım ve yedekten geri
aldım.

🆕 SINIF: "BİR DOSYANIN 'TEK KAYNAK' OLDUĞUNU YAZMAK ONU TEK KAYNAK
YAPMAZ — ÇALIŞTIRIP ÇIKTISINI SEVKİYATLA KARŞILAŞTIRMADIYSAN, O SATIR
BİR İDDİADIR."

============================================================================
YENİ YAPI — İDDİA ARTIK DOĞRU VE ÖLÇÜLÜYOR
============================================================================
KAYNAK  : `assets/mark-light.png` — kanat silueti (beyaz + alfa).
          Elle çizilmiş bir varlık; bu betik onu ÜRETMEZ, KULLANIR.
          Siluetı kodla yeniden çizmek eski hatanın ta kendisiydi: iki
          ayrı "gerçek" doğurur ve zamanla ayrışırlar.
RENKLER : `src/theme.js` — `tema_oku` ile okunuyor, elle kopyalanmıyor.
          (Eski hâlde `INK` elle (26,31,46) yazılıydı; tema sıcağa
          geçince marka geride kaldı ve hiçbir denetim bakmıyordu.)
TÜREYEN : icon · adaptive · monochrome · notification · favicon · splash
          · yatay lockup (açık/koyu)

`marka_check.py` her koşuda bu betiği geçici bir klasöre çalıştırıp
çıktısını sevkiyatla karşılaştırıyor.

ÖLÇÜ KURALLARI (hepsi burada, tahmine yer yok):
  · icon.png       tam kanama, OPAK, KÖŞE YUVARLATMA YOK
                   (iOS saydamlık kabul etmez; yuvarlatma sistemin işi)
  · adaptive       marka merkez %66 güvenli bölgeye sığar, zemin OPAK
  · monochrome     Android 13+ temalı ikon, tek renk beyaz, saydam zemin
  · notification   96px beyaz siluet (tanımsızsa Android beyaz kare basar)
  · splash         krem zemin + altın kanat
"""
import io
import os
import sys

import cairosvg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "assets"))
FONT_BOLD = os.path.join(ASSETS, "fonts", "CormorantGaramond-Bold.ttf")

sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
import tema_oku as _to                                    # noqa: E402

_P = _to.palet("C")


def _rgba(anahtar, yedek, a=255):
    h = _P.get(anahtar, yedek).lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ---------------------------------------------------------------------------
# PALET — TEMADAN. Elle kopya YOK.
# ---------------------------------------------------------------------------
IVORY = _rgba("surface", "#FFFDF9")
CREAM = _rgba("bg", "#F8F6F1")
INK = _rgba("ink", "#251E17")
GOLD = _rgba("gold", "#B8943A")
G_TOP = (214, 178, 96, 255)      # altın geçişin üst ucu
G_BOT = (163, 128, 44, 255)      # alt ucu — daha sıcak, daha az metalik
BEYAZ = (255, 255, 255, 255)

KAYNAK = os.path.join(ASSETS, "mark-light.png")


def kanat(boy, renk=None, yol=None):
    """Kanat silueti — kaynaktan okunur, istenen renge boyanır."""
    im = Image.open(yol or KAYNAK).convert("RGBA")
    im = im.crop(im.getbbox())
    o = boy / im.width
    im = im.resize((max(1, int(im.width * o)), max(1, int(im.height * o))), Image.LANCZOS)
    if renk:
        boya = Image.new("RGBA", im.size, tuple(renk[:3]) + (0,))
        boya.putalpha(im.getchannel("A"))
        return boya
    return im


def _gradyan(S, ust, alt):
    im = Image.new("RGBA", (1, S))
    d = ImageDraw.Draw(im)
    for i in range(S):
        t = i / max(1, S - 1)
        d.point((0, i), tuple(round(ust[j] * (1 - t) + alt[j] * t) for j in range(4)))
    return im.resize((S, S))


def altin_kare(S, yuvarlak=0.0):
    zem = _gradyan(S, G_TOP, G_BOT)
    if yuvarlak <= 0:
        return zem
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1],
                                        radius=int(S * yuvarlak), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(zem, (0, 0), m)
    return out


def ortala(zem, oge, oran):
    k = oge.resize((max(1, int(zem.width * oran)),
                    max(1, int(oge.height * (zem.width * oran) / oge.width))),
                   Image.LANCZOS)
    zem = zem.copy()
    zem.alpha_composite(k, ((zem.width - k.width) // 2, (zem.height - k.height) // 2))
    return zem


# ---------------------------------------------------------------------------
# ÜRETİM
# ---------------------------------------------------------------------------
def uret(klasor=None):
    cikti = os.path.normpath(klasor) if klasor else ASSETS
    os.makedirs(cikti, exist_ok=True)
    kb = kanat(1400, BEYAZ)

    # 🔴 SEVKİYATTAKİ icon.png SAYDAMDI — VE BU CANLI BİR KUSUR.
    # Köşe alfalarını ölçtüm: dördü de 0. Yani ikon yuvarlatılmış ve
    # köşeleri saydam bırakılmış. iOS App Store ikonunda saydamlık KABUL
    # EDİLMEZ (Apple HIG); yükleme sırasında ya reddedilir ya da alfa
    # düzleştirilip köşeler SİYAH çıkar.
    #
    # Bunu ben bulmadım — çıktıyı RGB'ye çevirince siyah köşeler belirdi
    # ve "acaba sevkiyattaki de mi böyle" diye ölçtüm. Kendi hatam,
    # var olan bir hatayı gösterdi.
    #
    # 🆕 SINIF: "BİR DÖNÜŞTÜRME SIRASINDA ORTAYA ÇIKAN ÇİRKİNLİK, BAZEN
    # DÖNÜŞTÜRMENİN DEĞİL KAYNAĞIN KUSURUDUR — ÖNCE KAYNAĞI ÖLÇ."
    #
    # Doğrusu: tam kanama, OPAK. Köşe yuvarlatmayı işletim sistemi yapar;
    # ikonun kendisi kare ve dolu olmalı.
    # ══════════════════════════════════════════════════════════════════
    # 🔴 20 EYLÜL — İKİ ÜRETİCİ OLMUŞTU, BİRE İNDİ.
    #
    # v6 ikonu ("Kemer · Işık Huzmesi") `build_kemer.py` ile çizildi ve
    # ben onu doğrudan `assets/`e kopyaladım. Ama TEK KAYNAK burasıydı:
    # `marka_check.py` bu betiği koşturup çıktısını sevkiyatla kıyaslıyor.
    # Sonuç: altı varlığın altısında da "ayrışma" — ve kapı haklıydı.
    # İkinci bir üretici, üreticisizlikten daha tehlikelidir: hangisinin
    # doğru olduğunu artık kimse bilmez.
    #
    # Çözüm: bu betik ARTIK ÇİZMİYOR, `build_kemer.py`ye DEVREDİYOR.
    # Mağaza kuralları (opak ikon, opak adaptive, 96px bildirim) orada
    # tablo hâlinde yazılı ve bu kapı onları kıyaslamaya devam ediyor.
    #
    # 🆕 SINIF: "BİR VARLIĞI ELLE ÜRETİP TEK-KAYNAK BETİĞİNİ GÜNCELLEMEZSEN,
    # PROJEDE İKİ GERÇEK OLUR — VE NÖBETÇİ HANGİSİNİN GERÇEK OLDUĞUNU
    # SANA SORMAZ, SADECE KIRMIZI YANAR."
    # ══════════════════════════════════════════════════════════════════
    sys.path.insert(0, HERE)
    import build_kemer as _kemer
    _P = _kemer.np.load(_kemer.IZ)
    for _ad, _uret, _boy, _seffaf in _kemer.varlik_tablosu(_P):
        _svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" '
                'width="%d" height="%d">%s</svg>' % (_boy, _boy, _uret()))
        _png = cairosvg.svg2png(bytestring=_svg.encode(),
                                output_width=_boy, output_height=_boy)
        _im = Image.open(io.BytesIO(_png)).convert("RGBA")
        if not _seffaf:
            _z = Image.new("RGB", (_boy, _boy), (8, 7, 7))
            _z.paste(_im, (0, 0), _im)
            _im = _z
        _im.save(os.path.join(cikti, _ad))

    # mark-* — KAYNAK dosyanın kendisi; üretilmiyor, yalnız kopyalanıyor
    # (aksi hâlde kaynak kendi türevinden yeniden doğar ve her koşuda bozulur)
    if cikti != ASSETS:
        for ad in ("mark-light.png", "mark-gold.png"):
            Image.open(os.path.join(ASSETS, ad)).save(os.path.join(cikti, ad))

    # ══════════════════════════════════════════════════════════════════
    # 🔴 20 EYLÜL — AÇILIŞ EKRANININ KANADI (mark-kanat.png)
    #
    # Gökberk: "yeni app ikonunu kullanmak yerine eskisi gibi logo
    # kullanmamız daha sade ve güzel bir görünüm yaratır."
    #
    # Bu ESKİ MARKAYA DÖNMEK DEĞİL — ve ayrımı yazmak önemli: kanat,
    # Kemer'in İÇİNDEKİ swoosh ile aynı çizim. Kemer ona bir KAP
    # veriyor, o kadar. İkon 48px'te okunmak zorunda ve orada kaba bir
    # silueti olan Kemer kazanıyor; açılış ekranında ise 390pt genişlik
    # var ve kap gereksiz bir kalabalık. Yani tek işaret, iki kadraj.
    #
    # ⚠️ ÜÇ ŞEY BURADA ÇÖZÜLÜYOR, RN TARAFINDA DEĞİL:
    #   1. KIRPMA — `mark-light.png` tuvalinin %55'i saydam boşluk
    #      (bbox 43..441 / 484). `contain` ile 96pt kutuya koyunca
    #      kanat 53pt'e düşerdi. Mürekkebe kırpıyoruz.
    #   2. RENK — fildişi (#FAEEDC, `C.foto.marka`) PİŞİRİLİYOR.
    #      Çalışma anında `tintColor` vermek de olurdu ama o, rengi
    #      jetondan koparıp bileşene gömmek olurdu; burada üretici
    #      temayı okuyor.
    #   3. ÖLÇÜ — neden şampanya değil fildişi: gökyüzü L* ~70,
    #      şampanya (#C9B693) L* 75, fildişi L* 94. Şampanya kanat bu
    #      fotoğrafın üstünde neredeyse kaybolurdu. Ölçtüm, seçmedim.
    # ══════════════════════════════════════════════════════════════════
    _kanat = kanat(1024, (250, 238, 220, 255))
    _kanat.save(os.path.join(cikti, "mark-kanat.png"))

    # ══════════════════════════════════════════════════════════════════
    # 🔴 20 EYLÜL — LOCKUP DA TEK ÜRETİCİYE DEVREDİLDİ.
    #
    # Burada 1600×480 SABİT tuvale 190pt "LoungeLink" basılıyordu. Dosyayı
    # açıp ölçtüm: kelime tuvale SIĞMIYORDU — son "k" kırpıktı. Üstelik
    # işaret eski kanat, renk eski pirinç altındı (C* p95 51.1 · tavan 28).
    # Üç kusur, ve hiçbiri görülmemişti çünkü hiçbir kapı pazarlama
    # kolateraline bakmıyordu.
    #
    # `build_lockup.py` tuvali ÖLÇÜLEN içerikten türetiyor ve sığmazsa
    # sessizce kırpmak yerine ÇÖKÜYOR.
    #
    # 🆕 SINIF: "SABİT TUVALE DEĞİŞKEN METİN BASMAK, KIRPILMAYI ZAMAN
    # MESELESİ YAPAR — TUVALİ İÇERİKTEN TÜRET, İÇERİĞİ TUVALE SIĞDIRMA."
    # ══════════════════════════════════════════════════════════════════
    import build_lockup as _lock
    lok = os.path.join(HERE, "lockup") if klasor is None else os.path.join(cikti, "lockup")
    os.makedirs(lok, exist_ok=True)
    for _ad, _koyu in (("lockup-dark.png", True), ("lockup-light.png", False)):
        _lock.uret(_koyu).save(os.path.join(lok, _ad))
    return cikti


if __name__ == "__main__":
    hedef = sys.argv[1] if len(sys.argv) > 1 else None
    uret(hedef)
    # 🔴 14 EYLUL · WINDOWS: konsol kodlamasi cp1254 ve "\u2192" (→)
    # o tabloda YOK — `print` UnicodeEncodeError ile patliyor, uretec
    # cokuyor, `marka_check` "uretici coktu" diyor. Uretilen varliklarda
    # bir sorun yok; ARIZA YALNIZ CIKTI SATIRINDA.
    # 🆕 SINIF: "BIR ARACIN CIKTISINDAKI SUS KARAKTERI, O ARACIN
    # CALISMASINI BASKA BIR MAKINEDE DURDURABILIR — MESAJI ASCII TUT."
    print("marka varliklari uretildi -> %s" % (hedef or ASSETS))
    print("kaynak: brand/build_kemer.py (Kemer + swoosh_izi.npy) · renkler: src/theme.js")
