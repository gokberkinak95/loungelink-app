#!/usr/bin/env node
// ============================================================
// LoungeLink · verify.js — denetim zinciri, DÜRÜST RAPORLU
//
// 🔴 NEDEN VAR (20 Ağustos 2026, Gokberk'in sorusu):
//     "e bu app kurulumunu bugüne kadar Python'suz yapıyordum,
//      neden şimdi kurmam lazım?"
//
// Haklı bir soru ve cevabı ÖLÇÜLDÜ. Python'u Windows'taki Store
// kısayoluyla taklit edip dört şeyi ayrı ayrı çalıştırdım:
//
//   npx expo export  (GERÇEK BUILD) → çıkış 0   ✅ Python GEREKMİYOR
//   npm run render                  → çıkış 0   ✅ Python GEREKMİYOR
//   node check.js                   → çıkış 0   ✅ Python GEREKMİYOR
//   npm run verify                  → çıkış 1   ❌ 11 denetim çalışmıyor
//
// Yani Python build için HİÇ gerekmedi — bu yüzden fark edilmedi.
// Gereken şey DENETİMLERDİ ve onlar bugüne kadar hiç çalışmadı.
//
// 🔴 ESKİ ZİNCİRİN AYRI BİR KUSURU: `python a && node b && python c`
// biçiminde yazılmıştı ve İLK adım Python'du. Python yoksa zincir
// daha ilk komutta ölüyor, dolayısıyla ÇALIŞABİLECEK olan `check.js`
// bile hiç koşmuyordu. Koşabilecek denetimi, koşamayan bir denetimin
// arkasına koymak, ikisini birden kaybetmek demek.
//
// Bu dosya sırayı tersine çevirir:
//   1) Node denetimleri ÖNCE (her ortamda çalışır)
//   2) Sonra Python denetimleri
//   3) Python yoksa: NE ATLANDIĞINI ve NEYİ KORUDUĞUNU tek tek yazar
//      ve çıkış 1 döner — sessizce yeşil YANMAZ.
// ============================================================
const { spawnSync } = require("child_process");
const path = require("path");

const NODE_ADIMLARI = [
  ["node", ["check.js"], "JS sözdizimi · i18n anahtarları · tema · sessiz hata yutma · sabit kap yolu"],
  // 🔴 19 Eylül — KENDİ YAZDIĞIM ÇÖKMENİN NÖBETÇİSİ. `Main`e eklediğim bir
  // `useEffect`in bağımlılık listesine, 100 satır aşağıda tanımlı bir
  // `const` yazdım; cihazda "Cannot access 'reload' before initialization"
  // ve oturum sonrası HER ekran beyaz kaldı (53 sahnenin 30'u).
  // ⚠️ NODE LİSTESİNDE, PYTHON'DA DEĞİL. İlk kaydımda Python bölümüne
  // yazdım ve `SyntaxError: invalid character '—'` aldım: Python bir JS
  // dosyasını ayrıştırmaya çalışıyordu. Kapı koşmuyordu ama kırmızı
  // yanıyordu — yani hem ölçüm yok hem gürültü var.
  ["node", ["render_check/olu_bolge_check.js"], "kanca bağımlılığında ölü bölge (cihazda beyaz ekran)"],
];

