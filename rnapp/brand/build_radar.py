#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_radar.py — TASARIMIN RADAR İŞARETİNİ GERÇEK BİR GLİFE ÇEVİRİR.

============================================================================
🔴 NEDEN: IONICONS'TA BU İŞARET YOK — 1338 GLİFİ TEK TEK ÖLÇTÜM
============================================================================
Gökberk "tasarımdaki keşfet logosunun kullanımı ve icon şekli ile app
önizlemesi farklı" dedi. Cevabı gözle vermek yerine ölçtüm: tasarımın
radar SVG'sini 128×128 maskeye çizdim, Ionicons'un **1338 glifinin
hepsini** aynı kutuya çizdim ve IoU (kesişim/birleşim) hesapladım.

    en iyi eşleşme    flashlight-sharp   0.500   ← anlamı ALAKASIZ
                      ticket             0.435
                      build              0.431
    aday saydıklarım  globe-outline      0.326
                      compass-outline    0.299
                      wifi-outline       0.222
    ŞU AN GÖNDERİLEN  radio-outline      0.132   ← EN KÖTÜSÜ

Yani: (a) Ionicons'ta radar YOK, (b) benim seçtiğim `radio-outline`
saydığım adaylar arasında ölçülen EN KÖTÜ eşleşme. "Aynı fikir, sinyal
yayılıyor" diye savunmuştum — sayı o savunmayı çürüttü.

🆕 SINIF: "BİR SEÇİMİ 'BENZER' DİYE SAVUNMADAN ÖNCE BENZERLİĞİ ÖLÇ —
GÖZ, KENDİ VERDİĞİ KARARI HAKLI ÇIKARMAK İÇİN BENZERLİK UYDURUR."

