#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mockup.py — EKRAN GÖRSELİ ÜRETMEK İÇİN ORTAK PARÇALAR.

🔴 NEDEN VAR
Website ve Instagram için ürünün ekran görüntüleri lazım. Elimizde
emülatör yok; gerçek cihaz görüntüsü alamıyorum. İki kötü seçenek var:
(a) eski ekran görüntülerini kullanmak — ürünü YANLIŞ gösterir,
(b) serbestçe "mockup" çizmek — ürünü OLMADIĞI gibi gösterir.

Üçüncü yol: parçaları ÜRÜNÜN KENDİ KAYNAĞINDAN türetmek. Renkler
`tema_oku` ile `theme.js`ten, geometri `ui.js`ten, metinler
`i18n.js`ten geliyor. Elle yazılmış tek bir hex ya da ölçü yok.
Böylece görsel, ürün değiştiğinde ONUNLA BİRLİKTE değişiyor.

🔴 VE BİR DERSİN SONUCU: bu dosyanın atası olan `onizleme.py`nin ilk
sürümü "ekran gibi görünen" bir renk tablosuydu ve ekran sanıldı.
O yüzden burada üretilen her görselin köşesinde ne olduğu yazıyor,
ve pazarlama çıktılarında bu etiket kaldırılıyorsa BİLEREK kaldırılıyor.

🆕 SINIF: "ÜRÜNÜN GÖRSELİNİ ÜRÜNÜN KAYNAĞINDAN ÜRET — ELLE ÇİZİLEN HER
PİKSEL, YARIN ÜRÜNLE ARASINDA AÇILACAK BİR MESAFEDİR."
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import palet, rozet                                   # noqa: E402

FONTD = os.path.join(KOK, "assets", "fonts")
K = 3                       # çizim ölçeği (3× — Instagram için de yeter)
G, Y = 390 * K, 844 * K     # iPhone 14 mantıksal ölçüsü
KENAR = 18 * K


# ── ui.js'ten geometri ──────────────────────────────────────────────
def _ui(ad, varsayilan):
    g = open(os.path.join(KOK, "src", "ui.js"), encoding="utf-8").read()
    m = re.search(r"const " + ad + r"\s*=\s*([0-9./ ]+);", g)
    return eval(m.group(1).strip()) if m else varsayilan


BANT_ORAN = _ui("BANT_ORAN", 520 / 1080)
FOTO_OLCEK = _ui("FOTO_OLCEK", 1.62)
FOTO_EN_BOY = _ui("FOTO_EN_BOY", 1475 / 1180)
FOTO_Y = _ui("FOTO_Y", 0.55)
PERDE_GUC = _ui("PERDE_GUC", 0.36)
PERDE_BANT = int(_ui("PERDE_BANT", 24))
ERIME_BANT = int(_ui("ERIME_BANT", 14))
MESH_BANT = int(_ui("MESH_BANT", 18))
HALE_HALKA = int(_ui("HALE_HALKA", 14))


# ── i18n'den metin ──────────────────────────────────────────────────
def sozluk(dil="tr"):
    g = open(os.path.join(KOK, "src", "i18n.js"), encoding="utf-8").read()
    if dil == "tr":
        i, j = g.index("  tr: {"), g.index("\n  en: {")
    else:
        i, j = g.index("  en: {"), len(g)
    # 🔴 30 AĞUSTOS — SATIR SONU YORUMU OLAN HER METİN GÖRÜNMEZDİ.
    # ("//" burada Python değil, aranan JS satırındaki yorum.)
    # Kalıp satırın `",` ile BİTMESİNİ şart koşuyordu; `i18n.js`te
    # değeri açıklayan bir yorum varsa (`matchWord: "uyum",  // E3: …`)
    # satır hiç eşleşmiyordu. Ölçtüm: **13 anahtar** böyle kayboluyordu
    # ve `t()` onları "i18n'de yok" diye PATLATIYORDU — yani üreticiyi
    # kırmanın yolu, sözlüğe bir yorum yazmaktı.
    #
    # 🆕 SINIF: **"BİR AYRIŞTIRICI, KAYNAĞIN BİÇİMİNE DAİR YAZILMAMIŞ
    # BİR VARSAYIM TAŞIYORSA, O VARSAYIMI İLK BOZAN KİŞİ HATAYI KENDİ
    # YAPTIĞINI SANIR."**
    # `\n` KAÇIŞI DA OKUNUYOR: tasarımdaki iki satırlı başlıklar
    # (`"{name} için\\nkapıyı açıyorsun"`) sözlükte satır sonu kaçışıyla
    # duruyor. Eski kalıp ters bölüyü tümüyle dışlıyordu, yani bu
    # metinler de "i18n'de yok" sayılıyordu.
    ham = re.findall(r'^\s{4}(\w+):\s*"((?:[^"\\]|\\.){0,300})",\s*(?://.*)?$',
                     g[i:j], re.M)
    return {k: v.replace("\\n", "\n").replace('\\"', '"') for k, v in ham}


def f(ad, boy):
    return ImageFont.truetype(os.path.join(FONTD, ad), int(boy * K))


# ══════════════════════════════════════════════════════════════════
# 🔴 30 AĞUSTOS — ÖNİZLEME HÂLÂ ARCHIVO ÇİZİYORDU.
#
# Gövde ailesi bu turda Archivo → Plus Jakarta Sans oldu (`src/theme.js`
# `F.sans`). Üretici değişmedi. Yani ben Gökberk'e "yeni tipografi
# uygulandı" derken ona ESKİ AİLEDE çizilmiş bir resim gönderiyordum;
# değişikliğin tam olarak görünmesi gereken yerde görünmüyordu.
#
# Aynı kusurun ikinci yüzü: `MONO` hiç yoktu. Uyum puanı, sayaç ve
# cüzdan rakamları uygulamada JetBrains Mono; önizlemede orantılı
# çiziliyordu — yani mono'ya geçmenin TEK GÖRÜNÜR FAYDASI (rakamların
# hizalanması) önizlemede hiç görünmüyordu.
#
# 🆕 SINIF: **"BİR ÖNİZLEME, ÜRÜNÜN MALZEMESİNİ KULLANMIYORSA
# ÜRÜNÜ DEĞİL, ÜRÜN HAKKINDAKİ FİKRİNİ GÖSTERİR."**
#
# `sansEski*` yerine doğrudan yeni aile: eski aile hâlâ `assets/fonts`
# altında (theme.js'te geri dönüş yolu olarak duruyor), silinmedi.
BOLD = "PlusJakartaSans-Bold.ttf"
SEMI = "PlusJakartaSans-SemiBold.ttf"
REG = "PlusJakartaSans-Regular.ttf"
MED = "PlusJakartaSans-Medium.ttf"
SERIF = "CormorantGaramond-Bold.ttf"
# Cormorant 300 — tasarımdaki `.an-h1` ve `.ust-h1.serif` bu kesiti
# istiyor. Uygulamada `F.serifLight`.
SERIF_LIGHT = "CormorantGaramond-Light.ttf"
# Tasarımın `.avatar{font-family:"Cormorant Garamond";font-weight:600}`
# kesiti. Uygulamada `F.serif` bu ağırlığa bağlı.
SERIF_SEMI = "CormorantGaramond-SemiBold.ttf"
# Değişen sayılar. Uygulamada `MONO[500]` / `MONO[600]`.
MONO_MED = "JetBrainsMono-Medium.ttf"
MONO_SEMI = "JetBrainsMono-SemiBold.ttf"


# ══════════════════════════════════════════════════════════════════
# 🔴 30 AĞUSTOS · 2. TUR — ÖNİZLEME ARTIK GERÇEK İKONLARI ÇİZİYOR.
#
# Sekme çubuğunda dört DAİRE çiziliyordu; uygulamada radar, kart,
# balon ve kişi ikonları var. Yani önizlemeye bakan kişi, ürünün
# gezinmesini "dört özdeş nokta" olarak görüyordu — oysa ikonların tek
# işi birbirinden AYRILMAK.
#
# Oysa gereken her şey elimizdeydi: `assets/fonts/Ionicons.ttf` APK'ya
# gömülü, `src/ikon.js` anlam→glif haritasını tutuyor ve glif→kod eşlemi
# `node_modules`ta duruyor. Üç parça da vardı; yalnız birleştirilmemişti.
#
# 🆕 SINIF: **"BİR ŞEYİ 'ÇİZEMİYORUM' DEMEDEN ÖNCE, ÜRÜNÜN ONU NEYLE
# ÇİZDİĞİNE BAK — GENELDE EKSİK OLAN YETENEK DEĞİL, İKİ DOSYA
# ARASINDAKİ BAĞDIR."**
_IONI_YOL = os.path.join(
    KOK, "node_modules", "@expo", "vector-icons", "build", "vendor",
    "react-native-vector-icons", "glyphmaps", "Ionicons.json")
_HARITA, _GLIF, _LL_GLIF = None, None, {}


