import React, { useEffect, useState, useCallback, useMemo, useRef } from "react";
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView, ActivityIndicator, KeyboardAvoidingView, Platform, BackHandler, Image, AppState, Modal, Dimensions, Animated, Easing, PanResponder } from "react-native";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { ErrorBoundary } from "./src/ErrorBoundary";
// v2.96: `logError` artık App.js'te de import ediliyor — dil ve huni
// çağrılarının hataları sessiz kalmasın (v2.78'de denetim eksikliği yakalamıştı).
import { supabase, setAppVersion, logError } from "./src/supabase";
import { kuyrugaAkit, kuyrugaBak, kuyrukDinle } from "./src/cevrimdisi";
import { signInWithGoogle, signInWithApple, appleAvailable, needsOnboarding, RESET_REDIRECT } from "./src/social";
import * as ExpoLinking from "expo-linking";
import Constants from "expo-constants";
import { applyAuthUrl, isAuthUrl } from "./src/deeplink";
import { D, getLang, setLang, badgeLabel, mapErr, BUYUK, dilAyarla, shortName } from "./src/i18n";
import { Hdr, BrandBar, TOPPAD, Sayfa, Tanecik, FotoSahne, FotoBant, Btn, Secim, Cip, KararCipi, CuzdanSeridi, MarkaYukleyici, AkanBaslik, useDaralanBant } from "./src/ui";
import { LegalDoc, Trips, Hosting, Discovery, RequestsPanel, Chat, VerifyPhone, KimlikDogrula, Profile, Notifications, useUnread, Meet, Marketplace, Plans, PublicProfile, CompanionChat, Safety, TrustVisual, SessionHistory, Referral, HostAccessSource, HostBroadcast, LiveStatus, ActionNeeded, RateReminder, HikayeDaveti, MyQuestions, EditAvailability, EditTrip, Wallet, LoungeRadarCard, HostApply, Settings, EditProfile, AddVisit, HostAvailability, ReportUser, Campaigns, HomeConnections, FindHostCard, LoungeGuide, Degerlendirmeler, HostDaveti, SakinGun, UlasilabilirlikKarti, YasOnayi, AkisSeridi } from "./src/screens";
// v2.87 (madde 7): ana sayfadaki ilan bloğu da katlanır oldu — ikinci bir
// katlanır bileşen yazmak yerine Pickers.js'teki tek Katlanir kullanılıyor.
import { Katlanir } from "./src/Pickers";
import { katalogUnut } from "./src/katalog";
import { Ikon, IkonMetin, BilgiRozeti, ikonFontuHazirla, ikonFontuDurumu } from "./src/ikon";
// 🔴 30 Ağu · Gece sistemi — cüzdan şeridindeki sayılar mono ailede.
import { MONO } from "./src/typography";
import { pushDurumOku } from "./src/push";
import { useRecognitionMoment } from "./src/HostWallet";
import MomentScreen from "./src/MomentScreen";
// v2.73 — GÖVDE YAZISI ARTIK BİZİM. Tek çağrı; ayrıntısı src/typography.js.
// Buraya, ilk render'dan ÖNCE koyuldu: sonrasında çağrılsaydı ilk ekran
// sistem fontuyla çizilip sonra zıplardı.
import { sansUygula } from "./src/typography";
import { runtimeYukle, runtimeDinle, runtimeTazele, sozluk, bayrak } from "./src/runtime";
sansUygula();

// TEMA: tek kaynak src/theme.js — MVP v15 paletinin birebir kopyasi.
// Daha once C uc ayri yerde (App.js, screens.js, theme.js) FARKLI degerlerle
// tanimliydi; mor/yesil/amber hic yoktu, teal yanlis tondaydi.
// v2.78 — TAP: App.js''te hitSlop HİÇ kullanılmıyordu (src/screens.js''te
// 134 kez). Sekme çubuğu, zil ve dil düğmesi 16-18pt dokunma alanına
// sahipti; `theme.js` bunun için `TAP.slop`u zaten yazmıştı.
import { ARA, ELEV, ACCENT, C, F, FS, R, SP, TAP, temaDinle, temaModu, temaYenidenKur, SATIR} from "./src/theme";
import { temaTercihYukle } from "./src/tema_tercih";
import { sadeGorunumYukle } from "./src/atmosfer";
import { yerelGun } from "./src/zaman";

// 🔴 v1.77'de bu satır v1.62'den beri GÜNCELLENMEMİŞTİ — hata kayıtları
// 15 sürüm boyunca "1.62.0" olarak düşüyordu. O zaman değeri elle
// düzelttim; v2.46'da yine "2.45.0"da kalmış halde buldum.
//
// İki kez ısıran bir şeyi üçüncü kez elle düzeltmek çözüm değil.
// Sürüm artık app.json'dan OKUNUYOR — tek kaynak, ve app.json'u zaten
// her build'de güncelliyoruz.
//
// Yedek değer neden duruyor: render_check'teki expo taklidi her şeye
// null döner, orada Constants.expoConfig yoktur. Yedek olmasa testler
// sürümsüz koşar; olması test ortamında zararsız, üründe erişilmez.
setAppVersion(Constants?.expoConfig?.version || "2.46.0");

function AppInner() {
  const [lang, setLangState] = useState("tr");
  // ══════════════════════════════════════════════════════════════════
  // 🔴 İKON FONTU KAPISI (30 Ağustos)
  //
  // `@expo/vector-icons` fontu YÜKLENENE KADAR her ikonu boş `<Text/>`
  // olarak çizer ve `loadAsync` bir kez reddederse bunu SONSUZA KADAR
  // yapar (bkz. src/ikon.js başlığı). Ekranların tamamı ikonsuz kaldı.
  //
  // Burada ilk çizimden ÖNCE yüklüyoruz: `Font.isLoaded("Ionicons")`
  // artık kütüphanenin kurucusunda `true` döner, boş dal ölür.
  // `false` dönerse ikon katmanı görünür yer tutucuya düşer — sessiz
  // kalmaz.
  //
  // ⚠️ Kapı UYGULAMAYI BEKLETMİYOR. Fontu beklemek için beyaz ekran
  // göstermek, ikon eksikliğinden daha kötü bir ilk izlenim olurdu;
  // ikonlar font geldiğinde kendiliğinden çizilir.
  // ══════════════════════════════════════════════════════════════════
  const [ikonFontu, setIkonFontu] = useState(ikonFontuDurumu() === "hazir");
  useEffect(() => {
    let canli = true;
    ikonFontuHazirla((kod, e) => logError(kod, e))
      .then((ok) => { if (canli) setIkonFontu(!!ok); });
    return () => { canli = false; };
  }, []);
  // v2.77 — sunucudan gelen bayrak/metin katmanı. `rtSurum` yalnızca
  // yeniden çizim tetiklemek için var; değerin kendisi runtime.js'te.
  const [rtSurum, setRtSurum] = useState(0);
  const [screen, setScreen] = useState("boot"); // boot | onboarding | splash | login | register | home
  const [session, setSession] = useState(null);
  const [recovery, setRecovery] = useState(false);   // v1.83: şifre sıfırlama akışı
  const [dlErr, setDlErr] = useState("");            // v1.84: derin bağlantı hatası (süresi dolmuş vb.)
  // 🔴 `D[lang]` YERİNE `sozluk(lang)`. Aradaki fark: BO'dan yapılan
  // metin düzeltmesi (SQL 212 · i18n_overrides) derli sözlüğün üstüne
  // biniyor. `D[lang]` yazsaydık /manage/i18n ekranının "anında
  // yansır" sözü yine tutulmamış olurdu.
  const t = useMemo(() => sozluk(lang), [lang, rtSurum]);

  useEffect(() => {
    const cik = runtimeDinle(() => setRtSurum(v => v + 1));
    runtimeYukle();
    return cik;
  }, []);

  // ── GÖRÜNÜM TERCİHLERİ ──────────────────────────────────────────
  // 🔴 SIRA MESELESİ, ÖLÇÜM MESELESİ DEĞİL.
  // Tema, İLK KARE ÇİZİLMEDEN uygulanmalı. Bir kare bile açık temada
  // çizilirse kullanıcı beyaz bir flaş görüp koyuya "atlar" — koyu tema
  // eklemenin en sık görülen kusuru budur. Uygulama zaten `screen:
  // "boot"` durumunda hiçbir şey çizmiyor; tercih o pencerede yükleniyor.
  //
  // `sadeGorunumYukle` de buraya girdi: yazılmıştı ama HİÇ ÇAĞRILMIYORDU
  // — yani kullanıcı sade görünümü açsa bile uygulama her açılışta
  // unutuyordu.
  const [temaSurum, setTemaSurum] = useState(0);
  useEffect(() => {
    const cik = temaDinle(() => setTemaSurum(v => v + 1));
    temaTercihYukle();
    sadeGorunumYukle();
    return cik;
  }, []);

  useEffect(() => {
    (async () => {
      // ══════════════════════════════════════════════════════════════
      // 🔴 v3.4 — İLK KARE ÜÇ SIRALI BEKLEMENİN ARKASINDAYDI.
      //
      // Gökberk (28 Ağu): "APP tarafında da performans artışı yapmamız
      // lazım. Bir tık yavaş şu an."
      //
      // ÖLÇÜM (kod okunarak, tahmin değil): ilk piksel çizilmeden önce
      // sırayla ÜÇ bekleme vardı ve BİRİ AĞDI:
      //     1. await getLang()                        → AsyncStorage
      //     2. await supabase.auth.getSession()       → AĞ (jeton yenileme)
      //     3. await AsyncStorage.getItem(recovery)   → AsyncStorage
      // Üçü de birbirinden BAĞIMSIZ. Yani toplam süre üçünün TOPLAMI
      // olmak zorunda değildi — en YAVAŞININ süresi yetiyordu.
      //
      // 🆕 SINIF: "BİRBİRİNİ BEKLEMEYEN İŞLERİ SIRAYA DİZERSEN, AÇILIŞ
      // SÜRESİ EN YAVAŞ İŞİN DEĞİL HEPSİNİN TOPLAMI OLUR — VE KULLANICI
      // O TOPLAMA BAKAR."
      //
      // `Promise.all` ile üçü aynı anda başlıyor. Sıra korunuyor, bedel
      // birleşiyor.
      const [_lang, { data }, _recoveryRaw] = await Promise.all([
        getLang(),
        supabase.auth.getSession(),
        AsyncStorage.getItem("ll_recovery_pending").catch(() => null),
      ]);
      setLangState(_lang);
      const t0 = (D && D[_lang]) || {};   // dil yuklenmeden once de metin lazim

      // 🔴 v2.41 — YARIM KALMIS KURTARMA OTURUMUNU TEMIZLE.
      // Kullanici sifre sifirlama baglantisina tiklayip yeni sifre
      // BELIRLEMEDEN cikmissa, cihazda sinirli yetkili bir oturum kalir.
      // Uygulama onu normal oturum sanip ana ekrana alir; sonra her
      // islem sessizce basarisiz olur ve kullanici "sifrem calismiyor"
      // der. Oysa sifresi gayet gecerlidir.
      //
      // Sessizce cikis yaptirip normal girise yonlendiriyoruz. Kullanici
      // eski sifresiyle girer — cunku o sifre HIC SILINMEDI.
      const pendingRecovery = _recoveryRaw === "1";
      if (pendingRecovery && data.session) {
        try { await supabase.auth.signOut(); } catch (e) {}
        try { await AsyncStorage.removeItem("ll_recovery_pending"); } catch (e) {}
        setSession(null);
        setScreen("login");
        setDlErr(t0.recoveryAbandoned ||
          "Şifre sıfırlamayı yarıda bıraktın. Eski şifren hâlâ geçerli — onunla giriş yapabilirsin.");
        return;
      }

      setSession(data.session);
      if (data.session) { pushDurumOku(); }   // DURUM OKUR — pencere ACMAZ (v2.98/G7)
      if (data.session) { setScreen("home"); }
      else {
        // 🔵 26 AĞUSTOS — burada `ll_onb` OKUNUYOR ama sonucu HİÇ
        // KULLANILMIYORDU (ölü değişken). Kararı Splash'teki "Başla"
        // düğmesi zaten kendisi veriyor; iki yerde okumak, ikisinin
        // ayrışması demektir.
        setScreen("splash"); // tanıtım "Başla"ya bağlı (#3 — MVP akışı)
      }
      // 🔴 v1.81 (Gokberk: "hatalı şifrede uyarı yok, en başa dönüyorum"):
      // giriş denemesinden ÖNCE signOut çağrılıyordu; bu SIGNED_OUT olayını
      // tetikliyor, aşağıdaki satır ekranı "splash"e atıyor ve giriş formu
      // (dolayısıyla hata mesajı) yok oluyordu. Artık oturum kapanması
      // ekranı YALNIZCA kullanıcı gerçekten giriş yapmışken sıfırlar;
      // login/register ekranındayken olduğu yerde bırakır.
      supabase.auth.onAuthStateChange((_e, s) => {
        // v1.83: sıfırlama bağlantısından gelindiğinde şifre belirleme ekranı
        if (_e === "PASSWORD_RECOVERY") {
          setRecovery(true);
          // 🔴 v2.41 — YARIM BIRAKILAN SIFIRLAMA GIRISI KILITLIYORDU.
          //
          // Gokberk sifresini unuttum'a basmis, maildeki baglantiya
          // tiklamis, YENI SIFRE BELIRLEMEDEN cikmisti. Sonra normal
          // giris yapamadi.
          //
          // Sifre SILINMIYOR (Supabase resetPasswordForEmail eski sifreyi
          // gecerli birakir) — sorun baska: o baglantiya tiklayinca
          // Supabase bir KURTARMA OTURUMU aciyor. O oturum sinirli
          // yetkilidir; yalniz sifre degistirmeye izin verir.
          //
          // Kullanici sifre belirlemeden cikinca oturum CIHAZDA KALIYOR.
          // Uygulama bir dahaki acilista "oturum var" goruyor, ana ekrana
          // aliyor, ama her islem sessizce basarisiz oluyor. Kullanici
          // acisindan bu "sifrem calismiyor" gibi gorunuyor.
          //
          // Isaretliyoruz; tamamlanmadan uygulama kapanirsa acilista
          // temizlenecek (asagidaki bootstrap kontrolu).
          try { AsyncStorage.setItem("ll_recovery_pending", "1"); } catch (e) {}
        }
        setSession(s);
        // 🔴 v2.16 — PUSH KAYDI BURADA YAPILMALIYDI, HIC YAPILMIYORDU.
        // src/push.js yazilmisti (izin iste, Expo token al, kaydet) ama
        // HICBIR YERDEN CAGRILMIYORDU. push_tokens tablosu bostu, yani
        // sunucu bildirim gondermek istese bile ADRES yoktu.
        // Oturum acilir acilmaz cagiriyoruz; icinde try/catch var, izin
        // reddedilse bile akis bozulmaz.
        if (s) { pushDurumOku(); }
        setScreen(prev => s ? "home" : (prev === "login" || prev === "register" ? prev : "splash"));
      });
    })();
  }, []);

  // ============================================================
  // 🔴 v1.84 — DERİN BAĞLANTI (şifre sıfırlama / e-posta doğrulama / sosyal dönüş)
  //
  // v1.83'te `PASSWORD_RECOVERY` olayı dinleniyordu ama o olay React
  // Native'de HİÇ GELMEZ: supabase-js adresten oturum okumayı yalnız
  // tarayıcıda yapar (detectSessionInUrl — bizde bilinçli olarak false).
  // Mobilde gelen adresi yakalamak uygulamanın işidir. Bu blok eksikti,
  // bu yüzden bağlantı uygulamayı açsa bile hiçbir şey olmuyordu.
  //
  // İki giriş kapısı var ve İKİSİ DE gerekli:
  //   getInitialURL()  → uygulama KAPALIYKEN bağlantıya tıklanırsa
  //   addEventListener → uygulama AÇIKKEN/arka plandayken tıklanırsa
  // ============================================================
  const handleDeepLink = useCallback(async (url) => {
    if (!url || !isAuthUrl(url)) return;
    const r = await applyAuthUrl(url, D[lang]);
    if (r.ok && (r.type === "recovery" || String(url).indexOf("reset-password") >= 0)) {
      setDlErr("");
      setRecovery(true);
    } else if (!r.ok && r.message) {
      setDlErr(r.message);
    }
  }, [lang]);

  useEffect(() => {
    let sub = null;
    (async () => {
      try {
        // Soğuk açılış: uygulama bağlantıyla başlatıldıysa
        if (typeof ExpoLinking.getInitialURL === "function") {
          const u = await ExpoLinking.getInitialURL();
          if (u) await handleDeepLink(u);
        }
      } catch (e) { /* derin bağlantı okunamadı: normal akışı BOZMA */ }
    })();
    try {
      if (typeof ExpoLinking.addEventListener === "function") {
        sub = ExpoLinking.addEventListener("url", (ev) => { handleDeepLink(ev && ev.url); });
      }
    } catch (e) { /* yut */ }
    return () => { try { if (sub && typeof sub.remove === "function") sub.remove(); } catch (e) {} };
  }, [handleDeepLink]);

  // ============================================================
  // 🔴 v1.71 — "SÜREKLİ İNTERNET BAĞLANTISI YOK" HATASININ KÖK NEDENİ
  //
  // Eski sürüm uygulamanın TAMAMINI tek bir yoklamaya bağlıyordu:
  // açılışta BİR KEZ /auth/v1/health'e istek atılıyor, o istek herhangi
  // bir sebeple düşerse (soğuk açılışta DNS henüz hazır değil, mobil veri
  // uyanıyor, VPN, 5 sn zaman aşımı, endpoint'in kimlik doğrulama isteyen
  // bir cevaba dönmesi) `online=false` yapılıp ekran KİLİTLENİYORDU.
  // Tek deneme + geri dönüşsüz kilit = kullanıcı gerçekte çevrimiçiyken
  // uygulamaya hiç giremiyor. Yaşanan buydu.
  //
  // Yeni davranış:
  //  • Yoklama GERÇEK veri yolunu kullanır (Supabase REST + apikey) —
  //    sağlık endpoint'i değil; yani "uygulamanın ihtiyacı olan şey"
  //    çalışıyor mu onu ölçer.
  //  • 3 deneme + artan bekleme; ancak hepsi düşerse çevrimdışı sayılır.
  //  • Çevrimdışı artık UYGULAMAYI KİLİTLEMEZ: üstte kapatılabilir bir
  //    şerit çıkar, kullanıcı gezinmeye devam eder (ekranlar kendi
  //    yükleme/boş durumlarını gösterir).
  //  • Uygulama öne geldiğinde (AppState) sessizce yeniden dener.
  // ============================================================
  const [online, setOnline] = useState(true);
  const [netBusy, setNetBusy] = useState(false);
  // 13 Eylül · v5.9.0 — kuyrukta bekleyen mesaj sayısı. Şeridin ikinci
  // satırı bunu şampanya saat ikonuyla gösteriyor; kullanıcı "yazdığım
  // kayboldu mu?" diye sormuyor.
  const [kuyrukSayisi, setKuyrukSayisi] = useState(0);
  useEffect(() => {
    let canli = true;
    const tazele = (l) => { if (canli) setKuyrukSayisi((l || []).filter((x) => x.durum !== "dustu").length); };
    const cik = kuyrukDinle(tazele);
    kuyrugaBak().then(tazele);
    return () => { canli = false; cik(); };
  }, []);
  const checkNet = useCallback(async (attempts = 3) => {
    setNetBusy(true);
    let ok = false;
    for (let i = 0; i < attempts && !ok; i++) {
      try {
        const { error } = await supabase.from("airports").select("code").limit(1);
        ok = !error;
      } catch (e) { ok = false; }
      if (!ok && i < attempts - 1) await new Promise(r => setTimeout(r, 1200 * (i + 1)));
    }
    setOnline(ok);
    setNetBusy(false);
    // 🔴 AĞ DÖNDÜĞÜNDE KUYRUK KENDİLİĞİNDEN GİDER. Kullanıcının "gönder"e
    // yeniden basması gerekmiyor — zaten bir kez bastı, sözümüz o.
    if (ok) kuyrugaAkit().catch(() => {});
    return ok;
  }, []);
  useEffect(() => { checkNet(); }, [checkNet]);
  // 🔴 v1.77: SQL 080'in expire_stale_sessions() fonksiyonu YAZILMIŞ ama
  // HİÇBİR YERDEN ÇAĞRILMIYORDU — yani buluşma saati geçmiş, hiç başlatılmamış
  // kabuller sonsuza kadar "accepted" kalıyor, slot dolu görünüyor ve misafirin
  // kredisi iade edilmiyordu. Ücretsiz katmanda zamanlanmış görev olmadığı için
  // uygulama açılışında (ve öne gelişte) bir kez çağrılır; idempotent ve ucuz.
  useEffect(() => {
    if (!session?.user?.id) return;
    // 🔴 v1.80 KÖK NEDEN (beyaz ekran, "rpc(...).catch is not a function"):
    // supabase-js'in rpc() dönüşü bir Promise DEĞİL, PostgrestFilterBuilder —
    // "thenable"dır (then vardır) ama .catch YOKTUR. .catch çağırmak anında
    // TypeError fırlatıyor, hata App bileşeninin render'ında patlıyor ve
    // uygulama beyaz ekranda kalıyordu. Doğrusu: await + try/catch.
    (async () => {
      try { await supabase.rpc("expire_stale_sessions"); } catch (e) {}
      // 🔴 v2.80 — AYLIK PLAN KREDİSİ (SQL 225).
      // `plan_catalog.monthly_credits` (Yolcu 2 · Sık Uçan 6 · Kâhya 12)
      // bugüne kadar HİÇ dağıtılmamıştı: `monthly_topup` ayarı kapalıydı
      // ve zaten okuyanı yoktu. Yani 249 ₺ ödeyen Kâhya kullanıcısı ayda
      // 12 kredi bekleyip hiç almıyordu — eksik özellik değil, tutulmamış
      // söz.
      //
      // Gizli bir sarmalayıcıya değil AÇIK bir çağrıya bağladım: app
      // bakiyeyi RPC'den değil doğrudan `credit_ledger` tablosundan
      // okuyor, sarmalanacak bir fonksiyon yok. Fonksiyon idempotent
      // (`reason = 'plan_monthly:<YYYY-MM>'`), kaç kez çağrıldığı
      // önemsiz. Cron kurulursa daha erken çalışır; kurulmazsa kullanıcı
      // uygulamayı her açtığında yerine oturur.
      try { await supabase.rpc("plan_kredisi_yerlestir"); } catch (e) {}
    })();
  }, [session?.user?.id]);
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 v3.7 — JETON YENİLEME ARKA PLANDA DURUYORDU.
  //
  // Gökberk (28 Ağustos): "token kontrolleri konusunda emin olmanı
  // istiyorum. Bi sıkıntı yaşamayalım."
  //
  // Ölçtüm ve bir eksik buldum. `supabase.js`te `autoRefreshToken: true`
  // yazıyor ve doğru — ama React Native'de bu bir `setInterval`dır.
  // Uygulama arka plana alındığında iOS ve Android bu zamanlayıcıyı
  // KISITLAR ya da tamamen durdurur. Kullanıcı uygulamayı bir saat sonra
  // açtığında erişim jetonu ÇOKTAN ölmüştür ve ilk istekler 401 alır.
  //
  // Supabase'in React Native rehberi bu yüzden `AppState`e bağlanmasını
  // AÇIKÇA söylüyor; bizde o bağ yoktu. Belirtisi tam da "ara ara" olur:
  // telefonu cebe koyup dönenler görür, sürekli açık tutanlar görmez —
  // yani en zor yakalanan hata sınıfı.
  //
  // 🆕 SINIF: "BİR ZAMANLAYICIYA DAYANAN YENİLEME, UYGULAMANIN UYUDUĞU
  // SÜREYİ HESABA KATMIYORSA, ÇALIŞTIĞI SÜRECE ÇALIŞIR — VE HATA HEP
  // GERİ DÖNÜŞTE ÇIKAR."
  //
  // `startAutoRefresh()` çağrısı ayrıca ANINDA bir yenileme dener; yani
  // öne gelen uygulama daha ilk sorgusundan önce taze jetona kavuşur.
  useEffect(() => {
    const sub = AppState.addEventListener("change", st => {
      if (st === "active") {
        checkNet(2);
        runtimeTazele();
        try { supabase.auth.startAutoRefresh(); } catch (e) {}
      } else {
        // Arka planda zamanlayıcıyı biz durduruyoruz: işletim sistemi
        // zaten kısıtlayacak, boşuna pil yakmasın.
        try { supabase.auth.stopAutoRefresh(); } catch (e) {}
      }
    });
    // İlk montajda da başlat — uygulama zaten önde açılıyor.
    try { supabase.auth.startAutoRefresh(); } catch (e) {}
    return () => {
      sub.remove();
      try { supabase.auth.stopAutoRefresh(); } catch (e) {}
    };
  }, [checkNet]);

  // 🔴 v2.96 (eleştiri E4) — DİL ARTIK SUNUCUYA DA SÖYLENİYOR.
  // Kural motorunun cümleleri (ürünün en önemli tek cümlesi: "kapıda ne
  // olacak") sunucuda üretiliyor ve şimdiye kadar YALNIZ TÜRKÇEYDİ.
  // SQL 238'in kendi notu bunu yazıyordu: "Ingilizce kullanici hala
  // Ingilizce baslik altinda Turkce govde goruyor."
  // SQL 250 bir dil katmanı kurdu (TR çıktının BAYT BAYT aynı kaldığı
  // kanıtlanarak). Tercih `profiles.dil`de yaşıyor — bir istekten
  // diğerine taşınması gereken şey bir değişken değil, bir kolondur.
  // Sunucuya yazamazsak dil YİNE DE değişir (ekran metinleri paketten
  // geliyor); yalnız kural cümleleri Türkçe kalır. Sessizce yutmuyoruz.
  const dilSunucuyaYaz = useCallback(async (l) => {
    try {
      const { error } = await supabase.rpc("dili_ayarla", { p_lang: l });
      if (error) logError("dili_ayarla", error);
    } catch (e) { /* ağ yoksa ekran dili yine değişsin */ }
  }, []);
  async function applyLang(l) {
    dilAyarla(l);   // v2.99: BUYUK() etkin dile gore calissin
    await setLang(l);
    setLangState(l);
    dilSunucuyaYaz(l);
  }
  async function toggleLang() {
    const next = lang === "tr" ? "en" : "tr";
    await setLang(next);
    setLangState(next);
    dilSunucuyaYaz(next);
  }

  // ============================================================
  // DONANIM GERI TUSU — KOK NEDEN DUZELTMESI (v1.25)
  // Uygulamada HIC BackHandler yoktu: Android varsayilani calisiyor,
  // geri tusu her ekranda uygulamayi KAPATIYORDU. Bu handler auth
  // katmanini yonetir; Main icindeki handler (daha sonra mount oldugu
  // icin ONCE calisir) oturum ici ekranlari yonetir.
  // ============================================================
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      if (screen === "login" || screen === "register" || screen === "guide") { setScreen("splash"); return true; }
      return false; // splash/onboarding: uygulamadan cikmak normal
    });
    return () => h.remove();
  }, [screen]);

  // 🔴 DURUM ÇUBUĞU DA TEMANIN PARÇASI — VE SABİT YAZILMIŞTI.
  // `<StatusBar style="dark" />` koyu temada koyu ikon demek: koyu
  // zeminde koyu saat, koyu pil. Kullanıcı "uygulama bozuk" der,
  // "durum çubuğu" demez. Tema değişkeni tam da bunun için okunuyor.
  const koyuMu = useMemo(() => temaModu() === "koyu", [temaSurum]);

  // 🔴 v3.4 — AÇILIŞ GÖSTERGESİ DE MARKA. Kullanıcının uygulamada gördüğü
  // İLK hareket bu; jenerik bir çember, marka anını harcamaktır.
  if (screen === "boot") return <View style={[st.center,{flex:1,backgroundColor:C.paper}]}><MarkaYukleyici boy={52} /></View>;

  return (
    <Sayfa ufuk={screen === "login" || screen === "register" ? 44 : screen === "onboarding" ? 40 : 56}>
      <StatusBar style={koyuMu ? "light" : "dark"} />
      {/* v1.71: engelleyen tam ekran yerine KAPATILABİLİR şerit */}
      {!online && <OfflineBanner t={t} onRetry={() => checkNet(3)} busy={netBusy} kuyruk={kuyrukSayisi} />}
      {/* v1.84: süresi dolmuş / bozuk sıfırlama bağlantısı sessizce yutulmasın */}
      {!!dlErr && !recovery && (
        <View style={{ position: "absolute", top: TOPPAD, left: 12, right: 12, zIndex: 90,
                       backgroundColor: C.hataBg, borderRadius: R.xs, padding: SP[3],
                       borderWidth: 1, borderColor: C.hataLine }}>
          <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 19 }}>{dlErr}</Text>
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setDlErr("")} style={{ marginTop: ARA[6] }}>
            <Text style={{ color: C.redInk, fontWeight: "700", fontSize: FS.sm }}>{t.close || "Kapat"}</Text>
          </TouchableOpacity>
        </View>
      )}
      {recovery && <SetNewPassword t={t} onDone={async () => {
        // Tamamlandi: bayragi kaldir, artik normal oturum.
        try { await AsyncStorage.removeItem("ll_recovery_pending"); } catch (e) {}
        setRecovery(false);
      }} />}
      {screen === "onboarding" && <Onboarding t={t} onDone={async () => { try { await AsyncStorage.setItem("ll_onb","1"); } catch {}; setScreen("register"); }} />}
      {screen === "splash" && <Splash t={t} go={setScreen} lang={lang} toggleLang={toggleLang} />}
      {/* 🔴 v3.6 — SALON REHBERİ ARTIK GİRİŞ YAPMADAN AÇILIYOR.
          Ekranın kendi alt metni "Kayıt gerekmez" diyordu ve sunucu
          tarafı da öyle kurulmuştu (`guide_*` RPC'leri `anon`a açık,
          SQL 143/147/154) — ama arayüzde ulaşılabilir tek yol giriş
          yapmış bir kullanıcının 2. sekmesiydi.
          Boş bir pazaryerinde arz sıfırken bile bir SORUYA cevap veren
          tek ekran bu. Değer önce, kayıt sonra. */}
      {screen === "guide" && (
        <LoungeGuide t={t} girisYok
          onBack={() => setScreen("splash")}
          onKayit={() => setScreen("register")} />
      )}
      {screen === "login" && <Auth mode="login" t={t} go={setScreen} lang={lang} toggleLang={toggleLang} />}
      {screen === "register" && <Auth mode="register" t={t} go={setScreen} lang={lang} toggleLang={toggleLang} />}
      {screen === "home" && <Main t={t} lang={lang} toggleLang={toggleLang} setLangGlobal={applyLang} session={session} />}
    </Sayfa>
  );
}



