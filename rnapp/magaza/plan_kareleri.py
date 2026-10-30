# 30 Ekim — mağaza kareleri 08/09 için plan ekranı: başlık bandı + tam kart (kesik görünmesin).
# Kaynak: web_sahne/out/29s_plan_inceleme_alt.png ve 29t_plan_inceleme_yillik.png (cek.py, boy=1600).
# Çalıştır: python magaza/plan_kareleri.py  →  sonra python magaza/uret.py
from PIL import Image
import pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent / "web_sahne" / "out"
def yap(kaynak, a, ad):
    b = Image.open(OUT / kaynak).convert("RGB")
    o = Image.new("RGB", (1170, 2532), (247, 244, 238))
    o.paste(b.crop((0, a * 3, 1170, (a + 639) * 3)), (0, 205 * 3))
    o.paste(b.crop((0, 0, 1170, 205 * 3)), (0, 0))
    o.save(OUT / ad); print(ad, o.size)
yap("29s_plan_inceleme_alt.png", 425, "29u_plan_sik_ucan.png")
yap("29t_plan_inceleme_yillik.png", 943, "29v_plan_jetset_yillik.png")
