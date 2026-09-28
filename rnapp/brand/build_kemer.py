#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_kemer.py — LoungeLink v6 ikonu "Kemer · Işık Huzmesi" üretir.

🔴 NEDEN BİR ÜRETEÇ, NEDEN ELLE ÇİZİLMİŞ BİR PNG DEĞİL

`brand/build_altin.py` ile aynı gerekçe: bir marka varlığı kaynaktan
üretilebilir olmalı. Aksi hâlde altı ay sonra "bu gradyanın açısı kaçtı"
sorusunun cevabı kimsede olmaz ve ikon dokunulamaz bir nesneye dönüşür.

🔴 SWOOSH UYDURULMADI

Eğri, mevcut `assets/icon.png`den `cv2.findContours` ile çıkarıldı ve
0..1 genişlik birimine normalize edildi (`sw.npy`). Yani bu, markanın
KENDİ eğrisi — yeniden çizilmiş bir benzeri değil. Kaynağı silinirse
`--izle` ile yeniden çıkarılabilir.

🆕 SINIF: "BİR MARKA VARLIĞINI YENİDEN ÇİZMEK, ONU DEĞİŞTİRMEKTİR.
DEĞİŞTİRMİYORSAN İZİNİ AL."

── ORANLAR (20 Eylül · Gökberk'in Canva referansına göre düzeltildi) ──

İlk denemede swoosh 128 birim genişlikteydi ama kemerin açıklığı 100
birim: kırpılması kaçınılmazdı ve "sığmıyor" olarak göründü. Ölçüler
referanstan yeniden türetildi:

    tuval           220 × 220
    kemer dış       x 44..176   (%60 genişlik, iki yanda %20 boşluk)
    bant kalınlığı  16
    kemer üst       y 40   ·  ayak dibi  y 186
    açıklık         x 60..160 · y 56..186   (100 × 130)
    eşik hattı      x 36..184 · y 186 · 3.4 kalınlık
    swoosh          gen 62 · merkez (107, 132)

`swoosh` merkezi 110 DEĞİL 107: eğrinin kütlesi sağda, uçları solda.
Kutu merkezine hizalanırsa göz onu sağa kaymış görür.

── KALDIRILAN DETAY ──

v1'de kemerin tepesinde bir "biniş kartı yırtma çentiği" vardı (koyu
daire). Gökberk: "kemerin orta üst kısmında neden siyah bir delik var
onu da anlamadım." Açıklama gerektiren bir detay çalışmıyor demektir;
60pt'de baskı hatası gibi okunuyordu. Kaldırıldı.

Kullanım:
    python brand/build_kemer.py            # assets/ değil, ikon_kemer/ altına
    python brand/build_kemer.py --izle     # swoosh izini icon.png'den yeniden çıkar
"""
import io
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "swoosh_izi.npy")
HEDEF = os.path.join(os.path.dirname(KOK), "ikon_kemer")


def izi_cikar(kaynak):
    """Mevcut ikondaki beyaz swoosh'un dış konturunu 0..1 birimine indir."""
    import cv2
    im = np.array(Image.open(kaynak).convert("L"))
    mask = (im > 225).astype(np.uint8) * 255
    mask = cv2.GaussianBlur(mask, (5, 5), 0)
    mask = (mask > 128).astype(np.uint8) * 255
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)
    x, y, w, _h = cv2.boundingRect(c)
    ap = cv2.approxPolyDP(c, 0.00045 * cv2.arcLength(c, True), True)
    p = ap.reshape(-1, 2).astype(float)
    p[:, 0] = (p[:, 0] - x) / w
    p[:, 1] = (p[:, 1] - y) / w
    return p


# ── GEOMETRİ ────────────────────────────────────────────────────────
DIS = ("M110 40 C146 40 176 70 176 106 L176 186 L160 186 L160 106 "
       "C160 78 138 56 110 56 C82 56 60 78 60 106 L60 186 L44 186 L44 106 "
       "C44 70 74 40 110 40 Z")
ACIK = "M110 56 C138 56 160 78 160 106 L160 186 L60 186 L60 106 C60 78 82 56 110 56 Z"

