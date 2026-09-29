// ══════════════════════════════════════════════════════════════════════
// src/BinisKarti.js — OTURUMU BAŞLAT · BİNİŞ KARTI DOĞRULAMA
//
// 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (v5.9.0 · onaylanmış mimari)
// Sohbetin altındaki "Oturumu Başlat"ın ÖNÜNE bir kapı: iki asil seçenek
// (fiziksel bilet · elektronik bilet), cihazda çözme, sunucuya hiçbir
// görsel göndermeme ve HER EKRANDA görünen "Doğrulamayı Atla".
//
// ⚠️ ÜÇ DÜRÜST SINIR — ÖLÇÜLDÜ, GİZLENMEDİ:
//
// 1) iOS'TA GALERİDEN PDF417 OKUNMAZ. `expo-camera`nın belgesi açık:
//    "On iOS, only QR codes are supported for URL scanning." Kağıt biniş
//    kartı PDF417, THY mobil bileti genelde Aztec. Bu yüzden iOS'ta
//    galeri seçeneği GİZLENMİYOR ama basıldığında kamerayı öneriyor —
//    sessizce çalışmamak, hiç olmamaktan kötüdür.
//
// 2) "RAM'DE ÇÖZÜLÜR, DİSKE YAZILMAZ" TUTULAMAZ BİR SÖZ. Seçici, dosyanın
//    KOPYASINI uygulama önbelleğine (diske) yazar ve bize bir yol verir.
//    Biz o kopyayı okuduktan sonra SİLERİZ; ama "hiç yazılmadı" diyemeyiz.
//    Mikro metin bu yüzden tutabileceğimiz hâliyle yazıldı.
//    🆕 SINIF: "BİR GİZLİLİK VAADİ ÜRÜNÜN EN KOLAY YAZILAN, EN ZOR GERİ
//    ALINAN CÜMLESİDİR — ÖLÇMEDEN YAZILMAZ."
//
// 3) KÖŞE 20 DEĞİL 22. Brief `radius: 20` diyor; ürünün ölçeğinde alt
//    sayfa köşesi `R.xl = 22`. 2pt için ölçek dışına çıkmak, o paneli
//    ürünün geri kalanından ayırırdı (`palette_check.py` ritmi denetliyor).
//    🆕 SINIF: "BİR ÖLÇEĞİN İÇİNDE KALMAK, TEK BİR EKRANI MÜKEMMEL
//    YAPMAKTAN DEĞERLİDİR."
//
// ⚠️ NATIVE MODÜLLER TEMBEL YÜKLENİYOR (`require` fonksiyon içinde).
// `expo-camera` kurulu değilse uygulama PATLAMAZ: kamera seçeneği
// kendini gizler, galeri/dosya ve Atla yolları çalışmaya devam eder.
// Aynı deseni `ui.js` jiroskop için zaten kullanıyor.
// ══════════════════════════════════════════════════════════════════════
import React, { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Animated, Easing, Linking, Platform, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import { bcbpBul, bcbpCoz, kuralUyum } from "./bcbp";
import { Ikon } from "./ikon";
import { mapErr } from "./i18n";
import { logError, supabase } from "./supabase";
import { ARA, C, F, FS, R, SATIR, SP, TAP } from "./theme";
import { Btn } from "./ui";
import { ustIsik } from "./ortak";
import { MONO } from "./typography";
import { BUYUK } from "./i18n";

// ── Tembel native yükleyiciler ────────────────────────────────────────
function kameraModulu() {
  try { return require("expo-camera"); } catch (e) { return null; }
}
function galeriModulu() {
  try { return require("expo-image-picker"); } catch (e) { return null; }
}
function dosyaModulu() {
  try { return require("expo-document-picker"); } catch (e) { return null; }
}
function dosyaSistemi() {
  try { return require("expo-file-system"); } catch (e) { return null; }
}

// 🔴 GİZLİLİK PROTOKOLÜ — OKUDUKTAN SONRA SİL.
// Seçicinin önbelleğe yazdığı kopya, IATA dizesi çıkarılır çıkarılmaz
// silinir. Silme BAŞARISIZ OLURSA sessiz kalmıyoruz: kaydediyoruz.
// Sonuç ne olursa olsun akış devam eder — temizlik, kullanıcının işini
// bölmek için bir sebep değildir.
async function kopyayiSil(uri) {
  const FS_ = dosyaSistemi();
  if (!FS_ || !uri) return false;
  try {
    await FS_.deleteAsync(uri, { idempotent: true });
    return true;
  } catch (e) {
    logError("binis_karti_kopya_silinemedi", e);
    return false;
  }
}

// ── Buzlu cam ─────────────────────────────────────────────────────────
// RN'de `backdrop-filter` yok. `expo-blur` iOS'ta gerçek blur verir,
// Android'de pahalı ve zayıf — 12 Eylül'de aynı kararı metin için verip
// kaydetmiştik. Burada da AYNI: iOS'ta blur, Android'de katmanlı alfa.
// Çağıran hangisi olduğunu bilmez.
function Cam({ children, stil, yogunluk = 26 }) {
  let BlurView = null;
  try { BlurView = require("expo-blur").BlurView; } catch (e) { BlurView = null; }
  if (BlurView && Platform.OS === "ios") {
    return (
      <BlurView intensity={yogunluk} tint="dark" style={stil}>
        <View style={{ backgroundColor: (C.popupZemin || C.paper) + "C8", flex: 1 }}>{children}</View>
      </BlurView>
    );
  }
  // v6.3 (pano D) — cam sayfa: Android'de bulanıklık yok; popup zemini
  // (#1E1B18) sohbetin kadife yüzeyinden bir kademe açık — ayrım ışıkla.
  return <View style={[{ backgroundColor: C.popupZemin || C.paper }, stil]}>{children}</View>;
}

// ── Seçenek satırı ────────────────────────────────────────────────────
function Secenek({ ikon, baslik, alt, onPress, disabled, sag }) {
  return (
    <TouchableOpacity
      hitSlop={TAP.slop}
      disabled={disabled}
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={baslik}
      style={{
        flexDirection: "row", alignItems: "center",
        backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
        borderRadius: R.lg, padding: SP[4], marginTop: ARA[10],
        minHeight: TAP.minHeight, opacity: disabled ? 0.5 : 1,
      }}>
      <Ikon ad={ikon} boy={FS.lg + 4} renk={C.gold} stil={{ marginRight: ARA[14] }} />
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.base, fontWeight: "600",
                                         lineHeight: SATIR(FS.base) }}>{baslik}</Text>
        {!!alt && (
          <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[2],
                         lineHeight: SATIR(FS.xs) }}>{alt}</Text>
        )}
      </View>
      {sag || <Ikon ad="sag" boy={FS.base} renk={C.dim} />}
    </TouchableOpacity>
  );
}

