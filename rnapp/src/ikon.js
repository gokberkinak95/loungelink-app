// ============================================================================
// İKON KATMANI  (28 Ağustos 2026 · v3.4)
//
// 🔴 NEDEN VAR — ÖLÇÜLDÜ, TAHMİN DEĞİL
// Gökberk: "kullanılan yeni ikonlarda hep kesilmeler var, profil tabındakiler
// yatay olarak yayılmış genişlemiş. İkonlar düzgün ve canlı bir yapıda olmalı."
//
// Üç ayrı şikâyet ama TEK sebep: uygulamanın ikon sistemi diye bir şeyi yoktu.
// İkon yerine EMOJİ yazılmıştı — kodda 505 yerde, 81 farklı karakter.
// Emoji bir ikon değildir, çünkü:
//
//   1) ÇİZİMİ BİZE AİT DEĞİL. Aynı 🛡 Samsung'da başka, Apple'da başka,
//      Huawei'de başka çizilir. "Uygulamanın geneliyle uyumlu ikon" emoji
//      ile MÜMKÜN DEĞİLDİR — çizimi işletim sistemi yapıyor.
//
//   2) BAZILARI RENKLİ DEĞİL. `⚙` (U+2699), `⬆` (U+2B06), `★` (U+2605)
//      varsayılan olarak METİN sunumludur; renkli emoji istemek için
//      arkasına U+FE0F gerekir. Yoksa cihaz onları normal bir harf gibi
//      SİYAH çizer ve gövde fontunun genişliğine yayar — Gökberk'in
//      "yayık siyah ikon" dediği şey tam olarak budur.
//
//   3) SATIR YÜKSEKLİĞİNE SIĞMAZLAR. Emoji'nin dikey metrikleri harfinkinden
//      büyüktür; `fontSize` ile ölçeklenen bir `<Text>` içinde alt/üst
//      kenarları KIRPILIR. Ekran görüntülerindeki kesik `ℹ` bu.
//
//   4) DİLİ SIZDIRIRLAR. 📅 Android'de üstünde "July 17" yazan bir takvim
//      çizer. Türkçe bir arayüzde İngilizce bir ikon.
//
// 🆕 SINIF: "EMOJİ BİR İKON DEĞİLDİR — ÇİZİMİNİ SEN YAPMIYORSAN, GÖRÜNTÜSÜNÜ
// DE SEN GARANTİ EDEMEZSİN."
//
// ÇÖZÜM: tek bir vektör ikon ailesi (Ionicons), tek bir bileşen, tek bir
// ANLAM haritası. Ekranlar artık glif adı yazmıyor — ANLAM yazıyor:
//   <Ikon ad="guvenlik" />   değil   <Ionicons name="shield-checkmark-outline" />
// Böylece aileyi bir gün değiştirirsek 200 dosya değil bu dosya değişir.
//
// ⚠️ YENİ BAĞIMLILIK EKLEMEDİM. `@expo/vector-icons` zaten `expo` paketinin
// bağımlılığı olarak KURULU (ölçüm: node_modules/@expo/vector-icons var,
// package-lock'ta expo'nun altında). Yerel bir modül eklemiyor; yalnız bir
// font dosyası. Yine de package.json'a AÇIKÇA yazıldı: dolaylı bağımlılığa
// yaslanmak, üst paket onu bırakırsa sessizce kırılan bir yapıdır.
//
// ⚠️ FONT BUILD'E GÖMÜLDÜ (5 Eylül, ikinci kez ve bu kez DOĞRU ADLA):
// `assets/fonts/ionicons.ttf` (küçük harf — bileşenin aile adı "ionicons";
// Android aileyi dosya adından türetir) + `assets/fonts/LLSimge.ttf`,
// app.json'daki `expo-font` eklentisiyle. 30 Ağu'da eklentiden çıkarılıp
// yalnız çalışma anına bırakılmıştı; cihazda `Font.loadAsync` iki sürüm
// üst üste reddetti ve her ikon yer tutucu kare çizdi. Gömülü font için
// `isLoaded` ilk kareden true → `loadAsync` hiç çağrılmaz; aşağıdaki
// çalışma anı yükleyicisi yalnız yedek (iOS'ta aile adı farkı için). Sebebi: çalışma anında yüklenen bir ikon fontu
// İLK KAREDE BOŞ çizer — kullanıcı ikonların "sonradan geldiğini" görür.
// Gömülü font ilk kareden itibaren hazırdır.
//
// 🆕 SINIF: "İKON FONTUNU ÇALIŞMA ANINDA YÜKLERSEN, İLK KARE İKONSUZDUR —
// VE İLK KARE KULLANICININ İLK İZLENİMİDİR."
// ============================================================================
// ============================================================================
// 🔴🔴 30 AĞUSTOS — BÜTÜN İKONLAR BOŞ ÇİZİLDİ. KÖK NEDEN VE ÜÇ KAPI.
//
// Gökberk: "Tüm iconlar badgeler hepsi uçmuş. Uygulamanın istisnasız her
// yerinde bu sorun var."
//
// ÖLÇÜM (tahmin değil): ekran görüntülerinde `✈` ve `‹` gibi METİN glifleri
// çiziliyor, rozet daireleri çiziliyor, yalnız Ionicons glifleri yok.
// Yani yerleşim doğru, renk doğru, bileşen mount oluyor — çizilen şey boş.
//
// Sebebi kütüphanenin kendi kodunda, tek satır:
//   node_modules/@expo/vector-icons/build/createIconSet.js
//     state = { fontIsLoaded: Font.isLoaded(fontName) };
//     async componentDidMount() {
//       if (!this.state.fontIsLoaded) { await Font.loadAsync(font); ... }
//     }
//     render() { if (!this.state.fontIsLoaded) return <Text />; }   ← BOŞLUK
//
// `Font.loadAsync` bir kez reddederse `setState` hiç çalışmaz ve bileşen
// UYGULAMANIN ÖMRÜ BOYUNCA boş `<Text/>` döndürür. Hata yakalanmaz, log
// düşmez, ekranda iz bırakmaz. Tam olarak gördüğümüz tablo.
//
// 🆕 SINIF: **"BİR BİLEŞENİN YÜKLENEMEDİĞİNDE BOŞLUK ÇİZMESİ, HATA
// VERMEMESİNDEN DAHA KÖTÜDÜR — HATA GÖRÜLÜR, BOŞLUK GÖRÜLMEZ."**
//
// ÜÇ KAPIYI BİRDEN KAPATIYORUZ, ÇÜNKÜ CİHAZDA ÖLÇEMİYORUM:
//
//  1) ÇİFT KAYIT. Font hem `app.json`daki `expo-font` eklentisiyle build'e
//     gömülüydü HEM de çalışma anında `Font.loadAsync` ile yükleniyordu.
//     İki kayıt yolu = iki farklı aile adı ihtimali ve `loadAsync`in
//     reddedebileceği bir durum. Eklenti listesinden çıkarıldı; tek yol
//     kaldı ve o yol aşağıdaki (2) ile ilk kareden önce tamamlanıyor.
//
//  2) ÖN YÜKLEME + KAPI. `ikonFontuHazirla()` App.js'te, ilk ekran
//     çizilmeden önce çağrılıyor. Böylece `Font.isLoaded("Ionicons")`
//     daha kurucuda `true` döner ve yukarıdaki boş `<Text/>` dalına
//     HİÇ GİRİLMEZ. Reddederse artık sessiz değil — `logError`a düşüyor.
//
//  3) `lineHeight` KALDIRILDI. `<Ionicons style={{ lineHeight: boy }}>`
//     yazıyorduk; `lineHeight === fontSize` Android'de glifin üst/alt
//     taşmasını kırpar. İkon zaten ortalanmış sabit bir kutunun içinde,
//     yani satır yüksekliğinin orada hiçbir işi yoktu.
//
// VE ARTIK SESSİZ BAŞARISIZLIK YOK: font yüklenemezse `Ikon` boşluk değil,
// GÖRÜNÜR bir yer tutucu çizer (aşağıdaki `YerTutucu`). Arayüz eksik
// görünür ama "bozuk" olduğu anlaşılır — sessizce yok olmaz.
// ============================================================================
import React from "react";
import { View, Text } from "react-native";
import Ionicons from "@expo/vector-icons/Ionicons";
import { createIconSet } from "@expo/vector-icons";
import { C } from "./theme";

