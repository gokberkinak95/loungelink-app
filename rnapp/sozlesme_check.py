#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · sozlesme_check.py   (v2.78'de doğdu)

🔴 NEDEN VAR — HATA SINIFI 21:
   "SÖZLEŞMEYİ DEĞİŞTİREN MIGRATION, ÇAĞIRICILARI DA AYNI DOSYADA
    DÜZELTMEK ZORUNDADIR."

ÖLÇÜLEN OLAY (212 turu):
  · 209 → `partner_gate(uuid,uuid) returns UUID` (yetkili kullanıcının
    kimliği) ve aynı dosyadaki BEŞ fonksiyon `v_uid := partner_gate(...)`
    diyor; `v_uid` UUID olarak bildirilmiş.
  · 212 → aynı kapıyı bayrağa bağlamak için sarmaladı ve sarmalayıcıyı
    `returns BOOLEAN` yazdı.
  · Çalışma zamanı sonucu:
        22P02  invalid input syntax for type uuid: "f"
    Sağlayıcı panelinin beş ekranı birden düştü.

NEDEN HİÇBİR NÖBETÇİ YAKALAMADI:
  Her migration KENDİ ANINDA doğruydu. 209'un nöbetçileri 209 çalışırken
  geçti — 212 henüz yoktu. 212'nin nöbetçileri de geçti — 209'un
  çağırıcılarına kimse bakmadı. `returns_check.py` DOSYALARI okur, yani
  "bu dosya kendi içinde tutarlı mı" sorusunu sorar. `wrapper_check.py`
  yalnız `_impl` çiftlerine bakar. İkisi de "SONRAKİ dosya ÖNCEKİ dosyanın
  çağırıcılarını bozdu mu?" sorusunu soramaz, çünkü o soru ancak
  MIGRATION'LARIN TAMAMI ÇALIŞTIKTAN SONRA cevaplanabilir.

  Bu dosya tam olarak o anda çalışır: pg_run.py bütün migration'ları
  çalıştırdıktan SONRA, gerçek `pg_proc` kataloğunu okuyarak.

NE ÖLÇER (tahmin değil, katalog):
  1) ÇAĞIRICI SÖZLEŞMESİ — her plpgsql gövdesindeki `v_x := f(...)`
     ataması bulunur, `v_x`in DECLARE'deki tipi ile `f`in GERÇEK dönüş
     tipi karşılaştırılır. Uyumsuzsa çalışma zamanında 22P02/42804 gelir.
  2) SARMALAYICI/DELEGE — `X` ile `X_preflag` / `X_impl` / `X_base` /
     `X_prebfilter` / `X_prerank` çiftlerinde, sarmalayıcı delegenin
     sonucunu DOĞRUDAN döndürüyorsa (`return public.X_preflag(...)`)
     dönüş tipleri aynı olmak ZORUNDADIR.

⚠️ NEDEN DÜZ "prorettype eşit mi" DEĞİL — ÖLÇTÜM:
  Bugünkü ŞEMADA `partner_gate` boolean, `partner_gate_preflag` uuid
  döndürüyor ve bu DOĞRU: 213 kapıyı bilerek boolean sözleşmesine taşıdı,
  sarmalayıcı delegenin sonucunu `v_uid uuid` değişkenine alıp
  `v_uid is not null` diye ÇEVİRİYOR ve beş çağırıcıyı da aynı dosyada
  düzeltti. Düz karşılaştırma bunu KIRMIZI yakardı — yani doğru çalışan
  bir tasarımı hata gibi gösterirdi. Yanlış alarm veren denetim, olmayan
  denetimden kötüdür (bu dersi `sql_lint` ve v2.68 zaten yazdı).
  Bu yüzden ölçüt "tip farklı mı" değil, "FARK ÇEVRİLMEDEN KULLANILIYOR
  mu": doğrudan dönüş ya da yanlış tipte değişkene atama.

SINIR (dürüstçe): yalnız `:=` atama bağlamını ve doğrudan dönüşü görür.
`select ... into v_x from f(...)` ve dinamik `execute` çağrıları bu
denetimin dışındadır. Gördüğü kadarını KESİN görür, göremediğini de
söyler — sessizce "temiz" demez.

KULLANIM: pg_run.py bu modülü migration'lardan sonra çağırır. Tek başına:
    python3 sozlesme_check.py "postgresql://..."   (canlı bir şemaya karşı)
