# -*- coding: utf-8 -*-
# HESAP YAŞAM DÖNGÜSÜ — kayıt → sil → 14 gün → anonim → aynı e-postayla yeniden kayıt (SQL 322 · 328 · 329)
# Her senaryo tek işlemde, sonunda geri alınır.
import json as _json, uuid as _uuid
import psycopg2
from akis_e2e import bolum, DSN
from akis_e2e_bolumler import _dene


def _kaydol(cur, eposta, rol="guest"):
    cur.execute("""insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
                     created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
                   values (gen_random_uuid(), 'authenticated', 'authenticated', %s, extensions.crypt('E2eSifre123', extensions.gen_salt('bf')),
                           now(), now(), now(), '{"provider":"email"}'::jsonb, %s::jsonb) returning id""",
                (eposta, _json.dumps({"name": "E2E Döngü", "role": rol})))
    return cur.fetchone()[0]


def _durum(cur, uid):
    cur.execute("""select u.role::text, u.banned_at is not null, u.deleted_at is not null,
                          coalesce((select sum(delta) from credit_ledger c where c.user_id = u.id), 0),
                          (select email from auth.users a where a.id = u.id)
                     from users u where u.id = %s""", (uid,))
    return cur.fetchone()


def _sil_ve_bekle(cur, uid):
    cur.execute("reset role")
    cur.execute("select set_config('request.jwt.claims', %s, true)", (_json.dumps({"sub": str(uid), "role": "authenticated"}),))
    cur.execute("set local role authenticated")
    cur.execute("select delete_my_account()::text"); cur.fetchone()
    cur.execute("reset role")
    cur.execute("update users set deleted_at = now() - interval '15 days' where id = %s", (uid,))


