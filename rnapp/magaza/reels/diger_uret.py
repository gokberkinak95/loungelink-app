# Kapanış B (kalkış panosu) ve C (iki ışık buluşuyor) anahtar kareleri.
import pathlib, random, re
KOK = pathlib.Path(__file__).parent
W, H = 1080, 1920
kanat_ic = re.search(r"<svg[^>]*>(.*)</svg>", (KOK / "mark-kanat.svg").read_text(encoding="utf-8"), re.S).group(1)
kanat_ic = kanat_ic.replace("#F2E9D8", "#3A5486").replace("#D6C3A0", "#1A2B4C").replace("#A89372", "#C9A86E")
FONT = "<style>@font-face{font-family:J;src:url(jakarta-semibold.woff2)}@font-face{font-family:JR;src:url(jakarta-regular.woff2)}</style>"

# ---------------- B · kalkış panosu ----------------
HARF = "ABCDEFGHIJKLMNOPRSTUVYZÇĞİÖŞÜ0123456789"
def pano(satirlar, alt, isik=0.0):
    x0, y0, hw, hh, ara = 70, 640, 62, 92, 6
    g = []
    g.append(f'<rect x="40" y="560" width="{W-80}" height="{len(satirlar)*(hh+26)+150}" rx="22" fill="#16181D"/>')
    g.append(f'<text x="80" y="615" font-family="J" font-size="30" fill="#E7C98F" letter-spacing="6">GİDİŞ · DEPARTURES</text>')
    for r, (metin, renk, yarim) in enumerate(satirlar):
        y = y0 + r * (hh + 26)
        for c in range(14):
            x = x0 + c * (hw + ara)
            ch = metin[c] if c < len(metin) else " "
            g.append(f'<rect x="{x}" y="{y}" width="{hw}" height="{hh}" rx="7" fill="#24272E"/>'
                     f'<rect x="{x}" y="{y+hh/2-1}" width="{hw}" height="2" fill="#0E0F12"/>')
            if yarim and c in yarim:   # dönüş anı: üst yarım eğik kapak
                g.append(f'<rect x="{x}" y="{y}" width="{hw}" height="{hh/2}" rx="7" fill="#30343C" transform="skewX(-8)" transform-origin="{x} {y+hh/2}"/>')
            g.append(f'<text x="{x+hw/2}" y="{y+hh*0.72}" text-anchor="middle" font-family="J" font-size="64" fill="{renk}">{ch}</text>')
    zemin = (f'<rect width="{W}" height="{H}" fill="url(#terminal)"/>'
             + "".join(f'<rect x="{x}" y="0" width="{w}" height="{H}" fill="#FFFFFF" opacity="{o}" transform="skewX(-14)"/>'
                       for x, w, o in [(200, 90, .10), (420, 40, .08), (760, 140, .10), (1100, 60, .07)]))
    parilti = f'<rect x="40" y="560" width="{W-80}" height="420" rx="22" fill="#F2D59A" opacity="{isik}"/>' if isik else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><defs>{FONT}'
            f'<linearGradient id="terminal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E9EEF5"/><stop offset=".6" stop-color="#F6EFE6"/><stop offset="1" stop-color="#EADFCF"/></linearGradient></defs>'
            f'{zemin}{"".join(g)}{parilti}<text x="40" y="70" font-family="J" font-size="26" fill="#2C4374">{alt}</text></svg>')

random.seed(4)
karma = lambda n: "".join(random.choice(HARF) for _ in range(n))
B = [
    ("B1", [("IST  14:20 A7", "#F4EFE6", None), ("SAW  15:05 B2", "#F4EFE6", None), ("ESB  15:40 C1", "#F4EFE6", None)],
     "B1 · terminalin kalkış panosu; kapaklar şakırdamaya başlıyor"),
    ("B2", [(karma(14), "#F4EFE6", {1, 4, 7, 10, 12}), (karma(14), "#F4EFE6", {0, 3, 6, 9}), ("ESB  15:40 C1", "#F4EFE6", {2, 5})],
     "B2 · bütün harfler aynı anda dönüyor (ses: tak-tak-tak)"),
    ("B3", [("  LOUNGELINK  ", "#F2D59A", None), ("  LOUNGE'DA   ", "#F4EFE6", None), ("  BULUŞALIM   ", "#8FD3B6", None)],
     "B3 · pano durur: LOUNGELINK · LOUNGE'DA BULUŞALIM"),
]
for ad, satir, alt in B:
    (KOK / f"pano_{ad}.svg").write_text(pano(satir, alt, 0.06 if ad == "B3" else 0), encoding="utf-8")