DEFS = """<defs>
<linearGradient id="zemin" x1="0" y1="0" x2="0" y2="1">
 <stop offset="0%" stop-color="#15120F"/><stop offset="52%" stop-color="#0C0B0A"/>
 <stop offset="100%" stop-color="#080707"/></linearGradient>
<radialGradient id="kadife" cx="50%" cy="32%" r="64%">
 <stop offset="0%" stop-color="#D6C3A0" stop-opacity="0.14"/>
 <stop offset="100%" stop-color="#D6C3A0" stop-opacity="0"/></radialGradient>
<linearGradient id="metal" x1="0" y1="0" x2="0.3" y2="1">
 <stop offset="0%" stop-color="#F2E9D8"/><stop offset="26%" stop-color="#DCC9A6"/>
 <stop offset="60%" stop-color="#A88E64"/><stop offset="100%" stop-color="#CBB792"/></linearGradient>
<linearGradient id="metal2" x1="0" y1="0" x2="1" y2="0.7">
 <stop offset="0%" stop-color="#9C8760"/><stop offset="32%" stop-color="#DCC9A6"/>
 <stop offset="68%" stop-color="#F4EBDA"/><stop offset="100%" stop-color="#B49B70"/></linearGradient>
<linearGradient id="ic" x1="0" y1="0" x2="0" y2="1">
 <stop offset="0%" stop-color="#4A423A" stop-opacity="0.85"/>
 <stop offset="100%" stop-color="#171412" stop-opacity="0.95"/></linearGradient>
<linearGradient id="isik" gradientUnits="userSpaceOnUse" x1="0" y1="36" x2="0" y2="112">
 <stop offset="0%" stop-color="#FFFBF4" stop-opacity="0.62"/>
 <stop offset="55%" stop-color="#FFFBF4" stop-opacity="0.26"/>
 <stop offset="100%" stop-color="#FFFBF4" stop-opacity="0"/></linearGradient>
<linearGradient id="isikIc" gradientUnits="userSpaceOnUse" x1="0" y1="52" x2="0" y2="118">
 <stop offset="0%" stop-color="#FFFBF4" stop-opacity="0.22"/>
 <stop offset="100%" stop-color="#FFFBF4" stop-opacity="0"/></linearGradient>
<clipPath id="kemerKirp"><path d="M110 40 C146 40 176 70 176 106 L176 186 L160 186 L160 106 C160 78 138 56 110 56 C82 56 60 78 60 106 L60 186 L44 186 L44 106 C44 70 74 40 110 40 Z"/></clipPath>
<filter id="yum" x="-60%" y="-60%" width="220%" height="220%">
 <feGaussianBlur stdDeviation="8"/></filter>
<filter id="haf" x="-60%" y="-60%" width="220%" height="220%">
 <feGaussianBlur stdDeviation="2.2"/></filter>
</defs>"""


def swoosh_yolu(P, cx=107.0, cy=132.0, gen=62.0):
    a = P.copy() * gen
    a[:, 0] += cx - gen / 2
    a[:, 1] += cy - gen * 0.462 / 2
    return "M " + " L ".join("%.2f,%.2f" % (u, v) for u, v in a) + " Z"


# ══════════════════════════════════════════════════════════════════════
# 🔴 23 EYLÜL — İŞARET KANVASIN ORTASINDA DEĞİLDİ (Gökberk #1 · #2 · #10)
#
# Ölçüm (mürekkep kutusu, 1024 kanvas):
#   icon.png           kutu merkezi y 0.521 → %2.1 AŞAĞIDA
#   adaptive-icon.png  kutu merkezi y 0.519 · merkezden en uzak mürekkep
#                      yarıçapın %69.1'i → Android'in %61.1'lik GÜVENLİ
#                      dairesinin DIŞINA taşıyor (eşik uçları dairesel
#                      maskelerde kırpılıyor ya da kenara yapışıyor)
#   splash.png         OPAK kadife zemin (13,12,13) ≠ pencere zemini
#                      (11,10,11) → Android 12+ açılışında işaretin
#                      etrafında KARE bir leke
#
# Sebep tekti: her ölçek `translate(110,113)` etrafında yapılıyordu.
# İşaretin gerçek merkezi 113 değil 114.7 — kemerin tepesi y=40, eşik
# y=189.4. Yani her küçültme işareti hem küçültüp hem AŞAĞI itiyordu.
# 🆕 SINIF: "BİR ŞEKLİ ÖLÇEKLERKEN DAYANAK NOKTASI ŞEKLİN KENDİ MERKEZİ
# DEĞİLSE, KÜÇÜLTME AYNI ZAMANDA BİR KAYDIRMADIR."
#
# Kural artık tek yerde: işaret (110, 114.7) etrafında ölçeklenir ve
# kanvasın (110, 110) noktasına oturur. Eşik ağır olduğu için kütle
# merkezi kendiliğinden kutu merkezinin ~%0.6 üstünde kalıyor — optik
# ortalama bunu istiyor (ağır tabanlı bir şekil tam ortada AŞAĞIDA durur).
# ══════════════════════════════════════════════════════════════════════
ISARET_MERKEZ_Y = (40.0 + 189.4) / 2.0      # kemer tepesi · eşik altı
KANVAS_MERKEZ = 110.0


