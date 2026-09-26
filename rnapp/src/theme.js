import { Platform } from "react-native";
// ============================================================
// TEMA — MVP v15 paletinin BIREBIR kopyasi
//
// MVP'de renk bir NAVIGASYON DILI: kullanici rengi gorup ne tur
// bir sey oldugunu anliyor. Kullanim sayilari (MVP v15'te olculdu):
//   mor  #7C3AED  74 kez — Meet / companion / networking
//   teal #0D9488  89 kez — Trips / host / seyahat
//   altin#B8943A 163 kez — LoungePuan / marka
//   yesil#059669  73 kez — basari / aktif / onaylandi
//   amber#D97706  28 kez — dikkat / uyari (engelleyici degil)
//   kirmizi #E11D48 41 kez — hata / sil / SOS
//
// v1.21'e kadar hepsi altina indirilmisti; o dil kayboldu.
// Yeni renk EKLEME — MVP'de olmayan renk buraya girmez.
// ============================================================

export const C = {
  // --- MVP ana palet (birebir) ---
  gold:   "#B8943A",   // cGD
  // 🔴 v3.1 — BU İKİ TOKEN HEM OKUNMUYORDU HEM DE YANLIŞ AİLEDENDİ.
  // Ölçüm:
  //     muted #6B7280 → sayfa 4.48 · blok 4.28   ✗ AA YOK   ton 220° MAVİ
  //     dim   #9CA3AF → sayfa 2.35 · blok 2.25   ✗✗         ton 218° MAVİ
  // Kullanım: `C.mut` METİN rengi olarak 219 yerde, `C.dim` 33 yerde
  // (+28 placeholder). Yani uygulamanın ikincil metninin BÜYÜK ÇOĞUNLUĞU
  // AA'nın altındaydı ve kimse görmüyordu, çünkü hiçbir denetim satır içi
  // metin renklerine bakmıyordu.
  //
  // v2.65'te `mutedAA` ve `dimAA` okunur karşılıkları eklenmiş ama ESKİ
  // adlar bırakılmıştı — ve 279 çağrı yeri eski adları kullanmaya devam
  // etti. Okunur bir alternatif eklemek, okunmayanı kaldırmaz.
  //
  // 🆕 SINIF: "BİR TOKENİN DOĞRUSUNU YANINA EKLEMEK YANLIŞINI EMEKLİYE
  // AYIRMAZ — ESKİ AD DURDUĞU SÜRECE KOD ONU KULLANMAYA DEVAM EDER."
  //
  // Kenarlık/zemin olarak hiç kullanılmadıkları ölçüldü (border 1, bg 0),
  // yani değerlerini değiştirmek yalnız METNİ etkiliyor.
  muted:  "#745E47",   // cMT · sıcak nötr · sayfa 5.66 · kart 6.02 · blok 5.42
  dim:    "#7C644C",   // cDM · sıcak nötr · sayfa 5.14 · kart 5.46 · blok 4.92
  ink:    "#251E17",   // cIK · v3.1 sıcak nötr (eski #1A1F2E ton 225° maviydi) · sayfa 15.23 · kart 16.19 · doku 13.51
  body:   "#4D3E2F",   // cBY · v3.1 sıcak nötr (eski #374151) · sayfa 9.56 · kart 10.16 · doku 8.43
  bgAlt:  "#F0EDE6",   // cBL — kart ici blok
  card:   "#FFFFFF",   // cBM
  bg:     "#F8F6F1",   // cBG — sayfa zemini
  teal:   "#0D9488",   // cTL
  green:  "#059669",   // cGR
  red:    "#E11D48",   // cRS
  purple: "#7C3AED",   // cPP
  avatarBg: "#F0EDE6",  // açık temada avatar diski (arşivde; taban değer)
  camIz: "rgba(0,0,0,0.03)",  // açık temada cam izi (taban değer)
  balonBen: "#FAF6EC",        // açık temada kendi balonum (taban değer)
  amber:  "#D97706",   // cAM
  line:   "rgba(0,0,0,0.08)", // cLN

  // 🔴 v2.31 — LACIVERT KALDIRILDI.
  // v2.30'da kahraman alan icin lacivert eklemistim; Gokberk hakli
  // olarak "bizim ana temamizda lacivert-uzeri-altin yok" dedi ve
  // kontrol ettim: DOGRU, o renk app'te BASKA HICBIR YERDE gecmiyordu.
  // Tek ekran icin palete yeni bir zemin rengi sokmak, temayi bir
  // ekranda catallamaktir. Kahraman alan artik kendi sicak paletimizle
  // kuruluyor: krem zemin, altin vurgu, murekkep metin.
  // Kullanilmayan bir rengi palette birakmak da ileride ayni sapmaya
  // davetiye cikarir — o yuzden siliyorum, yorumda yasasin.

  // --- Yumusak zeminler (MVP: cGDBg, cTLBg, ...) ---
  goldBg:   "#FAF6EC",
  tealBg:   "#EDFAF8",
  greenBg:  "#ECFDF5",
  redBg:    "#FEF2F4",
  purpleBg: "#F5F1FE",
  amberBg:  "#FEF6EC",

  // --- Kenarliklar ---
  goldLine:   "rgba(184,148,58,0.30)",
  // `--altinIz` (0.13): öne çıkan kartın/kendi balonumun kenarı. ⚠️ `temaUygula`
  // yalnız ACIK'taki anahtarları taşır — burada yoksa KOYU'daki de C'ye geçmez
  // (ölçüldü: `C.goldTrace` undefined kalıyor, 0.28'lik `goldLine`a düşüyordu).
  goldTrace:  "rgba(184,148,58,0.13)",
  // 🔴 20 EYLÜL — SIZINTI JETONLARI. İki değer kodda ELLE yazılıydı ve
  // ikisi de paletin dışındaydı:
  //   · `rgba(224,190,122,0.03)` → #E0BE7A · C* 38.9. Bu, şampanya
  //     kararının (C* 40.2 → 20.4) reddettiği ÇİĞ altının ta kendisi.
  //   · `#2E3647` → hue 277°, menekşe-mavi. Sistem 73-88° sıcak.
  // Jetonlaştırıldılar; `tema_sizinti_check.py` geri gelmelerini engelliyor.
  altinIz03:  "rgba(184,148,58,0.03)",
  amberLine:  "rgba(217,119,6,0.30)",
  pasifRozet: "#E3DED4",
  tealLine:   "rgba(13,148,136,0.30)",
  purpleLine: "rgba(124,58,237,0.30)",
};

// Geriye donuk takma adlar — eski kod C.mut / C.paper / C.goldSoft kullaniyordu.
// Tek seferde hepsini degistirmek yerine kopru kuruyoruz; boylece bu tur
// bir yeniden yapilandirma sirasinda ekranlar bir anda bozulmuyor.
C.mut = C.muted;
C.paper = C.bg;
C.goldSoft = C.goldBg;

// ============================================================================
// 🔴 26 AĞUSTOS — MARKA ZORUNLU RENKLER (palet dışı ama UYDURMA DEĞİL)
//
// Palet denetimi haklı olarak "tek ekran için uydurulan renk, temayı o ekranda
// çatallar" diyor. Ama sosyal giriş düğmelerinin renkleri BİZİM SEÇİMİMİZ
// DEĞİL: Apple ve Google kendi giriş düğmeleri için tam renk kodu ve kontrast
// şartı koyuyor; uymamak mağaza incelemesinde geri dönüş sebebidir.
//
// Bu yüzden palete "istisna" olarak değil, ADI VE GEREKÇESİYLE giriyorlar.
// 🆕 SINIF: "BİR KURALIN İSTİSNASI GEREKÇESİYLE ADLANDIRILMAZSA, BİR SONRAKİ
// KİŞİ ONU KURALIN KENDİSİ SANIR."
// ============================================================================
C.brandApple      = "#000000";   // Apple Sign In — siyah düğme zemini (zorunlu)
C.brandAppleInk   = "#1F1F1F";   // Apple/Google beyaz düğme üzerindeki metin
C.brandGoogle     = "#4285F4";   // Google marka mavisi (zorunlu)

export const F = {
  // MVP: Cormorant Garamond. iOS'ta Georgia en yakin sistem serif'i.
  // Android'de "Georgia" YOK — bilinmeyen fontFamily sessizce Roboto'ya
  // (sans) duser; bu yuzden serif basliklar hic gorunmuyordu. Android'in
  // "serif" takma adi Noto Serif'e cozunur ve MVP'nin gorunumunu verir.
  // v1.30: GERCEK Cormorant Garamond artik app'e gomulu (assets/fonts,
  // expo-font config plugin, OFL lisansli). Build oncesi `npx expo install
  // expo-font` sart. Basliklar sans'a donerse plugin calismamis demektir —
  // acil geri donus: bu satiri Platform.OS==="android"?"serif":"Georgia" yap.
  serif: "CormorantGaramond-Bold",
  // ══════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS — SEVK EDİLEN İKİ SERİF DOSYASI DA "LIGHT"MIŞ.
  //
  // Gece sistemindeki `.an-h1` ve `.ust-h1.serif` Cormorant **300**
  // istiyor; bizde yalnız `-Bold` ve `-SemiBold` vardı. Light'ı
  // eklerken elimdeki iki dosyayı da açıp ölçtüm:
  //
  //   CormorantGaramond-Bold.ttf      fvar: VAR   usWeightClass: 300
  //   CormorantGaramond-SemiBold.ttf  fvar: VAR   usWeightClass: 300
  //   (ikisi de 1.197.732 bayt — aynı DEĞİŞKEN fontun iki kopyası)
  //
  // Yani ikisi de statik bir kesit değil, DEĞİŞKEN fontun kendisiydi
  // ve varsayılan kesiti 300. React Native `Text` bir varyasyon ekseni
  // seçemez; her zaman varsayılanı çizer. Sonuç: uygulamadaki her
  // "kalın serif başlık" aslında AYNI İNCE kesitle çiziliyordu ve
  // yanındaki `fontWeight:"700"` ya hiç iş görmüyor ya da platforma
  // göre sahte kalınlaştırma yapıyordu — yani iOS ile Android farklı.
  //
  // Dosya adı doğruydu, içerik değil. Hiçbir denetim bunu yakalayamazdı:
  // adına bakan her araç "Bold var" diyordu.
  //
  // 🆕 SINIF: **"BİR DOSYANIN ADI, İÇİNDEKİNİN KANITI DEĞİLDİR.
  // İSMİ DOĞRULAYAN TEK ŞEY DOSYAYI AÇIP ÖLÇMEKTİR — VE ADIYLA
  // KENDİNİ DOĞRULAYAN VARLIKLAR EN UZUN YAŞAYAN HATALARDIR."**
  //
  // Üçü de artık gerçek statik kesit (300/600/700), doğru
  // `usWeightClass` ile ve `fvar` tablosu olmadan. Yan kazanç:
  // 1.197.732 → ~773.000 bayt, üç dosyada toplam ~1.27 MB APK azalması.
  // Eskileri `arsiv/font_20260830/` altında duruyor.
  serifLight: "CormorantGaramond-Light",
  // 🔴 31 AĞUSTOS · 10. TUR — GÖSTERİM SERİFİ AYRI BİR AD ALDI.
  //
  // Gökberk: "tasarımdaki daha farklı bir font stili ve daha bold bir
  // havası var." Ölçtüm — ve sebebi tasarım dosyasının KENDİSİYDİ:
  // `tasarim_kaynak/yap.py` fontları Google'dan çekiyor, render
  // makinesinde o istek başarısız oluyor ve tarayıcı YEDEK serife
  // düşüyor. Yani onayladığı görüntüdeki harfler Cormorant DEĞİL.
  //     aynı kelimenin mürekkep yoğunluğu · referans 0.288
  //                                       · Cormorant 300  0.165
  //
  // Ailede kalarak en yakın karşılık 600. Aile değiştirmek bir MARKA
  // kararı ve Gökberk'in onayı olmadan alınmıyor; bu yüzden `serifLight`
  // silinmedi, gösterim için AYRI bir ad açıldı. Kararı verdiğinde
  // değişecek tek yer burası.
  //
  // 🆕 SINIF: "BİR REFERANSIN KENDİSİ DE ÖLÇÜLMELİ — ONAYLANAN ŞEY,
  // TASARIMIN NİYETİ DEĞİL, O GÜN EKRANDA ÇIKAN ŞEYDİR."
  serifGosterim: "CormorantGaramond-SemiBold",
  // 🔴 v2.73 — ARTIK undefined DEĞİL. Eskiden burası boştu ve bu,
  // "iOS'ta SF Pro / Android'de Roboto" demekti: uygulama iki
  // platformda iki farklı ritimde okunuyordu. Archivo gömüldü
  // (SIL OFL, Türkçe glifleri dört ağırlıkta da tam).
  //
  // ⚠️ Bunu doğrudan bir stile yazmak GENELDE GEREKMEZ: src/typography.js
  // `Text`/`TextInput` render'ini bir kez sarmalayip agirliga gore
  // dogru aileyi kendisi enjekte ediyor. Burasi, aileyi ACIKCA
  // istemen gereken nadir yerler icin duruyor.
  // ══════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS — GÖVDE AİLESİ ARCHIVO → PLUS JAKARTA SANS
  //
  // Gece sistemi kararı. Sebebi zevk değil ÖLÇÜ: Plus Jakarta Sans'ın
  // x-yüksekliği Archivo'dan belirgin yüksek. Bu ürün sarsıntılı
  // ortamda (servis aracı, yürüyen bant, ayakta kapı önü) ve koyu
  // zeminde okunuyor; koyu zeminde ince harf "yenir", yüksek gövdeli
  // harf ayakta kalır.
  //
  // ⚠️ ARCHIVO SİLİNMEDİ. Dosyalar `assets/fonts` altında duruyor ve
  // aşağıdaki `sansEski` ile hâlâ çağrılabilir. Bir aileyi paketten
  // çıkarmak geri dönüşü olmayan bir karar; değiştirmek değil.
  //
  // 🆕 SINIF: "BİR AİLEYİ DEĞİŞTİRİRKEN ESKİSİNİ SİLMEK, KARARI
  // GERİ ALINAMAZ YAPAR — DEĞİŞTİR, KALDIRMA."
  sans: "PlusJakartaSans-Regular",
  sansMedium: "PlusJakartaSans-Medium",
  sansSemi: "PlusJakartaSans-SemiBold",
  sansBold: "PlusJakartaSans-Bold",

  // 🔴 SAYILAR AYRI AİLEDE — VE BU MEKANİK BİR ZORUNLULUK.
  // Geri sayım, uyum yüzdesi, kredi, saat. Orantılı bir fontta
  // `02:41:08` her saniye genişlik değiştirir ve satır ZIPLAR.
  // Tek genişlikli aile bunu imkânsız kılar.
  mono: "JetBrainsMono-Medium",
  monoSemi: "JetBrainsMono-SemiBold",

  // Eski aile — geri dönüş yolu açık dursun.
  sansEski: "Archivo-Regular",
  sansEskiMedium: "Archivo-Medium",
  sansEskiSemi: "Archivo-SemiBold",
  sansEskiBold: "Archivo-Bold",
};

// Rol/baglam -> renk. MVP'nin anlam haritasi.
export const ACCENT = {
  trip:      C.teal,     // seyahat, host bulma, musaitlik
  meet:      C.purple,   // tanis, companion, networking
  points:    C.gold,     // LoungePuan, marketplace, plan
  success:   C.green,    // aktif, onaylandi, tamamlandi
  warn:      C.amber,    // dikkat cek ama engelleme
  danger:    C.red,      // hata, sil, SOS
};

// ============================================================
// v1.89 — TİPOGRAFİ VE BOŞLUK ÖLÇEĞİ
//
// 🔴 NEDEN: 20+ ekranda fontSize elle yazılıyordu — 10, 10.5, 11.5, 12,
// 12.5, 13, 14, 15, 16... Aralar da öyle. Sonuç: hiçbir ekran "bozuk"
// görünmüyor ama hiçbiri de öbürüyle aynı ritimde değil. Kullanıcı bunu
// "amatör" diye adlandırmaz, sadece güven duymaz.
//
// Ölçek beşe indi. Yeni bir boyut gerekirse ölçeğe EKLENİR, ara değer
// uydurulmaz — kural bu.
// ============================================================
export const T = {
  xs:    { fontSize: 10.5,   lineHeight: 16 },   // yardımcı metin, rozet
  sm:    { fontSize: 12.5, lineHeight: 18 },   // ikincil satır
  base:  { fontSize: 14,   lineHeight: 20 },   // gövde
  lg:    { fontSize: 16,   lineHeight: 22 },   // vurgulu satır, buton
  title: { fontSize: 20,   lineHeight: 26 },   // ekran başlığı
  // ETİKET: büyük harf + harf aralığı. Tek yerde tanımlı ki 1.5 / 1.2 / 1
  // diye üç farklı aralık dolaşmasın.
  label: { fontSize: 10.5, letterSpacing: 1.2, fontWeight: "600" },

  // ══════════════════════════════════════════════════════════════════
  // 🔴 v3.6 — ÖLÇEK 20'DE BİTİYORDU AMA UYGULAMA 44'E KADAR ÇIKIYORDU.
  //
  // Denetimde sayıldı: `fontSize: 26` 19 kez, `34` 8 kez, `44` 7 kez —
  // toplam 34 kullanım, hepsi ÖLÇEĞİN DIŞINDA. Ölçek 20'de bittiği için
  // her kahraman sayı, her boş-durum başlığı, her fotoğraflı bant
  // KENDİ boyutunu uyduruyordu.
  //
  // Bir ölçeğin dışında kalan kullanım "kural ihlali" değildir; ölçeğin
  // EKSİK olduğunun kanıtıdır. 34 kullanım bir istisna değil, bir
  // KATMANDIR — ve adı olmayan bir katman her çağrı yerinde yeniden
  // pazarlık edilir.
  //
  // 🆕 SINIF: "BİR ÖLÇEĞİN SÜREKLİ DIŞINA ÇIKILIYORSA SORUN UYANLARDA
  // DEĞİL ÖLÇEKTEDİR — TEKRAR EDEN HER İSTİSNA, İSİMLENDİRİLMEMİŞ BİR
  // BASAMAKTIR."
  //
  // Üç basamak, üç iş:
  //   display → kart içi kahraman sayı (LoungePuan, güven skoru)
  //   hero    → tam ekran an (buluşma, kutlama, boş durum ikonu)
  //   bant    → fotoğraflı başlık bandının iri serif başlığı
  display: { fontSize: 26, lineHeight: 32 },
  hero:    { fontSize: 34, lineHeight: 40 },
  // 🔴 30 AĞUSTOS · 6. TUR — 44 DEĞİL 40. TASARIM ÖLÇÜLDÜ.
  //   .ust-h1{ font-size:40px; letter-spacing:-.028em; line-height:1.04 }
  // 44'ü nereden aldığımı bulamadım — tasarımdan almadım. Bandın en
  // büyük metni olduğu için o 4px başlığın altındaki HER ŞEYİ aşağı
  // itiyordu: Gökberk "keşfette kalkışına X saat X dakika textinin
  // konumu" derken tam bunu gösteriyordu. Alt bilgi yanlış yerde
  // değildi; ÜSTÜNDEKİ BAŞLIK fazla yer kaplıyordu.
  //
  // 🆕 SINIF: "BİR ÖĞENİN YERİ YANLIŞSA ÖNCE ONU DEĞİL, ÜSTÜNDEKİNİN
  // BOYUNU ÖLÇ — DİKEY AKIŞTA HER HATA AŞAĞIYA MİRAS KALIR."
  bant:    { fontSize: 40, lineHeight: 42 },

  // 🔴 ANA SAYFADAKİ İSİM AYRI BİR BASAMAK: `.ust-h1.serif` 52px.
  // Tasarımda serif başlığın kendi boyu var ve `.an-h1`den (46) BÜYÜK.
  // Ben ikisini de 46 çizmiştim; karşılaştırma görselinde "Gökberk"
  // tasarımdakinden gözle görülür biçimde küçük duruyordu.
  // Serif bu sistemde "insan"ın ailesi — ve insanın adı, o ekrandaki
  // en büyük şeydir.
  isim:    { fontSize: 52, lineHeight: 55 },
  // 🔴 30 Ağustos · Gece sistemi — `.an-h1` 46px. `hero` (34) ile
  //   `bant` (44) arasında değil, ikisinin de ÜSTÜNDE bir basamak:
  //   "an" ekranı bir başlık değil bir SAHNE ve orada tek bir cümle
  //   var. Sayfada rekabet etmediği için daha büyük olabilir.
  anBaslik:{ fontSize: 46, lineHeight: 49 },

  // 🔴 VE ÖLÇEĞİN ALTINDA DA BİR KATMAN VARDI: `fontSize: 9` 34 kez.
  // Rozet sayacı, sekme etiketi, çip üstü mikro bilgi. `T.xs` (10.5)
  // bu iş için fazla iri geldiği her yerde 9 uyduruldu. Adı olsun ki
  // 8 ya da 9.5 diye dördüncü bir değer doğmasın.
  //
  // ⚠️ 9 px ERİŞİLEBİLİRLİK SINIRINDA: yalnız SAYI ve KISA ETİKET için.
  // Cümle taşıyan hiçbir yerde kullanılmamalı — `tip_check.py` bunu
  // ayrıca ölçüyor.
  micro: { fontSize: 9, lineHeight: 12, fontWeight: "700" },
};

