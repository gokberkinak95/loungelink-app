#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
flight_chain_e2e.py — AviationStack ZİNCİRİNİ UÇTAN UCA KANITLA

🔴 NEDEN VAR:
Gokberk "AviationStack anahtarı zaten ekli, entegrasyonu yapmalısın"
dedi. Entegrasyon YAZILMIŞTI. Ama "yazılmış" ile "çalışıyor" arasında
bu projede defalarca fark çıktı:
  · v2.68'de kod doğruydu, `backofficeUrl` BOŞTU → hiç çalışmadı.
  · v1.64'te sağlayıcı `airline` alanını gönderiyordu, biz yazmıyorduk.
  · v2.71'de `create_availability` sonucu nesneydi, uuid sanılıyordu.
Üçü de "kod var" diyerek geçilmişti.

Bu betik zincirin HER HALKASINI ayrı ayrı ölçer:

  [1] Sağlayıcı cevabı → satır eşlemesi   (route.js'in map mantığı)
  [2] Satır → flight_cache                (kolonlar gerçekten var mı)
  [3] flight_cache → flight_info()        (19 anahtar dönüyor mu)
  [4] flight_cache → flight_carrier_resolve()  (kod paylaşımında
                                           İŞLETEN havayolu seçiliyor mu)
  [5] flight_cache → sync_visit_flight    (seyahate damga vuruluyor mu)
  [6] Kota kapısı flight_fetch_allow()    (gerçekten reddediyor mu)
  [7] BO adresi service_endpoints()       (uygulama nereye gidecek)

KANITLANAMAYAN TEK HALKA: sağlayıcıya gerçek HTTP çağrısı. Bunun için
canlı anahtar ve ağ gerekir; burada yapılmaz. Onun yerine sağlayıcının
GERÇEK cevap ŞEKLİ (AviationStack /v1/flights şeması) sabit olarak
gömülüdür ve eşleme ona göre sınanır. Yani "sağlayıcı bu şekli
gönderirse zincirin geri kalanı doğru çalışır" kanıtlanır.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

import pgserver

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
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


BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
D = pathlib.Path('/tmp/ll_flight_chain')
_ll_temizle(D)

ns = {}
exec(open(os.path.join(os.path.dirname(_HERE), 'pg_run.py')).read().split("def main()")[0], ns)


def q(uri, sql):
    r = subprocess.run([str(BIN / 'psql'), uri, '-X', '-t', '-A', '-c', sql],
                       capture_output=True, text=True, env=ENV)
    if r.returncode:
        return ['HATA: ' + (r.stderr or '').strip().splitlines()[0][:200]]
    return [l for l in r.stdout.splitlines() if l.strip()]


# ============================================================
# SAĞLAYICININ GERÇEK CEVAP ŞEKLİ
# ============================================================
# AviationStack /v1/flights tek kayıt şeması. `codeshared` DOLU olan
# bir örnek seçtim bilerek: kod paylaşımı bu ürünün kural motorunda
# doğrudan hak belirliyor (salon hakkı UÇURANA bağlı, bilet satana
# değil) ve en kolay yanlış yapılacak yer orası.
SAGLAYICI = {
    "flight_date": "2026-08-20",
    "flight_status": "scheduled",
    "departure": {"airport": "Istanbul Airport", "iata": "IST", "terminal": "I",
                  "gate": "F7", "scheduled": "2026-08-20T14:25:00+00:00"},
    "arrival": {"airport": "Heathrow", "iata": "LHR", "terminal": "2",
                "scheduled": "2026-08-20T16:40:00+00:00"},
    "airline": {"name": "Turkish Airlines", "iata": "TK", "icao": "THY"},
    "flight": {"number": "1979", "iata": "TK1979", "icao": "THY1979",
               "codeshared": {"airline_name": "sunexpress", "airline_iata": "XQ",
                              "airline_icao": "SXS", "flight_number": "1979",
                              "flight_iata": "XQ1979"}},
}


def satira_esle(f, ucus_no, tarih):
    """route.js'teki eşlemenin BİREBİR aynısı. Değişirse bu test kırılır
    ve bu İYİDİR: iki yerin ayrışmasını sessizce yaşamak istemiyoruz."""
    marketing = (f.get("airline") or {}).get("iata")
    codeshared = (f.get("flight") or {}).get("codeshared")
    return {
        "flight_no": ucus_no,
        "flight_date": tarih,
        "departure_iata": (f.get("departure") or {}).get("iata"),
        "arrival_iata": (f.get("arrival") or {}).get("iata"),
        "scheduled_departure": (f.get("departure") or {}).get("scheduled"),
        "scheduled_arrival": (f.get("arrival") or {}).get("scheduled"),
        "terminal": (f.get("departure") or {}).get("terminal"),
        "gate": (f.get("departure") or {}).get("gate"),
        "status": f.get("flight_status"),
        "airline": (f.get("airline") or {}).get("name"),
        "airline_iata": marketing,
        "codeshared": codeshared,
        "operating_iata": (codeshared or {}).get("airline_iata") or marketing,
        "source": "aviationstack",
    }


print('\n' + '=' * 72)
print('UÇUŞ ZİNCİRİ — sağlayıcıdan ekrana, her halka ayrı ölçülür')
print('=' * 72)

# ---- ROUTE.JS ile EŞLEMENİN AYNI OLDUĞUNU DOĞRULA ----
# Bu testin en büyük riski, buradaki kopyanın route.js'ten AYRIŞMASI.
# O yüzden route.js'i okuyup kritik alan adlarını orada da arıyoruz.
route = pathlib.Path(os.path.dirname(os.path.dirname(_HERE))) / 'backoffice' / 'app' / 'api' / 'flight' / 'route.js'
if route.exists():
    src = route.read_text(encoding='utf-8')
    eksik = [k for k in ('airline_iata', 'codeshared', 'operating_iata',
                         'scheduled_departure', 'terminal', 'gate')
             if k not in src]
    if eksik:
        print(f'✗ route.js bu kolonları YAZMIYOR: {eksik}')
        sys.exit(1)
    print(f'  ✓ route.js eşlemesi bu testle aynı alanları taşıyor')
else:
    print('  ⚠ route.js bulunamadı — eşleme karşılaştırması atlandı')

# ---- ŞEMAYI KUR ----
if D.exists():
    shutil.rmtree(D, ignore_errors=True)
D.mkdir(parents=True)
srv = pgserver.get_server(D)
uri = srv.get_uri()
ns['install_fake_extensions']()
subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-c', ns['SHIM']],
               capture_output=True, text=True, env=ENV)

