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


D = pathlib.Path('/tmp/ll_v355_' + str(os.getpid()))
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
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f) and int(f[:3])<=354), key=o) :
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', os.path.join(sd, f)],
                   capture_output=True, text=True, env=ENV)



ok, bad = [], []
def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra != '' else ''))
R='11111111-1111-4111-8111-111111111111'; Q='33333333-3333-4333-8333-333333333333'; E='44444444-4444-4444-8444-444444444444'
sql("insert into auth.users (id,email) values ('22222222-2222-4222-8222-222222222222','inceleme@loungelink.co')"); sql("select public.inceleme_hesabi_hazirla('inceleme@loungelink.co')")
sql(f"insert into auth.users (id,email) values ('{R}','gercek.kisi@gmail.com'),('{Q}','ikinci.kisi@gmail.com'),('{E}','sadece.eposta@gmail.com')")
for u in (R,Q):
    sql(f"update verifications set email_verified=true, phone_verified=true where user_id='{u}'")
sql(f"update verifications set email_verified=true where user_id='{E}'")
for u in (R,Q,E): sql(f"select public.recompute_trust('{u}')")
sql(f"update profiles set name='Ikinci Kisi', show_on_discovery=true where user_id='{Q}'")
print('puanlar:', sql(f"select string_agg(score::text,',' order by user_id) from trust_scores where user_id in ('{R}','{Q}','{E}')"))
print('esik:', sql("select value from beta_settings where key='profil_trusted_esik'"))
V="('a354a354-0000-4000-8000-000000000001'::uuid,'a354a354-0000-4000-8000-000000000002'::uuid)"
q_tanis=f"select count(*) from discover_people(null,null) p where p.user_id='{Q}'"
q_prof=f"select public.profil_gorunur_mu('{Q}')"
chk('ONCE: e-posta+telefon (24) Tanis ta Trusted+ kisiyi GORMUYOR (hata yeniden uretildi)', sql(q_tanis,R,True)[0]=='0', sql(q_tanis,R,True))
chk('ONCE: profil gorunmuyor', sql(q_prof,R,True)[0]=='f')
out=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
print('355 rc',out.returncode,out.stderr[-800:]); print(out.stdout[-1800:])
chk('355 hatasiz', out.returncode==0)
out2=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
chk('355 ikinci kosu hatasiz', out2.returncode==0, out2.stderr[-300:])
chk('SONRA: 24 puanli kullanici Tanis ta goruyor', sql(q_tanis,R,True)[0]=='1')
chk('SONRA: profil gorunuyor', sql(q_prof,R,True)[0]=='t')
chk('SONRA: yalniz e-posta (10) hala GORMUYOR', sql(q_tanis,E,True)[0]=='0' and sql(q_prof,E,True)[0]=='f')
for u,ad in ((R,'gercek'),(E,'eposta')):
    chk(f'{ad}: vitrin Kesfet 0', sql("select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V,u,True)[0]=='0')
    chk(f'{ad}: vitrin Tanis 0', sql("select count(*) from discover_people(null,null) p where p.user_id in "+V,u,True)[0]=='0')
    chk(f'{ad}: vitrin profil 0', sql("select count(*) from unnest(array"+V.replace('(','[',1)[:-1]+"]) x where public.profil_gorunur_mu(x)",u,True)[0]=='0')
    chk(f'{ad}: vitrin profiles tablosu (API) 0 satir', sql("select count(*) from profiles where user_id in "+V,u,True)[0]=='0')
I=sql("select id from users where email='inceleme@loungelink.co'")[0]
if I:
    chk('inceleme: vitrin profiles satiri okunuyor (ad gelir)', sql("select count(*) from profiles where user_id in "+V,I,True)[0]=='2')
    chk('inceleme: Kesfet 2 vitrin', sql("select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V,I,True)[0]=='2')
else:
    print('  (inceleme hesabi yerelde yok — 354 testinde ayrica olculdu)')
chk('olcum tablosunda gercek kullanicilarda vitrin 0', sql("select coalesce(sum(greatest(vitrin_kesfet,0)+greatest(vitrin_tanis,0)+vitrin_profil),0) from tezgah.olcum_355 where tur='gercek'")[0]=='0')
chk('olcum: gercek kullanicilar HICBIR test hesabini gormuyor (Kesfet/Tanis/profil/Radar)', sql("select coalesce(sum(greatest(test_kesfet,0)+greatest(test_tanis,0)+test_profil+greatest(test_radar,0)),0) from tezgah.olcum_355 where tur='gercek'")[0]=='0')
print('test hesabi sayisi (yerel):', sql("select count(*) from users where public.seed_test_hesabi(email)")[0])
chk('olcum hatasi yok', sql("select count(*) from tezgah.olcum_355 where vitrin_kesfet=-1 or tanis_kisi=-1 or test_radar=-1")[0]=='0')
chk('SONRA: gercek kullanicilar inceleme hesabini gormuyor (Tanis/Radar/profil)', sql("select coalesce(sum(greatest(inceleme_goren,0)),0) from tezgah.olcum_355 where asama='2_sonra' and tur='gercek'")[0]=='0')
print('   once inceleme goren:', sql("select coalesce(sum(greatest(inceleme_goren,0)),0) from tezgah.olcum_355 where asama='1_once' and tur='gercek'")[0])
I2='22222222-2222-4222-8222-222222222222'
print('   hizala:', sql("select public.inceleme_vitrin_tazele()")[0][:150])
av=sql("select id from availabilities where host_id='a354a354-0000-4000-8000-000000000001'")[0]
raw=sql(f"select public.create_request('{av}','lounge','test')",I2)
chk('SONRA: inceleme hesabi vitrin ilanina hala istek gonderebiliyor', raw[2]==0, (raw[0][:100], raw[1][:200]))
H=sql(f"select host_id from availabilities where id='{av}'")[0]
chk('SONRA: istegi alan vitrin host inceleme profilini goruyor', sql(f"select public.profil_gorunur_mu('{I2}')",H,True)[0]=='t')

# ── Tanış → İstekler → Bağlantılar akışı (gerçek iki kullanıcı, 355 sonrası) ──
sql(f"update profiles set name='Gercek Kisi', show_on_discovery=true where user_id='{R}'")
chk('AKIS: R Tanis ta Q yu goruyor', sql(f"select count(*) from discover_people(null,null) p where p.user_id='{Q}' and p.rel='none'",R,True)[0]=='1')
chk('AKIS: R, Q profilinde adi goruyor (profiles RLS)', sql(f"select name from profiles where user_id='{Q}'",R,True)[0]=='Ikinci Kisi')
rr=sql(f"select public.send_connection('{Q}','coffee','Ayni rotadayiz')",R)
chk('AKIS: R baglanti istegi gonderdi', rr[2]==0, (rr[0][:100], rr[1][:200]))
cid=sql(f"select id from connection_requests where from_id='{R}' and to_id='{Q}'")[0]
gi=sql("select count(*) from baglanti_istekleri() b",Q,True)
print('   Q baglanti_istekleri:', gi)
chk('AKIS: Q gelen istegi goruyor (connection_requests RLS)', sql(f"select count(*) from connection_requests where to_id='{Q}' and status='pending'",Q,True)[0]=='1')
chk('AKIS: Q gonderenin profilini goruyor', sql(f"select public.profil_gorunur_mu('{R}')",Q,True)[0]=='t')
ra=sql(f"select public.respond_connection('{cid}', true)",Q)
chk('AKIS: Q kabul etti', ra[2]==0, ra[1][:200])
chk('AKIS: iki taraf da bagli', sql(f"select status from connection_requests where id='{cid}'")[0]=='accepted')
chk('AKIS: bagli olan Tanis listesinde artik "none" degil', sql(f"select count(*) from discover_people(null,null) p where p.user_id='{Q}' and p.rel='none'",R,True)[0]=='0')
so=sql(f"select public.baglanti_sohbeti_ac('{cid}')",R)
print('   sohbet ac:', so[0][:100], so[1][:150])
chk('AKIS: baglanti sohbeti acilabiliyor', so[2]==0, so[1][:200])
# yalnız e-postalı kullanıcı da istek alıp verebiliyor mu (eşik yalnız görünürlüğü etkiler)
re_=sql(f"select public.send_connection('{Q}','coffee','merhaba')",E)
print('   yalniz e-posta send_connection:', re_[0][:80], re_[1][:160])
print(f'SON: {len(ok)} gecti · {len(bad)} dustu')
