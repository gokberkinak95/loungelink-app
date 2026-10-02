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
import os, re, json, shutil, pathlib, subprocess, pgserver
BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(__file__).resolve().parent.parent
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


D = pathlib.Path('/tmp/ll_iptal_' + str(os.getpid()))
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
for f in sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)), key=o) + sorted(x for x in os.listdir(sd) if x.startswith('SEED')):
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', os.path.join(sd, f)],
                   capture_output=True, text=True, env=ENV)

ok, bad = [], []


def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra != '' else ''))


def bakiye(uid):
    return int(sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{uid}'")[0] or 0)


def dolu(av):
    return int(sql(f"select filled from availabilities where id='{av}'")[0] or 0)


def son_bildirim(uid):
    return sql(f"select title from notifications where user_id='{uid}' order by created_at desc, id desc limit 1")[0]


GUEST = sql("select id from users where email='kmisafir1@seed.loungelink.test'")[0]
# Misafirin istek atabildiği (kesifte görünen, kendi ilanı olmayan, slotu boş) ilanlar —
# her senaryo AYRI ilan kullanır (önceki senaryonun izi sonrakini bozmasın).
_ilanlar = sql(f"""select d.id::text || '|' || d.host_id::text
  from discover_availabilities(null,null,null,null) d
 where d.host_id <> '{GUEST}' and not coalesce(d.fully_booked,false)
   and coalesce(d.slots,0) - coalesce(d.filled,0) > 0
   and not coalesce(d.blocks_request,false)
 order by d.avail_date, d.time_from, d.id""", GUEST)[0].splitlines()
print(f"=== GERİ ALMA · İPTAL · SLOT · KREDİ (aday ilan: {len(_ilanlar)}) ===")


def istek_kabul(av, host):
    """Yeni istek + kabul; (request_id, istekten önceki bakiye) döner. Olmazsa None."""
    once = bakiye(GUEST)
    raw, err, rc = sql(f"select public.create_request('{av}','lounge','test')", GUEST)
    if rc != 0:
        return None, once, err[:90]
    try:
        rid = json.loads(raw).get('id')
    except Exception:
        rid = raw.strip().strip('"')
    _, err, rc = sql(f"select public.respond_request('{rid}','accept')", host)
    if rc != 0:
        return None, once, err[:90]
    return rid, once, ''


senaryo_ilan = iter(_ilanlar)


def sonraki():
    for s in senaryo_ilan:
        av, host = s.split('|')
        rid, once, e = istek_kabul(av, host)
        if rid:
            return av, host, rid, once
    return None, None, None, None


# ── S1 · md.5: misafir TEK TARAFLI başlattı → host kabulü geri alabilmeli ──
av, host, rid, once = sonraki()
if not rid:
    chk('S0. Senaryo için kabul edilebilir ilan bulundu', False, 'aday kalmadı')
else:
    d0 = dolu(av)
    sql(f"select public.start_session_request('{rid}')", GUEST)
    st = sql(f"select status::text || '/' || (guest_started_at is not null)::text from sessions where request_id='{rid}'")[0]
    chk('S1.1 Misafir tek taraflı başlattı → oturum hâlâ "bekliyor"', st == 'pending/true', st)
    out, err, rc = sql(f"select public.respond_request('{rid}','decline')", host)
    chk('S1.2 Host kabulü geri alabiliyor (oturum BAŞLAMADI)', rc == 0, (err or out)[:90])
    chk('S1.3 İstek reddedildi', sql(f"select status from requests where id='{rid}'")[0] == 'declined')
    chk('S1.4 Bekleyen oturum satırı kapandı', sql(f"select status from sessions where request_id='{rid}'")[0] == 'cancelled')
    chk('S1.5 Slot açıldı (dolu sayısı bir azaldı)', dolu(av) == d0 - 1, f'{d0} → {dolu(av)}')
    chk('S1.6 Misafirin kredisi TAM iade (istek öncesi bakiye)', bakiye(GUEST) == once, f'{once} → {bakiye(GUEST)}')
    b = son_bildirim(GUEST)
    chk('S1.7 Misafire "kabulü geri aldı" bildirimi (isimli)', 'kabulü geri aldı' in b, b)

# ── S2 · md.6/7: İKİ TARAF başlattı → geri alma yok; oturum iptali her şeyi açar ──
av, host, rid, once = sonraki()
if rid:
    d0 = dolu(av)
    sql(f"select public.start_session_request('{rid}')", GUEST)
    sql(f"select public.start_session_request('{rid}')", host)
    sid = sql(f"select id from sessions where request_id='{rid}'")[0]
    chk('S2.1 İki taraf da başlattı → oturum aktif', sql(f"select status from sessions where id='{sid}'")[0] == 'active')
    _, err, rc = sql(f"select public.respond_request('{rid}','decline')", host)
    chk('S2.2 Başlamış oturumda "kabulü geri al" REDDEDİLİR', rc != 0 and 'session_started' in err, err[:70])
    out, err, rc = sql(f"select public.cancel_session('{sid}','plan degisti')", host)
    chk('S2.3 Oturum iptal edilebiliyor', rc == 0, (err or out)[:90])
    chk('S2.4 İstek iptal oldu (Oturumlar\'dan düşer)', sql(f"select status from requests where id='{rid}'")[0] == 'cancelled')
    chk('S2.5 Slot açıldı — ilan yeniden başvuru alabilir', dolu(av) == d0 - 1, f'{d0} → {dolu(av)}')
    chk('S2.6 5 dk içinde iptal → misafirin kredisi iade', bakiye(GUEST) == once, f'{once} → {bakiye(GUEST)}')
    b = son_bildirim(GUEST)
    chk('S2.7 Misafire "oturumu iptal etti" bildirimi (isimli)', 'oturumu iptal etti' in b, b)
    ch = sql(f"select id from chat_channels where request_id='{rid}'")[0]
    _, err, rc = sql(f"insert into messages (channel_id, from_id, body) values ('{ch}','{GUEST}','iptalden sonra')", GUEST, rol=True)
    chk('S2.8 İptal edilmiş oturumda mesaj YAZILAMAZ (RLS, gerçek rol)', rc != 0, (err or 'YAZDI!')[:70])

# ── S3: host tek taraflı başlattı → misafir isteğini iptal edebilmeli ──
av, host, rid, once = sonraki()
if rid:
    d0 = dolu(av)
    sql(f"select public.start_session_request('{rid}')", host)
    out, err, rc = sql(f"select public.respond_request('{rid}','cancel')", GUEST)
    chk('S3.1 Misafir tek taraflı başlatılmış buluşmayı iptal edebiliyor', rc == 0, (err or out)[:90])
    chk('S3.2 Oturum satırı kapandı', sql(f"select status from sessions where request_id='{rid}'")[0] == 'cancelled')
    chk('S3.3 Slot açıldı', dolu(av) == d0 - 1, f'{d0} → {dolu(av)}')
    chk('S3.4 Kredi iade', bakiye(GUEST) == once, f'{once} → {bakiye(GUEST)}')
    b = son_bildirim(host)
    chk('S3.5 Host\'a "buluşmayı iptal etti" bildirimi', 'buluşmayı iptal etti' in b, b)

# ── S4: misafir tek taraflı başlattı → host ilanı ZORLA kaldırabilmeli ──
av, host, rid, once = sonraki()
if rid:
    out, err, rc = sql(f"select public.cancel_availability('{av}', true)", host)
    chk('S4.1 Tek taraflı başlatılmış buluşmalı ilan kaldırılabiliyor', rc == 0, (err or out)[:90])
    chk('S4.2 İstek reddedildi + oturum yok/kapalı',
        sql(f"select status from requests where id='{rid}'")[0] == 'declined'
        and sql(f"select coalesce(max(status::text),'yok') from sessions where request_id='{rid}'")[0] in ('yok', 'cancelled'))
    chk('S4.3 Kredi iade', bakiye(GUEST) == once, f'{once} → {bakiye(GUEST)}')
    b = son_bildirim(GUEST)
    chk('S4.4 Misafire "ilanını kaldırdı" bildirimi', 'ilanını kaldırdı' in b, b)
    chk('S4.5 İlan pasif', sql(f"select active from availabilities where id='{av}'")[0] == 'f')

# ── S5 · md.2/3/10: soru bir bağlantı DEĞİL ──
print("=== SORU AKIŞI ===")
uygun = sql(f"""select a.id::text || '|' || a.host_id::text from availabilities a
  where a.active and a.avail_date >= current_date and a.host_id <> '{GUEST}'
    and public.kural_sorusu_durumu(a.id) = 'uygun'
    and not exists (select 1 from connection_requests c where
        (c.from_id = '{GUEST}' and c.to_id = a.host_id) or (c.to_id = '{GUEST}' and c.from_id = a.host_id))
  order by a.avail_date, a.id limit 1""", GUEST)[0]
if not uygun:
    chk('S5.0 Soru sorulabilir ilan bulundu', False, 'yok')
else:
    av, host = uygun.split('|')
    rz = sql(f"select can_ask_host::text from public.discovery_rule_badges(array['{av}'::uuid])", GUEST)[0]
    chk('S5.1 Rozet "sorabilirsin" diyor (can_ask_host)', rz == 'true', rz)
    out, err, rc = sql(f"select public.ilan_kurali_sor('{av}')", GUEST)
    chk('S5.2 Sunucu da soruyu kabul ediyor (rozet = kapı)', rc == 0 and 'soruldu' in out, (err or out)[:90])
    qid = sql(f"select id from connection_requests where from_id='{GUEST}' and to_id='{host}' and intent='kural_sorusu'")[0]
    pa = sql("select count(*) from public.pending_actions() where id = '" + qid + "'", host)[0]
    chk('S5.3 Soru Davet ekranında DEĞİL (pending_actions)', pa == '0', pa)
    bg = sql(f"select count(*) from public.bana_gelen_sorular() where id='{qid}'", host)[0]
    chk('S5.4 Soru host\'un Soru › Gelen listesinde', bg == '1', bg)
    akis = sql("select public.ana_sayfa_akisi()", host)[0]
    try:
        aj = json.loads(akis)
    except Exception:
        aj = {}
    chk('S5.5 Host ana sayfa SORU kutusu soruyu sayıyor, BAĞLANTI saymıyor',
        aj.get('soru', 0) >= 1 and aj.get('yeni', {}).get('soru') is True, akis[:160])
    # 314 — host YAZILI yanıt verir; bağlantı kararı ayrı; kabulde sohbet SORU + YANIT ile başlar
    out, err, rc = sql(f"select public.soruya_cevap_yaz('{qid}','Kartımda +1 hakkı var, ilanıma ekliyorum.')", host)
    chk('S5.6 Host yazılı yanıt gönderebiliyor (bağlantıyı kabul etmeden)', rc == 0, (err or out)[:90])
    st = sql(f"select status::text || '/' || coalesce(cevap_notu,'') from connection_requests where id='{qid}'")[0]
    chk('S5.7 Yanıt kaydedildi, bağlantı isteği hâlâ KARAR BEKLİYOR', st.startswith('pending/Kartımda'), st)
    ch = sql(f"select count(*) from chat_channels where connection_id='{qid}'")[0]
    chk('S5.8 Bağlantı kabul edilmeden sohbet AÇILMADI', ch == '0', ch)
    sr = sql(f"select cevap_durumu || '/' || coalesce(cevap_notu,'') from public.sorularim() where id='{qid}'", GUEST)[0]
    chk("S5.9 Soran Sorduklarım'da yanıtı görüyor", sr.startswith('yanitlandi/Kartımda'), sr)
    b = son_bildirim(GUEST)
    chk('S5.10 Sorana "sorunu yanıtladı" bildirimi', 'sorunu yanıtladı' in b, b)
    _, err, rc = sql(f"select public.soruya_cevap_yaz('{qid}','ikinci yanıt')", host)
    chk('S5.11 Aynı soruya ikinci yanıt yok (already_answered)', rc != 0 and 'already_answered' in err, err[:60])
    out, err, rc = sql(f"select public.respond_connection('{qid}', true)", host)
    chk('S5.12 Host bağlantıyı kabul etti', rc == 0, (err or out)[:90])
    msj = sql(f"""select string_agg(case when m.from_id='{GUEST}' then 'soran' else 'host' end, ',' order by m.created_at)
                  from messages m join chat_channels c on c.id=m.channel_id where c.connection_id='{qid}'""")[0]
    chk('S5.13 Sohbet SORU + YANIT ile başladı', msj == 'soran,host', msj)
    out, err, rc = sql(f"select public.ilan_kurali_sor('{av}')", GUEST)
    chk('S5.14 Bağlıyken tekrar sorunca: yeni istek YOK, soru sohbete düştü', rc == 0 and 'sohbete_eklendi' in out, (err or out)[:90])
    n = sql(f"select count(*) from connection_requests where from_id='{GUEST}' and to_id='{host}'")[0]
    m3 = sql(f"select count(*) from messages m join chat_channels c on c.id=m.channel_id where c.connection_id='{qid}'")[0]
    chk('S5.15 Tek bağlantı kaydı · sohbette 3 mesaj', n == '1' and m3 == '3', f'istek={n} mesaj={m3}')

# ── S6: YENİ işareti ──
print("=== YENİ İŞARETİ ===")
H = sql("select id from users where email='kural5@seed.loungelink.test'")[0]
sql("select public.akis_goruldu_isaretle('istek')", H)
y0 = json.loads(sql("select public.ana_sayfa_akisi()", H)[0] or '{}').get('yeni', {}).get('istek')
chk('S6.1 Baktıktan sonra İstek kutusunda "yeni" yok', y0 is False, y0)
# kural5'e yeni bir istek düşür (doğrudan: işaret mantığı ölçülüyor, istek kuralları değil)
avh = sql(f"select id from availabilities where host_id='{H}' and active order by avail_date limit 1")[0]
G3 = sql("select id from users where email='kmisafir3@seed.loungelink.test'")[0]
sql(f"insert into requests (avail_id, guest_id, host_id, status, created_at) values ('{avh}','{G3}','{H}','pending', now())")
y1 = json.loads(sql("select public.ana_sayfa_akisi()", H)[0] or '{}').get('yeni', {}).get('istek')
chk('S6.2 Yeni istek gelince İstek kutusunda "yeni" yanıyor', y1 is True, y1)
once = sql("select public.akis_goruldu_isaretle('istek')", H)[0]
y2 = json.loads(sql("select public.ana_sayfa_akisi()", H)[0] or '{}').get('yeni', {}).get('istek')
chk('S6.3 Alana girince söner; önceki bakış zamanı döner (çerçeve için)', y2 is False and len(once) > 10, f'{y2} · {once}')

# ── S7: Tanış araması ──
print("=== TANIŞ ARAMASI ===")
ad = sql(f"select name from profiles where user_id='{H}'")[0]
r1 = sql(f"select count(*) from public.kisi_ara('{ad[:3]}') where user_id='{H}'", GUEST)[0]
chk('S7.1 Ada göre arama kişiyi buluyor', r1 == '1', f'"{ad[:3]}" → {r1}')
r2 = sql("select count(*) from public.kisi_ara('a')", GUEST)[0]
chk('S7.2 Tek harfle arama yapılmıyor (dizin taraması yok)', r2 == '0', r2)
r3 = sql(f"select count(*) from public.kisi_ara('{ad[:3]}') where user_id='{GUEST}'", GUEST)[0]
chk('S7.3 Kişi kendini bulmuyor', r3 == '0', r3)
_, err, rc = sql("select public.kisi_ara('ab')")
chk('S7.4 Oturumsuz arama reddedilir', rc != 0, err[:60])

print(f'\n  {len(ok)} geçti · {len(bad)} başarısız')
if bad:
    print('  BAŞARISIZ: ' + ', '.join(bad))
raise SystemExit(1 if bad else 0)
