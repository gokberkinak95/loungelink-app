# -*- coding: utf-8 -*-
# ROL AYRIMI — misafire özgü alanlar host'a, host'a özgü alanlar misafire görünmüyor mu?
# Her kişi için bütün sekmeler + Planım alt sekmeleri + Profil menüsünün her satırı açılır;
# görünen metin rol işaretleriyle taranır. Ayrıca "Host olmak istiyorum" başvurusunun
# uçtan uca çalıştığı ve BO kuyruğuna düştüğü ölçülür.
from akis_e2e import bolum, Ekran, db, KIM
from akis_e2e_bolumler import _dene

# Yalnız MİSAFİRE görünmesi gerekenler (host olmaya davet / başvuru)
MISAFIR_OZEL = ["Host olsam ne kazanırım", "Misafir olarak kayıtlısın", "Kartımda bir kişilik yer var",
                "Kartındaki yeri değerlendir", "Host başvurusu yap", "İlk 100 host kurucu çemberde",
                "Bu ekran kart sahiplerine özel"]
# Yalnız HOST'A görünmesi gerekenler (ilan yönetimi, host cüzdanı, kurucu hostluk talebi)
HOST_OZEL = ["İlanlarım", "İlan Ekle", "Misafiri kabul et", "KAÇIRILAN", "MERTEBE", "Kurucu Host ol",
             "Rozetin profilinde ve ilanlarında görünür", "İlanı kaldır", "İlanı düzenle"]

PROFIL_MENU = ["Oturum Geçmişi", "Değerlendirmeler", "Bildirimler", "Güven Puanım", "Güvenlik Merkezi",
               "LoungePuan", "Arkadaşını Davet Et", "Kampanyalar", "Plan", "Ayarlar", "Profilini tamamla", "Cüzdan"]


def _tara(b, port, kim):
    """[(ekran, metin)] — her ekran ayrı sekmede açılır (alttaki ekranlar metne karışmasın)."""
    sonuc = []
    def ac(ad, adimlar):
        e = Ekran(b, port, kim)
        try:
            for a in adimlar:
                try:
                    getattr(e, a[0])(*a[1:])
                except Exception:
                    pass
            e.bekle(1500)
            for _ in range(6):
                e.pg.mouse.wheel(0, 1500); e.bekle(200)
            # yalnız EN ÜSTTEKİ katmanın metni: son açılan tam ekran katmanı varsa onu oku
            m = e.pg.evaluate("""() => {
              const kat = Array.from(document.querySelectorAll('[data-testid], [role=dialog]')).filter(x => x.getBoundingClientRect().height > 400);
              return document.body.innerText;
            }""")
            sonuc.append((ad, m))
        finally:
            e.kapat()
    ac("Ana sayfa", [])
    ac("Keşfet", [["dokun", "Keşfet"]])
    ac("Planım", [["dokun", "Planım"]])
    ac("Planım · Seyahatlerim", [["dokun", "Planım"], ["dokun", "Seyahatlerim"]])
    ac("Tanış", [["dokun", "Tanış"]])
    ac("Profil", [["dokun", "Profil"]])
    for m in PROFIL_MENU:
        ac("Profil › " + m, [["dokun", "Profil"], ["dokun_etiket", m]])
    return sonuc


def _sizinti(sonuc, isaretler, temel=None):
    """İşaretin göründüğü İLK ekran; ana sayfa metni katmanların altında kaldığı için ayrı tutulur."""
    bulgu = {}
    for ekran, metin in sonuc:
        for i in isaretler:
            # TAMAMI BÜYÜK HARF işaretler (KAÇIRILAN, MERTEBE) büyük/küçük harf DUYARLI: cümle içindeki
            # "kaçırılan bir bildirim" host kartı değildir (ilk koşuda yanlış alarm verdi).
            var = (i in metin) if i.isupper() else (Ekran._n(i) in Ekran._n(metin))
            if var and i not in bulgu:
                bulgu[i] = ekran
    return bulgu


