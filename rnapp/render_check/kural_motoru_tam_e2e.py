#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/kural_motoru_tam_e2e.py   (13 Kasım 2026)

KURAL MOTORU — TAM ÇAPRAZ DOĞRULAMA

NEDEN VAR (Gökberk): "Kullanıcının başvuramayacağı bir ilana başvurmasını veya başvurabildiği
bir ilana başvuramamasını kesinlikle istemeyiz." rule_dims_e2e her boyutu TEK senaryoyla ölçüyor;
rule_matrix_test() (resmî tablolardan üretilen 480+ vaka) hiçbir e2e'de koşmuyordu.

A · MOTOR ↔ RESMÎ LİSTELER: rule_matrix_test, flow_gate_test, rule_coverage_audit,
    rule_contamination_check, lounge_rules_health — tam SEED dünyasında, kırmızı = düşer.
B · EKRAN ↔ SUNUCU (her misafir × her gelecek ilan × 10 seyahat varyantı):
    1. KART: uygulamanın "İstek gönder" kararı (ekranlar_ana.js kuralIstekDurumu + isBlocked +
       has_trip; telefon doğrulanmış, istek yok, süresi geçmemiş varsayımıyla) — Keşfet satırı
       (discover_availabilities) + rozet (discovery_rule_badges) alanlarından AYNI formülle.
    2. ÖN KONTROL: request_precheck.can_request (gönderme ekranı)
    3. KURAL SATIRLARI: kural_kosullari'nda 'yok' satırı
    4. SUNUCU: create_request (alt işlemde koşar, geri alınır)
    Düşen sınıflar:
      M2 ön kontrol "olur" der, sunucu reddeder          (kullanıcı basar, hata alır)
      M3 ön kontrol "olmaz" der, sunucu kabul ederdi      (başvurabileceği ilana başvuramaz)
      M4 kart kapalı (kural engeli), sunucu kabul ederdi  (başvurabileceği ilana başvuramaz)
      M5 kart açık, ön kontrol ya da sunucu KURAL sebebiyle reddeder (kart yanlış söz verir)
      M6 kural satırında 'yok' var ama sunucu kabul eder / satır temiz ama sunucu kural reddi
      M7 ilan Keşfet'te görünmüyor ama sunucu kabul eder (doğrudan API ile görünmeyen ilana istek)
    Bilgi (düşürmez): kart açık + ön kontrol misafire özel kapıda (kredi, açık istek tavanı,
    aynı saatte kendi ilanı) → gönderme ekranında sebep yazar; bu bilinçli tasarım (301 §6).
