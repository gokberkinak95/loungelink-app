"""Bir sahnenin TAMAMINI kaydırarak çeker (ScrollView sabit boylu; full_page işe yaramaz).
python3 web_sahne/uzun_cek.py 18_ana_host1 19_ana_guest1  → out/<ad>_uzun.png"""
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
import cek
from playwright.sync_api import sync_playwright
from PIL import Image

def uzun(adlar):
    srv, port = cek.sunucu(); kopru = cek.kopru_baslat()
    try:
        with sync_playwright() as p:
            exe = "/opt/pw-browsers/chromium/chrome"
            b = p.chromium.launch(executable_path=exe if os.path.exists(exe) else None)
            for ad in adlar:
                kim, adimlar = cek.SAHNELER[ad]
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                                    is_mobile=True, has_touch=True, locale="tr-TR")
                pg = ctx.new_page()
                pg.goto(f"http://127.0.0.1:{port}/?sahne={ad}&kim={kim}&kopru=http://127.0.0.1:{cek.KOPRU_PORT}", wait_until="networkidle")
                try: pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception: pass
                kayit = {"errors": []}
                for a in adimlar: cek.adim_uygula(pg, a, kayit)
                pg.wait_for_timeout(1500)
                # en büyük kaydırılabilir öğe
                js = """() => { const els=[...document.querySelectorAll('*')].filter(e=>{const s=getComputedStyle(e);return /(auto|scroll)/.test(s.overflowY)&&e.scrollHeight>e.clientHeight+10;});
                       els.sort((a,b)=>b.scrollHeight-a.scrollHeight); const e=els[0]; if(!e) return null; e.setAttribute('data-ll-scroll','1'); return [e.scrollHeight,e.clientHeight]; }"""
                sh = pg.evaluate(js)
                parcalar = []
                if not sh:
                    pg.screenshot(path=os.path.join(cek.OUT, f"{ad}_uzun.png")); print(ad, "kaydırılamadı"); continue
                top = 0; total, client = sh
                while True:
                    pg.evaluate("y => { const e=document.querySelector('[data-ll-scroll]'); e.scrollTop=y; }", top)
                    pg.wait_for_timeout(500)
                    parcalar.append(pg.screenshot())
                    if top + client >= total: break
                    top = min(top + client, total - client)
                ims = [Image.open(__import__('io').BytesIO(x)) for x in parcalar]
                W = ims[0].width; H = sum(i.height for i in ims)
                sheet = Image.new("RGB", (W, H)); y = 0
                for i in ims: sheet.paste(i, (0, y)); y += i.height
                sheet.save(os.path.join(cek.OUT, f"{ad}_uzun.png")); print(ad, len(ims), "parça", kayit["errors"][:2])
                ctx.close()
            b.close()
    finally:
        srv.shutdown(); kopru.terminate()

if __name__ == "__main__":
    uzun([a for a in sys.argv[1:]] or ["18_ana_host1"])