// Her Python denetiminin NEYİ KORUDUĞU — atlanırken bunu göstereceğiz.
// Bir denetimi atlamanın bedeli, adı değil, KORUDUĞU ŞEYdir.
const PY_ADIMLARI = [
  ["snapshot_gen.py",  "ETKIN_TANIMLAR.sql'i tazeler — bayat döküm denetimlerin 1/3'ünü kör eder"],
  // 🔴 27 Ağustos: `eas build` "expo config --json exited with non-zero
  // code: 1" diye düştü. Sebep `expo-build-properties`in kilit dosyasında
  // olmaması; `npm ci` onu kurmuyordu. Hiçbir denetim app.json'daki
  // eklentilerle package-lock'u karşılaştırmıyordu.
  ["eklenti_check.py", "app.json eklentileri kurulu mu (eas build'in ilk adımı)"],
  ["palette_check.py", "Palet dışı renk (app ile marka ayrışması)"],
  // 🔴 26 Ağustos — palette_check rengin PALETTEN geldiğini denetliyor;
  // paletten gelip de OKUNMAYAN bir rengi göremiyor. Rozet metinlerinin
  // dördü de AA'nın altındaydı ve bu denetim hiçbir şey demiyordu.
  ["tema_check.py", "Rozet kontrastı · köşe ölçeği · kalınlık borcu"],
  // v3.1 — atmosfer dokusu sayfa zeminini değiştirdi. Kart yüzeylerini
  // tema_check ölçüyor; kart DIŞINDA duran metin bu nöbetçinin işi.
  ["doku_check.py", "Atmosfer dokusunun sayfa metinlerine kontrast bedeli"],
  // v3.1 — tema_check YALNIZ theme.js'te BİLDİRİLEN 19 yüzeyi ölçüyordu.
  // Ekranların satır içinde kurduğu yüzeyler hiçbir denetimde yoktu ve
  // 50 dokunulabilir + 317 metin çağrı yeri AA'nın altındaydı.
  ["yuzey_kontrast_check.py", "Satır içi renk çiftlerinin okunurluğu"],
  // v3.1 — 327 dokunulabilirin 23'ünde ne hitSlop ne minHeight vardı.
  ["dokunma_check.py", "Dokunma hedefi koruması (WCAG 2.5.5)"],
  ["erisim_check.py", "Ekran okuyucuda adı olmayan dokunulabilir alan (WCAG 4.1.2)"],
  // v3.2 — KOYU TEMA. Anahtarı kurmadan önce ölçtüm: `C`de 55 renk,
  // `KOYU`da 19. Kodda kullanılıp koyu karşılığı olmayan 39 token =
  // 1270 çağrı yeri. Anahtar o gün konsaydı, koyu sayfada açık tema
  // renkleriyle çizilen 1270 nokta olurdu. Boşluk kapatıldı; bu nöbetçi
  // TEKRAR AÇILMASINI engelliyor.
  ["koyu_check.py", "Koyu tema bütünlüğü — token kapsamı · gece yüzeyleri · yeniden kurulan yapılar"],
  // v3.2 — v3.1'de birincil/tehlike düğmesi ayrımını ölçtüm (ΔE 8.0 →
  // 28.3) ama ÖLÇÜMÜ BETİĞE YAZMADIM. Koyu tema düğmelerini türetirken
  // aynı soruyu yeniden sormam gerekti ve elimde çalıştırılacak bir şey
  // yoktu. Bir analizi betiğe çevirmediysen onu yapmadın, bir kez baktın.
  ["renk_korluk_check.py", "Renk körü bir gözde birincil ↔ tehlike ayrımı (iki temada)"],
  // v3.1 — 293/460 borderRadius ölçek dışıydı. Düzeltmek yetmez; tavan
  // olmadan borç yeniden birikir.
  ["kose_olcek.py --denetle", "Köşe yarıçapı R ölçeğinde mi"],
  // 30 Ağu — theme.js'in yorumu "ölçek dışı anahtarı DENETİM YAKALAR"
  // diyordu; öyle bir denetim yoktu. Ölçtüm: 13 çağrı yeri `undefined`
  // dönüyordu, dokuzu benim iki tur önce yazdığım boşluklardı. Bir
  // yorumda "yakalanır" yazmak, yakalayan şeyi yazmak değildir.
  ["olcek_anahtar_check.py", "ARA/SP/R/FS/T/MONO erişimi gerçekten tanımlı mı"],
  // 30 Ağu · 3. tur — Gökberk sordu: "uçtan uca tamam mıyız?" O soruya
  // ölçmeden cevap veremem. Beş kural (serif rolü · metin sembolü ·
  // emoji · ham köşe · ham renk) sayılıyor ve tavan yalnız DÜŞEBİLİR.
  ["tasarim_uyum_check.py", "Gece sistemi uçtan uca — tasarım borcu arttı mı"],
  // 30 Ağu · 4. tur — Gökberk üç YERLEŞİM hatası gösterdi (etiket
  // taşması · çiplerin yeri · düğmelerin yeri). Üçünde de MALZEME
  // doğruydu: doğru renk, doğru font, yanlış yer. Malzeme denetimi
  // onlara yeşil yanıyordu. Bu denetim tasarımın CSS'indeki yerleşim
  // iddialarını çıkarıp uygulamada kanıtını arıyor.
  ["tasarim_yapi_check.py", "Tasarımın YERLEŞİM iddialarının uygulamada kanıtı var mı"],
  // 30 Ağu · 5. tur — Gökberk beşinci kez "birebir" dedi ve yapı denetimi
  // 23/23 yeşilken tasarımı tarayıcıda çizip yan yana koyunca kartların
  // daha seyrek olduğunu gördüm. Yapı doğru, ÖLÇÜLER değildi: ana düğme
  // 52pt'ti, tasarım 48 diyor — kartın en uzun öğesi olduğu için o 4pt
  // her kartta çoğalıyordu. Bu denetim css.py'deki sayıları CANLI okuyup
  // uygulamada arıyor.
  ["tasarim_olcu_check.py", "Tasarımın SAYILARI uygulamanın sayılarıyla aynı mı"],
  // 30 Ağu · 6. tur — AYNANIN KENDİSİ ÜÇÜNCÜ KEZ YANLIŞ ÖLÇTÜ. Bu sefer
  // birim: `metin()` harf aralığını K ile çarpıyordu, `genislik()`
  // çarpmıyordu — çizim ölçümden 3 KAT geniş. Denetimlerim ürünü
  // ölçüyordu; ölçüm aletini kimse ölçmüyordu.
  ["mockup_kalibre.py", "Önizleme: çizim ile ölçüm aynı sayıyı mı veriyor"],
  // 30 Ağu · 7. tur — Profil önizlemesi ekranın 11 menü satırını ve
  // fotoğrafını HİÇ çizmiyordu; Gökberk duran özelliklerin silindiğini
  // sandı. Eksik bir ayna, kusur gizlemekten daha pahalı bir şey yapar:
  // ürünün sahibine duran bir özelliği kaybettirir.
  ["ayna_kapsam_check.py", "Önizleme ekranın ne kadarını gösteriyor (taban yalnız YÜKSELİR)"],
  // v3.1 — "◆" ve "ⓘ" tofu kutusu çıkınca doğdu: paketlenen fontta olmayan
  // her metin sembolü Android'de boş kare riski taşıyor.
  ["glif_check.py", "Paketlenen fontlarda olmayan metin sembolleri"],
  // v3.1 — `pencere.jpg` tasarım klasöründen assets/'e taşındı: artık
  // APK ile DAĞITILIYOR. Lisans açık olduğu sürece bu denetim kırmızı
  // kalacak ve bu bilinçli — mağaza incelemesinde telif gerçek bir ret sebebi.
  ["telif_check.py", "Dağıtılan görsellerin lisansı defterde net mi"],
  // v3.1 — `build_brand.py` "tek kaynak" diyordu ama çalıştırınca uygulamanın
  // İKONUNU DEĞİŞTİRİYORDU. Artık üreticinin çıktısı her koşuda sevkiyatla
  // karşılaştırılıyor; ayrıca ikonun mağaza kuralları (opak · 1024) ölçülüyor.
  ["marka_check.py", "Marka üreticisi sevkiyatla aynı mı · ikon mağaza kuralları"],
  ["tema_kaynak_check.py", "theme.js'i kendi başına ayrıştıran araç var mı"],
  // 🔴 12 EYLÜL · KAPSAM TURU — "her yere uyguladım" iddiasının nöbetçisi.
  ["ekran_kapsam_check.py", "her ekran mount'ta ve ana akış sahnede mi"],
  ["cihaz_parite_check.py", "iOS↔Android gölge ve alt piksel eşitliği"],
  ["taklit_yuzey_check.py", "render taklitleri gerçek RN yüzeyini kapsıyor mu"],
  ["buyuk_harf_check.py", "Türkçe büyük harf — noktasız I üreten stil yok"],
  ["hata_mesaji_check.py", "sunucunun fırlattığı her hatanın kendi cümlesi var mı"],
  ["durum_kapsam_check.py", "ekranın her HÂLİ en az bir sahnede görüldü mü"],
  ["satir_check.py", "klamplı başlıklarda inici harf (ğ ç ş) alttan kesiliyor mu"],
  ["kutu_tasma_check.py", "kutu ekrandan taşıyor mu · ikon metne yapışık mı (sahne ölçümü)"],
  ["gren_check.py", "gradyanda göz kenar görecek genişlikte düz şerit var mı"],
  ["kural_metni_check.py", "kural notlarında ASCII'ye düşmüş Türkçe var mı (çırçır)"],
  // 13 Eylül · SQL 292 — duvar saati (time without time zone) UTC ile
  // kıyaslanıyor mu. Ölçülen kayma Europe/Istanbul'da TAM 3 saat; kural
  // motoru "UYGUN" derken gerçek "KURAL İHLALİ"ydi. Tavan 0 (ratchet değil).
  ["zaman_dilimi_check.py", "duvar saatini UTC sanan kıyas var mı (3 saatlik hata)"],
  // 13 Eylül · v5.9.0 — IATA BCBP ayrıştırıcısı. 37 dize + 8 davranış
  // sınaması; brief'in "ilk 3 karakter" hatası geri gelirse 33 yerde
  // kırmızı yanar (mutasyonla kanıtlandı).
  ["bcbp_check.py", "biniş kartı ayrıştırıcısı doğru ofsetten okuyor mu (IATA Res. 792)"],
  // 13 Eylül · v5.9.0 — çevrimdışı mesaj kuyruğu. İki değişmez: MÜKERRER
  // TESLİM YOK · SESSİZ KAYIP YOK. Üç mutasyonla kanıtlandı.
  ["kuyruk_check.py", "çevrimdışı kuyruk mükerrer mesaj bırakıyor mu · sessizce kaybediyor mu"],
  ["kaplama_check.py", "kabını kaplayacak katman karşıt kenarla mı sabitlenmiş (cihazda kenarda çıplak zemin)"],
  // 🔴 18 Eylül — ÜÇ TUR SÜREN "HİÇBİR BUTON ÇALIŞMIYOR" HATASININ KAPISI.
  // `pointerEvents="none"` Android'de YALNIZ View/ScrollView ailesinde
  // okunuyor (TouchTargetHelper.java:309-311 · ReactImageView.kt'de 0
  // geçiş); `Image`de sessizce yok sayılıyor ve katman bütün dokunmayı
  // yutuyor. Web'de CSS'e çevrildiği için localhost'ta hata GÖRÜNMÜYORDU.
  // Mutasyonla kanıtlandı: tek katmanı geri alınca kırmızı.
  ["gecirgen_check.py", "`pointerEvents` gerçekten geçirgen mi (Android'de yalnız View okur)"],
  // 🔴 19 EYLÜL — "DÜĞME ÇALIŞMIYOR"UN KÖKÜ BİR EKSİK BAĞIMLILIKTI.
  // `App.js`in katman AÇILIŞ SIRASI defteri (`openSeq`) yedi katmanın
  // durumunu dinlemiyordu. Sonuç: "Tanış → Sohbetlerim → Sohbeti Aç"
  // sohbeti gerçekten açıyor ama YIĞININ ALTINA koyuyordu; ekran
  // değişmediği için kullanıcı düğmeyi bozuk sanıyordu. Kapıyı yazar
  // yazmaz benim göremediğim iki katmanı daha (`editAvail`, `editTrip`)
  // gösterdi.
  ["katman_sira_check.py", "Katman açılış sırası defteri her katmanı dinliyor mu"],
  // 🔴 20 EYLÜL — YUKARIDAKİ İKİ KAPI DA DOLAYLI: "şu desen yanlış" derler,
  // "şu düğme çalışıyor" demezler. `web_sahne/dokunma_yolu_test.py` gerçek
  // Chromium'da oturumsuz akışın HER düğmesine basıp ekranın değiştiğini
  // kanıtlıyor — ama tarayıcı ister, yani bu zincirde koşamaz. Bu kapı onun
  // MAKBUZUNU denetliyor: test güncel kaynağa karşı koştu mu, düşen var mı.
  // Mutasyonla kanıtlandı: tam ekran <View> koyunca test kırmızı; aynı şeyi
  // <Image> ile yapınca test YEŞİL kaldı (RNW `Image`i pointer-events:none
  // basar) — o delik `gecirgen_check.py`nin 2. ölçüsüne eklendi.
  ["dokunma_makbuz_check.py", "Oturumsuz akışın düğmelerine GERÇEKTEN basıldı mı (makbuz güncel mi)"],
  // 🔴 20 EYLÜL — BİRİNCİL DÜĞMENİN METNİ 1.65:1 İMİŞ.
  // `BTN.gold` koyu temada `#D9C8A6` zemine BEYAZ yazıyordu. Doğru jeton
  // (`C.onGold` = #17120B, 11.32:1) zaten vardı; çağrı yeri atlamıştı.
  // `yuzey_kontrast_check.py` bunu göremezdi: o SATIR İÇİ stil nesnelerini
  // tarıyor, burası bir ARAMA TABLOSU.
  ["dugme_kontrast_check.py", "Düğme arama tablosundaki { bg, fg } çiftleri AA'yı geçiyor mu"],
  // 🔴 20 EYLÜL — FOTOĞRAFLAR PALETİN DIŞINDAYDI.
  // `theme.js` her rengi ölçüp gerekçelendiriyor ama GÖRSELLER o
  // denetimin dışındaydı. `bant.jpg` (splash + iç ekran başlıkları +
  // MomentScreen, ÜÇÜ AYNI DOSYA) C* p95 36.6 · hue 41° idi; marka
  // 20.1 · 86°. Yani sapma kullanıcının gördüğü İLK karede başlıyordu.
  // Kapı alfa maskesi kullanır — maskesiz ölçüm saydam pikselleri sayıp
  // doğru bir varlığı "bozuk" gösterebiliyor (bir kez öyle oldu).
  ["gorsel_palet_check.py", "Görsellerin alfa maskeli kroma/hue değeri markanın içinde mi"],
  // 🔴 20 EYLÜL — 12 SIZINTI. En büyüğü `atmosfer.js`in gün batımı
  // rampasıydı: 10 durak, kroma 48'e kadar, hue 340°-71°. Şampanya
  // kararı (C* 40.2 → 20.4) JETONLARA uygulanmış ama bu ÇİZİME
  // uygulanmamıştı — yani uygulamanın en büyük renkli yüzeyi paletin
  // dışındaydı. Hepsi jetonlaştırıldı, tavan 0.
  ["tema_sizinti_check.py", "theme.js dışında paletin dışından gelen sabit renk"],
  // 🔴 20 EYLÜL — SIZINTI KAPISI YEŞİLKEN EKRANIN EN BÜYÜK BLOĞU
  // TERK EDİLMİŞ DÜNYADANDI. Sahneleri ölçtüm: `06b_sohbet_tanis`te
  // 155.992 piksel hue 310° (LAVANTA), `20_ayarlar`da 12.557 piksel
  // hue 262° (LACİVERT). Sızıntı yoktu — iki renk de `theme.js`te
  // düzgünce jetonlaşmıştı (`KOYU.purple`, `KOYU.gokMavi`). Yani kapı
  // "renk jetondan mı geliyor" diye soruyordu, "jetonun KENDİSİ palette
  // mi" diye hiç sormuyordu. Bu kapı ikincisini soruyor.
  ["jeton_bant_check.py", "theme.js'teki rengin KENDİSİ sıcak bantta / nötr / gerekçeli sinyal mi"],
  // 🔴 20 EYLÜL — BENİ YANILTAN SINIF.
  // `theme.js` `KOYU.gold`u ÜÇ KEZ atıyor (806 · 1371 · 1444). Ben nesne
  // literalini okuyup #D6C3A0 gördüm ve bütün bir analizi onun üstüne
  // kurdum; app zaten #C9B693 taşıyordu. Dahası siteyi "geride" sanıp
  // app'ten UZAKLAŞTIRDIM — sitenin kendi denetimi beni yakaladı.
  // 96 jetonun 21'i çok atamalı, 36 ölü değer var. Ölü değer yanlış
  // değerden tehlikelidir: yanlış değer hata verir, ölü değer İKNA EDER.
  ["olu_jeton_check.py", "Aynı jetona birden fazla değer — ölü atamalar işaretli mi"],
  // 🔴 19 EYLÜL — İKİ SAHNE AYNI GÖRÜNTÜYÜ KAYDEDİYORDU.
  // 53 sahnenin 4'ü iki ikiz kümesindeydi: biri düşen bir adım yüzünden
  // önceki ekranda kalmıştı, ikisi de veritabanında OLMAYAN bir kişiye
  // bakıyordu. Her sahne tek başına kusursuz görünüyordu; kusur ancak
  // sahneler birbiriyle kıyaslanınca ortaya çıktı.
  ["ayni_sahne_check.py", "İki sahne birebir aynı görüntüyü mü kaydetti"],
  // v3.2 — GÖKBERK 249'DA "column decision_note does not exist" ALDI.
  // Ölçtüm: o kolon hiçbir migration'da YOK. Sonra bütün şemaya sordum:
  // 15 yer, 8 dosya, 14'ü CANLIDA ETKİN fonksiyonlarda (oturum onayı,
  // başvuru oluşturma, KVKK silme...). Hiçbiri sözdizimi hatası değil;
  // PL/pgSQL ifadeyi ancak ÇALIŞTIRINCA çözümlüyor, o yüzden 289 dosyayı
  // koşturan harness çalışmayan dalı hiç görmedi.
  ["kolon_check.py", "Fonksiyon gövdelerinde olmayan kolona yazma (PL/pgSQL geç bağlama)"],
  ["schema_check.py",  "Olmayan tablo/kolon okuma — app boş liste gösterir, hata vermez"],
  ["sql_lint.py",      "SQL sözdizimi ve kalıp hataları"],
  ["returns_check.py", "RETURNS TABLE değişince DROP unutulmuş mu (42P13 — 19 Ağustos'ta canlıda patladı)"],
  ["wrapper_check.py", "Sarmalayıcı ile gerçek fonksiyonun imzası ayrışmış mı"],
  ["contract_check.py","RPC çağrılarının parametreleri SQL'deki imzayla uyuyor mu (app + BO)"],
  // v3.2 — GÖKBERK RAKİBİN SİTESİNDEKİ BİR CÜMLEYİ SORDU:
  // "Priority Pass, DragonPass & LoungeKey. No airline restrictions."
  // Ölçtüm: DragonPass'te misafir AYNI UÇUŞTA olmak zorunda
  // (md.7.15.7) — o cümle üçte bir yanlış. Sonra kendi geçmişimize
  // baktım: BİZ DE aynı hatayı yapmışız (content.js v0.17 notu) ve
  // düzeltmeyi koruyan hiçbir şey yoktu. Vitrindeki her kural cümlesi
  // artık bir İDDİA olarak kayıtlı ve motorun tablosuyla karşılaştırılıyor.
  ["kural_uyum_check.py", "Vitrindeki kural cümleleri motorun tablosuyla uyuşuyor mu"],
  ["gate_check.py",    "Motorun her hata kapısının kullanıcı dilinde karşılığı var mı — yoksa ham kod görünür"],
  ["flow_check.py",    "İş akışı değişmezleri (ilan→başvuru→kabul→oturum→çift onay)"],
  ["drift_check.py",   "Fonksiyonun etkin sürümü eski sürümün etkilerini koruyor mu"],
  // 🔴 21 EYLÜL — SQL 296 GÖKBERK'İN VERİTABANINDA DÜŞTÜ, ÜRÜN DOĞRUYKEN.
  // Sınama, `bekleyen_hikaye_daveti()`nin döndüreceği satırı AYRI bir
  // sırasız `limit 1` ile kendi seçiyordu; host'un birden çok bekleyen
  // oturumu olunca iki seçim farklı satıra düşüyor ve sınama patlıyordu.
  // Aynı sınıf SQL 211'de de yaşanmıştı — o zaman semptom kapatılmıştı.
  // ⚠️ Geniş kural (her sırasız `limit 1`) 135 bulgu veriyordu, çoğu
  // masum; ölçü "sınama fonksiyonun satırını kendi seçiyor" hâline
  // daraltıldı. Mutasyonla kanıtlandı.
  ["sinama_belirsiz_check.py",
   "SQL sınaması, fonksiyonun döndüreceği satırı kendi mi seçiyor (belirsiz limit 1)"],
  // 🔴 21 EYLÜL — SEED7 SUPABASE'DE İLK SATIRDA PATLADI:
  //     ERROR: 42601: syntax error at or near "\\"
  // Sebep benim eklediğim `\\set ON_ERROR_STOP on` satırıydı. `\\set` bir
  // SQL komutu değil, `psql`in meta-komutu; SQL Editor'de psql yok.
  // Üstelik hata mesajı YANLIŞ satırı gösteriyordu (bir önceki yorumu).
  // Diğer altı SEED'de o satır yoktu — yani hatayı "güvenli olsun"
  // alışkanlığım üretti.
  ["sql_editor_check.py",
   "Supabase SQL Editor'e yapıştırılacak dosyada psql meta-komutu (\\set, \\i…) var mı"],
  // 🔴 20 EYLÜL — "HANGİ SQL'LERİ ÇALIŞTIRDIM" TABLOSU SESSİZCE DARALMIŞTI.
  // `sql/KURULUM_TABLOSU.sql` 294'e kadardı; 295-299 içinde yoktu. Yani
  // tablo yanlış cevap vermiyordu, EKSİK cevap veriyordu — ve tam olarak
  // sorulan şeyi ("en son ne koştum") bilmiyordu. Hiçbir şey bunu
  // söylemiyordu; tablo "hepsi kurulu" deyip susuyordu.
  ["kurulum_tablosu_check.py",
   "'Hangi SQL'leri çalıştırdım' tablosu ilk dosyadan SON dosyaya kadar tam mı"],
  ["tip_check.py",     "İlan edilen dönüş tipi ile kaynak kolon tipi uyuşuyor mu"],
  // 🔴 v2.94 — YENİ. Var olan denetimler hep ÇAĞRILAN RPC'lere bakıyordu
  // (parametresi doğru mu, grant'ı var mı). HİÇ ÇAĞRILMAYAN bir RPC
  // ikisinin de kör noktasıydı: yazdım, ekrana koymadım, yapılmış sandım.
  ["yuzey_kullanim_check.py",
   "Yüzeye yazılan RPC app'te gerçekten çağrılıyor mu (yazılıp unutulan iş)"],
  // v2.95 — Gökberk madde 12'den doğdu: bağlı ama gövdesi boş bir olay
  // işleyicisi, bütün mevcut nöbetçilerin kör noktasıydı.
  ["bos_isleyici_check.py",
   "Çizilen her düğme gerçekten bir iş yapıyor mu (gövdesi boş işleyici)"],
  // v2.95 — Gökberk madde 14'ten doğdu: yaratma formu ile düzenleme formu
  // ayrı yazılırsa düzenleme formu her zaman geride kalır.
  ["alan_esitligi_check.py",
   "'Müsaitlik ekle' ile 'İlan düzenle' aynı alanları soruyor mu"],
  // v2.97 — screens.js bölünmesinden doğdu: bölmenin kazandırdığı şey
  // döngüsüzlük; onu ölçmeyen bir bölme, sadece dosya taşımadır.
  ["yonlendirme_check.py",
    "Tikladigim yere gercekten gidiyor muyum (on* prop'u cagriliyor ama verilmiyor mu)"],
  ["bagimlilik_check.py",
   "Dosyalar arası import döngüsü var mı · döngüsel çekirdek büyüdü mü"],

  // ══════════════════════════════════════════════════════════════════
  // v3.4 — GÖKBERK'İN 28 AĞUSTOS MADDELERİNDEN DOĞAN DÖRT NÖBETÇİ
  // Her biri o gün ÖLÇÜLEN bir kusurun geri gelmesini engelliyor.
  // ══════════════════════════════════════════════════════════════════
  // "İkonlarda hep kesilmeler var, profil tabındakiler yayık."
  // Sebep: ikon sistemi yoktu, 505 yerde emoji vardı.
  ["ikon_check.py",
   "Anlam→glif haritası geçerli mi · emoji borcu arttı mı (çırçır)"],
  // "Guest ilan açamamalı, ilanlarım gibi bir ekran görememeli. ÇOK KRİTİK."
  // Sebep: HostDaveti'ndeki düğme + sunucunun sessiz rol terfisi.
  ["rol_kapisi_check.py",
   "Guest host yüzeyine ulaşabiliyor mu (arayüz + sunucu kapıları)"],
  // "APP tarafında da performans artışı yapmamız lazım. Bir tık yavaş."
  // Sebep: bağımsız sorgular sıraya dizilmişti (Ayarlar 5, ilan formu 5).
  ["app_perf_check.py",
   "Sıralı ağ turu borcu arttı mı · açılış paralel mi · katalog önbellekli mi"],
  // "Keşfet, tanış gibi ekranlarda filtre butonu yok. Sağ üstte vardı."
  // Sebep: Hdr'in fotoğraflı dalı `right` ve `onBack`i sessizce yutuyordu.
  ["dal_prop_check.py",
   "Bir düğme/geri oku, bileşenin dallarından birinde sessizce ölüyor mu"],
  // v3.1'de sinyal→mürekkep ölçümü yapılmış, düzeltme yalnız `Btn`e
  // uygulanmıştı; 38 çağrı yeri geride kalmıştı (28 Ağu ölçümü).
  ["murekkep_check.py",
   "Sinyal rengi bir tint zeminde mürekkep olarak kullanılıyor mu (çırçır)"],
  // "görsel olarak etkileyici miyiz?" — 28 Ağu. Ölçüm: 49 elle yazılmış
  // kart gölgesizdi, 56 `S.card` gölgeliydi. Aynı ekranda iki farklı
  // yükselti kuralı = malzemenin ne olduğuna karar veremeyen bir göz.
  ["yuzey_check.py",
   "Kartlar aynı z-düzleminde mi (gölgesiz kart yüzeyi arttı mı)"],
  // `check.js` yalnız TERS yönü soruyor: "kodda kullanılan anahtar
  // tabloda var mı?" Bu, yazılıp hiç çizilmeyen metni ASLA göremez —
  // ve o sınıf bu projede beş kez yaşandı (t.pills, MyQuestions,
  // foundingLeft, waitingDemand, navDisc). 192 ölü anahtar ölçüldü.
  ["olu_metin_check.py",
   "i18n'de yazılıp hiçbir yerden çizilmeyen metin arttı mı (çırçır)"],
  // 289 dokunulabilirin 123'ü `Btn`i atlıyor. Hepsini bir turda taşımak
  // ölçmeden yapılacak 123 görsel değişiklikti; büyümesini engelledim.
  // Sert kural ayrı: sinyal zeminli bir düğme `Btn`in köşesinden başka
  // bir köşe kullanamaz — 9 tanesi kullanıyordu, düzeltildi.
  ["dugme_check.py",
   "Elle yazılmış düğme arttı mı · sinyal düğmesi Btn köşesini tutuyor mu"],
  // "şu an bildirim gider mi?" — 28 Ağu. İki gerçek kusur çıktı:
  // eklentide `icon` yoktu (Android beyaz siluet çiziyordu) ve
  // `getExpoPushTokenAsync()` argümansızdı (üretimde token alınamayabilir).
  ["push_check.py",
   "Bildirim ikonu · proje kimliği · kanal · dokunuş · izin penceresi"],

  // 🔴 v3.9.1 — YENİ. Var olan 40 denetim "kod doğru mu" diye soruyordu;
  // hiçbiri "bu kodun VAAT ETTİĞİ ŞEY OLUYOR MU" diye sormuyordu. Üç
  // kırık halka bu yüzden 40 yeşil ışığın altında durabildi:
  // gönderilmeyen SMS, kazanılamayan puan, okunmayan ayar.
  ["dogrulama_check.py",
   "Doğrulama zinciri: kod gerçekten gönderiliyor mu · puan kazanılıyor mu · ölü ayar"],
];

