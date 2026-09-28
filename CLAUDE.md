# LoungeLink — çalışma kuralları (her Claude oturumu önce bunu okur)

Bu dosya Cowork ile Claude Code arasında ORTAK hafızadır. Hangi oturum
çalışırsa çalışsın aynı kuralları uygular. Kuralları Gökberk koydu.

## Oturum başında
1. `DEVIR\` klasöründeki EN YENİ dosyayı oku: son oturum ne yaptı, ne açık kaldı.
2. Sürümleri dosyadan oku, ezberden yazma:
   - `rnapp\app.json` (version, android.versionCode, ios.buildNumber)
   - `backoffice\package.json`, `website\package.json`
3. `sql\` içindeki en büyük numara = son migration. Yeni dosya = bir fazlası.

## Oturum sonunda (ZORUNLU)
`DEVIR\YYYY-MM-DD_<kisa-ad>.md` yaz:
- ne değişti (dosya listesi) · yeni sürümler
- Supabase'de çalıştırılacak SQL'ler (sırayla) → aynı listeyi `sql\SQL_SIRA.txt`e de yaz
- koşulan testler ve SAYILARI (ör. "verify 77/77", "e2e 171 geçti")
- açık kalanlar / Gökberk'ten beklenen kararlar

## Kurallar
- Kabuk Windows PowerShell 5.1: `&&` YOK. Komutlar ayrı satır.
- Build talimatı her seferinde İKİ biçimde verilir:
  1. Tek komut: `powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1`
  2. "Elle yapmak istersen, her satır ayrı" (BO · site · app blokları)
- `KUR.ps1` ve her `.ps1` YALNIZ ASCII. (BOM'suz UTF-8'deki tek bir "—"
  5.1'de betiği sözdizimi hatasına çevirdi; `rnapp\ps1_check.py` ölçer.)
- Tasarım değişikliği (app / site / pazarlama görseli): ÖNCE önizleme göster,
  onay al, SONRA uygula.
- Eski dosya SİLİNMEZ → `_arsiv\` altına taşınır.
- Ölçmeden teşhis yok. Hatalar sayıyla söylenir, saklanmaz.
- Üretilen dosya teslim edilmeden iş bitmiş sayılmaz.
- Kullanıcıya ham kod gösterilmez (`fully_booked` vb.); TR ve EN'de alt
  çizgili metin yok. Yeni hata kodu → `rnapp\src\i18n.js` errMap'e TR+EN cümle.
- SQL, Supabase SQL Editor'de koşar ve Editor her ifadeyi AYRI işlemde koşar:
  satır başında `create temp table` yok, psql meta-komutu (`\set` …) yok.
  İfadeler arası veri `tezgah.*` kalıcı tablolarında tutulur.
- Seed'ler yalnız test hesaplarına yazar (`public.seed_test_hesabi(email)`).
- Sürüm artırırken: `app.json` (3 alan) + `package.json` + `package-lock.json`.

## Denetimler
- app: `cd rnapp` → `node check.js` (hızlı) · `npm run verify` (tam, Python ister)
- BO: `cd backoffice` → `node check.js` → `npm run build`
- site: `cd website` → `node verify.js` → `npm run build`

## İki oturum aynı anda çalışmaz
Cowork ve Claude Code AYNI dosyalara aynı anda dokunmaz; SQL numarası çakışır,
biri diğerinin değişikliğini ezer. Bir oturum bitirir, DEVIR yazar, diğeri okur.