def yerlestir(ic, olcek=1.0, hedef_y=KANVAS_MERKEZ):
    """İşareti kendi merkezinde ölçekler, kanvasın merkezine oturtur."""
    return (f'<g transform="translate({KANVAS_MERKEZ},{hedef_y}) scale({olcek}) '
            f'translate(-110,-{ISARET_MERKEZ_Y})">{ic}</g>')


# Android güvenli bölgesi: 108dp tuvalin ortasındaki 66dp daire → yarıçapın
# %61.1'i. Eşiğin uçları (±74, +74.7) işaretin en uzak noktası:
# √(74²+74.7²) = 105.1 birim. 0.62 ölçekte 65.2/110 = %59.2 → dairenin İÇİNDE.
ADAPTIVE_OLCEK = 0.62


def govde(P, zemin=True, olcek=1.0):
    sw = swoosh_yolu(P)
    ic = f"""
<path d="{ACIK}" fill="url(#ic)"/>
<path d="{sw}" fill="#D6C3A0" opacity="0.30" filter="url(#yum)"/>
<path d="{sw}" fill="url(#metal2)"/>
<path d="{DIS}" fill="url(#metal)"/>
<!-- ⚠️ KILCAL IŞIK KEMERE KIRPILIYOR VE YUKARIDAN AŞAĞI SÖNÜYOR.
     v1'de `stroke` doğrudan dış kenara çiziliyordu. Kontur bir yolun
     ÜSTÜNDE ortalanır: 1.2 kalınlığın yarısı siluetin DIŞINA taşıyordu
     ve koyu zeminde ayrık, soluk bir çizgi olarak görünüyordu. Üstelik
     omuzda `stroke-linecap="round"` ile aniden bitip bir güdük bırakıyordu.
     Gökberk bunu "hizasızlık gibi" diye işaretledi; haklıydı.
     İki düzeltme: (1) `clipPath` ile kemere kırpıldı — taşması imkânsız,
     (2) opaklık tepede 0.62'den omuzda 0'a sönüyor. Fizik zaten bunu
     söylüyor: ışık yukarıdan gelir, yüzey dikleştikçe parlama biter.
     Böylece "nerede bitecek" sorusu ortadan kalkıyor.
     🆕 SINIF: "BİR KONTUR ÇİZGİSİ YOLUN ÜSTÜNDE ORTALANIR — SİLUETİN
     KENARINA ÇİZERSEN YARISI DIŞARIDA KALIR." -->
<g clip-path="url(#kemerKirp)">
  <path d="M110 40 C146 40 176 70 176 106 L176 186" fill="none"
        stroke="url(#isik)" stroke-width="2.4"/>
  <path d="M110 40 C74 40 44 70 44 106 L44 186" fill="none"
        stroke="url(#isik)" stroke-width="2.0" opacity="0.7"/>
  <path d="M110 56 C138 56 160 78 160 106 L160 186" fill="none"
        stroke="url(#isikIc)" stroke-width="1.8"/>
  <path d="M110 56 C82 56 60 78 60 106 L60 186" fill="none"
        stroke="url(#isikIc)" stroke-width="1.8"/>
</g>
<rect x="36" y="186" width="148" height="3.4" rx="1.7" fill="url(#metal)"/>
<rect x="36" y="186" width="148" height="1.2" rx="0.6" fill="rgba(246,240,229,0.45)"/>
<path d="M44 189.4 L176 189.4 L176 198 L44 198 Z" fill="#000" opacity="0.5" filter="url(#haf)"/>"""
    # 23 Eylül: ölçek 1.0'da da ortalanıyor (eskiden hiç dokunulmuyordu → %2.1 aşağıda)
    ic = yerlestir(ic, olcek)
    zem = ('<rect width="220" height="220" fill="url(#zemin)"/>'
           '<rect width="220" height="220" fill="url(#kadife)"/>') if zemin else ""
    return DEFS + zem + ic