@bolum("hesap")
def hesap(b, port, k):
    B = "Hesap yaşam döngüsü"

    def dongu():
        c = psycopg2.connect(**DSN); cur = c.cursor(); iz = []
        try:
            e = "dongu.%s@e2e.test" % _uuid.uuid4().hex[:8]
            u1 = _kaydol(cur, e, "host")
            d1 = _durum(cur, u1); iz.append("kayıt(host seçti)→rol=%s kredi=%s" % (d1[0], d1[3]))
            # aynı e-postayla ikinci kayıt: auth seviyesinde benzersiz
            try:
                cur.execute("savepoint s1"); _kaydol(cur, e); ikinci = "AÇILDI!"
            except Exception as ex:
                cur.execute("rollback to savepoint s1"); ikinci = "reddedildi"
            iz.append("aynı e-posta ikinci kayıt=%s" % ikinci)
            # sil + 14 gün öncesi: henüz anonimleşmedi (13 gün senaryosu)
            _sil_ve_bekle(cur, u1)
            cur.execute("update users set deleted_at = now() - interval '13 days' where id = %s", (u1,))
            cur.execute("select silinen_hesaplari_anonimlestir()::text"); cur.fetchone()
            erken = _durum(cur, u1)[4]
            iz.append("13. gün e-posta=%s" % ("hâlâ dolu" if erken == e else "SERBEST!"))
            cur.execute("update users set deleted_at = now() - interval '15 days' where id = %s", (u1,))
            cur.execute("select silinen_hesaplari_anonimlestir()::text"); n = cur.fetchone()[0]
            d2 = _durum(cur, u1)
            cur.execute("select status from deletion_requests where matched_user_id=%s order by created_at desc limit 1", (u1,))
            talep = (cur.fetchone() or [None])[0]
            cur.execute("select count(*) from auth.identities where user_id=%s", (u1,)); kimlik = cur.fetchone()[0]
            iz.append("15. gün → %s · auth e-posta=%s · kimlik=%s · BO talebi=%s" % (n, d2[4], kimlik, talep))
            # aynı e-postayla yeniden kayıt
            u2 = _kaydol(cur, e)
            d3 = _durum(cur, u2)
            iz.append("yeniden kayıt → yeni hesap rol=%s yasaklı=%s hoşgeldin_kredisi=%s" % (d3[0], d3[1], d3[3]))
            ok = (d1[0] == "guest" and d1[3] > 0 and ikinci == "reddedildi" and erken == e and d2[4] != e
                  and kimlik == 0 and talep == "done" and u2 != u1 and not d3[1] and d3[3] == 0)
            return ok, " · ".join(iz)
        finally:
            c.rollback(); c.close()
    _dene(k, B, "Kayıt (host seçse de misafir) → aynı e-posta ikinci kez açılmaz → sil → 13. gün e-posta dolu → 15. gün otomatik anonim (BO talebi 'done') → aynı e-postayla temiz yeni hesap (kredi tekrar verilmez)",
          "misafir", "happy", "14 günlük döngü", dongu)

    def yasakli():
        c = psycopg2.connect(**DSN); cur = c.cursor(); iz = []
        try:
            e = "yasak.%s@e2e.test" % _uuid.uuid4().hex[:8]
            u1 = _kaydol(cur, e)
            cur.execute("update users set banned_at = now(), ban_reason = 'e2e taciz' where id = %s", (u1,))
            _sil_ve_bekle(cur, u1)
            cur.execute("select silinen_hesaplari_anonimlestir()::text"); cur.fetchone()
            u2 = _kaydol(cur, e)
            d = _durum(cur, u2)
            iz.append("yasaklı hesap silindi + anonim → aynı e-posta yeni hesap: yasaklı=%s kredi=%s" % (d[1], d[3]))
            return d[1] and d[3] == 0, " · ".join(iz)
        finally:
            c.rollback(); c.close()
    _dene(k, B, "Yasaklı hesap silinip aynı e-postayla dönerse yeni hesap da YASAKLI açılır (yasak sil-kaydol ile aşılamaz)",
          "misafir", "negative", "Yasak kalıcı", yasakli)

    # ── Arayüz: Hesabımı sil → çıkış → aynı bilgilerle giriş → "hesap kapatıldı" ─────
    def ui_sil_giris():
        import uuid as u_
        from akis_e2e import Ekran, db
        from akis_e2e_bolumler import GIRIS_SIFRE
        e_posta = "silui.%s@e2e.test" % u_.uuid4().hex[:8]
        c = psycopg2.connect(**DSN); cur = c.cursor()
        uid = _kaydol(cur, e_posta)
        cur.execute("""insert into consents (user_id, type, version)
                       select %s, x, 'v16' from unnest(array['no_lounge_sale','no_offplatform_payment','community_rules',
                                                         'venue_rules','terms_privacy','age_18']) x on conflict do nothing""", (uid,))
        c.commit(); c.close()
        e = Ekran(b, port, "")
        try:
            e.dokun("Giriş Yap"); e.yaz("ad@ornek.com", e_posta); e.yaz(GIRIS_SIFRE, "E2eSifre123")
            e.pg.get_by_role("button", name="Giriş Yap").last.click(); e.bekle(2500)
            girdi = e.var("Ana Sayfa", 6000)
            e.dokun("Profil"); e.bekle(1000); e.dokun_etiket("Ayarlar"); e.bekle(1200)
            for _ in range(8):
                e.pg.mouse.wheel(0, 1500); e.bekle(150)
            e.dokun_etiket("Hesabı Sil"); e.bekle(900)          # t.stDeleteAccount (erişilebilirlik etiketi)
            from akis_e2e_b3_kesfet import _tr
            e.dokun(_tr("confirmYes")); e.bekle(500)            # onay modalı: t.confirmYes
            e.bekle(2500)
            silindi = db("select deleted_at is not null from users where id=%s", (uid,), tek=True)
            cikti = e.var("Giriş Yap", 5000)
            e.dokun("Giriş Yap"); e.yaz("ad@ornek.com", e_posta); e.yaz(GIRIS_SIFRE, "E2eSifre123")
            e.pg.get_by_role("button", name="Giriş Yap").last.click(); e.bekle(2500)
            mesaj = e.var("Bu hesap kapatıldı", 3000)
            ham = e.var("banned", 300)
            return (girdi and silindi and cikti and mesaj and not ham,
                    "ilk giriş=%s · sil→DB=%s · çıkış=%s · tekrar giriş mesajı=%s · ham metin=%s" % (girdi, silindi, cikti, mesaj, ham))
        finally:
            e.kapat()
    _dene(k, B, "Arayüz: Ayarlar › Hesabımı sil → çıkış → aynı bilgilerle giriş → 'Bu hesap kapatıldı…' (yarı silinmiş hesaba girilmez)",
          "misafir", "negative", "Türkçe açıklama, giriş yok", ui_sil_giris)