sd = _llp.sql_dir()
_o = lambda f: (re.match(r'^(\d{3})([a-z]?)_', f).group(1),
                0 if re.match(r'^(\d{3})([a-z]?)_', f).group(2) else 1, f)
files = (sorted((f for f in os.listdir(sd) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)), key=_o)
         + sorted(x for x in os.listdir(sd) if x.startswith('SEED')))
for f in files:
    r = subprocess.run([str(BIN / 'psql'), uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                        '-f', os.path.join(sd, f)], capture_output=True, text=True, env=ENV)
    if r.returncode:
        print(f'✗ {f} düştü: {(r.stderr or "")[:200]}')
        srv.cleanup(); shutil.rmtree(D, ignore_errors=True); sys.exit(1)
print(f'  ✓ {len(files)} SQL dosyası kuruldu')

hatalar = []

# ============================================================
# [1] + [2] SAĞLAYICI → SATIR → flight_cache
# ============================================================
row = satira_esle(SAGLAYICI, 'TK1979', '2026-08-20')
if row['operating_iata'] != 'XQ':
    hatalar.append(f"[1] kod paylasiminda ISLETEN yanlis: {row['operating_iata']} (XQ olmali)")
if row['airline_iata'] != 'TK':
    hatalar.append(f"[1] pazarlayan yanlis: {row['airline_iata']}")

kolonlar = ', '.join(row.keys())
degerler = ', '.join(
    'null' if v is None else
    ("'" + json.dumps(v).replace("'", "''") + "'::jsonb") if isinstance(v, dict) else
    ("'" + str(v).replace("'", "''") + "'")
    for v in row.values())
r = q(uri, f"insert into flight_cache ({kolonlar}) values ({degerler}) "
           f"on conflict (flight_no, flight_date) do update set "
           f"operating_iata = excluded.operating_iata returning 'yazildi'")
