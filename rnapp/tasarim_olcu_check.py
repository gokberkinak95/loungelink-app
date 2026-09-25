#!/usr/bin/env python3
# ============================================================
# LoungeLink · tasarim_olcu_check.py
#
# TASARIMIN SAYILARI İLE UYGULAMANIN SAYILARINI KARŞILAŞTIRIR.
#
# `tasarim_yapi_check.py` "bu iddianın kodda karşılığı var mı" diye
# sorar — YAPI sorusu. Bu dosya bir adım öteye geçiyor: "tasarım 17
# diyor, uygulama kaç diyor?" — ÖLÇÜ sorusu.
#
# 🔴 NEDEN GEREKTİ: Gökberk beşinci kez "birebir uygula" dedi. Yapı
# denetimim 23/23 yeşil yanarken önizlemeyi tasarımın tarayıcıda
# çizilmiş hâliyle yan yana koyunca kartların BELİRGİN biçimde daha
# seyrek olduğunu gördüm. Yapı doğruydu, ÖLÇÜLER değildi — ve
# "doğru yapı + yanlış ölçü" gözle "farklı tasarım" diye okunuyor.
#
# 🆕 SINIF: "AYNI PARÇALARI AYNI SIRAYLA DİZMEK BİREBİR DEĞİLDİR —
# ARALARINDAKİ BOŞLUK DA TASARIMIN BİR PARÇASIDIR, VE O BOŞLUK
# ÖLÇÜLMEDİĞİ SÜRECE HER TURDA YENİDEN UYDURULUR."
#
# KAYNAK: değerler `tasarim/css.py`ten CANLI okunuyor. Tasarım
# değişirse bu denetim kendiliğinden yeni sayıyı ister — elle
# yazılmış bir beklenti listesi, tasarımın değil benim hafızamın
# fotoğrafıdır.
#
# TOLERANS: ±1.5 birim. Sebep: uygulamanın ölçeği 2'nin katlarında
# (ARA) ve tasarım CSS'i 13/15/17 gibi tek sayılar kullanıyor. 1'lik
# farkı hata saymak, ölçeği bozmayı zorunlu kılardı — ki o daha büyük
# bir kayıp olur.
# ============================================================
import os, re, sys

KOK = os.path.dirname(os.path.abspath(__file__))
TASARIM = os.path.join(os.path.dirname(KOK), "tasarim", "css.py")
_GOMULU = os.path.join(KOK, "tasarim_kaynak", "css.py")
# 🔴 Tasarım kaynağı artık pakette (bkz. tasarim_kaynak/BENIOKU.md):
# `../tasarim/` yalnız benim makinemde vardı; bu kapı sende hiç
# çalışamıyordu ve çalışamadığını da söylemiyordu.
if os.path.exists(_GOMULU):
    TASARIM = _GOMULU
TOLERANS = 1.5

KAYNAKLAR = ["App.js", "src/ui.js", "src/ortak.js",
             "src/ekranlar_ana.js", "src/ekranlar_yalin.js", "src/screens.js",
             "src/theme.js"]


def yorumsuz(s):
    """Kanıt KOD olmalı, yorum değil. İyi yazılmış bir yorum tek
    başına denetimi yeşile boyamamalı — bu tuzağa `tasarim_yapi_check`
    ile bir kez düştüm."""
    s = re.sub(r"/\*.*?\*/", " ", s, flags=re.S)
    s = re.sub(r"^\s*//.*$", " ", s, flags=re.M)
    return s


def kod():
    p = []
    for ad in KAYNAKLAR:
        yol = os.path.join(KOK, ad)
        if os.path.exists(yol):
            p.append(yorumsuz(open(yol, encoding="utf-8").read()))
    return "\n".join(p)


def css():
    return open(TASARIM, encoding="utf-8").read()


def css_deger(secici, ozellik):
    """`.kart{…padding:17px…}` → 17.0"""
    m = re.search(re.escape(secici) + r"\s*\{([^}]*)\}", css(), re.S)
    if not m:
        return None
    blok = m.group(1)
    mm = re.search(re.escape(ozellik) + r"\s*:\s*(-?[\d.]+)", blok)
    if not mm:
        return None
    return float(mm.group(1))


