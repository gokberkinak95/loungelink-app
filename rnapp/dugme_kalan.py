#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dugme_kalan.py — DÜĞME ZEMİNİ TAŞIYIP DA `<Btn>` OLMAYAN 24 DÜĞMEYİ
ONAYLANAN SİSTEME ÇEVİRİR.

🔴 NEDEN VAR
Gökberk sordu: "iç ekranların hepsi anlaştığımız tasarıma göre mi?"
Ölçtüm ve cevabın yarısı hayırdı: onaylanan düğme sistemi (gradyan +
sıcak gölge + 1px üst ışık) 34 yerde kullanılıyordu, ama **24 düğme
daha** düğme zeminini taşıyıp bileşeni kullanmıyordu — yani düz renk.

Renkleri doğruydu, dokunma alanları korumalıydı, AA geçiyorlardı.
Sadece onaylanan GÖRÜNÜMÜ taşımıyorlardı. Bir tasarım sistemi,
"çoğu yerde" uygulandığında sistem değil tavsiyedir.

🆕 SINIF: "BİR BİLEŞENİ YAZIP ÇAĞRI YERLERİNİN BİR KISMINI ÇEVİRMEK,
İŞİ BİTİRMEK DEĞİL — GERİ KALANI ARTIK 'İSTİSNA' GİBİ GÖRÜNÜR VE
KİMSE ONLARA DOKUNMAZ."

⚠️ YÜKSEKLİK DEĞİŞİYOR VE BUNU SAKLAMIYORUM: bu düğmeler ~34px'ti,
`<Btn sm>` 44px (TAP.minHeight). Yani yerleşim kart içinde bir tık
açılıyor. 44px zaten WCAG 2.5.5'in istediği; şu ana kadar yalnız
`hitSlop` ile karşılanıyordu — görünen kutu küçüktü, dokunulan büyük.
Artık ikisi aynı şeyi söylüyor.

