#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/oniz_cek.py — GEÇİCİ. Önizleme varyantlarını gerçek ağaçtan çeker.
`cek.py` ile aynı sunucu/köprü, tek fark: URL'ye varyant parametresi ekler.
Teyitten sonra silinecek.
"""
import os, sys, json
import cek

OUT = os.path.join(cek.KOK, "out", "oniz")
os.makedirs(OUT, exist_ok=True)

# ad → (sahne, ek_sorgu)
ISLER = {
    "perde_a":  ("15_tanitim",       ""),
    "perde_b":  ("15_tanitim",       "&perdev=b"),
    "perde3_a": ("15b_tanitim3",     ""),
    "perde3_b": ("15b_tanitim3",     "&perdev=b"),
    "kart_a":   ("15c_tanitim_kart", "&perdev=b"),
    "kart_b":   ("15c_tanitim_kart", "&perdev=b&kartv=b"),
    "kart_c":   ("15c_tanitim_kart", "&perdev=b&kartv=c"),
    "kesfet_a": ("02_kesfet",        ""),
    "kesfet_b": ("02_kesfet",        "&paletv=b&dugmev=b"),
    "kural_a":  ("03_kural",         ""),
    "kural_b":  ("03_kural",         "&paletv=b&dugmev=b"),
    "ana_a":    ("11_ana_misafir",   ""),
    "ana_b":    ("11_ana_misafir",   "&paletv=b&dugmev=b"),
    "profil_a": ("09_profil",        ""),
    "profil_b": ("09_profil",        "&paletv=b&dugmev=b"),
    "tanis_a":  ("05_tanis",         ""),
    "tanis_b":  ("05_tanis",         "&paletv=b&dugmev=b"),
    "onb_a":    ("15c_tanitim_kart", ""),
    "onb_b":    ("15c_tanitim_kart", "&perdev=b&kartv=b&paletv=b&dugmev=b"),
}

from playwright.sync_api import sync_playwright


def main(adlar):
    srv, port = cek.sunucu()
    kopru = cek.kopru_baslat()
    try:
        with sync_playwright() as p:
            exe = "/opt/pw-browsers/chromium/chrome"
            b = p.chromium.launch(executable_path=exe if os.path.exists(exe) else None)
            for ad in adlar:
                sahne, ek = ISLER[ad]
                kim, adimlar = cek.SAHNELER[sahne]
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=3,
                                    is_mobile=True, has_touch=True, locale="tr-TR",
                                    user_agent="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
                pg = ctx.new_page()
                kayit = {"console": [], "errors": []}
                pg.on("pageerror", lambda e: kayit["errors"].append(str(e)[:600]))
                pg.goto(f"http://127.0.0.1:{port}/?sahne={sahne}&kim={kim}"
                        f"&kopru=http://127.0.0.1:{cek.KOPRU_PORT}{ek}", wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception:
                    kayit["errors"].append("__LL_HAZIR beklenmedi")
                for adim in adimlar:
                    cek.adim_uygula(pg, adim, kayit)
                pg.wait_for_timeout(900)
                pg.screenshot(path=os.path.join(OUT, ad + ".png"))
                print("%-10s hata=%d" % (ad, len(kayit["errors"])), kayit["errors"][:1])
                ctx.close()
            b.close()
    finally:
        srv.shutdown()
        kopru.terminate()


if __name__ == "__main__":
    main(sys.argv[1:] or list(ISLER))