⚠️ ÖLÇÜMÜMDEKİ HATA DA BURAYA YAZILIYOR: ilk taramada merkez daireyi
DOLU çizmiştim. Tasarımın SVG'si `fill="none" stroke=...` — yani merkez
de bir HALKA. Skorlar bu yüzden hafifçe kaymıştı; sıralama değişmedi
(hiçbiri 0.5'i geçmiyor) ama sayıyı ürettiğim yolu düzeltmeden
raporlamak, ölçümü süslemek olurdu.

============================================================================
NEDEN AYRI FONT — ÜÇ YOL ÖLÇÜLDÜ
============================================================================
 1 · IONICONS.TTF'İ YAMALA — glifi Özel Kullanım Alanına ekle,
     `Ionicons.glyphMap`i çalışma anında genişlet. REDDEDİLDİ:
     `node_modules` her `npm ci`de sıfırlanır; yama sessizce kaybolur
     ve en çok kullanılan sekmede BOŞ KARE kalır.

 2 · react-native-svg EKLE — tek bir ikon için yerel (native) bir
     bağımlılık, yeni bir derleme ve daha büyük paket. REDDEDİLDİ:
     bedeli faydanın kat kat üstünde.

 3 · TEK GLİFLİK KENDİ FONTUMUZ  ← seçilen
     `@expo/vector-icons` zaten `createIconSet(glyphMap, aile, ttf)`
     API'sini dışa veriyor — Ionicons'un kendisi de tam olarak böyle
     kuruluyor. Yeni yerel bağımlılık YOK, `node_modules` yaması YOK,
     dosya bizim depomuzda ve lisansı bizim.

============================================================================
ÇİZİM — TASARIMIN SVG'SİNDEN BİREBİR
============================================================================
    <circle cx="12" cy="12" r="3"/>
    <path d="M12 3a9 9 0 0 1 9 9  M12 6.5a5.5 5.5 0 0 1 5.5 5.5"/>
    <path d="M12 21a9 9 0 0 1-9-9 M12 17.5A5.5 5.5 0 0 1 6.5 12"/>
    stroke-width 1.7 · stroke-linecap round

Yani: merkezde r=3 HALKA, sağ-üstte r=9 ve r=5.5 çeyrek yaylar,
sol-altta aynı ikisi (180° dönmüş). Dönel simetri kasıtlı — işaret
"tarama" değil, "iki yönlü sinyal" anlatıyor.

Konturlar burada DOLU alanlar olarak üretiliyor (font glifi çizgi
tutmaz): her yay, iç ve dış yarıçapı olan bir halka dilimi + iki uçta
yarım daire (yuvarlak kapak).
"""
import math
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

HERE = os.path.dirname(os.path.abspath(__file__))
CIKTI = os.path.join(HERE, "..", "assets", "fonts", "LLSimge.ttf")

EM = 1000
VB = 24.0          # tasarımın viewBox'ı
SW = 1.7           # stroke-width
ADIM = 4           # yay örnekleme adımı (derece) — 4° = çeyrek yayda 23 nokta

# ── IONICONS'UN KUTUSU — ÖLÇÜLDÜ, TAHMİN EDİLMEDİ ──────────────────
# 🔴 İLK YAZIMDA KENDİ ÖLÇEĞİMİ UYDURDUM (em'in %72'si, ana hattın
# %10 üstü) ve sekme çubuğunda radar diğer dört ikondan görünür biçimde
# KÜÇÜK ve SOLA KAÇIK çıktı.
#
# Sebep: `Ikon` bileşeni hem ikonu hem etiketi SABİT bir kutuda
# ortalıyor ve o kutu, Ionicons'un metriklerine göre hizalanıyor.
# Yeni bir aile eklerken glifi "güzel" yapmak yetmez; ESKİ AİLENİN
# KUTUSUNA oturması gerekir, yoksa tek bir sekme diğer dördünden kayar.
#
# Ionicons'tan ölçtüm (`radio-outline`, fontTools):
#     unitsPerEm 1000 · ilerleme 1000 · kutu x 0..1000 · y 0..848
# Yani glif ana hattın üstünde 848 birim yüksekliğinde ve ilerlemenin
# TAMAMINI kaplıyor. Bizimki de öyle olacak.
#
# 🆕 SINIF: "BİR SİSTEME YENİ BİR PARÇA EKLERKEN ONU 'DOĞRU' YAPMA —
# MEVCUT PARÇALARIN METRİĞİNİ ÖLÇ VE ONA UY; SİSTEMDE DOĞRULUK
# TEKİL DEĞİL, ORTAK BİR ÇERÇEVEDİR."
ILERLEME = 1000    # Ionicons ile aynı
MUREKKEP_BOY = 848  # Ionicons `radio-outline`ın ana hat üstü yüksekliği

# Aşağıdakiler main()'de ÖLÇÜLEREK dolduruluyor — hesapla değil, çiz-ölç-düzelt.
OLCEK = 1.0
DX = 0.0
DY = 0.0


def _d(x, y):
    """SVG koordinatı (y aşağı) → font koordinatı (y yukarı)."""
    return (x * OLCEK + DX, (VB - y) * OLCEK + DY)


def _yay_konturu(kalem, cx, cy, r, a0, a1, w):
    """Bir yayın DOLU konturunu çizer: dış yay ileri, iç yay geri,
    iki uçta yuvarlak kapak.

    a0/a1 SVG açıları (derece, 0° = sağ, saat yönü çünkü y aşağı).
    """
    ri, ro = r - w / 2.0, r + w / 2.0
    n = max(3, int(abs(a1 - a0) / ADIM))
    acilar = [a0 + (a1 - a0) * i / n for i in range(n + 1)]

    nok = []
    # dış yay ileri
    for a in acilar:
        t = math.radians(a)
        nok.append(_d(cx + ro * math.cos(t), cy + ro * math.sin(t)))
    # bitiş kapağı (yarım daire, dıştan içe)
    t1 = math.radians(a1)
    mx, my = cx + r * math.cos(t1), cy + r * math.sin(t1)
    for i in range(1, 8):
        f = math.pi * i / 8.0
        # kapak, yay teğetine dik düzlemde döner
        dx, dy = math.cos(t1), math.sin(t1)
        px, py = -dy, dx          # yay teğeti
        cx2 = math.cos(f); sy2 = math.sin(f)
        nok.append(_d(mx + (w / 2.0) * (dx * cx2 + px * sy2),
                      my + (w / 2.0) * (dy * cx2 + py * sy2)))
    # iç yay geri
    for a in reversed(acilar):
        t = math.radians(a)
        nok.append(_d(cx + ri * math.cos(t), cy + ri * math.sin(t)))
    # başlangıç kapağı
    t0 = math.radians(a0)
    mx, my = cx + r * math.cos(t0), cy + r * math.sin(t0)
    for i in range(1, 8):
        f = math.pi * i / 8.0
        dx, dy = -math.cos(t0), -math.sin(t0)
        px, py = dy, -dx
        cx2 = math.cos(f); sy2 = math.sin(f)
        nok.append(_d(mx + (w / 2.0) * (dx * cx2 + px * sy2),
                      my + (w / 2.0) * (dy * cx2 + py * sy2)))

    kalem.moveTo(nok[0])
    for p in nok[1:]:
        kalem.lineTo(p)
    kalem.closePath()


def _halka(kalem, cx, cy, r, w):
    """Kapalı halka: dış çember saat yönünün tersine, iç çember tersine.

    ⚠️ YÖN ÖNEMLİ. TrueType dolguyu non-zero kuralıyla yapar; iki
    çember AYNI yönde çizilirse deliğin yerinde dolu bir disk kalır —
    yani tasarımın halkası dolu bir noktaya döner. İlk denememde tam
    bunu yaptım; aşağıdaki nöbetçi (mürekkep oranı) yakaladı.
    """
    ri, ro = r - w / 2.0, r + w / 2.0
    n = 48
    # 🔴 İLK YÖN SEÇİMİM YANLIŞTI VE HALKA DOLU DİSK ÇIKTI.
    # `_d()` y'yi ters çeviriyor; yani SVG'de saat yönü olan bir çember
    # font uzayında saat yönünün TERSİ oluyor. İç çemberi `reverse()`
    # ile ters çevirmek, iki çemberi AYNI yöne getirdi — non-zero kuralı
    # deliği doldurdu. Doğrusu: DIŞ çember ters, iç çember düz.
    # Gözle "radar gibi duruyor" diyordum; merkez noktanın DOLU mu
    # HALKA mı olduğunu ancak pikseli sayınca gördüm.
    for yar, ters in ((ro, True), (ri, False)):
        nok = []
        for i in range(n):
            a = 2 * math.pi * i / n
            nok.append(_d(cx + yar * math.cos(a), cy + yar * math.sin(a)))
        if ters:
            nok.reverse()
        kalem.moveTo(nok[0])
        for p in nok[1:]:
            kalem.lineTo(p)
        kalem.closePath()


def radar_glifi(glyphSet):
    kalem = TTGlyphPen(glyphSet)
    _halka(kalem, 12, 12, 3, SW)
    # sağ-üst: 270°→360° (SVG'de y aşağı olduğu için bu, ekranda
    # saat 12'den saat 3'e giden çeyrek)
    for r in (9, 5.5):
        _yay_konturu(kalem, 12, 12, r, 270, 360, SW)
    # sol-alt: 90°→180°
    for r in (9, 5.5):
        _yay_konturu(kalem, 12, 12, r, 90, 180, SW)
    return kalem.glyph()


KOD = 0xE900          # Özel Kullanım Alanı
AD = "radar"


def _android_sertlestir(yol):
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.tables._c_m_a_p import CmapSubtable
    f = TTFont(yol)
    nm = f["name"]
    for pid, eid, lid in [(1, 0, 0), (3, 1, 1033)]:
        nm.setName("LLSimge Regular", 3, pid, eid, lid)
        nm.setName("LLSimge", 4, pid, eid, lid)
        nm.setName("LLSimge", 16, pid, eid, lid)
        nm.setName("Regular", 17, pid, eid, lid)
    uni = [t for t in f["cmap"].tables if t.platformID == 3][0]
    u0 = CmapSubtable.newSubtable(4); u0.platformID = 0; u0.platEncID = 3; u0.language = 0; u0.cmap = dict(uni.cmap)
    mac = CmapSubtable.newSubtable(0); mac.platformID = 1; mac.platEncID = 0; mac.language = 0; mac.cmap = {}
    f["cmap"].tables = [u0, mac, uni]
    if "ltag" in f:
        del f["ltag"]
    f["OS/2"].fsType = 0
    f["head"].flags |= 0x0008 | 0x0001
    f.save(yol)


def main():
    # 🔴 GLİF EM KUTUSUNDA ORTALANMIYORDU — VE BUNU TAHMİNLE
    # DÜZELTMEYE ÇALIŞMAK İKİNCİ BİR HATAYDI.
    # İlk denemem `hmtx`in yan boşluk (lsb) alanını glifin xMin'inden
    # FARKLI vermekti. TrueType'ta lsb'nin xMin'e EŞİT olması beklenir;
    # ayrıştırıcılar bu ikisi ayrışınca farklı davranır — yani düzeltme
    # oluşturucuya göre değişen bir sonuç verirdi.
    # Doğrusu: METRİĞİ değil KONTURU kaydırmak. Glif önce ölçülüyor,
    # gereken kayma hesaplanıyor, sonra o kaymayla YENİDEN çiziliyor.
    #
    # 🆕 SINIF: "BİR ŞEYİ YERİNE OTURTMAK İÇİN ONU TARİF EDEN SAYIYI
    # DEĞİL, KENDİSİNİ TAŞI — TARİFİ BOZMAK, SONUCU OKUYANA GÖRE
    # DEĞİŞTİRİR."
    global DX, DY, OLCEK
    gen = ILERLEME

    # 1. GEÇİŞ — birim ölçekte çiz, gerçek kutuyu ÖLÇ.
    OLCEK, DX, DY = 1.0, 0.0, 0.0
    g1 = radar_glifi(None)
    g1.recalcBounds({AD: g1})
    print("  1. geçiş kutusu  x %.1f..%.1f  y %.1f..%.1f"
          % (g1.xMin, g1.xMax, g1.yMin, g1.yMax))

    # 2. GEÇİŞ — ölçüye göre ölçekle.
    #
    # ⚠️ TEK GEÇİŞ YETMİYOR VE SEBEBİ İLK DENEMEDE ÇIKTI: `recalcBounds`
    # koordinatları TAM SAYIYA yuvarlar. Birim ölçekte gerçek kutu
    # 2.15..21.85 (19.7 birim) ama ölçüm 2..22 (20 birim) diyor —
    # %1.5'lik bir yanılma. 848 hedefine 835 ile varıyordum.
    # Çözüm ölçüyü "düzeltmek" değil, ÖLÇMEYİ TEKRARLAMAK: ölçekle,
    # yeniden ölç, oranı uygula. İki adımda 848'e oturuyor.
    #
    # 🆕 SINIF: "YUVARLANMIŞ BİR ÖLÇÜMDEN HESAPLANAN ÖLÇEK, HATAYI
    # BÜYÜTEREK TAŞIR — ÖLÇÜMÜ DÜZELTME, ÖLÇMEYİ TEKRARLA."
    OLCEK = MUREKKEP_BOY / float(g1.yMax - g1.yMin)
    for _ in range(4):
        g2 = radar_glifi(None)
        g2.recalcBounds({AD: g2})
        boy = g2.yMax - g2.yMin
        if abs(boy - MUREKKEP_BOY) <= 1:
            break
        OLCEK *= MUREKKEP_BOY / float(boy)
    DX = (gen - (g2.xMax - g2.xMin)) / 2.0 - g2.xMin   # yatayda ortala
    DY = -g2.yMin                                       # ana hatta otur

    fb = FontBuilder(EM, isTTF=True)
    fb.setupGlyphOrder([".notdef", AD])
    fb.setupCharacterMap({KOD: AD})

    bos = TTGlyphPen(None)
    gs = {}
    gs[".notdef"] = bos.glyph()
    gs[AD] = radar_glifi(None)
    fb.setupGlyf(gs)

    gl = gs[AD]
    gl.recalcBounds(gs)
    print("  son kutu         x %d..%d  y %d..%d · ilerleme %d"
          % (gl.xMin, gl.xMax, gl.yMin, gl.yMax, gen))
    fb.setupHorizontalMetrics({".notdef": (gen, 0), AD: (gen, gl.xMin)})

    # ── NÖBETÇİ 0: KUTU IONICONS'UNKİYLE AYNI MI ───────────────────
    # ±2 birim tolerans (yay örneklemesinden gelen yuvarlama).
    if abs((gl.yMax - gl.yMin) - MUREKKEP_BOY) > 2:
        print("✗ YÜKSEKLİK TUTMUYOR: %d, olması gereken %d — sekmede "
              "diğer ikonlardan farklı boyda görünür."
              % (gl.yMax - gl.yMin, MUREKKEP_BOY))
        return 1
    if abs(gl.yMin) > 2:
        print("✗ ANA HATTA OTURMUYOR (yMin=%d) — dikeyde kayar." % gl.yMin)
        return 1
    if abs((gl.xMin + gl.xMax) / 2.0 - gen / 2.0) > 3:
        print("✗ YATAYDA ORTALI DEĞİL (merkez %.1f, olması gereken %.1f)."
              % ((gl.xMin + gl.xMax) / 2.0, gen / 2.0))
        return 1
    fb.setupHorizontalHeader(ascent=int(EM * 0.80), descent=-int(EM * 0.20))
    fb.setupNameTable({
        "familyName": "LLSimge",
        "styleName": "Regular",
        "psName": "LLSimge-Regular",
        "version": "1.0",
        "copyright": "LoungeLink — kendi çizimimiz; dış lisans yok.",
    })
    fb.setupOS2(sTypoAscender=int(EM * 0.80), sTypoDescender=-int(EM * 0.20),
                usWinAscent=int(EM * 0.80), usWinDescent=int(EM * 0.20))
    fb.setupPost()
    os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
    fb.save(CIKTI)
    # 🔴 3 EYLÜL — ANDROID SERTLEŞTİRMESİ. Cihazda ikon fontları düşmüştü.
    # fontTools'un varsayılan çıktısı Mac (1,0) cmap'i ve nameID 3/4'ü
    # yazmıyor, ayrıca `ltag` tablosu ekliyor; masaüstünde sorun olmayan
    # bu eksikler bazı Android font yollarında (Skia/FreeType) fontun
    # reddedilmesine yol açabiliyor. Tablolar burada tamamlanıyor ki
    # her yeniden üretimde sertleştirme kaybolmasın.
    _android_sertlestir(CIKTI)
    print("✓ %s  (%d bayt)" % (os.path.relpath(CIKTI, HERE), os.path.getsize(CIKTI)))

    # ── NÖBETÇİ: GLİF GERÇEKTEN ÇİZİLİYOR MU ───────────────────────
    # 🔴 BU KAPI OLMASAYDI RİSK ŞUYDU: en çok kullanılan sekmede BOŞ
    # KARE. Bir ikon fontunun "kurulmuş" olması çizdiği anlamına
    # gelmez — glif boş da olabilir, kontur yönü ters de olabilir.
    # İkisi de sessizdir. Bu yüzden font YAZILDIKTAN SONRA PIL ile
    # geri okunup MÜREKKEBİ SAYILIYOR.
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("  ⚠ PIL yok — glif doğrulanamadı")
        return 0
    N = 96
    ft = ImageFont.truetype(CIKTI, int(N * 0.86))
    im = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(im)
    d.text((N * 0.07, N * 0.02), chr(KOD), font=ft, fill=255)
    mur = sum(1 for p in im.getdata() if p > 90)
    oran = mur / float(N * N)
    im.point(lambda v: 255 if v > 90 else 0).save(os.path.join(HERE, "radar_glif.png"))
    print("  mürekkep oranı %.3f  (beklenen 0.06–0.30)" % oran)
    if oran < 0.06:
        print("✗ GLİF NEREDEYSE BOŞ — sekmede boş kare çıkar.")
        return 1
    if oran > 0.30:
        print("✗ GLİF DOLU DİSK OLMUŞ — halkanın yönü ters "
              "(non-zero kuralı deliği doldurdu).")
        return 1

    # ── NÖBETÇİ 2: MERKEZ HALKA MI, DOLU NOKTA MI ──────────────────
    # 🔴 BU KAPIYI, İLK ÇIKTIYI GÖZLE "DOĞRU" ONAYLADIKTAN SONRA
    # EKLEDİM. Şekil radar gibi duruyordu ve kabul etmiştim; oysa
    # tasarımın SVG'si `fill="none"` — merkez bir HALKA. Kontur yönünü
    # ters kurduğum için delik dolmuş, ortada DOLU bir nokta kalmıştı.
    # Mürekkep oranı (0.076) bunu göremedi: yaylar ince olduğu için
    # merkezdeki 3 birimlik delik toplam oranı ancak binde birkaç
    # oynatıyor.
    #
    # 🆕 SINIF: "TOPLAM BİR ÖLÇÜ, KÜÇÜK AMA ANLAM TAŞIYAN BİR
    # BÖLGEYİ GİZLER — ANLAMIN DURDUĞU YERİ AYRICA ÖLÇ."
    # ⚠️ SONDA KOORDİNATI TAHMİN ETMEK, İKİNCİ BİR TAHMİN OLURDU.
    # İlk denememde merkezi "kutunun ortası" saydım ve nöbetçi
    # OLMAYAN bir kusuru bildirdi — çünkü glif kutunun ortasında
    # değil, MÜREKKEBİN kutusunun ortasında. Sonda artık gerçek
    # mürekkep sınırından türetiliyor.
    ik_kutu = im.point(lambda v: 255 if v > 90 else 0).getbbox()
    cx = (ik_kutu[0] + ik_kutu[2]) // 2
    cy = (ik_kutu[1] + ik_kutu[3]) // 2
    yaricap = (ik_kutu[3] - ik_kutu[1]) / 2.0
    # tasarımda merkez halkanın yarıçapı 3, en dış yay 9.85 → oran 0.30
    duvar = int(round(yaricap * 3.0 / 9.85))
    mrk = im.getpixel((cx, cy))
    # halkanın çeperini bir dikey taramayla bul: merkezden yukarı
    cepere = [im.getpixel((cx, cy - k)) for k in range(1, duvar + 4)]
    print("  mürekkep kutusu %s · merkez %d (delik: <90) · "
          "çeper taraması %s" % (ik_kutu, mrk, cepere))
    if mrk > 90:
        print("✗ MERKEZ DOLU — tasarımda halka; kontur yönü hâlâ ters.")
        return 1
    if max(cepere) < 90:
        print("✗ MERKEZ HALKASI HİÇ ÇİZİLMEMİŞ.")
        return 1
    print("  ✓ glif çiziliyor · brand/radar_glif.png ile göz kontrolü yapılabilir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