// ══════════════════════════════════════════════════════════════════════
// 🔴 v3.6 — `T` BİR NESNE OLDUĞU İÇİN `fontSize:` SATIRLARI ONU
// KULLANAMIYORDU.
//
// `T.sm` = `{ fontSize, lineHeight }`. Bir stilde yalnız boyut gerektiğinde
// (`fontSize: 12.5`) `T`yi çağırmanın yolu yoktu — `T.sm.fontSize` yazmak
// mümkün ama kimse yazmadı. Ölçüm: 1117 ham `fontSize`, 43 `T.*`.
//
// Yani ölçek vardı ve KULLANILAMIYORDU. Bir tokenı kullanmak, onu elle
// yazmaktan daha zorsa, elle yazılır.
//
// 🆕 SINIF: "BİR TOKENI KULLANMAK HAM DEĞERİ YAZMAKTAN ZORSA, O TOKEN
// KULLANILMAZ — BENİMSEMEYİ DİSİPLİN DEĞİL ERGONOMİ BELİRLER."
//
// `FS` aynı ölçeğin skaler hâli. `T`den TÜRETİLİYOR: iki yerde iki farklı
// sayı olması imkânsız.
// ════════════════════════════════════════════════════════════════════
// SATIR — KIRPILMAYAN EN KÜÇÜK SATIR YÜKSEKLİĞİ  (12 Eylül · Gökberk md.5)
//
// 🔴 NEDEN VAR: "bağlantılarım başlığı headerda kesik gibi alttan
// (bunu app genelinde kontrol et başlığın alttan kesik olması)".
// Haklıydı ve sebebi tek bir sayıydı: `bant` satır yüksekliği 42,
// punto 40 — yani 1.04. Tasarımın CSS'inde `line-height:1.04` yazıyor
// ve ben onu BİREBİR almıştım. Tarayıcıda 1.04 kırpMAZ (taşan inici
// harf sadece taşar); React Native'de ve `numberOfLines` KLAMPLI bir
// kutuda KIRPAR. Aynı sayı iki motorda iki farklı şey demek.
//
// ÖLÇÜM (fonttools, assets/fonts içindeki ttf'ler · em=1000):
// ⚠️ Bu satırda bir zamanlar "fonts/" ardından yıldız-nokta-ttf yazıyordu.
// O iki karakter JS'te BLOK YORUM AÇIYOR: `tema_check.py` dosyanın geri
// kalanını yorum sanıp C.badgeInk ve kurYuzey()'i bulamadı ve "denetim
// körleşti" dedi. Nöbetçi doğru davrandı — sessizce geçmedi.
// 🆕 SINIF: "BİR YORUM SATIRI KODU BOZMAZ AMA KODU OKUYAN NÖBETÇİYİ
// KÖRLEŞTİREBİLİR; DOSYA ARTIK YALNIZ DERLEYİCİNİN DEĞİL DENETİMİN DE
// GİRDİSİDİR."
//   Plus Jakarta Sans : hheaAsc 1038 · hheaDesc −222 · en alçak glif ç/ş −237
//   Cormorant Garamond: hheaAsc  924 · hheaDesc −287 · en alçak glif ğ  −282
//   JetBrains Mono    : hheaAsc 1020 · hheaDesc −300 · en alçak glif ç  −213
// Satır kutusunda taban çizgisi (L−(A+D))/2 + A noktasındadır; tabanın
// ALTINDA kalan yer L/2 − (A−D)/2 olur. Kırpılmaması için:
//      L ≥ 2·|ymin| + A − D     ve     L ≥ 2·ymax − A + D
//   Jakarta   → 1.290 em   (Bağlantılarım'ın ğ'si 40 puntoda 4.1 px kesiliyordu)
//   Cormorant → 1.201 em
//   Mono      → 1.180 em
//
// 🆕 SINIF: "TASARIMDAN ALINAN BİR SAYI, ALINDIĞI MOTORUN KURALIYLA
// BİRLİKTE GELİR — CSS'TEN KOPYALANAN `line-height` BAŞKA BİR MOTORDA
// AYNI ŞEYİ YAPMAZ."
export const SATIR_ORAN = { sans: 1.29, serif: 1.201, mono: 1.182 };
export function SATIR(fs, aile = "sans") {
  return Math.ceil(fs * (SATIR_ORAN[aile] || SATIR_ORAN.sans));
}

export const FS = {
  micro:   T.micro.fontSize,     //  9   — rozet sayacı, sekme etiketi
  xs:      T.xs.fontSize,        // 10.5 — yardımcı metin, rozet
  sm:      T.sm.fontSize,        // 12.5 — ikincil satır (en sık)
  base:    T.base.fontSize,      // 14   — gövde
  lg:      T.lg.fontSize,        // 16   — vurgulu satır
  title:   T.title.fontSize,     // 20   — ekran başlığı
  display: T.display.fontSize,   // 26   — kart içi kahraman sayı
  hero:    T.hero.fontSize,      // 34   — tam ekran an
  bant:    T.bant.fontSize,      // 40   — bant başlığı (.ust-h1)
  isim:    T.isim.fontSize,      // 52   — ana sayfadaki İSİM (.ust-h1.serif)
  anBaslik:T.anBaslik.fontSize,  // 46   — "an" ekranının tek cümlesi
};

// 4'ün katları. "13 padding" gibi ara değerler ritmi bozuyordu.
export const SP = { 1: 4, 2: 8, 3: 12, 4: 16, 5: 24, 6: 32 };

// ════════════════════════════════════════════════════════════════════
// ARA — 2'NİN KATLARI (ara basamaklar)
//
// 🔴 v3.6 — "776 IZGARA DIŞI BOŞLUK" ÖLÇÜMÜ YANLIŞ ETİKETLENMİŞTİ.
//
// `token_check.py` SP dışındaki her boşluğu "ham" sayıyordu ve rakam
// 776'ydı. Ama `palette_check.py`in ritim kuralına bakınca iş değişti:
// orada 2·6·10·14·18·22·26·30 zaten AÇIKÇA meşru sayılıyor. Yani ürün
// 4'lük değil 2'LİK bir ızgarada kurulmuş; iki denetim aynı şeye iki
// farklı isim veriyordu.
//
// Sayınca netleşti: 851 ham değerden 841'i 2'nin katı. Gerçek aykırı
// yalnız 10 tane (3·9·11·13). Yani "776 ihlal" diye raporladığım şey,
// büyük ölçüde ÖLÇEĞİN EKSİK OLMASIYDI — kodun bozukluğu değil.
//
// 🆕 SINIF: "BİR ÖLÇEĞİ 800 KULLANIM İHLAL EDİYORSA İHLAL EDEN KOD
// DEĞİL, ÜRÜNÜ TARİF ETMEYEN ÖLÇEKTİR."
//
// Neden değeriyle anahtarlanıyor (`ARA[10]`): amaç yeniden adlandırmak
// değil, KÜMEYİ KAPATMAK. `ARA[13]` yazmak derleme hatası değil ama
// `undefined` döner ve denetim yakalar — yani yeni bir aykırı değer
// sessizce içeri giremez.
//
// ⚠️ SP'nin 1–6 anahtarları DEĞİŞTİRİLMEDİ. `SP[5]`i 24'ten 20'ye çekip
// ölçeği "düzeltmek" 965 çağrı yerini sessizce kaydırırdı — ölçeği
// düzeltirken ürünü bozmak.
// 🔴 30 AĞUSTOS — ÖLÇEKTE OLMAYAN DÖRT BASAMAK ÖLÇÜLDÜ.
// Kümenin kapalı olması amaçtı ve işe yaradı: `ARA[4]` yazan 13 çağrı
// yeri `undefined` döndürüyordu — yani o boşluklar EKRANDA HİÇ YOKTU
// ve kimse fark etmemişti (`undefined` bir stil değeri hata vermez,
// sessizce düşer). Saydım: 3(×1) 4(×9) 8(×1) 12(×1) 13(×1).
// Bunların dokuzu benim son iki turda yazdıklarım.
//
// 🆕 SINIF: **"KAPALI BİR KÜME YALNIZCA İHLALİ GÖRÜLÜR KILDIĞINDA
// KORUR; SESSİZCE `undefined` DÖNEN BİR KÜME KORUMAZ, GİZLER."**
//
// Basamakları uyduramam da — tasarımın kendi ölçüleri bunlar
// (kart-mert 3, uyum etiketi 4, rozet aralığı 8, ipucu 12). Ölçek
// ürünü tarif etmiyorsa değişmesi gereken ölçektir.
export const ARA = {
  2: 2, 3: 3, 4: 4, 6: 6, 8: 8, 10: 10, 12: 12, 14: 14, 18: 18, 20: 20, 22: 22,
  26: 26, 28: 28, 30: 30, 34: 34, 36: 36, 38: 38, 40: 40, 44: 44,
  // 🔴 20 EYLÜL — AÇILIŞ EKRANI BASAMAKLARI. İkisi de ÖLÇÜLDÜ, seçilmedi:
  //   64 → kanadın MERKEZİ 341pt'e otursun (blok 253.2pt'te başlıyor,
  //        kanat 96×47.3pt → üst kenar 317.7 → 317.7 − 253.2 = 64.5)
  //   92 → kanadın altı 365pt, slogan 458pt'te DURUYOR (gerçek render
  //        karesinde ölçüldü) → 93; ızgara 2'nin katı olduğu için 92.
  // Marka kelimesi ortadan kalkarken sloganın YERİNDEN OYNAMAMASI
  // gerekiyordu: değişen tek şey işaretin kendisi olsun.
  64: 64, 92: 92,
};

// Yükseklik. Kartların hepsi 1px çizgiyle ayrılıyordu; bu, ekranı
// "tablo" gibi gösteriyor. Hafif gölge kartı yüzeyden ayırıyor ve
// dokunulabilir olduğunu söylüyor — RN'de iki platformda ayrı yazılır.
export const ELEV = {
  card: {
    shadowColor: "#1A1F2E", shadowOpacity: 0.05, shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 }, elevation: 1,
  },
  raised: {
    shadowColor: "#1A1F2E", shadowOpacity: 0.10, shadowRadius: 16,
    shadowOffset: { width: 0, height: 6 }, elevation: 4,
  },
};

// v1.89 — SICAKLIK. Palet "lüks fintech" varsayılanıydı: doğru ama soğuk.
// Gokberk daha davetkâr bir ton istedi. Marka çapaları (lacivert + altın)
// KORUNDU; değişen yalnız nötrler ve yüzeyler — krem tarafına birkaç
// derece kaydırıldı ve kartlara ayırt edici bir yüzey verildi.
C.surface   = "#FFFDF9";   // kart: saf beyaz değil, kremin bir tık üstü
C.surfaceAlt= "#F4F1E9";   // kart içi blok
C.warmLine  = "rgba(184,148,58,0.16)";  // altın tonlu ayraç — griden sıcak

// ============================================================
// ANLAM RENKLERİ (v2.31'de ADLANDIRILDI)
//
// 🔴 Bu renkler zaten kullanılıyordu — ama HER BİRİ ELLE, dosyanın
// içine gömülü hex olarak. 39 yerde. Palet denetimi yazınca ortaya
// çıktı: tema tanımı ile temanın GERÇEK hâli birbirinden ayrışmış.
//
// Muaf tutup görmezden gelmek kolaydı. Ama muafiyet listesi, denetimi
// delmenin kibar hâlidir. Doğrusu: kullanılan her rengi ADLANDIRMAK.
// Adı olan renk yeniden kullanılabilir, aranabilir, değiştirilebilir;
// gömülü hex yalnız bulunduğu satırda yaşar.
// ============================================================
C.goldInk    = "#6B5518";   // altın zemin üzerine koyu altın metin
C.goldLine   = "#E4D5AE";   // altın kutu kenarı
C.goldTint   = "#FDF3E7";   // en açık altın zemin
C.goldDeep   = "#B3701E";   // vurgulu altın metin (ikinci kademe)
C.redInk     = "#9B2C2C";   // kırmızı zemin üzerine koyu kırmızı metin
C.tealTint   = "#E6F4F1";   // açık teal zemin
C.tealTint2  = "#E2F1EE";   // teal zemin, bir tık koyu
C.warmGray   = "#CFC9B8";   // pasif/kapalı durum
C.warmGray2  = "#D6D1C4";   // anahtar kapalı yolu

// ── ANAHTAR (Toggle) SAHNESİ · 30 Ağustos ────────────────────────────
// Anahtar artık pist→gökyüzü anlatıyor (bkz. src/ui.js Toggle). Bu dört
// renk o sahnenin malzemesi ve MARKA PALETİNİN PARÇASI — satır içine
// yazılmış "sihirli" hex değil.
//
// 🔴 İlk yazımda dördünü de bileşenin içine hex olarak koydum ve palet
// nöbetçisi altısını birden kırmızıya boyadı. Nöbetçi haklıydı: satır içi
// bir renk, tema değiştiğinde kimsenin bulamayacağı bir renktir.
// 🆕 SINIF: "BİR RENGİ BİLEŞENİN İÇİNE YAZMAK, ONU TEMADAN GİZLEMEKTİR."
C.pistAsfalt = "#9AA0A6";   // kapalı: asfalt
C.pistIsik   = "#F5D97A";   // kapalı: kenar ışıkları
C.gokMavi    = "#AFCDE4";   // açık: gökyüzü
C.pistUcak   = "#6E7A85";   // topuzdaki uçak mürekkebi
C.warmBlock  = "#F2F0EA";   // sıcak blok zemin
C.warmBlock2 = "#EDEAE0";   // sıcak blok, bir tık koyu
C.warmBlock3 = "#ECE9DF";   // sıcak blok, en koyu
C.coolLine   = "#C9CFDA";   // soğuk ayraç (nötr bağlam)
C.inkSoft   = "#2E3647";   // gövde başlığı: saf siyaha kaçmayan lacivert

// ════════════════════════════════════════════════════════════════════
// GECE YÜZEYİ — `C.ink`in ikinci işi buradan ayrıldı.
//
// 🔴 ÖLÇÜM: kodda 7 yerde `backgroundColor: C.ink` vardı — ödül kartı,
// radar kartı, toast, Moment ekranı, splash zemini. Bunlar mürekkep
// DEĞİL, kasıtlı koyu yüzeyler: açık temanın içindeki gece adaları.
//
// Aynı token iki iş yapınca tema değiştiğinde ikisinden biri bozulur:
// koyu temada `C.ink` açık bir renge dönüyor, yani anahtar konsaydı bu
// 7 yüzey bembeyaz olur ve üstlerindeki beyaz metin kaybolurdu.
// Değer AYNI (#251E17) — değişen yalnız ADI, yani ROLÜ. Açık temada
// hiçbir piksel değişmiyor; koyu temada artık ayrı yönetiliyor.
//
// 🆕 SINIF: "BİR TOKENİN İKİ İŞTE KULLANILMASI, TEMA DEĞİŞTİĞİNDE
// İKİSİNDEN BİRİNİN BOZULACAĞI ANLAMINA GELİR — ROL AYRIŞMADIYSA
// TOKEN AYRIŞMAMIŞTIR."
// ════════════════════════════════════════════════════════════════════
C.gece      = "#251E17";   // kasıtlı koyu yüzey (açık temada = C.ink değeri)
// `S.err` bu değeri satır içinde taşıyordu (#FBEAE9): temanın dışında
// kalan tek kutu oydu. Token oldu ki koyu temada da bir karşılığı olsun.
C.hataBg    = "#FBEAE9";   // hata kutusu zemini · C.redInk ile 6.28:1
C.hataLine  = "#F2C9C9";   // hata kutusu kenarı
// Modal perdesi: `rgba(26,31,46,0.55)` ve `rgba(20,24,35,0.55)` diye İKİ
// ayrı yerde yazılıydı ve ikisi de v2.31'de kaldırılan LACİVERT paletten
// kalmaydı — kaldırılan bir renk, iki modalın arkasında yaşamaya devam
// etmişti. Tek token, sıcak mürekkep tonunda.
C.perde     = "rgba(26,20,16,0.55)";   // modal arkası

