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

## Ek · 20 Ekim akşam — site menüsü, marka adı, ortak hata görünümü (app 6.9.1 → 6.9.2, site 0.72.0 → 0.72.2)
- **Site mobil menü** (Gökberk: "kullandıktan sonra tekrar açınca kesik açıyor"): ÖLÇÜLDÜ — kaydırılmış sayfada çubuğun
  cam efekti (`backdrop-filter`, 0.45 sn geçiş) tam ekran menünün kapsayıcısı oluyor, menü 136 px'e hapsoluyordu.
  Menü `<header>` dışına taşındı (z 49), geçişten backdrop-filter çıktı, zemin ilk karede opak, içerik süzülür,
  aynı sayfa çapalarında önce kilit kalkıp sonra kaydırılır, dokunma vurgusu kaldırıldı.
  Ölçüm: aç → Nasıl çalışır → tekrar aç, 320/390/440 × 3 tur kare kare: menünün göründüğü 438 karede kesik/saydam kare 0.
- **App üst bant marka adı** 320 px'te "LOUNGEL…" oluyordu: harf aralığı yalnız sığmadığında 4.6'dan aşağı iner
  (en az 1.5, gerekirse 1 punto küçülür); 390/430 değişmedi. Görünmez ölçüm kabı `testID="olcum"` (cek.py taşma ölçümü sayar değil).
- **Ortak hata görünümü** (`LoadFailPage` · ortak.js): sayfanın ASIL verisi gelmezse başlık + "Liste şu an gelmedi ·
  Yeniden yükle", yarım veri yok. Bağlanan ekranlar: Planlar, LoungePuan, Cüzdan (iki ayrı hata kutusu + yarım sayfa
  kalktı), Tanış, Profil, Planım (rol okunamazsa misafir görünümü yerine; sarı şerit kalktı), Oturum geçmişi, Güven puanı
  (hata "0" gösteriyordu), Davet, Sorularım (sonsuz yükleniyordu), Canlı durum, Herkese açık profil, Lounge erişim ayarı
  (ön dolum gelmezse form varsayılanla açılıp kaydedince EZERDİ), Arkadaş sohbeti.
- **Ek bulgu:** profil sorgusu düşünce host'a "Lounge Erişim Kurulumu" zorla açılıyordu (App.js firstRunAccess) — hata = bilmiyoruz, form açılmaz.
- Sahne tohumu: Kaan'ın seyahati saatten bağımsız (akşam 50_istek_gonder "Seyahat ekle" gösteriyordu — ürün doğru, veri bayat).
- Yeni arıza sahneleri 49b–49h (plan, mağaza, tanış, geçmiş, güven, davet, profil).
- Ortam: GTK3 Runtime kuruldu (Gökberk, winget) → cairosvg çalışıyor (`C:\Program Files\GTK3-Runtime Win64\bin`).
- Testler: verify 77/77 · sahne 123, hata 0 (arıza sahneleri bilerek bozuk), dokunma yolu düşen 0 · akış e2e **224/224** · verify (GTK yoluyla) 77/77, ortam uyarısı 0.
- APK 6.9.1 (marka): https://expo.dev/artifacts/eas/aYMWozrVThPIaMJdtGGIzfy-yv4pucvNgRpRORv_Z8o.apk · 6.9.2 (295): https://expo.dev/artifacts/eas/oVsOtmTFop88tWaXyLnH22vKr6sRgxT362-q97YPUAs.apk

## Ek · 20 Ekim gece — mağaza hazırlığı (app 6.9.3 · site 0.72.3 · SQL 339)
Gökberk: SQL 330–338 Supabase'de koşuldu, hepsi true. Bireysel hesap kesin.
- **SQL 339** (koşulmadı): ödül adlarından marka çıkar (kategori adı; ürün/tedarikçi/puan aynı), ödül bildiriminde
  tedarikçi adı geçmez ("Amazon tarafından hazırlanıyor" → "Hazırlanıyor"), Plan ekranı hediye cümlesi eşik dolunca
  "bir sonraki onaylanan buluşmada açılır". Yerel 5/5, tekrar koşulabilir. SQL_SIRA 11. tur, KURULUM_TABLOSU 374.
