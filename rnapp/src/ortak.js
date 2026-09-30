// ============================================================================
// ortak.js — KATMAN 0: hicbir yerel bagimliligi olmayan atomlar
//
// 🔴 NEDEN BU DOSYA VAR (24 Agustos 2026 · elestiri D2)
// `screens.js` 12.802 satirdi. Gokberk "mimari kararlarini sana birakiyorum"
// dedi; ben de once BOLDUM demeden OLCTUM.
//
// OLCUM (bagimlilik grafi, 91 ust seviye bildirim):
//     katman 0 : 32 bildirim ·   587 satir  — hicbir yerel bagimliligi yok
//     katman 1 : 21 bildirim ·  2052 satir  — yalniz katman 0'a bagli
//     katman 2 :  8 bildirim ·  1575 satir
//     katman 3 :  2 bildirim ·   238 satir
//     DONGUSEL CEKIRDEK: 28 bildirim · 8319 satir  (%65)
//
// Yani dosya "kimse bolmedigi icin" degil, EKRANLAR BIRBIRINE BAGLI oldugu
// icin buyuk. Cekirdegi temaya gore bolmek, dosya ICI bagimliligi DOSYALAR
// ARASI DONGUYE cevirirdi: ayni baglilik + modul yukleme sirasi riski.
//
// 🆕 SINIF: "BIR DOSYAYI BOLMEK, ICINDEKI BAGIMLILIKLARI COZMEZ —
// YALNIZCA ONLARI DOSYALAR ARASI YAPAR."
//
// Bu yuzden yalniz KATMANLI kismi cikardim (%35). Cikan her sey bir DAG:
// bu dosya `screens.js`ten HICBIR SEY import etmez, dolayisiyla dongu
// matematiksel olarak imkansiz. `bagimlilik_check.py` bunu her kosuda
// dogruluyor ve dongusel cekirdegin BUYUMESINI de engelliyor.
// ============================================================================
import { AramaKutusu, Katlanir, eslesir } from "./Pickers";
import { fmtLongDate, mapErr, BUYUK, gorunur } from "./i18n";
import { LEGAL_DOCS, LEGAL_ORDER, LEGAL_VERSION } from "./legal";
import { bayrak } from "./runtime";
// `ui.js` ortak.js'i içe AKTARMIYOR — yön tek, döngü yok (bagimlilik_check ölçüyor).
import { Ikon, IkonMetin } from "./ikon";
import { logError, supabase } from "./supabase";
import { bildirimAyarlariniAc, pushIzniIste, pushDurumOku } from "./push";
import { ARA, C, ELEV, F, FS, R, SP, T, TAP, temaYenidenKur } from "./theme";
import { MONO } from "./typography";
import { Btn, Hdr, Sayfa, MarkaYukleyici, Serit } from "./ui";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Platform, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from "react-native";

// ══════════════════════════════════════════════════════════════════════
// 🔴 28 EYLÜL (Gökberk: "keşfetteki alanların çerçeveleri dar ve dikdörtgen,
// sert") — v6 kadife kartın ışığı YALNIZ ÜST kenarda (`borderTopWidth`).
// Android yuvarlak köşeli kutuda tek kenarlı kenarlığı köşeyi izlemeden
// çiziyor: üstte köşelerde kesilen düz, sert bir şerit. Web doğru çizdiği
// için sahnede görünmedi. Android'de ışık artık köşeyi izleyen saç teli
// tam kenarlık; iOS'ta tasarımın üst ışığı aynen.
// ══════════════════════════════════════════════════════════════════════
export const ustIsik = (renk) => Platform.OS === "android"
  ? { borderWidth: StyleSheet.hairlineWidth, borderColor: renk }
  : { borderWidth: 0, borderTopWidth: 1, borderTopColor: renk };

export { C, F, ACCENT } from "./theme";

// ════════════════════════════════════════════════════════════════════
// 🔴 `S` DEĞERLERİ MODÜL YÜKLENİRKEN OKUYOR — TEMA ANAHTARININ EN
// SESSİZ TUZAĞI BURASIYDI.
// `S.card` içindeki `backgroundColor: C.surface`, dosya yüklendiği an
// bir KOPYA alıyor. `C`yi sonradan değiştirmek `S`yi değiştirmiyor.
// Yani anahtar konsaydı ekranın satır içi renkleri değişir, ortak
// stiller AÇIK TEMADA KALIRDI — yarısı gece yarısı gündüz bir arayüz.
//
// Çözüm nesneyi DEĞİŞTİRMEK değil İÇİNİ yenilemek: `S`ye referans
// tutan yüzlerce `...S.card` yayılımı aynı nesneyi okumaya devam ediyor.
//
// 🆕 SINIF: "TEMA DEĞİŞTİRİLEBİLİR YAPMAK, RENGİ DEĞİŞTİRMEK DEĞİL —
// RENGİ KOPYALAMIŞ HER YAPIYI BULUP ONA DA HABER VERMEKTİR."
// ════════════════════════════════════════════════════════════════════
function kurS() {
  return {
  h1: { ...T.title, fontWeight: "700", color: C.ink },
  // v2.65 — ikincil metinler okunur katmana geçti (C.mut 4.4:1 -> mutedAA 5.66:1)
  sub: { ...T.sm, color: C.mutedAA, marginTop: SP[1] / 2, marginBottom: SP[4] },
  label: { ...T.label, color: C.mutedAA, marginTop: SP[4], marginBottom: SP[2] - 2 },
  // ══════════════════════════════════════════════════════════════════
  // 🔴 v3.6 — BU ÜÇ SATIR, R ÖLÇEĞİNİN ÜST BASAMAKLARINI ÖLDÜRÜYORDU.
  //
  // `R` altı basamak tanımlıyor ve her birinin YAZILI bir işi var:
  //     sm 14 "giriş alanı" · md 20 "düğme" · lg 26 "kart, kutu, uyarı"
  // Ama uygulamadaki üç çapa stil de 14'te duruyordu: kart 14, düğme 14,
  // giriş 10. Bütün ekranlar bunları kopyaladığı için 424 yarıçap
  // kullanımının 322'si 10 veya 14 — ve `lg`(26) yalnız 2, `xl`(32)
  // yalnız 2 kez geçiyor.
  //
  // Sonuç: derinlik hiyerarşisi DÜZ. Bir modal, bir kart ve bir giriş
  // alanı aynı köşeyle çiziliyor; göz hangisinin daha "üstte" olduğunu
  // köşeden okuyamıyor.
  //
  // 🆕 SINIF: "BİR ÖLÇEĞİN ÜST BASAMAKLARI KULLANILMIYORSA ÖLÇEK ALTI
  // BASAMAKLI DEĞİL İKİ BASAMAKLIDIR — VE ÇAPA STİLLER YANLIŞ BASAMAKTA
  // DURUYORSA BÜTÜN KOPYALARI DA ORADA DURUR."
  //
  // ⚠️ ÖLÇÜLÜ DEĞİŞİKLİK: yalnız köşe değişti. Zemin, kenarlık, gölge,
  // dolgu — hepsi aynı. Kontrast ölçümleri etkilenmiyor.
  // ══════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL · GECE — GİRİŞ ALANINDAN ÇİZGİ KALKTI (Gökberk onayı).
  //
  // "Modern Glow" önerisinin tamamı reddedildi; Gökberk yalnız BU
  // maddeyi onayladı — ve ölçüm onu destekliyor:
  //
  //   eski kenarlık `C.line` #211E1C, kart zemininde  1.13:1
  //   yeni dolgu    `C.bgAlt` #1B1816, sayfa zemininde 1.12:1
  //
  // Yani kaldırdığımız çizgi zaten GÖRÜNMÜYORDU (1.13:1). Onun yerine
  // aynı kontrastta ama ALAN kaplayan bir yüzey koyuyoruz; göz bir
  // hattı değil bir şekli daha kolay seçer.
  //
  // ⚠️ DÜRÜST SINIR: ikisi de WCAG 1.4.11'in metin dışı 3:1 eşiğini
  // geçmiyor ve bu palette geçemez — 3:1 için dolgunun #3A3633
  // civarına çıkması gerekirdi, o da obsidyeni griye çevirir.
  // Süpürdüm: yer tutucu (`dimAA`) AA'da kalarak gidilebilecek en açık
  // dolgu #1F1C19 (ayrışma 1.17, yer tutucu 4.56). Kazanç +0.05;
  // palete yeni bir jeton sokmaya değmez, `bgAlt` kalıyor.
  //
  // Gölge de kalktı: bir giriş alanı sayfadan YÜKSELMEZ, gömülür.
  // (Aynı gerekçe `yuzey_check.py`de 31 Ağustos'ta yazılmıştı.)
  //
  // 🆕 SINIF: "BİR ÇİZGİYİ KALDIRMADAN ÖNCE O ÇİZGİNİN GÖRÜNÜP
  // GÖRÜNMEDİĞİNİ ÖLÇ — GÖRÜNMEYEN BİR SINIRI SAVUNMAK, OLMAYAN BİR
  // ŞEYİ KAYBETMEKTEN KORKMAKTIR."
  // ══════════════════════════════════════════════════════════════════
  input: { backgroundColor: C.bgAlt, borderRadius: R.lg, borderWidth: 0,
           paddingVertical: SP[3], paddingHorizontal: SP[4] - 2, ...T.lg, color: C.ink },
  // 🔴 12 EYLÜL — KART KENARI `C.warmLine`DAN `C.kartKenar`A GEÇTİ.
  // Ölçüm: eski kenar kartın kendi zemini üstünde ΔE 20.36 (sıcak sarı
  // bir çizgi), yenisi ΔE 3.91. Tek satır, ama bu stili 100+ kart
  // kopyalıyor — yani "kutu cümbüşü"nün en büyük tek kalemi burası.
  // v6 — kadife kart: çevre çizgisi yok; yalnız ÜST kenarda 1px speküler ışık
  card: { backgroundColor: C.camYuzey || C.surface, ...ustIsik(C.parlama || C.kartKenar), borderRadius: R.lg,
          // tasarım `.kart{padding:17px;margin-bottom:13px}` — 16/12 en
          // yakın ölçek basamağı (ARA 2'nin katları). 10'du; kartlar
          // arası boşluk tasarımdakinden dardı.
          padding: SP[4], marginBottom: ARA[12], ...ELEV.card },
  // 🔴 v2.65 — ANA CTA ZEMİNİ. C.gold + beyaz metin = 2.86:1 (AA 4.5 ister).
  // C.goldBtn ile 5.15:1. Altın İŞARET rengi (C.gold) marka çapası olarak
  // her yerde duruyor; değişen yalnız METİN TAŞIYAN zemin.
  // minHeight: dokunma hedefi — paddingVertical tek başına 44'ü garanti etmiyordu.
  // 🔴 v3.6 — `S.btn` / `S.btnText` ARŞİVE ALINDI (bkz. _yedek_ui/).
  // İkisinin de çağrı yeri SIFIRDI. Doğru yol `Btn` bileşeni: kontrast
  // düzeltmesi (C.goldBtn + C.onAccent = 5.15:1), 44pt dokunma hedefi ve
  // meşgul durumu ORADA yaşıyor. Burada ikinci bir tanım tutmak, ileride
  // birinin yanlış olanı seçmesini garanti ediyordu.
  // 🆕 SINIF: "AYNI İŞİN İKİ TANIMI VARSA, BİRİ ÇAĞRILMIYOR OLSA BİLE
  // TEHLİKELİDİR — ÇÜNKÜ BİR GÜN ÇAĞRILACAKTIR."
  empty: { padding: SP[6], alignItems: "center", backgroundColor: C.camYuzey || C.surface, ...ustIsik(C.parlama || "transparent"), ...ELEV.card,
           borderRadius: R.lg },
  // 🔴 v2.78 — ÇİPLERİN DOKUNMA HEDEFİ 44pt'NİN ALTINDAYDI.
  // Ölçüm: `paddingVertical: SP[2]` = 8 → yaklaşık 32pt. 33 çip düğmesinden
  // yalnız 2'si satırında `minHeight` ekliyordu; yani 31 çip standardın
  // altındaydı. Çipler bu üründe süs değil: havayolu seçimi, kabin sınıfı,
  // seyahat amacı, görünürlük — hepsi çip. Yanlış çipe basmak yanlış KURAL
  // demek. Tek yerden düzeltiliyor; `TAP.minHeight` zaten tek kaynak.
  // ══════════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS · 2. TUR — ÇİP İLE ROZETİ AYIRDIM (ÖNCE KARIŞTIRMIŞTIM).
  //
  // İlk denememde `S.chip`i doğrudan tasarımın `.roz`una çevirdim: hap
  // yarıçapı, 10.5 punto, 44px `minHeight` kaldırıldı. Sonra durup
  // tasarıma tekrar baktım — orada İKİ AYRI SINIF var ve ben ikisini
  // tek şey sanmışım:
  //
  //   .roz  10.5/600 · 5×10 dolgu · KART İÇİ DURUM ETİKETİ
  //         ("Misafir ücretsiz" · "TK1978" · "Aynı uçuş")
  //   .cip  12/500   · 9×14 dolgu · DOKUNULAN DENETİM
  //         (sohbetteki hazır cevaplar, filtre satırı)
  //
  // Rozeti küçültmek doğruydu; filtre çipini de küçültmek, tıklanan bir
  // denetimi 44px'ten 26px'e indirmek olurdu. Tasarım onları farklı
  // yaptıysa sebebi var: biri OKUNUR, öteki DOKUNULUR.
  //
  // 🆕 SINIF: **"AYNI GÖRÜNEN İKİ ÖĞEDEN BİRİ TIKLANIYORSA ONLAR AYNI
  // ÖĞE DEĞİLDİR — BENZERLİK BİÇİMDE, FARK İŞLEVDEDİR VE ÖLÇÜYÜ İŞLEV
  // BELİRLER."**
  //
  // `S.chip` denetim olarak KALDI (44px, dokunulabilir).
  // `S.roz` kart içi etiket olarak eklendi.
  chip: { ...ustIsik(C.parlama || "transparent"), borderRadius: R.full, paddingVertical: SP[2],
          paddingHorizontal: ARA[14], backgroundColor: C.surface,
          minHeight: TAP.minHeight, justifyContent: "center",
          marginRight: SP[2], marginBottom: SP[2] },
  // Tasarımdaki `.roz` — kart içi durum etiketi. Gölge YOK: rozet
  // kartın düzleminde duruyor, üstünde yüzmüyor.
  roz: { borderWidth: 0, borderRadius: R.full,
         paddingVertical: ARA[6], paddingHorizontal: ARA[10],
         backgroundColor: "transparent", justifyContent: "center" },
  chipOn: { borderTopColor: C.parlamaGuc || C.gold, ...(Platform.OS === "android" ? { borderColor: C.parlamaGuc || C.gold } : null), backgroundColor: C.surfaceAlt },
  err: { backgroundColor: C.hataBg, borderRadius: R.xs, padding: SP[3] - 1, marginTop: SP[3] },
  pickBtn: { backgroundColor: C.surface, ...ustIsik(C.parlama || "transparent"), borderRadius: R.sm,
             paddingVertical: SP[3] + 1, paddingHorizontal: SP[4] - 2, ...ELEV.card },};
}