def ikon_kodu(ad):
    """`ikon.js`teki anlam adını (örn. "radar") bir (glif, font) çiftine
    çevirir. Bulunamazsa None döner — ÇAĞIRAN yedeğe düşer, burada
    sessizce boş kutu çizilmez."""
    global _HARITA, _GLIF, _LL_GLIF
    if _HARITA is None:
        src = open(os.path.join(KOK, "src", "ikon.js"), encoding="utf-8").read()
        # `ll:radar` gibi iki nokta üst üste içeren adlar da yakalansın
        _HARITA = dict(re.findall(r'^\s*(\w+):\s*"([\w:-]+)",', src, re.M))
        # KENDİ glif haritamız da AYNI dosyadan okunuyor — iki yerde iki
        # liste tutmak, ikisinin ayrışmasını beklemektir.
        _LL_GLIF = {a: int(k, 16) for a, k in
                    re.findall(r"(\w+):\s*0x([0-9A-Fa-f]{4})",
                               (re.search(r"LL_GLIFLER\s*=\s*\{(.*?)\}", src, re.S)
                                or type("x", (), {"group": lambda s, i: ""})()).group(1))}
        try:
            import json as _j
            _GLIF = _j.load(open(_IONI_YOL, encoding="utf-8"))
        except Exception:
            _GLIF = {}
    g = _HARITA.get(ad)
    if not g:
        return None
    # 🔴 31 AĞU · 8. TUR — ARTIK İKİ AİLE VAR.
    # `ikon.js` Keşfet sekmesini `"ll:radar"` diye çözüyor: kendi tek
    # gliflik fontumuz (`assets/fonts/LLSimge.ttf`). Ayna yalnız
    # Ionicons'u biliyordu; `"ll:radar"` `_GLIF`te bulunmayınca
    # `None` dönüyor ve `ikon()` PATLIYORDU — yani ayna, ÜRÜNDE ÇALIŞAN
    # bir ikonu "çözülemedi" diye bildiriyordu.
    #
    # 🆕 SINIF: "AYNAYA YENİ BİR KAYNAK EKLEMEDEN ÜRÜNE YENİ BİR KAYNAK
    # EKLERSEN, AYNA ARTIK ÜRÜNÜ DEĞİL KENDİ ESKİ VARSAYIMINI GÖSTERİR."
    # (İade dönüşü: (kod noktası, font dosyası) — çağıran hangi fontla
    #  çizeceğini artık tahmin etmiyor.)
    if g.startswith("ll:"):
        return (chr(_LL_GLIF.get(g[3:], 0)) if g[3:] in _LL_GLIF else None,
                "LLSimge.ttf")
    if g not in _GLIF:
        return None
    return (chr(_GLIF[g]), "ionicons.ttf")


def buyuk(s):
    """Türkçe büyük harf. `str.upper()` DEĞİL.

    🔴 31 AĞUSTOS · 10. TUR — GÖKBERK KENDİ ADININ ÜSTÜNDE GÖRDÜ:
    "app görüntüsünde iyi günler yerine İyı günler yazıyo gibi."

    Python'un `"iyi günler".upper()` çıktısı `IYI GÜNLER` — noktasız I.
    Türkçede `i` → `İ` ve `ı` → `I`. Yani ürünün arayüzü, Türkçe bir
    ürün olarak KENDİ DİLİNİ yanlış yazıyordu; üstelik en görünür
    yerde, kullanıcıya "iyi günler" dediği satırda.

    Uygulama tarafı doğruydu — `textTransform:"uppercase"` platformun
    yerelleştirmesini kullanıyor ve `toLocaleUpperCase("tr-TR")`
    yazdığımız yerler de var. Yanlış olan yine AYNAYDI.

    🆕 SINIF: "BİR DİLİN BÜYÜK HARFİ EVRENSEL DEĞİLDİR — `upper()`
    ÇAĞIRAN HER SATIR, İNGİLİZCE VARSAYAN BİR SATIRDIR."
    """
    return s.replace("i", "İ").replace("ı", "I").upper()


def rgb(h):
    h = str(h).lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ══════════════════════════════════════════════════════════════════
