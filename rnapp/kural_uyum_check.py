#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kural_uyum_check.py — VİTRİN, MOTORUN SÖYLEDİĞİNİ Mİ SÖYLÜYOR?

════════════════════════════════════════════════════════════════════════
🔴 NEDEN VAR
════════════════════════════════════════════════════════════════════════
Gökberk rakibin sitesindeki şu cümleyi sordu:

    "Priority Pass, DragonPass & LoungeKey. No airline restrictions.
     If you're in the same terminal, you're a match."

Ölçtüm. Kendi kural tablomuz:

    PRIORITY_PASS   guest_flight_coupling = any          ✓
    LOUNGEKEY       guest_flight_coupling = any          ✓
    DRAGONPASS      guest_flight_coupling = same_flight  ✗

Yani o cümle DragonPass için yanlış (DragonPass md.7.15.7: misafir
üyeyle AYNI UÇUŞTA olmalı). Üç programı tek kutuda birleştirmek,
ikisinin doğrusunu üçüncünün yanlışıyla ödüyor — ve bedeli kapıda
geri çevrilen bir misafir.

VE BİZ DE AYNI HATAYI YAPMIŞIZ: `website/lib/content.js`teki v0.17
notu duruyor — eski metin "Priority Pass · DragonPass — Havayolu şartı
yok" idi. Düzeltilmiş, ama düzeltmeyi KORUYAN hiçbir şey yoktu. Yarın
biri site metnini elle değiştirse, motorla çeliştiğini kimse görmezdi.

🆕 SINIF: "VİTRİNDEKİ HER KURAL CÜMLESİ BİR İDDİADIR — İDDİAYI
MOTORUN CEVABIYLA KARŞILAŞTIRAN BİR DENETİM YOKSA, PAZARLAMA ER YA DA
GEÇ ÜRÜNÜ YALANLAR."

════════════════════════════════════════════════════════════════════════
NASIL ÇALIŞIR
Her vitrin cümlesi `kural_iddialari.json`da kayıtlı: hangi program,
hangi kural iddiası, ve cümlenin ayırt edici parçası. Denetim üçünü
birden kontrol eder:

  1 · İDDİA MOTORLA UYUŞUYOR MU  — `kural_programlari.txt` (motorun
      tablosundan alınan anlık görüntü) ile karşılaştırılır
  2 · CÜMLE HÂLÂ ORADA MI        — metin değiştiyse iddia da
      güncellenmeli; sessizce kaymasın
  3 · KAYITSIZ İDDİA VAR MI      — vitrinde bir program adı geçip de
      kayıtta yoksa uyarır (kapsam boşluğu)

NE ÖLÇMEZ: cümlenin DOĞRU YAZILDIĞINI ölçmez, İDDİANIN MOTORLA
UYUŞTUĞUNU ölçer. Motor yanlışsa denetim de yanlış "geçti" der —
motorun doğruluğu `rule_matrix_test()` ve 480 kural vakasının işi.

