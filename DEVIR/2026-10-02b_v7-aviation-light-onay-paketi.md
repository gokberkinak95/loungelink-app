# DEVIR · 2 Ekim 2026 (b) · v7 "Aviation Light" — onay paketi

Dal: `v7-tema` (YEREL; push yok, build yok — Gökberk onayı bekleniyor).
Sürüm DEĞİŞMEDİ: app 6.2.7 (versionCode 278, iOS 272). Onay gelirse 6.3.0 olacak.
Onay sayfası: https://claude.ai/artifact/8gAtL1zHB2GWv89ZtV39JT (78 ekran + ikon seti)

## Ne değişti
- `rnapp/src/theme.js` — üçüncü tema `V7` (KOYU'dan türetilir, tüm anahtarlar ezildi;
  açıkta kalan koyu değer yok — ölçüldü). `temaUygula("v7")` ilk kare. `amberMikro` (#E28743) yalnız nokta/ışıma.
- `rnapp/src/tema_tercih.js` — SECENEKLER ["v7"]. Koyu tema kodda duruyor, seçilemiyor.
- `rnapp/src/ui.js`
  - FotoBant v7 katmanları; sis SABİT 84pt (`V7_SIS`) — yüzdeyken ana sayfa cüzdanını yutuyordu.
  - Bant altı 1px fotoğraf sızıntısı kapatıldı.
  - Bandda küçük kanat logosu.
  - Başlıkta yüzde mono (`yuzdeMono`); tek uzun kelimeli başlık küçülür (SE 320 taşması).
  - Hdr → FotoBant yönlendirmesi.
  - CuzdanSeridi cam + şampanya değer + ince ayırıcılar.
  - DaralanBant kompakt çubuk v7'de gece mavisi.
  - `BTN.ustAcik` (açık zemindeki daire düğme).
  - Kahraman Bar (giriş/kayıt) mürekkep renkleri ve kanat.
  - Secim dolu çipte açık zeminde mürekkep metin (`acikZemin`).
  - Cip seçili metin `onGold`.
- `rnapp/App.js`
  - SplashV7: kanat, açılış ışığı, "Aynı lounge'da, doğru insanla.", tam genişlik düğmeler.
  - Yüzen sekme çubuğu, ortada Planım şampanya dairesi ve titreşim.
  - Sekme etiketleri ESKİ gibi düz harf ("Profil"); BUYUK() tüm sahne adımlarını kırıyordu. Aralık 0.5.
- `rnapp/src/ekranlar_yalin.js` — sohbet başlığı geri dairesi `ustAcik`.
- `rnapp/src/atmosfer.js` — şampanya/gök bulutları (altın bulut 0.07).
- `rnapp/src/i18n.js` — v7Slogan1/2, v7SplashAlt (TR+EN).
- `rnapp/brand/build_ikon_v7.py` (YENİ, ASCII) — ikon/adaptive/monochrome/favicon/splash, PIL ile.
- `rnapp/assets/{icon,adaptive-icon,monochrome-icon,favicon,splash}.png` — v7. Eskiler: `_arsiv/rnapp_ikon_koyu_20261002/`.
- `rnapp/app.json`
  - splash ve adaptive arka planı #1A2B4C
  - kök arka plan #F9F8F6
  - userInterfaceStyle "light"
- `rnapp/web_sahne/cek.py` — yeni sahne `86_akis_nehir_sohbet` (sohbet ekranı).

## SQL
Bu turda yeni SQL YOK. Önceki sıra geçerli: 313 → 314 → SEED8 → SEED9 (311 ve 312 koşulmadıysa önce onlar).

## Testler (sayılar)
| Test | Sonuç |
|---|---|
| `node check.js` | temiz |
| tasma_check | 0 taşma (320 + 390). İlk koşuda 2 bulundu, düzeltildi. |
| screens_test | 77/77 |
| app_boot | geçti |
| deeplink | 13/13 |
| error_map | 12/12 |
| mount_test | 54/54 (ikon tanımsız ad 0) |
| giris_kapisi | 37/37 |
| Web sahne | 81 sahnenin 78'i hatasız |

Web sahnedeki 3 hatalı sahne v7 kaynaklı değil:
- Sahneler: 06_sohbet, 35_canli_durum, 45_sohbet_uzun.
- Hepsi `gokberk → İstek: → Sohbeti Aç` yolunu izliyor. 6.2.7 IA'dan beri İstek hücresi Gelen/Gönderdiğim açıyor ve gokberk'in oturumu yok.
- Sahne tanımları güncellenmeli. Sohbet ekranı 86'da Nehir ile çekildi.

`npm run verify` bu turda koşulmadı (cairosvg yerelde yok).

## Açık / Gökberk'ten beklenen
1. Ekranlar ve ikon onayı → 6.3.0 sürüm artırma (app.json 3 alan + package.json + lock) → APK build.
2. Ayarlarda tema seçimi isteniyor mu? (şimdilik yalnız v7)
3. Onay sonrası: web sitesi ve uygulama içi görseller v7'ye taşınacak.
4. Sahne tanımları 06/35/45 güncellenecek (test borcu).

## EK · 3 Ekim (v7.2 revizyonu, prompt: boşluk / sikke / cam şerit)
- `rnapp/src/ui.js`
  - `V7_SIS` 84 → 48: bant ile ilk kart arası 36pt kısaldı.
  - `SikkeYuzey`, `SikkeDugme`, `useSikkeBasma`, `SIKKE_GOLGE`: şampanya gradyan, üst 1px rgba(255,255,255,0.40), alt bronz kenar, darp halkası, gölge 0.04, basınca 0.96 ve titreşim.
  - `UyumMuhru` v7'de sikke.
  - `CamSerit`: %45 beyaz, blur 16 (iOS expo-blur, web backdropFilter, Android yalnız zemin).
- `rnapp/App.js` — Planım merkezi `SikkeDugme`.
- `rnapp/src/ekranlar_ana.js`
  - "Sen de misafir olabilirsin" → CamSerit, serif başlık.
  - "Seyahat ekle / Telefonu doğrula" → Btn gold cip (disabled korunuyor).
- Testler:
  - check temiz
  - tasma 0
  - screens 77/77
  - mount 54/54
  - giris_kapisi 37/37
  - app_boot geçti
- Web sahne: 80 sahnenin 77'si temiz. Kalan 3 (06/35/45) aynı eski senaryo sorunu.
- Onay sayfası v2 (aynı link). Sürüm hâlâ 6.2.7. Prompttaki "v7.2.0" tasarım turunun adı.
- Gökberk'in "notlarım" dediği notlar bu mesajda gelmedi, yalnız prompt geldi.

## EK 2 · 3 Ekim ikinci tur (Gökberk 11 not + 2 ara not)
- KOK BULGU: react-native-web `tintColor` icin SVG filtresi kullaniyor. Filtre kimlikleri kayiyor:
  - katman #tint-5'e bakiyor, ama sayfada yok, Chrome katmani hic cizmiyor
  - #tint-6 yanlis renkte
  - Splash'in alt sis/fildisi gecisi bu yuzden hic gorunmuyordu.
  - Cozum: `brand/build_v7_perde.py` ile rengi gomulu PNG'ler (asagida). v7 katmanlarinda tintColor kalmadi.
    - v7_gece_ust, v7_sis_alt, v7_fildisi_alt, v7_isik_ust
    - mark-kanat-sampanya, mark-kanat-bronz
- Splash: A tuvali duraklari birebir (sis %50-74 rampa + duz %92, fildisi %74-90 + duz). Kanat ortada mavi kusakta.
- Sikke parlamasi: keskin elips yerine dikey yumusak isik.
- CamSerit: golge %7 + ust 1px isik; iOS ic/dis kap, Android elevation yok.
- `src/kutu_isik.js` (YENI): v7'de tint zeminli bilgi/uyari kutularina (107 yer) kabukta golge + ust isik.
  - Kapsam: radius ve pay >= 10.
  - Haric: sabit genislik, kendi golgesi olan.
- Ana sayfa:
  - telefon uyarisi CamSerit + kalkan
  - bolumler arasi gap 18
  - ust pay 6
  - V7_SIS 48 -> 36
- Sekme cubugu: icerik 40pt arkasindan gecer, kapsul buzlu cam, box-none.
- SekmeSeridi v7 cam segment; Cip bant icinde (BantBaglami) cam + secili sikke.
- akisKarti(): istek/oturum satirlari beyaz kart.
- Baslik tek satira sigacak boy (taban 26).
- Kucuk duzeltmeler:
  - Tanis arama odak zemini (koyu #181614 -> beyaz + amber %8, web outline 0)
  - Tumunu okundu sampanya
  - Market FotoBant'a gecti
  - MomentScreen gece altini sampanya, ghost -> ust
  - Tanitim eyebrow fildisi, noktalar
  - LangBtn sampanya
  - BosDurum "ucus" -> kanat logosu, kesikli kutu -> cam
- Hareket vitrini:
  - 5 yeni sahne (59, 66-69)
  - `web_sahne/hareket_kayit.py` 9 hareketi webm olarak kaydeder (onay sayfasinda video).
  - K4 kodda uygulu; Gokberk hatirladigi karara gore cikarilsin mi diye soruldu.
- cek.py: dokunus once dogrudan, olmazsa ortala.
- Testler:
  - check temiz
  - tasma 0 (SE'de profession 2 satir, Kabul/Reddet 1.35)
  - screens 77/77
  - mount 54/54
  - giris 37/37
  - deeplink 13/13
  - errmap 12/12
  - app_boot gecti
  - ps1 0
- Web sahne 85 / 82 temiz. Kalan 3 bilinen eski senaryo: 06, 35, 45.
- Onay sayfasi v3 (ayni link).
