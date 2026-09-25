# -*- coding: utf-8 -*-
"""
LoungeLink · bcbp_check.py  —  60. DENETİM
BİNİŞ KARTI AYRIŞTIRICISI (IATA Res. 792)

🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (v5.9.0 biniş kartı briefi)
Brief "barkodun ilk 3 karakterini kırp" diyordu. Ölçtüm: BCBP zorunlu
bloğu SABİT KONUMLU ve kalkış havalimanı 31. karakterde. İlk 3 karakter
`M1I` — format kodu + bacak sayısı + soyadın ilk harfi. Brief olduğu gibi
uygulansaydı HER doğrulama başarısız olurdu.

Bu denetim `src/bcbp.js`i GERÇEKTEN KOŞTURUR (node ile) ve 40+ dize
üzerinde davranışını sınar. Ayrıştırıcı ya DOĞRU ayrıştırır ya AÇIKÇA
reddeder; sessiz yanlış dönerse denetim kırmızı yanar.

⚠️ NEDEN SENTETİK DİZELER: gerçek biniş kartı barkodu PNR + ad taşır,
yani kişisel veridir. Depoya gerçek bilet koymak, korumak için yazdığımız
kuralı ilk biz çiğnemek olurdu. Dizeler spesifikasyondan üretildi.

🆕 SINIF: "BİR AYRIŞTIRICI EMİN OLMADIĞINDA TAHMİN ETMEMELİ — YARI DOĞRU
BİR AYRIŞTIRMA, HİÇ AYRIŞTIRMAMAKTAN TEHLİKELİDİR, ÇÜNKÜ ÜRÜN ONA
GÜVENİR."
"""
import os, sys, json, subprocess, tempfile, datetime, pathlib

KOK = os.path.dirname(os.path.abspath(__file__))
BCBP = os.path.join(KOK, "src", "bcbp.js")
# 🔴 13 EYLUL · GOKBERK'IN MAKINESINDE PATLADI, BENIMKINDE DEGIL:
#   ERR_UNSUPPORTED_ESM_URL_SCHEME ... Received protocol 'c:'
# Asagidaki betik bu yolu dogrudan `import ... from "<yol>"` icine
# gomuyordu. Linux'ta `/home/...` gecerli bir belirtec; Windows'ta
# `C:\...` ESM'e gore "c:" SEMASIDIR ve ters bolu de kacis karakteri.
# Yani kapi, ayristiriciyi hic kosturamadan "AYRISTIRICI KOSTURULAMADI"
# diyordu — urunde bir sey yokken kirmizi yaniyordu.
# 🆕 SINIF: "BIR YOLU KOD ICINE GOMUYORSAN ONU DOSYA YOLU DEGIL URL
# YAP — `file://` HER ISLETIM SISTEMINDE AYNI SEYI SOYLER."
BCBP_URL = pathlib.Path(BCBP).as_uri()


def alan(s, n):
    """n karakterlik alana sola dayalı, boşlukla doldurulmuş."""
    return (s + " " * n)[:n]


def dize(ad="INAK/GOKBERK", pnr="ABC123", kalkis="IST", varis="AYT",
         tasiyici="TK ", ucus="1979 ", gun="256", kabin="Y", koltuk="012A",
         sira="0042 ", durum="1", fmt="M", bacak="1"):
    """Zorunlu 60 karakterlik bloğu spesifikasyona göre kurar."""
    return (fmt + bacak + alan(ad, 20) + "E" + alan(pnr, 7)
            + alan(kalkis, 3) + alan(varis, 3) + alan(tasiyici, 3)
            + alan(ucus, 5) + alan(gun, 3) + alan(kabin, 1)
            + alan(koltuk, 4) + alan(sira, 5) + alan(durum, 1) + "00")


BUGUN = "2026-09-13"
bu = datetime.date(2026, 9, 13)


def jgun(d):
    return str(d.timetuple().tm_yday).zfill(3)


# ── VAKALAR: (ad, dize, beklenen) ─────────────────────────────────────
# beklenen: dict → ok:true ve bu alanlar tutmalı | str → ok:false ve bu kod
VAKALAR = []

