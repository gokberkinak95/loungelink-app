# -*- coding: utf-8 -*-
"""
imza_uret.py — HER MIGRATION DOSYASI ICIN "BU DOSYA KOSTU MU?" IMZASI URETIR

🔴 NEDEN VAR
Bu projede bir MIGRATION DEFTERI (schema_migrations) hic olmadi. Dosyalar
Supabase SQL Editor'e elle yapistiriliyor ve hangisinin kostugunu soyleyen
tek kayit YOK. 038_SQL_DURUM.sql bunu 36 dosya icin elle yazmisti; bugun
264 dosya var.

🔴 VE ISIN ZOR TARAFI SU: bir dosyanin kostugunu ancak BIRAKTIGI IZDEN
anlayabiliriz. Iz birakmayan dosya (yalniz daha once tanimlanmis bir
fonksiyonu yeniden yazan dosya) TESPIT EDILEMEZ — ve bunu SOYLEMEK
zorundayiz, "kosmamis" diye isaretlemek YALAN olur.

🆕 SINIF: **"TESPIT EDILEMEYEN SEYI 'YOK' DIYE RAPORLAMAK, OLCMEDEN TESHIS
VERMEKTIR."** Ucuncu bir durum var ve tabloda o da gorunmeli: BILINMIYOR.

IMZA SECIMI — en ozgulden en zayifa:
  1. enum degeri      (alter type ... add value)      → pg_enum
  2. kolon            (alter table ... add column)     → information_schema
  3. kisit            (add constraint)                 → pg_constraint
  4. indeks           (create [unique] index)          → pg_class
  5. tablo            (create table)                   → to_regclass
  6. tip              (create type)                    → pg_type
  7. politika         (create policy)                  → pg_policies
  8. tetikleyici      (create trigger)                 → pg_trigger
  9. ayar             (insert into beta_settings)      → beta_settings
 10. rpc yuzeyi       (insert into rpc_client_surface) → tablo satiri
 11. fonksiyon        (create ... function)            → pg_proc
Fonksiyon EN SONDA, cunku bu projede 10+ fonksiyon birden cok dosyada
tanimli; birden cok dosyada gecen bir imza, hangi dosyanin kostugunu
SOYLEYEMEZ. Bu yuzden her aday "ilk kez BU dosyada mi geciyor?" diye
suzuluyor.
"""
import os, re, json, sys

SQL = os.path.dirname(os.path.abspath(__file__))

def dosyalar():
    ad = [f for f in os.listdir(SQL) if re.match(r'^\d{3}[a-z]?_.*\.sql$', f)]
    def anahtar(f):
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
    return sorted(ad, key=anahtar)

def yorumsuz(s):
    """-- yorumlarini at. Dize icindeki '--' korunur (kaba ama yeterli:
    bu dosyalarda dize icinde '--' neredeyse hic yok, olan yerlerde de
    yalniz FAZLA aday uretir, yanlis aday degil)."""
    out = []
    for satir in s.split('\n'):
        i = satir.find('--')
        out.append(satir if i < 0 else satir[:i])
    return '\n'.join(out)

