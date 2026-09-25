#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/rule_dims_e2e.py   (v4.15'te doğdu)

KURAL MOTORU · ON İKİ BOYUT + GERİ BİLDİRİM DÖNGÜSÜ (SQL 283 + 284)

NEDEN VAR:
  3. geçiş karnesi motorun "hiç sormadığı 12 boyut" saydı. 283 onları
  sordu, 284 kapı reddini motora geri verdi. Bu dosya her boyutu
  CANLI bir senaryoyla kanıtlar: sunucu kapısı (create_request), ekran
  kapısı (pregate) ve ekran satırları (kural_kosullari) ÜÇÜ DE aynı
  şeyi söylüyor mu?

  Bir kuralı yazmak yetmez; yanlış girdiyle KAPININ KAPANDIĞINI ve
  doğru girdiyle AÇILDIĞINI ölçmek gerekir. Her boyut için ikisi de
  ölçülüyor.
"""
import os, re, json, shutil, subprocess, pathlib, sys
import pgserver

BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import ll_paths as _llp


def _ll_temizle(_d):
    import atexit, glob as _g, shutil as _s, pathlib as _p, re as _r
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
    d = pathlib.Path('/tmp/ll_ruledims_' + str(os.getpid()))
    _ll_temizle(d)
    if d.exists():
        shutil.rmtree(d, ignore_errors=True)
    d.mkdir(parents=True)
    srv = pgserver.get_server(d)
    uri = srv.get_uri()
    q(uri, ns['SHIM'])
    sd = pathlib.Path(_llp.sql_dir())
    # Göç listesi TEK KAYNAKTAN: sql/pg_run.py files() (RAPOR dosyalarını atlar)
    import importlib.util as _iu
    _spec = _iu.spec_from_file_location('_pgrun', os.path.join(sd, 'pg_run.py'))
    _pg = _iu.module_from_spec(_spec); _spec.loader.exec_module(_pg)
    for f in ([b for _n, b, _p in _pg.files()]
              + sorted(x for x in os.listdir(sd) if x.startswith('SEED'))):
        out, err, rc = q(uri, file=sd / f)
        if rc != 0:
            print('!! SQL düştü:', f, err[-400:])
            sys.exit(2)
    return uri


def q(uri, sql=None, file=None, as_user=None):
    cmd = [str(BIN / 'psql'), uri, '-X', '-t', '-A']
    if as_user:
        cmd += ['-c', 'set request.jwt.claims = \'{"sub":"%s"}\'' % as_user]
    cmd += ['-v', 'ON_ERROR_STOP=1']
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

    def J(s):
        try: return json.loads(s)
        except Exception: return {}

    u = lambda mail: q(uri, f"select id from users where email='{mail}'")[0]
    HOST = u('kural1@seed.loungelink.test')      # TK Elite Plus · IST dış hat · TK712
    HOST14 = u('kural14@seed.loungelink.test')   # BUSINESS_TICKET
    G1 = u('kmisafir1@seed.loungelink.test')     # TK712, aynı uçuş
    AV = q(uri, f"select id from availabilities where host_id='{HOST}' order by avail_date limit 1")[0]
    AV14 = q(uri, f"select id from availabilities where host_id='{HOST14}' order by avail_date limit 1")[0]
    AP, D = q(uri, f"select airport_code||'|'||avail_date from availabilities where id='{AV}'")[0].split('|')
    VIS = q(uri, f"select id from visits where user_id='{G1}' and airport_code='{AP}' and visit_date='{D}' order by created_at desc limit 1")[0]
    chk('0. Ön koşul: kural1 ilanı + kmisafir1 seyahati var', bool(AV) and bool(VIS), f'av={AV[:8]} vis={VIS[:8]}')

    dec = lambda: J(q(uri, f"select public.lounge_access_decision_v6('{AV}', 'TK712', 'TK', '{VIS}')")[0])
    pre = lambda: J(q(uri, f"select public.request_precheck('{AV}')", as_user=G1)[0])
    rows = lambda av=None: [l.split('|') for l in q(uri, f"select sira||'|'||kod||'|'||durum||'|'||agirlik||'|'||metin from public.kural_kosullari('{av or AV}') order by sira", as_user=G1)[0].splitlines()]
    def row(kod, av=None):
        for r in rows(av):
            if r[1] == kod: return r
        return None

    print('=== 1 · TEMEL: motor v6, satırlar ≥ 8 ===')
    d = dec()
    chk('1. Karar v6 imzalı', d.get('engine') == 'v6', d.get('engine'))
    chk('2. Temel senaryoda sert engel yok', d.get('block_code') is None, d.get('block_code'))
    r = rows()
    chk('3. kural_kosullari ≥ 8 satır', len(r) >= 8, len(r))
    chk('4. kişi sayısı satırı var ve ok', (row('kisi_sayisi') or [None]*3)[2] == 'ok', row('kisi_sayisi'))
    chk('5. hat satırı var', row('hat') is not None, row('hat'))
    chk('6. güncellik satırı var', row('guncellik') is not None, row('guncellik'))
    chk('7. biniş kartı satırı ok (TK712 aynı gün)', (row('binis_karti') or [None]*3)[2] == 'ok', row('binis_karti'))

    print('=== 2 · KİŞİ SAYISI (283/1) ===')
    lim = int(d.get('party_limit') or 0)
    o, e, rc = q(uri, f"select public.set_visit_party('{VIS}', {lim + 2}, null)", as_user=G1)
    chk('8. set_visit_party çalıştı', rc == 0, e[:80])
    d = dec()
    chk('9. Hak aşılınca block_code=party_too_big', d.get('block_code') == 'party_too_big', d.get('block_code'))
    chk('10. Ekran satırı "yok"', (row('kisi_sayisi') or [None]*3)[2] == 'yok', row('kisi_sayisi'))
    p = pre()
    chk('11. Pregate can_request=false + block_code', p.get('can_request') is False and p.get('block_code') == 'party_too_big', (p.get('can_request'), p.get('block_code')))
    o, e, rc = q(uri, f"select public.create_request('{AV}','lounge','üç kişiyiz')", as_user=G1)
    chk('12. create_request SUNUCUDA durdu (party_too_big)', rc != 0 and 'party_too_big' in e, (e or 'İZİN VERDİ')[:80])
    o, e, rc = q(uri, f"select public.set_visit_party('{VIS}', 9, null)", as_user=G1)
    chk('13. 9 kişi reddedildi (party_size_invalid)', rc != 0 and 'party_size_invalid' in e, e[:60])
    q(uri, f"select public.set_visit_party('{VIS}', 1, null)", as_user=G1)
    chk('14. 1 kişiye dönünce engel kalktı', dec().get('block_code') is None)

    print('=== 3 · ÇOCUK (283/2) ===')
    VEN, PRG = q(uri, f"select coalesce(venue_id::text,'')||'|'||coalesce(program_id::text,'') from (select (public.lounge_access_decision_prebase('{AV}')->>'venue_id')::uuid venue_id, (public.lounge_access_decision_prebase('{AV}')->>'program_id')::uuid program_id) t")[0].split('|')
    chk('15. Ön koşul: salon×program çözüldü', bool(VEN) and bool(PRG), f'{VEN[:8]}·{PRG[:8]}')
    q(uri, f"select public.set_visit_party('{VIS}', 2, '{{2}}'::smallint[])", as_user=G1)
    d = dec()
    chk('16. Politika bilinmiyorken çocuk "bilinmiyor" (uydurmuyor)', d.get('children_ok') is None and d.get('block_code') in (None, 'party_too_big'), (d.get('children_ok'), d.get('block_code')))
    chk('17. Çocuk satırı bilinmiyor', (row('cocuk') or [None]*3)[2] == 'bilinmiyor', row('cocuk'))
    q(uri, f"insert into lounge_venue_acceptance (venue_id, program_id, accepted, guest_policy, guest_included_count) values ('{VEN}','{PRG}',true,'included',1) on conflict (venue_id, program_id) do nothing")
    q(uri, f"update lounge_venue_acceptance set children_policy='age_limit', child_age_limit=12 where venue_id='{VEN}' and program_id='{PRG}'")
    d = dec()
    chk('18. 12 yaş sınırı + 2 yaş → children_not_allowed', d.get('block_code') == 'children_not_allowed', d.get('block_code'))
    q(uri, f"update lounge_venue_acceptance set children_policy='free_under', child_age_limit=6 where venue_id='{VEN}' and program_id='{PRG}'")
    d = dec()
    chk('19. free_under 6: çocuk haktan sayılmıyor, 2 kişi geçer', d.get('children_ok') is True and d.get('party_ok') is True and d.get('block_code') is None, (d.get('children_ok'), d.get('party_ok'), d.get('block_code')))
    q(uri, f"update lounge_venue_acceptance set children_policy=null, child_age_limit=null where venue_id='{VEN}' and program_id='{PRG}'")
    q(uri, f"select public.set_visit_party('{VIS}', 1, null)", as_user=G1)

    print('=== 4 · İÇ HAT / DIŞ HAT (283/7) ===')
    scope = q(uri, f"select coalesce(scope,'?') from lounge_venues where id='{VEN}'")[0]
    q(uri, f"update lounge_venues set scope='international' where id='{VEN}'")
    q(uri, f"update visits set destination='ESB' where id='{VIS}'")
    d = dec()
    chk('20. Dış hat salonu + iç hat uçuşu → scope_mismatch', d.get('block_code') == 'scope_mismatch', (d.get('guest_side'), d.get('block_code')))
    chk('21. Hat satırı "yok"', (row('hat') or [None]*3)[2] == 'yok', row('hat'))
    q(uri, f"update visits set destination='LHR' where id='{VIS}'")
    d = dec()
    chk('22. LHR → dış hat → geçer', d.get('scope_ok') is True and d.get('block_code') is None, (d.get('guest_side'), d.get('scope_ok')))
    q(uri, f"update visits set destination=null where id='{VIS}'")
    d = dec()
    chk('23. Varış yoksa "bilinmiyor" (engel değil)', d.get('scope_ok') is None and d.get('block_code') is None)
    q(uri, f"update lounge_venues set scope={'null' if scope=='?' else repr(scope)} where id='{VEN}'")
    q(uri, f"update visits set destination='LHR' where id='{VIS}'")

    print('=== 5 · HOST KOTASI (283/12) ===')
    q(uri, f"update host_entitlements set quota_total=1, quota_period='year', quota_used=1, quota_period_start=date_trunc('year',current_date)::date where user_id='{HOST}' and program_id='{PRG}'")
    d = dec()
    chk('24. Kota bitmiş → quota_exhausted', d.get('block_code') == 'quota_exhausted', d.get('block_code'))
    chk('25. Kota satırı "yok"', (row('host_kotasi') or [None]*3)[2] == 'yok', row('host_kotasi'))
    q(uri, f"update host_entitlements set quota_used=0 where user_id='{HOST}' and program_id='{PRG}'")
    d = dec()
    chk('26. Kota 0/1 → geçer, satır ok', d.get('block_code') is None and (row('host_kotasi') or [None]*3)[2] == 'ok', row('host_kotasi'))

    print('=== 6 · BİLET SINIFI (283/11) ===')
    d14 = J(q(uri, f"select public.lounge_access_decision_v6('{AV14}')")[0])
    chk('27. Bilet sınıfı programında cabin_required', d14.get('cabin_required') is True, d14.get('cabin_required'))
    q(uri, f"update availabilities set cabin_class='economy' where id='{AV14}'")
    d14 = J(q(uri, f"select public.lounge_access_decision_v6('{AV14}')")[0])
    chk('28. Ekonomi → cabin_required engeli', d14.get('block_code') == 'cabin_required', d14.get('block_code'))
    q(uri, f"update availabilities set cabin_class='business' where id='{AV14}'")
    d14 = J(q(uri, f"select public.lounge_access_decision_v6('{AV14}')")[0])
    chk('29. Business → engel yok', d14.get('block_code') is None and d14.get('cabin_ok') is True)

    print('=== 7 · TAM AKIŞ + KOTA TÜKETİMİ + GERİ BİLDİRİM (284) ===')
    raw, e, rc = q(uri, f"select public.create_request('{AV}','lounge','Merhaba')", as_user=G1)
    chk('30. İstek oluştu', rc == 0, e[:80])
    rid = J(raw).get('id') if raw.startswith('{') else raw
    q(uri, f"select public.respond_request('{rid}','accept')", as_user=HOST)
    q(uri, f"select public.start_session_request('{rid}')", as_user=HOST)
    q(uri, f"select public.start_session_request('{rid}')", as_user=G1)
    sid = q(uri, f"select id from sessions where request_id='{rid}'")[0]
    chk('31. Oturum açıldı', bool(sid), sid[:8])
    q(uri, f"select public.confirm_session('{sid}')", as_user=HOST)
    q(uri, f"select public.confirm_session('{sid}')", as_user=G1)
    st = q(uri, f"select status from sessions where id='{sid}'")[0]
    chk('32. Oturum completed', st == 'completed', st)
    used = q(uri, f"select quota_used from host_entitlements where user_id='{HOST}' and program_id='{PRG}'")[0]
    chk('33. Tamamlanan oturum host kotasını düşürdü (0→1)', used == '1', used)

    # Kapı reddi → şüphe (misafir bildirir; oturum tamamlandı ama 24 saat penceresi içinde)
    o, e, rc = q(uri, f"select public.kapida_giremedim('{sid}','kural_tutmadi','Kapıda kartı kabul etmediler')", as_user=G1)
    chk('34. kapida_giremedim çalıştı', rc == 0 and J(o).get('ok') is True, (e or o)[:80])
    n = q(uri, f"select count(*) from kural_supheleri where session_id='{sid}' and durum='acik'")[0]
    chk('35. Şüphe YAN TABLOYA düştü', n == '1', n)
    g = J(q(uri, f"select public.kural_guncelligi('{VEN}','{PRG}')")[0])
    chk('36. kural_guncelligi = supheli', g.get('durum') == 'supheli', g)
    d = dec()
    chk('37. v6 en az UYARI + freshness taşıyor', d.get('severity') in ('warn','block') and (d.get('freshness') or {}).get('durum') == 'supheli', (d.get('severity'), (d.get('freshness') or {}).get('durum')))
    chk('38. Güncellik satırı "yok" (doğrulanıyor)', (row('guncellik') or [None]*3)[2] == 'yok', row('guncellik'))
    # Kural tablolarına dokunulmadı
    touched = q(uri, f"select count(*) from pg_trigger where tgrelid in ('lounge_guest_rules'::regclass,'lounge_programs'::regclass,'lounge_venue_acceptance'::regclass) and tgname like '%suphe%'")[0]
    chk('39. Kural tablolarında şüphe tetikleyicisi YOK', touched == '0', touched)
    o, e, rc = q(uri, "select has_table_privilege('authenticated','kural_supheleri','select') or has_table_privilege('anon','kural_supheleri','select')")
    chk('40. Misafir/anon yan tabloyu okuyamıyor (yetki yok)', o == 'f', o)
    # BO kuyruğu ve karar
    ku = J(q(uri, "select public.bo_kural_suphe_kuyrugu('acik', 50)")[0])
    chk('41. BO kuyruğunda 1 salon×program', isinstance(ku, list) and len(ku) == 1 and int(ku[0].get('acik', 0)) == 1, len(ku) if isinstance(ku, list) else ku)
    o, e, rc = q(uri, f"select public.bo_kural_suphe_karar('{VEN}','{PRG}','dogrulandi','Kaynak yeniden okundu, kural doğru')")
    chk('42. BO kararı: dogrulandi', rc == 0 and J(o).get('kapatilan') == 1, (e or o)[:80])
    g = J(q(uri, f"select public.kural_guncelligi('{VEN}','{PRG}')")[0])
    chk('43. Karardan sonra güncellik = dogrulandi, gün=0', g.get('durum') == 'dogrulandi' and g.get('gun') == 0, g)
    ca = q(uri, f"select checked_at = current_date from lounge_venue_acceptance where venue_id='{VEN}' and program_id='{PRG}'")[0]
    chk('44. Yalnız METAVERİ yazıldı (checked_at=bugün), politika aynı', ca == 't', ca)
    pol = q(uri, f"select guest_policy||'/'||guest_included_count from lounge_venue_acceptance where venue_id='{VEN}' and program_id='{PRG}'")[0]
    chk('45. guest_policy/included değişmedi', pol == 'included/1', pol)
    o, e, rc = q(uri, f"select public.bo_kural_suphe_karar('{VEN}','{PRG}','olmayan', null)")
    chk('46. Geçersiz karar reddedildi', rc != 0 and 'gecersiz_durum' in e, e[:50])
    o, e, rc = q(uri, f"select public.bo_kural_suphe_karar('{VEN}','{PRG}','dogrulandi', null)", as_user=G1)
    chk('47. Misafir BO kararı veremez', rc != 0, (e or 'İZİN VERDİ')[:60])

    print('=== 8 · ANLAŞMAZLIK (open_dispute artık canlı) ===')
    o, e, rc = q(uri, f"select public.open_dispute('{sid}','gelmedi','Yarım saat bekledim')", as_user=HOST)
    chk('48. Host anlaşmazlık açtı', rc == 0 and J(o).get('ok') is True, (e or o)[:80])
    o, e, rc = q(uri, f"select public.open_dispute('{sid}','gelmedi','tekrar')", as_user=HOST)
    chk('49. İkinci açılış engellendi (dispute_already_open)', rc != 0 and 'dispute_already_open' in e, e[:60])
    o, e, rc = q(uri, f"select public.open_dispute('{sid}','saçma','x')", as_user=G1)
    chk('50. Geçersiz sebep reddedildi', rc != 0 and 'dispute_reason_invalid' in e, e[:60])
    n = q(uri, f"select count(*) from disputes where session_id='{sid}' and status='open'")[0]
    chk('51. disputes tablosunda 1 açık kayıt (BO sayfası artık boş değil)', n == '1', n)

    print('=== 9 · SAHA RAPORU → ŞÜPHE (284/4) ===')
    # yeni bir oturum yerine mevcut oturuma HOST raporu (kapı reddi zaten şüphe açtı → ikinci kayıt AÇILMAMALI)
    n0 = q(uri, "select count(*) from kural_supheleri")[0]
    q(uri, f"select public.submit_field_report('{sid}'::uuid, false, false, null, null, null, 'kapıda çevrildik')", as_user=HOST)
    n1 = q(uri, "select count(*) from kural_supheleri")[0]
    # şüphe 'dogrulandi'ye kapatıldığı için oturumun AÇIK şüphesi yok → yeni kayıt açılır
    chk('52. Saha raporu (refused) yeni şüphe açtı', int(n1) == int(n0) + 1 and q(uri, f"select kaynak from kural_supheleri where session_id='{sid}' order by created_at desc limit 1")[0] == 'saha_raporu', f'{n0}->{n1}')

    print('=== 10 · KATALOG: bilinmeyenler talebe göre ===')
    b = J(q(uri, "select public.bo_kural_bilinmeyenler(20)")[0])
    chk('53. bo_kural_bilinmeyenler liste döndü', isinstance(b, list), type(b).__name__)
    chk('54. Liste talebe göre azalan', all(int(b[i]['talep']) >= int(b[i+1]['talep']) for i in range(len(b)-1)) if isinstance(b, list) and len(b) > 1 else True)

    print(f'\n{len(ok)} geçti · {len(bad)} düştü')
    if bad:
        print('DÜŞENLER:', *bad, sep='\n  - ')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
