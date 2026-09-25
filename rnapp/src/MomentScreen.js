// ============================================================
// MomentScreen — ÜRÜNÜN "AN"LARI
//
// 🔴 TASARIM KARARI (Gokberk'e verdiğim söz): uygulamanın TAMAMI
// koyuya geçmiyor. Kural motoru bir referans aracıdır; okunabilirlik
// ve ciddiyet ister, açık kalır. Ama üç an var ki bunlar araç değil
// DENEYİM: eşleşmenin kabul edildiği an, oturumun başladığı an,
// oturumun tamamlandığı an. O anlarda ışık değişir.
//
// Rakip (Lounge Surf) her ekranı karanlık yapıyor; sonuç tek tonluk
// bir uygulama — hiçbir an diğerinden ayrışmıyor. Bizim yaklaşımımız
// KONTRAST üzerine: kullanıcı ürünü aydınlıkta kullanır, anı
// karanlıkta yaşar. Bu, aynı malzemeyle daha güçlü bir his üretir.
//
// Palet: tema renklerimiz KORUNUR — zemin ink (#1A1F2E) üzerine
// gece gradyanı, vurgu altın (#B8943A), metin fildişi (paper).
// Yeni renk İCAT EDİLMEDİ; var olanların koyu kompozisyonu.
// ============================================================
import React, { useEffect, useRef } from "react";
import { View, Text, TouchableOpacity, Animated, Easing, Image, Dimensions } from "react-native";
import { BUYUK } from "./i18n";
import { ARA, C, F, FS, R, SP, T, TAP } from "./theme";
import { MONO } from "./typography";
import { Ikon } from "./ikon";
import { TOPPAD, Btn, Hale, MESH_BANT } from "./ui";
import { Katman } from "./katman";

// Sahne ölçüleri — haleler ekran genişliğine oranlı (tasarımın
// radial-gradient'i de kutuya oranlı: `96% 62% at 50% 8%`).
const EN = Dimensions.get("window").width;
const BOY = Dimensions.get("window").height;

/* Tasarımdaki `.an-av`: 66px, yuvarlak, ince kenarlık, serif baş harf.
   İki tanesi yan yana ve aralarındaki çizgi — bu üçlü, "eşleştiniz"
   cümlesinin görsel karşılığı. İkincisi teal: kalkan rengiyle aynı,
   yani "seni içeri alacak olan" tarafı işaret ediyor. */
function AnAvatar({ harf, ton }) {
  return (
    <View style={{ width: 66, height: 66, borderRadius: R.full,
                   borderWidth: 1, borderColor: C.line2 || C.line,
                   backgroundColor: "rgba(255,255,255,0.05)",
                   alignItems: "center", justifyContent: "center" }}>
      <Text style={{ fontFamily: F.serif, fontSize: FS.display, fontWeight: "600",
                     color: ton || C.gold }}>
        {String(harf || "?").charAt(0).toUpperCase()}
      </Text>
    </View>
  );
}

// 🔴 8. tur — `STARS` KALDIRILDI (arşiv: `_yedek_sahne/`).
// Eski "gece şehri" sahnesinin ışık noktalarıydı. Sahne tasarımın
// `.mesh-yogun`una çevrilince kullanan kalmadı; duran ölü bir sabit,
// bir sonraki okuyucuya "bu ekranda yıldızlar var" der.