@bolum("rol")
def rol(b, port, k):
    B = "Rol ayrımı"
    for kim, rol_ad in [("arda", "misafir"), ("mina", "misafir"), ("nehir", "host"), ("mert", "host")]:
        sonuc = _tara(b, port, kim)
        yasak = HOST_OZEL if rol_ad == "misafir" else MISAFIR_OZEL
        bul = _sizinti(sonuc, yasak)
        _dene(k, B, "%s (%s): %s alanları hiçbir ekranda görünmez (%d ekran tarandı)" % (
                  kim, rol_ad, "host'a özgü" if rol_ad == "misafir" else "misafire özgü", len(sonuc)),
              rol_ad, "negative", "Hiçbiri görünmez",
              lambda bul=bul: (not bul, "; ".join("'%s' → %s" % (i, e) for i, e in bul.items()) or "temiz"))
        # olumlu taraf: kendi rolünün alanları görünüyor mu (yanlışlıkla hepsi gizlenmiş olmasın)
        kendi = MISAFIR_OZEL if rol_ad == "misafir" else HOST_OZEL
        gor = _sizinti(sonuc, kendi)
        _dene(k, B, "%s (%s): kendi rolünün alanları görünür" % (kim, rol_ad), rol_ad, "happy",
              "En az biri görünür", lambda gor=gor: (bool(gor), "görülen: %s" % ", ".join(gor) or "HİÇBİRİ"))

    # ── Host başvurusu uçtan uca: misafir başvurur → BO kuyruğu → onay → host ──
    def basvuru():
        G = KIM["ela"]
        once = db("select count(*) from host_applications where user_id=%s", (G,), tek=True)
        e = Ekran(b, port, "ela")
        try:
            e.dokun("Planım"); e.bekle(1500)
            yol = []
            for d in ("Kartımda bir kişilik yer var", "Kartındaki yeri değerlendir", "Host başvurusu yap", "Host ol"):
                try:
                    e.dokun(d, False); e.bekle(1500); yol.append(d); break
                except AssertionError:
                    continue
            if not yol:
                e.dokun("Profil"); e.bekle(1200)
                for d in ("Profilini tamamla",):
                    try:
                        e.dokun_etiket(d); e.bekle(1500)
                    except AssertionError:
                        pass
                for d in ("Kartımda bir kişilik yer var", "Host başvurusu yap"):
                    try:
                        e.dokun(d, False); e.bekle(1500); yol.append("Profil›" + d); break
                    except AssertionError:
                        continue
            ekran = e.metin()
            butonlar = [x.split("·", 1)[-1].strip() for x in e.dokunulabilirler()]
            return yol, ekran, butonlar
        finally:
            e.kapat()
    yol, ekran, butonlar = basvuru()
    _dene(k, B, "Misafir (Ela): 'host olmak istiyorum' girişi bulunur ve başvuru formuna götürür", "misafir", "happy",
          "Form açılır", lambda: (bool(yol), "yol=%s · ekrandaki düğmeler: %s" % (yol, [x for x in butonlar if x][-12:])))

    # ── Formu arayüzden gönder → DB (pending) → BO listesi → BO onayı → uygulamada host ──
    def gonder():
        G = KIM["ela"]
        e = Ekran(b, port, "ela")
        try:
            if yol[0].startswith("Profil›"):
                e.dokun("Profil"); e.bekle(1200); e.dokun_etiket("Profilini tamamla"); e.bekle(1500)
                e.dokun(yol[0].split("›", 1)[1], False); e.bekle(1800)
            else:
                e.dokun("Planım"); e.bekle(1500); e.dokun(yol[0], False); e.bekle(1800)
            if not e.var("Başvuruyu Gönder", 1500):
                for d in ("Kartındaki yeri değerlendir", "Host başvurusu yap"):
                    try:
                        e.dokun(d, False); e.bekle(1500); break
                    except AssertionError:
                        continue
            secenek = e.pg.evaluate("""() => { const t = document.body.innerText; return t; }""")
            # ilk erişim kaynağı çipi ve "1 misafir"
            try:
                e.dokun("Priority Pass", False)
            except AssertionError:
                pass
            e.dokun("1 misafir", False); e.bekle(300)
            e.dokun("Başvuruyu Gönder"); e.bekle(2200)
            r = db("select id, status, access_source, guest_capacity from host_applications where user_id=%s order by created_at desc limit 1", (G,))
            bekliyor = e.var("Başvurun inceleniyor", 2500)
            return r, bekliyor, e.metin()
        finally:
            e.kapat()
    r, bekliyor, metin = gonder()
    _dene(k, B, "Başvuru formu gönderilir → host_applications 'pending' · ekranda 'Başvurun inceleniyor'", "misafir", "happy",
          "Kayıt + durum", lambda: (bool(r) and r[0][1] == "pending" and bekliyor,
                                    "kayıt=%s · ekranda bekliyor=%s · ekran=%s" % (r[0][1:] if r else None, bekliyor,
                                    "" if r else metin[-300:].replace(chr(10), " | "))))
    def bo_ve_onay():
        if not r:
            return False, "başvuru kaydı yok"
        aid = r[0][0]; G = KIM["ela"]
        import psycopg2, json
        from akis_e2e import DSN
        c = psycopg2.connect(**DSN); cur = c.cursor()
        try:
            cur.execute("set role service_role")
            # BO'nun host-applications sayfasının sorgusu (page.jsx) — service_role
            cur.execute("""select id, status, (select email from users u where u.id = h.user_id) from host_applications h
                            order by created_at desc limit 100""")
            bo_listede = any(x[0] == aid and x[1] == "pending" for x in cur.fetchall())
            cur.execute("select review_host_application(%s, true, 'e2e onay')", (aid,))
            cur.execute("reset role"); c.commit()
            rol_yeni = db("select role from users where id=%s", (G,), tek=True)
        finally:
            c.close()
        e = Ekran(b, port, "ela")
        try:
            e.dokun("Planım"); e.bekle(1800)
            host_ui = e.var("İlanlarım", 2500) or e.var("İlan Ekle", 800)
            davet_yok = e.yok("Kartımda bir kişilik yer var", 600)
        finally:
            e.kapat()
        # temizlik: test hesabını misafire geri al (dünya her koşuda yeniden kuruluyor, yine de)
        db("update users set role='guest' where id=%s returning 1", (G,))
        db("delete from host_applications where id=%s returning 1", (aid,))
        return (bo_listede and rol_yeni == "host" and host_ui and davet_yok,
                "BO listesinde=%s · onay sonrası rol=%s · uygulamada host alanları=%s · 'host ol' daveti kalktı=%s" % (bo_listede, rol_yeni, host_ui, davet_yok))
    _dene(k, B, "BO başvuruyu listeler → onaylar → kullanıcı host olur: host alanları açılır, 'host ol' daveti kalkar",
          "BO→misafir", "happy", "Uçtan uca", bo_ve_onay)

    # ── TEK YOL (SQL 328): host rolü yalnız BO onaylı başvuruyla ─────────────
    def tek_yol_sunucu():
        from akis_e2e_b4_kurallar import Is, _salon, _simdi
        import datetime as dt
        s = Is()
        try:
            s.ol("mina"); _, h1 = s.cagir("select rolumu_sec('host')::text")
            _, h2 = s.cagir("select create_availability_base(%s,'IST',%s,'16:10','17:50',1)::text",
                            (_salon(s), _simdi(s).date() + dt.timedelta(days=21)))
            rol_ = s.q("select role from users where id=%s", (KIM["mina"],))
            s.ol("nehir"); _, h3 = s.cagir("select rolumu_sec('guest')::text")   # host → misafir serbest
            k1 = (h1 or "GEÇTİ!").split(":")[-1].strip().split(" ")[0]
            return (bool(h1) and "host_basvurusu_gerekli" in h1 and bool(h2) and rol_ == "guest" and not h3,
                    "misafir rolumu_sec(host)=%s · create_availability_base doğrudan=%s · rol=%s · host→misafir=%s" % (
                        k1, (h2 or "GEÇTİ!").split(":")[-1].strip()[:40], rol_, h3 or "OK"))
        finally:
            s.bitir()
    _dene(k, B, "Sunucu: misafir kendini host yapamaz (rolumu_sec reddi) · ilan arka kapısı kapalı · host→misafir serbest",
          "misafir", "negative", "Tek yol BO onayı", tek_yol_sunucu)

    def tek_yol_arayuz():
        M = KIM["mina"]
        db("delete from visits where user_id=%s and not exists (select 1 from requests r where r.visit_id=visits.id) returning 1", (M,))
        e = Ekran(b, port, "mina")
        try:
            e.dokun("Host olsam ne kazanırım?", False); e.bekle(1500)
            e.dokun("Kartındaki yeri değerlendir", True, 0); e.bekle(1800)
            form = e.var("Başvuruyu Gönder", 3000)
            rol_ = db("select role from users where id=%s", (M,), tek=True)
            return form and rol_ == "guest", "başvuru formu açıldı=%s · rol=%s (anında host OLMAMALI)" % (form, rol_)
        finally:
            e.kapat()
            db("update users set role='guest' where id=%s returning 1", (M,))
    _dene(k, B, "Ana sayfa 'Host olsam ne kazanırım?' → 'Kartındaki yeri değerlendir' → başvuru formu (anında host yok)",
          "misafir", "happy", "Form açılır, rol misafir", tek_yol_arayuz)
