# -*- coding: utf-8 -*-
"""
olcek_anahtar_check.py — ÖLÇEKTE OLMAYAN ANAHTAR SESSİZCE DÜŞÜYOR MU?

============================================================================
🔴 NEDEN VAR — 30 AĞUSTOS'TA ÖLÇÜLDÜ, TAHMİN DEĞİL

Gece sistemini uygularken kart aralıklarını `ARA[4]` diye yazdım. `ARA`
ölçeğinde 4 basamağı YOKTU. JavaScript bunu hata saymaz:

    ARA[4]                      → undefined
    { marginTop: undefined }    → özellik sessizce DÜŞER
    ekran                       → boşluk 0, uyarı yok, log yok

Saydım — ihlal eden 13 çağrı yeri vardı, 5 dosyada:

    ARA[3] ×1   ARA[4] ×9   ARA[8] ×1   ARA[12] ×1   (+1 yorumda)

Dokuzu benim son iki turda yazdıklarımdı. Yani tasarladığım boşlukların
dokuzu EKRANDA HİÇ OLUŞMAMIŞTI ve önizlemede de göremezdim, çünkü
"boşluk yok" ile "boşluk küçük" gözle ayırt edilmiyor.

theme.js'in kendi yorumu şunu iddia ediyordu:
    "`ARA[13]` yazmak derleme hatası değil ama `undefined` döner ve
     DENETİM YAKALAR"
Böyle bir denetim yoktu. İddia doğruydu, nöbetçi yazılmamıştı.

🆕 SINIF: **"KAPALI BİR KÜME YALNIZCA İHLALİ GÖRÜLÜR KILDIĞINDA KORUR.
SESSİZCE `undefined` DÖNEN BİR KÜME KORUMAZ — GİZLER. VE BİR YORUMDA
'DENETİM YAKALAR' YAZMAK, DENETİMİ YAZMAK DEĞİLDİR."**

NE ÖLÇÜYOR: kodda geçen her ölçek erişimi (`ARA[n]`, `SP[n]`, `R.x`,
`FS.x`, `MONO[n]`, `T.x`) gerçekten tanımlı mı. Tanımsız tek anahtar →
kırmızı.

⚠️ NEDEN AYRI BİR DENETİM: `token_check.py` ORANI ölçer (sistem ne kadar
bağlı). Bu betik DOĞRULUĞU ölçer (bağlanan şey var mı). Bir çağrı token
oranını yükseltirken aynı anda hiçbir şey yapmıyor olabilir — ikisi
farklı soru.
============================================================================
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")

# ── Ölçeğin KENDİSİNİ ayrıştır ───────────────────────────────────────
# Sabit liste yazmıyorum: ölçek büyüdüğünde denetimin de büyümesi gerek,
# ve elle güncellenen bir liste ilk unutulduğunda yalan söylemeye başlar.
def _blok(metin, ad):
    m = re.search(r"export const " + ad + r"\s*=\s*\{", metin)
    if not m:
        return None
    i = m.end() - 1
    derinlik = 0
    for j in range(i, len(metin)):
        if metin[j] == "{":
            derinlik += 1
        elif metin[j] == "}":
            derinlik -= 1
            if derinlik == 0:
                return metin[i:j + 1]
    return None


def anahtarlar(metin, ad):
    b = _blok(metin, ad)
    if b is None:
        return None
    # yorumları at — yorum içindeki `ARA[13]` bir tanım değil
    b = re.sub(r"/\*.*?\*/", " ", b, flags=re.S)
    b = re.sub(r"//[^\n]*", " ", b)
    return set(re.findall(r"(?:^|[{,])\s*(?:\"|')?([A-Za-z_$][\w$]*|\d+)(?:\"|')?\s*:", b))


def oku(yol):
    with open(yol, encoding="utf-8") as f:
        return f.read()


tema = oku(os.path.join(SRC, "theme.js"))
tipo = oku(os.path.join(SRC, "typography.js"))

OLCEK = {}
for ad, kaynak in (("ARA", tema), ("SP", tema), ("R", tema), ("FS", tema),
                   ("T", tema), ("MONO", tipo), ("SANS", tipo)):
    k = anahtarlar(kaynak, ad)
    if k is None:
        print("✗ ölçek bulunamadı: " + ad)
        sys.exit(1)
    OLCEK[ad] = k

# `F` bir nesne ama değerleri font ADI; anahtarları da aynı yolla gelir.
f_anahtar = anahtarlar(tema, "F")
if f_anahtar:
    OLCEK["F"] = f_anahtar

# ── Kodu tara ────────────────────────────────────────────────────────
KOSE = re.compile(r"\b(ARA|SP|MONO|SANS)\s*\[\s*(\d+)\s*\]")
NOKTA = re.compile(r"\b(R|FS|T|F)\.([A-Za-z_$][\w$]*)")

# `R.full` gibi tanımlı olanlar geçer; `C` renk kümesi zaten yuzey/token
# denetimlerinde ölçülüyor, burada tekrar etmiyorum.
ATLA_DOSYA = {"theme.js", "typography.js"}

hedefler = []
for kok, _dizin, dosyalar in os.walk(SRC):
    for d in sorted(dosyalar):
        if d.endswith(".js") and d not in ATLA_DOSYA:
            hedefler.append(os.path.join(kok, d))
for d in ("App.js", "index.js"):
    y = os.path.join(KOK, d)
    if os.path.exists(y):
        hedefler.append(y)

bulgu = []
for yol in hedefler:
    metin = oku(yol)
    # yorumları çıkar — yorumdaki örnek kod bir çağrı değil
    temiz = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), metin, flags=re.S)
    temiz = re.sub(r"//[^\n]*", "", temiz)
    for satir_no, satir in enumerate(temiz.split("\n"), 1):
        for ad, k in KOSE.findall(satir):
            if k not in OLCEK.get(ad, set()):
                bulgu.append((yol, satir_no, ad + "[" + k + "]"))
        for ad, k in NOKTA.findall(satir):
            if ad in OLCEK and k not in OLCEK[ad]:
                bulgu.append((yol, satir_no, ad + "." + k))

if bulgu:
    print("✗ " + str(len(bulgu)) + " ölçek erişimi TANIMSIZ — `undefined` dönüyor,")
    print("  stil özelliği sessizce düşüyor (hata verilmez, ekranda boşluk 0):")
    for yol, n, ifade in bulgu:
        print("    " + os.path.relpath(yol, KOK) + ":" + str(n) + "  " + ifade)
    print("")
    print("  Çözüm: ya ölçeğe basamağı ekle (tasarım gerçekten istiyorsa),")
    print("  ya çağrıyı ölçekteki en yakın basamağa taşı. Uydurma değer yazma.")
    sys.exit(1)

toplam = sum(len(v) for v in OLCEK.values())
print("✓ Ölçek anahtarları temiz — " + str(len(hedefler)) + " dosya, "
      + str(toplam) + " tanımlı basamak, tanımsız erişim yok.")
