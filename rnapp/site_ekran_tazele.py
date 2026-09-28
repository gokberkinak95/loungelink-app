#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
site_ekran_tazele.py — SİTENİN `public/screens/` RAFINI TAZELER.

🔴 NEDEN VAR
`website/ekran_goruntusu_check.py` sitenin tek kırmızısıydı: raftaki 9
JPG 16 Ağustos tarihli, ürün o günden beri fotoğraflı bant, sıcak
palet, yeni düğme sistemi ve koyu tema kazandı. Yani siteye gelen biri,
indirdiği uygulamadan BAŞKA bir şey görüyordu.

🔴 VE BİR DÜRÜSTLÜK MESELESİ
O denetimin kendi metni şöyle diyor: "Tazeleme kısa yol yok — gerçek
cihazdan/emülatörden yeni görüntü almak gerekir." Buradaki görseller
CİHAZDAN GELMİYOR; `ekran_uret.py` ile ÜRÜNÜN KAYNAĞINDAN üretiliyor
(renk `theme.js`, geometri `ui.js`, metin `i18n.js`).

Bu, bayat bir ekran görüntüsünden daha doğru — ama cihazın kendisi
değil: gerçek cihaz font hinting'i, durum çubuğu, güvenli alan ve
platform bileşenleri (klavye, seçici) burada yok.

O yüzden kendi nöbetçimi kandırmıyorum: `SURUM.json`a `tur: "render"`
yazıyorum ve denetimi bu alanı OKUYACAK ve ⚠ verecek şekilde
genişletiyorum. Yeşile boyamak bir dakikalık iş; borcu görünür
tutmak, o borcu kapatacak tek şey.

