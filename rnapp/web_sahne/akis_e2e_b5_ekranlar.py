# -*- coding: utf-8 -*-
# 7-10 · PLANIM · TANIŞ · PROFİL · BİLDİRİMLER · SOHBET — arayüzden, sonuç veritabanında doğrulanır.
import re as _re
from akis_e2e import bolum, Ekran, db, KIM
from akis_e2e_bolumler import _dene
from akis_e2e_b2_ana import _sayi


def _kredi_toplam(uid):
    return int(db("select coalesce(sum(delta),0) from credit_ledger where user_id=%s", (uid,), tek=True))


@bolum("ekranlar")
def ekranlar(b, port, k):
    A = KIM["arda"]

    # ── PROFİL · CÜZDAN ────────────────────────────────────────────
    B = "Profil ve hesap"
    e = Ekran(b, port, "arda")
    e.dokun("Profil"); e.bekle(1500)
    def profil_sayilar():
        m = e.metin()
        kr, lp = _sayi(m, "KREDİ"), _sayi(m, "LOUNGEPUAN")
        db_kr = _kredi_toplam(A)
        db_lp = int(db("select coalesce(points,0) from user_balances where user_id=%s", (A,), tek=True) or 0)
        return kr == db_kr and lp == db_lp, "ekran kredi=%s puan=%s · defter kredi=%s puan=%s" % (kr, lp, db_kr, db_lp)
    _dene(k, B, "Profil bandı: KREDİ ve LOUNGEPUAN = defter (ana sayfa şeridiyle aynı kaynak · B17)", "misafir", "happy",
          "İki ekran aynı sayı", profil_sayilar)
    def cuzdan():
        e.dokun_etiket("Cüzdan"); e.bekle(1800)
        db_kr = _kredi_toplam(A)
        m = e.metin()
        sayi = [int(x) for x in _re.findall(r"(?<![\d:.])(\d{1,4})(?![\d:.])", m[:800])]
        ok = db_kr in sayi
        e.dokun_etiket("Geri"); e.bekle(600)
        return ok, "defter=%s cüzdan ekranındaki sayılar=%s" % (db_kr, sayi[:8])
    _dene(k, B, "Cüzdan bakiyesi = defter toplamı (B17)", "misafir", "happy", "Aynı sayı", cuzdan)

    # ── BİLDİRİMLER ────────────────────────────────────────────────
    B = "Bildirimler"
    def bildirim_liste():
        e.dokun_etiket("Bildirimler"); e.bekle(1800)
        okunmamis = int(db("select count(*) from notifications where user_id=%s and not read", (A,), tek=True))
        d = [x.split("·", 1)[-1].strip() for x in e.dokunulabilirler()]
        tumu = next((x for x in d if x.startswith("Tümü")), "")
        n = int(_re.search(r"(\d+)", tumu).group(1)) if _re.search(r"(\d+)", tumu) else None
        return n == okunmamis, "sekme '%s' · DB okunmamış=%s" % (tumu, okunmamis)
    _dene(k, B, "Bildirim sekmesi sayacı = okunmamış bildirim sayısı", "misafir", "happy", "Aynı sayı", bildirim_liste)
    def bildirim_dokun():
        # Başlığı TEKİL olan okunmamış bildirim (aynı başlıklı iki satırda etiketle dokunuş belirsiz kalır)
        ilk = db("""select max(id::text)::uuid, title from notifications where user_id=%s and not read
                     group by title having count(*) = 1 order by max(created_at) desc limit 1""", (A,))
        if not ilk:
            return False, "okunmamış bildirim yok"
        nid, baslik = ilk[0]
        try:
            e.dokun_etiket(baslik)
        except AssertionError:
            return False, "bildirim satırı bulunamadı: %s" % baslik
        e.bekle(2000)
        okundu = db("select count(*) from notifications where id=%s and read", (nid,), tek=True)
        gitti = e.yok("Tümünü okundu işaretle", 600)
        return okundu >= 1 and gitti, "'%s' okundu=%s · hedef ekrana gitti=%s" % (baslik[:40], okundu, gitti)
    _dene(k, B, "Bildirime dokun → okundu olur · ilgili ekrana gider", "misafir", "happy", "İkisi birden", bildirim_dokun)
    e.kapat()
    def hepsi_okundu():
        e2 = Ekran(b, port, "arda")
        try:
            e2.dokun("Profil"); e2.dokun_etiket("Bildirimler"); e2.bekle(1500)
            e2.dokun("Tümünü okundu işaretle"); e2.bekle(1800)   # etiket "· 25" sayaçlı — dokun bunu yok sayar
            kalan = int(db("select count(*) from notifications where user_id=%s and not read", (A,), tek=True))
            rozet = [x for x in e2.dokunulabilirler() if "Bildirimler ·" in x or x.endswith("9+")]
            return kalan == 0, "kalan okunmamış=%s · rozet=%s" % (kalan, rozet[:2])
        finally:
            e2.kapat()
    _dene(k, B, "'Tümünü okundu işaretle' → okunmamış 0", "misafir", "alternate", "Sıfırlanır", hepsi_okundu)

    # ── PLANIM · SEYAHAT ───────────────────────────────────────────
    B = "Planım"
    e = Ekran(b, port, "arda")
    e.dokun("Planım"); e.bekle(1500)
    def seyahat_sayisi():
        n_db = int(db("select count(*) from visits where user_id=%s and visit_date >= current_date", (A,), tek=True))
        n_kart = len(_re.findall(r"\d{1,2} (?:OCAK|ŞUBAT|MART|NİSAN|MAYIS|HAZİRAN|TEMMUZ|AĞUSTOS|EYLÜL|EKİM|KASIM|ARALIK) ·", e.metin()))
        return n_db == n_kart, "kart=%s · DB gelecek seyahat=%s" % (n_kart, n_db)
    _dene(k, B, "Seyahatlerim: kart sayısı = gelecek seyahatler", "misafir", "happy", "Aynı sayı", seyahat_sayisi)
    def seyahat_iptal():
        v = db("""select v.id, to_char(v.visit_date,'FMDD') from visits v where v.user_id=%s and v.visit_date >= current_date
                   and not exists (select 1 from requests r where r.visit_id = v.id)
                   order by v.visit_date desc limit 1""", (A,))
        if not v:
            # Tohum tazelenince Arda'nın isteksiz gelecek seyahati kalmayabiliyor (ölçüldü: 1 seyahat · 7 istek) →
            # var olanın 20 gün sonrasına bir kopyası açılır (tohum bir sonraki koşuda yine tazelenir).
            db("""insert into visits select (jsonb_populate_record(null::visits, to_jsonb(x) ||
                    jsonb_build_object('id', gen_random_uuid(), 'visit_date', current_date + 20))).*
                  from visits x where x.user_id=%s order by x.visit_date desc limit 1""", (A,))
            e.pg.reload(); e.bekle(2500); e.dokun("Planım"); e.bekle(1500)
            v = db("""select v.id, to_char(v.visit_date,'FMDD') from visits v where v.user_id=%s and v.visit_date >= current_date
                       and not exists (select 1 from requests r where r.visit_id = v.id)
                       order by v.visit_date desc limit 1""", (A,))
        if not v:
            return False, "isteği olmayan seyahat yok"
        vid, gun = v[0]
        kart = [x for x in e.metin().split("\n") if _re.match(r"^%s (EKİM|KASIM|ARALIK)" % gun, x.strip())]
        if not kart:
            return False, "kart bulunamadı (%s)" % gun
        e.kart_dokun([kart[0].strip()[:7]], "Seyahati düzenle"); e.bekle(1500)
        e.dokun("Bu seyahati iptal et"); e.bekle(900)
        modal = e.var("Seyahati iptal et", 1500)
        e.dokun("Seyahati iptal et"); e.bekle(1800)
        kaldi = db("select count(*) from visits where id=%s", (vid,), tek=True)
        return modal and kaldi == 0, "onay modalı=%s · DB'de kaldı=%s" % (modal, kaldi)
    _dene(k, B, "Seyahat düzenle → 'Bu seyahati iptal et' → onay modalı → silinir", "misafir", "alternate", "Onay sorulur, kayıt silinir", seyahat_iptal)
    e.kapat()

    # ── TANIŞ ──────────────────────────────────────────────────────
    B = "Tanış ve bağlantılar"
    e = Ekran(b, port, "arda")
    e.dokun("Tanış"); e.bekle(1500)
    def ara():
        e.yaz("İsimle ara", "Nehir"); e.bekle(2200)
        bulundu = e.var("Nehir A.", 1500) and e.yok("kimseyi bulamadık", 300)
        sahte_bos = e.var("uçuşunu yazınca canlanıyor", 300)
        return bulundu and not sahte_bos, "Nehir A. listede=%s · 'seyahatini ekle' boş kartı=%s" % (bulundu, sahte_bos)
    _dene(k, B, "İsimle ara 'Nehir' → sonuç görünür (etkin süzgeç dışındaki kişi de · B18)", "misafir", "edge", "Bulunur", ara)
    def profil_ac():
        e.dokun_etiket("Nehir A."); e.bekle(1800)
        ok = e.var("Nehir A.", 1500) and (e.var("Bağlantı", 800) or e.var("Ürün Tasarımcısı", 800))
        return ok, "profil kartı açıldı=%s" % ok
    _dene(k, B, "Arama sonucuna dokun → profil kartı açılır", "misafir", "happy", "Profil açılır", profil_ac)
    _dene(k, B, "Tanış'ta ham kod / {yer tutucu} yok", "misafir", "edge", "Yok", lambda: (not e.ham_kodlar(), e.ham_kodlar()))
    e.kapat()

    # ── SOHBET ─────────────────────────────────────────────────────
    B = "Sohbet ve oturum"
    e = Ekran(b, port, "arda")
    def mesaj():
        e.dokun_etiket("Sohbet:"); e.bekle(1500)
        e.dokun("Sohbeti Aç", True, 0); e.bekle(2000)
        n0 = int(db("select count(*) from messages where from_id=%s", (A,), tek=True))
        e.yaz("Mesaj yaz", "E2E: kapıdayım"); e.dokun("Gönder"); e.bekle(2000)
        n1 = int(db("select count(*) from messages where from_id=%s", (A,), tek=True))
        ekranda = e.var("E2E: kapıdayım", 1500)
        return n1 == n0 + 1 and ekranda, "DB mesaj %s→%s · ekranda=%s" % (n0, n1, ekranda)
    _dene(k, B, "Sohbet aç → mesaj yaz → Gönder → DB'ye düşer ve ekranda görünür", "misafir", "happy", "İkisi birden", mesaj)
    def bos_mesaj():
        e.yaz("Mesaj yaz", "   "); n0 = int(db("select count(*) from messages where from_id=%s", (A,), tek=True))
        try:
            e.dokun("Gönder"); e.bekle(1000)
        except AssertionError:
            pass
        n1 = int(db("select count(*) from messages where from_id=%s", (A,), tek=True))
        return n1 == n0, "boş mesaj gönderildi mi=%s" % (n1 != n0)
    _dene(k, B, "Boş / yalnız boşluk mesaj gönderilmez", "misafir", "negative", "DB değişmez", bos_mesaj)
    e.kapat()

    # ── LOUNGE DAVETİ (host → misafir) ─────────────────────────────
    B = "İstek / soru / davet"
    e = Ekran(b, port, "arda")
    def davet_kabul():
        r = db("""select i.id from invites i where i.guest_id=%s and i.status='pending' order by i.created_at desc limit 1""", (A,))
        if not r:
            return False, "bekleyen lounge daveti yok"
        iid = r[0][0]
        e.kart_dokun(["Lounge daveti", "Nehir A."], "Kabul et"); e.bekle(2200)
        st = db("select status from invites where id=%s", (iid,), tek=True)
        istek = db("select count(*) from requests where guest_id=%s and host_id=%s and status='accepted' and created_at > now() - interval '2 minutes'",
                   (A, KIM["nehir"]), tek=True)
        return st == "accepted" and istek >= 1, "davet=%s · kabul edilmiş yeni istek=%s" % (st, istek)
    _dene(k, B, "Lounge davetini kabul et → davet accepted · kabul edilmiş istek (oturum yolu açılır)", "misafir", "happy", "İkisi birden", davet_kabul)
    e.kapat()

    # ── HOST · İLANLARIM ───────────────────────────────────────────
    B = "Planım"
    N = KIM["nehir"]
    e = Ekran(b, port, "nehir")
    e.dokun("Planım"); e.bekle(1500)
    def ilan_sayisi():
        m = _re.search(r"İLANLARIM · (\d+) aktif", e.metin())
        n_db = int(db("select count(*) from availabilities where host_id=%s and active and avail_date>=current_date", (N,), tek=True))
        return bool(m) and int(m.group(1)) == n_db, "ekran=%s · DB=%s" % (m.group(1) if m else None, n_db)
    _dene(k, B, "İlanlarım: 'N aktif' = veritabanı (ana sayfa sayacıyla aynı tanım)", "host", "happy", "Aynı sayı", ilan_sayisi)
    def ilan_kaldir():
        r = db("""select a.id, to_char(a.time_from,'HH24:MI') || '–' || to_char(a.time_to,'HH24:MI') from availabilities a
                   where a.host_id=%s and a.active and a.avail_date >= current_date
                     and not exists (select 1 from requests q where q.avail_id=a.id and q.status in ('pending','accepted'))
                   order by a.avail_date, a.time_from limit 1""", (N,))
        if not r:
            return False, "başvurusuz ilan yok"
        aid, aralik = r[0]
        e.kaydir_bul(aralik)
        e.kart_dokun([aralik], "İlanı kaldır"); e.bekle(1000)
        modal = e.metin()
        for d in ("İlanı kaldır", "Kaldır", "Evet, kaldır", "Evet"):
            try:
                e.dokun(d); break
            except AssertionError:
                continue
        e.bekle(1800)
        aktif = db("select active from availabilities where id=%s", (aid,), tek=True)
        sorulan = ("emin" in modal.lower()) or ("kaldır" in modal.lower() and "vazgeç" in modal.lower())
        return aktif is False and sorulan, "onay soruldu=%s · ilan aktif=%s" % (sorulan, aktif)
    _dene(k, B, "Başvurusuz ilanı kaldır → onay sorulur → ilan kapanır", "host", "alternate", "Onay + kapanış", ilan_kaldir)
    _dene(k, B, "İlanlarım'da ham kod / {yer tutucu} yok", "host", "edge", "Yok", lambda: (not e.ham_kodlar(), e.ham_kodlar()))
    e.kapat()
