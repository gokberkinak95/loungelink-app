# DEVIR · 3 Ekim 2026 · v7 denetim temizligi + build/push

Dal: `v7-tema`. Surumler (degismedi, dosyadan okundu):
- app 6.3.0 · versionCode 279 · buildNumber 273
- backoffice / website: bu turda dokunulmadi

## Ne degisti
Amac: "bugune kadar fixledigimiz seyler tekrarlanmasin". verify.js 18 kirmizi idi; 1'e indi (yalniz cairosvg: ortam, urun degil).

### App (gorunum birebir korunarak)
- Ham renkler tema jetonuna tasindi:
  - golgeRenk, card, goldBtn, warmBlock2, foto.marka
  - muhur/arac renkleri `C.x + "38"` gibi 8 haneli alfa
  - typography odak/giris yuzeyleri tembel kurulan jetonlu nesne
- Koseler: App.js tab kapsulu R.xl; RotaHatti noktalari R.full.
- Canli oturum:
  - "● OTURUM · CANLI" metin sembolu yerine View nokta.
  - "Canli durum" ve "Sorun bildir" artik `<Btn v="camTeal|camKirmizi" sm>` (yeni BTN varyantlari, ui.js).
  - Puan cumlesi `t.v7PuanN` acik dizi ile.
- SekmeSeridi: `<Secim bicim="camSegment">` (yeni bicim, ui.js; gorunum ayni, `sag` slotu da baglandi).
- Splash "Once dene" satiri: saydam dokunma kabi + ic cam yuzey (baglanti satiri; Android elevation 1).
- Kapi eylemi Btn'inin bos onPress'i gercek isleyiciye baglandi (ekranlar_ana).
- Android/iOS golge paritesi: kutu_isik ISIK/GOLGE, CamSerit Android, tab cubugu (shadowOpacity 0).
- Dokunma gecirgenligi: tab cubugu fildisi gecisi, secili cip altin gradyani, GeceKarti iki katmani -> pointerEvents="none" View icinde Image.
- Kaplama: hareket.js ve ui.js perde katmanlarina right:0.
- Olu i18n silindi:
  - refCondGG/GH/HH, refWhoGG/GH/HH (kademeler BE'de yok; Gokberk: "500 500 iyi")
  - refShareMsg (paylas -> kopyala)
  - v7SesBuluss
- SplashV7 + SplashKoyu export edildi, mount testine eklendi.

### Denetim araclari (gerekceli)
- tasarim_yapi_check: v7 bicimini de taniyan kanit desenleri (dugum sampanya · baslikBoy).
- jeton_bant_check SINYAL'e amberMikro (v7 gunes batimi, yalniz mikro).
- gorsel_palet_check MUAF'a v7_gece_ust.png + isik_bulutu_gok.png (v7 gece mavisi kutbu).
- tasarim_butce.json: App.js serif 2 -> 3.
  - BILINCLI TAVAN ARTISI: v7 splash slogani onayli A tasarimindaki Cormorant Bold. Gokberk itiraz ederse SemiBold'a (serifGosterim) cevrilir; gorsel fark kucuk ama birebir degil.
- TELIF.md: v7 uretilmis gorseller (hepsi `brand/build_v7_perde.py`, kendi uretimimiz).
  - altin_v7.png ureticisi eksikti; eklendi (sevkiyattakiyle <=3/255 fark, dosyaya dokunulmadi).
- dokunma_yolu_test: "Geri" sonrasi iz eski koyu slogandi -> iki splash'te ortak "Once dene" metni.
- cek.py: yeni sahne 87b_oturum_araclar (sakin araclar).

### Build / push altyapisi
- eas.json: preview/production profillerine `environment`.
- app.config.js: EAS "file" ortam degiskeni `GOOGLE_SERVICES_JSON` once okunur.
  - google-services.json .gitignore'da, git koku C:\LoungeLink -> EAS yuklemesi o dosyayi tasimaz.
  - Firebase dosyasi EAS'a `eas env:create ... --type file` ile verilmeli (rehber asagida).

## Testler (sayilar)
- check.js temiz.
- verify: 1 kirmizi = cairosvg ortam eksigi (onceki tur 18).
- render:
  - screens 77/77
  - mount 56 ekran / 0 basarisiz
  - giris 37/37
  - deeplink 13/13
  - errmap 12/12
  - tasma temiz
  - app_boot gecti
  - yoga 9/9
- e2e (e2e_win_kos.py):
  - iptal 47/47
  - edge 19/19
  - flow_matrix 27/27
  - onboarding 16/16
  - rule_dims 55/55
  - tam_akis 171/171
  - rpc_field ok
  - two_account ok
- Web sahne: 90/90 cekildi, hata=0 (44/49 bilerek ariza sahneleri). Dokunma yolu 9/9.

## SQL
Yeni SQL yok. (ETKIN_TANIMLAR.sql otomatik uretim farki.)

## Acik / Gokberk'ten beklenen
1. Firebase kurulumu: google-services.json + FCM V1 anahtari (rehber sohbette). Sonra yeni build.
2. Web sitesi v7 guncellemesi: tasarim degisikligi, once onizleme -> onay.
3. Splash slogan serif tavani (yukarida).
4. win_e2e IndexError ve flight_chain siralamasi: test altyapisi, urun degil.

## EK · aynı gün, ikinci yarı (web sitesi v7 + app sorulari)

### App
- K1 videosunda kanat yoktu: 9 hareket videosu kanat duzeltmesinden ONCE (10:43) kaydedilmisti. Dokuzu guncel kodla yeniden kaydedildi (web_sahne/out/hareket), kareden olculdu: kanat ortada. Galeri v7_onay surum 7.
- Kural motoru grup ayiricisi v7'de gorunmuyordu: cizgi C.kartKenar'a bagli, V7'de bu jeton saydam (gerileme). Secenekler onizlendi (A ince cizgi C.line2 · B ayri bolmeler). KARAR BEKLIYOR, kod degismedi.
- Acilis kanadi tonu: A fildisi (bugunku) · B duz sampanya · C isiltili sampanya onizlendi. KARAR BEKLIYOR. rnapp/assets/mark-kanat-isik.png gecici onizleme varligi (commit disi); A secilirse _arsiv'e tasinacak.
- tema_oku.py: palet("V7") eklendi (KOYU tabani + Object.assign blogu + V7_* sabitleri). C/KOYU ciktisi birebir ayni (olculdu).
- web_sahne/cek.py: LL_SAHNE_DIST / LL_SAHNE_OUT (onizleme derlemesi ayri klasorde).
- site_ekran_tazele.py: ss-eslesme <- 86_akis_nehir_sohbet, ss-m <- 45_sohbet_uzun, ss-puanla <- 88_oturum_puanla.
- Yorumlardaki "4 Ekim" tarihleri "3 Ekim" olarak duzeltildi (bugun 3 Ekim).

### Web sitesi (ayri repo: loungelink-website, yerel dal site-v7, commit 52fdbc9, PUSH YOK — onay bekliyor)
- site_paleti.py kaynagi KOYU -> V7; olcum govde zeminlerinde (tuval/blok/kart): ink 15.15 · body 9.60 · muted 5.24 · goldText 4.91 · teal 5.40 · green 5.56 · amber(amberInk) 5.08. --gold metinde bronza baglandi.
- globals.css sonuna "v7 · AVIATION LIGHT — SİTE KATMANI": kahraman gece penceresi (foto yalniz burada), fildisi govde, beyaz kart + lacivert golge, sampanya sikke dugmeler, baslik cubugu = app daralan bandi (gece cami), beta = gece kapanis, footer blok.
- SectionScene / sayfa kanadi / RuleDemo renkleri V7; karusel yan kartlari karartma yerine doygunluk dususu.
- 15 ekran karesi v7 sahnelerinden (app 6.3.0); eskiler public/screens/_arsiv_20261003_koyu. icon/favicon app ile ayni; og.jpg build_og.py ile v7 (eskisi arsiv_gorsel/og_2026-10-03.jpg).
- Denetimler v7'ye uyarlandi (gerekceli): check.js (palet listesi + yuzey sizintisi yonu + kahraman foto kapisi), palet_check (app V7 paleti muaf), tasarim_check (notr yuzeyler isik sayilmaz; parlama v7 degeri), gorsel_tutarlilik (gece bandi 255-295).
- Testler: node verify.js 7/7 temiz · npm run build ok · check.js 61 dosya 19 sayfa temiz.
- NOT: next dev sunucusunda site JS'i calismaz (CSP unsafe-eval yok) — gorsel kontrol icin `npm run build` + `npm start` kullan.
- Onizleme: https://claude.ai/artifact/Fed7nR6ykcZjB47D15miE3

### Acik
1. Site onayi -> site-v7 dalini push + website surum 0.70.0 (package.json + lock) + yayina alma karari.
2. App acilis kanadi tonu (A/B/C) ve kural motoru ayirici (A/B) -> uygula + yeni build.
3. Firebase (onceki bolum).
