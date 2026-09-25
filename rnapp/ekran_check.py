#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ekran_check.py — PAZARLAMA EKRANI ÜRÜNÜN SÖYLEDİĞİNİ Mİ SÖYLÜYOR?

🔴 NEDEN VAR
`ekran_uret.py` ürünün ekranlarını çiziyor ve metinleri `i18n.js`ten
alıyor. Ama bir satır elle yazmak çok kolay: bir başlık uydurursun,
görsel güzel olur, ve ürün o cümleyi HİÇBİR ZAMAN söylemez. Sonra o
görsel Instagram'a çıkar ve indiren kullanıcı ekranı bulamaz.

Bu, `kural_uyum_check.py`nin öğrettiği hatanın kardeşi: orada vitrin
motoru yalanlıyordu, burada vitrin ARAYÜZÜ yalanlar.

🆕 SINIF: "PAZARLAMA GÖRSELİNDEKİ HER CÜMLE BİR VAATTİR — ÜRÜNÜN
SÖZLÜĞÜNDE KARŞILIĞI YOKSA, İNDİREN KULLANICI ONU ARAYACAK VE
BULAMAYACAK."

NASIL ÇALIŞIR
1 · ÇIKTI — beklenen 14 PNG var mı, ölçüsü doğru mu
2 · GLİF   — `mockup.metin` kapsam kapısı yerinde mi (mutasyonla)
3 · METİN  — `ekran_uret.py`de çizilen her düz yazı ya `i18n.js`te
             geçer, ya `SERBEST` listesinde GEREKÇESİYLE kayıtlıdır
4 · KONTRAST — rozet tonlarının bandrol/çip zeminlerinde AA (4.5:1)

TAVAN 0.
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)

CIKTI = os.path.join(KOK, "ekranlar_render")
# 🔴 30 AĞUSTOS · 5. TUR — LİSTE ARTIK ELLE YAZILMIYOR.
#
# Üreticiye üç yeni ekran ekledim (tanıtım · giriş · kayıt) ve bu
# denetim onları HİÇ GÖRMEDİ: burada elle yazılmış 14 adlık bir liste
# vardı ve "✓ 14 ekran" diyordu. Yani ürün büyüdü, denetim büyümedi —
# ve büyümediğini kimse fark etmedi çünkü yeşil yanmaya devam etti.
#
# 🆕 SINIF: **"DENETİMİN KAPSAMINI ELLE YAZARSAN, KAPSAM ÜRÜNÜN DEĞİL
# SENİN HAFIZANIN SINIRINDA KALIR — VE UNUTULAN HER YENİ PARÇA, HİÇ
# DENETLENMEMİŞ OLDUĞU HÂLDE DENETLENMİŞ SAYILIR."**
#
# Artık üreticinin kendi `EKRANLAR` listesinden okunuyor.
def _beklenen():
    import ast
    g = open(os.path.join(KOK, "ekran_uret.py"), encoding="utf-8").read()
    m = re.search(r"^EKRANLAR = (\[.*?^\])", g, re.S | re.M)
    if not m:
        raise SystemExit("ekran_uret.py içinde EKRANLAR listesi bulunamadı")
    out = []
    for el in ast.parse(m.group(1), mode="eval").body.elts:
        out.append(el.elts[0].value)
    return out


BEKLENEN = _beklenen()

