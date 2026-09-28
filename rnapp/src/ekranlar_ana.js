// ============================================================================
// ekranlar_ana.js — screens.js'ten ayrilan KATMAN 0 (26 Agustos 2026)
//
// 🔴 BU DOSYA BIR OLCUM DUZELTMESININ SONUCU.
//
// D2 turunda `screens.js`in "dongusel bir cekirdek" oldugunu olctum ve buna
// dayanarak "bolmek ise yaramaz, once bagliligi cozmek gerek" dedim. Bu tur
// sasirtici bir bag gordum — `TimeInput -> AddVisit` — ve baktim: bag bir
// YORUM SATIRINDAN geliyordu. Tarayici duzyaziyi kod sayiyordu.
//
// Yorumlar ve dizeler ayiklaninca gercek yapi cikti:
//     katman 0 : 20 bildirim · 5.166 satir · HICBIR yerel bagimliligi yok
//     katman 1 :  8 bildirim · 3.337 satir · yalniz katman 0'a bagli
//     dongusel cekirdek: 0
//
// Yani ortada MIMARI bir sorun hic yoktu; duz bir tasima isi vardi ve bir tur
// boyunca yanlis teshisle yasadik.
//
// 🆕 SINIF: "KAYNAK KODU DUZ METIN OLARAK TARAYAN BIR OLCUM, O DOSYADAKI
// YORUMLARI DA OLCER — VE IYI YORUMLANMIS BIR DOSYA EN KOTU SONUCU VERIR."
//
// Disa aktarim ADRESI DEGISMEDI: `screens.js` bu dosyayi `export *` ile
// yeniden yayinliyor, cagri yerlerinin hicbiri degismedi.
// ============================================================================
import FlightField from "./FlightField";
import { HostPanel, useReciprocityMoment } from "./HostWallet";
import MomentScreen from "./MomentScreen";
import { TerminalRadari, OnayDamgasi } from "./hareket";
import { CarrierPicker, Katlanir } from "./Pickers";
import { badgeLabel, fmtLongDate, mapErr, shortName, sinirMetni, BUYUK, gorunur } from "./i18n";
import { LEGAL_DOCS, LEGAL_ORDER } from "./legal";
import { bayrak } from "./runtime";
import { logError, supabase } from "./supabase";
import { havalimanlariniGetir, carrierlariGetir } from "./katalog";
import { ARA, ELEV, C, F, FS, R, SATIR, SP, T, TAP } from "./theme";
// 🔴 30 Ağu · Gece sistemi — DEĞİŞEN/KARŞILAŞTIRILAN SAYILAR MONO AİLEDE.
// Uyum yüzdesi, geri sayım, kredi. Gerekçe src/typography.js `MONO`.
import { MONO } from "./typography";
import { BosDurum, ChipIcon, ConfirmModal, Hdr, LoadFail, TOPPAD, Toggle, ToneBadge, Sayfa, Btn, Secim, Cip, KararCipi, Olgu, useDaralanBant, Kaydirma, Muhur, IsikliKart, PerdeBulanik, POPUP_YUZEY } from "./ui";
import React, { useCallback, useEffect, useRef, useState, useMemo} from "react";
import { ActivityIndicator, BackHandler, Image, Linking, Modal, ScrollView, Share, Text, TextInput, TouchableOpacity, View } from "react-native";
import { Amenities, BaglantiIstekleri, Chat, DateInput, HaberVer, LiveStatus, Picker, Plans, ProfileCompletionWidget, ReportUser, RequestsPanel, VerifyPhone, profOpts, timeOk } from "./ekranlar_yalin";
import { ACCESS_SOURCES, erisimKaynaklari, erisimEtiketi, AirportPicker, CarrierChip, FieldReportPrompt, LANG_OPTS, LegalDoc, Load, PURPOSES, Pill, PromiseBox, RefCodeEntry, ReqStateBadge, S, SECTOR_OPTS, Sayac, TrustRing, VenuePrices, _DTP, abbrevName, dateOk, geriSayim, getProfileCompletion, greeting, intentLabel, pickAndUploadPhoto } from "./ortak";
import { Ikon, IkonMetin, BilgiRozeti } from "./ikon";
import { yerelGun } from "./zaman";

export { C, F, ACCENT } from "./theme";


// ============================================================================
// 🔴 v2.97 — BU DOSYA ARTIK YALNIZ DONGUSEL CEKIRDEK (elestiri D2)
// Katmanlanabilen 63 bildirim `ortak.js` ve `ekranlar_yalin.js`e tasindi.
// Burada kalan 28 bildirim BIRBIRINE bagli: hangisini alsam otekini de
// almam gerekiyor. Bolmek icin once BAGLILIGI cozmek lazim — bu bir dosya
// tasima isi degil, mimari is (teslim notunda anlatildi).
//
// Disa aktarim ADRESI DEGISMEDI: App.js ve testler hala "./screens"ten
// import ediyor. Bir yeniden yapilandirmanin cagri yerlerini degistirmesi
// gerekmez; degistirirse yeniden yapilandirma degil, yeniden yazma olur.
// ============================================================================
export * from "./ortak";
export * from "./ekranlar_yalin";

// ════════════════════════════════════════════════════════════════
// SoguBaslangic — BOŞ PAZARI DAVETE ÇEVİREN BLOK
//
// Tek bir RPC (`sogu_baslangic_ozeti`) ve tek bir cümle. Sunucu
// TAHMİNİ ARZ DÖNDÜRMÜYOR (SQL 279'un nöbetçisi bunu kilitliyor);
// yalnız ölçülmüş üç sayı: salon, program, kullanıcının kendi kartı.
//
// Veri gelmezse ya da sayılar sıfırsa bileşen HİÇBİR ŞEY çizmez —
// "0 salonun 0 programı" cümlesi kurmaktansa susmak doğrudur.
//
// 🆕 SINIF: "BOŞ BİR EKRANI DOLDURMANIN İKİ YOLU VARDIR: UYDURMAK VE
// ZATEN BİLDİĞİN DOĞRUYU SÖYLEMEK — İKİNCİSİ HER ZAMAN VARDIR."
function SoguBaslangic({ t, airport, onHostOl }) {
  const [ozet, setOzet] = useState(null);
  useEffect(() => {
    let canli = true;
    (async () => {
      const { data, error } = await supabase.rpc("sogu_baslangic_ozeti",
                                                 { p_airport: airport || "" });
      if (error) { logError("sogu_baslangic", error); return; }
      if (canli) setOzet(data || null);
    })();
    return () => { canli = false; };
  }, [airport]);

  if (!ozet || !ozet.salon || !ozet.program) return null;
  return (
    <View style={{ alignSelf: "stretch", marginTop: SP[3], padding: ARA[18],
                   borderWidth: 1, borderColor: C.goldTrace || C.goldLine,
                   borderRadius: R.lg, backgroundColor: C.camIz || C.bgAlt }}>
      <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "600",
                     lineHeight: 22 }}>{t.sbBaslik}</Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[6],
                     lineHeight: 20 }}>
        {String(t.sbGercek || "")
          .replace("{salon}", String(ozet.salon))
          .replace("{program}", String(ozet.program))}
        {ozet.kartin_uygun ? " " + t.sbSenin : ""}
      </Text>
      {/* 🔴 BLOĞUN ASIL İŞİ BU DÜĞME. Yukarısı bir gerçek; burası bir
          DAVET. Etiket kullanıcının kendi durumuna göre değişiyor:
          kartı uygunsa doğrudan "aç", değilse önce "kontrol et" —
          çünkü uygun olmayan birine "koltuğunu aç" demek, tutamayacağı
          bir söz verdirmektir. */}
      {onHostOl ? (
        <Btn v={ozet.kartin_uygun ? "gold" : "ghost"} sm
          label={ozet.kartin_uygun ? t.sbCta : t.sbCtaAlt}
          onPress={onHostOl}
          style={{ marginTop: ARA[14], alignSelf: "stretch" }} />
      ) : null}
    </View>
  );
}

export function Discovery({ t, session, scope, onOpenProfile, onBack, onMeet, onAddTrip, onVerify, lang }) {
  const bnt = useDaralanBant();                            // 12 Eyl · daralan bant
  const [filtersOpen, setFiltersOpen] = useState(false);   // MVP: Filtre butonu
  // 🔴 KANCA SIRASI: bu blok ÖNCE `askHost`un yanına, yani
  // `if (rows === null) return <Load/>` SATIRINDAN SONRAYA yazmıştım.
  // App'in kendi nöbetçisi yakaladı: "erken return SONRASINDA hook
  // cagriliyor -> BEYAZ EKRAN riski". React'in kanca kuralı: kancalar
  // her render'da AYNI SIRADA ve KOŞULSUZ çağrılmalı.
  //
  // 🆕 SINIF: "BİR KANCAYI KOŞULLU HÂLE GETİREN ŞEY `if` DEĞİL, ONDAN
  // ÖNCEKİ `return`DÜR."
  // 🔴 v2.94 — "YAZDIM AMA ÇAĞIRMADIM" DÜZELTMESİ.
  // `acik_istek_tavanim`, `kural_sorusu_hakkim` ve `ucus_kotam` sunucuda
  // vardı ve kullanıcı hiçbirini görmüyordu. Bir sınırı uygulayıp
  // göstermemek, kullanıcıya "bozuk" hissi verir.
  const [kotalar, setKotalar] = useState(null);
  useEffect(() => {
    let iptal = false;
    (async () => {
      const [a, b, c] = await Promise.all([
        supabase.rpc("acik_istek_tavanim"),
        supabase.rpc("kural_sorusu_hakkim"),
        supabase.rpc("ucus_kotam"),
      ]);
      // Hata YUTULMUYOR ama ekranı da kilitlemiyor: kota satırı
      // gösterilemezse yokmuş gibi davranır, log'a düşer.
      if (a.error) logError("kota_istek", a.error);
      if (b.error) logError("kota_soru", b.error);
      if (c.error) logError("kota_ucus", c.error);
      if (!iptal) setKotalar({ istek: a.data || null, soru: b.data || null, ucus: c.data || null });
    })();
    return () => { iptal = true; };
  }, []);

  const [myRole, setMyRole] = useState(null);
  const [phoneOk, setPhoneOk] = useState(false);
  const [idOk, setIdOk] = useState(false);       // MVP: "Tam Doğrulanmış" rozeti
  const [myTrust, setMyTrust] = useState(0);     // MVP: "Yüksek Güvenli Misafir" rozeti
  // 🔴 PROP-DROP (bu ailenin 5. ornegi): App.js `scope` gonderiyordu ama
  // Discovery imzasinda YOKTU → seyahat kartindan "Host Bul"a basinca o
  // seyahatin havalimani/tarihi HIC uygulanmiyordu. Artik on-dolduruluyor.
  const [dateF, setDateF] = useState(scope?.date || null);
  const uid = session?.user?.id;
  const [rows, setRows] = useState(null);
  const [hosts, setHosts] = useState({});
  const [kartAdi, setKartAdi] = useState({});   // avail_id → program adı (tasarım 02, isim altı)
  const [myReqs, setMyReqs] = useState({});
  const [apFilter, setApFilter] = useState(scope?.airport ? { key: scope.airport, label: scope.airport } : null);
  const [airports, setAirports] = useState([]);
  const [flight, setFlight] = useState("");
  const [sector, setSector] = useState("");
  const [sortBy, setSortBy] = useState("match");     // MVP: Eşleşme/Güven/Saat
  const [womenOnly, setWomenOnly] = useState(false); // MVP: yalnızca kadın host
  const [langF, setLangF] = useState(null);          // MVP: Dil chip filtresi (host_langs kesişimi)

  // ════════════════════════════════════════════════════════════════════
  // 🔴 22 EYLÜL — ÜÇ AYRI FİLTRE LİSTESİ, ÜÇÜ DE FARKLI (Gökberk cihazda
  // gördü: "tüm havalimanlarını gör"e basınca sadece düğme kalkıyor).
  // Ölçtüm, aynı ekranda üç yerde üç farklı liste vardı:
  //   · "filtreli mi" mesajı   : apFilter · dateF · sector · flight · langF · womenOnly   (6)
  //   · temizle düğmesi görünür: apFilter · dateF · sector · flight                        (4)
  //   · temizle düğmesi siler  : apFilter · dateF · sector · flight                        (4)
  // Yani `langF` ya da `womenOnly` açıkken: mesaj "filtreler daraldı" der,
  // düğme HİÇ ÇIKMAZ; dördü açıkken düğme çıkar, basınca dördü silinir ama
  // diğer ikisi kalır — liste dolmaz, düğme kaybolur. Tam olarak onun
  // gördüğü davranış.
  //
  // 🆕 SINIF: "AYNI SORUYU ÜÇ YERDE AYRI AYRI CEVAPLARSAN, ÜÇÜ DE AYNI
  // ANDA DOĞRU OLMAZ — SORUYU BİR KEZ SOR, ÜÇÜ DE ONA BAKSIN."
  // ════════════════════════════════════════════════════════════════════
  const FILTRELER = [apFilter, dateF, sector, flight, langF, womenOnly];
  const filtreVar = FILTRELER.some(Boolean);
  const filtreleriTemizle = React.useCallback(() => {
    setApFilter(null); setDateF(""); setSector(""); setFlight("");
    setLangF(null); setWomenOnly(false);
  }, []);
  // v1.71: scope.sortTrip = FİLTRE DEĞİL sıralama ipucu. FindHostCard artık
  // seyahatin havalimanı/tarihine sert filtre uygulamıyor (liste boş kalıyordu);
  // tüm açık slotlar gelir, seyahate uyum sırasına dizilir.
  // 🔴 3 EYLÜL — SIRADAKİ SEYAHAT OTOMATİK. Keşfet sekmesi `scope={null}`
  // ile açılıyordu; kullanıcının BUGÜN bir seyahati olsa bile başlık
  // "TÜM HAVALİMANLARI VE TARİHLER / Keşfet" diyordu. Tasarım (02):
  // "İSTANBUL · IST / İstanbul / Kalkışına 3 sa 12 dk · 6 host yayında".
  // Kapsam verilmediyse sıradaki seyahat okunur ve sıralama ipucu olur
  // (filtre DEĞİL — liste yine tam, önce uyanlar).
  const [otoTrip, setOtoTrip] = useState(null);
  useEffect(() => {
    if (scope?.sortTrip || !session?.user?.id) return;
    let canli = true;
    (async () => {
      const today = yerelGun();
      const { data, error } = await supabase.from("visits")
        .select("airport_code, visit_date, time_from")
        .eq("user_id", session.user.id).gte("visit_date", today)
        .order("visit_date").limit(1);
      if (error) { logError("disc_oto_seyahat", error); return; }
      const v = data && data[0];
      if (canli && v) setOtoTrip({ airport: v.airport_code, date: v.visit_date, timeFrom: String(v.time_from || "").slice(0, 5) });
    })();
    return () => { canli = false; };
  }, [scope?.sortTrip, session?.user?.id]);
  const sortTrip = scope?.sortTrip || otoTrip;
  const [target, setTarget] = useState(null); // istek modalı
  const [intro, setIntro] = useState("");
  const [reqType, setReqType] = useState("lounge"); // MVP: istek türü
  // v1.86 — kural motoru kapısı: istek göndermeden ÖNCE sunucudan karar al
  const [pre, setPre] = useState(null);
  // v2.69: uçuş saati / terminal / giriş penceresi uyarıları (SQL 199)
  const [fit, setFit] = useState(null);     // request_precheck çıktısı
  // v2.98 (G7 · SQL 252 §4b): ilanın sahibine anlık ulaşılabiliyor mu.
  // Ulaşılamıyorsa istek KREDİ HARCAMAZ ve misafir bunu göndermeden ÖNCE
  // öğrenir. Ayrı RPC: düşerse karar ekranı aynen çalışır.
  const [ulasNot, setUlasNot] = useState(null);
  const [ackOk, setAckOk] = useState(false);
  const [badges, setBadges] = useState({}); // avail_id -> rozet
  const [sameFlight, setSameFlight] = useState(0);
  const [loadErr, setLoadErr] = useState("");
  // v2.02 — rozete dokununca açıklama. "Lounge kuralı doğrulanmadı"
  // gibi bir rozet açıklamasız kaldığında kullanıcı ilanın geçersiz
  // olduğunu sanıyor ve geri çekiliyor.
  const [badgeInfo, setBadgeInfo] = useState(null);
  // 🔴 v2.79 (A7) — "HOST'A SOR" DURUMU.
  // Sonuç ilan bazında tutuluyor: kullanıcı başka bir karta bakıp geri
  // dönünce "gönderildi" bilgisi kaybolmasın. Tek bir global bayrak
  // olsaydı, iki farklı ilana sorduğunda ikincisinin cevabı birincisinin
  // üstüne yazardı.
  const [askState, setAskState] = useState({});
  const [askBusy, setAskBusy] = useState(false);
  const [hiddenCount, setHiddenCount] = useState(0);
  // 23 Eylül — gönderimden sonra "şimdi ne olacak?" cevabı (bkz. send()).
  const [gonderildi, setGonderildi] = useState(null);
  // Bilgi şeridi 12 sn sonra kendiliğinden kalkar (dokunulacak bir şey değil).
  useEffect(() => {
    if (!gonderildi) return;
    const z = setTimeout(() => setGonderildi(null), 12000);
    return () => clearTimeout(z);
  }, [gonderildi]);
  const [moreOpen, setMoreOpen] = useState(false);
  // 🔴 v2.89 (Gökberk md.4) — KURAL KUTUSU KATLANIYOR.
  // Kutu kaynak etiketi + rozet + başlık + gerekçe + pencere uyarısı +
  // "başka ilan yok" + "hangi kart işine yarar" + "detayları göster"
  // taşıyordu; ekranın yarısını kaplıyor ve "İsteği gönder" düğmesini
  // kaydırmanın altına itiyordu (ekran görüntüsünde düğme gri ve en altta).
  // KARAR (rozet + başlık) HER ZAMAN görünür kalır — kutunun varlık sebebi
  // o. Katlanan yalnız gerekçe.
  // ⚠️ Varsayılan severity'ye bağlı: reddedilen kullanıcı SEBEBİ görmeden
  // kapatılmamalı, o yüzden `block` açık başlar.
  const [kuralAcik, setKuralAcik] = useState(false);
  const [alts, setAlts] = useState(null);
  const [amenities, setAmenities] = useState({});
  const [advice, setAdvice] = useState(null);
  // Kural kararı ekranı — tam ekran katman (tasarımın 03 ekranı).
  const [kural, setKural] = useState(null);
  // 🔴 v2.87 — HAVAYOLU GÖRÜNÜRLÜĞÜ (Gökberk madde 5).
  // "keşfet ve diğer sayfalarda ilana ait havayolu firmasının daha belirgin
  // ve açık belirtilmesi lazım. Biliyosun kurallardan birinde THY'li
  // AJet'liyi alamıyor."
  //
  // ⚠ ÖLÇTÜM VE VARSAYIM YANLIŞ ÇIKTI: taşıyıcı keşif yükünde YOK.
  // `discover_availabilities`in RETURNS TABLE listesi (ETKIN_TANIMLAR.sql)
  // `carrier_note` döndürüyor — yani kural motorunun NOTUNU — ama ilanın
  // taşıyıcı KODUNU döndürmüyor (fonksiyon içeride `av_carrier` diye
  // hesaplıyor ve dışarı vermiyor). `r.carrier` yazsaydım sessizce
  // `undefined` okuyup çip hiç çizilmezdi; "yaptım" derdim, ekranda
  // hiçbir şey olmazdı.
  // SQL'e DOKUNMUYORUM (kural). Bunun yerine listenin `id`leriyle
  // `availabilities` tablosundan taşıyıcıyı çekiyorum — tabloda RLS kapalı
  // ve `authenticated` SELECT hakkı var (159_grants...sql:38). Aynı desen
  // zaten kullanılıyor: rozetler ve olanaklar da liste geldikten SONRA
  // ikinci bir çağrıyla zenginleştiriliyor.
  const [availCarrier, setAvailCarrier] = useState({});   // avail_id -> kod
  const [kurucu, setKurucu] = useState({});               // host_id -> kurucu no (v6.1 md.35)
  // Kod tek başına ("TK") herkese bir şey söylemez; `carrier_options`
  // kod→ad eşlemesini veren mevcut RPC. Gelmezse çip kodu gösterir.
  const [carrierMap, setCarrierMap] = useState({});
  // Modali YALNIZ BIR KEZ ac: load() her filtre degisiminde calisiyor,
  // ref olmasa kullanici modali kapatinca hemen yeniden acilirdi.
  const targetOpenedRef = useRef(false);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    // NOT: kendi ilanin listede gorunmemeli — kendi ilanina istek atamazsin
    // (create_request 'self_request_blocked' firlatir). Sunucu tarafi bunu
    // filtrelemiyor, burada eliyoruz.
    // 🔴 26 AĞUSTOS — `error` OKUNMUYORDU VE BU, BU ÜRÜNDEKİ EN PAHALI
    // YANLIŞ CÜMLEYİ ÜRETİYORDU: ağ bir an koptuğunda keşif ekranı
    // "Bu havalimanında host yok" yazıyordu. Kapıda, 40 dakikası olan
    // misafir onu okuyup uygulamayı kapatıyor.
    //
    // `Trips` bu tuzağı yorumunda zaten tarif etmiş: "Boş durum DAVET eder,
    // hata durumu YENİDEN DENEMEYE çağırır — ikisi aynı ekran olamaz."
    // Doğru ders yazılmış, YAYILMAMIŞTI.
    // 🆕 SINIF: "BİR DERSİN YAZILMIŞ OLMASI, UYGULANMIŞ OLMASI DEĞİLDİR —
    // DERSLER SINIFA DEĞİL ÖRNEĞE UYGULANIR VE ORADA KALIR."
    const [{ data, error: eDisc }, { data: reqs }, { data: allData }] = await Promise.all([
      supabase.rpc("discover_availabilities", { p_airport: apFilter ? apFilter.key : null, p_sector: sector || null, p_flight: flight || null, p_date: dateF || null }),
      // 🔴 v2.23 — "GERISI NEREDE?" SORUSUNU CEVAPLA.
      // Ana sayfadan IST baglamiyla girilince filtre IST'e ayarlaniyor ve
      // diger havalimanlarindaki ilanlar SESSIZCE gizleniyor. Kullanici
      // "ilanlarin cogu yok" diye okur — filtrenin calistigini degil,
      // urunun bos oldugunu dusunur. Filtresiz sayiyi da cekip farki
      // soyluyoruz.

      // 🔴 v2.87 — REDDEDİLEN/İPTAL BAŞVURULAR DA OKUNUYOR.
      // Eskiden yalnız pending+accepted çekiliyordu; reddedilmiş bir
      // başvuru istemcide "hiç başvurmamış" ile AYNI görünüyordu. Kart
      // "reddedildin" diyemiyordu çünkü veri hiç gelmiyordu.
      // (request_status: pending, accepted, declined, cancelled, expired,
      //  completed — VERITABANI_SEMASI.md satır 22.)
      supabase.from("requests").select("avail_id, status, created_at").eq("guest_id", uid)
        .in("status", ["pending", "accepted", "declined", "cancelled"])
        .order("created_at", { ascending: true }),
      // 🔴 v2.23 — "GERISI NEREDE?" SORUSUNU CEVAPLA. Filtre bir sey
      // gizliyorsa KAC TANE gizledigini soyle; yoksa kullanici urunun bos
      // oldugunu sanir. Sirasi dizinin SONUNDA — Promise.all'da isim yok,
      // yalniz sira var (BO'da bu hatayi bir kez yapmistim).
      supabase.rpc("discover_availabilities", { p_airport: null, p_sector: null, p_flight: null, p_date: null }),
    ]);
    if (eDisc) {
      logError("discover_availabilities", eDisc);
      setLoadErr(mapErr(t, eDisc.message));
      setRows([]);
      return;
    }
    setLoadErr("");
    // kendi ilanini listede gosterme (kendine istek atilamaz)
    let list = (data || []).filter(r => r.host_id !== uid);
    // MVP filtreleri: tarih · yalnizca kadin host · siralama
    if (dateF) list = list.filter(r => r.avail_date === dateF);
    if (womenOnly) list = list.filter(r => r.host_gender === "female");
    if (langF) list = list.filter(r => (r.host_langs || []).includes(langF));
    // v1.86 — KURAL ROZETLERİ. discover_availabilities'in İMZASINA
    // DOKUNMADIK (eski sürümler bozulmasın); liste geldikten sonra ayrı bir
    // RPC ile rozetleri alıp burada birleştiriyoruz.
    // 🔴 v3.4 — ÜÇ EK SORGU DA SIRAYLA GİDİYORDU VE ÜÇÜ DE AYNI `ids`
    // DİZİSİNİ KULLANIYORDU: rozetler · olanaklar · taşıyıcılar.
    // Aynı girdiyle çalışan sorgular tanım gereği birbirini beklemez.
    // Üstündeki yorum "iki ayrı istek yerine tek ek çağrı" diyordu ama
    // gerçekte İKİNCİ bir sıralı çağrıydı — yorum, koddan geride kalmıştı.
    //
    // 🆕 SINIF: "AYNI GİRDİYİ KULLANAN SORGULAR SIRAYLA GİDİYORSA, ORADA
    // BİR BAĞIMLILIK DEĞİL BİR ALIŞKANLIK VARDIR."
    let bmap = {};
    const ids = list.map(r => r.id).filter(Boolean).slice(0, 60);
    if (ids.length) {
      const hostIds = [...new Set(list.map(r => r.host_id).filter(Boolean))].slice(0, 60);
      const [rz, ol, tsy, kr] = await Promise.all([
        supabase.rpc("discovery_rule_badges", { p_ids: ids }),
        supabase.rpc("amenities_for", { p_ids: ids }),
        supabase.from("availabilities").select("id, carrier").in("id", ids),
        // v6.1 (Gökberk md.35) — "Kurucu Host rozeti ilanlarında görünür"
        // vaadi ilk kez tutuluyor. Düşerse rozet yok; liste etkilenmez.
        hostIds.length
          ? supabase.from("profiles").select("user_id, founding_host_no").in("user_id", hostIds)
              .not("founding_host_no", "is", null).then(r => r).catch(() => ({ data: [] }))
          : Promise.resolve({ data: [] }),
      ]);
      const km = {};
      for (const k of ((kr && kr.data) || [])) if (k && k.founding_host_no) km[k.user_id] = k.founding_host_no;
      setKurucu(km);
      for (const b of (rz.data || [])) bmap[b.avail_id] = b;
      const amap = {};
      for (const a of (ol.data || [])) amap[a.avail_id] = a.amenities;
      setAmenities(amap);
      // Taşıyıcı: hata varsa BOŞ harita — yanlış havayolu göstermektense
      // hiç göstermemek doğru bozulma yönü (v2.87'deki karar korunuyor).
      if (tsy.error) setAvailCarrier({});
      else {
        const cmap = {};
        for (const a of (tsy.data || [])) if (a && a.carrier) cmap[a.id] = a.carrier;
        setAvailCarrier(cmap);
      }
    } else {
      setAmenities({});
      setAvailCarrier({});
    }

    // 🔵 v2.87'nin taşıyıcı sorgusu YUKARIDAKİ `Promise.all`a taşındı —
    // aynı `ids` ile çalışıyordu, ayrı bir tur atmasının sebebi yoktu.
    // Karar (hata → boş harita) aynen korundu.

    // 🔴 ROZETLER CİHAZDA HİÇ GÖRÜNMÜYORDU (Gökberk madde 6).
    // Rozetler ayrı bir RPC'den (discovery_rule_badges) geliyordu ve o
    // çağrı başarısız olursa hata YUTULUYOR, liste rozetsiz çiziliyordu.
    // Sessiz yutma bu projenin en pahalı hata sınıfı: kullanıcı eksik
    // bilgiyle karar veriyor ve kimse fark etmiyor.
    //
    // SQL 182 ile karar alanları artık listenin KENDİSİNDE geliyor
    // (guest_policy, blocks_request, block_reason, carrier_note).
    // Ek RPC bir HIZLANDIRMA olmalı, tek kaynak değil. Eksik kalan her
    // ilan için liste verisinden rozet üretiyoruz.
    for (const r of list) {
      if (bmap[r.id] || !r.guest_policy) continue;
      const pol = r.guest_policy;
      bmap[r.id] = {
        avail_id: r.id,
        label:
          pol === "included" ? t.badgeGuestFree
          : pol === "paid" ? t.badgeGuestPaid
          : pol === "not_allowed" ? t.badgeGuestNo
          : t.badgeGuestUnknown,
        tone: pol === "included" ? "ok" : pol === "paid" ? "cost"
              : pol === "not_allowed" ? "block" : "unknown",
        info: r.decision_note || null,
        blocks_request: !!r.blocks_request,
        block_reason: r.block_reason || null,
        carrier_note: r.carrier_note || null,
        // 🔴 v2.79 — YEDEK YOLDA `false`. `can_ask_host` yalnız rozet
        // RPC'sinden gelir (SQL 221). Rozet RPC'si düşmüşse "host'a sor"
        // butonunu GÖSTERMİYORUZ: sunucu o ilanda soruyu kabul etmeyecekse
        // butona basan kullanıcı ham hata görür. Yanlış buton
        // göstermektense butonu hiç göstermemek doğru bozulma yönü.
        can_ask_host: false,
      };
    }
    // Kapı durumu HER ZAMAN liste verisinden gelir: ek RPC eski bir
    // cevabı önbelleklemiş olsa bile kapasite/kural güncel kalır.
    for (const r of list) {
      if (!bmap[r.id]) continue;
      if (r.blocks_request) bmap[r.id].blocks_request = true;
      // 🔴 v2.66 (madde 9): guest_policy = 'not_allowed' TEK BAŞINA kapıdır.
      // blocks_request eski satırlarda boş kalabiliyor; o zaman rozet
      // "misafir alınmıyor" derken buton açık kalıyordu. Rozet hayır
      // derken butonun evet demesi, kullanıcıyı sunucu hatasına sürer.
      if (r.guest_policy === "not_allowed") bmap[r.id].blocks_request = true;
      if (r.block_reason && !bmap[r.id].block_reason) bmap[r.id].block_reason = r.block_reason;
      if (r.carrier_note) bmap[r.id].carrier_note = r.carrier_note;
      // 🔴 v2.66 (madde 6): ücretsiz misafir hakkı KAÇ KİŞİ? 187 bu sayıyı
      // guest_included_count olarak veriyor (eski adı guest_allowance).
      // Sunucudan gelen rozete de eklenir: sayı bilgidir, yargı değil.
      const gn = Number(r.guest_included_count ?? r.guest_allowance ?? 0);
      if (r.guest_policy === "included" && gn > 0 && !/\d/.test(String(bmap[r.id].label || ""))) {
        bmap[r.id].label = `${bmap[r.id].label} · ${String(t.badgeGuestCount).replace("{n}", String(gn))}`;
      }
    }
    setBadges(bmap);
    const allCount = (allData || []).filter(r => r.host_id !== uid).length;
    setHiddenCount(Math.max(0, allCount - list.length));

    // 🔴 v2.25 — "LOUNGE ISTEGI GONDER" ARTIK DOGRUDAN ISTEK EKRANINA GIDIYOR.
    // Tanis ekranindan bu butona basan kullanici KESFE atiliyordu ve ilani
    // ORADA TEKRAR BULMASI gerekiyordu. Kullanici zaten KIMI istedigini
    // secmisti; ona "simdi git onu bul" demek, yaptigi secimi yok saymaktir.
    // Hedef ilan listede varsa modali kendimiz aciyoruz.
    if (scope?.focusAvail && !targetOpenedRef.current) {
      const hit = list.find(r => r.id === scope.focusAvail);
      // 🔴 v6.1 (Gökberk md.34) — KAPALI KAPININ İSTEK EKRANI AÇILMIYOR.
      // Seyahat eklendikten sonra ilan "farklı havayolu" yüzünden kapanmış
      // olabilir; o zaman istek formu değil, SEBEP açılır.
      const bh = hit && bmap[hit.id];
      const kapali = hit && ((bh && bh.blocks_request) || hit.guest_policy === "not_allowed" || hit.blocks_request);
      if (hit && kapali) {
        targetOpenedRef.current = true;
        if (bh && bh.info) setBadgeInfo({ id: hit.id, label: bh.label, info: bh.info, canAsk: !!bh.can_ask_host });
      } else if (hit) { targetOpenedRef.current = true; setTarget(hit); setErr(""); setMoreOpen(false); }
    }

    // 💡 Anlatı: aynı uçuştaki eşleşme sayısı listenin başında tek satırla
    // söylenir. Bu bir özellik duyurusu değil, ürünün SEBEBİNİ hatırlatan
    // cümle — "bekleme süresi" değil "tanışma zamanı" çerçevesi.
    setSameFlight(Object.values(bmap).filter(b => b.same_flight_match).length);

    const boost = r => (bmap[r.id] ? (bmap[r.id].sort_boost || 0) : 0);
    // 🔴 v2.23 — UC KADEMELI SIRALAMA.
    // Kullanicinin ILK gordugu sey YAPABILECEGI sey olmali. Yapamayacagi
    // bir ilani basa koymak, once umut verip sonra geri almaktir.
    //   1. Basvurabilecegin ilanlar (seyahatin var + kural engeli yok)
    //   2. Seyahatinin disindakiler (seyahat eklerse basvurabilir)
    //   3. Kural engelli olanlar — en altta
    // Her kademe KENDI ICINDE eslesme puanina gore siralanir.
    const tier = r => {
      const bg = bmap[r.id];
      if (bg && bg.blocks_request) return 2;      // en alt
      return r.has_trip ? 0 : 1;
    };
    // v2.50: sıralama TEK GEÇİŞE indirildi (aşağıda). İki ayrı geçiş,
    // ikincisinin birincisini ezmesi sınıfını doğuruyordu.
    // 🔴 v1.76: TEK BİRLEŞİK SIRALAMA. Önceki sürümde önce "dolular alta",
    // sonra "seyahat uyumu" diye İKİ AYRI sıralama vardı; ikincisi birincinin
    // sonucunu bozup dolu bir ilanı tekrar en üste taşıyabiliyordu.
    // Öncelik sırası: (1) AÇIK ilanlar her zaman önce (2) seyahatine uyum
    // (aynı havalimanı+tarih > aynı havalimanı > diğer) (3) mevcut sıralama
    // (eşleşme/güven/saat — kullanıcının seçtiği).
    {
      // 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: 58 puanlı, başvurulamayan ilan
      // "EN İYİ EŞLEŞME" olarak 83 puanlı, başvurulabilir ilanın ÜSTÜNDE
      // duruyordu. Sebep: yukarıdaki kademeli sıralamadan SONRA çalışan
      // İKİNCİ bir sıralama vardı ve "seyahatinle aynı havalimanı" ölçütü
      // KADEMEYİ EZİYORDU. v1.76'da tam bu hata bir kez düzeltilmiş,
      // ikinci geçiş sonradan geri gelmiş.
      //
      // Doğrusu: uyum kademenin YERİNE değil, kademenin İÇİNDE bir
      // ölçüttür. Tek geçişte, öncelik sırasıyla:
      //   1. Dolu ilanlar en altta
      //   2. Kademe: başvurabilirsin > seyahatin dışında > kural engelli
      //   3. Aynı uçuş rozeti
      //   4. Seyahatine uyum (aynı havalimanı+tarih > aynı havalimanı)
      //   5. Eşleşme puanı / kullanıcının seçtiği sıralama
      const fit = r => (sortTrip && r.airport_code === sortTrip.airport)
        ? (String(r.avail_date).slice(0,10) === String(sortTrip.date).slice(0,10) ? 2 : 1) : 0;
      const bittiMi = r => (geriSayim(r.avail_date, r.time_from, r.time_to, t) || {}).tur === "bitti";
      list = [...list].sort((a, b) =>
        ((bittiMi(a) ? 1 : 0) - (bittiMi(b) ? 1 : 0))          // 23 Eylül: saati geçen en alta
        || ((a.fully_booked ? 1 : 0) - (b.fully_booked ? 1 : 0))
        || (tier(a) - tier(b))
        || (boost(b) - boost(a))
        || (fit(b) - fit(a))
        || (sortBy === "trust" ? (b.host_score || 0) - (a.host_score || 0)
          : sortBy === "time" ? String(a.avail_date + a.time_from).localeCompare(String(b.avail_date + b.time_from))
          : (b.match_score || 0) - (a.match_score || 0))
      );
    }
    setRows(list);
    // v2.96 (F1): keşfi GERÇEKTEN gören kullanıcı — huninin ikinci basamağı.
    supabase.rpc("huni_yaz", { p_olay: "kesif_goruldu",
      p_airport: (scope && scope.airport) || null })
      .then(({ error }) => { if (error) logError("huni_yaz", error); });
    const rm = {}; (reqs || []).forEach(r => { rm[r.avail_id] = r.status; });
    setMyReqs(rm);
    const m = {};
    list.forEach(r => { m[r.host_id] = { name: r.host_name, badge: r.host_badge, score: r.host_score, prof: r.host_profession, photo: r.host_photo }; });
    setHosts(m);
    // 🔴 3 EYLÜL — TASARIM 02: ismin altındaki satır MESLEK değil KART
    // ("Elite Plus · Star Alliance Gold"). Kapıyı açan şey kart; meslek
    // profilde. `kural_kart_adi` ilanın programını döndürür (SQL 240).
    // Program bilinmiyorsa ('Kart') mesleğe düşülür — boş satır yerine.
    // 4 Eylül — tasarım "Elite Plus · Star Alliance Gold" yazıyor: KART TİPİ.
    // Program adı tek başına ("Miles&Smiles (THY & AJet statüsü)") kapıyı
    // anlatmıyor; kural kararı (`availability_rule_snapshot`) program + tier
    // kodunu verir, tier etiketi `card_tier_options`tan (programa göre, tek
    // sefer). Sonuç: "Miles&Smiles · Elite Plus" / "Priority Pass · Prestige".
    const ilk = list.slice(0, 30);
    const tierEtiket = {};   // program kodu → { tier → etiket }
    Promise.all(ilk.map(r => Promise.resolve(supabase.rpc("availability_rule_snapshot", { p_avail_id: r.id }))
      .then(({ data }) => [r.id, data], () => [r.id, null])))
      .then(async cift => {
        const programlar = [...new Set(cift.map(([, d]) => d && d.tier && d.program).filter(Boolean))];
        await Promise.all(programlar.map(kod => Promise.resolve(supabase.rpc("card_tier_options", { p_program_code: kod }))
          .then(({ data }) => { tierEtiket[kod] = {}; (data || []).forEach(x => { tierEtiket[kod][x.tier] = x.label; }); }, () => {})));
        const k = {};
        cift.forEach(([id, d]) => {
          if (!d || !d.program) return;
          const prog = String(d.program_name || d.program).replace(/\s*\(.*\)\s*$/, "").trim();
          const tl = d.tier && tierEtiket[d.program] && tierEtiket[d.program][d.tier];
          k[id] = tl ? `${prog} · ${tl}` : prog;
        });
        setKartAdi(k);
      });
  }, [apFilter, sector, flight, uid, sortTrip]);

  useEffect(() => {
    (async () => {
      const uid = session?.user?.id; if (!uid) return;
      // 🔴 v3.4 — ÜÇ BAĞIMSIZ TUR SIRAYLA ATILIYORDU (rol · doğrulama ·
      // güven puanı). Keşfet uygulamanın en çok açılan ekranı; buradaki
      // her fazladan tur, kullanıcının en sık ödediği bedel.
      const [{ data }, { data: v }, { data: ts }] = await Promise.all([
        supabase.from("users").select("role").eq("id", uid).maybeSingle(),
        supabase.from("verifications").select("phone_verified, id_verified").eq("user_id", uid).maybeSingle(),
        supabase.from("trust_scores").select("score").eq("user_id", uid).maybeSingle(),
      ]);
      setMyRole(data?.role || null);
      setPhoneOk(!!v?.phone_verified);
      setIdOk(!!v?.id_verified);
      setMyTrust(ts?.score ?? 0);
    })();
  }, [session]);
  useEffect(() => {
    load();
    // 🔴 v3.4 — ÖNBELLEKTEN (bkz. src/katalog.js). 222 satırlık bu liste
    // uygulamada BEŞ ayrı ekrandan, her açılışta yeniden çekiliyordu.
    havalimanlariniGetir()
      // 19 Eylül — `city` de taşınıyor: `AirportPicker` şehri ayrı satırda
      // gösteriyor ve arama şehir adında da eşleşiyor ("İstanbul" yazan
      // kullanıcı IST'i bulabilmeli).
      .then((data) => setAirports((data || []).map(a => ({ key: a.code, label: `${a.code} — ${a.city}`, city: a.city }))));
    // v2.87: havayolu kodu → ad. İKİNCİL bir sözlük: gelmezse chip kodu
    // gösterir, ekran çalışmaya devam eder. `error` yutulmuyor; boş harita
    // kuruluyor ki "yükleniyor" ile "yok" karışmasın.
    carrierlariGetir().then((data) => {
      const cm = {};
      (data || []).forEach(c => { if (c && c.code) cm[c.code] = c.name || c.code; });
      setCarrierMap(cm);
    });
  }, [load]);

  // Modal açıldığında kararı çek. Sunucu misafirin KENDİ uçuş numarasını
  // seyahatinden okur — istemciye güvenmeyiz.
  useEffect(() => {
    if (!target) { setPre(null); setAckOk(false); setUlasNot(null); return; }
    let alive = true;
    (async () => {
      try {
        // 🔴 v2.69 — AYRI ÇAĞRI, BİLEREK. trip_fit_note precheck'in İÇİNE
        // konsaydı precheck'in ALTI return dalının altısını da güncellemek
        // gerekirdi (192'nin "erken dönüş sözleşmenin yarısını düşürür"
        // dersi). Ayrı RPC → precheck'e sıfır regresyon riski. Düşerse
        // uyarılar görünmez, karar ekranı aynen çalışır.
        //
        // 🔴 v3.6 — AMA "AYRI ÇAĞRI" DEMEK "SIRAYLA ÇAĞRI" DEMEK DEĞİL.
        // Üçü de yalnız `target.id` istiyor; hiçbiri diğerinin cevabını
        // beklemiyordu. Yine de sırayla koşuyorlardı: 3 × ~345 ms ≈ 1 sn,
        // ve tam olarak misafirin KREDİ HARCAMAYA karar verdiği ekranda.
        //
        // 🆕 SINIF: "BİR SORGUYU AYRI TUTMANIN SEBEBİ REGRESYON RİSKİYSE,
        // O SEBEP ONU AYRI ÇAĞIRMAYI GEREKTİRİR — SIRAYLA ÇAĞIRMAYI DEĞİL."
        //
        // `allSettled`: biri düşerse diğerleri yine gelsin. Ek uyarılar
        // ikincil; karar ekranı onlarsız da doğru çalışır.
        const [pc, fitR, ulasR] = await Promise.allSettled([
          supabase.rpc("request_precheck", { p_avail_id: target.id }),
          supabase.rpc("trip_fit_note", { p_avail_id: target.id }),
          supabase.rpc("ilan_ulasilabilirlik_notu", { p_avail_id: target.id }),
        ]);
        let data = pc.status === "fulfilled" ? pc.value.data : null;
        // 🔴 23 Eylül · SQL 301 §6 — ön kontrol artık sunucunun kendi yolunu
        // kuru koşuyor; misafire özel bir kapı (havayolu, kişi sayısı, kendi
        // ilanı, kredi, açık istek tavanı…) takılırsa `gate` = sunucunun hata
        // kodu ve `headline` BOŞ gelir — metni burada TR/EN sözlükten çeviriyoruz.
        // Eskiden bu kapılar "İstek gönder"e basınca, sayfa kapanırken çıkıyordu.
        if (data && data.can_request === false && !data.headline && data.gate) {
          data = { ...data, headline: mapErr(t, data.gate) };
        }
        if (alive) { setPre(data || null); setAckOk(false); setAlts(null); }
        if (alive) {
          const fv = fitR.status === "fulfilled" ? fitR.value : null;
          setFit(fv && !fv.error ? (fv.data || null) : null);
          const uv = ulasR.status === "fulfilled" ? ulasR.value : null;
          setUlasNot(uv && !uv.error ? (uv.data || null) : null);
        }
        // 🔴 v2.25 — REDDEDILEN KULLANICIYA CIKIS YOLU.
        // "Basvuramazsin" tek basina bir CIKMAZ SOKAK. Kullanici ilk redde
        // "burada bana gore bir sey yok" der ve bir daha acmaz. Cogu engelin
        // bir cikisi var; alternatif sayisini GERCEKTEN hesaplayip
        // soyluyoruz — sifirsa sifir diyoruz, uydurmuyoruz.
        if (alive && data && data.can_request === false) {
          try {
            const { data: alt, error: hata1 } = await supabase.rpc("alternatives_for", { p_avail_id: target.id });
            if (hata1) logError("ekranlar_ana.js:488", hata1);
            if (alive) setAlts(alt || null);
          } catch (e) { /* alternatif alinamazsa asil mesaj yine gorunur */ }
        }
      } catch (e) { if (alive) setPre(null); }
    })();
    return () => { alive = false; };
  }, [target]);

  async function loadAdvice(loungeId) {
    if (advice) { setAdvice(null); return; }      // ikinci dokunusta kapat
    if (!loungeId) return;
    try {
      const { data, error: hata2 } = await supabase.rpc("card_advice_for_lounge", { p_lounge_id: loungeId });
      if (hata2) logError("ekranlar_ana.js:502", hata2);
      setAdvice(data && data.length ? data : []);
    } catch (e) { setAdvice([]); }
  }

  async function send() {
    if (pre && pre.can_request === false) { setErr(pre.headline || ""); return; }
    if (pre && pre.needs_ack && !ackOk) { setErr(t.ruleAckRequired); return; }
    setErr(""); setBusy(true);
    const { data, error } = await supabase.rpc("create_request", {
      p_avail_id: target.id, p_type: reqType, p_intro: intro.trim() || null,
      p_idem: `${uid}:${target.id}`,
    });
    setBusy(false);
    if (error) {
      // v2.80: sinir hatalarinda yenilenme saati de gosterilir.
      const key = "e_" + (error.message || "").split(" ")[0].replace(/[^a-z_]/g, "");
      const taban = t[key] || mapErr(t, error.message);
      const saatli = sinirMetni(t, error, lang);
      const genel = mapErr(t, error.message);

      // 🔴 v2.80 (Ö-C1) — "İlan bulunamadı." ÜÇ FARKLI DÜNYAYI TEK
      // CÜMLEYE SIKIŞTIRIYORDU: ilan silinmiş / host kapatmış / tarihi
      // geçmiş. Üçünde de kullanıcının yapacağı şey farklı, ama üçünde
      // de aynı cümleyi görüyordu ve "bende mi bir tuhaflık var" diye
      // düşünüyordu. Sunucuya SEBEBİ soruyoruz (SQL 224) ve listeyi
      // tazeliyoruz — ölü kart ekrandan kalksın.
      if (/availability_not_found/i.test(String(error.message || ""))) {
        try {
          // Hata YUTULMUYOR: `node check.js` bu satırı ilk yazımda
          // yakaladı ("errorSwallow — 79 bulgu, tavan 78"). Sebep
          // alınamazsa genel mesaj kalır ama sessiz kalmaz.
          const { data: nd, error: ndErr } = await supabase.rpc("ilan_neden_yok", { p_avail_id: target.id });
          if (ndErr) logError("ilan_neden_yok", ndErr);
          if (nd && nd.metin) {
            setErr(nd.metin);
            if (nd.tazele) { setTarget(null); load(); }
            return;
          }
        } catch (e) { /* sebep alinamazsa asagidaki genel mesaj kalir */ }
      }

      return setErr(saatli && saatli !== genel ? taban + saatli.slice(genel.length) : taban);
    }
    // 🔴 23 EYLÜL — GÖNDERİMDEN SONRA SESSİZLİK. Sayfa kapanıyor, kart
    // sessizce "Gönderildi" oluyordu. Kullanıcı ne zaman yanıt geleceğini,
    // yanıt gelmezse ne olacağını ve kredisinin nerede olduğunu bilmiyordu —
    // oysa üçünün de cevabı sunucuda VAR (tutulan kredi, bayat istek
    // süpürgesi, bildirim). Tek satırda söylüyoruz.
    const bedel = data && typeof data.kredi_bedeli === "number" ? data.kredi_bedeli : null;
    setGonderildi({ ad: (hosts[target.host_id] && hosts[target.host_id].name) || target.host_name || "", bedel });
    setTarget(null); setIntro("");
    load();
  }

  // 🔴 AYNI HATAYI BU DOSYADA İKİNCİ KEZ YAPTIM.
  // Bu `useMemo`yu ilk yazışımda `if (kural) return …` erken
  // dönüşünden SONRAYA koydum ve render testi "Rendered more hooks
  // than during the previous render" ile patladı. Dosyanın 63.
  // satırında tam bu dersin yazılı olduğu bir blok duruyor.
  //
  // 🆕 SINIF: "BİR DERSİ YORUMA YAZMAK ONU ÖĞRENMEK DEĞİLDİR —
  // AYNI DOSYADA İKİNCİ KEZ DÜŞTÜĞÜM TUZAK, YORUMUN DEĞİL KAPININ
  // İŞİDİR." (kanca sırasını `check.js` zaten denetliyor; bu blok
  // artık ondan önce, koşulsuz alanda.)
  // ══════════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS · 5. TUR — BAŞLIĞIN ÜÇ KATMANI TEK YERDE HESAPLANIYOR.
  //
  // Tasarımın `.dugum` / `.ust-h1` / `.ust-alt` üçlüsü. Üçü de GERÇEK
  // veriden geliyor; hiçbiri uydurulmuyor. Veri yoksa katman düşer,
  // yerine sahte bir cümle KONMAZ — boş bir satır, yanlış bir satırdan
  // iyidir.
  //
  //   dugum  : filtre/seyahat havalimanının kodu+şehri, yoksa "TÜM HAVALİMANLARI"
  //   baslik : havalimanının adı, yoksa sekmenin adı (dürüst geri düşüş)
  //   alt    : "Kalkışına …" (yalnız seyahat varsa) · "N host yayında"
  const basKonum = useMemo(() => {
    const kod = apFilter ? (apFilter.key || apFilter) : (sortTrip ? sortTrip.airport : null);
    const ap = kod ? airports.find(a => a.key === kod) : null;
    // `airports` girdileri `{ key: "IST", label: "IST — İstanbul" }`
    const sehir = ap && ap.label && ap.label.includes("—")
      ? ap.label.split("—").pop().trim() : null;
    const dugum = kod ? (sehir ? `${sehir} · ${kod}` : kod) : t.allAirportsDates;
    const baslik = sehir || (kod ? kod : t.discTitle);
    const parcalar = [];
    // 🔴 ALT SATIR ESKİ BİLGİYİ KAYBETMEDEN TASARIMIN ALT SATIRI OLDU.
    // İlk yazışımda üç anahtarı (`sortedByTrip` · `tapToChange` ·
    // `tapToFilter`) öksüz bıraktım; `olu_metin_check` yakaladı.
    // O anahtarlar süs değildi: kullanıcıya listenin NEDEN bu sırada
    // olduğunu ve filtreyi NEREDEN değiştireceğini söyleyen tek
    // cümlelerdi. Yeni satır ikisini de taşıyor.
    //
    // 🆕 SINIF: "BİR EKRANI TASARIMA UYDURURKEN SİLDİĞİM CÜMLE,
    // TASARIMIN REDDETTİĞİ BİR CÜMLE DEĞİL — BENİM UNUTTUĞUM BİR
    // İŞLEVDİR."
    if (sortTrip && sortTrip.date) {
      const gs = geriSayim(sortTrip.date, sortTrip.timeFrom || "00:00", null, t);
      if (gs && gs.tur === "once" && gs.metin) {
        parcalar.push(String(t.discToDeparture || "{s}").replace("{s}", gs.ham || gs.metin));
      } else {
        parcalar.push(String(t.sortedByTrip || "")
          .replace("{ap}", sortTrip.airport).replace("{d}", fmtLongDate(sortTrip.date, lang)));
      }
    }
    if (dateF) parcalar.push(fmtLongDate(dateF, lang));
    // `rows` yüklenene kadar NULL — bu memo erken dönüşlerden önce
    // çalıştığı için sayıyı korumasız okumak çökertiyordu.
    if (rows && rows.length) parcalar.push(String(t.discHostsLive || "{n}").replace("{n}", String(rows.length)));
    // 3 Eylül — "filtrelemek için dokun" kuyruğu kalktı: tasarım 02'de alt
    // satır iki parça ("Kalkışına 3 sa 12 dk · 6 host yayında"); filtre
    // yolu sağ üstteki daire, etkin filtre varsa altın nokta onu söylüyor.
    // Etkin filtre hâlinde "değiştirmek için dokun" kalıyor (durum bilgisi).
    if (apFilter || dateF) parcalar.push(t.tapToChange);
    return { dugum: BUYUK(String(dugum)), baslik, alt: parcalar.join(" · ") };
  }, [apFilter, sortTrip, airports, dateF, rows, lang, t]);

  // v6.2 (K3) — liste gelene kadar terminal radarı: "arıyoruz" anlatılıyor.
  if (rows === null) return <Load t={t} title={t.discTitle} onBack={onBack}
    gosterge={<TerminalRadari etiket={t.discScanning} dugum={scope && scope.airport ? scope.airport : null} />} />;

  // 🔴 v2.66 (madde 9) — TEK KAPI TANIMI. Rozet ile ilan verisi ayrı
  // kaynaklardır; ikisinden biri "misafir alınamaz" diyorsa kapı kapalıdır.
  // Kapıyı iki yerde ayrı ayrı yazmak, birinin bayatlaması demekti.
  const isBlocked = r => !!(r && ((badges[r.id] && badges[r.id].blocks_request)
    || r.guest_policy === "not_allowed" || r.blocks_request));

  // 🔴 v2.79 (A7) — HOST'A KURAL SORUSU.
  // Hata YUTULMUYOR: sunucunun reddetme sebebi (doğrulanmış kural, günlük
  // tavan, telefon doğrulaması) kullanıcının GÖRMESİ gereken şey. Sessizce
  // hiçbir şey olmaması, butonun bozuk olduğunu düşündürür.
  async function askHost(availId) {
    if (!availId || askBusy) return;
    setAskBusy(true);
    const { data, error } = await supabase.rpc("ilan_kurali_sor", { p_avail_id: availId });
    setAskBusy(false);
    if (error) {
      // Sunucu gunluk sinirda yenilenme anini `hint` ile gonderiyor
      // (SQL 223). Kullaniciya yalniz "hakkin doldu" demek yarim cevap;
      // "ne zaman acilacak" olmadan kullanici tekrar tekrar deniyor.
      const key = "e_" + String(error.message || "").split(" ")[0].replace(/[^a-z_]/g, "");
      const taban = t[key] || mapErr(t, error.message);
      const zenginlestirilmis = sinirMetni(t, error, lang);
      setAskState(m => ({ ...m, [availId]:
        zenginlestirilmis && zenginlestirilmis !== mapErr(t, error.message)
          ? taban + zenginlestirilmis.slice(mapErr(t, error.message).length)
          : taban }));
      return;
    }
    const durum = data && data.durum;
    setAskState(m => ({ ...m, [availId]:
      durum === "baglanti_var" ? (t.askHostAlreadyConnected || "Bu host ile zaten bağlantın var — Tanış sekmesinden yazabilirsin.")
      : durum === "zaten_soruldu" ? (t.askHostAlreadyAsked || "Bu host'a zaten sordun; yanıtını bekliyoruz.")
      : (t.askHostSent || "Soru gönderildi. Host yanıtlarsa bildirim alacaksın.") }));
  }
  const blockedTarget = isBlocked(target);

  // v2.98 (SQL 252 §4b) — TUTULACAK KREDİ SUNUCUDAN. Alan yoksa (eski
  // sunucu) 1'e düşüyoruz: yeni app + eski veritabanı hâlinde kullanıcıya
  // "bedava" demek, alınan krediyi gizlemek olurdu. Yanılıyorsak kendi
  // aleyhimize yanılalım.
  const tut = (pre && pre.credit_hold != null) ? Number(pre.credit_hold) : 1;
  const toplam = (pre && pre.credit_total != null)
    ? Number(pre.credit_total) : tut + ((pre && pre.credit_cost) || 0);

  // Kural kararı tam ekran açıldığında keşif listesini KAPATIYOR: bu bir
  // yan panel değil, kullanıcının bütün dikkatini hak eden bir cevap.
  if (kural) {
    // 4 Eylül — tasarım 03 TAM EKRAN: alt sekme çubuğu görünmez. Keşfet sekme
    // kabuğunun içinde çizildiği için çubuk altta kalıyordu; `Modal` her
    // şeyin üstüne çıkar (donanım geri tuşu da kapatır).
    return (
      <Modal visible animationType="none" onRequestClose={() => setKural(null)}>
        <KuralKarari t={t} avail={kural.avail} skor={kural.skor}
          onBack={() => setKural(null)}
          onSend={isBlocked(kural.avail) ? null : () => { const a = kural.avail; setKural(null);
                          setTarget(a); setErr(""); setMoreOpen(false); setAdvice(null); }}
          // 🔴 v6.1 (Gökberk md.e) — "Salon kurallarını oku" burada Keşfet'e
          // dönüp "% uyum" açıklamasını açıyordu: etiket bir şey, varış
          // başka bir şey. Düğme artık KuralKarari'nin içinde programın
          // resmî kural sayfasını açıyor; kaynak yoksa hiç görünmüyor.
          />
      </Modal>
    );
  }

  return (
    <Sayfa>
    <Hdr t={t} right={
        // ══════════════════════════════════════════════════════════════
        // 🔴 30 AĞUSTOS — FİLTRE DÜĞMESİNİN YERİ.
        //
        // Gökberk: "filtre butonunun yeri iyileştirilmeli."
        //
        // Eskiden ikon + "Filtre" etiketi taşıyan geniş bir hapti ve
        // bandın üst satırında LOUNGELINK ile bildirim rozetinin ARASINA
        // giriyordu. Üç öğe (marka · filtre · zil+EN) tek satırda
        // sıkışınca hiçbiri nefes alamıyor; parlak gökyüzünün üstündeki
        // koyu dolgu da düğmeyi bir "gri leke" gibi gösteriyordu.
        //
        // Yeni hâli EN rozetiyle AYNI DİLDE: aynı çap, aynı ince çerçeve,
        // yalnız ikon. Etiket ekran okuyucuda duruyor — görsel gürültü
        // gitti, bilgi gitmedi. Filtre açıkken altın bir nokta durumu
        // söylüyor.
        //
        // 🆕 SINIF: **"AYNI SATIRDA DURAN İKİ DÜĞME AYNI DİLİ KONUŞMALI —
        // BİRİ ETİKETLİ HAP, DİĞERİ YUVARLAK ROZETSE SATIR DEĞİL
        // KALABALIK OLUR."**
        // ══════════════════════════════════════════════════════════════
        // 🔴 5. tur — 40px özel düğme yerine tasarımın `.ust-eylem`i:
        // 38px daire, 1px `--cizgi2`, %4 beyaz zemin. Aynı halka geri
        // okunda ve ana sayfadaki profil düğmesinde de kullanılıyor;
        // bandın sağ üst köşesi artık tek bir dil konuşuyor.
        <View>
          <Btn v="ust" daire a11yLabel={t.filterBtn} onPress={() => setFiltersOpen(v => !v)}
            sol={<Ikon ad="filtre" boy={17} renk={C.foto.baslik} />} />
          {(apFilter || dateF) ? (
            <View pointerEvents="none" style={{ position: "absolute", top: 2, right: 2,
                           width: 7, height: 7, borderRadius: R.full,
                           backgroundColor: C.gold }} />
          ) : null}
        </View>
      }
      /* ══════════════════════════════════════════════════════════════
         🔴 30 AĞUSTOS · 5. TUR — KEŞFET BAŞLIĞI HÂLÂ ESKİ YAPIDAYDI.

         Gökberk: "Keşfet eski yapıda kalmış mesela."

         Tasarımı bu kez OKUMADIM, TARAYICIDA ÇİZDİRDİM
         (tasarim/tasarim_render.py → tasarim/ref/00_kesfet.png) ve
         uygulamanın önizlemesiyle yan yana koydum. Üç katmanlı başlık:

           .dugum   İSTANBUL · IST                     ← yerin kimliği
           .ust-h1  Terminal A                         ← YERİN ADI
           .ust-alt Kalkışına 3 sa 12 dk · 6 host yayında

         Uygulamada ise:
           .dugum   TÜM HAVALIMANLARI VE TARIHLER
           .ust-h1  Keşfet                             ← SEKMENİN ADI
           .ust-alt (YOK)

         İki fark, ikisi de yapısal:
         · Başlık bir YER değil bir SEKME adıydı. Kullanıcı zaten
           Keşfet'e bastı; ekranın ona söyleyeceği şey nerede olduğu.
         · Üçüncü satır hiç yoktu — yani "kaç host yayında" ve "ne
           kadar vaktin var", tasarımda başlığın taşıdığı iki CANLI
           sayı, üründe hiçbir yerde görünmüyordu.

         ⚠️ VERİ UYDURULMADI. Tasarımdaki "Terminal A" bizde yok;
         yerine gerçek olan kullanılıyor: filtrelenen ya da seyahatteki
         havalimanının adı. O da yoksa dürüst geri düşüş ("Keşfet").
         "6 host yayında" ise gerçekten `rows.length`.

         🆕 SINIF: "BİR BAŞLIK SEKMENİN ADINI TEKRAR EDİYORSA, EKRANIN
         EN GENİŞ SATIRI HİÇBİR ŞEY SÖYLEMİYOR DEMEKTİR."
         ══════════════════════════════════════════════════════════════ */
      title={basKonum.baslik}
      sub={basKonum.alt}
      /* 🔴 FOTOĞRAFLI/MESH BANT İLK BURADA — tasarımı bu ekran için
         çizdik ("Keşfet") ve bant bir LİSTE ekranında yerini hak
         ediyor. Form ekranlarına GİRMİYOR: orada aynı yer doldurulacak
         alanlardan çalınmış olur.
         ⚠️ Bu satırı bir kez KAZAYLA SİLDİM: başlığı yeniden yazarken
         `sub` ile `onBack` arasındaki bloğu toptan değiştirdim ve
         aradaki `foto` prop'u da gitti. Keşfet sessizce düz başlığa
         düştü — `mount_test`in bant nöbetçisi yakaladı.
         🆕 SINIF: "BİR BLOĞU BAŞTAN YAZARKEN EN BÜYÜK RİSK YAZDIĞIM
         DEĞİL, ARASINDA DURAN VE FARK ETMEDİĞİM ŞEYDİR." */
      foto={{ ustBilgi: basKonum.dugum, olc: bnt.olc, tam: bnt.tam }}
      kaydir={bnt.kaydir}
      onBack={onBack} />
    <Kaydirma {...bnt.scrollProps}
      contentContainerStyle={{ padding: ARA[20], paddingTop: bnt.ustBosluk + ARA[20],
                               paddingBottom: ARA[40] }}>

      {/* 033: host da basvurabilir — rol bir kimlik degil, o gunku baglam */}
      {myRole === "host" && (
        <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: SP[3], marginBottom: SP[3] }}>
          <Text style={{ fontWeight: "700", color: C.goldInk, fontSize: FS.base }}>{t.hostCanApplyTitle}</Text>
          <Text style={{ color: C.goldInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{t.hostCanApplyBody}</Text>
        </View>
      )}

      {/* MVP: filtreler "Filtre" butonunun arkasinda, panel varsayilan KAPALI */}
      {filtersOpen && (
        <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: ARA[14], marginBottom: SP[3] }}>
          <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.mutedAA, letterSpacing: 1.5, marginBottom: ARA[10] }}>{t.filterSort}</Text>
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterAirport}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[10] }}>
            {hiddenCount > 0 && (
              <Btn v="tealSoft" sm style={{ marginBottom: SP[2] }}
                label={t.hiddenByFilter.replace("{n}", String(hiddenCount))}
                onPress={() => { setApFilter(null); setDateF(""); }} />
            )}
          </View>
          {/* ══════════════════════════════════════════════════════════
              🔴 19 EYLÜL (Gökberk md.17 · ONAYLANDI) — ÇİP SATIRI GİTTİ,
              ARAMALI SEÇİCİ GELDİ.
              "filtrede tüm havalimanlarını tek tek vermek filtre alanını
               çok uzatıyor; droplist sistemi getirelim bence."
              Ölçüm: katalogda 222 havalimanı var ve hepsi alt alta
              çiziliyordu; filtre paneli ekranın çoğunu yiyor, altındaki
              tarih/sektör/kural filtreleri kaydırmadan görünmüyordu.
              Düz droplist YAZMADIM: sık kullanılanlar (IST·SAW·ESB·ADB·
              AYT) listenin başında kendi başlığıyla duruyor, gerisi
              aramada. Yani çipin hızı korunuyor, yeri harcanmıyor.
              Seçici `ortak.js`te ve TEK: aynı bileşen md.9'da tekli
              kipte çalışıyor.
              ══════════════════════════════════════════════════════════ */}
          <AirportPicker
            t={t}
            label=""
            airports={(airports || []).map(a => ({ code: a.key, name: a.label || a.key, city: a.city || "" }))}
            value={apFilter ? (apFilter.key || apFilter) : ""}
            onSelect={(kod) => {
              if (!kod) return setApFilter(null);
              const bul = (airports || []).find(a => a.key === kod);
              setApFilter(bul || { key: kod, label: kod });
            }}
          />
          {!!apFilter && (
            <Btn v="ghost" sm full={false} label={t.allAirports}
              onPress={() => setApFilter(null)} style={{ marginBottom: ARA[10] }} />
          )}
          {/* MVP: "Uçuş Numarası" etiketi + tek genis input ("örn. TK712") */}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterFlightLbl}</Text>
          <TextInput style={[S.input, { backgroundColor: C.card, marginBottom: ARA[10] }]} value={flight}
            onChangeText={x => setFlight(x.toUpperCase())} placeholder={t.filterFlight} placeholderTextColor={C.mut} autoCapitalize="characters" />
          {/* MVP: Sektör serbest metin degil CHIP — secili chip sunucu ilike filtresine gider */}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterSector}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[10] }}>
            {SECTOR_OPTS.map(sc => (
              <TouchableOpacity key={sc} style={[S.chip, sector === sc && S.chipOn]} onPress={() => setSector(sector === sc ? "" : sc)}>
                <Text style={{ color: sector === sc ? C.gold : C.ink, fontSize: FS.sm }}>{gorunur(sc)}</Text>
              </TouchableOpacity>
            ))}
          </View>
          {/* MVP: Dil chip'leri — host_langs kesisimi, istemci tarafi */}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterLang}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[10] }}>
            {LANG_OPTS.map(lg => (
              <TouchableOpacity key={lg} style={[S.chip, langF === lg && S.chipOn]} onPress={() => setLangF(langF === lg ? null : lg)}>
                <Text style={{ color: langF === lg ? C.gold : C.ink, fontSize: FS.sm }}>{gorunur(lg)}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* MVP: TARİH — canlıda hiç yoktu */}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterDate}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[10] }}>
            <TouchableOpacity style={[S.chip, !dateF && S.chipOn]} onPress={() => setDateF(null)}>
              <Text style={{ color: !dateF ? C.gold : C.ink, fontSize: FS.sm }}>{t.allDates}</Text>
            </TouchableOpacity>
            {[...new Set((rows || []).map(r => r.avail_date))].filter(Boolean).sort().slice(0, 6).map(d => (
              <TouchableOpacity key={d} style={[S.chip, dateF === d && S.chipOn]} onPress={() => setDateF(d)}>
                <Text style={{ color: dateF === d ? C.gold : C.ink, fontSize: FS.sm }}>{String(d).slice(5)}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* MVP: SIRALAMA — Eşleşme / Güven / Saat */}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterSortBy}</Text>
          <View style={{ flexDirection: "row", gap: ARA[6], marginBottom: ARA[10] }}>
            {[["match", t.sortMatch], ["trust", t.sortTrust], ["time", t.sortTime]].map(([k, lab]) => {
              const on = sortBy === k;
              return (
                <Secim key={k} bicim="segment" dolu ton="purple" secili={on}
                  etiket={lab} onPress={() => setSortBy(k)} />
              );
            })}
          </View>

          {/* MVP: Yalnızca kadın host'lar (kadın güvenlik akışının parçası) */}
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setWomenOnly(v => !v)}
            style={{ flexDirection: "row", alignItems: "center", paddingVertical: ARA[6] }}>
            <View style={{ width: 20, height: 20, borderRadius: R.onay, borderWidth: 1.5, marginRight: SP[2],
                           borderColor: womenOnly ? C.purple : C.line, backgroundColor: womenOnly ? C.purple : "transparent",
                           alignItems: "center", justifyContent: "center" }}>
              {womenOnly ? <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} /> : null}
            </View>
            <Text style={{ color: C.body, fontSize: FS.sm }}>{t.womenHostsOnly}</Text>
          </TouchableOpacity>
        </View>
      )}
      {/* TASARIM 02 · `.not.iyi`: "Senin uçuşunda N kişi daha var — …" teal
          çerçeveli kutu, listenin ÜSTÜNDE (kartın içinde değil). */}
      {sameFlight > 0 && rows.length > 0 ? (
        <View style={{ borderWidth: 1, borderColor: "transparent", borderRadius: R.md,
                       backgroundColor: C.tealTint, paddingVertical: ARA[10], paddingHorizontal: ARA[14],
                       marginBottom: ARA[14] }}>
          <Text style={{ color: C.teal, fontSize: FS.xs, fontWeight: "600", lineHeight: 16 }}>
            {String(t.sameFlightStrip || "").replace("{n}", String(sameFlight))}
          </Text>
        </View>
      ) : null}
      {/* KOTA ŞERİDİ — sunucunun uyguladığı üç sınır. 3 Eylül: tasarım 02'de
          listenin üstünde çip yok; şerit filtre paneliyle birlikte açılıyor
          (bilgi kaybolmadı, yeri değişti). */}
      {filtersOpen && kotalar && (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[10], marginTop: ARA[4] }}>
          {kotalar.istek && (
            <View style={[S.chip, { backgroundColor: C.card, borderColor: C.line }]}>
              <Text style={{ fontSize: FS.xs, color: C.mut }}>
                {String(t.quotaOpenRequests || "")
                  .replace("{a}", String(kotalar.istek.acik ?? 0))
                  .replace("{t}", String(kotalar.istek.tavan ?? 1))}
              </Text>
            </View>
          )}
          {kotalar.soru && typeof kotalar.soru.kalan === "number" && (
            <View style={[S.chip, { backgroundColor: C.card, borderColor: C.line }]}>
              <Text style={{ fontSize: FS.xs, color: C.mut }}>
                {String(t.quotaAskHost || "").replace("{n}", String(kotalar.soru.kalan))}
              </Text>
            </View>
          )}
          {kotalar.ucus && typeof kotalar.ucus.kalan === "number" && (
            <View style={[S.chip, { backgroundColor: C.card, borderColor: C.line }]}>
              <Text style={{ fontSize: FS.xs, color: C.mut }}>
                {String(t.quotaFlight || "").replace("{n}", String(kotalar.ucus.kalan))}
              </Text>
            </View>
          )}
        </View>
      )}

      {/* ══════════════════════════════════════════════════════════════
          🔴 12 EYLÜL · GECE — "HATA" İLE "BOŞ" AYNI EKRANDA DURUYORDU.
          İlk kez bir arıza sahnesi çekince gördüm (42_kesfet_ariza):
          liste yüklenemediğinde ekran ÖNCE "Bağlantı kurulamadı", hemen
          ALTINDA "Burada henüz ilan yok" diyordu — ve peşine "haber ver"
          formunu, "yol arkadaşlarına bak" düğmesini, "burada henüz host
          yok" kartını diziyordu.
          İki cümle birbirini yalanlıyor: biri "soramadım" diyor, öteki
          "sordum, yok" diyor. Kullanıcı İKİNCİSİNE inanır — çünkü o daha
          kesin konuşuyor. Sonuç: havalimanının boş olduğunu sanıp
          kapatıyor, oysa yalnız bağlantı kopmuştu.
          Artık yükleme HATASI kendi ekranını alıyor; boş durum yalnız
          BAŞARIYLA yüklenip sıfır satır dönen listeye ait.
          🆕 SINIF: "HATA DURUMU İLE BOŞ DURUM AYNI EKRANDA GÖRÜNÜYORSA
          ÜRÜN İKİ ŞEY SÖYLÜYOR VE KULLANICI YANLIŞ OLANA İNANIYOR —
          'VERİ YOK' İLE 'VERİYİ ALAMADIM' AYNI CÜMLE DEĞİLDİR."
          ══════════════════════════════════════════════════════════ */}
      {!!gonderildi && (
        <View accessibilityLiveRegion="polite"
          style={{ backgroundColor: C.greenBg, borderRadius: R.sm, padding: SP[3], marginTop: ARA[10],
                   flexDirection: "row", alignItems: "flex-start", gap: SP[2] }}>
          <Ikon ad="tamam" boy={FS.base} renk={C.greenInk} />
          <Text style={{ flex: 1, color: C.greenInk, fontSize: FS.sm, lineHeight: 19 }}>
            {String(t.reqSentNotice || "").replace("{ad}", abbrevName(gonderildi.ad) || "")}
            {gonderildi.bedel === 0 ? "" : " " + (t.reqSentNoticeCredit || "")}
          </Text>
        </View>
      )}
      {loadErr ? (
        <LoadFail t={t} onRetry={load} style={{ marginTop: ARA[26] }} />
      ) : rows.length === 0 ? (
        <View style={[S.empty, { paddingVertical: ARA[26] }]}>
          <Ikon ad="salon" boy={28} renk={C.muted} stil={{ marginBottom: SP[2] }} />
          <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", fontWeight: "600" }}>
            {filtreVar ? t.noHostsFiltered : (myRole === "host" ? t.noAvailFound : (t.noAvailFoundGuest || t.noAvailFound))}
          </Text>
          {(apFilter || dateF) ? (
            <Text style={{ color: C.dim, fontSize: FS.sm, textAlign: "center", marginTop: SP[1], lineHeight: 16 }}>
              {t.viewingClearBody.replace("{f}", `${apFilter ? (apFilter.key || apFilter) : t.allAirports}${dateF ? " · " + fmtLongDate(dateF, lang) : ""}`)}
            </Text>
          ) : null}

          {/* 🔴 v2.93 — BOŞ EKRAN, ÜRÜNÜN EN PAHALI EKRANI.
              Misafir açar, ilan yoktur, kapatır ve bir daha açmaz. Oysa
              tam o anda bir ihtiyacı var ve yazmaya hazır. "Haber ver"
              bu ekranı bir söze çeviriyor — ve host tarafına gösterilecek
              TALEP KANITI üretiyor (SQL 247). */}
          <HaberVer t={t} lang={lang}
            airport={apFilter ? (apFilter.key || apFilter) : null}
            date={dateF || null} />
          {/* Ek görsel: "Yol arkadaşlarına bak" → Tanış sekmesi */}
          {filtreVar && (
            <Btn v="gold" sm full={false} label={t.clearFilters} onPress={filtreleriTemizle} style={{ marginTop: SP[3], alignSelf: "stretch" }} />
          )}
          {onMeet && (
            <Btn v="ghost" sm label={t.seeCompanions} onPress={onMeet} style={{ marginTop: ARA[10] }} />
          )}
          {/* Marketing: boş liste = kayıp değil, talep sinyali. Seyahati olan guest
              zaten 056 ile host gelince bildirim alacak — bunu ona söyle. */}
          {onAddTrip && (
            <View style={{ marginTop: ARA[14], backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.sm, padding: SP[3], alignSelf: "stretch" }}>
              <IkonMetin ad="kutlama" renk={C.tealInk} stilMetin={{ color: C.tealInk, fontWeight: "700", fontSize: FS.sm, textAlign: "center" }} metin={t.notifyWhenHostTitle} />
              <Text style={{ color: C.mutedAA, fontSize: FS.sm, textAlign: "center", marginTop: SP[1], lineHeight: 16 }}>{t.notifyWhenHostBody}</Text>
              <Btn v="teal" sm label={t.notifyWhenHostCta} onPress={onAddTrip} style={{ marginTop: ARA[10] }} />
            </View>
          )}
        </View>
      ) : rows.map((r, idx) => {
        const h = hosts[r.host_id] || {};
        const mine = r.host_id === uid;
        const open = r.slots - r.filled;
        const rst = myReqs[r.id];
        // 🔴 23 EYLÜL — "SONA ERDİ" YAZAN KARTTA AKTİF "İSTEK GÖNDER" VARDI.
        // Sunucu bugünün ilanlarını gün bitene kadar döndürüyor; saati geçmiş
        // bir ilan sayacında "Sona erdi" yazarken düğmesi açıktı (sahne 02 ve
        // 37'de ölçüldü — biri listenin EN ÜSTÜNDEYDİ). Sunucu da artık
        // reddediyor (SQL 300 §B5); ekran aynı şeyi önceden söylüyor.
        const bitti = (geriSayim(r.avail_date, r.time_from, r.time_to, t) || {}).tur === "bitti";
        return (
          // 🔴 6. tur — TASARIMDA İLK KART FARKLI: `.kart.one`
          // altın izli kenar + üstten çok soluk altın tint. Ben bütün
          // kartları aynı çizmiştim; önizlemede İKİSİ de altın kenarlı
          // görünüyordu — yani "öne çıkan" işareti hiçbir şeyi öne
          // çıkarmıyordu.
          // ⚠️ Gradyan yok (expo-linear-gradient bağımlılık olur);
          // tasarımın %5.5'ten %0'a inen tinti yerine sabit %3 altın.
          // Ölçtüm: ortalama fark 1.4/255 — gözle ayırt edilemez.
          // 🔴 8. tur — ÇİZGİ İKİ KAT PARLAKTI. `C.goldLine` 0.28,
          // tasarımın `--altinIz`i 0.13. Piksel ölçümü: tasarım
          // (53,45,43) ↔ uygulama (119,99,45). `goldTrace` = 0.13.
          // 🔴 12 EYLÜL · 3. TUR — ÜST IŞIK ARTIK STATİK DEĞİL.
          // Kartı yüzeyden ayıran şey çerçeve değil üstüne düşen ışık
          // (üst ΔE 6.32, alt oturma ΔE 2.01; eski sıcak sarı kenar
          // ΔE 20.36'ydı). `IsikliKart` o ışığı dokunuşla besliyor:
          // basılıyken ×2.6 → ΔE 16.35, yani 2.6 katına çıkıyor ama hâlâ
          // eski çerçevenin altında kalıyor.
          // Kartın içindeki üç dokunma hedefi (avatar · rozet · düğme)
          // bozulmuyor: `IsikliKart` sorumluluk talep etmeden dinliyor.
          <IsikliKart key={r.id} stil={[S.card, idx === 0 && !mine && {
                 borderColor: C.goldTrace || C.goldLine,
                 backgroundColor: C.altinIz03 }]}>
            {/* v1.86: yuzde HEM burada HEM sagdaki halkada yaziyordu — ayni
                sayiyi iki kez gostermek bilgi degil gurultu. Halka kaldi. */}
            {/* 🔴 v2.23 — BILGI KUTUSU YANLIS KARTTA ACILIYORDU.
                Kosul `idx === 0` idi: 5. kartin rozetine dokununca kutu
                1. kartin icinde, ekranin cok yukarisinda aciliyordu.
                Kullanici "hicbir sey olmuyor" diye okur — ve hakli.
                Artik DOKUNULAN kartin icinde aciliyor. */}
            {badgeInfo && badgeInfo.id === r.id && (
              <View style={{ backgroundColor: C.card, borderWidth: 0, borderTopWidth: 1, borderTopColor: C.parlamaGuc,
                             borderRadius: R.sm, padding: SP[3], marginBottom: ARA[10] , ...ELEV.card }}>
                <Text style={{ ...T.label, color: C.goldText, marginBottom: SP[1] }}>{badgeInfo.label}</Text>
                <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body }}>{badgeInfo.info}</Text>

                {/* 🔴 v2.79 (A7) — KAPALI KAPININ ARKASINDA BİR İNSAN VAR.
                    Gökberk: "o görselden görebileceğin şekilde host ile bir
                    sohbet butonu yok."
                    Haklıydı: 219 ile metni dürüst hâle getirdik ("host'a
                    sohbetten sorabilirsin") ama işaret ettiğimiz kapı
                    EKRANDA YOKTU. Doğru cümlenin altında yol olmayınca
                    cümle bir tesellidir, çözüm değil.
                    Yeni "Bağlantı kur" kopyası YAZMADIM: aynı işi yapan
                    ikinci bir onay+sohbet makinesi, ikisi de yarım bakımlı
                    olurdu. Var olan bağlantı raylarında gidiyor
                    (SQL 221, intent='kural_sorusu').
                    Buton YALNIZCA `can_ask_host` true iken çıkıyor — yani
                    kuralı resmî kaynaktan DOĞRULADIĞIMIZ ilanlarda çıkmıyor.
                    Doğruladığımız bir kuralı host'a sormak hem onu boşuna
                    rahatsız eder hem bizi güvenilmez yapar. */}
                {badgeInfo.canAsk && (
                  <View style={{ marginTop: ARA[10], borderTopWidth: 1, borderTopColor: C.line, paddingTop: ARA[10] }}>
                    {askState[badgeInfo.id] ? (
                      <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.teal }}>
                        {askState[badgeInfo.id]}
                      </Text>
                    ) : (
                      <>
                        <TouchableOpacity
                          disabled={askBusy}
                          onPress={() => askHost(badgeInfo.id)}
                          accessibilityRole="button"
                          style={{ backgroundColor: askBusy ? C.goldSoft : C.gold, borderRadius: R.xs,
                                   paddingVertical: SP[3], paddingHorizontal: ARA[14],
                                   minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center" }}>
                          <Text style={{ color: askBusy ? C.gold : "#fff", fontSize: FS.sm, fontWeight: "700" }}>
                            {/* 🔴 v2.89 (Gökberk md.5) — "Host'a sor" eylemin YARISINI söylüyordu.
                                Bu düğme bir soru göndermiyor sadece; bir BAĞLANTI
                                İSTEĞİ açıyor (connection_requests, intent='kural_sorusu').
                                Host kabul ederse sohbet kanalı açılıyor. Kullanıcı
                                ne yaptığını bilmeden bir bağlantı kurmamalı. */}
                            {askBusy ? (t.askHostBusy || "Gönderiliyor…") : (t.askHostCta2 || t.askHostCta)}
                          </Text>
                        </TouchableOpacity>
                        <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[6], lineHeight: 16 }}>
                          {t.askHostHint}
                        </Text>
                      </>
                    )}
                  </View>
                )}

                <TouchableOpacity onPress={() => setBadgeInfo(null)}
                  accessibilityRole="button" accessibilityLabel={t.close}
                  style={{ marginTop: SP[2], minHeight: TAP.minHeight, justifyContent: "center" }}>
                  <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm }}>{t.close || "Kapat"}</Text>
                </TouchableOpacity>
              </View>
            )}
            {/* 🔴 3 EYLÜL — TASARIM 02: kartın İÇİNDE not ve "EN İYİ EŞLEŞME"
                etiketi YOK. "Senin uçuşunda N kişi daha var" cümlesi
                listenin ÜSTÜNDE tek bir teal kutu (rows.map'ten önce).
                İlk kartın öne çıkması `.kart.one` kenarıyla söyleniyor;
                ikinci bir etiket aynı şeyi iki kez söylerdi. */}
            {/* ══════════════════════════════════════════════════════════
                🔴 30 AĞUSTOS · GECE SİSTEMİ — KART SIRASI TASARIMDAKİ SIRA.

                Gökberk: "tasarımda hazırladığın tasarımı birebir uygula."

                Bir önceki turda kişi satırını tasarımdaki hâle getirmiştim
                ama KARTIN SIRASI hâlâ eskisiydi. Ölçtüm — iki sıra yan yana:

                  ESKİ                      TASARIM
                  1 salon adı + uyum        1 kişi + kalkan + uyum
                  2 olanaklar               2 salon adı
                  3 rozetler                3 terminal/kapı satırı
                  4 kişi satırı             4 rozetler
                  5 tarih satırı            5 sayaç + altın düğme
                  6 slot + düğme

                Fark yalnız estetik değil: eskide kullanıcı ÖNCE mekânı,
                EN SON insanı görüyordu. Oysa bu ürünün sattığı şey mekân
                değil — kapıyı açacak KİŞİ. Salonu ikinci sıraya almak
                cümlenin öznesini değiştiriyor: "Primeclass'a girebilirsin"
                değil, "Deniz seni Primeclass'a alabilir".

                🆕 SINIF: **"BİR KARTTAKİ SIRALAMA BİR CÜMLEDİR; İLK
                ÖĞE ÖZNEDİR. YANLIŞ ÖĞEYİ BAŞA KOYARSAN ÜRÜNÜ YANLIŞ
                ANLATIRSIN — RENKLER DOĞRU OLSA BİLE."**
                ═══════════════════════════════════════════════════════ */}
            <View style={{ flexDirection: "row", alignItems: "flex-start" }}>
              {/* Tasarımdaki kart anatomisi:
                    · 44px avatar, altına gömülü GÜVEN KALKANI (teal daire)
                    · isim 16/600 · mertebe satırı 11.5 sessiz
                    · sağda uyum: MONO, iri, teal + altında "UYUM" etiketi
                  Kalkan avatarın kendisine değiyor, ayrı bir satırda değil:
                  "doğrulanmış" yazan bir etiket okunmaz, kişinin yüzüne
                  değen bir işaret okunur. */}
              <TouchableOpacity hitSlop={TAP.slop} disabled={mine} onPress={() => !mine && onOpenProfile && onOpenProfile(r.host_id)}
                accessibilityRole={mine ? undefined : "button"}
                accessibilityLabel={mine ? undefined : (h.name || "")}
                style={{ flexDirection: "row", alignItems: "flex-start", flex: 1, minWidth: 0 }}>
                <View style={{ width: 44, height: 44, marginRight: SP[3] }}>
                  {/* 🔴 8. tur — disk tasarımda ALTIN DEĞİL, mor-gri bir taş
                      (`linear-gradient(145deg,#2B2430,#1E1A22)`). `C.goldSoft`
                      pikselde (44,37,20) veriyordu, tasarım (39,33,43). Harf
                      altın kalıyor — kontrast oradan geliyor, zeminden değil. */}
                  <View style={{ width: 44, height: 44, borderRadius: R.full, backgroundColor: C.avatarBg || C.goldSoft,
                                 borderWidth: 1, borderColor: C.line2 || C.line,
                                 alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
                    {h.photo ? <Image source={{ uri: h.photo }} style={{ width: 44, height: 44 }} />
                      : <Text style={{ fontSize: FS.title, fontWeight: "600", color: C.goldText,
                                       fontFamily: F.serif }}>
                          {(h.name || "?").charAt(0).toUpperCase()}</Text>}
                  </View>
                  {/* GÜVEN KALKANI — yalnız gerçekten doğrulanmışta. Rozeti
                      herkese takmak, rozeti anlamsız kılar. */}
                  {!!h.badge && (
                    <View style={{ position: "absolute", right: -3, bottom: -3, width: 17, height: 17,
                                   borderRadius: R.full, backgroundColor: C.teal,
                                   borderWidth: 2, borderColor: C.card,
                                   alignItems: "center", justifyContent: "center" }}>
                      <Ikon ad="guvenlik" boy={9} renk={C.bg} />
                    </View>
                  )}
                </View>
                <View style={{ flex: 1, minWidth: 0 }}>
                  {/* 🔴 12 EYLÜL — KİŞİ ADI SERİFE GEÇTİ, VE BU BİR
                      SÜSLEME DEĞİL BİR SAPMANIN DÜZELTİLMESİ.
                      Tipografi kuralımız yazılı: "Cormorant YALNIZ insan
                      adı ve kural hükmü." Keşfet kartındaki isim düz
                      sans'tı — yani kendi kuralımızın en görünür ihlali
                      tam da ürünün ana listesindeydi.
                      Hiyerarşi de buradan geliyor: salon adı (sans 16)
                      ile kişi adı (serif 20) artık BOYUTLA değil
                      AİLEYLE ayrılıyor. Kimseyi küçültmeden ayrışıyorlar.
                      🆕 SINIF: "İKİ ŞEYİ AYIRMAK İÇİN ÖNCE BOYUTA
                      UZANMA — AİLE, AĞIRLIK VE RENK DAHA UCUZ VE DAHA
                      SESSİZ AYIRICILARDIR." */}
                  <Text numberOfLines={1} style={{ fontFamily: F.serifGosterim, fontSize: FS.title,
                                                   color: C.ink, lineHeight: SATIR(FS.title, "serif") }}>
                    {h.name || "—"}{mine ? ` ${t.you}` : ""}
                  </Text>
                  {!!(kartAdi[r.id] || h.prof) && (
                    <Text numberOfLines={1} style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[3] }}>{kartAdi[r.id] || h.prof}</Text>
                  )}
                  {kurucu[r.host_id] ? (
                    <Text numberOfLines={1} style={{ fontFamily: MONO[500], fontSize: FS.micro, letterSpacing: 1,
                                                     color: C.goldText, marginTop: ARA[3] }}>
                      {BUYUK(String(t.foundingBadge || "Kurucu Host #{n}").replace("{n}", String(kurucu[r.host_id])))}
                    </Text>
                  ) : null}
                </View>
              </TouchableOpacity>
              {/* MVP satir 427: v>=85 yesil · v>=65 altin · alti gri.
                  Tek esikli (>=60 altin) hali skorun anlamini duzlestiriyordu:
                  85'lik bir eslesme ile 61'lik ayni gorunuyordu. */}
              {/* ══════════════════════════════════════════════════════════
                  🔴 v3.4 — UYUM HALKASI ÜÇ AYRI KUSURU BİRDEN TAŞIYORDU.
                  Ekran görüntülerinde net görülüyor:

                  1) ÇIPLAK BİR SAYI. Kartın sağ üstünde "58" ya da "92"
                     yazıyor ve NE OLDUĞU hiçbir yerde yazmıyor. Kullanıcı
                     bir sayı görüyor, anlamını tahmin ediyor.

                  2) SAYI CEVABIN ÖNÜNE GEÇİYOR. Ekran görüntüsündeki bir
                     kart aynı anda şunları söylüyordu: yeşil "92" · altın
                     "Misafir alınmıyor" · yeşil "Seyahatinle eşleşiyor".
                     Yani ürünün ASIL cevabı ("giremezsin") ile ikincil bir
                     sıralama ipucu ("92") aynı ağırlıkta, hatta sayı daha
                     parlak. Kural motoru bu ürünün kalbi; onun cevabı
                     hiçbir şeyin arkasında kalmamalı.

                  3) DOKUNULAMIYOR. Yanındaki her rozet açıklanabiliyor
                     (ⓘ), bu sayı açıklanamıyordu.

                  🆕 SINIF: "BİR SAYI, ÜRÜNÜN ASIL CEVABIYLA AYNI GÖRSEL
                  AĞIRLIKTAYSA, KULLANICI HANGİSİNİN KARAR OLDUĞUNU
                  BİLEMEZ — SIRALAMA İPUCU, CEVABIN ÖNÜNE GEÇEMEZ."

                  Artık: başvurulamıyorsa halka SUSUYOR (gri, ince, düşük
                  vurgu). Başvurulabiliyorsa renkli. Altında ne olduğu
                  yazıyor ve dokunulunca açıklıyor.
                  ═══════════════════════════════════════════════════════ */}
              {!mine ? (() => {
                const ms = r.match_score || 0;
                const kapali = !!r.blocks_request;
                const mc = kapali ? C.dim : ms >= 85 ? C.green : ms >= 65 ? C.gold : C.muted;
                return (
                  <TouchableOpacity hitSlop={TAP.slop}
                    /* 🔴 30 AĞUSTOS · 2. TUR — SAYIYA DOKUNMAK ARTIK
                       BİR PARAGRAF DEĞİL, KURAL EKRANINI AÇIYOR.
                       Bu, tasarımın 03 ekranına giden yol: kullanıcı
                       "neden %84?" diye sorduğu anda cevabı KOŞUL KOŞUL
                       görüyor. Eski açıklama paragrafı silinmedi — kural
                       ekranının açılamadığı durumda hâlâ devrede. */
                    onPress={() => setKural({ avail: r, skor: ms })}
                    accessibilityRole="button"
                    accessibilityLabel={`${t.matchScoreLabel}: ${ms}`}
                    style={{ alignItems: "flex-end", marginLeft: ARA[12], flexShrink: 0,
                             opacity: kapali ? 0.55 : 1 }}>
                    {/* 🔴 30 Ağu · Gece sistemi — HALKA KALDIRILDI, SAYI MONO.
                        Tasarımda bu sayının çevresinde ÇERÇEVE YOK: sağa
                        yaslanmış iri bir mono sayı ve altında harf aralıklı
                        küçük bir etiket. Çerçeveyi ben eklemiştim (v3.4) ve
                        gerekçem "sayı çıplak kalmasın"dı — ama çerçeve sayıyı
                        AÇIKLAMIYOR, sadece bir kutuya koyuyor. Açıklayan şey
                        altındaki etiket; o zaten var.

                        🆕 SINIF: "BİR SAYIYI KUTUYA ALMAK ONU AÇIKLAMAZ —
                        ÇERÇEVE VURGUDUR, ANLAM DEĞİL. ANLAMI ANCAK KELİME
                        VERİR."

                        Renk merdiveni (kapalı→gri · 85+ yeşil · 65+ altın)
                        KALDI. Tasarımdaki iki örnek kartın ikisi de açık
                        ilandı; kapalı ilan hâli orada hiç çizilmemişti.
                        Tasarımın çizmediği bir durumu tasarıma sormak yerine
                        ürünün kendi kuralını koruyorum — sayının sustuğu
                        yer, kural motorunun konuştuğu yerdir. */}
                    <Text style={{ color: mc, fontSize: FS.title, fontWeight: "600",
                                   fontFamily: MONO[600], lineHeight: Math.round(FS.title * 1.3) }}>{ms}</Text>
                    <Text style={{ fontSize: FS.micro, color: C.dim, marginTop: ARA[4],
                                   fontWeight: "600",
                                   letterSpacing: 1.4, }}>{BUYUK(t.matchWord)}</Text>
                  </TouchableOpacity>
                );
              })() : null}
            </View>
            {/* ── kart-salon ── Tasarımda 19/600, kişi satırından sonra ve
                TAM GENİŞLİKTE. Eskiden uyum sayısıyla aynı satırdaydı ve
                uzun salon adları (`TAV Primeclass Lounge Dış Hatlar`) tek
                satıra sığmadığı için ya kırpılıyor ya sayıyı sıkıştırıyordu.
                Kendi satırında iki satıra kadar nefes alabiliyor. */}
            <Text numberOfLines={2} style={{ fontSize: FS.lg, fontWeight: "600", color: C.ink,
                                             marginTop: SP[3], lineHeight: SATIR(FS.lg) }}>
              {r.lounge_name || r.airport_code}
            </Text>
            {/* ── kart-term ── havalimanı · tarih · saat aralığı.
                Tasarımdaki "Dış hatlar · Kapı A12" satırının bizdeki
                karşılığı. Uçuş numarası varsa sonuna ekleniyor. */}
            <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[4] }}>
              {r.airport_code} · {fmtLongDate(r.avail_date, lang)} · {String(r.time_from).slice(0,5)}–{String(r.time_to).slice(0,5)}
            </Text>
            {/* 🔴 v2.29 — "GIRINCE NE VAR?" Kural motoru "girebilir misin"i
                cevapliyordu; bu satir digerini cevapliyor. Misafirin salonu
                secerken bakacagi ikinci sey bu. */}
            {/* 3 Eylül — olanak ikon satırı karttan çıktı (tasarım 02'de yok);
                `amenities` verisi salon rehberinde okunuyor. */}
            {/* ══════════════════════════════════════════════════════════
                🔴 3 EYLÜL — ROZET SIRASI TASARIMIN ÜÇ ÇİPİ (02_kesfet):
                  [Misafir ücretsiz · teal] [TK1979 · nötr] [Aynı uçuş · bilgi]
                Eskiden aynı satırda 6-7 rozet vardı (kural rozeti ⓘ,
                "Seyahatinle eşleşiyor", taşıyıcı, öne çıkan, dolu, başvuru
                durumu). Her biri doğruydu ama hepsi birden kartı bir
                etiket duvarına çeviriyordu; tasarım üçünü seçmiş.
                  · misafir politikası → `guest_policy` (included/paid/
                    not_allowed) — kural motorunun kısa cevabı
                  · uçuş numarası → ilanın uçuşu
                  · aynı uçuş → `same_flight` (olgu · bilgi tonu)
                Kural rozetinin AÇIKLAMASI kaybolmadı: çipe dokununca
                eskisi gibi bilgi kutusu açılıyor (badgeInfo); ENGEL hâli
                (blocks_request) amber çip olarak yine görünür; başvuru
                durumu (kabul/bekliyor/dolu) kart-alt satırında yazıyor.
                ══════════════════════════════════════════════════════════ */}
            <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[20],
                           flexWrap: "wrap", marginTop: ARA[18] }}>
              {(() => {
                const bg = badges[r.id];
                const acKutu = () => bg && bg.info && setBadgeInfo(
                  badgeInfo && badgeInfo.id === r.id ? null
                    : { id: r.id, label: bg.label, info: bg.info, canAsk: !!bg.can_ask_host });
                const gp = r.guest_policy;
                // v6.1 (md.34.1) — rozet RPC'si de kapatabilir (farklı havayolu);
                // o zaman çip "Misafir ücretsiz" DEMEZ, kapının sebebini söyler.
                const engel = isBlocked(r);
                /* 11 Eylül — renk/glif kararı artık `KararCipi`de (ui.js).
                   Burada yalnız HANGİ politika olduğu söyleniyor; engel
                   varsa metin sunucudan gelen sebep, ama rozet yine
                   "girilmez" dilinde — aynı anlam, aynı görünüş. */
                // 🔴 13 EYLÜL (Gökberk md.18, md.19) — `r.block_reason`
                // SUNUCU ANAHTARIDIR, etiket değil. Ham hâliyle basılınca
                // kullanıcı çipte "guests_not_allowed" / "fully_booked"
                // okuyordu. Artık `t.engelKisa` sözlüğünden geçiyor;
                // sözlükte olmayan bir anahtar gelirse ham kod DEĞİL,
                // nötr "Başvuru kapalı" yazıyor.
                const gpEtiket = engel
                  ? ((r.blocks_request && t.engelKisa && t.engelKisa[r.block_reason])
                     || (bg && bg.label) || t.cannotApply)
                  : (bg && !gp ? bg.label : null);
                const gpPolitika = engel ? "not_allowed" : gp;
                return (
                  <>
                    {/* 🔴 12 EYLÜL — ÜÇ HAPTAN BİRİ KALDI.
                        Gökberk: "isim bir kutuda, havayolu başka bir
                        kutuda, uçuş kodu ayrı bir hap içinde… bu göz
                        yorar." Haklı ve ayrımı yapmak kolay: bu üç
                        şeyden yalnız BİRİ bir karar — "misafir ücretsiz".
                        Diğer ikisi OLGU: uçuş numarası ve "aynı uçuş".
                        Bir olguyu hap içine koymak, ona karar ağırlığı
                        verir. Artık ikisi de mono, harf aralıklı, büyük
                        harf METİN; onları ayıran şey çerçeve değil 20pt
                        boşluk.
                        🆕 SINIF: "HER BİLGİYİ ÇERÇEVELERSEN HİÇBİRİNİ
                        VURGULAMAMIŞ OLURSUN — VURGU BİR FARKTIR, BİR
                        KAPLAMA DEĞİL." */}
                    {(gpPolitika || gpEtiket)
                      ? <KararCipi t={t} politika={gpPolitika} etiket={gpEtiket}
                                   onPress={bg && bg.info ? acKutu : undefined} /> : null}
                    {r.flight_number ? <Olgu metin={r.flight_number} /> : null}
                    {r.same_flight ? <Olgu metin={t.sameFlight} /> : null}
                    {/* v6.1 (md.32) — çip zaten "Dolu" diyorsa ikinci kez yazılmaz. */}
                    {r.fully_booked && !engel ? <Olgu metin={t.fullyBooked} renk={C.amber} /> : null}
                  </>
                );
              })()}
            </View>
            {/* ══════════════════════════════════════════════════════════
                ── kart-alt ── TASARIMDAKİ SON SATIR: SAYAÇ + ALTIN DÜĞME.

                Eskiden bu satırın solunda "• • 2 slot açık" yazıyordu.
                Ölçtüm ve şunu gördüm: kapasite, kullanıcının bu ekranda
                sorduğu soru DEĞİL. Kapasite biterse düğme zaten çıkmıyor
                (`open > 0`), yani sayı hiçbir kararı değiştirmiyor — yalnız
                kartın en değerli satırını dolduruyordu. Kullanıcının o
                satırda sorduğu asıl soru "ne kadar vaktim var".

                🆕 SINIF: **"BİR SAYIYI GÖSTERMEK, ONUN BİR KARARI
                DEĞİŞTİRDİĞİ ANLAMINA GELMEZ. HİÇBİR DAVRANIŞI
                DEĞİŞTİRMEYEN SAYI, YER KAPLAYAN BİR SÜSTÜR."**

                Kapasite kaybolmadı: doluluk bilgisi rozet sırasındaki
                `fully_booked` çipinde ve `ReqStateBadge`de duruyor —
                yani ANLAMLI olduğu yerde.
                ═══════════════════════════════════════════════════════ */}
            <View style={{ flexDirection: "row", alignItems: "center", marginTop: SP[4] }}>
              <Sayac veri={geriSayim(r.avail_date, r.time_from, r.time_to, t)} />
              {/* 🔴 12 EYLÜL · 3. TUR — KART İÇİ DÜĞME İÇERİK KADAR.
                  Gökberk: "kart içlerindeki butonları tam genişlik yerine
                  içerik kadar daralt."
                  Yukarıdaki eski gerekçem ("kartın tek asıl eylemi en geniş
                  alan olmalı") Fitts'ten geliyordu ve yarısı doğru: ALT
                  KENARDAKİ tek birincil eylem için geçerli, çünkü orada
                  başparmak kör atış yapar. Kart İÇİNDE değil — orada
                  kullanıcı zaten karta bakıyor, hedefi görüyor. Ve dört
                  kart alt alta gelince dört tam genişlik altın dolgu,
                  listeyi düğme duvarına çeviriyor.
                  Dokunma hedefi küçülmüyor: `Btn` 44pt tabanını `hitSlop`
                  ile koruyor.
                  🆕 SINIF: "FITTS YASASI 'BÜYÜK YAP' DEMEZ, 'UZAK VE KÖR
                  OLAN HEDEFİ BÜYÜT' DER — GÖRÜNEN BİR HEDEFİ BÜYÜTMEK
                  ERİŞİMİ DEĞİL YALNIZ GÜRÜLTÜYÜ ARTIRIR." */}
              <View style={{ flex: 1, marginLeft: SP[3], alignItems: "flex-end" }}>
              {!mine && (
                rst === "accepted" ? <Text style={{ color: C.teal, fontWeight: "700", fontSize: FS.sm, textAlign: "right" }}>{t.reqAcc}</Text>
                : rst === "pending" ? <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm, textAlign: "right" }}>{t.reqSent}</Text>
                : bitti ? <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "right" }}>{t.listingEndedCard}</Text>
                // 🔴 23 EYLÜL — REDDEDİLEN İSTEK KARTTA GÖRÜNMÜYORDU. Veri v2.87'den
                // beri geliyor (`declined` okunuyor) ama hiç çizilmiyordu: kart
                // "hiç başvurmamışsın" gibi duruyor, aynı host'a tekrar tekrar
                // istek atılabiliyordu.
                // 🔴 v6.1 (Gökberk md.23) — "Bu kez olmadı" ne olduğunu söylemiyordu.
                // Durum + sonuç: kim ne yaptı, kredin nerede.
                : (rst === "declined" || rst === "expired") ? (
                  <View style={{ alignItems: "flex-end" }}>
                    <Text style={{ color: C.body, fontWeight: "600", fontSize: FS.sm, textAlign: "right" }}>
                      {rst === "declined" ? t.reqDeclinedShort : t.reqExpiredShort}</Text>
                    <Text style={{ color: C.mut, fontSize: FS.xs, textAlign: "right", marginTop: ARA[2] }}>{t.reqRefundedShort}</Text>
                  </View>
                )
                : open > 0 ? (
                  /* MVP kuralı: başvuru fiziksel katılıma bağlı — aynı havalimanı+tarih+
                     çakışan saat (has_trip) + telefon doğrulaması. Yoksa buton pasif + neden. */
                  // 🔴 v2.23 — KURAL ENGELI VARSA BUTONLAR DA KAPANMALI.
                  // "Bu ilan misafir alamıyor" rozeti gösterip ALTINA aktif
                  // bir "İstek Gönder" koymak, kullanıcıya çelişkili iki
                  // sinyal vermektir: rozet hayır der, buton evet der.
                  // Kullanıcı butona güvenir, tıklar, sonra reddedilir.
                  // Rozet bir SÜS değil, bir KAPI olmalı.
                  isBlocked(r) ? (
                    // 🔴 v2.34 — "rozete dokun" ANLAMSIZ BIR BUTON METNIYDI.
                    // Kullanici hangi rozete dokunacagini bilmiyor. Eylemi
                    // degil SEBEBI soylemek gerekiyordu — ve sebep zaten
                    // elimizde: rozetin kendi aciklamasi. Dokunmayi
                    // beklemeden gosteriyoruz.
                    <TouchableOpacity hitSlop={TAP.slop} activeOpacity={0.8}
                      onPress={() => badges[r.id]?.info && setBadgeInfo(
                        badgeInfo && badgeInfo.id === r.id ? null
                          : { id: r.id, label: badges[r.id].label, info: badges[r.id].info,
                              canAsk: !!badges[r.id].can_ask_host })}
                      style={{ alignItems: "flex-end", alignSelf: "flex-end", maxWidth: "100%" }}>
                      <View style={{ backgroundColor: C.redBg || C.hataBg, borderWidth: 1,
                                     borderColor: "transparent", borderRadius: R.xs,
                                     paddingVertical: SP[2], paddingHorizontal: SP[3] }}>
                        <Text style={{ color: C.redInk, fontSize: FS.xs, fontWeight: "600", textAlign: "right" }}>
                          {t.cannotApply}
                        </Text>
                        <View style={{ flexDirection: "row", alignItems: "center",
                                       justifyContent: "flex-end", marginTop: ARA[2] }}>
                          <Text style={{ color: C.redInk, fontSize: FS.xs }}>{t.cannotApplyWhy}</Text>
                          <Ikon ad="bilgi" boy={12} kutu={14} renk={C.redInk} stil={{ marginLeft: SP[1] }} />
                        </View>
                      </View>
                    </TouchableOpacity>
                  ) : (r.has_trip && phoneOk) ? (
                    <Btn v="gold" sm full={false} sagAd="sag" label={t.reqSoon}
                      onPress={() => { setTarget(r); setErr(""); setMoreOpen(false); setAdvice(null); }} />
                  ) : (
                    // 🔴 v2.24 — PASIF GORUNEN BUTON TIKLANABILIYORDU.
                    // Gorsel olarak soluk ama dokunulabilir bir buton,
                    // kullaniciya "calismiyor mu, ben mi beceremiyorum"
                    // dedirtir. Gorunum ile davranis ayni seyi soylemeli.
                    <TouchableOpacity hitSlop={TAP.slop}
                      disabled={!phoneOk && !onVerify}
                      // 🔴 v2.89 (Gökberk md.11) — İLANIN VERİSİ ARTIK TAŞINIYOR.
                      // `AddVisit` zaten bir `suggest` prop'u kabul ediyor ve
                      // havalimanı/tarih/saati ondan dolduruyor (screens.js:9256)
                      // — ama bu düğme `onAddTrip()` diye ARGÜMANSIZ çağırıyordu,
                      // yani hazır makine altı çağrı yerinin beşinde kullanılmıyordu.
                      // Sonuç: misafir formu boş buluyor ve özellikle TARİH/SAATİ
                      // elle girerken karıştırıyor — başvurusu da o yüzden eşleşmiyor.
                      // 🆕 SINIF: "VAR OLAN BİR YETENEK, ÇAĞRILMADIĞI SÜRECE YOK
                      // HÜKMÜNDEDİR."
                      onPress={() => { if (!phoneOk && onVerify) onVerify(); else if (!r.has_trip && onAddTrip) onAddTrip(r); }}
                      style={{ alignItems: "flex-end", alignSelf: "flex-end" }}>
                      <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: "transparent", borderRadius: R.xs, paddingVertical: SP[2], paddingHorizontal: SP[3] }}>
                        <Text style={{ color: C.goldText, fontSize: FS.xs, fontWeight: "600" }}>
                          {!phoneOk ? t.gateVerifyNow : t.gateAddTripNow}
                        </Text>
                      </View>
                    </TouchableOpacity>
                  )
                ) : null
              )}
              </View>
            </View>
          </IsikliKart>
        );
      })}
      <Modal visible={!!target} animationType="slide" onRequestClose={() => setTarget(null)}>
        {/* #32: MVP Istek Gonder — tam ekran, Hdr'li */}
        <Sayfa>
          <Hdr t={t} scene="İSTEK" title={t.reqTitle} onBack={() => setTarget(null)} />
          <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[34] }}>
            {/* ══════════════════════════════════════════════════════════
                🔴 v3.4 — TAAHHÜT ANINDA GÜVENLİK TEK KELİME BİLE YAZMIYORDU.

                Bu ekran ürünün en kritik anı: bir YABANCI seçiliyor ve
                kredi harcanıyor. Buraya kadar kullanıcı yalnız kredi
                matematiği görüyordu.

                Ölçtüm: güvenlikle ilgili her yüzey KARARDAN SONRA
                geliyordu — `safetyBar` yalnız SOHBETİN içinde (istek kabul
                edilmeden sohbet açılmıyor), Güvenlik Merkezi profil
                menüsünün derinliğinde, `sos112` onun da içinde.
                Yani "yabancıyla buluşma" ürününde güvenlik, buluşmaya
                karar verdikten SONRA anlatılıyordu.

                🆕 SINIF: "GÜVENLİK BİLGİSİ KARARDAN SONRA GÖSTERİLİYORSA
                BİLGİ DEĞİL BEYANNAMEDİR — KARARI ETKİLEMESİ İÇİN KARARIN
                ÖNÜNDE DURMALI."

                Metin yeni yazılmadı: `safetyBar` zaten TR ve EN olarak
                vardı, yalnız yanlış yerde duruyordu.
                ═══════════════════════════════════════════════════════ */}
            {/* v6.1 (Gökberk md.33) — üç bilgi kutusu KATLANIR: başlık hep
                görünür (güvence kaybolmaz), gövde bir dokunuş uzakta. */}
            <Katlanir buyukBaslik baslik={t.reqSafeTitle} stil={{ marginBottom: SP[3] }}
              ikon={<Ikon ad="guvenlik" boy={15} renk={C.tealInk} />}>
              <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 19 }}>{t.reqSafeBody}</Text>
            </Katlanir>
            <View style={[S.card, { flexDirection: "row", alignItems: "center" }]}>
              <View style={{ width: 46, height: 46, borderRadius: R.full, backgroundColor: C.goldSoft, alignItems: "center", justifyContent: "center", marginRight: SP[3] }}>
                <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.goldText, fontFamily: F.serif }}>{(target?.host_name || "?").charAt(0).toUpperCase()}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.lg }}>{abbrevName(target?.host_name)}</Text>
                {/* MVP: isim altinda "• Güvenilir Host" rozeti */}
                <Text style={{ color: C.tealInk, fontSize: FS.sm, marginTop: ARA[2], fontWeight: "600" }}>• {badgeLabel(t, target?.host_badge)}</Text>
                <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>
                  {target?.lounge_name || target?.airport_code} · {fmtLongDate(target?.avail_date, lang)} · {String(target?.time_from || "").slice(0,5)}–{String(target?.time_to || "").slice(0,5)}
                </Text>
                {/* v2.87 (madde 5): istek gönderme ekranında da taşıyıcı
                    görünür. Kural burada işliyor; kullanıcının kararını
                    verdiği son ekranda bilginin eksik olması en pahalı yer. */}
                {!!(target && availCarrier[target.id]) && (
                  <View style={{ marginTop: SP[1] }}>
                    <CarrierChip code={availCarrier[target.id]} map={carrierMap} t={t} />
                  </View>
                )}
                {/* MVP: nokta gostergesi + "2 açık" + eslesme yuzdesi ayni satirda */}
                <Text style={{ color: C.green, fontSize: FS.sm, marginTop: SP[1], fontWeight: "600" }}>
                  {"•".repeat(Math.max(0, (target?.slots || 0) - (target?.filled || 0)))}{"·".repeat(Math.min(target?.slots || 0, target?.filled || 0))} {Math.max(0, (target?.slots || 0) - (target?.filled || 0))} {t.openWord} · {target?.match_score || 0}% {t.matchPct}
                </Text>
              </View>
              {/* ══════════════════════════════════════════════════════
                  🔴 18 EYLÜL (Gökberk md.15) — BU ÇEMBER ETİKETSİZDİ VE
                  "UYUM" DİYE OKUNUYORDU.
                  Gökberk: "istek gönder butonuna tıklanınca 38 yazıyor."
                  O 38 uyum değil, host'un GÜVEN PUANI (`host_score`).
                  Uyum ise hemen solundaki satırda ("%68 eşleşme") zaten
                  yazıyordu — ama çember 42px, altın ve ekranın en vurgulu
                  ögesiydi; göz onu okur, yanındaki 12pt satırı okumaz.
                  Etiketsiz bir sayı, en yakın başlığın adını çalar.
                  🆕 SINIF: "ETİKETSİZ BİR SAYI KENDİNİ TANIMLAMAZ —
                  EKRANDAKİ EN VURGULU KELİMENİN ANLAMINI ÜSTLENİR."
                  ══════════════════════════════════════════════════════ */}
              <View style={{ alignItems: "center", marginLeft: SP[2] }}>
                <View style={{ width: 42, height: 42, borderRadius: R.full, borderWidth: 2, borderColor: C.gold, alignItems: "center", justifyContent: "center" }}>
                  <Text style={{ color: C.gold, fontWeight: "700", fontSize: FS.base }}>{target?.host_score || 0}</Text>
                </View>
                <Text style={{ color: C.mutedAA, fontSize: FS.micro, fontWeight: "600",
                               letterSpacing: 0.6, marginTop: ARA[3] }}>{BUYUK(t.trustShort)}</Text>
              </View>
            </View>

            {/* 🔴 MVP: uygun seyahat YOKSA en ustte uyari + cikis yolu.
                has_trip sunucudan gelir (discover_availabilities) ve
                create_request'in 'no_matching_trip' kurallariyla AYNI
                kosulu tasir — yani burada gosterilen kapi ile sunucunun
                reddi bire bir ortusur. Onceden hicbir uyari yoktu:
                kullanici Gonder'e basip ham hata aliyordu. */}
            {target && !target.has_trip && (
              <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.sm, padding: SP[3], marginTop: SP[3] }}>
                <IkonMetin ad="uyari" boy={13} renk={C.amberInk} metin={t.reqNoTripTitle}
                  stilMetin={{ color: C.amberInk, fontWeight: "700", fontSize: FS.sm }} />
                <Text style={{ color: C.amberInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>
                  {t.reqNoTripBody
                    .replace("{ap}", target.airport_code || "")
                    .replace("{date}", fmtLongDate(target.avail_date, lang))
                    .replace("{from}", String(target.time_from || "").slice(0,5))
                    .replace("{to}", String(target.time_to || "").slice(0,5))}
                </Text>
                {onAddTrip && (
                  <Btn v="gold" sm label={t.reqAddTrip} onPress={() => { const av = target; setTarget(null); onAddTrip(av); }} style={{ marginTop: ARA[10] }} />
                )}
              </View>
            )}

            {/* MVP: ✦ EŞLEŞME AVANTAJLARIN — İSTEK TÜRÜ'nün ÜSTÜNDE */}
            {(() => {
              const adv = [];
              if (myTrust >= 55) adv.push(t.advHighTrust);
              if ((target?.match_score || 0) >= 65) adv.push(t.advHighMatch);
              if (target?.same_flight) adv.push(t.advSameFlight);
              if (target?.same_sector) adv.push(t.advSameSector);
              if (phoneOk && idOk) adv.push(t.advFullyVerified);
              else if (phoneOk) adv.push(t.advVerified);
              return adv.length > 0 ? (
                <Katlanir baslik={t.advTitle} sayi={adv.length} stil={{ marginTop: SP[1], marginBottom: SP[1] }}
                  ikon={<Ikon ad="kutlama" boy={14} renk={C.goldText} />}>
                  {adv.map(a => (
                    <View key={a} style={{ flexDirection: "row", alignItems: "center", marginBottom: SP[1] }}>
                      <Ikon ad="tamam" boy={FS.sm} renk={C.greenInk} stil={{ marginRight: SP[2] }} />
                      <Text style={{ fontSize: FS.sm, color: C.body }}>{a}</Text>
                    </View>
                  ))}
                </Katlanir>
              ) : null;
            })()}

            {/* MVP: İSTEK TÜRÜ seçimi */}
            <Text style={S.label}>{t.reqTypeLabel}</Text>
            {[["lounge", t.reqTypeLounge], ["airport", t.reqTypeAirport], ["coffee", t.reqTypeCoffee], ["route", t.reqTypeRoute]].map(([k, lab]) => {
              const sel = reqType === k;
              return (
                <Secim key={k} bicim="radyo" ton="gold" zemin="alt" secili={sel}
                  etiket={lab} onPress={() => setReqType(k)} stil={{ marginBottom: SP[2] }} />
              );
            })}

            {/* MVP: KISA TANITIM — İSTEK TÜRÜ'nün ALTINDA */}
            <Text style={S.label}>{t.reqIntro} <Text style={{ color: C.dim, fontWeight: "400" }}>— {t.max120}</Text></Text>
            <TextInput style={[S.input, { minHeight: 80 }]} value={intro} onChangeText={x => setIntro(x.slice(0, 120))} multiline placeholder={t.introPh} placeholderTextColor={C.dim} />
            <Text style={{ color: C.dim, fontSize: FS.xs, textAlign: "right", marginTop: SP[1] }}>{intro.length}/120</Text>


            {/* 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: "1 kredi escrow'da tutulur" ile
                "3 kredi ona aktarılır" iki AYRI kutuda, birbirinden habersiz
                duruyordu; kullanıcı çelişki okuyor. İkisi farklı şeyler
                (istek escrow'u vs ücretli girişe teşekkür) ama parçalı
                anlatıldığında bunu kimse çıkaramaz. Tek kutu, tek hesap. */}
            <Katlanir buyukBaslik stil={{ marginTop: ARA[10] }}
              baslik={tut === 0 ? t.creditFreeLine : t.creditTotalLine.replace("{n}", String(toplam))}
              ozet={(pre && pre.credit_balance != null) ? t.creditBalanceWord.replace("{b}", String(pre.credit_balance)) : undefined}
              ikon={<Ikon ad={tut === 0 ? "davet" : "planKart"} boy={15} renk={C.goldText} />}>
              {/* 🔴 v2.98 (SQL 252 §4b) — BU KUTU SABİT "1" YAZIYORDU.
                  Ölçtüm: `request_precheck_pregate` 'credit_hold' alanını
                  SABİT 1 dolduruyordu, oysa isteği gerçekten ücretlendiren
                  `request_credit_cost` 249'dan beri soğuk ağda 0 döndürüyor.
                  Yani ekran "1 kredi tutulacak" diyor, sunucu 0 alıyordu.
                  Kimse şikâyet etmez — lehine bir fark — ama gösterilen bedel
                  onu hesaplayan fonksiyondan okunmuyorsa o bir FİYAT değil
                  TAHMİNDİR. Artık sunucudan okunuyor. */}

              {tut === 0 ? (
                <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 18, marginTop: 0 }}>
                  {"· " + (ulasNot || t.coldFreeReq)}
                </Text>
              ) : (
                <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 18, marginTop: 0 }}>
                  {"· " + t.creditPartEscrow}
                </Text>
              )}
              {(pre && pre.credit_cost > 0) ? (
                <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 18, marginTop: SP[1] }}>
                  {"· " + t.creditPartThanks.replace("{n}", String(pre.credit_cost))}
                </Text>
              ) : null}
              {(pre && pre.credit_balance != null && pre.credit_balance < toplam) ? (
                <Text style={{ color: C.red,
                               fontSize: FS.sm, marginTop: SP[2] }}>
                  {t.creditBalanceWord.replace("{b}", String(pre.credit_balance))}
                </Text>
              ) : null}
            </Katlanir>

            {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
            {/* v1.86 — KURAL KAPISI. Sunucu kararı tek kutuda; misafir
                buluşmadan ÖNCE ne olacağını biliyor. Kapıda sürpriz = güven kaybı. */}
            {!!pre && (pre.headline || pre.detail) && (
              <View style={{ marginTop: ARA[14], borderRadius: R.xs, padding: SP[3], borderWidth: 1,
                             backgroundColor: pre.severity === "block" ? C.hataBg
                                            : pre.severity === "warn" ? C.amberBg : C.tealBg,
                             borderColor: pre.severity === "block" ? C.hataLine
                                        : pre.severity === "warn" ? C.amber : C.teal }}>
                {!!pre.source_label && (
                  <Text style={{ fontSize: FS.xs, letterSpacing: 0.8, fontWeight: "700",
                                 color: C.muted, marginBottom: SP[1] }}>
                    {BUYUK(pre.source_label)}
                  </Text>
                )}
                {/* 🔴 v2.67 (A4) — MİSAFİR HAKKI ROZETİ PRECHECK'TEN.
                    SQL 192 `card_generic` dalına guest_policy/guest_allowance
                    ekledi. Eskiden kredi kartı kaynaklı ilanlarda bu kutuda
                    misafir hakkına dair TEK KELİME yoktu: kullanıcı kredisini
                    harcayıp kapıda öğreniyordu. Rozet yargı değil bilgi verir —
                    politikayı söyler, kullanıcıyı damgalamaz. */}
                {!!pre.guest_policy && (
                  <View style={{ marginBottom: ARA[6] }}>
                    <KararCipi t={t} politika={pre.guest_policy} />
                  </View>
                )}
                <Text style={{ fontSize: FS.sm, fontWeight: "700",
                               color: pre.severity === "block" ? C.redInk
                                    : pre.severity === "warn" ? C.amberInk : C.teal }}>
                  {pre.headline}
                </Text>
                {/* ══════════════════════════════════════════════════════
                    🔴 13 EYLÜL (Gökberk md.3) — "misafir ücretli girer
                    mesajına rağmen istek gönder butonu aktif değil…
                    kullanıcılar ilanlara başvuramıyor mu?"

                    ÖLÇTÜM, `request_precheck`i gerçek veriyle çağırdım:
                      headline    "Misafir hakkı var (1 kişi), ek ücret yok."
                      can_request false
                      block_code  "party_too_big"
                    Yani sunucu ENGELİ ve SEBEBİNİ söylüyor; ekran yalnız
                    `headline`i basıyordu — ve o başlık HOST'UN HAKKINI
                    anlatıyor, engeli değil. Kullanıcı olumlu bir cümle
                    okuyup kilitli bir düğme görüyordu.
                    Başka bir ilanda ise `severity` "warn" gelirken
                    `can_request` false'tu (severity_src "block"): sarı bir
                    uyarı + kilitli düğme.
                    Artık engel varsa SEBEP kendi satırında, kırmızı ve
                    `errMap`ten geçmiş olarak yazılıyor.
                    🆕 SINIF: "BİR DÜĞMEYİ KİLİTLEYEN SEBEP EKRANDA
                    YAZMIYORSA, KULLANICI İÇİN O DÜĞME BOZUKTUR."
                    ══════════════════════════════════════════════════════ */}
                {pre.can_request === false && (
                  <View style={{ backgroundColor: C.hataBg, borderRadius: R.xs,
                                 padding: ARA[10], marginTop: ARA[8] }}>
                    <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18, fontWeight: "700" }}>
                      {t.reqBlockedTitle}
                    </Text>
                    <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18, marginTop: ARA[3] }}>
                      {pre.block_code ? mapErr(t, pre.block_code)
                        : (pre.detail || t.cannotApplyWhy)}
                    </Text>
                  </View>
                )}
                {/* 🔴 v2.24 — UZUN METIN KATLANIYOR.
                    Detay her katmanin notunu arka arkaya ekleyip 400+
                    karakterlik bir duvar olusturuyordu. Kullanici uzun
                    metni OKUMAZ, atlar — ve icindeki gercekten onemli
                    cumle de atlanmis olur. Artik EN KRITIK cumle gorunur,
                    gerisi "Detayları göster" ile acilir. */}
                {/* 🔴 v2.47 — CIHAZDA GORULDU: "Detayları göster" acilinca
                    kisa metin USTTE DURUYOR, tam metin altina geliyordu —
                    ilk cumleler iki kez okunuyordu. Acikken kisa metin
                    gizlenir; tam metin zaten onu iceriyor. */}
                {/* ── KATLANAN GEREKÇE (v2.89 md.4) ──
                    Üstteki rozet + başlık KARARDIR ve hep görünür.
                    Aşağısı GEREKÇE ve kapalı başlar (block hariç). */}
                {(kuralAcik || pre.severity === "block") && (
                <>
                {!!pre.detail && !(moreOpen && pre.more) && (
                  <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body, marginTop: SP[1] }}>
                    {pre.detail}
                  </Text>
                )}
                {/* 🔴 v2.67 (A3) — SEYAHAT KAPISI EKRANA ÇIKTI.
                    SQL 192 precheck'in BAŞINA seyahat kontrolü koydu ve
                    `fix_action: "add_trip"` döndürüyor. Ekran bu dalı
                    tanımadığı için kullanıcı "gönderemezsin" duvarına
                    çarpıyor, çıkışı göremiyordu. Olumsuzu güce çevir:
                    engelin yanında çözümü de göster. Buton fiil taşır. */}
                {pre.fix_action === "add_trip" && onAddTrip && (
                  <Btn v="gold" sm label={t.reqAddTrip} onPress={() => { setTarget(null); onAddTrip(target); }} style={{ marginTop: ARA[10] }} />
                )}
                {/* 🔴 v2.69 — UÇUŞ SAATİ ve TERMİNAL UYARILARI (SQL 199).
                    Gerçek vaka: misafir "14:00–18:00 IST'teyim" yazıyor,
                    uçuşu 15:20'de kalkıyor, host 16:00'da ilan açmış.
                    Saatler ÖRTÜŞÜYOR ama misafir 16:00'da uçakta. İki
                    taraf da birbirini bekliyor, ikisinin de puanı düşüyor.
                    197 gerçek kalkış saatini getirdi; 199 karşılaştırıyor;
                    burası SÖYLÜYOR. Engel değil UYARI: uçuş verisi
                    gecikebilir, plan değişmiş olabilir. */}
                {!!fit && Array.isArray(fit.uyarilar) && fit.uyarilar.length > 0 && (
                  <View style={{ marginTop: ARA[10], borderTopWidth: 1, borderTopColor: C.line + "88", paddingTop: ARA[10] }}>
                    {fit.uyarilar.map((u, i) => (
                      <Text key={u.tip || i}
                        style={{ fontSize: FS.sm, lineHeight: 17, marginTop: i ? 5 : 0,
                                 color: u.tip === "ucus_once_kalkiyor" ? C.amberInk : C.body }}>
                        {u.metin}
                      </Text>
                    ))}
                    {!!fit.tz_varsayildi && (
                      <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: SP[1] }}>
                        {t.tzAssumed}
                      </Text>
                    )}
                  </View>
                )}
                {!!alts && (
                  <TouchableOpacity hitSlop={TAP.slop}
                    onPress={() => { if (alts.count > 0) { setTarget(null); setApFilter(null); setDateF(alts.date || ""); } }}
                    disabled={!alts.count}
                    style={{ backgroundColor: C.card, borderWidth: 1,
                             borderColor: alts.count ? C.teal + "55" : C.line,
                             borderRadius: R.xs, padding: SP[3], marginTop: SP[2] , ...ELEV.card }}>
                    {!!alts.reason && (
                      <Text style={{ fontSize: FS.sm, color: C.mut, lineHeight: 18, marginBottom: SP[1] }}>
                        {alts.reason}
                      </Text>
                    )}
                    <Text style={{ fontSize: FS.sm, fontWeight: "700",
                                   color: alts.count ? C.teal : C.mut }}>
                      {alts.count > 0
                        ? t.altSome.replace("{n}", String(alts.count))
                        : t.altNone}
                    </Text>
                  </TouchableOpacity>
                )}
                {/* 🔴 v2.29 — BASARISIZLIK ANINI FAYDA ANINA CEVIR.
                    Alternatif de yoksa kullanici elimizden cikiyor. Oysa
                    "kendi hakkini nasil alirsin" sorusunu bu uygulamadaki
                    HERKESTEN iyi cevaplayabiliriz: kart katalogu, kart
                    kademesi matrisi ve dogrulanmis banka verisi bizde.
                    Satis degil BILGI: komisyon almiyoruz, dogrulanmamisi
                    dogrulanmamis diye veriyoruz. */}
                {!!alts && alts.count === 0 && (
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => loadAdvice(target.lounge_id)}
                    style={{ marginTop: SP[2], borderTopWidth: 1, borderTopColor: C.line, paddingTop: ARA[10] }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.gold }}>
                      {advice ? t.adviceHide : t.adviceShow}
                    </Text>
                  </TouchableOpacity>
                )}
                {!!advice && advice.length > 0 && (
                  <View style={{ marginTop: SP[2] }}>
                    <Text style={{ fontSize: FS.sm, color: C.mut, lineHeight: 17, marginBottom: SP[2] }}>
                      {t.adviceIntro}
                    </Text>
                    {advice.map((a, i) => (
                      <View key={i} style={{ backgroundColor: C.card, borderWidth: 1,
                                             borderColor: a.confidence === "verified" ? C.green + "50" : C.line,
                                             borderRadius: R.xs, padding: ARA[10], marginBottom: ARA[6] , ...ELEV.card }}>
                        <View style={{ flexDirection: "row", alignItems: "center" }}>
                          <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink, flex: 1 }}>
                            {a.issuer} · {a.card}
                          </Text>
                          <Text style={{ fontSize: FS.xs,
                                         color: a.confidence === "verified" ? C.green : C.amber }}>
                            {a.confidence === "verified" ? t.cardVerified : t.cardUnverified}
                          </Text>
                        </View>
                        <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[1] }}>
                          {a.program}{a.quota ? " · " + a.quota : ""}
                        </Text>
                        <Text style={{ fontSize: FS.sm, color: C.body, marginTop: SP[1], lineHeight: 17 }}>
                          {a.guest_note}
                        </Text>
                      </View>
                    ))}
                  </View>
                )}
                {!!pre.more && pre.more !== pre.detail && (
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => setMoreOpen(v => !v)} style={{ marginTop: ARA[6] }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: "700",
                                   color: pre.severity === "block" ? C.red : C.gold }}>
                      {moreOpen ? t.hideDetails : t.showDetails}
                    </Text>
                  </TouchableOpacity>
                )}
                {moreOpen && !!pre.more && (
                  <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body, marginTop: ARA[6] }}>
                    {pre.more}
                  </Text>
                )}
                </>
                )}
                {/* Katlama düğmesi. `block` durumunda gizli: reddedilen
                    kullanıcıya "sebebi kapat" seçeneği sunmak, sebebi
                    saklamaya davet etmektir. */}
                {pre.severity !== "block" && (!!pre.detail || !!pre.more) && (
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => setKuralAcik(v => !v)}
                    accessibilityRole="button"
                    accessibilityLabel={kuralAcik ? t.ruleWarnClose : t.ruleWarnOpen}
                    style={{ minHeight: TAP.minHeight, justifyContent: "center", marginTop: SP[1] }}>
                    <View style={{ flexDirection: "row", alignItems: "center" }}>
                      <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.gold }}>
                        {kuralAcik ? t.ruleWarnClose : t.ruleWarnOpen}
                      </Text>
                      <Ikon ad={kuralAcik ? "yukari" : "asagi"} boy={14} renk={C.gold} stil={{ marginLeft: SP[1] }} />
                    </View>
                  </TouchableOpacity>
                )}
                {/* 🔴 v2.12 — TESEKKUR KREDISI, ISTEK GONDERMEDEN ONCE.
                    Ucret host'un kartindan cekiliyor; misafir karsiliginda
                    kredi aktariyor. Bunu kabul SONRASI gostermek, parayi
                    alip sonra haber vermek olurdu. Bakiye yetmiyorsa da
                    ONCEDEN soyluyoruz — akis durmuyor ama surpriz de yok. */}
                {/* v2.50: kredi bilgisi artık YUKARIDAKİ tek kutuda
                    toplanıyor; burada tekrar etmiyoruz. */}
                {pre.needs_ack && pre.can_request !== false && (
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => setAckOk(v => !v)}
                    style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[10] }}>
                    <View style={{ width: 19, height: 19, borderRadius: R.onay, borderWidth: 1.5,
                                   borderColor: ackOk ? C.teal : C.line, marginRight: SP[2],
                                   alignItems: "center", justifyContent: "center",
                                   backgroundColor: ackOk ? C.teal : "transparent" }}>
                      {ackOk && <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} />}
                    </View>
                    <Text style={{ fontSize: FS.sm, color: C.ink, flex: 1 }}>{t.ruleAckLabel}</Text>
                  </TouchableOpacity>
                )}
              </View>
            )}
            {/* v2.48 — İstek ekranı da rozetle AYNI dili konuşur: kural
                motoru "misafir alınamaz" diyorsa Gönder kilitlidir (sunucu
                kapısı 159'da zaten var; bu katman kullanıcıya nedeni
                tıklamadan önce söyler). */}
            {/* 🔴 v2.66 (madde 9): kapı artık İKİ kaynaktan okunuyor —
                rozet (blocks_request) VE ilanın kendi guest_policy'si.
                Rozet hiç gelmemiş olsa bile 'not_allowed' bir kapıdır;
                eskiden bu durumda buton açık kalıyor, kullanıcı basıp
                sunucu hatası alıyordu. Neden her zaman yazılır. */}
            {!!blockedTarget && (
              <Text style={{ color: C.red, fontSize: FS.sm, marginTop: ARA[10], lineHeight: 18 }}>
                {(badges[target.id] && (badges[target.id].info || badges[target.id].block_reason))
                  || target.block_reason || t.cannotApplyWhy}
              </Text>
            )}
            {/* 🔴 13 EYLÜL (Gökberk md.3) — KİLİTLİ DÜĞME ARTIK SUSMUYOR.
                Üç ayrı sebeple kilitleniyordu ve üçünde de üstünde
                "İsteği gönder" yazıyordu: kullanıcı düğmeye basıp hiçbir
                şey olmadığını görüyor, bozuk sanıyordu. Sebep varsa
                etiket de değişiyor; "ack" hâli tek eksik onay olduğu için
                kendi cümlesini taşıyor. */}
            {(() => {
              const kapali = (target && !target.has_trip) || (pre && pre.can_request === false)
                || blockedTarget;
              const ackEksik = !kapali && pre && pre.needs_ack && !ackOk;
              const pasif = busy || kapali || ackEksik;
              return (
                <Btn label={kapali ? t.reqSendBlocked : ackEksik ? t.ruleAckRequired : `${t.send}`}
                  sagAd={pasif ? undefined : "sag"} onPress={send} disabled={pasif} busy={busy}
                  style={{ marginTop: ARA[14], opacity: pasif && !busy ? 0.45 : 1 }} />
              );
            })()}
          </ScrollView>
        </Sayfa>
      </Modal>
    </Kaydirma>
    </Sayfa>
  );
}


// #26: MVP isim bicimi — "Elif Kaya" -> "Elif K."

// Ortak onay popup'ı — çıkış, hesap silme, seyahat iptali gibi tüm yıkıcı işlemler için.
// 🔴 19 EYLÜL · DERİN DENETİM — `ConfirmModal` `ui.js`E TAŞINDI.
// Sebep bir bağımlılık yönü: `ekranlar_ana.js` → `ekranlar_yalin.js`
// import ediyor, yani tersi olamaz. Değerlendirme silmeye onay eklerken
// `ekranlar_yalin.js`in bu bileşene ihtiyacı oldu ve tek seçenek İKİNCİ
// BİR KOPYA yazmaktı — bu kod tabanının en pahalı hatası (dört ayrı
// Row, üç ayrı Toggle dersi hemen aşağıda yazılı).
// `ui.js` ikisinin de altında duruyor; doğru yer orası. Adı buradan da
// dışa veriliyor ki `screens.js`in mevcut importu kırılmasın.
// 🆕 SINIF: "İKİ MODÜLÜN İKİSİNİN DE İHTİYAÇ DUYDUĞU BİR BİLEŞEN,
// İKİSİNDEN BİRİNE DEĞİL İKİSİNİN ALTINA KONUR."
export { ConfirmModal };

// 🔴 v2.65 · İKİZ BİLEŞENLER SİLİNDİ (MODÜL SEVİYESİ Row + Toggle)
// Bu iki bileşen burada tanımlıydı ama HİÇBİR YERDEN çağrılmıyordu:
// <Row> kullanan iki ekranın (Safety, Settings) kendi YEREL Row'u var ve
// onu gölgeliyor; <Toggle> ise hiç kullanılmıyordu. Üç ayrı Toggle ve dört
// ayrı Row, dört ayrı API demekti — ui.js'e yazılan erişilebilirlik ve
// 44px dokunma hedefi düzeltmeleri hiçbirine ulaşmıyordu.
// Artık Toggle TEK yerden gelir: ./ui. Ölü ikizler kaldırıldı.
export function Meet({ t, lang, session, rol, onOpenProfile, onOpenChat, radarFilter, onClearRadar, onRequestListing, onVerify, onAddTrip, filtersOpen: filtersOpenProp, setFiltersOpen: setFiltersOpenProp, altSekme, setAltSekme, bnt}) {
  // 🔴 Canlı APP 18: Meet, onOpenChat'i NESNE ile çağırıyordu ama App.js
  // (channelId, name) bekliyor → companion sohbet HİÇ açılmıyordu.
  // Doğrusu: kabul edilmiş bağlantının kanalını bul (yoksa oluştur), sonra aç.
  async function openCompanionChat(peerId, peerName) {
    const uid = session?.user?.id;
    if (!uid || !peerId) return;
    const { data: cr, error: hata3 } = await supabase.from("connection_requests")
      .select("id").eq("status", "accepted")
      .or(`and(from_id.eq.${uid},to_id.eq.${peerId}),and(from_id.eq.${peerId},to_id.eq.${uid})`)
      .maybeSingle();
      if (hata3) logError("ekranlar_ana.js:1841", hata3);
    if (!cr) return;
    // 🔴 v2.96 (C3) — KANAL AÇMAYI SUNUCU YAPIYOR.
    // İstemcinin `chat_channels`e insert edebilmesi, ENGELLENMİŞ bir
    // çiftte bile kanal açabilmesi demekti: engelleme sohbeti kesmiyor,
    // yalnız listeden düşürüyordu. `baglanti_sohbeti_ac` (SQL 248) hem
    // sahipliği hem engeli kontrol ediyor.
    // Değişken adı `k` DEĞİL `kanal`: `k` bu kod tabanında HostWallet'ta
    // kart nesnesi olarak kullanılıyor ve RPC alan denetimi kaynağı ADLA
    // izlediği için ikisini karıştırıyor. Aynı sınıfa bu turda ikinci kez
    // düştüm — "bir değişken adı, kaynağı adla izleyen nöbetçiye de
    // bildirimdir".
    const { data: kanal, error: ke } = await supabase.rpc("baglanti_sohbeti_ac", { p_conn_id: cr.id });
    // 19 Eylül — aynı sınıf (bkz. HomeConnections): sunucunun bilinçli
    // reddi ekranda yazılmadığı sürece kullanıcı için "buton bozuk".
    if (ke) { logError("baglanti_sohbeti_ac", ke); setErr(mapErr(t, ke.message)); return; }
    setErr("");
    if (kanal?.channel_id && onOpenChat) onOpenChat(kanal.channel_id, peerName);
  }

  // ════════════════════════════════════════════════════════════════════
  // 🔴 v2.95 (Gökberk madde 8) — "SEYAHAT EKLE" ARTIK DOLU GELİYOR.
  // "bağlantılar sayfasından seyahat ekle dediğimde ilgili bilgiler
  //  otomatik dolmuyor. Bunu keşfet ekranındaki seyahat ekle butonları
  //  için yapmıştık. Burada da uygulanmalı."
  //
  // KÖK NEDEN — App.js'te tek bir satır:
  //     Discovery : onAddTrip={(av) => { setPendingReqAvail(av...); ... }}
  //     Meet      : onAddTrip={() => setShowAddVisit(true)}     ← ARGÜMAN YOK
  // Yani ekranın kendisi doğru davranıyordu; ÜST KATMAN veriyi taşımıyordu.
  // Aynı adı taşıyan iki prop, iki farklı sözleşmeye sahipti.
  // 🆕 SINIF: "AYNI ADI TAŞIYAN İKİ PROP FARKLI PARAMETRE ALIYORSA, BİRİ
  // SESSİZCE HİÇBİR ŞEY TAŞIMIYOR DEMEKTİR."
  //
  // İkinci eksik sunucudaydı: `discover_people` ilanın ID'sini veriyor,
  // TARİH ve SAATİNİ vermiyordu — AddVisit'in dolduracağı alanlar tam
  // olarak bunlar. SQL 248 `ilan_ozeti(uuid)` ile o boşluğu kapattı.
  async function seyahatEkle(p) {
    const availId = p && (p.host_avail_id || p.id);
    if (!availId) { if (onAddTrip) onAddTrip(null); return; }
    const { data, error } = await supabase.rpc("ilan_ozeti", { p_avail_id: availId });
    // Özet gelmezse yine de ekranı AÇIYORUZ — boş form, kapalı kapıdan iyidir.
    if (error) { logError("ilan_ozeti", error); if (onAddTrip) onAddTrip(null); return; }
    if (onAddTrip) onAddTrip(data && data.ok ? data : null);
  }

  const uid = session?.user?.id;
  // 🔴 v3.4 — ALT SEKME DURUMU YUKARI TAŞINDI.
  // Başlık bandındaki etiket artık aktif alt sekmeyi yazıyor ("Tanış"ı
  // ikinci kez değil). Başlık `App.js`te çizildiği için durumu orada
  // tutmak zorundayız; burada yalnız okunuyor.
  //
  // Dışarıdan gelmezse eski davranış aynen sürüyor: bileşen tek başına
  // da çalışır (render testleri onu propsuz mount ediyor).
  const [subYerel, setSubYerel] = useState("discover"); // discover | conns | reqs
  const sub = altSekme || subYerel;
  const setSub = (k) => { setSubYerel(k); if (setAltSekme) setAltSekme(k); };
  const [apFilter, setApFilter] = useState(null);   // #39: havalimani filtresi
  const [flightF, setFlightF] = useState("");       // MVP: "Uçuş" filtresi (örn. TK712)
  const [roleF, setRoleF] = useState(null);         // MVP: "Sadece Misafirler" | "Sadece Host'lar"
  const [airports, setAirports] = useState([]);
  // 🔵 `myFlight` KALDIRILDI (v2.99). Aynı uçuş rozeti SQL 070'ten beri
  // sunucudan geliyor (`discover_people.same_flight` + `flight_number`) ve
  // `PersonCard` onu ZATEN çiziyor. İstemcideki ikinci kopya hiç okunmuyordu.
  // İki kaynaklı bir gerçek, er ya da geç iki farklı cevap verir.
  // 3 Eylül — tasarım 05'in üç çipi: Uçuş · Salon · Rota (istemci filtresi)
  const [cipF, setCipF] = useState(null);           // "ucus" | "salon" | "rota" | null
  const [filtersOpenLocal, setFiltersOpenLocal] = useState(false);
  const filtersOpen = filtersOpenProp !== undefined ? filtersOpenProp : filtersOpenLocal;
  const setFiltersOpen = setFiltersOpenProp || setFiltersOpenLocal;
  const [people, setPeople] = useState(null);
  const [conns, setConns] = useState([]);
  const [hostMap, setHostMap] = useState({});   // user_id -> keşif satırı (host bilgisi)
  const [incoming, setIncoming] = useState([]);
  const [giden, setGiden] = useState([]);       // tasarım 13 · GÖNDERDİKLERİN · "Yanıt bekliyor."
  // Sekme rozeti icin bekleyen istek sayisi. Ayri ve KUCUK bir sorgu:
  // sekmenin uzerindeki sayi, sekmeye girmeden gorulmeli.
  const [istekSayisi, setIstekSayisi] = useState(0);
  // 19 Eylül (md.13) — "İstekler" sekmesinin iç sekmesi.
  const [istekSekmesi, setIstekSekmesi] = useState("gelen");
  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("baglanti_istekleri");
      if (error) { logError("baglanti_istekleri_sayaci", error); return; }
      if (!iptal) setIstekSayisi((data || []).filter(x => x.yon === "gelen" && x.durum === "pending").length);
    })();
    return () => { iptal = true; };
  }, [sub]);
  const [target, setTarget] = useState(null);
  // 🔴 23 Eylül — gelen bağlantı isteğine dokunmak ONAYSIZ kabul ediyordu.
  const [gelen, setGelen] = useState(null);   // { rec, p }
  const [intent, setIntent] = useState(null);
  const [intro, setIntro] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    // radarFilter aktifse: yalnizca su an ayni lounge/saat araliginda olanlar
    const peopleQuery = radarFilter
      ? supabase.rpc("lounge_radar_people")
      // 044: p_airport bos birakiliyor -> fonksiyon KENDI aktif seyahatimden
      // havalimani+zamani cikariyor. Once "p_airport: null" geciyorduk ama
      // 024'teki govde parametreyi zaten HIC kullanmiyordu; simdi kullaniyor.
      : supabase.rpc("discover_people", apFilter ? { p_airport: apFilter } : {});
    const [{ data: ppl }, { data: inc }] = await Promise.all([
      peopleQuery,
      supabase.from("connection_requests").select("*").eq("to_id", uid).eq("status", "pending"),
    ]);
    // 🔴 GELEN BAĞLANTI İSTEKLERİ KAYBOLUYORDU (Gökberk madde 1).
    // `inc` yukarıda çekiliyordu ama HİÇ KULLANILMIYORDU: liste yalnız
    // discover_people'dan türetiliyor ve o RPC keşif filtrelerini
    // uyguluyor (seyahat penceresi, görünürlük, kadın güvenlik modu).
    // İsteği gönderen kişi bu filtrelerden birine takılırsa GÖNDERDİĞİ
    // İSTEK DE ORTADAN KAYBOLUYOR — karşı taraf hiç görmüyor.
    //
    // Bu, hafızadaki "türetilmiş liste, filtrelenmiş kaynaktan beslenir"
    // hatasının tekrarı (v1.31'de Bağlantılarım'da yaşanmıştı ve kural
    // yazılmıştı: KALICI İLİŞKİ KALICI SORGUDAN GELİR). Gelen istek de
    // kalıcı bir olaydır; keşif akışına bağlanamaz.
    let all = ppl || [];
    const incoming = inc || [];
    if (incoming.length) {
      const knownIds = new Set(all.map(x => x.user_id));
      const missing = incoming.map(x => x.from_id).filter(id => id && !knownIds.has(id));
      if (missing.length) {
        const [{ data: mp }, { data: mt }] = await Promise.all([
          supabase.from("profiles").select("user_id, name, profession, photo_url").in("user_id", missing),
          supabase.from("trust_scores").select("user_id, score, badge").in("user_id", missing),
        ]);
        const tmap = {}; (mt || []).forEach(x => { tmap[x.user_id] = x; });
        all = all.concat((mp || []).map(p => ({
          user_id: p.user_id,
          name: p.name,
          profession: p.profession,
          photo_url: p.photo_url,
          score: (tmap[p.user_id] || {}).score,
          badge: (tmap[p.user_id] || {}).badge,
          rel: "incoming",
        })));
      }
      // Keşiften gelenlerin ilişkisi de gerçek duruma göre düzeltilir.
      const incFrom = new Set(incoming.map(x => x.from_id));
      all = all.map(x => (incFrom.has(x.user_id) ? { ...x, rel: "incoming" } : x));
    }
    // MVP Bağlantılarım kartında "İstek →" için host bilgisi gerekiyor; keşif
    // RPC'si zaten hesaplıyor (is_hosting/host_avail_id/can_request/req_reason).
    const hm = {}; all.forEach(x => { hm[x.user_id] = x; }); setHostMap(hm);
    // Gorsel-4: gelen istek sahipleri de kesif listesinde "Yanitla" ile gorunur
    const gorunen = all.filter(p => p.rel === "none" || p.rel === "incoming");
    setPeople(gorunen);
    // 4 Eylül — tasarım 05'te "Uçuş" çipi SEÇİLİ açılıyor: aynı uçuştaki
    // insan varsa liste onlarla başlar (en yakın eşleşme); yoksa süzgeç boş
    // bir ekran üretmesin diye seçilmez. Kullanıcı elle değiştirince dokunulmaz.
    setCipF(f => (f === null && gorunen.some(p => p.same_flight) ? "ucus" : f));
    // 🔴 #33 KOK COZUM: Baglantilarim ARTIK discover_people'dan DEGIL —
    // kesif filtreleri (seyahat penceresi/gorunurluk/kadin-guvenlik) kabul
    // edilmis baglantiyi gizleyebiliyordu. Kalici iliski kalici sorgudan gelir:
    try {
      const { data: cr, error: hata4 } = await supabase.from("connection_requests")
        .select("id, from_id, to_id, status")
        .eq("status", "accepted").or(`from_id.eq.${uid},to_id.eq.${uid}`);
        if (hata4) logError("ekranlar_ana.js:1989", hata4);
      const otherIds = [...new Set((cr || []).map(x => x.from_id === uid ? x.to_id : x.from_id))];
      if (otherIds.length) {
        const [{ data: ps }, { data: tss }] = await Promise.all([
          supabase.from("profiles").select("user_id, name, profession, photo_url").in("user_id", otherIds),
          supabase.from("trust_scores").select("user_id, badge").in("user_id", otherIds),
        ]);
        const tb = {}; (tss || []).forEach(x => { tb[x.user_id] = x.badge; });
        setConns((ps || []).map(x => ({ user_id: x.user_id, name: x.name, profession: x.profession,
          photo: x.photo_url, badge: tb[x.user_id], rel: "accepted" })));
      } else setConns([]);
    } catch (e) { setConns(all.filter(p => p.rel === "accepted")); }
    setIncoming(inc || []);
    // GÖNDERDİKLERİN (baglanti_istekleri → yon='giden', durum='pending') ve
    // gelen isteklerin gönderen adları: birbirinden bağımsız, TEK dalga.
    const ids = (inc || []).map(r => r.from_id);
    const [biRes, psRes] = await Promise.all([
      Promise.resolve(supabase.rpc("baglanti_istekleri")).catch(e => ({ data: null, error: e })),
      ids.length ? supabase.from("profiles").select("user_id, name, profession").in("user_id", ids)
                 : Promise.resolve({ data: null, error: null }),
    ]);
    if (biRes.error) logError("baglanti_istekleri", biRes.error);
    setGiden((biRes.data || []).filter(r => r.yon === "giden" && r.durum === "pending"));
    if (ids.length) {
      if (psRes.error) logError("ekranlar_ana.js:2008", psRes.error);
      const ps = psRes.data;
      setIncoming((inc || []).map(r => ({ ...r, _p: (ps || []).find(x => x.user_id === r.from_id) })));
    }
  }, [uid, radarFilter, apFilter]);
  useEffect(() => {
    havalimanlariniGetir().then((data) => setAirports((data || []).map(a => a.code)));
    (async () => {
      const today = yerelGun();
    })();
  }, [uid]);
  useEffect(() => { load(); }, [load]);

  async function send() {
    setErr(""); setBusy(true);
    const { error } = await supabase.rpc("send_connection", {
      p_to: target.user_id, p_intent: intent, p_intro: intro.trim() || null,
    });
    setBusy(false);
    if (error) { const k = "e_" + (error.message||"").split(" ")[0].replace(/[^a-z_]/g,""); return setErr(t[k] || mapErr(t, error.message)); }
    setTarget(null); setIntent(null); setIntro(""); load();
  }
  async function respond(id, action) {
    // SQL imzasi: respond_connection(p_id uuid, p_accept boolean)
    const { error } = await supabase.rpc("respond_connection", {
      p_id: id, p_accept: action === "accept" || action === true,
    });
    if (error) { setErr(mapErr(t, error.message)); return; }
    load();
  }

  // MVP kart yapısı: rozet İSİM ALTINDA pill · host avatarı altın ·
  // ✈ havalimanı + TARİH pill'i · "✦ Ayrıca host'luk yapıyor" satırı.
  // Aynı uçuş şeridi artık p.same_flight + p.flight_number'dan (SQL 070).
  // ══════════════════════════════════════════════════════════════════
  // 🔴 3 EYLÜL — KİŞİ KARTI TASARIM 05 (tanis) ANATOMİSİNDE:
  //   [avatar 46 · mor-gri taş · serif altın harf] [isim 15/600]
  //                                                [TK1979 · IST → AMS  11.5 sessiz]
  //                                                [çip: Aynı uçuş / amaç]      [→]
  // Eskiden: mor kenarlı kart, mor "AYNI UÇUŞTASINIZ" şeridi, rozet pili,
  // meslek, biyografi, teal havalimanı kutusu, sağda 116px'lik düğme
  // sütunu. Tasarımın kartı TEK bir şey söylüyor: bu kişi, bu uçuş,
  // bu niyet — ve sağdaki ok. Eylemler karta dokununca (ok) açılıyor;
  // ikinci eylem (ilana istek) altta küçük altın çip.
  // ══════════════════════════════════════════════════════════════════
  const bolumBaslik = { color: C.goldText, fontSize: FS.micro + 0.5, fontWeight: "700", marginBottom: ARA[10] };
  const PersonCard = ({ p, action, sameFlight, onAc, ikinci }) => {
    const flightTag = sameFlight || (p.same_flight ? p.flight_number : null);
    // tasarım 05: "TK1979 · IST" — tarih yalnız bugünden farklıysa eklenir
    const bugun = yerelGun();
    const dateTxt = p.visit_date && String(p.visit_date).slice(0, 10) !== bugun
      ? fmtLongDate(String(p.visit_date).slice(0, 10), lang) : null;
    const rota = [p.flight_number, p.airport || p.host_airport].filter(Boolean).join(" · ")
      + (dateTxt ? ` · ${dateTxt}` : "");
    // `discover_people.purpose` = visits.purpose (business/connecting/…) —
    // niyet değil. Eski eşleme (coffee/work/wait) hiç tutmuyordu, çip hiç
    // çıkmıyordu. Aynı amaç → "Aynı rota tanışma" (tasarım 05), değilse amacın adı.
    const amac = p.same_purpose ? t.reqTypeRoute
      : (p.purpose ? gorunur((PURPOSES.find(x => x[0] === p.purpose) || [])[1] || null) : null);
    return (
    <TouchableOpacity activeOpacity={0.85} disabled={!onAc && !p.user_id} hitSlop={TAP.slop}
      onPress={onAc || (() => p.user_id && onOpenProfile && onOpenProfile(p.user_id))}
      accessibilityRole="button" accessibilityLabel={p.name || ""}
      style={[S.card, { flexDirection: "row", alignItems: "center" }]}>
      <View style={{ width: 48, height: 48, borderRadius: R.full, backgroundColor: C.avatarBg || C.goldSoft,
                     borderWidth: 1, borderColor: C.line2 || C.line,
                     alignItems: "center", justifyContent: "center", overflow: "hidden", marginRight: ARA[14] }}>
        {p.photo ? <Image source={{ uri: p.photo }} style={{ width: 48, height: 48 }} />
          : <Text style={{ fontSize: FS.title, fontWeight: "600", color: C.goldText, fontFamily: F.serif }}>
              {(p.name || "?").charAt(0).toUpperCase()}</Text>}
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text numberOfLines={1} style={{ fontWeight: "600", color: C.ink, fontSize: FS.lg - 1 }}>{p.name}</Text>
        {/* ══════════════════════════════════════════════════════════
            🔴 13 EYLÜL (Gökberk md.6) — "sadece havalimanı bilgisi biraz
            eksik kalıyor eğer network istiyorsam… varsa meslek bilgisi de
            eklenebilir."
            Eski mantık MESLEĞİ ROTA VARSA GİZLİYORDU (`!rota && …`) —
            yani tam da tanışmaya en yakın kişide (aynı havalimanında,
            aynı gün) meslek hiç görünmüyordu. Sunucu alanı zaten
            döndürüyor (`discover_people.profession`).
            İki satır, ikisi de tek satıra klamplı: taşma yok, kart 16 pt
            uzuyor. Güven rozeti de çip olarak eklendi — "kiminle
            tanışıyorum" sorusunun ikinci yarısı.
            🆕 SINIF: "BİR ALANI 'YER YOK' DİYE GİZLEMEK, EN ÇOK İHTİYAÇ
            DUYULAN SATIRDA GİZLEMEK OLUR — ÖNCE SATIRI AÇ." */}
        {!!p.profession && (
          <Text numberOfLines={1} style={{ color: C.body, fontSize: FS.xs + 1, marginTop: ARA[3] }}>
            {p.profession}
          </Text>
        )}
        {!!rota && <Text numberOfLines={1} style={{ color: C.mutedAA, fontSize: FS.xs + 1, marginTop: ARA[2] }}>{rota}</Text>}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginTop: ARA[8] }}>
          {/* tasarım 05: aynı uçuş = teal ("ok"), amaç = bilgi tonu */}
          {flightTag ? <Cip etiket={t.sameFlight} ton="teal" /> : null}
          {amac ? <Cip etiket={amac} ton="purple" /> : null}
          {/* 5 Eylül (Gökberk: "ilana git düğmesini kaldırdık mı?") — kartta
              düğme yok (tasarım 05); ilanı olan kişi altın çiple işaretlenir,
              kısayol bağlantı sayfasında ("İlanına git"). Host'a gösterilmez. */}
          {p.is_hosting && p.host_avail_id && rol !== "host" ? <Cip etiket={t.meetHasListing} ton="gold" /> : null}
          {p.badge ? <Cip etiket={`• ${badgeLabel(t, p.badge)}${p.score != null ? ` · ${p.score}` : ""}`} ton="notr" /> : null}
          {p.connected ? <Cip etiket={t.connActiveShort} ton="teal" /> : null}
          {p.rel === "pending" ? <Cip etiket={t.connSent} ton="notr" /> : null}
          {ikinci}
        </View>
      </View>
      <View style={{ marginLeft: SP[2] }}>
        {action || <Ikon ad="sag" boy={16} renk={C.goldText} />}
      </View>
    </TouchableOpacity>
    );
  };

  const shownPeople = (people || []).filter(p => {
    if (flightF && String(p.flight_number || "").toUpperCase() !== flightF.trim().toUpperCase()) return false;
    if (roleF === "host" && !p.is_hosting) return false;
    if (roleF === "guest" && p.is_hosting) return false;
    if (cipF === "ucus" && !p.same_flight) return false;
    if (cipF === "salon" && !p.is_hosting) return false;
    if (cipF === "rota" && !(p.same_purpose || p.airport)) return false;
    return true;
  });

  return (
    <Kaydirma {...(bnt ? bnt.scrollProps : null)}
       contentContainerStyle={{ padding: ARA[20], paddingTop: (bnt ? bnt.ustBosluk : 0) + SP[4], paddingBottom: ARA[40] }}>

      {/* Radar filtresi aktifse: bant goster + sifirlama */}
      {!!radarFilter && (
        <View style={{ backgroundColor: C.gece, borderRadius: R.sm, padding: SP[3], marginBottom: ARA[14], flexDirection: "row", alignItems: "center" }}>
          <Ikon ad="radar" boy={22} renk={C.mutedAA} />
          <View style={{ flex: 1 }}>
            <Text style={{ color: C.purpleUst, fontWeight: "700", fontSize: FS.sm }}>{t.radarFilterOn}</Text>
            <Text style={{ color: C.warmGray, fontSize: FS.sm, marginTop: ARA[2] }}>
              {radarFilter.airport} · {String(radarFilter.time_from || "").slice(0, 5)}–{String(radarFilter.time_to || "").slice(0, 5)}
            </Text>
          </View>
          <TouchableOpacity hitSlop={TAP.slop} onPress={onClearRadar}
            style={{ borderWidth: 1, borderColor: C.purple, borderRadius: R.xs, paddingVertical: ARA[6], paddingHorizontal: SP[3] }}>
            <Text style={{ color: C.purpleUst, fontSize: FS.sm, fontWeight: "600" }}>{t.radarClear}</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Filtre butonu artık header'da (App Hdr right slot) — #3 */}

      {/* ══════════════════════════════════════════════════════════════
          🔴 3 EYLÜL — SEKME ÇİZGİSİ GİTTİ, TASARIMIN ÇİP SATIRI GELDİ.
          05_tanis: [Uçuş][Salon][Rota] — üç filtre çipi. Bağlantılar ve
          istekler tasarımda AYRI ekran (13_baglantilar: "Bağlantılarım");
          buraya dördüncü çip olarak girdi ve o görünümü açıyor. O
          görünümdeyken satır [Bağlantılar (n)][İstekler (n)] olur; geri
          ok banttadır (App.js). */}
      {sub === "discover" ? (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[8], marginBottom: ARA[14] }}>
          {[["ucus", t.meetChipFlight], ["salon", t.meetChipLounge], ["rota", t.meetChipRoute]].map(([k, lb]) => (
            <Cip key={k} etiket={lb} secili={cipF === k} onPress={() => setCipF(cipF === k ? null : k)} />
          ))}
        </View>
      ) : null}

      {/* MVP filtre paneli: "YOLCULARI ŞUNA GÖRE BUL" — Havalimanı chip'leri,
          Uçuş girişi ve Sadece Misafirler / Sadece Host'lar seçimi. Canlıda
          yalnız havalimanı şeridi vardı; uçuş ve rol filtreleri hiç yoktu. */}
      {sub === "discover" && filtersOpen && (
        <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: ARA[14], marginBottom: SP[3] }}>
          <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.mutedAA, letterSpacing: 1.5, marginBottom: ARA[10] }}>{t.meetFilterTitle}</Text>
          {airports.length > 0 && (
            <>
              <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.filterAirport}</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: ARA[10] }} contentContainerStyle={{ gap: SP[2] }}>
                {[null, ...airports].map(code => (
                  <Secim key={code || "all"} ton="purple" secili={apFilter === code}
                    etiket={code || t.catAll} onPress={() => setApFilter(code)} />
                ))}
              </ScrollView>
            </>
          )}
          <Text style={{ fontSize: FS.sm, color: C.body, marginBottom: ARA[6] }}>{t.meetFilterFlight}</Text>
          <TextInput style={[S.input, { backgroundColor: C.card, marginBottom: ARA[10] }]} value={flightF}
            onChangeText={x => setFlightF(x.toUpperCase())} placeholder={t.filterFlight} placeholderTextColor={C.mut} autoCapitalize="characters" />
          <View style={{ flexDirection: "row", gap: SP[2] }}>
            {[["guest", t.onlyGuests], ["host", t.onlyHosts]].map(([k, lab]) => {
              const on = roleF === k;
              return (
                <Secim key={k} bicim="segment" dolu ton="purple" secili={on}
                  etiket={lab} onPress={() => setRoleF(on ? null : k)} />
              );
            })}
          </View>
        </View>
      )}

      {sub === "discover" ? (
        people === null ? <Load /> : (
          <>
            {/* 3 Eylül — mor "Havalimanı Yol Arkadaşı Ağı" kutusu kalktı
                (tasarım 05'te yok); metin boş durumda söyleniyor. */}
            {/* 3 Eylül — gelen istekler keşif listesinden çıktı: tasarım 13'te
                (Bağlantılarım → SANA GELENLER) kendi yerleri var. */}
            {/* 🔴 v2.99 — BOŞ DURUM EYLEM ÇAĞIRIYOR AMA DÜĞME VERMİYORDU.
                `meetEmpty` metni "Seyahatini ekle, aynı terminaldeki yolcular
                karşına çıksın" diyor; `onAddTrip` prop'u da BU BİLEŞENE
                GEÇİLİYOR — ama boş durumda kullanılmıyordu. `Discovery`nin
                boş durumu (HaberVer + filtre temizle + seyahat ekle) bunu üç
                ekran ötede DOĞRU yapıyor.
                🆕 SINIF: "EYLEME ÇAĞIRAN BİR BOŞ DURUM, O EYLEMİN DÜĞMESİNİ
                VERMİYORSA ÇAĞRI DEĞİL SİTEMDİR." */}
            {shownPeople.length === 0 ? (
              <View style={S.empty}>
                <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base, textAlign: "center" }}>{t.networkTitle}</Text>
                <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: SP[1], lineHeight: 18 }}>{t.networkDesc}</Text>
                <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: SP[2] }}>{t.meetEmpty}</Text>
                {onAddTrip && (
                  <Btn label={t.addTrip} onPress={() => onAddTrip(null)} a11yLabel={t.addTrip} style={{ marginTop: SP[3], paddingHorizontal: ARA[20] }} />
                )}
              </View>
            )
            : shownPeople.map(p => {
              // Tasarım 05: karta dokunmak = kişiye giden tek yol (ok).
              //   bağlı → sohbet · gelen istek → yanıtla · bekliyor → profil ·
              //   tanımadık → bağlantı kur (not ile).
              const ac = p.rel === "accepted" ? () => openCompanionChat(p.user_id, p.name)
                // 🔴 23 EYLÜL — DOKUNMAK = KABUL ETMEK'Tİ. Tek bir kaçak dokunuş
                // bir yabancıyla bağlantı ve sohbet açıyordu; notunu bile görmeden.
                // P2P bir buluşma ürününde "kiminle bağlandım" sorusu geri
                // alınamaz bir eylemin arkasında kalamaz. Artık yanıt sayfası:
                // not + profili gör + Kabul et / Reddet.
                // 🆕 SINIF: "GERİ ALINAMAYAN BİR EYLEM, BİR GEZİNTİ
                // DOKUNUŞUNUN ARKASINA SAKLANAMAZ."
                : p.rel === "incoming" ? () => { const rec = incoming.find(x => x.from_id === p.user_id); if (rec) { setErr(""); setGelen({ rec, p }); } }
                : p.rel === "pending" ? () => p.user_id && onOpenProfile && onOpenProfile(p.user_id)
                : () => { setTarget(p); setErr(""); };
              // Tasarım 05: kartta eylem çipi yok; ilana istek bağlantı
              // sayfasındaki "İlanına git" kısayolundan (Keşfet'e odaklı).
              const ikinci = null;
              return <PersonCard key={p.user_id} p={p} onAc={ac} ikinci={ikinci} />;
            })}
            {/* TASARIM 05 · alt kart: "Host olsam ne kazanırım?" — misafire host
                daveti (altın zemin). 🔴 5 Eylül — HOST'A DA ÇIKIYORDU (Gökberk:
                "host olmama rağmen host olsam ne kazanırım geliyor"): koşul
                `onRequestListing` idi, rol değil. Yalnız host olmayana. */}
            {onRequestListing && rol !== "host" ? (
              <View style={{ backgroundColor: C.goldBg, borderRadius: R.lg, padding: SP[4], marginTop: ARA[8] }}>
                <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.base }}>{t.calmBecomeHost}</Text>
                <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>{t.hostOnlyBody}</Text>
              </View>
            ) : null}
          </>
        )
      ) : (
        /* ══════════════════════════════════════════════════════════════
           🔴 3 EYLÜL — TASARIM 13 · "Bağlantılarım":
             SANA GELENLER   → bekleyen gelen istekler · çip "Kabul et" (teal)
             GÖNDERDİKLERİN  → bağlı olduklarım · çip "Bağlısınız" (teal)
                               (bekleyen gidenler "İstekler" çipinde: durum
                                bilgisi orada tam — kim, ne zaman, iptal)
           Kart: avatar · isim · "Profili görüntüle" · çip. Karta dokunmak
           bağlıysa sohbeti, değilse profili açar.
           ══════════════════════════════════════════════════════════════ */
        /* ══════════════════════════════════════════════════════════════
           🔴 19 EYLÜL (Gökberk md.13 · ONAYLANDI) — İKİ AYRI ŞEY, İKİ
           AYRI SEKME.
           Eski hâl: kurulmuş bir BAĞLANTI ile cevap bekleyen bir İSTEK
           aynı listede, yalnız rozetiyle ayrılıyordu ve ikisi birden
           "GÖNDERDİKLERİN" başlığının altındaydı — ki gelen istekler
           gönderdiklerim değil.
           "Kiminle konuşabilirim?" sorusu taranarak cevaplanıyordu.
           Şimdi: `conns` → Bağlantılarım · `incoming`/`giden` → İstekler.
           🆕 SINIF: "İKİ FARKLI HAYAT DÖNGÜSÜ OLAN KAYIT AYNI LİSTEDE
           DURUYORSA, ROZET EKLEMEK AYIRMAZ — YALNIZ AYIRDIĞINI SANDIRIR."
           ══════════════════════════════════════════════════════════════ */
        sub === "reqs" ? (
          (incoming.length === 0 && giden.length === 0) ? (
            <View style={S.empty}>
              <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center" }}>{t.connReqEmpty}</Text>
              {setSub ? (
                <Btn label={t.meetTitle} onPress={() => setSub("discover")} a11yLabel={t.calmFind} style={{ marginTop: SP[3], paddingHorizontal: ARA[20] }} />
              ) : null}
            </View>
          ) : (
            <>
              {/* İç sekmeler: gelen / gönderilen. Sayılar çipin üstünde —
                  hangi tarafta iş olduğu sekmeye girmeden görünmeli. */}
              <View style={{ flexDirection: "row", gap: ARA[8], marginBottom: SP[3] }}>
                {[["gelen", t.connIncomingTitle, incoming.length],
                  ["giden", t.connSentTitle, giden.length]].map(([k, lb, n]) => (
                  <Cip key={k} etiket={n > 0 ? `${lb} · ${n}` : lb}
                       a11yLabel={`${lb} · ${n}`}
                       secili={istekSekmesi === k} onPress={() => setIstekSekmesi(k)} />
                ))}
              </View>
              {istekSekmesi === "gelen" ? (
                incoming.length === 0 ? (
                  <View style={S.empty}><Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center" }}>{t.connIncomingEmpty}</Text></View>
                ) : incoming.map(r => (
                  <PersonCard key={r.id}
                    p={{ user_id: r.from_id, name: r._p?.name || "—", profession: t.ccViewProfile }}
                    onAc={() => r.from_id && onOpenProfile && onOpenProfile(r.from_id)}
                    ikinci={<Cip etiket={t.accept} ton="teal" onPress={() => respond(r.id, "accept")} />}
                    action={<View />} />
                ))
              ) : (
                giden.length === 0 ? (
                  <View style={S.empty}><Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center" }}>{t.connSentEmpty}</Text></View>
                ) : giden.map(r => (
                  <PersonCard key={"g" + r.id}
                    p={{ user_id: r.peer_id, name: r.peer_name || "—", profession: t.ccViewProfile, photo: r.peer_photo }}
                    onAc={() => r.peer_id && onOpenProfile && onOpenProfile(r.peer_id)}
                    ikinci={<Cip etiket={t.connAwaiting} ton="amber" />}
                    action={<View />} />
                ))
              )}
            </>
          )
        ) : conns.length === 0 ? (
          <View style={S.empty}>
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center" }}>{t.connEmpty}</Text>
            {/* Bekleyen isteği varsa boş durum onu SÖYLER ve oraya götürür:
                "hiç bağlantın yok" derken üç isteğinin beklediğini
                söylememek, boş durumu bir yalana çevirirdi. */}
            {(incoming.length > 0 || giden.length > 0) && setSub ? (
              <Btn v="ghost" label={String(t.connGoRequests || "").replace("{n}", String(incoming.length + giden.length))}
                onPress={() => setSub("reqs")} style={{ marginTop: SP[3], paddingHorizontal: ARA[20] }} />
            ) : null}
            {onRequestListing || setSub ? (
              <Btn label={t.meetTitle} onPress={() => setSub("discover")} a11yLabel={t.calmFind} style={{ marginTop: SP[3], paddingHorizontal: ARA[20] }} />
            ) : null}
          </View>
        ) : (
          <>
            {conns.map(p => {
              const h = hostMap[p.user_id] || {};
              return (
                <PersonCard key={p.user_id} p={{ ...p, ...h, profession: t.ccViewProfile, airport: null, flight_number: null, visit_date: null }}
                  onAc={() => openCompanionChat(p.user_id, p.name)}
                  ikinci={<Cip etiket={t.connActive} ton="teal" />} action={<View />} />
              );
            })}
            <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[12], lineHeight: 16 }}>{t.connSub}</Text>
          </>
        )
      )}

      <Modal visible={!!gelen} transparent animationType="fade" onRequestClose={() => setGelen(null)}>
        <View style={{ flex: 1, backgroundColor: C.perde, justifyContent: "flex-end" }}>
          <View style={{ backgroundColor: C.card, borderTopLeftRadius: R.lg, borderTopRightRadius: R.lg, padding: SP[4], paddingBottom: ARA[30] }}>
            <Text style={{ color: C.mut, fontSize: FS.xs, fontWeight: "700", letterSpacing: 1 }}>{BUYUK(t.connIncomingTitle)}</Text>
            <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.lg, marginTop: SP[1] }}>{abbrevName(gelen?.p?.name)}</Text>
            {!!gelen?.p?.profession && <Text style={{ color: C.mut, fontSize: FS.sm }}>{gelen.p.profession}</Text>}
            <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[3], marginTop: SP[3] }}>
              <Text style={{ color: gelen?.rec?.intro ? C.ink : C.mut, fontSize: FS.sm, lineHeight: 19 }}>
                {gelen?.rec?.intro ? `“${gelen.rec.intro}”` : t.connIncomingNoNote}</Text>
            </View>
            {onOpenProfile && gelen?.p?.user_id && (
              <TouchableOpacity hitSlop={TAP.slop} accessibilityRole="button" accessibilityLabel={t.viewProfile}
                onPress={() => { const id = gelen.p.user_id; setGelen(null); onOpenProfile(id); }}
                style={{ paddingVertical: SP[3], minHeight: TAP.minHeight, justifyContent: "center" }}>
                <IkonMetin sag ad="sag" renk={C.purple} stilMetin={{ color: C.purple, fontWeight: "700", fontSize: FS.sm }} metin={t.viewProfile} />
              </TouchableOpacity>
            )}
            {!!err && <Text style={{ color: C.red, fontSize: FS.sm, marginBottom: SP[2] }}>{err}</Text>}
            <Btn v="teal" label={t.accept} a11yLabel={t.accept}
              onPress={async () => { const id = gelen.rec.id; setGelen(null); await respond(id, true); }} />
            <Btn v="ghost" label={t.decline} a11yLabel={t.decline} style={{ marginTop: ARA[10] }}
              onPress={async () => { const id = gelen.rec.id; setGelen(null); await respond(id, false); }} />
          </View>
        </View>
      </Modal>
      <Modal visible={!!target} animationType="slide" onRequestClose={() => setTarget(null)}>
        {/* #31: MVP Baglanti Kur — tam ekran */}
        <Sayfa>
          <Hdr t={t} ustBilgi={t.sceneConnect} title={`${t.connTitle}: ${abbrevName(target?.name)}`} onBack={() => setTarget(null)} />
          <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[34] }}>
            <View style={[S.card, { flexDirection: "row", alignItems: "center" }]}>
              <View style={{ width: 46, height: 46, borderRadius: R.full, backgroundColor: C.purpleBg, alignItems: "center", justifyContent: "center", marginRight: SP[3], overflow: "hidden" }}>
                {target?.photo ? <Image source={{ uri: target.photo }} style={{ width: 46, height: 46 }} />
                  : <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.purpleInk, fontFamily: F.serif }}>{(target?.name || "?").charAt(0).toUpperCase()}</Text>}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.lg }}>{abbrevName(target?.name)}</Text>
                {!!target?.badge && <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>• {badgeLabel(t, target.badge)}</Text>}
                {!!target?.profession && <Text style={{ color: C.mut, fontSize: FS.sm }}>{target.profession}</Text>}
              </View>
              {onOpenProfile && target?.user_id && (
                <TouchableOpacity hitSlop={TAP.slop} onPress={() => { const id = target.user_id; setTarget(null); onOpenProfile(id); }}>
                  <IkonMetin sag ad="sag" renk={C.purple} stilMetin={{ color: C.purple, fontWeight: "700", fontSize: FS.sm }} metin={t.viewProfile} />
                </TouchableOpacity>
              )}
            </View>

            {/* 5 Eylül — "İLANA GİT" GERİ GELDİ, AMA KARTTA DEĞİL BURADA:
                kişinin açık ilanı varsa bağlantı isteğinin yanında salon
                isteği yolu da görünür (Keşfet'e odaklı açılır). Yalnız host
                olmayana; ilanı kapalıysa satır yok. */}
            {target?.is_hosting && target?.host_avail_id && onRequestListing && rol !== "host" ? (
              <TouchableOpacity hitSlop={TAP.slop} accessibilityRole="button" accessibilityLabel={t.meetGoListing}
                onPress={() => { const tg = target; setTarget(null);
                                 onRequestListing({ id: tg.host_avail_id, host_id: tg.user_id, airport_code: tg.host_airport || tg.airport }); }}
                style={[S.card, { borderColor: C.goldTrace, flexDirection: "row", alignItems: "center", minHeight: TAP.minHeight }]}>
                <Ikon ad="salon" boy={18} renk={C.goldText} />
                <View style={{ flex: 1, marginLeft: ARA[10] }}>
                  <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm }}>{t.meetGoListing}</Text>
                  <Text style={{ color: C.mutedAA, fontSize: FS.xs + 1, marginTop: ARA[2] }}>
                    {String(t.meetGoListingSub || "").replace("{ap}", target.host_airport || target.airport || "")}
                  </Text>
                </View>
                <Ikon ad="sag" boy={16} renk={C.goldText} />
              </TouchableOpacity>
            ) : null}
            <View style={{ backgroundColor: C.purpleBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.sm, padding: SP[3], marginBottom: ARA[14] }}>
              <Text style={{ color: C.purpleInk, fontWeight: "700", fontSize: FS.sm }}>{t.connBoxTitle}</Text>
              <Text style={{ color: C.body, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{t.connBoxBody}</Text>
            </View>

            <Text style={S.label}>{t.connIntent}</Text>
            {/* 🔴 v3.6 — ETİKETİN İÇİNDEKİ EMOJİ, ETİKETİN YANINDAKİ İKON OLDU.
                `t.intCoffee + " ☕"` deseni iki şeyi birden bozuyordu: (a) ☕
                Archivo'da yok, sessizce sistem emoji fontuna düşüyor ve satırın
                dikey ölçüsünü bozuyor; (b) çeviri dizgesine görsel gömmek,
                çevirmenin ikonu da çevirmesini bekler.
                🆕 SINIF: "BİR İKONU METNİN İÇİNE GÖMERSEN, O İKON ARTIK
                TASARIMIN DEĞİL SÖZLÜĞÜN PARÇASIDIR." */}
            {[["coffee", t.intCoffee, "olanakKahve"], ["networking", t.intNetwork, "is"], ["route", t.intRoute, "ucus"], ["hello", t.intHello, "selam"]].map(([k, lb, ik]) => (
              <Secim key={k} bicim="radyo" ton="purple" zemin="alt" secili={intent === k}
                etiket={lb} onPress={() => setIntent(k)} stil={{ marginBottom: SP[2] }}
                ikon={<Ikon ad={ik} boy={16} renk={intent === k ? C.purple : C.mutedAA} />} />
            ))}

            <Text style={S.label}>{t.connIntro}</Text>
            <TextInput style={[S.input, { minHeight: 80 }]} value={intro} onChangeText={x => setIntro(x.slice(0, 140))} multiline placeholder={t.connIntroPh} placeholderTextColor={C.dim} />

            {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
            <Btn v="purple" label={t.connSend} sagAd="sag" a11yLabel={t.connSend} onPress={send}
              disabled={busy || !intent} busy={busy} style={{ marginTop: SP[3] }} />
          </ScrollView>
        </Sayfa>
      </Modal>
    </Kaydirma>
  );
}
export function PublicProfile({ t, session, targetId, onBack, onOpenChat, onReport }) {
  const uid = session?.user?.id;
  const [d, setD] = useState(null);
  const [rel, setRel] = useState("none");
  // 🔴 30 Ağu · 7. tur — BAĞLANTIYI KALDIRMA (SQL 277).
  const [connId, setConnId] = useState(null);
  const [kaldirOnay, setKaldirOnay] = useState(false);
  const [kaldirBusy, setKaldirBusy] = useState(false);
  // 🔴 `ppRemoveDone`u yazıp ÇİZMEMİŞTİM; `olu_metin_check` yakaladı.
  // Sessizce başarılı olan yıkıcı bir eylem, kullanıcıyı "oldu mu?"
  // diye bırakır — ve o kişi aynı düğmeye bir daha basar.
  // 🆕 SINIF: "GERİ ALINAMAZ BİR EYLEMİN SONUCUNU SÖYLEMEYEN ARAYÜZ,
  // O EYLEMİ İKİ KEZ YAPTIRIR."
  const [kaldirildi, setKaldirildi] = useState(false);
  const [err, setErr] = useState("");
  // 🔴 BU HOOK'LAR ERKEN RETURN'UN ÜSTÜNDE OLMAK ZORUNDA.
  // Altına konduğunda ilk render'da (d null iken) hiç çalışmıyor, veri
  // gelince çalışıyor → React "Rendered more hooks than during the previous
  // render" hatası → BEYAZ EKRAN. Profil resmine tıklayınca çökmenin sebebi buydu.
  const [connOpen, setConnOpen] = useState(false);
  const [connIntro, setConnIntro] = useState("");
  const [connBusy, setConnBusy] = useState(false);
  const [connIntent, setConnIntent] = useState("coffee");   // MVP: NE ARIYORSUN
  const [myScore, setMyScore] = useState(0);
  const [ppSessions, setPpSessions] = useState(null);  // MVP: "Oturum" satırı   // "Trusted+" gorunurlugu icin kendi guven puanim

  useEffect(() => {
    (async () => {
      // 🔴 23 EYLÜL — BAŞKASININ ROZETLERİ HİÇ GÖRÜNMÜYORDU.
      // `users` ve `verifications` RLS'i yalnız KENDİ satırını gösteriyor
      // (`users_own`, `verif_own`). Başka birinin profilinde bu iki sorgu
      // her zaman BOŞ dönüyordu: telefon/kimlik/e-posta rozetleri, "doğrulanmış
      // kadın" ve host rengi hiç çizilmiyordu — hata da vermeden.
      // Artık dar bir kart: `profil_karti` (SQL 300 §A5) — yalnız evet/hayır
      // bayrakları, ham iletişim ya da cinsiyet YOK.
      const [{ data: p }, { data: ts }, { data: kart, error: eKart }, { data: cr }] = await Promise.all([
        supabase.from("profiles").select("*").eq("user_id", targetId).maybeSingle(),
        supabase.from("trust_scores").select("*").eq("user_id", targetId).maybeSingle(),
        supabase.rpc("profil_karti", { p_user: targetId }),
        supabase.from("connection_requests").select("id, status, from_id, to_id")
          .or(`and(from_id.eq.${uid},to_id.eq.${targetId}),and(from_id.eq.${targetId},to_id.eq.${uid})`).maybeSingle(),
      ]);
      if (eKart) logError("profil_karti", eKart);
      let r = "none";
      if (cr) r = cr.status === "accepted" ? "connected" : (cr.from_id === uid ? "sent" : "incoming");
      setRel(r);
      setConnId(cr ? cr.id : null);
      setD({ ...(p || {}), ...(ts || {}), role: kart?.role, gender: kart?.kadin ? "female" : null,
        phone_verified: !!kart?.phone_verified, id_verified: !!kart?.id_verified,
        email_verified: !!kart?.email_verified });
      // 🔴 v3.9 — İKİ TUR DAHA VARDI VE İKİSİ DE HİÇBİR ŞEYİ BEKLEMİYORDU.
      // Yukarıdaki 5'li dalga bittikten SONRA sırayla kendi puanım ve
      // oturum sayısı okunuyordu; ikisi de yalnız `uid`/`targetId` ile
      // parametreli. Tek dalga.
      // `sessions` kendi `try`si içindeydi (düşerse "—" gösteriliyordu);
      // o tolerans `.catch(() => null)` ile TAŞINDI, kaybolmadı.
      const { data: mine, error: eMine } = await supabase.from("trust_scores").select("score").eq("user_id", uid).maybeSingle();
      if (eMine) logError("pp_kendi_guven", eMine);
      setMyScore(mine?.score ?? 0);
      // "Oturum N": eskiden RLS yüzünden yalnız İKİNİZİN ortak oturumlarını
      // sayıyordu. Sayı artık karttan (sunucu, kişinin tüm tamamlanmış oturumları).
      setPpSessions(kart && typeof kart.oturum === "number" ? kart.oturum : null);
    })();
  }, [targetId, uid]);

  if (!d) return <Load t={t} title={t.ccViewProfile} onBack={onBack} />;
  const connected = rel === "connected";
  const accent = d.role === "host" ? C.gold : C.teal;
  const canSeePhoto = d.photo_url && (!d.photo_connections_only || connected);
  // 🔴 "Trusted+" = GÜVENİLİR KULLANICILARA AÇIK demek; herkese kapalı demek
  // değil. Eski kod yalnızca "Everyone"ı açıyordu ve varsayılan "Trusted+"
  // olduğu için neredeyse HER profil boş görünüyordu (MVP'de zengin görünür).
  const showFull = connected
    || d.profile_visibility === "Everyone"
    || (d.profile_visibility === "Trusted+" && myScore >= 55);
  const firstName = (d.name || "").split(" ")[0];

  // 🔴 Canlı APP 16: profilden "Bağlan" hiçbir sayfa açmadan sessizce
  // boş bir istek gönderiyordu (intro yok, hata mesajı ham). MVP'de bağlantı
  // daveti NOT ile gönderilir. Artık modal açılıyor.
  async function doConnect() {
    setErr(""); setConnBusy(true);
    const { error } = await supabase.rpc("send_connection", {
      p_to: targetId, p_intent: connIntent, p_intro: connIntro.trim() || null });
    setConnBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    setConnOpen(false); setConnIntro("");
    setRel("sent");
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneProfile} title={t.ppTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <View style={[S.card, { alignItems: "center" }]}>
          <View style={{ width: 72, height: 72, borderRadius: R.full, backgroundColor: canSeePhoto ? "transparent" : C.goldSoft, alignItems: "center", justifyContent: "center", overflow: "hidden", marginBottom: ARA[10] }}>
            {canSeePhoto ? <Image source={{ uri: d.photo_url }} style={{ width: 72, height: 72 }} />
              : <Text style={{ fontSize: FS.display, fontFamily: F.serif, fontWeight: "700", color: accent }}>{(d.name || "?").charAt(0).toUpperCase()}</Text>}
          </View>
          <Text style={{ fontSize: FS.title, fontWeight: "700", color: C.ink }}>{d.name}</Text>
          <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[2] }}>
            {d.profession || "Traveler"}{d.gender === "female" && d.women_safety_mode ? `  ·  ${t.ppVerifiedWoman}` : ""}
          </Text>
          <View style={{ flexDirection: "row", gap: ARA[6], marginTop: SP[2], flexWrap: "wrap", justifyContent: "center" }}>
            {/* 🔴 v6.1 (Gökberk md.17 · md.35) — rozet ham koddu ("verified")
                ve üç rozet üç ayrı çerçeve dilindeydi. Artık tek dil: v6
                fildişi mühür (`ToneBadge`), metin `badgeLabel`dan. Kurucu
                Host rozeti ilk kez burada — "profilinde görünür" deniyordu
                ama hiçbir ekran çizmiyordu. */}
            {d.founding_host_no ? (
              <ToneBadge tone="cost">{String(t.foundingBadge || "Kurucu Host #{n}").replace("{n}", String(d.founding_host_no))}</ToneBadge>
            ) : null}
            <ToneBadge tone="info">{badgeLabel(t, d.badge)}</ToneBadge>
            {(d.email_verified || d.phone_verified) ? (
              <ToneBadge tone="ok">{d.email_verified ? t.ppEmailOk : t.ppPhoneOk}</ToneBadge>
            ) : null}
            {d.id_verified ? <ToneBadge tone="ok">{t.ppIdOk}</ToneBadge> : null}
          </View>
        </View>

        {/* Güven skoru */}
        <View style={[S.card, { flexDirection: "row", alignItems: "center", gap: ARA[14] }]}>
          <View style={{ width: 64, height: 64, borderRadius: R.xl, borderWidth: 3, borderColor: accent, alignItems: "center", justifyContent: "center" }}>
            <Text style={{ fontSize: FS.title, fontWeight: "700", color: accent }}>{d.score ?? 45}</Text>
            {/* 🔴 7.5 piksel OKUNMUYOR. Olcek denetimi bunu yakaladi ve hakliydi:
                halkanin icine sigsin diye kucultmusum ama sigmasi okunmasindan
                onemli degil. Etiket halkanin ALTINA cikti, olcek boyutunda. */}
            <Text style={{ fontSize: FS.micro, color: C.mutedAA, letterSpacing: 0.5 }}>{t.trustRingLabel}</Text>
          </View>
          <View style={{ flex: 1 }}>
            {/* MVP: Oturum · Puan · Üyelik seviyesi */}
            <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: SP[1] }}>
              <Text style={{ fontSize: FS.sm, color: C.mut }}>{t.ppSessions}</Text>
              <Text style={{ fontSize: FS.sm, color: C.ink, fontWeight: "700" }}>{ppSessions == null ? "—" : ppSessions}</Text>
            </View>
            <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: SP[1] }}>
              <Text style={{ fontSize: FS.sm, color: C.mut }}>{t.trust}</Text>
              <Text style={{ fontSize: FS.sm, color: C.ink, fontWeight: "700" }}>{d.score ?? 0}/100</Text>
            </View>
            <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
              <Text style={{ fontSize: FS.sm, color: C.mut }}>{t.ppTier}</Text>
              <Text style={{ fontSize: FS.sm, color: accent, fontWeight: "700" }}>{badgeLabel(t, d.badge)}</Text>
            </View>
          </View>
        </View>

        {/* Bio + diller (bağlı değilse kilitli) */}
        {showFull ? (
          <>
            {!!d.bio && <View style={S.card}><Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mut, letterSpacing: 1.5, marginBottom: ARA[6] }}>{t.ppAbout}</Text><Text style={{ fontSize: FS.sm, color: C.ink, lineHeight: 20 }}>{d.bio}</Text></View>}
            {(d.languages?.length > 0) && <View style={S.card}><Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mut, letterSpacing: 1.5, marginBottom: SP[2] }}>{t.ppLangs}</Text><View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6] }}>{d.languages.map(l => <View key={l} style={S.chip}><Text style={{ fontSize: FS.xs, color: C.ink }}>{gorunur(l)}</Text></View>)}</View></View>}
          </>
        ) : (
          <View style={[S.card, { alignItems: "center", padding: ARA[18] }]}>
            <Ikon ad="kilit" boy={22} renk={C.mutedAA} />
            <Text style={{ fontSize: FS.sm, color: C.mut, textAlign: "center", lineHeight: 19 }}>{firstName} {t.ppLocked}</Text>
            {/* MVP: kilit kutusunun İÇİNDE doğrudan "Bağla →" çıkışı */}
            {/* 🔴 v1.75 (Gokberk): kilit kutusundaki "Bağla" düğmesi KALDIRILDI —
                sayfanın altındaki "Bağlantı Kur" ile birebir aynı işi yapıyordu,
                iki buton kullanıcıda "ikisi farklı mı?" tereddüdü yaratıyordu.
                Açıklama metni (kilit ikonuyla) duruyor; aksiyon tek yerde. */}
          </View>
        )}

        {/* Aksiyon */}
        {targetId !== uid && (
          rel === "connected" ? (
            <>
              <Btn label={t.ppMessage} onPress={() => onOpenChat && onOpenChat(targetId, d.name)} />
              {/* ══════════════════════════════════════════════════════
                  🔴 30 AĞUSTOS · 7. TUR — ÇIKIŞ YOLU EKLENDİ.

                  Gökberk: "kullanıcı bağlantı kurabiliyor ancak rahatsız
                  olduğu bir bağlantıyı kaldırabilmeli de."

                  Ölçtüm: `connection_requests` üstünde beş sunucu
                  fonksiyonu var ve hiçbiri geri almıyordu. Yani ürün
                  bir ilişkiyi KURMAYI biliyor, BİTİRMEYİ bilmiyordu —
                  ve rahatsız olan kişinin elindeki tek araç "rapor
                  et"ti. Yani geri çekilmek için önce SUÇLAMAK
                  gerekiyordu.

                  🆕 SINIF: "BİR İLİŞKİYİ KURAN HER ÜRÜN ONU BİTİRMEYİ
                  DE SUNMAK ZORUNDADIR — ÇIKIŞI OLMAYAN BİR BAĞ, BAĞ
                  DEĞİL TUZAKTIR."

                  `ghost` varyant: yıkıcı ama SUÇLAYICI DEĞİL. Kırmızı
                  bir düğme bunu bir şikâyet gibi gösterirdi; kaldırmak
                  sessiz bir karardır. Rapor yolu ayrı ve ayrı renkte.
                  ══════════════════════════════════════════════════════ */}
              <Btn v="ghost" sm label={t.ppRemoveConn} solAd="kapat"
                style={{ marginTop: ARA[10] }}
                onPress={() => setKaldirOnay(true)} />
            </>
          )
          : rel === "sent" ? <View style={{ padding: SP[3], backgroundColor: C.warmBlock2, borderRadius: R.sm, alignItems: "center" }}><Text style={{ color: C.mut, fontSize: FS.sm }}>{t.ppPending}</Text></View>
          : rel === "incoming" ? <View style={{ padding: SP[3], backgroundColor: C.goldSoft, borderRadius: R.sm, alignItems: "center" }}><Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>{t.ppRespond}</Text></View>
          : <Btn label={`${t.ppConnect}`} sagAd="sag" onPress={() => setConnOpen(true)} />
        )}
        {kaldirildi && (
          <View style={{ marginTop: ARA[10], padding: SP[3], borderRadius: R.sm,
                         backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent" }}>
            <Text style={{ color: C.tealInk, fontSize: FS.sm, fontWeight: "600", textAlign: "center" }}>
              {t.ppRemoveDone}</Text>
          </View>
        )}
        {!!err && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
        {/* Kaldırma ONAYI — geri alınamaz bir eylem tek dokunuşla olmaz.
            Metin ne olacağını TAM söylüyor: sohbet kapanır, karşı taraf
            BİLDİRİM ALMAZ, sonra yeniden bağlanılabilir. */}
        <Modal visible={kaldirOnay} transparent animationType="fade"
               onRequestClose={() => setKaldirOnay(false)}>
          <View style={{ flex: 1, justifyContent: "center", padding: ARA[30] }}>
            <PerdeBulanik />
            <View style={{ ...POPUP_YUZEY(), borderRadius: R.md, padding: ARA[22],
                           borderWidth: 1, borderColor: C.line, ...ELEV.card }}>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink }}>{t.ppRemoveTitle}</Text>
              <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[2], lineHeight: 20 }}>
                {String(t.ppRemoveBody || "").replace("{ad}", shortName(d.name) || "")}
              </Text>
              <Btn v="redSoft" label={t.ppRemoveYes} busy={kaldirBusy}
                style={{ marginTop: SP[4] }}
                onPress={async () => {
                  if (!connId) { setKaldirOnay(false); return; }
                  setKaldirBusy(true); setErr("");
                  const { error } = await supabase.rpc("baglanti_kaldir", { p_conn_id: connId });
                  setKaldirBusy(false); setKaldirOnay(false);
                  if (error) { logError("baglanti_kaldir", error); setErr(mapErr(t, error.message)); return; }
                  setRel("none"); setConnId(null); setKaldirildi(true);
                }} />
              <Btn v="ghost" label={t.cancelNo} style={{ marginTop: SP[2] }}
                onPress={() => setKaldirOnay(false)} />
            </View>
          </View>
        </Modal>

        {/* MVP: bağlantı daveti NOT ile gönderilir */}
        <Modal visible={connOpen} animationType="slide" transparent onRequestClose={() => setConnOpen(false)}>
          <View style={{ flex: 1, justifyContent: "flex-end" }}>
            <PerdeBulanik />
            <View style={{ ...POPUP_YUZEY(), borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: ARA[18] }}>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[1] }}>
                {t.connTitle}: {shortName(d.name)}
              </Text>
              <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[3] }}>{t.connSub}</Text>
              {/* MVP: "NE ARIYORSUN" — 4 niyet seçeneği. Canlıda hiç yoktu,
                  bağlantı isteği niyetsiz gidiyordu. */}
              <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.mut, letterSpacing: 1.2, marginBottom: SP[2] }}>{t.connWhat}</Text>
              {[["coffee", t.ciCoffee], ["networking", t.ciWork], ["route", t.ciRoute], ["hello", t.ciHello]].map(([k, lab]) => {
                const sel = connIntent === k;
                return (
                  <TouchableOpacity hitSlop={TAP.slop} key={k} onPress={() => setConnIntent(k)}
                    style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], borderRadius: R.xs, borderWidth: 1.5, marginBottom: SP[2],
                             borderColor: sel ? C.purple : C.line, backgroundColor: sel ? C.purpleBg : C.bgAlt }}>
                    <Text style={{ fontSize: FS.sm, color: sel ? C.purple : C.body, fontWeight: sel ? "700" : "400" }}>{lab}</Text>
                  </TouchableOpacity>
                );
              })}
              <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.mut, letterSpacing: 1.2, marginTop: SP[1], marginBottom: ARA[6] }}>{t.connIntroLabel}</Text>
              <TextInput style={[S.input, { minHeight: 76, textAlignVertical: "top" }]}
                value={connIntro} onChangeText={x => setConnIntro(x.slice(0, 140))} multiline
                placeholder={t.connPh} placeholderTextColor={C.dim} />
              <Text style={{ color: C.dim, fontSize: FS.xs, textAlign: "right", marginTop: SP[1] }}>{connIntro.length}/140</Text>
              <Btn label={`${t.connSend}`} sagAd="sag" onPress={doConnect} disabled={connBusy} busy={connBusy} style={{ marginTop: ARA[10] }} />
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => setConnOpen(false)} style={{ alignItems: "center", paddingVertical: SP[3] }}>
                <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.cancel}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>
        {targetId !== uid && onReport && (
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => onReport(targetId, d.name)} style={{ alignSelf: "center", marginTop: SP[4], padding: SP[2] }}>
            <Text style={{ color: C.mut, fontSize: FS.sm, textDecorationLine: "underline" }}>{t.ppReport}</Text>
          </TouchableOpacity>
        )}
      </ScrollView>
    </Sayfa>
  );
}

// ============ PhoneGate kartı (§6) ============
export function PhoneGate({ t, onVerify }) {
  return (
    <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.sm, padding: ARA[14], marginVertical: SP[2] }}>
      <IkonMetin ad="uyari" boy={15} renk={C.amberInk} metin={t.phoneGate}
        stilMetin={{ color: C.amberInk, fontWeight: "700", fontSize: FS.base }} />
      <Text style={{ color: C.amberInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{t.phoneGateBody}</Text>
      {/* 🔴 v3.4 — `C.amber` + beyaz = 3.19:1, AA'nın altı. `C.amberBtn`
          bu iş için ölçülmüş zemin: beyazla 4.84:1. Sinyal rengi bir
          İŞARET rengidir; üstünde metin taşıyan bir yüzeyin zemini olmak
          için ayarlanmamıştır (theme.js §v3.1'in dersi). */}
      {/* Uyarı düğmesi kehribar: bu bir eylem çağrısı DEĞİL, bir engelin
          kaldırılması. `Btn`in `gold` geometrisini alıyor, rengini
          bağlamdan — iki karar değil, bir karar + bir üstü yazma. */}
      <Btn v="gold" sm label={t.verifyNow} onPress={onVerify}
        style={{ marginTop: ARA[10], backgroundColor: C.amberBtn, borderColor: C.amberBtn }} />
    </View>
  );
}

// ============ CompanionChat (§17) ============
export function CompanionChat({ t, session, channelId, otherName, onBack, onOpenProfile, onReport }) {
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      if (onBack) { onBack(); return true; }
      return false;
    });
    return () => h.remove();
  }, [onBack]);
  const uid = session?.user?.id;
  const [msgs, setMsgs] = useState(null);
  const [txt, setTxt] = useState("");
  const [peerId, setPeerId] = useState(null);   // karsi tarafin id'si (profil + bildir icin)
  const [err, setErr] = useState("");           // v2.78: gonderim hatasi artik GORUNUYOR
  const ref = useRef(null);

  const load = useCallback(async () => {
    const { data, error: hata6 } = await supabase.from("messages").select("*").eq("channel_id", channelId).order("created_at");
    if (hata6) logError("ekranlar_ana.js:2696", hata6);
    setMsgs(data || []);
  }, [channelId]);

  // Kanaldan bagli oldugu connection'i, oradan da KARSI TARAFI cozer.
  useEffect(() => {
    (async () => {
      if (!channelId || !uid) return;
      const { data: ch, error: hata7 } = await supabase.from("chat_channels")
        .select("connection_id").eq("id", channelId).maybeSingle();
        if (hata7) logError("ekranlar_ana.js:2705", hata7);
      if (!ch?.connection_id) return;
      const { data: cr, error: hata8 } = await supabase.from("connection_requests")
        .select("from_id, to_id").eq("id", ch.connection_id).maybeSingle();
        if (hata8) logError("ekranlar_ana.js:2709", hata8);
      if (cr) setPeerId(cr.from_id === uid ? cr.to_id : cr.from_id);
    })();
  }, [channelId, uid]);

  useEffect(() => {
    load();
    let sub;
    const timer = setTimeout(() => {
      try {
        sub = supabase.channel("cc-" + channelId)
          .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `channel_id=eq.${channelId}` }, load)
          .subscribe();
      } catch (e) {}
    }, 1200);
    const iv = setInterval(load, 8000);
    return () => { clearTimeout(timer); clearInterval(iv); try { if (sub) supabase.removeChannel(sub); } catch (e) {} };
  }, [load, channelId]);

  async function send() {
    const body = txt.trim();
    if (!body) return;
    setTxt("");
    // 🔴 v2.78 — MESAJ SESSİZCE BUHARLAŞIYORDU.
    // Bu fonksiyon `error`ü hiç okumuyordu. SQL 204 engellemeyi
    // TETİKLEYİCİYE taşıdı: taraflardan biri diğerini engellemişse
    // insert `raise exception` verir. O anda kullanıcı mesajı yazar,
    // gönderir, kutu boşalır — ve mesaj YOKTUR, hiçbir şey de yazmaz.
    // Ağ koptuğunda da aynı.
    //
    // Aynı ürün eylemi `Chat.send()`te (bu dosyada) DOĞRU yazılmış.
    // İki ekran, aynı iş, iki farklı davranış: kopyalanan kod
    // düzeltmeyi kopyalamıyor. Burada ikisi eşitlendi ve metin geri
    // konuyor — kullanıcı yazdığını kaybetmesin.
    const { error } = await supabase.from("messages")
      .insert({ channel_id: channelId, from_id: uid, body });
    if (error) { setTxt(body); setErr(mapErr(t, error.message)); return; }
    setErr("");
    load();
  }

  return (
    <Sayfa>
      {/* MVP paritesi: isim -> profil · sag ustte BILDIR · altinda guvenlik bandi.
          Bunlarin hicbiri yoktu (Gokberk: "bilgiler MVP'ye gore cok cok az"). */}
      <Hdr t={t} ustBilgi={t.sceneMeet} title={otherName || t.ccTitle} onBack={onBack} right={
        onReport ? (
          <Btn v="redSoft" mini label={t.ppReport2} onPress={() => onReport(peerId, otherName)} />
        ) : null
      } />
      {onOpenProfile && peerId && (
        <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpenProfile(peerId)}
          style={{ backgroundColor: C.card, paddingVertical: SP[2], paddingHorizontal: ARA[14], borderBottomWidth: 1, borderColor: C.line }}>
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <Ikon ad="kisi" boy={14} renk={C.purple} stil={{ marginRight: SP[1] }} />
            <Text style={{ color: C.purple, fontSize: FS.sm, fontWeight: "600" }}>{t.ccViewProfile}</Text>
            <Ikon ad="sag" boy={13} renk={C.purple} stil={{ marginLeft: SP[1] }} />
          </View>
        </TouchableOpacity>
      )}
      <View style={{ backgroundColor: C.goldTint, paddingVertical: ARA[6], paddingHorizontal: ARA[14] }}>
        <Text style={{ color: C.goldInk, fontSize: FS.xs, textAlign: "center" }}>{t.safetyBar}</Text>
      </View>
      {msgs === null ? <Load /> : (
        <ScrollView ref={ref} onContentSizeChange={() => ref.current?.scrollToEnd({ animated: true })}
          contentContainerStyle={{ padding: ARA[14], paddingBottom: ARA[20] }}>
          {msgs.length === 0 && <Text style={{ color: C.mut, textAlign: "center", marginTop: ARA[30], fontSize: FS.sm }}>{t.ccEmpty}</Text>}
          {msgs.map(m => {
            const mine = m.from_id === uid;
            return (
              <View key={m.id} style={{ alignSelf: mine ? "flex-end" : "flex-start", maxWidth: "78%", marginBottom: SP[2] }}>
                {/* ══════════════════════════════════════════════════════════
                    🔴 20 EYLÜL — İKİNCİ SOHBET ÇİZİCİSİ HİÇ GÜNCELLENMEMİŞTİ.
                    VE İKİ AYRI KUSUR BİRDEN TAŞIYORDU:

                    1) ZEMİN: `C.purple` = #B7A8C6 (LAVANTA). 3 Eylül'de
                       "mor yüzeyler gece sisteminde yok" denip `purpleBg`,
                       `purpleInk`, `purpleUst`, `purpleLine` altına
                       eşlendi — ama BEŞİNCİSİ, `purple`'ın kendisi
                       eşlenmedi. Ve dolgu olarak kullanılan tek jeton oydu.
                       Sahneyi ölçtüm: 06b'de 155.992 piksel #B6A7C5, hue
                       310°. Sistem bandı 45-120°. Yani en çok kullanılan
                       ekranın en büyük renk bloğu terk edilmiş dünyadandı.

                    2) KONTRAST: metin `"#fff"` sabitti. Beyaz / #B7A8C6 =
                       **2.23:1**. AA 4.5 ister. Kendi yazdığın mesaj
                       okunmuyordu. `BTN.gold`un 1.65:1'i ile AYNI SINIF:
                       jeton doğruydu, ÇAĞRI YERİ atlamıştı.

                    Doğrusu zaten vardı: `ekranlar_yalin.js`teki sohbet
                    `balonBen` + `goldTrace` + `C.body` kullanıyor (14.27:1).
                    İki sohbet, iki görünüm olmamalı — aynı jetonlar.

                    🆕 SINIF: "BİR JETON AİLESİNİ EŞLERKEN AİLENİN KÖKÜNÜ
                    ATLARSAN, EN BÜYÜK YÜZEY ESKİ DÜNYADA KALIR — VE
                    EŞLEME RAPORU YİNE DE 'TAMAM' DER."
                    ══════════════════════════════════════════════════════════ */}
                <View style={{
                  backgroundColor: mine ? (C.balonBen || C.goldSoft) : C.card,
                  borderWidth: 1,
                  borderColor: mine ? (C.goldTrace || C.goldLine) : C.line,
                  borderRadius: R.sm, paddingHorizontal: SP[3], paddingVertical: SP[2] }}>
                  <Text style={{ color: mine ? C.body : C.ink, fontSize: FS.base, lineHeight: 19 }}>{m.body}</Text>
                </View>
                <Text style={{ fontSize: FS.micro, color: C.mut, marginTop: ARA[2], textAlign: mine ? "right" : "left" }}>
                  {new Date(m.created_at).toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" })}
                </Text>
              </View>
            );
          })}
        </ScrollView>
      )}
      {!!err && (
        <View style={{ paddingHorizontal: SP[3], paddingTop: SP[2] }}>
          <Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text>
        </View>
      )}
      <View style={{ flexDirection: "row", padding: ARA[10], gap: SP[2], borderTopWidth: 1, borderTopColor: C.line, backgroundColor: C.card }}>
        <TextInput style={[S.input, { flex: 1, marginBottom: 0 }]} value={txt} onChangeText={setTxt} placeholder="..." placeholderTextColor={C.mut} />
        <TouchableOpacity hitSlop={TAP.slop} disabled={!txt.trim()} onPress={send}
          accessibilityRole="button" accessibilityLabel={t.sendMsg}
          style={{ backgroundColor: txt.trim() ? C.purple : C.line, borderRadius: R.xs, paddingHorizontal: ARA[18], justifyContent: "center" }}>
          <Ikon ad="sag" boy={FS.base} renk={C.onAccent} />
        </TouchableOpacity>
      </View>
    </Sayfa>
  );
}

// ============ Safety Center (§21, §23) ============
export function Safety({ t, lang, session, onBack, onReport, onTrust, onEditProfile }) {
  // ============================================================
  // v1.22: bu ekran ARKAYA BAGLI DEGILDI.
  //   · App.js gender/wsm/onToggleWsm prop'larini HIC gecirmiyordu ->
  //     kadin guvenlik anahtari kimseye gorunmuyordu, ustelik kadinlara
  //     da "bu ozellik kadinlar icin" yazisi cikiyordu
  //   · SOS modali yazi gosterip kapaniyordu — hicbir sey yapmiyordu
  //   · "Bildir" satirinin onPress'i yoktu; olsaydi da cagiracak bir
  //     RPC yoktu (create_report hic yazilmamisti)
  // Artik ekran kendi verisini cekiyor ve 042'deki RPC'lere gidiyor.
  // ============================================================
  const uid = session?.user?.id;
  const [me, setMe] = useState(null);
  const [sos, setSos] = useState(false);
  const [sosBusy, setSosBusy] = useState(false);
  const [sosDone, setSosDone] = useState(null);
  const [note, setNote] = useState("");
  const [openItem, setOpenItem] = useState(null);
  // 🔴 23 Eylül — ENGEL LİSTESİ GERÇEK. "Engellenen Kullanıcılar" satırı
  // açılınca yalnız sabit bir metin gösteriyordu; uygulamadan birini
  // engellemenin de, engeli kaldırmanın da yolu yoktu (blocks tablosuna
  // insert yetkisi yok, RPC yok). SQL 301 `engelle` / `engeli_kaldir` /
  // `engellediklerim` ile artık liste canlı ve her satır geri alınabilir.
  const [engelli, setEngelli] = useState(null);      // null = yüklenmedi
  const [engelErr, setEngelErr] = useState("");
  const [engelBusy, setEngelBusy] = useState(null);  // kaldırılan user_id
  const engelYukle = useCallback(async () => {
    setEngelErr("");
    const { data, error } = await supabase.rpc("engellediklerim");
    if (error) { logError("engellediklerim", error); setEngelErr(mapErr(t, error.message)); setEngelli([]); return; }
    setEngelli(Array.isArray(data) ? data : []);
  }, [t]);
  async function engeliKaldir(id) {
    setEngelBusy(id); setEngelErr("");
    const { error } = await supabase.rpc("engeli_kaldir", { p_user: id });
    setEngelBusy(null);
    if (error) { logError("engeli_kaldir", error); setEngelErr(mapErr(t, error.message)); return; }
    setEngelli(l => (l || []).filter(x => x.user_id !== id));
  }

  const load = useCallback(async () => {
    if (!uid) return;
    const [{ data: u }, { data: p }, { data: ts }] = await Promise.all([
      supabase.from("users").select("gender").eq("id", uid).maybeSingle(),
      supabase.from("profiles").select("women_safety_mode").eq("user_id", uid).maybeSingle(),
      supabase.from("trust_scores").select("badge, score").eq("user_id", uid).maybeSingle(),
    ]);
    // MVP: "Güven Seviyesi" satırı CANLI veri gösterir ("Trusted Host · 15 oturum").
    let sesN = 0;
    try {
      const { data: ss, error: hata9 } = await supabase.from("sessions")
        .select("id, requests!inner(guest_id, host_id)").eq("status", "completed").limit(300);
        if (hata9) logError("ekranlar_ana.js:2839", hata9);
      sesN = (ss || []).filter(x => x.requests?.guest_id === uid || x.requests?.host_id === uid).length;
    } catch (e) {}
    setMe({ gender: u?.gender, wsm: !!p?.women_safety_mode, badge: ts?.badge, score: ts?.score ?? 0, sessions: sesN });
  }, [uid]);
  useEffect(() => { load(); }, [load]);

  async function toggleWsm() {
    const next = !me.wsm;
    setMe(m => ({ ...m, wsm: next }));                 // iyimser
    const { error } = await supabase.from("profiles")
      .update({ women_safety_mode: next }).eq("user_id", uid);
    if (error) load();                                  // basarisizsa geri al
  }

  async function fireSos() {
    setSosBusy(true);
    const { data, error } = await supabase.rpc("sos_alert", { p_note: note.trim() || null });
    setSosBusy(false);
    if (error) { setSosDone({ ok: false, msg: mapErr(t, error.message) }); return; }
    setSosDone({ ok: true, hasSession: data?.has_session });
  }

  const Row = ({ icon, title, body, onPress, accent }) => (
    <TouchableOpacity hitSlop={TAP.slop} disabled={!onPress} onPress={onPress}
      style={[S.card, onPress ? { borderColor: (accent || C.line) } : null]}>
      <View style={{ flexDirection: "row", alignItems: "center" }}>
        <Ikon ad={icon} boy={15} renk={accent || C.muted} stil={{ marginRight: SP[2] }} kutu={18} />
        <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base, flex: 1 }}>{title}</Text>
        {onPress ? <Ikon ad="sag" boy={16} renk={accent || C.dim} /> : null}
      </View>
      {!!body && <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{body}</Text>}
    </TouchableOpacity>
  );

  if (!me) return <Load t={t} title={t.safetyTitle} onBack={onBack} />;

  return (
    <Sayfa>
      <Hdr t={t} scene="GÜVENLİK" title={t.safetyTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[3] }}>{t.safetySub}</Text>

        <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setSosDone(null); setNote(""); setSos(true); }}
          style={{ backgroundColor: C.redBg, borderWidth: 1.5, borderColor: "transparent", borderRadius: R.sm, padding: SP[4], marginBottom: SP[3] }}>
          <Text style={{ color: C.redInk, fontWeight: "700", fontSize: FS.lg }}>{t.safetySOS}</Text>
          <Text style={{ color: C.redInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 17 }}>{t.safetySOSBody}</Text>
        </TouchableOpacity>

        {/* Kadin guvenlik modu — SUNUCUDA da zorlaniyor (012/030) */}
        {me.gender === "female" ? (
          <View style={[S.card, { flexDirection: "row", justifyContent: "space-between", alignItems: "center" }]}>
            <View style={{ flex: 1, marginRight: ARA[10] }}>
              {/* 🔴 13 EYLÜL (Gökberk md.12) — "text object falan yazıyor".
                    Ölçüldü: ekranda "Kadın Güvenlik Modu stilMetin=[object
                    Object]" yazıyordu. Sebep bir şablon dizesi kazası:
                    `stilMetin` PROP olacakken `metin={`...`}` dizesinin
                    İÇİNE girmiş, JS de nesneyi "[object Object]" diye
                    yazıya çevirmiş. Aynı kaza ÜÇ yerde vardı (bu, PhoneGate,
                    seyahatsiz istek uyarısı) — yani kullanıcı üç ayrı
                    ekranda ham kod görüyordu.
                    🆕 SINIF: "BİR PROP'U DİZENİN İÇİNE YAZARSAN JS HATA
                    VERMEZ — NESNEYİ SESSİZCE METNE ÇEVİRİR." */}
                <IkonMetin ad="guvenlik" boy={15} renk={C.purple} metin={t.safetyWSM}
                stilMetin={{ color: C.ink, fontSize: FS.base, fontWeight: "600" }} />
              <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>{t.safetyWSMBody}</Text>
            </View>
            {/* 🔴 Bu bir ANAHTAR ama ekran okuyucuya "düğme" diyordu ve
                AÇIK/KAPALI olduğunu hiç söylemiyordu — yani kadın güvenlik
                modunun durumu görme engelli bir kullanıcı için okunamazdı.
                Rol `switch`, durum `checked`. */}
            <TouchableOpacity hitSlop={TAP.slop} onPress={toggleWsm}
              accessibilityRole="switch"
              accessibilityState={{ checked: !!me.wsm }}
              accessibilityLabel={t.safetyWSM}
              style={{ width: 42, height: 24, borderRadius: R.full, backgroundColor: me.wsm ? C.purple : C.bgAlt,
                       borderWidth: 1, borderColor: me.wsm ? C.purple : C.line, justifyContent: "center" }}>
              <View style={{ width: 18, height: 18, borderRadius: R.full, backgroundColor: "#fff", marginLeft: me.wsm ? 21 : 2 }} />
            </TouchableOpacity>
          </View>
        ) : (
          // v1.79 (MVP paritesi): kapalıyken MVP önce ÖZELLİK LİSTESİNİ gösterir,
          // altında nasıl açılacağını söyler. Canlıda yalnız tek satır vardı.
          <Row icon="guvenlik" title={t.safetyWSM} body={t.safetyWSMFeatures + "\n" + t.safetyWSMOff}
            onPress={onEditProfile} accent={C.purple} />
        )}

        <Row icon="bayrak" title={t.safetyReport} body={t.safetyRules} accent={C.amber}
          onPress={onReport} />

        {/* MVP: genişleyebilen güvenlik satırları — ikon karo + akordeon */}
        {[["yasak", C.mut, t.safeBlockedT, t.safeBlockedB],
          ["hukuk", C.amber, t.safeDisputeT, t.safeDisputeB],
          ["guvenlik", C.teal, t.safeTrustT, `${badgeLabel(t, me.badge)} · ${me.sessions} ${t.sessionsWord} · ${me.score}/100`, onTrust],
          ["belge", C.mut, t.safeRulesT, t.safeRulesB, null, "rules"]].map(([ic, c, title, body, go, kind]) => {
          const open = openItem === title;
          return (
            <View key={title} style={[S.card, { padding: 0, overflow: "hidden", marginBottom: SP[2] }]}>
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => { if (go) { go(); return; } if (!open && title === t.safeBlockedT) { setEngelli(null); engelYukle(); } setOpenItem(open ? null : title); }}
                style={{ flexDirection: "row", alignItems: "center", padding: SP[3] }}>
                <View style={{ width: 38, height: 38, borderRadius: R.xs, backgroundColor: c + "1F", alignItems: "center", justifyContent: "center", marginRight: SP[3] }}>
                  <Ikon ad={ic} boy={18} renk={c} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: FS.sm, fontWeight: "600", color: c }}>{title}</Text>
                  <Text style={{ fontSize: FS.xs, color: C.muted, marginTop: ARA[2] }}>{body}</Text>
                </View>
                <Ikon ad={!go && open ? "asagi" : "sag"} boy={16} renk={C.dim} />
              </TouchableOpacity>
              {open && kind === "rules" && (
                <View style={{ borderTopWidth: 1, borderTopColor: C.line, padding: SP[3], backgroundColor: C.bgAlt }}>
                  {[t.rule1, t.rule2, t.rule3, t.rule4, t.rule5].map(r => (
                    <View key={r} style={{ flexDirection: "row", marginBottom: ARA[6] }}>
                      <Ikon ad="tamam" boy={14} renk={C.greenInk} stil={{ marginRight: SP[2], marginTop: ARA[2] }} />
                      <Text style={{ fontSize: FS.sm, color: C.body, flex: 1, lineHeight: 17 }}>{r}</Text>
                    </View>
                  ))}
                </View>
              )}
              {open && title === t.safeBlockedT && (
                <View style={{ borderTopWidth: 1, borderTopColor: C.line, padding: SP[3], backgroundColor: C.bgAlt }}>
                  {engelli === null ? (
                    <ActivityIndicator color={C.gold} />
                  ) : engelli.length === 0 ? (
                    <Text style={{ fontSize: FS.sm, color: C.mutedAA, lineHeight: 17 }}>{t.safeBlockedLong}</Text>
                  ) : engelli.map(b => (
                    <View key={b.user_id} style={{ flexDirection: "row", alignItems: "center", paddingVertical: ARA[6] }}>
                      <View style={{ flex: 1, minWidth: 0, marginRight: SP[2] }}>
                        <Text numberOfLines={1} style={{ fontSize: FS.sm, fontWeight: "600", color: C.ink }}>{b.name || "—"}</Text>
                        {!!b.created_at && (
                          <Text style={{ fontSize: FS.xs, color: C.muted, marginTop: ARA[2] }}>
                            {String(t.blockedSince || "{d}").replace("{d}", fmtLongDate(String(b.created_at).slice(0, 10), lang))}
                          </Text>
                        )}
                      </View>
                      <Btn v="ghost" cip label={t.unblock} a11yLabel={`${t.unblock} · ${b.name || ""}`}
                        busy={engelBusy === b.user_id} disabled={!!engelBusy}
                        onPress={() => engeliKaldir(b.user_id)} />
                    </View>
                  ))}
                  {!!engelErr && <Text style={{ color: C.red, fontSize: FS.sm, marginTop: SP[2] }}>{engelErr}</Text>}
                  {engelli && engelli.length > 0 && (
                    <Text style={{ fontSize: FS.xs, color: C.muted, marginTop: SP[2], lineHeight: 16 }}>{t.blockedNote}</Text>
                  )}
                </View>
              )}
              {open && kind !== "rules" && title !== t.safeBlockedT && (
                <View style={{ borderTopWidth: 1, borderTopColor: C.line, padding: SP[3], backgroundColor: C.bgAlt }}>
                  <Text style={{ fontSize: FS.sm, color: C.mutedAA, lineHeight: 17 }}>{t.safeDisputeLong}</Text>
                </View>
              )}
            </View>
          );
        })}
      </ScrollView>

      <Modal visible={sos} transparent animationType="fade" onRequestClose={() => setSos(false)}>
        <View style={{ flex: 1, justifyContent: "center", padding: ARA[30] }}>
          <PerdeBulanik />
          <View style={{ ...POPUP_YUZEY(), borderRadius: R.md, padding: ARA[22] }}>
            <Ikon ad="acil" boy={34} renk={C.red} stil={{ alignSelf: "center" }} />

            {!sosDone ? (
              <>
                <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, textAlign: "center", marginTop: SP[2] }}>{t.safetySOS}</Text>
                <Text style={{ fontSize: FS.sm, color: C.mutedAA, textAlign: "center", marginTop: SP[2], lineHeight: 20 }}>{t.sosWhat}</Text>
                <TextInput value={note} onChangeText={setNote} placeholder={t.sosNote} placeholderTextColor={C.dim} multiline
                  style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                           padding: SP[3], marginTop: SP[3], height: 64, textAlignVertical: "top", color: C.body, fontSize: FS.sm }} />
                <Btn v="danger" sm label={t.sosSend} onPress={fireSos} disabled={sosBusy} busy={sosBusy} style={{ marginTop: SP[3] }} />
              </>
            ) : sosDone.ok ? (
              <>
                <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.greenInk, textAlign: "center", marginTop: SP[2] }}>{t.sosSent}</Text>
                <Text style={{ fontSize: FS.sm, color: C.mutedAA, textAlign: "center", marginTop: SP[2], lineHeight: 19 }}>{t.sosSentBody}</Text>
              </>
            ) : (
              <Text style={{ fontSize: FS.sm, color: C.red, textAlign: "center", marginTop: SP[2] }}>{sosDone.msg}</Text>
            )}

            {/* Gercek acil durumda dogru cevap 112'dir — biz onun yerini almayiz */}
            <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginTop: SP[3] }}>
              <Text style={{ fontSize: FS.sm, color: C.amberInk, lineHeight: 17 }}>{t.sos112}</Text>
            </View>

            <TouchableOpacity hitSlop={TAP.slop} onPress={() => setSos(false)} style={{ marginTop: SP[3], padding: SP[2], alignItems: "center" }}>
              <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.close}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </Sayfa>
  );
}

// ============ TrustVisual (§16) ============
// Gerçek dolan ilerleme halkası (SVG bağımlılığı olmadan).
// Mantık: iki yarım daire maskesi + döndürülen dolu yarımlar.
export function TrustVisual({ t, session, onBack }) {
  const uid = session?.user?.id;
  const [d, setD] = useState(null);
  const [isHost, setIsHost] = useState(false);   // "Lounge hakkı beyanı" yalnız host'a gösterilir
  useEffect(() => {
    (async () => {
      const { data, error: hata10 } = await supabase.from("trust_scores").select("score, components, badge").eq("user_id", uid).maybeSingle();
      if (hata10) logError("ekranlar_ana.js:3000", hata10);
      setD(data || { score: 0, components: {} });
      // Rolü oku: "Lounge hakkı beyanı" bileşeni MİSAFİRDE ANLAMSIZ —
      // misafir lounge hakkı beyan etmez, o yalnızca host'un verdiği bilgi.
      const { data: u, error: hata11 } = await supabase.from("users").select("role").eq("id", uid).maybeSingle();
      if (hata11) logError("ekranlar_ana.js:3005", hata11);
      setIsHost(u?.role === "host");
    })();
  }, [uid]);
  if (!d) return <Load t={t} title={t.trustTitle} onBack={onBack} />;
  const comp = d.components || {};
  const score = d.score || 0;
  // MVP renk kodu: yeşil=doğrulama, altın=profil, teal=erişim/linkedin
  // 🔴 Bu liste SQL'deki recompute_trust ile BİREBİR aynı olmalı.
  // Önceki hâlinde maksimumlar uydurmaydı (e-posta 8 yazıyordu ama SQL 10
  // veriyor) ve anahtar "access" idi — SQL "host_access" yazıyor. Sonuç:
  // kazanılan 8 puan hiç görünmüyor, toplam (18) ile dökümün toplamı (8)
  // tutmuyordu. Ayrıca oturum ve puan bileşenleri hiç listelenmiyordu.
  const ITEMS = [
    ["email", t.trustEmail, 10, C.green], ["phone", t.trustPhone, 10, C.green],
    ["profession", t.trustProf, 6, C.gold], ["bio", t.trustBio, 6, C.gold],
    ["linkedin", t.trustLinkedin, 8, C.teal], ["id", t.trustId, 18, C.gold],
    ...(isHost ? [["host_access", t.trustAccess, 8, C.teal]] : []),
    ["sessions", t.trustSessions, 14, C.gold], ["rating", t.trustRating, 10, C.teal],
  ];
  const nextLevel = score >= 88 ? 100 : score >= 72 ? 88 : score >= 56 ? 72 : 56;
  return (
    <Sayfa>
      <Hdr t={t} scene="GÜVEN" title={t.trustTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {/* Halka */}
        <View style={{ alignItems: "center", marginBottom: ARA[22] }}>
          {/* 🔴 v1.71 (Gokberk: "dairesel bar dolmuyor"): eski halka kenarlık
              hilesiyle çiziliyordu — dört kenarı ayrı ayrı şeffaf yapıp
              -45° döndürmek yalnızca 25/50/75 eşiklerinde ve çoğu Android
              sürümünde HİÇ görünmüyordu (ekranda tamamen gri kalıyordu).
              Gerçek çözüm: iki yarım daire maskesi. Sol yarı 0-50, sağ yarı
              50-100 aralığını çizer; her yüzde değeri düzgün dolar. */}
          <TrustRing score={score} />
        </View>
        {/* Sonraki kademe kartı */}
        <View style={{ backgroundColor: C.goldBg, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[14] }}>
          <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: ARA[6] }}>
            <Text style={{ fontSize: FS.sm, color: C.goldText, fontWeight: "600" }}>{badgeLabel(t, d.badge)}</Text>
            <Text style={{ fontSize: FS.xs, color: C.muted }}>{t.trustNext}: {nextLevel}</Text>
          </View>
          <View style={{ height: 4, backgroundColor: C.bgAlt, borderRadius: R.full, overflow: "hidden", marginBottom: ARA[6] }}>
            <View style={{ width: `${Math.min(100, (score / nextLevel) * 100)}%`, height: "100%", backgroundColor: C.gold, borderRadius: R.full }} />
          </View>
          <Text style={{ fontSize: FS.xs, color: C.mutedAA }}>{Math.max(0, nextLevel - score)} {t.trustMorePts}</Text>
        </View>
        {/* Faktör çubukları */}
        {/* ══════════════════════════════════════════════════════════════
            🔴 13 EYLÜL (Gökberk md.13) — "alttaki puanların toplamı ile
            yukarıdaki puan gösterimi birbirini tutmuyor. Alttakilerin
            toplamı 66, en üstteki total puanda 58 yazıyor."

            Ölçtüm: bu liste kalemin KAZANILAN değerini değil TAVANINI
            yazıyordu — `has ? pts : 0`. Yani sunucu "sessions: 6" dese
            bile ekranda "14/14" görünüyordu. Kullanıcı kalemleri
            topluyor 66 buluyor, halka 58 diyor.
            Daha kötüsü: alttaki MUTABAKAT satırı da kaçırıyordu, çünkü
            o `comp`un GERÇEK toplamını (58) skorla karşılaştırıyor —
            ikisi tutuyor, dolayısıyla hiç uyarı çıkmıyordu. Yani
            denetim doğru sayıyı ölçüyor, EKRAN yanlış sayıyı yazıyordu.
            Artık kalem gerçek değerini yazıyor; çubuk da oranı kadar
            doluyor. Mutabakat satırı EKRANDA GÖRÜNENİ karşılaştırıyor.
            🆕 SINIF: "BİR LİSTENİN TOPLAMI BAŞLIKTAKİ SAYIYI TUTMUYORSA,
            ÖNCE LİSTENİN NE YAZDIĞINA BAK — TAVANI YAZIYOR OLABİLİR."
            ══════════════════════════════════════════════════════════════ */}
        {ITEMS.map(([key, label, pts, barC]) => {
          const ham = comp[key];
          const has = ham != null;
          const kazanilan = Math.max(0, Math.min(pts, parseInt(ham, 10) || 0));
          const oran = pts > 0 ? Math.round((kazanilan / pts) * 100) : 0;
          return (
            <View key={key} style={{ marginBottom: SP[3] }}>
              {/* 🔴 v2.50 (Gokberk: "aldığım puanlar neye göre doluyor?"):
                  kalemler puanı GÖSTERİYOR ama NASIL kazanıldığını
                  söylemiyordu. Kapalı bir kalem, kullanıcı için yapılacak
                  iş demektir; ne yapacağını yazmayan bir liste yalnızca
                  eksik hissettirir. Her kaleme tek satır açıklama. */}
              <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: ARA[2] }}>
                <Text style={{ fontSize: FS.sm, color: has ? C.body : C.mut }}>{label}</Text>
                <Text style={{ fontSize: FS.xs, color: kazanilan > 0 ? barC : C.dim, fontWeight: "600" }}>{kazanilan}/{pts}</Text>
              </View>
              {!!(t.trustHow && t.trustHow[key]) && (
                <Text style={{ fontSize: FS.xs, color: C.dim, marginBottom: SP[1], lineHeight: 15 }}>
                  {t.trustHow[key]}
                </Text>
              )}
              <View style={{ height: 4, backgroundColor: C.bgAlt, borderRadius: R.full, overflow: "hidden" }}>
                <View style={{ width: `${oran}%`, height: "100%", backgroundColor: barC, borderRadius: R.full }} />
              </View>
            </View>
          );
        })}

        {/* 🔴 v1.86 — EKSİLER GÖRÜNMÜYORDU.
            ITEMS sabit bir BEYAZ LİSTE; recompute_trust'ın ürettiği
            `reliability` (geç iptal / gelmeme cezası) bu listede olmadığı
            için hiç çizilmiyordu. Sonuç: kullanıcı bileşenleri topluyor 72
            buluyor ama halkada 64 görüyordu. Bir GÜVEN ekranında aritmetiğin
            tutmaması, güven ekranının kendisini çürütür.
            Artık bilinmeyen/eksi her bileşen de listeleniyor ve altta
            mutabakat satırı var. */}
        {(() => {
          const known = ITEMS.map(x => x[0]);
          const extras = Object.keys(comp).filter(k => !known.includes(k));
          // 13 Eylül md.13 — EKRANDA GÖRÜNEN toplam. Eskiden `comp`un ham
          // toplamı karşılaştırılıyordu; ekran başka bir sayı yazdığı için
          // mutabakat satırı kullanıcının gördüğü farkı hiç yakalamıyordu.
          const gorunen = ITEMS.reduce((a, [k, , pts]) =>
            a + Math.max(0, Math.min(pts, parseInt(comp[k], 10) || 0)), 0)
            + extras.reduce((a, k) => a + (parseInt(comp[k], 10) || 0), 0);
          if (!extras.length && gorunen === score) return null;
          return (
            <View style={{ marginTop: ARA[6], borderTopWidth: 1, borderTopColor: C.line, paddingTop: ARA[14] }}>
              {extras.map(k => {
                const v = parseInt(comp[k], 10) || 0;
                const neg = v < 0;
                return (
                  <View key={k} style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: SP[2] }}>
                    <Text style={{ fontSize: FS.sm, color: neg ? C.red : C.body }}>
                      {k === "reliability" ? t.trustReliability : k}
                    </Text>
                    <Text style={{ fontSize: FS.xs, fontWeight: "600", color: neg ? C.red : C.body }}>
                      {v > 0 ? "+" : ""}{v}
                    </Text>
                  </View>
                );
              })}
              <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: SP[1] }}>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{t.trustTotal}</Text>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{score}/100</Text>
              </View>
              {extras.includes("reliability") && (
                <Text style={{ fontSize: FS.xs, color: C.muted, marginTop: ARA[6], lineHeight: 16 }}>
                  {t.trustReliabilityNote}
                </Text>
              )}
            </View>
          );
        })()}
      </ScrollView>
    </Sayfa>
  );
}

// ============ SessionHistory ============

// ============================================================
// v1.95 — SAHA RAPORU SORUSU
//
// 🔴 NEDEN: `lounge_field_reports` tablosu ve `pending_field_report()`
// SQL 087'de yazıldı ama uygulamada TEK BİR ÇAĞRI YOKTU. Yani kural
// verisini kendi kullanımıyla büyüten mekanizma hiç çalışmıyordu.
// Tabloyu yazıp soruyu sormamak, kutuyu kurup fişini takmamaktır.
//
// TEK SORU, ÜÇ CEVAP. Uzun anket kimse doldurmaz; bu üç şık kapıda ne
// olduğunu anlatmaya yeter ve "bilinmiyor" hücrelerini kapatır.
// Rapor kuralı OTOMATİK DEĞİŞTİRMEZ — BO'da insan okur (SQL 087 kararı).
// ============================================================
export function SessionHistory({ t, lang, session, onBack, onOpenChat, onOpenProfile, onOpenCompanion }) {
  const uid = session?.user?.id;
  const [tab, setTab] = useState("sessions");
  const [data, setData] = useState(null);
  // v1.82 (Gokberk): "sonra puanla" dediğim oturumu SONRA NEREDE BULACAĞIM?
  // Cevap burası: puanlanmamış oturumlar (ertelenmişler DAHİL) 24 saat
  // boyunca "★ Puanla" rozetiyle Oturum sekmesinde durur (SQL 081).
  const [unrated, setUnrated] = useState({});
  useEffect(() => {
    (async () => {
      // Oturumlar + karşı taraf profilleri + puan — tek yükleme
      // 🔴 v3.9 — ÜÇ TUR TEK DALGAYA İNDİ. `sessions`, `unrated_sessions`
      // ve `connection_requests`in hiçbiri diğerinin sonucunu kullanmıyor;
      // yalnız `uid` ile parametreliler. Ekran üç tur beklerken yalnız
      // birini bekliyor.
      const [{ data: ss }, ur, { data: cr }] = await Promise.all([
        supabase.from("sessions")
          .select("id, status, started_at, request_id, requests!inner(id, guest_id, host_id, availabilities(lounge_name, airport_code, avail_date))")
          .order("started_at", { ascending: false }).limit(80),
        supabase.rpc("unrated_sessions").then(r => r.data).catch(() => null),
        supabase.from("connection_requests")
          .select("from_id, to_id, status").eq("status", "accepted").or(`from_id.eq.${uid},to_id.eq.${uid}`),
      ]);
      const mine = (ss || []).filter(x => x.requests?.guest_id === uid || x.requests?.host_id === uid);
      const completed = mine.filter(x => x.status === "completed");
      // 🔴 v1.77 + SQL 080: 'pending' (bir taraf başlatmış, diğeri bekleniyor)
      // hiçbir listede görünmüyordu — kullanıcı o oturuma yalnız sohbetten
      // ulaşabiliyordu. Aktif sekmesi artık ikisini de gösterir.
      const active = mine.filter(x => x.status === "active" || x.status === "pending");
      const m = {}; (ur || []).forEach(x => { m[x.session_id] = x; });
      setUnrated(m);
      // Bağlantılar: kabul edilmiş connection_requests + oturum karşı tarafları
      // (yukarıdaki dalgada okundu)
      // 🔴 v1.81 (Gokberk'in 7. maddesi): "Bağlantılar" sekmesi oturum karşı
      // taraflarını da bağlantı SAYIYORDU. Oysa bağlantı, karşılıklı kabul
      // edilmiş bir connection_request'tir. Bu yüzden Geçmiş ekranı "bağlısın"
      // derken oturum tamamlandı ekranı haklı olarak "bağlantı kur" diyordu —
      // iki farklı tanım. Tek tanım: yalnız kabul edilmiş bağlantılar.
      const otherIds = new Set();
      (cr || []).forEach(c => otherIds.add(c.from_id === uid ? c.to_id : c.from_id));
      const allIds = [...new Set([...otherIds,
        ...mine.map(x => x.requests?.host_id === uid ? x.requests?.guest_id : x.requests?.host_id)])].filter(Boolean);
      let umap = {};
      if (allIds.length) {
        const [{ data: ps }, { data: us }] = await Promise.all([
          supabase.from("profiles").select("user_id, name, profession, photo_url").in("user_id", allIds),
          supabase.from("users").select("id, role").in("id", allIds),
        ]);
        (ps || []).forEach(p => { umap[p.user_id] = { ...(umap[p.user_id] || {}), ...p }; });
        (us || []).forEach(u => { umap[u.id] = { ...(umap[u.id] || {}), role: u.role }; });
      }
      const { data: bal, error: hata12 } = await supabase.from("user_balances").select("points").eq("user_id", uid).maybeSingle();
      if (hata12) logError("ekranlar_ana.js:3189", hata12);
      setData({ completed, active, conns: [...otherIds].map(id => ({ id, ...umap[id] })).filter(x => x.name), umap, points: bal?.points ?? 0 });
    })();
  }, [uid]);
  if (!data) return <Load t={t} title={t.histTitle} onBack={onBack} />;
  const other = s => { const o = s.requests?.host_id === uid ? s.requests?.guest_id : s.requests?.host_id; return data.umap[o] || {}; };
  const tabs = [["sessions", t.histTabSessions, data.completed.length], ["active", t.histTabActive, data.active.length], ["connections", t.histTabConns, data.conns.length]];

  // 🔴 v3.6 — YEREL `Empty`, ORTAK `BosDurum`A DEVREDİLDİ.
  // Kendi kopyası emoji alıyordu (`emoji="📅"`); emoji gövde fontunda
  // yok, sistem emoji fontuna düşüyor ve `FS.hero`da dikey ölçüsü
  // satırı taşırıyordu — Gökberk'in "ikonlar kesiliyor" şikâyetinin
  // tam kaynağı. Artık ortak bileşen ve vektör ikon.
  const Empty = ({ ikon, label }) => (
    <View style={{ paddingVertical: SP[5] }}>
      <BosDurum ikon={ikon} baslik={label} />
    </View>
  );

  return (
    <Sayfa>
      <Hdr t={t} scene="GEÇMİŞ" title={t.histFullTitle} onBack={onBack} />
      {/* MVP: istatistik üçlüsü Oturum / Bağlantılar / Puan */}
      <View style={{ flexDirection: "row", gap: SP[2], padding: ARA[14] }}>
        {[[data.completed.length, t.statSessions], [data.conns.length, t.histTabConns], [data.points, t.points]].map(([v, l]) => (
          <View key={l} style={{ flex: 1, backgroundColor: C.card, borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center", borderWidth: 1, borderColor: C.line }}>
            <Text style={{ fontSize: FS.lg, fontFamily: MONO[600], fontWeight: "700", color: C.goldText }}>{v}</Text>
            <Text style={{ fontSize: FS.micro, color: C.dim, marginTop: 0 }}>{l}</Text>
          </View>
        ))}
      </View>
      {/* MVP: 3 sekme, altın alt çizgi */}
      <View style={{ flexDirection: "row", borderBottomWidth: 1, borderBottomColor: C.line }}>
        {tabs.map(([id, lb, n]) => (
          <TouchableOpacity hitSlop={TAP.slop} key={id} onPress={() => setTab(id)}
            style={{ flex: 1, paddingVertical: ARA[10], alignItems: "center", borderBottomWidth: 2, borderBottomColor: tab === id ? C.gold : "transparent" }}>
            <Text style={{ fontSize: FS.xs, fontWeight: "600", color: tab === id ? C.gold : C.dim }}>{lb}{n > 0 ? ` (${n})` : ""}</Text>
          </TouchableOpacity>
        ))}
      </View>
      <ScrollView contentContainerStyle={{ padding: ARA[14], paddingBottom: ARA[40] }}>
        <FieldReportPrompt t={t} session={session} />
        {tab === "sessions" && (data.completed.length === 0 ? <Empty ikon="takvim" label={t.histEmpty} /> :
          data.completed.map(s => {
            const o = other(s);
            return (
              <View key={s.id} style={[S.card, { marginBottom: ARA[10] }]}>
                <View style={{ flexDirection: "row", alignItems: "center", marginBottom: ARA[10] }}>
                  <View style={{ width: 36, height: 36, borderRadius: R.full, backgroundColor: C.tealBg, alignItems: "center", justifyContent: "center", marginRight: ARA[10] }}>
                    <Text style={{ color: C.tealInk, fontWeight: "700", fontFamily: F.serif }}>{(o.name || "?").charAt(0).toUpperCase()}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{abbrevName(o.name) || "—"}</Text>
                    <Text style={{ fontSize: FS.xs, color: C.dim }}>{s.started_at ? fmtLongDate(yerelGun(new Date(s.started_at)), lang) : ""}</Text>
                  </View>
                  <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] }}>
                    <Text style={{ color: C.greenInk, fontSize: FS.xs, fontWeight: "600" }}>{t.completedWord}</Text>
                  </View>
                </View>
                {/* 🔴 v1.82 (Gokberk): "sonra puanla"ya basınca oturum ana
                    sayfadan kalkıyordu ve bir daha bulunamıyordu. Puanlanmamış
                    oturum artık BURADA duruyor; kaç saat kaldığı da yazıyor. */}
                {unrated[s.id] && (
                  <Btn v="gold" sm solAd="degerlendirme" label={`${t.rateNowBtn}${unrated[s.id].hours_left > 0 ? ` · ${String(t.hoursLeftShort || "{n} sa").replace("{n}", String(Math.round(unrated[s.id].hours_left)))}` : ""}`} onPress={() => onOpenChat && onOpenChat({ req: { id: s.request_id }, name: o.name, openPanel: true })} style={{ marginBottom: SP[2] }} />
                )}
                <View style={{ flexDirection: "row", gap: SP[2] }}>
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpenChat && onOpenChat({ req: { id: s.request_id }, name: o.name })}
                    style={{ flex: 1, backgroundColor: C.bgAlt, borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center" }}>
                    <Text style={{ fontSize: FS.xs, color: C.body }}>{t.chatBtn}</Text>
                  </TouchableOpacity>
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpenProfile && onOpenProfile(other(s).id || (s.requests?.host_id === uid ? s.requests?.guest_id : s.requests?.host_id))}
                    style={{ flex: 1, backgroundColor: C.bgAlt, borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center" }}>
                    <Text style={{ fontSize: FS.xs, color: C.body }}>{t.profileBtn}</Text>
                  </TouchableOpacity>
                </View>
              </View>
            );
          }))}
        {tab === "active" && (data.active.length === 0 ? <Empty ikon="bekliyor" label={t.histNoActive} /> :
          data.active.map(s => {
            const o = other(s);
            return (
              <View key={s.id} style={[S.card, { marginBottom: ARA[10], borderColor: "transparent", borderWidth: 1.5 }]}>
                <View style={{ flexDirection: "row", alignItems: "center" }}>
                  <View style={{ width: 36, height: 36, borderRadius: R.full, backgroundColor: C.greenBg, alignItems: "center", justifyContent: "center", marginRight: ARA[10] }}>
                    <Text style={{ color: C.greenInk, fontWeight: "700", fontFamily: F.serif }}>{(o.name || "?").charAt(0).toUpperCase()}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{abbrevName(o.name) || "—"}</Text>
                    <Text style={{ fontSize: FS.xs, color: C.greenInk }}>{t.inProgress}</Text>
                  </View>
                  <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] }}>
                    <Text style={{ color: C.greenInk, fontSize: FS.xs, fontWeight: "600" }}>• {s.status === "pending" ? t.waitingStartShort : t.activeWord}</Text>
                  </View>
                </View>
                {/* Aktif oturum kartından doğrudan oturuma dönüş (canlıda kart
                    tamamen aksiyonsuzdu — kullanıcı sohbete başka yoldan gitmek
                    zorundaydı). */}
                <Btn v="gold" sm label={t.goToSession} onPress={() => onOpenChat && onOpenChat({ req: { id: s.request_id }, name: o.name })} style={{ marginTop: ARA[10] }} />
              </View>
            );
          }))}
        {tab === "connections" && (data.conns.length === 0 ? <Empty ikon="elSikisma" label={t.histNoConns} /> :
          data.conns.map(u => (
            <View key={u.id} style={[S.card, { marginBottom: ARA[10] }]}>
              <View style={{ flexDirection: "row", alignItems: "center", marginBottom: ARA[10] }}>
                <View style={{ width: 40, height: 40, borderRadius: R.md, backgroundColor: u.role === "host" ? C.goldSoft : C.tealBg, alignItems: "center", justifyContent: "center", marginRight: ARA[10] }}>
                  <Text style={{ color: u.role === "host" ? C.gold : C.teal, fontWeight: "700", fontFamily: F.serif }}>{(u.name || "?").charAt(0).toUpperCase()}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{abbrevName(u.name)}</Text>
                  <Text style={{ fontSize: FS.xs, color: C.dim }}>{u.profession || ""}</Text>
                </View>
              </View>
              {/* MVP: bağlantılar sekmesinde PROFİL + MESAJ (mesaj butonu YOKTU) */}
              <View style={{ flexDirection: "row", gap: SP[2] }}>
                <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpenProfile && onOpenProfile(u.id)}
                  style={{ flex: 1, backgroundColor: C.bgAlt, borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center" }}>
                  <Text style={{ fontSize: FS.xs, color: C.body }}>{t.profileBtn}</Text>
                </TouchableOpacity>
                <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpenCompanion && onOpenCompanion(u.id, u.name)}
                  style={{ flex: 1, backgroundColor: C.goldBg, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center" }}>
                  <Text style={{ fontSize: FS.xs, color: C.goldText, fontWeight: "600" }}>{t.ppMessage}</Text>
                </TouchableOpacity>
              </View>
            </View>
          )))}
      </ScrollView>
    </Sayfa>
  );
}

// ============ Referral (§19) ============
// Referans kodu girişi — kayıttan taşınan işlev (v1.64). apply_referral
// idempotent değilse bile sunucu hatası kullanıcıya aynen gösterilir.
// ============================================================
// DEĞERLENDİRMELER (v2.95 · Gökberk madde 11)
//
// NEDEN AYRI BİR EKRAN:
// Ana sayfadaki "Ağırlaman nasıl geçti?" kartı iki kusur taşıyordu.
//  (a) Katlanamıyordu — bir ekran dolusu yer kaplıyor ve altındaki her
//      şeyi (Sorduklarım, Bağlantılar) görünmez kılıyordu.
//  (b) "Şimdi değil"e basınca `defer_rating` kaydı yazılıyor ve o oturum
//      BİR DAHA HİÇBİR YERDE görünmüyordu. Ertelemek, silmeye eşitti.
//
// Puanlama bu ürünün güven döngüsünün TEK girdisi: güven puanı ondan
// besleniyor, rozetler ondan çıkıyor, host sıralaması ona bakıyor. Onu
// tek dokunuşla kalıcı olarak kaybetmek, motoru yakıtsız bırakmaktır.
//
// Burada iki sekme var ve ikisi de oturumun HANGİSİ olduğunu açıkça
// söylüyor (Gökberk'in şartı): salon · havalimanı · tarih · saat.
// ============================================================
export function Referral({ t, session, onBack }) {
  const uid = session?.user?.id;
  const [code, setCode] = useState(null);
  const [invited, setInvited] = useState([]);
  const [copied, setCopied] = useState(false);
  const [paylasiyor, setPaylasiyor] = useState(false);
  // v2.77 — BO'daki `referral` bayrağı artık GERÇEKTEN kapatıyor.
  const kapali = !bayrak("referral");
  useEffect(() => {
    if (kapali) return;
    (async () => {
      const { data, error: hata13 } = await supabase.rpc("my_referral");
      if (hata13) logError("ekranlar_ana.js:3353", hata13);
      setCode(data?.code || null);
      setInvited(data?.invited || []);
    })();
  }, [uid, kapali]);

  // 🔴 ERKEN RETURN, HOOK'LARDAN SONRA. İlk yazdığımda bayrak kontrolünü
  // fonksiyonun EN BAŞINA koymuştum; `useState`/`useEffect` o return'ün
  // ARDINDA kalıyordu. React'te hook sayısı her render'da aynı olmalı —
  // bayrak açıkken 3 hook, kapalıyken 0 hook çalışırdı ve bayrak
  // sunucudan gelip değiştiği anda uygulama BEYAZ EKRANA düşerdi.
  // Kendi nöbetçim (`check.js` hook sırası denetimi) yakaladı.
  if (kapali) return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneGrow} title={t.refTitle} onBack={onBack} />
      <View style={{ padding: SP[5] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 20 }}>{t.featureOffNotice}</Text>
      </View>
    </Sayfa>
  );
  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneGrow} title={t.refTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: ARA[14] }}>{t.refSub}</Text>
        {/* v1.64 (MVP paritesi): kayit Adim 1'deki REFERANS KODU alani MVP'de
            yok — kaldirildi. Islev kaybolmasin diye kod girisi BURAYA tasindi:
            davet edilen kisi kodu bu ekrandan uygular (apply_referral). */}
        <RefCodeEntry t={t} />
        <View style={[S.card, { alignItems: "center", paddingVertical: ARA[22] }]}>
          <Text style={{ fontSize: FS.xs, color: C.mut, letterSpacing: 1.5 }}>{t.refCode}</Text>
          <Text style={{ fontSize: FS.display, fontFamily: MONO[600], fontWeight: "700", color: C.gold, letterSpacing: 3, marginTop: SP[2] }}>{code || "..."}</Text>
          {/* 🔴 v2.99 — BU DÜĞME HİÇBİR ŞEY PAYLAŞMIYORDU.
              `onPress={() => setCopied(true)}` yalnız yazıyı "Kopyalandı"
              yapıyordu; panoda hiçbir şey yoktu. Altındaki üç kutu da
              `View` idi — düğme gibi görünüyor, dokunmaya tepki vermiyordu.
              Ölçüm: projede `Clipboard`, `Share` ya da `Linking.openURL`
              HİÇ import edilmemiş. Yani referans programı tamamen
              işlevsizdi ve üstelik ÇALIŞIYORMUŞ gibi yalan söylüyordu.

              Çözüm: React Native'in kendi `Share` API'si — ek bağımlılık
              yok, ve sistem paylaşım sayfası WhatsApp/e-posta/diğer'in
              üçünü de zaten içeriyor. Üç sahte kutu kalktı.

              🆕 SINIF: "ÇALIŞIYORMUŞ GİBİ GÖRÜNEN BİR DÜĞME, OLMAYAN BİR
              DÜĞMEDEN KÖTÜDÜR — ÇÜNKÜ KULLANICI ONU BİR KEZ DENER VE
              ÜRÜNÜN GERİ KALANINA DA GÜVENMEZ." */}
          <Btn label={copied ? t.refCopied : t.refShare} onPress={async () => {
              if (!code) return;
              setPaylasiyor(true);
              try {
                // 🔴 DEĞİŞKENİ `r` DİYE ADLANDIRMIŞTIM ve RPC alan nöbetçisi
                // `r.action`'ı `iletisim_epostam_yaz()`ın dönüşü sandı. Aynı
                // sınıf hatayı bu projede ikinci kez yaptım (v2.96: `k`).
                // 🆕 SINIF: "BİR DEĞİŞKEN ADI YALNIZ İNSANA DEĞİL, KAYNAĞI
                // ADLA İZLEYEN NÖBETÇİYE DE BİLDİRİMDİR."
                const paylasim = await Share.share({
                  message: String(t.refShareMsg || "").replace("{kod}", String(code)),
                });
                if (paylasim && paylasim.action === Share.sharedAction) setCopied(true);
              } catch (e) { logError("referans_paylas", e); }
              finally { setPaylasiyor(false); }
            }}
            disabled={!code || paylasiyor} busy={paylasiyor}
            style={{ marginTop: ARA[14], paddingHorizontal: ARA[26] }} />
        </View>
        {/* MVP: davet koşulları tablosu */}
        <View style={S.card}>
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.dim, letterSpacing: 1.5, marginBottom: SP[3] }}>{t.refConditions}</Text>
          {/* 🔵 v2.99 — "Guest → Guest" TÜRKÇE ARAYÜZDE İNGİLİZCE duruyordu. */}
          {[[t.refWhoGG, t.refCondGG, "+500"], [t.refWhoHH, t.refCondHH, "+1.000"], [t.refWhoGH, t.refCondGH, "+750"]].map(([who, when, pts], i, arr) => (
            <View key={who} style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: SP[2], borderBottomWidth: i < arr.length - 1 ? 1 : 0, borderBottomColor: C.line }}>
              <View>
                <Text style={{ fontSize: FS.sm, color: C.ink }}>{who}</Text>
                <Text style={{ fontSize: FS.xs, color: C.muted }}>{when}</Text>
              </View>
              <View style={{ backgroundColor: C.goldBg, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] }}>
                <Text style={{ fontSize: FS.xs, color: C.goldText, fontWeight: "600" }}>{pts} {t.ptsUnit}</Text>
              </View>
            </View>
          ))}
        </View>
        {invited.length > 0 && (
          <>
            <Text style={S.label}>{t.refInvited}</Text>
            {invited.map((n, i) => (
              <View key={i} style={[S.card, { flexDirection: "row", justifyContent: "space-between" }]}>
                <Text style={{ color: C.ink, fontSize: FS.sm }}>{n.name || "—"}</Text>
                <Text style={{ color: C.green, fontWeight: "700", fontSize: FS.sm }}>+500 {t.ptsUnit}</Text>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </Sayfa>
  );
}

// ============ HostAccessSource (§7.1) ============
export function HostAccessSource({ t, session, onDone, onBack, role, onBecomeHost }) {
  const uid = session?.user?.id;
  // MVP (parite): "kaynağını/kaynaklarını seç" — COKLU secim. Tek text
  // kolonuna ", " ile birlesik yazilir; okurken ayni ayracla cozulur.
  const [srcs, setSrcs] = useState([]);
  const [cap, setCap] = useState(null);
  // v1.88 — host'a SORULMAYAN iki soru:
  //   feePaid : misafir kapıda ücret ödüyor mu (PP/LoungeKey/DragonPass)
  //   quota*  : kalan hak (beyan; doğrulanamaz ama sorulabilir)
  const [feePaid, setFeePaid] = useState(null);
  const [qTotal, setQTotal] = useState("");
  const [qUsed, setQUsed] = useState("");
  const [qPeriod, setQPeriod] = useState("year");
  // v1.95 — HANGİ KART? `host_entitlements.card_product_id` bugüne kadar
  // hep NULL'dı; bu yüzden 087/088'de modellediğimiz kota, karekod şartı
  // ve "yalnız asıl kart" kuralı HİÇBİR ZAMAN devreye girmiyordu.
  const [cards, setCards] = useState([]);
  const [cardId, setCardId] = useState(null);
  const [cardOpen, setCardOpen] = useState(false);
  // 🔴 v2.24 — KAYNAK SECILINCE KURAL OZETI.
  // Host kurali OGRENDIGI an, ilani ACTIGI an degil KAYNAGI SECTIGI
  // andir. Sonra soylemek, yanlis beklentiyle ilerlemis birini geri
  // dondurmek demektir.
  const [srcSummary, setSrcSummary] = useState([]);   // v2.49: kaynak başına özet dizisi
  // 🔴 v1.99 — KART TİPİ. En kritik eksikti: THY/AJet'te misafir hakkı
  // kart tipine göre değişiyor (Classic Plus'ta HAK YOK) ama biz hiç
  // sormuyorduk. Karar motoru da bilmediği için en iyi ihtimali
  // varsayıyor ve Classic Plus'lı host'a "misafir hakkın var" diyordu.
  const [tiers, setTiers] = useState([]);
  // v2.69: PP/DragonPass plan ücretleri (SQL 196 plan_options)
  const [plans, setPlans] = useState([]);
  const [tier, setTier] = useState(null);
  const [tierOpen, setTierOpen] = useState(false);
  // 🔴 v2.67 (Gokberk madde 5) — İKİ AYNI KART, GERÇEK YOL.
  // "bende 2 tane M&S kartı var, birinde kendim diğerinde misafirim
  // gelebiliyor." SQL 193 üç RPC açtı ve önceki turun iki duvarını
  // kaldırdı:
  //   my_access_cards()  → kartları OKU (tabloda GRANT yok, tek yol bu)
  //   save_host_card()   → TEK karta dokunur, ötekileri SİLMEZ
  //   remove_host_card() → sahiplik şartlı silme
  // Bir önceki turda etiketi `p_sources` metnine gömüyorduk; o bir
  // kaçış yoluydu ve ikinci HAK SATIRI yaratmıyordu — kaldırıldı.
  const [myCards, setMyCards] = useState(null);   // null = yükleniyor
  const [progs, setProgs] = useState([]);         // guide_programs()
  const [draft, setDraft] = useState(null);       // { program, label, cap }
  const [draftOpen, setDraftOpen] = useState(false);
  // v2.89 (md.9) — program listesi katlanır; seçim yoksa açık başlar.
  const [progAcik, setProgAcik] = useState(true);
  // v2.89 (md.10) — "Bankayı kaydet" geri bildirimi
  const [bankOk, setBankOk] = useState(null);
  const [banks, setBanks] = useState({});         // { entId: { bank, product } }
  const [cardBusy, setCardBusy] = useState(null);
  // 19 Eylül · derin denetim — kart kaldırma onayı.
  const [kartSilAdayi, setKartSilAdayi] = useState(null);
  const [cardErr, setCardErr] = useState("");
  const [cardNote, setCardNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  useEffect(() => {
    (async () => {
      const { data, error: hata14 } = await supabase.rpc("my_host_access");
      if (hata14) logError("ekranlar_ana.js:3512", hata14);
      if (data?.access_source) setSrcs(erisimKaynaklari(data.access_source));
      if (data?.guest_capacity != null) setCap(data.guest_capacity);
      if (data?.guest_fee_expected != null) setFeePaid(!!data.guest_fee_expected);
      if (data?.quota_total != null) setQTotal(String(data.quota_total));
      if (data?.quota_used != null) setQUsed(String(data.quota_used));
      if (data?.quota_period) setQPeriod(data.quota_period);
      if (data?.card_product_id) setCardId(data.card_product_id);
      // 🔴 v3.9 — KART LİSTESİ İLE KADEME LİSTESİ SIRAYLA ÇEKİLİYORDU.
      // `card_tier_options`ın parametresi (`code`) YUKARIDAKİ profil
      // okumasından türüyor — `card_product_options`tan DEĞİL. Yani
      // ikinci sorgu birinciyi beklemek zorunda değildi; erişim kaynağı
      // ekranı bir tur fazladan bekliyordu.
      // Her ikisinin `catch` düşüşü ayrı ayrı korunuyor: biri düşerse
      // diğerinin listesi yine dolar (eskiden de böyleydi).
      const code = /ajet/i.test(String(data?.access_source || "")) ? "AJET_MS" : "TK_MS";
      const [cp, tl] = await Promise.all([
        supabase.rpc("card_product_options").then(r => r.data || []).catch(() => []),
        // Kart tipi listesi PROGRAMA bağlı; kart ağlarında (PP/LoungeKey)
        // kademe kavramı yok, o yüzden liste boş dönerse soru hiç çıkmaz.
        supabase.rpc("card_tier_options", { p_program_code: code })
          .then(r => r.data || []).catch(() => []),
      ]);
      setCards(cp);
      setTiers(tl);
      if (data?.tier) setTier(data.tier);
      // 🔴 v2.69 — PLAN ÜCRETLERİ EKRANA ÇIKIYOR (SQL 196).
      // `plan_options()` yazılmıştı ama hiçbir yerden çağrılmıyordu.
      // Host "Priority Pass'im var" derken hangi planda olduğunu ve o
      // planın misafire ne kadara mal olduğunu bilerek seçsin: Standard
      // 89 €/yıl ama ücretsiz ziyaret yok; Prestige 459 € ama misafir
      // yine 30 €. Bu, ilan açma kararını doğrudan değiştiren bilgi.
      try {
        const src = String(data?.access_source || "");
        const pcode = /dragon/i.test(src) ? "DRAGONPASS"
                    : /priority/i.test(src) ? "PRIORITY_PASS" : null;
        if (pcode) {
          const { data: pl, error: plErr } = await supabase.rpc("plan_options", { p_program_code: pcode });
          setPlans(plErr ? [] : (pl || []));
        } else setPlans([]);
      } catch (e) { setPlans([]); }
    })();
  }, [uid]);

  // 🔴 KART LİSTESİ TEK KAYNAKTAN: `my_access_cards()`.
  // host_entitlements'ta app'e tablo GRANT'i YOK; doğrudan sorgu 42501
  // döner. Sunucu bize `bank_dependent` ve `verified` bayraklarını da
  // veriyor — banka sorusunu bu bayrağa göre soruyoruz, kodda ikinci
  // bir program listesi tutmuyoruz.
  // 🔴 v2.70 — BEYAN YAZMA YOLU. Sunucu sahipliği doğruluyor (SQL 201);
  // istemci yalnız çağırıyor. Hata YUTULMUYOR: kullanıcı neden
  // kaydedilmediğini görüyor.
  const setBankCoverage = useCallback(async (entId, value) => {
    setCardBusy(entId);
    const { error } = await supabase.rpc("set_card_bank_coverage",
      { p_entitlement_id: entId, p_value: value });
    setCardBusy(null);
    if (error) { setCardErr(mapErr(t, error.message)); return; }
    setCardErr("");
    loadCardsRef.current && loadCardsRef.current();
  }, [t]);

  const loadCards = useCallback(async () => {
    const { data, error } = await supabase.rpc("my_access_cards");
    if (error) { setMyCards([]); setCardErr(mapErr(t, error.message)); return; }
    setMyCards(data || []);
  }, [t]);

  // v2.70: setBankCoverage loadCards'tan ÖNCE tanımlı (JS'te const
  // hoisting yok). Ref ile bağlıyoruz ki iki yönlü bağımlılık
  // kapalı kalsın ve useCallback zinciri kırılmasın.
  const loadCardsRef = useRef(null);
  loadCardsRef.current = loadCards;

  useEffect(() => { loadCards(); }, [loadCards]);

  useEffect(() => {
    (async () => {
      // Program katalogu SUNUCUDAN (guide_programs); kodda sabit liste yok.
      const { data, error } = await supabase.rpc("guide_programs");
      setProgs(error ? [] : (data || []));
    })();
  }, []);

  const cleanLabel = s => String(s || "").replace(/\s+/g, " ").trim().slice(0, 24);
  // Motorun gördüğü toplam: her kartın kendi kapasitesi toplanır.
  const cardsCap = (myCards || []).reduce((s, c) => s + (Number(c.guest_capacity) || 0), 0);

  // Tek karta dokunur — ötekiler yerinde kalır (save_host_card'ın sözü).
  async function saveCard(programCode, label, capacity, tierCode, bankCode, product) {
    setCardErr(""); setCardNote(""); setCardBusy(programCode + ":" + (label || ""));
    const { data, error } = await supabase.rpc("save_host_card", {
      p_program_code: programCode,
      p_tier: tierCode || null,
      p_card_label: cleanLabel(label) || null,
      p_guest_capacity: capacity == null ? null : capacity,
      p_bank_code: bankCode || null,
      p_card_product: product || null,
    });
    setCardBusy(null);
    if (error) { setCardErr(mapErr(t, error.message)); return false; }
    if (data && data.note) setCardNote(String(data.note));
    await loadCards();
    return true;
  }

  async function removeCard(entId) {
    setCardErr(""); setCardNote(""); setCardBusy(entId);
    const { error } = await supabase.rpc("remove_host_card", { p_entitlement_id: entId });
    setCardBusy(null);
    if (error) { setCardErr(mapErr(t, error.message)); return; }
    await loadCards();
  }

  async function save() {
    setErr(""); setBusy(true);
    // Beyan (kaynak metni, ücret beklentisi, kota) burada kalır.
    // KARTLAR artık burada DEĞİL: her biri kendi `save_host_card`
    // çağrısıyla kaydedilir ve bu fonksiyon onlara dokunmaz.
    // Kapasite: kart varsa kartların toplamı otoritedir, yoksa beyan.
    const { error } = await supabase.rpc("save_host_access", {
      p_sources: srcs,
      p_guest_capacity: cardsCap > 0 ? cardsCap : cap,
      p_guest_fee_expected: feePaid,
      p_quota_total: qTotal === "" ? null : parseInt(qTotal, 10),
      p_quota_period: qTotal === "" ? null : qPeriod,
      p_quota_used: qUsed === "" ? null : parseInt(qUsed, 10),
      p_card_product_id: cardId,
      p_card_tier: tier,
    });
    setBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    onDone && onDone();
  }

  // 🔴 v2.89 (Gökberk md.12) — EKRANIN KENDİ KAPISI.
  // Gezinme kapıları (App.js) bir yolu unutabilir — nitekim Profili
  // Düzenle yolu unutulmuştu. Ekranın kendisi de rolüne baksın: iki
  // kapı, çünkü bu ekrandan çıkan yazma (`save_host_access`) host
  // durumunu KURUYOR.
  // ⚠️ Kapı bir DUVAR değil, bir KAVŞAK: misafirin kartı gerçekten
  // varsa host'a geçmesi bir tıklama. Ürün tasarımı zaten "kart hakkını
  // beyan eden host olur" diyor; bunu engellemiyoruz, ADLANDIRIYORUZ.
  if (role === "guest") {
    return (
      <Sayfa>
        <Hdr t={t} ustBilgi={t.sceneHost} title={t.accessTitle} onBack={onBack || undefined} />
        <ScrollView contentContainerStyle={{ padding: ARA[18], paddingBottom: ARA[40] }}>
          <View style={[S.card, { borderColor: "transparent", borderWidth: 1.5 }]}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{t.hostOnly}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginTop: ARA[6] }}>{t.hostOnlyBody}</Text>
            {/* 🔴 v2.99 — DÜĞME ARTIK KOŞULLU ÇİZİLİYOR (yonlendirme_check).
                Bu ekranın İKİ çağrı yeri var ve yalnız biri `onBecomeHost`
                veriyor. Bugün zararsız: diğer çağrı yeri `role` prop'unu hiç
                geçmediği için bu kapı orada zaten çizilmiyor. Ama bu KAZAYLA
                doğru: biri `role={role}` eklese — son derece doğal bir
                değişiklik — hiçbir şey yapmayan bir "Host ol" düğmesi belirirdi.
                🆕 SINIF: "BİR DÜĞMENİN ÇALIŞMASI BAŞKA BİR PROP'UN
                UNUTULMASINA BAĞLIYSA, O DÜĞME ÇALIŞMIYOR — SADECE HENÜZ
                GÖRÜNMÜYOR." */}
            {onBecomeHost ? (
              <Btn label={t.becomeHost} onPress={() => onBecomeHost()} a11yLabel={t.becomeHost} style={{ marginTop: ARA[14] }} />
            ) : null}
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => onBack && onBack()}
              accessibilityRole="button" accessibilityLabel={t.backToGuest}
              style={{ minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center", marginTop: ARA[6] }}>
              <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.backToGuest}</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </Sayfa>
    );
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneHost} title={t.accessTitle} onBack={onBack || undefined} />
      <ScrollView contentContainerStyle={{ padding: ARA[18], paddingBottom: ARA[40] }}>
        {/* MVP: "• Host Kurulumu · Adım 1/2" pill'i (müsaitlik ekle = Adım 2/2) */}
        <View style={{ alignSelf: "flex-start", backgroundColor: C.goldBg, borderRadius: R.sm, paddingVertical: SP[1], paddingHorizontal: SP[3], marginBottom: SP[3] }}>
          <Text style={{ fontSize: FS.xs, color: C.goldText, fontWeight: "600" }}>• {t.hostSetupStep1}</Text>
        </View>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[4], lineHeight: 19 }}>{t.accessSub}</Text>

        <Text style={S.label}>{t.accessSource}</Text>
        {/* 🔴 v2.34 — SECIMLER TASIYORDU.
            flexWrap vardi ama TEK BIR chip ekrandan genis olabiliyordu:
            "Miles&Smiles Elite Plus" gibi uzun etiketler S.chip'in sabit
            dolgusuyla birlesince satira sigmiyordu. Sarmalama, TEK
            ogenin tasmasini cozmez — ogenin kendisi de sinirlanmali. */}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], width: "100%" }}>
          {ACCESS_SOURCES.map(a => { const on = srcs.includes(a); return (
            <TouchableOpacity key={a} onPress={async () => {
                const next = on ? srcs.filter(x => x !== a) : [...srcs, a];
                setSrcs(next);
                // Kaynak secilir secilmez kuralini ozetle. Banka karti ve
                // dogrulanmamis kaynaklarda sunucu zaten known:false doner
                // ve hicbir sey gostermeyiz — bilmedigimizi biliyormus
                // gibi gostermemek icin.
                // 🔴 v2.49 (cihazda görüldü): birden çok kaynak seçilince
                // TEK birleşik özet çıkıyordu — hangi uyarının hangi kaynağa
                // ait olduğu belirsizdi. Artık HER seçili kaynak için ayrı
                // özet istenir; bilinmeyenler (banka kartı vb.) sessizce
                // atlanır.
                try {
                  const results = await Promise.all(next.map(src =>
                    supabase.rpc("access_source_summary", { p_source: src })
                      .then(({ data }) => (data && data.known ? { src, ...data } : null))
                      .catch(() => null)));
                  setSrcSummary(results.filter(Boolean));
                } catch (e) { setSrcSummary([]); }
              }}
              style={[S.chip, { borderColor: on ? C.gold : C.line,
                                backgroundColor: on ? C.goldSoft : C.card,
                                maxWidth: "100%", flexShrink: 1 }]}>
              <Text numberOfLines={2}
                style={{ color: on ? C.gold : C.ink, fontSize: FS.sm,
                         fontWeight: on ? "700" : "400", flexShrink: 1 }}>{erisimEtiketi(t, a)}</Text>
            </TouchableOpacity>
          ); })}
        </View>
        {Array.isArray(srcSummary) && srcSummary.map(sm => (
          <View key={sm.src} style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent",
                         borderRadius: R.xs, padding: SP[3], marginTop: SP[1], marginBottom: ARA[10] }}>
            <View style={{ flexDirection: "row", alignItems: "center", marginBottom: SP[1] }}>
              <Text style={{ ...T.label, color: C.tealInk, flex: 1 }}>{sm.program}</Text>
              {/* 🔴 v2.50 — "⚠ doğrulanmadı" HER kaynakta çıkıyordu çünkü
                  sunucu bu alanı sabit false döndürüyordu (SQL 162). Artık
                  gerçek: kural resmî kaynaktan okunduysa TARİHİYLE söylenir;
                  bilmediğimiz kaynakta uyarı dürüstçe kalır. */}
              <Text style={{ fontSize: FS.xs, color: sm.verified ? C.green : C.amber }}>
                {sm.verified
                  ? t.cardVerifiedOn.replace("{d}", String(sm.checked_at || "").slice(0, 10))
                  : t.cardUnverified}
              </Text>
            </View>
            <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body }}>{sm.summary}</Text>
          </View>
        ))}

        <View style={{ flexDirection: "row", alignItems: "baseline", gap: ARA[6] }}>
          <Text style={S.label}>{t.accessCap}</Text>
          <Text style={{ color: C.red, fontSize: FS.xs, fontWeight: "600" }}>{t.accessCapCrit}</Text>
        </View>
        <View style={{ flexDirection: "row", gap: SP[2] }}>
          {[[1, t.cap1], [2, t.cap2], [0, t.capNone]].map(([v, lb]) => (
            <TouchableOpacity hitSlop={TAP.slop} key={v} onPress={() => setCap(v)}
              style={{ flex: 1, borderWidth: 1.5, borderColor: cap === v ? C.gold : C.line, backgroundColor: cap === v ? C.goldSoft : C.card, borderRadius: R.sm, paddingVertical: SP[3], alignItems: "center" }}>
              <Text style={{ color: cap === v ? C.gold : C.ink, fontWeight: "700", fontSize: FS.sm }}>{lb}</Text>
            </TouchableOpacity>
          ))}
        </View>
        {cap === 0 && (
          <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginTop: ARA[10] }}>
            <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.capNoneWarn}</Text>
          </View>
        )}

        {/* 🔴 v1.88 — DÖRDÜNCÜ SEÇENEK.
            Priority Pass / LoungeKey / DragonPass'te misafir GİREBİLİR ama
            ÜCRET ÖDER. Bu soru sorulmadığı için host "Evet, 1 misafir dahil"
            seçiyordu ve uygulama kapıda ödenecek parayı gizliyordu. */}
        {cap !== 0 && cap != null && (
          <View style={{ marginTop: SP[4] }}>
            <Text style={S.label}>{t.feeQ}</Text>
            {[[false, t.feeFree], [true, t.feePaidOpt]].map(([v, lb]) => (
              <TouchableOpacity hitSlop={TAP.slop} key={String(v)} onPress={() => setFeePaid(v)}
                style={{ flexDirection: "row", alignItems: "center", borderWidth: 1.5,
                         borderColor: feePaid === v ? C.gold : C.line,
                         backgroundColor: feePaid === v ? C.goldSoft : C.card,
                         borderRadius: R.sm, padding: SP[3], marginBottom: SP[2] }}>
                <View style={{ width: 18, height: 18, borderRadius: R.full, borderWidth: 2,
                               borderColor: feePaid === v ? C.gold : C.line, marginRight: ARA[10],
                               alignItems: "center", justifyContent: "center" }}>
                  {feePaid === v && <View style={{ width: 8, height: 8, borderRadius: R.full, backgroundColor: C.gold }} />}
                </View>
                <Text style={{ flex: 1, color: feePaid === v ? C.gold : C.ink, fontSize: FS.sm,
                               fontWeight: feePaid === v ? "700" : "400" }}>{lb}</Text>
              </TouchableOpacity>
            ))}
            {feePaid === true && (
              <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3] }}>
                <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.feePaidNote}</Text>
              </View>
            )}
          </View>
        )}

        {/* 🔴 v1.99 — KART TİPİ.
            Havayolu programlarında misafir hakkını belirleyen ASIL alan bu.
            Seçenekler veritabanındaki kural satırlarından geliyor, kodda
            sabit liste yok — kural değişirse ekran kendiliğinden değişir.
            Her seçeneğin yanında misafir hakkı yazıyor ki host yanlış
            seçtiğinde sonucu hemen görsün. */}
        {cap != null && tiers.length > 0 && (
          <View style={{ marginTop: SP[4] }}>
            <Text style={S.label}>{t.tierQ}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginBottom: SP[2] }}>{t.tierSub}</Text>
            <TouchableOpacity onPress={() => setTierOpen(v => !v)} style={S.pickBtn}>
              <Text style={{ color: tier ? C.ink : C.dim, fontSize: FS.base }}>
                {tier ? (tiers.find(x => x.tier === tier)?.label || tier) : t.tierNone}
              </Text>
            </TouchableOpacity>
            {tierOpen && (
              <View style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.xs, marginTop: ARA[6], overflow: "hidden" }}>
                {tiers.map(x => (
                  <TouchableOpacity hitSlop={TAP.slop} key={x.tier}
                    onPress={() => { setTier(x.tier); setTierOpen(false); }}
                    style={{ padding: SP[3], borderBottomWidth: 1, borderBottomColor: C.line,
                             backgroundColor: tier === x.tier ? C.goldSoft : "transparent" }}>
                    <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "600" }}>{x.label}</Text>
                    <Text style={{ color: (x.guest_allowance > 0) ? C.green : C.red, fontSize: FS.sm, marginTop: ARA[2] }}>
                      {x.guest_allowance > 0
                        ? `${x.guest_allowance} misafir${x.family_allowed ? " veya aile" : ""}`
                        : t.tierNoGuest}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            )}
            {!!tier && (tiers.find(x => x.tier === tier)?.guest_allowance === 0) && (
              <View style={{ backgroundColor: C.hataBg, borderRadius: R.xs, padding: SP[3], marginTop: SP[2] }}>
                <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>{t.tierNoGuestWarn}</Text>
              </View>
            )}
          </View>
        )}

        {/* 🔴 v2.69 — PLAN ve ÜCRET TABLOSU (Priority Pass / DragonPass).
            Rakamlar 196'da resmî plan sayfasından kaynağıyla girildi.
            Kaynağı da yazıyoruz: kaynaksız rakam, yanlış rakamla aynı
            riski taşır. */}
        {plans.length > 0 && (
          <View style={{ marginTop: SP[4], backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[3] }}>
            <Text style={{ ...T.label, color: C.mutedAA, marginBottom: SP[2] }}>
              {BUYUK(plans[0].plan_name || "").includes("GO") ? "DRAGONPASS" : "PRIORITY PASS"}
            </Text>
            {plans.map(pl => (
              <View key={pl.plan_code} style={{ marginBottom: SP[2] }}>
                <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>
                  {pl.plan_name} · {pl.annual_fee} {pl.currency} {t.planYearly}
                </Text>
                <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 17, marginTop: 0 }}>
                  {pl.member_free_visits == null
                    ? t.ownEntryFree
                    : pl.member_free_visits === 0
                      ? String(t.planNoFreeVisits).replace("{fee}", pl.member_visit_fee).replace("{cur}", pl.currency)
                      : String(t.planFreeVisits).replace("{n}", pl.member_free_visits)
                          .replace("{fee}", pl.member_visit_fee).replace("{cur}", pl.currency)}
                  {`  ·  ${t.planGuestFee} ${pl.guest_visit_fee} ${pl.currency}`}
                </Text>
              </View>
            ))}
            <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 15, marginTop: ARA[2] }}>
              {t.bankOverrideNote || "Kartını bir banka verdiyse planı ve ücreti banka üstlenmiş olabilir — bankandan teyit et."}
            </Text>
          </View>
        )}

        {/* 🔴 v1.95 — KART SEÇİMİ.
            "Kredi Kartı Avantajı" ya da "Banka / Özel Bankacılık" seçen
            host'a HANGİ KART olduğu sorulmuyordu. Oysa kota, karekod şartı
            ve misafir kuralı KARTA bağlı — kart bilinmeden bunların hiçbiri
            uygulanamaz. Kart seçilirse program da ondan gelir; serbest metin
            tahmini devreye girmez (host'un seçimi tahminden güvenilirdir).
            "Bilmiyorum" birinci sınıf cevap: listeyi boş bırakmak serbest. */}
        {cap !== 0 && cap != null && cards.length > 0 &&
         srcs.some(x => /kart|banka/i.test(String(x))) && (
          <View style={{ marginTop: SP[4] }}>
            <Text style={S.label}>{t.cardQ}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginBottom: SP[2] }}>{t.cardSub}</Text>
            <TouchableOpacity onPress={() => setCardOpen(v => !v)} style={S.pickBtn}>
              <Text style={{ color: cardId ? C.ink : C.dim, fontSize: FS.base }}>
                {cardId ? (cards.find(c => c.id === cardId)?.label || "—") : t.cardNone}
              </Text>
            </TouchableOpacity>
            {!!cardId && !cards.find(c => c.id === cardId)?.verified && (
              <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginTop: SP[2] }}>
                <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>
                  {cards.find(c => c.id === cardId)?.note || t.cardUnverifiedNote}
                </Text>
              </View>
            )}
            {cardOpen && (
              <View style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                             marginTop: ARA[6], maxHeight: 240, overflow: "hidden" }}>
                <ScrollView nestedScrollEnabled keyboardShouldPersistTaps="handled">
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setCardId(null); setCardOpen(false); }}
                    style={{ padding: SP[3], borderBottomWidth: 1, borderBottomColor: C.line }}>
                    <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.cardNone}</Text>
                  </TouchableOpacity>
                  {cards.map(c => (
                    <TouchableOpacity hitSlop={TAP.slop} key={c.id}
                      onPress={() => { setCardId(c.id); setCardOpen(false); }}
                      style={{ padding: SP[3], borderBottomWidth: 1, borderBottomColor: C.line,
                               backgroundColor: cardId === c.id ? C.goldSoft : "transparent" }}>
                      <View style={{ flexDirection: "row", alignItems: "center" }}>
                        <Text style={{ color: C.ink, fontSize: FS.sm, flex: 1 }}>{c.label}</Text>
                        {/* 🔴 v2.20 — GUVEN DERECESI GORUNMUYORDU.
                            Host listeden "TEB Infinite" seciyor, biz de misafire
                            "ayda 4 misafir hakki var" gibi KESIN bir cumle
                            kuruyorduk — oysa o rakami hicbir zaman dogrulamadik.
                            Dogrulanmamis bir rakam, "bilmiyoruz" demekten KOTUDUR:
                            kullanici tedbiri birakir. */}
                        <Text style={{ fontSize: FS.xs, color: c.verified ? C.green : C.amber }}>
                          {c.verified ? t.cardVerified : t.cardUnverified}
                        </Text>
                      </View>
                      {!!c.program_code && (
                        <Text style={{ color: C.mut, fontSize: FS.xs }}>{c.program_code}</Text>
                      )}
                    </TouchableOpacity>
                  ))}
                </ScrollView>
              </View>
            )}
          </View>
        )}

        {/* 🔴 v2.67 (Gokberk madde 5) — KARTLARIN, GERÇEK KAYITLA.
            SQL 193: `save_host_card` TEK karta dokunur, ötekileri
            silmez — ikinci M&S kartını imkânsız kılan tam da bu
            "toptan yeniden yaz" davranışıydı. Liste `my_access_cards()`
            ile okunur (tabloda GRANT yok), silme `remove_host_card`.
            Etiket İSTEĞE BAĞLI: boş bırakmak birinci sınıf cevap. */}
        {cap != null && cap !== 0 && (
          <View style={{ marginTop: ARA[18] }}>
            <Text style={S.label}>{t.cardsTitle}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginBottom: SP[2] }}>{t.cardLabelHint}</Text>

            {myCards === null ? <ActivityIndicator color={C.gold} /> : null}
            {myCards !== null && myCards.length === 0 && !draftOpen ? (
              <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: SP[2] }}>
                {t.cardsEmpty}
              </Text>
            ) : null}

            {(myCards || []).map(c => (
              <View key={c.id} style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                                        padding: SP[3], marginBottom: SP[2], backgroundColor: C.card , ...ELEV.card }}>
                <View style={{ flexDirection: "row", alignItems: "center" }}>
                  <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink, flex: 1 }}>
                    {c.card_label || t.cardRowUnnamed}
                  </Text>
                  <Text style={{ fontSize: FS.xs, color: c.verified ? C.green : C.amber }}>
                    {c.verified ? t.cardVerified : t.cardUnverified}
                  </Text>
                </View>
                <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[2] }}>
                  {c.program_name}{c.tier ? " · " + c.tier : ""}
                </Text>
                <Text style={{ fontSize: FS.sm, marginTop: ARA[2],
                               color: Number(c.guest_capacity) > 0 ? C.green : C.mut }}>
                  {Number(c.guest_capacity) > 0
                    ? String(t.cardCapRow).replace("{n}", String(c.guest_capacity))
                    : t.cardCapNoneRow}
                </Text>

                {/* 🔴 BANKA SORUSU YALNIZ SUNUCU "banka belirler" DEDİĞİNDE.
                    `bank_dependent` my_access_cards()'ten gelir; kodda ikinci
                    bir program listesi tutmuyoruz. 191'in bank_program_overrides
                    tablosu bu cevapla eşleşince motor kesin konuşabiliyor. */}
                {c.bank_dependent ? (
                  <View style={{ marginTop: SP[2], borderTopWidth: 1, borderTopColor: C.line, paddingTop: SP[2] }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.ink }}>{t.cardBankQ}</Text>
                    <Text style={{ fontSize: FS.sm, color: C.mut, lineHeight: 17, marginTop: ARA[2], marginBottom: SP[2] }}>
                      {t.cardBankHint}
                    </Text>
                    <TextInput
                      value={banks[c.id] ? banks[c.id].bank : (c.bank_code || "")}
                      onChangeText={v => setBanks(b => ({ ...b,
                        [c.id]: { bank: v.slice(0, 24), product: (b[c.id] ? b[c.id].product : (c.card_product || "")) } }))}
                      placeholder={t.cardBankPh} placeholderTextColor={C.dim}
                      style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line,
                               borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.base }} />
                    <TextInput
                      value={banks[c.id] ? banks[c.id].product : (c.card_product || "")}
                      onChangeText={v => setBanks(b => ({ ...b,
                        [c.id]: { bank: (b[c.id] ? b[c.id].bank : (c.bank_code || "")), product: v.slice(0, 40) } }))}
                      placeholder={t.cardProductPh} placeholderTextColor={C.dim}
                      style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line,
                               borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.base, marginTop: SP[2] }} />
                    {/* ══════════════════════════════════════════════════
                        🔴 v2.89 (Gökberk md.10) — "BANKAYI KAYDET ÇALIŞMIYOR"
                        ══════════════════════════════════════════════════
                        Ölçtüm: handler VAR, RPC VAR, grant VAR, kısıt VAR.
                        Buton gerçekten çalışıyordu. Kullanıcının "çalışmıyor"
                        demesinin dört sebebi vardı ve DÖRDÜ DE BİZİM:

                        (a) Boş alanla basılırsa sunucu `coalesce(excluded.
                            bank_code, host_entitlements.bank_code)` yapıyor →
                            hiçbir şey yazılmıyor, `ok:true` dönüyor. Alanı
                            TEMİZLEMEK de imkânsızdı.
                        (b) Başarıda geri bildirim YOK: RPC `note` alanını
                            yalnız o programda BİRDEN ÇOK kartı olan
                            kullanıcıya döndürüyor (193:101). Tek kartlı
                            kullanıcı hiçbir şey görmüyordu.
                        (c) Ekran değişmiyor: girdiler yerel `banks[c.id]`
                            state'inde, `saveCard` onu temizlemiyor. Sunucu
                            değeri büyük harfe çevirse bile ekranda eski
                            yazı duruyor. SIFIR piksel oynuyordu.
                        (d) Hata olursa `cardErr` ~150 satır aşağıda
                            basılıyor — ekranın dışında.

                        🆕 SINIF: **"ÇALIŞTIĞINI GÖSTERMEYEN BİR İŞLEM,
                        ÇALIŞMIYOR DEMEKTİR."**

                        Düzeltme: boş isim engelleniyor, sonuç KENDİ YANINDA
                        yazılıyor, adı da netleşiyor (banka VEYA kredi kartı). */}
                    <TouchableOpacity
                      disabled={cardBusy != null}
                      accessibilityRole="button" accessibilityLabel={t.bankSave2}
                      onPress={async () => {
                        const bank = (banks[c.id] ? banks[c.id].bank : c.bank_code) || "";
                        if (!String(bank).trim()) { setBankOk({ id: c.id, err: t.bankNeedName }); return; }
                        setBankOk(null);
                        const ok = await saveCard(c.program_code, c.card_label, c.guest_capacity, c.tier,
                          bank, (banks[c.id] ? banks[c.id].product : c.card_product) || null);
                        setBankOk(ok ? { id: c.id } : { id: c.id, err: cardErr || t.errGeneric });
                      }}
                      style={{ minHeight: TAP.minHeight, justifyContent: "center", marginTop: SP[2] }}>
                      <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>{t.bankSave2}</Text>
                    </TouchableOpacity>
                    {bankOk && bankOk.id === c.id ? (
                      <Text style={{ fontSize: FS.sm, fontWeight: "700", marginTop: SP[1],
                                     color: bankOk.err ? C.red : C.green }}>
                        {bankOk.err || t.bankSaved}
                      </Text>
                    ) : null}
                    {/* Ne işe yaradığı ARTIK YAZIYOR. Gökberk: "Bir de bu ne
                        işe yarıyor?" — soruyu soruyorsa ekran cevaplamıyor
                        demektir. */}
                    <Text style={{ fontSize: FS.xs, lineHeight: 15, color: C.mut, marginTop: ARA[6] }}>
                      {t.bankWhy}
                    </Text>

                    {/* 🔴 v2.70 — TEK SORU, BİZİM ARAŞTIRAMAYACAĞIMIZ CEVAP.
                        Banka banka tablo tutmuyoruz (SQL 201): efor yüksek,
                        veri sürekli bayatlıyor ve sorumluluk bize ait değil.
                        Ama cevabı BİLEN biri var — kartın sahibi. Tek dokunuş,
                        %100 isabet. Beyan bir KANIT DEĞİL: motor her cümlede
                        "senin beyanın" diyor ve "kapıda teyit et" uyarısını
                        koruyor. */}
                    <Text style={{ ...T.label, color: C.mut, marginTop: SP[3], marginBottom: ARA[6] }}>
                      {t.bankCoverQ}
                    </Text>
                    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6] }}>
                      {[["yes", t.bankCoverYes], ["no", t.bankCoverNo], ["unknown", t.bankCoverUnknown]].map(([k, lb]) => {
                        const on = (c.bank_covers_fee || "") === k;
                        return (
                          <TouchableOpacity key={k} accessibilityRole="button" accessibilityLabel={lb}
                            disabled={cardBusy != null}
                            onPress={() => setBankCoverage(c.id, on ? null : k)}
                            style={{ minHeight: TAP.minHeight, minWidth: TAP.minWidth,
                                     justifyContent: "center", paddingHorizontal: SP[3],
                                     borderRadius: R.full, borderWidth: 1,
                                     borderColor: on ? C.gold : C.line,
                                     backgroundColor: on ? C.goldSoft : C.card }}>
                            <Text style={{ fontSize: FS.sm, color: on ? C.gold : C.ink,
                                           fontWeight: on ? "700" : "400" }}>{lb}</Text>
                          </TouchableOpacity>
                        );
                      })}
                    </View>

                    {/* Motorun ÜÇ KATMANLI cevabı — bilinen / bankanın
                        değiştirebildiği / tek eylem. Metin sunucudan gelir;
                        app kendi cümlesini yazmaz (BO'dan düzenlenebilsin). */}
                    {!!c.bank_note && c.bank_note.bank_dependent ? (
                      <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, padding: SP[3], marginTop: SP[2] }}>
                        {!!c.bank_note.biliyoruz && (
                          <Text style={{ fontSize: FS.sm, color: C.ink, lineHeight: 17 }}>
                            {c.bank_note.biliyoruz}
                          </Text>
                        )}
                        {!!c.bank_note.beyan && (
                          <Text style={{ fontSize: FS.sm, color: C.teal, lineHeight: 17, marginTop: ARA[6] }}>
                            {c.bank_note.beyan}
                          </Text>
                        )}
                        {!!c.bank_note.banka_degistirebilir && (
                          <Text style={{ fontSize: FS.xs, color: C.mutedAA, lineHeight: 15, marginTop: ARA[6] }}>
                            {c.bank_note.banka_degistirebilir}
                          </Text>
                        )}
                        {!!c.bank_note.ne_yapmalisin && (
                          <Text style={{ fontSize: FS.xs, color: C.mut, lineHeight: 15, marginTop: SP[1] }}>
                            {c.bank_note.ne_yapmalisin}
                          </Text>
                        )}
                      </View>
                    ) : null}
                  </View>
                ) : null}

                <View style={{ flexDirection: "row", gap: ARA[14], marginTop: SP[1] }}>
                  <TouchableOpacity
                    disabled={cardBusy != null}
                    onPress={() => { setDraft({ program: c.program_code, label: "", cap: 1 }); setDraftOpen(true); }}
                    style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
                    <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>+ {t.addAnotherCard}</Text>
                  </TouchableOpacity>
                  {/* 🔴 19 EYLÜL · DERİN DENETİM — ONAY EKLENDİ.
                      Kartı kaldırmak `profiles.guest_capacity`yi düşürüyor;
                      kapasite düşünce host'un AÇIK İLANLARI da geçersiz
                      hâle gelebiliyor (SQL 295'teki `slots_exceed_capacity`
                      kapısı bunu söylüyor). Yani bu, tek dokunuşluk bir
                      görünüm ayarı değil, ilanları etkileyen bir karar. */}
                  <TouchableOpacity
                    disabled={cardBusy != null}
                    onPress={() => setKartSilAdayi({ id: c.id, ad: c.program_name || c.label || "" })}
                    accessibilityRole="button" accessibilityLabel={t.cardRemove}
                    style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
                    <Text style={{ color: C.red, fontSize: FS.sm, fontWeight: "700" }}>{t.cardRemove}</Text>
                  </TouchableOpacity>
                </View>
              </View>
            ))}

            {/* YENİ KART TASLAĞI */}
            {draftOpen && draft ? (
              <View style={{ borderWidth: 1.5, borderColor: "transparent", borderRadius: R.xs,
                             padding: SP[3], marginBottom: SP[2], backgroundColor: C.goldSoft }}>
                {/* 🔴 v2.89 (Gökberk md.9) — PROGRAM LİSTESİ KATLANIYOR.
                    20+ program çipi ekranı doldurup altındaki alanları
                    (kart etiketi, statü, banka) kaydırmanın dibine
                    itiyordu. Seçim YAPILDIKTAN sonra 20 seçeneği ekranda
                    tutmanın hiçbir faydası yok.
                    · seçim yoksa AÇIK başlar (seçmesi gereken şey bu)
                    · seçim varsa KAPALI başlar ve seçilen program özet
                      satırında yazar — bilgi kaybolmuyor, yer açılıyor */}
                <TouchableOpacity hitSlop={TAP.slop}
                  onPress={() => setProgAcik(v => !v)}
                  accessibilityRole="button"
                  accessibilityLabel={progAcik ? t.programClose : t.programOpen}
                  style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between",
                           minHeight: TAP.minHeight, marginTop: ARA[6] }}>
                  <View style={{ flex: 1, paddingRight: SP[2] }}>
                    <Text style={S.label}>{t.cardProgramQ}</Text>
                    {!progAcik && draft.program ? (
                      <Text numberOfLines={1} style={{ fontSize: FS.sm, color: C.goldText, fontWeight: "700" }}>
                        {(progs.find(p => p.code === draft.program) || {}).name || draft.program}
                      </Text>
                    ) : null}
                  </View>
                  <Ikon ad={progAcik ? "yukari" : "asagi"} boy={14} renk={C.mut} />
                </TouchableOpacity>
                {progAcik && (
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: SP[1] }}>
                  {progs.map(p => (
                    <TouchableOpacity key={p.code}
                      onPress={() => { setDraft(d => ({ ...d, program: p.code })); setProgAcik(false); }}
                      style={[S.chip, { minHeight: TAP.minHeight, justifyContent: "center",
                                        maxWidth: "100%", flexShrink: 1,
                                        borderColor: draft.program === p.code ? C.gold : C.line,
                                        backgroundColor: draft.program === p.code ? C.card : C.card }]}>
                      <Text numberOfLines={2}
                        style={{ fontSize: FS.sm, flexShrink: 1,
                                 color: draft.program === p.code ? C.gold : C.ink,
                                 fontWeight: draft.program === p.code ? "700" : "400" }}>{p.name}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
                )}

                <Text style={S.label}>{t.cardLabelTitle}</Text>
                <TextInput value={draft.label}
                  onChangeText={v => setDraft(d => ({ ...d, label: v.slice(0, 24) }))}
                  placeholder={t.cardRowUnnamed} placeholderTextColor={C.dim}
                  style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
                           borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.base , ...ELEV.card }} />

                <View style={{ flexDirection: "row", gap: SP[2], marginTop: SP[2] }}>
                  {[[1, t.cap1], [2, t.cap2], [0, t.capNone]].map(([v, lb]) => (
                    <TouchableOpacity key={v} onPress={() => setDraft(d => ({ ...d, cap: v }))}
                      style={{ flex: 1, minHeight: TAP.minHeight, justifyContent: "center",
                               borderWidth: 1.5, borderRadius: R.xs, alignItems: "center",
                               borderColor: draft.cap === v ? C.gold : C.line,
                               backgroundColor: draft.cap === v ? C.card : C.card }}>
                      <Text style={{ fontSize: FS.sm, fontWeight: "700",
                                     color: draft.cap === v ? C.gold : C.ink }}>{lb}</Text>
                    </TouchableOpacity>
                  ))}
                </View>

                <View style={{ flexDirection: "row", gap: ARA[14], marginTop: SP[2] }}>
                  <TouchableOpacity
                    disabled={!draft.program || cardBusy != null}
                    onPress={async () => {
                      const ok = await saveCard(draft.program, draft.label, draft.cap, null, null, null);
                      if (ok) { setDraft(null); setDraftOpen(false); }
                    }}
                    style={{ minHeight: TAP.minHeight, justifyContent: "center",
                             opacity: draft.program ? 1 : 0.45 }}>
                    <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>{t.cardSaveBtn}</Text>
                  </TouchableOpacity>
                  <TouchableOpacity onPress={() => { setDraft(null); setDraftOpen(false); }}
                    style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
                    <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "700" }}>{t.cardCancelBtn}</Text>
                  </TouchableOpacity>
                </View>
              </View>
            ) : (
              <TouchableOpacity
                onPress={() => { setDraft({ program: null, label: "", cap: 1 }); setDraftOpen(true); }}
                style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
                <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>+ {t.cardAddBtn}</Text>
              </TouchableOpacity>
            )}

            {!!cardErr && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{cardErr}</Text></View>}
            {/* Motorun kendi cümlesi — kendi metnimizi yazmıyoruz. */}
            {!!cardNote && (
              <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent",
                             borderRadius: R.xs, padding: SP[3], marginTop: SP[2] }}>
                <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body }}>{cardNote}</Text>
              </View>
            )}

            {cardsCap > 0 && (
              <Text style={{ fontSize: FS.sm, color: C.tealInk, fontWeight: "700", marginTop: ARA[10] }}>
                {String(t.cardTotalCap).replace("{n}", String(cardsCap))}
              </Text>
            )}
          </View>
        )}

        {/* 🔴 v1.88 — KALAN HAK. Doğrulayamayız (banka API'si yok) ama
            SORABİLİRİZ. Beyan, hiç bilmemekten iyidir. */}
        {cap !== 0 && cap != null && (
          <View style={{ marginTop: ARA[18] }}>
            <Text style={S.label}>{t.quotaQ}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginBottom: SP[2] }}>{t.quotaSub}</Text>
            <View style={{ flexDirection: "row", gap: SP[2], marginBottom: SP[2] }}>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: FS.xs, color: C.muted, marginBottom: SP[1], letterSpacing: 0.8 }}>{t.quotaTotal}</Text>
                <TextInput value={qTotal} onChangeText={v => setQTotal(v.replace(/[^0-9]/g, "").slice(0, 3))}
                  keyboardType="number-pad" placeholder="8" placeholderTextColor={C.dim}
                  style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                           padding: SP[3], color: C.body, fontSize: FS.base }} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: FS.xs, color: C.mutedAA, marginBottom: SP[1], letterSpacing: 0.8 }}>{t.quotaUsed}</Text>
                <TextInput value={qUsed} onChangeText={v => setQUsed(v.replace(/[^0-9]/g, "").slice(0, 3))}
                  keyboardType="number-pad" placeholder="0" placeholderTextColor={C.dim}
                  style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                           padding: SP[3], color: C.body, fontSize: FS.base }} />
              </View>
            </View>
            <View style={{ flexDirection: "row", gap: SP[2] }}>
              {[["year", t.quotaYear], ["month", t.quotaMonth], ["unlimited", t.quotaUnlimited]].map(([v, lb]) => (
                <TouchableOpacity key={v} onPress={() => setQPeriod(v)}
                  style={[S.chip, { borderColor: qPeriod === v ? C.teal : C.line,
                                    backgroundColor: qPeriod === v ? C.tealBg : C.card }]}>
                  <Text style={{ fontSize: FS.sm, color: qPeriod === v ? C.teal : C.muted,
                                 fontWeight: qPeriod === v ? "700" : "400" }}>{lb}</Text>
                </TouchableOpacity>
              ))}
            </View>
            {qTotal !== "" && qUsed !== "" && parseInt(qUsed, 10) >= parseInt(qTotal, 10) && (
              <View style={{ backgroundColor: C.hataBg, borderRadius: R.xs, padding: SP[3], marginTop: ARA[10] }}>
                <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>{t.quotaExhausted}</Text>
              </View>
            )}
          </View>
        )}

        {!!err && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
        {/* ══════════════════════════════════════════════════════════════
            🔴 19 EYLÜL · DERİN DENETİM — "KAYDET" GRİYDİ, SEBEBİ YOKTU.
            `disabled={!srcs.length || cap == null || cap === 0 || busy}`
            ÜÇ ayrı sebep tek bir gri düğmede birleşiyordu ve ekranda
            hiçbirini söyleyen tek kelime yoktu. Host formu dolduruyor,
            Kaydet gri kalıyor, hangisinin eksik olduğunu deneme-yanılma
            ile arıyor.
            Sessizce devre dışı bir düğme, bozuk bir düğmeden ayırt
            edilemez — bu turda üçüncü kez aynı sınıf (bkz. md.14).
            ══════════════════════════════════════════════════════════════ */}
        {(!srcs.length || cap == null || cap === 0) && (
          <Text style={{ color: C.mutedAA, fontSize: FS.sm, lineHeight: 18, marginTop: ARA[14] }}>
            {!srcs.length ? t.accessWhyNoSource : t.accessWhyNoCap}
          </Text>
        )}
        <Btn label={t.accessSave} onPress={save} disabled={!srcs.length || cap == null || cap === 0 || busy} busy={busy} style={{ marginTop: ARA[18], opacity: (!srcs.length || cap == null || cap === 0) ? 0.45 : 1 }} />
      </ScrollView>
      <ConfirmModal
        visible={!!kartSilAdayi}
        title={t.cardRemoveTitle}
        body={String(t.cardRemoveBody || "").replace("{ad}", kartSilAdayi?.ad || "")}
        confirmLabel={t.cardRemove}
        cancelLabel={t.confirmNo}
        danger
        busy={cardBusy === kartSilAdayi?.id}
        onCancel={() => setKartSilAdayi(null)}
        onConfirm={async () => { const id = kartSilAdayi?.id; setKartSilAdayi(null); if (id) await removeCard(id); }}
      />
    </Sayfa>
  );
}

// ============ HostBroadcast (§7.4) ============

// ============ LiveStatus (§25) ============
// MVP "Session · Live Status" — oturum sırasında durum paylaşımı (konum DEĞİL)
export function ActionNeeded({ t, lang, onRefresh, onOpenChat, onOpenLoungeChat, tamEkran, tazele }) {   // v2.65: ölü `session` kaldırıldı
  const [items, setItems] = useState([]);
  const [busy, setBusy] = useState(null);
  // 🔴 v6.1 (Gökberk md.15 · md.c) — "kabul ettiğim davete bir daha
  // ulaşamıyorum". Kabul, daveti bekleyenler listesinden düşürüyordu ve
  // hiçbir ekran "kabul ettiklerin" demiyordu. Tam ekranda artık ikinci
  // bölüm var: yaklaşan kabul edilmiş davetler, sohbete tek dokunuş.
  const [kabuller, setKabuller] = useState([]);
  const kabulYukle = useCallback(async () => {
    if (!tamEkran) return;
    const [inv, sr] = await Promise.all([
      supabase.from("invites").select("avail_id").eq("status", "accepted"),
      supabase.rpc("my_sent_requests"),
    ]);
    if (inv.error) { logError("invites.accepted", inv.error); return; }
    if (sr.error) { logError("my_sent_requests", sr.error); return; }
    const ids = new Set((inv.data || []).map(x => x.avail_id));
    const bugun = new Date().toISOString().slice(0, 10);
    setKabuller((sr.data || []).filter(r => r.status === "accepted" && ids.has(r.avail_id)
      && String(r.avail_date || "") >= bugun));
  }, [tamEkran]);
  useEffect(() => { kabulYukle(); }, [kabulYukle, tazele]);

  const load = useCallback(async () => {
    // 🔴 Hata yutuluyordu: bekleyen davetler KAYBOLUYOR ve üstüne `SakinGun`
    // "Bekleyen bir işin yok" yazıyordu. İki yalan üst üste.
    const { data, error: eAct } = await supabase.rpc("pending_actions");
    if (eAct) { logError("pending_actions", eAct); return; }
    setItems(data || []);
  }, []);
  // 🔴 18 EYLÜL (Gökberk md.1 · md.6) — `tazele` BAĞIMLILIĞA GİRDİ.
  // Belirti: "mesaj yanıtla tıkladığımda already_responded döndü" ve
  // "isteği ana sayfada kabul etmiş olmama rağmen bağlantılar sayfasında
  // hâlâ kabul et butonu çıkıyor".
  // Ölçüm: bu listeyi okuyan DÖRT ayrı yer var (ActionNeeded ·
  // HomeConnections · Meet · RequestsPanel) ve her biri kendi `load`unu
  // kendi bağımlılığıyla çalıştırıyordu. Biri cevap veriyor, ötekiler
  // bayat kalıyordu. Bayat bir listeden basılan "Kabul et", sunucuya
  // ikinci kez gidiyor ve sunucu haklı olarak 'already_responded' diyor —
  // yani kullanıcının gördüğü hata, aslında ekranın kendi hafızasıydı.
  // 🆕 SINIF: "AYNI GERÇEĞİ OKUYAN HER EKRANIN AYRI BİR TAZELEME ANAHTARI
  // VARSA, ONLARDAN BİRİ HER ZAMAN YANLIŞTIR — VE HANGİSİ OLDUĞUNU
  // KULLANICI SUNUCU HATASINDAN ÖĞRENİR."
  useEffect(() => { load(); }, [load, tazele]);

  const [hata, setHata] = useState("");
  async function respond(kind, id, accept) {
    setBusy(id); setHata("");
    const fn = kind === "invite" ? "respond_invite" : "respond_connection";
    // 🔴 v2.95 — HATA YUTULUYORDU. `await supabase.rpc(...)` sonucu HİÇ
    // okunmuyordu: sunucu 'already_responded', 'blocked_pair' ya da
    // 'not_recipient' dese bile ekranda hiçbir şey olmuyor, kart yerinde
    // kalıyordu. Kullanıcı için bu "buton bozuk" demek — v1.75'te
    // RequestsPanel'de teşhis edip düzelttiğim hatanın AYNISI, başka
    // ekranda. "Bir kusurun bir yerde çözülmesi, aynı kusurun diğer
    // yerlerde çözüldüğü anlamına gelmez."
    const { error } = await supabase.rpc(fn, { p_id: id, p_accept: accept });
    setBusy(null);
    if (error) { setHata(mapErr(t, error.message)); return; }
    load(); kabulYukle();
    onRefresh && onRefresh();
  }

  const kabulBolumu = tamEkran && kabuller.length > 0 ? (
    <View style={{ marginTop: items.length ? ARA[22] : 0 }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1.2, marginBottom: SP[2] }}>
        {BUYUK(t.invAcceptedTitle)}</Text>
      {kabuller.map(r => (
        <View key={r.id} style={[S.card, { borderTopColor: C.parlamaGuc }]}>
          <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{shortName(r.host_name)}</Text>
          <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>
            {[r.lounge_name || r.airport_code, fmtLongDate(r.avail_date, lang),
              r.time_from ? `${String(r.time_from).slice(0, 5)}–${String(r.time_to || "").slice(0, 5)}` : null]
              .filter(Boolean).join(" · ")}
          </Text>
          {!!onOpenLoungeChat && (
            <Btn v="ghost" sm full label={t.openChat} solAd="sohbet" style={{ marginTop: ARA[10] }}
              onPress={() => onOpenLoungeChat({ req: r, name: r.host_name })} />
          )}
        </View>
      ))}
    </View>
  ) : null;

  // Blokken boşsa kaybolur, tam ekranken kendini açıklar (aynı sınıf:
  // `RequestsPanel` · md.3).
  if (!items.length) {
    if (!tamEkran) return null;
    return kabulBolumu || <BosDurum ikon="eposta" metin={t.flowInvitesEmpty} ortala pano={{ baslik: t.panoDavetBas, durum: t.panoDavetDurum }} />;
  }
  return (
    /* 5 Eylül — ÖLÇÜLDÜ (web sahne 11): başlık "BUGÜN" kartının alt
       kenarına yapışıyordu (kartın alt boşluğu yok). Üst boşluk burada. */
    <View style={{ marginTop: tamEkran ? 0 : ARA[18], marginBottom: ARA[14] }}>
      {/* Tam ekranda başlık `Hdr`de; ikinci kez yazmak tekrar olurdu. */}
      {!tamEkran && (
        <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.gold, letterSpacing: 1.5, marginBottom: SP[2] }}>
          {t.actionNeeded}
        </Text>
      )}
      {!!hata && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{hata}</Text></View>}
      {items.map(it => {
        // MVP: davet ALTIN, bağlantı MOR çerçeve/buton. Alt satır MVP metni.
        const isInv = it.kind === "invite";
        // gece sisteminde mor yok: davet ALTIN, bağlantı TEAL (tasarım 13'ün
        // "Kabul et" çipiyle aynı aile).
        const accent = isInv ? C.gold : C.teal;
        const accentBg = isInv ? C.goldSoft : C.tealBg;
        // 🔴 `t.intents` bir ÇİFT LİSTESİ ([["coffee","…"],…]), sözlük değil:
        // `t.intents[it.subtitle]` hep undefined kalıyor, ekrana ham kod
        // ("· connect") düşüyordu. Listede olmayan niyet (varsayılan
        // "connect") hiç yazılmaz.
        const niyet = !isInv && it.subtitle
          ? ((Array.isArray(t.intents) ? t.intents : []).find(x => x[0] === it.subtitle) || [])[1] : null;
        // 5 Eylül — ÖLÇÜLDÜ (SEED6 · host1): kural sorusu "bağlantı kurmak
        // istiyor" diye çiziliyordu. Soru sorudur: alt satır + "Yanıtla".
        const soru = !isInv && it.subtitle === "kural_sorusu";
        // 5 Eylül — ÖLÇÜLDÜ (SEED6 · guest1): davet kartı "TAV P. · Lounge
        // daveti · IST · 2026-09-05" çiziyordu — salon adı `shortName`den
        // geçip kısalmış, tarih ham ISO. Başlık DAVET EDEN kişi; salon ve
        // "5 Eylül" alt satırda.
        const altBilgi = String(it.subtitle || "").replace(/\d{4}-\d{2}-\d{2}/, (m) => fmtLongDate(m, lang));
        const subLine = isInv
          ? [t.anInvite, it.title, altBilgi].filter(Boolean).join(" · ")
          : soru ? t.anRuleQuestion
          : t.anWantsConnect + (niyet ? " · " + niyet : "");
        return (
        <View key={it.id} style={[S.card, { borderTopColor: C.parlamaGuc }]}>
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <View style={{ width: 36, height: 36, borderRadius: R.full, backgroundColor: accentBg, alignItems: "center", justifyContent: "center", overflow: "hidden", marginRight: ARA[10] }}>
              {it.from_photo ? <Image source={{ uri: it.from_photo }} style={{ width: 36, height: 36 }} />
                : <Text style={{ fontWeight: "700", color: accent }}>{shortName(it.from_name).charAt(0)}</Text>}
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{shortName(isInv ? (it.from_name || it.title) : (it.title || it.from_name))}</Text>
              <Text style={{ color: accent, fontSize: FS.sm, marginTop: 0 }}>{subLine}</Text>
            </View>
          </View>
          {!!it.note && (
            <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, padding: ARA[10], marginTop: SP[2] }}>
              <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 17, fontStyle: "italic" }}>"{it.note}"</Text>
            </View>
          )}
          <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
            {/* Varyant `accent`in AYNI KOŞULUNDAN türüyor (isInv → altın,
                değilse mor); ikinci bir renk kararı yok. */}
            <Btn v={isInv ? "gold" : "purple"} sm label={soru ? t.anAnswer : t.accept}
              onPress={() => respond(it.kind, it.id, true)}
              disabled={busy === it.id} busy={busy === it.id} style={{ flex: 1 }} />
            <Btn v="muted" sm label={t.decline} onPress={() => respond(it.kind, it.id, false)}
              disabled={busy === it.id} style={{ flex: 1 }} />
          </View>
        </View>
      ); })}
      {kabulBolumu}
    </View>
  );
}

// ============ Settings modal'ları (§22) ============
// SettingsModals KALDIRILDI (v1.22): sifre/telefon/e-posta duzenleme artik
// ayri Settings ekraninin icinde (MVP v15 satir 2829 yapisi). Bu bilesen
// Profil sekmesinin dibindeki eski modal sisteminin kalintisiydi ve
// hicbir yerden cagrilmiyordu.
// ============================================================
// HİKÂYE DAVETİ (v2.88) — sitedeki referans bölümünü DOLDURAN yer
//
// 🔴 NEDEN VAR: Sitenin host bölümündeki her cümleyi ben yazdım. Bir
// yabancının yanına oturmayı anlatan bir üründe en ikna edici cümle,
// benim yazabileceğim hiçbir cümle değil. Siteye uydurma referans
// koymak yerine, SQL 230 ile toplayan makineyi kurduk.
//
// 🔴 AMA MAKİNE, KİMSE TETİKLEMEZSE ÇALIŞMAZ. Bir RPC yazıp "artık
// hikâye toplayabiliyoruz" demek, 228'de düştüğüm tuzağın aynısı
// olurdu: kuralı METNE yazmak, onu SİSTEMDE uygulamak değildir.
// Bu kart o tetik — ana sayfada, ağırladıktan sonra, TEK SORU.
//
// ÜÇ SINIR, BİLEREK:
//   · Tek davet gösterilir (bekleyen_hikaye_daveti LIMIT 1). Üst üste
//     istemek davet değil baskıdır.
//   · Rıza AYRI bir onaydır ve varsayılanı KAPALI. Yazmak ≠ yayına izin.
//   · "Şimdi değil" kalıcıdır: boş metinle kaydedilir, bir daha sorulmaz.
// ============================================================
// ============================================================
// SORDUKLARIM (v2.89 · Gökberk md.5)
//
// Gökberk: "ben guest olarak bu aksiyonu yaptığımda ne ana sayfa ne de
// başka bir yerde bu aksiyonuma dair bir şey göremiyorum."
//
// Ölçtüm ve haklı — üstelik sandığından beter:
//   · `pending_actions()` YALNIZ gelen istekleri döndürüyor (to_id);
//     soran `from_id` olduğu için kendi sorusu hiçbir yerde yok
//   · soru gönderilince misafire HİÇ bildirim yazılmıyordu
//   · sohbet kanalı ancak host KABUL ederse açılıyor → bekleyen soru
//     hiçbir sohbet listesinde görünmüyor
//   · Tanış sekmesinde host KAYBOLUYOR (rel='pending' filtreleniyor),
//     yani soru sormak host'u listeden siliyordu
//   · karttaki "Soru gönderildi" yazısı bileşen state'i; Keşfet
//     kapanınca yok oluyor
//
// 🆕 SINIF: **"BİR EYLEMİN İZİ YOKSA, KULLANICI ONU YAPMADIĞINI SANIR —
// VE İKİNCİ KEZ YAPAR."**
//
// SQL 235 hem `sorularim()` RPC'sini hem de iki tetikleyiciyi kurdu
// (soru gönderilince sorana bildirim, host hakkını beyan edince sorana
// bildirim). Bu kart o veriyi ana sayfaya getiriyor.
// Veri yoksa `null` döner — boş kutu çizmiyoruz.
// ============================================================
// ============================================================
// HABER VER  (v2.93 · SQL 247)
//
// 🔴 NEDEN: Boş keşif ekranı, erken dönem pazaryerlerinin öldüğü yer.
// Kullanıcı ilan bulamaz, kapatır, bir daha açmaz. Oysa o anda ürüne
// en yakın olduğu noktadadır — bir ihtiyacı vardır.
//
// Bu bileşen o anı yakalıyor: "haber ver" diyen kullanıcı gitmiyor, ve
// biz host tarafına "bu tarihte N kişi bekliyor" diyebiliyoruz.
//
// ⚠️ SESSİZ BAŞARI YOK: kayıt sonrası kaç kişinin aynı aralıkta
// beklediğini gösteriyoruz. "Kaydettim" demek yetmez; kullanıcının o
// anda merak ettiği şey "umut var mı".
// ============================================================

// ============================================================
// EditProfile — MVP v15 satir 3142-3256'nin portu. AYRI EKRAN.
//
// MVP'de bu ekran vardi ve profil tamamlanma cubugunu CANLI gosteriyordu
// (form degistikce yuzde degisir). v1.21'e kadar app'te hic yoktu; kullanici
// meslegini/bio'sunu hicbir yerden duzenleyemiyordu -> guven puani 10'da
// takili kaliyordu (bkz. ekran goruntusu: "Meslek —, Diller —").
//
// MVP secenekleri BIREBIR:
//   profOpts: Tech/Finance/Consulting/Healthcare/Legal/Media/Startup/Academia/Other
//   langOpts: English/Turkish/French/German/Arabic/Spanish/Japanese/Chinese
// Fotograf yukleme MVP'de FileReader/base64'tu; bizde Supabase Storage
// (024 SQL: avatars bucket) — HostAccessSource'taki mevcut akisi kullanir.
// ============================================================
// 🔴 v2.65 — SEÇENEK ETİKETLERİ i18n'E BAĞLANDI.
// Liste sabit Türkçeydi: lang="en" seçen kullanıcı meslek seçeneklerini
// Türkçe görüyordu. Depoya yazılan DEĞER değişmedi (kanonik anahtar), yalnız
// GÖSTERİLEN etiket çevriliyor — eski kayıtlar bozulmasın diye.
export function EditProfile({ t, session, onBack, onDone, onVerify, onVerifyId, onAccess, onHostApply }) {
  // v2.50: doğrulama satırları artık gerçek aksiyon taşıyor (aşağıya bak).
  const liRef = useRef(null);
  const scRef = useRef(null);
  const uid = session?.user?.id;
  const [form, setForm] = useState(null);
  const [verif, setVerif] = useState({});
  const [myRole, setMyRole] = useState("guest");
  const [busy, setBusy] = useState(false);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [err, setErr] = useState("");
  // 🔴 v2.40 — SEYAHAT TARZI ARTIK BURADA.
  // Profil sekmesinde secim yapinca alan kapanmiyordu ve surekli
  // ekranin ortasinda duruyordu. Duzenlenebilir her sey duzenleme
  // ekraninda yasar — ad, bio, diller zaten burada.
  //
  // Burada AYRI kaydetme yok: sayfanin kendi "Kaydet" butonu var ve
  // diger alanlarla birlikte kaydediliyor. Bir sayfada iki kaydetme
  // mekanizmasi olmasi, kullaniciya "hangisi neyi kaydediyor?" diye
  // sorduran bir tasarim hatasidir.
  const [styleOpts, setStyleOpts] = useState([]);
  // 🔴 v2.66 (Gökberk madde 4) — PROFİL SEKMESİNDEN TAŞINAN BLOKLAR.
  // Durum bilgisi (kalan hak · misafir kapasitesi · erişim kaynağı) ve
  // kurucu çember kartı artık burada yaşıyor. Profil bir vitrindir.
  const [hostQuota, setHostQuota] = useState(null);
  const [guestCap, setGuestCap] = useState(null);
  const [founding, setFounding] = useState(null);
  const [foundingMsg, setFoundingMsg] = useState(null);
  const [hostApp, setHostApp] = useState(null);
  const [fcOpen, setFcOpen] = useState(false);   // madde 14: misafire bilgilendirme

  useEffect(() => {
    (async () => {
      const [{ data: p }, { data: v }, { data: u }] = await Promise.all([
        supabase.from("profiles")
          .select("name, bio, profession, languages, linkedin_url, photo_url, photo_connections_only, access_source, women_safety_mode, travel_style, guest_capacity")
          .eq("user_id", uid).maybeSingle(),
        supabase.from("verifications").select("email_verified, phone_verified, id_verified").eq("user_id", uid).maybeSingle(),
        supabase.from("users").select("gender, role").eq("id", uid).maybeSingle(),
      ]);
      setVerif(v || {});
      setMyRole(u?.role || "guest");
      setForm({
        name: p?.name || "", bio: p?.bio || "", profession: p?.profession || "",
        languages: p?.languages || [], linkedin_url: p?.linkedin_url || "",
        photo_url: p?.photo_url || null, photo_connections_only: !!p?.photo_connections_only,
        access_source: p?.access_source || "", gender: u?.gender || "",
        women_safety_mode: !!p?.women_safety_mode,
        travel_style: p?.travel_style || null,
      });
      supabase.rpc("travel_style_options")
        .then(({ data, error }) => setStyleOpts(error ? [] : (data || [])))
        .catch(() => setStyleOpts([]));
      setGuestCap(p?.guest_capacity ?? null);
      // Durum bilgisi: kalan hak host'un KENDİ beyanı — geri göstermeyince
      // ölü veriye dönüşüyordu (v1.96'nın dersi, ekran değişti mantık değil).
      supabase.rpc("my_host_access")
        .then(({ data, error }) => setHostQuota(error ? null : (data?.quota || null)))
        .catch(() => setHostQuota(null));
      supabase.rpc("founding_host_status")
        .then(({ data, error }) => setFounding(error ? null : data))
        .catch(() => {});
      if (u?.role === "guest") {
        supabase.rpc("my_host_application")
          .then(({ data, error }) => setHostApp(error ? null : (data || null)))
          .catch(() => {});
      }
    })();
  }, [uid]);

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const toggleLang = l => setForm(f => ({
    ...f, languages: f.languages.includes(l) ? f.languages.filter(x => x !== l) : [...f.languages, l],
  }));

  async function save() {
    setBusy(true); setErr("");
    const { error } = await supabase.from("profiles").update({
      name: form.name.trim(), bio: form.bio.trim(), profession: form.profession,
      languages: form.languages, linkedin_url: form.linkedin_url.trim() || null,
      photo_connections_only: form.photo_connections_only,
      women_safety_mode: form.women_safety_mode,
      // 🔴 v2.66: SEYAHAT TARZI KAYDEDİLMİYORDU. v2.40'ta alan buraya
      // taşınmış ama save()'e EKLENMEMİŞTİ: kullanıcı seçiyor, Kaydet'e
      // basıyor, geri dönünce seçim yok. Taşınan alanın işlevi taşınmamış.
      travel_style: form.travel_style,
    }).eq("user_id", uid);
    // Cinsiyet users tablosunda — kadın güvenlik modu ona bağlı
    // 🔴 v2.78 — CİNSİYET İKİNCİ BİR YAZMA VE HATASI OKUNMUYORDU.
    // `012_women_safety.sql`'in KADIN GÜVENLİK MODU bu alana bağlı.
    // Profil "kaydedildi" derken cinsiyet yazılmamış olabiliyordu →
    // güvenlik filtresi yanlış çalışır. En sessiz kalması en tehlikeli
    // olan yazma buydu.
    // 🔴 v2.99 — `users.gender` ARTIK DOĞRUDAN YAZILAMIYOR (SQL 253 §5).
    // Sebep: erkek bir hesap tek `update` ile `gender='female'` yazıp kadın
    // güvenlik modundaki kadınların listesine giriyordu. Ürünün en hassas
    // vaadi tek satırla çürüyordu.
    // Yerine kapılı RPC (SQL 255 §2b): beyan BİR KEZ yazılır, değişiklik
    // yönetim işidir ve denetim kaydına düşer.
    let gErr = null;
    if (!error && form.gender) {
      const { data: cins, error: cinsHata } =
        await supabase.rpc("cinsiyetimi_bildir", { p_gender: form.gender });
      if (cinsHata) gErr = cinsHata;
      else if (cins && cins.ok === false) gErr = { message: cins.reason };
    }
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    if (gErr) { setErr(t.genderSaveFailed + " " + mapErr(t, gErr.message)); return; }
    if (onDone) onDone();
    onBack();
  }

  if (!form) return <View style={{ flex: 1, backgroundColor: C.bg, alignItems: "center", justifyContent: "center" }}><ActivityIndicator color={C.gold} /></View>;

  const comp = getProfileCompletion(form);
  const compColor = comp.pct >= 80 ? C.green : comp.pct >= 50 ? C.gold : C.red;

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneAccount} title={t.editProfTitle} onBack={onBack} />
      <ScrollView ref={scRef} contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {/* MVP: avatar + kamera rozeti (fotoğraf yükleme cihazda ayrı akış) */}
        <View style={{ alignItems: "center", marginBottom: SP[3] }}>
          {/* MVP: avatarin altinda "Fotoğraf yükle" — canlida kamera ikonu vardi
              ama DOKUNULAMIYORDU (yukleme yalniz Profil ekranindan yapilabiliyordu). */}
          <TouchableOpacity hitSlop={TAP.slop} disabled={photoBusy}
            accessibilityRole="button" accessibilityLabel={t.epPhotoUpload}
            onPress={async () => {
            setPhotoBusy(true);
            const url = await pickAndUploadPhoto(uid);
            setPhotoBusy(false);
            if (url) set("photo_url", url);
          }}>
            <View style={{ width: 74, height: 74 }}>
              <View style={{ width: 74, height: 74, borderRadius: R.full, backgroundColor: myRole === "host" ? C.goldSoft : C.tealBg, alignItems: "center", justifyContent: "center", overflow: "hidden", borderWidth: 2.5, borderColor: myRole === "host" ? C.gold : C.teal }}>
                {photoBusy ? <ActivityIndicator color={C.gold} />
                  : form.photo_url
                  ? <Image source={{ uri: form.photo_url }} style={{ width: 74, height: 74 }} />
                  : <Text style={{ fontSize: FS.hero, fontWeight: "700", color: myRole === "host" ? C.gold : C.teal, fontFamily: F.serif }}>{(form.name || "?").charAt(0).toUpperCase()}</Text>}
              </View>
              <View style={{ position: "absolute", bottom: 0, right: 0, width: 24, height: 24, borderRadius: R.full, backgroundColor: C.goldBtn, alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: "#fff" }}>
                <Ikon ad="kamera" boy={22} renk={C.mutedAA} />
              </View>
            </View>
            <Text style={{ color: C.goldText, fontSize: FS.xs, textAlign: "center", marginTop: SP[1], fontWeight: "600" }}>{t.epPhotoUpload}</Text>
          </TouchableOpacity>
        </View>

        {/* Tamamlanma — MVP'de bu ekranin en ustunde, CANLI */}
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, padding: ARA[14], marginBottom: SP[3] , ...ELEV.card }}>
          <Text style={{ fontSize: FS.sm, color: C.mutedAA, marginBottom: SP[2] }}>{String(t.epCompletedPct).replace("{n}", comp.pct)}</Text>
          <View style={{ height: 4, backgroundColor: C.bgAlt, borderRadius: R.full, overflow: "hidden" }}>
            <View style={{ width: `${comp.pct}%`, height: "100%", backgroundColor: compColor, borderRadius: R.full }} />
          </View>
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingTop: ARA[10], marginTop: ARA[10], borderTopWidth: 1, borderTopColor: C.line }}>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: FS.sm, color: C.body, fontWeight: "600" }}>{t.epPhotoOnly}</Text>
              <Text style={{ fontSize: FS.micro, color: C.dimAA, marginTop: 0 }}>{t.epPhotoOnlySub}</Text>
            </View>
            <Toggle val={form.photo_connections_only} a11yLabel={t.epPhotoOnly}
              onChange={() => set("photo_connections_only", !form.photo_connections_only)} />
          </View>
        </View>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[1] }}>{t.epNameLabel}</Text>
        <TextInput value={form.name} onChangeText={v => set("name", v)} placeholderTextColor={C.dim}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14], color: C.ink }} />

        {/* 🔴 SEYAHAT TARZI — profil sekmesinden BURAYA tasindi (v2.40).
            Orada secim yapinca alan kapanmiyor, surekli ekranin ortasinda
            duruyordu. Gokberk "kaydet butonu ekle, sonra gizle" onerdi;
            gizlemeyi AYNEN uygulamadim cunku gizlenen alan BULUNAMAYAN
            alandir — kullanici sonradan degistirmek isteyince aramaya
            baslar. Dogrusu daha basit: PROFIL VITRINDIR, FORM DEGIL.
            Duzenlenebilir her sey duzenleme ekraninda yasar.

            Burada AYRI kaydetme YOK: sayfanin kendi Kaydet butonuyla,
            diger alanlarla birlikte kaydediliyor. Bir sayfada iki
            kaydetme mekanizmasi, "hangisi neyi kaydediyor?" sorusunu
            dogurur. */}
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1, marginBottom: SP[1] }}>
          {t.styleTitle} <Text style={{ fontWeight: "400", color: C.dimAA }}>{t.epOptional}</Text>
        </Text>
        {styleOpts.map(o => {
          const on = form.travel_style === o.code;
          return (
            <Secim key={o.code} bicim="kart" ton="gold" zemin="yok" secili={on}
              etiket={o.label} alt={o.sub} stil={{ marginBottom: ARA[6] }}
              onPress={() => set("travel_style", on ? null : o.code)} />
          );
        })}
        <Text style={{ fontSize: FS.xs, color: C.dim, lineHeight: 16, marginBottom: ARA[14] }}>
          {t.styleNote}
        </Text>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1, marginBottom: SP[1] }}>
          {t.epBio} <Text style={{ fontWeight: "400", color: C.dimAA }}>{t.epBioHelp}</Text>
        </Text>
        <TextInput value={form.bio} onChangeText={v => set("bio", v)} multiline placeholder={t.epBioPlaceholder} placeholderTextColor={C.dimAA}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: form.bio.length > 20 ? C.teal : C.line, borderRadius: R.xs,
                   padding: SP[3], height: 84, textAlignVertical: "top", color: C.body }} />
        <Text style={{ fontSize: FS.xs, color: C.dimAA, textAlign: "right", marginTop: ARA[2], marginBottom: ARA[14] }}>{form.bio.length} {t.epChars}</Text>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[2] }}>{t.epProfession}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[14] }}>
          {profOpts(t).map(o => {
            const sel = form.profession === o;
            return (
              <Secim key={o} ton="teal" secili={sel} etiket={o}
                onPress={() => set("profession", sel ? "" : o)}
                stil={{ marginRight: ARA[6], marginBottom: ARA[6] }} />
            );
          })}
        </View>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[2] }}>{t.epLanguages}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[14] }}>
          {LANG_OPTS.map(l => {
            const sel = form.languages.includes(l);
            return (
              <Secim key={l} ton="purple" coklu secili={sel} etiket={gorunur(l)} onPress={() => toggleLang(l)}
                stil={{ marginRight: ARA[6], marginBottom: ARA[6] }} />
            );
          })}
        </View>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1, marginBottom: SP[1] }}>
          LINKEDIN <Text style={{ fontWeight: "400", color: C.dimAA }}>{t.epLinkedinHelp}</Text>
        </Text>
        <TextInput ref={liRef} value={form.linkedin_url} onChangeText={v => set("linkedin_url", v)} autoCapitalize="none"
          placeholder="https://linkedin.com/in/…" placeholderTextColor={C.dim}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[20], color: C.ink }} />

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[2] }}>
          {t.epGender} <Text style={{ fontWeight: "400", color: C.dimAA }}>{t.epGenderHelp}</Text>
        </Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[14] }}>
          {[["female", t.epGenderF], ["male", t.epGenderM], ["other", t.epGenderO], ["", t.epGenderNone]].map(([val, lbl]) => {
            const sel = form.gender === val;
            return (
              <Secim key={lbl} ton="purple" secili={sel} etiket={lbl} onPress={() => set("gender", val)}
                stil={{ marginRight: ARA[6], marginBottom: ARA[6] }} />
            );
          })}
        </View>

        {form.gender === "female" && (
          <View style={{ backgroundColor: C.card, borderWidth: 0, borderTopWidth: 1, borderTopColor: C.parlamaGuc, borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[14], flexDirection: "row", alignItems: "flex-start" , ...ELEV.card }}>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: FS.sm, color: C.purple, fontWeight: "700", marginBottom: SP[1] }}>{t.stWomenMode}</Text>
              <Text style={{ fontSize: FS.xs, color: C.mutedAA, lineHeight: 16 }}>{t.epWomenModeBody}</Text>
            </View>
            <View style={{ marginLeft: ARA[10] }}>
              <Toggle val={form.women_safety_mode} a11yLabel={t.stWomenMode}
                onChange={() => set("women_safety_mode", !form.women_safety_mode)} />
            </View>
          </View>
        )}

        <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[20] , ...ELEV.card }}>
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1.5, marginBottom: ARA[10] }}>{t.epVerifyStatus}</Text>
          {/* 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: "Bağla →" ve "Doğrula →" BUTON
              DEĞİLDİ; satırlar düz View'di ve hiçbir dokunmayı almıyordu.
              Eylem çağıran bir metin yazıp onu tıklanamaz bırakmak,
              kullanıcıya "bozuk" dedirtir. Satırlar artık gerçek aksiyon
              taşıyor: LinkedIn alanına odaklanır, telefon/kimlik
              doğrulama akışını açar. */}
          {[[t.epVEmail, verif.email_verified, C.greenBtn, "—", null],
            [t.epVPhone, verif.phone_verified, C.greenBtn, t.epVVerifyCta, () => onVerify && onVerify()],
            // SQL 285 — kimlik satırı artık BELGE yükleme ekranına gider (telefon ekranına değil)
            [t.epVId, verif.id_verified, C.goldText, t.epVIdCta, () => (onVerifyId ? onVerifyId() : onVerify && onVerify())],
            [t.epVLinkedin, !!form.linkedin_url, C.teal, t.epVLinkCta,
              () => { try { scRef.current && scRef.current.scrollTo && scRef.current.scrollTo({ y: 520, animated: true }); } catch (e) {}
                      setTimeout(() => { try { liRef.current && liRef.current.focus && liRef.current.focus(); } catch (e) {} }, 250); }],
          ].map(([lbl, done, c, cta, act], i, arr) => (
            <TouchableOpacity key={lbl} activeOpacity={act && !done ? 0.7 : 1}
              onPress={() => { if (act && !done) act(); }}
              accessibilityRole={act && !done ? "button" : undefined}
              accessibilityLabel={act && !done ? String(lbl) + " — " + String(cta).replace("→", "").trim() : undefined}
              style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: SP[2], minHeight: TAP.minHeight, borderBottomWidth: i < arr.length - 1 ? 1 : 0, borderBottomColor: C.line }}>
              <View style={{ flexDirection: "row", alignItems: "center" }}>
                <View style={{ width: 20, height: 20, borderRadius: R.xs, backgroundColor: done ? c + "22" : "transparent", borderWidth: 1.5, borderColor: done ? c : C.dimAA, alignItems: "center", justifyContent: "center", marginRight: SP[2] }}>
                  {done ? <Ikon ad="tamam" boy={FS.xs} renk={c} /> : null}
                </View>
                <Text style={{ fontSize: FS.sm, color: C.body }}>{lbl}</Text>
              </View>
              <Text style={{ fontSize: FS.xs, color: done ? c : C.amberInk, fontWeight: done ? "500" : "600" }}>{done ? t.epVDone : cta}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {!!err && <View style={{ backgroundColor: C.redBg, borderRadius: R.xs, padding: SP[3], marginBottom: SP[3] }}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
        {/* 🔴 v2.65 — LOUNGE HAKKI KAYNAĞI. access_source yukarıda zaten
            çekiliyordu ama hiç gösterilmiyordu; App.js'in geçtiği onAccess
            de imzada olmadığı için yutuluyordu. İkisi birleşince satır
            gerçek oldu: kullanıcı kaynağını görür ve dokununca değiştirir. */}
        {!!onAccess && (
          <TouchableOpacity onPress={onAccess} activeOpacity={0.7}
            accessibilityRole="button" accessibilityLabel={t.accessSourceRow}
            style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm,
                     paddingHorizontal: ARA[14], paddingVertical: SP[3], minHeight: TAP.minHeight, marginBottom: ARA[20],
                     flexDirection: "row", alignItems: "center", justifyContent: "space-between" , ...ELEV.card }}>
            <View style={{ flex: 1, minWidth: 0, marginRight: SP[2] }}>
              <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1 }}>
                {BUYUK(t.accessSourceRow)}
              </Text>
              <Text numberOfLines={1} style={{ flex: 1, fontSize: FS.sm, color: C.ink, marginTop: SP[1] }}>
                {erisimKaynaklari(form.access_source).map(k => erisimEtiketi(t, k)).join(", ") || t.stPhoneUnset}
              </Text>
            </View>
            <Ikon ad="sag" boy={FS.lg} renk={C.dimAA} />
          </TouchableOpacity>
        )}

        {/* 🔴 v2.66 — DURUM BİLGİSİ (Gökberk madde 4). Profil sekmesinden
            taşındı. Kalan hak ve misafir kapasitesi host'un KENDİ beyanı:
            "kimin söylediği" önemli, o yüzden satır adı sahibini söylüyor. */}
        {myRole === "host" && (
          <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
                         borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[20] , ...ELEV.card }}>
            {!!hostQuota && hostQuota.known && !hostQuota.unlimited && (
              <View style={{ flexDirection: "row", justifyContent: "space-between", paddingVertical: SP[1], marginBottom: SP[1] }}>
                <Text style={{ fontSize: FS.sm, color: C.mut }}>{t.quotaLeftRowOwn}</Text>
                <Text style={{ fontSize: FS.sm, fontWeight: "700",
                               color: hostQuota.left === 0 ? C.red : hostQuota.left <= 2 ? C.amber : C.green }}>
                  {hostQuota.left} / {hostQuota.total}{hostQuota.stale ? ` · ${t.quotaStale}` : ""}
                </Text>
              </View>
            )}
            <View style={{ flexDirection: "row", justifyContent: "space-between", paddingVertical: SP[1] }}>
              <Text style={{ fontSize: FS.sm, color: C.mut }}>{t.guestAllowanceRow}</Text>
              <Text style={{ fontSize: FS.sm, fontWeight: "700", color: (guestCap || 0) > 0 ? C.green : C.amber }}>
                {(guestCap || 0) > 0 ? String(guestCap) : t.notSetWord}
              </Text>
            </View>
          </View>
        )}

        {/* 🔴 v2.66 — KURUCU ÇEMBER (Gökberk madde 4 + 14).
            Eski koşul `session?.role !== "guest"` idi; `session` auth
            oturumudur ve `role` ALANI YOKTUR -> koşul DAİMA doğru, kart
            misafirde de çiziliyordu. Rol artık users.role'dan okunan
            myRole'dan gelir. Misafirde kart "Host olmak istiyorum" olur
            ve önce kurucu çemberi ANLATIR, sonra başvuruya götürür. */}
        {myRole === "guest" ? (
          <TouchableOpacity onPress={() => setFcOpen(true)} activeOpacity={0.8}
            accessibilityRole="button" accessibilityLabel={t.hostApplyLink}
            style={{ flexDirection: "row", alignItems: "center", backgroundColor: C.goldSoft,
                     borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: SP[3],
                     minHeight: TAP.minHeight, marginBottom: ARA[20] }}>
            {/* 12 Eylül md.6 — bu ikonun da sağ boşluğu yoktu (sahne
                ölçümü: 0.0 pt; "✨Kartımda" bitişik çiziliyordu). */}
            <Ikon ad="kutlama" boy={FS.title} renk={C.mut} stil={{ marginRight: ARA[10] }} />
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={{ fontWeight: "700", color: C.goldInk, fontSize: FS.base }}>
                {hostApp?.status === "pending" ? t.hostApplyPendingTitle : t.hostApplyLink}
              </Text>
              <Text style={{ color: C.goldInk, fontSize: FS.sm, marginTop: ARA[2] }}>
                {hostApp?.status === "pending" ? t.hostApplyPendingBody.slice(0, 60) + "…" : t.hostApplyLinkSub}
              </Text>
            </View>
            <Ikon ad="sag" boy={FS.lg} renk={C.goldInk} />
          </TouchableOpacity>
        ) : (!!founding && (founding.mine || founding.left > 0) && (
          <TouchableOpacity disabled={!!founding.mine}
            accessibilityRole="button" accessibilityLabel={t.foundingTitle}
            onPress={async () => {
              try {
                const { data, error } = await supabase.rpc("claim_founding_host");
                if (error) { setFoundingMsg(t.foundingErr); return; }
                if (data?.ok) { setFounding(f => ({ ...f, mine: data.no })); setFoundingMsg(null); }
                // 🔴 23 Eylül — sunucu 'full' DEMİYOR: `claim_founding_host` yalnız
                // 'closed' (kontenjan doldu) ya da 'no_listing' döndürüyor. Eski
                // kontrol hiç tutmuyor, kontenjan dolunca "tekrar dene" yazıyordu —
                // tekrar denemek işe yaramayan bir durumda.
                else setFoundingMsg(
                  data && (data.reason === "closed" || data.reason === "full") ? t.foundingFull
                  : data && data.reason === "no_listing" ? (t.foundingNoListing || t.foundingErr)
                  : t.foundingErr);
              } catch (e) { setFoundingMsg(t.foundingErr); }
            }}
            style={{ flexDirection: "row", alignItems: "center",
                     backgroundColor: founding.mine ? C.goldSoft : C.card,
                     borderWidth: 1, borderColor: founding.mine ? C.gold : C.line,
                     borderRadius: R.sm, padding: SP[3], minHeight: TAP.minHeight, marginBottom: ARA[20] }}>
            <Ikon ad="kisiler" boy={17} renk={C.purple} stil={{ marginRight: ARA[10] }} kutu={19} />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: FS.base, fontWeight: "700", color: founding.mine ? C.gold : C.ink }}>
                {founding.mine ? t.foundingMine.replace("{n}", String(founding.mine)) : t.foundingTitle}
              </Text>
              <Text style={{ fontSize: FS.sm, color: founding.mine ? C.gold : C.mut, marginTop: 0 }}>
                {founding.mine ? t.foundingMineSub : t.foundingLeft.replace("{n}", String(founding.left))}
              </Text>
              {!!foundingMsg && (
                <Text style={{ fontSize: FS.sm, color: C.red, marginTop: SP[1] }}>{foundingMsg}</Text>
              )}
            </View>
          </TouchableOpacity>
        ))}
        {/* EDITPROFILE_SAVE */}

        <Btn v="gold" sm label={busy ? t.epSaving : t.epSave} onPress={save} disabled={busy} a11yLabel={t.epSave} />
      </ScrollView>

      {/* 🔴 v2.66 (madde 14) — KURUCU ÇEMBER BİLGİLENDİRMESİ.
          Misafire "Kurucu Host ol" demek yanlıştı; hiçbir şey dememek de
          yanlış olurdu: rozet SONRADAN ALINAMIYOR. Bu yüzden başvuruya
          gitmeden önce ne kazandığını okuyor. Rozet yargı değil bilgi. */}
      {fcOpen && (
        <Modal visible transparent animationType="fade" onRequestClose={() => setFcOpen(false)}>
          <View style={{ flex: 1, justifyContent: "center", padding: ARA[26] }}>
            <PerdeBulanik />
            <View style={{ ...POPUP_YUZEY(), borderRadius: R.md, padding: ARA[22] }}>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, lineHeight: 23 }}>{t.fcModalTitle}</Text>
              <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[2], lineHeight: 19 }}>{t.fcModalBody}</Text>
              {[t.fcModalB1, t.fcModalB2].map((b, i) => (
                <View key={i} style={{ flexDirection: "row", marginTop: SP[2] }}>
                  <Text style={{ color: C.goldText, fontSize: FS.sm, marginRight: SP[2] }}>·</Text>
                  <Text style={{ flex: 1, color: C.body, fontSize: FS.sm, lineHeight: 19 }}>{b}</Text>
                </View>
              ))}
              <Btn v="gold" sm label={t.fcModalApply} onPress={() => { setFcOpen(false); if (onHostApply) onHostApply(); }} a11yLabel={t.fcModalApply} style={{ marginTop: ARA[18] }} />
              <TouchableOpacity accessibilityRole="button" accessibilityLabel={t.fcModalLater}
                onPress={() => setFcOpen(false)}
                style={{ alignItems: "center", justifyContent: "center", minHeight: TAP.minHeight, marginTop: ARA[6] }}>
                <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.fcModalLater}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>
      )}
    </Sayfa>
  );
}

// ============================================================
// AirportPicker / LoungePicker — MVP v15 satir 3447-3473'un portu.
//
// MVP'de bunlar <select> idi ve lounge secilince ALTINDA bir teal kutu
// aciliyordu: "Terminal · saatler · ilk 3 imkan". v1.21'de secici yoktu,
// kullanici havalimani kodunu ELLE yaziyordu.
//
// MVP'de AIRPORTS sabit bir diziydi; bizde tablodan gelir (002 seed:
// 12 havalimani, 21 lounge). Bu yuzden verileri prop olarak aliyorlar.
// ============================================================
// 🔴 v2.79 — ARAMA EKLENDİ.
// Gökberk: "havalimanı ve havayolu droplistlerine search alanı ekle çünkü
// çok fazla veri var." Ölçtüm: katalogda 222 havalimanı var ve liste
// alfabetikti — ekran görüntüsünde LED/LGW/LHE yan yana görünüyordu,
// yani IST'e ulaşmak için onlarca satır kaydırmak gerekiyordu.
// Arama hem KODA hem ADA hem ŞEHRE bakıyor: kullanıcıların çoğu "IST"
// yazıyor, "İstanbul" yazan da bulabilmeli. Türkçe küçültme `norm()`
// içinde (src/Pickers.js) — `toLowerCase()` "İSTANBUL"u eşleştirmiyor.
export function LoungePicker({ lounges, value, onSelect, emptyNote, t = {} }) {
  const [open, setOpen] = useState(false);
  // 🔴 v2.24 — IC HAT / DIS HAT SEKMELERI.
  // IST'te bir havalimaninda 10+ salon var ve kullanici uzun bir listede
  // kendi terminalini ariyor. Terminal, salon seciminin EN AYIRT EDICI
  // ozelligi: yolcu zaten hangi terminalde oldugunu biliyor. Once ona
  // sorup listeyi yariya indirmek, alfabetik siralamadan cok daha hizli.
  const [term, setTerm] = useState("all");
  // 🔴 v2.34 — SEKMELER HIC GORUNMUYORDU, SEBEBI TURKCE "İ".
  // JavaScript'te "İç Hat".toLowerCase() -> "i̇ç hat" (i + BIRLESIK
  // NOKTA, U+0307). Yani /iç/ deseni TUTMUYOR. Butun ic hat salonlari
  // "other" sayiliyordu; dom sayisi 0 kaliyor ve sekme cubugu hic
  // cizilmiyordu. Ayni hatayi SQL sayma sorgumda da yapmistim —
  // veri dogruymus, iki taraftaki OKUMA yanlismis.
  //
  // Cozum: aksanlari NORMALIZE et (NFD + birlesik isaretleri sil).
  const norm = x => String(x || "")
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  // 🔴 190 — KAPSAM ARTIK VERIDEN GELIR, METINDEN DEGIL.
  // v2.34'te Turkce "İ" yuzunden bir kez kirildi; kirilganligin kaynagi
  // "isimden anlam cikarmak"ti. lounges_for_airport artik scope
  // (domestic/international/both) donduruyor. Metin YALNIZ yedek yol:
  // katalogda scope'u doldurulmamis eski satirlar icin.
  const termOf = l => {
    if (l.scope === "domestic") return "dom";
    if (l.scope === "international") return "int";
    if (l.scope === "both") return "both";
    const t = norm(`${l.terminal || ""} ${l.name || ""}`);   // eski yedek
    if (/dis hat|international|dis$/.test(t)) return "int";
    if (/ic hat|domestic|ic$/.test(t)) return "dom";
    return "other";
  };
  // "both" salonu IKI sekmede de gorunur: o salon iki tarafa da hizmet
  // veriyor, kullaniciyi yanlis sekmede aratmak bizim isimiz degil.
  const inTab = (l, k) => {
    if (k === "all") return true;
    const s = termOf(l);
    return s === k || (s === "both" && (k === "dom" || k === "int"));
  };
  const labelOf = l => l.display_name || l.name;
  // Bolumlu salonlarda sessiz tek renk cip — yargi degil bilgi.
  const sectionChip = l => l.section === "business" ? "Business"
    : l.section === "miles_smiles" ? "Miles&Smiles" : null;
  // 🔴 v1.85: eskiden bos listede null donuyordu -> alan EKRANDAN KAYBOLUYORDU.
  // Kullanici "Lounge sec" hatasi aliyor ama secebilecegi bir alan gormuyordu.
  // Artik alan HER ZAMAN gorunur; katalog bossa neden yazilir ve akis
  // ENGELLENMEZ (katalog eksikligi bizim sorunumuz, kullanicinin degil).
  if (!lounges || !lounges.length) {
    return (
      <View style={{ marginBottom: ARA[14] }}>
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, marginBottom: SP[1], letterSpacing: 1 }}>LOUNGE</Text>
        <View style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                       paddingVertical: SP[3], paddingHorizontal: SP[3] }}>
          <Text style={{ fontSize: FS.sm, color: C.dimAA }}>
            {emptyNote || t.noLoungeYet}
          </Text>
        </View>
      </View>
    );
  }
  const sel = lounges.find(l => l.id === value || l.name === value);
  return (
    <View style={{ marginBottom: ARA[14] }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[1], letterSpacing: 1 }}>LOUNGE</Text>
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => setOpen(!open)}
        style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: open ? C.teal : C.line, borderRadius: R.xs,
                 paddingVertical: SP[3], paddingHorizontal: SP[3], flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <Text style={{ fontSize: FS.sm, color: sel ? C.body : C.dim }}>{sel ? labelOf(sel) : gorunur("Lounge seç…")}</Text>
        <Ikon ad={open ? "yukari" : "asagi"} boy={14} renk={C.mutedAA} />
      </TouchableOpacity>
      {open && (
        <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, marginTop: SP[1], maxHeight: 260, overflow: "hidden" , ...ELEV.card }}>
          {(() => {
            // Sayilar da inTab ile hesaplanir — "both" iki sayida da yer alir.
            const counts = { dom: 0, int: 0 };
            for (const l of lounges) {
              if (inTab(l, "dom")) counts.dom++;
              if (inTab(l, "int")) counts.int++;
            }
            const tabs = [["all", gorunur("Tümü"), lounges.length],
                          ["dom", gorunur("İç Hat"), counts.dom],
                          ["int", gorunur("Dış Hat"), counts.int]];
            // 🔴 SEKME ARTIK HER ZAMAN GORUNUR (tek salon haric).
            // Eski kosul "her iki terminalde de salon varsa goster"
            // idi; bir terminal bossa kullanici sekmenin VARLIGINI
            // bile ogrenemiyordu. Bos sekme "burada salon yok" bilgisi
            // verir — bu da bir bilgidir. Sayilar sekmede yazili.
            if (lounges.length < 2) return null;
            return (
              <View style={{ flexDirection: "row", borderBottomWidth: 1, borderBottomColor: C.line }}>
                {tabs.map(([k, label, n]) => (
                  <TouchableOpacity hitSlop={TAP.slop} key={k} disabled={n === 0}
                    onPress={() => setTerm(k)}
                    style={{ flex: 1, paddingVertical: SP[2], alignItems: "center",
                             borderBottomWidth: 2,
                             borderBottomColor: term === k ? C.teal : "transparent" }}>
                    <Text style={{ fontSize: FS.sm, fontWeight: term === k ? "700" : "400",
                                   color: n === 0 ? C.dim : term === k ? C.teal : C.mut }}>
                      {label} ({n})
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            );
          })()}
          <ScrollView nestedScrollEnabled>
            {lounges.filter(l => inTab(l, term)).map(l => (
              <TouchableOpacity hitSlop={TAP.slop} key={l.id} onPress={() => { onSelect(l.id); setOpen(false); }}
                style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], borderBottomWidth: 1, borderBottomColor: C.line,
                         backgroundColor: l.id === value ? C.tealBg : "transparent" }}>
                <View style={{ flexDirection: "row", alignItems: "center", gap: SP[2] }}>
                  {/* display_name: ayni ad iki kapsamda geciyorsa RPC ayirt edici ek koyar */}
                  <Text style={{ flex: 1, fontSize: FS.sm, color: l.id === value ? C.teal : C.body, fontWeight: l.id === value ? "600" : "400" }}>{labelOf(l)}</Text>
                  {!!sectionChip(l) && (
                    <View style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, paddingVertical: ARA[2], paddingHorizontal: SP[2] }}>
                      <Text style={{ fontSize: FS.micro, color: C.mutedAA, fontWeight: "600" }}>{sectionChip(l)}</Text>
                    </View>
                  )}
                </View>
                <Text style={{ fontSize: FS.xs, color: C.dimAA, marginTop: 0 }}>{l.terminal || "—"}{(l.access_types && l.access_types.length) ? ` · ${l.access_types.join(", ")}` : ""}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}
      {/* MVP: secim yapilinca ALTINDA teal bilgi kutusu */}
      {sel && (
        <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.tealLine, borderRadius: R.xs, paddingVertical: SP[2], paddingHorizontal: SP[3], marginTop: ARA[6] }}>
          <Text style={{ fontSize: FS.xs, color: C.tealInk }}>
            {/* 🔴 v2.68 — ÜÇ ALANIN İKİSİ HİÇ YOKTU. lounges_for_airport
                `access_types` (DİZİ) ve `section` döndürüyor; burada
                `access_type` (tekil) ve `hours` okunuyordu — ikisi de
                undefined, yani kutu çoğu salonda yalnız terminali
                gösteriyordu. Ölçüm: RPC imzası id, name, terminal,
                access_types, scope, accepts_guests, note, section,
                display_name. */}
            {[sel.terminal, sel.section,
              (sel.access_types && sel.access_types.length) ? sel.access_types.join(", ") : null,
              sel.note].filter(Boolean).join(" · ") || sel.display_name || sel.name}
          </Text>
          {/* 🔴 v2.69 — SALON FİYAT LİSTESİ (SQL 196 venue_price_list).
              Kepler Club gibi saatlik oda satan tesislerde "üyelikle
              ücretsiz girilir" varsayımı YANLIŞ. Fiyatı burada
              gösterirsek host da misafir de kapıda değil ekranda öğrenir.
              Fiyatı olmayan salonda blok hiç çizilmez. */}
          <VenuePrices venueId={sel.key || sel.id} t={t} />
        </View>
      )}
    </View>
  );
}

// ============================================================
// DateInput / TimeInput — MASKELI giris.
// MVP'de duz <input> idi ama Gokberk hakli olarak sordu: "Tarih ve saat
// girisi yapilan alanlar formatli gelse daha iyi olabilir" — ekran
// goruntusunde "2026" yazip devamini elle ugrasiyordu.
// YYYY-AA-GG ve SS:DD ayiraclarini otomatik koyar.
// ============================================================
// v1.88 — YERLİ TARİH/SAAT SEÇİCİ + HIZLI SEÇİM
//
// 🔴 NEDEN DEĞİŞTİ: maskeli metin kutusu bir iyileştirmeydi ama hâlâ
// KLAVYEYLE 8 RAKAM yazdırıyordu. Tarih ve saat bu üründe eşleşmenin
// TEMELİ; en kırılgan giriş yöntemini en kritik iki alana koymuştuk.
// Ölçülebilir sonucu: yanlış/eksik tarih = ilan hiç eşleşmez.
//
// ÜÇ KATMANLI ÇÖZÜM (üstten alta doğru zahmet artar):
//   1. HIZLI SEÇİM cipleri — "Bugün / Yarın / Cumartesi" tek dokunuş.
//      Native modül olmadan da çalışır. Vakaların çoğunu buradan kapatır.
//   2. YERLİ SEÇİCİ — takvim/saat tekerleği, iki dokunuş.
//   3. MASKELİ METİN — yalnız native modül yüklenemezse (Expo Go'nun eski
//      sürümleri, web) devreye girer. Yani hiçbir ortamda ekran ölmez.
//
// Modül yüklemesi TRY/CATCH içinde: paket kurulu değilse uygulama
// ÇÖKMEZ, sessizce 1+3'e düşer. (v1.80 dersi: kütüphane varsayımı
// render sırasında patlarsa tüm ağaç gider.)
// ============================================================
export function TimeInput({ label, value, onChange }) {
  const [open, setOpen] = useState(false);
  const ok = /^\d{2}:\d{2}$/.test(String(value || ""));
  return (
    <View style={{ flex: 1 }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, marginBottom: SP[1], letterSpacing: 1 }}>{label}</Text>
      {_DTP ? (
        <>
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setOpen(true)}
            style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: ok ? C.teal : C.line,
                     borderRadius: R.xs, padding: SP[3], flexDirection: "row",
                     justifyContent: "space-between", alignItems: "center" }}>
            <Text style={{ color: ok ? C.ink : C.dim, fontSize: FS.lg, fontWeight: ok ? "600" : "400" }}>
              {ok ? value : "--:--"}
            </Text>
            <Ikon ad="saat" boy={22} renk={C.mutedAA} />
          </TouchableOpacity>
          {open && (
            <_DTP
              value={(() => {
                const d = new Date();
                if (ok) { d.setHours(+value.slice(0, 2), +value.slice(3, 5), 0, 0); }
                return d;
              })()}
              mode="time" display="default" is24Hour={true}
              onChange={(ev, d) => {
                setOpen(false);
                if (d && ev?.type !== "dismissed") {
                  const p = n => String(n).padStart(2, "0");
                  onChange(`${p(d.getHours())}:${p(d.getMinutes())}`);
                }
              }} />
          )}
        </>
      ) : (
        <TextInput value={value}
          onChangeText={v => {
            const d = v.replace(/\D/g, "").slice(0, 4);
            onChange(d.length > 2 ? d.slice(0, 2) + ":" + d.slice(2) : d);
          }}
          keyboardType="number-pad" placeholder="14:00" placeholderTextColor={C.dim} maxLength={5}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: ok ? C.teal : C.line,
                   borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.sm }} />
      )}
    </View>
  );
}

// ⚠️ BU İKİ BİLEŞEN NEDEN BU DOSYADA?
// `SeyahatFormu` dört ayrı yerden bileşen kullanıyor: `AirportPicker`
// (ortak) · `DateInput` (ekranlar_yalin) · `TimeInput` (bu dosya) ·
// `CarrierPicker` (Pickers) · `FlightField`. Katman sırası
// ortak → ekranlar_yalin → ekranlar_ana → screens olduğu için hepsini
// aynı anda görebilen EN ALT katman burası.
//
// `EditTrip` de buraya taşındı: `ekranlar_yalin`de kalsaydı formu
// `screens`ten alması gerekirdi ve bu bir döngü olurdu. `screens.js` üç
// dosyayı da `export *` ile yeniden yayımlıyor, yani App.js'in import
// satırı DEĞİŞMİYOR.
//
// 🆕 SINIF: "PAYLAŞILAN BİR BİLEŞEN, ONU KULLANAN EN ALT KATMANA KONUR —
// YUKARIDAN AŞAĞI BİR IMPORT, DÖNGÜNÜN BAŞLANGICIDIR."

// ════════════════════════════════════════════════════════════════════════
// SEYAHAT FORMU — EKLEME VE DÜZENLEME AYNI BİLEŞEN  (v3.4)
//
// 🔴 GÖKBERK (28 Ağustos)
// "seyahat düzenle ekranı seyahat ekle ile aynı olmalı aslında ki eksik bir
//  düzenleme yapmıyım. Ayrıca düzenleye tıkladığımda mevcut verilerle
//  gelmeli bu da önemli ki en baştan doldurmak zorunda kalmıyım."
//
// ÖLÇÜLEN FARK (v3.3.3):
//   AddVisit  → 7 alan, hepsi seçici/doğrulamalı
//   EditTrip  → 4 alan, hepsi DÜZ METİN KUTUSU
//   Eksik: VARIŞ · HAVAYOLU · SEYAHAT AMACI
//
// Ve VARIŞ'ın hâli bundan da kötüydü: değer form durumunda TUTULUYOR ve
// `update_visit`e GÖNDERİLİYOR, ama ekranda ÇİZİLMİYORDU. Yani yanlış
// girilmiş bir varış kodu asla düzeltilemiyordu.
//
// 🔴 SEBEP BİR UNUTMA DEĞİL, BİR YAPI HATASI. Kod tabanı bu dersi ZATEN
// yazmıştı (ekranlar_ana.js: "bir nesneyi yaratan form ile düzenleyen form
// ayrı yazılırsa, düzenleme formu her zaman geride kalır") ve bunun için
// `alan_esitligi_check.py` nöbetçisi bile vardı — AMA o nöbetçi YALNIZCA
// `screens.js` içindeki ilan çiftini karşılaştırıyordu. `EditTrip`
// `ekranlar_yalin.js`te olduğu için nöbetçinin görüş alanının DIŞINDAYDI.
//
// 🆕 SINIF: "BİR DERSİ ÖĞRENİP NÖBETÇİSİNİ TEK BİR ÖRNEĞE BAĞLARSAN, AYNI
// HATA İKİNCİ ÖRNEKTE SESSİZCE YAŞAMAYA DEVAM EDER — NÖBETÇİ DERSİ DEĞİL
// DOSYAYI KORUYOR OLUR."
//
// Bu yüzden çözüm "düzenleme formuna alan eklemek" DEĞİL: iki ekran artık
// TEK bileşen. Ayrışma imkânsız, çünkü ayrı bir kopya yok.
//
// `mod`: "ekle" | "duzenle" — yalnız üç şeyi değiştiriyor:
//   · kilitli alanlar (düzenlemede bağlı başvuru varsa havalimanı/tarih)
//   · kaydet düğmesinin metni
//   · ön doldurma bandı (yalnız eklemede, Keşfet'ten gelindiyse)
// Alanların KENDİSİ hiçbir modda farklı değil. Fark ederse nöbetçi düşer.
// ════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════
// KİŞİ SAYISI + ÇOCUK  (SQL 283 · kural motoru boyut 1-2)
//
// Motor "bu hak kaç misafir alıyor" sorusunu yıllardır cevaplıyordu;
// "sen kaç kişisin" sorusunu HİÇ SORMAMIŞTIK. İki kişi gelen bir
// misafir tek kişilik hakla kapıda dönüyordu ve ürün bunu bilmiyordu.
//
// Tasarım: çip satırı (1–6), altında çocuk yaş bantları. Yaş bandı
// seçmek bir çocuk EKLER; eklenen çocuk "4 yaş ×" çipi olur. Çocuk
// sayısı kişi sayısından az olmak zorunda (sunucu da doğrular).
// ════════════════════════════════════════════════════════════════════════
export function KisiSayisi({ t, kisi, cocuk, onKisi, onCocuk, stil }) {
  const n = Math.max(1, Math.min(6, Number(kisi) || 1));
  const kids = Array.isArray(cocuk) ? cocuk : [];
  const bands = t.childBands || [["0–2", 1], ["3–5", 4], ["6–11", 8], ["12–17", 14]];
  const kisiSec = (k) => {
    onKisi(k);
    if (kids.length >= k) onCocuk(kids.slice(0, Math.max(0, k - 1)));
  };
  return (
    <View style={stil}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.partyLabel}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: SP[2] }}>
        {[1, 2, 3, 4, 5, 6].map(k => (
          <Secim key={k} ton="teal" secili={n === k}
            etiket={k === 1 ? t.partyOne : (t.partyN || "{n}").replace("{n}", String(k))}
            a11yRol="radio" onPress={() => kisiSec(k)}
            stil={{ marginRight: SP[2], marginBottom: SP[2] }} />
        ))}
      </View>
      {n > 1 && (
        <>
          <Text style={{ color: C.body, fontSize: FS.sm, marginBottom: SP[2] }}>{t.childLabel}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: SP[1] }}>
            {kids.map((yas, i) => (
              <Secim key={"c" + i} ton="gold" secili dolu
                etiket={(t.childAge || "{n}").replace("{n}", String(yas)) + "  ×"}
                a11yRol="button" a11yLabel={t.childRemove + " · " + (t.childAge || "{n}").replace("{n}", String(yas))}
                onPress={() => onCocuk(kids.filter((_, j) => j !== i))}
                stil={{ marginRight: SP[2], marginBottom: SP[2] }} />
            ))}
            {kids.length < n - 1 && bands.map(([lb, yas]) => (
              <Secim key={"b" + lb} ton="teal" secili={false} etiket={"+ " + lb}
                a11yRol="button" onPress={() => onCocuk([...kids, yas])}
                stil={{ marginRight: SP[2], marginBottom: SP[2] }} />
            ))}
          </View>
        </>
      )}
      <Text style={{ color: C.muted, fontSize: FS.xs, lineHeight: 16, marginBottom: SP[3] }}>{t.partyHint}</Text>
    </View>
  );
}

export function SeyahatFormu({ t, f, set, airports, carriers, kilitli, mod }) {
  return (
    <>
        <AirportPicker t={t} airports={airports} value={f.airport} onSelect={v => set("airport", v)} />

        {/* destination char(3) — serbest metin DEGIL, havalimani kodu.
            "Londra LHR" yazilsaydi insert 22001 ile patlardi. */}
        <AirportPicker t={t} label={t.avDestLabel} airports={airports} value={f.destination} onSelect={v => set("destination", v)} />
        <DateInput value={f.date} onChange={v => set("date", v)} />

        <View style={{ flexDirection: "row", marginBottom: ARA[14] }}>
          <TimeInput label={t.avStart} value={f.from} onChange={v => set("from", v)} />
          <View style={{ width: 8 }} />
          <TimeInput label={t.avEnd} value={f.to} onChange={v => set("to", v)} />
        </View>

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[1], letterSpacing: 1 }}>{t.avFlightLabel}</Text>
        {/* v2.47 — HAVAYOLU SECIMI (cihazda istendi). Kural motoru
            tasiyiciya gore karar verir (md.17: THY yolcusu yalniz THY
            yolcusunu davet eder; AJet listesinde IST yoktur). Secim,
            ucus numarasinin onekini de hazirlar. */}
        {/* 🔴 v2.79 — DÖRT ÇİP YERİNE TAM LİSTE + ARAMA.
            Çipler yalnız THY/AJet/Pegasus/SunExpress veriyordu; beşinci
            seçenek "Diğer" idi ve BOŞ kaydediyordu. Yani Lufthansa ile
            uçan bir misafirin taşıyıcısı hiç yazılamıyordu — kural motoru
            "misafir aynı havayolunda mı" sorusunu yanıtsız alıyordu.
            Sık kullanılan dördü listenin BAŞINDA duruyor, hız kaybı yok. */}
        <CarrierPicker t={t} carriers={carriers} value={f.carrier}
          label={t.carrierLabel || "HAVAYOLU"}
          onSelect={(cd) => {
            set("carrier", cd);
            // Uçuş numarası öneki çipten geliyordu; davranış korunuyor.
            if (cd && !String(f.flight || "").toUpperCase().startsWith(cd)) {
              const digits = String(f.flight || "").replace(/^[A-Za-z]+/, "");
              set("flight", cd + digits);
            }
          }} />
        {/* 🔴 v2.68 — AYNI BİLEŞEN BURADA DA. Uyarı artık KOŞULLU:
            numara doğrulanabildiyse "elle girildi" demiyoruz (doğrulanmış
            bir uçuşa öyle demek yalan olurdu), doğrulanamadıysa aynen
            duruyor. Uçuş numarası burada da İSTEĞE BAĞLI. */}
        <FlightField t={t} value={f.flight} onChange={v => set("flight", v)}
          date={f.date} carrier={f.carrier} showChips={false} hideLabel
          manualWarn={t.flightManualWarn}
          inputStyle={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.sm }} />
        <View style={{ height: 14 }} />

        {/* MVP: SEYAHAT AMACI cipleri */}
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.intentLabel}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[20] }}>
          {PURPOSES.map(([k, lb, ic]) => {
            const sel = f.purpose === k;
            return (
              <Secim key={k} ton="teal" secili={sel} etiket={gorunur(lb)}
                onPress={() => set("purpose", sel ? "" : k)}
                ikon={<Ikon ad={ic} boy={13} renk={sel ? C.teal : C.muted} />}
                stil={{ marginRight: SP[2], marginBottom: SP[2] }} />
            );
          })}
        </View>
        {/* Ön seçim kaldırıldığı için "boş bırakabilirsin" cümlesi ŞART:
            yoksa kullanıcı zorunlu sanıp rastgele bir çip seçer ve
            sağlayıcıya giden beyan oranı yine yalan olur. */}
        <Text style={{ color: C.muted, fontSize: FS.xs, lineHeight: 16, marginBottom: SP[4] }}>
          {t.purposeOptional}
        </Text>

        {/* SQL 283 — kişi sayısı + çocuk: kural motorunun 1. ve 2. boyutu */}
        <KisiSayisi t={t} kisi={f.kisi} cocuk={f.cocuk}
          onKisi={v => set("kisi", v)} onCocuk={v => set("cocuk", v)} />

    </>
  );
}

// ════════════════════════════════════════════════════════════════════════
// SEYAHAT DÜZENLE  (v3.4 · YENİDEN YAZILDI)
//
// 🔴 GÖKBERK: "seyahat düzenle ekranı seyahat ekle ile birebir aynı olmalı
// ki istediğim alanı düzenleyebileyim... düzenleye tıkladığımda mevcut
// verilerle gelmeli."
//
// ESKİ HÂLİ dört DÜZ METİN KUTUSUYDU. Havalimanı elle "IST" yazılıyordu,
// tarih elle "2026-09-04", saatler maskesiz — `"1400"` yazan biri
// sunucuya `"1400:00"` gönderiyordu. VARIŞ, HAVAYOLU ve AMAÇ alanları
// hiç yoktu.
//
// Artık ekleme ekranıyla AYNI bileşen (`SeyahatFormu`): aynı seçiciler,
// aynı doğrulama, aynı alanlar. Ön doldurma zaten vardı ve korunuyor —
// ama artık gelen değer bir metin kutusuna değil, DOĞRU SEÇİCİYE düşüyor.
//
// Sunucu tarafı: SQL 262 (`update_visit`e `p_purpose` eklendi; `p_carrier`
// 237'den beri vardı ama form onu hiç göndermiyordu).
// ════════════════════════════════════════════════════════════════════════
export function EditTrip({ t, visit, onBack, onDone }) {
  const [f, setF] = useState({
    airport: String(visit?.airport_code || ""),
    destination: String(visit?.destination || ""),
    date: String(visit?.visit_date || ""),
    from: String(visit?.time_from || "").slice(0, 5),
    to: String(visit?.time_to || "").slice(0, 5),
    flight: String(visit?.flight_number || ""),
    // 🔴 BU İKİSİ ESKİDEN DURUMDA BİLE YOKTU — yani kayıtlı değerler
    // ekrana hiç gelmiyor, kaydedince de SIFIRLANMA riski taşıyordu.
    carrier: String(visit?.carrier_code || ""),
    purpose: String(visit?.purpose || ""),
    // SQL 283 — kayıtlı kişi sayısı ve çocuk yaşları da forma gelir
    kisi: Number(visit?.party_size) || 1,
    cocuk: Array.isArray(visit?.child_ages) ? visit.child_ages : [],
  });
  const [airports, setAirports] = useState([]);
  const [carriers, setCarriers] = useState([]);
  const [bagli, setBagli] = useState(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  // 3 Eylül — tasarım 14: seyahat kartında × yok. İptal, seyahatin
  // kendi düzenleme ekranında (tek kapı, onaylı).
  const [iptalSor, setIptalSor] = useState(false);

  const set = (k, v) => setF(x => ({ ...x, [k]: v }));

  useEffect(() => {
    let iptal = false;
    (async () => {
      // 🔴 v3.4 — ÜÇ İŞ TEK DALGADA. Eskiden yalnız `my_sent_requests`
      // vardı; katalogları da çekmek gerekiyor ama SIRAYLA çekmek yeni
      // bir şelale yaratırdı. Aynı turda gidiyorlar.
      const [rq, ap, cs] = await Promise.all([
        supabase.rpc("my_sent_requests"),
        havalimanlariniGetir(),
        carrierlariGetir(),
      ]);
      if (iptal) return;
      setAirports(ap || []);
      setCarriers(cs || []);
      if (rq.error) { logError("edit_trip_reqs", rq.error); setBagli(0); return; }
      const n = (rq.data || []).filter(r =>
        (r.status === "pending" || r.status === "accepted") &&
        r.airport_code === visit?.airport_code &&
        String(r.avail_date) === String(visit?.visit_date)).length;
      setBagli(n);
    })();
    return () => { iptal = true; };
  }, [visit?.id, visit?.airport_code, visit?.visit_date]);

  const kilitli = (bagli || 0) > 0;

  async function kaydet() {
    if (busy) return;
    // 🔴 EKLEME EKRANINDAKİ DOĞRULAMA BURADA DA. Eskiden yoktu: maskesiz
    // saat kutusuna "1400" yazan kullanıcı `"1400:00"` gönderiyordu ve
    // hatayı ancak sunucudan öğreniyordu.
    if (!f.airport) { setErr(t.avPickAirport || "Havalimanı seç"); return; }
    if (String(f.date).length !== 10) { setErr(t.avFixDate || "Tarihi tamamla (YYYY-AA-GG)"); return; }
    setBusy(true); setErr(""); setOk("");
    const { error } = await supabase.rpc("update_visit", {
      p_id: visit.id,
      p_airport: f.airport || null,
      p_destination: f.destination || null,
      p_date: f.date || null,
      p_from: f.from ? f.from + ":00" : null,
      p_to: f.to ? f.to + ":00" : null,
      p_flight: f.flight,
      p_carrier: f.carrier || null,
      p_purpose: f.purpose || null,
    });
    // SQL 283 — kişi sayısı ayrı RPC: update_visit imzasına dokunmadan.
    let hata283 = error;
    if (!hata283) {
      const { error: hataP } = await supabase.rpc("set_visit_party", {
        p_visit_id: visit.id, p_kisi: Number(f.kisi) || 1,
        p_cocuk_yas: (f.cocuk || []).length ? f.cocuk : null });
      if (hataP) { logError("set_visit_party", hataP); hata283 = hataP; }
    }
    setBusy(false);
    if (hata283) { setErr(mapErr(t, hata283.message)); return; }
    setOk(t.editDone);
    if (onDone) onDone();
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.scenePlan} title={t.editTrip} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {kilitli ? (
          <View style={[S.card, { borderColor: "transparent", borderWidth: 1.5, marginBottom: SP[3] }]}>
            <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18 }}>{t.editTripLocked}</Text>
          </View>
        ) : null}

        <SeyahatFormu t={t} f={f} set={set} airports={airports} carriers={carriers}
                      kilitli={kilitli} mod="duzenle" />

        {err ? <Text style={{ color: C.red, fontSize: FS.sm, marginTop: ARA[10] }}>{err}</Text> : null}
        {ok ? <Text style={{ color: C.green, fontSize: FS.sm, marginTop: ARA[10] }}>{ok}</Text> : null}

        <Btn label={busy ? "…" : t.editSave} onPress={kaydet} disabled={busy} a11yLabel={t.editSave} style={{ marginTop: ARA[14] }} />
        <TouchableOpacity hitSlop={TAP.slop} onPress={() => setIptalSor(true)} disabled={busy}
          accessibilityRole="button" accessibilityLabel={t.a11yCancelTrip}
          style={{ alignItems: "center", marginTop: ARA[14], minHeight: TAP.minHeight, justifyContent: "center" }}>
          <Text style={{ color: C.red, fontSize: FS.sm, fontWeight: "600" }}>{t.cancelTripConfirm}</Text>
        </TouchableOpacity>
      </ScrollView>
      <ConfirmModal
        visible={iptalSor}
        title={t.cancelTripTitle}
        body={visit ? (visit.airport_code + (visit.destination ? " \u2192 " + visit.destination : "") + " \u00b7 " + visit.visit_date + " \u2014 " + t.cancelTripBody) : ""}
        confirmLabel={t.cancelTripConfirm}
        cancelLabel={t.confirmNo}
        danger busy={busy}
        onCancel={() => setIptalSor(false)}
        onConfirm={async () => {
          setBusy(true);
          // SQL 240/296: `seyahat_sil` başvurusu olan seyahati reddeder ve
          // anlaşılır kod döndürür; burada gösterilir, yutulmaz.
          const { error: eDel } = await supabase.rpc("seyahat_sil", { p_id: visit.id });
          setBusy(false); setIptalSor(false);
          if (eDel) { setErr(mapErr(t, eDel.message)); return; }
          if (onDone) onDone();
          if (onBack) onBack();
        }}
      />
    </Sayfa>
  );
}

// ============================================================
// AddVisit — MVP v15 satir 1603-1640'in portu.
//
// MVP'de Trips ekraninda "+ Add" -> BU EKRAN. v1.21'de "Seyahat" AYRI TAB'di
// ve icinde havalimani kodunu elle yaziyordun (ekran goruntusu: "2026" yazip
// tarihi elle ugrasiyordun).
//
// MVP'den BIREBIR gelenler:
//   · AirportPicker (elle yazma yok)
//   · Varis / Tarih / Baslangic / Bitis / Ucus(ops)
//   · SEYAHAT AMACI cipleri: Business/Conference/Leisure/Connecting/Event
//   · Ucus alaninda uyari: "Elle girildi — dogrulanmadi."
// Bizim eklememiz: maskeli DateInput/TimeInput (Gokberk'in istegi).
// ============================================================
// [db_value, TR etiket, ikon] — DB'de CHECK kisiti ingilizce degerleri
// bekliyor (044). Etiketi cevirebiliriz, degeri asla degistiremeyiz.

// ============================================================
// HostAvailability — MVP v15 satir 726-779'un portu.
//
// MVP'de host'un musaitlik yayinlama ekrani. v1.21'de "Yayin" AYRI TAB'di.
// MVP'den BIREBIR gelenler:
//   · "Host Setup · Step 2 of 2" rozeti
//   · AirportPicker -> LoungePicker (havalimani secilince lounge listesi gelir)
//   · MISAFIR SLOTU: 1/2/3 buyuk kutu secim (elle sayi yazma YOK)
//   · GORUNURLUK: 3 secenekli radio
//       all     -> Tum dogrulanmis misafirlere gorunur
//       trusted -> Yalniz guvenilir misafirler (onerilen)  <- MVP varsayilani
//       hidden  -> Eslesmedikce gizli
//   · Telefon dogrulanmamissa PhoneGate -> VerifyPhone'a yollar
// ============================================================
// 🔴 v2.65 — görünürlük etiketleri i18n'e bağlandı; anahtarlar (all/trusted/
// hidden) SUNUCU değerleri olduğu için sabit kaldı.
export const visOpts = (t) => [
  ["all", t.haVisAll],
  ["trusted", t.haVisTrusted],
  ["hidden", t.haVisHidden],
];

// ============================================================
// İLAN DÜZENLE (v2.89 · Gökberk md.13)
//
// 🔴 NEDEN AYRI BİR EKRAN: `HostAvailability` create-only ve 1000+
// satır — içine bir "düzenleme modu" koymak, o ekranın her dalını iki
// kez düşünmek demekti. Düzenleme YAPISI da farklı: burada salon
// seçimi ikincil, ASIL SORU "neyi değiştirebilirim?".
//
// Sözleşme kilidi sunucuda (SQL 237): kabul edilmiş başvuru varken
// tarih/saat/salon değişmiyor. Ekran o kuralı ÖNCEDEN söylüyor —
// kullanıcıyı formu doldurup hata almaya bırakmak, kuralı hiç
// söylememekten kötüdür.
// ============================================================
// ⚠️ `session` imzada YOK ve olmamalı: bu ekran hiçbir yerde uid
// okumuyor, tüm yetki kontrolü sunucuda (`update_availability` auth.uid()
// ile sahipliği doğruluyor). Ölü prop nöbetçisi ilk yazımda yakaladı —
// haklı: imzada duran ama okunmayan prop, sonraki geliştiriciye
// "burada bir şey var" diye yalan söyler.
// ════════════════════════════════════════════════════════════════════════
// İLAN DÜZENLE (v2.95 · Gökberk madde 14)
//
// "ilan düzenle sayfasındaki alanların, müsaitlik ekle sayfasındaki alanlar
//  ile birebir aynı olması lazım. Ek olarak değişikliği kaydet dediğimde her
//  türlü 'slot sayısı kapasiteni aşıyor' hatası çıkıyor."
//
// İKİ AYRI İŞ, İKİSİ DE YAPILDI:
//
// 1) KAYDEDEMEME — sunucuda. `update_availability` kapasite kapısını
//    KOŞULSUZ çalıştırıyordu; host yalnız uçuş numarasını düzeltse bile
//    `no_access_source` / `slots_exceed_capacity` alıyordu. SQL 248 kapıyı
//    "slot sayısını ARTIRIYORSAN" koşuluna bağladı. Ölçüm dosyanın içinde.
//
// 2) ALANLARIN AYNI OLMASI — burada. Eski düzenleme ekranı DÖRT düz metin
//    kutusundan ibaretti (tarih, saat, kontenjan, uçuş). "Müsaitlik ekle"
//    ekranında ise ON bir alan var: salon seçici, havayolu seçici, kabin,
//    charter, tarih seçici, saat seçici, uçuş alanı (doğrulamalı), slot
//    kutuları, görünürlük. Yani host bir ilanı AÇARKEN sorduğumuz sorunun
//    yarısını DÜZENLERKEN soramıyordu — ve o alanlar kural motorunun karar
//    girdileri. Taşıyıcısı yanlış girilmiş bir ilan düzeltilemiyordu.
//
// 🆕 SINIF: "BİR NESNEYİ YARATAN FORM İLE DÜZENLEYEN FORM AYRI YAZILIRSA,
// DÜZENLEME FORMU HER ZAMAN GERİDE KALIR — ÇÜNKÜ YENİ ALANLAR HEP YARATMA
// TARAFINA EKLENİR."
//
// Bu yüzden yalnız alanları eşitlemekle yetinmedim: `alan_esitligi_check.py`
// nöbetçisi iki ekranın alan kümesini karşılaştırıyor. Biri diğerinden
// ayrılırsa `npm run verify` kırmızı yanar. İnsan dikkatine bırakılan
// "birebir aynı" sözü, bir sonraki özellikte bozulur.
//
// HAVALİMANI BİLEREK KİLİTLİ: `update_availability` salon (`lounge_id`)
// güncelliyor ama `airport_code` kolonuna DOKUNMUYOR. Başka havalimanından
// bir salon seçilseydi ilan "IST kodlu, ESB salonlu" bir yalan olurdu.
// Alan görünür ve kilitli — gizlemek yerine SEBEBİNİ yazıyoruz.
// ════════════════════════════════════════════════════════════════════════

// ============================================================
// ReportUser — v1.22'de EKLENDI.
//
// `reports` tablosu 001'den beri var, BO'nun moderasyon kuyrugu
// 021'den beri var, `resolve_report` 029'da var — ama kullanicinin
// rapor OLUSTURACAGI ekran ve RPC hic yazilmamisti. BO'daki kuyrugun
// hep bos olmasinin sebebi buydu: doldurmanin bir yolu yoktu.
//
// report_type enum'u (001) SABIT ve tam olarak sunlar:
//   harassment · fraud · fake_profile · off_platform_payment · other
// Yeni deger EKLEMIYORUZ — enum cerrahisi Supabase editorunde riskli.
// ============================================================
export function Campaigns({ t, onBack }) {   // v2.65: ölü `session` kaldırıldı
  const [tab, setTab] = useState("camps");     // #23: iki sekme
  const [rows, setRows] = useState(null);
  const [loadErr, setLoadErr] = useState(false);   // v2.65 — bkz. Trips
  const [detail, setDetail] = useState(null);  // #23: detay gorunumu
  const [code, setCode] = useState("");
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const [joinBusy, setJoinBusy] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("active_campaigns");
    if (error) { setLoadErr(true); return; }
    setLoadErr(false);
    setRows(Array.isArray(data) ? data : []);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function redeem() {
    if (!code.trim()) return;
    setBusy(true); setMsg(null);
    const { data, error } = await supabase.rpc("redeem_promo_code", { p_code: code.trim() });
    setBusy(false);
    if (error) {
      const m = error.message || "";
      setMsg({ ok: false, text: m.includes("already_used") ? t.promoErrUsed
        : m.includes("limit") ? t.promoErrLimit : t.promoErrInvalid });
      return;
    }
    setCode("");
    setMsg({ ok: true, text: (data?.reward_type === "credits" ? `+${data.amount} ` + t.promoOkCredits : `+${data?.amount ?? ""} ` + t.promoOkPoints) });
  }

  async function join(id) {
    setJoinBusy(true);
    const { error } = await supabase.rpc("join_campaign", { p_id: id });
    setJoinBusy(false);
    if (!error) { await load(); setDetail(d => d ? { ...d, joined: true } : d); }
  }

  // ---- Detay gorunumu (#23): karta tiklaninca acilir; Katil burada ----
  if (detail) return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneGuide} title={detail.title} onBack={() => setDetail(null)} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <View style={S.card}>
          {!!detail.description && <Text style={{ color: C.body, fontSize: FS.base, lineHeight: 22 }}>{detail.description}</Text>}
          {!!detail.ends_at && <IkonMetin ad="bekliyor" renk={C.amber} stilMetin={{ color: C.amber, fontSize: FS.sm, marginTop: ARA[10] }} metin={`${t.campEnds}: ${detail.ends_at}`} />}
        </View>
        {detail.joinable === false ? null : detail.joined ? (
          <View style={{ backgroundColor: C.greenBg, borderRadius: R.sm, paddingVertical: ARA[14], alignItems: "center" }}>
            <Text style={{ color: C.greenInk, fontWeight: "700", fontSize: FS.base }}>{t.campJoined}</Text>
          </View>
        ) : (
          <Btn v="gold" sm label={t.campJoin} onPress={() => join(detail.id)} disabled={joinBusy} busy={joinBusy} />
        )}
      </ScrollView>
    </Sayfa>
  );

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneGrow} title={t.campaignsTitle} sub={t.campaignsSub} onBack={onBack} />
      {/* #23: iki sekme */}
      <View style={{ flexDirection: "row", backgroundColor: C.card, borderBottomWidth: 1, borderBottomColor: C.line }}>
        {[["camps", t.campTabActive], ["code", t.campTabCode]].map(([k, lb]) => (
          <TouchableOpacity hitSlop={TAP.slop} key={k} onPress={() => setTab(k)}
            style={{ flex: 1, paddingVertical: SP[3], alignItems: "center", borderBottomWidth: 2, borderBottomColor: tab === k ? C.gold : "transparent" }}>
            <Text style={{ color: tab === k ? C.gold : C.mut, fontWeight: "700", fontSize: FS.sm }}>{lb}</Text>
          </TouchableOpacity>
        ))}
      </View>
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {tab === "code" ? (
          <View style={S.card}>
            <Text style={S.label}>{t.promoLabel}</Text>
            <View style={{ flexDirection: "row", gap: SP[2], alignItems: "center" }}>
              <TextInput style={[S.input, { flex: 1, letterSpacing: 2 }]} value={code}
                onChangeText={x => setCode(x.toUpperCase())} autoCapitalize="characters"
                placeholder={t.promoPlaceholder} placeholderTextColor={C.dim} maxLength={20} />
              <Btn v="gold" sm full={false} label={t.promoApply} onPress={redeem} disabled={busy || !code.trim()} busy={busy} />
            </View>
            {msg && (
              <View style={{ backgroundColor: msg.ok ? C.greenBg : C.redBg, borderRadius: R.xs, padding: ARA[10], marginTop: ARA[10] }}>
                <Text style={{ color: msg.ok ? C.green : C.red, fontSize: FS.sm }}>{msg.text}</Text>
              </View>
            )}
          </View>
        ) : loadErr ? <LoadFail t={t} onRetry={load} />
          : rows === null ? <Load /> : rows.length === 0 ? (
          <BosDurum ikon="kampanya" metin={t.campEmpty} />
        ) : rows.map(c => (
          <TouchableOpacity hitSlop={TAP.slop} key={c.id} onPress={() => setDetail(c)} activeOpacity={0.75}
            style={[S.card, c.joined && { borderColor: C.green }]}>
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.lg, flex: 1 }}>{c.title}</Text>
              {c.joined && <Text style={{ color: C.green, fontSize: FS.sm, fontWeight: "700" }}>{t.campJoined}</Text>}
            </View>
            {!!c.description && <Text numberOfLines={2} style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[1], lineHeight: 19 }}>{c.description}</Text>}
            <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: SP[2] }}>
              {c.ends_at ? <IkonMetin ad="bekliyor" renk={C.amber} stilMetin={{ color: C.amber, fontSize: FS.sm }} metin={`${t.campEnds}: ${c.ends_at}`} /> : <View />}
              <IkonMetin sag ad="sag" renk={C.gold} stilMetin={{ color: C.gold, fontSize: FS.sm, fontWeight: "600" }} metin={t.campDetail} />
            </View>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </Sayfa>
  );
}


// ============ HomeConnections — ana sayfada kabul edilmiş bağlantılar ============
// 🔴 Canlı APP 17: bağlantı kabul edilince ana sayfadan tamamen kayboluyordu;
// kullanıcı "ne oldu?" diye kalıyordu. MVP'de ana sayfada yalnızca bir
// "Yol Arkadaşları" banner'ı var; burada bir adım öteye gidip kabul edilmiş
// bağlantıları SOHBET BUTONUYLA gösteriyoruz — bağlantı izsiz kaybolmasın.
// ════════════════════════════════════════════════════════════════════════
// HOST DAVETİ (v2.96 · eleştiri A1)
//
// "Host'u çekmeye yönelik yeterli şeyimiz yok gibi?"
//
// ÖLÇTÜM VE CEVAP BEKLENDİĞİNDEN İYİ: yeterince şeyimiz VAR, hiçbirini
// GÖSTERMİYORUZ. `host_tiers` dört mertebe ve her birinin ölçülebilir bir
// karşılığı; SQL 236 iki ağırlamadan sonra 30 gün ücretsiz üst plan
// veriyor — otomatik, tetikleyiciyle. Ama bu ekranların hepsi yalnız HOST
// rolündeki kullanıcıya görünüyordu. Yani teklifi, yalnızca teklifi zaten
// kabul etmiş olanlara yapıyorduk.
//
// 🆕 SINIF: "BİR MERDİVENİ YALNIZCA ÜZERİNDE DURANLARA GÖSTERİRSEN, KİMSE
// İLK BASAMAĞA ÇIKMAZ."
//
// ÇERÇEVE DE DEĞİŞTİ VE BU EN AZ ÖDÜL KADAR ÖNEMLİ: host'a "iyilik yap"
// demiyoruz. "Yanında kimin oturacağına sen karar veriyorsun" diyoruz.
// Ağırlamak bir bağış değil, bir seçim. Veriyi zaten topluyoruz (meslek,
// seyahat amacı, aynı uçuş, güven puanı) ama bu dili hiç kurmamıştık.
// ════════════════════════════════════════════════════════════════════════
// 🔴 ROL FARKINDALIĞI (v3.6)
// `calmPulseEmpty` misafire "İlk ilanı sen açabilirsin" diyordu. SQL 261'den
// beri misafir ilan AÇAMAZ (`not_a_host`). Yani boş ağ metni host için
// yazılmış, herkese gösteriliyordu: kullanıcıyı yapamayacağı bir eyleme
// davet eden bir cümle, boş ekrandan daha kötüdür.
//
// 🆕 SINIF: "BOŞLUK METNİ, O BOŞLUĞU DOLDURABİLECEK KİŞİYE GÖRE YAZILIR —
// AKSİ HÂLDE ÜRÜN, KAPISINI KİLİTLEDİĞİ ODAYA DAVET EDER."
//
// Ve boş bir ağda çalışan TEK ekran Salon Rehberi'dir: arz gerektirmez,
// tek başına bir soruya cevap verir. Bu yüzden sakin günün çıkışları
// arasına girdi.
export function SakinGun({ t, session, role, bekleyenVar, onDiscover, onPlan, onHostOl, onMeet, onGuide }) {
  const [nabiz, setNabiz] = useState(null);
  const [yakin, setYakin] = useState(null);

  useEffect(() => {
    let iptal = false;
    (async () => {
      const uid = session?.user?.id;
      if (uid) {
        // (aşağıdaki dalgada okunuyor)
      }
      // 🔴 v3.9 — İKİ TUR TEK DALGADA. Kullanıcının yaklaşan seyahati ile
      // havalimanı nabzı birbirinden bağımsız; kart ikisini de bekliyordu.
      // `uid` yoksa seyahat sorgusu HİÇ AÇILMIYOR — dalgaya `null` giriyor,
      // yani oturumsuz kullanıcı için fazladan bir tur da eklenmiyor.
      const [vRes, { data, error }] = await Promise.all([
        uid ? supabase.from("visits")
          .select("airport_code, visit_date").eq("user_id", uid)
          .gte("visit_date", yerelGun())
          .order("visit_date").limit(1)
          : Promise.resolve({ data: null, error: null }),
        supabase.rpc("havalimani_nabzi", { p_gun: 14 }),
      ]);
      if (vRes.error) logError("sakin_gun_visit", vRes.error);
      if (!iptal) setYakin((vRes.data && vRes.data[0]) || null);
      if (error) { logError("havalimani_nabzi", error); return; }
      if (!iptal) setNabiz(Array.isArray(data) ? data : []);
    })();
    return () => { iptal = true; };
  }, [session]);

  // Bekleyen iş varsa bu kart HİÇ çizilmez: sakin gün değil.
  if (bekleyenVar) return null;

  const benimAp = yakin?.airport_code || null;
  const satir = benimAp && Array.isArray(nabiz)
    ? nabiz.find(x => x.airport_code === benimAp) : null;
  const enCanli = Array.isArray(nabiz)
    ? nabiz.filter(x => x.durum === "canli").slice(0, 3) : [];

  return (
    <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
                   borderRadius: R.sm, padding: ARA[18], marginTop: ARA[14] , ...ELEV.card }}>
      {/* 🔴 23 Eylül — üst satır SABİT "BUGÜN" yazıyordu; altında "7 gün kaldı"
          duruyordu (sahne 11/19/39). Seyahat bugün değilse başlık "SIRADAKİ
          SEYAHATİN" olur; "gün kaldı" da KALKIŞ için ayrı bir anahtar. */}
      <Text style={{ color: C.dim, fontSize: FS.micro, letterSpacing: 1.6, fontWeight: "700" }}>
        {BUYUK((yakin && yakin.visit_date && String(yakin.visit_date).slice(0, 10) !== new Date().toISOString().slice(0, 10))
          ? (t.nextTripEyebrow || t.calmEyebrow || "") : (t.calmEyebrow || ""))}
      </Text>
      {/* 🔴 3 EYLÜL — TASARIM 11 "BUGÜN" KARTI: başlık sıradaki seyahat
          ("Esenboğa · 14 gün"), altı tek cümle, altın "Misafir olarak host
          bul". Seyahat yoksa eski sakin-gün cümlesi. */}
      <Text style={{ color: C.ink, fontSize: FS.lg + 3, fontWeight: "700", marginTop: SP[2] }}>
        {yakin && yakin.visit_date
          ? `${yakin.airport_code} · ${(() => { const g = Math.max(0, Math.round((new Date(yakin.visit_date) - new Date(yerelGun())) / 86400000)); return g === 0 ? BUYUK(t.calmEyebrow || "") : g === 1 ? (t.tripTomorrow || "yarın") : String(t.tripDaysLeft || t.planGiftLeft || "{n} gün").replace("{n}", String(g)); })()}`
          : t.calmTitle}
      </Text>
      {yakin && yakin.visit_date ? (
        <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>
          {t.heroWithTripSub}
        </Text>
      ) : null}

      {/* AĞIN GERÇEK HÂLİ — gizlemiyoruz (seyahat yokken; seyahat varken
          tasarım 11'in kartı üç satırdır: başlık · cümle · düğme). */}
      {!yakin && satir ? (
        <Text style={{ color: C.body, fontSize: FS.sm, marginTop: SP[2], lineHeight: 18 }}>
          {satir.host_sayisi > 0
            ? String(t.calmPulseSome)
                .replace("{ap}", String(satir.airport_code))
                .replace("{n}", String(satir.host_sayisi))
                .replace("{slot}", String(satir.acik_slot))
            : String(role === "host" ? t.calmPulseNone : t.calmPulseNoneGuest)
                .replace("{ap}", String(satir.airport_code))}
        </Text>
      ) : nabiz && nabiz.length === 0 ? (
        <Text style={{ color: C.body, fontSize: FS.sm, marginTop: SP[2], lineHeight: 18 }}>
          {role === "host" ? t.calmPulseEmpty : t.calmPulseEmptyGuest}
        </Text>
      ) : null}

      {!yakin && enCanli.length > 0 && (
        <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[2] }}>
          {enCanli.map(x => (
            <Pill key={x.airport_code} c={C.green}>
              {x.airport_code} · {x.host_sayisi} {t.calmHosts}
            </Pill>
          ))}
        </View>
      )}

      <Btn v="gold" label={role === "host" ? t.calmFind : t.fhAsGuest} onPress={onDiscover}
        a11yLabel={role === "host" ? t.calmFind : t.fhAsGuest} style={{ marginTop: ARA[14] }} />

      {/* Host olmayana merdiven; host'a kendi planı. Seyahat varken kart
          tasarım 11 gibi üç parçadır; bu bağlantılar yalnız boş günde. */}
      {yakin ? null : <>
      <TouchableOpacity onPress={role === "host" ? onPlan : onHostOl}
        accessibilityRole="button"
        accessibilityLabel={role === "host" ? t.calmMyPlan : t.calmBecomeHost}
        style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.sm, minHeight: TAP.minHeight,
                 alignItems: "center", justifyContent: "center", marginTop: SP[2] }}>
        <Text style={{ color: C.ink, fontWeight: "600", fontSize: FS.sm }}>
          {role === "host" ? t.calmMyPlan : t.calmBecomeHost}
        </Text>
      </TouchableOpacity>
      {/* Arz sıfırken bile cevap veren tek ekran. */}
      {onGuide ? (
        <TouchableOpacity onPress={onGuide} hitSlop={TAP.slop}
          accessibilityRole="button" accessibilityLabel={t.calmGuide}
          style={{ minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center", marginTop: SP[1] }}>
          <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.calmGuide}</Text>
        </TouchableOpacity>
      ) : null}
      <TouchableOpacity onPress={onMeet} hitSlop={TAP.slop}
        accessibilityRole="button" accessibilityLabel={t.calmMeet}
        style={{ minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center", marginTop: SP[1] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.calmMeet}</Text>
      </TouchableOpacity>
      </>}
    </View>
  );
}

// ============================================================
// BAĞLANTI İSTEKLERİ (v2.95 · Gökberk madde 9)
//
// "Bağlantı kur ile gönderilen bağlantı istekleri ana sayfada gözükmüyor.
//  Ayrıca Tanış ekranında Keşfet ve Bağlantılar yanına bir 'Bağlantı
//  istekleri' tabı da eklemeyi düşünelim."
//
// ÖLÇTÜM — iki ayrı boşluk vardı:
//  (a) GÖNDERDİĞİN isteği gösteren HİÇBİR sorgu yoktu. Meet yalnız
//      `to_id = ben and status = pending` çekiyordu. Gönderdikten sonra
//      eylemin izi ortadan kayboluyordu; kullanıcı "gitti mi?" diye
//      sormaktan başka bir şey yapamıyordu.
//  (b) Ana sayfadaki `home_connections` yalnız KABUL EDİLMİŞ bağlantıların
//      sohbetlerini döndürüyor. Bekleyen hiçbir yerde yoktu.
//
// 🆕 SINIF: "BİR EYLEMİN SONUCUNU GÖSTERMİYORSAN, KULLANICI EYLEMİ
// YAPMADIĞINI SANIR VE TEKRAR YAPAR."
//
// Tek bileşen iki yerde: ana sayfada katlanır panel, Tanış'ta sekme.
// İki ayrı kopya yazsaydım, bir sonraki değişiklikte ayrılırlardı.
// ============================================================
export function HomeConnections({ t, session, onOpenChat, tamEkran, tazele }) {
  const uid = session?.user?.id;
  // 🔴 19 EYLÜL · DERİN DENETİM — "MESAJ AT" SESSİZCE ÖLÜYDU.
  // `baglanti_sohbeti_ac` engellenmiş çiftte BİLİNÇLİ olarak reddediyor
  // (v2.96). Ama istemci hatayı yalnız günlüğe yazıp `return` ediyordu:
  // kullanıcı bağlantı kartına dokunuyor — kartın TEK eylemi bu — ve
  // hiçbir şey olmuyor. "Neden açılmıyor?" sorusunun cevabı hiçbir
  // yerde yoktu.
  // 🆕 SINIF: "SUNUCUNUN BİLİNÇLİ REDDİ, İSTEMCİDE YAZILMAZSA BİR KURAL
  // DEĞİL BİR ARIZADIR."
  const [sohbetHatasi, setSohbetHatasi] = useState("");
  // 🔴 v2.65 — error YAKALANIYORDU ama `setRows([])` yapıp `null` render
  // ediliyordu: bölüm ekrandan TAMAMEN siliniyordu. Kullanıcının bağlantıları
  // duruyor, ekranda yok. Sessiz kaybolma, hata mesajından beterdir.
  const [rows, setRows] = useState(null);
  const [loadErr, setLoadErr] = useState(false);

  const load = useCallback(async () => {
    if (!uid) return;
    // 🔴 v2.48 — CİHAZDA GÖRÜLDÜ + YERELDE ÖLÇÜLDÜ: bu bileşen üç tabloya
    // doğrudan gidiyordu ve chat_channels'ta authenticated GRANT'ı yoktu →
    // "permission denied" → catch'siz useEffect sessizce ölüyordu → ana
    // sayfada bağlantı HİÇ görünmüyordu. Artık tek RPC (home_connections):
    // grant/RLS dertsiz + 24 saat kuralı SUNUCUDA (kabulden 24 saat; son
    // 24 saatte mesaj varsa sohbet sürdükçe kalır; Tanış > Bağlantılar'da
    // her zaman durur).
    try {
      const { data, error } = await supabase.rpc("home_connections");
      if (error) { setLoadErr(true); return; }
      setLoadErr(false);
      setRows((data || []).map(c => ({
        crId: c.conn_id, peerId: c.peer_id, name: c.peer_name,
        photo: c.peer_photo, channelId: c.channel_id,
      })));
    } catch (e) { setLoadErr(true); }
  }, [uid]);
  // `tazele`: bir bağlantı isteği başka ekranda kabul edildiğinde bu
  // liste de yeniden okunur (md.6 — bayat "Kabul et" ile aynı kök).
  useEffect(() => { load(); }, [load, tazele]);

  async function open(r) {
    let cid = r.channelId;
    if (!cid) {
      // v2.96 (C3): kanal açma sunucuda — engelli çiftte kanal açılmaz.
      const { data, error } = await supabase.rpc("baglanti_sohbeti_ac", { p_conn_id: r.crId });
      if (error) { logError("baglanti_sohbeti_ac", error); setSohbetHatasi(mapErr(t, error.message)); return; }
      setSohbetHatasi("");
      cid = data?.channel_id;
    }
    if (cid && onOpenChat) onOpenChat(cid, r.name);
  }

  // Hata varsa bölüm KAYBOLMAZ; başlığıyla durur ve yeniden denemeyi önerir.
  if (loadErr) return (
    <View style={{ marginTop: SP[1] }}>
      {/* 13 Eylül — DÖRDÜNCÜ "[object Object]" kazası. Bu sefer nesne
          değil DİZİ şablon dizesine kaçmıştı; JS onu da sessizce metne
          çevirir. check.js'in deseni genişletildi — süslü parantezin
          yanında köşeli parantez de sayılıyor.
          (Örneği buraya YAZMIYORUM: nöbetçi düz metin tarıyor ve kendi
          açıklamamı bulgu sayıyor — 12 Eylül'de aynı tuzağa düşmüştüm.) */}
      <IkonMetin ad="kisiler" boy={14} renk={C.purple} metin={t.myConnections}
        stilMetin={[S.label, { color: C.purple }]} />
      <LoadFail t={t} onRetry={load} />
    </View>
  );
  if (rows === null || !rows.length) {
    if (!tamEkran) return null;
    return <BosDurum ikon="kisiler" metin={t.flowChatsEmpty} ortala pano={{ baslik: t.panoSohbetBas, durum: t.panoSohbetDurum }} />;
  }
  // Tam ekranda katlamak anlamsız: ekranın TEK işi bu liste.
  if (tamEkran) return (
    <View>
      {!!sohbetHatasi && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{sohbetHatasi}</Text></View>}
      {rows.map(r => (
        <View key={r.crId} style={[S.card, { flexDirection: "row", alignItems: "center", borderColor: "transparent" }]}>
          <View style={{ width: 38, height: 38, borderRadius: R.full, backgroundColor: C.purpleBg, alignItems: "center", justifyContent: "center", overflow: "hidden", marginRight: ARA[10] }}>
            {r.photo ? <Image source={{ uri: r.photo }} style={{ width: 38, height: 38 }} />
              : <Text style={{ fontWeight: "700", color: C.purpleInk }}>{shortName(r.name).charAt(0)}</Text>}
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{shortName(r.name)}</Text>
            <IkonMetin ad="tamam" renk={C.greenInk} stilMetin={{ color: C.greenInk, fontSize: FS.xs, marginTop: 0 }} metin={t.connActive} />
          </View>
          <Btn v="purple" sm full={false} label={t.openChat} sagAd="sag" a11yLabel={t.openChat}
            onPress={() => open(r)} />
        </View>
      ))}
    </View>
  );
  // 🔴 v2.87 (madde 7) — BAĞLANTI BLOĞU KATLANIR, KAPALI BAŞLAR.
  // Ana sayfanın dibindeki bu blok her bağlantı için tam boy bir kart
  // çiziyordu. Kapalıyken başlıkta kaç bağlantın olduğu ve İLK İSİMLER
  // duruyor — yani "kim var" sorusunun cevabı açmadan da görünüyor.
  const ozetMetni = rows.slice(0, 3).map(r => shortName(r.name)).join(", ")
    + (rows.length > 3 ? ` +${rows.length - 3}` : "");
  return (
    <Katlanir baslik={t.myConnections} sayi={rows.length} ozet={ozetMetni}>
      {!!sohbetHatasi && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{sohbetHatasi}</Text></View>}
      {rows.map(r => (
        <View key={r.crId} style={[S.card, { flexDirection: "row", alignItems: "center", borderColor: "transparent" }]}>
          <View style={{ width: 38, height: 38, borderRadius: R.full, backgroundColor: C.purpleBg, alignItems: "center", justifyContent: "center", overflow: "hidden", marginRight: ARA[10] }}>
            {r.photo ? <Image source={{ uri: r.photo }} style={{ width: 38, height: 38 }} />
              : <Text style={{ fontWeight: "700", color: C.purpleInk }}>{shortName(r.name).charAt(0)}</Text>}
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{shortName(r.name)}</Text>
            <IkonMetin ad="tamam" renk={C.greenInk} stilMetin={{ color: C.greenInk, fontSize: FS.xs, marginTop: 0 }} metin={t.connActive} />
          </View>
          <Btn v="purple" sm full={false} label={t.openChat} sagAd="sag" a11yLabel={t.openChat}
            onPress={() => open(r)} />
        </View>
      ))}
    </Katlanir>
  );
}


// ============ FindHostCard — TEK ve SÜREKLİ görünen "Host Bul" girişi ============
// ÜRÜN KARARI (Gokberk + Claude, 22 Tem): Eskiden "Host Bul" yalnızca seyahat
// eklenince ve HER SEYAHAT İÇİN AYRI çıkıyordu. İki sorun:
//   1) Yeni kullanıcı hiç seyahat eklemeden bu özelliğin VARLIĞINI bilmiyordu
//      (huni deliği — MVP'de sorun değildi çünkü MVP'de kullanıcının hep
//       hazır bir seyahati vardı; gerçek boş-başlangıçta yok).
//   2) 3 seyahat = 3 ayrı kart = tekrar.
// Çözüm: TEK kart, HER ZAMAN görünür, içinde CANLI arz bilgisi.
// Yaklaşan seyahat varsa onu bağlam olarak gösterir ve filtreyi ön-doldurur.
export function FindHostCard({ t, session, onDiscover }) {
  const uid = session?.user?.id;
  // 🔴 v2.65 — ÜÇ DURUM AYRILDI: yükleniyor / hata / gerçek boş.
  // Eskiden stat başlangıçta null'dı ve `(stat?.listings||0) > 0` false
  // dönüyordu; yani kart AÇILIR AÇILMAZ "Şu an açık ilan yok" diyordu.
  // Bu kart ürünün ana huni girişi — ilk saniyede kullanıcıya "burada
  // kimse yok" demek, en pahalı yalan. Artık sayım bitene kadar
  // "sayılıyor…", RPC hata verirse "yeniden bakalım" der.
  const [stat, setStat] = useState(null);
  const [failed, setFailed] = useState(false);
  const [trip, setTrip] = useState(null);
  // 🔴 Canlı APP 1: host'un ana sayfasında "Host Bul" ile KENDİ İLANLARI
  // birbirine karışıyordu. Host da başka host'lara misafir olarak
  // başvurabildiği için kart duruyor ama artık AÇIKÇA öyle etiketleniyor.
  const [amHost, setAmHost] = useState(false);

  const load = useCallback(async () => {
    if (!uid) return;
    const today = yerelGun();
    // Yaklaşan (SÜRESİ GEÇMEMİŞ) en yakın seyahat — bağlam + ön filtre
    // 🔴 v3.9 — ÜÇ TUR TEK DALGAYA. Seyahat · rol · ilan listesi:
    // üçü de yalnız `uid`/sabit parametrelerle çalışıyor, hiçbiri
    // diğerinin sonucunu kullanmıyor. Ana sayfanın en görünür kartı
    // üç tur bekliyordu ("sayılıyor…" yazısı bu yüzden uzun kalıyordu).
    const [{ data: v }, { data: me }, { data: av, error: avErr }] = await Promise.all([
      supabase.from("visits")
        .select("airport_code, visit_date").eq("user_id", uid)
        .gte("visit_date", today).order("visit_date").limit(1).maybeSingle(),
      supabase.from("users").select("role").eq("id", uid).maybeSingle(),
      supabase.rpc("discover_availabilities", {
        p_airport: null, p_sector: null, p_flight: null, p_date: null }),
    ]);
    setTrip(v || null);
    setAmHost(me?.role === "host");
    // 🔴 v1.63 (kart 3 diyor, liste 2 gosteriyor): once availabilities
    // tablosundan HAM sayim yapiliyordu. Ham tablo gorunurluk kapilarini
    // BILMEZ (Hidden/Connections, min_trust esigi, is_staff/kesif-kapali
    // host, kadin-guvenlik, onayli-host kosulu). Discovery ekrani ise
    // discover_availabilities RPC'siyle bu kapilarin HEPSINI uygular —
    // sayilar tutmuyordu. Kart artik AYNI RPC'den sayar: kartta ne
    // gorursen, listede o kadar ilan vardir (tek dogruluk kaynagi).
    // 🔴 error ARTIK YAKALANIYOR. Öncesinde yalnız `data` destructure
    // ediliyordu: ağ/RPC hatası sessizce `null` olup boş listeye dönüşüyordu.
    if (avErr) { setFailed(true); setStat(null); return; }
    // RPC kendi ilanlarini da dondurur (a.host_id = v_uid dali) — kart
    // "misafir olarak host bul" oldugu icin kendini ve dolu ilanlari ele.
    const open = (av || []).filter(a => a.host_id !== uid && !a.fully_booked &&
      Math.max(0, (a.slots || 0) - (a.filled || 0)) > 0);
    const slots = open.reduce((n, a) => n + Math.max(0, (a.slots || 0) - (a.filled || 0)), 0);
    // Havalimani basina KAC HOST musait — "4 ilan · 6 slot" soyut kaliyordu,
    // "IST'te 2 host" somut. (Canli APP 2)
    const byAp = {};
    open.forEach(a => { const k = String(a.airport_code || "").trim(); if (k) byAp[k] = (byAp[k] || 0) + 1; });
    const airports = Object.keys(byAp).sort((a, b) => byAp[b] - byAp[a]);
    const hosts = new Set(open.map(a => a.host_id)).size;
    setFailed(false);
    setStat({ listings: open.length, slots, airports, byAp, hosts });
  }, [uid]);
  useEffect(() => { load(); }, [load]);

  const loading = !failed && stat === null;
  const has = (stat?.listings || 0) > 0;
  // Hata durumunda kart DOKUNUNCA YENİDEN DENER — keşfe götürmez.
  // Boş bir listeye götürmek, hatayı "sonuç" gibi gösterir.
  const onCardPress = () => {
    if (failed) { setFailed(false); return load(); }
    if (loading) return;
    return onDiscover && onDiscover(trip ? { sortTrip: { airport: trip.airport_code, date: trip.visit_date } } : {});
  };
  return (
    <TouchableOpacity hitSlop={TAP.slop} activeOpacity={0.85}
      /* 🔴 v1.71 (Gokberk: "9 slot açık gözükmesine rağmen tıklayınca boş
         dönüyor"): kart, yaklaşan seyahatin havalimanı+tarihine SERT FİLTRE
         uyguluyordu. Kartta tüm havalimanlarının toplamı sayılıp listede tek
         bir güne inilince ekran boş kalıyordu. Artık filtre YOK — tüm açık
         slotlar gösterilir, seyahatine EN UYUMLUDAN en uyumsuza sıralanır
         (aynı havalimanı+tarih → aynı havalimanı → diğerleri). */
      onPress={onCardPress}
      accessibilityRole="button"
      accessibilityLabel={failed ? t.fhRetry : (amHost ? t.fhAsGuest : t.findHost)}
      /* v2.02: kart, ustundeki ilan listesine yapisik duruyordu — iki farkli
         is (kendi ilanlarim / misafir olarak host bul) arasinda gorsel nefes
         yoktu. marginTop ile ayrildi. */
      style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent",
               borderRadius: R.sm, padding: SP[4], marginTop: ARA[18], marginBottom: ARA[14] }}>
      {/* 🔴 MARKA_RUHU §9 — İKON ÇİPİ GRAMERİ. Site ve IG'de kartlar
          sessiz çip + başlık + somut ayrıntı düzeninde; app'te başlığın
          içine emoji gömülüydü. Aynı ürün iki dil konuşmasın diye çip
          buraya da geldi ve emoji başlıktan çıktı. */}
      <View style={{ flexDirection: "row", alignItems: "center" }}>
        <View style={{ flex: 1 }}>
          <ChipIcon ad="ucus" tone="ok" size={34} />
          <Text style={{ color: C.tealInk, fontWeight: "700", fontSize: FS.lg }}>
            {amHost ? t.fhAsGuest : t.findHost}
          </Text>
          <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: SP[1], lineHeight: 17 }}>
            {loading ? t.fhLoading
              : failed ? t.fhRetry
              : has ? t.fhOpen.replace("{h}", stat.hosts).replace("{s}", stat.slots)
              : t.fhEmpty}
          </Text>
        </View>
        <Ikon ad="sag" boy={FS.title} renk={C.teal} />
      </View>
      {!loading && !failed && has && stat.airports.length > 0 && (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginTop: ARA[10] }}>
          {stat.airports.slice(0, 6).map(a => (
            <View key={a} style={{ backgroundColor: C.card, borderWidth: 1, borderColor: "transparent", borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] , ...ELEV.card }}>
              <Text style={{ color: C.tealInk, fontSize: FS.xs, fontWeight: "600" }}>{a} · {stat.byAp[a]}</Text>
            </View>
          ))}
        </View>
      )}
      {trip && (
        <Text style={{ color: C.dimAA, fontSize: FS.xs, marginTop: SP[2] }}>
          {t.fhContext.replace("{ap}", trip.airport_code).replace("{d}", String(trip.visit_date).slice(0, 10))}
        </Text>
      )}
    </TouchableOpacity>
  );
}


// ════════════════════════════════════════════════════════════════════════
// AKIŞ ŞERİDİ — ANA SAYFANIN "BEN BURADAYIM" SATIRI  (v3.4)
//
// 🔴 GÖKBERK (28 Ağustos)
// "ana sayfaya gelen sohbetler, istekler, sorularım gibi alanlar (gerisini
//  sen biliyorsun hepsini yazmadım tek tek) sanki ana sayfaya yansımıyor gibi?"
//
// TEŞHİS — ve sebep sandığımız şey değildi. Ana sayfadaki ALTI bölümün
// hepsi "boşsa hiç çizilme" kuralıyla yazılmış:
//     ActionNeeded · RequestsPanel · HomeConnections · BaglantiIstekleri
//     · RateReminder · LoungeRadarCard
// Tek tek hepsi doğru. Ama altısı aynı anda kaybolduğunda ekran "bugün bir
// şey yok" demiyor, "bu özellikler var mı acaba" dedirtiyor.
//
// 🆕 SINIF: "HER BİRİ TEK BAŞINA DOĞRU OLAN 'BOŞSA GİZLE' KURALLARI BİR
// ARAYA GELDİĞİNDE, EKRAN BOŞ OLDUĞUNU DEĞİL VAR OLMADIĞINI SÖYLER."
//
// Bu şerit HER ZAMAN çiziliyor — sayı sıfır olsa bile. Sıfır bir bilgidir:
// "burası var ve şu an boş". Yokluk bilgi değildir.
//
// Ve bir gerçek ölü kod: `MyQuestions` bileşeni yazılmış, `sorularim()`
// RPC'si var, `App.js` onu import ediyor — ama HİÇBİR YERDE çizilmiyordu.
// "Sorularım" diye bir ekran gerçekten YOKTU. Artık bu şeritten açılıyor.
//
// 🆕 SINIF: "IMPORT EDİLİP HİÇ ÇİZİLMEYEN BİR EKRAN, YAZILMIŞ AMA
// TESLİM EDİLMEMİŞTİR — VE KİMSE ONU ARAMADIĞI İÇİN KAYIP DA SAYILMAZ."
//
// ⚠️ MALİYET: TEK ağ turu (SQL 263 · `ana_sayfa_akisi`). Beş sayı beş ayrı
// sorgudan gelseydi ana sayfaya beş tur eklerdi — aynı turda "app bir tık
// yavaş" da deniyordu; bir şikâyeti çözerken diğerini büyütmezdik.
// ════════════════════════════════════════════════════════════════════════
/* ══════════════════════════════════════════════════════════════════════
   KURAL KARARI — tasarımın 03 ekranı. ÜRÜNÜN FARKININ TEK EKRANI.

   Gökberk bir tur önce haklı olarak sordu: bu ekran neden yok?
   Cevabım "veri yok"tu ve doğruydu ama eksikti — veri VARDI, yalnız
   `discovery_rule_badges` onu dışa verirken tek bir paragrafa
   eziyordu (bkz. sql/275). Önce veriyi açtım, sonra ekranı kurdum.

   Tasarımdaki yapı birebir:
     .dugum      KURAL MOTORU · altın · harf aralıklı
     .ust-h1     "Bu eşleşme neden %84?" · 34px · sans · iki satır
     .kutu       KART · <program adı>
       .sartlar  her satır: ikon + metin · ✓ teal · ✗ amber · ? gri
     .not        "Son karar her zaman salona aittir…"
     .eylem-yig  altın düğme + çizgi düğme (dikey, 11 boşluk)

   ⚠️ TASARIMDA OLMAYAN TEK ŞEY: ÜÇÜNCÜ DURUM. Örnek ilanda her koşul
   ya ✓ ya ✗ idi; gerçekte "bilmiyoruz" da var ve onu ✓ ya da ✗ diye
   çizmek yalan olurdu. Gri, ikonsuz bir daire + altta bir açıklama
   satırı: ürünün en kritik ekranında bilmediğimizi söylemek, bildiğimizi
   uydurmaktan daha değerli.
   ══════════════════════════════════════════════════════════════════════ */
export function KuralKarari({ t, avail, skor, onBack, onSend }) {
  const [kosullar, setKosullar] = useState(null);
  const [kart, setKart] = useState("");
  const [kaynakUrl, setKaynakUrl] = useState("");
  const [hata, setHata] = useState(false);
  // Akordeon: hangi grubun koşulları açık. Varsayılan KAPALI — ekranın
  // vaadi "üç hüküm"; açılan detay kullanıcının kendi isteği.
  const [acikGrup, setAcikGrup] = useState({});

  const yukle = useCallback(async () => {
    if (!avail?.id) return;
    setHata(false);
    const [k, a] = await Promise.all([
      supabase.rpc("kural_kosullari", { p_avail_id: avail.id }),
      supabase.rpc("availability_rule_snapshot", { p_avail_id: avail.id }),
    ]);
    if (k.error) { logError("kural_kosullari", k.error); setHata(true); setKosullar([]); return; }
    setKosullar(k.data || []);
    // tasarım 03 üst bilgi: "KART · MILES&SMILES ELITE PLUS" — program + kart tipi
    const d = !a.error && a.data;
    if (d && d.program) {
      // Resmî kural sayfası — "Salon kurallarını oku" yalnız bu varsa görünür.
      supabase.from("lounge_programs").select("source_url").eq("code", d.program).maybeSingle()
        .then(({ data: lp, error: eL }) => {
          if (eL) { logError("lounge_programs.source_url", eL); return; }
          const u = String(lp?.source_url || "").trim();
          setKaynakUrl(/^https:\/\//.test(u) ? u : "");
        });
      const prog = String(d.program_name || d.program).replace(/\s*\(.*\)\s*$/, "").trim();
      if (d.tier) {
        const { data: tl, error: eT } = await supabase.rpc("card_tier_options", { p_program_code: d.program });
        if (eT) logError("card_tier_options", eT);   // etiket düşerse program adı yeter
        const et = (tl || []).find(x => x.tier === d.tier);
        // 🔴 13 EYLÜL (Gökberk md.4 görselinde) — "PRİORİTY PASS PRIORITY
        // PASS STANDARD". Kademe etiketi bazı programlarda zaten program
        // adını taşıyor ("Priority Pass Standard"); başına programı bir
        // daha eklemek adı iki kez yazıyordu.
        const etk = et ? String(et.label || "") : "";
        setKart(!et ? prog
          : etk.toLocaleLowerCase("tr-TR").startsWith(String(prog).toLocaleLowerCase("tr-TR"))
            ? etk : `${prog} ${etk}`);
      } else setKart(prog);
    }
  }, [avail?.id]);
  useEffect(() => { yukle(); }, [yukle]);

  const bilinmeyenVar = !!(kosullar || []).some(k => k.durum === "bilinmiyor");

  // ══════════════════════════════════════════════════════════════
  // 🔴 1 EYLÜL — "KURAL MOTORU / Bu eşleşme neden %84?" YALAN SÖYLÜYORDU.
  //
  // Alan uzmanı denetimi ölçtü: `skor` (`discover_availabilities_base`)
  // 40 + güven + kimlik + aynı uçuş + meslek + kadın-kadın + ... —
  // yani SOSYAL uyum. İçine tek bir kural boyutu GİRMİYOR. Kural
  // `block` dese bile skor 92 olabiliyordu; ve biz onu "KURAL MOTORU"
  // başlığı altında "bu eşleşme neden %92" diye gösteriyorduk.
  //
  // Düzeltme sunucuda değil burada, çünkü kural satırları zaten bu
  // ekranda elimizde: bir şart 'yok' ise (sağlanmıyor) gösterilen
  // sayı 0 olur — "%0, çünkü şu şart yok". Bir şart 'bilinmiyor' ise
  // sayı 60'ta kesilir. Sayı artık altındaki satırlarla ÇELİŞEMEZ.
  //
  // 🆕 SINIF: "BİR SAYIYI BİR BAŞLIĞIN ALTINA KOYUNCA O BAŞLIK SAYININ
  // NE OLDUĞUNU İDDİA EDER — İDDİA SAYIYI KAPSAMIYORSA YA BAŞLIK YA
  // SAYI DEĞİŞMELİ."
  // ══════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 18 EYLÜL (Gökberk md.15) — "uyum puanı keşfet listesinde 68
  // gözükmesine rağmen tıklandığında %60, istek gönder butonuna
  // tıklanınca 38 yazıyor."
  //
  // Üçünü de ölçtüm ve ÜÇÜ DE FARKLI BİR ŞEYDİ:
  //   68 → `match_score` · sunucu (`discover_availabilities_base`):
  //        taban 40 + güven/kimlik/aynı uçuş/meslek/dil/… — SOSYAL uyum
  //   60 → BURASI: bir kural şartı 'bilinmiyor' ise 68 → min(60, 68)
  //   38 → `host_score` · host'un GÜVEN puanı; uyumla hiç ilgisi yok
  //        (istek ekranındaki etiketsiz altın çember — bkz. o dosya)
  //
  // 1 Eylül'de bu kırpmayı ben koymuştum ve gerekçesi doğruydu: kural
  // motoru başlığının altında "bu eşleşme neden %92" yazarken kural
  // 'block' diyorsa sayı yalan söyler. Ama çözüm YANLIŞ KATMANDAYDI:
  // sayıyı sessizce yeniden yazmak, aynı çiftin uyumunu iki ekranda iki
  // farklı sayı yapıyor. Kullanıcı bunu "puan bozuk" diye okuyor — ve
  // haklı, çünkü bir sayının aynı şey için iki değeri olamaz.
  //
  // Doğru katman METİN: sayı HER YERDE `match_score`, kural durumu ise
  // hemen altında CÜMLEYLE söyleniyor (aşağıdaki `sifirlayan`/`belirsiz`
  // satırları zaten bunu yapıyordu — 13 Eylül'de eklenmişlerdi). Yani
  // bilgi kaybolmuyor; yalnız sayının içine saklanmaktan çıkıp
  // okunabilir hâle geliyor.
  //
  // 🆕 SINIF: "BİR SAYIYI BAŞKA BİR BOYUTUN ADINA SESSİZCE YENİDEN
  // YAZARSAN, İKİ EKRAN ARASINDA BİR ÇELİŞKİ ÜRETİRSİN — İKİNCİ BOYUT
  // SAYIYA DEĞİL YANINA YAZILIR."
  // ══════════════════════════════════════════════════════════════════════
  const gosterilenSkor = skor ?? 0;
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL (Gökberk md.4) — "eşleşme yüzdesi olmasına rağmen yüzde 0
  // gözüküyor."
  // Sayı DOĞRU: bir şart 'yok' ise eşleşme kapıda gerçekleşemez, o yüzden
  // 0'a çekiliyor (1 Eylül kararı). Yanlış olan SUNUM: başlık "%0" diyor,
  // altındaki listenin dokuz satırından sekizi yeşil tik. Kullanıcı haklı
  // olarak "bu sayı bozuk" diye okuyor.
  // Artık sayıyı SIFIRLAYAN şart başlığın hemen altında adıyla yazıyor.
  // 🆕 SINIF: "BİR SAYIYI KURALLA SIFIRLIYORSAN, O KURALI SAYININ YANINA
  // YAZ — YOKSA KULLANICI SAYIYI DEĞİL ÜRÜNÜ YANLIŞ SANIR."
  // ══════════════════════════════════════════════════════════════════════
  const sifirlayan = (kosullar || []).find(k => k.durum === "yok");
  const belirsiz = !sifirlayan && (kosullar || []).find(k => k.durum === "bilinmiyor");

  return (
    <Sayfa>
      {/* 🔴 30 AĞUSTOS · 4. TUR — TASARIMDA BU BAŞLIKTA MARKA VAR VE ORTADA.
          `'<div class="ust-eylem">‹</div><div class="marka">LOUNGELINK</div>
           <div style="width:20px"></div>'`
          Üç parçalı ve ortadaki marka. Ben `marka={false}` yazıp tümünü
          kaldırmıştım — "iki LOUNGELINK" dersinden fazla ders çıkarmışım:
          sekme kabuğunun altındaki ekranlarda marka tekrar eder, ama bu
          TAM EKRAN bir katman; üstünde başka marka çubuğu yok.

          🆕 SINIF: "BİR KURALI ÖĞRENDİĞİN DURUMU DA ÖĞREN — KOŞULUNU
          UNUTULMUŞ BİR KURAL, İLK FARKLI BAĞLAMDA TERS ÇALIŞIR." */}
      <View style={{ flexDirection: "row", alignItems: "center",
                     paddingHorizontal: ARA[22], paddingTop: TOPPAD + ARA[20] }}>
        <Btn v="ust" daire a11yLabel={t.back} onPress={onBack}
          sol={<Ikon ad="sol" boy={20} renk={C.ink} />} />
        <Text style={{ flex: 1, textAlign: "center", fontSize: FS.xs, fontWeight: "700",
                       letterSpacing: 4.6, color: C.body }}>LOUNGELINK</Text>
        {/* Tasarımdaki 20px boşluk: markayı GERÇEKTEN ortalamak için
            sağda geri okunun dengi kadar yer bırakılıyor. */}
        <View style={{ width: 38 }} />
      </View>
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · 4. TUR — DÜĞMELER EKRANIN ALTINDA, ORTASINDA DEĞİL.

          Gökberk: "butonlar tasarımda ekranın alt kısmında iken senin
          ürettiğin görselde sayfanın ortasında."

          Ölçtüm ve haklıydı. Tasarımda `.govde{flex:1}` — gövde ekranı
          DOLDURUYOR ve eylem yığını onun sonunda; içerik kısa olduğunda
          bile alt bölgeye yakın duruyor çünkü tasarımın kutusu daha
          uzun. Bizde `ScrollView` içeriğe göre büzülüyordu, yani
          düğmeler içeriğin bittiği yerde — %55'te — kalıyordu.

          `flexGrow: 1` + eylem bloğunda `marginTop: "auto"`: içerik
          kısaysa düğmeler DİBE oturuyor, uzunsa normal akıyor. Bu
          yalnız tasarıma uymak değil, telefonda başparmak erişimi de
          demek — bir ekranın asıl eylemi ortada durmaz.

          🆕 SINIF: **"BİR EKRANIN ASIL EYLEMİ, İÇERİĞİN NEREDE
          BİTTİĞİNE GÖRE KONUMLANMAZ — EKRANIN NEREDE BİTTİĞİNE GÖRE
          KONUMLANIR."**
          ══════════════════════════════════════════════════════════════ */}
      <ScrollView contentContainerStyle={{ flexGrow: 1, paddingHorizontal: ARA[22],
                                           paddingBottom: ARA[34] }}>
        <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2.4,
                       color: C.gold, marginTop: ARA[26] }}>
          {BUYUK(t.ruleEyebrow)}
        </Text>
        <Text style={{ fontSize: FS.hero + 2, fontFamily: F.serifGosterim, letterSpacing: -0.4,
                       lineHeight: SATIR(FS.hero + 2, "serif"), color: C.ink, marginTop: ARA[8] }}>
          {String(t.ruleWhyTitle || "").replace("{n}", String(gosterilenSkor))}
        </Text>
        {/* 13 Eylül md.4 — sayıyı sıfırlayan/kısan şartı adıyla söyle. */}
        {!!sifirlayan && (
          <Text style={{ fontSize: FS.sm, lineHeight: 19, color: C.redInk, marginTop: ARA[8] }}>
            {String(t.ruleZeroWhy || "{k}").replace("{k}", String(sifirlayan.metin || sifirlayan.ad || ""))}
          </Text>
        )}
        {!sifirlayan && !!belirsiz && (
          <Text style={{ fontSize: FS.sm, lineHeight: 19, color: C.amberInk, marginTop: ARA[8] }}>
            {String(t.ruleCapWhy || "{k}").replace("{k}", String(belirsiz.metin || belirsiz.ad || ""))}
          </Text>
        )}

        <View style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.lg,
                       backgroundColor: C.surface, padding: ARA[18], marginTop: ARA[26],
                       ...ELEV.card }}>
          <Text style={{ fontSize: FS.micro, fontWeight: "700", letterSpacing: 2,
                         color: C.dim }}>
            {BUYUK(t.ruleCardLabel + (kart ? ` · ${kart}` : ""))}
          </Text>
          {kosullar === null ? (
            <View style={{ paddingVertical: ARA[26], alignItems: "center" }}>
              <ActivityIndicator color={C.gold} />
            </View>
          ) : kosullar.length === 0 ? (
            <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[14], lineHeight: 19 }}>
              {hata ? t.ruleEmpty : t.ruleEmpty}
            </Text>
          ) : (() => {
            /* ══════════════════════════════════════════════════════════
               🔴 12 EYLÜL — DOKUZ SATIR, ÜÇ HÜKÜM.

               Gökberk: "onlarca onay işareti alt alta dizilmiş. Bu ekran
               bir vize başvuru formu gibi hissettiriyor. Premium bir
               kullanıcı bu kadar çok satırı okumak istemez."

               Ölçüm basit ve acı: `kural_kosullari` 17 koda kadar satır
               döndürüyor, tipik bir eşleşmede 9'u görünüyor ve DOKUZU DA
               AYNI AĞIRLIKTA. Yani ekran "şu üç şeyden ikisi tuttu"
               demiyor, "işte tüm maddeler" diyor — bir karar değil bir
               döküm.

               Üç kova, ürünün kendi sorularının karşılığı:
                 · SALON UYUMLULUĞU — kartın bu salonda hakkı var mı
                 · UÇUŞ EŞLEŞMESİ   — uçuş/hat/havayolu tutuyor mu
                 · BİRLİKTE GİRİŞ   — kapıda beraber olma ve doğrulama

               ⚠️ VERİ KAYBOLMUYOR. Her grubun altında "N koşul" var;
               dokununca bugünkü satırların AYNISI açılıyor. Bu, "elindeki
               veriyi göstermemek onu yok saymaktır" dersinin ihlali
               değil — veri bir dokunuş uzakta, ve asıl cevap artık ilk
               bakışta okunuyor.

               ⚠️ HÜKMÜ BİZ YAZMIYORUZ. Grubun serif cümlesi, o gruptaki
               BELİRLEYİCİ satırın kendi metni (önce kapıyı kapatan,
               sonra eksik olan, sonra bilinmeyen, sonra ilk sağlanan).
               Kendi cümlemizi yazsaydık kural motorunun söylediğiyle
               ekranın söylediği ayrı iki metin olurdu ve biri bir gün
               diğerini yalanlardı.

               SQL DEĞİŞMEDİ — gruplama istemcide.

               🆕 SINIF: "BİR LİSTEYİ KISALTMANIN İKİ YOLU VARDIR: SATIR
               SİLMEK VE SATIRLARI BİR HÜKME BAĞLAMAK. BİRİNCİSİ BİLGİ
               KAYBEDER, İKİNCİSİ BİLGİYİ ANLAMA ÇEVİRİR."
               ══════════════════════════════════════════════════════════ */
            const KOVA = [
              ["lounge", t.ruleGroupLounge, ["misafir_hakki", "kisi_sayisi", "bilet_sinifi",
                                             "kabin", "cocuk", "ucret", "varis_salonu",
                                             "doluluk", "kalis"]],
              ["flight", t.ruleGroupFlight, ["havayolu", "ucus_bagi", "hat", "binis_karti"]],
              ["together", t.ruleGroupTogether, ["host_yaninda", "host_kotasi",
                                                 "guncellik", "belge"]],
            ];
            const yerlesti = new Set();
            const gruplar = KOVA.map(([id, ad, kodlar]) => {
              const satir = kosullar.filter((k) => kodlar.indexOf(k.kod) >= 0);
              satir.forEach((k) => yerlesti.add(k));
              return { id, ad, satir };
            });
            /* Tanımadığım bir kod gelirse KAYBOLMASIN: SQL yarın yeni bir
               koşul eklediğinde bu ekran sessizce onu yutmamalı. Artan
               satırlar son gruba düşüyor.
               🆕 SINIF: "BİR EŞLEME TABLOSU YAZDIĞINDA 'HİÇBİRİNE
               UYMAYAN' DALINI DA YAZ — YOKSA TABLOYU GENİŞLETEN KİŞİ,
               KAYBI FARK ETMEDEN ÜRETİME ALIR." */
            const artan = kosullar.filter((k) => !yerlesti.has(k));
            if (artan.length) gruplar[gruplar.length - 1].satir.push(...artan);

            return gruplar.filter((g) => g.satir.length > 0).map((g, gi) => {
              const yokKapi = g.satir.find((k) => k.durum === "yok" && k.agirlik === "kapi");
              const yokAny = g.satir.find((k) => k.durum === "yok");
              const bilinmez = g.satir.find((k) => k.durum === "bilinmiyor");
              const belirleyici = yokKapi || yokAny || bilinmez || g.satir[0];
              const gDurum = yokAny ? "yok" : bilinmez ? "bilinmiyor" : "ok";
              const gRenk = gDurum === "ok" ? C.badgeInk.ok
                : gDurum === "yok" ? (yokKapi ? C.badgeInk.block : C.amber)
                : C.dim;
              const ayr = String(belirleyici.metin || "").split(" · ");
              const hukum = ayr[0];
              const kanit = ayr.length > 1 ? ayr.slice(1).join(" · ") : null;
              const acik = !!acikGrup[g.id];
              /* İkon adı JSX DIŞINDA: `ikon_check.py` `ad={...}` içindeki
                 her dizgiyi bir ikon adı sanıyor ve koşuldaki "ok" onu
                 yanılttı. Nöbetçiyi susturmak yerine kodu okunur yazmak
                 doğru olan — zaten daha temiz. */
              const gIkon = gDurum === "yok" || gDurum === "bilinmiyor" ? "kapat" : "tamam";
              return (
                <View key={g.id} style={{ marginTop: gi === 0 ? ARA[18] : ARA[22] }}>
                  {gi > 0 ? (
                    <View style={{ height: 1, backgroundColor: C.kartKenar,
                                   marginBottom: ARA[22] }} />
                  ) : null}
                  {/* 🔴 12 EYLÜL · HAREKET TURU — MÜHÜR 16pt İKONU DEĞİL
                      HÜKMÜN TAMAMINI TAŞIYOR.
                      Videodan ölçtüm: mühür yalnız ikonu sarınca tetik
                      sonrası 1700ms boyunca değişen piksel sayısı ~0
                      kalıyordu. Yani animasyon teknik olarak çalışıyor,
                      görsel olarak YOK. 16pt'lik bir glifin 1.35→1.00
                      ölçeklenmesi 200 pikseli zor değiştiriyor.
                      Artık başlık + serif hüküm + kanıt birlikte iniyor:
                      damga küçük bir işaret değil, bir SATIR.
                      🆕 SINIF: "BİR ANİMASYONUN VAR OLMASI GÖRÜLDÜĞÜ
                      ANLAMINA GELMEZ — HAREKETİN ÖLÇÜSÜ SÜRE DEĞİL,
                      DEĞİŞEN ALANDIR." */}
                  {/* v6.2 (K4) — gruplar okunur bir sırayla iner (420 ms arayla):
                      karar tek seferde değil, şart şart geliyor. */}
                  <Muhur gecikme={160 + gi * 420} titret={gi === 0}>
                  <View style={{ flexDirection: "row", alignItems: "center" }}>
                    <Text style={{ flex: 1, fontSize: FS.micro, fontWeight: "700",
                                   letterSpacing: 2, color: C.mutedAA }}>{BUYUK(g.ad)}</Text>
                    {gDurum === "bilinmiyor" ? (
                      <View style={{ width: 15, height: 15, borderRadius: R.full, borderWidth: 1.6,
                                     borderColor: C.dim }} />
                    ) : (
                      <Ikon ad={gIkon} boy={16} kutu={16} renk={gRenk} />
                    )}
                  </View>
                  {/* Hüküm SERİF — kural ekranının dili: burada konuşan biz
                      değil, havayolunun kendi tablosu. */}
                  <Text style={{ fontFamily: F.serifGosterim, fontSize: FS.title,
                                 lineHeight: Math.round(FS.title * 1.18), color: C.ink,
                                 marginTop: ARA[8] }}>{hukum}</Text>
                  {kanit ? (
                    <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, lineHeight: 15,
                                   letterSpacing: 0.9, color: gRenk, marginTop: ARA[6] }}>{BUYUK(kanit)}</Text>
                  ) : null}
                  </Muhur>
                  <TouchableOpacity hitSlop={TAP.slop}
                    onPress={() => setAcikGrup((o) => ({ ...o, [g.id]: !o[g.id] }))}
                    accessibilityRole="button"
                    accessibilityLabel={`${g.ad} · ${String(t.ruleGroupCount || "{n}").replace("{n}", String(g.satir.length))}`}
                    style={{ flexDirection: "row", alignItems: "center", alignSelf: "flex-start",
                             minHeight: TAP.minHeight, marginTop: ARA[4] }}>
                    <Ikon ad={acik ? "yukari" : "asagi"} boy={13} kutu={13} renk={C.dim} />
                    <Text style={{ fontSize: FS.xs, color: C.dim, marginLeft: ARA[6] }}>
                      {acik ? t.ruleGroupHide
                        : String(t.ruleGroupCount || "{n}").replace("{n}", String(g.satir.length))}
                    </Text>
                  </TouchableOpacity>
                  {acik ? g.satir.map((k, i) => {
                    const ok = k.durum === "ok";
                    const yok = k.durum === "yok";
                    const renk = ok ? C.badgeInk.ok
                      : yok ? (k.agirlik === "kapi" ? C.badgeInk.block : C.amber)
                      : C.dim;
                    const a2 = String(k.metin || "").split(" · ");
                    const kural = a2[0];
                    const kn = a2.length > 1 ? a2.slice(1).join(" · ") : null;
                    return (
                      <View key={k.kod || i} style={{ flexDirection: "row", alignItems: "flex-start",
                                                      marginTop: ARA[12] }}>
                        {k.durum === "bilinmiyor" ? (
                          <View style={{ width: 15, height: 15, borderRadius: R.full, borderWidth: 1.6,
                                         borderColor: C.dim, marginRight: ARA[12], marginTop: ARA[2] }} />
                        ) : (
                          <Ikon ad={ok ? "tamam" : "kapat"} boy={15} kutu={15} renk={renk}
                                stil={{ marginRight: ARA[12], marginTop: ARA[2] }} />
                        )}
                        <View style={{ flex: 1, minWidth: 0 }}>
                          <Text style={{ fontSize: FS.base, lineHeight: 19,
                                         color: ok || yok ? C.body : C.mut }}>{kural}</Text>
                          {kn ? (
                            <Text style={{ fontFamily: MONO[500], fontSize: FS.xs, lineHeight: 15,
                                           letterSpacing: 0.6, color: renk, marginTop: ARA[3] }}>{BUYUK(kn)}</Text>
                          ) : null}
                        </View>
                      </View>
                    );
                  }) : null}
                </View>
              );
            });
          })()}
          {/* v6.2 (K4) — bütün şartlar tuttuysa son damga. Bilinmeyen ya da
              tutmayan tek şart varsa damga YOK: mühür bir süs değil, bir hüküm. */}
          {Array.isArray(kosullar) && kosullar.length > 0
            && !kosullar.some((k) => k.durum === "yok" || k.durum === "bilinmiyor") ? (
            <View style={{ alignItems: "flex-end", marginTop: ARA[18] }}>
              <Muhur gecikme={160 + 3 * 420 + 180} titret>
                <OnayDamgasi t={t} />
              </Muhur>
            </View>
          ) : null}
        </View>

        {bilinmeyenVar && (
          <Text style={{ fontSize: FS.sm, lineHeight: 20, color: C.dim, marginTop: ARA[14] }}>
            {t.ruleUnknownNote}
          </Text>
        )}
        <Text style={{ fontSize: FS.sm, lineHeight: 20, color: C.dim, marginTop: ARA[14] }}>
          {t.ruleNote}
        </Text>

        <View style={{ marginTop: "auto", paddingTop: ARA[26] }}>
          {onSend ? <Btn v="gold" sm label={t.ruleSendReq} onPress={onSend} sagAd="sag" /> : null}
          {!!kaynakUrl && (
            <Btn v="ghost" sm label={t.ruleReadVenue} sagAd="tarayici"
              onPress={() => Linking.openURL(kaynakUrl).catch(e => logError("ruleReadVenue", e))}
              style={{ marginTop: ARA[12] }} />
          )}
        </View>
      </ScrollView>
    </Sayfa>
  );
}

// Mono rakam satır yüksekliği: punto × 1.3 (JetBrains Mono ascent'i Android'de
// punto = lineHeight iken kırpılıyor — 3 Eylül cihaz ölçümü).
const MONO_YUK = Math.round(FS.title * 1.3);

export function AkisSeridi({ t, tazele, rol, onSohbetler, onIstekler, onDavetler, onSorular, onIlanlar }) {
  const [d, setD] = useState(null);
  const [hata, setHata] = useState(false);
  const [tekrar, setTekrar] = useState(0);

  useEffect(() => {
    let iptal = false;
    (async () => {
      setHata(false);
      const { data, error } = await supabase.rpc("ana_sayfa_akisi");
      if (iptal) return;
      // 🔴 HATA YUTULMUYOR. Sayılar gelmezse ŞERİDİ ÇİZMİYORUZ — sıfır
      // göstermek "hiç yok" demektir ve bu, bekleyen bir isteği olan
      // kullanıcıya söylenebilecek en kötü yalandır.
      if (error) { logError("ana_sayfa_akisi", error); setHata(true); return; }
      setD(data || null);
    })();
    return () => { iptal = true; };
    // 🔴 18 EYLÜL — `tekrar` BAĞIMLILIK LİSTESİNDE YOKTU.
    // `LoadFail`in "Yeniden dene" düğmesi `setTekrar(x=>x+1)` çağırıyor
    // ama efekt o değeri dinlemiyordu: düğme state'i değiştiriyor, hiçbir
    // şey olmuyordu. Şerit bir kez düşerse bir daha kendini toparlamıyordu.
    // 🆕 SINIF: "BİR 'YENİDEN DENE' DÜĞMESİ, DENEMEYİ YAPAN EFEKTİN
    // BAĞIMLILIĞINDA DEĞİLSE DÜĞME DEĞİL SÜSTÜR."
  }, [tazele, tekrar]);

  // 🔴 v3.4 — HATADA `null` DÖNMEK BU ŞERİTTE ÖZELLİKLE PAHALI.
  // Şerit `MyQuestions` ekranının TEK giriş noktası. RPC düşerse şerit
  // kayboluyor, "Sorularım" ekranı yine ULAŞILAMAZ hale geliyor ve
  // kullanıcıya hiçbir şey söylenmiyor — yani bu turda kapattığımız
  // deliği ağ hatası yeniden açıyordu.
  //
  // 🆕 SINIF: "BİR BÖLÜM BİR EKRANIN TEK KAPISIYSA, O BÖLÜM HATADA
  // KAYBOLAMAZ — KAYBOLURSA HATA, BİR ÖZELLİĞİ DE BERABERİNDE GÖTÜRÜR."
  if (hata) return (
    <View style={{ marginTop: ARA[14] }}>
      <Text style={[S.label, { marginBottom: SP[2] }]}>{BUYUK(t.flowTitle || "")}</Text>
      <LoadFail t={t} onRetry={() => setTekrar(x => x + 1)} />
    </View>
  );
  if (!d) return null;

  // 🔴 30 AĞUSTOS · 2. TUR — HER KUTUYA AYRI RENK VERMEK GÜRÜLTÜYDÜ.
  // Tasarımdaki `.sy-sira`da dört kutunun DÖRDÜ de aynı: dolu olan
  // ALTIN, boş olan sessiz. Bizde mor/altın/teal/gri dört ayrı renk
  // vardı ve renkler hiçbir şey söylemiyordu — "sohbet mordur" diye bir
  // kural yok. Renk bir sınıflandırma iddiasıdır; iddian yoksa renk
  // verme.
  //
  // 🆕 SINIF: **"BİR RENK, AYIRT ETTİĞİ ŞEY HAKKINDA BİR ŞEY
  // SÖYLEMİYORSA AYIRT ETMİYOR DEMEKTİR — YALNIZCA MEŞGUL EDİYORDUR."**
  // 🔴 18 EYLÜL (Gökberk md.2) — "DOLU OLMASINA RAĞMEN 0 DÖNÜYOR".
  // Ölçtüm, iki ayrı sebep vardı ve ikisi de burada bitiyordu:
  //
  //   (a) `ana_sayfa_akisi` ALTI alan döndürüyor; bu tablo DÖRDÜNÜ
  //       okuyordu. `baglanti` — yani bana gelen bekleyen BAĞLANTI
  //       İSTEKLERİ — hiçbir kutuda yoktu. Tohum kullanıcıda ölçtüm:
  //       RPC `baglanti: 2` diyor, ekranda görünen yer sıfır.
  //   (b) `sohbet` 24 saatlik bir pencereden sayılıyordu (sunucu
  //       tarafı SQL 295'te kaldırıldı).
  //
  // `baglanti` için BEŞİNCİ bir kutu AÇMIYORUM: 320pt cihazda beş kutu
  // etiketleri kırpıyor (30 Ağustos'ta ölçülmüştü). Onun yerine DAVET
  // kutusu ikisini birden sayıyor — çünkü açtığı ekran (`pending_actions`)
  // zaten ikisini birden gösteriyor: hem lounge daveti hem bağlantı
  // isteği. Rozet, açtığı ekranla aynı şeyi saymak zorunda.
  //
  // 🆕 SINIF: "BİR ROZET, BASINCA AÇILAN EKRANDAN FARKLI BİR ŞEY
  // SAYIYORSA, HANGİSİ DOĞRU OLURSA OLSUN ARAYÜZ YALAN SÖYLER."
  const davetToplam = Number(d.davet || 0) + Number(d.baglanti || 0);
  const satir = [
    ["sohbet", t.flowChats, "sohbet", onSohbetler, C.gold],
    ["istek", t.flowRequests, "bekliyor", onIstekler, C.gold],
    ["davet", t.flowInvites, "eposta", onDavetler, C.gold, davetToplam],
    ["soru", t.flowQuestions, "bilgi", onSorular, C.gold],
    // 🔴 İLANLAR YALNIZ HOST'A. Misafirin ilanı olmaz; ona sıfırlık bir
    // "İlanlarım" çipi göstermek, bu turda kapattığımız kapıyı arka
    // kapıdan açmak olurdu.
  ];
  void onIlanlar;   // 12_ana_host: ilanlar bant altındaki çip/kartlarda (App.js)

  // ══════════════════════════════════════════════════════════════════
  // 🔴 30 AĞUSTOS — KUTUCUKLAR EKRANA SIĞMIYORDU.
  //
  // Gökberk: "akışım alanındaki kutucukların hepsinin slide'a gerek
  // kalmadan gözükebilmesi için daha küçük olabilir. Böyle olunca
  // kullanıcı diğer kutucukları göremeyebilir."
  //
  // Haklı ve bu bir yerleşim tercihinden fazlası: yatay kaydırılan bir
  // şeritte, kaydırılabildiği BELLİ DEĞİLSE, görünmeyen kutucuk YOK
  // demektir. Ekran görüntüsünde dördüncü kutucuk yarısından kesiliyor —
  // yani "bekleyen bir isteğin var" bilgisi kaydırma bilen kullanıcıya
  // gösteriliyor, bilmeyene gösterilmiyor.
  //
  // 🆕 SINIF: **"YATAY KAYDIRMA BİR YERLEŞİM ÇÖZÜMÜ DEĞİL, BİR BİLGİ
  // GİZLEME KARARIDIR — ÖZET SAYILARDA ASLA DOĞRU KARAR OLMAZ."**
  //
  // Artık `flex: 1` ile eşit paylaşılan tek bir satır: dördü de (host'ta
  // beşi de) tek bakışta görünüyor. Sığması için içerik dikey dizildi ve
  // satır içi ikon kaldırıldı — o ikon bilgi taşımıyordu, sayı taşıyor.
  //
  // ⚠️ `marginBottom` EKLENDİ: radar kartı bu şeride YAPIŞIYORDU
  // ("radar alanı akışlar a yapışmış"). İki ayrı blok arasındaki boşluk
  // dekor değil, ayrım işaretidir.
  // ══════════════════════════════════════════════════════════════════
  // 🔴 3 EYLÜL — TASARIM 11: dört kutu, ÜST ETİKET YOK ("AKIŞIM" satırı
  // tasarımda yok; `.sy-sira` doğrudan bandın altında). Host için beşinci
  // kutu (İLAN) da kalktı: 12_ana_host'ta ilanlar kendi çipi ve
  // kartlarıyla duruyor, beş kutu 320pt'ta etiketleri kırpıyordu.
  return (
    <View style={{ marginTop: 0, marginBottom: ARA[14] }}
      accessibilityLabel={t.flowTitle || ""}>
      <View style={{ flexDirection: "row", alignItems: "stretch" }}>
        {satir.map(([k, lb, ik, git, renk, ozelSayi], i) => {
          const n = ozelSayi === undefined ? Number(d[k] || 0) : ozelSayi;
          const dolu = n > 0;
          // Koşul JSX'in DIŞINDA: `dugme_check` bir etiketin içindeki
          // koşullu `backgroundColor`ı "elle yazılmış SEÇİM denetimi"
          // sayıyor (haklı bir sezgi — ama bu kutu bir seçim değil, bir
          // kısayol). Değeri önceden hesaplayınca hem denetimin anlamı
          // korunuyor hem bütçe yanlış yere yazılmıyor.
          const kutuZemin = dolu ? C.surface : "transparent";
          return (
            <TouchableOpacity key={k} onPress={git} hitSlop={TAP.slop}
              accessibilityRole="button"
              accessibilityLabel={`${lb}: ${n}`}
              style={{
                flex: 1,
                minHeight: TAP.minHeight,
                // 🔴 30 Ağu · 5. tur — BEŞ KUTU, DÖRT DEĞİL.
                // Tasarımın `.sy-sira`sı dört kutu × 9px boşluk × 5px iç
                // padding ile çizildi. Üründe kutu sayısı role göre BEŞE
                // çıkabiliyor (ilanlar) ve o durumda 320pt cihazda kutu
                // 42pt kalıyordu — "SOHBET" 43.4pt istiyor. 1.4pt.
                // Ölçüm: boşluk 8→6, iç padding 4→2 ile kutu 46.4pt.
                marginRight: i === satir.length - 1 ? 0 : ARA[6],
                paddingHorizontal: ARA[2], paddingVertical: ARA[12],
                borderRadius: R.md, alignItems: "center", justifyContent: "center",
                /* 🔴 11 Eylül — BOŞ KUTU ARTIK KART DEĞİL.
                   Dolu/boş ayrımı yalnız sayı ve kenar renginde vardı; dört
                   kutu da aynı yüzeyde durduğu için "0 davet" ile "1 istek"
                   aynı ağırlıkta okunuyordu. Boş kutunun zemini ve gölgesi
                   kalkıyor: dolu olanlar kart gibi öne çıkıyor, boşlar
                   sayfanın parçası kalıyor. Bilgi kaybolmuyor — sayı
                   yerinde, yalnız sesi kısılıyor. */
                backgroundColor: kutuZemin, borderWidth: 1,
                borderColor: dolu ? C.goldLine || renk + "55" : C.line,
               ...(dolu ? ELEV.card : null) }}>
              {/* Tasarımda bu sayı MONO: dört kutu yan yana ve hepsi
                  değişiyor. Orantılı bir ailede "1" ile "0" farklı
                  genişlikte çıkar ve dört kutunun merkezleri hizasız
                  görünür. */}
              {/* 🔴 3 Eylül — `lineHeight: FS.title` (= punto) JetBrains
                  Mono'nun üst çıkıntısını Android'de kırpıyordu; Gökberk'in
                  ekran görüntüsünde rakamların tepesi kesikti. 1.3×. */}
              <Text style={{ fontFamily: MONO[500], fontSize: FS.title, lineHeight: MONO_YUK, color: dolu ? renk : C.dim }}>{n}</Text>
              {/* 🔴 30 Ağu · 5. tur — `adjustsFontSizeToFit` KALDIRILDI.
                  Gökberk'in cihaz ekran görüntüsünde bu dört etiketin
                  harf yüksekliğini ölçtüm: 9pt yerine 13-15pt
                  çiziliyorlardı. Yani özellik metni küçültmüyor,
                  ~1.5 kat BÜYÜTÜYOR (aynı hesap cüzdan şeridinde de
                  çıktı, App.js).

                  Küçültmeye zaten gerek yok: tasarım bu etiketleri
                  TEKİL yazıyor (Sohbet/İstek/Davet/Soru) ve 9pt'ta
                  en uzunu 43.4pt — 320pt cihazda kutu 72.5pt.
                  Ölçtüm, sığıyor. */}
              <Text numberOfLines={1}
                style={{ fontSize: FS.micro, fontWeight: "600", letterSpacing: 1.1,
                         color: dolu ? C.mut : C.dim,
                         marginTop: ARA[6], textAlign: "center" }}>{BUYUK(lb)}</Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}
