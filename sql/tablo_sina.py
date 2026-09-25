# -*- coding: utf-8 -*-
"""
tablo_sina.py — KURULUM_TABLOSU.sql'i UC DURUMDA OLCER

🔴 NEDEN VAR
Bu tablonun tek isi "hangi dosya kostu" demek. Dogru cevabi verdigini
gorebilecegimiz TEK yol, cevabini BILDIGIMIZ veritabanlarinda denemek:

  A. TAM KURULU (330 dosya)      → hic ❌ KOSMADI olmamali
  B. 285'E KADAR KURULU          → 286..294 tam olarak ❌ olmali,
                                    "BURADAN DEVAM ET" = 286 olmali
  C. BOS VERITABANI              → patlamadan calismali

B, bu tablonun ASIL kullanildigi durum: Gokberk bir yerde kalmis ve
nerede kaldigini soruyor. A'yi gecip B'yi gecmeyen bir tablo, "her sey
kurulu" demekten baska bir sey bilmiyor demektir.

🆕 SINIF: "BIR TESHIS ARACI, YALNIZ SAGLIKLI HASTADA DENENMISSE
DENENMEMISTIR — ASIL SINAV HASTA OLANDIR."
"""
import os, re, sys, shutil, subprocess
import pgserver

SQL = os.path.dirname(os.path.abspath(__file__))
RNAPP = os.path.join(os.path.dirname(SQL), 'rnapp')
sys.path.insert(0, RNAPP)
ns = {}
exec(open(os.path.join(RNAPP, 'pg_run.py'), encoding='utf-8').read()
     .replace("if __name__ == '__main__':\n    sys.exit(main())", ""), ns)
ns['install_fake_extensions']()
PSQL = os.path.join(os.path.dirname(pgserver.__file__), 'pginstall', 'bin', 'psql')


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


def kur(dizin, tavan=None):
    """tavan: bu numaraya (dahil) kadar kur. None → hepsi."""
    shutil.rmtree(dizin, ignore_errors=True)
    srv = pgserver.get_server(dizin)
    uri = srv.get_uri()
    subprocess.run([PSQL, uri, '-X', '-q', '-c', ns['SHIM']], capture_output=True, text=True)
    n = 0; dusen = []
    for f in sirali():
        if f.startswith('000_'):
            continue                     # rapor dosyasi, migration degil
        if tavan is not None and f[:3] > tavan:
            continue
        r = subprocess.run([PSQL, uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                            '-f', os.path.join(SQL, f)], capture_output=True, text=True)
        if r.returncode != 0:
            dusen.append((f, (r.stderr or '').strip().split('\n')[0][:140]))
        n += 1
    if dusen:
        print(f"  ⚠️  kurulumda dusen: {len(dusen)}")
        for f, e in dusen[:8]:
            print(f"     {f} → {e}")
    return uri, n


def calistir(uri):
    r = subprocess.run([PSQL, uri, '-X', '-t', '-A', '-F', '\t', '-f',
                        os.path.join(SQL, 'KURULUM_TABLOSU.sql')],
                       capture_output=True, text=True, timeout=900)
    if r.returncode != 0:
        return None, r.stderr[-1500:]
    satir = []
    for s in r.stdout.splitlines():
        p = s.split('\t')
        if len(p) >= 4:
            satir.append(p)
    return satir, None


def rapor(ad, satirlar):
    ozet = {}
    for p in satirlar:
        if p[1].startswith('>>>'):
            ozet[p[1]] = p[2]
    durum = {}
    for p in satirlar:
        if p[1].startswith('>>>'):
            continue
        d = p[2]
        durum[d] = durum.get(d, 0) + 1
    print(f"\n── {ad}")
    for k, v in ozet.items():
        print(f"   {k}  {v}")
    for k in sorted(durum):
        print(f"   {k:32s} {durum[k]}")
    return ozet, durum


hata = []

SEED = ['SEED_KURAL_SENARYOLARI.sql', 'SEED2_KAYNAK_SENARYOLARI.sql',
        'SEED3_UCTAN_UCA.sql', 'SEED4_KURAL_VITRINI.sql',
        'SEED5_BASVURU_AKISLARI.sql', 'SEED6_TEST_DUNYASI.sql',
        # 🔴 21 EYLUL — SEED7'yi tabloya ekledim ama SINAVIN kurulum
        # listesine eklemeyi unuttum. Sonuc: "tam kurulu" dedigi
        # veritabaninda SEED7 ❌ cikti ve bunu SEED7'nin kusuru sandim.
        # Yukaridaki yorumun anlattigi hatanin BIREBIR TEKRARI.
        # 🆕 SINIF: "BIR SINAVIN KURDUGU DUNYA, SINADIGI LISTEDEN
        # KISAYSA, SINAV KENDI EKSIGINI URUNE FATURA EDER."
        'SEED7_TEZGAH.sql']


