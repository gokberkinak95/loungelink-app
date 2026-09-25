#!/usr/bin/env python3
# ============================================================
# LoungeLink · tasma_metrik.py
#
# NE YAPAR: assets/fonts altındaki GERÇEK ttf dosyalarından her
# karakterin ilerleme genişliğini (advance width) çıkarır ve
# render_check/font_metrik.json dosyasına yazar.
#
# NEDEN VAR: "taşma var mı?" sorusunun cevabı bir GÖRÜŞ değil bir
# SAYIDIR. Bir metnin kaç piksel yer istediğini bilmeden, o metnin
# kutusuna sığıp sığmadığını söyleyemem. Bugüne kadar taşmayı
# gözümle arıyordum; göz, 40 ekranda 900 etikete bakamaz.
#
# ⚠️ KERNING YOK SAYILIYOR. Kerning genişliği DARALTIR, yani buradaki
# ölçüm gerçeğin ÜST SINIRIDIR. Bir yanlış alarm mümkündür; kaçırılan
# bir taşma mümkün değildir. Bir kapının hangi yöne yanılacağını
# seçmek zorundaysan, güvenli yön budur.
# ============================================================
import json, os, sys
from fontTools.ttLib import TTFont

KOK = os.path.dirname(os.path.abspath(__file__))
FONT_DIZIN = os.path.join(KOK, "assets", "fonts")
CIKTI = os.path.join(KOK, "render_check", "font_metrik.json")

# Uygulamanın çizebileceği karakter kümesi: latin + Türkçe + noktalama +
# para/simge. Kümede olmayan bir karakter için `.notdef` genişliği
# kullanılır ve JS tarafı bunu ayrıca sayar.
KARAKTERLER = (
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "çÇğĞıİöÖşŞüÜâÂîÎûÛéÉèÈáÁñÑ"
    + "₺€$£%‰·•–—…‘’“”«»→←↑↓✓×°±≈≠"
    + "0123456789"
)


def cikar(yol):
    f = TTFont(yol, fontNumber=0, lazy=True)
    upem = f["head"].unitsPerEm
    cmap = f.getBestCmap()
    hmtx = f["hmtx"]
    tablo = {}
    eksik = []
    notdef = hmtx[".notdef"][0] if ".notdef" in hmtx.metrics else upem // 2
    for ch in KARAKTERLER:
        gname = cmap.get(ord(ch))
        if gname is None or gname not in hmtx.metrics:
            eksik.append(ch)
            continue
        tablo[ch] = hmtx[gname][0]
    f.close()
    return {"upem": upem, "adv": tablo, "notdef": notdef}, eksik


def main():
    if not os.path.isdir(FONT_DIZIN):
        print("HATA: font dizini yok:", FONT_DIZIN)
        return 1
    cikti = {}
    toplam_eksik = 0
    for ad in sorted(os.listdir(FONT_DIZIN)):
        if not ad.endswith(".ttf"):
            continue
        aile = ad[:-4]
        if aile == "Ionicons":
            continue  # ikon fontu; metin ölçülmez
        veri, eksik = cikar(os.path.join(FONT_DIZIN, ad))
        cikti[aile] = veri
        if eksik:
            toplam_eksik += len(eksik)
            print(f"  ⚠ {aile}: {len(eksik)} karakter yok → {''.join(eksik)}")
        else:
            print(f"  ✓ {aile}: {len(veri['adv'])} karakter (upem {veri['upem']})")

    os.makedirs(os.path.dirname(CIKTI), exist_ok=True)
    with open(CIKTI, "w", encoding="utf-8") as fh:
        json.dump(cikti, fh, ensure_ascii=False, separators=(",", ":"))
    kb = os.path.getsize(CIKTI) / 1024
    print(f"\n✓ {len(cikti)} aile · {CIKTI} ({kb:.0f} KB)")
    if toplam_eksik:
        print(f"⚠ toplam {toplam_eksik} eksik karakter — JS tarafı bunları")
        print("  .notdef genişliğiyle sayar (yani FAZLA sayar, az değil).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
