#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kurulum_tablosu_check.py

============================================================================
"HANGİ SQL'LERİ ÇALIŞTIRDIM?" TABLOSU SON DOSYAYI DA KAPSIYOR MU?

🔴 NEDEN VAR — 20 EYLÜL

Gökberk sordu: "en son hangi sql'i run ettiğimi anlayabilmem için
tablo halinde ilk sql'den son sql'e kadar hangisini çalıştırıp
hangisini çalıştırmadığımı dönen bir sorgu hazırla."

Böyle bir sorgu ZATEN vardı: `sql/KURULUM_TABLOSU.sql`. Açtım ve
ölçtüm — 294'e kadardı. 295, 296, 297, 298 ve 299 içinde YOKTU.

Yani tablo çalışıyordu ama **tam da sorulan soruya cevap veremiyordu**:
Gökberk'in bilmek istediği şey "en son ne koştum" ve tablonun bilmediği
şey tam olarak son beş dosyaydı. Üstelik 299 bu turda yazılan dosya.

Daha kötüsü: tablo bunu SÖYLEMİYORDU. "294'e kadar hepsi kurulu" deyip
susuyordu; eksik olduğunu kimse fark etmezdi.

🆕 SINIF: "BİR RAPORUN KAPSAMI SESSİZCE DARALIRSA, RAPOR YANLIŞ CEVAP
VERMEZ — EKSİK CEVAP VERİR, VE EKSİK CEVAP YANLIŞTAN DAHA İKNA EDİCİDİR."

── NE ÖLÇÜYOR ──────────────────────────────────────────────────────────

1. `sql/` altındaki NUMARALI her migration dosyası tabloda geçiyor mu.
2. Tabloda olup diskte olmayan dosya var mı (silinmiş/adı değişmiş).
3. SEED dosyalarının hepsi tabloda mı (migration değiller ama
   "hangilerini çalıştırdım" sorusu onları da kapsıyor).
4. Tablonun başlık satırındaki "son: NNN" gerçekten SON dosya mı
   (başlık elle yazıldığında bayatlıyordu — üretimden türetildi).

NASIL YEŞİLE DÖNER
    cd sql
    python imza_uret.py        # yeni dosyalar için aday imzalar
    python imza_dogrula.py     # adayları boş veritabanında ÖLÇ
    python tablo_uret.py       # tabloyu yeniden bas
    python tablo_sina.py       # üç durumda sına (tam / kısmi / boş)

TAVAN 0.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")
TABLO = os.path.join(SQL, "KURULUM_TABLOSU.sql")
TAVAN = 0

NUMARALI = re.compile(r"^\d{3}[a-z]?_.*\.sql$")
SEED = re.compile(r"^SEED.*\.sql$")


def main():
    print("=" * 74)
    print("KURULUM TABLOSU — 'hangi SQL'leri çalıştırdım' sorgusu güncel mi?")
    print("=" * 74)

    # 🔴 21 Eylül — bkz. sql_editor_check.py'deki aynı düzeltme.
    # Klasör yokken 0 dönüyordu: "kurulum tablosu güncel" demiş
    # oluyordu, hiçbir dosyaya bakmadan.
    if not os.path.isdir(SQL):
        print("  ✗ sql/ klasörü bulunamadı — denetim KOŞMADI (sessiz geçmiyor).")
        print("     Aranan: %s" % SQL)
        print("     ÇÖZÜM: SQL_TAMAMI zip'ini C:\\ altına aç → C:\\sql")
        print("")
        print("SONUC  bulgu=KOSMADI  tavan=%d" % TAVAN)
        return 1
    if not os.path.exists(TABLO):
        print("  ✗ sql/KURULUM_TABLOSU.sql YOK")
        print("")
        print("SONUC  bulgu=1  tavan=%d" % TAVAN)
        return 1

    tablo = open(TABLO, encoding="utf-8").read()
    # Tablodaki dosya adları tek tırnak içinde geçiyor.
    icinde = set(re.findall(r"'([^']*\.sql)'", tablo))

    diskte_m = sorted(f for f in os.listdir(SQL) if NUMARALI.match(f))
    diskte_s = sorted(f for f in os.listdir(SQL) if SEED.match(f))

    bulgular = []

    eksik_m = [f for f in diskte_m if f not in icinde]
    eksik_s = [f for f in diskte_s if f not in icinde]
    fazla = sorted(a for a in icinde
                   if (NUMARALI.match(a) or SEED.match(a))
                   and not os.path.exists(os.path.join(SQL, a)))

    print("  diskteki migration : %d" % len(diskte_m))
    print("  diskteki SEED      : %d" % len(diskte_s))
    print("  tabloda geçen      : %d" % len([a for a in icinde
                                             if NUMARALI.match(a) or SEED.match(a)]))
    print("")

    if eksik_m:
        print("  ✗ tabloda OLMAYAN migration (%d):" % len(eksik_m))
        for f in eksik_m:
            print("        %s" % f)
        bulgular.append("%d migration tabloda yok" % len(eksik_m))
    else:
        print("  ✓ her migration tabloda")

    if eksik_s:
        print("  ✗ tabloda OLMAYAN SEED (%d): %s" % (len(eksik_s), ", ".join(eksik_s)))
        bulgular.append("%d SEED tabloda yok" % len(eksik_s))
    else:
        print("  ✓ her SEED tabloda")

    if fazla:
        print("  ✗ tabloda VAR, diskte YOK (%d): %s" % (len(fazla), ", ".join(fazla[:6])))
        bulgular.append("%d dosya tabloda var ama diskte yok" % len(fazla))
    else:
        print("  ✓ tabloda hayalet dosya yok")

    # 4) başlıktaki kapsam gerçekten son dosya mı
    m = re.search(r"son:\s*(\d{3})", tablo)
    son_disk = max(f[:3] for f in diskte_m) if diskte_m else None
    if not m:
        print("  ✗ başlıkta 'son: NNN' yok — kapsam okunamıyor")
        bulgular.append("başlıkta kapsam yok")
    elif son_disk and m.group(1) != son_disk:
        print("  ✗ başlık 'son: %s' diyor, diskteki son dosya %s" % (m.group(1), son_disk))
        bulgular.append("başlık bayat: %s ≠ %s" % (m.group(1), son_disk))
    else:
        print("  ✓ başlık kapsamı doğru (son: %s)" % son_disk)

    print("")
    if bulgular:
        print("  ✗ %d bulgu:" % len(bulgular))
        for b in bulgular:
            print("      %s" % b)
        print("")
        print("  ÇÖZÜM (sql/ içinde, sırayla):")
        print("      python imza_uret.py && python imza_dogrula.py")
        print("      python tablo_uret.py && python tablo_sina.py")
    else:
        print("  ✓ tablo ilk dosyadan son dosyaya kadar tam")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    return 1 if len(bulgular) > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
