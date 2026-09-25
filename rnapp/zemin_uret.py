# -*- coding: utf-8 -*-
"""
zemin_uret.py — İÇ EKRAN ZEMİNİNİ ÜRETİR VE ÖLÇER

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "iç sayfalarda arka plandaki tırtıklı görünüm sanki
ekranda bir sorun var havası yaratıyor... Dümdüz bir şey de sıkıcı olabilir
ama güzel bir çözüm düşün. Tema renklerimizi bozmadan soft bir renk geçişli
güzel bir şey olabilir."

TEŞHİS — TAHMİN DEĞİL, KODDAN ÖLÇÜLDÜ (`src/atmosfer.js`, eski hâli):

  · `IrtifaGrid` — her 30 dp'de bir, 1 dp kalınlığında 25 ADET SERT ÇİZGİ
  · `Ufuk`       — 14 basamaklı bir BANT YIĞINI (gradyan değil, merdiven)
  · `Bulut` ×3

Yani ekranda 42 ayrı `View` vardı ve 39'unun KENARI KESKİNDİ.

Bir cihazda 1 dp = 2.75 fiziksel piksel (Gökberk'in telefonu 1080×2312,
~2.75x). 2.75 tam sayı değildir: rasterleştirici çizgileri sırayla 3 px, 3 px,
2 px, 3 px... çizer. Göz bu düzensizliği "titreşim" olarak okur. Üstüne
çizgiler eşit aralıklı olduğu için ekranın piksel ızgarasıyla MOİRE üretir.
Sonuç: "ekranda bir sorun var" hissi. Gökberk kusuru doğru gördü, biz
sebebini yanlış yere koymuştuk — bu bir renk sorunu değil, RASTERLEŞTİRME
sorunuydu.

🆕 SINIF: "SERT KENARLI VE EŞİT ARALIKLI HER DESEN, PİKSEL IZGARASIYLA
GİRİŞİM YAPAR — DOKU İSTİYORSAN KENARI OLMAYAN BİR ŞEY ÇİZ."

ÇÖZÜM: çizgi yok, basamak yok. Tek bir PNG — gerçek bir gradyan, 8-bit
banding'i kırmak için GÜRÜLTÜLENDİRİLMİŞ (dither). Ekranda tek bir
`<Image resizeMode="stretch">` olarak geriliyor; ara pikselleri GPU
doğrusal olarak karıştırıyor, yani ölçek ne olursa olsun basamak oluşmuyor.

YAN KAZANÇ (ölçülebilir): ekran başına 42 native `View` → 1 `Image`.
Bu 41 daha az düğüm, 41 daha az ölçüm/yerleştirme, her render'da.

⚠️ RENK PALETTEN. Hiçbir sabit renk yok: `tema_oku.palet()` ile theme.js'ten
okunuyor. Palet değişirse bu betik yeniden çalıştırılır; `doku_check.py`
üretilen dosyanın palete uyduğunu doğruluyor.

⚠️ KONTRAST ÖNCE ÖLÇÜLÜYOR. Zemin metnin ARKASINDA — kartlar opak olsa da
bazı metinler (bölüm başlıkları, boş durum satırları) doğrudan zeminin
üstünde. Bu betik gradyanın HER SATIRINDA gövde/ikincil/soluk mürekkebin
oranını ölçüyor ve EN KÖTÜ NOKTA AA'yı geçmiyorsa dosyayı YAZMIYOR.
============================================================================
"""
import os
import sys

from PIL import Image

import tema_oku as T

KOK = os.path.dirname(os.path.abspath(__file__))
CIKTI = os.path.join(KOK, "assets")

# Gradyan yüksekliği. 1024 satır, 2312 px'lik bir ekrana gerildiğinde
# satır başına ~2.26 px düşer ve GPU aradakileri karıştırır — yani
# görünürde sonsuz basamak.
BOY = 1024
EN = 8          # genişlik: yatayda düz, ama 1 px'lik doku bazı sürücülerde
                # kenar yumuşatmayı bozuyor; 8 px güvenli ve hâlâ ~10 KB.

# Metin AA tabanı. Gövde metni 4.5, iri metin 3.0 — biz en sıkısını alıyoruz.
AA = 4.5