// ============================================================
// 🔴 v2.65 — OKUNABİLİRLİK KATMANI (WCAG AA)
//
// Ölçtük: C.gold (#B8943A) üzerine beyaz metin = 2.86:1. AA metin
// için 4.5 gerekiyor. 70 CTA ve 199 metin bu orandaydı. Altın
// İŞARET rengi olarak DEĞİŞMEZ (marka çapası); ama METİN ve ZEMİN
// olarak kullanıldığında ikinci bir katman gerekiyor.
//
// Bu renkler altının aynı ailesinden, bir tık koyulaştırılmış:
// marka aynı kalıyor, metin okunuyor. Her satırın yanında ÖLÇÜLEN
// oran yazılı — "daha koyu görünüyor" bir gerekçe değildir.
// ============================================================
// 🔴 26 AĞUSTOS — v2.65'TE YANLIŞ ZEMİNDE ÖLÇÜLMÜŞ.
// Eski değer #8C702C ve yanındaki not "beyaz üzerinde 4.70:1" diyordu.
// Ölçüm doğruydu — ama bu renk BEYAZ üzerinde neredeyse hiç kullanılmıyor.
// Uygulamanın gerçek zeminleri krem: sayfa #F8F6F1, altın kutu #FAF6EC,
// altın tint #FDF3E7. Oralarda değer 4.35 / 4.35 / 4.29 — hepsi AA ALTINDA.
//
// Yani "geçiyor" diye kaydettiğim bir renk, kullanıldığı HİÇBİR yerde
// geçmiyordu. Yeni değer beş zeminin BEŞİNDE de ölçüldü.
//
// 🆕 SINIF: "BİR METİN RENGİNİ BEYAZDA ÖLÇÜP GEÇTİ SAYMAK, O RENGİN
// KULLANILDIĞI ZEMİNİ HİÇ ÖLÇMEMEKTİR — KREM BİR ARAYÜZDE BEYAZ,
// EN İYİMSER ZEMİNDİR."
// 🔴 v3.1 — ATMOSFER DOKUSU ZEMİNİ DEĞİŞTİRDİ, TOKEN DE DEĞİŞTİ.
// #866C2A temiz sayfada 4.64 idi; dokunun ufuk bandının en koyu noktasında
// 4.11'e düşüyor (ÖLÇÜLDÜ: doku_check.py). Arka plan koyduysan artık
// "sayfa zemini" diye tek bir renk yoktur — EN KÖTÜ zemin vardır.
C.goldText = "#7F6523";   // doku ufku 4.55 · bulut 5.23 · temiz sayfa 5.13 · kart 5.46
C.goldBtn  = "#846A2A";   // beyaz metinle 5.15:1 — ana CTA zemini
C.tealBtn  = "#0A6E65";   // beyaz metinle 6.12:1
C.greenBtn = "#047857";   // beyaz metinle 5.48:1
C.amberInk = "#9A5303";   // amberBg üzerinde 5.43:1 — uyarı metni
// ═══════════════════════════════════════════════════════════════════════
// 🔴 v3.1 — MÜREKKEP AİLESİ MAVİYDİ, SAYFA SICAKTI. ÖLÇÜLDÜ:
//     ink #1A1F2E → ton 225°   ·  sayfa #F8F6F1 → ton 43°
//     body 217°   ·  mutedAA 222°  ·  dimAA 219°
// Yani metnin TAMAMI mavi ailesinden, zemin ise kehribar. Gökberk
// "her şey yeni temaya uysun" derken hissettiği şey buydu; ben rozetleri
// ve düğmeleri düzeltip METNİ hiç sormamıştım.
//
// Koyu tema bu hatayı taşımıyordu (ink 35°, body 34°) çünkü onu fotoğrafa
// BAKARAK kurmuştum. Açık tema ise MVP'den miras kalmıştı ve kimse ona
// "bu palet hangi dünyaya ait?" diye sormamıştı.
//
// 🆕 SINIF: "BİR TEMAYI PARÇA PARÇA SICAKLAŞTIRIRSAN EN SON BAKTIĞIN YER
// METİN OLUR — OYSA EKRANIN ÇOĞU METİNDİR."
//
// Yeni değerler tahmin değil: her rengin PARLAKLIĞI sabit tutuldu (yani
// kontrast birebir korundu), yalnız TON kehribar ailesine taşındı. Beş
// zeminde ölçüldü: sayfa · kart · blok · doku ufku · doku bulutu.
// ═══════════════════════════════════════════════════════════════════════
C.mutedAA  = "#745E47";   // sıcak nötr · sayfa 5.65 · kart 6.01 · blok 5.41 · doku 5.02
// 🔴 26 AĞUSTOS — "BİR TIK ALTINDA" DİYE KAYITLI BİR BORÇ, YİNE BORÇTUR.
// Eski değer #6E7686 ve yanındaki not "4.23 — eşiğin bir tık altında,
// yalnız ipucu metni için" diyordu. Ama iç sayfa çizimini yaparken
// ölçüldü: bu renk KONUM SATIRINDA kullanılıyor ("Dış Hat · Terminal A")
// ve orası ipucu değil, İÇERİK. Üç zeminde de düşük: sayfa 4.23,
// kart 4.49, blok 4.05.
//
// Bir istisnayı yorumda kayıt altına almak, onu kuralın dışına çıkarmaz;
// yalnızca bilerek yapıldığını gösterir. Ölçülebilir olduğu için de
// düzeltilebilir: %7 açıklık düşürüldü, üç zeminde de geçiyor.
//
// 🆕 SINIF: "BİR EŞİĞİN 'BİR TIK ALTI' DİYE YAZILAN İSTİSNA, ER GEÇ
// İÇERİK METNİNDE KULLANILIR — İSTİSNAYI YAZMAK YERİNE KAPAT."
C.dimAA    = "#7C644C";   // sıcak nötr · sayfa 5.11 · kart 5.43 · blok 4.89 · doku 4.56

// ============================================================
// 🔴 v2.65 — DOKUNMA HEDEFİ
// Apple HIG 44pt, Material 48dp. Uygulamada ikon butonları ≈21px
// yüksekliğindeydi (genişlik verilmiş, yükseklik unutulmuş).
// Tek kaynak: elle 44 yazmak yerine TAP.minHeight kullanılır.
// ============================================================
export const TAP = {
  minHeight: 44,
  minWidth: 44,
  // 🔴 v2.74 — DOKUNMA PAYI. 119 dokunulabilir alan 44px'in altındaydı
  // ve hepsine `minHeight: 44` vermek DÜZENİ BOZARDI: satır içi bağlantı,
  // çip, küçük "▾" düğmesi — hepsi birden büyüyüp ritmi dağıtırdı.
  //
  // `hitSlop` tam bu iş için var: GÖRÜNEN kutuyu büyütmez, DOKUNULABİLİR
  // alanı büyütür. 12px, Apple HIG'in 44pt'sini 20px yükseklikteki bir
  // düğmede bile karşılar (20 + 12 + 12 = 44).
  //
  // Neden tek yerde: 119 çağrı noktasına elle sayı yazmak, yarın
  // değeri değiştirmek istediğimizde 119 yerde arama demekti.
  slop: { top: 12, bottom: 12, left: 12, right: 12 },
};

// ============================================================
// 🔴 MARKA_RUHU §10 — ROZET RENK SİSTEMİ
// ------------------------------------------------------------
// Rozet renkleri bugüne kadar tek tek, yazıldığı yerde seçildi:
// aynı anlam iki ekranda iki farklı renkle çıkabiliyordu. Renk
// dekorasyon değil BİLGİDİR; kullanıcı rengi okumayı öğrenir ve
// tutarsızlık o öğrenmeyi bozar.
//
// Beş anlam, beş renk — başka renk kullanılmaz:
//   ok      → hakkın var, kapı açık          (yeşil)
//   cost    → girebilirsin ama ücretli       (altın)
//   unknown → kartına göre değişir, teyit al (nötr/gri)
//   block   → bu koşulda mümkün değil        (kırmızı, YALNIZ gerçek engel)
//   info    → nötr bilgi (uçuş, saat, sayı)  (mürekkep/soluk)
//
// Kural: "block" cimri kullanılır. Kullanıcıya kapıyı kapatan renk
// yalnız gerçekten kapalıysa yanar; belirsizlik "unknown"dır.
// ============================================================
// ════════════════════════════════════════════════════════════════════
// 🔴 26 AĞUSTOS 2026 — ROZET METİNLERİ AA'DAN GEÇMİYORDU. DÖRDÜ DE.
//
// Gökberk keşif kartının ekran görüntüsünü işaretleyip "bunlar temayla
// uyumlu durmuyor" dedi. Gözüyle gördüğü şeyi ölçtüm ve haklıydı —
// ama sebep tema değil, KONTRASTTI:
//
//   ok      #059669  → 3.30:1   ✗
//   cost    #B8943A  → 2.52:1   ✗   ← en kötüsü
//   unknown #6B7280  → 4.21:1   ✗
//   block   #E11D48  → 4.02:1   ✗
//
// Rozet metni 8–10,5px, yani KÜÇÜK METİN: eşik 4,5:1, 3,0 değil.
// Dördü de altında. En kötü olanı `cost` — "girebilirsin ama ücretli"
// diyen rozet, yani KURAL MOTORUNUN CEVABI. Ürünün tek farkı orası.
//
// 🔴 NASIL KAÇTI: v2.65'te bir "okunabilirlik katmanı" kurmuştum
// (goldText, goldBtn, tealBtn, amberInk…) ve metinleri düzeltmiştim.
// Rozet sistemi ondan SONRA yazıldı ve `fg` alanına HAM palet renklerini
// aldı — kurduğum katmanı baştan atladı.
//
// 🆕 SINIF: "BİR DÜZELTME KATMANI KURDUKTAN SONRA YAZILAN HER YENİ
// BİLEŞEN, O KATMANI ATLAMAYA ADAYDIR — KATMANI KURMAK YETMEZ,
// SONRAKİLERİ ONA BAĞLAYAN BİR NÖBETÇİ GEREKİR." (bkz. tema_check.py)
//
// DÜZELTME YÖNTEMİ: renkleri değiştirmedim, YALNIZ AÇIKLIKLARINI
// düşürdüm. Ton ve doygunluk aynen duruyor — yani rengin ANLAMI
// (yeşil = hakkın var, altın = ücretli) hiç değişmedi, yalnız okunuyor.
// Her satırın yanında ölçülen oran yazılı; ikisi de kart (#FFFDF9) ve
// kart içi blok (#F4F1E9) zeminlerinde doğrulandı.
//
// ⚠️ `bg` ve `bd` DEĞİŞMEDİ: rozetin rengi uzaktan hâlâ aynı okunuyor,
// değişen yalnız üstündeki yazı.
// ════════════════════════════════════════════════════════════════════
C.badgeInk = {
  ok:      "#047552",   // kart 5.01:1 · blok 4.53:1   (açıklık −%22)
  cost:    "#7B6327",   // kart 5.05:1 · blok 4.61:1   (açıklık −%33)
  unknown: "#5F6572",   // kart 5.09:1 · blok 4.60:1   (açıklık −%11)
  block:   "#C4193F",   // kart 5.05:1 · blok 4.57:1   (açıklık −%13)
  info:    "#374151",   // kart 9.22:1 · blok 8.28:1   (zaten geçiyordu)
};

C.badge = {
  ok:      { fg: C.badgeInk.ok,      bg: "rgba(5,150,105,0.10)",   bd: "rgba(5,150,105,0.28)" },
  cost:    { fg: C.badgeInk.cost,    bg: "rgba(184,148,58,0.12)",  bd: "rgba(184,148,58,0.32)" },
  unknown: { fg: C.badgeInk.unknown, bg: "rgba(107,114,128,0.10)", bd: "rgba(107,114,128,0.24)" },
  block:   { fg: C.badgeInk.block,   bg: "rgba(225,29,72,0.09)",   bd: "rgba(225,29,72,0.26)" },
  info:    { fg: C.badgeInk.info,    bg: "rgba(26,31,46,0.05)",    bd: "rgba(26,31,46,0.10)" },
};

// ════════════════════════════════════════════════════════════════════
// KÖŞE ÖLÇEĞİ (26 Ağustos)
//
// 🔴 ÖLÇÜM: uygulamada **33 farklı `borderRadius`** kullanılıyordu
// (460 kullanım): 8, 9, 10, 11, 12, 13, 14, 16, 18, 20… Bunların çoğu
// gözle ayırt edilemez ama hepsi ayrı bir karar demek.
//
// Tipografi ölçeğe bağlıydı, boşluklar 4'ün katına bağlıydı — KÖŞELER
// hiçbir şeye bağlı değildi. Denetlenmeyen tek boyut, serbestçe kaymış
// olan boyut çıktı. Bu projede tam olarak beklenen sonuç.
//
// Beş basamak. Yeni bir köşe gerekiyorsa ölçeğe EKLENİR, ara değer
// uydurulmaz — `tema_check.py` bunu ölçüyor.
// ════════════════════════════════════════════════════════════════════
// 🔴 26 AĞUSTOS · İKİNCİ TUR — ÖLÇEK YUVARLATILDI.
// Gökberk: "alanları keskin dikdörtgen yapı yerine yeni tema ve
// backgrounda uygun daha oval hale getirebiliriz".
// Doğru: yeni zemin (gün batımı fotoğrafı + sıcak geçiş) yumuşak;
// onun üstünde 10–14px köşe sert duruyor. Rozet ve çipler artık HAP
// (tam yuvarlak) — bir rozet dikdörtgen olmak zorunda değil.
// 🔴 30 AĞUSTOS · GECE SİSTEMİ YARIÇAP ÖLÇEĞİ
// Eski ölçek 10/14/20/26/32 idi — her kademe "yumuşak". Koyu bir arayüzde
// büyük yarıçap yüzeyi şişirir ve premium değil oyuncak okunur. Yeni ölçek
// referans sistemin 12/14 ikilisi etrafında sıkıştırıldı.
// KART (16) düğmeden (12) DAHA yumuşak: yüzey davet eder, eylem keser.
export const R = {
  xs:   8,    // küçük etiket, minik gösterge
  sm:   12,   // giriş alanı, kart içi blok
  md:   12,   // düğme
  lg:   16,   // kart, kutu, uyarı
  xl:   22,   // modal, sayfa üstü yüzey, alt sayfa
  onay: 5,    // onay kutusu — daire DEĞİL yuvarlak kare (ürünün seçim dili)
  full: 999,  // rozet, çip, avatar, anahtar — HAP
};

