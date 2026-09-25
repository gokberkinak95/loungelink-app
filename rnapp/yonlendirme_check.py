#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""yonlendirme_check.py — HER TIKLAMA GERCEKTEN BIR YERE GIDIYOR MU?

🔴 NEDEN VAR (24 Agustos 2026)

Gokberk: "App icerisinde de tum yonlendirmelerin dogru ve eksiksiz
oldugundan emin ol. Yani ben bir yere tikladigimda gercekten oraya
yonelebilmeliyim."

Elimizde ZATEN `bos_isleyici_check.py` var ama o yalniz GOVDESI BOS
isleyicileri buluyor. Bu uygulamada yonlendirme bir "route" degil, bir
PROP: `onOpenChat`, `onWallet`, `onAddTrip`... Bileşen o prop'u cagiriyor,
App.js onu VERIYORSA bir yere gidiliyor, VERMIYORSA hicbir sey olmuyor.

Ve tipik yazim su:

    <TouchableOpacity onPress={() => onOpenProfile && onOpenProfile(id)}>

`onOpenProfile` gelmemisse bu dugme SESSIZCE hicbir sey yapmaz. Ne hata,
ne uyari, ne cokme. Kullanici basar, ekran durur. Bos isleyici denetimi
bunu goremez cunku govde BOS DEGIL — yalnizca CALISMIYOR.

🆕 SINIF: "BIR YONLENDIRME PROP ISE, O PROP'U VERMEMEK YONLENDIRMEYI
SILMEKTIR — VE SESSIZ BIR SILME HICBIR DENETIME TAKILMAZ."

BU DENETIMIN OLCTUGU UC SEY:

  (1) OLU YONLENDIRME — bileşen bir `on*` prop'unu CAGIRIYOR ama hicbir
      cagri yeri onu VERMIYOR. O dugme hicbir yere gitmiyor.

  (2) ISIMSIZ CAGRI YERI — bir bileşen bir yerde `on*` prop'suz
      cagriliyor ama BASKA yerde ayni prop'la cagriliyor. Iki cagri yeri
      farkli davraniyor demektir; kasitliysa gerekce ister.

  (3) OLU KAPI — `setShowX(true)` cagriliyor ama `showX` hicbir yerde
      OKUNMUYOR (yani acilan sey cizilmiyor).

