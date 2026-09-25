#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/bant_olcum.py — BANT RİTMİNİ SAHNEDEN ÖLÇER.

🔴 NEDEN VAR — GÖKBERK NOT2 (13 Eylül)
"seyahatlerim güncel tasarımda boş görünümde header alanındaki
 seyahatlerim ve ilanlarım sekmeleri biraz fazla yukarı kaymamış mı
 (planım-host görseli)? app'in boş görünümünde burada ve diğer
 yerlerde benzer bir sorun mu olacak?"

Soru bir GEOMETRİ sorusu ve gözle cevaplanamaz: "fazla yukarıda"
demek, çipin üstündeki ve altındaki boşluğun ÖLÇÜLMESİ demek. `cek.py`
metin ve taşma ölçüyor, BOŞLUK ölçmüyordu.

NE ÖLÇER (390×844, gerçek render):
  · bandın alt kenarı
  · çip satırının üst/alt kenarı
  · çipin ÜSTÜNDEKİ boşluk (başlığın altından çipin üstüne)
  · çipin ALTINDAKİ boşluk (çipin altından bandın altına)
  · ilk içerik satırının üstü (bandın altına göre)
ve aynı bandı BOŞ ile DOLU durumda karşılaştırır — fark varsa
"boş görünümde kaymış" iddiası ÖLÇÜLMÜŞ olur.