// ---------------------------------------------------------------------------
// KENDİ GLİF SETİMİZ — ŞU AN TEK BİR İŞARET: RADAR
//
// 🔴 NEDEN: TASARIMIN KEŞFET İŞARETİ IONICONS'TA YOK. ÖLÇTÜM.
// Gökberk "tasarımdaki keşfet logosunun ... icon şekli ile app önizlemesi
// farklı" dedi. Cevabı gözle vermek yerine sayıyla verdim: tasarımın radar
// SVG'sini gerçek bir tarayıcıda çizdim (yuvarlak kapaklar dahil) ve
// Ionicons'un **1338 glifinin hepsini** aynı kutuda aynı yolla ölçtüm
// (IoU = kesişim/birleşim):
//
//     Ionicons'un EN İYİSİ     at-circle-outline    0.497
//                              radio-button-on      0.481
//                              nuclear-outline      0.469
//     benim gönderdiğim        radio-outline        0.129   ← EN KÖTÜSÜ
//     bu dosyadaki kendi glif  LLSimge/radar        0.885
//
// Yani (a) Ionicons'ta bu işaret YOK — 1338 glifin hiçbiri 0.5'i geçmiyor,
// (b) "aynı fikir, sinyal yayılıyor" diye savunduğum `radio-outline`
// ölçülen EN KÖTÜ adaydı. Savunmam gözün ürettiği bir benzerlikti.
//
// 🆕 SINIF: "BİR SEÇİMİ 'BENZER' DİYE SAVUNMADAN ÖNCE BENZERLİĞİ ÖLÇ —
// GÖZ, KENDİ VERDİĞİ KARARI HAKLI ÇIKARMAK İÇİN BENZERLİK UYDURUR."
//
// ⚠️ YENİ YEREL (NATIVE) BAĞIMLILIK YOK. `createIconSet` zaten
// `@expo/vector-icons`in dışa verdiği API — Ionicons'un kendisi de tam
// olarak böyle kuruluyor (`createIconSet(glyphMap,'ionicons',font)`).
// `react-native-svg` eklemek tek bir ikon için yerel bir modül, yeni bir
// derleme ve daha büyük paket demekti; `node_modules/Ionicons.ttf`i
// yamalamak ise her `npm ci`de sessizce kaybolurdu — ikisi de reddedildi.
//
// Font `brand/build_radar.py` ile ÜRETİLİYOR ve o betiğin kendi nöbetçisi
// var: glif yazıldıktan sonra PIL ile geri okunup mürekkebi sayılıyor ve
// merkezin DOLU değil HALKA olduğu ayrıca doğrulanıyor. Sebebi: bir ikon
// fontunun "kurulmuş" olması çizdiği anlamına gelmez; boş glif de,
// yönü ters kontur da SESSİZDİR — ve burası uygulamanın en çok
// kullanılan sekmesi.
// ---------------------------------------------------------------------------
export const LL_GLIFLER = { radar: 0xE900 };
const LLSimge = createIconSet(LL_GLIFLER, "LLSimge",
                              require("../assets/fonts/LLSimge.ttf"));

