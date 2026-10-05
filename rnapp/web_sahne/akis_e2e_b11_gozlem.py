# -*- coding: utf-8 -*-
# GÖZLEM + KONTROL (5 Ekim · Gökberk'in 4 maddesi)
from akis_e2e import bolum, Ekran, db, KIM
from akis_e2e_bolumler import _dene


@bolum("gozlem")
def gozlem(b, port, k):
    B = "Gezinti ve boş durumlar"

    # 1 · Host ana sayfası → "Salon ara" → Keşfet katmanı: ana sayfa arkadan görünmez
    def salon_ara():
        e = Ekran(b, port, "arda")
        try:
            e.bekle(1500)
            e.pg.mouse.move(200, 500); e.pg.mouse.wheel(0, 1400); e.bekle(900)   # ana sayfa perdesi açılsın
            try:
                e.dokun_etiket("Misafir olarak host bul")   # host'ta aynı katmanı "Salon ara" açar
            except AssertionError:
                e.pg.mouse.wheel(0, -3000); e.bekle(800); e.dokun_etiket("Misafir olarak host bul")
            e.bekle(2500)
            e.foto("g1_salon_ara")
            # katmanın alt kenarı çubuğun 40pt arkasında mı (ana sayfa arada görünmesin)
            olcum = e.pg.evaluate("""() => {
              const bar = Array.from(document.querySelectorAll('[role=button]')).find(x => /^ana sayfa/i.test((x.getAttribute('aria-label') || x.innerText || '').trim()) && x.getBoundingClientRect().top > 600);
              let el = bar; while (el && el.parentElement && getComputedStyle(el).position !== 'absolute' && el.getBoundingClientRect().width < 380) el = el.parentElement;
              const ust = bar ? bar.getBoundingClientRect().top : null;
              const z = Array.from(document.querySelectorAll('div')).filter(d => getComputedStyle(d).zIndex === '50');
              const kat = z.length ? z[0].getBoundingClientRect() : null;
              return { kapsulUst: ust, katmanAlt: kat ? kat.bottom : null };
            }""")
            ok = olcum["katmanAlt"] is not None and olcum["kapsulUst"] is not None and olcum["katmanAlt"] >= olcum["kapsulUst"] - 30
            return ok, "katman alt=%s · çubuk düğmesi üst=%s" % (olcum["katmanAlt"], olcum["kapsulUst"])
        finally:
            e.kapat()
    _dene(k, B, "Ana sayfa (kaydırılmış) → Salon ara / Host bul → Keşfet katmanı çubuğa kadar iner, arada ana sayfa görünmez",
          "misafir", "edge", "Ana sayfa sızmaz", salon_ara)

    # 2 · Profil kaydırınca sağ üst düğme durum çubuğuna yapışmaz
    def profil_kaydir():
        e = Ekran(b, port, "arda")
        try:
            e.dokun("Profil"); e.bekle(1500)
            e.pg.mouse.move(200, 500); e.pg.mouse.wheel(0, 900); e.bekle(900); e.foto("g2_profil_kaydir")
            r = e.pg.evaluate("""() => Array.from(document.querySelectorAll('[aria-label]')).filter(x => /^ayarlar$/i.test(x.getAttribute('aria-label') || ''))
                .map(x => x.getBoundingClientRect()).filter(r => r.width && r.height && r.bottom > 0 && r.top < 120)
                .map(r => Math.round(r.top))""")
            # web'de durum çubuğu 0 → düğme kompakt çubuğun alt hizasında (üst > 20) olmalı
            return bool(r) and all(t > 20 for t in r), "kompakt çubuktaki Ayarlar üst kenarı: %s" % r
        finally:
            e.kapat()
    _dene(k, B, "Profil kaydırılınca Ayarlar düğmesi kompakt başlıkla aynı hizada (durum çubuğuna yapışmaz)",
          "misafir", "edge", "Hizalı", profil_kaydir)

    # 3 · Tanış › Uçuş boş: sekmeye özgü mesaj · seyahat yoksa Seyahat Ekle açılır
    def tanis_ucus():
        db("delete from visits where user_id=%s and visit_date >= current_date and not exists (select 1 from requests r where r.visit_id = visits.id)", (KIM["duru"],))
        has = db("select count(*) from visits where user_id=%s and visit_date >= current_date", (KIM["duru"],), tek=True)
        e = Ekran(b, port, "duru")
        try:
            e.dokun("Tanış"); e.bekle(1800)
            e.dokun("Uçuş"); e.bekle(1200)
            e.foto("g3_tanis_ucus")
            baslik = e.var("Uçuşunda henüz tanıdık yüz yok", 1500)
            tum = e.var("Tüm yolculara bak", 500)
            ekle = e.var("Seyahat Ekle", 500)
            iz = "seyahat=%s · başlık=%s · tümü düğmesi=%s · seyahat ekle=%s" % (has, baslik, tum, ekle)
            ok = baslik and tum and (ekle == (int(has) == 0))
            if int(has) == 0 and ekle:
                e.dokun("Seyahat Ekle"); e.bekle(1800); e.foto("g3b_seyahat_ekle")
                form = e.var("Havalimanı", 1500) or e.var("Seyahat", 300)
                iz += " · seyahat formu açıldı=%s" % form
                ok = ok and form
            return ok, iz
        finally:
            e.kapat()
    _dene(k, B, "Tanış › Uçuş boşken sekmeye özgü mesaj + 'Tüm yolculara bak' + (seyahat yoksa) Seyahat Ekle formu açılır",
          "misafir", "alternate", "Sekmeye özgü", tanis_ucus)

    # 4 · Bağlantılarım: "Tanış" yerine "Yeni yolcularla tanış"
    def baglantilarim():
        e = Ekran(b, port, "duru")
        try:
            e.dokun("Tanış"); e.bekle(1500)
            e.dokun("Bağlantılarım"); e.bekle(1500); e.foto("g4_baglantilarim")
            var = e.var("Yeni yolcularla tanış", 1500)
            if var:
                e.dokun("Yeni yolcularla tanış"); e.bekle(1200)
                ok = e.pg.get_by_placeholder("İsimle ara", exact=False).count() > 0
                return ok, "düğme var · Tanış listesi (arama kutusu) açıldı=%s" % ok
            return False, "düğme görünmedi (boş durum değil olabilir)"
        finally:
            e.kapat()
    _dene(k, B, "Bağlantılarım boşken 'Yeni yolcularla tanış' → Tanış listesine götürür",
          "misafir", "happy", "Doğru etiket", baglantilarim)
