# Tek seferlik hata ayıklama: bir akışı adım adım koşturup her adımda ekran ve dokunulabilir öğeleri döker.
import sys, json, re
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import akis_e2e as A, cek
from playwright.sync_api import sync_playwright

ADIMLAR = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
KIM = sys.argv[1] if len(sys.argv) > 1 else ""
srv, port = cek.sunucu(); kopru = cek.kopru_baslat()
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        e = A.Ekran(b, port, KIM)
        for i, a in enumerate(ADIMLAR):
            try:
                getattr(e, a[0])(*a[1:])
                durum = "ok"
            except Exception as ex:
                durum = "HATA " + str(ex)[:160]
            print("── adım %d %s → %s" % (i, a, durum))
        e.bekle(800)
        print("METİN:", " | ".join(s for s in e.metin().split("\n") if s.strip())[:int(__import__("os").environ.get("DBG_N","900"))])
        print("DOKUNULABİLİR:", " | ".join(re.sub(r"[-]", "", x) for x in e.dokunulabilirler())[:1500])
        print("INPUTLAR:", e.pg.evaluate("Array.from(document.querySelectorAll('input,textarea')).map(i=>i.placeholder+'#'+(i.disabled?'kapali':''))"))
        print("HATA:", e.hatalar, e.logerror(), e.rpc_hatalari())
        e.foto("dbg")
        b.close()
finally:
    srv.shutdown(); kopru.terminate()