export const S = kurS();
temaYenidenKur(() => {
  const y = kurS();
  for (const k of Object.keys(S)) delete S[k];
  Object.assign(S, y);
});
export const dateOk = s => /^\d{4}-\d{2}-\d{2}$/.test(s);
export function greeting(t) {
  const h = new Date().getHours();
  if (h < 6) return t.greetNight;
  if (h < 12) return t.greetMorning;
  if (h < 18) return t.greetDay;
  return t.greetEvening;
}

// v2.87 (madde 11): `onMeet` imzadan ÇIKARILDI. Seyahat kartındaki tek
// yönlendirme artık Keşfet; Tanış'a giden ◈ düğmesi kaldırıldığı için prop
// gövdede okunmuyordu. Okunmayan bir prop, bir sonraki geliştiriciye
// "burada bir bağlantı var" diye yalan söyler.
// 🔴 v2.99 — BU BILESEN BASLIGI DA YUTUYORDU VE iOS'TA CIKISSIZ EKRAN
// URETIYORDU.
//
// Olcum: 16 ekran `if (!veri) return <Load />;` yaziyor ve bu satir `Hdr`dan
// ONCE donuyor. Yani veri gelmezse ne baslik, ne geri oku, ne yeniden dene.
// Android'de donanim geri tusu kurtariyor; iOS'ta HICBIR CIKIS YOK.
//
// Garantili vaka: `Profile` — `profiles` satiri henuz olusmamis yeni bir
// hesapta `p` null kalir ve Profil sekmesi kalici olarak spinner olur.
// Ustelik CIKIS YAP ve HESAP SIL'in tek yolu o sekme.
//
// 🆕 SINIF: "YUKLENIYOR DURUMU BIR EKRANIN YERINE GECIYORSA, O EKRANIN
// CIKISINI DA YUTAR."
//
// `t` ve `onBack` verildiginde baslik cizilir. Vermeyen eski cagri yerleri
// aynen calisir (govde ici kucuk bir yukleme gostergesi olarak dogru).
// 🔴 v3.4 — "YÜKLENİYOR" ÜÇ KEZ YAZIYORDU.
//
// Gökberk (28 Ağu): "hem yükleniyor yazıyor üstte hem de ortada spinner
// dönüyor. Yine loungelink başlığı da yükleniyorun üstünde mesela."
//
// Haklı ve sebebi BENİM v2.99 düzeltmemdi. O turda 16 ekran çıkışsız
// spinner gösteriyordu; başlık ekledim — ama başlığa ekranın KENDİ adını
// değil `t.loading`i geçtim. Sonuç: marka çubuğu + "Yükleniyor…" başlığı +
// dönen gösterge. Aynı bilgi üç kez, ve ikisi bilgi bile değil.
//
// 🆕 SINIF: "BİR EKSİĞİ KAPATIRKEN ORAYA EN KOLAY BULDUĞUN METNİ KOYARSAN,
// EKSİĞİ TEKRARLA DEĞİŞTİRMİŞ OLURSUN."
//
// Artık: başlık EKRANIN ADI (yani kullanıcı nerede olduğunu bilir ve geri
// dönebilir), ortada da yalnız marka göstergesi. "Yükleniyor" kelimesi
// hiçbir yerde yazmıyor — dönen bir şey zaten onu söylüyor.
//
// `baslik` verilmezse `t.loading`e DÜŞMÜYORUZ: başlıksız ama geri oklu bir
// çubuk çiziyoruz. Çıkış korunur, tekrar geri gelmez.
export function Load({ t, title, onBack, gosterge: ozelGosterge, icerik }) {
  // v6.2 — ekran kendi bekleme anlatımını verebilir (Keşfet: terminal radarı · K3).
  const gosterge = (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center", minHeight: 120 }}>
      {ozelGosterge || <MarkaYukleyici />}
    </View>
  );
  // ══════════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS — YÜKLENİRKEN ÜÇ BAŞLIK ÜST ÜSTE BİNİYORDU.
  //
  // Ekranda şu görünüyordu: LOUNGELINK · LOUNGELINK · Profil · dönen işaret.
  // İlk çubuk sekme kabuğunun, ikincisi buranın, "Profil" de yine buranın.
  //
  // 28 Ağustos'ta "çıkışsız spinner" sorununu çözerken buraya BAŞLIK
  // eklemiştim. Çözüm doğruydu ama fazlasını yaptı: kabuk zaten hem markayı
  // hem sekmeyi gösteriyor; yükleme anında ekranın adını TEKRAR yazmak
  // bilgi vermiyor, gürültü üretiyor.
  //
  // 🆕 SINIF: **"BİR EKSİĞİ KAPATAN ÇÖZÜM, KAPATTIĞINDAN FAZLASINI
  // EKLİYORSA YENİ BİR EKSİKTİR — SADECE TERS YÖNDE."**
  //
  // Yeni kural, Gökberk'in istediği yapı (ekran görüntüsü "8"):
  //   · sekme içindeyken  → YALNIZ dönen işaret. Kabuk zaten konumu söylüyor.
  //   · itilmiş ekranda   → yalnız GERİ OKU + işaret. Çıkış korunur,
  //                          marka çubuğu tekrarlanmaz, başlık yazılmaz.
  // ══════════════════════════════════════════════════════════════════
  // ⚠️ `<Sayfa>` HER İKİ DALDA DA DURUYOR — ve bunu nöbetçi öğretti.
  // İlk yazımda sekme içindeki dalda `<Sayfa>`yı da attım; `mount_test`
  // hemen kırmızı yandı: "Profile · ATMOSFER YOK — bu ekran <Sayfa>
  // kullanmıyor". Haklıydı: `<Sayfa>` bir başlık değil, sayfanın ZEMİNİ.
  // Başlığı kaldırmak isterken zemini kaldırmışım — ekran, kabuğun
  // olmadığı her yerde (ör. birim testi, tam ekran itilmiş görünüm)
  // boyasız kalırdı.
  //
  // 🆕 SINIF: "BİR SARMALAYICIYI KALDIRIRKEN NE ÇİZDİĞİNİ SOR —
  // 'BAŞLIK' SANDIĞIN KATMAN SAYFANIN KENDİSİ OLABİLİR."
  // 🔴 29 EYLÜL (Gökberk md.8: "Tanış'taki loading'de bozukluk var") — içerik
  // İÇİNDE (bandın altında, listenin yerinde) çağrılan yükleyici de tam bir
  // `<Sayfa>` çiziyordu: zemin + atmosfer (bulut, zerre) 120 px'lik bir kutuya
  // sıkışıp listenin ortasında ikinci bir "sayfa" gibi duruyordu.
  // `icerik`: yalnız işaret; zemin ve atmosfer zaten dıştaki sayfanın.
  if (icerik) return gosterge;
  if (!onBack) return <Sayfa>{gosterge}</Sayfa>;
  return (
    <Sayfa>
      <Hdr t={t} onBack={onBack} marka={false} title=" " />
      {gosterge}
    </Sayfa>
  );
}

// MVP Host Bul filtresi: Sektör CHIP seçenekleri (profession ilike eşleşir)
export const SECTOR_OPTS = ["Teknoloji", "Finans", "Danışmanlık", "Sağlık", "Hukuk"];

