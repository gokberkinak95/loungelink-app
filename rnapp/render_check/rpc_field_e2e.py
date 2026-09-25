#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · rpc_field_e2e.py   (17 Ağustos 2026 — Tur 4'te doğdu)

🔴 NEDEN VAR — YENİ BİR HATA SINIFI: "OKUNAN ALAN, YAZILAN ALAN DEĞİL"

Gökberk "app'teki kart alanlarını doğrula" dedi. Doğruladım ve ALTI
alanın veritabanında hiç olmadığı çıktı:

    screens.js  fInfo.airline        flight_info() döndürmüyordu
    screens.js  fInfo.airline_iata   flight_cache'te kolon bile yoktu
    screens.js  fInfo.dep_iata       flight_info() döndürmüyordu
    screens.js  fInfo.arr_iata       flight_info() döndürmüyordu
    screens.js  fInfo.dep_time       flight_info() döndürmüyordu
    screens.js  target.same_sector   discover_availabilities döndürmüyordu
    screens.js  sel.access_type      RPC `access_types` (dizi) veriyor
    screens.js  sess.entry_code      `sessions` tablosunda böyle kolon yok

Hiçbiri ÇÖKMEDİ. JavaScript'te olmayan bir alanı okumak `undefined`
verir; React `undefined`i sessizce hiç çizmez. Sonuç: kutular açılıyor,
satırların yarısı boş kalıyor, rozetler hiç görünmüyor — ve kimse
nedenini bilmiyor. Bu, projedeki en pahalı hata türü: SESSİZ olan.

Mevcut denetimlerin hiçbiri bunu göremezdi:
    schema_check  → SQL'in kendi içindeki kolon adlarına bakar
    contract_check→ RPC imzalarının kendi aralarındaki tutarlılığa bakar
    render_check  → ekran ÇİZİLİYOR mu diye bakar (boş satır da çizilir)
Hiçbiri "app'in okuduğu ad, veritabanının ürettiği ad mı" sorusunu
sormuyordu. Bu betik tam olarak onu soruyor.

NASIL ÇALIŞIR
  1. pgserver ile GERÇEK bir PostgreSQL kaldırır, tüm migration'ları
     çalıştırır (pg_run.py) — yani ölçüm CANLI şemadan gelir, dosya
     okumaktan değil.
  2. Veritabanının ÜRETEBİLDİĞİ bütün adları toplar:
       · her tablonun kolonları (public + auth)
       · her fonksiyonun dönüş kolonları ve parametre adları
       · her fonksiyon gövdesindeki jsonb_build_object anahtarları
  3. App/BO/site kaynağından OKUNAN `.alan_adi` erişimlerini toplar.
     Yorumlar ve dizgi sabitleri MASKELENİR (yoksa denetim kaydı
     eylem adları — "lounge.acceptance_save" — hayalet sanılır;
     ilk denememde 40 yanlış alarm verdi).
  4. Yerel olarak tanımlanmış anahtarlar (`{ bir_sey: ... }`),
     i18n anahtarları ve dış API alanları düşülür.
  5. Kalan her ad HAYALETTİR: kod onu okuyor, veritabanı üretmiyor.

NE YAKALAR: yanlış yazılmış alan adı; tekil/çoğul karışması
(access_type ↔ access_types); RPC'den kaldırılmış ama app'te okunmaya
devam eden alan; hiç eklenmemiş alan.
NE YAKALAR (v2 · Tur 6): iki ayrı geçiş çalışıyor.
  GEÇİŞ 1 — genel tarama: alt çizgili her alan adı, veritabanının
  ürettiği adlar kümesiyle karşılaştırılır.
  GEÇİŞ 2 — DEĞİŞKEN DÜZEYİ: hangi değişkenin hangi RPC'den geldiği
  izlenir (`const { data: X } = await supabase.rpc("...")` ve
  `.rpc("...").then(({ data }) => ...)`), sonra o değişkenin okunan
  HER alanı O RPC'nin alan kümesiyle karşılaştırılır. Böylece
    (a) tek kelimelik adlar (`sel.hours`) da kapsama girer,
    (b) "veritabanında VAR ama BU RPC'de YOK" sınıfı yakalanır.
  İkincisi ilk koşuda gerçek bir hata buldu: `lounges_for_airport`
  `scope` döndürüyor, app `l.venue_scope` okuyordu — `venue_scope`
  başka bir tabloda gerçek bir kolon olduğu için genel tarama susuyordu.

