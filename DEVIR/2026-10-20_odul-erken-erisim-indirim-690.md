# DEVIR · 20 Ekim 2026 · Ödül mağazası: erken erişim · plana göre indirim · vitrin — app 6.9.0

Gökberk'in kararları (20 Ekim):
- Konsiyerj basamağı kaldırıldı (SQL 337'ye eklendi; 337 doğrulaması 12 satır).
- Ödül ekonomisinde şimdilik SINIR YOK (ayda 4 buluşma / 90 günde 1 önerileri reddedildi; denge en sonda).
- Haftalık stok fikri yok. Çekiliş yok (Milli Piyango izni).
- Ücretli plana erken erişim + plana göre ödül indirimi: oranlar BO'dan, her şey dinamik.
  "2700 gösterip 3000 çekmesin" → fiyat yalnız sunucuda.
- Tasarım (önizleme v5 onaylı): gece kartı (takımyıldız kartı), şampanya düğme, Yolcu'da sayaç,
  ücretlide sayaç yok, rozet ücretlide "Erken erişim", Yolcu'da "Sık Uçan ve Jetset'e erken erişim".
- Vitrin süresi ayrı kutu ("Vitrinde göster" + gün); bitince ödül listeye iner, iki yerde görünmez.

## Değişen dosyalar
### SQL (Supabase'de henüz koşulmadı) — `sql/338_odul_erken_erisim_plan_indirimi.sql`
- `rewards`: erken_erisim, acilis_at, erken_erisim_gun (1–30), vitrin_bitis, plan_indirimi_yok; kısıt.
- `plan_catalog.odul_indirim_yuzde` (0–50; başlangıç Sık Uçan 5, Jetset 10). `redemptions.liste_puani`.
- RLS: açılış anı gelmemiş ödül kimseye görünmez.
- `odul_fiyati_ic` (10'un katına aşağı yuvarlar; indirim yoksa liste fiyatı), `plan_ucretli`.
- `odul_magazasi()`: kullanıcının fiyatı, plan fiyatları, erken/alabilir/vitrin, sunucu saati,
  `sonraki_degisim` (istemci tam o anda yeniler), indirimli ve ücretli plan listeleri.
- `redeem_reward(p_reward_id, p_beklenen default null)`: kilit önce; erken erişim kapısı
  (`odul_erken_erisimde`), fiyat sunucuda, `p_beklenen` farklıysa `odul_fiyati_degisti`;
  redemptions.cost_points = ödenen (iade bunu geri yükler). Eski imza düşürüldü.
- `odul_yayin_ayarla` (BO, service_role): vitrin tekliği, erken alanlarının sıfırlanması.
  `bo_odul_fiyatlari` (BO tablosu için sunucu hesabı). `set_featured_reward` vitrin_bitis'i temizler.
- `subscription_plans`: haklar'a "Ödüllerde %X indirim" (oran > 0 ise) + "Yeni ödüllere erken erişim".
- `my_plan` yaması: hediye sayacı 30 gün penceresi; ücretli planda kazanç cümlesi.
- `sql/SQL_SIRA.txt` (10. tur), `sql/KURULUM_TABLOSU.sql` 373 elle (tablo_uret.py KOŞMA).

### App 6.9.0 (versionCode 293, buildNumber 287)
- `src/odul_magaza.js` (yeni): VitrinKarti, MiniErken, MiniFiyat, IndirimBandi, TR ekleri
  (bulunma/yönelme), sunucu saatli geri sayım, bitince yenileme.
- `src/ekranlar_yalin.js` Marketplace: `odul_magazasi` (338 yoksa eski yol), p_beklenen ile alım,
  hata kodlarında yenileme, kategori çipleri yalnız dolu kategoriler, kart düzeni (fiyat üstte, düğme altta).
- `App.js`: Marketplace'e `onPlans` (Planlar açılır, geri → mağaza) ve `lang`.
- `src/theme.js` ODUL jetonları; `src/i18n.js` odul* metinleri + errMap (odul_erken_erisimde,
  odul_fiyati_degisti, erken_erisim_eksik, vitrin_suresi_gecersiz); ölü pointsUnit/shopHeroReward silindi;
  mağaza "Planına göre +100 · +250 · +500".
- `src/legal.js` (+BO, site) LEGAL_VERSION 2026-10-20: plan ayrıcalıkları (ödüller) maddesi.
- `web_sahne/cek.py`: `gen=NNN` genişlik parametresi; sahneler 22b–22g. `sahne_seed.sql`: vitrin ödülü.
- `web_sahne/akis_e2e_b2_ana.py` (19 Ekim): istek_red SQL 336'ya uyduruldu.

### BO 1.101.0 (main) · Site 0.72.0 (site-v7 + main)
- BO › Ödüller: satır altında "Yayın" (YayinFormu.jsx): vitrin + gün, erken erişim kutusu (alanlar
  yalnız işaretliyken), açılış İstanbul saati, plan indirimi yok; "Planlara göre" sütunu; rozetler.
  Yeni ödül formu: maliyet türü, doğru kategoriler (varsayılan "lounge" kısıta takılıyordu).
- BO › Planlar: "Ödül indirimi %". BO 1.100.1 (20 Ekim): kullanıcı Planı Ata listesi düzeltildi.
- Site: PlanKartlari oranı `subscription_plans`'tan canlı okur; SSS.

## Testler (sayılarla)
- SQL 338 yerel: doğrulama 11/11 · senaryo t338 **22/22** (Jetset 2700 / Sık Uçan 2850 / Yolcu 3000,
  yanlış beklenen reddedilir, iade 2700, 2750 bakiye ile 2700'lük alınır, oran 0 → indirim yok,
  süre bitince Yolcu alır, vitrin bitince listeye iner, gelecek ödül görünmez/alınamaz, BO sıfırlama).
- SQL 337 yerel 12/12 · t337 18/18 (Konsiyerj sonrası).
- app `npm run verify` **77/77 temiz** (ortam: cairosvg yok — ürün kusuru değil).
- sahne: 116 sahne, hata 0 (arıza sahneleri 42/43/44/49 bilerek bozuk) · dokunma yolu düşen 0.
  89_seyahat_duzenle ilk koşuda köprü bağlantısı (push jetonu) düştü; tek başına 0.
- akış e2e **217/217**.
- BO check + build temiz · site verify 7/7, check temiz, build temiz.

## APK
- Android önizleme 6.9.0 (293): https://expo.dev/artifacts/eas/O7NEyyg9yrqJ0aIyYqORBksc6RWpAB93rQ8SxWYODdA.apk

## Açık / Gökberk'ten
1. SQL sırası: 335 → 336 → 337 → 338.
2. Ödül ekonomisi dengesi (puan/para) — her şey bitince birlikte.
3. Ortaklık belgesi: kod havuzu 200 mü 50 mi (belgedeki yorum).
4. 320 px'te üst bantta "LOUNGEL…" kısalıyor (bakiye hapı yer kaplıyor) — eski, ayrı iş.
5. Firebase 10/10b, RevenueCat anahtarları, eas.json appleId + ascAppId.
