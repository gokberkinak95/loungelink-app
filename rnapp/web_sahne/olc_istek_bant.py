# -*- coding: utf-8 -*-
# İstek Gönder başlığındaki beyaz şerit: hangi katman nerede? (teşhis, 16 Ekim)
import json, sys
sys.argv = [sys.argv[0]]
import akis_e2e as A
import cek
from playwright.sync_api import sync_playwright

cek.dunyayi_tazele()
srv, port = cek.sunucu()
kopru = cek.kopru_baslat()
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        e = A.Ekran(b, port, "kaan")
        e.dokun("Keşfet"); e.bekle(1800)
        e.dokun("İstek gönder"); e.bekle(1500)
        r = e.pg.evaluate("""() => {
          const out = [];
          for (let y = 200; y <= 330; y += 6) {
            const els = document.elementsFromPoint(195, y).slice(0, 4).map(el => {
              const r = el.getBoundingClientRect(); const cs = getComputedStyle(el);
              return el.tagName + ' ' + Math.round(r.top) + '-' + Math.round(r.bottom) + ' bg=' + cs.backgroundColor.slice(0, 22) + (el.tagName === 'IMG' ? ' img' : '') + ' op=' + cs.opacity;
            });
            out.push(y + ': ' + els.join(' | '));
          }
          return out;
        }""")
        print("\n".join(r))
        e.foto("teshis_istek_bant")
        e.kapat(); b.close()
finally:
    srv.shutdown(); kopru.terminate()