NE YAKALAMAZ: prop zinciriyle üç bileşen ötesine taşınan listeler.
Onlar için küçük ve gerekçeli bir açık harita var (PROP_BAGLARI);
haritada bilinmeyen bir RPC adı yazarsa denetim patlar.
"""
import os
import re
import shutil
import pathlib
import subprocess
import sys

import pgserver

BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import ll_paths as _llp  # noqa: F401  (yol çözümü tek kaynaktan)

# ════════════════════════════════════════════════════════════════════
# 🔴 BU HARNESS DİSKİ DOLDURUYORDU — VE BUNU e2e ÇÖKÜNCE ÖĞRENDİM.
# Her koşu `/tmp/ll_<ad>_<pid>` altında yeni bir PostgreSQL veri dizini
# açıyor (~50 MB) ve onu YALNIZ BAŞLANGIÇTA, aynı PID'e denk gelirse
# siliyordu. PID her koşuda farklı olduğu için hiçbir dizin silinmedi.
#
# Ölçüm: 517 artık dizin, 26 GB. Disk %100 dolunca `initdb` düştü ve
# e2e "başarısız" verdi — ama kodda hiçbir şey bozulmamıştı. Yani
# harness, ölçtüğü şey hakkında YANLIŞ HABER veriyordu.
#
# 🆕 SINIF: "GEÇİCİ DOSYAYI BAŞLANGIÇTA TEMİZLEMEK TTEMİZLİK DEĞİLDİR —
# ÇIKIŞTA TEMİZLEMEZSEN, HER KOŞU BİR ÖNCEKİNİ DEĞİL KENDİNİ BIRAKIR."
#
# İki katman: (1) çıkışta kendi dizinini sil, (2) başlangıçta ESKİ
# kardeşlerini süpür (çöken bir koşu çıkışa hiç gelmez).
def _ll_temizle(_d):
    import atexit, glob as _g, shutil as _s, os as _o, pathlib as _p, re as _r
    kok = _p.Path(_d)
    onek = _r.sub(r'_\d+$', '', kok.name)
    for eski in _g.glob('/tmp/' + onek + '_*'):
        if _p.Path(eski) != kok:
            _s.rmtree(eski, ignore_errors=True)
    atexit.register(lambda: _s.rmtree(str(kok), ignore_errors=True))


ns = {}
exec(open(ROOT / 'pg_run.py').read().replace(
    "if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns['install_fake_extensions']()

D = pathlib.Path('/tmp/ll_rpcfield_' + str(os.getpid()))

_ll_temizle(D)
if D.exists():
    shutil.rmtree(D, ignore_errors=True)
D.mkdir(parents=True)
srv = pgserver.get_server(D)
uri = srv.get_uri()


def q(sql):
    r = subprocess.run([str(BIN / 'psql'), uri, '-X', '-t', '-A', '-c', sql],
                       capture_output=True, text=True, env=ENV)
    return [l for l in r.stdout.splitlines() if l.strip()]


# ============================================================
# 1) ŞEMAYI KUR
# ============================================================
print('\n' + '=' * 72)
print('RPC ALAN DENETİMİ — app hangi adı okuyor, veritabanı hangi adı üretiyor')
print('=' * 72)

subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-c', ns['SHIM']],
               capture_output=True, text=True, env=ENV)

# 🔴 SIRALAMA KURALI pg_run.py ile AYNI olmak ZORUNDA: "087a_" (PRE_drop)
# her zaman "087_"den ÖNCE çalışır. Düz `sorted()` bunu ters yapar ve
# 088 "does not exist" der. flow_matrix_e2e.py da aynı satırı taşıyor.
sd = _llp.sql_dir()
_o = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1),
                0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
# 🔴 31 AĞUSTOS — RAPOR/ARAÇ DOSYALARI DA `pg_run.py` İLE AYNI
# DIŞLANMAK ZORUNDA. `pg_run.py`ye bugün iki dışlama eklendi:
#   000_HANGI_SQL_KURULU.sql   → salt okunur RAPOR, migration değil
#   268a_telefon_cakismasi.sql → elde çalıştırılan OPERATÖR aracı
# Bu dosya listeyi kendi kuruyordu ve o dışlamaları almadı; sonuç:
# `npm run e2e` "3 migration düştü" diyerek ölçüm yapamıyordu.
#
# Yorumda "pg_run.py ile AYNI olmak ZORUNDA" yazıyordu — ama kural
# iki yerde AYRI AYRI yazılıydı, yani "aynı" olmasını hiçbir şey
# garanti etmiyordu. Artık liste TEK KAYNAKTAN okunuyor.
#
# 🆕 SINIF: "'ŞU DOSYAYLA AYNI OLMALI' DİYE YAZILMIŞ HER KURAL, BİR
# GÜN AYNI OLMAYI BIRAKIR — TEK ÇARE O KURALI İKİ YERDE DEĞİL BİR
# YERDE TUTMAKTIR."
import importlib.util as _iu
_spec = _iu.spec_from_file_location('_pgrun', os.path.join(sd, 'pg_run.py'))
_pg = _iu.module_from_spec(_spec); _spec.loader.exec_module(_pg)
files = ([b for _n, b, _p in _pg.files()]
         + sorted(x for x in os.listdir(sd) if x.startswith('SEED')))

hata = 0
for f in files:
    r = subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                        '-f', os.path.join(sd, f)], capture_output=True, text=True, env=ENV)
    if r.returncode:
        hata += 1
        ilk = next((l for l in r.stderr.splitlines() if 'ERROR' in l), '?')
        print(f'  ✗ {f}: {ilk.strip()[:140]}')
if hata:
    print(f'\n✗ {hata} migration düştü — alan denetimi ölçüm yapamaz.')
    sys.exit(1)
print(f'  ✓ {len(files)} SQL dosyası kuruldu')


# ============================================================
# 2) VERİTABANININ ÜRETEBİLDİĞİ ADLAR
# ============================================================
uretilen = set()
for l in q("select column_name from information_schema.columns "
           "where table_schema in ('public','auth')"):
    uretilen.add(l.strip())

TIPLER = (r'uuid|text|int|integer|bigint|smallint|boolean|numeric|date|jsonb|json|'
          r'time|timestamp|real|double|char|bytea|interval|record')
for l in q("select coalesce(pg_get_function_result(p.oid),'')||' '||"
           "coalesce(pg_get_function_arguments(p.oid),'') "
           "from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
           "where n.nspname='public'"):
    for tok in re.findall(r'\b([a-z][a-z0-9_]*)\s+(?:%s)\b' % TIPLER, l):
        uretilen.add(tok)

# jsonb_build_object('anahtar', deger, ...) → anahtar adları
for l in q("select replace(string_agg(p.prosrc,' '),chr(10),' ') "
           "from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
           "where n.nspname='public'"):
    for k in re.findall(r"'([a-z][a-z0-9_]{2,40})'\s*,", l):
        uretilen.add(k)

# 🔴 TABLO ADLARI da üretilen addır: PostgREST gömülü ilişkiyi tablo
# adıyla döndürür — `select("*, trust_scores(*)")` sonucu `u.trust_scores`
# olur. İlk sürüm bunu hayalet sandı.
for l in q("select table_name from information_schema.tables where table_schema='public'"):
    uretilen.add(l.strip())

# 🔴 beta_settings ANAHTARLARI da üretilen addır: BO ayarları
# `Object.fromEntries(rows)` ile nesneye çevirip `cfg.flight_month_cap`
# diye okuyor. Anahtar VERİTABANINDA yaşıyor, kodda değil — bu yüzden
# yerel anahtar taramasına takılmıyordu ve hayalet sanıldı.
for l in q("select key from beta_settings"):
    uretilen.add(l.strip())

# 🔴 `to_jsonb(x)` / `row_to_json(x)` ALTINDAKİ SÜTUN TAKMA ADLARI.
# ÖLÇÜM (17 Ağu): SQL 213'ün sağlayıcı fonksiyonları satırlarını
#     select jsonb_agg(to_jsonb(w)) from ( ... min(price) as en_dusuk ... ) w
# kalıbıyla kuruyor. Anahtar adı `jsonb_build_object('en_dusuk', ...)`
# olarak GEÇMİYOR; alt sorgunun TAKMA ADI olarak geçiyor. Bu yüzden
# denetim `.en_dusuk`, `.en_yuksek`, `.benim_fiyatim`, `.fark_yuzde`,
# `.salon_sayisi`, `.kume_en_yeni_kontrol` alanlarını HAYALET sandı —
# oysa altısı da gerçekten üretiliyor (fonksiyonu çağırıp gördüm).
#
# Yanlış pozitif, denetimi gözardı etmeyi öğretir; bu depoda o dersin
# yazılı olduğu iki ayrı yer var. Çözüm denetimi gevşetmek DEĞİL,
# üreten kalıbı da tanımak: gövdede `to_jsonb`/`row_to_json` geçen
# fonksiyonlarda `... as <ad>` takma adlarını da üretilen kabul et.
for l in q("select replace(coalesce(p.prosrc,''), chr(10), ' ') "
           "from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
           "where n.nspname='public' "
           "and (p.prosrc ilike '%to_jsonb(%' or p.prosrc ilike '%row_to_json(%')"):
    for k in re.findall(r'\bas\s+([a-z][a-z0-9_]{2,40})\b', l, re.I):
        uretilen.add(k.lower())

print(f'  ✓ veritabanı {len(uretilen)} farklı alan adı üretebiliyor')


# ============================================================
# 3) KAYNAKTAN OKUNAN ADLAR
# ============================================================
def maskele(s):
    """Yorumları ve dizgi sabitlerini BOŞLUKLA doldurur; satır sayısı korunur.

    🔴 Bu maskeleme olmadan denetim işe yaramaz: BO'daki denetim kaydı
    eylem adları ("lounge.acceptance_save") dizgi İÇİNDE geçiyor ve
    `.acceptance_save` gibi görünüyor. İlk sürümde 40 yanlış alarm
    verdi — bir aracın yanlış alarmı, kaçırdığı hatadan pahalıdır.
    """
    s = re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group(0)), s, flags=re.S)
    # 🔴 UZUNLUK KORUNMALI. Satır yorumunu SİLMEK (yerine boşluk
    # koymamak) ham metinle maskeli metnin ofsetlerini kaydırıyordu;
    # `.then` gövdesini ham ofsetle kesip maskeli metinden okuyunca
    # YANLIŞ ARALIK taranıyor ve denetim sessizce hiçbir şey bulmuyordu.
    # Maskeleme bir dönüşüm değil, bir ÖRTMEDİR: boyut değişmez.
    s = '\n'.join(re.sub(r'//.*$', lambda m: ' ' * len(m.group(0)), line) for line in s.split('\n'))
    # 🔴 DİZGİ MASKELEME SATIR SONUNDA DURMALI.
    # İlk sürüm ' " ` üçünü de `re.S` ile maskeliyordu; JavaScript'te
    # tek/çift tırnaklı dizgi SATIR ATLAYAMAZ, ama JSX METİN DÜĞÜMLERİ
    # Türkçe kesme işareti taşıyor ("Gökberk'in", "host'un"). Tek başına
    # kalan o kesme işareti bir dizgi başlatıyor ve BİR SONRAKİ kesme
    # işaretine kadar HER ŞEYİ boşluğa çeviriyordu.
    # ÖLÇÜM: screens.js'in %54,5'i maskeleniyordu — yani denetim
    # dosyanın yarısını hiç görmüyordu ve "temiz" diyordu.
    # Tek tırnak/çift tırnak satırda kalır; yalnız ters tırnak (template
    # literal) satır atlayabilir.
    s = re.sub(r"'(?:\\.|[^'\\\n])*'", lambda m: "'" + ' ' * (len(m.group(0)) - 2) + "'", s)
    s = re.sub(r'"(?:\\.|[^"\\\n])*"', lambda m: '"' + ' ' * (len(m.group(0)) - 2) + '"', s)
    s = re.sub(r'`(?:\\.|[^`\\])*`', lambda m: '`' + ' ' * (len(m.group(0)) - 2) + '`', s, flags=re.S)
    return s


def js_dosyalari():
    hedef = {}
    app = ROOT
    hedef['app'] = [app / 'App.js'] + sorted((app / 'src').glob('*.js'))
    bo = ROOT.parent / 'backoffice'
    if bo.exists():
        hedef['backoffice'] = [p for p in bo.rglob('*.js*')
                               if '.next' not in p.parts and 'node_modules' not in p.parts]
    site = ROOT.parent / 'website'
    if site.exists():
        hedef['site'] = [p for p in site.rglob('*.js*')
                         if '.next' not in p.parts and 'node_modules' not in p.parts]
    return hedef


# JavaScript'in KENDİ üyeleri — bir veri alanı değil, dilin parçası.
JS_UYELERI = {
    'length', 'map', 'filter', 'forEach', 'find', 'findIndex', 'includes', 'indexOf',
    'slice', 'splice', 'join', 'push', 'pop', 'shift', 'sort', 'reverse', 'concat',
    'reduce', 'some', 'every', 'flat', 'flatMap', 'keys', 'values', 'entries',
    'toString', 'toFixed', 'trim', 'split', 'replace', 'toUpperCase', 'toLowerCase',
    'then', 'catch', 'finally', 'startsWith', 'endsWith', 'padStart', 'padEnd',
    'getTime', 'toISOString', 'toLocaleString', 'toLocaleDateString', 'charAt',
    'match', 'test', 'repeat', 'substring', 'substr', 'at', 'data', 'error', 'status',
}

# i18n anahtarları: `t.birSey` diye okunuyor ama veritabanı alanı değil.
i18n = set()
i18n_yol = ROOT / 'src' / 'i18n.js'
if i18n_yol.exists():
    i18n |= set(re.findall(r'\b([a-zA-Z][a-zA-Z0-9_]*)\s*:', i18n_yol.read_text(encoding='utf-8')))

# Bizim şemamızda olmayan ama MEŞRU dış alanlar. Her biri gerekçeli.
DIS_ALANLAR = {
    'access_token':      'Supabase auth oturum nesnesi',
    'refresh_token':     'Supabase auth oturum nesnesi',
    'expires_at':        'Supabase auth oturum nesnesi',
    'email_confirmed_at': 'Supabase auth.users (bizim şemamız değil)',
    'phone_confirmed_at': 'Supabase auth.users',
    'user_metadata':     'Supabase auth.users',
    'app_metadata':      'Supabase auth.users',
    'flight_status':     'AviationStack yanıtı (BO rotası)',
    'flight_date':       'AviationStack yanıtı / flight_cache',
    'flight_iata':       'AviationStack yanıtı',
    'airline_name':      'AviationStack codeshared nesnesi',
    'status_code':       'HTTP yanıtı',
    'content_type':      'HTTP başlığı',
    'error_code':        'Supabase auth yönlendirme parametresi (deeplink)',
    'error_description': 'Supabase auth yönlendirme parametresi (deeplink)',
}

toplam_okunan = 0
hayaletler = []
for proje, dosyalar in js_dosyalari().items():
    yerel = set()
    okunan = {}
    for f in dosyalar:
        try:
            ham = f.read_text(encoding='utf-8')
        except Exception:
            continue
        s = maskele(ham)
        # `{ bir_sey: ... }` — kodun KENDİ ürettiği anahtarlar
        yerel |= set(re.findall(r'\b([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\s*:', s))
        for m in re.finditer(r'\.([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\b', s):
            okunan.setdefault(m.group(1), []).append(
                (f.name, s[:m.start()].count('\n') + 1))
    toplam_okunan += len(okunan)
    for ad, yerler in sorted(okunan.items()):
        if ad in uretilen or ad in yerel or ad in i18n or ad in DIS_ALANLAR:
            continue
        hayaletler.append((proje, ad, yerler))

print(f'  ✓ kaynakta {toplam_okunan} farklı alan adı okunuyor')


# ============================================================
# 4) SONUÇ
# ============================================================

# ============================================================
# 3b) RPC SONUÇ DEĞİŞKENİ TAKİBİ — tek kelimelik alanları da yakalar
# ============================================================
# 🔴 NEDEN GEREKLİ: yukarıdaki genel tarama yalnız alt çizgili adlara
# bakabiliyor, çünkü `sel.hours` gibi tek kelimelik bir ad yerel bir
# değişkenden ayırt edilemiyor. Ama asıl tehlikeli hata sınıfı bu
# değil: bir alan adı VERİTABANINDA VAR ama O RPC'DE YOK olabilir.
#
# Gerçek örnek (bu turda bulundu): `lounges_for_airport` `scope`
# döndürüyor; app `l.venue_scope` okuyor. `venue_scope` başka bir
# tabloda GERÇEK bir kolon olduğu için genel tarama SUSUYOR — oysa
# bu RPC onu hiç döndürmüyor ve salon sekmesi sessizce "other"a
# düşüyor.
#
# Çözüm: hangi değişkenin hangi RPC'den geldiğini izle, sonra o
# değişkenin okunan HER alanını O RPC'nin alan kümesiyle karşılaştır.
# Tek kelimelik adlar da böylece kapsama giriyor.
print('--- RPC sonuç değişkeni takibi ---')

rpc_alanlari = {}
for l in q("select p.proname || '§' || coalesce(pg_get_function_result(p.oid),'') "
           "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
           "where n.nspname = 'public'"):
    ad, res = (l.split('§') + [''])[:2]
    if res.strip().lower().startswith('table('):
        ic = res[res.index('(') + 1: res.rindex(')')]
        alanlar = set(re.findall(r'(?:^|,)\s*([a-z_][a-z0-9_]*)\s+', ic))
        rpc_alanlari.setdefault(ad, set()).update(alanlar)

# jsonb dönenler: gövdedeki jsonb_build_object anahtarları
for l in q("select p.proname || '§' || replace(coalesce(p.prosrc,''), chr(10), ' ') "
           "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
           "where n.nspname = 'public' and pg_get_function_result(p.oid) = 'jsonb'"):
    ad, src = (l.split('§') + [''])[:2]
    rpc_alanlari.setdefault(ad, set()).update(
        re.findall(r"'([a-zA-Z][a-zA-Z0-9_]{1,40})'\s*,", src))

# 🔴 PROP ÜZERİNDEN GEÇEN LİSTELER için AÇIK harita. Bunlar bir
# bileşenden diğerine prop olarak geçiyor; otomatik izleme zinciri
# takip edemiyor. Harita KÜÇÜK ve GEREKÇELİ tutuluyor; bilinmeyen bir
# RPC adı yazılırsa denetim patlar (aşağıda kontrol var).
PROP_BAGLARI = {
    'lounges': 'lounges_for_airport',   # LoungePicker'a prop olarak geçiyor
    'sel':     'lounges_for_airport',   # LoungePicker içinde seçili salon
}
for _v, _r in PROP_BAGLARI.items():
    if _r not in rpc_alanlari:
        print(f'✗ PROP_BAGLARI bilinmeyen RPC gösteriyor: {_r}')
        srv.cleanup(); shutil.rmtree(D, ignore_errors=True); sys.exit(1)

# 🔴 İKİ KAYNAK BİRDEN GEREKİYOR. RPC ADI bir DİZGİ ("host_requests")
# ve maskeleme dizgileri boşaltıyor — maskelenmiş metinde bağ HİÇ
# bulunamıyor (ilk sürümde 14 bağın 14'ünü de kaçırdı). Alan okumaları
# ise maskelenmiş metinden okunmalı, yoksa yorum ve dizgi içindekiler
# alan sanılıyor. sql_mask.py'nin "ifade düzeyi maskeli, ifade içi ham"
# dersinin JavaScript hâli.
app_ham, app_mask = {}, {}
for f in [ROOT / 'App.js'] + sorted((ROOT / 'src').glob('*.js')):
    try:
        ham = f.read_text(encoding='utf-8')
    except Exception:
        continue
    app_ham[f.name] = ham
    app_mask[f.name] = maskele(ham)

# Kodun KENDİ eklediği anahtarlar (`{...l, key: l.id, label: ...}`)
eklenen = set()
for s_ in app_mask.values():
    eklenen |= set(re.findall(r'\b([a-zA-Z][a-zA-Z0-9_]*)\s*:', s_))


def alanlari_dogrula(dosya, metin, ofset, degisken, rpc, bilinen, kotu):
    """`degisken.alan` ve `degisken.map(x => x.alan)` okumalarını sınar."""
    for m in re.finditer(r'\b' + re.escape(degisken) + r'\s*\??\.\s*([a-zA-Z][a-zA-Z0-9_]*)\b', metin):
        alan = m.group(1)
        if alan in bilinen or alan in eklenen or alan in JS_UYELERI or alan in DIS_ALANLAR:
            continue
        kotu.append((dosya, (ofset + m.start()), degisken, rpc, alan))
    for m in re.finditer(
            r'\b' + re.escape(degisken) + r'\s*(?:\|\|\s*\[\])?\s*\)?\s*\.\s*(?:map|forEach|filter|find)\('
            r'\s*\(?\s*([A-Za-z_$][\w$]*)', metin):
        it = m.group(1)
        govde = metin[m.end(): m.end() + 900]
        for m2 in re.finditer(r'\b' + re.escape(it) + r'\s*\??\.\s*([a-zA-Z][a-zA-Z0-9_]*)\b', govde):
            alan = m2.group(1)
            if alan in bilinen or alan in eklenen or alan in JS_UYELERI or alan in DIS_ALANLAR:
                continue
            kotu.append((dosya, (ofset + m.start()), f'{degisken}[].{it}', rpc, alan))


# ---- (a) `const { data: VAR } = await supabase.rpc("NAME")` ----
# Aynı ad İKİ farklı RPC'ye bağlıysa ATLANIR: belirsiz bir bağ üzerinden
# alarm üretmek yanlış alarmdır.
bag, cakisan = {}, set()
for fn, ham in app_ham.items():
    for m in re.finditer(
            r'const\s*\{\s*data\s*:\s*([A-Za-z_$][\w$]*)[^}]*\}\s*=\s*await\s+'
            r'supabase\s*\.\s*rpc\(\s*"([a-z_0-9]+)"', ham):
        v, r = m.group(1), m.group(2)
        if v in bag and bag[v] != r:
            cakisan.add(v)
        bag[v] = r
for v in cakisan:
    bag.pop(v, None)
bag.update(PROP_BAGLARI)

kotu = []
for fn, mask in app_mask.items():
    for v, r in bag.items():
        bilinen = rpc_alanlari.get(r, set())
        if bilinen:
            alanlari_dogrula(fn, mask, 0, v, r, bilinen, kotu)

# ---- (b) `.rpc("NAME", ...).then(({ data }) => { ... })` ----
# Burada `data` YEREL bir ada bağlı: yalnız o okun gövdesinde geçerli.
# Gövdeyi süslü parantez sayarak kesiyoruz; kesilemezse 1200 karakter.
then_sayisi = 0
for fn, ham in app_ham.items():
    mask = app_mask[fn]
    for m in re.finditer(r'\.\s*rpc\(\s*"([a-z_0-9]+)"[^;]{0,400}?\.\s*then\(\s*\(\s*\{\s*data\b', ham, re.S):
        r = m.group(1)
        bilinen = rpc_alanlari.get(r, set())
        if not bilinen:
            continue
        # 🔴 GÖVDE OKUN ARDINDAN BAŞLAR. İlk yazımda saymayı `data`nın
        # hemen ardından başlattım; oysa orada YIKIM PARANTEZİ hâlâ
        # açıktı (`{ data, error }`) ve ilk `}` gövdeyi sıfır uzunlukta
        # kesiyordu — 14 blok bağlandı, hiçbiri taranmadı. Sessizce
        # "temiz" diyen bir denetim, olmayan denetimden kötüdür.
        ok = ham.find('=>', m.end(), m.end() + 200)
        if ok < 0:
            continue
        bas = ham.find('{', ok, ok + 40)
        if bas < 0:
            continue
        bas += 1
        derinlik, son = 1, min(len(ham), bas + 2400)
        for k in range(bas, son):
            c = ham[k]
            if c == '{':
                derinlik += 1
            elif c == '}':
                derinlik -= 1
                if derinlik == 0:
                    son = k
                    break
        then_sayisi += 1
        alanlari_dogrula(fn, mask[bas:son], bas, 'data', r, bilinen, kotu)

print(f'  ✓ {len(bag)} değişken + {then_sayisi} `.then` bloğu '
      f'{len(set(bag.values()))}+ RPC\'ye bağlandı'
      + (f' · {len(cakisan)} belirsiz bağ atlandı' if cakisan else ''))

if kotu:
    print()
    print('✗ RPC ALAN UYUŞMAZLIĞI — değişken o RPC\'nin döndürmediği bir alanı okuyor:')
    gorulen = set()
    for fn, off, v, r, alan in kotu:
        anahtar = (fn, v, alan)
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        satir = app_mask[fn][:off].count('\n') + 1
        print(f'    {fn}:{satir}  {v}.{alan}   → {r}() bu alanı DÖNDÜRMÜYOR')
    print()
    print('  Alan adı veritabanında BAŞKA bir yerde var olabilir; önemli olan')
    print('  BU RPC\'nin onu döndürüp döndürmediği. Ya RPC\'ye ekle ya adı düzelt.')
    srv.cleanup()
    shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print('  ✓ Değişken düzeyinde uyuşmazlık yok (tek kelimelik alanlar dahil)')


# ============================================================
# (c) NESNE DÖNEN RPC'nin SONUCU SKALER GİBİ GEÇİRİLİYOR MU
# ============================================================
# 🔴 v2.71 — BU DENETİM BİR HATANIN ARDINDAN DOĞDU, ÖNCESİNDEN DEĞİL.
#
# `create_availability` jsonb döndürüyor:
#     {"ok":true,"id":"...","visibility":"Public","min_trust":0}
# Kod ise sonucu `newId` diye adlandırıp üç ayrı RPC'ye
# `p_avail_id: newId` olarak geçiriyordu. PostgREST bir NESNEYİ uuid
# parametresine yazamaz — üçü de 22P02 ile düşüyor, ikisinin `catch`i
# hatayı yutuyordu. Sonuç: host'un seçtiği CHARTER, TAŞIYICI ve KABİN
# ilana hiç yazılmıyordu ve kural motoru bu üç alana bakarak karar
# veriyor. Ekranda hiçbir hata yok, üründe sessiz yanlış karar var.
#
# Yukarıdaki (a) ve (b) denetimleri bunu YAKALAYAMAZ: onlar
# "değişken YANLIŞ ALAN okuyor mu" diye bakıyor; buradaki hata
# "değişken HİÇ alan okumadan geçiriliyor".
#
# KURAL: jsonb dönen bir RPC'nin sonucu, adı `p_` ile başlayan bir
# parametreye DOĞRUDAN geçirilemez. Ya `.id` gibi bir alan okunur ya
# da parametrenin kendisi jsonb'dir (o durumda ad listeye eklenir).
JSONB_PARAM_ISTISNA = {
    # Parametresi gerçekten jsonb olan çağrılar buraya yazılır.
    'p_permissions', 'p_payload', 'p_filters', 'p_meta',
}
jsonb_donenler = set(q(
    "select proname from pg_proc "
    "where pronamespace='public'::regnamespace and prokind='f' "
    "and pg_get_function_result(oid) in ('jsonb','json')"))

skaler_hatasi = []
for fn, mask in app_mask.items():
    for v, r in bag.items():
        if r not in jsonb_donenler:
            continue
        for m in re.finditer(r'\b(p_[a-z0-9_]+)\s*:\s*' + re.escape(v) + r'\s*[,}\n]', mask):
            if m.group(1) in JSONB_PARAM_ISTISNA:
                continue
            satir = mask[:m.start()].count('\n') + 1
            skaler_hatasi.append((fn, satir, v, r, m.group(1)))

if skaler_hatasi:
    print()
    print('✗ NESNE, SKALER YERİNE GEÇİRİLİYOR — çağrı sessizce düşer:')
    for fn, satir, v, r, p in skaler_hatasi:
        print(f'    {fn}:{satir}  {p}: {v}   → {r}() bir NESNE döndürür, uuid/metin değil')
    print()
    print('  Düzeltme: `const id = sonuc && typeof sonuc === "object" ? sonuc.id : sonuc;`')
    print('  Bu hata ÇÖKMEZ; PostgREST 22P02 döner ve çoğu çağrı yerinde yutulur.')
    srv.cleanup()
    shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print(f'  ✓ Nesne dönen {len(jsonb_donenler)} RPC\'nin sonucu hiçbir yerde '
      f'skaler parametreye geçirilmiyor')


# ============================================================
# (d) UYGULAMA, YAZMA HAKKI OLMAYAN BİR TABLOYA YAZIYOR MU
# ============================================================
# 🔴 v2.74 — BU DENETİM ÜÇ SESSİZ KUSURUN ARDINDAN DOĞDU (SQL 207).
# `users`, `availabilities` ve `chat_channels`: üçünde de RLS
# POLİTİKASI DOĞRU yazılmıştı ama GRANT hiç verilmemişti. Kapıyı
# kilitleyip anahtarı kimseye vermemek gibi — PostgREST 42501 dönüyor,
# çağıran `error`'u okumuyor, kullanıcı hiçbir şey görmüyor.
# Somut sonucu: host "İlanı kaldır"a basıyor, liste tazeleniyor ve
# ilan geri geliyor.
#
# ⚠️ İLK DENEMEMDE BU DENETİMİ pg_run.py'ye KATALOG SORGUSU olarak
# yazdım ve ALTI YANLIŞ ALARM üretti (`messages`, `disputes`,
# `push_tokens`, `lounge_offers`, `partner_rule_cards`,
# `lounge_field_reports`). Hepsinin politikası var ama uygulama
# onlara DOĞRUDAN yazmıyor — RPC üzerinden gidiyor ya da yalnız BO
# service_role ile dokunuyor. Yani politika+grant eşleşmemesi tek
# başına kusur DEĞİL; kusur, UYGULAMANIN YAZDIĞI bir tabloda hakkın
# olmaması. Doğru soru ancak kaynak koda bakılarak sorulur — bu yüzden
# denetim buraya taşındı.
#
# Yanlış alarm üreten bir denetim, denetim olmaktan çıkar: birkaç tur
# sonra herkes onu görmezden gelir.
HAK = {'insert': 'INSERT', 'update': 'UPDATE', 'upsert': 'INSERT', 'delete': 'DELETE'}

# 🔴 ADI MASKEDEN DEĞİL, HAM METİNDEN OKU. `maskele()` dizgi
# İÇERİĞİNİ boşluğa çeviriyor (tırnakları koruyarak), yani maskede
# `.from("     ")` görünüyor ve tablo adı kayboluyor. İlk denememde
# regex'i maskeye uyguladım ve denetim "0 tablo" deyip yeşil geçti —
# yani hiçbir şey ölçmeden başarılı göründü. Doğru yol: YAPIYI
# maskede bul (yorum içindeki örnekler elensin), ADI aynı ofsetten
# HAM metinden oku (maskeleme uzunluğu koruduğu için ofsetler birebir).
YAZMA_YAPI = re.compile(r'\.from\(\s*"[^"]*"\s*\)((?:[^;]{0,400}?))\.(insert|update|upsert|delete)\s*\(')
AD = re.compile(r'\.from\(\s*"([a-z_0-9]+)"')

yazilan = {}
for fn, mask in app_mask.items():
    ham = app_ham[fn]
    for m in YAZMA_YAPI.finditer(mask):
        adm = AD.match(ham, m.start())
        if not adm:
            continue
        tablo, islem = adm.group(1), m.group(2)
        satir = mask[:m.start()].count('\n') + 1
        yazilan.setdefault((tablo, HAK[islem]), []).append(f'{fn}:{satir}')

haksiz = []
for (tablo, hak), yerler in sorted(yazilan.items()):
    r = q("select coalesce(has_table_privilege('authenticated','public.%s','%s')::text,'?')" % (tablo, hak))
    if not r:
        continue
    # ⚠️ `boolean::text` PostgreSQL'de 'true'/'false' verir — psql'in
    # tablo çıktısındaki 't'/'f' DEĞİL. Bu tuzağa bu oturumda ÜÇÜNCÜ
    # kez düştüm (flight_chain testinde `flight_verified::text` ile
    # aynısı). Yanlış karşılaştırma yüzünden denetim `visits/DELETE`
    # için yanlış alarm verdi — hak ZATEN vardı.
    if r[0].strip() != 'true':
        # upsert INSERT + UPDATE ister; ikisini de ayrica soruyoruz
        kolon = q("select count(*) from information_schema.column_privileges "
                  "where table_schema='public' and table_name='%s' "
                  "and grantee='authenticated' and privilege_type='%s'" % (tablo, hak))
        if kolon and kolon[0].strip() not in ('0', ''):
            continue        # kolon duzeyinde verilmis (bkz. users.role/gender)
        haksiz.append((tablo, hak, yerler))

if haksiz:
    print()
    print('✗ HAKSIZ YAZMA — uygulama bu tabloya yazıyor ama `authenticated` YETKİSİ YOK:')
    for tablo, hak, yerler in haksiz:
        print(f'    {tablo} / {hak}   → {", ".join(yerler[:4])}')
    print()
    print('  PostgREST 42501 döner. Çağıran `error`\'ü okumuyorsa kullanıcı')
    print('  HİÇBİR ŞEY görmez; işlem yapılmamış gibi devam eder.')
    print('  Çözüm: `grant <hak> on public.<tablo> to authenticated;`')
    print('  (kolon düzeyinde vermek daha güvenliyse onu tercih et)')
    srv.cleanup()
    shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print(f'  ✓ Uygulamanın doğrudan yazdığı {len(set(t for t, _ in yazilan))} tablonun '
      f'hepsinde yazma yetkisi var')

print()
if hayaletler:
    print('✗ HAYALET ALAN — kod okuyor, veritabanı ÜRETMİYOR:')
    for proje, ad, yerler in hayaletler:
        konum = ', '.join(f'{d}:{n}' for d, n in yerler[:4])
        print(f'    [{proje}] .{ad}   → {konum}')
    print()
    print('  Bu satırlar ÇÖKMEZ; sessizce undefined okur ve ekranda BOŞ görünür.')
    print('  Her biri için karar ver: alan RPC\'ye EKLENMELİ mi, yoksa')
    print('  kod YANLIŞ ADI mı okuyor?')
    srv.cleanup()
    shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print('✓ Hayalet alan yok — okunan her ad veritabanının ürettiği bir ad.')

# ---- Ek ölçüm: bilinen kritik RPC'lerin alanları gerçekten dönüyor mu ----
# 🔴 "var olmak ≠ çalışmak" (193'ün dersi): imzada görünmesi yetmez,
# ÇAĞRILINCA o kolon adının gelmesi lazım.
KRITIK = {
    'flight_info': ['dep_iata', 'arr_iata', 'dep_time', 'airline', 'airline_iata',
                    'operating_iata', 'codeshare'],
    'discover_availabilities': ['same_sector', 'guest_policy', 'blocks_request'],
    'lounges_for_airport': ['access_types', 'section', 'display_name', 'scope'],
    'my_sent_requests': ['lounge_name', 'airport_code', 'carrier', 'guest_policy'],
    'pending_ratings': ['other_name', 'airport_code', 'flight_number', 'carrier'],
    'my_access_cards': ['card_label', 'bank_code', 'card_product', 'bank_dependent'],
}
eksik = []
for fn, alanlar in KRITIK.items():
    imza = q("select coalesce(pg_get_function_result(oid),'') from pg_proc "
             "where proname='%s' and pronamespace='public'::regnamespace limit 1" % fn)
    imza_txt = imza[0] if imza else ''
    if imza_txt.strip().lower() == 'jsonb':
        # jsonb dönenler gövdeden okunur
        govde = q("select replace(prosrc,chr(10),' ') from pg_proc where proname='%s' "
                  "and pronamespace='public'::regnamespace limit 1" % fn)
        imza_txt = govde[0] if govde else ''
    for a in alanlar:
        if a not in imza_txt:
            eksik.append(f'{fn}.{a}')

if eksik:
    print('\n✗ KRİTİK ALANLAR EKSİK: ' + ', '.join(eksik))
    srv.cleanup()
    shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print(f'✓ {len(KRITIK)} kritik RPC\'nin sözleşme alanları yerinde '
      f'({sum(len(v) for v in KRITIK.values())} alan).')
print('=' * 72)

srv.cleanup()
shutil.rmtree(D, ignore_errors=True)
sys.exit(0)
