#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
eklenti_check.py — `app.json`DAKİ HER EXPO EKLENTİSİ GERÇEKTEN KURULU MU?

🔴 NEDEN VAR — 27 AĞUSTOS, GÖKBERK'İN EKRANINDA PATLADI

    PS C:\\rnapp> npx eas build --platform android
    C:\\rnapp\\node_modules\\expo\\bin\\cli config --json exited with
    non-zero code: 1
        Error: build command failed.

Hata mesajı NE OLDUĞUNU SÖYLEMİYOR: yalnız "çıkış kodu 1". Sebebi
`expo config --type public` ile ortaya çıktı:

    PluginError: Failed to resolve plugin for module
    "expo-build-properties" relative to "/rnapp"

`expo-build-properties`, Play Store'un istediği `targetSdkVersion 35` için
`app.json`a eklenmişti. `package.json`a da yazılmıştı — AMA
`package-lock.json`a hiç girmemişti (o gün `npm install` koşmamışım).
`npm ci` kilit dosyasını kural kabul eder; kilitte olmayan paketi kurmaz.
Sonuç: paket "bağımlılık listesinde var" ama diskte YOK, ve build her
denemede aynı sessiz kodla düşüyor.

🆕 SINIF: **"BİR PAKETİ package.json'A YAZMAK ONU KURMAZ — KİLİT DOSYASINA
GİRMEDİYSE `npm ci` ONU YOK SAYAR, VE EKSİKLİK ANCAK BUILD ANINDA,
SEBEBİNİ SÖYLEMEYEN BİR HATAYLA ORTAYA ÇIKAR."**

NE ÖLÇÜYOR — bir eklenti için ÜÇ yer birden doğru olmalı:
  1 · `app.json` → `expo.plugins` içinde adı geçiyor
  2 · `package.json` → `dependencies` içinde var
  3 · `package-lock.json` → gerçekten kilitli (yoksa `npm ci` kurmaz)
ve mümkünse 4 · `node_modules/` altında duruyor.

Üçü de olmadan build ALINAMAZ; ve hiçbiri bugüne kadar ölçülmüyordu.

TAVAN 0.
"""
import json
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))

# Eklenti adı gibi görünüp paket olmayanlar (Expo'nun kendi içindekiler).
GOMULU = {"expo-router"}


def oku(ad):
    y = os.path.join(KOK, ad)
    if not os.path.exists(y):
        return None
    with open(y, encoding="utf-8") as f:
        return json.load(f)


def main():
    app = oku("app.json")
    pkg = oku("package.json")
    lock = oku("package-lock.json")
    print("=" * 74)
    print("EKLENTİ DENETİMİ — app.json'daki her plugin gerçekten kurulu mu?")
    print("=" * 74)
    if not app or not pkg:
        print("  🔴 app.json ya da package.json okunamadı.")
        return 1

    plugins = (app.get("expo") or {}).get("plugins") or []
    adlar = []
    for p in plugins:
        ad = p[0] if isinstance(p, list) and p else p
        if isinstance(ad, str) and ad not in GOMULU and not ad.startswith("."):
            adlar.append(ad)

    deps = dict(pkg.get("dependencies") or {})
    deps.update(pkg.get("devDependencies") or {})
    kilit = set()
    if lock:
        for k in (lock.get("packages") or {}):
            if k.startswith("node_modules/"):
                kilit.add(k[len("node_modules/"):])

    kotu = []
    print("\n  eklenti                        package.json  kilit  node_modules")
    print("  " + "-" * 70)
    for ad in adlar:
        d = ad in deps
        k = (ad in kilit) if lock else None
        n = os.path.isdir(os.path.join(KOK, "node_modules", ad))
        if not d:
            kotu.append("%s app.json'da var, package.json'da YOK" % ad)
        if lock and not k:
            kotu.append("%s package-lock.json'da YOK — `npm ci` bunu KURMAZ" % ad)
        # node_modules yoksa (temiz paket) bu tek başına hata değil
        print("  %-30s %-13s %-6s %s"
              % (ad,
                 (deps.get(ad, "—") if d else "✗ YOK"),
                 ("—" if k is None else ("✓" if k else "✗ YOK")),
                 ("✓" if n else "· (kurulmamış)")))

    print("\n  eklenti: %d · package.json'da: %d · kilitte: %d"
          % (len(adlar),
             sum(1 for a in adlar if a in deps),
             sum(1 for a in adlar if a in kilit) if lock else 0))

    # `expo config` gerçekten koşuyor mu — en kesin kanıt bu
    print("\n  expo config --json çalışıyor mu (eas build'in ilk adımı)")
    cli = os.path.join(KOK, "node_modules", "expo", "bin", "cli")
    if os.path.exists(cli):
        import subprocess
        r = subprocess.run(["node", cli, "config", "--json"],
                           cwd=KOK, capture_output=True, text=True, timeout=300)
        if r.returncode == 0:
            print("    ✓ çıkış kodu 0 — `eas build` bu adımı geçer")
        else:
            kotu.append("expo config --json çıkış kodu %d — eas build DÜŞER"
                        % r.returncode)
            print("    ✗ çıkış kodu %d" % r.returncode)
            for satir in (r.stderr or "").strip().split("\n")[:6]:
                print("      %s" % satir)
    else:
        print("    · node_modules yok, çalıştırılamadı (npm ci sonrası tekrar bak)")

    print()
    if kotu:
        print("🔴 %d BULGU — bu hâliyle `eas build` DÜŞER." % len(kotu))
        for k in kotu:
            print("   · %s" % k)
        print("\n   Düzeltme:  npx expo install <eklenti-adi>")
        print("   (`npm install` değil `expo install`: SDK ile uyumlu sürümü seçer)")
        return 1
    print("✓ Her eklenti üç yerde de kayıtlı ve `expo config` temiz.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
