#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hata_mesaji_check.py — SUNUCUNUN FIRLATTIĞI HER HATANIN TÜRKÇESİ VAR MI?

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK:
"Tüm akışlar uçtan uca doğru ve eksiksiz çalışmalı, her mesajı doğru
şekilde göstermeliyiz."

Bu nöbetçi o cümlenin SUNUCU tarafını ölçüyor. Uygulama bir RPC çağırır,
RPC `raise exception 'kod'` der, istemci `mapErr()` ile onu bir cümleye
çevirir. Karşılığı yoksa `mapErr` kullanıcıya şunu der:

    "Bir şeyler ters gitti. Lütfen tekrar dene."

Bu cümle YANLIŞ değil ama YARARSIZ: kullanıcı ne olduğunu bilmez ve
"tekrar dene" çoğu durumda işe yaramaz ("geçmiş tarih seçtin",
"kontenjanı doluluğun altına indiremezsin" gibi hatalarda tekrar denemek
aynı sonucu verir).

⚠️ ÖLÇERKEN BİR KEZ YANILDIM VE YAZIYORUM.
İlk taramada yalnız `e_*` anahtarlarına baktım ve "99 hata kodunun
karşılığı yok" diye okudum. Yanlıştı: asıl sözlük `errMap` bloğu ve
orada 162 anahtar var. Doğru sayı 135 ulaşılabilir koddan **4**'tü.
Yanlış ölçüm panik üretir; panik de gereksiz iş.
🆕 SINIF: "BİR EKSİK BULDUĞUNU SANDIĞINDA ÖNCE ARADIĞIN YERİN DOĞRU YER
OLDUĞUNU DOĞRULA — YANLIŞ SÖZLÜĞE BAKAN BİR ÖLÇÜM, OLMAYAN BİR FELAKET
ÜRETİR."

NE ÖLÇÜYOR
  1. Uygulamanın gerçekten çağırdığı RPC'ler (`supabase.rpc("x")`).
  2. O RPC'lerin gövdesinde `raise exception '<kod>'` ile fırlatılan
     kodlar — yani KULLANICININ ULAŞABİLECEĞİ hatalar. (Tüm SQL'deki
     227 kodu saymak yanıltıcı olurdu: çoğu yönetici yolunda.)
  3. Her kodun `errMap` ya da `e_*` içinde karşılığı var mı.

MUAF: test/geri-alma işaretleri. Bunlar SQL'in kendi kendini sınadığı
bloklarda bilerek fırlatılıyor ve bir işlemi geri almak için var;
kullanıcı yoluna hiç çıkmazlar.
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")
I18N = os.path.join(KOK, "src", "i18n.js")
TAVAN = 0

MUAF_DESEN = re.compile(r"^(GERI_AL|ROLLBACK|NOBETCI_GERI_AL|KASTEN_BOZULDU)", re.I)


def _yorumsuz(s):
    """🔴 YORUMLARI ÇIKARMADAN SAYMA. İlk yazımda çıkarmıyordum ve
    `// … Rakam değil, sebep: kullanıcı …` satırındaki "sebep:" bir
    errMap anahtarı sanıldı; tr/en eşitlik ölçümü olmayan bir fark
    gösterdi. Aynı hatayı `taklit_yuzey_check.py`de de bir kez yaptım —
    bir nöbetçinin yanlış alarmı, yokluğu kadar zararlıdır."""
    s = re.sub(r"/\*[\s\S]*?\*/", " ", s)
    s = re.sub(r"(?m)^\s*//.*$", " ", s)
    return s


def _errmap_blok(s, bas):
    i = s.index(bas)
    m = re.search(r"errMap:\s*\{", s[i:])
    st = i + m.end()
    d, j = 1, st
    while j < len(s):
        if s[j] == "{":
            d += 1
        elif s[j] == "}":
            d -= 1
            if d == 0:
                break
        j += 1
    return set(re.findall(r'(?:^|,|\{)\s*"?([a-zA-Z_]\w*)"?\s*:',
                          _yorumsuz(s[st:j]), re.M))


def sozluk():
    s = open(I18N, encoding="utf-8").read()
    tr = _yorumsuz(s[s.index("  tr: {"):s.index("  en: {")])
    errmap = _errmap_blok(s, "  tr: {")
    e_anahtar = set(re.findall(r"\be_([a-z0-9_]+)\s*:", tr))
    return errmap, e_anahtar


def cagrilan_rpcler():
    out = set()
    for p in [os.path.join(KOK, "App.js")] + sorted(glob.glob(os.path.join(KOK, "src", "*.js"))):
        s = open(p, encoding="utf-8").read()
        out |= set(re.findall(r'\.rpc\(\s*["\']([a-zA-Z0-9_]+)["\']', s))
    return out


def fonksiyon_govdeleri():
    """Aynı fonksiyon birden çok dosyada yeniden tanımlanmış olabilir;
    dosya adı sırası uygulanma sırasıdır, sonuncusu kazanır."""
    govde = {}
    for p in sorted(glob.glob(os.path.join(SQL, "*.sql"))):
        s = open(p, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r"(?is)create\s+or\s+replace\s+function\s+(?:public\.)?([a-z0-9_]+)\s*\(", s):
            bas = m.end()
            nxt = re.search(r"(?is)\ncreate\s+or\s+replace\s+function", s[bas:])
            govde[m.group(1)] = s[bas: bas + (nxt.start() if nxt else 20000)]
    return govde


