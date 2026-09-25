# -*- coding: utf-8 -*-
"""
LoungeLink · kural_metni_check.py  —  58. DENETİM
KURAL NOTLARINDA ASCII'LEŞMİŞ TÜRKÇE

🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (4. görsel)
Kural motoru ekranında şu cümle çiziliyordu:
  "Uc uyelik planinin UCUNDE de ayni… MISAFIR YINE 30 EUR — yani misafir
   hakki daha pahali plan alarak KAZANILAMIYOR."
Ürünün EN YETKİLİ ekranında, tek farkımız olan veri, Türkçe harfleri
sökülmüş hâlde duruyordu. Hiçbir nöbetçi bakmıyordu: `hardcodedTrCheck`
JS kaynağındaki Türkçeyi arıyor, bu metin VERİTABANINDAN geliyor.

ÖLÇÜM (yerel, sözcük sınırıyla): 181 satır → SQL 290'dan sonra 0.

NE DENETLİYOR: `sql/` altındaki dosyalarda `notes`/`note`/`guest_note`
kolonlarına yazılan DİZE değerleri. Türkçe bir cümlenin içinde ASCII'ye
düşmüş sözcük varsa sayar. Tavan RATCHET: bugünkü sayıdan yukarı çıkamaz.

⚠️ NE DENETLEMİYOR: çalışan veritabanını. Bu kap Supabase'e erişemiyor;
denetim KAYNAĞA bakıyor. Veriyi 290 düzeltti, bu nöbetçi YENİSİNİN
bozuk gelmesini engelliyor.

🆕 SINIF: "BİR METİN VERİTABANINDAN GELİYOR DİYE ÜRÜNÜN METNİ OLMAKTAN
ÇIKMAZ — EKRANDA ÇIKAN HER CÜMLE DENETLENMELİDİR."
"""
import os, re, sys, glob, json

KOK = os.path.dirname(os.path.abspath(__file__))
SQLDIZ = os.path.join(os.path.dirname(KOK), "sql")
BUTCE = os.path.join(KOK, "kural_metni_butce.json")

# ASCII'ye düşmüş hâli AYRI bir sözcük olmayan, yalnız Türkçe okunuşu olan
# kökler. "hat", "kart", "saat", "bir", "var" gibi zaten doğru sözcükler
# bilerek YOK.
ASCII_TR = re.compile(
    r"\b(icin|degil|degildir|bagimsiz|uyelik|uyeligi|uyesi|ucret|ucretli|ucretsiz|"
    r"gecerli|yalniz|kisi|kisiye|ucus|ucusu|ucusun|olmali|olmasi|oldugunu|"
    r"hakki|girisi|giris|sinirsiz|sinirli|ayni|hicbir|cocuk|cocuklar|kullanici|"
    r"sarti|planin|planina|uzerinden|uzerinde|gunluk|yillik|bazli|kurallari|"
    r"kosullari|duzeyinde|karti|kartini|kartindan|basina|basi|yurtdisi|"
    r"aglarinda|rakami|yanlis|havalimani|degisir|gore|kapatildi|aktarildi|"
    r"mukerrer|birlestirildi|artik|bolumu|bolume|salonlari|yasagi|buyuk)\b", re.I)

# Türkçe cümle mi? (en az bir Türkçe harf ya da Türkçe bağlaç)
TR_ISARET = re.compile(r"[çğıöşüÇĞİÖŞÜ]|\b(ve|veya|ile|için|bir|bu|da|de)\b", re.I)

# Yalnız METİN KOLONLARINA yazılan dizeler
KOLON = re.compile(r"\b(notes|note|guest_note|decision_note|headline|detail)\b", re.I)

# ════════════════════════════════════════════════════════════════════
# 🔴 21 EYLÜL — KÖR ÖLÇÜM TAVANI DÜŞÜRDÜ
#
# Bu denetim bir CIRCIR: bulgu tavandan azsa tavanı kendiliğinden
# indiriyor (`borç azaldı`). Ama `sql/` klasörü yokken hiçbir dosyayı
# okumuyor, 0 bulgu sayıyor ve o 0'ı TAVAN OLARAK YAZIYORDU.
# Klasör geri geldiğinde 43 > 0 → kapı kırmızı. Yani bir kez kör
# koşmak, bütçeyi kalıcı olarak bozuyordu.
#
# Gökberk'te de tam bu oldu: `C:\sql` yokken koştu, `kural_metni_
# butce.json` 0'a düştü. Klasörü açtığı anda bu kapı, kodunda hiçbir
# şey değişmeden kırmızı yanacaktı.
#
# 🆕 SINIF: "KENDİ TAVANINI İNDİREN BİR ÇIRÇIR, ÖLÇEMEDİĞİ TURDA DA
# İNDİRİYORSA, ÇIRÇIR DEĞİL KENDİNİ SİLEN BİR SAYAÇTIR."
# ════════════════════════════════════════════════════════════════════
if not os.path.isdir(SQLDIZ):
    print("kural_metni_check · ✗ sql/ klasörü bulunamadı — KOŞMADI.")
    print("   Aranan: %s" % SQLDIZ)
    print("   Bütçe dosyasına DOKUNULMADI (kör ölçüm tavanı indiremez).")
    print("   ÇÖZÜM: SQL_TAMAMI zip'ini C:\\ altına aç → C:\\sql")
    sys.exit(1)

