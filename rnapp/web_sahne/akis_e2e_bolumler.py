# -*- coding: utf-8 -*-
"""
akis_e2e_bolumler.py — akis_e2e.py'nin BÖLÜMLERİ (v7 onay galerisinin başlıklarıyla aynı sıra).
Her `k.ekle(...)`: bölüm · akış · rol · tür (happy/edge/alternate/negative) · BEKLENEN · gerçekleşen.
"""
import time, uuid
from akis_e2e import bolum, Ekran, db, KIM


def _dene(k, bol, akis, rol, tur, beklenen, fn):
    """Bir kontrolü koşturur; istisna = KALDI (gerçekleşen = istisna metni)."""
    try:
        ok, gercek = fn()
    except Exception as ex:
        ok, gercek = False, "istisna: " + str(ex)[:220]
    k.ekle(bol, akis, rol, tur, beklenen, ok, gercek)
    return ok


GIRIS_SIFRE = "••••••••"   # giriş formunun şifre yer tutucusu
KAYIT_EPOSTA = "ad@ornek.com"   # kayıt formu da sözlükteki t.emailPh (4 Ekim düzeltmesi)


def _yeni_eposta(on="e2e"):
    return "%s.%s@e2e.loungelink.test" % (on, uuid.uuid4().hex[:8])