// ------------------------------------------------------------
// v2.87 — HAVAYOLU ÇİPİ (Gökberk madde 5)
// ------------------------------------------------------------
// "ilana ait havayolu firmasının daha belirgin ve açık belirtilmesi lazım.
//  Biliyosun kurallardan birinde THY'li AJet'liyi alamıyor."
// Taşıyıcı, kural motorunun en sert girdilerinden biri ama kartta hiç
// görünmüyordu. Tek bir çip: kod + (varsa) ad. Ad sözlüğü yoksa kod tek
// başına çizilir — bilgiyi hiç göstermemektense kısaltmayla göstermek yeğdir.
//
// `code` YOKSA çip HİÇ çizilmez: "havayolu belirtilmemiş" diye boş bir çip
// koymak, ilanın taşıyıcısı varmış gibi bir izlenim bırakır.
// 30 Eylül (Gökberk md.3) — havayolu seçilince uçuş kutusuna ÖNEK yazılıyor ("TK");
// rakam girilmezse "TK" UÇUŞ NUMARASI diye kaydediliyordu ve kartın köşesinde
// anlamsız bir kod olarak duruyordu. Rakamsız değer uçuş numarası değildir.
export function ucusNo(s, bos = null) {
  const v = String(s || "").replace(/\s+/g, "").toUpperCase();
  return /\d/.test(v) ? v : bos;
}

export function CarrierChip({ code, map, t, tone = "gold" }) {
  if (!code) return null;
  const ad = (map && map[code]) || null;
  const fg = tone === "purple" ? C.purple : C.gold;
  const bg = tone === "purple" ? C.purpleBg : C.goldSoft;
  return (
    <View style={[S.roz, { alignSelf: "flex-start", flexDirection: "row", alignItems: "center",
                           backgroundColor: bg, borderColor: fg + "55" }]}>
      <IkonMetin ad="ucus" renk={fg} stilMetin={{ color: fg, fontSize: FS.xs, fontWeight: "600", letterSpacing: 0.3 }} metin={`${String(code).toUpperCase()}${ad ? ` · ${ad}` : ""}`} />
    </View>
  );
}

// ------------------------------------------------------------
// v2.87 — "BEN NEREDEYİM?" ROZETİ (Gökberk madde 9)
// ------------------------------------------------------------
// "2'de 2 dolu olmasına rağmen sohbeti aç falan geliyo garip değil mi.
//  Bu ilana kabul alan kişilerden olup olmadığımı anlamıyorum."
// Kök neden: kart yalnızca KAPASİTEYİ anlatıyordu (2/2 dolu) ve izleyicinin
// KENDİ durumunu yalnız DOLAYLI olarak, hem de sadece slot açıkken
// gösteriyordu (`open > 0 ? ... : null`). Dolu ilanda kullanıcı kendi
// başvurusunun ne olduğunu göremiyordu — "dolu" ile "beni almadılar"
// arasındaki farkı okumanın hiçbir yolu yoktu.
// Dört durumun DÖRDÜ de yazılıyor; "başvurmadın" da bir cevaptır.
// v6.3 (md.9 · katman kuralı) — aynı durum, kutusuz: DurumSatiri öğesi.
export function reqDurumOgesi(status, t) {
  return status === "accepted"  ? { metin: t.reqStateAccepted, ton: "olmus" }
       : status === "pending"   ? { metin: t.reqStatePending, ton: "bekliyor" }
       : status === "declined"  ? { metin: t.reqStateDeclined, ton: "engel" }
       : status === "cancelled" ? { metin: t.reqStateCancelled, ton: "sessiz" }
       :                          { metin: t.reqStateNone, ton: "sessiz" };
}
export function ReqStateBadge({ status, t }) {
  const [lab, fg, bg] =
      status === "accepted"  ? [t.reqStateAccepted, C.green, C.greenBg]
    : status === "pending"   ? [t.reqStatePending,  C.amber, C.amberBg]
    : status === "declined"  ? [t.reqStateDeclined, C.red,   C.redBg]
    : status === "cancelled" ? [t.reqStateCancelled, C.mut,  C.bgAlt]
    :                          [t.reqStateNone,     C.mut,  C.bgAlt];
  return (
    <View style={[S.roz, { alignSelf: "flex-start", backgroundColor: bg,
                           borderColor: fg + "40" }]}>
      <Text style={{ color: fg, fontSize: FS.xs, fontWeight: "600", letterSpacing: 0.3 }}>{lab}</Text>
    </View>
  );
}
export function abbrevName(n) {
  if (!n) return "—";
  const parts = String(n).trim().split(/\s+/);
  if (parts.length < 2) return parts[0];
  return parts[0] + " " + parts[parts.length - 1].charAt(0).toUpperCase() + ".";
}
// lang: tarih biçimi için (fmtLongDate). Verilmezse fmtLongDate TR'ye düşer.
export function useUnread(session) {
  const uid = session?.user?.id;
  const [n, setN] = useState(0);
  const load = useCallback(async () => {
    if (!uid) return;
    const { count, error: hata1 } = await supabase.from("notifications")
      .select("*", { count: "exact", head: true }).eq("user_id", uid).eq("read", false);
      if (hata1) logError("ortak.js:320", hata1);
    setN(count || 0);
  }, [uid]);
  useEffect(() => {
    if (!uid) return;
    load();
    const iv = setInterval(load, 12000);
    let sub;
    // Realtime aboneliğini geciktir + tamamen izole et (APK'da beyaz ekran riskine karşı)
    const timer = setTimeout(() => {
      try {
        sub = supabase.channel("notif-" + uid)
          .on("postgres_changes", { event: "INSERT", schema: "public", table: "notifications", filter: `user_id=eq.${uid}` }, load)
          .subscribe();
      } catch (e) {}
    }, 2000);
    return () => { clearInterval(iv); clearTimeout(timer); try { if (sub) supabase.removeChannel(sub); } catch (e) {} };
  }, [load, uid]);
  return [n, load];
}
export function timeAgo(ts, t) {
  const s = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
  if (s < 60) return t.justNow;
  if (s < 3600) return Math.floor(s/60) + " " + t.minsAgo;
  if (s < 86400) return Math.floor(s/3600) + " " + t.hrsAgo;
  return Math.floor(s/86400) + " " + t.daysAgo;
}
/* Tasarımın bildirim satırı saati: "2 dk" · "1 sa" · "1 g" — "önce" yok,
   çünkü liste zaten geçmiş; kelime her satırda tekrar eder, bilgi vermez. */
export function zamanKisa(ts, t) {
  const s = Math.max(0, Math.floor((Date.now() - new Date(ts).getTime()) / 1000));
  if (s < 60) return t.justNow;
  if (s < 3600) return Math.floor(s/60) + " " + t.tMin;
  if (s < 86400) return Math.floor(s/3600) + " " + t.tHr;
  return Math.floor(s/86400) + " " + t.tDay;
}
/* ══════════════════════════════════════════════════════════════════
   🔴 30 AĞUSTOS · GECE SİSTEMİ — GERİ SAYIM (`sayac`).

   Tasarımdaki kart alt satırının sol yarısı. Neden var:

   Kartta zaten "2026-09-04 · 14:20–17:00" yazıyordu. Bu bir TARİH,
   bir ACİLİYET değil. Kullanıcı tarihi okuyup kafasında bugünle
   çıkarma yapmak zorunda kalıyor — ve yapmıyor; sadece bakıp geçiyor.
   Ürünün satın alma anı ise tam olarak aciliyetin okunduğu an.

   🆕 SINIF: **"BİR ZAMANI TARİH OLARAK YAZARSAN KULLANICI ONU
   HESAPLAMAK ZORUNDA KALIR; GERİ SAYIM OLARAK YAZARSAN HİSSEDER.
   KARAR HESAPLA DEĞİL HİSLE VERİLİR."**

   Üç durum döner ve üçü de FARKLI bir şey söyler:
     · "3 sa 12 dk içinde"  → pencere daha açılmadı
     · "Şu an açık"          → pencere içindeyiz (en güçlü hâli)
     · "Sona erdi"           → geçti
   `null` dönerse satır hiç çizilmez: uydurulmuş bir sayaç,
   olmayan bir sayaçtan daha kötüdür.

   Saat dilimi: `avail_date` + `time_from` cihazın YEREL saatinde
   kuruluyor — çünkü havalimanı saatiyle kullanıcının telefonundaki
   saat, kullanıcı o havalimanına giderken zaten aynı olacak. UTC'ye
   çevirmek burada yanlış olur: kullanıcı "14:20" yazan bir uçuşu
   telefonundaki 14:20 ile karşılaştırır.
   ══════════════════════════════════════════════════════════════════ */
// 🔴 31 AĞUSTOS · 8. TUR — `saatli` KİPİ EKLENDİ (tasarımın sohbet başlığı).
// Tasarım sohbetin tepesinde `02:41:08 kalkışa` gösteriyor — SANİYELİ,
// canlı bir sayaç. Biz orada `3 sa 12 dk içinde` yazıyorduk.
//
// İkisi de doğru, ama AYNI EKRANDA doğru değiller: kartta kaba ölçek
// doğru (hemen altındaki yorumun anlattığı sebeple — 3 günlük bir ilanda
// saniye gürültüdür), sohbet başlığında ise soru "şu an ne kadar kaldı".
// O soruya "3 sa 12 dk" demek, saate bakıp "öğleden sonra" demek gibidir.
//
// 🆕 SINIF: "BİR SAYACIN ÖLÇEĞİ, SAYDIĞI ŞEYE DEĞİL SORULDUĞU YERE
// GÖRE SEÇİLİR."
export function geriSayim(availDate, timeFrom, timeTo, t, simdi, secenek) {
  if (!availDate || !timeFrom) return null;
  const gun = String(availDate).slice(0, 10);
  const bas = new Date(`${gun}T${String(timeFrom).slice(0, 5)}:00`);
  if (isNaN(bas.getTime())) return null;
  const now = simdi == null ? Date.now() : simdi;
  const fark = bas.getTime() - now;
  if (fark > 0) {
    const dk = Math.floor(fark / 60000);
    const gn = Math.floor(dk / 1440);
    const sa = Math.floor((dk % 1440) / 60);
    const kdk = dk % 60;
    // 3 günden uzak bir ilanda dakika göstermek gürültüdür; yakınlaştıkça
    // hassaslaşıyor. Bir sayaç, ölçeğini konusuna uydurmalı.
    if (secenek && secenek.saatli && gn < 1) {
      // 24 saatin altında: HH:MM:SS. Üstünde gün bilgisi daha anlamlı,
      // orada saatli kip kendiliğinden kaba ölçeğe düşüyor.
      const sn = Math.floor((fark % 60000) / 1000);
      const ik = n => String(n).padStart(2, "0");
      return { tur: "once", saatli: true,
               metin: `${ik(sa)}:${ik(kdk)}:${ik(sn)}` };
    }
    const metin = gn >= 1 ? `${gn} g ${sa} sa` : sa >= 1 ? `${sa} sa ${kdk} dk` : `${kdk} dk`;
    // `ham`: sade süre ("3 sa 12 dk") — "Kalkışına 3 sa 12 dk" gibi zaten
    // yön taşıyan cümlelerde "içinde" eki tekrar olur (tasarım 02 alt satırı).
    return { tur: "once", ham: metin, metin: String(t.cdIn || "{v}").replace("{v}", metin) };
  }
  if (timeTo) {
    const bit = new Date(`${gun}T${String(timeTo).slice(0, 5)}:00`);
    if (!isNaN(bit.getTime()) && bit.getTime() > now) {
      return { tur: "acik", metin: t.cdNow || "Şu an açık" };
    }
  }
  return { tur: "bitti", metin: t.cdEnded || "Sona erdi" };
}
/* Tasarımdaki `.sayac` — saat ikonu + tek genişlikli sayı.
   MONO şart: sayaç canlı bir değer, her dakika değişiyor. Orantılı bir
   ailede "3 sa 12 dk" → "3 sa 9 dk" olduğunda satırın tamamı sola
   kayar ve yanındaki altın düğme yerinden oynar. Tek genişlikli ailede
   yalnız rakam değişir, düzen durur. */
