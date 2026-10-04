# -*- coding: utf-8 -*-
"""
yuk_eszamanli.py — EŞZAMANLI YÜK TESTİ (ölçekli dünya ll_yuk) · 4 Ekim 2026

N sanal kullanıcı (her biri kendi bağlantısıyla, Supabase'deki PostgREST havuzu
gibi) aynı anda gerçekçi bir uygulama oturumu karışımı koşturur:
  ana sayfa açılışı (ana_sayfa_akisi + home_connections + pending_actions +
  bildirim sayısı + expire_stale_sessions) · Keşfet (IST) · kesfet_ozeti ·
  bildirim listesi · istek gönder / iptal et (YAZMA — işlem sonunda geri alınır).
Her kademe SURE saniye koşar; işlem/sn, p50/p95/p99, hata ve kilit beklemesi raporlanır.

Not: yerel dizüstü Postgres (tek makine, istemci ve sunucu aynı CPU'da). Mutlak
sayılar Supabase'den farklıdır; kademeler arası EĞİM ve kırılma noktası anlamlıdır.
"""
import os, sys, time, json, random, threading, statistics
try:
    import psycopg2
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2

DB = os.environ.get("PGDATABASE", "ll_yuk")
DSN = dict(host="127.0.0.1", dbname=DB, user="postgres", password="ll", port=int(os.environ.get("PGPORT", "5432")))
KADEMELER = [int(x) for x in os.environ.get("YUK_KADEME", "10,25,50,100").split(",")]
SURE = int(os.environ.get("YUK_SURE", "30"))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out_perf"); os.makedirs(OUT, exist_ok=True)

ANA = ["select ana_sayfa_akisi()", "select count(*) from home_connections()", "select count(*) from pending_actions()",
       "select count(*) from notifications where user_id = (current_setting('request.jwt.claims')::json->>'sub')::uuid and not read", "select expire_stale_sessions()"]
AGIRLIK = [  # (ad, ağırlık, sorgular, yazma mı)
    ("ana_sayfa", 40, ANA, False),
    ("kesfet_SAW", 20, ["select count(*) from discover_availabilities('SAW')"], False),
    ("kesfet_ozeti", 8, ["select count(*) from kesfet_ozeti(14)"], False),
    ("bildirimler", 15, ["select count(*) from (select * from notifications where user_id = (current_setting('request.jwt.claims')::json->>'sub')::uuid order by created_at desc limit 50) x"], False),
    ("istek_gonder_iptal", 10, None, True),
    ("planim", 7, ["select count(*) from my_sent_requests()", "select count(*) from taleplerim()"], False),
]

def misafirler():
    c = psycopg2.connect(**DSN); cur = c.cursor()
    cur.execute("select id from users where email like 'yuk.%%' and role='guest' order by random() limit 2000")
    u = [r[0] for r in cur.fetchall()]
    # İstek yazma akışı için GERÇEKTEN başvurulabilir çiftler: aynı havalimanı + tarih + saat örtüşen seyahat
    cur.execute("""select v.user_id, a.id from visits v
                     join availabilities a on a.airport_code = v.airport_code and a.avail_date = v.visit_date
                      and a.time_from < v.time_to and v.time_from < a.time_to
                    where v.user_id in (select id from users where email like 'yuk.%%' and role='guest')
                      and a.active and a.avail_date > current_date and a.filled < a.slots
                      and not exists (select 1 from requests r where r.guest_id = v.user_id and r.avail_id = a.id)
                    order by random() limit 3000""")
    a = cur.fetchall()
    c.close(); return u, a

def kullanici_ol(cur, uid):
    cur.execute("set local role authenticated")
    cur.execute("select set_config('request.jwt.claims', %s, true)", (json.dumps({"sub": str(uid), "role": "authenticated"}),))

def vu(dur, uids, ilanlar, sonuc, kilit):
    c = psycopg2.connect(**DSN); c.autocommit = False
    cur = c.cursor()
    adlar = [x[0] for x in AGIRLIK]; w = [x[1] for x in AGIRLIK]
    while not dur.is_set():
        ad = random.choices(adlar, w)[0]
        _, _, sorgular, yazma = next(x for x in AGIRLIK if x[0] == ad)
        uid = random.choice(uids)
        if yazma:
            uid, ilan = random.choice(ilanlar)
        t = time.perf_counter(); hata = None
        try:
            cur.execute("begin"); kullanici_ol(cur, uid)
            if yazma:
                cur.execute("select create_request(%s, 'lounge', 'yük testi')", (ilan,))
                cur.fetchall()
                cur.execute("""select id from requests where guest_id = %s and status = 'pending'
                               order by created_at desc limit 1""", (uid,))
                r = cur.fetchone()
                if r:
                    cur.execute("select respond_request(%s, 'cancel')", (r[0],)); cur.fetchall()
                c.rollback()     # dünya kirlenmesin
            else:
                for q in sorgular:
                    cur.execute(q); cur.fetchall()
                c.rollback()
        except Exception as e:
            hata = str(e).splitlines()[0][:90]
            try: c.rollback()
            except Exception: pass
        ms = (time.perf_counter() - t) * 1000
        with kilit:
            sonuc.append((ad, ms, hata))
    c.close()

def kademe(n, uids, ilanlar):
    dur = threading.Event(); sonuc = []; kilit = threading.Lock()
    th = [threading.Thread(target=vu, args=(dur, uids, ilanlar, sonuc, kilit), daemon=True) for _ in range(n)]
    for x in th: x.start()
    time.sleep(SURE); dur.set()
    for x in th: x.join(timeout=60)
    ok = [s for s in sonuc if not s[2]]
    tum = sorted(s[1] for s in ok)
    def p(l, q): return l[min(len(l) - 1, int(len(l) * q))] if l else None
    satir = dict(vu=n, islem=len(sonuc), islem_sn=round(len(sonuc) / SURE, 1),
                 p50=round(p(tum, .5) or 0, 1), p95=round(p(tum, .95) or 0, 1), p99=round(p(tum, .99) or 0, 1),
                 hata=len(sonuc) - len(ok),
                 hata_ornek=sorted({s[2] for s in sonuc if s[2]})[:4],
                 akis={})
    for ad, *_ in AGIRLIK:
        l = sorted(s[1] for s in ok if s[0] == ad)
        satir["akis"][ad] = dict(n=len(l), p50=round(p(l, .5) or 0, 1), p95=round(p(l, .95) or 0, 1))
    return satir

if __name__ == "__main__":
    uids, ilanlar = misafirler()
    c = psycopg2.connect(**DSN); cur = c.cursor(); cur.execute("show max_connections"); mx = cur.fetchone()[0]; c.close()
    print("Veritabanı %s · max_connections=%s · kademe süresi %ds · kullanıcı havuzu %d · başvurulabilir çift %d" % (DB, mx, SURE, len(uids), len(ilanlar)))
    tum = []
    for n in KADEMELER:
        s = kademe(n, uids, ilanlar); tum.append(s)
        print("  VU=%-4d işlem/sn=%-7s p50=%-7s p95=%-8s p99=%-8s hata=%d %s" % (
            n, s["islem_sn"], s["p50"], s["p95"], s["p99"], s["hata"], s["hata_ornek"]))
        for ad, v in s["akis"].items():
            print("        %-20s n=%-5d p50=%-7s p95=%s" % (ad, v["n"], v["p50"], v["p95"]))
    json.dump(tum, open(os.path.join(OUT, "yuk_eszamanli_%s.json" % DB), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
