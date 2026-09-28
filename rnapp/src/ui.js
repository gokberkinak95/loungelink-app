// ============================================================
// UI — MVP v15'in gorsel dil bilesenleri (Btn/Input/Card/Pill/
// Bar/Avatar/Section), React Native'e cevrilmis.
//
// MVP'de bu bilesenler urunun "sesini" tasiyor: Btn'in 7 varyanti
// var (gold/teal/purple/rose/outline/ghost/muted) ve her biri bir
// ANLAM tasiyor. v1.21'e kadar bunlar yoktu; her ekran kendi
// butonunu altin renkle cizdi -> anlam kayboldu.
//
// MVP kaynagi: LoungeLink_MVP_v15.jsx satir 307-465
// ============================================================
import React, { useCallback, useEffect, useRef, useState } from "react";
import { BUYUK, gorunur } from "./i18n";
import { View, Text, TextInput, TouchableOpacity, ScrollView, StatusBar, Platform, Animated, Easing, Image, Dimensions, ActivityIndicator, Modal } from "react-native";
// 🔴 `BTN` adı bu dosyada ZATEN VAR (varyant haritası). Tema tarafındaki
// ölçüler ayrı adla giriyor; aynı adı ikinci kez bağlamak sessiz bir
// gölgeleme değil, doğrudan çalışma anı hatası verdi.
import { ARA, ELEV, BTN as BOY, C, F, FS, R, SATIR, SP, T, TAP, temaYenidenKur, temaModu } from "./theme";
import { MONO } from "./typography";
import { Atmosfer } from "./atmosfer";
import { Ikon } from "./ikon";
import { Katman } from "./katman";

// Durum cubugu yuksekligi — icerik artik status bar'in ALTINA girmiyor.
// (EditProfile basligi status bar'in arkasinda kaliyordu — gercek cihaz
// ekran goruntusunde yakalandi.)
// Web (yalnız `web_sahne` render'ı): durum çubuğu yok → 0. Böylece sahne
// görüntüsü onaylanan tasarımla AYNI koordinat sisteminde karşılaştırılır;
// cihazda üstteki pay durum çubuğu kadar (Android gerçek değer, iOS 48).
export const TOPPAD = Platform.OS === "android" ? (StatusBar.currentHeight || 24) : Platform.OS === "web" ? 0 : 48;

// bant iç kenar boşluğu — tasarımda 64/1080 ≈ %5.9
const SP_BANT = 20;
// Ana eylem düğmesindeki gradyanın bant sayısı — 3'ten çıkarıldı,
// sebebi `Btn` içindeki 30 Ağustos notu.
// 🔴 12 Eylül · akşam — `BTN_BANT` KALDIRILDI: düğme gradyanı artık
// `assets/altin.png` (512 satır, `brand/build_altin.py`). Bkz. `Btn`.

// ============================================================
// MVP Sbar (satir 325) — HER ekranin tepesindeki marka cubugu:
// beyaz zemin, ortada L O U N G E L I N K altin + genis harf araligi,
// altta ince cizgi. MVP APK'sinin en ayirt edici ogesi.
// ============================================================
export function BrandBar({ right }) {
  return (
    <View style={{
      backgroundColor: C.card, borderBottomWidth: 1, borderBottomColor: C.line,
      paddingTop: TOPPAD + 6, paddingBottom: SP[2], paddingHorizontal: SP[4],
      flexDirection: "row", alignItems: "center", justifyContent: "center",
    }}>
      {/* v3.1 — marka serife çevrildi, sonra GERİ ALINDI. Gökberk sans
          hâli seçti: serif marka + serif başlık bloğu ağırlaştırıyor ve
          bu bir çalışma ekranı, dergi kapağı değil. */}
      <Text style={{ fontSize: FS.xs, color: C.goldText, letterSpacing: 4, fontWeight: "700" }}>LOUNGELINK</Text>
      {right ? <View style={{ position: "absolute", right: 12, bottom: 5 }}>{right}</View> : null}
    </View>
  );
}

// MVP Btn (satir 359) — 7 varyant, hepsi anlamli
// 🔴 v2.65 — CTA ZEMİNLERİ OKUNABİLİRLİK KATMANINA GEÇTİ.
// Altın işaret rengi (#B8943A) üzerine beyaz metin 2.86:1'di. Zemin
// artık C.goldBtn (5.15:1), kenarlık da aynı — buton hâlâ altın
// ailesinde ama metin okunuyor. Marka çapası C.gold olarak duruyor;
// değişen yalnız METİN TAŞIYAN yüzeyler.
// 🔴 BU TABLO DA `C`DEN DEĞER KOPYALIYOR — VE KOYU TEMA NÖBETÇİM
// BUNU KAÇIRDI. `koyu_check.py` "değer kopyalayan yapılar yeniden
// kuruluyor mu" diye soruyor ama listesinde `ui.js` yoktu; ben de
// listeyi ELLE yazmıştım. Yani nöbetçi, benim hatırladığım kadarını
// koruyordu.
//
// Sonuç: koyu temada `Btn` düğmeleri AÇIK tema zeminiyle çizilirdi.
// Mount testi de görmedi, çünkü "açık tema sızdı mı" listesinde yalnız
// üç yüzey rengi vardı; düğme zeminleri yoktu. İkisi de düzeltildi.
//
// 🆕 SINIF: "ELLE YAZILMIŞ BİR NÖBETÇİ LİSTESİ, YAZANIN HAFIZASI
// KADAR KAPSAMLIDIR — LİSTEYİ KAPSAMIN KENDİSİNDEN TÜRETEMİYORSAN,
// EN AZINDAN ONU BOZMAYI DENE."
//
// `danger` de eklendi: `Btn` `v="danger"` ile çağrılıyordu ama tabloda
// karşılığı yoktu ve sessizce `BTN.gold`a düşüyordu. Çalışıyordu —
// çünkü ana eylemde kenarlık çizilmiyor — ama "çalışıyor ama yanlış
// yerden" bir sonraki değişiklikte kırılır.
// ════════════════════════════════════════════════════════════════════════
// 🔴 18 EYLÜL (Gökberk md.5) — BİRİNCİL DÜĞMENİN GRADYANI ARTIK TEMAYA
// GÖRE SEÇİLİYOR.
// Ölçüm (gerçek render, iki tema):
//     tema   zemin      metin      çizilen gradyan
//     açık   #6E5620    #FFFFFF    #E2D4B8 → #B49B70   ← KOYU PALET
//     koyu   #B49B70    #17120B    #E2D4B8 → #B49B70
// Yani açık temada beyaz yazı şampanyanın üstündeydi: 1.65:1 (AA 4.5).
// `brand/build_altin.py` artık iki PNG üretiyor; seçimi burası yapıyor.
// `require` STATİK olmak zorunda (Metro varlıkları derleme anında
// çözer) — bu yüzden ikisi de üstte bağlanıyor, seçim çalışma anında.
const ALTIN_KOYU = require("../assets/altin.png");
const ALTIN_ACIK = require("../assets/altin_acik.png");
const ALTIN_GRADYAN = () => (temaModu() === "koyu" ? ALTIN_KOYU : ALTIN_ACIK);

// ══════════════════════════════════════════════════════════════════════
// 🔴 20 EYLÜL — BİRİNCİL DÜĞMENİN METNİ AA'NIN YARISINDAYDI.
//
// `gold` varyantı `fg: "#fff"` yazıyordu. Koyu temada zemin
// `C.goldBtn = #B49B70`; beyaz metinle kontrast **2.67:1** — gereken 4.5.
// Bu, uygulamanın EN ÇOK BASILAN düğmesi: "Kaydet ve Devam", "Galeriden
// seç", her altın birincil eylem.
//
// Doğru jeton ZATEN VARDI: `KOYU.onGold = "#17120B"` (theme.js:1284) ve
// onunla oran **6.97:1**. Yani palet doğruydu, çağrı yeri jetonu
// atlamıştı. `purple` varyantı üç satır aşağıda `C.onGold || "#fff"`
// diye DOĞRU yazılmış — biri düzeltilirken öteki atlanmış.
//
// `rose` de aynı kusurdaydı: `C.red = #C97E76` üstünde beyaz **3.12**,
// `C.onGold` ile **5.97**.
//
// NEDEN HİÇBİR KAPI GÖRMEDİ: `yuzey_kontrast_check.py` SATIR İÇİ stil
// nesnelerindeki renk çiftlerini ölçüyor (16 çift, hepsi geçiyor).
// Burası bir ARAMA TABLOSU — `bg` ve `fg` aynı nesnede ama bir stil
// nesnesi değil, o yüzden tarayıcının desenine hiç düşmüyordu.
// `dugme_kontrast_check.py` bu tabloyu okumak için yazıldı.
//
// 🆕 SINIF: "BİR DENETİM STİL NESNELERİNİ TARIYORSA, RENGİ STİL
// NESNESİ OLMAYAN BİR YERDE TUTAN HER TABLO O DENETİMİN KÖR NOKTASIDIR."
// ══════════════════════════════════════════════════════════════════════
const BTN = {
  gold:    { bg: C.goldBtn,  fg: C.onGold, bd: C.goldBtn },
  teal:    { bg: C.tealBtn,  fg: "#fff",   bd: C.tealBtn },
  danger:  { bg: C.dangerBtn, fg: "#fff",  bd: C.dangerBtn },
  // 🔴 3 Eylül — gece sisteminde DOLU MOR düğme yok (tasarım: tek dolgu
  // altın, ikincisi çizgili). `purple` varyantı altına eşlendi; çağrı
  // yerleri (bağlantı kabul/yanıtla) tasarımın birincil eylemiyle çizilir.
  purple:  { bg: C.goldBtn,  fg: C.onGold || "#fff", bd: C.goldBtn },
  rose:    { bg: C.red,      fg: C.onGold, bd: C.red },
  outline: { bg: "transparent", fg: C.goldText, bd: C.gold },
  // 🔴 30 Ağu · 8. tur — `ghost` tasarımın `.btn-cizgi`si oldu.
  //   .btn-cizgi{ border:1.5px solid var(--cizgi2);
  //               background:rgba(255,255,255,.03); color:var(--bulut) }
  // `C.bgAlt` DOLU bir yüzeydi ve ikincil eylemi birincille aynı
  // ağırlıkta gösteriyordu. Saydam zemin + belirgin kenar, sıralamayı
  // renkle değil AĞIRLIKLA anlatıyor.
  ghost:   { bg: "rgba(255,255,255,0.03)", fg: C.ink, bd: C.line2 || C.line },
  // Tasarımdaki `.ust-eylem` tonu: %4 beyaz zemin + `--cizgi2` kenar.
  // `ghost`tan ayrı, çünkü o GÖVDE yüzeyinde duruyor; bu MESH BAŞLIĞIN
  // üstünde ve zemininin ne olduğunu bilmiyor — o yüzden yarı saydam.
  ust:     { bg: "rgba(255,255,255,0.04)", fg: C.foto.baslik, bd: C.line2 || C.line },
  muted:   { bg: C.bgAlt,  fg: C.mutedAA, bd: C.line },
  // ──────────────────────────────────────────────────────────────────────
  // 🔴 v3.9 — YUMUŞAK (TINT) VARYANTLAR: `Btn`in İKİNCİ KAPSAM BOŞLUĞU.
  //
  // 123 elle yazılmış düğmenin dökümünde 15'i tam olarak aynı şeydi:
  //     zemin `C.goldBg` · metin `C.goldText` · kenar `C.gold + "40"`
  // Yani "ikincil, satır içi, tinti taşıyan" bir düğme. `Btn`de karşılığı
  // yoktu: `outline` saydam, `ghost` nötr gri. Bu yüzden 15 çağrı yeri
  // aynı üç satırı kendi kopyasında yazdı — ve dördü kenar rengini
  // atladı, ikisi `R.xs` çizdi.
  //
  // 🆕 SINIF: "BİR VARYANT TABLOSUNDA OLMAYAN AMA ÜRÜNDE 15 KEZ ÇİZİLEN
  // BİR GÖRÜNÜM, VARYANT TABLOSUNUN EKSİK OLDUĞUNUN KANITIDIR."
  //
  // ⚠️ `anaEylem` bunlara UYGULANMIYOR (yalnız gold/danger): tint zeminde
  // gradyan ve sıcak gölge, ikincil bir eylemi birincil gibi gösterirdi.
  goldSoft:   { bg: C.goldBg,   fg: C.goldText,  bd: C.goldLine },
  purpleSoft: { bg: C.purpleBg, fg: C.purpleInk, bd: C.goldLine },   // 3 Eylül: altın ailesi (theme.js eşlemesi)
  tealSoft:   { bg: C.tealBg,   fg: C.tealInk,   bd: C.teal + "40" },
  redSoft:    { bg: C.redBg,    fg: C.redInk,    bd: C.red + "40" },
  greenSoft:  { bg: C.greenBg,  fg: C.greenInk,  bd: C.green + "40" },
};
temaYenidenKur(() => {
  BTN.gold.bg = BTN.gold.bd = C.goldBtn;
  // 🔴 30 Ağu — altın düğmenin mürekkebi artık temadan geliyor.
  // Açık temada beyaz, koyu temada koyu. Gerekçe theme.js `C.onGold`.
  BTN.gold.fg = C.onGold;
  BTN.teal.bg = BTN.teal.bd = C.tealBtn;
  BTN.danger.bg = BTN.danger.bd = C.dangerBtn;
  BTN.purple.bg = BTN.purple.bd = C.goldBtn; BTN.purple.fg = C.onGold;   // 3 Eylül: altın (bkz. harita)
  BTN.rose.bg = BTN.rose.bd = C.red;
  BTN.outline.fg = C.goldText; BTN.outline.bd = C.gold;
  BTN.ghost.bg = C.bgAlt; BTN.ghost.fg = C.body; BTN.ghost.bd = C.line;
  BTN.muted.bg = C.bgAlt; BTN.muted.fg = C.mutedAA; BTN.muted.bd = C.line;
  BTN.goldSoft.bg = C.goldBg;     BTN.goldSoft.fg = C.goldText;   BTN.goldSoft.bd = C.goldLine;
  BTN.purpleSoft.bg = C.purpleBg; BTN.purpleSoft.fg = C.purpleInk; BTN.purpleSoft.bd = C.goldLine;
  BTN.tealSoft.bg = C.tealBg;     BTN.tealSoft.fg = C.tealInk;    BTN.tealSoft.bd = C.teal + "40";
  BTN.redSoft.bg = C.redBg;       BTN.redSoft.fg = C.redInk;      BTN.redSoft.bd = C.red + "40";
  BTN.greenSoft.bg = C.greenBg;   BTN.greenSoft.fg = C.greenInk;  BTN.greenSoft.bd = C.green + "40";
});

