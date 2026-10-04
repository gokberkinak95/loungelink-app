# -*- coding: utf-8 -*-
# PUANLAMA ANI (Gökberk md.1 · md.9) — kullanıcının yolu: Profil › Oturum Geçmişi (Geçmiş & Bağlantılar).
#  · Bağlantılar › Mesaj gönder (yalnız bağlantı sohbeti) → puanlama HİÇ çıkmaz
#  · Oturum › Sohbeti aç (puanlanmamış) → "Oturum tamamlandı" BİR KEZ çıkar; yeniden açınca çıkmaz
#  · Puanı Gönder → puan bir kez yazılır; sohbet yeniden açılınca puan istenmez
from akis_e2e import bolum, Ekran, db, KIM
from akis_e2e_bolumler import _dene

AN = "Oturum tamamlandı"


def _gecmis(e, sekme):
    e.dokun("Profil"); e.bekle(1200)
    e.dokun("Oturum Geçmişi"); e.bekle(1800)
    _sekme(e, sekme)


def _sekme(e, ad):
    e.pg.locator("[role=tab][aria-label='%s']" % ad).last.click(timeout=3000); e.bekle(900)


def _geri(e):
    try:
        e.dokun_etiket("Geri")
    except AssertionError:
        e.pg.keyboard.press("Escape")
    e.bekle(900)


def _puan_sayisi(kim):
    return db("select count(*) from ratings where rater_id=%s", (KIM[kim],), tek=True)


@bolum("puan")
def puan(b, port, k):
    B = "Sohbet ve oturum"

    def baglanti_sohbeti():
        e = Ekran(b, port, "arda")
        try:
            _gecmis(e, "Bağlantılar")
            e.dokun("Mesaj gönder", True, 0); e.bekle(2200)
            an = e.var(AN, 800) or e.var("Şimdi puanla", 300)
            return not an, "bağlantı sohbetinde puanlama anı=%s" % an
        finally:
            e.kapat()
    _dene(k, B, "Geçmiş & Bağlantılar › Bağlantılar › Mesaj gönder (yalnız bağlantı) → puanlama ekranı ÇIKMAZ", "misafir", "negative",
          "Puanlama yok", baglanti_sohbeti)

    def bir_kez_ve_puan():
        e = Ekran(b, port, "arda")
        try:
            _gecmis(e, "Oturum")
            n = len([x for x in e.dokunulabilirler() if x.lower().endswith("sohbeti aç")])
            ilk = None
            for i in range(n):
                e.dokun("Sohbeti aç", True, i); e.bekle(2200)
                if e.var(AN, 900):
                    ilk = i; break
                _geri(e)
                _sekme(e, "Oturum")
            if ilk is None:
                return False, "puanlanmamış oturumda an hiç çıkmadı (%d sohbet denendi)" % n
            iz = ["1. açılış: an çıktı"]
            e.dokun("Sohbete dön"); e.bekle(900)
            _geri(e)
            _sekme(e, "Oturum")
            e.dokun("Sohbeti aç", True, ilk); e.bekle(2200)
            tekrar = e.var(AN, 1000)
            iz.append("2. açılış: an=%s" % tekrar)
            # Puanla: sohbetteki puan paneli (yıldız radyo düğmeleri)
            r0 = _puan_sayisi("arda")
            if not e.pg.locator("[role=radio][aria-label='5']").count():
                for d in ("Oturumu puanla", "Şimdi puanla", "Puanla"):
                    try:
                        e.dokun(d, False); e.bekle(1000); break
                    except AssertionError:
                        continue
            e.pg.locator("[role=radio][aria-label='5']").last.click(timeout=3000); e.bekle(300)
            e.dokun("Puanı Gönder"); e.bekle(2500)
            r1 = _puan_sayisi("arda")
            iz.append("puan %s→%s (tek dokunuş)" % (r0, r1))
            _geri(e)
            _sekme(e, "Oturum")
            e.dokun("Sohbeti aç", True, ilk); e.bekle(2200)
            tekrar2 = e.var(AN, 1000) or e.var("Puanı Gönder", 300)
            iz.append("puandan sonra açılış: puan istendi=%s" % tekrar2)
            return (not tekrar and r1 == r0 + 1 and not tekrar2), " · ".join(iz)
        finally:
            e.kapat()
    _dene(k, B, "Oturum › Sohbeti aç: 'Oturum tamamlandı' BİR KEZ · Puanı Gönder tek dokunuşta yazar · sonra puan bir daha istenmez",
          "misafir", "edge", "Tek sefer", bir_kez_ve_puan)