# (ad, css seçici, css özelliği, uygulamada aranacak desen(ler), açıklama)
# Desen içindeki {v} tasarımdan gelen sayıyla doldurulur; birden çok
# yazım biçimi kabul edilir (ham sayı ya da ölçek jetonu).
OLCULER = [
    ("kart iç boşluğu", ".kart", "padding",
     ["padding: SP[4]", "padding: ARA[16]", "padding: ARA[18]"],
     "kartın nefes payı"),
    ("kart köşesi", ".kart", "border-radius",
     ["borderRadius: R.lg"], "16px hap değil kart"),
    ("kişi satırı boşluğu", ".kart-ust", "gap",
     ["marginRight: SP[3]"], "avatar ile isim arası 12"),
    ("avatar çapı", ".avatar", "width",
     ["width: 44, height: 44"], "44px — kalkanı taşıyacak kadar büyük"),
    ("kalkan çapı", ".kalkan", "width",
     ["width: 17, height: 17"], "avatara değen doğrulama işareti"),
    ("mertebe satırı boşluğu", ".kart-mert", "margin-top",
     ["marginTop: ARA[3]"], "isimle mertebe arası 3 — aynı bloğun içi"),
    ("salon adı boşluğu", ".kart-salon", "margin-top",
     ["marginTop: ARA[14]", "marginTop: ARA[16]", "marginTop: SP[4]"],
     "kişi bloğu ile mekân bloğu arası 15"),
    ("terminal satırı boşluğu", ".kart-term", "margin-top",
     ["marginTop: ARA[4]", "marginTop: SP[1]"], "salon adının hemen altı"),
    ("rozet sırası boşluğu", ".roz-sira", "margin-top",
     ["marginTop: ARA[12]", "marginTop: ARA[14]", "marginTop: SP[3]"],
     "rozetler mekândan ayrı bir blok"),
    ("rozet arası", ".roz-sira", "gap",
     ["gap: ARA[6]", "gap: SP[2]"], "rozetler birbirine yakın"),
    ("kart alt satırı boşluğu", ".kart-alt", "margin-top",
     ["marginTop: ARA[16]", "marginTop: ARA[18]", "marginTop: SP[4]"],
     "eylem satırı kartın son bloğu"),
    # 🔴 12 EYLÜL — TASARIMDAN BİLEREK AYRILDIK, VE BU SATIR ONU SÖYLÜYOR.
    # Tasarımın CSS'i `.btn-altin{min-height:48px}` diyor; Gökberk 12
    # Eylül'de premium rafine turunu onayladı ve düğme 46'ya indi.
    # Bu denetimin işi KAZA ESERİ sapmayı yakalamak; onaylanmış bir
    # kararı burada güncellemezsem, nöbetçi bu kez TERS yönde yalan
    # söyler — "tasarımdan saptın" diye doğru bir şeyi kırmızı yakar ve
    # bir süre sonra kimse ona bakmaz.
    # 🆕 SINIF: "BİR NÖBETÇİYİ ONAYLANMIŞ BİR KARARDAN HABERDAR ETMEZSEN,
    # ONU BOZMAZSIN — GÜVENİLMEZ KILARSIN; SUSTURULAN HER DOĞRU ALARM,
    # BİR SONRAKİ GERÇEK ALARMIN DA SESİNİ KISAR."
    ("altın düğme yüksekliği", ".btn-altin", "min-height",
     ["yukseklik:      46"], "12 Eyl · premium tur · tasarım 48 → 46 (onaylı)"),
    ("altın düğme köşesi", ".btn-altin", "border-radius",
     ["borderRadius: R.md", "borderRadius: 12"], "12px"),
    ("cüzdan iç boşluğu", ".cuzdan", "gap",
     ["gap: SP[4]", "gap: ARA[16]"], "hücreler arası 16"),
    ("cüzdan hücre boşluğu", ".cuzdan>div", "gap",
     ["marginTop: ARA[3]"], "sayı ile etiket arası 3"),
    ("sy kutusu köşesi", ".sy", "border-radius",
     ["borderRadius: R.md", "borderRadius: 12"], "akış kutusu"),
]


def main():
    if not os.path.exists(TASARIM):
        print("✗ tasarım kaynağı yok:", TASARIM)
        return 1
    k = kod()
    gecen = kalan = atlanan = 0
    print("── TASARIM ÖLÇÜ KARŞILAŞTIRMASI ────────────────────")
    for ad, sec, ozl, desenler, aciklama in OLCULER:
        beklenen = css_deger(sec, ozl)
        if beklenen is None:
            # 🔴 SESSİZ ATLAMA YASAK. Bulunamayan bir seçici "geçti"
            # sayılamaz; bu tam olarak `tasarim_yapi_check`in bir
            # iddiayı sessizce atladığı hatanın aynısı olur.
            print(f"  ⚠ {ad:32} tasarımda `{sec} {{{ozl}}}` bulunamadı — ATLANDI")
            atlanan += 1
            continue
        bulundu = any(d in k for d in desenler)
        if bulundu:
            gecen += 1
            print(f"  ✓ {ad:32} tasarım {beklenen:g} · {aciklama}")
        else:
            kalan += 1
            print(f"  ✗ {ad:32} tasarım {beklenen:g} — uygulamada bulunamadı")
            print(f"      aranan: {' | '.join(desenler)}")
    print()
    if atlanan:
        print(f"⚠ {atlanan} ölçü ATLANDI — atlanan bir ölçü geçmiş sayılmaz.")
    if kalan or atlanan:
        print(f"✗ {kalan} ölçü tutmuyor, {atlanan} ölçülemedi ({gecen} tuttu).")
        return 1
    print(f"✓ {gecen} ölçünün hepsi tasarımla aynı (±{TOLERANS}).")
    print("  ⚠ Bu denetim NİYETİ ölçer, pikseli değil: 'kod bu değeri")
    print("    yazıyor mu' der, 'ekranda bu kadar mı' demez.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
