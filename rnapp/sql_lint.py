#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · sql_lint.py   (v2.04'te doğdu)

NEDEN VAR — BU OTURUMDA CANLIDA PATLAYAN İKİ HATA SINIFI:

  1) 22P02 malformed array literal
       v_notes text[] := '{}';
       v_notes := v_notes || 'düz metin';        -- ❌
     PostgreSQL literalin tipini bilmediği için `array_cat(text[], text[])`
     seçiyor ve metni diziye çevirmeye çalışıyor. Doğrusu:
       v_notes := v_notes || ('düz metin')::text;  -- ✅ array_append
     `format(...)` ya da başka bir text ifadesi kullanıldığında sorun YOK;
     yalnız TİPSİZ literal belirsizlik yaratıyor.

  2) 22P02 invalid input value for enum
       insert into availabilities (..., visibility) values (..., 'all')
     Enum'da 'all' yok (Public/Connections/Hidden). Uygulama RPC üzerinden
     yazdığı için görülmüyordu; doğrudan tabloya yazan SEED patladı.

Bu iki hata da SÖZDİZİMİ AÇISINDAN GEÇERLİ; ayrıştırıcı yakalayamaz,
ancak çalıştırınca ortaya çıkar. Bu ortamda PostgreSQL olmadığı için
maliyeti hep Gokberk ödüyordu. Bu denetim o maliyeti buraya taşıyor.

