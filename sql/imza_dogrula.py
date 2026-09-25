# -*- coding: utf-8 -*-
"""
imza_dogrula.py — ADAY IMZALARI **IKI NOKTADAN** OLCER

🔴 BIRINCI SURUMUN HATASI (22 Agustos)
Dosya basina TEK imza secip tabloyu urettim; tam kurulu bir veritabaninda
31 dosya "KOSMADI" dedi. Hepsi yanlis negatifti: sectigim izler SONRAKI
dosyalarca EZILMISTI. Cozum: dosya basina 8 aday tasi, tam kurulu
veritabaninda AYAKTA KALANI sec.
🆕 SINIF: "BIR IZ, UZERINE YAZILABILIYORSA IZ DEGILDIR."

🔴 IKINCI SURUMUN HATASI (13 Eylul · bugun)
"Ayakta kalmak" YETMIYOR. 285'e kadar kurulu bir veritabaninda tabloyu
kostum ve 286 · 287 · 290 "KOSTU" dedi — UCU DE KURULU DEGILDI:
  · 286 → izi `discover_people_prebfilter`; o fonksiyon ZATEN vardi,
          benim "ilk kez bu dosyada geciyor" cikarimim yanilmisti.
  · 287 → izi `v_uid uuid := public.kimlik(p_user);`; onceki `my_plan`
          govdesinde de vardi, govde ayiklayicim o tanimi kacirmisti.
  · 290 → izi "notlarda Turkce harf var"; 285'te de 91 satirda vardi.
Ucu de AYNI KOKTEN: izin "yeni" oldugunu KAYNAK KODDAN CIKARIYORDUM.
Regex'im bir tanimi kacirirsa iz sahte cikiyor ve tablo, KURULMAMIS bir
dosyaya "kuruldu" diyor — bu, tablonun yapabilecegi EN KOTU hata.

🆕 SINIF: **"BIR IZIN YENI OLDUGUNU KAYNAK KODA BAKARAK KARAR VERMEK
CIKARIMDIR; IZ OLDUGUNU ANCAK DOSYADAN ONCE YOK, SONRA VAR OLDUGUNU
OLCEREK BILIRSIN."**

Bu surum dosyalari TEK TEK kuruyor ve her dosyanin adaylarini UC KEZ
olcuyor:
    ONCE  → false olmali  (yoksa iz degil, zaten oradaydi)
    SONRA → true  olmali  (yoksa dosya bu izi birakmiyor)
    SON   → true  olmali  (yoksa sonraki dosyalar ezmis)
Ucunu birden gecen ILK aday secilir. Hicbiri gecmezse dosya BILINMIYOR —
uydurma bir "kosmadi" yerine durustce bilinmiyor.
"""
import os, re, sys, json, shutil, subprocess
import pgserver

SQL = os.path.dirname(os.path.abspath(__file__))
RNAPP = os.path.join(os.path.dirname(SQL), 'rnapp')
sys.path.insert(0, RNAPP)

