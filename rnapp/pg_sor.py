#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""pg_sor.py — pg_run.py --keep ile birakilan veritabanina SORGU atar.

NEDEN VAR: pgserver sunucuyu Python sureci bitince kapatiyor; --keep yalniz
VERI KLASORUNU birakiyor. Bu yuzden `psql` ile disaridan baglanmak
"No such file or directory" veriyor. Bu betik ayni veri klasorunu tekrar
ayaga kaldirip verilen SQL dosyasini/metnini calistirir.

KULLANIM:
  python pg_sor.py dosya.sql
  python pg_sor.py -c "select 1"
"""
import pathlib, subprocess, sys
import pgserver

DATA = pathlib.Path('/tmp/ll_pg')
BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'

if not DATA.exists():
    print('✗ /tmp/ll_pg yok. Once: python pg_run.py --keep'); sys.exit(1)

srv = pgserver.get_server(DATA)
uri = srv.get_uri()
cmd = [str(BIN / 'psql'), uri, '-X', '--pset=pager=off']
if sys.argv[1] == '-c':
    cmd += ['-c', sys.argv[2]]
else:
    cmd += ['-f', sys.argv[1]]
sys.exit(subprocess.run(cmd).returncode)
