#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/edge_flows_e2e.py   (v2.16'da doğdu)

MUTLU YOL DIŞINDAKİ AKIŞLAR

NEDEN VAR:
  two_account_e2e mutlu yolu koşuyor: istek → kabul → oturum → puan.
  onboarding_e2e kayıt yolunu koşuyor. İkisi de HER ŞEYİN YOLUNDA
  GİTTİĞİ durumu ölçüyor.

  Ama üretimde asıl acıtan yerler bunlar değil: reddedilen istek,
  iptal edilen buluşma, gelmeyen taraf, engellenen kullanıcı,
  şikayet, çifte istek, kendi ilanına başvurma, dolu ilan,
  geçmiş tarihli ilan, yetersiz kredi. Bunların hiçbiri test
  edilmemişti.

  Bir sistemin sağlamlığı mutlu yolda değil, REDDETME yollarında
  belli olur: yanlış şeyin OLMAMASI gerektiği yerde gerçekten
  olmuyor mu?
"""
import os
import re
import shutil
import subprocess
import pathlib

import pgserver

BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(__file__).resolve().parent.parent
# 🔴 v2.46 — SQL KLASÖRÜ ARTIK ll_paths ÜZERİNDEN ÇÖZÜLÜYOR.
# Üç E2E betiği de `ROOT/'sql'` sabitini yazıyordu. SQL klasörü rnapp'in
# içinde değilse üçü de FileNotFoundError ile çöküyordu — yani "E2E
# kırmızı" görünüyordu ama ürün değil YOL yanlıştı. ll_paths hem ortam
# değişkenini (LL_SQL_DIR) hem kardeş klasörü tanır.
import sys as _sys
_sys.path.insert(0, str(ROOT))
import ll_paths as _llp

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


ns = {}
exec(open(ROOT / 'pg_run.py').read()
     .replace("if __name__ == '__main__':\n    sys.exit(main())", ""), ns)


def build():
    ns['install_fake_extensions']()
# 🔴 v2.42 — TESTLER BIRBIRINI BOZUYORDU.
# Uc E2E de SABIT bir /tmp dizini kullaniyordu. Tek basina kosunca
# 14/14 geciyor, ustuste kosunca 9/14 dusuyordu: onceki kosudan kalan
# yarim kapanmis bir postgres, ayni veri dizinine baglaniyor.
#
# Kirilgan test, denetimin en kotu halidir: yesil yanar ama guvenilmez,
# ve bir sure sonra "yine mi takildi" deyip gormezden gelinir.
# Her kosu artik KENDI dizinini alir.
    d = pathlib.Path('/tmp/ll_edge_' + str(os.getpid()))
    _ll_temizle(d)
    if d.exists():
        shutil.rmtree(d, ignore_errors=True)
    d.mkdir(parents=True)
    srv = pgserver.get_server(d)
    uri = srv.get_uri()
    q(uri, ns['SHIM'])
    sd = pathlib.Path(_llp.sql_dir())
    order = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1),
                       0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
    for f in (sorted((x for x in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', x)), key=order)
              + sorted(x for x in os.listdir(sd) if x.startswith('SEED'))):
        q(uri, file=sd / f)
    return uri


def q(uri, sql=None, file=None, as_user=None):
    cmd = [str(BIN / 'psql'), uri, '-X', '-t', '-A']
    if as_user:
        cmd += ['-c', 'set request.jwt.claims = \'{"sub":"%s"}\'' % as_user]
    cmd += ['-v','ON_ERROR_STOP=1']
    cmd += (['-f', str(file)] if file else ['-c', sql])
    r = subprocess.run(cmd, capture_output=True, text=True, env=ENV)
    out = [l for l in r.stdout.splitlines() if l.strip() and l.strip() != 'SET']
    return ('\n'.join(out).strip(), r.stderr.strip(), r.returncode)


def main():
    uri = build()
    ok, bad = [], []

    def chk(name, cond, extra=''):
        (ok if cond else bad).append(name)
        print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra else ''))

    u = lambda mail: q(uri, f"select id from users where email='{mail}'")[0]
    HOST = u('kural1@seed.loungelink.test')      # TK Elite Plus, kurallı ilan
    HOST2 = u('kural4@seed.loungelink.test')
    G1 = u('kmisafir1@seed.loungelink.test')
    G2 = u('kmisafir2@seed.loungelink.test')
    G3 = u('kmisafir3@seed.loungelink.test')
    AV = q(uri, f"select id from availabilities where host_id='{HOST}'")[0]

    print('=== REDDETME VE SINIR AKIŞLARI ===')

    # --- 1) Kendi ilanina basvuramaz ---
    _, err, rc = q(uri, f"select public.create_request('{AV}','lounge','ben')", as_user=HOST)
    chk('1. Host kendi ilanına başvuramıyor', rc != 0, (err or 'İZİN VERDİ!')[:70])

    # --- 2) Ayni ilana iki kez istek ---
    r1, e1, c1 = q(uri, f"select public.create_request('{AV}','lounge','ilk')", as_user=G1)
    r2, e2, c2 = q(uri, f"select public.create_request('{AV}','lounge','ikinci')", as_user=G1)
    chk('2. Aynı ilana ikinci istek engellendi', c2 != 0 or r2 == r1, (e2 or r2)[:70])

    # --- 3) Reddedilen istek: kredi geri gelmeli, sohbet acilmamali ---
    import json
    rid = json.loads(r1).get('id') if r1.startswith('{') else r1
    b0, _, _ = q(uri, f"select coalesce(sum(delta),0) from credit_ledger where user_id='{G1}'")
    _, err, rc = q(uri, f"select public.respond_request('{rid}','decline')", as_user=HOST)
    chk('3. Host reddedebildi', rc == 0, err[:90])
    st, _, _ = q(uri, f"select status from requests where id='{rid}'")
    chk('4. İstek durumu declined', st == 'declined', st)
    b1, _, _ = q(uri, f"select coalesce(sum(delta),0) from credit_ledger where user_id='{G1}'")
    chk('5. Redde kredi geri iade edildi ya da hiç düşmedi', int(b1) >= int(b0), f'{b0}->{b1}')
    ses, _, _ = q(uri, f"select count(*) from sessions where request_id='{rid}'")
    chk('6. Reddedilen istekte oturum açılmadı', ses == '0', ses)

    # --- 4) Dolu ilan: slot kadar kabul, fazlasi hayir ---
    # 🔴 v2.46 — BU ADIM SAHTE YESIL VERIYORDU.
    # Eski hali iki istek olusturup ikincisinin kabulunu bekliyordu ama
    # ISTEKLERIN OLUSTUGUNU HIC DOGRULAMIYORDU. Olculdu: kmisafir2'nin
    # ESB'de seyahati yok, create_request `no_matching_trip` diyor, rb
    # BOS donuyor, sonra `respond_request('')` cagriliyor ve PostgreSQL
    # "invalid input syntax for type uuid" hatasi veriyor. rc2 != 0
    # oldugu icin adim YESIL yaniyordu.
    #
    # Yani test "kapasite kilidi calisiyor" diyordu; gercekte olculen sey
    # bos bir uuid'nin gecersiz olmasiydi. Kapasite kilidi HIC test
    # edilmemisti. Bir testin gecmesi, olcmek istedigi seyi olctugu
    # anlamina gelmez — HANGI sebeple gectigi de dogrulanmalidir.
    AV1, AP1, D1, T1, T2 = q(uri,
        "select a.id||'|'||a.airport_code||'|'||a.avail_date||'|'||a.time_from||'|'||a.time_to "
        "from availabilities a join users u on u.id=a.host_id "
        "where u.email='kural4@seed.loungelink.test' "
        "order by a.avail_date, a.time_from, a.id limit 1")[0].split('|')

    # Iki misafirin de bu ilanla ORTUSEN seyahati olmali; yoksa olculen
    # sey kapasite degil, seyahat eslesmesi olur.
    for g in (G1, G2):
        q(uri, f"""insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to)
                   select '{g}','{AP1}','ESB','{D1}','{T1}','{T2}'
                   where not exists (select 1 from visits
                     where user_id='{g}' and airport_code='{AP1}' and visit_date='{D1}')""")

    ra, ea, ca = q(uri, f"select public.create_request('{AV1}','lounge','a')", as_user=G1)
    rb, eb, cb = q(uri, f"select public.create_request('{AV1}','lounge','b')", as_user=G2)
    chk('7. Dolu-slot testinin ON KOSULU: iki istek de olustu',
        ca == 0 and cb == 0, (ea or eb or 'ikisi de olustu')[:70])
    ida = json.loads(ra).get('id') if ra.startswith('{') else ra
    idb = json.loads(rb).get('id') if rb.startswith('{') else rb
    q(uri, f"select public.respond_request('{ida}','accept')", as_user=HOST2)
    _, err2, rc2 = q(uri, f"select public.respond_request('{idb}','accept')", as_user=HOST2)
    fl, _, _ = q(uri, f"select filled||'/'||slots from availabilities where id='{AV1}'")
    # Kabul REDDEDILMELI ve reddin sebebi kapasite OLMALI — herhangi bir
    # hata degil. `fully_booked` gormezsek yesil vermiyoruz.
    chk('7b. Slot dolunca ikinci kabul engellendi (fully_booked)',
        rc2 != 0 and 'fully_booked' in err2, (err2 or 'IZIN VERDI! ' + fl)[:90])
    chk('7c. filled slots sinirini asmadi',
        int(fl.split('/')[0]) <= int(fl.split('/')[1]), fl)

    # --- 5) Engelleme: engellenen kullanici kesifte gormemeli ---
    _, err, rc = q(uri, f"insert into blocks (blocker, blocked) values ('{HOST}','{G3}')")
    chk('8. Engelleme kaydı oluştu', rc == 0, err[:70])
    n, _, _ = q(uri, f"select count(*) from discover_availabilities('IST',null,null,null) d "
                     f"where d.id='{AV}'", as_user=G3)
    chk('9. Engellenen kullanıcı ilanı görmüyor', n == '0', n)

    # --- 6) Sikayet akisi ---
    _, err, rc = q(uri, f"select public.create_report('{G3}','harassment','test')", as_user=HOST)
    chk('10. Şikayet kaydedilebiliyor', rc == 0, err[:90])

    # --- 7) Gecmis tarihli ilan kesifte cikmamali ---
    q(uri, f"""insert into availabilities (host_id, airport_code, avail_date, time_from,
               time_to, slots, filled, visibility)
               values ('{HOST}','IST', current_date - 3, '10:00','12:00',1,0,'Public')""")
    past, _, _ = q(uri, "select count(*) from discover_availabilities('IST',null,null,null) d "
                        "join availabilities a on a.id=d.id where a.avail_date < current_date",
                   as_user=G1)
    chk('11. Geçmiş tarihli ilan keşifte yok', past == '0', past)

    # --- 8) Yetersiz kredi: ucretli ilanda akis DURMAMALI ---
    # 🔴 v2.46 — 14. ADIM AYLARDIR YANLIS ILANA BAKIYORDU.
    # Eski hali "kural5 ucretli host'tur" diye VARSAYIYORDU. Olculdu:
    # kural5'in tek ilani var ve o ilanin lounge_id'si NULL — salon yok,
    # dolayisiyla venue yok, dolayisiyla paid_guest_credit() 0 donuyor.
    # 108'in "kredi yetersiz" bildirim dali `v_n <= 0` kapisinda daha
    # ilk satirda cikiyor; bildirim hic dusmuyor. Yani test bir URUN
    # hatasi bildirmiyordu, kendi varsayimini bildiriyordu.
    #
    # DERS (two_account'ta da ayni): test, olcmek istedigi sarti
    # VARSAYMAZ, SECER. Aranan sey "kural5'in ilani" degil, "tesekkur
    # kredisi > 0 olan ilan"dir. Kosul dogrudan yazilinca hem kirilganlik
    # hem yanlis teshis birlikte gidiyor.
    _paid = q(uri, "select a.id||'|'||a.host_id||'|'||a.airport_code||'|'||a.avail_date"
                   "||'|'||a.time_from||'|'||a.time_to from availabilities a "
                   "where public.paid_guest_credit(a.id) > 0 "
                   "order by a.airport_code, a.avail_date, a.time_from, a.id limit 1")[0]
    if not _paid.strip():
        print('\n🔴 ORTAM: tesekkur kredisi olan ucretli ilan yok — 12-14 kosulmadi.')
        print('   Bu bir urun hatasi degil; seed boyle bir senaryo uretmemis.')
        raise SystemExit(2)
    PAID, PHOST, PAPT, PD, PT1, PT2 = [x.strip() for x in _paid.split('|')[:6]]
    # 🔴 Kabulu YAPACAK olan, ilanin GERCEK host'udur. Eski kod burada da
    # kural5'i sabit yaziyordu; ilan koşula gore secilince kabul
    # `not_host` ile dusuyordu — yani 13. adim da ayni varsayimin
    # uzerinde duruyormus.
    # 🔴 SQL 283 (iç/dış hat boyutu) bu adımı kırdı: varış 'ESB' yazılıydı,
    # yani İÇ HAT uçuşuyla DIŞ HAT salonuna istek — motor artık bunu
    # kapıda değil burada durduruyor (scope_mismatch) ve 12. adım
    # insufficient_credits yerine o hatayı görüyordu. Test yanlıştı,
    # motor doğru. Bu adım KREDİYİ ölçüyor; varış boş bırakılır ("bilinmiyor"
    # engel değildir) ki yalnız kredi kapısı konuşsun.
    q(uri, f"""insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to)
               select '{G2}','{PAPT}',null,'{PD}','{PT1}','{PT2}'
               where not exists (select 1 from visits
                 where user_id='{G2}' and airport_code='{PAPT}' and visit_date='{PD}')""")
    q(uri, f"update visits set destination = null where user_id='{G2}' and airport_code='{PAPT}' and visit_date='{PD}'")
    q(uri, f"delete from credit_ledger where user_id='{G2}'")   # bakiye sifir
    rp, ep, cp = q(uri, f"select public.create_request('{PAID}','lounge','ucretli')", as_user=G2)
    # 🔴 TEST VARSAYIMIM YANLISTI: kredisiz misafirin istek GONDEREBILMESINI
    # bekledim. Urun `insufficient_credits` diyor ve BU DOGRU — kredi
    # istegin para birimi; kredisiz istek gondermek, bedava spam demektir.
    # 108'deki "kredi yetmezse akisi durdurma" dali baska bir durum icin:
    # istek gonderildikten SONRA bakiye duserse kabul yine de gecerli olur.
    chk('12. Kredisiz misafir istek GÖNDEREMİYOR (doğru)',
        cp != 0 and 'insufficient_credits' in ep, (ep or 'izin verdi!')[:70])
    # 108'in "bakiye sonradan dustu" dali: istek varken krediyi sifirla
    if cp != 0:
        q(uri, f"insert into credit_ledger (user_id, delta, reason, balance_after) "
               f"values ('{G2}', 5, 'test-topup', 5)")
        # 🔴 SQL 246 "ayni anda kac acik istegin olabilir" tavani getirdi
        # ve bu test onceki adimlardan kalan bekleyen istekle tavana
        # takildi. Tavan DOGRU; testin o dunyada kendini kurmasi gerek.
        # Bekleyen istekleri temizliyorum — bu adimin olcmek istedigi sey
        # tavan degil, "kredisi yetmeyen misafirin kabul akisi".
        q(uri, f"update requests set status='cancelled' "
               f"where guest_id='{G2}' and status='pending'")
        rp, ep, cp = q(uri, f"select public.create_request('{PAID}','lounge','ucretli')", as_user=G2)
        q(uri, f"delete from credit_ledger where user_id='{G2}'")
    # 🔴 ESKI HALI `if cp == 0:` idi ve else DALI YOKTU: istek olusmazsa
    # 13 ve 14 hic calismiyor, hic yazilmiyor, toplam sayidan da dusuyordu.
    # Sessizce atlanan bir adim, kirmizi bir adimdan daha tehlikelidir —
    # kimse eksildigini fark etmez.
    chk('12b. Ucretli ilana istek olusturulabildi (13-14 icin on kosul)',
        cp == 0, (ep or 'olustu')[:70])
    if cp == 0:
        idp = json.loads(rp).get('id') if rp.startswith('{') else rp
        _, ea, ca = q(uri, f"select public.respond_request('{idp}','accept')", as_user=PHOST)
        chk('13. Bakiye sonradan sıfırlansa da kabul kırılmadı', ca == 0, ea[:80])
        nb, _, _ = q(uri, f"select count(*) from notifications where user_id='{G2}' "
                          "and title ilike '%yetersiz%'")
        chk('14. Kredisi yetmeyene bildirim düştü', int(nb or 0) > 0, nb)

    # --- 9) Bildirim -> push zinciri ---
    q(uri, f"""insert into push_tokens (user_id, token, platform, active)
               values ('{G1}','ExponentPushToken[test123]','android', true)
               on conflict (token) do nothing""")
    _, err, rc = q(uri, f"""insert into notifications (user_id, category, title, body)
                            values ('{G1}','requests','Test','Gövde')""")
    chk('15. Bildirim + push tetikleyicisi hata vermiyor', rc == 0, err[:110])

    # --- 10) Soru → ilan bağı (312) ---
    # 239 bu yamayı "zaten var" sanıp atlamıştı; hiçbir test ilan_kurali_sor'u
    # çağırmadığı için aylarca görünmedi (soru metni “bu” ilanına diyordu).
    # Kurulumdan sonra CANLI gövde okunur: INSERT avail_id yazmalı.
    gv, _, _ = q(uri, "select position('''pending'', p_avail_id)' in "
                      "pg_get_functiondef('public.ilan_kurali_sor(uuid)'::regprocedure)) > 0")
    chk('16. Soru ilanına bağlanıyor (ilan_kurali_sor avail_id yazıyor)', (gv or '').strip() == 't', gv)

    print(f'\n  {len(ok)} geçti · {len(bad)} başarısız')
    if bad:
        print('  BAŞARISIZ: ' + ', '.join(bad))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
