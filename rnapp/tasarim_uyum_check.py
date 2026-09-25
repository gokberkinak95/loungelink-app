# -*- coding: utf-8 -*-
"""
tasarim_uyum_check.py — GECE SİSTEMİ UÇTAN UCA UYGULANDI MI?

============================================================================
🔴 NEDEN VAR

Gökberk sordu: "Uçtan uca tamam mıyız? Tüm gösterimler, arayüzler, UX UI her
şey bu tasarıma uyumlu mu?"

Bu soruya "evet" diye cevap vermek kolay ve ölçmeden verilen her "evet"
yanlış. Üstelik iki turdur tam bu hatayı yaptım: kartı uyguladım "oldu"
dedim, kabuk eskiydi; kabuğu uyguladım "oldu" dedim, iç ekranlar eskiydi.

🆕 SINIF: **"BİR TASARIMIN UYGULANIP UYGULANMADIĞI BİR KANI DEĞİL BİR
SAYIDIR. SAYIYI ÜRETMEDEN VERİLEN HER CEVAP, EN SON BAKTIĞIN EKRANIN
CEVABIDIR."**

NE ÖLÇÜYOR — beş kural, hepsi tasarım belgesinden:

  1 SERİF ROLÜ      `.ust-h1.serif` sistemde TEK yerde: ana sayfadaki İSİM.
                    Serif "insan"ın ailesi. Başka her yerde sans.
  2 METİN SEMBOLÜ   Tasarımda her işaret VEKTÖR. `✓ ✕ › ● ★` gibi bir
                    karakteri metin olarak çizmek, onu gövde fontunun
                    metriklerine teslim etmek demek (bkz. kırpılan `✕`).
  3 EMOJİ           Ürün arayüzünde emoji YOK. Emoji cihazdan cihaza
                    değişir; bir tasarım sisteminin en kontrolsüz parçası.
  4 SERT KÖŞE       Rozet/hap `R.full`, kart `R.lg/md`. Ham `borderRadius`
                    sayısı ölçek dışıdır.
  5 SERT RENK       `#rrggbb` doğrudan yazılmış her renk paletin dışında.

Her kural için TAVAN var (`tasarim_butce.json`). Tavan düşer, yükselmez.
============================================================================
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")
BUTCE_YOL = os.path.join(KOK, "tasarim_butce.json")

# theme/typography ölçeğin KENDİSİ; i18n metin taşır — sayıma girmez.
ATLA = {"theme.js", "typography.js", "i18n.js", "katalog.js", "legal.js"}

# Ürünün gerçekten çizdiği sembol karakterleri. Kutu çizimi (═ ─ │ ┌ └)
# yorum çerçevesidir, çizilen bir şey değil — listede yok.
SEMBOL = "✓✕✗★☆●○◈◆◇✦✧⇄→←↑↓⏳⏱⌛✈⬡ⓘℹ›‹»«▸▾▴■□"
EMOJI = re.compile(
    "[" "\U0001F300-\U0001FAFF" "☀-➿" "️" "⬀-⯿" "]")


def kod(s):
    """Yorumları ve i18n dizgilerini çıkar — yorumda geçen `✓` çizilmiyor."""
    s = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), s, flags=re.S)
    s = re.sub(r"//[^\n]*", "", s)
    return s


def dosyalar():
    out = []
    for kok, _d, fs in os.walk(SRC):
        for f in sorted(fs):
            if f.endswith(".js") and f not in ATLA:
                out.append(os.path.join(kok, f))
    for f in ("App.js",):
        p = os.path.join(KOK, f)
        if os.path.exists(p):
            out.append(p)
    return out


def olc(yol):
    with open(yol, encoding="utf-8") as f:
        ham = f.read()
    s = kod(ham)
    d = {}

    # 1 · SERİF — `serifLight` (isim/an başlığı) SAYILMAZ; o tasarımın
    #     kendi kararı. Sayılan yalnız `F.serif`.
    # ══════════════════════════════════════════════════════════════
    # 🔴 30 AĞUSTOS · 6. TUR — AVATAR HARFİ SAYILMAMALI.
    #
    # Bu sayaç `F.serif`in her geçtiği yeri "borç" sayıyordu. Ama
    # tasarımda serifin ÜÇ meşru yeri var ve biri AVATAR HARFİ:
    #     .avatar{ font-family:"Cormorant Garamond"; font-weight:600 }
    # Keşfet kartındaki avatarı tasarıma uydurup serif yapınca sayaç
    # 9→10 çıktı ve "borç arttı" dedi — yani TASARIMA UYMAYI bir
    # gerileme olarak raporladı.
    #
    # 🆕 SINIF: "BİR BÜTÇE NÖBETÇİSİ MEŞRU KULLANIMI TANIMIYORSA,
    # DOĞRU İŞİ YAPMANIN BEDELİNİ KIRMIZIYLA ÖDETİR — VE BİR SÜRE
    # SONRA KİMSE DOĞRU İŞİ YAPMAZ."
    #
    # Muafiyet DAR: yalnız aynı satırda `charAt(0)` geçen kullanımlar,
    # yani gerçekten bir baş harf çizen yerler. "Serif kullanmak
    # istiyorum" diyen hiçbir satır bu muafiyete giremez.
    # ══════════════════════════════════════════════════════════════
    serif_satir = [ln for ln in s.split("\n")
                   if re.search(r"\bF\.serif\b(?!Light)", ln)]
    d["serif"] = sum(1 for ln in serif_satir if "charAt(0)" not in ln)

    # 2 · METİN SEMBOLÜ — JSX metin düğümü ya da dizgi içinde.
    d["sembol"] = len([m for m in re.finditer(
        r">[^<>{}]*([" + SEMBOL + r"])[^<>{}]*<", s)])
    d["sembol"] += len(re.findall(r'"[^"]*[' + SEMBOL + r'][^"]*"', s))

    # 3 · EMOJİ
    d["emoji"] = len(EMOJI.findall(s))

    # 4 · SERT KÖŞE — `borderRadius: 14` gibi ham sayı (R.* değil)
    d["kose"] = len(re.findall(r"borderRadius:\s*\d", s))

    # 5 · SERT RENK — doğrudan hex. `+ \"55\"` gibi alfa ekleri sayılmaz.
    d["renk"] = len(re.findall(r'"#[0-9A-Fa-f]{6}"', s))
    return d


def main():
    print("=" * 74)
    print("TASARIM UYUMU — GECE SİSTEMİ UÇTAN UCA UYGULANDI MI?")
    print("=" * 74)

    butce = {}
    if os.path.exists(BUTCE_YOL):
        with open(BUTCE_YOL, encoding="utf-8") as f:
            butce = json.load(f)

    simdi, artan = {}, []
    toplam = {"serif": 0, "sembol": 0, "emoji": 0, "kose": 0, "renk": 0}
    for y in dosyalar():
        # 🔴 14 EYLUL · WINDOWS: `relpath` `src\ui.js` uretiyor, taban
        # dosyasindaki anahtar ise `src/ui.js`. Ayni dosya iki farkli ad
        # tasiyinca `butce.get(ad)` bos donuyor ve HER dosya "0 → N borc
        # ARTTI" diye kirmizi yaniyordu. Gokberk'in makinesinde 13 sahte
        # bulgu; benim makinemde sifir.
        # 🆕 SINIF: "DOSYA YOLUNU ANAHTAR YAPIYORSAN ONU NORMALLESTIR —
        # AYRAC ISLETIM SISTEMINE GORE DEGISIR, ANAHTAR DEGISMEMELI."
        ad = os.path.relpath(y, KOK).replace(os.sep, "/")
        d = olc(y)
        if any(d.values()):
            simdi[ad] = d
        for k in toplam:
            toplam[k] += d[k]
        eski = butce.get(ad, {})
        for k, v in d.items():
            e = eski.get(k, 0)
            if v > e:
                artan.append((ad, k, e, v))

    baslik = {"serif": "serif (isim dışı)", "sembol": "metin sembolü",
              "emoji": "emoji", "kose": "ham köşe", "renk": "ham renk"}
    print("\n  TOPLAM")
    for k, v in toplam.items():
        t = sum(b.get(k, 0) for b in butce.values()) if butce else None
        işaret = "✓" if (t is None or v <= t) else "✗"
        print("    %s %-20s %4d %s" % (işaret, baslik[k], v,
                                       ("(tavan %d)" % t) if t is not None else "(taban kuruluyor)"))

    if simdi:
        print("\n  DOSYA DÖKÜMÜ (yalnız sıfır olmayanlar)")
        for ad in sorted(simdi, key=lambda a: -sum(simdi[a].values())):
            d = simdi[ad]
            print("    %-30s %s" % (ad, "  ".join(
                "%s=%d" % (k, v) for k, v in d.items() if v)))

    if "--kaydet" in sys.argv:
        with open(BUTCE_YOL, "w", encoding="utf-8") as f:
            json.dump(simdi, f, ensure_ascii=False, indent=2, sort_keys=True)
        print("\n  ↳ bütçe yazıldı: %s" % os.path.basename(BUTCE_YOL))
        return 0

    if artan:
        print("\n  ✗ TASARIM BORCU ARTMIŞ:")
        for ad, k, e, v in artan:
            print("      %-30s %-14s %d → %d" % (ad, baslik[k], e, v))
        print("\n  Yeni bir ekran yazarken sembolü `<Ikon>`e, rengi paletе,")
        print("  köşeyi `R.*`ye, serifi sans'a çevir. Tavan yükselmez.")
        return 1

    print("\n✓ Tasarım borcu artmadı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