"""
import os as _w_os, sys as _w_sys
_w_sys.path.insert(0, _w_os.path.dirname(_w_os.path.abspath(__file__)))
import win_e2e  # noqa: F401,E402
import json, os, re, sys, pathlib, shutil, subprocess, time
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import psycopg2
import pgserver
import ll_paths as _llp

BIN = pathlib.Path(pgserver.__file__).parent / "pginstall" / "bin"
ENV = {"PATH": f"{BIN}:/usr/bin:/bin", "HOME": "/tmp"}
D = pathlib.Path("/tmp/ll_kuraltam_" + str(os.getpid()))
import atexit, glob
for eski in glob.glob("/tmp/ll_kuraltam_*"):
    if pathlib.Path(eski) != D:
        shutil.rmtree(eski, ignore_errors=True)
atexit.register(lambda: shutil.rmtree(str(D), ignore_errors=True))
D.mkdir(parents=True)
ns = {}
exec(open(ROOT / "pg_run.py").read().replace("if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns["install_fake_extensions"]()
srv = pgserver.get_server(D)
uri = srv.get_uri()


def _psql(args):
    return subprocess.run([str(BIN / "psql"), uri, "-X", "-q", "-v", "ON_ERROR_STOP=1"] + args,
                          capture_output=True, text=True, env=ENV)


_psql(["-c", ns["SHIM"]])
sd = _llp.sql_dir()
_o = lambda f: (re.match(r"^(\d{3})([a-z]?)_", f).group(1), 0 if re.match(r"^(\d{3})([a-z]?)_", f).group(2) else 1, f)
dusen_dosya = []
for f in (sorted((f for f in os.listdir(sd) if re.match(r"^\d{3}[a-z]?_.*\.sql$", f)), key=_o)
          + sorted(x for x in os.listdir(sd) if x.startswith("SEED"))):
    r = _psql(["-f", os.path.join(sd, f)])
    if r.returncode != 0:
        dusen_dosya.append((f, r.stderr.strip().splitlines()[-1][:160] if r.stderr.strip() else "?"))

cx = psycopg2.connect(uri)
cx.autocommit = True
cur = cx.cursor()

ok, bad = [], []
def chk(ad, kosul, ek=""):
    (ok if kosul else bad).append(ad)
    print(("  ✓ " if kosul else "  ✗ ") + ad + (("  → " + str(ek)[:400]) if ek != "" else ""))

def q(sql, args=None):
    cur.execute(sql, args)
    return cur.fetchall() if cur.description else []

print("kurulum: düşen dosya", len(dusen_dosya), dusen_dosya[:5])

# ════════════════════════════════════════════════════════════════════════════
# A · MOTOR ↔ RESMÎ LİSTELER
# ════════════════════════════════════════════════════════════════════════════
print("\n=== A · MOTOR ↔ RESMÎ LİSTELER ===")
try:
    q("select public.rebuild_rule_test_cases()")
except Exception as e:
    print("  rebuild_rule_test_cases:", str(e)[:120])
tum = q("select vaka, seviye, beklenen, gercek, sonuc from public.rule_matrix_test(false)")
kirmizi = [r for r in tum if str(r[4]).upper() not in ("OK", "GECTI", "GEÇTİ", "PASS", "✓")]
print(f"  rule_matrix_test: {len(tum)} vaka · sonuç dağılımı {Counter(str(r[4]) for r in tum).most_common(6)}")
chk(f"resmî tablo matrisi: {len(tum)} vakanın hepsi beklenenle aynı", len(tum) > 100 and not kirmizi,
    [r[:5] for r in kirmizi[:8]])

try:
    fg = q("select senaryo, beklenen, gercek, sonuc from public.flow_gate_test()")
    fk = [r for r in fg if str(r[3]).upper() not in ("OK", "GECTI", "PASS", "ATLANDI", "SKIP", "✓", "—")]
    print(f"  flow_gate_test: {len(fg)} senaryo · {Counter(str(r[3]) for r in fg).most_common(6)}")
    chk(f"akış kapısı testi: {len(fg)} senaryo", len(fg) > 0 and not fk, fk[:6])
except Exception as e:
    chk("akış kapısı testi koştu", False, str(e)[:200])

ca = q("select kontrol, sinif, deger, esik, sonuc from public.rule_coverage_audit()")
cak = [r for r in ca if str(r[4]).upper() not in ("OK", "GECTI", "PASS", "BILGI", "BİLGİ", "INFO", "✓")]
print(f"  rule_coverage_audit: {len(ca)} satır · {Counter(str(r[4]) for r in ca).most_common(6)}")
chk("kural kapsam denetimi kırmızısız", not cak, cak[:6])
cc = q("select program, kart, sorun, ornek from public.rule_contamination_check()")
chk("kural bulaşma denetimi (program ↔ kart) boş", not cc, cc[:6])
lh = q("select alan, sorun, ayrinti, agirlik from public.lounge_rules_health()")
lh_yer = [r for r in lh if 'yer tutucu' in str(r[1])]
lh_kaynak = [r for r in lh if str(r[1]) == 'kaynak yok']
print(f"  bilgi · resmî kaynak bağlantısı girilmemiş program/salon: {len(lh_kaynak)} → {[r[0] for r in lh_kaynak]}")
lh_agir = [r for r in lh if (r[3] or 0) >= 3 and 'yer tutucu' not in str(r[1]) and str(r[1]) != 'kaynak yok']
print(f"  lounge_rules_health ağır bulgu türleri: {Counter(str(r[1]) for r in lh if (r[3] or 0) >= 3).most_common()}")
print(f"  bilgi · araştırılmamış (yer tutucu) salon-program satırı: {len(lh_yer)} — bu salonlarda karar 'doğrulanmadı' uyarısı + onay kutusuyla verilir")
print(f"  lounge_rules_health: {len(lh)} satır · ağırlık dağılımı {Counter(r[3] for r in lh).most_common()}")
chk("salon kural sağlığı: ağır (>=3) bulgu yok", not lh_agir, lh_agir[:6])

# ════════════════════════════════════════════════════════════════════════════
# B · EKRAN ↔ SUNUCU
# ════════════════════════════════════════════════════════════════════════════
print("\n=== B · EKRAN ↔ ÖN KONTROL ↔ KURAL SATIRLARI ↔ SUNUCU ===")
q("""
create table if not exists public.mat_sonuc (
  g uuid, av uuid, varyant text, gorunur boolean, host_id uuid, slots int, filled int,
  guest_policy text, d_blocks boolean, has_trip boolean, rozet_engel boolean, rozet_etiket text,
  pre_can boolean, pre_gate text, pre_ack boolean, pre_head text, kk_yok int, kk text, srv text, hata text)