"""
import csv
import io
import os
import re
import sys

# Kaç şey ölçüldüğü RAPORLANIR. Sıfır satır ölçüp "temiz" demek, bu
# depodaki en pahalı hata sınıfı (bkz. ll_paths.py başlığı).
OLCUM = {}


# ============================================================
# TİP EŞDEĞERLİĞİ
# ============================================================
# Aynı tipin farklı yazımları 22P02 ÜRETMEZ; bunları fark saymak yanlış
# pozitif üretir. (returns_check.py ile aynı sözlük — orada da aynı ders.)
ALIAS = {
    'int': 'integer', 'int4': 'integer', 'int2': 'smallint', 'int8': 'bigint',
    'bool': 'boolean', 'varchar': 'text', 'character varying': 'text',
    'bpchar': 'character', 'timestamptz': 'timestamp with time zone',
    'timestamp': 'timestamp without time zone', 'time': 'time without time zone',
    'timetz': 'time with time zone', 'float8': 'double precision',
    'float4': 'real', 'decimal': 'numeric',
}

# Aynı AİLE içindeki atama, açık bir cast olmasa bile güvenlidir:
# PostgreSQL metin G/Ç çevrimi yapar ve değer her zaman geçerlidir.
# (`v_int integer := bigint_donen_fn()` gibi.) Aileler arası çevrim ise
# değere bağlıdır — 212'nin boolean→uuid'i tam olarak buydu.
AILELER = [
    {'integer', 'smallint', 'bigint', 'numeric', 'double precision', 'real', 'money'},
    {'text', 'character', 'name', 'citext', 'uuid'},   # uuid: metinden okunabilir
    {'timestamp with time zone', 'timestamp without time zone', 'date',
     'time without time zone', 'time with time zone', 'interval'},
    {'json', 'jsonb'},
]

# Tipi çözemediğimiz durumlar — SESSİZCE geçilir ama SAYILIR.
BELIRSIZ = {'record', 'any', 'anyelement', 'anyarray', 'trigger', 'void',
            'unknown', 'refcursor', 'cursor'}


def norm(t):
    """Tip adını tek yazıma indirger. TAM eşleşme — kısmi eşleşme
    `time` → `time without time zone` → tekrar genişletme hatasını
    üretiyordu (returns_check.py'de ölçüldü)."""
    t = (t or '').strip().lower().rstrip(';')
    t = re.sub(r'\s+', ' ', t)
    t = re.sub(r'^public\.', '', t)
    t = re.sub(r'\(\d+(,\s*\d+)?\)$', '', t)          # numeric(10,2) → numeric
    dizi = t.endswith('[]')
    if dizi:
        t = t[:-2].strip()
    t = ALIAS.get(t, t)
    return t + ('[]' if dizi else '')


def uyumlu(hedef, kaynak, cast_ciftleri):
    """`hedef_degisken := kaynak_fonksiyon()` ataması güvenli mi?

    True dönerse "çalışma zamanında tip yüzünden patlamaz" demektir."""
    h, k = norm(hedef), norm(kaynak)
    if not h or not k:
        return True
    if h == k:
        return True
    if h in BELIRSIZ or k in BELIRSIZ:
        return True
    # TABLE(...) / SETOF ... dönenler skaler bir değişkene atanamaz —
    # bu GERÇEK bir uyumsuzluktur, belirsizlik değil.
    if k.startswith('table(') or k.startswith('setof '):
        return False
    if h.endswith('[]') != k.endswith('[]'):
        return False
    hb, kb = h.rstrip('[]'), k.rstrip('[]')
    for aile in AILELER:
        if hb in aile and kb in aile:
            return True
    # PostgreSQL'in KENDİ bildiği bir çevrim varsa (pg_cast) sorun yok.
    if (kb, hb) in cast_ciftleri:
        return True
    return False


# ============================================================
# KATALOĞU OKU
# ============================================================
def _fonksiyonlar(kopyala):
    return kopyala("""
        select p.oid::text, p.proname, l.lanname,
               pg_get_function_result(p.oid), p.prosrc
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          join pg_language l on l.oid = p.prolang
         where n.nspname = 'public' and p.prokind = 'f'""")


def _cast_ciftleri(kopyala):
    """pg_cast: PostgreSQL'in bildiği çevrimler. Bunları ELLE yazmak
    yerine veritabanına SORUYORUZ — tahmin etmemenin ucuz yolu."""
    ciftler = set()
    for kaynak, hedef in kopyala("""
        select format_type(castsource, null), format_type(casttarget, null)
          from pg_cast"""):
        ciftler.add((norm(kaynak), norm(hedef)))
    return ciftler


def deklarasyonlar(prosrc):
    """plpgsql gövdesinin DECLARE bölümündeki değişken → tip eşlemesi.

    Yalnız EN BAŞTAKİ declare bloğuna bakar: iç bloklardaki yeniden
    bildirimleri karıştırmamak için (yanlış tip → yanlış alarm)."""
    m = re.match(r'\s*declare\b(.*?)\bbegin\b', prosrc, re.S | re.I)
    if not m:
        return {}
    out = {}
    for stmt in m.group(1).split(';'):
        s = re.sub(r'--[^\n]*', ' ', stmt).strip()
        if not s:
            continue
        s = re.split(r':=|\bdefault\b', s, flags=re.I)[0].strip()
        s = re.sub(r'\bconstant\b', ' ', s, flags=re.I).strip()
        parts = s.split()
        if len(parts) < 2:
            continue
        tip = ' '.join(parts[1:])
        # `availabilities%rowtype` / `users.id%type` çözülemez → atla.
        if '%' in tip:
            continue
        out[parts[0].lower()] = tip
    return out


# ============================================================
# 1) ÇAĞIRICI SÖZLEŞMESİ
# ============================================================
# `v_uid := public.partner_gate(...)` — 212'nin kırdığı tam olarak bu
# satırdı ve beş kere geçiyordu. Denetim bunu ATAMA BAĞLAMINDAN okur:
# değişkenin BİLDİRİLEN tipi, fonksiyonun GERÇEK dönüş tipiyle
# karşılaştırılır.
_ATAMA = re.compile(r'(\w+)\s*:=\s*(?:public\.)?(\w+)\s*\(', re.I)


def cagirici_sozlesmesi(kopyala):
    fns = _fonksiyonlar(kopyala)
    if not fns:
        return ['OLCUM YAPILAMADI: public semasinda hic fonksiyon okunamadi']
    donus = {}
    for _oid, ad, _lang, ret, _src in fns:
        donus.setdefault(ad.lower(), set()).add(ret)
    castlar = _cast_ciftleri(kopyala)

    ihlal, sayac, atlanan = [], 0, 0
    for _oid, ad, lang, _ret, src in fns:
        if lang != 'plpgsql':
            continue
        dv = deklarasyonlar(src)
        if not dv:
            continue
        for m in _ATAMA.finditer(src):
            deg, fn = m.group(1).lower(), m.group(2).lower()
            if fn not in donus or deg not in dv:
                continue
            # Aşırı yüklenmiş fonksiyonda hangi imzanın çağrıldığını
            # metinden bilemeyiz; TAHMİN ETMEK yerine SAYIP GEÇİYORUZ.
            if len(donus[fn]) > 1:
                atlanan += 1
                continue
            fret = next(iter(donus[fn]))
            sayac += 1
            if not uyumlu(dv[deg], fret, castlar):
                ihlal.append(
                    f'{ad}: {deg} {norm(dv[deg])} := {fn}() -> {norm(fret)} '
                    f'(cagirici eski sozlesmeyi varsayiyor)')
    OLCUM['atama'] = sayac
    OLCUM['atama_atlanan'] = atlanan
    return ihlal


# ============================================================
# 2) SARMALAYICI ↔ DELEGE
# ============================================================
# 212'nin İKİNCİ yarısı: sarmalayıcı `returns boolean` yazıp gövdesinde
# `return public.partner_gate_preflag(...)` diyordu; preflag UUID
# döndürüyor. plpgsql gövdeleri OLUŞTURMA anında tip denetiminden
# geçmez — bu yüzden migration YEŞİL yanar, hata ancak ÇAĞRILINCA çıkar.
# Denetimin yeri bu yüzden burası: katalog + gövde, çalıştıktan sonra.
DELEGE_EKLERI = ('_preflag', '_impl', '_base', '_prebfilter', '_prerank',
                 '_orig', '_inner', '_core')


def sarmalayici_delege(kopyala):
    fns = _fonksiyonlar(kopyala)
    if not fns:
        return ['OLCUM YAPILAMADI: public semasinda hic fonksiyon okunamadi']
    bilgi = {}
    for _oid, ad, lang, ret, src in fns:
        bilgi.setdefault(ad.lower(), (lang, ret, src))
    castlar = _cast_ciftleri(kopyala)

    ihlal, cift = [], 0
    for ad, (lang, ret, src) in sorted(bilgi.items()):
        for ek in DELEGE_EKLERI:
            delege = ad + ek
            if delege not in bilgi:
                continue
            cift += 1
            dret = bilgi[delege][1]
            # DOĞRUDAN DÖNÜŞ MÜ? `return public.X_preflag(...)` ya da
            # `return query select * from public.X_preflag(...)`.
            dogrudan = re.search(
                r'\breturn\s+(?:public\.)?' + re.escape(delege) + r'\s*\(', src, re.I) \
                or re.search(
                    r'\breturn\s+query\s+select\s+(?:\*|\w+\.\*)\s+from\s+'
                    r'(?:public\.)?' + re.escape(delege) + r'\s*\(', src, re.I) \
                or re.match(
                    r'\s*select\s+(?:\*|\w+\.\*)\s+from\s+(?:public\.)?'
                    + re.escape(delege) + r'\s*\(', src, re.I)
            if not dogrudan:
                # Uyarlayıcı sarmalayıcı (213'ün partner_gate'i gibi):
                # delegenin sonucu bir değişkene alınıp ÇEVRİLİYOR.
                # O yolun doğruluğunu (1) numaralı denetim ölçer.
                continue
            if norm(ret) != norm(dret) and not uyumlu(ret, dret, castlar):
                ihlal.append(
                    f'{ad} -> {norm(ret)} ama delege {delege} -> {norm(dret)} '
                    f'(govde delegeyi DOGRUDAN donduruyor)')
            elif norm(ret) != norm(dret):
                # Tip farklı ama PostgreSQL çevirebiliyor: yine de
                # sözleşme kayması, GÖRÜNÜR olmalı.
                ihlal.append(
                    f'{ad} -> {norm(ret)} ama delege {delege} -> {norm(dret)} '
                    f'(dogrudan donus, cevrim degere bagli)')
    OLCUM['delege_cifti'] = cift
    return ihlal


# ============================================================
# 3) APP'İN DOĞRUDAN TABLO SORGULARI ↔ GRANT
# ============================================================
# 🔴 HATA SINIFI 22'nin ikinci yarısı. 159 şu sınıfı ÖLÇMÜŞTÜ:
# "politika var, GRANT yok" — RPC'ler security definer olduğu için
# E2E'ler yeşildi, app'in DOĞRUDAN tablo sorguları ise canlıda
# permission denied alıp SESSİZCE boş dönüyordu (ana sayfa sayacı hep 0).
# 159 bunu 24 tablo adını ELLE yazarak kapattı ve bekçisi de yalnız
# O LİSTEYİ kontrol ediyor. Yani liste, yazıldığı günün fotoğrafı:
# app'e bugün yeni bir `.from("x")` eklenirse hiçbir şey kırmızı yanmaz.
# Bu fonksiyon listeyi HER KOŞUDA kaynaktan yeniden üretir.
_FROM = re.compile(r"\.from\(\s*['\"`]([A-Za-z0-9_]+)['\"`]\s*\)"
                   r"\s*(?:\.\s*([A-Za-z_]+)\s*\()?")
_ISLEM_HAK = {'select': 'SELECT', 'insert': 'INSERT', 'update': 'UPDATE',
              'delete': 'DELETE', 'upsert': 'INSERT'}


def app_tablo_haklari(kopyala, dosyalar):
    """App (anon anahtarı + kullanıcı oturumu = `authenticated` rolü)
    doğrudan hangi tabloya hangi işlemi yapıyor, GRANT'ı var mı?"""
    if not dosyalar:
        return ['OLCUM YAPILAMADI: taranacak app dosyasi bulunamadi '
                '(bos tarama "temiz" SAYILMAZ)']
    istek = {}
    for f in dosyalar:
        try:
            src = open(f, encoding='utf-8', errors='replace').read()
        except OSError as e:
            return [f'OLCUM YAPILAMADI: {os.path.basename(f)} okunamadi: {e}']
        for m in _FROM.finditer(src):
            onces = src[max(0, m.start() - 40):m.start()]
            # `supabase.storage.from("avatars")` bir TABLO değil, bir
            # depolama kovasıdır. İlk ölçümde `avatars` bu yüzden
            # listeye girmişti — kova için tablo grant'ı aramak
            # yanlış alarmdır.
            if re.search(r'storage\s*$', onces):
                continue
            tablo = m.group(1)
            islem = (m.group(2) or 'select').lower()
            # Zincirin devamı tanınmıyorsa okuma varsayılır (PostgREST
            # `.from(x)` ile en az SELECT ister).
            hak = _ISLEM_HAK.get(islem, 'SELECT')
            istek.setdefault((tablo, hak), set()).add(os.path.basename(f))
            if islem == 'upsert':
                istek.setdefault((tablo, 'UPDATE'), set()).add(os.path.basename(f))
    OLCUM['app_tablo'] = len(istek)
    if not istek:
        return ['OLCUM YAPILAMADI: app kaynaginda hic .from("tablo") bulunamadi']

    degerler = ', '.join(
        "(" + "'" + t.replace("'", "''") + "','" + h + "')" for t, h in sorted(istek))
    satirlar = kopyala(f"""
        with app(tb, act) as (values {degerler})
        select tb, act, (to_regclass('public.'||tb) is not null)::text
          from app
         where to_regclass('public.'||tb) is null
            or not case when act in ('SELECT','INSERT','UPDATE')
                     then has_any_column_privilege('authenticated','public.'||tb,act)
                     else has_table_privilege('authenticated','public.'||tb,act) end
         order by tb, act""")
    ihlal = []
    for tb, act, var in satirlar:
        nerede = ', '.join(sorted(istek[(tb, act)]))
        if var == 'false':
            ihlal.append(f'{tb}.{act} — TABLO YOK ({nerede})')
        else:
            ihlal.append(f'{tb} {act} — authenticated icin GRANT yok '
                         f'({nerede} dogrudan sorguluyor, canlida 42501)')
    return ihlal


# ============================================================
# TEK BAŞINA ÇALIŞTIRMA
# ============================================================
def _kopyala_yapici(uri):
    import subprocess
    import pathlib
    import pgserver
    BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
    ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}

    def kopyala(sql):
        r = subprocess.run(
            [str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
             '-c', f'copy ({sql}) to stdout with (format csv)'],
            capture_output=True, text=True, env=ENV)
        if r.returncode != 0:
            # 🔴 HATAYI ASLA GİZLEME: sessizce boş liste dönmek,
            # denetimi yeşil yakan bir yalandır.
            raise RuntimeError(r.stderr.strip()[:400])
        return [row for row in csv.reader(io.StringIO(r.stdout)) if row]
    return kopyala