# 1-6 · SAĞLAM DİZELER
VAKALAR += [
    ("temel IST", dize(gun=jgun(bu)), {"kalkis": "IST", "ucusTarihi": BUGUN,
                                       "ucusKodu": "TK1979", "kabinKodu": "Y"}),
    ("AYT kalkis", dize(kalkis="AYT", varis="IST", gun=jgun(bu)),
     {"kalkis": "AYT", "ucusTarihi": BUGUN}),
    ("SAW kalkis", dize(kalkis="SAW", gun=jgun(bu)), {"kalkis": "SAW"}),
    ("3 harfli tasiyici", dize(tasiyici="PGT", ucus="2100 ", gun=jgun(bu)),
     {"ucusKodu": "PGT2100"}),
    ("business kabin", dize(kabin="J", gun=jgun(bu)), {"kabinKodu": "J"}),
    ("E format kodu", dize(fmt="E", gun=jgun(bu)), {"kalkis": "IST"}),
]

# 7-10 · ⚠️ BRİEFTEKİ HATA: ilk 3 karakter kalkış DEĞİLDİR
VAKALAR += [
    ("ilk3 != kalkis (INAK)", dize(ad="INAK/GOKBERK", gun=jgun(bu)), {"kalkis": "IST"}),
    ("ilk3 != kalkis (SAHIN)", dize(ad="SAHIN/AYSE", gun=jgun(bu)), {"kalkis": "IST"}),
    ("ilk3 != kalkis (ISTANBULLU)", dize(ad="ISTANBULLU/ALI", gun=jgun(bu)), {"kalkis": "IST"}),
    ("kisa soyad", dize(ad="AK/EGE", gun=jgun(bu)), {"kalkis": "IST", "soyad": "AK"}),
]

# 11-16 · JULIAN YIL ÇIKARIMI (yılbaşı ve artık yıl sınırları)
VAKALAR += [
    ("julian bugun", dize(gun=jgun(bu)), {"ucusTarihi": BUGUN}),
    ("julian dun", dize(gun=jgun(bu - datetime.timedelta(days=1))),
     {"ucusTarihi": str(bu - datetime.timedelta(days=1))}),
    ("julian yarin", dize(gun=jgun(bu + datetime.timedelta(days=1))),
     {"ucusTarihi": str(bu + datetime.timedelta(days=1))}),
    # 001 · Eylül'de bakıldığında en yakın 1 Ocak GELECEK yıl (2027-01-01
    # 110 gün sonra; 2026-01-01 255 gün önce)
    ("julian 001 (yilbasi)", dize(gun="001"), {"ucusTarihi": "2027-01-01"}),
    # 365 · en yakın 31 Aralık BU yıl
    ("julian 365", dize(gun="365"), {"ucusTarihi": "2026-12-31"}),
    # 366 · 31 Aralık, YALNIZ artık yılda var. Referans 2026'da üç aday
    # (2025/2026/2027) da artık değil → ayrıştırıcı AÇIKÇA REDDEDİYOR.
    # ⚠️ İLK BEKLENTİM YANLIŞTI, AYRIŞTIRICI DOĞRUYDU: "en yakın artık yılı
    # bul" deseydim 2028-12-31'e, yani iki yıl sonrasına giderdik. İki yıl
    # sonrasına biniş kartı olmaz; uydurulmuş bir tarih, reddedilmiş bir
    # tarihten tehlikelidir.
    # 🆕 SINIF: "BİR SINAMA BEKLENTİSİ TUTMADIĞINDA ÖNCE BEKLENTİYİ
    # SORGULA — TEST, KODUN DEĞİL SENİN VARSAYIMININ AYNASIDIR."
    ("julian 366 (artik olmayan pencere)", dize(gun="366"), "bcbp_tarih_okunmadi"),
]

# 17-26 · AÇIKÇA REDDEDİLMESİ GEREKENLER (sessiz yanlış YOK)
VAKALAR += [
    ("bos dize", "", "bcbp_kisa"),
    ("cok kisa", "M1INAK", "bcbp_kisa"),
    # ⚠️ 74 karakterlik bir URL uzunluk kapısını GEÇER; onu eleyen şey
    # format kodudur ('h' ≠ M/E). Beklentimi `bcbp_kisa` yazmıştım;
    # ayrıştırıcı haklıydı. Uzunluk bir BCBP işareti değildir.
    ("market QR (uzun ama BCBP degil)",
     "https://ornek.com/kampanya/12345678901234567890123456789012345678", "bcbp_degil"),
    ("kisa QR", "https://ornek.com/x", "bcbp_kisa"),
    ("59 karakter", dize(gun=jgun(bu))[:59], "bcbp_kisa"),
    ("format kodu X", dize(fmt="X", gun=jgun(bu)), "bcbp_degil"),
    ("bacak 0", dize(bacak="0", gun=jgun(bu)), "bcbp_degil"),
    ("bacak harf", dize(bacak="A", gun=jgun(bu)), "bcbp_degil"),
    ("kalkis rakamli", dize(kalkis="1ST", gun=jgun(bu)), "bcbp_havalimani_okunmadi"),
    ("kalkis bos", dize(kalkis="   ", gun=jgun(bu)), "bcbp_havalimani_okunmadi"),
    ("julian 000", dize(gun="000"), "bcbp_tarih_okunmadi"),
    ("julian 999", dize(gun="999"), "bcbp_tarih_okunmadi"),
    ("julian harf", dize(gun="ABC"), "bcbp_tarih_okunmadi"),
]