// ---------------------------------------------------------------------------
// FONT HAZIRLIĞI — App.js ilk çizimden önce bunu bekler.
//
// `Ionicons.font` = { Ionicons: <asset> }. `loadFont()` kütüphanenin kendi
// yardımcısı; `Font.loadAsync(font)` çağırır. Burada SARMALIYORUZ ki hata
// yutulmasın ve durumu okuyabilelim.
// ---------------------------------------------------------------------------
let _fontDurum = "bekliyor";   // "bekliyor" | "hazir" | "hata" (İKİ aile de düştü)
// 🔴 3 EYLÜL — AİLE BAŞINA DURUM. Cihazda İKONLARIN HEPSİ yer tutucuya
// dönmüştü. Sebep ölçüldü: iki aile TEK try içinde yükleniyordu; biri
// düşünce `_fontDurum="hata"` oluyor ve ÖTEKİ (yüklenmiş!) aile de
// çizilmiyordu. Radar fontu yüzünden Ionicons'un 60 ikonu boşa gitti.
//
// 🆕 SINIF: "BAĞIMSIZ İKİ KAYNAĞI TEK BİR HATA DURUMUNA BAĞLARSAN, BİRİNİN
// ARIZASI ÖTEKİNİN DE ARIZASI OLUR — DURUMU KAYNAK BAŞINA TUT."
const _aile = { Ionicons: "bekliyor", LLSimge: "bekliyor" };
const _aileHata = { Ionicons: null, LLSimge: null };
let _fontSoz = null;