bulgu = []
if os.path.isdir(SQLDIZ):
    for yol in sorted(glob.glob(os.path.join(SQLDIZ, "*.sql"))):
        ad = os.path.basename(yol)
        if ad.startswith("290_"):            # onarım dosyasının kendisi
            continue
        # 🔴 13 EYLÜL — `ETKIN_TANIMLAR.sql` MUAF: TÜRETİLMİŞ DOSYA.
        # `snapshot_gen.py` her fonksiyonun canlı gövdesini bu dosyaya
        # KOPYALAR. Yani buradaki her dize, kaynak dosyasında ZATEN bir
        # kez sayılıyor. Bu turda anlık görüntüyü yeniden ürettim ve
        # denetim 52'den 57'ye çıktı — borç artmamıştı, AYNI BORÇ İKİNCİ
        # KEZ SAYILIYORDU. Tavanı yükseltmek bu gürültüyü kalıcı hâle
        # getirirdi; doğru olan kaynağı saymak.
        # 🆕 SINIF: "TÜRETİLMİŞ BİR DOSYAYI DENETLERSEN, KAYNAKTAKİ HER
        # BORCU İKİ KEZ ÖDERSİN — VE İKİNCİSİNİ DÜZELTEMEZSİN."
        if ad == "ETKIN_TANIMLAR.sql":
            continue
        s = open(yol, encoding="utf-8", errors="replace").read()
        # kolon adının geçtiği ifadeye yakın dizeler
        for m in re.finditer(r"'((?:[^']|'')*)'", s):
            deger = m.group(1)
            # ⚠️ İLK SÜRÜM GÜRÜLTÜLÜYDÜ: 241 "bulgu"nun çoğu SQL parçasıydı
            # (`grant execute on function…`). Gürültülü bir nöbetçi,
            # nöbetçi değildir — süzgeç sıkılaştırıldı:
            #   · en az 40 karakter ve 6 sözcük  (düzyazı)
            #   · içinde SQL işareti olmayacak
            #   · kolon adı en fazla 120 karakter geride
            if len(deger) < 40 or deger.count(" ") < 5:
                continue
            if re.search(r"\$\$|;\s|\b(grant|select|insert|update|create|execute|function)\b", deger, re.I):
                continue
            bul = ASCII_TR.search(deger)
            if not bul or not TR_ISARET.search(deger):
                continue
            pencere = s[max(0, m.start() - 120):m.start()]
            if not KOLON.search(pencere):
                continue
            satir = s[:m.start()].count("\n") + 1
            # bulunan sözcüğün ETRAFINI göster — 70 karakterlik baş değil
            i = max(0, bul.start() - 25)
            bulgu.append((ad, satir, "…" + deger[i:bul.end() + 25] + "…"))

tavan = None
if os.path.exists(BUTCE):
    try:
        tavan = json.load(open(BUTCE, encoding="utf-8")).get("tavan")
    except Exception:
        tavan = None
if tavan is None:
    tavan = len(bulgu)
    json.dump({"tavan": tavan, "not": "13 Eylül · SQL 290 sonrası taban"},
              open(BUTCE, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

print(f"kural_metni_check · ASCII'ye düşmüş Türkçe not: {len(bulgu)} (tavan {tavan})")
for ad, satir, d in bulgu[:8]:
    print(f"   {ad}:{satir}  «{d}»")
if len(bulgu) > 8:
    print(f"   … ve {len(bulgu) - 8} tane daha")

if len(bulgu) > tavan:
    print("\n✗ ARTMIŞ — yeni bir kural notu Türkçe harfsiz yazılmış.")
    print("  Çözüm: notu Türkçe yaz. Eski veriyi `sql/290` onarıyor.")
    sys.exit(1)
if len(bulgu) < tavan:
    json.dump({"tavan": len(bulgu), "not": "borç azaldı"},
              open(BUTCE, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("  ↓ borç azaldı — tavan güncellendi")
print("✓ yeni Türkçe harfsiz kural notu yok")