export default function MomentScreen({
  // 🔵 26 AĞUSTOS — `t` EKLENDİ. "GİRİŞ KODU" başlığı sabit Türkçeydi ve
  // İngilizce cihazda öyle kalıyordu. Varsayılanlı prop: geçmeyen çağrı
  // yerleri aynen çalışır, geçen yerler çevrilir.
  t = {},
  kind,          // "matched" | "started" | "completed"
  title,
  subtitle,
  code,          // oturum giriş kodu (varsa büyük gösterilir)
  meta,          // salon · saat gibi ikincil satır
  dugum,         // üst etiket — tasarımdaki `.dugum` (örn. "EŞLEŞTİNİZ")
  ikiz,          // [benHarf, oHarf] — eşleşme anındaki iki avatar
  sayac,         // { deger: "02:41:08", etiket: "kalkışa" }
  primary,       // { label, onPress }
  secondary,     // { label, onPress }
  children,
}) {
  // Tek bir animasyon: içerik yukarı süzülerek belirir. Abartılı
  // hareket "an"ı ucuzlatır; tek yumuşak giriş yeterli.
  const rise = useRef(new Animated.Value(0)).current;
  const glow = useRef(new Animated.Value(0.5)).current;
  useEffect(() => {
    Animated.timing(rise, {
      toValue: 1, duration: 620, easing: Easing.out(Easing.cubic), useNativeDriver: true,
    }).start();
    const loop = Animated.loop(Animated.sequence([
      Animated.timing(glow, { toValue: 1, duration: 2200, useNativeDriver: true }),
      Animated.timing(glow, { toValue: 0.5, duration: 2200, useNativeDriver: true }),
    ]));
    loop.start();
    return () => loop.stop();
  }, [rise, glow]);

  const translateY = rise.interpolate({ inputRange: [0, 1], outputRange: [18, 0] });
  // 🔴 v2.72 — İKİ AN EKLENDİ VE İKİSİ DE HOST'UN ANLARI.
  // Ürünün üç anı vardı ve ÜÇÜ DE MİSAFİRİN anıydı: eşleşme, oturum,
  // tamamlanma. Host hiçbir zaman tam ekran bir şey yaşamıyordu —
  // arka planda çalışan bir altyapı gibi davranılıyordu.
  //
  // Gokberk'in kaygısı ("host çekemezsek bir işe yaramaz") bir mekanik
  // sorunu kadar bir DUYGU sorunu: host'un ürünle bağ kurduğu bir an
  // yoktu. İki an ekliyorum:
  //   · "recognized" — kişi kartını tanıttı ve elindeki hakkı İLK KEZ
  //     bir sayı olarak gördü. "Sen bir host'sun" dediğimiz an.
  //   · "reciprocity" — ağırladı ve karşılığını aldı. "Artık sen de
  //     misafir olabilirsin" dediğimiz an. Döngünün kapandığı yer.
  // 🔴 30 AĞUSTOS · 3. TUR — İŞARET ARTIK AD, KARAKTER DEĞİL.
  // Dördü de metin glifiydi ve `FS.hero` (34) ile çiziliyordu: cihazın
  // gövde fontuna bağlı, kırpılabilir, platformdan platforma değişen.
  const mark = kind === "completed" ? "tamam"
             : kind === "started" ? "radar"
             : kind === "reciprocity" ? "degistir"
             : "kutlama";

  return (
    <View style={{ flex: 1, backgroundColor: C.gece, paddingTop: TOPPAD }}>
      {/* ══════════════════════════════════════════════════════════════
          🔴 31 AĞUSTOS · 8. TUR — BU SAHNE TASARIMIN SAHNESİ DEĞİLDİ.

          Burada elle kurulmuş bir "gece şehri" vardı: iki küçük daire,
          46 ışık noktası ve bir ufuk çizgisi. Güzeldi ama tasarımın
          `.an` ekranı bambaşka bir şey söylüyor:

              .mesh-yogun{
                radial-gradient(96% 62% at 50%  8%, altın .42)
                radial-gradient(88% 58% at 22% 44%, mavi  .26)
                linear-gradient(180deg,#241D26 0%, gece 62%)}
              .an::after{ background:FOTO center 46%/cover;
                          opacity:.20; mix-blend-mode:screen }

          Yani: iri iki hale + %20 SCREEN harmanlı uçak camı fotoğrafı.
          Fark ölçülebilir — önizleme üreticisini tasarıma çevirdikten
          sonra aynı noktaları örnekledim:
              tasarım (105,86,68) (80,82,86) (75,64,67)
              eski sahne          çok daha koyu ve fotoğrafsız

          Ve önemlisi: bu ekran ürünün EN DUYGUSAL ekranı. "Gece" ile
          "uçakta gece" arasındaki fark, tam olarak bu ürünün nerede
          geçtiğini söyleyen fark.

          🆕 SINIF: "BİR SAHNEYİ ELLE KURMAK, TASARIMIN SAHNESİNİ
          UYGULAMAKTAN DAHA KOLAYDIR — VE SONUCU HEP 'BENZER AMA BAŞKA'
          OLUR."

          ⚠️ `experimental_mixBlendMode` RN 0.76'da DENEYSEL. Desteklenmezse
          göz ardı edilir ve fotoğraf düz %20 alfayla biner — yani sahne
          bir tık koyulaşır, KIRILMAZ. Bilerek seçilmiş bir düşüş yolu.
          ══════════════════════════════════════════════════════════════ */}
      {/* 1 · dikey taban — `meshUst2` → saydam, %62'de biter.
          18 bant yığınının ikinci kopyası; `cihaz_parite_check.py`
          bunu da yakaladı. Aynı `dikey.png`, farklı renk ve yükseklik. */}
      <Katman source={require("../assets/dikey.png")} resizeMode="stretch"
        tintColor={C.meshUst2 || C.meshUst}
        // Genişlik karşıt kenarla sabit (bkz. kaplama_check.py); yükseklik
        // kasten oranlı — bu katman kabın yalnız üst %62'sini boyuyor.
        style={{ position: "absolute", left: 0, right: 0, top: 0, height: "62%" }} />
      {/* 2 · fotoğraf — %20, screen */}
      <Katman source={require("../assets/bant.jpg")} resizeMode="cover"
        style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
                 opacity: 0.20, experimental_mixBlendMode: "screen" }} />
      {/* 3 · iki iri hale — altın üstte ortada (nefes alıyor), mavi solda */}
      <Animated.View pointerEvents="none" style={{
        position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
        opacity: glow.interpolate({ inputRange: [0.5, 1], outputRange: [0.82, 1] }),
      }}>
        <Hale renk={C.gold} cap={EN * 1.92} x={EN * 0.50} y={BOY * 0.08} guc={0.42} />
        <Hale renk={C.purple} cap={EN * 1.76} x={EN * 0.22} y={BOY * 0.44} guc={0.26} />
      </Animated.View>

      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · GECE SİSTEMİ — "AN" EKRANI TASARIMDAKİ ANATOMİYE.

          Tasarımdaki `.an` bloğu (sırayla):
            .an-ikiz   iki 66px avatar + aralarında altın→teal 52×1 çizgi
            .dugum     EŞLEŞTİNİZ · altın · büyük harf · aralık .24em
            .an-h1     Cormorant **300** · 46px · satır 1.06 · ORTALI
            .an-alt    13.5 · sessiz · satır 1.66
            .an-sayac  hap: saat ikonu + MONO 15/600 + "KALKIŞA" etiketi

          Eskisinde üç yapısal fark vardı ve üçü de anlamı taşıyordu:

          1) SOLA YASLI. Bir "an" ekranı sola yaslandığında bir SAYFA
             gibi okunur; ortalandığında bir SAHNE olur. Ürünün en
             duygusal üç ekranı sayfa gibi duruyordu.

          2) İKİ KİŞİ YOKTU. Eşleşme ekranında tek bir marka işareti
             vardı. Oysa o anın konusu marka değil, İKİ İNSAN ve
             aralarında kurulan bağ — tasarımdaki çizgi tam olarak o
             bağ. Marka işareti onun yerini alamaz.

          3) SAYAÇ DÜZ METİNDİ. "kalkışa 2 sa" bir cümleydi; tasarımda
             kendi çerçevesi olan, mono, canlı bir sayaç.

          🆕 SINIF: **"BİR ANIN EKRANI, O ANIN KONUSUNU MERKEZE ALMALI.
          EŞLEŞME ANININ KONUSU ÜRÜN DEĞİL, EŞLEŞEN İKİ KİŞİDİR."**
          ══════════════════════════════════════════════════════════════ */}
      <Animated.View style={{ flex: 1, justifyContent: "center", alignItems: "center",
                              paddingHorizontal: ARA[26],
                              opacity: rise, transform: [{ translateY }] }}>
        {ikiz ? (
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <AnAvatar harf={ikiz[0]} />
            {/* Bağ çizgisi: tasarımda altından teale giden 52×1 bir
                gradyan. Gradyan paketi yok — çizgi iki yarıya bölündü,
                sol yarı altın, sağ yarı teal. 52px'te geçiş noktası
                zaten tek bir piksel; göz bunu gradyan olarak okur. */}
            <View style={{ flexDirection: "row", opacity: 0.7 }}>
              <View style={{ width: 26, height: 1, backgroundColor: C.gold }} />
              <View style={{ width: 26, height: 1, backgroundColor: C.teal }} />
            </View>
            <AnAvatar harf={ikiz[1]} ton={C.teal} />
          </View>
        ) : (kind === "completed" || kind === "reciprocity")
          ? <Ikon ad={mark} boy={38} renk={C.gold} />
          : <Image source={require("../assets/mark-kemer.png")}
              style={{ width: 76, height: 76 }} resizeMode="contain" />}
        {!!dugum && (
          <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2.4,
                         color: C.gold, marginTop: ARA[34] }}>
            {BUYUK(dugum)}
          </Text>
        )}
        <Text style={{ fontFamily: F.serifGosterim, fontSize: FS.anBaslik,
                       lineHeight: Math.round(FS.anBaslik * 1.06),
                       letterSpacing: -0.7, textAlign: "center",
                       color: C.paper, marginTop: dugum ? ARA[12] : ARA[14] }}>
          {title}
        </Text>
        {!!subtitle && (
          <Text style={{ fontSize: FS.sm, lineHeight: Math.round(FS.sm * 1.66),
                         textAlign: "center", color: C.paper, opacity: 0.72, marginTop: ARA[18] }}>
            {subtitle}
          </Text>
        )}
        {/* Sayaç hapı — tasarımdaki `.an-sayac`. `sayac` verilmezse eski
            `meta` satırı çiziliyor: hiçbir çağrı yeri kırılmıyor. */}
        {sayac ? (
          <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[26],
                         borderWidth: 1, borderColor: C.line2 || C.line, borderRadius: R.full,
                         paddingVertical: ARA[10], paddingHorizontal: SP[4] }}>
            <Ikon ad="saat" boy={14} kutu={16} renk={C.paper} />
            <Text style={{ fontFamily: MONO[600], fontSize: FS.lg, color: C.paper,
                           marginLeft: SP[2] }}>{sayac.deger}</Text>
            {!!sayac.etiket && (
              <Text style={{ fontSize: FS.micro, fontWeight: "600", letterSpacing: 1.4,
                             color: C.dim, marginLeft: SP[2] }}>
                {BUYUK(sayac.etiket)}
              </Text>
            )}
          </View>
        ) : !!meta && (
          <Text style={{ fontSize: FS.sm, color: C.gold, marginTop: ARA[14],
                         letterSpacing: 0.4, textAlign: "center" }}>{meta}</Text>
        )}

        {!!code && (
          <View style={{ marginTop: ARA[26], borderWidth: 1, borderColor: C.gold + "55",
                         borderRadius: R.sm, paddingVertical: ARA[20], alignItems: "center",
                         backgroundColor: C.goldBg }}>
            <Text style={{ fontSize: FS.xs, letterSpacing: 3, color: C.goldInk, marginBottom: SP[2] }}>{t.entryCode || "GİRİŞ KODU"}</Text>
            <Text style={{ fontSize: FS.bant, color: C.paper, letterSpacing: 8, fontWeight: "700" }}>
              {code}
            </Text>
          </View>
        )}

        {children}
      </Animated.View>

      <View style={{ paddingHorizontal: ARA[30], paddingBottom: ARA[34] }}>
        {!!primary && (
          <Btn v="gold" sm label={primary.label} onPress={primary.onPress} />
        )}
        {!!secondary && (
          <TouchableOpacity hitSlop={TAP.slop} onPress={secondary.onPress}
            style={{ paddingVertical: ARA[14], alignItems: "center" }}>
            <Text style={{ color: C.paper, opacity: 0.7, fontSize: FS.base }}>{secondary.label}</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}
