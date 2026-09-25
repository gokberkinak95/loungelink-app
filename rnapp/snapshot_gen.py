#!/usr/bin/env python3
# LoungeLink · snapshot_gen.py — ETKİN TANIMLAR ANLIK GÖRÜNTÜSÜ
# ----------------------------------------------------------------------------
# NEDEN VAR:
# 63 SQL dosyası var ve 10'dan fazla fonksiyon birden çok dosyada tanımlı.
# "create_request'in canlıdaki hâli hangisi?" sorusunun cevabı için dosyaları
# tek tek açmak gerekiyordu — ve tam bu yüzden iki kez adım düştü:
#   • create_request 026'da yeniden yazılırken slot artışı kayboldu
#   • respond_request 007'de kaldı, düzeltme turuna hiç girmedi
#
# BU BETİK NE ÜRETİR:
#   ETKIN_TANIMLAR.sql — her fonksiyonun YALNIZCA canlı (son) sürümü, hangi
#   dosyadan geldiği not düşülmüş hâlde, tek dosyada.
#
# NASIL KULLANILIR:
#   • Bir fonksiyonu değiştirmeden ÖNCE buradan oku (dosya avına gerek yok).
#   • Yeni SQL yazarken "acaba eski sürümde başka ne vardı?" sorusunu
#     drift_check.py cevaplar; "canlıda şu an ne var?" sorusunu bu dosya.
#   • ÇALIŞTIRILABİLİR BİR MİGRATION DEĞİLDİR — okuma referansıdır.
#     (Sıfırdan kurulum için numaralı dosyalar sırayla çalıştırılır.)
# ----------------------------------------------------------------------------
import re, os, glob, sys
from datetime import date

# 🔴 v2.47 — BU DOSYA DA ll_paths GÖÇÜNDEN ATLANMIŞTI (wrapper_check
# ve 3 E2E ile aynı aile, bir üye daha). '/mnt/user-data/outputs'a
# bakıyor, 0 dosya buluyor ve yine de "✓ üretildi · 0 fonksiyon"
# diyordu. Bir şey üretemeyen bir üretici asla ✓ dememelidir —
# ll_paths.require_sql boş klasörde GÜRÜLTÜYLE ölür.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ll_paths

SQL_DIR, _SQL_FILES = ll_paths.require_sql('snapshot_gen')
OUT     = os.path.join(SQL_DIR, 'ETKIN_TANIMLAR.sql')

def sql_files():
# 🔴 v2.0 — DESEN DUZELTMESI: eskiden '0*.sql' idi ve migration 100'den
# itibaren HICBIR DOSYAYI GORMUYORDU. Uc haneli numaralara gecince
# denetimler sessizce eksik calisiyordu — contract_check bunu
# "fonksiyon SQL'de yok" diye bildirdi ve tuzak boyle yakalandi.
    fs = glob.glob(os.path.join(SQL_DIR, '[0-9]*.sql'))
    def key(p):
        m = re.match(r'(\d+)([a-z]?)', os.path.basename(p))
        return (int(m.group(1)), m.group(2) or '')
    return sorted(fs, key=key)

effective = {}   # fonksiyon -> (dosya, gövde)
order = []
for f in sql_files():
    src = open(f, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'create or replace function\s+(?:public\.)?(\w+)\s*\(',
                         src, re.I):
        name = m.group(1)
        endm = re.search(r'\nend\s*\$\$\s*;|\n\$\$;', src[m.start():], re.I)
        stop = m.start() + endm.end() if endm else len(src)
        nxt = src.find('create or replace function', m.end())
        if nxt != -1:
            stop = min(stop, nxt)
        if name not in effective:
            order.append(name)
        effective[name] = (os.path.basename(f), src[m.start(): stop].rstrip())

multi = {}
for f in sql_files():
    src = open(f, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'create or replace function\s+(?:public\.)?(\w+)\s*\(', src, re.I):
        multi.setdefault(m.group(1), set()).add(os.path.basename(f))

lines = []
lines.append("-- ============================================================")
lines.append("-- LoungeLink · ETKIN TANIMLAR (otomatik uretildi)")
lines.append(f"-- Uretim tarihi: {date.today().isoformat()}")
lines.append("--")
lines.append("-- Her fonksiyonun CANLIDAKI (son tanimlanan) hali. Bir fonksiyonu")
lines.append("-- degistirmeden once BURADAN oku - dosya avina gerek yok.")
lines.append("--")
lines.append("-- 🔴 BU DOSYAYI CALISTIRMA. Okuma referansidir; sifirdan kurulum")
lines.append("--    icin numarali dosyalar SIRAYLA calistirilir.")
lines.append("-- ============================================================")
lines.append("")
multi_list = sorted([n for n, fs in multi.items() if len(fs) > 1])
lines.append(f"-- Toplam fonksiyon: {len(effective)}")
lines.append(f"-- Birden cok dosyada tanimli (dikkat!): {len(multi_list)}")
for n in multi_list:
    lines.append(f"--   {n:28} -> etkin: {effective[n][0]}  (ayrica: "
                 f"{', '.join(sorted(multi[n] - {effective[n][0]}))})")
lines.append("")

for name in order:
    f, body = effective[name]
    lines.append("-- " + "-" * 70)
    lines.append(f"-- {name}   [etkin kaynak: {f}]")
    if len(multi.get(name, set())) > 1:
        lines.append(f"-- ⚠ Bu fonksiyon {len(multi[name])} dosyada tanimli. "
                     f"Degistirirken drift_check.py calistir.")
    lines.append("-- " + "-" * 70)
    lines.append(body)
    lines.append("")

open(OUT, 'w', encoding='utf-8').write("\n".join(lines))
print(f"✓ {OUT} uretildi")
print(f"  {len(effective)} fonksiyon · {len(multi_list)} tanesi birden cok dosyada tanimli")
