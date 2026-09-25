import re
import os, glob, json, sys
from sql_mask import mask_bodies

# v1.94 — yollar SABİT DEĞİL, betiğin konumundan türetiliyor (ll_paths.py).
# Öncesinde Linux yolları gömülüydü ve Windows'ta hiçbir dosya bulunamayıp
# denetim "temiz" diyordu — yani sıfır satır denetlenip yeşil yanıyordu.
import ll_paths
SQL_DIR = ll_paths.sql_dir()
BO_DIR  = ll_paths.bo_dir()
APP_DIR = ll_paths.app_dir()
ll_paths.require_bo('contract_check')
ll_paths.require_sql('contract_check')
ll_paths.require_code('contract_check', [os.path.join(APP_DIR, 'src'), APP_DIR, BO_DIR])

# ---- 1) SQL'de tanimli TUM fonksiyonlar (son tanim kazanir; dosya sirasina gore) ----
def sql_files():
# 🔴 v2.0 — DESEN DUZELTMESI: eskiden '0*.sql' idi ve migration 100'den
# itibaren HICBIR DOSYAYI GORMUYORDU. Uc haneli numaralara gecince
# denetimler sessizce eksik calisiyordu — contract_check bunu
# "fonksiyon SQL'de yok" diye bildirdi ve tuzak boyle yakalandi.
    fs = sorted(glob.glob(os.path.join(SQL_DIR, '[0-9]*.sql')))
    def key(p):
        m = re.match(r'(\d+)([a-z]?)', os.path.basename(p))
        return (int(m.group(1)), m.group(2) or '')
    return sorted(fs, key=key)

defined = {}   # name -> {'params': [...], 'file': ...}
dropped = set()
for f in sql_files():
    # 🔴 187 turu: 187 gövdeleri `execute 'create or replace function
    # public.discover_availabilities(' || v_args || ')'` ile yeniden
    # kuruyor. Ayristirici bu DIZEYI gercek imza sanip parametresiz
    # kaydediyor, sonra app'in DOGRU cagrisini "fazla parametre" diye
    # bildiriyordu. Govde/dize maskelenerek okunur.
    src = mask_bodies(open(f, encoding='utf-8', errors='replace').read())
    for m in re.finditer(r'drop function if exists\s+(?:public\.)?(\w+)\s*\(([^)]*)\)', src, re.I):
        dropped.add(m.group(1))
    for m in re.finditer(r'create or replace function\s+(?:public\.)?(\w+)\s*\(', src, re.I):
        name = m.group(1)
        # parametre listesini PARANTEZ SAYARAK al (cok satirli imzalar icin)
        i = m.end() - 1
        depth = 0; j = i
        while j < len(src):
            if src[j] == '(': depth += 1
            elif src[j] == ')':
                depth -= 1
                if depth == 0: break
            j += 1
        raw = src[i+1:j]
        # yorum satirlarini at
        raw = re.sub(r'--[^\n]*', '', raw)
        params = []
        for p in re.split(r',(?![^()]*\))', raw):
            p = p.strip()
            if not p: continue
            pm = re.match(r'(\w+)\s+([\w\[\]\. ]+?)(?:\s+default\s+(.+))?$', p, re.I | re.S)
            if pm:
                params.append({'name': pm.group(1), 'type': pm.group(2).strip(),
                               'default': pm.group(3) is not None})
        defined[name] = {'params': params, 'file': os.path.basename(f)}

# ---- 2) SQL'de tanimli TABLO + KOLONLAR ----
tables = {}
for f in sql_files():
    src = open(f, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'create table(?: if not exists)?\s+(\w+)\s*\((.*?)\n\);', src, re.S | re.I):
        t, body = m.group(1), m.group(2)
        cols = set()
        for line in body.split('\n'):
            line = line.strip()
            cm = re.match(r'(\w+)\s+', line)
            if cm and cm.group(1).lower() not in ('primary','foreign','unique','check','constraint'):
                cols.add(cm.group(1))
        tables.setdefault(t, set()).update(cols)
    for m in re.finditer(r'alter table\s+(\w+)\s+add column(?: if not exists)?\s+(\w+)', src, re.I):
        tables.setdefault(m.group(1), set()).add(m.group(2))

