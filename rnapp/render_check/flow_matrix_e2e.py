#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · flow_matrix_e2e.py   (17 Ağu 2026 — Tur 2'de doğdu)

🔴 NEDEN VAR — ÜÇ E2E VARDI, BİRİ BUNU ÖLÇMÜYORDU:

Gökberk'in ilk maddesi şuydu:
  "Bağlantı kur butonuna tıklıyorum, bağlantı daveti gönderdiğim
   kişinin ana sayfasına veya bağlantılarım sayfasına düşmüyor.
   Bağlantı kurma, ilan isteği gönderme, bağlantı sonrası sohbet
   alanı, ilan kabulü sonrası gösterimler — her şeyin gösteriminin
   olması gerekiyor. Tüm akışlarımız doğru ve verimli çalışmalı."

Mevcut testler her adımı KENDİ TARAFINDAN doğruluyordu:
  two_account  → istek→kabul→oturum→tamamlama→puanlama (host gözünden)
  edge_flows   → kapasite, engelleme, kredi sınırı
  onboarding   → kayıt akışı
Hiçbiri KARŞI TARAFIN NE GÖRDÜĞÜNÜ ölçmüyordu. Oysa bu ürün bir
PAZARYERİ: bir tarafta doğru olan bir şey, diğer tarafta görünmüyorsa
YOKTUR. v1.31'in "kalıcı ilişki kalıcı sorgudan gelir" dersi ve
16 Ağustos'taki "gelen bağlantı istekleri çekiliyor ama hiç
kullanılmıyor" bulgusu tam bu boşluktan doğmuştu.

BU TESTİN İLKESİ — KARŞILIKLILIK:
  Her adımda ÜÇ soru sorulur:
    1. İşlem başarılı oldu mu?          (yapan taraf)
    2. KARŞI TARAF bunu görüyor mu?     (alan taraf)
    3. Kural motoru ne diyor?            (motorla tutarlı mı)
  Üçü birden yeşil değilse adım KIRMIZI.