def main():
    if len(sys.argv) < 2:
        print('KULLANIM: python3 sozlesme_check.py "<psql-uri>"')
        print('  (asil cagirici pg_run.py — migrationlar bittikten SONRA)')
        return 2
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ll_paths
    kopyala = _kopyala_yapici(sys.argv[1])
    app = [f for f in ll_paths.require_code('sozlesme_check', [ll_paths.app_dir()])
           if os.path.dirname(f) in (ll_paths.app_dir(),
                                     os.path.join(ll_paths.app_dir(), 'src'))]
    bloklar = [
        ('Cagirici sozlesmesi (v_x := f() tip uyumu)', cagirici_sozlesmesi(kopyala)),
        ('Sarmalayici/delege donus tipi', sarmalayici_delege(kopyala)),
        ('App tablo sorgusu / GRANT', app_tablo_haklari(kopyala, app)),
    ]
    print('=' * 72)
    print('SOZLESME DENETIMI — sonraki dosya oncekinin cagiricilarini bozdu mu?')
    print('=' * 72)
    kotu = 0
    for ad, satirlar in bloklar:
        if satirlar:
            kotu += len(satirlar)
            print(f'  ✗ {ad}:')
            for s in satirlar:
                print(f'      {s}')
        else:
            print(f'  ✓ {ad}')
    print(f'\nOLCUM: {OLCUM}')
    return 1 if kotu else 0


if __name__ == '__main__':
    sys.exit(main())
