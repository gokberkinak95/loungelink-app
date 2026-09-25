#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · tip_derin.py   (18 Agustos 2026)

🔴 NEDEN VAR — UCUNCU HATAYI BEKLEMEDEN:

Gokberk canlida iki kez 42804 aldi (186 · my_sent_requests):
    character(3) vs text   ·   smallint vs integer
ve 186'dan 217'ye kadar KURULUMA DEVAM EDIYOR. Ucuncusu varsa onu
BUGUN bulmak gerekiyor.

Elimde iki enstruman vardi ve ikisi de YETMIYOR:

  · canli_cagri.py — son semada gercek satirla cagirir. Ama 186'nin
    hatasini GOREMEZ: 187 ayni fonksiyonu CAST'LERLE yeniden tanimliyor,
    yani son semada hata YOK. Gokberk hatayi 186'yi CALISTIRIRKEN aldi.
    (Olctum: 186'yi bozup tam kosu yaptim → canli gecis YESIL kaldi.)

  · tip_check.py — dosyalari statik okur, ARA HALLERI de gorur ve
    mutasyon testinde KIRMIZI yandi. Ama kapsami dar:
        "34 fonksiyon · 9'unda select listesi okundu · 25 sutun cozuldu
         · 56 sutun atlandi (ifade/belirsiz kolon)"
    Cunku select listesini KENDIM ayristirmaya calisiyordum: takma ad
    tablolari, `coalesce(...)`, alt sorgular, `case` ifadeleri...
    Her biri bir tahmin, her tahmin bir korluk.

────────────────────────────────────────────────────────────────────
FIKIR: AYRISTIRMAYI BIRAK, POSTGRESQL'E SOR
────────────────────────────────────────────────────────────────────
`prepare` bir sorguyu CALISTIRMADAN planlar ve `pg_prepared_statements`
tablosu sonucun tiplerini `result_types regtype[]` olarak verir.
Yani sorgunun her sutununun GERCEK tipini PostgreSQL'in kendisi soyler
— takma ad cozmeye, `coalesce` tipini tahmin etmeye gerek yok.

Yapilan is:
  1. Dosyadan `create function ... returns table (...)` basligini oku.
  2. Govdedeki `return query <SELECT>;` metnini al.
  3. PL/pgSQL degiskenlerini (arguman + DECLARE) `null::tip` ile degistir
     — boylece sorgu duz SQL olur.
  4. `prepare` et, `result_types` oku, ILAN EDILEN tiplerle TAM ESITLIK
     ara (olctum: PostgreSQL `returns table` sozlesmesinde genisletme
     YAPMIYOR; integer←smallint bile reddediliyor).
  5. Hazirlanamayan her fonksiyonu SEBEBIYLE birlikte YAZ.

🔴 KAPSAM YALANI YOK: "temiz" cumlesi yalniz HAZIRLANABILEN fonksiyonlar
icindir. Hazirlanamayan sayisi her kosuda basilir. Bir denetimin en
pahali hatasi, olcemedigi seyi olculmus gostermesidir — bu depoda tam
olarak bu yuzden iki kez canliya hata gitti.
"""
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

TAKMA = {
    'timestamptz': 'timestamp with time zone',
    'timestamp': 'timestamp without time zone',
    'timetz': 'time with time zone',
    'time': 'time without time zone',
    'varchar': 'character varying',
    'char': 'character',
    'bpchar': 'character',
    'int': 'integer', 'int4': 'integer',
    'int8': 'bigint', 'int2': 'smallint',
    'float8': 'double precision', 'float4': 'real',
    'bool': 'boolean',
    'decimal': 'numeric',
}


def normal(t):
    t = ' '.join(str(t).strip().lower().split())
    t = t.replace('"', '')
    if t.startswith('public.'):
        t = t[7:]
    dizi = t.endswith('[]')
    if dizi:
        t = t[:-2].strip()
    t = re.sub(r'\(\s*\d+(\s*,\s*\d+)?\s*\)$', '', t).strip()
    t = TAKMA.get(t, t)
    return t + ('[]' if dizi else '')


def kolonlari_ayir(icerik):
    """`returns table ( ... )` icini (ad, tip) ciftlerine bol."""
    out, derinlik, tampon = [], 0, ''
    for ch in icerik:
        if ch in '([':
            derinlik += 1
        elif ch in ')]':
            derinlik -= 1
        if ch == ',' and derinlik == 0:
            out.append(tampon); tampon = ''
        else:
            tampon += ch
    if tampon.strip():
        out.append(tampon)
    ciftler = []
    for p in out:
        p = ' '.join(p.split())
        m = re.match(r'^("?[a-zA-Z_][a-zA-Z0-9_]*"?)\s+(.+)$', p)
        if m:
            ciftler.append((m.group(1).strip('"'), m.group(2).strip()))
    return ciftler


BASLIK = re.compile(
    r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?("?[a-zA-Z_][a-zA-Z0-9_]*"?)\s*\(',
    re.I)


def _paren_kapa(t, i):
    """t[i] == '(' iken eslesen ')' indeksini dondur (tirnak farkindali)."""
    d, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == "'":
            i += 1
            while i < n:
                if t[i] == "'":
                    if i + 1 < n and t[i + 1] == "'":
                        i += 2; continue
                    break
                i += 1
        elif c == '(':
            d += 1
        elif c == ')':
            d -= 1
            if d == 0:
                return i
        i += 1
    return -1


def fonksiyonlari_bul(metin):
    """Dosyadan (ad, argumanlar, returns-table-kolonlari, govde) uret."""
    out = []
    for m in BASLIK.finditer(metin):
        ad = m.group(1).strip('"')
        ap = m.end() - 1
        kap = _paren_kapa(metin, ap)
        if kap < 0:
            continue
        argmetni = metin[ap + 1:kap]
        kuyruk = metin[kap + 1:kap + 4000]
        rt = re.search(r'returns\s+table\s*\(', kuyruk, re.I)
        if not rt:
            continue
        rap = kap + 1 + rt.end() - 1
        rkap = _paren_kapa(metin, rap)
        if rkap < 0:
            continue
        # 🔴 ILAN LISTESINI DE YORUMSUZLASTIR — IKINCI KEZ ISIRDI.
        # `returns table (...)` icinde acikayici yorum satirlarim var:
        #     -- 🔴 186: baglam alanlari
        #     airport_code text, ...
        # Yorum, ardindaki kolonla ayni parcaya dusuyor ve `^ad tip$`
        # kalibi tutmadigi icin O KOLON SESSIZCE DUSUYORDU. Sonuc:
        # pending_ratings 13 kolon ilan ederken 12 sayildi ve denetim
        # "SUTUN SAYISI UYUSMUYOR" diye UYDURMA bir bulgu uretti.
        # Ayni sinif yukarida govdede de cikti (CAST'I ŞART). Ders:
        # yorumlari BIR YERDE degil, okunan HER metinde temizle.
        kolonlar = kolonlari_ayir(yorumsuz(metin[rap + 1:rkap]))
        # Govde: $tag$ ... $tag$
        g = re.search(r'\$([a-zA-Z_]*)\$', metin[rkap:rkap + 3000])
        if not g:
            continue
        etiket = g.group(0)
        bas = rkap + g.end()
        son = metin.find(etiket, bas)
        if son < 0:
            continue
        # 🔴 GOVDEYI YORUMSUZ SAKLA — yoksa Turkce kesme isaretleri
        # ("CAST'I ŞART") tirnak sayacini kaydiriyor ve degisken
        # degistirme sessizce yarida kesiliyor. Olctum: bu yuzden 197
        # tanimin 0'i hazirlanabiliyordu.
        # `language sql` mi? Govdede `begin` yoksa ve select/with ile
        # basliyorsa govdenin KENDISI sorgudur.
        dil = 'plpgsql'
        kuy = metin[son:son + 400].lower()
        onc = metin[rkap:bas].lower()
        if 'language sql' in onc or 'language sql' in kuy:
            dil = 'sql'
        out.append(dict(ad=ad, arg=yorumsuz(argmetni), kolon=kolonlar,
                        govde=yorumsuz(metin[bas:son]), etiket=etiket, dil=dil))
    return out


def degisken_tipleri(argmetni, govde):
    """Arguman ve DECLARE degiskenlerini ad→tip olarak topla."""
    harita = {}
    # Argumanlar
    derinlik, tampon, parcalar = 0, '', []
    for ch in argmetni:
        if ch in '([':
            derinlik += 1
        elif ch in ')]':
            derinlik -= 1
        if ch == ',' and derinlik == 0:
            parcalar.append(tampon); tampon = ''
        else:
            tampon += ch
    if tampon.strip():
        parcalar.append(tampon)
    for p in parcalar:
        p = ' '.join(p.split())
        p = re.sub(r'^(in|out|inout|variadic)\s+', '', p, flags=re.I)
        p = re.split(r'\s+default\s+|\s*=\s*', p, flags=re.I)[0]
        m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s+(.+)$', p)
        if m:
            harita[m.group(1).lower()] = m.group(2).strip()
    # DECLARE blogu
    d = re.search(r'\bdeclare\b(.*?)\bbegin\b', govde, re.I | re.S)
    if d:
        for satir in d.group(1).split(';'):
            satir = ' '.join(re.sub(r'--[^\n]*', ' ', satir).split())
            if not satir:
                continue
            satir = re.split(r'\s*:=\s*|\s+default\s+', satir, flags=re.I)[0]
            m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s+(?:constant\s+)?(.+)$', satir, re.I)
            if m and m.group(2).strip().lower() not in ('record', 'refcursor'):
                harita[m.group(1).lower()] = m.group(2).strip()
    return harita


def yorumsuz(t):
    """`--` ve `/* */` yorumlarini at; tirnak ve dolar-tirnak farkindali.

    🔴 BUNU YAZMADAN ONCE UC SAAT KAYBETTIM. Ayristirici `return query`
    metnini dogru kesiyordu ama degisken degistirme ORTADA DURUYORDU.
    Sebep: KENDI YAZDIGIM Turkce yorumlar.

        -- 🔴 char(3) → text CAST'I ŞART.

    `CAST'I` icindeki tek tirnak, tirnak sayacini kaydiriyor ve o
    noktadan sonra butun sorgu "string icinde" sayiliyordu. Yani
    denetimin korlugunun sebebi denetimin kendi yorumlariydi.
    Ders: bir ayristirici, uzerinde calistigi metnin YORUM DILINI de
    bilmek zorunda."""
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if c == '-' and i + 1 < n and t[i + 1] == '-':
            j = t.find('\n', i)
            i = n if j < 0 else j          # satir sonunu birak
            continue
        if c == '/' and i + 1 < n and t[i + 1] == '*':
            j = t.find('*/', i + 2)
            i = n if j < 0 else j + 2
            out.append(' ')
            continue
        if c == "'":
            j = i + 1
            while j < n:
                if t[j] == "'":
                    if j + 1 < n and t[j + 1] == "'":
                        j += 2; continue
                    break
                j += 1
            out.append(t[i:j + 1]); i = j + 1
            continue
        m = re.match(r'\$([a-zA-Z_][a-zA-Z0-9_]*)?\$', t[i:i + 40])
        if m:
            etiket = m.group(0)
            j = t.find(etiket, i + len(etiket))
            if j >= 0:
                out.append(t[i:j + len(etiket)]); i = j + len(etiket); continue
        out.append(c); i += 1
    return ''.join(out)


def return_query_bul(govde):
    """Govdedeki `return query <sql>;` metinlerini cikar."""
    out = []
    for m in re.finditer(r'\breturn\s+query\b', govde, re.I):
        i, n, d = m.end(), len(govde), 0
        bas = i
        while i < n:
            c = govde[i]
            if c == "'":
                i += 1
                while i < n:
                    if govde[i] == "'":
                        if i + 1 < n and govde[i + 1] == "'":
                            i += 2; continue
                        break
                    i += 1
            elif c == '(':
                d += 1
            elif c == ')':
                d -= 1
            elif c == ';' and d == 0:
                break
            i += 1
        s = govde[bas:i].strip()
        if s.lower().startswith('execute'):
            continue          # dinamik SQL — hazirlanamaz, YAZILACAK
        if s:
            out.append(s)
    return out


def sqllestir(sorgu, harita):
    """PL/pgSQL degiskenlerini `null::tip` ile degistirip duz SQL yap."""
    def yerine(m):
        onceki = m.string[m.start() - 1] if m.start() > 0 else ''
        if onceki == '.':
            return m.group(0)           # a.slots → kolon, degisken degil
        ad = m.group(0).lower()
        if ad in harita:
            return f'(null::{harita[ad]})'
        return m.group(0)
    # Tirnak icindeki metni koru
    parcalar, i, n, out = [], 0, len(sorgu), ''
    while i < n:
        if sorgu[i] == "'":
            j = i + 1
            while j < n:
                if sorgu[j] == "'":
                    if j + 1 < n and sorgu[j + 1] == "'":
                        j += 2; continue
                    break
                j += 1
            out += sorgu[i:j + 1]; i = j + 1
        else:
            j = i
            while j < n and sorgu[j] != "'":
                j += 1
            out += re.sub(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', yerine, sorgu[i:j])
            i = j
    return out


def dosya_denetle(psql, uri, yol):
    """TEK dosyayi, O ANKI semaya karsi denetle.

    🔴 BURASI ISIN KALBI. Once butun dosyalari SON semaya karsi
    denetledim ve 197 tanimin 197'si "column ... does not exist" dedi:
    cunku 143'un sorgusu 154'te DEGISEN bir kolona bakiyor. Yani eski
    dosyalari yeni semaya karsi olcuyordum — canli_cagri'de yaptigim
    hatanin aynisi, bir kat asagida.

    Dogrusu: dosya UYGULANDIKTAN HEMEN SONRA denetle. O an sema, Gokberk
    o dosyayi SQL Editor'e yapistirdigi andaki semanin TA KENDISI.
    Veri gerekmez — `prepare` calistirmaz, yalniz planlar."""
    bulgular, hazir, hazirsiz = [], 0, []
    metin = open(yol, encoding='utf-8', errors='replace').read()
    for fn in fonksiyonlari_bul(metin):
        if not fn['kolon']:
            continue
        harita = degisken_tipleri(fn['arg'], fn['govde'])
        sorgular = return_query_bul(fn['govde'])
        if not sorgular and fn.get('dil') == 'sql':
            g = fn['govde'].strip().rstrip(';').strip()
            if re.match(r'^\(?\s*(select|with)\b', g, re.I):
                sorgular = [g]
        if not sorgular:
            hazirsiz.append((fn['ad'], 'sorgu cikarilamadi (dinamik EXECUTE / baska desen)'))
            continue
        duz = sqllestir(sorgular[0], harita)
        # 🔴 PREPARE VE OKUMA AYNI OTURUMDA OLMAK ZORUNDA.
        # Ilk surumde ikisini ayri `psql -c` ile calistirdim; hazirlanan
        # ifade OTURUMA OZEL oldugu icin ikinci baglanti onu goremiyordu
        # ve 128 tanim "result_types okunamadi" diyordu. Yani denetim
        # hicbir sey olcmedigi halde "0 bulgu" yaziyordu — bu depoda
        # iki kez canliya hata gonderen tam olarak bu desen.
        r = psql(uri,
                 f"prepare tip_probe as {duz};\n"
                 "select 'TIPLER:' || array_to_string(result_types, '|') "
                 "from pg_prepared_statements where name = 'tip_probe';",
                 tuples=True)
        if r.returncode != 0:
            sebep = next((l.strip() for l in (r.stderr or '').splitlines()
                          if 'ERROR' in l), 'bilinmiyor')
            sebep = sebep.replace('ERROR:', '').strip()
            # 🔴 "column ... does not exist" HER ZAMAN OLCUM BOSLUGU DEGIL.
            # Bunlari topluca "olculemedi" saymistim ve icinde GERCEK BIR
            # KUSUR sakliydi: `lounge_radar_people` govdesinde
            # `v.flight_no` yaziyor ama `visits` tablosundaki kolonun adi
            # `flight_number`. Fonksiyon 034'ten beri OLU — cagirildiginda
            # 42703 veriyor. Gorunmemesinin sebebi, ondan once gelen
            # `if v_air is null then return; end if;` erken cikisiydi.
            #
            # Ayrim su: NITELIKLI bir ad (`v.flight_no`, `p.linkedin`)
            # sorgunun KENDI hatasidir. Niteliksiz ve `p_`/`v_` ile
            # baslayan bir ad (`p_airport`) ise BENIM degisken
            # degistirmemin tutmadigi anlamina gelir — arac eksigi.
            m2 = re.search(r'column "?([a-zA-Z_][a-zA-Z0-9_.]*)"? does not exist', sebep)
            gercek = False
            if m2:
                isim = m2.group(1)
                if '.' in isim:
                    gercek = True                      # v.flight_no → kolon yok
                elif not re.match(r'^(p_|v_)', isim):
                    gercek = True
            if 'relation' in sebep and 'does not exist' in sebep:
                gercek = True
            if gercek:
                bulgular.append(f"{fn['ad']}() SORGU KOLONU YOK → {sebep[:120]}")
            else:
                hazirsiz.append((fn['ad'], sebep[:120]))
            continue
        satir = next((l.strip() for l in (r.stdout or '').splitlines()
                      if l.strip().startswith('TIPLER:')), None)
        if satir is None:
            hazirsiz.append((fn['ad'], 'result_types okunamadi'))
            continue
        gercek = [x for x in satir[len('TIPLER:'):].split('|') if x != '']
        hazir += 1
        if len(gercek) != len(fn['kolon']):
            bulgular.append(f"{fn['ad']}() SUTUN SAYISI: ilan {len(fn['kolon'])} · "
                            f"sorgu {len(gercek)}")
            continue
        for i, ((kad, ktip), gtip) in enumerate(zip(fn['kolon'], gercek), 1):
            if normal(ktip) != normal(gtip):
                bulgular.append(f"{fn['ad']}() sutun {i} \"{kad}\": "
                                f"ILAN {normal(ktip)} · SORGU {normal(gtip)}")
    return bulgular, hazir, hazirsiz


def denetle(psql, uri, sql_dir, yaz=print):
    dosyalar = sorted(f for f in os.listdir(sql_dir)
                      if f.endswith('.sql') and f != 'ETKIN_TANIMLAR.sql')
    bulgular, hazirlanan, hazirlanamayan, fn_sayisi = [], 0, [], 0
    sayac = 0

    for f in dosyalar:
        metin = open(os.path.join(sql_dir, f), encoding='utf-8', errors='replace').read()
        # Yorumlari temizleme! `--` iceren string olabilir; ayristirici
        # zaten tirnak farkindali.
        for fn in fonksiyonlari_bul(metin):
            if not fn['kolon']:
                continue
            fn_sayisi += 1
            harita = degisken_tipleri(fn['arg'], fn['govde'])
            sorgular = return_query_bul(fn['govde'])
            if not sorgular and fn.get('dil') == 'sql':
                g = fn['govde'].strip().rstrip(';').strip()
                if re.match(r'^\(?\s*(select|with)\b', g, re.I):
                    sorgular = [g]
            if not sorgular:
                hazirlanamayan.append((f, fn['ad'], 'return query yok (dinamik/EXECUTE ya da baska desen)'))
                continue
            cozuldu = False
            for sorgu in sorgular:
                sayac += 1
                isim = f'tip_probe_{sayac}'
                duz = sqllestir(sorgu, harita)
                r = psql(uri, f'prepare {isim} as {duz};', tuples=True)
                if r.returncode != 0:
                    continue
                rr = psql(uri,
                          "select array_to_string(result_types, '|') "
                          f"from pg_prepared_statements where name = '{isim}';",
                          tuples=True)
                psql(uri, f'deallocate {isim};', tuples=True)
                if rr.returncode != 0 or not (rr.stdout or '').strip():
                    continue
                gercek = [x for x in (rr.stdout.strip().splitlines()[0]).split('|') if x != '']
                if len(gercek) != len(fn['kolon']):
                    # Sutun sayisi tutmuyor: bu da GERCEK bir hata sinifi.
                    bulgular.append(
                        f"{f} · {fn['ad']}() SUTUN SAYISI: ilan {len(fn['kolon'])} · "
                        f"sorgu {len(gercek)}")
                    cozuldu = True
                    break
                for i, ((kad, ktip), gtip) in enumerate(zip(fn['kolon'], gercek), 1):
                    if normal(ktip) != normal(gtip):
                        bulgular.append(
                            f"{f} · {fn['ad']}() sutun {i} \"{kad}\": "
                            f"ILAN {normal(ktip)} · SORGU {normal(gtip)}")
                cozuldu = True
                break
            if cozuldu:
                hazirlanan += 1
            else:
                # Hazirlanamama sebebini YAZ — sessiz atlamak kapsam yalanidir.
                son = psql(uri, f'prepare tip_probe_x as {sqllestir(sorgular[0], harita)};',
                           tuples=True)
                psql(uri, 'deallocate tip_probe_x;', tuples=True)
                sebep = next((l.strip() for l in (son.stderr or '').splitlines()
                              if 'ERROR' in l), 'bilinmiyor')
                hazirlanamayan.append((f, fn['ad'], sebep[:150]))

    # tekrarlari at
    bulgular = list(dict.fromkeys(bulgular))

    yaz(f'  {fn_sayisi} `returns table` tanimi tarandi (butun dosyalar, ARA HALLER dahil)')
    yaz(f'  PostgreSQL ile hazirlanip tipleri OLCULEN: {hazirlanan}')
    yaz(f'  hazirlanamayan: {len(hazirlanamayan)}  → bunlar hakkinda GARANTI YOK')
    if bulgular:
        yaz('')
        yaz(f'  ✗ {len(bulgular)} TIP UYUSMAZLIGI (canlida 42804 · kurulum DURUR):')
        for b in bulgular:
            yaz(f'      {b}')
    if hazirlanamayan:
        yaz('')
        yaz('  Hazirlanamayanlar (sebebiyle):')
        gruplu = {}
        for f, ad, sebep in hazirlanamayan:
            gruplu.setdefault(sebep.split('ERROR:')[-1].strip()[:70], []).append(f'{ad}')
        for sebep, adlar in sorted(gruplu.items(), key=lambda x: -len(x[1])):
            yaz(f'      [{len(adlar)}] {sebep}')
            yaz(f'          {", ".join(sorted(set(adlar))[:8])}'
                + (' ...' if len(set(adlar)) > 8 else ''))
    return bulgular, hazirlanan, hazirlanamayan


if __name__ == '__main__':
    import ll_paths
    import pathlib
    import subprocess
    import pgserver
    DATA = pathlib.Path('/tmp/ll_pg')
    BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
    ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}

    def psql(uri, sql=None, file=None, quiet=True, tuples=False):
        cmd = [str(BIN / 'psql'), uri, '-v', 'ON_ERROR_STOP=1', '-X']
        if tuples:
            cmd += ['-t', '-A']
        if quiet:
            cmd += ['-q']
        cmd += (['-f', str(file)] if file else ['-c', sql])
        return subprocess.run(cmd, capture_output=True, text=True, env=ENV)

    if not DATA.exists():
        print('✗ /tmp/ll_pg yok. Once: python pg_run.py --keep'); sys.exit(1)
    srv = pgserver.get_server(DATA)
    sql_dir, _ = ll_paths.require_sql('tip_derin')
    print('=' * 72)
    print('DERIN TIP DENETIMI — tipleri PostgreSQL olcuyor (prepare)')
    print('=' * 72)
    b, h, hz = denetle(psql, srv.get_uri(), sql_dir)
    sys.exit(1 if b else 0)


# ============================================================================
# KATALOG DENETIMI — DINAMIK KURULAN FONKSIYONLAR ICIN
# ============================================================================
# 🔴 NEDEN: dosya taramasi 45 tanimi olcemiyordu, sebebi tek satirda:
#     execute format('create function public.%s(...) ... $BODY$ %s $BODY$', ...)
# Govde CALISMA ANINDA olusuyor; dosyada duran sey bir SABLON, sorgu degil.
# 207'nin `discover_availabilities` sarmalayicisi, 212'nin `create_request_impl`
# sarmalayicisi, 192'nin `request_precheck` yamasi... hepsi boyle.
#
# Ama bu fonksiyonlar CALISTIKTAN SONRA katalogda GERCEK govdeleriyle
# duruyor. Yani ayristirilamayan sey dosya; katalog ayristirilabilir.
# Ustelik burada ILAN EDILEN kolonlari da tahmin etmiyoruz:
# `proargnames` + `proallargtypes` + `proargmodes` PostgreSQL'in kendi
# kaydi — `returns table (...)` metnini elle okumaya gerek yok.
#
# Kapsam farki: bu denetim SON SEMAYA bakar, yani ARA HALLERI gormez.
# Dosya taramasi ara halleri gorur ama dinamikleri goremez. Ikisi
# birbirinin korlugunu kapatiyor; ayri ayri raporlaniyorlar.

# PostgreSQL/uzanti fonksiyonlari — bizim degil.
SISTEM_ON_EK = ('pg_', 'uuid_', 'gen_', 'crypt', 'digest', 'armor', 'dearmor',
                'hmac', 'set_limit', 'show_limit', 'show_trgm', 'similarity',
                'word_similarity', 'strict_word_similarity', 'unaccent',
                'ts_', 'json', 'jsonb', 'array_')

KATALOG_SQL = """
select p.oid::text,
       p.proname,
       coalesce((select string_agg(x.nm || '§' || format_type(x.tp, null), '¦'
                                   order by x.ord)
                   from unnest(p.proargnames, p.proallargtypes)
                        with ordinality as x(nm, tp, ord)), ''),
       coalesce(array_to_string(p.proargmodes::text[], ''), ''),
       p.prosrc
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prokind = 'f' and p.proretset
  and p.proallargtypes is not null
order by p.proname
"""


def katalog_denetle(psql, uri, yaz=print):
    """Katalogdaki ETKIN tanimlari olc (dinamik kurulanlar dahil)."""
    r = psql(uri, f'copy ({KATALOG_SQL}) to stdout with (format csv)', tuples=True)
    if r.returncode != 0:
        yaz('  ⚠ katalog sorgusu calismadi: ' + (r.stderr or '')[:200])
        return [], 0, []
    import csv as _csv, io as _io
    bulgular, olculen, olculemeyen = [], 0, []
    for satir in _csv.reader(_io.StringIO(r.stdout)):
        if len(satir) < 5:
            continue
        _oid, ad, alanlar, modlar, govde = satir[0], satir[1], satir[2], satir[3], satir[4]
        if ad.startswith(SISTEM_ON_EK) or ad.startswith(('trg_', '_')):
            continue
        # OUT ('o') ve TABLE ('t') kipli alanlar ilan edilen kolonlardir
        cift = [x.split('§') for x in alanlar.split('¦') if '§' in x]
        if len(modlar) != len(cift) or not cift:
            continue
        kolon = [(cift[i][0], cift[i][1]) for i in range(len(cift))
                 if modlar[i] in ('t', 'o')]
        girdi = {cift[i][0].lower(): cift[i][1] for i in range(len(cift))
                 if modlar[i] in ('i', 'b', 'v')}
        if not kolon:
            continue
        g = yorumsuz(govde)
        sorgular = return_query_bul(g)
        if not sorgular:
            # `language sql` govdesi dogrudan sorgudur — `return query`
            # aramak burada anlamsizdi ve 62 tanimi tek kalemde
            # "olculemedi" yiginina atiyordu.
            gs = g.strip().rstrip(';').strip()
            if re.match(r'^\(?\s*(select|with)\b', gs, re.I):
                sorgular = [gs]
        if not sorgular:
            olculemeyen.append((ad, 'sorgu cikarilamadi (return query yok, select ile de baslamiyor)'))
            continue
        harita = dict(girdi)
        harita.update(degisken_tipleri('', g))
        duz = sqllestir(sorgular[0], harita)
        rr = psql(uri,
                  f"prepare kat_probe as {duz};\n"
                  "select 'TIPLER:' || array_to_string(result_types, '|') "
                  "from pg_prepared_statements where name = 'kat_probe';",
                  tuples=True)
        if rr.returncode != 0:
            sebep = next((l.strip() for l in (rr.stderr or '').splitlines()
                          if 'ERROR' in l), 'bilinmiyor').replace('ERROR:', '').strip()
            m2 = re.search(r'column "?([a-zA-Z_][a-zA-Z0-9_.]*)"? does not exist', sebep)
            if m2 and ('.' in m2.group(1) or not re.match(r'^(p_|v_)', m2.group(1))):
                bulgular.append(f'{ad}() SORGU KOLONU YOK → {sebep[:110]}')
            else:
                olculemeyen.append((ad, sebep[:110]))
            continue
        cizgi = next((l.strip() for l in (rr.stdout or '').splitlines()
                      if l.strip().startswith('TIPLER:')), None)
        if not cizgi:
            olculemeyen.append((ad, 'result_types okunamadi')); continue
        gercek = [x for x in cizgi[len('TIPLER:'):].split('|') if x != '']
        olculen += 1
        if len(gercek) != len(kolon):
            bulgular.append(f'{ad}() SUTUN SAYISI: ilan {len(kolon)} · sorgu {len(gercek)}')
            continue
        for i, ((kad, ktip), gtip) in enumerate(zip(kolon, gercek), 1):
            if normal(ktip) != normal(gtip):
                bulgular.append(f'{ad}() sutun {i} "{kad}": '
                                f'ILAN {normal(ktip)} · SORGU {normal(gtip)}')
    return bulgular, olculen, olculemeyen