// ============================================================================
// 🔴 v3.1 — ONAYLANAN DÜĞME SİSTEMİ ARTIK BURADA.
// Gökberk `dugmeler.jpg`i onayladı; o tasarım bir Python çizim betiğinin
// içinde yaşıyordu, yani onaylanan şey ÜRÜNDE YOKTU. Bir tasarım, ürün
// kodunda karşılığı olana kadar bir resimdir.
//
// Dört öge, dördü de ölçülmüş (bkz. ui_onerisi/dugmeler.py):
//   1 · GRADYAN — düz altın yerine altından derin kehribara.
//       `expo-linear-gradient` KURULU DEĞİL ve bunun için kurmuyorum:
//       56px'lik bir düğmede üç katmanlı yığın gradyandan ayırt edilmiyor.
//       Yeni bir yerel bağımlılık = yeni bir build kırılma noktası.
//   2 · SICAK GÖLGE — shadowColor nötr siyah değil, altın ailesinden.
//   3 · ÜST IŞIK — 1px açık kenar; ışık yukarıdan geliyor.
//   4 · YÜKSEKLİK/YARIÇAP — BTN.yukseklik 56, radius R.md (20).
//
// KONTRAST, GRADYANIN KOYU UCUNDA ölçülür — açık ucunda değil. Metin
// düğmenin her yerinde okunmalı; ortalama okunurluk diye bir şey yok.
// ============================================================================
// ══════════════════════════════════════════════════════════════════════════
// 🔴 v3.6 — `Btn` NEDEN 138 KEZ ATLANDI: ÇÜNKÜ SADECE BİR ŞEY OLABİLİYORDU.
//
// Denetimde sayıldı: uygulamada 289 dokunulabilir var; 76'sı `<Btn>`,
// **138'i elle yazılmış düğme** (zemin + yarıçap + metin). Yani düğmelerin
// %64'ü bileşeni atlıyor.
//
// Sebep suçlama değil, TASARIM: `full = true` varsayılanı ve SABİT
// `height: yuk` (56 / 44). `Btn` yalnız tam genişlikte bir blok olabiliyordu.
// Bir çip, bir segment, bir satır içi eylem — hiçbiri bu kalıba girmiyor.
// O yüzden her biri elle yazıldı; ve her biri kendi yüksekliğine, kendi
// yarıçapına, kendi zeminine karar verdi.
//
// 🆕 SINIF: "BİR BİLEŞEN SÜREKLİ ATLANIYORSA SORUN DİSİPLİNDE DEĞİL
// KAPSAMDADIR — KARŞILAMADIĞI HER İHTİYAÇ, KENDİ KOPYASINI DOĞURUR."
//
// Üç yeni boyut, üçü de aynı `BTN` varyant tablosunu kullanıyor:
//   `sm`   → 44 (mevcut, dokunma tabanı)
//   `cip`  → 36, hap yarıçapı, satır içi; dokunma alanı `hitSlop` ile 44
//   `mini` → 32, yalnız salt-okunur bağlamda (rozet gibi davranan eylem)
// `full={false}` artık gerçekten satır içi çalışıyor: `alignSelf` da
// serbest bırakıldı, yoksa esnek bir satırda germeye devam ediyordu.
// ══════════════════════════════════════════════════════════════════════════
export function Btn({ label, onPress, v = "gold", sm, cip, mini, daire, disabled,
                     full = true, style, a11yLabel, busy, sol, sag, solAd, sagAd }) {
  // 🔴 `busy` DÜĞMENİN KENDİ İŞİ — 30 EKRAN AYRI AYRI YAZIYORDU.
  // Her çağrı yeri şunu tekrarlıyordu:
  //     {busy ? <ActivityIndicator color="#fff" /> : <Text>{etiket}</Text>}
  // Aynı davranışı 30 yerde yeniden yazmak, 30 farklı bekleme deneyimi
  // riski demektir: biri rengi unutur, biri düğmeyi devre dışı bırakmayı
  // unutur, biri hiç göstermez. Bekleme durumu düğmenin DAVRANIŞIDIR.
  //
  // 🆕 SINIF: "BİR BİLEŞENİN DURUMUNU ÇAĞRI YERİNE BIRAKIRSAN, O DURUM
  // ÇAĞRI YERİ SAYISI KADAR FARKLI DAVRANIR."
  const st = BTN[v] || BTN.gold;
  disabled = disabled || busy;
  const anaEylem = !disabled && (v === "gold" || v === "danger");
  const ust = v === "danger" ? C.dangerBtn : st.bg;
  const altUc = v === "danger" ? (C.dangerBtn2 || st.bg) : (C.goldBtn2 || st.bg);
  // `cip`/`mini` verildiğinde `full` otomatik kapanır: bir çip tam
  // genişlikte olamaz. Çağrı yerinin ikisini birden yazmasını beklemek,
  // unutulacak bir kural yazmaktır.
  // 🔴 30 AĞUSTOS · 2. TUR — `daire` VARYANTI.
  // Tasarımın `.ust-eylem`i: 38px daire, 1px `--cizgi2` kenar, %4 beyaz
  // zemin, İÇİNDE YALNIZ İKON. Uygulamada üç yerde geçiyor (geri oku,
  // radar, profil) ve üçünü de elle yazsaydım `dugme_check.py` haklı
  // olarak sayardı — nitekim ilk denememde SAYDI (+1).
  //
  // 🆕 SINIF: "BİR TASARIMDA ÜÇ KEZ GEÇEN ŞEY BİR ÖRNEK DEĞİL BİR
  // BİLEŞENDİR; ÜÇÜNÜ DE ELLE YAZMAK, ÜÇ FARKLI GELECEK DEMEKTİR."
  if (cip || mini || daire) full = false;
  const yuk = daire ? 38 : mini ? 32 : cip ? 36 : sm ? (BOY.yukseklikKucuk || 44) : (BOY.yukseklik || 56);
  const yariCap = (cip || mini || daire) ? R.full : (BOY.radius || R.md);
  // 🔴 44pt DOKUNMA TABANI ÇİPTE DE KORUNUYOR — görsel yükseklik 36/32
  // olsa bile dokunma alanı `hitSlop` ile 44'e tamamlanıyor. Küçük bir
  // düğme küçük bir HEDEF demek değildir.
  const slop = yuk >= 44 ? undefined : (() => { const d = Math.ceil((44 - yuk) / 2); return { top: d, bottom: d, left: 4, right: 4 }; })();
  // ══════════════════════════════════════════════════════════════════
  // DİNAMİK KENAR IŞIĞI (specular) — 12 Eylül · akşam
  // Gökberk: "statik, dümdüz bir opacity olmasın; parmak dokunduğunda o
  // lüks ışık hafifçe parlasın."
  // Fiziksel karşılığı var: metal bir yüzeye bastığında yansıma açısı
  // değişir ve kenar parlar. Burada ışık %14'ten %30'a çıkıyor, 120ms
  // içinde; bırakınca 220ms'de geri iniyor (çıkış girişten yavaş — göz
  // "yaylanma" değil "sönme" görsün).
  // `useNativeDriver: true` — opacity native driver'a girer, JS köprüsü
  // kaydırma sırasında bile takılmaz.
  //
  // 🆕 SINIF: "BİR YÜZEYİN 'CANLI' HİSSETTİRMESİ HAREKETTEN DEĞİL
  // TEPKİDEN GELİR — DOKUNUŞA CEVAP VERMEYEN HER PARLAKLIK BİR RESİMDİR."
  const bas = useRef(new Animated.Value(0)).current;
  const parlak = bas.interpolate({ inputRange: [0, 1], outputRange: [1, 2.1] });
  const isikPay = Math.round(yuk / 2) + 2;   // hapın düz üst kenarı yarıçaptan sonra başlar
  const basla = () => Animated.timing(bas, { toValue: 1, duration: 120, useNativeDriver: true }).start();
  const bitir = () => Animated.timing(bas, { toValue: 0, duration: 220, useNativeDriver: true }).start();
  return (
    <TouchableOpacity onPress={disabled ? undefined : onPress} activeOpacity={0.75}
      onPressIn={disabled || !anaEylem ? undefined : basla}
      onPressOut={disabled || !anaEylem ? undefined : bitir}
      hitSlop={slop}
      accessibilityRole="button"
      accessibilityLabel={a11yLabel || (label == null ? undefined : String(label))}
      accessibilityState={{ disabled: !!disabled }}
      style={[{
        backgroundColor: disabled ? C.bgAlt : (anaEylem ? altUc : st.bg),
        // 🔴 4 Eylül — `daire` 38'lik DAİRE değil dik bir HAP çıkıyordu:
        // `width` anahtarı aşağıda ikinci kez yazılıp `undefined`a eziliyordu
        // (ölçüldü: geri dairesi 28×38). Tek `width`. Kenar tasarımdaki
        // `.ust-eylem` gibi 1px.
        borderWidth: anaEylem ? 0 : daire ? 1 : 1.5, borderColor: disabled ? C.line : st.bd,
        borderRadius: yariCap, paddingHorizontal: daire ? 0 : (cip || mini) ? 12 : 18,
        minHeight: yuk, height: yuk, justifyContent: "center",
        alignItems: "center", flexDirection: "row",
        width: full ? "100%" : daire ? yuk : undefined,
        alignSelf: full ? undefined : "flex-start",
        overflow: "hidden",
        opacity: disabled ? 0.65 : 1,
      }, anaEylem && BOY.golge, style]}>
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS — "TIRTIKLI" DÜĞMELER. İKİ SEBEP, İKİSİ DE BU
          DOSYADA ZATEN ÇÖZÜLMÜŞTÜ — SADECE BURAYA UYGULANMAMIŞTI.

          Gökberk: "salon ara butonunda tırtıklı görünüm var… özellikle
          kahverengi butonlarda tırtıklı yapı devam ediyor."

          (1) ÜÇ BANT AZ. Eski not "üç bant yeter, ölçüldü" diyordu ama
              ölçüm yanlış yerde yapılmıştı: komşu iki bant arasında
              %34 opaklık farkı var. `FotoBant` tam bu dersi 660. satırda
              yazıyor — orada 8 bant yetmemiş, 24'e çıkılmıştı. Aynı göz,
              aynı ekran, aynı fizik; düğmede farklı davranmıyor.

          (2) BANTLAR BİNDİRİYORDU. `top: i*33.4%` + `height: 34%` →
              her sınırda %0.6 bindirme. `FotoBant` 667. satırda bunun
              sonucunu yazmış: "yarı saydam katmanlarda 'biraz taşsın'
              diye verilen pay, boşluğu değil YENİ BİR ÇİZGİYİ üretir."
              Yani düğmedeki çizgiler, gradyanın kabalığından değil,
              tam olarak onu düzeltmek için konmuş paydan geliyordu.

          🆕 SINIF: **"BİR DERSİ BİR DOSYADA ÖĞRENMEK, O DOSYANIN
          TAMAMINDA UYGULAMAK DEĞİLDİR — ÖĞRENİLEN HER KURALIN GEÇERLİ
          OLDUĞU HER YERİ AYRICA ARAMAK GEREKİR."**

          Şimdi: 20 bant, sıfır bindirme (yükseklik tam adım), yumuşak
          geçiş (smoothstep). Adım %34'ten ~%5'e iniyor. Maliyet 17 ek
          View, sıfır bağımlılık.
          ══════════════════════════════════════════════════════════════ */}
      {/* 🔴 12 EYLÜL · AKŞAM — 20 BANT GİTTİ, TEK PNG GELDİ.
          Gökberk: "tüm butonlarda bir çizgi oluşmuş." Ölçtüm; çizgi bir
          FAZLALIK değil bir EKSİKLİK'ti: bantların yüzdeleri cihaz
          pikseline yuvarlanınca bazı sınırlarda 1px BOŞLUK kalıyor ve
          orada düğmenin çıplak taban rengi görünüyor. Gerçek render'ın
          metinsiz sol sütununda:
              +10.7pt  bandın rengi     (band 4'ün altı)
              +11.0pt  ÇIPLAK ZEMİN     ← BOŞLUK
              +12.0pt  bandın rengi     (band 5'in üstü)
          30 Ağustos'ta "bindirme çizgi üretir" diye payı kaldırmıştım;
          meğer sıfır bindirme de bir varsayımmış.
          🆕 SINIF: "SIFIR BİNDİRME DE BİR VARSAYIMDIR — ALT PİKSEL
          YUVARLAMASI VARKEN BİTİŞİK ÇİZİLEN HER KATMAN YA BİNDİRİR YA
          BOŞLUK BIRAKIR."
          `assets/altin.png` üç duraklı, 512 satır, paletten üretiliyor
          (`brand/build_altin.py`). Sıfır sınır, 20 View yerine 1 Image. */}
      {anaEylem && (
        <Katman source={ALTIN_GRADYAN()} resizeMode="stretch"
          // 🔴 14 EYLÜL · GÖKBERK'İN CİHAZ EKRAN GÖRÜNTÜSÜNDEN ÖLÇÜLDÜ.
          // Önceki hâl `left:0, top:0, width:"100%", height:"100%"` idi ve
          // altın gradyan düğmenin SAĞ UCUNA KADAR GİTMİYORDU: son ~36pt'de
          // çıplak taban rengi kalıyor, ekranda sert bir dikey çizgi
          // görünüyordu. Ekran görüntüsünün pikselleri (1080×2312, 2.98x):
          //     düğme  x 88…992  (904px)
          //     gradyan x 88…888 (800px)   eksik 104px
          //     ebeveynin paddingHorizontal'i 18pt × 2 = 107px  ← birebir
          // Sebep: `left:0` KENARLIK kutusuna, `width:"100%"` ise İÇERİK
          // kutusuna göre çözülüyor. İkisi aynı kutuyu ölçmediği için
          // katman, ebeveynin yatay dolgusu kadar dar kalıyor.
          // 🆕 SINIF: "BİR KATMANI 'TAMAMINI KAPLASIN' DİYE KURUYORSAN
          // YÜZDEYLE DEĞİL KARŞIT KENARLA SABİTLE — `%100` HANGİ KUTUYU
          // ÖLÇTÜĞÜNÜ SÖYLEMEZ, `right:0` SÖYLER."
          style={{ position: "absolute", left: 0, top: 0, right: 0, bottom: 0 }} />
      )}
      {/* ÜST IŞIK — 1px, ışık yukarıdan.
          🔴 12 EYLÜL · AKŞAM — GÖKBERK: "tüm butonlarda bir çizgi oluşmuş."
          Haklı, ve sebebi benim kendi değişikliğim. Yarıçap 12'den 999'a
          (hap) çıkınca bu ışık çizgisinin geometrisi yanlış kaldı:
          `left/right: 10` bir hapın KAVİSİNİN İÇİNE düşüyor, yani çizgi
          artık üst KENARI değil düğmenin YÜZÜNÜ kesiyordu — ve düz uçları
          görünüyordu. Hapın düz üst kenarı x = yarıçap'ta başlar; ışık da
          orada başlamalı.
          İkinci kusur: beyaz %34, yeni şampanya dolgunun üstünde ΔE 7.33 —
          bir "ışık" değil bir ÇİZGİ. %14'te ΔE 3.10: kenarı belli eder,
          çizgi kurmaz. Basınca 0.30'a çıkıyor (aşağıdaki `parlak`).
          🆕 SINIF: "BİR KÖŞE YARIÇAPINI DEĞİŞTİRDİĞİNDE O KÖŞEYE GÖRE
          KONUMLANMIŞ HER ŞEYİ YENİDEN ÇÖZ — YARIÇAP BİR SÜS DEĞİL BİR
          KOORDİNAT SİSTEMİDİR." */}
      {anaEylem && (
        <Animated.View pointerEvents="none" style={{
          position: "absolute", left: isikPay, right: isikPay, top: 1, height: 1,
          opacity: parlak,
          // ⚠️ TEK KALAN HAM YARIÇAP — ve bilerek. Bu 1.5px'lik ışık
          // çizgisi bir daire de hap da değil; `R.full` onu görünür
          // biçimde uçlarından yer, `R.xs`(10) yüksekliğinin yedi katı
          // olduğu için hiçbir şey değiştirmez. Ölçeğe zorlamak,
          // ölçeğin ne işe yaradığını unutmak olurdu.
          // 🆕 SINIF: "BİR TASARIM ÖLÇEĞİ, ÖLÇEĞİN ALTINDA KALAN
          // AYRINTIYI DA YÖNETMEYE ÇALIŞIRSA ÖLÇEK OLMAKTAN ÇIKAR."
          borderRadius: 1, backgroundColor: C.btnUstIsik,
        }} />
      )}
      {busy
        ? <ActivityIndicator color={st.fg} size="small" />
        : (<>
            {/* `sol`/`sag`: satır içi ikon yuvaları. Bunlar olmadan her
                ikonlu düğme elle yazılıyordu — 138'in bir kısmı tam da
                bu yüzden vardı. */}
            {/* 🔴 30 AĞUSTOS · 3. TUR — `solAd`/`sagAd`: İKON ADIYLA YUVA.
                `sol`/`sag` bir DÜĞÜM alıyordu, yani her çağrı yeri ikonun
                RENGİNİ de kendi tahmin ediyordu — ve düğmenin mürekkebi
                varyanta göre değişiyor (altın→beyaz, hayalet→gövde). 230
                sembolü vektöre çevirirken bunu 230 kez doğru tahmin etmek
                zorunda kalacaktım; birinde yanılsam görünmez bir ikon.
                Ad verildiğinde rengi DÜĞMENİN KENDİSİ koyuyor.

                🆕 SINIF: "BİR YUVAYA HAZIR DÜĞÜM ALDIRIRSAN, YUVANIN
                BİLDİĞİ HER ŞEYİ ÇAĞRI YERİNE DE ÖĞRETMEK ZORUNDA
                KALIRSIN — ADI AL, DÜĞÜMÜ KENDİN KUR." */}
            {!!solAd && <Ikon ad={solAd} boy={sm || cip || mini ? 15 : 17}
                              renk={disabled ? C.dimAA : st.fg}
                              stil={{ marginRight: ARA[6] }} />}
            {!!sol && <View style={daire ? null : { marginRight: ARA[6] }}>{sol}</View>}
            {/* 🔴 12 EYLÜL — ETİKET KİBARLAŞTI.
                15/700/ls0 → 13.5/600/ls1.1. Harf aralığı düşen punto
                kadar önemli: 700 ağırlıkta sıfır aralık, harfleri
                birbirine yapıştırıp "kalın blok" hissi veriyordu.
                Aralık açıldığında aynı genişlikte AZ HARF durur ve
                düğme "bağıran" değil "kesin" okunur. */}
            {label == null || label === "" ? null : (
              <Text style={{ color: disabled ? C.dimAA : st.fg, fontWeight: "600",
                             fontSize: (cip || mini) ? 11.5 : sm ? 11.5 : 13.5,
                             letterSpacing: (cip || mini) ? 0.6 : 1.1 }}>{label}</Text>
            )}
            {!!sag && <View style={daire ? null : { marginLeft: ARA[6] }}>{sag}</View>}
            {!!sagAd && <Ikon ad={sagAd} boy={sm || cip || mini ? 15 : 17}
                              renk={disabled ? C.dimAA : st.fg}
                              stil={{ marginLeft: ARA[6] }} />}
          </>)}
    </TouchableOpacity>
  );
}

// ══════════════════════════════════════════════════════════════════════════
// 🔴 v3.9 — "123 ELLE YAZILMIŞ DÜĞME"NİN YARISI DÜĞME DEĞİLDİ.
//
// 28 Ağustos, Gökberk: "neden hâlâ çözmüyoruz bunları. Biz yapamıyo muyuz?"
//
// Gerekçem "123 görsel değişikliği cihazda görmeden yapmam"dı. Doğru itiraz
// aldı. Ama taşımaya oturunca ÇOK DAHA TEMEL bir şey çıktı: `dugme_check.py`
// bir `TouchableOpacity`yi "zemin + yarıçap varsa düğmedir" diye sayıyordu.
// 123'ün DÖKÜMÜNÜ çıkardım (metin sayısı · seçim durumu · şekil):
//
//     gerçek eylem düğmesi   (kabul · reddet · sohbet · doğrula…)   ~57
//     SEÇİM denetimi         (çip · segment · radyo · seçenek kartı) ~66
//
// İkinci grup `Btn` ile YAZILAMAZ — çünkü `Btn`in SEÇİLİ DURUMU YOK.
// Bir çipin "seçili" hâli zemini, kenarı, metin rengini VE metin kalınlığını
// birlikte değiştirir. 66 çağrı yerinin her biri bu dört kararı kendi
// başına verdi; bu yüzden aynı ekranda iki çip farklı kalınlıkta seçiliydi.
//
// 🆕 SINIF: "BİR BİLEŞENİN ATLANDIĞINI SAYAN DENETİM, ATLANANLARIN AYNI
// BİLEŞENE AİT OLDUĞUNU VARSAYAR — OYSA BORCUN YARISI EKSİK BİR BİLEŞENDİR,
// TAŞINMAMIŞ BİR ÇAĞRI YERİ DEĞİL."
//
// Yani borç "taşımadım"dan değil, GİDECEK YER OLMAMASINDAN büyüktü. `Secim`
// o yer. Dört biçim, tek seçim dili:
//
//   `cip`     satır içi hap        — filtre, meslek, dil, cinsiyet
//   `segment` satırda `flex:1`     — sıralama, rol, kapasite, dönem
//   `radyo`   tam genişlik + nokta — tekli seçim listesi
//   `kart`    başlık + alt satır   — rol seçimi, onay kartı
//
// SEÇİLİ HÂLİN KURALI TEK YERDE: zemin `<ton>Bg`, kenar `<ton>`, metin
// `<ton>Ink`, kalınlık 700. Seçilmemiş hâl: `C.card`, `C.line`, `C.body`,
// 400. Artık bir ekran bunun yarısını uygulayamaz.
//
// ⚠️ DOKUNMA TABANI: çipin görünen yüksekliği 34'e kadar inebilir; 44pt
// `hitSlop` ile tamamlanıyor — `Btn`deki kuralın aynısı, kopyası değil
// aynı hesabı yapan iki satır. (Ortak yardımcıya çekmedim: `Btn` sabit
// yükseklik, `Secim` iç boşlukla büyüyor — "aynı görünen" iki hesap.)
// ══════════════════════════════════════════════════════════════════════════
const SECIM_TON = {
  gold:   () => ({ bg: C.goldBg,   bd: C.gold,   fg: C.goldText  }),
  purple: () => ({ bg: C.purpleBg, bd: C.purple, fg: C.purpleInk }),
  teal:   () => ({ bg: C.tealBg,   bd: C.teal,   fg: C.tealInk   }),
  amber:  () => ({ bg: C.amberBg,  bd: C.amber,  fg: C.amberInk  }),
};

export function Secim({ etiket, alt, secili, onPress, ton = "gold",
                        bicim = "cip", ikon, sag, disabled, stil,
                        a11yRol = "button", coklu, dolu, zemin = "kart", a11yLabel }) {
  // 🔴 RENKLER ÇAĞRIDA OKUNUYOR, MODÜL YÜKLENİRKEN DEĞİL. `BTN` haritası
  // modül seviyesinde kurulduğu için tema değişince elle yeniden
  // yazılmak zorunda (`temaYenidenKur`). Aynı hatayı ikinci kez
  // yapmıyorum: `Secim` her çizimde güncel `C`yi okur, senkronize
  // edilecek ikinci bir kopya yok.
  // 🆕 SINIF: "TEMA DEĞİŞEBİLİYORSA, RENGİ ÖNBELLEKLEYEN HER YAPI BİR
  // SENKRONİZASYON BORCUDUR — OKUMAK ÖNBELLEKLEMEKTEN UCUZDUR."
  const T2 = (SECIM_TON[ton] || SECIM_TON.gold)();
  // 🔴 `dolu`: SEÇİLİ HÂL TİNT DEĞİL DOLU ZEMİN. Segmentli denetimlerde
  // (sıralama, rol) seçili öge canlıda DOLU mordu; hepsini tinte
  // çevirmek "birleştirme" değil, ONAYLANMIŞ BİR GÖRÜNÜMÜ ÖLÇMEDEN
  // DEĞİŞTİRMEK olurdu. Bileşen iki şiddeti de bilir; kural yine tek
  // yerde: dolu → zemin `ton`, metin `C.onAccent`.
  //
  // 🆕 SINIF: "BİRLEŞTİRME, VAR OLAN GÖRÜNÜMLERİ SİLMEK DEĞİL, HEPSİNİ
  // TEK BİR KURALIN İÇİNDEN ÜRETEBİLMEKTİR."
  const secZemin = dolu ? T2.bd : T2.bg;
  const secMetin = dolu ? C.onAccent : T2.fg;
  // Seçilmemiş zemin ÇAĞRI YERİNİN ÜSTÜNDE DURDUĞU YÜZEYE bağlı: bir
  // `C.card` çipi `C.card` bir kartın üstünde GÖRÜNMEZ. İki ada
  // kapatıldı — serbest renk değil.
  const bosZemin = zemin === "alt" ? C.bgAlt : zemin === "yok" ? "transparent" : C.card;
  const kart = bicim === "kart";
  const radyo = bicim === "radyo";
  const segment = bicim === "segment";
  const cip = bicim === "cip";

  const dikey = cip ? ARA[6] : segment ? SP[2] : SP[3];
  const yatay = cip ? SP[3] : segment ? SP[2] : SP[3];
  const yariCap = cip ? R.full : segment ? R.md : R.sm;
  const gorunen = (cip ? 14 : segment ? 18 : 20) + dikey * 2;
  const slop = gorunen >= TAP.minHeight
    ? undefined
    : (() => { const d = Math.ceil((TAP.minHeight - gorunen) / 2);
               return { top: d, bottom: d, left: 8, right: 8 }; })();

  return (
    <TouchableOpacity
      onPress={disabled ? undefined : onPress}
      disabled={!!disabled}
      activeOpacity={0.75}
      hitSlop={slop}
      accessibilityRole={a11yRol}
      accessibilityLabel={a11yLabel || (etiket == null ? undefined : String(etiket))}
      // 🔴 `selected` VE `checked` AYRI ŞEYLER. Ekran okuyucu bir çipte
      // "seçili", bir onay kutusunda "işaretli" der. Tek seçimli listede
      // `selected`, çok seçimlide `checked` doğrusu — `coklu` bunu söyler.
      accessibilityState={coklu ? { checked: !!secili, disabled: !!disabled }
                                : { selected: !!secili, disabled: !!disabled }}
      style={[{
        backgroundColor: secili ? secZemin : bosZemin,
        borderWidth: (secili && dolu) ? 0 : (kart || radyo ? 1.5 : 1),
        borderColor: secili ? T2.bd : C.line,
        borderRadius: yariCap,
        paddingVertical: dikey, paddingHorizontal: yatay,
        flexDirection: kart ? "column" : "row",
        alignItems: kart ? "stretch" : "center",
        justifyContent: segment ? "center" : "flex-start",
        alignSelf: cip ? "flex-start" : undefined,
        flex: segment ? 1 : undefined,
        opacity: disabled ? 0.55 : 1,
      }, stil]}>
      {/* Radyo noktası — seçili hâlin İKİNCİ işareti. Yalnız renkle
          anlatılan bir seçim, renk körü bir kullanıcıda kaybolur.
          🆕 SINIF: "SEÇİLİLİK TEK BİR KANALDAN ANLATILIRSA, O KANALI
          GÖREMEYEN KULLANICI SEÇİMİNİ GÖREMEZ." */}
      {radyo && (
        <View style={{ width: 16, height: 16, borderRadius: coklu ? R.onay : R.full,
                       borderWidth: 2, borderColor: secili ? (dolu ? C.onAccent : T2.bd) : C.dim,
                       marginRight: ARA[10], alignItems: "center",
                       justifyContent: "center" }}>
          {!!secili && <View style={{ width: 8, height: 8,
                                      borderRadius: coklu ? 2 : R.full,
                                      backgroundColor: dolu ? C.onAccent : T2.bd }} />}
        </View>
      )}
      {!!ikon && !kart && (
        <View style={{ marginRight: cip ? SP[1] : SP[2] }}>{ikon}</View>
      )}
      <View style={kart || radyo ? { flex: 1, minWidth: 0 } : undefined}>
        <Text numberOfLines={kart ? 2 : 1}
          style={{
            fontSize: cip ? FS.sm : kart ? FS.base : FS.sm,
            color: secili ? secMetin : (kart ? C.ink : C.body),
            fontWeight: secili ? "700" : (kart ? "700" : "400"),
            textAlign: segment ? "center" : "left",
          }}>{etiket}</Text>
        {!!alt && (
          <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[2] }}>{alt}</Text>
        )}
      </View>
      {!!sag && <View style={{ marginLeft: SP[2] }}>{sag}</View>}
    </TouchableOpacity>
  );
}

// MVP Input (satir 381) — etiket her zaman BUYUK HARF + letterSpacing

// MVP Card (satir 398) — accent kenarlik = baglamin rengi

// MVP Pill (satir 408) — nokta + etiket, rengi baglamdan alir
// ══════════════════════════════════════════════════════════════════════════
// 🔴 3 EYLÜL — `Cip`: TASARIMIN `.cip` / `.roz` ROZETİ, TEK YERDE.
//
// Ölçüler `mockup.py::cip` ile BİREBİR (onaylanan 17 ekran bununla çizildi):
//   yükseklik 26 · yarıçap 13 · yatay iç boşluk 11 · yazı 10.5/600
//   zemin: bgAlt (seçili → goldBg) · kenar ve yazı: ton rengi
//   ton: "gold" (varsayılan) · "teal" (iyi) · "amber" (uyarı) ·
//        "purple" (bilgi · #7FA8E8) · "notr" (sessiz)
// Uygulamada aynı rozet dört farklı şekilde çizilmişti (st.pill, Pill,
// Secim, elle yazılmış View'lar) ve hiçbiri tasarımın ölçüsünde değildi.
// Dokunulabilir olduğunda (onPress) 44pt dokunma alanı hitSlop ile sağlanır.
// ══════════════════════════════════════════════════════════════════════════
/* ════════════════════════════════════════════════════════════════════
   CÜZDAN ŞERİDİ — bandın içindeki 62pt cam şerit (tasarım 11 `.cuzdan`).
   5 Eylül — TEK BİLEŞEN: ana sayfa (misafir + host) ve profil aynı şeridi
   çiziyor. Hücreler şeridin TAMAMINA eşit dağılır (Gökberk: "veriler sola
   dayalı, sağda çok boşluk"); her hücre ortalı; ayraç `line2`.
   hucreler: [{ deger, etiket, onPress?, a11y? }]
   ════════════════════════════════════════════════════════════════════ */
export function CuzdanSeridi({ hucreler, stil }) {
  const sik = (hucreler || []).length >= 4;
  return (
    <View style={[{ flexDirection: "row", alignItems: "center", marginTop: ARA[22],
                    borderWidth: 1, borderColor: C.line, borderRadius: R.lg,
                    backgroundColor: "rgba(255,255,255,0.035)", height: 62 }, stil]}>
      {hucreler.map((h, i) => (
        <React.Fragment key={h.etiket + i}>
          {i > 0 && <View style={{ width: 1, height: 26, backgroundColor: C.line2 || C.line }} />}
          <TouchableOpacity disabled={!h.onPress} onPress={h.onPress || undefined} hitSlop={TAP.slop}
            accessibilityRole={h.onPress ? "button" : undefined}
            accessibilityLabel={h.a11y || `${h.etiket}: ${h.deger}`}
            style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
            {/* mono satır yüksekliği ≥ 1.3× — Android üst çıkıntıyı kırpmasın */}
            <Text numberOfLines={1} style={{ fontFamily: MONO[600], fontSize: FS.title,
                                             lineHeight: Math.round(FS.title * 1.3), color: C.gold }}>{String(h.deger)}</Text>
            {/* 4+ hücrede (profil şeridi) SE 320'de hücre 69pt: "LOUNGEPUAN"
                1.3 aralıkla 76.6pt → ÖLÇÜLDÜ, taştı (0.6 ile 69.6 — hâlâ 0.6pt). Sık şeritte aralık 0.4. */}
            <Text numberOfLines={1} style={{ fontSize: FS.micro, color: C.dim, marginTop: ARA[3], fontWeight: "600",
                                             letterSpacing: sik ? 0.4 : 1.3 }}>{BUYUK(h.etiket)}</Text>
          </TouchableOpacity>
        </React.Fragment>
      ))}
    </View>
  );
}

