#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · schema_check.py   (v1.85'te doğdu)

NEDEN VAR — GERÇEK BİR ÜRETİM HATASINDAN:
  src/screens.js şunu yazıyordu:
      .from("lounges").select("id, name, terminal, access_type")
  Şemada kolonun adı `access_types` (text[]). PostgREST bilinmeyen kolonda
  400 döner; supabase-js `data: null` verir; kod `setLounges(data || [])`
  dediği için liste SESSİZCE boş kalır. Sonuç: lounge listesi her
  havalimanında boştu, alan ekrandan kayboluyordu ve publish() lounge
  zorunlu kıldığı için HİÇBİR HOST İLAN YAYINLAYAMIYORDU.

  Var olan denetimlerin HİÇBİRİ bunu göremezdi:
    check.js        → JS/JSX sözdizimi ve import'lara bakar
    contract_check  → yalnız RPC ÇAĞRILARINI SQL imzalarıyla karşılaştırır
    flow/drift      → iş mantığı zincirine bakar
    render testleri → taklit veri kullanır, gerçek kolon adı bilmez
  Yani kod ile TABLO KOLONLARI arasında hiç sözleşme denetimi yoktu.
  Bu dosya o boşluğu kapatır.

NASIL: VERITABANI_SEMASI.md'den tablo→kolon haritasını çıkarır, sonra
app ve backoffice kaynağındaki .from(...).select/.eq/.order/... çağrılarını
tarar ve şemada olmayan kolonları raporlar.

