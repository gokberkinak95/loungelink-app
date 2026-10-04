# -*- coding: utf-8 -*-
# 5-10 · İŞ KURALLARI (BE) — kullanıcı ADINA (RLS + auth.uid), uçtan uca zincirler.
# Her senaryo TEK işlemde koşar ve sonunda GERİ ALINIR: dünya kirlenmez, sıra bağımlılığı yok.
# Ekrandaki karşılıkları (rozet, kart, bildirim metni) diğer bölümler arayüzden ölçer;
# burası "sunucu doğru şeyi yapıyor mu" sorusunu her yan etkisiyle (kredi · slot · bildirim ·
# görünürlük) cevaplar. Hata kodlarının Türkçe karşılığı da burada sınanır.
import json as _json, re as _re, io as _io, os as _os, datetime as _dt
import psycopg2
from akis_e2e import bolum, KIM, DSN, db
from akis_e2e_bolumler import _dene

_I18N = _io.open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "src", "i18n.js"), encoding="utf-8").read()


def _cevirisi_var(kod):
    return len(_re.findall(r'(?:\be_%s\b\s*:|"%s"\s*:)' % (_re.escape(kod), _re.escape(kod)), _I18N)) >= 2


class Is:
    """Tek işlem; kimlik değiştirerek adım adım. Her çağrı bir savepoint içinde (hata işlemi bozmaz)."""
    def __init__(self):
        self.c = psycopg2.connect(**DSN); self.cur = self.c.cursor(); self.n = 0
        self.cur.execute("set timezone = 'Europe/Istanbul'")

    def ol(self, kim):
        self.cur.execute("reset role")
        self.cur.execute("select set_config('request.jwt.claims', %s, true)", (_json.dumps({"sub": KIM[kim], "role": "authenticated"}),))
        self.cur.execute("set local role authenticated")

    def cagir(self, sql, args=()):
        self.n += 1; sp = "s%d" % self.n
        self.cur.execute("savepoint " + sp)
        try:
            self.cur.execute(sql, args)
            r = self.cur.fetchone() if self.cur.description else None
            self.cur.execute("release savepoint " + sp)
            return (r[0] if r and len(r) == 1 else r), None
        except Exception as e:
            self.cur.execute("rollback to savepoint " + sp)
            return None, str(e).splitlines()[0].strip()

    def q(self, sql, args=(), tek=True):
        """Süper kullanıcı gözüyle doğrulama (aynı işlem içinde)."""
        self.cur.execute("reset role")
        self.cur.execute(sql, args)
        r = self.cur.fetchall()
        return (r[0][0] if r and r[0] else None) if tek else r

    def bitir(self):
        try:
            self.c.rollback()
        finally:
            self.c.close()


def _kredi(s, kim):
    return int(s.q("select coalesce(sum(delta),0) from credit_ledger where user_id=%s", (KIM[kim],)))


def _bildirim(s, kim):
    return int(s.q("select count(*) from notifications where user_id=%s", (KIM[kim],)))


def _salon(s):
    return s.q("select id from lounges where airport_code='IST' and active order by name limit 1")


def _simdi(s):
    return s.q("select (now() at time zone 'Europe/Istanbul')")


def _pencere(s, once_dk=30, sonra_dk=90):
    t = _simdi(s)
    a = (t - _dt.timedelta(minutes=once_dk)); b = (t + _dt.timedelta(minutes=sonra_dk))
    if a.date() != t.date() or b.date() != t.date():   # gece yarısı sınırı: yarına 10:00-12:00
        g = t.date() + _dt.timedelta(days=1); return g, _dt.time(10, 0), _dt.time(12, 0), False
    return t.date(), a.time().replace(second=0, microsecond=0), b.time().replace(second=0, microsecond=0), True


def _ilan_ve_seyahat(s, host="nehir", misafir="arda", slots=1, gun=None, bas=None, son=None):
    if gun is None:
        gun, bas, son, _ = _pencere(s)
    s.ol(host)
    aid, h = s.cagir("select (create_availability(%s,'IST',%s,%s,%s,%s)->>'id')::uuid", (_salon(s), gun, bas, son, slots))
    if h:
        aid2, h2 = s.cagir("select create_availability(%s,'IST',%s,%s,%s,%s)::text", (_salon(s), gun, bas, son, slots))
        raise AssertionError("ilan açılamadı: %s / %s" % (h, aid2 or h2))
    if misafir:
        s.ol(misafir)
        _, h = s.cagir("select seyahat_ekle('IST',%s,%s,%s)", (gun, bas, son))
        if h and "overlap" not in h and "zaten" not in h and "trip_exists" not in h:
            pass   # misafirin o saatte seyahati zaten olabilir — create_request karar verir
    return aid, gun, bas, son