// ── Vizör ─────────────────────────────────────────────────────────────
// 🔴 PENCERE YATAY VE GENİŞ. Kare bir QR vizörü kağıt bileti kadraja
// sokmaz: PDF417 çok geniş, çok alçak bir barkoddur. Oranı ona göre.
function Vizor({ t, onKapat, onDize, onHata }) {
  const K = kameraModulu();
  const [izin, setIzin] = useState(null);
  // v6.1 (Gökberk md.7) — izin kalıcı reddedildiyse sistem bir daha
  // sormaz; tek çıkış Ayarlar. "Geri"den başka yol göstermiyorduk.
  const [tekrarSor, setTekrarSor] = useState(true);
  const [okundu, setOkundu] = useState(false);
  const basladi = useRef(Date.now());
  const nabiz = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    let canli = true;
    (async () => {
      if (!K) { setIzin(false); return; }
      try {
        const izinFn = K.Camera && K.Camera.requestCameraPermissionsAsync
          ? K.Camera.requestCameraPermissionsAsync
          : K.requestCameraPermissionsAsync;
        const { status, canAskAgain } = await izinFn();
        if (canli) { setIzin(status === "granted"); setTekrarSor(canAskAgain !== false); }
      } catch (e) { if (canli) setIzin(false); }
    })();
    return () => { canli = false; };
  }, [K]);

  // Köşe işaretleri nefes alır: "çalışıyor" sinyali, metin olmadan.
  useEffect(() => {
    const d = Animated.loop(Animated.sequence([
      Animated.timing(nabiz, { toValue: 1, duration: 1100, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      Animated.timing(nabiz, { toValue: 0, duration: 1100, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
    ]));
    d.start();
    return () => d.stop();
  }, [nabiz]);

  // 🔴 SÜRE SINIRI: 8 saniyede kod okunamazsa kullanıcıyı BEKLETMEYİZ.
  // Parlama mı, odak mı ayırt edemeyiz; ikisini de aynı dalda topluyoruz
  // ve ikisinde de Atla açık kalıyor.
  useEffect(() => {
    const z = setTimeout(() => { if (!okundu) onHata && onHata("odak_yok"); }, 8000);
    return () => clearTimeout(z);
  }, [okundu, onHata]);

  const kodOkundu = useCallback((olay) => {
    if (okundu) return;
    const ham = olay && (olay.data || olay.raw);
    if (!ham) return;
    setOkundu(true);
    onDize && onDize(String(ham), Date.now() - basladi.current);
  }, [okundu, onDize]);

  if (izin === null) {
    return (
      <View style={{ flex: 1, backgroundColor: C.bg, alignItems: "center", justifyContent: "center" }}>
        <ActivityIndicator color={C.gold} />
      </View>
    );
  }
  if (!K || izin === false) {
    // Çıkmaz sokak yok: izin yoksa bile öbür yollar ve Atla duruyor.
    return (
      <View style={{ flex: 1, backgroundColor: C.bg, alignItems: "center", justifyContent: "center", padding: SP[5] }}>
        <Ikon ad="kamera" boy={40} renk={C.dim} />
        <Text style={{ color: C.ink, fontSize: FS.base, textAlign: "center", marginTop: ARA[14],
                       lineHeight: SATIR(FS.base) }}>
          {K ? t.bpCamDenied : t.bpCamMissing}
        </Text>
        <View style={{ alignSelf: "stretch", marginTop: ARA[20] }}>
          {K && !tekrarSor ? (
            <Btn v="gold" label={t.bpOpenSettings} solAd="ayarlar"
              onPress={() => Linking.openSettings && Linking.openSettings().catch(() => {})} />
          ) : null}
          <Btn v="ghost" label={t.back} onPress={onKapat} a11yLabel={t.back}
            style={K && !tekrarSor ? { marginTop: ARA[10] } : undefined} />
        </View>
      </View>
    );
  }

  const CameraView = K.CameraView || K.Camera;
  const kose = { position: "absolute", width: 26, height: 26, borderColor: C.gold };
  const sonuc = { opacity: nabiz.interpolate({ inputRange: [0, 1], outputRange: [0.55, 1] }) };

  return (
    <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.92)" }}>
      <CameraView
        style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0 }}
        facing="back"
        autofocus="on"
        barcodeScannerSettings={{ barcodeTypes: ["pdf417", "aztec", "qr", "datamatrix"] }}
        onBarcodeScanned={kodOkundu}
      />
      {/* Perde: ortadaki yatay pencere açık, çevresi koyu */}
      <View style={{ flex: 1 }} pointerEvents="box-none">
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.62)" }} />
        <View style={{ flexDirection: "row", height: 128 }}>
          <View style={{ width: SP[4], backgroundColor: "rgba(0,0,0,0.62)" }} />
          <Animated.View style={[{ flex: 1, borderRadius: R.lg }, sonuc]}>
            <View style={[kose, { left: 0, top: 0, borderLeftWidth: 2, borderTopWidth: 2, borderTopLeftRadius: R.lg }]} />
            <View style={[kose, { right: 0, top: 0, borderRightWidth: 2, borderTopWidth: 2, borderTopRightRadius: R.lg }]} />
            <View style={[kose, { left: 0, bottom: 0, borderLeftWidth: 2, borderBottomWidth: 2, borderBottomLeftRadius: R.lg }]} />
            <View style={[kose, { right: 0, bottom: 0, borderRightWidth: 2, borderBottomWidth: 2, borderBottomRightRadius: R.lg }]} />
          </Animated.View>
          <View style={{ width: SP[4], backgroundColor: "rgba(0,0,0,0.62)" }} />
        </View>
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.62)", paddingHorizontal: SP[5], paddingTop: SP[5] }}>
          <Text style={{ color: C.foto.baslik, fontSize: FS.sm, textAlign: "center",
                         lineHeight: SATIR(FS.sm) }}>{t.bpScanHint}</Text>
          <Text style={{ color: C.meshAlt, fontSize: FS.xs, textAlign: "center",
                         marginTop: ARA[10], lineHeight: SATIR(FS.xs) }}>{t.bpPrivacy}</Text>
        </View>
      </View>
    </View>
  );
}

