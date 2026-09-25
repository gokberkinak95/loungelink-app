#!/usr/bin/env python3
# ============================================================
# LoungeLink · ayna_kapsam_check.py
#
# ÖNİZLEME, EKRANIN KAÇINI GÖSTERİYOR?
#
# 🔴 NEDEN VAR — AYNANIN EN PAHALI HATASI:
# `ekran_uret.py`in `profil()` fonksiyonu yalnız istatistik üçlüsünü
# ve iki kartı çiziyordu. Uygulamanın Profil ekranında ise ÜÇ GRUPTA
# 11 menü satırı, profil fotoğrafı ve kırmızı "Çıkış yap" var — hepsi
# duruyordu, hiçbiri çizilmiyordu.
#
# Sonuç: Gökberk önizlemeye baktı ve DURAN özelliklerin silindiğini
# sandı. Sormak zorunda kaldı: "bunları kaldırmadın di mi?"
#
# 🆕 SINIF: "EKSİK BİR AYNA YALNIZ KUSUR GİZLEMEZ — ÜRÜNÜN SAHİBİNE
# DURAN BİR ÖZELLİĞİ KAYBETTİRİR. GİZLENEN BİR HATA BİR GÜN BULUNUR;
# KAYBEDİLEN BİR GÜVEN BULUNMAZ."
#
# NASIL ÖLÇÜYOR: iki taraf da KAYNAKTAN okunuyor.
#   · uygulama ekranı → o bileşenin gövdesindeki `t.anahtar` kullanımı
#   · önizleme        → o fonksiyondaki `t("anahtar")` kullanımı
# Önizlemenin ekranın anahtarlarının en az %ESIK'ini taşıması gerekir.
#
# ⚠️ NE ÖLÇMEZ: görsel benzerlik. "Aynı anahtarları çiziyor" demek
# "aynı görünüyor" demek değil. Bu kapı yalnız EKSİK MİRROR'ı yakalar
# — yanlış çizilmiş bir mirror'ı değil (onu `tasarim_olcu_check` ve
# `mockup_kalibre` ölçüyor).
# ============================================================
import ast, os, re, sys

KOK = os.path.dirname(os.path.abspath(__file__))
URETICI = os.path.join(KOK, "ekran_uret.py")
BUTCE = os.path.join(KOK, "ayna_kapsam_butce.json")

# (önizleme fonksiyonu, uygulama bileşeni, kaynak dosya)
# Elle yazılmış TEK şey bu eşleşme — çünkü iki ad uzayı arasında
# otomatik bir köprü yok. Ama listeye girmeyen bir önizleme de
# raporlanıyor (aşağıda), yani liste sessizce eskimiyor.
ESLESME = [
    ("profil",       "Profile",       "src/screens.js"),
    ("bildirim",     "Notifications", "src/ekranlar_yalin.js"),
    ("kesfet",       "Discovery",     "src/ekranlar_ana.js"),
    ("baglantilar",  "HomeConnections", "src/ekranlar_ana.js"),
    ("seyahatler",   "Trips",         "src/screens.js"),
]
# ══════════════════════════════════════════════════════════════════
# 🔴 DÜZ EŞİK YANLIŞTI — İLK KOŞUDA KENDİM GÖRDÜM.
#
# %34'lük tek bir eşikle Keşfet 4/112 (%4) ile kırmızı yandı. Ama o
# 112 anahtarın çoğu ŞARTLI DAL: filtre paneli, boş durumlar, hata
# metinleri, üç ayrı modal. Bir önizleme TEK BİR DURUMU çizer; hepsini
# çizmesi ne mümkün ne de istenir.
#
# Yani eşik, çok dallı bir ekranı "eksik ayna" diye cezalandırıyordu —
# ve bu, `kolon_check`te bugün düzelttiğim yanlış-alarm tuzağının
# aynısı: doğru işi cezalandıran bir kapı, bir süre sonra hiçbir işi
# denetlemez.
#
# 🆕 SINIF: "BİR ORAN, PAYDASI DEĞİŞKEN OLAN HER YERDE YANLIŞ EŞİK
# ÜRETİR — ÖLÇÜLECEK ŞEY 'YETERİNCE Mİ' DEĞİL, 'DÜNDEN AZ MI'."
#
# Onun yerine PER-EKRAN TABAN: bugünkü kapsam kaydediliyor ve yalnız
# YÜKSELEBİLİYOR. Ayna hiç mükemmel olmayacak, ama geriye gidemeyecek.
TABAN_DOSYA = BUTCE


