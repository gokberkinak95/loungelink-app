# -*- coding: utf-8 -*-
"""
app_perf_check.py — UYGULAMANIN ÖDEDİĞİ SIRALI AĞ TURLARI

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "APP tarafında da performans artışı yapmamız lazım.
Bir tık yavaş şu an."

"Bir tık yavaş" ölçülebilir bir cümle değildir. Ölçülebilir hâle getirmek
için önce SEBEBİ saymak gerekti. Kodu tarayınca desen netti:

    const { data: a } = await supabase...   ← tur 1
    const { data: b } = await supabase...   ← tur 2   (a'yı kullanmıyor)
    const { data: c } = await supabase...   ← tur 3   (a'yı da b'yi de değil)

Ayarlar ekranı BEŞ, ilan formu BEŞ, Keşfet ÜÇ tur atıyordu — hiçbiri
diğerini beklemek zorunda değilken. Supabase turu bu projede ölçüldü:
BO tarafında 345 ms. Telefonda mobil şebekeyle daha da yüksek.

🆕 SINIF: "BAĞIMSIZ SORGULARI SIRAYA DİZMEK BİR HATA DEĞİL BİR ALIŞKANLIKTIR
— VE ALIŞKANLIK, HATADAN DAHA ZOR FARK EDİLİR ÇÜNKÜ HER SATIRI TEK BAŞINA
DOĞRUDUR."

NE ÖLÇÜYOR
Bir fonksiyon gövdesinde ARDIŞIK `await supabase...` satırları; sonrakiler
öncekinin değişkenine DOKUNMUYORSA bu bir şelaledir. Bağımlılık varsa
sıralılık doğrudur ve sayılmaz.

⚠️ ÇIRÇIR: mevcut borç `app_perf_butce.json`da. Azalınca tavan kendiliğinden
iner; ARTARSA build düşer. Bir kerede hepsini düzeltemedim — ama geriye
gidişi imkânsız kıldım.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "app_perf_butce.json")

AWAIT_SB = re.compile(
    r"^(\s*)(?:const\s*(?:\{(?P<yikim>[^}]*)\}|(?P<ad>\w+))\s*=\s*)?"
    r"await\s+supabase\s*[.\n]", re.M)


def kod(s):
    # 🔴 v3.9 — BİLDİRİLEN SATIR NUMARALARI YANLIŞTI.
    # Blok yorumu `/* … */` SİLİNİYORDU; içindeki satır sonları da gitti.
    # Sonuç: 18 bulgunun her biri, dosyadaki gerçek yerinden ONLARCA satır
    # yukarıda raporlandı. Bulguyu açıp bakınca alakasız bir kod görüyorsun
    # ve "denetim yanılmış" diyorsun — oysa bulgu doğru, ADRES yanlıştı.
    #
    # 🆕 SINIF: "YERİ YANLIŞ BİLDİRİLEN BİR BULGU, YANLIŞ BULGUDAN DAHA
    # ZARARLIDIR — ÇÜNKÜ DOĞRU OLDUĞU HÂLDE GÜVENİ KAYBEDER."
    #
    # Çözüm: yorumu silme, satır sayısını KORUYARAK boşalt.
    # ⚠️ İLK DÜZELTMEM YETMEDİ: yorumu yalnız `\n` sayısıyla değiştirmek
    # 61 satırlık bir kaymayı hâlâ bırakıyordu (bir dizgi/regex içindeki
    # `*/` deseni eşleşmeyi kaydırıyor). Sayıyı KORUMAK yerine KONUMU
    # koruyorum: her yorum karakteri AYNI UZUNLUKTA boşlukla değişiyor,
    # `\n`ler yerinde kalıyor. Böylece kod metnindeki her ofset, ham
    # dosyadaki aynı ofsettir — satır numarası artık türetilmiyor,
    # ÖLÇÜLÜYOR.
    # 🆕 SINIF: "BİR METNİ TEMİZLERKEN UZUNLUĞU KORURSAN, KONUM BİLGİSİ
    # HİÇ KAYBOLMAZ — SAYMAK YERİNE YERİNDE BIRAKMAK DAHA UCUZDUR."
    def _bosalt(m):
        return "".join(c if c == "\n" else " " for c in m.group(0))
    s = re.sub(r"/\*[\s\S]*?\*/", _bosalt, s)
    s = re.sub(r"^([ \t]*)//.*$", lambda m: m.group(0)[:0] + " " * len(m.group(0)),
               s, flags=re.M)
    return s


def dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            d.append(os.path.join(SRC, f))
    return d


def _adlar(m):
    """Bu await'in ürettiği değişken adları."""
    if m.group("ad"):
        return {m.group("ad")}
    y = m.group("yikim") or ""
    # `{ data: u }` → u ;  `{ data, error }` → data, error
    out = set()
    for parca in y.split(","):
        parca = parca.strip()
        if not parca:
            continue
        out.add(parca.split(":")[-1].strip())
    return out


