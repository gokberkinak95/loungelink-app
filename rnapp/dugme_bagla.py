#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dugme_bagla.py — `S.btn` / `st.btn` bloklarını `<Btn>` bileşenine çevirir.

🔴 NEDEN
Onaylanan düğme sistemi (gradyan + sıcak gölge + üst ışık) `src/ui.js`
içindeki `Btn` bileşeninde duruyor ve ÖLÇTÜM: uygulamada `<Btn>` SIFIR
kez kullanılıyor. Yani tasarımı ürün koduna geçirdim ama ürün onu
çağırmıyor — bir önceki hatanın (tasarımın çizim betiğinde kalması)
tam olarak bir sonraki katmandaki hâli.

🆕 SINIF: "BİR BİLEŞENİ YAZMAK ONU ÜRÜNE SOKMAZ — ÇAĞRI SAYISINI
ÖLÇMEDİYSEN, YAZDIĞIN ŞEY ÖLÜ KOD OLABİLİR."

DÖNÜŞÜM — kalıp tek tip olduğu için mekanik:

    <TouchableOpacity style={S.btn} onPress={X} disabled={Y}>
      {B ? <ActivityIndicator color="#fff" /> : <Text style={S.btnText}>{L}</Text>}
    </TouchableOpacity>
        ↓
    <Btn label={L} onPress={X} disabled={Y} busy={B} />

