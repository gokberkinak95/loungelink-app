# -*- coding: utf-8 -*-
"""
render_check/pg8000_psycopg2.py — psycopg2'nin KÜÇÜK bir yüzeyini saf Python
pg8000 üstünde verir. YALNIZ psycopg2 yüklenemediğinde devreye girer.

🔴 NEDEN (29 Eylül, ölçüldü): bu Windows makinesinde psycopg2'nin C uzantısını
"Uygulama Denetimi ilkesi" engelliyor ("DLL load failed ... Uygulama Denetimi
ilkesi bu dosyayı engelledi"). tam_akis_e2e ve web_sahne/pg_kopru.py yalnız
connect / cursor / execute / fetch* / AsIs / extras.Json / RealDictCursor /
Error kullanıyor — bu katman tam olarak onu taklit eder. Linux'ta gerçek
psycopg2 yüklenir ve bu dosya hiç çalışmaz.

  import pg8000_psycopg2; pg8000_psycopg2.kur()   # gerekirse sys.modules'a yerleşir
"""
import os, sys, types, datetime, decimal, json as _json, urllib.parse as _up


def kur():
    try:
        import psycopg2  # noqa: F401
        import psycopg2.extras  # noqa: F401
        return False
    except ImportError:
        pass
    for k in [k for k in sys.modules if k == "psycopg2" or k.startswith("psycopg2.")]:
        del sys.modules[k]
    import pg8000.dbapi as _pg

    class AsIs:
        def __init__(self, v): self.v = v

    class Json:
        def __init__(self, v): self.v = v

    def _lit(v):
        if v is None: return "NULL"
        if isinstance(v, AsIs): return str(v.v)
        if isinstance(v, Json): return "'" + _json.dumps(v.v, default=str).replace("'", "''") + "'"
        if isinstance(v, bool): return "true" if v else "false"
        if isinstance(v, (int, float, decimal.Decimal)): return str(v)
        if isinstance(v, (datetime.date, datetime.datetime, datetime.time)): return "'" + v.isoformat() + "'"
        if isinstance(v, tuple): return "(" + ",".join(_lit(x) for x in v) + ")"   # psycopg2: IN %s
        if isinstance(v, list): return "ARRAY[" + ",".join(_lit(x) for x in v) + "]"
        if isinstance(v, dict): return "'" + _json.dumps(v, default=str).replace("'", "''") + "'::jsonb"
        return "'" + str(v).replace("'", "''") + "'"

    class Error(Exception):
        def __init__(self, msg, kod=None, mesaj="", ayrinti=None, ipucu=None):
            super().__init__(msg); self.pgerror = msg; self.pgcode = kod
            self.diag = types.SimpleNamespace(message_primary=mesaj, sqlstate=kod,
                                              message_detail=ayrinti, message_hint=ipucu)

    def _u(v): return str(v) if type(v).__name__ == "UUID" else v

    class _Cur:
        def __init__(self, c, sozluk=False):
            self._c = c; self._sozluk = sozluk; self.description = None; self._rows = []; self.rowcount = -1
        def __enter__(self): return self
        def __exit__(self, *a): self.close()
        def close(self): pass
        def execute(self, sql, args=None):
            if isinstance(args, dict): sql = sql % {k: _lit(v) for k, v in args.items()}
            elif args is not None: sql = sql % tuple(_lit(v) for v in args)   # psycopg2: boş liste de %% çözer
            try:
                self._c.execute(sql)
            except Exception as e:
                a = e.args[0] if e.args else {}
                m = a.get("M", str(e)) if isinstance(a, dict) else str(e)
                kod = a.get("C") if isinstance(a, dict) else None
                raise Error("ERROR:  " + m + "\n", kod, m,
                            a.get("D") if isinstance(a, dict) else None,
                            a.get("H") if isinstance(a, dict) else None) from None
            self.description = self._c.description
            self.rowcount = self._c.rowcount
            self._rows = list(self._c.fetchall()) if self._c.description else []
        def _t(self, x):
            x = tuple(_u(v) for v in x)
            if self._sozluk:
                return {d[0]: v for d, v in zip(self.description, x)}
            return x
        def fetchall(self): r = self._rows; self._rows = []; return [self._t(x) for x in r]
        def fetchone(self): return self._t(self._rows.pop(0)) if self._rows else None

    class _Cx:
        def __init__(self, dsn=None, **kw):
            if dsn:
                u = _up.urlparse(dsn); qs = dict(_up.parse_qsl(u.query))
                kw = dict(user=u.username or "postgres", dbname=(u.path or "/postgres").lstrip("/") or "postgres",
                          password=u.password, host=u.hostname or qs.get("host") or "127.0.0.1",
                          port=u.port or qs.get("port") or 5432)
            ar = dict(user=kw.get("user", "postgres"), database=kw.get("dbname") or kw.get("database") or "postgres",
                      host=kw.get("host") or "127.0.0.1",
                      port=int(kw.get("port") or os.environ.get("PGPORT") or 5432))   # libpq gibi PGPORT
            if kw.get("password"): ar["password"] = kw["password"]
            object.__setattr__(self, "_c", _pg.connect(**ar))
            object.__setattr__(self, "autocommit", False)
        def __setattr__(self, k, v):
            object.__setattr__(self, k, v)
            if k == "autocommit": self._c.autocommit = v
        def __enter__(self): return self
        def __exit__(self, t, *a):
            (self._c.rollback if t else self._c.commit)()
        def cursor(self, cursor_factory=None):
            return _Cur(self._c.cursor(), sozluk=cursor_factory is RealDictCursor)
        def commit(self): self._c.commit()
        def rollback(self): self._c.rollback()
        def close(self): self._c.close()

    class RealDictCursor:  # yalnız işaret
        pass

    m = types.ModuleType("psycopg2"); ext = types.ModuleType("psycopg2.extensions"); ex = types.ModuleType("psycopg2.extras")
    ext.AsIs = AsIs; ex.Json = Json; ex.RealDictCursor = RealDictCursor
    m.extensions = ext; m.extras = ex; m.Error = Error; m.DatabaseError = Error
    m.connect = lambda dsn=None, **k: _Cx(dsn, **k)
    sys.modules["psycopg2"] = m; sys.modules["psycopg2.extensions"] = ext; sys.modules["psycopg2.extras"] = ex
    return True
