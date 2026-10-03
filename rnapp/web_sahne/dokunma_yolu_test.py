#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/dokunma_yolu_test.py

============================================================================
DOKUNMA YOLU — "BASIYORUM, HİÇBİR ŞEY OLMUYOR" BİR DAHA OLMASIN

🔴 NEDEN VAR — GÖKBERK'İN İKİ KEZ YAŞADIĞI ŞEY

  1. "app açıldığında splash ekrandaki butonlar çalışmıyor"
     Kök: dekoratif bir `Image` katmanı bütün dokunmayı yutuyordu.
     Android'de `pointerEvents` YALNIZ `ReactViewGroup`tan okunur
     (`TouchTargetHelper.java:309-311`); `Image`de sessizce yok sayılır.
     Web'de CSS'e çevrildiği için localhost'ta HATA GÖRÜNMÜYORDU.

  2. "Tanış → Sohbeti Aç hiçbir şey yapmıyor"
     Kök: katman açılış sırası defteri o katmanı dinlemiyordu; sohbet
     gerçekten açılıyor ama YIĞININ ALTINDA kalıyordu.

İkisi de **sözdizimi kusursuz** hatalardı. İkisini de statik kapılar
göremezdi. Birincisini `gecirgen_check.py`, ikincisini
`katman_sira_check.py` artık yakalıyor — ama ikisi de DOLAYLI kapı:
"şu desen yanlış" diyorlar, "şu düğme çalışmıyor" demiyorlar.

Bu dosya DOĞRUDAN soruyu soruyor: **bastım, ekran değişti mi?**

🆕 SINIF: "BİR DÜĞMENİN ÇALIŞTIĞINI KANITLAMANIN TEK YOLU ONA BASMAKTIR
— DESEN DENETİMİ 'BU KEZ NEDEN ÇALIŞMADIĞINI' YAKALAR, 'ÇALIŞTIĞINI'
DEĞİL."

── NE YAPIYOR ──────────────────────────────────────────────────────────

Gerçek Chromium'da uygulamayı açar ve OTURUMSUZ yolun her adımına
tek tek basar:

    Splash → "Başla"        → Tanıtım
    Tanıtım → "Devam" ×4    → Kart seçimi
    Tanıtım → "Başla"       → Kayıt formu
    Splash → "Giriş Yap"    → Giriş formu

Her adımda EKRANIN DEĞİŞTİĞİNİ kanıtlar: dokunmadan önceki ve sonraki
`document.body.innerText` AYNI ise adım DÜŞMÜŞ sayılır ve kapı kırmızı
yanar. Ayrıca her adımda `pageerror` ve `console.error` toplanır.

⚠️ NEDEN "ekran metni değişti" ÖLÇÜSÜ: bir düğme çalışmadığında ekran
AYNI kalır. Ekran görüntüsü karşılaştırması da olurdu ama metin daha
ucuz ve daha az kırılgan (animasyon karesi farkı yanlış alarm üretmez).

── ⛔ BU KAPININ GÖREMEDİĞİ ŞEY — MUTASYON TESTİNİN SÖYLEDİĞİ ───────────

Mutasyon testini iki kez koştum. Sonuç DÜRÜSTÇE şu:

  MUTASYON                                       bu kapı    gecirgen_check
  ────────────────────────────────────────────   ───────    ──────────────
  tam ekran <View>, pointerEvents yok             🔴 KIRMIZI    yeşil
  tam ekran <Image>, pointerEvents yok             yeşil ⚠️    🔴 KIRMIZI

İkinci satır bu kapının SINIRIDIR ve tam olarak Gökberk'in yaşadığı
hatanın şeklidir. Sebebini DOM'da ölçtüm: react-native-web `Image`i
`pointer-events:none` + `z-index:-1` ile basar — o katman TARAYICIDA
hiçbir zaman dokunma almaz. Android'de ise `ReactImageView`
`ReactPointerEventsView` uygulamadığı için AUTO sayılır ve yutar.

Yani: **tarayıcıda koşan hiçbir test `Image` kaynaklı dokunma tuzağını
yakalayamaz.** Onu `gecirgen_check.py`nin 2. ölçüsü kaynakta yakalar.

🆕 SINIF: "BİR TESTİN YEŞİL YANMASI, O HATA SINIFINI ÖLÇTÜĞÜ ANLAMINA
GELMEZ — MUTASYONU SOKUP KIRMIZI GÖRMEDEN 'KORUYOR' DEME; GÖREMEDİĞİ
SINIFI DA YANINA YAZ, YOKSA BİRİ ONA GÜVENİR."

