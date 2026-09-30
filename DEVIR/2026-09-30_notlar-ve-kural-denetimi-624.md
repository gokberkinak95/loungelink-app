# DEVIR · 30 Eylül 2026 · Gökberk'in 6.2.3 notları (1–8, a) + kural tablosu denetimi · app 6.2.4

Önceki devir: `2026-09-29b_tur3-uygulama-623.md`. Dal `pc-5.17.1`.

## Sürümler
- app `rnapp/app.json`: 6.2.4 · versionCode 275 · buildNumber 269 (package + lock aynı)
- BO 1.96.2 (main) · site 0.69.5 (main) — bu turda değişmedi

## Supabase'de çalıştırılacak SQL (sırayla) — `sql/SQL_SIRA.txt` ile aynı
1. `309_kural_tablosu_denetimi_ve_ilan_erisimi.sql` (tekrar koşulabilir; salonlar ad+havalimanıyla
   bulunur, uuid YOK). Beklenen NOTICE: "yer tutucu kalan=0 · SAW THY CIP seçicide=0 · IST iç hat
   kopya seçicide=0 · eklenen kabul=4".

## Ne değişti (app)
- md.1 · Uyum yüzdesi (KuralKarari) kartla AYNI durum makinesini kullanıyor (`kuralIstekDurumu`):
  istek gönderildi / kabul / reddedildi / süresi doldu / kendi ilanın / doldu → düğme yerine durum
  satırı. "Kapıdan geçemezsin" yalnız KAPI ağırlıklı şart düşünce (not ağırlıklı satır engel değil).
- md.2 · Kural ekranı başlığı Keşfet/Planım ile aynı fotoğraf bandında (kaş "KURAL MOTORU · IST",
  serif "neden %X?", altında salon adı).
- md.3 · Seyahat kartı: sağ üstteki çıplak kod kalktı; havayolu rotanın altında ADIYLA (çip),
  uçuş numarası hücrelerde "UÇUŞ" etiketiyle. İlanlarım kartında havalimanı kodu tarih satırına.
  Rakamsız uçuş "numarası" ("TK" öneki) artık kaydedilmiyor (`ucusNo`, 6 kayıt yeri) + 309 temizler.
- md.4 · Seyahatlerim ilk açılışta siyah bant: bant sekme/`reload` değişince sıfırlanıyor.
- md.5 · Çıkış yap cam kutuda (kiremit ton korunur). "AYARLAR" satırı "Ayarlar".
- md.6 · Ana sayfa panelleri (Bağlantılarım · İstekler · Bağlantı istekleri) çerçeveli cam kutu,
  satırlar 1 px çizgi; sakin gündeki "Salon rehberi / Yol arkadaşları" çerçeveli düğme.
- md.7 · İlan ekle 1. adım: "Bu salon için kuralın" + "Hangi kartını kullanmalısın" KALDIRILDI.
  Yerine "ERİŞİM HAKKIN": ayarlardaki kartlardan bu salonda misafir getirebilenler çip olarak;
  varsayılan = önerilen kart; hiç yoksa "Erişim kaynağı ekle" (HostAccessSource modalı sihirbazın
  üstünde açılır, form kaybolmaz). Bilgi notu: "Bu bilgi sayesinde ilanına başvuracak kişileri en
  doğru şekilde sana yönlendirebileceğiz." Seçim `set_availability_program` ile ilana yazılır —
  ÖLÇÜLDÜ: ilanın programı değişince misafire verilen karar değişiyor. Yayın onayı yalnız KESİN
  engelde soruluyor (uyarılar misafirin ekranında). 3. adımdaki kural rozeti kalktı.
- md.8 · Keşfet ilk kartın açık zemini kalktı (hepsi aynı cam).
- md.a · Seyahat/ilan ekleme sonrası Planım kendiliğinden yenileniyor (`reload`).

## Kural tablosu denetimi (kaynak: kural tabloları.xlsx 108 görsel + lounge(2).zip 141 görsel)
Uyanlar: THY yurtiçi salon listesi · THY/AJet misafir kuralları (seviye, aile, aynı taşıyıcı) ·
Pegasus fiyatları (Primeclass 27 EUR, Plaza SAW 49/63 EUR) · PP ziyaret/konuk 30 EUR · DragonPass
konuk 36 EUR + "aynı uçuş" (T&C 7.15.7) · LoungeKey ve PP'nin TR salon listeleri.
Düzeltilenler (309): THY'nin kendi salonlarında M&S yer tutucusu (AYT dış hat FTA CIP, BJV iç hat) →
kabul; THY olmayan TR salonlarında M&S yer tutucusu → geçmez (misafir "doğrulayamadık" görmez);
IST iç hat (Business) kopya kaydı kapandı (THY'de iç hat TEK salon); SAW THY CIP 3 Nisan'dan beri
geçici kapalı → seçiciden çekildi (venue aktif, eski ilanlar çözülür); Kepler PP (pasifti) + Pegasus;
COV Çelebi iç hat Pegasus 1260 TL; AYT CIP iç (T3) DragonPass (28 Eylül'de "belirsiz" diye
kapatılmıştı — PP ve DP kartlarındaki fotoğraf aynı → çözüldü).
Doğrulanan davranış: THY host + AJet misafir → Keşfet kartı "başvuramazsın" (rozet
`carrier_ok=false` → blocks_request), kural ekranında düğme yok. Ücretli girişte "Misafir girişi
ücretli" uyarısı + başvuru açık.

## Koşulan testler
- check temiz · render 77/13/12/53/37 · e2e: flow_matrix 27/27 · tam_akis 171/171 · edge 18/18 ·
  onboarding 16/16 · two_account geçti · rule_dims / rpc_field: aşağıda SON DURUM
- Sahne yakalama (03_kural, 11, 14, 12b, 09, 02, 65): hata=0 db/logError=0

## Açık kalanlar / öneri
- SUNUCU SERTLEŞTİRMESİ (öneri, yapılmadı): taşıyıcı uyuşmazlığı sunucuda yalnız `enforcement=block`
  satırlarda duruyor; TK_MS/AJET_MS satırlarının çoğu `warn`. Uygulama kapıyı zaten tutuyor (rozet);
  doğrudan API çağrısı geçebilir. Sertleştirmek için enforcement + request_precheck_pregate BİRLİKTE
  değişmeli (yalnız biri değişirse ön kontrol ↔ sunucu farkı geri gelir — tam_akis bunu ölçer).
- SAW THY CIP yeniden açılınca: `update lounges set active = true where venue_id = (SAW THY CIP)`.