# Ürün sözlüğünde OLMAYAN ama bilerek çizilen metinler. Her biri
# GEREKÇELİ — gerekçesiz giriş eklemek, bu denetimi kapatmaktır.
SERBEST = {
    "LOUNGELINK": "marka adı — çeviri konusu değil",
    "KURAL MOTORU": "bölüm etiketi; ürün içinde de aynı ifade kullanılıyor",
    "HOST'UN KARTI": "bölüm etiketi",
    "MOTORUN KONTROLLERİ": "bölüm etiketi",
    "HIZLI DURUM": "bölüm etiketi (canlı durum çipleri)",
    "Program": "tablo satır adı",
    "Aynı terminal": "kural kontrolü adı — motorun same_terminal kuralı",
    "Havayolu şartı": "kural kontrolü adı — guest_flight_coupling",
    "Kabin şartı": "kural kontrolü adı — cabin_requirement",
    "Kapasite": "kural kontrolü adı — guest_included_count",
    "Priority Pass": "program adı",
    "· PRIORITY PASS": "program adı (kural kutusu başlığı)",
    "DragonPass olsaydı: misafirin": "karşılaştırma cümlesi (bkz. aşağıdaki not)",
    "seninle aynı uçuşta olmalıydı.": "DragonPass md.7.15.7 — motorla birebir",
    "Güvenilir Host · Kademe 2": "örnek veri",
    "Gökberk": "örnek veri — ana sayfadaki isim (tasarımdaki `.ust-h1.serif`)",
    "Esenboğa · 14 gün": "örnek veri — BUGÜN kartının başlığı",
    "E-posta": "doğrulama satır adı",
    "TAV Primeclass · IST": "örnek veri",
    "TK1979 · 16:40": "örnek veri",
    "Merhaba! Primeclass girişinde buluşalım mı?": "örnek sohbet metni",
    "Olur, güvenlikten yeni geçtim — 5 dakikaya oradayım.": "örnek sohbet metni",
    "SELİN B. · İSTANBUL": "örnek veri",
    "Deniz K.": "örnek veri", "Mert A.": "örnek veri", "Selin B.": "örnek veri",
    "Kaan T.": "örnek veri", "Ece Y.": "örnek veri",
    "IST · TAV Primeclass": "örnek veri", "SAW · Comfort Lounge": "örnek veri",
    "TK1979 · IST → AMS": "örnek veri", "Primeclass · 2 saat": "örnek veri",
    "IST → LHR · 18:05": "örnek veri",
    "14:20 – 16:40": "örnek veri", "09:00 – 11:30": "örnek veri",
    "14:02": "örnek veri", "14:04": "örnek veri", "14:09": "örnek veri",
    "Salon": "filtre çipi", "Rota": "filtre çipi",
    "+1": "marka çerçevesi — bkz. `tanitim_uret.py`",
    "→": "yön oku", "✓": "onay işareti", "%94": "örnek veri", "%71": "örnek veri",
    "1 misafir": "örnek veri", "yok": "kural değeri", "1/1": "örnek veri",
    "4.9": "örnek veri", "1.240": "örnek veri", "38 dk": "örnek veri",
    "+120": "örnek veri", "9": "örnek veri", "4": "örnek veri", "2": "örnek veri",
    "1": "örnek veri", "D": "avatar harfi", "S": "avatar harfi",
    "M": "avatar harfi", "K": "avatar harfi", "E": "avatar harfi",
    "3": "örnek veri", "94": "örnek veri", "Deniz": "örnek veri",
    "…": "kırpma işareti",
    "6": "örnek veri", "· 2": "örnek veri (ayraç + sayı)",
    "Priority Pass ·": "program adı + ayraç; devamı i18n'den (`noFlightCond`)",
    # 🔴 30 Ağu · 7. tur — YENİ FİKSTÜR METİNLERİ.
    # Üçü de örnek VERİ: üründe sunucudan gelir, i18n'de karşılığı
    # olmaz ve olmamalı. Buraya yazılmalarının sebebi denetimi
    # susturmak değil, "bu bir çeviri değil bir örnek" demek.
    "Kapı A12 önü": "örnek buluşma noktası (sohbet şeridi)",
    # 31 Ağu · 8. tur — sohbet başlığına geri oku eklenince alt satır
    # yeniden konumlandı; salon + kapı örnek VERİ, çeviri değil.
    "TAV Primeclass · Kapı A12": "örnek salon + kapı (sohbet başlığı)",
    "Ürün Yönetimi": "örnek meslek (profil)",
    "• Doğrulanmış · 64": "örnek rozet + güven puanı (profil)",
}

CIZEN = ("metin", "golgeli", "cip", "dugme", "hayalet", "bandrol", "balon",
         "baslik", "satir")


def yazilar():
    """
    `ekran_uret.py`de ÇİZİLEN düz yazı sabitlerini toplar.

    🔴 İLK HÂLİM REGEX'Tİ VE ÇÖPLÜK ÜRETTİ: `metin(` görüp parantez
    sayıyordu, ama argümanların içinde `e.P["bg"]` gibi tırnaklı,
    parantezli ifadeler var — eşleşme kaydı yarım cümlelerle doldu ve
    38 sahte bulgu çıktı. Sahte bulgu, bulgusuzluktan beterdir: denetimi
    kimse okumaz olur.

    🆕 SINIF (yine): "KAYNAK KODU REGEX'LE AYRIŞTIRMA — DİLİN KENDİ
    AYRIŞTIRICISI VARSA ONU KULLAN." (`ast`)
    """
    import ast
    g = open(os.path.join(KOK, "ekran_uret.py"), encoding="utf-8").read()
    agac = ast.parse(g)
    bulunan = set()

    def ad_of(node):
        f = node.func
        if isinstance(f, ast.Name):
            return f.id
        if isinstance(f, ast.Attribute):
            return f.attr
        return None

    class Z(ast.NodeVisitor):
        def visit_Call(self, node):
            if ad_of(node) in CIZEN:
                # 🔴 30 Ağu · 4. tur — `kaynak=` ÇİZİLMİYOR, TEŞHİS İÇİN.
                # Taşma kapısına hangi öğenin taştığını söyleyen bir
                # etiket ekledim (`kaynak="cüzdan etiketi"`); bu denetim
                # onu EKRANA ÇİZİLEN metin sandı. Anahtar argümanların
                # hepsini metin saymak, bileşenin imzasını bilmemek
                # demek.
                atla = {"kaynak", "a11y", "ad", "kod"}
                for a in (list(node.args)
                          + [k.value for k in node.keywords if k.arg not in atla]):
                    for alt in ast.walk(a):
                        # t("anahtar") ürünün sözlüğünden gelir — atla
                        if isinstance(alt, ast.Call) and ad_of(alt) == "t":
                            continue
                        if isinstance(alt, ast.Constant) and isinstance(alt.value, str):
                            if _kapsayan_t(a, alt):
                                continue
                            s = alt.value.strip()
                            # renk sabiti metin değil (fotoğraf üstü beyaz
                            # mürekkep `ui.js`teki `FotoBant` ile aynı)
                            if s.startswith("#") or s.startswith("%02"):
                                continue
                            if s and not re.fullmatch(r"[a-zA-Z_][a-zA-Z_0-9]*", s):
                                bulunan.add(s)
                            elif s and s in ("D", "S", "M", "K", "E"):
                                bulunan.add(s)
            self.generic_visit(node)

    def _kapsayan_t(kok, hedef):
        """Sabit bir `t("...")` çağrısının içinde mi (anahtar/yedek)?"""
        for n in ast.walk(kok):
            if isinstance(n, ast.Call) and ad_of(n) == "t":
                for m in ast.walk(n):
                    if m is hedef:
                        return True
        return False

    Z().visit(agac)
    return bulunan


