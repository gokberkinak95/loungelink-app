#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ham_kod_check.py — KULLANICI HİÇBİR DİLDE HAM KOD GÖRÜYOR MU?

🔴 NEDEN VAR — 23 EYLÜL
Gökberk SEED8 raporunda `fully_booked`, `contact_not_verified`,
`insufficient_credits` gibi kodları gördü ve sordu: "App'de kullanıcıya
bunları göstermiyoruz, değil mi? İngilizcede de alt çizgili mesaj
olmamalı." Rapor bir geliştirici tezgâhı; ama soru doğru — ve cevabı
ölçmeden "hayır" demek, tam da gösterdiğimiz hatayı saklamak olurdu.

Ölçünce üç yol buldum; hepsinde ham metin ekrana gidiyordu:
  · SOS başarısızsa `error.message` olduğu gibi (Güvenlik ekranı)
  · Ayarlar'da şifre/telefon değişimi hatası `flash(error.message)`
  · giriş ekranında tanınmayan hata `setErr(raw)`, host başvurusunda
    `setErr(m)`, e-posta bağlantısında Supabase'in `error_description`ı
Bu denetim o sınıfın tamamını kapıda tutar.

── NE ÖLÇÜYOR ──────────────────────────────────────────────────────────
 A. SUNUCUNUN HER KODU → mapErr (TR ve EN). Kodlar CANLI tanımlardan
    (`sql/ETKIN_TANIMLAR.sql`): her `raise exception '<kod>'` ve jsonb
    içindeki `'reason'|'gate'|'code' , '<kod>'` değerleri — yalnız
    uygulamanın çağırdığı RPC'lerin değil, onların çağırdığı iç
    fonksiyonların ve tetikleyicilerin de (rl_guard, hesap_kapisi…).
    Çıktıda alt çizgili sözcük VARSA → bulgu. Genel mesaja düşen kod
    sayısı ayrıca raporlanır (tavanlı).
 B. SÖZLÜĞÜN HER DEĞERİ (TR ve EN, iç içe diziler dahil): alt çizgili
    sözcük → bulgu. Kullanıcıya giden her cümle buradan geçiyor.
 C. KAYNAK: ham hata metnini ekrana yazan çağrı (`setX(error.message)`,
    `flash(e.message)`, `: raw)` …) mapErr'siz → bulgu.
 D. SAHNE: `web_sahne/out/*.json` — gerçek ağacın ekrana bastığı metin
    (54+ sahne): alt çizgili sözcük → bulgu.

TAVAN: A/B/C/D bulgu 0.
🆕 SINIF: "BİR HATA KODUNUN KULLANICIYA SIZMADIĞINI SÖYLEMEK İÇİN, KODUN
EKRANA GİDEBİLECEĞİ HER YOLU SAYMAK GEREKİR — ÇEVİRİ SÖZLÜĞÜNE BAKMAK
YETMEZ."
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
import ll_paths  # noqa: E402

SQL_DIR, _ = ll_paths.require_sql("ham_kod_check")
ETKIN = os.path.join(SQL_DIR, "ETKIN_TANIMLAR.sql")
I18N = os.path.join(KOK, "src", "i18n.js")
TAVAN_GENEL = 33   # genel mesaja düşen kod sayısı (23 Eylül ölçümü: 33, hepsi BO/yönetici ya da uygulamanın çağırmadığı RPC)

SNAKE = re.compile(r"\b[a-z][a-z0-9]*_[a-z0-9_]+\b")
# Sözlükte bilerek duran, kullanıcıya metin olarak GÖSTERİLMEYEN değerler
# (ör. analitik olay adları, iç anahtarlar). Boş başlıyor; eklenen her
# satır gerekçesiyle yazılmalı.
IZINLI_DEGER = {
    # [anahtar, etiket] çiftlerinin ANAHTAR yarısı — sunucuya giden değer,
    # ekranda çizilen ikinci eleman (etiket).
    "tr.genders[3][0]", "en.genders[3][0]",
    "tr.disputeReasons[1][0]", "en.disputeReasons[1][0]",
    # tanıtım kartının karar rozeti için politika KODU (KararCipi çevirir)
    "tr.onbKartlar[2].politika", "en.onbKartlar[2].politika",
}