function pythonBul() {
  for (const [cmd, onEk] of [["py", ["-3"]], ["python3", []], ["python", []]]) {
    const r = spawnSync(cmd, [...onEk, "--version"], { encoding: "utf8" });
    if (r.error || r.status !== 0) continue;
    const s = ((r.stdout || "") + (r.stderr || "")).trim();
    if (/^Python 3\./.test(s)) return { cmd, onEk, surum: s };
  }
  return null;
}

let hata = 0;

// ════════════════════════════════════════════════════════════════════
// ORTAM ÖN KONTROLÜ — "19 denetim kırmızı" ile "19 kusur" aynı şey değil
//
// 🔴 21 EYLÜL — Gökberk paketi açtı, `npm run verify` koştu, 19 kırmızı
// aldı. Hiçbiri ürün kusuru değildi:
//
//     14 tanesi  `C:\sql` yok            ← zip'i gönderdim, NEREYE
//                                           açılacağını hiç yazmadım
//      3 tanesi  scikit-image kurulu değil
//      1 tanesi  cairosvg kurulu değil
//      1 tanesi  yerel PostgreSQL yok
//     ──
//     19  =  onun gördüğü sayının TAMAMI
//
// Zincir doğru davrandı (ölçemeyen denetim yeşil yanmadı) ama EKRANDA
// "19 denetim kırmızı yandı" yazıyordu ve bu cümle, kodunda 19 şey
// bozuk sanan birine hiçbir şey açıklamıyordu.
//
// 🆕 SINIF: "EKSİK GİRDİYİ KUSURDAN AYIRMAYAN BİR RAPOR, DOĞRU SAYIYI
// YANLIŞ ANLAM İLE VERİR — VE KORKUTTUĞU KİŞİ ÜRÜNÜN SAHİBİDİR."
// ════════════════════════════════════════════════════════════════════
const fs = require("fs");