// ============================================================
// v1.74 · SOSYAL GİRİŞ SONRASI TAMAMLAMA
//
// Sosyal kimlikle gelen kullanıcı kayıt sihirbazını atlar; rol seçimi ve
// KVKK sözleşme onayları ALINMAMIŞ olur. Bunlar olmadan uygulamayı
// kullandırmak hem ürün (rolü olmayan kullanıcı hangi ekranı görecek?)
// hem hukuk (onaysız işleme) açısından yanlış. Bu ekran o boşluğu kapatır
// ve KAPATILAMAZ — tek çıkış "Çıkış Yap".
// ============================================================
export function CompleteOnboarding({ t, session, onDone, onLogout }) {
  const [role, setRole] = useState(null);
  const [gender, setGender] = useState(null);
  const [consents, setConsents] = useState([false, false, false, false, false, false]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [legal, setLegal] = useState(null);
  const all = consents.every(Boolean);
  const uid = session?.user?.id;

  async function submit() {
    if (!role || !all) return;
    setBusy(true); setErr("");
    try {
      // 🔴 v2.89 — ROL ARTIK TEK KAPIDAN GEÇİYOR (SQL 232).
      // Eskiden `users.role` istemciye açıktı ve buradan doğrudan
      // yazılıyordu. Aynı grant, kayıt akışının dışındaki herkesin de
      // rolünü yazabilmesi demekti: bir misafir tek satırla host olup
      // host ekranlarının tamamına ulaşabiliyordu. `rolumu_sec` geçişi
      // ENGELLEMİYOR (ürün tasarımı "ilan açan host olur" diyor) ama
      // kaynağını kaydediyor ve audit_log'a düşürüyor — BO artık kimin
      // nasıl host olduğunu görebiliyor.
      const { error } = await supabase.rpc("rolumu_sec", {
        p_role: role,
        p_gender: gender || null,
      });
      if (error) throw error;
      await supabase.rpc("grant_consents", {
        // 🔴 v2.99 — "18 yaşındayım" AYRI BİR ONAY OLARAK EKLENDİ.
        // Platform sözleşmesi 18 yaş sınırı koyuyordu ama uygulama bunu
        // HİÇ SORMUYORDU. Mağaza yaş derecelendirmesi (yabancılarla sohbet +
        // yüz yüze buluşma) ile sözleşme arasındaki boşluk buydu.
        // 🆕 SINIF: "SÖZLEŞMEDE YAZAN BİR ŞART, AKIŞTA SORULMUYORSA ŞART DEĞİL
        // TEMENNİDİR."
        p_types: ["no_lounge_sale", "no_offplatform_payment", "community_rules", "venue_rules", "terms_privacy", "age_18"],
        p_version: "v16",
      });
      onDone();
    } catch (e) {
      setErr(mapErr(t, e.message || String(e)));
      setBusy(false);
    }
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneAccount} title={t.onbCompleteTitle} />
      <ScrollView contentContainerStyle={{ padding: ARA[22], paddingBottom: ARA[40] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 20, marginBottom: SP[4] }}>{t.onbCompleteBody}</Text>

        <Text style={st.label}>{t.roleTitle}</Text>
        {[["host", t.roleHost, t.roleHostSub], ["guest", t.roleGuest, t.roleGuestSub]].map(([k, title, sub]) => (
          <Secim key={k} bicim="kart" ton="gold" secili={role === k} etiket={title} alt={sub}
            a11yRol="radio" stil={{ marginBottom: SP[2] }} onPress={() => setRole(k)} />
        ))}

        <Text style={st.label}>{t.gender}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[6] }}>
          {(t.genders || []).map(([k, lab]) => (
            <Secim key={k} ton="gold" secili={gender === k} etiket={lab} onPress={() => setGender(k)} />
          ))}
        </View>
        <Text style={{ color: C.dim, fontSize: FS.xs, marginBottom: ARA[14] }}>{t.genderWhy}</Text>

        <Text style={st.label}>{t.consentTitle}</Text>
        {[t.c1, t.c2, t.c3, t.c4, t.c5, t.c6Age].map((txt, i) => (
          <TouchableOpacity hitSlop={TAP.slop} key={i} onPress={() => setConsents(c => c.map((v, j) => j === i ? !v : v))}
            style={{ flexDirection: "row", alignItems: "flex-start", gap: SP[2], backgroundColor: C.card, borderWidth: 1,
                     borderColor: consents[i] ? C.gold : C.line, borderRadius: R.xs, padding: SP[3], marginBottom: SP[2] , ...ELEV.card }}>
            <Ikon ad={consents[i] ? "kutuDolu" : "kutuBos"} boy={18} renk={consents[i] ? C.gold : C.mut} />
            <Text style={{ color: C.ink, fontSize: FS.sm, flex: 1, lineHeight: 18 }}>{txt}</Text>
          </TouchableOpacity>
        ))}

        {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
        <Btn label={t.onbCompleteBtn} onPress={submit} disabled={!role || !all || busy} busy={busy} style={{ marginTop: SP[3], opacity: (role && all) ? 1 : 0.45 }} />
        <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: SP[4], alignItems: "center" }} onPress={onLogout}>
          <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.logout}</Text>
        </TouchableOpacity>
      </ScrollView>
      {!!legal && (
        <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: C.paper }}>
          <LegalDoc t={t} docKey={legal} onBack={() => setLegal(null)} onOpen={setLegal} />
        </View>
      )}
    </Sayfa>
  );
}


// ============================================================
// v1.83 · ŞİFRE BELİRLEME EKRANI (sıfırlama bağlantısından gelince)
//
// Supabase, sıfırlama bağlantısına tıklanınca uygulamayı PASSWORD_RECOVERY
// olayıyla açar ve geçici bir oturum verir. O anda kullanıcı yeni şifresini
// belirlemeli — aksi halde ne yapacağını bilemez (eski akışta backoffice'e
// düşüyordu, oraya da giremiyordu).
// ============================================================
export function SetNewPassword({ t, onDone }) {
  const [p1, setP1] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState(false);

  async function save() {
    setErr("");
    if (p1.length < 8) { setErr(t.pwMin); return; }
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: p1 });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }   // v2.65: ham metin değil
    // 🔴 v2.73 — BU SATIR YILLARDIR HİÇBİR ŞEY YAPMIYORDU.
    // `users` tablosunda `must_change_password` diye bir kolon YOK;
    // bayrak `admin_roles` ve `lounge_partners` tablolarında duruyor.
    // Çağrı try/catch içindeydi, hata yutuluyordu — yani geçici
    // şifresini değiştiren admin ya da partner her girişte yeniden
    // "şifreni değiştir" ekranına düşüyordu ve nedeni görünmüyordu.
    // Doğru yol zaten vardı: `mark_password_changed()`.
    {
      const { error: mErr } = await supabase.rpc("mark_password_changed");
      if (mErr) console.warn("mark_password_changed basarisiz:", mErr.message);
    }
    setOk(true);
    setTimeout(() => onDone && onDone(), 1200);
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneAccount} title={t.setNewPassTitle} />
      <ScrollView contentContainerStyle={{ padding: ARA[22] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 20, marginBottom: SP[4] }}>{t.setNewPassBody}</Text>
        {ok ? (
          <View style={{ backgroundColor: C.tealTint2, borderRadius: R.xs, padding: ARA[14] }}>
            <IkonMetin ad="tamam" renk={C.tealInk} stilMetin={{ color: C.tealInk, fontWeight: "700" }} metin={t.setNewPassDone} />
          </View>
        ) : (
          <>
            <Text style={st.label}>{t.pass}</Text>
            <IconField icon={<Ikon ad="kilit" boy={15} renk={C.muted} />}>
              <TextInput style={st.inputBare} value={p1} onChangeText={setP1} secureTextEntry
                placeholder="En az 8 karakter" placeholderTextColor={C.mut} />
            </IconField>
            {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
            <Btn label={t.setNewPassBtn} onPress={save} disabled={busy} busy={busy} style={{ marginTop: ARA[14] }} />
          </>
        )}
      </ScrollView>
    </Sayfa>
  );
}