""")
q(r"""
create or replace function public.mat_kos(p_g uuid, p_av uuid, p_var text, p_dest text, p_flight text,
  p_carrier text, p_party int, p_child smallint[], p_purpose text, p_from time, p_to time)
returns void language plpgsql set search_path = public as $mk$
declare a availabilities%rowtype; d record; b record; v_gor boolean := false; v_rb boolean; v_ret text;
  v_pre jsonb; v_kky int; v_kk text; v_srv text; v_hata text;
  v_slots int; v_filled int; v_gp text; v_db boolean; v_ht boolean; v_host uuid;
begin
  select * into a from availabilities where id = p_av;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_g, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_g::text, true);
    delete from requests where guest_id = p_g;
    delete from visits where user_id = p_g and visit_date = a.avail_date;
    insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to,
                        flight_number, carrier_code, party_size, child_ages, purpose)
    values (p_g, a.airport_code, p_dest, a.avail_date, p_from, p_to, p_flight, p_carrier, p_party, p_child, p_purpose);
    select * into d from public.discover_availabilities(a.airport_code::text, null, null, a.avail_date) x where x.id = p_av;
    if found then
      v_gor := true; v_slots := d.slots; v_filled := d.filled; v_gp := d.guest_policy;
      v_db := d.blocks_request; v_ht := d.has_trip; v_host := d.host_id;
    end if;
    select * into b from public.discovery_rule_badges(array[p_av]) limit 1;
    if found then v_rb := b.blocks_request; v_ret := b.label; end if;
    v_pre := public.request_precheck(p_av);
    select count(*) filter (where durum = 'yok' and agirlik = 'kapi'), string_agg(kod || ':' || durum || ':' || agirlik, ',' order by sira)
      into v_kky, v_kk from public.kural_kosullari(p_av);
    begin
      perform public.create_request(p_av, 'lounge', null, null);
      v_srv := 'ok';
    exception when others then v_srv := split_part(sqlerrm, ' ', 1);
    end;
    raise exception 'MAT_GERI';
  exception when others then
    if sqlerrm <> 'MAT_GERI' then v_hata := left(sqlerrm, 200); end if;
  end;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  insert into mat_sonuc values (p_g, p_av, p_var, v_gor, v_host, v_slots, v_filled, v_gp, v_db, v_ht, v_rb, v_ret,
    (v_pre ->> 'can_request')::boolean, v_pre ->> 'gate', coalesce((v_pre ->> 'needs_ack')::boolean, false),
    left(v_pre ->> 'headline', 120), v_kky, v_kk, v_srv, v_hata);
