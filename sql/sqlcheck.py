import re
import sys

import pglast
from pglast import parse_sql

# ============================================================
# 🔴 OUT PARAMETRESİ DEĞİŞEN FONKSİYONDA DROP KONTROLÜ
#
# Bu hatayı DÖRT KEZ yaptım: `create or replace function` ile bir
# fonksiyonun döndürdüğü kolonları değiştirmek PostgreSQL'de yasak —
# "cannot change return type of existing function" der.
#
# `returns_check.py` bunu zaten denetliyordu ama YANLIŞ ZAMANDA:
# tüm klasörü tarayan bir denetim ancak migration'ları çalıştırınca
# haber veriyor. Oysa dosyayı yazar yazmaz uyarması gerekiyordu.
#
# Dört tekrar, benim dikkatsizliğimden çok ARACIN YANLIŞ YERDE
# olduğunun işareti. Kontrol artık yazım anında, burada.
#
# Yalnız `returns table` / `returns setof` denetlenir — skaler dönüş
# tipleri de değişebilir ama çok daha nadir ve returns_check onları
# zaten yakalıyor. Amaç en sık tekrarlanan hatayı en erken kesmek.
# ============================================================
FUNC_RE = re.compile(
    r"create\s+or\s+replace\s+function\s+(?:public\.)?(\w+)\s*\("
    r"[^)]*\)\s*returns\s+(?:table|setof)\b",
    re.I | re.S,
)


def check_returns_drop(sql):
    found = []
    for m in FUNC_RE.finditer(sql):
        name = m.group(1)
        if not re.search(
            r"drop\s+function\s+if\s+exists\s+(?:public\.)?" + re.escape(name) + r"\b",
            sql, re.I,
        ):
            found.append((sql[: m.start()].count("\n") + 1, name))
    return found


# ════════════════════════════════════════════════════════════════════
# 🔴 19 AĞUSTOS — allow-replace İŞARETİ CANLIDA PATLADI (42P13)
#
# 219 şunu yazıyordu:
#     -- sqlcheck: allow-replace discovery_rule_badges  (returns table AYNI)
# ve denetim bunu kabul ediyordu. "AYNI" iddiası 135'e göre doğruydu
# (8 kolon) ama 221'e göre yanlıştı (9 kolon, can_ask_host).
#
# Boş veritabanına 1→226 kurunca 219 her zaman 135'i görür ve çalışır.
# Ama canlı veritabanı bir SIRA değil bir DURUM'dur: tur bir kez
# kurulduktan sonra fonksiyon 9 kolonludur, 219 tekrar koşunca 42P13.
#
# Ders: "aynı" bir KARŞILAŞTIRMADIR; neye göre olduğu söylenmedikçe
# boştur. Bu yüzden artık iddiaya güvenilmiyor, ÖLÇÜLÜYOR: aynı
# fonksiyonun tüm dosyalardaki dönüş şekilleri toplanır; birden fazla
# şekil varsa allow-replace REDDEDİLİR ve drop zorunlu olur.
#
# 🔴 ÖNEMLİ: bu ölçüm ancak TÜM dosyalar aynı çağrıda verilirse
# yapılabilir. Tek dosya verildiğinde şekil haritası kurulamaz —
# o durumda denetim "ölçemedim" der, sessizce geçmez.
# ════════════════════════════════════════════════════════════════════
SEKIL_RE = re.compile(
    r"create\s+or\s+replace\s+function\s+(?:public\.)?(\w+)\s*\([^)]*\)\s*"
    r"returns\s+table\s*\((.*?)\)\s*(?:language|stable|immutable|volatile|security|set|as)\b",
    re.I | re.S,
)


def sekil_haritasi(yollar):
    """ad -> {donus_sekli: [dosyalar]}"""
    harita = {}
    for p in yollar:
        try:
            s = open(p, encoding="utf-8").read()
        except OSError:
            continue
        for m in SEKIL_RE.finditer(s):
            ad = m.group(1)
            kols = ",".join(x.strip() for x in re.sub(r"\s+", " ", m.group(2)).lower().split(","))
            harita.setdefault(ad, {}).setdefault(kols, []).append(p)
    return harita


ok = True
YOLLAR = sys.argv[1:]
HARITA = sekil_haritasi(YOLLAR)
TEK_DOSYA = len(YOLLAR) < 2

for path in YOLLAR:
    sql = open(path, encoding="utf-8").read()
    try:
        stmts = parse_sql(sql)
    except Exception as e:
        ok = False
        print(f"HATA {path}: {e}")
        continue

    warns = check_returns_drop(sql)
    # 🔴 v158 istisnası: dönüş tipi DEĞİŞMEYEN bir tablo fonksiyonunda
    # drop eklemek yanlıştır — drop+create atomik değildir, canlıda o
    # anki çağrıyı düşürür ve grant'ları sıfırlar. Bilinçli replace,
    # dosyada şu işaretle beyan edilir ve fonksiyon bazında geçer:
    #   -- sqlcheck: allow-replace <fonksiyon_adi>
    allowed = set(re.findall(r"--\s*sqlcheck:\s*allow-replace\s+(\w+)", sql))

    # 🔴 İŞARET ARTIK ÖLÇÜLÜYOR (bkz. yukarıdaki 42P13 bloğu).
    # İddia edilen "dönüş tipi aynı", TÜM dosyalara göre doğrulanır.
    #
    # YALNIZ YÜK TAŞIYAN İŞARETLER denetlenir: dosyada zaten `drop
    # function if exists` varsa işaret hiçbir şeyi geçirmiyordur, o
    # yüzden doğruluğu da bir şeyi değiştirmez. İlk yazımda hepsini
    # denetledim ve 221'i yanlış yere kırmızı yaktım — oysa 221 drop
    # ediyor. Yanlış alarm, alarmı öğretir.
    yuk_tasiyan = {n for (_, n) in warns}
    for ad in sorted(allowed & yuk_tasiyan):
        sekiller = HARITA.get(ad, {})
        if TEK_DOSYA and len(sekiller) < 2:
            print(f"NOT {path}: allow-replace {ad} — tüm dosyalar verilmediği için "
                  f"ÖLÇÜLEMEDİ (tek dosya modu). Tam denetim: python sqlcheck.py *.sql")
            continue
        if len(sekiller) > 1:
            ok = False
            allowed.discard(ad)      # işaret geçersiz → drop zorunlu kalsın
            print(f"HATA {path}: `allow-replace {ad}` İDDİASI YANLIŞ — "
                  f"{len(sekiller)} FARKLI dönüş şekli var:")
            for i, (kols, dosyalar) in enumerate(sekiller.items(), 1):
                print(f"     şekil{i} ({len(kols.split(','))} kolon): {', '.join(dosyalar)}")
            print(f"     Canlıda hangi şekil olduğu SIRAYA değil DURUMA bağlıdır; "
                  f"tur bir kez kurulduysa 42P13 alırsın.")
            print(f"     Çözüm: işareti kaldır, `drop function if exists "
                  f"public.{ad}(...);` ekle.")

    warns = [(l, n) for (l, n) in warns if n not in allowed]
    if warns:
        ok = False
        for line, name in warns:
            print(f"HATA {path}:{line}  {name}() — tablo döndüren tanımın önünde DROP yok")
            print(f"     Ekle:  drop function if exists public.{name}(...);")
            print("     Yoksa canlıda: cannot change return type of existing function")
    else:
        print(f"OK  {path}  ({len(stmts)} ifade)")

sys.exit(0 if ok else 1)
