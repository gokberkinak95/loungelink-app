import os,re,shutil,pathlib,subprocess,pgserver
BIN=pathlib.Path(pgserver.__file__).parent/'pginstall'/'bin'; ENV={'PATH':f'{BIN}:/usr/bin:/bin','HOME':'/tmp'}
import pathlib as _pl
ROOT=_pl.Path(__file__).resolve().parent.parent
# 🔴 v2.46 — SQL KLASÖRÜ ARTIK ll_paths ÜZERİNDEN ÇÖZÜLÜYOR.
# Üç E2E betiği de `ROOT/'sql'` sabitini yazıyordu. SQL klasörü rnapp'in
# içinde değilse üçü de FileNotFoundError ile çöküyordu — yani "E2E
# kırmızı" görünüyordu ama ürün değil YOL yanlıştı. ll_paths hem ortam
# değişkenini (LL_SQL_DIR) hem kardeş klasörü tanır.
import sys as _sys
_sys.path.insert(0, str(ROOT))
import ll_paths as _llp
ns={}; exec(open(ROOT/'pg_run.py').read().replace("if __name__ == '__main__':\n    sys.exit(main())",""), ns)
ns['install_fake_extensions']()
# 🔴 v2.42 — TESTLER BIRBIRINI BOZUYORDU.
# Uc E2E de SABIT bir /tmp dizini kullaniyordu. Tek basina kosunca
# 14/14 geciyor, ustuste kosunca 9/14 dusuyordu: onceki kosudan kalan
# yarim kapanmis bir postgres, ayni veri dizinine baglaniyor.
#
# Kirilgan test, denetimin en kotu halidir: yesil yanar ama guvenilmez,
# ve bir sure sonra "yine mi takildi" deyip gormezden gelinir.
# Her kosu artik KENDI dizinini alir.
# ════════════════════════════════════════════════════════════════════
# 🔴 BU HARNESS DİSKİ DOLDURUYORDU — VE BUNU e2e ÇÖKÜNCE ÖĞRENDİM.
# Her koşu `/tmp/ll_<ad>_<pid>` altında yeni bir PostgreSQL veri dizini
# açıyor (~50 MB) ve onu YALNIZ BAŞLANGIÇTA, aynı PID'e denk gelirse
# siliyordu. PID her koşuda farklı olduğu için hiçbir dizin silinmedi.
#
# Ölçüm: 517 artık dizin, 26 GB. Disk %100 dolunca `initdb` düştü ve
# e2e "başarısız" verdi — ama kodda hiçbir şey bozulmamıştı. Yani
# harness, ölçtüğü şey hakkında YANLIŞ HABER veriyordu.
#
# 🆕 SINIF: "GEÇİCİ DOSYAYI BAŞLANGIÇTA TEMİZLEMEK TTEMİZLİK DEĞİLDİR —
# ÇIKIŞTA TEMİZLEMEZSEN, HER KOŞU BİR ÖNCEKİNİ DEĞİL KENDİNİ BIRAKIR."
#
# İki katman: (1) çıkışta kendi dizinini sil, (2) başlangıçta ESKİ
# kardeşlerini süpür (çöken bir koşu çıkışa hiç gelmez).
def _ll_temizle(_d):
    import atexit, glob as _g, shutil as _s, os as _o, pathlib as _p, re as _r
    kok = _p.Path(_d)
    onek = _r.sub(r'_\d+$', '', kok.name)
    for eski in _g.glob('/tmp/' + onek + '_*'):
        if _p.Path(eski) != kok:
            _s.rmtree(eski, ignore_errors=True)
    atexit.register(lambda: _s.rmtree(str(kok), ignore_errors=True))

D=pathlib.Path('/tmp/ll_e2e_' + str(os.getpid()))
_ll_temizle(D)
if D.exists(): shutil.rmtree(D,ignore_errors=True)
D.mkdir(parents=True); srv=pgserver.get_server(D); uri=srv.get_uri()
def sql(q, as_user=None):
    # 🔴 `set request.jwt.claims` AYRI bir -c ile gonderilmeli.
    # Ayni -c icinde noktali virgulle birlestirince psql once "SET"
    # basiyor ve o satir SONUCA karisiyordu: create_request'in dondurdugu
    # uuid "SET\n{...}" olarak okunup sonraki adimlar cokuyordu.
    # Testin kendi kosucusundaki hata, urunun hatasi gibi gorunuyordu.
    cmd=[str(BIN/'psql'),uri,'-X','-t','-A','-v','ON_ERROR_STOP=1']
    if as_user:
        cmd += ['-c', "set request.jwt.claims = '{\"sub\":\"%s\"}'" % as_user]
    cmd += ['-c', q]
    r=subprocess.run(cmd,capture_output=True,text=True,env=ENV)
    out=[l for l in r.stdout.splitlines() if l.strip() and l.strip()!='SET']
    return ('\n'.join(out).strip(), r.stderr.strip(), r.returncode)