// ════════════════════════════════════════════════════════════════════
// KOYU TEMA (26 Ağustos · Gökberk "A + koyu mod" seçti)
//
// 🔴 HER TOKEN AYRI ÖLÇÜLDÜ. Açık temada geçen bir oran koyu temada
// geçmiyor — bunu iki kez yaşadım: `dimAA` açık temada 4.23 çıktı,
// koyu karşılığı da 4.35 çıktı. İki palet, iki ayrı ölçüm.
//
// 🆕 SINIF: "KOYU TEMA, AÇIK TEMANIN TERSİ DEĞİLDİR — AYRI BİR
// PALETTİR VE AYRI ÖLÇÜLMESİ GEREKİR."
//
// Zeminler fotoğrafın kabin renginden türedi (sıcak nötr, saf gri değil).
export const KOYU = {
  // ── YÜZEY MERDİVENİ ──────────────────────────────────────────────
  // 🔴 v3.2 · İKİ ÖLÇÜLEBİLİR KUSUR BULDUM VE İKİSİ DE GÖZLE
  // GÖRÜLMÜYORDU ÇÜNKÜ KOYU TEMA HİÇ ÇİZİLMEMİŞTİ.
  //
  // 1 · TON. Açık temanın nötrleri 30–43° (sıcak amber): `ink` 30°,
  //     `bg` 43°. Koyu temanın YÜZEYLERİ ise 324–330° — yani MOR.
  //     Mürekkepler sıcak (27–35°), zeminler mor: koyu temada ürün
  //     kimliğini değiştiriyordu. Üstelik bu, v3.1'de açık temada
  //     düzeltilen kusurun (eski `ink` 225° maviydi) aynısı.
  //
  // 2 · MERDİVEN. Kart, sayfadan yalnız 1.13:1 ayrılıyordu — kart içi
  //     tonlu bloklar (1.45:1) karttan DAHA belirgindi. Yani yükseklik
  //     sırası tersine dönmüştü: iç blok dış kartın üstünde yüzüyordu.
  //
  // 🆕 SINIF: "BİR PALETİ ÇİZMEDEN ONAYLAMAK, BİR METNİ OKUMADAN
  // İMZALAMAKTIR — SAYILAR GEÇERKEN TON VE SIRA SESSİZCE KAYABİLİR."
  //
  // Yeni merdiven tek bir sıcak tondan (31°, %16 doygunluk) türedi:
  //     sayfa 1.00 → kart 1.32 → blok 1.62 → gece 1.95
  // ══════════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS — "GECE SİSTEMİ". PALET YENİDEN KURULDU.
  //
  // Gökberk onayladı: uygulama koyu zeminli bir gece arayüzüne geçiyor.
  // Rakip sistemin (LoungeSurf) lacivert #0B132B + sarı #FFBE0B ikilisi
  // ALINMADI — o onların markası ve elimizdeki gün batımı fotoğrafı
  // laciverte oturmuyor, sıcak.
  //
  // Yeni merdiven mor-siyah bir gece üstünde kuruldu: fotoğrafın sıcağı
  // bu tonun üstünde çakışmadan duruyor.
  //     sayfa #100E12 → kart #1C1820 → blok #241F28
  //
  // ⚠️ MERDİVEN ESKİSİNDEN SIK: eski kart sayfadan 1.32:1 ayrılıyordu ve
  // koyu bir arayüzde bu FAZLA — kartlar zeminden kopup "yüzüyor"du.
  // Gece sisteminde derinliği kontrast değil KENAR ÇİZGİSİ ve gölge
  // kuruyor; yüzey farkı yalnız bir ipucu.
  //
  // 🆕 SINIF: **"KOYU BİR ARAYÜZDE DERİNLİĞİ YÜZEY FARKI DEĞİL KENAR
  // KURAR — YÜZEYİ AÇARAK DERİNLİK ARAYAN HER KART, ZEMİNDEN KOPAR."**
  // 🔴 12 EYLÜL — OBSİDYEN. Gökberk: "düz mor/kahve siyah yerine
  // arkadaki uçak penceresi görseliyle eriyen derinliği olan bir zemin."
  // Teşhisi ÖLÇÜLDÜ ve doğru çıktı: eski #100E12'nin Lab hue açısı
  // **308°** — yani sayfa zemini MORDU, kroması C* 2.33. Fotoğraf sıcak
  // (gün batımı, kabin), zemin soğuk-mor: her bant kenarında ton çakışması.
  //
  // Yeni rampa nötr-sıcak: C* 2.33 → 0.51. Katman farkı da düştü:
  //     eski  sayfa→kart ΔE 6.24 · kart→blok ΔE 3.69
  //     yeni  sayfa→kart ΔE 3.02 · kart→blok ΔE 3.12
  // Yani kart artık sayfadan "kutu" gibi değil, IŞIK FARKI gibi ayrılıyor.
  //
  // 🆕 SINIF: "BİR ZEMİNİN NÖTR OLDUĞUNU GÖZLE ONAYLAYAMAZSIN —
  // NÖTRLÜK BİR HUE AÇISIDIR VE ANCAK ÖLÇÜLEREK BİLİNİR."
  bg:         "#0B0A0B",   // sayfa · obsidyen (hue 324° · C* 0.51)   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1877 (v6 katmanı)
  surface:    "#141211",   // kart  · sayfadan ΔE 3.02   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1878 (v6 katmanı)
  surfaceAlt: "#1B1816",   // kart içi blok · karttan ΔE 3.12   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1879 (v6 katmanı)
  ink:        "#F4EFE6",   // başlık · sayfa 17.26:1 · blok 15.42:1
  body:       "#D8D0C4",   // gövde · sayfa 12.93:1 · blok 11.56:1
  // 🔴 MERDİVENİ YÜKSELTMEK ÜÇ KADEMELİ METİN HİYERARŞİSİNİ EZDİ.
  // Blok zemini 1.13'ten 1.62'ye çıkınca `dimAA`nın AA'yı tutması için
  // açılması gerekti — ve `mutedAA` ile aynı değere (#AAA39C ↔ #AEA49C)
  // düştü. İki ad, tek renk: üç kademe ikiye iner, "ikincil" ile
  // "üçüncül" ayrımı kaybolurdu. İkisi de yeniden ölçüldü: blokta
  // 6.31 ↔ 4.55 — hem AA hem hiyerarşi duruyor.
  //
  // 🆕 SINIF: "BİR ZEMİNİ AÇMAK YALNIZ KONTRASTI DEĞİL, O ZEMİNDEKİ
  // KADEMELERİN ARASINDAKİ MESAFEYİ DE DEĞİŞTİRİR — HİYERARŞİ DE
  // ÖLÇÜLMESİ GEREKEN BİR ŞEYDİR."
  mutedAA:    "#A99D8C",   // ikincil satır · en kötü zemin 6.64:1
  // 🔴 #8B8071 ile başlamıştım; tema nöbetçisi blok zemininde 4.17:1
  // ölçüp kırmızı yandı (gereken 4.5). Ton korunarak açıldı: 4.52.
  dimAA:      "#8E8373",   // üçüncül · blok 4.75 · kart 5.02 · sayfa 5.31
  // 🔴 AYRAÇ ARTIK BİR RENK DEĞİL, BİR IŞIK SIZINTISI.
  // Eski `#54483C` koyu zeminde kalın gri bir çizgi çiziyordu — kartı
  // "kutu" gibi gösteriyordu. Gece sisteminde ayraç, altının çok düşük
  // opaklıkta bir izi: kenarı belli eder, kutu kurmaz.
  line:       "rgba(232,214,182,0.10)",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1948
  line2:      "rgba(232,214,182,0.17)",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1949
  // Marka altını (#B8943A) koyu zeminde OKUNMUYOR. Işığa doğru açıldı;
  // ton aynı, parlaklık farklı. Marka değişmedi, zemin değişti.
  // 🔴 12 EYLÜL — ŞAMPANYA. Gökberk: "çiğ altın sarısı lüks algısını
  // ucuzlatır." Ölçüldü: eski marka altını #D1B56D'nin kroması C* 40.2.
  // Karşılaştırma için: nötr grimiz C* 6, saf sarı 90+. Yani "altın"
  // değil DOYMUŞ SARI tarafındaydık.
  // Yeni değer AYNI IŞIKTA yarı kroma: L* 74.6 → 74.8, C* 40.2 → 20.4.
  // Işık aynı kaldığı için hiçbir kontrast ölçümü bozulmuyor; değişen
  // tek şey doygunluk.
  //
  // 🆕 SINIF: "BİR RENGİ 'YUMUŞATMAK' ONU KARARTMAK DEĞİLDİR —
  // AÇIKLIĞI SABİT TUTUP KROMAYI DÜŞÜRMEKTİR; KARARTIRSAN HİYERARŞİYİ
  // BOZAR, KROMAYI DÜŞÜRÜRSEN YALNIZ SESİNİ KISARSIN."
  gold:       "#D6C3A0",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1444
  goldText:   "#D6C3A0",
  goldBtn:    "#B49B70",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1299
  goldBtn2:   "#B49B70",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1300
  goldLine:   "rgba(214,195,160,0.28)",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1447
  goldBg:     "rgba(214,195,160,0.09)",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1312
  // 🔴 31 Ağu · 8. tur — "ÖNE ÇIKAN KART"IN ÇERÇEVESİ İKİ KAT PARLAKTI.
  // Tasarım `.kart.one{border-color:var(--altinIz)}` ve
  // `--altinIz:rgba(224,190,122,.13)`. Ben `goldLine`ı (0.28)
  // kullanıyordum. Aynı satırdan iki kareyi piksel piksel ölçtüm:
  //     tasarım (53,45,43)  ·  uygulama (119,99,45)
  // yani çizgi 2.2 kat parlaktı. Tasarımda "öne çıkan" bir FISILTI;
  // bende bir ÇERÇEVEYDİ — kart, listedeki diğerlerinden ayrılmıyor,
  // onlara "sen önemsizsin" diyordu.
  //
  // 🆕 SINIF: "VURGU BİR MİKTARDIR; DOĞRU RENGİ YANLIŞ ŞİDDETTE
  // KULLANMAK, YANLIŞ RENK KULLANMAKLA AYNI ŞEYİ BOZAR."
  goldTrace:  "rgba(214,195,160,0.13)",
  altinIz03:  "rgba(214,195,160,0.03)",
  // Koyu temada ham amber (#D97706 · C* 73) yerine paletin kendi
  // amberi (#FAA23C) %30 — aynı işlev, sistemin içinde.
  amberLine:  "rgba(250,162,60,0.30)",
  // Pasif rozet: eski `#2E3647` ile AYNI PARLAKLIK (L* 21.8 ↔ 22.6) —
  // görsel ağırlık değişmiyor — ama hue 277° yerine 73°, yani sistemin
  // içinde. Beyaz metinle 12.43:1.
  pasifRozet: "#3A332C",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1886 (v6 katmanı)
  // Tasarımın "cam izi" yüzeyi: `rgba(255,255,255,.03….035)`. Üç yerde
  // geçiyor (`.btn-cizgi`, `.cip`, `.sabit-serit`) ve üçünde de aynı
  // fikir: zemine değil, ÜSTÜNDEKİ IŞIĞA ait çok ince bir katman.
  // Ham yazıldığı her yerde tema nöbetçisi haklı olarak saydı.
  camIz:      "rgba(255,255,255,0.035)",
  // 🔴 31 AĞUSTOS · 9. TUR — KENDİ MESAJ BALONUMUN TONU.
  // Gökberk: "mesajın arka planındaki background tonu da tasarımda daha
  // iyi sanki." Ölçtüm, haklı ve fark ölçülebilir:
  //     tasarım (43, 37, 31)   ·   uygulama (44, 37, 20)
  // Kırmızı ve yeşil aynı, MAVİ 11 birim düşük — yani balon tasarımda
  // "sıcak taş", bende "hardal". Sebebi: tasarım
  // `linear-gradient(180deg, rgba(224,190,122,.17), rgba(224,190,122,.09))`
  // kullanıyor (ORTALAMASI %13), ben tek bir %9 katman koyuyordum.
  // Degrade tek renge indirildi: iki durağın ortası.
  //
  // 🆕 SINIF: "BİR DEGRADEYİ TEK RENGE İNDİRİRKEN UÇLARINDAN BİRİNİ
  // DEĞİL ORTASINI AL — UCU ALMAK, RENGİ SİSTEMLİ OLARAK KAYDIRIR."
  balonBen:   "#241F19",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1887 (v6 katmanı)
  // Anlam renkleri koyu zemin için açıldı — hepsi AA tutuyor.
  // 🔴 12 EYLÜL — NEON GİTTİ. Turkuazın kroması C* 45.3, yeşilin 44.5
  // idi: marka altınından bile doymuş. Gökberk'in "fintech havası"
  // teşhisi sayıyla doğru. Hepsi mat karşılıklarıyla değişti.
  teal:       "#9DBBA6",   // güven · doğrulanmış · sağlanan şart   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1448
  tealInk:    "#9DBBA6",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1449
  green:      "#EDE7DB",   // uyum ≥85 — HUE değil IŞIK (bkz. aşağıda)   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1460
  greenInk:   "#A9C0AD",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1472
  amber:      "#D9A45E",   // uyarı · engel DEĞİL, eksik   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1450
  red:        "#C97E76",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1490
  redInk:     "#D9A9A4",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1491
  purple:     "#B7A8C6",   // ikincil/bilgi   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1452
  // 🔴 31 Ağu · 8. tur — AVATAR DİSKİ TASARIMDA ALTIN DEĞİL, MOR-GRİ.
  // Tasarım: `.avatar{background:linear-gradient(145deg,#2B2430,#1E1A22)}`
  // — soğuk bir taş. Uygulama `C.goldBg` (altının %9'u) kullanıyordu;
  // aynı kareyi iki dosyadan örnekleyip ölçtüm:
  //     uygulama (44,37,20)  ·  tasarım (39,33,43)
  // yani disk SICAK KAHVE çıkıyordu, tasarım SOĞUK MOR istiyordu.
  // Gözle "altın rengi bir daire" ikisinde de doğru görünüyor; fark
  // ancak yan yana konunca ve ancak PİKSEL ÖLÇÜLÜNCE ayrılıyor.
  //
  // 🆕 SINIF: "İKİ RENK 'AYNI AİLEDEN' GÖRÜNÜYORSA GÖZ ONAYLAR —
  // AİLEYİ DEĞİL DEĞERİ ÖLÇMEK GEREKİR."
  //
  // Degrade tek renge indirildi: 145°'lik geçişin orta noktası.
  // (#2B2430 ↔ #1E1A22 ortası = #251F29)
  avatarBg:   "#1B1816",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1882 (v6 katmanı)

  // ── DÜĞMELER — KOYU TEMADA DA BEYAZ MÜREKKEP ─────────────────────
  // 🔴 İLK KARARIM YANLIŞTI VE BEDELİ ÖLÇÜLEBİLİRDİ.
  // Koyu temada düğme zeminini AÇIK altın (#D8B36A) yapmıştım; o zeminde
  // beyaz metin okunmaz, yani üstüne koyu metin gerekiyordu. Sonra
  // ölçtüm: uygulamada 73 yerde `color: "#fff"` var ve hepsinin zemini
  // DIŞ bir View'da — statik olarak hangisinin düğme olduğunu
  // ayırt etmek mümkün değil. Yani o karar, 73 noktayı elle
  // sınıflandırma borcu yaratıyordu.
  //
  // Sonra asıl soruyu sordum: beyaz mürekkep KORUNABİLİR miydi?
  // Beyaz metin zeminine bir tavan koyar (L ≤ 0.1833). Koyu sayfa
  // L = 0.0070. Aradaki boşlukta 4.6:1 beyaz VE sayfadan 3.96:1
  // ayrışma aynı anda sağlanıyor — üstelik açık temanın kendi
  // düğmesinden (3.56:1) daha net.
  //
  // 🆕 SINIF: "BİR KARARIN MALİYETİ 73 NOKTAYI ELLE AYIKLAMAKSA, ÖNCE
  // O KARARIN ZORUNLU OLUP OLMADIĞINI ÖLÇ — GENELDE DEĞİLDİR."
  goldBtn:    "#8D712D",   // beyazla 4.63:1 · sayfadan 3.96:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1299
  goldBtn2:   "#7A6127",   // gradyanın alt ucu   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1300
  goldBtnInk: "#FFFFFF",   // ← beyaz kaldı; 73 çağrı yeri korundu
  tealBtn:    "#0C8379",   // beyazla 4.63:1 · sayfadan 3.97:1
  // 🔴 20 EYLÜL — C* 62.4 · marka sinyal tavanı 45. L* korunarak indirildi
  // (49.2 → 49.3): beyazla kontrast 4.61 → 4.61, yani okunurluk AYNI.
  amberBtn:   "#A4672F",   // beyazla 4.61:1 · C* 62.4 → 45.1 · hue 65° → 64°
  dangerBtn:  "#C71A62",   // beyazla 5.51:1 · sayfadan 3.10:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1304
  // 🔴 20 EYLÜL — C* 60.3 → 45.1 (sinyal tavanı). L* 37.8 → 37.7.
  dangerBtn2: "#993456",   // gradyanın alt ucu · beyazla 7.05:1
  dangerBtnInk: "#FFFFFF",

  // 🔴 `greenBtn` ADI "DÜĞME" AMA İŞİ MÜREKKEPTİ: kodda yalnız metin
  // rengi olarak geçiyordu (7 yer, ölçüldü) ve bu yüzden koyu karşılığı
  // AÇIK bir yeşil (#5CCF9B) seçilmişti. `C.yuzey` tablosu ise onu bir
  // düğme ZEMİNİ olarak ilan ediyordu — beyaz metinle 1.93:1.
  // Yani tablo ürünle çelişiyordu ve iki temada iki farklı yalan
  // söylüyordu. Çağrı yerleri `C.greenInk`e taşındı; bu token artık
  // gerçekten bir düğme zemini.
  greenBtn:   "#048561",   // beyazla 4.63:1 · sayfadan 3.96:1
  red:        "#F2607F",   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1490
  // 🔴 20 EYLÜL — adı "sıcak" ama hue 56° · C* 50.7 ile marka tavanının
  // (28) neredeyse iki katıydı. Adıyla kendini doğrulayan bir jeton:
  // "sıcak" yazdığı için kimse ölçmemiş. L* korunarak 86°/27'ye alındı.
  sicak:      "#A99366",   // alt sıcak geçişin rengi · C* 50.7 → 26.9 · hue 56° → 86°
  sicakGuc:   0.26,        // geçişin en yoğun noktası
};

// Koyu temada rozet metni AÇIK tona döner — koyu zeminde koyu metin
// okunmaz. Dördü de koyu kart üzerinde ölçüldü (6.76–7.47:1).
// ════════════════════════════════════════════════════════════════════
// 🔴 11 EYLÜL — KARAR ÜÇLÜSÜ RENK KÖRÜ GÖZDE AYRIŞMIYORDU.
//
// Ölçüm (Brettel/Viénot dikromazi benzetimi, CIE Lab ΔE):
//   ok #6FD9A8 → dötanopi #00FFA1
//   block #F79BAF → dötanopi #00FFA2      ← TEK HANE FARK
// Yani "Misafir ücretsiz" ile "Girilmez" kırmızı-yeşil renk körü bir
// gözde AYNI PİKSEL. Protanopide ΔE 2.6. Ürünün tek işi olan kararı,
// erkeklerin ~%8'i renkten okuyamıyordu.
//
// Ayrıca cost #E8C87A ile MARKA ALTINI #D1B56D arasında ΔE 7.7, ton
// farkı 0.8° — "bu bizim rengimiz" ile "bu sana para yazacak" aynı sarı.
//
// `renk_korluk_check.py` yeşil yanıyordu çünkü kontrol ettiği dört
// çiftin arasında bu üçlü YOKTU.
// 🆕 SINIF: "BİR KAPININ YEŞİL YANMASI, DENETLENEN ŞEYİN DOĞRU OLDUĞUNU
// DEĞİL, O KAPININ O KURALI BİLDİĞİNİ SÖYLER." (19 Ağustos'ta sitede
// aynı dersi yazmıştım; kapıya yazmamışım.)
//
// YENİ DEĞERLER — cost amber'a, block koyulaştırılmış güle:
//   en kötü ΔE 0.5 → 37.7  (normal 47 · dötanopi 41 · protanopi 38)
//   kontrast (sayfa): ok 11.1 · cost 9.6 · block 6.0 — rozet zemininde
//   en düşük 4.88, hepsi AA
// Renk TEK BAŞINA yeterli değil — `Cip`e işaret + dolgu eklendi, üç
// rozet renksiz bakıldığında da ayrı (bkz. ui.js `KararCipi`).
// ════════════════════════════════════════════════════════════════════
KOYU.badgeInk = {
  ok:      "#6FD9A8",   // 11.13:1
  cost:    "#FAA542",   // 9.62:1  (marka altınıyla ΔE 31.1 — eskiden 7.7)
  unknown: "#B6BCC8",   // 6.89:1
  block:   "#F2605D",   //  6.04:1 sayfa · 4.88:1 rozet zemininde
  info:    "#DDD6CD",
};

// Açık temanın sıcak geçişi (aynı öge, düşük yoğunlukta)
C.sicak = "#E39B6B";
C.sicakGuc = 0.16;

