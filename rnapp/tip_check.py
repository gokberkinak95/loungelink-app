#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · tip_check.py — RETURNS TABLE SÖZLEŞMESİ, VERİ OLMADAN

🔴 NEDEN VAR — 18 Ağustos 2026, canlıda patladı:

    ERROR: 42804 structure of query does not match function result type
    DETAIL: Returned type character(3) does not match expected type text
            in column 9.
    CONTEXT: PL/pgSQL function my_sent_requests() line 4 at RETURN QUERY

`186_context_for_cards.sql` `my_sent_requests()`i şöyle tanımlıyordu:

    returns table (..., airport_code text, ...)
    ...
    select ..., a.airport_code, ...     -- availabilities.airport_code CHAR(3)

Cast yok. PostgreSQL bu uyuşmazlığı **yalnız bir satır döndüğünde** kontrol
eder; sıfır satırda hiç coercion yapmaz. Yani:

  · Benim harness'ımda 186 çalışırken `requests` tablosunda pending/accepted
    HİÇ SATIR YOKTU (senaryo verisi en sonda geliyor) → hata çıkmadı.
  · İki dosya sonra 187 aynı fonksiyonu `airport_code::text` ile yeniden
    tanımlıyordu → hata kendiliğinden "düzelmiş" görünüyordu.
  · Gökberk'in veritabanında gerçek bir istek vardı → anında patladı.

İki körlük üst üste binmişti ve "238 dosya baştan sona temiz çalıştı"
cümlesi bu sınıf için HİÇBİR ŞEY kanıtlamıyordu.

HATA SINIFI 24 — "TİP UYUŞMAZLIĞI VERİ OLMADAN GÖRÜNMEZ."

ÇÖZÜM: veriye hiç ihtiyaç duymadan, STATİK olarak ölç. Her `returns table`
fonksiyonunun ilan ettiği sütun tipleri ile gövdesindeki `select` listesinde
o sütuna denk gelen ifadenin gerçek tipi karşılaştırılır.

⚠️ NEDEN "ÇALIŞTIRIP BAK" DEĞİL: fonksiyonu veriyle çağırmak, ancak o an
veri varsa bir şey kanıtlar — yani tam da bu hatanın kaçtığı yol. Statik
ölçüm veri durumundan BAĞIMSIZ.

