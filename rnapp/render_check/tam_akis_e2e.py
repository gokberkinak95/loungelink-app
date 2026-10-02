#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · tam_akis_e2e.py                                   (23 Eylül 2026)

"UÇTAN UCA TÜM AKIŞLARIN — İLAN AÇMA, SEYAHAT OLUŞTURMA, İLANA BAŞVURMA/
 BAŞVURAMAMA, BAĞLANTI GÖNDERME/KABUL, İLAN VE BAĞLANTI DAVETLERİNİ
 REDDEDEBİLME, İLAN/SEYAHAT DÜZENLEME/KALDIRMA, CHAT, OTURUM BAŞLATMA/
 TAMAMLAMA, PUANLAMA… TUTARLI VE DOĞRU ÇALIŞIYOR MU EMİN OL"   — Gökberk

🔴 NEDEN AYRI BİR TEST — ÖNCEKİ BEŞİNDEN FARKI

Önceki e2e'ler (two_account, flow_matrix, edge_flows…) kimlik taklidini
yalnız `request.jwt.claims` ile yapıyordu; sorgular SÜPER KULLANICI olarak
koşuyordu. Süper kullanıcı RLS'i ve GRANT'ları ATLAR. Yani o testler
"fonksiyon doğru mu" sorusunu cevaplıyor, "uygulama bunu YAPABİLİR mi"
sorusunu cevaplamıyordu. Bu projede tam o boşluktan iki kez kaza çıktı:
`show_on_discovery` (253'ten beri istemciye kapalı, ekran her dokunuşta
hata veriyordu) ve başkasının doğrulama rozetleri (RLS yalnız kendi
satırını gösteriyordu). İkisini de süper kullanıcılı testler göremezdi.

Bu test HER ADIMI PostgREST'in yaptığı gibi koşuyor:
    SET LOCAL ROLE authenticated  +  request.jwt.claims = {sub: …}
ve uygulamanın GÖNDERDİĞİ argüman adlarını kullanıyor (kaynaktan okundu).
Her bölüm iki soru soruyor: (1) yapan taraf yapabildi mi, (2) KARŞI TARAF
bunu kendi RLS'iyle görüyor mu.

Tek işlem, en sonda GERİ ALINIR: veritabanında iz bırakmaz, tekrar koşulur.
Aktörler taze `@e2e.test` hesapları (test kümesi).

🆕 SINIF: "SÜPER KULLANICIYLA KOŞAN BİR AKIŞ TESTİ, ÜRÜNÜ DEĞİL VERİTABANINI
TEST EDER — KULLANICININ YAPABİLECEĞİNİ ÖLÇMEK İÇİN KULLANICI OLMAK GEREKİR."

