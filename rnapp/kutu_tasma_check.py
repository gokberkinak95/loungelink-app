# -*- coding: utf-8 -*-
"""
LoungeLink · kutu_tasma_check.py  —  56. DENETİM
EKRANDAN TAŞAN KUTU · İKONA YAPIŞIK METİN  (çekilen sahnelerin ölçümünden)

🔴 NEDEN VAR — İKİ KUSUR, İKİSİ DE MEVCUT KAPILARIN KÖR NOKTASINDA
(12 Eylül, Gökberk md.4 ve md.6)

  md.4 "39. görselde ekranda taşma var"
     `tasma_check.js` bir metnin KENDİ kutusuna sığıp sığmadığını ölçer.
     Telefon doğrulama şeridinde metin kendi kutusuna SIĞIYORDU —
     kutu 638 pt'ydi, ekran 390. Yanlış olan metin değil KUTUYDU ve o
     sınıfı hiçbir kapı ölçmüyordu.

  md.6 "plan sayfasında ayda x kredi yazan yerin yanındaki icon bitişik
        duruyor text ile"
     Kaynak kodundan aramak yanıltıcı: boşluk `marginRight`ten de,
     ebeveynin `gap`inden de gelebiliyor. Tek güvenilir yer ÇİZİLMİŞ
     PİKSEL: ikon kutusunun sağ kenarı ile metnin sol kenarı.

NASIL: `web_sahne/cek.py` her sahneyi çekerken tarayıcıdan bu iki ölçümü
alıp JSON'a yazıyor; bu kapı onları okuyor. Yani ölçüm kaynaktan değil
GERÇEK YERLEŞİMDEN geliyor.

⚠️ Metin TAŞIMAYAN kutular sayılmaz: ambiyans halesi (`Hale`) bilerek
ekrandan geniştir ve kırpılır — tasarımın kendisi odur.

🆕 SINIF: "BİR KAPI 'METİN KUTUSUNA SIĞIYOR MU' DİYE SORUYORSA, 'KUTU
EKRANA SIĞIYOR MU' SORUSU HİÇ SORULMAMIŞ DEMEKTİR."
"""
import json, os, sys, glob

TAVAN = 0
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_sahne", "out")

dosyalar = sorted(glob.glob(os.path.join(OUT, "*.json")))
if not dosyalar:
    print("kutu_tasma_check: web_sahne/out boş — önce `python3 web_sahne/cek.py`")
    sys.exit(0)

olculen = 0
tasan, bitisik, eksik = [], [], []
for y in dosyalar:
    ad = os.path.basename(y)[:-5]
    # `karsilama.json` sahne değil, `oniz_cek.py`nin tek karelik çıktısı;
    # `cek.py` ölçüm alanlarını oraya yazmaz.
    if ad.startswith("_") or ad == "karsilama":
        continue
    d = json.load(open(y, encoding="utf-8"))
    if "tasan" not in d or "bitisik" not in d:
        eksik.append(ad)
        continue
    olculen += 1
    for k in d["tasan"]:
        if (k.get("tx") or "").strip():        # yalnız METİN TAŞIYAN kutular
            tasan.append((ad, k))
    for k in d["bitisik"]:
        bitisik.append((ad, k))

print(f"kutu_tasma_check · ölçülen sahne: {olculen}")
if eksik:
    print(f"  ⚠ ölçüm alanı olmayan (eski) sahne JSON'u: {len(eksik)} → cek.py'yi yeniden koştur")

if tasan:
    print(f"\n✗ EKRANDAN TAŞAN, METİN TAŞIYAN KUTU — {len(tasan)}:")
    for ad, k in tasan:
        print(f"   {ad:22} genişlik {k['g']} pt (sol {k['sol']}) · «{k['tx']}»")
else:
    print("  ✓ metin taşıyan hiçbir kutu 390 pt'yi aşmıyor")

if bitisik:
    print(f"\n✗ İKONA YAPIŞIK METİN (< 4 pt) — {len(bitisik)}:")
    for ad, k in bitisik:
        print(f"   {ad:22} boşluk {k['bos']} pt · «{k['tx']}»")
else:
    print("  ✓ satır-içi ikonların tamamında en az 4 pt boşluk var")

if len(tasan) + len(bitisik) > TAVAN:
    sys.exit(1)