export function Sayac({ veri, ton }) {
  if (!veri) return null;
  const renk = ton || (veri.tur === "acik" ? C.teal : veri.tur === "bitti" ? C.dim : C.body);
  // ══════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL · GECE — SANİYELİ KİP ARTIK BİR KALKIŞ PANOSU.
  //
  // `saatli` yalnız TEK yerde kullanılıyor: sohbetin üst şeridi
  // (ekranlar_yalin.js). Yani bu dal, ürünün SANİYE SANİYE değişen
  // tek sayısı. Onu split-flap yapmak, ürünün başka hiçbir yerini
  // değiştirmeden vizyondaki FIDS şeridini gerçek kılıyor.
  //
  // ⚠️ BOY 12.5 → 16 BÜYÜDÜ VE BU BİLEREK. Bir yaprak panosunda
  // okunan şey rakam değil KATLANMA ÇİZGİSİ; 12.5pt'lik bir hücrede
  // o çizgi yarım piksele düşer ve taklit "titreyen bir yazı" gibi
  // görünür. Şerit kutusu 44pt (ölçüldü); 16pt rakam + 1.45 satır =
  // 23pt hücre, kutuya 10pt payla sığıyor.
  //
  // Dakikalı/gün ölçekli kip DEĞİŞMEDİ: 3 günde bir dönen bir yaprak
  // animasyon değil, hiç görülmeyen bir süstür.
  // ══════════════════════════════════════════════════════════════════
  if (veri.saatli) {
    return (
      <View style={{ flexDirection: "row", alignItems: "center", flexShrink: 0 }}>
        <Ikon ad="saat" boy={12} kutu={14} renk={C.mut} />
        <Serit metin={veri.metin} boy={16} renk={renk} stil={{ marginLeft: ARA[6] }} />
      </View>
    );
  }
  return (
    <View style={{ flexDirection: "row", alignItems: "center", flexShrink: 0 }}>
      <Ikon ad="saat" boy={12} kutu={14} renk={veri.tur === "bitti" ? C.dim : C.mut} />
      <Text numberOfLines={1} style={{ fontFamily: MONO[500], fontSize: FS.sm, color: renk,
                                       marginLeft: ARA[6] }}>
        {veri.metin}
      </Text>
    </View>
  );
}
export async function pickAndUploadPhoto(uid) {
  const ImagePicker = await import("expo-image-picker");
  const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!perm.granted) return null;
  const res = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images, allowsEditing: true, aspect: [1, 1], quality: 0.6, base64: true,
  });
  if (res.canceled || !res.assets?.[0]?.base64) return null;
  const b64 = res.assets[0].base64;
  const path = `${uid}/avatar.jpg`;
  const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
  const { error } = await supabase.storage.from("avatars").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
  if (error) return null;
  const { data } = supabase.storage.from("avatars").getPublicUrl(path);
  const url = data.publicUrl + "?t=" + Date.now();
  // 23 Eylül: güncelleme hatası yutuluyordu — ekranda yeni foto görünür,
  // ama profile yazılmadığı için bir sonraki açılışta eskisi geri gelirdi.
  const { error: eFoto } = await supabase.from("profiles").update({ photo_url: url }).eq("user_id", uid);
  if (eFoto) { logError("avatar_photo_url", eFoto); return null; }
  return url;
}
export function TrustRing({ score }) {
  // 🔴 v1.75: iki önceki iki deneme de Android'de dolmadı (kenarlık hilesi ve
  // yarım-daire maskesi transform+overflow kombinasyonuna takılıyor). Bu
  // sürüm hiçbir hileye dayanmıyor: halka 36 küçük segmentten oluşuyor,
  // puana düşen segmentler altın, kalanlar gri. Her cihazda aynı çalışır ve
  // dolum oranı gözle net okunur.
  const pct = Math.max(0, Math.min(100, Math.round(score || 0)));
  const SIZE = 132, R = SIZE / 2, SEG = 36, filled = Math.round((pct / 100) * SEG);
  return (
    <View style={{ width: SIZE, height: SIZE, alignItems: "center", justifyContent: "center" }}>
      {Array.from({ length: SEG }).map((_, i) => {
        const on = i < filled;
        const angle = (i / SEG) * 2 * Math.PI - Math.PI / 2;   // tepeden başla
        const rad = R - 8;
        return (
          <View key={i} style={{
            position: "absolute",
            left: R + rad * Math.cos(angle) - (on ? 4 : 3),
            top:  R + rad * Math.sin(angle) - (on ? 4 : 3),
            width: on ? 8 : 6, height: on ? 8 : 6, borderRadius: R.full,
            backgroundColor: on ? C.gold : C.line,
          }} />
        );
      })}
      <Text style={{ fontSize: FS.hero, fontFamily: MONO[600], fontWeight: "700", color: C.ink }}>{pct}</Text>
      <Text style={{ fontSize: FS.micro, color: C.mut, marginTop: ARA[2] }}>/100</Text>
    </View>
  );
}
// 🔴 23 Eylül — yönetim notları salon ADINA yazılmış: 190/211/214 pasife
// aldıkları salonların adına "(214 kaynaksız → pasif)" gibi iz düştü ve bu
// iz "Kapıda ne oldu?" kartında kullanıcıya aynen çiziliyordu (sahne 25).
// Salon tablosundaki iz yönetim için anlamlı — ekrana giden kopya temizlenir.
// Desen: "(" + üç haneli migration no + boşluk … ")".
export function salonAdi(ad) {
  if (!ad) return ad;
  return String(ad).replace(/\s*\(\d{3}\s[^)]*\)/g, "").trim();
}

