#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ekran_uret.py — PAZARLAMA İÇİN ÜRÜN EKRANLARINI ÜRETİR.

🔴 NEDEN VAR
Gökberk website ve Instagram için yeni tasarımın ekran görüntülerini
istedi. Emülatör yok, gerçek cihaz görüntüsü alamıyorum. Elde iki kötü
seçenek vardı (eski görüntüler = yanlış ürün; serbest çizim = olmayan
ürün). Üçüncü yolu `mockup.py` açtı: renk `theme.js`ten, geometri
`ui.js`ten, METİN `i18n.js`ten geliyor.

🔴 HANGİ EKRANLAR — VE NEDEN BU SIRA
Gökberk "splash, chat, oturum tamamlama, oturum başlatma, keşif, tanış,
profil" dedi ve "sen karar ver" diye ekledi. Karar verdim ve LİSTEYE
İKİ EKRAN EKLEDİM, ÇÜNKÜ ONUN LİSTESİ ÜRÜNÜN FARKINI GÖSTERMİYOR:

  01 splash          — marka + söz
  02 kesfet          — ürünün kalbi: uyumlu ilanlar + kural rozetleri
  03 kural  ★EKLENDİ — KURAL MOTORU. Bizi rakipten ayıran tek şey bu.
                       Rakip "no airline restrictions" diyor ve
                       DragonPass'te yanılıyor. Biz karta göre cevap
                       veriyoruz. Bu ekran yoksa, farkımız görünmüyor.
  04 eslesme ★EKLENDİ — "Eşleştiniz." Duygusal doruk; Instagram'ın
                       en çok paylaşılan karesi bu tür ekranlardır.
  05 tanis           — aynı salondaki yolcular
  06 sohbet          — canlı durum + "Oturumu Başlat"
  07 oturum          — canlı oturum + "Oturumu Tamamla"
  08 puanla          — oturum tamamlandı, güven döngüsü kapanıyor
  09 profil          — güven: puan, oturum, LoungePuan, kademe
  10 kesfet_koyu     — aynı ekran koyu temada (yeni temanın kanıtı)

🆕 SINIF: "PAZARLAMA EKRANINI ÜRÜN SAHİBİNİN SAYDIĞI EKRANLARDAN DEĞİL,
ÜRÜNÜN FARKINI TAŞIYAN EKRANLARDAN SEÇ — LİSTE İSTEK, SEÇİM İŞTİR."

TAVAN 0 — üretilen her PNG `ekran_check.py` ile ölçülür.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from mockup import (buyuk, SERIF_SEMI, BOLD, K, KENAR, MED, MONO_MED, MONO_SEMI, REG, SEMI, SERIF,  # noqa: E402
                    SERIF_LIGHT, Ekran, f, rgb,
                    sozluk, temiz)

CIKTI = os.path.join(KOK, "ekranlar_render")
T = sozluk("tr")


def t(k, ye=""):
    """i18n'den metin. Anahtar yoksa PATLA — sessizce uydurma metin
    yazmak, ürünün söylemediğini söylemektir."""
    v = T.get(k)
    if v is None:
        if ye:
            return ye
        raise KeyError("i18n'de yok: %s" % k)
    return v


# ══════════════════════════════════════════════════════════════════
# EK PARÇALAR — mockup.Ekran'a bu dosyada eklenenler
# ══════════════════════════════════════════════════════════════════
def satir(e, x, y, sol, sag, ft=None, renk=None, sag_renk=None, sag_ft=None):
    ft = ft or f(REG, 12.5)
    e.metin((x, y), sol, ft, renk or e.P["mutedAA"])
    sf = sag_ft or f(SEMI, 12.5)
    w = e.genislik(sag, sf)
    e.metin((x + e.gen_ic - w, y), sag, sf, sag_renk or e.P["ink"])


def ayirac(e, x, y, g, alfa=90):
    """1px ayraç — tasarımın `--cizgi`si.

    🔴 31 AĞUSTOS · 8. TUR — İKİ HATA ÜST ÜSTEYDİ VE SONUÇ ALTIN
    BİR CETVELDİ.

      1) YANLIŞ TOKEN. `goldLine` (altının %28'i) kullanıyordum;
         tasarımın ayracı `--cizgi` = rgba(232,214,182,.10) — yani
         altın DEĞİL, sıcak beyazın çok soluk bir izi.
      2) ALFA HİÇ UYGULANMIYORDU. `ImageDraw.rectangle(fill=(r,g,b,a))`
         RGBA olmayan bir çizim bağlamında alfayı YOK SAYAR. Yani
         `alfa=160` yazıp %100 opak çiziyordum ve bunu fark etmedim,
         çünkü sayı kodda duruyordu.

    Ölçtüm: sohbet başlığının altındaki çizgi (119,99,45) — kalın,
    doygun bir altın. Tasarımda o çizgi HİÇ YOK (`.ust.ince-ust`
    gövdeye bir degradeyle bağlanıyor), başka yerlerde ise zar zor
    görünür.

    🆕 SINIF: "KODDA DURAN BİR PARAMETRE, ETKİ ETTİĞİNİN KANITI
    DEĞİLDİR — ÇİZDİĞİN PİKSELİ OKU."
    """
    kat = Image.new("RGBA", (int(g), max(1, K)), rgb(e.P["line"]) + (int(alfa),))
    e.im.alpha_composite(kat, (int(x), int(y)))


def yildiz(e, x, y, n=5, dolu=5, boy=15):
    """★ glifini font'a bırakmıyorum — Archivo'da yok. Çokgen çiziyorum."""
    import math
    r = boy * K / 2.0
    for i in range(n):
        cx, cy = x + i * (boy * K + 4 * K) + r, y + r
        pts = []
        for j in range(10):
            rr = r if j % 2 == 0 else r * 0.42
            a = -math.pi / 2 + j * math.pi / 5
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        e._d().polygon(pts, fill=rgb(e.P["gold"] if i < dolu else e.P["bgAlt"]) + (255,))
    return x + n * (boy * K + 4 * K)


def balon(e, y, metin, ben=False, saat=""):
    """Sohbet balonu. Genişlik metne göre, en fazla %74."""
    ft = f(REG, 13.5)
    ic = 14 * K
    enfazla = int(e.g * 0.74) - 2 * ic
    kelimeler, satirlar, cur = metin.split(" "), [], ""
    for w in kelimeler:
        d = (cur + " " + w).strip()
        if e.genislik(d, ft) > enfazla and cur:
            satirlar.append(cur)
            cur = w
        else:
            cur = d
    if cur:
        satirlar.append(cur)
    # 🔴 30 Ağu · 4. tur — saat balonun İÇİNDE (uygulamada da öyle),
    # MONO ve balonun yüksekliği ona göre. Eskiden dışarıda ayrı bir
    # satırdaydı ve her balonun altında boş bir şerit açıyordu.
    sf = f(MONO_MED, 9.5)
    gen = int(max(e.genislik(s, ft) for s in satirlar)) + 2 * ic
    if saat:
        gen = max(gen, int(e.genislik(saat, sf)) + 2 * ic)
    yuk = len(satirlar) * int(ft.size * 1.42) + 2 * ic - 2 * K + (16 * K if saat else 0)
    x = e.g - KENAR - gen if ben else KENAR
    zemin = e.P.get("balonBen", e.P["goldSoft"]) if ben else e.P["surface"]
    kat = e.yuvarlak((gen, yuk), 16, rgb(zemin) + (255,),
                     rgb((e.P.get("goldTrace") or e.P.get("goldLine", "#E4D5AE"))
                         if ben else e.P["line"]) + (255,))
    e.im.alpha_composite(kat, (x, y))
    for i, s in enumerate(satirlar):
        e.metin((x + ic, y + ic - 2 * K + i * int(ft.size * 1.42)), s, ft,
                # 🔴 8. tur — kendi mesajımın metni de GÖVDE rengi.
                # Tasarımda `.bal.ben` yalnız zemini değiştiriyor.
                e.P["body"])
    if saat:
        # Tasarım `.bal time{display:block}` → her iki balonda da SOLA.
        e.metin((x + ic, y + yuk - 17 * K), saat, sf, e.P["dim"])
    return y + yuk + 10 * K


def bandrol(e, y, metin, ton="ok", nokta=False):
    """
    Ekran genişliğinde ince durum şeridi (kural verdikti, oturum aktif).
    Punto ÖLÇÜLEREK sığdırılır — ilk render'da bu şerit sağdan kesilmişti.
    `nokta=True` ise sola dolu bir daire çizilir; ürün metnindeki "●"
    karakteri Archivo'da yok, o yüzden ÇİZİLİYOR, yazılmıyor.
    """
    # 🔴 ALFA 30 İDİ VE AÇIK TEMADA EN KÖTÜ ORAN 4.49:1 ÇIKTI — AA'nın
    # 4.5'ini KIL PAYI kaçırıyordu. Ton zemini kendi rengiyle boyamak,
    # zemini mürekkebin YÖNÜNE çekiyor; yani tint arttıkça kontrast
    # DÜŞÜYOR. Ölçüp 20'ye indirdim: en kötü oran 4.76:1.
    # (Koyu temada zaten 7.38–9.91 aralığındaydı.)
    renk = rgb(e.R.get(ton, e.P["gold"]))
    yuk = 40 * K
    kat = e.yuvarlak((e.g - 2 * KENAR, yuk), 14, renk + (20,), renk + (255,))
    e.im.alpha_composite(kat, (KENAR, y))
    x = KENAR + 14 * K
    if nokta:
        e._d().ellipse([x, y + yuk / 2 - 5 * K, x + 10 * K, y + yuk / 2 + 5 * K],
                       fill=renk + (255,))
        x += 18 * K
    ft = e.sigdir(metin, SEMI, 12, e.g - 2 * KENAR - (x - KENAR) - 14 * K, alt=9)
    e.metin((x, y + (yuk - ft.size) / 2 - K), metin, ft, "#%02X%02X%02X" % renk)
    return y + yuk


# `gen_ic` = kart içi kullanılabilir genişlik (satır yardımcısı için)
Ekran.gen_ic = property(lambda self: self._gi)
Ekran._gi = 0


