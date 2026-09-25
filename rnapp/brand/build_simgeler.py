#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_simgeler.py — EKSİK SEMBOL GLİFLERİNİ KENDİ FONTUMUZA ÇİZER.

============================================================================
🔴 NEDEN BU YOL SEÇİLDİ — ÜÇ SEÇENEK ÖLÇÜLDÜ
============================================================================
Uygulamada 22 sembol var (✓ ✕ ★ ⚠ ✈ ⏳ ◈ ▾ …) ve HİÇBİRİ paketlediğimiz
fontlarda yok. Android'de özel bir `fontFamily` varken glif düşüşü garanti
değil: boş kare çıkabilir. 160 GERÇEK çizim yeri var (yorumlar hariç).

  1 · HEPSİNİ ŞEKLE ÇEVİR — 160 çağrı yeri elden geçecek. Üstelik çoğu
      metin dizesinin İÇİNDE ("⏱ Oturumu Aktif İşaretle"); şekle çevirmek
      dizeyi bölmek demek, yani i18n'i de bölmek. En pahalı yol.

  2 · İKON FONTU PAKETLE — ikon fontları glifleri Özel Kullanım Alanına
      koyar, bu kod noktalarına DEĞİL. Yani her çağrı yerini yine
      değiştirmek gerekir. Üstelik dış lisans.

  3 · EKSİK GLİFLERİ KENDİ FONTUMUZA EKLE  ← seçilen
      Kod hiç değişmiyor. 160 yer olduğu gibi kalıyor. Lisans temiz:
      Archivo ve Cormorant OFL-1.1 ve İKİSİNDE DE "Reserved Font Name"
      yok — OFL değişikliğe ve yeniden dağıtıma açıkça izin veriyor
      (OFL metni zaten `assets/fonts/` içinde birlikte taşınıyor).

🆕 SINIF: "BİR EKSİĞİ 160 ÇAĞRI YERİNDE DÜZELTMEK YERİNE, EKSİĞİN
KENDİSİNİ GİDERMEYİ DENE — SORUN KULLANIM DEĞİL, KAYNAKTA OLABİLİR."

============================================================================
ÇİZİM İLKELERİ
============================================================================
· Em kutusu 1000 birim (Archivo ile aynı). Semboller 0..1 normalize
  koordinatlarda tanımlanıyor, sonra ölçekleniyor.
· Optik hizalama: semboller büyük harf yüksekliğine (~700) oturuyor,
  ana hattın (baseline) 0'ından başlıyor.
· Hepsi TEK RENK ve dolgu — ince çizgi yok. Küçük boyutta kaybolmasınlar.
  (v1'de iğne ince çeperdi ve 48 pikselde yok oluyordu; aynı hatayı
  tekrarlamıyoruz.)