end $mk$;
""")


q(r"""
create or replace function public.mat_tani(p_g uuid, p_av uuid, p_dest text, p_flight text,
  p_carrier text, p_party int, p_child smallint[], p_purpose text, p_from time, p_to time)
returns jsonb language plpgsql set search_path = public as $mt$
declare a availabilities%rowtype; v_vid uuid; j jsonb; v_out jsonb;
begin
  select * into a from availabilities where id = p_av;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_g, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_g::text, true);
    delete from requests where guest_id = p_g;
    delete from visits where user_id = p_g and visit_date = a.avail_date;
    insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to,
                        flight_number, carrier_code, party_size, child_ages, purpose)
    values (p_g, a.airport_code, p_dest, a.avail_date, p_from, p_to, p_flight, p_carrier, p_party, p_child, p_purpose)
    returning id into v_vid;
    j := jsonb_build_object(
      'v6', public.lounge_access_decision_v6(p_av, p_flight, p_carrier, v_vid),
      'rozet', (select to_jsonb(b) from public.discovery_rule_badges(array[p_av]) b limit 1),
      'pre', public.request_precheck(p_av),
      'kk', (select jsonb_agg(to_jsonb(k) order by k.sira) from public.kural_kosullari(p_av) k),
      'ham_var', exists (select 1 from public.discover_availabilities_ham(a.airport_code::text, null, null, a.avail_date) h where h.id = p_av),
      'base_var', exists (select 1 from public.discover_availabilities_base(a.airport_code::text, null, null, a.avail_date) h where h.id = p_av),
      'kesfet_sayisi', (select count(*) from public.discover_availabilities(a.airport_code::text, null, null, a.avail_date)),
      'ilan', (select jsonb_build_object('vis', a.visibility, 'min_trust', a.min_trust, 'carrier', a.carrier_code, 'cabin', a.cabin_class,
                 'host_kadin_mod', (select women_safety_mode from profiles where user_id = a.host_id),
                 'host_cins', (select gender from users where id = a.host_id),
                 'misafir_cins', (select gender from users where id = p_g),
                 'misafir_puan', (select score from trust_scores where user_id = p_g),
                 'host_gizli', public.test_hesabi_gizli_mi(a.host_id),
                 'host_rol', (select role from users where id = a.host_id),
                 'host_onayli_basvuru', exists (select 1 from host_applications h where h.user_id = a.host_id and h.status = 'approved'),
                 'host_kesifte', (select show_on_discovery from profiles where user_id = a.host_id),
                 'host_golge', (select shadow_limited from users where id = a.host_id),
                 'host_ekip', (select is_staff from users where id = a.host_id),
                 'host_email', (select email from users where id = a.host_id),
                 'engel', public.is_blocked_pair(p_g, a.host_id))));
    v_out := j;
    raise exception 'MAT_GERI';
  exception when others then
    if sqlerrm <> 'MAT_GERI' then v_out := jsonb_build_object('hata', sqlerrm); end if;
  end;
  return v_out;