BİLİNÇLİ SINIR: gömülü kaynak sözdizimi (`profiles(name)`, `a:b`) ve
`*` atlanır — amaç yanlış pozitif üretmemek. Yanlış pozitif, denetimi
görmezden gelmeyi öğretir (check.js'te bunu bir kez yaşadık).
"""
import os, re, sys, glob

SQL_ILE_BESLENDI = False

# v1.94 — taşınabilir yollar (ll_paths.py). Öncesi Linux'a gömülüydü.
import ll_paths
ll_paths.require_bo("schema_check")
CODE_DIRS = [os.path.join(ll_paths.app_dir(), "src"), ll_paths.app_dir(), ll_paths.bo_dir()]

# PostgREST'in kolon gibi görünen ama kolon OLMAYAN sözdizimi
SKIP_TOKENS = ("(", ")", ":", "!", "*", "->", "::")


def load_schema():
    path = ll_paths.schema_file()
    if not path:
        # 🔴 v1.94: eskiden sys.exit(0) ile ATLIYORDU — yani şema dosyası
        # olmayan bir makinede denetim sessizce "başarılı" sayılıyordu.
        # Denetleyemediğini "temiz" diye raporlamak, hiç denetlememekten
        # daha zararlıdır.
        print("✗ ŞEMA DENETİMİ ÇALIŞTIRILAMADI — VERITABANI_SEMASI.md bulunamadı.")
        print("  Dosyayı proje köküne koy (C:\\rnapp\\VERITABANI_SEMASI.md)")
        print("  ya da yolunu ver:  $env:LL_SCHEMA = \"C:\\yol\\VERITABANI_SEMASI.md\"")
        sys.exit(1)
    tables, cur = {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^###\s+([a-z_][a-z0-9_]*)", line.strip())
        if m:
            cur = m.group(1)
            tables.setdefault(cur, set())
            continue
        if cur:
            c = re.match(r"^\|\s*`([a-z_][a-z0-9_]*)`\s*\|", line.strip())
            if c:
                tables[cur].add(c.group(1))
    schema = {t: c for t, c in tables.items() if c}
    merge_pending_migrations(schema)
    return path, schema


def merge_pending_migrations(schema):
    """
    Şema dökümü bir ANLIK GÖRÜNTÜ; henüz çalıştırılmamış migration'ların
    eklediği kolonları bilmez. Onları da okumazsak, DOĞRU yazılmış yeni kod
    yanlış pozitif üretir — ve yanlış pozitif, denetimi görmezden gelmeyi
    öğretir (check.js'te bunu bir kez yaşadık).

    CREATE TABLE gövdesi regex ile ayrıştırılMAZ: gövdede `now()`,
    `references x(id)`, `check (a in ('b','c'))` gibi iç içe parantezler
    var ve non-greedy bir regex bunları yanlış yerde kesiyor (ilk denemede
    lounge_venue_acceptance tam da bu yüzden atlandı). Bunun yerine
    parantez derinliği sayan deterministik bir tarayıcı kullanılıyor.
    """
    sql_dirs = [d for d in [ll_paths.sql_dir()] if d]
    # 🔴 13 EYLUL · GOKBERK'IN MAKINESINDE 21 SORUN GORUNDU, BENDE 0.
    # Fark su: semanin YARISI `VERITABANI_SEMASI.md`den (28 Agustos, 49
    # tablo), digger yarisi `sql/` klasorundeki migration'lardan geliyor.
    # Onun makinesinde `sql/` yoktu; kapi 49 tabloyla olcup 21 kolonu
    # "YOK" ilan etti. Hicbiri gercek degildi — 101 tabloyla 0 bulgu.
    # Kapi kor oldugunu SOYLEMEDI, KENDINDEN EMIN BIR LISTE verdi.
    # 🆕 SINIF: "EKSIK KAYNAKLA OLCEN BIR KAPI, SESSIZ KALMAKTAN DAHA
    # TEHLIKELIDIR — YANLIS BULGU, OLMAYAN BIR HATAYI KOVALATIR."
    global SQL_ILE_BESLENDI
    SQL_ILE_BESLENDI = bool(sql_dirs) and any(
        glob.glob(os.path.join(d, "*.sql")) for d in sql_dirs)
    add_col = re.compile(
        r"alter\s+table\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)\s+"
        r"add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z_][a-z0-9_]*)", re.I)
    create_head = re.compile(
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z_][a-z0-9_]*)\s*\(", re.I)
    NOT_A_COLUMN = ("primary", "unique", "foreign", "check", "constraint",
                    "references", "exclude", "like")

    for d in sql_dirs:
        for f in sorted(glob.glob(os.path.join(d, "*.sql"))):
            try:
                src = open(f, encoding="utf-8", errors="replace").read()
            except OSError:
                continue

            for m in add_col.finditer(src):
                schema.setdefault(m.group(1), set()).add(m.group(2))

            for m in create_head.finditer(src):
                table = m.group(1)
                i, depth, body = m.end(), 1, []
                while i < len(src) and depth > 0:
                    ch = src[i]
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    body.append(ch)
                    i += 1
                cols = schema.setdefault(table, set())
                # Yalnız DEPTH 0'daki virgüller kolonları ayırır
                depth, cur, parts = 0, "", []
                for ch in "".join(body):
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                    if ch == "," and depth == 0:
                        parts.append(cur); cur = ""
                    else:
                        cur += ch
                parts.append(cur)
                for part in parts:
                    line = re.sub(r"--[^\n]*", " ", part).strip()
                    c = re.match(r"([a-z_][a-z0-9_]*)\s+[a-z\"]", line, re.I)
                    if c and c.group(1).lower() not in NOT_A_COLUMN:
                        cols.add(c.group(1))

def js_files():
    out = []
    for d in CODE_DIRS:
        for ext in ("js", "jsx"):
            out += [f for f in glob.glob(os.path.join(d, "**", f"*.{ext}"), recursive=True)
                    if "node_modules" not in f and "/.next/" not in f
                    and "/render_check/" not in f]
    return sorted(set(out))


def columns_in_select(arg):
    """select("id, name, profiles(name)") -> {'id','name'}  (gömülü olan atlanır)"""
    cols, depth, cur = set(), 0, ""
    for ch in arg:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            cols.add(cur.strip()); cur = ""
            continue
        if depth == 0:
            cur += ch
        # parantez içi (gömülü kaynak) tamamen yok sayılır
    cols.add(cur.strip())
    return {c for c in cols if c and not any(tok in c for tok in SKIP_TOKENS)}


def _zincir(src, i):
    """`.from(...)` sonrasındaki zinciri parantez sayarak çıkar."""
    d = 0
    for j in range(i, min(len(src), i + 4000)):
        c = src[j]
        if c in "([{":
            d += 1
        elif c in ")]}":
            if d == 0:
                return src[i:j]
            d -= 1
        elif c in ",;" and d == 0:
            return src[i:j]
    return src[i:i + 4000]


def main():
    path, schema = load_schema()
    problems, checked = [], 0

    # .from("tablo") ... zincirin devamı
    FROM = re.compile(r'\.from\(\s*["\']([a-z_][a-z0-9_]*)["\']\s*\)')
    SELECT = re.compile(r'\.select\(\s*["\']([^"\']*)["\']')
    FILTER = re.compile(r'\.(eq|neq|gt|gte|lt|lte|like|ilike|is|in|order|contains|overlaps)\(\s*["\']([a-z_][a-z0-9_.]*)["\']')

    for f in js_files():
        src = open(f, encoding="utf-8", errors="replace").read()
        for m in FROM.finditer(src):
            table = m.group(1)
            if table not in schema:
                continue  # şemada olmayan tablo: view olabilir, sessiz geç
            # ══════════════════════════════════════════════════════════
            # 🔴 v3.4 — ZİNCİR ARTIK PARANTEZ SAYILARAK KESİLİYOR.
            #
            # Eski hâli SABİT 500 KARAKTERLİK bir pencere alıp yalnız bir
            # sonraki `.from(` ile kesiyordu. Backoffice'te sorguları saran
            # bir yardımcı yazınca (`say(t, f) => sb.from(t)...`) o `.from(`
            # artık METİNDE görünmüyor ve YANLIŞ tabloya ait filtreler
            # penceredeki tabloya yazılıyordu:
            #     ✗ visits.is_staff YOK · visits.role YOK · visits.status YOK
            # Üçü de `requests`/`users` filtresiydi; `visits` sorgusunun
            # 500 karakter ardında duruyorlardı, o kadar.
            #
            # 🆕 SINIF: "BİR ZİNCİRİ KARAKTER SAYARAK KESERSEN, KOMŞU
            # İFADENİN PARÇALARINI O ZİNCİRE MAL EDERSİN — YAPIYI SAY,
            # UZUNLUĞU DEĞİL."
            #
            # Artık zincir, parantez derinliği 0'a düştüğü ilk `,` `;` `)`
            # ile bitiyor: yani sorgunun GERÇEK sonuyla.
            tail = _zincir(src, m.end())

            cand = set()
            s = SELECT.search(tail)
            if s:
                cand |= columns_in_select(s.group(1))
            for fm in FILTER.finditer(tail):
                raw = fm.group(2)
                # `requests.host_id` gibi NOKTALI filtreler GÖMÜLÜ kaynağı
                # hedefler (select içindeki requests!inner(...)), ana tablonun
                # kolonu değildir. Bunları denetlemek yanlış pozitif üretir.
                if "." in raw:
                    continue
                if not any(tok in raw for tok in SKIP_TOKENS):
                    cand.add(raw)

            for col in sorted(cand):
                checked += 1
                if col not in schema[table]:
                    line = src[: m.start()].count("\n") + 1
                    problems.append((os.path.relpath(f), line, table, col,
                                     sorted(schema[table])))

    print("=" * 72)
    print("ŞEMA DENETİMİ — kodun okuduğu her kolon, tabloda gerçekten var mı?")
    print("=" * 72)
    print(f"Şema kaynağı: {path}")
    print(f"Tablo: {len(schema)} · kontrol edilen kolon referansı: {checked}\n")

    if not SQL_ILE_BESLENDI:
        print("✗ ŞEMA DENETİMİ KÖR — `sql/` klasörü bulunamadı.")
        print("  Şemanın yarısı migration dosyalarından geliyor; onlarsız")
        print(f"  yalnız {len(schema)} tablo görünüyor (tam hâli 101).")
        print("  Bu hâlde bulunan her 'kolon YOK' YANLIŞ OLABİLİR — o yüzden")
        print("  liste hiç basılmıyor.")
        print("  ÇÖZÜM: migration dosyalarını şuraya koy:")
        print("    " + os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql")
              + "   ya da bir üst klasörde  sql\\")
        print("  ya da:  $env:LL_SQL_DIR = \"C:\\yol\\sql\"")
        return 1

    if not problems:
        print("✓ tüm kolon referansları şemayla uyumlu")
        return 0

    for rel, line, table, col, cols in problems:
        near = [c for c in cols if c.startswith(col[:4]) or col.startswith(c[:4])]
        print(f"✗ {rel}:{line}  {table}.{col} YOK")
        if near:
            print(f"    bunu mu demek istedin: {', '.join(near)}")
    print(f"\n✗ {len(problems)} sorunlu kolon referansı")
    print("  NOT: PostgREST bilinmeyen kolonda 400 döner; supabase-js data=null verir.")
    print("       `data || []` yazan her yerde bu hata SESSİZ bir boş listeye dönüşür.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
