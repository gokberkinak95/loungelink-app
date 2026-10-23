# Kapanış A · "Kalem kanat": ikondaki kanat gün batımı göğünde kalem gibi uçar ve "loungelink"i tek akışta yazar.
import math, pathlib, re
from HersheyFonts import HersheyFonts

KOK = pathlib.Path(__file__).parent
W, H = 1080, 1920
h = HersheyFonts(); h.load_default_font("cursive"); h.normalize_rendering(100)
seg = list(h.lines_for_text("loungelink"))
# kontur listesi
kont = []; cur = []
for a, b in seg:
    if cur and cur[-1] == a: cur.append(b)
    else:
        if cur: kont.append(cur)
        cur = [a, b]
kont.append(cur)
xs = [p[0] for k in kont for p in k]; ys = [p[1] for k in kont for p in k]
gen = max(xs) - min(xs)
S = 800 / gen                 # 800 px genişlik
OX = (W - gen * S) / 2 - min(xs) * S
OY = 1010
EGIM = 0.12                   # hafif eğik yazı
def donus(p):
    x, y = p
    return (OX + x * S + EGIM * y * S, OY - y * S)

def catmull(pts, n=6):
    if len(pts) < 3: return pts
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n; t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(P[-2]); return out

konturlar = [catmull([donus(p) for p in k]) for k in kont]
# kalemin toplam yolu (kontur arası "kalem kalkar" geçişleri dahil değil: uzunluk yalnız çizgi)
def uz(k): return sum(math.dist(k[i], k[i + 1]) for i in range(len(k) - 1))
toplam = sum(uz(k) for k in konturlar)

def kesit(p):
    """p: 0..1 ilerleme → (çizilmiş konturlar d, kalem ucu, açı)"""
    hedef = p * toplam; d = []; uc = konturlar[0][0]; aci = 0
    for k in konturlar:
        L = uz(k)
        if hedef <= 0: break
        if hedef >= L:
            d.append(k); hedef -= L; uc = k[-1]; aci = math.degrees(math.atan2(k[-1][1] - k[-2][1], k[-1][0] - k[-2][0])); continue
        parca = [k[0]]; kal = hedef
        for i in range(len(k) - 1):
            s = math.dist(k[i], k[i + 1])
            if kal >= s: parca.append(k[i + 1]); kal -= s
            else:
                t = kal / s if s else 0
                q = (k[i][0] + (k[i + 1][0] - k[i][0]) * t, k[i][1] + (k[i + 1][1] - k[i][1]) * t)
                parca.append(q); uc = q; aci = math.degrees(math.atan2(k[i + 1][1] - k[i][1], k[i + 1][0] - k[i][0])); break
        d.append(parca); hedef = 0
    return d, uc, aci

KANAT = (KOK / "mark-kanat.svg").read_text(encoding="utf-8")
kanat_ic = re.search(r"<svg[^>]*>(.*)</svg>", KANAT, re.S).group(1)
kanat_ic = re.sub(r"<defs>.*?</defs>", "", kanat_ic, flags=re.S).replace("url(#kanatMetal)", "url(#kanatLac)")
# kanadın kuyruğu (76,129.6) kalem ucunda; burnu (137.9,117.7) gidiş yönünde → yerel açı −10.9°
def kanat(uc, aci, olcek=4.2):
    return (f'<g transform="translate({uc[0]:.1f},{uc[1]:.1f}) rotate({aci + 10.9:.1f}) scale({olcek}) translate(-76,-129.6)" '
            f'filter="url(#golge)">{kanat_ic.replace("kanatMetal", "km")}</g>')