🆕 SINIF: "'FAZLA YUKARIDA' BİR HİS DEĞİL BİR SAYIDIR — ÖLÇMEDEN
DÜZELTMEK, BAŞKA BİR EKRANI BOZMAKTIR."
"""
import os, sys, json, time, subprocess, functools, http.server, socketserver, threading
from playwright.sync_api import sync_playwright

KOK = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(KOK, "dist")
OUT = os.path.join(KOK, "out")
KOPRU_PORT = 8765

# (sahne adı, kim, adımlar, ek sorgu) — cek.py'nin SAHNELER tablosuyla aynı dil
OLCUMLER = [
    ("47_ilanlarim_bos",    "boshost", [("dokun", "Planım")], ""),
    ("12b_ilanlarim",       "selin",   [("dokun", "Planım")], ""),
    ("48_seyahat_bos_host", "boshost", [("dokun", "Planım"), ("a11y", "Seyahatlerim")], ""),
    ("14b_seyahatler_host", "selin",   [("dokun", "Planım"), ("a11y", "Seyahatlerim")], ""),
    ("05_tanis",            "gokberk", [("dokun", "Tanış")], ""),
]

OLC_JS = r"""() => {
  const kutu = (e) => { const r = e.getBoundingClientRect();
    return { ust: Math.round(r.top), alt: Math.round(r.bottom),
             sol: Math.round(r.left), gen: Math.round(r.width), yuk: Math.round(r.height) }; };
  const metni = (e) => (e.innerText || "").trim();

  // Bant: en üstte duran, ekran genişliğinde, yüksekliği 120+ olan kap.
  let bant = null;
  for (const e of document.querySelectorAll("div")) {
    const r = e.getBoundingClientRect();
    if (r.top <= 2 && r.width >= 380 && r.height >= 120 && r.height <= 420) {
      if (!bant || r.height > bant.getBoundingClientRect().height) bant = e;
    }
  }
  if (!bant) return { hata: "bant bulunamadi" };

  // 🔴 İLK SÜRÜM BAŞLIĞI DA ÇİP SANDI: 47'de "4 çip" saydı, oysa iki
  // tane var. Sebep, süzgecin METNE bakmasıydı — bandın başlığı da
  // "İlanlarım", üst bilgisi de. Metinle ayırmak imkânsız; YAPIYLA
  // ayrılır: `FotoBant` dışarıdan gelen her şeyi `testID="bant-slot"`
  // ile işaretliyor ve `altIcerik` (çip satırı) onlardan biri.
  // 🆕 SINIF: "AYNI METNİ TAŞIYAN İKİ ÖĞEYİ METİNLE AYIRAMAZSIN —
  // ÖLÇÜMÜ YAPIYA BAĞLA."
  const adlar = ["Seyahatlerim", "İlanlarım", "Tanış", "Bağlantılarım"];
  const cipler = [];
  for (const slot of bant.querySelectorAll('[data-testid="bant-slot"]')) {
    for (const e of slot.querySelectorAll("*")) {
      const m = metni(e);
      if (!adlar.includes(m)) continue;
      if (cipler.some(c => c.el.contains(e))) continue;
      // iç Text düğümünü değil, dokunulabilir kabı al
      let kap = e;
      while (kap.parentElement && kap.parentElement !== slot &&
             metni(kap.parentElement) === m) kap = kap.parentElement;
      if (cipler.some(c => c.el === kap)) continue;
      cipler.push({ el: kap, ad: m, k: kutu(kap) });
    }
  }

  // Başlık: bandın KENDİ metinlerinden (slot dışı) en büyük yazı boyutlu.
  // Slot içeriği bandın metni değil; başlık oradan seçilemez.
  let baslik = null, enBuyuk = 0;
  for (const e of bant.querySelectorAll("*")) {
    if (e.children.length) continue;
    if (e.closest('[data-testid="bant-slot"]')) continue;
    const m = metni(e); if (!m) continue;
    const fs = parseFloat(getComputedStyle(e).fontSize) || 0;
    if (fs > enBuyuk) { enBuyuk = fs; baslik = e; }
  }

  // Bandın ALTINDAKİ ilk görünür içerik
  const bk = bant.getBoundingClientRect();
  let ilkIcerik = null;
  for (const e of document.querySelectorAll("*")) {
    if (bant.contains(e) || e.children.length) continue;
    const m = metni(e); if (!m) continue;
    const r = e.getBoundingClientRect();
    if (r.top >= bk.bottom - 1 && r.height > 4) {
      if (!ilkIcerik || r.top < ilkIcerik.k.ust) ilkIcerik = { ad: m.slice(0, 28), k: kutu(e) };
    }
  }

  const cipUst = cipler.length ? Math.min(...cipler.map(c => c.k.ust)) : null;
  const cipAlt = cipler.length ? Math.max(...cipler.map(c => c.k.alt)) : null;
  return {
    bant: kutu(bant),
    baslik: baslik ? { metin: metni(baslik).slice(0, 28), fs: Math.round(enBuyuk), k: kutu(baslik) } : null,
    cip_sayisi: cipler.length,
    cipler: cipler.map(c => ({ ad: c.ad, ust: c.k.ust, alt: c.k.alt, yuk: c.k.yuk })),
    cip_ustu_bosluk: (baslik && cipUst !== null) ? cipUst - kutu(baslik).alt : null,
    cip_alti_bosluk: (cipAlt !== null) ? kutu(bant).alt - cipAlt : null,
    ilk_icerik: ilkIcerik,
    icerik_bosluk: ilkIcerik ? ilkIcerik.k.ust - kutu(bant).alt : null,
  };
}"""


class Sessiz(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def sunucu():
    socketserver.TCPServer.allow_reuse_address = True
    h = functools.partial(Sessiz, directory=DIST)
    srv = socketserver.TCPServer(("127.0.0.1", 0), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, srv.server_address[1]


def main():
    kopru = subprocess.Popen([sys.executable, os.path.join(KOK, "pg_kopru.py"), str(KOPRU_PORT)],
                             stdout=subprocess.DEVNULL,
                             stderr=open(os.path.join(OUT, "_kopru_olcum.log"), "w"))
    time.sleep(0.9)
    srv, port = sunucu()
    sonuc = {}
    try:
        with sync_playwright() as p:
            b = p.chromium.launch(args=["--no-sandbox"])
            for ad, kim, adimlar, ek in OLCUMLER:
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                                    is_mobile=True, has_touch=True, locale="tr-TR")
                pg = ctx.new_page()
                pg.goto(f"http://127.0.0.1:{port}/?sahne={ad}&kim={kim}"
                        f"&kopru=http://127.0.0.1:{KOPRU_PORT}" + (("&" + ek) if ek else ""),
                        wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=12000)
                except Exception:
                    pass
                for adim in adimlar:
                    try:
                        if adim[0] == "dokun":
                            import re as _re
                            pg.get_by_text(_re.compile(r"^\s*" + _re.escape(adim[1]) + r"\s*$")).first.click(timeout=5000)
                        else:
                            import re as _re
                            pg.get_by_label(_re.compile(_re.escape(adim[1]))).first.click(timeout=5000)
                        pg.wait_for_timeout(500)
                    except Exception as e:
                        print(f"   ! {ad}: adım düştü {adim} — {str(e)[:70]}")
                pg.wait_for_timeout(700)
                # ══════════════════════════════════════════════════════
                # 🔴 ÖLÇÜM ARACININ KENDİ YAPAYLIĞI — 78 pt'LİK HAYALET.
                #
                # İlk ölçümde Seyahatlerim sekmesinde bandın içeriği 78pt
                # yukarıda çıkıyordu ve bunu ürün hatası sandım; hatta
                # `useDaralanBant`a sıfırlama yazdım. SONRA DÖNÜŞÜMÜ
                # ÖLÇTÜM: `matrix(1,0,0,1,0,0)` — kimlik. Yani bant
                # kaymamıştı.
                # Gerçek sebep: `FotoBant`ın dekoratif fotoğrafı BİLEREK
                # kutudan büyük ve `overflow:hidden` ile kırpılıyor
                # (ölçüm: clientHeight 225 · scrollHeight 377). Tarayıcıda
                # bu, kabı PROGRAMLA kaydırılabilir yapıyor ve Playwright'ın
                # `click()`i çipi "görünür kılmak" için o gizli kabı 78pt
                # kaydırıyor. Cihazda RN `overflow:hidden` böyle
                # kaydırılmaz — yani ölçtüğüm şey üründe YOK.
                #
                # 🆕 SINIF: "BİR ÖLÇÜM ARACI ÖLÇTÜĞÜ ŞEYİ DEĞİŞTİRİYORSA,
                # BULDUĞU KUSUR ÖNCE ARACIN KUSURUDUR."
                pg.evaluate("""() => {
                  for (const e of document.querySelectorAll("*"))
                    if (e.scrollTop) e.scrollTop = 0;
                }""")
                pg.wait_for_timeout(200)
                sonuc[ad] = pg.evaluate(OLC_JS)
                ctx.close()
            b.close()
    finally:
        srv.shutdown()
        kopru.terminate()

    with open(os.path.join(OUT, "_bant_olcum.json"), "w", encoding="utf-8") as f:
        json.dump(sonuc, f, ensure_ascii=False, indent=1)

    print("\n" + "=" * 74)
    print("BANT RİTMİ — ÇİP KONUMU (390×844, gerçek render)")
    print("=" * 74)
    bas = f"{'sahne':<22}{'bant_alt':>9}{'çip':>5}{'çip_üst':>9}{'çip_alt':>9}{'üst_bşl':>9}{'alt_bşl':>9}{'içerik':>8}"
    print(bas)
    print("-" * 74)
    for ad, d in sonuc.items():
        if d.get("hata"):
            print(f"{ad:<22} {d['hata']}")
            continue
        print(f"{ad:<22}{d['bant']['alt']:>9}{d['cip_sayisi']:>5}"
              f"{(d['cipler'][0]['ust'] if d['cipler'] else -1):>9}"
              f"{(d['cipler'][0]['alt'] if d['cipler'] else -1):>9}"
              f"{str(d['cip_ustu_bosluk']):>9}{str(d['cip_alti_bosluk']):>9}"
              f"{str(d['icerik_bosluk']):>8}")
    print("-" * 74)

    # BOŞ vs DOLU karşılaştırması — Not2'nin asıl sorusu
    ciftler = [("47_ilanlarim_bos", "12b_ilanlarim"), ("48_seyahat_bos_host", "14b_seyahatler_host")]
    print("\nBOŞ ↔ DOLU KARŞILAŞTIRMASI (Not2'nin sorusu)")
    kusur = 0
    for bos, dolu in ciftler:
        a, c = sonuc.get(bos), sonuc.get(dolu)
        if not a or not c or a.get("hata") or c.get("hata"):
            print(f"  {bos} ↔ {dolu}: ölçülemedi")
            continue
        for alan, ad in [("cip_ustu_bosluk", "çip üstü boşluk"),
                         ("cip_alti_bosluk", "çip altı boşluk"),
                         ("icerik_bosluk", "içerik boşluğu")]:
            x, y = a.get(alan), c.get(alan)
            if x is None or y is None:
                print(f"  {ad:<18} {bos}={x}  {dolu}={y}  (biri yok)")
                continue
            fark = x - y
            isaret = "✓" if abs(fark) <= 1 else "✗"
            if abs(fark) > 1:
                kusur += 1
            print(f"  {isaret} {ad:<18} boş={x:>4}  dolu={y:>4}  fark={fark:+d} pt")
        if a["cip_sayisi"] != c["cip_sayisi"]:
            print(f"  ✗ çip sayısı  boş={a['cip_sayisi']} dolu={c['cip_sayisi']}")
            kusur += 1
    print()
    if kusur:
        print(f"✗ {kusur} ölçümde boş ile dolu arasında fark var — bant ritmi içeriğe bağlı.")
        sys.exit(1)
    print("✓ Bant ritmi boş ve dolu durumda AYNI — çipler kaymıyor.")


if __name__ == "__main__":
    main()