BEYAZ LISTE: gercekten istege bagli olan prop'lar (varsayilani olan,
ya da yalniz bazi baglamlarda anlamli olan) GEREKCESIYLE burada.
"""
import io
import os
import re
import sys
import json
import pathlib
import collections

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "src"

# ── GEREKCELI ISTISNALAR ────────────────────────────────────────────────
# Bir prop burada YALNIZCA "verilmemesi de dogru" ise durabilir.
BEYAZ_LISTE = {
    "onBack":        "Modal/ekran kendi kendine kapanabilir; kok ekranda geri YOK.",
    "onRefresh":     "Listeyi tazeleme istege bagli; veren ekran tazeler, vermeyen kendi ic durumunu kullanir.",
    "onDone":        "Form bitince ust ekran kapatir; bazi kullanimlarda bileşen kendi kapaniyor.",
    "onClose":       "onBack ile ayni gerekce.",
    "onFocusDone":   "Odak temizleme yalniz odakli acilista anlamli.",
    "onClearRadar":  "Radar suzgeci yoksa temizlenecek bir sey de yok.",
    "onOpen":        "Yasal belge acici — yalniz belge listesi olan ekranlarda anlamli.",
    "onPress":       "Genel dokunma prop'u; tasiyici bileşenlerde istege bagli.",
    "onChange":      "Kontrollu girdi; salt-okunur kullanimda verilmez.",
    "onSelect":      "Secici bileşenleri salt-gosterim modunda da kullaniliyor.",
    "onToggle":      "Katlanir basliklar kendi durumlarini tutabiliyor.",
    "onRate":        "Degerlendirme kisayolu yalnız oturum gecmisi olan ekranlarda.",
    "onRetry":       "Yeniden dene yalniz ag hatasi gosteren kabuklarda.",
}

# `setX` cagriliyor ama `X` okunmuyor — GEREKCELI istisnalar.
OKUNMAYAN_BEYAZ = {
    "tick": "Kasitli: 30 sn'de bir yeniden cizim tetiklemek icin var. Degeri "
            "OKUNMAMASI dogru; okunsaydi gereksiz bir bagimlilik olurdu.",
}

# `on*` disinda da yonlendirme tasiyan prop adlari
EK_YONLENDIRME = {"go", "setTab", "setScreen"}

JS = re.compile(r"\.js$")


def dosyalar():
    out = []
    app = HERE / "App.js"
    if app.exists():
        out.append(app)
    if SRC.is_dir():
        out += sorted(SRC.rglob("*.js"))
    return out


def yorumsuz(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    return s


# ── (A) BILESEN TANIMLARI: adi + yikilan prop'lari + govdesi ────────────
TANIM = re.compile(
    r"(?:export\s+)?function\s+([A-Z][\w$]*)\s*\(\s*\{([^}]*)\}", re.S)


def bilesenler(kaynaklar):
    """ad -> {"props": set, "govde": str, "dosya": str}"""
    out = {}
    for yol, src in kaynaklar:
        for m in TANIM.finditer(src):
            ad = m.group(1)
            ham = m.group(2)
            props = set()
            for p in re.split(r",(?![^{]*\})", ham):
                p = p.strip()
                if not p:
                    continue
                # `onX = () => {}` varsayilanli → istege bagli, atla
                if "=" in p:
                    continue
                p = re.split(r"[:\s]", p)[0].strip()
                if re.match(r"^[A-Za-z_$][\w$]*$", p):
                    props.add(p)
            # govde: tanimdan sonraki 40.000 karakter (bileşen sinirini
            # tam bulmak icin ayrastirici gerekir; burada ONEMLI olan
            # prop'un GECIP GECMEDIGI — fazla okumak yanlis NEGATIF degil,
            # yanlis POZITIF uretmez cunku fazladan okunan metin baska bir
            # bileşene ait ve orada da ayni prop kullaniliyorsa zaten ayni
            # sonuc cikar.)
            bas = m.end()
            out[ad] = {"props": props, "bas": bas, "dosya": str(yol.name),
                       "src": src}
    return out


def govde_sinir(src, bas):
    """Bir sonraki ust seviye `function`/`const X =` bildirimine kadar."""
    m = re.search(r"^(?:export\s+)?(?:async\s+)?function\s+[\w$]|"
                  r"^(?:export\s+)?(?:const|let|var)\s+[\w$]+\s*=", src[bas:], re.M)
    return src[bas: bas + (m.start() if m else len(src))]


# ── (B) CAGRI YERLERI: <Comp ... /> ─────────────────────────────────────
def cagri_yerleri(kaynaklar, adlar):
    """ad -> [set(verilen prop)] her cagri yeri icin"""
    out = collections.defaultdict(list)
    for yol, src in kaynaklar:
        for m in re.finditer(r"<([A-Z][\w$]*)\b", src):
            ad = m.group(1)
            if ad not in adlar:
                continue
            # etiketin sonunu bul: derinlik sayarak `>` ara
            i = m.end()
            derin = 0
            son = None
            while i < len(src):
                c = src[i]
                if c == "{":
                    derin += 1
                elif c == "}":
                    derin -= 1
                elif c == ">" and derin <= 0:
                    son = i
                    break
                elif c in "\"'" and derin <= 0:
                    j = src.find(c, i + 1)
                    i = j if j > 0 else i
                i += 1
            if son is None:
                continue
            govde = src[m.end(): son]
            verilen = set(re.findall(r"(?:^|\s)([A-Za-z_$][\w$]*)\s*=\s*[{\"']", govde))
            if re.search(r"\{\s*\.\.\.", govde):
                verilen.add("__yayilim__")
            out[ad].append((verilen, str(yol.name)))
    return out


def main() -> int:
    print("=" * 72)
    print("YONLENDIRME DENETIMI — tikladigim yere gercekten gidiyor muyum?")
    print("=" * 72)

    kaynaklar = [(p, yorumsuz(p.read_text(encoding="utf-8", errors="ignore")))
                 for p in dosyalar()]
    if not kaynaklar:
        print("✗ kaynak okunamadi — denetim KOSMADI (sessiz gecmiyor).")
        return 2

    comp = bilesenler(kaynaklar)
    cagri = cagri_yerleri(kaynaklar, set(comp))

    olu = []          # (bileşen, prop, dosya)
    tutarsiz = []     # (bileşen, prop, veren, vermeyen)
    incelenen = 0

    for ad, bilgi in sorted(comp.items()):
        govde = govde_sinir(bilgi["src"], bilgi["bas"])
        yerler = cagri.get(ad, [])
        if not yerler:
            continue                      # hic cagrilmayan bileşen: baska denetimin isi
        for p in sorted(bilgi["props"]):
            if not (p.startswith("on") and len(p) > 2 and p[2].isupper()) \
               and p not in EK_YONLENDIRME:
                continue
            # Bu prop govdede GERCEKTEN cagriliyor mu?
            if not re.search(r"\b" + re.escape(p) + r"\s*(\(|&&|\?\.|\))", govde):
                continue
            incelenen += 1
            veren = [d for (v, d) in yerler if p in v or "__yayilim__" in v]
            vermeyen = [d for (v, d) in yerler if p not in v and "__yayilim__" not in v]
            if not veren:
                if p not in BEYAZ_LISTE:
                    olu.append((ad, p, bilgi["dosya"]))
            elif vermeyen and p not in BEYAZ_LISTE:
                tutarsiz.append((ad, p, len(veren), len(vermeyen)))

    # ── (C) OLU KAPI: setShowX cagriliyor ama showX okunmuyor ───────────
    olu_kapi = []
    for yol, src in kaynaklar:
        for m in set(re.findall(r"\bset([A-Z][\w$]*)\s*\(", src)):
            degisken = m[0].lower() + m[1:]
            if not re.search(r"useState", src):
                continue
            if not re.search(r"\b(?:const|let)\s*\[\s*" + re.escape(degisken)
                             + r"\s*,\s*set" + re.escape(m) + r"\s*\]", src):
                continue
            # degisken govdede OKUNUYOR mu (atama disinda)
            okuma = re.findall(r"(?<![.\w])" + re.escape(degisken) + r"(?![\w(])", src)
            if len(okuma) <= 1 and degisken not in OKUNMAYAN_BEYAZ:
                olu_kapi.append((str(yol.name), degisken))

    hata = 0
    print(f"  bileşen          : {len(comp)}")
    print(f"  cagri yeri       : {sum(len(v) for v in cagri.values())}")
    print(f"  incelenen prop   : {incelenen}")
    print(f"  gerekceli istisna: {len(BEYAZ_LISTE)}")

    if olu:
        print()
        print(f"  ✗ {len(olu)} OLU YONLENDIRME — bileşen cagiriyor, HICBIR cagri yeri vermiyor:")
        for ad, p, d in olu:
            print(f"      {ad}.{p}   ({d})  → bu dugme HICBIR YERE gitmiyor")
        print()
        print("  Her biri icin karar ver: prop'u VER, ya da BEYAZ_LISTE'ye")
        print("  GEREKCESIYLE ekle. Sessizce birakmak = olmayan bir dugme cizmek.")
        hata = 1
    else:
        print("  ✓ olu yonlendirme yok — cagrilan her on* prop'u en az bir yerden veriliyor")

    if tutarsiz:
        print()
        print(f"  ⚠ {len(tutarsiz)} TUTARSIZ CAGRI YERI (ayni bileşen, bazi yerde prop var bazi yerde yok):")
        for ad, p, a, b in tutarsiz[:12]:
            print(f"      {ad}.{p} — {a} yerde veriliyor, {b} yerde VERILMIYOR")
        print("  Bu HATA degil ama ayni dugme iki ekranda farkli davraniyor demektir.")

    if olu_kapi:
        print()
        print(f"  ⚠ {len(olu_kapi)} OLU KAPI (setX var, X okunmuyor):")
        for d, v in olu_kapi[:10]:
            print(f"      {d}: {v}")

    return hata


if __name__ == "__main__":
    sys.exit(main())