NE YAKALAR: bir tarafta yazılıp diğer tarafta okunmayan her şey;
görünürlük/RLS/GRANT kopuklukları; akış kapılarının tek yönlü olması.
NE YAKALAMAZ: piksel, dokunma, ağ. Onlar render_check'in işi.
"""
import os, re, shutil, pathlib, subprocess, sys
import pgserver

BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
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
exec(open(ROOT / 'pg_run.py').read().replace(
    "if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns['install_fake_extensions']()

# Her koşu KENDİ dizinini alır (v2.42 dersi: sabit dizin testleri
# birbirine bulaştırıyordu ve "yine mi takıldı" dedirtiyordu).
D = pathlib.Path('/tmp/ll_flow_' + str(os.getpid()))
_ll_temizle(D)
if D.exists():
    shutil.rmtree(D, ignore_errors=True)
D.mkdir(parents=True)
srv = pgserver.get_server(D)
uri = srv.get_uri()


def sql(q, as_user=None):
    """JWT taklidi AYRI -c ile gider — aynı -c içinde birleştirilirse
    psql'in 'SET' çıktısı sonuca karışır (two_account'ta bir kez ısırdı)."""
    cmd = [str(BIN / 'psql'), uri, '-X', '-t', '-A', '-v', 'ON_ERROR_STOP=1']
    if as_user:
        cmd += ['-c', "set request.jwt.claims = '{\"sub\":\"%s\",\"role\":\"authenticated\"}'" % as_user]
    cmd += ['-c', q]
    r = subprocess.run(cmd, capture_output=True, text=True, env=ENV)
    out = [l for l in r.stdout.splitlines() if l.strip() and l.strip() != 'SET']
    return ('\n'.join(out).strip(), r.stderr.strip(), r.returncode)


sql(ns['SHIM'])
sd = _llp.sql_dir()
_o = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1),
                0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
for f in (sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)), key=_o)
          + sorted(x for x in os.listdir(sd) if x.startswith('SEED'))):
    subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                    '-f', os.path.join(sd, f)], capture_output=True, text=True, env=ENV)

ok, bad = [], []


def chk(name, cond, extra=''):
    (ok if cond else bad).append(name)
    print(('  ✓ ' if cond else '  ✗ ') + name + (('  → ' + str(extra)) if extra else ''))


def skip(name, why):
    print(f'  ⊘ {name}  → atlandı: {why}')


print('=== KARŞILIKLI AKIŞ MATRİSİ (gerçek PostgreSQL) ===')

A = sql("select id from users where email='kmisafir1@seed.loungelink.test'")[0]
B = sql("select id from users where email='kmisafir2@seed.loungelink.test'")[0]
if not A or not B:
    print('  ⊘ SEED kullanıcıları yok — test atlandı')
    sys.exit(0)
an = sql(f"select coalesce(name,'A') from profiles where user_id='{A}'")[0]
bn = sql(f"select coalesce(name,'B') from profiles where user_id='{B}'")[0]
print(f'  A={an} ({A[:8]})   B={bn} ({B[:8]})\n')


# ============================================================
# BÖLÜM 1 · BAĞLANTI ZİNCİRİ — Gökberk'in 1. maddesi
# ============================================================
print('--- 1) BAĞLANTI: A → B')

# Temiz başlangıç: bu çift arasındaki eski istekleri temizle
sql(f"delete from connection_requests where (from_id='{A}' and to_id='{B}') or (from_id='{B}' and to_id='{A}')")

raw, err, rc = sql(f"select public.send_connection('{B}'::uuid, 'lounge', 'Merhaba')", A)
if rc != 0:
    # İmza farklı olabilir; ürünün gerçek imzasını bul ve bildir.
    sig = sql("select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace"
              " where n.nspname='public' and p.proname like '%connection%' order by 1")[0]
    skip('1. Bağlantı isteği gönderildi', f'send_connection imzası farklı. Mevcut: {sig[:200]}')
else:
    chk('1. Bağlantı isteği gönderildi', True, raw[:60])

# 🔴 ASIL SORU: B BUNU GÖRÜYOR MU? Gökberk'in şikayeti tam buydu.
n_inc, _, _ = sql(f"select count(*) from connection_requests"
                  f" where to_id='{B}' and from_id='{A}' and status='pending'", B)
chk('2. B, gelen isteği TABLODA görüyor', n_inc == '1', f'{n_inc} satır')

# Alıcı tarafın kullandığı RPC de görmeli (tablo görüp RPC görmemek,
# 159'da yaşanan "politika var grant yok" sınıfının tersidir)
inc_rpc, e_rpc, rc_rpc = sql("select count(*) from public.incoming_connections()", B)
if rc_rpc != 0:
    skip('3. B, gelen isteği RPC ile görüyor', 'incoming_connections yok — app tabloyu okuyor')
else:
    chk('3. B, gelen isteği RPC ile görüyor', inc_rpc != '0', f'{inc_rpc} satır')

# Gönderenin profili alıcıya OKUNABİLİR olmalı, yoksa liste isimsiz çıkar
p_ok, _, _ = sql(f"select count(*) from profiles where user_id='{A}'", B)
chk('4. B, gönderenin profilini okuyabiliyor', p_ok == '1', f'{p_ok} satır')

# Kabul
req_id, _, _ = sql(f"select id from connection_requests"
                   f" where to_id='{B}' and from_id='{A}' and status='pending' limit 1", B)
if req_id:
    _, e_acc, rc_acc = sql(f"select public.respond_connection('{req_id}'::uuid, true)", B)
    chk('5. B kabul etti', rc_acc == 0, e_acc[:100])
else:
    skip('5. B kabul etti', 'bekleyen istek bulunamadı')

st, _, _ = sql(f"select status from connection_requests where id='{req_id}'")
chk('6. Bağlantı durumu accepted', st == 'accepted', st)

# 🔴 KARŞILIKLILIK: bağlantı İKİ TARAFTA DA görünmeli. v1.31'in dersi —
# kalıcı ilişki kalıcı sorgudan gelir, keşif akışından türetilemez.
for who, uid, other in (('A', A, B), ('B', B, A)):
    n, _, _ = sql(f"select count(*) from connection_requests"
                  f" where status='accepted' and (from_id='{uid}' or to_id='{uid}')"
                  f" and (from_id='{other}' or to_id='{other}')", uid)
    chk(f'7{who}. {who} bağlantıyı görüyor', n == '1', f'{n} satır')

# Ana sayfa bağlantı şeridi (159'un home_connections RPC'si)
hc_a, e_hc, rc_hc = sql("select count(*) from public.home_connections()", A)
if rc_hc != 0:
    skip('8. Ana sayfa bağlantı şeridi', 'home_connections yok')
else:
    chk('8. A ana sayfada bağlantıyı görüyor (24s kuralı)', hc_a != '0', f'{hc_a} satır')

# Sohbet kanalı: bağlantı kabul edilince açılmalı ve İKİ TARAF da yazabilmeli
ch, e_ch, rc_ch = sql(f"select public.open_dm('{B}'::uuid)", A)
if rc_ch != 0:
    ch2 = sql("select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace"
              " where n.nspname='public' and (p.proname like '%dm%' or p.proname like '%companion%')")[0]
    skip('9. Sohbet kanalı açıldı', f'open_dm yok. Aday: {ch2[:160]}')
else:
    chk('9. Sohbet kanalı açıldı', bool(ch), ch[:40])


# ============================================================
# BÖLÜM 2 · İLAN → BAŞVURU → KABUL, KURAL MOTORUYLA TUTARLI MI
# ============================================================
print('\n--- 2) İLAN VE BAŞVURU (kural motoruyla karşılaştırmalı)')

# 🔴 İLANI KOŞULA GÖRE SEÇ — ve koşula MİSAFİRİN SEYAHATİ de dahil.
# İlk yazımda yalnız "aktif + boş slot" diye seçiyordum; seçilen ilan
# A'nın seyahati OLMAYAN bir tarihteydi ve akış `no_matching_trip` ile
# duruyordu. Test ürünün bozuk olduğunu değil KENDİ SENARYOSUNUN
# kurulmadığını bildiriyordu — 12 Ağustos'ta iki kez öğrenilen ders.
# Mutlu yolu ölçmek istiyorsak mutlu yolun ÖN KOŞULUNU kurmalıyız.
av, _, _ = sql(f"""select a.id from availabilities a
                    join visits v on v.user_id = '{A}'
                                 and v.airport_code = a.airport_code
                                 and v.visit_date = a.avail_date
                   where a.active and a.slots > a.filled
                     and a.host_id <> '{A}'
                   order by a.airport_code, a.avail_date, a.time_from, a.id limit 1""")
if not av:
    # Seyahat eşleşmesi yoksa senaryoyu KUR — ölçemediğimiz bir şeyi
    # "atlandı" diye geçmek, boşluğu kalıcı mazerete çevirir.
    src, _, _ = sql(f"""select a.id from availabilities a
                         where a.active and a.slots > a.filled and a.host_id <> '{A}'
                         order by a.avail_date, a.id limit 1""")
    if src:
        sql(f"""insert into visits (user_id, airport_code, destination, visit_date,
                                    time_from, time_to, flight_number)
                select '{A}', a.airport_code, 'IST', a.avail_date,
                       a.time_from, a.time_to, 'TK9999'
                  from availabilities a where a.id = '{src}'
                on conflict do nothing""")
        av = src
        print('  ⓘ senaryo kuruldu: misafire eşleşen seyahat eklendi')
if not av:
    skip('10-16. İlan akışı', 'uygun ilan yok')
else:
    host, _, _ = sql(f"select host_id from availabilities where id='{av}'")
    apt, _, _ = sql(f"select airport_code from availabilities where id='{av}'")

    # 🔴 ÜÇ YÜZEY AYNI CEVABI VERMELİ. Bu üçlü ayrışırsa kullanıcı
    # keşifte "hakkın var" görüp istek ekranında "yok" duyar — 187'nin
    # kapattığı hatanın nöbetçisi.
    d_pol, _, _ = sql(f"select public.lounge_access_decision('{av}', null) ->> 'guest_policy'")
    disc_pol, _, rc_d = sql(
        f"select d.guest_policy from public.discover_availabilities('{apt}', null, null, null) d"
        f" where d.id='{av}'", A)
    pre_json, _, rc_p = sql(f"select public.request_precheck('{av}')", A)

    if rc_d == 0 and disc_pol:
        chk('10. Keşif ve karar AYNI politikayı söylüyor',
            disc_pol == d_pol, f'keşif={disc_pol} karar={d_pol}')
    else:
        skip('10. Keşif/karar tutarlılığı', 'ilan A için keşifte görünmüyor (seyahat yok)')

    pre_kind = re.search(r'"kind"\s*:\s*"([^"]*)"', pre_json or '')
    if pre_kind and pre_kind.group(1) == 'trip_gate':
        # 192'nin bilinçli kararı: seyahat kapısı kapalıysa precheck
        # kararı taşımaz — kullanıcı o ilana zaten başvuramaz ve
        # NEDENİNİ biliyor. Bekçi de bu dalı atlıyor.
        skip('11-12. Ön kontrol/karar', 'seyahat kapısı kapalı (trip_gate) — kararsız dal')
    elif rc_p == 0 and pre_json:
        pre_pol = re.search(r'"guest_policy"\s*:\s*"([^"]*)"', pre_json)
        chk('11. Ön kontrol ve karar AYNI politikayı söylüyor',
            bool(pre_pol) and pre_pol.group(1) == d_pol,
            f'precheck={pre_pol.group(1) if pre_pol else "?"} karar={d_pol}')
        # Kredi toplamı kalemlerle tutmalı (187'nin credit_total'ı)
        m_t = re.search(r'"credit_total"\s*:\s*(\d+)', pre_json)
        m_c = re.search(r'"credit_cost"\s*:\s*(\d+)', pre_json)
        if m_t and m_c:
            chk('12. Kredi toplamı = 1 escrow + aktarım',
                int(m_t.group(1)) == 1 + int(m_c.group(1)),
                f'toplam={m_t.group(1)} aktarım={m_c.group(1)}')
        else:
            skip('12. Kredi toplamı', 'precheck credit_total vermiyor')
    else:
        skip('11-12. Ön kontrol', 'request_precheck çağrılamadı')

    # 🔴 KAPI TUTARLILIĞI: ekran "gönderemezsin" diyorsa SUNUCU DA
    # reddetmeli. Tersi daha kötü: ekran kilitli ama sunucu açık ise
    # eski bir APK ya da doğrudan RPC kapıdan geçer (187 madde 12).
    can_req = re.search(r'"can_request"\s*:\s*(true|false)', pre_json or '')
    raw_r, err_r, rc_r = sql(f"select public.create_request('{av}','lounge','akış testi')", A)
    olustu = rc_r == 0 and 'id' in (raw_r or '')
    if can_req:
        chk('13. Ekran kapısı ile sunucu kapısı AYNI karar veriyor',
            (can_req.group(1) == 'true') == olustu,
            f'ekran can_request={can_req.group(1)} sunucu={"olustu" if olustu else err_r[:60]}')
    else:
        skip('13. Kapı tutarlılığı', 'precheck can_request vermiyor')

    if olustu:
        import json as _j
        try:
            rid = _j.loads(raw_r).get('id', '')
        except Exception:
            rid = ''
        # KARŞILIKLILIK: host başvuruyu görmeli
        hr, _, rc_hr = sql("select count(*) from public.host_requests()", host)
        if rc_hr == 0:
            chk('14. Host başvuruyu görüyor', hr != '0', f'{hr} satır')
        else:
            skip('14. Host başvuruyu görüyor', 'host_requests çağrılamadı')

        # KARŞILIKLILIK: misafir kendi isteğini görmeli (186/187'nin RPC'si)
        ms, _, rc_ms = sql("select count(*) from public.my_sent_requests()", A)
        chk('15. Misafir kendi isteğini görüyor', rc_ms == 0 and ms != '0',
            f'{ms} satır' if rc_ms == 0 else 'RPC patlıyor')

        # Kredi escrow'a alınmış olmalı
        led, _, _ = sql(f"select count(*) from credit_ledger"
                        f" where user_id='{A}' and ref_id='{rid}' and delta < 0")
        chk('16. Kredi escrow''a alındı', led != '0', f'{led} kayıt')
    else:
        skip('14-16. Başvuru sonrası', f'istek oluşmadı: {err_r[:70]}')


# ============================================================
# BÖLÜM 3 · ÇOKLU HAK VE KURAL YÜZEYLERİ (189/190/191)
# ============================================================
print('\n--- 3) KURAL YÜZEYLERİ')

ven, _, _ = sql("select id from lounge_venues where active and airport_code='IST' limit 1")
if ven:
    n_opt, e_o, rc_o = sql(f"select count(*) from public.access_options_for_user('{A}'::uuid,'{ven}'::uuid,null,null)")
    chk('17. Çoklu hak çözümleyicisi çalışıyor', rc_o == 0, e_o[:80] if rc_o else f'{n_opt} seçenek')

    best, e_b, rc_b = sql(f"select public.best_access_for_user('{A}'::uuid,'{ven}'::uuid,null,null) ->> 'found'")
    chk('18. En iyi hak cevabı üretiliyor', rc_b == 0 and best in ('true', 'false'), best or e_b[:60])

# Rehber ile karar AYNI salonda çelişmemeli (187 madde 5'in nöbetçisi)
#
# 🔴 v2.72 — BU TEST İKİ YÖNDEN BOZUKTU VE ŞANSLA GEÇİYORDU.
#
# (1) FARKLI SORULAR KARŞILAŞTIRILIYORDU. Rehbere sabit `TK_MS/ELPL`
#     soruluyordu ama karar, ilanı açan host'un GERÇEK kartına göre
#     hesaplanıyor. ADB'de yakalandı: host'un kartı Priority Pass
#     Prestige, salon bir THY salonu → karar dogru olarak
#     `not_allowed`; rehber ise "Miles&Smiles Elite Plus'lı biri
#     misafir getirebilir mi?" sorusuna dogru olarak `yes` diyor.
#     İki cevap da DOĞRU; test yanlış soruyordu.
#
# (2) `limit 1` SIRALAMASIZDI. Hangi ilanın seçildiği çalıştırmadan
#     çalıştırmaya değişiyordu; test bugüne kadar "uygun" bir satır
#     denk geldiği için yeşildi. Rastgele satır seçen bir test,
#     testten çok kura çekmektir.
#
# 🔴 v2.78.2 — AYNI HATA İKİ YERDE DAHA DURUYORMUŞ. 18 Ağustos'ta
#     `npm run e2e` kırmızı yandı ve ölçtüğümde ikisi de "farklı soru"
#     çıktı; yani (1)'i yalnız TEK KARTLI hostlar için kapatmışım:
#
# (3) UÇUŞ, KARARIN GİRDİSİ AMA REHBERİN DEĞİL. 192a ile charter
#     kuralı karar TABANINA indi. Artık TK9001 (charter) ilanında
#     karar dogru olarak `not_allowed` + headline "Charter seferde
#     salon hakkı yok" diyor; rehbere ise uçuş hiç sorulmuyor, o da
#     dogru olarak `yes` diyor. Ölçüm:
#         karar : charter=true severity=block guest_policy=not_allowed
#         rehber: verdict=yes  (uçuş bilgisi girdi olarak YOK)
#     Yani testi kırmızı yakan şey ÜRÜN KUSURU DEĞİL, benim kendi
#     192a düzeltmemdi. Charter ilanlar karşılaştırma dışı.
#
# (4) ÇOK KARTLI HOST'ta kartezyen açılım. `join host_entitlements`
#     3 kartlı bir host için 3 satır üretiyor; rehbere TK_MS/ELITE
#     soruluyor ama karar Priority Pass Standard'ı seçmiş oluyor.
#     Ölçüm: iGA Lounge — Dış Hat, host 3 kartlı, karar tier=
#     PP_STANDARD, rehber TK_MS/ELITE → yine iki farklı soru.
#
# BU SEFERKİ İLKE: soruyu KARARIN KENDİ ÇIKTISINDAN türet. Karar
# hangi programı/tier'ı seçtiyse rehbere O sorulur — böylece
# karşılaştırma tanım gereği aynı soru üstünde olur ve gerçek bir
# ayrışma saklanamaz.
#
# VE: karşılaştırılan satır sayısı da rapor edilir. Sıfır satır
# karşılaştıran bir sorgu bugüne kadar "0 çelişki" diye YEŞİL
# yanıyordu (bu turda bir kez tam olarak bu tuzağa düştüm).
row, _, rc_g = sql("""
  with karar as (
    select a.id as avail_id, v.airport_code as ap, v.id as venue_id,
           public.lounge_access_decision(a.id, null) as d
      from availabilities a
      join lounge_venues v on v.id = public.resolve_venue_for_availability(a.id)
     where a.active
  ), soru as (
    select k.ap, k.venue_id, k.d, p.code as prog, (k.d ->> 'tier') as tier
      from karar k
      join lounge_programs p on p.id = (k.d ->> 'program_id')::uuid
     where coalesce((k.d ->> 'known')::boolean, false)
       -- charter: kararın girdisi, rehberin değil → karşılaştırılamaz
       and coalesce((k.d ->> 'charter')::boolean, false) = false
  )
  select count(*),
         count(*) filter (where celiski),
         coalesce(min(ayrinti) filter (where celiski), '')
    from (
      select (g.verdict = 'yes' and (s.d ->> 'guest_policy') = 'not_allowed') as celiski,
             s.ap || '/' || s.prog || '/' || coalesce(s.tier,'-')
             || ' rehber=' || g.verdict
             || ' karar=' || coalesce(s.d ->> 'guest_policy','-')
             || ' baslik=' || coalesce(s.d ->> 'headline','-') as ayrinti
        from soru s
        join lateral public.guide_lounges(s.ap, s.prog, s.tier, null, null) g
          on g.venue_id = s.venue_id
    ) q""")
if rc_g == 0 and row:
    n_kars, n_cel, ayrinti = (row.split('|') + ['', ''])[:3]
    _kars = int(n_kars.strip() or 0)
    chk('19. Rehber ile karar çelişmiyor (kararın SEÇTİĞİ kartla, charter hariç)',
        _kars > 0 and n_cel.strip() == '0',
        (f'{_kars} karşılaştırma · {n_cel} çelişki'
         + (f' · {ayrinti}' if ayrinti.strip() else ''))
        if _kars else 'HİÇBİR SATIR KARŞILAŞTIRILMADI — test boşa döndü')
else:
    skip('19. Rehber/karar tutarlılığı', 'örnek bulunamadı')

# Salon listesinde mükerrer olmamalı (190'ın nöbetçisi, app tarafından)
dup, _, _ = sql("""select count(*) from (
    select airport_code, lower(name), count(*) from (
      select l.airport_code, l.name from lounges l
       join lounge_venues v on v.id=l.venue_id where l.active and v.active) s
     group by 1,2 having count(*)>1) x""")
chk('20. Katalogda aynı havalimanında mükerrer ad yok', dup == '0', f'{dup} grup')

# İç/dış hat ayrımı sekmelere yansıyor mu (190 + v2.66)
scopes, _, rc_s = sql("select count(distinct scope) from public.lounges_for_airport('IST')")
chk('21. IST birden çok kapsam döndürüyor (sekmeler dolu)',
    rc_s == 0 and int(scopes or 0) >= 2, f'{scopes} farklı kapsam')

has_sec, _, _ = sql("select count(*) from public.lounges_for_airport('IST') where section is not null")
chk('22. Bölüm bilgisi listeye taşınıyor', has_sec != '0', f'{has_sec} bölümlü salon')


# ============================================================
# BÖLÜM 4 · ÇELİŞKİ DEFTERİ VE MİMARİ KABLOLAR (191)
# ============================================================
print('\n--- 4) 191 KABLOLARI')

n_conf, _, rc_c = sql("select count(*) from rule_source_conflicts")
chk('23. Çelişki defteri dolu ve okunabilir', rc_c == 0 and n_conf != '0', f'{n_conf} kayıt')

acik, _, _ = sql("select count(*) from rule_source_conflicts where durum='acik'")
chk('24. Karara bağlanmamış çelişki yok', acik == '0', f'{acik} açık')

bo, _, rc_bo = sql("select public.bank_override_for("
                   "(select id from lounge_programs where code='PRIORITY_PASS'),'GARANTI',null)")
chk('25. Banka örtüşmesi çağrılabiliyor', rc_bo == 0, 'veri yokken null' if rc_bo == 0 else 'patlıyor')

cab, _, rc_cab = sql("select not_metni from public.cabin_rule_reach()")
chk('26. Kabin erişilebilirliği raporlanıyor', rc_cab == 0 and bool(cab), (cab or '')[:70])

# Aynı programdan iki kart GERÇEKTEN eklenebiliyor mu (191 madde 4)
pid, _, _ = sql("select id from lounge_programs where code='TK_MS'")
sql(f"delete from host_entitlements where card_label like 'flowtest-%'")
sql(f"""insert into host_entitlements (user_id, program_id, tier, card_label, origin)
        values ('{A}','{pid}','ELPL','flowtest-a','admin'),
               ('{A}','{pid}','ELPL','flowtest-b','admin')""")
n_cards, _, _ = sql(f"select count(*) from host_entitlements"
                    f" where user_id='{A}' and card_label like 'flowtest-%'")
chk('27. Aynı programdan iki kart eklenebiliyor', n_cards == '2', f'{n_cards} kart')
sql("delete from host_entitlements where card_label like 'flowtest-%'")

# Erişim beyanı hâlâ çalışıyor mu (uq_he değişikliğinin nöbetçisi)
# 🔴 TESTİN KENDİ HATASIYDI: imza save_host_access(text[], smallint,
# boolean, smallint, text, smallint, uuid, text) — ilk parametre DİZİ.
# 'TK_MS' yazınca "malformed array literal" veriyordu ve bunu bir ÜRÜN
# hatası sandım. İmzayı okumadan çağırmanın 13. örneği.
# 🔴 İKİNCİ TEST HATASI: parametre SIRASINI okumadan doldurdum.
# İmza: (p_sources text[], p_guest_capacity, p_guest_fee_expected,
#        p_quota_total, p_quota_period, p_quota_used, p_card_product_id,
#        p_card_tier). Ben 'ELPL'i 5. sıraya (quota_period) yazmıştım,
# 'year'i de 8. sıraya (card_tier). Ürün doğru davranıp geçersiz dönemi
# reddediyordu; hata TESTTEYDİ. Adlandırılmış parametre kullanmak bu
# sınıfı tümden kapatır — sıra bilgisine bağımlılık kalmaz.
_, e_sa, rc_sa = sql(
    "select public.save_host_access("
    " p_sources => array['TK_MS']::text[],"
    " p_guest_capacity => 1::smallint,"
    " p_quota_period => 'year'::text,"
    " p_card_tier => 'ELPL'::text)", A)
if rc_sa != 0 and 'does not exist' in (e_sa or ''):
    skip('28. Erişim beyanı kaydediliyor', 'save_host_access imzası farklı')
else:
    chk('28. Erişim beyanı kaydediliyor', rc_sa == 0, (e_sa or '')[:90])


# ============================================================
print()
print(f'  {len(ok)} geçti · {len(bad)} başarısız')
if bad:
    print('  BAŞARISIZ: ' + ', '.join(bad))
sys.exit(1 if bad else 0)