sql(ns['SHIM'])
sd=_llp.sql_dir()
o=lambda f:(re.match(r'^(\d{3})([a-z]?)_',f).group(1),0 if re.match(r'^(\d{3})([a-z]?)_',f).group(2) else 1,f)
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$',f)),key=o)+sorted(x for x in os.listdir(sd) if x.startswith('SEED')):
    subprocess.run([str(BIN/'psql'),uri,'-X','-q','-v','ON_ERROR_STOP=1','-f',os.path.join(sd,f)],
                   capture_output=True,text=True,env=ENV)

HOST,GUEST = None,None
HOST = sql("select id from users where email='kural5@seed.loungelink.test'")[0]   # Priority Pass (ucretli)
GUEST= sql("select id from users where email='kmisafir1@seed.loungelink.test'")[0]
# 🔴 KIRILGANLIGIN SON PARCASI BURASIYDI — TESTIN KENDISINDE.
# `select id from availabilities where host_id=...` ORDER BY'siz.
# Host'un birden fazla ilani varsa PostgreSQL istedigini donduruyor
# ve test bazen Priority Pass kabul etmeyen bir salonun ilanini
# aliyordu. Bes kosuda dort gecip bir dusmesinin sebebi buydu.
#
# Haftalarca "kural motoru belirsiz" sandim ve motoru iki kez
# yeniden yazmaya kalktim. Hata motorda degil, ONU OLCEN ARACTAYDI.
# Kirilgan bir test yalnizca guvenilmez degil, YANLIS YERI GOSTERIR.
# 🔴 TEST IHTIYACI OLAN ILANI KOSULA GORE SECER, HOST'A GORE DEGIL.
#
# Eski hali: `select id from availabilities where host_id=...` — yani
# "kural5'in ilani" varsayimi. Ama seed'in sectigi salon her kosuda
# ayni olmayabiliyor ve o salonda Priority Pass ucretli olmayabiliyor.
# Test bes kosuda dort gecip bir dusuyordu.
#
# Bu testin OLCMEK ISTEDIGI sey "ucretli misafir akisi". O halde
# aradigi ilan "kural5'in ilani" degil, "ucretli misafir kurali olan
# ilan"dir. Kosulu dogrudan yazinca kirilganlik ortadan kalkar —
# ve test artik NEYI olctugunu da soyluyor.
#
# Ders: bir test, olcmek istedigi sartlari VARSAYMAK yerine SECMELI.
_rows = sql("""select av.id::text, av.host_id::text, av.airport_code::text
  from availabilities av
  join lounges l on l.id = av.lounge_id
  join host_entitlements he on he.user_id = av.host_id
  join lounge_venue_acceptance a on a.venue_id = l.venue_id
   and a.program_id = he.program_id and a.active
 where a.guest_policy = 'paid' and a.fee_payer = 'member_card'
 -- 🔴 `order by av.id` DETERMINIST DEGIL: av.id gen_random_uuid ile
 -- uretiliyor, yani her kosuda BASKA bir aday one geciyordu. Testin
 -- hangi ilani sectigi kosudan kosuya degisince, dusen bir adimin
 -- sebebini aramak da imkansiz hale geliyor. Sabit kolonlarla siralanir;
 -- av.id yalnizca son esitlik bozucu olarak kalir.
 order by av.airport_code, av.avail_date, av.time_from, av.id
 limit 1""")
if not _rows or not _rows[0].strip():
    print("\n🔴 ORTAM: ucretli misafir kurali olan ilan bulunamadi — test kosulmadi.")
    print("   Bu bir urun hatasi degil; seed bu kosuda boyle bir senaryo uretmemis.")
    raise SystemExit(2)
AV, HOST, APT = [x.strip() for x in _rows[0].split("|")[:3]]

