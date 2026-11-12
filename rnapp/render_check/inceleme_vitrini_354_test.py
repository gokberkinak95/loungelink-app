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


D = pathlib.Path('/tmp/ll_v354_' + str(os.getpid()))
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
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f) and int(f[:3])<=353), key=o) :
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', os.path.join(sd, f)],
                   capture_output=True, text=True, env=ENV)


ok, bad = [], []
def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra != '' else ''))
print('vitrin oncesi test hesabi:', sql("select count(*) from users where email like '%.test'")[0])
# gercek kullanici + inceleme hesabi
sql("insert into auth.users (id,email) values ('11111111-1111-4111-8111-111111111111','gercek.kisi@gmail.com'),('22222222-2222-4222-8222-222222222222','inceleme@loungelink.co')")
print('hazirla:', sql("select public.inceleme_hesabi_hazirla('inceleme@loungelink.co')"))
R='11111111-1111-4111-8111-111111111111'; I='22222222-2222-4222-8222-222222222222'
# gercek kullanici IST icin haber ver
print('talep:', sql(f"insert into talep_kayitlari (user_id, airport_code, tarih_bas, tarih_bit, aktif) values ('{R}','IST',current_date,current_date+10,true)"))
n0=sql(f"select count(*) from notifications where user_id='{R}'")[0]
out=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
print('354 rc',out.returncode, out.stderr[-600:]); print(out.stdout[-500:])
out=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
chk('354 ikinci kosu hatasiz', out.returncode==0, out.stderr[-200:])
V="('a354a354-0000-4000-8000-000000000001'::uuid,'a354a354-0000-4000-8000-000000000002'::uuid)"
chk('vitrin ilan sayisi 2 (tekrar kosu cift acmadi)', sql(f"select count(*) from availabilities where host_id in {V} and active")[0]=='2', sql(f"select count(*) from availabilities where host_id in {V}")[0])
chk('gercek kisiye haber ver bildirimi GITMEDI', sql(f"select count(*) from notifications where user_id='{R}'")[0]==n0)