export function FieldReportPrompt({ t, session }) {
  const [rows, setRows] = useState([]);
  const [busy, setBusy] = useState(null);
  const [fee, setFee] = useState("");
  const [openFee, setOpenFee] = useState(null);
  const [sendErr, setSendErr] = useState("");

  const load = useCallback(async () => {
    try {
      const { data, error: hata2 } = await supabase.rpc("pending_field_report", { p_user_id: null });
      if (hata2) logError("ortak.js:494", hata2);
      setRows(data || []);
    } catch (e) { setRows([]); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function send(sid, outcome, amount) {
    setBusy(sid); setSendErr("");
    // 🔴 v2.19 — KULLANICININ BASTIGI DUGME SESSIZCE BASARISIZ OLAMAZ.
    // Eskiden hata yutuluyordu: kullanici dokunuyor, kutu kapaniyor,
    // hicbir sey kaydedilmiyor ve o bunu BASARILI saniyor. Ustelik bu
    // veri bizim icin degerli — kaydedilmedigini bilmemiz de gerek.
    // "Akisi bozma" ilkesi, SESSIZ KALMA anlamina gelmez: akis devam
    // etsin ama kullanici ne oldugunu bilsin.
    // 🔴 v2.43 — SORULAR DEGISTI: "salon nasildi" degil "KAPIDA NE OLDU".
    // Ilki bir yorum sitesi sorusudur; bizim kural motorumuz icin
    // degersizdir. Ikincisi ise dogrudan kurala geri besleniyor:
    // girebildin mi, misafir kabul edildi mi, ucret cikti mi.
    //
    // Bes kullanici ayni seyi soyledginde kural DOGRULANMIS olur —
    // ve bu, rakibin kopyalayamayacagi tek sey. Onlarda kart kademesi
    // kavrami bile yok, dolayisiyla toplayacak saha verisi de yok.
    const { error } = await supabase.rpc("submit_field_report", {
      p_session_id: sid,
      p_entered: outcome !== "denied",
      p_guest_accepted: outcome === "ok" ? true : (outcome === "guest_denied" ? false : null),
      p_fee_charged: amount ? true : (outcome === "ok" ? false : null),
      p_fee_amount: amount || null,
      p_quota_left: null,
      p_note: null,
    });
    setBusy(null);
    if (error) {
      setSendErr(t.frFailed);
      return;                       // kutu ACIK kalsin ki tekrar denesin
    }
    setOpenFee(null); setFee("");
    load();
  }

  if (!rows.length) return null;
  const r = rows[0];   // aynı anda tek soru; yığmak cevaplanma oranını düşürür

  // ══════════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL (Gökberk md.7) — "oturum geçmişinde kapıda ne oldu
  // genişleyip daralmalı bence" + (md.1) "üstünde bir cümle başlığı
  // olmamalı".
  // Ölçtüm: kart 25_oturum_gecmisi'nde 268 pt yer kaplıyordu ve bunun
  // 44 pt'si SADECE açıklama cümlesiydi (`frSub`). Kart artık `Katlanir`:
  //  · AÇIK BAŞLIYOR — çünkü bu bir SORU; kapalı başlarsa cevaplanma
  //    oranı düşer ve kural motorunun tek saha girdisi budur.
  //  · Kapalıyken bile başlıkta SALON ADI duruyor (`ozet`) → bilgi kaybı yok.
  //  · Açıklama cümlesi SİLİNMEDİ, `not` olarak GÖVDENİN ALTINA indi;
  //    "üstünde" olmaması istenmişti, yok olması değil.
  // 🆕 SINIF: "BİR CÜMLEYİ KALDIRMAK İLE AŞAĞI ALMAK AYNI ŞEY DEĞİLDİR —
  // KULLANICI YERİNDEN ŞİKÂYET EDİYORSA ÖNCE YERİNİ DEĞİŞTİR, SİLME."
  // ══════════════════════════════════════════════════════════════════════
  return (
    <Katlanir baslik={t.frTitle} ozet={salonAdi(r.venue_name) || t.frVenueUnknown}
      tint={C.surface} cizgi={C.gold} not={t.frSub} acikBasla>
      {!!sendErr && (
        <View style={{ backgroundColor: C.hataBg, borderRadius: R.xs, padding: ARA[10], marginBottom: ARA[10] }}>
          <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>{sendErr}</Text>
        </View>
      )}

      {openFee === r.session_id ? (
        <View>
          <Text style={{ ...T.sm, color: C.body, marginBottom: SP[2] }}>{t.frFeeAsk}</Text>
          <TextInput value={fee} onChangeText={v => setFee(v.replace(/[^0-9.]/g, ""))}
            keyboardType="decimal-pad" placeholder="63" placeholderTextColor={C.dim}
            style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line,
                     borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.lg }} />
          <Btn v="gold" sm label={t.frSend} onPress={() => send(r.session_id, "admitted_paid", fee)} disabled={busy === r.session_id} style={{ marginTop: ARA[10] }} />
        </View>
      ) : (
        <View>
          {[["admitted_free", t.frFree, C.green],
            ["admitted_paid", t.frPaid, C.gold],
            ["refused", t.frRefused, C.red]].map(([code, label, col]) => (
            <TouchableOpacity hitSlop={TAP.slop} key={code} disabled={busy === r.session_id}
              onPress={() => code === "admitted_paid"
                ? setOpenFee(r.session_id) : send(r.session_id, code, null)}
              style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                       paddingVertical: SP[3], paddingHorizontal: SP[3], marginBottom: SP[2] }}>
              <Text style={{ color: col, ...T.sm, fontWeight: "600" }}>{label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </Katlanir>
  );
}
export function RefCodeEntry({ t }) {
  const [val, setVal] = useState("");
  const [done, setDone] = useState(false);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  if (done) return (
    <View style={{ backgroundColor: C.tealTint2, borderWidth: 0, borderTopWidth: 1, borderTopColor: C.parlama, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14] }}>
      <Text style={{ color: C.tealInk, fontSize: FS.sm, fontWeight: "700" }}>{t.refCodeApplied}</Text>
    </View>
  );
  return (
    <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, padding: SP[3], marginBottom: ARA[14] , ...ELEV.card }}>
      <Text style={{ fontSize: FS.xs, color: C.mut, letterSpacing: 1, marginBottom: ARA[6] }}>{t.refCodeTitle}</Text>
      <View style={{ flexDirection: "row", gap: SP[2] }}>
        <TextInput value={val} onChangeText={x => setVal(x.toUpperCase())} autoCapitalize="characters" maxLength={10}
          style={{ flex: 1, backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, paddingHorizontal: ARA[10], paddingVertical: SP[2], color: C.ink, fontSize: FS.sm, letterSpacing: 2 }} />
        <Btn v="gold" sm full={false} label={t.refCodeApply} onPress={async () => {
          setErr(""); setBusy(true);
          const { error } = await supabase.rpc("apply_referral", { p_code: val.trim() });
          setBusy(false);
          if (error) return setErr(mapErr(t, error.message));
          setDone(true);
        }} disabled={!val.trim() || busy} />
      </View>
      {!!err && <Text style={{ color: C.red, fontSize: FS.sm, marginTop: ARA[6] }}>{err}</Text>}
    </View>
  );
}
export const ACCESS_SOURCES = ["Priority Pass", "LoungeKey", "DragonPass", "Kredi Kartı Avantajı",
  "Havayolu Statüsü", "Business Class", "Banka / Özel Bankacılık", "Kurumsal Seyahat"];

// 🔴 v6.1 (Gökberk md.10) — profilde "airline_status" yazıyordu ve başka
// seçim yapılınca da kalıyordu. `profiles.access_source` bazı hesaplarda
// SUNUCU KODUYLA yazılmış (priority_pass, airline_status…); ekran ise
// yalnız etiket tanıyordu: kod çipe eşlenmiyor, seçimi kaldırılamıyor ve
// her kayıtta yeniden yazılıyordu. Okurken kodu etikete çeviriyoruz;
// tanınmayan bir değer düşürülmez ama ham kod da ekrana basılmaz.
const KAYNAK_KODLARI = {
  priority_pass: "Priority Pass", lounge_key: "LoungeKey", loungekey: "LoungeKey",
  dragon_pass: "DragonPass", dragonpass: "DragonPass",
  credit_card: "Kredi Kartı Avantajı", bank_card: "Kredi Kartı Avantajı", card_membership: "Kredi Kartı Avantajı",
  airline_status: "Havayolu Statüsü", alliance_status: "Havayolu Statüsü",
  business_class: "Business Class", ticket_class: "Business Class",
  private_bank: "Banka / Özel Bankacılık", private_banking: "Banka / Özel Bankacılık",
  corporate: "Kurumsal Seyahat",
  // eski etiketler (i18n.accessOpts) → güncel adlar
  "Kredi Kartı": "Kredi Kartı Avantajı", "Credit Card": "Kredi Kartı Avantajı",
  "Airline Status": "Havayolu Statüsü",
};
// Ekranda gösterim: kayıt her zaman TR etiketiyle tutulur (sunucu ve
// kural motoru onu okur); İngilizce arayüz onu `t.accessSrcNames` ile çevirir.
export function erisimEtiketi(t, etiket) {
  return (t && t.accessSrcNames && t.accessSrcNames[etiket]) || etiket;
}
export function erisimKaynaklari(ham) {
  const liste = String(ham || "").split(",").map(x => x.trim()).filter(Boolean)
    .map(x => KAYNAK_KODLARI[x] || KAYNAK_KODLARI[x.toLowerCase()] || x);
  return [...new Set(liste)];
}

// v2.65 — `firstRun` imzada vardı, gövdede hiç okunmuyordu ve App.js'in
// ilk-çalıştırma dalı normal dalla aynı davranıyordu. Ölü bayrak kaldırıldı.
export function getProfileCompletion(p) {
  const fields = [
    { label: "Fotoğraf", done: !!p?.photo_url },
    { label: "Bio", done: !!(p?.bio && p.bio.length > 20) },
    { label: "Meslek", done: !!p?.profession },
    { label: "LinkedIn", done: !!p?.linkedin_url },
    { label: "Diller", done: !!(p?.languages && p.languages.length > 0) },
    { label: "Lounge hakkı", done: !!(p?.access_source && p.access_source.length > 0) },
  ];
  const earned = fields.filter(f => f.done).length;
  const pct = Math.min(Math.round(earned / fields.length * 100), 100);
  return { pct, missing: fields.filter(f => !f.done), earned, total: fields.length };
}
export function LegalDoc({ docKey, onBack, onOpen, t }) {
  const d = LEGAL_DOCS[docKey] || LEGAL_DOCS.gizlilik;
  return (
    <Sayfa>
      <Hdr t={t} title={d.title} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: ARA[18], paddingBottom: ARA[44] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[3] }}>{d.short}</Text>
        <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 21 }}>{d.body}</Text>
        <View style={{ height: 1, backgroundColor: C.line, marginVertical: ARA[18] }} />
        <Text style={{ color: C.dimAA, fontSize: FS.xs, marginBottom: SP[2] }}>{t ? t.legalOtherDocs : "Diğer metinler"}</Text>
        {LEGAL_ORDER.filter(k => k !== docKey).map(k => (
          <TouchableOpacity hitSlop={TAP.slop} key={k} onPress={() => onOpen && onOpen(k)} style={{ paddingVertical: SP[2] }}>
            <IkonMetin sag ad="sag" renk={C.gold} stilMetin={{ color: C.gold, fontSize: FS.sm, fontWeight: "600" }} metin={LEGAL_DOCS[k].title} />
          </TouchableOpacity>
        ))}
        <Text style={{ color: C.dimAA, fontSize: FS.xs, marginTop: ARA[14] }}>{(t ? t.legalVersionLabel : "Sürüm:")} {LEGAL_VERSION}</Text>
      </ScrollView>
    </Sayfa>
  );
}

// Giriş/kayıt ekranının altındaki bağlantı satırı (MVP referans görseli)
// 🔴 v2.65 — bu bileşen `t`'yi HİÇ almıyordu; ayraçlar (" ve ", ", ") ve
// kapanış eki sabit Türkçeydi. Giriş ekranı EN'de bile "…'nı kabul etmiş
// olursun." yazıyordu. t artık prop; App.js üç çağrı yerinde de geçiyor.
export function LegalFooter({ onOpen, prefix, t }) {
  return (
    <View style={{ paddingHorizontal: ARA[18], paddingTop: ARA[6], paddingBottom: ARA[14] }}>
      <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 18, textAlign: "center" }}>
        {prefix}{" "}
        {LEGAL_ORDER.map((k, i) => (
          <Text key={k}>
            <Text onPress={() => onOpen(k)} style={{ color: C.ink, textDecorationLine: "underline", fontWeight: "600" }}>
              {LEGAL_DOCS[k].title}
            </Text>
            {i < LEGAL_ORDER.length - 1 ? (i === LEGAL_ORDER.length - 2 ? (t ? t.legalSepAnd : " ve ") : (t ? t.legalSepComma : ", ")) : ""}
          </Text>
        ))}
        {t ? t.legalAcceptSuffix : ""}
      </Text>
    </View>
  );
}

// 🔴 v2.65 · onLogout ÖLÜ PROP'TU — aynı dosyadaki #22 yorumu "Cikis Yap
// KALDIRILDI (Profil'de zaten var)" diyor. Kaldırma kasıtlıydı, prop
// unutulmuştu. onVerify de ölüydü; SİLİNMEDİ, telefon satırına BAĞLANDI:
// "Doğrulamayı bekliyor" rozetine dokunan doğrudan doğrulamaya gider.
export const PROF_KEYS = ["epProfTech","epProfFinance","epProfConsulting","epProfHealth",
                   "epProfLegal","epProfMedia","epProfStartup","epProfAcademia","epProfOther"];
export const LANG_OPTS = ["Türkçe", "İngilizce", "Fransızca", "Almanca", "Arapça", "İspanyolca", "Japonca", "Çince"];

// 🔴 v2.65 · PROP-DROP: App.js bu ekrana onAccess geçiyordu, imzada YOKTU.
// SİLMEK YERİNE BAĞLANDI — çünkü ekran zaten access_source'u veritabanından
// çekiyor (aşağıdaki select'e bak) ama hiçbir yerde göstermiyordu. Yüklenip
// gösterilmeyen alan, ölü ağırlıktan da kötüdür: sorgu maliyeti var, faydası yok.
// ════════════════════════════════════════════════════════════════════════
// 🔴 19 EYLÜL (Gökberk md.9 · md.17) — TEK SEÇİCİ, İKİ KİP.
//
// md.17 "filtrede tüm havalimanlarını tek tek vermek filtre alanını çok
//        uzatıyor; droplist sistemi getirelim bence."
// md.9  "haber ver alanında havalimanları droplist ile gelmeli"
//
// İkisi de AYNI bileşeni istiyor, yalnız biri ÇOKLU biri TEKLİ seçim.
// İki ayrı seçici yazmak bu dosyanın kendi dersine aykırı olurdu
// (başlıktaki not: aynı alanın üç ekranda üç hâli).
//
// EKLENEN İKİ ŞEY:
//   · `sik`    — sık kullanılan kodlar listenin BAŞINDA, kendi başlığıyla.
//                Ölçüm: katalogda 222 havalimanı var; vakaların çoğunda
//                IST/SAW/ESB yazılıyor. Sıralama veriden değil üründen.
//   · `coklu`  — `value` bir DİZİ olur, seçilenler çip olarak üstte durur,
//                liste açık kalır (çoklu seçimde her seçimde kapanmak
//                kullanıcıyı listeyi yeniden açmaya zorlar).
//
// 🆕 SINIF: "AYNI ALANIN İKİ KİPİ VARSA BU İKİ BİLEŞEN DEĞİL BİR PROP'TUR
// — İKİYE BÖLERSEN YARIN BİRİ ÖTEKİNDEN BAYATLAR."
// ════════════════════════════════════════════════════════════════════════
const AP_SIK = ["IST", "SAW", "ESB", "ADB", "AYT"];

