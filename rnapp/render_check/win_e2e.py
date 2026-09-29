# -*- coding: utf-8 -*-
"""
render_check/win_e2e.py — e2e betiklerini Windows'ta DEĞİŞTİRMEDEN koşturur.

  python render_check/win_e2e.py render_check/tam_akis_e2e.py

🔴 NEDEN VAR (29 Eylül, ölçüldü): 7 e2e'den 6'sı her koşuda kendi geçici
Postgres'ini `pgserver.get_server()` ile kuruyor. Windows'ta bu iki yerde
düşüyordu:
  1) initdb: sistem yerel ayarı "Turkish_Türkiye.1254" pgserver'ın istediği
     UTF8 ile birleşmiyor (rnapp/pg_run.py'deki sorunun aynısı);
  2) alt süreçlere `env={"PATH": "...:/usr/bin"}` veriliyor — Windows'ta
     SYSTEMROOT olmadan psql/initdb açılmıyor.
Betiklerin kendisi Linux (bulut kabı) için doğru; burada yalnız bu iki şey
Windows'a uyarlanıyor, sonra betik OLDUĞU GİBİ çalışır. Linux'ta hiçbir
şey yapmaz.
"""
import os, sys, runpy, subprocess, pathlib

if os.name == "nt":
    os.environ.setdefault("PYTHONUTF8", "1")
    import pgserver
    _bin = pathlib.Path(pgserver.__file__).parent / "pginstall" / "bin"
    _asil_get_server = pgserver.get_server

    def _get_server(dizin, *a, **k):
        d = pathlib.Path(str(dizin))
        if not (d / "PG_VERSION").exists():
            d.mkdir(parents=True, exist_ok=True)
            _asil_run([str(_bin / "initdb.exe"), "-D", str(d), "--auth=trust", "--encoding=UTF8",
                       "--locale=C", "-U", "postgres"], check=True, capture_output=True)
        return _asil_get_server(dizin, *a, **k)
    pgserver.get_server = _get_server

    _asil_run = subprocess.run
    def _psql_sirala(args):
        """Windows psql'i ilk konumsal argümandan (adres) SONRAKİ seçenekleri yok sayar
        ('extra command-line argument -t ignored'); Linux getopt sıralar. Adresi -d yap."""
        if not isinstance(args, (list, tuple)) or not args or "psql" not in os.path.basename(str(args[0])).lower():
            return args
        args = list(args)
        for i in range(1, len(args)):
            x = str(args[i])
            if (x.startswith("postgresql://") or x.startswith("postgres://")) and str(args[i - 1]) != "-d":
                return [args[0], "-d", x] + args[1:i] + args[i + 1:]
        return args

    def _psql_stdin(args, k):
        """Çok satırlı / ASCII olmayan `-c SQL` Windows komut satırında bozulur
        (pg_run.py'deki ders; Türkçe harf cp1254'e çevrilip 0xfd diye düşüyor):
        BÜTÜN -c'leri sırayla stdin'den UTF-8 ver. Birden çok -c olabilir
        (önce 'set request.jwt.claims', sonra sorgu) — hepsi birlikte taşınır."""
        if not isinstance(args, list) or "-c" not in args or "-f" in args or "input" in k                 or "psql" not in os.path.basename(str(args[0])).lower():
            return args
        cler = [str(args[i + 1]) for i in range(len(args) - 1) if args[i] == "-c"]
        if not any(chr(10) in c or len(c) > 1500 or not c.isascii() for c in cler):
            return args
        yeni, i = [], 0
        while i < len(args):
            if args[i] == "-c" and i + 1 < len(args): i += 2; continue
            yeni.append(args[i]); i += 1
        sql = "".join(c.rstrip().rstrip(";") + ";" + chr(10) for c in cler)
        k["input"] = sql
        if not (k.get("text") or k.get("universal_newlines") or k.get("encoding")):
            k["input"] = sql.encode("utf-8")
        return yeni

    def _run(*a, **k):
        if a:
            a = (_psql_stdin(_psql_sirala(a[0]), k),) + tuple(a[1:])
        elif "args" in k:
            k["args"] = _psql_stdin(_psql_sirala(k["args"]), k)
        env = k.get("env")
        if env is not None:
            tam = dict(os.environ); tam.update({x: y for x, y in env.items() if x != "PATH"})
            tam["PATH"] = str(_bin) + os.pathsep + os.environ.get("PATH", "")
            k["env"] = tam
        if k.get("text") or k.get("universal_newlines"):
            k.setdefault("encoding", "utf-8"); k.setdefault("errors", "replace")
        return _asil_run(*a, **k)
    subprocess.run = _run

    # 3) psycopg2'nin C uzantısını Windows "Uygulama Denetimi" ilkesi engelliyor:
    #    saf Python pg8000 üstünde aynı yüzey (render_check/pg8000_psycopg2.py).
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pg8000_psycopg2
    pg8000_psycopg2.kur()

if __name__ == "__main__":
    hedef = sys.argv[1]
    sys.argv = sys.argv[1:]
    sys.path.insert(0, os.path.dirname(os.path.abspath(hedef)))
    runpy.run_path(hedef, run_name="__main__")
