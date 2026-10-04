#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/akis_e2e.py — UÇTAN UCA AKIŞ TESTİ (gerçek uygulama · gerçek tarayıcı · gerçek veritabanı)

4 Ekim 2026 · Gökberk: "her sayfa, her akış için beklenen / gerçekleşen; misafir ve
host; iptal, red, kabul, düzenleme; happy · edge · alternate · negative."

Nasıl çalışır:
  · `LL_SAHNE=1` web derlemesi (web_sahne/dist) → GERÇEK App.js ve GERÇEK ekranlar.
  · `pg_kopru.py` → her rpc()/from() yerel `ll` veritabanında GERÇEK fonksiyon
    gövdesi + GERÇEK RLS ile koşar; kayıt/giriş de `auth.users` üzerinde gerçek.
  · Her akış: ekranda dokun/yaz → ekranda ne göründü (beklenen/gerçekleşen) →
    veritabanında ne oldu (beklenen/gerçekleşen). İkisi de kayda geçer.
  · Dünya her bölümden önce `sahne_seed.sql` ile tazelenir (deterministik).

Kullanım:
  python web_sahne/akis_e2e.py               → bütün bölümler
  python web_sahne/akis_e2e.py giris kesfet  → seçili bölümler
  python web_sahne/akis_e2e.py --envanter    → her ekranın dokunulabilir öğe dökümü
