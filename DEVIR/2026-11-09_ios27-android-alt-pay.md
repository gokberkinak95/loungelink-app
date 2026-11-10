# 9 Kasım 2026 — iOS 27 açılış çökmesi, Android alt pay ve açılış sahnesi

## Ne değişti
- `rnapp/eas.json`: iOS imajı `latest` → `macos-tahoe-26.5-xcode-26.6` (production + preview-device).
  KÖK (çökme raporu LoungeLink-2026-11-09-110640.ips): `latest` = Xcode 27.1 / iOS 27.1 SDK.
  iOS 27 SDK ile derlenen ve UIScene yaşam döngüsüne geçmemiş uygulamayı iOS 27.2 açılışta
  durduruyor (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`, EXC_BREAKPOINT).
  294/295/299 hep Xcode 27.1 ile derlenmişti. RN 0.76 / Expo 52 UIScene desteklemiyor.
  **YAPILACAK (2027 baharından önce):** Apple iOS 27 SDK'yı zorunlu kılmadan Expo SDK yükseltmesi
  + UIScene. O güne kadar `image` "latest"e ÇEVRİLMEZ.
- `rnapp/src/ui.js`: `ALTPAD` Android'de pencerenin gezinti çubuğuyla gerçek örtüşmesi
  (kenardan kenara olmayan pencerede ilk ölçü 48dp bildiriyordu → sekme çubuğu yukarıda kalıyordu).
- `rnapp/src/acilis.js`: sahne tam kök (`bottom: 0` + onLayout ölçüsü; Android pencere yüksekliği
  durum çubuğunu saymıyordu) + Android `elevation: 1000` (Başla düğmesi bulutların üstünde çiziliyordu).
- `rnapp/src/supabase.js` `logError(screen, err, code, context)`; `rnapp/src/i18n.js` mapErr
  TypeError sınıfında çağıran yığınını `context.yigin`e yazar. Android'deki 3 "undefined is not a function"
  kaydı `@example.com` test hesaplarından (kodda geçmiyor; muhtemelen Google'ın otomatik inceleme robotu).

## Sürümler
- app 1.0.0 · iOS buildNumber **300** · Android versionCode **307**.
- iOS 300 ad hoc (2c92ec1a) Gökberk'in iPhone'unda (iOS 27.2) açıldı, sorun yok.
- iOS 300 production (e1ecb22c) + auto-submit App Store Connect'e.
- Android 307 (db809501) + auto-submit Play dahili test taslağı.
- 294–299 iOS / 301–306 Android kullanılmayacak.

## SQL
- Yeni SQL yok. 349 canlıda koştu (3/3 true). İnceleme hesabı hazır (10 kredi, doğrulandı).
- Bekleyen: DENETIM_TAM'ı 349 sonrası yeniden koşmak.

## Testler
- `node check.js` temiz (iki kez). Render/e2e bu turda koşulmadı (değişiklikler yalnız yerel cihaz davranışı).

## Açık / Gökberk'ten
- App Store: build 300'ü seç, gönder. Play: 307'yi dahili testte yayınla, kapalı teste 12 kullanıcı × 14 gün.
- Expo bu ayın $45 kredisini doldurdu; sonraki build'ler ücretli (iOS $2, Android $1). Mağaza onayı sonrası
  ücretsiz plana geçiş önerildi.

## Ek (aksam)
- iOS **301**: `NSUserTrackingUsageDescription` app.json'dan cikarildi (App Store "tracking beyan et" diye
  gonderimi durduruyordu; izleme yok). Build 68d053d1 + auto-submit.
- SQL **350** (Gokberk calistiracak): canlida rehber 187 yamasi YOKTU (DENETIM_TAM guide_lounges farki);
  inceleme vitrini acik ilan 0 idi → tazele + gerekirse yeniden ac + pg_cron `ll-vitrin-tazele` 03:30.
- 270a_GORUNURLUK canlida 0 satir (fikstur gercek kullaniciya gorunmuyor).
- DENETIM_TAM (349 sonrasi): guide_lounges disinda 21 satir bilinen zararsiz (connection_test,
  sql_migration_durumu, test_hesabi_kaydi, kurulum_imzasi_var, schema_migrations.kaynak nullable).
- ACIK KIRMIZI: `sql/tablo_sina.py` B ve C senaryolari dusuyor (350'den ONCE de dusuyordu, olculdu);
  KURULUM_TABLOSU kontrolu (kurulum_tablosu_check) temiz. Sonraki turda incelenecek.

## Magaza durumu (9 Kasim aksam)
- App Store: 1.0.0 (301) + 3 kredi + 4 abonelik + LoungeLink Uyelik grubu incelemeye gonderildi (manuel yayin).
- Play: kapali test Alpha 307 YAYINLANDI (9 Kasim 14:48); test kullanicisi Google Grubu
  testers-community@googlegroups.com (Testers Community Starter). Reklam kimligi: Hayir; satici: Evet.
  14 gun sayaci test kullanicilari katildiktan sonra baslar → sonra uretim erisimi basvurusu.

## 10 Kasim — Apple ONAYI, yayin hazirligi
- App Store 1.0.0 (301) ONAYLANDI (Pending Developer Release, manuel). Yayin plani: 12 Kasim Persembe 10:00.
- SQL 351 canlida (iki gecis): test/fikstur/example.com/test@loungelink.com + Gokberk'in iki deneme hesabi
  silindi; mustafa.emre... icin admin_roles satiri Gokberk onayiyla kaldirildi, sonra silindi. Kurucu
  (super_admin) + inceleme hesabi kaldi, icerikleri temizlendi. 11 Testers Community hesabina dokunulmadi
  (dis hesap kilidi + once/sonra sayimi). Dogrulama 5/5 true, kalan hesap 13. ll-vitrin-tazele kaldirildi.
- SQL 352 canlida: nakit maliyetli oduller stok 0 (geri acma komutu dosyada). 2/2 true.
- TEMIZLIK_ENVANTER.sql (salt okunur) eklendi.
- Satin alma (sandbox, inceleme hesabi): kredi 9 sn, abonelik ilk alim 43 sn (uygulama 30 sn bekliyor →
  ekran plani gostermiyor; sunucu dogru). Yenileme/bitis dogru. → 1.0.1 duzeltmesi.
- Nominations (App Launch, 12 Kasim, Turkiye) gonderildi.
- Website: branch `yayin-onizleme` (yerel, PUSH YOK): App Store rozeti, Android haber formu, itunes akilli
  bant, JSON-LD. verify 7/7, build 298/298. Yayin gunu surum artir + canliya al.
- Pazarlama onizlemeleri: _gorseller/onizleme_yayinda (post_1/3/5_lansman, reels_lansman_9x16/4x5,
  event_kart/detay "Kurucu Host ol"). Gokberk onayladi. posts.html &durum=lansman, videoLansman.html, etkinlik.html.

## 1.0.1 listesi (yayindan sonra gonderilecek)
1. Satin alma sonrasi plan/kredi aninda (RevenueCat CustomerInfo) + arka planda yoklama + ekrana donuste yenile.
2. Odullerde "yakinda" etiketi (stok 0 yerine).
3. App Store: ad "LoungeLink: Lounge Arkadasi", alt baslik, anahtar kelimeler (DEVIR'deki konusma), EN de.
4. Degerlendirme istegi (basarili bulusma sonrasi).
5. Eski ekran goruntusu ekran/34_host_ol.jpg kaldirilmis vaadi gosteriyor → yenile.
6. Inceleme hesabina guncel seyahat + inceleme notu ("ag yeni").
- ACIK: DENETIM_TAM 351/352 sonrasi yeniden uretilmeli; tablo_sina B/C kirmizisi.
