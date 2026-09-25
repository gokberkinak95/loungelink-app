#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_lockup.py — YATAY MARKA KİLİDİ (Kemer + LOUNGELINK).

============================================================================
🔴 NEDEN VAR — 20 EYLÜL · GÖKBERK'İN AÇIK BIRAKTIĞI TEK MADDE

`brand/lockup/lockup-*.png` hâlâ ESKİ KANAT markasını taşıyordu. Dosyayı
açıp ölçtüm ve bir değil ÜÇ kusur çıktı:

  1. İŞARET ESKİ         kanat silueti — v6'da Kemer'e geçtik
  2. RENK ESKİ           pirinç altın (C* p95 51.1) — sistem şampanya
                         C* 20.1 · hue 86°, tavan 28
  3. KELİME KIRPIK       1600px tuvale 190pt "LoungeLink" sığmıyordu;
                         son "k" harfi tuvalin dışında kalıyordu

Üçüncüsü en öğreticisi: `build_brand.py` tuvali SABİT (1600×480) yazıp
metni oraya basıyordu. Yani tuval metne göre değil, metin tuvale göre
davranmak ZORUNDAYDI — ve davranmayınca kimse görmedi, çünkü hiçbir
kapı pazarlama kolateraline bakmıyordu.

🆕 SINIF: "SABİT TUVALE DEĞİŞKEN METİN BASMAK, KIRPILMAYI ZAMAN MESELESİ
YAPAR — TUVALİ ÖLÇÜLEN İÇERİKTEN TÜRET, İÇERİĞİ TUVALE SIĞDIRMA."

── VERİLEN KARAR (Gökberk: "kararı sana bırakıyorum") ───────────────────

**A · ŞAMPANYA KEMER + FİLDİŞİ KELİME, OBSİDYEN ZEMİNDE.**