İKİSİ BİRLİKTE kapatıyor. Biri tek başına kapatmıyor.

TAVAN 0 · düşen adım.
============================================================================
"""
import functools
import http.server
import json
import os
import re
import socketserver
import subprocess
import sys
import threading
import time
from datetime import datetime

from playwright.sync_api import sync_playwright

KOK = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(KOK, "dist")
KOPRU_PORT = 8766
TAVAN = 0

# ⚠️ MAKBUZ — bu test tarayıcı ister, `verify.js` ise Python + Node ile
# her yerde koşar. Bağlamazsak "yazılmış ama koşmamış" bir test olur ki
# `website/verify.js`in başındaki ders tam olarak budur. Çözüm: test
# başarıyla bitince KAYNAK ÖZETİNİ bir makbuza yazar; `dokunma_makbuz_check.py`
# makbuzun GÜNCEL kaynakla eşleştiğine bakar. Kod değişip test koşmadıysa
# özet tutmaz ve zincir kırmızı yanar.
MAKBUZ = os.path.join(KOK, "out", "dokunma_yolu.json")
sys.path.insert(0, os.path.dirname(KOK))
from dokunma_makbuz_check import kaynak_ozeti  # noqa: E402

# (etiket, dokunma tipi, hedef metin, adımdan sonra beklenen İZ)
# `iz`: yeni ekranda GÖRÜNMESİ gereken metin parçası. Yalnız "değişti mi"
# demek yetmez — yanlış bir ekrana gitmek de bir kusurdur.
YOL = [
    ("Splash → Başla",          "dokun", "Başla",     "Devam"),
    ("Tanıtım 1 → Devam",       "dokun", "Devam",     "Devam"),
    ("Tanıtım 2 → Devam",       "dokun", "Devam",     "Devam"),
    ("Tanıtım 3 → Devam",       "dokun", "Devam",     "Devam"),
    ("Tanıtım 4 → Devam",       "dokun", "Devam",     "HANGİ KART SENİN"),
    ("Kart ekranı → Başla",     "dokun", "Başla",     "Hesap Oluştur"),
]

GIRIS_YOLU = [
    ("Splash → Giriş Yap",      "dokun", "Giriş Yap", "Kaldığın yerden devam et"),
]

# ⚠️ ÜÇÜNCÜ KAPI: splash'teki İKİNCİ bağlantı ("Önce dene…"). Kayıt
# düğmesi çalışırken bunun ölü kalması mümkündür — ayrı yol, ayrı kanıt.
DENE_YOLU = [
    ("Splash → Önce dene",      "dokun", "Önce dene: hangi salona girebilirim?", "Salon Rehberi"),
    ("Salon Rehberi → ‹ Geri",  "dokun", "‹ Geri",                                "Önce dene: hangi salona"),   # v7: iki splash'te de ortak iz (eski koyu slogan v7'de yok)
]


class Sessiz(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def sunucu():
    socketserver.TCPServer.allow_reuse_address = True
    h = functools.partial(Sessiz, directory=DIST)
    srv = socketserver.TCPServer(("127.0.0.1", 0), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, srv.server_address[1]


def kopru():
    return subprocess.Popen(
        [sys.executable, os.path.join(KOK, "pg_kopru.py"), str(KOPRU_PORT)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def chromium():
    for p in ("/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
              "/opt/pw-browsers/chromium/chrome"):
        if os.path.exists(p):
            return p
    return None


def metin(pg):
    try:
        return re.sub(r"\s+", " ", pg.evaluate("document.body.innerText")).strip()
    except Exception:
        return ""


def yuru(pg, yol, kayit, bulgular, basligi):
    print("  %s" % basligi)
    for etiket, _tur, hedef, iz in yol:
        once = metin(pg)
        try:
            loc = pg.get_by_text(re.compile(r"^\s*" + re.escape(hedef) + r"\s*(→|›)?\s*$", re.I))
            loc.last.click(timeout=4000)
        except Exception as e:
            bulgular.append((etiket, "DOKUNULAMADI: %s" % str(e).splitlines()[0][:90]))
            print("      ✗ %-26s dokunulamadı" % etiket)
            return
        pg.wait_for_timeout(950)
        sonra = metin(pg)
        if sonra == once:
            bulgular.append((etiket, "EKRAN DEĞİŞMEDİ — düğme basıldı, hiçbir şey olmadı"))
            print("      ✗ %-26s EKRAN DEĞİŞMEDİ" % etiket)
            return
        if iz and iz.lower() not in sonra.lower():
            bulgular.append((etiket, "beklenen iz yok: '%s'" % iz))
            print("      ✗ %-26s beklenen iz yok ('%s')" % (etiket, iz))
            return
        print("      ✓ %-26s ekran değişti (%d → %d karakter)"
              % (etiket, len(once), len(sonra)))


def main():
    if not os.path.isdir(DIST):
        print("🔴 web_sahne/dist yok — önce:")
        print("     LL_SAHNE=1 npx expo export --platform web --output-dir web_sahne/dist --clear")
        sys.exit(1)
    exe = chromium()
    srv, port = sunucu()
    kp = kopru()
    time.sleep(0.8)
    bulgular = []
    kayit = {"hata": [], "konsol": []}

    print("=" * 74)
    print("DOKUNMA YOLU — oturumsuz akışın her düğmesine gerçekten basılıyor")
    print("=" * 74)

    try:
        with sync_playwright() as p:
            b = p.chromium.launch(executable_path=exe)
            for ad, yol in (("A · Kayıt yolu", YOL),
                            ("B · Giriş yolu", GIRIS_YOLU),
                            ("C · Önce dene yolu", DENE_YOLU)):
                ctx = b.new_context(viewport={"width": 390, "height": 844},
                                    device_scale_factor=2, is_mobile=True,
                                    has_touch=True, locale="tr-TR")
                pg = ctx.new_page()
                pg.on("pageerror", lambda e: kayit["hata"].append(str(e)[:200]))
                pg.on("console", lambda m: kayit["konsol"].append(m.text[:200])
                      if m.type == "error" else None)
                pg.goto("http://127.0.0.1:%d/?sahne=01_splash&kim=&kopru=http://127.0.0.1:%d"
                        % (port, KOPRU_PORT), wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception:
                    bulgular.append((ad, "__LL_HAZIR hiç gelmedi — app açılmadı"))
                    print("  ✗ %s — app açılmadı" % ad)
                    ctx.close()
                    continue
                yuru(pg, yol, kayit, bulgular, ad)
                ctx.close()
            b.close()
    finally:
        kp.kill()
        srv.shutdown()

    print("")
    if kayit["hata"]:
        print("  ⚠ sayfa hatası: %d" % len(kayit["hata"]))
        for h in kayit["hata"][:3]:
            print("      %s" % h)
        bulgular.append(("sayfa hatası", kayit["hata"][0][:90]))

    # ── MAKBUZ ──────────────────────────────────────────────────────────
    # Başarısız koşu da yazılır: makbuzun tek işi "en son ne oldu"yu
    # söylemektir. Kırmızı bir makbuz, makbuzsuzluktan daha dürüsttür.
    try:
        os.makedirs(os.path.dirname(MAKBUZ), exist_ok=True)
        json.dump({
            "tarih": datetime.now().isoformat(timespec="seconds"),
            "kaynak_ozeti": kaynak_ozeti(),
            "dusen": len(bulgular),
            "adimlar": [e for e, _t, _h, _i in YOL]
                       + [e for e, _t, _h, _i in GIRIS_YOLU]
                       + [e for e, _t, _h, _i in DENE_YOLU],
        }, open(MAKBUZ, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("  · makbuz: web_sahne/out/dokunma_yolu.json")
    except Exception as e:
        print("  ⚠ makbuz yazılamadı: %s" % e)

    print("")
    if bulgular:
        print("  ✗ %d adım düştü:" % len(bulgular))
        for e, n in bulgular:
            print("      %-28s %s" % (e, n))
        print("")
        print("  BU TAM OLARAK 'BASIYORUM AMA İLERLEMİYOR' DEMEKTİR.")
        print("  Bak: dekoratif katmanda `pointerEvents` (gecirgen_check.py) ·")
        print("  katman sırası (katman_sira_check.py) · onPress bağlı mı.")
    else:
        print("  ✓ oturumsuz akışın her düğmesi ekranı gerçekten değiştiriyor")
    print("")
    print("SONUC  dusen=%d  tavan=%d" % (len(bulgular), TAVAN))
    sys.exit(1 if len(bulgular) > TAVAN else 0)


main()
