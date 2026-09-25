#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/onboarding_e2e.py   (v2.15'te doğdu)

YENİ KULLANICI AKIŞI — GERÇEK PostgreSQL'DE

NEDEN VAR:
  two_account_e2e.py var olan kullanıcılarla çalışıyor: seed hesapları
  hazır profil, hazır doğrulama, hazır krediyle geliyor. Ama gerçek bir
  kullanıcı bunların HİÇBİRİYLE gelmiyor — sıfırdan kaydoluyor.

  Kayıt akışı en kırılgan yer, çünkü tek bir tetikleyiciye bağlı:
  `on_auth_user_created`. O tetikleyici sessizce çalışmazsa kullanıcı
  Supabase'de VAR ama uygulamada YOK olur; giriş yapar, boş ekran görür
  ve sebebini kimse anlamaz. Bu testin tek işi o zinciri baştan sona
  yürümek.

  Test edilen: kayıt → users/profiles/verifications satırları →
  hoş geldin kredisi → KVKK rızaları → referans kodu → profil
  tamamlama → doğrulama → ilk seyahat → keşifte görünme.
"""
import os
import re
import shutil
import subprocess
import pathlib

import pgserver

BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
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
    d = pathlib.Path('/tmp/ll_onboard_' + str(os.getpid()))
    _ll_temizle(d)
    if d.exists():
        shutil.rmtree(d, ignore_errors=True)
    d.mkdir(parents=True)
    srv = pgserver.get_server(d)
    uri = srv.get_uri()
    run(uri, ns['SHIM'])
    sd = pathlib.Path(_llp.sql_dir())
    order = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1),
                       0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
    files = sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)),
                   key=order)
    for f in files + sorted(x for x in os.listdir(sd) if x.startswith('SEED')):
        run(uri, file=sd / f)
    return uri


def run(uri, sql=None, file=None, as_user=None):
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

    NEW = '90000001-0000-4000-8000-000000000001'
    MAIL = 'yenikullanici@seed.loungelink.test'

    print('=== YENİ KULLANICI KAYIT AKIŞI ===')

    # 1) Supabase'in yaptigi sey: auth.users'a satir
    _, err, rc = run(uri, f"""
      insert into auth.users (id, email, instance_id, aud, role, email_confirmed_at,
                              raw_app_meta_data, raw_user_meta_data)
      values ('{NEW}', '{MAIL}', '00000000-0000-0000-0000-000000000000',
              'authenticated', 'authenticated', now(),
              '{{"provider":"email"}}'::jsonb, '{{"name":"Yeni Kullanici"}}'::jsonb);""")
    chk('1. auth.users satırı oluştu', rc == 0, err[:120])

    # 2) Tetikleyici zinciri: users / profiles / verifications
    for tbl, col in (('users', 'id'), ('profiles', 'user_id'), ('verifications', 'user_id')):
        n, _, _ = run(uri, f"select count(*) from {tbl} where {col} = '{NEW}'")
        chk(f'2. {tbl} satırı tetikleyiciyle açıldı', n == '1', n)

    # 3) Hos geldin kredisi
    bal, _, _ = run(uri, f"select coalesce(sum(delta),0) from credit_ledger where user_id='{NEW}'")
    chk('3. Hoş geldin kredisi verildi', int(bal or 0) > 0, bal)

    # 4) KVKK rizalari
    # 🔴 ILK YAZIMDA YANLIS VARSAYIM: rizalarin TETIKLEYICIYLE olusmasini
    # bekledim. Oysa app kayittan hemen sonra `grant_consents` RPC'sini
    # KENDI cagiriyor (App.js:240 ve :915) — cunku kullanicinin HANGI
    # metni onayladigi istemcide belli. Testin isi, urunun akisini
    # taklit etmektir; kendi varsayimini dogrulatmak degil.
    # Imza `text[]`, jsonb DEGIL — ve app'in gonderdigi BES riza tipini
    # birebir kullaniyoruz. Testin uydurdugu bir liste, urunun gercekte
    # aldigi rizalari dogrulamaz.
    _, err, rc = run(uri,
        "select public.grant_consents("
        "array['no_lounge_sale','no_offplatform_payment','community_rules',"
        "'venue_rules','terms_privacy'], 'v15')", as_user=NEW)
    c, _, _ = run(uri, f"select count(*) from consents where user_id='{NEW}'")
    chk('4. Beş rıza tipi de kaydedildi', int(c or 0) == 5, (c or '0') + ' ' + err[:90])

    # 5) Referans kodu uretildi mi
    ref, _, _ = run(uri, f"select public.my_referral()", as_user=NEW)
    chk('5. Referans kodu üretildi', bool(ref) and 'null' not in ref.lower(), ref[:60])

    # 6) Profil tamamlama
    _, err, rc = run(uri, f"""
      update profiles set name='Yeni Kullanici', profession='Tasarim',
             bio='Merhaba', show_on_discovery=true where user_id='{NEW}';""")
    chk('6. Profil tamamlandı', rc == 0, err[:100])

    # 7) Dogrulama
    _, err, rc = run(uri, f"update verifications set phone_verified=true where user_id='{NEW}'")
    chk('7. Telefon doğrulandı', rc == 0, err[:100])

    # 8) Ilk seyahat
    _, err, rc = run(uri, f"""
      insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
      values ('{NEW}', 'IST', current_date + 2, '12:00', '18:00', 'TK712');""")
    chk('8. İlk seyahat eklendi', rc == 0, err[:120])

    # 9) Kesifte ilan gorebiliyor mu (misafir yolu)
    n, err, _ = run(uri, "select count(*) from discover_availabilities('IST',null,null,null)",
                    as_user=NEW)
    chk('9. Yeni kullanıcı keşifte ilan görüyor', int(n or 0) > 0, n or err[:100])

    # 10) Guven puani baslangici
    t, _, _ = run(uri, f"select coalesce(score::text,'yok') from trust_scores where user_id='{NEW}'")
    chk('10. Güven puanı satırı açıldı', t != 'yok' and t != '', t)

    # 11) Host olma yolu: ilan acinca rol degisiyor mu
    # 🔴 ONEMLI ON KOSUL — ilk testte KACIRDIM:
    # create_availability `no_access_source` diye reddediyor. Bu bir HATA
    # DEGIL, dogru davranis: salona nasil girdigini soylemeden ilan
    # acilamaz. Gercek akista host once Lounge Erisim ekranini dolduruyor.
    # Testin bu adimi atlamasi, urunun akisini eksik taklit etmesiydi.
    _, err, rc = run(uri, "select public.save_host_access("
                          "array['Miles&Smiles Elite Plus'], 1::smallint, false, "
                          "null::smallint, null, null::smallint, null, 'ELPL')", as_user=NEW)
    chk('11. Host erişim beyanı kaydedildi', rc == 0, err[:140])

    lg, _, _ = run(uri, "select id from lounges where airport_code='IST' and active limit 1")
    if lg:
        # ══════════════════════════════════════════════════════════════
        # 🔴 31 AĞUSTOS · BU İKİ TEST ESKİ SÖZLEŞMEYİ SINIYORDU.
        #
        # Eskiden ilan açmak kişiyi SESSİZCE host yapıyordu (055'teki
        # `update users set role='host'`). Migration 261 bunu bilerek
        # kapattı: host olmanın tek yolu AÇIK NİYET —`rolumu_sec('host')`
        # (uygulamadaki "Host ol" düğmesi) ya da onaylanmış başvuru.
        # Gerekçe 261'de yazılı: bir kullanıcıyı, bir formu doldurduğu
        # için başkasının salonuna karşı SORUMLU bir role terfi ettirmek,
        # onun vermediği bir kararı onun adına vermektir.
        #
        # Testler o değişiklikle birlikte güncellenmemişti ve `npm run e2e`
        # üç turdur kırmızı yanıyordu — yani düzelen bir davranış, bozuk
        # bir test yüzünden "hata" olarak duruyordu.
        #
        # 🆕 SINIF: "BİR DAVRANIŞI BİLEREK DEĞİŞTİRDİĞİNDE ONU SINAYAN
        # TESTİ DE DEĞİŞTİR — YOKSA SÜREKLİ KIRMIZI YANAN BİR TEST,
        # BİR SÜRE SONRA HİÇ OKUNMAYAN BİR TESTTİR."
        #
        # Artık ASIL sözleşme sınanıyor: kapı kapalı mı, ve açık niyetle
        # açılıyor mu.
        ilan = f"""select public.create_availability(
            '{lg}'::uuid, 'IST', (current_date + 2)::date, '13:00'::time, '16:00'::time,
            1, 'TK712', 'all')"""
        _, err, rc = run(uri, ilan, as_user=NEW)
        chk('12. Host OLMAYAN ilan açamaz (rol kapısı)',
            rc != 0 and 'not_a_host' in (err or ''), (err or '')[:140])
        run(uri, "select public.rolumu_sec('host')", as_user=NEW)
        _, err2, rc2 = run(uri, ilan, as_user=NEW)
        chk('13. Açık niyetle host olan ilan açabilir', rc2 == 0, (err2 or '')[:140])
        role, _, _ = run(uri, f"select role from users where id='{NEW}'")
        chk('14. rolumu_sec sonrası rol host', role == 'host', role)
    else:
        chk('12. Host OLMAYAN ilan açamaz (rol kapısı)', False, 'IST salonu yok')

    print(f'\n  {len(ok)} geçti · {len(bad)} başarısız')
    if bad:
        print('  BAŞARISIZ: ' + ', '.join(bad))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