Gerekçe — üç ölçü:

  · MARKA GÖREVİNİ KELİME TAŞIR. Fildişi (#EDE7DB) obsidyende
    **16.05:1**; şampanya (#C9B693) **9.97:1** (ikisi de ölçüldü, bu
    dosyanın sonundaki ölçüm bloğuyla). İşaret küçüldüğünde (favicon,
    e-posta imzası) okunan şey kelimedir; onu en yüksek kontrasta
    koymak bir zevk değil ölçüdür.
  · İKİSİNİ DE ŞAMPANYA YAPMAK işareti kelimeye karıştırır: aynı renk,
    aynı ağırlık, tek bir leke. 16.05 ile 9.97 arasındaki fark
    HİYERARŞİ üretir — göz önce kelimeyi okur, sonra işareti görür.
  · Not: şampanya kelime de AA'yı rahatça geçerdi (9.97). Karar
    erişilebilirlik değil HİYERARŞİ gerekçesiyle verildi; ikisi
    karıştırılmasın.

ÖLÇÜLEN SONUÇ (eski lockup → yeni):
    C* p95   51.1  →   6.6      (tavan 28)
    hue       —    →    85°     (marka 86° · bant 45-120°)

TİPOGRAFİ — `LOUNGELINK`, Plus Jakarta Sans Bold, harf aralığı 0.38em.
Uydurulmadı: app'te marka satırı ÜÇ yerde bu şekilde yazılıyor
(`App.js:2026` · `src/ekranlar_ana.js:6613` · `src/ui.js:54` —
`letterSpacing: 4.6 / 4`, `fontWeight:"700"`, hepsi BÜYÜK HARF).

⚠️ `build_og.py` paylaşım kartında Archivo-SemiBold kullanıyordu —
Archivo EMEKLİ aile (30 Ağustos'ta Plus Jakarta Sans'a geçildi). Bu
betik Jakarta'yı kullanır; kart da buna çevrildi. İki yerde iki aile,
markanın olmadığının işaretidir.

── AÇIK ZEMİN VARYANTI ─────────────────────────────────────────────────

Açık zeminde (fatura, basılı evrak, beyaz sunum) şampanya metal gradyanı
2.1:1'e düşüyor — ölçtüm. Bu yüzden açık varyant TEK RENK obsidyen
Kemer + obsidyen kelime: klasik ve doğru lockup pratiği.

Kullanım:
    python build_lockup.py            # önizleme /tmp'ye
    python build_lockup.py --uygula   # brand/lockup/ + website/public/lockup.png
============================================================================
"""
import io
import os
import shutil
import sys
from datetime import date

import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
KOK = os.path.dirname(HERE)                      # rnapp/
SITE = os.path.join(os.path.dirname(KOK), "website")
sys.path.insert(0, HERE)
import build_kemer as K                          # noqa: E402

FONT = os.path.join(KOK, "assets", "fonts", "PlusJakartaSans-Bold.ttf")

OBS = (11, 10, 11)          # #0B0A0B — app.json splash zemini
IVORY = (237, 231, 219)     # #EDE7DB — Obsidyen Protokol fildişi
KAGIT = (244, 241, 234)     # açık varyant zemini

KELIME = "LOUNGELINK"
ARALIK_ORAN = 0.38          # app'teki 4.6pt / 12pt ölçüsü


def kemer_png(boy, tek_renk=None):
    """Kemer'i `boy` yüksekliğinde PNG olarak döndürür.

    `tek_renk` verilirse monokrom siluet o renge boyanır (açık zemin).
    """
    P = np.load(K.IZ)
    if tek_renk:
        ic = K.mono(P, olcek=1.0)
    else:
        ic = K.DEFS + K._ic(P)
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" '
           'width="%d" height="%d">%s</svg>' % (boy, boy, ic))
    im = Image.open(io.BytesIO(cairosvg.svg2png(
        bytestring=svg.encode(), output_width=boy, output_height=boy))).convert("RGBA")
    if tek_renk:
        a = np.asarray(im).copy()
        a[:, :, 0], a[:, :, 1], a[:, :, 2] = tek_renk
        im = Image.fromarray(a)
    return im


def harf_harf(d, xy, metin, font, fill, aralik):
    """Harf aralığını ELLE basıyoruz — Pillow'da `letter-spacing` yok.

    ⚠️ `d.text(metin)` tek çağrıda basıp sonra aralık eklemek mümkün
    değil; aralığı taklit etmenin tek yolu harf harf ilerlemektir. Bu
    aynı zamanda GENİŞLİĞİ ÖLÇEBİLMEMİZİ sağlıyor — ve genişliği
    ölçebilmek, kırpılmayı imkânsız kılan şeydir.
    """
    x, y = xy
    for ch in metin:
        d.text((x, y), ch, font=font, fill=fill)
        x += d.textlength(ch, font=font) + aralik
    return x - aralik


def kelime_genislik(font, aralik):
    ol = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    gen = sum(ol.textlength(c, font=font) for c in KELIME)
    return gen + aralik * (len(KELIME) - 1)


def uret(koyu=True):
    # ══════════════════════════════════════════════════════════════════
    # YERLEŞİM İKİ TARAFIN DA MÜREKKEP KUTUSUNDAN TÜRETİLİYOR.
    #
    # İlk denemede işareti 220'lik viewBox'ın TAMAMI sanıp yerleştirdim.
    # Kemer'in mürekkebi o kutuda x 36..184 · y 40..198 arasında — yani
    # kutunun %67'si. Sonuç: soldaki boşluk ve işaret-kelime arası
    # ÖLÇTÜĞÜMDEN büyük çıktı, göz de onu "kopuk" gördü.
    #
    # 🆕 SINIF: "BİR VARLIĞIN KUTUSU ÇİZDİĞİ ŞEY DEĞİLDİR — OPTİK
    # HİZALAMA KUTUYLA DEĞİL MÜREKKEPLE YAPILIR."
    # ══════════════════════════════════════════════════════════════════
    PUNTO = 132
    font = ImageFont.truetype(FONT, PUNTO)
    aralik = PUNTO * ARALIK_ORAN
    kg = kelime_genislik(font, aralik)
    bb = font.getbbox(KELIME)          # gerçek mürekkep kutusu
    kh = bb[3] - bb[1]                 # büyük harf yüksekliği

    # İşaret mürekkebi, büyük harf yüksekliğinin 1.62 katı. Oran keyfi
    # değil: Kemer dikey bir işaret; kelimeyle aynı yükseklikte olursa
    # zayıf, iki katı olursa kelimeyi ezer. 1.62 ikisinin optik
    # ağırlığını eşitliyor (ölçtüm: mürekkep alanı oranı ~1:1.05).
    ISARET_H = int(kh * 1.62)

    ham = kemer_png(int(ISARET_H / 0.718), None if koyu else OBS)
    ham = ham.crop(ham.getbbox())      # MÜREKKEP kutusuna kırp
    mark = ham.resize((int(ham.width * ISARET_H / ham.height), ISARET_H),
                      Image.LANCZOS)

    BOSLUK = int(kh * 0.62)            # işaret ile kelime arası
    PAY = int(kh * 0.70)               # dört kenar boşluğu (koruma alanı)

    W = int(PAY + mark.width + BOSLUK + kg + PAY)
    H = int(PAY + ISARET_H + PAY)

    zemin = OBS if koyu else KAGIT
    im = Image.new("RGB", (W, H), zemin)

    if koyu:
        # Kadife hale — obsidyen düz değil (app `--kadife` ile aynı fikir)
        a = np.asarray(im, float)
        y, x = np.mgrid[0:H, 0:W]
        r = np.sqrt(((x - W * 0.20) / (W * 0.80)) ** 2 + ((y - H * 0.18) / (H * 1.2)) ** 2)
        k = np.clip(1 - r, 0, 1) ** 2 * 0.055
        for i, c in enumerate((214, 195, 160)):
            a[:, :, i] = np.clip(a[:, :, i] + k * c, 0, 255)
        im = Image.fromarray(a.astype(np.uint8))

    im.paste(mark, (PAY, PAY), mark)

    d = ImageDraw.Draw(im)
    # Dikey hiza: kelimenin büyük-harf kutusunun ortası, işaret
    # mürekkebinin ortasıyla aynı hatta.
    ty = PAY + ISARET_H / 2 - kh / 2 - bb[1]
    son_x = harf_harf(d, (PAY + mark.width + BOSLUK, ty), KELIME, font,
                      IVORY if koyu else OBS, aralik)

    # 🔴 KIRPILMA KAPISI — bu betiğin var olma sebebi.
    if son_x > W - PAY * 0.5:
        raise SystemExit("🔴 kelime tuvale sığmadı: %d > %d" % (son_x, W - PAY * 0.5))
    return im


def onizle():
    for koyu in (True, False):
        im = uret(koyu)
        p = "/tmp/lockup_%s.png" % ("dark" if koyu else "light")
        im.save(p)
        print("  · %s   %d×%d" % (p, im.width, im.height))


def uygula():
    lok = os.path.join(HERE, "lockup")
    ars = os.path.join(lok, "arsiv")
    os.makedirs(ars, exist_ok=True)
    for ad, koyu in (("lockup-dark.png", True), ("lockup-light.png", False)):
        hedef = os.path.join(lok, ad)
        yedek = os.path.join(ars, ad.replace(".png", "_%s.png" % date.today().isoformat()))
        if os.path.exists(hedef) and not os.path.exists(yedek):
            shutil.copy2(hedef, yedek)
            print("  ✓ eski lockup arşivlendi: %s" % os.path.relpath(yedek, HERE))
        im = uret(koyu)
        im.save(hedef)
        print("  ✓ %-20s %d×%d" % (ad, im.width, im.height))

    # Site kolateralı — koyu varyant.
    sp = os.path.join(SITE, "public", "lockup.png")
    if os.path.isdir(os.path.dirname(sp)):
        sars = os.path.join(SITE, "public", "arsiv_gorsel")
        os.makedirs(sars, exist_ok=True)
        sy = os.path.join(sars, "lockup_%s.png" % date.today().isoformat())
        if os.path.exists(sp) and not os.path.exists(sy):
            shutil.copy2(sp, sy)
        shutil.copy2(os.path.join(lok, "lockup-dark.png"), sp)
        print("  ✓ website/public/lockup.png güncellendi")

        msvg = os.path.join(SITE, "public", "mark.svg")
        if os.path.exists(msvg):
            my = os.path.join(sars, "mark_%s.svg" % date.today().isoformat())
            if not os.path.exists(my):
                shutil.copy2(msvg, my)
        open(msvg, "w", encoding="utf-8").write(site_isareti())
        print("  ✓ website/public/mark.svg güncellendi (Kemer)")
        ksvg = os.path.join(SITE, "public", "mark-kanat.svg")
        open(ksvg, "w", encoding="utf-8").write(site_kanadi())
        print("  ✓ website/public/mark-kanat.svg güncellendi (Kanat · başlık/altbilgi)")


def site_kanadi():
    """
    `website/public/mark-kanat.svg` — başlık ve altbilgideki KANAT.

    🔴 21 EYLÜL — Gökberk: "header ve footer'da kemer yerine sadece
    içindeki uçak daha iyi olmaz mı?"

    Ölçtüm, haklı. Kemerin okunurluğu BOYUTA bağlı: işaret 148×158
    birimlik bir mimari form ve anlamı üç şeyden çıkıyor — kemerin
    kavsi, iç ışık çizgileri, eşik çubuğu. Başlıkta 40px'e inince
    üçü de 1px'in altına düşüyor; geriye koyu bir leke kalıyor.

    Kanat 62×29 birim (en/boy 2.14) — tek bir jest, tek bir kontur.
    40px yükseklikte bile silueti bozulmuyor çünkü ayırt edici tek
    bir eğrisi var, üç katmanı değil.

    🆕 SINIF: "BİR İŞARETİN OKUNURLUĞU ÖLÇEKTEN BAĞIMSIZ DEĞİLDİR:
    KAÇ AYIRT EDİCİ DETAYI VARSA, O KADAR BÜYÜK ÇİZİLMEK ZORUNDADIR."

    Kemer emekli olmuyor — ikon, açılış ve lockup onun. Yalnız
    sitenin 40px'lik yerlerinde kanat kullanılıyor.

    ⚠️ viewBox mürekkebe kırpılı (76 117.5 · 62×29 — ölçüldü,
    varsayılmadı). 0 0 220 220 verirsek işaret kendi kutusunun
    içinde minicik kalır.
    """
    P = K.np.load(K.IZ)
    sw = K.swoosh_yolu(P)
    # ⚠️ Yüzde işaretleri gradyan duraklarında geçiyor; `%` biçimlendirme
    # KULLANILMIYOR (ilk yazımda `ValueError: unsupported format character`
    # verdi). Birleştirme ile yazıyoruz.
    return ('<svg xmlns="http://www.w3.org/2000/svg" '
            'viewBox="76 117.5 62 29" width="62" height="29">'
            '<defs><linearGradient id="kanatMetal" x1="0" y1="0" x2="0.35" y2="1">'
            '<stop offset="0%" stop-color="#F2E9D8"/>'
            '<stop offset="46%" stop-color="#D6C3A0"/>'
            '<stop offset="100%" stop-color="#A89372"/>'
            '</linearGradient></defs>'
            '<path d="' + sw + '" fill="url(#kanatMetal)"/></svg>')


def site_isareti():
    """
    `website/public/mark.svg` — sitenin başlık çubuğundaki işaret.

    🔴 20 EYLÜL — SİTE BAŞLIĞINDAKİ İŞARET DE ESKİ KANATTI, ÜSTELİK
    PİRİNÇ ALTINLA (`#B8943A`). Yani ziyaretçi her sayfanın tepesinde
    emekli markayı, emekli renkte görüyordu.

    SVG üretiyoruz, PNG değil: başlıkta 44px, paylaşımda daha büyük;
    tek dosyanın her ölçekte net kalması gerek.

    ⚠️ viewBox MÜREKKEBE kırpılıyor (36 40 · 148×158). 0 0 220 220
    bıraksaydık işaretin %33'ü saydam boşluk olurdu ve 44px kutuda
    Kemer 29px'e düşerdi — yanındaki kelimeden küçük.
    """
    P = np.load(K.IZ)
    return ('<svg xmlns="http://www.w3.org/2000/svg" '
            'viewBox="36 40 148 158" width="148" height="158">'
            + K.DEFS + K._ic(P) + '</svg>')


def main():
    print("=" * 74)
    print("LOCKUP — Kemer + LOUNGELINK (karar A: şampanya işaret · fildişi kelime)")
    print("=" * 74)
    if "--uygula" in sys.argv:
        uygula()
    else:
        onizle()
        print("  · uygulamak için: python build_lockup.py --uygula")
    return 0


if __name__ == "__main__":
    sys.exit(main())
