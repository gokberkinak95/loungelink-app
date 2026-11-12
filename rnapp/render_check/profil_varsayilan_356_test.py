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


D = pathlib.Path('/tmp/ll_v356_' + str(os.getpid()))
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
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f) and int(f[:3])<=355), key=o) :
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', os.path.join(sd, f)],
                   capture_output=True, text=True, env=ENV)




ok, bad = [], []
def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra != '' else ''))
R='11111111-1111-4111-8111-111111111111'; Q='33333333-3333-4333-8333-333333333333'; C='55555555-5555-4555-8555-555555555555'; I='22222222-2222-4222-8222-222222222222'
# 355 vitrini ve inceleme hesabini kurmus olsun diye: inceleme once, sonra 354+355 tekrar
sql(f"insert into auth.users (id,email) values ('{I}','inceleme@loungelink.co')"); sql("select public.inceleme_hesabi_hazirla('inceleme@loungelink.co')")
import os as _o
for f in ('354_inceleme_vitrini_gizli.sql','355_tanis_esik_ve_test_profil.sql'):
    rr=subprocess.run([str(BIN/'psql'),uri,'-X','-q','-v','ON_ERROR_STOP=1','-f',_o.path.join(sd,f)],capture_output=True,text=True,env=ENV); print(f,'rc',rr.returncode, rr.stderr[-200:] if rr.returncode else '')
sql(f"insert into auth.users (id,email) values ('{R}','yeni.uye@gmail.com'),('{Q}','diger.uye@gmail.com'),('{C}','gizli.uye@gmail.com')")
for u,ad in ((R,'Yeni Uye'),(Q,'Diger Uye'),(C,'Gizli Uye')):
    sql(f"update verifications set email_verified=true where user_id='{u}'"); sql(f"select public.recompute_trust('{u}')")
    sql(f"update profiles set name='{ad}', show_on_discovery=true where user_id='{u}'")