def selaleler(yol):
    """Ardışık, birbirine bağımlı OLMAYAN await supabase satırları."""
    with open(yol, encoding="utf-8") as f:
        ham = f.read()
    s = kod(ham)
    satir = s.split("\n")
    yerler = []
    for m in AWAIT_SB.finditer(s):
        yerler.append((s[:m.start()].count("\n"), _adlar(m), m.start(), m.end()))

    bulgu = []
    for i in range(1, len(yerler)):
        onceki_sat, onceki_ad, _, _ = yerler[i - 1]
        bu_sat, _, bu_bas, bu_son = yerler[i]

        # Ardışık sayılması için aralarında en fazla 12 satır olsun:
        # daha uzağı büyük olasılıkla ayrı bir mantık bloğu.
        if bu_sat - onceki_sat > 12:
            continue

        # 🔴 BAĞIMLILIK KONTROLÜ. Sonraki çağrı, öncekinin ürettiği bir
        # değişkeni KULLANIYORSA sıralılık ZORUNLUDUR ve bu bir kusur
        # değildir. Bunu saymayan bir denetim, doğru kodu suçlar.
        #
        # 🆕 SINIF: "BİR ŞELALE SAYACI BAĞIMLILIĞI GÖRMEZSE, DÜZELTİLEMEZ
        # BULGULAR ÜRETİR — VE DÜZELTİLEMEYEN BULGU GÖRMEZDEN GELİNİR."
        arasi = s[yerler[i - 1][3]:bu_son]

        # 🔴 v3.6 — `data` KÖR NOKTASI. Önceki sürüm `data`/`error`/`count`
        # adlarını bağımlılık saymıyordu (çok genel diye). Ama Supabase'de
        # EN SIK yazım tam da `const { data } = await ...`; yani kural,
        # en yaygın durumda bağımlılığı hiç göremiyordu:
        #
        #     const { data } = await supabase.from("requests")...   ← 1
        #     const ids = [...new Set((data||[]).map(x => x.host_id))];
        #     const { data: ps } = await supabase...in("user_id", ids); ← 2
        #
        # İkinci sorgu birincinin SONUCUNU kullanıyor. Sıralılık zorunlu.
        # Yine de "paralelleştir" diye raporlanıyordu — ve düzeltilemeyen
        # bir bulgu, görmezden gelinen bir bulgudur.
        #
        # 🆕 SINIF: "BİR ADI 'ÇOK GENEL' DİYE ELEMEK, O ADIN EN SIK
        # KULLANILDIĞI YERDE KURALI KÖR ETMEK DEMEKTİR."
        #
        # ⚠️ VE İLK DÜZELTMEM AŞIRI DÜZELTMEYDİ: `data`yı bağımlılık
        # sayınca 17 şelaleden 16'sı kayboldu. Sebep `error`: hemen her
        # blokta `if (error)` geçiyor, yani "aradaki metinde adı geçiyor"
        # ölçütü neredeyse HER ZAMAN doğru çıkıyordu. Kural bu kez ters
        # yönde kör oldu.
        #
        # 🆕 SINIF: "BİR KÖRLÜĞÜ DÜZELTİRKEN ÖLÇÜTÜ GENİŞLETİRSEN, AYNI
        # KURALI TERS YÖNDE KÖR EDERSİN — ARANAN ŞEY 'ADI GEÇİYOR MU'
        # DEĞİL, 'BU ÇAĞRIYI BESLİYOR MU'DUR."
        #
        # Doğru ölçüt: önceki çağrının ürettiği ad, SONRAKİ ÇAĞRININ
        # KENDİ İFADESİNDE geçiyor mu? `.in("user_id", ids)` gibi. Hata
        # kontrolü aradadır ama çağrının içinde değildir.
        sonraki_ifade = s[bu_bas:bu_son + 260]
        # Türetilmiş ad zinciri: `data` → `rs` → `ids` gibi ara
        # değişkenler de bağımlılık taşır; aradaki atamalardan topla.
        tasiyici = set(onceki_ad)
        for _ in range(3):
            yeni = set()
            for m2 in re.finditer(r"(?:const|let|var)\s+(\w+)\s*=\s*([^;\n]+)", arasi):
                if any(re.search(r"\b%s\b" % re.escape(t), m2.group(2)) for t in tasiyici):
                    yeni.add(m2.group(1))
            if yeni <= tasiyici:
                break
            tasiyici |= yeni
        bagimli = any(
            ad and re.search(r"\b%s\b" % re.escape(ad), sonraki_ifade)
            for ad in tasiyici
        )
        if bagimli:
            continue

        # `Promise.all` içindeyse zaten paralel.
        pencere = s[max(0, bu_bas - 400):bu_bas]
        if pencere.rfind("Promise.all") > pencere.rfind(";"):
            continue

        # ══════════════════════════════════════════════════════════════
        # 🔴 v3.6 — BU KURAL ÜÇ TURDUR YANLIŞ SAYI RAPORLUYORDU.
        #
        # "48 şelale" diye bildirdiğim borcun büyük kısmı şelale DEĞİLDİ.
        # Örnek (`screens.js`, ayarlar ekranı):
        #
        #     async function profilKaydet() { await supabase...update() }
        #     async function sifreDegistir() { await supabase.auth... }
        #     async function telefonDegistir() { await supabase.rpc(...) }
        #
        # Üç AYRI eylem işleyicisi, üçü de kullanıcının ayrı bir
        # dokunuşuyla çalışıyor. Aralarında 12 satırdan az mesafe olduğu
        # için "ardışık" sayıldılar — oysa aynı anda ASLA koşmuyorlar.
        # Paralelleştirilecek bir şey yok; `Promise.all`a almak zaten
        # imkânsız.
        #
        # 🆕 SINIF: "YAKINLIK ARDIŞIKLIK DEĞİLDİR — İKİ SATIRIN AYNI
        # AKIŞTA KOŞTUĞUNU KANITLAMADAN, MESAFEYE BAKARAK ÖLÇEN BİR
        # SAYAÇ BORCU ŞİŞİRİR VE GERÇEK BORCU İÇİNDE SAKLAR."
        #
        # Kanıt şartı: iki `await` arasında YENİ BİR FONKSİYON GÖVDESİ
        # başlamamalı. Başlıyorsa ikisi ayrı akıştadır.
        aradaki = s[yerler[i - 1][3]:bu_bas]
        if re.search(r"(?:\basync\s+function\b|\bfunction\s+\w*\s*\(|"
                     r"=>\s*\{|\basync\s*\([^)]*\)\s*=>|\basync\s+\w+\s*=>)",
                     aradaki):
            continue

        # ══════════════════════════════════════════════════════════════
        # 🔴 v3.9 — ARADA BİR KAPI VARSA, PARALELLEŞTİRME BİR İYİLEŞTİRME
        # DEĞİL BİR GERİLEMEDİR.
        #
        # 28 Ağustos, Gökberk: "neden hâlâ çözmüyoruz bunları."
        # Oturup 18 bulgunun HER BİRİNİ tek tek açtım. 18'in 11'i
        # paralelleştirilemez — ve sebebi "riskli" değil, MANTIKSAL:
        #
        #   const { data: taken } = await supabase.rpc("phone_in_use", …);
        #   if (taken) { setErr(…); return; }          ← KAPI
        #   const { data: sud } = await supabase.auth.signUp(…);
        #
        # İkinci çağrı, birincisinin sonucuna göre HİÇ YAPILMAYABİLİR.
        # `Promise.all`a almak, telefonu zaten kayıtlı olan bir kullanıcı
        # için GEREKSİZ BİR `signUp` DENEMESİ demektir — yani daha hızlı
        # değil, DAHA ÇOK İŞ. Aynı desen: yazma sonrası okuma
        # (`send_invite` → `invitable_guests`), hesap silme → çıkış,
        # ve `if (code) { … return; }` gibi BİRBİRİNİ DIŞLAYAN dallar.
        #
        # 🆕 SINIF: "SIRALI GÖRÜNEN İKİ ÇAĞRININ ARASINDA BİR ERKEN ÇIKIŞ
        # VARSA, ONLAR SIRALI DEĞİL KOŞULLUDUR — VE KOŞULLU İKİ ÇAĞRIYI
        # PARALELE ALMAK, YAPILMAMASI GEREKEN İŞİ YAPMAKTIR."
        #
        # ⚠️ Bu kuralı eklerken bütçeyi DÜŞÜRMEK için bahane üretmedim:
        # kural eklendikten sonra kalan 7 bulgunun HEPSİNİ gerçekten
        # `Promise.all`a aldım. Sayıyı kuralla değil, kodla düşürdüm.
        if re.search(r"\breturn\b|\bthrow\b", aradaki):
            continue

        # 🔴 KAPININ İKİNCİ BİÇİMİ: `return` yok ama İKİNCİ ÇAĞRI, BİRİNCİDEN
        # SONRA AÇILAN BİR BLOĞUN İÇİNDE.
        #
        #   const { error } = await supabase.rpc("share_session_status", …);
        #   if (!error) {                                   ← KAPI
        #     const { data: ch } = await supabase.from("chat_channels")…
        #
        # Yazma başarısızsa ikinci okuma HİÇ YAPILMAZ. `Promise.all`a almak,
        # başarısız bir yazmadan sonra da okumak demektir — yani hem gereksiz
        # tur hem de YANLIŞ VERİ (yazılmamış bir şeyin sonucunu okumak).
        #
        # Ölçüt sözcük değil YAPI: ikinci `await`in süslü parantez derinliği
        # birincininkinden büyükse, arada bir blok açılmış demektir.
        # 🆕 SINIF: "KOŞULLULUĞU ANAHTAR SÖZCÜKLE ARAYAN BİR DENETİM, SÜSLÜ
        # PARANTEZLE YAZILMIŞ KOŞULU GÖREMEZ — YAPIYI SAY, SÖZCÜĞÜ DEĞİL."
        if aradaki.count("{") > aradaki.count("}"):
            continue

        # 🔴 KAPININ ÜÇÜNCÜ BİÇİMİ: İKİSİ AYRI DALLARDA (`} else {`).
        # Kayıt akışında `grant_consents` oturum AÇILDIYSA, `signIn` ise
        # AÇILMADIYSA çalışıyor. İkisi aynı çalıştırmada ASLA birlikte
        # koşmaz; paralelleştirilecek bir şey yok. Derinlik sayımı bunu
        # göremez çünkü `}` ve `{` dengeli.
        if re.search(r"\}\s*else\b", aradaki):
            continue

        bulgu.append(bu_sat + 1)
    return bulgu