export function ikonFontuDurumu() { return _fontDurum; }
export function ikonAileDurumu() { return { ..._aile, hata: { ..._aileHata } }; }

async function aileYukle(ad, Aile, hataBildir) {
  // Font.loadAsync bir kez reddederse `createIconSet` boş <Text/> çizer
  // ve bir daha denemez; o yüzden burada İKİ deneme var (ilk açılışta
  // asset kopyası yarım kalmış olabilir — Android'de görüldü).
  for (let deneme = 1; deneme <= 2; deneme++) {
    try {
      if (typeof Aile.loadFont === "function") await Aile.loadFont();
      _aile[ad] = "hazir";
      return true;
    } catch (e) {
      _aileHata[ad] = e;
      if (deneme === 2) {
        _aile[ad] = "hata";
        try {
          hataBildir && hataBildir("ikon_font_yuklenemedi",
            new Error(ad + ": " + String(e && e.message ? e.message : e)));
        } catch (_) {}
      }
    }
  }
  return false;
}

export async function ikonFontuHazirla(hataBildir) {
  if (_fontDurum === "hazir") return true;
  if (_fontSoz) return _fontSoz;
  _fontSoz = (async () => {
    try {
      // İki aile PARALEL ve BAĞIMSIZ. Biri düşerse öteki yine çizilir.
      const [ion, ll] = await Promise.all([
        aileYukle("Ionicons", Ionicons, hataBildir),
        aileYukle("LLSimge", LLSimge, hataBildir),
      ]);
      _fontDurum = (ion || ll) ? "hazir" : "hata";
      return ion && ll;
    } finally {
      _fontSoz = null;
    }
  })();
  return _fontSoz;
}

