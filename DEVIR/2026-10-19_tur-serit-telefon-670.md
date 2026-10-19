# DEVIR — 19 Ekim 2026 · app 6.7.0 · BO 1.99.0 · site 0.70.4

## Gökberk onayları (bugün)
- Önizleme v9 "Bildirim Şeridi ve İlk Kullanım" (https://claude.ai/artifact/AutU7VdeomJ6ZSYRh8YTHm): hepsi.
- Telefon şartı: SMS açıkken lounge isteği ve Tanış bağlantı isteği telefon ister; kural sorusuna e-posta yeter.

## Ne değişti

### App 6.7.0
- **"?" sayfa turları** (`src/tur.js`): Ana Sayfa (5) · Keşfet (4) · Planım misafir (4) / host (5, Seyahatlerim+İlanlarım
  birlikte) · Tanış (4) · Cüzdan (4, son adım üyelik planları + "Planları gör") · Kural sonucu (4).
  1. adım sayfanın genel özeti; sonrası hedef öğeyi gerçek konumundan (measureInWindow) vurgular.
  Ekranda olmayan hedefin adımı atlanır, sayaç kendini ayarlar. "Geç" · "Devam et" · son adımda "Anladım".
  Ana sayfa turu ilk girişte bir kez (açılıştan ~4,8 sn sonra); "Nasıl çalışır?" etiketi + nokta ilk tura kadar.
  Hedefler `turHedef(id)` ile: tab_disc/trips/meet, ana_kredi, kesfet_cipler/uyum/istek, seyahat_kart/uyumlu/hostbul,
  planim_sekme, ilan_ozet/ekle/basvuru, tanis_sekme/suzgec/kisi, cuzdan_bakiye/paket, kural_ozet/sart/sorun.
- **Uygulama içi bildirim şeridi** (`src/serit.js`): ince kart, 4 sn, parmak üstünde bekler, yukarı it = kapat,
  dokun = `bildirim_hedefi` yönlendirmesi; peş peşe gelenler "N yeni bildirim" (dokun = Bildirimler).
  Kaynak: expo push (ön plan) + gerçek zamanlı `notifications`; aynı kimlik bir kez. Açık sohbetin mesajı için çıkmaz.
  Uygulama açıkken telefonun kendi bildirim şeridi gösterilmez (`push.js`).
- **Keşfet uçuş çipleri**: 2+ yaklaşan uçuşta bandın altında, yatay kaydırılır (`Cip`).
- **Telefon kartı**: sayaçların ALTINDA, sağ üstte ✕ (7 gün), yalnız SMS kanalı açıkken; yeni metin.
- Metinler TR+EN (152 anahtar), `e_contact_not_verified` "Profil › Doğrulamalarım"a yönlendirir.
- Sahneler: 94_tur_ana … 98b_tur_kural, 99_serit, 99b_tel_kart, yönlendirme sahneleri 98c/99c/99d/99e.

### SQL 335 (henüz koşulmadı; tek dosya)
- §6c telefon şartı: `is_contact_verified` kanal 'firebase' iken yalnız telefon; `iletisim_dogrulandi_gevsek`;
  `ilan_kurali_sor` artık telefon VEYA e-posta (hata: SMS yokken kimse kural sorusu soramıyordu).
- §6d kredi paketi adları "1 kredi / 3 kredi / 5 kredi" (Cüzdan "Tek hak / Üç hak" yazıyordu).
- Doğrulama: dokuz satır tamam = true. Yerel: 9/9; telefon şartı senaryosu (kanal kapalı/açık/kural sorusu) doğru.

## Testler (sayılarla)
- app `npm run verify`: ilk koşu 8 kırmızı (yeni kod: şerit dokunma alanı, ham renkler → `TUR` jetonu, tema
  sızıntısı, elle seçim düğmesi → `Cip`, ölü metin goVerify, ham_kod_check'in Windows komut satırı sınırı
  [WinError 206 → anahtarlar dosyayla]) → ikinci koşu yalnız bayat dokunma makbuzu; sahne koşusu yeniledi.
- sahne çekimi hata 0 (arıza sahneleri hariç) · dokunma yolu düşen 0 · akış e2e **197/197**, ✗ 0.
- yönlendirme sahneleri: Planları gör → Plan · şerit → Bildirimler · telefon kartı → Doğrulamalarım · Host bul → Keşfet.
- SQL 335 yerelde 9/9; telefon şartı senaryosu doğru.

## APK
- Android önizleme APK 6.7.0 (291): https://expo.dev/artifacts/eas/KCwW3mhANZZ1oLqZxbNidLWuLO4t5rhJIOBYrobHVMc.apk

## Açık / Gökberk'ten
1. SQL: 330 → … → 334 → 335.
2. Rehber 10 + 10b (Firebase) → "Firebase tamam" → Firebase'li build → kanalı açan iki SQL satırı.
3. Telefonda dene: geri tuşu (Android 16), alt sekmeler, "?" turları, bildirim şeridi.