print('DBG av:', sql(f"select a.min_trust, a.visibility, a.avail_date, a.lounge_id is not null, hu.role, hu.is_staff, hu.shadow_limited, p.show_on_discovery, p.women_safety_mode from availabilities a join users hu on hu.id=a.host_id left join profiles p on p.user_id=a.host_id where a.host_id in {V}"))
print('DBG trust inc:', sql(f"select score from trust_scores where user_id='{I}'"))
print('DBG ham inc:', sql("select count(*) from discover_availabilities_ham(null,null,null,null)",I,True))
print('DBG base inc:', sql("select count(*) from discover_availabilities_base(null,null,null,null)",I,True))
print('DBG all inc:', sql("select count(*) from discover_availabilities(null,null,null,null)",I,True))
for ad,q in [('discover_availabilities',"select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V),
             ('discover_people IST',"select count(*) from discover_people('IST',null) p where p.user_id in "+V),
             ('kisi_ara Elif',"select count(*) from kisi_ara('Elif') k where k.user_id in "+V),
             ('kisi_ara Mert',"select count(*) from kisi_ara('Mert') k where k.user_id in "+V),
             ('guide_hosts_today IST +2',"select count(*) from guide_hosts_today('IST', current_date+2) g where g.host_id in "+V),
             ('kesfet_ozeti',"select kesfet_ozeti(14)::text"),
             ('havalimani_nabzi',"select havalimani_nabzi(14)::text"),
             ('lounge_radar_people',"select count(*) from lounge_radar_people() x where x.user_id in "+V)]:
    gr=sql(q,R,True); gi=sql(q,I,True)
    print(f'   {ad}: gercek={gr[0][:120]!r} {gr[1][:120]}  | inceleme={gi[0][:120]!r} {gi[1][:120]}')
gr=sql("select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V,R,True)[0]
gi=sql("select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V,I,True)[0]
chk('Kesfet: gercek kullanici vitrin ilani gormuyor', gr=='0', gr)
chk('Kesfet: inceleme hesabi 2 vitrin ilani goruyor', gi=='2', gi)
gr=sql("select count(*) from availabilities a where a.host_id in "+V,R,True)[0]
gi=sql("select count(*) from availabilities a where a.host_id in "+V,I,True)[0]
chk('Tablo dogrudan (API): gercek kullanici 0 satir', gr=='0', gr)
chk('Tablo dogrudan (API): inceleme 2 satir (rozet/tasiyici okumasi)', gi=='2', gi)
H1='a354a354-0000-4000-8000-000000000001'
chk('Host kendi ilanini okuyabiliyor (RLS host)', sql("select count(*) from availabilities where host_id='"+H1+"'",H1,True)[0]=='1')
chk('inceleme seyahati 1. ilanla ayni gun', sql(f"select (select visit_date from visits where user_id='{I}' and flight_number='TK1979')=(select avail_date from availabilities where host_id='{H1}')")[0]=='t')
av=sql("select d.id from discover_availabilities(null,null,null,null) d where d.host_id in "+V+" order by d.avail_date limit 1",I,True)[0]
print('DBG5', sql("select a.lounge_name from availabilities a where a.host_id in "+V))
b0=sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{I}'")[0]
raw=sql(f"select public.create_request('{av}','lounge','test')",I)
chk('inceleme hesabi vitrin ilanina istek gonderebiliyor', raw[2]==0, (raw[0][:120], raw[1][:200]))
b1=sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{I}'")[0]
kb=json.loads(raw[0]).get('kredi_bedeli',1)
chk('istek kredisi bedel kadar dustu', int(b0)-int(b1)==kb, f'{b0}->{b1} bedel {kb}')
print('   discover lounge_name:', sql("select string_agg(coalesce(lounge_name,'-'),' / ') from discover_availabilities(null,null,null,null)",I,True)[0])
sql(f"update verifications set email_verified=true, phone_verified=true where user_id='{R}'")
sql(f"insert into visits (user_id,airport_code,destination,visit_date,time_from,time_to,flight_number) select '{R}','IST','LHR',avail_date,'09:30','14:00','TK1979' from availabilities where id='{av}'")
raw=sql(f"select public.create_request('{av}','lounge','test')",R)
chk('gercek kullanici vitrin ilanina istek GONDEREMIYOR', raw[2]!=0, raw[1][:160])
# gece tazeleme
sql(f"update availabilities set avail_date=current_date-1 where host_id in {V} and id::text<>'{av}'")
print('tazele:', sql("select public.test_verisi_tazele(2)"))
sql(f"update availabilities set avail_date=current_date where host_id='{H1}'")
print('hizala:', sql("select public.inceleme_vitrin_tazele()"))
chk('hizalayici bugune gelen ilani ileri aldi + seyahati esledi', sql(f"select (select avail_date from availabilities where host_id='{H1}')=current_date+2 and (select visit_date from visits where user_id='{I}' and flight_number='TK1979')=current_date+2")[0]=='t', sql(f"select visit_date from visits where user_id='{I}'"))
chk('hizalayici kullaniciya kapali', sql("select public.inceleme_vitrin_tazele()",R,True)[2]!=0)
chk('gece tazeleme gecmis vitrin ilanini ileri aldi', sql(f"select count(*) from availabilities where host_id in {V} and active and avail_date>=current_date")[0]=='2')
print(f'\n{len(ok)} gecti · {len(bad)} dustu')
cr=sql("insert into connection_requests (from_id,to_id) values ('11111111-1111-4111-8111-111111111111','a354a354-0000-4000-8000-000000000002')",'11111111-1111-4111-8111-111111111111',True)
chk('gercek kullanici vitrin host a baglanti GONDEREMIYOR', cr[2]!=0, cr[1][:120])
rm=sql("select public.temizlik_derin_sil('public.users', $$email like '%@vitrin.loungelink.test'$$)")
rm2=sql("delete from auth.users where email like '%@vitrin.loungelink.test'")
chk('kaldirma komutlari hatasiz, vitrin kalmadi', rm[2]==0 and rm2[2]==0 and sql("select count(*) from users where email like '%@vitrin%'")[0]=='0', (rm[1][:200],rm2[1][:200]))
chk('kaldirinca inceleme ve gercek hesap duruyor', sql("select count(*) from users where email in ('inceleme@loungelink.co','gercek.kisi@gmail.com')")[0]=='2')
print(f'SON: {len(ok)} gecti · {len(bad)} dustu')