def main():
    print("=" * 70)
    print("APP PERFORMANS — sıralı (paralelleştirilebilir) ağ turları")
    print("=" * 70)

    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    simdi, artan, azalan = {}, [], []
    for y in dosyalar():
        ad = os.path.relpath(y, KOK).replace("\\", "/")
        n = len(selaleler(y))
        if n:
            simdi[ad] = n
        onceki = butce.get(ad, 0 if ad in butce else None)
        if onceki is None:
            continue
        if n > onceki:
            artan.append((ad, onceki, n))
        elif n < onceki:
            azalan.append((ad, onceki, n))

    # ══════════════════════════════════════════════════════════════════
    # 🔴 SIFIR ÖLÇÜM KORUMASI — v3.9'da bu sayı 18'den 0'a indi ve
    # "0" iki farklı şeyin görüntüsüdür:
    #   (a) borç ödendi,
    #   (b) DESEN BOZULDU, denetim artık hiçbir şey görmüyor.
    # `yuzey_check.py`de paydayı saymayı unuttuğum için başarıyı arıza
    # sanmıştım; burada tersi tehlike var — arızayı başarı sanmak.
    #
    # Payda: dosyalarda kaç `await supabase` var. Sıfırsa desen kırılmış
    # demektir ve build DÜŞER. Ayrıca `Promise.all` sayısı da yazılıyor:
    # şelale 0'a inerken dalga sayısı ARTMADIYSA, borç ödenmemiş
    # yalnızca gizlenmiştir.
    # 🆕 SINIF: "SIFIR BULGU, PAYDASI YAZILMADIKÇA BİR SONUÇ DEĞİL BİR
    # İDDİADIR."
    payda, dalga = 0, 0
    for y in dosyalar():
        s = kod(open(y, encoding="utf-8").read())
        payda += len(AWAIT_SB.findall(s))
        dalga += s.count("Promise.all")
    if payda == 0:
        print("\n  ✗ HİÇ `await supabase` BULUNAMADI — desen bozulmuş, denetim kör.")
        return 1

    toplam = sum(simdi.values())
    print("\n  Şelale sayısı: %d  (bütçe: %d)   [payda: %d `await supabase` · %d `Promise.all` dalgası]"
          % (toplam, sum(butce.values()) if butce else toplam, payda, dalga))
    for ad, n in sorted(simdi.items(), key=lambda x: -x[1]):
        print("    %-28s %3d" % (ad, n))
    for ad, o, n in azalan:
        print("    ↓ %-26s %3d → %3d" % (ad, o, n))

    hata = 0
    if artan:
        print("\n  ✗ ŞELALE ARTMIŞ:")
        for ad, o, n in artan:
            print("      %-26s %3d → %3d  (+%d)" % (ad, o, n, n - o))
        print("      Bağımsız sorguları `Promise.all` ile tek dalgaya al.")
        hata = 1
    elif butce:
        print("  ✓ Hiçbir dosyada şelale artmadı.")

    yeni = {a: min(n, butce.get(a, n)) for a, n in simdi.items()}
    for a in butce:
        if a not in yeni:
            yeni[a] = 0          # tamamen temizlenen dosya sıfırda kilitlenir
    if yeni != butce and not artan:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(yeni, f, indent=1, sort_keys=True)
        print("  · bütçe güncellendi (yalnız aşağı)")

    # ── AÇILIŞ YOLU: İLK KAREDEN ÖNCE KAÇ BEKLEME VAR ─────────────────
    # 🔴 Bu ayrı sayılıyor çünkü buradaki her bekleme, kullanıcının
    # gördüğü İLK gecikmedir — diğer hepsinden daha pahalıdır.
    with open(os.path.join(KOK, "App.js"), encoding="utf-8") as f:
        app = kod(f.read())
    m = re.search(r'const \[_lang, \{ data \}, _recoveryRaw\] = await Promise\.all\(', app)
    print("")
    if m:
        print("  ✓ Açılış: dil · oturum · kurtarma bayrağı TEK dalgada.")
    else:
        print("  ✗ Açılış yolu sıralı bekliyor — ilk kare gecikiyor.")
        hata = 1

    # ── KATMAN SEKME AĞACINI SÖKÜYOR MU ───────────────────────────────
    # 🔴 v3.4'te ölçüldü: `if (topOverlay) return (...)` satırı, bir katman
    # açıldığında SEKME AĞACININ TAMAMINI ağaçtan düşürüyordu. Geri
    # dönüldüğünde her sekme sıfırdan mount oluyor ve bütün `useEffect`leri
    # yeniden koşuyordu — Profil'de 6, Keşfet'te 5 sorgu.
    #
    # Gökberk bunu ÜÇ ayrı şikâyet olarak yaşadı: "çıkış yap çalışmıyor"
    # (ilk dokunuş spinner'a iniyor), "back yapınca ana sayfaya dönüyor"
    # (iç durum sıfırlanıyor), "bir tık yavaş".
    #
    # 🆕 SINIF: "BİR KATMANI EKRANIN YERİNE KOYARSAN, ALTINDAKİ EKRANI DA
    # KAPATMIŞ OLURSUN — VE GERİ DÖNÜŞ, AYNI YERE DEĞİL AYNI YERİN YENİDEN
    # KURULUŞUNA VARIR."
    if re.search(r"if \(topOverlay\)\s*return", app):
        print("  ✗ KATMAN SEKME AĞACINI SÖKÜYOR (`if (topOverlay) return ...`).")
        print("    Katman, sekme ağacının ÜSTÜNE mutlak konumlu çizilmeli;")
        print("    yoksa her geri dönüş bütün sorguları yeniden koşturur.")
        hata = 1
    elif "position: \"absolute\"" not in app or "OVERLAY_VIEWS[topOverlay]()" not in app:
        print("  ✗ Katman çizimi bulunamadı — nöbetçi kör kaldı.")
        hata = 1
    else:
        print("  ✓ Katman sekme ağacının üstünde — alttaki ekran monte kalıyor.")

    # ── KATALOG ÖNBELLEĞİ ─────────────────────────────────────────────
    kacak = []
    for y in dosyalar():
        with open(y, encoding="utf-8") as f:
            g = kod(f.read())
        if os.path.basename(y) == "katalog.js":
            continue
        # 🔴 İLK KURALIM ÇOK GENİŞTİ: `App.js`teki AĞ YOKLAMASINI da
        # katalog okuması sandı — o satır `select("code").limit(1)`, yani
        # listeyi değil BAĞLANTIYI ölçüyor. Tek satır çeken bir sorgu
        # önbelleklenemez zaten; önbelleklenirse yoklama olmaktan çıkar.
        #
        # 🆕 SINIF: "BİR KURALI YAZARKEN ARADIĞIN ŞEYİN ADINI DEĞİL
        # DAVRANIŞINI TARİF ET — AYNI TABLO İKİ FARKLI İŞ İÇİN OKUNABİLİR."
        for m in re.finditer(r'(from\("airports"\)|rpc\("carrier_options"\))', g):
            kuyruk = g[m.end():m.end() + 220]
            if re.match(r'[\s\S]{0,120}?\.limit\(\s*1\s*\)', kuyruk):
                continue        # bağlantı yoklaması, katalog değil
            kacak.append("%s:%d" % (os.path.relpath(y, KOK), g[:m.start()].count("\n") + 1))
    if kacak:
        print("  ✗ KATALOG ÖNBELLEĞİ ATLANMIŞ: %s" % ", ".join(kacak))
        print("    `airports` (222 satır) ve `carrier_options` değişmeyen")
        print("    listelerdir; her ekran açılışında çekilmemeli.")
        hata = 1
    else:
        print("  ✓ Katalog okumalarının hepsi önbellekten (src/katalog.js).")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Performans bulgusu var.")
        return 1
    print("✓ App performans denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