# ══════════════════════════════════════════════════════════════════
# 01 · SPLASH
# ══════════════════════════════════════════════════════════════════
def splash():
    e = Ekran()
    e.bant("", None, marka=None, tam=True)
    mark = Image.open(os.path.join(KOK, "assets", "mark-light.png")).convert("RGBA")
    mark.thumbnail((int(e.g * 0.30), int(e.g * 0.30)), Image.LANCZOS)
    e.im.alpha_composite(mark, ((e.g - mark.size[0]) // 2, int(e.y * 0.30)))
    ft = f(BOLD, 24)
    w = e.genislik("LOUNGELINK", ft)
    e.golgeli(((e.g - w) / 2 - 5 * K, e.y * 0.30 + mark.size[1] + 26 * K),
              "LOUNGELINK", ft, "#FFFDF9")
    for i, s in enumerate((t("tagline1"), t("tagline2"))):
        sf = f(SERIF, 34)
        w = e.genislik(s, sf)
        e.golgeli(((e.g - w) / 2, e.y * 0.30 + mark.size[1] + 78 * K + i * 44 * K),
                  s, sf, "#F6E4C4" if i else "#FFFDF9")
    return e


# ══════════════════════════════════════════════════════════════════
# 02 · KEŞFET
# ══════════════════════════════════════════════════════════════════
# ══════════════════════════════════════════════════════════════════
# 🔴 30 AĞUSTOS — ÜRETİCİ ARTIK UYGULAMANIN AYNASI (Gökberk: "B olur").
#
# İki seçenek vardı: (A) önizlemeyi elle güzelleştirmek, (B) üreticiyi
# uygulamanın YAPISINA birebir bağlamak. Gökberk B'yi seçti ve doğru
# seçim buydu — çünkü A, güzel ama YALAN bir önizleme üretir.
#
# Bu turdan önce üretici ile uygulama şu noktalarda AYRIŞIYORDU:
#
#   üretici (eski)            uygulama (yeni · tasarım)
#   ─────────────────────     ─────────────────────────────
#   isim → salon aynı blokta  kart-üst: kişi + kalkan + uyum
#   uyum "%94" · orantılı     uyum "94" · MONO · altında UYUM
#   salon avatarın yanında    kart-salon kendi satırında, iri
#   saat düz satır            kart-alt: sayaç + altın düğme
#   düğme tam alt, tek başına düğme sayaçla aynı satırda
#
# Yani üretici, uygulamanın bir ÖNCEKİ sürümünü çiziyordu ve ben ona
# bakıp "uygulandı" diyordum.
#
# 🆕 SINIF: **"ÜRÜNÜN KENDİSİNİ DEĞİL BİR TEMSİLİNİ ÖLÇÜYORSAN,
# ÖLÇTÜĞÜN ŞEY TEMSİLİN GÜNCELLİĞİDİR — ÜRÜNÜN DEĞİL."**
#
# Ölçüler `src/ekranlar_ana.js` kart bloğundan birebir alındı:
#   avatar 44 · kalkan 17 (sağ-alt −3) · isim FS.lg/600 ·
#   mertebe FS.xs +3 · uyum FS.title MONO + FS.micro etiket +4 ·
#   salon FS.lg/600 marginTop SP[3] · term FS.sm +4 ·
#   rozetler · kart-alt marginTop SP[4], sayaç solda, düğme flex:1
# ══════════════════════════════════════════════════════════════════
def _ilan(e, y, ad, salon, saat, ton, rozet_metin, aciklama, ucus=None,
          eslesme=None, kapali=False, kalan=None, mertebe=None, kalkan=True,
          ucus3=None, vurgu=False):
    # 🔴 6. tur — KART YÜKSEKLİĞİ TASARIMDAN HESAPLANDI, GÖZLE DEĞİL.
    #   17 pad + 44 kişi bloğu + 15 + 25 salon + 4 + 16 terminal
    # + 13 + 23 rozet + 17 + 48 düğme + 17 pad = 239
    # 258 çiziyordum: kartın altında 19px ölü boşluk vardı ve iki kart
    # yan yana konunca uygulama tasarımdan gözle görülür biçimde daha
    # seyrek duruyordu.
    yuk = (281 if aciklama else 239) * K
    # `vurgu` = tasarımdaki `.kart.one` — YALNIZ ilk kart.
    x, y, g = e.kart(yuk, y=y, vurgu=vurgu)
    e._gi = g - 32 * K
    ix = x + 16 * K
    ig = g - 32 * K

    # ── kart-üst ── avatar + kalkan · isim/mertebe · uyum
    e.avatar(ix, y + 16 * K, ad[0], boy=44)
    if kalkan:
        # Güven kalkanı: avatarın sağ-alt köşesine DEĞİYOR (−3, −3),
        # ayrı bir satırda değil. Uygulamadaki `h.badge` dalı.
        # 🔴 8. tur — DAİRENİN İÇİ BOŞTU.
        # Tasarım: `.kalkan{background:var(--guven)}` + İÇİNDE kalkan
        # ikonu (`ik(I['kalkan'],9,...)`). Uygulamada var
        # (`<Ikon ad="guvenlik" boy={9} renk={C.bg} />`), önizlemede
        # yalnız yeşil bir daire çiziliyordu — yani "doğrulanmış"
        # işareti, neyi doğruladığını söylemeyen bir benek oluyordu.
        #
        # 🆕 SINIF: "BİR ROZETİN ANLAMINI TAŞIYAN ŞEY RENGİ DEĞİL
        # İŞARETİDİR — RENK YALNIZ ONU BULMANI SAĞLAR."
        kb = 17 * K
        kx = int(ix + 44 * K - kb + 3 * K)
        ky_ = int(y + 16 * K + 44 * K - kb + 3 * K)
        e.im.alpha_composite(
            e.yuvarlak((kb, kb), kb / 2, rgb(e.P["teal"]) + (255,),
                       rgb(e.P["card"]) + (255,), kalinlik=2), (kx, ky_))
        e.ikon(kx + 4 * K, ky_ + 4 * K, "guvenlik", 9, e.P["bg"])
    e.metin((ix + 56 * K, y + 18 * K), ad, f(BOLD, 16), e.P["ink"])
    if mertebe:
        e.metin((ix + 56 * K, y + 41 * K), mertebe, f(REG, 10.5), e.P["mutedAA"])
    if eslesme:
        # MONO ŞART — uygulamada `MONO[600]`. Kartlar arası karşılaştırılan
        # bir sayı, orantılı bir ailede hizalanmaz.
        # tasarım `.uyum b{font-size:22px}` — 20 çiziyordum
        ft = f(MONO_SEMI, 22)
        s = str(eslesme)
        w = e.genislik(s, ft)
        e.metin((x + g - 16 * K - w, y + 16 * K), s, ft, e.P["teal"])
        sf = f(SEMI, 9)
        s2 = buyuk(t("matchWord"))
        w2 = e.genislik(s2, sf)
        e.metin((x + g - 16 * K - w2, y + 40 * K), s2, sf, e.P["dimAA"])

    # ── kart-salon ── kendi satırında, iri
    # 🔴 6. tur — tasarım `.kart-salon{font-size:19px;font-weight:600}`.
    # 16 çiziyordum: mekân adı, isimle AYNI boydaydı ve kartta iki eşit
    # başlık oluyordu. Tasarımda mekân daha iri — çünkü kartın ikinci
    # cümlesi o.
    e.metin((ix, y + 76 * K), salon, f(SEMI, 19), e.P["ink"])
    # ── kart-term ── tasarım 12px
    e.metin((ix, y + 102 * K), saat, f(REG, 12), e.P["mutedAA"])

    # ── rozet sırası ──
    cy = y + 134 * K
    cx = e.cip(ix, cy, rozet_metin, ton=ton)
    if ucus:
        cx = e.cip(cx, cy, ucus, ton="info")
    # 🔴 Tasarımda ÜÇ çip var (Misafir ücretsiz · TK1978 · Aynı uçuş);
    # ben ikisini çiziyordum. Üçüncüsü satıra sığmıyorsa ALT SATIRA
    # geçiyor — tasarımdaki `.roz-sira{flex-wrap:wrap}` da öyle.
    if ucus3:
        gf = f(SEMI, 10.5)
        if cx + e.genislik(ucus3, gf) + 26 * K > x + g - 16 * K:
            e.cip(ix, cy + 30 * K, ucus3, ton="bilgi")
        else:
            e.cip(cx, cy, ucus3, ton="bilgi")

    ay = y + 174 * K
    if aciklama:
        ft = f(REG, 11.5)
        e.blok(ix, ay, ig, 40 * K, zemin=e.P["bgAlt"])
        e.metin((ix + 12 * K, ay + 12 * K), aciklama, ft, e.P["mutedAA"])
        ay += 52 * K

    # ── kart-alt ── sayaç SOLDA, düğme kalan genişlikte
    sol_g = 0
    if kalan and not kapali:
        # 🔴 6. tur — tasarımda sayacın SOLUNDA saat ikonu var
        # (`.sayac{gap:6px}` + `ik(I['saat'],13)`). Önizlemede yoktu;
        # uygulamada `Sayac` bileşeni onu çiziyor. Ayna eksikti.
        e.ikon(ix, ay + 14 * K, "saat", 13, e.P["mutedAA"])
        ft = f(MONO_MED, 12)
        e.metin((ix + 19 * K, ay + 15 * K), kalan, ft, e.P["body"])
        sol_g = int(19 * K + e.genislik(kalan, ft)) + 12 * K
    if kapali:
        e.im.alpha_composite(
            e.yuvarlak((ig, 44 * K), 12, rgb(e.P["bgAlt"]) + (255,),
                       rgb(e.R["block"]) + (200,)), (ix, ay))
        ft = f(SEMI, 12.5)
        s = t("cannotApply")
        w = e.genislik(s, ft)
        e.metin((ix + (ig - w) / 2, ay + 14 * K), s, ft, e.R["block"])
    else:
        e.dugme(ay, t("reqSoon"), "gold", x=int(ix + sol_g), g=int(ig - sol_g),
                yuk=48, ft=f(BOLD, 14), sag_ikon="sag")
    return y + yuk + 14 * K


def kesfet(kapsam=None):
    e = Ekran(kapsam)
    e.doku()
    # 🔴 30 Ağu · 5. tur — BAŞLIK ARTIK YER SÖYLÜYOR, SEKME ADI DEĞİL.
    # Tasarım (tasarim/ref/00_kesfet.png): İSTANBUL · IST / Terminal A /
    # "Kalkışına 3 sa 12 dk · 6 host yayında". Uygulamada da öyle oldu
    # (src/ekranlar_ana.js `basKonum`), üretici ona ayna olmalı — yoksa
    # önizleme ürünün artık olmayan bir sürümünü gösterir.
    e.bant("İstanbul", "İSTANBUL · IST",
           altBilgi="Kalkışına 3 sa 12 dk · 6 host yayında",
           sag_ikon="filtre")
    y = e.imlec
    y = bandrol(e, y, t("sameFlightStrip").replace("{n}", "3"), "ok") + 14 * K
    y = _ilan(e, y, "Deniz K.", "TAV Primeclass", "IST · 4 Eylül · 14:20–16:40",
              "ok", t("badgeGuestFree"), None, ucus="TK1979", eslesme=94,
              kalan="3 sa 12 dk içinde", mertebe="Elite Plus · Star Alliance Gold",
              ucus3=t("sameFlight"), vurgu=True)
    y = _ilan(e, y, "Mert A.", "Comfort Lounge", "SAW · 5 Eylül · 09:00–11:30",
              "cost", t("badgeGuestPaid", "Misafir ücretli"),
              None, eslesme=71,
              kalan="1 g 4 sa içinde", mertebe="Miles&Smiles Classic", kalkan=False)
    e.alt_bar(1)
    return e


# ══════════════════════════════════════════════════════════════════
# 03 · KURAL MOTORU  ★ farkımız
# ══════════════════════════════════════════════════════════════════
def kural():
    """🔴 30 AĞUSTOS · 2. TUR — ARTIK GERÇEK EKRANIN AYNASI.

    Bu ekran bugüne kadar üreticide VARDI ama uygulamada YOKTU: yani
    pazarlama görselinde ürünün en büyük farkı gösteriliyor, üründe ise
    o farkın kendi ekranı bulunmuyordu. Bu turda `KuralKarari`
    (src/ekranlar_ana.js) + `kural_kosullari()` (sql/275) ile ekran
    gerçekten kuruldu; üretici de ona ayna oldu.

    Satırlar artık tasarımdaki gibi tek sütun ✓/✗ listesi — sağda ikinci
    bir değer sütunu YOK. Eski hâlde "Havayolu şartı … yok" yazıyordu ve
    bu iki farklı okumaya açıktı ("şart yok" mu, "sağlanmıyor" mu?).
    Tek sütunda cümlenin tamamı yazıyor.
    """
    e = Ekran()
    e.doku(y0=e.y * 0.30)
    e.daire_eylem(KENAR, 40 * K, "sol")
    # 🔴 7. tur — ORTALANMIŞ MARKA ÖNİZLEMEDE YOKTU.
    # Tasarım: `<div class="ust-eylem">‹</div><div class="marka">
    # LOUNGELINK</div><div style="width:20px">` — üç parçalı ve
    # ortadaki MARKA. Uygulamada var (src/ekranlar_ana.js KuralKarari),
    # önizlemede yoktu; Gökberk karşılaştırmada boş kutuyu işaretledi.
    mf_ = f(BOLD, 10.5)
    mw_ = e.genislik("LOUNGELINK", mf_, aralik=4.6)
    e.metin(((e.g - mw_) / 2, 50 * K), "LOUNGELINK", mf_, e.P["body"], aralik=4.6)
    e.metin((KENAR, 92 * K), t("ruleEyebrow"), f(BOLD, 10.5), e.P["gold"],
            aralik=2.4)
    for i, parca in enumerate(t("ruleWhyTitle").replace("{n}", "84").split("\n")):
        e.metin((KENAR, 112 * K + i * 38 * K), parca, f(BOLD, 34), e.P["ink"],
                )
    y = 208 * K

    # Uygulamadaki `kural_kosullari` satırlarıyla AYNI metinler.
    # 🔴 SQL 283/284 — `kural_kosullari` artık on iki boyutu soruyor:
    # kişi sayısı, iç/dış hat, host kotası, çocuk, biniş kartı, kalış,
    # doluluk, ücret, kural güncelliği. Metinler sunucu fonksiyonundan
    # birebir; üçüncü durum ("bilinmiyor") gri içi boş daire ile çizilir —
    # uygulamadaki `KuralKarari` ile aynı (✓ yeşil · ✗ amber · ○ gri).
    kosullar = [
        ("Misafir hakkı var · 2 kişilik", "ok"),
        ("Aynı havayolu · TK", "ok"),
        ("Aynı uçuş şartı sağlanıyor", "ok"),
        ("2 kişi · hak yetiyor", "ok"),
        ("Dış hatlar salonu · uçuşun dış hat", "ok"),
        ("Host giriş anında yanında olmalı", "ok"),
        ("Biniş kartın aynı gün · TK712", "ok"),
        ("Kalış sınırı 3.0 saat", "ok"),
        ("Kural 12 gün önce doğrulandı", "ok"),
        ("Kendi biniş kartın ve kimliğin gerekir", "ok"),
    ]
    # Not: "bilinmiyor" satırı burada YOK — uygulama böyle bir satır
    # varken başlıktaki yüzdeyi 60'a çeker (KuralKarari.gosterilenSkor);
    # %84 başlığıyla gri bir daire aynı ekranda çelişirdi.
    kh = 60 * K + len(kosullar) * 28 * K
    x, y, g = e.kart(kh, y=y)
    e._gi = g - 32 * K
    ix = x + 16 * K
    e.metin((ix, y + 18 * K), (t("ruleCardLabel") + " · MILES&SMILES ELITE PLUS"),
            f(BOLD, 9.5), e.P["dim"], aralik=2)
    ky = y + 44 * K
    for metin, durum in kosullar:
        ok = durum == "ok"
        if durum == "bilinmiyor":
            b = int(15 * K)
            e._d().ellipse([int(ix), int(ky - 1 * K), int(ix) + b, int(ky - 1 * K) + b],
                           outline=rgb(e.P["dim"]) + (255,), width=max(1, int(1.6 * K)))
            e.metin((ix + 26 * K, ky), metin, f(REG, 13.5), e.P["mutedAA"])
        else:
            renk = e.R["ok"] if ok else e.R["cost"]
            e.ikon(ix, ky - 1 * K, "tamam" if ok else "kapat", 15, renk)
            e.metin((ix + 26 * K, ky), metin, f(REG, 13.5), e.P["body"])
        ky += 28 * K

    y += kh + 16 * K
    # 🔴 Not KIRPILMIYOR, SARILIYOR. `[:52] + "…"` yazmıştım ve
    # tasarımda iki tam satır olan cümle önizlemede yarım kalıyordu —
    # üstelik kırpılan yer tam da vaadin olduğu yer ("kredin iade
    # edilir"). Bir cümleyi kısaltmak, cümlenin en sonunu atmak
    # değildir.
    ft = f(REG, 12)
    ic = e.g - 2 * KENAR
    kel, satirlar, cur = t("ruleNote").split(" "), [], ""
    for w in kel:
        dd = (cur + " " + w).strip()
        if e.genislik(dd, ft) > ic and cur:
            satirlar.append(cur); cur = w
        else:
            cur = dd
    if cur:
        satirlar.append(cur)
    for i, sat in enumerate(satirlar[:3]):
        e.metin((KENAR, y + i * 20 * K), sat, ft, e.P["dim"], enfazla=ic,
                kaynak="kural notu")
    # 🔴 Eylem yığını DİBE — uygulamadaki `marginTop:"auto"` ile aynı.
    # Önizleme onları içeriğin bittiği yere koyuyordu (%55) ve Gökberk
    # "sayfanın ortasında" diye gösterdi. Ayna, hizalamayı da aynalamalı.
    ay = e.y - 34 * K - 48 * K - 12 * K - 48 * K
    # Tasarım `altin_dugme("Lounge isteği gönder")` → etiketin sağında `›`.
    y2 = e.dugme(ay, t("ruleSendReq"), "gold", yuk=48, sag_ikon="sag")
    e.dugme(y2 + 12 * K, t("ruleReadVenue"), "ghost", yuk=48)
    return e


# ══════════════════════════════════════════════════════════════════
# 04 · EŞLEŞTİNİZ
# ══════════════════════════════════════════════════════════════════
def eslesme():
    e = Ekran()
    # 🔴 8. tur — TAM FOTOĞRAF DEĞİL, `.mesh-yogun`.
    # Tasarım: koyu sahne (#241D26 → gece) + iki radyal hale +
    # fotoğraf %20. Ben fotoğrafı ZEMİN yapmıştım (%100) ve üstündeki
    # her metne gölge koymak zorunda kalmıştım.
    e.mesh_yogun()
    # ══════════════════════════════════════════════════════════════
    # 🔴 31 AĞUSTOS · 8. TUR — ZEMİNİ DÜZELTTİM, ÜSTÜNDEKİ PERDEYİ
    # KALDIRMAYI UNUTTUM. VE PERDE ZEMİNDEN GÜÇLÜYDÜ.
    #
    # Burada şu üç satır duruyordu:
    #     kat = Image.new(...); rectangle(..., fill=(16,12,10,130))
    #     e.im.alpha_composite(kat)
    # Yani TÜM EKRANA %51 siyah bir perde. O perde, zemin bir
    # FOTOĞRAFKEN metni okutmak için konmuştu. Bir tur önce zemini
    # tasarımdaki `.mesh-yogun`a çevirdim — ama perdenin varlık sebebi
    # ortadan kalkarken perdeyi silmedim.
    #
    # Ölçtüm (aynı noktalar, aynı yükseklik oranları):
    #     tasarım (105,86,68) (80,82,86) (75,64,67)
    #     ayna    ( 25,19,20) (31,30,34) (23,20,23)
    # yani sahne 3–4 kat karanlıktı. Gökberk'in "background biraz daha
    # saydamlaştırılarak veriliyor" cümlesinin sayısal karşılığı bu.
    #
    # 🆕 SINIF: "BİR SORUNU ÇÖZERKEN ONUN İÇİN KOYULMUŞ TELAFİLERİ DE
    # KALDIR — KALAN TELAFİ, ÇÖZÜMÜN KENDİSİNİ GİZLER."
    #
    # LOUNGELINK yazısı da kaldırıldı: tasarımın `.an` ekranında marka
    # YOK. Bir tur önce "her ekranda marka olsun" diye ekledim; oysa bu
    # ekran markanın değil, İKİ KİŞİNİN ekranı — ve tasarım bunu
    # bilerek boş bırakmış.
    # ══════════════════════════════════════════════════════════════

    # 🔴 İLK RENDER'DA "+1" SAĞDAKİ AVATARIN ÜSTÜNE BİNİYORDU: avatarları
    # 0.26/0.60'a koyup metni 0.50'ye ortalamıştım — iki merkez arası
    # 0.34 genişlikte, avatar yarıçapı 33px, metin ~46px. Çakışma
    # kaçınılmazdı ve "gözle bakınca ortalı görünüyor" diye geçmişti.
    # Artık avatarlar simetrik (0.24 / 0.76) ve aradaki boşluk ölçülü.
    # ══════════════════════════════════════════════════════════════
    # Tasarımdaki `.an` anatomisi — uygulamadaki `MomentScreen` ile
    # BİREBİR aynı sıra ve aynı ölçüler:
    #   an-ikiz (66 avatar · 26+26 bağ çizgisi) → dugum → an-h1 (Cormorant
    #   300 · 46) → an-alt → an-sayac (hap · MONO)
    # Eskiden buradaki ikinci avatar 0.76'daydı ve aralarında "+1"
    # yazıyordu; tasarımda araya bir BAĞ ÇİZGİSİ giriyor. "+1" bir
    # muhasebe işareti, çizgi ise bir ilişki — ekranın konusu ikincisi.
    # ══════════════════════════════════════════════════════════════
    # ══════════════════════════════════════════════════════════════
    # 🔴 31 AĞUSTOS · 8. TUR — BLOK SAYFADA ORTALI DEĞİLDİ.
    #
    # Gökberk: "belki biraz daha sayfaya göre ortalı olabilir, sadece sen
    # karar ver doğru bir şekilde."
    #
    # KARAR: ORTALI. Üç gerekçe, sırayla:
    #
    #  1) ÜRÜN ZATEN ÖYLE. `src/MomentScreen.js` içerik bloğunu
    #     `justifyContent:"center"` ile ortalıyor. Ayna 0.24 gibi sabit
    #     bir orana yaslanmıştı — yani ayna, ÜRÜNÜN yerleşimini değil
    #     kendi tahminini çiziyordu. (Bu turda üçüncü kez aynı kusur.)
    #
    #  2) TASARIMIN KENDİSİ SABİT ORAN DEMİYOR. `.an{display:flex;
    #     justify-content:space-between; padding:64px 26px 34px}` — yani
    #     yerleşim CİHAZIN boyuna göre çözülüyor. Tasarım dosyası tek bir
    #     yükseklikte (2469px) çizildiği için bloğun "yukarıda" durması
    #     o cihazın sonucu, bir kural değil.
    #
    #  3) UZUN CİHAZDA SABİT ORAN KOPUYOR. 0.24, kısa bir cihazda bloğu
    #     düğmeye yapıştırır, uzun bir cihazda tepede bırakır. Ortalama,
    #     her boyda aynı ilişkiyi korur.
    #
    # Blok yüksekliği ÖLÇÜLEREK bulunuyor (avatar + boşluk + dugum +
    # başlık satırları + gövde satırları + sayaç), sonra üst pay ile
    # düğmenin arasına ortalanıyor.
    # ══════════════════════════════════════════════════════════════
    DUGME_Y = int(e.y * 0.76)
    _sf0 = f(SERIF_SEMI, 46)
    _bas_satir = len(t("momentMatchTitle").replace("{name}", "Deniz").split("\n"))
    _gov = t("momentMatchBody").replace("{name}", "Deniz")
    _gf0 = f(REG, 13.5)
    _gs, _cur = [], ""
    for _kel in _gov.split(" "):
        _dd = (_cur + " " + _kel).strip()
        if e.genislik(_dd, _gf0) > e.g - 4 * KENAR and _cur:
            _gs.append(_cur); _cur = _kel
        else:
            _cur = _dd
    _gs.append(_cur)
    BLOK = (66 * K                      # an-ikiz
            + 34 * K + 10 * K           # dugum margin + satır
            + 18 * K                    # an-h1 margin
            + _bas_satir * int(46 * K * 1.06)
            + 16 * K + len(_gs) * 22 * K   # an-alt
            + 26 * K + 40 * K)          # an-sayac margin + hap
    ky = max(int(e.y * 0.10), (DUGME_Y - BLOK) // 2)
    av, bag = 66 * K, 52 * K
    tg = av * 2 + bag
    sx = (e.g - tg) // 2
    e.avatar(sx, ky, "G", boy=66)
    # 🔴 8. tur — İKİNCİ HARF TASARIMDA TEAL. `.an-av.alt{color:var(--guven)}`
    # İkisi de altın olunca ekranın anlattığı ŞEY kayboluyor: bu ekran
    # iki TARAFI gösteriyor (host altın, misafir teal) ve aradaki çizgi de
    # tam olarak o iki renk arasında geçiyor. Aynı rengi iki kez çizmek,
    # çizginin neden iki renkli olduğunu anlaşılmaz bırakıyordu.
    e.avatar(sx + av + bag, ky, "D", boy=66, harf_renk=e.P["teal"])
    cy = ky + av // 2
    d = e._d()
    d.rectangle([sx + av, cy, sx + av + bag // 2, cy + K],
                fill=rgb(e.P["gold"]) + (180,))
    d.rectangle([sx + av + bag // 2, cy, sx + av + bag, cy + K],
                fill=rgb(e.P["teal"]) + (180,))

    # dugum — altın, büyük harf, harf aralıklı
    df = f(BOLD, 10)
    ds = t("momentMatchEyebrow")
    w = e.genislik(ds, df, aralik=2.4)
    e.metin(((e.g - w) / 2, ky + av + 34 * K), ds, df, e.P["gold"], aralik=2.4)

    # an-h1 — Cormorant **300**, iki satıra kadar, ortalı
    sf = f(SERIF_SEMI, 46)
    y2 = ky + av + 62 * K
    for parca in t("momentMatchTitle").replace("{name}", "Deniz").split("\n"):
        w = e.genislik(parca, sf)
        e.metin(((e.g - w) / 2, y2), parca, sf, e.P["ink"])
        y2 += int(46 * K * 1.06)

    govde = t("momentMatchBody").replace("{name}", "Deniz")
    # `.an-alt{font-size:13.5px; line-height:1.66}` — 12.5/21 çiziyordum.
    # "fontlar dahil" denen yer tam burası: aynı aile, yanlış punto.
    ft = f(REG, 13.5)
    satirlar, cur = [], ""
    for kelime in govde.split(" "):
        dd = (cur + " " + kelime).strip()
        if e.genislik(dd, ft) > e.g - 4 * KENAR and cur:
            satirlar.append(cur)
            cur = kelime
        else:
            cur = dd
    satirlar.append(cur)
    # 🔴 8. tur — GÖVDE BAŞLIĞA YAPIŞIKTI. Tasarım `.an-alt{margin-top:16px}`;
    # ben 6 çiziyordum ve Cormorant 300'ün inen uçları (ç, ğ, y) gövde
    # satırına DEĞİYORDU. Gökberk'in "font tipleri farklı gibi" dediği
    # şeyin bir kısmı buydu: font aynı, ARALARINDAKİ MESAFE farklıydı —
    # ve sıkışık bir satır, farklı bir font gibi okunur.
    y2 += 16 * K
    for i, s2 in enumerate(satirlar):
        w = e.genislik(s2, ft)
        e.metin(((e.g - w) / 2, y2 + i * 22 * K), s2, ft, e.P["mutedAA"])

    # an-sayac — hap içinde MONO geri sayım
    y2 += len(satirlar) * 22 * K + 26 * K
    mf = f(MONO_SEMI, 15)
    lf = f(SEMI, 10)
    sayi, etiket = "02:41:08", t("toDeparture", "kalkışa")
    hw = int(e.genislik(sayi, mf) + e.genislik(buyuk(etiket), lf, aralik=1.4)) + 81 * K
    hy = 40 * K
    e.im.alpha_composite(
        e.yuvarlak((hw, hy), hy // 2, (255, 255, 255, 10),
                   rgb(e.P.get("line2", e.P["line"])) + (150,)),
        (int((e.g - hw) / 2), int(y2)))
    # Tasarım `.an-sayac`ın içinde saat ikonu var (`ik(I['saat'],13)`).
    tx = (e.g - hw) / 2 + 18 * K
    e.ikon(tx, y2 + 13 * K, "saat", 13, e.P["mutedAA"])
    tx += 19 * K
    e.metin((tx, y2 + 11 * K), sayi, mf, "#FFFDF9")
    e.metin((tx + e.genislik(sayi, mf) + 10 * K, y2 + 14 * K),
            buyuk(etiket), lf, e.P["dimAA"], aralik=1.4)

    # Tasarımın `altin_dugme`si etiketin sağına `›` koyuyor.
    e.dugme(DUGME_Y, t("momentMatchCta"), "gold", sag_ikon="sag")
    return e


# ══════════════════════════════════════════════════════════════════
# 05 · TANIŞ
# ══════════════════════════════════════════════════════════════════
def tanis():
    e = Ekran()
    e.doku()
    e.bant(t("meetTitle"), t("meetSub"))
    y = e.imlec
    cx = e.cip(KENAR, y, t("meetFilterFlight"), secili=True)
    cx = e.cip(cx, y, "Salon")
    e.cip(cx, y, "Rota")
    y += 44 * K
    for ad, alt, etiket, ton in (
        ("Selin B.", "TK1979 · IST → AMS", t("sameFlight"), "ok"),
        ("Kaan T.", "Primeclass · 2 saat", t("reqTypeCoffee"), "info"),
        ("Ece Y.", "IST → LHR · 18:05", t("reqTypeRoute"), "info"),
    ):
        x, y0, g = e.kart(112 * K, y=y)
        e.avatar(x + 16 * K, y0 + 20 * K, ad[0], boy=48)
        e.metin((x + 78 * K, y0 + 22 * K), ad, f(BOLD, 15), e.P["ink"])
        e.metin((x + 78 * K, y0 + 44 * K), alt, f(REG, 11.5), e.P["mutedAA"])
        e.cip(x + 78 * K, y0 + 68 * K, etiket, ton=ton)
        ft = f(BOLD, 12)
        w = e.genislik("→", ft)
        e.metin((x + g - 24 * K - w, y0 + 48 * K), "→", ft, e.P["goldText"])
        y = y0 + 112 * K + 12 * K
    # Boş kalan alt boşluğa ürünün gerçek dürtüsü: host'a geçiş.
    x, y, g = e.kart(112 * K, y=y + 6 * K, zemin=e.P["goldBg"])
    e.metin((x + 18 * K, y + 20 * K), t("calmBecomeHost"), f(BOLD, 14.5),
            e.P["goldText"])
    s = t("hostOnlyBody")
    ft = f(REG, 11.5)
    kelime, cur, satirlar = s.split(" "), "", []
    for w0 in kelime:
        d = (cur + " " + w0).strip()
        if e.genislik(d, ft) > g - 36 * K and cur:
            satirlar.append(cur)
            cur = w0
        else:
            cur = d
    satirlar.append(cur)
    for i, sr in enumerate(satirlar[:2]):
        e.metin((x + 18 * K, y + 46 * K + i * 19 * K),
                sr + ("…" if i == 1 and len(satirlar) > 2 else ""), ft,
                e.P["mutedAA"])
    e.alt_bar(3)
    return e


# ══════════════════════════════════════════════════════════════════
# 06 · SOHBET + OTURUMU BAŞLAT
# ══════════════════════════════════════════════════════════════════
def sohbet():
    e = Ekran()
    e.doku(y0=e.y * 0.20)
    # üst başlık şeridi
    e.im.alpha_composite(
        # 🔴 8. tur — ŞERİT BAŞLIĞIN İÇİNDE, ALTINDA DEĞİL.
        # Tasarımda `.sabit-serit` `<header class="ust ince-ust">`in
        # ÇOCUĞU: `margin-top:16px` ile ad bloğundan ayrılıyor ve
        # başlığın kendi yüzeyinde duruyor. Ben yüzeyi 108pt'de bitirip
        # şeridi tam sınırın üstüne koyuyordum — kutu yarı içeride,
        # yarı gövdedeydi. Yüzey şeridi kapsayacak kadar uzatıldı:
        #   108 (ad bloğu) + 16 (margin) + 44 (şerit) + 14 (padding) = 182
        # 🔴 10. TUR — BAŞLIK HÂLÂ YÜKSEKTİ. Yüksekliği elle veriyordum;
        # artık tasarımın kendi yığınından TÜRÜYOR:
        #   20 (.ust padding-top) + 38 (satır) + 16 (.sabit-serit margin)
        # + 44 (şerit) + 14 (padding-bottom) = 132pt
        Image.new("RGBA", (e.g, 132 * K), rgb(e.P["surface"]) + (255,)), (0, 0))
    # ⚠️ AYRAÇ YOK — bilerek. Tasarımın sohbet başlığı
    # `.ust.ince-ust{background:linear-gradient(180deg,#191520,var(--gece))}`
    # yani gövdeye bir ÇİZGİYLE değil bir GEÇİŞLE bağlanıyor. Buraya
    # koyduğum çizgi başlığı bir "kutu" yapıyordu.
    # 🔴 8. tur — GERİ OKU ÖNİZLEMEDE YOKTU.
    # Tasarımın sohbet başlığı üç parçalı:
    #   <div class="ust-eylem">‹</div> · avatar+ad+mekân · 20px boşluk
    # Uygulamada `Hdr`e `onBack` gidiyor ve ok çiziliyor; önizleme
    # doğrudan avatarla başlıyordu. Gökberk işaretledi: "back butonu
    # bile yok mesela."
    # ══════════════════════════════════════════════════════════════
    # 🔴 9. TUR — GERİ OKU İLE AVATAR AYNI SATIRDA DEĞİLDİ.
    # Gökberk: "back butonu ile isim kısmı arasında bi hizasızlığa
    # sebep olmuş." Ölçtüm, haklı:
    #     geri dairesi 38pt, y=40  → merkezi 59
    #     avatar       36pt, y=48  → merkezi 66
    # 7pt kayma. İki farklı boydaki nesneyi iki farklı ÜST kenardan
    # konumlandırmıştım; oysa bir satırda hizalanan şey üst kenar değil
    # MERKEZDİR (`.ust-sira{align-items:center}`).
    #
    # 🆕 SINIF: "AYNI SATIRDAKİ FARKLI BOYDA NESNELERİ ÜST KENARDAN
    # KONUMLANDIRIRSAN, HİZA BOYLARI EŞİT OLDUĞU SÜRECE ÇALIŞIR —
    # YANİ BİR GÜN SESSİZCE BOZULUR."
    #
    # Artık tek bir eksen var: `SATIR_MERKEZ`. Üç öğe de ondan türüyor.
    SATIR_MERKEZ = 20 * K + 19 * K       # `.ust` padding-top + satırın (38pt) yarısı
    _gd = 38 * K
    e.daire_eylem(KENAR, SATIR_MERKEZ - _gd // 2, "sol")
    # `.avatar.sm{width:36px;height:36px;font-size:17px}`
    _ad = 36 * K
    ax_ = KENAR + 46 * K
    _ay = SATIR_MERKEZ - _ad // 2
    e.avatar(ax_, _ay, "D", boy=36)
    # 🔴 8. tur — TASARIMDA SOHBET BAŞLIĞINDAKİ AVATARDA DA KALKAN VAR
    # (`<div class="avatar sm">D'+kalkan_roz()+'</div>`). Keşfet
    # kartında çiziyordum, burada çizmiyordum: yani aynı kişi bir
    # ekranda doğrulanmış, öbüründe doğrulanmamış görünüyordu.
    #
    # 🆕 SINIF: "BİR ROZET, KİŞİYE AİTSE HER EKRANDA GÖRÜNMELİ —
    # BİR EKRANDA EKSİK OLAN ROZET, O EKRANDA YOK DEMEKTİR."
    _kb = 15 * K
    _kx = int(ax_ + _ad - _kb + 3 * K)
    _ky = int(_ay + _ad - _kb + 3 * K)
    e.im.alpha_composite(
        e.yuvarlak((_kb, _kb), _kb / 2, rgb(e.P["teal"]) + (255,),
                   rgb(e.P["bg"]) + (255,), kalinlik=2), (_kx, _ky))
    e.ikon(_kx + 3.5 * K, _ky + 3.5 * K, "guvenlik", 8, e.P["bg"])
    # İki satırlık blok da MERKEZDEN türüyor: 15pt ad + 3 + 11.5 alt
    # ≈ 32pt yüksekliğinde bir blok, satır merkezine oturuyor.
    _bx = ax_ + 46 * K
    e.metin((_bx, SATIR_MERKEZ - 16 * K), "Deniz K.", f(BOLD, 15), e.P["ink"])
    e.metin((_bx, SATIR_MERKEZ + 4 * K), "TAV Primeclass · Kapı A12",
            f(REG, 11.5), e.P["mutedAA"])

    # ── sabit şerit ── uygulamadaki `Chat` başlığının altındaki şerit
    # (bkz. src/ekranlar_yalin.js). Eskiden burada YEŞİL NOKTA + "Sohbet
    # açık" yazıyordu; uygulamada öyle bir şey yok — bu, üreticinin kendi
    # uydurduğu bir öğeydi ve tam da bu yüzden `chatOpen` anahtarı
    # uygulamada ölü kalmıştı: metin yalnız ÖNİZLEMEDE yaşıyordu.
    # 🔴 31 AĞUSTOS · 8. TUR — ŞERİT BİR BANT DEĞİL, BİR KUTU.
    # Tasarım: `.sabit-serit{margin-top:16px;padding:11px 14px;
    # border:1px solid var(--cizgi);border-radius:12px;
    # background:rgba(255,255,255,.035)}` — başlığın içinde, kenarlardan
    # boşluklu, yuvarlak. Kenardan kenara uzanan altı çizgili bir bant
    # çiziyordum; uygulama da öyleydi. İkisi de düzeltildi.
    sy = 74 * K
    syh = 44 * K
    e.im.alpha_composite(
        e.yuvarlak((e.g - 2 * KENAR, syh), 12, (255, 255, 255, 9),
                   rgb(e.P["line"]) + (255,)), (KENAR, sy))
    mf = f(MONO_MED, 12.5)
    # 🔴 8. tur — TASARIM BURADA SANİYELİ BİR SAAT GÖSTERİYOR.
    # `.sabit-serit b` → `02:41:08`. Ben `2 sa 41 dk içinde` çiziyordum
    # (kartların kaba ölçeği). `geriSayim`e `saatli` kipi eklendi ve
    # sohbet başlığı onu kullanıyor; ayna da aynı biçimi çiziyor.
    kalan = "02:41:08"
    # 🔴 7. tur — ŞERİDİN İKİNCİ YARISI ÖNİZLEMEDE YOKTU.
    # Tasarım: `02:41:08 kalkışa │ 🚪 Kapı A12 önü` — iki bilgi, arada
    # ayraç. Uygulamada ikisi de var (src/ekranlar_yalin.js: Sayac +
    # ayraç + salon ikonu + yer). Önizleme yalnız ilkini çiziyordu ve
    # Gökberk karşılaştırmada tam bu boşluğu işaretledi.
    ix0 = KENAR + 14 * K            # `.sabit-serit` iç boşluğu
    e.ikon(ix0, sy + 15 * K, "saat", 13, e.P["mutedAA"])
    e.metin((ix0 + 19 * K, sy + 15 * K), kalan, mf, e.P["body"])
    lx = ix0 + 19 * K + int(e.genislik(kalan, mf)) + 8 * K
    # 🔴 ETİKET VERSALDİ. Tasarım `<span>kalkışa</span>` — küçük harf,
    # `--sessiz`, harf aralığı yok. Versal + 1.2 aralık, 9px'lik bir
    # yardımcı metni sayaçla eşit ağırlığa çıkarıyordu.
    et = t("toDeparture")
    ef = f(REG, 11.5)
    e.metin((lx, sy + 16 * K), et, ef, e.P["mutedAA"])
    ax = lx + int(e.genislik(et, ef)) + 12 * K
    e._d().rectangle([ax, sy + 15 * K, ax + K, sy + 29 * K],
                     fill=rgb(e.P.get("line2", "#444")) + (255,))
    # Tasarımda bina değil KAPI glifi (`I['kapi']`) — `src/ikon.js`teki
    # `kapi` adı, orada ölçümüyle birlikte yazılı.
    e.ikon(ax + 12 * K, sy + 15 * K, "kapi", 13, e.P["mutedAA"])
    e.metin((ax + 31 * K, sy + 15 * K), "Kapı A12 önü", f(REG, 11.5), e.P["mut"],
            enfazla=e.g - (ax + 31 * K) - KENAR - 14 * K, kaynak="sohbet şeridi yeri")

    y = 150 * K
    y = balon(e, y, "Merhaba! Primeclass girişinde buluşalım mı?", False, "14:02")
    y = balon(e, y, "Olur, güvenlikten yeni geçtim — 5 dakikaya oradayım.",
              True, "14:04")
    y = balon(e, y, t("lsHost2"), False, "14:09")

    # ══════════════════════════════════════════════════════════════
    # 🔴 30 AĞUSTOS · 4. TUR — HIZLI DURUM ÇİPLERİ YAZMA KUTUSUNUN
    # HEMEN ÜSTÜNE.
    #
    # Gökberk: "tasarımda hızlı durum alanı mesaj yazın üstünde iken
    # burada chat'in ortasında bir yerde çıkmış."
    #
    # Haklı ve sebebi şuydu: çipleri BALONLARIN bittiği yere çiziyordum,
    # yani konuşma kısaysa ekranın ortasında kalıyorlardı. Tasarımda
    # `.cipler` ile `.yazma` KARDEŞ ve ikisi de `flex:0 0 auto` — yani
    # ikisi de ALTA yapışık. Uygulamada zaten öyle (composer'ın hemen
    # üstünde); ayna yanlıştı.
    #
    # 🆕 SINIF: **"BİR ÖĞE 'ŞUNUN ÜSTÜNDE' DİYE TARİF EDİLİYORSA,
    # ONU ÖNCEKİ ÖĞENİN ALTINA ÇİZMEK AYNI ŞEY DEĞİLDİR — BİRİ
    # BAĞLIDIR, ÖTEKİ TESADÜFTÜR."**
    # ══════════════════════════════════════════════════════════════
    alt = e.y - 178 * K            # yazma + oturum çubuğu bloğu
    cy = alt - 52 * K              # çipler bloğu bunun HEMEN üstünde
    # 🔴 31 AĞUSTOS · 8. TUR — AYNA BURADA İKİ ŞEY UYDURDU.
    #
    #   1) "HIZLI DURUM" BAŞLIĞI. Uygulamada YOK, tasarımda YOK.
    #      Yalnız önizlemede vardı — yani Gökberk'e üründe olmayan
    #      bir başlık gösteriyordum.
    #   2) ÇİPLER ALTINDI. Tasarım `.cip{border:1px solid var(--cizgi2);
    #      color:var(--sessiz); background:rgba(255,255,255,.03)}` —
    #      NÖTR. Uygulama da öyle çiziyor (`Btn v="ghost" cip`).
    #      Ayna ikisinden de ayrılıp altın çiziyordu ve sohbet ekranında
    #      ikinci bir altın kütle üretiyordu.
    #
    # 🆕 SINIF: "BİR AYNA, ÜRÜNDE OLMAYAN BİR ŞEY ÇİZDİĞİNDE HATA
    # GİZLEMİYOR — ÜRÜNE OLMAYAN BİR KUSUR EKLİYOR. İKİSİ DE YANLIŞ
    # KARARA GÖTÜRÜR; İKİNCİSİ DAHA HIZLI."
    cx = e.cip(KENAR, cy, t("lsGuest3"), ton="notr")
    e.cip(cx, cy, temiz(f(SEMI, 10.5), t("lsGuest5"), "lsGuest5"), ton="notr")

    # 🔴 İLK RENDER'DA MESAJ KUTUSU YOKTU. Sohbet ekranının görselinde
    # yazma alanı olmaması, ekranı "okunur" gösterir — ürün yanlış
    # anlatılır. Eksik olan bir bileşen değil, ekranın ANLAMIYDI.
    e.im.alpha_composite(
        Image.new("RGBA", (e.g, e.y - alt), rgb(e.P["surface"]) + (252,)), (0, alt))
    ayirac(e, 0, alt, e.g, 160)
    # 🔴 9. tur — `.gonder` `.yazma`nın İÇİNDE (bkz. src/ekranlar_yalin.js).
    # Kutu: yuvarlak DİKDÖRTGEN (r=14), kenarı `--cizgi2` (altın DEĞİL),
    # zemini `--yuzey`. Düğme: 36pt altın daire, KOYU ok, kutunun içinde.
    kg = e.g - 2 * KENAR
    ky0 = alt + 18 * K
    kyh = 62 * K
    e.im.alpha_composite(
        e.yuvarlak((kg, kyh), 14, rgb(e.P["surface"]) + (255,),
                   rgb(e.P["line2"]) + (255,)), (KENAR, ky0))
    e.metin((KENAR + 14 * K, ky0 + 21 * K), t("typeMsg"), f(REG, 13),
            e.P["dimAA"])
    _gc = 36 * K
    gx = e.g - KENAR - 13 * K - _gc
    gy = ky0 + (kyh - _gc) // 2
    e._d().ellipse([gx, gy, gx + _gc, gy + _gc],
                   fill=rgb(e.P["goldBtn"]) + (255,))
    # Ok KOYU — `.gonder{color:#171009}`. Beyaz ok altın zeminde 1.5:1.
    e.ikon(gx + 10 * K, gy + 10 * K, "sag", 16, e.P.get("onGold", "#171009"))
    e.dugme(alt + 96 * K, t("startSessionBtn"), "gold", yuk=52)
    return e


# ══════════════════════════════════════════════════════════════════
# 07 · CANLI OTURUM
# ══════════════════════════════════════════════════════════════════
def oturum():
    e = Ekran()
    e.doku(y0=e.y * 0.34)
    e.baslik("LOUNGELINK", t("liveSessionTitle"), None)
    y = e.imlec
    y = bandrol(e, y, temiz(f(SEMI, 12), t("liveTitle"), "sessActive"),
                "ok", nokta=True) + 16 * K

    x, y, g = e.kart(268 * K, y=y)
    e._gi = g - 32 * K
    ix = x + 16 * K
    e.avatar(ix, y + 18 * K, "D", boy=48)
    e.metin((ix + 62 * K, y + 22 * K), t("sessWith"), f(REG, 11.5), e.P["mutedAA"])
    e.metin((ix + 62 * K, y + 40 * K), "Deniz K.", f(BOLD, 16), e.P["ink"])
    ayirac(e, ix, y + 84 * K, g - 32 * K)
    satir(e, ix, y + 104 * K, t("sessLounge").title(), "TAV Primeclass · IST")
    satir(e, ix, y + 134 * K, t("flightLabel").title(), "TK1979 · 16:40")
    satir(e, ix, y + 164 * K, t("sessDurationLabel").title(), "38 dk")
    satir(e, ix, y + 194 * K, t("sessCredit"), "1")
    ayirac(e, ix, y + 228 * K, g - 32 * K)

    y += 268 * K + 18 * K
    y = e.dugme(y, t("completeSessionBtn"), "gold", yuk=56) + 12 * K
    e.hayalet(y, t("sessReportShort"))
    return e


# ══════════════════════════════════════════════════════════════════
# 08 · OTURUM TAMAMLANDI · PUANLA
# ══════════════════════════════════════════════════════════════════
def puanla():
    e = Ekran()
    e.doku(y0=e.y * 0.22)
    # "🎉 Oturum tamamlandı" — 🎉 Cormorant'ta yok (cihazda var).
    # Emoji atılıyor; kutlama duygusu yıldızlarla zaten taşınıyor.
    # 🔴 Bu bir "an" ekranı (oturum kapandı) — tasarımın `.an-h1`
    # kesiti Cormorant **300**. Bold serif başlık gibi duruyordu.
    s = temiz(f(SERIF_LIGHT, 40), t("sessDone"), "sessDone")
    ft = e.sigdir(s, SERIF_LIGHT, 40, e.g - 2 * KENAR)
    w = e.genislik(s, ft)
    e.metin(((e.g - w) / 2, 96 * K), s, ft, e.P["ink"])
    ft2 = f(REG, 13)
    s2 = t("rateWithWho").replace("{name}", "Deniz K.")
    w = e.genislik(s2, ft2)
    e.metin(((e.g - w) / 2, 152 * K), s2, ft2, e.P["mutedAA"])

    x, y, g = e.kart(300 * K, y=196 * K)
    e._gi = g - 32 * K
    ix = x + 16 * K
    yy = y + 30 * K
    sonx = yildiz(e, ix + (g - 32 * K - (5 * 34 * K)) / 2, yy, 5, 5, boy=30)
    e.metin((ix, yy + 62 * K), t("rateTitle"), f(BOLD, 9.5), e.P["goldText"])
    ayirac(e, ix, yy + 92 * K, g - 32 * K)
    satir(e, ix, yy + 112 * K, t("loungePointsLabel"), "+120")
    satir(e, ix, yy + 142 * K, t("trustSessions"), "9")
    satir(e, ix, yy + 172 * K, t("ratingRoleGuest"), "✓")
    ft3 = f(REG, 11.5)
    e.metin((ix, yy + 210 * K), t("ratePrompt")[:44] + "…", ft3, e.P["dimAA"])

    y2 = 196 * K + 300 * K + 20 * K
    y2 = e.dugme(y2, t("rateNowBtn"), "gold", yuk=56) + 12 * K
    e.hayalet(y2, t("rateLater"))
    return e


# ══════════════════════════════════════════════════════════════════
# 09 · PROFİL
# ══════════════════════════════════════════════════════════════════
def profil():
    """🔴 30 AĞUSTOS · 7. TUR — BU ÖNİZLEME ÜRÜNÜ EKSİK GÖSTERİYORDU.

    Gökberk sordu: "profil tabında yayın&davet, oturum geçmişi,
    değerlendirmeler, bildirimler, güven puanım, güvenlik merkezi,
    lounge puan, arkadaşını davet et, kampanyalar, plan, ayarlar,
    çıkış yap gibi sayfalara yönlendiren buton alanları da olurdu.
    Bunları kaldırmadın di mi?"

    KALDIRMADIM — hepsi `src/screens.js`te, üç gruba ayrılmış 11 satır
    ve altında kırmızı "Çıkış yap" duruyor. Profil FOTOĞRAFI da öyle
    (`pickAndUploadPhoto`). Eksik olan ÖNİZLEMEYDİ: bu fonksiyon
    yalnız istatistik üçlüsü + iki kart çiziyordu.

    Ve bu, aynanın gizlediği bir hatadan daha kötü bir şey yaptı:
    OLMAYAN BİR KAYBI VAR GÖSTERDİ. Ürünün sahibi, duran özelliklerin
    silindiğini sandı ve bunu sormak zorunda kaldı.

    🆕 SINIF: "EKSİK BİR AYNA YALNIZ KUSUR GİZLEMEZ — ÜRÜNÜN SAHİBİNE
    DURAN BİR ÖZELLİĞİ KAYBETTİRİR, VE O GÜVENİ GERİ KAZANMAK
    KUSURU DÜZELTMEKTEN PAHALIDIR."
    """
    e = Ekran()
    e.doku()
    e.bant(t("ppProfile"), "SELİN B. · İSTANBUL", marka="LOUNGELINK",
           sag_ikon="ayarlar")
    y = e.imlec

    # ── kimlik satırı: FOTOĞRAF + isim + meslek + rozet ──
    # Uygulamada 76px daire; fotoğraf varsa resim, yoksa serif baş harf
    # ve altında "Fotoğraf ekle" bağlantısı.
    av = 76 * K
    e.avatar(KENAR, y, "S", boy=76)
    e.metin((KENAR + av + 14 * K, y + 6 * K), "Selin B.", f(BOLD, 20), e.P["ink"])
    e.metin((KENAR + av + 14 * K, y + 34 * K), "Ürün Yönetimi", f(REG, 12.5),
            e.P["mutedAA"])
    e.cip(KENAR + av + 14 * K, y + 54 * K, "• Doğrulanmış · 64", ton="ok")
    e.metin((KENAR, y + av + 6 * K), t("photoChange", "Fotoğrafı değiştir"),
            f(SEMI, 10.5), e.P["goldText"])
    y += av + 30 * K

    # ── istatistik üçlüsü (tasarımın `.sy-sira`sı) ──
    g3 = (e.g - 2 * KENAR - 2 * 9 * K) / 3
    # ⚠️ eskiden bu değişken `buyuk` adındaydı ve `buyuk()`
    # yardımcısını GÖLGELİYORDU — Türkçe büyük harfe geçerken
    # "str is not callable" ile patladı. Ad çakışması bir
    # yardımcıyı sessizce devre dışı bırakabilirdi.
    for i, (sayi_, kucuk) in enumerate((("9", t("statSessions")),
                                        ("4.9", t("ratingShort", "Yıldız")),
                                        ("1.240", t("loungePointsLabel")))):
        gx = KENAR + i * (g3 + 9 * K)
        e.im.alpha_composite(
            e.yuvarlak((int(g3), 76 * K), 12, rgb(e.P["surface"]) + (255,),
                       rgb(e.P.get("line", "#333")) + (255,)), (int(gx), y))
        ft = f(MONO_MED, 20)
        w = e.genislik(sayi_, ft)
        e.metin((gx + (g3 - w) / 2, y + 14 * K), sayi_, ft, e.P["gold"])
        sf = f(SEMI, 9)
        et = buyuk(kucuk)
        w = e.genislik(et, sf, aralik=1.1)
        e.metin((gx + (g3 - w) / 2, y + 46 * K), et, sf, e.P["dim"], aralik=1.1,
                enfazla=g3 - 6 * K, kaynak="profil istatistik etiketi")
    y += 76 * K + 18 * K

    # ── MENÜ — ürünün gerçek sırası (src/screens.js) ──
    # ⚠️ İlk grubun BAŞLIĞI YOK — üründe de öyle: liste doğrudan
    # başlıyor. İlk yazımda oraya `bcTitle` koydum ve aynı cümle üst
    # üste iki kez çizildi ("YAYIN & DAVET" başlığı + "Yayın & Davet"
    # satırı). Bir grubun adı, içindeki tek maddenin adıysa o grup
    # yoktur.
    MENU = (
        ("yayin", t("bcTitle"), "teal"),
        ("gecmis", t("histTitle"), None),
        ("degerlendirme", t("ratingsTitle"), "gold"),
        ("bildirim", t("notifTitle"), None),
        (None, t("menuGroupTrust")),
        ("guvenPuan", t("trustTitle"), None),
        ("guvenlik", t("safetyTitle"), None),
        (None, t("menuGroupRewards")),
        ("puan", t("shopTitle"), "gold"),
        ("davet", t("refTitle"), None),
        ("kampanya", t("campaignsTitle"), "gold"),
        (None, t("menuGroupAccount")),
        ("planKart", t("plansTitle"), None),
        ("ayarlar", t("settings", "Ayarlar"), None),
    )
    # Alt sekme çubuğunun üstünde DUR: liste kayıyor, önizleme
    # kaymıyor. Çubuğun altına metin çizmek, üründe olmayan bir
    # kırıklık gösterir.
    SINIR = e.y - 96 * K
    for oge in MENU:
        if y > SINIR:
            break
        if oge[0] is None:
            y += 10 * K
            e.metin((KENAR, y), oge[1].upper(), f(BOLD, 9.5), e.P["goldText"],
                    aralik=1.2)
            y += 20 * K
            continue
        ad, etiket, ton = oge
        x, y0, g = e.kart(46 * K, y=y, r=12)
        e.ikon(x + 14 * K, y0 + 14 * K, ad, 18,
               e.P.get(ton, e.P["mutedAA"]) if ton else e.P["mutedAA"])
        e.metin((x + 44 * K, y0 + 14 * K), etiket, f(SEMI, 14), e.P["ink"],
                enfazla=g - 74 * K, kaynak="profil menü satırı")
        e.ikon(x + g - 26 * K, y0 + 14 * K, "sag", 16, e.P["dim"])
        y = y0 + 46 * K + 8 * K

    # ── çıkış: menünün EN ALTINDA, kırmızı, tek yerde ──
    # Sığmıyorsa ÇİZİLMEZ: liste kayıyor ve çubuğun altına bir satır
    # çizmek üründe olmayan bir kırıklık gösterir.
    y += 6 * K
    if y > SINIR:
        e.alt_bar(4)
        return e
    x, y0, g = e.kart(46 * K, y=y, r=12, kenar=e.P.get("red", "#B0243C"))
    e.ikon(x + 14 * K, y0 + 14 * K, "cikis", 18, e.P.get("redInk", "#F0736A"))
    e.metin((x + 44 * K, y0 + 14 * K), t("logout", "Çıkış yap"), f(SEMI, 14),
            e.P.get("redInk", "#F0736A"))

    e.alt_bar(4)
    return e

def bildirim():
    """🔴 BU EKRAN ÖNİZLEMEDE HİÇ YOKTU.

    Yerinde `kesfet("C")` vardı: Keşfet'in AÇIK TEMADAKİ hâli. Yani
    17 karelik önizlemenin bir karesi, ürünün artık desteklemediği bir
    temayı gösteriyordu — ve Gökberk onu gördü ("keşfet yine beyaz
    temada").

    Bildirimler ise ürünün en çok açılan üçüncü ekranı ve gece
    sistemine bu turda geçti: sekmeler `.roz` hapı, satır `.kart`,
    kimlik bir VEKTÖR ikon (renkli benek değil), saat MONO.
    """
    e = Ekran()
    e.doku()
    # 🔴 ÜST BİLGİ YANLIŞ BÖLÜMÜ SÖYLÜYORDU: "TANIŞ".
    # Bildirimler kendi başına bir ekran; `sceneMeet` başka bir sekmenin
    # adı. Ayna, ekranın hangi bölümde olduğunu YANLIŞ anlatıyordu.
    e.bant(t("notifTitle"), t("notifTitle"))
    y = e.imlec

    # kategori hapları — seçili olan altın tint
    cx = KENAR
    for i, lb in enumerate((t("catAll"), t("catConnections"), t("catRequests"),
                            t("catSessions"))):
        cx = e.cip(cx, y, lb, secili=(i == 0))
    y += 44 * K

    satirlar = (
        ("sohbet", "gold",  t("notifReqAcceptTitle", "İstek kabul edildi"),
         "Deniz K. seni Primeclass'a alıyor.", "2 dk"),
        # 🔴 `connIncomingTitle` = "SANA GELENLER" — o bir BÖLÜM BAŞLIĞI
        # (Bağlantılar ekranında), bir bildirim başlığı değil. Ayna onu
        # başlık sanınca listede tek bir satır VERSAL çıkıyor ve diğer
        # dördünden kopuyordu. Bildirim başlıkları cümle düzenindedir.
        ("kisiler", "purple", "Yeni bağlantı isteği",
         "Ayşegül D. seninle tanışmak istiyor.", "18 dk"),
        ("salon", "teal", t("sessInProgress", "Oturum başladı"),
         "TAV Primeclass · Kapı A12 önü.", "1 sa"),
        ("degerlendirme", "green", t("rateReminderTitle", "Oturumu değerlendir"),
         "Deniz K. ile geçen oturum tamamlandı.", "3 sa"),
        ("cuzdan", "gold", t("creditsTitle", "Kredin yenilendi"),
         "Bu ay 2 kredi eklendi.", "1 g"),
    )
    for i, (ikon_ad, ton, baslik, govde, saat) in enumerate(satirlar):
        okunmadi = i < 2
        x, y0, g = e.kart(96 * K, y=y, vurgu=okunmadi)
        # `.avatar.sm` ölçüsü: 36px halka + vektör ikon
        e.im.alpha_composite(
            e.yuvarlak((36 * K, 36 * K), 18, rgb(e.P["bgAlt"]) + (255,),
                       rgb(e.P.get("line2", e.P["line"])) + (255,)),
            (int(x + 14 * K), int(y0 + 14 * K)))
        e.ikon(x + 14 * K + 9 * K, y0 + 14 * K + 9 * K, ikon_ad, 17,
               e.P.get(ton, e.P["gold"]))
        ix = x + 14 * K + 36 * K + 12 * K
        sf = f(MONO_MED, 9)
        sw = e.genislik(saat, sf)
        e.metin((x + g - 14 * K - sw, y0 + 18 * K), saat, sf, e.P["dim"])
        bf = e.sigdir(baslik, SEMI, 14, (x + g - 14 * K - sw - 8 * K) - ix)
        e.metin((ix, y0 + 16 * K), baslik, bf, e.P["ink"])
        gf = e.sigdir(govde, REG, 12.5, x + g - 14 * K - ix)
        e.metin((ix, y0 + 40 * K), govde, gf, e.P["mutedAA"])
        y = y0 + 96 * K + 10 * K

    e.alt_bar(0)
    return e


# ══════════════════════════════════════════════════════════════════
# 11 · ANA SAYFA (misafir)  ·  12 · ANA SAYFA (host paneli)
# 13 · BAĞLANTILAR          ·  14 · SEYAHATLERİM
#
# 🔴 BU DÖRDÜ SONRADAN EKLENDİ VE SEBEBİ PAZARLAMA DEĞİL: sitenin
# `public/screens/` rafı 9 görsel istiyor ve bunlardan dördünün
# (ss-home, ss-home2, ss-baglanti, ss-seyahat) karşılığı yoktu.
# 10 ekran üretip "bitti" demek, sitenin kırmızısını açık bırakırdı.
# ══════════════════════════════════════════════════════════════════
def ana_misafir():
    """🔴 30 AĞUSTOS · 2. TUR — ANA SAYFA UYGULAMADAKİ HÂLE.

    Uygulamanın ana sayfası bu turda tasarımdaki `.ust.mesh` + cüzdan
    kutusu + `.sy-sira` yapısına geçti (App.js). Üretici hâlâ eski
    "kahraman + istek kartı" düzenini çiziyordu — yani ürünün en çok
    açılan ekranının önizlemesi, artık var olmayan bir ekrandı.

    Sıra birebir uygulamadaki gibi:
      dugum(İYİ GÜNLER) → isim (Cormorant **300**) → cüzdan kutusu
      → sy-sira (4 kutu, MONO) → BUGÜN kartı
    """
    e = Ekran()
    e.doku()
    # ── başlık: mesh + selam + serif-ince isim ──
    # Cüzdan kutusu bandın İÇİNDE: yüksekliğini banda bildiriyoruz.
    #   .dugum 10 + .ust-h1(52×1.04≈54) + .cuzdan margin 22 + kutu 62
    CUZDAN_Y = 62 * K
    # Tasarımın ana sayfasında da sağ üstte `.ust-eylem` var
    # (`ik(I['profil'],19)`) — uygulamada da profil düğmesi orada.
    # Aynada yoktu: iki ekrandan birinde daire var, öbüründe yok.
    YB = e.bant(None, None, marka="LOUNGELINK", sag_ikon="profil",
                ek_yuk=(10 + 8 + 54 + 22) * K + CUZDAN_Y)
    # Gölge yok — tasarımda `text-shadow` hiç geçmiyor (bkz. mockup.bant).
    e.metin((KENAR, 92 * K), buyuk(t("greetDay", "İyi günler")), f(BOLD, 10.5),
            e.P["gold"], aralik=2.4)
    # 🔴 İSİM 46 ÇİZİLİYORDU, TASARIM 52 DİYOR.
    # `.ust-h1.serif{font-size:52px; font-weight:300}` — uygulama da 52
    # (`T.isim`). Ayna 46'da kalmıştı: aynı font, farklı punto, ve
    # Gökberk "fontlar dahil" diye işaretledi.
    # 🔴 10. TUR — GÖSTERİM SERİFİ 300 → 600.
    # Gökberk: "tasarımdaki daha farklı bir font stili ve daha bold bir
    # havası var." Ölçtüm ve sebebi TASARIM REFERANSININ KENDİSİYDİ:
    # `yap.py` fontları Google'dan çekiyor, bu makinede o istek
    # başarısız oluyor ve tarayıcı YEDEK serife düşüyor. Yani onayladığı
    # görüntüdeki harfler Cormorant değil, yedek bir geçiş serifi —
    # daha büyük x-yüksekliği, daha kalın gövde.
    # Ölçüm: aynı kelimenin mürekkep yoğunluğu tasarımda 0.288,
    # Cormorant 300 ile 0.165.
    # Ailede kalarak en yakın karşılık Cormorant 600. (Aile değişimi
    # marka kararı — Gökberk'in onayı olmadan yapılmıyor.)
    e.metin((KENAR, 106 * K), "Gökberk", f(SERIF_SEMI, 52), "#FFFDF9")

    # ── cüzdan kutusu ──
    cy = 182 * K
    cg = e.g - 2 * KENAR
    e.im.alpha_composite(
        e.yuvarlak((cg, 62 * K), 14, (255, 255, 255, 9),
                   rgb(e.P.get("line", "#333")) + (255,)), (KENAR, cy))
    # ══════════════════════════════════════════════════════════════
    # 🔴 30 AĞUSTOS · 5. TUR — HÜCRELER EŞİT DEĞİL, İÇERİK KADAR.
    #
    # Buraya "üç sütun EŞİT PAYLAŞIR ve içerik ORTALANIR" yazmıştım ve
    # uygulamayı da öyle yapmıştım. Tasarım bunu demiyor:
    #
    #   .cuzdan     { display:flex; align-items:center; gap:16px;
    #                 padding:14px 16px }
    #   .cuzdan>div { display:flex; flex-direction:column; gap:3px }
    #
    # `>div`de flex YOK — her hücre içeriği kadar geniş, satır SOLA
    # YASLI. Eşit üçe bölünce en uzun etiket ("LOUNGEPUAN") 1/3'e
    # sığmak zorunda kaldı; cihazda ayracı 14.4pt aştı.
    #
    # 🆕 SINIF: "AYNANIN KENDİ YORUMU OLAMAZ — 'DAVRANIŞI AYNALAMAK'
    # DİYE YAZDIĞIM ŞEY, TASARIMIN DEĞİL BENİM DAVRANIŞIMDI."
    # ══════════════════════════════════════════════════════════════
    nf = f(MONO_SEMI, 19)
    lf = f(SEMI, 9.5)
    hucreler = []
    for deger, etiket in (("14", t("walletCredits", "kredi")),
                          ("200", t("marketTitle")),
                          ("44", t("trust", "Güven"))):
        et = buyuk(etiket)
        gen = max(e.genislik(deger, nf), e.genislik(et, lf, aralik=1.3))
        hucreler.append((deger, et, gen))
    cx = KENAR + 16 * K
    for i, (deger, et, gen) in enumerate(hucreler):
        if i:
            # 🔴 31 AĞUSTOS · 10. TUR — AYRAÇLAR KAYBOLMUŞTU.
            # Gökberk işaretledi: "aralardaki | ayrımları kaybolmuş."
            # Sebep: `line2` (rgba(232,214,182,.17)) paletten okunurken
            # SAYFA ZEMİNİNE düzleştiriliyor ve sonuç koyu bir gri
            # oluyor. Ama bu çizgi sayfa zemininde değil, PARLAK MESH
            # FOTOĞRAFININ üstünde duruyor — koyu gri orada görünmez.
            # Tasarım `--cizgi2`yi olduğu gibi, YARI SAYDAM bindiriyor.
            #
            # 🆕 SINIF: "BİR RENGİ SABİT BİR ZEMİNE DÜZLEŞTİRİRSEN,
            # O RENK BAŞKA BİR ZEMİNDE KULLANILDIĞI ANDA YANLIŞ OLUR —
            # SAYDAMLIK BİR RENK DEĞİL, BİR İLİŞKİDİR."
            e.im.alpha_composite(
                Image.new("RGBA", (K, 26 * K), (232, 214, 182, 44)),
                (int(cx), int(cy + 18 * K)))
            cx += K + 16 * K
        e.metin((cx, cy + 12 * K), deger, nf, e.P["gold"])
        e.metin((cx, cy + 40 * K), et, lf, e.P["dim"], aralik=1.3,
                enfazla=gen + 2 * K, kaynak="cüzdan etiketi")
        cx += gen + 16 * K

    # 🔴 GÖVDE, BANDIN BİTTİĞİ YERDEN BAŞLAR — SABİT BİR SAYIDAN DEĞİL.
    # `y` cüzdanın altından hesaplanıyordu; bant içerikle büyüyünce
    # `.sy-sira` kutuları mesh'in İÇİNDE kalıyordu. Bandın kendi
    # imlecini kullanmak, iki tarafı tek bir sayıya bağlar.
    y = max(cy + 62 * K + 20 * K, e.imlec)

    # ── sy-sira: dört kutu, MONO sayı, dolu olan ALTIN ──
    sg = (e.g - 2 * KENAR - 3 * 9 * K) / 4
    for i, (n, lb) in enumerate((("0", t("flowChats")), ("1", t("flowRequests")),
                                 ("0", t("flowInvites")), ("2", t("flowQuestions")))):
        bx = KENAR + i * (sg + 9 * K)
        dolu = n != "0"
        e.im.alpha_composite(
            e.yuvarlak((int(sg), 62 * K), 12, rgb(e.P["surface"]) + (255,),
                       rgb(e.P["gold"] if dolu else e.P.get("line", "#333")) + (90 if dolu else 255,)),
            (int(bx), int(y)))
        nf = f(MONO_MED, 20)
        w = e.genislik(n, nf)
        e.metin((bx + (sg - w) / 2, y + 13 * K), n, nf,
                e.P["gold"] if dolu else e.P["dim"])
        lf = e.sigdir(buyuk(lb), SEMI, 9, sg - 12 * K, alt=6)
        w = e.genislik(buyuk(lb), lf, aralik=1.1)
        e.metin((bx + (sg - w) / 2, y + 42 * K), buyuk(lb), lf,
                e.P["mutedAA"] if dolu else e.P["dim"], aralik=1.1,
                enfazla=sg - 8 * K, kaynak="sy-sira etiketi")
    y += 62 * K + 16 * K

    # ── BUGÜN kartı ──
    x, y2, g = e.kart(178 * K, y=y)
    ix = x + 16 * K
    e._gi = g - 32 * K
    e.metin((ix, y2 + 16 * K), buyuk(t("today", "BUGÜN")), f(BOLD, 9.5),
            e.P["dim"], aralik=2)
    e.metin((ix, y2 + 36 * K), "Esenboğa · 14 gün", f(BOLD, 19), e.P["ink"])
    ft = e.sigdir(t("heroWithTripSub"), REG, 13, g - 32 * K)
    e.metin((ix, y2 + 66 * K), t("heroWithTripSub"), ft, e.P["mutedAA"])
    e.dugme(y2 + 112 * K, t("fhAsGuest"), "gold", x=ix, g=g - 32 * K, yuk=48,
            ft=f(BOLD, 14))
    e.alt_bar(0)
    return e


def ana_host():
    e = Ekran()
    e.doku()
    # 🔴 BAŞLIĞI "Host Paneli" DİYE ELLE YAZMIŞTIM — ürün o cümleyi
    # hiçbir yerde söylemiyor. `ekran_check.py` tam bunun için var.
    e.bant(t("navHome"), "SELİN B. · GÜVENİLİR HOST")
    y = e.imlec
    x, y, g = e.kart(132 * K, y=y, zemin=e.P["goldBg"])
    ix = x + 16 * K
    e.metin((ix, y + 18 * K), t("hostMonthTitle"), f(BOLD, 9.5), e.P["goldText"])
    s = t("hostMonthBody").replace("{ses}", "3").replace("{pts}", "360")
    ft = e.sigdir(s, SEMI, 14, g - 32 * K)
    e.metin((ix, y + 42 * K), s, ft, e.P["ink"])
    e.metin((ix, y + 76 * K), t("hostToNextTier").replace("{n}", "3"),
            f(REG, 11.5), e.P["mutedAA"])
    e.metin((ix, y + 100 * K), t("hwWalletUnknown") + " · 2 " + t("hwHostings"),
            f(SEMI, 11.5), e.P["goldText"])
    y += 132 * K + 14 * K

    cx = e.cip(KENAR, y, t("subTabListings"), secili=True)
    e.cip(cx, y, t("subTabTrips"))
    y += 42 * K
    for salon, saat, ton, rz in (
            ("TAV Primeclass · IST", "14:20 – 16:40", "ok", t("badgeGuestFree")),
            ("Comfort Lounge · SAW", "09:00 – 11:30", "cost",
             t("badgeGuestPaid", "Misafir ücretli"))):
        x, y0, g = e.kart(130 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 18 * K), salon, f(BOLD, 14), e.P["ink"])
        e.metin((ix, y0 + 42 * K), saat, f(REG, 12), e.P["mutedAA"])
        e.cip(ix, y0 + 68 * K, rz, ton=ton)
        ft = f(SEMI, 11.5)
        s = t("discTitle")
        w = e.genislik(s, ft)
        e.metin((x + g - 16 * K - w, y0 + 72 * K), s, ft, e.P["goldText"])
        y = y0 + 130 * K + 12 * K
    e.alt_bar(0)
    return e


def baglantilar():
    e = Ekran()
    e.doku()
    e.bant(t("myConnections"), t("connSub")[:38])
    y = e.imlec
    for baslik_, kayitlar in ((t("connIncomingTitle"),
                               (("Deniz K.", t("connAccept"), "ok"),)),
                              (t("connOutgoingTitle"),
                               (("Kaan T.", t("connAwaiting"), "cost"),
                                ("Ece Y.", t("connActive"), "ok")))):
        e.metin((KENAR, y), baslik_, f(BOLD, 9.5), e.P["goldText"])
        y += 22 * K
        for ad, durum, ton in kayitlar:
            x, y0, g = e.kart(104 * K, y=y)
            e.avatar(x + 16 * K, y0 + 18 * K, ad[0], boy=44)
            e.metin((x + 74 * K, y0 + 22 * K), ad, f(BOLD, 14.5), e.P["ink"])
            e.metin((x + 74 * K, y0 + 44 * K), t("ccViewProfile"), f(REG, 11),
                    e.P["mutedAA"])
            e.cip(x + 74 * K, y0 + 66 * K, durum, ton=ton)
            y = y0 + 104 * K + 12 * K
        y += 8 * K
    ft = e.sigdir(t("connSub"), REG, 11.5, e.g - 2 * KENAR)
    e.metin((KENAR, y + 6 * K), t("connSub"), ft, e.P["dimAA"])
    e.alt_bar(3)
    return e


def seyahatler():
    e = Ekran()
    e.doku()
    e.bant(t("tripsTitle"), t("tripsSub"))
    y = e.imlec
    cx = e.cip(KENAR, y, t("subTabTrips"), secili=True)
    e.cip(cx, y, t("subTabListings"))
    y += 42 * K
    for ap, tarih, es, ton in (("IST · Aktarma", "16 Ekim · 14:00 – 18:00",
                                t("tripMatchCta").replace("{n}", "6"), "ok"),
                               ("SAW · Varış", "24 Ekim · 09:00 – 11:00",
                                t("tripMatchNone"), "unknown")):
        x, y0, g = e.kart(146 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 18 * K), ap, f(BOLD, 15), e.P["ink"])
        e.metin((ix, y0 + 42 * K), tarih, f(REG, 12), e.P["mutedAA"])
        # SQL 283 — kişi sayısı seyahat kartında görünür ("2 kişi · 4 yaş")
        if ap.startswith("IST"):
            e.cip(int(x + g - 16 * K - e.genislik("2 kişi · 4 yaş", f(SEMI, 10.5)) - 22 * K),
                  int(y0 + 14 * K), "2 kişi · 4 yaş")
        ayirac(e, ix, y0 + 72 * K, g - 32 * K)
        ft = e.sigdir(es, SEMI, 12, g - 32 * K)
        e.metin((ix, y0 + 88 * K), es, ft, e.R[ton])
        ft2 = f(SEMI, 11.5)
        s = t("findHost")
        w = e.genislik(s, ft2)
        e.metin((x + g - 16 * K - w, y0 + 114 * K), s, ft2, e.P["goldText"])
        y = y0 + 146 * K + 12 * K
    # 🔴 18 Eylül (Gökberk md.12) — önizleme de "Seyahat Ekle" diyor.
    # Bu düğme YENİ seyahat açıyor; etiketi "Seyahati Kaydet →" idi.
    # Ayna kapsamı (ayna_kapsam_check.py) önizleme ile ekranın AYNI
    # i18n anahtarlarını kullanmasını ölçüyor: ekranda değiştirip
    # burada bırakmak, aynanın bir özelliği "duruyor" göstermesi olurdu.
    y = e.dugme(y + 6 * K, t("addTrip"), "gold", yuk=52)
    ft = e.sigdir(t("tripsEmpty"), REG, 11.5, e.g - 2 * KENAR)
    e.metin((KENAR, y + 20 * K), t("tripsEmpty"), ft, e.P["dimAA"])
    e.alt_bar(2)
    return e



# ══════════════════════════════════════════════════════════════════
# 15–17 · GİRİŞ KAPISI — TANITIM · GİRİŞ · KAYIT
#
# 🔴 NEDEN ŞİMDİ EKLENDİ
#
# Gökberk: "splash, login, tanıtım ekranları, signup ... için önizleme
# görsellerini ver ve bakalım."
#
# Üreticide bu üç ekran YOKTU ve ben iki turdur "uçtan uca tamam"
# diyordum. Yani ürünün kullanıcıyla İLK KARŞILAŞTIĞI üç ekranı hiç
# çizmemişim — ve çizmediğim şeyi göremezdim.
#
# 🆕 SINIF: **"BİR ÖNİZLEME KÜMESİ, ÜRÜNÜN AKIŞINDAN DEĞİL BENİM
# DİKKATİMDEN SEÇİLMİŞSE, EN AZ BAKTIĞIM EKRAN EN ÇOK BOZULAN EKRAN
# OLUR — VE İLK EKRAN HERKESİN GÖRDÜĞÜ TEK EKRANDIR."**
# ══════════════════════════════════════════════════════════════════
def _sar(e, metin, ft, ic):
    """Metni verilen genişliğe SARAR. Kırpmaz — kırpmak cümlenin sonunu
    atmaktır ve bir başlıkta sonu atmak anlamı atmaktır."""
    kel, sat, cur = metin.split(" "), [], ""
    for w in kel:
        d = (cur + " " + w).strip()
        if e.genislik(d, ft) > ic and cur:
            sat.append(cur); cur = w
        else:
            cur = d
    if cur:
        sat.append(cur)
    return sat


def _alan(e, y, etiket, deger, ikon=None, g=None):
    """Form alanı — uygulamadaki `IconField` + `st.label` ile aynı."""
    g = g or (e.g - 2 * KENAR)
    e.metin((KENAR, y), buyuk(etiket), f(SEMI, 10.5), e.P["mut"], aralik=1.5,
            enfazla=g, kaynak="form etiketi")
    ky = y + 20 * K
    e.im.alpha_composite(
        e.yuvarlak((g, 52 * K), 12, rgb(e.P["bgAlt"]) + (255,),
                   rgb(e.P["line"]) + (255,)), (KENAR, ky))
    ix = KENAR + 16 * K
    if ikon:
        e.ikon(ix, ky + 17 * K, ikon, 16, e.P["mutedAA"])
        ix += 26 * K
    e.metin((ix, ky + 17 * K), deger, f(REG, 14), e.P["dimAA"])
    return ky + 52 * K + 18 * K


def tanitim():
    """Tanıtım (Başla sonrası). Uygulamadaki `Onboarding` ile aynı yapı:
    84px halka + vektör ikon → başlık (sans/700) → gövde → noktalar →
    altın düğme. Kare kutu ve glif ikon GİTTİ (bkz. App.js)."""
    e = Ekran()
    e.doku(y0=e.y * 0.30)
    # 🔴 Boş bir mesh bandı çizmiştim: içinde ne başlık ne üst bilgi
    # olduğu için ekranın tepesinde ANLAMSIZ koyu bir dikdörtgen
    # duruyordu. Bir başlık bandı, taşıyacak bir şeyi olduğunda vardır.
    e.metin((KENAR, 44 * K), "LOUNGELINK", f(BOLD, 10.5), e.P["body"],
            aralik=4.6)
    # halka + ikon
    d = 84 * K
    cx = (e.g - d) / 2
    ky = int(e.y * 0.30)
    e.im.alpha_composite(
        e.yuvarlak((d, d), d // 2, (255, 255, 255, 10),
                   rgb(e.P.get("line2", e.P["line"])) + (255,)), (int(cx), ky))
    e.ikon(cx + d / 2 - 17 * K, ky + d / 2 - 17 * K, "kutlama", 34, e.P["gold"])

    # başlık — iki satır, ortalı
    bas = "Kalkışa iki saat.\nSen ayaktasın."
    bf = f(BOLD, 34)
    y = ky + d + 34 * K
    for parca in bas.split("\n"):
        w = e.genislik(parca, bf)
        e.metin(((e.g - w) / 2, y), parca, bf, e.P["ink"])
        y += 38 * K

    gov = "Aynı terminalde, kartında kullanılmayan misafir hakkı olan biri oturuyor."
    ft = f(REG, 14)
    kel, satirlar, cur = gov.split(" "), [], ""
    for w in kel:
        dd = (cur + " " + w).strip()
        if e.genislik(dd, ft) > e.g - 4 * KENAR and cur:
            satirlar.append(cur); cur = w
        else:
            cur = dd
    if cur:
        satirlar.append(cur)
    y += 8 * K
    for i, sat in enumerate(satirlar[:4]):
        w = e.genislik(sat, ft)
        e.metin(((e.g - w) / 2, y + i * 22 * K), sat, ft, e.P["mut"])

    # nokta göstergesi — aktif olan uzun
    ny = e.y - 150 * K
    tg = 22 * K + 3 * (8 * K) + 3 * (4 * K)
    nx = (e.g - tg) / 2
    for i in range(4):
        w = 22 * K if i == 0 else 8 * K
        e.im.alpha_composite(
            e.yuvarlak((int(w), 8 * K), 4,
                       rgb(e.P["gold"] if i == 0 else e.P["line"]) + (255,)),
            (int(nx), int(ny)))
        nx += w + 4 * K
    e.dugme(e.y - 110 * K, t("onbNext"), "gold", yuk=52)
    return e


def giris():
    """Giriş ekranı. Tasarımın başlık hiyerarşisi burada da geçerli:
    dugum (GİRİŞ) → h1 → form → altın düğme."""
    e = Ekran()
    e.doku(y0=e.y * 0.34)
    e.daire_eylem(KENAR, 40 * K, "sol")
    e.metin((KENAR + 50 * K, 52 * K), "LOUNGELINK", f(BOLD, 10.5), e.P["body"],
            aralik=4.6)
    e.metin((KENAR, 108 * K), buyuk(t("login")), f(BOLD, 10.5), e.P["gold"],
            aralik=2.4, enfazla=e.g - 2 * KENAR, kaynak="giriş üst bilgi")
    # 🔴 30 AĞUSTOS · 5. TUR — TAŞMA KAPISI GERÇEK BİR ÜRÜN HATASI BULDU.
    # "Kaldığın yerden devam et" 34 puntoda 1180px istiyor, 1062px var.
    # Uygulamada bu başlık `numberOfLines={1}` bir `Bar` içindeydi —
    # yani KIRPILIYORDU: "Kaldığın yerden deva…". Kapıyı önizleme için
    # yazmıştım, ürünün kendi metnini yakaladı.
    #
    # 🆕 SINIF: **"BİR ÖNİZLEME KAPISI ÜRÜNÜN KENDİ VERİSİYLE
    # ÇALIŞIYORSA, ÖNİZLEMEYİ DEĞİL ÜRÜNÜ DENETLER."**
    bf = f(BOLD, 34)
    ya = 130 * K
    for sat in _sar(e, t("welcomeBack"), bf, e.g - 2 * KENAR)[:2]:
        # 🔴 `aralik=-1*K` KALDIRILDI: benim `metin()`im aralığı BOŞLUK
        # karakterine de uyguluyor, yani negatif izleme kelimeleri
        # birbirine yapıştırıyordu ("Kaldığınyerden"). Uygulamada RN'in
        # `letterSpacing`i bunu doğru yapıyor; önizlemede yapamıyorum.
        # Yapamadığım bir şeyi taklit etmektense HİÇ yapmıyorum —
        # yanlış bir taklit, eksik bir taklitten daha çok yanıltır.
        e.metin((KENAR, ya), sat, bf, e.P["ink"],
                enfazla=e.g - 2 * KENAR, kaynak="giriş başlığı")
        ya += 38 * K

    # 🔴 Sosyal düğmeler formun ÜSTÜNDE — uygulamada da öyle
    # (App.js: `<SocialAuthButtons/>` sonra e-posta alanı). Önizlemede
    # alta koymuştum; sıra bir yerleşim tercihi değil, bir AKIŞ kararı:
    # tek dokunuşla girebilecek kullanıcıyı form doldurmaya sokmamak.
    y = ya + 26 * K
    y = e.dugme(y, t("continueWithGoogle"), "ghost", yuk=52) + 12 * K
    y = e.dugme(y, t("continueWithApple"), "ghost", yuk=52) + 22 * K
    ayirac(e, KENAR, y, e.g - 2 * KENAR, 120)
    sf = f(REG, 11)
    ow = e.genislik(t("orWord"), sf)
    e._d().rectangle([(e.g - ow) / 2 - 10 * K, y - 9 * K,
                      (e.g + ow) / 2 + 10 * K, y + 12 * K],
                     fill=rgb(e.P["bg"]) + (255,))
    e.metin(((e.g - ow) / 2, y - 7 * K), t("orWord"), sf, e.P["dim"])
    y += 26 * K

    y = _alan(e, y, t("email"), "gokberk@ornek.com", "eposta")
    y = _alan(e, y, t("pass"), "••••••••", "kilit")
    y = e.dugme(y + 6 * K, t("login"), "gold", yuk=52) + 18 * K
    s2 = t("forgotLink")
    ft = f(SEMI, 13)
    w = e.genislik(s2, ft)
    e.metin(((e.g - w) / 2, y), s2, ft, e.P["goldText"])
    return e


def kayit():
    """Kayıt ekranı — adım 3 (onaylar). Onay kutuları artık VEKTÖR
    (`kutuDolu`/`kutuBos`); eskiden `☑`/`☐` karakterleriydi ve ikisi
    farklı genişlikte olduğu için her işaretlemede satır kayıyordu."""
    e = Ekran()
    e.doku(y0=e.y * 0.34)
    e.daire_eylem(KENAR, 40 * K, "sol")
    e.metin((KENAR + 50 * K, 52 * K), "LOUNGELINK", f(BOLD, 10.5), e.P["body"],
            aralik=4.6)
    e.metin((KENAR, 108 * K), buyuk(t("regStep3")), f(BOLD, 10.5),
            e.P["gold"], aralik=2.4)
    bf = f(BOLD, 34)
    ya = 130 * K
    for sat in _sar(e, t("consentTitle"), bf, e.g - 2 * KENAR)[:2]:
        e.metin((KENAR, ya), sat, bf, e.P["ink"],
                enfazla=e.g - 2 * KENAR, kaynak="kayıt başlığı")
        ya += 38 * K

    y = ya + 20 * K
    e.im.alpha_composite(
        e.yuvarlak((e.g - 2 * KENAR, 52 * K), 12, rgb(e.P["goldSoft"]) + (255,),
                   rgb(e.P["gold"]) + (255,)), (KENAR, y))
    e.ikon(KENAR + 16 * K, y + 16 * K, "kutuDolu", 19, e.P["gold"])
    e.metin((KENAR + 46 * K, y + 18 * K), t("consentAll"), f(SEMI, 14),
            e.P["goldText"], enfazla=e.g - 2 * KENAR - 62 * K, kaynak="tümünü kabul")
    y += 52 * K + 20 * K

    for anahtar, dolu in (("c1", True), ("c2", True), ("c3", True),
                          ("c4", True), ("c5", True), ("c6Age", False)):
        e.ikon(KENAR, y, "kutuDolu" if dolu else "kutuBos", 19,
               e.P["gold"] if dolu else e.P["mut"])
        s = t(anahtar)
        ft = f(REG, 13)
        ic = e.g - 2 * KENAR - 30 * K
        kel, sat, cur = s.split(" "), [], ""
        for w in kel:
            dd = (cur + " " + w).strip()
            if e.genislik(dd, ft) > ic and cur:
                sat.append(cur); cur = w
            else:
                cur = dd
        if cur:
            sat.append(cur)
        for i, l in enumerate(sat[:2]):
            e.metin((KENAR + 30 * K, y + 1 * K + i * 19 * K), l, ft,
                    e.P["body"] if dolu else e.P["mut"], enfazla=ic,
                    kaynak="onay satırı")
        y += max(30 * K, len(sat[:2]) * 19 * K + 14 * K)

    e.dugme(e.y - 110 * K, t("register"), "gold", yuk=52)
    return e


# ══════════════════════════════════════════════════════════════════
# 18–20 · v4.15 · YENİ ALANLAR — SEYAHAT FORMU (kişi/çocuk), ANLAŞMAZLIK, KİMLİK
#
# Üç yeni arayüz parçası (SQL 283/284/285). Gökberk'in kuralı: tasarım
# değişikliği önizlemesiz teslim edilmez. Üçü de uygulamadaki bileşenle
# aynı metin (i18n.js) ve aynı geometriyle (Secim çipi, S.card, Btn).
# ══════════════════════════════════════════════════════════════════
def _ust_geri(e, ust, baslik, alt=None):
    """Geri daireli üst: `Hdr` bileşeninin aynası (kural() ile aynı ölçüler):
    daire 40pt'de, eyebrow 92pt, başlık 112pt. `e.baslik()` eyebrow'u 54pt'e
    yazar ve geri dairesinin ÜSTÜNE biner — ilk denemede öyle oldu."""
    e.daire_eylem(KENAR, 40 * K, "sol")
    e.metin((KENAR, 92 * K), buyuk(ust), f(BOLD, 10.5), e.P["gold"], aralik=2.4)
    e.metin((KENAR, 112 * K), baslik, f(BOLD, 34), e.P["ink"])
    if alt:
        e.metin((KENAR, 156 * K), alt, f(REG, 12.5), e.P["mutedAA"])
    e.imlec = (180 if alt else 164) * K


def seyahat_formu():
    e = Ekran()
    e.doku(y0=e.y * 0.30)
    _ust_geri(e, t("scenePlan"), t("addTrip"))
    y = e.imlec + 6 * K
    y = _alan(e, y, "Havalimanı", "IST — İstanbul Havalimanı", ikon="ucus")
    y = _alan(e, y, t("date"), "2026-10-16", ikon="takvim")
    # SEYAHAT AMACI (mevcut)
    e.metin((KENAR, y), "SEYAHAT AMACI", f(SEMI, 10.5), e.P["mut"], aralik=1.5)
    y += 22 * K
    cx = KENAR
    for lb, sec in (("İş", True), ("Konferans", False), ("Tatil", False), ("Aktarma", False)):
        cx = e.cip(cx, y, lb, ton="ok", secili=sec) + 8 * K
    y += 40 * K
    # KİMLER GİRİYOR — SQL 283 · KisiSayisi bileşeni
    e.metin((KENAR, y), t("partyLabel"), f(SEMI, 10.5), e.P["mutedAA"], aralik=1.5)
    y += 22 * K
    cx = KENAR
    for i, lb in enumerate((t("partyOne"), "2 kişi", "3 kişi", "4 kişi")):
        cx = e.cip(cx, y, lb, ton="ok", secili=(i == 1)) + 8 * K
    y += 40 * K
    e.metin((KENAR, y), t("childLabel"), f(REG, 13), e.P["body"])
    y += 24 * K
    cx = KENAR
    cx = e.cip(cx, y, "4 yaş  ×", secili=True) + 8 * K
    for lb in ("+ 0–2", "+ 3–5", "+ 6–11", "+ 12–17"):
        cx = e.cip(cx, y, lb, ton="ok") + 8 * K
    y += 38 * K
    ft = f(REG, 11.5)
    for i, sat in enumerate(_sar(e, t("partyHint"), ft, e.g - 2 * KENAR)[:3]):
        e.metin((KENAR, y + i * 17 * K), sat, ft, e.P["dimAA"])
    y += 3 * 17 * K + 14 * K
    e.dugme(y, t("saveTrip"), "gold", yuk=52)
    return e


def anlasmazlik():
    e = Ekran()
    e.doku(y0=e.y * 0.30)
    _ust_geri(e, "SOHBET", "Ayşegül D.", alt="Turkish Airlines Lounge · IST · tamamlandı")
    y = e.imlec + 10 * K
    # tamamlanmış oturum çubuğu: Puanla düğmesi + "sorun bildir" bağlantısı
    y = e.dugme(y, t("rateNowBtn"), "gold", yuk=44)
    e.metin((KENAR, y + 12 * K), t("disputeBtn"), f(REG, 12.5), e.P["mut"])
    y += 44 * K
    # anlaşmazlık paneli (amber zemin) — Chat içindeki itirazPaneli
    ph = 300 * K
    x, y0, g = e.kart(ph, y=y, zemin=e.P["amberBg"] if "amberBg" in e.P else None)
    ix = x + 14 * K
    e.metin((ix, y0 + 14 * K), t("disputeTitle"), f(BOLD, 13), e.P["ink"])
    ft = f(REG, 12.5)
    for i, sat in enumerate(_sar(e, t("disputeBody"), ft, g - 28 * K)[:3]):
        e.metin((ix, y0 + 36 * K + i * 18 * K), sat, ft, e.P["body"])
    cy = y0 + 96 * K
    cx = ix
    # `disputeReasons` i18n'de DİZİ; sözlük ayrıştırıcı yalnız dize okur.
    # Aynı metinler (src/i18n.js · disputeReasons) — değişirse burası da.
    SEBEPLER = [("gelmedi", "Karşı taraf gelmedi"), ("kapida_ret", "Kapıda alınmadık"),
                ("ucret", "Beklenmeyen ücret istendi"), ("davranis", "Rahatsız edici davranış"),
                ("kredi", "Kredi / iade sorunu"), ("diger", "Başka bir şey")]
    for k, lb in SEBEPLER:
        w = e.genislik(lb, f(SEMI, 10.5)) + 22 * K
        if cx + w > x + g - 14 * K:
            cx = ix; cy += 34 * K
        cx = e.cip(cx, cy, lb, secili=(k == "gelmedi")) + 8 * K
    cy += 40 * K
    e.im.alpha_composite(e.yuvarlak((g - 28 * K, 56 * K), 12, rgb(e.P["bgAlt"]) + (255,),
                                    rgb(e.P["line"]) + (255,)), (int(ix), int(cy)))
    e.metin((ix + 14 * K, cy + 18 * K), t("disputeNote"), f(REG, 13), e.P["dimAA"])
    cy += 56 * K + 12 * K
    e.dugme(cy, t("disputeSend"), "gold", x=ix, g=g - 28 * K, yuk=40)
    return e


def kimlik():
    e = Ekran()
    e.doku(y0=e.y * 0.30)
    _ust_geri(e, t("kycEyebrow"), t("kycTitle"))
    y = e.imlec + 6 * K
    ft = f(REG, 13)
    sat = _sar(e, t("kycBody"), ft, e.g - 2 * KENAR)
    for i, l in enumerate(sat[:5]):
        e.metin((KENAR, y + i * 20 * K), l, ft, e.P["body"])
    y += len(sat[:5]) * 20 * K + 16 * K
    for lb, secili in ((t("kycDoc"), True), (t("kycSelfie"), False)):
        x, y0, g = e.kart(88 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 16 * K), lb, f(SEMI, 13), e.P["ink"])
        if secili:
            e.im.alpha_composite(e.yuvarlak((64 * K, 44 * K), 8, rgb(e.P["avatarBg"]) + (255,)), (int(ix), int(y0 + 38 * K)))
            e.cip(ix + 76 * K, y0 + 46 * K, t("kycPicked"), ton="ok")
        else:
            e.cip(ix, y0 + 46 * K, t("kycPick"))
        y = y0 + 88 * K + 12 * K
    ft2 = f(REG, 11.5)
    sat2 = _sar(e, t("kycPrivacy"), ft2, e.g - 2 * KENAR)
    for i, l in enumerate(sat2[:3]):
        e.metin((KENAR, y + i * 17 * K), l, ft2, e.P["dimAA"])
    y += len(sat2[:3]) * 17 * K + 16 * K
    e.dugme(y, t("kycSend"), "gold", yuk=52)
    return e


EKRANLAR = [
    ("01_splash", splash),
    ("02_kesfet", kesfet),
    ("03_kural", kural),
    ("04_eslesme", eslesme),
    ("05_tanis", tanis),
    ("06_sohbet", sohbet),
    ("07_oturum", oturum),
    ("08_puanla", puanla),
    ("09_profil", profil),
    # 🔴 30 Ağu · 6. tur — `("10_kesfet_acik", kesfet("C"))` KALKTI.
    # Gökberk: "attığın son önizleme görselinde keşfet yine beyaz
    # temada." Haklıydı ve sorun önizlemeden büyüktü: AÇIK TEMA hiç
    # yeniden tasarlanmamıştı ve üründe hâlâ seçilebiliyordu. Tema
    # arşive alındı (`_yedek_acik_tema/`), bu kare de yerini hiç
    # önizlenmemiş bir ekrana bıraktı: BİLDİRİMLER.
    ("10_bildirim", bildirim),
    ("11_ana_misafir", ana_misafir),
    ("12_ana_host", ana_host),
    ("13_baglantilar", baglantilar),
    ("14_seyahatler", seyahatler),
    ("15_tanitim", tanitim),
    ("16_giris", giris),
    ("17_kayit", kayit),
    ("18_seyahat_formu", seyahat_formu),
    ("19_anlasmazlik", anlasmazlik),
    ("20_kimlik", kimlik),
]


def main():
    os.makedirs(CIKTI, exist_ok=True)
    for ad, fn in EKRANLAR:
        e = fn()
        yol = os.path.join(CIKTI, ad + ".png")
        e.kaydet(yol)
        print("  ✓ %-18s %s" % (ad, os.path.basename(yol)))
    print("\n%d ekran → %s" % (len(EKRANLAR), CIKTI))
    import mockup
    if mockup._ATILAN:
        print("\nBİLEREK ATILAN GLİFLER (cihazda görünür, render fontunda yok):")
        for kaynak, glifler in mockup._ATILAN:
            print("   · %-14s %s" % (kaynak, glifler))
    return 0


if __name__ == "__main__":
    sys.exit(main())
