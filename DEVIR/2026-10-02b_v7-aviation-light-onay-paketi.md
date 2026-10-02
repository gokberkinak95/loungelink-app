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