export function Main({ t, lang, toggleLang, setLangGlobal, session }) {
  // 🔴 12 EYLÜL · KAPSAM TURU — TANIŞ VE PLANIM DA DARALIYOR.
  // Bu iki sekmenin bandı App.js'te, kaydırma listesi ise `Meet` /
  // `Trips` / `Hosting` içinde. O yüzden ilk turda bağlayamamıştım:
  // `kaydir` bileşen sınırından geçmiyordu. Kanca burada kuruluyor ve
  // `bnt` olduğu gibi çocuğa iniyor — çocuk `bnt` almazsa eski
  // davranışı sürdürüyor (`bnt ? ... : null`), yani bağlantı kademeli.
  // 🆕 SINIF: "BİR DAVRANIŞI BİLEŞEN SINIRINDAN GEÇİRMEK İÇİN ÖNCE
  // O DAVRANIŞIN SAHİBİNİ SEÇ — BAŞLIK BURADAYSA KANCA DA BURADA
  // DOĞAR, ÇOCUK YALNIZ TAŞIR."
  const bntMeet = useDaralanBant();
  const bntTrips = useDaralanBant();
  // v1.74: sosyal girişle gelen kullanıcının eksik adımları (rol + onaylar)
  // burada tamamlanır. null = henüz bilinmiyor (ekranı boş göstermemek için
  // uygulama normal akışta kalır), true = tamamlama ekranı.
  const [needsOnb, setNeedsOnb] = useState(false);
  useEffect(() => {
    let alive = true;
    (async () => {
      const need = await needsOnboarding(session?.user?.id);
      if (alive) setNeedsOnb(!!need);
    })();
    return () => { alive = false; };
  }, [session?.user?.id]);

  async function handleLogout() {
    try {
      // 🔴 v1.75 (Gokberk): ÇIKIŞ ARTIK ENGELLENMİYOR. Eski kural tek taraflı
      // başlatılmış bir oturum yüzünden kullanıcıyı uygulamada kilitliyordu
      // ("aktif oturumum yok ama çıkamıyorum"). Çıkışı engellemek güvenlik
      // sağlamıyor (uygulamayı silmek serbest); oturum kaydı zaten sunucuda
      // duruyor ve kullanıcı döndüğünde kaldığı yerden devam ediyor.
    } catch (e) {}
    // 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: çıkış "ara ara" çalışmıyordu.
    // signOut() sunucuya gider; ağ yavaş/kopuksa promise ASILI KALIR ve
    // ekran hiç değişmez — kullanıcı butonu bozuk sanır. Oturumu
    // kapatmak KULLANICININ kararıdır ve yerelde her koşulda uygulanır:
    // ağ cevabı 2,5 saniyede gelmezse beklemeyi bırakırız, hata dönerse
    // yutarız; her iki durumda da oturum yerelde düşer (sunucu tarafı
    // token zaten süresi dolunca geçersizleşir).
    try {
      await Promise.race([
        supabase.auth.signOut(),
        new Promise(res => setTimeout(res, 2500)),
      ]);
    } catch (e) {}
    // 🔴 v3.4 — ÇIKIŞTA KATALOG ÖNBELLEĞİ DE TEMİZLENİYOR.
    // `src/katalog.js` modül düzeyinde 30 dakika tutuyor. Havalimanı ve
    // havayolu listeleri kişiye bağlı DEĞİL, yani içerik yanlış olmazdı —
    // ama bir önbelleğin hesap sınırını aşması, bir gün kişiye bağlı bir
    // liste eklendiğinde SESSİZ bir sızıntıya döner.
    //
    // 🆕 SINIF: "BİR ÖNBELLEĞİN ÖMRÜNÜ VERİNİN DEĞİL OTURUMUN SINIRINA DA
    // BAĞLA — BUGÜN ZARARSIZ OLAN, YARIN EKLENEN BİR ALANLA ZARARLI OLUR."
    try { katalogUnut(); } catch (e) {}
    // Rol hatirasi da gitsin: baska bir hesapla girildiginde eski rolun
    // sekmesi bir an gorunmemeli.
    try { await AsyncStorage.removeItem("ll_rol"); } catch (e) {}
    return true;
  }

  const [tab, setTab] = useState("home");
  // v2.96: alt sekme artık her rolde var. Varsayılan role göre: host
  // İlanlarım'a, misafir Seyahatlerim'e düşer — herkes kendi işine.
  const [hostTripsSub, setHostTripsSub] = useState("ilan");  // tab2: ilan | seyahat
  const [altSekmeKuruldu, setAltSekmeKuruldu] = useState(false);
  // 🔴 3 EYLÜL — bu etki eskiden BURADAYDI ve `role`ü tanımından 60 satır
  // ÖNCE okuyordu (TDZ). Hermes TDZ denetimini kapalı çalıştırdığı için
  // cihazda sessiz kaldı; web sahnesinde (V8) ilk karede
  // "Cannot access 'role' before initialization" ile çöktü. Etki `role`ün
  // altına taşındı — bkz. `setRoleState` sonrası.
  useEffect(() => {
    const t = setTimeout(() => {
      import("./src/push").then(m => m.pushDurumOku && m.pushDurumOku()).catch(() => {});
    }, 1500);
    return () => clearTimeout(t);
  }, []);
  const [chat, setChat] = useState(null);
  const [showWallet, setShowWallet] = useState(false);
  const [showHostApply, setShowHostApply] = useState(false);
  const [radar, setRadar] = useState(null);
  const [meetFilterOpen, setMeetFilterOpen] = useState(false);
  // Tanış'ın aktif alt sekmesi başlıkta ETİKET olarak gösteriliyor;
  // durumu `Meet` tutuyordu, başlık ona ulaşamıyordu.
  const [meetSub, setMeetSub] = useState("discover");   // #3: filtre butonu header'da
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL — ALT SEKME DEĞİŞİNCE DARALAN BANT SIFIRLANIR.
  // Gerekçe ve dürüstlük notu `src/ui.js · useDaralanBant.sifirla`
  // üstünde: bu, Not2'yi ararken bulunan BAĞIMSIZ bir kusur; Not2'nin
  // sebebi DEĞİL (o ölçüm aracımın yapaylığıydı ve düzeltildi).
  // Kısaca: alt sekme değişince altındaki `ScrollView` yepyeni ve
  // offset'i 0, ama `kaydir` eski değerini koruyor; bant yarı katlanmış
  // donabiliyor. Sekme değişimi, kaydırma konumunun GEÇERSİZ olduğu an.
  // İKİ BANT DA aynı deseni kullanıyor (Planım ve Tanış) — birini
  // düzeltip diğerini bırakmak, aynı hatayı iki ay sonra yeniden
  // bulmak demekti.
  useEffect(() => { bntTrips.sifirla(); }, [hostTripsSub, bntTrips.sifirla]);
  useEffect(() => { bntMeet.sifirla(); }, [meetSub, bntMeet.sifirla]);
  const [showVerify, setShowVerify] = useState(false);
  const [showKimlik, setShowKimlik] = useState(false);   // SQL 285 — kimlik belgesi
  const [showNotif, setShowNotif] = useState(false);
  const [showPlans, setShowPlans] = useState(false);
  const [pubProfile, setPubProfile] = useState(null);
  const [compChat, setCompChat] = useState(null);   // {channelId, name}
  const [showSafety, setShowSafety] = useState(false);
  const [report, setReport] = useState(null);   // {targetId, targetName, sessionId}
  const [showTrust, setShowTrust] = useState(false);
  const [showHist, setShowHist] = useState(false);
  const [showRef, setShowRef] = useState(false);
  const [showAccess, setShowAccess] = useState(false);
  const [showBc, setShowBc] = useState(false);
  const [showLive, setShowLive] = useState(false);
  // v2.95 (madde 11) — Profil > Değerlendirmeler
  const [showRatings, setShowRatings] = useState(false);
  // 🔴 v3.4 — "SORULARIM" EKRANI ARTIK ULAŞILABİLİR.
  // `MyQuestions` bileşeni yazılmış, `sorularim()` RPC'si canlıda, App.js
  // onu IMPORT ediyordu — ama hiçbir yerde ÇİZİLMİYORDU. Yani ekran
  // vardı ve kullanıcı için YOKTU. Akış şeridinden açılıyor.
  //
  // 🆕 SINIF: "IMPORT EDİLİP HİÇ ÇİZİLMEYEN BİR EKRAN YAZILMIŞ AMA
  // TESLİM EDİLMEMİŞTİR — VE KİMSE ARAMADIĞI İÇİN KAYIP DA SAYILMAZ."
  const [showQuestions, setShowQuestions] = useState(false);
  // 🔴 30 AĞUSTOS — "İSTEKLER" KUTUCUĞUNUN GİDECEK YERİ YOKTU.
  // Ayrıntı için `AkisSeridi` çağrısındaki nota bak.
  const [showIstekler, setShowIstekler] = useState(false);
  // 🔴 18 EYLÜL (Gökberk md.4) — "hem sohbet hem de davet kutucukları
  // bağlantılarım sayfasına yönleniyor. Sohbete tıkladığımda aktif
  // sohbetlerim gelmeli, davette bana gelen davetleri görmeliyim."
  //
  // Ölçtüm, haklıydı ve sebep tek satırdı: `onDavetler` `setMeetSub("reqs")`
  // diyordu ama `"reqs"` diye bir görünüm YOK — `Meet` iki dallı
  // (`sub === "discover" ? … : …`), yani "reqs" else dalına düşüp
  // "conns" ile AYNI listeyi çiziyordu. Çip satırında bile karşılığı yok.
  // Sohbet de aynı yere gidiyordu.
  //
  // 🆕 SINIF: "TANIMSIZ BİR DURUM DEĞERİ HATA VERMEZ — SESSİZCE 'ELSE'E
  // DÜŞER VE İKİ AYRI DÜĞMEYİ AYNI EKRANA BAĞLAR."
  //
  // İkisinin de artık kendi tam ekranı var. Davet ekranı `pending_actions`
  // kullanıyor: hem lounge davetleri hem bağlantı istekleri — akış
  // şeridindeki DAVET rozeti de tam olarak bu ikisini sayıyor.
  const [showDavetler, setShowDavetler] = useState(false);
  const [showSohbetler, setShowSohbetler] = useState(false);
  // v2.95 (madde 7) — "İlanıma git": İlanlarım'da odaklanılacak ilan
  const [odakAvail, setOdakAvail] = useState(null);
  // ══════════════════════════════════════════════════════════════════
  // 🔴 v3.4 — ROL ARTIK CİHAZDA HATIRLANIYOR. Sebebi bir REGRESYON RİSKİ.
  //
  // Bu tur "İlanlarım" sekmesini role bağladım (Gökberk'in kritik maddesi).
  // Ama `role` yalnızca `Home` mount olup sorgusu dönünce doluyordu ve
  // varsayılanı `"guest"` idi. Yani bir HOST uygulamayı açtığında, ilk
  // birkaç yüz milisaniye kendi sekmesini GÖRMÜYOR — sonra sekme aniden
  // beliriyor. Kapıyı doğru kurup deneyimi bozmak olurdu.
  //
  // Çözüm ek bir ağ turu DEĞİL: son bilinen rol `AsyncStorage`da. Ekran
  // onunla açılıyor, ağ cevabı gelince düzeltiyor.
  //
  // ⚠️ GÜVENLİK: bu değer bir YETKİ KAYNAĞI DEĞİL, bir ÇİZİM TAHMİNİ.
  // Gerçek kapı sunucuda (SQL 261 · `not_a_host`). Cihazdaki değer
  // kurcalansa bile ilan açılamaz — yalnız boş bir sekme görünür.
  //
  // 🆕 SINIF: "BİR ARAYÜZ KAPISINI AĞ CEVABINA BAĞLARSAN, KAPI DOĞRU
  // OLSA BİLE İLK KARE YANLIŞ OLUR — SON BİLİNEN DURUMU HATIRLA, AMA
  // ONU ASLA YETKİ SAYMA."
  const [role, setRoleStateHam] = useState("guest");
  const setRoleState = useCallback((r) => {
    setRoleStateHam(r);
    if (r) AsyncStorage.setItem("ll_rol", String(r)).catch(() => {});
  }, []);
  // 🔴 5 EYLÜL — ÖLÇÜLDÜ (web sahne 12b, Selin/host): Planım "Seyahatlerim"
  // açılıyordu. `role` "guest" yer tutucusuyla başlar; eski sürüm ilk
  // turda "seyahat"e kilitleyip `altSekmeKuruldu`yu true yapıyordu, sunucu
  // "host" dediğinde bir daha bakmıyordu. Şimdi: kullanıcı çipe basana
  // kadar rol değişince alt sekme rolü izler.
  // 🆕 SINIF: "YER TUTUCU BİR DEĞERE GÖRE VERİLEN KARAR, GERÇEK DEĞER
  // GELİNCE YENİDEN VERİLMELİDİR."
  useEffect(() => {
    if (altSekmeKuruldu || !role) return;
    setHostTripsSub(role === "host" ? "ilan" : "seyahat");
  }, [role, altSekmeKuruldu]);
  useEffect(() => {
    AsyncStorage.getItem("ll_rol")
      .then((r) => { if (r === "host" || r === "guest") setRoleStateHam(r); })
      .catch(() => {});
  }, []);
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL · GÖKBERK NOT2 — ROL BİR EKRANIN DEĞİL KABUĞUN BİLGİSİ.
  //
  // "planım-seyahat görselinde seyahatlerim/ilanlarım sekmeleri neden
  //  gelmemiş… bunun host tarafında da yaşanmadığından emin ol."
  //
  // ÖLÇTÜM VE HOST TARAFINDA YAŞANIYORDU. `role`, ürünün hangi
  // yüzeylerinin var olduğuna karar veren değer, TEK BİR YERDEN
  // geliyordu: `Home`un yükleyicisi (`onRole={setRoleState}`, App.js
  // ~2784). Sonuçları:
  //   1. `users.role` sorgusu düşerse `Home` `return` ediyor ve `onRole`
  //      HİÇ çağrılmıyor → `role` o oturum boyunca "guest" kalıyor →
  //      host, Planım'da "İlanlarım" çipini HİÇ görmüyor ve o yüzeye
  //      giden kapı kapanıyor. (Sahne: `49_planim_rol_kaybi`.)
  //   2. İlk açılışta önbellekte rol yoksa, `Home`un isteği dönene kadar
  //      host misafir gibi çiziliyor.
  // Üstelik kabuk rolü ZATEN SORUYOR (aşağıdaki ilk-açılış etkisi,
  // `users.role`) — ama sonucu yalnız bir `if`te kullanıp ATIYORDU.
  //
  // 🆕 SINIF: "BİR DEĞER ÜRÜNÜN HANGİ EKRANLARININ VAR OLDUĞUNU
  // BELİRLİYORSA O DEĞER BİR EKRANDAN GELEMEZ — KABUĞUN KENDİSİ
  // SORMALIDIR."
  //
  // ⚠️ YETKİ DEĞİL GÖRÜNÜRLÜK: gerçek kapı sunucuda (SQL 261 ·
  // `not_a_host`). Burada yanlış bir değer en fazla boş bir sekme
  // gösterir; ilan açtırmaz.
  // ⚠️ BU HATA EKRANA ÇİZİLMİYOR VE BU BİLİNÇLİ BİR KARAR:
  // Planım bandına yeni bir uyarı satırı koymak ONAYLI TASARIMI
  // değiştirmek olurdu. Onun yerine hatanın karşılığı DAVRANIŞTA:
  //   · 3 deneme + artan bekleme (ağ bir an koptuysa kapı kapanmasın)
  //   · hepsi düşerse ÖNBELLEKTEKİ son bilinen rol korunur
  //   · her düşen deneme `logError` ile kaydedilir (sessizce yutulmaz)
  // Altındaki ekranlar (`Hosting`/`Trips`) kendi `LoadFail`larını zaten
  // çiziyor; kullanıcı "bir şey yüklenmedi"yi orada görüyor.
  // 19 Eylül — rol okunamadığında görünen şeridin durumu ve yeniden
  // deneme sayacı. İKİSİ DE EFEKTİN ÜSTÜNDE: bir `const`u tanımından
  // önce kullanmak `Main`i tamamen çökertiyor (ölü bölge).
  const [rolHatasi, setRolHatasi] = useState(false);
  const [rolTekrar, setRolTekrar] = useState(0);
  useEffect(() => {
    let canli = true;
    const uid = session?.user?.id;
    if (!uid) return;
    (async () => {
      for (let i = 0; i < 3 && canli; i++) {
        const { data, error } = await supabase.from("users").select("role").eq("id", uid).maybeSingle();
        if (!canli) return;
        if (!error) {
          if (data?.role === "host" || data?.role === "guest") setRoleState(data.role);
          return;
        }
        logError("kabuk_rol", error);
        if (i < 2) await new Promise((r) => setTimeout(r, 1200 * (i + 1)));
      }
      // ══════════════════════════════════════════════════════════════
      // 🔴 19 EYLÜL · DERİN DENETİM — ÜÇ DENEME DE DÜŞERSE SESSİZLİK
      // BİR KARAR DEĞİL BİR KAYIPTI.
      //
      // Buradaki eski yorum "önbellekteki son bilinen rol korunur"
      // diyordu — ama kod bunu YAPMIYORDU: üç deneme düşünce hiçbir şey
      // yapmıyor, `roleState` varsayılan "guest"te kalıyordu. Ve
      // `App.js`teki sekme kabuğu `role === "host"` ile İlanlarım çipini
      // gizliyor.
      //
      // Sahneyle ölçüldü (49_planim_rol_kaybi ↔ 48_seyahat_bos_host):
      //     48 (sağlıklı) : … 'Seyahatlerim', 'İlanlarım' …
      //     49 (ağ hatası): … 'Seyahatlerim'              ← çip YOK
      //     console       : "kabuk_rol Network request failed"
      //
      // Yani bir ağ dalgalanmasından sonra host, ilanlarına ulaşamıyor
      // ve uygulama ona "sen host değilsin" diyor. Hiçbir hata mesajı
      // yok. Aynı dosyadaki `Home` bunu doğru yapıyor (`setYukErr`).
      //
      // 🆕 SINIF: "BİR ROLÜ OKUYAMADIĞINDA VARSAYILANA DÜŞMEK, BİLMEMEYİ
      // BİR CEVAP GİBİ SUNMAKTIR — BİLMİYORSAN ÖNCEKİNİ KORU VE SÖYLE."
      if (canli) setRolHatasi(true);
    })();
    return () => { canli = false; };
  // ⚠️ BAĞIMLILIK `reload` DEĞİL `rolTekrar`. İlk yazımda buraya `reload`
  // koydum ve uygulama AÇILIŞTA ÇÖKTÜ: `const [reload] = useState(0)` bu
  // satırdan 100 satır AŞAĞIDA tanımlı, yani `const`un ÖLÜ BÖLGESİ
  // (temporal dead zone). Hata: "Cannot access 'reload' before
  // initialization" — ekranların yarısında beyaz ekran.
  // Mount testleri bunu göremedi çünkü onlar tek tek EKRAN mount ediyor,
  // `Main`i değil; `web_sahne` yakaladı (30 sahnede aynı çökme).
  // 🆕 SINIF: "BİR EFEKTİN BAĞIMLILIK LİSTESİ DE KODDUR — ORAYA YAZDIĞIN
  // HER AD, O SATIRDA ZATEN TANIMLI OLMAK ZORUNDADIR."
  }, [session?.user?.id, setRoleState, rolTekrar]);
  // MVP'de tab olmayan, ic ekran olan seyler:
  const [showShop, setShowShop] = useState(false);        // Profil > LoungePuan
  const [showSettings, setShowSettings] = useState(false); // Profil > Ayarlar (AYRI EKRAN)
  const [showCamps, setShowCamps] = useState(false);       // Profil > Kampanyalar (048)
  const [showEditProf, setShowEditProf] = useState(false); // Profil > Profili Duzenle
  const [profRefresh, setProfRefresh] = useState(0);       // v2.47: duzenleme sonrasi tazeleme
  // 3 Eylül — tasarım 09 bandı: "SELİN B. · İSTANBUL". İsim profilden,
  // şehir sıradaki seyahatin havalimanından; ikisi de yoksa "Profil".
  const [showAddVisit, setShowAddVisit] = useState(false);
  // v2.50: kayıttan sonraki İLK açılışta lounge hakkı sorulur (bir kez).
  const [firstRunAccess, setFirstRunAccess] = useState(false);
  const [taninmaTetik, setTaninmaTetik] = useState(0);   // v2.74 — tanınma anını yeniden sorgula
  // v2.87: `t` geçiyor — anın başlığı artık i18n'den geliyor (eskiden
  // kancanın içinde sabit Türkçe'ydi, EN kullanıcısı Türkçe görüyordu).
  const [taninma, taninmaKapat] = useRecognitionMoment(session?.user?.id, taninmaTetik, t);
  useEffect(() => {
    let alive = true;
    (async () => {
      if (!session?.user?.id) return;
      try {
        const flag = await AsyncStorage.getItem("ll_access_asked");
        if (flag) return;
        // 🔴 KRİTİK (Gökberk madde 3): MİSAFİRE LOUNGE ERİŞİM KURULUMU
        // SORULUYORDU. "Hangi lounge hakkın var?" sorusu yalnız DAVET
        // EDEN tarafına aittir; misafir zaten hakkı olmadığı için
        // burada. Ona sormak, ürünü anlamadığımızı gösterir ve ilk
        // izlenimi bozar. Rol kontrolü ekleniyor.
        const { data: u, error: hata1 } = await supabase.from("users")
          .select("role").eq("id", session.user.id).maybeSingle();
          if (hata1) logError("App.js:790", hata1);
        // 🔴 v2.66 (Gökberk madde 3, ikinci yarı): adımı ATLAMAK yetmiyor.
        // v2.65 misafire soruyu sormayı bıraktı ama YERİNE bir şey
        // koymadı: misafir kayıttan sonra boş bir ana sayfaya düşüyordu.
        // Misafirin ilk işi ilan açmak DEĞİL, uçuşunu yazmaktır —
        // uçuş olmadan başvurabileceği ilan da eşleşmez. Bu yüzden
        // misafir doğrudan "Uçuşunu ekle" adımına gider.
        // Uçuşu zaten varsa hiçbir şey sorulmaz: iş bitmiş demektir.
        if (u?.role === "guest") {
          await AsyncStorage.setItem("ll_access_asked", "1");
          const today = yerelGun();
          // Hata YUTULMAZ: sorgu düşerse var olan uçuşu "yok" sanıp
          // kullanıcıyı zorla forma sokmayız.
          const { data: vs, error: vErr } = await supabase.from("visits")
            .select("id").eq("user_id", session.user.id).gte("visit_date", today).limit(1);
          if (vErr) return;
          // Mevcut addVisit katmanı kullanılıyor; ayrı bir kopya
          // yazılmadı — iki kopya olsaydı biri bayatlardı (firstAccess
          // katmanında da aynı karar verilmişti).
          if (alive && !(vs && vs.length)) setShowAddVisit(true);
          return;
        }
        const { data, error: hata2 } = await supabase.from("profiles")
          .select("access_source").eq("user_id", session.user.id).maybeSingle();
          if (hata2) logError("App.js:814", hata2);
        // Yalnız hiç kaynak seçmemiş DAVET EDENE sorulur.
        if (alive && !data?.access_source) setFirstRunAccess(true);
        else await AsyncStorage.setItem("ll_access_asked", "1");
      } catch (e) {}
    })();
    return () => { alive = false; };
  }, [session?.user?.id]);
  // v2.48 — Keşfet→Seyahat köprüsü: ilandan gelinen seyahat kaydında
  // ilan hatırlanır; kayıt sonrası "başvur?" onayı sorulur.
  const [pendingReqAvail, setPendingReqAvail] = useState(null);

  // ══════════════════════════════════════════════════════════════════════
  // 🔴 v2.95 (Gökberk madde 12) — "MESAJ GÖNDER" ARTIK SOHBETİ AÇIYOR.
  // "kullanıcı profiline girdiğimdeki mesaj gönder butonuna tıklayınca
  //  tanış ekranına atıyor. Chat sayfasını açmıyor yani."
  //
  // ÖLÇTÜM VE SEBEP UTANÇ VERİCİ DERECEDE BASİTTİ. App.js'te tek satır:
  //     onOpenChat={(id, name) => { setPubProfile(null); }}
  // İşleyici VARDI, BAĞLIYDI, ve GÖVDESİ BOŞTU. Yaptığı tek şey profili
  // kapatmaktı — altında hangi sekme duruyorsa o görünüyordu (Tanış).
  // Kullanıcının "beni Tanış'a atıyor" dediği şey buydu: bir yönlendirme
  // değil, bir hiçlik.
  //
  // 🆕 SINIF: "GÖVDESİ BOŞ BİR OLAY İŞLEYİCİSİ, OLMAYAN BİR DÜĞMEDEN
  // DAHA KÖTÜDÜR — OLMAYAN DÜĞME ÇİZİLMEZ, BOŞ İŞLEYİCİ ÇİZİLİR VE
  // ÇALIŞIYOR SANILIR."
  // Bu sınıf için kalıcı bir nöbetçi de yazdım: `bos_isleyici_check.py`.
  //
  // Mantık üç yerde tekrar ediyordu (Meet, Oturum Geçmişi, burada) ve
  // üçünde de elle yazılmıştı; şimdi TEK yer.
  const companionAc = useCallback(async (peerId, peerName, kapat) => {
    const uid = session?.user?.id;
    if (!uid || !peerId) return false;
    const { data: cr, error: e1 } = await supabase.from("connection_requests")
      .select("id").eq("status", "accepted")
      .or(`and(from_id.eq.${uid},to_id.eq.${peerId}),and(from_id.eq.${peerId},to_id.eq.${uid})`)
      .maybeSingle();
    if (e1 || !cr) return false;
    // Kanalı SUNUCU garanti eder (SQL 248). İstemcinin kanal INSERT
    // etmesi, engellenmiş çiftte bile kanal açabilmesi demekti.
    const { data, error } = await supabase.rpc("baglanti_sohbeti_ac", { p_conn_id: cr.id });
    if (error || !data || !data.channel_id) return false;
    if (kapat) kapat();
    setCompChat({ channelId: data.channel_id, name: peerName });
    return true;
  }, [session]);
  // v2.89 (md.13) — düzenlenen ilan / seyahat
  const [editAvail, setEditAvail] = useState(null);
  const [editTrip, setEditTrip] = useState(null);
  // Düzenleme sonrası listeleri tazelemek için sayaç (v2.47'nin kalıbı)
  const [reload, setReload] = useState(0);
  // ══════════════════════════════════════════════════════════════════
  // 🔴 18 EYLÜL (Gökberk md.8) — "yöneldiğim sayfalarda da back butonu
  // olmalı."
  //
  // Ölçüm: ana sayfadaki kısayollar üç farklı şey yapıyordu — kimi
  // KATMAN açıyor (geri oku var), kimi `setTab(...)` ile SEKME
  // değiştiriyor (geri oku yok, çünkü bir sekmenin geri oku olmaz).
  // Kullanıcı için ikisi aynı hareket: "bir şeye bastım, bir sayfaya
  // gittim". Sekmeye gittiğinde geri dönüş yolu ALT ÇUBUKTA — ama o
  // yolu bulmak, bastığı düğmeyi hatırlamayı gerektiriyor.
  //
  // Çözüm sekmeleri katmana çevirmek DEĞİL (ağaç yeniden kurulur,
  // v3.4'te ölçtüm): sekmeye ANA SAYFADAN gelindiyse geri oku çizilir.
  // Alt çubuktan gelindiyse çizilmez — çünkü o zaman gerçekten bir
  // sekme değişimidir.
  //
  // 🆕 SINIF: "GERİ OKU BİR EKRANIN ÖZELLİĞİ DEĞİL, O EKRANA NASIL
  // GELİNDİĞİNİN ÖZELLİĞİDİR."
  // ══════════════════════════════════════════════════════════════════
  const [sekmeGeri, setSekmeGeri] = useState(null);
  // Ana sayfadan sekmeye giden TEK kapı. `setTab` yerine bu geçiliyor.
  const sekmeyeGit = useCallback((k) => { setSekmeGeri("home"); setTab(k); }, []);
  const sekmeGeriDon = useCallback(() => { setSekmeGeri(null); setTab("home"); }, []);
  const [askApply, setAskApply] = useState(null); // Trips > + Ekle
  const [showAddAvail, setShowAddAvail] = useState(false); // Hosting > + Ekle
  const [showDisc, setShowDisc] = useState(null);          // Trips karti > "Host Bul →"
  // 🔴 v2.43 — SALON REHBERI: tek basina degerli olan ilk ekran.
  const [showGuide, setShowGuide] = useState(false);
  const [unread, refreshUnread] = useUnread(session);

  // ---- Acilis-sirali overlay yigini (#9) ----
  const OVERLAYS = {
    notif: [showNotif, () => setShowNotif(false)],
    plans: [showPlans, () => setShowPlans(false)],
    compChat: [!!compChat, () => setCompChat(null)],
    report: [!!report, () => setReport(null)],
    safety: [showSafety, () => setShowSafety(false)],
    trust: [showTrust, () => setShowTrust(false)],
    hist: [showHist, () => setShowHist(false)],
    ref: [showRef, () => setShowRef(false)],
    ratings: [showRatings, () => setShowRatings(false)],
    questions: [showQuestions, () => setShowQuestions(false)],
    istekler: [showIstekler, () => setShowIstekler(false)],
    davetler: [showDavetler, () => setShowDavetler(false)],
    sohbetler: [showSohbetler, () => setShowSohbetler(false)],
    firstAccess: [firstRunAccess, () => setFirstRunAccess(false)],
    access: [showAccess, () => setShowAccess(false)],
    bc: [showBc, () => setShowBc(false)],
    live: [showLive, () => setShowLive(false)],
    pub: [!!pubProfile, () => setPubProfile(null)],
    verify: [showVerify, () => setShowVerify(false)],
    kimlik: [showKimlik, () => setShowKimlik(false)],
    wallet: [showWallet, () => setShowWallet(false)],
    hostApply: [showHostApply, () => setShowHostApply(false)],
    shop: [showShop, () => setShowShop(false)],
    camps: [showCamps, () => setShowCamps(false)],
    settings: [showSettings, () => setShowSettings(false)],
    // v2.47 — CIHAZDA GORULDU: duzenlemede kaydedilen tarz, profil
    // sekmesine donunce ESKI degerle gorunuyordu (Profile mount verisini
    // onbellekliyor). Kapanista sayac artar, Profile prop degisince
    // yeniden ceker.
    editProf: [showEditProf, () => { setShowEditProf(false); setProfRefresh(x => x + 1); }],
    addVisit: [showAddVisit, () => setShowAddVisit(false)],
    addAvail: [showAddAvail, () => setShowAddAvail(false)],
    // v2.89 (md.13) — düzenleme ekranları
    editAvail: [!!editAvail, () => setEditAvail(null)],
    editTrip: [!!editTrip, () => setEditTrip(null)],
    disc: [!!showDisc, () => setShowDisc(null)],
    guide: [showGuide, () => setShowGuide(false)],
    chat: [!!chat, () => setChat(null)],
  };
  const [openSeq, setOpenSeq] = useState([]);
  useEffect(() => {
    setOpenSeq(prev => {
      let next = prev.filter(k => OVERLAYS[k][0]);          // kapananlar duser
      for (const k of Object.keys(OVERLAYS))                 // yeni acilanlar sona
        if (OVERLAYS[k][0] && !next.includes(k)) next = [...next, k];
      return next.length === prev.length && next.every((k, i) => k === prev[i]) ? prev : next;
    });
  // ══════════════════════════════════════════════════════════════════
  // 🔴 19 EYLÜL — BEŞ KATMAN BU LİSTEDE YOKTU VE BİRİ SOHBETİ YUTUYORDU.
  //
  // Bulunuş: `web_sahne` sahneleri karşılaştırıldı ve `06b_sohbet_tanis`
  // ile `13_baglantilar` BİREBİR AYNI md5'i verdi. Yani "Tanış →
  // Sohbetlerim → Sohbeti Aç" hiçbir şey açmıyordu. Elle de doğruladım:
  // düğmeye basılıyor, hata yok, ekran değişmiyor.
  //
  // KÖK: bu bağımlılık listesi `showSohbetler`, `showIstekler`,
  // `showDavetler`, `showQuestions` ve `firstRunAccess`i İÇERMİYORDU.
  // Sonuç şöyle akıyordu:
  //   1. Kullanıcı Sohbetlerim'i açar → effect KOŞMAZ (hiçbir bağımlılık
  //      değişmedi) → `openSeq` boş kalır.
  //   2. `liveSeq` eksikleri `Object.keys(OVERLAYS)` SIRASIYLA sona
  //      ekler → `sohbetler` en üstte görünür. (Doğru sonuç, şans eseri.)
  //   3. "Sohbeti Aç" → `setCompChat(...)`. ŞİMDİ effect koşar (compChat
  //      bağımlılıkta VAR) ve `openSeq`i anahtar sırasıyla kurar:
  //      `compChat` anahtar listesinde `sohbetler`den ÖNCE geldiği için
  //      `openSeq = ["compChat", "sohbetler"]` olur.
  //   4. `topOverlay` = sonuncu = `sohbetler`. Sohbet açıldı ama ALTTA.
  //
  // Yani katman gerçekten açılıyordu; yığının yanlış ucunda duruyordu.
  // Hata gözle görünmez çünkü ekran DEĞİŞMİYOR — "tıklama çalışmıyor"
  // gibi hissediliyor.
  //
  // 🆕 SINIF: "BİR SIRA DEFTERİ, KAYDETTİĞİ OLAYLARIN HEPSİNİ
  // DİNLEMİYORSA SIRA DEĞİL ALFABE TUTAR — VE ALFABE, KULLANICININ
  // AÇILIŞ SIRASIYLA İLGİSİZDİR."
  //
  // `katman_sira_check.py` artık OVERLAYS'teki her durumun bu listede
  // olmasını ZORUNLU tutuyor; yeni bir katman eklenip buraya yazılmazsa
  // denetim kırmızı yanar.
  // ══════════════════════════════════════════════════════════════════
  }, [showNotif, showPlans, compChat, report, showSafety, showTrust, showHist, showRef, showRatings,
      showQuestions, showIstekler, showDavetler, showSohbetler, firstRunAccess,
      // `editAvail` ve `editTrip`i ben gözden kaçırdım; `katman_sira_check.py`
      // yazıldığı ilk koşuşta ikisini de gösterdi. Kapı, onu yazan kişiden
      // daha dikkatli olduğu gün işe yaramaya başlar.
      editAvail, editTrip,
      showAccess, showBc, showLive, pubProfile, showVerify, showKimlik, showWallet, showHostApply,
      showShop, showCamps, showSettings, showEditProf, showAddVisit, showAddAvail, showDisc, showGuide, chat]);
  // 🔴 v1.63 KOK NEDEN (sohbetten geri = uygulama KAPANIYOR): openSeq bir
  // useEffect ile guncellenir; effect COMMIT'ten sonra kosar. setChat(null)
  // sonrasi ILK render'da openSeq hala ["...","chat"] tasir, topOverlay "chat"
  // kalir ve render OVERLAY_VIEWS.chat() cagirir — chat artik null oldugu icin
  // chat.req PATLAR → prod'da uygulama kapanir. Ayni tuzak compChat.channelId
  // ve report.targetId icin de gecerli. Donanim geri TUSU DA ekrandaki geri
  // OK'U DA ayni setChat(null) yolundan gectigi icin ikisi de cokuyordu
  // (v1.56'daki BackHandler duzeltmesi bu yuzden yetmedi — cokme handler'da
  // degil, kapanis SONRASI render'daydi). COZUM: gorunur katman her render'da
  // CANLI bayraklarla yeniden hesaplanir; openSeq yalnizca SIRAYI hatirlar.
  let liveSeq = openSeq.filter(k => OVERLAYS[k][0]);
  for (const k of Object.keys(OVERLAYS))
    if (OVERLAYS[k][0] && !liveSeq.includes(k)) liveSeq = [...liveSeq, k];
  const topOverlay = liveSeq.length ? liveSeq[liveSeq.length - 1] : null;

  // Donanim geri tusu (oturum ici): render zinciriyle AYNI sirada calisir —
  // ekranda hangi katman goruluyorsa onu kapatir. Katman yoksa: sekme
  // ana sayfa degilse ana sayfaya doner; ana sayfadaysa cikisa izin verir.
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      if (topOverlay) { OVERLAYS[topOverlay][1](); return true; }   // son acilani kapat
      if (tab !== "home") { setTab("home"); return true; }
      return false; // ana sayfadayken geri = uygulamadan cik (Android standardi)
    });
    return () => h.remove();
  }, [topOverlay, tab]);

  // ══════════════════════════════════════════════════════════════════════
  // 🔴 v3.7 — TELEFONDAN GELEN BİLDİRİME DOKUNMAK HİÇBİR YERE GİTMİYORDU.
  //
  // Gökberk (28 Ağustos): "telefona gönderdiğimiz bildirimlerin nasıl
  // olduğunu görmek istiyorum."
  //
  // Bakınca zincirin ikinci yarısının hiç olmadığını gördüm:
  // `expo-notifications`ın `addNotificationResponseReceivedListener`
  // kancası uygulamanın HİÇBİR yerinde yoktu. Yani bildirim telefona
  // düşüyor (pg_net açıksa), kullanıcı dokunuyor, uygulama açılıyor —
  // ve ANA SAYFAYA düşüyor. Bildirimin ne hakkında olduğu kayboluyor.
  //
  // Bir bildirimin işi haber vermek DEĞİL, işin başına GÖTÜRMEKTİR.
  // Götürmeyen bildirim, kullanıcının aramak zorunda kaldığı bir
  // kesintidir — ve ikinci kez aramaz, bildirimleri kapatır.
  //
  // 🆕 SINIF: "BİR BİLDİRİM GÖNDERMEK, BİLDİRİM ÖZELLİĞİNİN YARISIDIR —
  // DİĞER YARISI DOKUNUŞUN NEREYE GİTTİĞİDİR VE O YARI OLMADAN İLKİ
  // ZARAR VERİR."
  //
  // ⚠️ İKİNCİ BİR YÖNLENDİRME TABLOSU YAZILMADI: hedefi yine sunucu
  // (`bildirim_hedefi`) söylüyor, uygulama yalnız uyguluyor. Bildirim
  // listesindeki dokunuş da bu aynı fonksiyondan geçiyor.
  const bildirimeGit = useCallback((h) => {
    if (!h || !h.ekran) return;
    if (h.ekran === "plan") {
      setHostTripsSub(h.alt === "seyahat" ? "seyahat" : "ilan");
      if (h.ref) setOdakAvail(h.ref);
      setTab("trips");
    } else if (h.ekran === "tanis") setTab("meet");
    else if (h.ekran === "cuzdan") setShowWallet(true);
    else if (h.ekran === "degerlendirmeler") setShowRatings(true);
    else if (h.ekran === "guvenlik") setShowSafety(true);
    else if (h.ekran === "sohbet" && h.ref) {
      // Mesaj bildirimi: `ref` sohbet kanalının kimliği. Kanal hangi
      // türse (lounge / companion) doğru ekran açılıyor.
      (async () => {
        try {
          const { data, error } = await supabase.from("chat_channels")
            .select("id, kind, request_id").eq("id", h.ref).maybeSingle();
          if (error) { logError("bildirim_sohbet", error); return; }
          if (!data) return;
          if (data.kind === "companion") setCompChat({ channelId: data.id, name: "" });
          else if (data.request_id) setChat({ req: { id: data.request_id }, name: "" });
        } catch (e) { logError("bildirim_sohbet", e); }
      })();
    }
  }, []);

  // Bildirime DOKUNULDUĞUNDA (uygulama açıkken ya da kapalıyken).
  useEffect(() => {
    if (!session?.user?.id) return;
    let canli = true;
    async function isle(response) {
      const nid = response?.notification?.request?.content?.data?.notification_id;
      if (!nid) return;
      try {
        // Okundu işaretle + hedefi sunucudan al. Aynı iki çağrı,
        // bildirim listesindeki dokunuşla birebir aynı.
        //
        // ⚠️ TEK DALGADA: hedef, okundu bilgisine BAĞLI DEĞİL. Sıraya
        // dizmek kullanıcıyı iki tur bekletirdi — ve burası beklemenin
        // en pahalı olduğu an: kişi bildirime dokundu, ekranın açılmasını
        // bekliyor. (Kendi şelale nöbetçim bunu yakaladı.)
        const [, hedef] = await Promise.all([
          supabase.rpc("bildirim_okundu", { p_id: nid }),
          supabase.rpc("bildirim_hedefi", { p_id: nid }),
        ]);
        const { data, error } = hedef;
        if (error) { logError("bildirim_hedefi_push", error); return; }
        if (canli && data && data.ekran) bildirimeGit(data);
        refreshUnread && refreshUnread();
      } catch (e) { logError("push_dokunus", e); }
    }
    let sub = null;
    (async () => {
      try {
        const Bildirimler = require("expo-notifications");
        // (a) Uygulama KAPALIYKEN dokunulduysa: son cevabı oku.
        const son = await Bildirimler.getLastNotificationResponseAsync();
        if (son) await isle(son);
        // (b) Uygulama AÇIKKEN/arka plandayken dokunulursa.
        sub = Bildirimler.addNotificationResponseReceivedListener(isle);
      } catch (e) { logError("push_dinleyici", e); }
    })();
    return () => { canli = false; try { sub && sub.remove(); } catch (e) {} };
  }, [session?.user?.id, bildirimeGit, refreshUnread]);

  // Overlay render'i: acilis-sirali yiginin TEPESI gorunur (#9).
  const OVERLAY_VIEWS = {
    notif: () => (<Notifications t={t} session={session} onRefreshBadge={refreshUnread}
      onBack={() => setShowNotif(false)}
      onGit={(h) => {
        // 🔵 v2.99 — sunucunun verdiği hedefi UYGULAYAN tek yer burası.
        // Bildirim ekranı kapanıyor ve kullanıcı doğrudan işin başına gidiyor.
        setShowNotif(false);
        bildirimeGit(h);
      }} />),
    // 🔴 v2.79 — `lang` ARTIK GEÇİYOR. Plan adı ve ayrıcalık maddeleri
    // veritabanından HAM geliyordu (screens.js:4395 `{p.ad}`), yani EN
    // diline geçen kullanıcı planı Türkçe görüyordu. SQL 220 katalogda
    // `ad_en`/`perks_en` alanlarını açtı; `subscription_plans(p_lang)`
    // hangi dili istediğimizi sormamızı bekliyor. Cihazın dilini sunucu
    // bilmiyor — söylemek bizim işimiz.
    plans: () => (<Plans t={t} lang={lang} session={session} onBack={() => setShowPlans(false)} />),
    compChat: () => (<CompanionChat t={t} session={session} channelId={compChat.channelId} otherName={compChat.name} onBack={() => setCompChat(null)} onOpenProfile={(id) => setPubProfile(id)} onReport={(id, nm) => setReport({ targetId: id, targetName: nm, sessionId: null })} />),
    report: () => (<ReportUser t={t} session={session} targetId={report.targetId} targetName={report.targetName}
    sessionId={report.sessionId} onBack={() => setReport(null)} />),
    safety: () => (<Safety t={t} session={session} onBack={() => setShowSafety(false)}
    onReport={() => { setShowSafety(false); setReport({ targetId: null, targetName: null, sessionId: null }); }}
    onTrust={() => { setShowSafety(false); setShowTrust(true); }}
    onEditProfile={() => { setShowSafety(false); setShowEditProf(true); }} />),
    trust: () => (<TrustVisual t={t} session={session} onBack={() => setShowTrust(false)} />),
    hist: () => (<SessionHistory t={t} lang={lang} session={session} onBack={() => setShowHist(false)} onOpenChat={setChat} onOpenProfile={setPubProfile} onOpenCompanion={(pid, nm) => companionAc(pid, nm, () => setShowHist(false))} />),
    ref: () => (<Referral t={t} session={session} onBack={() => setShowRef(false)} />),
    // v2.50 — KAYIT SONRASI İLK ADIM: "hangi lounge hakkın var?".
    // Aynı ekranın kendisi (HostAccessSource) kullanılıyor; ayrı bir
    // tanıtım kopyası YAZILMADI — iki kopya olsaydı biri bayatlardı.
    // Atlanabilir: cevap vermeyen kullanıcı akışta tıkanmaz, soru
    // profilinde "Erişim Kaynağı" olarak durmaya devam eder.
    // v2.74 — KARTI TANITTIKTAN SONRA "TANINMA ANI". Kişi hakkını
    // ilk kez bir SAYI olarak görüyor; ürünün host'a "sen bir
    // host'sun" dediği tek an bu. Sayı yoksa an hiç kurulmaz.
    firstAccess: () => (<HostAccessSource t={t} session={session}
      onDone={async () => { try { await AsyncStorage.setItem("ll_access_asked","1"); } catch (e) {} setFirstRunAccess(false); setTaninmaTetik(x => x + 1); }}
      onBack={async () => { try { await AsyncStorage.setItem("ll_access_asked","1"); } catch (e) {} setFirstRunAccess(false); }} />),
    access: () => (<HostAccessSource t={t} session={session} role={role}
      onBecomeHost={async () => {
        // 🔴 v2.89 — "Host'a geç" TEK KAPIDAN (SQL 232). Doğrudan
        // users.update yerine rolumu_sec: kaynak yazılıyor, audit_log'a
        // düşüyor, ve istemcinin role kolonuna yazma yetkisi yok.
        const { error } = await supabase.rpc("rolumu_sec", { p_role: "host" });
        // ⚠️ `logError` App.js'te import edilmemiş (denetim yakaladı);
        // burada sessiz yutmuyoruz — hata konsola düşüyor ve rol
        // değişmediği için ekran misafir kapısında kalıyor.
        if (error) { console.warn("rolumu_sec", error.message); return; }
        setRoleState("host");
      }}
      onDone={() => setShowAccess(false)} onBack={() => setShowAccess(false)} />),
    bc: () => (<HostBroadcast t={t} lang={lang} session={session} onBack={() => setShowBc(false)} onVerify={() => setShowVerify(true)} />),
    // 🔴 v3.4 — bu satır YOKTU. `MyQuestions` import ediliyor ama hiçbir
    // yerden çizilmiyordu: yazılmış, teslim edilmemiş bir ekran.
    istekler: () => (
      <Sayfa>
        <Hdr t={t} ustBilgi={t.sceneRequests} title={t.flowRequests} onBack={() => setShowIstekler(false)} marka={false} />
        <ScrollView contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
          {/* ⚠️ `onOpenChat`/`onOpenProfile` BURADA YOK — bunlar `Home`un
              propları. Overlay `AppInner` kapsamında çiziliyor, yani
              state'i doğrudan kullanmalı. İlk yazımda `Home`daki adları
              kopyaladım; check.js "satır 1093 TANIMSIZ" diye yakaladı. */}
          {/* 3 Eylül — bu ekranın TEK işi istek listesi; katlı gelirse
              kullanıcı "İstek"e basıp boş bir kutu görüyor (web sahnesinde
              ölçüldü). Burada açık başlar; ana sayfadaki katlı hâl aynen. */}
          <RequestsPanel t={t} lang={lang} session={session} acikBasla
            onOpenChat={setChat} onOpenProfile={setPubProfile} />
        </ScrollView>
      </Sayfa>),
    davetler: () => (
      <Sayfa>
        <Hdr t={t} ustBilgi={t.sceneMeet} title={t.flowInvitesTitle} onBack={() => setShowDavetler(false)} marka={false} />
        <ScrollView contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
          {/* ⚠️ `tazele` `Home`un kendi state'i; bu katmanlar `Main`
              kapsamında çiziliyor. Ortak anahtar `reload` — ve katmanda
              verilen cevap `setReload` ile ana sayfayı da tazeliyor. */}
          <ActionNeeded t={t} lang={lang} tamEkran tazele={reload}
            onRefresh={() => setReload(x => x + 1)}
            onOpenChat={setChat} />
        </ScrollView>
      </Sayfa>),
    sohbetler: () => (
      <Sayfa>
        <Hdr t={t} ustBilgi={t.sceneMeet} title={t.flowChatsTitle} onBack={() => setShowSohbetler(false)} marka={false} />
        <ScrollView contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
          <HomeConnections t={t} session={session} tamEkran tazele={reload}
            onOpenChat={(cid, nm) => setCompChat({ channelId: cid, name: nm })} />
        </ScrollView>
      </Sayfa>),
    questions: () => (<MyQuestions t={t} lang={lang}
      onBack={() => setShowQuestions(false)}
      onOpenProfile={(id) => setPubProfile(id)}
      /* 🔴 19 EYLÜL (md.16) — ilan açıldıysa İLANA. `setShowDisc` zaten
         `focusAvail` ile ilanın başvuru modalını açıyor (v2.25'te
         Tanış ekranı için yazılmıştı); ikinci bir yol açmıyoruz. */
      onIlanaGit={(availId, ap) => { setShowQuestions(false); setShowDisc({ airport: ap || null, focusAvail: availId }); }}
      onOpenCompanion={(cid, nm) => { setShowQuestions(false); setCompChat({ channelId: cid, name: nm }); }} />),
    ratings: () => (<Degerlendirmeler t={t} lang={lang}
      onBack={() => setShowRatings(false)}
      onOpenProfile={(id) => setPubProfile(id)}
      /* Puanlama formu sohbetin içindeki panelde yaşıyor (tek kaynak).
         Buradan "★ Puanla"ya basınca o panel AÇIK olarak açılıyor —
         ikinci bir puanlama formu yazmak, iki ayrı doğruluk kaynağı
         yaratmak olurdu. */
      onRate={(r) => { setShowRatings(false);
        if (r && r.request_id) setChat({ req: { id: r.request_id }, name: r.other_name, openPanel: true }); }} />),
    live: () => (<LiveStatus t={t} session={session} onBack={() => setShowLive(false)}
      onGoSession={(req) => { setShowLive(false); if (req) setChat({ req, name: null }); }} />),
    pub: () => (<PublicProfile t={t} session={session} targetId={pubProfile} onBack={() => setPubProfile(null)}
      onOpenChat={(id, name) => { companionAc(id, name, () => setPubProfile(null)); }}
      onReport={(id, name) => { setPubProfile(null); setReport({ targetId: id, targetName: name, sessionId: null }); }} />),
    verify: () => (<VerifyPhone t={t} session={session} onDone={() => setShowVerify(false)} onBack={() => setShowVerify(false)} />),
    kimlik: () => (<KimlikDogrula t={t} session={session} onBack={() => setShowKimlik(false)} />),
    wallet: () => (<Wallet t={t} session={session} onBack={() => setShowWallet(false)} />),
    hostApply: () => (<HostApply t={t} session={session} onBack={() => setShowHostApply(false)} />),
    shop: () => (<Marketplace t={t} session={session} onBack={() => setShowShop(false)} />),
    camps: () => (<Campaigns t={t} onBack={() => setShowCamps(false)} />),
    settings: () => (<Settings t={t} lang={lang} setLang={setLangGlobal} session={session} onBack={() => setShowSettings(false)}
    onEditProfile={() => setShowEditProf(true)}
    onVerify={() => setShowVerify(true)} />),
    // 🔴 v2.89 (Gökberk md.12) — MİSAFİR HOST EKRANINA BURADAN GİRİYORDU.
    // `onAccess` KOŞULSUZ geçiliyordu; Profili Düzenle içindeki satır
    // `{!!onAccess && ...}` diye çiziliyor, yani rol HİÇ sorulmuyordu.
    // İlk çalıştırma akışı bu kapıyı açıkça kapatmış (App.js:583
    // "role === guest ise erişim kurulumunu atla") ama Profil yolu açık
    // kalmıştı. Oradan giren misafir `save_host_access` çağırıp host
    // durumunu tamamen kurabiliyordu.
    // 🆕 SINIF: "BİR KAPIYI BİR YOLDA KAPATMAK, DİĞER YOLLARI KAPATMAZ."
    // (v0.26'da sitede aynı sınıf: hukuki kapı app'te vardı, sitede yoktu.)
    editProf: () => (<EditProfile t={t} session={session} onVerify={() => { setShowEditProf(false); setShowVerify(true); }} onVerifyId={() => { setShowEditProf(false); setShowKimlik(true); }} onBack={() => setShowEditProf(false)} onAccess={role === "host" ? () => { setShowEditProf(false); setShowAccess(true); } : null}
      /* v2.66: "Host olmak istiyorum" kartı buraya taşındı (madde 4) */
      onHostApply={() => { setShowEditProf(false); setShowHostApply(true); }} />),
    // v2.89 (md.13) — düzenleme ekranları
    editAvail: () => (<EditAvailability t={t} avail={editAvail}
      onBack={() => setEditAvail(null)}
      onDone={() => { setEditAvail(null); setReload(x => x + 1); }} />),
    editTrip: () => (<EditTrip t={t} visit={editTrip}
      onBack={() => setEditTrip(null)}
      onDone={() => { setEditTrip(null); setReload(x => x + 1); }} />),
    addVisit: () => (<AddVisit t={t} session={session} suggest={pendingReqAvail}
      onBack={() => { setShowAddVisit(false); setPendingReqAvail(null); }}
      onDone={() => {
        setShowAddVisit(false);
        // 🔴 v2.48 (cihazda görüldü): Keşfet'ten "Seyahat ekle" ile gelen
        // kullanıcı kayıttan sonra İLANI KAYBEDİYORDU — tekrar Keşfet'e
        // gidip aramak zorundaydı. Artık kayıt biter bitmez soruyoruz.
        if (pendingReqAvail) setAskApply(pendingReqAvail);
      }} />),
    // 🔴 v3.4 — ÜÇÜNCÜ KAPI. Sekme gizlendi, davet ekranındaki düğme
    // kaldırıldı; ama bu overlay bir `setShowAddAvail(true)` çağrısıyla
    // AÇILIYOR ve o çağrı ileride başka bir yerden gelebilir. Kapıyı
    // düğmeye değil EKRANIN KENDİSİNE koyuyoruz.
    //
    // 🆕 SINIF: "BİR EKRANI AÇAN DÜĞMELERİ KAPATMAK, EKRANI KAPATMAK
    // DEĞİLDİR — KAPIYI EKRANIN ÖNÜNE KOY, DÜĞMENİN ARKASINA DEĞİL."
    addAvail: () => (role === "host"
      ? (<HostAvailability t={t} session={session} onBack={() => setShowAddAvail(false)} onDone={() => setShowAddAvail(false)} onVerify={() => { setShowAddAvail(false); setShowVerify(true); }} />)
      : (<HostDaveti t={t} onBecomeHost={() => { setShowAddAvail(false); setShowAccess(true); }} onBack={() => setShowAddAvail(false)} />)),
    guide: () => (<LoungeGuide t={t} onBack={() => setShowGuide(false)}
      onDiscover={(sc) => { setShowGuide(false); setShowDisc(sc || {}); }} />),
    disc: () => (<Discovery t={t} lang={lang} session={session} scope={showDisc} onOpenProfile={setPubProfile} onBack={() => setShowDisc(null)} onMeet={() => { setShowDisc(null); setTab("meet"); }} onAddTrip={(av) => { setShowDisc(null); setPendingReqAvail(av && av.id ? av : null); setShowAddVisit(true); }} onVerify={() => { setShowDisc(null); setShowVerify(true); }} />),
    chat: () => (<Chat t={t} session={session} request={chat.req} otherName={chat.name} openPanel={chat.openPanel} onBack={() => setChat(null)} onReferral={() => { setChat(null); setShowRef(true); }} onOpenProfile={(id) => setPubProfile(id)} onReport={(id, nm) => setReport({ targetId: id, targetName: nm, sessionId: null })}
      /* 🔴 v1.75: onLiveStatus HİÇ GEÇİLMEMİŞTİ — "Canlı Durum" düğmesi bu
         yüzden hiçbir şey yapmıyordu. */
      onLiveStatus={(sid) => { setShowLive(sid || true); }}
      onSafety={() => setShowSafety(true)} />),
  };
  // 🔴 v2.47 — KESFET'TE BOTTOM BAR (cihazda istendi). Kesfet bir
  // overlay ama urunun ana gezinti duraklarindan biri gibi kullaniliyor;
  // tab cubugu olmadan kullanici "cikis yolu geri tusu" saniyordu.
  // Yalniz disc overlay'i tab cubuguyla sarilir; tab'a basmak overlay'i
  // kapatip o sekmeye goturur. Diger overlay'ler tam ekran kalir.
  // v2.48 — Keşfet→Seyahat onay kartı (her görünümün üstünde çizilir)
  const askApplyModal = askApply ? (
    <Modal visible transparent animationType="fade" onRequestClose={() => { setAskApply(null); setPendingReqAvail(null); }}>
      <View style={{ flex: 1, backgroundColor: C.perde, justifyContent: "center", padding: ARA[28] }}>
        <View style={{ backgroundColor: C.card, borderRadius: R.md, padding: ARA[22] }}>
          <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink }}>{t.tripReadyTitle}</Text>
          <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[2], lineHeight: 19 }}>
            {t.tripReadyBody.replace("{ap}", askApply.airport_code || "").replace("{dt}", askApply.avail_date || "")}
          </Text>
          <Btn v="gold" sm label={t.tripReadyApply} onPress={() => { const av = askApply; setAskApply(null); setPendingReqAvail(null);
                             setShowDisc({ airport: av.airport_code, focusAvail: av.id }); }} style={{ marginTop: SP[4] }} />
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setAskApply(null); setPendingReqAvail(null); }}
            style={{ alignItems: "center", marginTop: SP[3] }}>
            <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.tripReadyLater}</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  ) : null;

  // ══════════════════════════════════════════════════════════════════════
  // 🔴 v3.4 — KATMANLAR ARTIK SEKME AĞACINI SÖKMÜYOR. ÜÇ ŞİKÂYET, TEK KÖK.
  //
  // Gökberk (28 Ağu):
  //   · "çıkış yap butonu zaman zaman çalışmıyor. Özellikle profil tabında
  //      bir sayfaya girip geri döndükten sonraki İLK aksiyonda"
  //   · "bazı sayfalarda back yapınca direkt ana sayfaya falan dönüyo"
  //   · "app bir tık yavaş"
  //
  // Üçünün de sebebi bu satırdı:
  //     if (topOverlay) return (<View>{OVERLAY_VIEWS[topOverlay]()}</View>);
  //
  // Bu erken `return`, katman açıldığı anda SEKME AĞACININ TAMAMINI
  // ağaçtan düşürüyordu. Sonucu:
  //
  //   1) ÇIKIŞ DÜĞMESİ. Profil → Ayarlar → geri: `Profile` YENİDEN mount
  //      olur, `p` yeniden `null`dur ve ekran bir an `<Load/>` çizer.
  //      Kullanıcı "Çıkış yap"ın DURDUĞU yere basar — orada artık bir
  //      spinner vardır. Düğme bozuk değildi; O AN ORADA DEĞİLDİ.
  //
  //   2) GERİ TUŞU. Sekmenin kendi iç durumu (Meet'in alt sekmesi,
  //      listelerin kaydırma konumu, açık akordeonlar) sökülürken
  //      kayboluyordu; geri dönünce ekran "başa sarmış" görünüyor —
  //      "direkt ana sayfaya dönüyor" hissi buradan geliyor.
  //
  //   3) HIZ. Her katman kapanışı, o sekmenin BÜTÜN `useEffect`lerini
  //      yeniden koşturuyordu: Profil'de 6, Keşfet'te 5 sorgu. Yani
  //      "geri" tuşu, ölçülü 345 ms'lik turlardan yarım düzinesini
  //      yeniden ödetiyordu.
  //
  // 🆕 SINIF: "BİR KATMANI EKRANIN YERİNE KOYARSAN, ALTINDAKİ EKRANI DA
  // KAPATMIŞ OLURSUN — VE KULLANICI GERİ DÖNDÜĞÜNDE AYNI YERE DEĞİL,
  // AYNI YERİN YENİDEN KURULUŞUNA VARIR."
  //
  // Artık katman sekme ağacının ÜSTÜNE, mutlak konumlu ve opak olarak
  // çiziliyor. Alttaki sekme MONTE KALIYOR: durumu, kaydırması ve
  // yüklenmiş verisi yerinde duruyor. Geri dönüş anlıktır ve ilk dokunuş
  // gerçek bir düğmeye iner.
  //
  // `disc` (Keşfet) katmanı sekme çubuğunu görmeye devam ediyor — o bir
  // gezinti durağı gibi kullanılıyor (v2.47 kararı). Fark artık tek bir
  // bayrakla anlatılıyor, ayrı bir `return` dalıyla değil.
  // ══════════════════════════════════════════════════════════════════════
  // 4 Eylül — tasarım 10 (Bildirimler) da sekme çubuğunu gösteriyor: bir
  // gezinti durağı (Profil → Bildirimler), bir işin içi değil.
  const katmanCubuguGoster = topOverlay === "disc" || topOverlay === "notif";


  // MVP: TÜM roller 4 sekme. Host'ta 2. sekme "Yayın" (ilan yönetimi 📡);
  // Yayın & Davet ayrı sekme DEĞİL — Profil menüsünden açılır (MVP birebir).
  // ════════════════════════════════════════════════════════════════════
  // 🔴 v2.96 (eleştiri E2) — İKİNCİ SEKME ARTIK AD DEĞİŞTİRMİYOR.
  // Eski hâli role göre üç ayrı ad taşıyordu: "Yayın" / "Seyahat" /
  // "Keşfet". Aynı yerde üç farklı kelime.
  //
  // Ama ürünün kendi vaadi bunun tam tersi: "açtığın kapı, sana bir kapı
  // açar" — yani bir kişi HEM host HEM misafir olmalı. Rolü bir MOD gibi
  // kurgulamak, karşılıklılık vaadiyle doğrudan çelişiyordu. Üstelik host
  // olan biri de başka host'lara başvurabiliyor: yani "Yayın" adı zaten
  // sekmenin yarısını anlatmıyordu.
  //
  // 🆕 SINIF: "BİR SEKMENİN ADI KULLANICININ ROLÜNE GÖRE DEĞİŞİYORSA, O
  // SEKME İKİ AYRI ÜRÜNÜ AYNI YERE KOYMUŞ DEMEKTİR."
  //
  // Artık tek ad: PLANIM. İçinde iki alt sekme — İlanlarım · Seyahatlerim.
  // Host olmayan kullanıcı "İlanlarım"a bastığında boş bir liste değil,
  // MERDİVENİ görüyor (host_daveti · SQL 249). Yani host dönüşümünün en
  // doğal yeri de burası oldu.
  // 🔴 v3.4 — SEKME İKONLARI ARTIK SEMBOL DEĞİL, İKON.
  // Eskisi: ⌂ ◇ ◈ ◉ — dördü de gövde fontundan gelen geometrik
  // karakterlerdi. Cihaz onları harf gibi çiziyordu: "Profil"in ◉'si
  // ekran görüntüsünde bir GÖZ gibi, "Planım"ın ◇'i içi boş bir baklava
  // gibi görünüyordu. Hiçbiri o sekmenin ne olduğunu anlatmıyordu.
  //
  // 🆕 SINIF: "BİR SEKME İKONU SÜS DEĞİL ETİKETTİR — TARİF ETMİYORSA
  // ORADA OLMASININ BİR SEBEBİ YOKTUR."
  //
  // Seçili sekme DOLU, seçili olmayan ÇİZGİ: rengin yanında ikinci ve
  // renk körlüğünden bağımsız bir "buradasın" işareti.
  const tab2 = ["trips", "plan", t.navPlan];
  // 🔴 v3.6 — ÜRÜNÜN ÇEKİRDEK EYLEMİNİN KALICI BİR ADRESİ YOKTU.
  //
  // `navDisc` ("Keşfet") i18n'de iki dilde yazılıydı ve HİÇBİR sekme
  // onu kullanmıyordu. Keşfet'e yalnız ana sayfadaki bir CTA'dan ya da
  // bir kartın içinden giriliyordu — yani misafirin ürünle kurduğu tek
  // ilişki ("bugün hangi salona girebilirim?"), üründe kalıcı bir yeri
  // olmayan tek eylemdi. Kullanıcı geri döndüğünde onu ARAMAK zorunda
  // kalıyordu; arayan kullanıcı ikinci kez aramaz.
  //
  // 🆕 SINIF: "BİR ÜRÜNÜN ÇEKİRDEK EYLEMİ, GEZİNTİDE KALICI BİR ADRESE
  // SAHİP DEĞİLSE, O EYLEM ÜRÜNÜN DEĞİL O EKRANIN ÖZELLİĞİDİR."
  //
  // ⚠️ KATMAN YOLU DOKUNULMADAN DURUYOR: kapsamlı açılışlar (bir
  // seyahate bağlı "bu tarihte host bul") hâlâ `showDisc` katmanı.
  // Sekme yalnız kapsamsız (genel) keşfi açar. İki yol tek bileşene
  // çıkıyor; ikinci bir kopya YAZILMADI.
  const tabs = [
    ["home", "ana", t.navHome],
    ["disc", "kesfet", t.navDisc],
    tab2,
    ["meet", "tanis", t.navMeet],
    ["prof", "profil", t.navProfile],
  ];
  // Marka cubugunun sag kosesi: zil + dil — ozellikler korunuyor,
  // MVP'nin marka cubugu cercevesine tasindi.
  const brandRight = (
    <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[10] }}>
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => setShowNotif(true)} style={{ position: "relative", padding: ARA[2] }}
        accessibilityRole="button"
        accessibilityLabel={(t.notifTitle || "Bildirimler") + (unread > 0 ? " · " + unread : "")}>
        <Ikon ad="bildirim" boy={19} renk={C.goldText} />
        {unread > 0 && <View style={{ position: "absolute", top: -3, right: -5, backgroundColor: C.dangerBtn, borderRadius: R.xs, minWidth: 14, height: 14, alignItems: "center", justifyContent: "center", paddingHorizontal: ARA[2] }}>
          <Text style={{ color: C.onAccent, fontSize: FS.micro, fontWeight: "600" }}>{unread > 9 ? "9+" : unread}</Text>
        </View>}
      </TouchableOpacity>
      <TouchableOpacity hitSlop={TAP.slop} onPress={toggleLang}
      accessibilityRole="button"
      accessibilityLabel={lang === "tr" ? "Switch to English" : "Türkçeye geç"}
      style={{ borderColor: C.gold, borderWidth: 1, borderRadius: R.sm, paddingVertical: ARA[2], paddingHorizontal: SP[2] }}>
        <Text style={{ color: C.gold, fontWeight: "600", fontSize: FS.xs }}>{lang === "tr" ? "EN" : "TR"}</Text>
      </TouchableOpacity>
    </View>
  );
  // v1.74: rol/sözleşme eksikse önce tamamlama ekranı (sosyal giriş yolu).
  if (needsOnb) return (
    <CompleteOnboarding t={t} session={session}
      onDone={() => setNeedsOnb(false)}
      onLogout={handleLogout} />
  );

  return (
    // 🔴 SEKME KABUĞU ATMOSFERİ TAŞIYOR — ve bu bir ÖLÇÜMÜN sonucu.
    // 38 ekran kökünü <Sayfa>'ya çevirdikten sonra nöbetçi üç ekranı
    // kırmızıya boyadı: Trips, LoungeGuide, BaglantiIstekleri. Sebep şuydu:
    // bu üçü sekme İÇERİĞİ ve kökleri <View> değil <ScrollView> — yani
    // kendi sayfalarını hiç boyamıyorlar, kabuğun zeminini kullanıyorlar.
    //
    // Doğru cevap onlara zorla <Sayfa> giydirmek değildi (ScrollView'ın
    // içine sayfa koymak yerleşimi bozardı); atmosferi ZEMİNİ KİM
    // BOYUYORSA ORAYA koymaktı. Sekme içerikleri için o yer burası.
    //
    // 🆕 SINIF: "BİR EKRAN ARKA PLANINI ÇİZMİYORSA EKSİK DEĞİLDİR —
    // ONU TAŞIYAN KABUĞU BULMAMIŞSINDIR."
    <Sayfa>
      {/* MVP cercevesi: her sekmenin tepesinde marka cubugu. Meet ve
          Trips/Hosting MVP'deki gibi serif baslik + ‹ (ana sayfaya doner)
          tasir; Ana Sayfa ve Profil yalniz marka cubugu tasir (MVP birebir). */}
      {/* 🔴 3 EYLÜL — ANA SEKMEDE KABUK BAŞLIK YOK: bandı `Home` kendisi
          çiziyor (FotoBant). Buradaki `<Hdr>` ikinci bir "LOUNGELINK"
          satırıydı (cihazda ölçüldü). Profil sekmesi de tasarımdaki
          bandı (09: "SELİN B. · İSTANBUL / Profil / dişli") `Profile`
          içinde çiziyor. */}
      {/* 🔴 BANT YALNIZ TARAMA YÜZEYLERİNDE. Ölçtüm: bant ekranın %22-27'sini
          kaplıyor (iPhone SE'de altında 3.5 ilan görünüyor). Bir LİSTE ekranında
          bu yer, göze nerede olduğunu söylüyor ve hak ediyor. Bir FORM ekranında
          aynı yer doldurulacak alanlardan çalınmış olurdu.
          Ekranları sınıflandırdım (giriş alanı sayısı / liste sayısı / kart
          sayısı): tarama yüzeyi üç tane — Keşfet · Tanış · Seyahatler.
          Ayarlar, Profili Düzenle, Doğrulama, Sohbet HARİÇ. */}
      {/* 🔴 v3.4 — "İKİ TANE TANIŞ YAZIYOR" (Gökberk).
          Haklıydı ve sebep basitti: `title={t.meetTitle}` ("Tanış") ile
          `foto.ustBilgi={t.navMeet}` ("Tanış") AYNI kelimeyi iki kez
          basıyordu — biri iri serif başlık, biri onun üstündeki etiket.
          İkisi de aynı şeyi söyleyince etiket bilgi taşımıyor, gürültü
          yapıyor.
          Etiketin işi BAĞLAM vermek (Keşfet'te "IST · 27 Ağustos" yazıyor).
          Burada doğru bağlam AKTİF ALT SEKME: Keşfet · Bağlantılar ·
          İstekler. Böylece başlık "neredeyim", etiket "hangi bölümdeyim"
          diyor.
          🆕 SINIF: "BİR ETİKET BAŞLIĞIN AYNISINI YAZIYORSA O BİR ETİKET
          DEĞİL, BOŞA HARCANMIŞ BİR SATIRDIR." */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 3 EYLÜL — TANIŞ BANDI TASARIM 05/13:
            05  AYNI LOUNGE'DAKİ YOLCULARLA BAĞLAN / Tanış      (sağda hiçbir şey)
            13  KISA BİR NOT EKLE — KARŞILIKLI ONAYLA / Bağlantılarım (geri oku)
          Geri oku, "Filtre" hapı, zil ve EN pili banttan çıktı — tasarımda
          yoklar. Filtre işi 05'in üç çipinde (Uçuş/Salon/Rota, Meet içinde);
          bildirimler Profil > Bildirimler ve Akışım'da; dil Ayarlar'da. */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 13 EYLÜL (Gökberk md.7 · KRİTİK) — "Bağlantılarım sayfasına
          doğrudan Tanış üzerinden erişemiyorum artık… Planım tabındaki
          gibi header alanında iki sekme oluşturabiliriz."
          Ölçtüm ve haklıydı: `Meet` içinde iki alt görünüm VAR (`discover`
          / `conns`) ama BANTTA HİÇBİR GEÇİŞ YOKTU. "conns"a yalnız ana
          sayfadaki Sohbet kutusundan girilebiliyordu; sekmeye basınca
          `discover`a düşüyor ve geri dönüş yolu kalmıyordu.
          Çözüm onun önerdiği gibi ve Planım'la AYNI desen: çipler bandın
          içinde (`altIcerik`), tasarım 14b/12c ile birebir.
          🆕 SINIF: "BİR EKRANIN İKİ GÖRÜNÜMÜ VARSA VE ARALARINDA GEÇİŞ
          YOKSA, İKİNCİSİ EKRAN DEĞİL ÖLÜ BİR DALDIR."
          ══════════════════════════════════════════════════════════════ */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 19 EYLÜL · DERİN DENETİM — ROL OKUNAMADIĞINDA ŞERİT.
          `role` ürünün hangi yüzeylerinin VAR OLDUĞUNA karar veriyor.
          Üç deneme de düşerse eskiden hiçbir şey olmuyordu: host
          "İlanlarım"ı kaybediyor ve sebebini hiçbir yerde göremiyordu.
          Önbellekteki rol varsa o korunuyor (yukarıda) — bu şerit
          yalnız gerçekten bilinmeyen durumda çiziliyor.
          ══════════════════════════════════════════════════════════════ */}
      {rolHatasi && (
        <View style={{ backgroundColor: C.amberBg, borderBottomWidth: 1, borderBottomColor: C.amber,
                       paddingVertical: ARA[10], paddingHorizontal: ARA[18],
                       flexDirection: "row", alignItems: "center", gap: SP[3] }}>
          <Text style={{ flex: 1, color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.roleLoadFail}</Text>
          <TouchableOpacity hitSlop={TAP.slop} accessibilityRole="button" accessibilityLabel={t.retry}
            onPress={() => { setRolHatasi(false); setRolTekrar(x => x + 1); }}
            style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
            <Text style={{ color: C.amberInk, fontWeight: "700", fontSize: FS.sm }}>{t.retry}</Text>
          </TouchableOpacity>
        </View>
      )}
      {tab === "meet" && <Hdr t={t} kaydir={bntMeet.kaydir}
        onBack={sekmeGeri ? sekmeGeriDon : undefined}
        title={meetSub === "discover" ? t.meetTitle : meetSub === "reqs" ? t.connRequestsTitle : t.myConnections}
        foto={{ ustBilgi: meetSub === "discover" ? t.meetSub : t.connBandEyebrow,
                olc: bntMeet.olc, tam: bntMeet.tam,
                altIcerik: (
                  /* ══════════════════════════════════════════════════
                     🔴 19 EYLÜL (Gökberk md.13 · ONAYLANDI) — ÜÇÜNCÜ ÇİP.
                     "gönderdiğim istekler ve mevcut bağlantılarım
                      'gönderdiklerin' altında toplanmış; mevcut
                      bağlantılarım / bağlantı isteklerim (gelen,
                      gönderilen) şeklinde alt sekmelere ayıralım"
                     Ölçüm: `"reqs"` değeri kodda VARDI (yorumda üç değer
                     vaat ediliyordu) ama ne çipi ne render dalı vardı;
                     sessizce `else`e düşüp "conns" ile aynı listeyi
                     çiziyordu. Artık üç çip, üç gerçek görünüm.
                     ══════════════════════════════════════════════════ */
                  <View style={{ flexDirection: "row", gap: ARA[8], marginTop: ARA[12] }}>
                    {[["discover", t.meetTitle], ["conns", t.myConnections], ["reqs", t.connRequestsTitle]].map(([k, lb]) => (
                      <Cip key={k} etiket={lb} secili={meetSub === k} onPress={() => setMeetSub(k)} />
                    ))}
                  </View>
                ) }} />}
      {tab === "trips" && (() => {
        /* misafirde `hostTripsSub` "ilan" kalmış olabilir (derin bağlantı);
           sekme başlığı ve çip seçimi rolü de sorar — tek karar. */
        const ilanSekmesi = role === "host" && hostTripsSub === "ilan";
        /* 5 Eylül — çipler BANDIN İÇİNDE (onaylı 14b/12c). Misafirde çip yok:
           v3.4 kararı ("misafir ilan yüzeyi görmez") + Gökberk 5 Eylül madde 6;
           tek çipli satır anlamsız olurdu, başlık zaten "Seyahatlerim". */
        const cipler = role === "host" ? (
          <View style={{ flexDirection: "row", gap: ARA[8], marginTop: ARA[12] }}>
            {[["seyahat", t.subTabTrips], ["ilan", t.subTabListings]].map(([k, lb]) => (
              <Cip key={k} etiket={lb} secili={ilanSekmesi ? k === "ilan" : k === "seyahat"}
                onPress={() => { setAltSekmeKuruldu(true); setHostTripsSub(k); }} />
            ))}
          </View>
        ) : null;
        return (
          <Hdr t={t} title={ilanSekmesi ? t.subTabListings : t.subTabTrips} kaydir={bntTrips.kaydir}
            onBack={sekmeGeri ? sekmeGeriDon : undefined}
            foto={{ ustBilgi: ilanSekmesi ? t.hostingSub : t.tripsSub, altIcerik: cipler,
                    olc: bntTrips.olc, tam: bntTrips.tam }} />
        );
      })()}
      <View style={{ flex: 1 }}>
        {/* 🔴 18 EYLÜL (md.1 · md.6) — `key` ORTAK TAZELEME ANAHTARINA
            BAĞLANDI. Davet/bağlantı katmanında verilen cevap `setReload`
            çağırıyor; ana sayfa da o cevabı görmeden bayat kalıyordu.
            `Discovery`/`Hosting`/`Trips` zaten bu anahtarı taşıyordu. */}
        {tab === "home" && <Home key={"hm" + reload} t={t} lang={lang} session={session} onOpenChat={setChat} onProfilSekmesi={() => setTab("prof")} onOpenCompanion={(cid, nm) => setCompChat({ channelId: cid, name: nm })} onVerify={() => setShowVerify(true)} onRole={setRoleState} setRadar={setRadar} setTab={sekmeyeGit} setHostTripsSub={setHostTripsSub} onWallet={() => setShowWallet(true)} onDiscover={(sc) => setShowDisc(sc || {})} onOpenProfile={setPubProfile} setShowQuestions={setShowQuestions} onGuide={() => setShowGuide(true)}
          setShowIstekler={setShowIstekler}
          setShowDavetler={setShowDavetler} setShowSohbetler={setShowSohbetler} />}
        {/* Sekme olarak Keşfet: kapsamsız. `onBack` YOK — bir sekmenin
            geri oku olmaz (bkz. `dal_prop_check.py` gerekçeli istisna). */}
        {tab === "disc" && <Discovery key={"dsc" + reload} t={t} lang={lang} session={session} scope={null}
          onOpenProfile={setPubProfile}
          onMeet={() => setTab("meet")}
          onAddTrip={(av) => { setPendingReqAvail(av && av.id ? av : null); setShowAddVisit(true); }}
          onVerify={() => setShowVerify(true)} />}
        {/* 🔴 v3.4 — `hostTripsSub` guest'te "ilan" olamaz. Sekme
            çizilmiyor ama derin bağlantı (bildirim) onu "ilan"a
            ayarlayabiliyordu (App.js · bildirim yönlendirmesi). O yüzden
            burada da rol soruluyor: iki kapı, tek karar.
            🆕 SINIF: "GÖRÜNMEYEN BİR SEKMEYE DERİN BAĞLANTIYLA
            GİRİLEBİLİYORSA O SEKME KAPALI DEĞİL SADECE GİZLİDİR." */}
        {/* 🔴 13 EYLÜL · NOT2 (ikinci bulgu) — `HostDaveti` DALI ÖLÜYDÜ.
            Koşul şöyleydi:
                hostTripsSub === "ilan" && role === "host"
                  ? (role === "host" ? <Hosting/> : <HostDaveti/>)
                  : <Trips/>
            Dış koşul zaten `role === "host"` istiyor; yani iç `else`
            dalına GİRİLMESİ İMKÂNSIZ. v2.96'nın "host olmayana merdiveni
            göster" kararı kodda duruyor, erişilemiyordu — ve 4 Eylül
            notu "host daveti İlanlarım çipinin arkasında" diyor, oysa
            arkasında `Trips` vardı.
            Düzeltme: rol sorusu YALNIZ içte. Misafirde çip hâlâ YOK
            (v3.4 + 5 Eylül madde 6 — onaylı tasarım değişmiyor); ama
            bildirimden gelen derin bağlantı "ilan"a düştüğünde artık
            sessizce yanlış ekranı değil, MERDİVENİ açıyor.
            🆕 SINIF: "BİR KOŞULU İKİ KEZ SORMAK ONU GÜVENLİ YAPMAZ —
            İÇTEKİ SORUYU ANLAMSIZ, ONA BAĞLI DALI ÖLÜ YAPAR." */}
        {tab === "trips" && (hostTripsSub === "ilan"
          ? (role === "host"
              ? <Hosting key={"h" + reload} t={t} lang={lang} session={session} onOpenChat={setChat} onAddAvail={() => setShowAddAvail(true)} onAddCard={() => setShowAccess(true)} onEditAvail={(a) => setEditAvail(a)} bnt={bntTrips}
                  focusAvailId={odakAvail} onFocusDone={() => setOdakAvail(null)} />
              /* 🔴 v2.96 (eleştiri A1) — HOST OLMAYANA MERDİVENİ GÖSTER.
                 Ölçtüm: host'a verdiğimiz karşılıkların HEPSİ zaten kurulu
                 (mertebeler, sıralama önceliği, 2 ağırlamada 30 gün ücretsiz
                 üst plan) ama hiçbiri host OLMAYAN kişiye görünmüyordu.
                 🆕 SINIF: "BİR MERDİVENİ YALNIZCA ÜZERİNDE DURANLARA
                 GÖSTERİRSEN, KİMSE İLK BASAMAĞA ÇIKMAZ." */
              : <HostDaveti t={t} onBecomeHost={() => setShowAccess(true)} />)
          /* 🔴 v2.65 · PROP-DROP: burada onAddVisit geçiliyordu ama Trips'in
             imzasında öyle bir prop YOK — o yüzden misafir tarafında
             "+ Seyahat ekle" eski SATIR-İÇİ formu açıyordu, host tarafında
             ise yeni AddVisit ekranı. Aynı düğme iki kullanıcıya iki farklı
             ürün gösteriyordu. Doğru ad: onAddTrip. */
          : <Trips key={"tr" + reload} t={t} lang={lang} session={session} onAddTrip={(av) => { setPendingReqAvail(av && av.id ? av : null); setShowAddVisit(true); }} onDiscover={(sc) => setShowDisc(sc)} onEditTrip={(v) => setEditTrip(v)} bnt={bntTrips} />)}
        {/* 4 Eylül — Trips artık yalnız tasarım 14'ü çiziyor: host daveti
            (v3.4 merdiveni) "İlanlarım" çipinin arkasında (misafirde Lounge
            erişim kurulumunu açar), rehber Ana Sayfa'da, sohbet İstekler'de. */}
        {tab === "meet" && <Meet t={t} lang={lang} session={session} rol={role} onOpenProfile={setPubProfile} onOpenChat={(channelId, name) => setCompChat({ channelId, name })} radarFilter={radar} onClearRadar={() => setRadar(null)} onRequestListing={(av) => setShowDisc({ airport: av.airport_code, focusHost: av.host_id, focusAvail: av.id })} onVerify={() => setShowVerify(true)} onAddTrip={(av) => { setPendingReqAvail(av && av.id ? av : null); setShowAddVisit(true); }} filtersOpen={meetFilterOpen} setFiltersOpen={setMeetFilterOpen} altSekme={meetSub} setAltSekme={setMeetSub} bnt={bntMeet} />}
        {/* 5 Eylül — profil bandı artık Profile'ın kendisinde (kimlik + şerit
            bandın içinde; veri orada). */}
        {tab === "prof" && <Profile t={t} refresh={profRefresh} session={session} onManagePlan={() => setShowPlans(true)} onSafety={() => setShowSafety(true)} onTrust={() => setShowTrust(true)} onHistory={() => setShowHist(true)} onReferral={() => setShowRef(true)} onRatings={() => setShowRatings(true)} onWallet={() => setShowWallet(true)} onLogout={handleLogout} onShop={() => setShowShop(true)} onSettings={() => setShowSettings(true)} onCampaigns={() => setShowCamps(true)} onBroadcast={() => setShowBc(true)} onBell={() => setShowNotif(true)} onEditProfile={() => setShowEditProf(true)} />}
      </View>
      {/* ============================================================
          MVP v15 Nav() satir 344: cubuk BEYAZ (cBM) + ustte ince cizgi,
          aktif tab ALTIN, pasif cDM (#9CA3AF). Bizde lacivert zemindi.
          Profil tab'inda okunmamis bildirim rozeti — MVP'de kirmizi (cRS).
          ============================================================ */}
      {/* 🔴 30 AĞUSTOS · GECE SİSTEMİ — ÇUBUK ÖLÇÜLERİ TASARIMDAN.
          Tasarımdaki çubuk dolgusu 11/8/22, zemini gecenin %94'ü;
          sekme içi boşluk beş, gösterge üstte eksi yedi, etiket 9.5/600.
          🔴 VE BİR DÜZELTME: ilk denememde zemini `C.gece` yaptım ve
          önizlemede çubuk KAHVERENGİ çıktı. Ölçtüm: koyu temada
          `C.gece` — o bir "gece" değil, açık temadaki koyu yüzeyin adı
          ve koyu temada SICAK BİR KAHVE. Tasarımdaki `rgba(...,.94)` ise
          sayfanın KENDİ zemininin (`C.bg`) neredeyse opak hâli.

          🆕 SINIF: "BİR JETONUN ADI ONUN DEĞERİNİ GARANTİ ETMEZ —
          'gece' ADINI TAŞIYAN BİR RENK, BAŞKA BİR TEMADA GECE
          OLMAYABİLİR. ADI DEĞİL DEĞERİ ÖLÇ."

          Doğru jeton `C.bg`: gövdeyle aynı zemin, üstünde 1px çizgi.
          Liste `C.surface` kartlarla akıyor; çubuk onların ALTINDAKİ
          zemine oturuyor ve bu ayrımı çizgi yapıyor. */}
      <View style={{ flexDirection: "row", backgroundColor: C.bg,
                     borderTopWidth: 1, borderTopColor: C.line,
                     paddingBottom: ARA[22], paddingTop: ARA[12], paddingHorizontal: ARA[8] }}>
        {tabs.map(([k, ic, lab]) => {
          const on = tab === k;
          return (
            <TouchableOpacity hitSlop={TAP.slop} key={k} style={{ flex: 1, alignItems: "center", paddingVertical: ARA[2] }}
              onPress={() => {
                // Çubuğu gösteren katman (Keşfet/Bildirimler) açıkken sekmeye
                // dokunmak önce o katmanı kapatır — yoksa dokunuş sessiz kalır
                // (ölçüldü: katman sekme ağacının üstünde, sekme altta değişiyordu).
                if (katmanCubuguGoster && topOverlay) OVERLAYS[topOverlay][1]();
                if (k === "meet") setMeetSub("discover");
                // Alt çubuktan gelen geçiş bir SEKME değişimidir, bir
                // yönlendirme değil: geri oku silinir (md.8).
                setSekmeGeri(null);
                setTab(k);
              }}>
              {k === "prof" && unread > 0 && (
                <View style={{ position: "absolute", top: 0, right: "50%", marginRight: -22, minWidth: 15, height: 15,
                               borderRadius: R.full, backgroundColor: C.dangerBtn, alignItems: "center", justifyContent: "center", paddingHorizontal: ARA[2], zIndex: 2 }}>
                  <Text style={{ fontSize: FS.micro, color: C.onAccent, fontWeight: "600" }}>{unread > 9 ? "9+" : unread}</Text>
                </View>
              )}
              {/* ══════════════════════════════════════════════════════
                  🔴 30 AĞUSTOS · GECE SİSTEMİ — AKTİF SEKME GÖSTERGESİ
                  İkonun ÜSTÜNDE 3px altın çizgi. Sebebi referans sistemin
                  kararıyla aynı ve doğru: yalnız RENGİ değiştirmek yürürken
                  bakılan bir ekranda kaçar — altın ile gri arasındaki fark
                  hareket hâlinde ayırt edilmiyor. Çizgi KONUMU da bildiriyor,
                  yani ikinci bir kanal ekliyor.

                  🆕 SINIF: "TEK KANALLA (yalnız renk) ANLATILAN DURUM,
                  O KANALIN ZAYIFLADIĞI HER KOŞULDA ANLATILMAMIŞ SAYILIR."
                  ══════════════════════════════════════════════════════ */}
              <View style={{ width: 22, height: 3, borderRadius: R.full, marginBottom: ARA[6],
                             backgroundColor: on ? C.gold : "transparent" }} />
              <Ikon ad={on ? ic + "Dolu" : ic} boy={21} renk={on ? C.gold : C.dim} />
              <Text numberOfLines={1} style={{ fontSize: FS.micro, fontWeight: "600",
                                               letterSpacing: 0.3,
                                               color: on ? C.gold : C.dim, marginTop: ARA[6] }}>{lab}</Text>
            </TouchableOpacity>
          );
        })}
      </View>
      {askApplyModal}

      {/* KATMAN — sekme ağacının ÜSTÜNDE, opak. Alttaki sekme monte kalır.
          `disc` dışındaki katmanlar sekme çubuğunu da örter: onlar bir
          gezinti durağı değil, bir işin içidir.

          ⚠️ Katmanın `zIndex`i var, yükseltme (Android gölge jetonu) YOK:
          o jeton sıralamayı düzeltirken bir de GÖLGE çizer ve tam ekran
          opak bir katmanın gölgesi kenarlarda kir bırakır. RN `zIndex`i
          Android'de de kardeş sırasına uyguluyor, yani gerek de yok.
          (Kelimeyi stil nesnesinin içine yazmıyorum: `cihaz_parite_check.py`
          bloğu düz metin olarak tarıyor ve bir YORUMU da gölge sanıyor —
          nöbetçiyi zayıflatmaktansa açıklamayı dışarı aldım.) */}
      {topOverlay ? (
        <View
          pointerEvents="box-none"
          style={{
            position: "absolute", left: 0, right: 0, top: 0,
            bottom: katmanCubuguGoster ? CUBUK_YUKSEKLIK : 0,
            backgroundColor: C.paper,
            // ══════════════════════════════════════════════════════════
            // 🔴 12 EYLÜL — KATMAN, ALTINDAKİ EKRANIN BANDININ ALTINDA
            // KALIYORDU.
            // Sahnede yakalandı: 06b_sohbet_tanis'te ekranın başlığı
            // "Ece Y." olmalıyken "Bağlantılarım" yazıyordu. DOM'u
            // ölçtüm: sohbetin kendi başlığı y=57'de, "Profili görüntüle"
            // y=105'te, güvenlik şeridi y=136'da GERÇEKTEN ÇİZİLİYOR —
            // ama Tanış sekmesinin fotoğraflı bandı (ui.js:1255,
            // `zIndex: 5`) onların üstüne biniyordu. Katmanın z'si yoktu;
            // CSS'te z'si olan, olmayanı DOM sırasından bağımsız yener.
            // Yani kullanıcı yanlış başlık görüyor, güvenlik şeridini ve
            // "Bildir" düğmesini HİÇ göremiyordu.
            // 🆕 SINIF: "ÜSTE ÇİZİLMESİ GEREKEN KATMANA Z VERMEZSEN, EN
            // ÜSTTE OLAN KATMAN DEĞİL Z'Sİ OLAN HERHANGİ BİR ŞEY OLUR."
            // ══════════════════════════════════════════════════════════
            zIndex: 20,
          }}>
          {OVERLAY_VIEWS[topOverlay]()}
        </View>
      ) : null}
    </Sayfa>
  );
}