Çıktı: web_sahne/out/akis_e2e.json (+ ekran görüntüleri out/akis/)
"""
import os, sys, re, json, time, traceback
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cek   # sunucu · köprü · tohum altyapısı
from playwright.sync_api import sync_playwright

try:
    import psycopg2
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "render_check"))
    import pg8000_psycopg2; pg8000_psycopg2.kur()
    import psycopg2

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(KOK, "out")
EKRAN = os.path.join(OUT, "akis")
os.makedirs(EKRAN, exist_ok=True)
DSN = dict(host="127.0.0.1", dbname="ll", user="postgres", password="ll",
           port=int(os.environ.get("PGPORT", "5432")))

KIM = {}   # ad → uuid (sahneler.js'ten)
for m in re.finditer(r"(\w+):\s*\{\s*id:\s*\"([0-9a-f-]{36})\"", open(os.path.join(KOK, "sahneler.js"), encoding="utf-8").read()):
    KIM[m.group(1)] = m.group(2)


def db(sql, args=None, tek=False):
    c = psycopg2.connect(**DSN)
    try:
        cur = c.cursor(); cur.execute(sql, args or ())
        rows = cur.fetchall() if cur.description else []
        c.commit()
        return (rows[0][0] if rows and rows[0] else None) if tek else rows
    finally:
        c.close()


class Kayit:
    def __init__(self):
        self.satirlar = []
    def ekle(self, bolum, akis, rol, tur, beklenen, ok, gerceklesen, kanit=None):
        self.satirlar.append(dict(bolum=bolum, akis=akis, rol=rol, tur=tur, beklenen=beklenen,
                                  gerceklesen=gerceklesen, durum="GECTI" if ok else "KALDI", kanit=kanit))
        print("  %s [%s·%s·%s] %s%s" % ("✓" if ok else "✗", bolum, rol, tur, akis, "" if ok else "  — " + str(gerceklesen)[:160]))
    def yaz(self):
        json.dump(self.satirlar, open(os.path.join(OUT, "akis_e2e.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        g = sum(1 for s in self.satirlar if s["durum"] == "GECTI")
        print("\n%d/%d akış kontrolü geçti" % (g, len(self.satirlar)))
        return g, len(self.satirlar)


class Ekran:
    """Tek bir kullanıcının tarayıcı sekmesi."""
    def __init__(self, b, port, kim, ek="", genis=False):
        self.kim = kim
        self.ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                                 is_mobile=True, has_touch=True, locale="tr-TR")
        self.pg = self.ctx.new_page()
        self.hatalar = []
        self.pg.on("pageerror", lambda e: self.hatalar.append(str(e)[:300]))
        url = f"http://127.0.0.1:{port}/?sahne=e2e&kim={kim}&dil=tr&kopru=http://127.0.0.1:{cek.KOPRU_PORT}" + (("&" + ek) if ek else "")
        self.pg.goto(url, wait_until="networkidle")
        try:
            self.pg.wait_for_function("window.__LL_HAZIR === true", timeout=12000)
        except Exception:
            self.hatalar.append("__LL_HAZIR beklenmedi")
        self.pg.wait_for_timeout(500)

    # ── eylemler ───────────────────────────────────────────────────
    def _tik(self, loc, zaman=4000):
        try:
            loc.click(timeout=1500)
        except Exception:
            cek.ortala(loc)
            try:
                loc.click(timeout=zaman)
            except Exception:
                # Alt sekme çubuğu / yüzen katman öğeyi örtüyorsa: DOM tıklaması (RN-web onPress'i tetikler)
                loc.evaluate("el => el.click()")
        self.pg.wait_for_timeout(700)

    def dokun(self, metin, tam=True, kacinci=-1):
        desen = ("^\\s*" + re.escape(metin) + "\\s*(→|›|✓)?\\s*$") if tam else re.escape(metin)
        loc = self.pg.get_by_text(re.compile(desen, re.I))
        n = loc.count()
        if n == 0 and tam:
            # Türkçe büyük harf: CSS text-transform "İsteği gönder"i "İSTEĞİ GÖNDER" çizer ve JS'in
            # büyük/küçük harf duyarsız regex'i i ↔ İ'yi eşlemez. Düğmeleri normalize ederek ara.
            bulundu = self.pg.evaluate(r"""(arg) => {
              const n = s => (s || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase().replace(/[→›✓]/g, '').replace(/\s+/g, ' ').trim();
              const h = n(arg.m);
              document.querySelectorAll('[data-e2e-hedef]').forEach(x => x.removeAttribute('data-e2e-hedef'));
              const ad = Array.from(document.querySelectorAll('[role=button]')).filter(b => {
                const r = b.getBoundingClientRect(); if (!r.width || !r.height) return false;
                // metin ya da (yalnız ikonlu düğmede) erişilebilirlik etiketi; "· 25" gibi sayaç eki yok sayılır
                const ad = [n(b.innerText), n(b.getAttribute('aria-label'))].map(x => x.replace(/\s*·\s*\d+\+?$/, ''));
                return ad.includes(h);
              });
              if (!ad.length) return false;
              ad[arg.k >= 0 ? Math.min(arg.k, ad.length - 1) : ad.length - 1].setAttribute('data-e2e-hedef', '1');
              return true;
            }""", {"m": metin, "k": kacinci})
            if bulundu:
                self._tik(self.pg.locator('[data-e2e-hedef="1"]').first)
                return
        if n == 0:
            raise AssertionError("dokunulacak metin yok: " + metin)
        self._tik(loc.nth(kacinci if kacinci >= 0 else n - 1))

    def dokun_etiket(self, etiket, kacinci=0):
        loc = self.pg.get_by_label(re.compile(re.escape(etiket), re.I))
        if loc.count() == 0:
            raise AssertionError("dokunulacak etiket yok: " + etiket)
        self._tik(loc.nth(kacinci))

    def yaz(self, yer_tutucu, deger):
        loc = self.pg.get_by_placeholder(re.compile(re.escape(yer_tutucu), re.I)).first
        loc.fill(deger, timeout=4000)
        self.pg.wait_for_timeout(200)

    def bekle(self, ms):
        self.pg.wait_for_timeout(ms)

    # ── gözlem ─────────────────────────────────────────────────────
    def metin(self):
        try:
            return self.pg.evaluate("document.body.innerText")
        except Exception:
            return ""

    @staticmethod
    def _n(s):
        # Türkçe büyük harf (CSS text-transform innerText'e yansır): İ→i, I→ı; boşlukları sadeleştir.
        return re.sub(r"\s+", " ", str(s).replace("İ", "i").replace("I", "ı").lower())

    def var(self, parca, ms=3500):
        son = time.time() + ms / 1000.0
        while time.time() < son:
            if self._n(parca) in self._n(self.metin()):
                return True
            self.pg.wait_for_timeout(250)
        return False

    def yok(self, parca, ms=1200):
        self.pg.wait_for_timeout(ms)
        return self._n(parca) not in self._n(self.metin())

    def ham_kodlar(self):
        """Görünen metinde VE erişilebilirlik etiketlerinde doldurulmamış {yer_tutucu} / ham kod."""
        try:
            return self.pg.evaluate(r"""() => {
              const bul = [];
              const desen = /\{[a-zA-Z_]+\}|\b[a-z]+_[a-z_]+\b/;
              const izin = /@|https?:|\.test|loungelink/;
              document.querySelectorAll('[aria-label]').forEach(e => {
                const v = e.getAttribute('aria-label') || '';
                if (desen.test(v) && !izin.test(v)) bul.push('etiket: ' + v.slice(0, 80));
              });
              (document.body.innerText || '').split('\n').forEach(l => {
                if (desen.test(l) && !izin.test(l)) bul.push('metin: ' + l.slice(0, 80));
              });
              return Array.from(new Set(bul)).slice(0, 10);
            }""")
        except Exception as ex:
            return ["NÖBETÇİ ÇÖKTÜ: " + str(ex)[:120]]   # sessiz geçme yok

    def logerror(self):
        try:
            return self.pg.evaluate("(globalThis.__CALLS||[]).filter(c=>c.kind==='logError').map(c=>c.screen+': '+c.err)")
        except Exception:
            return []

    def rpc_hatalari(self):
        try:
            return self.pg.evaluate("(globalThis.__CALLS||[]).filter(c=>c.error).map(c=>(c.fn||c.table)+': '+c.error)")
        except Exception:
            return []

    def foto(self, ad):
        try:
            self.pg.screenshot(path=os.path.join(EKRAN, ad + ".png"))
        except Exception:
            pass

    def dokunulabilirler(self):
        return self.pg.evaluate("""() => {
          const out = [];
          document.querySelectorAll('[role=button],[role=tab],[role=link],[role=radio],[role=checkbox],[role=switch],input,textarea').forEach(e => {
            const r = e.getBoundingClientRect(); if (!r.width || !r.height) return;
            const ad = (e.getAttribute('aria-label') || e.innerText || e.getAttribute('placeholder') || '').trim().replace(/\\s+/g,' ').slice(0,70);
            out.push((e.getAttribute('role') || e.tagName.toLowerCase()) + ' · ' + ad);
          });
          return out;
        }""")

    # ── kart düzeyi (Keşfet / istek listeleri) ─────────────────────
    # Kart sınırı: içinde TEK bir "HH:MM–HH:MM" aralığı olan en büyük ata. Böylece
    # aynı host'un aynı gün iki ilanı karışmaz (ölçüldü: Bora'nın 10:00 ve 13:30 isteği).
    _KART_JS = r"""(arg) => {
      const n = s => (s || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase().replace(/\s+/g, ' ');
      const aralik = /\d\d:\d\d\s*[–-]\s*\d\d:\d\d/g;
      const say = s => ((s || '').match(aralik) || []).length;
      const parcalar = arg.parcalar.map(n);
      const hepsi = el => { const t = n(el.innerText); return parcalar.every(p => t.includes(p)); };
      let en = null;
      document.querySelectorAll('div,span').forEach(el => {
        if (!hepsi(el) || say(el.innerText) !== 1) return;
        let k = el;
        while (k.parentElement && say(k.parentElement.innerText) === 1) k = k.parentElement;
        if (!en || k.innerText.length < en.innerText.length) en = k;
      });
      if (!en) {
        // Saat aralığı olmayan kartlar (davet, bildirim): parçaları içeren en küçük ata,
        // aranan düğme isteniyorsa onu da içerene kadar yukarı.
        document.querySelectorAll('div').forEach(el => {
          if (!hepsi(el)) return;
          let k = el;
          if (arg.dugme) { let g = 0; while (k && g < 6 && !Array.from(k.querySelectorAll('[role=button]')).some(b => n(b.getAttribute('aria-label') || b.innerText).replace(/[→›✓]/g, '').trim() === n(arg.dugme))) { k = k.parentElement; g++; } }
          if (k && (!en || k.innerText.length < en.innerText.length)) en = k;
        });
      }
      if (!en) return null;
      if (arg.dugme) {
        const d = n(arg.dugme);
        const aday = Array.from(en.querySelectorAll('[role=button]')).filter(b => {
          const t = n(b.getAttribute('aria-label') || b.innerText).replace(/[→›✓]/g, '').trim();
          return t === d;
        });
        document.querySelectorAll('[data-e2e-hedef]').forEach(x => x.removeAttribute('data-e2e-hedef'));
        if (!aday.length) return {metin: en.innerText, dugme: false};
        aday[0].setAttribute('data-e2e-hedef', '1');
        return {metin: en.innerText, dugme: true};
      }
      return {metin: en.innerText};
    }"""

    def kart_metni(self, *parcalar):
        r = self.pg.evaluate(self._KART_JS, {"parcalar": list(parcalar), "dugme": None})
        return r["metin"] if r else None

    def kart_dokun(self, parcalar, dugme):
        r = self.pg.evaluate(self._KART_JS, {"parcalar": list(parcalar), "dugme": dugme})
        if not r:
            raise AssertionError("kart yok: %s" % (parcalar,))
        if not r["dugme"]:
            raise AssertionError("kartta '%s' düğmesi yok: %s" % (dugme, r["metin"][:160].replace("\n", " | ")))
        self._tik(self.pg.locator('[data-e2e-hedef="1"]').first)

    def kaydir_bul(self, *parcalar, tur=12):
        """Uzun listede kart görünene kadar aşağı kaydırır (FlatList sanallaştırması)."""
        for _ in range(tur):
            if self.kart_metni(*parcalar):
                return True
            self.pg.mouse.wheel(0, 900); self.pg.wait_for_timeout(350)
        return bool(self.kart_metni(*parcalar))

    def kapat(self):
        try:
            self.ctx.close()
        except Exception:
            pass


BOLUMLER = {}   # ad → fonksiyon(b, port, kayit)
def bolum(ad):
    def sar(f):
        BOLUMLER[ad] = f
        return f
    return sar


# ════════════════════════════════════════════════════════════════════
# ENVANTER — her ekranın dokunulabilir öğeleri (test matrisi buradan kurulur)
# ════════════════════════════════════════════════════════════════════
ENVANTER = [
    ("acilis", "", []),
    ("ana_misafir", "gokberk", []),
    ("ana_host", "selin", []),
    ("ana_nehir", "nehir", []),
    ("ana_arda", "arda", []),
    ("kesfet_misafir", "gokberk", [("dokun", "Keşfet")]),
    ("kesfet_arda", "arda", [("dokun", "Keşfet")]),
    ("planim_misafir", "gokberk", [("dokun", "Planım")]),
    ("planim_host", "selin", [("dokun", "Planım")]),
    ("tanis_misafir", "gokberk", [("dokun", "Tanış")]),
    ("profil_misafir", "gokberk", [("dokun", "Profil")]),
    ("profil_host", "selin", [("dokun", "Profil")]),
]

def envanter(b, port):
    rapor = {}
    for ad, kim, adimlar in ENVANTER:
        e = Ekran(b, port, kim)
        for a in adimlar:
            try:
                getattr(e, a[0])(*a[1:])
            except Exception as ex:
                print("  ! %s adım: %s" % (ad, ex))
        e.bekle(1200)
        rapor[ad] = {"dokunulabilir": e.dokunulabilirler(), "metin": [s for s in e.metin().split("\n") if s.strip()][:120],
                     "hata": e.hatalar, "logError": e.logerror(), "rpc_hata": e.rpc_hatalari()}
        e.foto("env_" + ad)
        print("%-16s dokunulabilir=%3d  hata=%d  rpc_hata=%d" % (ad, len(rapor[ad]["dokunulabilir"]), len(e.hatalar), len(rapor[ad]["rpc_hata"])))
        e.kapat()
    json.dump(rapor, open(os.path.join(OUT, "akis_envanter.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def calis(secili, env=False):
    cek.dunyayi_tazele()
    srv, port = cek.sunucu()
    kopru = cek.kopru_baslat()
    k = Kayit()
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            if env:
                envanter(b, port)
            else:
                for ad in (secili or list(BOLUMLER)):
                    print("\n══ %s ══" % ad)
                    cek.dunyayi_tazele()
                    try:
                        BOLUMLER[ad](b, port, k)
                    except Exception as ex:
                        k.ekle(ad, "bölüm çöktü", "-", "altyapı", "bölüm sonuna kadar koşmalı", False, repr(ex)[:300])
                        traceback.print_exc()
            b.close()
    finally:
        srv.shutdown(); kopru.terminate()
    if not env:
        return k.yaz()


# Bölümler ayrı dosyada (akis_e2e_bolumler.py) — bu dosya altyapı.
sys.modules.setdefault("akis_e2e", sys.modules[__name__])   # bölümler AYNI kayıt defterine yazsın
import glob as _glob
for _f in sorted(_glob.glob(os.path.join(KOK, "akis_e2e_b*.py"))):
    __import__(os.path.splitext(os.path.basename(_f))[0])   # bölümler bolum() ile kaydolur

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sonuc = calis(args, env="--envanter" in sys.argv)
    if sonuc and sonuc[0] < sonuc[1]:
        sys.exit(1)
