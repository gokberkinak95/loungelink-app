# -*- coding: utf-8 -*-
# BO → UYGULAMA · yönetici eylemlerinin uygulamada görünen sonucu (service_role / yönetici oturumu).
# Her senaryo tek işlemde, sonunda geri alınır (akis_e2e_b4_kurallar.Is).
import datetime as _dt
from akis_e2e import bolum, KIM
from akis_e2e_bolumler import _dene
from akis_e2e_b4_kurallar import Is, _kredi, _bildirim, _salon, _simdi, _ilan_ve_seyahat


def _servis(s):
    s.cur.execute("reset role")
    s.cur.execute("""select set_config('request.jwt.claims', '{"role":"service_role"}', true)""")
    s.cur.execute("set local role service_role")


def _yonetici_ol(s, kim):
    s.q("insert into admin_roles (user_id, role, display_name) values (%s, 'super_admin', 'e2e') on conflict do nothing returning 1", (KIM[kim],))
    s.ol(kim)


def _kod(h):
    return (h or "GEÇTİ!").split(":")[-1].strip().split(" ")[0]


@bolum("bo")
def bo(b, port, k):
    B = "BO → uygulama"

    def kredi_ayar():
        s = Is()
        try:
            k0 = _kredi(s, "arda")
            s.ol("arda"); g0 = s.cagir("select credits from user_balances where user_id=%s", (KIM["arda"],))[0]
            _servis(s); _, h = s.cagir("select admin_adjust_credit(%s, 5, 'admin:e2e telafi')::text", (KIM["arda"],))
            s.ol("arda"); g1 = s.cagir("select credits from user_balances where user_id=%s", (KIM["arda"],))[0]
            s.ol("arda"); _, h2 = s.cagir("select admin_credit_adjust(%s, 100, 'kendime')::text", (KIM["arda"],))
            k2 = _kredi(s, "arda")
            _servis(s); _, h3 = s.cagir("select admin_credit_adjust(%s, 2, 'e2e')::text", (KIM["arda"],))   # BO: sbAdmin (ledger/actions.js)
            k3 = _kredi(s, "arda")
            ok = (not h) and g1 == g0 + 5 and bool(h2) and k2 == k0 + 5 and (not h3) and k3 == k0 + 7
            return ok, "BO +5 → uygulamada %s→%s (%s) · kullanıcı kendine kredi=%s · BO defter ekranı +2 → %s (%s)" % (
                g0, g1, h or "OK", _kod(h2), k3, h3 or "OK")
        finally:
            s.bitir()
    _dene(k, B, "Kredi düzeltme: BO (servis) +5 → uygulama bakiyesi +5 · kullanıcı kendine kredi YAZAMAZ (yetki yok)",
          "BO→misafir", "happy", "Yetki kapısı + yansıma", kredi_ayar)

    def ilan_sil():
        s = Is()
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, gun=_simdi(s).date() + _dt.timedelta(days=15), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (rid,))
            k0, b0 = _kredi(s, "arda"), _bildirim(s, "arda")
            _servis(s); _, h = s.cagir("select admin_delete_availability(%s, false, 'e2e içerik ihlali')::text", (aid,))
            s.ol("arda"); gor = s.cagir("select count(*) from discover_availabilities() where id=%s", (aid,))[0]
            st = s.q("select status from requests where id=%s", (rid,)); k1, b1 = _kredi(s, "arda"), _bildirim(s, "arda")
            return ((not h) and gor == 0 and st in ("cancelled", "declined") and k1 > k0 and b1 > b0,
                    "sil=%s · keşifte=%s · kabul edilmiş istek=%s · misafir kredi %s→%s · bildirim %s→%s" % (h or "OK", gor, st, k0, k1, b0, b1))
        finally:
            s.bitir()
    _dene(k, B, "BO ilanı siler (kabul edilmiş misafiri var) → keşiften düşer · istek kapanır · misafire iade + bildirim",
          "BO→host/misafir", "alternate", "Kimse habersiz kalmaz", ilan_sil)

    def yasak_bulusma():
        s = Is()
        try:
            aid, gun, bas, son = _ilan_ve_seyahat(s, gun=_simdi(s).date() + _dt.timedelta(days=16), bas=_dt.time(16, 10), son=_dt.time(17, 50))
            s.ol("arda"); s.cagir("select create_request(%s,'lounge',null)::text", (aid,))
            rid = s.q("select id from requests where avail_id=%s and guest_id=%s", (aid, KIM["arda"]))
            s.ol("nehir"); s.cagir("select respond_request(%s,'accept')::text", (rid,))
            k0, b0 = _kredi(s, "arda"), _bildirim(s, "arda")
            s.q("update users set banned_at = now(), ban_reason = 'e2e taciz' where id=%s returning 1", (KIM["nehir"],))
            st = s.q("select status from requests where id=%s", (rid,)); k1, b1 = _kredi(s, "arda"), _bildirim(s, "arda")
            metin = s.q("select string_agg(body, ' | ') from notifications where user_id=%s and ref_id=%s and created_at = now()", (KIM["arda"], rid)) or ""
            sizdi = any(x in metin.lower() for x in ("taciz", "yasak", "ban"))
            return (st == "cancelled" and k1 > k0 and b1 > b0 and not sizdi,
                    "kabul edilmiş buluşma=%s · misafir kredi %s→%s · bildirim %s→%s · sebep sızdı=%s · metin=%r" % (st, k0, k1, b0, b1, sizdi, metin[:80]))
        finally:
            s.bitir()
    _dene(k, B, "BO host'u yasaklar (kabul edilmiş buluşması var) → buluşma iptal · misafire iade + tarafsız bildirim (B19)",
          "BO→misafir", "negative", "Misafir korunur, sebep açıklanmaz", yasak_bulusma)

    def host_basvuru():
        s = Is()
        try:
            g = _simdi(s).date() + _dt.timedelta(days=17)
            s.ol("ela"); _, h = s.cagir("select apply_for_host('TK_MS', 1, 'e2e başvuru')::text")
            ap = s.q("select id from host_applications where user_id=%s order by created_at desc limit 1", (KIM["ela"],))
            s.ol("ela"); _, h0 = s.cagir("select create_availability(%s,'IST',%s,'16:10','17:50',1)::text", (_salon(s), g))
            if not ap:
                return False, "başvuru=%s · kayıt yok" % h
            b0 = _bildirim(s, "ela")
            _servis(s); _, h1 = s.cagir("select review_host_application(%s, true, 'e2e onay')::text", (ap,))
            b1 = _bildirim(s, "ela")
            s.ol("ela"); _, h2 = s.cagir("select create_availability(%s,'IST',%s,'16:10','17:50',1)::text", (_salon(s), g))
            return ((not h) and bool(h0) and (not h1) and (not h2) and b1 > b0,
                    "başvuru=%s · onaysız ilan=%s · onay=%s bildirim %s→%s · onaylı ilan=%s" % (h or "OK", _kod(h0), h1 or "OK", b0, b1, h2 or "AÇILDI"))
        finally:
            s.bitir()
    _dene(k, B, "Host başvurusu: onaysız ilan açılamaz → BO onaylar → kullanıcıya bildirim · ilan açılır",
          "BO→misafir", "happy", "Rol kapısı BO kararına bağlı", host_basvuru)

    def kyc():
        s = Is()
        try:
            M = KIM["mina"]
            s.ol("mina"); _, hb = s.cagir("select kimlik_belgesi_gonder(%s, null)::text", (KIM["arda"] + "/on.jpg",))   # başkasının klasörü
            s.ol("mina"); _, hg = s.cagir("select kimlik_belgesi_gonder(%s, %s)::text", (M + "/e2e_on.jpg", M + "/e2e_ozcekim.jpg"))
            st0 = s.q("select id_status from verifications where user_id=%s", (KIM["mina"],))
            s.ol("mina"); _, h0 = s.cagir("select bo_kyc_karar(%s,'approved')::text", (KIM["mina"],))
            _servis(s); _, h1 = s.cagir("select bo_kyc_karar(%s,'rejected')::text", (KIM["mina"],))   # BO: sbAdmin (kyc/actions.js)
            _, h2 = s.cagir("select bo_kyc_karar(%s,'approved','e2e')::text", (KIM["mina"],))
            v = s.q("select id_verified from verifications where user_id=%s", (KIM["mina"],))
            return (bool(hb) and not hg and st0 == "submitted" and bool(h0) and bool(h1) and not h2 and v is True,
                    "başkasının klasörü=%s · belge gönder=%s (durum=%s) · kullanıcı kendini onaylar=%s · notsuz ret=%s · BO onayı=%s → id_verified=%s" % (
                        _kod(hb), hg or "OK", st0, _kod(h0), _kod(h1), h2 or "OK", v))
        finally:
            s.bitir()
    _dene(k, B, "Kimlik (KYC): belge gönder → kullanıcı kendini onaylayamaz · ret not ister · BO onayı → id_verified",
          "BO→misafir", "negative", "Kapılar + yansıma", kyc)
