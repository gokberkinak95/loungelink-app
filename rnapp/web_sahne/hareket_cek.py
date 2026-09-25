#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/hareket_cek.py — DURAĞAN KAREDE GÖRÜNMEYENİ GÖRÜNÜR KIL.

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK: "Hareket ve titreşim durağan karede
yok. Parallax, kelime akışı, mühür, specular ve haptik ancak cihazda
görünür."

Doğruydu ve bunu ona ben söylemiştim — ama söylemekle bırakmak bir
çözüm değil. Hareket TEK KAREDE görünmez; ÇOK KAREDE görünür.
Bu betik animasyonun içinden kare kare geçip film şeridi çıkarıyor.

Ölçüm de yapıyor: ardışık kareler arasındaki piksel farkı. Bir
"animasyon" eklediğimi söyleyip kareler arasında 0 fark çıkarsa,
animasyon YOK demektir — ve bunu gözle değil sayıyla biliyorum.

⚠️ Ne ölçmüyor: titreşim (haptik). Web'de Taptic Engine yok; onun
tek kanıtı cihaz. Bunu gizlemiyorum, yazıyorum.

🆕 SINIF: "BİR ŞEYİN ÖLÇÜLEMEZ OLDUĞUNU SÖYLEMEK BİR TESPİTTİR, ÇÖZÜM
DEĞİL — ÖLÇÜM ARACINI DEĞİŞTİREBİLİYORSAN TESPİT MAZERET OLUR."
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cek                                                    # noqa: E402
from playwright.sync_api import sync_playwright               # noqa: E402

OUT = os.path.join(cek.KOK, "out", "hareket")
os.makedirs(OUT, exist_ok=True)
EXE = "/opt/pw-browsers/chromium/chrome"

# ad → (sahne, kim, hazırlık adımları, tetik adımı, kare zamanları ms)
ISLER = {
    # Zamanlar VİDEONUN başından itibaren (tetik ~sabit bir noktada).
    # Tanıtım 1 → 2 geçişi: kadraj kayar (parallax) + kelimeler süzülür
    "parallax": ("15_tanitim", "", [("dokun", "Başla")], ("dokun", "Devam"),
                 [0, 120, 240, 400, 600, 900]),
    # Kural motoru açılışı: üç hüküm sırayla mühürlenir
    "muhur":    ("03_kural", "kaan", [("dokun", "Keşfet")], ("dokun_a11y", "Uyum"),
                 [0, 100, 200, 320, 450, 700]),
    # ══════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — TETİKSİZ İKİ HAREKET.
    # Yaprak panosu SANİYEDE BİR kendiliğinden dönüyor; geçiş kartının
    # parıltısı AÇILIŞTA bir kez süzülüyor. İkisinin de bir "dokunma"sı
    # yok — `tetik=None` o durumu anlatıyor: hazırlık bitince kamera
    # zaten kayıtta, beklemek yeterli.
    # ══════════════════════════════════════════════════════════════
    "yaprak":   ("06_sohbet", "gokberk",
                 [("dokun_a11y", "İstek:"), ("bekle", 1500), ("dokun", "Sohbeti Aç")],
                 # 🔴 40ms ARALIK, 30 KARE. İlk denemede 120ms aralıkla 10
                 # kare aldım ve şeritte yalnız DURAN rakamlar çıktı: yaprak
                 # saniyede bir dönüyor ve dönüş 260ms sürüyor, yani 120ms'lik
                 # bir tarak dönüşün ya başını ya sonunu yakalıyor, ortasını
                 # değil. Örnekleme aralığı olayın süresinden büyükse olay
                 # "yok" görünür.
                 None, [i * 40 for i in range(30)]),
    "parilti":  ("21_cuzdan", "selin", [("dokun", "Profil")],
                 ("dokun_a11y", "Cüzdan"), [60, 200, 340, 480, 620, 800]),
}