// ══════════════════════════════════════════════════════════════════════
// OLGU — ÇERÇEVESİZ VERİ (12 Eylül)
//
// 🔴 NEDEN VAR
// Keşfet kartında üç hap yan yana duruyordu: "Misafir ücretsiz" (KARAR),
// "TK1979" (OLGU), "Aynı uçuş" (OLGU). Üçü de aynı kaplamayı taşıyınca
// üçü de aynı ağırlıkta okunuyordu — oysa ikisi yalnız bir bilgi, biri
// ürünün cevabı.
//
// `Olgu` bir hap değil: mono, harf aralıklı, BÜYÜK harf bir metin. Onu
// komşusundan ayıran şey çerçeve değil BOŞLUK (çağrı yerinde 20pt).
// Mono seçilmesi tesadüf değil: bu üründe DEĞİŞEN her sayı mono —
// "TK1979" de, "12 Eylül 14:20" de aynı ailedendir.
//
// 🆕 SINIF: "BİR BİLGİYİ KUTUYA ALMAK ONU AÇIKLAMAZ, YALNIZ AĞIRLAŞTIRIR
// — ÇERÇEVE BİR VURGUDUR VE HER ŞEY VURGULUYSA HİÇBİR ŞEY VURGULU
// DEĞİLDİR."
// ══════════════════════════════════════════════════════════════════════
export function Olgu({ metin, renk, stil }) {
  if (metin == null || metin === "") return null;
  return (
    <Text style={[{ fontFamily: MONO[500], fontSize: FS.xs, letterSpacing: 1.1,
                    color: renk || C.mutedAA }, stil]}>
      {BUYUK(metin)}
    </Text>
  );
}

export function Cip({ etiket, ton = "gold", secili, onPress, onLongPress, stil, a11yLabel, ikon,
                      isaret, dolgu, kabartma }) {
  // "ok": rozet mürekkebi (koyu temada nane #6FD9A8) — mockup `ton="ok"`;
  // Gökberk 5 Eylül: "güvenilir host rozetinde soldaki (mockup) renk daha iyi".
  // ──────────────────────────────────────────────────────────────────
  // 🔴 11 EYLÜL — `isaret` VE `dolgu`: RENK TEK BAŞINA ANLAM TAŞIYAMAZ.
  // theme.js'teki ölçüm: karar üçlüsü dikromazide çakışıyordu. Renkleri
  // ayırmak ΔE'yi 0.5'ten 30.5'e çıkardı ama ayrışma büyük ölçüde
  // AÇIKLIK farkına dayanıyor — yani "hangisi daha açık" bilmeyen biri
  // için hâlâ zayıf. İki renksiz ipucu ekleniyor:
  //   · isaret : ✓ / ✕ / bilgi — solda 12pt vektör glif
  //   · dolgu  : rozetin zemini tonun %14'ü (yalnız "karar" rozetlerinde)
  // Üçü birlikte gri tonlamada bile ayrı okunuyor (ölçüldü: dolgu var /
  // yok / var + üç ayrı glif).
  // 🆕 SINIF: "BİR AYRIMI YALNIZ RENGE YÜKLERSEN, O AYRIMI GÖREMEYEN
  // HERKES İÇİN AYRIM YOK DEMEKTİR — İKİNCİ BİR İPUCU BİR SÜS DEĞİL,
  // AYRIMIN KENDİSİDİR."
  // ──────────────────────────────────────────────────────────────────
  const RZ = C.badgeInk || {};
  const renk = ton === "teal" ? C.teal : ton === "amber" ? C.amber
             : ton === "purple" ? C.purple
             : ton === "ok" ? (RZ.ok || C.teal)
             : ton === "ucretli" ? (RZ.cost || C.amber)
             : ton === "engel" ? (RZ.block || C.red)
             : ton === "notr" ? C.mutedAA : C.gold;
  const zemin = secili ? C.goldBg
    : dolgu ? ((C.badge && C.badge[dolgu === true ? (ton === "ok" ? "ok" : ton === "engel" ? "block" : "cost") : dolgu] || {}).bg || C.bgAlt)
    : C.bgAlt;
  // ══════════════════════════════════════════════════════════════════
  // `kabartma` — KARAR ROZETİ BİR ETİKET DEĞİL, BİR MÜHÜR (12 Eylül)
  //
  // Gökberk: "durum etiketlerini arka planından ince bir derinlik
  // efektiyle ayır ki adeta bir broş veya kabartma mühür gibi premium
  // dursun."
  //
  // Koyu zeminde gölge tek başına iş görmez — karanlığın üstüne karanlık
  // hiçbir şey çizmez (aynı dersi `BTN.golge`de yazmıştık). Kabartmayı
  // üreten şey İKİ kenar: üstte ışık, altta gölge. Göz "yukarıdan gelen
  // ışık" varsayar ve iki kenarı birlikte görünce yüzeyi KALKIK okur.
  // Ölçüm (rozet zemini rgba(237,231,219,0.10) kart üstünde = #211F1E):
  //   üst ışık rgba(244,239,230,0.055) → ΔE 5.14  · kenarı belli eder
  //   alt gölge rgba(0,0,0,0.22)       → ΔE 4.38  · oturmayı verir
  // İlk denememde 0.10 / 0.40 yazmış ve yorumuna "5.6 / 3.1" demiştim;
  // ölçünce 9.20 / 8.00 çıktı — yani yazdığım sayı TAHMİNDİ. Değerler
  // ölçüme göre düşürüldü. Bir yorumdaki sayı, ölçülmediyse yorum değil
  // temennidir.
  // Yalnız KARAR rozetlerinde açık — bağlam çipleri düz kalıyor, yoksa
  // "her şey kabartma" olur ve kabartma anlamını kaybeder.
  //
  // 🆕 SINIF: "KABARTMA BİR GÖLGE DEĞİL BİR IŞIK YÖNÜDÜR — TEK KENARLA
  // DÜZ, İKİ KENARLA HACİMLİ OKUNUR."
  const ic = (
    <View style={[{ height: 26, borderRadius: R.full, paddingHorizontal: ARA[12],
                    flexDirection: "row", alignItems: "center", alignSelf: "flex-start",
                    backgroundColor: zemin,
                    borderWidth: 1, borderColor: renk },
                  kabartma ? {
                    shadowColor: "#000000", shadowOpacity: 0.38, shadowRadius: 6,
                    shadowOffset: { width: 0, height: 2 }, elevation: 3,
                    overflow: "hidden",
                  } : null, stil]}>
      {kabartma ? (
        <>
          <View pointerEvents="none" style={{ position: "absolute", left: 9, right: 9, top: 0,
                                              height: 1, backgroundColor: C.kabartmaIsik }} />
          <View pointerEvents="none" style={{ position: "absolute", left: 9, right: 9, bottom: 0,
                                              height: 1, backgroundColor: C.kabartmaDip }} />
        </>
      ) : null}
      {ikon ? <View style={{ marginRight: ARA[4] }}>{ikon}</View> : null}
      {isaret ? <Ikon ad={isaret} boy={12} kutu={12} renk={renk} stil={{ marginRight: ARA[4] }} /> : null}
      <Text numberOfLines={1} style={{ fontSize: 10.5, fontWeight: "600", lineHeight: 14,
                                       letterSpacing: kabartma ? 0.3 : 0,
                                       color: secili ? C.goldText : renk }}>{etiket}</Text>
    </View>
  );
  if (!onPress) return ic;
  return (
    <TouchableOpacity onPress={onPress} onLongPress={onLongPress} hitSlop={{ top: 9, bottom: 9, left: 4, right: 4 }}
      accessibilityRole="button" accessibilityLabel={a11yLabel || etiket}
      accessibilityState={{ selected: !!secili }}>
      {ic}
    </TouchableOpacity>
  );
}

export function Pill({ label, color = C.gold }) {
  return (
    <View style={{
      flexDirection: "row", alignItems: "center", alignSelf: "flex-start", gap: SP[1],
      backgroundColor: color + "12", borderWidth: 1, borderColor: color + "25",
      borderRadius: R.md, paddingHorizontal: SP[2], paddingVertical: SP[1],
    }}>
      <View style={{ width: 5, height: 5, borderRadius: R.full, backgroundColor: color }} />
      <Text style={{ fontSize: FS.xs, color, fontWeight: "500" }}>{label}</Text>
    </View>
  );
}

// MVP Bar (satir 316) — ic ekranlarin baslik cubugu.
// MVP APK'sindaki gorunum: beyaz zemin, SOLDA buyuk altin ‹ sevron,
// yaninda SERIF kalin baslik (Cormorant/Noto Serif), istege bagli
// alt yazi ve sagda aksiyon. Alti ince cizgi.
// ══════════════════════════════════════════════════════════════════════════
// 🔴 v3.6 — SPLASH'İN İMZASI ARTIK HER BAŞLIKTA.
//
// Gökberk: "splash ekranındaki temayı tüm uygulamaya taşı."
//
// Splash'in imzası üç öge: SERİF kahraman tipografi · ATMOSFERİK zemin ·
// ALTIN MİKRO-KAPİTAL eyebrow. İlk ikisi v3.4-3.6'da bütün ekranlara
// yayıldı. Üçüncüsü YAYILMAMIŞTI — ve tuhaf olan şu: ürün onu zaten
// biliyordu. `FotoBant`ın `ustBilgi` yuvası tam bu işi yapıyor
// ("IST · 27 Ağustos"). Yani fotoğraflı başlık markanın imzasını
// taşıyordu, düz başlık taşımıyordu. 45 `<Hdr>` çağrısının 38'inde
// başlığın üstünde hiçbir bağlam yoktu.
//
// 🆕 SINIF: "BİR TASARIM İMZASI ÜRÜNÜN BİR YARISINDA VARSA, DİĞER
// YARISINDA YOKLUĞU TERCİH DEĞİL KOPUKLUK OLARAK OKUNUR."
//
// `ustBilgi` yoksa `scene` kelimesine düşülüyor; ikisi de yoksa hiçbir
// şey çizilmiyor — yani hiçbir mevcut ekran değişmiyor, yalnız yuva açıldı.
// 🔴 30 AĞUSTOS · 5. TUR — `kahraman`: BAŞLIK İKİ SATIRA SIĞABİLSİN.
//
// Taşma kapısını önizleme için yazmıştım; ürünün kendi metnini yakaladı:
// giriş ekranının başlığı "Kaldığın yerden devam et" 34 puntoda tek
// satıra SIĞMIYOR ve `Bar` `numberOfLines={1}` ile onu KIRPIYORDU —
// "Kaldığın yerden deva…". Kullanıcının gördüğü ilk cümlelerden biri.
//
// 🆕 SINIF: **"BİR ÖNİZLEME KAPISI ÜRÜNÜN KENDİ VERİSİYLE ÇALIŞIYORSA,
// ÖNİZLEMEYİ DEĞİL ÜRÜNÜ DENETLER — VE ORADA BULDUĞU HER ŞEY GERÇEK
// BİR KUSURDUR."**
//
// `kahraman` verilince başlık tasarımın `.ust-h1` ölçüsünde ve
// SATIRLARA BÖLÜNEBİLİR: giriş kapısı ekranları (giriş · kayıt · şifre)
// bir liste başlığı değil, bir karşılama cümlesi taşıyor.
// Geri okunun ekran okuyucu etiketi: sözlükteki "‹ Geri" gibi metinlerden
// işaret karakterleri ayıklanır (tek yerde — sembol sayacı bunu iki kez saymasın).
const GERI_ISARET = /[\u2039\u203A]/g;
function geriEtiketi(t) { return String((t && t.back) || "Geri").replace(GERI_ISARET, "").trim(); }

export function Bar({ title, sub, onBack, right, t, ustBilgi, scene, kahraman, ustPay = 0 }) {
  const eyebrow = ustBilgi || scene || null;
  if (kahraman) {
    // 🔴 3 EYLÜL — TASARIM 16/17 (giriş kapısı): tek bir üst satır
    // [geri dairesi] [L O U N G E L I N K] [sağ], altında düğüm + iki
    // satırlık başlık; kart zemini ve alt çizgi YOK (sayfa zemininde).
    // Eskiden bunun üstünde ayrı bir BrandBar daha çiziliyordu → iki
    // "LOUNGELINK", iki çubuk.
    return (
      <View style={{ paddingHorizontal: ARA[22], paddingTop: TOPPAD + ARA[12], paddingBottom: ARA[8] }}>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          {onBack ? (
            <Btn v="ust" daire a11yLabel={geriEtiketi(t)}
              onPress={onBack} sol={<Ikon ad="sol" boy={20} renk={C.foto.baslik} />} />
          ) : null}
          <Text style={{ fontSize: FS.xs, fontWeight: "700", letterSpacing: 4.6, color: C.foto.marka,
                         marginLeft: onBack ? ARA[12] : 0, flex: 1 }}>LOUNGELINK</Text>
          {right ? <View style={{ marginLeft: SP[2] }}>{right}</View> : null}
        </View>
        <View style={{ marginTop: ARA[28] }}>
          {eyebrow ? (
            <Text numberOfLines={1} style={{ fontSize: FS.micro, color: C.goldText,
                   letterSpacing: 2.4, fontWeight: "700", marginBottom: ARA[8] }}>
              {BUYUK(String(eyebrow))}
            </Text>
          ) : null}
          <Text numberOfLines={3} style={{ fontSize: FS.hero, fontWeight: "700", color: C.ink,
                    letterSpacing: -1, lineHeight: SATIR(FS.hero) }}>
            {title}
          </Text>
          {sub ? <Text numberOfLines={2} style={{ fontSize: FS.sm, color: C.muted, marginTop: ARA[6],
                       lineHeight: Math.round(FS.sm * 1.35) }}>{sub}</Text> : null}
        </View>
      </View>
    );
  }
  return (
    <View style={{
      backgroundColor: C.card, borderBottomWidth: 1, borderBottomColor: C.line,
      // ══════════════════════════════════════════════════════════════════
      // 🔴 13 EYLÜL (Gökberk md.5, 5.1) — "headerdaki akış başlığı
      // telefonun üstteki simgeleri ile çakışıyor. Bunun yaşandığı tüm
      // sayfalarda düzeltmemiz lazım."
      // Ölçüldü: bu çubuğun HİÇ üst payı yok; durum çubuğu payını
      // ÜSTÜNDEKİ `BrandBar` taşıyordu (`paddingTop: TOPPAD + 6`).
      // `marka={false}` verilen ekranlarda BrandBar çizilmiyor ve başlık
      // y=0'dan başlıyor — yani saatin ve pil simgesinin arkasına giriyor.
      // Pay artık ÇUBUĞUN KENDİSİNDE: markasız her ekranda otomatik.
      // 🆕 SINIF: "BİR PAYI KOMŞU BİLEŞENİN TAŞIMASI, O KOMŞU
      // ÇİZİLMEDİĞİ GÜN PAYIN DA YOK OLMASI DEMEKTİR — PAY, ONA İHTİYACI
      // OLAN BİLEŞENİN KENDİSİNDE DURMALI."
      // ══════════════════════════════════════════════════════════════════
      paddingTop: SP[3] + (ustPay || 0), paddingBottom: SP[3], paddingHorizontal: SP[4],
      flexDirection: "row", alignItems: "center",
    }}>
      {onBack ? (
        <TouchableOpacity onPress={onBack} hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
          accessibilityRole="button"
          // t.back "‹ Geri" — sevron GÖRSEL bir işaret, ekran okuyucu onu
          // "sol tek tırnak" diye okur. Etikette yalnız kelime kalır.
          accessibilityLabel={geriEtiketi(t)}
          style={{ paddingRight: ARA[10], minHeight: TAP.minHeight, minWidth: TAP.minWidth, justifyContent: "center" }}>
          <Ikon ad="sol" boy={22} renk={C.goldText} />
        </TouchableOpacity>
      ) : null}
      <View style={{ flex: 1 }}>
        {/* Tasarımdaki `.dugum`: 10/700 · aralık .24em · BÜYÜK HARF · altın.
            Zemin burada fotoğraf değil düz koyu yüzey — altın ölçüldü:
            #E0BE7A / #1C1820 = 9.84:1. Fotoğraflı bantta aynı altın
            2.91'e düşüyor; oradaki karşılığı `C.foto.dugum`. */}
        {eyebrow ? (
          <Text numberOfLines={1} style={{ fontSize: FS.micro, color: C.goldText,
                 letterSpacing: 2.4, fontWeight: "700", marginBottom: ARA[3] }}>
            {BUYUK(String(eyebrow))}
          </Text>
        ) : null}
        {/* Serif DEĞİL. Tasarımda `.ust-h1` sans/700/sıkı; serif yalnız
            `.ust-h1.serif` — ve o varyant tek bir yerde, ana sayfadaki
            İSİMDE kullanılıyor. Serif bu sistemde "insan"ın ailesi. */}
        {/* 🔴 30 Ağu · 5. tur — `numberOfLines` 1'DEN 2'YE.
            Taşma kapısı ölçtü: "Gizlilik ve Veri Yönetimi Politikası"
            20pt'ta 295.5pt yer istiyor, 320pt cihazda 244pt var. Tek
            satırda o başlık "Gizlilik ve Veri Yöneti…" diye KIRPILIYORDU.

            Kırpmak bir çözüm değil bir gizlemedir: kullanıcı eksik
            cümleyi görür, ben logda göremem. İki satır ise ekranın
            başlığını uzatır — ki bir başlığın işi zaten kendini
            söylemektir.

            🆕 SINIF: "`numberOfLines={1}` TAŞMAYI ENGELLEMEZ, YALNIZ
            GÖRÜNMEZ KILAR — SIĞMAYAN BİR BAŞLIĞIN DOĞRU CEVABI DAHA
            AZ HARF DEĞİL, DAHA ÇOK SATIRDIR." */}
        <Text numberOfLines={kahraman ? 3 : 2}
              style={kahraman
                ? { fontSize: FS.hero, fontWeight: "700", color: C.ink,
                    letterSpacing: -1, lineHeight: SATIR(FS.hero) }
                : { fontSize: FS.title, fontWeight: "700", color: C.ink,
                    letterSpacing: -0.5, lineHeight: Math.round(FS.title * 1.2) }}>
          {title}
        </Text>
        {sub ? <Text numberOfLines={2} style={{ fontSize: FS.sm, color: C.muted, marginTop: 0,
                     lineHeight: Math.round(FS.sm * 1.35) }}>{sub}</Text> : null}
      </View>
      {right ? <View style={{ marginLeft: SP[2] }}>{right}</View> : null}
    </View>
  );
}

// BrandBar + Bar birlikte — her ic ekranin standart tepesi.
// title verilmezse yalniz marka cubugu cizilir (Ana Sayfa / Profil sekmeleri).
// ============================================================
// 🔴 SAHNE DİLİ APP'E TAŞINDI
// Site v0.14'te her bölümün kendi arka plan sahnesi ve başlığın
// arkasında dev soluk bir kelime var. App'te bu yoktu: aynı marka
// iki farklı yerde iki farklı his veriyordu. Uygulama açık temada
// kalır (okunabilirlik), ama başlık bandı artık markanın izini
// taşır: ince kanat yayı + hayalet kelime.
//
// Ölçülü tutuluyor — app bir çalışma aracı, dekor okumayı
// zorlaştırmamalı. Opaklıklar %4-6 bandında.
// ============================================================
// ============================================================
// 🔴 30 AĞUSTOS · 5. TUR — `ScenePad` KALDIRILDI (arşiv: _yedek_sahne/).
//
// NEYDİ: başlığın arkasında 74pt'luk soluk bir "hayalet kelime" ve
// köşeden geçen iki renkli yay. Açık temadaki "site dili"nden gelme.
//
// NEDEN GİTTİ — İKİ AYRI SEBEP, İKİSİ DE ÖLÇÜLDÜ:
//
// 1) GECE SİSTEMİ'NDE YOK. Onaylanan tasarımın CSS'inde ne bir
//    filigran kelime ne de bu yaylar var. Başlık ya mesh bandın
//    içinde ya da düz bir `.ic-h1`. Yani bu blok ürüne ikinci bir
//    görsel dil sokuyordu — ve iki dil konuşan bir arayüz, ikisini
//    de konuşmuyor demektir.
//
// 2) TAŞMA KAPISI YAKALADI: "GÜVENLİK" kelimesi 74pt'ta 350.4pt yer
//    istiyor, 320pt cihazda 320pt var. `overflow:hidden` bunu
//    gizliyordu — yani kelime zaten yarım çiziliyordu ve kimse
//    bilmiyordu, çünkü %4.5 opaklıkta.
//
// 🆕 SINIF: "DEKORU `overflow:hidden` İLE KIRPMAK, ONU DOĞRU
// YERLEŞTİRMEKLE AYNI ŞEY DEĞİLDİR — GÖRÜNMEYEN BİR HATA,
// OLMAYAN BİR HATA DEĞİLDİR."
// ============================================================