function sqlKlasoru() {
  const adaylar = [
    process.env.LL_SQL_DIR,
    path.join(__dirname, "sql"),
    path.join(path.dirname(__dirname), "sql"),
  ].filter(Boolean);
  for (const a of adaylar) {
    try {
      if (fs.existsSync(a) &&
          fs.readdirSync(a).some((f) => /^\d{3}_.*\.sql$/.test(f))) return a;
    } catch (_) {}
  }
  return null;
}

function modulVar(py, ad) {
  if (!py) return false;
  const r = spawnSync(py.cmd, [...py.onEk, "-c", `import ${ad}`],
                      { stdio: "ignore" });
  return r.status === 0;
}

function ortamOnKontrol(py) {
  const sql = sqlKlasoru();
  const gruplar = [
    { ad: "SQL migration klasörü",
      var: !!sql,
      sayi: 17,
      neden: sql ? sql : "LL_SQL_DIR · rnapp\\sql · ..\\sql — üçünde de yok",
      cozum: ["Expand-Archive -Path .\\SQL_TAMAMI_001-299.zip -DestinationPath C:\\ -Force",
              "(zip'in içinde `sql\\` var; hedef C:\\ → sonuç C:\\sql)"] },
    { ad: "Python · scikit-image",
      var: modulVar(py, "skimage"),
      sayi: 3,
      neden: "renk ölçümü (Lab/LCh) bu kütüphaneyle yapılıyor",
      cozum: ["py -3 -m pip install scikit-image"] },
    { ad: "Python · cairosvg",
      var: modulVar(py, "cairosvg"),
      sayi: 1,
      neden: "marka üreticisi SVG'den PNG basıyor",
      cozum: ["py -3 -m pip install cairosvg"] },
    { ad: "Yerel PostgreSQL",
      var: fs.existsSync("/tmp/ll_pg"),
      sayi: 1,
      neden: "tip_check gerçek bir veritabanına soruyor",
      cozum: ["Windows'ta kurulu değilse bu denetim KIRMIZI KALIR.",
              "Ürün kusuru değil; SQL tarafı Supabase'de zaten koşuyor."] },
  ];
  const eksik = gruplar.filter((g) => !g.var);
  const beklenen = eksik.reduce((t, g) => t + g.sayi, 0);

  if (eksik.length) {
    console.log("=".repeat(74));
    console.log("ORTAM ÖN KONTROLÜ — aşağıdaki denetimler ÖLÇEMEYECEK");
    console.log("=".repeat(74));
    for (const g of eksik) {
      console.log(`\n  ✗ ${g.ad}  →  ${g.sayi} denetim kırmızı yanacak`);
      console.log(`      ${g.neden}`);
      for (const c of g.cozum) console.log(`      ${c}`);
    }
    console.log(`\n  TOPLAM ${beklenen} kırmızı BEKLENİYOR — bunlar EKSİK GİRDİ,`);
    console.log("  ürün kusuru DEĞİL. Zincirin sonundaki sayıdan bu kadarını düş.");
    console.log("=".repeat(74) + "\n");
  }
  return beklenen;
}

