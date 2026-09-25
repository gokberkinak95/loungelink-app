#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""bos_isleyici_check.py — GÖVDESİ BOŞ OLAY İŞLEYİCİSİ

🔴 NEDEN VAR (24 Agustos 2026, Gokberk madde 12):
   "kullanici profiline girdigimdeki mesaj gonder butonuna tiklayinca
    tanis ekranina atiyor. Chat sayfasini acmiyor yani."

   Olctum. App.js'te tek satir:

       onOpenChat={(id, name) => { setPubProfile(null); }}

   Isleyici VARDI, BAGLIYDI ve GOVDESI BOSTU. Yaptigi tek sey acik olan
   ekrani KAPATMAKTI; altinda hangi sekme duruyorsa o goruntuye geliyordu.
   Kullanicinin "beni Tanis'a atiyor" dedigi sey bir yonlendirme degil,
   bir hiclikti.

   Bu hatanin en tehlikeli tarafi GORUNMEZ olmasi:
     · sozdizimi dogru      → parser gormez
     · prop BAGLI           → "olu prop" denetimi gormez
     · RPC cagrisi yok      → sozlesme denetimi gormez
     · hata firlatmiyor     → sessiz yutma denetimi gormez
   Butun nobetcilerin kor noktasi.

🆕 SINIF: "GÖVDESİ BOŞ BİR OLAY İŞLEYİCİSİ, OLMAYAN BİR DÜĞMEDEN DAHA
KÖTÜDÜR — OLMAYAN DÜĞME ÇİZİLMEZ, BOŞ İŞLEYİCİ ÇİZİLİR VE ÇALIŞIYOR
SANILIR."

NE ARIYOR:
  `onXxx={(...) => { ... }}` biciminde bir prop atamasinda, govdenin
  YALNIZCA "kapatma" cagrilarindan olusmasi. Yani:

      onOpenChat={() => { setX(null); }}           → İHLAL
      onOpenChat={() => { setX(null); openY(); }}  → temiz
      onClose={() => setX(null)}                   → temiz (adı kapatmak)

KAPSAM DURUSTLUGU:
  Yalniz "bir yere GITMESI beklenen" isleyicileri denetliyorum. Adi zaten
  kapatmak olan prop'lar (onClose/onBack/onCancel/onDismiss/onDone/
  onFocusDone/onClear...) mesru olarak yalniz kapatir. Genis bir yasak,
  dogru kullanimi cezalandirirdi — site check.js §9'da ogrendigim ders.