def mono(P, olcek=ADAPTIVE_OLCEK):
    """Android monokrom: tek renk, şeffaf zemin, güvenli daire içinde.
    (Temalı ikon da adaptive ile AYNI güvenli daireyi kullanır.)"""
    sw = swoosh_yolu(P)
    ic = f"""
<path d="{sw}" fill="#FFFFFF" opacity="0.55"/>
<path d="{DIS}" fill="#FFFFFF"/>
<rect x="36" y="186" width="148" height="3.4" rx="1.7" fill="#FFFFFF"/>"""
    return DEFS + yerlestir(ic, olcek)


def splash(P, olcek=0.42):
    """Yerel açılış karesi: obsidyen zemin + ortada kemer.

    🔴 20 EYLÜL — ESKİ SPLASH SİSTEMİN DIŞINDAYDI.
    `assets/splash.png` krem zeminde (L* 96) eski çiğ altın swoosh'tu ve
    `app.json` zemini `#F8F6F1` idi. Yani her SOĞUK AÇILIŞTA kullanıcı
    önce BEYAZ bir kare görüyor, sonra uygulama obsidyeni çiziyordu.
    Bu, temanın uygulanmadığı tek kare değil — GÖRÜLEN İLK kareydi.

    🆕 SINIF: "YEREL AÇILIŞ KARESİ UYGULAMANIN DEĞİL İŞLETİM SİSTEMİNİN
    ÇİZDİĞİ TEK EKRANDIR — TEMAYI ORAYA DA YAZMAZSAN, HER AÇILIŞ BİR
    FLAŞLA BAŞLAR."
    """
    # 🔴 23 EYLÜL — ZEMİN KALKTI: KARE LEKE (Gökberk #2).
    # Kadife zemin opak basılıyordu; ortası (13,12,13), pencere zemini
    # (11,10,11). Android 12+ açılışında görsel ikon alanına sığdırılıyor
    # ve o kare, düz zeminin üstünde kenarlarıyla görünüyordu:
    # "siyah ekrandayken iconun etrafında siyah kare var".
    # Artık saydam: pencere zemini (`splash.backgroundColor`) ne ise o.
    # Işıltı korunuyor ama ALFA ile — %0'a sönen bir hale; kenarı yok.
    # 🆕 SINIF: "İŞLETİM SİSTEMİNİN ÇİZDİĞİ ZEMİNİN ÜSTÜNE KONAN OPAK BİR
    # GÖRSEL, RENGİ NE KADAR YAKIN OLURSA OLSUN, SINIRINI TAŞIR."
    sw = swoosh_yolu(P)
    return f"""{DEFS}
<defs><radialGradient id="hale" cx="50%" cy="50%" r="50%">
  <stop offset="0%" stop-color="#D6C3A0" stop-opacity="0.10"/>
  <stop offset="55%" stop-color="#D6C3A0" stop-opacity="0.035"/>
  <stop offset="100%" stop-color="#D6C3A0" stop-opacity="0"/>
</radialGradient></defs>
<circle cx="110" cy="110" r="78" fill="url(#hale)"/>
<g transform="translate(110,110) scale({olcek}) translate(-110,-{ISARET_MERKEZ_Y})">
<path d="{ACIK}" fill="url(#ic)"/>
<path d="{sw}" fill="#D6C3A0" opacity="0.30" filter="url(#yum)"/>
<path d="{sw}" fill="url(#metal2)"/>
<path d="{DIS}" fill="url(#metal)"/>
<g clip-path="url(#kemerKirp)">
  <path d="M110 40 C146 40 176 70 176 106 L176 186" fill="none" stroke="url(#isik)" stroke-width="2.4"/>
  <path d="M110 40 C74 40 44 70 44 106 L44 186" fill="none" stroke="url(#isik)" stroke-width="2.0" opacity="0.7"/>
</g>
<rect x="36" y="186" width="148" height="3.4" rx="1.7" fill="url(#metal)"/>
<rect x="36" y="186" width="148" height="1.2" rx="0.6" fill="rgba(246,240,229,0.45)"/></g>"""


