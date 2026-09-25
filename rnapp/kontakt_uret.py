#!/usr/bin/env python3
# ============================================================
# LoungeLink · kontakt_uret.py
#
# 17 ÖNİZLEME KARESİNİ TEK SAYFAYA DİZER (teslim/gece_tum_ekranlar.png)
#
# 🔴 NEDEN AYRI BİR DOSYA: bu iş bugüne kadar her turda YENİDEN
# yazılan tek kullanımlık bir betikti ve son turda iki hatayı birden
# yaptı:
#
#   1) EKRAN ADLARINI YORUMDAN OKUDU. `EKRANLAR` listesinin içindeki
#      bir AÇIKLAMA satırında `("10_kesfet_acik", kesfet("C"))` yazıyordu
#      — yani ARTIK ÜRETİLMEYEN bir ekranın adı. Regex yorumu koddan
#      ayırt edemedi ve o adı listeye aldı.
#   2) DİSKTEKİ BAYAT PNG'Yİ BULDU. Dosya bir önceki turdan kalmıştı,
#      silinmemişti. Ad + dosya bir araya gelince açık temalı Keşfet
#      kontakt sayfasına GERİ DÖNDÜ.
#
# Gökberk onu gördü ve haklı olarak sordu: "10_kesfet_acik hâlâ beyaz
# bir temada, bu neden mevcut temaya göre ayarlanmıyor?" — cevabı
# "ayarlanmıyor" değil, "artık üretilmiyor ama sayfaya giriyor"du.
#
# 🆕 SINIF: "İKİ AYRI ZARARSIZ HATA — BİR YORUMU KOD SANMAK VE BİR
# ÇIKTIYI TEMİZLEMEMEK — ÜST ÜSTE GELDİĞİNDE, SİLİNMİŞ BİR ÖZELLİĞİ
# CANLIYMIŞ GİBİ GÖSTERİR."
#
# Bu dosya ikisini de kapatıyor:
#   · adlar AST ile okunuyor (yorumları Python'un kendisi atıyor)
#   · listede olmayan her PNG önce ARŞİVE taşınıyor, sonra dizim
# ============================================================
import ast, os, shutil, sys
from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.abspath(__file__))
URETICI = os.path.join(KOK, "ekran_uret.py")
RENDER = os.path.join(KOK, "ekranlar_render")
ARSIV = os.path.join(KOK, "arsiv", "onizleme_eski")
FONT = os.path.join(KOK, "assets", "fonts", "PlusJakartaSans-SemiBold.ttf")
CIKTI = os.path.join(os.path.dirname(KOK), "teslim", "gece_tum_ekranlar.png")

KOL = 6
BOY = 560
BOS = 18
ETI = 26


def ekran_adlari():
    """`EKRANLAR` listesini AST ile okur.

    ⚠️ REGEX KULLANILMIYOR. Regex yorumu koddan ayırt edemez; AST
    yorumları hiç görmez. `ekran_check.py` bu dersi bir tur önce
    öğrenmişti, bu betik öğrenmemişti — aynı dersin iki ayrı yerde
    ayrı ayrı öğrenilmesi gerekiyormuş.
    """
    agac = ast.parse(open(URETICI, encoding="utf-8").read())
    for d in agac.body:
        if not isinstance(d, ast.Assign):
            continue
        if not any(getattr(t, "id", None) == "EKRANLAR" for t in d.targets):
            continue
        adlar = []
        for oge in d.value.elts:
            ilk = oge.elts[0]
            if isinstance(ilk, ast.Constant) and isinstance(ilk.value, str):
                adlar.append(ilk.value)
        return adlar
    return []


def bayatlari_arsivle(adlar):
    """Üreticinin listesinde OLMAYAN her PNG arşive taşınır.

    Silinmez (kural: eski dosya silinmez) ama render klasöründe de
    kalmaz — çünkü orada kalırsa bir sonraki betik onu yine bulur.
    """
    if not os.path.isdir(RENDER):
        return []
    beklenen = {a + ".png" for a in adlar}
    tasinan = []
    os.makedirs(ARSIV, exist_ok=True)
    for f in sorted(os.listdir(RENDER)):
        if not f.endswith(".png") or f in beklenen:
            continue
        shutil.move(os.path.join(RENDER, f), os.path.join(ARSIV, f))
        tasinan.append(f)
    return tasinan


def main():
    adlar = ekran_adlari()
    if not adlar:
        print("✗ EKRANLAR listesi okunamadı — kontakt sayfası üretilmedi.")
        return 1
    tasinan = bayatlari_arsivle(adlar)
    for f in tasinan:
        print("  ⚠ bayat kare arşive alındı: %s" % f)

    eksik = [a for a in adlar if not os.path.exists(os.path.join(RENDER, a + ".png"))]
    if eksik:
        print("✗ %d kare üretilmemiş: %s" % (len(eksik), ", ".join(eksik)))
        print("  Önce `python ekran_uret.py` çalıştır.")
        return 1

    ims = [(a, Image.open(os.path.join(RENDER, a + ".png")).convert("RGB")) for a in adlar]
    k = [(a, i.resize((int(i.width * BOY / i.height), BOY))) for a, i in ims]
    W = max(i.width for _, i in k)
    sat = (len(k) + KOL - 1) // KOL
    c = Image.new("RGB", (KOL * (W + BOS) + BOS, sat * (BOY + BOS + ETI) + BOS + 40),
                  (12, 10, 14))
    d = ImageDraw.Draw(c)
    try:
        ft = ImageFont.truetype(FONT, 15)
    except Exception:
        ft = ImageFont.load_default()

    surum = "?"
    try:
        import json
        surum = json.load(open(os.path.join(KOK, "app.json"), encoding="utf-8"))["expo"]["version"]
    except Exception:
        pass
    d.text((BOS, 10), "LoungeLink v%s · %d ekran · gece sistemi (tek tema)"
           % (surum, len(k)), font=ft, fill=(224, 190, 122))
    for i, (a, im) in enumerate(k):
        r, cc = divmod(i, KOL)
        x = BOS + cc * (W + BOS)
        y = 40 + BOS + r * (BOY + BOS + ETI)
        c.paste(im, (x, y))
        d.text((x, y + BOY + 5), a, font=ft, fill=(190, 185, 180))
    os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
    c.save(CIKTI)
    print("✓ %d ekran → %s  %s" % (len(k), CIKTI, c.size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
