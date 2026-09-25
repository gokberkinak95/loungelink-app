#!/usr/bin/env python3
"""
gate_check.py — MOTORUN HER KAPISI KULLANICI DİLİNE ÇEVRİLMİŞ Mİ?

🔴 NEDEN VAR
Kural motoru bir kullanıcıyı durdurduğunda `raise exception 'x'` atar ve
PostgREST bunu ham metin olarak app'e taşır. app/i18n'de karşılığı yoksa
kullanıcı ekranda `not_open` ya da `rate_limited_request` görür.

Bu, "hata gösterimi" meselesi değil ÜRÜN meselesidir: kullanıcı neden
durdurulduğunu anlamazsa ürünün bozuk olduğunu düşünür. Ölçüldüğünde
app'ten ULAŞILABİLEN 11 kapının çevirisi yoktu (103 kapının 20'si toplamda).

NE YAPAR
1. ETKIN_TANIMLAR.sql'den her fonksiyonun gövdesini çıkarır.
2. App'in gerçekten çağırdığı RPC'leri (rpc("...")) toplar.
3. O RPC'lerin gövdesindeki her `raise exception '<kod>'` için i18n'de
   karşılık arar ("<kod>" veya e_<kod>).
4. Karşılıksız kapı varsa exit 1 — build durur.

KAPSAM DIŞI (bilinçli): app'in çağırmadığı BO/iç fonksiyonların kapıları.
Onlar admin ekranında görünür ve teknik okur kitlesi vardır.
"""
import re
import sys
import pathlib

# 🔴 ll_paths.require_sql(name) İMZASI: bir ad ister ve SQL KLASÖRÜNÜ
# döndürür (dosya değil). v2.46'da beş araç bu göçten atlanıp yanlış
# yere bakmıştı — aynı hatayı tekrarlamamak için imza okundu.
ROOT = pathlib.Path(__file__).parent
try:
    import ll_paths
    SQL = pathlib.Path(ll_paths.require_sql("gate_check.py")[0])
except Exception:
    SQL = ROOT / "sql"

DEFS = SQL / "ETKIN_TANIMLAR.sql"
if not DEFS.exists():
    print(f"HATA: {DEFS} yok — snapshot_gen.py ile üretilmeli")
    sys.exit(1)

# 🔴 19 Agu 2026 — BAYAT SNAPSHOT SESSIZCE KOR NOKTA URETIYOR.
# Bu denetim ETKIN_TANIMLAR.sql'i okuyor ve o dosya ELLE uretiliyor
# (`npm run snapshot`). Bugun olctum: dosya 12 Agustos'ta uretilmisti ve
# yalniz 157 numarali migration'a kadar olan halleri iceriyordu.
# Yani 158-225 arasi 68 dosyanin kapilari HIC TARANMAMISTI — denetim
# yesil yaniyordu ama ucte birine bakmiyordu. Tazeleyince dort kapi
# birden "i18n karsiligi yok" diye kirmizi yandi (bad_purpose,
# gecersiz_deger, kart_yok ×2).
#
# Hatirlanmasi gereken bir uretici, unutulur. Artik unutulunca BAGIRIYOR:
# snapshot en yeni SQL dosyasindan eskiyse denetim durur.
_snap_mtime = DEFS.stat().st_mtime
_yeni = [f for f in SQL.glob("*.sql") if f.name != "ETKIN_TANIMLAR.sql"
         and f.stat().st_mtime > _snap_mtime + 5]
if _yeni:
    print(f"HATA: ETKIN_TANIMLAR.sql BAYAT — {len(_yeni)} SQL dosyasi ondan yeni.")
    print("      En yenisi: " + max(_yeni, key=lambda f: f.stat().st_mtime).name)
    print("      Bu denetim bayat dokumu tararsa yeni kapilari GORMEZ.")
    print("      Cozum:  npm run snapshot")
    sys.exit(1)

sql = DEFS.read_text(encoding="utf-8")
app_src = ""
for f in ["src/screens.js", "App.js", "src/i18n.js"]:
    p = ROOT / f
    if p.exists():
        app_src += p.read_text(encoding="utf-8")
i18n = (ROOT / "src" / "i18n.js").read_text(encoding="utf-8")

# fonksiyon gövdeleri (aynı ad birden çok kez tanımlıysa hepsi birleşir —
# hangi sürümün canlıda olduğunu bilemeyiz, en geniş kümeyi denetleriz)
bodies = {}
for m in re.finditer(r"(?:create or replace|CREATE OR REPLACE) FUNCTION public\.([a-z_0-9]+)\(", sql, re.I):
    name = m.group(1)
    i = m.start()
    e = re.search(r"\$(function)?\$\s*;", sql[i:])
    bodies[name] = bodies.get(name, "") + sql[i:i + (e.end() if e else 2000)]

called = set(re.findall(r'rpc\(\s*"([a-z_0-9]+)"', app_src))
problems = []
total_gates = 0
for fn in sorted(called):
    body = bodies.get(fn, "")
    for gate in sorted(set(re.findall(r"raise exception '([a-z_0-9]+)'", body))):
        total_gates += 1
        if f'"{gate}"' not in i18n and f"e_{gate}" not in i18n:
            problems.append((fn, gate))

print("=" * 60)
print("KAPI DENETİMİ — motorun durdurma sebepleri kullanıcı dilinde mi?")
print("=" * 60)
print(f"App'in çağırdığı RPC: {len(called)} · denetlenen kapı: {total_gates}")
if problems:
    for fn, gate in problems:
        print(f"  ✗ {fn}() → '{gate}' için i18n karşılığı YOK (kullanıcı ham kod görür)")
    print(f"\n✗ {len(problems)} kapı çevrilmemiş")
    sys.exit(1)
print("\n✓ her kapının kullanıcı dilinde karşılığı var")
sys.exit(0)
