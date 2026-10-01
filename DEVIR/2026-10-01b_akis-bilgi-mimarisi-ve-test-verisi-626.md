# DEVIR · 1 Ekim 2026 (2. tur) · sayılar tek kaynak · akış bilgi mimarisi · soru→ilan bağı · app 6.2.6

Önceki: `2026-10-01_310-tasiyici-kapisi-guvenlik-625.md`. Dal `pc-5.17.1`.

## Sürüm
- app 6.2.6 · versionCode 277 · buildNumber 271 (package + lock aynı). BO/site değişmedi.
- Build ALINMADI (Gökberk onayı bekleniyor; tasarım değişikliği → önce önizleme).

## Supabase SQL (sırayla) — `sql/SQL_SIRA.txt` ile aynı
1. `311_kesfet_ozeti_tek_kaynak.sql` — ana sayfa havalimanı çipleri Keşfet'in kendi listesinden
   (`kesfet_ozeti`); ana sayfa SOHBET kutusu = bağlantı sohbetleri + kabul edilmiş buluşmalar.
2. `312_soru_ilan_bagi_gercekten.sql` — HATA: 239'un "zaten yamalı" koruması `like '%p_avail_id)%'`
   gövdedeki `kural_sorusu_uygun_mu(p_avail_id)`a uyuyordu → yama hiç uygulanmadı → 239'dan beri
   hiçbir soru ilanına bağlanmadı (metin/bildirim “bu” ilanına, "İlana git" boş). 312 tam INSERT
   satırına bakar, sonra canlı gövdeyi yeniden okuyup bağ yoksa HATA verir. Eski sorular yalnız
   emin olunan yerde (o an hostun tek ilanı) bağlanır ve “bu” metni salon adıyla düzeltilir.
3. `SEED8_AKIS_TEZGAHI.sql` → 4. `SEED9_AKIS_GENIS.sql` (ikisi birlikte, bu sırayla; yalnız test hesapları).

## Gökberk'in 1 Ekim maddeleri → yapılanlar
- (a) "IST 11 host / Keşfet 3 ilan": ÖLÇÜLDÜ — çipler `havalimani_nabzi` (BO panosu, Keşfet'in
  görünürlük kurallarını uygulamıyor) okuyordu. Artık `kesfet_ozeti` (discover_availabilities'in
  çağıran gözüyle çıktısı; kendi/dolu/bitmiş ilan hariç). Keşfet başlığı AYNI tanımla
  "{i} ilan · {h} host yayında" (eskiden ilanı host diye sayıyordu). Çipe dokununca Keşfet o
  havalimanına süzülü açılır.
- (b) Siyah başlık bandı: genel çözüm — `Kaydirma` (ui.js) montajda bandı sıfırlar; her ekran
  yeniden açıldığında bant kaydırma 0'dan başlar. Sekme/yenileme geçişinde de sıfırlanıyor (App.js).
- (c) İstek ekranı: sekmeler GELEN · GÖNDERDİĞİM (sayılı), sekmeye göre boş durum + pano metni.
  İstek = yalnız karar bekleyenler.
- (d) Oturumlar: "Sohbet" kutusu → "Oturumlar ve sohbetler" ekranı, sekmeler OTURUMLAR ·
  BAĞLANTILAR. Kabul edilen istek İstek'ten Oturumlar'a taşınır; kart oturumun hâlini taşır
  (başlamadı / sen başlattın / karşı taraf başlattı / sürüyor / onayın bekleniyor / karşı tarafın
  onayı / tamamlandı). 5. kutu AÇILMADI (320pt'de etiket kırpılıyor — 30 Ağustos ölçümü).
- (e) Test verisi SEED9 (SEED8'in üstüne): Selen Ö. (akis.host3) eklendi; taşıyıcı engeli (THY ilan,
  VF uçan misafir), ücretli giriş (ADB Primeclass), kural bilinmiyor → hosta sor (bekleyen + yanıtlanmış
  + sohbete dönmüş), gelen soru, doğrudan davet, bekleyen/kabul/ret edilebilir istekler, karşı
  tarafın başlattığı oturum, karşı tarafın tamamladığı oturum, gelen/giden bağlantı istekleri.
  Sayım (yerel): host İstek 4=4 · Sohbet 6=6 · Davet 3=3 (1 davet + 2 bağlantı) · Soru 0;
  misafir İstek 1=1 · Sohbet 5=5 · Davet 2=2 (1+1) · Soru 1=1.
- (f) İptal: VAR — sohbette "Oturumu iptal et" (cancel_session / respond_request cancel),
  İlanlarım'da "yayından kaldır" (cancel_availability). Veride: kabul edilmiş, başlamamış oturumlar.
- Ek (vizyon): Soru ekranı tam ekranda açık başlar, "2 · 1 yanıt bekliyor" yazar (ana sayfa yalnız
  cevapsızı sayar, çelişki görünmesin); Davet/Soru üst etiketi "AKIŞ" (4 kutu aynı şerit);
  Soru ekranındaki fazladan marka şeridi kaldırıldı; 312 hatası bulundu ve düzeltildi.

## Testler
- check.js temiz · render 77/13/12 · 53 ekran 0 hata (mount_test'in Main penceresi 60000 karakterdi,
  Main büyüyünce `return (` dışarıda kaldı → yanlış kırmızı; pencere artık sonraki fonksiyona kadar)
- e2e: tam_akis 171/171 · flow_matrix 27/27 · rule_dims 55/55 · edge 19/19 (312 ile) · onboarding 16/16 ·
  rpc_field geçti (hayalet alan yok, 26 sözleşme alanı) · two_account 14/14. edge'e 16. denetim eklendi (ilan_kurali_sor avail_id yazıyor mu —
  hiçbir e2e bu fonksiyonu çağırmadığı için hata aylarca görünmedi).
- Web sahneleri 70–78 (Nehir/Arda) + 02, 11: konsol hatası 0, db/logError 0.
- 312 yerelde iki kez (ikincisi "dokunulmadi"); SEED8+SEED9 312'den sonra: 3 sorunun 3'ü salon adıyla.

## Açık kalanlar / Gökberk'ten beklenen
- Önizleme onayı (sahneler 71–78) → sonra 6.2.6 build.
- 311, 312, SEED8, SEED9'u Supabase'de sırayla koş.