NE KORUNUYOR: `onPress` · `disabled` · erişilebilirlik etiketi ·
yerleşimi etkileyen stil (margin/flex/alignSelf/width) · bekleme
durumu (`ActivityIndicator` varsa `busy` prop'una geçiyor).
"""
import datetime
import glob
import os
import re
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
DOSYA = sorted(glob.glob(os.path.join(KOK, "src", "*.js"))) + [os.path.join(KOK, "App.js")]
ZEMIN = {"goldBtn": "gold", "tealBtn": "teal", "dangerBtn": "danger",
         "amberBtn": "gold", "greenBtn": "teal"}
# Yerleşimi etkileyen ve bu yüzden `style` ile aktarılan anahtarlar.
YERLESIM = ("marginTop", "marginBottom", "marginLeft", "marginRight",
            "marginHorizontal", "marginVertical", "flex", "alignSelf",
            "width", "minWidth", "maxWidth", "position", "top", "bottom",
            "left", "right", "zIndex")


def etiket_sonu(g, i):
    """`<TouchableOpacity ...>` açılış etiketinin kapanış `>` konumu."""
    d, j, q = 0, i, None
    while j < len(g):
        c = g[j]
        if q:
            if c == q:
                q = None
        elif c in "\"'`":
            q = c
        elif c == "{":
            d += 1
        elif c == "}":
            d -= 1
        elif c == ">" and d == 0:
            return j
        j += 1
    return -1


def oz(ifade):
    """`{...}` sarmalını soy."""
    ifade = ifade.strip()
    if ifade.startswith("{") and ifade.endswith("}"):
        return ifade[1:-1].strip()
    return ifade


def prop(tag, ad):
    """
    🔴 İLK HÂLİM REGEX'TİDİ VE İKİ SEVİYEDEN DERİN SÜSLÜ PARANTEZDE
    ÇÖKÜYORDU: `onPress={() => { if (x) { ... } }}` gibi bir gövdede
    eşleşme bulamıyor, betik "onPress yok" deyip 11 düğmeyi atlıyordu.
    Süslü parantez SAYILIR, tahmin edilmez.
    """
    m = re.search(r"(?<![\w.])" + ad + r"=", tag)
    if not m:
        return None
    i = m.end()
    if tag[i] == '"':
        j = tag.index('"', i + 1)
        return tag[i:j + 1]
    if tag[i] != "{":
        return None
    d, j = 0, i
    while j < len(tag):
        if tag[j] == "{":
            d += 1
        elif tag[j] == "}":
            d -= 1
            if d == 0:
                return tag[i:j + 1]
        j += 1
    return None


def etiket_ifadesi(ic):
    """
    JSX çocuklarını TEK bir JS ifadesine çevirir.

    🔴 BU BETİK BİR DAHA KIRILDI VE KIRILMA TANIDIKTI:
        <Text>{cond ? a : b} · {liveClock}</Text>
    karışık bir etiket — ifade + düz metin + ifade. İlk hâlim yalnız
    dıştaki süslüyü soyuyordu ve ortaya
        label={cond ? a : b} · {liveClock} />
    gibi geçersiz JSX çıkıyordu (Babel: "Unexpected character '·'").

    Bunu DAHA ÖNCE `dugme_bagla.py`de çözmüştüm. Yeni bir betik yazıp
    o çözümü yanına almadım — yani düzeltilmiş bir hatayı, düzeltmenin
    bulunduğu dosyanın dışında yeniden ürettim.

    🆕 SINIF: "ÇÖZÜLMÜŞ BİR PROBLEM İÇİN İKİNCİ BİR ARAÇ YAZIYORSAN,
    ÇÖZÜMÜ DE TAŞIMADIYSAN AYNI HATAYI YENİDEN ÜRETİRSİN."

    Karışık içerik şablon dizesine çevriliyor: metin parçaları olduğu
    gibi, `{ifade}` parçaları `${ifade}` olarak. Böylece sonuç hâlâ tek
    bir dize — `Btn`in erişilebilirlik için yaptığı `String(label)`
    çalışmaya devam ediyor. (Fragment kullansaydım o bozulurdu.)
    """
    ic = ic.strip()
    parcalar, i, duz = [], 0, ""
    while i < len(ic):
        if ic[i] == "{":
            d, j = 0, i
            while j < len(ic):
                if ic[j] == "{":
                    d += 1
                elif ic[j] == "}":
                    d -= 1
                    if d == 0:
                        break
                j += 1
            if duz.strip():
                parcalar.append(("metin", duz))
            duz = ""
            parcalar.append(("ifade", ic[i + 1:j].strip()))
            i = j + 1
            continue
        duz += ic[i]
        i += 1
    if duz.strip():
        parcalar.append(("metin", duz))
    if not parcalar:
        return None
    if len(parcalar) == 1:
        t, v = parcalar[0]
        return "{%s}" % v if t == "ifade" else '"%s"' % v.strip()
    # karışık → şablon dizesi
    govde = "".join("${%s}" % v if t == "ifade" else v for t, v in parcalar)
    return "{`%s`}" % govde


def main():
    ye = os.path.join(KOK, "_yedek_dugme_kalan",
                      datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(ye, exist_ok=True)
    toplam, atlanan = 0, []
    for p in DOSYA:
        if not os.path.exists(p):
            continue
        g = open(p, encoding="utf-8").read()
        ham = g
        while True:
            m = re.search(r"<TouchableOpacity(?![\w])", g)
            bulundu = False
            for m in re.finditer(r"<TouchableOpacity(?![\w])", g):
                k = etiket_sonu(g, m.start())
                if k < 0:
                    continue
                tag = g[m.start():k + 1]
                mz = re.search(r"backgroundColor:\s*C\.(\w+)", tag)
                if not mz or mz.group(1) not in ZEMIN:
                    continue
                kapanis = g.find("</TouchableOpacity>", k)
                if kapanis < 0:
                    continue
                govde = g[k + 1:kapanis]
                if govde.count("<TouchableOpacity") or govde.count("<Text") != 1:
                    atlanan.append((os.path.basename(p), "iç içe / birden çok Text"))
                    continue

                mt = re.search(r"<Text[^>]*>(.*?)</Text>", govde, re.S)
                etiket = mt.group(1).strip()
                if not etiket:
                    atlanan.append((os.path.basename(p), "boş etiket"))
                    continue

                # bekleme durumu:  {busy ? <ActivityIndicator/> : <Text>..}
                busy = None
                mb = re.search(r"\{\s*([^?{}]+?)\s*\?\s*<ActivityIndicator", govde)
                if mb:
                    busy = mb.group(1).strip()

                onp = prop(tag, "onPress")
                if not onp:
                    atlanan.append((os.path.basename(p), "onPress yok"))
                    continue
                dis = prop(tag, "disabled")
                a11 = prop(tag, "accessibilityLabel")

                stil = prop(tag, "style") or ""
                tasi = []
                for anahtar in YERLESIM:
                    ms = re.search(anahtar + r":\s*([^,}\n]+)", stil)
                    if ms:
                        tasi.append("%s: %s" % (anahtar, ms.group(1).strip()))
                tam = "alignItems" in stil and "paddingHorizontal" not in stil

                lab = etiket_ifadesi(etiket)
                if not lab or "<" in lab:
                    atlanan.append((os.path.basename(p), "etiket JSX içeriyor"))
                    continue
                yeni = "<Btn v=\"%s\" sm%s label=%s onPress=%s" % (
                    ZEMIN[mz.group(1)], "" if tam else " full={false}", lab, onp)
                if dis:
                    yeni += " disabled=%s" % dis
                if busy:
                    yeni += " busy={%s}" % busy
                if a11:
                    yeni += " a11yLabel=%s" % a11
                if tasi:
                    yeni += " style={{ %s }}" % ", ".join(tasi)
                yeni += " />"

                g = g[:m.start()] + yeni + g[kapanis + 19:]
                toplam += 1
                bulundu = True
                break
            if not bulundu:
                break
        if g != ham:
            shutil.copy2(p, os.path.join(ye, os.path.basename(p)))
            open(p, "w", encoding="utf-8").write(g)
            print("  ✓ %s" % os.path.basename(p))
    print("\n%d düğme onaylı sisteme geçti · %d atlandı" % (toplam, len(atlanan)))
    for ad, sebep in atlanan:
        print("    · %s — %s" % (ad, sebep))
    print("yedek: %s" % ye)
    return 0


if __name__ == "__main__":
    sys.exit(main())