# ---- 3) Kodun cagirdigi RPC'ler ----
problems = []
calls = []
for d, label in [(BO_DIR, 'BO'), (APP_DIR, 'APP')]:
    for f in glob.glob(os.path.join(d, '**', '*.js'), recursive=True) + \
             glob.glob(os.path.join(d, '**', '*.jsx'), recursive=True):
        if 'node_modules' in f: continue
        src = open(f, encoding='utf-8', errors='replace').read()
        rel = os.path.relpath(f, d)
        for m in re.finditer(r'\.rpc\(\s*["\'](\w+)["\']', src):
            fn = m.group(1)
            # arg nesnesini PARANTEZ SAYARAK al — regex ".*?}" yanlis yerde bitiyordu
            i = m.end()
            while i < len(src) and src[i] in ' \t\n': i += 1
            args = set()
            if i < len(src) and src[i] == ',':
                i += 1
                while i < len(src) and src[i] in ' \t\n': i += 1
                if i < len(src) and src[i] == '{':
                    depth = 0; j = i
                    while j < len(src):
                        if src[j] == '{': depth += 1
                        elif src[j] == '}':
                            depth -= 1
                            if depth == 0: break
                        j += 1
                    argsraw = src[i:j+1]
                    # 🔴 19 Agu 2026 — YORUM SATIRLARI ANAHTAR SANILIYORDU.
                    # Olcum: screens.js'te create_availability cagrisinin
                    # icine Turkce bir aciklama yazdim ve bir satir soyle
                    # bitiyordu:
                    #     // ... ikisi AYRI degiskene yaziyordu: cipler ...
                    # Bu denetim `yaziyordu:` desenini bir NESNE ANAHTARI
                    # sandi ve su hatayi verdi:
                    #     rpc('create_availability') FAZLA parametre
                    #     ['yaziyordu'] — fonksiyon bunlari tanimiyor: [...]
                    # Hem yanlis alarm hem YANILTICI: hata mesaji dokuz
                    # gercek parametreyi "tanimiyor" diye listeliyordu,
                    # yani insani fonksiyon imzasina bakmaya gonderiyordu.
                    #
                    # SQL tarafinda yorumlar zaten temizleniyordu (satir 52,
                    # `--` icin). JS tarafinda ayni sey yapilmamis. Bir
                    # denetimin yalnizca YARISINDA yorum temizligi olmasi,
                    # obur yarisinin uyudugu anlamina geliyor.
                    #
                    # ONCE yorumlar, SONRA string'ler: ters sirada yapilirsa
                    # yorum icindeki tirnak (ornegin "host'un") string
                    # tarayicisini kaydirir — bu turda ayni sinifa iki kez
                    # dustum, ucuncusu olmasin.
                    nocmt = re.sub(r'/\*.*?\*/', '', argsraw, flags=re.S)
                    nocmt = re.sub(r'(?m)//[^\n]*', '', nocmt)
                    # yalniz EN UST seviye anahtarlar
                    # SATIR BASINDAKI anahtarlar (ternary ':' ve template ':' degil)
                    # once string/template literal'leri temizle
                    clean = re.sub(r'`[^`]*`|"[^"]*"|\'[^\']*\'', '""', nocmt)
                    # 🔴 v2.96 — OPSIYONEL ZINCIRLEME `?.` TERNARY SANILIYORDU.
                    # Olcum: `p_destination: dest?.key || null,` satirindan
                    # SONRAKI `p_date` anahtari denetimden DUSUYORDU ve
                    # "EKSIK zorunlu parametre ['p_date']" diye yanlis alarm
                    # veriyordu. Sebep: uye erisimi silinirken `.key` gidiyor
                    # ama `?` KALIYOR; asagidaki ternary korumasi da
                    # "oncesinde ? varsa anahtar degildir" dedigi icin bir
                    # sonraki GERCEK anahtari atliyordu.
                    # 🆕 SINIF: "BIR TARAYICININ 'TERNARY' SANDIGI SEY
                    # OPSIYONEL ZINCIRLEME OLABILIR — `?.` ILE `? :` AYNI
                    # KARAKTERLE BASLAR."
                    # Once `?.`yi tamamen at, SONRA uye erisimini sil.
                    clean = clean.replace('?.', '.')
                    # uye erisimini (obj.key) sil -> anahtar sanilmasin
                    clean = re.sub(r'\.\s*[A-Za-z_$][\w$]*', '', clean)
                    depth = 0; prev_end = 0
                    for k in re.finditer(r'[{}]|([A-Za-z_$][\w$]*)\s*:', clean):
                        if k.group(0) == '{': depth += 1
                        elif k.group(0) == '}': depth -= 1
                        elif depth == 1 and k.group(1):
                            # oncesinde '?' varsa ternary'dir, anahtar degil
                            before = clean[prev_end:k.start()]
                            if '?' in before: 
                                prev_end = k.end(); continue
                            args.add(k.group(1))
                            prev_end = k.end()
            calls.append((label, rel, fn, args))

