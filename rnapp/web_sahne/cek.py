#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_sahne/cek.py — GERÇEK REACT AĞACINDAN, GERÇEK VERİYLE EKRAN GÖRÜNTÜSÜ.

  1. pg_kopru.py'yi başlatır (yerel Postgres · gerçek RPC + RLS)
  2. dist/'i sunar, her sahneyi 390×844 @3x Chromium'da açar
  3. sahne adımlarını UYGULAMANIN KENDİ DÜĞMELERİNE DOKUNARAK yürütür
  4. PNG + JSON (konsol, hata, logError, görünen metin) yazar

Kullanım:
  LL_SAHNE=1 npx expo export --platform web --output-dir web_sahne/dist
  python3 web_sahne/cek.py [sahne ...]      # boş = hepsi   --tam = tam sayfa

⚠️ Bu bir emülatör değil: react-native-web + Chromium. Metin motoru,
yazı tipi ölçümü ve flex yerleşimi cihazla aynı kurallara yakın ama
birebir değil; durum çubuğu/çentik yok. Geometri, renk, font ailesi,
ikonlar ve BİLEŞEN YAPISI ise kaynaktan geldiği için cihazla aynı.
"""
import http.server, threading, socketserver, os, sys, json, functools, subprocess, time, re
from playwright.sync_api import sync_playwright

KOK = os.path.dirname(os.path.abspath(__file__))
DIST = os.environ.get("LL_SAHNE_DIST") or os.path.join(KOK, "dist")   # 3 Ekim: önizleme derlemesi ayrı klasörde
# 23 Eylül — `LL_SAHNE_DIL=en`: aynı sahneler İngilizce, `out_en/`e.
# (ham_kod_check.py iki dilin de ekran metnini tarıyor.)
DIL = os.environ.get("LL_SAHNE_DIL", "tr")
OUT = os.environ.get("LL_SAHNE_OUT") or os.path.join(KOK, "out" if DIL == "tr" else "out_" + DIL)
os.makedirs(OUT, exist_ok=True)
KOPRU_PORT = 8765

# sahne adı → (kim, adımlar). Adım: ("dokun", metin) | ("dokun_a11y", etiket) | ("yaz", yer_tutucu, deger) | ("bekle", ms) | ("kaydir",)
SAHNELER = {
    "01_splash":       ("",        []),   # ekran: Splash
    "16_giris":        ("",        [("dokun", "Giriş Yap")]),   # ekran: Auth
    "17_kayit":        ("",        [("dokun", "Başla"), ("dokun", "Devam"), ("dokun", "Devam"), ("dokun", "Devam"), ("dokun", "Devam"), ("dokun", "Başla"),
                                   ("yaz", "adın soyadın", "Gökberk İnak"), ("yaz", "email@example.com", "gokberk@ornek.com"),
                                   ("yaz", "En az 8 karakter", "sahne-sifre-1"), ("dokun", "Devam Et"),
                                   ("dokun_a11y", "Lounge'a girmek istiyorum"), ("dokun", "Devam Et"),
                                   ("dokun_a11y", "Kabul ediyorum: Kullanım"), ("dokun_a11y", "Kabul ediyorum: Topluluk"), ("dokun_a11y", "Kabul ediyorum: Bu uygulama"), ("dokun_a11y", "Kabul ediyorum: Havalimanı"), ("dokun_a11y", "Kabul ediyorum: Platform")]),   # ekran: CompleteOnboarding
    "15_tanitim":      ("",        [("dokun", "Başla")]),   # ekran: Onboarding
    "15b_tanitim3":    ("",        [("dokun", "Başla"), ("dokun", "Devam"), ("dokun", "Devam")]),   # ekran: Onboarding
    "15c_tanitim_kart": ("",       [("dokun", "Başla"), ("dokun", "Devam"), ("dokun", "Devam"), ("dokun", "Devam"), ("dokun", "Devam"),
                                    ("dokun", "Priority Pass")]),   # ekran: Onboarding
    "11_ana_misafir":  ("gokberk", []),   # ekran: Home
    "12_ana_host":     ("selin",   []),   # ekran: Home
    "18_ana_host1":    ("host1",   []),    # SEED6 dünyası: istekler · aksiyon · davet   # ekran: Home
    "19_ana_guest1":   ("guest1",  []),   # ekran: Home
    "02_kesfet":       ("kaan",    [("dokun", "Keşfet")]),   # Kaan: Deniz'e isteği yok → tasarımdaki "İstek gönder"   # ekran: Discovery
    # v6.1 — md.33: istek formu, üç katlanır bilgi paneli kapalı
    # v6.2 — hareket vitrini (onaylı bileşenler, tek başına)
    "60_vitrin_kapi":  ("",        [("bekle", 1600)]),   # ekran: MomentScreen · K5
    "61_vitrin_radar": ("",        [("bekle", 2400)]),   # ekran: TerminalRadari · K3
    "62_vitrin_puan":  ("",        [("bekle", 1400)]),
    "66_vitrin_yukleyici": ("",    [("bekle", 1200)]),   # ekran: MarkaYukleyici · K2
    "67_vitrin_damga": ("",        [("bekle", 1800)]),   # ekran: OnayDamgasi · K4
    "68_vitrin_pano":  ("",        [("bekle", 1200)]),   # ekran: SessizPano · K6
    "69_vitrin_kalkis": ("",       [("bekle", 1200)]),   # ekran: KalkisHalkasi · K7
    "59_vitrin_zemin": ("",        [("bekle", 2400)]),   # ekran: Sayfa atmosferi · K9   # ekran: TakimyildizPuan · K8 + K2
    "50_istek_gonder": ("kaan",    [("dokun", "Keşfet"), ("dokun", "İstek gönder"), ("bekle", 900)]),   # ekran: Discovery · istek modalı
    # v6.1 — md.e: kural ekranının altı ("Salon kurallarını oku" resmî kaynağa)
    "51_kural_alt":    ("kaan",    [("dokun", "Keşfet"), ("dokun_a11y", "Uyum"), ("kaydir",), ("bekle", 700)]),   # ekran: KuralKarari
    "14_seyahatler":   ("gokberk", [("dokun", "Planım")]),   # ekran: Trips
    "05_tanis":        ("gokberk", [("dokun", "Tanış")]),   # ekran: Meet
    "05b_baglanti_kur": ("kaan",   [("dokun", "Tanış"), ("dokun_a11y", "Salon"), ("dokun_a11y", "Deniz K.")]),   # ilanı olan kişi → "İlanına git" kısayolu   # ekran: Meet
    "13_baglantilar":  ("gokberk", [("dokun_a11y", "Sohbet:")]),   # ekran: Meet
    "09_profil":       ("selin",   [("dokun", "Profil")]),   # tasarım 09 host profili (Yayın & Davet satırı)   # ekran: Profile
    "09b_profil_misafir": ("gokberk", [("dokun", "Profil")]),   # ekran: Profile
    "12b_ilanlarim":   ("selin",   [("dokun", "Planım")]),   # host Planım → İlanlarım (öneri 5 Eylül)   # ekran: Trips
    "12c_ilanlarim_pasif": ("selin",  [("dokun", "Planım"), ("dokun_a11y", "Yayında olmayanlar"), ("kaydir",), ("bekle", 800)]),   # v6.3 · H3 katlı bölüm açık · "Yeniden yayınla"   # ekran: Hosting
    "14b_seyahatler_host": ("selin", [("dokun", "Planım"), ("dokun_a11y", "Seyahatlerim")]),   # ekran: Trips
    "10_bildirim":     ("gokberk", [("dokun", "Profil"), ("dokun", "Bildirimler")]),   # ekran: Notifications
    "03_kural":        ("kaan",    [("dokun", "Keşfet"), ("dokun_a11y", "Uyum"), ("bekle", 2600)]),   # ekran: KuralKarari · 29 Eylül: K4 grupları 160+420ms arayla iner, bitmeden çekiliyordu
    "03b_kural_damga": ("gokberk", [("dokun", "Keşfet"), ("dokun_a11y", "Uyum"), ("bekle", 3200)]),   # K4 · üç şart tutunca damga   # ekran: KuralKarari
    # ══════════════════════════════════════════════════════════════
    # 🔴 20 EYLÜL — `ayni_sahne_check.py` ÜÇ İKİZ KÜMESİ BULDU VE ÜÇÜ DE
    # SAHNE BETİĞİNİN HATASIYDI, ÜRÜNÜN DEĞİL. Teker teker ölçtüm:
    #
    #  a) Üç sahne (06 · 35 · 45) sohbete `("dokun_a11y", "İstek:")`
    #     ile giriyordu ve zaman aşımına uğruyordu. Tarayıcıda ölçtüm —
    #     ve suçlu düğme DEĞİLDİ, o satırdaki SAYIYDI:
    #
    #         o anki a11y etiketleri:  ['Sohbet: 1', 'İstek: 0']
    #
    #     `gokberk`in SIFIR aktif isteği vardı: süpürge, tohumun `active`
    #     oturumunu günler içinde kapatıp isteği `completed` yapmıştı.
    #     "İstek: 0" sayacına dokunmak hiçbir şey açmıyor — açmaması
    #     DOĞRU. Sahne bunu "düğme bozuk" diye bildiriyordu.
    #
    #     ⚠️ İLK DÜZELTMEM YANLIŞTI: üçünü `Sohbet:` yoluna aldım. O yol
    #     BAŞKA bir sohbeti (bağlantı sohbeti, 4 mesaj) açıyor — yani üç
    #     sahne de 06b'nin kopyası oldu ve "21 mesaj" ile "canlı oturum"
    #     hiç çekilmedi. Asıl kusur sahnede değil DÜNYADAYDI
    #     (bkz. `dunyayi_tazele`); tohum her koşuda tazelenince
    #     orijinal `İstek:` yolu yine doğru oldu ve geri alındı.
    #
    #     🆕 SINIF: "SAYAÇ SATIRINA DOKUNAN BİR TEST, SAYACIN SIFIR
    #     OLABİLECEĞİNİ DE ÖLÇMELİDİR — VE SIFIRSA SUÇLU GENELDE DÜĞME
    #     DEĞİL, O SAYIYI ÜRETEN DÜNYADIR."
    #
    #  b) `39_ana_yeni` ve `36_kesfet_dogrula` de aynı BAYAT DÜNYA
    #     yüzünden düşüyordu: kullanıcının seyahati kalmamıştı, ürün de
    #     açılışta seyahat formunu açıyordu (App.js:835 — kasıtlı) ve
    #     form sekmeleri örtüyordu. Önce "formu kapat" adımı ekledim;
    #     tohum tazelenince form HİÇ AÇILMADI ve bu sefer o adım düştü.
    #     Yani düzeltmem de bayat dünyaya göre yazılmıştı. İkisi de
    #     orijinal hâline geri alındı.
    #
    #     🆕 SINIF: "BAYAT BİR DÜNYADA YAZILAN DÜZELTME, DÜNYA
    #     TAZELENİNCE KENDİSİ HATAYA DÖNÜŞÜR — SEMPTOMU DÜZELTMEDEN
    #     ÖNCE DÜNYANIN TAZE OLDUĞUNU KANITLA."
    #
    # 🆕 SINIF: "BİR SAHNE ADIMININ ZAMAN AŞIMI 'DÜĞME BOZUK' DEMEK
    # DEĞİLDİR — ÖNCE SEÇİCİYİ VE ÖRTEN KATMANI ELE; ÜRÜNÜ SUÇLAMAK EN
    # SON İHTİMALDİR VE YANLIŞ SUÇLAMA GERÇEK HATAYI GİZLER."
    # ══════════════════════════════════════════════════════════════
    "63_istekler_host":   ("selin",   [("dokun_a11y", "İstek:"), ("bekle", 1500)]),   # v6.3 md.9 · katman kuralı · host gelen istekler   # ekran: RequestsPanel
    "64_istekler_misafir":("gokberk", [("dokun_a11y", "İstek:"), ("bekle", 1500)]),   # v6.3 md.9 · gönderdiğin istek kartı   # ekran: RequestsPanel
    "65_ilan_ekle":       ("selin",   [("dokun", "Planım"), ("dokun_a11y", "+ İlan Ekle"), ("bekle", 1500)]),   # v6.3 · İlan sihirbazı 1/3   # ekran: HostAvailability
    # 1 Ekim — SEED9 akış dünyası: İstek (Gelen/Gönderdiğim) · Sohbet (Oturumlar/Bağlantılar) · Keşfet kural durumları
    "70_akis_nehir_ana":     ("nehir", [("bekle", 1500)]),   # ekran: Home
    "71_akis_nehir_istek":   ("nehir", [("dokun", "İSTEK"), ("bekle", 1500)]),   # ekran: RequestsPanel · Gelen
    "72_akis_nehir_giden":   ("nehir", [("dokun", "İSTEK"), ("dokun_a11y", "Gönderdiğim"), ("bekle", 1200)]),   # ekran: RequestsPanel · Gönderdiğim
    "73_akis_nehir_oturum":  ("nehir", [("dokun", "SOHBET"), ("bekle", 1500)]),   # ekran: RequestsPanel · Oturumlar
    # v7.2 (Gökberk 3 Ekim: "tasarımda olmayan ekranları ekle ki doğruluğu teyitleyelim")
    "87_oturum_canli": ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 1500), ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1500),
                                    ("dokun_a11y", "Oturumu tamamla"), ("bekle", 1800)]),   # ekran: Chat · oturum paneli (canlı)
    "87b_oturum_araclar": ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 1500), ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1500),
                                    ("dokun_a11y", "Oturumu tamamla"), ("bekle", 1800), ("gor", "Sorun bildir"), ("bekle", 1200)]),   # ekran: Chat · oturum paneli (sakin araçlar · Btn camTeal/camKirmizi)
    "88_oturum_puanla": ("selin",  [("dokun", "Şimdi puanla"), ("bekle", 2200), ("dokun", "Şimdi puanla"), ("bekle", 1800)]),   # ekran: Chat · oturum paneli (puanlama · K8)
    "89_seyahat_duzenle": ("gokberk", [("dokun", "Planım"), ("bekle", 900), ("dokun_a11y", "Seyahati düzenle"), ("bekle", 1200)]),   # ekran: EditTrip
    "90_ilan_duzenle": ("selin",   [("dokun", "Planım"), ("bekle", 700), ("dokun_a11y", "İlanlarım"), ("bekle", 900), ("dokun", "İlanı düzenle"), ("bekle", 1200)]),   # ekran: EditAvailability
    "91_kural_damga": ("nehir", [("dokun", "Keşfet"), ("bekle", 1800), ("dokun_a11y", "Filtre"), ("bekle", 600), ("dokun", "Havalimanı seç…"), ("bekle", 600), ("yaz", "Havalimanı ara…", "ADB"), ("bekle", 800), ("ilk_metin", "ADB"), ("bekle", 900), ("dokun_a11y", "Filtre"), ("bekle", 1500), ("dokun_a11y", "Uyum"), ("bekle", 1200), ("kaydir",), ("bekle", 2600)]),   # K4 · 10/10 şart (Tuna H. · ADB) — damga
    "86_akis_nehir_sohbet":  ("nehir", [("dokun", "SOHBET"), ("bekle", 1500), ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1500)]),   # ekran: Chat (v7 · gokberk dünyasında oturum yok)
    "74_akis_nehir_baglanti":("nehir", [("dokun", "SOHBET"), ("dokun_a11y", "Bağlantılar"), ("bekle", 1200)]),   # ekran: HomeConnections
    "75_akis_arda_ana":      ("arda",  [("bekle", 1500)]),   # ekran: Home
    "76_akis_arda_kesfet":   ("arda",  [("dokun", "Keşfet"), ("bekle", 1800)]),   # ekran: Discovery
    "77_akis_arda_oturum":   ("arda",  [("dokun", "SOHBET"), ("bekle", 1500)]),   # ekran: RequestsPanel · Oturumlar
    "78_akis_arda_soru":     ("arda",  [("dokun", "SORU"), ("bekle", 1500)]),   # ekran: SoruEkrani · Gönderdiğim
    # 2 Ekim · 6.2.7 — soru alanı, davet (sorusuz), ana sayfa gövdesi, arama, rozet, bildirim
    "79_akis_nehir_soru":    ("nehir", [("dokun", "SORU"), ("bekle", 1500)]),   # ekran: SoruEkrani · Gelen
    "80_akis_nehir_davet":   ("nehir", [("dokun", "DAVET"), ("bekle", 1500)]),   # ekran: ActionNeeded
    "81_akis_nehir_govde":   ("nehir", [("bekle", 1500), ("gor", "DAVETLER"), ("bekle", 600)]),   # ekran: Home
    "82_akis_nehir_ara":     ("nehir", [("dokun", "Tanış"), ("bekle", 1200), ("yaz", "İsimle ara — tanıştığın kişiyi bul", "Ar"), ("bekle", 1500)]),   # ekran: Meet
    "83_akis_nehir_profil":  ("nehir", [("dokun", "Profil"), ("bekle", 1200)]),   # ekran: Profile
    "84_akis_nehir_bildirim":("nehir", [("dokun", "Profil"), ("dokun", "Bildirimler"), ("bekle", 1200)]),   # ekran: Notifications
    "85_akis_arda_neden":    ("arda",  [("dokun", "Keşfet"), ("bekle", 1800), ("dokun", "Neden?"), ("bekle", 900)]),   # ekran: Discovery
    "06_sohbet":       ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 1500), ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1200)]),   # ekran: Chat
    # ══════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · KAPSAM TURU — 15 SAHNE DAHA.
    # `ekran_kapsam_check.py` saydı: ana akıştaki 26 ekranın 10'unun
    # sahnesi vardı. Geri kalanına premium tur boyunca hiç bakmadım.
    # Hepsi Profil menüsünden ya da sekmeden parmakla ulaşılıyor —
    # yani bu adımlar kullanıcının gerçekten yürüdüğü yol.
    # ══════════════════════════════════════════════════════════════
    "20_ayarlar":      ("selin",   [("dokun", "Profil"), ("dokun_a11y", "Ayarlar")]),   # ekran: Settings
    "21_cuzdan":       ("selin",   [("dokun", "Profil"), ("dokun_a11y", "Cüzdan")]),     # ekran: Wallet
    "22_market":       ("selin",   [("dokun", "Profil"), ("dokun", "LoungePuan")]),     # ekran: Marketplace
    "23_degerlendirme":("selin",   [("dokun", "Profil"), ("dokun", "Değerlendirmeler")]),  # ekran: Degerlendirmeler
    "24_guvenlik":     ("selin",   [("dokun", "Profil"), ("dokun", "Güvenlik Merkezi")]),  # ekran: Safety
    "25_oturum_gecmisi":("selin",  [("dokun", "Profil"), ("dokun", "Oturum Geçmişi")]),    # ekran: SessionHistory
    "26_guven_puani":  ("selin",   [("dokun", "Profil"), ("dokun", "Güven Puanım")]),      # ekran: TrustVisual
    "27_davet":        ("selin",   [("dokun", "Profil"), ("dokun", "Arkadaşını Davet Et")]),  # ekran: Referral
    "28_kampanyalar":  ("selin",   [("dokun", "Profil"), ("dokun", "Kampanyalar")]),       # ekran: Campaigns
    "29_plan":         ("selin",   [("dokun", "Profil"), ("dokun", "Plan")]),              # ekran: Plans
    "30_yayin_davet":  ("selin",   [("dokun", "Profil"), ("dokun", "Yayın & Davet")]),     # ekran: HostBroadcast
    "31_profil_duzenle":("selin",  [("dokun", "Profil"), ("dokun_a11y", "Profilini tamamla")]),  # ekran: EditProfile
    "32_herkese_acik_profil": ("kaan", [("dokun", "Tanış"), ("dokun_a11y", "Burak S.")]),  # ekran: PublicProfile
    "33_sorularim":    ("gokberk", [("dokun_a11y", "Soru")]),                              # ekran: MyQuestions
    "34_host_ol":      ("gokberk", [("dokun", "Profil"), ("dokun_a11y", "Profilini tamamla"),
                                ("dokun_a11y", "Kartımda bir kişilik yer var")]),           # ekran: HostApply
    # 🔴 19 EYLÜL — BU SAHNE İKİ TURDUR HİÇBİR ŞEY ÖLÇMÜYORMUŞ.
    # İkinci adım `("dokun_a11y", "Ece Y.")` idi ve 4 sn'de zaman aşımına
    # uğruyordu: bağlantı satırında dokunulabilir olan şey İSİM DEĞİL
    # "Sohbeti Aç" düğmesi. Adım düşünce sahne Tanış ekranında kalıyor ve
    # `13_baglantilar`ın BİREBİR AYNI görüntüsünü kaydediyordu —
    # md5'leri eşitti (a3857667…). Yani "sohbet" sahnesi sohbeti hiç
    # görmemişti; galeri 53 sahne gösteriyor ama 52 ekran ölçüyordu.
    #
    # 🆕 SINIF: "BİR ADIM DÜŞTÜĞÜNDE SAHNE YİNE DE BİR GÖRÜNTÜ KAYDEDER —
    # O GÖRÜNTÜ BAŞKA BİR SAHNENİNKİYLE AYNIYSA, ÖLÇÜM DEĞİL KOPYADIR."
    "06b_sohbet_tanis": ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 800),
                                     ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1500)]),   # ekran: Chat
    # ══════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — GEREKÇELİ TEK BOŞLUK KAPANDI.
    # `LiveStatus` "tohumda aktif oturum yok" diye sahnesizdi. Gerekçe
    # doğruydu; ama bir gerekçeyi iki tur taşımak onu mazerete çevirir.
    # Tohuma aktif oturum eklendi (sahne_seed.sql) ve ekran artık
    # kullanıcının gerçek yolundan açılıyor: sohbetin altındaki yeşil
    # canlı-durum şeridi.
    # ══════════════════════════════════════════════════════════════
    "35_canli_durum":  ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 1500),
                                    ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1200),
                                    ("dokun", "Durumumu paylaş")]),   # ekran: LiveStatus
    # ══════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — EKRAN DEĞİL DURUM KAPSAMI.
    # 39 sahne 39 EKRAN gösteriyordu ama her ekranın TEK hâlini.
    # Keşfet kartının eylem alanının beş durumu var; ikisi çekiliyordu.
    # Aşağıdaki altı sahne kalan üç durumu ve üç BOŞ dünyayı çekiyor.
    # ══════════════════════════════════════════════════════════════
    "36_kesfet_dogrula": ("yeni",  [("dokun", "Keşfet")]),   # ekran: Discovery · telefon kapısı
    "37_kesfet_seyahat": ("hazir", [("dokun", "Keşfet")]),   # ekran: Discovery · seyahat kapısı
    "38_kesfet_kendi":   ("selin", [("dokun", "Keşfet")]),   # ekran: Discovery · kendi ilanı
    "39_ana_yeni":       ("yeni",  []),                      # ekran: Home · ilk gün
    # Seyahati HİÇ olmayan kullanıcı: ürün açılışta seyahat formunu
    # açıyor (App.js:835). Bu, hiç çekilmemiş bir İLK GÜN ekranı.
    "40_ilk_seyahat":    ("bos",   []),                      # ekran: AddVisit · ilk gün
    "41_bildirim_bos":   ("hazir", [("dokun", "Profil"), ("dokun", "Bildirimler")]),  # ekran: Notifications · boş
    # ══════════════════════════════════════════════════════════════
    # 🔴 12 EYLÜL · GECE — ÜRÜNÜN KÖTÜ GÜNÜ.
    # 45 sahnenin hepsinde sunucu çalışıyordu. `LoadFail` bileşeni
    # hiç çekilmedi; "veri gelmezse ekran ne diyor" sorusu hiç
    # sorulmadı. `?bozuk=` ile ilgili çağrı ağ hatası döndürüyor ve
    # gerisi ürünün KENDİ `catch` yolu.
    # ══════════════════════════════════════════════════════════════
    "42_kesfet_ariza":   ("kaan", [("dokun", "Keşfet")],
                          "bozuk=discover_availabilities"),          # ekran: Discovery · yükleme hatası
    "43_bildirim_ariza": ("gokberk", [("dokun", "Profil"), ("dokun", "Bildirimler")],
                          "bozuk=notifications"),                    # ekran: Notifications · yükleme hatası
    "44_cuzdan_ariza":   ("selin", [("dokun", "Profil"), ("dokun_a11y", "Cüzdan")],
                          "bozuk=credit_ledger"),                    # ekran: Wallet · yükleme hatası
    # 🔴 UZUN İÇERİK — üç mesajlık sohbet ve beş satırlık liste, ürünü
    # yalnız kısa içerikte ölçüyordu. Tohumda artık 21 mesaj ve 29
    # bildirim var; bu iki sahne onların ALTINI gösteriyor.
    "45_sohbet_uzun":    ("gokberk", [("dokun_a11y", "Sohbet:"), ("bekle", 1500),
                                      ("dokun_a11y", "Sohbeti Aç"), ("bekle", 1200),
                                      ("kaydir",), ("bekle", 700)]),   # ekran: Chat · 21 mesaj
    "46_bildirim_uzun":  ("gokberk", [("dokun", "Profil"), ("dokun", "Bildirimler"),
                                      ("kaydir",), ("bekle", 700)]),  # ekran: Notifications · 29 satır
    # ══════════════════════════════════════════════════════════════
    # 🔴 13 EYLÜL · GÖKBERK NOT2 — PLANIM'IN BOŞ HÂLİ VE ROL KAYBI.
    #
    # Not2 iki şey sordu: (a) boş görünümde başlıktaki çipler fazla
    # yukarıda mı, (b) çipler neden yok — ve "host tarafında da
    # yaşanmadığından emin ol".
    #
    # Üç sahne de bunu ÖLÇMEK için var:
    #   47  boş host · İlanlarım  → çipler boş ekranda nerede duruyor
    #   48  boş host · Seyahatlerim → aynı bant, öbür çip seçili
    #   49  ROL KAYBI: `users` sorgusu düşerse host ne görüyor.
    #       Rol YALNIZ Home'un yükleyicisinden geliyordu; Home düşerse
    #       host kalıcı olarak misafir gibi çiziliyor ve İlanlarım'a
    #       giden KAPI KAPANIYOR. Sahne bunu kanıtlıyor.
    # ══════════════════════════════════════════════════════════════
    "47_ilanlarim_bos":   ("boshost", [("dokun", "Planım")]),                         # ekran: Hosting · boş
    "48_seyahat_bos_host":("boshost", [("dokun", "Planım"), ("dokun_a11y", "Seyahatlerim")]),  # ekran: Trips · boş host
    "49_planim_rol_kaybi":("selin",   [("dokun", "Planım")], "bozuk=users"),          # ekran: Trips · rol gelmedi
}

class Sessiz(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

def sunucu():
    socketserver.TCPServer.allow_reuse_address = True
    h = functools.partial(Sessiz, directory=DIST)
    srv = socketserver.TCPServer(("127.0.0.1", 0), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, srv.server_address[1]

def kopru_baslat():
    p = subprocess.Popen([sys.executable, os.path.join(KOK, "pg_kopru.py"), str(KOPRU_PORT)],
                         stdout=subprocess.DEVNULL, stderr=open(os.path.join(OUT, "_kopru.log"), "w"))
    time.sleep(0.8)
    return p

# v7.2 — yüzen cam sekme çubuğunun ARKASINA içerik uzanıyor (40pt). Ekranın dibindeki bir
# düğme görünür ama çubuğun altında kalabilir; kullanıcı kaydırır, sahne de ortalar.
def ortala(loc):
    try:
        # Yalnız iç kaydırma kabı kaysın: scrollIntoView pencereyi de kaydırıyor ve sonra açılan
        # Modal o kadar yukarı kayık çiziliyordu (ölçüldü: 50_istek_gonder bandı kesik).
        loc.evaluate("e => { e.scrollIntoView({ block: 'center', inline: 'nearest' }); window.scrollTo(0, 0);"
                     " document.documentElement.scrollTop = 0; document.body.scrollTop = 0; }", timeout=3000)
    except Exception:
        pass

def adim_uygula(pg, adim, kayit):
    tur = adim[0]
    try:
        if tur == "dokun":
            # DOM metni CSS `text-transform`tan ÖNCEKİ hâl; büyük/küçük harf duyarsız ara.
            loc = pg.get_by_text(re.compile("^\\s*" + re.escape(adim[1]) + "\\s*(→|›)?\\s*$", re.I))
            try:
                loc.last.click(timeout=1500)
            except Exception:
                ortala(loc.last)
                loc.last.click(timeout=4000)
        elif tur == "dokun_a11y":
            hedef = pg.get_by_label(re.compile(re.escape(adim[1]), re.I)).first
            try:
                hedef.click(timeout=1500)
            except Exception:
                ortala(hedef)
                hedef.click(timeout=4000)
        elif tur == "ilk_metin":
            pg.get_by_text(re.compile("^\s*" + re.escape(adim[1]), re.I)).first.click(timeout=4000)
        elif tur == "kart_uyum":
            # 3 Ekim — belirli bir KARTIN uyum mührüne dokun (tüm mühürlerin etiketi aynı: "Uyum puanı: NN").
            kart = pg.locator("div", has_text=adim[1]).filter(has=pg.get_by_label(re.compile("Uyum", re.I))).last
            hedef = kart.get_by_label(re.compile("Uyum", re.I)).first
            ortala(hedef)
            hedef.click(timeout=4000)
        elif tur == "yaz":
            pg.get_by_placeholder(adim[1]).first.fill(adim[2], timeout=4000)
        elif tur == "bekle":
            pg.wait_for_timeout(adim[1])
        elif tur == "gor":
            # 2 Ekim — sayfanın ORTASINDAKİ bir bölümü kadraja getir (kaydir yalnız sona gider).
            loc = pg.get_by_text(re.compile(r"^\s*" + re.escape(adim[1]) + r"\s*$", re.I))
            loc.first.scroll_into_view_if_needed(timeout=4000)
        elif tur == "kaydir":
            # ══════════════════════════════════════════════════════════
            # 🔴 20 EYLÜL — "UZUN İÇERİK" SAHNELERİ UZUNU HİÇ GÖSTERMİYORDU.
            #
            # `45_sohbet_uzun` ve `46_bildirim_uzun` 12 Eylül'de "listenin
            # ALTINI göstersin" diye eklenmiş. Ama `cek.py`de KAYDIRMA
            # ADIMI YOKTU: ikisi de kısa kardeşiyle (06 · 10) aynı ilk
            # ekranı çekiyordu ve `ayni_sahne_check.py` onları ikiz
            # buluyordu. Tohumda 21 mesaj ve 29 bildirim GERÇEKTEN var
            # (ölçtüm: notifications'ta bir kullanıcıda 29 satır) —
            # görünmeyen şey veri değil, KADRAJDI.
            #
            # 🆕 SINIF: "BİR SAHNEYİ 'UZUN İÇERİK' DİYE ADLANDIRMAK ONU
            # UZUN İÇERİĞE GÖTÜRMEZ — KADRAJI TAŞIYAN ADIM YOKSA, AD
            # BİR NİYET BEYANIDIR, BİR ÖLÇÜM DEĞİL."
            #
            # En içteki kaydırılabilir kabı bulup sonuna götürüyoruz;
            # `window.scrollTo` çalışmıyor çünkü RNW listeleri kendi
            # `overflow:auto` kabında kayıyor.
            # ══════════════════════════════════════════════════════════
            pg.evaluate("""() => {
              const kaydirir = e => {
                const c = getComputedStyle(e);
                return (c.overflowY === 'auto' || c.overflowY === 'scroll')
                       && e.scrollHeight > e.clientHeight + 40;
              };
              const hepsi = [...document.querySelectorAll('*')].filter(kaydirir);
              if (!hepsi.length) return 0;
              const en = hepsi.reduce((a, b) =>
                (b.scrollHeight - b.clientHeight) > (a.scrollHeight - a.clientHeight) ? b : a);
              en.scrollTop = en.scrollHeight;
              return en.scrollHeight;
            }""")
        pg.wait_for_timeout(1200)
    except Exception as e:
        kayit["errors"].append("adım %s: %s" % (adim, str(e).splitlines()[0][:200]))

# ════════════════════════════════════════════════════════════════════════
# 🔴 19 EYLÜL — SAHNE KİŞİLERİ ÖNCE VARLIKLARINI KANITLIYOR.
#
# `18_ana_host1` ve `19_ana_guest1` sahneleri SEED6'nın iki hesabına
# bakıyor. Ölçtüm: o iki kullanıcı veritabanında YOKTU (0 satır). Sebep
# `pg_run.py`nin dosya seçimi:
#
#     re.match(r"^(\d{3})([a-z]?)_", b)
#
# Yalnız NUMARALI migration'ları alıyor — `SEED6_TEST_DUNYASI.sql` hiç
# koşmuyor. Ama sahne yine de bir görüntü kaydediyordu: oturum var
# sayılıyor, veri yok, uygulama "Host Kurulumu · Adım 1/2" sihirbazına
# düşüyor. İKİ SAHNE DE AYNI SİHİRBAZI çekti — md5'leri eşitti.
#
# Yani galeri 53 sahne gösteriyordu ama 51 ekran ölçüyordu, ve bunu
# söyleyen hiçbir şey yoktu.
#
# 🆕 SINIF: "BİR SAHNE, BAKTIĞI KİŞİNİN VAR OLDUĞUNU ÖNCE KANITLAMALI —
# YOKSA BOŞLUĞUN FOTOĞRAFINI ÇEKER VE ONU VERİ SANIR."
# ════════════════════════════════════════════════════════════════════════
def dunyayi_tazele():
    """
    ══════════════════════════════════════════════════════════════════
    🔴 20 EYLÜL — SAHNE DÜNYASI YAŞLANIYORDU VE KİMSE SÖYLEMİYORDU.

    `ayni_sahne_check.py` dört sahneyi ikiz buldu (06 · 06b · 35 · 45).
    Tek tek ölçtüm ve kök şu çıktı:

        chat_channels  request  →  status **completed**  ·  21 mesaj

    `sahne_seed.sql` o isteği `accepted` yazıyor ve oturumu `active`
    başlatıyor — ama her şeyi `now()`a göre. Tohum GÜNLER ÖNCE atılmıştı;
    aradan geçen zamanda süpürge/vade fonksiyonları oturumu kapatıp
    isteği `completed` yapmıştı. Doğru davranış — ama dünya artık
    sahnelerin yazıldığı dünya değildi:

        · "İstek:" sayacı 0 gösteriyordu → o yoldan giren 3 sahne düştü
        · 21 mesajlık sohbete ULAŞILABİLİR YOL kalmamıştı
        · "Durumumu paylaş" (canlı oturum) hiç çizilmiyordu

    Ve hiçbir şey bunu söylemiyordu: sahneler "çekildi" diyordu,
    görüntüler birbirinin kopyasıydı.

    🆕 SINIF: "`now()` İLE KURULAN BİR TOHUM YALNIZ KURULDUĞU AN
    DOĞRUDUR — ONU HER KOŞUDA YENİDEN ATMAZSAN DÜNYA SESSİZCE YAŞLANIR
    VE SAHNELER, ÜRÜNÜ DEĞİL GEÇMİŞİ ÇEKMEYE BAŞLAR."

    Bu yüzden her çekimden ÖNCE tohum yeniden atılıyor. Başarısız
    olursa sessizce geçilmiyor: uyarı basılıyor, çünkü bayat bir dünya
    üstünde çekilen sahneler yanlış cevap verir.
    ══════════════════════════════════════════════════════════════════
    """
    tohum = os.path.join(KOK, "sahne_seed.sql")
    if not os.path.exists(tohum):
        return
    for psql in ("psql", "/usr/lib/postgresql/16/bin/psql", "/usr/bin/psql"):
        try:
            r = subprocess.run([psql, "-h", "127.0.0.1", "-U", "postgres", "-d", "ll",
                                "-v", "ON_ERROR_STOP=1", "-q", "-f", tohum],
                               capture_output=True, text=True, timeout=180)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
        if r.returncode == 0:
            print("  ✓ sahne dünyası tazelendi (sahne_seed.sql)")
            # 4 Ekim — akış dünyası (akis.* · Nehir/Arda/Cem/Bora/Duru…) da now()'a göre
            # kurulu ve uçtan uca test onu DEĞİŞTİRİYOR (kabul/ret/erteleme). Her koşu
            # SEED8 → SEED9'dan başlar; yoksa ikinci koşu birincinin artığını test eder.
            for ad in ("SEED8_AKIS_TEZGAHI.sql", "SEED9_AKIS_GENIS.sql"):
                yol = os.path.join(KOK, "..", "..", "sql", ad)
                if not os.path.exists(yol):
                    continue
                r2 = subprocess.run([psql, "-h", "127.0.0.1", "-U", "postgres", "-d", "ll",
                                     "-v", "ON_ERROR_STOP=1", "-q", "-f", yol],
                                    capture_output=True, text=True, timeout=300)
                print(("  ✓ akış dünyası tazelendi (%s)" % ad) if r2.returncode == 0 else
                      ("  ⚠ %s ATILAMADI: %s" % (ad, ((r2.stderr or "").strip().splitlines() or [""])[-1][:160])))
        else:
            print("  ⚠ TOHUM ATILAMADI — sahneler BAYAT bir dünyada çekiliyor:")
            print("     " + (r.stderr or "").strip().splitlines()[-1][:160])
        return
    print("  ⚠ psql bulunamadı — tohum atılamadı, dünya bayat olabilir.")


def kisileri_dogrula(sahneler):
    import json as _json
    kis = os.path.join(KOK, "sahneler.js")
    metin = open(kis, encoding="utf-8").read()
    harita = {}
    for m in re.finditer(r"(\w+):\s*\{\s*id:\s*\"([0-9a-f-]{36})\"", metin):
        harita[m.group(1)] = m.group(2)

    gerekli = sorted({SAHNELER[a][0] for a in sahneler if SAHNELER[a][0]})
    bilinmeyen = [k for k in gerekli if k not in harita]
    if bilinmeyen:
        print("✗ sahneler.js'te tanımsız kişi: " + ", ".join(bilinmeyen))
        sys.exit(1)

    try:
        sys.path.insert(0, os.path.join(KOK, "..", "render_check"))
        import pg8000_psycopg2; pg8000_psycopg2.kur()   # Windows: DLL engelliyse saf Python katman
        import psycopg2
    except ImportError:
        print("  ⚠ psycopg2 yok — kişi doğrulaması ATLANDI (sahneler boş çıkabilir).")
        return
    kon = psycopg2.connect(host="127.0.0.1", user="postgres", dbname="ll")
    cur = kon.cursor()
    cur.execute("select id::text from users where id::text = any(%s)",
                ([harita[k] for k in gerekli],))
    var = {r[0] for r in cur.fetchall()}
    kon.close()

    eksik = [(k, harita[k]) for k in gerekli if harita[k] not in var]
    if eksik:
        print("=" * 74)
        print("✗ SAHNE KİŞİSİ VERİTABANINDA YOK — bu sahneler BOŞLUĞUN")
        print("  fotoğrafını çeker ve sessizce yeşil yanar:")
        for k, i in eksik:
            sahne = [a for a in sahneler if SAHNELER[a][0] == k]
            print("    %-9s %s   → %s" % (k, i, ", ".join(sahne)))
        print("")
        print("  ÇÖZÜM: eksik tohumu koş. `pg_run.py` yalnız NUMARALI")
        print("  migration'ları koşar; SEED dosyaları elle koşulur:")
        print("      psql -d ll -f sql/SEED6_TEST_DUNYASI.sql")
        print("      psql -d ll -f rnapp/web_sahne/sahne_seed.sql")
        print("=" * 74)
        sys.exit(1)
    print("  ✓ %d sahne kişisinin hepsi veritabanında var." % len(gerekli))


def cek(sahneler, tam=False):
    dunyayi_tazele()
    kisileri_dogrula(sahneler)
    srv, port = sunucu()
    kopru = kopru_baslat()
    try:
        with sync_playwright() as p:
            exe = "/opt/pw-browsers/chromium/chrome"
            b = p.chromium.launch(executable_path=exe if os.path.exists(exe) else None)
            for ad in sahneler:
                # Sahne üçlü de olabilir: (kim, adımlar, ek_sorgu)
                # `ek_sorgu` → URL'e eklenen parametreler (ör. bozuk=...).
                kayit_sahne = SAHNELER[ad]
                kim, adimlar = kayit_sahne[0], kayit_sahne[1]
                ek = kayit_sahne[2] if len(kayit_sahne) > 2 else ""
                ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=3,
                                    is_mobile=True, has_touch=True, locale="tr-TR",
                                    user_agent="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
                pg = ctx.new_page()
                kayit = {"console": [], "errors": []}
                pg.on("console", lambda m: kayit["console"].append({"t": m.type, "s": m.text[:400]})
                      if m.type in ("error", "warning") and "useNativeDriver" not in m.text else None)
                pg.on("pageerror", lambda e: kayit["errors"].append(str(e)[:600]))
                pg.goto(f"http://127.0.0.1:{port}/?sahne={ad}&kim={kim}&dil={DIL}"
                        f"&kopru=http://127.0.0.1:{KOPRU_PORT}" + (("&" + ek) if ek else ""),
                        wait_until="networkidle")
                try:
                    pg.wait_for_function("window.__LL_HAZIR === true", timeout=10000)
                except Exception:
                    kayit["errors"].append("__LL_HAZIR beklenmedi (10s)")
                for adim in adimlar:
                    adim_uygula(pg, adim, kayit)
                pg.wait_for_timeout(900)
                # 3 Ekim: soğuk tarayıcıda ilk sahnede görseller (açılış kanadı) henüz yüklenmemiş olabiliyordu
                # → kare kanatsız çekildi. Bütün <img>'ler tamamlanana kadar bekle (en çok 6 sn).
                try:
                    pg.wait_for_function("Array.from(document.images).every(i => i.complete && i.naturalWidth > 0)", timeout=6000)
                except Exception:
                    kayit["errors"].append("gorseller 6 sn'de yuklenmedi")
                # Windows'ta PNG yazımı arada kilitleniyor (Errno 22, iki kez ölçüldü): 4 deneme.
                for _den in range(4):
                    try:
                        pg.screenshot(path=os.path.join(OUT, f"{ad}.png"), full_page=tam)
                        break
                    except OSError:
                        time.sleep(0.8)
                try:
                    kayit["calls"] = pg.evaluate("(globalThis.__CALLS||[]).filter(c=>c.kind==='logError'||c.error)")
                    kayit["metin"] = [s for s in pg.evaluate("document.body.innerText").split("\n") if s.strip()][:90]
                    # 🔴 12 EYLÜL (Gökberk md.4) — EKRANDAN TAŞAN KUTULAR.
                    # `tasma_check.js` metnin KENDİ kutusuna sığıp sığmadığını
                    # ölçüyor; telefon doğrulama şeridinde metin kendi
                    # kutusuna sığıyordu — KUTU 638 pt'ydi, ekran 390.
                    # Yani yanlış olan metin değil kutuydu ve o sınıf hiç
                    # ölçülmüyordu. Artık her sahne kendi taşan kutularını
                    # bildiriyor (`kutu_tasma_check.py` okuyor).
                    kayit["tasan"] = pg.evaluate("""() => {
                      const V = 390, cik = [];
                      const kaydirirMi = e => {
                        const c = getComputedStyle(e);
                        return c.overflowX === "auto" || c.overflowX === "scroll" ||
                               c.overflow === "auto" || c.overflow === "scroll";
                      };
                      document.querySelectorAll("*").forEach(e => {
                        const r = e.getBoundingClientRect();
                        if (r.width <= V + 0.5) return;
                        // yatay kaydırılan bir atanın içindeyse taşma değil
                        let q = e.parentElement, kaydirilir = false;
                        while (q && q !== document.body) { if (kaydirirMi(q)) { kaydirilir = true; break; } q = q.parentElement; }
                        if (kaydirilir || kaydirirMi(e)) return;
                        const tx = (e.textContent || "").trim().slice(0, 60);
                        cik.push({ g: Math.round(r.width), sol: Math.round(r.left), tx: tx });
                      });
                      // yalnız EN İÇTEKİ taşanlar: aynı metni taşıyan ata zincirini tekrar yazma
                      return cik.filter((a, i) => !cik.some((b, j) => j !== i && b.tx && a.tx === b.tx && b.g <= a.g && j > i)).slice(0, 20);
                    }""")
                    # 🔴 12 EYLÜL (Gökberk md.6) — İKON İLE METİN ARASINDAKİ BOŞLUK.
                    # "plan sayfasında ayda x kredi yazan yerin yanındaki icon
                    # bitişik duruyor text ile". Kaynaktan aramak yanıltıcı
                    # (boşluk `gap`ten, `marginRight`ten ya da ebeveynden
                    # gelebiliyor); GERÇEK ÇİZİMDEN ölçüyoruz: ikon
                    # kutusunun sağ kenarı ile sağındaki metnin sol kenarı.
                    kayit["bitisik"] = pg.evaluate("""() => {
                      const ESIK = 4, cik = [];
                      const ikonMu = e => {
                        const ff = getComputedStyle(e).fontFamily || "";
                        return /ionicons|llsimge/i.test(ff);
                      };
                      // mutlak konumlu bir kutunun içindeyse (rozet sayacı gibi)
                      // yan yana durmaları YERLEŞİM değil, üst üste bindirmedir
                      const mutlakMi = e => {
                        let q = e;
                        for (let i = 0; i < 6 && q; i++) {
                          if (getComputedStyle(q).position === "absolute") return true;
                          q = q.parentElement;
                        }
                        return false;
                      };
                      document.querySelectorAll("*").forEach(e => {
                        if (!ikonMu(e) || e.children.length || mutlakMi(e)) return;
                        const ri = e.getBoundingClientRect();
                        if (!ri.width) return;
                        // ikonun sarmalayıcısını bul, YALNIZ onun kardeşlerinde ara:
                        // böylece ekranın öbür ucundaki bir metinle eşleşmeyiz
                        const kap = e.parentElement && e.parentElement.parentElement;
                        if (!kap) return;
                        let en = null;
                        kap.querySelectorAll("*").forEach(o => {
                          if (o === e || o.children.length || ikonMu(o) || mutlakMi(o)) return;
                          const tx = (o.textContent || "").trim();
                          if (!tx) return;
                          const r = o.getBoundingClientRect();
                          if (!r.width || r.left < ri.right - 0.5) return;
                          if (r.bottom <= ri.top + 1 || r.top >= ri.bottom - 1) return;   // aynı satır değil
                          if (r.left - ri.right > 24) return;                             // uzaktaki metin bu ikonun eşi değil
                          if (!en || r.left < en.r.left) en = { o, r, tx };
                        });
                        if (!en) return;
                        const bos = en.r.left - ri.right;
                        if (bos < ESIK) cik.push({ bos: +bos.toFixed(1), tx: en.tx.slice(0, 40) });
                      });
                      return cik.slice(0, 20);
                    }""")
                except Exception as e:
                    kayit["errors"].append("evaluate: " + str(e)[:200])
                json.dump(kayit, open(os.path.join(OUT, f"{ad}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
                print(f"{ad:18s} konsol={len(kayit['console']):2d} hata={len(kayit['errors'])} db/logError={len(kayit.get('calls', []))}")
                ctx.close()
            b.close()
    finally:
        srv.shutdown()
        kopru.terminate()

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cek(args or list(SAHNELER), tam="--tam" in sys.argv)
