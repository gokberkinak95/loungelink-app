# DEVIR · 2 Ekim 2026 · oturum durum makinesi · bildirimler · soru akışı · ana sayfa · app 6.2.7

Önceki: `2026-10-01b_akis-bilgi-mimarisi-ve-test-verisi-626.md`. Dal `pc-5.17.1`.

## Sürüm
- app 6.2.7 · versionCode 278 · buildNumber 272 (package + lock aynı). BO/site değişmedi.
- Build ALINMADI: tasarım değişikliği var → önce önizleme + Gökberk onayı.

## Supabase SQL (sırayla) — `sql/SQL_SIRA.txt` ile aynı
(311, 312 koşulmadıysa önce onlar.)
1. `313_akis_durum_makinesi_bildirim_soru.sql` (tekrar koşulabilir; yerelde iki kez temiz)
2. `314_soru_yazili_yanit_ve_baglanti.sql` (tekrar koşulabilir; yerelde iki kez temiz)
3. `SEED8_AKIS_TEZGAHI.sql` → 4. `SEED9_AKIS_GENIS.sql`

## 2 Ekim akşam — Gökberk'in iki notu (aynı 6.2.7)
- **Soru = yazılı yanıt + bağlantı isteği (314)** — 313'ün Evet/Hayır'ı kalktı. Soru yine bağlantı
  isteğiyle gider (akış korunuyor). Host yazar → Gönder (`soruya_cevap_yaz`); yanıt sorana bildirim +
  Sorduklarım. Bağlantı kararı ayrı: "Kabul et, sohbeti aç" → sohbet SORU + YANIT ile açılır, oradan
  sürer; "Şimdi değil" → yanıt gider, sohbet açılmaz. Zaten bağlıysanız yeni istek GİTMEZ, soru
  aradaki sohbete mesaj olarak düşer (`ilan_kurali_sor` → `sohbete_eklendi`). Kabul edilen soru artık
  gerçek bir bağlantı (hediye listesi dahil).
- **Düz / derin "Kabul et"** — `purple` varyantı Eylül'den beri altına eşliydi ama gradyan + gölge yalnız
  `gold`a çiziliyordu → bağlantı kabul / sohbeti aç / bağlantı gönder (6 yer) düz görünüyordu. Kaynağında
  (`Btn.anaEylem`) düzeldi. Keşfet'teki elle çizilmiş düz "Host'a sor" da `Btn`'e çevrildi.

## Gökberk'in 2 Ekim maddeleri → kök neden → yapılan
- **5 · Kabulü geri al "oturum başladı" diyordu** — ÖLÇÜLDÜ: geri alma/iptal kapısı, tek tarafın
  bastığı `pending` oturumu "başladı" sayıyordu (4 fonksiyonda 4 ayrı yazım). Tek tanım:
  `istegin_acik_oturumu_var_mi` = yalnız `active` (iki taraf bastı). respond_request, cancel_request,
  cancel_availability buna bağlandı; tek taraflı başlatılmış oturum satırı da kapanıyor.
  Hata mesajı artık onay penceresinin İÇİNDE (eskiden listenin en altına düşüyordu).
- **6 · İptal sonrası ilan "dolu" görünüyordu** — ÖLÇÜLDÜ: sunucu doğruydu (istek cancelled, slot
  geri sayıldı; ana sayfa 0/1 diyordu). İlanlarım veriyi YALNIZ montajda okuyordu. Sohbetten her
  dönüş (geri oku + Android geri tuşu) `reload` verir → İlanlarım/Seyahatlerim/sayaçlar tazelenir.
  Uçtan uca kanıt: yeni `iptal_akisi_e2e` (43/43) — her senaryoda istek, oturum, dolu sayısı,
  misafir bakiyesi (TAM iade), bildirim metni ölçülüyor. Seyahat sil/düzenle (bağlı başvuru varken
  engelli) ve ilan düzenle (dolu slotun altına inemez) zaten güvenliydi.
- **7 · İptal edilen oturumda yazışma** — sunucu zaten reddediyordu (RLS); ekran yazma kutusunu
  açık bırakıyordu. Sohbet artık isteğin GÜNCEL durumunu + engeli okuyor: iptal/geri alınmış/süresi
  dolmuş/engelli çiftte salt okunur (yazma kutusu ve hızlı cevaplar yerine sakin şerit). Tamamlanmış
  buluşmada yazışma açık kalır. "Sorun bildir" iptal edilmiş buluşmada KALIR (kapıda ret sonrası
  oturum iptal olur; itiraz yolu orası). Şikayet ekranında "bu kişiyi de engelle" VARSAYILAN AÇIK.
- **11 · Hızlı cevap şeridi siyah** — `C.bg` idi, yazma alanı `C.card`; aynı zemine alındı.
- **2 · "Doğrulayamadık" ↔ "doğruladık" çelişkisi** — ÖLÇÜLDÜ: rozet/panel metni
  `lounge_access_decision_v5(ilan, misafirin uçuşu, taşıyıcısı)` ile, soru kapısı
  `lounge_access_decision(ilan, null)` ile karar veriyordu; panel metni de düğmeden bağımsız
  seçiliyordu. Tek karar: `kural_sorusu_durumu` (rozetle aynı hesap) → uygun / dogrulanmis / tasiyici /
  charter / gerek_yok / bilinmiyor. Rozet metni buna göre (yeni `guest_none_noask`), sunucu sebebiyle
  reddeder (`rule_ask_*`, TR+EN errMap), red olursa kart rozeti yeniden çekilir.
  Not: THY salonlarında Business bileti her yerde DOĞRULANMIŞ "misafir yok" → orada soru yok.