// ---------------------------------------------------------------------------
// ATMOSFER DOKUSU — RENKLER PALETTEN, `atmosfer.js`TEN DEĞİL
//
// 🔴 İLK HALDE DOKU RENKLERİ atmosfer.js'E GÖMÜLÜYDU: ufuk "#E39B6B",
// bulut "#FFFDF9". Açık temada doğru; KOYU temada felaket. Ölçtüm:
// neredeyse beyaz bulut, koyu sayfada gövde metnini 12.74 → 4.37'ye
// düşürüyordu (10 puana varan kayıp). Doku paleti görmüyordu çünkü
// dokunun rengi palette DEĞİLDİ.
//
// 🆕 SINIF: "İKİ TEMASI OLAN BİR ÜRÜNDE RENGİ BİLEŞENİN İÇİNE YAZMAK,
// O BİLEŞENİ TEK TEMAYA SESSİZCE ÇİVİLEMEKTİR."
//
// Değerler tahmin değil, arama sonucu: renk × yoğunluk uzayında AA'yı
// koruyan bileşimler arasından dokunun EN GÖRÜNÜR olduğu nokta seçildi.
// (Koyu temada bulutu sıcak-koyuya çevirip yoğunluğu %9→%7 düşürmek,
// dokuyu görünmez yapmadan en kötü rolü 4.37 → 4.59'a çıkardı.)
// ---------------------------------------------------------------------------
// FOTOĞRAF ÜSTÜ MÜREKKEP — ayrı bir yüzey ailesi
//
// 🔴 BU GRUBU `palette_check.py` DOĞURDU. Fotoğraflı bandı ve splash'i
// yazarken metin renklerini satır içinde uydurdum (#FAEEDC, #FFFBF2, …) ve
// denetim beşini birden kırmızıya boyadı. Haklıydı: tek ekran için
// uydurulan renk, temayı o ekranda çatallar.
//
// Ama bunlar gerçekten AYRI bir aile: sayfa mürekkebi krem zemin için
// ayarlandı, bunlar FOTOĞRAF için. Aynı kutuya koymak da yanlış olurdu.
// O yüzden palete giriyorlar — ama bir grup olarak, adlarıyla ve
// ölçüleriyle.
//
// Ölçümler `ui_onerisi/ic_sayfa_son.py` ve `logo_yerlesim.py` çıktısından
// (dört katmanlı gölgenin oluşturduğu zeminde, harf pikselinde):
//   marka 7.19 · etiket 5.01 · başlık 7.02 · alt 7.14 · altın bağ 18.18
//
// 🆕 SINIF: "SATIR İÇİNDE UYDURULAN BİR RENK YA PALETE GİRER YA DA SİLİNİR —
// ÜÇÜNCÜ SEÇENEK OLAN 'ORADA KALSIN' TEMAYI SESSİZCE İKİYE BÖLER."
// ══════════════════════════════════════════════════════════════════════
// 🔴 v3.6 — `"#fff"` 63 YERDE ELLE YAZILMIŞTI VE TEMA ONU HİÇ GÖRMÜYORDU.
//
// Altın/teal/mor bir düğme zemininin üstündeki metin her yerde `"#fff"`
// diye sabit yazılmış. Bu bir renk değil bir ROL: "vurgu zemini üstündeki
// mürekkep". Rolün adı olmadığı için:
//   · `temaYenidenKur` bütün `bg`/`bd` değerlerini yeniden kuruyor ama
//     `fg` HİÇ dokunulmuyor — koyu temada da beyaz kalıyor (şu an doğru,
//     ama tema değişirse sessizce yanlış olur),
//   · üç ayrı yazımı dolaşıyor: `#fff` ×63, `#FFFFFF` ×3.
//
// 🆕 SINIF: "BİR RENGİ 60 YERDE AYNI YAZMAN ONU TUTARLI YAPMAZ — ADI
// OLMAYAN BİR ROL, TEMANIN GÖREMEDİĞİ BİR ROLDÜR."
C.onAccent = "#FFFFFF";   // vurgu zemini (gold/teal/red/purple) üstündeki mürekkep
// 🔴 30 AĞUSTOS — ALTIN DÜĞMENİN MÜREKKEBİ ARTIK AYRI BİR JETON.
// Açık temada beyaz kalıyor; KOYU temada koyu mürekkebe dönüyor.
// Sebep ölçüldü: gece sisteminin parlak altını (#EBCD92→#C39B4C) üstünde
//     beyaz  1.54 – 2.59:1   → okunmuyor
//     koyu  12.27 – 7.28:1   → rahat geçiyor
// 26 Ağustos'ta "beyaz mürekkep korunsun" kararı DOĞRUYDU — ama o karar
// KOYU altın bir zemin için verilmişti. Zemin değişti, karar da değişmeli.
// 🆕 SINIF: "BİR KARARIN GEREKÇESİ BİR ÖLÇÜMSE, ÖLÇÜMÜN ZEMİNİ DEĞİŞTİĞİNDE
// KARAR OTOMATİK OLARAK GEÇERSİZDİR — KORUNMASI GEREKEN SONUÇ DEĞİL YÖNTEMDİR."
C.onGold = "#FFFFFF";

C.foto = {
  marka:  "#FAEEDC",   // LOUNGELINK · fotoğraf üstü · 7.19:1
  etiket: "#FFFBF2",   // İSTANBUL · 4 EYLÜL · 5.01:1
  baslik: "#FFFDF9",   // Keşfet · 7.02:1
  alt:    "#F6EEE6",   // alt bilgi satırı · 7.14:1
  // 🔴 30 AĞUSTOS — TASARIMIN ALTIN ÜST BİLGİSİ FOTOĞRAFTA ÖLÇÜLDÜ VE KALDI.
  //
  // Tasarımda `.dugum` (İSTANBUL · IST) düpedüz altın: `#E0BE7A`. Zemini
  // ise düz koyu bir mesh (`#1A1620`). Orada ölçtüm: **10.02:1** — kusursuz.
  //
  // Bizim bandın zemini ise FOTOĞRAF. Aynı altını orada ölçtüm:
  //     #E0BE7A / bant zemini  →  2.91:1     (AA eşiği 4.5)
  //     #EBCD92                →  3.37:1
  //     #F7E6C8                →  4.22:1     hâlâ altında
  // Ve bu metin 10px/700 — "büyük metin" istisnasına da girmiyor.
  //
  // Yani tasarımın rengini buraya kopyalamak, tasarımı uygulamak değil;
  // tasarımın HİÇ ÇİZMEDİĞİ bir zeminde onun kararını taklit etmek olurdu.
  // Altına en yakın, AA'yı geçen sıcak beyaz: **4.57:1**. Gerçek altın,
  // fotoğrafsız (mesh) başlıklarda kullanılıyor — orada zaten 10.8:1.
  //
  // 🆕 SINIF: **"BİR TASARIM KARARI HER ZAMAN BİR ZEMİN ÜZERİNDE
  // VERİLMİŞTİR. ZEMİNİ TAŞIMADAN RENGİ TAŞIRSAN, KARARI DEĞİL
  // YALNIZ SAYIYI KOPYALAMIŞ OLURSUN."**
  // 🔴 30 Ağu · 7. tur — TASARIMIN ALTINI GERİ GELDİ.
  // #FFEFD2 idi: bant bir FOTOĞRAF iken tasarımın altını (#E0BE7A)
  // orada 2.91:1 ölçülüyordu ve açılmıştı. Bant artık mesh; aynı
  // altını yeniden ölçtüm — 6.68:1. Açmanın gerekçesi kalmadı.
  // (Aynı ders `GolgeliMetin`de de geçerli, bkz. ui.js.)
  dugum:  "#E0BE7A",   // üst bilgi · fotoğraf üstü altın izlenimi · 4.57:1
  altSol: "#E8E1D9",   // splash alt satırı (daha soluk bağlam)
  bag:    "#F6D296",   // "Giriş yap" — fotoğraf üstünde altın bağlantı
  // 3 Eylül — tasarım 01: sloganın İKİNCİ satırı sıcak krem (mockup: #F6E4C4).
  sozIkinci: "#F6E4C4",
};

// ═══════════════════════════════════════════════════════════════════════
// 🔴 v3.1 — RENKLİ YÜZEYLERİN MÜREKKEBİ. 50 DOKUNULABİLİR AA'NIN ALTINDAYDI.
//
// Düğme sistemini bağlarken 361 dokunulabiliri sınıflandırdım ve elle
// renklendirilmiş 61 tanesinde metin/zemin oranını ölçtüm. 50'si AA'yı
// geçmiyordu — ve hepsi aynı birkaç çiftin tekrarıydı:
//
//     C.gold   + beyaz  → 2.86   (22 yer)   ← Btn'de düzelttiğim hatanın kopyası
//     C.goldBg + C.gold → 2.65   ( 3 yer)
//     C.amberBg+ C.amber→ 2.97
//     C.tealBg + C.teal → 3.50
//     C.greenBg+ C.green→ 3.58
//     C.teal   + beyaz  → 3.74   ( 5 yer)
//     C.bgAlt  + C.muted→ 4.13   ( 4 yer)
//     C.redBg  + C.red  → 4.30   ( 6 yer)
//
// Sebep tek: ekranlar SİNYAL rengini (C.gold, C.teal, C.red) MÜREKKEP
// olarak kullanıyor. Sinyal rengi bir işaret rengidir; okunmak için
// ayarlanmamıştır. Okunacak her yüzeyin kendi mürekkebi olmalı.
//
// 🆕 SINIF: "BİR RENGİN İŞARET DEĞERİ İLE OKUNURLUK DEĞERİ AYRI ŞEYLERDİR
// — AYNI TOKENİ İKİSİ İÇİN KULLANIRSAN, HER ZAMAN OKUNURLUK KAYBEDER."
//
// Aşağıdaki üç token eksikti; tonları KORUNARAK, eşiği geçen EN AÇIK
// değerde arandı (yani gereğinden fazla koyulaşmıyorlar).
// ═══════════════════════════════════════════════════════════════════════
C.greenInk  = "#047E58";   // greenBg üzerinde 4.83:1
C.tealInk    = "#0B786F";   // 🔴 #0B7B71 idi: tealTint2 üstünde 4.42:1 — AA'nın
                            // ALTINDA. `tealBtn`i mürekkep olarak kullanan tek
                            // satırı bu tokene çevirirken ölçtüm ve yakaladım.
                            // tealTint2 4.59 · tealBg 4.99 · kart 5.26 · blok 4.73
C.amberBtn  = "#AB5E05";   // beyaz metin taşıyan amber zemin · 4.84:1
C.purpleInk = "#6B2FD6";   // purpleBg üzerinde okunur mor
// 🔴 KOYU BİR YÜZEYDE AÇIK MÜREKKEP GEREKİR. `C.ink` zeminli bir kutuda
// `C.purple` 2.89:1 veriyordu — mor koyu bir renk, koyu zeminde kaybolur.
// Aynı ton, açık ucundan alındı.
C.purpleUst = "#A172F2";   // C.ink zemininde 4.86:1

C.doku = { ufuk: "#E39B6B", bulut: "#FFFDF9", cizgi: C.ink, yogunluk: 0.09 };
KOYU.doku = { ufuk: "#E39B6B", bulut: "#8E4E38", cizgi: KOYU.ink, yogunluk: 0.07 };

// Karar motorunun cevabını rozet tonuna çeviren TEK yer. Ekranlar
// kendi başına renk seçmez; bu fonksiyonu çağırır.
C.badgeToneFor = function (policy, opts) {
  const o = opts || {};
  if (o.blocked) return "block";
  switch (policy) {
    case "included": return "ok";
    case "paid": return "cost";
    case "not_allowed": return o.paidEntry ? "cost" : "block";
    case "unknown":
    case null:
    case undefined: return "unknown";
    default: return "info";
  }
};

// ════════════════════════════════════════════════════════════════════
// YÜZEY SÖZLEŞMESİ (26 Ağustos)
//
// 🔴 NEDEN: Aynı kusuru bugün İKİ KEZ buldum — rozetlerde ve App.js'in
// ana düğmesinde. İkisinde de sebep aynıydı: v2.65'te okunabilirlik
// katmanı kuruldu, sonra yazılan/dokunulmayan kod o katmanı atladı.
//
// Renk paletten geliyor diye denetimden geçiyordu; oysa asıl soru
// "paletten mi geldi" değil, "ÜSTÜNDEKİ YAZI OKUNUYOR MU".
//
// Bu tablo her ZEMİN + METİN çiftini ADIYLA kaydeder ve `tema_check.py`
// her build'de hepsini tek tek hesaplar. Yeni bir düğme/kutu eklerken
// buraya bir satır eklemek zorundasın — eklemezsen denetim değil,
// KULLANICI bulur.
//
// tur: "metin" → 4,5:1 (WCAG 1.4.3) · "sekil" → 3,0:1 (WCAG 1.4.11)
// ════════════════════════════════════════════════════════════════════
// 🔴 BU KAYITTAKİ HER SATIR AYNI ANDA HEM ÜRÜNÜN GERÇEĞİ HEM DENETİMİN
// KAYNAĞI (`tema_check.py` burayı okur). Tema değişince yeniden kurulmak
// zorunda — yoksa nöbetçi YANLIŞ paleti ölçer.
//
// 🔴 İLK YAZIŞIMDA REBUILD'İ ELLE LİSTELEDİM VE 21 SATIRDAN 7'SİNİ
// ATLADIM (kartAlt · blok · sayfa · sayfaIkincil · üç `Ucuncul`).
// Yani koyu temada o yedi yüzey açık tema renklerinde kalırdı ve
// denetim bunu "geçti" diye raporlardı — çünkü denetimin kaynağı da
// aynı eksik listeydi.
//
// 🆕 SINIF: "BİR LİSTEYİ İKİ YERDE TUTARSAN, İKİNCİSİNİ YAZARKEN
// BİRİNCİSİNİ EKSİK KOPYALARSIN — LİSTE TEK OLMALI, İKİ KEZ
// ÇAĞRILMALI."
// Düğme mürekkebi İKİ TEMADA DA BEYAZ (bkz. KOYU düğme ailesi kararı),
// bu yüzden burada tema koşulu YOK: `kurYuzey` yalnız `C`nin bir
// fonksiyonu. Koşulu bıraksaydım nöbetçi bu tabloyu koyu tema için
// hesaplayamazdı — çünkü onu ölçen Python, JS'in `TEMA_MOD`unu bilmiyor.
function kurYuzey() {
  // 🔴 30 AĞUSTOS — ALTIN DÜĞMENİN MÜREKKEBİ ARTIK SABİT DEĞİL.
  // Nöbetçi bu tabloyu okuyup ölçüyor; tabloyu güncellemeseydim gerçek
  // düğme koyu mürekkeple çizilirken nöbetçi beyazı ölçmeye devam eder,
  // yani DOĞRU olan şeyi kırmızı gösterirdi.
  //
  // 🆕 SINIF: "BİR NÖBETÇİ ÖLÇTÜĞÜ ŞEYİN TANIMINDAN BESLENİYORSA,
  // TANIMI GÜNCELLEMEDEN DAVRANIŞI DEĞİŞTİRMEK NÖBETÇİYİ YALANCI YAPAR."
  const btnMetin = "#FFFFFF";
  const tehMetin = "#FFFFFF";
  return {
    btnBirincil:   { zemin: C.goldBtn,  metin: C.onGold, tur: "metin" },
    btnTeal:       { zemin: C.tealBtn,  metin: btnMetin, tur: "metin" },
    btnYesil:      { zemin: C.greenBtn, metin: btnMetin, tur: "metin" },
    btnTehlike:    { zemin: C.dangerBtn, metin: tehMetin, tur: "metin" },
    btnTehlikeAlt: { zemin: C.dangerBtn2, metin: tehMetin, tur: "metin" },
    btnBirincilAlt:{ zemin: C.goldBtn2,  metin: C.onGold, tur: "metin" },
    btnHayalet:    { zemin: C.bg,       metin: C.goldText, tur: "metin" },
    btnHayaletKen: { zemin: C.bg,       metin: C.goldText, tur: "sekil" },
    pill:          { zemin: C.goldBg,   metin: C.goldText, tur: "metin" },
    cipSecili:     { zemin: C.goldBg,   metin: C.goldText, tur: "metin" },
    hataKutusu:    { zemin: C.hataBg,   metin: C.redInk,   tur: "metin" },
    uyariKutusu:   { zemin: C.amberBg,  metin: C.amberInk, tur: "metin" },
    olumluKutu:    { zemin: C.tealTint2, metin: C.tealInk, tur: "metin" },
    kart:          { zemin: C.surface,  metin: C.ink,      tur: "metin" },
    kartAlt:       { zemin: C.surface,  metin: C.mutedAA,  tur: "metin" },
    blok:          { zemin: C.surfaceAlt, metin: C.body,   tur: "metin" },
    sayfa:         { zemin: C.bg,       metin: C.ink,      tur: "metin" },
    sayfaIkincil:  { zemin: C.bg,       metin: C.mutedAA,  tur: "metin" },
    kartUcuncul:   { zemin: C.surface,  metin: C.dimAA,    tur: "metin" },
    blokUcuncul:   { zemin: C.surfaceAlt, metin: C.dimAA,  tur: "metin" },
    sayfaUcuncul:  { zemin: C.bg,       metin: C.dimAA,    tur: "metin" },
    gece:          { zemin: C.gece,     metin: "#FFFFFF",  tur: "metin" },
    geceIkincil:   { zemin: C.gece,     metin: C.warmGray, tur: "metin" },
  };
}
C.yuzey = kurYuzey();


// ════════════════════════════════════════════════════════════════════
// DÜĞME SİSTEMİ (26 Ağustos · ikinci tur)
//
// 🔴 NEDEN: Gökberk "sadece renk paleti olarak düşünme, şu an daha
// canlı bir temamız var" dedi. Haklı — düz altın bir dikdörtgen, gün
// batımı zeminin altında ölü duruyor. Dört değişiklik, her biri sebeple:
//
//   1 · GRADYAN DOLGU  altından derin kehribara. RN'de `expo-linear-
//       gradient` KURULMADI: 56px'lik bir düğmede üst üste bindirilmiş
//       12 View, gradyandan ayırt edilemiyor. Yeni bir yerel bağımlılık
//       = yeni bir build kırılma noktası; bu iş onu hak etmiyor.
//   2 · SICAK GÖLGE    `shadowColor` nötr siyah değil altın ailesinden.
//       Düğme "yüzen kutu" değil, ışık alan bir yüzey gibi duruyor.
//   3 · ÜST IŞIK ÇİZGİSİ  1px açık kenar — ışık yukarıdan geliyor.
//   4 · ÖLÇÜ           yükseklik 48 → 56, köşe 12 → R.md (20).
//
// Kırmızı da değişti: C.red (#E11D48) beyaz metinle 4.70 — geçiyor ama
// sınırda. Düğme zemini olarak daha derin bir kırmızı kullanıyoruz
// (6.64), C.red işaret/metin rengi olarak yerinde kalıyor.
// ════════════════════════════════════════════════════════════════════
// 🔴 18 EYLÜL (Gökberk md.5) — AÇIK TEMANIN GRADYAN ÜST UCU YOKTU.
// `brand/build_altin.py` üç durak okuyor: goldBtnUst → goldBtn → goldBtn2.
// Açık palette `goldBtnUst` TANIMSIZDI, o yüzden görsel her zaman
// `palet("KOYU")`den üretiliyordu ve açık temada şampanya gradyanın
// üstüne BEYAZ metin basılıyordu: 1.65:1 (AA eşiği 4.5).
// Üst uç seçilirken tek kısıt beyaz metin: #8D712D 4.63:1 ile AA'yı
// ancak geçiyor, #937832 4.22'ye düşüyor. Üst uç #8D712D.
// Gradyanın en açık noktası bile AA — yani hiçbir satırda düşmüyor.
C.goldBtnUst = "#8D712D";   // açık tema · ışık ucu · beyazla 4.63:1
C.goldBtn2   = "#6E5620";   // birincil gradyanın ALT ucu (goldBtn → bu)
C.goldGolge  = "#966E28";   // sıcak gölge rengi (shadowColor)
// 🔴 v3.1 — TEHLİKE RENGİ, RENK KÖRLÜĞÜNDE BİRİNCİL DÜĞMEDEN AYRILMIYORDU.
// Bunu düğme rengini tartışırken buldum ve beklediğim yönde çıkmadı:
// suçlu yeni renkler değil, ŞU AN CANLIDA OLAN ikili.
//
// ÖLÇÜM (CIELAB ΔE, en kötü dikromazi hâlinde):
//     birincil #846A2A  ↔  tehlike #B0243C   →  ΔE  8.0   ✗
// ΔE < 15 "aynı renk" demektir. Yani dötanop bir kullanıcı için
// "Uçuşunu yaz" ile "İlanı sil" AYNI RENK. Bu estetik değil güvenlik
// sorunu: geri alınamaz eylem, ana eylemden ayırt edilemiyor.
//
// Aday tarandı; her birincil seçenekten 25'i geçen tek aile mor-kırmızı:
//     #A11450 → kahve 28.3 · altın 60.9 · gün batımı 47.2 · terrakota 45.2
//
// 🆕 SINIF: "İKİ DÜĞMENİN AYRI RENKTE OLMASI YETMEZ — RENK KÖRÜ BİR
// GÖZDE DE AYRI KALDIĞINI ÖLÇMEDİYSEN, AYRI DEĞİLLER."
C.dangerBtn  = "#A11450";   // tehlike düğmesi zemini · beyazla 7.69:1
C.dangerBtn2 = "#8A1145";   // gradyanın alt ucu
// 🔴 12 Eylül · akşam — %34 → %14. Yeni şampanya dolgunun üstünde %34
// ΔE 7.33 veriyordu: bir ışık değil bir ÇİZGİ. %14 → ΔE 3.10.
// Basılı hâlde `Btn` bunu 2.1 katına çıkarıyor (≈%29) — o an parlaması
// GEREKEN tek an orası.
C.btnUstIsik = "rgba(255,255,255,0.14)";  // 1px üst ışık · basınca ×2.1

