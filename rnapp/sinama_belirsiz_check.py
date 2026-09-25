#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sinama_belirsiz_check.py

============================================================================
BİR SINAMA, FONKSİYONUN DÖNDÜRECEĞİ SATIRI KENDİ Mİ SEÇİYOR?

🔴 NEDEN VAR — 21 EYLÜL

Gökberk Supabase'de SQL 296'yı koştu ve şunu aldı:

    ERROR: P0001: 296: 31 gun sonra tekrar sorulmadi (erteleme kalici oldu)

Yerelde geçiyordu. Sebebi bulup birebir ürettim ve ÜRÜNDE KUSUR YOKTU:

  · `bekleyen_hikaye_daveti()` TEK davet döndürür
    (`order by completed_at desc ... limit 1`) — ürün aynı anda tek
    davet gösterdiği için.
  · Sınama ise AYRI bir `limit 1` ile, SIRASIZ olarak rastgele bir
    tamamlanmış oturum seçip "fonksiyon TAM BU satırı döndürecek"
    diye varsayıyordu.

Host'un birden çok bekleyen oturumu varsa iki `limit 1` FARKLI satırı
gösterir ve sınama, ürün kusursuzken patlar. Yerelde bir host'ta 3
bekleyen oturum vardı; sınamayı o host'a sabitleyince Gökberk'in aldığı
hatanın AYNISI çıktı.

⚠️ BU SINIF İKİNCİ KEZ: SQL 211'in kendi sınaması da sırasız `limit 1`
yüzünden bir kez düşmüştü. O zaman "sıraya bağladık" diye kapatılmıştı —
yani SEMPTOM düzeltilmiş, SINIF açık kalmıştı.

🆕 SINIF: "BİR FONKSİYONUN DÖNDÜRECEĞİ SATIRI SINAMADA YENİDEN SEÇERSEN,
İKİ SEÇİMİN AYNI SATIRA DÜŞTÜĞÜNÜ DE VARSAYMIŞ OLURSUN — SEÇME, SOR."

── NE ÖLÇÜYOR (ve neden bu kadar dar) ─────────────────────────────────

Önce geniş kuralı denedim: "`do $$` bloğunda sırasız `limit 1` ile
`into`". **135 bulgu.** Çoğu tamamen masum — `select prosrc into v_src
from pg_proc where proname = 'x'` gibi zaten tekil satırlar. Böyle bir
kapı gürültüdür ve gürültülü kapı susturulur.

Bu yüzden ölçü DAR: aynı `do $$` bloğunda
  1. bir değişken SIRASIZ `limit 1` ile dolduruluyor, VE
  2. aynı blok bir `public.<fonksiyon>()` çağırıyor, VE
  3. o değişken, fonksiyonun çıktısıyla KARŞILAŞTIRILIYOR
     (`where <kolon> = v_x` ya da `<kolon> <> v_x`).

Yani yalnız "sınama kendi seçtiği satırın fonksiyondan döneceğini
varsayıyor" hâli. Diğer `limit 1`ler rahatsız edilmiyor.

ÇÖZÜM (296'da uygulanan): satırı SEÇME, fonksiyona SOR —
    select session_id into v_sid from public.bekleyen_hikaye_daveti();
Fonksiyonun sırası yarın değişse bile sınama doğru satıra bakar.

TAVAN 0.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")
TAVAN = 0

BLOK = re.compile(r"do \$\$.*?\n\s*end \$\$;", re.S)
SECIM = re.compile(r"(?is)\bselect\b(?:(?!\bselect\b|;).)*?\binto\b\s+([a-z_][a-z0-9_,\s]*?)\s+from\b(?:(?!;).)*?;")
FN = re.compile(r"(?i)\bfrom\s+public\.([a-z_][a-z0-9_]*)\s*\(")


def degiskenler(ifade_into):
    return [d.strip() for d in ifade_into.split(",") if d.strip()]


def main():
    print("=" * 74)
    print("BELİRSİZ SINAMA — sınama, fonksiyonun satırını kendi mi seçiyor?")
    print("=" * 74)

    if not os.path.isdir(SQL):
        print("  · sql/ yok — atlandı")
        print("")
        print("SONUC  bulgu=0  tavan=%d" % TAVAN)
        return 0

    bulgular = []
    blok_sayisi = 0
    for f in sorted(x for x in os.listdir(SQL) if re.match(r"^\d{3}[a-z]?_.*\.sql$", x)):
        s = open(os.path.join(SQL, f), encoding="utf-8").read()
        for m in BLOK.finditer(s):
            blok = m.group(0)
            blok_sayisi += 1
            fonksiyonlar = set(FN.findall(blok))
            if not fonksiyonlar:
                continue
            for sm in SECIM.finditer(blok):
                ifade = sm.group(0)
                if not re.search(r"(?i)\blimit\s+1\b", ifade):
                    continue
                if re.search(r"(?i)\border\s+by\b", ifade):
                    continue
                if re.search(r"(?i)\bfrom\s+public\.[a-z_]+\s*\(", ifade):
                    continue          # zaten fonksiyona SORUYOR — doğrusu bu
                for d in degiskenler(sm.group(1)):
                    # Fonksiyon çağrısının bulunduğu ifadelerde bu değişken
                    # bir karşılaştırmada geçiyor mu?
                    for fs in re.finditer(r"(?is)\bfrom\s+public\.[a-z_]+\s*\([^;]*?;", blok):
                        if re.search(r"(?i)[a-z_.]+\s*(=|<>)\s*" + re.escape(d) + r"\b", fs.group(0)):
                            satir = s.count("\n", 0, m.start() + sm.start()) + 1
                            bulgular.append((f, satir, d, sorted(fonksiyonlar)[:2],
                                             re.sub(r"\s+", " ", ifade)[:70]))
                            break

    print("  taranan `do $$` bloğu : %d" % blok_sayisi)
    print("  bulgu                 : %d  (tavan %d)" % (len(bulgular), TAVAN))
    print("")

    if bulgular:
        for f, satir, d, fns, ifade in bulgular:
            print("  ✗ %s:%d" % (f, satir))
            print("      `%s` SIRASIZ `limit 1` ile seçiliyor," % d)
            print("      sonra public.%s(...) çıktısıyla karşılaştırılıyor." % fns[0])
            print("      %s" % ifade)
        print("")
        print("  ÇÖZÜM: satırı seçme, fonksiyona SOR —")
        print("      select <kolon> into v_x from public.<fonksiyon>();")
        print("  `order by` eklemek semptomu kapatır, sınıfı kapatmaz:")
        print("  fonksiyonun sırası değişirse sınama yine yanlış satıra bakar.")
    else:
        print("  ✓ hiçbir sınama, fonksiyonun döndüreceği satırı kendi seçmiyor")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    return 1 if len(bulgular) > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
