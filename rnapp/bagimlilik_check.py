#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""bagimlilik_check.py — DOSYALAR ARASI DÖNGÜ VE DÖNGÜSEL ÇEKİRDEK

🔴 NEDEN VAR (24 Agustos 2026 · elestiri D2)

Gokberk: "mimari kararlarinda kararlari sana birakiyorum. Gerekli
degerlendirmeleri yapip en dogru ve bize zarar vermeyecek sekilde uygula."

`screens.js` 12.802 satirdi ve "bolelim" demek kolaydi. Once OLCTUM:

    91 ust seviye bildirim · bagimlilik grafi tek bir baglantili bilesen
    katman 0 : 33 bildirim ·   587 satir  — hicbir yerel bagimliligi yok
    katman 1 : 21 bildirim ·  2052 satir  — yalniz katman 0'a bagli
    katman 2 :  8 bildirim ·  1575 satir
    katman 3 :  2 bildirim ·   238 satir
    DONGUSEL CEKIRDEK: 28 bildirim · 8319 satir  (%65)

Yani dosya "kimse bolmedigi icin" degil, EKRANLAR BIRBIRINE BAGLI oldugu
icin buyuk. Cekirdegi temaya gore bolmek (host/guest/social gibi) dosya ICI
bagimliligi DOSYALAR ARASI DONGUYE cevirirdi: ayni baglilik, ustune modul
yukleme sirasi riski.

🆕 SINIF: "BIR DOSYAYI BOLMEK, ICINDEKI BAGIMLILIKLARI COZMEZ — YALNIZCA
ONLARI DOSYALAR ARASI YAPAR."

Bu yuzden yalniz KATMANLANABILIR kismi cikardim (%35, dongusuz bir DAG):
    src/ortak.js          ← katman 0
    src/ekranlar_yalin.js ← katman 1-3
    src/screens.js        ← dongusel cekirdek + `export *` ile disa aktarim

BU DENETIMIN ISI IKI TANE:
  (1) Uygulama kaynagi icinde HICBIR IMPORT DONGUSU olmadigini kanitlamak.
      Metro donguyu tolere eder ama modul yukleme sirasina gore `undefined`
      uretebilir — yani ureticide beyaz ekran, gelistiricide sessizlik.
  (2) Dongusel cekirdegin BUYUMESINI engellemek. Bugun 28 bildirim; yeni bir
      ekran cekirdege bir bag daha eklerse burasi kirmizi yanar ve o bagin
      GEREKLI olup olmadigi TARTISILIR. Borcun kendisi degil, BUYUMESI
      tehlikelidir.