# ---- aday cikaricilar -------------------------------------------------
def adaylar(src):
    a = []
    for m in re.finditer(r"alter\s+type\s+(?:public\.)?(\w+)\s+add\s+value\s+if\s+not\s+exists\s+'([^']+)'", src, re.I):
        a.append(('enum_degeri', f"{m.group(1)}.{m.group(2)}"))
    for m in re.finditer(r"alter\s+type\s+(?:public\.)?(\w+)\s+add\s+value\s+'([^']+)'", src, re.I):
        a.append(('enum_degeri', f"{m.group(1)}.{m.group(2)}"))
    for m in re.finditer(r"alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?(\w+)\s+add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)", src, re.I):
        a.append(('kolon', f"{m.group(1)}.{m.group(2)}"))
    for m in re.finditer(r"add\s+constraint\s+(\w+)", src, re.I):
        a.append(('kisit', m.group(1)))
    for m in re.finditer(r"create\s+(?:unique\s+)?index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?(\w+)\s+on", src, re.I):
        a.append(('indeks', m.group(1)))
    for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)", src, re.I):
        a.append(('tablo', m.group(1)))
    for m in re.finditer(r"create\s+type\s+(?:public\.)?(\w+)\s+as", src, re.I):
        a.append(('tip', m.group(1)))
    for m in re.finditer(r'create\s+policy\s+"?([\w ]+?)"?\s+on\s+(?:public\.)?(\w+)', src, re.I):
        a.append(('politika', f"{m.group(2)}|{m.group(1).strip()}"))
    for m in re.finditer(r"create\s+trigger\s+(\w+)", src, re.I):
        a.append(('tetikleyici', m.group(1)))
    for m in re.finditer(r"insert\s+into\s+beta_settings[\s\S]{0,4000}?;", src, re.I):
        blok = m.group(0)
        for k in re.findall(r"\('([a-z0-9_]+)'\s*,", blok, re.I):
            a.append(('ayar', k))
    for m in re.finditer(r"insert\s+into\s+rpc_client_surface[\s\S]{0,8000}?;", src, re.I):
        blok = m.group(0)
        for k in re.findall(r"\('([a-z0-9_]+)'\s*,", blok, re.I):
            a.append(('rpc_yuzeyi', k))
    for m in re.finditer(r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(", src, re.I):
        a.append(('fonksiyon', m.group(1)))
    a += ayar_degerleri(src)
    a += veri_satirlari(src)
    a += kural_notlari(src)
    return a

# ---- (D) KURAL NOTU ---------------------------------------------------
# Kural matrisi besleyen dosyalar (097/098/106/110/127/168/177/188...) ne
# tablo ne fonksiyon yaratir; yaptiklari sey `lounge_guest_rules` /
# `lounge_venue_acceptance` satiri EKLEMEK. O satirlarin `notes` metni
# dosyaya ozgudur ve canlida aranabilir.
def kural_notlari(src):
    out = []
    for tablo in ('lounge_guest_rules', 'lounge_venue_acceptance'):
        for m in re.finditer(r"insert\s+into\s+" + tablo + r"[\s\S]{0,20000}?;", src, re.I):
            for lit in re.findall(r"'([^'\n]{20,90})'", m.group(0)):
                if '%' in lit or '||' in lit or '::' in lit:
                    continue
                out.append(('kural_notu', f"{tablo}|{lit.strip()}"))
                break
            if out:
                break
    return out

ONCELIK = ['enum_degeri','kolon','kisit','indeks','tablo','tip',
           'politika','tetikleyici','ayar_deger','ayar','rpc_yuzeyi',
           'satir','kural_notu','desen','desen_yok','fonksiyon','govde']
# 🔴 `fonksiyon` EN SONDAYDI VE 292'NIN EN GUCLU IZINI KAYBETTIRDI.
# 292 uc YENI fonksiyon yaratiyor (`yerel_an` · `yerel_gun` · `yerel_saat`)
# ama ayni zamanda alti fonksiyonu yeniden yaziyor; 24 `govde` adayi
# sekizlik listeyi doldurup `yerel_an`i disari itti.
# `fonksiyon` adaylari zaten "ILK KEZ BU DOSYADA" suzgecinden geciyor —
# yani yeni bir nesne, uzerine yazilamaz. `govde` ise ancak SONRAKI bir
# dosya o fonksiyonu yeniden yazana kadar yasar.
# 🆕 SINIF: "YENI BIR NESNE, ESKI BIR NESNENIN YENI GOVDESINDEN DAHA
# DAYANIKLI BIR IZDIR — SIRALAMAYI DAYANIKLILIGA GORE KUR."
GOVDE_TAVANI = 30     # dosya basina en cok 30 govde adayi; gerisine yer kalsin
ADAY_TAVANI = 36

# ---- (A) DEGERE BAGLI AYAR --------------------------------------------
# 219 `paid_guest_credits` ayarini 1'e cekiyor ama ANAHTARI 181 acmis.
# Anahtar imzasi "181 kostu mu"yu soyler, "219 kostu mu"yu SOYLEMEZ.
# Deger dahil edilince ayirt edici olur.
def ayar_degerleri(src):
    out = []
    for m in re.finditer(r"insert\s+into\s+beta_settings[\s\S]{0,4000}?;", src, re.I):
        blok = m.group(0)
        for k, v in re.findall(r"\('([a-z0-9_]+)'\s*,\s*'?([^,)']{1,40})'?\s*(?:::[a-z]+)?\s*\)", blok, re.I):
            v = v.strip()
            if re.fullmatch(r"(to_jsonb\()?\d+\)?", v):
                sayi = re.sub(r"[^0-9]", "", v)
                if sayi:
                    out.append(('ayar_deger', f"{k}={sayi}"))
    for m in re.finditer(r"update\s+beta_settings\s+set\s+value\s*=\s*'?(\d+)'?[^;]*?key\s*=\s*'([a-z0-9_]+)'", src, re.I):
        out.append(('ayar_deger', f"{m.group(2)}={m.group(1)}"))
    return out

# ---- (B) FONKSIYON GOVDESI -------------------------------------------
# Bir dosya YALNIZCA var olan bir fonksiyonu yeniden yaziyorsa, izi o
# fonksiyonun YENI GOVDESIDIR. Govdede gecen ama ONCEKI tanimlarda
# GECMEYEN kisa bir dize, "canlida hangi surum duruyor" sorusunun
# dogrudan cevabidir — ki kullanicinin asil sordugu da bu.
def fonksiyon_govdeleri(src):
    """[(fn_adi, govde_metni)] — $tag$ ... $tag$ araligi."""
    out = []
    for m in re.finditer(
        r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(", src, re.I):
        ad = m.group(1)
        kuyruk = src[m.end():]
        t = re.search(r"\$(\w*)\$", kuyruk)
        if not t:
            continue
        etiket = t.group(0)
        bas = t.end()
        son = kuyruk.find(etiket, bas)
        if son < 0:
            continue
        out.append((ad, kuyruk[bas:son]))
    return out

def govde_imzasi(ad, govde, onceki_govdeler):
    """Govdede gecen, onceki tanimlarda GECMEYEN kisa bir dize bul."""
    adaylar = []
    # (1) tek tirnakli metin sabitleri — en okunakli iz
    for lit in re.findall(r"'([^'\n]{10,80})'", govde):
        if '%' in lit or '||' in lit:
            continue
        adaylar.append(lit.strip())
    # (2) ozgun tanimlayicilar
    for kw in re.findall(r"\b(distinct\s+on|lateral|materialized|generate_series)\b", govde, re.I):
        adaylar.append(kw)
    # ── (3) KOD PARCASI — 13 EYLUL'DE ACILAN UCUNCU SINIF ───────────────
    # 🔴 287 ve 288 hic aday uretmedi. Ikisi de bir fonksiyonu YENIDEN
    # yaziyor ama degistirdikleri sey METIN degil KOD:
    #   288 → `profiles pr … pr.trust_score`  ⇒  `trust_scores ts … ts.score`
    #   287 → plan enum'unun metinle karsilastirilmasi
    # Metin sabitleri 246/210'daki hâliyle AYNI kaldigi icin (1) ve (2)
    # bos dondu ve dosya "tespit edilemez" gorundu — oysa canli govdede
    # apacik duruyordu.
    # 🆕 SINIF: "IZ YALNIZCA METIN SABITLERINDE ARANIRSA, KODU DEGISTIRIP
    # METNI DEGISTIRMEYEN DOSYA GORUNMEZ OLUR."
    # Govdenin HER SATIRI bir adaydir; onceki hicbir surumde gecmeyen en
    # kisa satir izdir. Satir icinden alindigi icin bosluklari aynen
    # korunur — `prosrc` kaynagi harfi harfine sakladigindan tam eslesir.
    satirlar = []
    for ham in govde.split('\n'):
        s = ham.strip()
        if len(s) < 12 or len(s) > 110:
            continue
        if s.startswith('--'):
            continue
        satirlar.append(s)
    satirlar.sort(key=len)
    adaylar += satirlar
    # 🔴 ESIK 8 KARAKTERDI VE 289'A `session_id` IZINI SECTIRDI. On karakterlik,
    # projede yuzlerce yerde gecen bir ad "bu dosya kostu" demez — "bir yerde
    # boyle bir alan var" der. Iz AYIRT ETMELIDIR, VAR OLMAK YETMEZ.
    # 🆕 SINIF: "KISA VE YAYGIN BIR PARCA IZ DEGIL RASTLANTIDIR."
    # 🔴 «ONCEKI GOVDELERDE GECIYORSA AT» BIR ON ELEMEYDI VE 286 · 287'NIN
    # IZINI 4 · 3 adaya dusurdu; ucu de dogrulamayi gecemedi ve iki dosya
    # BILINMIYOR kaldi. Sorun elemede degil, ELEMEYI BENIM YAPMAMDA:
    # "onceki govde" listesini kendi ayristiricim kuruyor ve dinamik SQL
    # ile tanimlanmis surumleri GORMUYOR. Dogrulayici ayni soruyu canli
    # veritabaninda soruyor — benden dogru cevap veriyor.
    # Artik eleme degil SIRALAMA: once "benim gordugum kadariyla yeni"
    # olanlar, sonra gerisi. Karari olcum veriyor.
    tier1, tier2 = [], []
    for a in adaylar:
        if not a or len(a) < 16:
            continue
        # 🔴 «TIRNAK IÇEREN SATIRI ATLA» KURALI 287'YI TESPIT EDILEMEZ YAPTI.
        # 287'nin TEK degisikligi `v_etkin::text <> v_satin` — ve o ifade
        # su satirin icinde yasiyor:
        #   'ucretsiz_yukseltme', (v_g.id is not null and v_etkin::text <> v_satin),
        # Satirda tirnak var diye elendi; dosyanin baska izi yoktu ve
        # "bilinmiyor" cikti. Oysa tirnak bir tehlike DEGIL: degeri SQL'e
        # gomen `q()` zaten ikiye katlayarak kaciriyor.
        # 🆕 SINIF: "KENDI KACIS YOLUN VARKEN KACMASI GEREKEN KARAKTERI
        # YASAKLAMAK, GUVENLIK DEGIL KORLUKTUR."
        if "\\" in a:
            continue
        if a in tier1 or a in tier2:
            continue
        (tier2 if any(a in g for g in onceki_govdeler) else tier1).append(a)
    # Tavan genis: 287'nin belirleyici satiri («v_etkin::text <> v_satin»
    # tasiyan uzun satir) 12'lik tavanda disarida kaliyordu. Olcum ucuz,
    # aday elemek pahali — tavani olcume gore degil, KARARA gore kur.
    return (tier1 + tier2)[:40]


# ── ELLE SECILMIS IZLER ────────────────────────────────────────────────
# 🔴 Bazi dosyalar ne nesne yaratir ne fonksiyon yazar — yaptiklari sey
# VERIYI DUZELTMEKTIR. 290 bunun saf ornegi: `lounge_guest_rules.notes`
# icindeki ASCII'lesmis Turkce sozcukleri geri koyuyor. Otomatik cikarici
# boyle bir dosyada hicbir sey goremez, cunku semada hicbir sey degismez.
# Izi VERININ KENDISIDIR: kostuktan sonra notlarda Turkce harf VARDIR,
# kosmadan once YOKTUR. Bu iz elle secildi ama TAHMIN DEGIL — dogrulayici
# onu da tam kurulu veritabaninda olcuyor; olcum tutmazsa dusuyor.
ELLE = {
    # ÖLÇÜLDÜ: `UCRETSIZ` 285'te 17 satır, 290'dan sonra 0 satır.
    # `AILE`/`YURTDISI` de aynı sözlükte; üçü birden aranıyor ki tek bir
    # not satırının elle düzeltilmesi izi bozmasın.
    '290_kural_notlari_turkce.sql':
        ('desen_yok', 'lounge_guest_rules|notes|(UCRETSIZ|YURTDISI|ANLASMALI)'),
}

# ---- (C) VERI SATIRI --------------------------------------------------
# Katalog besleyen dosyalar (havalimani, salon, odul) fonksiyon da tablo da
# yaratmiyor; izleri EKLEDIKLERI SATIR.
VERI_TABLO = {
    'airports': 'code', 'lounges': 'name', 'lounge_venues': 'name',
    'lounge_programs': 'code', 'rewards': 'title', 'carriers': 'code',
    'plan_catalog': 'plan', 'host_tiers': 'code',
}
def veri_satirlari(src):
    out = []
    for m in re.finditer(r"insert\s+into\s+(?:public\.)?(\w+)\s*\(([^)]*)\)\s*values([\s\S]{0,6000}?);", src, re.I):
        tablo = m.group(1).lower()
        if tablo not in VERI_TABLO:
            continue
        kolonlar = [c.strip().strip('"').lower() for c in m.group(2).split(',')]
        hedef = VERI_TABLO[tablo]
        if hedef not in kolonlar:
            continue
        idx = kolonlar.index(hedef)
        for satir in re.findall(r"\(([^()]*(?:\([^()]*\)[^()]*)*)\)", m.group(3)):
            parcalar = [x.strip() for x in re.split(r",(?![^(]*\))", satir)]
            if idx >= len(parcalar):
                continue
            v = parcalar[idx].strip()
            mm = re.fullmatch(r"'([^']{2,40})'", v)
            if mm:
                out.append(('satir', f"{tablo}.{hedef}={mm.group(1)}"))
                break   # dosya basina TEK satir yeter
    return out

def main():
    fs = dosyalar()
    tum = {}                       # dosya -> [(tip, ad)]
    ilk = {}                       # (tip, ad) -> ilk gecen dosya
    govde_gecmisi = {}             # fn -> [onceki govdeler]
    govde_aday = {}                # dosya -> [(tip, ad)]
    for f in fs:
        src = yorumsuz(open(os.path.join(SQL, f), encoding='utf-8', errors='replace').read())
        a = adaylar(src)
        tum[f] = a
        for k in a:
            ilk.setdefault(k, f)
        # govde imzasi: bu dosya bir fonksiyonu YENIDEN yaziyorsa
        # 🔴 BURADA `if onceki:` KOSULU VARDI VE 286 · 287'YI IZSIZ BIRAKTI.
        # Kosul suydu: "bu fonksiyon daha once tanimlandiysa govde izi
        # uret". Ama "daha once tanimlandi mi"yi KAYNAK KODDAN, kendi
        # regex'imle cikariyordum — ve `discover_people_prebfilter` ile
        # `my_plan` icin YANILDIM (ikisi de dinamik SQL / farkli yazimla
        # daha once tanimlanmisti). Yanildigim yerde hic aday uretmedim.
        # Artik HER fonksiyon icin govde adayi uretiliyor; "yeni mi"
        # sorusuna dogrulayici CEVAP VERIYOR (dosyadan once olculuyor).
        # 🆕 SINIF: "ELINDE OLCUM VARKEN CIKARIMLA ON ELEME YAPMA —
        # ON ELEME, OLCUMUN GOREBILECEGI SEYI GORUNMEZ KILAR."
        ga = []
        for ad, govde in fonksiyon_govdeleri(src):
            onceki = govde_gecmisi.get(ad, [])
            for iz in govde_imzasi(ad, govde, onceki):
                ga.append(('govde', f"{ad}|{iz}"))
            govde_gecmisi.setdefault(ad, []).append(govde)
        govde_aday[f] = ga

    # 🔴 PRE_drop DOSYALARI IZ BIRAKMAZ — cunku isleri SILMEK.
    # Ama her biri bir SONRAKI ana dosyanin on kosuludur: 024a olmadan
    # 024 patlar (42P13). Yani 024 kostuysa 024a da kosmustur.
    # Bunu "esitleyerek" cozuyoruz, uydurarak degil.
    def eslikci(f):
        m = re.match(r'^(\d{3})([a-z])_', f)
        if not m:
            return None
        for g in fs:
            if re.match(r'^' + m.group(1) + r'_', g):
                return g
        return None

    secim = []
    tespitsiz = []
    for f in fs:
        # yalniz BU dosyada ILK KEZ gecen adaylar ise yarar
        ozgul = [k for k in tum[f] if ilk.get(k) == f]
        ozgul += govde_aday.get(f, [])
        if f in ELLE:
            ozgul.insert(0, ELLE[f])
        if not ozgul:
            es = eslikci(f)
            if es:
                secim.append((f, [['eslikci', es]]))
                continue
            tespitsiz.append(f)
            secim.append((f, []))
            continue
        # 🔴 BU SIRALAMA `govde` ADAYLARINI DA UZUNLUGA GORE YENIDEN
        # DIZIYORDU VE `govde_imzasi`nin KATMAN SIRASINI YOK EDIYORDU.
        # O fonksiyon adaylari zaten "onceki govdede YOK olanlar once"
        # diye siralamisti — 287'nin belirleyici satiri (`v_etkin::text
        # <> v_satin`) 1. katmandaydi; uzunluga gore yeniden dizilince
        # 40 kisa ama ESKI govdede de bulunan literalin arkasina dustu ve
        # tavandan tasti. Dosya "bilinmiyor" cikti.
        # 🆕 SINIF: "BIR ANLAM TASIYAN SIRAYI, SONRADAN BASKA BIR OLCUTLE
        # YENIDEN SIRALARSAN O ANLAMI SESSIZCE SILERSIN."
        # `govde` disindakiler oncelige gore siralaniyor; `govde` adaylari
        # URETILDIGI SIRAYI koruyor.
        ozgul = [k for k in ozgul if k[0] != 'govde']
        ozgul.sort(key=lambda k: (ONCELIK.index(k[0]), len(k[1])))
        ozgul += govde_aday.get(f, [])
        # 🔴 TEK ADAY YETMEZ. Ilk yazimda dosya basina TEK imza sectim ve
        # tam kurulu bir veritabaninda 31 dosya "KOSMADI" cikti — hepsi
        # YANLIS NEGATIFTI: sectigim imzalar SONRAKI dosyalar tarafindan
        # ezilmisti (fonksiyon govdesi yeniden yazildi, ayar degeri
        # degisti, kural notu guncellendi).
        # 🆕 SINIF: "BIR IZ, UZERINE YAZILABILIYORSA IZ DEGILDIR."
        # Artik dosya basina 8 aday tasiniyor; dogrulayici (imza_dogrula.py)
        # TAM KURULU bir veritabaninda hangisinin AYAKTA KALDIGINI olcup
        # onu seciyor. Hicbiri kalmiyorsa dosya BILINMIYOR olur — uydurma
        # bir "kosmadi" yerine durustce bilinmiyor.
        digerleri = [k for k in ozgul if k[0] != 'govde']
        # 🔴 GOVDE ADAYLARI UZUNLUGA GORE SIRALANIYORDU VE 293'UN
        # `cancel_availability` IZLERINI TAMAMEN DISARI ITTI: sirada
        # `respond_invite|…` girdileri vardi ve FONKSIYON ADI KISA oldugu
        # icin hepsi one geciyordu. Yani siralama, izin gucunu degil
        # FONKSIYONUN ADININ UZUNLUGUNU olcuyordu.
        # 🆕 SINIF: "SIRALAMA ANAHTARIN OLCMEK ISTEDIGIN SEYI DEGIL DE
        # ONA YAPISIK BIR SEYI OLCUYORSA, SIRALAMA GURULTUDUR."
        # Artik fonksiyonlar arasinda DONUSUMLU seciliyor: her yeniden
        # yazilan fonksiyon listeye en az bir aday sokuyor.
        gruplar = {}
        for k in ozgul:
            if k[0] == 'govde':
                gruplar.setdefault(k[1].split('|', 1)[0], []).append(k)
        govdeler = []
        while len(govdeler) < GOVDE_TAVANI and any(gruplar.values()):
            for ad in list(gruplar):
                if gruplar[ad]:
                    govdeler.append(gruplar[ad].pop(0))
                    if len(govdeler) >= GOVDE_TAVANI:
                        break
        secim.append((f, [list(k) for k in (digerleri + govdeler)[:ADAY_TAVANI]]))

    print(f"dosya: {len(fs)} · aday uretilen: {len(fs)-len(tespitsiz)} · HIC ADAY YOK: {len(tespitsiz)}")
    if tespitsiz:
        print("  " + ", ".join(tespitsiz))
    json.dump(secim, open(os.path.join(SQL, 'imza_adaylari.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print("→ imza_adaylari.json yazildi (dogrulama icin imza_dogrula.py)")

if __name__ == '__main__':
    main()
