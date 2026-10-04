# -*- coding: utf-8 -*-
# rapor_uret.py — uçtan uca test + yük testi raporunu (HTML) üretir · 4 Ekim 2026
# Girdi: out/akis_e2e.json (akis_e2e.py) · ../render_check/out_perf/*.txt · out/akis_bulgular.md
import json, os, re, html, sys, collections
KOK = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(KOK, "out", "rapor.html")
E = json.load(open(os.path.join(KOK, "out", "akis_e2e.json"), encoding="utf-8"))
esc = html.escape

gecen = sum(1 for s in E if s["durum"] == "GECTI"); toplam = len(E)
bolumler = collections.OrderedDict()
for s in E:
    bolumler.setdefault(s["bolum"], []).append(s)

# bulgular tablosu (md → satırlar)
bul = []
for satir in open(os.path.join(KOK, "out", "akis_bulgular.md"), encoding="utf-8"):
    p = [x.strip() for x in satir.strip().strip("|").split("|")]
    if len(p) == 5 and re.match(r"^[BP]\d+$", p[0]):
        bul.append(p)

def onem_sinif(o):
    o = o.lower()
    return "kritik" if "kritik" in o else "yuksek" if "yüksek" in o else "orta" if "orta" in o else "dusuk"

def tur_etiket(t):
    return {"happy": "mutlu yol", "negative": "olumsuz", "edge": "uç durum", "alternate": "alternatif"}.get(t, t)

satirlar_e2e = []
for ad, liste in bolumler.items():
    g = sum(1 for s in liste if s["durum"] == "GECTI")
    satirlar_e2e.append('<details class="bolum"%s><summary><span class="bad">%s</span><span class="say %s">%d/%d</span></summary>'
                        '<div class="tablo"><table><thead><tr><th>Akış</th><th>Rol</th><th>Tür</th><th>Beklenen</th><th>Gerçekleşen (ölçüm)</th><th></th></tr></thead><tbody>'
                        % (" open" if g < len(liste) else "", esc(ad), "tam" if g == len(liste) else "eksik", g, len(liste)))
    for s in liste:
        satirlar_e2e.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td class='kanit'>%s</td><td class='d %s'>%s</td></tr>" % (
            esc(s["akis"]), esc(s["rol"]), esc(tur_etiket(s["tur"])), esc(str(s["beklenen"])), esc(str(s["gerceklesen"]))[:420],
            "ok" if s["durum"] == "GECTI" else "no", "✓" if s["durum"] == "GECTI" else "✗"))
    satirlar_e2e.append("</tbody></table></div></details>")

satirlar_bul = "".join(
    "<tr><td class='kod'>%s</td><td>%s</td><td>%s</td><td><span class='onem %s'>%s</span></td><td>%s</td></tr>" % (
        esc(b[0]), esc(b[1]), esc(b[2]), onem_sinif(b[3]), esc(b[3]), esc(b[4])) for b in bul)

tpl = open(os.path.join(KOK, "rapor_sablon.html"), encoding="utf-8").read()
cikti = (tpl.replace("{{GECEN}}", str(gecen)).replace("{{TOPLAM}}", str(toplam))
            .replace("{{BOLUM_SAYISI}}", str(len(bolumler)))
            .replace("{{BULGU_SAYISI}}", str(len(bul)))
            .replace("{{E2E}}", "\n".join(satirlar_e2e)).replace("{{BULGULAR}}", satirlar_bul))
open(OUT, "w", encoding="utf-8").write(cikti)
print("rapor:", OUT, "·", gecen, "/", toplam, "·", len(bul), "bulgu")