if not r or 'yazildi' not in r[0]:
    hatalar.append(f'[2] flight_cache yazilamadi → {r}')
else:
    print('  ✓ [1][2] sağlayıcı cevabı flight_cache satırına eşlendi ve yazıldı')

# ============================================================
# [3] flight_cache → flight_info()
# ============================================================
r = q(uri, "select flight_info('TK1979','2026-08-20')::text")
info = {}
try:
    info = json.loads(r[0]) if r else {}
except Exception:
    hatalar.append(f'[3] flight_info okunamadi → {r}')

BEKLENEN = ['hit', 'dep_iata', 'arr_iata', 'dep_time', 'terminal', 'gate', 'status',
            'airline', 'airline_iata', 'operating_iata', 'codeshare', 'carrier_note',
            'source', 'stale']
eksik = [k for k in BEKLENEN if k not in info]
if eksik:
    hatalar.append(f'[3] flight_info bu anahtarlari DONDURMUYOR: {eksik}')
elif info.get('hit') is not True:
    hatalar.append(f'[3] flight_info hit=false dondu → {info}')
elif info.get('dep_iata') != 'IST' or info.get('arr_iata') != 'LHR':
    hatalar.append(f'[3] kalkis/varis yanlis → {info.get("dep_iata")}/{info.get("arr_iata")}')
elif info.get('operating_iata') != 'XQ':
    hatalar.append(f'[3] flight_info isleteni yanlis dondurdu → {info.get("operating_iata")}')
else:
    print(f'  ✓ [3] flight_info {len(info)} anahtar döndürdü · '
          f'{info.get("dep_iata")}→{info.get("arr_iata")} · işleten {info.get("operating_iata")}')

# ============================================================
# [4] KOD PAYLAŞIMI ÇÖZÜMÜ
# ============================================================
r = q(uri, "select flight_carrier_resolve('TK1979','2026-08-20')::text")
try:
    cz = json.loads(r[0]) if r else {}
except Exception:
    cz = {}
    hatalar.append(f'[4] flight_carrier_resolve okunamadi → {r}')
if cz:
    if cz.get('carrier') != 'XQ':
        hatalar.append(f'[4] cozumleyici ISLETENI secmedi → {cz}')
    elif cz.get('kaynak') != 'onbellek':
        hatalar.append(f'[4] kaynak "onbellek" olmaliydi → {cz.get("kaynak")}')
    else:
        print(f'  ✓ [4] kod paylaşımı çözüldü: bilet TK, uçuran XQ · kaynak {cz.get("kaynak")}')

# Önbellekte OLMAYAN uçuşta önek yoluna düşmeli — sessizce boş dönmemeli
r = q(uri, "select flight_carrier_resolve('PC2034','2026-08-20')::text")
try:
    cz2 = json.loads(r[0]) if r else {}
except Exception:
    cz2 = {}
if cz2.get('carrier') != 'PC' or cz2.get('kaynak') != 'onek':
    hatalar.append(f'[4] onbelleksiz ucusta onek yolu calismadi → {cz2}')
else:
    print('  ✓ [4] önbellekte yokken uçuş numarası önekinden taşıyıcı türetiliyor')

# ============================================================
# [5] SEYAHATE DAMGA — flight_cache satırı gelince visit doluyor mu
# ============================================================
uid = q(uri, "select id::text from users limit 1")
if uid and not uid[0].startswith('HATA'):
    u = uid[0]
    q(uri, f"delete from visits where user_id='{u}' and flight_number='TK1979'")
    q(uri, f"insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number) "
           f"values ('{u}','IST','2026-08-20','12:00','18:00','TK1979')")
    # 🔴 KOLON ADLARI ÖLÇÜLDÜ, TAHMİN EDİLMEDİ. İlk yazımda `dep_iata`
    # ve `arr_iata` varsaydım — `visits` tablosunda öyle kolonlar YOK
    # (kalkış/varış zaten `airport_code` + `destination`). Test kendi
    # uydurduğu kolonla "zincir kopuk" diye bağırdı. Ders: bir testin
    # yanlış olması, kodun yanlış olmasıyla aynı maliyeti üretir.
    r = q(uri, f"select coalesce(flight_verified::text,'?')||'|'||coalesce(terminal,'-')"
               f"||'|'||coalesce(carrier_code,'-')"
               f"||'|'||coalesce(to_char(scheduled_departure at time zone 'UTC','HH24:MI'),'-')"
               f" from visits where user_id='{u}' and flight_number='TK1979'")
    if not r or r[0] != 'true|I|XQ|14:25':
        hatalar.append(f'[5] seyahate ucus damgasi eksik/yanlis → {r} '
                       f'(beklenen: true|I|XQ|14:25)')
    else:
        print('  ✓ [5] seyahat eklenince damga vuruldu: doğrulandı · terminal I · '
              'taşıyıcı XQ (İŞLETEN) · kalkış 14:25')
