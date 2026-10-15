# DEVIR — 16 Ekim 2026 · ekonomi, ret riskleri, mağaza görselleri/metinleri · app 6.4.1

Rehber (güncel, §4 şablonlar, §5 Apple e-posta aktarımı, §6 iPad/Mac, §14 mağaza metinleri):
https://claude.ai/artifact/DRgmDDYaZeHkcYCcWx8oWS

## Sürümler
- App **6.4.1** · versionCode **287** · buildNumber **281**
- BO 1.97.0: Bekleme Listesi ekranı eklendi (CSV indir, davet edildi işaretle). Push edildi, yayında.
- Site 0.70.1:
  - "beta" dili kalktı → "Erken erişim"; plan fiyat cümleleri düzeltildi. YAYINDA (onaylı, 3e65868).
  - Plan kartları yenilendi (DB ile birebir, mağaza fiyatları): **önizleme gönderildi, ONAY BEKLİYOR, yayına alınmadı.**

## SQL 334 (Supabase'de çalıştırılacak)
- Ekonomi:
  - Kâhya 12 → 16 kredi (kredi başına 20,75 → 15,56 ₺; önce Sık Uçan'dan pahalıydı).
  - Yolcu aylık kredisi birikmez (bakiye paya tamamlanır).
  - Kayıt hediyesi 5 → 3.
- Apple 1.2: `uygunsuz_maskele` + tetikleyiciler. Kapsam: profiles (ad, bio, meslek), connection_requests, kural_sorulari, ratings, requests, invites, availabilities.rule_note, sohbet (işaretlenir).
- Testler:
  - 334 senaryo 6/6 (Yolcu birikmez/verir/tekrar, Kâhya yükseltme farkı 15, bio maskesi);
  - sohbet maskesi + bayrak ✓;
  - 332 senaryo hâlâ 15/15.

## App değişiklikleri
- Cüzdan: mağaza satışı açıkken ücretsiz "Kredi talep et" gizli (paket satışını kemiriyordu).
- Şifre sıfırlama `redirectTo` → `https://panel.loungelink.co/sifre-sifirla` (köprü: telefonda uygulamayı açar, bilgisayarda / uygulama içi tarayıcıda web formu).
- `deleteAccountBody` mağaza adı geçmeden (Apple 2.3.10).
- `pwMinPh` i18n.
- `android.blockedPermissions`: ACTIVITY_RECOGNITION, RECORD_AUDIO (kullanılmıyor). Depolama izinleri bilerek KALDI: Android ≤12'de galeri seçici istiyor.

## Mağaza görselleri
- `rnapp/magaza/uret.py` → `rnapp/magaza/cikti/`
  - appstore 6 × 1320×2868
  - play 6 × 1080×1920, feature 1024×500, icon-512
- Kaynak: cek.py gerçek sahneler (02_kesfet, 50_istek_gonder, 05_tanis, 06_sohbet, 87_oturum_canli, 88_oturum_puanla).
- **ONAY BEKLİYOR** (pazarlama görseli kuralı).

## Testler
- e2e tam regresyon (13 bölüm): **192/192** (334 yerelde uygulanmış haliyle).
- check.js temiz; kurulum / returns / sql_editor denetimleri temiz.
- Site verify 7/7 + build ✓. BO check + build ✓.

## Supabase'de çalıştırılacak (sırayla)
330, 331 (çalıştırılmadıysa) → 332 → 333 → **334**

## Bekleyen kararlar
- Mağaza görselleri ve site plan kartları onayı.
- Apple/Google hesapları, RevenueCat anahtarları (rehber).

## Build
- Android önizleme APK 6.4.1: https://expo.dev/artifacts/eas/O88MRAPh3KNkYLdlysRQ5CjhcKR1FfTXd3MSfhVCELY.apk