def kodlar():
    s = open(ETKIN, encoding="utf-8", errors="ignore").read()
    k = set(re.findall(r"raise\s+exception\s+'([a-z][a-z0-9_]{2,60})'", s, re.I))
    k |= set(re.findall(r"'(?:reason|gate|code|kod)'\s*,\s*'([a-z][a-z0-9_]{2,60})'", s))
    # dinamik fırlatılanlar: `raise exception '%', (v_dec ->> 'block_code')` —
    # kod bir değişkende taşınıyor (party_too_big, scope_mismatch …)
    k |= set(re.findall(r"v_(?:block|kod|code|reason)\s*:=\s*(?:coalesce\(\s*v_\w+\s*,\s*)?'([a-z][a-z0-9_]{2,60})'", s))
    return sorted(x for x in k if not re.match(r"^(geri_al|rollback|nobetci|kasten|tezgah)", x, re.I))


def node_olc(kodlist):
    kaynak = open(I18N, encoding="utf-8").read()
    kaynak = kaynak.replace('import { logError } from "./supabase";', "const logError = () => {};")
    kaynak = kaynak.replace('import AsyncStorage from "@react-native-async-storage/async-storage";',
                            "const AsyncStorage = { getItem: async () => null, setItem: async () => {} };")
    kaynak = re.sub(r"^import .*?;\s*$", "", kaynak, flags=re.M)
    tmp = tempfile.mkdtemp()
    mod = os.path.join(tmp, "i18n.mjs")
    open(mod, "w", encoding="utf-8").write(kaynak)
    betik = os.path.join(tmp, "olc.mjs")
    open(betik, "w", encoding="utf-8").write(r"""
globalThis.console.warn = () => {};
const M = await import(process.argv[2]);
const kodlar = JSON.parse(process.argv[3]);
const out = { harita: {}, degerler: { tr: [], en: [] } };
for (const dil of ["tr", "en"]) {
  const t = M.D[dil];
  for (const k of kodlar) {
    out.harita[dil + ":" + k] = [M.mapErr(t, k), M.mapErr(t, "ERROR: " + k), M.mapErr(t, k + " (ayrinti)")];
  }
  out.harita[dil + ":__genel"] = M.mapErr(t, "zzz_hic_olmayan_kod");
  const gez = (v, yol) => {
    if (typeof v === "string") out.degerler[dil].push([yol, v]);
    else if (Array.isArray(v)) v.forEach((x, i) => gez(x, yol + "[" + i + "]"));
    else if (v && typeof v === "object") for (const [a, b] of Object.entries(v)) gez(b, yol + "." + a);
  };
  gez(t, dil);
}
process.stdout.write(JSON.stringify(out));
""")
    p = subprocess.run(["node", betik, "file://" + mod, json.dumps(kodlist)],
                       capture_output=True, text=True, timeout=60)
    if p.returncode:
        print("  ✗ i18n.js node'da yüklenemedi:\n" + p.stderr[:800])
        sys.exit(1)
    return json.loads(p.stdout)


# C · ham metni ekrana yazan çağrılar
HAM = [
    re.compile(r"\b(set[A-Z]\w*|flash|onError)\(\s*[\w?.]*\.message\s*\)"),
    re.compile(r"\b(set[A-Z]\w*|flash)\(\s*\{[^}]*\bmsg\s*:\s*[\w?.]*\.message\b"),
    re.compile(r"\bsetErr\(\s*(raw|m|msg)\s*\)"),
    re.compile(r"\?\s*t\[\w+\]\s*:\s*raw\)"),
    re.compile(r"\|\|\s*p\.error_description"),
    re.compile(r"message:\s*(error|e)\.message\b"),
]