TAVAN 0.
"""
import json
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(os.path.dirname(KOK), "website")
IDDIA = os.path.join(KOK, "kural_iddialari.json")
PROGRAM = os.path.join(KOK, "kural_programlari.txt")
TAVAN = 0

# Vitrinde adı geçebilecek programlar → tablo kodu.
AD_KOD = {
    "Priority Pass": "PRIORITY_PASS",
    "DragonPass": "DRAGONPASS",
    "LoungeKey": "LOUNGEKEY",
    "Star Alliance": "STAR_GOLD",
    "Miles&Smiles": "TK_MS",
    "Business bileti": "BUSINESS_TICKET",
}


def programlar():
    if not os.path.exists(PROGRAM):
        return None
    d = {}
    for satir in open(PROGRAM, encoding="utf-8"):
        p = satir.strip().split("|")
        if len(p) >= 2:
            d[p[0]] = {"coupling": p[1], "guest": p[2] if len(p) > 2 else "?",
                       "kapsam": p[3] if len(p) > 3 else "?"}
    return d


def main():
    P = programlar()
    print("=" * 78)
    print("KURAL UYUM DENETİMİ — vitrin, motorun söylediğini mi söylüyor?")
    print("=" * 78)
    if not P:
        print("  ⚠ %s yok — motorun tablosu olmadan bu denetim ÖLÇEMEZ." %
              os.path.basename(PROGRAM))
        print("    `python pg_run.py --keep` sonra tabloyu dışa aktar.")
        print("    Ölçemediğini söylemek, ölçmüş gibi yapmaktan iyidir.")
        return 0
    if not os.path.exists(IDDIA):
        print("  🔴 kural_iddialari.json yok — vitrin iddiaları hiç kayıtlı değil.")
        return 1

    K = json.load(open(IDDIA, encoding="utf-8"))
    kotu = []
    kaynaklar = {}
    print("\n  1 · İDDİA ↔ MOTOR")
    for it in K["iddialar"]:
        kod = it["program"]
        m = P.get(kod)
        if not m:
            kotu.append("program %s motorun tablosunda yok" % kod)
            print("    ✗ %-14s motorda YOK" % kod)
            continue
        ok = m["coupling"] == it["iddia_coupling"]
        if not ok:
            kotu.append("%s: vitrin '%s' diyor, motor '%s'"
                        % (kod, it["iddia_coupling"], m["coupling"]))
        print("    %s %-14s vitrin %-13s motor %-13s %s"
              % ("✓" if ok else "✗", kod, it["iddia_coupling"], m["coupling"],
                 "" if ok else "← ÇELİŞKİ"))

    print("\n  2 · CÜMLE HÂLÂ ORADA MI")
    for it in K["iddialar"]:
        yol = os.path.join(os.path.dirname(KOK), it["yer"])
        if yol not in kaynaklar:
            kaynaklar[yol] = open(yol, encoding="utf-8").read() if os.path.exists(yol) else ""
        var = it["aranan"] in kaynaklar[yol]
        if not var:
            kotu.append("%s: kayıtlı cümle artık dosyada yok — metin değişti, "
                        "iddia güncellenmedi" % it["program"])
        print("    %s %-14s %s" % ("✓" if var else "✗", it["program"],
                                   it["aranan"][:56]))

    print("\n  3 · KAYITSIZ İDDİA (vitrinde geçen ama kayıtta olmayan program)")
    kayitli = {it["program"] for it in K["iddialar"]}
    acik = []
    for yol, g in kaynaklar.items():
        for ad, kod in AD_KOD.items():
            if ad in g and kod not in kayitli:
                acik.append((os.path.basename(yol), ad, kod))
    print("      kayıtlı iddia : %d · kayıtsız geçen program : %d"
          % (len(K["iddialar"]), len(acik)))
    for dosya, ad, kod in acik:
        print("      ⚠ %s içinde '%s' geçiyor ama iddiası kayıtlı değil (%s)"
              % (dosya, ad, kod))
        print("        Not: bu KIRMIZI değil — her geçiş bir kural iddiası olmayabilir.")

    print()
    if len(kotu) > TAVAN:
        print("🔴 %d ÇELİŞKİ. Vitrin, motorun söylemediği bir şeyi söylüyor." % len(kotu))
        for k in kotu:
            print("   · %s" % k)
        print("\n   Rakip bugün tam bu hatayı yapıyor: Priority Pass · DragonPass ·")
        print("   LoungeKey'i tek kutuda 'no airline restrictions' diye topluyor.")
        print("   DragonPass'te misafir AYNI UÇUŞTA olmak zorunda (md.7.15.7).")
        return 1
    print("✓ Vitrindeki her kural iddiası motorun tablosuyla birebir.")
    print("  ⚠️ Bu denetim cümlenin DOĞRU olduğunu değil, MOTORLA UYUŞTUĞUNU")
    print("     ölçer. Motorun doğruluğu 480 kural vakasının ve")
    print("     `rule_matrix_test()`in işi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