· Genişlik: kare semboller 1 em'in %78'i, ok/işaret olanlar daha dar.
"""
import math
import os
import sys

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FD = os.path.join(HERE, "..", "assets", "fonts")
EM = 1000
TABAN = 0        # ana hat
BOY = 700        # sembol yüksekliği (büyük harf hizası)


# ---------------------------------------------------------------------------
# ÇİZİM YARDIMCILARI — hepsi 0..1 kutusunda çalışır
# ---------------------------------------------------------------------------
def _alan(k):
    """İşaretli alan — konturun dönüş yönünü söyler."""
    s = 0.0
    for i in range(len(k)):
        x0, y0 = k[i]
        x1, y1 = k[(i + 1) % len(k)]
        s += x0 * y1 - x1 * y0
    return s / 2.0


def yonlendir(konturlar, delikler=()):
    """
    🔴 DELİKLER YANLIŞ YÖNDEYDİ VE ÜÇ SEMBOL DOLU ÇIKTI.
    ⚠'nin ünlemi, ⚙'nin göbeği, ℹ'nin "i"si — üçü de kayboldu, çünkü
    deliği "listeyi ters çevirerek" yapmıştım ve DIŞ konturun yönünü hiç
    ölçmemiştim. İki kontur aynı yöndeyse TrueType'ın sıfır-olmayan
    doldurma kuralı deliği doldurur.

    Doğrusu yönü VARSAYMAK değil HESAPLAMAK: dış kontur pozitif alan,
    delik negatif alan. İşaretli alan bunu tek satırda söylüyor.

    🆕 SINIF: "BİR DELİĞİ 'TERS ÇEVİREREK' AÇAMAZSIN — NEYE GÖRE TERS
    OLDUĞUNU ÖLÇMEDİYSEN, YARISI DOLU ÇIKAR."
    """
    out = []
    for k in konturlar:
        out.append(k if _alan(k) > 0 else k[::-1])
    for k in delikler:
        out.append(k if _alan(k) < 0 else k[::-1])
    return out


def dikdortgen(x0, y0, x1, y1):
    return [[(x0, y0), (x1, y0), (x1, y1), (x0, y1)]]


def cerceve(x0, y0, x1, y1, k):
    return yonlendir([[(x0, y0), (x1, y0), (x1, y1), (x0, y1)]],
                     [[(x0 + k, y0 + k), (x1 - k, y0 + k), (x1 - k, y1 - k), (x0 + k, y1 - k)]])


def cokgen(*n):
    return [list(n)]


def daire(cx, cy, r, n=32, ters=False):
    p = [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n))
         for i in range(n)]
    return [p[::-1] if ters else p]


def halka(cx, cy, r, k, n=32):
    return yonlendir(daire(cx, cy, r, n), daire(cx, cy, r - k, n))


def yildiz(cx, cy, r, ic=0.40, uc=5, don=math.pi / 2):
    p = []
    for i in range(uc * 2):
        rr = r if i % 2 == 0 else r * ic
        a = don + math.pi * i / uc
        p.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return [p]


def kalin_cizgi(x0, y0, x1, y1, k):
    dx, dy = x1 - x0, y1 - y0
    u = math.hypot(dx, dy) or 1
    nx, ny = -dy / u * k / 2, dx / u * k / 2
    return [[(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]]


def cokgen_n(n, cx, cy, r, don=math.pi / 2):
    return [[(cx + r * math.cos(don + 2 * math.pi * i / n),
              cy + r * math.sin(don + 2 * math.pi * i / n)) for i in range(n)]]


# ---------------------------------------------------------------------------
# SEMBOLLER — (kod noktası, genişlik oranı, konturlar)
# Koordinatlar 0..1; y yukarı doğru.
# ---------------------------------------------------------------------------
def S():
    s = {}

    # ✓ onay — kalın çift kırık çizgi
    s[0x2713] = (0.80, kalin_cizgi(0.10, 0.48, 0.36, 0.20, 0.17)
                 + kalin_cizgi(0.33, 0.20, 0.90, 0.80, 0.17))
    # ✕ çarpı
    s[0x2715] = (0.78, kalin_cizgi(0.14, 0.14, 0.84, 0.84, 0.15)
                 + kalin_cizgi(0.14, 0.84, 0.84, 0.14, 0.15))
    # ★ dolu yıldız
    s[0x2605] = (0.86, yildiz(0.45, 0.48, 0.45))
    # ⭐ aynı biçim (emoji karşılığı metin bağlamında da kullanılıyor)
    s[0x2B50] = (0.86, yildiz(0.45, 0.48, 0.45))
    # ✦ dört uçlu parıltı
    s[0x2726] = (0.78, yildiz(0.42, 0.48, 0.44, ic=0.34, uc=4, don=math.pi / 2))
    # ◈ elmas içinde elmas
    s[0x25C8] = (0.82, yonlendir(cokgen_n(4, 0.44, 0.48, 0.46),
                                cokgen_n(4, 0.44, 0.48, 0.19)))
    # ◉ dolu daire içinde halka
    s[0x25C9] = (0.82, halka(0.44, 0.48, 0.44, 0.10) + daire(0.44, 0.48, 0.20))
    # ⬡ altıgen çerçeve
    s[0x2B21] = (0.82, yonlendir(cokgen_n(6, 0.44, 0.48, 0.46),
                                cokgen_n(6, 0.44, 0.48, 0.32)))
    # ▴ ▾ küçük üçgenler
    s[0x25B4] = (0.56, cokgen((0.08, 0.30), (0.50, 0.66), (0.92, 0.30)))
    s[0x25BE] = (0.56, cokgen((0.08, 0.66), (0.92, 0.66), (0.50, 0.30)))
    # ⬆ yukarı ok
    s[0x2B06] = (0.72, cokgen((0.40, 0.86), (0.06, 0.48), (0.28, 0.48),
                              (0.28, 0.08), (0.52, 0.08), (0.52, 0.48), (0.74, 0.48)))
    # ⇄ iki yönlü ok
    s[0x21C4] = (0.94, kalin_cizgi(0.08, 0.62, 0.80, 0.62, 0.09)
                 + cokgen((0.92, 0.62), (0.68, 0.76), (0.68, 0.48))
                 + kalin_cizgi(0.14, 0.30, 0.86, 0.30, 0.09)
                 + cokgen((0.02, 0.30), (0.26, 0.44), (0.26, 0.16)))
    # ☐ boş kutu · ☑ işaretli kutu
    s[0x2610] = (0.82, cerceve(0.06, 0.08, 0.82, 0.84, 0.09))
    s[0x2611] = (0.82, cerceve(0.06, 0.08, 0.82, 0.84, 0.09)
                 + kalin_cizgi(0.22, 0.44, 0.38, 0.26, 0.13)
                 + kalin_cizgi(0.36, 0.26, 0.68, 0.66, 0.13))
    # ⚠ üçgen ünlem
    s[0x26A0] = (0.90, yonlendir(
        [[(0.45, 0.92), (0.92, 0.04), (-0.02, 0.04)]],
        [[(0.39, 0.28), (0.51, 0.28), (0.51, 0.66), (0.39, 0.66)],
         [(0.39, 0.12), (0.51, 0.12), (0.51, 0.23), (0.39, 0.23)]]))
    # ℹ bilgi — dolu daire, içinde "i" boşluğu
    s[0x2139] = (0.80, yonlendir(
        daire(0.42, 0.48, 0.45),
        [[(0.36, 0.18), (0.48, 0.18), (0.48, 0.54), (0.36, 0.54)],
         [(0.36, 0.62), (0.48, 0.62), (0.48, 0.76), (0.36, 0.76)]]))
    # ✈ uçak — sadeleştirilmiş, dolu
    s[0x2708] = (0.94, cokgen((0.04, 0.40), (0.36, 0.46), (0.60, 0.18), (0.72, 0.18),
                              (0.60, 0.48), (0.92, 0.54), (0.92, 0.64), (0.60, 0.62),
                              (0.70, 0.90), (0.58, 0.90), (0.34, 0.60), (0.04, 0.52)))
    # ✉ zarf
    s[0x2709] = (0.92, cerceve(0.04, 0.16, 0.88, 0.76, 0.07)
                 + kalin_cizgi(0.08, 0.72, 0.46, 0.42, 0.07)
                 + kalin_cizgi(0.46, 0.42, 0.84, 0.72, 0.07))
    # ⏱ kronometre
    s[0x23F1] = (0.86, halka(0.44, 0.42, 0.40, 0.10)
                 + dikdortgen(0.34, 0.84, 0.54, 0.92)
                 + kalin_cizgi(0.44, 0.42, 0.44, 0.68, 0.07)
                 + kalin_cizgi(0.44, 0.42, 0.64, 0.42, 0.07))
    # ⏳ kum saati
    s[0x23F3] = (0.72, cokgen((0.06, 0.90), (0.66, 0.90), (0.36, 0.50))
                 + cokgen((0.06, 0.06), (0.66, 0.06), (0.36, 0.46))
                 + dikdortgen(0.02, 0.90, 0.70, 0.97)
                 + dikdortgen(0.02, -0.01, 0.70, 0.06))
    # ⚖ terazi
    # 🔴 İLK HÂLİ TANINMIYORDU: kefeler üçgendi ve kirişe DEĞMİYORDU,
    # ortaya "T harfi + iki üçgen" gibi bir şey çıkıyordu. Terazi,
    # kefelerin kirişten SARKTIĞI için terazidir — askı çizgileri şart.
    s[0x2696] = (0.90, yonlendir(
        [[(0.41, 0.08), (0.49, 0.08), (0.49, 0.80), (0.41, 0.80)],      # direk
         [(0.04, 0.76), (0.86, 0.76), (0.86, 0.83), (0.04, 0.83)],      # kiriş
         [(0.20, 0.02), (0.70, 0.02), (0.70, 0.10), (0.20, 0.10)],      # taban
         [(0.12, 0.50), (0.16, 0.50), (0.16, 0.76), (0.12, 0.76)],      # sol askı
         [(0.74, 0.50), (0.78, 0.50), (0.78, 0.76), (0.74, 0.76)],      # sağ askı
         [(0.00, 0.50), (0.28, 0.50), (0.21, 0.30), (0.07, 0.30)],      # sol kefe
         [(0.62, 0.50), (0.90, 0.50), (0.83, 0.30), (0.69, 0.30)]]))    # sağ kefe
    # ⚙ dişli — sekiz dişli halka
    # 🔴 İLK HÂLDE DİŞLER AYRI PARÇALARDI: sekiz küçük dörtgen halkanın
    # ÜSTÜNE değil YANINA düşüyordu ve dişli "noktalı bir çember" gibi
    # göründü. Dişli TEK GÖVDEDİR — dış kontur, diş diş ilerleyen tek bir
    # kapalı yol olmak zorunda.
    dis, ic_r, dis_r = [], 0.30, 0.45
    N = 8
    for i in range(N):
        a0 = 2 * math.pi * i / N
        w = math.pi / N * 0.52          # diş yarı genişliği
        b = math.pi / N * 0.46          # boşluk yarı genişliği
        dis += [(dis_r * math.cos(a0 - w) + 0.46, dis_r * math.sin(a0 - w) + 0.48),
                (dis_r * math.cos(a0 + w) + 0.46, dis_r * math.sin(a0 + w) + 0.48),
                (ic_r * math.cos(a0 + w + b) + 0.46, ic_r * math.sin(a0 + w + b) + 0.48),
                (ic_r * math.cos(a0 + 2 * math.pi / N - w - b) + 0.46,
                 ic_r * math.sin(a0 + 2 * math.pi / N - w - b) + 0.48)]
    s[0x2699] = (0.94, yonlendir([dis], daire(0.46, 0.48, 0.16)))
    return s


SEMBOL = S()


def glif_ad(kod):
    return "llsim%04X" % kod


def ekle(yol, cikti):
    fnt = TTFont(yol)
    glyf, hmtx = fnt["glyf"], fnt["hmtx"]
    cmaps = [t for t in fnt["cmap"].tables if t.isUnicode()]
    sira = fnt.getGlyphOrder()
    eklenen = 0
    for kod, (gen, konturlar) in SEMBOL.items():
        if any(kod in t.cmap for t in cmaps):
            continue                      # zaten varsa dokunma
        ad = glif_ad(kod)
        pen = TTGlyphPen(None)
        for kontur in konturlar:
            pen.moveTo((round(kontur[0][0] * EM), round(TABAN + kontur[0][1] * BOY)))
            for x, y in kontur[1:]:
                pen.lineTo((round(x * EM), round(TABAN + y * BOY)))
            pen.closePath()
        glyf[ad] = pen.glyph()
        hmtx[ad] = (round(gen * EM), 0)
        if ad not in sira:
            sira.append(ad)
        for t in cmaps:
            t.cmap[kod] = ad
        eklenen += 1
    fnt.setGlyphOrder(sira)
    # 🔴 maxp/hhea kendiliğinden güncellenmiyor — yazarken fontTools
    # hesaplıyor ama numGlyphs'i elle senkronlamak gerekiyor.
    fnt["maxp"].numGlyphs = len(sira)
    fnt.save(cikti)
    return eklenen


if __name__ == "__main__":
    # 🔴 30 AĞUSTOS — GECE SİSTEMİ GÖVDE AİLESİNİ DEĞİŞTİRDİ.
    # Archivo → Plus Jakarta Sans. Semboller (✓ ✕ ⚠ ✈ …) özgün fontlarda
    # YOK; bu betik onları çiziyor. Yeni aile listeye eklenmezse uygulamada
    # o karakterler sessizce SİSTEM fontuna düşer — yani "kesilme" sorunu
    # geri gelir.
    #
    # 🆕 SINIF: "BİR GÖVDE FONTUNU DEĞİŞTİRİRKEN, ESKİSİNE SONRADAN
    # EKLENMİŞ HER ŞEYİ DE TAŞIMAN GEREKİR — FONT BİR DOSYA DEĞİL, BİR
    # BİRİKİMDİR."
    #
    # ⚠️ JetBrains Mono LİSTEDE YOK ve olmamalı: o yalnız RAKAM çiziyor
    # (sayaç, yüzde, kredi). Tek genişlikli bir aileye orantılı sembol
    # eklemek, o ailenin tek işini bozar.
    hedef = ["PlusJakartaSans-Regular.ttf", "PlusJakartaSans-Medium.ttf",
             "PlusJakartaSans-SemiBold.ttf", "PlusJakartaSans-Bold.ttf",
             "Archivo-Regular.ttf", "Archivo-Medium.ttf", "Archivo-SemiBold.ttf",
             "Archivo-Bold.ttf", "CormorantGaramond-Bold.ttf",
             "CormorantGaramond-SemiBold.ttf",
             # 🔴 30 Ağu — LIGHT KESİTİ EKLENDİ VE AYNI DERS İKİNCİ KEZ
             # ÖDENDİ. Cormorant'ın üç dosyası da bu tur yeniden
             # üretildi (ikisi sahte "Bold"du, bkz. theme.js) — yani
             # buradan eklenmiş 22 glif SİLİNDİ ve bu betiği yeniden
             # koşmadan fark edilmezdi.
             # "BİR FONT BİR DOSYA DEĞİL BİR BİRİKİMDİR" dersi bu
             # dosyanın 30 satır yukarısında yazıyordu; yazmak
             # uygulamak değilmiş.
             "CormorantGaramond-Light.ttf"]
    print("=" * 68)
    print("SEMBOL GLİFLERİ EKLENİYOR — %d sembol" % len(SEMBOL))
    print("=" * 68)
    for ad in hedef:
        yol = os.path.join(FD, ad)
        if not os.path.exists(yol):
            print("  ✗ %s yok" % ad)
            continue
        n = ekle(yol, yol)
        print("  ✓ %-32s %d glif eklendi" % (ad, n))
    print("\nLisans: Archivo ve Cormorant OFL-1.1, ikisinde de Reserved Font Name")
    print("YOK — değişiklik ve yeniden dağıtım serbest. OFL metinleri")
    print("assets/fonts/ içinde birlikte taşınıyor.")