// Alt sekme çubuğunun yüksekliği (paddingTop 8 + ikon 22 + etiket + 20).
// Katman `disc` iken çubuğun üstünde bitmeli; sayı tek yerde dursun ki
// çubuk değişirse katman da onunla değişsin.
const CUBUK_YUKSEKLIK = 76;

function Onboarding({ t, onDone }) {
  const [i, setI] = useState(0);
  const slides = t.onbSlides || [];
  const s = slides[i] || {};
  // 🔴 v2.43 — SON ADIM ARTIK CANLI BIR SORU.
  // Onceki hali "Başla" ile bitiyordu: kullanici degeri GORMEDEN
  // kaydolmaya davet ediliyordu. Oysa elimizde Turkiye'de kimsenin
  // veremedigi bir cevap var — kaydolma duvarini degerin ARKASINA
  // koymak, onune koymaktan her zaman iyidir.
  // 🔴 v2.50 (Gokberk): KART SORUSU TANITIMDAN ALINDI.
  // v2.43'te "değeri kaydolmadan göster" diye buraya konmuştu; doğru
  // niyet, yanlış yer: cevap HİÇBİR YERE YAZILMIYORDU. Kullanıcı kartını
  // seçiyor, kaydoluyor ve uygulama onu tekrar soruyordu. Aynı soruyu iki
  // kez sormak, ilk sorunun ciddiye alınmadığını söyler.
  // Artık kart seçimi KAYITTAN HEMEN SONRA sorulur ve gerçek hakka
  // (host_entitlements + profil erişim kaynağı) dönüşür.
  // 🔴 KRİTİK HATA (Gökberk madde 2): "tüm tanıtım ekranlarında aynı
  // şey var". Sebep burasıydı. v2.50'de kart adımı kaldırılırken
  // `askStep = -1` yazılmış ve `last = i === askStep` bırakılmış.
  // i hiçbir zaman -1 olamaz → last DAİMA false → buton hep setI(i+1)
  // yapıyor, onDone() ASLA çağrılmıyor. Dizi bitince slides[i] undefined
  // oluyor ve ekran boş bir kabuğa dönüşüyor; kullanıcı aynı boş ekranı
  // tekrar tekrar görüyor ve tanıtımdan ÇIKAMIYOR.
  // Ders: bir adımı kaldırırken ona bağlı BİTİŞ KOŞULUNU da güncelle.
  // 🔴 v2.66 (Gökberk madde 2, HÂLÂ CANLI): "tüm tanıtım ekranları aynı".
  // v2.65 bitiş koşulunu düzeltti ama ASIL kırığı kaçırdı: aşağıdaki
  // dal koşulu `i < askStep` idi ve askStep = -1. `i` hiçbir zaman
  // -1'den küçük olamaz → SLAYT DALI HİÇ ÇİZİLMEDİ. Her adımda alt
  // daldaki kart sorusu ("Hangi lounge hakkın var?") basılıyordu;
  // slaytlar yazılmış ama ekrana HİÇ çıkmamıştı.
  // Ders: bir adımı kapatırken ona bağlı DAL koşulunu da güncelle —
  // v2.65'te bitiş koşulu için öğrenilen ders, dal koşulunda tekrarlandı.
  // 🔵 26 AĞUSTOS — `askStep`/`askOn` SİLİNDİ. İkisi de yalnız artık var
  // olmayan bir dalı kapalı tutmak içindi; dal gidince kapatacak bir şey
  // kalmadı. Yukarıdaki v2.50/v2.65/v2.66 notları DURUYOR: aynı hatanın üç
  // kez tekrarlandığı yer burasıydı ve tekrarın sebebi "kapalı ama duran"
  // bir daldı.
  // 🔴 11 EYLÜL — SON KART ARTIK BİR CEVAP.
  // v2.43'te kart sorusu tanıtıma konmuş, v2.50'de kaldırılmıştı ve
  // gerekçe HAKLIYDI: cevap hiçbir yere yazılmıyor, kullanıcı kaydolunca
  // aynı soru tekrar soruluyordu. Bu sefer soru DEĞİL, CEVAP koyuyoruz:
  // hiçbir şey kaydedilmiyor, hiçbir şey sorulmuyor — üç karta resmî
  // tablodan cevap gösteriliyor. Kaydolma duvarı değerin arkasında kalıyor
  // ve boş Keşfet'in ("soğuk başlangıç") panzehiri ilk 30 saniyede veriliyor.
  // 🆕 SINIF: "BİR ADIMI KALDIRMANIN GEREKÇESİ 'YANLIŞ YERDEYDİ' İSE,
  // DOĞRU YERİ ARAMAYI BIRAKMA — KALDIRMAK BİR ÇÖZÜM DEĞİL BİR ERTELEMEDİR."
  const kartlar = Array.isArray(t.onbKartlar) ? t.onbKartlar : [];
  const [kartI, setKartI] = useState(0);
  const last = i >= Math.max(0, slides.length - 1);
  const kartAdimi = last && kartlar.length > 0;
  const secili = kartlar[kartI] || null;
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      if (i > 0) { setI(i - 1); return true; }
      return false; // ilk slaytta geri = cikis (Android standardi)
    });
    return () => h.remove();
  }, [i]);
  // 🔴 11 EYLÜL — TANITIM SPLASH'İN DÜNYASINA GERİ DÖNDÜ.
  // Gökberk: "onboardingde biraz eksik ve sade kaldığımızı düşünüyorum…
  // app'e girdiğinde heyecan duyuracak onboardingler lazım."
  // Ölçülebilir kusur şuydu: `Splash` tam ekran fotoğraf + serif slogan
  // veriyor, hemen SONRAKİ ekran fotoğrafı tamamen bırakıp düz koyu
  // zeminde 84px'lik bir daire ikona düşüyordu. Vaat bir ekran sonra
  // sönüyordu. Artık `FotoSahne` — Splash'le BİREBİR aynı bileşen — ve
  // her kartta kadraj kayıyor (`odak`): geniş çerçeve → pencereye
  // yakınlaşma → buluta çıkış. Tek kare bakınca fark edilmez, kaydırınca
  // kamera hareket ediyor gibi olur.
  // 🆕 SINIF: "BİR AKIŞIN İLK EKRANI BİR SÖZ VERİR; İKİNCİ EKRAN O SÖZÜ
  // YA SÜRDÜRÜR YA DA GERİ ALIR — ARASI YOKTUR."
  const odaklar = [0.12, 0.34, 0.52, 0.70, 0.86];
  // ══════════════════════════════════════════════════════════════════
  // KADRAJ VE METİN GİRİŞİ — 12 Eylül · akşam
  //
  // Gökberk: "harfler ekrana ipeksi bir duman efektiyle (fade-in +
  // slight blur) sırayla akmalı."
  //
  // ⚠️ DÜRÜST SINIR: RN'de METNE blur uygulanamaz (`filter: blur` yok,
  // `expo-blur` bir YÜZEY bulanıklaştırır, harfleri değil). "Duman"ın
  // RN'deki karşılığını üç kanalla kurdum ve üçü de native driver'a
  // girer: opaklık 0→1, 14pt aşağıdan yukarı süzülme, ve ÜST BLOK İLE
  // ALT BLOK ARASINDA 160ms GECİKME. Gözün "sırayla aktı" dediği şey
  // zaten bu gecikmedir; bulanıklık onun süsüdür.
  //
  // 🆕 SINIF: "BİR EFEKTİ TAKLİT EDERKEN GÖRÜNTÜSÜNÜ DEĞİL İŞLEVİNİ
  // KOPYALA — 'DUMAN' BİR PİKSEL İŞLEMİ DEĞİL, BİR ZAMANLAMADIR."
  const odakA = useRef(new Animated.Value(odaklar[0])).current;
  const gir1 = useRef(new Animated.Value(1)).current;   // üst blok
  const gir2 = useRef(new Animated.Value(1)).current;   // alt blok
  useEffect(() => {
    gir1.setValue(0); gir2.setValue(0);
    Animated.timing(odakA, {
      toValue: odaklar[Math.min(i, odaklar.length - 1)],
      duration: 760, easing: Easing.inOut(Easing.cubic), useNativeDriver: true,
    }).start();
    Animated.stagger(160, [
      Animated.timing(gir1, { toValue: 1, duration: 480, delay: 80,
                              easing: Easing.out(Easing.cubic), useNativeDriver: true }),
      Animated.timing(gir2, { toValue: 1, duration: 520,
                              easing: Easing.out(Easing.cubic), useNativeDriver: true }),
    ]).start();
  }, [i]);
  const suzul = (v) => ({ opacity: v,
    transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }] });
  // ══════════════════════════════════════════════════════════════════
  // KAYDIRARAK GEÇİŞ — 12 Eylül · 3. tur
  // Gökberk parallax'ı "kullanıcı sayfaları KAYDIRDIKÇA" diye tarif
  // etti; bizde geçiş yalnız "Devam" düğmesindeydi. Bir tanıtım akışının
  // kaydırılabilir olmaması, kullanıcının ilk refleksini boşa çıkarır.
  // `PanResponder` RN çekirdeğinde — yeni bağımlılık yok.
  // Eşik 45pt: daha azı liste kaydırmasıyla karışır, daha fazlası
  // "çalışmıyor" hissi verir. Yatay hareket dikeyin 1.6 katı olmalı ki
  // parmağın eğik kayması yanlış yöne sayfa çevirmesin.
  // 🆕 SINIF: "BİR JESTİ EKLEMEK YETMEZ — HANGİ JESTLE KARIŞACAĞINI
  // BULUP ARALARINA ÖLÇÜLMÜŞ BİR EŞİK KOYMADAN O JEST GÜVENİLİR DEĞİLDİR."
  const kaydirici = useRef(PanResponder.create({
    onMoveShouldSetPanResponder: (_e, g) =>
      Math.abs(g.dx) > 12 && Math.abs(g.dx) > Math.abs(g.dy) * 1.6,
    onPanResponderRelease: (_e, g) => {
      if (g.dx < -45) setI((o) => Math.min(o + 1, slides.length - 1));
      else if (g.dx > 45) setI((o) => Math.max(o - 1, 0));
    },
  })).current;
  // 🔴 12 EYLÜL · AKŞAM — PERDE TAM KAPANIYOR (0.94 → 1.0).
  // Gökberk: "alttaki gri alan biraz uyumsuz ve dikkat çekici duruyor."
  // Ölçtüm ve şikâyet ton değil HUE meselesiymiş: perde %94'te kalınca
  // fotoğrafın soğuk kabin mavisi %6 sızıyor ve en alt şerit #1D1E29
  // çıkıyor — sayfayla ΔE 11.63, hue 289° (mor-mavi) vs sayfanın 324°,
  // kroma 8.01 vs 0.51. Yani ekranın dibinde 16 kat doymuş, SOĞUK bir
  // bant duruyordu; obsidyen zemin sıcak-nötr olduğu için göz bunu
  // "gri leke" diye okuyor.
  // Perde 1.0'a çıkınca dip tam `C.bg` oluyor; rampanın şekli değişmiyor,
  // yalnız sonu kapanıyor.
  // 🆕 SINIF: "BİR LEKENİN SEBEBİNİ PARLAKLIKTA ARARKEN HUE'YU UNUTMA —
  // GÖZ, AYNI AÇIKLIKTAKİ YABANCI BİR TONU LEKE DİYE OKUR."
  return (
    <FotoSahne perdeBas={0.24} perdeGuc={1} odakAnim={odakA}>
    <View style={{ flex: 1 }} {...kaydirici.panHandlers}>
    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between",
                   paddingTop: TOPPAD + ARA[20], paddingHorizontal: ARA[22] }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "700", letterSpacing: 4.6, color: C.foto.marka }}>LOUNGELINK</Text>
    </View>

    {/* METİN BLOĞU ALTTA — tasarım 15'te ortadaydı, ama orada fotoğraf
        yoktu. Fotoğrafın üstünde metin ortaya konursa pencerenin en açık
        bölgesine denk geliyor (sitede ölçtük: başlık 2.48:1'e düşüyordu).
        Altta perde tam değerine ulaşıyor ve kontrast ölçülebilir oluyor. */}
    <View style={{ flex: 1 }} />
    <View style={{ paddingHorizontal: ARA[22] }}>
      {kartAdimi ? (
        <>
          <Animated.View style={suzul(gir1)}>
            <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2.4,
                           color: C.gold }}>{BUYUK(t.onbKartSoru)}</Text>
            <Text style={{ fontSize: FS.hero, fontWeight: "700", color: C.foto.baslik,
                           letterSpacing: -1.2, lineHeight: 38, marginTop: ARA[8] }}>{t.onbKartBaslik}</Text>
          </Animated.View>
          <Animated.View style={[{ flexDirection: "row", flexWrap: "wrap", gap: ARA[8], marginTop: ARA[18] }, suzul(gir2)]}>
            {kartlar.map((k, idx) => (
              <Cip key={k.ad} etiket={k.ad} secili={idx === kartI}
                   onPress={() => setKartI(idx)} a11yLabel={k.ad} />
            ))}
          </Animated.View>
          {/* 🔴 12 EYLÜL — CAM KART. Opak `C.surface` fotoğrafın önünde
              "kesilmiş bir delik" gibi duruyordu; %55 dumanlı cam
              (`C.camKart`) fotoğrafı sızdırıyor. Gölge de kalktı:
              saydam bir yüzeyin altında gölge, camı kâğıda çeviriyor.
              En küçük etiket `dim` DEĞİL `mutedAA` — cam zeminde `dim`
              3.78:1'e düşüyor, `mutedAA` 4.95 (ölçüm: theme.js camKart). */}
          {secili ? (
            <View style={{ backgroundColor: C.camKart, borderWidth: 1, borderColor: C.camKenar,
                           borderRadius: R.lg, padding: ARA[18], marginTop: ARA[14] }}>
              <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2,
                             color: C.mutedAA }}>{BUYUK(t.onbKartYer)}</Text>
              {/* Hüküm SERİF — kural ekranıyla aynı dil: burada konuşan biz
                  değil, havayolunun kendi tablosu. */}
              <Text style={{ fontFamily: F.serifGosterim, fontSize: FS.title + 2,
                             lineHeight: Math.round((FS.title + 2) * 1.15),
                             color: C.ink, marginTop: ARA[10] }}>{secili.yanit}</Text>
              <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[12] }}>
                <KararCipi t={t} politika={secili.politika} />
              </View>
              <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, letterSpacing: 0.6,
                             color: C.mutedAA, marginTop: ARA[10] }}>{secili.kanit}</Text>
            </View>
          ) : null}
          <Text style={{ fontSize: FS.sm, lineHeight: 19, color: C.meshAlt, marginTop: ARA[12] }}>{t.onbKartNot}</Text>
        </>
      ) : (
        <>
          {/* Başlık ve gövde AYRI Animated.View: aralarındaki 160ms
              gecikme "sırayla akma" hissini üreten şey. Tek bloğa
              sarsaydım ikisi aynı anda gelir, efekt kaybolurdu. */}
          {/* 🔴 12 EYLÜL · 3. TUR — BAŞLIK KELİME KELİME AKIYOR.
              Geçen turda blok düzeyinde süzülüyordu; istenen "kelimeler
              sırayla aksın"dı. `AkanBaslik` her kelimeyi 55ms arayla
              getiriyor. `anahtar={i}` — slayt değişince akış baştan
              başlasın diye (yoksa React aynı bileşeni yeniden kullanır
              ve ikinci slayt animasyonsuz gelir). */}
          <AkanBaslik metin={s.title} anahtar={i}
            stil={{ fontSize: FS.hero, fontWeight: "700", color: C.foto.baslik,
                    letterSpacing: -1.2, lineHeight: 38 }} />
          <Animated.View style={suzul(gir2)}>
            <Text style={{ fontSize: FS.base, color: C.meshAlt, marginTop: ARA[10], lineHeight: 22 }}>{s.body}</Text>
          </Animated.View>
        </>
      )}
    </View>

    <View style={{ paddingHorizontal: ARA[22], paddingBottom: 58, paddingTop: ARA[26] }}>
      <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[4], marginBottom: ARA[22] }}>
        {slides.map((_, idx) => (
          <View key={idx} style={{ width: idx === i ? 22 : 8, height: 6, borderRadius: R.full,
                                   backgroundColor: idx === i ? C.gold : C.warmLine || C.line }} />
        ))}
      </View>
      <Btn v="gold" label={!last ? t.onbNext : t.onbStart} onPress={() => last ? onDone() : setI(i + 1)} a11yLabel={!last ? t.onbNext : t.onbStart} />
    </View>
    </View>
    </FotoSahne>
  );
}