// ============================================================================
// FOTOĞRAFLI BAŞLIK BANDI — tasarımın ürüne geçtiği yer  (v3.1)
//
// 🔴 BU BİLEŞEN NEDEN BU KADAR AÇIKLAMALI
// Bugüne kadar bu bant yalnız bir Python çiziminde vardı. Beş tasarım
// kararının beşi de "sadece resimde" durumundaydı. Bir tasarım, ürün
// kodunda karşılığı olana kadar bir resimdir.
//
// ⚠️ RN'İN SINIRI VE NASIL AŞILDI — ÖLÇÜLDÜ, VARSAYILMADI
// Tasarımda metin gölgesi DÖRT geçişli (geniş hale + orta + iki temas
// gölgesi). React Native `textShadow*` ile TEK gölge verir. Ölçtüm:
//     tasarım · 4 geçiş · perde %36 → 5.06:1
//     RN      · 1 gölge · perde %36 → 2.80:1
// Yarıçapı büyütmek İŞE YARAMIYOR (4→2.90, 18→2.41; büyüdükçe kötüleşiyor,
// çünkü geniş bulanıklık haleyi seyreltiyor). Perdeyi %66'ya çıkarmak bile
// 3.70'te kalıyor ve fotoğrafı söndürüyor.
//
// Çözüm: AYNI METNİ DÖRT KEZ ÇİZ. Üç katman gölge, biri asıl metin.
// Tasarımın birebir kopyası, 5.06:1. Maliyeti: satır başına 3 fazladan
// `Text` düğümü — bir başlık için kabul edilebilir.
//
// 🆕 SINIF: "BİR TASARIMI PLATFORM 'DESTEKLEMİYOR' DEMEDEN ÖNCE, O ETKİYİ
// PLATFORMUN VERDİĞİ İLKELERLE YENİDEN KURMAYI DENE — GENELDE EKSİK OLAN
// ÖZELLİK DEĞİL, KATMAN SAYISIDIR."
//
// ⚠️ NE ÖLÇÜLMEDİ: bu sayılar tasarım aracının Gauss bulanıklığıyla
// modellenmiş hâli. RN'in `textShadowRadius` bulanıklığı aynı aileden ama
// birebir aynı çekirdek değil. GERÇEK CİHAZDA doğrulanmadı — Gökberk'in
// ekranında görülene kadar bunlar "beklenen değer".
// ============================================================================
// ══════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS · 8. TUR — BANT 19pt KISAYDI VE SON SATIR DIŞARI
// DÜŞÜYORDU.
//
// Gökberk: "kalkışına X saat X dk alanındaki text app önizlemesinde
// siyah alana da denk gelmiş. Tasarımdaki gibi üstteki görsel
// uzatılırsa sorun çözülür gibi." — teşhis birebir doğru.
//
// Oranı (520/1080) tasarımdan ALMAMIŞIM; tasarımın kendi yığınını
// hiç toplamamışım. `css.py`den satır satır:
//
//   .ust padding-top            20
//   marka satırı (.ust-eylem)   38
//   .dugum      margin-top 34 + 10
//   .ust-h1     margin-top  9 + 41.6   (40px × 1.04)
//   .ust-alt    margin-top 11 + 19.5   (13px × 1.5)
//   .ust padding-bottom         22
//   ─────────────────────────────────
//                              207.1pt
//
// 520/1080 × 390 = 187.8pt. 19.3pt EKSİK — ve eksik olan tam olarak
// son satırın oturduğu yer. Bant `minHeight` ile büyüyordu ama FOTOĞRAF
// KATMANI sabit yükseklikte çiziliyordu: yani büyüyen kısım mesh değil
// DÜZ SİYAHTI. Metin bandın içinde kalıyor, zemininin dışına çıkıyordu.
//
// 🆕 SINIF: "BİR KUTUYU İÇERİĞE GÖRE BÜYÜTÜRKEN ZEMİNİNİ BÜYÜTMEZSEN,
// METİN KUTUNUN İÇİNDE AMA TASARIMIN DIŞINDA KALIR."
//
// Yeni oran tasarımın yığınından TÜRETİLDİ, göz kararı değil:
//   207.1 / 390 = 0.531 → 574/1080
// ══════════════════════════════════════════════════════════════════
const BANT_ORAN = 574 / 1080;        // tasarımın kendi yığınından türetildi
const BANT_FOTO_GEN = 1180, BANT_FOTO_YUK = 1475;   // assets/bant.jpg piksel boyu
const FOTO_Y = 0.55;                 // kırpmanın dikey yeri (Gökberk'in seçimi)
const PERDE_GUC = 0.36;
// 🔴 12 EYLÜL — `PERDE_BANT` KALDIRILDI. Tam ekran perdesi artık
// `assets/perde.png` (512 adım, `brand/build_perde.py`); bkz. FotoSahne.
const ERIME_BANT = 14;               // alttan erimenin bant sayısı              // soldan sağa perde — ARANDI, bkz. yukarı
// 🔴 30 Ağu · 2. tur — mesh başlığın dikey tabanı ve halelerin halka sayısı.
// 18 bant: komşu iki bant arası ~%5.5 — düz koyu zeminde ayırt edilmiyor
// (bkz. bandın kendi 24-bant ölçümü; orada zemin PARLAK olduğu için daha
// çok bant gerekiyordu, burada zemin koyu).
export const MESH_BANT = 18;
const HALE_HALKA = 14;

/* Yumuşak radyal hale — RN'de `radial-gradient` yok.
   TEK daire yetmez: %30 opaklıkta kenarı çizgi gibi görünür. 14 eş
   merkezli daire, opaklık merkeze doğru kare artışla — kenar çözülüyor
   ve toplam opaklık merkezde `guc`e yaklaşıyor.

   🆕 SINIF: "BİR GRADYANI TEK KATMANLA TAKLİT EDERSEN GRADYAN DEĞİL
   BİR LEKE ELDE EDERSİN — GEÇİŞİ ÜRETEN ŞEY ADIM SAYISIDIR." */
export function Hale({ renk, cap, x, y, guc }) {
  const kat = 1 - Math.pow(1 - guc, 1 / HALE_HALKA);
  return (
    <View pointerEvents="none" style={{ position: "absolute", left: x - cap / 2, top: y - cap / 2 }}>
      {Array.from({ length: HALE_HALKA }, (_, i) => {
        const d = cap * (1 - i / HALE_HALKA);
        return (
          <View key={i} style={{
            position: "absolute", left: (cap - d) / 2, top: (cap - d) / 2,
            width: d, height: d, borderRadius: d / 2,
            backgroundColor: renk, opacity: kat,
          }} />
        );
      })}
    </View>
  );
}

// Gölge katmanları: (yarıçap, opaklık, aşağı kayma)
// 🔴 DIŞA AKTARILDI: nöbetçi bu sayıyı ölçüyor. Üç gölge + asıl metin =
// dört geçiş, ve 5.06:1 rakamı TAM OLARAK buna bağlı. Biri düşerse
// kontrast 4.33'e, ikisi düşerse 2.80'e iner ve hiçbir şey görünmez.
export const GOLGE_KATMAN = [
  { r: 22, a: 0.75, dy: 5 },
  { r: 10, a: 0.92, dy: 2 },
  { r: 3,  a: 1.00, dy: 1 },
];

// 🔴 30 Ağu · 5. tur — `satir` PROP'U EKLENDİ.
// Dört katmanın dördü de `numberOfLines={1}` yazıyordu. Hemen üstteki
// yorum ise "uzun başlık artık bandı BÜYÜTÜYOR, küçültülmüyor" diyordu
// — büyütmüyordu, KIRPIYORDU. Yorum kodu anlatmıyordu.
//
// Taşma kapısı Keşfet'in alt bilgisinde yakaladı: 296.5pt gerekiyor,
// 276pt var (320pt cihaz). Yani "…· filtrelemek için dokun" cümlesinin
// sonu görünmüyordu — üstelik o cümle KULLANICIYA NE YAPACAĞINI
// söyleyen tek cümleydi.
//
// ⚠️ Satır sayısı DÖRT KATMANDA DA AYNI olmalı: farklı olursa gölge
// asıl metinden kayar.
// ══════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS · 7. TUR — GÖLGE ARTIK VARSAYILAN DEĞİL.
//
// Gökberk: "sayfanın en üstünde yer alan loungelink font tipi bence
// tasarımdaki daha iyi." Ölçtüm — font AYNI (Plus Jakarta Bold, 4.6
// harf aralığı, %3 boy farkı). Farklı olan GÖLGEYDİ: bu bileşen her
// metni DÖRT KEZ çiziyor (3 gölge + 1 asıl) ve sonuç gözde daha
// KALIN, daha bulanık bir marka işareti oluyordu. Tasarımın `.marka`sı
// düz: `color:var(--bulut); opacity:.92`, gölge yok.
//
// GÖLGE NEDEN VARDI: bant bir FOTOĞRAFTI ve açık mürekkep parlak
// gökyüzünde kayboluyordu. Ama bant artık `.ust.mesh` — koyu taban +
// %16 fotoğraf. Zemini yeniden ölçtüm (bant.jpg'nin EN AÇIK pikseli,
// mesh harmanından sonra #3E3537):
//     marka #FAEEDC → 10.36:1     dugum #E0BE7A → 6.68:1
// Yani gölgenin çözdüğü sorun ARTIK YOK.
//
// 🆕 SINIF: "BİR ÇÖZÜMÜ AYAKTA TUTAN ŞEY GEREKÇESİDİR — ZEMİN
// DEĞİŞTİĞİNDE GEREKÇE DÜŞER, AMA ÇÖZÜM KENDİLİĞİNDEN DÜŞMEZ;
// ONU ELLE KALDIRMAK GEREKİR."
//
// ⚠️ Bileşen SİLİNMEDİ: `golge` prop'u ile hâlâ çağrılabiliyor.
// Splash gibi zemini GERÇEKTEN fotoğraf olan bir yer çıkarsa oraya
// geri gelir — ve o zaman yine ÖLÇÜLEREK gelir.
// ══════════════════════════════════════════════════════════════════
function GolgeliMetin({ children, style, satir = 1, golge = false }) {
  if (!golge) {
    return <Text numberOfLines={satir} style={style}>{children}</Text>;
  }
  return (
    // 🔴 18 EYLÜL — `pointerEvents` GÖLGE `Text`LERİNDEN KABA TAŞINDI.
    // Android'de `Text` de `ReactPointerEventsView` uygulamıyor (ölçüm:
    // `Katman` başlığı), yani gölge katmanları prop'a rağmen dokunmayı
    // yutuyordu. Üstelik en üstteki ASIL metinde prop hiç yoktu. Blok
    // yalnız metin çiziyor — tamamı kapanınca dokunuş, kabı saran
    // düğmeye (varsa) düşüyor.
    <View pointerEvents="none">
      {GOLGE_KATMAN.map((g, i) => (
        <Text key={i} numberOfLines={satir}
          style={[style, {
            position: i === 0 ? "relative" : "absolute",
            left: 0, right: 0, top: i === 0 ? 0 : g.dy,
            opacity: i === 0 ? 0 : 1,        // ilk katman yalnız yer tutar
            color: `rgba(10,6,6,${g.a})`,
            textShadowColor: `rgba(10,6,6,${g.a})`,
            textShadowOffset: { width: 0, height: g.dy },
            textShadowRadius: g.r,
          }]}>{children}</Text>
      ))}
      {/* 🔴 YER TUTUCU + GÖLGELER + ASIL METİN sırası önemli: gölgeler
          mutlak konumlu, bu yüzden akışta yer kaplayan görünmez bir
          kopya gerekiyor; yoksa satır yüksekliği sıfırlanır. */}
      <Text numberOfLines={satir} style={[style, {
        position: "absolute", left: 0, right: 0, top: 0,
        textShadowColor: "rgba(10,6,6,1)",
        textShadowOffset: { width: 0, height: 0 },
        textShadowRadius: 2,
      }]}>{children}</Text>
    </View>
  );
}

// ============================================================================
// TAM EKRAN FOTOĞRAF SAHNESİ — splash'in zemini
//
// Banttan farkı: burada fotoğraf TAM EKRAN ve perde ALTTAN yukarı çıkıyor
// (metin bloğu aşağıda). Kırpma da farklı: bant ufuk kuşağını alıyor,
// splash pencerenin tamamını.
//
// 🔴 UZATMA YOK. Fotoğrafı ekrana `cover` ile oturtunca yatayda kırpılıyor
// ama PENCERE TAM SIĞIYOR (ölçüldü: pencere x=277..1179, kırpma x=228..1308).
// Daha önce rengi uzatmak / aynalamak / bulanıklaştırmak denendi; üçü de
// yeni kusur üretti. Kusurları düzelterek değil SEBEBİ KALDIRARAK gitti.
// ============================================================================
export function FotoSahne({ children, perdeBas = 0.36, perdeGuc = 0.58, odak, odakAnim }) {
  // 🔴 11 EYLÜL — `odak`: AYNI FOTOĞRAFIN FARKLI KADRAJI (0…1).
  // Tanıtımda beş kart aynı fotoğrafı gösterince kaydırma "sayfa değişti"
  // hissi vermiyordu. `odak` fotoğrafı %14 büyütüp dikeyde kaydırıyor:
  // kart ilerledikçe kamera pencereye yaklaşıp buluta çıkıyor. Splash ve
  // giriş kapısı `odak` VERMİYOR — orada dönüşüm hiç uygulanmıyor, yani
  // o ekranların pikseli birebir aynı kaldı.
  // 🔴 12 EYLÜL · AKŞAM — `odakAnim`: KADRAJ ARTIK ZIPLAMIYOR, KAYIYOR.
  // `odak` bir SAYIYDI: kart değişince kamera bir karede atlıyordu.
  // Gökberk: "arkadaki uçak penceresi statik kalmamalı… bulutlar
  // derinlik hissiyle arkada akmalı (parallax)."
  // Şimdi çağıran bir `Animated.Value` verebiliyor; dönüşüm formülü aynı
  // (translateY = (0.5 − odak) × 90), yalnız değeri zamanla geliyor.
  // `useNativeDriver` ile çizim JS köprüsüne hiç uğramıyor.
  // Parallax'ı üreten şey iki katmanın FARKLI hızda kayması: fotoğraf 90pt
  // yol alırken perde sabit duruyor — yani ön plan (metin + perde) ile
  // arka plan (pencere) ayrışıyor.
  // 🆕 SINIF: "DERİNLİK BİR GÖLGE DEĞİL BİR HIZ FARKIDIR."
  // 🔴 12 EYLÜL · 3. TUR — PARALLAX ASİMETRİK OLDU.
  // Gökberk: "çok hafif bir ASİMETRİK parallax efekti ver."
  // Önceki hâl yalnız dikeydi ve doğrusaldı: kadraj yukarı-aşağı
  // kayıyordu. Simetrik bir hareket göz için "kaydırma" okunur,
  // "derinlik" okunmaz — çünkü gerçek bir pencereden bakarken sahne
  // asla tek eksende kaymaz.
  // Üç eksen, üç FARKLI eğri:
  //     translateY   45 → −45     (doğrusal · ana hareket)
  //     translateX   −6 → +13     (asimetrik · merkezi 0'da DEĞİL)
  //     scale      1.14 → 1.19    (yaklaşma · son kartta biraz daha yakın)
  // X'in merkezi kasten kaçık: 0.5'te 0 olsaydı hareket yine simetrik
  // olurdu. Şimdi sahne sola doğru bir yay çiziyor.
  // Üçü de native driver'a girer.
  // 🆕 SINIF: "SİMETRİK HAREKET KAYDIRMADIR, ASİMETRİK HAREKET
  // DERİNLİKTİR — GÖZ EKSENLERİN AYNI HIZDA OLMADIĞINI PARALLAX DİYE
  // OKUR."
  const buyut = odakAnim
    ? { transform: [
        { scale: odakAnim.interpolate({ inputRange: [0, 1], outputRange: [1.14, 1.19] }) },
        { translateY: odakAnim.interpolate({ inputRange: [0, 1], outputRange: [45, -45] }) },
        { translateX: odakAnim.interpolate({ inputRange: [0, 0.45, 1], outputRange: [-6, 2, 13] }) },
      ] }
    : odak == null ? null
    : { transform: [{ scale: 1.14 }, { translateY: Math.round((0.5 - odak) * 90) }] };
  return (
    <View style={{ flex: 1, backgroundColor: C.gece, overflow: "hidden" }}>
      <Katman anim source={require("../assets/bant.jpg")} resizeMode="cover"
        style={[{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
                 width: "100%", height: "100%" }, buyut]} />
      {/* ALTTAN PERDE — metin bloğunun üstünden başlayan uzun rampa.
          Rampa metnin ÜSTÜNDEN başlar; en altta tam değerine ulaşır.

          🔴 12 EYLÜL — 24 BANT GİTTİ, TEK PNG GELDİ.
          Gökberk: "onboarding tasarımlarında tırtıklı görünüm var."
          Ölçtüm (gerçek render · düz gökyüzü sütunu · x 900–1060):

              24 bant → bant sınırındaki 16 geçişin 13'ü GÖRÜNÜR
                        ortalama 7.11/255 · en büyük 11.88
              PNG     → görünür sıçrama 0/16
                        ortalama 0.85/255 · en büyük 2.39   (eşik ~3)

          Eski yorum "24 bant, şerit orada olmaz" diyordu ve ben o notu
          bir ölçüm sanmıştım — oysa bir TAHMİNDİ. 30 Ağustos'ta 10'dan
          24'e çıkarırken de aynı şeyi yapmıştım: adım sayısını artırmak
          sorunu küçültür, kaldırmaz.

          🆕 SINIF: "BİR SÜREKLİLİĞİ SONLU ADIMLA TAKLİT EDİYORSAN,
          ADIM SAYISINI ARTIRMAK ÇÖZÜM DEĞİL ERTELEMEDİR."

          `assets/perde.png` 512 satır taşıyor ve `stretch` ile geriliyor;
          ara satırları motor interpolasyonla çiziyor. Rengi paletten
          (`brand/build_perde.py` · `C.bg`), yani zemin değişirse perde
          de değişir. */}
      {/* ⚠️ `bottom: 0` YETMİYOR — VE BUNU GERÇEK RENDER SÖYLEDİ.
          İlk yazımda `top: X%` + `bottom: 0` vermiştim; DOM'u ölçünce
          perde 203pt'de başlayıp 715pt'de bitiyordu (ekran 844). Sebep:
          `Image` yükseklik verilmediğinde kaynağın KENDİ piksel boyunu
          (512) kullanıyor, `bottom` kısıtını çözmüyor. Yani perdenin
          altındaki ~130pt hiç örtülmüyordu ve fotoğrafın soğuk kabin
          mavisi orada çıplak duruyordu — Gökberk'in "alttaki gri alan"
          dediği şeyin ASIL sebebi buydu; perdenin gücü değil BOYU.
          🆕 SINIF: "BİR KUTUYU 'İKİ KENARINI SABİTLEYEREK' GERDİĞİNİ
          SANIYORSAN ÖLÇ — BAZI ÖĞELER KENDİ İÇSEL BOYUNU TERCİH EDER VE
          KISITI SESSİZCE YOK SAYAR." */}
      <Katman source={require("../assets/perde.png")} resizeMode="stretch"
        style={{ position: "absolute", left: 0, width: "100%",
                 top: `${perdeBas * 100}%`, height: `${(1 - perdeBas) * 100}%`,
                 opacity: perdeGuc }} />
      {children}
    </View>
  );
}

// 🔴 v3.4 — `eylem` VE `geri` SLOTLARI EKLENDİ. Sebebi aşağıda, `Hdr`de.
// ══════════════════════════════════════════════════════════════════════
// DARALAN BANT — kaydırınca 199pt'den 84pt'ye inen fotoğraflı başlık
//                                                          (12 Eylül)
//
// 🔴 NEDEN VAR — GÖKBERK'İN TEŞHİSİ VE ÖLÇÜMÜ
// "O alan scroll yapınca ekranla beraber aşağıya iniyor yani yapışık
// sanırım. Bu yüzden de aşağıda görmem gereken asıl alanları daha zor
// görüyorum."
//
// Doğruydu: bant `<ScrollView>`in DIŞINDA duruyordu, yani sabitti.
// Profil ekranının gerçek render'ında ölçtüm (390×844):
//
//     bandın alt kenarı        198.7 pt
//     sekme çubuğunun üstü     733.7 pt
//     kaydırılabilir pencere   535.0 pt   = ekranın %63.4'ü
//     kalıcı olarak dolu       309.0 pt   = ekranın %36.6'sı
//
// iPhone SE'de bant 170pt, kalan pencere ~%56.
//
// Üç seçenek vardı: (a) bugünkü sabit hâli, (b) daralan bant,
// (c) bandın tamamen kayıp gitmesi. (c) en çok yeri kazandırıyor
// (+199pt) ama bandın içinde yalnız dekor yok — cüzdan şeridi (kredi ·
// LoungePuan · güven) ve kimlik orada. Tamamen yok olursa kullanıcı
// "neredeyim" çıpasını kaybeder. (b) seçildi: **+115pt = +%21.5**.
//
// ⚠️ NEDEN YÜKSEKLİĞİ DEĞİL KONUMU ANİME EDİYORUM
// `height` native driver'a girmez; her karede JS köprüsünden geçer ve
// kaydırma sırasında takılır. `translateY` ve `opacity` girer. Bu
// yüzden bant KÜÇÜLMÜYOR, YUKARI KAYIYOR; kompakt çubuk da kabın ALT
// kenarına çapalı olduğu için kayarken tam olarak ekranın tepesine
// oturuyor. Sonuç aynı, maliyet sıfır.
//
// 🆕 SINIF: "BİR ANİMASYONU 'DOĞRU ÖZELLİK' ÜZERİNDEN YAZMAK, ONU AKICI
// YAZMAKTAN DAHA AZ ÖNEMLİDİR — KULLANICI HANGİ ÖZELLİĞİN DEĞİŞTİĞİNİ
// GÖRMEZ, TAKILDIĞINI GÖRÜR."
// ══════════════════════════════════════════════════════════════════════
export const BANT_KOMPAKT = 84;

export function bantYuksekligi() {
  return Math.round(Dimensions.get("window").width * BANT_ORAN);
}

/* Ekran tarafının tek satırlık bağlantısı:
     const bnt = useDaralanBant();
     <Hdr … foto={{…}} kaydir={bnt.kaydir} />
     <ScrollView {...bnt.scrollProps} contentContainerStyle={{ paddingTop: bnt.ustBosluk }}>
   `ustBosluk` bandın yüksekliği kadar: bant artık MUTLAK konumlu, yani
   akışta yer kaplamıyor; o yeri içeriğin dolgusu açıyor. */
export function useDaralanBant() {
  const kaydir = useRef(new Animated.Value(0)).current;
  // 🔴 YÜKSEKLİK HESAPLANMAZ, ÖLÇÜLÜR.
  // İlk yazımda `bantYuksekligi()` (genişlik × BANT_ORAN) yeterli
  // sanmıştım. Profil ekranının gerçek render'ı yalanladı: bant orada
  // avatar satırı + cüzdan şeridi taşıdığı için `minHeight`ı AŞIYOR ve
  // 199 değil ~250pt çiziyor. Sabit dolgu kullanınca ilk satır ("Yayın
  // & Davet") bandın altında kaldı.
  // Oran yalnız BAŞLANGIÇ değeri; gerçek yükseklik `onLayout`tan gelir.
  // 🆕 SINIF: "İÇERİĞE GÖRE BÜYÜYEN BİR KUTUNUN YÜKSEKLİĞİNİ FORMÜLLE
  // BİLDİĞİNİ SANIYORSAN, FORMÜLÜ DEĞİL KUTUYU ÖLÇ."
  const [tam, setTam] = useState(bantYuksekligi());
  const olc = useCallback((y) => {
    if (y > 0) setTam((eski) => (Math.abs(eski - y) > 1 ? y : eski));
  }, []);
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL — KAYDIRMA DEĞERİ, ALTINDAKİ YÜZEY DEĞİŞİNCE BAYATLIYOR.
  //
  // ⚠️ DÜRÜSTLÜK NOTU: bunu Gökberk'in Not2'sini ("sekmeler fazla yukarı
  // kaymış") araştırırken buldum ve İLK ÖLÇÜMDE Not2'nin nedeni SANDIM.
  // Sandığım ölçüm yanlıştı: Seyahatlerim sekmesinde bandın 78pt yukarı
  // kaydığını görmüştüm, ama dönüşümü ölçünce `matrix(1,0,0,1,0,0)`
  // çıktı — bant hiç kaymamıştı. 78pt, ölçüm aracımın kendi yapaylığıydı
  // (bkz. `web_sahne/bant_olcum.py`). Düzeltilmiş ölçümde beş sahnenin
  // BEŞİNDE de çipler birebir aynı yerde: 177–203, üstte 12pt, altta
  // 22pt. Yani Not2'nin sebebi BU DEĞİL.
  //
  // Ama buradaki kusur GERÇEK ve bağımsız olarak duruyor: bu kanca TEK
  // bir `Animated.Value` tutuyor ve o değer YALNIZ `onScroll` ile
  // güncelleniyor. Alt sekme değişince altındaki `ScrollView` yepyeni
  // bir bileşen (`Hosting` → `Trips`) ve offset'i 0'dan başlıyor — ama
  // HİÇ KAYDIRMA OLAYI ÜRETMEDİĞİ için `kaydir` eski değerinde kalıyor.
  // Erişilebilir yol: kullanıcı listeyi aşağı kaydırır, sonra bir
  // bildirimin derin bağlantısı alt sekmeyi değiştirir; yeni liste kısa
  // ya da BOŞSA geri kaydırıp düzeltmek de mümkün olmaz ve bant kalıcı
  // olarak yarı katlanmış kalır.
  //
  // 🆕 SINIF: "KAYDIRMA KONUMUNU BİR ANİMASYON DEĞERİNDE TUTUYORSAN,
  // ALTINDAKİ KAYDIRILAN YÜZEY DEĞİŞTİĞİNDE O DEĞER ARTIK BİR ŞEYİ
  // TEMSİL ETMEZ — SIFIRLANMASI GEREKİR."
  const sifirla = useCallback(() => { kaydir.setValue(0); }, [kaydir]);
  return {
    kaydir, olc, tam, sifirla,
    ustBosluk: tam,
    scrollProps: {
      scrollEventThrottle: 16,
      onScroll: Animated.event([{ nativeEvent: { contentOffset: { y: kaydir } } }],
                               { useNativeDriver: true }),
    },
  };
}

