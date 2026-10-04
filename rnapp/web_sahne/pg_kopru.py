#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/pg_kopru.py — YEREL POSTGRES'İ TARAYICIDAKİ UYGULAMAYA BAĞLAYAN KÖPRÜ.

🔴 NEDEN VAR: web sahnesi (react-native-web) gerçek ekranları çiziyor ama
ekranlar Supabase'e soruyor. Fikstürü elle yazmak 150+ RPC için hem
imkânsız hem yalan (uydurduğum veri, gerçek fonksiyonun döndürdüğü veri
değil). Bu köprü, uygulamanın `rpc()` ve `from()` çağrılarını YEREL
Postgres'te (`ll` · 319 migration + vitrin fikstürü) GERÇEK fonksiyon
gövdeleriyle ve GERÇEK RLS'le (rol `authenticated`, `request.jwt.claims`)
koşturur. Ekranda görünen her sayı veritabanından gelir.

PostgREST'in KULLANILAN alt kümesi: select (gömülü ilişki `rel(...)`,
`rel!inner(...)`, iç içe), eq/neq/gt/gte/lt/lte/in/is/not/ilike/like/or,
order, limit, range, count=exact, head, single/maybeSingle, insert/
update/upsert/delete (basit). Uygulamada olmayan şey burada da yok.