# ════════════════════════════════════════════════════════════════════
# 1 · AÇILIŞ · GİRİŞ YAP · BAŞLA (tanıtım + kayıt) · ŞİFREMİ UNUTTUM
# ════════════════════════════════════════════════════════════════════
@bolum("giris")
def giris(b, port, k):
    B = "Açılış/Giriş/Kayıt"

    # 1.1 Açılış ekranı: üç kapı
    e = Ekran(b, port, "")
    _dene(k, B, "Açılış: Başla · Giriş Yap · Önce dene görünür", "ziyaretçi", "happy",
          "Üç eylem de ekranda", lambda: (all(e.var(x) for x in ["Başla", "Giriş Yap", "Önce dene"]), e.metin()[:120]))

    # 1.2 Önce dene → Salon Rehberi (giriş yapmadan) → geri → açılış
    def onceden():
        e.dokun("Önce dene: hangi salona girebilirim?", tam=False)
        a = e.var("Salon Rehberi")
        e.dokun("‹ Geri")
        return a and e.var("Başla"), "rehber=%s" % a
    _dene(k, B, "Önce dene → Salon Rehberi kayıtsız açılır, Geri açılışa döner", "ziyaretçi", "alternate",
          "Rehber açılır; geri açılış", onceden)

    # 1.3 Başla → 5 tanıtım → kart ekranı → Başla → kayıt formu
    def tanitim():
        e.dokun("Başla")
        for _ in range(4):
            e.dokun("Devam")
        kart = e.var("Hangi kart senin?")
        e.dokun("Başla")
        return kart and e.var("Hesap Oluştur"), "kart_ekrani=%s" % kart
    _dene(k, B, "Başla → tanıtım (5 adım) → kart ekranı → kayıt formu", "ziyaretçi", "happy",
          "Tanıtımın sonunda kayıt formu", tanitim)
    e.kapat()

    # 1.4 Giriş: boş form → hata, sunucuya gitmez
    e = Ekran(b, port, "")
    e.dokun("Giriş Yap")
    def bos_giris():
        e.dokun_etiket("Giriş Yap", kacinci=0) if False else e.pg.get_by_role("button", name="Giriş Yap").last.click()
        e.bekle(600)
        return e.var("Lütfen tüm alanları doldur."), e.metin()[:160]
    _dene(k, B, "Giriş: boş form → 'tüm alanları doldur'", "ziyaretçi", "negative", "Uyarı; giriş denenmez", bos_giris)

    # 1.5 Giriş: geçersiz e-posta biçimi
    def gecersiz():
        e.yaz("ad@ornek.com", "gecersiz-eposta"); e.yaz(GIRIS_SIFRE, "Sifre12345")
        e.pg.get_by_role("button", name="Giriş Yap").last.click(); e.bekle(600)
        return e.var("Geçerli bir e-posta gir"), e.metin()[:160]
    _dene(k, B, "Giriş: geçersiz e-posta → 'Geçerli bir e-posta gir'", "ziyaretçi", "negative", "Biçim uyarısı", gecersiz)

    # 1.6 Giriş: kayıtlı olmayan hesap / yanlış şifre
    def yanlis():
        e.yaz("ad@ornek.com", "yok.boyle@e2e.loungelink.test"); e.yaz(GIRIS_SIFRE, "YanlisSifre1")
        e.pg.get_by_role("button", name="Giriş Yap").last.click(); e.bekle(900)
        return e.var("E-posta veya şifre hatalı"), e.metin()[:160]
    _dene(k, B, "Giriş: yanlış bilgiler → anlaşılır hata, ekranda kalır", "ziyaretçi", "negative",
          "'E-posta veya şifre hatalı', form yerinde", yanlis)

    # 1.7 Şifremi unuttum: geçersiz → uyarı; geçerli → 'gönderildi' + sunucuda kurtarma kaydı
    def sifre():
        e.dokun("Şifremi unuttum"); ok1 = e.var("Şifreni sıfırla")
        alan = e.pg.locator("input").first
        alan.fill("bozuk"); e.dokun("Sıfırlama Bağlantısı Gönder"); ok2 = e.var("Geçerli bir e-posta gir")
        alan.fill("gokberk@sahne.loungelink.test"); e.dokun("Sıfırlama Bağlantısı Gönder")
        ok3 = e.var("Bağlantı gönderildi")
        tok = db("select recovery_token is not null and recovery_token<>'' from auth.users where email='gokberk@sahne.loungelink.test'", tek=True)
        return ok1 and ok2 and ok3 and bool(tok), "form=%s biçim=%s gönderildi=%s db_token=%s" % (ok1, ok2, ok3, tok)
    _dene(k, B, "Şifremi unuttum: biçim kontrolü + gönderildi ekranı + sunucuda kurtarma kaydı", "ziyaretçi", "happy",
          "Uyarı → gönderildi; auth.users.recovery_token yazıldı", sifre)
    e.kapat()

    # 1.8–1.12 Kayıt (e-posta doğrulaması KAPALI): misafir ve host
    for rol, rol_metin in [("guest", "Lounge'a girmek istiyorum"), ("host", "Kartımda misafir hakkı var")]:
        eposta = _yeni_eposta(rol)
        e = Ekran(b, port, "")
        e.dokun("Başla")
        for _ in range(4): e.dokun("Devam")
        e.dokun("Başla")
        def kayit_adim1():
            e.dokun("Devam Et"); ok_bos = e.var("Lütfen tüm alanları doldur.")
            e.yaz("adın soyadın", "E2E %s" % rol); e.yaz(KAYIT_EPOSTA, eposta); e.yaz("En az 8 karakter", "kisa")
            e.dokun("Devam Et"); ok_kisa = e.var("Şifre en az 8 karakter olmalı.")
            e.yaz("En az 8 karakter", "E2eSifre123"); e.dokun("Devam Et")
            ok2 = e.var("hangi taraftan giriyorsun")
            return ok_bos and ok_kisa and ok2, "boş=%s kısa=%s adım2=%s" % (ok_bos, ok_kisa, ok2)
        _dene(k, B, "Kayıt adım 1: boş/kısa şifre engellenir, doğru bilgiyle adım 2", rol, "negative+happy",
              "İki uyarı, sonra rol adımı", kayit_adim1)
        def rol_adim():
            e.dokun("Devam Et")   # rol seçmeden
            kilitli = e.var("hangi taraftan giriyorsun", 800) and e.yok("Tümünü kabul et", 300)
            e.dokun_etiket(rol_metin); e.dokun("Devam Et")
            ok = e.var("Şartlar ve Sözleşmeler") or e.var("Tümünü kabul et")
            return ok and kilitli, "rol seçilmeden kilitli=%s, adım3=%s" % (kilitli, ok)
        _dene(k, B, "Kayıt adım 2: rol seçmeden ilerlenemez, seçince sözleşmeler", rol, "edge", "Rol zorunlu", rol_adim)
        def onay_ve_kayit():
            hesap_btn = e.pg.get_by_role("button", name="Hesap Oluştur").last
            hesap_btn.click(); e.bekle(1200)   # onaysız
            kilit = db("select count(*) from auth.users where email=%s", (eposta,), tek=True) == 0
            e.dokun("Tümünü kabul et"); e.bekle(300)
            hesap_btn.click(); e.bekle(2500)
            ana = e.var("Ana Sayfa", 6000)
            r = db("select u.role::text, p.name, (select count(*) from consents c where c.user_id=u.id) from users u join profiles p on p.user_id=u.id where u.email=%s", (eposta,))
            ok = kilit and ana and r and r[0][0] == rol and r[0][2] >= 6
            return ok, "onaysız kilitli=%s ana_sayfa=%s db=%s" % (kilit, ana, r)
        _dene(k, B, "Kayıt: onaysız kilitli; onayla → ana sayfa; DB rol=%s + 6 onay + profil" % rol, rol, "happy",
              "Ana sayfa; users.role doğru; consents≥6", onay_ve_kayit)
        def tanitim_yok():
            return e.yok("Kalkışa iki saat"), "tanıtım metni görünüyor mu"
        _dene(k, B, "Kayıt sonrası tanıtım TEKRAR GELMEZ", rol, "edge", "Ana sayfada kalır", tanitim_yok)
        e.kapat()

        # 1.13 Aynı e-postayla ikinci kayıt → 'zaten bir hesap var'
        if rol == "guest":
            e = Ekran(b, port, "")
            e.dokun("Başla");
            for _ in range(4): e.dokun("Devam")
            e.dokun("Başla")
            def ayni():
                e.yaz("adın soyadın", "Tekrar"); e.yaz(KAYIT_EPOSTA, eposta); e.yaz("En az 8 karakter", "E2eSifre123")
                e.dokun("Devam Et"); e.dokun_etiket("Lounge'a girmek istiyorum"); e.dokun("Devam Et")
                e.dokun("Tümünü kabul et"); e.pg.get_by_role("button", name="Hesap Oluştur").last.click(); e.bekle(1500)
                n = db("select count(*) from auth.users where email=%s", (eposta,), tek=True)
                return e.var("zaten bir hesap var") and n == 1, "ekran/db hesap sayısı=%s" % n
            _dene(k, B, "Kayıt: kayıtlı e-posta → 'zaten bir hesap var', ikinci hesap açılmaz", "ziyaretçi", "negative",
                  "Uyarı; auth.users'ta tek kayıt", ayni)
            e.kapat()

            # 1.14 Giriş happy + çıkış
            e = Ekran(b, port, "")
            def giris_cikis():
                e.dokun("Giriş Yap"); e.yaz("ad@ornek.com", eposta); e.yaz(GIRIS_SIFRE, "E2eSifre123")
                e.pg.get_by_role("button", name="Giriş Yap").last.click(); e.bekle(1500)
                ana = e.var("Ana Sayfa", 6000)
                sihirbaz = e.var("Havalimanı Ziyareti", 1500)   # yeni kullanıcı: ilk seyahat sihirbazı kendiliğinden açılır
                if sihirbaz: e.dokun_etiket("Geri")
                e.dokun("Profil"); e.dokun("Çıkış Yap")
                soru = e.var("Çıkış yapmak istediğine emin misin?")
                e.dokun("Vazgeç"); kaldi = e.yok("emin misin", 600) and e.var("Güven Puanım")
                e.dokun("Çıkış Yap"); e.dokun("Çıkış Yap"); e.bekle(1500)
                donus = e.var("Başla") and e.yok("Kalkışa iki saat", 300)
                return ana and soru and kaldi and donus, "ana=%s onay_sorusu=%s vazgeç_kaldı=%s çıkış→açılış=%s" % (ana, soru, kaldi, donus)
            _dene(k, B, "Giriş (doğru şifre) → ana sayfa; Çıkış onay sorar; Vazgeç kalır; Çıkış → açılış (tanıtım değil)", "misafir", "happy",
                  "Ana sayfa; çıkışta açılış ekranı", giris_cikis)
            e.kapat()

    # 1.15 Kayıt — e-posta doğrulaması AÇIK: bekleme ekranı, doğrulanmadan giriş yok, doğrulayınca
    #      bekleyen onay/telefon ilk girişte yazılır (6.3.2 düzeltmesi)
    eposta = _yeni_eposta("dogrula")
    e = Ekran(b, port, "", ek="onay=acik")
    e.dokun("Başla")
    for _ in range(4): e.dokun("Devam")
    e.dokun("Başla")
    def dogrulamali():
        e.yaz("adın soyadın", "E2E Doğrula"); e.yaz(KAYIT_EPOSTA, eposta); e.yaz("+90 5XX", "+90555%07d" % (int(uuid.uuid4().int % 10**7)))
        e.yaz("En az 8 karakter", "E2eSifre123"); e.dokun("Devam Et")
        e.dokun_etiket("Lounge'a girmek istiyorum"); e.dokun("Devam Et"); e.dokun("Tümünü kabul et")
        e.pg.get_by_role("button", name="Hesap Oluştur").last.click(); e.bekle(1500)
        bek = e.var("doğrulama bağlantısı gönderdik")
        onay0 = db("select count(*) from consents c join users u on u.id=c.user_id where u.email=%s", (eposta,), tek=True)
        e.dokun("Doğruladım, devam et"); e.bekle(1200)
        henuz = e.var("henüz açılmamış")
        db("update auth.users set email_confirmed_at=now() where email=%s", (eposta,))
        e.dokun("Doğruladım, devam et"); e.bekle(2500)
        ana = e.var("Ana Sayfa", 6000); e.bekle(2500)
        r = db("select (select count(*) from consents c where c.user_id=u.id), u.phone from users u where u.email=%s", (eposta,))
        ok = bek and onay0 == 0 and henuz and ana and r and r[0][0] >= 6 and r[0][1]
        return ok, "bekleme=%s onay_önce=%s henüz=%s ana=%s db(onay,tel)=%s" % (bek, onay0, henuz, ana, r)
    _dene(k, B, "Doğrulamalı kayıt: bekleme ekranı → doğrulanmadan giriş yok → doğrulayınca ana sayfa; onay+telefon ilk girişte yazılır",
          "misafir", "alternate", "Onaylar ve telefon kaybolmaz", dogrulamali)
    e.kapat()