def main():
    import mockup
    from tema_oku import oran, palet, rozet, uzerine
    kotu = []
    print("=" * 78)
    print("EKRAN RENDER DENETİMİ — pazarlama görseli ürünü doğru anlatıyor mu?")
    print("=" * 78)

    print("\n  1 · ÇIKTI")
    for ad in BEKLENEN:
        y = os.path.join(CIKTI, ad + ".png")
        if not os.path.exists(y):
            kotu.append("%s.png yok" % ad)
            print("    ✗ %s — yok" % ad)
            continue
        from PIL import Image
        w, h = Image.open(y).size
        ok = (w, h) == (mockup.G, mockup.Y)
        if not ok:
            kotu.append("%s ölçüsü %dx%d (beklenen %dx%d)"
                        % (ad, w, h, mockup.G, mockup.Y))
        print("    %s %-16s %dx%d" % ("✓" if ok else "✗", ad, w, h))

    print("\n  2 · GLİF KAPISI (mutasyon)")
    e = mockup.Ekran("C")
    try:
        e.metin((0, 0), "🎉", mockup.f(mockup.BOLD, 12), "#000000")
        kotu.append("glif kapısı tofu'yu geçirdi")
        print("    ✗ kapı açık — tofu çizilebiliyor")
    except ValueError:
        print("    ✓ kapsanmayan glif çizilmeye kalkışılınca istisna fırlıyor")
    try:
        e.metin((0, 0), "Oturum", mockup.f(mockup.BOLD, 12), "#000000")
        print("    ✓ kapsanan metin sorunsuz (yanlış alarm yok)")
    except ValueError:
        kotu.append("glif kapısı yanlış alarm veriyor")
        print("    ✗ yanlış alarm")

    print("\n  3 · ÇİZİLEN METİN ÜRÜNÜN SÖZLÜĞÜNDE Mİ")
    S = set(mockup.sozluk("tr").values()) | set(mockup.sozluk("en").values())
    parcali = set()
    for v in list(S):
        for p in re.split(r"\s·\s|\s—\s", v):
            parcali.add(p.strip())
    S |= parcali
    kayitsiz = []
    for s in sorted(yazilar()):
        if s in SERBEST or s in S:
            continue
        # i18n değerinin kırpılmış hâli mi ("…" ile biten)
        c = s.rstrip("…").strip()
        if c and any(v.startswith(c) for v in S):
            continue
        kayitsiz.append(s)
    print("      çizilen sabit : %d · sözlükte/kayıtta : %d · KAYITSIZ : %d"
          % (len(yazilar()), len(yazilar()) - len(kayitsiz), len(kayitsiz)))
    for s in kayitsiz:
        kotu.append("kayıtsız pazarlama metni: %r" % s)
        print("    ✗ %r — ürünün sözlüğünde yok, SERBEST'te de kayıtlı değil" % s)
    if not kayitsiz:
        print("    ✓ her cümlenin ya i18n'de karşılığı var ya SERBEST'te gerekçesi")

    print("\n  4 · ROZET TONU KONTRASTI (bandrol %8 tint · çip bgAlt)")
    for kap in ("C", "KOYU"):
        P = dict(palet("C"))
        if kap == "KOYU":
            P.update(palet("KOYU"))
        R = rozet(kap)
        en_kotu = 99.0
        for ad, h in R.items():
            for zemin in (uzerine(P["bg"], h, 20 / 255.0), P["bgAlt"]):
                en_kotu = min(en_kotu, oran(h, zemin))
        ok = en_kotu >= 4.5
        if not ok:
            kotu.append("%s rozet kontrastı %.2f < 4.5" % (kap, en_kotu))
        print("    %s %-5s en kötü %.2f:1" % ("✓" if ok else "✗", kap, en_kotu))

    print()
    if kotu:
        print("🔴 %d BULGU." % len(kotu))
        for k in kotu:
            print("   · %s" % k)
        return 1
    print("✓ %d ekran" % len(BEKLENEN) + "  · glif kapısı canlı · çizilen her cümle kayıtlı · AA geçti")
    return 0


if __name__ == "__main__":
    sys.exit(main())
