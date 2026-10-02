# Hareket dili vitrini: her hareketi kısa bir video (webm) olarak kaydeder.
# Kullanım: PYTHONUTF8=1 PGPORT=58911 python web_sahne/hareket_kayit.py
# Çıktı: web_sahne/out/hareket/<ad>.webm  (390x844, ~5 sn)
import os, sys, glob, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cek
from playwright.sync_api import sync_playwright

HAREKETLER = [
    ("k1_acilis", "01_splash", 5200),
    ("k2_yukleyici", "66_vitrin_yukleyici", 4200),
    ("k3_radar", "61_vitrin_radar", 5200),
    ("k4_damga", "67_vitrin_damga", 3600),
    ("k5_kapi", "60_vitrin_kapi", 4800),
    ("k6_pano", "68_vitrin_pano", 5200),
    ("k7_kalkis", "69_vitrin_kalkis", 4200),
    ("k8_puan", "62_vitrin_puan", 4200),
    ("k9_zemin", "59_vitrin_zemin", 6000),
]

def main():
    hedef = os.path.join(cek.OUT, "hareket")
    os.makedirs(hedef, exist_ok=True)
    gecici = os.path.join(hedef, "_ham")
    srv, port = cek.sunucu()
    kopru = cek.kopru_baslat()
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for ad, sahne, sure in HAREKETLER:
                shutil.rmtree(gecici, ignore_errors=True)
                ctx = b.new_context(viewport={"width": 390, "height": 844}, locale="tr-TR",
                                    record_video_dir=gecici, record_video_size={"width": 390, "height": 844})
                pg = ctx.new_page()
                kim = cek.SAHNELER[sahne][0]
                pg.goto(f"http://127.0.0.1:{port}/?sahne={sahne}&kim={kim}&dil=tr&kopru=http://127.0.0.1:{cek.KOPRU_PORT}",
                        wait_until="networkidle")
                pg.wait_for_timeout(sure)
                ctx.close()
                vid = glob.glob(os.path.join(gecici, "*.webm"))
                if vid:
                    shutil.move(vid[0], os.path.join(hedef, ad + ".webm"))
                    print(ad, "ok", os.path.getsize(os.path.join(hedef, ad + ".webm")) // 1024, "KB")
                else:
                    print(ad, "VIDEO YOK")
            b.close()
    finally:
        kopru.terminate()
        shutil.rmtree(gecici, ignore_errors=True)

if __name__ == "__main__":
    main()
