# DEVIR · 4 Ekim 2026 (2) · uçtan uca test + yük testi · app 6.3.3 · BO 1.96.3

Önceki: DEVIR/2026-10-04_v7-site-ikinci-tur-631.md

## APK (EAS preview, 6.3.3 · FINISHED)
https://expo.dev/artifacts/eas/PdumHeeZWq0Sl7R4w_rrFL18WX12AO8hSmbdBky9GKs.apk
(google-services.json hâlâ yok → Android push bu build'de de çalışmaz.)

## Sürümler (dosyadan)
- app 6.3.3 · versionCode 282 · buildNumber 276 (app.json + package.json + lock)
- backoffice 1.96.3 (package.json + lock)
- website 0.70.0 (değişmedi)

## İstek (Gökberk)
App + BO + BE için performans/yük testi (sınırlar, zorlanma noktaları, önlemler) ve
sayfa sayfa / akış akış uçtan uca test (misafir + host; kabul/ret/iptal/düzenle;
mutlu · uç · alternatif · olumsuz), bulunan sorunların düzeltilmesi.

## Rapor
- Artifact: https://claude.ai/artifact/1WEz5xZPBbfxVc3hF7CaXS (sayfa sayfa beklenen/gerçekleşen tablosu, bulgular, sınırlar)
- Üretici: rnapp/web_sahne/rapor_uret.py (girdi out/akis_e2e.json + out/akis_bulgular.md + rapor_sablon.html)

## Commit
- loungelink-app v7-tema 86d7e4b (push) · loungelink-backoffice main 5b087c3 (push)

## Değişen dosyalar
### App (rnapp)
- src/ekranlar_ana.js — Keşfet çift sorgu kaldırıldı (P8) · kesfet_ozeti: kart çizilmeyecekse sorulmaz + 60 sn önbellek (P9) ·
  istek ekranı onay kutusu role=checkbox (B11) · önkontrol sebep cümlesi e_<kod> ayrıntılı (B12) ·
  Tanış araması etkin süzgeç dışındaki kişiyi gösterir + arama sürerken "seyahatini ekle" kartı gizli (B18)
- src/ekranlar_yalin.js — istek durum etiketi expired/completed (B8) · Cüzdan bakiyesi user_balances (B17)
- src/screens.js — Profil kredisi user_balances (B17) · (sabah) seyahat kartı a11y etiketi (B1)
- App.js — (sabah) B2 · B3 · B5
- src/i18n.js — not_your_connection · active_session_exists · cuzdan_sahibi_degil TR+EN (B9)
- render_check/giris_kapisi_test.js — Animated taklidine stop() (d.stop uyarıları 0)
- YENİ render_check: be_yetki_tarama.py · be_bo_istemci.py · hata_kodu_tarama.py · perf_olcum.py · yuk_eszamanli.py ·
  yuk_veri_uret.sql · bo_perf.py   · package.json: "be" betiği (be_yetki_tarama + hata_kodu_tarama; yerel ll gerekir)
- YENİ web_sahne: akis_e2e.py (+ kart_dokun / kaydir_bul / Türkçe büyük harf dokunuşu) · akis_e2e_bolumler.py ·
  akis_e2e_b2_ana.py · akis_e2e_b3_kesfet.py · akis_e2e_b4_kurallar.py · akis_e2e_b5_ekranlar.py · akis_e2e_b6_bo.py ·
  akis_dbg.py · rapor_uret.py · rapor_sablon.html · cek.py (her koşu SEED8→SEED9 da yeniden atılır)
### BO
- public/icon.png · public/favicon.png ← rnapp/assets (v7 ikon; eskiler _arsiv/backoffice_ikon_20261004/) (B20)
### SQL (yeni)
- 315 … 324 (aşağıda)

## Supabase'de çalıştırılacak SQL (sırayla) — aynı liste sql/SQL_SIRA.txt'de
1. 315_bo_rapor_fonksiyonlari_kullaniciya_kapali.sql
2. 316_bayat_istek_supurgede.sql
3. 317_kesfet_olcek.sql
4. 318_ana_sayfa_akisi_olcek.sql
5. 319_tanis_gorunurluk_olcek.sql
6. 320_istek_puani_daraltilmis.sql   (317'den sonra)
7. 321_erisim_karari_kart_secimi_belirli.sql
8. 322_hesap_silme_calisir_ve_acik_isleri_kapatir.sql
9. 323_ilan_ac_saat_ve_kontenjan_kapisi.sql
10. 324_tanis_silinmis_yasakli_suzgeci.sql   (319'dan sonra)
Her dosyanın sonunda doğrulama sorgusu: tüm satırlarda tamam = true.

## Testler ve sayılar
- Uçtan uca (web sahnesi + gerçek RLS): 166/166 (tam koşu 165/166 — tek kırmızı test aracının belirsizliğiydi: aynı başlıklı iki
  bildirim; araç düzeltildi, o bölüm yeniden koşuldu 16/16). out/akis_e2e.json bölüm bazında birleşir.
  tarama 98 · giriş/kayıt 18 · ana sayfa 17 · Keşfet/kural/istek 16 · iş kuralları 11 · BO→uygulama 5 · ekranlar 16
- Bölümler: tarama (tüm sahneler ham kod/hata) · giriş/kayıt · ana sayfa · Keşfet+kural motoru+istek (SEED8 2xx/1xx vakaları) ·
  iş kuralları BE 11 · BO→uygulama 5 · ekranlar (profil/cüzdan/bildirim/planım/tanış/sohbet/davet/ilanlarım) 16
- npm run render: screens 77/77 · mount 56 ekran ×2 tema · tasma 0 · giris_kapisi 39/39 · kayit_yonlendirme 18/18 · uyarı 0
- node check.js temiz · app_perf_check şelale 0
- npm run be: yetki taraması 88 BO + 170 app fonksiyonu → 0 bulgu · hata kodu 150 → çevirisi eksik 0
- Eşdeğerlik (performans değişikliklerinde eski gövde ile): Keşfet 246+164 · özet 164 · Tanış/arama/radar 656 · nabız 246 ·
  istek puanı 1.673 · prerank 248 → fark 0
- Yük: ll_yuk (50.076 üye · 30.088 ilan · 600 bin bildirim); perf_kosu3.txt · yuk_kosu3.txt (render_check/out_perf/)
  ana sayfa p50 @80 eşzamanlı: 22.809 ms → 12 ms · işlem/sn 13 → 63–68 · Keşfet 39,6 sn → 1,2 sn
- BO: node check.js temiz · npm run build OK (88 sayfa, ilk yük ≤156 kB) · bo_perf en ağır rule_full_report 2,3 sn
- Site: verify.js 7/7 (değişiklik yok)

## Açık kalanlar / Gökberk'ten beklenen
1. B15 kararı: aynı saatte FARKLI havalimanında seyahat reddedilsin mi?
2. SQL 315–324'ü Supabase'de koş.
3. Universal/App Link girdileri (Apple Team ID, canlı alan adı) · Firebase google-services.json · Redirect URLs loungelink://**.
4. Kalan sınırlar (raporda): Keşfet havalimanı listesi ~150–220 ms (büyümede ilan kartı ön-hesabı + sayfalama) ·
   kisi_ara geniş eşleşme (aday sınırı + trigram) · kesfet_ozeti sunucu önbelleği (pg_cron dakikalık tablo).
5. pg_cron 'll-supurge' (5 dk) canlıda açık mı — panelden teyit.