function IconField({ icon, children }) {
  // #24: MVP input dili — bgAlt kutu, solda kucuk ikon
  return (
    <View style={{ flexDirection: "row", alignItems: "center", backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, paddingHorizontal: SP[3], marginBottom: SP[1] }}>
      <Text style={{ fontSize: FS.base, marginRight: SP[2], opacity: 0.75 }}>{icon}</Text>
      <View style={{ flex: 1 }}>{children}</View>
    </View>
  );
}

function LangBtn({ lang, toggleLang }) {
  return (
    <TouchableOpacity hitSlop={TAP.slop} onPress={toggleLang} style={{ borderColor: C.gold, borderWidth: 1, borderRadius: R.sm, paddingVertical: ARA[2], paddingHorizontal: SP[2] }}>
      <Text style={{ color: C.goldInk, fontWeight: "600", fontSize: FS.xs }}>{lang === "tr" ? "EN" : "TR"}</Text>
    </TouchableOpacity>
  );
}

// v1.71: çevrimdışı ŞERİDİ (eski tam ekran kapı kaldırıldı — tek bir düşen
// istek yüzünden uygulamayı kilitliyordu). Kullanıcı gezinmeye devam eder.
//
// 🔴 13 EYLÜL · v5.9.0 — FİLDİŞİ VE SÜZÜLEREK GİRİYOR (Gökberk brief).
// Eski şerit AMBER zeminliydi. Amber ürünün UYARI rengi ve bir uyarı
// "bir şey yaptın, yanlış gitti" der. Oysa çevrimdışı olmak kullanıcının
// yaptığı bir şey değil; havalimanında olağan bir durum. Fildişi zemin
// (C.surface) + şampanya altını çizgi, aynı bilgiyi SUÇLAMADAN veriyor.
// Giriş `useNativeDriver: true` ile opaklık + 8pt süzülme — JS köprüsüne
// hiç uğramaz, kaydırma sırasında takılmaz.
// 🆕 SINIF: "BİR DURUMU UYARI RENGİYLE ÇİZERSEN KULLANICI ONU KENDİ
// HATASI SANIR — RENK, BİLGİNİN TONUDUR."
function OfflineBanner({ t, onRetry, busy, kuyruk = 0 }) {
  const [hidden, setHidden] = useState(false);
  const gir = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(gir, { toValue: 1, duration: 420, easing: Easing.out(Easing.cubic),
                           useNativeDriver: true }).start();
  }, [gir]);
  if (hidden) return null;
  return (
    <Animated.View style={{ backgroundColor: C.surface, borderBottomWidth: 1, borderBottomColor: C.gold,
                   paddingVertical: SP[2], paddingHorizontal: ARA[14],
                   opacity: gir,
                   transform: [{ translateY: gir.interpolate({ inputRange: [0, 1], outputRange: [-8, 0] }) }] }}>
    <View style={{ flexDirection: "row", alignItems: "center" }}>
      {/* 🔴 30 Ağu · 5. tur — TAŞMA KAPISI BU METNİ 0pt GENİŞLİKTE BULDU.
          Sarmalayıcının `flex: 1`i yoktu; satır içindeki bir kutu flex
          almazsa İÇERİĞİ KADAR genişler, içindeki `flex: 1` metin de
          `flexBasis: 0` olduğu için o hesaba SIFIR katkı yapar. Sonuç:
          çevrimdışı uyarısında ikon, "Yeniden dene" ve çarpı görünüyor
          — ASIL CÜMLE görünmüyordu.

          🆕 SINIF: "`flex: 1` BİR GENİŞLİK DEĞİL BİR PAY TALEBİDİR;
          PAYLAŞTIRACAK GENİŞLİĞİ OLMAYAN BİR EBEVEYNİN İÇİNDE SIFIR
          EDER — VE SIFIR GENİŞLİKTEKİ METİN HATA VERMEZ, SADECE YOK
          OLUR." */}
      <View style={{ flex: 1, flexDirection: "row", alignItems: "center" }}><Ikon ad="radar" boy={15} renk={C.gold} stil={{ marginRight: SP[1] }} /><Text style={{ flex: 1, color: C.ink, fontSize: FS.sm, fontWeight: "600" }}>{t.offlineTitle}</Text></View>
      <TouchableOpacity hitSlop={TAP.slop} onPress={onRetry} disabled={busy} style={{ paddingHorizontal: ARA[10] }}>
        {busy ? <ActivityIndicator color={C.gold} size="small" />
          : <Text style={{ color: C.goldInk, fontSize: FS.sm, fontWeight: "700" }}>{t.offlineRetry}</Text>}
      </TouchableOpacity>
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => setHidden(true)} style={{ paddingHorizontal: SP[1] }}
        accessibilityRole="button" accessibilityLabel={t.close || "Kapat"}>
        <Ikon ad="kapat" boy={FS.base} renk={C.mut} />
      </TouchableOpacity>
    </View>
    {/* 🔴 KUYRUKTAKİ MESAJ SAYISI — ŞAMPANYA SAAT İKONUYLA.
        Brief'in istediği bu satır, kullanıcıya "yazdığın kayboldu mu?"
        sorusunu sordurtmayan tek şey. Sayı görünmüyorsa kuyruk boş. */}
    {kuyruk > 0 && (
      <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[6] }}>
        <Ikon ad="saat" boy={FS.sm} renk={C.gold} stil={{ marginRight: ARA[6] }} />
        <Text style={{ flex: 1, minWidth: 0, color: C.mut, fontSize: FS.xs, lineHeight: SATIR(FS.xs) }}>
          {String(t.offlineQueued || "").replace("{n}", String(kuyruk))}
        </Text>
      </View>
    )}
    </Animated.View>
  );
}