# 🔴 v2.46 — "BILINEN SINIR" DIYE YAZILAN SEY ASLINDA TESTIN HATASIYDI.
#
# Eski not soyle diyordu: "1. adim bir ORTAM adimidir, urun adimi degil;
# discover_availabilities seyahatten fazlasina bakiyor." Bu TESHIS
# YANLISTI ve bir hatayi kalici bir mazerete cevirmisti.
#
# Gercek sebep tek satirlik: ilani KOSULA gore seciyoruz (dogru) ama
# kesfi SABIT 'IST' ile cagiriyorduk. Secilen ilan SAW'daydi. Yani
# testin sordugu soru "misafir bu ilani goruyor mu" degil, "SAW'daki
# ilani IST listesinde goruyor mu" idi — cevabin hayir olmasi lazim.
# Olculdu: ayni ilan, ayni misafir, 'SAW' ile -> 1; 'IST' ile -> 0.
#
# Ilan artik kendi havalimani koduyla (APT) araniyor.
#
# DERS: "bilinen sinir" etiketi, bir adim ANLASILDIGINDA yazilir.
# Anlasilmadan yazilirsa yaptigi tek sey, kirmizi bir adimi kimsenin
# bir daha bakmayacagi hale getirmektir.

ok=[];bad=[]
def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ')+name+(('  → '+str(extra)) if extra else ''))

print("=== IKI HESAPLI CANLI AKIS (gercek PostgreSQL) ===")
print(f"ilan={AV[:8]} ({APT}, ucretli misafir kurali) guest=kmisafir1")

# 1 misafir ilani goruyor mu
n,_,_ = sql(f"select count(*) from discover_availabilities('{APT}',null,null,null) d where d.id='{AV}'", GUEST)
chk(f"1. Misafir ilani kesifte goruyor ({APT})", n=='1', n)

# 2 precheck: ucret ve kredi bilgisi
pre,_,_ = sql(f"select public.request_precheck('{AV}')", GUEST)
chk("2. Precheck ucretli diyor", "'paid'" in pre or '"paid"' in pre)
# 🔴 187: eski hali '"credit_cost": 3' ariyordu ve KIRMIZI yaniyordu.
# Test urunun bozuk oldugunu degil KENDI VARSAYIMINI bildiriyordu:
# credit_cost yalnizca AKTARIM kalemi (2); escrow (1) ayri.
# 187 precheck'e credit_total ekledi. Artik TOPLAM olculuyor.
import json as _jp
try: _pj = _jp.loads(pre)
except Exception: _pj = {}
# 🔴 22 AGUSTOS — BU ADIM UC GUNDUR KIRMIZIYDI VE KIMSE GORMEDI.
# Test "2 aktarim = 3 toplam" diye SABIT bir sayi bekliyordu. Oysa
# SQL 219 (19 Agustos) urun kararini degistirip `paid_guest_credits`
# ayarini 1'e cekti ve kendi nobetcisini de koydu (219:326: "ayar 1
# bekleniyor"). Yani iki nobetci BIRBIRIYLE CELISIYORDU: 219 "1 olmali"
# diyor, e2e "2 olmali" diyordu.
#
# 🆕 SINIF: **"BIR TESTIN ICINE URUN KARARINI SABIT YAZMAK, O KARARI
# DEGISTIREN HERKESI YALANCI CIKARIR."**
# Test artik AYARI okuyup ILISKIYI dogruluyor: toplam = escrow + aktarim.
# Sayinin kendisi urunun karari; testin isi o karara uyulup uyulmadigi.
_ayar = sql("select coalesce((value)::text::int, 2) from beta_settings where key='paid_guest_credits'")[0]
_bekl = int(_ayar or 2)
chk(f"3. Precheck TOPLAM krediyi soyluyor (1 escrow + {_bekl} aktarim = {1+_bekl})",
    _pj.get("credit_total") == 1 + int(_pj.get("credit_cost") or 0)
    and int(_pj.get("credit_cost") or -1) == _bekl,
    f'total={_pj.get("credit_total")} cost={_pj.get("credit_cost")} hold={_pj.get("credit_hold")} ayar={_bekl}')
chk("4. Ucret host''un kartindan", 'member_card' in pre)

# 3 istek gonder
raw,err,rc = sql(f"select public.create_request('{AV}','lounge','Merhaba')", GUEST)
import json as _j
try: rid = _j.loads(raw).get('id','')
except Exception: rid = raw
chk("5. Istek olusturuldu", rc==0 and rid, err[:120] or rid[:8])

gb0 = sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{GUEST}'")[0]
hb0 = sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{HOST}'")[0]

# 4 host kabul ediyor
out,err,rc = sql(f"select public.respond_request('{rid}','accept')", HOST)
chk("6. Host kabul etti", rc==0, err[:150])