# 🔴 EKRAN GÖRÜNTÜSÜ İLE ANİMASYON ÖRNEKLENMEZ — İKİNCİ DERS.
# Zamanlamayı sayfanın kendi saatine bağladıktan sonra bile kare
# zamanları 0/90/180 yerine 6/340/607 çıktı: tek bir `page.screenshot`
# ~200ms sürüyor ve 760ms'lik bir animasyonu 90ms aralıklarla
# örneklemek fiziksel olarak mümkün değil.
# Doğru alet VİDEO: Playwright bağlamı kaydediyor, kareleri sonradan
# ffmpeg kesiyor. Kayıt animasyonu yavaşlatmıyor, çünkü tarayıcının
# dışında çalışıyor.
# 🆕 SINIF: "BİR OLAYI ÖLÇEN ARAÇ, OLAYDAN YAVAŞSA ÖLÇÜM DEĞİL
# ÖRNEKLEME HATASI ÜRETİR — ARACI DEĞİŞTİR, EŞİĞİ DEĞİL."
def videodan_kareler(video_yolu, ad, zamanlar):
    import subprocess
    yollar = []
    for z in zamanlar:
        y = os.path.join(OUT, "%s_%04d.png" % (ad, z))
        # 🔴 `-ss` GİRDİDEN ÖNCE HIZLI ARAMADIR VE ANAHTAR KAREYE YAPIŞIR —
        # DÖRDÜNCÜ DERS.
        # 40ms aralıkla 30 kare aldığımda yalnız 3-4'ünde değişim çıktı;
        # "demek ki animasyon yok" diye okuyacaktım. Değilmiş: Playwright
        # videosunda anahtar kareler seyrek ve `-ss`i `-i`den ÖNCE
        # yazınca ffmpeg en yakın anahtar kareye atlıyor — yani 8 ayrı
        # zaman için AYNI kareyi yazıyordum. Ölçüm aleti sessizce
        # tekrar ediyordu.
        # `-ss`i `-i`den SONRA yazmak tam arama (decode ederek) yapar:
        # yavaş ama doğru. Bir ölçümde yavaşlık, yanlışlığa yeğdir.
        # 🆕 SINIF: "BİR ARACIN HIZLI KİPİ VARSA, HIZI NEYİN
        # KARŞILIĞINDA ALDIĞINI ÖĞRENMEDEN KULLANMA — BU ARAÇ HIZI
        # ÇÖZÜNÜRLÜKTEN ALIYORDU."
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
                        "-i", video_yolu, "-ss", "%.3f" % (z / 1000.0),
                        "-frames:v", "1", y], check=True)
        yollar.append((z, y))
    return yollar


def main(adlar):
    srv, port = cek.sunucu()
    kopru = cek.kopru_baslat()
    try:
        with sync_playwright() as p:
            b = p.chromium.launch(executable_path=EXE if os.path.exists(EXE) else None)
            for ad in adlar:
                sahne, kim, hazirlik, tetik, zamanlar = ISLER[ad]
                # 🔴 KARE ZAMANLARI VİDEONUN BAŞINDAN SAYILAMAZ — ÜÇÜNCÜ DERS.
                # İlk ölçümde `yaprak` 180ms'de 58.500 (= kırpmanın TAMAMI),
                # `parilti` 260ms'de 109.200 (yine tamamı) değişmiş çıktı.
                # O sayılar animasyon değil EKRAN GEÇİŞİYDİ: video bağlam
                # açılınca başlıyor, hazırlık adımları (gezinme, bekleme)
                # bir-iki saniye sürüyor ve istediğim pencere çoktan
                # geçmiş oluyordu. Yani ölçtüğüm şey ölçmek istediğim şey
                # değildi — ve rakam BÜYÜK olduğu için "çalışıyor" diye
                # okunabilirdi. En tehlikeli ölçüm yanlış olan değil,
                # yanlışken de inandırıcı olandır.
                # Çözüm: sıfır noktasını duvar saatiyle taşımak.
                # 🆕 SINIF: "BİR ÖLÇÜMÜN SIFIR NOKTASINI VARSAYARSAN,
                # ÖLÇTÜĞÜN BÜYÜKLÜK DOĞRU AMA KONUSU YANLIŞ OLUR."
                import time as _time
                t0 = _time.monotonic()
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                                    is_mobile=True, has_touch=True, locale="tr-TR",
                                    record_video_dir=os.path.join(OUT, "_video"),
                                    record_video_size={"width": 390, "height": 844})
                pg = ctx.new_page()
                kayit = {"console": [], "errors": []}
                pg.on("pageerror", lambda e: kayit["errors"].append(str(e)[:300]))
                pg.goto("http://127.0.0.1:%d/?sahne=%s&kim=%s&kopru=http://127.0.0.1:%d"
                        % (port, sahne, kim, cek.KOPRU_PORT), wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception:
                    kayit["errors"].append("__LL_HAZIR beklenmedi")
                for a in hazirlik:
                    cek.adim_uygula(pg, a, kayit)
                # tetik: `adim_uygula` sonrası 1200ms bekliyor — animasyonu
                # kaçırmamak için tetiği ELLE, beklemesiz tıklıyoruz.
                import re as _re
                if tetik is None:
                    pass                       # kendiliğinden dönen hareket
                elif tetik[0] == "dokun":
                    pg.get_by_text(_re.compile(r"^\s*" + _re.escape(tetik[1]) + r"\s*(→|›)?\s*$",
                                               _re.I)).last.click(timeout=4000)
                else:
                    pg.get_by_label(_re.compile(_re.escape(tetik[1]), _re.I)).first.click(timeout=4000)
                sifir = int((_time.monotonic() - t0) * 1000)   # tetik anı, video başından
                pg.wait_for_timeout(1800)          # animasyon bitene kadar kaydet
                vid = pg.video.path()
                ctx.close()                        # video ancak kapanınca yazılıyor
                videodan_kareler(vid, ad, [sifir + z for z in zamanlar])
                print("%-10s hata=%d  sıfır=%dms  video=%s" %
                      (ad, len(kayit["errors"]), sifir, os.path.basename(vid)), kayit["errors"][:1])
            b.close()
    finally:
        srv.shutdown()
        kopru.terminate()


if __name__ == "__main__":
    main(sys.argv[1:] or list(ISLER))