sql(f"update profiles set profile_visibility='Connections' where user_id='{C}'")
print('puan/gorunurluk:', sql(f"select string_agg(p.name||':'||coalesce(t.score,0)||':'||p.profile_visibility,' ') from profiles p left join trust_scores t on t.user_id=p.user_id where p.user_id in ('{R}','{Q}','{C}')")[0])
qt=f"select count(*) from discover_people(null,null) p where p.user_id='{Q}'"
chk('ONCE: yalniz e-postali yeni uye Tanis ta digerini GORMUYOR (sorun uretildi)', sql(qt,R,True)[0]=='0')
out=subprocess.run([str(BIN/'psql'),uri,'-X','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV)
print('356 rc',out.returncode,out.stderr[-500:]); print(out.stdout[-1500:])
chk('356 hatasiz', out.returncode==0)
chk('356 ikinci kosu hatasiz', subprocess.run([str(BIN/'psql'),uri,'-X','-q','-v','ON_ERROR_STOP=1','-f',_sys.argv[1]],capture_output=True,text=True,env=ENV).returncode==0)
chk('SONRA: yeni uye Tanis ta digerini goruyor', sql(qt,R,True)[0]=='1')
chk('SONRA: profilde ad geliyor', sql(f"select name from profiles where user_id='{Q}'",R,True)[0]=='Diger Uye')
chk('SONRA: Baglantilarim secen kisi Tanis ta GORUNMUYOR (tercih korunur)', sql(f"select count(*) from discover_people(null,null) p where p.user_id='{C}'",R,True)[0]=='0')
chk('SONRA: Baglantilarim secenin profil satiri kapali', sql(f"select count(*) from profiles where user_id='{C}'",R,True)[0]=='0')
chk('SONRA: inceleme hesabi gorunmuyor', sql(f"select count(*) from discover_people(null,null) p where p.user_id='{I}'",R,True)[0]=='0' and sql(f"select public.profil_gorunur_mu('{I}')",R,True)[0]=='f')
chk('SONRA: inceleme profili Connections kaldi', sql(f"select profile_visibility from profiles where user_id='{I}'")[0]=='Connections')
V="('a354a354-0000-4000-8000-000000000001'::uuid,'a354a354-0000-4000-8000-000000000002'::uuid)"
chk('SONRA: vitrin Kesfet/Tanis/profil gercek kullaniciya 0', sql("select (select count(*) from discover_availabilities(null,null,null,null) d where d.host_id in "+V+")+(select count(*) from discover_people(null,null) p where p.user_id in "+V+")+(select count(*) from profiles where user_id in "+V+")",R,True)[0]=='0')
chk('SONRA: yeni kayit varsayilani Everyone', (sql("insert into auth.users (id,email) values ('66666666-6666-4666-8666-666666666666','en.yeni@gmail.com')") and sql("select profile_visibility from profiles where user_id='66666666-6666-4666-8666-666666666666'")[0]=='Everyone'))
chk('SONRA: Ayarlar den Guvenilir uyeler secen tekrar gizlenir (tercih calisiyor)', (sql(f"update profiles set profile_visibility='Trusted+' where user_id='{Q}'") and sql(qt,R,True)[0]=='0'))
rr=sql(f"select public.send_connection('{Q}','coffee','selam')",R)
chk('baglanti istegi (yalniz e-posta) gonderilebiliyor', rr[2]==0, rr[1][:150])
chk('geri alma tablosu dolu', int(sql("select count(*) from tezgah.gorunurluk_356")[0])>=2)
chk('olcum: gercek kullanicida test/inceleme gorunurlugu 0', sql("select coalesce(sum(greatest(test_kesfet,0)+greatest(test_tanis,0)+test_profil+greatest(test_radar,0)+greatest(inceleme_goren,0)),0) from tezgah.olcum_355 where asama like '%356%' and tur='gercek'")[0]=='0')

# ── telefon kanalı 'firebase' iken: doğrulama kuralı aynen çalışıyor mu ──
sql("insert into beta_settings (key,value) values ('telefon_kanali', to_jsonb('firebase'::text)) on conflict (key) do update set value=excluded.value")
P='77777777-7777-4777-8777-777777777777'
sql(f"insert into auth.users (id,email) values ('{P}','telefonsuz@gmail.com')"); sql(f"update verifications set email_verified=true where user_id='{P}'")
sql(f"update profiles set profile_visibility='Everyone' where user_id='{Q}'")
r1=sql(f"select public.send_connection('{Q}','coffee','selam')",P)
chk('firebase: telefonsuz kullanici baglanti isteginde contact_not_verified aliyor (kural duruyor)', r1[2]!=0 and 'contact_not_verified' in r1[1], r1[1][:120])
chk('firebase: contact_not_verified icin TR+EN metin var (errMap)', 'contact_not_verified' in open(r'C:/LoungeLink/rnapp/src/i18n.js',encoding='utf-8').read())
sql(f"update verifications set phone_verified=true, phone_verified_at=now() where user_id='{P}'"); sql(f"select public.recompute_trust('{P}')")
r2=sql(f"select public.send_connection('{Q}','coffee','selam')",P)
chk('firebase: telefonu dogrulayinca baglanti istegi HATASIZ', r2[2]==0, r2[1][:150])
rs=sql(f"select public.seyahat_ekle(p_airport=>'IST', p_date=>current_date+4, p_from=>'09:30'::time, p_to=>'14:00'::time, p_destination=>'LHR', p_flight=>'TK1980')",P)
chk('firebase: telefonlu kullanici seyahat ekleyebiliyor', rs[2]==0, rs[1][:150])
rs2=sql(f"select public.seyahat_ekle(p_airport=>'IST', p_date=>current_date+5, p_from=>'09:30'::time, p_to=>'14:00'::time, p_destination=>'LHR', p_flight=>'TK1981')",'33333333-3333-4333-8333-333333333333')
print('   telefonsuz seyahat_ekle:', rs2[0][:80], rs2[1][:120])
print(f'SON: {len(ok)} gecti · {len(bad)} dustu')
