# ÇALIŞTIRMA · 28 Eylül 2026 · SQL 303–305 · site 0.68.0 · app 6.2.0

> Akşam güncellemesi: app 6.2'ye K1′ (yalnız splash ışığı) ve K2 iz düzeltmesi eklendi
> (sürüm aynı: henüz build alınmadı). Site 0.68.0 = 0.67 + hareket katmanı W1–W9.
> Ayrıntı ve yeni sohbet için ilk mesaj: `DEVIR\2026-09-28b_SON_yerel-oturum-ve-cowork.md`.

> `CALISTIRMA_6.1.0.md`nin yerine geçer. O dosyadaki C adımında taban YANLIŞTI
> (`origin/main`); doğrusu aşağıda (`96eb4ae`).

Sıra önemli. A ve B **hemen** yapılabilir. C, 5.17.1 ile 6.2'yi tek dalda
birleştirir; D ondan sonra.

---

## A · Supabase (hemen)

SQL Editor'de, her dosyanın tamamını ayrı ayrı yapıştırıp çalıştır:

1. `sql\303_ertelenen_puan_ana_sayfadan_duser.sql`
2. `sql\304_kesfet_engelinin_gercek_sebebi.sql`
3. `sql\305_erisim_kaynagi_etiketleri.sql`

Üçü de tekrar koşulabilir. 305 sonunda kendini ölçer.

---

## B · Web sitesi 0.68.0 (hemen)

```powershell
cd C:\LoungeLink\website
git fetch origin
git checkout main
git pull
git merge origin/claude/peaceful-brown-02srm2
npm install
node check.js
npm run build
git push
```

---

## C · 5.17.1 ile 6.2'yi birleştir (bir kerelik)

Bunu **yerel Claude Code oturumuna yaptırman** en kolayı (bkz. `DEVIR\2026-09-28b_SON_yerel-oturum-ve-cowork.md`).
Elle yapmak istersen:

```powershell
robocopy C:\LoungeLink C:\LoungeLink_yedek_2809 /E /XD node_modules .next .expo
cd C:\LoungeLink
git config --global core.autocrlf true
git init
git remote add origin https://github.com/gokberkinak95/loungelink-app.git
git fetch origin
git reset 96eb4ae
git checkout -b pc-5.17.1
git add rnapp sql
git commit -m "PC 5.17.1 - Cowork teslimi (rnapp + sql)"
git push -u origin pc-5.17.1
git merge origin/claude/v6-gozlemler
```

- `git reset 96eb4ae` dosyalarına **dokunmaz**. Git'e "karşılaştırma tabanı saf 5.14" der.
  (5.17.1 de 6.2 de 5.14'ten türedi; ortak ata bu olmalı.)
- `git merge` çakışma bildirirse çakışan dosyaları Claude'a çözdür ya da
  bana listeyi gönder. Çakışma yoksa doğrudan D'ye geç.
- Birleştirmeden sonra: `git push`

---

## D · Uygulama 6.2.0 (birleştirmeden sonra)

**Tek komut:**

```powershell
cd C:\LoungeLink
powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -Atla bo,site
```

(İlk seferde eski `KUR.ps1` birleştirmede yenisiyle değişir; eskisi yedekte durur.)

**Seçenekler:**

- Yalnız denetim: `powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -SadeceDenetim`
- Önce GitHub'dan çek, sonra hepsi: `powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -Guncelle`
- BO ve site değişikliklerini de gönder: `... KUR.ps1 -Uygula "0.68.0"`

**Elle yapmak istersen, her satır ayrı:**

BO (bu turda değişmedi):

```powershell
cd C:\LoungeLink\backoffice
npm install
node check.js
npm run build
```

Site: yukarıdaki B.

App:

```powershell
cd C:\LoungeLink\rnapp
npm install
node check.js
npx eas build --platform android --profile preview
```

Telefonda sürüm **6.2.0** (versionCode 268) görünmeli.

### Telefona kurmak

- Build bitince terminal **QR kod + bağlantı** basar; telefonun kamerasıyla okut, APK'yı kur.
- Terminali kapattıysan: expo.dev → proje → **Builds** → en üstteki 6.2.0 → **Install**.
- OTA kurulu değil; her uygulama değişikliği yeni build ister (kamera için ek bir şey yok).
- Kurulumdan sonra ilk barkod taramasında Android kamera iznini **soracak**. Eski
  sürümde hiç sormuyordu; sebep aşağıda.

### Kamera neden açılmıyordu, şimdi ne olacak

- "Biniş kartını doğrula" → **Kamerayla tara**: uygulamanın İÇİNDE bir tarayıcı açılır
  (diğer uygulamalardaki gibi; PDF417/Aztec/QR okur).
- Sorun kodda değil `app.json`daydı. `expo-image-picker` ayarındaki
  `"cameraPermission": false`, Android manifest'ine
  `<uses-permission android:name="android.permission.CAMERA" tools:node="remove"/>`
  yazdırıyordu. İzin manifestte olmadığı için Android sormadan reddediyordu.
  `expo prebuild` ile iki ayar yan yana üretilip ölçüldü.
- Yeni ayarda izin ekleniyor. Kullanılmayan **mikrofon** izni de artık engelleniyor.
- İzni bir kez "bir daha sorma" ile reddeden kullanıcıya ekranda **"Ayarlardan
  kamerayı aç"** düğmesi çıkar.

---

## Bu turda koşulan testler (bulutta)

- SQL zinciri sıfırdan: 340 dosya, 0 hata (303–305 dahil)
- app: check.js temiz · render 37/37 · 58 web sahnesi hatasız · verify.js kırmızı yok
  (tip_check yerel koşucuyla) · gren 1.67 pt · schema 1211 kolon · contract 501 RPC
- site 0.68: check.js · tasarim_check · palet_check temiz · build temiz · verify.js 1 kırmızı (ikon farkı; PC'de 5.17.1 ikonlarıyla kapanır)