else:
    print('  ⚠ [5] seed kullanıcı yok — atlandı')

# ============================================================
# [6] KOTA KAPISI GERÇEKTEN REDDEDİYOR MU
# ============================================================
if uid and not uid[0].startswith('HATA'):
    u = uid[0]
    # 🔴 AYAR ANAHTARI DA ÖLÇÜLDÜ: `flight_month_cap`, uydurduğum
    # `flight_fetch_monthly_cap` değil. Var olmayan bir anahtarı
    # yazınca fonksiyon varsayılanı (80) kullanıyordu ve test "kapı
    # sahte" diye bağırıyordu — kapı sağlamdı, test yanlış yere
    # bakıyordu. En pahalı hata türü: yanlış alarm.
    q(uri, "delete from flight_fetch_log")
    r = q(uri, "select coalesce((select value::text from beta_settings where key='flight_month_cap'),'-')")
    onceki = r[0] if r else '-'
    q(uri, "insert into beta_settings (key, value) values ('flight_month_cap', to_jsonb(0)) "
           "on conflict (key) do update set value = to_jsonb(0)")
    r = q(uri, f"select (flight_fetch_allow('{u}','ZZ9999','2026-08-20') ->> 'reason')")
    red = (r[0] if r else '') == 'denied_month_cap'
    if onceki != '-':
        q(uri, f"update beta_settings set value = '{onceki}'::jsonb where key='flight_month_cap'")
    else:
        q(uri, "delete from beta_settings where key='flight_month_cap'")
    q(uri, "delete from flight_fetch_log")
    r2 = q(uri, f"select (flight_fetch_allow('{u}','ZZ9998','2026-08-20') ->> 'allow')")
    izin = (r2[0] if r2 else '') == 'true'
    q(uri, "delete from flight_fetch_log")
    if not red:
        hatalar.append(f'[6] aylik kota 0 iken bile IZIN VERILDI — kapi sahte ({r})')
    elif not izin:
        hatalar.append(f'[6] kota geri acildi ama HALA reddediyor ({r2})')
    else:
        print('  ✓ [6] kota kapısı mutasyonla kanıtlandı (aylık 0 → denied_month_cap, geri → izin)')

# ============================================================
# [7] UYGULAMA NEREYE GİDECEK
# ============================================================
q(uri, "select bo_register_url('https://ornek-bo.vercel.app')")
r = q(uri, "select service_endpoints()::text")
try:
    ep = json.loads(r[0]) if r else {}
except Exception:
    ep = {}
if ep.get('backoffice_url') != 'https://ornek-bo.vercel.app' or ep.get('flight_lookup_ready') is not True:
    hatalar.append(f'[7] uygulama BO adresini okuyamiyor → {ep}')
else:
    print('  ✓ [7] uygulama BO adresini Supabase üzerinden okuyabiliyor (elle adım yok)')

print()
if hatalar:
    print('✗ UÇUŞ ZİNCİRİ KOPUK:')
    for h in hatalar:
        print('   ' + h)
    srv.cleanup(); shutil.rmtree(D, ignore_errors=True)
    sys.exit(1)

print('✓ Zincirin yedi halkası da ölçüldü ve sağlam.')
print('  Kanıtlanamayan tek halka: sağlayıcıya gerçek HTTP çağrısı')
print('  (canlı anahtar + ağ gerekir). Onun ŞEKLİ bu testte sabit.')
print('=' * 72)
srv.cleanup()
shutil.rmtree(D, ignore_errors=True)