// ⚠️ `t = {}`: bu bileşen eskiden her yerde `t.anahtar` yazıyordu ve
// `olu_metin_check.py` o kanalı GÖREMİYOR — yeni eklediğim üç anahtarı
// "hiç çizilmiyor" diye bildirdi ve haklıydı: bir anahtarın canlı
// olduğunu nöbetçi göremiyorsa, yarın silinir. Varsayılan boş nesne hem
// aynı korumayı veriyor hem okunabilir kalıyor.
export function AirportPicker({ label = "HAVALİMANI", airports, value, onSelect, t = {}, sik = true, coklu = false, hepsiEtiketi }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const secili = coklu ? (Array.isArray(value) ? value : []) : [];
  const sel = coklu ? null : airports?.find(a => a.code === value);
  // Sık kullanılanlar başa; gerisi katalog sırasında.
  const sirali = useMemo(() => {
    const liste = Array.isArray(airports) ? airports.slice() : [];
    if (!sik) return liste;
    liste.sort((x, y) => {
      const ix = AP_SIK.indexOf(x.code), iy = AP_SIK.indexOf(y.code);
      if (ix !== -1 || iy !== -1) return (ix === -1 ? 99 : ix) - (iy === -1 ? 99 : iy);
      return 0;
    });
    return liste;
  }, [airports, sik]);
  const gorunen = sirali.filter(a => eslesir(q, a.code, a.name, a.city));
  // Arama yokken ilk beşi "SIK KULLANILANLAR" başlığı altında ayırıyoruz:
  // başlıksız bir sıralama, sıralamayı fark etmeyen için rastgeledir.
  const sikSayisi = (sik && !q) ? gorunen.filter(a => AP_SIK.includes(a.code)).length : 0;
  return (
    <View style={{ marginBottom: ARA[14] }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, marginBottom: SP[1], letterSpacing: 1 }}>{gorunur(label)}</Text>
      {/* ÇOKLU KİPTE seçilenler kutunun ÜSTÜNDE çip olarak durur:
          liste kapalıyken de "neyi seçtim" görünür. Çipin kendisi
          kaldırma düğmesi — seçimi geri almak listeyi açmayı
          gerektirmemeli. */}
      {coklu && secili.length > 0 && (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: SP[2] }}>
          {/* ⚠️ `Btn`in `cip` kipi — elle yazılmış bir hap DEĞİL.
              İlk yazımda elle yazdım ve `dugme_check.py` saydı (+1).
              Haklıydı: elle yazınca 44pt dokunma tabanı, bekleme durumu
              ve dokunuşta kenar ışığı gelmiyor. Bu kod tabanının kendi
              dersi: "bir düğmeyi elle yazdığında yalnız görünüşünü
              kopyalarsın — davranışını değil." */}
          {secili.map(kod => (
            <Btn key={kod} cip sm v="goldSoft" label={kod} sagAd="kapat"
              a11yLabel={`${kod} · ${t.clear || "Temizle"}`}
              onPress={() => onSelect(secili.filter(x => x !== kod))} />
          ))}
        </View>
      )}
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setOpen(!open); setQ(""); }}
        accessibilityRole="button"
        accessibilityLabel={label}
        style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: open ? C.teal : C.line, borderRadius: R.xs,
                 paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: 46, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <Text numberOfLines={1} style={{ flex: 1, fontSize: FS.sm, color: (sel || secili.length) ? C.body : C.dim }}>
          {coklu
            ? (secili.length
                ? String(t.airportPickedN || "{n} havalimanı seçili").replace("{n}", String(secili.length))
                : (hepsiEtiketi || t.allAirports || "Tüm havalimanları"))
            : (sel ? `${sel.code} — ${sel.city}` : (t.airportPick || "Havalimanı seç…"))}
        </Text>
        <Ikon ad={open ? "yukari" : "asagi"} boy={14} renk={C.mutedAA} />
      </TouchableOpacity>
      {open && (
        <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, marginTop: SP[1], maxHeight: 300, overflow: "hidden" , ...ELEV.card }}>
          <AramaKutusu value={q} onChange={setQ} sonuc={gorunen.length}
            placeholder={t.searchAirport || "Havalimanı ara…"} t={t} />
          <ScrollView nestedScrollEnabled keyboardShouldPersistTaps="handled">
            {gorunen.map((a, i) => {
              const secilMi = coklu ? secili.includes(a.code) : a.code === value;
              return (
              <React.Fragment key={a.code}>
                {/* Başlıksız bir sıralama, sıralamayı fark etmeyen için
                    rastgeledir — iki başlık da o yüzden var. */}
                {sikSayisi > 0 && i === 0 && (
                  <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 1.2,
                                 color: C.mutedAA, paddingHorizontal: SP[3], paddingTop: SP[2], paddingBottom: ARA[4] }}>
                    {BUYUK(t.airportFrequent || "Sık kullanılanlar")}
                  </Text>
                )}
                {sikSayisi > 0 && i === sikSayisi && (
                  <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 1.2,
                                 color: C.mutedAA, paddingHorizontal: SP[3], paddingTop: SP[3], paddingBottom: ARA[4],
                                 borderTopWidth: 1, borderTopColor: C.line }}>
                    {BUYUK(t.airportAll || "Tüm havalimanları")}
                  </Text>
                )}
                <TouchableOpacity hitSlop={TAP.slop}
                  accessibilityRole={coklu ? "checkbox" : "button"}
                  accessibilityState={coklu ? { checked: secilMi } : undefined}
                  accessibilityLabel={`${a.code} ${a.name}`}
                  onPress={() => {
                    if (coklu) {
                      // Çoklu seçimde liste AÇIK kalır: her seçimde kapanmak
                      // kullanıcıyı listeyi yeniden açmaya zorlardı.
                      onSelect(secilMi ? secili.filter(x => x !== a.code) : [...secili, a.code]);
                    } else {
                      onSelect(a.code); setOpen(false); setQ("");
                    }
                  }}
                  style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: 46, borderBottomWidth: 1, borderBottomColor: C.line,
                           flexDirection: "row", alignItems: "center",
                           backgroundColor: secilMi ? C.tealBg : "transparent" }}>
                  <View style={{ flex: 1, minWidth: 0 }}>
                    <Text numberOfLines={1} style={{ fontSize: FS.sm, color: secilMi ? C.teal : C.body, fontWeight: secilMi ? "600" : "400" }}>
                      {a.code} — {a.name}
                    </Text>
                    <Text numberOfLines={1} style={{ fontSize: FS.xs, color: C.dim, marginTop: 0 }}>{a.city}</Text>
                  </View>
                  {coklu && secilMi && <Ikon ad="tamam" boy={16} renk={C.teal} />}
                </TouchableOpacity>
              </React.Fragment>
              );
            })}
          </ScrollView>
          {coklu && secili.length > 0 && (
            /* ⚠️ Elle yazılmış bir dokunulabilir DEĞİL `Btn`: `dugme_check.py`
               haklı olarak saydı. Elle yazmak yalnız görünüşü kopyalar —
               44pt dokunma tabanı, bekleme durumu ve dokunuşta kenar ışığı
               `Btn`in işi. */
            <View style={{ padding: SP[2], borderTopWidth: 1, borderTopColor: C.line }}>
              <Btn v="ghost" sm label={t.clear || "Temizle"} a11yLabel={t.clear || "Temizle"}
                onPress={() => onSelect([])} />
            </View>
          )}
        </View>
      )}
    </View>
  );
}

// ============================================================
// OLANAK ROZETLERI (v2.29)
//
// 🔴 NEDEN: kurali kusursuz biliyoruz ama misafirin GERCEKTEN merak
// ettigi seyi soylemiyorduk. "Girebilir miyim" cevaplaniyor, "girince
// ne var" susuyordu. Veriyi zaten toplamistik — havalimani
// sayfalarindaki olanak listelerini gecerken okuyup atmisim.
//
// Bilmedigimiz olanagi GOSTERMIYORUZ. Kuralda yapmadigimiz hatayi
// olanakta da yapmayalim: eksik bilgi, yanlis bilgiden iyidir.
// ============================================================
// 🔴 v3.4 — DEĞERLER ARTIK EMOJİ DEĞİL, İKON ADI (bkz. src/ikon.js).
// Eski hâlinde 15 emoji vardı ve ekran görüntüsünde hepsi FARKLI bir
// üslupla çiziliyordu: 🍽 ince gri çizgi, 🧸 dolgun kahverengi bir
// oyuncak, 💻 gümüş bir dizüstü. Aynı satırdaki 5 rozet 5 ayrı
// tasarımcının elinden çıkmış gibi duruyordu — çünkü öyleydi.
//
// 🆕 SINIF: "AYNI SATIRDAKİ İKONLARIN ÇİZİM ÜSLUBU AYNI DEĞİLSE, ORADA
// BİR TASARIM DEĞİL BİR TOPLAMA VARDIR."
export const AMENITY_ICONS = {
  wifi: "olanakWifi", food: "olanakYemek", buffet: "olanakBufe",
  bar: "olanakBar", shower: "olanakDus", sleep: "olanakDinlenme",
  kids: "olanakCocuk", prayer: "olanakIbadet", work: "olanakCalisma",
  tv: "olanakTv", terrace: "olanakTeras", cinema: "olanakSinema",
  games: "olanakOyun", luggage: "olanakBagaj", nursery: "olanakCocuk",
};
export const AMENITY_TR = {
  wifi: "Wi-Fi", food: "Yiyecek", buffet: "Açık büfe", bar: "Bar",
  shower: "Duş", sleep: "Dinlenme", kids: "Çocuk alanı", prayer: "Mescit",
  work: "Çalışma", tv: "TV", terrace: "Teras", cinema: "Sinema",
  games: "Oyun", luggage: "Emanet", nursery: "Bebek bakım",
};
export function VenuePrices({ venueId, t }) {
  const [rows, setRows] = useState(null);
  useEffect(() => {
    let alive = true;
    if (!venueId) { setRows(null); return; }
    (async () => {
      try {
        const { data, error } = await supabase.rpc("venue_price_list", { p_venue_id: venueId });
        if (alive) setRows((!error && data && data.length) ? data : null);
      } catch (e) { if (alive) setRows(null); }
    })();
    return () => { alive = false; };
  }, [venueId]);

  if (!rows) return null;
  return (
    <View style={{ marginTop: SP[2], borderTopWidth: 1, borderTopColor: C.teal + "33", paddingTop: ARA[6] }}>
      <Text style={{ fontSize: FS.micro, letterSpacing: 1.2, color: C.teal, fontWeight: "700", marginBottom: SP[1] }}>
        {t.venuePrices || "SALON FİYATLARI"}
      </Text>
      {rows.map(r => (
        <Text key={r.item_code} style={{ fontSize: FS.xs, color: C.body, lineHeight: 15 }}>
          · {r.item_name}: {r.price} {r.currency}/{r.unit}
        </Text>
      ))}
      {!!rows[0].note && (
        <Text style={{ fontSize: FS.micro, color: C.mut, lineHeight: 14, marginTop: SP[1] }}>{rows[0].note}</Text>
      )}
    </View>
  );
}


