# -*- coding: utf-8 -*-
"""
perf_olcum.py — SICAK YOL GECİKME ÖLÇÜMÜ (ölçekli dünya ll_yuk) · 4 Ekim 2026

Her fonksiyon, rastgele seçilen gerçek ölçek kullanıcıları ADINA (RLS + auth.uid)
N kez çağrılır; p50 / p95 / maks (ms) raporlanır. Eşiği aşanların sorgu planı
(EXPLAIN ANALYZE, ilk çağrı) out/perf_plan_<fn>.txt'e yazılır.

Not: yerel Windows dizüstünde tek Postgres; Supabase'de ağ turu (~40–120 ms) eklenir,
CPU farklıdır. Göreli sıralama ve "hangi sorgu ölçekle büyüyor" sorusu için geçerli.
"""
import os, sys, time, json, random, statistics
try:
    import psycopg2
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2

DB = os.environ.get("PGDATABASE", "ll_yuk")
DSN = dict(host="127.0.0.1", dbname=DB, user="postgres", password="ll", port=int(os.environ.get("PGPORT", "5432")))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out_perf"); os.makedirs(OUT, exist_ok=True)
N = int(os.environ.get("PERF_N", "25"))
ESIK_MS = 150

MISAFIR = [
    ("ana_sayfa_akisi", "select ana_sayfa_akisi()"),
    ("discover_availabilities(tümü)", "select count(*) from discover_availabilities()"),
    ("discover_availabilities(SAW)", "select count(*) from discover_availabilities('SAW')"),
    ("kesfet_ozeti", "select count(*) from kesfet_ozeti(14)"),
    ("home_connections", "select count(*) from home_connections()"),
    ("my_sent_requests", "select count(*) from my_sent_requests()"),
    ("pending_actions", "select count(*) from pending_actions()"),
    ("discover_people(SAW)", "select count(*) from discover_people('SAW')"),
    ("kisi_ara('Yük')", "select count(*) from kisi_ara('Yük')"),
    ("sorularim", "select count(*) from sorularim()"),
    ("taleplerim", "select count(*) from taleplerim()"),
    ("pending_ratings", "select count(*) from pending_ratings()"),
    ("my_connections", "select count(*) from my_connections()"),
    ("baglanti_istekleri", "select count(*) from baglanti_istekleri()"),
    ("bildirim listesi (son 50)", "select count(*) from (select * from notifications where user_id = (current_setting('request.jwt.claims')::json->>'sub')::uuid order by created_at desc limit 50) x"),
    ("okunmamış bildirim sayısı", "select count(*) from notifications where user_id = (current_setting('request.jwt.claims')::json->>'sub')::uuid and not read"),
    ("havalimani_nabzi", "select count(*) from havalimani_nabzi(14)"),
    ("lounge_radar_count", "select lounge_radar_count()"),
    ("plan_kredisi_yerlestir", "select plan_kredisi_yerlestir()"),
    ("expire_stale_sessions", "select expire_stale_sessions()"),
]
HOST = [
    ("host_requests", "select count(*) from host_requests()"),
    ("my_availabilities", "select count(*) from my_availabilities()"),
    ("host_wallet", "select host_wallet()"),
    ("host_standing", "select host_standing()"),
    ("host_missed_value", "select host_missed_value(30)"),
    ("ana_sayfa_akisi (host)", "select ana_sayfa_akisi()"),
]

def kullanicilar(rol):
    c = psycopg2.connect(**DSN); cur = c.cursor()
    cur.execute("select id from users where email like 'yuk.%%' and role=%s order by random() limit 200", (rol,))
    r = [x[0] for x in cur.fetchall()]; c.close(); return r

def olc(c, uid, sql, plan_yolu=None):
    cur = c.cursor()
    cur.execute("begin")
    cur.execute("set local role authenticated")
    cur.execute("select set_config('request.jwt.claims', %s, true)", (json.dumps({"sub": str(uid), "role": "authenticated"}),))
    t = time.perf_counter()
    hata = None
    try:
        cur.execute(sql); cur.fetchall()
    except Exception as e:
        hata = str(e).splitlines()[0][:120]
    ms = (time.perf_counter() - t) * 1000
    if plan_yolu and not hata:
        try:
            cur.execute("explain (analyze, buffers, format text) " + sql)
            open(plan_yolu, "w", encoding="utf-8").write("\n".join(r[0] for r in cur.fetchall()))
        except Exception:
            pass
    c.rollback()
    return ms, hata

def kos(liste, rol):
    uids = kullanicilar(rol)
    c = psycopg2.connect(**DSN)
    sonuc = []
    for ad, sql in liste:
        sureler, hatalar = [], []
        for i in range(N):
            ms, h = olc(c, random.choice(uids), sql)
            (hatalar.append(h) if h else sureler.append(ms))
        p50 = statistics.median(sureler) if sureler else None
        p95 = sorted(sureler)[int(len(sureler) * 0.95) - 1] if len(sureler) >= 2 else (sureler[0] if sureler else None)
        mx = max(sureler) if sureler else None
        if p95 and p95 > ESIK_MS:
            olc(c, uids[0], sql, os.path.join(OUT, "perf_plan_%s.txt" % ad.split("(")[0].replace(" ", "_")))
        sonuc.append(dict(fn=ad, rol=rol, p50=p50, p95=p95, maks=mx, hata=hatalar[:1]))
        print("  %-34s %-7s p50=%7s p95=%7s maks=%7s %s" % (ad, rol, "%.1f" % p50 if p50 else "-", "%.1f" % p95 if p95 else "-",
              "%.1f" % mx if mx else "-", ("HATA: " + hatalar[0]) if hatalar else ("⚠ eşik üstü" if p95 and p95 > ESIK_MS else "")))
    c.close()
    return sonuc

if __name__ == "__main__":
    print("Veritabanı: %s · çağrı/fonksiyon: %d · eşik p95 %d ms" % (DB, N, ESIK_MS))
    s = kos(MISAFIR, "guest") + kos(HOST, "host")
    json.dump(s, open(os.path.join(OUT, "perf_%s.json" % DB), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
