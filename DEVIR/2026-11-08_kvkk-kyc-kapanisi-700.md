# DEVİR · 8 Kasım 2026 · KYC kapanışı · doğrulanmış profil · KVKK metinleri

Önceki devir: `2026-10-20_odul-erken-erisim-indirim-690.md` (6 Kasım'a kadar ekli).

## 6–8 Kasım arası (özet)
- Firebase: proje loungelink-b9f35; Android co.loungelink.app (4 SHA), iOS co.loungelink.app, APNs anahtarı, Phone Auth,
  Play Integrity. EAS dosya değişkenleri GOOGLE_SERVICES_JSON / GOOGLE_SERVICE_INFO_PLIST. FCM V1 anahtarı EAS'ta.
- Android paket adı **co.loungelink.app** (com.loungelink.app Play'de alınmıştı). AAB 1.0.0 (301) Play iç teste yüklendi.
- iOS: RNFB auth eklentisi yerine kendi eklentimiz (REVERSED_CLIENT_ID yok); `react-native.config.js` RNFB yolu açık.
- Play formları (içerik derecelendirme, hedef kitle, veri güvenliği, satıcı beyanı, mağaza girişi TR+EN) Gökberk tarafından dolduruldu.
- Hukuk denetimi (ajan) → Gökberk kararı: **KYC kaldırılır**, hukuk "bireysel geliştirici seviyesinde" kalır
  (bkz. hafıza `hukuk-seviyesi`: ek hukuki yük önerilmez).

## Bu tur ne değişti
**SQL 345** `sql/345_kyc_kapanisi_dogrulanmis_profil_kvkk.sql`
- KYC kapalı (`kimlik_belgesi_gonder` → `kyc_kapali`), kyc kovası yazma kuralları silindi, belge yolları temizlendi.
- `verifications.id_verified` artık **Doğrulanmış profil** = e-posta + telefon (SMS, bypass değil) + foto + meslek;
  `profil_dogrulama_esitle` + iki tetikleyici. Okuyan her yer (istek rozeti, profil rozeti, `yalniz_kimlikli` ilan kapısı) yeni anlamla çalışır.
- `recompute_trust`: telefon 14, foto 6 (yeni `photo`), oturum 8/13/18, puan 14/8/3; üst sınır aynı. Herkes yeniden hesaplanır.
- Pazarlama izni: `users.pazarlama_izni(_at)`, `pazarlama_izni_yaz`, `grant_consents` 'pazarlama_bildirimi' tipini görünce açar,
  `bildirim_tercihlerim` döndürür, `send_campaign` yalnız izinliye + "Kapatmak için: Ayarlar › Bildirimler." satırı.
- `admin_anonymize_user`: cinsiyet, pazarlama izni, bildirimler, bildirim tercihleri, user_contact, kimlik izleri.
- `saklama_suresi_imha()` + pg_cron `ll-saklama-imha` 04:10: app_errors/notifications/flight_fetch_log 12 ay, messages 24 ay,
  reports 5 yıl, anonim hesap consents 10 yıl, onceki_epostalar 5 yıl.

**App** (1.0.0 · Android versionCode 302 · iOS buildNumber 296)
- `App.js`: kayıtta ve sosyal giriş tamamlamada ayrı, işaretsiz pazarlama kutusu (Tümünü kabul et'e dahil değil);
  onay sürümü v16 → v17; kimlik ekranına giden yollar kaldırıldı (doğrulama ekranındaki 3. satır → Profili Düzenle).
- `src/screens.js`: Ayarlar › Bildirimler'de "Kampanya ve duyurular" anahtarı (pazarlama_izni_yaz); "system" satırı "Hizmet duyuruları";
  hesap silmede avatars kovasındaki dosyalar silinir (liste silme çağrısıyla aynı dalgada).
- `src/ekranlar_ana.js`: güven puanı dökümü yeni ağırlıklar + "Profil fotoğrafı"; Profili Düzenle'de "Doğrulanmış profil" satırı.
- `src/ekranlar_yalin.js`: doğrulama ekranı telefon +14, foto +6; puan ekranından sunucuda hiç verilmeyen kimlik +400 / LinkedIn +150 vaatleri çıktı.
- `src/telefon.js`: +14 / "+6 Sonraki adım: profil fotoğrafı ekle".
- `src/i18n.js`: ~25 metin TR+EN (doğrulanmış profil, kadın modu "telefonu doğrulanmış", c1 aydınlatma "okudum", cPazarlama,
  kyc_kapali errMap, partnersNote marka notu, biyografi 40 karakter); 11 ölü anahtar silindi.
- `src/legal.js` (LEGAL_VERSION 2026-11-08) baştan: gizlilik (KYC yok, Firebase/aviationstack, tüm sağlayıcılar yurt dışı,
  gerçek saklama süreleri, m.11 tam), aydınlatma (her kategoriye hukuki sebep), açık rıza (yalnız pazarlama bildirimi),
  çerez (site çerezsiz), sözleşme (host kart koşulları, bedel yasağı, kredi=eşleştirme bedeli, marka notu, cayma m.15/1-ğ,
  bildir-kaldır, bildirimler).
- `app.json` + `assets/locales/*.json`: galeri izin metni (profil fotoğrafı sunucuya yüklenir).

**BO 1.102.0**: KYC sayfası → `_arsiv/20261108/kyc`, menüden çıktı; panoda "Doğrulanmış profil" sayısı; Kullanıcılar "Profil ✓";
Doğrulamalar'dan elle kimlik anahtarı kalktı; puan sayfası kazanma metni gerçek değerler; İletişim'de izin notu; legal.js kopyası.

**Site 0.74.0**: legal-source.js kopyası; /hesap-sil ve /en/delete-account gerçek davranış; /en/privacy ve /en/terms güncel;
GüvenKalkan 3. satır "Biniş kartı doğrulandı"; plan kartları "yalnız doğrulanmış profilleri kabul et".

## Supabase'de çalıştırılacak (sırayla)
1. (koşulmadıysa) 341, 342, 343, 344
2. **345_kyc_kapanisi_dogrulanmis_profil_kvkk.sql** — tüm satırlar tamam = true
3. Dashboard › Storage › kyc › dosyaları sil, sonra kovayı sil (SQL'le silinemez)

## Testler (son koşu, 8 Kasım öğleden sonra)
- app `node check.js`: 0 bulgu · `npm run verify`: **77/77 temiz**
- tarayıcı dokunma testi (`web_sahne/dokunma_yolu_test.py`): **9/9** · sahne ölçümleri (kutu taşma, gren) temiz
- yerel Postgres kurulumu (`pg_run.py`, 001→345 + SEED): ilk kurulum **temiz** (345 dahil)
- BO `node check.js` temiz · `npm run build` başarılı · site `node verify.js` **7/7** · `npm run build` başarılı
- Android AAB 1.0.0 (302): EAS 8a698265 FINISHED → `_aab/LoungeLink-1.0.0-302.aab`

### Bu turda kapatılan eski kırmızılar (Gökberk: "gözlemlediğini çöz")
- tasarım sembolü 6/5 → 3/5 (CompanionChat "›" → Ikon; iki regex'te unicode kaçışı)
- SQL 343:181 nullsort → coalesce(..., false)
- site mühür: legal metinde "ticaret" → "muhasebe"
- dokunma makbuzu bayattı: test güncel koda koşturuldu; Salon Rehberi düğmesi artık Ikon + "Geri" (test metni güncellendi)
- tarayıcı testinin açtığı 2 görsel bulgu: radar kartında ikon-metin boşluğu 0 → gap SP[3]; vitrin_kalkis sahnesine gren
- kutu_tasma_check test çıktılarını sahne sanıyordu (3 uyarı) → atlama listesi
- `npm run sahne:export` Windows'ta çalışmıyordu (`LL_SAHNE=1` cmd sözdizimi) → node ile ortam değişkeni
- yerel kurulum: 337 CRLF/LF gövde karşılaştırması (338/339 zincirleme düşüyordu) · pg_run sıralaması (268a/269a/270a teşhis
  dosyaları ana dosyadan SONRA) · 345 doğrulamasında cron.job doğrudan başvurusu → `cron_isi_var()`
- Gradle dağıtımı: GitHub 504/502 → app.config.js `gradleIndirme` (Tencent aynası + resmi SHA-256)

## Açık kalanlar / Gökberk'ten beklenen
- ✅ pg_run "tekrar kurulum" stres testi KAPANDI: 389 dosya baştan sona + 145 dosya ikinci kez temiz, gerileme yok, verify 77/77.
  Düzenlenen eski dosyalar (yalnız ikinci koşuyu etkiler, Supabase'de yeni SQL YOK): 224, 228, 235, 236, 237, 239, 248, 250,
  253, 256, 261, 292, 295, 298, 313, 335, SEED4. Kalıp: kurulu yeni hâl varsa eski tanımı atla; nöbetçiler veri durumuna göre düzeltildi.
- Play 9.5/9.6 ürünleri (sürüyor), RevenueCat iOS appl_ anahtarı → iOS 296 production build + gönderim.
- App Store açıklamasında "Kural motoru" ve "Kadın güvenlik modu" ifadeleri 296 gönderiminde değiştirilecek.
- Mağaza rehberi: veri güvenliği / App Privacy'den "kimlik belgesi" çıkarıldı (v34).
