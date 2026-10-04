# -*- coding: utf-8 -*-
# BO yetki bulgularını sınıflar: her fonksiyon BO'da hangi istemciyle çağrılıyor (sbAdmin / sbSession)?
import os, re, glob, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import psycopg2
except ImportError:
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2
KOK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
bul = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "be_yetki_tarama.json"), encoding="utf-8"))
adlar = [b["fonksiyon"] for b in bul if b["tur"] == "BO"]
dosyalar = [f for f in glob.glob(os.path.join(KOK, "backoffice", "**", "*.js*"), recursive=True)
            if "node_modules" not in f and ".next" not in f and "_arsiv" not in f]
c = psycopg2.connect(host="127.0.0.1", dbname="ll", user="postgres", password="ll", port=int(os.environ.get("PGPORT", "5432")))
cur = c.cursor()
for ad in adlar:
    istemci = set()
    for f in dosyalar:
        g = open(f, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"(\w+)\s*(?:\(\))?\s*\.rpc\(\s*[\"'`]" + ad + r"[\"'`]", g):
            v = m.group(1)
            # değişkenin neye bağlandığını bul
            t = re.search(r"(?:const|let)\s+" + v + r"\s*=\s*(sbAdmin|sbSession)\s*\(", g)
            istemci.add((t.group(1) if t else v) + "@" + os.path.relpath(f, os.path.join(KOK, "backoffice")))
    cur.execute("select bool_or(prosecdef), string_agg(prosrc, ' ') from pg_proc where proname=%s", (ad,))
    secdef, src = cur.fetchone()
    kapi = bool(re.search(r"auth\.uid\(\)|partner|lounge_partners|admin", src or "", re.I))
    print("%-26s secdef=%-5s gövde_kontrol=%-5s çağıran=%s" % (ad, secdef, kapi, sorted(istemci)))
