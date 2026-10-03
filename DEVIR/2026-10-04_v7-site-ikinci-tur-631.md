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