def _maperr_davranisi():
    import subprocess, json as _j
    kaynak = open(I18N, encoding="utf-8").read()
    i = kaynak.find("export function mapErr(t, msg) {")
    if i < 0:
        return "mapErr bulunamadı"
    j = kaynak.find("\n}\n", i)
    govde = kaynak[i + len("export "):j + 2]
    js = ("const logError=()=>{};const console={warn(){}};" + govde +
          "const t={errMap:{bilinen:'B'},e_ozel_kod:'OZEL',errGeneric:'GENEL'};"
          "const r=[mapErr(t,'ozel_kod'),mapErr(t,'ERROR: ozel_kod'),mapErr(t,'bilinen'),mapErr(t,'hic_yok')];"
          "process.stdout.write(JSON.stringify(r));")
    try:
        p = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=20)
    except Exception as e:
        return "node koşmadı: %s" % e
    if p.returncode:
        return "node hatası: " + p.stderr.strip()[:120]
    r = _j.loads(p.stdout)
    return "ok" if r == ["OZEL", "OZEL", "B", "GENEL"] else "beklenmeyen sonuç %s" % r


def main():
    print("=" * 74)
    print("HATA MESAJI DENETİMİ — sunucunun dediğini kullanıcı anlıyor mu?")
    print("=" * 74)
    errmap, e_anahtar = sozluk()
    kapsam = errmap | e_anahtar
    rpcler = cagrilan_rpcler()
    govde = fonksiyon_govdeleri()

    ulasilabilir, eksik, muaf = set(), {}, set()
    bulunamayan = 0
    for r in sorted(rpcler):
        g = govde.get(r)
        if g is None:
            bulunamayan += 1
            continue
        for m in re.finditer(r"raise\s+exception\s+'([a-zA-Z0-9_]{3,40})'", g, re.I):
            k = m.group(1)
            if MUAF_DESEN.match(k):
                muaf.add(k)
                continue
            ulasilabilir.add(k)
            if k not in kapsam:
                eksik.setdefault(k, set()).add(r)

    print("  uygulamanın çağırdığı RPC        : %d" % len(rpcler))
    print("  SQL'de tanımı bulunamayan RPC    : %d" % bulunamayan)
    print("  errMap + e_* karşılığı           : %d" % len(kapsam))
    print("  kullanıcının ulaşabildiği kod    : %d" % len(ulasilabilir))
    print("  test/geri-alma işareti (muaf)    : %d" % len(muaf))
    print("  KARŞILIĞI OLMAYAN                : %d  (tavan %d)" % (len(eksik), TAVAN))
    for k in sorted(eksik):
        print("     ✗ %-30s ← %s" % (k, ", ".join(sorted(eksik[k]))[:60]))

    # ── TÜRKÇE/İNGİLİZCE EŞİTLİĞİ ─────────────────────────────────
    # Bir kodun yalnız tr karşılığı varsa, İngilizce arayüzdeki
    # kullanıcı yine "Something went wrong" görür. Sözlüğün yarısı
    # dolu olması, hatanın yarısının anlaşılması demek değil.
    tr_map = _errmap_blok(open(I18N, encoding="utf-8").read(), "  tr: {")
    en_map = _errmap_blok(open(I18N, encoding="utf-8").read(), "  en: {")
    tek_dil = sorted(tr_map - en_map)
    print("  errMap tr %d · en %d · yalnız tr'de: %d"
          % (len(tr_map), len(en_map), len(tek_dil)))
    for k in tek_dil:
        print("     ✗ %s — İngilizce karşılığı yok" % k)

    # ── mapErr GERÇEKTEN e_* OKUYOR MU? (23 Eylül) ─────────────────
    # Bu denetim bir kodu `errMap` YA DA `e_*` varsa "karşılandı" sayıyordu;
    # `mapErr` ise yalnız `errMap`e bakıyordu. Denetim yeşil, kullanıcı
    # "Bir şeyler ters gitti" görüyordu (22 kod). Artık sözlüğü değil
    # DAVRANIŞI ölçüyoruz: `mapErr`i çıkarıp node'da iki girdiyle çağırıyoruz.
    davranis = _maperr_davranisi()
    print("  mapErr e_* yolu (davranış)       : %s" % davranis)
    if davranis != "ok":
        print("\n🔴 `mapErr` e_* anahtarlarını okumuyor — sözlükteki cümleler ekrana ULAŞMAZ.")
        return 1

    if len(eksik) > TAVAN or tek_dil:
        print("\n🔴 Bu kodlar kullanıcıya 'Bir şeyler ters gitti' diye görünür.")
        print("   `src/i18n.js` → `errMap` içine NE OLDUĞUNU ve NE YAPACAĞINI")
        print("   söyleyen bir cümle yaz (tr ve en).")
        return 1
    print("\n✓ Kullanıcının ulaşabildiği her sunucu hatasının kendi cümlesi var.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