// v2.69: `t` eklendi — fiyat listesi başlığı için. Varsayılanı var,
// çağıran vermezse bileşen yine çizilir (prop düşmesi ekran bozmaz).
export let _DTP = null;
try { _DTP = require("@react-native-community/datetimepicker").default; } catch (e) { _DTP = null; }
export const TR_DAYS = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];
export const TR_MONTHS = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
                   "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
export function isoOf(d) {
  const p = n => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
// 🔴 v3.7 — ÜÇÜNCÜ SÜTUN ARTIK EMOJİ DEĞİL İKON ADI.
// Emoji burada VERİ olarak duruyordu: yani ikon, bileşenin değil
// sözlüğün parçasıydı. Beşi de gövde fontunda yok, hepsi sistem emoji
// fontuna düşüyordu (ölçüldü: `ikon_check.py` font kapsamı kuralı).
// 🆕 SINIF: "BİR İKONU VERİ TABLOSUNA YAZARSAN, TASARIM SİSTEMİNİN
// DIŞINDA BİR İKON SETİ DAHA KURMUŞ OLURSUN."
export const PURPOSES = [
  ["business", "İş", "amacIs"],
  ["conference", "Konferans", "amacKonferans"],
  ["leisure", "Tatil", "amacTatil"],
  ["connecting", "Aktarma", "amacAktarma"],
  ["event", "Etkinlik", "amacEtkinlik"],
];
export function PromiseBox({ t, lounge, f, esik, yogunluk }) {
  return (
    <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: "transparent",
                   borderRadius: R.sm, padding: SP[3], marginTop: SP[3] }}>
      <Text style={{ color: C.goldText, fontSize: FS.xs, letterSpacing: 1.1, fontWeight: "700" }}>
        {t.promiseTitle}
      </Text>
      <Text style={{ color: C.ink, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>
        {String(t.promiseLine || "")
          .replace("{lounge}", String(lounge || "—"))
          .replace("{date}", f?.date || "—")
          .replace("{from}", f?.from || "—")
          .replace("{to}", f?.to || "—")
          .replace("{n}", String(f?.slots || "1"))}
      </Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>
        {Number(esik) > 0
          ? String(t.promiseTrust || "").replace("{n}", String(esik))
          : t.promiseTrustAny}
      </Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>
        {t.promiseEngine}
      </Text>
      {yogunluk && Number(yogunluk.bekleyen) > 0 && (
        <Text style={{ color: C.gold, fontSize: FS.sm, marginTop: SP[2], fontWeight: "700", lineHeight: 18 }}>
          {String(t.demandProof || "")
            .replace("{n}", String(yogunluk.bekleyen))
            .replace("{ap}", String(yogunluk.havalimani || ""))}
        </Text>
      )}
    </View>
  );
}

// ============================================================
// SEYAHAT DÜZENLE (v2.89 · Gökberk md.13)
// Kilit kuralı ilanınkinden FARKLI: seyahat bir başvurunun dayanağı.
// O seyahate dayanan aktif başvuru varken havalimanı ve tarih kilitli;
// saat ve uçuş her zaman düzeltilebilir (asıl karışan da o ikisi).
// ============================================================
export const REPORT_TYPES = [
  ["harassment", "Taciz / rahatsız edici davranış", "raporTaciz"],
  ["fraud", "Dolandırıcılık", "raporDolandirici"],
  ["fake_profile", "Sahte profil", "raporSahte"],
  ["off_platform_payment", "Platform dışı ödeme talebi", "uyari"],
  ["other", "Diğer", "raporDiger"],
];
// 🔴 30 AĞUSTOS · 3. TUR — `ad` PROP'U: PİLİN İŞARETİ ARTIK VEKTÖR.
// Çağrı yerleri `<Pill c={C.green} ad="tamam">{t.rqIdOk}</Pill>` diye yazıyordu;
// yani işaret metnin İÇİNDE bir karakterdi ve gövde fontunun
// metriklerine tabiydi. Pil bir `<Text>` olduğu için içine `<Ikon>`
// koyulamıyordu — o yüzden pil artık bir satır.
//
// 🆕 SINIF: "BİR BİLEŞENİN KÖK ETİKETİ `<Text>` İSE, İÇİNE HİÇBİR ZAMAN
// BİR ÇİZİM KOYAMAZSIN — VE BU, ÇAĞRI YERLERİNİ SEMBOL YAZMAYA
// MECBUR BIRAKIR."
export function Pill({ c, children, ad }) {
  const yazi = { fontSize: FS.micro, fontWeight: "600", color: c };
  if (!ad) {
    return (
      <Text style={{ ...yazi, backgroundColor: c + "18",
                     borderRadius: R.full, paddingHorizontal: SP[2], paddingVertical: ARA[2],
                     marginRight: SP[1], marginBottom: SP[1], overflow: "hidden" }}>
        {children}
      </Text>
    );
  }
  return (
    <View style={{ flexDirection: "row", alignItems: "center",
                   backgroundColor: c + "18", borderRadius: R.full,
                   paddingHorizontal: SP[2], paddingVertical: ARA[2],
                   marginRight: SP[1], marginBottom: SP[1] }}>
      <Ikon ad={ad} boy={11} kutu={13} renk={c} stil={{ marginRight: ARA[3] }} />
      <Text style={yazi}>{children}</Text>
    </View>
  );
}

// ============ KAMPANYALAR (048) — Profil menusunden acilir ============
// Duyuru "Kampanyalar'dan katil" der; kullanici burada Katil'a basar,
// katilim BO denetim kaydina duser (app.campaign_join). Ust kisim:
// promosyon kodu girisi (redeem_promo_code — odul SUNUCUDA yazilir).
export function intentLabel(t, k) {
  return k === "coffee" ? t.intCoffee
    : k === "networking" ? t.intNetwork
    : k === "route" ? t.intRoute
    : k === "hello" ? t.intHello
    // 29 Eylül — "Diğer" eklendi; bilinmeyen kod ASLA ham basılmaz (kural: kullanıcıya ham kod yok).
    // insan metni (ör. "Lounge oturumunda tanışıldı") olduğu gibi; tanınmayan KOD ise "Diğer".
    : (/^[a-z_]+$/.test(String(k || "")) ? (t.intOther || "—") : String(k || ""));
}

// ============================================================================
// ULAŞILABİLİRLİK KARTI (v2.98 · eleştiri G7 · SQL 252)
//
// 🔴 NEDEN BİR "AYAR UYARISI" DEĞİL:
// "Bildirimlerin kapalı" bir ayar cümlesidir; kimse umursamaz. Bu kart
// sunucudan kullanıcının O AN NE KAYBETTİĞİNİ alır: bekleyen isteği mi var,
// yayında ilanı mı var, yoksa henüz ikisi de yok mu. Uyarının şiddetini
// bizim ne kadar istediğimiz değil, kullanıcının kaybı belirler.
//
// Üç şiddet, üç davranış:
//   kritik → bekleyen istek VAR. Kapatılamaz. Misafir kapıda bekliyor.
//   uyari  → yayında ilan var. Kapatılamaz.
//   bilgi  → henüz kaybedecek bir şey yok. KAPATILABİLİR — çünkü bu anda
//            ısrar etmek, izni gerçekten gerektiğinde istemekten daha
//            değerli değil.
//
// 🔵 Ve en önemlisi: sistem artık izin soramıyorsa (iOS'ta bir kez
// reddedilmiş), düğme "Bildirimleri aç" demez — çünkü açamaz. Ayarlar'a
// yönlendirir. Hiçbir şey yapmayan bir düğme, olmayan bir düğmeden kötüdür.
// ============================================================================
// `goster`: bu kartın hangi şiddetleri çizeceği. Tek bir bileşen, İKİ
// FARKLI ANDA kullanılıyor:
//   ana sayfanın TEPESİ  → ["kritik","uyari"]  (ortada bir kayıp var)
//   sakin gün bölümü     → ["bilgi"]           (ortada kayıp yok; HAZIRLIK anı)
// Aynı kartı her iki yerde de tüm şiddetlerle çizmek, kaybı olmayan
// kullanıcıyı ana sayfanın tepesinde kırmızıya boğardı.
export function UlasilabilirlikKarti({ t, tazele, goster }) {
  const [d, setD] = useState(null);
  const [bekle, setBekle] = useState(false);
  const [kapali, setKapali] = useState(false);
  // 🔴 v3.4 — İSTEMCİNİN KENDİ BİLDİĞİ GERÇEK. Aşağıda anlatılıyor.
  const [ayarGerekliYerel, setAyarGerekliYerel] = useState(false);
  const [sonuc, setSonuc] = useState("");

  // 🔴 3 EYLÜL — CİHAZDAKİ İZİN DE OKUNUYOR. Gökberk (cihaz ekran
  // görüntüsü): telefonda bildirim izni AÇIK, kart yine "BİLDİRİMLER
  // KAPALI · Bildirimleri aç" diyor; basınca "İzin verildi ama cihazın
  // kaydedilemedi. İnterneti kontrol et" — internet açık. İki hata:
  //   (1) Kart yalnız SUNUCUNUN gözüyle karar veriyordu (jeton yok →
  //       "kapalı"). İzin cihazda açıkken "aç" demek yanlış teşhis.
  //   (2) Jetonun neden alınamadığı söylenmiyordu (Firebase kurulu değil).
  // Kart artık cihazdaki izni de biliyor: izin AÇIKSA "aç" düğmesi yok;
  // sorun jetonsa nedeni yazılır ve "Tekrar dene" verilir. İzin KAPALIYSA
  // düğme doğrudan telefonun LoungeLink → Bildirimler sayfasını açar.
  const [cihaz, setCihaz] = useState(null);   // { durum, tekrar, token, tokenNeden }
  const oku = useCallback(async () => {
    const [{ data, error }, c] = await Promise.all([
      supabase.rpc("ulasilabilirlik_uyarim"),
      pushDurumOku().catch(() => null),
    ]);
    if (c) setCihaz(c);
    if (error) { logError("ulasilabilirlik_uyarim", error); return; }
    setD(data || null);
  }, []);

  useEffect(() => { oku(); }, [oku, tazele]);

  if (!d || d.ulasilabilir || kapali) return null;
  if (Array.isArray(goster) && goster.indexOf(d.siddet) < 0) return null;

  const izinAcik = !!(cihaz && cihaz.durum === "verildi");
  const jetonNeden = cihaz && cihaz.tokenNeden;
  // 🔴 v6.1 (Gökberk md.14) — "bildirim izni alanı çalışmıyor". İzin
  // VERİLMİŞ ama bu derlemede FCM yok: kullanıcının yapabileceği hiçbir
  // şey kalmamışken kart "Yeniden dene" diye duruyordu ve düğme her
  // dokunuşta aynı cümleyi geri getiriyordu. Kullanıcıya iş çıkarmayan
  // bir altyapı eksiği ana sayfada kart olmaz.
  if (izinAcik && jetonNeden === "fcm_yok") return null;
  // İzin açık + jeton yok → "kapalı" değil, "altyapı/kayıt" hâli: sessiz ton.
  const siddet = izinAcik ? "bilgi" : d.siddet;
  const renk = siddet === "kritik" ? C.red : siddet === "uyari" ? C.amber : C.gold;
  const zemin = siddet === "kritik" ? C.redBg : siddet === "uyari" ? C.amberBg : C.goldBg;
  const kapanabilir = siddet === "bilgi";
  const ayarGerekli = !izinAcik && (ayarGerekliYerel || !!d.ayarlar_gerekli
    || (cihaz && cihaz.durum === "reddedildi" && cihaz.tekrar === false));
  const jetonMetni = !izinAcik ? null
    : jetonNeden === "fcm_yok" ? t.pushInfraMissing
    : jetonNeden === "ag" ? t.pushTokenFail
    : jetonNeden === "sunucu" ? t.pushTokenServer
    : t.pushTokenUnknown;

  const bas = async () => {
    setBekle(true);
    setSonuc("");
    try {
      if (ayarGerekli) {
        const acildi = await bildirimAyarlariniAc();
        // 🔴 AYARLAR AÇILAMAZSA DA SÖYLE. `Linking.openSettings` bazı
        // cihazlarda yok; sessizce başarısız olmak, düzelttiğimiz
        // hatanın aynısıdır.
        if (!acildi) setSonuc(t.pushSettingsFail || "Ayarlar açılamadı. Telefon ayarlarından LoungeLink → Bildirimler'i aç.");
      } else {
        const r = await pushIzniIste();
        if (r) setCihaz(r);
        // ══════════════════════════════════════════════════════════
        // 🔴 30 AĞUSTOS — "BİLDİRİMLERİ AÇ" HÂLÂ SESSİZ KALABİLİYORDU.
        //
        // 28 Ağustos'ta düğmenin BOŞ olan gövdesi doldurulmuştu. Ama
        // bir yol hâlâ hiçbir iz bırakmıyordu: izin VERİLDİ, cihaz
        // token'ı KAYDEDİLEMEDİ. `pushIzniIste` bunu `r.token = false`
        // ile bildiriyordu; burası o alanı hiç okumuyordu.
        //
        // O durumda: `setSonuc("")` mesajı siliyor, `oku()` sunucudan
        // aynı "ulaşılamıyorsun" uyarısını geri getiriyor ve kart
        // DEĞİŞMEDEN yeniden çiziliyordu. Kullanıcı için bu, tıkladığı
        // hiçbir şeyin olmaması demek — basılan düğme ile bozuk düğme
        // arasında fark kalmıyor.
        //
        // Bu dosyanın kendi kuralı (aşağıda, ~870. satır) bunu zaten
        // söylüyordu: "SONUCUNU GÖSTERMEYEN BİR DÜĞME, HİÇBİR ŞEY
        // YAPMAYAN BİR DÜĞMEDEN AYIRT EDİLEMEZ." Kural yazılmış ama bir
        // dalda uygulanmamıştı.
        //
        // 🆕 SINIF: **"BİR KURALI YAZMAK ONU UYGULAMAK DEĞİLDİR —
        // KURALIN GEÇMEDİĞİ HER DAL, KURALIN OLMADIĞI BİR YERDİR."**
        // ══════════════════════════════════════════════════════════
        if (r && r.durum === "verildi" && r.token) {
          setSonuc(t.pushEnabled || "Bildirimler açıldı. Artık isteklerden haberin olacak.");
        } else if (r && r.durum === "verildi" && !r.token) {
          setSonuc(r.tokenNeden === "fcm_yok" ? t.pushInfraMissing
            : r.tokenNeden === "ag" ? t.pushTokenFail
            : r.tokenNeden === "sunucu" ? t.pushTokenServer : t.pushTokenUnknown);
        } else if (r && r.ayarlarGerekli) {
          // Sistem bir daha soramaz. Bunu SUNUCUYA sormadan biliyoruz.
          setAyarGerekliYerel(true);
          setSonuc(t.pushDeniedGoSettings || "İzin kapalı. Telefon ayarlarından açman gerekiyor.");
        } else if (r && r.durum === "desteklenmiyor") {
          setSonuc(t.pushNoDevice || "Bildirimler yalnız gerçek cihazda çalışır.");
        } else if (r && r.durum !== "verildi") {
          setSonuc(t.pushDenied || "Şimdilik izin verilmedi. İstersen sonra açabilirsin.");
        }
      }
      await oku();
    } finally { setBekle(false); }
  };

  return (
    /* 🔴 13 EYLÜL (Gökberk md.15) — "ana sayfada bildirim izni alanı ile
       bağlantılarım kutucukları bitişik duruyor."
       Ölçtüm: bu kartın `marginTop: 12` vardı ama ALT BOŞLUĞU YOKTU;
       altındaki `Katlanir` da yalnız `marginBottom` taşıyor. İki kart
       arasındaki mesafe bu yüzden 0 pt'ydi — kenarlıkları birbirine
       değiyordu. Ritim `ARA[14]`; boşluk artık iki uçta da var.
       🆕 SINIF: "BOŞLUĞU YALNIZ BİR YÖNE YAZAN İKİ KOMŞU, ARALARINDA
       HİÇ BOŞLUK BIRAKMAZ." */
    <View style={{ backgroundColor: zemin, borderWidth: 0, borderTopWidth: 1, borderTopColor: C.kabartmaIsik,
                   borderRadius: R.sm, padding: SP[4], marginTop: SP[3], marginBottom: ARA[14] }}>
      <View style={{ flexDirection: "row", alignItems: "center" }}>
        <Ikon ad="bildirimKapali" boy={15} renk={renk} stil={{ marginRight: SP[2] }} />
        <Text style={{ color: renk, fontSize: FS.micro, letterSpacing: 1.6, fontWeight: "700", flex: 1 }}>
          {BUYUK(izinAcik ? (t.pushInfraEyebrow || "") : d.siddet === "kritik" ? (t.pushCritEyebrow || "") : (t.pushEyebrow || ""))}
        </Text>
        {kapanabilir && (
          <TouchableOpacity onPress={() => setKapali(true)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <Text style={{ color: C.dim, fontSize: FS.base }}>×</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Cümleler SUNUCUDAN geliyor (SQL 252 §3 · metin() üzerinden TR/EN). */}
      <Text style={{ color: C.ink, fontSize: FS.sm, lineHeight: 18, marginTop: SP[2] }}>
        {izinAcik ? jetonMetni : d.mesaj}
      </Text>
      {!izinAcik && !!d.ayarlar_mesaji && (
        <Text style={{ color: C.body, fontSize: FS.xs, lineHeight: 16, marginTop: SP[2] }}>
          {d.ayarlar_mesaji}
        </Text>
      )}
      {!ayarGerekli && !!d.hazirlik_mesaji && (
        <Text style={{ color: C.body, fontSize: FS.xs, lineHeight: 16, marginTop: SP[2] }}>
          {d.hazirlik_mesaji}
        </Text>
      )}
      {/* 🔴 v3.4 — DÜĞMENİN CEVABI. Eskiden dokunuşun sonucu HİÇBİR YERDE
          yazmıyordu: izin reddedilse de, cihaz desteklemese de, Ayarlar
          açılamasa da ekranda aynı şey duruyordu. "Aksiyon almadı"
          şikâyetinin diğer yarısı buydu — aksiyon alındı ama SÖYLENMEDİ.
          🆕 SINIF: "SONUCUNU GÖSTERMEYEN BİR DÜĞME, HİÇBİR ŞEY YAPMAYAN
          BİR DÜĞMEDEN AYIRT EDİLEMEZ." */}
      {!!sonuc && (
        <Text style={{ color: renk, fontSize: FS.sm, lineHeight: 18, marginTop: SP[2], fontWeight: "600" }}>
          {sonuc}
        </Text>
      )}

      <TouchableOpacity
        onPress={bas}
        disabled={bekle}
        accessibilityRole="button"
        accessibilityState={{ disabled: bekle, busy: bekle }}
        accessibilityLabel={izinAcik ? (t.retry || "Tekrar dene")
                            : ayarGerekli ? (t.pushOpenSettings || "Telefon ayarlarını aç")
                            : (t.pushEnable || "Bildirimleri aç")}
        style={{ backgroundColor: renk, borderRadius: R.sm, paddingVertical: SP[3],
                 minHeight: TAP.minHeight, justifyContent: "center",
                 alignItems: "center", marginTop: SP[3], opacity: bekle ? 0.6 : 1 }}>
        <Text style={{ color: siddet === "kritik" ? C.onAccent : C.onGold, fontSize: FS.sm, fontWeight: "700" }}>
          {bekle ? (t.loading || "…")
                 : izinAcik ? (t.retry || "Tekrar dene")
                 : ayarGerekli ? (t.pushOpenSettings || "Telefon ayarlarını aç")
                 : (t.pushEnable || "Bildirimleri aç")}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

// ============================================================================
// 18 YAŞ ONAYI — MEVCUT KULLANICILAR İÇİN (v2.99 · SQL 255 §2)
//
// 🔴 NEDEN AYRI BİR KART: 18 yaş onayı kayıt akışına eklendi, ama bu YALNIZ
// YENİ kullanıcıları kapsıyor. v2.99'dan önce kaydolmuş herkesin
// `consents` tablosunda `age_18` satırı YOK — yani sözleşmenin dayanağı da
// yok. Mağaza yaş derecelendirmesi (yabancılarla sohbet + yüz yüze buluşma)
// bütün kullanıcılar için geçerli; onay yalnız bir kısmı için geçerliyse
// eksiktir.
//
// 🆕 SINIF: "BİR ŞARTI KAYIT AKIŞINA EKLEMEK, ZATEN KAYITLI OLANLARI
// KAPSAMAZ — VE ÜRÜNÜN KULLANICILARININ ÇOĞU HER ZAMAN 'ZATEN KAYITLI'DIR."
//
// Bir kez sorulur, cevaplanınca bir daha görünmez. Kapatılamaz: onay
// vermeden geçilebilen bir yaş kapısı, kapı değildir.
// ============================================================================
export function YasOnayi({ t }) {
  const [gerek, setGerek] = useState(false);
  const [bekle, setBekle] = useState(false);

  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("yas_onayim");
      if (error) { logError("yas_onayim", error); return; }
      if (!iptal) setGerek(data === false);
    })();
    return () => { iptal = true; };
  }, []);

  if (!gerek) return null;

  const onayla = async () => {
    setBekle(true);
    const { error } = await supabase.rpc("grant_consents",
      { p_types: ["age_18"], p_version: "v16" });
    setBekle(false);
    if (error) { logError("grant_consents_age", error); return; }
    setGerek(false);
  };

  return (
    <View style={{ backgroundColor: C.goldBg, borderWidth: 1, borderColor: "transparent",
                   borderRadius: R.sm, padding: SP[4], marginTop: SP[3] }}>
      <Text style={{ color: C.goldText, fontSize: FS.micro, letterSpacing: 1.6, fontWeight: "700" }}>
        {BUYUK(t.ageGateEyebrow || "")}
      </Text>
      <Text style={{ color: C.ink, fontSize: FS.sm, lineHeight: 18, marginTop: SP[2] }}>
        {t.c6Age}
      </Text>
      <Btn v="gold" sm label={bekle ? (t.loading || "…") : (t.ageGateConfirm || "Onaylıyorum")} onPress={onayla} disabled={bekle} a11yLabel={t.ageGateConfirm} style={{ marginTop: SP[3] }} />
    </View>
  );
}