SINIR: metin taraması yapar. `insert ... select` içindeki dolaylı enum
atamalarını göremez; gördüğü, açık literal atamalarıdır.
"""
import os
import re
from sql_mask import mask_bodies
import sys

import ll_paths


def enum_values(schema_path):
    """Şema dökümündeki `- **enum_adi**: a, b, c` satırlarını okur."""
    out = {}
    for line in open(schema_path, encoding='utf-8'):
        m = re.match(r'^-\s+\*\*([a-z_]+)\*\*:\s*(.+)$', line.strip())
        if m:
            out[m.group(1)] = {v.strip() for v in m.group(2).split(',') if v.strip()}
    return out


def enum_columns(schema_path):
    """`| kolon | USER-DEFINED | ... | 'x'::enum_adi |` satırından
    (TABLO, kolon) -> enum eşlemesi çıkarır.

    🔴 ESKİ HÂLİ TABLOYU YOK SAYIYORDU ve YANLIŞ ALARM veriyordu:
    `users.role` bir user_role enum'u olduğu için, `role` ADINI taşıyan
    HER kolonu enum sanıyordu. SQL 194'te `waitlist.role` düz bir text
    kolonu (kendi check kısıtı var) ve denetim iki kez
    "'misafir' user_role enum'unda YOK" dedi — ürün doğruydu, ARAÇ
    yanlıştı.

    Bu, bu projede üçüncü kez yaşanan sınıf: 187 turunda üç denetim
    birden dolar-tırnaklı gövdeleri kod sanmıştı. Yanlış alarm veren
    bir denetim, üç tur sonra okunmaz hâle gelir ve o andan sonra
    GERÇEK hatayı da yakalayamaz. `npm run verify`'ın kırmızısı
    anlamlı kalmalı.
    """
    cols = {}
    tbl = None
    for line in open(schema_path, encoding='utf-8'):
        h = re.match(r'^###\s+([a-z_]+)', line.strip())
        if h:
            tbl = h.group(1)
            continue
        m = re.match(r"^\|\s*`([a-z_]+)`\s*\|\s*USER-DEFINED\s*\|[^|]*\|\s*'[^']*'::([a-z_]+)", line.strip())
        if m and tbl:
            cols.setdefault((tbl, m.group(1)), m.group(2))
    return cols


def main():
    d, files = ll_paths.require_sql('sql_lint')
    schema = ll_paths.schema_file()
    enums = enum_values(schema) if schema else {}
    ecols = enum_columns(schema) if schema else {}

    problems = []

    # --- 1) text[] || 'literal' (cast yok) ---
    # 🔴 22 AGUSTOS — BU DESEN KENDI ONERDIGI DUZELTMEYI DE YAKALIYORDU.
    # Eski hali: r"(\w+)\s*:=\s*\1\s*\|\|\s*'" — tirnaktan SONRASINA
    # hic bakmiyordu. Yani nobetci "('...')::text yaz" diyor, yazinca
    # yine kirmizi yaniyordu. 237'yi yazarken tam bunu yasadim: castleri
    # koydum, 9 bulgu 9 olarak kaldi.
    #
    # 🆕 SINIF: **"KENDI ONERDIGI DUZELTMEYI KABUL ETMEYEN BIR NOBETCI,
    # KURALI DEGIL GURULTUYU BUYUTUR."** (Kardesi: check.js'in kendi
    # yorumunu yakalamasi — yorum ayiklama oradan geldi.)
    #
    # Yeni hali: literalden sonra `::tip` ya da `)::tip` GELMIYORSA yakala.
    arr = re.compile(r"(\w+)\s*:=\s*\1\s*\|\|\s*'[^']*'(?!\s*(?:\)\s*)?::)", re.I)
    # --- 2) insert ... (kolonlar) values (...) icinde enum kolonu ---
    ins = re.compile(r"insert\s+into\s+(\w+)\s*\(([^)]*)\)\s*values\s*([\s\S]{0,4000}?);", re.I)

    for f in files:
        src = open(f, encoding='utf-8', errors='replace').read()
        base = os.path.basename(f)

        # text[] degiskenlerini bul
        arrvars = set(re.findall(r'\b(\w+)\s+text\[\]', src, re.I))
        for m in arr.finditer(src):
            if m.group(1) in arrvars:
                line = src[:m.start()].count('\n') + 1
                problems.append((base, line, 'dizi',
                                 f"{m.group(1)} text[] degiskenine TIPSIZ literal ekleniyor",
                                 f"{m.group(1)} := {m.group(1)} || ('...')::text;"))

        # enum kolonuna gecersiz literal
        for m in ins.finditer(src):
            cols = [c.strip().strip('"') for c in m.group(2).split(',')]
            body = m.group(3)
            for idx, c in enumerate(cols):
                en = ecols.get((m.group(1).lower(), c))
                if not en or en not in enums:
                    continue
                for row in re.finditer(r'\(([^()]*)\)', body):
                    vals = [v.strip() for v in row.group(1).split(',')]
                    if len(vals) != len(cols) or idx >= len(vals):
                        continue
                    v = vals[idx]
                    lit = re.fullmatch(r"'([^']*)'(?:::\w+)?", v)
                    if lit and lit.group(1) not in enums[en]:
                        line = src[:m.start()].count('\n') + 1
                        problems.append((base, line, 'enum',
                                         f"{m.group(1)}.{c} = '{lit.group(1)}' — {en} enum'unda YOK",
                                         'gecerli: ' + ', '.join(sorted(enums[en]))))

    # --- 3) CHECK kisitiyla celisen UPDATE ---
    # 🔴 lva_included_chk: (guest_policy='included' or guest_included_count=0)
    # 096'daki bir update politikaya bakmadan sayiyi 1 yapip
    # 'not_allowed' bir satira carpti -> 23514.
    # Genel kural: KOSULLU bir kolonu yazan UPDATE, kosulun DAYANDIGI
    # kolonu WHERE'inde tutmali. Yoksa kisit canlida patlar.
    upd = re.compile(r"(update\s+lounge_venue_acceptance[\s\S]{0,1800}?);", re.I)
    for f in files:
        raw = open(f, encoding='utf-8', errors='replace').read()
        # 🔴 YORUMLARI IFADEYI BOLMEDEN ONCE AT.
        # Kendi acikayici yorumumda gecen bir NOKTALI VIRGUL ("anlamlidir;")
        # ifadeyi erken kesiyordu; WHERE'in son satiri disarida kaliyor ve
        # denetim DUZELTILMIS dosyayi hatali sayiyordu. Yorum, ifadenin
        # parcasi degildir — once temizle, sonra bol.
        src = re.sub(r'--[^\n]*', ' ', raw)
        for m in upd.finditer(src):
            # 🔴 YORUMLARI AT. Ilk denememde kuralin kendi aciklama satirinda
            # "guest_policy" gectigi icin kontrol HEP geciyordu — mutasyon
            # testi bunu yakaladi. Denetim, kendi yorumunu kanit sayamaz.
            st = m.group(1)
            g = re.search(r"guest_included_count\s*=\s*([^,\n]+)", st)
            if not g or g.group(1).strip() == '0':
                continue
            if 'guest_policy' not in st:
                line = src[:m.start()].count('\n') + 1
                problems.append((os.path.basename(f), line, 'kisit',
                                 "guest_included_count sifirdan farkli yapiliyor ama "
                                 "WHERE'de guest_policy YOK",
                                 "ekle: and guest_policy = 'included'  "
                                 "(kisit: lva_included_chk)"))

    # --- 4) IFADELER ARASI TABLO BAGIMLILIGI ---
    # 🔴 UC KEZ YASADIK (099, 103, 113): bir migration `create table _x`
    # yapip sonraki ifadede kullaniyor. Benim harness'imda calisiyor
    # (tek psql oturumu) ama Supabase SQL Editor ifadeleri AYRI
    # calistirdigi icin canlida "42P01 relation _x does not exist" veriyor.
    #
    # Bende gecip sende patlayan bir kalip, en kotu kalip turudur:
    # yesil gorup gonderiyorum, maliyeti sen oduyorsun.
    # Kural: migration ifadeler arasi GECICI DURUMA guvenmemeli.
    # Cozum CTE ya da tek `do $$` blogu.
    mk = re.compile(r'create\s+(?:temp\s+)?table\s+(?:if not exists\s+)?(_\w+)', re.I)
    for f in files:
        # 🔴 187 turu: 176/178/179'da `create temp table _akis_tmp` bir
        # FONKSIYON GOVDESININ icindeydi. Govde tek ifadedir; Supabase
        # onu bolmez, 42P01 olmaz. Denetim govde ile top-level'i
        # ayirt etmedigi icin uc yanlis alarm veriyordu.
        src = mask_bodies(open(f, encoding='utf-8', errors='replace').read())
        for m in mk.finditer(src):
            name = m.group(1)
            after = src[m.end():]
            # ayni ifadede degil, SONRAKI ifadelerde kullaniliyor mu?
            tail = after.split(';', 1)[1] if ';' in after else ''
            if re.search(r'\b' + re.escape(name) + r'\b', tail):
                line = src[:m.start()].count('\n') + 1
                problems.append((os.path.basename(f), line, 'bagimlilik',
                                 f'{name} tablosu SONRAKI ifadelerde kullaniliyor',
                                 'Supabase ifadeleri ayri calistirir -> 42P01. '
                                 'CTE ya da tek do-blogu kullan.'))

    # --- 5) NULL, DESC SIRALAMADA EN BASA CIKAR ---
    # 🔴 144'te bu tuzak urunun en cok sorulan sorusuna YANLIS cevap
    # verdirdi: `order by (x.card_tier = p_tier) desc` yazdim; card_tier
    # NULL oldugunda karsilastirma false DEGIL **NULL** doner ve
    # PostgreSQL'in varsayilan NULLS FIRST kurali onu en basa tasir.
    # Elite Plus'a "misafir goturemezsin" dedirtiyordu.
    #
    # Sozdizimi gecerli, calisir, hata vermez — sadece YANLIS SIRALAR.
    # En sinsi hata turu: sessizce yanlis cevap.
    nullsort = re.compile(
        r'order\s+by[^;]*?\(\s*\w+\.\w+\s*=\s*[^)]+\)\s*desc', re.I | re.S)
    for f in files:
        src = re.sub(r'--[^\n]*', ' ', open(f, encoding='utf-8', errors='replace').read())
        for m in nullsort.finditer(src):
            seg = m.group(0)
            if 'coalesce' in seg.lower() or 'nulls last' in seg.lower():
                continue
            line = src[:m.start()].count('\n') + 1
            problems.append((os.path.basename(f), line, 'nullsort',
                             'ORDER BY (kolon = deger) DESC — kolon NULL ise EN BASA cikar',
                             'coalesce(kolon = deger, false) yaz ya da NULLS LAST ekle.'))

        # ── 🔴 IFADE ARASI GECICI TABLO (42P01) ─────────────────────
        # 18 Agustos 2026, Gokberk canlida:
        #     ERROR 42P01: relation "_tz_src" does not exist   (202)
        # Supabase SQL Editor ifadeleri AYRI BAGLANTILARDA calistirabiliyor.
        # Bir ifadede yaratilan gecici tablo, sonraki ifadede YOK.
        # psql tek oturumda calistigi icin harness bunu HIC gormuyor —
        # yani bu, ortam farkindan dogan ve yalniz CANLIDA cikan bir sinif.
        #
        # 099 bu tuzaga zaten dusmus ve dosyasina yazmis ("Once create
        # temp table denedim ... 42P01 verdi ... Kok cozum: ifadeler
        # arasi bagimliligi TAMAMEN kaldirmak"). Ders yaziliydi ama
        # KURALA donusmedigi icin 202'de tekrarlandi. Simdi kural.
        #
        # 🔴 DOLAR-TIRNAKLI HER BOLGE TEK BIR IFADEDIR — hepsini ele.
        # Ilk surumde yalniz `do $$...$$` bloklarini ayikliyordum ve uc
        # dosyada YANLIS ALARM verdim: 176/178/179'daki gecici tablolar
        # DO blogunda degil, bir FONKSIYON GOVDESINDE (`... as $$`).
        # Ikisi de tek ifade icinde calisir, ikisi de guvenli. Yanlis
        # alarm ureten bir denetim, olmayan denetimden kotudur: guveni
        # asindirir ve gercek bulguyu gurultuye gomer.
        #
        # Bolgeleri AYNI UZUNLUKTA boslukla degistiriyorum ki satir
        # numaralari kaymasin.
        def _dolar_sil(metin):
            out, i, n = [], 0, len(metin)
            desen = re.compile(r'\$([a-zA-Z_][a-zA-Z0-9_]*)?\$')
            while i < n:
                m2 = desen.match(metin, i)
                if m2:
                    etiket = m2.group(0)
                    j = metin.find(etiket, m2.end())
                    if j >= 0:
                        parca = metin[i:j + len(etiket)]
                        out.append(re.sub(r'[^\n]', ' ', parca))
                        i = j + len(etiket)
                        continue
                out.append(metin[i]); i += 1
            return ''.join(out)

        dosuz = _dolar_sil(src)

        # ── 🔴 AYNI DOSYADA ENUM DEGERI EKLEYIP KULLANMAK (55P04) ────
        # 18 Agustos 2026, Gokberk canlida:
        #     ERROR 55P04: unsafe use of new value "yolcu" of enum plan_type
        #     HINT: New enum values must be committed before they can be used.
        # `alter type ... add value` ile eklenen deger AYNI ISLEMDE
        # kullanilamaz. psql her ifadeyi ayri islemde kosuyor, Supabase
        # SQL Editor betigi TEK ISLEM olarak sariyor — yani bu da
        # yalniz canlida cikan bir sinif.
        #
        # 🔴 210'un YORUMUNDA bu risk ZATEN yaziliydi ("...BEGIN/COMMIT
        # icine alinirsa cikar") ama kurala donusmedigi icin dosyada
        # kaldi. Bir yorumda duran uyari, denetime donusmediyse dipnottur.
        #
        # AYRIM ONEMLI: 066 ve 080 de enum'a deger ekliyor ama sorun
        # cikarmiyor — oradaki degerler yalniz FONKSIYON GOVDESI icinde,
        # yani dolar-tirnakli bolgede METIN olarak geciyor ve gövde
        # tanimlanirken degerlendirilmiyor. O yuzden arama `dosuz`
        # (dolar-tirnaklar silinmis metin) uzerinde yapiliyor.
        eklenen = re.findall(
            r"alter\s+type\s+\S+\s+add\s+value\s+(?:if\s+not\s+exists\s+)?'([^']+)'",
            dosuz, re.I)
        if eklenen:
            kalan = re.sub(r"alter\s+type\s+\S+\s+add\s+value[^;]*;", ' ', dosuz, flags=re.I)
            for deger in sorted(set(eklenen)):
                m3 = re.search(r"'" + re.escape(deger) + r"'", kalan)
                if m3:
                    line = kalan.count('\n', 0, m3.start()) + 1
                    problems.append((os.path.basename(f), line, 'enumislem',
                                     f'enum degeri "{deger}" AYNI DOSYADA eklenip kullaniliyor',
                                     'Eklemeyi ayri bir <n>a_PRE_ dosyasina al; yeni enum '
                                     'degeri eklendigi ISLEMDE kullanilamaz.'))

        for m in re.finditer(r'create\s+temp(?:orary)?\s+table\s+(?:if\s+not\s+exists\s+)?'
                             r'"?([a-zA-Z_][a-zA-Z0-9_]*)"?', dosuz, re.I):
            line = dosuz.count('\n', 0, m.start()) + 1
            problems.append((os.path.basename(f), line, 'gecici',
                             f'ifade DISINDA gecici tablo "{m.group(1)}" — '
                             'Supabase ifadeleri ayri baglantida kosabilir',
                             'Listeyi her ifadenin ICINDE bir CTE yap (bkz. 099), '
                             'ya da tum isi tek bir DO blogunun icine al.'))

    # ── MIGRATION NUMARA ÇAKIŞMASI ──────────────────────────────────
    # 🔴 GÖKBERK İKİ FARKLI "250" ALDI VE SORDU: HANGİSİNİ ÇALIŞTIRACAĞIM?
    # Yeni bir migration yazarken sıradaki numarayı VARSAYDIM; klasöre
    # bakmadım. 250 zaten alınmıştı. Migration'lar ad sırasına göre
    # koşuyor — aynı numaradan iki dosya, sıralamayı belirsiz bırakır ve
    # çalıştıran kişiyi ikisinden birini seçmek zorunda bırakır.
    #
    # Bu, ölçmesi en kolay kusur sınıfından: bir dizin listesi ve bir
    # sayaç. Kolay ölçülen bir şeyi ölçmemek, ölçmeyi unutmaktır.
    #
    # 🆕 SINIF: "SIRADAKİ NUMARAYI HATIRLAMA — SAY. VE SAYMAYI BİR
    # DENETİME BIRAK, ÇÜNKÜ SEN BİR DAHAKİ SEFERE YİNE HATIRLAYACAKSIN."
    import collections
    numara = collections.defaultdict(list)
    for f in files:
        b = os.path.basename(f)
        m = re.match(r'^(\d{3})_', b)
        if m:
            numara[m.group(1)].append(b)
    cakisan = {n: v for n, v in numara.items() if len(v) > 1}

    print('=' * 72)
    print('SQL LINT — sozdizimi gecerli ama CALISINCA patlayan kaliplar')
    print('=' * 72)
    print(f'SQL: {d} · dosya: {len(files)} · enum: {len(enums)} · '
          f'numara cakismasi: {len(cakisan)}\n')

    if cakisan:
        for n, v in sorted(cakisan.items()):
            print(f'✗ {n} numarasi {len(v)} dosyada: ' + ' · '.join(sorted(v)))
        print('    -> Migration ad sirasina gore kosuyor; ayni numaradan iki dosya')
        print('       sirayi belirsiz birakir. Sonrakini bos bir numaraya tasi.')
        return 1

    # ══════════════════════════════════════════════════════════════════
    # 🔴 GÖRÜNMEYEN CEVAP KURALI  (29 Ağustos)
    #
    # Bu turda ÜÇ KEZ aynı hatayı yaptım: bir SQL dosyasının belirleyici
    # cevabını `raise notice` içine koydum. Supabase SQL Editor bunları
    # ayrı bir "Messages" panelinde gösteriyor; kullanıcı sonuç sekmesine
    # bakıyor ve orada HİÇBİR ŞEY yok.
    #
    #   000_HANGI_SQL_KURULU  → "hiçbir şey dönmüyor" (yeniden yazıldı)
    #   270a_GORUNURLUK       → karar notice'ta kaldı
    #   270b_NEDEN_SIZIYOR    → §3'ün cevabı notice'ta kaldı
    #
    # Bir kere yapmak dikkatsizlik, üç kere yapmak alışkanlıktır — ve
    # alışkanlık ancak yazılı bir kuralla durur.
    #
    # KURAL: adında BAK / KONTROL / KARAR / DOGRULAMA / RAPOR / KURULU /
    # GORUNURLUK geçen bir dosya, yani SORU SORAN bir dosya, cevabını
    # TABLOYLA vermek zorundadır — son anlamlı ifadesi `select` olmalı.
    #
    # 🆕 SINIF: "BİR ÇIKTI KANALI KULLANICIYA GÖRÜNMÜYORSA, O KANALA
    # YAZILAN HER ŞEY YAZILMAMIŞ SAYILIR."
    SORAN = ('bak', 'kontrol', 'karar', 'dogrulama', 'rapor',
             'kurulu', 'gorunurluk', 'neden_siziyor', 'saglik')
    gorunmez = []
    for f in files:
        ad = os.path.basename(f).lower()
        if not any(k in ad for k in SORAN):
            continue
        ham = open(f, encoding='utf-8', errors='ignore').read()
        # Yorumları at, sonra son anlamlı ifadeye bak.
        g = re.sub(r'/\*[\s\S]*?\*/', ' ', ham)
        g = re.sub(r'--[^\n]*', ' ', g)
        # ⚠️ DEĞİŞİKLİK YAPAN DOSYA BU KURALIN DIŞINDA.
        # `192_on_kontrol_…` bir göçün ÖN KONTROLÜ: sorusuna `raise
        # exception` ile cevap verir ve göçü durdurur — bu doğru davranış,
        # tablo döndürmesi gerekmez. Kural yalnız SALT OKUNUR soru
        # dosyaları için geçerli.
        # 🆕 SINIF: "BİR KURALI YAZARKEN İSTİSNASINI DA ÖLÇ — ADI UYAN
        # AMA İŞİ FARKLI OLAN DOSYA, KURALIN İLK YANLIŞ ALARMIDIR."
        if re.search(r'\b(create|alter|insert|update|delete|drop|grant|revoke)\s',
                     g, re.I):
            continue
        ifadeler = [x.strip() for x in g.split(';') if x.strip()]
        if not ifadeler:
            continue
        son = ifadeler[-1].lower()
        # `select ... from` ile BAŞLIYORSA tablo döndürüyordur.
        # (`select fn()` de tablo döndürür — o da kabul.)
        if not re.match(r'^\s*(with|select)\b', son):
            gorunmez.append((os.path.basename(f),
                             son.split('\n')[0][:60]))

    if gorunmez:
        print('\n✗ GORUNMEYEN CEVAP — soru soran dosya tablo dondurmuyor:')
        for ad, son in gorunmez:
            print(f'    {ad}  (son ifade: {son}…)')
        print('    -> Supabase yalniz SON SELECT\'in tablosunu gosterir.')
        print('       `raise notice` kullaniciya GORUNMEZ. Cevabi SELECT ile ver.')
        return 1

    if not problems:
        print('✓ tipsiz dizi · gecersiz enum · gecici tablo · enum-islem sinir ihlali yok')
        print('✓ soru soran her dosya cevabini TABLOYLA veriyor')
        return 0

    seen = set()
    for base, line, kind, msg, fix in problems:
        key = (base, line, msg)
        if key in seen:
            continue
        seen.add(key)
        print(f'✗ {base}:{line}  [{kind}]  {msg}')
        print(f'    -> {fix}')
    kinds = {k for _, _, k, _, _ in problems}
    codes = ', '.join(sorted({'22P02' if k in ('dizi','enum') else ('42P01' if k in ('bagimlilik','gecici') else ('55P04' if k=='enumislem' else ('SIRALAMA' if k=='nullsort' else '23514'))) for k in kinds}))
    print(f'\n✗ {len(seen)} sorun. Bunlar CANLIDA {codes} verir.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