def _karis(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _egri(t):
    """Yumuşama eğrisi (smoothstep).

    Doğrusal bir gradyan, iki ucunda göze BANT gibi görünür — çünkü göz
    değişim hızındaki ANİ kesintiyi yakalar, değerin kendisini değil.
    smoothstep türevi uçlarda sıfırlanır: geçiş başlarken ve biterken
    yumuşar.

    🆕 SINIF: "GÖZ DEĞERİ DEĞİL DEĞİŞİM HIZINI GÖRÜR — GRADYANIN UCUNU
    YUMUŞATMAZSAN ORTASI PÜRÜZSÜZ OLSA BİLE UCU BANT YAPAR."
    """
    return t * t * (3 - 2 * t)


def uret(kapsam, ad):
    p = T.palet(kapsam)
    zemin = T.hex_rgb(p["bg"])
    doku = p.get("_doku_ufuk") or "#E39B6B"

    # Üst uç: sayfa zemininin kendisi. Alt uç: zemin + ufuk renginin
    # ÇOK az bir payı. Böylece gradyan paletin dışına ÇIKMIYOR — yalnız
    # kendi zemininden kendi sıcak tonuna doğru nefes alıyor.
    ufuk = T.hex_rgb(doku)
    pay = 0.085 if kapsam == "C" else 0.055     # koyu temada daha az: ışık az
    alt = tuple(round(zemin[i] + (ufuk[i] - zemin[i]) * pay) for i in range(3))

    # ── ÖNCE ÖLÇ, SONRA YAZ ────────────────────────────────────────────
    # Gradyanın her satırında mürekkeplerin oranı. En kötüsü AA'yı
    # geçmiyorsa hiç yazmıyoruz.
    murekkepler = {}
    for k in ("ink", "body", "mutedAA", "dimAA"):
        if p.get(k):
            murekkepler[k] = T.hex_rgb(p[k])
    enkotu = {k: 99.0 for k in murekkepler}
    satirlar = []
    for y in range(BOY):
        u = y / (BOY - 1)
        t = _egri(u)
        renk = _karis(zemin, alt, t)

        # ── UFUK PARILTISI ─────────────────────────────────────────────
        # 🔴 Gökberk: "dümdüz bir şey de sıkıcı olabilir." Haklı — ama
        # "sıkıcı değil"in bedeli KENAR olmamalı, yoksa düzelttiğimiz
        # kusura geri döneriz.
        #
        # Bu yüzden tek öge var ve KENARI YOK: ekranın %62'sinde, çok
        # geniş ve çok yumuşak bir aydınlanma. %62 keyfî değil — "an"
        # ekranlarının (splash, tanıtım, buluşma) çizilmiş gün batımında
        # ufuk tam orada (atmosfer.js · CizilmisGunBatimi, t > 0.62).
        # Yani iş ekranları, marka anlarıyla AYNI ufka sahip; kullanıcı
        # bunu fark etmez, sadece "aynı ürün" hisseder.
        #
        # 🆕 SINIF: "BİR ARKA PLANIN İŞİ İLGİ ÇEKMEK DEĞİL, EKRANLARI
        # BİRBİRİNE BAĞLAMAKTIR — FARK EDİLİYORSA FAZLA GELMİŞTİR."
        d = (u - 0.62) / 0.30
        pariltı = max(0.0, 1.0 - d * d)          # kenarları sıfıra inen parabol
        pariltı = pariltı * pariltı * 0.030      # tepe noktası %3
        if kapsam != "C":
            pariltı *= 0.55                       # koyu temada yarısı kadar
        renk = tuple(
            max(0, min(255, round(renk[i] + (ufuk[i] - renk[i]) * pariltı)))
            for i in range(3)
        )
        satirlar.append(renk)
        for k, m in murekkepler.items():
            o = T.oran(renk, m)
            if o < enkotu[k]:
                enkotu[k] = o

    print("  %s · zemin %s → %s" % (kapsam, p["bg"], "#%02X%02X%02X" % alt))
    kirik = []
    for k, o in sorted(enkotu.items()):
        im = "✓" if o >= AA else "✗"
        print("      %s %-8s en kötü %.2f:1" % (im, k, o))
        if o < AA:
            kirik.append(k)
    if kirik:
        print("      ✗ AA altına düşen mürekkep: %s — dosya YAZILMADI." % kirik)
        return False

    # ── DITHER ─────────────────────────────────────────────────────────
    # 🔴 8-bit bir gradyan 1024 satıra yayıldığında aynı değer onlarca
    # satır tekrar eder ve tam da o tekrarların bittiği yerde göz bir
    # ÇİZGİ görür. Bu, düzelttiğimiz kusurun daha ince bir biçimidir.
    # Çözüm: her piksele ±1 seviyelik düzenli (ordered) bir sapma ekle.
    # Gürültü rastgele değil DÜZENLİ: rastgele gürültü sıkıştırılamaz ve
    # dosyayı üç katına çıkarır.
    #
    # 🆕 SINIF: "8 BİTLİK BİR GRADYAN MATEMATİKSEL OLARAK PÜRÜZSÜZ OLSA
    # BİLE GÖRSEL OLARAK BANTLIDIR — TEK ÇARE KUANTALAMA HATASINI
    # DAĞITMAKTIR."
    BAYER = [[0, 2], [3, 1]]
    im = Image.new("RGB", (EN, BOY))
    px = im.load()
    for y in range(BOY):
        r, g, b = satirlar[y]
        for x in range(EN):
            d = BAYER[y % 2][x % 2] / 4.0 - 0.375     # -0.375 … +0.375
            px[x, y] = (
                max(0, min(255, round(r + d))),
                max(0, min(255, round(g + d))),
                max(0, min(255, round(b + d))),
            )
    yol = os.path.join(CIKTI, ad)
    im.save(yol, optimize=True)
    print("      → %s  (%d bayt)" % (ad, os.path.getsize(yol)))
    return True


def main():
    print("=" * 70)
    print("İÇ EKRAN ZEMİNİ — paletten üretiliyor, önce kontrast ölçülüyor")
    print("=" * 70)
    tamam = True
    tamam &= uret("C", "zemin-acik.png")
    tamam &= uret("KOYU", "zemin-koyu.png")
    print("=" * 70)
    if not tamam:
        print("✗ Zemin üretilemedi — kontrast AA'nın altında.")
        return 1
    print("✓ İki zemin de üretildi ve AA'yı geçiyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
