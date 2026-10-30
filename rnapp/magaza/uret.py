# -*- coding: utf-8 -*-
# ============================================================================
# MAĞAZA GÖRSELLERİ ÜRETİCİSİ (16 Ekim 2026)
#
# Gerçek uygulama ekranları (web_sahne/cek.py · gerçek React ağacı + gerçek veri,
# 1170×2532) uygulamanın kendi fontları ve renkleriyle mağaza karelerine yerleşir:
#   App Store  iPhone 6,9"  1320 × 2868   → cikti/appstore/
#   Google Play telefon      1080 × 1920   → cikti/play/
#   Google Play tanıtım      1024 × 500    → cikti/play/feature.png
#   Google Play ikon          512 × 512    → cikti/play/icon-512.png
# Kullanım:  python magaza/uret.py   (önce: python web_sahne/cek.py <sahneler>)
# ============================================================================
import os, pathlib, base64, time
from playwright.sync_api import sync_playwright
from PIL import Image

def yaz_png(out, veri):
    # Windows'ta dosya kısa süre kilitli olabiliyor (görüntüleyici/tarayıcı): Errno 22 → bekle, yeniden dene.
    for i in range(8):
        try:
            with open(out, "wb") as fh:
                fh.write(veri)
            return
        except OSError:
            time.sleep(0.5 * (i + 1))
    raise OSError("yazilamadi: " + str(out))


KOK = pathlib.Path(__file__).resolve().parent
APP = KOK.parent
SAHNE = APP / "web_sahne" / "out"
FONT = APP / "assets" / "fonts"
CIKTI = KOK / "cikti"

KARELER = [
    ("01", "02_kesfet",       "Lounge'a misafir<br>olarak gir.",        "Kartında misafir hakkı olan yolcuyla aynı salonda buluş."),
    ("02", "50_istek_gonder", "Tek istek.<br>Net kurallar.",           "Kabul edilmezse kredin anında geri döner."),
    ("03", "05_tanis",        "Aynı uçuştaki<br>yolcularla tanış.",     "Kahve, iş bağlantısı ya da yol arkadaşlığı."),
    ("04", "06_sohbet",       "Kapıda buluşmaya<br>kadar her şey burada.", "Buluşma noktası, durum paylaşımı, hazır mesajlar."),
    ("05", "87_oturum_canli", "Salondaki zaman<br>kayıt altında.",       "Oturum iki tarafın onayıyla tamamlanır."),
    ("06", "88_oturum_puanla","Güven her buluşmayla<br>büyür.",          "Karşılıklı puan, bildir ve engelle, kadın güvenlik modu."),
    # 20 Ekim (6.9.2) — Jetset, plana göre puan, ödül indirimi ve erken erişim görünür olsun.
    ("07", "22c_market_jetset","Her buluşma<br>puan kazandırır.",       "LoungePuan'ı seyahatte işine yarayan ödüllere çevir."),
    # 30 Ekim — plan karesi ikiye ayrıldı: kartlar kesik görünmesin, aylık ve yıllık ikisi de görünsün.
    ("08", "29u_plan_sik_ucan", "Sık Uçan ve<br>Jetset.",                "Aylık ya da yıllık: her ay ilan başvurusu, ödül indirimi, erken erişim."),
    ("09", "29v_plan_jetset_yillik", "Yıllık planda<br>daha avantajlı.",  "Jetset yıllıkta %25 indirimli: her ay 7 ilan başvurusu."),
]


def uri(p):
    return pathlib.Path(p).resolve().as_uri()


def mark_svg():
    p = APP / "assets" / "fonts" / "mark-kanat.svg"
    if not p.exists():
        p = APP.parent / "website" / "public" / "mark-kanat.svg"
    return "data:image/svg+xml;base64," + base64.b64encode(p.read_bytes()).decode()


CSS = """
@font-face { font-family: Corm; src: url('%(f)s/CormorantGaramond-SemiBold.ttf'); font-weight: 600; }
@font-face { font-family: Corm; src: url('%(f)s/CormorantGaramond-Medium.ttf'); font-weight: 500; }
@font-face { font-family: Jak; src: url('%(f)s/PlusJakartaSans-Medium.ttf'); font-weight: 500; }
@font-face { font-family: Jak; src: url('%(f)s/PlusJakartaSans-Bold.ttf'); font-weight: 700; }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; }
body { background: radial-gradient(120%% 70%% at 50%% 0%%, #2A3F68 0%%, #1A2B4C 45%%, #0E1830 100%%);
       font-family: Jak, sans-serif; color: #F9F8F6; position: relative; }
.isik { position: absolute; left: 50%%; top: %(isik)dpx; width: %(isikw)dpx; height: %(isikw)dpx; transform: translateX(-50%%);
        background: radial-gradient(circle, rgba(212,195,163,0.28) 0%%, rgba(212,195,163,0) 62%%); }
.ust { position: absolute; left: 0; right: 0; top: %(ust)dpx; text-align: center; padding: 0 %(kenar)dpx; }
.marka { display: inline-flex; align-items: center; gap: %(mg)dpx; font: 700 %(mf)dpx Jak; letter-spacing: 0.32em; color: #D4C3A3; }
.marka img { width: %(mi)dpx; }
h1 { font: 600 %(hf)dpx/1.04 Corm, serif; margin-top: %(hm)dpx; letter-spacing: -0.005em; }
p { font: 500 %(pf)dpx/1.35 Jak, sans-serif; color: rgba(249,248,246,0.78); margin-top: %(pm)dpx; }
.tel { position: absolute; left: 50%%; top: %(tt)dpx; width: %(tw)dpx; transform: translateX(-50%%);
       border-radius: %(tr)dpx; padding: %(tb)dpx; background: linear-gradient(160deg, #3A4560, #0B1020 55%%, #2A3248);
       box-shadow: 0 %(sg)dpx %(sb)dpx rgba(0,0,0,0.45), inset 0 0 0 2px rgba(212,195,163,0.25); }
.tel img { display: block; width: 100%%; border-radius: %(ir)dpx; }
"""