def adaptive_opak(P, olcek=ADAPTIVE_OLCEK):
    """Android adaptive ÖN PLANI — OPAK.

    ⚠️ `marka_check.py` bunu şart koşuyor: "adaptive-icon.png saydam —
    Android maskeleme için opak olmalı". İlk yazımda saydam üretmiştim
    (Expo'nun `backgroundColor` alanına güvenerek) ve kapı kırmızı yandı.
    Kapı haklı: maskeleme sırasında saydam ön plan cihazdan cihaza farklı
    davranıyor; zemini görselin İÇİNE basmak tek garantili yol.
    """
    return f"""{DEFS}
<rect width="220" height="220" fill="#0B0A0B"/>
<rect width="220" height="220" fill="url(#kadife)"/>
{yerlestir(_ic(P), olcek)}"""


def _ic(P):
    """Kemerin kendisi — zeminsiz gövde (ölçeklenebilir)."""
    sw = swoosh_yolu(P)
    return f"""
<path d="{ACIK}" fill="url(#ic)"/>
<path d="{sw}" fill="#D6C3A0" opacity="0.30" filter="url(#yum)"/>
<path d="{sw}" fill="url(#metal2)"/>
<path d="{DIS}" fill="url(#metal)"/>
<g clip-path="url(#kemerKirp)">
  <path d="M110 40 C146 40 176 70 176 106 L176 186" fill="none" stroke="url(#isik)" stroke-width="2.4"/>
  <path d="M110 40 C74 40 44 70 44 106 L44 186" fill="none" stroke="url(#isik)" stroke-width="2.0" opacity="0.7"/>
  <path d="M110 56 C138 56 160 78 160 106 L160 186" fill="none" stroke="url(#isikIc)" stroke-width="1.8"/>
  <path d="M110 56 C82 56 60 78 60 106 L60 186" fill="none" stroke="url(#isikIc)" stroke-width="1.8"/>
</g>
<rect x="36" y="186" width="148" height="3.4" rx="1.7" fill="url(#metal)"/>
<rect x="36" y="186" width="148" height="1.2" rx="0.6" fill="rgba(246,240,229,0.45)"/>
<path d="M44 189.4 L176 189.4 L176 198 L44 198 Z" fill="#000" opacity="0.5" filter="url(#haf)"/>"""


# ── TEK KAYNAK: `build_brand.py` bu tabloyu kullanır ────────────────────
# (ad, svg üreteci, boy, saydam mı)  · mağaza kuralları burada yazılı:
#   icon        opak (Apple HIG — saydamlık reddedilir)
#   adaptive    opak (Android maskeler)
#   monochrome  saydam, tek renk
#   notification 96px (tanımsız/yanlış boyutta Android beyaz kare basar)
def isaret(P, ton=None, olcek=0.94):
    """
    UYGULAMA İÇİ MARKA İŞARETİ — saydam, ölçeklenebilir.

    🔴 20 EYLÜL — ÜRÜNÜN İÇİNDEKİ İŞARET HÂLÂ EMEKLİ KANATTI.

    v6'da ikon Kemer'e geçti. Ama işaretin ÜRÜN İÇİNDE göründüğü dört
    yer (`App.js` splash · `src/ui.js` yükleyici ×2 · `MomentScreen`)
    ve sitenin başlığı hâlâ `assets/mark-light.png`i — yani eski kanat
    siluetini — çiziyordu. Sahneyi çekip BAKTIĞIMDA gördüm: açılış
    ekranının tam ortasında eski marka duruyordu.

    Yani kullanıcı ikonda Kemer görüp uygulamayı açıyor ve içeride
    kanat buluyordu. İkon değiştirmek markayı değiştirmez; işaretin
    GÖRÜNDÜĞÜ HER YERİ değiştirmek değiştirir.

    🆕 SINIF: "BİR İŞARETİ DEĞİŞTİRİRKEN MAĞAZA VARLIKLARINI SAYIP
    ÜRÜNÜN İÇİNİ SAYMAMAK, MARKAYI İKİYE BÖLER — VE BÖLÜNEN YARI,
    KULLANICININ HER GÜN GÖRDÜĞÜ YARIDIR."

    `ton` verilmezse tam renkli metal (koyu zemin için); verilirse
    tek renk siluet (açık zemin için).
    """
    sw = swoosh_yolu(P)
    if ton:
        return DEFS + yerlestir(f"""
<path d="{sw}" fill="{ton}" opacity="0.55"/>
<path d="{DIS}" fill="{ton}"/>
<rect x="36" y="186" width="148" height="3.4" rx="1.7" fill="{ton}"/>""", olcek)
    return DEFS + yerlestir(_ic(P), olcek)


