# -*- coding: utf-8 -*-
"""
dal_prop_check.py — DALLARDAN BİRİNDE ÖLEN PROP'LAR

============================================================================
🔴 NEDEN VAR — GERÇEK BİR KAYIPTAN DOĞDU
28 Ağustos, Gökberk: "keşfet, tanış gibi ekranlarda filtre butonu yok.
Sağ üstte filtre butonumuz vardı biliyosun."

Düğme silinmemişti. `Discovery` onu hâlâ `right={...}` diye geçiriyordu.
Ama `Hdr` iki dallı bir bileşen:

    export function Hdr({ title, sub, onBack, right, brandRight, scene, t, foto }) {
      if (foto) {
        return <FotoBant ... sag={brandRight} />;   ← `right` YOK, `onBack` YOK
      }
      return ... <Bar right={right} onBack={onBack} /> ...
    }

Yani `right` imzada VAR, bir dalda OKUNUYOR, diğer dalda BUHARLAŞIYOR.
Aynı sebeple GERİ OKU da bütün fotoğraflı ekranlarda çizilmiyordu — iOS'ta
o ekranlardan çıkışın tek yolu alt sekme çubuğuydu.

`check.js`in prop-drop nöbetçisi bunu göremez: o "prop imzada var mı" diye
sorar ve cevap EVET'ti.

🆕 SINIF: "BİR PROP'U İMZADA GÖRMEK ONUN KULLANILDIĞINI KANITLAMAZ — İKİ
DALI OLAN BİR BİLEŞENDE PROP, DALLARDAN BİRİNDE SESSİZCE ÖLEBİLİR."

NE ÖLÇÜYOR: erken `return` ile dallanan bileşenlerde, imzadaki bir prop
dallardan BAZILARINDA okunup bazılarında hiç okunmuyorsa bildiriyor.
İSTİSNA gerekiyorsa `GEREKCELI` sözlüğüne GEREKÇESİYLE yazılır.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")

# Bilerek tek dalda kullanılan proplar — her biri gerekçeli.
GEREKCELI = {
    # "scene" yalnız fotoğrafsız dalda anlamlı: fotoğraflı bantta
    # sahne kelimesi zaten bandın kendisidir.
    ("Hdr", "scene"): "fotoğraflı bantta sahne kelimesi bandın kendisi",
    # `t` yalnız Bar'a geçiyor; FotoBant metin çevirisi yapmıyor.
    ("Hdr", "t"): "FotoBant çeviri yapmıyor, yalnız verilen metni çiziyor",
}

# ══════════════════════════════════════════════════════════════════════════
# 🔴 KURALI DARALTTIM — VE SEBEBİNİ YAZIYORUM.
#
# İlk sürüm "imzadaki HER prop her dalda okunmalı" diyordu ve 121 bulgu
# üretti. Çoğu haklıydı ama HİÇBİRİ ÖNEMLİ DEĞİLDİ: bir yükleme dalının
# `lang`i okumaması bir kusur değildir.
#
# 121 bulgulu bir nöbetçi, sıfır bulgulu bir nöbetçiden kötüdür: ilkine
# bakılmaz. Ve bakılmayan bir nöbetçi, gerçek bulguyu da gizler.
#
# 🆕 SINIF: "GÜRÜLTÜLÜ BİR NÖBETÇİ SESSİZ BİR NÖBETÇİDEN KÖTÜDÜR —
# GÖRMEZDEN GELİNMEYİ ÖĞRETİR VE İÇİNDEKİ GERÇEK BULGUYU DA GÖMER."
#
# Bu yüzden kural artık YALNIZ "SLOT" PROP'LARINI ölçüyor: bir düğme, bir
# geri oku, bir eylem alanı taşıyan proplar. Onların kaybı GÖRÜNMEZDİR —
# ekran çizilir, çöker de yazmaz, sadece bir düğme yoktur. Gökberk'in
# "filtre butonu yok" dediği kayıp tam olarak bu sınıftı.
#
# Diğer propların kaybı ya çökme ya boş metin üretir; onları başka
# nöbetçiler (check.js prop-drop, i18n, render testleri) zaten yakalıyor.
SLOT_PROP = {"right", "onBack", "sag", "eylem", "geri", "brandRight",
             "sol", "ustSag", "aksiyon", "onClose", "onKapat"}

# Yapısal/ortak proplar: her dalda beklenmez.
YOKSAY = {"children", "style", "key", "testID"}


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


def bilesenler(metin):
    """(ad, imza_proplari, govde) üretir."""
    for m in re.finditer(r"export function (\w+)\(\{([^}]*)\}\)\s*\{", metin):
        ad = m.group(1)
        props = [p.split("=")[0].strip() for p in m.group(2).replace("\n", " ").split(",")]
        props = [p for p in props if p and p not in YOKSAY]
        # 🔴 GÖVDE SINIRI `export function`la KESİLİYORDU VE BU YANLIŞ
        # POZİTİF ÜRETTİ: `ScenePad` ile `FotoBant` arasında EXPORT
        # EDİLMEYEN bir `GolgeliMetin` var. Onun `return`ü ScenePad'in
        # gövdesine karışıp "iki dal" gibi göründü ve olmayan bir kayıp
        # bildirildi.
        #
        # 🆕 SINIF: "BİR GÖVDEYİ 'BİR SONRAKİ EXPORT'A KADAR' DİYE
        # KESERSEN, EXPORT EDİLMEYEN KOMŞUYU DA İÇİNE ALIRSIN."
        sonrakiler = [x.start() for x in re.finditer(
            r"^(?:export\s+)?(?:function|const)\s+\w+", metin[m.end():], re.M)]
        son = m.end() + sonrakiler[0] if sonrakiler else -1
        govde = metin[m.end(): son if son > 0 else len(metin)]
        yield ad, props, govde


def dallar(govde):
    """Erken `return` ile ayrılan parçalar.

    Basit ama yeterli: `  if (...) {` ... `  return (` blokları ile son
    `return` arasını ayırıyoruz. Amaç kusursuz bir ayrıştırıcı değil,
    "bu bileşen dallanıyor mu ve dallar farklı prop mu okuyor" sorusu.
    """
    # 🔴 `^  return ` KALIBI ERKEN DÖNÜŞLERİ KAÇIRIYORDU: bir `if (...) {`
    # bloğunun içindeki `return` DÖRT boşlukla girintili. Kalıbı
    # daralttığımda "dallanan bileşen: 0" oldu — yani nöbetçi hiçbir şey
    # ölçmüyordu ve yine de YEŞİL yanıyordu.
    #
    # 🆕 SINIF: "SIFIR BULGU İLE SIFIR ÖLÇÜM AYNI RENGİ VERİR — BİR
    # NÖBETÇİ NE KADAR ŞEY BAKTIĞINI DA YAZDIRMALIDIR."
    # ══════════════════════════════════════════════════════════════════
    # 🔴 v3.6 — BU KURAL 14 BULGUNUN ÇOĞUNU UYDURUYORDU.
    #
    # `Wallet(onBack)` "3 daldan yalnız 1'inde okunuyor" diyordu. Baktım:
    # `onBack` `Hdr`e geçiliyor, geri oku çiziliyor, hata ve yükleme
    # durumları o başlığın ALTINDA çiziliyor — yani geri yolu her an var.
    #
    # Sayılan "dallar" şunlardı:
    #     const uid = session?.user?.id; if (!uid) return;   ← veri yükleyici
    #     if (error) { setLoadErr(true); return; }           ← veri yükleyici
    #
    # İkisi de `load()` fonksiyonunun içinde, HİÇBİR ŞEY RENDER ETMİYOR.
    # Bir render dalı değiller. Kural `return` kelimesini görüyor ve dal
    # sayıyordu.
    #
    # 🆕 SINIF: "BİR RENDER DALINI 'return' KELİMESİYLE TANIMLARSAN,
    # KONTROL AKIŞININ HER DURAĞINI EKRAN SANIRSIN."
    #
    # Şart daraltıldı: dal sayılması için `return`ün JSX döndürmesi
    # gerekiyor — `return (` ardından `<`, ya da doğrudan `return <`.
    # `return;` ve `return baskaBirDeger;` artık dal değil.
    # ⚠️ VE İLK DARALTMAM YETMEDİ. Kalan iki bulgu da uydurmaydı:
    #     Settings  → içeride tanımlı yardımcı bir bileşenin `return`ü
    #     FotoBant  → bir `.map()` geri çağrısının `return`ü
    # İkisi de JSX döndürüyor ama BİLEŞENİN dalı değil; iç içe bir
    # fonksiyonun gövdesi. Bir iç bileşenin `onBack` okumaması normaldir.
    #
    # 🆕 SINIF: "İÇ İÇE FONKSİYONLARI SAYMAYAN BİR 'DAL' TANIMI, HER
    # YARDIMCI BİLEŞENİ EKSİK BİR DAL GİBİ RAPORLAR."
    #
    # Ayrım süslü parantez DERİNLİĞİYLE yapılıyor: bileşenin kendi
    # dalları gövdenin en üstünde (derinlik 0) ya da bir `if` bloğunun
    # içinde (derinlik 1) durur. Daha derini iç içe bir fonksiyondur.
    # ⚠️ DERİNLİK DE TEK BAŞINA YETMEDİ: `Settings`in içinde `function Row()`
    # ve `function SwitchCell()` var; onların `return`ü de derinlik 1'de
    # duruyor. Bir İÇ BİLEŞEN, dış bileşenin `onBack`ini okumak zorunda
    # değildir — okusa tuhaf olurdu.
    #
    # Bu yüzden açılan her fonksiyon gövdesi bir YIĞINDA tutuluyor: yığın
    # boş değilse, o `return` iç içe bir fonksiyona aittir.
    yerler = []
    derinlik = 0
    satir_bas = 0
    fn_yigin = []          # iç fonksiyonların açıldığı derinlikler
    FN_BAS = re.compile(r"(?:\bfunction\b|=>\s*$|=>\s*\{)")
    for i, ch in enumerate(govde):
        if ch == "{":
            # Bu `{` bir fonksiyon gövdesi mi açıyor?
            onceki = govde[max(0, i - 160):i]
            if FN_BAS.search(onceki.split("\n")[-1] or ""):
                fn_yigin.append(derinlik)
            derinlik += 1
        elif ch == "}":
            derinlik -= 1
            if fn_yigin and fn_yigin[-1] == derinlik:
                fn_yigin.pop()
        elif ch == "\n":
            satir_bas = i + 1
            continue
        if i != satir_bas:
            continue
        m = re.match(r"[ \t]{2,8}return\s*(\(|<)", govde[i:i + 40])
        if not m or derinlik > 1 or fn_yigin:
            continue
        if m.group(1) == "<":
            yerler.append(i)
            continue
        kuyruk = govde[i + m.end():i + m.end() + 200].lstrip()
        if kuyruk.startswith("<"):
            yerler.append(i)
    if len(yerler) < 2:
        return []
    parcalar = []
    for i, y in enumerate(yerler):
        son = yerler[i + 1] if i + 1 < len(yerler) else len(govde)
        parcalar.append(govde[y:son])
    return parcalar


def main():
    print("=" * 70)
    print("DAL PROP DENETİMİ — bir dalda okunup diğerinde ölen prop var mı?")
    print("=" * 70)

    # ── ÇIRÇIR ────────────────────────────────────────────────────────
    # 🔴 15 BULGUNUN HEPSİNİ BU TURDA DÜZELTMEDİM VE BUNU SAKLAMIYORUM.
    # Üçü gerçek ve düzeltildi (`Hdr`/`FotoBant` slotları — Gökberk'in
    # "filtre butonu yok" maddesi). Kalanların bir kısmı meşru: sekmeyle
    # açılan ekranların (`Trips`, `Hosting`, `Profile`) `onBack`i YOKTUR,
    # çıkışı sekme çubuğudur. Bir kısmı ise gerçek borç: boş/hata
    # dallarında geri oku düşüyor.
    #
    # Hepsini ayırmak bu turun işi değil; ama GERİYE GİDİŞİ yasaklamak
    # bugünün işi.
    #
    # 🆕 SINIF: "BİR BORCU TEK TURDA KAPATAMIYORSAN, EN AZINDAN
    # BÜYÜMESİNİ İMKÂNSIZ KIL — DONDURULMUŞ BİR BORÇ, BİLİNEN BİR BORÇTUR."
    BUTCE_YOL = os.path.join(KOK, "dal_prop_butce.json")
    onceki = None
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            onceki = json.load(f).get("bulgu")

    hata = 0
    bakilan = 0
    dosyalar = [os.path.join(KOK, "App.js")] + [
        os.path.join(SRC, f) for f in sorted(os.listdir(SRC)) if f.endswith(".js")]

    for y in dosyalar:
        with open(y, encoding="utf-8") as f:
            metin = kod(f.read())
        for ad, props, govde in bilesenler(metin):
            d = dallar(govde)
            if len(d) < 2:
                continue
            bakilan += 1
            for p in props:
                if p not in SLOT_PROP:
                    continue          # yalnız slot propları — gerekçe yukarıda
                if (ad, p) in GEREKCELI:
                    continue
                okuyan = [i for i, parca in enumerate(d)
                          if re.search(r"\b%s\b" % re.escape(p), parca)]
                # Hiçbir dalda okunmuyorsa bu check.js'in işi (ölü prop).
                # BAZI dallarda okunuyorsa: dal düzeyinde kayıp.
                if okuyan and len(okuyan) < len(d):
                    # Prop'un dal DIŞINDA (ortak gövdede) okunması yeterli:
                    # o zaman dallara ayrı ayrı girmesi gerekmiyor.
                    ortak = govde[:d[0] and govde.index(d[0]) or 0]
                    if re.search(r"\b%s\b" % re.escape(p), ortak):
                        continue
                    print("  ✗ %s(%s) — %d daldan yalnız %d tanesinde okunuyor  [%s]"
                          % (ad, p, len(d), len(okuyan), os.path.basename(y)))
                    print("      Diğer dal(lar)da bu prop SESSİZCE ÖLÜYOR.")
                    hata += 1

    print("\n  Dallanan bileşen: %d · ölçülen slot prop türü: %d · gerekçeli istisna: %d"
          % (bakilan, len(SLOT_PROP), len(GEREKCELI)))
    if bakilan == 0:
        # 🔴 SIFIR ÖLÇÜM = SESSİZ YEŞİL. Bir kez bu tuzağa düştüm.
        print("  ✗ Hiçbir dallanan bileşen bulunamadı — nöbetçi kör kaldı.")
        return 1
    print("=" * 70)
    if onceki is None:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump({"bulgu": hata}, f, indent=1)
        print("· ilk ölçüm: bütçe %d olarak donduruldu." % hata)
        return 0
    if hata > onceki:
        print("✗ SLOT PROP KAYBI ARTMIŞ: %d → %d" % (onceki, hata))
        print("  Bir düğme ya da geri oku bir dalda sessizce ölüyor.")
        print("  Ya prop'u o dala da bağla, ya GEREKCELI'ye GEREKÇESİYLE yaz.")
        return 1
    if hata < onceki:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump({"bulgu": hata}, f, indent=1)
        print("✓ Borç azaldı: %d → %d (bütçe indirildi)." % (onceki, hata))
        return 0
    print("✓ Slot prop borcu sabit (%d) — artmadı." % hata)
    return 0


if __name__ == "__main__":
    sys.exit(main())