// ---------------------------------------------------------------------------
// ANLAM → GLİF
//
// Kural: SOLDAKİ ad üründen gelir (ne demek istiyoruz), SAĞDAKİ ad
// kütüphaneden. Ekranlar yalnız soldakini bilir.
//
// Hepsi `-outline`: uygulamanın çizgisi ince (Archivo gövde + Cormorant
// başlık, 1px ayraçlar, 0.08 opaklıkta çerçeveler). Dolu ikonlar bu
// tipografinin yanında ağır durur. İSTİSNA: seçili sekme ve gerçekten
// uyarı niteliğindeki durumlar dolu çizilir — orada ağırlık İSTENİR.
// ---------------------------------------------------------------------------
export const IKONLAR = {
  kesfetYedek:    "compass-outline",         // radar fontu düşerse Keşfet sekmesi (3 Eylül)
  // ── Alt sekme çubuğu ──────────────────────────────────────────────
  // 🔴 ESKİSİ: ⌂ ◇ ◈ ◉ — dördü de geometrik SEMBOL, hiçbiri o sekmenin
  // ne olduğunu anlatmıyordu. "Profil" için baklava dilimi içinde bir
  // nokta, cihazın gövde fontunda bir GÖZ gibi çiziliyordu (ekran
  // görüntüsünde net görülüyor). Artık dördü de tarif edici.
  ana:            "home-outline",
  anaDolu:        "home",
  // 🔴 v3.6 — KEŞFET ARTIK BİR SEKME. Misafirin ürünle kurduğu ilişki
  // tek cümledir: "bugün hangi salona girebilirim?" O sorunun ekranı
  // bugüne kadar ana sayfadaki bir CTA'nın ARKASINDAYDI — yani ürünün
  // çekirdek eylemi, kalıcı bir adresi olmayan tek eylemdi.
  // 🔴 30 AĞUSTOS · 7. TUR — KEŞFET ARTIK BÜYÜTEÇ DEĞİL RADAR.
  // Gökberk: "tasarim_vs_app'de keşfet iconu tasarımdaki daha iyi."
  // Haklı ve sebebi biçimsel değil ANLAMSAL: büyüteç "aradığını yaz"
  // der; bu ekranda kullanıcı bir şey ARAMIYOR, çevresinde KİM VAR
  // ona bakıyor. Tasarımın tabbar'ı da `I['radar']` kullanıyor —
  // yani bu bir tercih değil, uygulanmamış bir karardı.
  //
  // 🆕 SINIF: "BİR İKON EYLEMİ DEĞİL EKRANIN VAAT ETTİĞİ ŞEYİ
  // ANLATMALI — 'ARA' İLE 'ÇEVRENDE KİM VAR' AYNI JEST DEĞİLDİR."
  // 🔴 31 AĞUSTOS · 8. TUR — ARTIK IONICONS'TAN DEĞİL, KENDİ GLİFİMİZDEN.
  // `radio-outline` ölçülen IoU'su 0.129 ile 1338 adayın en kötüsüydü;
  // tasarımın kendi SVG'sinden çizilen `ll:radar` 0.885. Ayrıntı ve
  // ölçüm yukarıdaki LL_GLIFLER başlığında.
  //
  // `ll:` öneki BİLEREK var: bu ad uzayı bizim, Ionicons'unki değil.
  // Ön ek olmasaydı bir gün Ionicons'a "radar" eklenince hangi ailenin
  // kastedildiği okunamazdı.
  //
  // Dolu hâli YOK — tasarımın tabbar'ında seçili sekme de aynı çizgi
  // işaretini kullanıyor; ayrımı ikonun kalınlığı değil, ÜSTÜNDEKİ altın
  // gösterge çizgisi ve rengi taşıyor. Dolu bir varyant uydurmak,
  // tasarımın kurmadığı bir ayrımı eklemek olurdu.
  kesfet:         "ll:radar",
  kesfetDolu:     "ll:radar",
  plan:           "calendar-outline",
  planDolu:       "calendar",
  tanis:          "people-outline",
  tanisDolu:      "people",
  profil:         "person-circle-outline",
  profilDolu:     "person-circle",

  // ── Profil menüsü ─────────────────────────────────────────────────
  yayin:          "megaphone-outline",      // ⬆ (siyah/yayık) → Yayın & Davet
  gecmis:         "time-outline",           // 📅 ("July 17" yazan takvim)
  degerlendirme:  "star-outline",
  degerlendirmeDolu: "star",   // puan yıldızının DOLU hâli (bkz. ekranlar_yalin)           // ★ (siyah/yayık)
  bildirim:       "notifications-outline",  // 🔔
  bildirimKapali: "notifications-off-outline",
  guvenPuan:      "ribbon-outline",         // 🌟
  guvenlik:       "shield-checkmark-outline", // 🛡
  puan:           "trophy-outline",         // 🏆
  davet:          "gift-outline",           // 🎁
  kampanya:       "pricetag-outline",       // 🎯
  planKart:       "card-outline",           // 💳
  ayarlar:        "settings-outline",       // ⚙ (siyah/yayık — en belirgin hata)
  cikis:          "log-out-outline",        // 🚪
  cuzdan:         "wallet-outline",

  // ── Durum / geri bildirim ─────────────────────────────────────────
  bilgi:          "information-circle-outline", // ℹ — KIRPILAN ikon buydu
  uyari:          "warning-outline",         // ⚠
  hata:           "alert-circle-outline",
  tamam:          "checkmark-outline",       // ✓
  tamamDaire:     "checkmark-circle-outline",
  // 🔴 30 Ağu · 3. tur — ONAY KUTUSU. Kayıt ekranındaki 6 onay `☑`/`☐`
  // METİN karakteriyle çiziliyordu: ikisi de gövde fontunun metriklerine
  // tabi, ikisi de farklı genişlikte — işaretlenince satır kayıyordu.
  kutuBos:        "square-outline",
  kutuDolu:       "checkbox",// ✅
  kapat:          "close-outline",           // ✕
  bekliyor:       "hourglass-outline",       // ⏳
  yasak:          "ban-outline",             // 🚫
  kilit:          "lock-closed-outline",     // 🔒
  // 🔴 22 Eylül — şifre göster/gizle düğmesi için (giriş ekranı).
  goz:            "eye-outline",              // şifreyi göster
  gozKapali:      "eye-off-outline",          // şifreyi gizle
  kilitAcik:      "lock-open-outline",       // 🔓
  bayrak:         "flag-outline",            // 🚩
  acil:           "medkit-outline",          // 🆘
  hukuk:          "scale-outline",           // ⚖
  belge:          "clipboard-outline",       // 📋
  yenile:         "refresh-outline",         // 🔄
  ara:            "search-outline",          // 🔎
  duzenle:        "create-outline",          // 📝
  filtre:         "options-outline",         // (yeni — filtre butonu)

  // ── Yön ───────────────────────────────────────────────────────────
  ileri:          "arrow-forward-outline",   // →
  geri:           "arrow-back-outline",      // ←
  yukari:         "chevron-up-outline",      // ▲ ▴
  asagi:          "chevron-down-outline",    // ▼ ▾
  sag:            "chevron-forward-outline", // ›
  sol:            "chevron-back-outline",    // ‹
  degistir:       "swap-horizontal-outline", // ⇄ ↔

  // ── Ürün kavramları ───────────────────────────────────────────────
  ucus:           "airplane-outline",        // ✈
  salon:          "business-outline",        // 🛋 (turuncu kanepe emoji)
  // Tasarımın `I['kapi']`si: kapı çerçevesi + dışarı çıkan ok. Bir
  // BULUŞMA NOKTASI anlatır ("Kapı A12 önü"), bir mekân değil — o yüzden
  // `salon`dan ayrı bir ad. 1338 Ionicons glifi ölçüldü:
  // log-out-outline 0.633 · exit-outline 0.625 · business-outline 0.378.
  kapi:           "exit-outline",
  konum:          "location-outline",        // 📍
  radar:          "radio-outline",           // 📡
  saat:           "time-outline",            // ⏱ 🕐
  takvim:         "calendar-outline",        // 📅
  eposta:         "mail-outline",            // ✉ 📨
  telefon:        "phone-portrait-outline",  // 📱
  kimlik:         "id-card-outline",         // 🪪
  kamera:         "camera-outline",          // 📷
  // 13 Eylül · v5.9.0 biniş kartı akışı — üç yeni ANLAM.
  // Var olanları zorlamadım: "galeriden ekle" için `kamera` yanlış olurdu
  // (kamera çekmek, galeri seçmek), "PDF ekle" için `belge` (pano) da.
  // 🆕 SINIF: "YAKIN BİR İKONU ZORLAMAK, İKONU DEĞİL ANLAMI BOZAR."
  galeri:         "images-outline",          // 🖼 galeriden ekran görüntüsü
  dosya:          "document-text-outline",   // 📄 PDF bilet
  tarayici:       "scan-outline",            // ⛶ vizör / barkod tara
  kutlama:        "sparkles-outline",        // 🎉
  elSikisma:      "people-circle-outline",   // 🤝
  is:             "briefcase-outline",       // 💼
  selam:          "happy-outline",           // 👋
  kredi:          "cash-outline",            // 💸
  bilet:          "ticket-outline",          // 🎫
  kisi:           "person-outline",
  kisiler:        "people-outline",
  sohbet:         "chatbubble-ellipses-outline",
  yildizParlak:   "sparkles-outline",        // ✦ ⭐ 🌟
  hedef:          "locate-outline",
  sinyal:         "cellular-outline",        // 📶

  // ── Olanaklar (lounge amenities) ──────────────────────────────────
  olanakWifi:     "wifi-outline",            // 📶
  olanakYemek:    "restaurant-outline",      // 🍽
  olanakBufe:     "fast-food-outline",       // 🥗
  olanakBar:      "wine-outline",            // 🍷
  olanakDus:      "water-outline",           // 🚿
  olanakDinlenme: "moon-outline",            // 🌙
  olanakCocuk:    "happy-outline",           // 🧸 👶
  olanakIbadet:   "moon-outline",            // 🕌
  olanakCalisma:  "laptop-outline",          // 💻
  olanakTv:       "tv-outline",              // 📺
  olanakTeras:    "partly-sunny-outline",    // 🌤
  olanakSinema:   "film-outline",            // 🎬
  olanakOyun:     "game-controller-outline", // 🎮
  olanakBagaj:    "bag-handle-outline",      // 🧳
  olanakKahve:    "cafe-outline",            // ☕
  olanakOtel:     "bed-outline",             // 🏨

  // ── Seyahat amacı · rapor türü · ödül kategorisi ──────────────────
  // 🔴 v3.7 — BU ÜÇ LİSTE EMOJİYİ VERİ OLARAK TAŞIYORDU:
  //     PURPOSES = [["business", "İş", "💼"], ...]
  // Yani ikon, bileşenin değil SÖZLÜĞÜN parçasıydı; ve hiçbiri gövde
  // fontunda yok, hepsi sistem emoji fontuna düşüyordu.
  amacIs:         "briefcase-outline",       // 💼
  amacKonferans:  "mic-outline",             // 🎤
  amacTatil:      "sunny-outline",           // 🏖
  amacAktarma:    "swap-horizontal-outline", // 🔄
  amacEtkinlik:   "ticket-outline",          // 🎫
  raporTaciz:     "ban-outline",             // 🚫
  raporDolandirici:"card-outline",           // 💸
  raporSahte:     "person-remove-outline",   // 🎭
  raporDiger:     "ellipsis-horizontal-outline",
  odulSalon:      "business-outline",        // 🛋
  odulMil:        "airplane-outline",        // ✈
  odulOtel:       "bed-outline",             // 🏨
  odulEsim:       "cellular-outline",        // 📶
  odulSigorta:    "shield-checkmark-outline",// 🛡
};