export const BTN = {
  // 🔴 30 AĞUSTOS · GECE SİSTEMİ ÖLÇÜLERİ
  // Yükseklik 56 → 52: koyu zeminde altın dolgu zaten güçlü bir leke;
  // 56 onu ekranda fazla yer kaplar hâle getiriyordu. 52 hâlâ 48dp
  // tabanının üstünde (referans sistemin Fitts kuralı).
  // Yarıçap 20 → 12: 20 "yumuşak/samimi", 12 "kesin/premium". Kart
  // yarıçapı 16'da kaldı — düğme karttan DAHA keskin, çünkü eylem
  // yüzeyden daha kesin olmalı.
  // 🔴 30 AĞUSTOS · 5. TUR — 52 DEĞİL 48. TASARIM NE DİYORSA O.
  // Yukarıdaki yorumda "56 → 52" diye bir muhakeme var ve o muhakeme
  // benim. Tasarımın kendi CSS'i ise açıkça yazıyor:
  //     .btn-altin{ min-height:48px }
  //     .btn-cizgi{ min-height:48px }
  //     .btn-sessiz{ min-height:44px }
  // Yani 52'yi tasarımdan almadım, tasarımın etrafında düşündüm.
  // Kartın en uzun öğesi düğme olduğu için o 4px, KART BOYUNCA
  // çoğalıyordu: önizlemeyi tasarımın tarayıcıda çizilmiş hâliyle yan
  // yana koyunca kartlar gözle görülür biçimde daha seyrekti.
  //
  // 🆕 SINIF: "TASARIMIN VERDİĞİ BİR SAYIYI KENDİ GEREKÇEMLE
  // DEĞİŞTİRDİĞİMDE ARTIK O TASARIMI UYGULAMIYORUM — ONA BENZEYEN
  // BİR ŞEY YAPIYORUM; VE FARK HER TEKRARDA BİRİKİYOR."
  // 🔴 12 EYLÜL — HAP DÜĞME VE KİBARLAŞTIRILMIŞ ETİKET.
  // Gökberk: "butonlar ekranın enini kaplıyor ve çok kaba bir
  // yüksekliğe sahip." Ölçtüm: yükseklik ZATEN 48'di (56 değil) —
  // yani kabalığı üreten şey yükseklik değildi. Üç gerçek sebep:
  //   1· dolgunun kroması (C* 33 — bkz. şampanya kararı)
  //   2· etiketin ağırlığı (700) ve harf aralığının sıfır olması
  //   3· köşe yarıçapı 12 — "yumuşak kart", "kesin düğme" değil
  // 48 → 46: iki piksel, ama kart boyunca çoğalıyor. Küçük düğme
  // 44'te KALIYOR: 40 dokunma tabanının altına iner ve o taban bir
  // zevk kararı değil (`dokunma_check.py` ölçüyor).
  //
  // 🆕 SINIF: "BİR ŞEY 'KABA' GÖRÜNÜYORSA ÖNCE ÖLÇ — ŞİKÂYETİN ADRESİ
  // ÇOĞU ZAMAN ŞİKÂYETİN SÖYLEDİĞİ YER DEĞİLDİR."
  yukseklik:      46,   // ana düğme
  yukseklikKucuk: 44,   // kart içi ikincil — dokunma tabanı
  radius:         999,  // HAP — lüksün geometrisi bu üründe hap tarafında
  // 🔴 GECE SİSTEMİ · ALTIN PARILTI
  // Koyu zeminde gölge işe yaramaz — zaten karanlık. Onun yerine düğme
  // KENDİ IŞIĞINI yayıyor: geniş yarıçap, düşük opaklık, altın renk.
  // Referans sistem buna `shadow-glow` diyor; mekanik aynı.
  golge: {
    shadowColor: C.goldGolge, shadowOpacity: 0.20, shadowRadius: 22,
    shadowOffset: { width: 0, height: 4 }, elevation: 8,
  },
  golgeKapali: { shadowOpacity: 0, elevation: 0 },
};

// Koyu temanın düğme karşılıkları
// 🔴 GECE SİSTEMİ: koyu temada gölge KOYULAŞTIRMAZ, IŞITIR.
// Eski #5C3F16 karanlık zeminde görünmüyordu — karanlığın üstüne
// karanlık koymak hiçbir şey çizmez. Parıltı altının kendisi.
KOYU.goldGolge = "#C9B693";   // altın parıltı — şampanya
// Gece sistemi düğme gradyanı: üstte açık altın, altta derin altın.
// 🔴 12 EYLÜL — ÜÇ DURAKLI ŞAMPANYA. Eski ikili (#EBCD92 → #C39B4C)
// uç-uca ΔE 22.1'di; yenisi 22.8 — yani ARALIK NEREDEYSE AYNI.
// "Sert" olan şey gradyanın uzunluğu değildi, iki ucun da doymuş sarı
// olmasıydı. Yeni uçlar aynı aralıkta, yarı kroma.
// 🆕 SINIF: "BİR GEÇİŞ SERT GÖRÜNÜYORSA ÖNCE UÇLARIN DOYGUNLUĞUNA BAK,
// SONRA ARALIĞINA — GÖZ DOYGUNLUĞU 'SERTLİK' DİYE OKUR."
KOYU.goldBtnUst = "#E2D4B8";   // ışık ucu       · koyu mürekkep 12.72:1
KOYU.goldBtn  = "#D9C8A6";     // gövde (%52)    · koyu mürekkep 11.32:1
KOYU.goldBtn2 = "#B49B70";     // gölge ucu      · koyu mürekkep  6.97:1
KOYU.onGold   = "#17120B";   // altın üstündeki mürekkep — koyu
// "İlanı sil" gece sisteminde parlak macenta olarak patlıyordu; premium
// bir arayüzde yıkıcı eylem BAĞIRMAZ, KESİNLEŞİR.
KOYU.dangerBtn = "#7E3A3C";

// <<< KOYU-TURETILDI — koyu_doldur.py yazar, ELLE DÜZENLEME
// 38 token · her biri ölçülerek türetildi (bkz. tema_koyu_turet.py)
// sayfa #0B0A0B · kart #141211 · blok #1B1816

// ── TONLU ZEMİN — sayfadan ayrışan koyu bloklar ──
KOYU.amberBg     = "#2C2214";   // sayfa 1.27:1 · kart 1.20:1
KOYU.goldBg      = "#292312";   // sayfa 1.26:1 · kart 1.19:1
KOYU.goldTint    = "#261C11";   // sayfa 1.18:1 · kart 1.12:1
KOYU.greenBg     = "#12281D";   // sayfa 1.27:1 · kart 1.20:1
KOYU.purpleBg    = "#281D40";   // sayfa 1.26:1 · kart 1.19:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1589
KOYU.redBg       = "#391A1F";   // sayfa 1.26:1 · kart 1.19:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1884 (v6 katmanı)
KOYU.tealBg      = "#112724";   // sayfa 1.26:1 · kart 1.19:1
KOYU.tealTint    = "#0F211D";   // sayfa 1.18:1 · kart 1.12:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1883 (v6 döngüsü)
KOYU.tealTint2   = "#102520";   // sayfa 1.23:1 · kart 1.16:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1883 (v6 döngüsü)

// ── NÖTR ZEMİN — sıcak gri bloklar (ton taşımaz) ──
KOYU.warmBlock   = "#1D1A18";   // sayfa 1.14:1
KOYU.warmBlock2  = "#23201E";   // sayfa 1.22:1
KOYU.warmBlock3  = "#292522";   // sayfa 1.30:1

// ── DOĞRUDAN EŞLEME ──
KOYU.card        = KOYU.surface;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1880 (v6 katmanı)
KOYU.bgAlt       = KOYU.surfaceAlt;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1881 (v6 katmanı)
KOYU.muted       = KOYU.mutedAA;
KOYU.dim         = KOYU.dimAA;
KOYU.mut         = KOYU.mutedAA;
KOYU.paper       = KOYU.bg;
KOYU.goldSoft    = KOYU.goldBg;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1886 (v6 katmanı)
KOYU.hataBg      = KOYU.redBg;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1885 (v6 katmanı)

// ── MÜREKKEP — kendi tonlu zemininde ölçüldü ──
KOYU.amberInk    = "#FBA13A";   // amberBg 7.62:1 · kart 9.13:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1451
// 🔴 20 EYLÜL — SOĞUK GRİLER LACİVERT DÜNYADAN KALMIŞTI.
// `coolLine` hue 269° · `inkSoft` hue 272°: kroması düşük (9-11) ama
// YÖNÜ maviydi. Obsidyen SICAK bir siyahtır; üstündeki gri de sıcak
// olmalı, yoksa yüzey "kirli" okunur. L* birebir korundu (73.7/73.8),
// yani kontrast tablosundaki 9.13 ve 9.15 değerleri DEĞİŞMEDİ.
KOYU.coolLine    = "#BEB4A4";   // kart 9.13:1 · hue 269° → 85°
KOYU.goldInk     = "#D6B148";   // goldBg 7.62:1 · kart 9.11:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1445
KOYU.greenInk    = "#07CE90";   // greenBg 7.60:1 · kart 9.11:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1472
KOYU.inkSoft     = "#BFB4A2";   // kart 9.15:1 · hue 272° → 85°
KOYU.purpleInk   = "#C2AAEE";   // purpleBg 7.67:1 · kart 9.14:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1590
KOYU.redInk      = "#F79BAE";   // redBg 7.64:1 · kart 9.12:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1491
KOYU.tealInk     = "#13CBBB";   // tealBg 7.68:1 · kart 9.15:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1449
KOYU.warmGray    = "#BDB59D";   // kart 9.13:1 · kart 9.13:1
KOYU.purpleUst   = "#D7C2F9";   // gece 6.21:1 · kart 11.54:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1591

// 🔴 KOYU TEMADA HATA MÜREKKEBİ TÜRETİMDEN GELDİĞİ GİBİ KALAMADI.
// Türetim yalnız KONTRASTA bakar; `renk_korluk_check.py` ikinci bir
// soru sordu: dötanop bir gözde `greenInk` ile `redInk` ayrı mı?
// Ölçüm: ΔE 5.7 — yani hata metni ile başarı metni AYNI RENK.
// Aynı ton ailesinde, daha AÇIK bir değer ΔE'yi 23.4'e çıkarıyor.
// (Açık temada aynı çift 21.0 ile zaten geçiyordu.)
//
// 🔴 BU DEĞERİ İKİ KEZ SEÇTİM. İlki (#FFADC6) ESKİ yüzey
// merdivenine göre çözülmüştü; merdiven sıcak tona taşınıp
// yükseltilince ΔE 18.9'dan 15.7'ye düştü — eşiğin 0.7 üstünde,
// yani tesadüfen geçiyordu. Bir zemin değişince ONUN ÜSTÜNDEKİ
// her kararın yeniden çözülmesi gerekiyor; 'zaten geçmişti'
// diye bırakılan her değer bir sonraki değişimde sessizce düşer.
//
// 🆕 SINIF: "BİR EŞİĞİ KIL PAYI GEÇEN DEĞER, GEÇMİŞ DEĞİL
// ERTELENMİŞTİR — MARJI OLMAYAN ÖLÇÜM BİR SONRAKİ DEĞİŞİKLİKTE
// KIRMIZIYA DÖNER."
// Doygunluk %100'de tutuldu: hata rengi soluklaşırsa alarm
// sinyalini kaybeder — kazanılan erişilebilirlik, kaybedilen
// aciliyetten büyük olmalı.
KOYU.redInk      = "#FFD1E2";   // dikromazi ΔE 23.4 · en kötü zemin 6.94:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1491

// ── SİNYAL — metin ve kenarlık; bağlayıcı eşik metin ──
KOYU.gold        = "#D0B268";   // en kötü zemin 4.91:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1444
KOYU.amber       = "#FAA23C";   // en kötü zemin 4.93:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1450
KOYU.green       = "#07CE90";   // en kötü zemin 4.90:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1460
KOYU.teal        = "#12CBBA";   // en kötü zemin 4.92:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1448
KOYU.purple      = "#C5A7F7";   // en kötü zemin 4.91:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1452
KOYU.goldDeep    = "#E5AA61";   // en kötü zemin 4.91:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1446

// ── GECE YÜZEYİ — çevresinden KOYU olan kasıtlı ada ──
KOYU.gece        = "#4C4033";   // sayfa 1.97:1 (çukur)

// ── KENARLIK · DÜĞME · MARKA ──
KOYU.goldLine    = "#725F2B";   // kart 3.01:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1447
KOYU.warmGray2   = "#695F59";   // kart 3.01:1
KOYU.brandApple  = "#FFFFFF";   // Apple HIG: koyu zeminde BEYAZ düğme
KOYU.brandAppleInk = "#000000";
KOYU.brandGoogle = "#8AB4F8";   // Google'ın kendi koyu tema mavisi

// ── YARI SAYDAM ÇİZGİLER — koyu zeminde %16 opaklık kaybolur.
// Ölçtüm: rgba(184,148,58,0.16) koyu sayfada 1.06:1 — yok gibi.
// Koyu temada aynı ton, daha yüksek opaklıkla yazılıyor.
KOYU.warmLine   = "rgba(216,179,106,0.22)";
KOYU.hataLine   = "rgba(255,173,198,0.34)";
// Koyu temada modal perdesi daha DERİN olmalı: %55 siyah, koyu bir
// sayfanın üstünde yalnız 1.4:1 fark yaratıyor — modal 'öne çıkmıyor'.
KOYU.perde      = "rgba(0,0,0,0.72)";
KOYU.tealLine   = "rgba(79,197,182,0.42)";
KOYU.purpleLine = "rgba(169,125,243,0.42)";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1592

// ── ROZET TİNTİ — `info` açık temada rgba(26,31,46,0.05):
// koyu sayfada tamamen görünmez. Koyu temada mürekkep tarafına
// dönüyor; diğer dördü zaten renkli, opaklıkları artırıldı.
KOYU.badge = {
  ok:      { fg: KOYU.badgeInk.ok, bg: "rgba(111,217,168,0.13)", bd: "rgba(111,217,168,0.30)" },
  cost:    { fg: KOYU.badgeInk.cost, bg: "rgba(232,200,122,0.13)", bd: "rgba(232,200,122,0.30)" },
  unknown: { fg: KOYU.badgeInk.unknown, bg: "rgba(182,188,200,0.13)", bd: "rgba(182,188,200,0.30)" },
  block:   { fg: KOYU.badgeInk.block, bg: "rgba(247,155,175,0.13)", bd: "rgba(247,155,175,0.30)" },
  info:    { fg: KOYU.badgeInk.info, bg: "rgba(244,239,232,0.13)", bd: "rgba(244,239,232,0.30)" },
};

// ── GÖLGE — koyu temada gölge SİYAH ve daha derin olmalı;
// #1A1F2E gibi mavi-gri bir gölge koyu zeminde MOR bir hale bırakır.
KOYU.golgeRenk = "#000000";
KOYU.golgeCarp = 2.4;   // opaklık çarpanı

// İKİ TEMADA AYNI KALANLAR — ve neden:
//   badgeToneFor  fonksiyon, renk değil
//   btnUstIsik    düğmenin 1px üst ışığı — iki temada da beyaz %34
//   foto          fotoğrafın üstündeki mürekkep — zemin fotoğraf, tema değil
//   line          KOYU.line ayrı tanımlı
// KOYU-TURETILDI >>>

// ══════════════════════════════════════════════════════════════════════
// 12 EYLÜL · PREMIUM KİMLİK RENKLERİ — TÜRETİMDEN SONRA, BİLEREK
//
// 🔴 NEDEN TÜRETİMİN ÜSTÜNE YAZIYORUM
// `tema_koyu_turet.py` bir SORUYA cevap veriyor: "bu ton, bu zeminde
// AA'yı tutacak şekilde ne kadar açılmalı?" — yani KONTRAST çözüyor.
// Ama onun tonu AÇIK TEMADAN alıyor: `C.teal` neon turkuazsa, türetim
// AA'yı tutan bir NEON TURKUAZ üretir. Doğru çalışıp yanlış sonuç verir.
//
// Gökberk'in istediği şey kontrast değil KROMA: "neon yeşil ve turkuaz
// uygulamanın tüm lüks ağırlığını alıp götürüyor." Ölçüm onu doğruladı:
//     teal  #12CDBC  C* 45.3       green #6FD9A8  C* 44.5
//     marka altını   C* 40.2       nötr grimiz    C*  6.0
// Yani sinyallerimiz markamızdan daha doymuştu.
//
// Bu blok o kararı taşıyor. Her değer DÖRT zeminde ölçüldü
// (sayfa #0B0A0B · kart #141211 · blok #1B1816 · gece adası #4C4033),
// bağlayıcı olan en kötüsü, ve hepsi AA (4.5) üstünde.
//
// 🆕 SINIF: "TÜRETİM BİR ÖLÇÜYÜ ÇÖZER, BİR KİMLİĞİ ÇÖZMEZ — FORMÜLÜN
// GİRDİSİ YANLIŞ AİLEDENSE, ÇIKTISI DOĞRU HESAPLANMIŞ BİR YANLIŞTIR."
// ══════════════════════════════════════════════════════════════════════
KOYU.gold      = "#C9B693";   // en kötü 5.07:1 · C* 40.2 → 20.4
KOYU.goldInk   = "#C9B693";   // en kötü 5.07:1
KOYU.goldDeep  = "#CBB28A";   // en kötü 4.92:1
KOYU.goldLine  = "#6B6150";   // kenarlık · kart 3.07:1 (WCAG 1.4.11 · 3:1)   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1950
KOYU.teal      = "#9DBBA6";   // en kötü 4.83:1 · C* 45.3 → 20.0
KOYU.tealInk   = "#9DBBA6";
KOYU.amber     = "#D9A45E";   // en kötü 4.51:1 · C* 65.9 → 45.1
KOYU.amberInk  = "#D9A45E";
KOYU.purple    = "#B7A8C6";   // en kötü 4.52:1   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1604
KOYU.purpleInk = "#B7A8C6";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1590
KOYU.purpleUst = "#CFC5D8";   // en kötü 6.05:1 — purple'ın bir üst kademesi   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1591

