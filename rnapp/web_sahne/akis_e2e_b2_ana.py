# -*- coding: utf-8 -*-
# 2 · ANA SAYFA — şerit · akış hücreleri · davet · istek · soru · puan · kısayollar
import json as _json, re as _re
from akis_e2e import bolum, Ekran, db, KIM, DSN
from akis_e2e_bolumler import _dene


def _rpc_as(kim, sql, args=None):
    """Bir RPC'yi o kullanıcı olarak (RLS + auth.uid) çağırır, sonucu döndürür, değişikliği geri alır."""
    import psycopg2
    uid = KIM[kim]
    c = psycopg2.connect(**DSN)
    try:
        cur = c.cursor()
        cur.execute("set local role authenticated")
        cur.execute("select set_config('request.jwt.claims', %s, true)", (_json.dumps({"sub": uid, "role": "authenticated"}),))
        cur.execute(sql, args or ())
        r = cur.fetchone()[0] if cur.description else None
        c.rollback()
        return r
    finally:
        c.close()


def _sayi(metin, etiket):
    """'14 | KREDİ' biçiminde etiketten hemen önceki sayıyı okur."""
    parca = [x.strip() for x in metin.split("\n") if x.strip()]
    E = Ekran._n(etiket)
    for i, p in enumerate(parca):
        if Ekran._n(p) == E and i > 0 and _re.match(r"^\d+$", parca[i - 1]):
            return int(parca[i - 1])
    return None


def _beklenen(akis):
    """Davet kutusu davet + baglanti sayar (AkisSeridi · 18 Eylül kararı)."""
    d = {x: int(akis.get(x) or 0) for x in ["sohbet", "istek", "soru"]}
    d["davet"] = int(akis.get("davet") or 0) + int(akis.get("baglanti") or 0)
    return d


def _kredi(uid):
    return int(db("select coalesce(sum(delta),0) from credit_ledger where user_id=%s", (uid,), tek=True))