# ---------------- C · iki ışık buluşuyor ----------------
def isik(adim, alt):
    # stilize terminal planı: koridorlar
    kor = ["M 120 1500 L 120 1100 L 540 900", "M 960 1500 L 960 1100 L 540 900", "M 540 900 L 540 640",
           "M 120 1100 L 40 1100", "M 960 1100 L 1040 1100", "M 330 1000 L 330 1300", "M 750 1000 L 750 1300"]
    plan = "".join(f'<path d="{d}" stroke="#C9D4E6" stroke-width="34" stroke-linecap="round" stroke-linejoin="round" fill="none"/>' for d in kor)
    kapilar = "".join(f'<circle cx="{x}" cy="{y}" r="9" fill="#9FB2D2"/>' for x, y in [(330, 1300), (750, 1300), (120, 1500), (960, 1500), (40, 1100), (1040, 1100)])
    salon = '<rect x="470" y="590" width="140" height="90" rx="18" fill="#FFFFFF" stroke="#C9A86E" stroke-width="3"/><text x="540" y="645" text-anchor="middle" font-family="J" font-size="22" fill="#8A6D3B" letter-spacing="3">LOUNGE</text>'
    if adim == 1:
        a, b = (120, 1250), (960, 1180); iz = ('<path d="M 120 1500 L 120 1250" stroke="#E2B867" stroke-width="10" stroke-linecap="round" opacity=".7"/>'
                                              '<path d="M 960 1500 L 960 1180" stroke="#4FB6A0" stroke-width="10" stroke-linecap="round" opacity=".7"/>')
        nokta = f'<circle cx="{a[0]}" cy="{a[1]}" r="20" fill="#E2B867" filter="url(#p)"/><circle cx="{b[0]}" cy="{b[1]}" r="20" fill="#4FB6A0" filter="url(#p)"/>'
        orta = ""
    elif adim == 2:
        iz = ('<path d="M 120 1500 L 120 1100 L 470 935" stroke="#E2B867" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity=".7"/>'
              '<path d="M 960 1500 L 960 1100 L 610 935" stroke="#4FB6A0" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity=".7"/>')
        nokta = '<circle cx="470" cy="935" r="22" fill="#E2B867" filter="url(#p)"/><circle cx="610" cy="935" r="22" fill="#4FB6A0" filter="url(#p)"/>'
        orta = '<text x="540" y="1040" text-anchor="middle" font-family="J" font-size="34" fill="#1A2B4C">Kapıda buluşma</text>'
    else:
        iz = ""; nokta = ""
        orta = (f'<circle cx="540" cy="880" r="240" fill="url(#hale)"/>'
                f'<g transform="translate(540,880) scale(5.2) translate(-107,-132)" filter="url(#p)">{kanat_ic}</g>'
                f'<text x="540" y="1170" text-anchor="middle" font-family="J" font-size="74" fill="#1A2B4C" letter-spacing="22">LOUNGELINK</text>'
                f'<text x="540" y="1250" text-anchor="middle" font-family="JR" font-size="36" fill="#41557E">Havalimanında üç saat, yalnız geçmek zorunda değil.</text>')
        plan = f'<g opacity=".25">{plan}</g>'; salon = ""; kapilar = ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><defs>{FONT}'
            f'<linearGradient id="zc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F4F6FA"/><stop offset="1" stop-color="#F3EDE4"/></linearGradient>'
            f'<radialGradient id="hale"><stop offset="0" stop-color="#FFF1D4"/><stop offset="1" stop-color="#FFF1D4" stop-opacity="0"/></radialGradient>'
            f'<filter id="p" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="8" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>'
            f'<rect width="{W}" height="{H}" fill="url(#zc)"/>{plan}{kapilar}{salon}{iz}{nokta}{orta}'
            f'<text x="40" y="70" font-family="J" font-size="26" fill="#2C4374">{alt}</text></svg>')
for i, alt in [(1, "C1 · iki yolcu, iki ayrı kapı: altın ışık host, yeşil ışık misafir"),
               (2, "C2 · koridorlar onları lounge kapısına getiriyor"),
               (3, "C3 · iki ışık birleşir, kanada dönüşür; logo ve slogan")]:
    (KOK / f"isik_C{i}.svg").write_text(isik(i, alt), encoding="utf-8")
print("ok")
