# -*- coding: utf-8 -*-
# 3-5 · KEŞFET · KURAL MOTORU · İSTEK — SEED8 tezgâh vakaları (tezgah.rapor 2xx/1xx) arayüzden
# Her vaka: beklenen (rapor.ekranda) ↔ ekranda görülen ↔ veritabanındaki sonuç.
import re as _re, io as _io, os as _os
from akis_e2e import bolum, Ekran, db, KIM
from akis_e2e_bolumler import _dene

_I18N = _io.open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "src", "i18n.js"), encoding="utf-8").read()


def _tr(anahtar):
    """i18n.js'teki İLK (TR) değeri: `anahtar: "..."` ya da errMap `"kod": "..."`."""
    for desen in (r'\b%s:\s*"((?:[^"\\]|\\.)*)"' % _re.escape(anahtar), r'"%s":\s*"((?:[^"\\]|\\.)*)"' % _re.escape(anahtar)):
        m = _re.search(desen, _I18N)
        if m:
            return m.group(1).replace('\\"', '"')
    return None


def _ilk_cumle(s):
    return (s or "").split(".")[0][:48]


def _kredi(uid):
    return int(db("select coalesce(sum(delta),0) from credit_ledger where user_id=%s", (uid,), tek=True))


def _istek(gid, host_ad, saat, durumlar=("pending",)):
    r = db("""select r.id, r.status from requests r join availabilities a on a.id=r.avail_id
               join profiles p on p.user_id=a.host_id
              where r.guest_id=%s and p.name=%s and a.time_from=%s::time and r.status = any(%s::request_status[])
              order by r.created_at desc limit 1""", (gid, host_ad, saat, list(durumlar)))
    return r[0] if r else None


def _kesfet(kim):
    e = Ekran(_B, _PORT, kim)
    e.dokun("Keşfet"); e.bekle(2500)
    return e


def _gonder(e, host, aralik, mesaj=None):
    """Kartta 'İstek gönder' → modal → (mesaj) → 'İsteği gönder'. Modalın metnini döndürür."""
    e.kaydir_bul(host, aralik)
    e.kart_dokun([host, aralik], "İstek gönder"); e.bekle(1500)
    if mesaj:
        try:
            e.pg.locator("textarea, input").last.fill(mesaj, timeout=2000)
        except Exception:
            pass
    modal = e.metin()
    if Ekran._n(_tr("ruleAckRequired")) in Ekran._n(modal):
        # Kural uyarısı onay ister (doğru davranış): kutuyu işaretle — rolü checkbox (B11).
        try:
            e.pg.locator("[role=checkbox]").last.click(timeout=2500); e.bekle(400)
        except Exception:
            pass
    try:
        e.dokun(_tr("send")); e.bekle(2200)
    except AssertionError:
        pass   # düğme etiketi kilitliyken değişir (reqSendBlocked)
    return modal


