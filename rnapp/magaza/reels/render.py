# video.html'yi kare kare çizer. Kullanım:
#   python render.py A pano 1.5 4.5 7.5 ...   → anahtar kare panosu (pano_A.png)
#   python render.py A video                   → kareler + MP4 (LoungeLink_reels_A.mp4)
import sys, pathlib, subprocess, shutil
from playwright.sync_api import sync_playwright
from PIL import Image
KOK = pathlib.Path(__file__).parent
FF = r"C:\Users\gokbe\AppData\Local\Programs\Python\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"
tema, mod = sys.argv[1], sys.argv[2]
FPS = 30
BEKLE = "Promise.all([...document.images].filter(i=>i.src).map(i=>i.complete&&i.naturalWidth?1:i.decode().catch(()=>0)))"
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1080, "height": 1920})
    pg.goto((KOK / (f"video{tema}.html" if (KOK / f"video{tema}.html").exists() else "video.html")).as_uri() + f"?tema={tema}")
    pg.wait_for_timeout(800)
    hatalar = []
    pg.on("pageerror", lambda e: hatalar.append(str(e)))
    if mod == "pano":
        zam = [float(x) for x in sys.argv[3:]]
        ims = []
        for t in zam:
            pg.evaluate(f"window.ciz({t})"); pg.evaluate(BEKLE); pg.wait_for_timeout(60)
            ims.append(Image.open(__import__("io").BytesIO(pg.screenshot(type="png"))).convert("RGB").resize((270, 480)))
        cols = 6; rows = (len(ims) + cols - 1) // cols
        o = Image.new("RGB", (cols * 276, rows * 486), (30, 30, 30))
        for i, im in enumerate(ims): o.paste(im, ((i % cols) * 276, (i // cols) * 486))
        o.save(KOK / f"pano_{tema}.png"); print("pano", len(ims), hatalar[:3])
    else:
        d = KOK / f"kare_{tema}"; shutil.rmtree(d, ignore_errors=True); d.mkdir()
        sure = pg.evaluate("window.SURE"); n = int(sure * FPS)
        for i in range(n):
            pg.evaluate(f"window.ciz({i / FPS})"); pg.evaluate(BEKLE)
            pg.screenshot(path=str(d / f"{i:04d}.jpg"), type="jpeg", quality=93)
        print("kare", n, hatalar[:3])
        out = KOK / f"LoungeLink_reels_{tema}.mp4"
        subprocess.run([FF, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", str(d / "%04d.jpg"),
                        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out)], check=True)
        print("mp4", out, out.stat().st_size // 1024, "KB")
    b.close()