/* ⚠️ `Animated.event(..., {useNativeDriver:true})` YALNIZ `Animated.ScrollView`
   ile çalışır; düz `ScrollView`e bağlanırsa çalışma zamanında patlar.
   Bu satır o bağımlılığı tek yerde tutuyor — daralan bant kullanan her
   ekran `Kaydirma`yı kullanır, hangi sınıf olduğunu bilmesi gerekmez.
   🆕 SINIF: "BİR API'NİN GİZLİ ŞARTI VARSA, O ŞARTI ÇAĞIRANA BIRAKMA —
   ŞARTI SAĞLAYAN SARMALAYICIYI VER." */
export const Kaydirma = Animated.ScrollView;

export function DaralanBant({ kaydir, olc, tam: tamProp, kompaktBaslik, kompaktSag, children }) {
  const tam = tamProp || bantYuksekligi();
  const yol = Math.max(1, tam - BANT_KOMPAKT);
  const ortak = { inputRange: [0, yol], extrapolate: "clamp" };
  const kay = kaydir.interpolate({ ...ortak, outputRange: [0, -yol] });
  // Bant içeriği yolun %70'inde sönüyor: sonuna kadar görünür kalırsa
  // kompakt çubuğun altından "hayalet" olarak sızıyor.
  const sol = kaydir.interpolate({ inputRange: [0, yol * 0.7], outputRange: [1, 0],
                                   extrapolate: "clamp" });
  const bel = kaydir.interpolate({ inputRange: [yol * 0.45, yol], outputRange: [0, 1],
                                   extrapolate: "clamp" });
  return (
    <Animated.View pointerEvents="box-none"
      style={{ position: "absolute", left: 0, right: 0, top: 0, zIndex: 5,
               transform: [{ translateY: kay }] }}>
      <Animated.View style={{ opacity: sol }}
        onLayout={olc ? (e) => olc(Math.round(e.nativeEvent.layout.height)) : undefined}>
        {children}
      </Animated.View>
      <Animated.View pointerEvents="box-none"
        style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: BANT_KOMPAKT,
                 opacity: bel, backgroundColor: C.bg,
                 borderBottomWidth: 1, borderBottomColor: C.kartKenar,
                 flexDirection: "row", alignItems: "flex-end",
                 paddingHorizontal: ARA[22], paddingBottom: ARA[14] }}>
        <Text numberOfLines={1}
          style={{ flex: 1, fontFamily: F.serifGosterim, fontSize: FS.title,
                   color: C.ink, lineHeight: SATIR(FS.title, "serif") }}>
          {kompaktBaslik || ""}
        </Text>
        {kompaktSag || null}
      </Animated.View>
    </Animated.View>
  );
}