// ---------------------------------------------------------------------------
// BİLEŞEN
//
// 🔴 KIRPILMAYI ÖNLEYEN ŞEY BURASI. İkon bir `<Text>` değil, SABİT ÖLÇÜLÜ
// bir kutunun içine ORTALANMIŞ bir vektör. Kutu `boy × boy`; glif kutudan
// küçük. Satır yüksekliği, harf metrikleri, `lineHeight` — hiçbiri ona
// dokunamaz, çünkü ikon artık metin akışının içinde değil.
//
// 🆕 SINIF: "BİR İKONU METİN GİBİ YERLEŞTİRİRSEN, METNİN BÜTÜN
// KIRPILMA KURALLARINI DA MİRAS ALIR — İKONA KENDİ KUTUSUNU VER."
// ---------------------------------------------------------------------------
// Görünür yer tutucu: ikonun olması gereken yerde nötr bir çerçeve.
// Boşluktan farkı, GÖRÜLMESİ. Renk gövde mürekkebinin soluk hâli, yani
// arayüzü bağırmadan "burada bir şey eksik" der.
function YerTutucu({ boy, stil, renk }) {
  return (
    <View style={[{ width: boy, height: boy, alignItems: "center", justifyContent: "center" }, stil]}>
      <View style={{
        width: Math.round(boy * 0.62), height: Math.round(boy * 0.62),
        borderRadius: Math.round(boy * 0.16),
        borderWidth: 1.2, borderColor: (renk || C.ink) + "55",
      }} />
    </View>
  );
}

