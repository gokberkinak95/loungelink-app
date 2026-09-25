# -*- coding: utf-8 -*-
"""
dogrulama_check.py — DOĞRULAMA ZİNCİRİ GERÇEKTEN BÜTÜN MÜ? (41. nöbetçi)

============================================================================
🔴 NEDEN VAR

28 Ağustos, Gökberk: "E-posta ve telefon doğrulamalarımız gerçekten
çalışıyor mu? … Doğrulama sonrasında puanını hemen veriyor muyuz?
Bu kritik bence."

Sordu diye baktım ve ÜÇ kırık halka çıktı. Üçü de "yazılmış" görünüyordu:

  1. `send_otp` bir kod üretip saklıyor, HİÇBİR YERE GÖNDERMİYOR ve
     `{ok:true}` dönüyor. Uygulama `ok` görüp kod ekranına geçiyor.
     Kullanıcı 8 ayrı ekrandan buraya yönlendirilip asla gelmeyecek bir
     SMS'i bekliyordu. Hiçbir yerde HATA YOKTU.

  2. `recompute_trust` e-posta için +10'u KOŞULSUZ veriyordu. Ölçüm:
     doğrulanmamış 10 → doğrulanmış 10 (fark 0). Kullanıcı doğrulama
     ekranından geçiyor, "✓" görüyor, puanı kıpırdamıyordu.

  3. `beta_settings.otp_channel = "email"` ayarını HİÇBİR YER OKUMUYORDU.
     Ürün bir karar vermiş, kod o kararı hiç duymamıştı.

Üçünün ortak paydası: **hiçbiri hata üretmiyordu.** Mevcut 40 nöbetçinin
hepsi yeşildi. Çünkü hepsi "kod doğru mu" diye soruyor; hiçbiri "bu kodun
vaat ettiği şey GERÇEKLEŞİYOR mu" diye sormuyordu.

🆕 SINIF: "BİR ZİNCİRİN HER HALKASI TEK BAŞINA DOĞRU OLABİLİR VE ZİNCİR
YİNE DE HİÇBİR ŞEY TAŞIMAZ — HALKALARI DEĞİL, UÇTAN UCA GEÇEN ŞEYİ ÖLÇ."

============================================================================
NE ÖLÇÜYOR — ÜÇ BAĞIMSIZ SORU

1) VAAT EDİLEN AMA GÖNDERİLMEYEN: uygulama "kod göndereceğiz" diyen bir
   akışa girerken, o kodu gerçekten gönderecek bir mekanizma var mı — ya da
   ekran bunu SUNUCUDAN sorup kendini kapatıyor mu?

2) KAZANILAMAYAN PUAN: `recompute_trust`ta bir bileşen koşulsuz veriliyorsa,
   o bileşeni "kazandıran" bir ekran olmamalı. Varsa kullanıcıya
   yapılmayacak bir iş vaat ediyoruz.

3) ÖLÜ AYAR: `beta_settings`e yazılmış ama hiçbir yerden okunmayan
   anahtarlar. Bir ayar bir kararın kaydıdır; okunmuyorsa mezar taşıdır.

⚠️ Bu denetim CANLI VERİTABANINA BAKMAZ — kaynak metni okur. Amaç
"bugün doğru mu" değil, "yarın sessizce bozulabilir mi".
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
SQL = os.path.abspath(os.path.join(KOK, "..", "sql"))
BUTCE_YOL = os.path.join(KOK, "dogrulama_butce.json")

# Bir kodun kullanıcıya ULAŞMASINI sağlayabilecek mekanizmalar.
# `supabase.auth.signInWithOtp` → Supabase'in kendi e-posta göndericisi.
TASIYICI = (
    "net.http_post", "http_post", "pg_net",
    "twilio", "netgsm", "iletimerkezi", "vonage", "messagebird",
    "signInWithOtp", "resetPasswordForEmail",
)
# ⚠️ `otp_sms_saglayici` BİLEREK BU LİSTEDE DEĞİL. O bir KAPI, taşıyıcı
# değil: gövdede geçmesi "gönderici var" demek değil, "gönderici var mı
# diye BAKIYOR" demektir. İlk yazışımda listeye koymuştum ve denetim
# kendi düzeltmemi "gönderici bulundu" diye yeşile boyadı — yani kuralı
# tam da sınamak istediği durumda kör etti.
# 🆕 SINIF: "BİR KORUMANIN ADINI, KORUDUĞU ŞEYİN KANITI SAYMA."


def js_dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            d.append(os.path.join(SRC, f))
    return d


def js_kaynak():
    return "\n".join(open(y, encoding="utf-8").read() for y in js_dosyalar())


def etkin_sql():
    """`ETKIN_TANIMLAR.sql` — hangi tanımın CANLIDA olduğunun tek kaydı.

    🔴 Tek tek `sql/*.sql` okumak YANLIŞ CEVAP verir: aynı fonksiyon 4
    dosyada tanımlı olabiliyor ve eskisini okuyup "düzelmiş" sanmak,
    257'de bir kez yaşadığım hatanın aynısı olurdu.
    """
    y = os.path.join(SQL, "ETKIN_TANIMLAR.sql")
    if not os.path.exists(y):
        return None
    return open(y, encoding="utf-8").read()


def son_surum_sql():
    """En yüksek numaralı SQL dosyaları — ETKIN_TANIMLAR'dan SONRA yazılmış
    olabilecek düzeltmeler. (ETKIN_TANIMLAR bir anlık görüntüdür; onu
    tek kaynak saymak, en yeni dosyayı görmezden gelmek olurdu.)"""
    if not os.path.isdir(SQL):
        return ""
    p = []
    for f in sorted(os.listdir(SQL)):
        m = re.match(r"^(\d{3})_", f)
        if m and f.endswith(".sql") and int(m.group(1)) >= 260:
            p.append(open(os.path.join(SQL, f), encoding="utf-8").read())
    return "\n".join(p)


def sql_yorumsuz(s):
    """SQL yorumlarını KONUMU KORUYARAK boşaltır.

    🔴 BU DENETİM İLK ÇALIŞTIRMASINDA KENDİ YORUMUNU KANIT SANDI.
    269'un `send_otp` gövdesinde şu satır var:
        -- ⚠️ SMS GÖNDERİMİ BURAYA GELECEK (Edge Function / pg_net → …)
    İçindeki `pg_net` kelimesi "taşıyıcı var" kuralını tetikledi ve
    denetim, GÖNDERİCİSİ OLMAYAN bir fonksiyonu yeşile boyadı — hem de
    tam o durumu yakalamak için yazılmışken.

    Aynı hatayı `ikon_check.py`de de yapmıştım (kendi doküman yorumlarını
    saymıştı). İkinci kez olduğuna göre bu bir dikkatsizlik değil bir DESEN:
    🆕 SINIF: "KAYNAK METNİ ARAYAN HER DENETİM, ÖNCE YORUMLARI ÇIKARMAK
    ZORUNDADIR — ÇÜNKÜ BİR ŞEYİ ANLATAN CÜMLE, O ŞEYİN VARLIĞINA BENZER."
    """
    s = re.sub(r"/\*[\s\S]*?\*/",
               lambda m: "".join(c if c == "\n" else " " for c in m.group(0)), s)
    s = re.sub(r"--[^\n]*", lambda m: " " * len(m.group(0)), s)
    return s


def bolum(baslik):
    print("\n  " + baslik)


def main():
    print("=" * 70)
    print("DOĞRULAMA ZİNCİRİ — vaat edilen şey gerçekten oluyor mu?")
    print("=" * 70)

    js = js_kaynak()
    etkin = etkin_sql()
    yeni = son_surum_sql()
    if etkin is None:
        print("  ⚠ ETKIN_TANIMLAR.sql bulunamadı — SQL tarafı denetlenemedi.")
        etkin = ""
    sql_hepsi = etkin + "\n" + yeni

    hata = 0

    # ══════════════════════════════════════════════════════════════════
    # 1) "KOD GÖNDERECEĞİZ" DİYEN HER AKIŞIN BİR TAŞIYICISI OLMALI
    # ══════════════════════════════════════════════════════════════════
    bolum("1 · KOD VAAT EDEN AKIŞIN TAŞIYICISI VAR MI")

    # `send_otp`ın CANLI gövdesi: en yeni tanım kazanır.
    govdeler = re.findall(
        r"create or replace function public\.send_otp\(.*?\$[a-z0-9_]*\$(.*?)\$[a-z0-9_]*\$",
        sql_hepsi, re.S | re.I)
    if not govdeler:
        print("    ⚠ `send_otp` tanımı bulunamadı — atlandı.")
    else:
        govde = sql_yorumsuz(govdeler[-1])   # son tanım = etkin tanım
        tasir = any(t in govde for t in TASIYICI)
        # Taşıyıcı yoksa fonksiyon SESSİZCE BAŞARILI OLMAMALI.
        durur = bool(re.search(r"raise exception\s+'sms_not_configured'", govde))
        if tasir:
            print("    ✓ `send_otp` bir gönderici mekanizmaya bağlı.")
        elif durur:
            print("    ✓ Gönderici yok — `send_otp` `sms_not_configured` ile DURUYOR")
            print("      (sessizce `ok` dönmüyor).")
        else:
            print("    ✗ `send_otp` HİÇBİR YERE GÖNDERMİYOR ama hata da vermiyor.")
            print("      Kullanıcı asla gelmeyecek bir kodu bekler.")
            hata = 1

        # Ve uygulama, kod ekranına geçmeden önce sunucuya SORMALI.
        if "dogrulama_kanali" in js:
            print("    ✓ Ekran, kanalın açık olup olmadığını sunucudan soruyor.")
        else:
            print("    ✗ Uygulama SMS'in açık olduğunu KOD İÇİNDE varsayıyor.")
            print("      Kanal `dogrulama_kanali()` ile sorulmalı.")
            hata = 1

    # ══════════════════════════════════════════════════════════════════
    # 2) KOŞULSUZ VERİLEN BİR PUANIN "KAZANMA" EKRANI OLAMAZ
    # ══════════════════════════════════════════════════════════════════
    bolum("2 · DOĞRULAMA PUANI GERÇEKTEN KAZANILIYOR MU")

    rt = re.findall(
        r"CREATE OR REPLACE FUNCTION public\.recompute_trust\(.*?\$function\$(.*?)\$function\$",
        sql_hepsi, re.S | re.I)
    if not rt:
        rt = re.findall(
            r"create or replace function public\.recompute_trust\(.*?\$[a-z0-9_]*\$(.*?)\$[a-z0-9_]*\$",
            sql_hepsi, re.S | re.I)
    if not rt:
        print("    ⚠ `recompute_trust` bulunamadı — atlandı.")
    else:
        govde = rt[-1]
        kosulsuz = []
        for m in re.finditer(r"v_c\s*:=\s*v_c\s*\|\|\s*'\{\"(\w+)\":\s*-?\d+\}'", govde):
            ad = m.group(1)
            # Satırın kendisi bir `if …then` içinde mi? Aynı satırda
            # `then` varsa koşulludur.
            satir_bas = govde.rfind("\n", 0, m.start()) + 1
            satir = govde[satir_bas:govde.find("\n", m.end())]
            if not re.search(r"\bthen\b", satir):
                kosulsuz.append(ad)

        if not kosulsuz:
            print("    ✓ Her puan bileşeni bir koşula bağlı — hepsi kazanılabilir.")
        else:
            for ad in kosulsuz:
                print("    ✗ `%s` puanı KOŞULSUZ veriliyor." % ad)
                print("      Kullanıcı '%s doğrula' ekranından geçse bile puanı" % ad)
                print("      değişmez: yapılmamış işin karşılığı peşin ödenmiş.")
            hata = 1

    # ══════════════════════════════════════════════════════════════════
    # 3) ÖLÜ AYARLAR
    # ══════════════════════════════════════════════════════════════════
    bolum("3 · YAZILMIŞ AMA HİÇ OKUNMAYAN AYARLAR")

    # `beta_settings`e yazılan anahtarlar
    yazilan = set()
    for m in re.finditer(
            r"insert into beta_settings\s*\([^)]*\)\s*values\s*\(\s*'([a-z0-9_]+)'",
            sql_hepsi, re.I):
        yazilan.add(m.group(1))
    for m in re.finditer(r"beta_settings\s+set\s+value[^;]*?key\s*=\s*'([a-z0-9_]+)'",
                         sql_hepsi, re.I):
        yazilan.add(m.group(1))

    # 🔴 SİLİNEN AYAR ARTIK "YAZILMIŞ" SAYILMAZ.
    # 269 `otp_demo_mode`u sildi (gövde artık onu okumuyor, bırakmak
    # olmayan bir kontrolü kontrol sanmaya davetti). Ama bu denetim
    # yalnız `insert`leri sayıyordu ve silinmiş anahtarı "ölü ayar"
    # diye raporladı — yani TEMİZLİĞİ KİRLİLİK OLARAK GÖSTERDİ.
    # `yuzey_kullanim_check.py` bugün aynı körlükle kırmızı yandı;
    # ikisi de aynı satırı okumuyordu.
    # 🆕 SINIF: "EKLEMEYİ SAYIP SİLMEYİ SAYMAYAN HER ENVANTER, ZAMANLA
    # GERÇEĞİN ÜSTÜNE ÇIKAR — VE İLK ŞİKÂYETİ DOĞRU YAPILMIŞ İŞE EDER."
    for m in re.finditer(r"delete\s+from\s+beta_settings[^;]*?key\s*=\s*'([a-z0-9_]+)'",
                         sql_hepsi, re.I | re.S):
        yazilan.discard(m.group(1))

    # Okunan: SQL'de `where key = '…'` VEYA uygulama kaynağında geçen ad.
    okunan = set()
    for m in re.finditer(r"where\s+key\s*=\s*'([a-z0-9_]+)'", sql_hepsi, re.I):
        okunan.add(m.group(1))

    # ⚠️ YAZAN SATIR OKUYAN SAYILMAZ. Bir anahtarı yalnız `insert`/`update`
    # eden dosya onu "kullanıyor" değildir. Bu yüzden okuma kümesinden,
    # yalnızca kendi yazma satırında geçen anahtarları düşmek gerekir —
    # ama `where key=` zaten bir okuma/güncelleme filtresi olduğu için
    # burada ayrım yapmak yerine, GERÇEK KULLANIMI şu iki yerde arıyoruz:
    #   · bir fonksiyon gövdesinde `select … from beta_settings … key = X`
    #   · uygulama kaynağında adın geçmesi
    gercek_okuma = set()
    for m in re.finditer(
            r"select[^;]{0,400}?from\s+beta_settings[^;]{0,200}?key\s*=\s*'([a-z0-9_]+)'",
            sql_hepsi, re.I | re.S):
        gercek_okuma.add(m.group(1))
    for k in yazilan:
        if k in js:
            gercek_okuma.add(k)

    # `_note`/`_notice` ile biten anahtarlar BELGEDİR: bir kararın neden
    # alındığını yazarlar, okunmaları beklenmez.
    olu = sorted(k for k in yazilan
                 if k not in gercek_okuma
                 and not k.endswith(("_note", "_notice"))
                 and "_notice_" not in k)

    butce = {}
    if os.path.exists(BUTCE_YOL):
        butce = json.load(open(BUTCE_YOL, encoding="utf-8"))
    tavan = butce.get("olu_ayar", len(olu))

    print("    beta_settings anahtarı: %d yazılan · %d okunan"
          % (len(yazilan), len(gercek_okuma)))
    if olu:
        for k in olu[:12]:
            print("    · ölü: %s" % k)
    print("    Ölü ayar: %d  (tavan %d)" % (len(olu), tavan))

    # 🔴 SIFIR ÖLÇÜM KORUMASI — payda yazılmadan "0 bulgu" bir sonuç değil.
    if not yazilan:
        print("    ✗ Hiç `beta_settings` yazımı bulunamadı — desen bozuk, denetim kör.")
        return 1

    if len(olu) > tavan:
        print("    ✗ ÖLÜ AYAR ARTMIŞ: %d → %d" % (tavan, len(olu)))
        print("      Bir ayar yazdıysan onu OKU; okumayacaksan yazma.")
        hata = 1
    else:
        if len(olu) < tavan:
            butce["olu_ayar"] = len(olu)
            json.dump(butce, open(BUTCE_YOL, "w", encoding="utf-8"),
                      indent=1, sort_keys=True)
            print("    · bütçe güncellendi (yalnız aşağı)")
        print("    ✓ Ölü ayar sayısı artmadı.")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Doğrulama zincirinde bulgu var.")
        return 1
    print("✓ Doğrulama zinciri bütün.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
