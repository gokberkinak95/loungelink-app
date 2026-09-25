#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
katman_sira_check.py

============================================================================
KATMAN SIRA DENETİMİ — AÇILIŞ SIRASI DEFTERİ HER KATMANI DİNLİYOR MU?

🔴 NEDEN VAR — 19 EYLÜL

`App.js` açık katmanları (overlay) bir `OVERLAYS` sözlüğünde tutuyor ve
AÇILIŞ SIRASINI ayrı bir `openSeq` dizisinde biriktiriyor. Sıra bir
`useEffect` ile güncelleniyor:

    useEffect(() => { setOpenSeq(...) }, [showNotif, showPlans, compChat, ...]);

Bağımlılık listesinde BEŞ katmanın durumu eksikti: `showSohbetler`,
`showIstekler`, `showDavetler`, `showQuestions`, `firstRunAccess`.

Eksik olmasının sonucu "sıra biraz kayar" değil, ŞU:

  1. Kullanıcı Sohbetlerim'i açar → effect koşmaz → `openSeq` boş.
  2. Eksikler `Object.keys(OVERLAYS)` SIRASIYLA sona eklenir.
  3. "Sohbeti Aç" → `setCompChat(...)`. Effect ŞİMDİ koşar ve `openSeq`i
     anahtar sırasıyla kurar: `compChat` anahtarı `sohbetler`den ÖNCE
     geldiği için sohbet katmanı YIĞININ ALTINDA kalır.
  4. Ekran değişmez. Kullanıcı için bu "düğme çalışmıyor" demektir.

Yani hata görünmez bir yerde değil, TAM ORTADA duruyordu — ve hiçbir
kapı onu göremiyordu, çünkü kod sözdizimsel olarak kusursuz.
Yakalayan tek şey iki sahne görüntüsünün md5'inin eşit çıkması oldu.

🆕 SINIF: "BİR SIRA DEFTERİ, KAYDETTİĞİ OLAYLARIN HEPSİNİ DİNLEMİYORSA
SIRA DEĞİL ALFABE TUTAR — VE ALFABE, KULLANICININ AÇILIŞ SIRASIYLA
İLGİSİZDİR."

NE ÖLÇÜYOR
  `OVERLAYS = { ad: [<durum ifadesi>, ... ] }` içindeki her durum
  ifadesinin okuduğu state adının, `setOpenSeq` effect'inin bağımlılık
  listesinde geçip geçmediği.

NEYİ ÖLÇMÜYOR
  Sıranın doğruluğunu çalışma anında. Bu STATİK bir kapı: eksik
  bağımlılığı ucuz yoldan yakalar, sıranın mantığını değil.

TAVAN 0.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(KOK, "App.js")
TAVAN = 0


def main():
    if not os.path.exists(APP):
        print("✗ App.js bulunamadı.")
        sys.exit(1)
    g = open(APP, encoding="utf-8").read()

    # ── 1 · OVERLAYS sözlüğünü bul ────────────────────────────────────
    m = re.search(r"const\s+OVERLAYS\s*=\s*\{", g)
    if not m:
        print("✗ App.js içinde `const OVERLAYS = {` bulunamadı —")
        print("  katman kaydı taşınmış olabilir. Denetim körleşmesin diye")
        print("  bu bir HATA sayılıyor, sessiz geçiş değil.")
        sys.exit(1)

    i = g.index("{", m.start())
    derinlik, j = 0, i
    while j < len(g):
        if g[j] == "{":
            derinlik += 1
        elif g[j] == "}":
            derinlik -= 1
            if derinlik == 0:
                break
        j += 1
    govde = g[i + 1:j]

    # ── 2 · Her katmanın durum ifadesinden state adını çıkar ──────────
    # `notif: [showNotif, () => …]`  ·  `compChat: [!!compChat, …]`
    katmanlar = {}
    for mm in re.finditer(r"(\w+)\s*:\s*\[\s*([^,\]]+),", govde):
        ad, ifade = mm.group(1), mm.group(2).strip()
        adlar = set(re.findall(r"[A-Za-z_$][\w$]*", ifade))
        adlar -= {"true", "false", "null", "undefined", "Boolean"}
        if adlar:
            katmanlar[ad] = adlar

    if len(katmanlar) < 5:
        print("✗ OVERLAYS içinde yalnız %d katman çözülebildi — ayrıştırıcı"
              % len(katmanlar))
        print("  biçim değişikliğinden körleşmiş olabilir.")
        sys.exit(1)

    # ── 3 · setOpenSeq effect'inin bağımlılık listesini bul ───────────
    m2 = re.search(r"setOpenSeq\(", g)
    if not m2:
        print("✗ `setOpenSeq(` bulunamadı.")
        sys.exit(1)
    # Effect'i kapatan `}, [ ... ]);` — setOpenSeq'ten SONRAKİ ilki.
    m3 = re.search(r"\}\s*,\s*\[([^\]]*)\]\s*\)\s*;", g[m2.start():], re.S)
    if not m3:
        print("✗ setOpenSeq effect'inin bağımlılık listesi bulunamadı.")
        sys.exit(1)
    bagimli = set(re.findall(r"[A-Za-z_$][\w$]*", m3.group(1)))

    # ── 4 · Karşılaştır ───────────────────────────────────────────────
    eksik = []
    for ad, adlar in sorted(katmanlar.items()):
        if not (adlar & bagimli):
            eksik.append((ad, sorted(adlar)))

    print("=" * 74)
    print("KATMAN SIRASI — açılış defteri her katmanı dinliyor mu?")
    print("=" * 74)
    print("  OVERLAYS katmanı        : %d" % len(katmanlar))
    print("  effect bağımlılığı      : %d" % len(bagimli))
    print("")

    if eksik:
        print("  ✗ %d katmanın durumu bağımlılık listesinde YOK." % len(eksik))
        print("    Bu katmanlar açıldığında sıra defteri güncellenmez; yığın")
        print("    ANAHTAR ADI sırasına düşer ve yanlış katman üste gelir.")
        print("    Kullanıcı bunu 'düğme çalışmıyor' olarak yaşar:")
        for ad, adlar in eksik:
            print("        OVERLAYS.%-12s → %s" % (ad, ", ".join(adlar)))
        print("")
        print("  ÇÖZÜM: eksik state adlarını `setOpenSeq` effect'inin")
        print("  bağımlılık dizisine ekle.")
    else:
        print("  ✓ her katmanın durumu bağımlılık listesinde var")

    print("")
    print("SONUC  eksik=%d  tavan=%d" % (len(eksik), TAVAN))
    sys.exit(1 if len(eksik) > TAVAN else 0)


main()