- **Yasal (bireysel):** metinler zaten "gerçek kişi · Gökberk İnak". Site check.js gerçek kişide MERSİS/KEP aramıyor.
  **AÇIK: adres** — `ADDRESS` hâlâ "İstanbul, Türkiye — APA GIZ PLAZA" (tebligat adresi değil). Gökberk'ten alınacak;
  3 kopyada değişecek (rnapp/src/legal.js → backoffice/lib/legal.js, website/lib/legal-source.js).
- **Ortak hata görünümü** ek ekranlar: Profili Düzenle (profil gelmezse boş form + Kaydet ad/bio'yu EZERDİ),
  Ayarlar, Kimlik doğrulama (hata "belge yok" sayılıp yeniden yükletiyordu), Şikâyet kişi listesi. Sahneler 49i, 49j.
- **Oturum sonu kazanç** sabit "+500 / +200" yazıyordu → defterden (ref_id = oturum) gerçek tutar.
- **Plan ekranı** ücretli üyede "AĞIRLA, ÖDEME" yerine "PLANININ KAZANCI".
- **Mağaza görselleri** yenilendi: 8 kare (07 LoungePuan · Jetset, 08 Plan · Jetset), App Store 1320×2868 + Play 1080×1920.
  Eski 6.3.1 kareleri `_arsiv/magaza_cikti_6.3.1/`. Sahne tohumu: Selin oturum puanları 100 (Yolcu), son kayıt oturuma bağlı.
- Site 0.72.3: ödül örnekleri markasız.
- Testler: verify 77/77 · sahne 126 (hata 0; arıza sahneleri bilerek bozuk) · dokunma düşen 0 · akış e2e **227/227** (tam koşu 226 + "Tam döngü" testi saat 23:00 sonrası test verisi çakışmasına takıldı — ürün doğru reddediyordu; test penceresi düzeltildi, bölüm 11/11).
- iOS: kod aynı (Expo · tek kod tabanı). İlk iOS build'i Apple girişi ister (rehber §7) → Gökberk başlatır; sonrakileri ben.
  eas.json'da appleId + ascAppId hâlâ REPLACE.

- APK 6.9.3 (296): https://expo.dev/artifacts/eas/7ag5ZHEXG96f64Pp3EcGGoi43GkvOq0WuVMC0WnXPwI.apk

## Ek · 21 Ekim — yasal metin adres kararı (app 6.9.4 · BO 1.101.1 · site 0.72.4)
- Gökberk: açık adres yayınlanmayacak (bireysel geliştiricilerin yaygın uygulaması). Metin: veri sorumlusu Gökberk İnak
  (gerçek kişi) + kvkk@loungelink.co; posta yoluyla yazılı başvuru için posta adresi İSTEK ÜZERİNE 7 gün içinde bildirilir
  (yazılı başvuru kanalı kapanmaz). LEGAL_VERSION 2026-10-21, üç kopya aynı. Site check.js: adres yoksa "istek üzerine"
  cümlesi aranır. loungelink.co MX = Cloudflare Email Routing (kvkk@ yönlendirmesini bir test e-postasıyla doğrula).
- `main` ← `v7-tema` ileri sarıldı (89 commit; çakışma yok). gh kurulu değil, PR yerine doğrudan ileri sarma.
- App 6.9.4 yalnız yasal metin + sürüm; APK alınmadı (bir sonraki derlemeyle gider).

## 21 Ekim (öğleden sonra) — mağaza yolu baştan gözden geçirildi · app 6.9.5
- **SQL 340** `340_jetset_urun_kimlikleri.sql` (yerelde 3/3): mağaza ürün kimlikleri `ll_jetset_aylik/yillik` (Apple),
  abonelik `ll_jetset` (Google) → plan 'kahya' (iç kod). Eski `ll_kahya_*` pasif. Gökberk ürünleri henüz açmadı (6a'da);
  App Store kimliği sonradan değişmediği için şimdi değişti. SQL_SIRA 12. tur, KURULUM_TABLOSU 375 (iki kopya), başlık "son: 340".
- `rnapp/src/odeme.js`: `ll_jetset_*` (ve eski `ll_kahya_*`) → plan kahya. check.js temiz.
- App **6.9.5** (versionCode 298, buildNumber 292). APK alınmadı.
- Mağaza rehberi v17 (https://claude.ai/artifact/DRgmDDYaZeHkcYCcWx8oWS): 6d ve 9 jetset kimlikleri + "kimlik değişmez, Kopyala ile al";
  11 entitlement `jetset`, paketler `jetset_*`, kredi teklifi `kredi_5` (eski metin kredi_6 diyordu — yanlıştı);
  8 hedef API 36 (6.5.1'den beri, uzatma gereksiz) ve Play kontrolünde 36; 7'de APNs anahtar sınırı (ekip başına 2);
  SQL listesine 340; 14'te 8 kare; mağaza metni PLANLAR/PLANS'a ödül mağazası + plan indirimi + erken erişim; "Benim tarafımda" güncel sürümler.
- Yerel inceleme ajanı `.claude/agents/inceleyici.md` (teknik + ürün + QA; kod değiştirmez). `.claude/` gitignore'da → yalnız bu makinede.
- Gökberk'ten: SQL 339 ve 340'ı koş (340, 6d/9'da ürün açmadan önce). Apple ID e-postası + ascAppId; ilk iOS build (§7); Firebase 10/10b; RevenueCat anahtarları.

## 22 Ekim — site 0.72.5: llms.txt (GEO) + canlı SEO denetimi
- Canlı denetim (290 sitemap URL'i, hepsi 200): tekrarlanan title 0; canonical, og:image, h1, JSON-LD hepsinde var ve geçerli; noindex yok.
  Uyarı düzeyinde: 274 sayfada title > 65 karakter (soru biçimi bilerek uzun; Google kırpar, hata değil), 241 sayfada description > 170,
  /en sayfaları `<div lang="en">` ile (kök html tr; Next kısıtı, hreflang var). Eksik olan tek şey llms.txt'ydi.
- `website/app/llms.txt/route.js`: SSS + 72 rehber + 144 kart sayfası veriden; fiyat/oran bilerek yok. Build'de statik, 316 satır.
- Site check 19 sayfa temiz, verify 7/7, build temiz. Betik: scratchpad seo_denetim.py.
- Gökberk'ten: Google Search Console ve Bing Webmaster Tools'a loungelink.co ekleyip sitemap.xml gönderme (DNS TXT ile, Cloudflare).

## 22 Ekim — app 1.0.0: iOS kimliği co.loungelink.app
- `com.loungelink.app` Apple'da başka geliştiricide kayıtlı çıktı ("not available"). Gökberk iOS için `co.loungelink.app`'i
  kaydetti (Sign in with Apple + Push). `rnapp/app.json` ios.bundleIdentifier değişti; Android `com.loungelink.app` AYNI.
  Koddaki diğer `com.loungelink.app` geçişleri yalnız Android (odeme.js abonelik yönetimi, push.js bildirim ayarı) → dokunulmadı.
- Sürüm adı mağazalar için **1.0.0** (Gökberk sordu; uygulama hiçbir mağazada yayımlanmadı). versionCode 299, buildNumber 293
  (iç sayaçlar artmaya devam). Kodda sürüme bakan tek yer hata kaydı (app_errors.app_version, BO yalnız gösteriyor).
  Telefondaki 6.9.x APK'nın üstüne kurulur (Android yalnız versionCode'a bakar).
- Rehber v20: Supabase Apple Client IDs, 6b, Firebase iOS, RevenueCat iOS → co.loungelink.app; 6b'de iki kimlik uyarısı.
- Bundan sonra: sürüm 1.0.x / 1.x olarak devam.

## 23 Ekim — app 1.0.0 içine "Bulunduğum havalimanı" (Gökberk önizlemeyi onayladı) · BO 1.101.2 · site 0.72.6
- `expo-location ~18.0.10`. Yalnız ön plan izni; arka plan kapalı (plugin) + Android'de ACCESS_BACKGROUND_LOCATION ve
  FOREGROUND_SERVICE_LOCATION blockedPermissions. İzin metni app.json'da (TR).
- `rnapp/src/konum.js`: izin YALNIZ düğmeye basınca; son bilinen konum (10 dk) yoksa düşük doğrulukla anlık konum, 12 sn zaman aşımı;
  en yakın havalimanı TELEFONDA (haversine), eşik 25 km; konum sunucuya gitmez → App Privacy / Data safety'de konum YOK.
- `rnapp/src/havalimani_konum.js`: 222 havalimanının koordinatı (airportsdata; FRU, PNH elle). Katalogda yeni havalimanı
  açılıp burada yoksa düğme onu önermez (form elle çalışır) — yeni havalimanı eklenince bu tabloya da satır.
- `ekranlar_ana.js` SeyahatFormu: `BulundugumHavalimani` (yalnız mod="ekle", havalimanı seçicisinin üstünde); sonuç satırı
  accessibilityLiveRegion. i18n konum* (TR+EN).
- HATA DÜZELTİLDİ: `ucusGeldi` `a.key` arıyordu, katalog `{code}` veriyor → uçuş bulunsa da kalkış/varış hiç seçilmiyordu.
- Yasal metin 2026-10-23: Seyahat verileri maddesine konum cümlesi (üç kopya) + site /en/privacy. BO ve site sürüm artışı.
- Sahne: 40b_konum_bulundu · 40c_konum_red · 40d_konum_uzak (cek.py `konum=lat,lon` / `konum=red`). Önizleme _gorseller/onizleme_konum_1.0.png.
- Denetim: app check temiz · BO check temiz + build · site check 19 sayfa + verify 7/7 + build.

## 23 Ekim akşam — Instagram tanıtım videosu + site 0.72.7
- Reels motoru `rnapp/magaza/reels/` (BENIOKU). Gökberk C'yi seçti → `videoC3.html` (48.2 sn): açılış panosu KAPI B12 · 3 SAAT VAR →
  LOUNGE'DA BULUŞALIM, iki pin (Misafir/Host) lounge'da buluşur + eşleşme kesmesi, KEŞFET/TANIŞ/İSTEK/SOHBET/LOUNGE/PUAN/HOST,
  kapanışta kanat "loungelink" yazar + Yakında + App Store/Google Play + "Ön kayıt listesine katıl · loungelink.co".
  Çıktı `_gorseller/reels/LoungeLink_reels_C3.mp4` (A, B, C, C2 alternatifleri de orada).
- Site 0.72.7: kayıt çağrısı "Ön kayıt ol" (eskisi "Erken erişime katıl"; "erken erişim" uygulamada ödül özelliği), ana sayfa
  başlık etiketi "Ön kayıt", form onay cümlesi "yayın duyurusu ve ön kayıt bilgilendirmesi". check 19 sayfa + verify 7/7 + build.
- Açık: 18 sn kısa kesit (öneri), 4:5 gönderi + kapak, yayından sonra resmi mağaza rozetleri.

## 24 Ekim — rehber revizyonu sırasında bulunan iki ürün hatası (app 1.0.0 içine) · site 0.72.8
- LOUNGE SOHBETİNDE güvenlik şeridi YOKTU: "⚠ Lounge satışı yok · Platform dışı ödeme yok · …" (`safetyBar`) ilk sürümden beri
  yalnız Tanış sohbetindeydi (CompanionChat). `ekranlar_yalin.js` Chat'e aynı şerit eklendi (klavye açıkken gizli). Sahne 06_sohbet'te görüldü.
- KURUCU HOST vaadi gerçek değildi: "İlanların keşifte önce görünür" (app fcModalB1 TR/EN + site ana sayfa). `founding_host_no`
  hiçbir keşif/sıralama fonksiyonunda kullanılmıyor (ETKIN_TANIMLAR'da ölçüldü). App: rozet = "ilk kuranlardan olduğunu gösterir;
  ek hak/öncelik sağlamaz". Site: madde kaldırıldı + "* Rozet bir teşekkürdür…" dipnotu.
- Doğrulandı (hata DEĞİL): "Host başvurusu yap" yalnız myRole === "guest" iken görünüyor.
- Yeni sahneler: 17b_rol_misafir, 17c_rol_host (kayıttaki rol seçimi).
- Denetim: app check temiz · site check 19 sayfa + verify 7/7 + derleme OK; yerel statik üretim RAM yetersizliğinden (0.9/8 GB boş) yarıda —
  Vercel build'i doğrulayacak.

## 24 Ekim — APK 1.0.0 (versionCode 299)
- https://expo.dev/artifacts/eas/b1PZ-d86tL0BNVxJUmIXo-A5s_pj-Z4Fu0_IylTQ1K4.apk
- İçinde: Bulunduğum havalimanı (expo-location), uçuş bulununca havalimanı seçimi düzeltmesi, lounge sohbeti güvenlik şeridi
  (yeni metin: "Burada misafirlik paylaşılır, satılmaz · Ödeme konuşulmaz · Salon ve havayolu kuralları her zaman geçerli"),
  Kurucu Host metni, co.loungelink.app (iOS). google-services.json yok → Android push bu build'de çalışmaz (bilinen).
- Telefonda denenecek: konum izni penceresi ve 3 hâl, sohbet şeridi, Kurucu Host penceresi (misafir hesabında Profil'de).

## 25 Ekim — "lounge girişi" → "ilan başvurusu" · paylaşım şeridi · inceleme görselleri
- Gökberk: "Ayda 7 lounge girişi" giriş hakkı satılıyormuş gibi okunuyor. Her yerde "ilan başvurusu":
  app i18n (planVisitsMonth, planPerVisit, planFreeCredit, walletPackCredits; TR+EN), site PlanKartlari, BO kredi paketleri notu,
  **SQL 341** (plan_catalog.perks/perks_en + kredi_paketleri 'tek' açıklaması; yerelde 4/4). Mağaza rehberi 6d IAP/abonelik açıklamaları.
- Sohbet şeridi: `ortak.js PaylasimSeridi` — kapalıyken tek satır ("LoungeLink bir paylaşım platformudur; lounge hakkı satılmaz" + Ayrıntı),
  dokununca 3 madde; klavye açıkken gizli; lounge sohbeti + Tanış sohbeti. safetyBar anahtarı kalktı. (Önizleme gönderildi; onay bekliyor.)
- App Store inceleme görselleri 1290×2796: _gorseller/appstore_inceleme (kredi · Sık Uçan · Jetset). Mağaza kareleri yeniden üretildi
  (08 alt yazı "Her ay ilan başvurusu…"); eskiler _arsiv/magaza_cikti_1.0_onceki.
- Sahne: odeme=sahte (yalnız web), "ust" adımı, boy= parametresi; 06c, 21r, 29r, 29s.
- Sürümler: site 0.72.9, BO 1.101.3, app 1.0.0 (299) — yeni APK alınmadı.
- Gökberk'ten: SQL 341'i koş; App Store'da açıklamaları yeni metinle gir (rehber 6d).

## 25 Ekim — APK 1.0.0 (versionCode 300, iOS build 294)
- https://expo.dev/artifacts/eas/uVSYucooOgdWYPv9CZYGAdsVd9XFM6TxkV5oq4kqWao.apk
- İçinde: katlanır paylaşım şeridi (onaylandı), "ilan başvurusu" dili, Cüzdan'da Sık Uçan ipucu kaldırıldı,
  plan kartında "Kuruluş fiyatı" rozeti kaldırıldı (açıklama kutusu ve yasal güvence duruyor). Site 0.73.0 rozetsiz.
- App Store inceleme görselleri: kredi + abonelik başına ayrı (sik_ucan/jetset × aylik/yillik), 1290×2796.
- Gökberk'ten: SQL 341.
