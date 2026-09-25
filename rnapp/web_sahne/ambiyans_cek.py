#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/ambiyans_cek.py — AYNI EKRAN, GÜNÜN DÖRT SAATİ.

🔴 NEDEN AYRI BİR BETİK
`cek.py` her sahneyi TEK kuşakta ("aksam") çekiyor ve bu bilerek:
sahne görüntüleri belirlenimli olmalı. Ama "günün saatine göre
ambiyans" özelliğinin tek kanıtı, AYNI ekranın dört kuşakta yan yana
durmasıdır — tek bir kareye bakan biri değişimi göremez, çünkü
değişim zaten görülmemek üzere tasarlandı (tepe şiddeti %5–8.5).

Yani bu betik bir test değil, bir KANIT üreticisi: ölçüm
`doku_check.py`de (dört dosyanın her satırında dört mürekkep),
burada yalnız gözle karşılaştırma var.

🆕 SINIF: "GÖRÜNMEMEK ÜZERE TASARLANMIŞ BİR ŞEYİ TESLİM EDERKEN,
GÖRÜNÜR HÂLE GETİREN AYRI BİR KARE ÜRET — YOKSA YAPILMAMIŞ SAYILIR."
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cek                                                    # noqa: E402
from playwright.sync_api import sync_playwright               # noqa: E402

OUT = os.path.join(cek.KOK, "out", "ambiyans")
os.makedirs(OUT, exist_ok=True)
EXE = "/opt/pw-browsers/chromium/chrome"
KUSAKLAR = ["safak", "gunduz", "aksam", "gece"]


def main(sahne="11_ana_misafir"):
    kim, adimlar = cek.SAHNELER[sahne]
    srv, port = cek.sunucu()
    kopru = cek.kopru_baslat()
    try:
        with sync_playwright() as p:
            b = p.chromium.launch(executable_path=EXE if os.path.exists(EXE) else None)
            for kusak in KUSAKLAR:
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                                    is_mobile=True, has_touch=True, locale="tr-TR")
                pg = ctx.new_page()
                kayit = {"console": [], "errors": []}
                pg.on("pageerror", lambda e: kayit["errors"].append(str(e)[:300]))
                pg.goto("http://127.0.0.1:%d/?sahne=%s&kim=%s&an=%s&kopru=http://127.0.0.1:%d"
                        % (port, sahne, kim, kusak, cek.KOPRU_PORT), wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception:
                    kayit["errors"].append("__LL_HAZIR beklenmedi")
                for a in adimlar:
                    cek.adim_uygula(pg, a, kayit)
                pg.wait_for_timeout(700)
                pg.screenshot(path=os.path.join(OUT, "%s_%s.png" % (sahne, kusak)))
                print("%-8s hata=%d" % (kusak, len(kayit["errors"])), kayit["errors"][:1])
                ctx.close()
            b.close()
    finally:
        srv.shutdown()
        kopru.terminate()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "11_ana_misafir")