// ── Panel ─────────────────────────────────────────────────────────────
// `onDogrulandi(sonuc)` → çağıran `start_session_request`i sürer.
// ⚠️ PANEL HİÇBİR DURUMDA "BAŞLATMAYI" KENDİSİ YAPMAZ: doğrulama ile
// oturum başlatma iki ayrı sorumluluk. Karıştırırsak, doğrulamayı
// değiştirmek oturum akışını da riske atar.
export function BinisKartiPanel({ t, request, ilan, onKapat, onDogrulandi }) {
  const [gorunum, setGorunum] = useState("secim");   // secim | eBilet | vizor | sonuc
  const [busy, setBusy] = useState(false);
  const [hata, setHata] = useState("");
  const [sonuc, setSonuc] = useState(null);
  const gir = useRef(new Animated.Value(0)).current;
  // 29 Eylül · SQL 307 — 30 günde 2 sessiz atlama. RPC yoksa (307 koşmadıysa) not gizlenir.
  const [hak, setHak] = useState(null);
  useEffect(() => {
    let iptal = false;
    (async () => {
      try {
        const { data, error } = await supabase.rpc("binis_karti_atlama_hakki");
        if (!error && !iptal) setHak(data || null);
      } catch (e) { /* 307 yoksa sessiz */ }
    })();
    return () => { iptal = true; };
  }, []);

  useEffect(() => {
    Animated.timing(gir, { toValue: 1, duration: 260, easing: Easing.out(Easing.cubic),
                           useNativeDriver: true }).start();
  }, [gir]);

  // ── Sunucuya YALNIZ türetilmiş alanlar ──────────────────────────────
  const kaydet = useCallback(async (yontem, gecti, sebep, coz, sure) => {
    try {
      const { error } = await supabase.rpc("binis_karti_kaydet", {
        p_request_id: request && request.id,
        p_method: yontem,
        p_passed: !!gecti,
        p_reason_code: sebep || null,
        p_airport: coz && coz.kalkis ? coz.kalkis : null,
        p_flight_date: coz && coz.ucusTarihi ? coz.ucusTarihi : null,
        p_carrier_flight: coz && coz.ucusKodu ? coz.ucusKodu : null,
        p_cabin: coz && coz.kabinKodu ? coz.kabinKodu : null,
        // 🔴 HAM DİZE DEĞİL: yalnız karma GİRDİSİ. Sunucu tuzlar ve
        // karmalar; ne ham girdi ne karma geri döner (bkz. SQL 294).
        p_pnr_girdi: coz && coz._pnrKarmaGirdisi ? coz._pnrKarmaGirdisi : null,
        p_duration_ms: sure || null,
      });
      if (error) {
        // `zaten_dogrulandi` kullanıcıya anlamlı bir cümledir; yutmuyoruz.
        setHata(mapErr(t, error.message));
        logError("binis_karti_kaydet", error);
        return false;
      }
      return true;
    } catch (e) {
      logError("binis_karti_kaydet", e);
      setHata(t.errGeneric);
      return false;
    }
  }, [request, t]);

  // ── Çözülen dizeyi değerlendir ──────────────────────────────────────
  const dizeGeldi = useCallback(async (ham, sure, yontem) => {
    setBusy(true); setHata("");
    const coz = bcbpCoz(ham);
    if (!coz.ok) {
      setBusy(false);
      setSonuc({ gecti: false, kod: coz.kod });
      setGorunum("sonuc");
      await kaydet(yontem, false, coz.kod, null, sure);
      return;
    }
    const uyum = kuralUyum(coz, ilan || {});
    const kod = uyum.gecti ? null : (uyum.sert[0] && uyum.sert[0].kod) || "bcbp_degil";
    const ok = await kaydet(yontem, uyum.gecti, kod, coz, sure);
    setBusy(false);
    setSonuc({ gecti: uyum.gecti && ok, kod, coz, uyum });
    setGorunum("sonuc");
  }, [ilan, kaydet]);

  // ── Galeri ──────────────────────────────────────────────────────────
  const galeriden = useCallback(async () => {
    const IP = galeriModulu();
    const K = kameraModulu();
    if (!IP || !K) { setHata(t.bpNoModule); return; }
    // ⚠️ iOS'ta durağan görselde YALNIZ QR okunur (expo-camera belgesi).
    // Kağıt bilet PDF417 olduğu için burada dürüst davranıp kamerayı
    // öneriyoruz; sessizce başarısız olmuyoruz.
    if (Platform.OS === "ios") {
      setHata(t.bpIosGalleryHint);
      return;
    }
    setBusy(true); setHata("");
    const t0 = Date.now();
    let uri = null;
    try {
      const izin = await IP.requestMediaLibraryPermissionsAsync();
      if (!izin || izin.status !== "granted") { setBusy(false); setHata(t.bpGalleryDenied); return; }
      const sec = await IP.launchImageLibraryAsync({ quality: 1, allowsEditing: false });
      if (sec.canceled || !sec.assets || !sec.assets[0]) { setBusy(false); return; }
      uri = sec.assets[0].uri;
      const tara = (K.CameraView && K.CameraView.scanFromURLAsync) || K.scanFromURLAsync;
      const bulunan = await tara(uri, ["pdf417", "aztec", "qr", "datamatrix"]);
      const ham = bulunan && bulunan[0] && bulunan[0].data;
      if (!ham) {
        setBusy(false);
        await kopyayiSil(uri);
        setSonuc({ gecti: false, kod: "cozulmedi" });
        setGorunum("sonuc");
        await kaydet("gallery", false, "cozulmedi", null, Date.now() - t0);
        return;
      }
      await kopyayiSil(uri);     // 🔴 okundu → kopya SİLİNDİ
      await dizeGeldi(String(ham), Date.now() - t0, "gallery");
    } catch (e) {
      logError("binis_karti_galeri", e);
      await kopyayiSil(uri);
      setBusy(false);
      setHata(t.bpDecodeFail);
    }
  }, [t, dizeGeldi, kaydet]);

  // ── Dosya (PDF) ─────────────────────────────────────────────────────
  // 🔴 RASTERLEŞTİRME YOK. PDF'i piksele çevirmek yeni bir native modül
  // demek. Ölçülen pratik gerçek: e-bilet PDF'lerinin çoğunda BCBP dizesi
  // METİN KATMANINDA da duruyor (barkod onun görsel karşılığı). Önce
  // metinde arıyoruz; yoksa kullanıcıya dürüst yolu söylüyoruz.
  const dosyadan = useCallback(async () => {
    const DP = dosyaModulu();
    const FS_ = dosyaSistemi();
    if (!DP || !FS_) { setHata(t.bpNoModule); return; }
    setBusy(true); setHata("");
    const t0 = Date.now();
    let uri = null;
    try {
      const sec = await DP.getDocumentAsync({ type: ["application/pdf"], copyToCacheDirectory: true });
      if (sec.canceled || !sec.assets || !sec.assets[0]) { setBusy(false); return; }
      uri = sec.assets[0].uri;
      const ham = await FS_.readAsStringAsync(uri, { encoding: "utf8" });
      const dize = bcbpBul(ham);
      await kopyayiSil(uri);     // 🔴 okundu → kopya SİLİNDİ
      if (!dize) {
        setBusy(false);
        setSonuc({ gecti: false, kod: "pdf_metin_yok" });
        setGorunum("sonuc");
        await kaydet("file", false, "pdf_metin_yok", null, Date.now() - t0);
        return;
      }
      await dizeGeldi(dize, Date.now() - t0, "file");
    } catch (e) {
      logError("binis_karti_dosya", e);
      await kopyayiSil(uri);
      setBusy(false);
      setHata(t.bpDecodeFail);
    }
  }, [t, dizeGeldi, kaydet]);

  // ── ESNEK GÜVENCE: HER EKRANDA AÇIK ─────────────────────────────────
  // "Kullanıcıyı asla kapıda bırakma." Akış kesilmez; kayıt düşer ve
  // karşı tarafa Gökberk'in yazdığı editoryal uyarı gider (SQL 294).
  const atla = useCallback(async () => {
    setBusy(true);
    await kaydet("bypass", false, "kullanici_atladi", null, null);
    setBusy(false);
    onDogrulandi && onDogrulandi({ gecti: false, atlandi: true });
  }, [kaydet, onDogrulandi]);

  const AtlaDugmesi = (
    <TouchableOpacity
      hitSlop={TAP.slop} disabled={busy} onPress={atla}
      accessibilityRole="button" accessibilityLabel={t.bpSkip}
      style={{ alignItems: "center", paddingVertical: SP[3], marginTop: ARA[6], minHeight: TAP.minHeight, justifyContent: "center" }}>
      <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.bpSkip}</Text>
      <Text style={{ color: hak && hak.kalan === 0 ? C.goldText : C.dim, fontSize: FS.xs, marginTop: ARA[4], textAlign: "center", lineHeight: SATIR(FS.xs) }}>
        {hak == null ? t.bpSkipNote
          : hak.kalan > 0 ? String(t.bpSkipLeft).replace("{n}", String(hak.kalan))
          : t.bpSkipNoneLeft}
      </Text>
    </TouchableOpacity>
  );

  if (gorunum === "vizor") {
    return (
      <View style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0, zIndex: 60 }}>
        <Vizor t={t} onKapat={() => setGorunum("secim")}
          onDize={(ham, sure) => { setGorunum("secim"); dizeGeldi(ham, sure, "scan"); }}
          onHata={(kod) => { setGorunum("sonuc"); setSonuc({ gecti: false, kod });
                             kaydet("scan", false, kod, null, null); }} />
        <View style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: SP[4],
                       backgroundColor: C.paper }}>
          {AtlaDugmesi}
          <Btn v="ghost" sm label={t.back} a11yLabel={t.back} onPress={() => setGorunum("secim")} />
        </View>
      </View>
    );
  }

  const kay = gir.interpolate({ inputRange: [0, 1], outputRange: [320, 0] });

  return (
    <View style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0, zIndex: 60 }}>
      <TouchableOpacity activeOpacity={1} onPress={onKapat}
        accessibilityRole="button" accessibilityLabel={t.close}
        style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
                 backgroundColor: "rgba(0,0,0,0.55)" }} />
      <Animated.View style={{ position: "absolute", left: 0, right: 0, bottom: 0,
                              transform: [{ translateY: kay }] }}>
        {/* Köşe `R.xl` (22) — ürünün alt sayfa köşesi. Brief 20 diyor;
            2pt için ölçek dışına çıkmıyoruz (dosya başındaki not). */}
        <Cam stil={{ borderTopLeftRadius: R.xl + 6, borderTopRightRadius: R.xl + 6, overflow: "hidden",
                     ...ustIsik(C.kenarIsik || C.line) }}>
          <View style={{ paddingHorizontal: ARA[22], paddingTop: ARA[12], paddingBottom: ARA[30] }}>
            <View style={{ alignSelf: "center", width: 36, height: 4, borderRadius: R.full,
                           backgroundColor: C.kenarIsik || C.line, marginBottom: SP[4] }} />

            {gorunum === "sonuc" ? (
              <Sonuc t={t} sonuc={sonuc} ilan={ilan} onTekrar={() => { setSonuc(null); setGorunum("secim"); }}
                onDevam={() => onDogrulandi && onDogrulandi(sonuc)} atla={AtlaDugmesi} />
            ) : (
              <>
                {/* ══ v6.3 · PANO D (Gökberk onayı) — CAM SAYFA ══════════
                    Kaş · serif başlık · tek cümle · kilitli gizlilik satırı ·
                    iki eşit düğme (kamera | galeri). PDF yolu kaybolmadı:
                    düğmelerin altında sessiz bir bağlantı. */}
                <Text style={{ color: C.goldText, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(t.bpEyebrow)}</Text>
                <Text style={{ color: C.ink, fontSize: FS.display + 4, fontFamily: F.serifGosterim, marginTop: ARA[6],
                               lineHeight: SATIR(FS.display + 4, "serif"), letterSpacing: -0.8 }}>{t.bpTitle2}</Text>
                <Text style={{ color: C.body, fontSize: FS.sm, marginTop: ARA[8], lineHeight: SATIR(FS.sm) }}>{t.bpSub}</Text>
                <View style={{ flexDirection: "row", alignItems: "flex-start", marginTop: ARA[18] }}>
                  <Ikon ad="kilit" boy={15} renk={C.goldText} stil={{ marginRight: ARA[10], marginTop: ARA[2] }} />
                  <Text style={{ flex: 1, minWidth: 0, color: C.mut, fontSize: FS.xs, lineHeight: SATIR(FS.xs) }}>{t.bpPrivacy}</Text>
                </View>
                <View style={{ flexDirection: "row", marginTop: ARA[20] }}>
                  {kameraModulu() ? (
                    <Btn v="ghost" label={t.bpCamBtn} a11yLabel={t.bpPhysicalSub} disabled={busy}
                      onPress={() => { setHata(""); setGorunum("vizor"); }} style={{ flex: 1, marginRight: ARA[10] }} />
                  ) : null}
                  <Btn v="gold" label={t.bpGalleryBtn} a11yLabel={t.bpGallerySub} disabled={busy}
                    onPress={galeriden} style={{ flex: 1 }} />
                </View>
                <TouchableOpacity hitSlop={TAP.slop} disabled={busy} onPress={dosyadan}
                  accessibilityRole="button" accessibilityLabel={t.bpFileSub}
                  style={{ alignSelf: "center", minHeight: TAP.minHeight, justifyContent: "center", marginTop: ARA[4] }}>
                  <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "600" }}>{t.bpFileLink}</Text>
                </TouchableOpacity>
                {!!hata && <Uyari metin={hata} />}
                {AtlaDugmesi}
              </>
            )}
            {busy && <ActivityIndicator color={C.gold} style={{ marginTop: ARA[10] }} />}
          </View>
        </Cam>
      </Animated.View>
    </View>
  );
}