def kare_html(w, h, olcu, sahne, baslik, alt):
    d = dict(f=uri(FONT), w=w, h=h, **olcu)
    return ("<html><head><meta charset='utf-8'><style>" + CSS % d + "</style></head><body>"
            "<div class='isik'></div>"
            "<div class='ust'><div class='marka'><img src='" + mark_svg() + "'>LOUNGELINK</div>"
            "<h1>" + baslik + "</h1><p>" + alt + "</p></div>"
            "<div class='tel'><img src='" + uri(SAHNE / (sahne + ".png")) + "'></div>"
            "</body></html>")


APPSTORE = dict(isik=360, isikw=1500, ust=150, kenar=90, mg=22, mf=30, mi=64, hf=112, hm=34, pf=42, pm=26,
                tt=760, tw=1040, tr=120, tb=24, ir=98, sg=40, sb=120)
PLAY = dict(isik=200, isikw=1100, ust=80, kenar=70, mg=16, mf=22, mi=46, hf=76, hm=20, pf=30, pm=16,
            tt=470, tw=760, tr=92, tb=18, ir=76, sg=30, sb=90)


def main():
    (CIKTI / "appstore").mkdir(parents=True, exist_ok=True)
    (CIKTI / "play").mkdir(parents=True, exist_ok=True)
    tmp = CIKTI / "_tmp.html"
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        for hedef, (w, h, olcu) in (("appstore", (1320, 2868, APPSTORE)), ("play", (1080, 1920, PLAY))):
            pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
            for no, sahne, baslik, alt in KARELER:
                if hedef == "play" and no == "06": continue   # Play en çok 8 kare alır; puanlama karesi 07 ile örtüşüyor
                tmp.write_text(kare_html(w, h, olcu, sahne, baslik, alt), encoding="utf-8")
                pg.goto(uri(tmp)); pg.wait_for_timeout(500)
                out = CIKTI / hedef / f"{no}_{sahne}.png"
                yaz_png(out, pg.screenshot())
                Image.open(out).convert("RGB").save(out)   # mağazalar alfa kanalı istemez
            pg.close()

        # Google Play tanıtım görseli 1024×500
        html = ("<html><head><meta charset='utf-8'><style>" + CSS % dict(f=uri(FONT), w=1024, h=500, **dict(
            isik=-120, isikw=900, ust=0, kenar=0, mg=14, mf=18, mi=40, hf=64, hm=14, pf=22, pm=12,
            tt=0, tw=0, tr=0, tb=0, ir=0, sg=0, sb=0)) +
            ".sol{position:absolute;left:64px;top:118px;width:560px}"
            ".sol h1{font-size:64px}.sag{position:absolute;right:70px;top:40px;width:300px;border-radius:40px;padding:10px;"
            "background:linear-gradient(160deg,#3A4560,#0B1020 55%,#2A3248);box-shadow:0 24px 60px rgba(0,0,0,.45),inset 0 0 0 2px rgba(212,195,163,.25)}"
            ".sag img{display:block;width:100%;border-radius:32px}"
            "</style></head><body><div class='isik' style='left:30%'></div>"
            "<div class='sol'><div class='marka'><img src='" + mark_svg() + "'>LOUNGELINK</div>"
            "<h1>Lounge'a misafir<br>olarak gir.</h1><p>Misafir hakkı olan yolcularla aynı salonda buluş.</p></div>"
            "<div class='sag'><img src='" + uri(SAHNE / "02_kesfet.png") + "'></div></body></html>")
        tmp.write_text(html, encoding="utf-8")
        pg = b.new_page(viewport={"width": 1024, "height": 500}, device_scale_factor=1)
        pg.goto(uri(tmp)); pg.wait_for_timeout(500)
        out = CIKTI / "play" / "feature.png"
        yaz_png(out, pg.screenshot())
        Image.open(out).convert("RGB").save(out)
        b.close()
    tmp.unlink(missing_ok=True)

    # Play ikonu 512×512 (App Store ikonu build'den gelir: assets/icon.png 1024)
    Image.open(APP / "assets" / "icon.png").convert("RGB").resize((512, 512), Image.LANCZOS).save(CIKTI / "play" / "icon-512.png")
    for f in sorted(CIKTI.rglob("*.png")):
        print(f.relative_to(CIKTI), Image.open(f).size)


if __name__ == "__main__":
    main()

# 30 Ekim — App Store Connect artık "iPhone with Dynamic Island (medium display)" alanında 6,1"/6,3" boyut istiyor
# (1206×2622 · 1179×2556). 6,9" kareler bundan küçültülür (oran farkı 1 px; sağdan kırpılır).
def _orta_ekran():
    from PIL import Image
    hedef = CIKTI / "appstore_6.3" if "CIKTI" in globals() else Path(__file__).parent / "cikti" / "appstore_6.3"
    hedef.mkdir(parents=True, exist_ok=True)
    for f in sorted((hedef.parent / "appstore").glob("0*.png")):
        im = Image.open(f).convert("RGB").resize((1207, 2622), Image.LANCZOS).crop((0, 0, 1206, 2622))
        im.save(hedef / f.name)
        print("appstore_6.3\\" + f.name, im.size)

_orta_ekran()
