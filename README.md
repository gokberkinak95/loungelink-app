# LoungeLink — uygulama deposu

| klasör | ne |
|---|---|
| `rnapp/` | Expo / React Native uygulaması (iOS · Android) |
| `sql/`   | Supabase migration'ları (`001…300`), tohumlar, `pg_run.py` yerel replika |

## Hızlı başlangıç

    cd rnapp
    npm ci
    npm start            # Expo
    node check.js        # statik denetim
    npm run render       # render / mount testleri

## Yerel veritabanı replikası

    cd sql
    python3 pg_run.py --reset          # 001…300, sıfırdan (Postgres 16)
    psql -d ll -f SEED6_TEST_DUNYASI.sql
    psql -d ll -f ../rnapp/web_sahne/sahne_seed.sql

`pg_net` ve `pg_cron` Supabase'e özgü eklentiler; yerel Postgres'te yoksa
bootstrap 014'te düşer. Ağsız taklitleri (stub) kurmak için
`/usr/share/postgresql/16/extension/` altına `pg_net.control` +
`pg_net--0.0.sql` ve `pg_cron.control` + `pg_cron--0.0.sql` koymak yeterli.

## Site ile bağ

Site deposu (`loungelink-website`) bu depoyu **yan klasörde** (`../rnapp`)
arar: fontlar (`build_fontlar.py`), palet (`site_paleti.py`) ve ekran
görüntüsü tazeliği (`ekran_goruntusu_check.py`) buradan okunur.

    <çalışma kökü>/
      loungelink-website/
      rnapp/   ← bu deponun rnapp klasörü (ya da sembolik bağlantısı)

## Gizli değerler

Depoda gizli anahtar yok. `src/supabase.js`teki `sb_publishable_…` anahtarı
tasarım gereği herkese açıktır (güvenlik RLS'tedir). `.env*`, keystore,
`google-services.json`, `GoogleService-Info.plist` `.gitignore`da.