def main():
    print("=" * 74)
    print("HAM KOD DENETİMİ — kullanıcı TR ya da EN'de alt çizgili kod görüyor mu?")
    print("=" * 74)
    bulgu = []

    ks = kodlar()
    o = node_olc(ks)
    genel = {d: o["harita"][d + ":__genel"] for d in ("tr", "en")}
    genele_dusen = {"tr": [], "en": []}
    for d in ("tr", "en"):
        for k in ks:
            for cikti in o["harita"][d + ":" + k]:
                if SNAKE.search(cikti or ""):
                    bulgu.append(("A", d, k, cikti[:80]))
            if o["harita"][d + ":" + k][0] == genel[d]:
                genele_dusen[d].append(k)
    print("  A · sunucu kodu (canlı tanımlar)   : %d  · TR/EN'de ham çıktı: %d"
          % (len(ks), sum(1 for b in bulgu if b[0] == "A")))
    print("      genel mesaja düşen (TR / EN)  : %d / %d  (tavan %d)"
          % (len(genele_dusen["tr"]), len(genele_dusen["en"]), TAVAN_GENEL))

    nB = 0
    for d in ("tr", "en"):
        for yol, v in o["degerler"][d]:
            if yol in IZINLI_DEGER:
                continue
            for h in SNAKE.findall(v):
                if "@" in v or "://" in v:
                    continue
                bulgu.append(("B", d, yol, h)); nB += 1
    print("  B · sözlük değeri (TR+EN)         : %d  · alt çizgili: %d"
          % (len(o["degerler"]["tr"]) + len(o["degerler"]["en"]), nB))

    nC = 0
    for p in [os.path.join(KOK, "App.js")] + sorted(glob.glob(os.path.join(KOK, "src", "*.js"))):
        for n, satir in enumerate(open(p, encoding="utf-8"), 1):
            if satir.strip().startswith("//") or "mapErr" in satir or "ham-kod: sözlük" in satir:
                continue
            if any(r.search(satir) for r in HAM):
                bulgu.append(("C", os.path.basename(p), n, satir.strip()[:90])); nC += 1
    print("  C · ham hata metni ekrana         : %d" % nC)

    nD, sahne = 0, 0
    for f in sorted(glob.glob(os.path.join(KOK, "web_sahne", "out", "*.json"))
                    + glob.glob(os.path.join(KOK, "web_sahne", "out_en", "*.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        sahne += 1
        metin = d.get("metin")
        s = metin if isinstance(metin, str) else json.dumps(metin, ensure_ascii=False)
        for h in set(SNAKE.findall(s)):
            bulgu.append(("D", os.path.relpath(f, os.path.join(KOK, "web_sahne")), 0, h)); nD += 1
    print("  D · sahne ekranı (gerçek ağaç)    : %d sahne · alt çizgili: %d" % (sahne, nD))

    # E · İngilizce ekranda TÜRKÇE BÜYÜK HARF ("GOOD EVENİNG", "CREDİTS").
    # `BUYUK()` etkin dili bilmiyorsa İngilizce metni tr-TR kuralıyla
    # büyütür. Ölçüt: tamamı büyük harf bir sözcüğün İÇİNDE (başında değil)
    # noktalı İ — Türkçe özel adlar ("İSTANBUL") başta İ taşır, yakalanmaz.
    nE, en_sahne = 0, 0
    for f in sorted(glob.glob(os.path.join(KOK, "web_sahne", "out_en", "*.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        en_sahne += 1
        metin = d.get("metin")
        s = metin if isinstance(metin, str) else json.dumps(metin, ensure_ascii=False)
        for w in set(re.findall(r"\b[A-ZÇĞİÖŞÜ]{2,}\b", s)):
            if "İ" in w[1:] and re.search(r"[A-Z]", w):
                bulgu.append(("E", os.path.basename(f), 0, w)); nE += 1
    print("  E · EN sahnede Türkçe büyük harf   : %d sahne · bulgu: %d" % (en_sahne, nE))

    # F · İngilizce ekranda TÜRKÇE SÖZLÜK CÜMLESİ. E yalnız büyük harfi
    # yakalar; "SEYAHAT AMACI" gibi Türkçe harf taşımayan bir metni
    # yakalamaz. Ölçüt: EN sahnedeki bir metin, TR sözlükte bir değere
    # birebir eşit ve o anahtarın EN karşılığı FARKLI → Türkçe sızmış.
    # (büyük harfli hâli de sayılır: BUYUK(t.x))
    tr_yol = dict((y[3:], v) for y, v in o["degerler"]["tr"])
    en_yol = dict((y[3:], v) for y, v in o["degerler"]["en"])
    en_kume = set(en_yol.values())
    tr_sizinti = {}
    for y, v in tr_yol.items():
        e = en_yol.get(y)
        if e is not None and e != v and len(v) >= 3 and v not in en_kume:
            tr_sizinti[v] = y
            tr_sizinti[v.upper()] = y
            tr_sizinti[v.replace("i", "İ").upper()] = y
    nF = 0
    for f in sorted(glob.glob(os.path.join(KOK, "web_sahne", "out_en", "*.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        metin = d.get("metin")
        for x in (metin if isinstance(metin, list) else [str(metin)]):
            x = str(x).strip()
            if x in tr_sizinti:
                bulgu.append(("F", os.path.basename(f), 0, "%s  (tr.%s)" % (x[:50], tr_sizinti[x]))); nF += 1
    print("  F · EN sahnede Türkçe sözlük metni : bulgu: %d" % nF)

    # G · KAYNAKTA ÇEVRİLMEYEN TÜRKÇE (JSX) — sahneye girmeyen ekranlar da.
    # H · `t.x || "Türkçe yedek"` ama `x` EN sözlükte YOK → İngilizcede
    #     Türkçe yedek görünür (carrierPick, searchCount … 23 Eylül'de 6 tane).
    en_anahtar = sorted(set(y[3:].split(".")[0].split("[")[0] for y, _ in o["degerler"]["en"]))
    p = subprocess.run(["node", os.path.join(KOK, "render_check", "jsx_turkce_tara.js"), json.dumps(en_anahtar)],
                       capture_output=True, text=True, timeout=120)
    if p.returncode:
        bulgu.append(("G", "jsx_turkce_tara.js", 0, "KOŞMADI: " + p.stderr[:200]))
        gh = {"G": [], "H": []}
    else:
        gh = json.loads(p.stdout)
    for x in gh["G"]:
        bulgu.append(("G", x[0], x[1], x[2]))
    for x in gh["H"]:
        bulgu.append(("H", x[0], x[1], x[2] + " EN sözlükte yok"))
    print("  G · kaynakta çevrilmeyen Türkçe    : %d" % len(gh["G"]))
    print("  H · EN'de olmayan anahtar + TR yedek: %d" % len(gh["H"]))
    if sahne == 0:
        bulgu.append(("D", "web_sahne/out", 0, "sahne çıktısı YOK — ölçülemedi"))

    print("")
    for b in bulgu[:40]:
        print("  ✗ %s · %s · %s · %s" % b)
    if len(bulgu) > 40:
        print("  … ve %d tane daha" % (len(bulgu) - 40))
    asim = max(len(genele_dusen["tr"]), len(genele_dusen["en"])) > TAVAN_GENEL
    if "--genel" in sys.argv:
        print("  genel mesaja düşenler: " + ", ".join(genele_dusen["tr"]))
    if asim:
        print("  ✗ genel mesaja düşen kod tavanı aştı: " + ", ".join(genele_dusen["tr"][:20]))
    if not bulgu and not asim:
        print("  ✓ hiçbir yolda ham kod yok (TR · EN · sözlük · kaynak · sahne)")
    print("")
    print("SONUC  bulgu=%d  tavan=0" % (len(bulgu) + (1 if asim else 0)))
    return 1 if (bulgu or asim) else 0


if __name__ == "__main__":
    sys.exit(main())