@bolum("kurallar")
def kurallar(b, port, k):
    B = "İş kuralları (BE)"

    # ── 1 · tam yaşam döngüsü: ilan → istek → kabul → başlat → tamamla → puan ───────────
    def dongu():
        s = Is(); iz = []
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s)
            s.ol("arda"); gor = s.cagir("select count(*) from discover_availabilities('IST') where id=%s", (aid,))[0]
            iz.append("keşifte=%s" % gor)
            k0, nb0 = _kredi(s, "arda"), _bildirim(s, "nehir")
            r, h = s.cagir("select create_request(%s,'lounge','e2e')::text", (aid,))
            rid = s.q("select id from requests where guest_id=%s and avail_id=%s and status='pending'", (KIM["arda"], aid))
            iz.append("istek=%s hata=%s kredi %s→%s host_bildirim %s→%s" % (bool(rid), h, k0, _kredi(s, "arda"), nb0, _bildirim(s, "nehir")))
            if not rid:
                return False, " · ".join(iz)
            s.ol("nehir"); _, h = s.cagir("select respond_request(%s,'accept')::text", (rid,))
            st = s.q("select status from requests where id=%s", (rid,)); dolu = s.q("select filled from availabilities where id=%s", (aid,))
            kanal = s.q("select count(*) from chat_channels where request_id=%s", (rid,))
            iz.append("kabul=%s hata=%s dolu=%s kanal=%s" % (st, h, dolu, kanal))
            s.ol("arda"); _, h1 = s.cagir("select start_session_request(%s)::text", (rid,))
            s.ol("nehir"); _, h2 = s.cagir("select start_session_request(%s)::text", (rid,))
            sid = s.q("select id from sessions where request_id=%s", (rid,)); sst = s.q("select status from sessions where request_id=%s", (rid,))
            iz.append("başlat=%s (%s/%s)" % (sst, h1, h2))
            s.ol("arda"); _, h3 = s.cagir("select confirm_session(%s)::text", (sid,))
            s.ol("nehir"); _, h4 = s.cagir("select confirm_session(%s)::text", (sid,))
            sst2 = s.q("select status from sessions where id=%s", (sid,)); rst2 = s.q("select status from requests where id=%s", (rid,))
            puan = s.q("select coalesce(sum(delta),0) from points_ledger where user_id=%s and created_at > now() - interval '1 minute'", (KIM["nehir"],))
            iz.append("tamamla=%s/%s (%s/%s) host_puan=+%s" % (sst2, rst2, h3, h4, puan))
            s.ol("arda"); _, h5 = s.cagir("select rate_session(%s,5,'e2e harika')::text", (sid,))
            s.ol("nehir"); _, h6 = s.cagir("select rate_session(%s,5,null)::text", (sid,))
            n_puan = s.q("select count(*) from ratings where session_id=%s", (sid,))
            iz.append("puanlama=%s (%s/%s)" % (n_puan, h5, h6))
            ok = gor == 1 and rid and st == "accepted" and dolu == 1 and kanal == 1 and sst in ("active", "pending") \
                 and sst2 == "completed" and rst2 == "completed" and n_puan == 2
            return ok, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Tam döngü: ilan → keşifte görünür → istek (kredi tutulur, host'a bildirim) → kabul (slot, sohbet) → iki taraf başlat → iki taraf tamamla → iki yönlü puan",
          "host+misafir", "happy", "Her adımın yan etkisi doğru", dongu)

    # ── 2 · ilan doğrulamaları ─────────────────────────────────────────
    def ilan_negatif():
        s = Is(); sonuc = []
        try:
            s.ol("nehir"); L = _salon(s); bugun = _simdi(s).date()
            g9 = bugun + _dt.timedelta(days=9)
            vakalar = [("geçmiş tarih", (L, bugun - _dt.timedelta(days=1), _dt.time(3, 10), _dt.time(4, 40), 1)),
                       ("bitiş ≤ başlangıç", (L, g9, _dt.time(4, 40), _dt.time(3, 10), 1)),
                       ("0 kişilik", (L, g9, _dt.time(3, 10), _dt.time(4, 40), 0)),
                       ("aşırı kişi (50)", (L, g9, _dt.time(3, 10), _dt.time(4, 40), 50))]
            ok = True
            for ad, a in vakalar:
                _, h = s.cagir("select create_availability(%s,'IST',%s,%s,%s,%s)::text", a)
                kod = (h or "").split(":")[-1].strip().split(" ")[0] if h else None
                cev = _cevirisi_var(kod) if kod else None
                sonuc.append("%s→%s%s" % (ad, kod or "KABUL EDİLDİ", "" if not kod else ("✓TR/EN" if cev else "✗çeviri")))
                ok = ok and bool(h) and bool(cev)
            return ok, " · ".join(sonuc)
        finally:
            s.bitir()
    _dene(k, B, "İlan aç: geçmiş tarih / ters saat / 0 kişi / 50 kişi → reddedilir · her kodun TR+EN cümlesi var",
          "host", "negative", "Hepsi reddedilir, çeviri var", ilan_negatif)

    # ── 3 · seyahat doğrulamaları ──────────────────────────────────────
    def seyahat_negatif():
        s = Is(); sonuc = []
        try:
            s.ol("arda"); bugun = _simdi(s).date(); g = bugun + _dt.timedelta(days=20)
            _, h0 = s.cagir("select seyahat_ekle('IST',%s,'10:00','12:00')", (g,))
            sonuc.append("mutlu→%s" % ("OK" if not h0 else h0))
            vakalar = [("geçmiş tarih", ("IST", bugun - _dt.timedelta(days=1), "10:00", "12:00")),
                       ("ters saat", ("IST", g + _dt.timedelta(days=1), "12:00", "10:00")),
                       ("bilinmeyen havalimanı", ("ZZZ", g, "10:00", "12:00")),
                       ("aynı havalimanında çakışan saat", ("IST", g, "11:00", "13:00"))]
            ok = not h0
            for ad, a in vakalar:
                _, h = s.cagir("select seyahat_ekle(%s,%s,%s,%s)", a)
                kod = h.split(":")[-1].strip().split(" ")[0] if h else None
                cev = _cevirisi_var(kod) if kod else None
                sonuc.append("%s→%s%s" % (ad, kod or "KABUL EDİLDİ", "" if not kod else ("✓TR/EN" if cev else "✗çeviri")))
                ok = ok and bool(h) and bool(cev)
            vid = s.q("select id from visits where user_id=%s and visit_date=%s and airport_code='IST'", (KIM["arda"], g))
            s.ol("arda"); _, hu = s.cagir("select update_visit(%s, null, null, null, '10:30', '12:30')::text", (vid,))
            yeni = s.q("select time_from::text from visits where id=%s", (vid,))
            s.ol("arda"); _, hs = s.cagir("select seyahat_sil(%s)::text", (vid,))
            kaldi = s.q("select count(*) from visits where id=%s", (vid,))
            sonuc.append("düzenle→%s(%s) sil→%s" % (yeni, hu or "OK", "silindi" if kaldi == 0 else "DURUYOR %s" % hs))
            # B15 · SQL 325: başka havalimanında aynı saat REDDEDİLİR; aktarmalı (örtüşmeyen) aynı gün kabul
            s.ol("arda"); g2 = g + _dt.timedelta(days=3)
            s.cagir("select seyahat_ekle('IST',%s,'10:00','12:00')", (g2,))
            _, hx = s.cagir("select seyahat_ekle('SAW',%s,'11:00','13:00')", (g2,))
            _, hy = s.cagir("select seyahat_ekle('ESB',%s,'15:00','17:00')", (g2,))
            vy = s.q("select id from visits where user_id=%s and visit_date=%s and airport_code='ESB'", (KIM["arda"], g2))
            s.ol("arda"); _, hz = s.cagir("select update_visit(%s, null, null, null, '11:00', '13:00')::text", (vy,))
            kx = (hx or "").split(":")[-1].strip().split(" ")[0]; kz = (hz or "").split(":")[-1].strip().split(" ")[0]
            sonuc.append("başka havalimanı aynı saat→%s%s · aktarmalı ESB 15–17→%s · düzenleyip çakıştır→%s%s" % (
                kx or "KABUL!", "✓TR/EN" if kx and _cevirisi_var(kx) else "", hy or "OK", kz or "KABUL!", "✓TR/EN" if kz and _cevirisi_var(kz) else ""))
            b15 = bool(hx) and _cevirisi_var(kx) and not hy and bool(hz) and _cevirisi_var(kz)
            return ok and yeni == "10:30:00" and kaldi == 0 and b15, " · ".join(sonuc)
        finally:
            s.bitir()
    _dene(k, B, "Seyahat: ekle / düzenle / sil + geçmiş tarih · ters saat · bilinmeyen havalimanı · çakışan saat (aynı ve FARKLI havalimanı, düzenlemede de · B15) reddedilir · aktarmalı gün kabul",
          "misafir", "edge", "Kurallar sunucuda", seyahat_negatif)

    # ── 4 · host ilanı kaldırır: bekleyen + kabul edilmiş misafir ─────────
    def ilan_kaldir():
        s = Is(); iz = []
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, slots=2, gun=_simdi(s).date() + _dt.timedelta(days=11), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("duru"); s.cagir("select seyahat_ekle('IST',%s,'16:10','17:50')", (gun,))
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            s.ol("duru"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            ra = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            rd = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["duru"]))
            if not (ra and rd):
                return False, "iki istek kurulamadı arda=%s duru=%s" % (ra, rd)
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (ra,))
            ka, kd = _kredi(s, "arda"), _kredi(s, "duru"); ba, bd = _bildirim(s, "arda"), _bildirim(s, "duru")
            s.ol("nehir"); _, h1 = s.cagir("select cancel_availability(%s, false)::text", (aid,))
            iz.append("zorlamadan=%s" % (h1 or "kaldırıldı"))
            if not h1:
                aktif = s.q("select active from availabilities where id=%s", (aid,))
            else:
                _, h2 = s.cagir("select cancel_availability(%s, true)::text", (aid,))
                iz.append("zorla=%s" % (h2 or "kaldırıldı"))
                aktif = s.q("select active from availabilities where id=%s", (aid,))
            sa, sd = s.q("select status from requests where id=%s", (ra,)), s.q("select status from requests where id=%s", (rd,))
            ka2, kd2 = _kredi(s, "arda"), _kredi(s, "duru"); ba2, bd2 = _bildirim(s, "arda"), _bildirim(s, "duru")
            iz.append("ilan_aktif=%s kabul_edilen=%s bekleyen=%s iade arda %s→%s duru %s→%s bildirim arda %s→%s duru %s→%s"
                      % (aktif, sa, sd, ka, ka2, kd, kd2, ba, ba2, bd, bd2))
            if h1:
                iz.append("kod=%s çeviri=%s" % (h1.split(":")[-1].strip(), _cevirisi_var(h1.split(":")[-1].strip().split(" ")[0])))
            kod_ok = (not h1) or _cevirisi_var(h1.split(":")[-1].strip().split(" ")[0])
            ok = (aktif is False and sa in ("cancelled", "declined") and sd in ("cancelled", "declined") and ka2 > ka and kd2 > kd
                  and ba2 > ba and bd2 > bd and kod_ok)
            return ok, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Host ilanı kaldırır (1 kabul + 1 bekleyen) → ilan kapanır · iki istek kapanır · ikisine kredi iadesi + bildirim",
          "host", "alternate", "Kimse kredisini kaybetmez, herkes haber alır", ilan_kaldir)

    # ── 5 · kabulü geri al / misafir iptal / host reddi ───────────────────
    def geri_al():
        s = Is(); iz = []
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, gun=_simdi(s).date() + _dt.timedelta(days=12), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            k0 = _kredi(s, "arda")
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (rid,))
            d1 = s.q("select filled from availabilities where id=%s", (aid,))
            s.ol("nehir"); _, h = s.cagir("select respond_request(%s,'decline')::text", (rid,))
            st = s.q("select status from requests where id=%s", (rid,)); d2 = s.q("select filled from availabilities where id=%s", (aid,))
            k1 = _kredi(s, "arda")
            son_b = s.q("select string_agg(title, ' | ') from notifications where user_id=%s and created_at = now() and ref_id=%s", (KIM["arda"], rid))
            iz.append("kabul→dolu=%s · geri_al=%s(%s) dolu=%s kredi %s→%s · bildirim=%r" % (d1, st, h or "OK", d2, k0, k1, son_b))
            return st == "declined" and d1 == 1 and d2 == 0 and k1 > k0 and son_b and "geri" in son_b.lower(), " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Host kabulü geri alır → istek kapanır · slot boşalır · misafire iade + 'kabulü geri aldı' bildirimi",
          "host", "alternate", "Slot ve kredi geri döner", geri_al)

    # ── 6 · aynı ilana ikinci istek · kendi ilanına istek · dolu ilan ─────
    def istek_kapilari():
        s = Is(); iz = []
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, gun=_simdi(s).date() + _dt.timedelta(days=13), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("arda"); _, h1 = s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            _, h2 = s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            s.ol("nehir"); _, h3 = s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (rid,))
            s.ol("duru"); s.cagir("select seyahat_ekle('IST',%s,'16:10','17:50')", (gun,)); _, h4 = s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            kodlar = [(x or "KABUL").split(":")[-1].strip().split(" ")[0] for x in (h2, h3, h4)]
            iz.append("ilk=%s · ikinci=%s · kendi ilanı=%s · dolu ilan=%s" % (h1 or "OK", *kodlar))
            cev = all(_cevirisi_var(x) for x in kodlar if x != "KABUL")
            return (not h1) and all(x != "KABUL" for x in kodlar) and cev, " · ".join(iz) + " · çeviriler=%s" % cev
        finally:
            s.bitir()
    _dene(k, B, "İstek kapıları: aynı ilana ikinci istek · kendi ilanına istek · dolu ilan → reddedilir, Türkçe sebep",
          "misafir", "negative", "Üçü de reddedilir", istek_kapilari)

    # ── 7 · bağlantı: gönder → kabul → kaldır ─────────────────────────────
    def baglanti():
        s = Is(); iz = []
        try:
            hedef = next(k_ for k_ in ("ela", "mina", "can", "ece", "mert", "selen", "duru") if not s.q(
                "select count(*) from connection_requests where (from_id=%s and to_id=%s) or (from_id=%s and to_id=%s)",
                (KIM["arda"], KIM[k_], KIM[k_], KIM["arda"])))
            nb0 = _bildirim(s, hedef)
            s.ol("arda"); r, h = s.cagir("select send_connection(%s,'coffee','e2e merhaba')::text", (KIM[hedef],))
            cid = s.q("select id from connection_requests where from_id=%s and to_id=%s order by created_at desc limit 1", (KIM["arda"], KIM[hedef]))
            nb = _bildirim(s, hedef) - nb0
            iz.append("hedef=%s" % hedef)
            iz.append("gönder=%s bildirim=%s" % (h or "OK", nb))
            if not cid:
                return False, " · ".join(iz)
            s.ol(hedef); _, h2 = s.cagir("select respond_connection(%s,true)::text", (cid,))
            s.ol("arda"); bag = s.cagir("select count(*) from my_connections() m where m.other_id=%s and m.status='accepted'", (KIM[hedef],))
            iz.append("kabul=%s listede=%s" % (h2 or "OK", bag))
            s.ol("arda"); _, h3 = s.cagir("select baglanti_kaldir(%s)::text", (cid,))
            bag2 = s.cagir("select count(*) from my_connections() m where m.other_id=%s and m.status='accepted'", (KIM[hedef],))
            iz.append("kaldır=%s listede=%s" % (h3 or "OK", bag2))
            return (not h) and nb >= 1 and (not h2) and bag[0] == 1 and (not h3) and bag2[0] == 0, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Bağlantı: gönder (karşıya bildirim) → kabul (Bağlantılarım'da) → kaldır (listeden düşer)",
          "misafir", "happy", "Üç adım", baglanti)

    # ── 8 · engelle: her yüzeyden kaybolur, geri alınınca döner ───────────
    def engel():
        s = Is(); iz = []
        try:
            s.ol("arda")
            def yuzey():
                ilan = s.cagir("select count(*) from discover_availabilities() d where d.host_id=%s", (KIM["tuna"],))[0]
                kisi = s.cagir("select count(*) from discover_people(null, null) p where p.user_id=%s", (KIM["tuna"],))[0]
                ara = s.cagir("select count(*) from kisi_ara('Tuna') x where x.user_id=%s", (KIM["tuna"],))[0]
                return ilan, kisi, ara
            once = yuzey()
            _, h = s.cagir("select engelle(%s,'e2e')::text", (KIM["tuna"],))
            sonra = yuzey()
            s.ol("tuna"); ters = s.cagir("select count(*) from discover_people(null, null) p where p.user_id=%s", (KIM["arda"],))[0]
            _, hb = s.cagir("select send_connection(%s,'coffee','x')::text", (KIM["arda"],))
            s.ol("arda"); _, h2 = s.cagir("select engeli_kaldir(%s)::text", (KIM["tuna"],))
            geri = yuzey()
            iz.append("önce ilan/kişi/arama=%s · engel=%s sonra=%s · Tuna'dan Arda görünür=%s · Tuna→Arda bağlantı=%s · kaldır=%s geri=%s"
                      % (once, h or "OK", sonra, ters, (hb or "GİTTİ").split(":")[-1].strip(), h2 or "OK", geri))
            return (once[0] > 0 and sonra == (0, 0, 0) and ters == 0 and hb and geri[0] == once[0]), " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Engelle: ilanları · Tanış · arama İKİ YÖNLÜ kaybolur, bağlantı isteği gönderilemez · kaldırınca geri gelir",
          "misafir", "negative", "Güvenlik özelliği gerçekten korur", engel)

    # ── 9 · şikâyet → BO kuyruğu ──────────────────────────────────────────
    def sikayet():
        s = Is()
        try:
            s.ol("duru"); r, h = s.cagir("select create_report(%s,'harassment','e2e şikâyet')::text", (KIM["tuna"],))
            if h and ("type" in h or "invalid" in h):
                r, h = s.cagir("select create_report(%s,'other','e2e şikâyet')::text", (KIM["tuna"],))
            satir = s.q("select count(*) from reports where reporter_id=%s and target_id=%s and created_at = now()", (KIM["duru"], KIM["tuna"]))
            s.ol("duru"); gorur = s.cagir("select count(*) from reports")[0]
            return (not h) and satir == 1 and (gorur is None or gorur <= 1), "şikâyet=%s kayıt=%s kullanıcı_tüm_şikâyetleri_görüyor=%s" % (h or "OK", satir, gorur)
        finally:
            s.bitir()
    _dene(k, B, "Şikâyet → reports'a düşer (BO kuyruğu) · kullanıcı başkalarının şikâyetini okuyamaz", "misafir", "happy",
          "Kayıt var, RLS kapalı", sikayet)

    # ── 10 · hesap silme: başkalarının yüzeyinden kalkar, açık işler kapanır ──
    def hesap_sil():
        s = Is(); iz = []
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, host="nehir", misafir="cem", gun=_simdi(s).date() + _dt.timedelta(days=14), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("cem"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["cem"]))
            s.ol("cem"); _, h = s.cagir("select delete_my_account()::text")
            sil = s.q("select deleted_at is not null from users where id=%s", (KIM["cem"],))
            st = s.q("select status from requests where id=%s", (rid,)) if rid else None
            s.ol("arda"); kisi = s.cagir("select count(*) from discover_people(null,null) p where p.user_id=%s", (KIM["cem"],))[0]
            ara = s.cagir("select count(*) from kisi_ara('Cem') x where x.user_id=%s", (KIM["cem"],))[0]
            bagli = s.cagir("select count(*) from my_connections() m where m.other_id=%s and m.status='accepted'", (KIM["cem"],))[0]
            s.ol("nehir"); gelen = s.cagir("select count(*) from host_requests() h where h.guest_id=%s and h.status='pending'", (KIM["cem"],))[0]
            talep = s.q("select status from deletion_requests where matched_user_id=%s order by created_at desc limit 1", (KIM["cem"],))
            iz.append("sil=%s deleted_at=%s BO_talebi=%s · bekleyen_istek=%s · Tanış'ta=%s aramada=%s Arda'nın_bağlantılarında=%s · host'un gelen kutusunda=%s"
                      % (h or "OK", sil, talep, st, kisi, ara, bagli, gelen))
            return (not h) and sil and talep == "pending" and st != "pending" and kisi == 0 and ara == 0 and bagli == 0 and gelen == 0, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Hesabımı sil → hesap kapanır · bekleyen isteği kapanır · Tanış/aramada görünmez · host'un gelen kutusundan düşer",
          "misafir", "edge", "Silinen hesap iz bırakmaz", hesap_sil)

    # ── 11 · yasaklanan kullanıcı hiçbir keşif yüzeyinde kalmaz (B16) ───────
    def yasak():
        s = Is()
        try:
            T = KIM["tuna"]
            def yuzey():
                s.ol("arda")
                return (s.cagir("select count(*) from discover_people(null,null) p where p.user_id=%s", (T,))[0],
                        s.cagir("select count(*) from discover_availabilities() d where d.host_id=%s", (T,))[0],
                        s.cagir("select count(*) from kisi_ara('Tuna') x where x.user_id=%s", (T,))[0])
            once = yuzey()
            s.q("update users set banned_at = now() where id=%s returning 1", (T,))
            sonra = yuzey()
            return once[0] > 0 and sonra == (0, 0, 0), "Tanış/Keşfet/arama önce=%s yasaklanınca=%s" % (once, sonra)
        finally:
            s.bitir()
    _dene(k, B, "Yasaklanan kullanıcı Tanış · Keşfet · aramada görünmez (BO ban → uygulama)", "BO→misafir", "negative",
          "Üç yüzeyden de düşer", yasak)