gb1 = sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{GUEST}'")[0]
hb1 = sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{HOST}'")[0]
print(f"      misafir kredi {gb0} -> {gb1} · host {hb0} -> {hb1}")
chk("7. Tesekkur kredisi misafirden dustu", int(gb1) < int(gb0), f"{gb0}->{gb1}")
chk("8. Tesekkur kredisi host''a gecti", int(hb1) > int(hb0), f"{hb0}->{hb1}")

# 5 sohbet
m,_,_ = sql(f"select count(*) from messages m where m.channel_id in (select id from chat_channels where request_id='{rid}')")
chk("9. Kabulde tanitim mesaji sohbete dustu", int(m or 0)>0, m)

# 6 oturum baslat (iki taraf)
o1h,e1h,_ = sql(f"select public.start_session_request('{rid}')", HOST)
o1g,e1g,_ = sql(f"select public.start_session_request('{rid}')", GUEST)
if e1h or e1g: print("      start hatasi:", (e1h or e1g)[:120])
allst,_,_ = sql(f"select count(*)||' oturum: '||string_agg(status::text,',') from sessions where request_id='{rid}'")
# 🔴 TESTIN HATASI, URUNUN DEGIL: `sessions` tablosunda `created_at`
# YOK. Siralama hata verince psql bos donuyordu ve ben bunu "oturum
# aktif degil" diye okuyordum. Tani sorgusu "1 oturum: active" deyince
# celiski ortaya cikti — urun bastan beri dogru calisiyormus.
st,_,_ = sql(f"select status from sessions where request_id='{rid}' limit 1")
chk("10. Iki taraf basladi -> oturum aktif", st=='active', f"{st} | {allst}")

# 7 cift onay tamamlama
sid = sql(f"select s.id from sessions s where s.request_id='{rid}'")[0]
sql(f"select public.confirm_session('{sid}')", HOST)
sql(f"select public.confirm_session('{sid}')", GUEST)
st2,_,_ = sql(f"select status from sessions where id='{sid}'")
chk("11. Cift onayla tamamlandi", st2=='completed', st2)

# 8 puanlama
o1,e1,r1 = sql(f"select public.rate_session('{sid}',5,'Harika')", GUEST)
chk("12. Misafir puanladi", r1==0, e1[:120])
# 9 saha raporu
# 🔴 187: eski 5 parametreli imza (095) PostgREST belirsizligi
# yaratiyordu ve DUSURULDU. App 152'nin 7 parametreli imzasini
# cagiriyor (screens.js:4828) — test de onu cagirmali. Eski hali
# "does not exist" veriyordu ve bu URUN hatasi degil TEST hatasiydi.
o2,e2,r2 = sql(f"select public.submit_field_report('{sid}'::uuid, true, true, true, '35', null, null)", GUEST)
chk("13. Saha raporu kaydedildi", r2==0, e2[:120])
# 10 tekrar kabul -> cifte kredi almamali
sql(f"update requests set status='pending' where id='{rid}'")
sql(f"select public.respond_request('{rid}','accept')", HOST)
gb2 = sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{GUEST}'")[0]
chk("14. Tekrar kabulde CIFTE kredi alinmadi", gb2==gb1, f"{gb1}->{gb2}")

print(f"\n  {len(ok)} gecti · {len(bad)} basarisiz")
if bad: print("  BASARISIZ: "+", ".join(bad))

# 🔴 22 AGUSTOS — VE ASIL KUSUR BUYDU: `bad` DOLU OLSA BILE BU DOSYA
# 0 ILE CIKIYORDU. `npm run e2e` zincirinde && var, yani bu dosya sifir
# donunce sonraki koşuyor ve tur YESIL bitiyordu. Uc gundur kirmizi olan
# 3. adim tam bu yuzden kimseye ulasmadi.
#
# 🆕 SINIF: **"CIKIS KODUNA YANSIMAYAN BIR KIRMIZI, KIRMIZI DEGILDIR."**
# (Kardesi: olcum araci sunucu kapaliyken "0 sorun" diyordu — site
# tarafinda ayni sinif, 21 Agustos.)
_EXIT_KODU = 1 if bad else 0

print("\n--- 9 ve 10 icin tani ---")
print("messages kolonlari:", sql("select string_agg(column_name,',') from information_schema.columns where table_name='messages'")[0])
print("sessions satiri:", sql(f"select id::text||' '||status::text from sessions where request_id='{rid}'")[0])
print("intro kaydi:", sql(f"select coalesce(intro,'(bos)') from requests where id='{rid}'")[0])

import sys as _sys


_sys.exit(_EXIT_KODU)
