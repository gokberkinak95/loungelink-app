#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · sql_mask.py   (17 Ağu 2026 — 187 turunda doğdu)

🔴 NEDEN VAR — ÜÇ ARAÇ AYNI ANDA YALAN SÖYLEDİ:

187 yazıldıktan sonra `npm run verify` kırmızıya döndü ve ÜÇ denetim de
YANLIŞ ALARM verdi. Hiçbiri gerçek bir hata değildi:

  sql_lint     "176/178/179: _akis_tmp SONRAKI ifadelerde kullaniliyor"
               → temp table `rule_full_report()` GÖVDESİNİN İÇİNDE.
                 Gövde tek ifadedir; Supabase onu bölmez. 42P01 olmaz.

  returns_check "176: flow_gate_test dönüş tipi FARKLI, drop YOK
                 önce: returns table (...)
                 şimdi: returns table ' || '(...)"
               → o satır `execute 'create or replace ...'` içindeki
                 DİZE PARÇASI. Gerçek bir tanım değil.

  contract_check "discover_availabilities FAZLA parametre — fonksiyon
                  (187) bunları tanımıyor: []"
               → 187 gövdeyi `execute 'create or replace function
                 public.discover_availabilities(' || v_args || ')'`
                 ile yeniden kuruyor. Ayrıştırıcı bu dizeyi GERÇEK bir
                 imza sanıp parametresiz kaydediyor ve app'in doğru
                 çağrısını hatalı bildiriyor.

ORTAK KÖK: üç ayrıştırıcı da dolar-tırnaklı gövdeleri ($$ … $$,
$BODY$ … $BODY$, $function$ … $function$) ve tek tırnaklı dizeleri
KOD SANIYOR. Gövdenin içi ayrı bir dildir; oradaki `create`,
`;` ve `returns` dışarıdaki ile aynı anlama gelmez.

🔴 BU NEDEN ÖNEMLİ — YANLIŞ ALARM, KAÇIRILAN HATADAN DAHA PAHALI:
Bir denetim üç tur üst üste yanlış alarm verirse insan ona bakmayı
bırakır; o andan sonra GERÇEK hatayı da yakalayamaz, çünkü kimse
okumaz. `npm run verify`'ın kırmızısı ANLAMLI kalmalı.

KULLANIM:
    from sql_mask import mask_bodies, strip_comments
    dis = mask_bodies(src)   # gövdeler ve dizeler BOŞLUKLA doldurulmuş
                             # (uzunluk ve satır numaraları KORUNUR)

⚠️ HANGİ DENETİM HANGİSİNİ KULLANMALI:
  · İFADE düzeyi denetimler (ifade ayrımı, imza, dönüş tipi)
    → mask_bodies() kullan. Gövdenin içi onları ilgilendirmez.
  · İFADE İÇİ denetimler (nullsort, guest_policy filtresi)
    → HAM kaynağı kullan. 183'ün hatalı ORDER BY'ı gövdenin İÇİNDEYDİ;
      maskelenmiş kaynakta arasaydık GERÇEK hatayı kaçırırdık.
  Bu ayrımı bozmak, aracı ya kör ya gürültülü yapar.
"""
import re

__all__ = ['mask_bodies', 'strip_comments', 'allow_replace_marks']

# $$ · $BODY$ · $function$ · $tag$  — açılış etiketi
_DOLLAR_OPEN = re.compile(r'\$([A-Za-z_][A-Za-z0-9_]*)?\$')


def _blank(s: str) -> str:
    """Aynı uzunlukta, satır sonları KORUNMUŞ boşluk üret.
    Satır numaraları ve karakter ofsetleri bozulmasın diye şart —
    aksi hâlde denetim doğru bulguyu YANLIŞ SATIRDA raporlar."""
    return ''.join('\n' if c == '\n' else ' ' for c in s)


def strip_comments(src: str) -> str:
    """`--` satır yorumlarını ve `/* */` blok yorumlarını boşlukla doldur."""
    out = re.sub(r'--[^\n]*', lambda m: ' ' * len(m.group(0)), src)
    out = re.sub(r'/\*.*?\*/', lambda m: _blank(m.group(0)), out, flags=re.S)
    return out


def mask_bodies(src: str, keep_signatures: bool = True) -> str:
    """Dolar-tırnaklı gövdeleri ve tek tırnaklı dizeleri boşlukla doldurur.

    keep_signatures=True iken `create or replace function foo(...)` imzası
    OLDUĞU GİBİ kalır — o zaten gövdenin dışındadır. İçeride kalan
    `execute 'create or replace ...'` gibi DİNAMİK tanımlar silinir;
    zaten silinmesini istediğimiz tam olarak onlar.
    """
    src = strip_comments(src)
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]

        # --- dolar-tırnaklı gövde ---
        if ch == '$':
            m = _DOLLAR_OPEN.match(src, i)
            if m:
                tag = m.group(0)
                end = src.find(tag, m.end())
                if end == -1:
                    # kapanmamış gövde: dosyanın sonuna kadar maskele.
                    # (Bu tek başına bir hata işaretidir; sql_lint'in
                    #  kendi sözdizimi denetimi onu ayrıca yakalar.)
                    for k in range(m.end(), n):
                        if src[k] != '\n':
                            out[k] = ' '
                    break
                for k in range(m.end(), end):
                    if src[k] != '\n':
                        out[k] = ' '
                i = end + len(tag)
                continue

        # --- tek tırnaklı dize ---
        if ch == "'":
            j = i + 1
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":   # kaçışlı ''
                        j += 2
                        continue
                    break
                j += 1
            for k in range(i + 1, min(j, n)):
                if src[k] != '\n':
                    out[k] = ' '
            i = j + 1
            continue

        i += 1
    return ''.join(out)


def allow_replace_marks(src: str) -> set:
    """`-- sqlcheck: allow-replace <fn>` işaretlerini toplar.

    Bu işaret 158'de doğdu: dönüş tipi AYNI kalan bir tablo
    fonksiyonunda drop istemek YANLIŞTIR — drop+create atomik değildir,
    canlıda anlık kesinti ve GRANT kaybı yaratır. returns_check bu
    işareti okumuyordu; artık okuyor."""
    return {m.group(1) for m in
            re.finditer(r'--\s*sqlcheck:\s*allow-replace\s+(\w+)', src, re.I)}


if __name__ == '__main__':
    import sys
    demo = """
create or replace function public.f(a int) returns int
language plpgsql as $$
begin
  create temp table _x as select 1;   -- govde ICINDE: ifade ayrimi YOK
  execute 'create or replace function public.g(' || v_args || ')';
  return 1;
end $$;
"""
    masked = mask_bodies(demo)
    assert 'create temp table' not in masked, 'govde maskelenmedi'
    assert 'public.g' not in masked, 'dinamik tanim maskelenmedi'
    assert 'create or replace function public.f' in masked, 'imza silindi!'
    assert demo.count('\n') == masked.count('\n'), 'satir sayisi degisti'
    print('✓ sql_mask kendi testini gecti (govde maskelendi, imza korundu,'
          ' satir numaralari bozulmadi)')
