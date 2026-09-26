# -*- coding: utf-8 -*-
"""
tasarim_yapi_check.py — TASARIMIN YAPISI UYGULANDI MI? (ÖLÇÜM)

============================================================================
🔴 NEDEN VAR

Gökberk üç şey gösterdi ve üçü de doğruydu:
  1. ana sayfada etiket taşmaları
  2. sohbette hızlı durum çiplerinin YERİ (yazma kutusunun üstünde
     olmalıydı, konuşmanın ortasında çıktı)
  3. kural ekranında düğmelerin YERİ (ekranın altında olmalıydı,
     ortada çıktı)

Ve sonra şunu söyledi: **"birebir uygulayıp uygulamadığını ÖLÇ."**

`tasarim_uyum_check.py` MALZEMEYİ ölçüyor (serif · sembol · emoji · renk).
Malzeme doğru olabilir ve YERLEŞİM yine yanlış olabilir — üç bulgusunun
üçü de tam olarak buydu: doğru renk, doğru font, yanlış yer.

🆕 SINIF: **"BİR TASARIMIN MALZEMESİNİ ÖLÇMEK, YAPISINI ÖLÇMEK DEĞİLDİR.
DOĞRU TUĞLALARLA YANLIŞ BİR EV YAPILABİLİR — VE MALZEME DENETİMİ ONA
YEŞİL YANAR."**

NE ÖLÇÜYOR: tasarımın `css.py`sindeki YERLEŞİM İDDİALARINI çıkarıp
uygulamada karşılığını arıyor. Her iddia bir çift:
    (tasarımdaki kural, uygulamada aranan kanıt)

Bir iddianın kanıtı yoksa BULGU. Kanıt bir yorum değil, KODUN KENDİSİ.

⚠️ NE ÖLÇMÜYOR: piksel. Cihazda render alamıyorum; bu denetim
"yapı kurulmuş mu" der, "2 piksel kaymış mı" demez. Bunu yazmak
zorundayım çünkü bir denetimin en tehlikeli hâli, ölçmediği şeyi
ölçüyor sanılmasıdır.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
# 🔴 Tasarım İKİ dosyada: `css.py` kuralları, `gen.py` yapıyı kuruyor.
# İlk hâlimde yalnız `css.py`ye bakıyordum ve `gen.py`deki bir iddiayı
# "tasarımda bulunamadı" diye ATLADI — yani denetim sessizce daralmıştı.
# Atlanan bir iddia, bulgusuz bir iddiadan ayırt edilemez.
TASARIM_D = os.path.join(os.path.dirname(KOK), "tasarim")

# 🔴 30 AĞUSTOS · 5. TUR — TASARIM KAYNAĞI ARTIK PAKETİN İÇİNDE.
# Bu denetim `../tasarim/css.py` okuyordu ve o klasör YALNIZ BENİM
# makinemde vardı. Yani Gökberk `node verify.js` çalıştırdığında bu
# kapı kırmızı yanacaktı — hiç haber vermeden, "senin makinende
# çalışmıyor" diye değil "tasarım uygulanmamış" diye.
#
# 🆕 SINIF: "BENİM MAKİNEMDE GEÇEN AMA KULLANICININ MAKİNESİNDE
# ÇALIŞAMAYAN BİR KAPI, KAPI DEĞİL — KENDİME YAZILMIŞ BİR NOTTUR."
_GOMULU = os.path.join(KOK, "tasarim_kaynak")
if os.path.exists(os.path.join(_GOMULU, "css.py")):
    TASARIM_D = _GOMULU



def oku(*p):
    with open(os.path.join(*p), encoding="utf-8") as f:
        return f.read()


def kod(s):
    """🔴 30 AĞUSTOS · 4. TUR — DENETİM KENDİ YORUMUMU KANIT SANDI.

    Bu dosyanın kendi açıklaması "Kanıt bir yorum değil, KODUN KENDİSİ"
    diyordu ve ben yorumları AYIKLAMAYI unutmuştum. Mutasyon testi
    yaptım: kural ekranındaki `marginTop:"auto"`yu sildim — denetim
    YEŞİL yandı, çünkü aynı ifade 70 satır yukarıdaki YORUMUMDA
    geçiyordu.

    Yani nöbetçi, kendi hakkında yazdığım övgüyü kanıt sayıyordu.

    🆕 SINIF: **"BİR DENETİM, DOĞRULADIĞI ŞEYİN AÇIKLAMASINI DA
    OKUYORSA, İYİ YAZILMIŞ BİR YORUM TEK BAŞINA YEŞİL YAKAR — VE
    KODUN NE YAPTIĞINI DEĞİL, NE YAPTIĞINI SÖYLEDİĞİMİ ÖLÇER."**
    """
    s = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)


# ── İDDİALAR ────────────────────────────────────────────────────────
# (ad, tasarımda_aranan_css, dosya, uygulamada_aranan_kanıt, açıklama)
IDDIALAR = [
    ("eylem yığını dibe",
     r"\.an\{[^}]*justify-content:space-between",
     "ekranlar_ana.js", r'marginTop: "auto"',
     "`.an` ve kural ekranı: asıl eylem ekranın DİBİNDE"),

    ("çipler yazma kutusuna bitişik",
     r"\.cipler\{[^}]*flex:0 0 auto",
     # 🔴 31 AĞU · 9. TUR — PENCERE 700'DÜ VE DOĞRU BİR DEĞİŞİKLİK ONU AŞTI.
     # Yazma kutusu tasarımdaki `.yazma`ya çevrilince (düğme kutunun İÇİNE
     # girdi) araya bir sarmalayıcı `View` ve stilleri eklendi; iki çapa
     # arasındaki KOD 700 karakteri geçti ve nöbetçi DOĞRU işi kırmızı
     # yaktı. Yorumlar zaten ayıklanıyor, yani bu şişme gerçek koddan.
     #
     # 🆕 SINIF: "MESAFEYLE KANIT TOPLAYAN BİR DENETİM, ARAYA GİREN HER
     # MEŞRU SATIRDA BİRAZ DAHA YANLIŞ ALARM ÜRETİR — PENCEREYİ YAPININ
     # BÜYÜKLÜĞÜNE GÖRE SEÇ, BUGÜNKÜ SATIR SAYISINA GÖRE DEĞİL."
     # Ölçtüm: aradaki gerçek kod 2063 karakter. Pencere 2400 —
     # araya BAŞKA bir bölüm girerse (örn. bir banner) yine yakalar.
     "ekranlar_yalin.js", r"cipler\.map[\s\S]{0,2400}?placeholder=\{t\.typeMsg\}",
     "`.cipler` ile `.yazma` kardeş ve ikisi de alta yapışık"),

    ("sabit şerit başlıkta",
     r"\.sabit-serit\{",
     "ekranlar_yalin.js", r"sabit şerit|geriSayim\(av\.avail_date",
     "sohbetin bağlamı kaymaz — `ScrollView`ın DIŞINDA"),

    ("kart-alt: sayaç + düğme aynı satırda",
     r"\.kart-alt\{display:flex",
     "ekranlar_ana.js", r"<Sayac veri=\{geriSayim",
     "kartın son satırı: solda sayaç, sağda altın düğme"),

    ("rozet hap yarıçapında",
     r"\.roz\{[^}]*border-radius:999px",
     "ortak.js", r"roz: \{[^}]*borderRadius: R\.full",
     "kart içi etiket hap; kart değil"),

    ("uyum sayısı mono",
     r"\.uyum b\{[^}]*JetBrains Mono",
     "ekranlar_ana.js", r"fontFamily: MONO\[600\][\s\S]{0,120}?\{ms\}",
     "kartlar arası karşılaştırılan sayı tek genişlikte"),

    ("cüzdan sayıları mono",
     r"\.cuzdan b\{[^}]*JetBrains Mono",
     "../src/ui.js", r"fontFamily: MONO\[600\][\s\S]{0,300}?\{String\(h\.deger\)\}",   # 5 Eylül: şerit `CuzdanSeridi`ye taşındı
     "kredi/puan/güven değişiyor — orantılı fontta satır oynar"),

    ("sy-sira sayıları mono",
     r"\.sy b\{[^}]*JetBrains Mono",
     "ekranlar_ana.js", r"fontFamily: MONO\[500\][\s\S]{0,100}?\{n\}",
     "dört kutu yan yana; merkezleri hizalı kalmalı"),

    ("üst bilgi altın",
     r"\.dugum\{[^}]*color:var\(--altin\)",
     "ui.js", r"letterSpacing: 2\.4[\s\S]{0,120}?color: C\.gold",
     "düğüm noktası markanın rengiyle işaretleniyor"),

    # 🔴 26 EYLÜL · v6.1 — İDDİA BİLEREK DEĞİŞTİ. Gökberk önce/sonra
    # önizlemesini (uygulama_basliklari_once_sonra.jpg) onayladı: ekran
    # başlıkları artık Cormorant SemiBold. Tasarım dosyasındaki `.ust-h1`
    # sans kuralı bu kararla geçersiz; kanıt artık bant başlığının SERİF
    # olduğu. Gövde/düğme/sayı sans-mono kalıyor (başka iddialar ölçüyor).
    ("başlık serif (v6.1 onay)",
     r"\.ust-h1\{",
     "ui.js", r"fontSize: FS\.bant \+ 4[\s\S]{0,160}?fontFamily: F\.serifGosterim",
     "ekran başlıkları serif — önizleme onaylı (26 Eylül)"),

    ("isim serif-ince",
     r"\.ust-h1\.serif\{[^}]*Cormorant",
     # 🔴 3 EYLÜL — KANIT YERİ DEĞİŞTİ: isim artık `FotoBant`ın
     # `serifBaslik` yuvasında (src/ui.js); App.js yalnız veriyi veriyor.
     "ui.js", r"fontFamily: F\.serifGosterim[\s\S]{0,300}?serifBaslik",
     # 🔴 31 AĞU · 10. TUR — KANIT ADI DEĞİŞTİ, İDDİA DEĞİL.
     # `F.serifLight` (300) → `F.serifGosterim` (600). Sebep theme.js'te
     # yazılı: onaylanan tasarım referansı Cormorant DEĞİL, tarayıcının
     # yedek serifiyle çizilmiş ve Gökberk o kalınlığı seçti. İddia
     # ("gösterim başlığı serif") aynen duruyor.
     "sistemdeki tek serif kullanımı: ana sayfadaki İSİM"),

    ("an başlığı serif-ince",
     r"\.an-h1\{[^}]*Cormorant",
     "MomentScreen.js", r"fontFamily: F\.serifGosterim",
     "`an` ekranının tek cümlesi"),

    ("avatar serif baş harf",
     r"\.avatar\{[^}]*Cormorant",
     "ekranlar_ana.js", r"fontFamily: F\.serif[\s\S]{0,140}?charAt\(0\)",
     "avatar harfi serif — insanın ailesi"),

    ("kalkan avatara değiyor",
     r"\.kalkan\{position:absolute;right:-3px;bottom:-3px",
     "ekranlar_ana.js", r'position: "absolute", right: -3, bottom: -3',
     "doğrulama işareti kişinin yüzüne değer, ayrı satırda durmaz"),

    ("sekme göstergesi ikonun üstünde",
     r"\.tb-ind\{[^}]*top:-7px",
     "../App.js", r"width: 22, height: 3[\s\S]{0,120}?backgroundColor: on \? C\.gold",
     "renk tek kanal; konum ikinci kanal"),

    ("dairesel eylem düğmesi",
     r"\.ust-eylem\{width:38px;height:38px",
     "ui.js", r"daire \? 38 :",
     "`.ust-eylem` bir bileşen, üç yerde geçiyor"),

    ("altın düğme kalan genişliği kaplar",
     r"\.btn-altin\{flex:1",
     "ekranlar_ana.js", r"flex: 1, marginLeft: SP\[3\]",
     "kartın tek asıl eylemi en geniş dokunma alanı"),

    ("sayaç mono",
     r"\.sayac b\{[^}]*JetBrains Mono",
     "ortak.js", r"fontFamily: MONO\[500\][\s\S]{0,120}?veri\.metin",
     "her dakika değişen sayı"),

    ("mesh başlık koyu taban",
     r"\.ust\.mesh\{background:",
     "ui.js", r"MESH_BANT|C\.meshUst",
     "zemin koyu; fotoğraf yalnız doku"),

    ("kural başlığında marka ortada",
     r'class="marka">LOUNGELINK</div><div style="width:20px"',
     "ekranlar_ana.js", r'textAlign: "center"[\s\S]{0,140}?LOUNGELINK',
     "tam ekran katmanda marka görünür ve ortada"),

    ("kendi balonum altın TİNT",
     r"\.bal\.ben\{[^}]*linear-gradient\(180deg,rgba\(224,190,122,\.17\)",
     # `C.goldSoft` → `C.balonBen`: tasarımın degradesinin ORTASI ölçülerek
     # tek renge indirildi (bkz. theme.js). İddia değişmedi — "dolu altın
     # değil tint" — ama kanıtın adı değişti.
     # 🔴 25 EYLÜL · v6.0.0 — İDDİA BİLEREK DEĞİŞTİ. Gökberk'in v6 brief'i:
     # "host balonları dumanlı cam, misafir balonları mat şampanya." Tint
     # kararı geri çevrildi; kanıt artık iki malzemenin kurulmuş olması.
     # Şampanya MAT (gradyansız) — asıl eylemin parlaklığı düğmede kalıyor.
     "ekranlar_yalin.js", r"hostMu[\s\S]{0,400}?DumanliCam[\s\S]{0,200}?backgroundColor: C\.goldBtn",
     "v6: host dumanlı cam, misafir mat şampanya — iki malzeme, çizgi yok"),

    ("balon saati mono ve içeride",
     r"\.bal time\{[^}]*JetBrains Mono",
     "ekranlar_yalin.js", r"fontFamily: MONO\[500\][\s\S]{0,200}?toLocaleTimeString",
     "saat balonun içinde, tek genişlikte"),

    ("fotoğraf %16 doku",
     r"\.ust\.mesh::after\{[^}]*opacity:\.16",
     "ui.js", r"opacity: 0\.16",
     "fotoğraf zemin değil doku"),
]


def main():
    print("=" * 74)
    print("TASARIM YAPISI — İDDİA / KANIT")
    print("=" * 74)
    css = oku(TASARIM_D, "css.py") + "\n" + oku(TASARIM_D, "gen.py")
    bulgu, tamam, atlanan = [], 0, []

    for ad, css_kalip, dosya, kod_kalip, aciklama in IDDIALAR:
        if not re.search(css_kalip, css, re.S):
            atlanan.append((ad, "tasarımda bu kural bulunamadı"))
            continue
        yol = os.path.normpath(os.path.join(SRC, dosya))
        if not os.path.exists(yol):
            atlanan.append((ad, "dosya yok: " + dosya))
            continue
        if re.search(kod_kalip, kod(oku(yol)), re.S):
            tamam += 1
            print("  ✓ %-34s %s" % (ad, aciklama))
        else:
            bulgu.append((ad, dosya, aciklama))

    if atlanan:
        print("\n  ⚠ ÖLÇÜLEMEYEN (%d):" % len(atlanan))
        for ad, n in atlanan:
            print("      %-32s %s" % (ad, n))

    if bulgu:
        print("\n  ✗ TASARIMDA VAR, UYGULAMADA KANITI YOK (%d):" % len(bulgu))
        for ad, d, a in bulgu:
            print("      %-32s → %s" % (ad, d))
            print("        %s" % a)
        print("\n  Bu denetim PİKSEL ölçmez; 'yapı kurulmuş mu' der.")
        return 1

    print("\n✓ %d yapı iddiasının hepsinin uygulamada karşılığı var." % tamam)
    print("  ⚠ Bu denetim piksel ölçmez — cihazda görmenin yerini tutmaz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