def varlik_tablosu(P):
    return [
        ("icon.png",              lambda: govde(P),          1024, False),
        ("adaptive-icon.png",     lambda: adaptive_opak(P),  1024, False),
        ("monochrome-icon.png",   lambda: mono(P),           1024, True),
        ("notification-icon.png", lambda: mono(P, 0.78),       96, True),
        ("favicon.png",           lambda: govde(P),            64, False),
        # 23 Eylül: splash SAYDAM (zemin pencereden gelir — kare leke biter)
        ("splash.png",            lambda: splash(P),         1284, True),
        # ⚠️ ÜRÜN İÇİ İŞARET — saydam. İki ton:
        #   mark-kemer.png      koyu zemin (tam metal, şampanya)
        #   mark-kemer-ink.png  açık zemin (tek renk obsidyen; metal
        #                       gradyanı kâğıt üzerinde 2.1:1'e düşüyor)
        # Eski `mark-light.png` / `mark-gold.png` SİLİNMEDİ — "bir aileyi
        # değiştirirken eskisini silmek kararı geri alınamaz yapar".
        ("mark-kemer.png",        lambda: isaret(P),          512, True),
        ("mark-kemer-ink.png",    lambda: isaret(P, "#141210"), 512, True),
    ]


def yaz(ad, ic, boy, seffaf=False):
    import cairosvg
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" '
           f'width="{boy}" height="{boy}">{ic}</svg>')
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=boy, output_height=boy)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    if not seffaf:
        z = Image.new("RGB", (boy, boy), (8, 7, 7))
        z.paste(im, (0, 0), im)
        im = z
    im.save(os.path.join(HEDEF, ad))
    print("  ✓ %-24s %d×%d" % (ad, boy, boy))


def main():
    global IZ
    if "--izle" in sys.argv:
        P = izi_cikar(os.path.join(KOK, "assets", "icon.png"))
        np.save(IZ, P)
        print("· swoosh izi yeniden çıkarıldı (%d nokta)" % len(P))
    if not os.path.exists(IZ):
        print("🔴 %s yok — önce: python brand/build_kemer.py --izle" % IZ)
        return 1
    P = np.load(IZ)
    os.makedirs(HEDEF, exist_ok=True)

    print("=" * 66)
    print("KEMER · IŞIK HUZMESİ — ikon seti")
    print("=" * 66)
    for ad, uret, boy, seffaf in varlik_tablosu(P):
        yaz(ad, uret(), boy, seffaf)
    open(os.path.join(HEDEF, "kemer.svg"), "w").write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" '
        f'width="1024" height="1024">{govde(P)}</svg>')
    print("  ✓ kemer.svg")

    # Önizleme rafı
    import cairosvg
    sayfa = Image.new("RGB", (900, 460), (14, 13, 12))
    x = 40
    for boy, yari in [(380, 84), (180, 40), (120, 26), (60, 13)]:
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" '
               f'width="{boy}" height="{boy}">{govde(P)}</svg>')
        im = Image.open(io.BytesIO(cairosvg.svg2png(
            bytestring=svg.encode(), output_width=boy, output_height=boy))).convert("RGBA")
        m = Image.new("L", (boy, boy), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, boy - 1, boy - 1], radius=yari, fill=255)
        k = Image.new("RGB", (boy, boy), (14, 13, 12))
        k.paste(im, (0, 0), im)
        k.putalpha(m)
        sayfa.paste(k, (x, 40 + (380 - boy)), k)
        x += boy + 26
    sayfa.save(os.path.join(HEDEF, "ONIZLEME.png"))
    print("  ✓ ONIZLEME.png")
    print("\n⚠️ assets/ altına KONMADI. Logo değişikliği ayrı onay ister.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
