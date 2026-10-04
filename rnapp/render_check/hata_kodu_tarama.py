# -*- coding: utf-8 -*-
"""
hata_kodu_tarama.py — SUNUCU HATA KODU ↔ ÇEVİRİ TARAMASI · 4 Ekim 2026

Kural (CLAUDE.md): "Kullanıcıya ham kod gösterilmez · yeni hata kodu → i18n errMap'e TR+EN".
Soru: uygulamanın çağırdığı fonksiyonların (ve onların çağırdığı fonksiyonların) attığı
her `raise exception '<kod>'` için i18n.js'te TR ve EN cümle var mı?
Eksik kod, kullanıcıya "Bir şeyler ters gitti" (ya da ham kod) olarak düşer.
Çıktı: eksik kod listesi; varsa çıkış 1.
"""
import os, re, sys, glob
try:
    import psycopg2
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2

KOK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DSN = dict(host="127.0.0.1", dbname=os.environ.get("PGDATABASE", "ll"), user="postgres", password="ll",
           port=int(os.environ.get("PGPORT", "5432")))

def kaynak_rpc():
    adlar = set()
    for f in glob.glob(os.path.join(KOK, "src", "**", "*.js"), recursive=True) + [os.path.join(KOK, "App.js")]:
        adlar.update(re.findall(r"rpc\(\s*[\"'`]([a-z_0-9]+)", open(f, encoding="utf-8").read()))
    return adlar

I18N = open(os.path.join(KOK, "src", "i18n.js"), encoding="utf-8").read()
# Kasıtlı olarak kullanıcıya gösterilmeyen iç kodlar (istemci yakalar ve kendi akışını yürütür)
IC = {"atlandi", "not_found", "GERI_AL_ONKONTROL_GECER"}   # son: request_precheck kuru koşu nöbetçisi

c = psycopg2.connect(**DSN); cur = c.cursor()
cur.execute("select p.proname, string_agg(p.prosrc, ' ') from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
            "where n.nspname='public' group by p.proname")
SRC = dict(cur.fetchall())

kok = kaynak_rpc() & set(SRC)
gez, sira = set(), list(kok)
while sira:                                  # çağrı ağacı (ad eşleşmesiyle, geçişli)
    f = sira.pop()
    if f in gez:
        continue
    gez.add(f)
    for g in re.findall(r"\b(?:public\.)?([a-z_][a-z0-9_]{3,})\s*\(", SRC.get(f, "")):
        if g in SRC and g not in gez:
            sira.append(g)

kodlar = {}
for f in gez:
    for k in re.findall(r"raise\s+exception\s+'([a-z][a-z0-9_]{2,})'", SRC[f], re.I):
        if "_" in k and k not in IC:
            kodlar.setdefault(k, set()).add(f)

eksik = []
for k in sorted(kodlar):
    n = len(re.findall(r'(?:\be_%s\b\s*:|"%s"\s*:)' % (re.escape(k), re.escape(k)), I18N))
    if n < 2:
        eksik.append((k, n, sorted(kodlar[k])[:3]))

print("Uygulamanın çağırdığı fonksiyon: %d · çağrı ağacında: %d · ayrı hata kodu: %d" % (len(kok), len(gez), len(kodlar)))
print("TR+EN çevirisi eksik: %d" % len(eksik))
for k, n, fl in eksik:
    print("  ✗ %-34s çeviri=%d  ← %s" % (k, n, ", ".join(fl)))
sys.exit(1 if eksik else 0)
