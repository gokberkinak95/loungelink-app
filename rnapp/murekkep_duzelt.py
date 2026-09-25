#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
murekkep_duzelt.py — AA'nın altındaki renk çiftlerini doğru tokene çevirir.

🔴 NEDEN BETİK
50 dokunulabilirde metin/zemin oranı AA'nın altında ve hepsi aynı sekiz
çiftin tekrarı. Elle 50 satır düzenlemek hem yorucu hem de yarısını
atlama garantisi. Ama daha önemlisi: sorun 50 satırda DEĞİL, sekiz
çiftte. Çifti düzeltmek 50 satırı düzeltir.

⚠️ SINIRLI VE KASITLI: yalnız BİLİNEN çiftler değişiyor. Bir zemin/metin
ikilisi listede yoksa dokunulmuyor ve raporda görünüyor. "Kalanları da
tahminle düzelttim" yok.

DEĞİŞİM İKİ TÜRLÜ:
  · ZEMİN — beyaz metin taşıyan sinyal rengi, düğme tonuna geçiyor
            (C.gold → C.goldBtn). Metin beyaz kalıyor.
  · MÜREKKEP — renkli tint üstündeki sinyal rengi, mürekkep tonuna
            geçiyor (C.red → C.redInk). Zemin aynı kalıyor.

İkisinin ayrımı önemli: zemini koyulaştırmak düğmeyi ağırlaştırır,
mürekkebi koyulaştırmak yalnız yazıyı okunur yapar. Hangi yüzeyde
hangisinin doğru olduğu, yüzeyin İŞİNE bağlı.
"""
import datetime
import os
import re
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from tema_oku import oran, palet                                   # noqa: E402

P = palet("C")
YEDEK = os.path.join(KOK, "_yedek_murekkep",
                     datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
DOSYA = ["src/screens.js", "src/ekranlar_ana.js", "src/ekranlar_yalin.js",
         "src/ortak.js", "src/ui.js", "src/HostWallet.js", "src/MomentScreen.js",
         "src/ErrorBoundary.js", "src/Pickers.js", "src/FlightField.js", "App.js"]

# (zemin_token, metin_ifadesi, yeni_zemin, yeni_metin)
KURAL = [
    # ── ZEMİN değişimi: beyaz metin taşıyan sinyal renkleri ──
    ("gold",     '"#fff"',    "goldBtn",   None),
    ("gold",     '"#FFF"',    "goldBtn",   None),
    ("gold",     '"#ffffff"', "goldBtn",   None),
    ("teal",     '"#fff"',    "tealBtn",   None),
    ("green",    '"#fff"',    "greenBtn",  None),
    ("amber",    '"#fff"',    "amberBtn",  None),
    ("red",      '"#fff"',    "dangerBtn", None),
    # ── MÜREKKEP değişimi: renkli tint üstündeki sinyal renkleri ──
    ("redBg",    "C.red",     None, "redInk"),
    ("greenBg",  "C.green",   None, "greenInk"),
    ("tealBg",   "C.teal",    None, "tealInk"),
    ("goldBg",   "C.gold",    None, "goldText"),
    ("amberBg",  "C.amber",   None, "amberInk"),
    ("purpleBg", "C.purple",  None, "purpleInk"),
    ("bgAlt",    "C.muted",   None, "mutedAA"),
    ("bgAlt",    "C.mut",     None, "mutedAA"),
    # ── İKİNCİ TUR: nöbetçinin "şüpheli" listesinden doğrulananlar ──
    # Bunlar dış View'da zemin, iç Text'te renk taşıyor; nöbetçi kesin
    # diyemedi, elle bakıldı ve 16'sı GERÇEK çıktı (2'si yanlış alarmdı:
    # beyaz metin iç düğmenin üstündeydi, kartın değil).
    ("bgAlt",    "C.dim",     None, "dimAA"),
    ("bgAlt",    "C.gold",    None, "goldInk"),
    ("bgAlt",    "C.green",   None, "greenBtn"),
    ("card",     "C.gold",    None, "goldText"),
    ("card",     "C.teal",    None, "tealInk"),
    ("surface",  "C.gold",    None, "goldText"),
    ("ink",      "C.purple",  None, "purpleUst"),
    ("tealTint2","C.teal",    None, "tealInk"),   # düğme tokeni mürekkep DEĞİL
    ("tealTint", "C.green",   None, "greenInk"),  # düğme tokeni mürekkep DEĞİL
    ("goldTint", "C.goldDeep",None, "goldInk"),
]

AC = re.compile(r"<(TouchableOpacity|View|Text)\b")


def blok_bul(g, i, etiket):
    kapali = "</%s>" % etiket
    ac = "<%s" % etiket
    d, k = 1, g.index(">", i)
    while k < len(g):
        if g.startswith(kapali, k):
            d -= 1
            if d == 0:
                return k + len(kapali)
            k += len(kapali)
            continue
        if g.startswith(ac, k):
            d += 1
            k += len(ac)
            continue
        k += 1
    return -1


def main():
    os.makedirs(YEDEK, exist_ok=True)
    toplam, rapor = 0, {}
    for rel in DOSYA:
        yol = os.path.join(KOK, rel)
        if not os.path.exists(yol):
            continue
        g = open(yol, encoding="utf-8").read()
        ham = g
        for zem, metin, yeni_zem, yeni_met in KURAL:
            # aynı stil nesnesi ya da aynı bileşen bloğu içinde ikisi birlikte
            desen = re.compile(
                r"(backgroundColor:\s*C\.)" + zem + r"\b(?![A-Za-z])")
            yeni = g
            # blok bazlı: zemin ve metin AYNI 900 karakterlik pencerede olmalı
            i = 0
            cikti = []
            son = 0
            for m in desen.finditer(g):
                pencere = g[m.start():m.start() + 900]
                if re.escape(metin).replace("\\ ", " ") and metin not in pencere:
                    continue
                if yeni_zem:
                    cikti.append((m.start(), m.end(), m.group(1) + yeni_zem))
            for a, b, yerine in reversed(cikti):
                g = g[:a] + yerine + g[b:]
                toplam += 1
                rapor.setdefault(rel, []).append("%s→%s" % (zem, yeni_zem))
            if yeni_met:
                # metin rengini yalnız o zemine sahip pencerelerde değiştir
                yer = []
                for m in re.finditer(r"backgroundColor:\s*C\." + zem + r"\b(?![A-Za-z])", g):
                    pen_bas, pen_son = m.start(), min(len(g), m.start() + 900)
                    for mm in re.finditer(r"color:\s*" + re.escape(metin) + r"\b(?![A-Za-z])",
                                          g[pen_bas:pen_son]):
                        yer.append((pen_bas + mm.start(), pen_bas + mm.end()))
                for a, b in sorted(set(yer), reverse=True):
                    g = g[:a] + "color: C." + yeni_met + g[b:]
                    toplam += 1
                    rapor.setdefault(rel, []).append("%s ink→%s" % (zem, yeni_met))
        if g != ham:
            shutil.copy2(yol, os.path.join(YEDEK, os.path.basename(rel)))
            open(yol, "w", encoding="utf-8").write(g)
    print("=" * 68)
    print("MÜREKKEP DÜZELTMESİ")
    print("=" * 68)
    for rel, liste in rapor.items():
        from collections import Counter
        c = Counter(liste)
        print("  %-26s %s" % (rel, " · ".join("%s×%d" % (k, v) for k, v in c.most_common())))
    print("\ntoplam %d değişiklik · yedek: %s" % (toplam, YEDEK))
    return 0


if __name__ == "__main__":
    sys.exit(main())