- **2 (ek) · Soru = bağlantı kabulüydü** — yanıtlamak bağlantıyı KABUL etmekti: sohbet açılıyor ve
  soran kişi host'un bağlantısı oluyordu (yalnız-bağlantılarım ilanları, profil görünürlüğü, Sohbet
  sayısı). Artık `soruyu_yanitla(Evet/Hayır + not)`: status=declined + cevap alanları, sohbet YOK.
  Eski istemci `respond_connection` ile yanıtlarsa aynı yola yönlenir.
- **3 · 10 · Sorular Davet'teydi** — `pending_actions` sorusuz; Soru ekranı GELEN · GÖNDERDİĞİM
  (`SoruEkrani`, `bana_gelen_sorular`); "Evet" diyen host'a "Hakkını ilanına ekle" → erişim hakkı.
- **4 · Bildirimler** — envanter: neredeyse her olayda vardı ve hepsi push'a gidiyordu; eksik olan
  isim ve doğruluktu. `bildir()` (alıcının dilinde TR/EN), `kisa_ad()`. İsimli: başvuru, kabul, ret,
  KABULÜ GERİ ALDI (ayrı), misafir iptali, ilan kaldırıldı, oturumu başlattı-sen de bas, oturum
  başladı, tamamladı-sen de tamamla, tamamlandı-puanla, iptal, davet, davet kabul/ret, bağlantı,
  soru yanıtı. Davet kabulündeki "oturum başladı" yanlışı düzeldi. Hatırlatmalar YAZILMIŞTI AMA HİÇ
  ZAMANLANMAMIŞTI → pg_cron: 1 saat kala (yeni `yaklasan_bulusma_hatirlat`, 10 dk), yarın (günlük),
  puanlama (saatlik) — `zamanli_is_kos` üzerinden (BO zamanlanmış işler sayfası izler).
  Bildirime dokununca: istek → İstek · kabul/oturum/1 saat → o buluşmanın sohbeti · davet/bağlantı
  isteği → Davet · kabul edilen bağlantı → Bağlantılar · soru → Soru (`bildirim_hedefi`).
- **8 · Ana sayfa kartları** — üçü de host'un İLANI idi; "İLANLARIM · N · Tümü" başlığı, etiket
  İlanlarım diliyle ("Yayında · 1 yer açık / dolu"), "Keşfet'te gör" → "İlanı yönet".
- **9 · Sayılar** — gövde "gelen 3 · 4 kabul · gönderdiğin 2" (her durum) sayıyordu; artık başlıktaki
  İstek kutusuyla aynı küme (yalnız yanıt bekleyen).
- **Öneri 1+2 (ana sayfa)** — karar: ikinci öneri + birincinin işareti. Davet/İstek/Soru gövdede
  AYNI kalıpta akordeon, en fazla 3 satır, fazlası "Diğer N … alanına git". Kutularda YENİ noktası
  (`akis_goruldu`): son bakıştan sonra gelen varsa yanar, alana girince söner; o ziyarette yeniler
  ince altın çerçeve + YENİ etiketi taşır, sonraki ziyarette taşımaz.
- **Tanış araması** — liste isimle süzülür (kelime başı, Türkçe duyarsız); 2+ harfte sunucuda
  `kisi_ara` (Tanış'ın gizlilik kurallarının aynısı: keşifte görünme, kadın güvenlik modu, engel,
  test/personel, profil görünürlüğü; en az 2 harf, en çok 20 sonuç).
- **Profil · Bildirimler** — satırda okunmamış sayısı; Bildirimler'de görünür "Tümünü okundu işaretle"
  (eskiden yalnız "Tümü" çipine uzun basınca).
- **1 · Keşfet "İstek gönder" solda** — `Btn cip` kendi alignSelf'iyle kabın flex-end'ini eziyordu.
- Yan bulgu: Cüzdan › misafir hakkı hediye listesi bekleyen/reddedilmiş/soru satırlarını da
  gösteriyordu (sunucu zaten reddediyordu) → yalnız kabul edilmiş bağlantılar.

## Testler
- check.js temiz · render 77/13/12 · 53 ekran 0 · giriş 37/37
- e2e: iptal_akisi 47/47 (YENİ; soru bölümü 314'e göre) · tam_akis 171/171 (7. adım yeni kurala göre: "iki taraf başlattıktan
  sonra istekten iptal → session_started"; eski adım tek taraflı basışı kilit sayıyordu) ·
  flow_matrix 27/27 · rule_dims 55/55 · edge 19/19 · onboarding 16/16 · rpc_field temiz · two_account 14/14
- SEED8+SEED9 yerelde: kutu = liste (host İstek 4 · Sohbet 6 · Davet 2 · Soru 1; misafir 1 · 4 · 2 · 1)
- Web sahneleri 70–85: hata 0, db/logError 0

## Açık / Gökberk'ten beklenen
- Önizleme onayı → 6.2.7 build.
- 313'ü canlıda koş (pg_cron işleri orada kurulur; NOTICE "hatirlatma isleri zamanlandi").
- Bilinen sınır: rozet metinleri (badge_labels) yalnız TR.
- Öneri (sonraki tur): profilde kısa "tanışma kodu" — gizli profillerde bile yüz yüze bağlantı.
