# GÖRSEL TELİF DEFTERİ

Bu dosya, uygulamada kullanılan HER fotoğrafın lisans durumunu tutar.
`telif_check.py` bunu okur ve lisansı belirsiz bir görsel varsa denetimi
kırmızıya boyar.

## 🔴 NEDEN VAR

`assets/bant.jpg`i uygulamaya koydum. O görsel bugüne kadar yalnız
tasarım klasöründeydi (`ui_onerisi/pencere.jpg`) ve orada durduğu sürece
kimseye dağıtılmıyordu. **Uygulamaya girdiği an dağıtılıyor** — ve
mağaza incelemesinde lisanssız görsel gerçek bir ret sebebi.

Bunu bir "sonra hallederiz" notu olarak bırakmak, tam olarak unutulan
şeylerin bırakıldığı yer. O yüzden bir denetim satırı oldu.

🆕 SINIF: "BİR VARLIĞI TASARIM KLASÖRÜNDEN ÜRÜNE TAŞIMAK, ONU BİR
REFERANSTAN BİR YÜKÜMLÜLÜĞE ÇEVİRİR."

## DURUM

| dosya | kaynak | lisans | durum |
|---|---|---|---|
| `bant.jpg` | Pinterest pin 66709638231091375 (özgün üretici bilinmiyor) | belirsiz | ⚠️ KABUL EDİLDİ — Gökberk, 26 Ağu 2026 |
| `arsiv_gorsel/bant_2026-09-20.jpg` | AYNI görselin derecelendirme ÖNCESİ hâli — `brand/build_bant_derece.py --uygula` arşivledi (eski dosya silinmez kuralı) | `bant.jpg` ile aynı | ⚠️ KABUL EDİLDİ — aynı madde |
| `icon.png` | `brand/build_brand.py` üretiyor | kendi üretimimiz | ✓ |
| `adaptive-icon.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `monochrome-icon.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `notification-icon.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `favicon.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `zemin-acik.png` | `zemin_uret.py` üretiyor (paletten) | kendi üretimimiz | ✓ |
| `zemin-koyu.png` | `zemin_uret.py` üretiyor (paletten) | kendi üretimimiz | ✓ |
| `zemin-doku-koyu.png` | `brand/build_doku.py` üretiyor (paletten · tasarımın `Ekran.doku` kuşağı · AKŞAM kuşağı) | kendi üretimimiz | ✓ |
| `zemin-doku-safak.png` | `brand/build_doku.py` üretiyor (paletten · ambiyans ŞAFAK kuşağı, `amber` %8.5) | kendi üretimimiz | ✓ |
| `zemin-doku-gunduz.png` | `brand/build_doku.py` üretiyor (paletten · ambiyans GÜNDÜZ kuşağı, `mutedAA` %5.0) | kendi üretimimiz | ✓ |
| `zemin-doku-gece.png` | `brand/build_doku.py` üretiyor (paletten · ambiyans GECE kuşağı, `purple` %5.5) | kendi üretimimiz | ✓ |
| `parilti.png` | `brand/build_parilti.py` üretiyor (yalnız alfa · geçiş kartının Gauss profilli parıltı şeridi) | kendi üretimimiz | ✓ |
| `dikey.png` | `brand/build_dikey.py` üretiyor (yalnız alfa rampası · rengi `tintColor` veriyor) | kendi üretimimiz | ✓ |
| `altin.png` | `brand/build_altin.py` üretiyor (paletten · birincil düğmenin üç duraklı şampanya gradyanı) | kendi üretimimiz | ✓ |
| `altin_acik.png` | `brand/build_altin.py` üretiyor (AÇIK paletten · 18 Eyl: tek PNG iki temaya yetmiyordu — açık temada koyu paletin şampanyası çiziliyor ve beyaz metin 1.65:1 kalıyordu) | kendi üretimimiz | ✓ |
| `perde.png` | `brand/build_perde.py` üretiyor (paletten · tam ekran fotoğrafın alt perdesi, 512 adım) | kendi üretimimiz | ✓ |
| `bant_hale.png` | `brand/build_bant_hale.py` üretiyor (paletten · bandın iki radial halesi) | kendi üretimimiz | ✓ |
| `icon.png` · `adaptive-icon.png` · `monochrome-icon.png` · `notification-icon.png` · `favicon.png` · `splash.png` | `brand/build_kemer.py` üretiyor (kemer geometrisi elle çizildi; swoosh izi kendi eski ikonumuzdan `cv2.findContours` ile alındı) | kendi üretimimiz | ✓ |
| `arsiv_ikon_v5/*` | v5 ikon setinin derecelendirme/yenileme ÖNCESİ hâli — "eski dosya silinmez" kuralı gereği saklandı, dağıtılmıyor | kendi üretimimiz | ✓ |
| `arsiv_ikon_20260923/*` | 23 Eyl ikon/açılış turu (#1 #2 #10) ÖNCESİ hâli — işaret %2 aşağıdaydı, adaptive güvenli daireyi aşıyordu, splash opak zeminliydi. "Eski dosya silinmez" kuralı gereği saklandı, dağıtılmıyor | kendi üretimimiz | ✓ |
| `tanecik.png` | `brand/build_tanecik.py` üretiyor (sabit tohumlu rastgele gren · ekranın üstüne serilen dither katmanı) | kendi üretimimiz | ✓ |
| `fonts/ionicons.ttf` | `@expo/vector-icons` 14.0.4 · Ionicons (ionic-team) — 5 Eyl: dosya adı küçük harf (Android aileyi addan türetiyor; eski `Ionicons.ttf` → `arsiv/fontlar/`) | **MIT** — ticari kullanım ve dağıtım serbest | ✓ |
| `splash.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `mark-gold.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `mark-light.png` | `brand/build_brand.py` | kendi üretimimiz | ✓ |
| `mark-kemer.png` | `brand/build_kemer.py` → `varlik_tablosu` (20 Eyl 2026 · ürün içi marka işareti, koyu zemin) | kendi üretimimiz | ✓ |
| `mark-kemer-ink.png` | `brand/build_kemer.py` → `varlik_tablosu` (20 Eyl 2026 · ürün içi marka işareti, açık zemin) | kendi üretimimiz | ✓ |
| `mark-kanat.png` | `brand/build_brand.py` (20 Eyl 2026 · açılış ekranı işareti — `mark-light.png` mürekkebe kırpılıp fildişi #FAEEDC pişirildi) | kendi üretimimiz | ✓ |
| `fonts/Archivo-*.ttf` | Google Fonts · **DEĞİŞTİRİLDİ** (22 sembol glifi eklendi, `brand/build_simgeler.py`) | OFL-1.1 (`OFL-Archivo.txt`) — Reserved Font Name YOK, değişiklik serbest | ✓ |
| `fonts/CormorantGaramond-*.ttf` | Google Fonts · **DEĞİŞTİRİLDİ** (aynı 22 glif + 30 Ağu 2026: değişken fonttan 300/600/700 statik kesit üretildi) | OFL-1.1 (`OFL.txt`) — Reserved Font Name YOK | ✓ |
| `fonts/PlusJakartaSans-*.ttf` | Google Fonts (Tokotype) · **DEĞİŞTİRİLDİ** (aynı 21 sembol glifi, `brand/build_simgeler.py`) | OFL-1.1 (`OFL-PlusJakartaSans.txt`) — Reserved Font Name YOK | ✓ |
| `fonts/JetBrainsMono-*.ttf` | Google Fonts (JetBrains) · değiştirilmedi | OFL-1.1 (`OFL-JetBrainsMono.txt`) — Reserved Font Name YOK | ✓ |
| `fonts/LLSimge.ttf` | `brand/build_radar.py` · **sıfırdan bizim çizimimiz** (tek glif: radar, U+E900) | dış lisans YOK — türetildiği tek kaynak kendi tasarım dosyamız (`tasarim_kaynak/gen.py`, `I['radar']`) | ✓ |

## `LLSimge.ttf` — KENDİ GLİF SETİMİZ (31 Ağustos 2026)

Tek glif taşıyor: **radar** (U+E900), Keşfet sekmesinin işareti.

**Neden var:** tasarımın radar işareti Ionicons'ta YOK. Tahmin değil, ölçüm:
tasarımın SVG'si gerçek bir tarayıcıda çizildi ve Ionicons'un **1338 glifinin
hepsiyle** aynı kutuda IoU (kesişim/birleşim) karşılaştırıldı.

| aday | IoU |
|---|---|
| Ionicons'un en iyisi (`at-circle-outline`) | 0.497 |
| `radio-button-on` | 0.481 |
| önceki sürümde gönderdiğimiz `radio-outline` | **0.129** |
| **`LLSimge/radar` (bu font)** | **0.885** |

**Telif durumu:** dış bir fonttan türetilmedi, bir ikon setinden kopyalanmadı.
`brand/build_radar.py` glifi tasarım dosyamızın kendi yol verisinden
(`tasarim_kaynak/gen.py` içindeki `I['radar']`) çiziyor. Yani kaynak da bizim,
çizim de bizim; lisans yükümlülüğü yok. Fontu yeniden üretmek için:

    python3 brand/build_radar.py

Betik, yazdığı fontu PIL ile geri okuyup glifin gerçekten çizildiğini ve
merkezinin dolu değil **halka** olduğunu doğrular; ayrıca kutusunun
Ionicons'unkiyle (ilerleme 1000, ana hat üstü 848) aynı olduğunu ölçer —
yoksa sekme çubuğunda diğer dört ikondan farklı boyda görünürdü.

## FONT DEĞİŞİKLİĞİ NOTU (OFL gereği)

`Archivo-*.ttf`, `PlusJakartaSans-*.ttf` ve `CormorantGaramond-*.ttf` **değiştirilmiştir**: uygulamanın
kullandığı 22 sembol (✓ ✕ ★ ⚠ ✈ ⏳ …) özgün fontlarda yoktu ve
`brand/build_simgeler.py` tarafından çizilip eklendi.

OFL-1.1 buna izin veriyor: her iki telif satırında da "Reserved Font Name"
belirtilmemiş, dolayısıyla ad kısıtı yok. OFL metinleri değiştirilmiş
dosyalarla birlikte `assets/fonts/` içinde taşınıyor (OFL şartı).

Eklenen glifler bizim çizimimiz; onların telifi bize ait ve aynı OFL
kapsamında dağıtılıyor.

**30 Ağustos 2026 — Cormorant kesitleri.** Sevk edilen `-Bold` ve
`-SemiBold` dosyalarının İKİSİ DE aslında değişken fontun kendisiydi
(`fvar` tablosu var, `usWeightClass: 300`) — yani ikisi de Light
çiziyordu. Üçü de (`-Light`, `-SemiBold`, `-Bold`) Google Fonts'un
resmî değişken kaynağından `fontTools.varLib.instancer` ile statik
kesit olarak yeniden üretildi ve 22 sembol glifi yeniden eklendi.
Kaynak aynı OFL-1.1; örnekleme (instancing) OFL kapsamında serbest bir
değişikliktir ve Reserved Font Name yoktur. Eski dosyalar
`arsiv/font_20260830/` altında saklanıyor.

## KABUL EDİLEN RİSK — `bant.jpg`  (26 Ağustos 2026)

Gökberk: *"telife takılma, bir sıkıntı yaratmaz"* + kaynak olarak bir
Pinterest bağlantısı iletti.

Karar onun ve kaydı burada. Ama kaydın işe yaraması için ne kabul edildiğinin
net yazılması gerekiyor:

**Pinterest bir lisans kaynağı değildir.** Bir pin, başkasının görselinin
yeniden yüklenmiş hâlidir; pin sayfası hiçbir kullanım hakkı vermez ve
Pinterest'in kendi şartları da bunu açıkça söyler. Yani şu an görselin
özgün üreticisi ve hakları BİLİNMİYOR.

Somut risk iki yerde:
  · **Apple Guideline 5.2** (fikri mülkiyet) gerçek bir ret sebebi.
  · Yayından SONRA gelen bir kaldırma talebi, yayından ÖNCE değiştirmekten
    her zaman pahalıdır — sürüm çıkarmak gerekir.

Bu iki cümle bir itiraz değil, kaydın kendisi: ileride biri "bunu bilmiyor
muyduk" diye sorarsa cevap burada.

## ÇÖZÜM YOLU (hazır, uygulanmayı bekliyor)

Mağazaya çıkmadan ÖNCE üç yoldan biri:

1. **Lisans satın al / belgele.** Kaynağı bul, ticari kullanım ve
   uygulama içi dağıtım hakkını kapsayan lisansı al, belgeyi
   `assets/lisans/` altına koy ve bu tabloyu güncelle.
2. **Lisanslı bir eşdeğerle değiştir.** Unsplash/Pexels lisansı ticari
   kullanıma izin verir; aynı kompozisyonda (uçak penceresinden gün
   batımı) bir görsel bulunabilir. Kırpma parametreleri `ic_sayfa_son.py`
   içinde ve yeni görselle yeniden aranması gerekir.
3. **Çizime dön.** `src/atmosfer.js` içindeki `CizilmisGunBatimi` telifsiz
   bir yedek olarak zaten duruyor — 0 KB, her cihazda birebir aynı.
   Görsel olarak fotoğrafın yerini tutmaz; bu bir geri çekilme seçeneği.

`telif_check.py` bu maddeyi artık KIRMIZI değil ⚠️ olarak raporluyor —
karar verildi, denetim onu geçersiz kılmıyor. Ama satır listede kalıyor:
kabul edilmiş bir risk, unutulmuş bir risk değildir.

🆕 SINIF: "BİR RİSKİ KABUL ETMEK ONU SİLMEK DEĞİLDİR — DENETİMDEN
ÇIKARILAN RİSK, KARAR VERİLMİŞ DEĞİL UNUTULMUŞ SAYILIR."

### Lisanslı eşdeğerler (Unsplash Lisansı · ticari kullanım serbest, atıf şart değil)
Aynı kompozisyona en yakın adaylar — değiştirmek istersen kırpma
parametrelerinin `ic_sayfa_son.py` içinde yeniden aranması gerekir:
  · https://unsplash.com/photos/airplane-wing-and-clouds-seen-through-window-at-sunset-GgNUhBO1-dk
  · https://unsplash.com/photos/photo-of-clouds-from-airplanes-window-xlNqmgDDYp0
  · https://unsplash.com/photos/a-view-of-the-clouds-from-an-airplane-window-gdxOGN_fTjE


## v3.4 EKLERİ (28 Ağustos 2026)

**`zemin-acik.png` · `zemin-koyu.png`** — `zemin_uret.py` bu iki dosyayı
`src/theme.js` paletinden ÜRETİYOR. Hiçbir dış kaynak yok, tek satır
sabit renk yok. Telif sorusu doğmuyor; yine de deftere yazılıyor, çünkü
bu defterin kuralı "dağıtılan her varlık burada olacak" — kaynağı biz
olsak bile.

**`fonts/ionicons.ttf`** — MIT lisanslı (ionic-team/ionicons; paket
`@expo/vector-icons` 14.0.4 üzerinden geliyor ve o da MIT). MIT, ticari
kullanıma ve gömülü dağıtıma açıkça izin verir; tek şart lisans metninin
korunması ve bu paket `node_modules/@expo/vector-icons/LICENSE` içinde
zaten dağıtımla birlikte geliyor.

Fontu neden `node_modules`tan kopyaladık: `app.json`daki `expo-font`
eklentisi fontları BUILD'E GÖMÜYOR ve yalnız `assets/` altındaki
dosyaları görüyor. Kopya, kütüphanenin bir sürüm sonra dosyayı taşıması
hâlinde build'i de kırılmaz kılıyor.

🆕 SINIF: "BİR VARLIĞI KENDİN ÜRETMİŞ OLMAN, ONU DEFTERE YAZMAMAK İÇİN
SEBEP DEĞİL — DEFTER 'NEYİ DAĞITIYORUZ' SORUSUNU CEVAPLAR, 'KİMDEN
ALDIK' SORUSUNU DEĞİL."
