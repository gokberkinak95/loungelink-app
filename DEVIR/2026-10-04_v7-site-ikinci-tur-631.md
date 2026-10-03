# DEVIR · 4 Ekim 2026 · site v7 2. tur + app 6.3.1

Onceki: DEVIR/2026-10-03_v7-denetim-temizligi-build.md

## Surumler (dosyadan)
- app 6.3.1 · versionCode 280 · buildNumber 274 (app.json + package.json + lock)
- website 0.69.5 (degismedi; onaydan sonra 0.70.0)

## App (v7-tema, commit aa6eda3, push edildi)
- Gokberk karari: acilis kanadi A (fildisi, degisiklik yok), kural motoru ayirici A.
- src/ekranlar_ana.js: grup ayiricisi v7'de C.line2 (koyu temada C.kartKenar aynen).
- Gecici onizleme varligi mark-kanat-isik.png -> _arsiv/rnapp_onizleme_20261004/.
- Testler: check.js temiz · screens 77/77 · mount 56/56 · tasma temiz · web sahne 03_kural + 91_kural_damga hata=0.
- EAS preview build FINISHED: https://expo.dev/artifacts/eas/2xg2EJ2Xun7uhHiMjHBnxma5tH3-qmo2vChrXaTVq_E.apk
  (google-services.json hala yok -> Android push bu build'de de calismaz.)

## Web sitesi (loungelink-website, yerel dal site-v7, PUSH YOK)
Gokberk notlari ve karsiliklari:
- Kapsam / koltuk hareketlerinin zemini duz beyaz -> W5 kapsam, W7 guven, W8 koltuk GECE PANELI (lacivert derinlik + yildiz tozu); panel icinde token'lar yerel gece degerleri, SVG'ler sampanya/fildisi. Imlec isigi (el feneri) panellerde sampanya %15; demo ve hak hesaplayicida safak tonu.
- Acilis ucagi (W1) gorunmuyordu: kanat var(--ink) ile ciziliyordu (v7'de lacivert). Kahramanda yerel --ink fildisi, --goldText sampanya. Olculdu: 3.5 sn'de x=488.
- Telefon kahramaninda "pencere coklanmis": pencere cercevesi + yari inik perde iç içe kemer. Telefonda yalniz pencere acikligi (320% · 46%); inset:0 denemesi nefes animasyonunda ust seridi aciyordu, -6% korundu.
- Kartlar telefonda zeminden ayrismiyordu: --kart-golge katmanli + 1px halka (box-shadow; muhur "cerceve yok" korunuyor).
- W3 secili cip sampanya sikke.
- site_paleti.py --denetle yalniz uretilen blogu karsilastiriyor (panel ici yerel token'lar sapma sayilmasin).
- Testler: verify.js 7/7 · npm run build ok · check.js 61 dosya 19 sayfa temiz.
- Onizleme v2: https://claude.ai/artifact/Fed7nR6ykcZjB47D15miE3

## SQL
Yok.

## Acik
1. Site onayi -> 0.70.0 + push + yayina alma karari.
2. Firebase (google-services.json + FCM V1) -> sonra yeni build.

## EK · ayni gun: site yayini + giris/kayit denetimi (app 6.3.2)

### Site
- 0.70.0 (package.json + lock), ekran rafi app 6.3.1 damgali. main'e fast-forward + push (fe40070), site-v7 dali da push.
- Vercel yayinda: loungelink-website.vercel.app/og.jpg yeni kartla bayt bayt ayni (olculdu).
- loungelink.co DNS'i bu agda 192.168.1.1'e cozuluyor, yanit yok: alan adi henuz baglanmamis.

### App 6.3.2 (versionCode 281 · buildNumber 275) — commit 9a41587, push edildi
Gokberk sorusu: login/signup akislari, rol secimi, kayittan sonra tanitim.
- Rol secimi: e-posta kaydinda adim 2 ZORUNLU (secmeden ilerlenmiyor), rol signUp meta verisiyle gidiyor, handle_new_user users.role'e yaziyor (olculdu: ETKIN_TANIMLAR).
- BULGU 1 (duzeltildi): Google/Apple ile gelen kullanici rol + sozlesme onayi tamamlama ekranini HIC gormuyordu. needsOnboarding "rol yok" diye bakiyordu; tetikleyici rolu coalesce(...,'guest') ile hep doldurdugu icin kosul hic dogru olmuyordu. Yeni olcut: sosyal saglayici + terms_privacy onayi yok. E-posta hesaplari etkilenmez (v1.81).
- BULGU 2 (duzeltildi): e-posta dogrulamasi aciksa signUp oturum donmuyor; onay/telefon/davet kodu hic yazilmiyordu. Artik cihazda e-postaya bagli bekliyor (ll_kayit_bekliyor), ayni e-postayla ilk acilista yaziliyor; baska hesaba yazilmaz.
- BULGU 3 (duzeltildi): tamamlama ekraninda host secen kisi icin kabuk rolu yeniden okunmuyordu.
- signUp/resend: emailRedirectTo = loungelink://auth-callback (izinli listede yoksa Site URL'ye duser — bugunku davranis).
- "Kayittan sonra tanitim": kodda yol yok; olculdu (kayit_yonlendirme_test): tanitim/giris/kayit ekranindayken oturum acilinca -> ana sayfa; cikis -> acilis (tanitim degil); tanitim gorulduyse Basla -> kayit.
- Yeni test render_check/kayit_yonlendirme_test.js 18/18 (npm run render zincirinde). Eski needsOnboarding ile kosuldu: Google senaryosu KIRMIZI (acik kanitlandi).
- giris_kapisi_test 39/39 · screens 77/77 · mount 56/56 · deeplink 13/13 · dokunma yolu 9/9 · verify: yalniz cairosvg (ortam).

### Bildirim baglantilari
- Push dokunusu Universal Link KULLANMAZ: payload data.notification_id -> bildirim_hedefi RPC -> ekran. Sunucunun dondugu tum ekranlar (akis/istek/davet/soru/baglanti/oturum, sohbet, istek_sohbet, tanis, cuzdan, degerlendirmeler, guvenlik) uygulamada karsilaniyor; kapali/acik uygulamada dokunus yakalaniyor.
- Universal Link (iOS) / App Link (Android) KURULU DEGIL: associatedDomains, intentFilters ve sitede .well-known yok. Gerekli olanlar: Apple Team ID (iOS), Android imza SHA-256 (APK'dan okunabilir), canli alan adi (loungelink.co baglanmali), hangi yollarin uygulamayi acacagi karari.

### Acik
1. Universal/App Link karari ve girdileri (Team ID, alan adi).
2. Supabase Auth -> URL Configuration -> Redirect URLs: loungelink://** ekli mi (kontrol: Gokberk).
3. Firebase (onceki).