⚠️ KAPSAM DÜRÜSTLÜĞÜ: yalnız `alias.kolon` biçimindeki ÇIPLAK kolon
referansları çözülür. `coalesce(...)`, `case ...`, fonksiyon çağrısı gibi
ifadeler ATLANIR ve atlanan sayısı RAPOR EDİLİR — sıfır satır ölçüp
"temiz" demek bu depodaki en pahalı hata sınıfı.
"""
import os, re, sys, subprocess, pathlib

DATA = pathlib.Path('/tmp/ll_pg')

def psql(sql):
    import pgserver
    binp = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
    uri = pgserver.get_server(DATA).get_uri()
    r = subprocess.run([str(binp/'psql'), uri, '-X', '-A', '-t', '-F', '\x1f', '-c', sql],
                       capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:800])
    return [l.split('\x1f') for l in r.stdout.splitlines() if '\x1f' in l or l.strip()]

# ---- tip denkliği ----
# 🔴 BU FONKSIYONUN ILK HALI YANLISTI VE BIR HATAYI GECIRDI.
# "text ↔ varchar sorun degil, sayisal aile icinde serbest" diye
# YAZMISTIM — olcmeden. Gokberk 186'yi tekrar calistirdi ve ikinci bir
# 42804 aldi: `slots` SMALLINT, `int` diye ilan edilmis. Benim denetimim
# o farki KABUL EDIYORDU.
#
# PostgreSQL'e sordum (14 cift, gercek fonksiyon yaratip cagirarak):
#   ilan=integer  kolon=smallint  → RED 42804
#   ilan=bigint   kolon=integer   → RED 42804
#   ilan=numeric  kolon=integer   → RED 42804
#   ilan=text     kolon=varchar   → RED 42804
#   ilan=text     kolon=char(3)   → RED 42804
#   ilan=bigint   kolon=bigint    → KABUL
#   ilan=text     kolon=text      → KABUL
#
# Kural tek cumle: RETURNS TABLE **TAM TIP ESITLIGI** ister. Genisletme
# yok, uyarlama yok. Varsayimi olcumle degistirdim.
TAKMA = {
    'timestamptz': 'timestamp with time zone',
    'timestamp':   'timestamp without time zone',
    'time':        'time without time zone',
    'timetz':      'time with time zone',
    'varchar':     'character varying',
    'char':        'character',
    'bpchar':      'character',
    'int':  'integer', 'int4': 'integer', 'int8': 'bigint', 'int2': 'smallint',
    'bool': 'boolean', 'float8': 'double precision', 'float4': 'real',
    'decimal': 'numeric',
}
def normal(t):
    t = ' '.join(str(t).strip().lower().split())
    t = re.sub(r'\(\d+(,\d+)?\)$', '', t)     # varchar(30) -> varchar
    dizi = t.endswith('[]')
    t = re.sub(r'\[\]$', '', t)
    t = TAKMA.get(t, t)
    return t + ('[]' if dizi else '')

def denk(ilan, gercek):
    # TAM ESITLIK. Esneklik yok — PostgreSQL de esnek degil (olculdu).
    return normal(ilan) == normal(gercek)


# ---- takma ad -> tablo cozumu ----
# 🔴 BU OLMADAN DENETIM KORDU. `airport_code` katalogda IKI FARKLI TIPTE var
# (availabilities/lounges/visits -> character(3), lounge_venues -> text).
# Ilk surum "belirsiz" deyip ATLIYOR ve yakalamasi gereken hatayi kaciriyordu;
# mutasyon testi gosterdi. FROM/JOIN cumlesinden takma adi tabloya bagliyoruz.
def takma_adlar(govde):
    esles = {}
    for m in re.finditer(
            r'\b(?:from|join)\s+(?:public\.)?([a-z_][a-z0-9_]*)\s+(?:as\s+)?([a-z_][a-z0-9_]*)',
            govde, re.I):
        tablo, ad = m.group(1).lower(), m.group(2).lower()
        if ad in ('on','where','group','order','left','right','inner','join',
                  'using','cross','full','outer','lateral','limit','having'):
            continue
        esles.setdefault(ad, tablo)
    return esles

def main():
    if not DATA.exists():
        print('✗ /tmp/ll_pg yok. Once: python3 pg_run.py --keep')
        return 2

    # 1) Her returns table fonksiyonunun ilan ettigi sutunlar
    fns = psql("""
      select p.proname,
             pg_get_function_result(p.oid),
             replace(coalesce(p.prosrc,''), chr(10), ' ')
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and pg_get_function_result(p.oid) like 'TABLE%'
         and p.prolang = (select oid from pg_language where lanname='plpgsql')
       order by p.proname""")

    # 2) Kolon tipleri sozlugu: tablo.kolon -> tip
    kols = {}
    # ⚠️ `information_schema.columns.data_type` DIZILER ICIN 'ARRAY' der,
    # eleman tipini soylemez — `text[]` ilanini "ARRAY" ile kiyaslayinca
    # sahte bulgu cikti. `pg_attribute` + `format_type` gercek tipi verir.
    for t, c, dt in psql("""
        select c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod)
          from pg_attribute a
          join pg_class c on c.oid = a.attrelid
          join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relkind in ('r','v','m')
           and a.attnum > 0 and not a.attisdropped"""):
        kols.setdefault(c.strip(), {})[t.strip()] = dt.strip()

    bulgular, atlanan, incelenen, cozulen = [], 0, 0, 0

    for ad, res, src in fns:
        ad, res, src = ad.strip(), res.strip(), src.strip()
        m = re.match(r'TABLE\((.*)\)$', res, re.S)
        if not m:
            continue
        # ilan edilen sutunlar: "ad tip" ciftleri (virgulle, parantez dengeli)
        parcalar, derinlik, cur = [], 0, ''
        for ch in m.group(1):
            if ch == '(': derinlik += 1
            if ch == ')': derinlik -= 1
            if ch == ',' and derinlik == 0:
                parcalar.append(cur); cur = ''
            else:
                cur += ch
        parcalar.append(cur)
        ilanlar = []
        for p in parcalar:
            p = p.strip()
            if not p: continue
            i = p.find(' ')
            if i < 0: continue
            ilanlar.append((p[:i].strip(), p[i+1:].strip()))

        # gövdedeki `return query select ... from` listesini al
        sm = re.search(r'return\s+query\s+select\s+(.*?)\s+from\s', src, re.I | re.S)
        if not sm:
            continue
        incelenen += 1
        ifadeler, derinlik, cur = [], 0, ''
        for ch in sm.group(1):
            if ch in '([': derinlik += 1
            if ch in ')]': derinlik -= 1
            if ch == ',' and derinlik == 0:
                ifadeler.append(cur); cur = ''
            else:
                cur += ch
        ifadeler.append(cur)

        for idx, ifade in enumerate(ifadeler):
            if idx >= len(ilanlar):
                break
            ifade = ifade.strip()
            sutun_ad, ilan_tip = ilanlar[idx]
            # YALNIZ ciplak alias.kolon — geri kalani durustce ATLA
            bm = re.fullmatch(r'([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*)', ifade, re.I)
            if not bm:
                atlanan += 1
                continue
            kol = bm.group(2).lower()
            adaylar = kols.get(kol)
            if not adaylar:
                atlanan += 1
                continue
            tipler = set(adaylar.values())
            if len(tipler) != 1:
                # ayni ada sahip kolon farkli tablolarda farkli tipte — cozemeyiz
                atlanan += 1
                continue
            cozulen += 1
            gercek = tipler.pop()
            if not denk(ilan_tip, gercek):
                bulgular.append(
                    f'{ad}() sutun {idx+1} "{sutun_ad}": ILAN {ilan_tip} · GERCEK {gercek} '
                    f'({ifade}) → satir dondugu anda 42804')

    # ============================================================
    # 2. GECIS — DOSYALAR. Canli govdeyi okumak YETMEZ.
    # 🔴 Bu, hatanin ikinci yarisi: 186 bozuktu ama 187 ayni fonksiyonu
    # duzeltilmis haliyle yeniden tanimliyordu. Canli `pg_proc` yalnizca
    # SON tanimi tasir — yani 186'nin bozuk hali orada HIC GORUNMEZ.
    # Ama migration'lari SIRAYLA calistiran biri 186'da patlar.
    # "Her dosya kendi aninda dogru olmali" kurali (hata sinifi 21)
    # tip sozlesmesi icin de gecerli.
    dosya_bulgu = []
    sql_dir = os.environ.get('LL_SQL_DIR') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'sql')
    if os.path.isdir(sql_dir):
        for fn in sorted(os.listdir(sql_dir)):
            if not fn.endswith('.sql'):
                continue
            # ⚠️ ETKIN_TANIMLAR.sql CALISTIRILMAYAN bir referans dokumudur
            # (kendi basligi "BU DOSYAYI CALISTIRMA" diyor). Denetime
            # sokmak, hic kosmayacak koddan alarm uretmek olurdu.
            if fn.startswith('ETKIN_TANIMLAR'):
                continue
            metin = open(os.path.join(sql_dir, fn), encoding='utf-8', errors='replace').read()
            metin = re.sub(r'--[^\n]*', ' ', metin)          # yorumlari at
            for fm in re.finditer(
                    r'create\s+or\s+replace\s+function\s+(?:public\.)?(\w+)\s*\([^)]*\)\s*'
                    r'returns\s+table\s*\((.*?)\)\s*language', metin, re.I | re.S):
                fad, ilan_metin = fm.group(1), fm.group(2)
                govde = metin[fm.end(): fm.end() + 6000]
                # 🔴 KAPSAM GENISLETMESI. Ilk surum yalniz
                # `return query select` ariyordu — yani plpgsql. Ama bu depoda
                # `returns table(...) language sql as $$ select ... $$` biciminde
                # ONLARCA fonksiyon var ve onlar HIC TARANMIYORDU. 34
                # fonksiyonun 9'unu okuyup "temiz" demek, kapsami raporlamadan
                # yesil yanmaktir. Iki bicimi de deniyoruz.
                sm2 = (re.search(r'return\s+query\s+select\s+(.*?)\s+from\s', govde, re.I | re.S)
                       or re.search(r'as\s*\$[a-z_]*\$\s*select\s+(.*?)\s+from\s', govde, re.I | re.S))
                if not sm2:
                    continue
                adlar = takma_adlar(govde)
                def bol(metin_):
                    ps, d, c = [], 0, ''
                    for ch in metin_:
                        if ch in '([': d += 1
                        if ch in ')]': d -= 1
                        if ch == ',' and d == 0:
                            ps.append(c); c = ''
                        else:
                            c += ch
                    ps.append(c); return ps
                ilanlar2 = []
                for pp in bol(ilan_metin):
                    pp = ' '.join(pp.split())
                    if not pp or ' ' not in pp:
                        continue
                    i2 = pp.find(' ')
                    ilanlar2.append((pp[:i2], pp[i2+1:].strip()))
                for i3, ifd in enumerate(bol(sm2.group(1))):
                    if i3 >= len(ilanlar2):
                        break
                    ifd = ' '.join(ifd.split())
                    bm2 = re.fullmatch(r'([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*)', ifd, re.I)
                    if not bm2:
                        continue
                    takma2, ad2 = bm2.group(1).lower(), bm2.group(2).lower()
                    # 🔴 HIZA GUVENCESI. Ilk kosuda sutun 7'nin ilanini
                    # sutun 7'nin ifadesiyle eslestirdim ve hizalama kaydigi
                    # icin "visit_date ILAN date · GERCEK text (v.flight_number)"
                    # gibi sacma bulgular cikti — ayristirici, select
                    # listesindeki bir ifadeyi yanlis sutuna denk getirmisti.
                    # Cozum: yalniz ADI TUTAN ciplak kolonu karsilastir.
                    # Gercek hatada ad zaten tutuyordu (airport_code ↔
                    # a.airport_code). Boylece denetim daha DAR ama
                    # yanilmaz olur; genis ve yalanci olmasindansa.
                    if ad2 != ilanlar2[i3][0].lower():
                        continue
                    aday2 = kols.get(ad2)
                    if not aday2:
                        continue
                    tablo2 = adlar.get(takma2)
                    if tablo2 and tablo2 in aday2:
                        g2 = aday2[tablo2]                 # takma addan COZULDU
                    else:
                        tip2 = set(aday2.values())
                        if len(tip2) != 1:
                            continue                       # gercekten belirsiz
                        g2 = tip2.pop()
                    if not denk(ilanlar2[i3][1], g2):
                        dosya_bulgu.append(
                            f'{fn} · {fad}() sutun {i3+1} "{ilanlar2[i3][0]}": '
                            f'ILAN {ilanlar2[i3][1]} · GERCEK {g2} ({ifd})')

    print('=' * 72)
    print('TIP DENETIMI — returns table sozlesmesi (veri gerekmez)')
    print('=' * 72)
    print(f'  {len(fns)} returns-table fonksiyonu · {incelenen} tanesinde select listesi okundu')
    print(f'  {cozulen} sutun cozuldu · {atlanan} sutun atlandi (ifade/belirsiz kolon)')
    hepsi = bulgular + dosya_bulgu
    if dosya_bulgu:
        print(f'  DOSYA taramasi: {len(dosya_bulgu)} bulgu (ara hâller dahil)')
    if hepsi:
        print(f'\n  ✗ {len(hepsi)} TIP UYUSMAZLIGI:')
        for b in hepsi:
            print('      ' + b)
        print('\n  Bu hatalar SATIR YOKKEN CIKMAZ. Bos bir veritabaninda migration')
        print('  temiz gorunur, CANLIDA ILK SATIRDA patlar. Cast ekle: kolon::text')
        return 1
    print('\n  ✓ ilan edilen tip ile kaynak kolon tipi uyusmayan sutun yok (canli + dosyalar)')
    return 0

if __name__ == '__main__':
    sys.exit(main())