function Splash({ t, go, lang, toggleLang }) {
  // ==========================================================================
  // 🔴 v3.1 — TASARIM ARTIK BURADA.
  // Bu ekran aylardır krem zeminde ortalanmış bir ikon + metin yığınıydı.
  // Tasarımı Python'da çizip onayladık ve orada bıraktık: ölçtüm, aldığımız
  // 12 karardan 5'i "sadece resimde" durumundaydı. Bir tasarım, ürün kodunda
  // karşılığı olana kadar bir resimdir.
  //
  // KOMPOZİSYON — Gökberk'in üç düzeltmesiyle:
  //   · marka kelimesi ORTADA (sola dayalıydı)
  //   · kanat işareti %35, pencerenin ortasında (yukarıdaydı)
  //   · başlık cümlesi ORTADA (sola dayalıydı)
  //
  // MARKAYI KELİME TAŞIYOR, İŞARET DEĞİL. Kanat %35'te 1.5:1 veriyor ve
  // WCAG'ın anlamlı grafik eşiğini (3.0) geçmiyor — geçmesi de gerekmiyor,
  // çünkü marka görevi ortadaki "LoungeLink"te ve o 18.18:1.
  // ==========================================================================
  const G = Dimensions.get("window").width;
  return (
    <FotoSahne>
      {/* 🔴 30 Ağu · 5. tur — DİL DÜĞMESİ MUTLAK KONUMA ALINDI.
          Marka kelimesi `flex:1 + paddingLeft:44` ile ortalanıyordu:
          o 44pt, sağdaki dil düğmesini dengelemek içindi ama KELİMENİN
          YERİNDEN çalınıyordu. Taşma kapısı ölçtü: "LOUNGELINK" 26pt +
          6 harf aralığıyla 229.7pt istiyor, 320pt cihazda 188pt vardı.
          Yani en dar telefonda marka kelimesi KIRPIK açılıyordu.

          Düğme akıştan çıkınca kelime tam genişliği kullanıyor:
          320 − 28×2 = 264pt · gereken 229.7pt. Ölçüldü, sığıyor.

          🆕 SINIF: "BİR ÖĞEYİ ORTALAMAK İÇİN KARŞI TARAFA PADDING
          KOYMAK, ORTALAMAK DEĞİL DARALTMAKTIR — DENGELEYİCİYİ AKIŞTAN
          ÇIKAR, YERİ ÖĞEYE BIRAK." */}
      {/* 🔴 3 EYLÜL — TASARIM 01: marka satırı tepede DEĞİL; kanat işareti,
          altında "LOUNGELINK" (24/700) ve serif slogan ekranın ORTASINDA,
          hepsi ortalı. Dil düğmesi sağ üstte kalıyor (tasarımda yok; giriş
          öncesi dil değiştirmenin tek yeri burası). */}
      <View style={{ position: "absolute", right: ARA[28], top: TOPPAD + 8, zIndex: 2 }}>
        <LangBtn lang={lang} toggleLang={toggleLang} />
      </View>

      {/* ══════════════════════════════════════════════════════════════
          🔴 20 EYLÜL · GÖKBERK'İN KARARI — MARKA SATIRI EN ÜSTE TAŞINDI.

          "ortada loungelink başlığı olması ve yeni app iconu kullanmak
           yerine aynı eskisi gibi logo kullanımı… daha sade ve güzel bir
           görünüm yaratır… illa başlığı kullanacaksak sayfanın en üstünde
           orta kısma app'in geneline uygun bir font tipi ve büyüklüğü ile"

          Haklıydı: ortada ÜÇ marka öğesi üst üste duruyordu (kap + kelime
          + serif slogan) ve göz hangisinin başlık olduğuna karar vermek
          zorunda kalıyordu.

          ⚠️ ÖLÇÜ UYDURULMADI. Bu satır app'te ÜÇ yerde zaten aynı
          biçimde yazılıyor — `App.js:2026` (FotoBant), `ekranlar_ana.js`
          (üst bant) ve `ui.js` (marka şeridi): FS.xs · letterSpacing 4.6
          · 700 · büyük harf. Splash şimdiye kadar bunun DIŞINDAYDI
          (26pt, aralıksız). Yani bu değişiklik bir sadeleştirme değil,
          splash'in nihayet diğer ekranlarla AYNI ritmi tutması.

          🆕 SINIF: "BİR EKRAN SİSTEMİN DIŞINDAYSA BUNU GENELDE 'ÖZEL
          EKRAN' DİYE SAVUNURUZ — OYSA AÇILIŞ EKRANI, SİSTEMİN İLK KEZ
          GÖRÜLDÜĞÜ YERDİR VE ORADA YAPILAN İSTİSNA, SİSTEMİN KENDİSİ
          SANILIR."
          ══════════════════════════════════════════════════════════════ */}
      <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0,
                                          top: TOPPAD + 12, alignItems: "center", zIndex: 1 }}>
        <Text style={{ fontSize: FS.xs, fontWeight: "700", letterSpacing: 4.6,
                       color: C.foto.marka, textShadowColor: "rgba(10,6,6,0.9)",
                       textShadowOffset: { width: 0, height: 1.5 }, textShadowRadius: 6 }}>
          LOUNGELINK
        </Text>
      </View>

      {/* KANAT — DOKU. Tasarım 01 ölçüleri: kanat kutusu ekranın %30'unda
          (G×0.30 kare), "LOUNGELINK" 24/700 kutunun 26 altında, serif slogan
          78 altında (34 punto, 44 satır; ikinci satır krem). Hepsi ortalı ve
          TEK blok — düğmelerden bağımsız, ekran boyu değişse de aynı yerde. */}
      <View pointerEvents="none" style={{ position: "absolute", left: 0, right: 0, top: "30%", alignItems: "center" }}>
        {/* ⚠️ KANAT — KEMER'E DÖNÜŞ DEĞİL, KEMER'İN İÇİ.
            Kanat, Kemer'in açıklığındaki swoosh ile AYNI çizim; Kemer ona
            bir KAP veriyor. İkon 48px'te okunmak zorunda ve orada kaba
            silueti olan kap kazanıyor; burada 390pt genişlik var ve kap
            gereksiz bir kalabalık. Tek işaret, iki kadraj.

            `mark-kanat.png` `brand/build_brand.py`den geliyor: mürekkebe
            KIRPILMIŞ (ham dosyanın %55'i saydam boşluktu — `contain` ile
            96pt kutuda kanat 53pt'e düşerdi) ve fildişi (#FAEEDC)
            PİŞİRİLMİŞ. Renk ölçüyle seçildi: gökyüzü L* ~70, şampanya
            L* 75, fildişi L* 94 — şampanya kanat bu fotoğrafın üstünde
            kaybolurdu.

            marginTop 64: kanadın MERKEZİ 341pt'e otursun diye. Slogan
            458pt'te kalıyor — yani kelime ortadan kalktı ama slogan
            YERİNDEN OYNAMADI (gerçek karede ölçüldü). */}
        <Image source={require("./assets/mark-kanat.png")} resizeMode="contain"
          style={{ width: G * 0.246, height: G * 0.246 * 0.4925, marginTop: ARA[64] }} />
        {/* ⚠️ İkinci satır AYRI Text ve fontFamily'yi AÇIKÇA taşıyor: `sansUygula`
            aile vermeyen her Text'e sans basar — iç içe Text'te miras yok. */}
        <Text style={{ fontSize: FS.hero, fontFamily: F.serif, lineHeight: 44, marginTop: ARA[92],
                       marginHorizontal: ARA[12], color: C.foto.baslik, textAlign: "center",
                       textShadowColor: "rgba(10,6,6,0.85)",
                       textShadowOffset: { width: 0, height: 2 }, textShadowRadius: 10 }}>
          {t.tagline1}{"\n"}<Text style={{ fontFamily: F.serif, color: C.foto.sozIkinci }}>{t.tagline2}</Text>
        </Text>
      </View>

      <View style={{ flex: 1, justifyContent: "flex-end", paddingHorizontal: ARA[28],
                     paddingBottom: ARA[34] }}>
        {/* 🔴 4 EYLÜL — TASARIM 01 BİREBİR: sloganın altında paragraf ve güven
            çipleri YOK (Gökberk: "onaylanan tasarım ile birebir"). O metinler
            tanıtım ekranlarında (15) zaten anlatılıyor. */}
        <Btn v="gold" label={t.start} style={{ marginTop: ARA[30] }}
          onPress={async () => {
            let seen = false;
            try { seen = (await AsyncStorage.getItem("ll_onb")) === "1"; } catch {}
            go(seen ? "register" : "onboarding");   // #3: Basla -> tutorial -> kayit
          }} />

        {/* 🔴 v3.6 — "ÖNCE DENE" YOLU. Kayıt duvarını değerin arkasına
            koyuyor: kullanıcı kartını seçiyor, hangi salona girebileceğini
            ve o havalimanında kaç kişinin onu içeri alabileceğini GÖRÜYOR,
            sonra kayıt isteniyor. */}
        <TouchableOpacity hitSlop={TAP.slop} accessibilityRole="button"
          accessibilityLabel={t.splashGuide} style={{ marginTop: SP[4], alignItems: "center" }}
          onPress={() => go("guide")}>
          <Text style={{ color: C.foto.baslik, fontSize: FS.sm, fontWeight: "700",
                         textDecorationLine: "underline",
                         textShadowColor: "rgba(10,6,6,0.8)",
                         textShadowOffset: { width: 0, height: 1 },
                         textShadowRadius: 6 }}>{t.splashGuide}</Text>
        </TouchableOpacity>

        <TouchableOpacity hitSlop={TAP.slop} accessibilityRole="button"
          accessibilityLabel={t.haveAcc} style={{ marginTop: SP[3], alignItems: "center" }}
          onPress={() => go("login")}>
          <Text style={{ color: C.foto.bag, fontSize: FS.sm, fontWeight: "700",
                         textShadowColor: "rgba(10,6,6,0.8)",
                         textShadowOffset: { width: 0, height: 1 },
                         textShadowRadius: 6 }}>{t.haveAcc}</Text>
        </TouchableOpacity>
      </View>
    </FotoSahne>
  );
}


// ============================================================
// v1.74 · SOSYAL GİRİŞ/KAYIT DÜĞMELERİ
//
// ÜRÜN MANTIĞI (Gokberk'in sorusuna cevap):
//  • Aynı düğmeler HEM giriş HEM kayıt ekranında durur. Sosyal kimlikte
//    "kayıt" ve "giriş" ayrı işlem DEĞİLDİR — Google/Apple hesabı ilk kez
//    geliyorsa hesap açılır, daha önce geldiyse oturum açılır. Kullanıcıya
//    iki ayrı düğme göstermek yanlış zihinsel model kurar ve "zaten hesabım
//    vardı, kayıt mı oluyorum?" tereddüdü yaratır.
//  • Apple düğmesi YALNIZCA iOS'ta. App Store kuralı: başka sosyal giriş
//    sunuyorsan Sign in with Apple zorunlu; Android'de ise beklenmez.
//  • Sıra: Google üstte (Türkiye'de baskın), sonra Apple, sonra "veya"
//    ayracı ve e-posta formu. Sosyal seçenekler ÜSTTE çünkü tek dokunuşluk
//    yol, form doldurmaktan hızlıdır.
// ============================================================
function SocialAuthButtons({ t, onBusyChange, onError }) {
  const [busy, setBusy] = useState(null);
  const [hasApple, setHasApple] = useState(false);
  useEffect(() => { (async () => setHasApple(await appleAvailable()))(); }, []);

  async function run(kind) {
    setBusy(kind); onBusyChange && onBusyChange(true); onError("");
    const res = kind === "google" ? await signInWithGoogle() : await signInWithApple();
    setBusy(null); onBusyChange && onBusyChange(false);
    if (!res.ok && res.code !== "cancelled") {
      // Sağlayıcı Supabase'de açılmadıysa bu hata gelir — kullanıcıya
      // teknik mesaj değil, anlaşılır bir açıklama göster.
      const provNotSet = /provider is not enabled|unsupported provider|oauth_no_url/i.test(res.code || "");
      onError(provNotSet ? t.socialNotReady : (t.socialFailed || res.code));
    }
    // Başarılıysa onAuthStateChange oturumu alır; ekran kendiliğinden geçer.
  }

  /* 4 Eylül — TASARIM 16 BİREBİR: iki sosyal düğme de tasarımın `ghost`
     düğmesi (52 yüksek · yarıçap 12 · 1.5px `line2` kenar · %3 beyaz zemin ·
     14/600 `body` metin · ikon yok). Altta ince ayraç üstünde "veya" hapı. */
  const hayalet = { alignItems: "center", justifyContent: "center",
                    backgroundColor: "rgba(255,255,255,0.03)", borderWidth: 1.5,
                    borderColor: C.line2 || C.line, borderRadius: R.md, minHeight: 52 };
  const dugme = (kind, etiket) => (
    <TouchableOpacity hitSlop={TAP.slop} onPress={() => run(kind)} disabled={!!busy}
      accessibilityRole="button" accessibilityLabel={etiket}
      accessibilityState={{ disabled: !!busy, busy: busy === kind }}
      style={[hayalet, { marginBottom: kind === "google" ? ARA[12] : 0 }]}>
      {busy === kind ? <ActivityIndicator color={C.gold} />
        : <Text style={{ color: C.body, fontWeight: "600", fontSize: FS.base }}>{etiket}</Text>}
    </TouchableOpacity>
  );
  return (
    <View style={{ marginBottom: ARA[26] }}>
      {dugme("google", t.continueWithGoogle)}
      {hasApple ? <View style={{ marginTop: ARA[12] }}>{dugme("apple", t.continueWithApple)}</View> : null}
      <View style={{ alignItems: "center", justifyContent: "center", marginTop: ARA[22], height: 22 }}>
        <View style={{ position: "absolute", left: 0, right: 0, height: 1, backgroundColor: C.line }} />
        <View style={{ backgroundColor: C.bg, paddingHorizontal: ARA[10] }}>
          <Text style={{ color: C.dim, fontSize: FS.xs + 0.5 }}>{t.orWord}</Text>
        </View>
      </View>
    </View>
  );
}