def yol(d): return " ".join("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in k) for k in d if len(k) > 1)

def zemin():
    bulut = "".join(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#FFFFFF" opacity="{o}" filter="url(#bulanik)"/>'
                    for cx, cy, rx, ry, o in [(180, 1380, 380, 70, .55), (900, 1460, 420, 80, .5), (560, 1620, 600, 110, .65),
                                              (820, 520, 260, 40, .35), (230, 640, 220, 34, .3)])
    return (f'<rect width="{W}" height="{H}" fill="url(#gok)"/>'
            f'<circle cx="{W*0.72}" cy="1330" r="330" fill="url(#gunes)"/>{bulut}')

DEFS = '''<defs><style>@font-face{font-family:J;src:url(jakarta-semibold.woff2)}</style>
<linearGradient id="gok" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6E93C8"/><stop offset=".42" stop-color="#A9C0E0"/>
<stop offset=".7" stop-color="#F3D7BE"/><stop offset="1" stop-color="#FBEADB"/></linearGradient>
<radialGradient id="gunes"><stop offset="0" stop-color="#FFF4DE" stop-opacity=".95"/><stop offset=".35" stop-color="#FFE2B8" stop-opacity=".5"/><stop offset="1" stop-color="#FFE2B8" stop-opacity="0"/></radialGradient>
<linearGradient id="murekkep" x1="0" x2="1"><stop offset="0" stop-color="#1A2B4C"/><stop offset="1" stop-color="#2C4374"/></linearGradient>
<linearGradient id="kanatLac" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3A5486"/><stop offset=".55" stop-color="#1A2B4C"/><stop offset="1" stop-color="#C9A86E"/></linearGradient>
<filter id="bulanik" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="28"/></filter>
<filter id="golge" x="-50%" y="-80%" width="200%" height="260%"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#1A2B4C" flood-opacity=".35"/></filter>
<filter id="iz" x="-5%" y="-30%" width="110%" height="160%"><feDropShadow dx="0" dy="3" stdDeviation="3" flood-color="#1A2B4C" flood-opacity=".18"/></filter>
</defs>'''

def kare(p, alt, son=False):
    d, uc, aci = kesit(p)
    cizgi = f'<path d="{yol(d)}" fill="none" stroke="url(#murekkep)" stroke-width="11" stroke-linecap="round" stroke-linejoin="round" filter="url(#iz)"/>'
    # kalemin arkasında kısa, sönen bir buhar izi
    k = "" if son else kanat(uc, aci)
    if son:  # kanat imza gibi yazının sonundan yukarı süzülüp k'nın sağında durur
        sx, sy = konturlar[-1][-1]
        k = (f'<path d="M {sx:.0f} {sy:.0f} C {sx+25:.0f} {sy-20:.0f} {sx+10:.0f} {sy-110:.0f} {sx-70:.0f} {sy-150:.0f}" fill="none" stroke="#1A2B4C" stroke-width="5" stroke-linecap="round" stroke-dasharray="2 16" opacity=".55"/>'
             + kanat((sx - 70, sy - 150), -12, 2.5))
    yazi = ""
    if son:
        yazi = (f'<text x="{W/2}" y="1200" text-anchor="middle" font-family="J" font-size="40" fill="#1A2B4C">'
                f'Havalimanında üç saat, yalnız geçmek zorunda değil.</text>'
                f'<text x="{W/2}" y="1300" text-anchor="middle" font-family="J" font-size="30" fill="#41557E" letter-spacing="8">YAKINDA</text>'
                + "".join(f'<rect x="{x}" y="1340" width="250" height="74" rx="37" fill="#FFFFFF" fill-opacity=".55" stroke="#1A2B4C" stroke-opacity=".35" stroke-width="2"/>'
                          f'<text x="{x+125}" y="1388" text-anchor="middle" font-family="J" font-size="28" fill="#1A2B4C">{ad}</text>'
                          for x, ad in [(W/2-265, "App Store"), (W/2+15, "Google Play")]))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}{zemin()}{cizgi}{k}{yazi}'
            f'<text x="40" y="70" font-family="J" font-size="26" fill="#2C4374" opacity=".8">{alt}</text></svg>')

for ad, p, alt, son in [("1", 0.06, "A1 · kanat sahneye süzülüp kalem ucunu indiriyor", False),
                        ("2", 0.38, "A2 · 'loun' — kanat yazarken yazının eğimiyle yalpalıyor", False),
                        ("3", 0.62, "A3 · 'lounge' — her harf aynı elden, aynı mürekkeple", False),
                        ("4", 1.0, "A4 · imza tamam: kanat k'nın kuyruğundan havalanıp yanına konuyor", True)]:
    (KOK / f"kalem_{ad}.svg").write_text(kare(p, alt, son), encoding="utf-8")
print("ok", round(toplam))