Koşum:
    LL_E2E_DSN="dbname=ll user=postgres" python3 render_check/tam_akis_e2e.py
  (DSN verilmezse pgserver ile sıfırdan kurulmuş geçici bir veritabanında,
   diğer e2e'lerle aynı yoldan koşar.)
"""
import json, os, re, sys, uuid, pathlib, shutil, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

try:
    import psycopg2
except ImportError:
    print("⊘ psycopg2 yok — pip install psycopg2-binary"); sys.exit(1)

DSN = os.environ.get("LL_E2E_DSN")
if not DSN:
    # Diğer e2e'lerle aynı: geçici pgserver + bütün migration'lar + SEED'ler
    import pgserver
    import ll_paths as _llp
    BIN = pathlib.Path(pgserver.__file__).parent / "pginstall" / "bin"
    ENV = {"PATH": f"{BIN}:/usr/bin:/bin", "HOME": "/tmp"}
    D = pathlib.Path("/tmp/ll_tamakis_" + str(os.getpid()))
    import atexit, glob
    for eski in glob.glob("/tmp/ll_tamakis_*"):
        if pathlib.Path(eski) != D: shutil.rmtree(eski, ignore_errors=True)
    atexit.register(lambda: shutil.rmtree(str(D), ignore_errors=True))
    D.mkdir(parents=True)
    ns = {}
    exec(open(ROOT / "pg_run.py").read().replace(
        "if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
    ns["install_fake_extensions"]()
    srv = pgserver.get_server(D)
    uri = srv.get_uri()
    def _psql(args):
        return subprocess.run([str(BIN / "psql"), uri, "-X", "-q", "-v", "ON_ERROR_STOP=1"] + args,
                              capture_output=True, text=True, env=ENV)
    _psql(["-c", ns["SHIM"]])
    sd = _llp.sql_dir()
    _o = lambda f: (re.match(r"^(\d{3})([a-z]?)_", f).group(1),
                    0 if re.match(r"^(\d{3})([a-z]?)_", f).group(2) else 1, f)
    for f in (sorted((f for f in os.listdir(sd) if re.match(r"^\d{3}[a-z]?_.*\.sql$", f)), key=_o)
              + sorted(x for x in os.listdir(sd) if x.startswith("SEED"))):
        _psql(["-f", os.path.join(sd, f)])
    DSN = uri

cx = psycopg2.connect(DSN)
cx.autocommit = False
cur = cx.cursor()

ok, bad = [], []
def chk(ad, kosul, ek=""):
    (ok if kosul else bad).append(ad)
    print(("  ✓ " if kosul else "  ✗ ") + ad + (("  → " + str(ek)[:160]) if ek != "" else ""))

def _kimlik(uid):
    if uid:
        cur.execute("select set_config('request.jwt.claims', %s, true), set_config('request.jwt.claim.sub', %s, true)",
                    (json.dumps({"sub": uid, "role": "authenticated"}), uid))
        cur.execute("set local role authenticated")
    else:
        cur.execute("reset role")
        cur.execute("select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true)")

def q(sql, args=None, uid=None, tek=False):
    """uid verilirse PostgREST gibi: authenticated rolü + JWT. Hata → istisna."""
    cur.execute("savepoint adim")
    try:
        _kimlik(uid)
        cur.execute(sql, args)
        rows = cur.fetchall() if cur.description else []
        _kimlik(None)
        cur.execute("release savepoint adim")
    except Exception:
        cur.execute("rollback to savepoint adim")
        cur.execute("reset role")
        raise
    if tek:
        return rows[0][0] if rows else None
    return rows

def dene(sql, args=None, uid=None):
    """(True, sonuç) ya da (False, hata kodu)"""
    try:
        return True, q(sql, args, uid, tek=True)
    except Exception as e:
        msg = getattr(e, "pgerror", None) or str(e)
        m = re.search(r"ERROR:\s+([^\n]+)", msg)
        return False, (m.group(1) if m else msg).strip()

def _pgrest(v):
    """PostgREST argümanları JSON'dan TÜRSÜZ (unknown) literal olarak gelir ve
    fonksiyon imzasına göre çözülür. psycopg2 bir Python int'ini `integer`
    diye gönderir; `smallint` parametreli bir fonksiyon o zaman BULUNAMAZ —
    uygulamada olmayan bir hata. Birebir taklit: her değer metin literal."""
    if v is None: return None
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (list, tuple)):
        return "{" + ",".join('"' + str(x).replace('"', '\\"') + '"' for x in v) + "}"
    return str(v)

class _Tursuz(str):
    pass

def rpc(uid, ad, **kw):
    """Uygulamanın `supabase.rpc(ad, {…})` çağrısının birebiri (adlandırılmış argüman)."""
    kw = {k: (None if v is None else psycopg2.extensions.AsIs("'" + _pgrest(v).replace("'", "''") + "'"))
          for k, v in kw.items()}
    arg = ", ".join(f"{k} => %({k})s" for k in kw)
    return dene(f"select to_jsonb(x) from public.{ad}({arg}) x" if ad in TABLO_DONEN
                else f"select public.{ad}({arg})", kw, uid)

TABLO_DONEN = {"host_requests", "my_sent_requests", "discover_availabilities", "discover_people",
               "pending_ratings", "unrated_sessions", "engellediklerim", "invitable_guests"}

def liste(uid, ad, **kw):
    kw = {k: (None if v is None else psycopg2.extensions.AsIs("'" + _pgrest(v).replace("'", "''") + "'"))
          for k, v in kw.items()}
    arg = ", ".join(f"{k} => %({k})s" for k in kw)
    return q(f"select to_jsonb(x) from public.{ad}({arg}) x", kw, uid)

def kod(sonuc):
    return sonuc[1] if not sonuc[0] else "GECTI"

def bakiye(u):
    return q("select coalesce(sum(delta),0) from credit_ledger where user_id=%s", (u,), tek=True)

def id_(r):
    return (r[1] or {}).get("id") if r[0] and isinstance(r[1], dict) else None

# ════════════════════════════════════════════════════════════════════
print("=" * 74)
print("TAM AKIŞ — her adım `authenticated` rolüyle, uygulamanın argümanlarıyla")
print("=" * 74)

def hesap(ad, email):
    uid = str(uuid.uuid4())
    q("insert into auth.users (id, email) values (%s, %s)", (uid, email))
    q("insert into users (id, email, password_hash) values (%s,%s,'x') on conflict (id) do nothing", (uid, email))
    q("insert into profiles (user_id, name, show_on_discovery) values (%s,%s,true) "
      "on conflict (user_id) do update set name = excluded.name", (uid, ad))
    # İletişim doğrulaması (OTP'nin sonucu) — kurulum adımı, akış değil
    q("insert into verifications (user_id, email_verified, phone_verified) values (%s,true,true) "
      "on conflict (user_id) do update set email_verified = true, phone_verified = true", (uid,))
    q("insert into credit_ledger (user_id, delta, reason, balance_after) values (%s, 10, 'e2e', 10)", (uid,))
    return uid

sfx = uuid.uuid4().hex[:6]
H  = hesap("Hale E2E",  f"h_{sfx}@e2e.test")
H2 = hesap("Hakan E2E", f"h2_{sfx}@e2e.test")
G  = hesap("Gül E2E",   f"g_{sfx}@e2e.test")
G2 = hesap("Gani E2E",  f"g2_{sfx}@e2e.test")
G3 = hesap("Gaye E2E",  f"g3_{sfx}@e2e.test")
X  = hesap("Yabancı E2E", f"x_{sfx}@e2e.test")

# ── 0 · Kayıt: rol + sözleşmeler (uygulamanın ilk ekranı) ───────────
print("\n--- 0 · KAYIT")
for u, rol in [(H, "host"), (H2, "host"), (G, "guest"), (G2, "guest"), (G3, "guest"), (X, "guest")]:
    r = rpc(u, "rolumu_sec", p_role=rol, p_gender=None)
    if not r[0]: chk(f"0. rolumu_sec({rol})", False, r[1])
    r2 = rpc(u, "grant_consents", p_types=["no_lounge_sale", "no_offplatform_payment", "community_rules",
                                            "venue_rules", "terms_privacy", "age_18"], p_version="v16")
    if not r2[0]: chk("0. grant_consents", False, r2[1])
chk("0. altı hesap rol ve sözleşmeyle açıldı",
    q("select count(*) from users where id in %s and role is not null", ((H, H2, G, G2, G3, X),), tek=True) == 6)
chk("0. yaş onayı okunuyor (yas_onayim)", rpc(G, "yas_onayim") == (True, True))

# ── 1 · Host kartı + ilan açma ─────────────────────────────────────
print("\n--- 1 · İLAN AÇMA")
for u in (H, H2):
    r = rpc(u, "save_host_access", p_sources=["Havayolu Statüsü"], p_guest_capacity=2,
            p_guest_fee_expected=False, p_quota_total=None, p_quota_period=None, p_quota_used=None,
            p_card_product_id=None, p_card_tier=None)
    chk("1. save_host_access (erişim kaynağı: havayolu statüsü)", r[0], kod(r))
    r = rpc(u, "save_host_card", p_program_code="TK_MS", p_tier="ELPL", p_card_label=None,
            p_guest_capacity=2, p_bank_code=None, p_card_product=None)
    chk("1. save_host_card (THY Elite Plus)", r[0], r[1])
lounge = q("select id from lounges where airport_code='IST' and name='Primeclass Lounge' order by id limit 1", tek=True)
yarin = q("select (current_date + 1)::text", tek=True)
r = rpc(H, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="10:00:00", p_to="13:00:00", p_slots=2, p_flight=None, p_visibility="all", p_carrier="TK")
chk("1. create_availability (uygulamanın 'all' görünürlüğüyle)", r[0], r[1])
AV1 = (r[1] or {}).get("id") if r[0] else None
r = rpc(H, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="14:00:00", p_to="16:00:00", p_slots=1, p_flight=None, p_visibility="all", p_carrier="TK")
AV2 = (r[1] or {}).get("id") if r[0] else None
chk("1. ikinci ilan (tek kişilik)", bool(AV2), r[1])
r = rpc(H, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="12:00:00", p_to="15:00:00", p_slots=1, p_flight=None, p_visibility="all", p_carrier="TK")
chk("1. KENDİ ilanıyla çakışan ilan reddediliyor", not r[0], kod(r))
r = rpc(G, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="18:00:00", p_to="19:00:00", p_slots=1, p_flight=None, p_visibility="all", p_carrier="TK")
chk("1. misafir ilan AÇAMIYOR (not_a_host)", kod(r) == "not_a_host", kod(r))
r = rpc(H, "set_availability_carrier", p_avail_id=AV1, p_carrier="TK")
chk("1. set_availability_carrier", r[0], kod(r))
chk("1. host kendi ilanını RLS ile görüyor",
    q("select count(*) from availabilities where id = %s", (AV1,), uid=H, tek=True) == 1)

# ── 2 · Seyahat ────────────────────────────────────────────────────
print("\n--- 2 · SEYAHAT")
def seyahat(u, bas, bit, kisi=1, cocuk=None, ap="IST", tarih=None, carrier="TK"):
    return rpc(u, "seyahat_ekle", p_airport=ap, p_destination="LHR", p_date=tarih or yarin,
               p_from=bas, p_to=bit, p_flight=None, p_purpose="business", p_carrier=carrier,
               p_kisi=kisi, p_cocuk_yas=cocuk)
r = seyahat(G, "09:00:00", "17:00:00")
chk("2. seyahat_ekle", r[0], kod(r))
VG = q("select id from visits where user_id=%s order by created_at desc limit 1", (G,), uid=G, tek=True)
r = seyahat(G, "10:00:00", "11:00:00")
chk("2. aynı saatte ikinci seyahat reddediliyor", kod(r) == "ayni_saatte_seyahatin_var", kod(r))
r = seyahat(G, "18:00:00", "17:00:00")
chk("2. bitiş < başlangıç reddediliyor", not r[0], kod(r))
r = seyahat(G, "10:00:00", "11:00:00", tarih=q("select (current_date - 1)::text", tek=True))
chk("2. geçmiş tarih reddediliyor", kod(r) == "date_in_past", kod(r))
r = seyahat(G, "20:00:00", "21:00:00", kisi=9)
chk("2. kişi sayısı sınırı (9)", not r[0], kod(r))
for u, b, e in [(G2, "09:30:00", "16:00:00"), (G3, "09:30:00", "12:00:00"), (X, "09:30:00", "16:00:00")]:
    seyahat(u, b, e)
r = rpc(G, "update_visit", p_id=VG, p_airport=None, p_destination="CDG", p_date=None,
        p_from="08:30:00", p_to="17:30:00", p_flight=None, p_carrier="TK", p_purpose="business")
chk("2. update_visit (saat/varış)", r[0], kod(r))
chk("2. düzenleme kaydedildi",
    q("select destination||'/'||time_from::text from visits where id=%s", (VG,), uid=G, tek=True) == "CDG/08:30:00")
r = rpc(G, "set_visit_party", p_visit_id=VG, p_kisi=1, p_cocuk_yas=None)
chk("2. set_visit_party", r[0], kod(r))
chk("2. başkası seyahati GÖREMİYOR (RLS)", q("select count(*) from visits where id=%s", (VG,), uid=X, tek=True) == 0)
r = rpc(X, "seyahat_sil", p_id=VG)
chk("2. başkası seyahati SİLEMİYOR", not r[0], kod(r))

# ── 3 · Keşif: iki taraf aynı şeyi mi görüyor ──────────────────────
print("\n--- 3 · KEŞİF")
kesif = [row[0] for row in liste(G, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)]
k1 = next((x for x in kesif if x["id"] == AV1), None)
chk("3. misafir yeni ilanı Keşfet'te görüyor", bool(k1))
chk("3. has_trip = true (seyahat çakışıyor)", bool(k1 and k1.get("has_trip")))
chk("3. host kendi ilanını Keşfet'te listeliyor (istemci eliyor)",
    any(x["id"] == AV1 for x in (row[0] for row in liste(H, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None))))

# ── 4 · Başvuru: precheck ↔ create_request TUTARLILIĞI ─────────────
print("\n--- 4 · BAŞVURU VE KURAL TUTARLILIĞI")
g_once = bakiye(G)
pre = rpc(G, "request_precheck", p_avail_id=AV1)
chk("4. request_precheck çağrılabiliyor", pre[0], kod(pre))
r = rpc(G, "create_request", p_avail_id=AV1, p_type="lounge", p_intro="Merhaba, kahve?", p_idem=f"{G}:{AV1}")
chk("4. create_request (uygulamanın tekrar-deneme anahtarıyla)", r[0], kod(r))
chk("4. precheck 'başvurabilirsin' dediyse sunucu da kabul etti",
    (pre[1] or {}).get("can_request") is not False and r[0])
R1 = (r[1] or {}).get("id") if r[0] else None
r2 = rpc(G, "create_request", p_avail_id=AV1, p_type="lounge", p_intro="Merhaba, kahve?", p_idem=f"{G}:{AV1}")
chk("4. çift dokunuş aynı isteği döndürüyor (idempotent)", r2[0] and (r2[1] or {}).get("id") == R1)
r3 = rpc(G, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=None)
chk("4. ikinci başvuru anlaşılır kodla reddediliyor", kod(r3) == "already_requested", kod(r3))
chk("4. kredi tutuldu (1 kredi emanette)", bakiye(G) == g_once - 1, f"{g_once} → {bakiye(G)}")
hr = [row[0] for row in liste(H, "host_requests")]
chk("4. HOST gelen isteği host_requests'te görüyor", any(x["id"] == R1 for x in hr))
chk("4. host isteğin notunu görüyor", any(x["id"] == R1 and x.get("intro_message") == "Merhaba, kahve?" for x in hr))
ms = [row[0] for row in liste(G, "my_sent_requests")]
chk("4. MİSAFİR gönderdiğini my_sent_requests'te görüyor", any(x["id"] == R1 and x["status"] == "pending" for x in ms))
chk("4. host'a bildirim düştü", q("select count(*) from notifications where user_id=%s and ref_id=%s", (H, R1), uid=H, tek=True) >= 1)

# Başvuramama kapıları
r = rpc(H, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=None)
chk("4. kendi ilanına başvuru yok", kod(r) == "self_request_blocked", kod(r))
q("delete from verifications where user_id=%s", (X,))
r = rpc(X, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=None)
chk("4. doğrulanmamış iletişim → contact_not_verified", kod(r) == "contact_not_verified", kod(r))
q("insert into verifications (user_id, email_verified) values (%s, true)", (X,))
r = rpc(G3, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
chk("4. seyahat penceresi dışı → no_matching_trip", kod(r) == "no_matching_trip", kod(r))
q("update visits set time_to='17:00' where user_id=%s", (G3,))
_b3 = bakiye(G3)
q("insert into credit_ledger (user_id, delta, reason, balance_after) values (%s, %s, 'admin_e2e', 0)", (G3, -_b3))
r = rpc(G3, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
chk("4. kredisiz → insufficient_credits", kod(r) == "insufficient_credits", kod(r))
q("insert into credit_ledger (user_id, delta, reason, balance_after) values (%s, %s, 'e2e', %s)", (G3, _b3, _b3))
q("update availabilities set min_trust = 95 where id=%s", (AV2,))
r = rpc(G3, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
chk("4. güven eşiği altında → guven_esigi_altinda", kod(r) == "guven_esigi_altinda", kod(r))
chk("4. eşik üstü ilan Keşfet'te de GİZLİ (ekran = sunucu)",
    not any(row[0]["id"] == AV2 for row in liste(G3, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)))
q("update availabilities set min_trust = 0 where id=%s", (AV2,))

# KURAL TUTARLILIĞI — üç yüzey aynı şeyi mi söylüyor?
#   (a) Keşfet rozeti `blocks_request` — misafirden BAĞIMSIZ kurallar
#       (misafir kabul etmiyor, dolu, kural engeli)
#   (b) `request_precheck` — istek sayfası açılınca, MİSAFİRE ÖZEL
#       (kişi sayısı, çocuk, havayolu, kabin, kota)
#   (c) `create_request` — sunucunun son sözü
# Kural: (b) "başvurabilirsin" dediyse (c) kabul etmeli; (b) "olmaz" dediyse
# (c) de reddetmeli. (a) "olmaz" dediyse (c) kesin reddetmeli.
print("    · kural tutarlılığı taranıyor (rozet ↔ ön kontrol ↔ sunucu)…")
uyusmaz, rozet_yalan = [], []
taranan = 0
MISAFIRE_OZEL = ("party_too_big", "children_not_allowed", "guest_carrier_mismatch", "cabin_required",
                 "scope_mismatch", "quota_exhausted", "no_matching_trip", "guven_esigi_altinda",
                 "insufficient_credits", "contact_not_verified", "hosting_same_slot", "blocked_pair")
KAPASITE = ("acik_istek_tavani", "too_many_active_requests", "rate_limited_request", "already_requested")
for (gid,) in q("select distinct v.user_id from visits v join users u on u.id=v.user_id "
                "where public.seed_test_hesabi(u.email) and v.visit_date >= current_date "
                "and u.email not like 'akis.%%' and u.email not like '%%@e2e.test' "
                # 🔴 bu koşunun KENDİ aktörleri taramaya girerse (sıra rastgele,
                # limit 14) tarama onların saatlik istek sayacını doldurur ve
                # §5 'rate_limited' ile düşer — ürün hatası değil, ölçüm kirliliği.
                "order by v.user_id limit 14"):
    for row in liste(gid, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None):
        a = row[0]
        if a["host_id"] == gid or not a.get("has_trip") or a.get("fully_booked"):
            continue
        taranan += 1
        p = rpc(gid, "request_precheck", p_avail_id=a["id"])
        s_ = dene("select public.create_request(%s, 'lounge', null, null)", (a["id"],), gid)
        if s_[0]:
            rid = s_[1].get("id")
            for t_ in ("credit_ledger where ref_id", "notifications where ref_id", "huni_olaylari where ref_id", "requests where id"):
                q(f"delete from {t_} = %s", (rid,))
        q("delete from rate_limits where user_id = %s", (gid,))   # tarama sayacı şişirmesin
        if not s_[0] and s_[1] in KAPASITE:
            continue
        on_izin = (p[1] or {}).get("can_request") if p[0] else None
        sunucu_izin = s_[0]
        if on_izin is not None and bool(on_izin) != sunucu_izin:
            uyusmaz.append((a["id"][:8], "ön:" + str(on_izin), (p[1] or {}).get("gate"), kod(s_)))
        if a.get("blocks_request") and sunucu_izin:
            rozet_yalan.append((a["id"][:8], a.get("block_reason"), "sunucu kabul etti"))
chk(f"4. ön kontrol ↔ sunucu kararı tutarlı ({taranan} ilan×misafir)", not uyusmaz, uyusmaz[:5])
chk("4. Keşfet 'başvurulamaz' dediği ilanı sunucu da reddediyor", not rozet_yalan, rozet_yalan[:5])

# ── 5 · Kabul / ret / iptal ────────────────────────────────────────
print("\n--- 5 · KABUL · RET · İPTAL")
g2_once = bakiye(G2)
r = rpc(G2, "create_request", p_avail_id=AV1, p_type="lounge", p_intro="Ben de!", p_idem=None)
R2 = (r[1] or {}).get("id") if r[0] else None
r = rpc(H, "respond_request", p_request_id=R2, p_action="decline")
chk("5. host REDDETTİ", r[0], kod(r))
chk("5. ret → misafirin kredisi iade", bakiye(G2) == g2_once, f"{g2_once} → {bakiye(G2)}")
chk("5. misafir reddi görüyor (RLS)", q("select status::text from requests where id=%s", (R2,), uid=G2, tek=True) == "declined")
r = rpc(G2, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=f"{G2}:{AV1}")
chk("5. reddedilen misafir aynı ilana YENİDEN başvurabiliyor (yeni istek)", r[0] and (r[1] or {}).get("id") != R2, kod(r))
R2b = (r[1] or {}).get("id") if r[0] else None
r = rpc(G2, "respond_request", p_request_id=R2b, p_action="cancel")
chk("5. misafir bekleyen isteğini İPTAL etti", r[0], kod(r))
r = rpc(G2, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=f"{G2}:{AV1}")
chk("5. iptal sonrası tekrar istek YENİ istek (sessizce eskisi dönmüyor)", r[0] and (r[1] or {}).get("id") not in (R2, R2b), kod(r))
R2c = (r[1] or {}).get("id") if r[0] else None
r = rpc(G, "respond_request", p_request_id=R1, p_action="accept")
chk("5. misafir kendi isteğini KABUL EDEMİYOR", kod(r) == "not_host", kod(r))
r = rpc(H, "respond_request", p_request_id=R1, p_action="accept")
chk("5. host KABUL etti", r[0], kod(r))
CH = (r[1] or {}).get("channel_id") if r[0] else None
chk("5. kabul → sohbet kanalı açıldı", bool(CH))
chk("5. ilan doluluğu 1/2", q("select filled from availabilities where id=%s", (AV1,), tek=True) == 1)
r = rpc(H, "respond_request", p_request_id=R2c, p_action="accept")
chk("5. ikinci kabul → ilan 2/2", r[0] and q("select filled from availabilities where id=%s", (AV1,), tek=True) == 2, kod(r))
r = rpc(G3, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=None)
chk("5. dolu ilana başvuru → fully_booked", kod(r) == "fully_booked", kod(r))

# ── 6 · Sohbet ─────────────────────────────────────────────────────
print("\n--- 6 · SOHBET")
chk("6. istek notu sohbetin ilk mesajı (misafir görüyor)",
    q("select body from messages where channel_id=%s order by created_at limit 1", (CH,), uid=G, tek=True) == "Merhaba, kahve?")
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'Kapıda buluşalım') returning id", (CH, G), G)
chk("6. misafir yazabiliyor (uygulamanın doğrudan insert'i)", r[0], kod(r))
chk("6. host mesajı görüyor", q("select count(*) from messages where channel_id=%s", (CH,), uid=H, tek=True) == 2)
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'10:30 oradayım') returning id", (CH, H), H)
chk("6. host yanıtladı", r[0], kod(r))
chk("6. YABANCI sohbeti okuyamıyor", q("select count(*) from messages where channel_id=%s", (CH,), uid=X, tek=True) == 0)
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'sızma') returning id", (CH, X), X)
chk("6. YABANCI sohbete yazamıyor", not r[0], kod(r))
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'taklit') returning id", (CH, G), H)
chk("6. başkası adına mesaj yazılamıyor", not r[0], kod(r))

# ── 7 · Oturum: başlat · durum · tamamla · puan ────────────────────
print("\n--- 7 · OTURUM")
r = rpc(G, "start_session_request", p_request_id=R1)
chk("7. misafir 'Oturumu başlat' → bekliyor", r[0] and (r[1] or {}).get("status") == "pending", r[1])
SID = (r[1] or {}).get("id") if r[0] else None
chk("7. host bekleyen oturumu görüyor (RLS)", q("select status::text from sessions where id=%s", (SID,), uid=H, tek=True) == "pending")
# 🔴 2 Ekim (SQL 313 · Gökberk md.5) — KURAL DEĞİŞTİ: oturum ancak İKİ TARAF da "Başlat"a
# basınca başlar. Eskiden burada "biri başlattıktan sonra iptal → session_started" bekleniyordu;
# yani tek taraflı basış iptali/geri almayı kilitliyordu (canlıda host "kabulü geri al" diyemedi).
# Tek taraflı başlatılmış buluşmanın iptal/geri alınabildiğini iptal_akisi_e2e (S1 · S3 · S4)
# ölçüyor; burada İKİ taraf başlattıktan SONRA istek üzerinden iptalin kilitli olduğu ölçülür.
r = rpc(H, "start_session_request", p_request_id=R1)
chk("7. host da başlattı → SÜRÜYOR", r[0] and (r[1] or {}).get("status") == "active", r[1])
r = rpc(G, "respond_request", p_request_id=R1, p_action="cancel")
chk("7. iki taraf başlattıktan sonra istekten iptal → session_started", kod(r) == "session_started", kod(r))
r = rpc(H, "share_session_status", p_session_id=SID, p_status="Pencere kenarı")
chk("7. canlı durum paylaşıldı", r[0], kod(r))
chk("7. misafir host'un durumunu görüyor",
    q("select host_status from sessions where id=%s", (SID,), uid=G, tek=True) == "Pencere kenarı")
r = rpc(G, "rate_session", p_session_id=SID, p_score=5, p_comment=None)
chk("7. bitmemiş oturum puanlanamıyor", kod(r) == "not_completed", kod(r))
r = rpc(G, "confirm_session", p_session_id=SID)
chk("7. misafir tamamladı → karşı tarafı bekliyor", r[0] and (r[1] or {}).get("completed") is False, r[1])
r = rpc(H, "confirm_session", p_session_id=SID)
chk("7. host tamamladı → TAMAMLANDI", r[0] and (r[1] or {}).get("completed") is True, r[1])
chk("7. istek de 'completed'", q("select status::text from requests where id=%s", (R1,), uid=G, tek=True) == "completed")
chk("7. puan: host +500, misafir +200",
    q("select string_agg(delta::text, ',' order by delta) from points_ledger where ref_id=%s", (SID,), tek=True) == "200,500")
pr = [row[0] for row in liste(G, "pending_ratings")]
chk("7. misafirin puanlanacaklar listesinde", any(x["session_id"] == SID for x in pr))
r = rpc(G, "rate_session", p_session_id=SID, p_score=5, p_comment="Harika sohbet")
chk("7. misafir puanladı", r[0], kod(r))
r = rpc(G, "rate_session", p_session_id=SID, p_score=4, p_comment=None)
chk("7. ikinci puan → already_rated", kod(r) == "already_rated", kod(r))
r = rpc(H, "rate_session", p_session_id=SID, p_score=6, p_comment=None)
chk("7. 1–5 dışı puan reddediliyor", not r[0], kod(r))
r = rpc(X, "rate_session", p_session_id=SID, p_score=1, p_comment=None)
chk("7. yabancı puanlayamıyor", not r[0], kod(r))
r = rpc(H, "rate_session", p_session_id=SID, p_score=5, p_comment=None)
chk("7. host puanladı", r[0], kod(r))
chk("7. puanlar karşı tarafa yazıldı",
    q("select count(*) from ratings where session_id=%s", (SID,), tek=True) == 2)

# ── 8 · Gelmedi (301) ──────────────────────────────────────────────
print("\n--- 8 · GELMEDİ")
r = rpc(G2, "start_session_request", p_request_id=R2c)
S2 = (r[1] or {}).get("id") if r[0] else None
r = rpc(G2, "gelmedi_bildir", p_request_id=R2c)
chk("8. 15 dk dolmadan 'gelmedi' → gelmedi_erken", kod(r) == "gelmedi_erken", kod(r))
r = rpc(H, "gelmedi_bildir", p_request_id=R2c)
chk("8. başlatmayan taraf bildiremez → gelmedi_once_baslat", kod(r) == "gelmedi_once_baslat", kod(r))
q("update sessions set guest_started_at = now() - interval '16 minutes' where id=%s", (S2,))
once = q("select sum(delta) from credit_ledger where user_id=%s", (G2,), tek=True)
r = rpc(G2, "gelmedi_bildir", p_request_id=R2c)
chk("8. 16 dk sonra misafir 'host gelmedi' bildirdi", r[0], kod(r))
chk("8. oturum no_show, gelmeyen = host",
    q("select status::text||'/'||cancel_reason||'/'||(no_show_user_id=%s)::text from sessions where id=%s", (H, S2), tek=True) == "expired/no_show/true")
chk("8. misafirin kredisi iade", q("select sum(delta) from credit_ledger where user_id=%s", (G2,), tek=True) == once + 1)
chk("8. ilan kapasitesi geri açıldı (1/2)", q("select filled from availabilities where id=%s", (AV1,), tek=True) == 1)
chk("8. host'a bildirim", q("select count(*) from notifications where user_id=%s and ref_id=%s and title='Buluşma kapandı'", (H, R2c), uid=H, tek=True) == 1)
r = rpc(G2, "gelmedi_bildir", p_request_id=R2c)
chk("8. ikinci bildirim yok", not r[0], kod(r))
r = rpc(G2, "gelmedi_esigi")
chk("8. eşik uygulamaya açık ve sunucuyla aynı (15)", r[0] and r[1] == 15, r)
chk("8. misafire 'kredin iade edildi' bildirimi (iade > 0 iken)",
    q("select count(*) from notifications where user_id=%s and ref_id=%s and body like '%%iade edildi%%'", (G2, R2c), uid=G2, tek=True) == 1)
r = rpc(H, "open_dispute", p_session=S2, p_reason="diger", p_detail="oradaydım")
chk("8. 'gelmedi' denen taraf itiraz açabiliyor (expired oturum)", r[0], kod(r))

# ── 9 · Kapıda alınmadım (aktif oturum) ────────────────────────────
print("\n--- 9 · KAPIDA ALINMADIM")
# G2 son dakikalarda 5 istek attı; saatlik istek sınırı (10/saat, rl_guard)
# gerçek bir kullanıcıyı bu hızda durdurur — doğru. Testte "bir saat geçti":
q("delete from rate_limits where user_id = %s", (G2,))
r = rpc(G2, "create_request", p_avail_id=AV1, p_type="lounge", p_intro=None, p_idem=None)
chk("9. yeni istek (gelmedi sonrası aynı ilana)", r[0], kod(r))
R9 = id_(r)
r = rpc(H, "respond_request", p_request_id=R9, p_action="accept"); chk("9. kabul", r[0], kod(r))
r = rpc(G2, "start_session_request", p_request_id=R9); chk("9. misafir başlattı", r[0], kod(r))
r = rpc(H, "start_session_request", p_request_id=R9)
S9 = (r[1] or {}).get("id") if r[0] else None
r = rpc(G2, "kapida_ret_bildirebilir_mi", p_session_id=S9)
chk("9. kapıda ret bildirilebilir mi sorusu çalışıyor", r[0], kod(r))
r = rpc(G2, "kapida_giremedim", p_session_id=S9, p_sebep="kural_tutmadi", p_aciklama=None)
chk("9. misafir 'kapıda alınmadım' bildirdi", r[0] and (r[1] or {}).get("ok") is not False, r[1])
r = rpc(G2, "open_dispute", p_session=S9, p_reason="kapida_ret", p_detail="Görevli kartı kabul etmedi")
chk("9. itiraz açıldı", r[0] or kod(r) == "dispute_already_open", kod(r))

# ── 10 · Davet: gönder · reddet · kabul · iptal ────────────────────
print("\n--- 10 · DAVET")
r = rpc(H, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="16:30:00", p_to="17:30:00", p_slots=2, p_flight=None, p_visibility="all", p_carrier="TK")
AV3 = (r[1] or {}).get("id") if r[0] else None
r = rpc(H, "send_invite", p_guest=G3, p_avail_id=AV3, p_note="Gel")
chk("10. geçmişi olmayana davet yok (cold_invite_blocked)", kod(r) == "cold_invite_blocked", kod(r))
ig = [row[0] for row in liste(H, "invitable_guests", p_avail_id=AV3)]
chk("10. davet edilebilirler listesi çalışıyor", True, f"{len(ig)} kişi")
r = rpc(H, "send_invite", p_guest=G, p_avail_id=AV3, p_note="Yine gel!")
chk("10. host, eski misafirini davet etti", r[0], kod(r))
INV = q("select id from invites where host_id=%s and guest_id=%s and status='pending'", (H, G), uid=G, tek=True)
chk("10. misafir daveti görüyor (RLS)", bool(INV))
r = rpc(G, "respond_invite", p_id=INV, p_accept=False)
chk("10. misafir daveti REDDETTİ", r[0], kod(r))
chk("10. host reddi görüyor", q("select status::text from invites where id=%s", (INV,), uid=H, tek=True) == "declined")
r = rpc(G, "respond_invite", p_id=INV, p_accept=True)
chk("10. yanıtlanmış davet tekrar yanıtlanamıyor", kod(r) == "already_responded", kod(r))
rpc(H, "send_invite", p_guest=G, p_avail_id=AV3, p_note="Son kez?")
INV2 = q("select id from invites where host_id=%s and guest_id=%s and status='pending'", (H, G), uid=G, tek=True)
r = rpc(G, "respond_invite", p_id=INV2, p_accept=True)
chk("10. misafir daveti KABUL etti → istek kabul + sohbet", r[0] and (r[1] or {}).get("channel_id"), r[1])
RI = (r[1] or {}).get("request_id") if r[0] else None
r = rpc(G, "respond_request", p_request_id=RI, p_action="cancel")
chk("10. davetle açılan buluşma İPTAL edilebiliyor (300/B2)", r[0], kod(r))

# ── 11 · İlan düzenle / kaldır / yeniden yayınla ───────────────────
print("\n--- 11 · İLAN DÜZENLE · KALDIR")
r_ = rpc(H, "update_availability", p_id=AV3, p_date=None, p_from=None, p_to=None, p_slots=4,
        p_lounge_id=None, p_lounge_name=None, p_flight=None, p_visibility=None, p_carrier=None,
        p_cabin=None, p_charter=None, p_min_trust=None)
chk("11. kart kapasitesini aşan kontenjan reddediliyor", kod(r_) == "slots_exceed_capacity", kod(r_))
r = rpc(H, "update_availability", p_id=AV3, p_date=None, p_from="16:00:00", p_to="17:45:00", p_slots=2,
        p_lounge_id=None, p_lounge_name=None, p_flight="TK1", p_visibility=None, p_carrier=None,
        p_cabin=None, p_charter=None, p_min_trust=None)
chk("11. ilan düzenlendi (saat + kontenjan)", r[0], kod(r))
chk("11. misafir değişikliği Keşfet'te görüyor",
    any(row[0]["id"] == AV3 and row[0]["time_to"] == "17:45:00" for row in liste(G2, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)))
r = rpc(G2, "update_availability", p_id=AV3, p_date=None, p_from=None, p_to=None, p_slots=1,
        p_lounge_id=None, p_lounge_name=None, p_flight=None, p_visibility=None, p_carrier=None,
        p_cabin=None, p_charter=None, p_min_trust=None)
chk("11. başkasının ilanı düzenlenemiyor", not r[0], kod(r))
r = rpc(G3, "create_request", p_avail_id=AV3, p_type="lounge", p_intro=None, p_idem=None)
R11 = (r[1] or {}).get("id") if r[0] else None
chk("11. kaldırılacak ilana bekleyen istek var", bool(R11), kod(r))
g3_once = bakiye(G3)
r = rpc(H, "cancel_availability", p_id=AV3, p_force=True)
chk("11. ilan kaldırıldı (uygulama p_force=true gönderiyor)", r[0], kod(r))
chk("11. bekleyen istek kapandı", q("select status::text from requests where id=%s", (R11,), uid=G3, tek=True) in ("cancelled", "declined"))
chk("11. bekleyen misafirin kredisi iade", bakiye(G3) == g3_once + 1, f"{g3_once} → {bakiye(G3)}")
chk("11. kaldırılan ilan Keşfet'ten düştü",
    not any(row[0]["id"] == AV3 for row in liste(G2, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)))
r = rpc(H, "ilani_yeniden_yayinla", p_id=AV3)
chk("11. ilan yeniden yayınlandı", r[0] and (r[1] or {}).get("ok") is not False, r[1])

# ── 12 · Seyahat silme kuralları ───────────────────────────────────
print("\n--- 12 · SEYAHAT SİL")
VG2 = q("select id from visits where user_id=%s order by created_at desc limit 1", (G2,), uid=G2, tek=True)
acik = q("select count(*) from requests where visit_id=%s and status in ('pending','accepted')", (VG2,), tek=True)
if acik < 2:
    r = rpc(G2, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
    acik = q("select count(*) from requests where visit_id=%s and status in ('pending','accepted')", (VG2,), tek=True)
r = rpc(G2, "seyahat_sil", p_id=VG2)
chk(f"12. {acik} açık başvurulu seyahat silinemiyor (anlaşılır kodla)", kod(r) == "seyahat_silinemez_basvuru_var", kod(r))
kapali = q("select count(*) from requests where visit_id=%s and status not in ('pending','accepted')", (VG,), tek=True)
acik_g = q("select count(*) from requests where visit_id=%s and status in ('pending','accepted')", (VG,), tek=True)
r = rpc(G, "seyahat_sil", p_id=VG)
chk(f"12. yalnız KAPALI başvurusu olan seyahat silinebiliyor ({kapali} kapalı, {acik_g} açık)",
    r[0] if acik_g == 0 else kod(r) == "seyahat_silinemez_basvuru_var", kod(r))
chk("12. geçmiş istek kaydı korunuyor (bağ koptu, satır duruyor)",
    q("select count(*) from requests where guest_id=%s", (G,), tek=True) >= kapali)
r = seyahat(G, "09:00:00", "17:00:00")
chk("12. (hazırlık) G yeni seyahat", r[0], kod(r))

# ── 13 · Bağlantı: gönder · reddet · kabul · sohbet · kaldır ───────
print("\n--- 13 · BAĞLANTI")
r = rpc(G, "send_connection", p_to=G2, p_intent="coffee", p_intro="Aynı rotadayız")
chk("13. bağlantı isteği gönderildi", r[0], kod(r))
C1 = q("select id from connection_requests where from_id=%s and to_id=%s", (G, G2), uid=G2, tek=True)
chk("13. alıcı gelen isteği görüyor (RLS)", bool(C1))
r = rpc(G, "send_connection", p_to=G2, p_intent="coffee", p_intro="tekrar")
chk("13. aynı kişiye ikinci istek → connection_exists", kod(r) == "connection_exists", kod(r))
r = rpc(G, "respond_connection", p_id=C1, p_accept=True)
chk("13. gönderen kendi isteğini kabul edemiyor", not r[0], kod(r))
r = rpc(G2, "respond_connection", p_id=C1, p_accept=False)
chk("13. alıcı REDDETTİ", r[0], kod(r))
r = rpc(G, "send_connection", p_to=G2, p_intent="coffee", p_intro="bir daha")
chk("13. ret sonrası 7 gün soğuma", kod(r) == "baglanti_soguma", kod(r))
r = rpc(G3, "send_connection", p_to=G, p_intent="coffee", p_intro="Selam")
C2 = q("select id from connection_requests where from_id=%s and to_id=%s", (G3, G), uid=G, tek=True)
r = rpc(G, "respond_connection", p_id=C2, p_accept=True)
chk("13. KABUL", r[0], kod(r))
r = rpc(G, "baglanti_sohbeti_ac", p_conn_id=C2)
chk("13. bağlantı sohbeti açıldı", r[0], kod(r))
CC = q("select id from chat_channels where connection_id=%s", (C2,), uid=G, tek=True)
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'Selam!') returning id", (CC, G3), G3)
chk("13. bağlantı sohbetine yazılıyor", r[0], kod(r))
chk("13. karşı taraf okuyor", q("select count(*) from messages where channel_id=%s", (CC,), uid=G, tek=True) >= 1)
chk("13. yabancı okuyamıyor", q("select count(*) from messages where channel_id=%s", (CC,), uid=X, tek=True) == 0)
r = rpc(G, "baglanti_kaldir", p_conn_id=C2)
chk("13. bağlantı kaldırıldı", r[0], kod(r))

# ── 14 · Bildir + ENGELLE (301) ────────────────────────────────────
print("\n--- 14 · BİLDİR · ENGELLE")
r = rpc(G3, "create_report", p_target=H, p_type="harassment", p_description="Rahatsız edici mesajlar", p_session=None)
if not r[0] and "invalid input value for enum" in r[1]:
    tip = q("select enumlabel from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='report_type' order by enumsortorder limit 1", tek=True)
    r = rpc(G3, "create_report", p_target=H, p_type=tip, p_description="Rahatsız edici mesajlar", p_session=None)
chk("14. bildirim oluşturuldu", r[0], kod(r))
r4 = rpc(G3, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
R14 = (r4[1] or {}).get("id") if r4[0] else None
chk("14. engellenecek host'a açık istek var", bool(R14), kod(r4))
g3_once = bakiye(G3)
r = rpc(G3, "engelle", p_user=H, p_sebep="taciz")
chk("14. ENGELLE çalışıyor", r[0], kod(r))
print("      (R14:", q("select status::text from requests where id=%s", (R14,), tek=True), "· defter:",
      q("select string_agg(reason||':'||delta, ', ' order by created_at) from credit_ledger where ref_id=%s", (R14,), tek=True), ")")
chk("14. bekleyen isteği kapandı + kredi iade",
    q("select status::text from requests where id=%s", (R14,), tek=True) == "cancelled"
    and bakiye(G3) == g3_once + 1)
chk("14. engellenen host'un ilanları Keşfet'ten düştü",
    not any(row[0]["host_id"] == H for row in liste(G3, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)))
r = rpc(G3, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
chk("14. engelli çifte istek yok", kod(r) == "blocked_pair", kod(r))
r = rpc(H, "send_connection", p_to=G3, p_intent="coffee", p_intro="?")
chk("14. engellenen, bağlantı isteği atamıyor", kod(r) == "blocked_pair", kod(r))
eng = [row[0] for row in liste(G3, "engellediklerim")]
chk("14. engellediklerim listesinde", any(x["user_id"] == H for x in eng))
chk("14. engel sebebi listede taşınıyor (BO/uygulama)", any(x["user_id"] == H and x.get("sebep") == "taciz" for x in eng))
chk("14. engellenen, engeli GÖREMİYOR (sessiz engel)", q("select count(*) from blocks where blocked=%s", (H,), uid=H, tek=True) == 0)
r = rpc(G3, "engelle", p_user=G3)
chk("14. kendini engelleyemez", kod(r) == "cannot_block_self", kod(r))
r = rpc(G3, "engeli_kaldir", p_user=H)
chk("14. engel kaldırıldı", r[0] and not any(True for _ in liste(G3, "engellediklerim")))

# Engellenen çiftin AÇIK sohbetine mesaj yazılamaz
r = rpc(X, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
chk("14. (hazırlık) X yeni istek", r[0], kod(r))
R15 = id_(r)
r = rpc(H, "respond_request", p_request_id=R15, p_action="accept")
CH15 = (r[1] or {}).get("channel_id") if r[0] else None
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'selam') returning id", (CH15, X), X)
chk("14. engel ÖNCESİ X sohbete yazabiliyor", r[0], kod(r))
rpc(H, "engelle", p_user=X, p_sebep=None)
r = dene("insert into messages (channel_id, from_id, body) values (%s,%s,'hâlâ burada mısın') returning id", (CH15, X), X)
chk("14. engellenen, açık sohbete de yazamıyor", not r[0], kod(r))
chk("14. kabul edilmiş (başlamamış) buluşma da kapandı",
    q("select status::text from requests where id=%s", (R15,), tek=True) == "cancelled")

# ── 14b · Kabul edilmiş misafiri olan ilan (p_force=false) ─────────
rpc(G, "create_request", p_avail_id=AV2, p_type="lounge", p_intro=None, p_idem=None)
RP = q("select id from requests where guest_id=%s and avail_id=%s and status='pending'", (G, AV2), tek=True)
rpc(H, "respond_request", p_request_id=RP, p_action="accept")
r = rpc(H, "cancel_availability", p_id=AV2, p_force=False)
chk("14b. kabul edilmiş misafiri olan ilan p_force=false ile kapanmıyor",
    not r[0] or (r[1] or {}).get("ok") is False, r[1] if r[0] else kod(r))
chk("14b. ilan hâlâ yayında", q("select active from availabilities where id=%s", (AV2,), tek=True) is True)

# ── 15 · Profil kartı + keşifte görün (300) ────────────────────────
print("\n--- 15 · PROFİL · AYARLAR")
k = rpc(G, "profil_karti", p_user=H)
chk("15. başkasının doğrulama rozetleri okunuyor", k[0] and (k[1] or {}).get("phone_verified") is True, k[1])
r = rpc(H, "kesifte_gorun", p_acik=False)
chk("15. 'Keşifte göster' kapatıldı", r[0], kod(r))
chk("15. kapalıyken ilanları Keşfet'te yok",
    not any(row[0]["host_id"] == H for row in liste(G, "discover_availabilities", p_airport="IST", p_sector=None, p_flight=None, p_date=None)))
rpc(H, "kesifte_gorun", p_acik=True)
r = dene("update profiles set show_on_discovery = false where user_id = %s", (H,), H)
chk("15. kolon doğrudan yazılamıyor (kapı zorunlu)", not r[0], kod(r))

# ── 16 · Test hesapları gerçek kullanıcıdan gizli (301) ────────────
print("\n--- 16 · TEST HESABI GİZLEME")
R_ = str(uuid.uuid4())
q("insert into auth.users (id, email) values (%s, %s)", (R_, f"gercek_{sfx}@ornek.com"))
q("insert into users (id, email, password_hash) values (%s,%s,'x') on conflict (id) do nothing", (R_, f"gercek_{sfx}@ornek.com"))
gor = [row[0] for row in liste(R_, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None)]
test_host = q("select count(*) from users where id = any(%s::uuid[]) and public.seed_test_hesabi(email)",
              ([x["host_id"] for x in gor] or [str(uuid.uuid4())],), tek=True)
chk("16. gerçek kullanıcı test hostlarını GÖRMÜYOR", test_host == 0, f"{len(gor)} ilan, {test_host} test")
chk("16. test hesabı test ilanlarını GÖRÜYOR",
    len(liste(G, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None)) > 0)
# 302 · kişi bazında açma: bayrak AÇIK kalır, yalnız listedeki gerçek hesap görür
R2_ = str(uuid.uuid4())
q("insert into auth.users (id, email) values (%s, %s)", (R2_, f"gercek2_{sfx}@ornek.com"))
q("insert into users (id, email, password_hash) values (%s,%s,'x') on conflict (id) do nothing", (R2_, f"gercek2_{sfx}@ornek.com"))
q("insert into test_gorunurlugu (user_id, ekleyen) values (%s, 'e2e')", (R_,))
gor2 = [row[0] for row in liste(R_, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None)]
chk("16. (302) listeye eklenen gerçek hesap test ilanlarını GÖRÜYOR", len(gor2) > len(gor), f"{len(gor)} → {len(gor2)}")
gor3 = [row[0] for row in liste(R2_, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None)]
chk("16. (302) listede olmayan gerçek hesap hâlâ GÖRMÜYOR", len(gor3) == len(gor), f"{len(gor3)} vs {len(gor)}")
chk("16. (302) liste uygulamadan OKUNAMIYOR", not dene("select count(*) from test_gorunurlugu", None, R_)[0])
chk("16. (302) kişi kendini listeye YAZAMIYOR",
    not dene("insert into test_gorunurlugu (user_id) values (%s) returning 1", (R2_,), R2_)[0])
q("delete from test_gorunurlugu where user_id = %s", (R_,))
q("update feature_flags set enabled = false where key = 'test_hesaplarini_gizle'")
chk("16. BO bayrağı kapatınca gerçek kullanıcı da görüyor",
    len(liste(R_, "discover_availabilities", p_airport=None, p_sector=None, p_flight=None, p_date=None)) > len(gor))

# ── 17 · Yan akışlar: haber ver · bildirim · iptal penceresi · puan erteleme ──
print("\n--- 17 · YAN AKIŞLAR")
r = rpc(G3, "talep_birak", p_airport="AYT", p_bas=yarin, p_bit=q("select (current_date+5)::text", tek=True))
chk("17. 'Haber ver' kaydı bırakıldı", r[0], kod(r))
tl = q("select to_jsonb(x) from public.taleplerim() x", uid=G3)
chk("17. taleplerim listesinde", len(tl) >= 1, len(tl))
TID = q("select id from talep_kayitlari where user_id=%s order by created_at desc limit 1", (G3,), tek=True)
q("delete from rate_limits where user_id = %s", (H2,))
r = rpc(H2, "create_availability", p_lounge_id=q("select id from lounges where airport_code='AYT' order by name limit 1", tek=True),
        p_airport="AYT", p_date=yarin, p_from="10:00:00", p_to="11:00:00", p_slots=1, p_flight=None, p_visibility="all", p_carrier="TK")
chk("17. AYT'de ilan açılınca 'haber ver' bekleyenine bildirim düştü",
    r[0] and q("select count(*) from notifications where user_id=%s and ref_type='availability' and ref_id=%s", (G3, id_(r)), uid=G3, tek=True) == 1, kod(r))
r = rpc(G3, "talebi_kaldir", p_id=TID)
chk("17. 'haber ver' kaldırıldı", r[0], kod(r))
NID = q("select id from notifications where user_id=%s and not coalesce(read,false) limit 1", (G3,), uid=G3, tek=True)
r = rpc(G3, "bildirim_okundu", p_id=NID)
chk("17. bildirim okundu işaretlendi", r[0] and q("select read from notifications where id=%s", (NID,), uid=G3, tek=True) is True, kod(r))
r = rpc(X, "bildirim_okundu", p_id=NID)
chk("17. başkasının bildirimi işaretlenemiyor",
    (not r[0]) or q("select count(*) from notifications where id=%s", (NID,), uid=X, tek=True) == 0, kod(r))
# oturum iptali: ilk 5 dk içinde iade
q("delete from rate_limits where user_id in %s", ((G, H),))
r = rpc(H, "create_availability", p_lounge_id=lounge, p_airport="IST", p_date=yarin,
        p_from="20:00:00", p_to="21:00:00", p_slots=1, p_flight=None, p_visibility="all", p_carrier="TK")
AV5 = id_(r)
seyahat(G, "19:30:00", "22:00:00")
g_once = bakiye(G)
r = rpc(G, "create_request", p_avail_id=AV5, p_type="lounge", p_intro=None, p_idem=None); R17 = id_(r)
rpc(H, "respond_request", p_request_id=R17, p_action="accept")
rpc(G, "start_session_request", p_request_id=R17)
r = rpc(H, "start_session_request", p_request_id=R17); S17 = (r[1] or {}).get("id") if r[0] else None
r = rpc(G, "cancel_session", p_session_id=S17, p_reason="plan_degisti")
chk("17. oturum ilk 5 dk içinde iptal edildi", r[0], kod(r))
chk("17. 5 dk içindeki iptalde kredi iade", bakiye(G) == g_once, f"{g_once} → {bakiye(G)}")
chk("17. ilan kapasitesi geri açıldı", q("select filled from availabilities where id=%s", (AV5,), tek=True) == 0)
r = rpc(G, "defer_rating", p_session=SID)
chk("17. puan erteleme çağrılabiliyor", r[0] or kod(r) in ("already_rated",), kod(r))

cx.rollback()
print()
print("=" * 74)
print(f"{len(ok)} geçti · {len(bad)} düştü")
for b in bad: print("   ✗", b)
print("=" * 74)
sys.exit(1 if bad else 0)