function Auth({ mode, t, go, lang, toggleLang }) {
  // v1.72: giriş/kayıt ekranının altında sözleşme bağlantıları (KVKK + mağaza
  // şartı). Tıklanınca metin tam ekran açılır; ayrıca geri tuşu da kapatır.
  const [legal, setLegal] = useState(null);
  const [step, setStep] = useState(1);
  const [forgot, setForgot] = useState(false);
  const [fSent, setFSent] = useState(false);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [refIn, setRefIn] = useState("");
  const [pass, setPass] = useState("");
  const [gender, setGender] = useState(null);
  const [role, setRole] = useState(null);
  const [showPw, setShowPw] = useState(false);
  // Kayıt tamamlandı ama Supabase oturum vermedi → e-posta doğrulaması bekliyor
  const [verifyWait, setVerifyWait] = useState(false);
  const [resent, setResent] = useState(false);

  // ══════════════════════════════════════════════════════════════════
  // 🔴 26 AĞUSTOS 2026 — ONAY DİZİSİ SABİT UZUNLUKTA YAZILMIŞTI VE
  //    "TÜMÜNÜ KABUL ET" DÜĞMESİ 5 ELEMAN YAZIYORDU. KUTU 6 TANEYDİ.
  //
  //    ÖLÇÜLDÜ (render_check/giris_kapisi_test.js, gerçek dokunuşla):
  //      "Tümünü kabul et" → 6 işaretli, 1 İŞARETSİZ
  //      18+ kutusuna basıldı → önce 6 işaretli, sonra 6 (DEĞİŞMEDİ)
  //      buna rağmen grant_consents'e giden liste: [... , "age_18"]
  //
  //    Üç ayrı kusur, tek satırdan:
  //      (1) `allConsent = consents.every(Boolean)` — 5 elemanlı bir
  //          dizide `every` TRUE döner. Yani "Hesap Oluştur" düğmesi
  //          AÇILIYOR, ekranda ise bir kutu boş duruyor. Kullanıcı
  //          "neden açık?" diye düşünüyor; ürün tutarsız görünüyor.
  //      (2) `c.map((v,j) => j===5 ? !v : v)` — 5 elemanlı dizide j
  //          hiç 5 olmaz → 18+ kutusu ARTIK HİÇ TIKLANAMAZ.
  //      (3) 18+ onayı kullanıcı VERMEDEN sunucuya "verildi" diye
  //          yazılıyor. Bu artık bir arayüz kusuru değil, KAYDIN
  //          DOĞRULUĞU meselesidir.
  //
  //    Çözüm sabit sayı yazmamak: dizinin uzunluğu METİN LİSTESİNDEN
  //    türüyor. Bir onay maddesi eklenince/çıkınca kimsenin başka bir
  //    yeri güncellemesi gerekmiyor — kayabilecek bir sayı kalmadı.
  //
  // 🆕 SINIF: "İKİ YERDE YAZILAN BİR UZUNLUK, ER GEÇ İKİ FARKLI SAYI
  //    OLUR — VE ARADAKİ FARKI KULLANICI, SESSİZCE AÇIK KALAN BİR
  //    DÜĞME OLARAK GÖRÜR."
  // ══════════════════════════════════════════════════════════════════
  //    Metin ve kayıt tipi TEK BİR LİSTEDE. Eskiden ekranda gösterilen
  //    sıra (c1…c6) ile sunucuya yazılan tip sırası birbirini hiç
  //    tutmuyordu; ikisi ayrı yerlerde yazıldığı için de kimse fark
  //    edemezdi. Şimdi bir madde eklemek/çıkarmak tek satır.
  const CONSENT_ITEMS = [
    { text: t.c1,     type: "terms_privacy" },
    { text: t.c2,     type: "community_rules" },
    { text: t.c3,     type: "no_lounge_sale" },
    { text: t.c4,     type: "venue_rules" },
    { text: t.c5,     type: "no_offplatform_payment" },
    { text: t.c6Age,  type: "age_18" },
  ];
  const CONSENT_TEXTS = CONSENT_ITEMS.map(x => x.text);
  const CONSENT_TYPES = CONSENT_ITEMS.map(x => x.type);
  const [consents, setConsents] = useState(() => CONSENT_ITEMS.map(() => false));
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const isReg = mode === "register";
  // `length` kontrolü de şart: dizi bir şekilde kısalırsa `every` yine
  // true döner ve kapı sessizce açılır. İkisi birlikte kapatıyor.
  const allConsent = consents.length === CONSENT_TEXTS.length && consents.every(Boolean);

  // Kayit sihirbazinda donanim geri tusu bir ADIM geri gider; "sifremi
  // unuttum" aciksa once onu kapatir. Baska katman yoksa App'in handler'i
  // devreye girip splash'e doner.
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      if (isReg && step > 1) { setStep(step - 1); return true; }
      if (!isReg && forgot) { setForgot(false); setFSent(false); setErr(""); return true; }
      return false;
    });
    return () => h.remove();
  }, [isReg, step, forgot]);

  // Şifremi unuttum: Supabase sıfırlama e-postası gönderir
  async function sendReset() {
    setErr("");
    const e = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) { setErr(t.emailInvalid); return; }
    setBusy(true);
    // 🔴 v1.83 (Gokberk): sıfırlama maili BO'ya (Vercel) yönlendiriyordu —
    // oysa BO'ya yalnız admin girebilir; kullanıcı çıkmaz sokağa düşüyordu.
    // Artık bağlantı UYGULAMAYA dönüyor: loungelink://reset-password.
    // (Supabase → URL Configuration → Redirect URLs listesine bu adres
    // eklenmiş olmalı; eklenmezse Site URL'e düşer.)
    const { error } = await supabase.auth.resetPasswordForEmail(e, {
      redirectTo: RESET_REDIRECT,
    });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }   // v2.65: ham metin değil
    setFSent(true);
  }

  function validStep1() {
    setErr("");
    if (!name.trim() || !email.trim() || !pass) { setErr(t.errFill); return false; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) { setErr(t.emailInvalid); return false; }
    if (pass.length < 8) { setErr(t.pwMin); return false; }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════
  // 🔴 26 AĞUSTOS — GİRİŞTE HİÇ DOĞRULAMA YOKTU.
  //
  // ÖLÇÜLDÜ: boş e-posta ve boş şifreyle "Giriş yap"a basıldığında
  // `signInWithPassword` GERÇEKTEN çağrılıyordu (harness 1 çağrı saydı).
  // Supabase'in cevabı ham İngilizce bir hata ("Anonymous sign-ins are
  // disabled" / "missing email") ve `mapErr` bu kalıpları tanımadığı için
  // kullanıcı ekranda İngilizce teknik bir cümle görüyordu.
  //
  // Kayıt tarafında `validStep1()` vardı, girişte KARŞILIĞI YOKTU.
  // Aynı ürünün iki kapısından biri kibar, öteki değil.
  //
  // 🆕 SINIF: "DOĞRULAMAYI YALNIZ UZUN FORMA KOYARSAN, KISA FORM EN
  // HAM HATAYI ÜRETEN YER OLUR."
  function validLogin() {
    setErr("");
    const e = email.trim();
    if (!e || !pass) { setErr(t.errFill); return false; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) { setErr(t.emailInvalid); return false; }
    return true;
  }

  // 🔴 v3.6 — DOĞRULAMA BEKLEME EKRANININ TEK ÇIKIŞI GERİYE GİDİYORDU.
  //
  // Kayıt bitti, e-posta gitti. Kullanıcı postasını çoğu zaman TELEFONDA
  // DEĞİL, bilgisayarda açar. O durumda derin bağlantı bu cihaza hiç
  // gelmez ve `onAuthStateChange` hiç ateşlenmez. Ekranda kalan tek düğme
  // "Giriş ekranına dön"dü — ve `go("login")` `Auth`u BAŞKA BİR JSX
  // konumunda yeniden mount ettiği için e-posta da parola da state'le
  // birlikte siliniyordu. Yani doğrulamayı yapmış bir kullanıcı, hesabını
  // yeni oluşturduğu bilgileri BAŞTAN yazmak zorundaydı.
  //
  // 🆕 SINIF: "BİR BEKLEME EKRANININ 'BEKLEDİĞİM ŞEY OLDU' DÜĞMESİ YOKSA,
  // KULLANICI BEKLEMEYİ DEĞİL ÜRÜNÜ TERK EDER."
  //
  // Parola hâlâ state'te; tek dokunuşta girişi deneyip sonucu YAZIYORUZ.
  async function dogruladimDene() {
    setErr(""); setBusy(true);
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(), password: pass,
      });
      if (error) throw error;
      // Başarılıysa onAuthStateChange ekranı "home"a alır.
    } catch (e) {
      const raw = String(e.message || e);
      setErr(/email not confirmed/i.test(raw) ? t.verifyNotYet
        : /invalid login credentials/i.test(raw) ? t.e_bad_credentials
        : mapErr(t, raw));
      setBusy(false);
    }
  }

  async function resendVerify() {
    try {
      await supabase.auth.resend({ type: "signup", email: email.trim().toLowerCase() });
      setResent(true);
    } catch (e) { setErr(mapErr(t, String(e.message || e))); }
  }

  async function submit() {
    setErr("");
    if (isReg && !allConsent) return setErr(t.consentTitle);
    if (!isReg && !validLogin()) return;
    setBusy(true);
    try {
      if (isReg) {
        // ══════════════════════════════════════════════════════════════
        // 🔴 v3.9 — BURADAKİ `phone_in_use` KONTROLÜ ÖLÜYDÜ. KALDIRILDI.
        //
        // ÖLÇÜLDÜ (SQL 268):
        //     begin; set local role anon;
        //     select public.phone_in_use('+905551112233');
        //     → ERROR:  not_authenticated
        //
        // SQL 253 bu fonksiyona `auth.uid()` şartı koydu. Ama bu çağrı
        // `signUp`tan ÖNCE, yani kullanıcı HENÜZ ANONİMKEN yapılıyordu.
        // Çağrı her seferinde patlıyor, `catch (e) {}` yutuyor, `taken`
        // hiç dolmuyor: kontrol aylardır hiçbir şey kontrol etmiyordu.
        //
        // ⚠️ VE ARKASINDA KORUMA DA YOKTU: `users.phone` üzerinde UNIQUE
        // indeks yoktu; aynı numara iki hesapta durabiliyordu (SQL 268'de
        // deneyle gösterildi). Yani ürün, çalışmayan bir kontrolün
        // arkasına saklanmış bir kuralı uyguluyor sanıyordu.
        //
        // 🆕 SINIF: "ÇALIŞMAYAN BİR KONTROL, HİÇ OLMAYAN BİR KONTROLDEN
        // DAHA TEHLİKELİDİR — ÇÜNKÜ ARKASINA KİMSE İKİNCİ BİR KİLİT
        // KOYMAZ."
        //
        // Yeni kural: tekillik VERİTABANINDA (kısmi UNIQUE indeks) ve
        // `declare_phone` içinde. Kullanıcıya mesaj aşağıda, numara
        // yazılırken veriliyor — anonim bir tarama ucu bırakmadan.
        // ══════════════════════════════════════════════════════════════
        const { data: sud, error } = await supabase.auth.signUp({
          email: email.trim(), password: pass,
          options: { data: { name: name.trim(), gender: gender || undefined, role: role || "guest", phone: phone || undefined } },
        });
        if (error) {
          // #5: "zaten kayitli" hatasini anlasilir soyle
          const m = (error.message || "").toLowerCase();
          if (m.includes("already registered") || m.includes("already been registered") || m.includes("user already exists")) {
            setBusy(false); setErr(t.emailInUse); return;
          }
          throw error;
        }
        // ══════════════════════════════════════════════════════════
        // 🔴 26 AĞUSTOS — E-POSTA DOĞRULAMASI AÇIKSA KAYIT DÖNEN
        //    BİR ÇARKTA BİTİYORDU.
        //
        //    Supabase'te "Confirm email" AÇIK (varsayılan) ise
        //    `signUp` OTURUM DÖNDÜRMEZ: `data.session === null`.
        //    Eski kod bunu hiç sormuyordu; `setBusy(false)` yalnız
        //    `catch` içinde vardı ve ekran geçişi
        //    `onAuthStateChange`e bırakılmıştı — o olay ise HİÇ
        //    gelmiyor. Sonuç: kayıt SUNUCUDA BAŞARILI, kullanıcı
        //    ekranda sonsuza kadar dönen bir çark.
        //
        //    ÖLÇÜLDÜ (harness, session:null döndürülerek): ekranda
        //    doğrulama bilgisi yok, düğme kilitli, çark dönüyor.
        //
        //    Ayrıca oturum yokken aşağıdaki iki RPC de anonim
        //    çalışıyor ve SESSİZCE düşüyordu: referans ödülü hiç
        //    verilmiyor, KVKK onay kaydı hiç yazılmıyordu. İkincisi
        //    bir arayüz kusuru değil, KANIT KAYBIDIR.
        //
        // 🆕 SINIF: "BİR EKRANI SUNUCUDAN GELECEK BİR OLAYA BAĞLARSAN,
        //    O OLAYIN GELMEDİĞİ DALI DA ÇİZMEK ZORUNDASIN."
        // ══════════════════════════════════════════════════════════
        if (!sud || !sud.session) {
          setBusy(false);
          setVerifyWait(true);
          return;
        }

        // Telefon: 🔴 SORULUYORDU AMA HİÇBİR YERE YAZILMIYORDU.
        // `raw_user_meta_data.phone` gönderiliyordu; köprü tetikleyicisi
        // (`handle_new_user`) o alanı OKUMUYOR — ölçüldü. Yani kullanıcı
        // numarasını kayıtta giriyor, uygulama sonra tekrar soruyordu.
        // Sunucuda zaten `declare_phone(p_phone)` vardı ve app onu HİÇ
        // çağırmıyordu ("yazıp çağırmamak" sınıfı, bir kez daha).
        if (phone.trim()) {
          // 🔴 v3.9 — HATA ARTIK YUTULMUYOR. `declare_phone` (SQL 268)
          // numara başka bir hesapta kayıtlıysa `phone_taken` fırlatıyor.
          // Eskiden bu `catch (e) {}` içinde kaybolurdu: hesap açılır,
          // numara YAZILMAZ ve kullanıcı bunu asla öğrenmezdi — sonra
          // "telefonunu doğrula" kapısına takılır ve sebebini bilmez.
          // Hesabı geri almıyoruz (açıldı, e-postası çalışıyor); ama
          // eksik kalan şeyi SÖYLÜYORUZ.
          const { error: telHata } = await supabase.rpc("declare_phone", { p_phone: phone.trim() });
          if (telHata) {
            logError("declare_phone", telHata);
            setErr(mapErr(t, telHata.message));
            // ⚠️ DÜRÜST SINIR: oturum bu dalda ZATEN açıldığı için
            // `onAuthStateChange` ekranı ana sayfaya alabilir ve bu satır
            // görülmeyebilir. Hesabı geri almıyorum — e-postası çalışan
            // gerçek bir hesap açıldı; onu silmek daha kötü bir bozulma.
            // Kullanıcı numarasız kalır ve mevcut "telefonunu doğrula"
            // kapısına takılır; ORADA `declare_phone` aynı hatayı
            // döndürür ve `mapErr` "Bu telefon zaten kayıtlı." der.
            // Yani mesaj kaybolmuyor, kullanıcının ONA İHTİYAÇ DUYDUĞU
            // ana ertelenmiş oluyor.
            // 🆕 SINIF: "BİR HATAYI GÖSTERECEK EKRAN KAPANIYORSA, HATAYI
            // KULLANICININ O KONUYA GERİ DÖNECEĞİ YERDE KARŞILAMASINI
            // SAĞLA — YUTMAK İLE ZORLA GÖSTERMEK ARASINDA ÜÇÜNCÜ BİR YOL
            // VAR."
          }
        }
        // Referans kodu (opsiyonel): 028'in apply_referral'i VARDI ama app
        // hicbir yerden cagirmiyordu — kod uretiliyor, girilecek yer yoktu.
        // Basarisiz olursa kayit ETKILENMEZ (odul kaybi kayittan onemsiz).
        if (refIn.trim()) {
          try { await supabase.rpc("apply_referral", { p_code: refIn.trim() }); } catch (e) {}
        }
        // §5 Adım 3: sözleşme kabulü kaydı (KVKK)
        // Liste artık ekrandaki kutularla AYNI KAYNAKTAN geliyor:
        // kutu sayısı ile kayda giden tip sayısı ayrışamaz.
        try {
          await supabase.rpc("grant_consents", {
            p_types: CONSENT_TYPES,
            p_version: "v16",
          });
        } catch (e) {}
      } else {
        // #7: ayni cihazda onceki hesabin bayat oturumu "girdim ama baska
        // hesap acildi" vakasini yaratabiliyor — girise baslamadan temizle.
        try { await supabase.auth.signOut(); } catch (e) {}
        const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password: pass });
        if (error) throw error;
      }
    } catch (e) {
      // Supabase'in ham İngilizce mesajı ("Invalid login credentials") yerine
      // kullanıcının anlayacağı Türkçe karşılık.
      const raw = String(e.message || e);
      const key = /invalid login credentials/i.test(raw) ? "e_bad_credentials"
        : /email not confirmed/i.test(raw) ? "e_email_not_confirmed"
        : /rate limit|too many/i.test(raw) ? "e_too_many_attempts" : null;
      setErr(key ? t[key] : raw);
      setBusy(false);
    }
  }

  // ---- KAYIT SONRASI: E-POSTA DOĞRULAMASI BEKLENİYOR ----
  // Bu ekran olmadan kayıt akışının SONU YOKTU.
  if (verifyWait) {
    return (
      <View style={{ flex: 1 }}>
        <Hdr t={t} brandRight={<LangBtn lang={lang} toggleLang={toggleLang} />}
          title={t.verifySentTitle} onBack={() => { setVerifyWait(false); go("login"); }} />
        <ScrollView contentContainerStyle={{ padding: SP[5], paddingTop: ARA[20] }}>
          <View style={{ backgroundColor: C.tealTint, borderWidth: 1, borderColor: C.teal,
                         borderRadius: R.sm, padding: SP[4] }}>
            <Ikon ad="eposta" boy={FS.hero} renk={C.mut} />
            <Text style={{ color: C.tealInk, fontWeight: "700", fontSize: FS.base, textAlign: "center" }}>
              {t.verifySentTitle}
            </Text>
            <Text style={{ color: C.tealInk, fontSize: FS.sm, marginTop: SP[2], lineHeight: 18, textAlign: "center" }}>
              {String(t.verifySentBody || "").replace("{email}", email.trim())}
            </Text>
          </View>
          {resent && (
            <Text style={{ color: C.teal, fontSize: FS.sm, marginTop: SP[3], textAlign: "center" }}>
              {t.verifyResent}
            </Text>
          )}
          {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
          <Btn label={t.verifyDone} busy={busy} disabled={busy} onPress={dogruladimDene} style={{ marginTop: ARA[20] }} />
          <Btn v="ghost" label={t.verifyGoLogin} onPress={() => { setVerifyWait(false); setErr(""); go("login"); }} style={{ marginTop: SP[2] }} />
          <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: SP[4], alignItems: "center" }}
            onPress={resendVerify}>
            <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "600" }}>{t.verifyResend}</Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    );
  }

  // ---- LOGIN ----
  if (!isReg) {
    return (
      <View style={{ flex: 1 }}>
        {/* `kahraman`: giriş kapısı başlığı bir liste başlığı değil,
            karşılama cümlesi — tasarımın `.ust-h1` ölçüsünde ve
            satırlara bölünebilir. `ustBilgi` de tasarımdaki `.dugum`. */}
        <Hdr t={t}
          kahraman ustBilgi={forgot ? undefined : t.login}
          title={forgot ? t.forgotTitle : t.welcomeBack} onBack={() => forgot ? (setForgot(false), setFSent(false), setErr("")) : go("splash")} />
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ padding: SP[5], paddingTop: ARA[20] }}>
          {forgot ? (
            <>
              {fSent ? (
                <>
                  <View style={{ backgroundColor: C.tealTint2, borderWidth: 1, borderColor: C.teal, borderRadius: R.xs, padding: ARA[14], marginTop: SP[4] }}>
                    <Text style={{ color: C.tealInk, fontWeight: "700", fontSize: FS.base }}>{t.forgotSentTitle}</Text>
                    <Text style={{ color: C.tealInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>
                      {t.forgotSentBody.replace("{email}", email.trim())}
                    </Text>
                  </View>
                  <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: ARA[20], alignItems: "center" }}
                    onPress={() => { setForgot(false); setFSent(false); setErr(""); }}>
                    <IkonMetin ad="sol" renk={C.gold} stilMetin={{ color: C.gold, fontSize: FS.sm, fontWeight: "600" }} metin={t.backToLogin} />
                  </TouchableOpacity>
                </>
              ) : (
                <>
                  <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 19 }}>{t.forgotBody}</Text>
                  <Text style={st.label}>{t.email}</Text>
                  <TextInput style={st.input} value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
                  <Btn label={t.forgotSend} onPress={sendReset} disabled={busy} busy={busy} style={{ marginTop: ARA[22] }} />
                  {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
                  <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: ARA[18], alignItems: "center" }}
                    onPress={() => { setForgot(false); setErr(""); }}>
                    <IkonMetin ad="sol" renk={C.mut} stilMetin={{ color: C.mut, fontSize: FS.sm }} metin={t.backToLogin} />
                  </TouchableOpacity>
                </>
              )}
            </>
          ) : (
            <>
              <SocialAuthButtons t={t} onBusyChange={setBusy} onError={setErr} />
              <Text style={st.label}>{t.email}</Text>
              {/* 🔴 `autoComplete`/`textContentType` YOKTU: iOS ve Android'in
                  şifre yöneticileri alanı tanımıyor, otomatik doldurma
                  çalışmıyordu. Girişte en sık terk sebeplerinden biri budur
                  ve düzeltmesi iki prop. */}
              <IconField icon={<Ikon ad="eposta" boy={15} renk={C.muted} />}><TextInput style={st.inputBare} value={email} onChangeText={setEmail}
                placeholder={t.emailPh} placeholderTextColor={C.dim}
                autoCapitalize="none" autoCorrect={false} keyboardType="email-address"
                autoComplete="email" textContentType="emailAddress" returnKeyType="next" /></IconField>
              <Text style={st.label}>{t.pass}</Text>
              <IconField icon={<Ikon ad="kilit" boy={15} renk={C.muted} />}>
                <View style={{ flexDirection: "row", alignItems: "center" }}>
                  <TextInput style={[st.inputBare, { flex: 1 }]} value={pass} onChangeText={setPass}
                    placeholder="••••••••" placeholderTextColor={C.dim}
                    secureTextEntry={!showPw} autoCapitalize="none" autoCorrect={false}
                    autoComplete="password" textContentType="password"
                    returnKeyType="go" onSubmitEditing={submit} />
                  {/* 4 Eylül — "Göster" anahtarı kalktı: tasarım 16'da yok. */}
                </View>
              </IconField>
              <Btn label={t.doLogin} onPress={submit} disabled={busy} busy={busy} a11yLabel={t.doLogin} style={{ marginTop: ARA[22] }} />
              {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
              <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: ARA[14], alignItems: "center" }}
                onPress={() => { setForgot(true); setErr(""); }}>
                <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "600" }}>{t.forgotLink}</Text>
              </TouchableOpacity>
              {/* 4 Eylül — tasarım 16: "Hesabın yok mu?" ve yasal altbilgi yok.
                  Kayıt yolu karşılama ekranındaki "Başla"; sözleşmeler kayıtta (17). */}
            </>
          )}
        </ScrollView>
        </KeyboardAvoidingView>
        {!!legal && (
          <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: C.paper }}>
            <LegalDoc t={t} docKey={legal} onBack={() => setLegal(null)} onOpen={setLegal} />
          </View>
        )}
      </View>
    );
  }

  // ---- REGISTER: 3 ADIMLI SİHİRBAZ (§5) ----
  // (CONSENT_TEXTS yukarıda, state ile aynı yerde tanımlı — uzunluk
  //  artık tek bir kaynaktan geliyor.)
  // 🔴 v3.4 — GİRİŞ VE KAYIT DA AYNI SAHNEDE.
  // Fotoğraf ÇERÇEVEDE, form opak yaprakta: bütün alan/etiket renkleri
  // `C.card` zeminine göre ölçülüydü ve o zemin DEĞİŞMEDİ. Yani
  // atmosferi kazandık, tek bir kontrast oranını kaybetmedik.
  // Geri oku ve dil düğmesi fotoğrafın üstünde, Splash'teki gibi.
  return (
    /* 🔴 3 EYLÜL — TASARIM 17: kayıt da giriş gibi DÜZ gece zemininde;
       fotoğraflı çerçeve + yaprak kart kalktı. Üst satır: geri dairesi ·
       LOUNGELINK · dil; altında düğüm ("ADIM 2/3") ve başlık. */
    <Sayfa ufuk={44}>
      <Hdr t={t} kahraman
        ustBilgi={step === 3 ? t.consentEyebrow : `${t.step} ${step}${t.of}3`}
        title={step === 2 ? t.roleTitle : step === 3 ? t.consentTitle : t.register}
        onBack={() => step > 1 ? setStep(step - 1) : go("splash")} />
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={{ padding: SP[5], paddingTop: ARA[18] }}>
        {/* 3 Eylül — ilerleme çubuğu ve "Adım x/3 · …" satırı kalktı: düğüm
            (başlığın üstü) adımı söylüyor; tasarım 17'de ikinci bir gösterge yok. */}
        {/* 4 Eylül — tasarım 17 (adım 3): başlığın altında ikinci satır YOK;
            düğüm zaten "SÖZLEŞMELER". 1–2. adımda bilgi satırı kalıyor. */}
        {step !== 3 && (
        <Text style={{ color: C.mut, fontSize: FS.xs, marginBottom: ARA[14] }}>
          {step === 1 ? t.regStep1 : t.regStep2}
        </Text>
        )}

        {step === 1 && (
          <>
            <SocialAuthButtons t={t} onBusyChange={setBusy} onError={setErr} />
            <Text style={st.label}>{t.name}</Text>
            <IconField icon={<Ikon ad="kisi" boy={15} renk={C.muted} />}><TextInput style={st.inputBare} value={name} onChangeText={setName}
              placeholder={t.namePh} placeholderTextColor={C.mut}
              autoComplete="name" textContentType="name" /></IconField>
            <Text style={st.label}>{t.email}</Text>
            <IconField icon={<Ikon ad="eposta" boy={15} renk={C.muted} />}><TextInput style={st.inputBare} value={email} onChangeText={setEmail}
              autoCapitalize="none" autoCorrect={false} keyboardType="email-address"
              autoComplete="email" textContentType="emailAddress"
              placeholder="email@example.com" placeholderTextColor={C.mut} /></IconField>
            {/* 🔴 `t.phone || "Telefon"` ve sabit Türkçe yer tutucular: sözlükte
                anahtar VARDI (`phone: "TELEFON"`), yedek metin gereksizdi ve
                İngilizce dilde yer tutucular Türkçe kalıyordu. */}
            <Text style={st.label}>{t.phone}</Text>
            <IconField icon={<Ikon ad="telefon" boy={15} renk={C.muted} />}><TextInput style={st.inputBare} value={phone} onChangeText={setPhone}
              keyboardType="phone-pad" autoComplete="tel" textContentType="telephoneNumber"
              placeholder={t.phonePh} placeholderTextColor={C.mut} /></IconField>
            {/* Alanın isteğe bağlı olduğu HİÇBİR YERDE yazmıyordu; zorunlu
                sanılıp terk ediliyordu. `validStep1()` zaten telefonu
                aramıyor — ekran da bunu söylemeli. */}
            <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: -2, marginBottom: SP[1] }}>{t.phoneOpt}</Text>
            <Text style={st.label}>{t.pass}</Text>
            <IconField icon={<Ikon ad="kilit" boy={15} renk={C.muted} />}>
              <View style={{ flexDirection: "row", alignItems: "center" }}>
                <TextInput style={[st.inputBare, { flex: 1 }]} value={pass} onChangeText={setPass}
                  secureTextEntry={!showPw} autoCapitalize="none" autoCorrect={false}
                  autoComplete="new-password" textContentType="newPassword"
                  placeholder={t.pwPh} placeholderTextColor={C.mut} />
                {/* 🔴 `pass2` (şifre tekrar) STATE'İ VARDI AMA HİÇ ÇİZİLMİYORDU.
                    Yani "şifreler eşleşmiyor" metni (`t.errPass`) de ölü bir
                    metindi. İkinci alan eklemek yerine GÖSTER/GİZLE koyduk:
                    yazım hatasını aynı şekilde önler, bir alan daha
                    doldurtmaz. Ölü state aşağıda silindi. */}
                <TouchableOpacity hitSlop={TAP.slop} onPress={() => setShowPw(v => !v)}>
                  <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "600" }}>
                    {showPw ? t.pwHide : t.pwShow}
                  </Text>
                </TouchableOpacity>
              </View>
            </IconField>
            <Text style={st.label}>{t.gender}</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2] }}>
              {t.genders.map(([val, lab]) => (
                <TouchableOpacity hitSlop={TAP.slop} key={val} onPress={() => setGender(gender === val ? null : val)}
                  style={[st.chip, gender === val && st.chipOn]}>
                  <Text style={[st.chipText, gender === val && st.chipTextOn]}>{lab}</Text>
                </TouchableOpacity>
              ))}
            </View>
            {/* ══════════════════════════════════════════════════════════
                🔴 v3.6 — REFERANS KODU ALANI HİÇ ÇİZİLMİYORDU.

                `refIn` state'i vardı (App.js), `apply_referral` RPC'si
                çağrılıyordu (`if (refIn.trim())`) — ama o değeri
                DOLDURACAK bir `TextInput` uygulamada hiçbir yerde yoktu.
                Yani `refIn` kalıcı olarak `""` ve o RPC dalı ÖLÜ KODDU.

                Sonuç: davet edilen kullanıcı, davet edildiği anda kodu
                giremiyordu. Kodu kullanmak için önce kaydolup, sonra
                Profil → Davet Et'e girip oraya yapıştırması gerekiyordu —
                yani davetin işe yaradığı AN geçtikten sonra.

                🆕 SINIF: "BİR VİRAL DÖNGÜ, KODUN GİRİLECEĞİ ALAN DAVETİN
                GELDİĞİ ANDA EKRANDA DEĞİLSE MEKANİK OLARAK VAR, PRATİKTE
                YOKTUR."
                ═══════════════════════════════════════════════════════ */}
            <Text style={st.label}>{t.refCodeOptional}</Text>
            <IconField icon={<Ikon ad="davet" boy={15} renk={C.muted} />}>
              <TextInput value={refIn} onChangeText={(x) => setRefIn(x.toUpperCase().trim())}
                autoCapitalize="characters" autoCorrect={false} maxLength={12}
                placeholder={t.refCodePlaceholder} placeholderTextColor={C.dim}
                accessibilityLabel={t.refCodeOptional}
                style={{ flex: 1, paddingVertical: SP[3], color: C.ink, fontSize: FS.base }} />
            </IconField>
            <Text style={{ color: C.mutedAA, fontSize: FS.xs, marginTop: SP[1], marginBottom: SP[2], lineHeight: 15 }}>
              {t.refCodeHint}
            </Text>

            <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: C.amber, borderRadius: R.xs, padding: SP[3], marginTop: SP[4] }}>
              <IkonMetin ad="uyari" renk={C.amberInk} stilMetin={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }} metin={t.noSellWarn} />
            </View>
            {/* 🔴 v2.99 — BU KUTU YOKTU VE HUNININ EN TEPESINDEKI TERK
                NOKTASIYDI. `validStep1()` `setErr(t.pwMin)` cagiriyordu ama
                `!!err` yalnizca ADIM 3'un icinde ciziliyordu. Kullanici 7
                haneli sifre yazip "Ileri"ye basiyor ve HICBIR SEY olmuyordu:
                ne kirmizi kutu, ne titreme, ne ekran degisimi. Urunun ilk
                saniyelerinde "bozuk" hukmu verdiren sey buydu.
                🆕 SINIF: "BIR DOGRULAMA, SONUCUNU CIZMEYEN BIR EKRANDA
                CALISMIYOR DEMEKTIR." */}
            {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
            <Btn label={t.next} onPress={() => validStep1() && setStep(2)} style={{ marginTop: ARA[20] }} />
          </>
        )}

        {step === 2 && (
          <>
            {/* 🔴 `roleAskSub` İKİ DİLDE DE YAZILMIŞ AMA HİÇBİR YERDEN
                ÇAĞRILMIYORDU ("yazıp çağırmamak" sınıfı). Oysa bu ekranın
                en çok ihtiyaç duyduğu cümle oydu: kullanıcı burada geri
                dönüşü olmayan bir seçim yaptığını sanıp duraksıyor —
                cevabı yazmışız ve göstermiyormuşuz. */}
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: SP[3] }}>
              {t.roleAskSub}
            </Text>
            {/* 🔴 v3.6 — ROL KARTLARININ İKONU METİN GLİFİYDİ.
                `✈\uFE0E` (metin sunumu zorlanmış uçak) ve `◎` — ikincisi
                Archivo'da YOK, yani sistem fontuna düşüyordu. Huninin
                ayrıldığı ekranda iki kartın ikonu iki farklı yazı
                karakterinden geliyordu. İkisi de `Ikon`a taşındı. */}
            {[["host", t.roleHost, t.roleHostSub, t.hostNextSteps, "ucus", C.goldBg, C.gold], ["guest", t.roleGuest, t.roleGuestSub, t.guestNextSteps, "salon", C.tealBg, C.teal]].map(([val, lab, sub, steps, ic, icBg, icFg]) => (
              <TouchableOpacity hitSlop={TAP.slop} key={val} onPress={() => setRole(val)} activeOpacity={0.8}
                accessibilityRole="radio" accessibilityLabel={lab + " — " + sub}
                accessibilityState={{ selected: role === val, checked: role === val }}
                style={{ backgroundColor: C.card, borderWidth: 1.5, borderColor: role === val ? C.gold : C.line, borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[10],
                         flexDirection: "row", alignItems: "center" , ...ELEV.card }}>
                <View style={{ width: 46, height: 46, borderRadius: R.sm, backgroundColor: icBg, alignItems: "center", justifyContent: "center", marginRight: SP[3] }}>
                  <Ikon ad={ic} boy={22} renk={icFg} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base }}>{lab}</Text>
                  <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>{sub}</Text>
                  {role === val && <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[6], lineHeight: 17 }}>{steps}</Text>}
                </View>
                <View style={{ width: 24, height: 24, borderRadius: R.full, borderWidth: 2, marginLeft: ARA[10],
                               borderColor: role === val ? C.gold : C.dim, alignItems: "center", justifyContent: "center" }}>
                  {role === val && <View style={{ width: 12, height: 12, borderRadius: R.full, backgroundColor: C.gold }} />}
                </View>
              </TouchableOpacity>
            ))}
            {/* MVP: kartlarin altinda ℹ bilgilendirme kutusu */}
            <View style={{ flexDirection: "row", gap: SP[2], backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], marginTop: ARA[6] , ...ELEV.card }}>
              <Ikon ad="bilgi" boy={FS.sm} renk={C.mut} />
              <Text style={{ color: C.mut, fontSize: FS.sm, flex: 1, lineHeight: 18 }}>{t.roleNote}</Text>
            </View>
            <View style={{ flexDirection: "row", gap: ARA[10], marginTop: ARA[14] }}>
              <Btn label={t.back2} v="ghost" onPress={() => setStep(1)} style={{ flex: 1 }} />
              <Btn label={t.next} onPress={() => setStep(3)} disabled={!role} style={{ flex: 2, opacity: role ? 1 : 0.45 }} />
            </View>
          </>
        )}

        {step === 3 && (
          <>
            {/* Tasarım 17 birebir: "Tümünü kabul et" 52 yüksek · yarıçap 12 ·
                altın tint zemin + altın kenar · kutu ikonu 19 · 14/600 altın metin.
                Satırlar: kutu 19 + 13 punto metin (işaretli `body`, değil `mut`). */}
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => setConsents(CONSENT_TEXTS.map(() => !allConsent))}
              accessibilityRole="checkbox" accessibilityLabel={t.consentAll}
              accessibilityState={{ checked: allConsent }}
              style={{ flexDirection: "row", alignItems: "center", gap: ARA[12], minHeight: 52,
                       backgroundColor: C.goldSoft, borderWidth: 1, borderColor: C.gold,
                       borderRadius: R.md, paddingHorizontal: ARA[14], marginBottom: ARA[20] }}>
              <Ikon ad={allConsent ? "kutuDolu" : "kutuBos"} boy={19} renk={C.gold} />
              <Text style={{ color: C.goldText, fontWeight: "600", fontSize: FS.base, flex: 1 }}>
                {t.consentAll}
              </Text>
            </TouchableOpacity>
            {CONSENT_TEXTS.map((txt, i) => (
              <TouchableOpacity hitSlop={TAP.slop} key={i} onPress={() => setConsents(c => c.map((v, j) => j === i ? !v : v))}
                accessibilityRole="checkbox" accessibilityLabel={txt}
                accessibilityState={{ checked: !!consents[i] }}
                style={{ flexDirection: "row", alignItems: "flex-start", gap: ARA[10], paddingVertical: ARA[6], minHeight: TAP.minHeight }}>
                <Ikon ad={consents[i] ? "kutuDolu" : "kutuBos"} boy={19} renk={consents[i] ? C.gold : C.mut} />
                <Text style={{ color: consents[i] ? C.body : C.mut, fontSize: FS.sm + 0.5, flex: 1, lineHeight: 19 }}>{txt}</Text>
              </TouchableOpacity>
            ))}
            {!!err && <View style={st.errBox}><Text style={st.errText}>{err}</Text></View>}
          </>
        )}

        {step === 1 && (
          <TouchableOpacity hitSlop={TAP.slop} style={{ marginTop: ARA[18], alignItems: "center" }} onPress={() => go("login")}>
            <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.yesAcc} <Text style={{ color: C.gold, fontWeight: "600" }}>{t.login}</Text></Text>
          </TouchableOpacity>
        )}
      </ScrollView>
      {/* tasarım 17: tam genişlik altın "Hesap Oluştur" (ok yok) EKRANIN
          ALTINDA sabit (alttan 58) — liste üstte kayar, düğme yerinde. */}
      {step === 3 && (
        <View style={{ paddingHorizontal: SP[5], paddingBottom: 58, paddingTop: ARA[10] }}>
          <Btn label={t.register} onPress={submit} disabled={!allConsent || busy} busy={busy} a11yLabel={t.register}
            style={{ opacity: allConsent ? 1 : 0.45 }} />
        </View>
      )}
      </KeyboardAvoidingView>
      {!!legal && (
        <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: C.paper }}>
          <LegalDoc t={t} docKey={legal} onBack={() => setLegal(null)} onOpen={setLegal} />
        </View>
      )}
    </Sayfa>
  );
}

// Saate gore selamlama (§ dokuman: zaman bazli karsilama).
// i18n'de greetMorning/greetAfternoon/greetEvening VARDI ama onlari
// seceni fonksiyon hic yazilmamis -> Home render'da ReferenceError.
function greetWord(t) {
  const h = new Date().getHours();
  if (h < 12) return t.greetMorning || "Günaydın";
  if (h < 18) return t.greetAfternoon || "İyi günler";
  return t.greetEvening || "İyi akşamlar";
}