Kullanım:  python3 web_sahne/pg_kopru.py [port]   (varsayılan 8765)
"""
import http.server, json, re, sys, socketserver, traceback, os
try:
    import psycopg2, psycopg2.extras
except ImportError:
    # Windows "Uygulama Denetimi" psycopg2 DLL'ini engelliyorsa (29 Eylül, ölçüldü):
    # saf Python pg8000 üstünde aynı yüzey.
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "render_check"))
    import pg8000_psycopg2; pg8000_psycopg2.kur()
    import psycopg2, psycopg2.extras

DSN = dict(host="127.0.0.1", dbname="ll", user="postgres", password="ll")
_FK = None   # (table, col) -> (ftable, fcol) ve ters yön

def fk_yukle(cur):
    global _FK
    cur.execute("""
      select tc.table_name, kcu.column_name, ccu.table_name, ccu.column_name
      from information_schema.table_constraints tc
      join information_schema.key_column_usage kcu on tc.constraint_name=kcu.constraint_name and tc.table_schema=kcu.table_schema
      join information_schema.constraint_column_usage ccu on tc.constraint_name=ccu.constraint_name and tc.table_schema=ccu.table_schema
      where tc.constraint_type='FOREIGN KEY' and tc.table_schema='public'""")
    _FK = cur.fetchall()

def iliski(base, rel):
    """base → rel: ('one', base_col, rel_col) | rel → base: ('many', rel_col, base_col)"""
    for t, c, ft, fc in _FK:
        if t == base and ft == rel:
            return ("one", c, fc)
    for t, c, ft, fc in _FK:
        if t == rel and ft == base:
            return ("many", c, fc)
    raise ValueError("iliski yok: %s → %s" % (base, rel))

def parcala(s):
    """Üst düzey virgülle böl (parantezleri sayarak)."""
    out, d, cur = [], 0, ""
    for ch in s:
        if ch == "(": d += 1
        if ch == ")": d -= 1
        if ch == "," and d == 0:
            out.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def q(ident):
    return '"' + ident.replace('"', '') + '"'

class Sorgu:
    """Adlı parametreler: aynı koşul metni iki yerde (gömülü sütun + !inner
    exists) kullanılınca sıra bozulmasın."""
    def __init__(self):
        self.params = {}
    def p(self, v):
        k = "p%d" % len(self.params)
        self.params[k] = v
        return "%%(%s)s" % k

def kosul(sq, alias, f):
    op, col, val = f["op"], f["col"], f.get("val")
    c = "%s.%s" % (alias, q(col))
    if op == "eq":  return "%s = %s" % (c, sq.p(val))
    if op == "neq": return "%s <> %s" % (c, sq.p(val))
    if op == "gt":  return "%s > %s" % (c, sq.p(val))
    if op == "gte": return "%s >= %s" % (c, sq.p(val))
    if op == "lt":  return "%s < %s" % (c, sq.p(val))
    if op == "lte": return "%s <= %s" % (c, sq.p(val))
    if op == "in":  return "%s::text = any(%s::text[])" % (c, sq.p([str(x) for x in (val or [])]))
    if op == "is":  return "%s is %s" % (c, "null" if val is None else ("true" if val else "false"))
    if op == "ilike": return "%s ilike %s" % (c, sq.p(val))
    if op == "like":  return "%s like %s" % (c, sq.p(val))
    if op == "not":
        return "not (%s)" % kosul(sq, alias, {"op": f["iop"], "col": col, "val": val})
    if op in ("or", "and"):
        parts = []
        for item in parcala(val):
            g = re.match(r"^(and|or)\((.*)\)$", item, re.S)
            if g:
                parts.append(kosul(sq, alias, {"op": g.group(1), "col": "", "val": g.group(2)}))
                continue
            m = re.match(r"^([a-z_0-9.]+)\.(eq|neq|gt|gte|lt|lte|is|ilike|like|in)\.(.*)$", item, re.S)
            if not m: raise ValueError("or parçası: " + item)
            cc, oo, vv = m.groups()
            if oo == "is": vv = None if vv == "null" else (vv == "true")
            elif oo == "in": vv = [x.strip() for x in vv.strip("()").split(",")]
            parts.append(kosul(sq, alias, {"op": oo, "col": cc, "val": vv}))
        return "(" + (" or " if op == "or" else " and ").join(parts) + ")"
    raise ValueError("op: " + op)

def secim_sql(sq, table, alias, select, filtreler, derinlik=0):
    """Sütun listesi + gömülüler. Dotted filtreler gömülüye iner."""
    cols = []
    ic_kosullar = []   # !inner için exists koşulları
    for it in parcala(select or "*"):
        m = re.match(r"^(?:([a-z_0-9]+):)?([a-z_0-9]+)(!inner)?\((.*)\)$", it, re.S)
        if m:
            alias2, rel, inner, sub = m.groups()
            kind, a, b = iliski(table, rel)
            ra = "_r%d_%s" % (derinlik, rel)
            alt_f = [dict(f, col=f["col"].split(".", 1)[1]) for f in filtreler
                     if f["col"].startswith(rel + ".")]
            alt_cols, alt_where, alt_inner = secim_sql(sq, rel, ra, sub, alt_f, derinlik + 1)
            wh = " and ".join([("%s.%s = %s.%s" % (ra, q(b), alias, q(a))) if kind == "one"
                               else ("%s.%s = %s.%s" % (ra, q(a), alias, q(b)))] + alt_where + alt_inner)
            if kind == "one":
                cols.append("(select row_to_json(_e) from (select %s from %s %s where %s) _e) as %s"
                            % (alt_cols, q(rel), ra, wh, q(alias2 or rel)))
            else:
                cols.append("(select coalesce(json_agg(_e), '[]'::json) from (select %s from %s %s where %s) _e) as %s"
                            % (alt_cols, q(rel), ra, wh, q(alias2 or rel)))
            if inner:
                ic_kosullar.append("exists(select 1 from %s %s where %s)" % (q(rel), ra + "x", wh.replace(ra + ".", ra + "x.")))
        else:
            it = it.strip()
            if it == "*": cols.append(alias + ".*")
            elif ":" in it:
                a2, c2 = it.split(":", 1); cols.append("%s.%s as %s" % (alias, q(c2.strip()), q(a2.strip())))
            else: cols.append("%s.%s" % (alias, q(it)))
    where = [kosul(sq, alias, f) for f in filtreler if "." not in f["col"] or f["op"] in ("or", "and")]
    return ", ".join(cols), where, ic_kosullar

def tablo_sorgusu(cur, d):
    sq = Sorgu()
    t = d["table"]; al = "_b"
    op = d.get("op", "select")
    if op == "select":
        cols, where, inner = secim_sql(sq, t, al, d.get("select") or "*", d.get("filters", []))
        wsql = (" where " + " and ".join(where + inner)) if (where or inner) else ""
        if d.get("head") and d.get("count"):
            cur.execute("select count(*) as n from %s %s%s" % (q(t), al, wsql), sq.params)
            return {"data": None, "count": cur.fetchone()["n"], "error": None}
        osql = ""
        if d.get("order"):
            osql = " order by " + ", ".join("%s.%s %s" % (al, q(o["col"]), "asc" if o.get("asc", True) else "desc") for o in d["order"])
        lsql = ""
        if d.get("range"):
            a, b = d["range"]; lsql = " offset %d limit %d" % (a, b - a + 1)
        elif d.get("limit") is not None:
            lsql = " limit %d" % int(d["limit"])
        sql = "select %s from %s %s%s%s%s" % (cols, q(t), al, wsql, osql, lsql)
        cur.execute(sql, sq.params)
        rows = [dict(r) for r in cur.fetchall()]
        count = None
        if d.get("count"):
            cur.execute("select count(*) as n from %s %s%s" % (q(t), al, wsql), sq.params)
            count = cur.fetchone()["n"]
        if d.get("single"):
            if len(rows) > 1 and d["single"] == "single":
                return {"data": None, "error": {"message": "multiple rows", "code": "PGRST116"}}
            if not rows and d["single"] == "single":
                return {"data": None, "error": {"message": "no rows", "code": "PGRST116"}}
            return {"data": rows[0] if rows else None, "error": None, "count": count}
        return {"data": rows, "error": None, "count": count}
    if op in ("insert", "upsert"):
        vals = d.get("values")
        rows = vals if isinstance(vals, list) else [vals]
        out = []
        for r in rows:
            ks = list(r.keys())
            sql = "insert into %s (%s) values (%s)" % (q(t), ", ".join(q(k) for k in ks), ", ".join(sq.p(deger(r[k])) for k in ks))
            if op == "upsert":
                sql += " on conflict do nothing"
            sql += " returning *"
            cur.execute(sql, sq.params); sq.params = {}
            out += [dict(x) for x in cur.fetchall()]
        return {"data": out, "error": None}
    if op == "update":
        r = d.get("values") or {}
        sets = ", ".join("%s = %s" % (q(k), sq.p(deger(v))) for k, v in r.items())
        where = [kosul(sq, al, f) for f in d.get("filters", [])]
        cur.execute("update %s %s set %s%s returning *" % (q(t), al, sets, (" where " + " and ".join(where)) if where else ""), sq.params)
        return {"data": [dict(x) for x in cur.fetchall()], "error": None}
    if op == "delete":
        where = [kosul(sq, al, f) for f in d.get("filters", [])]
        cur.execute("delete from %s %s%s returning *" % (q(t), al, (" where " + " and ".join(where)) if where else ""), sq.params)
        return {"data": [dict(x) for x in cur.fetchall()], "error": None}
    raise ValueError("op: " + op)

def deger(v):
    if isinstance(v, (dict, list)):
        return psycopg2.extras.Json(v)
    return v

def rpc_sorgusu(cur, fn, args):
    cur.execute("""select p.proretset, pg_get_function_result(p.oid), p.proargnames,
                          (select array_agg(t.typname order by a.ord)
                           from unnest(p.proargtypes) with ordinality a(oid, ord)
                           join pg_type t on t.oid=a.oid)
                   from pg_proc p where p.pronamespace='public'::regnamespace and p.proname=%s
                   order by pronargs desc limit 1""", (fn,))
    row = cur.fetchone()
    if not row:
        return {"data": None, "error": {"message": "function %s does not exist" % fn, "code": "42883"}}
    retset, rettype, argnames, argtypes = row
    args = args or {}
    parts, params = [], []
    tipler = dict(zip(argnames or [], argtypes or []))
    for k, v in args.items():
        tip = tipler.get(k, "")
        if isinstance(v, (dict, list)) and tip in ("jsonb", "json"):
            v = psycopg2.extras.Json(v)
        parts.append("%s := %%s%s" % (q(k), ("::" + tip) if tip and tip not in ("jsonb", "json") and v is not None else ""))
        params.append(v)
    call = "%s(%s)" % (q(fn), ", ".join(parts))
    if retset:
        if rettype.startswith("TABLE") or rettype.startswith("SETOF record") or (rettype.startswith("SETOF ") and not re.match(r"^SETOF (text|integer|bigint|uuid|boolean|numeric|jsonb|json)$", rettype)):
            cur.execute("select coalesce(json_agg(row_to_json(_t)), '[]'::json) from %s _t" % call, params)
        else:
            cur.execute("select coalesce(json_agg(_t), '[]'::json) from %s _t" % call, params)
    else:
        cur.execute("select to_json(%s)" % call, params)
    return {"data": cur.fetchone()[0], "error": None}

def kimlik(istek):
    """
    4 Ekim 2026 — KİMLİK İŞLEMLERİ GERÇEK VERİTABANINDA (akis_e2e.py).
    Taklit `signUp` hiçbir şey yazmıyordu; kayıt akışı uçtan uca sınanamıyordu.
    Artık `auth.users`a yazılıyor ve `handle_new_user` tetikleyicisi GERÇEKTEN
    çalışıyor (rol, profil, güven puanı, açılış kredisi). Hata metinleri
    Supabase GoTrue'nun birebir metinleri — uygulamanın `mapErr`i de sınanır.
    `onay_kapali=False` → e-posta doğrulaması AÇIK davranışı (oturum dönmez).
    """
    op, e = istek.get("op"), str(istek.get("email") or "").strip().lower()
    conn = psycopg2.connect(**DSN)
    try:
        cur = conn.cursor()
        if op == "signup":
            if not re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", e):
                return {"data": None, "error": {"message": "Unable to validate email address: invalid format", "code": "validation_failed"}}
            if len(str(istek.get("password") or "")) < 6:
                return {"data": None, "error": {"message": "Password should be at least 6 characters.", "code": "weak_password"}}
            cur.execute("select 1 from auth.users where lower(email)=%s", (e,))
            if cur.fetchone():
                return {"data": None, "error": {"message": "User already registered", "code": "user_already_exists"}}
            onayli = bool(istek.get("onay_kapali", True))
            cur.execute("""insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
                             created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
                           values (gen_random_uuid(), 'authenticated', 'authenticated', %s, extensions.crypt(%s, extensions.gen_salt('bf')),
                                   case when %s then now() end, now(), now(), '{"provider":"email"}'::jsonb, %s::jsonb)
                           returning id""", (e, istek.get("password"), onayli, json.dumps(istek.get("data") or {})))
            uid = str(cur.fetchone()[0]); conn.commit()
            user = {"id": uid, "email": e, "app_metadata": {"provider": "email"}}
            return {"data": {"user": user, "session": {"user": user, "access_token": "sahne"} if onayli else None}, "error": None}
        if op == "signin":
            cur.execute("""select id, email_confirmed_at is not null, encrypted_password = extensions.crypt(%s, encrypted_password),
                                  coalesce(raw_app_meta_data, '{}'::jsonb), coalesce(banned_until > now(), false)
                             from auth.users where lower(email)=%s""", (str(istek.get("password") or ""), e))
            r = cur.fetchone()
            if not r or not r[2]:
                return {"data": None, "error": {"message": "Invalid login credentials", "code": "invalid_credentials"}}
            if r[4]:   # GoTrue gibi: banned_until gelecekteyse giriş reddedilir (SQL 329 · silme süreci)
                return {"data": None, "error": {"message": "User is banned", "code": "user_banned"}}
            if not r[1]:
                return {"data": None, "error": {"message": "Email not confirmed", "code": "email_not_confirmed"}}
            user = {"id": str(r[0]), "email": e, "app_metadata": r[3] if isinstance(r[3], dict) else json.loads(r[3])}
            return {"data": {"user": user, "session": {"user": user, "access_token": "sahne"}}, "error": None}
        if op == "reset":
            if not re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", e):
                return {"data": None, "error": {"message": "Unable to validate email address: invalid format", "code": "validation_failed"}}
            cur.execute("update auth.users set recovery_token = md5(random()::text) where lower(email)=%s", (e,))
            conn.commit()
            return {"data": {}, "error": None}   # GoTrue gibi: e-posta yoksa da başarı (kullanıcı taraması yok)
        return {"data": None, "error": {"message": "bilinmeyen kimlik islemi", "code": "KOPRU"}}
    finally:
        conn.close()

def calistir(istek):
    if istek.get("kind") == "auth":
        return kimlik(istek)
    uid = istek.get("uid")
    conn = psycopg2.connect(**DSN)
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor if istek.get("kind") == "from" else None)
        if _FK is None:
            c2 = conn.cursor(); fk_yukle(c2); c2.close()
        claims = json.dumps({"sub": uid, "role": "authenticated"}) if uid else ""
        cur.execute("set role %s" % ("authenticated" if uid else "anon"))
        cur.execute("select set_config('request.jwt.claims', %s, true)", (claims,))
        try:
            if istek["kind"] == "rpc":
                out = rpc_sorgusu(cur, istek["fn"], istek.get("args"))
            else:
                out = tablo_sorgusu(cur, istek)
            conn.commit()
            return out
        except psycopg2.Error as e:
            conn.rollback()
            return {"data": None, "error": {"message": (e.diag.message_primary or str(e)).strip(), "code": e.pgcode or "XX000",
                                            "details": e.diag.message_detail, "hint": e.diag.message_hint}}
    finally:
        conn.close()

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "content-type")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
    def do_OPTIONS(self):
        self.send_response(204); self._cors(); self.end_headers()
    def do_POST(self):
        n = int(self.headers.get("content-length") or 0)
        try:
            istek = json.loads(self.rfile.read(n) or b"{}")
            out = calistir(istek)
        except Exception as e:
            out = {"data": None, "error": {"message": "kopru: " + str(e), "code": "KOPRU"}}
            traceback.print_exc()
        body = json.dumps(out, default=str, ensure_ascii=False).encode("utf-8")
        self.send_response(200); self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)

class Sunucu(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print("pg_kopru :%d" % port, flush=True)
    Sunucu(("127.0.0.1", port), H).serve_forever()
