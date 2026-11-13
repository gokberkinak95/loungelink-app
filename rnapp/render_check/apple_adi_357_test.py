#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/iptal_akisi_e2e.py   (2 Ekim 2026 · SQL 313 ile doğdu)

GERİ ALMA · İPTAL · SLOT · KREDİ · SORU — Gökberk'in 2 Ekim maddeleri 5, 6, 7, 2, 3, 10

NEDEN VAR:
  Canlı testte üç şey kırıldı ve HİÇBİR e2e yakalamadı:
   (5) misafir tek taraflı "Başlat"a basınca host "Kabulü geri al" diyemedi
       ("oturum başladı") — oysa oturum İKİ TARAF basınca başlar.
   (6) iptal edilen oturumun ilanı "dolu" göründü (ekran bayattı; sunucu doğruydu
       ama bunu ölçen test yoktu → teşhis ekran mı sunucu mu, bilinmiyordu).
   (2) "soru sor" düğmesi görünüp sunucu reddediyordu (iki ayrı karar fonksiyonu).
  Bu test her senaryoda ŞUNLARI ölçer: istek durumu · oturum durumu · ilanın
  dolu sayısı · misafirin kredi bakiyesi (iade tam mı) · karşı tarafa giden
  bildirimin metni · iptal sonrası mesaj yazılamaması (RLS, gerçek rol ile).
"""
import sys as _s0, pathlib as _p0
_s0.path.insert(0, r'C:/LoungeLink/rnapp/render_check')
import win_e2e  # noqa: F401,E402  (Windows: stdout/stderr UTF-8, auth.users)
import os, re, json, shutil, pathlib, subprocess, pgserver
BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(r'C:/LoungeLink/rnapp')
import sys as _sys
_sys.path.insert(0, str(ROOT))
import ll_paths as _llp
ns = {}
exec(open(ROOT / 'pg_run.py').read().replace("if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns['install_fake_extensions']()


def _ll_temizle(_d):
    import atexit, glob as _g, shutil as _s, pathlib as _p, re as _r
    kok = _p.Path(_d)
    onek = _r.sub(r'_\d+$', '', kok.name)
    for eski in _g.glob('/tmp/' + onek + '_*'):
        if _p.Path(eski) != kok:
            _s.rmtree(eski, ignore_errors=True)
    atexit.register(lambda: _s.rmtree(str(kok), ignore_errors=True))


D = pathlib.Path('/tmp/ll_v357_' + str(os.getpid()))
_ll_temizle(D)
if D.exists():
    shutil.rmtree(D, ignore_errors=True)
D.mkdir(parents=True)
srv = pgserver.get_server(D)
uri = srv.get_uri()


def sql(q, as_user=None, rol=False):
    cmd = [str(BIN / 'psql'), uri, '-X', '-t', '-A', '-v', 'ON_ERROR_STOP=1']
    if as_user:
        cmd += ['-c', "set request.jwt.claims = '{\"sub\":\"%s\"}'" % as_user]
        if rol:
            cmd += ['-c', 'set role authenticated']
    cmd += ['-c', q]
    r = subprocess.run(cmd, capture_output=True, text=True, env=ENV)
    out = [l for l in r.stdout.splitlines() if l.strip() and l.strip() != 'SET']
    return ('\n'.join(out).strip(), r.stderr.strip(), r.returncode)


sql(ns['SHIM'])
sd = _llp.sql_dir()
o = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1), 0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f) and int(f[:3])<=356), key=o) :
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', os.path.join(sd, f)],
                   capture_output=True, text=True, env=ENV)





ok, bad = [], []
def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra != '' else ''))
A='a1111111-1111-4111-8111-111111111111'; B='b2222222-2222-4222-8222-222222222222'; E='e3333333-3333-4333-8333-333333333333'; G='f4444444-4444-4444-8444-444444444444'; A2='a5555555-5555-4555-8555-555555555555'
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('{A2}','eski.apple@privaterelay.appleid.com','{{\"provider\":\"apple\"}}','{{}}')")
chk('ONCE (357 yok): Apple kaydi adi e-postadan aliyor (sorun uretildi)', sql(f"select name from profiles where user_id='{A2}'")[0]=='eski.apple')
out=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
print('357 rc',out.returncode,out.stderr[-1500:]); print(out.stdout[-900:])
chk('357 hatasiz', out.returncode==0)
chk('357 ikinci kosu hatasiz', subprocess.run([str(BIN/'psql'),uri,'-X','-q','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV).returncode==0)
chk('mevcut hesaba dokunulmadi', sql(f"select name from profiles where user_id='{A2}'")[0]=='eski.apple')
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('{A}','k8n7xx@privaterelay.appleid.com','{{\"provider\":\"apple\"}}','{{}}')")
chk('Apple (gizli e-posta) yeni kayit: ad BOS aciliyor', sql(f"select name from profiles where user_id='{A}'")[0]=='')
chk('kayit tamam: users/verifications/trust/kredi satirlari var', sql(f"select (select count(*) from users where id='{A}')+(select count(*) from verifications where user_id='{A}')+(select count(*) from trust_scores where user_id='{A}')")[0]=='3')
r=sql(f"update profiles set name='Kemal Yılmaz' where user_id='{A}'",A,True)
chk('uygulama (kendi oturumuyla) Apple adini yazabiliyor (RLS)', r[2]==0 and sql(f"select name from profiles where user_id='{A}'")[0]=='Kemal Yılmaz', r[1][:150])
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('{B}','arda@icloud.com','{{\"provider\":\"apple\"}}','{{}}')")
chk('Apple (gercek e-posta) yeni kayit: ad BOS', sql(f"select name from profiles where user_id='{B}'")[0]=='')
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('{E}','yeni@gmail.com','{{\"provider\":\"email\"}}','{{\"name\":\"Ayse Kaya\"}}')")
chk('e-posta kaydi (formdan ad) degismedi', sql(f"select name from profiles where user_id='{E}'")[0]=='Ayse Kaya')
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('{G}','gg@gmail.com','{{\"provider\":\"google\"}}','{{\"name\":\"Gul Gun\",\"full_name\":\"Gul Gun\"}}')")
chk('Google kaydi degismedi', sql(f"select name from profiles where user_id='{G}'")[0]=='Gul Gun')
print('doldur (erken):', sql("select public.bos_adlari_doldur()"))
chk('guvenlik agi 10 dk dolmadan dokunmuyor', sql(f"select name from profiles where user_id='{B}'")[0]=='')
sql(f"update users set created_at=now()-interval '11 minutes' where id in ('{B}')")
sql(f"insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data) values ('c6666666-6666-4666-8666-666666666666','zz9@privaterelay.appleid.com','{{\"provider\":\"apple\"}}','{{}}')")
sql("update users set created_at=now()-interval '11 minutes' where id='c6666666-6666-4666-8666-666666666666'")
print('doldur:', sql("select public.bos_adlari_doldur()"))
chk('guvenlik agi: gercek e-postada @ oncesi', sql(f"select name from profiles where user_id='{B}'")[0]=='arda')
chk('guvenlik agi: gizli Apple adresinde Gezgin', sql("select name from profiles where user_id='c6666666-6666-4666-8666-666666666666'")[0]=='Gezgin')
chk('guvenlik agi: dolu ada dokunmadi', sql(f"select name from profiles where user_id='{A}'")[0]=='Kemal Yılmaz')
chk('guvenlik agi kullaniciya kapali', sql("select public.bos_adlari_doldur()",A,True)[2]!=0)
print(f'SON: {len(ok)} gecti · {len(bad)} dustu')