// 🔴 26 AĞUSTOS — `onMeet` ÇAĞRI YERİNDE VERİLİYOR AMA İMZADA YOKTU.
// İkinci ölçüm: Home'un onu KULLANMASINA da gerek yokmuş — içerideki
// `SakinGun` zaten `setTab`i doğrudan alıyor. Yani prop'u imzaya eklemek
// "düzeltme" değil, ölü bir prop daha üretmek olurdu. Doğrusu ÇAĞRI
// YERİNDEN kaldırmaktı.
// Tasarım denetimlerinin kapsamı `App.js`e açılır açılmaz çıktı: prop
// geçiliyor, bileşen onu hiç almıyor, davranış SESSİZCE kayboluyor.
// Dört prop da (toggleLang, onBell, unread, setOdakAvail) imzada var ama
// gövdede hiç okunmuyordu — okunmayan bir prop, bir sonraki geliştiriciye
// "burada bir bağlantı var" diye yalan söyler.
// 🆕 SINIF: "BİR PROP'U VERMEK, ONU ALMAK DEMEK DEĞİLDİR — VE ARADAKİ FARK
// HİÇBİR HATA ÜRETMEZ."
// 🔴 30 Ağu — `setMeetSub` ve `setShowIstekler` PROP OLARAK EKLENDİ.
// `Home` ayrı bir bileşen; `AppInner`ın state'ine doğrudan erişemez.
// İlk yazımda akış kutucuklarının yönlendirmesini burada `setMeetSub(...)`
// diye yazdım ve check.js hemen yakaladı: "satır 2779 — 'setMeetSub'
// TANIMSIZ". Kapsam hatası, çalışma anında beyaz ekran olurdu.
// 🆕 SINIF: "BİR DEĞİŞKENİ GÖRÜYOR OLMAN KAPSAMDA OLDUĞU ANLAMINA
// GELMEZ — AYNI DOSYA, AYNI KAPSAM DEĞİLDİR."
// 🔴 18 EYLÜL — `setMeetSub` İMZADAN ÇIKTI. Akış şeridi artık "reqs"/"conns"
// alt görünümlerine değil, kendi tam ekranlarına gidiyor (md.4); prop
// gövdede okunmayan bir yalan hâline gelmişti ve `check.js` yakaladı.
export function Home({ t, lang, session, onOpenChat, onOpenCompanion, onVerify, onRole, setRadar, setTab, setHostTripsSub, onWallet, onOpenProfile, onDiscover, setShowQuestions, onGuide, setShowIstekler, setShowDavetler, setShowSohbetler, onProfilSekmesi }) {
  const [data, setData] = useState(null);
  // 13 Eylül md.8/15 — durum çubuğu perdesi için kaydırma konumu.
  const kaydirY = useRef(new Animated.Value(0)).current;
  // 🔴 v2.95 — `onRefresh={() => {}}` NÖBETÇİ TARAFINDAN YAKALANDI.
  // Yeni yazdığım `bos_isleyici_check.py` ilk koşuşunda burayı gösterdi:
  // ActionNeeded bir daveti/bağlantıyı kabul ettikten SONRA `onRefresh()`
  // çağırıyor — ana sayfa tazelensin diye. Ama ana sayfa ona BOŞ BİR
  // FONKSİYON veriyordu. Sonuç: kullanıcı daveti kabul ediyor, üstteki
  // istatistikler ve paneller ESKİ hâlinde kalıyor, "bir şey olmadı"
  // hissi doğuyordu. Nöbetçiyi madde 12 için yazdım, bana madde 12'nin
  // KARDEŞİNİ buldu.
  const [tazele, setTazele] = useState(0);
  const [buAyAcik, setBuAyAcik] = useState(false);   // 5 Eylül — BU AY katlanır
  const [yukErr, setYukErr] = useState("");
  // 🔴 v2.96 (eleştiri F1) — HUNİ. Bu turda kredi ekonomisini, açık istek
  // tavanını ve ödül fiyatlarını ayarladık; hiçbirinin etkisini
  // ölçemiyorduk çünkü hiçbir yerde huni yoktu.
  // 🆕 SINIF: "AYARLAMAYI ÖLÇEMEDİĞİN BİR SİSTEMİ AYARLAMAK, AYARLAMAK
  // DEĞİL TAHMİN ETMEKTİR."
  // Üçüncü parti analitik YOK — bilinçli: bu ürünün en hassas verisi
  // "kim nerede, ne zaman" ve onu dışarı çıkarmıyoruz. Sunucudaki
  // `huni_yaz` 60 saniyelik gürültü kapısı taşıyor; olay adları da
  // veritabanı kısıtıyla beş taneyle sınırlı.
  useEffect(() => {
    if (!session?.user?.id) return;
    supabase.rpc("huni_yaz", { p_olay: "app_acildi" })
      .then(({ error }) => { if (error) logError("huni_yaz", error); });
  }, [session?.user?.id]);
  useEffect(() => {
    (async () => {
      const uid = session?.user?.id;
      if (!uid) return;
      // 🔴 DUZELTME: points_ledger'da balance_after KOLONU YOK — eski sorgu
      // sessizce bos donuyordu, Puan HER ZAMAN 0 gorunuyordu (ekran
      // goruntusundeki "Puan 0" bundandi). user_balances view'i (001) dogru kaynak.
      // 🔴 26 AĞUSTOS — ROL SORGUSUNUN HATASI YUTULUYORDU VE SONUCU AĞIRDI:
      // `ur?.role || "guest"` → ağ bir an koparsa HOST, MİSAFİR PANOSUNU
      // görüyordu. Ekranda hata yok, spinner yok, yalnız YANLIŞ ÜRÜN.
      // Rol, bu uygulamada hangi ekranların var olduğunu belirliyor;
      // bilinmiyorsa "misafir" varsaymak bir varsayılan değil bir İDDİADIR.
      // 🆕 SINIF: "BİR VARSAYILAN, HATA HÂLİNDE DE DOĞRU OLMALIDIR —
      // DEĞİLSE O BİR VARSAYILAN DEĞİL, SESSİZ BİR YANLIŞTIR."
      const [{ data: p }, { data: ur, error: eRole }, { data: ts }, { data: v }, { data: bal }] = await Promise.all([
        supabase.from("profiles").select("name").eq("user_id", uid).maybeSingle(),
        supabase.from("users").select("role").eq("id", uid).maybeSingle(),
        supabase.from("trust_scores").select("score, badge").eq("user_id", uid).maybeSingle(),
        supabase.from("verifications").select("phone_verified").eq("user_id", uid).maybeSingle(),
        supabase.from("user_balances").select("credits, points").eq("user_id", uid).maybeSingle(),
      ]);
      if (eRole) {
        logError("home_role", eRole);
        setYukErr(mapErr(t, eRole.message));
        return;   // rolü bilmeden ekran çizmiyoruz
      }
      setYukErr("");
      const role0 = ur?.role || "guest";
      if (ur?.role && onRole) onRole(ur.role);
      // #28: host icin MVP istatistikleri — Bekleyen / Aktif / Oturum
      let hostStats = null, myAvs = [];
      if (role0 === "host") {
        const [{ data: reqs }, { data: avs }, { count: sc }] = await Promise.all([
          supabase.from("requests").select("id, status").eq("host_id", uid),
          supabase.from("availabilities").select("id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled").eq("host_id", uid).eq("active", true).gte("avail_date", yerelGun()).order("avail_date").limit(3),
          supabase.from("sessions").select("id, requests!inner(host_id)", { count: "exact", head: true }).eq("status", "completed").eq("requests.host_id", uid),
        ]);
        hostStats = {
          pending: (reqs || []).filter(r => r.status === "pending").length,
          active: (avs || []).length,
          sessions: sc ?? 0,
        };
        myAvs = avs || [];
        // #7: bu ayki kazanç görünürlüğü — host motivasyonu
        const monthStart = new Date(); monthStart.setDate(1);
        const msIso = yerelGun(monthStart);
        const [{ count: monthSes }, { data: monthPts }] = await Promise.all([
          supabase.from("sessions").select("id, requests!inner(host_id)", { count: "exact", head: true })
            .eq("status", "completed").eq("requests.host_id", uid).gte("completed_at", msIso),
          supabase.from("points_ledger").select("delta").eq("user_id", uid).gte("created_at", msIso),
        ]);
        const ptsThisMonth = (monthPts || []).reduce((s, r) => s + (r.delta > 0 ? r.delta : 0), 0);
        // sıradaki kademeye kaç oturum kaldı (046: 6/10/14 eşikleri)
        const tot = sc ?? 0;
        const nextTierAt = tot < 6 ? 6 : tot < 10 ? 10 : tot < 14 ? 14 : null;
        hostStats.monthSessions = monthSes ?? 0;
        hostStats.monthPoints = ptsThisMonth;
        hostStats.toNextTier = nextTierAt ? nextTierAt - tot : 0;
        // 🔴 4 Eylül — ilan kartındaki çip SABİT "Misafir ücretsiz" yazıyordu;
        // ücretli/misafir almayan salonlarda host'a kendi ilanı hakkında YALAN
        // söylüyordu. Kural motorunun kararı (Keşfet'teki çiple aynı kaynak).
        const kararlar = await Promise.all(myAvs.map(a =>
          Promise.resolve(supabase.rpc("availability_rule_snapshot", { p_avail_id: a.id }))
            .then(({ data: k, error: eK }) => { if (eK) logError("ilan_kural_cipi", eK); return k && k.guest_policy; })
            .catch(() => null)));
        myAvs = myAvs.map((a, i) => ({ ...a, guest_policy: kararlar[i] || null }));
      }
      setData({
        name: p?.name || session.user.email,
        role: role0,
        score: ts?.score ?? 0, badge: ts?.badge || "New",
        credits: bal?.credits ?? 0,
        points: bal?.points ?? 0,
        phoneVerified: !!v?.phone_verified,
        hostStats, myAvs,
      });
    })();
  }, [session, tazele]);

  // Hata varsa SPINNER DEĞİL, yeniden deneme. Sonsuz spinner "yükleniyor"
  // demez, "bozuk" der — ve kullanıcı ikincisine inanır.
  if (yukErr) return (
    <View style={[st.center, { flex: 1, padding: SP[5] }]}>
      <Ikon ad="yenile" boy={22} renk={C.mutedAA} />
      <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "700", textAlign: "center" }}>{t.loadFailTitle}</Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: SP[2], lineHeight: 18 }}>{yukErr}</Text>
      <TouchableOpacity onPress={() => setTazele(x => x + 1)} hitSlop={TAP.slop}
        accessibilityRole="button" accessibilityLabel={t.retry}
        style={{ minHeight: TAP.minHeight, justifyContent: "center", marginTop: SP[3] }}>
        <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "700" }}>{t.retry}</Text>
      </TouchableOpacity>
    </View>
  );
  // 🔴 v3.4 — "Yükleniyor" yazısı KALDIRILDI. Dönen gösterge zaten onu
  // söylüyor; yanına kelimeyle yazmak aynı bilgiyi iki kez vermektir.
  if (!data) return <View style={[st.center, { flex: 1 }]}><MarkaYukleyici boy={48} /></View>;

  // MVP HostDashboard/GuestDashboard birebir: solda kucuk harf-aralikli
  // selamlama + SERIF isim, sagda SERIF altin LoungePuan; altinda rozet pili,
  // bgAlt istatistik kutulari. Debug notu ve Ana Sayfa'daki Cikis Yap
  // KALDIRILDI — MVP'de cikis yalniz Profil'in en altinda.
  return (
    <>
    {/* ══════════════════════════════════════════════════════════════════
        🔴 13 EYLÜL (Gökberk md.8 / md.15) — KAYDIRINCA İÇERİK SAATİN
        ARKASINA GİRİYOR.
        Ölçtüm (gerçek render, kaydırma sonrası): ana sayfada bant
        `ScrollView`ın İÇİNDE olduğu için yukarı kayıp EKRANDAN ÇIKIYOR ve
        kartlar y=0'dan başlıyor. Öteki sekmelerde bant mutlak konumlu ve
        kaydırınca kompakt çubuğa dönüşüyor — yani orada durum çubuğunun
        altı hep opak. Ana sayfa bu desenin tek istisnasıydı; Gökberk'in
        15. görselinde "bağlantı kurmak istiyor" satırı pilin üstünde.
        Çözüm bir TASARIM ÖĞESİ DEĞİL, bir perde: yalnız bant geçildikten
        sonra beliren, durum çubuğu boyunda opak bir şerit. Bant
        görünürken opaklığı 0 — yani bugünkü görüntü hiç değişmiyor.
        🆕 SINIF: "BİR BANDIN KAYDIRMAYLA EKRANDAN ÇIKMASI, ALTINDAKİ
        İÇERİĞİ DURUM ÇUBUĞUNA TESLİM ETMEKTİR."
        ══════════════════════════════════════════════════════════════════ */}
    {TOPPAD > 0 && (
      <Animated.View pointerEvents="none"
        style={{ position: "absolute", top: 0, left: 0, right: 0, height: TOPPAD,
                 backgroundColor: C.paper, zIndex: 30,
                 opacity: kaydirY.interpolate({ inputRange: [0, 60, 140], outputRange: [0, 0, 1], extrapolate: "clamp" }) }} />
    )}
    <ScrollView contentContainerStyle={{ paddingBottom: ARA[40] }}
      scrollEventThrottle={16}
      onScroll={Animated.event([{ nativeEvent: { contentOffset: { y: kaydirY } } }], { useNativeDriver: false })}>
      {/* ══════════════════════════════════════════════════════════════
          🔴 3 EYLÜL — ANA SAYFA BAŞLIĞI ARTIK `FotoBant` (tasarım 11/12).

          Cihaz ekran görüntüsü (Gökberk, 3 Eylül) üç şeyi gösterdi ve
          üçü de bu blokta çıktı:
            1. ÇİFT "LOUNGELINK" — kabuk (Main) ana sekmeye bir BrandBar
               çiziyor, bu blok da kendi markasını yazıyordu.
            2. DÜZ SİYAH BANT — burada `backgroundColor: C.meshUst` ile
               düz bir View vardı; tasarımın `.ust.mesh`i (fotoğraf %16 +
               iki hale) yalnız `FotoBant`ta yaşıyordu, ana sayfa onu
               hiç kullanmıyordu.
            3. TASARIMDA OLMAYAN PARÇALAR — "Temel Doğrulama" pili ve
               Kredi/Güven kutuları (cüzdan şeridi zaten ikisini de
               taşıyor: aynı sayı iki kez).

          🆕 SINIF: "TASARIMIN KABUĞUNU BİR BİLEŞENE KOYUP O BİLEŞENİ EN
          ÇOK AÇILAN EKRANDA KULLANMAMAK, TASARIMI UYGULAMAMAKTIR."

          Misafir (11): İYİ GÜNLER → isim (Cormorant 52) → cüzdan şeridi
          BANDIN İÇİNDE. Host (12): "SELİN B. · GÜVENİLİR HOST" → Ana
          Sayfa (sans 40). Sağ üst: tasarımın `.ust-eylem` dairesi
          (profil) — Profil sekmesine gider.
          ══════════════════════════════════════════════════════════════ */}
      {/* 5 EYLÜL — HOST DA MİSAFİRLE AYNI İSKELET (Gökberk madde 5): selam
          düğümü · serif isim (host'ta "Selin B." + rozet çipi) · cüzdan
          şeridi (kredi · LoungePuan · güven) BANDIN İÇİNDE; şerit tek bileşen
          (`CuzdanSeridi`), hücreler eşit dağılır. Sağ üst profil dairesi
          iki rolde de var. */}
      <FotoBant marka="LOUNGELINK"
        sag={onProfilSekmesi ? (
          <Btn v="ust" daire a11yLabel={t.navProfile} onPress={onProfilSekmesi}
            sol={<Ikon ad="profil" boy={19} renk={C.foto.baslik} />} />
        ) : null}
        ustBilgi={greetWord(t)}
        serifBaslik={data.role === "host" ? shortName(data.name) : (String(data.name || "").trim().split(/\s+/)[0] || data.name)}
        serifYani={data.role === "host" ? <Cip etiket={`• ${badgeLabel(t, data.badge, "host")}`} ton="ok" /> : null}
        altIcerik={
          <CuzdanSeridi hucreler={[
            { deger: data.credits ?? 0, etiket: t.walletCredits || "kredi", onPress: onWallet },
            { deger: (data.points || 0).toLocaleString("tr-TR"), etiket: t.marketTitle },
            { deger: data.score ?? 0, etiket: t.trust || "Güven" },
          ]} />
        } />

      <View style={{ paddingHorizontal: ARA[22], paddingTop: ARA[20] }}>
      {!data.phoneVerified && (
        // ══════════════════════════════════════════════════════════════
        // 🔴 12 EYLÜL (Gökberk md.4) — "39. görselde ekranda taşma var".
        // ÖLÇÜLDÜ (gerçek DOM, 390 pt cihaz): metin kutusu 638 pt,
        // içinde durduğu kart 346 pt → 292 pt ekran dışında.
        // Sebep: metne `flex: 1` verilmişti ama ONU SARAN SATIR
        // `flex: 0 0 auto` idi. Bir çocuğun `flex: 1`i, ebeveyni
        // daralmıyorsa hiçbir şey yapmaz — satır 657 pt'ye kadar büyüyüp
        // kartı taşırdı, metin de sarmadan tek satır kaldı.
        // `flex: 1 + minWidth: 0` satırı daraltılabilir yapar; metin
        // artık sarıyor. `alignItems` de "center"dan "flex-start"a geçti:
        // iki satırlık bir uyarıda ikon ortada asılı kalıyordu.
        // 🆕 SINIF: "`flex: 1` BİR İSTEK DEĞİL, EBEVEYNDEN GELEN BİR
        // İZİNDİR — ZİNCİRDEKİ İLK DARALMAYAN KUTU ONU İPTAL EDER."
        // ══════════════════════════════════════════════════════════════
        <TouchableOpacity hitSlop={TAP.slop} onPress={onVerify} style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: C.amber + "40", borderRadius: R.sm, padding: SP[3], flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start" }}>
          <View style={{ flexDirection: "row", alignItems: "flex-start", flex: 1, minWidth: 0 }}><Ikon ad="telefon" boy={15} renk={C.mutedAA} stil={{ marginRight: SP[1], marginTop: ARA[2] }} /><Text style={{ color: C.amberInk, fontSize: FS.sm, flex: 1, minWidth: 0, lineHeight: 18 }}>{t.phoneWhy}</Text></View>
          <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm, marginLeft: SP[2] }}>{t.goVerify}</Text>
        </TouchableOpacity>
      )}

      </View>

      <View style={{ padding: SP[4] }}>

      {/* ══════════════════════════════════════════════════════════════
          🔴 v2.96 (eleştiri E1) — ANA SAYFA ARTIK YALNIZCA "ŞİMDİ".

          v2.95'te on paneli üç bölgeye ayırmıştım (ŞİMDİ / PLANIM / AĞIM).
          Gökberk'in cevabı doğruydu: bölge bir çözüm değil, bir erteleme.
          "PLANIM ve AĞIM aslında birer sekme olmalı."

          Uyguladım. Ana sayfada artık YALNIZCA aksiyon gerektiren şeyler
          var; geri kalan her şey kendi sekmesinde YAŞIYOR — kopyası
          burada durmuyor:

            PLANIM  → 2. sekme (İlanlarım · Seyahatlerim)
            AĞIM    → Tanış sekmesi (Keşfet · Bağlantılar · İstekler)
            Bir cümle / puanlama geçmişi → Profil > Değerlendirmeler

          🆕 SINIF: "BİR ŞEYİ HEM ANA SAYFAYA HEM KENDİ SEKMESİNE KOYARSAN,
          KULLANICI İKİSİNİN FARKLI ŞEYLER OLDUĞUNU SANIR."

          ⚠️ TEK İSTİSNA VE GEREKÇESİ: bekleyen hiçbir işi olmayan
          kullanıcıya boş bir ekran göstermek, "burada yapacak bir şey yok"
          demektir. Onun için ANA SAYFANIN BOŞ HÂLİ bir giriş kapısına
          dönüşüyor (aşağıda) — bu da bir aksiyondur.
          ══════════════════════════════════════════════════════════════ */}
      {/* ── ULAŞILABİLİRLİK (G7) ────────────────────────────────────
          Bekleyen istek ya da yayında ilan varken bildirim kapalıysa,
          bu kart ActionNeeded'dan da ÖNCE gelir: aşağıdaki hiçbir işi
          zamanında GÖREMEYECEK olması, o işlerin kendisinden önce
          söylenmesi gereken şeydir. ─────────────────────────────────── */}
      {/* 🔴 v3.4 — AKIŞ ŞERİDİ. Aşağıdaki altı bölümün hepsi "boşsa
          çizilme" kuralıyla yazılı; altısı birden kaybolduğunda ana sayfa
          "bu özellikler var mı?" dedirtiyordu (Gökberk'in maddesi).
          Bu şerit HER ZAMAN çiziliyor — sıfır da bir bilgidir. */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS — BEŞ KUTUCUĞUN ÜÇÜ YANLIŞ YERE GİDİYORDU.
          Gökberk: "akışlar başlığındaki alanların doğru yönlendirmeleri
          ve gösterimleri yaptığından emin ol." Emin olmak için sayacın
          NE SAYDIĞINI (sql/263) yönlendirmenin NEREYE GİTTİĞİYLE tek tek
          karşılaştırdım:

            Sohbetler → home_connections()          → setTab("meet") ⇒ KEŞFET'e düşüyordu
            İstekler  → requests (pending, lounge)  → setTab("meet") ⇒ KEŞFET'e düşüyordu
            Davetler  → pending_actions kind=invite → SADECE tazele ⇒ HİÇBİR YERE
            Sorularım → sorularim()                 → ✓ doğru
            İlanlarım → availabilities (aktif)      → ✓ doğru

          İkinci satır en sinsisi: `setTab("meet")` alt sekmeyi kurmuyor,
          Tanış varsayılan sekmesi olan Keşfet'te açılıyordu. Kullanıcı
          "İstekler"e basıp Keşfet görüyordu. Tanış'ın kendi "İstekler"
          sekmesi ise BAĞLANTI istekleri — yani lounge isteğiyle alakasız
          bir liste; boş görünmesinin sebebi de buydu.

          🆕 SINIF: **"BİR SAYAÇ İLE ONA BASINCA AÇILAN EKRAN AYNI ŞEYİ
          SAYMIYORSA, SAYI DOĞRU OLSA BİLE ARAYÜZ YALAN SÖYLER."**

          `İstekler`in gidecek bir ekranı YOKTU: `RequestsPanel` yalnız
          host'a ve yalnız ana sayfada çiziliyordu. Misafirin gönderdiği
          istekler hiçbir ekranda toplu görünmüyordu. Artık kendi tam
          ekranı var (gelen + gönderilen, ikisi de).
          ══════════════════════════════════════════════════════════════ */}
      <AkisSeridi t={t} tazele={tazele} rol={data.role}
        onSohbetler={() => setShowSohbetler(true)}
        onIstekler={() => setShowIstekler(true)}
        onDavetler={() => setShowDavetler(true)}
        onSorular={() => setShowQuestions(true)}
        onIlanlar={() => { setHostTripsSub("ilan"); setTab("trips"); }} />
      {data.role === "host" && data.hostStats ? (
        /* ── TASARIM 12b · HOST: Akışım'ın ALTINDA "BU AY" (katlanır) → çipler → ilanlar ── */
        <>
        {/* 5 Eylül — BU AY KATLANIR (Gökberk madde 5): kapalı hâli tek satır
            özet + ok; açınca kademe ve kart hakkı satırları. Varsayılan kapalı:
            ilanlar ekranın üst yarısında kalır. */}
        {/* Katlanır kart (`Katlanir` deseni): zemin ve köşe SARMALAYICIDA, dokunma
            yüzeyi içeride — bu bir düğme değil, başlığı dokunulabilir bir kart. */}
        <View style={{ backgroundColor: C.goldBg, borderRadius: R.lg, overflow: "hidden" }}>
        <TouchableOpacity activeOpacity={0.85} onPress={() => setBuAyAcik(v => !v)}
          accessibilityRole="button" accessibilityLabel={t.hostMonthTitle}
          accessibilityState={{ expanded: buAyAcik }}
          style={{ paddingVertical: ARA[14], paddingHorizontal: SP[4], minHeight: TAP.minHeight }}>
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.micro + 0.5, letterSpacing: 1.2 }}>{BUYUK(t.hostMonthTitle)}</Text>
              <Text numberOfLines={buAyAcik ? undefined : 1}
                    style={{ color: C.ink, fontWeight: "600", fontSize: FS.sm + 0.5, marginTop: ARA[3], lineHeight: 18 }}>
                {(buAyAcik ? t.hostMonthBody : t.hostMonthShort)
                  .replace("{ses}", data.hostStats.monthSessions)
                  .replace("{pts}", data.hostStats.monthPoints)}
              </Text>
            </View>
            <Ikon ad={buAyAcik ? "yukari" : "asagi"} boy={18} renk={C.goldText} stil={{ marginLeft: ARA[10] }} />
          </View>
          {buAyAcik ? (
            <>
              {data.hostStats.toNextTier > 0 ? (
                <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: ARA[8] }}>
                  {t.hostToNextTier.replace("{n}", data.hostStats.toNextTier)}
                </Text>
              ) : null}
              <Text style={{ color: C.goldText, fontWeight: "600", fontSize: FS.sm, marginTop: ARA[8] }}>
                {t.hwWalletUnknown} · {data.hostStats.active} {t.hwHostings}
              </Text>
            </>
          ) : null}
        </TouchableOpacity>
        </View>
        {/* ══════════════════════════════════════════════════════════
            🔴 18 EYLÜL (Gökberk md.7) — "ana sayfada seyahatlerim ve
            ilanlarım sekmeleri gelmiş. Neden bu var anlamadım."
            KALDIRILDI. Ölçüm: bu iki çip, `Seyahatler` sekmesinin KENDİ
            başlığındaki çiplerin (App.js `trips` başlığı) birebir
            kopyasıydı ve ikisi de aynı yere gidiyordu. Ana sayfada bir
            SEKME ÇUBUĞU çizmek, kullanıcıya "burada bir sekme var"
            demektir — oysa alt çubukta zaten var.
            🆕 SINIF: "BİR GEZİNTİYİ İKİNCİ BİR YERE KOPYALAMAK
            KEŞFEDİLEBİLİRLİK DEĞİL, 'HANGİSİ DOĞRU?' SORUSUDUR."
            Altındaki ilan kartları duruyor: onlar gezinti değil İÇERİK.
            ══════════════════════════════════════════════════════════ */}
        {data.myAvs.map((a) => (
          <View key={a.id} style={{ backgroundColor: C.surface, borderWidth: 1, borderColor: C.line,
                                    borderRadius: R.lg, padding: SP[4], marginTop: ARA[12], ...ELEV.card }}>
            <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base }}>
              {(a.lounge_name || t.lounge)} · {a.airport_code}
            </Text>
            <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: ARA[4] }}>
              {String(a.time_from || "").slice(0, 5)} – {String(a.time_to || "").slice(0, 5)}
            </Text>
            <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: ARA[12] }}>
              {/* 11 Eylül — karar rozeti tek kaynaktan (`KararCipi`, ui.js).
                  Burada "included→teal, gerisi→amber" diye kendi sözlüğünü
                  yazıyordu; Keşfet ve ön-kontrol başka sözlük kullanıyordu. */}
              <KararCipi t={t} politika={a.guest_policy} />
              <TouchableOpacity hitSlop={TAP.slop} onPress={onDiscover} accessibilityRole="button">
                <Text style={{ color: C.goldText, fontWeight: "600", fontSize: FS.sm }}>{t.discTitle}</Text>
              </TouchableOpacity>
            </View>
          </View>
        ))}
        </>
      ) : null}
      {/* 4 Eylül — TASARIM 11 SIRASI: dört kutunun hemen altında BUGÜN kartı.
          Aksiyon kartları (yaş onayı, ulaşılabilirlik, bekleyen işler,
          bağlantı istekleri) onun ALTINDA — ilk ekran tasarımla aynı. */}
      {/* ── SAKİN GÜN: ana sayfanın boş hâli bir giriş kapısı ────────── */}
      <SakinGun t={t} session={session}
        role={data.role}
        bekleyenVar={!!(data.hostStats && data.hostStats.pending > 0)}
        onDiscover={onDiscover}
        onPlan={() => { setHostTripsSub(data.role === "host" ? "ilan" : "seyahat"); setTab("trips"); }}
        onHostOl={() => { setHostTripsSub("ilan"); setTab("trips"); }}
        onGuide={onGuide}
        onMeet={() => setTab("meet")} />
      <YasOnayi t={t} />
      <UlasilabilirlikKarti t={t} tazele={tazele} goster={["kritik", "uyari"]} />
      <ActionNeeded t={t} lang={lang} onRefresh={() => setTazele(x => x + 1)} />
      {data.role === "host" && data.hostStats && data.hostStats.pending > 0 && (
        <RequestsPanel t={t} lang={lang} session={session} onOpenChat={onOpenChat} onOpenProfile={onOpenProfile} />
      )}
      <LoungeRadarCard t={t} session={session} onOpen={(r) => { setRadar(r); setTab("meet"); }} />
      <RateReminder t={t} lang={lang}
        onRate={(it) => it?.request_id && onOpenChat && onOpenChat({ req: { id: it.request_id }, name: it.other_name, openPanel: true })} />
      {/* 5 Eylül — ÖLÇÜLDÜ (SEED6 · host1 ana sayfa): gelen bağlantı isteği
          hem "AKSİYON GEREKLİ" kartında hem "BAĞLANTI İSTEKLERİ" panelinde,
          aynı ekranda İKİ KEZ. `pending_actions` zaten her gelen bağlantıyı
          taşıyor; panel Tanış → Bağlantılarım'da duruyor. Burada kaldırıldı. */}

      {/* Kaybedecek bir şeyi henüz olmayan kullanıcı için izin HAZIRLIĞI
          burada: sakin gün, ısrar etmeden anlatmak için doğru an. */}
      <UlasilabilirlikKarti t={t} tazele={tazele} goster={["bilgi"]} />
      <HomeConnections t={t} session={session} onOpenChat={onOpenCompanion} />
      </View>
    </ScrollView>
    </>
  );
}

function Stat({ label, value, onPress }) {
  const body = (
    <View style={st.stat}>
      <Text style={{ fontSize: FS.title, fontWeight: "700", color: C.gold, fontFamily: MONO[600] }}>{value}</Text>
      <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[2] }}>{label}</Text>
    </View>
  );
  return onPress ? <TouchableOpacity hitSlop={TAP.slop} style={{ flex: 1 }} onPress={onPress} activeOpacity={0.7}>{body}</TouchableOpacity> : body;
}

// 🔴 AYNI TUZAK, İKİNCİ YER: `StyleSheet.create` DEĞERLERİ ANINDA
// OKUR. `st.logoBox`un zemini `C.card`ı modül yüklenirken kopyalıyor;
// tema değişince o kopya değişmiyor. `S` ile aynı çözüm: nesne kimliği
// korunuyor, içi yenileniyor.
function kurSt() {
  return StyleSheet.create({
  center: { alignItems: "center", justifyContent: "center" },
  logoBox: { width: 92, height: 92, borderRadius: R.lg, backgroundColor: C.card, alignItems: "center", justifyContent: "center", marginBottom: ARA[18], borderWidth: 1.5, borderColor: C.goldLine , ...ELEV.card },
  brand: { fontSize: FS.bant, fontWeight: "700", color: C.goldText },
  brandSub: { fontSize: FS.xs, letterSpacing: 4, color: C.mut, marginTop: ARA[2] },
  tagline: { fontSize: FS.title, color: C.ink, textAlign: "center", marginTop: ARA[22], fontWeight: "600", lineHeight: 28 },
  sub: { fontSize: FS.sm, color: C.mut, textAlign: "center", marginTop: ARA[10], lineHeight: 20 },
  pill: { backgroundColor: C.goldSoft, borderRadius: R.sm, paddingVertical: SP[1], paddingHorizontal: SP[3] },
  // pill zemini goldSoft (#FAF6EC); C.gold orada 2.71:1 — goldText 4.55:1.
  pillText: { color: C.goldText, fontSize: FS.xs, fontWeight: "600" },
  // ══════════════════════════════════════════════════════════════════
  // 🔴 26 AĞUSTOS — UYGULAMANIN EN ÇOK BASILAN DÜĞMESİ OKUNMUYORDU.
  //
  // ÖLÇÜM:  C.gold (#B8943A) zemin + beyaz metin = 2.86:1   (gereken 4,5)
  //         btnGhost kenarlığı C.gold on C.bg    = 2.65:1   (gereken 3,0)
  //
  // Bu stiller Splash'teki "Başla", giriş ekranındaki "Giriş yap" ve
  // kayıt sihirbazındaki "Hesap Oluştur" düğmeleri — yani kullanıcının
  // GÖRDÜĞÜ İLK ÜÇ EKRANIN ana eylemi.
  //
  // v2.65'te tam bu iş için `C.goldBtn` (#846A2A · 5.15:1) ve
  // `C.goldText` (#8C702C · 4.70:1) tanımlanmıştı. `src/ortak.js` onları
  // kullanıyor; App.js kullanmıyordu. Rozetlerde bulduğum kusurun aynısı:
  // düzeltme katmanı kuruldu, bir dosya ona hiç bağlanmadı.
  //
  // 🆕 SINIF: "BİR DÜZELTMEYİ 'PALETE EKLEDİM' DİYE BİTMİŞ SAYARSAN,
  // O PALETİ KULLANMAYAN DOSYA DÜZELTİLMEMİŞ KALIR — VE GENELDE EN
  // ESKİ, EN ÇOK GÖRÜLEN DOSYADIR."
  //
  // Köşeler de R ölçeğine bağlandı (12 → R.sm 10 · bkz. theme.js).
  // ══════════════════════════════════════════════════════════════════
  btn: { backgroundColor: C.goldBtn, borderRadius: R.sm, paddingVertical: ARA[14], alignItems: "center" },
  btnText: { color: C.onAccent, fontSize: FS.base, fontWeight: "700" },
  // Kenarlık artık goldText: 4.70:1 — hem 3,0 kenarlık eşiğini hem de
  // üstündeki metnin 4,5 eşiğini tek renkle karşılıyor.
  btnGhost: { borderWidth: 1.5, borderColor: C.goldText, borderRadius: R.sm, paddingVertical: SP[3], alignItems: "center" },
  btnGhostText: { color: C.goldText, fontSize: FS.base, fontWeight: "600" },
  h1: { fontSize: FS.display, fontWeight: "700", color: C.ink, marginBottom: ARA[10] },
  label: { fontSize: FS.xs, letterSpacing: 1.5, color: C.mut, marginTop: SP[4], marginBottom: ARA[6], fontWeight: "600" },
  inputBare: { paddingVertical: SP[3], fontSize: FS.base, color: C.ink },
  input: { backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, paddingVertical: SP[3], paddingHorizontal: ARA[14], fontSize: FS.base, color: C.ink , ...ELEV.card },
  chip: { borderWidth: 1, borderColor: C.line, borderRadius: R.md, paddingVertical: SP[2], paddingHorizontal: ARA[14], backgroundColor: C.card , ...ELEV.card },
  chipOn: { borderColor: C.gold, backgroundColor: C.goldSoft },
  chipText: { fontSize: FS.sm, color: C.ink },
  chipTextOn: { color: C.goldText, fontWeight: "600" },
  errBox: { backgroundColor: C.hataBg, borderRadius: R.xs, padding: ARA[10], marginTop: ARA[14] },
  // errBox zemini #FBEAE9; C.red orada 4.28:1 — redInk 6.31:1.
  errText: { color: C.redInk, fontSize: FS.sm },
  stat: { flex: 1, backgroundColor: C.bgAlt, borderRadius: R.sm, padding: ARA[14], alignItems: "center" },});
}

const st = kurSt();
temaYenidenKur(() => {
  const y = kurSt();
  for (const k of Object.keys(st)) delete st[k];
  Object.assign(st, y);
});

// ============================================================
// KOK SARMALAYICI (v2.39)
//
// 🔴 Sinir App'in ICINE degil DISINA konur. Icine koysaydik, App'in
// kendi govdesinde olusan bir hata siniri da birlikte goturur ve
// beyaz ekran yine gorunurdu.
//
// `t` prop'u opsiyonel: dil yuklenmeden once cokme olursa bile
// ErrorBoundary kendi varsayilan Turkce metinleriyle calisir. Hata
// ekraninin de bir hataya bagli olmasi, ilk kuralin ihlalidir.
// ============================================================
export default function App() {
  // 🔴 12 EYLÜL (Gökberk md.3) — TANECİK KÖKTE, TEK KOPYA.
  // Gren uygulamanın TAMAMININ üstüne seriliyor: bantlanan yalnız sayfa
  // zemini değil, header fotoğrafı, kart gradyanları ve hale de.
  // `Sayfa` içine koyduğumda üç sekme aynı anda mount olduğu için üç kez
  // çiziliyordu (ölçüm: zemin 11 → 8.58). Burada tek kopya (11 → 10.5).
  return (
    <ErrorBoundary>
      <View style={{ flex: 1 }}>
        <AppInner />
        <Tanecik />
      </View>
    </ErrorBoundary>
  );
}

// ============================================================
// 🔵 26 AĞUSTOS — GİRİŞ KAPISI EKRANLARI DIŞARI AÇILDI (yalnız test için)
//
// `Splash`, `Onboarding` ve `Auth` bugüne kadar bu dosyanın içinde
// kapalıydı; hiçbir mount testi onları RENDER EDEMİYORDU. Yani
// kullanıcının GÖRDÜĞÜ İLK ÜÇ EKRAN, tüm test kapsamının DIŞINDAydı.
//
// Ölçüm: `render_check/mount_test.js` 25 ekran mount ediyordu, hiçbiri
// oturum öncesi değildi. Kapsamı en dar olan yer, ilk izlenimin
// oluştuğu yerdi.
//
// 🆕 SINIF: "TEST KAPSAMI GENELLİKLE OTURUM AÇTIKTAN SONRA BAŞLAR —
// OYSA KULLANICI ORADAN BAŞLAMAZ."
// ============================================================
export { Splash, Onboarding, Auth, SocialAuthButtons, LangBtn, OfflineBanner };