export function Ikon({ ad, boy = 20, renk, stil, kutu }) {
  const glif = IKONLAR[ad];

  // 🔴 SESSİZ BOŞLUK, YANLIŞ İKONDAN DAHA KÖTÜDÜR: yanlış ikonu görürsün,
  // olmayan ikonu göremezsin. Geliştirmede gürültü çıkarıyoruz, üretimde
  // düzeni bozmadan boşluk bırakıyoruz.
  if (!glif) {
    // `__DEV__` Metro global'i; taşınabilir olsun diye korumalı okuyoruz.
    if (typeof __DEV__ !== "undefined" && __DEV__) console.warn("Ikon: tanımsız ad →", ad);
    return <YerTutucu boy={boy} stil={stil} renk={renk} />;
  }

  // 🔴 FONT YÜKLENEMEDİYSE BOŞLUK DEĞİL, GÖRÜNÜR YER TUTUCU.
  // Sebebi yukarıdaki başlıkta: boş çizim, kullanıcıya "bu ekranda ikon
  // yok" der; yer tutucu "bu ikon yüklenemedi" der. İkincisi doğru.
  // `ll:` ile başlayan adlar KENDİ setimize gider. Aile seçimi burada
  // TEK bir yerde yapılıyor; ekranlar hangi fontta olduğunu bilmiyor —
  // bu dosyanın en baştaki sözü buydu ("ekranlar glif adı değil ANLAM
  // yazar") ve yeni bir aile eklerken de bozulmadı.
  const yerli = glif.indexOf("ll:") === 0;
  const aileAd = yerli ? "LLSimge" : "Ionicons";
  // Yalnız KENDİ ailesi düştüyse yer tutucu; öteki aile bundan etkilenmez.
  // Radar düşerse Keşfet sekmesi Ionicons'un `compass-outline`ına düşer —
  // yer tutucu kareden iyidir ve anlamı taşır.
  if (_fontDurum === "hata") return <YerTutucu boy={boy} stil={stil} renk={renk} />;
  if (_aile[aileAd] === "hata") {
    if (yerli && _aile.Ionicons !== "hata") {
      // radar düşerse Ionicons'un pusulası (haritada `kesfetYedek`)
      return <Ikon ad="kesfetYedek" boy={boy} renk={renk} stil={stil} kutu={kutu} />;
    }
    return <YerTutucu boy={boy} stil={stil} renk={renk} />;
  }
  const Aile = yerli ? LLSimge : Ionicons;
  const icerik = (
    <Aile
      name={yerli ? glif.slice(3) : glif}
      size={boy}
      color={renk || C.ink}
      // `allowFontScaling` KAPALI: kullanıcı yazı tipini %200 büyüttüğünde
      // metin büyümeli ama satır içi ikon kutusunu patlatmamalı. Ölçeklenen
      // bir ikon, düzelttiğimiz kırpılmanın geri gelmesidir.
      allowFontScaling={false}
      // 🔴 `lineHeight` KALDIRILDI (30 Ağu). `lineHeight === fontSize`
      // Android'de glifi kırpar; ikon zaten ortalanmış sabit kutuda.
    />
  );

  // Sabit kutu: hizalama her satırda aynı olsun.
  const k = typeof kutu === "number" ? kutu : boy;
  return (
    <View style={[{ width: k, height: k, alignItems: "center", justifyContent: "center" }, stil]}>
      {icerik}
    </View>
  );
}

