import sys, pathlib
from playwright.sync_api import sync_playwright
K = pathlib.Path(__file__).parent
out = pathlib.Path(r"C:\LoungeLink\_gorseller\postlar"); out.mkdir(parents=True, exist_ok=True)
isler = sys.argv[1:]          # "1" "2" ... veya "m3" (misafir rehberi 3. kare), "h2" (host rehberi)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1080, "height": 1350})
    hata = []; pg.on("pageerror", lambda e: hata.append(str(e)))
    for i in isler:
        pg.goto((K / "posts.html").as_uri() + f"?p={i}"); pg.wait_for_timeout(900)
        pg.evaluate("Promise.all([...document.images].map(i=>i.complete?1:i.decode().catch(()=>0)))")
        pg.screenshot(path=str(out / f"post_{i}.png"))
    b.close()
print("ok", isler, hata[:3])