# 27-30 · TÜRKÇE AD KATLAMASI (aynı sınıfı üçüncü kez ödemeyelim)
VAKALAR += [
    ("turkce ad ASCII gelir", dize(ad="INAK/GOKBERK", gun=jgun(bu)),
     {"soyad": "INAK", "ad": "GOKBERK"}),
    ("noktali I", dize(ad="ISIK/IREM", gun=jgun(bu)), {"soyad": "ISIK", "ad": "IREM"}),
    ("uzun ad kirpilir", dize(ad="ABCDEFGHIJ/KLMNOPQRSTUV", gun=jgun(bu)), {}),
    ("tek isim", dize(ad="MADONNA", gun=jgun(bu)), {"soyad": "MADONNA"}),
]

# 31-34 · DEĞİŞKEN/KOŞULLU ALANLI UZUN DİZELER (zorunlu blok yine okunur)
uzun = dize(gun=jgun(bu)) + ">3180 M6242BTK 0071234567890 1TK TK 1234567890123    Y"
VAKALAR += [
    ("kosullu alanlarla", uzun, {"kalkis": "IST", "ucusTarihi": BUGUN}),
    ("sonunda bosluk", dize(gun=jgun(bu)) + "    ", {"kalkis": "IST"}),
    ("iki bacak", dize(bacak="2", gun=jgun(bu)), {"kalkis": "IST"}),
    ("dort bacak", dize(bacak="4", gun=jgun(bu)), {"kalkis": "IST"}),
]

# ── Node ile gerçekten koştur ─────────────────────────────────────────
betik = """
import { bcbpCoz, kuralUyum, asciiKatla, bcbpBul } from %s;
const girdi = JSON.parse(process.argv[2]);
const bugun = new Date(2026, 8, 13);
const out = girdi.map(([ad, s]) => {
  try { return { ad, r: bcbpCoz(s, bugun) }; }
  catch (e) { return { ad, patladi: String(e && e.message || e) }; }
});
// Ek: kural motoru ve yardimcilar
const c = bcbpCoz(%s, bugun);
out.push({ ad: "__kural_havalimani", r: kuralUyum(c, { airport_code: "AYT", avail_date: "2026-09-13" }, bugun) });
out.push({ ad: "__kural_tam", r: kuralUyum(c, { airport_code: "IST", avail_date: "2026-09-13" }, bugun) });
out.push({ ad: "__kural_ad", r: kuralUyum(c, { airport_code: "IST", avail_date: "2026-09-13", guest_name: "Gökberk İnak" }, bugun) });
out.push({ ad: "__kural_ad_yabanci", r: kuralUyum(c, { airport_code: "IST", avail_date: "2026-09-13", guest_name: "Zeynep Yıldırım" }, bugun) });
out.push({ ad: "__katla", r: { v: asciiKatla("Gökberk İnak") } });
out.push({ ad: "__bul", r: { v: bcbpBul("bilet bilgisi: " + %s + " son") } });
out.push({ ad: "__bul_yok", r: { v: bcbpBul("burada barkod yok") } });
console.log(JSON.stringify(out));
""" % (json.dumps(BCBP_URL), json.dumps(dize(gun=jgun(bu))), json.dumps(dize(gun=jgun(bu))))

with tempfile.NamedTemporaryFile("w", suffix=".mjs", delete=False, encoding="utf-8") as f:
    f.write(betik)
    yol = f.name

girdi = json.dumps([[ad, s] for ad, s, _ in VAKALAR], ensure_ascii=False)
cev = subprocess.run(["node", yol, girdi], capture_output=True, text=True, cwd=KOK)
os.unlink(yol)
if cev.returncode != 0:
    print("bcbp_check · ✗ ayrıştırıcı KOŞTURULAMADI")
    print(cev.stderr.strip()[:900])
    sys.exit(1)

