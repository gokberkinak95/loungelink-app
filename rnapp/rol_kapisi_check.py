# -*- coding: utf-8 -*-
"""
rol_kapisi_check.py — GUEST HOST YÜZEYİNE ULAŞABİLİYOR MU?

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "Guest ilan açma ve ilanlarım gibi ekranları görebiliyor
ve ilan açabiliyor. Bu guest'in temasına aykırı. Guest ilan açamamalı,
ilanlarım gibi bir ekran görememeli. Bu madde ÇOK KRİTİK."

Sızıntı tek bir düğmeydi (`HostDaveti` içindeki "+ Müsaitlik Ekle") ve
onu bulmak için üç dosyayı okumak gerekti — çünkü kapı bir yerde,
düğme başka yerde, terfi ise SUNUCUDAYDI.

Bir rol kapısı, tek bir `if` ile korunmaz: korunacak yüzey birden çok
dosyaya dağılmıştır ve her yeni ekran onu yeniden delebilir. Bu nöbetçi
o yüzeyi SAYIYOR.

🆕 SINIF: "BİR YETKİ KAPISI TEK BİR KOŞUL DEĞİL BİR YÜZEYDİR — YÜZEYİ
SAYMAYAN BİR DENETİM, DELİĞİ AÇILDIĞI GÜN GÖREMEZ."

NE ÖLÇÜYOR (dördü de mutasyonla test edildi):
  1) İlan formunu açan HER yol rolle kapılı mı?
  2) `HostDaveti` (host OLMAYANA gösterilen ekran) ilan formuna kapı
     açıyor mu?
  3) Alt sekme şeridi role bağlı mı?
  4) Sunucu kapısı (SQL 261) yerinde mi ve sessiz terfi gitti mi?
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")


def oku(*p):
    y = os.path.join(*p)
    if not os.path.exists(y):
        return ""
    with open(y, encoding="utf-8") as f:
        return f.read()


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


def main():
    hata = 0
    print("=" * 70)
    print("ROL KAPISI — guest host yüzeyine ulaşabiliyor mu?")
    print("=" * 70)

    app = kod(oku(KOK, "App.js"))
    yalin = kod(oku(KOK, "src", "ekranlar_yalin.js"))

    # ── 1) İLAN FORMUNU AÇAN OVERLAY ROLLE KAPILI MI ───────────────────
    # `addAvail` overlay'i `HostAvailability`yi çiziyor. O satırda rol
    # kontrolü yoksa, onu açan HERHANGİ bir çağrı formu açar.
    m = re.search(r"addAvail:\s*\(\)\s*=>\s*\((.{0,600}?)\),\n", app, re.S)
    print("\n  1) İlan formu overlay'i")
    if not m:
        print("     ✗ `addAvail` overlay tanımı bulunamadı — nöbetçi kör.")
        hata += 1
    elif "HostAvailability" not in m.group(1):
        print("     ✗ overlay artık `HostAvailability` çizmiyor — nöbetçi kör.")
        hata += 1
    elif not re.search(r'role\s*===\s*"host"', m.group(1)):
        print("     ✗ ROL KONTROLÜ YOK. Bu overlay'i açan her çağrı,")
        print("       host olmayan birine ilan formunu açar.")
        hata += 1
    else:
        print("     ✓ `role === \"host\"` ile kapılı.")

    # ── 2) HOST OLMAYANA GÖSTERİLEN EKRAN KAPI AÇIYOR MU ───────────────
    print("\n  2) HostDaveti (host olmayana gösterilen ekran)")
    hd = re.search(r"export function HostDaveti\(\{([^}]*)\}\)", yalin)
    if not hd:
        print("     ✗ HostDaveti bulunamadı — nöbetçi kör.")
        hata += 1
    else:
        props = [p.strip() for p in hd.group(1).split(",")]
        if "onAddAvail" in props:
            print("     ✗ `onAddAvail` PROP'U GERİ GELMİŞ.")
            print("       Bu ekran host OLMAYANA gösteriliyor; ilan formuna")
            print("       açılan bir kapı burada olamaz.")
            hata += 1
        else:
            print("     ✓ İlan formuna açılan prop yok (%s)" % ", ".join(props))
        # Gövdede de bir çağrı kalmasın
        i = yalin.index("export function HostDaveti")
        govde = yalin[i:i + 9000]
        if "onAddAvail" in govde or "setShowAddAvail" in govde:
            print("     ✗ Gövdede hâlâ ilan formu çağrısı var.")
            hata += 1

    # ── 3) ALT SEKME ŞERİDİ ROLE BAĞLI MI ──────────────────────────────
    print("\n  3) Planım alt sekme şeridi")
    if not re.search(r'role\s*===\s*"host"\s*&&\s*\(\s*\n\s*<View[^>]*flexDirection: "row"', app):
        # Daha gevşek ara: subTabListings çizen blok bir rol koşulu içinde mi
        j = app.find("subTabListings")
        pencere = app[max(0, j - 500):j]
        if 'role === "host"' not in pencere:
            print("     ✗ 'İlanlarım' sekmesi role bağlı DEĞİL — guest de görüyor.")
            hata += 1
        else:
            print("     ✓ Şerit yalnız host'a çiziliyor.")
    else:
        print("     ✓ Şerit yalnız host'a çiziliyor.")

    # ── Gövde dalı da kapılı mı ────────────────────────────────────────
    # 🔴 13 EYLÜL — BU DENETİM ŞEKLİ SINIYORDU, ÖZELLİĞİ DEĞİL.
    # Eski hâli şu dizgiyi arıyordu:
    #     hostTripsSub === "ilan" && role === "host"
    # Niyeti doğruydu ("misafir derin bağlantıyla host yüzeyine
    # giremesin") ama ÖLÇTÜĞÜ şey kaynağın BİÇİMİYDİ. O biçim, v2.96'nın
    # `HostDaveti` merdivenini ÖLÜ DALA düşürüyordu: dış koşul zaten
    # `role === "host"` istediği için iç `else` dalına girilmesi
    # imkânsızdı. Koşul düzeltilince (rol sorusu yalnız içte) niyet
    # KORUNDU ama dizgi kayboldu ve denetim kırmızı yandı — yani doğru
    # düzeltmeyi engelledi.
    # Artık ÖZELLİK ölçülüyor: `tab === "trips"` gövdesinde `<Hosting`
    # YALNIZCA bir `role === "host"` üçlüsünün DOĞRU dalında olabilir ve
    # yanlış dalında `HostDaveti` bulunmalı.
    # 🆕 SINIF: "BİR DENETİM KAYNAĞIN BİÇİMİNİ SINIYORSA, İYİLEŞTİRMEYİ
    # DE HATA SAYAR — SINANACAK ŞEY BİÇİM DEĞİL ÖZELLİKTİR."
    t0 = app.find('{tab === "trips" && (hostTripsSub')
    h0 = app.find("<Hosting", t0) if t0 >= 0 else -1
    if t0 < 0 or h0 < 0:
        print("     ✗ Planım gövde dalı bulunamadı (yapı değişmiş).")
        hata += 1
    else:
        onsoz = app[t0:h0]
        # `<Hosting`ten sonraki dal: aynı üçlünün `:` tarafı
        sonsoz = app[h0:h0 + 3000]
        rol_kapili = re.search(r'role\s*===\s*"host"\s*\n?\s*\?', onsoz) is not None
        merdiven = "HostDaveti" in sonsoz
        if not rol_kapili:
            print("     ✗ <Hosting> bir `role === \"host\"` üçlüsünün doğru dalında değil.")
            hata += 1
        elif not merdiven:
            print("     ✗ Rol üçlüsünün yanlış dalında `HostDaveti` yok — misafir boşluğa düşer.")
            hata += 1
        else:
            print("     ✓ <Hosting> rolle kapılı; misafir merdiveni görüyor (derin bağlantı dâhil).")

    # ── 4) SUNUCU KAPISI ───────────────────────────────────────────────
    print("\n  4) Sunucu kapısı (SQL 261)")
    s261 = oku(SQL, "261_rol_kapisi.sql")
    if not s261:
        print("     ✗ sql/261_rol_kapisi.sql YOK.")
        hata += 1
    else:
        # Yorumları at: kapıyı ANLATAN satır, kapının KENDİSİ değildir.
        temiz = re.sub(r"--[^\n]*", "", s261)
        # 🔴 ÜÇÜNCÜ KEZ AYNI TUZAK — VE BU KEZ KURAL OLARAK YAZIYORUM.
        # Dosyanın TAMAMINDA arama yapmak, ön kontrol bloğunun ve
        # nöbetçinin kendi metnini de bulur; mutasyon testi geçmedi çünkü
        # `create_availability_base` adı dosyada BAŞKA yerlerde de var.
        # Ölçülecek şey FONKSİYONUN GÖVDESİ; ölçüm de oraya daralmalı.
        #
        # 🆕 SINIF: "BİR DAVRANIŞI DOSYA GENELİNDE ARARSAN, O DAVRANIŞI
        # SORGULAYAN VE ANLATAN SATIRLARI DA BULURSUN — ARAMA ALANINI
        # DAVRANIŞIN YAŞADIĞI GÖVDEYE DARALT."
        gm = re.search(
            r"create or replace function public\.create_availability\("
            r"[\s\S]*?\$fn261\$([\s\S]*?)\$fn261\$", temiz)
        govde261 = gm.group(1) if gm else ""
        # 🔴 İLK SÜRÜMÜM BURADA KENDİ MUTASYONUNU KAÇIRDI.
        # Düz `"not_a_host" in temiz` araması YEŞİL yanıyordu, çünkü 261'in
        # KENDİ nöbetçi bloğunda `position('not_a_host' in v_metin)` diye
        # bir satır var. Yani kapıyı sildiğimde, kapının VARLIĞINI SORAN
        # cümle "kapı var" cevabını üretiyordu.
        #
        # 🆕 SINIF: "BİR ŞEYİN VARLIĞINI ANAHTAR KELİMEYLE ARARSAN, O
        # ŞEYİ SORGULAYAN KODU DA BULURSUN — DAVRANIŞI ARA, KELİMEYİ DEĞİL."
        if not re.search(r"raise\s+exception\s+'not_a_host'", govde261 or temiz):
            print("     ✗ 261'de `raise exception 'not_a_host'` kapısı yok.")
            hata += 1
        elif re.search(r"update\s+users\s+set\s+role", temiz):
            print("     ✗ 261 hâlâ sessiz rol terfisi içeriyor.")
            hata += 1
        elif not govde261:
            print("     ✗ 261'de `create_availability` gövdesi bulunamadı — nöbetçi kör.")
            hata += 1
        elif "create_availability_base" not in govde261:
            # 🔴 BU KURAL BENİM KENDİ HATAMDAN DOĞDU VE ONU YAKALARDI.
            # 261'in ilk sürümünde kapıyı `create_availability`nin ESKİ
            # gövdesine gömdüm. Oysa SQL 215 o gövdeyi
            # `create_availability_base` diye yeniden adlandırıp üstüne
            # 9 parametreli (p_carrier'lı) ince bir SARMALAYICI koymuştu.
            # Yani düzelttiğim şey artık GİRİŞ NOKTASI DEĞİLDİ: migration
            # yeşil yanar, kapı kapalı görünür, app 9 parametreyle eski
            # yola gider ve guest ilan açmaya devam ederdi.
            #
            # `contract_check.py` beni yakaladı ("FAZLA parametre
            # ['p_carrier']") ama o denetim BAŞKA bir soru soruyordu ve
            # yakalaması bir şanstı. Bu satır artık DOĞRUDAN soruyor.
            #
            # 🆕 SINIF: "BİR KAPIYI SARMALANMIŞ BİR GÖVDEYE KOYARSAN,
            # KAPI DEĞİL DEKOR YAPMIŞ OLURSUN — KAPI GİRİŞ NOKTASINDA
            # DURMALIDIR."
            print("     ✗ Kapı SARMALAYICIDA değil. 261 `create_availability_base`i")
            print("       çağırmıyor — yani giriş noktası olmayan bir gövdeyi")
            print("       düzeltmiş olabilir. App 9 parametreyle eski yola gider.")
            hata += 1
        elif "p_carrier" not in (gm.group(0) if gm else ""):
            print("     ✗ 261'deki imza `p_carrier` içermiyor — app'in çağırdığı")
            print("       9 parametreli giriş noktası bu DEĞİL.")
            hata += 1
        else:
            print("     ✓ Kapı 9 parametreli GİRİŞ NOKTASINDA (`_base` sarmalayıcısı).")
            print("     ✓ Sessiz terfi ulaşılamaz (kapı `_base`ten önce).")

    print("\n" + "=" * 70)
    if hata:
        print("✗ %d rol kapısı bulgusu." % hata)
        print("  Gökberk'in 'çok kritik' dediği madde bu — kapatılmadan gönderme.")
        return 1
    print("✓ Rol kapısı: guest hiçbir yoldan ilan yüzeyine ulaşamıyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
