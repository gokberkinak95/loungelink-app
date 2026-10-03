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
