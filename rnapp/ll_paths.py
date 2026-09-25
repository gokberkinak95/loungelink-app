#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · ll_paths.py   (v1.94)

DENETİM BETİKLERİNİN YOL ÇÖZÜMLEMESİ — TEK KAYNAK.

🔴 NEDEN VAR (gerçek bir sessiz arıza):
Dört Python denetimi de yolları SABİT yazıyordu:
    SQL_DIR = '/mnt/user-data/outputs'
    BO_DIR  = '/home/claude/backoffice'
    APP_DIR = '/home/claude/rnapp'
Bunlar yalnızca Claude'un çalıştığı Linux kabında var. Gokberk'in
makinesinde proje C:\\rnapp ve C:\\backoffice altında — yani bu yolların
HİÇBİRİ mevcut değil.

Sonuç, hatadan daha kötüsüydü: betikler patlamıyor, **taranacak dosya
bulamayıp "temiz" diyordu.** `npm run verify` yeşil yanıyor ama aslında
sıfır satır denetlenmiş oluyordu. Yani en tehlikeli test türü: yanlış
güven veren test.

BU DOSYA İKİ ŞEY YAPAR:
  1. Yolları betiğin KENDİ konumundan türetir (taşınabilir).
  2. Taranacak bir şey bulunamazsa **GÜRÜLTÜLÜ ÖLÜR**. Bir denetim,
     bir şey denetleyemediğinde asla "temiz" dememelidir.

Ortam değişkeniyle ezilebilir: LL_SQL_DIR, LL_BO_DIR, LL_APP_DIR.
"""
import os
import sys
import glob

APP_DIR = os.path.dirname(os.path.abspath(__file__))          # .../rnapp
PARENT  = os.path.dirname(APP_DIR)                            # .../  (C:\ ya da /home/claude)


def _first_existing(cands):
    for c in cands:
        if c and os.path.isdir(c):
            return c
    return None


def app_dir():
    return os.environ.get("LL_APP_DIR") or APP_DIR


def bo_dir():
    """Backoffice: app'in kardeşi olması beklenir (C:\\rnapp ve C:\\backoffice)."""
    return os.environ.get("LL_BO_DIR") or _first_existing([
        os.path.join(PARENT, "backoffice"),
        os.path.join(PARENT, "loungelink-backoffice"),
        "/home/claude/backoffice",
    ])


def sql_dir():
    """SQL migration klasörü. Sıra: ortam değişkeni → proje içi → kardeş → kap."""
    return os.environ.get("LL_SQL_DIR") or _first_existing([
        os.path.join(APP_DIR, "sql"),
        os.path.join(PARENT, "sql"),
        os.path.join(PARENT, "loungelink_sql"),
        "/mnt/user-data/outputs",
    ])


def schema_file():
    """VERITABANI_SEMASI.md — şema anlık görüntüsü."""
    for c in [
        os.environ.get("LL_SCHEMA"),
        os.path.join(APP_DIR, "VERITABANI_SEMASI.md"),
        os.path.join(PARENT, "VERITABANI_SEMASI.md"),
        "/mnt/user-data/uploads/VERITABANI_SEMASI.md",
    ]:
        if c and os.path.isfile(c):
            return c
    return None


def require_sql(name):
    """SQL klasörü yoksa ya da boşsa denetimi GEÇERSİZ ilan et ve öl.

    Sessizce 'temiz' demek, hiç denetim yapmamaktan daha kötüdür: yanlış
    güven verir ve gerçek bir hata olduğunda kimse bakmaz."""
    d = sql_dir()
    # Uc haneli migrationlari da kapsar (bkz. v2.0 desen duzeltmesi)
    files = sorted(glob.glob(os.path.join(d, "[0-9]*.sql"))) if d else []
    if not files:
        print("=" * 72)
        print(f"✗ {name} ÇALIŞTIRILAMADI — SQL migration klasörü bulunamadı.")
        print("=" * 72)
        print(f"  Aranan yerler (sırayla):")
        print(f"    LL_SQL_DIR ortam değişkeni")
        print(f"    {os.path.join(APP_DIR, 'sql')}")
        print(f"    {os.path.join(PARENT, 'sql')}")
        print()
        print("  ÇÖZÜM: migration dosyalarını (001_*.sql … ) şuraya koy:")
        print(f"    {os.path.join(APP_DIR, 'sql')}")
        print("  ya da klasörün yolunu ver:")
        print("    PowerShell →  $env:LL_SQL_DIR = \"C:\\sql\"")
        print()
        print("  🔴 Bu denetim ATLANMADI, BAŞARISIZ oldu. Bir şey denetleyemeyen")
        print("     bir denetim asla 'temiz' dememelidir.")
        sys.exit(1)
    return d, files


def require_code(name, dirs):
    """Taranacak kaynak dosya yoksa öl (aynı gerekçe)."""
    found = []
    for d in dirs:
        if not d:
            continue
        for ext in ("js", "jsx"):
            found += [f for f in glob.glob(os.path.join(d, "**", f"*.{ext}"), recursive=True)
                      if "node_modules" not in f and os.sep + ".next" + os.sep not in f]
    if not found:
        print(f"✗ {name} ÇALIŞTIRILAMADI — taranacak kaynak dosya bulunamadı.")
        print(f"  Bakılan klasörler: {[d for d in dirs if d]}")
        print("  🔴 Yanlış yeşil vermemek için başarısız sayıldı.")
        sys.exit(1)
    return sorted(set(found))


def require_bo(name):
    """Backoffice klasörü yoksa öl.

    🔴 Bu ayrı bir guard, çünkü sessiz başarısızlığı en ince olan yer burası:
    app dosyaları bulunduğu için `require_code` geçiyor, denetim çalışıyor,
    yeşil yanıyor — ama BO'nun yarısı hiç taranmamış oluyor. Test ettiğini
    sandığın ama etmediğin durum, hiç test etmemekten tehlikelidir."""
    d = bo_dir()
    # Klasörün VAR OLMASI yetmez, İÇİNDE kod olmalı. Boş ya da yanlış bir
    # klasör de sessizce geçerdi — ilk denememde tam bu oldu.
    has_code = bool(d) and any(
        glob.glob(os.path.join(d, "**", "*." + e), recursive=True) for e in ("js", "jsx"))
    if not has_code:
        print(f"✗ {name} ÇALIŞTIRILAMADI — backoffice klasörü bulunamadı.")
        print(f"  Bakılan: {d or os.path.join(PARENT, 'backoffice')}")
        print("  (klasör var ama içinde .js/.jsx yoksa da başarısız sayılır)")
        print("  (app ile backoffice KARDEŞ klasör olmalı: C:\\rnapp ve C:\\backoffice)")
        print("  ya da:  $env:LL_BO_DIR = \"C:\\backoffice\"")
        print("  🔴 BO taranmadan verilen yeşil, yanlış yeşildir.")
        sys.exit(1)
    return d