"""
import re
import sys
import pathlib

HERE = pathlib.Path(__file__).resolve().parent

# 🔴 İLK SÜRÜM ÇOK GENİŞTİ VE 11 SONUÇ DÖNDÜ — 10'u DOĞRU KULLANIMDI.
# "Temizle", "Vazgeç", "Kapat" düğmeleri MEŞRU olarak yalnız durum
# sıfırlar. Genel `onPress`i "yalnız kapatıyor" diye suçlamak, site
# check.js §9'da ve BO nöbetçisinde yaptığım hatanın aynısıydı:
# "BİR YASAK, BAĞLAMI OLMADAN YAZILIRSA DOĞRU KULLANIMI DA CEZALANDIRIR."
#
# Kapsam iki net kurala indi:
#   (a) TAMAMEN BOŞ gövde  → her prop için ihlal (hiçbir bağlamda doğru değil,
#       tek istisnası aşağıdaki gerekçeli beyaz liste)
#   (b) YALNIZ KAPATAN gövde → sadece BİR YERE GÖTÜRMESİ beklenen prop'lar
#       için ihlal. Adı "aç/git/gönder/kaydet" olan bir prop kapatmakla
#       yetiniyorsa, adı yalan söylüyor demektir.
GIDIS_ADLARI = re.compile(
    r'^on('
    r'Open\w*|Go\w*|Navigate\w*|Rate|Discover|Meet|Add\w+|Edit\w+|'
    r'Select|Submit|Send|Save|Apply|Publish|Verify|Report|Chat|Profile|'
    r'Request\w*|Manage\w*|History|Wallet|Shop|Settings|Campaigns|'
    r'Broadcast|Referral|Trust|Safety|Bell|Ratings|LiveStatus|Role'
    r')$')

# 🔴 `onRequestClose` YUKARIDAKI `Request\w*` desenine takildi ve yanlis
# yere suclandi: adi "Close" ile biten bir prop, tanimi geregi kapatir.
# Kapanis eki HER ZAMAN gidis adindan once gelir.
KAPANIS_EKI = re.compile(r'(Close|Back|Cancel|Done|Dismiss|Hide|Exit)$')

# Kapatma sayilan cagrilar
KAPATMA_CAGRISI = re.compile(
    r'^set[A-Z]\w*\(\s*(null|false|0|""|\'\')\s*\)$'      # setX(null)
    r'|^set[A-Z]\w*\(\s*\)$'
    r'|^[a-z]\w*Kapat\(\s*\)$'
    r'|^on(Back|Close|Done|Cancel)\s*&&\s*on(Back|Close|Done|Cancel)\(\)$'
)

# onXxx={(...) => { govde }}   — tek satirda ya da cok satirda
KALIP = re.compile(
    r'\b(on[A-Z]\w*)=\{\s*\((?P<args>[^)]*)\)\s*=>\s*\{(?P<body>[^{}]*)\}\s*\}')

# 🔴 GEREKÇELİ İSTİSNA — her satirin bir sebebi var. Gerekcesiz ekleme yok;
# aksi halde bu liste "unuttuklarimin cop kutusu" olur (v2.94'te ogrendim).
BEYAZ_LISTE = {
    ("screens.js", "onPress", "() => {}"):
        "Ayarlar > editor modali: karartilmis arka plana dokununca modal "
        "kapanir; ICERIDEKI karta dokunus KAPANMAMALIDIR. RN'de bunun tek "
        "yolu ic kabi da dokunulabilir yapip olayi YUTMAKTIR. Bos govde "
        "burada bilincli bir davranistir, unutulmus bir bagla degil.",
}


def dosyalar():
    for ad in ("App.js",):
        p = HERE / ad
        if p.exists():
            yield p
    src = HERE / "src"
    if src.is_dir():
        for p in sorted(src.glob("*.js")):
            yield p


def main() -> int:
    print("=" * 72)
    print("BOS ISLEYICI DENETIMI — dugme var mi, is yapiyor mu?")
    print("=" * 72)

    ihlaller = []
    taranan = 0
    isleyici = 0

    for p in dosyalar():
        taranan += 1
        ham = p.read_text(encoding="utf-8", errors="ignore")
        satirlar = ham.split("\n")
        # 🔴 İLK KOŞUŞTA KENDİ AÇIKLAMAMI YAKALADI: App.js'teki yorum bloğunda
        # hatanın ESKİ HALİNİ örnek olarak yazmıştım. Yorum kod değildir.
        # Satır numaraları korunsun diye yorumları BOŞLUKLA değiştiriyorum,
        # siliyor değilim.
        def _bosalt(mm):
            return re.sub(r"[^\n]", " ", mm.group(0))
        metin = re.sub(r"/\*.*?\*/", _bosalt, ham, flags=re.S)
        metin = re.sub(r"//[^\n]*", _bosalt, metin)
        for m in KALIP.finditer(metin):
            ad = m.group(1)
            isleyici += 1
            govde = m.group("body")
            # yorumlari at
            govde = re.sub(r"/\*.*?\*/", " ", govde, flags=re.S)
            govde = re.sub(r"//[^\n]*", " ", govde)
            ifadeler = [x.strip() for x in govde.split(";") if x.strip()]
            if not ifadeler:
                sebep = "govde TAMAMEN BOS"
            elif (GIDIS_ADLARI.match(ad) and not KAPANIS_EKI.search(ad)
                  and all(KAPATMA_CAGRISI.match(x) for x in ifadeler)):
                sebep = ("adi BIR YERE GOTURMEYI vaat ediyor ama govde yalniz kapatiyor: "
                         + " ; ".join(ifadeler))
            else:
                continue
            if (p.name, ad, "() => {}") in BEYAZ_LISTE and not ifadeler:
                continue
            if (p.name, ad) in BEYAZ_LISTE:
                continue
            satir = metin[: m.start()].count("\n") + 1
            ihlaller.append((p.name, satir, ad, sebep,
                             satirlar[satir - 1].strip()[:110]))

    print(f"  taranan dosya : {taranan}")
    print(f"  incelenen isleyici : {isleyici}")

    if ihlaller:
        print()
        print(f"  ✗ {len(ihlaller)} olay isleyicisi CIZILIYOR AMA IS YAPMIYOR:")
        for dosya, satir, ad, sebep, kod in ihlaller:
            print(f"      {dosya}:{satir}  {ad}")
            print(f"         {sebep}")
            print(f"         {kod}")
        print()
        print("  Her biri icin karar ver: isleyiciyi BAGLA, dugmeyi KALDIR,")
        print("  ya da bos_isleyici_check.py > BEYAZ_LISTE icine GEREKCESIYLE ekle.")
        return 1

    print("  ✓ cizilen her olay isleyicisi gercekten bir is yapiyor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