# ════════════════════════════════════════════════════════════════════
# 0 · TARAMA — 90 sahnenin hepsi: ham kod / {yer_tutucu} · sayfa hatası · sunucu hatası · logError
# ════════════════════════════════════════════════════════════════════
@bolum("tarama")
def tarama(b, port, k):
    import cek
    BILEREK_ARIZA = ("ariza", "rol_kaybi")   # bu sahneler ağ hatasını BİLEREK enjekte ediyor
    for ad, kayit in cek.SAHNELER.items():
        if "vitrin" in ad:
            continue
        kim, adimlar = kayit[0], kayit[1]
        ek = kayit[2] if len(kayit) > 2 else ""
        e = Ekran(b, port, kim, ek=ek)
        bos = {"errors": []}
        for a in adimlar:
            cek.adim_uygula(e.pg, a, bos)
        e.bekle(900)
        ham = e.ham_kodlar()
        rpc = [] if any(x in ad for x in BILEREK_ARIZA) else e.rpc_hatalari()
        loge = [] if any(x in ad for x in BILEREK_ARIZA) else e.logerror()
        sorun = {"ham": ham, "sayfa_hatasi": e.hatalar, "rpc": rpc, "logError": loge, "adim": bos["errors"]}
        temiz = not ham and not e.hatalar and not rpc and not loge
        k.ekle("Tarama", ad, kim or "ziyaretçi", "sweep",
               "ham kod yok · sayfa/sunucu hatası yok", temiz,
               "OK" if temiz else str({x: v for x, v in sorun.items() if v})[:400])
        e.kapat()