sonuc = {x["ad"]: x for x in json.loads(cev.stdout)}
hata = []
for ad, s, bekle in VAKALAR:
    g = sonuc.get(ad)
    if g is None:
        hata.append((ad, "sonuç dönmedi")); continue
    if "patladi" in g:
        hata.append((ad, "AYRIŞTIRICI PATLADI: " + g["patladi"])); continue
    r = g["r"]
    if isinstance(bekle, str):
        if r.get("ok"):
            hata.append((ad, f"reddedilmeliydi ({bekle}), kabul edildi: kalkis={r.get('kalkis')}"))
        elif r.get("kod") != bekle:
            hata.append((ad, f"red kodu {r.get('kod')}, {bekle} bekleniyordu"))
    else:
        if not r.get("ok"):
            hata.append((ad, f"ayrıştırılmalıydı, reddedildi: {r.get('kod')}")); continue
        for k, v in bekle.items():
            if r.get(k) != v:
                hata.append((ad, f"{k}={r.get(k)!r}, {v!r} bekleniyordu"))

# ── Kural motoru davranışı ────────────────────────────────────────────
k1 = sonuc["__kural_havalimani"]["r"]
if k1.get("gecti") is not False or not any(x["kod"] == "havalimani_uyusmuyor" for x in k1.get("sert", [])):
    hata.append(("kural: havalimani", "IST bilet AYT ilanda GEÇMEMELİYDİ"))
k2 = sonuc["__kural_tam"]["r"]
if k2.get("gecti") is not True:
    hata.append(("kural: tam uyum", f"geçmeliydi: {k2}"))
k3 = sonuc["__kural_ad"]["r"]
if any(x["kod"] == "ad_uyusmuyor" for x in k3.get("yumusak", [])):
    hata.append(("kural: ad katlama", "«Gökberk İnak» ↔ «INAK/GOKBERK» eşleşmeliydi"))
k4 = sonuc["__kural_ad_yabanci"]["r"]
if not any(x["kod"] == "ad_uyusmuyor" for x in k4.get("yumusak", [])):
    hata.append(("kural: yabanci ad", "farklı ad UYARMALIYDI"))
if k4.get("gecti") is not True:
    hata.append(("kural: ad yumuşak mı", "ad uyuşmazlığı doğrulamayı ENGELLEMEMELİ (yumuşak)"))
if sonuc["__katla"]["r"]["v"] != "GOKBERK INAK":
    hata.append(("asciiKatla", f"«{sonuc['__katla']['r']['v']}» ≠ «GOKBERK INAK»"))
if not sonuc["__bul"]["r"]["v"]:
    hata.append(("bcbpBul", "metin içindeki BCBP dizesi bulunamadı"))
if sonuc["__bul_yok"]["r"]["v"]:
    hata.append(("bcbpBul", "olmayan barkodu 'buldu' — sessiz yanlış"))

# ── Kaynak değişmezleri ───────────────────────────────────────────────
kaynak = open(BCBP, encoding="utf-8").read()
if "slice(30, 33)" in kaynak.replace("[30, 33]", "slice(30, 33)"):
    pass
if "kalkis:           [30, 33]" not in kaynak.replace("kalkis:        [30, 33]", "kalkis:           [30, 33]"):
    if "[30, 33]" not in kaynak:
        hata.append(("ofset", "kalkış alanı 30-33 değil — brief'in ilk-3-karakter hatası geri gelmiş olabilir"))
# Varış SAKLANMAMALI: dönen nesnede `varis` anahtarı olmamalı
if '\n    varis:' in kaynak or '\n    varis ' in kaynak:
    hata.append(("gizlilik", "varış havalimanı dönen nesnede — iş kuralı istemiyor, saklanmamalı"))
# PNR dışarı verilmemeli
if "\n    pnr:" in kaynak:
    hata.append(("gizlilik", "PNR dönen nesnede — PNR+soyadı rezervasyon anahtarıdır"))

print(f"bcbp_check · {len(VAKALAR)} dize + 8 davranış sınaması · bulgu: {len(hata)}")
for ad, m in hata[:12]:
    print(f"   ✗ {ad}: {m}")
if len(hata) > 12:
    print(f"   … ve {len(hata) - 12} tane daha")

if hata:
    print("\n✗ BCBP ayrıştırıcısı beklenen davranışı vermiyor.")
    print("  Ofsetler `src/bcbp.js · ALAN` içinde ve SPESİFİKASYONDAN gelir.")
    print("  Kalkış 31-33. karakterdir; 'ilk 3 karakter' format kodudur.")
    sys.exit(1)
print("✓ ayrıştırıcı doğru ayrıştırıyor, emin olmadığında açıkça reddediyor")