// ---- 0) Ortam ön kontrolü: ne ölçülemeyecek, ZİNCİR BAŞLAMADAN söyle ----
const pyErken = pythonBul();
const ORTAM_BEKLENEN = ortamOnKontrol(pyErken);

// ---- 1) Node denetimleri: her ortamda koşar ----
for (const [cmd, args, ne] of NODE_ADIMLARI) {
  const r = spawnSync(cmd, args, { stdio: "inherit" });
  if (r.status !== 0) { hata++; console.log(`  ↑ ${ne}`); }
}

// ---- 2) Python denetimleri ----
const py = pyErken;
if (!py) {
  console.log("\n" + "=".repeat(72));
  console.log("🔴 PYTHON YOK — AŞAĞIDAKİ 12 DENETİM ÇALIŞMADI");
  console.log("=".repeat(72));
  console.log("Build'in kendisi Python İSTEMEZ (ölçüldü: `npx expo export` çıkış 0).");
  console.log("Python'suz da APK/IPA alabilirsin. Atladığın şey denetimler:\n");
  for (const [dosya, ne] of PY_ADIMLARI) {
    console.log(`  ✗ ${dosya.padEnd(24)} ${ne}`);
  }
  console.log("\nAyrıca `npm run e2e` içindeki 5 uçtan uca test de çalışmaz");
  console.log("(gerçek PostgreSQL kaldırıp 26 senaryo koşuyorlar).\n");
  console.log("KURULUM — bir kez, ~3 dakika:");
  console.log("  winget install Python.Python.3.12     ← Windows 10/11, PATH'i kendi ayarlar");
  console.log("  (winget yoksa: python.org/downloads → 'Add python.exe to PATH' İŞARETLE)");
  console.log("  Sonra PowerShell'i KAPAT, yeniden aç. Doğrula:  node pyrun.js\n");
  console.log("Yalnız Node denetimlerini koşmak istersen:  npm run verify:js");
  console.log("=".repeat(72));
  process.exit(1);
}

