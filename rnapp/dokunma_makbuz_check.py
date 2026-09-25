#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dokunma_makbuz_check.py

============================================================================
DOKUNMA YOLU TESTİ GÜNCEL KODA KARŞI KOŞTU MU?

🔴 NEDEN VAR — 20 EYLÜL

`web_sahne/dokunma_yolu_test.py` gerçek bir tarayıcı ister (Chromium +
Playwright + `web_sahne/dist`). `verify.js` ise Gökberk'in Windows
makinesinde de koşuyor ve orada tarayıcı olmayabilir. Testi doğrudan
zincire koyarsam iki kötü sonuçtan biri olur:

  · tarayıcı yoksa zincir HER SEFERİNDE kırmızı yanar → susturulur,
  · ya da "atlandı" deyip YEŞİL yanar → test var sayılır ama yoktur.

İkisi de `website/verify.js`in başındaki aynı dersin başka yüzü:
"BİR DENETİM ZİNCİRE BAĞLI DEĞİLSE VAR DEĞİLDİR."

ÇÖZÜM — MAKBUZ. Test başarıyla bittiğinde arayüz kaynaklarının özetini
`web_sahne/out/dokunma_yolu.json`a yazar. Bu kapı da şunu sorar:

    makbuz var mı · düşen adım 0 mı · özeti BUGÜNKÜ kaynakla aynı mı

Kod değişip test yeniden koşmadıysa özet tutmaz ve zincir kırmızı yanar.
Yani tarayıcı gerektiren test, tarayıcı gerektirmeyen bir kapıyla zincire
bağlanmış olur.

🆕 SINIF: "ÇALIŞTIRILMASI PAHALI BİR TESTİ ZİNCİRE BAĞLAMANIN YOLU ONU
ZİNCİRDE KOŞTURMAK DEĞİL, ÇIKTISININ GÜNCEL OLDUĞUNU UCUZCA KANITLAMAKTIR."

NASIL YEŞİLE DÖNER
    npm run sahne          (dist güncelse)
  ya da tam hâli:
    npm run sahne:export && npm run sahne

TAVAN 0.
============================================================================
"""
import hashlib
import json
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
MAKBUZ = os.path.join(KOK, "web_sahne", "out", "dokunma_yolu.json")
TAVAN = 0

# Özete GİREN dosyalar: dokunma yolunun geçtiği her yer. Bunlardan biri
# değişirse testin yeniden koşması gerekir.
# ⚠️ Liste GENİŞ tutuluyor: dar tutmak "bu dosya dokunmayı etkilemez"
# varsayımıdır ve tam olarak o varsayım üç tur kaybettirdi.
KAYNAK_DIZIN = ["src"]
KAYNAK_DOSYA = ["App.js"]


def kaynak_ozeti(kok=None):
    kok = kok or KOK
    h = hashlib.sha256()
    yollar = []
    for d in KAYNAK_DOSYA:
        p = os.path.join(kok, d)
        if os.path.exists(p):
            yollar.append(p)
    for d in KAYNAK_DIZIN:
        t = os.path.join(kok, d)
        for dirpath, dirs, files in os.walk(t):
            dirs[:] = sorted(dirs)
            for f in sorted(files):
                if f.endswith(".js"):
                    yollar.append(os.path.join(dirpath, f))
    for p in sorted(yollar):
        h.update(os.path.relpath(p, kok).replace(os.sep, "/").encode())
        h.update(open(p, "rb").read())
    return h.hexdigest()[:16]


def main():
    print("=" * 74)
    print("DOKUNMA MAKBUZU — tarayıcı testi GÜNCEL koda karşı koştu mu?")
    print("=" * 74)
    simdi = kaynak_ozeti()

    if not os.path.exists(MAKBUZ):
        print("  ✗ makbuz YOK: web_sahne/out/dokunma_yolu.json")
        print("")
        print("  Bu, 'oturumsuz akışın düğmeleri çalışıyor' iddiasının HİÇ")
        print("  ölçülmediği anlamına gelir. Koş:")
        print("      npm run sahne:export && npm run sahne")
        print("")
        print("SONUC  bulgu=1  tavan=%d" % TAVAN)
        return 1

    m = json.load(open(MAKBUZ, encoding="utf-8"))
    bulgular = []
    print("  makbuz tarihi : %s" % m.get("tarih", "—"))
    print("  koşan adım    : %d" % len(m.get("adimlar", [])))
    print("  düşen adım    : %d" % m.get("dusen", -1))
    print("  kaynak özeti  : %s   (bugün: %s)" % (m.get("kaynak_ozeti", "—"), simdi))
    print("")

    if m.get("dusen", -1) != 0:
        bulgular.append("son koşuda %s adım düştü" % m.get("dusen"))
    if not m.get("adimlar"):
        bulgular.append("makbuzda hiç adım yok")
    if m.get("kaynak_ozeti") != simdi:
        bulgular.append("arayüz kaynağı testten SONRA değişti — test bayat")

    if bulgular:
        for b in bulgular:
            print("  ✗ %s" % b)
        print("")
        print("  Bu kapı 'düğmeler çalışmıyor' hatasının tek doğrudan kanıtıdır.")
        print("  Yeşile döndürmenin yolu susturmak değil, testi koşturmaktır:")
        print("      npm run sahne:export && npm run sahne")
    else:
        print("  ✓ oturumsuz akışın her düğmesi bu kaynağa karşı ölçüldü")
        for a in m.get("adimlar", []):
            print("      · %s" % a)

    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    return 1 if len(bulgular) > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
