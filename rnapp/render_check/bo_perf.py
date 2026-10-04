# -*- coding: utf-8 -*-
# bo_perf.py — BO'nun çağırdığı ARGÜMANSIZ fonksiyonların ölçek dünyasında süresi (service_role) · 4 Ekim 2026
import os, re, glob, sys, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import psycopg2
except ImportError:
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2
KOK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
adlar = set()
for f in glob.glob(os.path.join(KOK, "backoffice", "**", "*.js*"), recursive=True):
    if "node_modules" in f or ".next" in f or "_arsiv" in f:
        continue
    adlar.update(re.findall(r"rpc\(\s*[\"'`]([a-z_0-9]+)[\"'`]\s*\)", open(f, encoding="utf-8", errors="replace").read()))
c = psycopg2.connect(host="127.0.0.1", dbname=os.environ.get("PGDATABASE", "ll_yuk"), user="postgres", password="ll",
                     port=int(os.environ.get("PGPORT", "5432")))
c.autocommit = False; cur = c.cursor()
cur.execute("""select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                where n.nspname='public' and p.pronargs = 0 and p.proname = any(%s) and p.prorettype <> 'trigger'::regtype""", (sorted(adlar),))
fl = [r[0] for r in cur.fetchall()]
sonuc = []
for ad in sorted(fl):
    cur.execute("begin"); cur.execute("set local role service_role")
    cur.execute("set local statement_timeout = '60s'")
    t = time.perf_counter(); h = None
    try:
        cur.execute("select count(*) from (select %s()) x" % ad) if True else None
        cur.fetchall()
    except Exception as e:
        h = str(e).splitlines()[0][:80]
    ms = (time.perf_counter() - t) * 1000
    c.rollback()
    sonuc.append((ad, ms, h))
sonuc.sort(key=lambda x: -x[1])
print("BO argümansız fonksiyon: %d (BO'nun argümansız çağırdığı)" % len(sonuc))
for ad, ms, h in sonuc[:15]:
    print("  %-34s %8.0f ms %s" % (ad, ms, ("HATA " + h) if h else ("⚠" if ms > 1000 else "")))
json.dump(sonuc, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out_perf", "bo_perf.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