end $mt$;
""")

# misafirler: seed misafir hesapları (ekip değil), telefon doğrulanmış + bol kredi
q("insert into beta_settings (key, value) values ('telefon_kanali', to_jsonb('firebase'::text)) on conflict (key) do update set value = excluded.value")
misafir = q("""
  select u.id::text, u.email, coalesce(u.gender::text,'-') from users u
   where public.seed_test_hesabi(u.email) and u.role = 'guest' and not coalesce(u.is_staff,false)
     and u.deleted_at is null and u.banned_at is null
   order by u.email""")
print("  seed misafir sayısı:", len(misafir))
# cinsiyet çeşitliliği: en fazla 2 kadın + 2 erkek/diğer
secim, say = [], Counter()
for m in misafir:
    k = "f" if m[2] == "female" else "o"
    if say[k] < 2:
        secim.append(m); say[k] += 1
print("  seçilen misafirler:", [(m[1], m[2]) for m in secim])
for m in secim:
    q("update verifications set email_verified = true, phone_verified = true where user_id = %s", (m[0],))
    q("insert into credit_ledger (user_id, delta, reason, balance_after, note) values (%s, 200, 'admin_adjust', 200, 'kural matrisi')", (m[0],))
q("update users set shadow_limited = false where id = any(%s::uuid[])", ([m[0] for m in secim],))

ilan = q("""
  select a.id::text, a.airport_code::text, a.time_from, a.time_to, a.host_id::text from availabilities a
   where a.active and a.avail_date > current_date and a.visibility <> 'Hidden'
   order by a.airport_code, a.avail_date, a.id""")
print("  gelecek ilan sayısı:", len(ilan), "· havalimanları:", sorted({i[1] for i in ilan}))

# havalimanı başına iç/dış hat varış noktası
hedef = {}
for ap in sorted({i[1] for i in ilan}):
    dom = q("select code::text from airports where code <> %s and public.ucus_hatti(%s, code) = 'domestic' order by code limit 1", (ap, ap))
    intl = q("select code::text from airports where code <> %s and public.ucus_hatti(%s, code) = 'international' order by code limit 1", (ap, ap))
    hedef[ap] = (dom[0][0] if dom else None, intl[0][0] if intl else None)
print("  varış noktaları:", hedef)
tasiyicilar = [r[0] for r in q("select code from carriers where code in ('TK','PC','AJ','XQ','VF') order by code")]
diger = next((c for c in tasiyicilar if c != "TK"), None)
print("  taşıyıcılar:", tasiyicilar, "· TK dışı:", diger)

def zaman_cikar(t, saat):
    s = t.hour * 60 + t.minute - saat * 60
    return None if s < 0 else f"{s // 60:02d}:{s % 60:02d}"

def varyantlar(ap, tf, tt):
    dom, intl = hedef.get(ap, (None, None))
    base = dict(dest=intl or dom, flight="TK1001", carrier="TK", party=1, child=None, purpose=None,
                tf=str(tf)[:5], tt=str(tt)[:5])
    v = [("V01_dis_hat_TK", base),
         ("V02_ic_hat", {**base, "dest": dom}),
         ("V03_varis_yok", {**base, "dest": None}),
         ("V04_diger_tasiyici", {**base, "flight": (diger or "PC") + "2001", "carrier": diger}),
         ("V05_ucussuz", {**base, "flight": None, "carrier": None}),
         ("V06_uc_kisi", {**base, "party": 3}),
         ("V07_cocuk_3yas", {**base, "party": 2, "child": [3]}),
         ("V08_aktarma", {**base, "purpose": "connecting"}),
         ("V10_ic_hat_diger_2kisi", {**base, "dest": dom, "flight": (diger or "PC") + "2002", "carrier": diger, "party": 2})]
    uzun = zaman_cikar(tf, 4)
    if uzun:
        v.append(("V09_uzun_bekleme", {**base, "tf": uzun}))
    return v

t0 = time.time(); n = 0
for m in secim:
    for (avid, ap, tf, tt, host) in ilan:
        if host == m[0]:
            continue
        for ad, p in varyantlar(ap, tf, tt):
            cur.execute("select public.mat_kos(%s,%s,%s,%s,%s,%s,%s,%s::smallint[],%s,%s::time,%s::time)",
                        (m[0], avid, ad, p["dest"], p["flight"], p["carrier"], p["party"], p["child"],
                         p["purpose"], p["tf"], p["tt"]))
            n += 1
print(f"  koşulan kombinasyon: {n} · {time.time() - t0:.0f} sn")

rows = q("""select g::text, av::text, varyant, gorunur, host_id::text, slots, filled, guest_policy, d_blocks, has_trip,
                   rozet_engel, rozet_etiket, pre_can, pre_gate, pre_ack, pre_head, kk_yok, kk, srv, hata from mat_sonuc""")
KURAL = {"blocked_by_rule", "party_too_big", "scope_mismatch", "quota_exhausted", "cabin_required", "children_not_allowed",
         "guests_not_allowed", "guest_carrier_mismatch", "arrival_only", "stay_too_long", "no_access_source",
         "serves_mismatch", "stay_limit_exceeded"}
MISAFIRE_OZEL = {"insufficient_credits", "hosting_same_slot", "too_many_open_requests", "open_request_cap",
                 "rate_limited", "acik_istek_tavani", "daily_request_cap"}
sinif = defaultdict(list); tam = {}
srv_dag = Counter(); pre_dag = Counter(); hata = []
for r in rows:
    (g, av, var, gor, host, slots, filled, gp, dblk, ht, rblk, ret, pcan, pgate, pack, phead, kky, kk, s, h) = r
    if h:
        hata.append((var, av[:8], h)); continue
    srv_ok = s == "ok"
    srv_dag[s] += 1; pre_dag[(pcan, (pgate or "").split(" ")[0])] += 1
    kart = bool(gor) and host != g and (slots or 0) - (filled or 0) > 0 \
        and not (bool(rblk) or gp == "not_allowed" or bool(dblk)) and bool(ht)
    kart_kural_engel = bool(gor) and (bool(rblk) or gp == "not_allowed" or bool(dblk))
    pg = (pgate or "").split(" ")[0]
    tam[(var, av[:8])] = (g, av, var)
    ozet = (var, av[:8], f"kart={kart} pre={pcan}/{pg} kk_yok={kky} srv={s} rozet={ret!r} gp={gp} dblk={dblk} ht={ht}")
    if pcan is True and not srv_ok:
        sinif["M2 ön kontrol olur, sunucu reddeder"].append(ozet)
    if pcan is False and srv_ok:
        sinif["M3 ön kontrol olmaz, sunucu kabul ederdi"].append(ozet)
    if kart_kural_engel and srv_ok:
        sinif["M4 kart kural engeli gösterir, sunucu kabul ederdi"].append(ozet)
    if kart and ((s in KURAL) or (pcan is False and pg in KURAL)):
        sinif["M5 kart açık, kural sebebiyle red"].append(ozet)
    if (kky or 0) > 0 and srv_ok:
        # 359: 'aynı uçuş' istisnası kalktı — satır 'yok' yalnız kesin farklı uçuşta, sunucu da reddeder
        sinif["M6a kural satırında 'yok' var, sunucu kabul eder"].append(ozet)
    if (kky or 0) == 0 and s in KURAL:
        sinif["M6b kural satırları temiz, sunucu kural reddi"].append(ozet)
    if not gor and srv_ok:
        sinif["M7 Keşfet'te görünmeyen ilana sunucu istek kabul eder"].append(ozet)
    if gor and not ht and srv_ok:
        sinif["M8 eşleşen seyahat var ama kart 'seyahat yok' der"].append(ozet)

print("  sunucu sonuç dağılımı:", srv_dag.most_common(15))
print("  ön kontrol dağılımı:", pre_dag.most_common(15))
print("  varyant başına kabul:", sorted(Counter(r[2] for r in rows if r[18] == "ok").items()))
chk(f"B koşusu hatasız ({len(rows)} kombinasyon)", not hata and len(rows) == n, hata[:5])
chk("kombinasyonların bir kısmı kabul, bir kısmı red (test anlamlı)", 0 < srv_dag["ok"] < len(rows), srv_dag.most_common(5))
for ad in ["M2 ön kontrol olur, sunucu reddeder", "M3 ön kontrol olmaz, sunucu kabul ederdi",
           "M4 kart kural engeli gösterir, sunucu kabul ederdi", "M5 kart açık, kural sebebiyle red",
           "M6a kural satırında 'yok' var, sunucu kabul eder", "M6b kural satırları temiz, sunucu kural reddi",
           "M7 Keşfet'te görünmeyen ilana sunucu istek kabul eder",
           "M8 eşleşen seyahat var ama kart 'seyahat yok' der"]:
    L = sinif.get(ad, [])
    chk(f"{ad}: 0", not L, f"{len(L)} adet · örnek: {L[:4]}")
ay = Counter((r[2], r[18]) for r in rows if 'ucus_bagi:yok:kapi' in (r[17] or ''))
print(f"  bilgi · 359 'aynı uçuş' kesin farklı uçuş (satır 'yok'): {sum(ay.values())} kombinasyon · sunucu sonucu {dict(Counter(k[1] for k in ay.elements()))}")
chk("359 · kesin farklı uçuşta sunucu hep reddeder", all(k[1] != 'ok' for k in ay), ay.most_common(6))
exec(open(pathlib.Path(__file__).with_name('kural_ayni_ucus_bolum.py'), encoding='utf-8').read())
VARP = {}
for m in secim:
    for (avid, ap, tf, tt, host) in ilan:
        for ad, p in varyantlar(ap, tf, tt):
            VARP[(m[0], avid, ad)] = p
print("\n=== TANI (her sınıftan 2 örnek) ===")
for ad, L in sinif.items():
    for ozet in L[:2]:
        g, av, var = tam[(ozet[0], ozet[1])]
        p = VARP[(g, av, var)]
        j = q("select public.mat_tani(%s,%s,%s,%s,%s,%s,%s::smallint[],%s,%s::time,%s::time)",
              (g, av, p["dest"], p["flight"], p["carrier"], p["party"], p["child"], p["purpose"], p["tf"], p["tt"]))[0][0]
        print(f"\n--- {ad} · {var} · ilan {av[:8]}")
        v6 = (j or {}).get("v6") or {}
        ozetj = {
            "v6": {k: v6.get(k) for k in ["fits", "severity", "carrier_ok", "program_id", "program", "entitlement_model",
                                          "guest_policy", "block_code", "scope_ok", "party_ok", "child_ok", "quota_ok",
                                          "cabin_ok", "stay_ok", "serves_ok", "headline", "source", "known"]},
            "rozet": {k: ((j or {}).get("rozet") or {}).get(k) for k in ["severity", "label", "blocks_request"]},
            "pre": {k: ((j or {}).get("pre") or {}).get(k) for k in ["can_request", "gate", "headline", "needs_ack", "severity"]},
            "kk_ok_degil": [(x.get("kod"), x.get("durum"), x.get("agirlik"), x.get("metin")) for x in ((j or {}).get("kk") or []) if x.get("durum") != "ok"],
            "kesfet": {k: (j or {}).get(k) for k in ["ham_var", "base_var", "kesfet_sayisi"]},
            "ilan": (j or {}).get("ilan"), "hata": (j or {}).get("hata")}
        print(json.dumps(ozetj, ensure_ascii=False, default=str))
bilgi = Counter((r[13] or "").split(" ")[0] for r in rows if r[12] is False and (r[13] or "").split(" ")[0] in MISAFIRE_OZEL)
print("  bilgi · ön kontrolde misafire özel kapı (gönderme ekranında sebep yazar):", dict(bilgi))
# her ret kodu kullanıcıya TR+EN cümle olarak gösterilebiliyor mu
i18n = open(ROOT / "src" / "i18n.js", encoding="utf-8").read()
kodlar = sorted({s for s in srv_dag if s != "ok"})
eksik = [k for k in kodlar if (k not in i18n)]
chk(f"sunucunun döndürdüğü {len(kodlar)} ret kodunun hepsi i18n'de (ham kod görünmez)", not eksik, eksik)
print(f"\nSON: {len(ok)} gecti · {len(bad)} dustu")