print("=" * 72)
print("SÖZLEŞME DENETİMİ — kodun çağırdığı her RPC, SQL'de var mı?")
print("=" * 72)
ok = 0
for label, rel, fn, args in calls:
    if fn not in defined:
        problems.append(f"❌ {label}/{rel}: rpc('{fn}') — SQL'de BÖYLE BİR FONKSİYON YOK")
        continue
    d = defined[fn]
    pnames = {p['name'] for p in d['params']}
    required = {p['name'] for p in d['params'] if not p['default']}
    extra = args - pnames
    missing = required - args
    if extra:
        problems.append(f"❌ {label}/{rel}: rpc('{fn}') FAZLA parametre {sorted(extra)} — fonksiyon ({d['file']}) bunları tanımıyor: {sorted(pnames)}")
    if missing:
        problems.append(f"❌ {label}/{rel}: rpc('{fn}') EKSİK zorunlu parametre {sorted(missing)}")
    if not extra and not missing:
        ok += 1

print(f"\nToplam RPC çağrısı: {len(calls)} · uyumlu: {ok} · sorunlu: {len(problems)}\n")
for p in problems: print(p)
if not problems:
    print("✓ tüm RPC çağrıları SQL tanımlarıyla uyumlu")

# 🔴 v2.46 — BU DOSYA HATA BULSA BİLE exit 0 DÖNÜYORDU.
# Mutasyon testinde ortaya çıktı: BO'daki bir rpc adını kasten bozdum,
# denetim ❌ satırını DOĞRU bastı ama çıkış kodu yine 0 oldu.
#
# `npm run verify` dokuz denetimi `&&` ile zincirliyor; zincir yalnız
# çıkış koduna bakar. Yani bu denetim ekrana kırmızı basıyor, zincir
# yeşil devam ediyor ve en sonda "build'e hazır" yazıyordu. Ekranı
# okumayan biri (ya da CI) hatayı hiç görmez.
#
# Sekiz denetimin sekizi doğru kod döndürüyordu; atlanan tek dosya buydu
# ve tam da en çok gerçek hata yakalayan denetimdi (kırık
# respond_connection, olmayan my_credit_balance hep buradan çıkmıştı).
#
# DERS: bir denetimin hatayı GÖRMESİ yetmez, hatayı BİLDİRMESİ gerekir.
# Çıkış kodu, denetimin tek makine-okur çıktısıdır.
sys.exit(1 if problems else 0)