export function FotoBant({ marka = "LOUNGELINK", ustBilgi, baslik, altBilgi,
                          sag, eylem, geri, yukseklik, serifBaslik, serifYani, altIcerik }) {
  // 🔴 3 EYLÜL — `serifBaslik` ve `altIcerik` EKLENDİ.
  // Tasarımın ana sayfası (11_ana_misafir) bandın İÇİNDE iki şey daha
  // taşıyor: `.ust-h1.serif` (isim · Cormorant 52) ve `.cuzdan` şeridi.
  // App.js bunları bant DIŞINDA, düz bir View'da çiziyordu → cihazda
  // "düz siyah bant + çift LOUNGELINK". Bant tek yerde tanımlı olsun
  // diye slotlar buraya girdi; ana sayfa artık FotoBant'ı kullanıyor.
  const G = Dimensions.get("window").width;
  const Y = yukseklik || Math.round(G * BANT_ORAN);
  // 🔴 4 EYLÜL — BANT TASARIMDAN 54pt KISAYDI VE %35 DAHA KOYUYDU (ölçüldü:
  // tasarım bandı 207pt'te bitiyor, bizimki 151; ilk 60px ortalama parlaklık
  // 66 / 49). İki sebep:
  //   1) `Y` hesaplanıyor ama kaba HİÇ uygulanmıyordu — bant içerik kadardı.
  //      Tasarım: YB = max(G·BANT_ORAN, içerik). → `minHeight: Y`.
  //   2) `Hale` tasarımın radial-gradient'inin yarısıydı: çap 1.2·G iken
  //      tasarımda YARIÇAP 1.2·G; daire iken tasarımda elips (rx≠ry);
  //      14 halkalı basamak iken doğrusal düşüş. → Hale kalktı; iki hale
  //      `assets/bant_hale.png` (brand/build_bant_hale.py, önizlemeyle AYNI
  //      `mockup.radyal` fonksiyonundan) ve kutuya oranlı tanımlı olduğu için
  //      `stretch` ile her bant boyunda birebir.
  // Fotoğraf: tasarım `center 42% / cover` — RN `cover` %50'ye ortalar; kırpma
  // elle: genişliğe sığdır, fazlanın %42'si yukarı.
  const [olculenY, setOlculenY] = useState(Y);
  const fotoOran = G / BANT_FOTO_GEN >= olculenY / BANT_FOTO_YUK ? G / BANT_FOTO_GEN : olculenY / BANT_FOTO_YUK;
  const fotoG = BANT_FOTO_GEN * fotoOran, fotoY = BANT_FOTO_YUK * fotoOran;
  const fotoSol = -Math.max(0, fotoG - G) / 2;
  const fotoUst = -Math.max(0, fotoY - olculenY) * 0.42;
  return (
    // ══════════════════════════════════════════════════════════════
    // 🔴 30 AĞUSTOS — BAŞLIK ALANLARI BİRBİRİNE GİRİYORDU.
    //
    // Gökberk: "keşfet başlığındaki alanlar birbirine girmiş."
    // Ekran görüntüsünde "Keşfet" üst bilgisi LOUNGELINK'in ÜSTÜNE
    // biniyor ve "Tanış" başlığı onu eziyordu.
    //
    // ÖLÇÜM (393dp genişlikte):
    //   bant yüksekliği  Y = 393 × 520/1080 = 189
    //   içeriğin gereksinimi: 64 (üst satır) + 16 + 52 + 20 + 32 = 184
    //   → PAY: 5 piksel.
    //
    // Beş piksel pay, pay değildir. Durum çubuğu bir tık uzun bir
    // cihazda (`TOPPAD` büyür), kullanıcı yazı tipini büyüttüğünde ya da
    // başlık iki satıra düştüğünde içerik taşıyor; `justifyContent:
    // "flex-end"` de taşan bloğu YUKARI, marka satırının üstüne itiyor.
    //
    // 🆕 SINIF: **"SABİT ORANLA HESAPLANMIŞ BİR YÜKSEKLİK, İÇİNDEKİ
    // METNİN BÜYÜYEBİLECEĞİNİ VARSAYMAZ — ORAN TASARIMIN, İÇERİK
    // KULLANICININDIR."**
    //
    // `height` → `minHeight`: oran ARTIK TABAN, tavan değil. Fotoğraf
    // zaten bandın dört katı yükseklikte ve `overflow:hidden` ile
    // kırpılıyor; bant büyüyünce boşluk açılmıyor.
    // ══════════════════════════════════════════════════════════════
    <View style={{ width: "100%", overflow: "hidden", minHeight: Y,
                   backgroundColor: C.bg }}
          onLayout={e => { const h = e.nativeEvent.layout.height; if (h && Math.abs(h - olculenY) > 1) setOlculenY(h); }}>
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · İKİNCİ TUR — BANT DEĞİL, TASARIMDAKİ `ust.mesh`.

          Gökberk: "hâlâ kendi ürettiğin bu tasarıma uygun değil."
          Haklıydı ve sebebi kartta değil KABUKTAYDI. Tasarımdaki üst
          alan bir FOTOĞRAF BANDI değil:

              .ust.mesh{background:
                radial-gradient(120% 92% at 82% -14%, altın .30 → 0),
                radial-gradient(112% 88% at  8%  6%, mavi  .20 → 0),
                linear-gradient(180deg,#1A1620 0%, gece 100%)}
              .ust.mesh::after{ background:FOTO center 42%/cover;
                                opacity:.16; mix-blend-mode:screen }

          Yani zemin KOYU; fotoğraf yalnız **%16 doku**. Bizde ise
          fotoğraf tam opaklıkta zeminin kendisiydi ve okunabilirlik
          için üstüne 24 bantlık bir perde çekiliyordu. İki farklı
          malzeme, iki farklı his — ve benim ürettiğim önizlemede
          "gün batımı posteri", tasarımda ise "gece camı" çıkıyordu.

          🆕 SINIF: **"BİR TASARIMI KART KART UYGULAYABİLİRSİN AMA
          KABUK YANLIŞSA HİÇBİR KART DOĞRU GÖRÜNMEZ — KABUK, İÇİNDEKİ
          HER ŞEYİN ZEMİNİDİR."**

          RN'de `radial-gradient` ve `mix-blend-mode` yok. İkisini de
          var olan araçla kurdum ve ikisini de ÖLÇTÜM:

          · `screen` harmanı yerine düz alfa: fotoğrafın en açık
            pikselinde iki yöntemin ürettiği zemin luminansı
            0.0374 ve 0.0385 — **binde bir fark**. Yani burada screen
            harmanı bir görsel fark değil, bir isim farkı.
          · Hale (radial) için tek daire YETMEZ: %30 opaklıkta kenarı
            görünür. `Hale` bileşeni 14 eş merkezli daireyle çiziyor,
            opaklık düşüşü kare alınmış — kenar çözülüyor.

          YENİ ZEMİNDE KONTRAST YENİDEN ÖLÇÜLDÜ (fotoğrafın en açık
          dilimi, %16, #1A1620 üstünde → zemin (62,52,53)):
              marka  #FAEEDC  10.49:1
              başlık #FFFDF9  11.83:1
              ALTIN  #E0BE7A   6.76:1   ← eski bantta 2.91 idi
              alt    #A79B8A   4.41:1   ← AA'nın altında, açıldı
          Yani tasarımın GERÇEK ALTINI artık burada kullanılabiliyor;
          bir tur önce uydurduğum `C.foto.dugum` uzlaşmasına gerek
          kalmadı. Zemin değişince karar da değişti — tam da bir tur
          önce yazdığım sınıf.
          ══════════════════════════════════════════════════════════════ */}

      {/* 1 · DİKEY TABAN — `meshUst` → saydam.
          🔴 12 EYLÜL · PARİTE TURU — 18 BANT GİTTİ, TEK PNG GELDİ.
          Perdeyi ve düğmeyi tek görsele çevirmiştim, bu kopyayı
          atlamıştım; `cihaz_parite_check.py` buldu. Aynı alt piksel
          boşluğu burada da vardı, yalnız zemin koyu olduğu için daha
          az görünüyordu — "az görünen" ile "yok" aynı şey değil.
          `dikey.png` yalnız ALFA taşıyor; rengi `tintColor` veriyor,
          yani palet değişince bu da değişiyor. */}
      <Katman source={require("../assets/dikey.png")} resizeMode="stretch"
        tintColor={C.meshUst}
        // Karşıt kenarla sabit (bkz. kaplama_check.py). Bu kabın dolgusu
        // yok, yani bugün fark üretmiyor — ama kaba ileride dolgu
        // eklenirse katman sessizce daralmasın.
        style={{ position: "absolute", left: 0, top: 0, right: 0, bottom: 0 }} />

      {/* 2 · FOTOĞRAF — %16 doku. `center 42%/cover` (kırpma elle, yukarıda). */}
      <Katman source={require("../assets/bant.jpg")} resizeMode="stretch"
        style={{ position: "absolute", left: fotoSol, top: fotoUst, width: fotoG, height: fotoY,
                 opacity: 0.16 }} />

      {/* 3 · İKİ HALE — altın sağ üstte, mavi sol üstte; kutuya oranlı PNG. */}
      {/* ⚠️ width/height AÇIKÇA %100: yalnız inset verilince web'de Image kendi
          piksel boyunu (1080×574) alıyordu ve hale bandın altına taşıyordu
          (ölçüldü: alt-orta parlaklık 72, tasarım 42). */}
      <Katman source={require("../assets/bant_hale.png")} resizeMode="stretch"
        style={{ position: "absolute", left: 0, top: 0, width: "100%", height: "100%" }} />
      <View style={{ paddingHorizontal: ARA[22], paddingTop: TOPPAD + ARA[20] }}>
        {/* 🔴 5 EYLÜL — ÖLÇÜLDÜ: sağda daire olmayan bantlarda (Planım) eylem
            satırı yalnız marka yazısı kadar (14pt) kalıyordu; tasarım o satırı
            HER ZAMAN 38 (`.ust-eylem` dairesi) sayar. Sonuç: üst bilgi ve
            başlık 25pt yukarıda çiziliyor, altta boşluk kalıyordu
            (mockup 95 · uygulama 70). `minHeight: 38` — daire varken değişmez. */}
        <View style={{ flexDirection: "row", alignItems: "center", minHeight: 38 }}>
          {/* 🔴 GERİ OKU: fotoğraflı başlıkta HİÇ ÇİZİLMİYORDU. `Hdr`
              `onBack`i alıyor ama fotoğraf dalında kullanmıyordu; yani
              Keşfet, Planım ve Tanış'ta iOS'ta çıkış yolu yalnızca alt
              sekme çubuğuydu. */}
          {/* Tasarımdaki `.ust-eylem`: 38px daire, 1px `--cizgi2` kenar,
              %4 beyaz zemin, içinde VEKTÖR ok. Eskiden bir `‹` KARAKTERİ
              vardı ve serif ailenin metriklerine tabiydi — aynı sınıf
              hatayı `Pickers.js`teki `✕` ile bir kez ödemiştik. */}
          {geri ? (
            <View testID="bant-slot" style={{ marginRight: SP[3] }}>
              <Btn v="ust" daire a11yLabel="Geri" onPress={geri}
                sol={<Ikon ad="sol" boy={20} renk={C.foto.baslik} />} />
            </View>
          ) : null}
          <View style={{ flex: 1 }}>
            {/* Tasarımda `.marka`: 11/700, harf aralığı .42em (≈4.6px).
                3'lük aralık kelimeyi "kalın yazı" gibi gösteriyordu;
                4.6'da kelime bir MARKA İŞARETİNE dönüşüyor — okunacak bir
                kelime değil, tanınacak bir imza. */}
            <GolgeliMetin style={{ fontSize: FS.xs, fontWeight: "700",
                                   letterSpacing: 4.6, color: C.foto.marka }}>
              {marka}
            </GolgeliMetin>
          </View>
          {/* 🔴 EYLEM SLOTU: filtre düğmesi buraya geliyor. */}
          {/* 🔴 `testID="bant-slot"`: bu iki alan bandın KENDİ metni değil,
              dışarıdan gelen eylem alanları. `mount_test`in gölge-katman
              değişmezi (bandın her metni 4 düğüm = 3 gölge + 1 asıl)
              yalnız bandın kendi metinleri için geçerli; slot içeriği
              kendi zeminini getiriyor. İşaret olmadan denetim, doğru
              çalışan bir düğmeyi kusur sanıyordu. */}
          {eylem ? <View testID="bant-slot" style={{ marginLeft: SP[2] }}>{eylem}</View> : null}
          {sag ? <View testID="bant-slot" style={{ marginLeft: SP[2] }}>{sag}</View> : null}
        </View>
        {/* 🔴 `marginTop: SP[4]` ARTIK ZORUNLU BİR AYIRICI.
            Eskiden iki blok arasında yalnız `flex: 1` vardı; flex, yer
            YETMEDİĞİNDE ayırmaz — üst üste bindirir. Sabit bir boşluk,
            taşma hâlinde bile iki bloğun değmesini imkânsız kılar. */}
        {/* 🔴 2. TUR — `flex-end` GİTTİ, TASARIMIN SABİT RİTMİ GELDİ.
            Tasarımda başlık bloğu üstten YIĞILIYOR: `.dugum{margin-top:34}`
            → `.ust-h1{margin-top:9}` → `.ust-alt{margin-top:11}` ve alanın
            altında 22px pay var. `flex-end` bloğu tabana yapıştırıyordu;
            bu, bandın yüksekliği içeriğe göre değişince ritmi de
            değiştiriyor — yani iki farklı ekranda iki farklı boşluk.
            Sabit ritim her ekranda aynı. */}
        <View style={{ marginTop: ARA[34], paddingBottom: ARA[22] }}>
          {/* ══════════════════════════════════════════════════════════
              🔴 30 AĞUSTOS · GECE SİSTEMİ — BAŞLIK HİYERARŞİSİ TASARIMDAN.

              Tasarımdaki üç katman ve ölçüleri:
                .dugum   10/700 · aralık .24em · BÜYÜK HARF · ALTIN
                .ust-h1  40/700 · aralık -.028em · satır 1.04 · SANS
                .ust-alt 13     · sessiz

              İki gerçek sapma vardı:

              1) ÜST BİLGİ ALTIN DEĞİLDİ. Tasarımda "İSTANBUL · IST"
                 altın; bu tesadüf değil — düğüm noktası (havalimanı)
                 markanın kendi rengiyle işaretleniyor, çünkü ürünün
                 tamamı bir düğüm noktası etrafında dönüyor.

              2) BAŞLIK SERİF ÇİZİLİYORDU. Tasarımda `.ust-h1` SANS;
                 serif yalnız `.ust-h1.serif` varyantında ve o da tek
                 yerde kullanılıyor: ana sayfadaki İSİM. Yani serif bu
                 sistemde "yer" için değil "insan" için ayrılmış.
                 Ben ikisine de serif vermiştim — sistemin en anlamlı
                 ayrımını silmişim.

              🆕 SINIF: **"BİR TASARIMDA İKİNCİ BİR YAZI AİLESİ VARSA
              O AİLE BİR ROL TAŞIR. HER YERE UYGULARSAN AİLEYİ DEĞİL
              ROLÜ SİLERSİN — VE GERİYE YALNIZ SÜS KALIR."** */}
          {ustBilgi ? (
            /* 🔴 3 Eylül — `textTransform: "uppercase"` JS'in yerel-bağımsız
               toUpperCase'ini kullanır: "Selin" → "SELIN" (noktasız I).
               Tasarım "SELİN B." yazıyor. Türkçe büyük harf `BUYUK` ile. */
            <GolgeliMetin style={{ fontSize: FS.xs, fontWeight: "700",
                                   letterSpacing: 2.4, color: C.gold }}>
              {BUYUK(String(ustBilgi))}
            </GolgeliMetin>
          ) : null}
          {serifBaslik ? (
            /* `serifYani`: ismin sağında, taban çizgisine yakın bir çip (host
               rozeti — tasarım 12b). İsim daralır, çip sarılmaz. */
            <View style={{ flexDirection: "row", alignItems: "flex-end", flexWrap: "wrap", marginTop: ARA[8] }}>
              {/* flexWrap: SE 320'de "Gökberk İ." (52pt serif = 217pt) + rozet çipi
                  bir satıra sığmıyordu (167pt kalıyordu) → çip alt satıra
                  iner, isim küçülmez. Ref 390'da aynı satırda kalır. */}
              <Text numberOfLines={1} style={{ fontSize: FS.isim, fontFamily: F.serifGosterim,
                                               lineHeight: SATIR(FS.isim, "serif"),
                                               letterSpacing: -0.5, color: C.foto.baslik,
                                               flexShrink: 1 }}>
                {serifBaslik}
              </Text>
              {serifYani ? <View testID="bant-slot" style={{ marginLeft: ARA[12], marginBottom: ARA[10] }}>{serifYani}</View> : null}
            </View>
          ) : null}
          {baslik ? (
            <View style={{ marginTop: ARA[8] }}>
              {/* `adjustsFontSizeToFit` YOK: gölge katmanlarıyla birlikte
                  dört ayrı Text var, her biri kendi ölçeğini seçseydi
                  gölge asıl metinden kayardı. Uzun başlık artık bandı
                  BÜYÜTÜYOR (minHeight sayesinde), küçültülmüyor. */}
              <GolgeliMetin satir={2} style={{ fontSize: FS.bant, lineHeight: SATIR(FS.bant),
                                     fontWeight: "700", letterSpacing: -1.2,
                                     color: C.foto.baslik }}>
                {baslik}
              </GolgeliMetin>
            </View>
          ) : null}
          {altBilgi ? (
            <View style={{ marginTop: ARA[12] }}>
              <GolgeliMetin satir={2} style={{ fontSize: FS.sm, color: C.meshAlt,
                                     lineHeight: Math.round(FS.sm * 1.35) }}>
                {altBilgi}
              </GolgeliMetin>
            </View>
          ) : null}
          {altIcerik ? <View testID="bant-slot">{altIcerik}</View> : null}
        </View>
      </View>
    </View>
  );
}

// 🔴 30 AĞUSTOS — `marka` PROP'U EKLENDİ.
//
// Gökberk: "loading çıkan yerlerde 2 tane loungelink başlığı geliyor.
// Altında da ilgili sayfanın adı."
//
// Sebep: sekme KABUĞU zaten bir `<Hdr>` (yani bir `<BrandBar/>`) çiziyor
// (App.js ~1325). Sekmenin İÇERİĞİ yüklenirken `Load` bir `<Hdr>` daha
// çiziyordu. İki marka çubuğu + bir sayfa başlığı = üst üste üç başlık.
//
// Yani hata `Load`ta değil, `Hdr`in "beni kim çağırırsa marka çubuğunu da
// ben çizerim" varsayımındaydı. Bir bileşen, sahnede kendisinden başka
// kimsenin olmadığını varsayamaz.
//
// 🆕 SINIF: **"BİR BİLEŞEN KENDİ ÇEVRESİNİ VARSAYAMAZ — TEKİL OLMASI
// GEREKEN HER ŞEY, TEKİLLİĞİ ÇAĞIRANIN KARARINA BIRAKMALIDIR."**
export function Hdr({ title, sub, onBack, right, brandRight, scene, t, foto, ustBilgi, marka = true, kahraman, kaydir }) {
  // 🔴 `foto` AÇIK BİR TERCİH: her başlık fotoğraflı olmaz. Bant 520/1080
  // oranında yer kaplıyor ve bir LİSTE ekranında bu kabul edilebilir
  // (ölçüldü: iPhone SE'de ekranın %27'si, altında 3.5 ilan görünüyor);
  // bir FORM ekranında aynı yer, doldurulacak alanlardan çalınmış olur.
  if (foto) {
    // ══════════════════════════════════════════════════════════════════
    // 🔴 v3.4 — BU DAL `right` VE `onBack`İ SESSİZCE ÇÖPE ATIYORDU.
    //
    // Gökberk (28 Ağu): "keşfet, tanış gibi ekranlarda filtre butonu yok.
    // Sağ üstte filtre butonumuz vardı biliyosun."
    //
    // Düğme siliNMEMİŞTİ. `Discovery` onu hâlâ `right={...}` diye
    // geçiriyordu (ekranlar_ana.js) — ama `foto` verildiğinde bu dal
    // yalnız `brandRight`i iletiyor, `right` ve `onBack` hiçbir yere
    // gitmiyordu. Yani prop VARDI, imzada VARDI, bir dalda OKUNUYORDU —
    // ve diğer dalda buharlaşıyordu.
    //
    // `check.js`in prop-drop nöbetçisi de bunu göremezdi: o "prop imzada
    // var mı" diye sorar; burada vardı. Kayıp DAL DÜZEYİNDEYDİ.
    //
    // 🆕 SINIF: "BİR PROP'U İMZADA GÖRMEK ONUN KULLANILDIĞINI KANITLAMAZ —
    // İKİ DALI OLAN BİR BİLEŞENDE PROP, DALLARDAN BİRİNDE SESSİZCE ÖLEBİLİR."
    //
    // Aynı sebeple GERİ OKU da fotoğraflı ekranlarda hiç çizilmiyordu.
    // ══════════════════════════════════════════════════════════════════
    const bant = (
      <FotoBant marka="LOUNGELINK" ustBilgi={ustBilgi || foto.ustBilgi} baslik={title}
        altBilgi={sub} sag={brandRight} eylem={right} geri={onBack}
        altIcerik={foto.altIcerik} />
    );
    // 🔴 12 EYLÜL — `kaydir` VERİLDİYSE BANT DARALIR.
    // Verilmediğinde tek bir piksel değişmiyor: bu dal bugünkü davranışı
    // AYNEN döndürüyor. Yani daralma bir ekranın kendi kararı — form
    // ekranlarında (kaydırma yok) daralacak bir şey de yok.
    if (!kaydir) return bant;
    return (
      <DaralanBant kaydir={kaydir} olc={foto.olc} tam={foto.tam}
        kompaktBaslik={foto.kompaktBaslik || title || foto.ustBilgi}
        kompaktSag={right || brandRight}>
        {bant}
      </DaralanBant>
    );
  }
  return (
    <View>
      {marka && !kahraman ? <BrandBar right={brandRight} /> : null}
      {/* `scene` prop'u ARTIK ÜST ETİKET (eyebrow) OLARAK OKUNUYOR.
          Eskiden arkaya hayalet kelime çiziyordu; o blok kalktı. 47
          çağrı yerinde `scene="Güvenlik"` gibi anlamlı kelimeler
          duruyordu — onları çöpe atmak yerine tasarımın `.dugum`una
          bağladım: aynı bilgi, tasarımın kendi yerinde.
          (`ustBilgi` açıkça verildiyse o kazanır — elle seçilmiş
          olan her zaman kazanır.) */}
      {title ? (
        <Bar title={title} sub={sub} onBack={onBack} right={right} t={t}
             ustBilgi={ustBilgi || gorunur(scene)} kahraman={kahraman}
             ustPay={marka || kahraman ? 0 : TOPPAD + 6} />
      ) : null}
    </View>
  );
}

// MVP Avatar (satir 415)

// MVP bolum basligi — Settings'te ACCOUNT / PRIVACY / NOTIFICATIONS / DANGER ZONE

// Settings/Profil satiri: etiket + deger/ok
export function Row({ label, value, onPress, last, danger, icon }) {
  const body = (
    <View style={{
      flexDirection: "row", alignItems: "center", paddingVertical: SP[3],
      minHeight: TAP.minHeight,
      borderBottomWidth: last ? 0 : 1, borderBottomColor: C.line,
    }}>
      {icon ? <Text style={{ fontSize: FS.lg, marginRight: ARA[10] }}>{icon}</Text> : null}
      <Text style={{ flex: 1, fontSize: FS.base, color: danger ? C.red : C.ink }}>{label}</Text>
      {typeof value === "string"
        ? <Text style={{ fontSize: FS.sm, color: C.greenInk, fontWeight: "600", marginRight: onPress ? 7 : 0 }}>{value}</Text>
        : value}
      {onPress ? <Ikon ad="sag" boy={16} renk={danger ? C.red : C.dimAA} /> : null}
    </View>
  );
  return onPress ? (
    <TouchableOpacity hitSlop={TAP.slop} onPress={onPress} activeOpacity={0.6}
      accessibilityRole="button"
      accessibilityLabel={typeof label === "string" ? label : undefined}>
      {body}
    </TouchableOpacity>
  ) : body;
}

// MVP Toggle — Settings ve Profil'de
// 🔴 v2.65 — anahtarın GÖRSEL yüksekliği 25px; dokunulabilir alan artık
// 44px'lik saydam bir sarmalayıcı. Görünüm değişmedi, ıskalanan dokunuş
// bitti. Ekran okuyucu için rol "switch" ve durum bildiriliyor.
// ============================================================================
// 🔴 30 AĞUSTOS — ANLAŞTIĞIMIZ ANAHTAR TASARIMI UYGULANMAMIŞTI
//
// Gökberk: "switchli yerler için konuştuğumuz switch yapısı uygulanmamış
// gibi." Doğru — `Toggle` her yerde jenerik yeşil bir hapdı: iOS ayarlar
// ekranındaki anahtarın aynısı. Ürünün hiçbir yerine ait değildi.
//
// Referans: kapalıyken PİST (gri asfalt, kesikli orta çizgi, sarı kenar
// ışıkları, uçak solda beklerken), açıkken GÖKYÜZÜ (açık mavi, bulutlar,
// uçak sağda havada). Yani anahtar bir durum değil, bir HAREKET anlatıyor:
// kalkış. Ürünün tamamı bu anın etrafında kurulu.
//
// 🆕 SINIF: **"BİR ANAHTAR İKİ DURUM GÖSTERİR; İYİ BİR ANAHTAR İKİSİ
// ARASINDAKİ GEÇİŞİ ANLATIR. ÜRÜNÜN HİKÂYESİ EN KÜÇÜK BİLEŞENDE DE
// GEÇERLİDİR."**
//
// ⚠️ ERİŞİLEBİLİRLİK PAZARLIK KONUSU DEĞİL: `accessibilityRole="switch"`,
// `checked` durumu ve 44pt dokunma alanı aynen duruyor. Görsel değişti,
// sözleşme değişmedi.
//
// ⚠️ `useNativeDriver: true` — kayma ve solma GPU'da. Bir ayarlar
// listesinde altı anahtar aynı anda canlanabilir; JS iş parçacığında
// çizilen bir geçiş orada takılır.
// ============================================================================
export function Toggle({ val, onChange, disabled, a11yLabel }) {
  const G = 56, Y = 30, TOP = 24;          // genişlik · yükseklik · topuz
  const ilerle = useRef(new Animated.Value(val ? 1 : 0)).current;

  useEffect(() => {
    Animated.timing(ilerle, {
      toValue: val ? 1 : 0,
      duration: 260,
      useNativeDriver: true,
    }).start();
  }, [val, ilerle]);

  const kay = ilerle.interpolate({
    inputRange: [0, 1],
    outputRange: [0, G - TOP - ARA[4] * 2],
  });
  // Gökyüzü kapalıyken saydam, açıkken görünür — pistin ÜSTÜNDE duruyor.
  const gokOpak = ilerle;
  const pistOpak = ilerle.interpolate({ inputRange: [0, 1], outputRange: [1, 0] });

  return (
    <TouchableOpacity onPress={disabled ? undefined : () => onChange(!val)} activeOpacity={0.85}
      accessibilityRole="switch"
      accessibilityLabel={a11yLabel}
      accessibilityState={{ checked: !!val, disabled: !!disabled }}
      style={{ minHeight: TAP.minHeight, minWidth: TAP.minWidth,
               alignItems: "flex-end", justifyContent: "center" }}>
      <View style={{
        width: G, height: Y, borderRadius: Y / 2, overflow: "hidden",
        // 23 Eylül: 0.42'de "Kapatılamaz" (açık + kilitli) anahtarlar KAPALI
        // gibi okunuyordu. 0.62: kilitli olduğu belli, durumu da okunuyor.
        opacity: disabled ? 0.62 : 1, justifyContent: "center",
        backgroundColor: C.pistAsfalt,
      }}>
        {/* ── KAPALI: PİST ────────────────────────────────────────── */}
        <Animated.View pointerEvents="none" style={{
          position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
          backgroundColor: C.pistAsfalt, opacity: pistOpak, justifyContent: "center",
        }}>
          {/* kesikli orta çizgi */}
          <View style={{ flexDirection: "row", alignItems: "center",
                         paddingLeft: TOP + 4, paddingRight: 6 }}>
            {[0, 1, 2, 3].map((i) => (
              <View key={i} style={{ width: 4, height: 2, borderRadius: 1,
                                     backgroundColor: "#FFFFFF", opacity: 0.85, marginRight: ARA[4] }} />
            ))}
          </View>
          {/* kenar ışıkları */}
          <View style={{ position: "absolute", left: TOP + 4, right: 6, top: 4,
                         flexDirection: "row", justifyContent: "space-between" }}>
            {[0, 1, 2].map((i) => (
              <View key={i} style={{ width: 2.5, height: 2.5, borderRadius: 2,
                                     backgroundColor: C.pistIsik }} />
            ))}
          </View>
          <View style={{ position: "absolute", left: TOP + 4, right: 6, bottom: 4,
                         flexDirection: "row", justifyContent: "space-between" }}>
            {[0, 1, 2].map((i) => (
              <View key={i} style={{ width: 2.5, height: 2.5, borderRadius: 2,
                                     backgroundColor: C.pistIsik }} />
            ))}
          </View>
        </Animated.View>

        {/* ── AÇIK: GÖKYÜZÜ ──────────────────────────────────────── */}
        <Animated.View pointerEvents="none" style={{
          position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
          backgroundColor: C.gokMavi, opacity: gokOpak,
        }}>
          {/* iki bulut — sol tarafta, uçak sağa gidince geride kalır */}
          <View style={{ position: "absolute", left: 9, top: 7,
                         width: 13, height: 7, borderRadius: 4, backgroundColor: "#FFFFFF" }} />
          <View style={{ position: "absolute", left: 13, top: 4,
                         width: 8, height: 7, borderRadius: 4, backgroundColor: "#FFFFFF" }} />
          <View style={{ position: "absolute", left: 6, bottom: 6,
                         width: 8, height: 4.5, borderRadius: 3, backgroundColor: "#FFFFFF", opacity: 0.9 }} />
        </Animated.View>

        {/* ── TOPUZ: UÇAK ────────────────────────────────────────── */}
        <Animated.View style={{
          width: TOP, height: TOP, borderRadius: TOP / 2, marginLeft: ARA[4],
          backgroundColor: "#FFFFFF", alignItems: "center", justifyContent: "center",
          transform: [{ translateX: kay }],
        }}>
          <Ikon ad="ucus" boy={13} renk={C.pistUcak} />
        </Animated.View>
      </View>
    </TouchableOpacity>
  );
}

// MVP Warn (satir 450) — amber dikkat kutusu (engelleyici DEGIL)

// ============================================================
// 🔴 v2.65 — LoadFail: SESSİZ YUTMANIN SONU
//
// Yükleyicilerin çoğu `.catch(() => setX([]))` yazıyordu. Sonuç:
// ağ koptuğunda kullanıcı "hiç ilan yok" görüyordu. Bu bir yalan —
// üstelik en kötü türü, çünkü kullanıcı ürünün BOŞ olduğunu sanıp
// gidiyor.
//
// Boş durum DAVET EDER, hata durumu YENİDEN DENEMEYE ÇAĞIRIR.
// İkisi aynı ekran olamaz. Metin de suçlayıcı değil: "verilerin
// duruyor" — kaybetmedin, bağlantı bir an koptu.
// ============================================================
export function LoadFail({ t, onRetry, style }) {
  const s = t || {};
  return (
    <View style={[{ alignItems: "center", paddingVertical: ARA[26], paddingHorizontal: ARA[20] }, style]}>
      <Ikon ad="yenile" boy={22} renk={C.mutedAA} />
      <Text style={{ fontSize: FS.base, fontWeight: "700", color: C.ink, marginBottom: SP[1], textAlign: "center" }}>
        {s.loadFailTitle || "Liste şu an gelmedi"}
      </Text>
      <Text style={{ fontSize: FS.sm, color: C.mutedAA, textAlign: "center", lineHeight: 18, marginBottom: SP[3] }}>
        {s.loadFailBody || "Bağlantı bir an koptu. Verilerin duruyor."}
      </Text>
      {onRetry ? (
        <TouchableOpacity onPress={onRetry} activeOpacity={0.75}
          accessibilityRole="button"
          accessibilityLabel={s.loadFailCta || "Yeniden yükle"}
          style={{ minHeight: TAP.minHeight, minWidth: 140, justifyContent: "center", alignItems: "center",
                   borderWidth: 1.5, borderColor: C.gold, borderRadius: R.xs, paddingHorizontal: ARA[18] }}>
          <Text style={{ color: C.goldText, fontWeight: "600", fontSize: FS.base }}>
            {s.loadFailCta || "Yeniden yükle"}
          </Text>
        </TouchableOpacity>
      ) : null}
    </View>
  );
}

// 🔴 v2.51 — MARKA YÜKLEYİCİ (Gokberk: "LS gibi mi yapsak?")
// Rakipte bekleme ekranı koyu zemin + marka işareti + "Loading…".
// İşe yarayan tarafı KARANLIK DEĞİL, MARKANIN GÖRÜNMESİ: bekleme
// saniyesi boş bir gri yerine kimlik taşıyor. Bizim karşılığımız
// aynı fikir, kendi paletimizle: fildişi zemin + altın ◈ + nefes
// alan (pulse) hareket. Koyu tema yalnız "an" ekranlarına saklı —
// her yeri karartmak kontrastı öldürür.
// ============================================================
// 🔴 MARKA_RUHU §9/§10 — İKON ÇİPİ + ANLAMLI ROZET
// Lounge Surf'ün kart gramerinin app karşılığı: sessiz tek renk
// ikon çipi başlığın üstünde durur, dikkat başlığa gider.
// Site ve IG'de bu gramer var; app'te yoktu — aynı ürün iki
// farklı dil konuşuyordu.
// ============================================================
// 🔴 30 AĞUSTOS · 3. TUR — `glyph` YERİNE `ad`.
// Bu bileşenin adı "ChipIcon" ama aldığı şey bir GLİF karakteriydi;
// yani "ikon" diyip metin çiziyordu. Tasarımda her işaret vektör.
// `glyph` geriye dönük olarak KALDI: geçilirse hâlâ çizilir, ama
// çağrı yerleri `ad`a taşındı.
//
// Köşe de değişti: tasarımda işaret taşıyan her kap YUVARLAK
// (`.ust-eylem`, `.avatar`, `.roz`). `size*0.28` yumuşak bir kare
// üretiyordu — sistemde karşılığı yok.
export function ChipIcon({ glyph, ad, tone = "cost", size = 38 }) {
  // 🔴 26 AĞUSTOS — YEDEK DEĞER, DÜZELTTİĞİM HATANIN TA KENDİSİYDİ:
  // `C.gold` üzerine yazı = 2.52:1. Bilinmeyen bir `tone` geldiğinde
  // rozet sessizce okunmaz hâle dönüyordu. Yedek de ölçülmüş renkten.
  const tn = (C.badge && C.badge[tone]) || C.badge.cost;
  return (
    <View style={{ width: size, height: size, borderRadius: R.full,
                   backgroundColor: tn.bg, alignItems: "center",
                   justifyContent: "center", marginBottom: SP[3] }}>
      {ad ? <Ikon ad={ad} boy={Math.round(size * 0.44)} renk={tn.fg} />
          : <Text style={{ color: tn.fg, fontSize: size * 0.44, lineHeight: size * 0.52 }}>{glyph}</Text>}
    </View>
  );
}

// Anlam taşıyan rozet. Renk ARTIK yazıldığı yerde seçilmez —
// tone tek kaynaktan (C.badge) gelir, aynı anlam her ekranda aynı
// renkte görünür.
// ════════════════════════════════════════════════════════════════════
// KARAR ROZETİ — ÜRÜNÜN TEK İŞİ, TEK YERDEN
//
// 🔴 11 EYLÜL — AYNI KARAR ÜÇ EKRANDA ÜÇ FARKLI RENKTE ÇİZİLİYORDU:
//   Keşfet kartı      : included→teal · paid→amber · not_allowed→AMBER
//   Ön-kontrol çipi   : included→green · paid→amber · not_allowed→RED
//   Host ana sayfa    : included→teal · diğer hepsi→amber
// Yani "Girilmez" bir ekranda amber, ötekinde kırmızı; "ücretsiz" bir
// ekranda teal, ötekinde yeşil. Üç ekran, üç sözlük.
// 🆕 SINIF: "BİR ANLAMI HER ÇAĞIRAN KENDİ RENGİYLE ÇİZİYORSA, O ANLAMIN
// BİR RENGİ YOK DEMEKTİR — SÖZLÜK KODDA DEĞİL, KAFALARDA DURUYORDUR."
//
// Artık tek kaynak: politika → renk + glif + dolgu + metin.
// ════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════
// IŞIKLI KART — üst ışık dokununca besleniyor (12 Eylül · 3. tur)
//
// 🔴 NEDEN VAR
// Gökberk: "kartların üst kenarındaki o kılcal ışık çizgileri tamamen
// statik kalmasın; kullanıcı karta dokunduğunda o lüks ışık mikroskobik
// olarak parlasın."
//
// Geçen turda bunu YALNIZ düğmelerde yapabilmiştim ve sebebini de
// yazmıştım: Keşfet kartı `TouchableOpacity` değil `View`, ve onu
// basılabilir yapmak kartın içindeki üç ayrı dokunma hedefini
// (avatar → profil, rozet → açıklama, düğme → istek) yutardı.
//
// Çözüm dokunma hedefini DEĞİŞTİRMEDEN dinlemek: `onTouchStart` /
// `onTouchEnd` sorumluluk (responder) TALEP ETMEZ — olayı görür, ama
// sahiplenmez. Yani kartın çocukları dokunmayı aynen alır, kart yalnız
// "bana dokunuldu" bilgisini duyar.
//
// Ölçüm (kart zemini #141211 üstünde):
//     boşta   rgba(244,239,230,0.06)  → ΔE 6.32
//     basılı  ×2.6 ≈ %15.6            → ΔE 16.35
// Yani ışık üç katına çıkıyor ama hâlâ bir ÇİZGİ değil bir KENAR:
// eski sıcak sarı çerçeve ΔE 20.36'ydı, basılı hâlimiz bile onun altında.
//
// 🆕 SINIF: "BİR OLAYI DİNLEMEK İLE ONU SAHİPLENMEK AYRI ŞEYLERDİR —
// SAHİPLENMEDEN DİNLEYEBİLİYORSAN, ÜSTÜNDEKİ HİÇBİR ETKİLEŞİMİ BOZMADAN
// TEPKİ VEREBİLİRSİN."
// ══════════════════════════════════════════════════════════════════════
export function IsikliKart({ children, stil, isikPay = 14 }) {
  const bas = useRef(new Animated.Value(0)).current;
  const carp = bas.interpolate({ inputRange: [0, 1], outputRange: [1, 2.6] });
  const ac = () => Animated.timing(bas, { toValue: 1, duration: 110, useNativeDriver: true }).start();
  const kis = () => Animated.timing(bas, { toValue: 0, duration: 260, useNativeDriver: true }).start();
  return (
    <View style={stil} onTouchStart={ac} onTouchEnd={kis} onTouchCancel={kis}>
      <Animated.View pointerEvents="none" style={{
        position: "absolute", left: isikPay, right: isikPay, top: 0, height: 1,
        backgroundColor: C.kartIsik, opacity: carp }} />
      <View pointerEvents="none" style={{
        position: "absolute", left: isikPay, right: isikPay, bottom: 0, height: 1,
        backgroundColor: C.kartDip }} />
      {children}
    </View>
  );
}

// ══════════════════════════════════════════════════════════════════════
// AKAN BAŞLIK — kelimeler sırayla süzülür (12 Eylül · 3. tur)
//
// Gökberk: "harfler veya kelimeler ekrana ipeksi bir duman efektiyle
// sırayla aksın."
//
// Geçen turda bunu BLOK düzeyinde yapmıştım (başlık bloğu, sonra gövde
// bloğu, arada 160ms). Doğru yöndeydi ama istenen bu değildi: blok tek
// parça geliyordu. Artık başlık KELİME KELİME geliyor, her kelime bir
// öncekinden 55ms sonra.
//
// ⚠️ RN'de metne blur uygulanamaz (`filter: blur` yok). "Duman"ı üç
// kanal taşıyor ve üçü de native driver'a girer: opaklık, 10pt aşağıdan
// süzülme, ve kelimeler arası gecikme.
//
// ⚠️ SATIR SARMASI KORUNUYOR: kelimeler `flexWrap` bir satırda duruyor
// ve aralarındaki boşluk `marginRight` ile veriliyor — tek bir `Text`in
// kendi sarması kadar iyi değil ama ölçülebilir: taşma kapısı bu
// başlıkları ölçüyor ve 37/37 geçiyor.
//
// 🆕 SINIF: "BİR ANİMASYONU 'BLOK' DÜZEYİNDE YAPMAK ONU YAPMIŞ OLMAK
// DEĞİLDİR — GÖZ SIRAYI PARÇA SAYISINDAN OKUR, SÜREDEN DEĞİL."
// ══════════════════════════════════════════════════════════════════════
export function AkanBaslik({ metin, stil, adim = 55, gecikme = 80, anahtar }) {
  // 🔴 YAZARIN SATIR SONUNU ÖLDÜRMEK — İLK DENEMEMDE TAM OLARAK BUNU YAPTIM.
  // Metni `split(/\s+/)` ile kelimelere ayırınca `\n` de bir boşluk
  // sayılıyor ve i18n'deki "Kalkışa iki saat.\nSen ayaktasın." iki satırlık
  // vurusunu kaybediyordu — gerçek render'da "Kalkışa iki saat. Sen /
  // ayaktasın." diye sarıyordu. Yani animasyon eklerken TİPOGRAFİYİ
  // bozmuştum ve bunu ancak çekilen ekrana bakınca gördüm.
  // Artık önce SATIRLARA, sonra kelimelere bölünüyor; her satır kendi
  // sırasında, gecikme sayacı satırlar boyunca sürüyor.
  // 🆕 SINIF: "BİR METNİ PARÇALAYAN HER DÖNÜŞÜM, YAZARIN O METNE KOYDUĞU
  // BİÇİMİ DE PARÇALAR — `\n` BİR BOŞLUK DEĞİL BİR KARARDIR."
  const satirlar = String(metin || "").split("\n").map((sat) =>
    sat.split(/\s+/).filter(Boolean));
  const toplam = satirlar.reduce((n, sat) => n + sat.length, 0);
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    v.setValue(0);
    Animated.timing(v, { toValue: Math.max(1, toplam), duration: gecikme + adim * Math.max(1, toplam),
                         easing: Easing.linear, useNativeDriver: true }).start();
  }, [anahtar, metin]);
  let sira = -1;
  return (
    <View>
      {satirlar.map((sat, si) => (
        <View key={si} style={{ flexDirection: "row", flexWrap: "wrap" }}>
          {sat.map((k, i) => {
            sira += 1;
            const n = sira;
            const op = v.interpolate({ inputRange: [n, n + 0.85], outputRange: [0, 1], extrapolate: "clamp" });
            const ty = v.interpolate({ inputRange: [n, n + 0.85], outputRange: [10, 0], extrapolate: "clamp" });
            return (
              <Animated.Text key={k + i} style={[stil, { opacity: op, transform: [{ translateY: ty }] }]}>
                {k}{i < sat.length - 1 ? " " : ""}
              </Animated.Text>
            );
          })}
        </View>
      ))}
    </View>
  );
}