@bolum("ana")
def ana(b, port, k):
    B = "Ana sayfa"
    # ── misafir (Gökberk) ─────────────────────────────────────────
    e = Ekran(b, port, "gokberk")
    m = e.metin()
    G = KIM["gokberk"]
    beklenen = (_kredi(G), int(db("select coalesce(sum(delta),0) from points_ledger where user_id=%s", (G,), tek=True)),
                int(db("select score from trust_scores where user_id=%s", (G,), tek=True)))
    ekran = (_sayi(m, "KREDİ"), _sayi(m, "LOUNGEPUAN"), _sayi(m, "GÜVEN"))
    _dene(k, B, "Cüzdan şeridi: KREDİ · LOUNGEPUAN · GÜVEN = sunucudaki değerler", "misafir", "happy",
          "Üç sayı da veritabanıyla aynı", lambda: (ekran == beklenen, "ekran=%s db=%s" % (ekran, beklenen)))
    akis = _rpc_as("gokberk", "select ana_sayfa_akisi()")
    ekr = {x: _sayi(m, E) for x, E in [("sohbet", "SOHBET"), ("istek", "İSTEK"), ("davet", "DAVET"), ("soru", "SORU")]}
    _dene(k, B, "Akış hücreleri (Sohbet · İstek · Davet · Soru) = ana_sayfa_akisi", "misafir", "happy",
          "Dört sayı sunucuyla aynı",
          lambda: (all(ekr[x] == _beklenen(akis)[x] for x in ekr), "ekran=%s sunucu=%s" % (ekr, _beklenen(akis))))
    for hucre, iz in [("Sohbet", "Oturumlar ve sohbetler"), ("Davet", "Davet"), ("İstek", "İstek"), ("Soru", "Soru")]:
        def git(h=hucre, z=iz):
            e.dokun_etiket(h + ":"); ok = e.var(z, 4000)
            try:
                e.dokun_etiket("Geri")
            except Exception:
                e.dokun("Ana Sayfa")
            e.bekle(500)
            return ok and e.var("GÜNAYDIN", 3000) or ok and e.var("KREDİ", 3000), "'%s' göründü=%s · geri ana sayfa" % (z, ok)
        _dene(k, B, "'%s' hücresi → kendi listesi; Geri → ana sayfa" % hucre, "misafir", "happy", "Doğru ekran ve dönüş", git)

    def davet_kabul():
        r = db("""select cr.id, p.name from connection_requests cr join profiles p on p.user_id=cr.from_id
                  where cr.to_id=%s and cr.status='pending' order by cr.created_at desc limit 1""", (G,))
        cid, ad = r[0]
        once = _sayi(e.metin(), "DAVET")
        e.dokun("Kabul et", kacinci=0); e.bekle(1800)
        st = db("select status from connection_requests where id=%s", (cid,), tek=True)
        sonra = _sayi(e.metin(), "DAVET")
        listede = e.var(ad.split()[0], 3000)
        return (st == "accepted" and sonra == once - 1 and listede,
                "db=%s davet %s→%s · '%s' Bağlantılarım'da=%s" % (st, once, sonra, ad, listede))
    _dene(k, B, "Davet 'Kabul et' → DB accepted · Davet −1 · kişi Bağlantılarım'da (B5)", "misafir", "happy", "Üçü birden", davet_kabul)

    def davet_red():
        r = db("select cr.id from connection_requests cr where cr.to_id=%s and cr.status='pending' order by cr.created_at desc limit 1", (G,))
        if not r:
            return False, "reddedilecek davet kalmadı"
        cid = r[0][0]; once = _sayi(e.metin(), "DAVET")
        e.dokun("Reddet", kacinci=0); e.bekle(1800)
        st = db("select status from connection_requests where id=%s", (cid,), tek=True)
        return st in ("declined", "rejected") and _sayi(e.metin(), "DAVET") == once - 1, "db=%s davet %s→%s" % (st, once, _sayi(e.metin(), "DAVET"))
    _dene(k, B, "Davet 'Reddet' → DB reddedildi · Davet −1", "misafir", "negative", "Bağlantı kurulmaz", davet_red)

    def kredi_cip():
        e.dokun_etiket("kredi:"); ok = e.var("Cüzdan", 4000)
        e.dokun_etiket("Geri"); return ok, "cüzdan=%s" % ok
    _dene(k, B, "Kredi çipi → Cüzdan", "misafir", "happy", "Cüzdan açılır", kredi_cip)

    def host_bul():
        e.dokun("Host bul"); ok = e.var("uyum", 5000)
        e.dokun("Ana Sayfa"); return ok, "keşfet listesi=%s" % ok
    _dene(k, B, "Seyahat kartı 'Host bul' → Keşfet (uyumlu ilanlar)", "misafir", "happy", "Keşfet açılır", host_bul)
    _dene(k, B, "Ekranda ham kod / {yer tutucu} yok", "misafir", "edge", "Yok", lambda: (not e.ham_kodlar(), e.ham_kodlar()))
    e.kapat()

    # ── host (Nehir) ──────────────────────────────────────────────
    e = Ekran(b, port, "nehir")
    m = e.metin()
    N = KIM["nehir"]
    akis = _rpc_as("nehir", "select ana_sayfa_akisi()")
    ekr = {x: _sayi(m, E) for x, E in [("sohbet", "SOHBET"), ("istek", "İSTEK"), ("davet", "DAVET"), ("soru", "SORU")]}
    _dene(k, B, "Host akış hücreleri = ana_sayfa_akisi", "host", "happy", "Sunucuyla aynı",
          lambda: (all(ekr[x] == _beklenen(akis)[x] for x in ekr), "ekran=%s sunucu=%s" % (ekr, _beklenen(akis))))

    def _kartlar():
        """GELEN İSTEKLER kartlarını EKRAN SIRASIYLA okur: [(ad, 'HH:MM')]. Sıra eşleşme puanına göre."""
        parca = [x.strip() for x in e.metin().split(chr(10)) if x.strip()]
        out = []
        for i, p in enumerate(parca):
            if _re.match(r"^#\d+ / \d+$", p):
                ad = next((q for q in parca[i + 1:i + 4] if len(q) > 2 and q.endswith(".")), None)
                saat = next((m.group(1) for q in parca[i + 1:i + 9] for m in [_re.search(r"· (\d\d:\d\d)–\d\d:\d\d", q)] if m), None)
                out.append((ad, saat))
        return out

    def _istek_satiri(ad, saat):
        r = db("""select r.id, r.guest_id, r.avail_id, a.filled, a.slots from requests r join availabilities a on a.id=r.avail_id
                  join profiles p on p.user_id=r.guest_id
                  where r.host_id=%s and r.status='pending' and p.name=%s and a.time_from=%s::time limit 1""", (N, ad, saat))
        return r[0] if r else None

    def _reddet_sirasi(kart_i):
        # DAVETLER bölümünün "Reddet"i istek kartlarınınkinden ÖNCE gelir.
        d = [x.split("·", 1)[-1].strip() for x in e.dokunulabilirler()]
        return sum(1 for x in d[:d.index("Misafiri kabul et")] if x == "Reddet") + kart_i

    def _sec(dolu_mu):
        for i, (ad, saat) in enumerate(_kartlar()):
            r = _istek_satiri(ad, saat)
            if r and ((r[3] >= r[4]) == dolu_mu):
                return i, ad, saat, r
        return None, None, None, None

    def istek_dolu():
        i, ad, saat, r = _sec(True)
        if r is None:
            return False, "dolu ilana gelmiş bekleyen istek kartı yok (SEED8 §Dolu ilana KABUL)"
        e.dokun("Misafiri kabul et", kacinci=i); e.bekle(1800)
        st = db("select status from requests where id=%s", (r[0],), tek=True)
        mesaj = e.var("tüm slotları dolu", 2000)
        return st == "pending" and mesaj, "kart#%d %s %s durum=%s 'tüm slotları dolu' göründü=%s" % (i + 1, ad, saat, st, mesaj)
    _dene(k, B, "Dolu ilana gelen isteği kabul → 'ilan dolu' mesajı · istek bekliyor'da kalır", "host", "negative",
          "Türkçe sebep kartın altında; durum değişmez", istek_dolu)

    def istek_kabul():
        i, ad, saat, r = _sec(False)
        if r is None:
            return False, "boş yeri olan ilana gelmiş bekleyen istek kartı yok"
        rid, gid, aid, dolu, _ = r
        bild0 = db("select count(*) from notifications where user_id=%s", (gid,), tek=True)
        e.dokun("Misafiri kabul et", kacinci=i); e.bekle(2200)
        st = db("select status from requests where id=%s", (rid,), tek=True)
        dolu2 = db("select filled from availabilities where id=%s", (aid,), tek=True)
        bild1 = db("select count(*) from notifications where user_id=%s", (gid,), tek=True)
        return (st == "accepted" and dolu2 == dolu + 1 and bild1 > bild0,
                "kart#%d %s %s durum=%s dolu %s→%s misafire_bildirim %s→%s" % (i + 1, ad, saat, st, dolu, dolu2, bild0, bild1))
    _dene(k, B, "İstek 'Misafiri kabul et' → accepted · slot dolar · misafire bildirim", "host", "happy", "Üçü birden", istek_kabul)

    def istek_red():
        kartlar = _kartlar()
        if not kartlar:
            return False, "reddedilecek istek kartı kalmadı"
        ad, saat = kartlar[0]
        r = _istek_satiri(ad, saat)
        if r is None:
            return False, "kart (%s %s) DB'de bekleyen değil" % (ad, saat)
        rid, gid = r[0], r[1]
        k0 = _kredi(gid)
        e.dokun("Reddet", kacinci=_reddet_sirasi(0)); e.bekle(900)
        if e.var("emin misin", 600):
            e.dokun("Reddet")
        e.bekle(1500)
        st = db("select status from requests where id=%s", (rid,), tek=True)
        k1 = _kredi(gid)
        return st in ("declined", "rejected") and k1 > k0, "kart %s %s durum=%s misafir_kredisi %s→%s (iade beklenir)" % (ad, saat, st, k0, k1)
    _dene(k, B, "İstek 'Reddet' → reddedildi · misafirin kredisi iade", "host", "negative", "Kredi geri döner", istek_red)

    def puan_sonra():
        bek = _rpc_as("nehir", "select json_agg(x) from pending_ratings() x") or []
        if not bek:
            return False, "bekleyen puan yok"
        ilk = bek[0]
        e.dokun("Sonra"); e.bekle(1500)
        ertelendi = bool(db("select %s::uuid = any(coalesce(rate_deferred_by,'{}')) from sessions where id=%s", (N, ilk["session_id"]), tek=True))
        ad_gitti = e.yok(ilk["other_name"] + " ile", 800)
        sonraki = (bek[1]["other_name"] + " ile") if len(bek) > 1 else None
        kart_dogru = e.var(sonraki, 2000) if sonraki else e.yok("Son oturumunu puanla", 800)
        return ertelendi and ad_gitti and kart_dogru, "ertelendi=%s '%s' kalktı=%s sıradaki=%s görünüyor=%s" % (
            ertelendi, ilk["other_name"], ad_gitti, sonraki, kart_dogru)
    _dene(k, B, "Puan hatırlatması 'Sonra' → oturum ertelenir · kart sıradakine geçer (yoksa kalkar)", "host", "alternate",
          "Ertelenen kart düşer", puan_sonra)
    _dene(k, B, "Ekranda ham kod / {yer tutucu} yok", "host", "edge", "Yok", lambda: (not e.ham_kodlar(), e.ham_kodlar()))
    e.kapat()
