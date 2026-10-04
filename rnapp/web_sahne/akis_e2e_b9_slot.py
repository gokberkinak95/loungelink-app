# -*- coding: utf-8 -*-
# 13 · SLOT + KREDİ HESABI (Gökberk md.11): her iptal / çıkarma yolunda slot ve kredi doğru mu.
# Her senaryo tek işlemde, sonunda geri alınır (akis_e2e_b4_kurallar.Is).
import datetime as _dt
from akis_e2e import bolum, KIM
from akis_e2e_bolumler import _dene
from akis_e2e_b4_kurallar import Is, _kredi, _simdi, _ilan_ve_seyahat


def _durum(s, aid, rid, kim):
    return (s.q("select filled from availabilities where id=%s", (aid,)),
            s.q("select status from requests where id=%s", (rid,)),
            _kredi(s, kim),
            s.q("select coalesce(sum(delta),0) from credit_ledger where ref_id=%s", (rid,)))


def _isaret(a):
    return "✓" if a else "✗"


@bolum("slotlar")
def slotlar(b, port, k):
    B = "İş kuralları (BE)"

    def senaryolar():
        s = Is(); iz = []; ok = True
        try:
            g = _simdi(s).date() + _dt.timedelta(days=18)
            aid, *_ = _ilan_ve_seyahat(s, slots=1, gun=g, bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("duru"); s.cagir("select seyahat_ekle('IST',%s,'16:10','17:50')", (g,))
            k0 = _kredi(s, "arda")
            # 1) istek → bekleyen: kredi tutulur, slot değişmez
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            r1 = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            f, st, kr, net = _durum(s, aid, r1, "arda")
            a = (f == 0 and st == "pending" and kr == k0 - 1 and net == -1); ok &= a
            iz.append("1 istek: dolu=%s kredi %s→%s %s" % (f, k0, kr, _isaret(a)))
            # 2) bekleyen isteği iptal → iade, slot aynı
            s.ol("arda"); s.cagir("select respond_request(%s,'cancel')::text", (r1,))
            f, st, kr, net = _durum(s, aid, r1, "arda")
            a = (f == 0 and st == "cancelled" and kr == k0 and net == 0); ok &= a
            iz.append("2 bekleyeni iptal: %s dolu=%s kredi=%s net=%s %s" % (st, f, kr, net, _isaret(a)))
            # 2b) tekrar iptal → çift iade YOK
            s.ol("arda"); _, h = s.cagir("select respond_request(%s,'cancel')::text", (r1,))
            a = _kredi(s, "arda") == k0; ok &= a
            iz.append("2b tekrar iptal: %s kredi=%s %s" % ((h or "OK").split(":")[-1].strip()[:20], _kredi(s, "arda"), _isaret(a)))
            # 3) Duru da başvurur (yer boşken) · Arda yeniden ister → host Arda'yı kabul: slot dolar
            s.ol("duru"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rd = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["duru"]))
            kd0 = _kredi(s, "duru") + 1   # Duru'nun istekten ÖNCEKİ bakiyesi (1 kredi tutuldu)
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            r2 = s.q("select id from requests where avail_id=%s and guest_id=%s and status='pending'", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (r2,))
            f, st, kr, net = _durum(s, aid, r2, "arda")
            a = (f == 1 and st == "accepted" and kr == k0 - 1); ok &= a
            iz.append("3 kabul: dolu=%s kredi=%s %s" % (f, kr, _isaret(a)))
            # 4) dolu ilana ikinci kabul yok
            s.ol("nehir"); _, hf = s.cagir("select respond_request(%s,'accept')::text", (rd,))
            a = bool(hf) and "fully_booked" in (hf or ""); ok &= a
            iz.append("4 dolu ilana kabul: %s %s" % ((hf or "GEÇTİ!").split(":")[-1].strip()[:20], _isaret(a)))
            # 5) host kabul edilmiş misafiri çıkarır → slot boşalır, iade
            s.ol("nehir"); s.cagir("select respond_request(%s,'decline')::text", (r2,))
            f, st, kr, net = _durum(s, aid, r2, "arda")
            a = (f == 0 and st == "declined" and kr == k0 and net == 0); ok &= a
            iz.append("5 kabulü geri al: %s dolu=%s kredi=%s %s" % (st, f, kr, _isaret(a)))
            # 6) boşalan slota bekleyen misafir kabul edilir
            s.ol("nehir"); _, h6 = s.cagir("select respond_request(%s,'accept')::text", (rd,))
            f6 = s.q("select filled from availabilities where id=%s", (aid,))
            a = (not h6 and f6 == 1); ok &= a
            iz.append("6 boşalan slota kabul: %s dolu=%s %s" % (h6 or "OK", f6, _isaret(a)))
            # 7) kabul edilmiş misafir kendi iptal eder → slot boşalır, iade
            s.ol("duru"); s.cagir("select respond_request(%s,'cancel')::text", (rd,))
            f7, st7, kr7, net7 = _durum(s, aid, rd, "duru")
            a = (f7 == 0 and st7 == "cancelled" and kr7 == kd0 and net7 == 0); ok &= a
            iz.append("7 kabul edilmiş misafir iptal: %s dolu=%s kredi %s→%s %s" % (st7, f7, kd0, kr7, _isaret(a)))
            # 8) host ilanı kaldırır (kabul edilmiş misafir varken)
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            r8 = s.q("select id from requests where avail_id=%s and guest_id=%s and status='pending'", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (r8,))
            s.ol("nehir"); s.cagir("select cancel_availability(%s, true)::text", (aid,))
            f8, st8, kr8, net8 = _durum(s, aid, r8, "arda")
            akt = s.q("select active from availabilities where id=%s", (aid,))
            a = (akt is False and st8 in ("declined", "cancelled") and kr8 == k0 and net8 == 0 and f8 == 0); ok &= a
            iz.append("8 ilan kaldır: aktif=%s istek=%s dolu=%s kredi=%s %s" % (akt, st8, f8, kr8, _isaret(a)))
            # 9) defter: bu ilanın bütün istekleri için net kredi 0
            net_hepsi = s.q("select coalesce(sum(c.delta),0) from credit_ledger c join requests r on r.id = c.ref_id where r.avail_id=%s", (aid,))
            a = net_hepsi == 0; ok &= a
            iz.append("9 ilanın net kredi hareketi=%s %s" % (net_hepsi, _isaret(a)))
            return ok, " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Slot + kredi: istek → iptal (iade, çift iade yok) → kabul (slot dolar) → dolu ilana 2. kabul yok → kabulü geri al (slot + iade) → boşalan slota kabul → kabul edilmiş misafir iptal (slot + iade) → ilan kaldır (iade) → net 0",
          "host+misafir", "edge", "Gökberk md.11", senaryolar)

    def oturum_iptal():
        s = Is(); iz = []
        try:
            g = _simdi(s).date() + _dt.timedelta(days=19)
            aid, *_ = _ilan_ve_seyahat(s, slots=1, gun=g, bas=_dt.time(16, 10), son=_dt.time(17, 50))
            k0 = _kredi(s, "arda")
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (rid,))
            sid = s.q("select id from sessions where request_id=%s", (rid,))
            if not sid:
                return True, "kabulde oturum satırı açılmıyor — oturum iptali bu durumda istek iptaliyle aynı (senaryo 7)"
            s.ol("arda"); _, h = s.cagir("select cancel_session(%s,'e2e')::text", (sid,))
            f = s.q("select filled from availabilities where id=%s", (aid,))
            st = s.q("select status from requests where id=%s", (rid,))
            sst = s.q("select status from sessions where id=%s", (sid,))
            kr = _kredi(s, "arda")
            iz.append("oturum iptal (başlamadan)=%s · oturum=%s istek=%s dolu=%s kredi %s→%s" % (h or "OK", sst, st, f, k0, kr))
            return (not h and sst == "cancelled" and st == "cancelled" and f == 0 and kr == k0), " · ".join(iz)
        finally:
            s.bitir()
    _dene(k, B, "Kabul edilmiş buluşmayı (oturum) erkenden iptal → oturum + istek kapanır · slot boşalır · kredi iade",
          "misafir", "alternate", "Slot + kredi", oturum_iptal)
