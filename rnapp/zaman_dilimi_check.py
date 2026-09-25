# -*- coding: utf-8 -*-
"""
LoungeLink · zaman_dilimi_check.py  —  59. DENETİM
DUVAR SAATİNİ UTC SANAN KARŞILAŞTIRMA

🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (timezone brief'i)
`availabilities.time_from/time_to` ve `visits.time_from/time_to`
`time WITHOUT time zone`: bunlar HAVALİMANININ DUVAR SAATİ. Sunucu UTC.
İkisini doğrudan karşılaştıran her satır Europe/Istanbul'da TAM 3 SAAT
yanlış sonuç üretir.

ÖLÇÜM (13 Eylül, yerel Postgres):
  · SQL 080 ilanı 3.00 saat GEÇ ölü sayıyordu
  · Radar 10:00 IST'te "kimse yok", 23:00 IST'te "host var" diyordu
  · `lounge_access_decision_v3` en erken giriş kuralı:
      ilan 09:00 IST · uçuş 14:20 IST · salon 3 saat önce alıyor
      kod "UYGUN" diyordu, gerçek "KURAL İHLALİ"
    Yani ürün, kapıda geri çevrilecek ilanı ONAYLIYORDU.
  Etkilenen: 5 canlı nesne · 14 yer. SQL 292 hepsini `yerel_an` /
  `yerel_gun` / `yerel_saat`e bağladı.

⚠️ KAPSAM — İLK SÜRÜM YANLIŞ ŞEYİ ÖLÇTÜ (60 bulgu).
Bulguların çoğu `034`, `080`, `100`, `104`, `105`, `134`, `218`, `280`
gibi TARİHÎ GÖÇ dosyalarındaydı. Bir göç dosyası TARİHTİR: uygulanmış,
292 tarafından geçersiz kılınmış ve yeniden yazılmamalı. Onları saymak,
kapanmış bir borcu her koşuda yeniden faturalamaktır — ve gürültülü bir
nöbetçi, nöbetçi değildir (`kural_metni_check.py` ile AYNI sınıf hata,
ikinci kez).
Doğru kapsam CANLI OLAN: `ETKIN_TANIMLAR.sql` (her fonksiyonun canlı
hâli, `snapshot_gen.py` üretir) + numarası 292'DEN BÜYÜK yeni dosyalar.
🆕 SINIF: "BİR DENETİM TARİHE DEĞİL YÜRÜRLÜKTE OLANA BAKAR — GEÇMİŞİ
DENETLEMEK, GEÇMİŞİ DEĞİŞTİRMEYE ÇALIŞMAKTIR."

NE DENETLİYOR: yürürlükteki tanımlarda
  (a) `current_time` / `localtime` ile duvar saati kolonu kıyası
  (b) `(… _date + … time_…)` ifadesinin `at time zone` OLMADAN
      `now()` / `timestamptz` / `current_date` ile kıyaslanması
  (c) `(… _date + … time_…)::timestamptz` düz cast'i
  (d) `… _date = current_date` — UTC günü, havalimanı günü değil

TAVAN: 0. Bu bir RATCHET DEĞİL. Borç 292'de kapandı; yeniden açılamaz.
Yeni bir karşılaştırma yazmak isteyen `public.yerel_an(...)` kullanır.

⚠️ NE DENETLEMİYOR: çalışan veritabanını (bu kap Supabase'e erişemiyor)
ve `scheduled_departure` gibi zaten `timestamptz` olan kolonları —
onlar gerçek an taşıyor, dönüştürülmeleri YANLIŞ olurdu.

🆕 SINIF: "DOĞRU DESEN ÜRÜNDE ZATEN VARSA SORUN MİMARİ DEĞİL
YAYILMADIR — VE YAYILMAYI İNSAN DEĞİL NÖBETÇİ SAĞLAR."
"""
import os, re, sys, glob

KOK = os.path.dirname(os.path.abspath(__file__))
SQLDIZ = os.path.join(os.path.dirname(KOK), "sql")