def seed_kur(uri):
    # 🔴 ILK SINAVDA SEED'LERI HIC KURMADIM ve "tam kurulu" durumda alti
    # SEED dosyasi ❌ cikti; onlari hata sandim. Hata bendeydi: sinav
    # "tam kurulu" dedigi veritabanini tam kurmamisti.
    # 🆕 SINIF: "'TAM KURULU' DEDIGIN VERITABANINI TAM KURMADIYSAN,
    # OLCTUGUN SEY ARACIN DOGRULUGU DEGIL KENDI IHMALINDIR."
    for f in SEED:
        subprocess.run([PSQL, uri, '-X', '-q', '-v', 'ON_ERROR_STOP=1',
                        '-f', os.path.join(SQL, f)], capture_output=True, text=True)


# ── A · TAM KURULU ────────────────────────────────────────────────────
uri, n = kur('/tmp/ll_sina_tam')
seed_kur(uri)
print(f"A · tam kurulu ({n} dosya)")
sA, e = calistir(uri)
if e:
    print("✗ SORGU PATLADI:", e); sys.exit(2)
ozetA, durA = rapor("A · TAM KURULU", sA)
kosmadiA = [p[1] for p in sA if p[2].startswith('❌')]
if kosmadiA:
    hata.append(f"A: tam kurulu veritabaninda {len(kosmadiA)} dosya ❌ diyor → {kosmadiA[:10]}")

# ── B · 285'E KADAR ───────────────────────────────────────────────────
uri2, n2 = kur('/tmp/ll_sina_285', tavan='285')
print(f"\nB · 285'e kadar kurulu ({n2} dosya)")
sB, e = calistir(uri2)
if e:
    print("✗ SORGU PATLADI:", e); sys.exit(2)
ozetB, durB = rapor("B · 285'E KADAR", sB)
bekleniyor = [f for f in sirali() if f[:3] > '285']
eksik_diyor = {p[1] for p in sB if p[2].startswith('❌')}
kacirilan = [f for f in bekleniyor if f not in eksik_diyor]
fazladan = [f for f in eksik_diyor if f[:3] <= '285']
devam = ozetB.get('>>> BURADAN DEVAM ET <<<', '')
print(f"   kurulmamis 9 dosyadan ❌ diyen: {len(bekleniyor)-len(kacirilan)}/{len(bekleniyor)}")
if kacirilan:
    print(f"   ⚠️  KACIRILAN: {kacirilan}")
if fazladan:
    print(f"   ⚠️  YANLIS ❌ (kurulu oldugu halde): {fazladan}")
if not devam.startswith('286'):
    hata.append(f"B: 'BURADAN DEVAM ET' 286 olmali, '{devam}' dedi")
if kacirilan:
    hata.append(f"B: kurulmamis {len(kacirilan)} dosyayi kaciriyor → {kacirilan}")
if fazladan:
    hata.append(f"B: kurulu {len(fazladan)} dosyaya KOSMADI diyor → {fazladan}")

# ── C · BOS ───────────────────────────────────────────────────────────
shutil.rmtree('/tmp/ll_sina_bos', ignore_errors=True)
srv3 = pgserver.get_server('/tmp/ll_sina_bos')
uri3 = srv3.get_uri()
subprocess.run([PSQL, uri3, '-X', '-q', '-c', ns['SHIM']], capture_output=True, text=True)
sC, e = calistir(uri3)
if e:
    hata.append("C: bos veritabaninda patliyor → " + e[-300:])
    print("\n── C · BOS\n   ✗ patladi")
else:
    ozetC, durC = rapor("C · BOS VERITABANI", sC)
    if not ozetC.get('>>> BURADAN DEVAM ET <<<', '').startswith('001'):
        hata.append("C: bos veritabaninda 001'den baslamasi gerekirdi, "
                    f"'{ozetC.get('>>> BURADAN DEVAM ET <<<')}' dedi")

print("\n" + "=" * 60)
if hata:
    for h in hata:
        print("✗ " + h)
    sys.exit(1)
print("✓ UC DURUMUN UCU DE GECTI")
