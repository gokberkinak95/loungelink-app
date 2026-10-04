# DEVIR · 4 Ekim 2026 (3) · rol ayrımı · host tek yol · sosyal giriş · hesap silme · app 6.3.4

Önceki: DEVIR/2026-10-04b_uctan-uca-ve-yuk-testi-633.md

## Sürümler (dosyadan)
- app 6.3.4 · versionCode 283 · buildNumber 277
- backoffice 1.96.3 (değişmedi) · website 0.70.0 (değişmedi)

## Gökberk'in istekleri ve karşılıkları
1. "Nerede zorlanırız" önlemleri: kişi araması aday sınırı (SQL 326, 3,2 sn → ~0,2 sn, 820 karşılaştırma 0 fark).
   Keşfet havalimanı listesi için güvenli hızlı kazanç YOK (ölçüldü: mevcut plan doğru; zorlanan plan 108 sn).
   kesfet_ozeti sunucu önbelleği yapılmadı: izleyiciye özel görünürlük kuralları var, ortak önbellek yanlış sayı/sızıntı üretir.
   pg_trgm yerelde yok → trigram indeksi ölçülemedi, eklenmedi.
2. B15 (aynı saatte farklı havalimanı): ne app ne sunucu denetliyordu → SQL 325 (mutlak saatle; aktarmalı gün etkilenmez;
   update_visit de artık çakışma denetliyor). Yeni kod baska_havalimaninda_seyahatin_var TR+EN.
3. Tanış "Tümü" çipi: önizleme → onay ("Tümü seçili açılsın") → uygulandı; Uçuş kendiliğinden seçilmiyor.
   Ek bulgu B21: Tanış profil görünürlüğünü okumuyordu → SQL 327 (gizlilik + hız 0,7 → 0,15 sn).
4. Rol ayrımı denetimi: 4 kişi × 18 ekran (misafir: Arda, Mina · host: Nehir, Mert) → sızıntı 0.
   Host başvurusu uçtan uca: form → host_applications pending → BO listesi → BO onayı → rol host → uygulamada host alanları açılır.
   Ek bulgu B23: host olmanın 4 yolu vardı (biri anında, BO'suz) + create_availability_base arka kapısı.
   KARAR (Gökberk): tek yol BO onaylı başvuru → SQL 328 + app (tüm "host ol" girişleri başvuru formuna; kayıtta host seçen
   misafir açılır ve form kendiliğinden gelir; bu kişiye seyahat sihirbazı kendiliğinden açılmaz).
5. Google/Apple ve e-posta:
   - Google hesap seçici çıkıştan sonra gelmiyordu → prompt=select_account (B24)
   - doğrulama açıkken kayıtlı e-postayla kayıt sessizce "e-postanı kontrol et"e düşüyordu → identities boş = kayıtlı (B25)
   - "zaten hesap var" mesajı Google/Apple'ı anıyor
   - sunucu girişi reddederse (silme/yasak) OAuth dönüşünden okunur → "Bu hesap kapatıldı…"
   - Hesap silme: 14 gün (karar gerekçesi raporda) → SQL 329: silme sürecinde giriş kilidi (auth banned_until +15 gün),
     14. gün gece otomatik anonim (pg_cron ll-silinen-hesap-anonim 03:30), e-posta + Google/Apple kimliği serbest,
     yasaklı hesabın e-postası kalıcı engelli (sha256 özeti), silinip dönen e-postaya hoş geldin kredisi tekrar verilmez.
   - B22: BO "Anonimleştir" auth.users'ta olmayan kolonlara yazıyordu → hiç çalışmıyordu → 329'da düzeltildi.

## Değişen dosyalar
- App.js · src/ekranlar_ana.js · src/social.js · src/i18n.js
- render_check/sosyal_giris_test.js (yeni, render zincirinde) · package.json (render)
- web_sahne: akis_e2e_b7_rol.py · akis_e2e_b8_hesap.py (yeni) · akis_e2e_bolumler.py · akis_e2e_b4_kurallar.py ·
  pg_kopru.py (banned_until) · rapor_sablon.html
- sql: 325 · 326 · 327 · 328 · 329 · SQL_SIRA.txt
- Yerel ortam: service_role BYPASSRLS (Supabase ile aynı; yerel test DB'sinde)

## Supabase'de çalıştırılacak SQL (sırayla) — sql/SQL_SIRA.txt en üst blok
1. 325_seyahat_cakismasi_farkli_havalimani.sql
2. 326_kisi_ara_aday_siniri.sql
3. 327_tanis_profil_gorunurlugu.sql
4. 328_host_tek_yol_bo_onayli_basvuru.sql
5. 329_silinen_hesap_14_gun_anonim.sql  (sonra Cron'da ll-silinen-hesap-anonim)

## Testler
- Tam regresyon (9 bölüm: tarama · giriş · ana · Keşfet · iş kuralları · BO · ekranlar · rol · hesap): 182/182
- npm run render: 77/77 · 56 ekran ×2 tema · giriş kapısı 39/39 · yönlendirme 18/18 · sosyal giriş 5/5
- npm run be: yetki 0 bulgu · hata kodu 152, çevirisi eksik 0
- Eşdeğerlik: kisi_ara 820 · Tanış (eski ∩ profil_gorunur_mu) 164 → fark 0

## Açık / Gökberk'ten
1. SQL 325–329'u koş.
2. BO onayı olmadan host olmuş mevcut hesaplar (328 sonundaki sorgu) — gözden geçir.
3. 14 gün içinde geri alma şu an BO'da elle; istenirse BO'ya "Hesabı geri al" düğmesi.
4. Supabase Auth ayarları (panelden teyit): Google + Apple sağlayıcıları açık · Redirect URLs loungelink://** ·
   "Confirm email" açık/kapalı hangisi (iki durum da artık doğru davranıyor).
5. Önceki: Universal/App Link · Firebase.