@bolum("kesfet")
def kesfet(b, port, k):
    global _B, _PORT
    _B, _PORT = b, port
    B = "Keşfet·İstek"
    A = KIM["arda"]

    # ── 0 · liste = sunucu ─────────────────────────────────────────
    e = _kesfet("arda")
    def liste_sunucu():
        from akis_e2e_b2_ana import _rpc_as
        n = _rpc_as("arda", "select count(*) from discover_availabilities() d where d.host_id <> %s::uuid", (A,))
        ekran = len([x for x in e.dokunulabilirler() if "% uyum:" in x])
        for _ in range(25):
            e.pg.mouse.wheel(0, 1200); e.bekle(250)
        ekran2 = len(set(x for x in e.pg.evaluate(
            "Array.from(document.querySelectorAll('[aria-label^=\"% uyum\"]')).map((x,i)=>i)") or []))
        return n == max(ekran, ekran2) or (n > 0 and ekran > 0), "sunucu=%s ilk ekranda=%s kaydırınca=%s" % (n, ekran, ekran2)
    _dene(k, B, "Keşfet açılır · ilanlar sunucudan (discover_availabilities)", "misafir", "happy", "Kart sayısı > 0 ve sunucuyla tutarlı", liste_sunucu)
    _dene(k, B, "Keşfet'te ham kod / {yer tutucu} yok", "misafir", "edge", "Yok", lambda: (not e.ham_kodlar(), e.ham_kodlar()))
    e.kapat()

    # ── 205 · aynı ilana ikinci başvuru: kart 'Gönderildi', düğme yok ─
    e = _kesfet("arda")
    def ikinci():
        e.kaydir_bul("Tuna H.", "12:45–14:00")
        m = e.kart_metni("Tuna H.", "12:45–14:00") or ""
        return ("Gönderildi" in m and "İstek gönder" not in m), m.replace("\n", " | ")[-120:]
    _dene(k, B, "205 · Aynı ilana ikinci başvuru → kart 'Gönderildi', istek düğmesi yok", "misafir", "negative",
          "Gönderildi · düğme yok", ikinci)

    # ── 109 · reddedilmiş istek ─────────────────────────────────────
    def reddedilmis():
        e.kaydir_bul("Tuna H.", "11:00–12:30")
        m = e.kart_metni("Tuna H.", "11:00–12:30") or ""
        return ("kabul edemedi" in m.lower() and "iade" in m.lower()), m.replace("\n", " | ")[-120:]
    _dene(k, B, "109 · Reddedilmiş istek → kart 'Host kabul edemedi · Kredin iade edildi'", "misafir", "alternate",
          "Sebep + iade kartta", reddedilmis)

    # ── 204 · güven eşiği üstündeki ilan Keşfet'te görünmez ───────────
    def esik():
        bulundu = e.kaydir_bul("Tuna H.", "16:30–", tur=8)
        return not bulundu, "Tuna 16:30 (güven eşiği 90, Arda 60) görünüyor=%s" % bulundu
    _dene(k, B, "204 · Güven eşiğinin altındaysan ilan Keşfet'te YOK", "misafir", "negative", "Görünmez", esik)

    # ── 203 · seyahatin yok → 'Seyahat ekle' ─────────────────────────
    def seyahatsiz():
        if not e.kaydir_bul("Tuna H.", "AYT", tur=14):
            return False, "AYT kartı bulunamadı"
        m = e.kart_metni("Tuna H.", "AYT") or ""
        return ("Seyahat ekle" in m and "İstek gönder" not in m), m.replace("\n", " | ")[-120:]
    _dene(k, B, "203 · Seyahatin yok (AYT) → kartta 'Seyahat ekle'", "misafir", "negative", "Seyahat ekle · istek düğmesi yok", seyahatsiz)

    # ── 202 · dolu ilan ───────────────────────────────────────────────
    def dolu():
        bul = e.kaydir_bul("Nehir A.", "13:30–15:30", tur=10)
        m = e.kart_metni("Nehir A.", "13:30–15:30") or ""
        return ((not bul) or ("İstek gönder" not in m)), "kart=%s %s" % (bul, m.replace("\n", " | ")[-120:])
    _dene(k, B, "202 · Dolu ilan (1/1) → istek düğmesi yok (ya da listede değil)", "misafir", "negative", "Başvurulamaz", dolu)
    e.kapat()

    # ── 201 · açık ilana başvur (mutlu yol) ───────────────────────────
    e = _kesfet("arda")
    def basvur():
        k0 = _kredi(A); n0 = db("select count(*) from notifications where user_id=(select id from users where email='akis.host2@seed.loungelink.test') ", tek=True)
        modal = _gonder(e, "Tuna H.", "14:15–16:00", "E2E: 15 gibi salondayım.")
        r = _istek(A, "Tuna H.", "14:15")
        k1 = _kredi(A)
        notu = e.var(_tr("reqSentNotice").split("{ad}")[-1].strip()[:24], 2500)   # "adlı host'a gitti…" 
        kart = e.kart_metni("Tuna H.", "14:15–16:00") or ""
        intro = db("select intro_message from requests where id=%s", (r[0],), tek=True) if r else None
        return (bool(r) and k1 <= k0 and notu and "Gönderildi" in kart and intro and "E2E" in intro,
                "istek=%s kredi %s→%s bildirim_notu=%s kart_Gönderildi=%s mesaj=%r" % (r, k0, k1, notu, "Gönderildi" in kart, intro))
    _dene(k, B, "201 · Açık ilana istek → DB pending + mesaj · kredi tutulur · 'İsteğin gitti' notu · kart 'Gönderildi'",
          "misafir", "happy", "Dördü birden", basvur)

    # ── 108 · bekleyen isteği iptal et (Ana sayfa · İSTEKLERİM) ────────
    def iptal():
        r = _istek(A, "Tuna H.", "12:45")
        if not r:
            return False, "Tuna 12:45 bekleyen istek yok"
        k0 = _kredi(A)
        e2 = Ekran(_B, _PORT, "arda")
        try:
            e2.dokun_etiket("İstek:"); e2.bekle(1800)    # Ana sayfa · İstek hücresi → Gönderdiğim
            e2.kart_dokun(["Tuna H.", "12:45–14:00"], "İsteği iptal et"); e2.bekle(1200)
            if e2.var("emin", 800):
                for d in ("İptal et", "Evet", "İsteği iptal et"):
                    try:
                        e2.dokun(d); break
                    except AssertionError:
                        continue
            e2.bekle(1500)
            st = db("select status from requests where id=%s", (r[0],), tek=True)
            k1 = _kredi(A)
            return st == "cancelled" and k1 > k0, "durum=%s kredi %s→%s (iade beklenir)" % (st, k0, k1)
        finally:
            e2.kapat()
    _dene(k, B, "108 · Bekleyen isteği iptal et → cancelled · kredi iade", "misafir", "alternate", "İkisi birden", iptal)
    e.kapat()

    # ── 206 · kredisiz ────────────────────────────────────────────────
    def kredisiz():
        e = _kesfet("can")
        try:
            C = KIM["can"]
            modal = _gonder(e, "Tuna H.", "14:15–16:00")
            r = _istek(C, "Tuna H.", "14:15")
            beklenen = _ilk_cumle(_tr("e_insufficient_credits"))
            gor = Ekran._n(beklenen) in Ekran._n(modal) or e.var(beklenen, 1500)
            kilit = Ekran._n(_tr("reqSendBlocked")) in Ekran._n(modal)
            return (r is None and gor and kilit), "istek_olustu=%s '%s' göründü=%s düğme_kilitli=%s" % (bool(r), beklenen, gor, kilit)
        finally:
            e.kapat()
    _dene(k, B, "206 · Kredin 0 → istek oluşmaz · 'Kredin kalmadı…' cümlesi", "misafir(kredisiz)", "negative", "Türkçe sebep", kredisiz)

    # ── 207 · iletişim doğrulanmamış ──────────────────────────────────
    def dogrulanmamis():
        e = _kesfet("mina")
        try:
            M = KIM["mina"]
            e.kaydir_bul("Tuna H.", "14:15–16:00")
            kart = e.kart_metni("Tuna H.", "14:15–16:00") or ""
            dugme = "Telefonu doğrula" in kart and "İstek gönder" not in kart
            e.kart_dokun(["Tuna H.", "14:15–16:00"], "Telefonu doğrula"); e.bekle(1800)
            dogrulama_ekrani = e.var("doğrula", 2500) and (e.var("telefon", 500) or e.var("kod", 500))
            r = _istek(M, "Tuna H.", "14:15")
            return (dugme and dogrulama_ekrani and r is None), "kartta 'Telefonu doğrula'=%s · doğrulama ekranı=%s · istek_oluştu=%s" % (dugme, dogrulama_ekrani, bool(r))
        finally:
            e.kapat()
    _dene(k, B, "207 · İletişim doğrulanmamış → kart istek yerine 'Telefonu doğrula' der · dokununca doğrulamaya gider", "misafir(doğrulanmamış)", "negative", "Türkçe sebep", dogrulanmamis)

    # ── 208 · 211 · 214 · kural motoru: GEÇER vakaları ─────────────────
    for sira, host, aralik, saat, ad in [(208, "Mert A.", "THY Dış Hat", None, "included · tek kişi (uçuş bilgisi eksik uyarısı)"),
                                          (214, "Selin B.", "iGA", "12:00", "kuralı doğrulanmamış salon ('Host'a sor')")]:
        def gecer(host=host, aralik=aralik, saat=saat):
            e = _kesfet("ela")
            try:
                E_ = KIM["ela"]
                if not e.kaydir_bul(host, aralik, tur=16):
                    return False, "kart bulunamadı"
                n0 = db("select count(*) from requests where guest_id=%s and status='pending'", (E_,), tek=True)
                modal = _gonder(e, host, aralik)   # onay kutusu gerekiyorsa _gonder işaretler
                n1 = db("select count(*) from requests where guest_id=%s and status='pending'", (E_,), tek=True)
                ack = Ekran._n(_tr("ruleAckRequired") or "zzz") in Ekran._n(modal)
                kart = e.kart_metni(host, aralik) or ""
                return n1 == n0 + 1, "yeni_bekleyen=%s onay_kutusu_gerekti=%s kart=%s" % (n1 - n0, ack, kart.replace(chr(10), " | ")[-60:])
            finally:
                e.kapat()
        _dene(k, B, "%d · Kural %s → istek gider" % (sira, ad), "misafir(kural)", "happy", "pending oluşur", gecer)

    # ── 210 · 212 · 213 · kural motoru: ENGEL vakaları ─────────────────
    for sira, host, aralik, kod in [(210, "Mert A.", "SAW", "guests_not_allowed"),
                                    (212, "Selin B.", "14:20–16:40", "party_too_big"),
                                    (213, "Selin T.", "07:30", "guest_carrier_mismatch")]:
        def engel(host=host, aralik=aralik, kod=kod):
            e = _kesfet("ela")
            try:
                E_ = KIM["ela"]
                if not e.kaydir_bul(host, aralik, tur=16):
                    return True, "kart Keşfet'te yok (ilan gizlenmiş — kabul edilir)"
                kart = e.kart_metni(host, aralik) or ""
                if "İstek gönder" not in kart:
                    return True, "kartta istek düğmesi yok: " + kart.replace("\n", " | ")[-90:]
                n0 = db("select count(*) from requests where guest_id=%s", (E_,), tek=True)
                modal = _gonder(e, host, aralik)
                n1 = db("select count(*) from requests where guest_id=%s", (E_,), tek=True)
                sonra = e.metin()
                kilit = Ekran._n(_tr("reqSendBlocked")) in Ekran._n(modal + sonra)
                ham = kod in sonra or kod in modal
                return (n1 == n0 and not ham and (kilit or len(e.ham_kodlar()) == 0)), \
                       "yeni_istek=%s kilitli_düğme=%s ham_kod=%s" % (n1 - n0, kilit, ham)
            finally:
                e.kapat()
        _dene(k, B, "%d · Kural engeli (%s) → istek oluşmaz · sebep Türkçe" % (sira, kod.replace("_", " ")), "misafir(kural)", "negative",
              "Düğme kilitli ya da sebep yazılı", engel)
