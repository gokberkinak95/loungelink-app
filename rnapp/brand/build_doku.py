#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brand/build_doku.py — sayfa zemininin ufuk dokusu (`Ekran.doku`) tek PNG.

Tasarım: zemin DÜZ (`bg`), yalnız ekran boyunun %20'si kadar bir kuşakta
sıcak (`sicak`) bir ufuk izi; şiddet ortada %7, kenarlarda 0 (üçgen).
Uygulamadaki eski `zemin-koyu.png` bütün sayfayı 16→24 parlaklıkla
kademelendiriyordu — tasarımda öyle bir gradyan yok (ölçüldü: tasarım sağ
kenar 16/16/19/24/21/16/16, uygulama 16/17/18/19/22/23/24).

Çıktı: assets/zemin-doku-koyu.png (8×256, opak) — Atmosfer bunu
`top:(ufuk-10)%, height:20%` konumunda `stretch` ile çizer; kuşağın YERİ
ekrana göre değişir (sohbet %20, giriş %34, varsayılan %46 → merkez %56).

══════════════════════════════════════════════════════════════════════════
🔴 12 EYLÜL · GECE — DÖRT KUŞAK. GÜNÜN SAATİNE GÖRE AMBİYANS.

Gökberk'in vizyon listesindeki madde: "günün saatine göre ortam teması".

DOĞRU KATMAN BURASI, PALET DEĞİL. Paleti saate göre kaydırmak, üzerinde
ÖLÇÜLMÜŞ 87 jetonu ve onlarca kontrast oranını saate göre kaydırmak
demekti — yani sabah 07:00'de AA geçen bir metin, 14:00'te geçmeyebilirdi.
Bir tasarım sistemini saate bağlamak, onu ölçülemez kılar.

Değişen tek şey ufuk kuşağının TONU ve ŞİDDETİ:
    şafak   amber    %8.5  — gün doğumu, terminalin doğu cephesi
    gündüz  mutedAA  %5.0  — düz, renksiz, dikkat çekmeyen
    akşam   sicak    %7.0  — mevcut hâl (dosya birebir aynı kalıyor)
    gece    purple   %5.5  — apron ışıklarının soğuk moru

Dördü de aynı üçgen profil, aynı boyut, aynı zemin. Yani ekranın
"iskeleti" saat kaç olursa olsun aynı; değişen yalnız ufkun rengi.

⚠️ DÖRDÜ DE ÖLÇÜLÜYOR. `doku_check.py` artık dört dosyanın HER SATIRINDA
dört mürekkebi ayrı ayrı sınıyor. Şiddeti %8.5'e çıkarabilmemin sebebi
tahmin değil ölçüm: kuşak `bg`den uzaklaştıkça metin kontrastı DÜŞER ve
tavanı ölçüm belirledi.

🆕 SINIF: "BİR SİSTEMİ ZAMANA BAĞLAYACAKSAN, ZAMANA BAĞLANAN KATMANIN
ÖLÇÜLEBİLİRLİĞİNİ BOZMADIĞINI ÖNCE KANITLA — YOKSA ÜRÜNÜN YARISI GÜNÜN
YARISINDA ÖLÇÜLMEMİŞ OLUR."
══════════════════════════════════════════════════════════════════════════
"""
import os, sys
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, KOK)
from PIL import Image
import mockup

# ad → (palet jetonu, tepe şiddeti, dosya adı)
KUSAKLAR = {
    "safak":  ("amber",   0.085, "zemin-doku-safak.png"),
    "gunduz": ("mutedAA", 0.050, "zemin-doku-gunduz.png"),
    "aksam":  ("sicak",   0.070, "zemin-doku-koyu.png"),
    "gece":   ("purple",  0.055, "zemin-doku-gece.png"),
}


def _ciz(yol, zemin, ton, tepe, h=256):
    im = Image.new("RGB", (8, h))
    px = im.load()
    for i in range(h):
        t = i / (h - 1)
        a = tepe * (1 - abs(t - 0.5) * 2)
        c = tuple(round(zemin[k] + (ton[k] - zemin[k]) * a) for k in range(3))
        for x in range(8):
            px[x, i] = c
    im.save(yol, optimize=True)
    return yol


def uret(h=256):
    P = mockup.Ekran().P
    z = mockup.rgb(P["bg"])
    cikti = []
    for ad, (jeton, tepe, dosya) in KUSAKLAR.items():
        renk = P.get(jeton)
        if not renk:
            raise SystemExit("palette jetonu yok: %s" % jeton)
        yol = _ciz(os.path.join(KOK, "assets", dosya), z, mockup.rgb(renk), tepe, h)
        cikti.append((ad, os.path.basename(yol), jeton, renk, tepe))
    return cikti


if __name__ == "__main__":
    for s in uret():
        print("%-7s %-24s %-8s %-8s %.3f" % s)