# 292'nin KENDİSİ muaf (düzeltmenin kaynağı, eski deseni örnek olarak
# yorumlarında anıyor). Geri kalanı `kapsamda` karar verir.
MUAF_DOSYA = re.compile(r"^292_", re.I)
MUAF_DIZIN = ("arsiv", "_arsiv", "yedek")
SINIR = 292   # bu numaraya kadarki göçler TARİHTİR, 292 onları geçersiz kıldı


def kapsamda(bag):
    """Yürürlükte olan mı? `ETKIN_TANIMLAR.sql` + numarası 292'den büyük
    yeni göçler. Tarihî göçler denetlenmez (bkz. başlıktaki KAPSAM notu)."""
    ad = os.path.basename(bag)
    if ad == "ETKIN_TANIMLAR.sql":
        return True
    m = re.match(r"^(\d{3,4})_", ad)
    if m:
        return int(m.group(1)) > SINIR
    # Numarasız dosyalar (SEED*, canli_fikstur vb.) denetlenir: bunlar
    # tarih değil, hâlâ koşulan yardımcı betikler.
    return True

# Duvar saati kolonları — şema bunları `time without time zone` tutuyor.
DUVAR = r"(?:time_from|time_to)"
TARIH = r"(?:avail_date|visit_date|flight_date)"


def satirlari_temizle(s):
    """`--` yorumlarını ve `/* */` bloklarını boşlukla değiştirir; satır
    sayısı korunur. Dize içindeki `--` yanlış yere düşmesin diye tek
    tırnak farkındalığı var — bu sınıf hatayı `ikon_check.py`de üç kez
    ödedik (Türkçe kesme işareti yorum ayıklayıcıyı kör etmişti)."""
    out = []
    i, n = 0, len(s)
    dize = blok = satir_yorum = False
    while i < n:
        c = s[i]
        iki = s[i:i + 2]
        if satir_yorum:
            if c == "\n":
                satir_yorum = False
                out.append(c)
            else:
                out.append(" ")
            i += 1
            continue
        if blok:
            if iki == "*/":
                blok = False
                out.append("  ")
                i += 2
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if dize:
            out.append(c)
            if c == "'":
                # '' kaçışı
                if s[i + 1:i + 2] == "'":
                    out.append("'")
                    i += 2
                    continue
                dize = False
            i += 1
            continue
        if iki == "--":
            satir_yorum = True
            out.append("  ")
            i += 2
            continue
        if iki == "/*":
            blok = True
            out.append("  ")
            i += 2
            continue
        if c == "'":
            dize = True
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


# ── Kalıplar ──────────────────────────────────────────────────────────
KALIPLAR = [
    # (a) current_time / localtime ile duvar saati kıyası
    (re.compile(r"\b" + DUVAR + r"\b[^\n;]{0,80}\b(current_time|localtime)\b", re.I),
     "duvar saati × current_time"),
    (re.compile(r"\b(current_time|localtime)\b[^\n;]{0,80}\b" + DUVAR + r"\b", re.I),
     "current_time × duvar saati"),
    # (c) düz timestamptz cast'i
    (re.compile(r"\(\s*\w*\.?" + TARIH + r"\s*\+\s*\w*\.?" + DUVAR + r"\s*\)\s*::\s*timestamptz", re.I),
     "(tarih + duvar saati)::timestamptz"),
    # (d) UTC günü ile tarih kıyası — ARİTMETİKSİZ olanı (bkz. aşağıdaki not)
    # ⚠️ `\s*(?![+\-])` YAZMIŞTIM VE ÇALIŞMADI: `\s*` geri izler, sıfır
    # boşluk eşleşir, ileri bakış boşluk karakterini görür ve geçer.
    # Doğrusu boşluğu İLERİ BAKIŞIN İÇİNE almak: `(?!\s*[+\-])`.
    # 🆕 SINIF: "BİR İLERİ BAKIŞTAN ÖNCE ESNEK BİR ŞEY VARSA İLERİ BAKIŞ
    # DELİNİR — İSTEMEDİĞİN ŞEYİ BAKIŞIN İÇİNE YAZ."
    (re.compile(r"\b\w*\.?" + TARIH + r"\s*=\s*current_date\b(?!\s*[+\-])", re.I),
     "tarih = current_date (UTC günü)"),
]

