#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · returns_check.py   (v2.03'te doğdu)

NEDEN VAR — ÜÇÜNCÜ KEZ AYNI HATA:
  PostgreSQL `create or replace function` ile bir fonksiyonun DÖNÜŞ TİPİNİ
  değiştirmez:
      ERROR 42P13: cannot change return type of existing function
      HINT: Use DROP FUNCTION ... first.

  Bunu üç kez yaşadık:
    085 -> 086  lounge_rules_health   (3 kolon -> 4 kolon)
    092 -> 095  save_host_access      (imza degisti)
    090 -> 102  discovery_rule_badges (RETURNS TABLE'a `info` eklendi)

  Her seferinde çözüm aynıydı: aynı dosyanın içine `drop function if exists`
  koymak. Ama bunu HATIRLAMAYA güveniyorduk ve üçüncüde yine unuttuk.
  Hatırlamaya güvenen her süreç eninde sonunda unutur; denetime bağlanan
  unutmaz.

NE YAPAR:
  Migration'ları sırayla okur. Bir fonksiyonun dönüş tipi ya da parametre
  imzası önceki tanımından FARKLIYSA, o dosyada aynı fonksiyon için bir
  `drop function` var mı bakar. Yoksa hata verir ve düşülecek satırı yazar.

SINIR: metin karşılaştırması yapar, tip eşdeğerliğini (int/integer,
varchar/text) bilmez. Bu yüzden bazen gereksiz uyarı verebilir — o durumda
zaten `drop function if exists` eklemek zararsızdır.

SINIR-2 (v2.78'de ÖLÇÜLDÜ): bu dosya bir fonksiyonun dönüş tipinin
DEĞİŞTİĞİNİ görür, ama o dönüşü KİMİN OKUDUĞUNU göremez. 212 turunda
`partner_gate` uuid'den boolean'a taşındı; 209'daki beş çağırıcı hâlâ
`v_uid uuid := partner_gate(...)` diyordu ve canlıda
    22P02 invalid input syntax for type uuid: "f"
çıktı. Buradaki hiçbir kural kırmızı yanmadı, çünkü değişimin KENDİSİ
kurallara uygundu — bozulan şey ÇAĞIRICININ VARSAYIMIYDI.
Çağırıcı tarafını `sozlesme_check.py` ölçüyor (pg_run.py içinden,
migration'lar bittikten sonra, `pg_proc` üzerinden). İkisi birbirinin
yerine geçmez: burası "42P13 alır mısın", orası "çağıran ne bekliyordu".
"""
import os
import re
from sql_mask import mask_bodies, allow_replace_marks
import sys

import ll_paths


# Ayni tipin farkli yazimlari 42P13 URETMEZ; bunlari fark saymak
# yanlis pozitif uretir ve yanlis pozitif denetimi olduruzr.
ALIAS = {
    'int': 'integer', 'int4': 'integer', 'int2': 'smallint', 'int8': 'bigint',
    'bool': 'boolean', 'varchar': 'text', 'character varying': 'text',
    'timestamptz': 'timestamp with time zone', 'float8': 'double precision',
    'numeric': 'numeric', 'decimal': 'numeric',
    'time': 'time without time zone', 'timestamp': 'timestamp without time zone',
}


def strip_sql_comments(x):
    """Parametre listesindeki `-- ...` yorumlari imzanin parcasi DEGILDIR."""
    return re.sub(r'--[^\n]*', ' ', x or '')


def norm(x):
    x = strip_sql_comments(x)
    x = re.sub(r'\s+', ' ', x).strip().lower().rstrip(';')
    # parantez içi boşluk farkı tip farkı değildir: "table ( a int )" == "table(a int)"
    x = re.sub(r'\s*\(\s*', '(', x)
    x = re.sub(r'\s*\)\s*', ')', x).strip()
    x = re.sub(r'\s*,\s*', ', ', x)
    # 🔴 Takma adlari REGEX ILE DEGISTIRMEK, zaten genisletilmis bir tipi
    # tekrar genisletiyordu: "time" -> "time without time zone" -> tekrar
    # calisinca "time without time zone without time without time zone zone".
    # Cozum: TAM ESLESME. Kismi eslesme bu isi bozar.
    if x in ALIAS:
        return ALIAS[x]
    # 🔴 3 EYLÜL — `returns table(sira int, …)` ile `RETURNS TABLE(sira integer, …)`
    # AYNI tiptir; pg_get_functiondef `int`i `integer` yazar (284 explicit
    # gövdeleri böyle doğdu) ve bu denetim onları "FARKLI dönüş" sanıp
    # 42P13 uyarıyordu. Takma adlar tablo sütunlarında da TEK KELİMELİK
    # tam eşleşmeyle çözülür (`time`/`timestamp` bilerek dışarıda: çok
    # kelimeli açılımları tekrar açmak 176 dersini geri getirir).
    TEK = {k: v for k, v in ALIAS.items() if ' ' not in k and k not in ('time', 'timestamp', 'numeric', 'decimal')}
    x = re.sub(r'\b(' + '|'.join(sorted(TEK, key=len, reverse=True)) + r')\b',
               lambda m: TEK[m.group(1)], x)
    return x


def arg_types(args):
    args = strip_sql_comments(args)
    """Parametre TİPLERİ imzayı belirler; isim ve varsayılan değer değil."""
    out = []
    depth = 0
    cur = ''
    for ch in args:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur); cur = ''
        else:
            cur += ch
    out.append(cur)
    types = []
    for a in out:
        a = re.sub(r'\bdefault\b[\s\S]*$', '', a, flags=re.I).strip()
        if not a:
            continue
        parts = a.split()
        t = parts[-1].lower() if len(parts) == 1 else ' '.join(parts[1:]).lower()
        types.append(norm(t))
    return ', '.join(types)


def main():
    d, files = ll_paths.require_sql('returns_check')

    # Sonradan `drop function` ile temizlenen imzalar — uyari uretme.
    dropped_pre = set()
    for f in files:
        _src = re.sub(r'--[^\n]*', ' ', open(f, encoding='utf-8', errors='replace').read())
        for _m in re.finditer(r'drop function\s+(?:if exists\s+)?(?:public\.)?(\w+)\s*\(([^)]*)\)',
                              _src, re.I):
            dropped_pre.add((_m.group(1).lower(), arg_types(_m.group(2))))

    seen = {}       # fonksiyon -> (dosya, imza, dönüş)
    problems = []
    warns = []
    checked = 0

    # `returns X language plpgsql` kadar `returns X as $$` de gecerli bir
    # yazim. Ikincisinde durmazsak GOVDEYI donus tipi saniyoruz ve
    # compute_trust_badge gibi masum fonksiyonlari hatali isaretliyorduk.
    pat = re.compile(
        r'create or replace function\s+(?:public\.)?(\w+)\s*\(([\s\S]*?)\)\s*'
        r'returns\s+([\s\S]*?)\s*(?:language\s+(?:sql|plpgsql)|as\s+\$\$)', re.I)

    for f in files:
        raw = open(f, encoding='utf-8', errors='replace').read()
        # 🔴 187 turu: 176'nin `execute 'create or replace function
        # public.flow_gate_test() returns table ' || '(...)'` satiri
        # GERCEK bir tanim sanildi ve "donus tipi degisti" denildi.
        # Govde ve dize iceriklerini maskeleyip oyle ayristiriyoruz.
        src = mask_bodies(raw)
        # `-- sqlcheck: allow-replace <fn>` isareti: donus tipi AYNI kalan
        # tablo fonksiyonunda drop istemek yanlistir (158 dersi).
        allowed = allow_replace_marks(raw)
        drops = set(m.group(1).lower()
                    for m in re.finditer(r'drop function\s+(?:if exists\s+)?(?:public\.)?(\w+)',
                                         src, re.I))
        # `NNNa_PRE_drop.sql` HEMEN ONCE calisir; oradaki drop'lar bu dosya
        # icin gecerlidir. (086a/087a bu sekilde kullanildi.)
        base = os.path.basename(f)
        num = re.match(r'(\d+)', base)
        if num:
            for sib in files:
                sb = os.path.basename(sib)
                if re.match(r'^' + num.group(1) + r'[a-z]_', sb):
                    ssrc = open(sib, encoding='utf-8', errors='replace').read()
                    drops |= set(m.group(1).lower() for m in re.finditer(
                        r'drop function\s+(?:if exists\s+)?(?:public\.)?(\w+)', ssrc, re.I))
        for m in pat.finditer(src):
            name = m.group(1)
            sig = arg_types(m.group(2))
            ret = norm(m.group(3))
            checked += 1
            prev = seen.get(name)
            if prev:
                pf, psig, pret = prev
                # 🔴 IKI FARKLI DURUM, IKI FARKLI SONUC:
                #  · AYNI parametreler + FARKLI donus  -> 42P13 HATASI
                #  · FARKLI parametreler               -> PostgreSQL yeni bir
                #    ASIRI YUKLEME yaratir, hata VERMEZ. Ama iki surum birden
                #    kalir ve PostgREST "Could not choose the best candidate
                #    function" der. Bu bir HATA degil, RISK.
                if name.lower() in drops or name.lower() in {a.lower() for a in allowed}:
                    pass
                elif sig == psig and ret != pret:
                    problems.append(('HATA', os.path.basename(f), name, pf, pret, ret, psig, sig))
                elif sig != psig and (name.lower(), psig) not in dropped_pre:
                    warns.append(('RISK', os.path.basename(f), name, pf, psig, sig))
            seen[name] = (os.path.basename(f), sig, ret)

    # ============================================================
    # SARMALAYICI DENETIMI (v2.37)
    #
    # 🔴 140'ta bir fonksiyonu sarmalarken DORT hata birden yaptim:
    # parametre sirasi, dusen parametre (p_idem — cift gonderim
    # korumasi!), donus tipi ve ESKI GOVDE. Sebebi tek: govdeyi
    # grep sonucunun ORTASINDAN aldim, SONUNDAN degil.
    #
    # Kural: bir fonksiyonun `_impl` surumu varsa, sarmalayicinin
    # imzasi `_impl` ile AYNI olmali. Farkliysa ya parametre
    # dusuyor ya sira kayiyor — ikisi de sessizce yanlis calisir.
    # ============================================================
    wrap_problems = []
    wrappers = {}
    for f in files:
        src = open(f, encoding='utf-8', errors='replace').read()
        # 🔴 Adi BUTUN al, `_impl` ekini PYTHON'da ayir.
        # Ilk yazimda regex'e `(\w+?)(_impl)?` yazdim; opsiyonel grup
        # hicbir zaman eslesmedi (geri izleme tam adi baz gruba aldi) ve
        # denetim SESSIZCE hicbir sey bulmadi. Mutasyon testi olmasaydi
        # "calisiyor" sanacaktim — yesil yanan bos bir denetim, denetim
        # olmamasindan kotudur.
        for m in re.finditer(
                r'create\s+or\s+replace\s+function\s+(?:public\.)?(\w+)\s*\(([^)]*)\)'
                r'\s*returns\s+(\w+)', src, re.I | re.S):
            full, args, ret = m.group(1), m.group(2), m.group(3)
            if full.endswith('_impl'):
                base, kind = full[:-5], 'impl'
            else:
                base, kind = full, 'main'
            # 🔴 ANAHTAR DOSYAYI DA ICERIR.
            # Ilk yazimda yalniz fonksiyon adiyla anahtarlamistim ve
            # `main` girdisi BASKA dosyadaki eski tanimla eziliyordu
            # (dosya sirasi rastgele). Sarmalayici ile `_impl` zaten
            # AYNI dosyada yasar; karsilastirmayi da orada yapmali.
            wrappers.setdefault((base, os.path.basename(f)), {})[kind] = (
                arg_types(args), ret.lower(), os.path.basename(f))

    for (name, _wf), v in wrappers.items():
        if 'impl' not in v or 'main' not in v:
            continue
        ia, iret, ifile = v['impl']
        ma, mret, mfile = v['main']
        if ia != ma:
            wrap_problems.append(
                (mfile, name, f'FARKLI imza — sarmalayici({ma}) vs impl({ia})',
                 'Parametre dusuyor ya da sirasi kaymis olabilir.'))
        if iret != mret:
            wrap_problems.append(
                (mfile, name, f'FARKLI donus tipi — sarmalayici->{mret}, impl->{iret}',
                 'Cagiran taraf beklemedigi bir sey alir.'))

    print('=' * 72)
    print('DÖNÜŞ TİPİ DENETİMİ — değişen imzanın önünde DROP var mı?')
    print('=' * 72)
    print(f'SQL klasörü: {d}\nTanım: {checked}\n')

    for _, f, name, pf, psig, sig in warns:
        print(f'⚠ {f}: {name} — parametreler değişti, eski sürüm SİLİNMİYOR')
        print(f'    {pf}: ({psig})')
        print(f'    {f}: ({sig})')
        print('    İkisi birden kalır; PostgREST hangisini çağıracağını seçemeyebilir.')
        print(f'    Öneri: drop function if exists public.{name}({psig});')
        print()

    # 🔴 EK KONTROL — TEKRAR ÇALIŞTIRILABİLİRLİK.
    # Bir fonksiyon BİRDEN ÇOK dosyada tanımlıysa, ESKİ dosyayı YENİ
    # veritabanında çalıştırmak 42P13 verir (090'ı 102'den sonra
    # çalıştırınca tam bunu yaşadık). Çözüm: her tanımın önünde
    # savunma amaçlı `drop function if exists`.
    multi = {}
    for f in files:
        src = open(f, encoding='utf-8', errors='replace').read()
        for m in pat.finditer(src):
            multi.setdefault(m.group(1), []).append(
                (os.path.basename(f), src, m.start(), arg_types(m.group(2)), norm(m.group(3))))
    # 🔴 SONRADAN DUSURULENLERI SAYMA.
    # Denetim DOSYALARI tariyor, veritabanini degil. 123 eski imzalari
    # `drop function` ile temizledi ama uyari devam ediyordu — cunku eski
    # TANIM hala eski dosyada duruyor. Bir uyarinin dogru olmasi yetmez,
    # HALA GECERLI olmasi da gerekir; yoksa "zaten hallettim" diye
    # gormezden gelinmeye baslanir.
    dropped = set()
    for f in files:
        src = re.sub(r'--[^\n]*', ' ', open(f, encoding='utf-8', errors='replace').read())
        for m in re.finditer(r'drop function\s+(?:if exists\s+)?(?:public\.)?(\w+)\s*\(([^)]*)\)',
                             src, re.I):
            dropped.add((m.group(1).lower(), arg_types(m.group(2))))

    rerun = []
    for name, occ in multi.items():
        # 🔴 SADECE imzasi/donusu DEGISEN fonksiyonlar riskli. Ayni imzayla
        # birden cok kez tanimlanan fonksiyonu tekrar calistirmak zararsizdir;
        # onlari da uyarmak 94 satirlik gurultu uretiyordu ve gurultu,
        # denetimi gormezden gelmeyi ogretir.
        if len({(sig, ret) for _, _, _, sig, ret in occ}) < 2:
            continue
        if len(occ) < 2:
            continue
        # Yalniz AKTIF olarak uzerinde calistigimiz araligi uyar (083+).
        # Daha eski dosyalar canlida zaten sorunsuz calisti; onlari
        # uyarmak gecmisi tartismak olur ve listeyi okunmaz yapar.
        occ = [o for o in occ if re.match(r'^(0[89]\d|1\d\d)', o[0])]
        if len(occ) < 1:
            continue
        for base, src, pos, _sig, _ret in occ:
            if (name.lower(), _sig) in dropped_pre:
                continue
            if not re.search(r'drop function\s+(?:if exists\s+)?(?:public\.)?' + name + r'\b',
                             src[:pos], re.I):
                rerun.append((base, name))
    for base, name in rerun:
        print(f'⚠ {base}: {name} birden çok dosyada tanımlı, bu dosyada drop YOK')
        print('    Bu dosyayı tekrar çalıştırmak 42P13 verebilir.')
        print()

    if not problems:
        print('✓ dönüş tipi değiştiren her fonksiyonun önünde drop var'
              + (f' ({len(warns)} aşırı yükleme, {len(rerun)} tekrar-çalıştırma uyarısı)' if (warns or rerun) else ''))
        return 0

    for wf, wname, wmsg, whint in wrap_problems:
        print(f'✗ {wf}: {wname} sarmalayicisi — {wmsg}')
        print(f'    {whint}')
    for _, f, name, pf, pret, ret, psig, sig in problems:
        print(f'✗ {f}: {name} — dönüş tipi/imza {pf} sürümünden FARKLI, drop YOK')
        if pret != ret:
            print(f'    önce: returns {pret[:70]}')
            print(f'    şimdi: returns {ret[:70]}')
        if psig != sig:
            print(f'    önceki parametreler: ({psig})')
            print(f'    şimdiki parametreler: ({sig})')
        print(f'    ÇÖZÜM — bu satırı {f} içinde create\'ten ÖNCE ekle:')
        print(f'      drop function if exists public.{name}({psig});')
        print()
    print(f'✗ {len(problems)} fonksiyon 42P13 verecek (cannot change return type).')
    print('  Bu hata CANLIDA ortaya cikar; burada yakalamak bedavadir.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
