#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sql_editor_check.py

============================================================================
SUPABASE SQL EDITOR'E YAPIŞTIRILACAK BİR DOSYADA `psql` META-KOMUTU VAR MI?

🔴 NEDEN VAR — 21 EYLÜL

Gökberk `SEED7_TEZGAH.sql`i Supabase SQL Editor'e yapıştırdı:

    ERROR: 42601: syntax error at or near "\\"
    LINE 70: -- =========================================================

70. satır bir YORUM — yani hata mesajı bile yanlış yeri gösteriyordu.
Asıl suçlu 71. satırdı:

    \\set ON_ERROR_STOP on

`\\set` bir SQL komutu DEĞİL, `psql` istemcisinin kendi meta-komutu.
Supabase SQL Editor `psql` değil; sunucuya düz SQL gönderiyor ve sunucu
o ters eğik çizgiyi gördüğü anda düşüyor.

Bunu BEN ekledim. Diğer altı SEED dosyasında o satır YOK — bu yüzden
onlar sorunsuz koştu. Yani "her ihtimale karşı hata korumasını açayım"
alışkanlığım, dosyanın HANGİ İSTEMCİDE okunacağını hesaba katmadan
uygulandığı için bir sözdizimi hatasına dönüştü.

🆕 SINIF: "BİR DOSYAYI HANGİ İSTEMCİNİN OKUYACAĞINI BİLMEDEN YAZILAN HER
KOLAYLIK SATIRI, BAŞKA BİR İSTEMCİDE SÖZDİZİMİ HATASIDIR."

⚠️ Koruma kaybı yok: `do $$` blokları zaten `raise exception` ile
duruyor ve işlem geri alınıyor. `ON_ERROR_STOP` yalnız `psql -f`
akışında birden çok deyimi zincirlerken iş görür.

── NE ÖLÇÜYOR ──────────────────────────────────────────────────────────

`sql/` altındaki HER `.sql` dosyasında, satır başında duran psql
meta-komutları:  \\set \\i \\ir \\echo \\timing \\gexec \\c \\copy \\pset …

Hepsi Gökberk'in SQL Editor'e yapıştırdığı dosyalar; hiçbiri `psql` ile
koşmak zorunda değil. (Yerelde `pg_run.py` da `psql` kullanıyor ama
meta-komuta ihtiyaç duymuyor — zaten `-v ON_ERROR_STOP=1` geçiyor.)

TAVAN 0.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")
TAVAN = 0

# Satır BAŞINDA duran psql meta-komutu. Dize içindeki ters eğik çizgiler
# (E'\\n' gibi) satır başında olmadığı için yakalanmıyor.
META = re.compile(r"^\s*\\(set|i|ir|include|echo|timing|gexec|c|connect|copy|pset|x|q|d[a-z]*)\b",
                  re.IGNORECASE)


def main():
    print("=" * 74)
    print("SQL EDITOR UYUMU — yapıştırılacak dosyada psql meta-komutu var mı?")
    print("=" * 74)

    # 🔴 21 Eylül — burada "sql/ yok — atlandı" yazıp 0 dönüyordu.
    # Yani klasör yokken bu kapı YEŞİL yanıyordu: hiçbir dosyayı
    # okumadan "psql meta-komutu yok" demiş oluyordu. Zincirin geri
    # kalanı aynı durumda dürüstçe kırmızı yanarken bu ikisi sessizce
    # geçiyordu — kendi kuralımı kendi kapımda çiğnemişim.
    #
    # 🆕 SINIF: "BİR KAPININ 'ATLANDI' DİYEBİLECEĞİ TEK DURUM YOKTUR:
    # ÖLÇEMİYORSA KIRMIZI YANAR."
    if not os.path.isdir(SQL):
        print("  ✗ sql/ klasörü bulunamadı — denetim KOŞMADI (sessiz geçmiyor).")
        print("     Aranan: %s" % SQL)
        print("     ÇÖZÜM: SQL_TAMAMI zip'ini C:\\ altına aç → C:\\sql")
        print("")
        print("SONUC  bulgu=KOSMADI  tavan=%d" % TAVAN)
        return 1

    bulgular = []
    dosya = 0
    for f in sorted(x for x in os.listdir(SQL) if x.endswith(".sql")):
        dosya += 1
        for n, satir in enumerate(open(os.path.join(SQL, f), encoding="utf-8"), 1):
            if META.match(satir):
                bulgular.append((f, n, satir.strip()[:60]))

    print("  taranan .sql dosyası : %d" % dosya)
    print("  bulgu                : %d  (tavan %d)" % (len(bulgular), TAVAN))
    print("")

    if bulgular:
        for f, n, satir in bulgular:
            print("  ✗ %s:%d" % (f, n))
            print("      %s" % satir)
        print("")
        print("  Bu satır Supabase SQL Editor'de şu hatayı verir:")
        print("      ERROR: 42601: syntax error at or near \"\\\"")
        print("  ve hata mesajı GENELDE YANLIŞ SATIRI gösterir (bir önceki yorumu).")
        print("")
        print("  ÇÖZÜM: satırı sil. Hata koruması `do $$ … raise exception` ile")
        print("  zaten var; `ON_ERROR_STOP` yalnız `psql -f` akışında iş görür")
        print("  ve `pg_run.py` onu `-v ON_ERROR_STOP=1` ile kendisi geçiyor.")
    else:
        print("  ✓ hiçbir dosyada satır başı psql meta-komutu yok")
    print("")
    print("SONUC  bulgu=%d  tavan=%d" % (len(bulgular), TAVAN))
    return 1 if len(bulgular) > TAVAN else 0


if __name__ == "__main__":
    sys.exit(main())
