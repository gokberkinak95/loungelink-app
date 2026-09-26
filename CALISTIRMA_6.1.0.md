# ÇALIŞTIRMA · 26 Eylül 2026 · SQL 303–305 · site 0.67.0 · app 6.1.0

Bu turun sırası önemli. Aşağıdaki A ve B **hemen** yapılabilir. C bir kerelik
kurulumdur. D, 6.1 ile 5.17.1 birleştirildikten sonra yapılır.

---

## A · Supabase (hemen)

SQL Editor'de, her dosyanın tamamını ayrı ayrı yapıştırıp çalıştır:

1. `sql\303_ertelenen_puan_ana_sayfadan_duser.sql`
2. `sql\304_kesfet_engelinin_gercek_sebebi.sql`
3. `sql\305_erisim_kaynagi_etiketleri.sql`

Üçü de tekrar koşulabilir. 305 sonunda kendini ölçer: alt çizgili bir erişim
kaynağı kalırsa hata verip durur.

---

## B · Web sitesi 0.67.0 (hemen)

```powershell
cd C:\LoungeLink\website
git fetch origin
git checkout main
git pull
git merge origin/claude/peaceful-brown-02srm2
npm install
node verify.js
npm run build
git push
```

`git merge` bir commit mesajı editörü açarsa kaydedip kapat. Push, siteyi yayına alır.

---

## C · Bir kerelik kurulum: C:\LoungeLink'i GitHub'a bağla

Neden: PC'ndeki uygulama 5.17.1, benim bulutta çalıştığım taban 5.14. 5.17.1'i
bir kez GitHub'a gönderirsen 6.1'i onun üstüne birleştiririm. Bundan sonra
bulut oturumlarının her değişikliği tek komutla PC'ne gelir.

```powershell
robocopy C:\LoungeLink C:\LoungeLink_yedek_2609 /E /XD node_modules .next .expo
cd C:\LoungeLink
git init
git remote add origin https://github.com/gokberkinak95/loungelink-app.git
git fetch origin
git reset origin/main
git checkout -b pc-5.17.1
git add rnapp sql
git commit -m "PC 5.17.1 - Cowork teslimi (rnapp + sql)"
git push -u origin pc-5.17.1
```

- İlk satır tam bir yedek alır (node_modules hariç).
- `git reset origin/main` dosyalarına **dokunmaz**; yalnız Git'e "karşılaştırma
  tabanı bu" der. `git add rnapp sql` yalnız bu iki klasörü gönderir;
  website, backoffice ve _arsiv gitmez.
- Push'tan sonra bana "pc-5.17.1 gönderildi" yazman yeterli.

---

## D · Uygulama 6.1.0 (birleştirmeden sonra)

Birleştirme bitince sana haber vereceğim. Sonra:

**Tek komut:**

```powershell
cd C:\LoungeLink
Move-Item KUR.ps1 _arsiv\KUR_5.17.1.ps1
git fetch origin
git checkout claude/v6-gozlemler
powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -Atla bo,site
```

(İlk satır eski KUR.ps1'i arşive alır; yenisi depodan gelir. Sonraki turlarda
yalnız son satır yeter; `-Guncelle` eklersen önce GitHub'dan çeker.)

**Seçenekler:**

- Yalnız denetim: `powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -SadeceDenetim`
- Önce güncelle, sonra hepsi: `powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1 -Guncelle`
- BO ve site değişikliklerini de gönder: `... KUR.ps1 -Uygula "0.68.0"`

**Elle yapmak istersen, her satır ayrı:**

BO (bu turda değişmedi, istersen atla):

```powershell
cd C:\LoungeLink\backoffice
npm install
node check.js
npm run build
```

Site: yukarıdaki B bölümü.

App:

```powershell
cd C:\LoungeLink\rnapp
npm install
node check.js
npx eas build --platform android --profile preview
```

Telefonda sürüm **6.1.0** (versionCode 267) görünmeli.

### Telefona kurmak (QR akışı değişmedi)

- Build bitince terminal bir **QR kod ve bağlantı** basar. Telefonun kamerasıyla
  okut, APK'yı indir, kur.
- Terminali kapattıysan: expo.dev → proje → **Builds** → en üstteki 6.1.0 →
  **Install** (aynı QR orada da var).
- Bu projede OTA güncelleme kurulu değil. Yani her uygulama değişikliği zaten
  yeni bir build ister; kamera düzeltmesi için ayrıca bir şey yapman gerekmiyor.
  Yeni APK eskisinin üstüne kurulur (imza EAS'ta aynı).

---

## Bu turda koşulan testler (bulutta)

- SQL zinciri sıfırdan: 340 dosya, 0 hata
- app: check.js temiz · render 37/37 · 55 ekran hatasız · schema 1211 kolon ·
  contract 501 RPC · tip_check temiz
- site: check.js temiz · verify.js 1 kırmızı (ikon farkı; PC'de 5.17.1 ikonlarıyla kapanır)