// ── UYUM YÜZDESİ: HUE RAMPASI DEĞİL IŞIK RAMPASI ─────────────────────
// Eskiden ≥85 yeşil · 65–84 altın · <65 gri — üç ayrı RENK. Renk körü
// bir gözde bu üçlünün SIRASI kayboluyordu (yeşil ile altın dötanopide
// yaklaşıyor). Işık sırası kaybolmaz: en parlak = en iyi, açıklamasız.
KOYU.green     = "#EDE7DB";   // ≥85 · fildişi · en kötü 8.17:1
// 🔴 BURADA DA IŞIKLA AYIRDIM, RENKLE DEĞİL — VE BU BİR ÖLÇÜM ZORLAMASI.
// İlk seçimim #A9C0AD'ydi (mat adaçayı). `renk_korluk_check.py` kırmızı
// yandı: `greenInk ↔ redInk` dikromazide ΔE 5.4 — yani "doğrulandı" ile
// "hata" renk körü bir gözde AYNI metin rengi. Sebebi de öğretici:
// ikisini de matlaştırınca ikisi de ORTA AÇIKLIKTA nötre yaklaştı;
// doygunluğu düşürmek, hue ile taşınan ayrımı da düşürüyor.
// Beş aday × dört zemin taradım; AA'yı ve ΔE 15'i birlikte tutan tek
// çift bu: ΔE 18.2 · ΔL* 16.9.
//
// 🆕 SINIF: "DOYGUNLUĞU DÜŞÜRMEK SESİ KISMAZ, KANALI KAPATIR — HUE İLE
// AYRILAN HER ÇİFT, MATLAŞTIRILDIĞINDA IŞIKLA YENİDEN AYRILMALIDIR."
KOYU.greenInk  = "#DCE6DE";   // "doğrulandı" metni · en kötü 7.86:1

// ── YIKICI / HATA ─────────────────────────────────────────────────────
// 🔴 BURADA BİR ÖDÜNLEŞME VAR VE GÖRÜNÜR OLMASI GEREKİYOR.
// Mat gül (#D9938B) karar rozetinde mükemmel: dikromazi ΔE 25.5 (eşik
// 25). Ama `gece` adasında (#4C4033 — ödül kartı, toast, Moment ekranı)
// 4.07:1 kalıyor, AA'nın altında. Gül'ü AA'yı tutacak kadar açtığımda
// (#E3A69E) ΔE 19.3'e düşüyor — yani renk körü gözde "girilmez" ile
// "ücretsiz" yaklaşıyor.
//
// İki şart aynı renkte buluşmuyor. Rolleri ayırdım, çünkü rolleri ZATEN
// ayrı: `red` her zemine düşebilen genel tehlike mürekkebi; `badgeInk.block`
// yalnız kart ve rozet zemininde çizilen KARAR mürekkebi. Gece adasında
// hiçbir karar rozeti yok.
//
// 🆕 SINIF: "İKİ ŞART TEK DEĞERDE BULUŞMUYORSA ÖNCE 'BU GERÇEKTEN TEK
// ROL MÜ' DİYE SOR — ÇOĞU ZAMAN ÇATIŞAN ŞEY DEĞERLER DEĞİL, BİR TOKENE
// YÜKLENMİŞ İKİ İŞTİR."
KOYU.red       = "#E3A69E";   // genel tehlike · her zeminde 4.89:1
KOYU.redInk    = "#D9A9A4";   // hata metni · en kötü 4.87:1

// ── KARAR ROZETLERİ ───────────────────────────────────────────────────
// Renk tek kanal değil: `Cip` ayrıca glif (✓ / kredi / ✕) ve dolgu
// taşıyor. Buradaki mürekkepler o üçlünün RENK kanalı.
//   dikromazi ΔE76 (eşik 25):  normal 31.8 · dötanopi 25.5 · protanopi 27.6
KOYU.badgeInk = {
  ok:      "#EDE7DB",   // fildişi — "misafir ücretsiz"
  cost:    "#D9A45E",   // mat kehribar — "misafir ücretli"
  unknown: "#B6BCC8",
  block:   "#D9938B",   // mat gül — "girilmez"
  info:    "#DDD6CD",
};
// ── FOTOĞRAFIN ÜSTÜNDEKİ CAM YÜZEY ───────────────────────────────────
// 🔴 12 EYLÜL — Gökberk: "tanıtım 5'te alanların siyah background ile
// kullanılması onboardingin arka planı ile uyuşmamış."
// Haklıydı ve sebebi yapısal: `C.surface` OPAK. Fotoğrafın önünde opak
// bir kart, kartın kendisi değil FOTOĞRAFTAN KESİLMİŞ BİR DELİK gibi
// okunuyor. Üç aday gerçek render'da denendi, kartın EN PARLAK yerinde
// ölçüldü:
//     opak #141211          her mürekkep AA  — ama levha gibi
//     cam %55  → #3B2B23    ink 12.00 · body 8.93 · mutedAA 4.95 · dim 3.78
//     çerçevesiz %30 → #433133   mutedAA 4.46 · dim 3.41   ← AA ALTI
// %55 seçildi; `dim` o zeminde düşüyor, o yüzden cam yüzeydeki en küçük
// etiket `mutedAA` ile yazılıyor (kuralı `CamKart` taşıyor).
//
// 🆕 SINIF: "SAYDAMLIK BİR GÖRÜNÜM DEĞİL BİR ZEMİN DEĞİŞİKLİĞİDİR —
// ARKASI DEĞİŞEN HER YÜZEYDE MÜREKKEP HİYERARŞİSİ YENİDEN ÖLÇÜLMELİDİR."
KOYU.camKart  = "rgba(20,18,17,0.55)";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1897 (v6 katmanı)
KOYU.camKenar = "rgba(237,231,219,0.16)";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1951

// ── KART KENARI: ÇİZGİ DEĞİL IŞIK ────────────────────────────────────
// 🔴 12 EYLÜL — Gökberk: "kartların içi adeta birer kutu cümbüşü…
// tüm bu sınır çizgilerini kaldırın. Premium tasarım çizgilerle değil
// boşluklarla konuşur."
// Ölçtüm ve şikâyetin büyüklüğü beklediğimden fazla çıktı: kartın
// kenarlığı `C.warmLine` = rgba(216,179,106,0.22) — kartın KENDİ zemini
// üstünde ΔE **20.36**. Yani kenar bir "ipucu" değil, kartın en kuvvetli
// görsel öğelerinden biriydi; üstelik SICAK SARI bir çizgiydi.
// Yeni değer aynı işi ΔE 3.91 ile yapıyor: **5.2 kat daha sessiz**.
// Kenar kaybolmuyor — bağırmayı bırakıyor.
//
// 🆕 SINIF: "BİR ÇİZGİYİ 'İNCE' YAPAN ŞEY KALINLIĞI DEĞİL, ZEMİNİYLE
// ARASINDAKİ FARKTIR — 1px BİR ÇİZGİ, ΔE 20'DE BİR DUVARDIR."
KOYU.kabartmaIsik = "rgba(244,239,230,0.055)"; // rozetin üst kenarı · ΔE 5.14   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1893 (v6 katmanı)
KOYU.kabartmaDip  = "rgba(0,0,0,0.22)";        // rozetin alt kenarı · ΔE 4.38   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1894 (v6 katmanı)
KOYU.kartKenar = "rgba(244,239,230,0.035)";   // kart üstünde ΔE 3.91
KOYU.kartIsik  = "rgba(244,239,230,0.06)";    // üstten 1px ışık · ΔE 6.32   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1892 (v6 katmanı)
KOYU.kartDip   = "rgba(0,0,0,0.30)";          // alttan 1px oturma · ΔE 2.01

KOYU.badge = {
  ok:      { fg: KOYU.badgeInk.ok,      bg: "rgba(237,231,219,0.10)", bd: "rgba(237,231,219,0.26)" },
  cost:    { fg: KOYU.badgeInk.cost,    bg: "rgba(217,164,94,0.12)",  bd: "rgba(217,164,94,0.30)" },
  unknown: { fg: KOYU.badgeInk.unknown, bg: "rgba(182,188,200,0.09)", bd: "rgba(182,188,200,0.24)" },
  block:   { fg: KOYU.badgeInk.block,   bg: "rgba(217,147,139,0.10)", bd: "rgba(217,147,139,0.32)" },
  info:    { fg: KOYU.badgeInk.info,    bg: "rgba(221,214,205,0.09)", bd: "rgba(221,214,205,0.22)" },
};


// ══════════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS — TÜRETİLMİŞ BLOĞUN ALTINA YAZ, İÇİNE DEĞİL.
//
// Bu dört jetonu (anahtar sahnesi) ve `onAccent`i ilk yazımda türetilmiş
// bloğun HEMEN ÜSTÜNE koymuştum. `koyu_doldur.py` sonradan koşunca bloğu
// yeniden yazdı ve komşuluk yüzünden hepsi kayboldu; `koyu_check` beş
// jetonu birden kırmızıya boyadı: "koyu temada AÇIK tema rengi çizilir".
//
// Dosyanın kendi uyarısı zaten yazıyordu: "ELLE DÜZENLEME". Ben bloğun
// İÇİNİ düzenlemedim ama SINIRINA yazdım — üretici için ikisi aynı şey.
//
// 🆕 SINIF: **"ÜRETİLEN BİR BLOĞUN KENARINA YAZMAK, İÇİNE YAZMAKTIR —
// ÜRETİCİ SINIRI DA KENDİ SAYAR."**
// ══════════════════════════════════════════════════════════════════════

// Vurgu zemini üstündeki mürekkep. Koyu temada da BEYAZ kalıyor: teal,
// yeşil ve kırmızı düğmeler koyu temada da koyu zeminli (yalnız ALTIN
// açıldı — bkz. `KOYU.onGold`).
KOYU.onAccent = "#FFFFFF";

// ══════════════════════════════════════════════════════════════════════
// 🔴 3 EYLÜL — MOR YÜZEYLER GECE SİSTEMİNDE YOK; ALTINA EŞLENDİ.
//
// Onaylanan 17 ekranın paletinde altı jeton var: gece · yüzey · altın ·
// güven(teal) · uyarı(amber) · bulut. "Bilgi" (#7FA8E8) yalnız `.roz.bilgi`
// çipinin METNİDİR. Uygulamada ise 60+ çağrı yeri `purpleBg/purpleInk/
// purpleUst/purpleLine` ile MENEKŞE ZEMİNLİ kutular ve DOLU MOR düğmeler
// çiziyordu ("Havalimanı Yol Arkadaşı Ağı" kutusu, "Kabul et" düğmesi,
// bağlantı kartlarının çerçevesi). Cihaz ekran görüntüsünde bunlar
// tasarımın yanında yabancı duruyordu.
//
// 60 çağrı yerini tek tek altına çevirmek yerine JETONLAR eşlendi:
// "bağlantı" kavramının yüzeyi artık altın ailesi (tasarımın tek dolgu
// vurgusu), "bilgi" metni (#7FA8E8) olduğu gibi kaldı.
//
// 🆕 SINIF: "PALETTE OLMAYAN BİR RENK, ONU KULLANAN HER YERDE TASARIMIN
// DIŞINA ÇIKAR — ÇAĞRI YERİNİ DEĞİL JETONU DÜZELT."
// (`koyu_check.py` bu satırları türetilmiş bloğun ALTINDA görür; blok
// yeniden üretilse de kaybolmaz.)
KOYU.purpleBg   = KOYU.goldBg;
// 🔴 20 EYLÜL — RENK KÖRÜ BİR GÖZDE "SEYAHATLER" İLE "TANIŞ" AYNI RENKTİ.
//
// 3 Eylül'de `purpleInk` altına eşlendi. `renk_korluk_check.py` bunu
// GÖREMİYORDU: `tema_oku.py` takma adları yanlış çözüyor ve kapıya hâlâ
// eski LAVANTA değeri (#B7A8C6) gidiyordu. Ayrıştırıcı düzeltilince
// kapı gerçeği ölçtü ve 17 GÜNLÜK bir kusur ortaya çıktı:
//
//     tealInk ↔ purpleInk   ΔE 20.5 · dikromazi 10.2  (eşik 15)
//
// Yani protanop/döteranop bir kullanıcı için gezinme dilinin iki
// kategorisi ayırt edilemiyordu.
//
// Çözüm YENİ RENK UYDURMAK DEĞİL. Mor emekli olunca "Tanış"ın kendi
// rengi de kalmadı; doğru cevap onu GÖVDE MÜREKKEBİ yapmak:
//     ink (#F4EFE6)  dikromazi 20.7 · obsidyende 17.26:1
// Ölçtüğüm altın ailesindeki her aday (goldText 10.9 · goldBtn 11.1 ·
// goldBtnUst 12.0 · body 9.6) eşiğin ALTINDA kaldı — çünkü teal de
// altın da dikromazide aynı sarı-bej eksene düşüyor. Ayrımı üreten şey
// hue değil AYDINLIK.
//
// 🆕 SINIF: "DİKROMAZİDE İKİ RENGİ AYIRAN ŞEY HUE DEĞİL L*'DİR —
// 'FARKLI RENK SEÇTİM' DEMEK, RENK KÖRÜ BİR GÖZDE HİÇBİR ŞEY DEMEK
// DEĞİLDİR."
KOYU.purpleInk  = KOYU.ink;
KOYU.purpleUst  = KOYU.gold;
KOYU.purpleLine = KOYU.goldLine;
// 🔴 20 EYLÜL — AİLENİN KÖKÜ ATLANMIŞTI.
// Yukarıdaki dört satır 3 Eylül'de yazıldı ama BEŞİNCİSİ, ailenin kökü
// olan `purple`ın kendisi, satır 1452'de #B7A8C6 (LAVANTA, hue 310°)
// olarak kaldı. Ve dolgu olarak kullanılan tek jeton oydu:
// `ekranlar_ana.js`teki sohbet, kendi mesaj balonunu onunla boyuyordu.
// Sahneyi ölçtüm: 06b_sohbet_tanis'te 155.992 piksel hue 310° —
// ekranın EN BÜYÜK renk bloğu terk edilmiş dünyadandı. Üstelik üstüne
// `"#fff"` yazılıyordu: 2.23:1.
//
// 🆕 SINIF: "BİR JETON AİLESİNİ EŞLERKEN AİLENİN KÖKÜNÜ ATLARSAN, EN
// BÜYÜK YÜZEY ESKİ DÜNYADA KALIR — VE EŞLEME RAPORU YİNE DE 'TAMAM' DER."
KOYU.purple     = KOYU.gold;

// ══════════════════════════════════════════════════════════════════════
// Anahtar (Toggle) sahnesi — pist ve gökyüzü. Gece uçuşu.
//
// 🔴 20 EYLÜL — BU SAHNE DE LACİVERT DÜNYADAN KALMIŞTI.
// `gokMavi` #2E4A63 idi: hue 262°, sistem bandı 45-120°. Ayarlar
// ekranındaki HER anahtarda görünüyor — yani tek bir ekranda onlarca
// kez. Ölçtüm: 20_ayarlar'da bandın dışındaki renkli piksellerin
// %86'sı buydu.
//
// Hepsi L* KORUNARAK 86°'ye çevrildi — yani aydınlık/karanlık ilişkisi
// (dolayısıyla okunurluk ve anahtarın açık/kapalı okunması) AYNEN
// duruyor, yalnız hue döndü. Ölçüm:
//     gokMavi     L* 30.3 → 30.4   C* 18.1 → 18.3   hue 262° → 86°
//     pistAsfalt  L* 23.8 → 23.8   C*  7.4 →  7.2   hue 302° → 85°
//     pistUcak    L*  6.0 →  6.1   C*  5.8 →  5.9   hue 304° → 86°
//     pistIsik    L* 71.9 → 71.8   C* 44.2 → 26.4   hue  90° → 85°
// `pistIsik` zaten bandın içindeydi (90°) ama C* 44.2 ile marka
// tavanının (28) çok üstündeydi. Pist kenar ışığı bir IŞIK KAYNAĞI —
// en yüksek kromaya hakkı olan şey odur; bu yüzden tavana indirildi,
// tavanın altına değil.
// ══════════════════════════════════════════════════════════════════════
KOYU.pistAsfalt  = "#3E382E";
KOYU.pistIsik    = "#C5AD80";
KOYU.gokMavi     = "#53462B";
KOYU.pistUcak    = "#181308";

// ════════════════════════════════════════════════════════════════════
// TEMA MOTORU — ÇALIŞMA ANINDA AÇIK ⇄ KOYU
//
// 🔴 MİMARİ ENGELİ ÖNCE ÖLÇTÜM, SONRA ÇÖZDÜM.
// `C` bir modül sabiti ve 1270'ten fazla yerde `C.gold` gibi DOĞRUDAN
// okunuyor. React context'e taşımak 1270 çağrı yerini değiştirmek
// demekti — yani her biri ayrı bir kırılma riski.
//
// Ama `C.gold` bir DEĞER kopyası değil, her render'da yapılan bir
// OKUMA. Yani nesnenin İÇİNİ değiştirmek yeterli; nesnenin kendisini
// değiştirmek gerekmiyor. 1270 çağrı yerinin hiçbirine dokunulmuyor.
//
// İSTİSNA — ve asıl tuzak burada: değeri render'da değil, MODÜL
// YÜKLENİRKEN okuyan üç yapı var:
//     ACCENT · ELEV · BTN · C.yuzey · S (ortak.js) · st (App.js)
// Bunlar `C.gold`u bir kez okuyup kendi içine YAZIYOR. `C`yi
// değiştirmek onları değiştirmez. O yüzden her biri `temaYenidenKur`
// ile kayıt oluyor ve tema değişince İÇERİK olarak yeniden kuruluyor
// (nesne kimliği korunuyor — `...S.card` yapan yüzlerce yer bozulmasın).
//
// 🆕 SINIF: "BİR DEĞERİ RENDER'DA OKUYAN KOD TEMAYA HAZIRDIR; MODÜL
// YÜKLENİRKEN OKUYAN KOD DEĞİLDİR — FARKI BİLMEDEN ANAHTAR KOYARSAN
// EKRANIN YARISI DEĞİŞİR, YARISI DEĞİŞMEZ."
// ════════════════════════════════════════════════════════════════════