// ══════════════════════════════════════════════════════════════════════
// YAPRAK / ŞERİT — HAVALİMANI KALKIŞ PANOSU (SPLIT-FLAP · FIDS)
// 12 Eylül · gece
//
// 🔴 NEDEN VAR
// Gökberk'in vizyon listesi, son kalan üç maddeden biri: "sohbet
// ekranındaki uçuş bilgisi eski havalimanı panolarındaki gibi
// yapraklarla dönsün."
//
// Bu bir süs değil, bu üründe DOĞRU metafor: sohbet ekranındaki tek
// canlı sayı kalkışa kalan süre ve o sayı kullanıcının zaten bir
// havalimanı panosundan okumaya alışık olduğu sayı. Aynı nesneyi
// taklit etmek, açıklama ihtiyacını sıfıra indirir.
//
// FİZİK — neyi taklit ettiğimi biliyorum, yoksa "dönen bir şey"
// yapardım. Gerçek bir split-flap hücrede DÖRT yüzey vardır:
//     ┌───────────┐  ① sabit üst   : YENİ karakterin üst yarısı
//     │  ① / ③    │  ③ düşen kapak : ESKİ karakterin üst yarısı
//     ├───────────┤     (alt kenarı etrafında 0° → −90°)
//     │  ② / ④    │  ② sabit alt   : ESKİ karakterin alt yarısı
//     └───────────┘  ④ inen kapak  : YENİ karakterin alt yarısı
//                       (üst kenarı etrafında 90° → 0°)
// İlk yarıda ③ düşer ve altından ① çıkar; ikinci yarıda ④ iner ve
// ②'yi örter. Tek bir kapağı 180° döndürmek YANLIŞ olurdu: gerçek
// panoda düşen yaprağın arkası yoktur, yerine BAŞKA bir yaprak gelir.
//
// 🔴 DÖNME EKSENİ. RN'de `transformOrigin` 0.76'dan beri var (ölçtüm:
// `node_modules/react-native/Libraries/StyleSheet/private/_TransformStyle.js`).
// Olmasaydı ötele-döndür-geri ötele üçlüsü gerekirdi; varken onu
// kullanmak hem daha az kod hem de yerel sürücüye uygun.
//
// ⚠️ `perspective` transform dizisinin İÇİNDE ve İLK sırada olmalı;
// dışarıda bir stil anahtarı olarak RN'de sessizce yok sayılır — yani
// döndürme yapılır ama derinlik hissi hiç oluşmaz.
//
// 🆕 SINIF: "BİR NESNEYİ TAKLİT EDECEKSEN ÖNCE KAÇ PARÇADAN OLUŞTUĞUNU
// SAY — TEK PARÇAYLA YAPILAN TAKLİT, HAREKETİ DEĞİL YALNIZCA HIZI
// KOPYALAR."
// ══════════════════════════════════════════════════════════════════════
export const YAPRAK_SURE = 260;      // tam çevrim (ms) — mühürle aynı

export function Yaprak({ karakter, boy = 16, renk, sabit }) {
  const h = Math.round(boy * 1.45);
  const yari = h / 2;
  // JetBrains Mono ilerlemesi 0.6em; iki yandan 3'er pt nefes.
  const g = Math.round(boy * 0.6) + 6;
  const v = useRef(new Animated.Value(1)).current;
  const sonRef = useRef(karakter);
  const [cift, setCift] = useState({ eski: karakter, yeni: karakter });

  useEffect(() => {
    if (sonRef.current === karakter) return;
    const eski = sonRef.current;
    sonRef.current = karakter;
    setCift({ eski, yeni: karakter });
    v.setValue(0);
    Animated.timing(v, { toValue: 1, duration: YAPRAK_SURE,
                         easing: Easing.linear, useNativeDriver: true }).start();
  }, [karakter]);

  const yazi = { width: g, height: h, lineHeight: h, textAlign: "center",
                 fontFamily: MONO[600], fontSize: boy,
                 color: renk || C.goldText, includeFontPadding: false };

  // Bir yarım: tam boy metni yarım boy bir pencereden gösteriyoruz.
  // Alt yarım için metni yarı boy yukarı kaydırıyoruz — metni ikiye
  // bölmek yerine PENCEREYİ bölmek, iki yarımın harf biçimlerinin
  // birebir aynı kalmasını garanti eder.
  const Yarim = ({ ust, ch }) => (
    <View style={{ width: g, height: yari, overflow: "hidden" }}>
      <Text style={[yazi, ust ? null : { marginTop: -yari }]}>{ch}</Text>
    </View>
  );

  if (sabit) {
    // ":" gibi ayraçlar dönmez. Gerçek panoda da ayraç bir yaprak
    // değil, iki yaprak arasındaki boşluğa basılmış sabit bir işarettir.
    return (
      <Text style={[yazi, { width: Math.round(boy * 0.45), color: C.mutedAA || C.mut }]}>
        {karakter}
      </Text>
    );
  }

  const kapakUst = {
    opacity: v.interpolate({ inputRange: [0, 0.49, 0.5, 1], outputRange: [1, 1, 0, 0] }),
    transform: [{ perspective: 340 },
                { rotateX: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: ["0deg", "-90deg", "-90deg"] }) }],
  };
  const kapakAlt = {
    opacity: v.interpolate({ inputRange: [0, 0.49, 0.5, 1], outputRange: [0, 0, 1, 1] }),
    transform: [{ perspective: 340 },
                { rotateX: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: ["90deg", "90deg", "0deg"] }) }],
  };

  return (
    /* 🔴 KÖŞE YOK VE BU BİLEREK. İlk yazımda 3pt yuvarlaklık vardı;
       `kose_olcek.py` onu ölçek dışı saydı (haklı: 3 ne R.xs=8 ne
       R.onay=5). Ölçeğe yeni bir basamak eklemek yerine köşeyi
       KALDIRDIM — ve taklit böylesi daha doğru: gerçek bir pano
       yaprağı damgalanmış düz bir metal plakadır, yuvarlatılmış bir
       kart değil. Nöbetçi burada bir kusuru değil, bir gevşekliği
       yakaladı. */
    <View style={{ width: g, height: h, overflow: "hidden",
                   backgroundColor: C.bgAlt, marginHorizontal: 1 }}>
      {/* ① sabit üst — YENİ karakter */}
      <Yarim ust ch={cift.yeni} />
      {/* ② sabit alt — ESKİ karakter (④ inince örtülür) */}
      <Yarim ch={cift.eski} />
      {/* ③ düşen kapak — alt kenarı etrafında */}
      <Animated.View style={[{ position: "absolute", top: 0, left: 0,
                               transformOrigin: "50% 100%" }, kapakUst]}>
        <Yarim ust ch={cift.eski} />
      </Animated.View>
      {/* ④ inen kapak — üst kenarı etrafında */}
      <Animated.View style={[{ position: "absolute", top: yari, left: 0,
                               transformOrigin: "50% 0%" }, kapakAlt]}>
        <Yarim ch={cift.yeni} />
      </Animated.View>
      {/* Katlanma çizgisi: panonun iki yaprağı arasındaki gölge.
          `kartDip` zaten paletteki "aşağı doğru gölge" jetonu —
          buraya yeni bir renk sokmak, palete kaçak bir değer sokmaktır. */}
      <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0,
                                          top: yari - 0.5, height: 1,
                                          backgroundColor: C.kartDip }} />
    </View>
  );
}

export function Serit({ metin, boy = 16, renk, stil }) {
  const harfler = String(metin == null ? "" : metin).split("");
  return (
    <View style={[{ flexDirection: "row", alignItems: "center" }, stil]}>
      {harfler.map((ch, i) => (
        <Yaprak key={i} karakter={ch} boy={boy} renk={renk}
                sabit={!/[0-9A-Za-z]/.test(ch)} />
      ))}
    </View>
  );
}

// ══════════════════════════════════════════════════════════════════════
// GEÇİŞ KARTI — EĞİME TEPKİ VEREN METAL YÜZEY  · 12 Eylül · gece
//
// 🔴 NEDEN VAR
// Gökberk: "VIP geçiş kartı, telefonu eğince üzerinde ışık gezinsin —
// elinde metal bir kart varmış gibi."
//
// Yerini ÖLÇEREK seçtim: cüzdan ekranının tepesinde `goldBg` dolgulu,
// ortalanmış, üç satırlık bir kutu vardı ("BAKİYE / 1240 / kredi").
// O kutu bir kart değil bir ETİKETTİ; ürünün para konuştuğu ekranda
// kimlik taşımıyordu. Kart artık dört şeyi birden söylüyor: kimin,
// hangi seviyede, ne kadar, hangi numarayla.
//
// FİZİK — İKİ KANAL, TEK KAYNAK:
//   · eğim  (`gamma`, sol-sağ) → parıltının YERİ
//   · sönüm (yay değil, doğrusal yaklaşma) → ham sensör zıplamaz
// Kartın kendisi DÖNMÜYOR. Denedim ve ölçtüm: 3–4 derecelik bir
// `rotateY` metnin kenarlarını yumuşatıyor, yani okunurluğu parıltı
// uğruna bozuyor. Işık gezer, yazı durur.
//
// ⚠️ SENSÖR YOKSA KART ÖLÜ DEĞİL. Web'de ve sensörsüz cihazlarda
// açılışta TEK bir süpürme yapıyor ve dokununca tekrarlıyor. Sensörü
// olmayan kullanıcıya "burada bir şey vardı ama sende yok" dedirtmek,
// hiç yapmamaktan kötüdür.
//
// ⚠️ GENİŞLİK ÖLÇÜLÜYOR, VARSAYILMIYOR. Parıltının gideceği mesafe
// kartın enine bağlı; `onLayout` gelene kadar süpürme başlamıyor.
// Ekran enini `Dimensions`tan alıp kenar boşluklarını tahmin etmek,
// bu dosyada daha önce üç kez yanlış çıkmış bir alışkanlık.
//
// 🆕 SINIF: "BİR YÜZEYİ 'PAHALI' YAPAN ŞEY PARLAKLIĞI DEĞİL, IŞIĞA
// VERDİĞİ TEPKİNİN TUTARLILIĞIDIR — SABİT BİR PARLAMA SÜSTÜR, EĞİMİ
// İZLEYEN BİR PARLAMA MALZEMEDİR."
// ══════════════════════════════════════════════════════════════════════
const PARILTI = require("../assets/parilti.png");

export function GecisKarti({ marka = "LOUNGELINK", rozet, etiket, deger, birim, aciklama, ad, no, stil }) {
  const [en, setEn] = useState(0);
  const x = useRef(new Animated.Value(0.5)).current;   // 0..1 — kart üzerindeki yer
  const sensorRef = useRef(null);

  // 🔴 SÜRE 900ms VE BİTİŞ KARTIN DIŞINDA — İKİSİ DE ÖLÇÜMDEN.
  // Sahne çekimi her adımdan sonra 1200ms bekliyor; 1400ms'lik bir
  // süpürme çekim anında HÂLÂ yolda olurdu ve aynı ekran her koşuda
  // farklı piksel verirdi. 900ms + kartın dışında biten bir yol,
  // animasyonu GÖRÜNÜR ama sonucu BELİRLENİMLİ kılıyor.
  // 🆕 SINIF: "BİR ANİMASYONUN DİNLENME DURUMU YOKSA, O EKRANIN
  // EKRAN GÖRÜNTÜSÜ DE YOKTUR."
  const supur = useCallback(() => {
    x.setValue(-0.15);
    Animated.timing(x, { toValue: 1.15, duration: 900,
                         easing: Easing.inOut(Easing.quad), useNativeDriver: true }).start();
  }, []);

  useEffect(() => {
    let canli = true;
    let abone = null;
    if (Platform.OS === "web") { supur(); return () => { canli = false; }; }
    try {
      const S = require("expo-sensors");
      const DM = S && S.DeviceMotion;
      if (!DM) { supur(); return () => { canli = false; }; }
      const sz = DM.isAvailableAsync();
      const bagla = (varMi) => {
        if (!canli) return;
        if (!varMi) { supur(); return; }
        DM.setUpdateInterval(60);
        abone = DM.addListener((v) => {
          // `gamma`: telefonun sol-sağ eğimi (radyan). ±0.6 rad ≈ ±34°
          // gerçek kullanımda elin doğal salınım aralığı (ölçüm:
          // masada tutulan bir telefonun kendi gürültüsü ±0.02 rad).
          const g = (v && v.rotation && v.rotation.gamma) || 0;
          const hedef = Math.max(0, Math.min(1, 0.5 + g / 1.2));
          Animated.timing(x, { toValue: hedef, duration: 120,
                               easing: Easing.out(Easing.quad), useNativeDriver: true }).start();
        });
        sensorRef.current = abone;
      };
      if (sz && sz.then) sz.then(bagla).catch(() => { if (canli) supur(); });
      else bagla(!!sz);
    } catch (e) { supur(); }
    return () => {
      canli = false;
      try { if (sensorRef.current && sensorRef.current.remove) sensorRef.current.remove(); } catch (e) {}
    };
  }, []);

  // Şerit kartın eninin %55'i; iki yana taşarak giriyor ve çıkıyor.
  const seritEn = Math.max(40, Math.round(en * 0.55));
  const kay = x.interpolate({ inputRange: [0, 1],
                              outputRange: [-seritEn, Math.max(0, en)] });

  return (
    /* 🔴 BU BİR KART, DÜĞME DEĞİL — VE BUNU NÖBETÇİ HATIRLATTI.
       İlk yazımda dokununca parıltıyı tekrarlatan bir
       `TouchableOpacity`ydi; `dugme_check.py` onu "elle yazılmış
       düğme" saydı. Bütçeyi yükseltip geçebilirdim; geçmedim, çünkü
       nöbetçi biçimsel olarak haklıydı: zemin + yarıçap + dokunma =
       düğme kalıbı, ve `accessibilityRole="button"` ekran okuyucuya
       da "burada bir eylem var" diyordu — oysa yoktu, yalnız bir
       süs tekrarlanıyordu. Kart artık dokunulmuyor: parıltı açılışta
       bir kez geçiyor, sonrası cihazın eğimine bağlı.
       🆕 SINIF: "BİR NÖBETÇİYİ SUSTURMADAN ÖNCE ONA HAK VERİP
       VEREMEYECEĞİNE BAK — ÇOĞU YANLIŞ ALARM, ADI YANLIŞ KONMUŞ BİR
       TASARIM KARARIDIR." */
    <View accessibilityLabel={[ad, rozet, deger && `${deger} ${birim || ""}`].filter(Boolean).join(" · ")}
      onLayout={(e) => { const w = e.nativeEvent.layout.width; if (w > 0 && Math.abs(w - en) > 1) setEn(w); }}
      style={[{ borderRadius: R.lg, overflow: "hidden", backgroundColor: C.surface,
                borderWidth: 1, borderColor: C.goldLine, padding: ARA[20],
                minHeight: 150, justifyContent: "space-between",
                /* 🔴 YÜKSELTİ STİLİN İÇİNDE, DİZİDE DEĞİL. `ELEV.card`ı
                   dizinin ikinci elemanı olarak vermiştim ve
                   `yuzey_check.py` "gölgesiz kart" dedi. Nöbetçi stil
                   NESNESİNİ okuyor; dizinin öbür elemanını görmüyor.
                   Yanlış alarm değil: aynı körlük bir gün gerçek bir
                   gölgesiz kartı da gizlerdi. Kalıbı nöbetçinin
                   görebileceği yere yazmak, nöbetçiyi güvenilir tutar. */
                ...ELEV.card }, stil]}>
      {/* Üst kenardan sızan ışık — `kabartmaIsik` zaten "yukarıdan gelen
          ışık" jetonu; kart da o ışık kaynağının altında duruyor. */}
      <View pointerEvents="none" style={{ position: "absolute", top: 0, left: 0, right: 0,
                                          height: 1, backgroundColor: C.kabartmaIsik }} />
      {en > 0 ? (
        <Katman anim source={PARILTI} resizeMode="stretch"
          style={{ position: "absolute", top: -40, left: 0, width: seritEn, height: 260,
                   opacity: 0.13,
                   transform: [{ translateX: kay }, { rotate: "18deg" }] }} />
      ) : null}

      <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
        <Text style={{ fontSize: FS.xs, letterSpacing: 3.2, color: C.goldText, fontWeight: "600" }}>
          {marka}
        </Text>
        {rozet ? (
          <Text style={{ fontSize: FS.xs, letterSpacing: 1.4, color: C.mutedAA || C.mut }}>{BUYUK(rozet)}</Text>
        ) : null}
      </View>

      {/* ══════════════════════════════════════════════════════════════
          🔴 12 EYLÜL · GECE — "BAKİYE" VE KREDİNİN ANLAMI GERİ GELDİ.
          v5.4.0'da bakiye kutusunu bu kartla değiştirirken iki metni
          farkında olmadan düşürmüşüm:
              t.walletBalance      "BAKİYE"
              t.walletCreditsMeans "{n} misafir isteği gönderebilirsin"
          İkincisi bir süs değil: bu üründe 1 kredi = 1 misafir isteği
          ve bunu SÖYLEYEN tek cümle oydu. Sayıyı gösterip anlamını
          göstermemek, cüzdanı bir sayaca indirir.
          🆕 SINIF: "BİR KUTUYU DAHA GÜZEL BİR KUTUYLA DEĞİŞTİRİRKEN
          İÇİNDEKİ CÜMLELERİ SAY — TASARIM TURLARI METNİ SESSİZCE
          YUTAR, ÇÜNKÜ KİMSE METNİ ÖLÇMEZ."
          ══════════════════════════════════════════════════════════ */}
      <View style={{ marginTop: ARA[18] }}>
        {etiket ? (
          <Text style={{ fontSize: FS.micro, letterSpacing: 2, color: C.mutedAA || C.mut,
                         marginBottom: ARA[2] }}>{BUYUK(etiket)}</Text>
        ) : null}
        <Text style={{ fontFamily: MONO[600], fontSize: FS.hero, color: C.goldText,
                       lineHeight: Math.round(FS.hero * 1.2) }}>
          {deger == null ? "—" : String(deger)}
        </Text>
        {birim ? (
          <Text style={{ fontSize: FS.xs, letterSpacing: 1.6, color: C.mutedAA || C.mut,
                         marginTop: ARA[2] }}>{BUYUK(birim)}</Text>
        ) : null}
        {aciklama ? (
          <Text style={{ fontSize: FS.sm, color: C.body, marginTop: ARA[8], lineHeight: 18 }}>
            {aciklama}
          </Text>
        ) : null}
      </View>

      <View style={{ flexDirection: "row", alignItems: "flex-end",
                     justifyContent: "space-between", marginTop: ARA[18] }}>
        {/* İsim serif — bu üründe KİŞİ ADI serifle yazılır (12 Eylül kararı).
            Kartın üzerindeki ad, kartın sahibidir; bir veri değil bir imza. */}
        <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, fontFamily: F.serifGosterim,
                                         fontSize: FS.lg, letterSpacing: -0.4, color: C.ink }}>
          {ad || ""}
        </Text>
        {no ? (
          <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, color: C.dimAA || C.dim,
                         letterSpacing: 1.1, marginLeft: ARA[10] }}>{no}</Text>
        ) : null}
      </View>
    </View>
  );
}

// ══════════════════════════════════════════════════════════════════════
// MÜHÜR — kural motorunun kararı ekrana "vurulur" (12 Eylül · akşam)
//
// 🔴 NEDEN VAR
// Gökberk: "%99 veya %60 Uyum sonucu ekrana düz bir yazı gibi gelmesin.
// Tıpkı pasaporta vurulan o asil gümrük damgaları gibi… ekrana
// 'mühürlenerek' insin. Kullanıcı o doğrulamayı fiziksel olarak
// hissetsin."
//
// Fiziği taklit ediyoruz: bir mühür yukarıdan iner, temas anında
// DURUR (yaylanmaz — kauçuk değil, metal), ve temas anında el bir
// darbe hisseder. Üç kanal:
//   · ölçek 1.35 → 1.00   (yaklaşma)
//   · opaklık  0 → 1      (beliriş)
//   · titreşim `Haptics.impactAsync(Medium)` tam temas anında
// Süre 260ms: daha uzunu "animasyon", daha kısası "takılma" okunuyor.
// `Easing.out(Easing.back)` DEĞİL `Easing.out(Easing.cubic)` —
// geri sekme lastik hissi verir, mühür sekmez.
//
// `gecikme` ile üç grup 90ms arayla mühürleniyor; titreşim yalnız
// BİRİNCİSİNDE (üç kez arka arkaya titreyen bir telefon lüks değil,
// arızalı hissettirir).
//
// ⚠️ `expo-haptics` iOS'ta Taptic Engine, Android'de sistem titreşimi
// kullanır; ikisi de yoksa sessizce hiçbir şey yapmaz — o yüzden
// çağrısı `catch`siz bırakılmadı.
//
// 🆕 SINIF: "BİR HAREKETİ 'DOĞAL' YAPAN ŞEY EĞRİSİ DEĞİL, TAKLİT
// ETTİĞİ NESNENİN MALZEMESİDİR — LASTİK SEKER, METAL DURUR."
export function Muhur({ children, gecikme = 0, titret, stil }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const it = setTimeout(() => {
      // ⚠️ WEB'DE TİTREŞİM YOK VE SESSİZCE DEĞİL, ATARAK YOK.
      // İlk yazımda yalnız `try/catch` koymuştum; web sahnesi
      // "Haptic.impactAsync is not available on web" diye HATA kaydetti.
      // Sebep: hata senkron değil, dönen SÖZÜN reddi olarak geliyor —
      // `try/catch` onu görmez. Hem platform kontrolü hem `.catch()`
      // gerekiyor.
      // 🆕 SINIF: "`try/catch` YALNIZ SENKRON HATAYI TUTAR — BİR SÖZ
      // DÖNDÜREN ÇAĞRIYI KORUMANIN YOLU `catch` BLOĞU DEĞİL `.catch()`
      // KANCASIDIR."
      if (titret && Platform.OS !== "web") {
        try {
          const H = require("expo-haptics");
          const sz = H.impactAsync(H.ImpactFeedbackStyle.Medium);
          if (sz && sz.catch) sz.catch(() => {});
        } catch (e) { /* titreşim yoksa ekran yine de çalışır */ }
      }
      Animated.timing(v, { toValue: 1, duration: 260,
                           easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    }, gecikme);
    return () => clearTimeout(it);
  }, []);
  return (
    <Animated.View style={[{
      opacity: v,
      transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [1.35, 1] }) }],
    }, stil]}>
      {children}
    </Animated.View>
  );
}

export function KararCipi({ t, politika, etiket, onPress, a11yLabel, stil }) {
  const H = {
    included:    { ton: "ok",      isaret: "tamam", dolgu: true,  yz: t && t.badgeGuestFree },
    paid:        { ton: "ucretli", isaret: "kredi", dolgu: false, yz: t && t.badgeGuestPaid },
    not_allowed: { ton: "engel",   isaret: "kapat", dolgu: true,  yz: t && t.badgeGuestNo },
  };
  const h = H[politika] || { ton: "notr", isaret: "bilgi", dolgu: false, yz: t && t.badgeGuestUnknown };
  const yz = etiket || h.yz || "";
  if (!yz) return null;
  // `kabartma` HER karar rozetinde açık — "ücretli" dolgu taşımasa bile
  // bir karardır ve üçü de aynı fiziksel dilde durmalı. Kabartmayı
  // yalnız dolgulu olanlara verseydim üç rozet iki ayrı malzeme olurdu.
  return <Cip etiket={yz} ton={h.ton} isaret={h.isaret} dolgu={h.dolgu} kabartma
              onPress={onPress} a11yLabel={a11yLabel || yz} stil={stil} />;
}