⚠️ GÜVENLİK: yalnız TAM eşleşen kalıplar dönüştürülüyor. Eşleşmeyen blok
ELLE bırakılıyor ve raporda listeleniyor — "çoğunu çevirdim, gerisini
tahmin ettim" diye bir şey yok. Yedek `_yedek_dugme/` altına alınıyor.
"""
import datetime
import os
import re
import shutil
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
YEDEK = os.path.join(KOK, "_yedek_dugme",
                     datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
HEDEF = ["src/screens.js", "src/ekranlar_ana.js", "src/ekranlar_yalin.js",
         "src/ortak.js", "src/HostWallet.js", "src/MomentScreen.js", "App.js"]

AC = re.compile(r"<TouchableOpacity\b")


def etiket_sonu(g, i):
    """`<TouchableOpacity ...>` etiketinin kapanış `>` konumu."""
    derinlik, j, tirnak = 0, i, None
    while j < len(g):
        c = g[j]
        if tirnak:
            if c == tirnak:
                tirnak = None
        elif c in "\"'":
            tirnak = c
        elif c == "{":
            derinlik += 1
        elif c == "}":
            derinlik -= 1
        elif c == ">" and derinlik == 0:
            return j
        j += 1
    return -1


def blok_sonu(g, j):
    """Eşleşen `</TouchableOpacity>`."""
    derinlik, k = 1, j
    while k < len(g):
        if g.startswith("</TouchableOpacity>", k):
            derinlik -= 1
            if derinlik == 0:
                return k + 19
            k += 19
            continue
        if g.startswith("<TouchableOpacity", k):
            derinlik += 1
            k += 17
            continue
        k += 1
    return -1


def oz(ifade):
    """
    Etiket içeriğini `label={...}` içine konabilecek TEK BİR ifadeye çevirir.

    🔴 İLK HÂLİM SADECE DIŞ SÜSLÜ PARANTEZİ SOYUYORDU ve bir yerde
    `{t.send} →` gibi KARIŞIK içerik vardı: JSX ifadesi + düz metin.
    Soyunca `label={{t.send} →}` çıktı — sözdizimi hatası.

    Tek bir blokta patlaması şanstı; sessizce yanlış etiket üretmesi de
    mümkündü. Artık üç durum ayrı ayrı ele alınıyor ve hiçbiri tahmin
    değil.

    🆕 SINIF: "BİR DÖNÜŞTÜRÜCÜNÜN 'ÇOĞU DURUMDA ÇALIŞMASI' YETMEZ —
    ELE ALMADIĞI DURUMU FARK EDEMİYORSA, SESSİZCE YANLIŞ ÜRETİR."
    """
    s = ifade.strip()
    # (1) tek ifade: {t.save}
    if s.startswith("{") and s.endswith("}") and s.count("{") == 1:
        return s[1:-1].strip()
    # (2) düz metin: Kaydet
    if "{" not in s:
        return '"%s"' % s.replace('"', '\\"')
    # (3) karışık: {t.send} → · şablon dizesine çevir
    govde = re.sub(r"\{([^{}]+)\}", lambda mm: "${" + mm.group(1).strip() + "}", s)
    return "`" + govde + "`"


def cevir(blok):
    """Blok → `<Btn .../>` ya da None (dönüştürülemedi)."""
    m = AC.search(blok)
    j = etiket_sonu(blok, m.start())
    etiket, govde = blok[:j + 1], blok[j + 1:blok.rindex("</TouchableOpacity>")]

    stil = re.search(r"style=\{(\[)?(st|S)\.btn(Text)?\b", etiket)
    if not stil or stil.group(3):
        return None
    ek = ""
    if stil.group(1):                      # style={[S.btn, {...}]}
        ms = re.search(r"style=\{\[\s*(?:st|S)\.btn\s*,\s*(\{.*?\})\s*\]\}", etiket, re.S)
        if not ms:
            return None
        ek = ms.group(1)

    def al(ad):
        mm = re.search(ad + r"=\{", etiket)
        if not mm:
            return None
        s = mm.end() - 1
        d, k = 0, s
        while k < len(etiket):
            if etiket[k] == "{":
                d += 1
            elif etiket[k] == "}":
                d -= 1
                if d == 0:
                    return etiket[s:k + 1]
            k += 1
        return None

    onp, dis = al("onPress"), al("disabled")
    a11y = re.search(r'accessibilityLabel=(\{[^}]*\}|"[^"]*")', etiket)
    if not onp:
        return None

    g = govde.strip()
    # (a) {busy ? <ActivityIndicator .../> : <Text style={S.btnText}>{L}</Text>}
    ma = re.match(r"^\{\s*(.+?)\s*\?\s*<ActivityIndicator[^/]*/>\s*:\s*"
                  r"<Text style=\{(?:st|S)\.btnText\}>(.*?)</Text>\s*\}$", g, re.S)
    # (b) <Text style={S.btnText}>{L}</Text>
    mb = re.match(r"^<Text style=\{(?:st|S)\.btnText\}>(.*?)</Text>$", g, re.S)
    if ma:
        bekle, etiket_metin = ma.group(1).strip(), ma.group(2).strip()
    elif mb:
        bekle, etiket_metin = None, mb.group(1).strip()
    else:
        return None

    p = ["label={%s}" % oz(etiket_metin)]
    p.append("onPress=%s" % onp)
    if dis:
        p.append("disabled=%s" % dis)
    if bekle:
        p.append("busy={%s}" % bekle)
    if a11y:
        p.append("a11yLabel=%s" % a11y.group(1))
    if ek:
        p.append("style={%s}" % ek)
    return "<Btn " + " ".join(p) + " />"


def main():
    os.makedirs(YEDEK, exist_ok=True)
    cevrilen, atlanan = 0, []
    for rel in HEDEF:
        yol = os.path.join(KOK, rel)
        if not os.path.exists(yol):
            continue
        g = open(yol, encoding="utf-8").read()
        ham, n = g, 0
        i = 0
        while True:
            m = AC.search(g, i)
            if not m:
                break
            j = etiket_sonu(g, m.start())
            if j < 0:
                i = m.end()
                continue
            son = blok_sonu(g, j + 1)
            if son < 0:
                i = m.end()
                continue
            blok = g[m.start():son]
            if not re.search(r"style=\{(\[)?(st|S)\.btn\b", blok[:j - m.start() + 1]):
                i = m.end()
                continue
            yeni = cevir(blok)
            if yeni:
                g = g[:m.start()] + yeni + g[son:]
                i = m.start() + len(yeni)
                n += 1
            else:
                atlanan.append((rel, re.sub(r"\s+", " ", blok)[:96]))
                i = m.end()
        if n:
            shutil.copy2(yol, os.path.join(YEDEK, os.path.basename(rel)))
            open(yol, "w", encoding="utf-8").write(g)
            print("  ✓ %-26s %2d düğme <Btn> oldu" % (rel, n))
            cevrilen += n
    print("\ntoplam %d çevrildi · %d elle bırakıldı" % (cevrilen, len(atlanan)))
    for rel, ornek in atlanan:
        print("  · %-22s %s" % (rel, ornek))
    print("yedek: %s" % YEDEK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