# RADYAL HALE — ANALİTİK, HALKA YIĞMADAN
#
# 🔴 31 AĞUSTOS · 8. TUR — İKİ YERDE AYNI SESSİZ HATA: HALELER
# NEREDEYSE HİÇ ÇİZİLMİYORDU.
#
# İki yerde de desen şuydu: `guc`u HALKA adet eş merkezli daireye
# bölüp (`adim = 1-(1-guc)^(1/HALKA)`) hepsini ÜST ÜSTE çizmek. Matematik
# doğruydu — ama `ImageDraw.ellipse(fill=(r,g,b,a))` PİKSELİ DEĞİŞTİRİR,
# HARMANLAMAZ. Yani 26 halka birikmiyordu; sonuncusu diğerlerini SİLİYOR
# ve geriye %2'lik tek bir kat kalıyordu. Hedef %42 idi.
#
# Ölçüm (eşleşme ekranı, aynı noktalar):
#     tasarım (105,86,68)  ·  ayna (35,26,31)   → sahne 3 kat karanlık
#
# Uygulama tarafında AYNI mantık DOĞRU çalışıyor, çünkü orada halkalar
# 14 ayrı `<View>` ve React Native onları gerçek alfayla üst üste
# bindiriyor. Yani ürün doğruydu, ayna yanlıştı — ve ben aynaya bakıp
# "tasarım uygulanmamış" diye üç ayrı karar aldım.
#
# 🆕 SINIF: "İKİ FARKLI ÇİZİM MOTORUNDA AYNI ALGORİTMAYI YAZARSAN,
# 'ÜST ÜSTE ÇİZMEK' KELİMESİNİN İKİSİNDE AYNI ŞEYİ İFADE ETTİĞİNİ
# VARSAYMA — BİRİ HARMANLAR, ÖTEKİ SİLER."
#
# Halka yığmak zaten bir YAKLAŞIMDI (CSS'in radial-gradient'ini taklit).
# Doğrusunu doğrudan yazmak hem daha kısa hem tam: her piksel için
# normalize elips uzaklığı, CSS'in kendi düşüşüyle.
def radyal(boy, renk, cx, cy, rx, ry, guc, bitis=1.0):
    """CSS `radial-gradient(rx ry at cx cy, renk guc 0%, renk 0 bitis%)`.

    cx/cy/rx/ry KUTUYA ORANLI (0..1). Dönen katman doğrudan
    `alpha_composite` edilebilir.
    """
    import numpy as np
    W, H = boy
    x = np.arange(W, dtype=np.float32)[None, :] / max(1.0, W)
    y = np.arange(H, dtype=np.float32)[:, None] / max(1.0, H)
    dx = (x - cx) / max(1e-6, rx)
    dy = (y - cy) / max(1e-6, ry)
    u = np.sqrt(dx * dx + dy * dy) / max(1e-6, bitis)
    a = np.clip(1.0 - u, 0.0, 1.0) * guc
    kat = np.zeros((H, W, 4), dtype=np.uint8)
    r_, g_, b_ = rgb(renk)
    kat[..., 0], kat[..., 1], kat[..., 2] = r_, g_, b_
    kat[..., 3] = (a * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(kat, "RGBA")


def screen_bindir(taban, ust, opaklik):
    """CSS `mix-blend-mode:screen` + `opacity` — İKİSİ BİRLİKTE.

    🔴 31 AĞUSTOS · 8. TUR — FOTOĞRAF KATMANINI DÜZ ALFAYLA
    BİNDİRİYORDUM VE BU, TASARIMIN TERSİNİ YAPIYOR.

    Tasarımın iki fotoğraf katmanı da `mix-blend-mode:screen`:
        .ust.mesh::after{ opacity:.16; mix-blend-mode:screen }
        .an::after      { opacity:.20; mix-blend-mode:screen }
    `screen` ASLA KOYULTMAZ — yalnız ışık ekler. Düz alfa ise
    fotoğrafın KOYU pikselini de taşır, yani karanlık bir kabin
    fotoğrafı zemini KOYULTUR. İki yöntem burada zıt yönlere çalışıyor.

    `ui.js`te bir tur önce "ikisi arasında binde bir fark var" diye
    yazmışım. O ölçüm fotoğrafın EN AÇIK pikseli için yapılmıştı —
    orada gerçekten fark yok. Ama ekranın çoğu en açık piksel değil:
    kadrajın alt yarısında fotoğraf koyu ve orada fark 3 kata çıkıyor.

    🆕 SINIF: "BİR YAKLAŞIMIN HATASINI EN İYİ DURUMDA ÖLÇERSEN,
    ÖLÇTÜĞÜN ŞEY HATA DEĞİL EN İYİ DURUMDUR."

        screen(a,b) = 1 - (1-a)(1-b)
        sonuc       = a + opaklik * (screen(a,b) - a)
    """
    import numpy as np
    A = np.asarray(taban.convert("RGB"), dtype=np.float32) / 255.0
    B = np.asarray(ust.convert("RGB"), dtype=np.float32) / 255.0
    S = 1.0 - (1.0 - A) * (1.0 - B)
    out = A + opaklik * (S - A)
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").convert("RGBA")


# ── FONT KAPSAMI: TOFU'YU ÇİZİLMEDEN ÖNCE YAKALA ───────────────────
# 🔴 İLK RENDER'DA ÜÇ EKRANDA BOŞ KUTU (tofu) ÇIKTI:
#   `sessDone` = "🎉 Oturum tamamlandı"   → Cormorant'ta 🎉 yok
#   `sessActive` = "● Oturum Aktif"       → Archivo'da ● yok
#   `lsGuest5` = "Lounge'dayım ✅"         → Archivo'da ✅ yok
# Bu metinler CİHAZDA sorunsuz (sistem fontu emoji'yi kapsıyor);
# sorun yalnız RENDER'da. Ama pazarlama görselinde boş kutu, ürünün
# bozuk olduğunu söyler.
#
# `glif_check.py` KAYNAKTAKİ glifleri ölçüyor ve bu üçünü de doğru
# biliyor. Eksik olan halka şuydu: RENDER, kaynakla aynı fontu
# kullanmıyor. Ölçüm doğruydu, ölçülen yer yanlıştı.
#
# 🆕 SINIF: "AYNI METNİ FARKLI BİR FONTLA ÇİZEN HER İKİNCİ BORU HATTI,
# BİRİNCİDE ÇÖZÜLMÜŞ GLİF SORUNUNU SIFIRDAN GERİ GETİRİR."
#
# Çözüm bir uyarı değil, bir KAPI: kapsamayan bir karakter çizilmeye
# kalkışılırsa istisna fırlar. Bilerek atmak isteyen `temiz()` çağırır —
# ve ne attığı `_ATILAN`da raporlanır.
_CMAP = {}
_ATILAN = []
_IZINLI = set(" \n\t ")


def _kapsam(yol):
    if yol not in _CMAP:
        from fontTools.ttLib import TTFont
        tf = TTFont(yol, fontNumber=0, lazy=True)
        s = set()
        for tbl in tf["cmap"].tables:
            s |= set(tbl.cmap.keys())
        tf.close()
        _CMAP[yol] = s
    return _CMAP[yol]


def kapsiyor(font, s):
    yol = getattr(font, "path", None)
    if not yol:
        return []
    k = _kapsam(yol)
    return [c for c in s if c not in _IZINLI and ord(c) not in k]


def temiz(font, s, kaynak=""):
    """Fontun kapsamadığı karakterleri BİLEREK atar ve rapora yazar."""
    eks = kapsiyor(font, s)
    if not eks:
        return s
    _ATILAN.append((kaynak or s[:24], "".join(sorted(set(eks)))))
    out = "".join(c for c in s if c not in eks)
    return " ".join(out.split())


class Ekran:
    """Tek bir telefon ekranı — parçalar üstüne çiziliyor."""

    def __init__(self, kapsam=None, g=G, y=Y):
        # 🔴 30 AĞUSTOS — VARSAYILAN ARTIK KOYU.
        #
        # Uygulamanın varsayılan teması koyu (Gece sistemi). Bu üretici
        # ise 13 ekranı `"C"` (açık) ile çiziyordu ve yalnız biri koyuydu.
        # Yani ürünün varsayılan görüntüsünü ÜRETMİYORDU — üretse de
        # kimse fark etmezdi, çünkü çıktıya bakan kişi ekranın hangi
        # temada çizildiğini bilmiyor.
        #
        # 🆕 SINIF: "BİR ÖNİZLEME ÜRETİCİSİ, ÜRÜNÜN VARSAYILANINI
        # ÜRETMİYORSA, ÜRÜNÜ DEĞİL BİR SEÇENEĞİNİ GÖSTERİYORDUR."
        #
        # `kapsam="C"` açıkça geçilirse açık tema hâlâ çizilebiliyor.
        if kapsam is None:
            kapsam = "KOYU"
        self.P = dict(palet("C"))
        if kapsam == "KOYU":
            self.P.update(palet("KOYU"))
        self.R = rozet(kapsam) or rozet("C")
        self.kapsam = kapsam
        self.g, self.y = g, y
        self.im = Image.new("RGBA", (g, y), rgb(self.P["bg"]) + (255,))
        self.d = ImageDraw.Draw(self.im)
        self.imlec = 0

    # ── yardımcılar ────────────────────────────────────────────────
    def _d(self):
        self.d = ImageDraw.Draw(self.im)
        return self.d

    def yuvarlak(self, kutu, r, dolgu=None, kenar=None, kalinlik=1):
        g, y = kutu
        kat = Image.new("RGBA", (g, y), (0, 0, 0, 0))
        ImageDraw.Draw(kat).rounded_rectangle(
            [0, 0, g - 1, y - 1], r * K, fill=dolgu, outline=kenar, width=kalinlik * K)
        return kat

    def metin(self, xy, s, font, renk, aralik=0, enfazla=None, kaynak=""):
        # ══════════════════════════════════════════════════════════════
        # 🔴 30 AĞUSTOS · 4. TUR — TAŞMA KAPISI.
        #
        # Gökberk ürettiğim önizlemede gösterdi: ana sayfada
        # "LOUNGEPUAN" komşu sütuna, "SOHBETLER"/"SORULARIM" kendi
        # kutularının dışına taşıyordu. Ben o görseli üretip
        # "uçtan uca tamam" diye teslim ettim — yani ÜRETTİĞİM RESME
        # BAKMADIM, yalnız sayıya baktım.
        #
        # 🆕 SINIF: **"ÖLÇTÜĞÜN ŞEY DOĞRU OLABİLİR AMA ÖLÇMEDİĞİN ŞEY
        # HÂLÂ BOZUKTUR — BİR SAYAÇ, GÖZÜN YERİNE GEÇMEZ; YALNIZ
        # GÖZÜN BAKAMADIĞI YERE BAKAR."**
        #
        # Glif kapısıyla aynı mantık: uymayan bir şeyi çizmeye
        # kalkışınca İSTİSNA fırlar. Bilerek sığdırmak isteyen
        # `sigdir()` çağırır.
        if enfazla is not None:
            w = self.genislik(s, font, aralik)
            if w > enfazla + 0.5:
                raise ValueError(
                    "TAŞMA — %r %.0fpx yer istiyor, %.0fpx var (%s). "
                    "sigdir() kullan ya da metni kısalt."
                    % (s[:40], w, enfazla, kaynak or "?"))
        eks = kapsiyor(font, s)
        if eks:
            raise ValueError(
                "FONT KAPSAMIYOR — tofu çizilecekti: %r içinde %s "
                "(font: %s). Bilerek atmak için mockup.temiz() kullan."
                % (s[:48], "".join(sorted(set(eks))),
                   os.path.basename(getattr(font, "path", "?"))))
        # ══════════════════════════════════════════════════════════
        # 🔴 30 AĞUSTOS · 6. TUR — AYNI DERSİ ÜÇÜNCÜ KEZ ÖDEDİM.
        # BU SEFER FORMÜL DEĞİL, BİRİM.
        #
        # `metin()` `aralik * K` çarpıyordu; `genislik()` çarpmıyordu.
        # Yani aynı adı taşıyan parametre iki fonksiyonda İKİ FARKLI
        # BİRİMDEYDİ: biri nokta, öbürü cihaz pikseli. Çağrı yerleri de
        # `aralik=1.3 * K` yazınca çizim 1.3×3×3 = 11.7px kullandı,
        # ölçüm 3.9px. Fark 3 KAT.
        #
        # Ölçüm (ana_misafir.png · 1170px): "KREDİ" için `genislik` 95px
        # dedi, çizim 146px yaptı; "LOUNGEPUAN" 233 dendi, 298 çizildi
        # ve ikinci ayracı 17px aştı. Gökberk ekranda gördü ve "taşma"
        # dedi — haklıydı; ama taşan uygulama değil, AYNAYDI.
        #
        # 🆕 SINIF: "AYNI ADI TAŞIYAN İKİ PARAMETRE FARKLI BİRİMDEYSE,
        # HER ÇAĞRI YERİ BİRİNİ SEÇMEK ZORUNDA KALIR — VE HANGİSİNİ
        # SEÇTİĞİNİ HİÇBİR YERDE YAZMAZ."
        #
        # ARTIK TEK KURAL: `aralik` HER ZAMAN NOKTA. K çarpımı yalnız
        # burada ve `genislik()`te, aynı biçimde yapılır.
        # ══════════════════════════════════════════════════════════
        # ══════════════════════════════════════════════════════════
        # 🔴 31 AĞUSTOS · 10. TUR — "TASARIMDAKİ FONT DAHA BOLD"
        # Gökberk: "genel olarak font stili farklı gibi, tasarımdaki
        # daha bold bir havası var."
        #
        # Önce aile ve ağırlığı kontrol ettim: İKİSİ DE AYNI. Tasarım
        # `font-family:"Plus Jakarta Sans"`, ben aynı TTF'yi
        # kullanıyorum; `.ust-h1.serif{font-weight:300}`, ben
        # `CormorantGaramond-Light` (=300). Yani "farklı font" değil.
        #
        # Sonra MÜREKKEBİ ölçtüm (aynı kelime, aynı kutu):
        #     tasarım  eşik üstü piksel oranı  0.189
        #     ayna                             0.096
        # Yani harfler yarı kalınlıkta çiziliyordu.
        #
        # SEBEP GAMA. Tarayıcılar (ve iOS/Android metin motorları)
        # kenar yumuşatmayı gama düzeltmeli harmanlar; PIL 8-bit sRGB
        # değerlerini DOĞRUSAL harmanlıyor. Koyu zeminde açık metinde
        # bu fark tek yönlü çalışır ve harfleri İNCELTİR — çünkü
        # yarı-saydam kenar pikselleri olması gerekenden koyu çıkar.
        #
        # Yani ne fontu değiştirmek ne de sahte bir kalınlaştırma
        # (stroke_width) gerekiyordu: gerekli olan, PIL'in yaptığı
        # harmanı motorların yaptığı harmana çevirmek. Maskeyi
        # `a**(1/GAMA)` ile düzeltiyoruz — cihazda göreceğin şey bu.
        #
        # 🆕 SINIF: "'FONT FARKLI GÖRÜNÜYOR' ŞİKÂYETİNİN CEVABI ÇOĞU
        # ZAMAN FONTTA DEĞİL, ONU PİKSELE ÇEVİREN ADIMDADIR."
        self._metin_gama(xy, s, font, renk, aralik)

    # Metin harmanı için gama. 1.0 = eski (doğrusal) davranış.
    # 1.45 tarayıcı/mobil metin motorlarının pratikte ürettiği eğri;
    # ölçümle seçildi (aşağıdaki `gama_kalibre.py` bunu doğruluyor).
    GAMA = 1.45

    def _metin_gama(self, xy, s, font, renk, aralik=0):
        """Metni maskeye çizip gama düzeltmesiyle bindirir."""
        import numpy as np
        d0 = ImageDraw.Draw(self.im)
        # 1) genişliği ölç, maske kutusunu kur
        gen = int(self.genislik(s, font, aralik)) + 8 * K
        yuk = int(font.size * 2.2) + 8 * K
        mask = Image.new("L", (max(1, gen), max(1, yuk)), 0)
        md = ImageDraw.Draw(mask)
        if aralik:
            x = 4 * K
            for ch in s:
                md.text((x, 4 * K), ch, font=font, fill=255)
                x += md.textlength(ch, font=font) + aralik * K
        else:
            md.text((4 * K, 4 * K), s, font=font, fill=255)
        # 2) gama düzeltmesi — kenar pikselleri motorların ürettiği
        #    eğriye taşınıyor
        a = np.asarray(mask, dtype=np.float32) / 255.0
        a = np.power(a, 1.0 / self.GAMA)
        mask = Image.fromarray((a * 255.0 + 0.5).astype("uint8"), "L")
        # 3) bindir — `paste(renk, konum, maske)` HEM RGB HEM RGBA
        #    hedefte çalışır. Önce `alpha_composite` kullanmıştım ve
        #    `mockup_kalibre.py` (RGB tuvalle çalışıyor) "image has wrong
        #    mode" ile patladı. Kapı, kendi ölçüm aracını kıran bir
        #    değişikliği ilk denemede yakaladı.
        self.im.paste(rgb(renk), (int(xy[0]) - 4 * K, int(xy[1]) - 4 * K), mask)
        self.d = d0

    def genislik(self, s, font, aralik=0):
        # 🔴 `metin()` harf aralığını uygulayabiliyordu ama `genislik()`
        # onu hesaba katmıyordu. Sonuç: harf aralıklı her ORTALI metin
        # sola kayıyordu — kayma tam olarak `aralik × (harf-1)` kadar ve
        # 2.4×3 ölçekte 10 harflik bir etikette ~65 piksel. "Ortalı ama
        # biraz solda" duran her etiketin sebebi buydu.
        #
        # 🆕 SINIF: "BİR ÖLÇÜM İŞLEVİ, ÇİZİM İŞLEVİNİN BİLDİĞİ HER ŞEYİ
        # BİLMİYORSA, ÖLÇÜM DOĞRU AMA SONUÇ YANLIŞ OLUR."
        if not aralik:
            return self._d().textlength(s, font=font)
        # ⚠️ NEGATİF ARALIK ARTIK HİÇBİR YERDE KULLANILMIYOR — `metin()`
        # aralığı BOŞLUK karakterine de uyguladığı için negatif izleme
        # kelimeleri yapıştırıyordu ("Kaldığınyerden"). RN'in
        # `letterSpacing`i bunu doğru yapıyor; ben yapamıyorum.
        # Yapamadığım bir şeyi taklit etmektense HİÇ yapmıyorum.
        #
        # 🆕 SINIF: "BİR AYNANIN YAPAMADIĞI ŞEYİ YAKLAŞIK OLARAK
        # YAPMASI, HİÇ YAPMAMASINDAN DAHA YANILTICIDIR — EKSİK BİR
        # TEMSİL FARK EDİLİR, BOZUK BİR TEMSİL DOĞRU SANILIR."
        # 🔴 30 AĞUSTOS · 4. TUR — AYNI DERSİ İKİNCİ KEZ ÖDEDİM.
        #
        # İki tur önce "genislik aralığı saymıyordu" diye düzelttim ve
        # `textlength(s) + aralik*(n-1)` yazdım. Ama `metin()` aralıklı
        # metni KARAKTER KARAKTER çiziyor:
        #     cx += textlength(ch) + aralik
        # Tek tek karakterlerin toplamı, dizginin `textlength`inden
        # BÜYÜKTÜR (kerning tek çizimde kazanılır, karakter karakter
        # çizimde kaybedilir). Ölçtüm: "LOUNGEPUAN" için 235 dedim,
        # çizim 312 yaptı — **%33 fark**. Gökberk ekranda gördü.
        #
        # Yani düzeltmem "aralığı da say" idi; doğrusu "ÇİZİM NASIL
        # İLERLİYORSA ÖYLE SAY" olmalıydı.
        #
        # 🆕 SINIF: **"BİR ÖLÇÜMÜ ÇİZİME YAKLAŞTIRMAK YETMEZ — ÖLÇÜM,
        # ÇİZİMİN AYNI ADIMLARINI ATMALIDIR. 'BENZER' BİR FORMÜL,
        # FARKI GİZLEYECEK KADAR YAKIN VE YANILTACAK KADAR UZAKTIR."**
        # `aralik` NOKTA birimindedir (bkz. `metin()` içindeki blok).
        # K çarpımı burada da yapılır — iki fonksiyon aynı adımı atar.
        d = self._d()
        return (sum(d.textlength(ch, font=font) for ch in s)
                + aralik * K * max(0, len(s) - 1))

    def sigdir(self, s, ad, boy, en, alt=8.0):
        """
        🔴 İLK RENDER'DA İKİ YERDE METİN KUTUDAN TAŞTI: Keşfet'teki
        "aynı uçuş" şeridi ve "Oturum tamamlandı" başlığı sağdan
        kesildi. Sabit punto + değişken metin = er ya da geç taşma;
        ve i18n metni ÜRÜNDEN geldiği için yarın uzayabilir.
        Punto ölçülerek küçültülür — kırpma son çare.
        """
        while boy > alt and self.genislik(s, f(ad, boy)) > en:
            boy -= 0.5
        return f(ad, boy)

    # ── ATMOSFER DOKUSU ────────────────────────────────────────────
    def doku(self, y0=None):
        yog = 0.07 if self.kapsam == "KOYU" else 0.09
        ufuk = rgb(self.P.get("sicak", "#E39B6B"))
        z = rgb(self.P["bg"])
        y0 = self.y * 0.46 if y0 is None else y0
        h = int(self.y * 0.20)
        d = self._d()
        for i in range(h):
            t = i / (h - 1)
            a = yog * (1 - abs(t - 0.5) * 2)
            d.rectangle([0, int(y0) + i, self.g, int(y0) + i + 1],
                        fill=tuple(round(z[k] + (ufuk[k] - z[k]) * a) for k in range(3)) + (255,))

    # ── GÖLGELİ METİN (fotoğraf üstü) ──────────────────────────────
    def golgeli(self, xy, s, font, renk, aralik=0):
        eks = kapsiyor(font, s)
        if eks:
            raise ValueError("FONT KAPSAMIYOR (gölgeli): %r içinde %s"
                             % (s[:48], "".join(sorted(set(eks)))))
        x, yy = xy

        # Harf aralığı gölge katmanlarına da UYGULANMALI: gölge asıl
        # metinle aynı yolla çizilmezse, aralık verilen her başlıkta
        # gölge metinden kayar ve "çift baskı" gibi okunur.
        def _ciz(d, ox, oy, dolgu):
            if not aralik:
                d.text((ox, oy), s, font=font, fill=dolgu)
                return
            cx = ox
            for ch in s:
                d.text((cx, oy), ch, font=font, fill=dolgu)
                cx += self._d().textlength(ch, font=font) + aralik

        for yaricap, alfa, dy in ((22, 0.75, 5), (10, 0.92, 2), (3, 1.0, 1)):
            kat = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
            _ciz(ImageDraw.Draw(kat), x, yy + dy * K, (10, 6, 6, int(255 * alfa)))
            self.im.alpha_composite(kat.filter(ImageFilter.GaussianBlur(yaricap * K / 6.0)))
        _ciz(self._d(), x, yy, rgb(renk) + (255,))

    # ── FOTOĞRAFLI BANT ────────────────────────────────────────────
    def bant(self, baslik, ustBilgi=None, marka="LOUNGELINK", tam=False,
             altBilgi=None, eylem=None, geri=False, sag_ikon=None, ek_yuk=0):
        """
        🔴 30 AĞUSTOS · 2. TUR — ARTIK `FotoBant` DEĞİL, `ust.mesh`.

        Uygulamanın başlığı bu turda bir FOTOĞRAF BANDI olmaktan çıkıp
        tasarımdaki mesh başlığa döndü (bkz. src/ui.js). Üretici hâlâ
        eski bandı çiziyordu — yani önizleme, ürünün ARTIK OLMAYAN bir
        sürümünü gösteriyordu. Aynı kusuru bir tur önce fontlarda
        yaşamıştım; ayna, aynası olduğu şeyle birlikte değişmezse ayna
        değil, fotoğraf albümüdür.

        Katmanlar birebir uygulamadaki sırayla:
          1 dikey taban  #1A1620 → bg  (MESH_BANT adım)
          2 fotoğraf     %16
          3 iki hale     altın sağ üst · mavi sol üst
          4 metin        marka → dugum(ALTIN) → h1(sans) → alt

        `tam=True` (splash) eski davranışta kalıyor: orada fotoğraf
        gerçekten zeminin kendisi ve öyle de olmalı.
        """
        if tam:
            return self._bant_tam(baslik, marka)

        # ══════════════════════════════════════════════════════════════
        # 🔴 31 AĞUSTOS · 8. TUR — BANT YÜKSEKLİĞİ ORANDA DONMUŞTU;
        # UYGULAMADA İSE İÇERİKLE BÜYÜYOR.
        #
        # Gökberk: "iç sayfalarda üstteki görselli alanın aynı tasarımdaki
        # gibi olmasını istiyorum." İşaretlediği yer, alt satırın
        # ("Kalkışına 3 sa 12 dk · 6 host yayında") bandın alt kenarına
        # YAPIŞMASIYDI. Tasarımda o satırın altında `.ust{padding-bottom:22px}`
        # kadar hava var.
        #
        # Ölçüm — bu fonksiyonun KENDİ çizim ritmi:
        #     40 (üst pay) + 38 (eylem satırı) + 34 (.dugum margin)
        #   + 18 (.dugum + .ust-h1 margin) + 42 (.ust-h1 satırı)
        #   + 30 (.ust-alt margin + satırı) + 22 (padding-bottom) = 224pt
        # BANT_ORAN ise 390 × 574/1080 = 207.3pt → 17pt EKSİK.
        #
        # `src/ui.js` bu sorunu bir tur önce `height` → `minHeight` ile
        # çözmüştü ve o kararın gerekçesi orada yazılı. Ayna o kararı
        # ALMAMIŞTI: aynı ORANı okuyup TAVAN gibi kullanıyordu.
        #
        # 🆕 SINIF: "İKİ TARAF AYNI SABİTİ OKUYOR DİYE AYNI ŞEYİ
        # YAPMIYORDUR — SABİT PAYLAŞILIR, ONU NASIL KULLANDIĞIN KARARI
        # PAYLAŞILMAZ."
        gerek = 20 * K + 38 * K + 34 * K
        if ustBilgi:
            gerek += 10 * K + 8 * K
        if baslik:
            gerek += 42 * K
        if altBilgi:
            gerek += 12 * K + 18 * K
        # `ek_yuk`: çağıran, bandın İÇİNE kendi çizeceği bloğun boyunu
        # bildirir (ana sayfada cüzdan kutusu). Bildirmezse mesh o bloğun
        # ortasında bitiyor ve kutu yarı yarıya siyaha taşıyordu —
        # tasarımda cüzdan bandın İÇİNDE, altında 22px hava var.
        gerek += int(ek_yuk)
        gerek += 22 * K                       # `.ust{padding-bottom:22px}`
        YB = max(int(round(self.g * BANT_ORAN)), gerek)
        kat = Image.new("RGBA", (self.g, YB), rgb(self.P["bg"]) + (255,))

        # 1 · dikey taban
        ust = rgb(self.P.get("meshUst", "#1A1620"))
        for i in range(MESH_BANT):
            t = i / (MESH_BANT - 1)
            y0 = int(round(YB * t))
            y1 = int(round(YB * (t + 1.0 / (MESH_BANT - 1))))
            kat.alpha_composite(
                Image.new("RGBA", (self.g, max(1, y1 - y0)), ust + (int(255 * (1 - t)),)),
                (0, y0))

        # 2 · fotoğraf %16 · center 42%/cover
        foto = Image.open(os.path.join(KOK, "assets", "bant.jpg")).convert("RGBA")
        oran = max(self.g / foto.size[0], YB / foto.size[1])
        fg, fy = int(foto.size[0] * oran), int(foto.size[1] * oran)
        foto = foto.resize((fg, fy), Image.LANCZOS)
        sx = max(0, (fg - self.g) // 2)
        sy = int(max(0, (fy - YB)) * 0.42)
        foto = foto.crop((sx, sy, sx + self.g, sy + YB))
        # `.ust.mesh::after{opacity:.16; mix-blend-mode:screen}` —
        # AYNI hata buradaydı da: düz alfa fotoğrafın koyu piksellerini
        # de taşıyıp bandı koyultuyordu; screen yalnız ışık ekler.
        kat = screen_bindir(kat, foto, 0.16)

        # 3 · haleler — AYNI SESSİZ HATA BURADAYDI (bkz. `radyal()`
        # başlığı): 14 halka üst üste ÇİZİLİYOR ama harmanlanmıyordu,
        # yani %30'luk altın hale ekranda %2.5 olarak duruyordu. Başlık
        # bandının tasarımdan sönük görünmesinin sebeplerinden biri buydu.
        # `ui.js`teki `.ust.mesh` durakları:
        #   radial-gradient(120% 92% at 82% -14%, altın .30)
        #   radial-gradient(112% 88% at  8%   6%, mavi  .20)
        kat.alpha_composite(radyal((self.g, YB), self.P["gold"],
                                   0.82, -0.14, 1.20, 0.92, 0.30))
        kat.alpha_composite(radyal((self.g, YB), self.P.get("purple", "#7FA8E8"),
                                   0.08, 0.06, 1.12, 0.88, 0.20))

        self.im.alpha_composite(kat, (0, 0))

        # 4 · metin — uygulamadaki sabit ritim: 34 → 8 → 12
        #
        # 🔴 31 AĞUSTOS · 9. TUR — BANDIN TEPESİNDE 20pt FAZLA BOŞLUK VARDI.
        # Gökberk: "benzer bi yükseklik farkı sorunu ana sayfada da var."
        # Tasarım: `.ust{padding:20px 22px 22px}` — üstten **20**. Ben 40
        # çiziyordum. Fark tek bir sayı ama SONUCU her bantta birikiyor:
        # bant 20pt uzuyor, içindeki her satır 20pt aşağı iniyor ve
        # tasarımla yan yana konunca "uygulama daha yüksek" oluyor.
        #
        # 40'ı neden yazmışım: gerçek cihazın durum çubuğuna pay. Ama
        # tasarım maketi durum çubuğu ÇİZMİYOR (`durum()` boş dönüyor,
        # gerekçesi orada yazılı: "gerçek cihaz kendi çubuğunu çizer").
        # Yani ben karşılaştırmanın bir tarafına, öteki tarafta olmayan
        # bir boşluk ekleyip sonra ikisini kıyaslıyordum.
        #
        # ⚠️ CİHAZDA BU BOŞLUK VAR: uygulama `TOPPAD` (~47pt) ekliyor ve
        # oraya durum çubuğu oturuyor. Önizleme durum çubuğu çizmediği
        # için onu da REZERVE ETMİYOR — böylece iki taraf aynı şeyi
        # gösteriyor.
        #
        # 🆕 SINIF: "KARŞILAŞTIRDIĞIN İKİ ŞEYDEN YALNIZ BİRİNE EKLEDİĞİN
        # HER PAY, ÖLÇÜMÜ DEĞİL KARŞILAŞTIRMAYI BOZAR."
        x = KENAR
        ust_y = 20 * K
        if geri:
            self.daire_eylem(KENAR, ust_y - 10 * K, "sol")
            x = KENAR + 50 * K
        if marka:
            # 🔴 31 AĞUSTOS · 8. TUR — BANT METİNLERİ GÖLGELİYDİ, TASARIMDA DEĞİL.
            # `grep text-shadow tasarim_kaynak/css.py` → SIFIR sonuç.
            # `src/ui.js` bunu bir tur önce düzeltmişti (`GolgeliMetin`in
            # `golge` varsayılanı `false` oldu); ayna düzeltmeyi almadı ve
            # marka, selam, isim, alt satır — dördü de gölgeli çiziliyordu.
            # Gölge, "aynı font mu?" sorusunu bulanıklaştıran şeydi:
            # gölgeli bir Cormorant, gölgesiz Cormorant'tan KALIN görünür.
            #
            # 🆕 SINIF: "BİR METNİN ALTINDAKİ GÖLGE BİR SÜS DEĞİL, ZEMİNE
            # VERİLMİŞ BİR CEVAPTIR — ZEMİN DEĞİŞTİYSE CEVABI DA KALDIR."
            self.metin((x, ust_y), marka, f(BOLD, 10.5), "#FAEEDC", aralik=4.6)
        if sag_ikon:
            self.daire_eylem(self.g - KENAR - 38 * K, ust_y - 10 * K, sag_ikon)

        y = ust_y + 38 * K + 34 * K
        if ustBilgi:
            self.metin((KENAR, y), buyuk(ustBilgi), f(BOLD, 10.5),
                       self.P["gold"], aralik=2.4)
            y += 10 * K + 8 * K
        if baslik:
            self.metin((KENAR, y), baslik, f(BOLD, 40), "#FFFDF9")
            y += 42 * K
        if altBilgi:
            y += 12 * K
            self.metin((KENAR, y), altBilgi, f(REG, 13),
                       self.P.get("meshAlt", "#B4A997"))
            y += 18 * K
        self.imlec = max(YB, y + 22 * K) + 14 * K
        return YB

    def ikon(self, x, y, ad, boy, renk, zorunlu=True):
        """Ionicons glifini ÜRÜNÜN KENDİ FONTUYLA çizer.

        ══════════════════════════════════════════════════════════════
        🔴 30 AĞUSTOS · 7. TUR — BU FONKSİYON ÜÇ İKONU SESSİZCE YUTTU.

        İmza `(x, y, ad, …)`. Üç yeni çağrı yerini `(ad, x, y, …)` diye
        yazmışım. `ikon_kodu(<sayı>)` None döndü, fonksiyon `return 0`
        yaptı ve HİÇBİR ŞEY OLMADI:

          · bildirim satırlarındaki kategori ikonları  → boş daireler
          · kart sayacındaki saat ikonu                → yok
          · altın düğmedeki ok                         → yok

        Gökberk boş daireleri gördü ve sordu: "acaba iconların
        görünmemesi ile ilgili bir sıkıntı mı var?" Vardı — ve tam da
        bu satırdı.

        `ikon_kodu`nun dokümanı "ÇAĞIRAN yedeğe düşer, burada sessizce
        boş kutu çizilmez" diyordu. Doğruydu ama YARIMDI: boş kutu
        çizilmiyordu, HİÇBİR ŞEY çizilmiyordu — ki o daha sessiz.

        🆕 SINIF: "BİR ÇİZİM FONKSİYONUNUN 'HİÇBİR ŞEY ÇİZMEDEN
        DÖNMESİ' EN TEHLİKELİ BAŞARISIZLIKTIR — HATA VERMEZ, İZ
        BIRAKMAZ, VE EKSİKLİK ANCAK GÖZLE FARK EDİLİR."

        Artık `zorunlu=True` (varsayılan) iken PATLIYOR. Gerçekten
        isteğe bağlı olan tek yer (dolu/boş ikon zinciri) `zorunlu=False`
        geçiyor ve bunu açıkça yazıyor.
        ══════════════════════════════════════════════════════════════
        """
        cozum = ikon_kodu(ad) if isinstance(ad, str) else None
        if cozum is None or cozum[0] is None:
            if zorunlu:
                raise ValueError(
                    "İKON ÇÖZÜLEMEDİ: %r (tip %s). Argüman sırası "
                    "`ikon(x, y, ad, boy, renk)` — adı ilk sıraya "
                    "yazdıysan sessizce hiçbir şey çizilirdi."
                    % (ad, type(ad).__name__))
            return 0
        ch, fdosya = cozum
        ft = ImageFont.truetype(os.path.join(FONTD, fdosya), int(boy * K))
        self._d().text((x, y), ch, font=ft, fill=rgb(renk) + (255,))
        return self._d().textlength(ch, font=ft)

    def daire_eylem(self, x, y, ikon_ad):
        """Tasarımdaki `.ust-eylem` — 38px halka. Uygulamada `Btn daire`."""
        d = 38 * K
        self.im.alpha_composite(
            self.yuvarlak((d, d), d // 2, (255, 255, 255, 10),
                          rgb(self.P.get("line2", self.P.get("line", "#333"))) + (200,)),
            (int(x), int(y)))
        w = self.ikon(x + d / 2 - 10 * K, y + d / 2 - 10 * K, ikon_ad, 20, "#FFFDF9")
        if not w:   # haritada yoksa hiçbir şey çizme — boş kutu çizmektense boş bırak
            pass

    def mesh_yogun(self):
        """Tasarımın `.an.mesh-yogun` sahnesi — "an" ekranlarının zemini.

        🔴 30 AĞUSTOS · 8. TUR — ÖNİZLEME BURAYA TAM FOTOĞRAF ÇİZİYORDU.

        Gökberk: "eşleşme anı sayfasında sanki background biraz daha
        saydamlaştırılarak veriliyor." Ölçtüm, haklı ve fark yapısal:

            .an.mesh-yogun {
              radial-gradient(96% 62% at 50% 8%,  altın  .42)
              radial-gradient(88% 58% at 22% 44%, mavi   .26)
              linear-gradient(180deg, #241D26 0%, --gece 62%) }
            .an::after { background:url(FOTO) center 46%/cover;
                         opacity:.20 }

        Yani zemin KOYU BİR SAHNE, fotoğraf ise onun üstünde %20'lik
        bir doku. Ben `_bant_tam` çağırıp fotoğrafı ZEMİN yapmıştım —
        %100 opak. Uygulamanın kendi `MomentScreen`i zaten koyu sahne
        çiziyor; yine yalnız AYNA yanlıştı.

        Ve bunun ikinci bir sonucu var: parlak bir fotoğrafın üstünde
        metin okunsun diye başlığa GÖLGE koymuştum. Zemin koyulaşınca
        gölgenin gerekçesi düştü — ve gölge, Gökberk'in "font tipi
        farklı, bold olup olmama durumu var" dediği şeyin ta kendisi.

        🆕 SINIF: "YANLIŞ BİR ZEMİN, ÜSTÜNDEKİ HER KARARI DA YANLIŞ
        YAPAR — GÖLGE, KALINLIK VE RENK HEP ZEMİNE VERİLMİŞ CEVAPLARDIR."
        """
        W, H = self.g, self.y
        taban = Image.new("RGBA", (W, H), rgb(self.P["bg"]) + (255,))

        # 1 · dikey taban: #241D26 → gece (%62'de biter)
        ust = rgb(self.P.get("meshUst2", "#241D26"))
        bitis = int(H * 0.62)
        for i in range(MESH_BANT):
            t = i / (MESH_BANT - 1)
            y0 = int(round(bitis * t))
            y1 = int(round(bitis * (t + 1.0 / (MESH_BANT - 1))))
            taban.alpha_composite(
                Image.new("RGBA", (W, max(1, y1 - y0)), ust + (int(255 * (1 - t)),)),
                (0, y0))

        # 2 · iki radyal hale — altın üstte ortada, mavi solda
        # Tasarımın kendi durakları:
        #   radial-gradient(96% 62% at 50%  8%, altın .42 0%, altın 0 66%)
        #   radial-gradient(88% 58% at 22% 44%, mavi  .26 0%, mavi  0 62%)
        for renk, cx, cy, rx, ry, guc, bitis in (
                (self.P["gold"],   0.50, 0.08, 0.96, 0.62, 0.42, 0.66),
                (self.P.get("purple", "#7FA8E8"), 0.22, 0.44, 0.88, 0.58, 0.26, 0.62)):
            taban.alpha_composite(radyal((W, H), renk, cx, cy, rx, ry, guc, bitis))

        # 3 · fotoğraf %20 · center 46%/cover
        foto = Image.open(os.path.join(KOK, "assets", "bant.jpg")).convert("RGBA")
        oran = max(W / foto.size[0], H / foto.size[1])
        fg, fy = int(foto.size[0] * oran), int(foto.size[1] * oran)
        foto = foto.resize((fg, fy), Image.LANCZOS)
        sx = max(0, (fg - W) // 2)
        sy = int(max(0, (fy - H)) * 0.46)
        foto = foto.crop((sx, sy, sx + W, sy + H))
        # `mix-blend-mode:screen` · opacity .20 — düz alfa DEĞİL.
        taban = screen_bindir(taban, foto, 0.20)

        self.im.alpha_composite(taban, (0, 0))

    def _bant_tam(self, baslik, marka):
        YB = self.y
        foto = Image.open(os.path.join(KOK, "assets", "bant.jpg")).convert("RGBA")
        oran = max(self.g / foto.size[0], YB / foto.size[1])
        fg, fy = int(foto.size[0] * oran), int(foto.size[1] * oran)
        foto = foto.resize((fg, fy), Image.LANCZOS)
        kat = Image.new("RGBA", (self.g, YB), rgb(self.P["gece"]) + (255,))
        sx = max(0, (fg - self.g) // 2)
        sy = int(max(0, (fy - YB)) * 0.5)
        kat.alpha_composite(foto, (0, 0), (sx, sy, sx + self.g, sy + YB))
        for i in range(PERDE_BANT):
            t = i / (PERDE_BANT - 1)
            x0 = int(round(self.g * t * 0.72))
            x1 = int(round(self.g * (t * 0.72 + 0.72 / (PERDE_BANT - 1))))
            o = PERDE_GUC * (1 - t) ** 1.35
            kat.alpha_composite(
                Image.new("RGBA", (max(1, x1 - x0), YB), (10, 6, 6, int(255 * o))), (x0, 0))
        self.im.alpha_composite(kat, (0, 0))
        if marka:
            self.golgeli((KENAR, 44 * K), marka, f(BOLD, 10.5), "#FAEEDC", aralik=4.6)
        if baslik:
            self.golgeli((KENAR, YB - 194 * K), baslik, f(BOLD, 40), "#FFFDF9")
        self.imlec = YB + 14 * K
        return YB

    # ── KART ───────────────────────────────────────────────────────
    @staticmethod
    def karis(a, b, oran):
        """İki hex rengi `oran` kadar karıştırır — RN'deki
        `backgroundColor: "rgba(224,190,122,0.03)"` katmanının
        önizlemedeki karşılığı (PIL'de alfa katmanı yerine düz karışım;
        koyu opak zeminde ikisi aynı sonucu verir)."""
        ca, cb = rgb(a), rgb(b)
        return "#%02X%02X%02X" % tuple(
            round(ca[i] + (cb[i] - ca[i]) * oran) for i in range(3))

    def kart(self, yuk, x=None, g=None, y=None, zemin=None, kenar=None, r=16,
             vurgu=False):
        """
        🔴 30 AĞUSTOS · 6. TUR — İKİ VARSAYILAN YANLIŞTI.

        1) KENAR: `kenar or goldLine` yazıyordu — yani HER KART altın
           kenarlı çiziliyordu. Tasarımda altın kenar `.kart.one`a,
           yani YALNIZ ÖNE ÇIKAN karta ait:
               .kart      { border:1px solid var(--cizgi) }
               .kart.one  { border-color:var(--altinIz); + altın tint }
           Hepsi altın olunca "öne çıkan" işareti hiçbir şeyi öne
           çıkarmıyordu. Karşılaştırma görselinde ikinci kartın da
           altın çerçeveli olması buydu.

        2) YARIÇAP: 26 çiziyordum, tasarım `.kart{border-radius:16px}`.
           10px fark, kartın karakterini değiştiriyor: 26 "yumuşak/
           samimi", 16 "kesin". Aynı ayrımı düğmede zaten yapmıştım
           (20 → 12) ve kartta yapmayı unutmuşum.

        🆕 SINIF: "BİR VARSAYILAN, EN ÇOK KULLANILAN DEĞERDİR — YANLIŞ
        SEÇİLMİŞ BİR VARSAYILAN, HATAYI HER ÇAĞRI YERİNE KOPYALAR."
        """
        x = KENAR if x is None else x
        g = (self.g - 2 * KENAR) if g is None else g
        y = self.imlec if y is None else y
        if kenar is None:
            # 🔴 8. tur — vurgulu kartın çizgisi `--altinIz` (0.13),
            # `goldLine` (0.28) DEĞİL. İkisini karıştırmak "öne çıkan"ı
            # bir fısıltıdan bir çerçeveye çeviriyordu.
            kenar = self.P.get("goldTrace", self.P.get("goldLine", "#E4D5AE")) if vurgu else \
                    self.P.get("line", "#333333")
        if zemin is None and vurgu:
            # tasarımın %5.5→0 altın gradyanı yerine sabit %3 tint
            zemin = self.karis(self.P["surface"], self.P["gold"], 0.03)
        self.im.alpha_composite(
            self.yuvarlak((g, yuk), r, rgb(zemin or self.P["surface"]) + (255,),
                          rgb(kenar) + (255,)), (x, y))
        return x, y, g

    def blok(self, x, y, g, yuk, zemin=None, r=14):
        self.im.alpha_composite(
            self.yuvarlak((g, yuk), r, rgb(zemin or self.P["bgAlt"]) + (255,)), (x, y))

    # ── DÜĞME (onaylanan sistem) ───────────────────────────────────
    def dugme(self, y, etiket, v="gold", x=None, g=None, yuk=56, ft=None, sag_ikon=None):
        x = KENAR if x is None else x
        g = (self.g - 2 * KENAR) if g is None else g
        yuk = int(yuk * K)
        # 🔴 30 Ağu · 2. tur — `ghost` VARYANTI YOKTU VE SESSİZCE TEAL
        # ÇİZİLİYORDU. Uygulamada `Btn v="ghost"` = zemin `C.bgAlt`,
        # metin `C.body`, ince `C.line` kenar; önizlemede ise dolu bir
        # TEAL düğme çıkıyordu. Bir "yoksa öteki" zinciri (`gold` değilse
        # `danger`, o da değilse `teal`) bilinmeyen her varyantı sessizce
        # ÜÇÜNCÜSÜNE çeviriyordu.
        #
        # 🆕 SINIF: "SON DALI VARSAYILAN YAPAN BİR ZİNCİR, TANIMADIĞI HER
        # ŞEYİ O DALA ÇEVİRİR — VE YANLIŞ SONUÇ HİÇ HATA VERMEZ."
        if v in ("ghost", "outline", "cizgi"):
            # 🔴 8. tur — TASARIMIN `.btn-cizgi`si DOLU DEĞİL, SAYDAM.
            #   .btn-cizgi{ min-height:48px; border-radius:12px;
            #               border:1.5px solid var(--cizgi2);
            #               background:rgba(255,255,255,.03) }
            # Ben `C.bgAlt` ile DOLU çiziyordum: kutu, üstündeki altın
            # düğmeyle aynı ağırlıkta bir yüzey oluyordu ve "ikincil
            # eylem" olduğunu söylemiyordu. Gökberk işaretledi:
            # "salon kurallarını oku butonunun şekli ve yapısı
            # tasarımdakinden farklı gibi."
            #
            # 🆕 SINIF: "İKİNCİL BİR EYLEMİ BİRİNCİLLE AYNI DOLULUKTA
            # ÇİZERSEN, SIRALAMAYI RENKLE ANLATMAYA ÇALIŞIRSIN — OYSA
            # SIRALAMA ÖNCE AĞIRLIKLA OKUNUR."
            # 🔴 8. TUR · İKİNCİ HATA, AYNI SATIRDA: YARIÇAP İKİ KEZ
            # ÖLÇEKLENİYORDU. `yuvarlak()` yarıçapı KENDİSİ `r * K`
            # yapıyor; ben de `12 * K` geçiyordum → 12·K·K = 108px.
            # 48pt'lik (144px) bir düğmede 108px yarıçap = HAP.
            # Yani `.btn-cizgi`nin dolgusunu tasarıma uydururken
            # ŞEKLİNİ tasarımdan uzaklaştırmışım — ve Gökberk'in
            # cümlesi ("şekli ve yapısı ... farklı") ikisini de
            # kapsıyordu; ben yalnız birini görmüştüm.
            #
            # 🆕 SINIF: "AYNI BİRİMİ İKİ KATMANDA ÇARPMAK, `metin()`/
            # `genislik()` ARALIK HATASININ AYNISI — BİR ÖLÇEK ÇARPANI
            # TEK BİR YERDE UYGULANMALI VE O YER İMZADA YAZMALI."
            self.im.alpha_composite(
                self.yuvarlak((g, yuk), 12, (255, 255, 255, 8),
                              rgb(self.P.get("line2", self.P["line"])) + (255,),
                              kalinlik=int(1.5 * K)),
                (int(x), int(y)))
            ft = ft or f(SEMI, 14)
            w = self.genislik(etiket, ft)
            self.metin((x + (g - w) / 2, y + (yuk - ft.size) / 2 - K),
                       etiket, ft, self.P["body"])
            return y + yuk
        ust = self.P["goldBtn"] if v == "gold" else (
            self.P["dangerBtn"] if v == "danger" else self.P["tealBtn"])
        alt = self.P.get("goldBtn2", ust) if v == "gold" else (
            self.P.get("dangerBtn2", ust) if v == "danger" else ust)
        # sıcak gölge
        gol = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(gol).rounded_rectangle(
            [x, y + 6 * K, x + g, y + yuk + 6 * K], 12 * K,
            fill=rgb(self.P.get("goldGolge", "#966E28")) + (int(255 * 0.34),))
        self.im.alpha_composite(gol.filter(ImageFilter.GaussianBlur(7 * K)))
        # gradyan
        grad = Image.new("RGBA", (g, yuk))
        gd = ImageDraw.Draw(grad)
        cu, ca = rgb(ust), rgb(alt)
        for i in range(yuk):
            t = i / max(1, yuk - 1)
            gd.rectangle([0, i, g, i + 1],
                         fill=tuple(round(cu[k] + (ca[k] - cu[k]) * t) for k in range(3)) + (255,))
        m = Image.new("L", (g, yuk), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, g - 1, yuk - 1], 12 * K, fill=255)
        grad.putalpha(m)
        # içerideki üst ışık
        isik = Image.new("RGBA", (g, yuk), (0, 0, 0, 0))
        ImageDraw.Draw(isik).rounded_rectangle(
            [K, K, g - 1 - K, yuk - 1 - K], 11 * K,
            outline=(255, 255, 255, int(255 * 0.34)), width=K)
        um = Image.new("L", (g, yuk), 0)
        ImageDraw.Draw(um).rectangle([0, 0, g, int(yuk * 0.34)], fill=255)
        isik.putalpha(Image.composite(isik.split()[3], Image.new("L", (g, yuk), 0), um))
        grad.alpha_composite(isik)
        self.im.alpha_composite(grad, (x, y))
        # ══════════════════════════════════════════════════════════
        # 🔴 30 AĞUSTOS · 6. TUR — MÜREKKEP BEYAZ DEĞİL.
        # Tasarım: `.btn-altin{color:#171009}` — altın zeminde KOYU
        # mürekkep. Uygulama da öyle (`KOYU.onGold = "#171009"`).
        # Ama önizleme `"#FFFFFF"` yazıyordu. Yani karşılaştırma
        # görselinde tasarımın düğmesi koyu, "uygulamanın" düğmesi
        # beyaz metinliydi — oysa UYGULAMA DOĞRUYDU, AYNA YANLIŞTI.
        # Gökberk'e yanlış bir kusur gösterdim.
        #
        # Ölçüm: #171009 / #C39B4C = 7.28:1 (gradyanın en koyu ucu).
        # Beyaz aynı zeminde 2.40:1 — AA'yı geçmiyor.
        #
        # 🆕 SINIF: "BOZUK BİR AYNA YALNIZ HATA GİZLEMEZ; OLMAYAN BİR
        # HATA DA UYDURUR — VE O HATAYI DÜZELTMEYE ÇALIŞMAK, ÇALIŞAN
        # KODU BOZMAKTIR."
        # ══════════════════════════════════════════════════════════
        ft = ft or f(BOLD, 16)
        mur = self.P.get("onGold", "#171009") if v == "gold" else "#FFFFFF"
        w = self.genislik(etiket, ft)
        ik_g = 0
        if sag_ikon:
            ik_g = int(17 * K + 8 * K)   # tasarım `.btn-altin{gap:8px}`
        tx = x + (g - w - ik_g) / 2
        self.metin((tx, y + (yuk - ft.size) / 2 - K), etiket, ft, mur)
        if sag_ikon:
            self.ikon(tx + w + 8 * K, y + (yuk - 17 * K) / 2, sag_ikon, 17, mur)
        return y + yuk

    def hayalet(self, y, etiket, x=None, g=None, yuk=52):
        x = KENAR if x is None else x
        g = (self.g - 2 * KENAR) if g is None else g
        yuk = int(yuk * K)
        self.im.alpha_composite(
            self.yuvarlak((g, yuk), 20, (0, 0, 0, 0), rgb(self.P["gold"]) + (255,)), (x, y))
        ft = f(BOLD, 16)
        w = self.genislik(etiket, ft)
        self.metin((x + (g - w) / 2, y + (yuk - ft.size) / 2 - K), etiket, ft, self.P["goldText"])
        return y + yuk

    # ── ÇİP / ROZET ────────────────────────────────────────────────
    # 🔴 8. tur — `ton` ÇÖZÜLEMEYİNCE SESSİZCE BEYAZA DÜŞÜYORDU.
    # `_ilan()` üçüncü çipi `ton="bilgi"` ile çiziyor — tasarımın
    # `.roz.bilgi{color:var(--bilgi) /* #7FA8E8 */}` kuralı. Ama
    # `badgeInk` sözlüğünde "bilgi" diye bir anahtar YOK; `.get(ton,
    # self.P["ink"])` onu sessizce BEYAZA çevirdi. Uygulama doğru
    # çiziyordu (`color: C.purple` = #7FA8E8) — yani ayna, üründe
    # OLMAYAN bir kusuru uydurdu ve Gökberk onu "tasarımdan farklı"
    # diye işaretledi.
    #
    # 🆕 SINIF: "SESSİZ BİR VARSAYILAN, EKSİK BİR EŞLEMEYİ BİR TASARIM
    # HATASINA ÇEVİRİR — SORAN KİŞİ ÜRÜNÜ DEĞİL AYNAYI GÖRÜR."
    #
    # `ikon()`ta bir tur önce öğrendiğim dersin aynısı: çözülemeyen ad
    # sessizce yutulmaz, ATILIR.
    TON_TASARIM = {
        # tasarımın `.roz.*` / `.cip` sınıfları → temanın token adı
        "bilgi": "purple",   # --bilgi #7FA8E8
        "iyi":   "teal",     # --guven
        "uyari": "amber",    # --uyari
        "notr":  "mutedAA",  # `.cip` ve sınıfsız `.roz` → --sessiz
    }

    def cip(self, x, y, etiket, ton=None, secili=False):
        ft = f(SEMI, 10.5)
        w = int(self.genislik(etiket, ft)) + 22 * K
        h = 26 * K
        if ton is None:
            renk = rgb(self.P["gold"])
        elif ton in self.R:
            renk = rgb(self.R[ton])
        elif ton in self.TON_TASARIM and self.TON_TASARIM[ton] in self.P:
            renk = rgb(self.P[self.TON_TASARIM[ton]])
        else:
            raise ValueError(
                "cip(): '%s' tonu çözülemedi. badgeInk anahtarları: %s · "
                "tasarım eşlemesi: %s" % (ton, sorted(self.R), sorted(self.TON_TASARIM)))
        self.im.alpha_composite(
            self.yuvarlak((w, h), 13,
                          rgb(self.P["goldBg"] if secili else self.P["bgAlt"]) + (255,),
                          renk + (255,)), (x, y))
        self.metin((x + 11 * K, y + 6 * K), etiket, ft,
                   self.P["goldText"] if secili else ("#%02X%02X%02X" % renk))
        return x + w + 8 * K

    def avatar(self, x, y, harf, boy=46, harf_renk=None):
        b = int(boy * K)
        # 🔴 8. tur — DİSK ALTIN DEĞİL, ÇİZGİ DE ALTIN DEĞİL.
        # Tasarım: zemin `#2B2430→#1E1A22`, kenar `--cizgi2`. İkisini de
        # altından çiziyordum; ölçüm (44,37,20) ↔ (39,33,43) dedi.
        # Değerler artık temadan: `avatarBg` + `line2`.
        self._d().ellipse([x, y, x + b, y + b],
                          fill=rgb(self.P["avatarBg"]) + (255,),
                          outline=rgb(self.P["line2"]) + (255,), width=K)
        # 🔴 6. tur — tasarım `.avatar{font-family:"Cormorant Garamond";
        # font-size:20px;font-weight:600;color:var(--altin)}`. Sans/15
        # çiziyordum. Serif bu sistemde "insan"ın ailesi ve avatar
        # harfi onun üç yerinden biri; sans çizince o ayrımı siliyordum.
        ft = f(SERIF_SEMI, 20)
        w = self.genislik(harf, ft)
        # `.an-av.alt{color:var(--guven)}` — eşleşme ekranında misafirin
        # harfi TEAL. Renk bir süs değil, iki tarafı ayıran tek işaret.
        self.metin((x + (b - w) / 2, y + b * 0.22), harf, ft,
                   harf_renk or self.P["gold"])

    # ── ALT SEKME ÇUBUĞU ───────────────────────────────────────────
    # `App.js`teki sekme sırası ve ikon adları — birebir.
    SEKMELER = (("ana", "Ana Sayfa"), ("kesfet", "Keşfet"), ("plan", "Planım"),
                ("tanis", "Tanış"), ("profil", "Profil"))

    def alt_bar(self, etkin=0, etiketler=None):
        """🔴 30 Ağu · 2. tur — DÖRT DAİRE YERİNE GERÇEK İKONLAR.
        Ayrıca gösterge: uygulamada ikonun ÜSTÜNDE 22×3 altın çizgi var
        (renk körlüğünden bağımsız ikinci kanal); önizlemede hiç yoktu,
        yani o kararın görünür tek kanıtı önizlemede eksikti."""
        h = 76 * K
        y = self.y - h
        self.im.alpha_composite(
            Image.new("RGBA", (self.g, h), rgb(self.P["bg"]) + (240,)), (0, y))
        self._d().rectangle([0, y, self.g, y + K],
                            fill=rgb(self.P.get("line", "#333")) + (255,))
        ft = f(SEMI, 9.5)
        ogeler = list(zip([a for a, _ in self.SEKMELER],
                          etiketler or [b for _, b in self.SEKMELER]))
        adim = self.g / len(ogeler)
        for i, (ad, e) in enumerate(ogeler):
            cx = adim * (i + 0.5)
            on = i == etkin
            renk = self.P["gold"] if on else self.P["dim"]
            if on:
                self.im.alpha_composite(
                    self.yuvarlak((22 * K, 3 * K), 1.5, rgb(self.P["gold"]) + (255,)),
                    (int(cx - 11 * K), int(y + 12 * K)))
            self.ikon(cx - 10.5 * K, y + 21 * K, ad + ("Dolu" if on else ""), 21,
                      renk, zorunlu=False) \
                or self.ikon(cx - 10.5 * K, y + 21 * K, ad, 21, renk)
            w = self.genislik(e, ft, aralik=0.3)
            self.metin((cx - w / 2, y + 48 * K), e, ft, renk, aralik=0.3)

    # ── ÜST BAŞLIK (bantsız ekranlar) ──────────────────────────────
    def baslik(self, ust, baslik, alt=None, an=False):
        """🔴 30 AĞUSTOS · 5. TUR — BANTSIZ BAŞLIK DA SERİF ÇİZİYORDU.

        17 ekranı yan yana koyunca görüldü: bantlı ekranlarda başlığı
        sans'a çevirmiştim (`bant()`), bantsız olanlarda bu işlev hâlâ
        `SERIF` kullanıyordu. Yani "Oturum · Canlı Durum" serif, "Keşfet"
        sans — aynı üründe iki farklı başlık dili.

        🆕 SINIF: **"BİR KURALI BİR YOLDA UYGULAMAK, O KURALIN TÜM
        YOLLARINDA UYGULAMAK DEĞİLDİR — AYNI İŞİ YAPAN İKİNCİ BİR
        FONKSİYON, İLKİNDE ÇÖZÜLEN HER ŞEYİ SIFIRDAN GERİ GETİRİR."**

        `an=True` (oturum tamamlandı gibi) tasarımın `.an-h1` kesiti:
        Cormorant **300**. Serif burada "an"ın ailesi.
        """
        self.metin((KENAR, 54 * K), buyuk(ust), f(BOLD, 10), self.P["gold"],
                   aralik=2.4)
        if an:
            self.metin((KENAR, 74 * K), baslik, f(SERIF_LIGHT, 40), self.P["ink"])
        else:
            self.metin((KENAR, 74 * K), baslik, f(BOLD, 34), self.P["ink"])
        if alt:
            self.metin((KENAR, 118 * K), alt, f(REG, 12.5), self.P["mutedAA"])
        self.imlec = (142 if alt else 122) * K

    def etiketle(self, s):
        h = 26 * K
        self._d().rectangle([0, 0, self.g, h], fill=(16, 12, 10, 255))
        self.metin((KENAR, 7 * K), s, f(BOLD, 10), "#FFFFFF")

    def kaydet(self, yol):
        self.im.convert("RGB").save(yol)
        return yol