# ⚠️ `current_date ± N` AYRI VE DAHA ZAYIF BİR SINIF — ilk sürüm ikisini
# bir tutuyordu ve 9 bulgunun 8'i tohum üreticisiydi (`visit_date =
# current_date + 21` → "bugünden 21 gün sonra"; orada 3 saatlik kayma
# anlamsız, çünkü kıyas bir ANA değil bir GÜNE bakıyor).
# Ama tamamen görmezden gelmek de yanlıştı: `yarinki_lounge_hatirlat`
# tam bu kalıpla "yarın"ı UTC'nin yarını sanıyordu (00:00–03:00 İstanbul
# arasında BUGÜNÜN buluşmasına hatırlatma gidiyordu) — 292 düzeltti.
# Karar: sayılır ve LİSTELENİR, ama denetimi DÜŞÜRMEZ. Gürültü yapmadan
# görünür kalır.
# 🆕 SINIF: "İKİ FARKLI CİDDİYETTEKİ BULGUYU TEK SAYIYA TOPLAYAN DENETİM,
# YA YANLIŞ YERDE DURUR YA YANLIŞ YERDE SUSAR."
GUN_ARITMETIK = re.compile(r"\b\w*\.?" + TARIH + r"\s*=\s*current_date\s*[+\-]", re.I)

# (b) ayrı ele alınıyor: ifade + aynı satırda now()/utc ve `at time zone` yok
B_KALIP = re.compile(r"\(\s*\w*\.?" + TARIH + r"\s*\+\s*\w*\.?" + DUVAR + r"\s*\)", re.I)

bulgu = []
uyari = []
if os.path.isdir(SQLDIZ):
    for yol in sorted(glob.glob(os.path.join(SQLDIZ, "**", "*.sql"), recursive=True)):
        bag = os.path.relpath(yol, SQLDIZ)
        if MUAF_DOSYA.match(os.path.basename(yol)):
            continue
        if any(d in bag.lower().split(os.sep) for d in MUAF_DIZIN):
            continue
        if not kapsamda(bag):
            continue
        ham = open(yol, encoding="utf-8", errors="replace").read()
        s = satirlari_temizle(ham)
        for no, satir in enumerate(s.split("\n"), 1):
            for kal, ad in KALIPLAR:
                if kal.search(satir):
                    bulgu.append((bag, no, ad, satir.strip()[:110]))
            if GUN_ARITMETIK.search(satir):
                uyari.append((bag, no, satir.strip()[:100]))
            m = B_KALIP.search(satir)
            if m:
                # aynı satırda now()/utc var mı, ve `at time zone` YOK mu?
                if re.search(r"\bnow\s*\(\)|at time zone 'utc'|\bcurrent_timestamp\b", satir, re.I) \
                        and "at time zone" not in satir.lower().replace("at time zone 'utc'", ""):
                    bulgu.append((bag, no, "(tarih + duvar saati) × now()", satir.strip()[:110]))

TAVAN = 0
print(f"zaman_dilimi_check · duvar saatini UTC sanan kıyas: {len(bulgu)} (tavan {TAVAN})")
for bag, no, ad, satir in bulgu[:10]:
    print(f"   {bag}:{no}  [{ad}]\n      «{satir}»")
if len(bulgu) > 10:
    print(f"   … ve {len(bulgu) - 10} tane daha")

if uyari:
    print(f"  ℹ {len(uyari)} yerde `current_date ± N` (gün penceresi — denetimi düşürmez):")
    for bag, no, satir in uyari[:5]:
        print(f"     {bag}:{no}  «{satir}»")
    if len(uyari) > 5:
        print(f"     … ve {len(uyari) - 5} tane daha")

if len(bulgu) > TAVAN:
    print("\n✗ DUVAR SAATİ UTC SANILIYOR — Europe/Istanbul'da 3 SAAT yanlış sonuç.")
    print("  Çözüm: `public.yerel_an(tarih, saat, havalimani_kodu)` (SQL 292).")
    print("  Bugünün saati için: `public.yerel_gun(kod)` / `public.yerel_saat(kod)`.")
    print("  `scheduled_departure` gibi timestamptz kolonları DÖNÜŞTÜRÜLMEZ.")
    sys.exit(1)
print("✓ duvar saati × UTC kıyası yok")