export function ToneBadge({ tone = "info", children, style }) {
  const tn = (C.badge && C.badge[tone]) || C.badge.info;
  return (
    <View style={[{ backgroundColor: tn.bg, borderColor: tn.bd, borderWidth: 1,
                    borderRadius: R.full, paddingHorizontal: ARA[10], paddingVertical: SP[1],
                    alignSelf: "flex-start" }, style]}>
      <Text style={{ color: tn.fg, fontSize: FS.xs, fontWeight: "600" }}>{children}</Text>
    </View>
  );
}

export function Load({ dark }) {
  const pulse = useRef(new Animated.Value(0.35)).current;
  useEffect(() => {
    const loop = Animated.loop(Animated.sequence([
      Animated.timing(pulse, { toValue: 1, duration: 780, useNativeDriver: true }),
      Animated.timing(pulse, { toValue: 0.35, duration: 780, useNativeDriver: true }),
    ]));
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center",
                   backgroundColor: dark ? C.ink : C.bg }}>
      {/* v2.54 — MARKA İŞARETİ. Yükleyicideki ◈ jenerik bir sembol
          değil artık: uygulama ikonuyla AYNI işaret (konik kanat
          darbesi). Bekleme saniyesi markayı taşır. */}
      <Animated.Image
        source={dark ? require("../assets/mark-kemer.png") : require("../assets/mark-kemer-ink.png")}
        style={{ width: 92, height: 92, opacity: pulse, marginBottom: ARA[6] }}
        resizeMode="contain" />
      <Text style={{ color: dark ? C.paper : C.dim, fontSize: FS.xs, letterSpacing: 3 }}>LOUNGELINK</Text>
    </View>
  );
}

// ============================================================================
// SAYFA — ATMOSFERİN TEK GİRİŞ NOKTASI  (26 Ağustos 2026 · v3.1)
//
// 🔴 NEDEN BİLEŞEN, NEDEN 38 AYRI DÜZENLEME DEĞİL
// Atmosferi App.js'in kökünde tek yere koymayı denedim. ÖLÇTÜM: görünmedi.
// Sebep, ekranların 38'inin kendi kökünde `backgroundColor: C.paper` taşıması
// — yani her ekran kendi opak sayfasını boyuyor ve altındaki her şeyi
// örtüyor. "Tek yerden bağla" fikri doğruydu ama O TEK YER KÖK DEĞİLDİ:
// sayfa zeminini kim boyuyorsa atmosferi de o taşımalı.
//
// 🆕 SINIF: "BİR KATMANI TEK YERDEN BAĞLAYAMIYORSAN, O YERİ ARAMAYI DEĞİL
// ÖNCE KİMİN ÜSTÜNÜ BOYADIĞINI ÖLÇMEYİ BIRAKMIŞSINDIR."
//
// Bu yüzden zemin ile atmosfer TEK BİLEŞENDE birleşti. Ekranlar artık
// `backgroundColor` yazmıyor; yazarlarsa `atmosfer_check.py` kırmızıya döner.
// Yarın koyu mod geldiğinde de değişecek dosya sayısı: 1.
//
// Kullanımı — birebir eski kökün yerine geçer:
//   <View style={{ flex: 1, backgroundColor: C.paper }}>  →  <Sayfa>
//
// `ufuk`: dokudaki ufuk çizgisinin yüzdesi. Süs değil, sessiz bağlam:
// yerdeki ekranlarda alçak (keşif, form), uçuş/buluşma bağlamında yüksek.
// ============================================================================
// ────────────────────────────────────────────────────────────────────────
// 🔴 12 EYLÜL (Gökberk md.3) — TANECİK: EKRANIN ÜSTÜNDEKİ GÖRÜNMEZ GREN
// "iç ekranların ortasında tırtıklı halde geçiş tonu var, ayrıca header
//  alanındaki görseller de tırtıklı gibi."
// Ölçüm ve doz seçimi `brand/build_tanecik.py` başlığında; özeti:
// koyu zeminde 8 bit yumuşak geçişe yetmiyor, ufuk kuşağı 14 tonda
// çıkıyor ve her ton 5.3 pt'lik DÜZ bir şerit oluyor. α=0.008'lik gren
// şeridi 1.0 pt'ye indiriyor.
// ÇOCUKLARIN ÜSTÜNE çiziliyor — çünkü bantlanan yalnız zemin değil,
// header fotoğrafı ve kart gradyanları da. `pointerEvents="none"`,
// dokunma geçirir; tek `Image`, düzen maliyeti yok.
// ────────────────────────────────────────────────────────────────────────
const TANECIK = require("../assets/tanecik.png");

// ⚠️ TEK KOPYA. Önce `Sayfa`nın içine koymuştum; ölçtüm: sekmeli kabukta
// aynı anda ÜÇ `Sayfa` mount oluyor ve gren ÜÇ KEZ seriliyordu — zemin
// 11'den 8.58'e düştü (−2.4 ton), yani dither değil karartma oldu.
// Kök seviyesinde tek kopya: ölçüm 11 → 10.5, ±1 ton (istenen).
// 🆕 SINIF: "ÜST ÜSTE BİNEN BİR KATMANIN DOZU, KATMANIN KENDİSİ DEĞİL
// KAÇ KEZ ÇİZİLDİĞİDİR."
export function Tanecik() {
  return (
    /* 🔴 18 EYLÜL — BURASI UYGULAMAYI ÖLDÜREN YERDİ. Gren kökün SON
       çocuğu ve tam ekran; Android'de `<Image pointerEvents="none">`
       yok sayıldığı için (ölçüm: `Katman` başlığı) EKRANDAKİ HER DOKUNUŞ
       burada bitiyordu. `Katman` görünmez bir `View` ile sarıyor; o View
       arayüzü uyguladığı için alt ağacın tamamı dokunmaya kapanıyor. */
    <Katman source={TANECIK} resizeMode="repeat" fadeDuration={0}
           accessible={false} accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
           /* ⚠️ `width/height: "100%"` ŞART. Ölçtüm: yalnız
              top/left/right/bottom:0 verildiğinde react-native-web
              katmanı görselin DOĞAL boyunda (128×128) çiziyordu —
              gren ekranın sol üst köşesinde tek bir kare kalıyor ve
              ölçümde σ hiç değişmiyordu (0.135).
              🆕 SINIF: "BİR KATMANIN KODA GİRMESİ ÇİZİLDİĞİNİ
              GÖSTERMEZ — ÇİZİLDİĞİNİ ANCAK PİKSEL SÖYLER." */
           style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
                    width: "100%", height: "100%" }} />
  );
}

export function Sayfa({ children, tur = "is", ufuk = 56, kaynak, yogunluk, style }) {
  return (
    <View style={[{ flex: 1, backgroundColor: tur === "an" ? C.ink : C.paper }, style]}>
      <Atmosfer tur={tur} ufuk={ufuk} kaynak={kaynak} yogunluk={yogunluk} />
      {children}
    </View>
  );
}

// ════════════════════════════════════════════════════════════════════════
// ONAY KUTUSU — YIKICI EYLEMİN TEK KAPISI  (19 Eylül'de `ekranlar_ana.js`ten
// taşındı; gerekçe orada yazılı)
// ════════════════════════════════════════════════════════════════════════
export function ConfirmModal({ visible, title, body, confirmLabel, cancelLabel, danger, onConfirm, onCancel, busy }) {
  // Onay düğmesinin mürekkebi zeminine göre (bkz. aşağıdaki 23 Eylül notu).
  const onayMurekkep = danger ? "#fff" : C.onAccent;
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <View style={{ flex: 1, backgroundColor: C.perde, justifyContent: "center", padding: ARA[28] }}>
        <View style={{ backgroundColor: C.paper, borderRadius: R.md, padding: ARA[22] }}>
          <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[2] }}>{title}</Text>
          {!!body && <Text style={{ fontSize: FS.sm, color: C.mut, lineHeight: 19, marginBottom: ARA[18] }}>{body}</Text>}
          {/* 🔴 v2.67 — ETİKETSİZ BUTON ÇİZİLMEZ.
              `confirmLabel={null}` geçilen dal (kural ENGELİ) bugüne kadar
              BOŞ bir teal buton çiziyordu: yazısı yok, dokunulabilir ve
              hiçbir şey yapmıyor (onConfirm de undefined). Etiketsiz buton
              bir söz vermez ama tıklanır — kullanıcı ürünün bozuk
              olduğunu düşünür. Etiketi olmayan yol, yol değildir. */}
          <View style={{ flexDirection: "row", gap: ARA[10] }}>
            {!!cancelLabel && (
              <TouchableOpacity hitSlop={TAP.slop} onPress={onCancel} disabled={busy}
                style={{ flex: 1, backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, paddingVertical: SP[3], alignItems: "center" }}>
                <Text style={{ color: C.ink, fontWeight: "600", fontSize: FS.base }}>{cancelLabel}</Text>
              </TouchableOpacity>
            )}
            {!!confirmLabel && (
              <TouchableOpacity hitSlop={TAP.slop} onPress={onConfirm} disabled={busy}
                style={{ flex: 1, backgroundColor: danger ? C.dangerBtn : C.teal, borderRadius: R.sm, paddingVertical: SP[3], alignItems: "center" }}>
                {/* 🔴 23 Eylül — tehlike onayı `C.red` (koyu temada açık pembe
                    #F2607F) üstüne `onAccent` yazıyordu: ölçülen 3.11:1, AA (4.5) altı.
                    Tehlike DÜĞMESİNİN kendi zemini (`dangerBtn`, beyazla ≥7:1)
                    burada da kullanılıyor — aynı eylem, aynı renk. */}
                {busy ? <ActivityIndicator color="#fff" /> : <Text style={{ color: onayMurekkep, fontWeight: "700", fontSize: FS.base }}>{confirmLabel}</Text>}
              </TouchableOpacity>
            )}
          </View>
        </View>
      </View>
    </Modal>
  );
}

export { ScrollView, View, Text, TouchableOpacity };
export { Katman };

// ============================================================================
// MARKA YÜKLEYİCİSİ  (v3.4)
//
// 🔴 NEDEN VAR
// Gökberk (28 Ağu): "Yükleniyor durumu için ekran ortasında loading spinner
// döndürmek daha iyi bir çözüm ancak yaratıcılık açısından yuvarlak bir şey
// döndürmek yerine uygun göreceğin bir tarzda kendi logomuzu da
// döndürebiliriz ne dersin?"
//
// Evet — ve markamızın işareti bunun için ALIŞILMIŞTAN DAHA UYGUN. İşaret
// bir kanat (`assets/mark-gold.png`): sabit bir daire değil, YÖNÜ olan bir
// biçim. Yönü olan bir şeyin dönmesi rastgele görünmez, DAİRE ÇİZER —
// havacılıkta bekleyen uçağın yaptığı şeyin adı zaten budur: bekleme turu
// (holding pattern).
//
// Yani gösterge süs değil: "bekliyoruz" fikrinin ürünün kendi dilindeki
// karşılığı. Kullanıcı bunu düşünmez; sadece uygun bulur.
//
// 🆕 SINIF: "BİR BEKLEME GÖSTERGESİ ÜRÜNÜN DİLİNDEN BİR ŞEY SÖYLEYEBİLİYORSA,
// BEKLEME SÜRESİ KISALMAZ AMA BEKLEMEK BAŞKA BİR ŞEYE DÖNÜŞÜR."
//
// ⚠️ MALİYETİ SIFIRA YAKIN — VE BU ÖNEMLİ, ÇÜNKÜ AYNI TURDA "APP BİR TIK
// YAVAŞ" DENDİ. Animasyon `useNativeDriver: true` ile çalışıyor: dönüş
// tamamen UI iş parçacığında, JS köprüsünden HİÇ geçmiyor. Yani veri
// yüklenirken JS ne kadar meşgul olursa olsun gösterge takılmıyor —
// klasik `ActivityIndicator`ın veremediği garanti tam olarak budur.
//
// 🆕 SINIF: "BİR YÜKLEME GÖSTERGESİ JS İŞ PARÇACIĞINDA ÇALIŞIYORSA, TAM DA
// EN ÇOK GEREKTİĞİ ANDA — İŞ PARÇACIĞI DOLUYKEN — TAKILIR."
// ============================================================================
// 🔴 20 EYLÜL — Kemer'e geçildi. Eski kanat dosyaları SİLİNMEDİ
// (assets/mark-gold.png · assets/mark-light.png) — geri dönüş açık.
const MARKA_ALTIN = require("../assets/mark-kemer-ink.png");
const MARKA_ACIK = require("../assets/mark-kemer.png");

export function MarkaYukleyici({ boy = 46, koyuZemin = false }) {
  const don = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Tek bir 0→1 döngüsü, sonsuz tekrar. `easing` YOK: sabit hızlı dönüş,
    // bir bekleme turunun kendisi gibi. Değişken hız burada "takılıyor"
    // gibi okunurdu — göstergenin işi durumu bildirmek, dikkat çekmek değil.
    const dongu = Animated.loop(
      Animated.timing(don, {
        toValue: 1,
        duration: 2600,          // yavaş: telaş değil, süreklilik
        useNativeDriver: true,
      })
    );
    dongu.start();
    return () => dongu.stop();
  }, [don]);

  const aci = don.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] });
  // Kanat düz dönerken "yatıyor" gibi görünmesin diye hafif bir eğim:
  // dönüşün ekseni tam merkez değil, biraz aşağıda — süzülme hissi.
  return (
    <View style={{ alignItems: "center", justifyContent: "center" }}>
      <Animated.Image
        source={koyuZemin ? MARKA_ACIK : MARKA_ALTIN}
        resizeMode="contain"
        style={{ width: boy, height: boy, transform: [{ rotate: aci }] }}
        // Erişilebilirlik: ekran okuyucu bunu bir görsel olarak değil,
        // bir DURUM olarak duyurmalı.
        accessibilityRole="progressbar"
        accessible
      />
    </View>
  );
}

// ============================================================================
// GİRİŞ SAHNESİ — SPLASH'İN ATMOSFERİ, FORMUN OKUNURLUĞU  (v3.4)
//
// 🔴 GÖKBERK (28 Ağustos)
// "splash ekranında uyguladığımız tema ve arka planı login ekranına, başla
//  sonrasındaki tanıtım ekranlarına ve signup ekranına da uygulayalım bence.
//  Login sonrası ana sayfaya gelene kadar bu yapıda olalım bence tutarlılık
//  açısından."
//
// Doğru istek: bugün Splash bir dünya kuruyor (fotoğraf, geniş harf aralıklı
// marka, sıcak ışık), sonraki ekran o dünyayı BIRAKIYOR ve düz krem bir forma
// düşüyor. Kullanıcı iki farklı ürün gördüğünü hissediyor.
//
// ⚠️ AMA FOTOĞRAFI DOĞRUDAN FORMUN ALTINA KOYAMAM. Kayıt ekranında üç adım,
// yedi giriş alanı, altı onay kutusu ve uzun sözleşme metni var. Bunları
// fotoğrafın üstüne koymak, `atmosfer.js`in başında ÖLÇTÜĞÜMÜZ hatanın
// aynısıdır: referans görselleri zemin yaptığımda gövde metni piksellerin
// %0–16'sında AA geçiyordu, en kötü noktası 1.30:1'di.
//
// 🆕 SINIF: "BİR ATMOSFERİ TAŞIMAK, ONU HER ŞEYİN ALTINA KOYMAK DEĞİLDİR —
// METİN YOĞUN BİR EKRANDA ATMOSFER ÇERÇEVEDE DURUR, ZEMİNDE DEĞİL."
//
// ÇÖZÜM — üç katman:
//   1. Fotoğraf + ölçülmüş perde  (FotoSahne, Splash'le BİREBİR aynı)
//   2. Üstte marka bloğu          — fotoğrafın üstünde, `C.foto.*` ile
//                                   (bu renkler v3.1'de ÖLÇÜLDÜ: 7.19 / 7.02)
//   3. İçerik SAYFASI             — opak `C.card` zeminli, üstten yuvarlak
//                                   bir yaprak. Formun bütün metin renkleri
//                                   ZATEN bu zemine göre ölçülü; tek bir
//                                   kontrast oranı değişmiyor.
//
// Yani kullanıcı aynı dünyada kalıyor, ama okuduğu her satır hâlâ ölçülmüş
// bir zeminin üstünde. Fotoğraf çerçeve oluyor, zemin değil.
// ============================================================================
// 🔴 `t` PROP'U İMZADAN ÇIKARILDI. İlk yazımda alışkanlıkla koydum ve
// `check.js`in ölü-prop nöbetçisi yakaladı: bu bileşen hiçbir metni
// kendisi çevirmiyor, gelen değerleri ÇİZİYOR. Okunmayan bir prop, bir
// sonraki geliştiriciye "burada bir bağlantı var" diye yalan söyler.
export function GirisSahnesi({ ustBilgi, baslik, sag, children, yaprakUst = 0 }) {
  return (
    <FotoSahne perdeBas={0.10} perdeGuc={0.42}>
      <View style={{ paddingTop: TOPPAD + 8, paddingHorizontal: SP[5], paddingBottom: SP[3],
                     flexDirection: "row", alignItems: "flex-start" }}>
        <View style={{ flex: 1 }}>
          {/* 🔴 30 AĞUSTOS · 5. TUR — GİRİŞ KAPISI DA TASARIMIN ÖLÇÜLERİNE.
              Marka aralığı 4 → 4.6 (`.marka` .42em), üst bilgi altın ve
              BÜYÜK HARF (`.dugum`), başlık `.ust-h1` puntosunda ve
              satırlara bölünebilir.
              Bu ekranlar iki turdur önizlemede HİÇ ÇİZİLMEMİŞTİ — ben de
              "uçtan uca" derken onlara hiç bakmamışım. */}
          <Text style={{ fontSize: FS.xs, color: C.foto.marka, letterSpacing: 4.6,
                         fontWeight: "700",
                         textShadowColor: "rgba(10,6,6,0.9)",
                         textShadowOffset: { width: 0, height: 1 },
                         textShadowRadius: 6 }}>LOUNGELINK</Text>
          {!!ustBilgi && (
            <Text style={{ fontSize: FS.micro, color: C.foto.dugum, letterSpacing: 2.4,
                           fontWeight: "700", marginTop: ARA[34],
                           textShadowColor: "rgba(10,6,6,0.9)",
                           textShadowOffset: { width: 0, height: 1 },
                           textShadowRadius: 6 }}>{BUYUK(ustBilgi)}</Text>
          )}
          {!!baslik && (
            <Text numberOfLines={3}
                  style={{ fontSize: FS.hero, fontWeight: "700", letterSpacing: -1,
                           lineHeight: SATIR(FS.hero),
                           color: C.foto.baslik, marginTop: ARA[8],
                           textShadowColor: "rgba(10,6,6,0.85)",
                           textShadowOffset: { width: 0, height: 2 },
                           textShadowRadius: 9 }}>{baslik}</Text>
          )}
        </View>
        {sag}
      </View>

      {/* İÇERİK YAPRAĞI — opak. Üstteki iki köşe yuvarlak: fotoğrafın
          bittiği yeri gizlemek yerine AÇIKÇA gösteriyor. Kenar çizgisi yok;
          yaprağın kendisi zaten bir kenar. */}
      <View style={{ flex: 1, backgroundColor: C.card,
                     borderTopLeftRadius: 26, borderTopRightRadius: 26,
                     marginTop: yaprakUst, overflow: "hidden" }}>
        {children}
      </View>
    </FotoSahne>
  );
}

// ============================================================================
// BOŞ DURUM — TEK BİLEŞEN  (v3.4)
//
// 🔴 NEDEN VAR — DENETİMDE ÖLÇÜLDÜ
// Uygulamada boş durum ÜÇ farklı desenle ve 12 ayrı elle yazılmış blokla
// çiziliyordu: kesik çizgili çerçeve (`S.empty`, 10 yer) · bir ekranın
// GÖVDESİNİN İÇİNDE tanımlanmış yerel bir `Empty` (yalnız o ekranda
// kullanılabilir) · ve 12 tane tamamen elle yazılmış blok (kimi `S.card`,
// kimi çıplak `Text`, kimi tint kutu). Mürekkep de değişiyordu: `C.mut`,
// `C.mutedAA`, `C.dimAA`, `C.body`, `C.ink`.
//
// Yani kullanıcı aynı ANI — "burada henüz bir şey yok" — dört farklı
// görsel dille okuyordu. Bir ürünün en çok tekrar eden anı buysa, en
// tutarlı anı da o olmalı.
//
// 🆕 SINIF: "EN SIK TEKRAR EDEN DURUMU HER EKRAN KENDİ ELİYLE ÇİZİYORSA,
// ORTAYA BİR TASARIM DİLİ DEĞİL BİR EL YAZISI KOLEKSİYONU ÇIKAR."
//
// ⚠️ VE BOŞ DURUM BİR ÜRÜN YÜZEYİDİR, BİR BOŞLUK DEĞİL. Denetimde
// ölçüldü: 8 boş durum metni yalnız YOKLUĞU bildiriyordu ("Aktif oturum
// yok", "Eşleşme yok"). Bu bileşen bir `eylem` slotu taşıyor — çünkü
// boş bir ekranın işi, orayı doldurmanın yolunu göstermektir.
// ============================================================================
export function BosDurum({ ikon, baslik, metin, eylem, sikisik = false }) {
  return (
    <View style={{
      alignItems: "center", paddingVertical: sikisik ? 20 : 28, paddingHorizontal: ARA[20],
      borderWidth: 1, borderColor: C.line, borderStyle: "dashed", borderRadius: R.sm,
      backgroundColor: "transparent",
    }}>
      {!!ikon && (
        <View style={{
          // 🔴 `borderRadius: 22` YAZMIYORUM. 44/2 elle hesaplanmış bir
          // daire, boyut değiştiği gün sessizce yumurtaya döner — ve
          // denetimde ölçüldü: uygulamada beş ayrı yerde avatar dairesi
          // böyle hesaplanmış (r38/r37/r21/r20). `R.full` her boyutta
          // daire kalır.
          // 🆕 SINIF: "BİR DAİREYİ YARIÇAPI ELLE YAZARAK KURARSAN, O
          // DAİRE BOYUT DEĞİŞENE KADAR DAİREDİR."
          width: 44, height: 44, borderRadius: R.full, backgroundColor: C.bgAlt,
          alignItems: "center", justifyContent: "center", marginBottom: SP[3],
        }}>
          <Ikon ad={ikon} boy={20} renk={C.muted} />
        </View>
      )}
      {!!baslik && (
        <Text style={{ fontSize: FS.base, fontWeight: "700", color: C.ink,
                       textAlign: "center", marginBottom: SP[1] }}>{baslik}</Text>
      )}
      {!!metin && (
        <Text style={{ fontSize: FS.sm, color: C.mutedAA, textAlign: "center",
                       lineHeight: 18 }}>{metin}</Text>
      )}
      {!!eylem && <View style={{ marginTop: ARA[14], alignSelf: "stretch" }}>{eylem}</View>}
    </View>
  );
}