🆕 SINIF: "KENDİ NÖBETÇİNİ GEÇMEK İÇİN ÜRETTİĞİN VEKİL, VEKİL OLDUĞUNU
SÖYLEMİYORSA — NÖBETÇİYİ KAPATMIŞSIN DEMEKTİR."
"""
import json
import os
import sys

from PIL import Image

KOK = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(os.path.dirname(KOK), "website")
# ══════════════════════════════════════════════════════════════════════
# 🔴 19 EYLÜL — KAYNAK DEĞİŞTİ: `ekran_uret.py` → `web_sahne/out`.
#
# Eski kaynak `ekranlar_render/` idi: `ekran_uret.py` renkleri
# `theme.js`ten, geometriyi `ui.js`ten, metni `i18n.js`ten okuyup kareyi
# KENDİ ÇİZİYORDU. Yani ürünün bileşen ağacını değil, o ağacın bir
# YENİDEN ANLATIMINI gösteriyordu — ve o anlatım, bileşen değiştiğinde
# sessizce eskiyebiliyordu.
#
# `web_sahne/out` ise gerçek React ağacını gerçek veriyle, 1170×2532'de
# Chromium'da çiziyor: aynı bileşenler, aynı RPC'ler, aynı RLS.
# Dosya adları zaten birebir aynı (`01_splash`, `14_seyahatler`…),
# yani eşleme tablosuna dokunmak gerekmedi.
#
# ⚠️ BU HÂLÂ CİHAZ DEĞİL. react-native-web + Chromium; font hinting,
# durum çubuğu, güvenli alan ve platform bileşenleri yok. Manifestteki
# `tur` alanı bu yüzden "render" kalıyor ve nöbetçi ⚠ vermeye devam
# ediyor — borç kapanmadı, sadece küçüldü.
#
# 🆕 SINIF: "ÜRÜNÜN BİR RESMİNİ ÇİZMEKLE ÜRÜNÜN KENDİSİNİ ÇALIŞTIRIP
# FOTOĞRAFINI ÇEKMEK AYNI ŞEY DEĞİLDİR — İKİNCİSİ BİLEŞEN DEĞİŞTİĞİNDE
# KENDİLİĞİNDEN DEĞİŞİR, BİRİNCİSİ DEĞİŞMEZ."
# ══════════════════════════════════════════════════════════════════════
KAYNAK = os.path.join(KOK, "web_sahne", "out")
ESKI_KAYNAK = os.path.join(KOK, "ekranlar_render")
HEDEF = os.path.join(SITE, "public", "screens")
TANITIM = os.path.join(KOK, "tanitim")

EN, BOY = 480, 1039          # 1170×2532 oranı: 0.46209 → 480/0.46209

ESLESME = [
    ("ss-splash.jpg", "01_splash", "LoungeLink açılış — önce güven"),
    ("ss-kesfet.jpg", "02_kesfet", "Keşfet — kural rozetli ilan listesi"),
    ("ss-n.jpg", "03_kural", "İstek gönder — kural motorunun kararı"),
    # 🔴 19 EYLÜL — ÜÇ KARE YENİDEN EŞLEŞTİRİLDİ.
    # `04_eslesme`, `07_oturum` ve `08_puanla` yalnız `ekran_uret.py`nin
    # ÇİZDİĞİ karelerdi; `web_sahne`de karşılıkları yok çünkü o üç şey
    # ayrı bir ekran değil, var olan ekranların BİR HÂLİ. Uydurmak yerine
    # gerçek karşılıklarına bağlandılar — ve alt metinleri de o karenin
    # GERÇEKTEN gösterdiği şeye göre düzeltildi.
    #
    # 🆕 SINIF: "BİR GÖRSELİN ADINI DEĞİL GÖSTERDİĞİ ŞEYİ ANLAT — AD
    # ESKİYEBİLİR, GÖSTERDİĞİ ŞEY ESKİMEZ."
    # 🔴 21 EYLÜL — Gökberk: "örnek sohbet ekranı biraz boş bir ss gibi".
    # Ölçtüm, haklı: `06b_sohbet_tanis` dört mesaj taşıyor ve karenin
    # ALT %55'i boş siyah. Sebep ürün kusuru değil — sohbet ekranı kısa
    # bir konuşmayı ÜSTTEN diziyor. Üründe doğru, VİTRİNDE yanlış:
    # ziyaretçi boşluğu "içi yok" diye okuyor.
    # `45_sohbet_uzun` aynı ekranın dolu hâli: geri sayım, konum şeridi,
    # hızlı yanıt çipleri, yazma kutusu, bekleme düğmesi — hepsi görünür.
    # 🆕 SINIF: "VİTRİNE ÜRÜNÜN EN SEYREK HÂLİNİ KOYARSAN, ZİYARETÇİ
    # ÜRÜNÜN KENDİSİNİ SEYREK SANIR — EN DOLU DOĞRU HÂLİNİ KOY."
    ("ss-eslesme.jpg", "45_sohbet_uzun", "Sohbet — kapıda buluşma koordinasyonu"),
    ("ss-tanis.jpg", "05_tanis", "Tanış — havalimanı yol arkadaşı ağı"),
    ("ss-m.jpg", "06_sohbet", "Sohbet — oturum öncesi koordinasyon"),
    ("ss-oturum.jpg", "35_canli_durum", "Oturum · canlı durum paylaşımı"),
    ("ss-puanla.jpg", "23_degerlendirme", "Değerlendirmeler — güven döngüsü"),
    ("ss-profil.jpg", "09_profil", "Profil — puan, oturum, LoungePuan"),
    ("ss-home.jpg", "11_ana_misafir", "Ana ekran — misafir görünümü"),
    ("ss-home2.jpg", "12_ana_host", "Ana sayfa — host paneli"),
    ("ss-baglanti.jpg", "13_baglantilar", "Bağlantılar — karşılıklı onaylı"),
    ("ss-seyahat.jpg", "14_seyahatler", "Seyahatlerim — salon rehberiyle"),
    # yeni: koyu tema sitede hiç gösterilmiyordu
    # 🔴 30 Ağu · 6. tur — `10_kesfet_koyu` ARTIK ÜRETİLMİYOR.
    # Tek tema kaldığı için "koyu tema" diye ayrı bir kare anlamsız;
    # o karenin yerini BİLDİRİMLER aldı (`10_bildirim`). Eşleme
    # güncellenmeseydi script diskte duran ESKİ png'yi bulup siteye
    # basmaya devam ederdi — nitekim bir kez öyle yaptı.
    #
    # 🆕 SINIF: "BİR ÜRETİCİYİ DEĞİŞTİRİP TÜKETİCİSİNİ DEĞİŞTİRMEZSEN,
    # TÜKETİCİ ESKİ ÇIKTIYI DİSKTEN OKUMAYA DEVAM EDER — VE HİÇBİR
    # ŞEY HATA VERMEZ."
    ("ss-bildirim.jpg", "10_bildirim", "Bildirimler — akış tek yerde"),
    # 28 Eylül · site 0.69 (Gökberk: "Milleri topladın…" yanında eşleştiniz
    # ekranı) — 6.2'nin K5 "kapı aralanır" anı: kemerin altında iki koltuk.
    ("ss-eslesti.jpg", "60_vitrin_kapi", "Eşleştiniz — kapı aralanır, yanındaki koltuk dolar"),
]

TANITIM_ESLESME = [("hero-phones.jpg", "web_hero.png"),
                   ("hero-raf.jpg", "web_raf.png")]


def main():
    if not os.path.isdir(KAYNAK):
        print("🔴 %s yok — önce sahneleri çek:" % KAYNAK)
        print("     LL_SAHNE=1 npx expo export --platform web --output-dir web_sahne/dist")
        print("     python web_sahne/cek.py")
        return 1
    # ⚠️ AYNI SAHNEYİ İKİ SİTE GÖRSELİNE BASMAK YASAK.
    # `web_sahne` tarafında tam bu tuzağa düştük: iki sahne birebir aynı
    # kareyi kaydediyordu ve kimse fark etmiyordu. Aynı hata burada
    # "site 15 ekran gösteriyor ama 13 ekran var" olarak görünürdü.
    kay = [k for _a, k, _t in ESLESME]
    if len(set(kay)) != len(kay):
        tekrar = sorted({k for k in kay if kay.count(k) > 1})
        print("🔴 EŞLEME TABLOSUNDA TEKRAR EDEN SAHNE: %s" % ", ".join(tekrar))
        print("   İki site görseli aynı kareyi gösterirse site, üründe")
        print("   olmayan bir çeşitlilik vaat eder.")
        return 1
    os.makedirs(HEDEF, exist_ok=True)
    surum = json.load(open(os.path.join(KOK, "app.json"), encoding="utf-8"))
    surum = surum["expo"]["version"]

    print("=" * 74)
    print("SİTE EKRAN RAFI TAZELEME — kaynak: web_sahne/out (gerçek ağaç + gerçek veri)")
    print("=" * 74)
    yazilan = []
    for ad, kaynak, _alt in ESLESME:
        p = os.path.join(KAYNAK, kaynak + ".png")
        if not os.path.exists(p):
            print("  ✗ %s — kaynak render yok (%s)" % (ad, kaynak))
            return 1
        im = Image.open(p).convert("RGB").resize((EN, BOY), Image.LANCZOS)
        im.save(os.path.join(HEDEF, ad), quality=88, optimize=True)
        yazilan.append(ad)
        print("  ✓ %-20s ← %-16s %dx%d" % (ad, kaynak, EN, BOY))

    for ad, kaynak in TANITIM_ESLESME:
        p = os.path.join(TANITIM, kaynak)
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((1800, 1800), Image.LANCZOS)
            im.save(os.path.join(HEDEF, ad), quality=86, optimize=True)
            yazilan.append(ad)
            print("  ✓ %-20s ← %-16s %s" % (ad, kaynak, im.size))

    manifest = {
        "_not": ("Sitedeki ekran görüntülerinin HANGİ app sürümünden ve NASIL "
                 "üretildiği. ekran_goruntusu_check.py bunu rnapp/app.json ile "
                 "karşılaştırır ve `tur` alanını okur."),
        "app_surumu": surum,
        "alindi": __import__("datetime").date.today().isoformat(),
        "tur": "render",
        "uretici": "rnapp/web_sahne/cek.py (gercek React agaci + gercek veri, 1170x2532 Chromium)",
        "tur_aciklama": (
            "Bu görseller GERÇEK CİHAZDAN alınmadı. 19 Eylül'de kaynak "
            "değişti: artık `ekran_uret.py`nin kendi çizdiği kare değil, "
            "`web_sahne/cek.py`nin gerçek React ağacını gerçek veriyle "
            "(yerel Postgres · gerçek RPC + RLS) 1170×2532 Chromium'da "
            "çizip fotoğrafladığı kare. Bileşen değiştiğinde görsel de "
            "kendiliğinden değişir. EKSİK OLAN hâlâ cihazın kendisi: font "
            "hinting, durum çubuğu, güvenli alan ve platform bileşenleri "
            "(klavye/seçici). Cihaz görüntüsü alındığında `tur` alanını "
            "'cihaz' yap."),
        "kabul_edildi": False,
        "gorseller": yazilan,
        "aradaki_degisiklikler": [],
    }
    json.dump(manifest, open(os.path.join(HEDEF, "SURUM.json"), "w",
                             encoding="utf-8"),
              ensure_ascii=False, indent=2)
    print("\n  ✓ SURUM.json — app %s · tür: render" % surum)
    print("\n%d dosya yazıldı." % len(yazilan))
    print("⚠ Bunlar CİHAZ görüntüsü değil, kaynaktan render. Nöbetçi bunu")
    print("  ⚠ olarak raporlayacak — borç kapanmadı, GÖRÜNÜR hâle geldi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
