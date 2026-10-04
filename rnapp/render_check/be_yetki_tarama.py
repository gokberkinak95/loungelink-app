# -*- coding: utf-8 -*-
"""
be_yetki_tarama.py — SUNUCU (BE) YETKİ TARAMASI · 4 Ekim 2026

Soru: bir kullanıcı (ya da giriş yapmamış biri) yetkisi olmayan bir fonksiyonu
ÇAĞIRABİLİYOR mu, ve çağırabiliyorsa gövde onu durduruyor mu?

  1) BO'nun çağırdığı her fonksiyon (backoffice/ kaynağından okunur):
     authenticated / anon EXECUTE hakkı var mı? Varsa gövdede yönetici kapısı
     (yonetici_kapisi · admin_roles · is_staff) var mı?
  2) Uygulamanın çağırdığı her fonksiyon: anon EXECUTE hakkı var mı? Varsa
     bilinçli kamuya açık liste (salon rehberi vb.) dışında mı?
  3) SECURITY DEFINER olup veri YAZAN (insert/update/delete) ve authenticated'a
     açık her fonksiyonun gövdesinde auth.uid() kontrolü var mı?
Çıktı: bulgu listesi; açık bulgu varsa çıkış 1.
"""
import os, re, sys, glob, json
try:
    import psycopg2
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pg8000_psycopg2; pg8000_psycopg2.kur(); import psycopg2

KOK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DSN = dict(host="127.0.0.1", dbname=os.environ.get("PGDATABASE", "ll"), user="postgres", password="ll",
           port=int(os.environ.get("PGPORT", "5432")))

def kaynak_rpc(kok, dizinler):
    adlar = set()
    for d in dizinler:
        for f in glob.glob(os.path.join(kok, d, "**", "*.js*"), recursive=True):
            if "node_modules" in f or "_arsiv" in f or ".next" in f:
                continue
            g = open(f, encoding="utf-8", errors="replace").read()
            adlar.update(re.findall(r"rpc\(\s*[\"'`]([a-z_0-9]+)", g))
    return adlar

BO = kaynak_rpc(os.path.join(KOK, "backoffice"), ["app", "lib", "components"])
APP = kaynak_rpc(os.path.join(KOK, "rnapp"), ["src"]) | kaynak_rpc(os.path.join(KOK, "rnapp"), ["."]) - set()
# Bilinçli olarak giriş yapmadan da açık (salon rehberi, açılış ekranı, metin katmanı, istemci bayrakları)
KAMU = {"guide_airports", "guide_lounges", "guide_programs", "guide_hosts_today", "client_flags", "i18n_overrides",
        "service_endpoints", "log_client_error", "card_product_options", "carrier_options", "plan_options",
        "subscription_plans", "card_tier_options", "travel_style_options", "amenities_for", "venue_price_list",
        "venue_partners", "lounges_for_airport", "flight_info", "kural_kosullari", "hangi_kartimi_kullanayim",
        "card_advice_for_lounge", "alternatives_for", "salon_misafir_karsilastirmasi", "kabin_sorulmali_mi",
        "active_campaigns", "talep_yogunlugu", "havalimani_nabzi",
        "dogrulama_kanali",      # doğrulama kanalı yapılandırması (gizli veri yok)
        "sogu_baslangic_ozeti"}  # havalimanı salon/program sayımları — açılışta kayıtsız da gösterilir
# Bilinçli: SECURITY DEFINER + yazan + kullanıcı çağırabilir — gerekçeleri:
YAZAN_IZIN = {
    "expire_stale_sessions": "genel süpürge; 5 dk eşiğiyle kendini kısıtlar (supurge_damgasi), idempotent",
    "plan_kredisi_yerlestir": "kimlik() ile yalnız kendi hesabı; ay başına idempotent (plan_monthly:YYYY-MM)",
}
KAPI = re.compile(r"yonetici_kapisi|admin_roles|is_staff|service_role|current_user\s*=|session_user|partner_lounges|lounge_partners|partner_yetki|partner_gate\(|kimlik\(", re.I)

c = psycopg2.connect(**DSN); cur = c.cursor()
cur.execute("""select p.proname, p.prosecdef, p.prosrc,
                      has_function_privilege('authenticated', p.oid, 'execute'),
                      has_function_privilege('anon', p.oid, 'execute')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public'""")
F = {}
for ad, secdef, src, au, an in cur.fetchall():
    f = F.setdefault(ad, {"secdef": False, "src": "", "auth": False, "anon": False})
    f["secdef"] |= secdef; f["src"] += src or ""; f["auth"] |= au; f["anon"] |= an

bulgu = []
# 1) BO fonksiyonları
bo_yok = sorted(x for x in BO if x not in F)
for ad in sorted(BO & set(F)):
    f = F[ad]
    if ad in APP:          # app da çağırıyorsa kullanıcı fonksiyonudur (ör. mark_password_changed)
        continue
    if (f["auth"] or f["anon"]) and not KAPI.search(f["src"]):
        bulgu.append(("BO", ad, "authenticated=%s anon=%s ve gövdede yönetici kapısı YOK" % (f["auth"], f["anon"])))
# 2) App fonksiyonları: anon
for ad in sorted(APP & set(F)):
    f = F[ad]
    if f["anon"] and ad not in KAMU:
        bulgu.append(("APP-anon", ad, "giriş yapmamış ziyaretçi çağırabiliyor (kamu listesinde değil)"))
# 3) Yazan SECURITY DEFINER + authenticated, auth.uid() yok
YAZ = re.compile(r"\b(insert\s+into|update\s+\w+\s+set|delete\s+from)\b", re.I)
for ad, f in sorted(F.items()):
    if f["secdef"] and f["auth"] and YAZ.search(f["src"]) and "auth.uid()" not in f["src"] and not KAPI.search(f["src"]):
        if ad.startswith(("trg_", "_", "handle_")) or ad in YAZAN_IZIN:
            continue
        bulgu.append(("YAZAN", ad, "SECURITY DEFINER · authenticated çağırabilir · veri yazıyor · auth.uid()/yönetici kontrolü yok"))

print("BO fonksiyonu: %d (veritabanında olmayan: %d %s)" % (len(BO), len(bo_yok), bo_yok[:8]))
print("App fonksiyonu: %d" % len(APP & set(F)))
print("Bulgu: %d" % len(bulgu))
for t, ad, n in bulgu:
    print("  ✗ [%s] %s — %s" % (t, ad, n))
json.dump([dict(tur=t, fonksiyon=a, not_=n) for t, a, n in bulgu],
          open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "be_yetki_tarama.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
sys.exit(1 if bulgu else 0)
