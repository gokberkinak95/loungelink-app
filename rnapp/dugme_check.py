# -*- coding: utf-8 -*-
"""
dugme_check.py — DÜĞMELER TEK BİR DİLDEN Mİ KONUŞUYOR?

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "butonlar… görsel olarak etkileyici miyiz?"

Ölçüm: uygulamada 289 dokunulabilir var. 77'si `<Btn>`, **123'ü elle
yazılmış düğme** (zemin + yarıçap + metin). Yani düğmelerin yaklaşık
%60'ı ortak bileşeni atlıyor.

⚠️ VE SEBEP DİSİPLİNSİZLİK DEĞİLDİ. `Btn` uzun süre yalnız TAM GENİŞLİKTE
bir blok olabiliyordu (`full = true`, sabit `height`). Bir çip, bir
segment, bir satır içi eylem o kalıba girmiyordu — o yüzden her biri elle
yazıldı. v3.6'da `cip`/`mini` boyutları ve ikon yuvaları eklendi; kapsam
büyüdü ama 123 çağrı yeri geride kaldı.

🆕 SINIF: "BİR BİLEŞEN SÜREKLİ ATLANIYORSA SORUN DİSİPLİNDE DEĞİL
KAPSAMDADIR — KARŞILAMADIĞI HER İHTİYAÇ KENDİ KOPYASINI DOĞURUR."

============================================================================
NE ÖLÇÜYOR — İKİ AYRI SORU

1) SAYI (çırçır): elle yazılmış düğme sayısı ARTTI MI?
   Hepsini bir turda taşımak, ölçmeden yapılacak 123 görsel değişiklik
   demekti. Taşımadım — ama BÜYÜMESİNİ imkânsız kıldım.

2) GEOMETRİ (sert kural): bir SİNYAL zeminli düğme (`C.goldBtn`,
   `C.tealBtn`, `C.purple`…) `Btn`in köşesinden (`R.md`) başka bir
   köşe kullanamaz.

   Sebep ölçüldü: 9 sinyal düğmesi `R.xs`(10) veya `R.sm`(14) ile
   çiziliyordu; aynı ekranda `<Btn>` `R.md`(20) çiziyordu. Kullanıcı
   ikisini de "birincil düğme" olarak okur ve köşelerin farkını
   TASARIM SANMAZ — dikkatsizlik sanır.

   🆕 SINIF: "AYNI ANLAMI TAŞIYAN İKİ ÖGE FARKLI GEOMETRİYLE ÇİZİLİYORSA,
   KULLANICI İKİNCİ BİR ANLAM ARAR VE BULAMAYINCA ÜRÜNE GÜVENİ AZALIR."

⚠️ ÇIRÇIR dosyası: `dugme_butce.json`.
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "dugme_butce.json")

# Metin taşıyan SİNYAL zeminleri. Tint'ler (goldBg/tealBg…) hariç:
# onlar düğme değil vurgu alanı olabilir.
SINYAL = ("C.goldBtn", "C.tealBtn", "C.dangerBtn", "C.purple",
          "C.gold", "C.teal", "C.red")
BTN_KOSE = ("R.md", "R.full")     # `Btn`in kullandığı iki köşe


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", " ", s)
    s = re.sub(r"^\s*//.*$", " ", s, flags=re.M)
    return s


def dosyalar():
    d = [os.path.join(KOK, "App.js")]
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".js"):
            d.append(os.path.join(SRC, f))
    return d


def _acilis(s, i):
    """`<TouchableOpacity` konumundan açılış etiketinin sonuna kadar.

    🔴 `s.find(">")` KULLANMIYORUM: stil nesnesinin içinde `=>` ya da
    `a > b` geçebilir ve etiket erken kesilir. Süslü parantez derinliği
    sayılıyor; derinlik sıfırken görülen `>` gerçek etiket sonudur.
    """
    d = 0
    while i < len(s):
        if s[i] == "{":
            d += 1
        elif s[i] == "}":
            d -= 1
        elif s[i] == ">" and d == 0:
            return i
        i += 1
    return len(s)


# ══════════════════════════════════════════════════════════════════════════
# 🔴 v3.9 — BU DENETİM ÜÇ TURDUR YANLIŞ ŞEYİ SAYIYORDU.
#
# 28 Ağustos, Gökberk: "neden hâlâ çözmüyoruz bunları. Biz yapamıyo muyuz?"
#
# Taşımaya oturunca borcun ne olduğu değişti. "123 elle yazılmış düğme"nin
# DÖKÜMÜNÜ çıkardım. İki ayrı nüfus çıktı:
#
#   · EYLEM düğmesi  — bir şey YAPAR (kabul et · sohbet · doğrula)   ~57
#   · SEÇİM denetimi — bir şey SEÇER (çip · segment · radyo · kart)  ~66
#
# İkincisi `Btn` ile yazılamaz, çünkü `Btn`in SEÇİLİ DURUMU YOKTU. Yani
# borcun yarısı "taşımadım"dan değil, GİDECEK YER OLMAMASINDAN duruyordu.
# Tek bir sayıya bakan bu denetim, iki farklı problemi tek bir rakamın
# arkasında sakladı ve üç turdur "123" diye rapor etti.
#
# 🆕 SINIF: "İKİ FARKLI SEBEBİ OLAN BİR BORCU TEK SAYIYLA ÖLÇERSEN,
# SAYIYI DÜŞÜREMEZSİN — ÇÜNKÜ HANGİ YARISINA BAKACAĞINI BİLEMEZSİN."
#
# AYRIM ÖLÇÜTÜ (tahmin değil, kodun kendi deseni): bir seçim denetiminde
# HEM zemin HEM metin rengi AYNI koşula bağlı bir üçlü işleçtir:
#     backgroundColor: sel ? C.goldBg : C.card
#     <Text style={{ color: sel ? C.gold : C.body …
# Bir eylem düğmesinde zemin sabittir (ya da yalnız `busy`ye bağlıdır) ve
# metin rengi sabittir. Ölçüt mutasyonla sınandı (aşağıda).
DURUM = re.compile(r"backgroundColor:\s*[^,}]*\?")


def _secim_mi(etiket, govde):
    """Zemin VE metin rengi aynı anda koşulluysa: seçim denetimi."""
    if not DURUM.search(etiket):
        return False
    return bool(re.search(r"color:\s*[^,}]*\?", govde))


# `ui.js`teki ORTAK BİLEŞENLERİN KENDİ GÖVDESİ bir "atlama" değildir —
# atlanan şeyin ta kendisidir. `Btn` ve `Secim` kendi `TouchableOpacity`
# lerini yazmak ZORUNDA; onları saymak, çözümü borç olarak raporlamaktır.
# 🆕 SINIF: "BİR KURALIN SAYACI, KURALIN GEREĞİNİ YERİNE GETİREN KODU DA
# SAYIYORSA, KURALA UYMAK SAYIYI ARTIRIR."
PRIMITIF = ("export function Btn(", "export function Secim(")


def _primitif_icinde(s, i):
    for p in PRIMITIF:
        b = s.find(p)
        if b == -1 or b > i:
            continue
        # bileşenin sonu: bir sonraki sütun-0 `export ` ya da dosya sonu
        son = s.find("\nexport ", b + 1)
        if son == -1:
            son = len(s)
        if b < i < son:
            return True
    return False


def tara(yol):
    s = kod(open(yol, encoding="utf-8").read())
    elle, secim, ihlal = 0, 0, []
    for m in re.finditer(r"<TouchableOpacity\b", s):
        etiket = s[m.start():_acilis(s, m.start())]
        if not (re.search(r"backgroundColor", etiket)
                and re.search(r"borderRadius", etiket)):
            continue                      # düğme değil (sarmalayıcı/satır)
        if _primitif_icinde(s, m.start()):
            continue
        kapanis = s.find("</TouchableOpacity>", m.start())
        govde = s[_acilis(s, m.start()):kapanis if kapanis > 0 else m.start() + 600]
        if _secim_mi(etiket, govde):
            secim += 1
            continue
        elle += 1
        bg = re.search(r"backgroundColor:\s*([A-Za-z0-9_.]+)", etiket)
        if not bg or bg.group(1) not in SINYAL:
            continue
        r = re.search(r"borderRadius:\s*([A-Za-z0-9_.\[\]]+)", etiket)
        kose = r.group(1) if r else "?"
        if kose not in BTN_KOSE:
            ihlal.append((s[:m.start()].count("\n") + 1, bg.group(1), kose))
    return elle, secim, ihlal


def main():
    print("=" * 70)
    print("DÜĞME DENETİMİ — hepsi aynı dilden mi konuşuyor?")
    print("=" * 70)

    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    sec_butce = butce.pop("__secim__", None)

    simdi, sim_sec, artan, tum_ihlal = {}, {}, [], []
    for y in dosyalar():
        ad = os.path.relpath(y, KOK).replace("\\", "/")
        elle, secim, ihlal = tara(y)
        if elle:
            simdi[ad] = elle
        if secim:
            sim_sec[ad] = secim
        for ln, bg, kose in ihlal:
            tum_ihlal.append((ad, ln, bg, kose))
        onceki = butce.get(ad)
        if onceki is not None and elle > onceki:
            artan.append((ad, onceki, elle))

    toplam = sum(simdi.values())
    sec_toplam = sum(sim_sec.values())
    print("\n  Elle yazılmış EYLEM düğmesi: %d  (bütçe: %d)"
          % (toplam, sum(butce.values()) if butce else toplam))
    for ad, n in sorted(simdi.items(), key=lambda x: -x[1])[:8]:
        print("    %-28s %3d" % (ad, n))
    print("\n  Elle yazılmış SEÇİM denetimi: %d  (bütçe: %s)"
          % (sec_toplam, sec_butce if sec_butce is not None else sec_toplam))
    for ad, n in sorted(sim_sec.items(), key=lambda x: -x[1])[:8]:
        print("    %-28s %3d" % (ad, n))
    if sec_butce is not None and sec_toplam > sec_butce:
        print("\n  ✗ SEÇİM DENETİMİ ARTMIŞ: %d → %d" % (sec_butce, sec_toplam))
        print("      Yeni seçim için `<Secim>` kullan"
              " (cip/segment/radyo/kart · ton · dolu).")
        artan.append(("__secim__", sec_butce, sec_toplam))
    elif sec_butce is not None:
        print("  ✓ Seçim denetimi sayısı artmadı.")

    # 🔴 SIFIR ÖLÇÜM KORUMASI — `yuzey_check.py`de payda saymayı
    # unuttuğum için başarıyı arıza sanmıştım. Burada payda `Btn` dahil
    # TÜM dokunulabilirler; sıfır ancak desen bozulunca olur.
    if toplam + sec_toplam == 0 and butce:
        print("\n  ✗ HİÇ DÜĞME BULUNAMADI — desen bozulmuş, denetim kör.")
        return 1

    hata = 0
    if artan:
        print("\n  ✗ ELLE YAZILMIŞ DÜĞME ARTMIŞ:")
        for ad, o, n in artan:
            print("      %-26s %3d → %3d  (+%d)" % (ad, o, n, n - o))
        print("      Yeni düğme için `<Btn>` kullan (sm/cip/mini · sol/sag ikon).")
        hata = 1
    elif butce:
        print("  ✓ Elle yazılmış düğme sayısı artmadı.")

    print("\n  Sinyal zeminli düğmenin köşesi `Btn` ile aynı mı?")
    if tum_ihlal:
        for ad, ln, bg, kose in tum_ihlal:
            print("    ✗ %s:%d  bg=%s  köşe=%s (olması gereken: R.md)"
                  % (ad, ln, bg, kose))
        print("      Aynı anlam, aynı geometri.")
        hata = 1
    else:
        print("    ✓ Sinyal zeminli düğmelerin hepsi R.md / R.full.")

    # ══════════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — TAM GENİŞLİK + YATAY KENAR BOŞLUĞU = TAŞMA.
    #
    # `Btn` tam genişlikte `width: "100%"` alıyor. Aynı düğmeye
    # `marginHorizontal` verilirse toplam genişlik ebeveyni AŞAR ve
    # düğme sağdan ekran dışına çıkar. `LiveStatus`ta tam olarak bu
    # oldu: 14pt taşma, iki tur boyunca görülmedi — çünkü ekranın
    # sahnesi yoktu ve mount testi taşmayı ölçmüyor.
    #
    # Tek bir çağrı yeriydi; yine de nöbetçiye yazıyorum: bir kez olan
    # bir kalıp, ikinci kez de olur ve ikincisini kimse aramaz.
    #
    # 🆕 SINIF: "YÜZDE GENİŞLİK VE KENAR BOŞLUĞU AYNI ÖĞEDE BULUŞURSA
    # TOPLAMLARI EBEVEYNİ AŞAR — BİRİ ÖĞENİN, ÖTEKİ KABIN İŞİDİR."
    # ══════════════════════════════════════════════════════════════════
    print("\n  Tam genişlikte düğmeye yatay kenar boşluğu verilmiş mi?")
    tasan = []
    for y in dosyalar():
        ad = os.path.relpath(y, KOK).replace("\\", "/")
        s = kod(open(y, encoding="utf-8").read())
        for m in re.finditer(r"<Btn\b", s):
            i, derin = m.end(), 0
            while i < len(s):
                if s[i] == "{":
                    derin += 1
                elif s[i] == "}":
                    derin -= 1
                elif s[i] == ">" and derin == 0:
                    break
                i += 1
            et = s[m.start():i]
            if ("marginHorizontal" in et
                    and not re.search(r"\b(cip|mini|daire)\b", et)
                    and "full={false}" not in et):
                tasan.append((ad, s[:m.start()].count("\n") + 1))
    if tasan:
        for ad, ln in tasan:
            print("    ✗ %s:%d  — boşluğu düğmeye değil sarmalayıcıya ver" % (ad, ln))
        hata = 1
    else:
        print("    ✓ Tam genişlikteki hiçbir düğme kabından taşmıyor.")

    yeni = {a: min(n, butce.get(a, n)) for a, n in simdi.items()}
    for a in butce:
        if a not in yeni:
            yeni[a] = 0
    eski_tam = dict(butce)
    if sec_butce is not None:
        eski_tam["__secim__"] = sec_butce
        yeni["__secim__"] = min(sec_toplam, sec_butce)
    else:
        yeni["__secim__"] = sec_toplam
    butce = eski_tam
    if yeni != butce and not artan:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(yeni, f, indent=1, sort_keys=True)
        print("  · bütçe güncellendi (yalnız aşağı)")

    print("\n" + "=" * 70)
    if hata:
        print("✗ Düğme bulgusu var.")
        return 1
    print("✓ Düğme denetimi temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