ns = {}
exec(open(os.path.join(RNAPP, 'pg_run.py'), encoding='utf-8').read()
     .replace("if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns['install_fake_extensions']()

PSQL = os.path.join(os.path.dirname(pgserver.__file__), 'pginstall', 'bin', 'psql')
D = '/tmp/ll_imza_dogrula'


def sirali():
    def o(f):
        m = re.match(r'^(\d{3})([a-z]?)_', f)
        # 🔴 «HARF SONEKI VARSA ANA DOSYADAN ONCE KOSAR» VARSAYIMI YANLIS.
        # Dogru olan yalniz `*_PRE_*` dosyalari icin: 024a_PRE_drop, 037a…
        # Ama 268a_telefon_cakismasi, 269a_DOGRULAMA_KONTROL, 270a..270e
        # PRE degil — hepsi ana dosyanin SONUCUNU okuyan teshis dosyalari.
        # Once kosturulunca 268a «column phone_kanonik does not exist» ile
        # dusuyordu: 268 o kolonu HENUZ eklememisti.
        # 🆕 SINIF: "BIR ADLANDIRMA KURALINI, KURALI DOGURAN DURUMUN
        # DISINA TASIRSAN KURAL OLMAKTAN CIKIP VARSAYIM OLUR."
        pre = '_PRE_' in f
        return (m.group(1), 0 if pre else 1, f)
    return sorted((f for f in os.listdir(SQL) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)), key=o)


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def olc(uri, cift):
    """[(dosya,tip,ad)] → {(dosya,tip,ad): bool}. Tek sorguda."""
    if not cift:
        return {}
    vals = ",".join("(%s,%s,%s)" % (q(d), q(t), q(a)) for d, t, a in cift)
    sql = ("with a(dosya,tip,ad) as (values %s) "
           "select dosya||E'\\t'||tip||E'\\t'||ad||E'\\t'||"
           "coalesce(public.kurulum_imzasi_var(tip,ad)::text,'null') from a" % vals)
    # 🔴 `-c` ILE GECERKEN SON OLCUM «Argument list too long» ile DUSTU:
    # 304 dosya x 16 aday = 4000'den fazla satirlik tek bir sorgu, kabuk
    # arguman sinirini asiyor. Sorgu dosyadan besleniyor.
    tmp = os.path.join('/tmp', 'll_imza_olcum.sql')
    with open(tmp, 'w', encoding='utf-8') as fh:
        fh.write(sql)
    r = subprocess.run([PSQL, uri, '-X', '-t', '-A', '-f', tmp], capture_output=True, text=True)
    if r.returncode != 0:
        print("🔴 olcum sorgusu patladi:", r.stderr[:600]); sys.exit(2)
    out = {}
    for satir in r.stdout.splitlines():
        p = satir.split('\t')
        if len(p) == 4:
            out[(p[0], p[1], p[2])] = (p[3] == 'true')
    return out


def main():
    adaylar = json.load(open(os.path.join(SQL, 'imza_adaylari.json'), encoding='utf-8'))
    aday_map = {d: [tuple(k) for k in l] for d, l in adaylar}

    shutil.rmtree(D, ignore_errors=True)
    srv = pgserver.get_server(D)
    uri = srv.get_uri()
    subprocess.run([PSQL, uri, '-X', '-q', '-c', ns['SHIM']], capture_output=True, text=True)

    # Imza okuyucusunu EN BASTA kur — her dosyadan once/sonra olcebilmek icin.
    tab = open(os.path.join(SQL, 'KURULUM_TABLOSU.sql'), encoding='utf-8').read()
    kes = tab.index('-- 3) DEFTERİ TESPİTLE DOLDUR')
    r = subprocess.run([PSQL, uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-c', tab[:kes]],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("🔴 imza okuyucu kurulamadi:", r.stderr[:800]); sys.exit(2)

    once, sonra, dusen = {}, {}, []
    for f in sirali():
        cift = [(f, t, a) for t, a in aday_map.get(f, []) if t != 'eslikci']
        once.update(olc(uri, cift))
        rr = subprocess.run([PSQL, uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                             '-f', os.path.join(SQL, f)], capture_output=True, text=True)
        if rr.returncode != 0:
            dusen.append((f, (rr.stderr or '').strip().split('\n')[0][:150]))
        sonra.update(olc(uri, cift))

    # Ucuncu olcum: her sey kurulduktan SONRA hala ayakta mi?
    hepsi = [(d, t, a) for d, l in adaylar for t, a in l if t != 'eslikci']
    son = olc(uri, hepsi)

    if dusen:
        print(f"⚠️  KURULUMDA DUSEN DOSYA: {len(dusen)}")
        for f, e in dusen:
            print(f"    {f}  →  {e}")
        print("    (bunlarin BILINMIYOR cikmasi IZ eksikligi degil KURULUM hatasidir)")

    secim, bilinmiyor, eslikci, sahte = [], [], [], []
    for dosya, liste in adaylar:
        secildi = None
        for tip, ad in liste:
            k = (dosya, tip, ad)
            if tip == 'eslikci':
                secildi = (tip, ad); eslikci.append(dosya); break
            if once.get(k) is True:
                sahte.append((dosya, tip, ad))      # dosyadan ONCE de vardi
                continue
            if sonra.get(k) is True and son.get(k) is True:
                secildi = (tip, ad); break
        if secildi:
            secim.append([dosya, secildi[0], secildi[1]])
        else:
            secim.append([dosya, None, None])
            bilinmiyor.append(dosya)

    json.dump(secim, open(os.path.join(SQL, 'imzalar.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    n = len(secim)
    print(f"dosya: {n} · OLCULMUS imza: {n-len(bilinmiyor)} · BILINMIYOR: {len(bilinmiyor)} "
          f"(eslikci: {len(eslikci)})")
    print(f"ONCE DE VAR OLDUGU ICIN ELENEN aday: {len(sahte)}  "
          f"← eski surumun sahte 'kuruldu' dedigi yer")
    if bilinmiyor:
        print("  BILINMIYOR: " + ", ".join(bilinmiyor))
    print("→ imzalar.json yazildi (yalniz ONCE-YOK / SONRA-VAR / SON-VAR izler)")


if __name__ == '__main__':
    main()