"""
import io
import os
import re
import sys
import pathlib
import collections

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "src"

# 🔴 TAVAN. 26 Agustos: 28 → 0. Deger DUSMEDI, OLCUM DUZELDI: eski tarayici
# yorumlari da sayiyordu (bkz. `kod_govdesi`). Gercek deger bastan beri 0'di.
# Dusurmek serbest, yukseltmek GEREKCE ister.
CEKIRDEK_TAVANI = 0

# Dis bagimliliklar (react, react-native, expo-*) grafa girmez: onlar
# bizim dongumuzu yaratamaz.
YEREL = re.compile(r'^\.{1,2}/')


def moduller():
    """src/*.js + App.js → {modul_adi: (yol, kaynak)}"""
    m = {}
    app = HERE / "App.js"
    if app.exists():
        m["App"] = (app, app.read_text(encoding="utf-8", errors="ignore"))
    if SRC.is_dir():
        for p in sorted(SRC.rglob("*.js")):
            ad = str(p.relative_to(SRC)).replace(os.sep, "/")[:-3]
            m[ad] = (p, p.read_text(encoding="utf-8", errors="ignore"))
    return m


def baglar(kaynak, kendi_ad):
    """Bu modulun import/export ettigi YEREL modul adlari."""
    out = set()
    for kalip in (r'import\s+[^;]*?from\s+"([^"]+)"',
                  r'export\s+\*\s+from\s+"([^"]+)"',
                  r'export\s+\{[^}]*\}\s+from\s+"([^"]+)"'):
        for m in re.finditer(kalip, kaynak):
            yol = m.group(1)
            if not YEREL.match(yol):
                continue
            hedef = yol
            if hedef.startswith("./"):
                hedef = hedef[2:]
            # App.js'ten "./src/x" → "x"
            if kendi_ad == "App" and hedef.startswith("src/"):
                hedef = hedef[4:]
            hedef = hedef[:-3] if hedef.endswith(".js") else hedef
            out.add(hedef)
    return out


def donguleri_bul(g):
    """Tarjan yerine basit DFS: bulunan ILK dongu yeter — kirmizi zaten yanacak."""
    renk = {}
    yol = []
    bulunan = []

    def gez(n):
        renk[n] = 1
        yol.append(n)
        for k in sorted(g.get(n, ())):
            if k not in g:
                continue
            if renk.get(k) == 1:
                i = yol.index(k)
                bulunan.append(yol[i:] + [k])
            elif renk.get(k, 0) == 0:
                gez(k)
        yol.pop()
        renk[n] = 2

    for n in sorted(g):
        if renk.get(n, 0) == 0:
            gez(n)
    return bulunan


def kod_govdesi(s):
    """Yorumlari ve dizeleri BOSLUKLA degistirir, satir sayisini korur.

    🔴 26 AGUSTOS — BU FONKSIYON BIR HATANIN UZERINE YAZILDI.

    D2 turunda "dongusel cekirdek 28 bildirim" diye olctum ve buna dayanarak
    bir MIMARI KARAR verdim: "bolmek ise yaramaz, once bagliligi cozmek
    gerek". Sonra sasirtici bir bag gordum: `TimeInput -> AddVisit`. Bir saat
    girisi bileseninin seyahat ekleme ekranina bagli olmasi mantiksizdi.
    Baktim: bag bir YORUM SATIRINDAN geliyordu.

    Yorumlari ve dizeleri ayiklayinca cekirdek 28'den SIFIRA dustu. Yani
    `screens.js` icinde HIC dongu yok; tarayicim DUZYAZIYI KOD SANIYORDU ve
    bu proje bir tur boyunca yanlis bir mimari teshisle yasadi.

    🆕 SINIF: "KAYNAK KODU DUZ METIN OLARAK TARAYAN BIR OLCUM, O DOSYADAKI
    YORUMLARI DA OLCER — VE IYI YORUMLANMIS BIR DOSYA EN KOTU SONUCU VERIR."

    Ikinci ders daha aci: yorumlar ne kadar zenginse hata o kadar buyuyordu.
    Bu depoda yorumlar cok zengin oldugu icin teshis de o kadar yanlisti.
    """
    out = []
    i, n, mode = 0, len(s), None
    while i < n:
        c = s[i]
        if mode is None:
            if c == "/" and i + 1 < n and s[i + 1] == "/":
                mode = "line"; out.append(" "); i += 1
            elif c == "/" and i + 1 < n and s[i + 1] == "*":
                mode = "block"; out.append(" "); i += 1
            elif c in ("\"", "'", "`"):
                mode = c; out.append(" ")
            else:
                out.append(c)
        else:
            if mode == "line" and c == "\n":
                mode = None; out.append("\n")
            elif mode == "block" and c == "*" and i + 1 < n and s[i + 1] == "/":
                mode = None; out.append(" "); i += 1
            elif mode in ("\"", "'", "`") and c == mode and s[i - 1] != "\\":
                mode = None; out.append(" ")
            else:
                out.append("\n" if c == "\n" else " ")
        i += 1
    return "".join(out)


def cekirdek_olc():
    """screens.js icindeki dongusel cekirdegin buyuklugu."""
    p = SRC / "screens.js"
    if not p.exists():
        return None
    ham = p.read_text(encoding="utf-8", errors="ignore").split("\n")
    # 🔴 BILDIRIMLER ham metinden, GOVDE TARAMASI temizlenmis metinden okunur.
    # Bildirim satirlari zaten yorum degildir; govde ise yorumdan arindirilmali
    # (bkz. `kod_govdesi` — bu ayrimin neden bir turun mimari kararini
    # bozdugu orada yaziyor).
    lines = kod_govdesi("\n".join(ham)).split("\n")
    dec = []
    for i, l in enumerate(ham):
        m = re.match(r'^(export\s+)?(async\s+)?function\s+([A-Za-z_$][\w$]*)', l)
        if m:
            dec.append([i, m.group(3)])
            continue
        m = re.match(r'^(export\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=', l)
        if m:
            dec.append([i, m.group(2)])
    if not dec:
        return None
    for k in range(len(dec)):
        dec[k].append(dec[k + 1][0] if k + 1 < len(dec) else len(lines))
    adlar = {d[1] for d in dec}
    out = collections.defaultdict(set)
    for bas, ad, son in dec:
        for n in set(re.findall(r'\b([A-Za-z_$][\w$]*)\b', "\n".join(lines[bas:son]))):
            if n in adlar and n != ad:
                out[ad].add(n)
    kalan = set(adlar)
    while True:
        bu = {n for n in kalan if out[n] <= (adlar - kalan)}
        if not bu:
            break
        kalan -= bu
    return len(kalan), len(adlar), len(lines)


def main() -> int:
    print("=" * 72)
    print("BAGIMLILIK DENETIMI — dosyalar arasi dongu ve dongusel cekirdek")
    print("=" * 72)

    mods = moduller()
    if not mods:
        print("✗ src/ okunamadi — denetim KOSMADI (sessiz gecmiyor).")
        return 2

    g = {ad: baglar(k, ad) for ad, (p, k) in mods.items()}
    # yalniz var olan modullere bakan kenarlar
    g = {a: {b for b in bs if b in mods} for a, bs in g.items()}

    donguler = donguleri_bul(g)
    print(f"  modul            : {len(mods)}")
    print(f"  yerel bag        : {sum(len(v) for v in g.values())}")

    hata = 0
    if donguler:
        print()
        print(f"  ✗ {len(donguler)} IMPORT DONGUSU:")
        for d in donguler[:8]:
            print("      " + " → ".join(d))
        print()
        print("  Metro donguyu tolere eder AMA modul yukleme sirasina gore")
        print("  `undefined` uretebilir — ureticide beyaz ekran, burada sessizlik.")
        print("  Dongudeki ortak parcayi ucuncu bir dosyaya cikar.")
        hata = 1
    else:
        print("  ✓ import dongusu yok (yukleme sirasi guvenli)")

    olcum = cekirdek_olc()
    if olcum is None:
        print("  ⚠ screens.js okunamadi — cekirdek OLCULMEDI.")
        return hata
    cek, top, satir = olcum
    print(f"  screens.js       : {satir} satir · {top} ust seviye bildirim")
    print(f"  dongusel cekirdek: {cek} bildirim  (tavan {CEKIRDEK_TAVANI})")

    if cek > CEKIRDEK_TAVANI:
        print()
        print(f"  ✗ CEKIRDEK BUYUDU: {cek} > {CEKIRDEK_TAVANI}")
        print("  Yeni bir ekran, birbirine bagli cekirdege bir bag daha ekledi.")
        print("  Once SORU: bu bag gercekten gerekli mi? Ekranlar birbirini")
        print("  cagirmak yerine ust katmandan (App.js) yonlendirilemez mi?")
        print("  Gerekliyse tavani GEREKCESIYLE yukselt — sessizce degil.")
        hata = 1
    elif cek < CEKIRDEK_TAVANI:
        print(f"  ✓ cekirdek KUCULDU ({cek}) — tavani {cek} yap ki geri kaymasin.")
    else:
        print("  ✓ cekirdek buyumedi")

    return hata


if __name__ == "__main__":
    sys.exit(main())