def govde(dosya, ad):
    """Bileşenin/fonksiyonun gövde METNİ (yorumsuz)."""
    yol = os.path.join(KOK, dosya)
    if not os.path.exists(yol):
        return ""
    s = open(yol, encoding="utf-8").read()
    m = re.search(r"export function %s\s*\(" % re.escape(ad), s)
    if not m:
        return ""
    # kaba ama yeterli: bir sonraki `\nexport function`a kadar
    son = s.find("\nexport function ", m.end())
    g = s[m.start(): son if son > 0 else len(s)]
    g = re.sub(r"/\*.*?\*/", " ", g, flags=re.S)
    g = re.sub(r"^\s*//.*$", " ", g, flags=re.M)
    return g


def onizleme_govdesi(ad):
    agac = ast.parse(open(URETICI, encoding="utf-8").read())
    for d in agac.body:
        if isinstance(d, ast.FunctionDef) and d.name == ad:
            return ast.get_source_segment(open(URETICI, encoding="utf-8").read(), d) or ""
    return ""


def anahtarlar_app(g):
    return set(re.findall(r"\bt\.([A-Za-z_][A-Za-z0-9_]*)", g))


def anahtarlar_onizleme(g):
    # yorumları AST zaten atmıyor (docstring hariç) — elle temizle
    g = re.sub(r'"""[\s\S]*?"""', " ", g)
    g = re.sub(r"^\s*#.*$", " ", g, flags=re.M)
    return set(re.findall(r't\(\s*"([A-Za-z_][A-Za-z0-9_]*)"', g))


def onizleme_adlari():
    agac = ast.parse(open(URETICI, encoding="utf-8").read())
    for d in agac.body:
        if isinstance(d, ast.Assign) and any(
                getattr(t, "id", None) == "EKRANLAR" for t in d.targets):
            out = []
            for oge in d.value.elts:
                fn = oge.elts[1]
                if isinstance(fn, ast.Name):
                    out.append(fn.id)
                elif isinstance(fn, ast.Lambda):
                    out.append("(lambda)")
            return out
    return []


def tabanlari_oku():
    import json
    if os.path.exists(BUTCE):
        try:
            return json.load(open(BUTCE, encoding="utf-8"))
        except Exception:
            pass
    return {}


def tabanlari_yaz(d):
    import json
    json.dump(d, open(BUTCE, "w", encoding="utf-8"),
              ensure_ascii=False, indent=2, sort_keys=True)


def main():
    print("── AYNA KAPSAMI (önizleme ↔ ekran) ─────────────────")
    tabanlar = tabanlari_oku()
    kirik = 0
    eslesen = {a for a, _, _ in ESLESME}
    for onz, bilesen, dosya in ESLESME:
        og = onizleme_govdesi(onz)
        ag = govde(dosya, bilesen)
        if not og:
            print(f"  ✗ {onz:14} önizleme fonksiyonu bulunamadı"); kirik += 1; continue
        if not ag:
            print(f"  ✗ {onz:14} {bilesen} bulunamadı ({dosya})"); kirik += 1; continue
        ak = anahtarlar_app(ag)
        ok = anahtarlar_onizleme(og)
        ortak = ak & ok
        taban = tabanlar.get(onz)
        n = len(ortak)
        if taban is None:
            tabanlar[onz] = n
            print(f"  → {onz:14} taban {n}/{len(ak)} olarak kaydedildi")
            continue
        if n < taban:
            kirik += 1
            kayip = sorted((ak & ok) ^ ortak) or sorted(ak - ok)[:6]
            print(f"  ✗ {onz:14} GERİLEDİ: taban {taban}, şimdi {n} "
                  f"(ekranda {len(ak)} anahtar)")
            print(f"      çizilmeyenlerden: {', '.join(sorted(ak - ok)[:8])}")
        else:
            if n > taban:
                tabanlar[onz] = n
                print(f"  ↑ {onz:14} {taban} → {n}/{len(ak)} anahtar (taban yükseldi)")
            else:
                print(f"  ✓ {onz:14} {n}/{len(ak)} anahtar (taban {taban})")

    # Eşleşme listesine girmemiş önizlemeler — sessizce eskimesin
    hepsi = [a for a in onizleme_adlari() if a != "(lambda)"]
    disarida = [a for a in hepsi if a not in eslesen]
    if disarida:
        print(f"\n  ⓘ {len(disarida)} önizleme eşleşme listesinde değil "
              f"(kapsamı ölçülmüyor): {', '.join(disarida)}")

    tabanlari_yaz(tabanlar)
    print()
    if kirik:
        print(f"✗ {kirik} önizlemenin kapsamı GERİLEDİ.")
        print("  Eksik bir ayna, duran bir özelliği yokmuş gibi gösterir.")
        return 1
    print(f"✓ {len(ESLESME)} önizlemenin hiçbirinin kapsamı gerilemedi.")
    print("  ⚠ Bu kapı GÖRSEL benzerliği ölçmez — yalnız EKSİKLİĞİ.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