function Uyari({ metin }) {
  return (
    <View style={{ flexDirection: "row", alignItems: "flex-start", backgroundColor: C.hataBg,
                   borderWidth: 1, borderColor: C.hataLine, borderRadius: R.sm,
                   padding: SP[3], marginTop: ARA[12] }}>
      <Ikon ad="uyari" boy={FS.base} renk={C.redInk} stil={{ marginRight: ARA[8], marginTop: ARA[2] }} />
      <Text style={{ flex: 1, minWidth: 0, color: C.redInk, fontSize: FS.sm,
                     lineHeight: SATIR(FS.sm) }}>{metin}</Text>
    </View>
  );
}

// ── Sonuç ekranı ──────────────────────────────────────────────────────
// ⚠️ HER DALDA BİR SONRAKİ ADIM VAR. Çıkmaz sokak yok: başarısızlıkta
// bile "tekrar dene" ve "atla" duruyor.
function Sonuc({ t, sonuc, ilan, onTekrar, onDevam, atla }) {
  const gecti = sonuc && sonuc.gecti;
  const kod = sonuc && sonuc.kod;
  const coz = sonuc && sonuc.coz;
  const sert = (sonuc && sonuc.uyum && sonuc.uyum.sert) || [];
  const yumusak = (sonuc && sonuc.uyum && sonuc.uyum.yumusak) || [];

  // Sunucunun kodu yoksa ayrıştırıcının kodunu kullanıcı cümlesine çevir
  const cumle = gecti ? t.bpOk : (t["e_" + kod] || t.bpFailGeneric);
  const ayrinti = sert.map((x) => {
    if (x.kod === "havalimani_uyusmuyor") {
      return String(t.bpAirportMismatch || "").replace("{bilet}", x.bilet).replace("{ilan}", x.ilan);
    }
    if (x.kod === "tarih_uyusmuyor") {
      return String(t.bpDateMismatch || "").replace("{bilet}", x.bilet).replace("{ilan}", x.ilan);
    }
    return null;
  }).filter(Boolean);
  // Okunamadı mı (barkod yok) yoksa okundu ama uyuşmadı mı? İkisi ayrı cümle.
  const okunamadi = !gecti && !coz;

  if (gecti) {
    // ══ v6.3 · PANO D — OKUNAN | SEYAHATİN yan yana; eşleşme tek bakışta.
    return (
      <>
        <Text style={{ color: C.goldText, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(t.bpOkEyebrow)}</Text>
        <Text style={{ color: C.ink, fontSize: FS.display + 4, fontFamily: F.serifGosterim, marginTop: ARA[6],
                       lineHeight: SATIR(FS.display + 4, "serif"), letterSpacing: -0.8 }}>{t.bpOkTitle}</Text>
        {!!coz && (
          <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between",
                         marginTop: ARA[18], padding: SP[4], borderRadius: R.lg,
                         backgroundColor: C.surfaceAlt, ...ustIsik(C.parlama || C.line) }}>
            <View>
              <Text style={{ color: C.mut, fontSize: FS.micro, letterSpacing: 1.2 }}>{BUYUK(t.bpRead)}</Text>
              <Text style={{ color: C.ink, fontFamily: MONO[500], fontSize: FS.display + 4, marginTop: ARA[4] }}>{coz.kalkis}</Text>
            </View>
            <View style={{ alignItems: "flex-end" }}>
              <Text style={{ color: C.mut, fontSize: FS.micro, letterSpacing: 1.2 }}>{BUYUK(t.bpYourTrip)}</Text>
              <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[6] }}>
                <Ikon ad="tamam" boy={13} renk={C.ink} stil={{ marginRight: ARA[6] }} />
                <Text style={{ color: C.ink, fontFamily: MONO[500], fontSize: FS.sm }}>
                  {(ilan && ilan.airport_code) || coz.kalkis} · {t.bpMatched}
                </Text>
              </View>
            </View>
          </View>
        )}
        {!!coz && (
          <Text style={{ color: C.mut, fontFamily: MONO[500], fontSize: FS.xs, marginTop: ARA[10], letterSpacing: 0.4 }}>
            {BUYUK([coz.ucusKodu, coz.ucusTarihi].filter(Boolean).join(" · "))}
          </Text>
        )}
        {/* ⚠️ Kabin YALNIZ BİLGİ: harf→sınıf eşlemesi havayoluna göre değişir. */}
        {!!(coz && coz.kabinKodu) && (
          <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[4] }}>
            {String(t.bpCabin || "").replace("{k}", coz.kabinKodu)}
          </Text>
        )}
        {yumusak.map((y, i) => (
          <Text key={"y" + i} style={{ color: C.goldText, fontSize: FS.xs, marginTop: ARA[8], lineHeight: SATIR(FS.xs) }}>
            {y.kod === "ad_uyusmuyor" ? t.bpNameSoft : t.bpFlightSoft}
          </Text>
        ))}
        <View style={{ marginTop: ARA[20] }}>
          <Btn v="gold" label={t.startSessionBtn} a11yLabel={t.startSessionBtn} onPress={onDevam} />
        </View>
      </>
    );
  }

  // ══ v6.3 · PANO E (Gökberk onayı) — ZARAFET: suçlamadan, numaralı sebep
  // satırları (kutu yok, 1 px ışık çizgisi), birincil "Tekrar dene",
  // altında atlama yolu ve kaydının dürüst notu. Çıkmaz sokak yok.
  const satirlar = okunamadi
    ? [cumle, t.bpTipGlare, t.bpTipScreen]
    : [cumle, ...ayrinti];
  return (
    <>
      <Text style={{ color: C.goldText, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>
        {BUYUK(okunamadi ? t.bpFailEyebrow : t.bpMismatchEyebrow)}
      </Text>
      <Text style={{ color: C.ink, fontSize: FS.display + 2, fontFamily: F.serifGosterim, marginTop: ARA[6],
                     lineHeight: SATIR(FS.display + 2, "serif"), letterSpacing: -0.8 }}>
        {okunamadi ? t.bpFailTitle2 : t.bpFailTitle}
      </Text>
      <View style={{ marginTop: ARA[14] }}>
        {satirlar.filter(Boolean).map((m, i) => (
          <View key={i} style={{ flexDirection: "row", paddingVertical: ARA[10],
                                 borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: C.kenarIsik || C.line }}>
            <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, color: C.goldText, width: 24, marginTop: ARA[2] }}>
              {String(i + 1).padStart(2, "0")}
            </Text>
            <Text style={{ flex: 1, minWidth: 0, color: C.body, fontSize: FS.sm, lineHeight: SATIR(FS.sm) }}>{m}</Text>
          </View>
        ))}
      </View>
      <View style={{ marginTop: ARA[14] }}>
        <Btn v="gold" label={t.bpRetry} a11yLabel={t.bpRetry} onPress={onTekrar} />
      </View>
      {atla}
    </>
  );
}

export default BinisKartiPanel;