console.log(`\n(python: ${py.cmd} ${py.onEk.join(" ")} → ${py.surum})\n`);
for (const [dosya, ne] of PY_ADIMLARI) {
  // 🔴 BAZI DENETİMLER ARGÜMAN ALIYOR ("kose_olcek.py --denetle").
  // Dosya adını olduğu gibi geçirmek Python'a tek bir dosya adı gibi
  // görünüyordu ve "böyle bir dosya yok" diye sessizce ölüyordu.
  const parcalar = dosya.split(" ");
  const r = spawnSync(py.cmd, [...py.onEk, ...parcalar], { stdio: "inherit" });
  if (r.status !== 0) { hata++; console.log(`  ↑ ${dosya} — ${ne}`); }
}

console.log("=".repeat(72));
if (hata) {
  console.log(`✗ ${hata} denetim kırmızı yandı.`);
  if (ORTAM_BEKLENEN) {
    const kalan = hata - ORTAM_BEKLENEN;
    console.log(`   ${ORTAM_BEKLENEN} tanesi EKSİK GİRDİ (ortam ön kontrolü — en üstte).`);
    if (kalan > 0) {
      console.log(`   ${kalan} tanesi ORTAMLA AÇIKLANMIYOR — asıl bakılacak olan bu.`);
    } else if (kalan === 0) {
      console.log("   Geriye ortamla açıklanmayan bulgu KALMIYOR — girdiyi tamamla, zincir yeşile döner.");
    } else {
      console.log(`   ⚠️ Beklenenden ${-kalan} AZ kırmızı var — ön kontrol grubu yanlış sayıyor, söyle.`);
    }
  }
} else console.log(`✓ ${NODE_ADIMLARI.length + PY_ADIMLARI.length} denetimin hepsi temiz.`);
console.log("=".repeat(72));
process.exit(hata ? 1 : 0);