# ── 12 · SORU AKIŞI (SQL 331 · Gökberk md.4-5): ilk temas · bekleyen istek · bağlı ──────────
@bolum("sorular")
def sorular(b, port, k):
    B = "İş kuralları (BE)"
    # İlan kimlikleri tohum her tazelendiğinde DEĞİŞİR (sabit uuid yazmak testi bir gün sonra kırdı) →
    # rolüne göre sorguyla bulunur: host2 = Arda'nın hiç teması olmayan host · nehir1/2 = Nehir'in iki
    # gelecek ilanı (Duru→Nehir bekleyen istek tohumda) · selen = Selen'in gelecek ilanı (Arda bağlı).
    def _ilanlar(kim, n):
        return [r[0] for r in db("""select id from availabilities where host_id=%s and active
                                     and avail_date > current_date and public.kural_sorusu_durumu(id) <> 'gerek_yok'
                                     order by avail_date, time_from limit %s""", (KIM[kim], n))]
    _h2 = db("select id from availabilities where id='028d6172-cb7e-42bf-92c3-2a0006714cd7' and active", ())
    _ne = _ilanlar("nehir", 2)
    ILAN = {"host2": _h2[0][0] if _h2 else None, "nehir1": _ne[0] if _ne else None,
            "nehir2": _ne[1] if len(_ne) > 1 else "kopya", "selen": (_ilanlar("selen", 1) or [None])[0]}

    def akis():
        eksik = [k_ for k_, v in ILAN.items() if not v]
        if eksik:
            return False, "tohumda ilan bulunamadı: " + ", ".join(eksik)
        s = Is(); iz = []
        try:
            if ILAN["nehir2"] == "kopya":   # tohumda sorulabilir 2. ilan yoksa: işlem içinde kopya (geri alınır)
                ILAN["nehir2"] = s.q("""insert into availabilities select (jsonb_populate_record(null::availabilities,
                                          to_jsonb(a) || jsonb_build_object('id', gen_random_uuid(), 'avail_date', a.avail_date + 1, 'filled', 0))).*
                                        from availabilities a where a.id=%s returning id""", (ILAN["nehir1"],))
            # Tohumun BUGÜN yazdığı eski sorular günlük sınırı doldurmasın (ölçülen: Arda 4 soru) — geri alınır
            s.q("update kural_sorulari set created_at = created_at - interval '2 days' where soran_id in (%s,%s) returning 1",
                (KIM["arda"], KIM["duru"]))
            for kim in ("arda", "duru"):
                s.q("update verifications set phone_verified = true where user_id=%s returning 1", (KIM[kim],))
            def listeler(soran, host_kim, ilan):
                s.ol(soran); g = s.cagir("select count(*) from sorularim() x where x.avail_id=%s", (ilan,))[0]
                s.ol(host_kim); h = s.cagir("select count(*) from bana_gelen_sorular() x where x.avail_id=%s", (ilan,))[0]
                return g, h
            cr_say = lambda a, b_: s.q("select count(*) from connection_requests where (from_id=%s and to_id=%s) or (from_id=%s and to_id=%s)",
                                         (KIM[a], b_, b_, KIM[a]))
            host2 = s.q("select host_id from availabilities where id=%s", (ILAN["host2"],))
            # A · ilk temas: bağlantı isteği + soru
            c0 = cr_say("arda", host2)
            s.ol("arda"); r, h = s.cagir("select ilan_kurali_sor(%s)::text", (ILAN["host2"],))
            dA = (_json.loads(r) if r else {}).get("durum"); gA = listeler("arda", "arda", ILAN["host2"])[0]
            s.cur.execute("reset role")
            hA = s.q("select count(*) from kural_sorulari where host_id=%s and avail_id=%s", (host2, ILAN["host2"]))
            iz.append("A ilk temas → %s (hata=%s) · bağlantı satırı %s→%s · Gönderdiğim=%s Gelen=%s" % (dA, h, c0, cr_say("arda", host2), gA, hA))
            okA = dA == "soruldu" and cr_say("arda", host2) == c0 + 1 and gA == 1 and hA == 1
            # B · bekleyen bağlantı isteği: YALNIZ soru
            c0 = cr_say("duru", KIM["nehir"])
            gB0, hB0 = listeler("duru", "nehir", ILAN["nehir1"])   # ilanda başkalarının sorusu olabilir → fark ölçülür
            s.ol("duru"); r, h = s.cagir("select ilan_kurali_sor(%s)::text", (ILAN["nehir1"],))
            dB = (_json.loads(r) if r else {}).get("durum"); gB, hB = listeler("duru", "nehir", ILAN["nehir1"])
            iz.append("B bekleyen istek → %s (hata=%s) · bağlantı satırı %s→%s · Gönderdiğim=%s Gelen=%s" % (dB, h, c0, cr_say("duru", KIM["nehir"]), gB, hB))
            okB = dB == "soruldu" and cr_say("duru", KIM["nehir"]) == c0 and gB == gB0 + 1 and hB == hB0 + 1
            # C · zaten bağlı: YALNIZ soru (+ sohbete mesaj)
            c0 = cr_say("arda", KIM["selen"])
            gC0, hC0 = listeler("arda", "selen", ILAN["selen"])   # tohumda bu ilana YANITLANMIŞ eski soru var → yeniden sorulabilir
            m0 = s.q("select count(*) from messages where from_id=%s", (KIM["arda"],))
            s.ol("arda"); r, h = s.cagir("select ilan_kurali_sor(%s)::text", (ILAN["selen"],))
            dC = (_json.loads(r) if r else {}).get("durum"); gC, hC = listeler("arda", "selen", ILAN["selen"])
            m1 = s.q("select count(*) from messages where from_id=%s", (KIM["arda"],))
            iz.append("C bağlı → %s (hata=%s) · bağlantı satırı %s→%s · sohbete mesaj +%s · Gönderdiğim=%s Gelen=%s" % (
                dC, h, c0, cr_say("arda", KIM["selen"]), m1 - m0, gC, hC))
            okC = dC == "sohbete_eklendi" and cr_say("arda", KIM["selen"]) == c0 and m1 == m0 + 1 and gC == gC0 + 1 and hC == hC0 + 1
            # D · aynı ilan tekrar → zaten_soruldu · aynı host başka ilan → yeni soru
            s.ol("duru"); r1, _ = s.cagir("select ilan_kurali_sor(%s)::text", (ILAN["nehir1"],))
            r2, h2 = s.cagir("select ilan_kurali_sor(%s)::text", (ILAN["nehir2"],))
            d1 = (_json.loads(r1) if r1 else {}).get("durum"); d2 = (_json.loads(r2) if r2 else {}).get("durum")
            iz.append("D aynı ilan → %s · başka ilan → %s" % (d1, d2 or h2))
            okD = d1 == "zaten_soruldu" and d2 == "soruldu"
            # E · host yanıtlar → soran 'yanitlandi' · F · ana sayfa soru sayacı
            s.ol("nehir"); n0 = _json.loads(s.cagir("select ana_sayfa_akisi()::text")[0])["soru"]
            qid = s.cagir("select x.id from bana_gelen_sorular() x where x.avail_id=%s", (ILAN["nehir1"],))[0]
            _, he = s.cagir("select soruya_cevap_yaz(%s, 'Evet, 1 misafir hakkım var.')::text", (qid,))
            n1 = _json.loads(s.cagir("select ana_sayfa_akisi()::text")[0])["soru"]
            s.ol("duru"); cd = s.cagir("select x.cevap_durumu from sorularim() x where x.avail_id=%s", (ILAN["nehir1"],))[0]
            iz.append("E yanıt=%s → soran durumu=%s · host soru sayacı %s→%s" % (he or "OK", cd, n0, n1))
            okE = not he and cd == "yanitlandi" and n1 == n0 - 1
            return okA and okB and okC and okD and okE, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Soru: ilk temas → istek + soru · bekleyen istek varken YALNIZ soru · bağlıyken YALNIZ soru (sohbete de) · iki listede de görünür · aynı ilan tekrar yok, başka ilan olur · yanıt + sayaç",
          "misafir+host", "happy", "Gökberk md.4-5", akis)