// ---------------------------------------------------------------------------
// SATIR İÇİ İKON — metnin yanında duran, metinle aynı hizada
//
// Kullanım: <Satir ad="ucus" metin={"TK1955"} />
// Sebebi: `"✈ " + kod` deseni 18 yerde vardı ve her birinde boşluk,
// hizalama ve renk elle yazılıyordu — üçü de her yerde farklıydı.
// ---------------------------------------------------------------------------
export function IkonMetin({ ad, metin, boy = 14, renk, stilMetin, ara = 4,
                            sag = false, stil }) {
  // 🔴 30 AĞUSTOS · 3. TUR — `sag` EKLENDİ.
  // 230 metin sembolünü vektöre çevirirken gördüm ki işaretlerin bir
  // kısmı metnin SONUNDA duruyor: `{t.openChat} →`, `{t.adviceShow} ›`.
  // Bunlar "şuraya git" işaretleri ve sona ait — başa alsaydım cümlenin
  // anlamı değişirdi ("→ Sohbeti aç" ile "Sohbeti aç →" aynı şey değil:
  // biri işaret, öteki yön).
  const ik = <Ikon ad={ad} boy={boy} renk={renk || C.mut}
                   stil={sag ? { marginLeft: ara } : { marginRight: ara }} />;
  return (
    <View style={[{ flexDirection: "row", alignItems: "center" }, stil]}>
      {!sag && ik}
      {/* `flexShrink:1`: satır kutusundan uzun metin SARILSIN — kayıt
          ekranındaki "lounge erişimi satmaz" kutusu cihazda taşıyordu. */}
      <Text style={[{ flexShrink: 1 }, stilMetin]}>{metin}</Text>
      {sag && ik}
    </View>
  );
}

// ---------------------------------------------------------------------------
// BİLGİ ROZETİ — ekran görüntüsünde kırpılan `ℹ` bunun yerine geçtiği yer
//
// Dokunulabilir olması gerekiyor (kural açıklamasını açıyor), o yüzden
// dokunma alanı görsel boyuttan BÜYÜK: 20px ikon, 44px dokunma.
// (TAP kuralı: theme.js · erişilebilirlik tabanı 44dp.)
// ---------------------------------------------------------------------------
export function BilgiRozeti({ boy = 15, renk }) {
  return <Ikon ad="bilgi" boy={boy} renk={renk || C.mut} kutu={boy + 3} />;
}