function _kopya(v) {
  if (Array.isArray(v)) return v.map(_kopya);
  if (v && typeof v === "object") {
    const o = {};
    for (const k of Object.keys(v)) o[k] = _kopya(v[k]);
    return o;
  }
  return v;
}

// AÇIK temanın anlık görüntüsü — BÜTÜN `C.*` atamaları bittikten SONRA
// alınıyor. Daha erken alınsaydı yarısı eksik olurdu.
const ACIK = {};
for (const k of Object.keys(C)) ACIK[k] = _kopya(C[k]);

export let TEMA_MOD = "acik";
export function temaModu() { return TEMA_MOD; }

const _kurucular = [];
const _dinleyiciler = new Set();

/** Modül yüklenirken `C`den okuyan yapılar buraya kaydolur. */
export function temaYenidenKur(fn) { _kurucular.push(fn); fn(); return fn; }
/** Tema değişince haber almak isteyen React bileşenleri. */
export function temaDinle(fn) { _dinleyiciler.add(fn); return () => _dinleyiciler.delete(fn); }

// `yuzey` ve `badge` C'nin içinde ama TÜRETİLMİŞ: `C`nin başka
// tokenlerinden hesaplanıyorlar. Anlık görüntüden geri yazılırlarsa
// eski temanın değerleriyle dolarlar; onun yerine yeniden kuruluyorlar.
const _TUREMIS = ["yuzey"];

export function temaUygula(mod) {
  const koyu = mod === "koyu";
  const kaynak = koyu ? KOYU : ACIK;
  // 🔴 4 Eylül — yalnız ACIK'ın anahtarları dolaşılıyordu: KOYU'ya eklenen
  // ama açık temada hiç tanımlanmamış bir token (`goldTrace` gibi) C'ye HİÇ
  // geçmiyordu; kod `C.goldTrace || C.goldLine` deyip sessizce kalın kenara
  // düşüyordu. İki temanın anahtar BİRLEŞİMİ dolaşılır.
  for (const k of new Set([...Object.keys(ACIK), ...Object.keys(KOYU)])) {
    if (typeof ACIK[k] === "function" || typeof KOYU[k] === "function" || _TUREMIS.indexOf(k) >= 0) continue;
    const v = kaynak[k] !== undefined ? kaynak[k] : ACIK[k];
    if (v && typeof v === "object" && C[k] && typeof C[k] === "object" && !Array.isArray(v)) {
      for (const kk of Object.keys(C[k])) delete C[k][kk];   // kimliği koru, içeriği değiştir
      Object.assign(C[k], _kopya(v));
    } else {
      C[k] = _kopya(v);
    }
  }
  TEMA_MOD = koyu ? "koyu" : "acik";
  _kurucular.forEach(f => { try { f(); } catch (e) {} });
  _dinleyiciler.forEach(f => { try { f(mod); } catch (e) {} });
}

// ── TÜRETİLMİŞ YAPILARIN YENİDEN KURULMASI ──────────────────────────
temaYenidenKur(() => {
  ACCENT.trip = C.teal; ACCENT.meet = C.purple; ACCENT.points = C.gold;
  ACCENT.success = C.green; ACCENT.warn = C.amber; ACCENT.danger = C.red;
});

temaYenidenKur(() => {
  // Koyu temada gölge SİYAH ve daha derin: mavi-gri bir gölge koyu
  // zeminde mor bir hale bırakıyor, kartı "kirli" gösteriyor. Ayrıca
  // koyu zeminde %5 opaklık görünmüyor — çarpan ölçülmüş bir sabit.
  const koyu = TEMA_MOD === "koyu";
  const renk = koyu ? KOYU.golgeRenk : "#1A1F2E";
  const carp = koyu ? KOYU.golgeCarp : 1;
  ELEV.card.shadowColor = renk;
  ELEV.card.shadowOpacity = 0.05 * carp;
  ELEV.raised.shadowColor = renk;
  ELEV.raised.shadowOpacity = 0.10 * carp;
  BTN.golge.shadowColor = C.goldGolge;
  // 🔴 12 EYLÜL · PARİTE TURU — BU SATIR BENİM KENDİ DEĞİŞİKLİĞİMİ EZİYORDU.
  // `BTN.golge`i 0.34 → 0.20'ye indirmiştim (şampanya parıltı yarıya insin
  // diye) ama tema yeniden kurulduğunda burası 0.46 yazıyordu. Yani jetonu
  // değiştirdim, jetonu HER TEMA DEĞİŞİMİNDE yeniden yazan satırı
  // görmedim; koyu temada parıltı hiç inmemişti.
  // 🆕 SINIF: "BİR DEĞERİ BAŞLANGIÇTA AYARLAYIP BİR YERDE YENİDEN
  // YAZIYORSAN, O DEĞERİN TEK KAYNAĞI BAŞLANGIÇ DEĞİL YENİDEN YAZAN
  // YERDİR — DEĞİŞİKLİĞİNİ ORAYA YAPMADIYSAN YAPMAMIŞSINDIR."
  BTN.golge.shadowOpacity = koyu ? 0.20 : 0.34;
});

temaYenidenKur(() => {
  // Kimliği koru, içeriği yeniden kur: `C.yuzey`e referans tutan kod
  // (nöbetçiler dahil) aynı nesneyi okumaya devam etsin.
  const y = kurYuzey();
  for (const k of Object.keys(C.yuzey)) delete C.yuzey[k];
  Object.assign(C.yuzey, y);
});


// ══════════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS — MODÜL YÜKLENİR YÜKLENMEZ KOYU.
//
// `TEMA_MOD` başlangıçta "acik" ve `C` de `ACIK`ten kuruluyordu.
// `tema_tercih.js` koyuyu ASENKRON uyguluyor (AsyncStorage bekliyor) —
// yani ilk kare AÇIK çiziliyor ve sonra koyuya atlıyordu. Kullanıcının
// gördüğü ilk şey bir yanıp sönme olurdu.
//
// 🆕 SINIF: "VARSAYILANI ASENKRON BİR YÜKLEYİCİYE BIRAKIRSAN,
// VARSAYILAN O YÜKLEYİCİ DÖNENE KADAR BAŞKA BİR ŞEYDİR."
//
// ⚠️ Bu satır kullanıcının TERCİHİNİ ezmez: `temaTercihYukle()` sonradan
// koşup kayıtlı tercihi (varsa) uygular. Burada kurulan yalnız ilk kare.
// ══════════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS · 2. TUR — MESH BAŞLIĞIN TABAN RENGİ.
//
// Tasarımdaki `.ust.mesh` dikey tabanı `linear-gradient(180deg,#1A1620
// 0%, var(--gece) 100%)`. Üst uç bir jeton değil, geçişin BAŞLANGICI —
// o yüzden kendi adıyla duruyor; `ui.js` 18 bantla buradan `C.bg`ye
// iniyor.
//
// Açık temada bu başlık da koyu kalıyor: bir mesh başlığın altında
// açık gövde, tasarımın kendi kararı (`.ust` her iki durumda koyu).
C.meshUst = "#1A1620";
KOYU.meshUst = "#1A1620";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1900 (v6 katmanı)
// 🔴 30 Ağu · 8. tur — "AN" EKRANININ KENDİ TABANI.
// Tasarımda başlık bandı ile "an" ekranı AYNI zemini kullanmıyor:
//   .ust.mesh    linear-gradient(180deg, #1A1620 0%, --gece 100%)
//   .mesh-yogun  linear-gradient(180deg, #241D26 0%, --gece  62%)
// İkincisi daha AÇIK başlıyor ve daha ERKEN bitiyor — çünkü orada
// okunacak veri yok, sahne var. Aynı jetonu iki yerde kullanmak,
// tasarımın bu ayrımını siler.
C.meshUst2 = "#241D26";
KOYU.meshUst2 = "#241D26";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1901 (v6 katmanı)

// `.ust-alt` — tasarımda `--sessiz` (#A79B8A). Yeni mesh zeminde ölçtüm:
// **4.41:1** — AA'nın (4.5) kıl payı altında. Bir tık açtım: **5.19:1**.
// Tasarımın rengini korumak, tasarımın okunmasını bozmak pahasına
// yapılacak bir sadakat değil.
C.meshAlt = "#B4A997";
KOYU.meshAlt = "#B4A997";

// Cam yüzeyin AÇIK tema karşılığı: fotoğraf her iki temada da aynı
// fotoğraf, yani zemin tema değil FOTOĞRAF. Değer aynı kalıyor — ve
// bu bir "aynı bıraktım" değil, bir karar: `temaUygula` iki paletin
// anahtar birleşimini dolaştığı için burada TANIMSIZ bırakmak, açık
// temaya geçildiğinde kartı şeffaflaştırırdı.
C.camKart  = "rgba(20,18,17,0.55)";
C.camKenar = "rgba(237,231,219,0.16)";
// Açık temada "ışık" yukarıdan değil zeminden gelir: kart zaten beyaz,
// üstüne ışık koymak hiçbir şey çizmez. Orada kenar İNCE BİR GÖLGEDİR.
C.kabartmaIsik = "rgba(255,255,255,0.70)";
C.kabartmaDip  = "rgba(26,31,46,0.10)";
C.kartKenar = "rgba(26,31,46,0.07)";
C.kartIsik  = "rgba(255,255,255,0.60)";
C.kartDip   = "rgba(26,31,46,0.05)";


// ══════════════════════════════════════════════════════════════════════
// v6.0.0 · SESSİZ LÜKS — OBSİDYEN & KADİFE KARAR KATMANI   (25 Eylül)
//
// Gökberk'in v6 brief'i: "çamurlu, doygunluğu düşük kahverengi/mor kart
// zeminleri, kutu kalabalığı ve sert çevreleme çizgileri."
//
// ÖLÇÜLDÜ — kahverengi/mor dediği şey tek tek jetonlardı:
//     goldBg   #292312  (zeytin-kahve)   amberBg #2C2214  (kahve)
//     goldTint #261C11  (kahve)          purpleBg #281D40 (mor → sonra goldBg)
//     tealBg   #112724  greenBg #12281D  redBg #391A1F
//     pasifRozet #3A332C · balonBen #241F19 · meshUst #1A1620 / #241D26 (mor)
// Her biri "durum" anlatmak için bir ZEMİN rengi kullanıyordu. Sessiz
// lüksta durum zeminle değil MÜREKKEPLE anlatılır: zemin tek (kadife),
// anlam metnin renginde ve tipografide.
//
// ÇİZGİ YOK: çizgi jetonları şeffaf. Ayrım iki şeyle kuruluyor:
//   · derinlik: obsidyen (#0B0A0B) → kadife (#141211) → kadife-2 (#181614)
//   · IŞIK: yalnız ÜST kenarda 1px speküler (`parlama`, %3.5 fildişi) —
//     saat kasasının elmas kesimli kenarı gibi. Çevre çizgisi değil.
//
// ⚠️ ERİŞİLEBİLİRLİK BEDELİ AÇIKÇA: WCAG 1.4.11 etkileşimli öğenin
// sınırının 3:1 görünmesini ister. Çizgisiz giriş alanı ve seçim hapı bunu
// ZEMİNLE (kadife üstü obsidyen 1.2:1) karşılamaz; karşılığı: yer tutucu
// metin + odakta fildişi parıltı + seçilide mürekkep ve ağırlık değişimi.
// Seçililik hiçbir yerde yalnız renkle anlatılmıyor (radyo noktası kaldı).
// ══════════════════════════════════════════════════════════════════════
const V6_KADIFE  = "#141211";
const V6_KADIFE2 = "#181614";
const V6_YOK     = "rgba(0,0,0,0)";
KOYU.bg         = "#0B0A0B";
KOYU.surface    = V6_KADIFE;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1939
KOYU.surfaceAlt = V6_KADIFE2;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1940
KOYU.card       = V6_KADIFE;
KOYU.bgAlt      = V6_KADIFE2;
KOYU.avatarBg   = V6_KADIFE2;
for (const k of ["goldBg", "amberBg", "goldTint", "greenBg", "purpleBg", "tealBg", "tealTint", "tealTint2"]) KOYU[k] = V6_KADIFE2;
// Seçili yüzey: kadifenin bir basamak AYDINLIĞI (kahve değil — ton aynı,
// yalnız ışık fazla). Çerçeve kalkınca seçimi çizgi değil bu ışık taşır.
KOYU.goldSoft   = "#1E1B19";   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1942
KOYU.redBg      = "#1A1413";          // SOS/engel: kadifenin yalnız bir tık sıcağı — alarm mürekkepte   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1943
KOYU.hataBg     = KOYU.redBg;
KOYU.pasifRozet = V6_KADIFE2;
KOYU.balonBen   = V6_KADIFE2;
for (const k of ["line", "line2", "kartKenar", "goldLine", "amberLine", "tealLine",
                 "purpleLine", "camKenar", "goldTrace", "hataLine", "warmLine"]) KOYU[k] = V6_YOK;
KOYU.parlama    = "rgba(244,239,230,0.035)";   // brief'in değeri — üst kenar ışığı   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1944
KOYU.parlamaGuc = "rgba(244,239,230,0.07)";    // basılı / seçili hâlde ışık iki katı   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1945
KOYU.kartIsik   = KOYU.parlama;   // ⛔ ÖLÜ ATAMA — geçerli değer satır 1946
KOYU.kabartmaIsik = "rgba(244,239,230,0.09)";  // rozet mührü: kabartmanın üst sırtı
KOYU.kabartmaDip  = "rgba(0,0,0,0.30)";        // … ve bastırılmış alt gölgesi
KOYU.fildisi    = "#EDE7DB";                   // mühür mürekkebi (fildişi krem)
KOYU.muhurZemin = "rgba(237,231,219,0.06)";
KOYU.camKart    = "rgba(20,18,17,0.55)";       // dumanlı cam (host balonu)
KOYU.isikSizinti = "#C9B693";                  // ortam ışığı — dokununca sızar (≤ %12)
KOYU.onGoldSoluk = "rgba(23,18,11,0.62)";       // şampanya balon üstünde saat
KOYU.meshUst    = "#12100F";                   // mor mesh → sıcak obsidyen
KOYU.meshUst2   = "#171412";
// Rozetler: çerçeve yok, zemin tek, anlam mürekkepte. Nane yeşili ve
// turuncu (fintech) mühür diline çekildi: onay = fildişi, ücret = şampanya.
KOYU.badgeInk = { ok: "#EDE7DB", cost: "#D6C3A0", unknown: "#B0A296", block: "#D9A9A4", info: "#DDD6CD" };
KOYU.badge = {
  ok:      { fg: KOYU.badgeInk.ok,      bg: KOYU.muhurZemin, bd: V6_YOK },
  cost:    { fg: KOYU.badgeInk.cost,    bg: "rgba(214,195,160,0.06)", bd: V6_YOK },
  unknown: { fg: KOYU.badgeInk.unknown, bg: "rgba(176,162,150,0.06)", bd: V6_YOK },
  block:   { fg: KOYU.badgeInk.block,   bg: "rgba(217,169,164,0.07)", bd: V6_YOK },
  info:    { fg: KOYU.badgeInk.info,    bg: KOYU.muhurZemin, bd: V6_YOK },
};
C.parlama = "rgba(255,255,255,0.60)";
C.parlamaGuc = "rgba(255,255,255,0.80)";
C.fildisi = "#1A1F2E";
C.muhurZemin = "rgba(26,31,46,0.05)";
C.isikSizinti = "#C9B693";
C.onGoldSoluk = "rgba(255,255,255,0.70)";
C.golgeRenk = "#1A1F2E";


// ══════════════════════════════════════════════════════════════════════
// v6.1 · IŞIKLI KADİFE — cihaz geri bildirimi (26 Eylül)
// Gökberk: "popuplar çok karanlık, çerçevesi belli olmuyor", "sohbete dön
// butonu belli olmuyor", "profil düzenleme çok karanlık, alanlar belirsiz".
// Haklı: v6'da kadife (#141211) obsidyenden yalnız ΔE 3 ayrışıyordu —
// OLED'de, gece, parlaklık düşükken sıfır. Sessiz lüks görünmezlik değil.
//
// Derinlik merdiveni (her basamak bir öncekinden ölçülür biçimde açık):
//   zemin #0B0A0B → kart #171512 → iç blok/girdi #1F1C19 → seçili #262320
//   popup #1E1B18 (+ ışık kenarı)
// Üst ışık %3.5 → %6. Etkileşimli ikincil yüzeyler (hayalet düğme, girdi,
// popup) bir IŞIK KENARI alır (fildişi %12): kutu çizgisi değil, parmağın
// "buraya basılır" diye okuduğu yansıma. Kartlarda çevre çizgisi yok.
// ══════════════════════════════════════════════════════════════════════
const V61_KART = "#171512", V61_BLOK = "#1F1C19", V61_SECILI = "#262320";
KOYU.surface = V61_KART; KOYU.card = V61_KART;
KOYU.surfaceAlt = V61_BLOK; KOYU.bgAlt = V61_BLOK; KOYU.avatarBg = V61_BLOK;
for (const k of ["goldBg", "amberBg", "goldTint", "greenBg", "purpleBg", "tealBg", "tealTint", "tealTint2", "pasifRozet", "balonBen"]) KOYU[k] = V61_BLOK;
KOYU.goldSoft = V61_SECILI;
KOYU.redBg = "#221816"; KOYU.hataBg = KOYU.redBg;
KOYU.parlama = "rgba(244,239,230,0.06)";
KOYU.parlamaGuc = "rgba(244,239,230,0.12)";
KOYU.kartIsik = KOYU.parlama;
KOYU.kenarIsik = "rgba(237,231,219,0.12)";      // ikincil düğme · girdi · popup
KOYU.line = "rgba(237,231,219,0.06)";           // girdi/ayırıcı: görünür ama sessiz
KOYU.line2 = "rgba(237,231,219,0.09)";
KOYU.goldLine = "rgba(214,195,160,0.38)";       // seçili hâlin ışık kenarı
KOYU.camKenar = "rgba(237,231,219,0.12)";
KOYU.popupZemin = "#1E1B18";
KOYU.perdeRenk = "rgba(6,5,6,0.62)";            // popup arkası (bulanıklığın üstü)
C.kenarIsik = "rgba(26,31,46,0.14)";
C.popupZemin = "#FFFFFF";
C.perdeRenk = "rgba(26,31,46,0.40)";

temaUygula("koyu");
