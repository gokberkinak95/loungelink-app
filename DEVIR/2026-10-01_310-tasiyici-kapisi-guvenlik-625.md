# DEVIR · 1 Ekim 2026 · 309 düzeltmeleri + taşıyıcı kapısı sunucuda + güvenlik taraması · app 6.2.5

Önceki: `2026-09-30_notlar-ve-kural-denetimi-624.md`. Dal `pc-5.17.1`.

## Sürüm
- app 6.2.5 · versionCode 276 · buildNumber 270 (package + lock aynı). BO/site değişmedi.

## Supabase SQL (sırayla) — `sql/SQL_SIRA.txt` ile aynı
1. `310_309_duzeltme_tasiyici_kapisi_guvenlik.sql` (309'dan SONRA; tekrar koşulabilir).
   Beklenen NOTICE: "iç yardımcı istemciye açık=0 · SAW THY CIP seçicide=1 · geçmez satırı=0".
   Üretici: canlı tanımlardan en küçük farkla (create_request_impl_preflag, request_precheck_pregate).

## Gökberk'in kararları (1 Ekim)
- SAW THY CIP (iç hat) salon seçicide AÇIK kalsın (AJet tablosu 3 Nisan'dan beri geçici kapalı diyor;
  "açılmış olabilir, her türlü açılacak"). 310 geri açtı.
- Doğrulayamadığımız yerde ENGELLEME YOK; "kural doğrulanmadı · kapıda teyit et" mesajıyla başvuru
  açık (özellikle kredi kartı hakları). 309'un THY dışı TR salonlarında M&S için yazdığı "geçmez"
  doğrulanmış bilgi değildi → 310 önceki hâline döndürdü.
  Not: Miles&Smiles = THY + AJet'in statü programı (TK_MS: THY & AJet statüsü · AJET_MS: AJet
  seferleri). Kuralları yalnız THY/AJet salonlarında ve THY'nin anlaşmalı salonlarında tanımlı.
  Araştırma: THY'nin TR dış hat uçuşlarında statü sahiplerini hangi anlaşmalı salona aldığı resmî
  tabloda yok (ADB dış hatta tek salon Primeclass; ESB'de "Class Plus" anlaşmalı salon bahsi var) →
  bu salonlarda durum "doğrulanmadı" kalmalı.

## Taşıyıcı kapısı (sunucu)
Keşfet rozeti taşıyıcı uyuşmazlığını (THY host + AJet misafir vb.) zaten engelliyordu; sunucu yalnız
`enforcement=block` satırlarda duruyordu → doğrudan API çağrısı geçebiliyordu. 310: create_request VE
ön kontrol BİRLİKTE "carrier_ok=false → engel" (rozetle aynı istisna: program bilinmiyor ya da banka
kartı ise engel yok). tam_akis 171/171: ön kontrol ↔ sunucu tutarlı.

## Güvenlik taraması (ölçülen)
- RLS kapalı tablo: 0 · `true` yazma politikası: 0 · okuma `true` yalnız referans tablolarında
- `user_balances` görünümü security_invoker ✓ · `users`/`push_tokens`/`verifications` yalnız kendi satırı ✓
- bo_/admin_ fonksiyonları kullanıcıya kapalı ✓ · BO /api/flight (admin ya da geçerli JWT + kota) ✓,
  /api/tani (admin) ✓ · app paketinde gizli anahtar yok ✓ · beta_settings'te sır yok ✓
- Kullanıcı kimliği alan 17 istemci RPC'si `kimlik()`/`partner_gate()` ile korumalı (297) ✓
- AÇIK → KAPANDI (310): istemcinin HİÇ çağırmadığı 21 iç yardımcı fonksiyon oturum açmış her
  kullanıcıya açıktı ve korumasızdı (başkasının kimliğiyle çağrılıp veri okunabiliyordu:
  verification_state, best_access_for_user, card_self_check, etkin_plan, lounge_access_decision_v6
  (başkasının seyahat kimliği)…). EXECUTE yalnız service_role'e. Ölçüldü: bunları çağıran her şey
  SECURITY DEFINER; politika/görünüm/invoker çağıran YOK.
- AÇIK → KAPANDI (310 + app 6.2.5): profil fotoğrafı `<uid>/avatar.jpg` tahmin edilebilirdi ve
  `avatars` kovasında herkes her klasörü listeleyebiliyordu → "fotoğrafım yalnız bağlantılarıma"
  gizliliği URL tahminiyle aşılabiliyordu. App artık rastgele dosya adı kullanıyor, eskileri siliyor;
  listeleme yalnız sahibine. ⚠ Mevcut fotoğraflar kullanıcı yeniden yükleyene kadar eski adda durur
  (tahmin edilebilir); istenirse BO'dan toplu yeniden adlandırma işi yazılabilir.
- Bilinçli açık bırakılan: `expire_stale_sessions` her kullanıcıya açık — app bunu cron'a yedek olarak
  çağırıyor ve idempotent (yalnız zaten süresi dolmuş olanları kapatır).

## Resmî kaynak doğrulaması (Gökberk'in linkleri, 1 Ekim)
- THY anlaşmalı salon listesi: Türkiye bölümü YOK (yalnız KKTC). AMA THY kurallar sayfası: "Türkiye'deki
  Ortaklık markalı olmayan ve anlaşma yapılarak hizmet alınan dış hat salonlarında da yolcu kabulü aynı
  şekilde gerçekleştirilmektedir" + M&S EC için "Dalaman ve Diyarbakır'daki Turkish Airlines Lounge
  olmayan CIP salonları". Yani THY TR'de markasız salonlarla da anlaşmalı ama HANGİLERİ yazmıyor →
  THY dışı TR salonlarında M&S "doğrulanmadı · kapıda teyit" DOĞRU durum (310). 309'un "geçmez"i yanlıştı.
- THY kurallar sayfası tablolarımızla birebir: Tablo 1–5 (seviye × kabin × misafir/aile), IST dış hat
  Business/M&S bölümü, First +1, Corporate Club notları, 2026 ücret tarifesi (3000/2800/2000 TL),
  erken giriş (2 saat; IST iç hat 4/6 saat), charter, çocuk kuralları, md.17 (THY ↔ AJet misafir yok).
- Pegasus sayfası birebir (309 ekleriyle): Plaza SAW 49/63 EUR, Kepler indirimli, Primeclass
  BJV/ADB/ESB 27 EUR+KDV (iç+dış), Çelebi COV iç 1260 TL / dış 49,5 EUR.
- AJet sayfası tarayıcıda açılmadı (bot koruması); içerik Excel'den doğrulanmıştı.

## Testler
- app check temiz · render 77/13/12/53/37
- e2e (taze kurulum, 309+310): tam_akis 171/171 · flow_matrix 27/27 · rule_dims 55/55 · edge 18/18 ·
  onboarding 16/16 · rpc_field geçti (hayalet alan yok) · two_account geçti
- 310 yerelde iki kez: NOTICE beklenen değerlerle aynı
