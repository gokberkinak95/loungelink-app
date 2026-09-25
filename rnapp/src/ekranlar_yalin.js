// ============================================================================
// ekranlar_yalin.js — KATMAN 1-3: yalniz alt katmanlara bagli ekranlar
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
import MomentScreen from "./MomentScreen";
import { AramaKutusu, Katlanir, eslesir } from "./Pickers";
import { badgeLabel, fmtLongDate, mapErr, shortName, BUYUK } from "./i18n";
import { bayrak } from "./runtime";
import { havalimanlariniGetir } from "./katalog";
import { logError, supabase } from "./supabase";
import { MONO } from "./typography";
import { ARA, C, ELEV, F, FS, R, SP, T, TAP, SATIR} from "./theme";
import { BosDurum, ConfirmModal, GecisKarti, Hdr, LoadFail, TOPPAD, Sayfa, Btn, Secim, Cip, useDaralanBant, Kaydirma } from "./ui";
import { useCallback, useEffect, useRef, useState } from "react";
import { AppState, ActivityIndicator, BackHandler, FlatList, Image, Modal, ScrollView, Text, TextInput, TouchableOpacity, View } from "react-native";
import { BinisKartiPanel } from "./BinisKarti";
import { kuyrugaAkit, kuyrugaBak, kuyrukDinle, kuyruguYenidenDene, mesajKuyruga, onbellegeYaz, onbellektenOku } from "./cevrimdisi";
import { ACCESS_SOURCES, AMENITY_ICONS, AMENITY_TR, AirportPicker, Load, PROF_KEYS, Pill, REPORT_TYPES, ReqStateBadge, S, Sayac, TR_DAYS, TR_MONTHS, VenuePrices, _DTP, abbrevName, dateOk, geriSayim, getProfileCompletion, intentLabel, isoOf, zamanKisa } from "./ortak";
import { Ikon, IkonMetin, BilgiRozeti } from "./ikon";
import { yerelGun } from "./zaman";

export const timeOk = s => /^\d{2}:\d{2}$/.test(s);

// 🔴 v2.79 — ARAMA EKLENDİ (AirportPicker ile aynı sebep).
// Bu bileşen Seyahatlerim ekranında havalimanı seçiminde kullanılıyor ve
// 222 kayıtlık listeyi filtresiz basıyordu. Modal içinde olduğu için
// `keyboardShouldPersistTaps="handled"` şart: yoksa klavye açıkken ilk
// dokunuş klavyeyi kapatmakla harcanıyor ve kullanıcı iki kez basıyor.
export function Picker({ label, value, options, onPick, t }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const gorunen = (options || []).filter(o => eslesir(q, o.label, o.sub, o.key));
  return (
    <>
      <Text style={S.label}>{label}</Text>
      <TouchableOpacity style={S.pickBtn} onPress={() => { setOpen(true); setQ(""); }}>
        <Text style={{ color: value ? C.ink : C.mut, fontSize: FS.lg }}>{value ? value.label : t.select}</Text>
      </TouchableOpacity>
      <Modal visible={open} transparent animationType="slide">
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.4)", justifyContent: "flex-end" }}>
          <View style={{ backgroundColor: C.paper, borderTopLeftRadius: 18, borderTopRightRadius: 18, maxHeight: "70%", padding: SP[4] }}>
            <AramaKutusu value={q} onChange={setQ} sonuc={gorunen.length} t={t}
              placeholder={t.searchPlaceholder || "Ara…"} />
            <FlatList data={gorunen} keyExtractor={i => i.key}
              keyboardShouldPersistTaps="handled"
              renderItem={({ item }) => (
                <TouchableOpacity hitSlop={TAP.slop} style={[S.card, { marginBottom: SP[2] }]} onPress={() => { onPick(item); setOpen(false); setQ(""); }}>
                  <Text style={{ fontSize: FS.lg, color: C.ink }}>{item.label}</Text>
                  {item.sub ? <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: ARA[2] }}>{item.sub}</Text> : null}
                </TouchableOpacity>
              )} />
            <TouchableOpacity hitSlop={TAP.slop} style={{ alignItems: "center", padding: SP[3] }} onPress={() => setOpen(false)}>
              <Text style={{ color: C.mut }}>{t.cancel}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </>
  );
}

// Saate gore selam — kucuk bir dokunus ama ekrani "yasayan" yapiyor.
// Cihaz saatinden okunur; sunucuya sormaya degmez.
export function RequestsPanel({ t, session, onOpenChat, onOpenProfile, lang, acikBasla, tamEkran, tazele }) {
  const uid = session?.user?.id;
  // 🔴 v2.65 — useState([]) "hiç isteğin yok" demekti; oysa henüz
  // okunmamıştı. null = yükleniyor. Ayrıca Promise.allSettled iki dalı da
  // reddedebilir ve o durumda ekran sessizce boşalıyordu — artık ikisi de
  // düşerse hata durumu gösteriliyor.
  const [inc, setInc] = useState(null);
  const [sent, setSent] = useState(null);
  const [loadErr, setLoadErr] = useState(false);
  const [names, setNames] = useState({});

  // `tazele` DIŞARIDAN gelen tazeleme anahtarı: bir isteği başka bir
  // ekranda (ana sayfadaki `ActionNeeded`) cevapladığında bu liste de
  // yeniden okunur. Bkz. md.1 ve md.6 — "already_responded" ve bayat
  // "Kabul et" düğmesi aynı bayat listeden çıkıyordu.
  const load = useCallback(async () => {
    // ============================================================
    // 046: GELEN istekler artik host_requests() ile geliyor.
    //
    // Onceden host, kabul/red kararini verirken SADECE misafirin
    // ADINI ve tanitim mesajini goruyordu. Guven puani yok, rozet
    // yok, kimlik dogrulanmis mi belli degil, kac oturum yapmis
    // belli degil. Sira da "kim once basvurdu"ydu.
    //
    // Yani tum trust-first mimarisi (escrow, dogrulama, guven puani)
    // guvenin kullanilacagi TEK ANDA gorunmuyordu. Bir yabanciyi
    // lounge'una alacak insan, bir isim ve iki cumleyle karar veriyordu.
    // ============================================================
    // 🔴 v2.48 — YERELDE ÖLÇÜLDÜ: Promise.all'da İKİNCİ sorgu (doğrudan
    // tablo) grant eksikliğiyle reject olunca BİRİNCİDEN (security definer
    // RPC) gelen GELEN İSTEKLER de düşüyordu — host "başvuruyu hiçbir
    // yerde göremiyorum" diyordu. İki kaynak artık bağımsız: biri
    // düşerse öteki yaşar. (Grant kökten 159'da düzeldi; bu katman
    // gelecekteki benzer sınıfa karşı dayanıklılık.)
    const [ra, rb] = await Promise.allSettled([
      supabase.rpc("host_requests"),
      // 🔴 v2.66 (Gökberk madde 13): düz tablo sorgusu yerine my_sent_requests.
      // Tablo yalnız id/status/host_id veriyordu; kart bu yüzden "bir isim
      // ve bir kelime"den ibaretti. RPC salon, tarih/saat, uçuş, slot
      // doluluğu, karar notu ve host rozetini birlikte döndürüyor —
      // misafirin kartı artık host'unki kadar konuşuyor.
      supabase.rpc("my_sent_requests"),
    ]);
    // İKİSİ BİRDEN düştüyse bu bir hata; biri düştüyse öteki yaşar (kasıtlı).
    const aFail = ra.status !== "fulfilled" || !!(ra.value && ra.value.error);
    const bFail = rb.status !== "fulfilled" || !!(rb.value && rb.value.error);
    if (aFail && bFail) { setLoadErr(true); return; }
    setLoadErr(false);
    const a = ra.status === "fulfilled" ? ra.value.data : [];
    const b = rb.status === "fulfilled" ? rb.value.data : [];
    // 🔴 v1.82 (Gokberk: "tamamlanan oturumlar ana sayfadan ne zaman kalkıyor?"):
    // Kural şu: tamamlanan/iptal olan istek 24 SAAT görünür (itiraz + puanlama
    // penceresi), sonra listeden düşer. Böylece liste sonsuza kadar birikmez
    // ama kullanıcı biten işini hemen kaybetmez. Puanlanmayı bekleyen oturum
    // ayrıca Oturum Geçmişi'nde "★ Puanla" ile durmaya devam eder.
    const DAY = 24 * 60 * 60 * 1000;
    const fresh = (r) => !["completed", "cancelled", "declined"].includes(r.status)
      || (Date.now() - new Date(r.responded_at || r.created_at || Date.now()).getTime()) < DAY;
    setInc((a || []).filter(fresh)); setSent((b || []).filter(fresh));
    // 🔴 v1.81 (Gokberk 2. madde): ana sayfadaki kartlar yalnız requests.status
    // gösteriyordu; oturum başlatıldı mı, karşı taraf tamamla dedi mi bilgisi
    // ancak sohbete girince görülüyordu. Artık ilgili oturumlar da çekilip
    // kartta CANLI durum gösteriliyor (bekliyor / devam ediyor / onayın
    // bekleniyor / tamamlandı).
    const reqIds = [...new Set([...(a || []).map(x => x.id), ...(b || []).map(x => x.id)])];
    if (reqIds.length) {
      const { data: ss, error: hata1 } = await supabase.from("sessions")
        .select("request_id, status, host_confirmed, guest_confirmed, host_started_at, guest_started_at")
        .in("request_id", reqIds);
        if (hata1) logError("ekranlar_yalin.js:144", hata1);
      const sm = {}; (ss || []).forEach(x => { sm[x.request_id] = x; });
      setSessMap(sm);
    } else setSessMap({});
    // GONDERDIGIM istekler icin host adlari (host_requests yalniz gelenleri kapsar).
    // v2.66: my_sent_requests host_name'i zaten veriyor; bu sorgu artık
    // YALNIZ adı gelmeyen satırlar için çalışır (yedek yol). Boş id ile
    // .in() çağırmak sorguyu bozardı — filtrelenerek geçiliyor.
    const ids = [...new Set((b || []).filter(r => !r.host_name && r.host_id).map(r => r.host_id))];
    if (ids.length) {
      const { data: ps, error: hata2 } = await supabase.from("profiles").select("user_id, name").in("user_id", ids);
      if (hata2) logError("ekranlar_yalin.js:157", hata2);
      const m = {}; (ps||[]).forEach(p => { m[p.user_id] = p.name; });
      setNames(m);
    }
  }, [uid]);

  // `tazele` deps'te: başka ekranda verilen cevap bu listeyi de tazeler.
  useEffect(() => { load(); const iv = setInterval(load, 15000); return () => clearInterval(iv); }, [load, tazele]);

  // 🔴 v1.75 (Gokberk: "Kabul Et hiçbir şey yapmıyor"): hata SESSİZCE
  // yutuluyordu. Sunucu 'fully_booked' (ilanın tüm slotları dolu),
  // 'not_pending' gibi gerçek sebepler döndürüyor ama ekranda hiçbir şey
  // olmuyordu — kullanıcı butonun bozuk olduğunu sanıyordu. Artık sebep
  // kartın altında Türkçe olarak yazılıyor.
  const [actErr, setActErr] = useState({});
  const [sessMap, setSessMap] = useState({});   // request_id -> oturum durumu (v1.81)
  async function act(id, action) {
    setActErr(e => ({ ...e, [id]: null }));
    const { error } = await supabase.rpc("respond_request", { p_request_id: id, p_action: action });
    if (error) {
      const key = "e_" + (error.message || "").split(" ")[0].replace(/[^a-z_]/g, "");
      setActErr(e => ({ ...e, [id]: t[key] || mapErr(t, error.message) }));
      return;
    }
    load();
  }

  const stMap = { pending: [t.st_pending, C.gold], accepted: [t.st_accepted, C.green], declined: [t.st_declined, C.red], cancelled: [t.st_cancelled, C.mut] };

  if (loadErr) return (
    <View style={{ marginTop: ARA[22] }}><LoadFail t={t} onRetry={load} /></View>
  );
  if (inc === null || sent === null) return (
    <View style={{ marginTop: ARA[22], height: 120 }}><Load /></View>
  );

  // 🔴 v2.87 — ANA SAYFADAKİ İSTEK/SOHBET BLOĞU KATLANIR (Gökberk madde 7).
  // "aynısı ana sayfadaki sohbet ve ilan blokları için de."
  // Bu panel ana sayfanın en uzun bloğuydu: gelen + gönderilen tüm istekler
  // tam boy kartlar hâlinde alt alta diziliyordu; üç istek varken ana sayfa
  // üç ekran boyuna çıkıyordu.
  // İKİ KURAL:
  //  · Kapalıyken bile başlıkta SAYILAR var (kaç gelen, kaç gönderilen) —
  //    bilgi kaybolmuyor, yalnız kartlar kapanıyor.
  //  · BEKLEYEN İSTEK VARSA panel AÇIK başlar. Host'un bir numaralı işi
  //    bekleyen istektir; onu katlamak, işi saklamak olurdu.
  // ══════════════════════════════════════════════════════════════════
  // 🔴 18 EYLÜL (Gökberk md.3) — "ana sayfadaki istek alanına tıklayınca
  // sayfanın içi boş siyah ekran dönüyor".
  //
  // Sebebi tam olarak bu satırdı. Panel ANA SAYFADA BİR BLOK olarak
  // tasarlandı ve boşken kendini siliyor — orada doğru: boş bir blok
  // sayfayı uzatır. Ama aynı bileşen 3 Eylül'de TAM EKRAN olarak da
  // kullanılmaya başlandı (`OVERLAY_VIEWS.istekler`). Tam ekranda
  // `return null` demek: başlık + `Sayfa`nın koyu zemini + HİÇBİR ŞEY.
  // Kullanıcı "İstek"e basıyor, siyah bir ekran açılıyor, geri dönüyor.
  //
  // Bir bileşenin boş hâli, ÇAĞRILDIĞI YERE göre değişmek zorunda:
  // blokken kaybolur, ekranken kendini açıklar.
  //
  // 🆕 SINIF: "BİR BLOĞUN 'BOŞSA KAYBOL' KURALI, O BLOK TAM EKRANA
  // TERFİ ETTİĞİNDE BİR BOŞ EKRANA DÖNÜŞÜR — BOŞ DURUM BİLEŞENİN
  // DEĞİL BAĞLAMIN İŞİDİR."
  // ══════════════════════════════════════════════════════════════════
  if (!inc.length && !sent.length) {
    if (!tamEkran) return null;
    return <BosDurum ikon="bekliyor" metin={t.flowRequestsEmpty} />;
  }
  const bekleyen = inc.filter(r => r.status === "pending").length;
  // 🔴 v2.95 (Gökberk madde 2) — "'X gönderdiğin' yerine 'Gönderdiğin X
  // istek' gibi daha okunabilir bir şey olsun. Host tarafı da güncellensin."
  // Haklı: "3 gönderdiğin" Türkçe bir cümle değil; sayı sıfatı ile ortaç
  // arasında bir ad eksik. İki taraf da aynı kalıba geçti:
  //   "Sana gelen 3 istek"  ·  "Gönderdiğin 3 istek"
  // 5 Eylül — ÖLÇÜLDÜ (SEED6 · host1): Akışım "1 İSTEK" derken panel "Sana
  // gelen 2 istek" diyordu (kabul edilmiş 24 saatlik kartı da sayıyordu).
  // Aynı sayı: bekleyen; kalan varsa "· 1 kabul edildi" ile ayrı söylenir.
  const kabul = inc.length - bekleyen;
  const ozetMetni = [
    bekleyen ? String(t.homeReqIncoming || "Sana gelen {n} istek").replace("{n}", String(bekleyen)) : null,
    kabul ? String(t.homeReqAccepted || "{n} kabul edildi").replace("{n}", String(kabul)) : null,
    sent.length ? String(t.homeReqSent || "Gönderdiğin {n} istek").replace("{n}", String(sent.length)) : null,
  ].filter(Boolean).join(" · ");

  return (
    <Katlanir baslik={t.homeReqPanelTitle} ozet={ozetMetni} acikBasla={acikBasla || bekleyen > 0}
      tint={bekleyen > 0 ? C.goldBg : undefined}
      cizgi={bekleyen > 0 ? C.goldLine : undefined}>
      {inc.length > 0 && <>
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.dim, letterSpacing: 1.5, marginBottom: ARA[6], marginTop: ARA[14] }}>{t.incomingByMatch}</Text>
        {/* v2.02 — KABUL SONRASI NE OLUYOR? Host kabul ettikten sonra kart
            bir süre sonra ana sayfadan düşüyor ve kullanıcı "kayboldu"
            sanıyordu. Kaybolmuyor, taşınıyor — ama bunu söylemiyorduk.
            Beklentiyi baştan kurmak, sonradan aramaktan ucuz. */}
        {inc.some(r => r.status === "accepted") && (
          <IkonMetin ad="bilgi" renk={C.mut} stilMetin={{ fontSize: FS.xs, color: C.mut, lineHeight: 16, marginBottom: ARA[10] }} metin={t.reqStay24} />
        )}
        {inc.map((r, idx) => {
          const pendCount = inc.filter(x => x.status === "pending").length;
          const isBest = (r.guest_fit || 0) >= 85 && r.status === "pending";
          // Renk JSX'ten ONCE hesaplaniyor — JSX icinde IIFE kullanmiyoruz.
          // Sebep: sandbox'ta @babel/parser yok, check.js sezgisel fallback'e
          // dusuyor ve JSX icindeki `return (` onu sasirtiyor. Ayrica bu hali
          // daha okunakli.
          const fit = r.guest_fit || 0;
          const fitC = fit >= 85 ? C.green : fit >= 65 ? C.gold : C.muted;
          const scoreC = r.guest_score >= 70 ? C.green : r.guest_score >= 50 ? C.gold : C.muted;
          // 🔴 v2.86 (Gökberk, ekran görüntüsüyle): "hangi ilana ait olduğu
          // anlaşılmıyor". AYNI misafir host'un İKİ AYRI ilanına başvurunca
          // iki kart BİREBİR aynı çıkıyordu (aynı isim, aynı puan, aynı
          // çipler) ve kullanıcı çoklanma sanıyordu. Çoklanma yoktu; kart
          // bağlamı söylemiyordu. host_requests() lounge_name / avail_date /
          // time_from / time_to alanlarını ZATEN döndürüyor — bu projenin
          // tekrar eden hata sınıfı: "veri geliyor ama kart okumuyor".
          // NOT: RPC havalimanı kodu döndürmüyor (25 kolonda airport_code
          // yok); salon + gün + saat ayırt etmeye yetiyor. Uçuş numarası da
          // bilerek burada değil: o MİSAFİRİN uçuşu, ilanın değil ve zaten
          // çip satırında yazıyor — buraya koymak mükerrer bilgi olurdu.
          const availLine = [
            r.avail_date ? fmtLongDate(r.avail_date, lang) : null,
            (r.time_from && r.time_to)
              ? `${String(r.time_from).slice(0, 5)}–${String(r.time_to).slice(0, 5)}` : null,
            r.lounge_name || null,
          ].filter(Boolean).join(" · ");
          return (
          <View key={r.id} style={[S.card, { padding: 0, overflow: "hidden" }, isBest && { borderColor: C.gold }]}>
            {/* #26: MVP sira seridi — en iyi eslesme altin, digerleri gri */}
            {r.status === "pending" && (isBest ? (
              <View style={{ backgroundColor: C.goldBtn, paddingVertical: SP[1], paddingHorizontal: SP[3], flexDirection: "row", justifyContent: "space-between" }}>
                <IkonMetin ad="kutlama" renk={C.onAccent} stilMetin={{ fontSize: FS.micro, color: C.onAccent, fontWeight: "600" }} metin={`${t.bestMatch} · %${fit}`} />
                <Text style={{ fontSize: FS.micro, color: C.onAccent, opacity: 0.85 }}>#{idx + 1} / {pendCount}</Text>
              </View>
            ) : pendCount > 1 ? (
              <View style={{ backgroundColor: C.bgAlt, paddingVertical: SP[1], paddingHorizontal: SP[3] }}>
                <Text style={{ fontSize: FS.micro, color: C.mutedAA }}>#{idx + 1} / {pendCount} · %{fit} {t.matchWord}</Text>
              </View>
            ) : null)}
            <View style={{ padding: SP[3] }}>
            {/* 046: host artik misafiri GERCEKTEN goruyor.
                guest_fit = misafirin BU ilana uyumu (30-99).
                MVP renk dili: >=85 yesil · >=65 altin · alti gri */}
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              {/* #41: avatar tiklanir — misafirin profili acilir */}
              <TouchableOpacity hitSlop={TAP.slop} disabled={!onOpenProfile} onPress={() => onOpenProfile && onOpenProfile(r.guest_id)} activeOpacity={0.7}
                style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
              <View style={{ width: 42, height: 42, borderRadius: R.full, backgroundColor: C.goldBg,
                             alignItems: "center", justifyContent: "center", marginRight: ARA[10], overflow: "hidden" }}>
                {r.guest_photo
                  ? <Image source={{ uri: r.guest_photo }} style={{ width: 42, height: 42 }} />
                  : <Text style={{ fontWeight: "700", color: C.goldText, fontSize: FS.lg }}>{(r.guest_name || "?").charAt(0).toUpperCase()}</Text>}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{abbrevName(r.guest_name)}</Text>
                {!!r.guest_profession && <Text style={{ color: C.mut, fontSize: FS.sm }}>{r.guest_profession}</Text>}
              </View>
              </TouchableOpacity>
              {/* 🔴 v2.02 — İKİ PUAN BİRBİRİNE KARIŞIYORDU.
                  Sağ üstteki halka EŞLEŞME puanı, chip'teki ise GÜVEN puanı.
                  İkisi de çıplak sayıydı ve aynı karta sığıyordu; kullanıcı
                  hangisinin ne olduğunu ayıramıyordu. Halkanın altına küçük
                  etiket geldi, chip de artık "Güven puanı" diyor. */}
              <View style={{ alignItems: "center" }}>
                <View style={{ width: 38, height: 38, borderRadius: R.full, borderWidth: 2,
                               borderColor: fit >= 65 ? fitC : C.line, alignItems: "center", justifyContent: "center" }}>
                  <Text style={{ color: fitC, fontSize: FS.sm, fontWeight: "700" }}>{fit}</Text>
                </View>
                <Text style={{ fontSize: FS.micro, color: C.dim, marginTop: SP[1], letterSpacing: 0.3 }}>
                  {t.matchScoreLabel}
                </Text>
              </View>
            </View>

            {/* HANGİ İLANA BAŞVURDU — isimden hemen sonra, çiplerden önce.
                Yeni dokunma hedefi değil, saf veri satırı (yeni i18n anahtarı
                da gerekmiyor). */}
            {!!availLine && (
              <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginTop: SP[2] }}>
                {availLine}
              </Text>
            )}

            {/* Guven sinyalleri — host'un karar vermek icin ihtiyaci olan sey */}
            <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[2] }}>
              {/* 🔴 v2.50 — CİHAZDA BOŞ ROZET: iki sebep üst üste binmişti.
                  (1) rqIdOk İKİ KEZ tanımlıydı; JS'te son tanım sessizce
                  kazanır ve açıklayıcı metin ölü koda döner.
                  (2) 🪪 Unicode 14 emojisi (2021) eski Android font
                  setlerinde YOK — IG görsellerinde de aynı tuzağa
                  düşmüştüm. Rozet artık metne dayanır, emojiye değil. */}
              {r.guest_id_verified && <Pill c={C.green} ad="tamam">{t.rqIdOk}</Pill>}
              {r.guest_phone_verified && <Pill c={C.green} ad="tamam">{t.rqPhoneOk}</Pill>}
              {r.guest_linkedin && <Pill c={C.teal}>in</Pill>}
              {r.same_flight ? <Pill c={C.teal} ad="ucus">{t.sameFlight}</Pill>
                : <Pill c={C.muted} ad="ucus">{r.flight_number || t.flightNone}</Pill>}
              {r.same_purpose && <Pill c={C.purple} ad="kutlama">{t.rqSamePurpose}</Pill>}
              {r.guest_sessions > 0 && <Pill c={C.muted}>{r.guest_sessions} {t.rqSessions}</Pill>}
              {r.guest_rating_count >= 3 && <Pill c={C.gold} ad="degerlendirme">{Number(r.guest_rating).toFixed(1)}</Pill>}
              <Pill c={scoreC}>{t.trust} {r.guest_score ?? 0}</Pill>
            </View>

            {r.intro_message ? <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2], fontStyle: "italic" }}>"{r.intro_message}"</Text> : null}
            {r.status === "pending" ? (
            <View style={{ flexDirection: "row", marginTop: ARA[10] }}>
              <Btn v="gold" sm label={t.acceptGuest} onPress={() => act(r.id, "accept")} style={{ marginRight: SP[2], flex: 1 }} />
              <TouchableOpacity hitSlop={TAP.slop} style={{ flex: 1, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, paddingVertical: ARA[10], alignItems: "center" }}
                onPress={() => act(r.id, "decline")}>
                <Text style={{ color: C.ink, fontSize: FS.sm }}>{t.decline}</Text>
              </TouchableOpacity>
            </View>
            ) : (
            <Btn v="gold" sm label={t.openChat} onPress={() => onOpenChat && onOpenChat({ req: r, name: r.guest_name })} style={{ marginTop: ARA[10] }} />
            )}
            {!!actErr[r.id] && (
              <View style={{ backgroundColor: C.redBg, borderRadius: R.xs, padding: SP[2], marginTop: SP[2] }}>
                <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 17 }}>{actErr[r.id]}</Text>
              </View>
            )}
            </View>
          </View>
          );
        })}
      </>}
      {sent.length > 0 && <>
        <Text style={S.label}>{t.myReqs}</Text>
        {sent.map(r => {
          let [lab, col] = stMap[r.status] || [r.status, C.mut];
          // Oturum durumu, istek durumundan DAHA GÜNCEL bilgidir — varsa o kazanır.
          const sx = sessMap[r.id];
          if (sx) {
            const iAmHost = r.host_id === uid;
            const mineConf = iAmHost ? sx.host_confirmed : sx.guest_confirmed;
            const otherConf = iAmHost ? sx.guest_confirmed : sx.host_confirmed;
            if (sx.status === "completed") { lab = t.sessDone; col = C.mut; }
            else if (sx.status === "active" && otherConf && !mineConf) { lab = t.awaitingYourConfirm; col = C.amber; }
            else if (sx.status === "active" && mineConf && !otherConf) { lab = t.awaitingOtherConfirm; col = C.amber; }
            else if (sx.status === "active") { lab = t.sessOngoing; col = C.green; }
            else if (sx.status === "pending") { lab = t.waitingStartShort; col = C.amber; }
          }
          // 🔴 v2.66 (madde 13) — KART ARTIK BAĞLAM TAŞIYOR.
          // Eski kart: host adı + tek kelime durum. Misafir hangi salona,
          // hangi güne, hangi uçuşa başvurduğunu HATIRLAMAK zorundaydı.
          // my_sent_requests bunların hepsini veriyor; okumamak, veriyi
          // çekip çöpe atmaktı.
          const hostNm = r.host_name || names[r.host_id] || "—";
          const timeLine = [r.airport_code, r.avail_date,
            (r.time_from && r.time_to) ? `${String(r.time_from).slice(0,5)}–${String(r.time_to).slice(0,5)}` : null,
          ].filter(Boolean).join(" · ");
          const flightLine = [r.flight_number || null, r.carrier].filter(Boolean).join(" · ");
          const hasSlots = r.slots != null;
          const slotsFull = hasSlots && (r.filled || 0) >= r.slots;
          return (
            /* ════════════════════════════════════════════════════════════
               🔴 v2.95 — "İSTEKLERİM" KARTI (Gökberk madde 2 · 2.1)
               "isteklerim altındaki alanların içerikleri çok iç içe duruyor.
                Host tarafındaki yapı güzel, aynısını buraya da uygula."

               ÖLÇTÜM. Suçlu tek bir satırdı ve görsel değil YAPISAL:
                   <View style={[S.chip, ...]}>• Temel Doğrulama</View>
               `S.chip` bu kod tabanında DOKUNULABİLİR bir öğedir —
               tanımında `minHeight: TAP.minHeight` (44pt) var, çünkü filtre
               ve seçim çipleri için yazıldı. Salt-okunur bir rozet olarak
               kullanılınca 12.5 puntoluk bir metin satırının içine 44
               puntoluk bir kutu giriyor: "Host" ve "2/2 dolu" o kutunun
               altında kalıyor. Ekran görüntüsündeki üst üste binme tam
               olarak budur — CSS değil, bileşen seçimi hatası.

               🆕 SINIF: "DOKUNULABİLİR BİR ÇİPİ SALT-OKUNUR BİR ROZET
               OLARAK KULLANMAK, 44 PUNTOLUK DOKUNMA ALANINI METNİN İÇİNE
               SOKMAKTIR."

               YAPI ARTIK HOST KARTIYLA AYNI:
                 satır 1 · avatar + kimlik + sağda durum
                 satır 2 · bağlam (salon / tarih / saat / uçuş)
                 satır 3 · rozetler — hepsi aynı `Pill`, aynı yükseklik
                 satır 4 · karar notu
                 satır 5 · eylem
               ════════════════════════════════════════════════════════════ */
            <View key={r.id} style={[S.card, { padding: 0, overflow: "hidden" }]}>
              {/* Durum şeridi: host kartındaki "en iyi eşleşme" şeridinin
                  misafir tarafındaki karşılığı. Kartın ne durumda olduğunu
                  kaydırırken bile söyler. */}
              <View style={{ backgroundColor: col + "14", paddingVertical: SP[1], paddingHorizontal: SP[3],
                             flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, marginRight: SP[2], fontSize: FS.micro, fontWeight: "700", color: col, letterSpacing: 0.6 }}>
                  {BUYUK(lab)}
                </Text>
                {hasSlots && (
                  <Text style={{ flexShrink: 0, fontSize: FS.micro, fontWeight: "600", color: slotsFull ? C.red : C.green }}>
                    {String(t.srSlots).replace("{f}", String(r.filled || 0)).replace("{n}", String(r.slots))}
                  </Text>
                )}
              </View>
              <View style={{ padding: SP[3] }}>
              <View style={{ flexDirection: "row", alignItems: "center" }}>
                <View style={{ width: 42, height: 42, borderRadius: R.full, backgroundColor: C.tealBg,
                               alignItems: "center", justifyContent: "center", marginRight: ARA[10], overflow: "hidden" }}>
                  {r.host_photo
                    ? <Image source={{ uri: r.host_photo }} style={{ width: 42, height: 42 }} />
                    : <Text style={{ fontWeight: "700", color: C.tealInk, fontSize: FS.lg }}>{(hostNm || "?").charAt(0).toUpperCase()}</Text>}
                </View>
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.base, fontWeight: "700" }}>{shortName(hostNm)}</Text>
                  <Text numberOfLines={1} style={{ color: C.mut, fontSize: FS.xs, marginTop: 0 }}>{t.hostWord}</Text>
                </View>
              </View>

              {/* BAĞLAM — hangi ilana başvurdum */}
              <View style={{ marginTop: ARA[10], backgroundColor: C.bgAlt, borderRadius: R.xs, padding: ARA[10] }}>
                <Text numberOfLines={2} style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700", lineHeight: 18 }}>
                  {r.lounge_name || hostNm}
                </Text>
                {!!timeLine && <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: SP[1] }}>{timeLine}</Text>}
                {!!flightLine && <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: 0 }}>{flightLine}</Text>}
              </View>

              {/* ROZETLER — hepsi aynı bileşen, aynı yükseklik, üst üste binmez */}
              <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", marginTop: SP[2] }}>
                {!!r.host_badge && <Pill c={C.teal}>• {badgeLabel(t, r.host_badge)}</Pill>}
                {/* 🔴 v2.87 (madde 9) — "2/2 DOLU" YANINDA KENDİ DURUMUN.
                    Gökberk: "2'de 2 dolu olmasına rağmen sohbeti aç falan
                    geliyo... bu ilana kabul alan kişilerden olup olmadığımı
                    anlamıyorum." Kapasite ("2/2") ile kişisel sonuç
                    ("kabul edildin") iki AYRI bilgi; kart yalnız birincisini
                    yüksek sesle söylüyordu. Sağ üstteki durum metni (`lab`)
                    oturum durumuna göre değiştiği için ("Devam ediyor",
                    "Tamamlandı") başvurunun kendisini artık anlatmıyordu.
                    Bu rozet TEK BİR SORUYU cevaplar: bu ilana giren
                    kişilerden biri ben miyim? */}
                <ReqStateBadge status={r.status} t={t} />
              </View>

              {/* karar notu — host'un gerekçesi; yoksa "henüz yanıtlamadı" */}
              {!!r.decision_note && (
                <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2], lineHeight: 18, fontStyle: "italic" }}>"{r.decision_note}"</Text>
              )}
              {r.status === "pending" && !r.responded_at && (
                <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2] }}>{t.srNoAnswer}</Text>
              )}

              <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[10] }}>
                {r.status === "accepted" && (
                  <TouchableOpacity style={{ flex: 1, minHeight: TAP.minHeight, justifyContent: "center" }}
                    accessibilityRole="button" accessibilityLabel={t.openChat}
                    onPress={() => onOpenChat && onOpenChat({ req: r, name: hostNm })}>
                    <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "700" }}>{t.openChat}</Text>
                  </TouchableOpacity>)}
                {r.status === "pending" && (
                  <TouchableOpacity style={{ marginLeft: "auto", minHeight: TAP.minHeight, justifyContent: "center" }}
                    accessibilityRole="button" accessibilityLabel={t.cancelReq}
                    onPress={() => act(r.id, "cancel")}>
                    <Text style={{ color: C.red, fontSize: FS.sm }}>{t.cancelReq}</Text>
                  </TouchableOpacity>
                )}
              </View>
              </View>
            </View>
          );
        })}
      </>}
    </Katlanir>
  );
}
export function Chat({ t, session, request, otherName, onBack, onSafety, onReferral, onOpenProfile, onReport, onLiveStatus, openPanel }) {
  // Mesaj listesinin kaydırma tutamağı — liste yüksekliği her değiştiğinde
  // (mesajlar geldikçe) sona kaydırıyor. `dipteMi` kullanıcı geçmişi okumak
  // için yukarı kaydırdığında onu aşağı ÇEKMEMEK için tutuluyor.
  const kaydirGovde = useRef(null);
  const dipteMi = useRef(true);
  const dibeKaydir = useCallback(() => {
    const r = kaydirGovde.current;
    if (!r || !dipteMi.current) return;
    try { r.scrollToEnd({ animated: false }); } catch (e) {}
  }, []);
  // 🔴 Sohbetten geri basinca UYGULAMA KAPANIYORDU. Ust katmandaki overlay
  // yigini bu ekranda guvenilir calismiyordu; ekran kendi geri tusunu
  // yonetiyor (Onboarding'de oldugu gibi) — garanti cozum.
  const [panelOpenRef] = useState({ v: false });   // geri tuşu için canlı bayrak
  // Donanım geri tuşu `panelKapat`ı ÇAĞIRIR ama o aşağıda tanımlı (state'lerden
  // sonra). Ref, hook sırasını bozmadan canlı bağı kurar.
  const panelKapatRef = useRef(() => {});
  useEffect(() => {
    const h = BackHandler.addEventListener("hardwareBackPress", () => {
      // 🔴 v1.76: oturum paneli açıkken donanım geri tuşu ÖNCE PANELİ kapatır.
      // Önceden sohbetin tamamını kapatıyordu; kullanıcı "panelden çıkamıyorum"
      // hissi yaşıyordu (ekran görüntüsü 5/5.1).
      if (panelOpenRef.v) { panelOpenRef.v = false; panelKapatRef.current(); return true; }
      if (onBack) { onBack(); return true; }
      return false;
    });
    return () => h.remove();
  }, [onBack, panelOpenRef]);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [sosOpen, setSosOpen] = useState(false);
  // v1.74: oturum süresi CANLI aksın (MVP'deki "AKTİF 00:16 · oturum süresi").
  // Önceden süre yalnız yeni mesaj geldiğinde yeniden hesaplanıyordu.
  // 🔴 31 AĞUSTOS · 8. TUR — 30 SANİYE, SANİYELİ BİR SAYAÇ İÇİN YETMEZ.
  // Tasarımın sabit şeridi `02:41:08` gösteriyor. 30 sn'lik bir tik ile
  // saniye hanesi 30'ar 30'ar ZIPLAR — donmuş bir saat, yanlış bir saatten
  // daha kötü görünür ("uygulama takıldı mı?").
  // 1 sn'ye indirildi; maliyeti tek bir `setState`, ve `Chat` zaten açık
  // ekranken çalışıyor (ekran kapanınca `clearInterval`).
  //
  // 🆕 SINIF: "BİR SAYACIN TAZELEME SIKLIĞI, GÖSTERDİĞİ EN KÜÇÜK
  // BİRİMDEN SIK OLMAK ZORUNDADIR — YOKSA HASSASİYET YALAN OLUR."
  // 🔴 31 AĞUSTOS · TİK ARTIK UYARLANABİLİR.
  // Bir tur önce 30sn → 1sn yaptım (tasarımın `02:41:08` saati için
  // zorunluydu). Ama Gökberk'e sunduğum ölçümün kendisi şunu söylüyordu:
  // kalkışa 6 saat varken saniye göstermenin BİLGİ DEĞERİ YOK, buna
  // karşılık ekran açık kaldıkça saniyede bir yeniden çizim yapıyor.
  //
  // Artık eşik zamanın kendisinden geliyor: son 1 saatte saniyeli
  // (`saatli` kip zaten orada devreye giriyor), öncesinde dakikalık.
  // Yani tazeleme sıklığı, gösterilen en küçük birimi TAKİP EDİYOR.
  //
  // 🆕 SINIF: "BİR SAYACIN MALİYETİ, GÖSTERDİĞİ HASSASİYETİN BEDELİDİR —
  // HASSASİYET GEREKMEYEN YERDE BEDELİ DE ÖDEME."
  // ⚠️ `av` bu dosyada 280 satır AŞAĞIDA tanımlı (`request?.availabilities`).
  // İlk yazımda buradan `av`ye baktım ve `Chat` beş vakada birden ÇÖKTÜ —
  // `const`un zamansal ölü bölgesi. Mount testi anında yakaladı.
  // Kaynağı doğrudan prop'tan okuyorum; `av` yalnız bir kısaltma zaten.
  const [tick, setTick] = useState(0);
  // 🔴 3 Eylül — `my_sent_requests` / `host_requests` satırları ilan
  // alanlarını DÜZ taşıyor (avail_date, lounge_name…); iç içe
  // `availabilities` yok. Eski okuma bu yoldan gelen sohbette sabit
  // şeridi (kalkışa · buluşma yeri) ve başlık altını BOŞ bırakıyordu —
  // web sahnesinde ölçüldü. Düz satıra düşülüyor.
  const _a = request?.availabilities || (request && request?.avail_date ? request : {});
  const yakin = (() => {
    const gs = geriSayim(_a.avail_date, _a.time_from, _a.time_to, t,
                         undefined, { saatli: true });
    return !!(gs && gs.saatli);
  })();
  useEffect(() => {
    const id = setInterval(() => setTick(x => x + 1), yakin ? 1000 : 60000);
    return () => clearInterval(id);
  }, [yakin]);
  const [cancelErr, setCancelErr] = useState("");
  const uid = session?.user?.id;
  // 🔴 v1.71 KÖK NEDEN ("host tarafında oturum butonu görünmüyor"):
  // Sohbet bazı yerlerden (Oturum Geçmişi, Canlı Durum, bildirim) yalnızca
  // { id } taşıyan bir request nesnesiyle açılıyordu. host_id undefined
  // olunca isHost HER ZAMAN false hesaplanıyor, host kendini misafir
  // sanan bir ekran görüyordu: "Host oturumu başlatınca burada görünecek".
  // Çözüm: eksik alan varsa request satırı sunucudan tamamlanır.
  // 🔴 12 EYLÜL · KAPSAM TURU — `request` HİÇ GELMEYEBİLİR VE EKRAN ÇÖKÜYORDU.
  // Mount testine "Chat-bos" vakası eklendiği an ortaya çıktı:
  // "Cannot read properties of undefined (reading 'host_id')" — yani BEYAZ
  // EKRAN. Hemen üstteki v1.71 notu bu ekranın "yalnız { id } ile
  // açılabildiğini" zaten yazıyordu; ben eksik ALANLARA karşı sertleştirmiş,
  // eksik NESNEYE karşı sertleştirmemiştim.
  // 🆕 SINIF: "BİR NESNENİN ALANLARININ EKSİK OLABİLECEĞİNİ DÜŞÜNÜYORSAN,
  // NESNENİN KENDİSİNİN DE OLMAYABİLECEĞİNİ DÜŞÜN — İKİSİ AYNI YOLDAN GELİR."
  const [reqFull, setReqFull] = useState(request || {});
  useEffect(() => {
    if (request?.host_id && request?.guest_id) { setReqFull(request); return; }
    if (!request?.id) return;          // açacak bir istek yoksa sorgu da yok
    let alive = true;
    (async () => {
      const { data, error: hata3 } = await supabase.from("requests")
        .select("id, host_id, guest_id, avail_id, status, intro_message, type, purpose")
        .eq("id", request?.id).maybeSingle();
        if (hata3) logError("ekranlar_yalin.js:540", hata3);
      if (alive && data) setReqFull(prev => ({ ...prev, ...data }));
    })();
    return () => { alive = false; };
  }, [request?.id, request?.host_id, request?.guest_id]);
  const isHost = !!uid && reqFull?.host_id === uid;
  const otherId = isHost ? reqFull?.guest_id : reqFull?.host_id;   // oturumdaki diğer kişi
  const [connState, setConnState] = useState("none");            // none|sent|incoming|connected
  const [connReqId, setConnReqId] = useState(null);
  const [chan, setChan] = useState(null);
  const [msgs, setMsgs] = useState([]);
  const [txt, setTxt] = useState("");
  const [sess, setSess] = useState(undefined); // undefined=yükleniyor, null=yok
  // v1.82: "Şimdi puanla" gibi dışarıdan gelen girişlerde panel DOĞRUDAN açılır
  const [panelOpen, setPanelOpenState] = useState(!!openPanel);   // v1.75: tam ekran oturum paneli
  const setPanelOpen = (v) => { panelOpenRef.v = !!v; setPanelOpenState(!!v); };
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL (Gökberk Not 4) — "oturum puanla ile oturum tamamla
  // ekranına gittikten sonra back yapıldığında o kullanıcı ile olan BOŞ
  // chat ekranı açılıyor. Ben oturum tamamlaya chat üzerinden değil de
  // oturum tamamla üzerinden gittiysem back yapınca chat'e gitmem
  // mantıksız değil mi?"
  // Haklı. Puanlama paneli sohbetin İÇİNDE yaşıyor; Değerlendirmeler ya da
  // Oturum Geçmişi'nden gelindiğinde sohbet yalnız bir TAŞIYICI. Geri
  // tuşu o taşıyıcıyı değil, GELİNEN YERİ hedeflemeli.
  // `openPanel` zaten "buraya puanlamak için geldim" demek — geri o zaman
  // ekranın tamamını kapatıyor.
  // 🆕 SINIF: "GERİ TUŞU, EKRAN AĞACINDA BİR ÜST DÜĞÜME DEĞİL,
  // KULLANICININ GELDİĞİ YERE GİDER."
  // ══════════════════════════════════════════════════════════════════════
  const panelKapat = () => {
    if (openPanel && onBack) { onBack(); return; }
    setPanelOpen(false);
  };
  panelKapatRef.current = panelKapat;
  const [rated, setRated] = useState(false);
  // 🔵 v2.100 (SQL 256) — KAPIDA ALINMADIM.
  // Kredi para karşılığı satılacaksa, satılan şeyin "erişim" değil "istek
  // hakkı" olduğu iddiası ancak buluşma gerçekleşmediğinde paranın geri
  // dönmesiyle doğru olur. Bu düğme o iddianın mekanizması.
  // Görünürlüğüne SUNUCU karar veriyor (süre penceresi, tekrar bildirim,
  // taraf kontrolü) — istemci kendi kuralını uydurmuyor.
  const [kapiOlur, setKapiOlur] = useState(null);
  const [kapiAcik, setKapiAcik] = useState(false);
  const [kapiBusy, setKapiBusy] = useState(false);
  const [kapiMsg, setKapiMsg] = useState("");
  // SQL 284 — anlaşmazlık: her iki taraf, tamamlanmış/iptal edilmiş
  // buluşmada 72 saat içinde. Görünürlüğü sunucu kararı (pencere, tekrar).
  const [itirazAcik, setItirazAcik] = useState(false);
  const [itirazSebep, setItirazSebep] = useState("");
  const [itirazNot, setItirazNot] = useState("");
  const [itirazBusy, setItirazBusy] = useState(false);
  const [itirazMsg, setItirazMsg] = useState("");
  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState("");
  const [err, setErr] = useState("");
  // 13 Eylül · v5.9.0 — çevrimdışı kuyruğu: bu kanalda bekleyen mesajlar.
  const [kuyruk, setKuyruk] = useState(0);
  const [kuyruktakiler, setKuyruktakiler] = useState([]);

  // v2.89 — aktif oturumun sunucudan gelen detayı (ad, salon, uçuş)
  const [det, setDet] = useState(null);

  const addMsgs = rows => setMsgs(prev => {
    const seen = new Set(prev.map(m => m.id));
    return [...prev, ...rows.filter(m => !seen.has(m.id))];
  });

  // 🔴 v2.89 (Gökberk md.2) — EKRAN VERİYİ HİÇ İSTEMİYORDU.
  // "Birlikte: Guest" ve "LOUNGE: Lounge oturumu" ikisi de YER TUTUCUYDU:
  // karşı tarafın adı açanın verdiği string'den geliyordu (App.js:720
  // `name: null` geçiyor), salon adı ise `request?.availabilities`ten —
  // ama onarım sorgusu (aşağıda) availabilities'i JOIN etmiyor.
  // Artık tek kaynak: `aktif_oturum_detay()` (SQL 234). Altı ayrı açan
  // altı farklı `request` şekli geçiriyor; onarımı istemciye bırakırsam
  // altı yerde altı kez onarmam gerekir.
  const loadSess = useCallback(async () => {
    // 🔴 v3.9 — OTURUM SATIRI İLE OTURUM DETAYI SIRAYLA OKUNUYORDU.
    // İkisi de YALNIZ `request?.id` ile parametreli; ikincisi birincinin
    // sonucunu hiç kullanmıyor. Aktif oturum ekranı açılırken iki tur
    // bekliyordu — bu ekran, kapıda ayakta bakılan ekran.
    // ⚠️ `ratings` okuması dalgaya GİRMİYOR: o, `s.status === "completed"`
    // koşuluna bağlı. Koşullu bir çağrıyı dalgaya almak, tamamlanmamış
    // her oturumda gereksiz bir sorgu açmak olurdu.
    const [{ data: s }, { data: oturumDetay, error: de }] = await Promise.all([
      supabase.from("sessions").select("*").eq("request_id", request?.id).maybeSingle(),
      supabase.rpc("aktif_oturum_detay", { p_request_id: request?.id }),
    ]);
    setSess(s || null);
    // Ad + salon + uçuş: sunucudan. Hata olursa `det` null kalır ve
    // ekran eski davranışına düşer — sessizce YANLIŞ değil, sessizce ESKİ.
    // ⚠️ Değişken adı `oturumDetay` — kısa `d` DEĞİL. RPC alan denetimi
    // değişken adına bakarak "bu RPC bu alanı döndürüyor mu?" diye
    // soruyor; bu dosyada `d` adı Date nesneleri için de kullanılıyor
    // (tarih/saat seçiciler) ve denetim `d.setHours`u bu RPC'nin alanı
    // sanıp kırmızı yandı. Nöbetçi haksız değil: aynı ada iki farklı
    // anlam yüklemek okuyanı da yanıltır.
    if (de) logError("aktif_oturum_detay", de);
    else if (Array.isArray(oturumDetay) && oturumDetay.length) setDet(oturumDetay[0]);
    if (s?.status === "completed") {
      const { data: r, error: hata4 } = await supabase.from("ratings").select("id")
        .eq("session_id", s.id).eq("rater_id", uid).maybeSingle();
        if (hata4) logError("ekranlar_yalin.js:614", hata4);
      setRated(!!r);
    }
  }, [request?.id, uid]);

  const loadConn = useCallback(async () => {
    if (!otherId || !uid) return;
    const { data: cr, error: hata5 } = await supabase.from("connection_requests").select("id, from_id, to_id, status")
      .or(`and(from_id.eq.${uid},to_id.eq.${otherId}),and(from_id.eq.${otherId},to_id.eq.${uid})`)
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (hata5) logError("ekranlar_yalin.js:623", hata5);
    if (!cr) { setConnState("none"); setConnReqId(null); return; }
    setConnReqId(cr.id);
    if (cr.status === "accepted") setConnState("connected");
    else if (cr.status === "pending") setConnState(cr.from_id === uid ? "sent" : "incoming");
    else setConnState("none");
  }, [otherId, uid, request?.id]);

  useEffect(() => { loadConn(); }, [loadConn, sess]);

  async function doConnect() {
    setErr("");
    const { error } = await supabase.rpc("send_connection", { p_to: otherId, p_intent: "Lounge oturumunda tanışıldı", p_intro: t.stayInTouchIntro });
    if (error) return setErr(mapErr(t, error.message));
    loadConn();
  }
  async function doAcceptConn() {
    setErr("");
    if (!connReqId) return;
    const { error } = await supabase.rpc("respond_connection", { p_id: connReqId, p_accept: true });
    if (error) return setErr(mapErr(t, error.message));
    loadConn();
  }

  useEffect(() => {
    let sub, iv1, iv2;
    // 🔴 20 AĞUSTOS — OTURUM KONTROLLERİ SOHBETTE HİÇ GÖRÜNMÜYORDU.
    // Gökberk: "ilan kabulü sonrası açılan sohbet ekranında oturum başlat,
    // oturum tamamla, canlı durum gibi alanlar yok gibi. Uçmuş sanki."
    //
    // Sebep tam olarak bir satırdı: aşağıdaki `if (!c) return;`.
    // `chat_channels` satırı bulunamazsa fonksiyon ERKEN DÖNÜYOR ve
    // `loadSess()` HİÇ ÇAĞRILMIYOR. `sess` sonsuza kadar `undefined`
    // kalıyor; alttaki oturum çubuğu ise `sess !== undefined` koşuluna
    // bağlı → çubuk hiç çizilmiyor. Kullanıcı sohbeti görüyor, oturumu
    // göremiyor ve hiçbir hata mesajı yok.
    //
    // 🆕 SINIF: **"ERKEN DÖNÜŞ, ARKASINDAKİ HER ŞEYİ SESSİZCE İPTAL EDER."**
    // İki bağımsız iş (sohbet kanalı · oturum durumu) tek `async` bloğa
    // dizilince, birincisinin yokluğu ikincisini de öldürüyor.
    //
    // Çözüm: oturum yüklemesi kanaldan BAĞIMSIZ ve ÖNCE çalışır.
    // Ayrıca kanal yoksa artık sessiz kalmıyoruz.
    loadSess();
    (async () => {
      const { data: c, error: cErr } = await supabase
        .from("chat_channels").select("id").eq("request_id", request?.id).maybeSingle();
      if (cErr) setErr(t.chatChannelErr || "Sohbet kanalı açılamadı.");
      if (!c) { setChan(null); return; }
      setChan(c.id);
      const { data: m, error: hata6 } = await supabase.from("messages").select("*").eq("channel_id", c.id).order("created_at");
      if (hata6) logError("ekranlar_yalin.js:676", hata6);
      // 🔴 13 EYLÜL · v5.9.0 — ÇEVRİMDIŞI OKUMA.
      // Ağ yoksa sohbet BOŞ açılıyordu; havalimanında, buluşmanın tam
      // öncesinde, konuştuğun kişiyle ne konuştuğunu göremiyordun.
      // Artık son yükleme önbellekte duruyor ve ağ yokken o çiziliyor.
      // ⚠️ BAYAT VERİ TAZE GİBİ GÖSTERİLMİYOR: önbellek yaşı taşınıyor
      // (bkz. `onbellektenOku`), 72 saatten eskisi `bayat` işaretli gelir.
      if (m) { setMsgs(m); onbellegeYaz("sohbet:" + c.id, m.slice(-50)); }
      else {
        const onb = await onbellektenOku("sohbet:" + c.id);
        if (onb && Array.isArray(onb.veri)) setMsgs(onb.veri);
      }
      sub = supabase.channel("chat-" + c.id)
        .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `channel_id=eq.${c.id}` },
          p => addMsgs([p.new]))
        .subscribe();
      iv1 = setInterval(async () => {
        const { data: m2, error: hata7 } = await supabase.from("messages").select("*").eq("channel_id", c.id).order("created_at");
        if (hata7) logError("ekranlar_yalin.js:684", hata7);
        if (m2) setMsgs(m2);
      }, 6000);
      iv2 = setInterval(loadSess, 8000);
    })();
    // Kanal bulunamasa bile oturum durumu tazelenmeye devam etmeli.
    iv2 = iv2 || setInterval(loadSess, 8000);
    return () => { if (sub) supabase.removeChannel(sub); clearInterval(iv1); clearInterval(iv2); };
  }, [request?.id, loadSess]);

  // ══════════════════════════════════════════════════════════════════
  // 🔴 KUYRUK: OLAY DEĞİL DENEME. `NetInfo` eklemedik (gerekçe
  // `src/cevrimdisi.js` · KARAR 2 — havalimanı giriş portalı "bağlısın"
  // der). Bunun yerine üç tetik:
  //   1. Uygulama ÖNE GELDİĞİNDE (`AppState`, RN çekirdeği)
  //   2. Sohbet açıldığında bir kez
  //   3. Her gönderim denemesinde (kullanıcı zaten ağı deniyor)
  // Yoklama yok: "ağ var mı" sorusunu SORMAK yerine göndermeyi DENİYORUZ.
  // ══════════════════════════════════════════════════════════════════
  useEffect(() => {
    if (!chan) return;
    let canli = true;
    const tazele = async () => {
      const l = await kuyrugaBak(chan);
      if (!canli) return;
      setKuyruktakiler(l);
      setKuyruk(l.filter((x) => x.durum !== "dustu").length);
    };
    const cik = kuyrukDinle(tazele);
    tazele();
    kuyrugaAkit().then(tazele);
    const dinle = AppState.addEventListener("change", (durum) => {
      if (durum === "active") kuyrugaAkit().then(tazele);
    });
    return () => { canli = false; cik(); dinle && dinle.remove && dinle.remove(); };
  }, [chan]);

  // ══════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL · v5.9.0 — MESAJ ARTIK KAYBOLMUYOR (çevrimdışı kuyruğu).
  //
  // Eski hâl: ağ yoksa `insert` düşüyor, `setErr` bir cümle yazıyor ve
  // KULLANICININ YAZDIĞI METİN ZATEN SİLİNMİŞ oluyordu (`setTxt("")` en
  // başta). Yani havalimanında — ürünün TAM OLARAK kullanıldığı yerde —
  // yazdığın mesaj hem gitmiyor hem de geri gelmiyordu.
  //
  // Yeni hâl: mesaj ÖNCE kuyruğa yazılır (kalıcı, AsyncStorage), sonra
  // gönderim denenir. Ağ varsa aynı anda gider ve kuyruktan düşer; yoksa
  // orada bekler ve ağ dönünce kendiliğinden gider.
  // `id` kuyrukta üretiliyor: tekrar gönderimde birincil anahtar mükerrer
  // teslimi reddediyor (bkz. `src/cevrimdisi.js` · KARAR 3).
  //
  // 🆕 SINIF: "KULLANICININ YAZDIĞINI EKRANDAN SİLMEDEN ÖNCE BİR YERE
  // YAZ — GÖNDERİM BAŞARISIZ OLABİLİR, YAZMA EYLEMİ GERİ ALINAMAZ."
  async function send() {
    const body = txt.trim();
    if (!body || !chan) return;
    const k = await mesajKuyruga({ channel_id: chan, from_id: uid, body });
    if (!k.ok) { setErr(t.queueFull); return; }
    setTxt("");                      // ancak KAYIT ALTINA ALINDIKTAN SONRA
    // 🔴 İYİMSER EKLEME, MÜKERRER RİSKİ OLMADAN.
    // Mesajı hemen listeye koyuyoruz — kullanıcı yazdığını anında görsün.
    // Normalde bu, gerçek zamanlı INSERT olayı gelince İKİ KOPYA demektir;
    // burada değil: kuyruğun ürettiği `id`, sunucudaki satırın `id`si ile
    // AYNI (bkz. `cevrimdisi.js` · KARAR 3) ve `addMsgs` id'ye göre
    // tekilleştiriyor. Yani idempotans anahtarı bize ikinci bir hediye
    // veriyor: bedava iyimser arayüz.
    // 🆕 SINIF: "İSTEMCİDE ÜRETİLEN BİR KİMLİK, HEM MÜKERRER GÖNDERİMİ
    // HEM MÜKERRER ÇİZİMİ AYNI ANDA ÇÖZER."
    addMsgs([{ id: k.kayit.id, channel_id: chan, from_id: uid, body,
               created_at: new Date().toISOString() }]);
    const sonuc = await kuyrugaAkit();
    setKuyruk(sonuc.kalan > 0 ? sonuc.kalan : 0);
  }

  // 🔴 v2.52 — "AN" EKRANLARI. Oturum tamamlandığında kullanıcı sohbet
  // listesine düşüyordu; ürünün en değerli anı (buluşma gerçekleşti)
  // hiçbir iz bırakmıyordu. Artık tam ekran koyu sahne: tebrik, ne
  // kazandığı ve tek net sonraki adım (puanla). Kapatılabilir —
  // duygusal ekran, akışı KİLİTLEMEZ.
  const [momentSeen, setMomentSeen] = useState(false);
  const [sessJustStarted, setSessJustStarted] = useState(false);

  // 🔴 v1.75 + SQL 080: OTURUM ÇİFT ONAYLA BAŞLAR. Kabul, buluşmadan günler
  // önce olabildiği için artık kabulde otomatik başlamıyor; iki taraf da
  // "Oturumu Başlat"a basınca süre O AN işlemeye başlar.
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 13 EYLÜL · v5.9.0 — BİNİŞ KARTI KAPISI "OTURUMU BAŞLAT"IN ÖNÜNDE.
  //
  // Gökberk: "Eşleşme tamamlanıp taraflar sohbet ekranına geçtiğinde, en
  // altta tek bir birincil 'Oturumu Başlat' butonu belirecek… tıklandığında
  // ekrana bir alt panel inecek."
  //
  // ⚠️ KAPI, DÜĞMENİN YERİNİ ALMIYOR — ÖNÜNE GEÇİYOR. Düğme zaten vardı
  // (v1.75 · SQL 080, ÇİFT ONAY). Doğrulama ile oturum başlatma iki ayrı
  // sorumluluk; panel hiçbir durumda `start_session_request` çağırmaz,
  // yalnız "devam" der. Karıştırsaydık doğrulamayı değiştirmek oturum
  // akışını da riske atardı.
  //
  // ⚠️ KAPI TARAF BAŞINA. Çift onayda iki taraf ayrı ayrı basıyor; host'un
  // salon hakkı ile misafirin aynı-gün seyahat şartı AYRI kurallar
  // (SQL 099). Bu yüzden `dogrulandi` bu cihazın kararıdır.
  //
  // 🆕 SINIF: "BİR KAPIYI VAR OLAN BİR EYLEMİN İÇİNE GÖMERSEN İKİSİ TEK
  // BİR ŞEY OLUR — KAPIYI ÖNÜNE KOY, EYLEM KENDİ KALSIN."
  const [bpPanel, setBpPanel] = useState(false);
  const [bpBitti, setBpBitti] = useState(false);

  // Doğrulama kapısı: ilk basışta paneli açar, panel "devam" derse başlatır.
  function baslatIstegi() {
    if (bpBitti) return doStart();
    setErr("");
    setBpPanel(true);
  }

  async function doStart() {
    setErr("");
    const { error } = await supabase.rpc("start_session_request", { p_request_id: request?.id });
    if (error) return setErr(mapErr(t, error.message));
    await loadSess();
    // v2.53: oturum BU EKRANDA başladıysa "an" ekranını göster.
    // (Sonradan girişlerde gösterilmez — an bir kez yaşanır.)
    setSessJustStarted(true); setMomentSeen(false);
  }
  // İptal: oturum başlamamışsa veya ilk 5 dakikadaysa kredi iade + ceza yok;
  // sonrası geç iptal (kredi yanar, iptal edenin güveni düşer). Kural
  // sunucuda; burada sadece doğru fonksiyon çağrılır.
  async function doCancelSession(reason) {
    setErr("");
    if (sess && (sess.status === "pending" || sess.status === "active")) {
      // 🔴 v3.4 — HATA GÖRÜNMEYEN BİR DURUMA YAZILIYORDU.
      // `setErr` yazıyordu ama iptal onay penceresi `cancelErr`i çiziyor —
      // ve `setCancelErr`in kodda TEK BİR çağrısı yoktu. Sunucu iptali
      // reddettiğinde (örn. aktif oturum var) pencere açık kalıyor,
      // hiçbir şey değişmiyor, kullanıcı "Evet"e tekrar tekrar basıyordu.
      //
      // 🆕 SINIF: "BİR HATAYI DOĞRU YAKALAYIP YANLIŞ DURUMA YAZMAK, HİÇ
      // YAKALAMAMAKLA AYNI SONUCU VERİR — AMA KODA BAKAN 'HALLEDİLMİŞ'
      // SANIR."
      const { error } = await supabase.rpc("cancel_session", { p_session_id: sess.id, p_reason: reason || null });
      if (error) return setCancelErr(mapErr(t, error.message));
    } else {
      const { error } = await supabase.rpc("respond_request", { p_request_id: request?.id, p_action: "cancel" });
      if (error) return setCancelErr(mapErr(t, error.message));
    }
    setConfirmCancel(false);
    onBack && onBack();
  }
  async function doConfirm() {
    setErr("");
    const { error } = await supabase.rpc("confirm_session", { p_session_id: sess.id });
    if (error) return setErr(mapErr(t, error.message));
    loadSess();
  }
  async function doRate() {
    setErr("");
    if (!stars) return;
    const { data, error } = await supabase.rpc("rate_session", {
      p_session_id: sess.id, p_score: stars, p_comment: comment.trim() || null,
    });
    if (error) return setErr(mapErr(t, error.message));
    // v1.73 / SQL 078: puan artık OTURUM TAMAMLANINCA veriliyor, puanlamada
    // değil. rate_session points_earned döndürmez; kazanç kartı zaten
    // tamamlanma anında doğru rakamı gösteriyor.
    // 🔵 v2.99 — `setPts(...)` KALDIRILDI. Hemen üstteki not zaten "puan
    // puanlamada değil OTURUM TAMAMLANINCA veriliyor" diyor; yani burada
    // hesaplanan 500/200 sayısı SUNUCUNUN vermediği bir sayıydı ve zaten
    // hiçbir yerde çizilmiyordu. Çizilseydi kullanıcıya cüzdanında
    // görmeyeceği bir kazanç vaat etmiş olurduk.
    setRated(true);
  }

  useEffect(() => {
    let iptal = false;
    (async () => {
      if (!sess || !sess.id) { setKapiOlur(null); return; }
      const { data, error } = await supabase.rpc("kapida_ret_bildirebilir_mi", { p_session_id: sess.id });
      if (error) { logError("kapida_ret_bildirebilir_mi", error); return; }
      if (!iptal) setKapiOlur(data || null);
    })();
    return () => { iptal = true; };
  }, [sess && sess.id, sess && sess.status]);

  async function kapidaBildir(sebep) {
    if (!sess || !sess.id) return;
    setKapiBusy(true); setKapiMsg("");
    const { data, error } = await supabase.rpc("kapida_giremedim",
      { p_session_id: sess.id, p_sebep: sebep, p_aciklama: null });
    setKapiBusy(false);
    if (error) { logError("kapida_giremedim", error); setKapiMsg(mapErr(t, error.message)); return; }
    if (data && data.ok === false) { setKapiMsg(mapErr(t, data.reason)); return; }
    setKapiMsg(data && data.iade ? t.doorRefunded : t.doorSent);
    setKapiOlur({ olur: false });
    setKapiAcik(false);
  }

  async function itirazGonder() {
    if (!sess || !sess.id || !itirazSebep) return;
    setItirazBusy(true); setItirazMsg("");
    const { error } = await supabase.rpc("open_dispute",
      { p_session: sess.id, p_reason: itirazSebep, p_detail: itirazNot.trim() || null });
    setItirazBusy(false);
    if (error) { logError("open_dispute", error); setItirazMsg(mapErr(t, error.message)); return; }
    setItirazMsg(t.disputeSent); setItirazAcik(false); setItirazSebep(""); setItirazNot("");
  }
  // Anlaşmazlık paneli: tamamlanmış ve iptal edilmiş buluşmada ortak
  const itirazPaneli = (
    <>
      {!itirazAcik && !itirazMsg && (
        <TouchableOpacity hitSlop={TAP.slop} onPress={() => setItirazAcik(true)}
          accessibilityRole="button" accessibilityLabel={t.disputeBtn}
          style={{ minHeight: 44, justifyContent: "center", alignItems: "center", marginTop: SP[1] }}>
          <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.disputeBtn}</Text>
        </TouchableOpacity>
      )}
      {itirazAcik && (
        <View style={{ backgroundColor: C.amberBg, borderRadius: R.sm, padding: SP[3], marginTop: SP[2], marginBottom: SP[2] }}>
          <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{t.disputeTitle}</Text>
          <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 18, marginTop: ARA[6] }}>{t.disputeBody}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[2] }}>
            {(t.disputeReasons || []).map(([k, lb]) => (
              <Secim key={k} ton="gold" secili={itirazSebep === k} etiket={lb} a11yRol="radio"
                onPress={() => setItirazSebep(k)} stil={{ marginRight: SP[2], marginBottom: SP[2] }} />
            ))}
          </View>
          <TextInput value={itirazNot} onChangeText={setItirazNot} placeholder={t.disputeNote}
            placeholderTextColor={C.muted} multiline maxLength={600}
            accessibilityLabel={t.disputeNote}
            style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                     padding: SP[3], color: C.body, fontSize: FS.sm, minHeight: 64, marginTop: SP[1] }} />
          <Btn v="gold" sm label={t.disputeSend} disabled={itirazBusy || !itirazSebep} busy={itirazBusy}
            onPress={itirazGonder} a11yLabel={t.disputeSend} style={{ marginTop: SP[2] }} />
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setItirazAcik(false)}
            accessibilityRole="button" accessibilityLabel={t.close}
            style={{ minHeight: 44, justifyContent: "center", alignItems: "center", marginTop: SP[1] }}>
            <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.close}</Text>
          </TouchableOpacity>
        </View>
      )}
      {!!itirazMsg && (
        <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, padding: ARA[10], marginTop: ARA[6], marginBottom: SP[2] }}>
          <Text style={{ color: C.greenInk, fontSize: FS.sm }}>{itirazMsg}</Text>
        </View>
      )}
    </>
  );

  const myConfirmed = sess && (isHost ? sess.host_confirmed : sess.guest_confirmed);
  // Bu kullanıcı "başlat" dedi mi (çift onaylı başlatmanın kendi tarafı)
  const iStarted = !!(sess && (isHost ? sess.host_started_at : sess.guest_started_at));
  const otherStarted = !!(sess && (isHost ? sess.guest_started_at : sess.host_started_at));
  const liveClock = (sess && sess.started_at)
    ? (() => { const m = Math.max(0, Math.floor((Date.now() - new Date(sess.started_at).getTime()) / 60000));
               return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"); })()
    : "00:00";
  // 549. satırdaki ikizi `request?.` yazıyordu, bu yazmıyordu — aynı
  // ifadenin iki kopyası, biri korunmuş biri korunmamış. Kopya kod böyle
  // ısırır: düzeltmeyi bir kopyaya uygularsın, diğeri sessizce bekler.
  const av = request?.availabilities || (request && request?.avail_date ? request : {});
  // MVP baglam satiri: "Primeclass Lounge · IST · 14:00–18:00"
  const ctxTime = (av.time_from && av.time_to)
    ? ` · ${String(av.time_from).slice(0,5)}–${String(av.time_to).slice(0,5)}` : "";
  const ctx = av.lounge_name || av.airport_code
    ? `${av.lounge_name || av.airport_code}${av.airport_code ? " · " + av.airport_code : ""}${ctxTime}`
    : (request?.intent || t.loungeSession);
  // Buluşma noktası (tasarım: "Kapı A12 önü"): karşı tarafın paylaştığı son
  // canlı durum (sessions.host_status / guest_status — LiveStatus). Veritabanında
  // ayrı bir "meeting_point" alanı YOK (rpc_field_e2e bunu yakaladı); durum
  // paylaşılmadıysa başlık altı yalnız salon adını taşır.
  const bulusma = (sess && (isHost ? sess.guest_status : sess.host_status)) || null;

  // 🔴 v2.52 — OTURUM TAMAMLANDI ANI (koyu sahne, tema renkleriyle).
  // Yalnız oturum "completed" olduğunda ve kullanıcı bu ekranı henüz
  // kapatmadığında gösterilir; kapatınca normal sohbet görünür.
  // 2. AN — OTURUM BAŞLADI: koyu sahne, buluşma anının kendisi.
  //
  // 🔴 v2.68 — ÖLÜ `code` PROP'U KALDIRILDI. Buraya
  // `code={sess.entry_code || sess.code}` yazılmıştı; `sessions`
  // tablosunda bu iki kolonun İKİSİ DE YOK (ölçüldü: id, request_id,
  // status, host_confirmed, guest_confirmed, host_started_at,
  // guest_started_at, started_at, completed_at, cancel_*, *_status,
  // no_show_user_id, rate_deferred_by). Prop her zaman null geçiyor,
  // MomentScreen'in kod bloğu hiç çizilmiyordu. Üründe "giriş kodu"
  // diye bir kavram yok; olmayan alanı okumaya devam etmek ileride
  // "kod neden görünmüyor" diye saat harcatırdı.
  if (sess && sess.status === "active" && sessJustStarted && !momentSeen) {
    return (
      <MomentScreen t={t}
        kind="started"
        title={t.momentStartTitle}
        subtitle={t.momentStartBody}
        meta={ctx}
        primary={{ label: t.momentStartCta, onPress: () => setMomentSeen(true) }}
      />
    );
  }

  if (sess && sess.status === "completed" && !momentSeen) {
    return (
      <MomentScreen t={t}
        kind="completed"
        title={t.momentDoneTitle}
        subtitle={t.momentDoneBody.replace("{name}", shortName(otherName))}
        // 🔴 v2.79 — meta ARTIK DURUMU DA SÖYLÜYOR. Eskiden yalnız
        // "Lounge oturumu" yazıyordu ve altı boştu; ekranın en alt
        // satırı bir başlık gibi durup hiçbir şey anlatmıyordu.
        meta={`${ctx} · ${t.momentDoneMeta ? t.momentDoneMeta.split("·").pop().trim() : ""}`.replace(/ · $/, "")}
        primary={{ label: t.rateNow, onPress: () => { setMomentSeen(true); setPanelOpenState(true); } }}
        secondary={{ label: t.momentClose, onPress: () => setMomentSeen(true) }}
      />
    );
  }

  return (
    <Sayfa ufuk={30}>
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · 5. TUR — SOHBET BAŞLIĞINDA İSİM 35pt'YE
          SIKIŞMIŞTI.

          Taşma kapısı ölçtü (320pt cihaz): "Ayşegül Demirtaş" 20pt'ta
          84.2pt yer istiyor, kutusu 35pt. Yanındaki mekân satırı da
          64.4pt isteyip 35pt buluyordu. Sebep sağdaki üç eylem:
          "Bildir" (33pt) + acil ikonu + "İsteği iptal et" (79pt) —
          hepsi ETİKETLİ ve hepsi başlık çubuğunda.

          TASARIM NE DİYOR: sohbet başlığında EYLEM YOK.
            <header class="ust ince-ust">
              geri ‹ · avatar + ad + mekân · <div style="width:20px">
          Sağda yalnız 20px'lik bir denge boşluğu var. Yani tasarım o
          çubuğu tamamen KARŞIDAKİ İNSANA ayırmış.

          İki yıkıcı eylem SİLİNMEDİ — acil sayfasına taşındı (aşağıdaki
          Modal artık bir eylem sayfası). Bir dokunuş uzaklaştılar; bu
          doğru, çünkü ikisi de geri alınamaz.

          🆕 SINIF: "BİR BAŞLIK ÇUBUĞUNDA HER EYLEM, BAŞLIĞIN KENDİSİNDEN
          ÇALINMIŞ GENİŞLİKTİR — VE SOHBET EKRANINDA BAŞLIK, KARŞIDAKİ
          İNSANIN ADIDIR."
          ══════════════════════════════════════════════════════════════ */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 3 EYLÜL — SOHBET BAŞLIĞI TASARIM 06 (`.sohbet-ust`):
            [geri dairesi] [avatar 40 · teal nokta] [Deniz K. 15/700]
                                                    [TAV Primeclass · Kapı A12]
          "LOUNGELINK" marka satırı, "Profili görüntüle" bağlantı satırı ve
          altın güvenlik bandı burada yok: marka bant ekranlarına ait;
          profile avatara/ada dokunarak gidilir; güvenlik cümlesi sabit
          şeridin altında tek satır, sessiz. SOS dairesi (acil) tasarımda
          çizilmemiş ama güvenlik ürünün sözü — sağda kalıyor. */}
      {/* 4 Eylül — TASARIM 06 ÖLÇÜLDÜ: üst blok 132pt yüksek TEK `surface` yüzey;
          içinde satır (üstten 20, 38 yüksek) ve sabit şerit (üstten 74, 44
          yüksek). Bizde satır `card` zeminde 59pt'te bitiyor, şerit gövdeye
          düşüyordu. Şimdi blok tek parça, ölçüler tasarımın. */}
      <View style={{ backgroundColor: C.surface, paddingTop: TOPPAD, minHeight: TOPPAD + 132 }}>
      <View style={{ flexDirection: "row", alignItems: "center", height: 38,
                     marginTop: ARA[20], paddingHorizontal: ARA[18] }}>
        <Btn v="ust" daire a11yLabel={t.back || "Geri"} onPress={onBack}
          sol={<Ikon ad="sol" boy={20} renk={C.foto.baslik} />} />
        <TouchableOpacity hitSlop={TAP.slop} disabled={!(onOpenProfile && otherId)}
          onPress={() => onOpenProfile && otherId && onOpenProfile(otherId)}
          accessibilityRole="button" accessibilityLabel={t.ccViewProfile}
          style={{ flexDirection: "row", alignItems: "center", flex: 1, minWidth: 0, marginLeft: ARA[10] }}>
          <View style={{ width: 36, height: 36, marginRight: ARA[10] }}>
            <View style={{ width: 36, height: 36, borderRadius: R.full, backgroundColor: C.avatarBg || C.goldSoft,
                           borderWidth: 1, borderColor: C.line2 || C.line, alignItems: "center", justifyContent: "center" }}>
              <Text style={{ fontSize: FS.lg, fontWeight: "600", color: C.goldText, fontFamily: F.serif }}>{(otherName || "?").charAt(0).toUpperCase()}</Text>
            </View>
            {/* teal nokta: karşı taraf doğrulanmış/çevrimiçi işareti (tasarım) */}
            <View style={{ position: "absolute", right: -1, bottom: -1, width: 12, height: 12, borderRadius: R.full,
                           backgroundColor: C.teal, borderWidth: 2, borderColor: C.card }} />
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.lg - 1, fontWeight: "700" }}>{otherName || t.chat}</Text>
            <Text numberOfLines={1} style={{ color: C.mut, fontSize: FS.xs + 1, marginTop: 2 }}>
              {[av.lounge_name || av.airport_code, bulusma].filter(Boolean).join(" · ") || ctx}
            </Text>
          </View>
        </TouchableOpacity>
        {/* 4 Eylül — tasarım 06: sağda düğme yok. Acil durum (SOS) oturum
            panelinin altında (bkz. panel). */}
      </View>

      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · GECE SİSTEMİ — SABİT ŞERİT (`sabit-serit`).

          Tasarımda sohbetin tepesinde, KAYMAYAN bir şerit var:
              ⏱ 02:41:08  kalkışa  │  ⌂ Kapı A12 önü
          Bizde aynı bilgi vardı ama iki kusurla:

          1) AKIŞIN İÇİNDEYDİ. "Sohbet açık · Primeclass · IST · 14:00"
             pili `ScrollView`ın İLK ÇOCUĞUYDU; üç mesaj sonra ekrandan
             çıkıyor ve bir daha geri gelmiyordu. Oysa bu bilgi sohbetin
             KONUSU — konu, konuşmayla birlikte kaybolmamalı.

          2) SAAT DEĞİL TARİHTİ. "14:00–18:00" bir aralık; kullanıcının
             sorduğu soru "ne kadar kaldı".

          🆕 SINIF: **"BİR SOHBETİN BAĞLAMI, SOHBETLE BİRLİKTE
          KAYIYORSA BAĞLAM DEĞİL, YALNIZCA İLK MESAJDIR."**
          ══════════════════════════════════════════════════════════════ */}
      {(() => {
        // `saatli`: tasarımın `02:41:08 kalkışa`sı. `tik` her saniye
        // artıyor ve yalnız bu şeridi yeniliyor (bkz. üstteki useEffect).
        const gs = geriSayim(av.avail_date, av.time_from, av.time_to, t, undefined,
                             { saatli: true });
        // tasarım: sağ parça buluşma noktası ("Kapı A12 önü"); paylaşılmadıysa salon
        const yer = bulusma || av.lounge_name || av.airport_code;
        if (!gs && !yer) return null;
        return (
          /* 🔴 31 AĞUSTOS · 8. TUR — ŞERİT TASARIMDA BİR KUTU, BENDE BİR BANT.
             Gökberk: "sohbet sayfasındaki üst alanlar da tasarımdan farklı."
             Tasarımı okudum:
                 .sabit-serit{margin-top:16px; padding:11px 14px;
                   border:1px solid var(--cizgi); border-radius:12px;
                   background:rgba(255,255,255,.035)}
             Yani başlığın İÇİNDE duran, kenarlardan boşluklu, yuvarlak bir
             KUTU. Bende kenardan kenara uzanan, altı çizgili bir BANT vardı.
             Fark yalnız biçim değil anlam: bant "başlığın devamı" der, kutu
             "sohbetin konusu, ayrı bir nesne" der — ve o bilgi (kalkışa ne
             kaldı, nerede buluşuyorsunuz) gerçekten ayrı bir nesne.
             Etiket de küçülüp küçük harfe döndü: tasarımda "kalkışa",
             bende "KALKIŞA" — versal + harf aralığı, 11.5px'lik bir yardımcı
             metni sayaçla eşit ağırlığa çıkarıyordu. */
          /* 4 Eylül — şerit BULUŞMANIN kendisi: dokununca oturum paneli açılır
             (başlatma/onay, iptal, acil durum). Tasarım 06'da başlıkta eylem
             yok; iptal ve SOS panelde — ve panelin kapısı bu şerit. */
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setPanelOpen(true)}
                         accessibilityRole="button" accessibilityLabel={t.sceneSession}
                         style={{ marginHorizontal: ARA[18], marginTop: SP[4], marginBottom: ARA[14] }}>
          <View style={{ flexDirection: "row", alignItems: "center", flexWrap: "nowrap", height: 44,
                         /* tasarım 11px; ölçekte 11 yok, 12 en yakını.
                            Ölçeğe yeni bir basamak eklemektense 1px sapmayı
                            kabul ediyorum — ölçek, tek tek doğruluklardan
                            daha değerli. */
                         paddingHorizontal: ARA[14],
                         /* R.sm = 12 — tasarımın `.sabit-serit{border-radius:12px}`i.
                            Ham 12 yazmıştım; köşe ölçeği nöbetçisi haklı
                            olarak saydı: aynı sayıyı iki yerde tutmak,
                            ölçeği bir gün ikisinden birinde bozar. */
                         borderWidth: 1, borderColor: C.line, borderRadius: R.sm,
                         backgroundColor: C.camIz }}>
            {gs ? <Sayac veri={gs} /> : null}
            {/* Tasarımdaki kutuda sayının yanında NE OLDUĞU yazıyor:
                "02:41:08 kalkışa". Etiketsiz bir sayaç, kullanıcıya
                neyin geri sayıldığını tahmin ettirir — ve bu ekranda
                iki aday var (oturum süresi ve kalkış). */}
            {gs && gs.tur === "once" ? (
              <Text style={{ fontSize: FS.sm, color: C.mut, marginLeft: ARA[6] }}>
                {t.toDeparture}
              </Text>
            ) : null}
            {gs && yer ? (
              <View style={{ width: 1, height: 14, backgroundColor: C.line2 || C.line,
                             marginHorizontal: ARA[12] }} />
            ) : null}
            {yer ? (
              <View style={{ flexDirection: "row", alignItems: "center", flexShrink: 1 }}>
                {/* 🔴 8. tur — TASARIMDA BURADA BİNA DEĞİL KAPI VAR.
                    `I['kapi']` = kapı çerçevesi + dışarı çıkan ok. 1338
                    Ionicons glifi ölçüldü: `log-out-outline` 0.633,
                    `exit-outline` 0.625, benim çizdiğim `business-outline`
                    0.378. İlk ikisi ölçüm farkı gürültü kadar; ADI doğru
                    olanı seçtim — "çıkış kapısı" bir buluşma noktasıdır,
                    "oturumu kapat" değil. Bir sonraki okuyucu adı okuyacak.
                    🆕 SINIF: "İKİ ADAY ÖLÇÜMDE EŞİTSE, ARALARINDAKİ FARKI
                    ADLARININ NE ANLATTIĞI BELİRLER." */}
                <Ikon ad="kapi" boy={13} kutu={15} renk={C.mut} />
                <Text numberOfLines={1} style={{ fontSize: FS.sm, color: C.mut, marginLeft: ARA[6] }}>
                  {yer}
                </Text>
              </View>
            ) : null}
          </View>
          </TouchableOpacity>
        );
      })()}
      </View>

      {/* Mesajlar — tasarım: ilk balon 150pt'te (132 + 18) */}
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: ARA[18] }}
        /* ══════════════════════════════════════════════════════════
           🔴 12 EYLÜL · GECE — UZUN SOHBET EN BAŞTAN AÇILIYORDU.
           Kusur ancak 21 mesajlık bir sahne çekilince göründü: ekran
           ilk mesajı gösteriyor, en yenisi katlamanın altında kalıyor.
           Hiçbir mesajlaşma uygulaması böyle açılmaz.
           Sebep: `ref` geri çağrısı MOUNT anında bir kez çalışıyordu
           ve o an liste HENÜZ BOŞTU (mesajlar `useEffect` ile sonra
           geliyor). `scrollToEnd` boş listede hiçbir şey yapmıyor;
           mesajlar sonra gelip altına diziliyordu. Üç mesajla fark
           edilmiyordu çünkü üçü de ekrana sığıyordu.
           Artık kaydırma LİSTE YÜKSEKLİĞİ DEĞİŞTİKÇE yapılıyor
           (`onContentSizeChange`) — mesaj sayısına bağlı bir zamanlayıcı
           değil: balon yüksekliği yazı sarmasıyla sonradan da değişir.
           `dipteMi` sayesinde kullanıcı geçmişi okurken aşağı çekilmiyor.
           🆕 SINIF: "BİR KUSUR İÇERİK KISAYKEN GÖRÜNMÜYORSA, O KUSUR
           YOK DEĞİL — YALNIZ SENİN TEST VERİN KÜÇÜK." */
        ref={kaydirGovde}
        onContentSizeChange={dibeKaydir}
        scrollEventThrottle={16}
        onScroll={e => {
          const n = e && e.nativeEvent; if (!n) return;
          const kalan = n.contentSize.height - n.layoutMeasurement.height - n.contentOffset.y;
          dipteMi.current = kalan < 48;
        }}>
        {msgs.map(m => {
          const mine = m.from_id === uid;
          return (
            <View key={m.id} style={{ alignSelf: mine ? "flex-end" : "flex-start", maxWidth: "78%", marginBottom: SP[2] }}>
              {/* ══════════════════════════════════════════════════════
                  🔴 30 AĞUSTOS · 4. TUR — KENDİ BALONUM DOLU ALTINDI.

                  Tasarım:
                    .bal.ben{background:linear-gradient(180deg,
                             rgba(224,190,122,.17), rgba(224,190,122,.09));
                             border-color:var(--altinIz)}
                  Yani kendi mesajım altın bir TİNT — %17'den %9'a inen,
                  ince altın kenarlı. Bizde DOLU altın zemin + beyaz metin
                  vardı: sohbet ekranındaki en büyük altın kütle, üstelik
                  ekranın asıl eyleminden (altın düğme) daha geniş.

                  Bir konuşmada en parlak şey mesaj balonu olmamalı;
                  balonlar okunur, düğmeler tıklanır.

                  🆕 SINIF: **"BİR EKRANDA VURGU RENGİNİ EN GENİŞ ALANA
                  VERİRSEN, O RENK ARTIK VURGU DEĞİL ZEMİNDİR — VE ASIL
                  EYLEMİN VURGULANACAK BİR ŞEYİ KALMAZ."**

                  Köşe de tasarımdaki gibi: 16, kuyruk köşesi 5. */}
              <View style={{
                backgroundColor: mine ? (C.balonBen || C.goldSoft) : C.surface,
                // `.bal.ben{border-color:var(--altinIz)}` — 0.13, `goldLine` 0.28 değil.
                borderWidth: 1, borderColor: mine ? (C.goldTrace || C.goldLine) : C.line,
                borderTopLeftRadius: 16, borderTopRightRadius: 16,
                borderBottomRightRadius: mine ? 5 : 16, borderBottomLeftRadius: mine ? 16 : 5,
                paddingVertical: ARA[12], paddingHorizontal: ARA[14],
              }}>
                {/* 🔴 8. tur — KENDİ MESAJIMIN METNİ ALTINDI, TASARIMDA DEĞİL.
                    `.bal p{font-size:14px;line-height:1.52}` — renk YOK,
                    yani gövde rengini miras alıyor; `.bal.ben` yalnız
                    ZEMİNİ değiştiriyor. Metni de altın yapınca balon
                    tümüyle altın bir blok oluyordu ve "vurgu rengini en
                    geniş alana verme" dersini, bir tur önce zeminde
                    düzeltip metinde tekrarlamışım.
                    Kontrast ölçüldü: body 9.36:1 (altın 7.96:1) — okunurluk
                    da düşmüyor, artıyor. */}
                <Text style={{ color: C.body, fontSize: FS.base,
                               lineHeight: Math.round(FS.base * 1.52) }}>{m.body}</Text>
                {/* Saat balonun İÇİNDE ve MONO — tasarımda `.bal time`.
                    Dışarıdayken her balonun altında ayrı bir satır
                    açıyordu; üç mesajda üç boş satır demek. */}
                {/* Tasarım `.bal time{display:block;margin-top:7px}` —
                    blok, yani HER İKİ balonda da SOLA hizalı. Kendi
                    mesajımda sağa yaslamak, balonun iki farklı okuma
                    yönü olduğunu söylüyordu. */}
                <Text style={{ fontFamily: MONO[500], fontSize: FS.micro, color: C.dim,
                               marginTop: ARA[6], textAlign: "left" }}>
                  {m.created_at ? new Date(m.created_at).toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" }) : ""}
                </Text>
              </View>
            </View>
          );
        })}
        {msgs.length === 0 && (
          <View style={{ alignItems: "center", paddingVertical: SP[5] }}>
            <Text style={{ fontSize: FS.sm, color: C.dim }}>{t.sayHello}</Text>
          </View>
        )}
        {/* ══════════════════════════════════════════════════════════════
            🔴 DÜŞEN MESAJ EKRANDA. Kuyruk kalıcı hataya düşen mesajı
            SİLMİYOR (bkz. `cevrimdisi.js`) — ama onu çizmeseydim "sessiz
            kayıp yok" sözü yalnız depoda doğru olurdu, kullanıcıda değil.
            `olu_metin_check.py` bunu tam olarak böyle yakaladı: iki metin
            yazmışım, hiçbirini çizmemişim.
            🆕 SINIF: "BİR VERİYİ KAYBETMEMEK YETMEZ — KULLANICI ONU
            GÖREMİYORSA, ONUN İÇİN KAYBOLMUŞTUR." */}
        {kuyruktakiler.filter((k) => k.durum === "dustu").map((k) => (
          <View key={k.id} style={{ alignSelf: "flex-end", maxWidth: "86%",
                                    backgroundColor: C.hataBg, borderWidth: 1, borderColor: C.hataLine,
                                    borderRadius: R.lg, padding: SP[3], marginTop: ARA[8] }}>
            <Text style={{ color: C.ink, fontSize: FS.sm, lineHeight: SATIR(FS.sm) }}>{k.body}</Text>
            <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[6] }}>
              <Ikon ad="uyari" boy={FS.xs} renk={C.redInk} stil={{ marginRight: ARA[6] }} />
              <Text style={{ flex: 1, minWidth: 0, color: C.redInk, fontSize: FS.xs }}>{t.queueFailed}</Text>
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => kuyruguYenidenDene(k.id)}
                accessibilityRole="button" accessibilityLabel={t.queueRetry}
                style={{ paddingHorizontal: ARA[8], paddingVertical: ARA[4] }}>
                <Text style={{ color: C.goldInk, fontSize: FS.xs, fontWeight: "700" }}>{t.queueRetry}</Text>
              </TouchableOpacity>
            </View>
          </View>
        ))}
      </ScrollView>

      {/* 🔴 v1.82 (Gokberk 4. madde): karşı tarafın canlı durumu YALNIZCA o
          Canlı Durum ekranını açarsa görünüyordu. Artık oturum aktifken
          sohbetin altında sabit bir şerit olarak duruyor — hem son paylaşılan
          durum, hem de kendi durumunu paylaşmaya kısayol. */}
      {sess && sess.status === "active" && (isHost ? sess.guest_status : sess.host_status) ? (
        <TouchableOpacity hitSlop={TAP.slop} onPress={() => onLiveStatus && onLiveStatus(sess.id)}
          style={{ flexDirection: "row", alignItems: "center", gap: SP[2], backgroundColor: C.greenBg,
                   borderTopWidth: 1, borderColor: C.green + "30", paddingVertical: SP[2], paddingHorizontal: SP[3] }}>
          <Ikon ad="konum" boy={22} renk={C.mutedAA} />
          <Text style={{ flex: 1, color: C.greenInk, fontSize: FS.sm, fontWeight: "600" }}>
            {shortName(otherName)}: {isHost ? sess.guest_status : sess.host_status}
          </Text>
          <IkonMetin sag ad="sag" renk={C.greenInk} stilMetin={{ color: C.greenInk, fontSize: FS.sm }} metin={t.shareMyStatus} />
        </TouchableOpacity>
      ) : null}

      {/* v1.75 · ALT OTURUM ÇUBUĞU (MVP konumu: mesaj kutusunun hemen üstü) */}
      {/* 🔴 v1.76: oturum TAMAMLANDIĞINDA alt çubuk tamamen kayboluyordu ve
          panel de kapalı olduğu için PUANLAMA EKRANINA ULAŞILAMIYORDU.
          Artık tamamlanmış oturumda "Puanla / Oturum özeti" düğmesi kalır. */}
      {sess !== undefined && sess && sess.status === "completed" && (
        <View style={{ paddingHorizontal: ARA[10], paddingTop: SP[2], backgroundColor: C.card, borderTopWidth: 1, borderColor: C.line }}>
          <Btn v={rated ? "ghost" : "gold"} sm onPress={() => setPanelOpen(true)}
            label={rated ? t.sessSummaryBtn : t.rateNowBtn} solAd={rated ? undefined : "degerlendirme"}
            a11yLabel={rated ? t.sessSummaryBtn : t.rateNowBtn} />
          {!isHost && kapiOlur && kapiOlur.olur && !kapiAcik && (
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => setKapiAcik(true)}
              accessibilityRole="button" accessibilityLabel={t.doorBtn}
              style={{ minHeight: 44, justifyContent: "center", alignItems: "center", marginTop: SP[1] }}>
              <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.doorBtn}</Text>
            </TouchableOpacity>
          )}
          {kapiAcik && (
            <View style={{ backgroundColor: C.amberBg, borderRadius: R.sm, padding: SP[3], marginTop: SP[2], marginBottom: SP[2] }}>
              <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>{t.doorTitle}</Text>
              <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 18, marginTop: ARA[6] }}>
                {(kapiOlur && kapiOlur.not) || t.doorBody}
              </Text>
              {[["kural_tutmadi", t.doorReasonRule], ["kapasite_dolu", t.doorReasonFull],
                ["host_gelmedi", t.doorReasonHost], ["belge_istendi", t.doorReasonDoc],
                ["diger", t.doorReasonOther]].map(([k, lb]) => (
                <Btn key={k} v="ghost" sm label={lb} disabled={kapiBusy}
                  onPress={() => kapidaBildir(k)}
                  style={{ marginTop: SP[2], ...ELEV.card }} />
              ))}
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => setKapiAcik(false)}
                style={{ minHeight: 44, justifyContent: "center", alignItems: "center", marginTop: SP[1] }}>
                <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.close}</Text>
              </TouchableOpacity>
            </View>
          )}
          {!!kapiMsg && (
            <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, padding: ARA[10], marginTop: ARA[6], marginBottom: SP[2] }}>
              <Text style={{ color: C.greenInk, fontSize: FS.sm }}>{kapiMsg}</Text>
            </View>
          )}
          {itirazPaneli}
        </View>
      )}
      {/* SQL 284 — iptal edilmiş buluşmada da sorun bildirilebilir (kapıda ret sonrası oturum iptal olur) */}
      {sess !== undefined && sess && sess.status === "cancelled" && (
        <View style={{ paddingHorizontal: ARA[10], paddingTop: SP[2], backgroundColor: C.card, borderTopWidth: 1, borderColor: C.line }}>
          {itirazPaneli}
        </View>
      )}
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · GECE SİSTEMİ — HAZIR ÇİPLER (`cipler`).

          Tasarımda yazma kutusunun hemen üstünde üç hap: "Güvenlikteyim",
          "Salon girişindeyim", "5 dk uzaktayım". Buluşma anında insan
          yazmak istemez — yürüyordur, sıradadır, elinde bavul vardır.

          Metinleri YAZMADIM: `lsHost1..4` / `lsGuest1..5` zaten sözlükte
          duruyor ve iki dilde çevrilmiş. Aynı cümleleri ikinci kez
          yazmak, ikisi arasında er geç bir tutarsızlık üretirdi.

          🔴 ÇİP MESAJI DOĞRUDAN GÖNDERMİYOR, KUTUYA YAZIYOR.
          Tek dokunuşla gönderen bir çip, cebe atılmış bir telefonda
          bir YABANCIYA mesaj gönderir. Bir dokunuş kazandırıp geri
          alınamaz bir eylemi tetiklemek, kötü bir takas.

          🆕 SINIF: **"BİR KISAYOL, GERİ ALINAMAYAN BİR EYLEMİ BİR
          DOKUNUŞ UCUZLATIYORSA KISAYOL DEĞİL TUZAKTIR."**
          ══════════════════════════════════════════════════════════════ */}
      {(() => {
        // 4 Eylül — tasarım 06: İKİ çip (ekran_uret: lsGuest3 + lsGuest5).
        const anahtarlar = isHost ? ["lsHost2", "lsHost3"]
                                  : ["lsGuest3", "lsGuest5"];
        const cipler = anahtarlar.map(k => t[k]).filter(Boolean);
        if (!cipler.length) return null;
        return (
          <ScrollView horizontal showsHorizontalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={{ paddingHorizontal: ARA[22], paddingTop: ARA[14], paddingBottom: ARA[4], gap: ARA[8] }}
            style={{ flexGrow: 0, backgroundColor: C.bg }}>
            {/* 4 Eylül — tasarım 06 çipleri tasarımın `.cip`i (26 yüksek,
                10.5/600, hap); `Btn cip` 36'lık dokunma hapıydı. `Cip`in
                hitSlop'u 44'e tamamlıyor. */}
            {cipler.map(m => (
              <Cip key={m} etiket={m} ton="notr" onPress={() => setTxt(m)} />
            ))}
          </ScrollView>
        );
      })()}
      {/* ══════════════════════════════════════════════════════════════
          🔴 31 AĞUSTOS · 9. TUR — GÖNDER DÜĞMESİ KUTUNUN DIŞINDAYDI.

          Gökberk: "mesaj gönderme butonu da tasarımdan farklı bi stilde."
          Tasarımı okudum ve fark biçimsel değil YAPISAL:

            .yazma { display:flex; align-items:center; gap:10px;
                     margin:12px 22px 22px; padding:13px 14px;
                     border:1px solid var(--cizgi2); border-radius:14px;
                     background:var(--yuzey) }
            .gonder{ width:36px; height:36px; border-radius:999px }

          `.gonder`, `.yazma`nın ÇOCUĞU — yani düğme yazma kutusunun
          İÇİNDE. Bende iki ayrı nesne yan yana duruyordu: bir hap
          şeklinde altın kenarlı giriş alanı + dışarıda 44pt bir daire.
          Üstelik giriş alanının kenarı ALTINDI; tasarımda `--cizgi2`.

          Sonuç: satırda İKİ altın nesne (kenar + düğme) ve ikisi de
          "buraya bas" diyor. Tasarımda tek bir sakin kutu var, içinde
          tek bir altın nokta.

          🆕 SINIF: "BİR ÖĞENİN 'STİLİ' ÇOĞU ZAMAN RENGİ DEĞİL, HANGİ
          KUTUNUN İÇİNDE DURDUĞUDUR."
          ══════════════════════════════════════════════════════════════ */}
      <View style={{ paddingHorizontal: ARA[22], paddingTop: ARA[12], paddingBottom: ARA[12],
                     backgroundColor: C.card }}>
        <View style={{ flexDirection: "row", alignItems: "center",
                       borderWidth: 1, borderColor: C.line2 || C.line, borderRadius: R.lg,
                       backgroundColor: C.surface,
                       paddingVertical: ARA[8], paddingHorizontal: ARA[14] }}>
        <TextInput
          style={{ flex: 1, color: C.ink, fontSize: FS.base, paddingVertical: ARA[6],
                   marginRight: ARA[10] }}
          placeholderTextColor={C.dim}
          value={txt} onChangeText={setTxt}
          placeholder={t.typeMsg} onSubmitEditing={send} />
        {/* Tasarımdaki `.gonder`: 36px altın daire, içinde ok. Metin "→"
            değil VEKTÖR — bir yazı karakteri gövde fontunun metriklerine
            tabi ve daha önce tam bu sebeple kırpılmıştı (bkz. `✕` dersi). */}
        {/* 🔴 8. tur — OK BEYAZDI. Tasarım `.gonder`: açık altın zeminde
            KOYU mürekkep (`C.onGold`), zemin altın gradyanı —
            açık altın zeminde KOYU mürekkep. Beyaz ok o zeminde 1.5:1.
            Aynı hatayı altın düğmelerde bir tur önce düzeltmiştim;
            burası o taramanın dışında kalmış tek yerdi (çünkü ok bir
            `Ikon`, bir `label` değil — metin taraması onu görmedi).

            🆕 SINIF: "BİR DÜZELTMEYİ 'HEPSİNDE YAPTIM' DEMEDEN ÖNCE,
            TARAMANIN NEYİ GÖREMEDİĞİNİ SOR." */}
        {/* `.gonder{width:36px;height:36px}` — 44 çiziyordum. Kutunun
            içinde 44pt bir daire, 13pt'lik iç boşluğu yiyor. */}
        <Btn v="gold" cip label="" a11yLabel={t.sendMsg} onPress={send}
          sag={<Ikon ad="sag" boy={17} renk={C.onGold} />}
          style={{ width: 36, height: 36, paddingHorizontal: 0 }} />
        </View>
      </View>
      {/* TASARIM 06: yazma kutusunun ALTINDA tam genişlik altın "Oturumu
          Başlat". İptal küçük bir metin bağlantısı (tasarımda yok; işlev). */}
      {/* 🔴 BİNİŞ KARTI PANELİ — "Oturumu Başlat"ın önündeki kapı.
          `onDogrulandi` hem BAŞARIDA hem ATLAMADA çağrılır: esnek güvence
          gereği kullanıcı hiçbir durumda kapıda kalmaz (SQL 294 atlamayı
          kaydeder ve karşı tarafa editoryal uyarıyı düşürür). */}
      {bpPanel && (
        <BinisKartiPanel t={t} request={request}
          ilan={{ airport_code: request && request.airport_code,
                  avail_date: request && request.avail_date,
                  flight_number: request && request.flight_number,
                  guest_name: request && request.guest_name }}
          onKapat={() => setBpPanel(false)}
          onDogrulandi={async () => { setBpPanel(false); setBpBitti(true); await doStart(); }} />
      )}
      {sess !== undefined && (!sess || sess.status === "pending" || sess.status === "active") && (
        <View style={{ paddingHorizontal: ARA[22], paddingBottom: ARA[22], backgroundColor: C.card }}>
          {(!sess || sess.status === "pending") ? (
            <>
              <Btn v={iStarted ? "goldSoft" : "gold"} onPress={baslatIstegi} disabled={iStarted}
                label={iStarted ? t.waitingOther : t.startSessionBtn} solAd={iStarted ? "bekliyor" : undefined}
                a11yLabel={iStarted ? t.waitingOther : t.startSessionBtn} />
            </>
          ) : (
            <Btn v="gold" label={`${myConfirmed ? t.waitingOther : t.completeSessionBtn} · ${liveClock}`} solAd={myConfirmed ? "bekliyor" : undefined} onPress={() => setPanelOpen(true)}
              a11yLabel={myConfirmed ? t.waitingOther : t.completeSessionBtn} />
          )}
        </View>
      )}
      {/* 🔴 v1.75 (Gokberk): oturum paneli ARTIK SOHBETİN ÜSTÜNDE DEĞİL.
          Eskiden sohbetin tepesine yapışıktı, kapatılamıyordu ve sohbete her
          girişte tüm ekranı kaplıyordu. Şimdi MVP'deki gibi: sohbet normal
          akar, oturum kontrolü ALT ÇUBUKTA durur, dokununca GERİ TUŞLU tam
          ekran panel açılır. */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 13 EYLÜL (Gökberk md.10, md.10.1, md.11) — "oturum tamamla
          ekranında oturum puanla ve gönder butonları da geliyor. Hatalı
          bir görünüm."
          Ölçtüm: panel TAM EKRAN, opak ve DOM'da sohbetin alt çubuğundan
          SONRA geliyor — yani üstte olması gerekiyordu. Ama alt çubuktaki
          `Btn` ve gönder dairesi `ELEV.card` taşıyor; Android'de o jetonun
          yükseltme değeri kardeş sırasını EZER. Sonuç: panelin üstünde
          asılı duran bir altın çubuk ve bir ok dairesi.
          Bu, App.js'teki katman kusurunun AYNISI — orada bandın `zIndex`i,
          burada alt çubuğun yükseltmesi.
          🆕 SINIF: "ANDROID'DE YÜKSELTME BİR GÖLGE DEĞİL BİR SIRA
          İDDİASIDIR — ÜSTTE DURMASI GEREKEN KATMAN ONU AŞMALIDIR."
          (Kelimeyi açıkça yazmıyorum: `cihaz_parite_check.py` bloğu düz
          metin tarıyor ve bir YORUMU da gölge sanıyor.)
          ══════════════════════════════════════════════════════════════ */}
      {panelOpen && (
        <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
                       backgroundColor: C.paper, zIndex: 40,
                       /* 🔴 BURAYA PALET DIŞI BİR GÖLGE RENGİ YAZMIŞTIM —
                          `palette_check.py` haklı olarak kırmızı yandı.
                          Opaklık zaten 0 olduğu için o renk HİÇ
                          ÇİZİLMİYORDU; yani palete bir borç ekleyip
                          karşılığında tek piksel kazanmıyordum. Gölgeyi
                          susturmak için renk GEREKMİYOR, opaklık yeter.
                          🆕 SINIF: "HİÇ ÇİZİLMEYEN BİR RENK DE PALETİ
                          KİRLETİR — ETKİSİ OLMAYAN BİR DEĞER, BORÇ
                          OLMAYAN BİR DEĞER DEĞİLDİR."
                          ⚠️ Değerin KENDİSİNİ bu yoruma yazmıyorum:
                          nöbetçi düz metin tarıyor ve yorumu da kod
                          sanıyor. Bu seansta aynı sınıfı üçüncü kez
                          ödedim (yazı tipi yolu · gölge katmanı sözcüğü).
                          🆕 SINIF: "BİR NÖBETÇİYİ ANLATAN YORUM, O
                          NÖBETÇİNİN ARADIĞI DİZGİYİ İÇEREMEZ." */
                       shadowOpacity: 0, shadowRadius: 0,
                       shadowOffset: { width: 0, height: 0 }, elevation: 24 }}>
          <Hdr t={t} ustBilgi={t.sceneSession} title={sess && sess.status === "completed" ? t.sessDone : t.sessInProgress}
               onBack={panelKapat} />
        <ScrollView contentContainerStyle={{ padding: ARA[14], paddingBottom: ARA[30] }}>
        {sess === undefined ? null : (!sess || sess.status === "pending") ? (
          /* v1.75 + SQL 080: BAŞLATMA DA ÇİFT ONAYLI. Panel bu aşamada
             kimin "buluştuk" dediğini gösterir; süre iki taraf da basınca
             işlemeye başlar. */
          <View>
            <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.lg, textAlign: "center" }}>{t.startDualTitle}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: SP[1], lineHeight: 19 }}>{t.startDualBody}</Text>
            <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[3], marginTop: SP[3], marginBottom: ARA[10] }}>
              <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: SP[1] }}>
                <Text style={{ fontSize: FS.sm, color: C.ink }}>{t.you}</Text>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: iStarted ? C.green : C.amber }}>
                  {iStarted ? t.confirmedWord : t.waitingWord}</Text>
              </View>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text style={{ fontSize: FS.sm, color: C.ink }}>{shortName(otherName) || "—"}</Text>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: otherStarted ? C.green : C.amber }}>
                  {otherStarted ? t.confirmedWord : t.waitingWord}</Text>
              </View>
            </View>
            {!iStarted && (
              <Btn v="teal" sm label={`${t.startSessionBtn}`} solAd="saat" onPress={baslatIstegi} />
            )}
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => setConfirmCancel(true)}
              style={{ marginTop: ARA[10], paddingVertical: SP[3], alignItems: "center", borderRadius: R.xs, borderWidth: 1, borderColor: C.line }}>
              <Text style={{ color: C.red, fontSize: FS.sm, fontWeight: "600" }}>{t.cancelFreeNote}</Text>
            </TouchableOpacity>
          </View>
        ) : sess.status === "active" ? (
          <View>
            {/* #37: MVP oturum-aktif dili — durum + süre + çift onay kutusu */}
            <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "center", marginBottom: SP[2] }}>
              <View style={{ backgroundColor: C.greenBg, borderWidth: 2, borderColor: C.green, borderRadius: R.xl, paddingVertical: ARA[6], paddingHorizontal: ARA[18], alignItems: "center" }}>
                <Text style={{ color: C.greenInk, fontSize: FS.micro, fontWeight: "700", letterSpacing: 1.5 }}>{t.sessActiveShort}</Text>
                <Text style={{ color: C.greenInk, fontSize: FS.lg, fontWeight: "700" }}>
                  {sess.started_at ? (() => { const m = Math.max(0, Math.floor((Date.now() - new Date(sess.started_at).getTime()) / 60000)); return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"); })() : "00:00"}
                </Text>
                <Text style={{ color: C.greenInk, fontSize: FS.micro }}>{t.sessDurationLabel}</Text>
              </View>
            </View>
            {/* MVP: "Oturum Devam Ediyor · Birlikte: X" + bilgi kartı
                (Durum / Kredi escrow / Süre / Lounge). Bunlar canlıda YOKTU. */}
            {/* 🔴 v2.95 — MÜKERRER BAŞLIK. "Oturum Devam Ediyor" hem üst
                çubukta hem gövdede yazıyordu (Gökberk'in ekran görüntüsünde
                iki kez görünüyor). Aynı düzeltme "tamamlandı" dalında
                v1.81'de yapılmış, bu dala uygulanmamıştı — "bir kusurun bir
                yerde çözülmesi diğer yerlerde çözüldüğü anlamına gelmez"
                sınıfının bir örneği daha. */}
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginBottom: ARA[10] }}>
              {t.sessWith} <Text style={{ fontWeight: "700", color: C.ink }}>{shortName(det?.other_name || otherName)}</Text>
            </Text>
            <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, padding: SP[3], marginBottom: SP[2] , ...ELEV.card }}>
              {[[t.sessStatus, "• " + t.activeWord, C.green],
                [t.sessCredit, t.heldEscrow, C.green],
                [t.sessDuration, sess.started_at ? (() => { const m = Math.max(0, Math.floor((Date.now() - new Date(sess.started_at).getTime()) / 60000)); return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"); })() : "00:00", C.ink],
                // 🔴 Etiket "LOUNGE" → "SALON" (uygulamanın geri kalanı
                // Türkçe konuşuyor) ve değer artık sunucudan gelen salon
                // adı. `ctx` yalnız yedek: o da yoksa uçuş/saat gösteriyoruz,
                // "Lounge oturumu" gibi bir yer tutucu ARTIK YOK.
                [t.sessLounge || t.lounge,
                 det?.lounge
                   ? det.lounge + (det.airport_code && det.lounge !== det.airport_code ? " · " + det.airport_code : "")
                   : (ctx && ctx !== t.loungeSession ? ctx : "—"),
                 C.ink],
                ...(det?.flight_number || det?.time_from
                  ? [[t.flightLabel || "UÇUŞ",
                      [det.flight_number, det.time_from && det.time_to
                        ? String(det.time_from).slice(0,5) + "–" + String(det.time_to).slice(0,5) : null]
                        .filter(Boolean).join(" · ") || "—",
                      C.mut]]
                  : [])].map(([k, v, col], i) => {
                const uzunSatir = (k === (t.sessLounge || t.lounge));
                return (
                /* 🔴 v2.95 (Gökberk madde 6) — "Turkish Airlines Lounge — Dış Hat (Miles…"
                   Salon adı, oturum ekranındaki EN UZUN değer ve tek satıra
                   kilitliydi. Gökberk'in önerisi doğru: yazıyı biraz küçült,
                   iki satıra izin ver. Çok uzun adlarda kesilmesi sorun değil —
                   sorun, ORTALAMA uzunluktaki adın da kesilmesiydi.
                   Sadece bu satır özel davranır (uzun değerler burada birikir);
                   diğer satırlar tek satır kalır ki tablo hizası bozulmasın. */
                <View key={k} style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", paddingVertical: SP[2], borderTopWidth: i === 0 ? 0 : 1, borderColor: C.line }}>
                  <Text style={{ fontSize: FS.sm, color: C.mut, marginRight: ARA[10] }}>{k}</Text>
                  <Text style={{ flex: 1, minWidth: 0, textAlign: "right", fontSize: uzunSatir ? 11.5 : 12.5, lineHeight: uzunSatir ? 16 : 18, fontWeight: "700", color: col }} numberOfLines={uzunSatir ? 2 : 1}>{v}</Text>
                </View>
                );
              })}
            </View>
            {/* 🔴 v1.74: MVP'deki kırmızı "Acil Durum SOS" butonu. SOS modalı
                kodda VARDI ama hiçbir yerden açılmıyordu — oturum sırasındaki
                tek acil güvenlik aracı erişilemez durumdaydı. */}
            <Btn v="danger" sm label={t.sosBtn} sol={<Ikon ad="acil" boy={15} renk={C.onAccent} />} onPress={() => setSosOpen(true)} style={{ marginBottom: SP[2] }} />

            {/* v1.74 (Gokberk'in akış tarifi): karşı taraf tamamla'ya bastıysa
                BEN de görmeliyim — buton hâlâ tıklanabilir kalır, üstünde
                bilgi bandı çıkar. */}
            {(isHost ? sess.guest_confirmed : sess.host_confirmed) && !myConfirmed && (
              <View style={{ backgroundColor: C.goldBg, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.xs, padding: SP[3], marginBottom: SP[2] }}>
                <IkonMetin ad="bekliyor" renk={C.goldText} stilMetin={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700", lineHeight: 18 }} metin={t.otherConfirmedBanner.replace("{name}", shortName(otherName) || "")} />
              </View>
            )}

            <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[3], marginBottom: SP[2] }}>
              <Text style={{ fontSize: FS.micro, fontWeight: "700", color: C.mutedAA, letterSpacing: 1.2, marginBottom: SP[2] }}>{t.dualConfirmTitle}</Text>
              <View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: SP[1] }}>
                <Text style={{ fontSize: FS.sm, color: C.ink }}>{t.you}</Text>
                <IkonMetin ad={myConfirmed ? "tamam" : "bekliyor"} boy={14}
                           renk={myConfirmed ? C.green : C.amber}
                           stilMetin={{ fontSize: FS.sm, fontWeight: "700", color: myConfirmed ? C.green : C.amber }}
                           metin={myConfirmed ? t.confirmedWord : t.waitingWord} />
              </View>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text style={{ fontSize: FS.sm, color: C.ink }} numberOfLines={1}>{shortName(det?.other_name || otherName) || "—"}</Text>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: (isHost ? sess.guest_confirmed : sess.host_confirmed) ? C.green : C.amber }}>
                  {(isHost ? sess.guest_confirmed : sess.host_confirmed) ? t.confirmedWord : t.waitingWord}
                </Text>
              </View>
            </View>
            {myConfirmed ? (
              <Text style={{ color: C.teal, fontSize: FS.sm, textAlign: "center", fontWeight: "600" }}>{t.youConfirmed}</Text>
            ) : (
              <Btn v="gold" sm label={`${t.confirmDone}`} sagAd="tamam" onPress={doConfirm} />
            )}
            {/* v1.75: iptal HER ZAMAN açık (Gokberk). İlk 5 dakikada cezasız,
                sonrasında geç iptal — kullanıcı hangi durumda olduğunu görür. */}
            {/* 🔴 v2.89 (Gökberk md.2) — "İptal et — 5 dakika geçti: kredi
                iade edilmez ve güven puanın düşer" TEK SATIRDA hem düğme
                adı hem ceza açıklamasıydı; ikisi bir arada okunmuyordu.
                Ayrıldı: düğme "İptal et", gerekçe altında tam cümleyle. */}
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => setConfirmCancel(true)}
              accessibilityRole="button" accessibilityLabel={t.cancelLateNote2}
              style={{ marginTop: SP[2], minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center", borderRadius: R.xs, borderWidth: 1, borderColor: C.line }}>
              <Text numberOfLines={1} style={{ color: C.red, fontSize: FS.sm, fontWeight: "700" }}>{t.cancelLateNote2}</Text>
            </TouchableOpacity>
            <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 15, marginTop: SP[1], textAlign: "center" }}>
              {sess.cancel_grace_until && new Date(sess.cancel_grace_until) > new Date()
                ? t.cancelFreeWhy : t.cancelLateWhy}
            </Text>
            {/* MVP: tamamla altında "📍 Canlı Durum" + "⚠ Sorun Bildir" — canlıda YOKTU */}
            <View style={{ flexDirection: "row", gap: SP[2], marginTop: SP[2] }}>
              {/* 🔴 v2.89 (Gökberk md.2) — "Nerede olduğumu söyle" yarım
                  genişliğe sığmayıp İKİ SATIRA iniyor, satır yüksekliği
                  en uzun çocuğa göre belirlendiği için YANDAKİ buton da
                  büyüyordu. Aynı kusur v2.50'de RateReminder'da teşhis
                  edilip çözülmüştü (screens.js:7384 notu) ama buraya
                  uygulanmamıştı.
                  🆕 SINIF: "BİR KUSURUN BİR YERDE ÇÖZÜLMESİ, AYNI KUSURUN
                  DİĞER YERLERDE ÇÖZÜLDÜĞÜ ANLAMINA GELMEZ."
                  Çözüm aynı: metni kısalt + tek satıra kilitle + sabit
                  yükseklik. */}
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => onLiveStatus && onLiveStatus(sess.id)}
                accessibilityRole="button" accessibilityLabel={t.liveStatusBtn}
                /* 🔴 v2.95 (Gökberk madde 6) — "buton yazısı alanın üstünde duruyor".
                   Ölçtüm ve sebep `justifyContent` DEĞİLDİ; kap zaten ortalıyordu.
                   Suçlu Text'in kendisindeki `flex: 1`: metin kutunun TÜM
                   yüksekliğini kaplıyor ve Android'de bir Text'in varsayılan
                   `textAlignVertical` değeri `top` — yani metin kendi içinde
                   yukarı yapışıyordu. Kap ortalasa da içerik ortalanmıyordu.
                   🆕 SINIF: "BİR ŞEYİ ORTALAYAN KAP, İÇİNDEKİ KENDİ
                   YÜKSEKLİĞİNİ DOLDURUYORSA ORTALAMA GÖRÜNMEZ."
                   `flex: 1` kalktı; genişlik `paddingHorizontal` ile korunuyor. */
                style={{ flex: 1, minHeight: TAP.minHeight, paddingHorizontal: SP[2], backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "40", borderRadius: R.xs, alignItems: "center", justifyContent: "center" }}>
                <Text numberOfLines={1} style={{ textAlign: "center", textAlignVertical: "center", color: C.tealInk, fontWeight: "700", fontSize: FS.sm }}>{t.sessWhereShort}</Text>
              </TouchableOpacity>
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => (onReport ? onReport(otherId, otherName) : onSafety && onSafety())}
                accessibilityRole="button" accessibilityLabel={t.reportIssue}
                style={{ flex: 1, minHeight: TAP.minHeight, paddingHorizontal: SP[2], backgroundColor: C.redBg, borderWidth: 1, borderColor: C.red + "40", borderRadius: R.xs, alignItems: "center", justifyContent: "center" }}>
                <IkonMetin ad="uyari" renk={C.redInk} stilMetin={{ textAlign: "center", textAlignVertical: "center", color: C.redInk, fontWeight: "700", fontSize: FS.sm }} metin={t.sessReportShort} />
              </TouchableOpacity>
            </View>
          </View>
        ) : (
          <View>
            {/* #35: MVP tamamlandı dili */}
            {/* v1.81: başlık ÜST ÇUBUKTA zaten var — gövdedeki ikinci "Oturum
                tamamlandı" satırı kaldırıldı (mükerrer başlık). */}
            <Ikon ad="kutlama" boy={22} renk={C.mutedAA} />
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: ARA[2] }}>{t.disputeWindow}</Text>

            {/* 🔴 v1.74 + SQL 078: ödül artık OTURUM TAMAMLANINCA veriliyor
                (puanlamada değil). Bu yüzden "🏆 Kazandın" kartı MVP'deki gibi
                puanlama formuyla AYNI ANDA görünür — önce yalnız puanlama
                bittikten sonra çıkıyordu, yani kullanıcı kazandığı puanı
                görmeden puan vermek zorundaydı. */}
            <View style={{ backgroundColor: C.goldBg, borderRadius: R.sm, padding: SP[3], marginTop: ARA[10] }}>
              <View style={{ flexDirection: "row", alignItems: "center" }}><Ikon ad="puan" boy={15} renk={C.mutedAA} stil={{ marginRight: SP[1] }} /><Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm }}>{t.youEarned}</Text></View>
              <View style={{ flexDirection: "row", justifyContent: "space-around", marginTop: ARA[6] }}>
                <View style={{ alignItems: "center" }}>
                  <Text style={{ fontSize: FS.title, fontWeight: "700", color: C.ink, fontFamily: MONO[600] }}>{isHost ? 500 : 200}</Text>
                  <Text style={{ fontSize: FS.xs, color: C.mut }}>{t.loungePoints}</Text>
                </View>
                <View style={{ alignItems: "center" }}>
                  <Text style={{ fontSize: FS.title, fontWeight: "700", color: C.ink, fontFamily: MONO[600] }}>+1</Text>
                  <Text style={{ fontSize: FS.xs, color: C.mut }}>{t.sessionWord}</Text>
                </View>
              </View>
            </View>

            {!rated ? (
              <View style={{ marginTop: ARA[10] }}>
                <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{t.rateTitle} {shortName(otherName)}</Text>
                <View style={{ flexDirection: "row", justifyContent: "center", marginVertical: SP[2] }}>
                  {/* 🔴 Yıldızlar tek tek dokunulabilir ama ekran okuyucuda hepsi
                      "düğme" diye okunuyordu — kullanıcı kaç yıldız verdiğini
                      duyamıyordu. Rol `radio` + seçili durumu eklendi. */}
                  {[1,2,3,4,5].map(n => (
                    <TouchableOpacity hitSlop={TAP.slop} key={n} onPress={() => setStars(n)} style={{ padding: SP[1] }}
                      accessibilityRole="radio"
                      accessibilityState={{ selected: stars === n }}
                      accessibilityLabel={String(n)}>
                      {/* ══════════════════════════════════════════════
                          🔴 13 EYLÜL (Gökberk md.11) — "yıldız verme alanı
                          backgrounddan dolayı belli olmuyor."
                          Zemin değil KOD: `renk={n}` yazıyordu — yani
                          yıldızın RENGİ olarak 1,2,3,4,5 SAYILARI
                          geçiliyordu. Geçersiz renk → çizilmeyen yıldız.
                          Beş yıldızın beşi de görünmezdi; puanlama alanı
                          ekranda BOŞ bir şerit olarak duruyordu.
                          Artık dolu yıldız altın, boş yıldız soluk.
                          🆕 SINIF: "BİR PROP'A YANLIŞ TİPTE DEĞER GEÇMEK
                          HATA VERMEZ — SESSİZCE ÇİZMEZ." */}
                      <Ikon ad={n <= stars ? "degerlendirmeDolu" : "degerlendirme"}
                            boy={FS.display} renk={n <= stars ? C.gold : C.dimAA} />
                    </TouchableOpacity>
                  ))}
                </View>
                {/* MVP: "YORUM (İSTEĞE BAĞLI)" etiketi + "Deneyimini paylaş..." placeholder */}
                <Text style={S.label}>{t.comment}</Text>
                <TextInput style={S.input} value={comment} onChangeText={setComment} placeholder={t.commentPh} placeholderTextColor={C.dim} />
                <Btn label={t.submitRating} onPress={doRate} disabled={!stars} style={{ marginTop: ARA[10], opacity: stars ? 1 : 0.5 }} />
              </View>
            ) : (
              /* v1.81: puanlama bitince ikinci bir "Kazandın" kartı GÖSTERİLMEZ —
                 üstteki tek kart zaten kazancı yazıyordu, ekranda ÜÇ aynı kart
                 birikiyordu (Gokberk'in 6. maddesi). Burada sadece teşekkür. */
              <View style={{ backgroundColor: C.greenBg, borderRadius: R.sm, padding: SP[3], marginTop: SP[2] }}>
                <IkonMetin ad="tamam" renk={C.greenInk} stilMetin={{ color: C.greenInk, fontWeight: "700", fontSize: FS.sm }} metin={t.rateThanks} />
              </View>
            )}

            {/* MVP: puanlama zorunluluğu uyarısı — puanlamadan devam edilmemeli */}
            {!rated && (
              /* 🔴 13 EYLÜL (Gökberk md.11) — "alt taraftaki uyarı iconu
                 üste dayalı, texte göre ortalı olsa daha iyi olmaz mı".
                 Satırda hiza kuralı yoktu (`alignItems` yok → varsayılan
                 "stretch"): ikon iki satırlık metnin tepesine yapışıyordu.
                 Ayrıca ikonun sağ boşluğu da yoktu — 12 Eylül'de kapattığım
                 sınıfın bir örneği daha. */
              <View style={{ backgroundColor: C.goldBg, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.xs, padding: SP[3], marginTop: SP[3], flexDirection: "row", alignItems: "center" }}>
                <Ikon ad="uyari" boy={FS.sm} renk={C.goldText} stil={{ marginRight: ARA[8] }} />
                <Text style={{ color: C.goldText, fontSize: FS.sm, lineHeight: 17, flex: 1, minWidth: 0 }}>{t.ratePrompt}</Text>
              </View>
            )}

            {/* v1.81 (Gokberk 6. madde): tamamlandı ekranından hiçbir yere
                gidilemiyordu. Ana sayfaya dönüş eklendi (paneli kapatır,
                sohbetten çıkar). */}
            <Btn v="teal" sm label={t.goHomeBtn} onPress={() => { setPanelOpen(false); onBack && onBack(); }} style={{ marginTop: SP[3] }} />

            {/* MVP: 🤝 Stay in touch? — oturumdaki diğer kişiyle bağlantı kur */}
            <View style={{ backgroundColor: C.purpleBg, borderWidth: 1, borderColor: C.purple + "30", borderRadius: R.sm, padding: SP[3], marginTop: SP[3] }}>
              <View style={{ flexDirection: "row", alignItems: "center" }}><Ikon ad="elSikisma" boy={15} renk={C.mutedAA} stil={{ marginRight: SP[1] }} /><Text style={{ color: C.purpleInk, fontWeight: "700", fontSize: FS.sm }}>{t.stayInTouchTitle}</Text></View>
              <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 16, marginTop: SP[1], marginBottom: connState === "connected" ? 0 : 10 }}>
                {t.stayInTouchBody.replace("{name}", otherName || "")}
              </Text>
              {connState === "connected" ? (
                <IkonMetin ad="tamam" renk={C.green} stilMetin={{ color: C.green, fontWeight: "700", fontSize: FS.sm, marginTop: SP[2] }} metin={t.connActive} />
              ) : connState === "sent" ? (
                <IkonMetin ad="tamam" renk={C.green} stilMetin={{ color: C.green, fontWeight: "600", fontSize: FS.sm }} metin={t.connSentWaiting.replace("{name}", (otherName || "").split(" ")[0])} />
              ) : connState === "incoming" ? (
                <Btn v="purple" sm label={t.acceptConn} onPress={doAcceptConn} />
              ) : (
                <Btn v="purpleSoft" sm onPress={doConnect}
                  label={t.connectWith.replace("{name}", (otherName || "").split(" ")[0])} sagAd="sag"
                  a11yLabel={t.connectWith.replace("{name}", (otherName || "").split(" ")[0])} />
              )}
            </View>
            {/* MVP: bağlantı kutusunun altında ikincil çıkış — puanlama zorunlu değil,
                24 saat içinde puanlanabilir (sunucu kuralı: itiraz penceresi). */}
            {!rated && onBack && (
              <TouchableOpacity hitSlop={TAP.slop} onPress={onBack} style={{ paddingVertical: SP[3], alignItems: "center" }}>
                <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.rateLater}</Text>
              </TouchableOpacity>
            )}
            {/* #6: oturum sonrası davet CTA — kullanıcı en mutlu anında viral döngü */}
            {rated && onReferral && (
              <TouchableOpacity hitSlop={TAP.slop} onPress={onReferral}
                style={{ flexDirection: "row", alignItems: "center", backgroundColor: C.purpleBg, borderWidth: 1, borderColor: C.purple + "30", borderRadius: R.sm, padding: SP[3], marginTop: ARA[10] }}>
                <Ikon ad="davet" boy={22} renk={C.mutedAA} />
                <View style={{ flex: 1 }}>
                  <Text style={{ color: C.purpleInk, fontWeight: "700", fontSize: FS.sm }}>{t.inviteAfterTitle}</Text>
                  <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: 0 }}>{t.inviteAfterBody}</Text>
                </View>
                <Ikon ad="sag" boy={FS.lg} renk={C.purpleInk} />
              </TouchableOpacity>
            )}
          </View>
        )}
        {!!err && <Text style={{ color: C.red, fontSize: FS.sm, marginTop: SP[2], textAlign: "center" }}>{err}</Text>}
        </ScrollView>
        </View>
      )}
      {/* İptal onayı (§23 v7: Cancel → kredi iadeli iptal) */}
      <Modal visible={confirmCancel} transparent animationType="fade" onRequestClose={() => setConfirmCancel(false)}>
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.55)", justifyContent: "center", padding: ARA[28] }}>
          <View style={{ backgroundColor: C.card, borderRadius: R.md, padding: ARA[20] }}>
            <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink }}>
              {(sess && sess.status === "active" && sess.cancel_grace_until && new Date(sess.cancel_grace_until) <= new Date())
                ? t.cancelLateTitle : t.cancelReq}
            </Text>
            <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[2], lineHeight: 19 }}>{t.cancelConfirm}</Text>
            {!!cancelErr && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{cancelErr}</Text></View>}
            <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[14] }}>
              <Btn v="muted" sm label={t.cancelNo} onPress={() => setConfirmCancel(false)}
                style={{ flex: 1 }} />
              {/* 🔴 v1.75: eski kod HER ZAMAN cancel_request çağırıyordu; oturum
                  varsa sunucu "aktif oturum varken iptal edilemez" diyor ve
                  kullanıcı kilitleniyordu. Artık duruma göre doğru yol:
                  oturum varsa cancel_session (5 dk kuralı sunucuda). */}
              <Btn v="danger" sm label={t.cancelYes} onPress={() => doCancelSession(null)} style={{ flex: 1 }} />
            </View>
          </View>
        </View>
      </Modal>

      {/* SOS (§15: session sırasında güvenlik aracı) */}
      <Modal visible={sosOpen} transparent animationType="fade" onRequestClose={() => setSosOpen(false)}>
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.6)", justifyContent: "center", padding: ARA[30] }}>
          <View style={{ backgroundColor: C.card, borderRadius: R.md, padding: ARA[22] }}>
            <Ikon ad="acil" boy={22} renk={C.mutedAA} />
            <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, textAlign: "center", marginTop: SP[2] }}>{t.safetySOS}</Text>
            <Text style={{ fontSize: FS.sm, color: C.mut, textAlign: "center", marginTop: SP[2], lineHeight: 20 }}>{t.safetySOSBody}</Text>
            {/* ══════════════════════════════════════════════════════
                🔴 30 AĞUSTOS · 7. TUR — OTURUM İPTALİ DE BURADA.

                Gökberk sordu: "kullanıcı oturumu iptal etmek
                istediğinde nereye tıklayacak?"

                Ölçtüm — iptal ÜRÜNDE VARDI ve iki yerdeydi: oturum
                kartının içinde (başlamadan önce "cezasız iptal",
                başladıktan sonra "İptal et"). Yani eksik olan özellik
                değil, BULUNABİLİRLİKTİ: kullanıcı "iptal" ararken
                sohbetin ortasındaki bir karta değil, sağ üstteki
                eylem düğmesine bakar.

                🆕 SINIF: "BİR EYLEMİN VAR OLMASI ONUN BULUNABİLİR
                OLMASI DEĞİLDİR — KULLANICI ONU ARADIĞI YERDE
                BULAMIYORSA, O EYLEM ÜRÜNDE DEĞİL KODDA VARDIR."

                İkinci bir iptal MAKİNESİ yazılmadı: bu düğme var olan
                `setConfirmCancel` akışını açıyor (5 dakika kuralı,
                kredi iadesi ve `cancel_session` çağrısı orada). Aynı
                işin ikinci bir kopyası, ikisi de yarım bakımlı olurdu.
                ══════════════════════════════════════════════════════ */}
            {!!sess && sess.status !== "completed" && sess.status !== "cancelled" && (
              <Btn v="redSoft" label={t.cancelSessionBtn || t.cancelWord}
                style={{ marginTop: SP[4] }}
                onPress={() => { setSosOpen(false); setConfirmCancel(true); }} />
            )}

            {/* Başlıktan taşınan iki eylem. Yıkıcı oldukları için
                burada ADLARIYLA duruyorlar ve genişlik sıkıntısı yok. */}
            <Btn v="redSoft" label={t.ppReport2} style={{ marginTop: SP[4] }}
              onPress={() => { setSosOpen(false);
                (onReport ? onReport(otherId, otherName) : onSafety && onSafety()); }} />
            <Btn v="redSoft" label={t.cancelReq} style={{ marginTop: SP[2] }}
              onPress={() => { setSosOpen(false); setConfirmCancel(true); }} />
            <Btn label={t.cancelNo} onPress={() => setSosOpen(false)} style={{ marginTop: SP[2] }} />
          </View>
        </View>
      </Modal>
    </Sayfa>
  );
}

// ════════════════════════════════════════════════════════════════════════
// KİMLİK DOĞRULAMA — BELGE YÜKLEME  (SQL 285)
//
// 🔴 "Kimlik doğrulandı" rozeti (+18 güven, +400 puan, keşifte +14) bugüne
// kadar BO'da bir düğmeye basılarak veriliyordu; uygulamada belge yükleme
// akışı HİÇ YOKTU. Bu ekran o boşluğu kapatır: kimlik ön yüzü + selfie,
// özel `kyc` kovasına (yalnız kendi klasörüne yazabilir, kimse okuyamaz;
// BO süreli imzalı bağlantıyla görür), sonra `kimlik_belgesi_gonder`.
//
// KVKK: karar verilince belge silinir; bunu ekranda AÇIKÇA söylüyoruz.
// ════════════════════════════════════════════════════════════════════════
export function KimlikDogrula({ t, session, onBack, onDone }) {
  const uid = session?.user?.id;
  const [durum, setDurum] = useState(null);
  const [doc, setDoc] = useState(null);
  const [selfie, setSelfie] = useState(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [msg, setMsg] = useState("");

  const yukle = useCallback(async () => {
    const { data, error } = await supabase.rpc("kimlik_durumum");
    if (error) { logError("kimlik_durumum", error); setDurum({ status: "none" }); return; }
    setDurum(data || { status: "none" });
  }, []);
  useEffect(() => { yukle(); }, [yukle]);

  async function sec(hangi) {
    setErr("");
    try {
      const ImagePicker = await import("expo-image-picker");
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) return;
      const res = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images, allowsEditing: false, quality: 0.7, base64: true,
      });
      if (res.canceled || !res.assets?.[0]?.base64) return;
      (hangi === "doc" ? setDoc : setSelfie)(res.assets[0].base64);
    } catch (e) { logError("kyc_pick", e); setErr(t.kycUploadFail); }
  }

  async function gonder() {
    if (!uid || !doc) return;
    setBusy(true); setErr("");
    const yolla = async (b64, ad) => {
      const path = `${uid}/${ad}-${Date.now()}.jpg`;
      const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
      const { error } = await supabase.storage.from("kyc").upload(path, bytes, { contentType: "image/jpeg", upsert: false });
      if (error) { logError("kyc_upload", error); return null; }
      return path;
    };
    const docPath = await yolla(doc, "kimlik");
    if (!docPath) { setBusy(false); setErr(t.kycUploadFail); return; }
    const selfiePath = selfie ? await yolla(selfie, "selfie") : null;
    const { error } = await supabase.rpc("kimlik_belgesi_gonder", { p_doc_path: docPath, p_selfie_path: selfiePath });
    setBusy(false);
    if (error) { logError("kimlik_belgesi_gonder", error); setErr(mapErr(t, error.message)); return; }
    setMsg(t.kycSubmitted); setDoc(null); setSelfie(null);
    yukle(); onDone && onDone();
  }

  const st = durum?.status;
  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.kycEyebrow} title={t.kycTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <Text style={{ color: C.body, fontSize: FS.sm, lineHeight: 20, marginBottom: ARA[14] }}>{t.kycBody}</Text>
        {durum === null ? <Load /> : st === "approved" ? (
          <View style={[S.card, { borderColor: C.gold, borderWidth: 1.5 }]}>
            <Text style={{ color: C.goldText, fontSize: FS.lg, fontWeight: "700" }}>{t.kycApproved}</Text>
          </View>
        ) : st === "submitted" ? (
          <View style={[S.card, { borderColor: C.teal, borderWidth: 1.5 }]}>
            <Text style={{ color: C.tealInk, fontSize: FS.sm, fontWeight: "600" }}>
              {(t.kycPending || "{d}").replace("{d}", durum.submitted_at ? new Date(durum.submitted_at).toLocaleDateString() : "")}
            </Text>
          </View>
        ) : (
          <>
            {st === "rejected" && !!durum.note && (
              <View style={{ backgroundColor: C.amberBg, borderRadius: R.sm, padding: SP[3], marginBottom: ARA[14] }}>
                <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "600" }}>{(t.kycRejected || "{n}").replace("{n}", durum.note)}</Text>
              </View>
            )}
            {[["doc", t.kycDoc, doc], ["selfie", t.kycSelfie, selfie]].map(([k, lb, val]) => (
              <View key={k} style={[S.card, { marginBottom: SP[3] }]}>
                <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "600", marginBottom: SP[2] }}>{lb}</Text>
                <View style={{ flexDirection: "row", alignItems: "center", gap: SP[3] }}>
                  {val ? <Image source={{ uri: "data:image/jpeg;base64," + val }} style={{ width: 64, height: 44, borderRadius: R.xs }} accessibilityLabel={lb} /> : null}
                  <Btn v="ghost" sm label={val ? t.kycPicked : t.kycPick} onPress={() => sec(k)} a11yLabel={lb + " · " + t.kycPick} />
                </View>
              </View>
            ))}
            <Text style={{ color: C.muted, fontSize: FS.xs, lineHeight: 16, marginBottom: ARA[14] }}>{t.kycPrivacy}</Text>
            {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
            {!!msg && <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, padding: ARA[10], marginBottom: SP[3] }}><Text style={{ color: C.greenInk, fontSize: FS.sm }}>{msg}</Text></View>}
            <Btn v="gold" label={st === "rejected" ? t.kycRetry : t.kycSend} onPress={gonder} disabled={busy || !doc} busy={busy} a11yLabel={t.kycSend} />
          </>
        )}
      </ScrollView>
    </Sayfa>
  );
}

export function VerifyPhone({ t, session, onDone, onBack }) {
  // v1.74: klasik kayıtta telefon zaten alınıyor — kullanıcıya tekrar
  // yazdırmak gereksiz sürtünme. Kayıtlı numara varsa alan ÖN DOLU gelir;
  // sosyal girişte numara olmadığı için boş +90 ile başlar.
  const [phone, setPhone] = useState("+90");
  // ══════════════════════════════════════════════════════════════════════
  // 🔴 v3.9.1 — SMS'İN VAR OLUP OLMADIĞINI ARTIK SUNUCU SÖYLÜYOR.
  //
  // ÖLÇÜLDÜ (SQL 269): `send_otp` bir kod üretip saklıyor ve HİÇBİR YERE
  // GÖNDERMİYOR — depoda tek bir SMS sağlayıcı çağrısı yok. Ama `{ok:true}`
  // döndüğü için bu ekran kod aşamasına geçiyordu: kullanıcı 8 ayrı
  // ekrandan buraya yönlendirilip ASLA GELMEYECEK bir SMS'i bekliyordu.
  //
  // Kanal artık `dogrulama_kanali()`nden okunuyor. Sağlayıcı bağlandığı gün
  // `beta_settings.otp_sms_saglayici` doldurulur ve yol UYGULAMA
  // GÜNCELLEMESİ OLMADAN açılır — bugün ise ekran dürüstçe e-posta yolunu
  // öne alıyor ve numarayı yalnız KAYDEDİYOR.
  //
  // 🆕 SINIF: "BİR YOLUN AÇIK OLUP OLMADIĞINI KOD İÇİNDE SABİTLERSEN, YOL
  // AÇILDIĞI GÜN SÜRÜM ÇIKMAK ZORUNDA KALIRSIN — DURUMU SUNUCUDAN SOR."
  // ══════════════════════════════════════════════════════════════════════
  const [smsHazir, setSmsHazir] = useState(null);   // null = henüz bilinmiyor
  const [kanalNot, setKanalNot] = useState("");
  useEffect(() => {
    (async () => {
      const uid = session?.user?.id; if (!uid) return;
      const [{ data }, { data: k }] = await Promise.all([
        supabase.from("users").select("phone").eq("id", uid).maybeSingle(),
        supabase.rpc("dogrulama_kanali"),
      ]);
      if (data?.phone) setPhone(data.phone);
      // Sunucuya ulaşılamazsa SMS'i VAR SAYMIYORUZ: yanlış yönde bozulmak,
      // kullanıcıyı yine boş ekrana göndermek olurdu.
      setSmsHazir(!!(k && k.sms_hazir));
      if (k && k.not) setKanalNot(String(k.not));
    })();
  }, [session]);
  const [code, setCode] = useState("");
  const [stage, setStage] = useState("phone"); // phone | code | done
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  function mapOtpErr(e) {
    const key = "e_" + (e || "").split(" ")[0].replace(/[^a-z_]/g, "");
    return t[key] || mapErr(t, e);
  }

  // 🔴 v1.73 / SQL 079: E-POSTA İLE DOĞRULAMA (maliyetsiz yol).
  // SMS ücretli olduğu için doğrulama kapısı artık "telefon VEYA e-posta".
  // Kodu SUPABASE AUTH'un kendisi gönderir (ek servis/ücret yok); kod
  // doğrulanınca sunucudaki verify_email_contact() işareti yazar — ve o
  // fonksiyon auth.users.email_confirmed_at'e baktığı için istemci
  // "doğruladım" diye yalan söyleyemez.
  const myEmail = session?.user?.email || "";
  async function sendEmailCode() {
    setErr(""); setBusy(true);
    const { error } = await supabase.auth.signInWithOtp({
      email: myEmail, options: { shouldCreateUser: false },
    });
    setBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    setStage("emailCode");
  }
  async function verifyEmailCode() {
    setErr(""); setBusy(true);
    const { error } = await supabase.auth.verifyOtp({ email: myEmail, token: code.trim(), type: "email" });
    if (error) { setBusy(false); return setErr(mapErr(t, error.message)); }
    const { error: e2 } = await supabase.rpc("verify_email_contact");
    // 🔴 v2.36 — NE DOGRULANDIYSA O YAZILSIN.
    // Kod E-POSTAYA gitti; dogrulanan sey hesabin sahibi oldugun.
    // TELEFON numaran hala dogrulanmadi (SMS saglayicimiz yok).
    // Ikisini ayni rozette birlestirmek, 136'da temizledigimiz
    // "dogrulanmis gibi gorunen dogrulanmamis sey" hatasinin
    // daha kibar bir surumu olurdu.
    // 🔴 v3.9.1 — `mark_email_verified` ÇAĞRISI KALDIRILDI: gövdesi
    // `verify_email_contact` ile BİREBİR AYNI işi yapıyor (ikisi de
    // `auth.users.email_confirmed_at`e bakıp `verifications`a yazıp
    // `recompute_trust` çağırıyor). İki çağrı = bir tur fazladan bekleme
    // ve iki kez puan hesabı.
    // 🆕 SINIF: "AYNI İŞİ YAPAN İKİ FONKSİYONU ART ARDA ÇAĞIRMAK,
    // GÜVENLİK DEĞİL GECİKMEDİR.
    setBusy(false);
    if (e2) return setErr(mapOtpErr(e2.message));
    setStage("done");
    setTimeout(() => onDone && onDone(), 1400);
  }

  async function sendCode() {
    setErr(""); setBusy(true);
    const { error } = await supabase.rpc("send_otp", { p_phone: phone.trim() });
    setBusy(false);
    if (error) return setErr(mapOtpErr(error.message));
    setStage("code");
  }

  // SMS yokken numara yine de KAYDEDİLİR (talep kapısı numaranın yazılı
  // olmasını istiyor); ama "doğrulandı" DEMİYORUZ — 136'da temizlediğimiz
  // "doğrulanmış gibi görünen doğrulanmamış şey" hatasına dönmesin.
  async function numarayiKaydet() {
    setErr(""); setBusy(true);
    const { error } = await supabase.rpc("declare_phone", { p_phone: phone.trim() });
    setBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    setStage("kayitli");
  }
  async function verify() {
    setErr(""); setBusy(true);
    const { error } = await supabase.rpc("verify_otp", { p_phone: phone.trim(), p_code: code.trim() });
    setBusy(false);
    if (error) return setErr(mapOtpErr(error.message));
    setStage("done");
    setTimeout(() => onDone && onDone(), 1400);
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneAccount} title={t.verifyPhone} onBack={onBack} />
      <View style={{ flex: 1, padding: ARA[22] }}>

      {stage === "done" ? (
        <View style={{ marginTop: ARA[30], alignItems: "center" }}>
          <Ikon ad="tamam" boy={FS.bant} renk={C.mut} />
          <Text style={{ color: C.teal, fontWeight: "700", fontSize: FS.lg, marginTop: ARA[10], textAlign: "center" }}>{t.phoneDone}</Text>
        </View>
      ) : stage === "kayitli" ? (
        /* Numara kaydedildi — DOĞRULANMADI. İkisini ayırmak şart. */
        <View style={{ marginTop: ARA[30], alignItems: "center" }}>
          <Ikon ad="telefon" boy={34} renk={C.amber} />
          <Text style={{ color: C.amberInk, fontWeight: "700", fontSize: FS.base, marginTop: ARA[10], textAlign: "center" }}>
            {t.phoneSaved}
          </Text>
          <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2], textAlign: "center", lineHeight: 19 }}>
            {kanalNot || t.phoneSavedBody}
          </Text>
          {!!myEmail && (
            <Btn v="teal" label={t.verifyByEmail} onPress={sendEmailCode}
              sol={<Ikon ad="eposta" boy={15} renk={C.tealInk} />}
              disabled={busy} busy={busy} style={{ marginTop: SP[4] }} />
          )}
        </View>
      ) : stage === "phone" ? (
        <>
          {/* 🔴 v3.9.1 — SIRALAMA DEĞİŞTİ: ÇALIŞAN YOL ÖNDE.
              Eskiden ekranın birincil düğmesi "Kodu gönder"di ve o yol
              çıkmaz sokaktı; e-posta yolu altta ikincil bir kutuydu.
              Kullanıcıyı önce çalışmayan kapıya göndermek, sonra
              çalışanı fısıldamak — sıralama bir tasarım kararıdır.
              🆕 SINIF: "İKİ YOLDAN BİRİ ÇALIŞMIYORSA, EKRANIN BİRİNCİL
              DÜĞMESİ ÇALIŞAN YOL OLMALIDIR — SIRALAMA, KULLANICIYA HANGİ
              YOLA GÜVENDİĞİMİZİ SÖYLER." */}
          {!!myEmail && (
            <>
              <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2], lineHeight: 20 }}>
                {t.verifyEmailWhy || t.phoneWhy}
              </Text>
              <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "40",
                             borderRadius: R.sm, padding: SP[3], marginTop: SP[3] }}>
                <Text style={{ color: C.tealInk, fontSize: FS.sm, fontWeight: "700" }}>{myEmail}</Text>
              </View>
              <Btn v="teal" label={t.verifyByEmail} onPress={sendEmailCode}
                sol={<Ikon ad="eposta" boy={15} renk={C.tealInk} />}
                disabled={busy} busy={busy} style={{ marginTop: SP[3] }} />
            </>
          )}

          <Text style={S.label}>{t.phoneLabel}</Text>
          <TextInput style={S.input} value={phone} onChangeText={setPhone} keyboardType="phone-pad" />
          <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[6] }}>{t.phoneHint}</Text>
          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}

          {/* `smsHazir === null` → sunucu cevabı HENÜZ GELMEDİ. Bu aşamada
              hiçbir düğme gösterilmiyor: yanlış düğmeyi bir an gösterip
              değiştirmek, kullanıcıya iki farklı ürün göstermektir. */}
          {smsHazir === true ? (
            <Btn label={t.sendCode} onPress={sendCode} disabled={busy} busy={busy}
              style={{ marginTop: SP[3] }} />
          ) : smsHazir === false ? (
            <>
              <Btn v="ghost" label={t.phoneSaveOnly} onPress={numarayiKaydet}
                disabled={busy} busy={busy} style={{ marginTop: SP[3] }} />
              <Text style={{ color: C.mutedAA, fontSize: FS.xs, marginTop: SP[2], lineHeight: 17 }}>
                {kanalNot}
              </Text>
            </>
          ) : (
            <View style={{ marginTop: SP[4], alignItems: "center" }}>
              <ActivityIndicator color={C.gold} />
            </View>
          )}
        </>
      ) : stage === "code" ? (
        <>
          {/* 🔴 v2.99 — DOĞRULAMA KODU EKRANDA GÖSTERİLİYORDU.
              `send_otp` üretilen 6 haneli kodu yanıtın içinde geri veriyor,
              bu kutu da onu basıyordu. Yani herkes İSTEDİĞİ numarayı iki
              çağrıda "doğrulanmış" yapabiliyordu — ve telefon doğrulaması
              güven puanına +10 katkı verdiği için güven mimarisinin tamamı
              buna dayanıyordu. SQL 253 §3 sunucudaki dalı SİLDİ; burası da
              kalktı. Kutuyu bırakıp sunucuyu kapatmak, bir gün ayarı geri
              açan birinin arka kapıyı hazır bulması demekti.
              🆕 SINIF: "DEMO MODU, ÜRÜNE GİRDİĞİ GÜN BİR ARKA KAPIYA
              DÖNÜŞÜR — ÇÜNKÜ ONU KAPATMAYI HATIRLAYACAK KİMSE YOKTUR." */}
          <Text style={S.label}>{t.enterCode}</Text>
          <TextInput style={[S.input, { fontSize: FS.title, letterSpacing: 6, textAlign: "center" }]}
            value={code} onChangeText={x => setCode(x.replace(/[^0-9]/g, "").slice(0,6))}
            keyboardType="number-pad" maxLength={6} />
          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
          <Btn label={t.verifyBtn} onPress={verify} disabled={busy || code.length !== 6} busy={busy} />
          <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: ARA[14] }}>
            <TouchableOpacity hitSlop={TAP.slop} onPress={sendCode}><Text style={{ color: C.gold, fontSize: FS.sm }}>{t.resend}</Text></TouchableOpacity>
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setStage("phone"); setCode(""); setErr(""); }}>
              <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.changeNum}</Text></TouchableOpacity>
          </View>
        </>
      ) : stage === "emailCode" ? (
        /* v1.73: E-POSTA kodu aşaması */
        <>
          <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[2], lineHeight: 20 }}>
            {t.emailCodeSent.replace("{email}", myEmail)}
          </Text>
          <Text style={S.label}>{t.enterCode}</Text>
          <TextInput style={[S.input, { fontSize: FS.title, letterSpacing: 6, textAlign: "center" }]}
            value={code} onChangeText={x => setCode(x.replace(/[^0-9]/g, "").slice(0,6))}
            keyboardType="number-pad" maxLength={6} />
          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
          <Btn label={t.verifyBtn} onPress={verifyEmailCode} disabled={busy || code.length !== 6} busy={busy} />
          <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: ARA[14] }}>
            <TouchableOpacity hitSlop={TAP.slop} onPress={sendEmailCode}><Text style={{ color: C.gold, fontSize: FS.sm }}>{t.resend}</Text></TouchableOpacity>
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => { setStage("phone"); setCode(""); setErr(""); }}>
              <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.backToPhone}</Text></TouchableOpacity>
          </View>
        </>
      ) : null}
      </View>
    </Sayfa>
  );
}

// 🔴 v2.65 · ÖLÜ PROP TEMİZLİĞİ + BİR EKRANIN GERİ KAZANILMASI
//
// İmzada 7 prop vardı ve HİÇBİRİ gövdede okunmuyordu:
//   lang, setLang → dil seçimi Ayarlar'da yaşıyor. İkinci bir seçici,
//                   iki ayrı doğruluk kaynağı demek. SİLİNDİ.
//   onVerify      → doğrulama satırı Profili Düzenle'de gerçek aksiyonla
//                   duruyor. İkinci giriş eklemedik. SİLİNDİ.
//   onMeet/onTrips→ alt sekme çubuğu zaten bu iki yere gidiyor. SİLİNDİ.
//   onManagePlan  → 🔴 ÖLÇÜLDÜ: setShowPlans(true) çağıran BAŞKA yer YOK.
//                   Yani Plans ekranı canlıda ULAŞILAMAZ durumdaydı.
//                   BAĞLANDI (aşağıda "Plan" satırı).
//   onLive        → LiveStatus yalnız 1:1 sohbetten açılabiliyordu.
//                   Kod yorumu (bu dosyada) bu satırın menüde olması
//                   gerektiğini zaten yazıyor. BAĞLANDI.
// v2.66: `onAccess` imzadan ÇIKTI — lounge hakkı kartı Profili Düzenle
// ekranına taşındı (madde 4). Ölü prop bırakmıyoruz.
export function Notifications({ t, session, onRefreshBadge, onGit, onBack }) {
  const bnt = useDaralanBant();            // 12 Eyl · daralan bant
  const [yukErr, setYukErr] = useState("");
  const uid = session?.user?.id;
  const [rows, setRows] = useState(null);
  const [cat, setCat] = useState("all");   // #21: MVP kategori filtresi
  // 19 Eylül · derin denetim — bildirime dokunma yolunun hata satırı.
  const [hedefHatasi, setHedefHatasi] = useState("");

  const load = useCallback(async () => {
    const { data, error: eNotif } = await supabase.from("notifications").select("*")
      .eq("user_id", uid).order("created_at", { ascending: false }).limit(50);
    // 🔴 Hata yutuluyordu ve ekran "Sessizlik iyi haber" yazıyordu —
    // yani bir ağ hatası, KULLANICIYA HİÇ BİLDİRİM YOKMUŞ gibi görünüyordu.
    if (eNotif) { logError("bildirimlerim", eNotif); setYukErr(mapErr(t, eNotif.message)); setRows([]); return; }
    setYukErr("");
    setRows(data || []);
  }, [uid]);
  useEffect(() => { load(); }, [load]);

  // 🔴 v2.96 (C3) — "okundu" işareti artık RPC'den geçiyor.
  // Doğrudan yazımda iki kusur vardı: (a) hata TAMAMEN yutuluyordu —
  // yazma düşerse rozet düşmüyor ve kullanıcı tekrar tekrar basıyordu;
  // (b) tablo düzeyinde UPDATE hakkı açıktı.
  async function markAll() {
    const { error } = await supabase.rpc("bildirim_okundu");
    if (error) { logError("bildirim_okundu", error); return; }
    load(); onRefreshBadge && onRefreshBadge();
  }
  // 🔴 v2.99 — BİLDİRİME DOKUNMAK HİÇBİR YERE GİTMİYORDU.
  // Kullanıcı push'a basıyor, uygulama açılıyor, listede satıra dokunuyor,
  // satır griye dönüyor ve BİTİYOR. İsteği bulmak için Planım → İlanlarım'a
  // kendisi gidiyor. `nf.category` okunuyordu ama YALNIZ renk noktası için.
  //
  // Zaman kısıtlı bir üründe bu, en pahalı eksiklerden biri: misafir kapıda
  // beklerken host bildirimi görüp isteği bulamıyor.
  //
  // 🆕 SINIF: "ZAMANA BAĞLI BİR ÜRÜNDE BİLDİRİM, HABER DEĞİL KISAYOLDUR."
  //
  // Hedef eşlemesi SUNUCUDA (SQL 254 `bildirim_hedefi`): kategori→ekran
  // ürünün kuralıdır, iki istemcide ayrı ayrı yazılmamalı.
  async function tap(nf) {
    if (!nf.read) {
      // 🔴 19 EYLÜL · DERİN DENETİM — İKİ BAĞIMSIZ İŞ BİRBİRİNE BAĞLIYDI.
      // Eski hâl: `bildirim_okundu` düşerse `return` — yani OKUNDU
      // İŞARETLEMESİNDEKİ geçici bir hata, GEZİNMEYİ de tamamen
      // engelliyordu. Kullanıcı bildirime dokunuyor, ekran değişmiyor,
      // hata da görünmüyor. İkinci kez dokunuyor, yine hiçbir şey.
      // Okundu işareti bir KONFOR, hedefe gitmek bir İŞ.
      // 🆕 SINIF: "İKİ BAĞIMSIZ İŞİ ARDIŞIK YAZIP BİRİNCİSİNDE `return`
      // KOYARSAN, İKİSİNİ BİRBİRİNE BAĞLAMIŞSIN DEMEKTİR."
      const { error } = await supabase.rpc("bildirim_okundu", { p_id: nf.id });
      if (error) logError("bildirim_okundu", error);   // yut, ama DURMA
      else { load(); onRefreshBadge && onRefreshBadge(); }
    }
    if (!onGit) return;
    const { data, error } = await supabase.rpc("bildirim_hedefi", { p_id: nf.id });
    // 19 Eylül — hedef alınamazsa kullanıcı SEBEBİ görüyor; eskiden
    // dokunuş sessizce buharlaşıyordu.
    if (error) { logError("bildirim_hedefi", error); setHedefHatasi(mapErr(t, error.message)); return; }
    setHedefHatasi("");
    // Hedefi olmayan bildirim (duyuru) için hiçbir yere GİTMİYORUZ —
    // rastgele bir ekrana atmak, dokunmayı anlamsızlaştırırdı.
    if (data && data.ekran) onGit(data);
  }

  const catColor = { requests: C.gold, sessions: C.teal, safety: C.red, connections: C.purple, invites: C.gold, credits: C.gold, ratings: C.green, system: C.mut };
  // 🔴 İKON ADIYLA — GLİF KARAKTERİYLE DEĞİL. Bir karakter yazsaydım
  // (✉ ⚑ ★) pakete gömülü fontta yoksa Android'de boş kare çizerdi;
  // `ikon_check.py` de adı çözemediği için denetleyemezdi.
  const catIkon = { requests: "sohbet", sessions: "salon", safety: "guvenlik",
                    connections: "kisiler", invites: "davet", credits: "cuzdan",
                    ratings: "degerlendirme", system: "bilgi" };
  // 4 Eylül — tasarım 10: dört çip (Tümü · Bağlantılar · İstekler · Oturumlar),
  // sayaç yok. Güvenlik bildirimleri "Tümü"nde görünür.
  const cats = [["all", t.catAll], ["connections", t.catConnections], ["requests", t.catRequests], ["sessions", t.catSessions]];
  // Çip satırı artık bandın İÇİNDE çiziliyor (bkz. aşağıdaki `Hdr`).
  const cipSatiri = (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[8], marginTop: ARA[12] }}>
      {cats.map(([k, lb]) => {
        const n = (rows || []).filter(x => !x.read && (k === "all" || x.category === k)).length;
        return (
          <Cip key={k} etiket={lb} secili={cat === k}
               a11yLabel={lb + (n > 0 ? ` · ${n}` : "")} onPress={() => setCat(k)}
               onLongPress={k === "all" ? markAll : undefined} />
        );
      })}
    </View>
  );
  const shown = rows === null ? null : cat === "all" ? rows : rows.filter(n => n.category === cat);
  // Hedef alınamadığında görünen tek satır. Çip satırının altında,
  // listenin üstünde: kullanıcı dokunduğu yerin hemen yanında görür.
  const hedefSatiri = !hedefHatasi ? null : (
    <View style={[S.err, { marginTop: SP[2] }]}>
      <Text style={{ color: C.redInk, fontSize: FS.sm }}>{hedefHatasi}</Text>
    </View>
  );

  return (
    <Sayfa>
      {/* 3 Eylül — tasarım 10: mesh bant (BİLDİRİMLER / Bildirimler), sağ
          üstte `.ust-eylem` dairesi. Daire burada "tümünü okundu işaretle"
          (ekran okuyucuda etiketi var); geri oku bantta. */}
      {/* 4 Eylül — tasarım 10 birebir: bantta geri oku ve "tümünü okundu"
          dairesi yok. Ekran sekme çubuğuyla açılıyor (App.js: katman çubuğu
          gösterir); satıra dokunmak onu okundu yapar. `markAll` çip satırının
          uzun basışında (ekran okuyucu: "Tümünü okundu işaretle"). */}
      {/* 🔴 12 EYLÜL · KAPSAM TURU — ÇİPLER BANDIN İÇİNE GİRDİ VE BANT DARALIYOR.
          Gökberk: "Tanış / Planım / Bildirimler'de bant hâlâ sabit —
          sekmeler arası gezerken bunu fark edersin."
          Çipleri bandın ALTINDA bırakıp bandı daraltsaydım, çipler
          havada kalırdı. Planım zaten çiplerini bandın içinde taşıyor
          (5 Eylül kararı); Bildirimler de aynı dile geçti — böylece
          kaydırınca ikisi birlikte toplanıyor. */}
      {/* 🔴 13 EYLÜL (Gökberk md.14) — "bildirimlerde back yok".
          4 Eylül'de "tasarım 10 birebir" diye geri okunu kaldırmıştım;
          gerekçem "ekran sekme çubuğuyla açılıyor"du. Ama ürün o gün
          değişti: Bildirimler artık Profil MENÜSÜNDEN de açılıyor ve
          oradan gelen kullanıcının geri dönecek yeri yok — sekme çubuğu
          onu Profil'e değil, Profil'in köküne atıyor.
          🆕 SINIF: "BİR EKRANIN ÇIKIŞI, O EKRANA HANGİ KAPIDAN
          GİRİLDİĞİNE BAĞLIDIR — TEK GİRİŞ VARSAYIMIYLA SİLİNEN GERİ OKU,
          İKİNCİ KAPI AÇILDIĞI GÜN KAYBOLUR." */}
      <Hdr t={t} title={t.notifTitle} kaydir={bnt.kaydir} onBack={onBack}
           foto={{ ustBilgi: t.notifTitle, olc: bnt.olc, tam: bnt.tam, altIcerik: cipSatiri }} />
      {/* #21: MVP kategori sekmeleri — altin alt cizgi */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 30 AĞUSTOS · 6. TUR — BİLDİRİMLER GECE SİSTEMİNE GEÇTİ.

          Gökberk: "app içi ve telefonlara gönderdiğimiz bildirimlere de
          bu tasarımı doğru ve uygun şekilde uygulamayı atlama."

          Bu ekran gece sisteminden ÖNCEKİ üründen kalmaydı ve üç ayrı
          dil konuşuyordu:
            · sekmeler ALT ÇİZGİLİ (Material deseni — tasarımda yok)
            · satırda 8px RENKLİ NOKTA (bilgi taşımayan bir benek)
            · okunmamışta 4px SOL ŞERİT (yine Material)

          Tasarımın kendi dili zaten var: seçim `.roz` hapıdır, kimlik
          bir VEKTÖR İKONDUR, öne çıkan kart `.kart.one`dur.

          🆕 SINIF: "BİR EKRANI TASARIM SİSTEMİNE ALMAK, RENKLERİNİ
          DEĞİŞTİRMEK DEĞİL; ORADA UYDURDUĞUM HER DESENİ SİSTEMİN ZATEN
          SAHİP OLDUĞU KARŞILIĞIYLA DEĞİŞTİRMEKTİR."
          ══════════════════════════════════════════════════════════════ */}

      {/* ══════════════════════════════════════════════════════════════
          🔴 12 EYLÜL (Gökberk md.2) — "bildirimler tasarım görseli boş
          (neden anlamadım)".
          Haklıydı ve sebebi ekranın kendisiydi, sahnenin değil: bant
          `foto` olduğunda MUTLAK konumlu (ui.js:1206). Boş/hata dalı
          `Kaydirma`nın DIŞINDA ve `paddingTop` YOK → metin y=0'dan
          başlıyor, yani BANDIN ALTINDA KALIYOR. Ölçtüm: bant tam boyda
          420 pt; "Sessizlik iyi haber" 40 pt'de çiziliyordu — 380 pt
          bandın arkasında. Ekran boş DEĞİLDİ; yazı görünmüyordu.
          Aynı kusur hata dalında da vardı: `LoadFail` de görünmüyordu,
          yani BİR AĞ HATASI KULLANICIYA BOMBOŞ EKRAN OLARAK ÇIKIYORDU.
          🆕 SINIF: "MUTLAK KONUMLU BİR BAŞLIK, ALTINDAKİ HER DALI
          KENDİ BOYU KADAR İTMEK ZORUNDADIR — YALNIZ 'ASIL' DALI DEĞİL."
          ══════════════════════════════════════════════════════════════ */}
      {hedefSatiri}
      {shown === null ? <Load /> : shown.length === 0 ? (
        <View style={{ paddingTop: bnt.ustBosluk + SP[4], paddingHorizontal: SP[4] }}>
          {yukErr ? <LoadFail t={t} onRetry={load} />
          : <BosDurum ikon="bildirim" baslik={t.notifEmpty} metin={t.notifEmptyBody} />}
        </View>
      ) : (
        <Kaydirma {...bnt.scrollProps}
           contentContainerStyle={{ padding: SP[4], paddingTop: bnt.ustBosluk + SP[4], paddingBottom: ARA[40] }}>
          {shown.map(nf => (
            <TouchableOpacity hitSlop={TAP.slop} key={nf.id} onPress={() => tap(nf)}
              accessibilityRole="button"
              // Bildirim satırında üç ayrı metin var (başlık, gövde, saat);
              // ekran okuyucu üçünü ayrı ayrı okuyup okunmamış olduğunu hiç
              // söylemiyordu. Tek bir ad + durum.
              accessibilityLabel={`${nf.title}. ${nf.body || ""}`}
              accessibilityState={{ selected: !nf.read_at }}
              // Tasarımın `.kart` / `.kart.one` ayrımı: okunmamış olan
              // altın izli kenar + çok soluk altın tint alır. 4px sol
              // şerit gitti — bu sistemde vurgu KENARIN RENGİYLE, kalın
              // bir dikey çubukla değil söyleniyor.
              /* tasarım 10 satırı: 96 yüksek · 14 iç pay · okunmamış = altın
                 iz kenar (`goldTrace`, 0.13) + %3 altın tint */
              style={[S.card, { padding: ARA[14], marginBottom: ARA[10], minHeight: 96,
                flexDirection: "row", alignItems: "flex-start" },
                !nf.read && { borderColor: C.goldTrace || C.goldLine,
                              backgroundColor: C.altinIz03 }]}>
              {/* Tasarımın `.avatar.sm` ölçüsü (36px). Renkli benek
                  yerine kategorinin VEKTÖR ikonu: bir benek "bu hangi
                  kategori" sorusunu ancak renk hafızası olanlara
                  cevaplar; ikon herkese cevaplar. */}
              <View style={{ width: 36, height: 36, borderRadius: R.full,
                             backgroundColor: C.bgAlt,
                             borderWidth: 1, borderColor: C.line2 || C.line,
                             alignItems: "center", justifyContent: "center",
                             marginRight: ARA[12] }}>
                <Ikon ad={catIkon[nf.category] || "bilgi"} boy={17}
                      renk={catColor[nf.category] || C.mut} />
              </View>
              <View style={{ flex: 1, minWidth: 0 }}>
                <View style={{ flexDirection: "row", alignItems: "flex-start" }}>
                  <Text style={{ flex: 1, fontSize: FS.base, fontWeight: "600",
                                 color: nf.read ? C.body : C.ink, marginTop: ARA[2],
                                 lineHeight: Math.round(FS.base * 1.35) }}>{nf.title}</Text>
                  {/* Saat MONO: liste boyunca değişen bir sayı ve sağa
                      hizalı — orantılı ailede sütun titrer. */}
                  <Text style={{ fontFamily: MONO[500], fontSize: FS.micro, color: C.dim,
                                 marginLeft: ARA[10], marginTop: ARA[2] }}>
                    {zamanKisa(nf.created_at, t)}</Text>
                </View>
                {!!nf.body && <Text style={{ color: C.mutedAA, fontSize: FS.sm, marginTop: ARA[6],
                                             lineHeight: Math.round(FS.sm * 1.45) }}>{nf.body}</Text>}
              </View>
            </TouchableOpacity>
          ))}
        </Kaydirma>
      )}
    </Sayfa>
  );
}
export function Marketplace({ t, session, onBack }) {
  const uid = session?.user?.id;
  const [rewards, setRewards] = useState(null);
  const [bal, setBal] = useState(0);
  const [mine, setMine] = useState({});
  const [busy, setBusy] = useState(null);
  const [cat, setCat] = useState("all");   // #16: MVP kategori sekmeleri
  const [err, setErr] = useState("");
  const [yukErr, setYukErr] = useState("");

  const load = useCallback(async () => {
    // 🔴 v2.99 — `error` OKUNMUYORDU: ag koptugunda kullanici BOS BIR ODUL
    // IZGARASI goruyor ve "odul yok" saniyordu. Hata, "bos" kiligina giren
    // en pahali sinif.
    // 🆕 SINIF: "BOS DURUM DAVET EDER, HATA DURUMU YENIDEN DENEMEYE CAGIRIR
    // — IKISI AYNI EKRAN OLAMAZ."
    const [{ data: rw, error: e1 }, { data: pl }, { data: rd }] = await Promise.all([
      supabase.from("rewards").select("*").eq("active", true).order("sort_order"),
      supabase.from("points_ledger").select("delta").eq("user_id", uid),
      supabase.from("redemptions").select("reward_id, voucher_code").eq("user_id", uid),
    ]);
    if (e1) { logError("marketplace_rewards", e1); setYukErr(mapErr(t, e1.message)); setRewards([]); return; }
    setYukErr("");
    setRewards(rw || []);
    setBal((pl || []).reduce((s, r) => s + r.delta, 0));
    const m = {}; (rd || []).forEach(r => { m[r.reward_id] = r.voucher_code; });
    setMine(m);
  }, [uid]);
  useEffect(() => { load(); }, [load]);

  async function redeem(rw) {
    setBusy(rw.id);
    setErr("");
    const { error } = await supabase.rpc("redeem_reward", { p_reward_id: rw.id });
    setBusy(null);
    // 🔴 v2.99 — HATA DALI YOKTU. Kullanici "Kullan"a basiyor, dugme bir an
    // donuyor ve eski haline geliyordu. Kupon gelmiyor, mesaj cikmiyor.
    // Sunucu "yetersiz puan" / "stok bitti" / "zaten alinmis" dese bile ayni
    // hiclik. Ayni kusur `ActionNeeded` ve `RequestsPanel`de tespit edilip
    // duzeltilmisti; UCUNCU ekranda tekrar etmis.
    // 🆕 SINIF: "BIR KUSURUN IKI YERDE DUZELTILMESI, UCUNCU YERDE
    // DUZELTILDIGI ANLAMINA GELMEZ — SINIFI ARA, ORNEGI DEGIL."
    if (error) { logError("redeem_reward", error); setErr(mapErr(t, error.message)); return; }
    if (!error) load();
  }

  if (rewards === null) return <Load t={t} title={t.shopTitle} onBack={onBack} />;
  // 🔴 v3.7 — ÖDÜL KATEGORİSİ İKONLARI da emoji taşıyordu; beşi de
  // gövde fontunda yok. Anlam adlarına çevrildi.
  const icon = { lounge: "odulSalon", miles: "odulMil", hotel: "odulOtel", esim: "odulEsim", insurance: "odulSigorta" };

  return (
    <Sayfa>
    {/* MVP: başlık + sağda puan bakiyesi (kompakt) */}
    {/* 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: kupa ikonu, başlık ve puan pill'i
        DURUM ÇUBUĞUNUN ALTINA giriyordu. Bu ekran ortak Hdr'ı kullanmıyor
        (kendi başlığını çiziyor) ve güvenli alan payını kimse eklememişti.
        Ortak başlıkla aynı payı burada da uyguluyoruz. */}
    <View style={{ backgroundColor: C.card, borderBottomWidth: 1, borderBottomColor: C.line,
                   paddingTop: TOPPAD }}>
      <View style={{ height: 52, flexDirection: "row", alignItems: "center", paddingHorizontal: ARA[14] }}>
        <TouchableOpacity hitSlop={TAP.slop} onPress={onBack} style={{ paddingRight: ARA[10] }}
          accessibilityRole="button" accessibilityLabel={t.back}><Ikon ad="sol" boy={FS.display} renk={C.goldText} /></TouchableOpacity>
        {/* v1.82: başlık + bakiye hizası bozuktu (ikon başlıkla, sayı etiketiyle
            farklı satır yüksekliklerindeydi). Bakiye tek satırlık ALTIN PİLL
            oldu; başlık tek satırda dengeli duruyor. */}
        <Text style={{ flex: 1, fontSize: FS.lg, fontWeight: "700", color: C.ink }} numberOfLines={1}>
          {t.marketTitle}
        </Text>
        <View style={{ backgroundColor: C.goldBg, borderRadius: R.sm, paddingVertical: SP[1], paddingHorizontal: SP[3] }}>
          <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.goldText }}>{bal.toLocaleString()} {t.points}</Text>
        </View>
      </View>
      {!!(err || yukErr) && (
        <View style={{ backgroundColor: C.hataBg, borderRadius: R.xs, padding: SP[3], marginHorizontal: ARA[14], marginBottom: SP[2] }}>
          <Text style={{ color: C.redInk, fontSize: FS.sm }}>{err || yukErr}</Text>
          {!!yukErr && (
            <TouchableOpacity onPress={load} hitSlop={TAP.slop}
              style={{ minHeight: 44, justifyContent: "center" }}>
              <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>{t.retry || "Yeniden dene"}</Text>
            </TouchableOpacity>
          )}
        </View>
      )}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: ARA[14] }}>
        {[["all", t.catAll], ["lounge", "Lounge"], ["hotel", t.catHotel], ["miles", t.catMiles], ["esim", "eSIM"], ["insurance", t.catInsurance]].map(([k, lb]) => (
          <TouchableOpacity hitSlop={TAP.slop} key={k} onPress={() => setCat(k)}
            style={{ paddingVertical: SP[2], paddingHorizontal: SP[3], borderBottomWidth: 2.5, borderBottomColor: cat === k ? C.gold : "transparent" }}>
            <Text style={{ fontSize: FS.sm, color: cat === k ? C.gold : C.mut, fontWeight: cat === k ? "700" : "400" }}>{lb}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
    <ScrollView contentContainerStyle={{ padding: ARA[10], paddingBottom: ARA[40] }}>
      {/* MVP: 2 sütunlu ürün gridi */}
      <View style={{ flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between" }}>
      {/* 🔴 v1.93 — KAHRAMAN KART.
          Sekiz ödül eşit ağırlıkta dururken "hangisi bana göre?" sorusu
          kullanıcıya yıkılıyordu; eşit ağırlıklı liste çoğu zaman hiç
          seçim üretmez. Tek kahraman, listenin geri kalanını da okunur
          yapar. Hangi ödülün kahraman olacağı BO'dan seçilir (tek kahraman
          kuralı veritabanında kısmi benzersiz indeksle garanti). */}
      {(() => {
        const hero = rewards.find(r => r.is_featured);
        if (!hero || (cat !== "all" && hero.category !== cat)) return null;
        const owned = mine[hero.id];
        const short = Math.max(0, (hero.cost_points || 0) - bal);
        return (
          <TouchableOpacity hitSlop={TAP.slop} activeOpacity={0.85} disabled={!!owned || short > 0}
            onPress={() => redeem(hero)}
            style={{ backgroundColor: C.gece, borderRadius: R.sm, padding: ARA[18], marginBottom: SP[4], ...ELEV.raised }}>
            <Text style={{ ...T.label, color: C.gold, marginBottom: ARA[6] }}>{t.shopHeroReward}</Text>
            <Text style={{ ...T.title, fontWeight: "700", color: C.onAccent }}>{hero.title}</Text>
            {!!hero.subtitle && (
              <Text style={{ ...T.sm, color: C.coolLine, marginTop: SP[1] }}>{hero.subtitle}</Text>
            )}
            {!!hero.featured_note && (
              <Text style={{ ...T.sm, color: C.gold, marginTop: ARA[6], fontWeight: "700" }}>{hero.featured_note}</Text>
            )}
            <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[14] }}>
              <Text style={{ ...T.lg, fontWeight: "700", color: C.gold, flex: 1 }}>
                {(hero.cost_points || 0).toLocaleString()} {t.pointsUnit || "puan"}
              </Text>
              <View style={{ backgroundColor: owned ? C.pasifRozet : short > 0 ? C.pasifRozet : C.gold,
                             borderRadius: R.xs, paddingVertical: SP[2], paddingHorizontal: ARA[18] }}>
                <Text style={{ color: C.onAccent, ...T.sm, fontWeight: "700" }}>
                  {owned ? (t.shopOwned || "Alındı") : short > 0 ? (t.shopShort || "Yetersiz") : (t.shopRedeem || "Kullan")}
                </Text>
              </View>
            </View>
          </TouchableOpacity>
        );
      })()}
      {rewards.filter(r => (cat === "all" || r.category === cat) && !r.is_featured).map(rw => {
        const has = mine[rw.id];
        const can = bal >= rw.cost_points;
        return (
          <View key={rw.id} style={{ width: "48.5%", backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, padding: SP[3], marginBottom: SP[2], opacity: (can || has) ? 1 : 0.6 , ...ELEV.card }}>
            <Ikon ad={icon[rw.category] || "davet"} boy={26} renk={C.goldText} stil={{ marginBottom: SP[2] }} />
            <Text style={{ fontWeight: "600", color: C.ink, fontSize: FS.sm, marginBottom: SP[1], lineHeight: 16 }}>{rw.title}</Text>
            {!!rw.subtitle && <Text style={{ color: C.mut, fontSize: FS.xs, marginBottom: ARA[10] }}>{rw.subtitle}</Text>}
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: SP[1] }}>
              {/* v1.82: fiyat ile butondaki "eksik puan" yan yana İKİ SAYI gibi
                  okunuyordu ("1.500  +1.500"). Fiyatın yanına birim yazıldı,
                  buton artık sayı değil DURUM söylüyor. */}
              <Text style={{ fontSize: FS.xs, fontWeight: "600", color: has ? C.green : C.gold }}>
                {has ? t.redeemed : `${rw.cost_points.toLocaleString()} ${t.points}`}
              </Text>
              {!has && (
                <Btn v={can ? "gold" : "muted"} mini onPress={() => redeem(rw)}
                  disabled={!can || busy === rw.id} busy={busy === rw.id}
                  label={can ? t.redeem : t.notEnoughPoints} />
              )}
            </View>
            {has && <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2], marginTop: SP[2] }}>
              <Text style={{ fontSize: FS.micro, color: C.mutedAA, textAlign: "center" }}>{t.voucherIs}: {has}</Text>
            </View>}
          </View>
        );
      })}
      </View>

      {/* MVP: puan sona erme uyarısı */}
      <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: C.amber + "25", borderRadius: R.sm, padding: SP[3], marginTop: SP[1], marginBottom: SP[3] }}>
        <IkonMetin ad="uyari" renk={C.amberInk} stilMetin={{ fontSize: FS.xs, color: C.amberInk, lineHeight: 16 }} metin={t.pointsExpire} />
      </View>

      {/* MVP: nasıl daha çok puan kazanılır */}
      <View style={[S.card, { marginBottom: SP[4] }]}>
        <View style={{ flexDirection: "row", alignItems: "center" }}><Ikon ad="puan" boy={15} renk={C.mutedAA} stil={{ marginRight: SP[1] }} /><Text style={{ fontSize: FS.sm, fontWeight: "600", color: C.ink, marginBottom: ARA[10] }}>{t.earnMoreTitle}</Text></View>
        {[[t.earnSession, t.earnSessionD], [t.earnInvite, t.earnInviteD], [t.earnId, t.earnIdD], [t.earnLinkedin, t.earnLinkedinD]].map(([ti, de], i, arr) => (
          <View key={ti} style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: SP[2], borderBottomWidth: i < arr.length - 1 ? 1 : 0, borderBottomColor: C.line }}>
            <Text style={{ fontSize: FS.sm, color: C.body }}>{ti}</Text>
            <Text style={{ fontSize: FS.xs, color: C.gold, fontWeight: "600" }}>{de}</Text>
          </View>
        ))}
      </View>

      {/* 🔴 v2.94 — MARKA CÜMLESİ.
          "Açtığın kapı, sana bir kapı açar." Ürünün karşılıklılık
          sözleşmesini tek cümlede anlatıyor ve kredi oranının 1:1 olmasıyla
          artık BİREBİR doğru: bir ağırlama = bir misafirlik hakkı. Sayı 3
          iken bu cümle kurulamazdı. */}
      <Text style={{ fontSize: FS.lg, color: C.gold, textAlign: "center",
                     lineHeight: 24, marginBottom: SP[4], paddingHorizontal: SP[3] }}>
        {t.motto}
      </Text>
    </ScrollView>
    </Sayfa>
  );
}
export function Plans({ t, session, onBack, lang }) {
  // ============================================================
  // v2.76 — ABONELİK EKRANI YENİDEN KURULDU
  //
  // 🔴 ÜÇ SORUN VARDI:
  //  1. `plan_catalog` tablosunu DOĞRUDAN okuyordu. SQL 210 eski üç
  //     planı pasife aldı (silmedi — kullanıcıların `users.plan`
  //     değeri çözümsüz kalmasın diye); ekran hepsini basardı.
  //  2. Plan adları JS'te sabit bir haritada (`names`) duruyordu.
  //     Veritabanında ad varken kodda ikinci bir kopya tutmak, iki
  //     yerin ayrışmasını beklemekten başka bir şey değil.
  //  3. Ürünün en önemli abonelik kuralını HİÇ göstermiyordu:
  //     AĞIRLAYAN KİŞİ PARA ÖDEMEZ. Ayda 2 ağırlama üst planı
  //     ücretsiz açıyor — bu, aboneliği bir maliyet olmaktan
  //     çıkarıp arz tarafına teşvike çeviren tek mekanizma ve
  //     ekranda görünmüyorsa yok demektir.
  // ============================================================
  const uid = session?.user?.id;
  const [plans, setPlans] = useState(null);
  const [durum, setDurum] = useState(null);       // my_plan()
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState("");
  const [yillik, setYillik] = useState(false);

  const load = useCallback(async () => {
    const [{ data: pl, error: e1 }, { data: mp, error: e2 }] = await Promise.all([
      // 🔴 v2.79 — DİL PARAMETRESİ. Plan adı ve ayrıcalıklar bugüne kadar
      // veritabanından ham Türkçe geliyordu; EN'e geçen kullanıcı hem plan
      // adını hem altındaki maddeleri Türkçe görüyordu. i18n'de duran
      // planExplorer/planTraveler/planFrequent anahtarları ise ÖLÜYDÜ —
      // hiçbir yerden çağrılmıyordu, yani çeviri "var gibi" duruyordu.
      // Karşılık boşsa sunucu Türkçesine düşer: boş ekran, yanlış dilden kötü.
      supabase.rpc("subscription_plans", { p_lang: lang || "tr" }),
      supabase.rpc("my_plan"),
    ]);
    if (e1) console.warn("subscription_plans:", e1.message);
    if (e2) console.warn("my_plan:", e2.message);
    setPlans(Array.isArray(pl) ? pl : []);
    setDurum(mp && mp.known ? mp : null);
  }, [uid, lang]);
  useEffect(() => { load(); }, [load]);

  // 🔴 v2.99 — `change_plan` İSTEMCİDEN KALDIRILDI. İKİ SEBEP, İKİSİ DE AĞIR:
  //
  // (1) GÜVENLİK — ÖLÇÜLDÜ. Fonksiyon hiçbir ödeme kanıtı aramıyordu:
  //     yolcu → kahya çağrısı 249 ₺'lik planı bedava veriyor ve +11 kredi
  //     basıyordu. Yükselt/indir döngüsüyle 7 çağrıda 4 kredi 48 oldu.
  //     Kredi ekonomisinin tamamı tek RPC ile çökebiliyordu. (SQL 253 §2)
  //
  // (2) MAĞAZA — Apple Guideline 3.1.1: uygulamanın içinden satılan dijital
  //     hak IAP ile satılmak zorunda. Ödeme adımı, "Satın alımları geri
  //     yükle", otomatik yenileme koşulları — hiçbiri yoktu ama ekran
  //     ₺ fiyatlı aylık/yıllık planları listeleyip TEK DOKUNUŞLA
  //     uyguluyordu. Bu, incelemeden dönmenin en bilinen yollarından biri.
  //
  // 🆕 SINIF: "ÖDEME ADIMI OLMAYAN BİR SATIN ALMA EKRANI, SATIN ALMA DEĞİL
  // BEDAVA DAĞITIMDIR — VE MAĞAZA ONU SATIN ALMA SAYAR."
  //
  // Ekran BİLGİLENDİRME olarak kalıyor: planlar, neyi içerdikleri ve
  // "ağırlayan kişi para ödemez" kuralı görünüyor. Yükseltme, ödeme
  // entegrasyonu (Stripe/IAP) bağlanana kadar destek üzerinden.
  function choose(plan) {
    setMsg(t.plansUpgradeSoon);
  }

  if (plans === null) return <Load t={t} title={t.plansTitle} onBack={onBack} />;

  return (
    <Sayfa>
      <Hdr t={t} scene="PLAN" title={t.plansTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>

        {/* 🔴 EN ÜSTTE: AĞIRLARSAN ÖDEMEZSİN.
            Bu kart, fiyat listesinden ÖNCE geliyor ve sırası bir tez:
            kullanıcı fiyatları görmeden önce ödememenin yolunu
            öğrenmeli. Cümle motordan geliyor (`my_plan().neden`) —
            eşik BO'dan değişince ekran kendiliğinden düzelir. */}
        {!!durum && (
          <View style={{
            backgroundColor: durum.ucretsiz_yukseltme ? C.tealBg : C.goldBg,
            borderWidth: 1, borderColor: durum.ucretsiz_yukseltme ? C.tealLine : C.goldLine,
            borderRadius: R.sm, padding: SP[4], marginBottom: SP[4],
          }}>
            <Text style={[T.label, { color: durum.ucretsiz_yukseltme ? C.teal : C.gold, marginBottom: SP[2] }]}>
              {durum.ucretsiz_yukseltme ? t.planFreeUpgradeLabel : t.planHostLabel}
            </Text>
            <Text style={{ fontSize: FS.lg, lineHeight: 24, fontWeight: "700", color: C.ink }}>
              {durum.ad}
            </Text>
            <Text style={[T.sm, { color: C.body, marginTop: SP[1] }]}>{durum.neden}</Text>
            {/* 🔴 v2.89 (Gökberk md.7) — "1 AYLIĞINA" GÖRÜNÜR OLDU.
                Eski cümle "üst plan ücretsiz açılır" diyordu ve SÜRESİNİ
                söylemiyordu. Daha kötüsü: sistem gerçekten de süre
                TUTMUYORDU — hediye her çağrıda "bu takvim ayında kaç
                oturum" diye yeniden hesaplanıyordu, yani ayın 28'inde
                hak eden 3 gün alıyordu ve ayın 1'inde hediye SESSİZCE
                bitiyordu (ne bildirim, ne kayıt).
                SQL 236 hediyeyi bir KAYDA çevirdi: başlangıcı, bitişi ve
                geri sayımı var. Aşağıdaki satır o kaydı gösteriyor. */}
            {durum.hediye_gun_kaldi != null ? (
              <View style={{ flexDirection: "row", alignItems: "center", gap: SP[2], marginTop: SP[2] }}>
                <View style={{ backgroundColor: C.card, borderRadius: R.full, paddingVertical: SP[1], paddingHorizontal: ARA[10] }}>
                  <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.tealInk }}>
                    {String(t.planGiftLeft).replace("{n}", String(durum.hediye_gun_kaldi))}
                  </Text>
                </View>
                {durum.hediye_biter ? (
                  <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, fontSize: FS.xs, color: C.mut }}>
                    {String(t.planGiftEnds).replace("{d}",
                      new Date(durum.hediye_biter).toLocaleDateString("tr-TR"))}
                  </Text>
                ) : null}
              </View>
            ) : null}
          </View>
        )}

        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[3] }}>{t.plansSub}</Text>

        {/* Aylık / yıllık — indirim oranı VERİDEN geliyor, elle yazılmıyor */}
        <View style={{ flexDirection: "row", backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[1], marginBottom: SP[4] }}>
          {[[false, t.planCycleMonthly], [true, t.planCycleYearly]].map(([v, l]) => (
            <Secim key={String(v)} bicim="segment" ton="gold" zemin="yok" secili={yillik === v}
              etiket={l} onPress={() => setYillik(v)} />
          ))}
        </View>

        {plans.map(p => {
          const isCur = durum && durum.etkin === p.plan;
          const perks = Array.isArray(p.haklar) ? p.haklar : [];
          // 🔴 v2.87 — HER PLAN "ÜCRETSİZ" YAZIYORDU (Gökberk madde 8).
          // KÖK NEDEN ÖLÇÜLDÜ, tahmin edilmedi: SQL 220 `subscription_plans`ı
          // yeniden yazarken alan adlarını DEĞİŞTİRDİ —
          //     210: 'fiyat_try', 'yillik_try'
          //     220: 'aylik_fiyat', 'yillik_fiyat'   (etkin tanım)
          // Ekran 210'un adlarını okumaya devam ediyordu. `p.fiyat_try`
          // artık her plan için `undefined` dönüyor, `!ucret` true oluyor ve
          // ekran "Ücretsiz" basıyordu. Yani 249 ₺'lik plan bedava
          // görünüyordu — yanlış fiyat, fiyatsızlıktan beter.
          // İki düzeltme:
          //  1. Etkin adlar (`aylik_fiyat`/`yillik_fiyat`/`aylik_kredi`)
          //     okunuyor; eski adlar yedek olarak duruyor ki 220 öncesi bir
          //     sunucuya bağlanan eski cihaz da doğru fiyatı görsün.
          //  2. "Ücretsiz" YALNIZCA fiyat gerçekten 0 ise yazılır. Alan hiç
          //     okunamıyorsa ekran bunu SÖYLER; sessizce "bedava" demez —
          //     aynı sınıf hata bir daha aynı şekilde gizlenemez.
          const ilkSayi = (...a) => { for (const v of a) if (v != null && v !== "" && !Number.isNaN(Number(v))) return Number(v); return null; };
          const aylik    = ilkSayi(p.aylik_fiyat, p.fiyat_try);
          const yilFiyat = ilkSayi(p.yillik_fiyat, p.yillik_try);
          const ucret = yillik ? yilFiyat : aylik;
          // Aylık kredi hakkı — `plan_catalog.monthly_credits`, RPC'de
          // 'aylik_kredi'. Ürünün aboneliğe bağlı TEK somut hakkı bu ve
          // ekranda hiç yoktu: "249 ₺ ödersem ne alıyorum?" sorusunun
          // cevabı yazmıyordu.
          const krediAy = ilkSayi(p.aylik_kredi, p.monthly_credits);
          return (
            <View key={p.plan} style={{
              backgroundColor: isCur ? C.goldSoft : C.card,
              borderWidth: 1.5, borderColor: isCur ? C.gold : C.line,
              borderRadius: R.sm, padding: SP[4], marginBottom: SP[3],
            }}>
              <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink }}>{p.ad}</Text>
                {isCur && <Text style={{ color: C.goldText, fontSize: FS.xs, fontWeight: "700", letterSpacing: 1 }}>{t.currentPlan}</Text>}
              </View>

              <Text style={{ marginTop: SP[1], color: C.gold, fontSize: FS.title, fontWeight: "700" }}>
                {ucret == null ? t.planPriceUnknown : ucret === 0 ? t.free : `₺${ucret}`}
                {ucret > 0 && (
                  <Text style={{ fontSize: FS.sm, color: C.mut, fontWeight: "400" }}>
                    {yillik ? t.planPerYear : ` ${t.perMonth}`}
                  </Text>
                )}
              </Text>
              {yillik && !!p.yillik_indirim_yuzde && (
                <Text style={[T.xs, { color: C.teal, marginTop: ARA[2], fontWeight: "700" }]}>
                  {String(t.planDiscount).replace("{n}", String(p.yillik_indirim_yuzde))}
                </Text>
              )}

              {/* 🔴 v2.87 (madde 8) — "KREDİ HAKKI NEDEN YOK?"
                  Gökberk'in sorusu bir eksiklik değil, doğrudan bir kusur
                  bildirimiydi: `plan_catalog.monthly_credits` (Yolcu 2 ·
                  Sık Uçan 6 · Kâhya 12) v2.80'de gerçekten dağıtılmaya
                  başlandı (App.js `plan_kredisi_yerlestir`) ama SATIN ALMA
                  EKRANINDA hiç yazmıyordu. Verilen ama söylenmeyen hak,
                  hiç verilmemiş haktır.
                  Ayrıcalıkların EN ÜSTÜNDE ve sayıyla duruyor: listedeki
                  cümlelerin arasına karışan bir madde değil, planın somut
                  karşılığı. */}
              {krediAy != null && krediAy > 0 && (
                // 🔴 12 EYLÜL (Gökberk md.6) — "plan sayfasında ayda x kredi
                // yazan yerin yanındaki icon bitişik duruyor text ile".
                // Doğru: ikonun `stil`i hiç verilmemişti, yani sağ boşluğu
                // 0 pt. Uygulamadaki diğer 40+ satır-içi ikonun hepsinde
                // `marginRight` var; burada unutulmuştu. `alignItems` de
                // "center"dan "flex-start"a geçti — kutu iki satır ve ikon
                // ikisinin ortasında asılı duruyordu.
                <View style={{ flexDirection: "row", alignItems: "flex-start", marginTop: SP[3],
                               backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.tealLine,
                               borderRadius: R.xs, paddingVertical: SP[2], paddingHorizontal: ARA[10] }}>
                  <Ikon ad="kutlama" boy={FS.lg} renk={C.mut} stil={{ marginRight: ARA[8], marginTop: ARA[2] }} />
                  <View style={{ flex: 1, minWidth: 0 }}>
                    <Text style={{ color: C.tealInk, fontSize: FS.base, fontWeight: "700" }}>
                      {String(t.planMonthlyCredits).replace("{n}", String(krediAy))}
                    </Text>
                    <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 15, marginTop: 0 }}>
                      {t.planMonthlyCreditsWhy}
                    </Text>
                  </View>
                </View>
              )}

              {/* v2.87: ayrıcalıklar taranabilir olsun diye madde işareti
                  metnin AKIŞINDAN çıkarıldı — ✓ artık ayrı bir sütunda ve
                  uzun maddeler ikinci satırda hizada kalıyor. Eskiden
                  "✓ " metnin içindeydi ve sarma satırlar sola kayıyordu. */}
              <View style={{ marginTop: SP[3] }}>
                {perks.map((perk, i) => (
                  // 12 Eylül md.6'nın aynı sınıfı: ✓ ile metin arası 0 pt'ydi
                  // (sahne ölçümü: −0.3 pt, yani harfe değiyordu).
                  <View key={i} style={{ flexDirection: "row", marginBottom: SP[1] }}>
                    <Ikon ad="tamam" boy={FS.sm} renk={C.green} stil={{ marginRight: ARA[6], marginTop: ARA[2] }} />
                    <Text style={{ flex: 1, minWidth: 0, color: C.body, fontSize: FS.sm, lineHeight: 18 }}>{perk}</Text>
                  </View>
                ))}
                {perks.length === 0 && krediAy == null && (
                  <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18 }}>{t.planPerksUnknown}</Text>
                )}
              </View>

              {isCur ? (
                <View style={{ backgroundColor: C.goldBtn + "20", borderRadius: R.xs, paddingVertical: SP[2], alignItems: "center", marginTop: SP[3] }}>
                  <Text style={{ color: C.gold, fontWeight: "700", fontSize: FS.sm }}>{t.current}</Text>
                </View>
              ) : (
                <Btn v="gold" sm label={t.choosePlan} onPress={() => choose(p.plan)} disabled={busy === p.plan} busy={busy === p.plan} style={{ marginTop: SP[3] }} />
              )}
            </View>
          );
        })}

        {/* 🔴 KREDİ SATMIYORUZ — ve bunu AÇIKÇA söylüyoruz.
            Ürünün cümlesi "kullanmadığın hakkı çevir". Krediyi
            parayla satmak o cümleyi bozar; söylemezsek kullanıcı
            "neden kredi paketi yok" diye sorar ve cevabı bilmez. */}
        <View style={{ backgroundColor: C.bgAlt, borderRadius: R.sm, padding: SP[4], marginTop: SP[2] }}>
          <Text style={[T.sm, { color: C.body, lineHeight: 19 }]}>{t.planNoCreditSale}</Text>
        </View>

        {!!msg && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{msg}</Text></View>}
        <Text style={{ color: C.mutedAA, fontSize: FS.xs, textAlign: "center", marginTop: SP[2], lineHeight: 17 }}>{t.upgradeNote}</Text>
      </ScrollView>
    </Sayfa>
  );
}

// Profil fotoğrafı: Supabase Storage'a yükler, profiles.photo_url'e yazar
export function Degerlendirmeler({ t, lang, session, onBack, onRate, onOpenProfile }) {
  const [rows, setRows] = useState(null);
  const [loadErr, setLoadErr] = useState(false);
  const [sekme, setSekme] = useState("bekleyen");
  const [busy, setBusy] = useState(null);
  const [err, setErr] = useState("");
  // 19 Eylül · derin denetim — değerlendirme silme artık onay istiyor.
  const [silAdayi, setSilAdayi] = useState(null);

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("degerlendirmelerim");
    if (error) { logError("degerlendirmelerim", error); setLoadErr(true); return; }
    setLoadErr(false); setRows(Array.isArray(data) ? data : []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const bekleyen   = (rows || []).filter(r => r.durum === "bekleyen");
  const tamamlanan = (rows || []).filter(r => r.durum === "tamamlanan");
  const liste = sekme === "bekleyen" ? bekleyen : tamamlanan;

  function baglam(r) {
    return [r.salon, r.airport_code,
            r.avail_date ? fmtLongDate(r.avail_date, lang) : null,
            (r.time_from && r.time_to)
              ? `${String(r.time_from).slice(0,5)}–${String(r.time_to).slice(0,5)}` : null,
           ].filter(Boolean).join(" · ");
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneTrust} title={t.ratingsTitle} sub={t.ratingsSub} onBack={onBack} />
      <View style={{ flexDirection: "row", backgroundColor: C.card, borderBottomWidth: 1, borderBottomColor: C.line }}>
        {[["bekleyen", t.ratingsPending, bekleyen.length],
          ["tamamlanan", t.ratingsDone, tamamlanan.length]].map(([k, lb, n]) => (
          <TouchableOpacity hitSlop={TAP.slop} key={k} onPress={() => setSekme(k)}
            accessibilityRole="button" accessibilityState={{ selected: sekme === k }}
            style={{ flex: 1, paddingVertical: SP[3], alignItems: "center",
                     borderBottomWidth: 2, borderBottomColor: sekme === k ? C.gold : "transparent" }}>
            <Text style={{ color: sekme === k ? C.gold : C.mut, fontWeight: "700", fontSize: FS.sm }}>
              {lb}{n ? ` · ${n}` : ""}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
        {/* 🔴 "Ağırlaman nasıl geçti?" (bir cümle) ile "Oturumu puanla"
            AYNI SORUNUN iki yarısı: biten bir oturumun senden hâlâ
            istediği şey. Gökberk ikisini tek başlık altında düşünmüş
            ("Değerlendirmeler") ve haklı — ana sayfada iki ayrı kart,
            bu ekranda tek yer. Ana sayfada hiç görmeyen ya da "şimdi
            değil" diyen kullanıcı artık BURADA bulur. */}
        {sekme === "bekleyen" && <HikayeDaveti t={t} lang={lang} hepAcik onDone={load} />}
        {loadErr ? <LoadFail t={t} onRetry={load} />
        : rows === null ? <Load />
        : liste.length === 0 ? (
          <View style={S.empty}>
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", lineHeight: 18 }}>
              {sekme === "bekleyen" ? t.ratingsNonePending : t.ratingsNoneDone}
            </Text>
          </View>
        ) : liste.map(r => (
          <View key={r.session_id} style={S.card}>
            {/* HANGİ OTURUM — Gökberk'in açık şartı: "hangi oturuma ait
                olduğu açıkça belirtilmeli". Kimlik satırı ile bağlam satırı
                AYRI: kişi kim, oturum hangisi. */}
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              <View style={{ flex: 1, minWidth: 0, marginRight: SP[2] }}>
                <TouchableOpacity hitSlop={TAP.slop} disabled={!onOpenProfile}
                  onPress={() => onOpenProfile && onOpenProfile(r.other_id)} activeOpacity={0.7}
                  accessibilityRole="button" accessibilityLabel={r.other_name}>
                  <Text numberOfLines={1} style={{ fontSize: FS.base, fontWeight: "700", color: C.ink }}>
                    {shortName(r.other_name)}
                  </Text>
                </TouchableOpacity>
                <Text numberOfLines={2} style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[1], lineHeight: 17 }}>
                  {baglam(r)}
                </Text>
              </View>
              <View style={{ flexShrink: 0, backgroundColor: r.i_am_host ? C.tealBg : C.goldBg,
                             borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] }}>
                <Text style={{ fontSize: FS.xs, fontWeight: "600", color: r.i_am_host ? C.teal : C.gold }}>
                  {r.i_am_host ? t.ratingRoleHost : t.ratingRoleGuest}
                </Text>
              </View>
            </View>

            {sekme === "bekleyen" ? (
              <Btn v="gold" sm label={`${t.rateNow}`} solAd="degerlendirme" onPress={() => onRate && onRate(r)} a11yLabel={t.rateNow} style={{ marginTop: SP[3] }} />
            ) : (
              <>
                <View style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[10] }}>
                  {/* 🔴 30 Ağu · 3. tur — YILDIZLAR ARTIK VEKTÖR.
                      `"★".repeat(n)` gövde fontunun `★` glifini beş kez
                      basıyordu: dolu/boş ayrımı yalnız RENKLE yapılıyor,
                      genişlik cihazdan cihaza değişiyor ve satır kayıyordu.
                      Beş ayrı `<Ikon>`: dolu olan `degerlendirmeDolu`. */}
                  <View style={{ flexDirection: "row", alignItems: "center" }}>
                    {[1, 2, 3, 4, 5].map(n => (
                      <Ikon key={n} ad={n <= (r.puan || 0) ? "degerlendirmeDolu" : "degerlendirme"}
                            boy={15} kutu={17} renk={n <= (r.puan || 0) ? C.gold : C.line} />
                    ))}
                  </View>
                  <Text style={{ fontSize: FS.xs, color: C.mut, marginLeft: SP[2] }}>
                    {r.verildi_at ? new Date(r.verildi_at).toLocaleDateString("tr-TR") : ""}
                  </Text>
                </View>
                {!!r.yorum && (
                  <Text style={{ fontSize: FS.sm, color: C.body, marginTop: ARA[6], fontStyle: "italic", lineHeight: 18 }}>
                    "{r.yorum}"
                  </Text>
                )}
                {/* Değerlendirmeyi geri alma HAKKI: verdiğim puanı
                    kaldırabilmeliyim. `remove_rating` sunucuda vardı ve
                    hiçbir ekran çağırmıyordu. */}
                {/* ══════════════════════════════════════════════════
                    🔴 19 EYLÜL · DERİN DENETİM — ONAY EKLENDİ.
                    Aynı üründe bir BAĞLANTIYI kaldırmak iki adım
                    (`ekranlar_ana.js` ConfirmModal), bir SEYAHATİ silmek
                    iki adım — ama yazdığın değerlendirmeyi silmek TEK
                    DOKUNUŞTU ve geri dönüşü yok. Listede kaydırırken
                    kırmızı metne yanlışlıkla dokunmak, yazdığın yorumu
                    kalıcı olarak siliyordu.
                    🆕 SINIF: "YIKICI EYLEMLERDE ONAY BİR TERCİH DEĞİL BİR
                    TUTARLILIKTIR — BİRİNDE SORUP ÖTEKİNDE SORMAMAK,
                    KULLANICIYA HANGİSİNİN CİDDİ OLDUĞUNU YANLIŞ ÖĞRETİR."
                    ══════════════════════════════════════════════════ */}
                <TouchableOpacity hitSlop={TAP.slop} disabled={busy === r.rating_id}
                  /* `degerlendirmelerim()` alan adı `other_name` — ilk yazımda
                      `karsi_ad` yazmıştım ve `rpc_field_e2e` yakaladı:
                      "kod okuyor, veritabanı üretmiyor". Çökmüyor, sessizce
                      boş görünüyordu. */
                  onPress={() => setSilAdayi({ id: r.rating_id, ad: r.other_name || "" })}
                  accessibilityRole="button" accessibilityLabel={t.ratingRemove}
                  style={{ marginTop: ARA[10], minHeight: TAP.minHeight, justifyContent: "center" }}>
                  <Text style={{ color: C.red, fontSize: FS.sm }}>{busy === r.rating_id ? "…" : t.ratingRemove}</Text>
                </TouchableOpacity>
              </>
            )}
          </View>
        ))}
      </ScrollView>
      <ConfirmModal
        visible={!!silAdayi}
        title={t.ratingRemoveTitle}
        body={String(t.ratingRemoveBody || "").replace("{ad}", silAdayi?.ad || "")}
        confirmLabel={t.ratingRemove}
        cancelLabel={t.confirmNo}
        danger
        busy={busy === silAdayi?.id}
        onCancel={() => setSilAdayi(null)}
        onConfirm={async () => {
          const id = silAdayi?.id; if (!id) return;
          setBusy(id); setErr("");
          const { error } = await supabase.rpc("remove_rating", { p_rating_id: id });
          setBusy(null); setSilAdayi(null);
          if (error) { setErr(mapErr(t, error.message)); return; }
          load();
        }}
      />
    </Sayfa>
  );
}
export function LiveStatusPicker({ t, sess, isHost, uid }) {
  const savedMine = isHost ? sess.host_status : sess.guest_status;
  const savedOther = isHost ? sess.guest_status : sess.host_status;
  const [myStatus, setMyStatus] = useState(savedMine || null);
  const [shared, setShared] = useState(!!savedMine);
  const [busy, setBusy] = useState(false);
  const opts = isHost
    ? [t.lsHost1, t.lsHost2, t.lsHost3, t.lsHost4]
    : [t.lsGuest1, t.lsGuest2, t.lsGuest3, t.lsGuest4, t.lsGuest5];
  async function share() {
    if (!myStatus) return;
    setBusy(true);
    const { error } = await supabase.rpc("share_session_status", { p_session_id: sess.id, p_status: myStatus });
    // 🔴 v1.81 (Gokberk 5. madde): seçilen durum HİÇBİR YERE yansımıyordu —
    // yalnız sessions tablosuna yazılıyor, karşı taraf onu göreceği bir ekran
    // olmadığı için hiç öğrenmiyordu. Durum artık SOHBETE de düşüyor; iki
    // taraf da anında görüyor (MVP'nin amacı buydu).
    if (!error) {
      try {
        const { data: ch, error: hata8 } = await supabase.from("chat_channels")
          .select("id").eq("request_id", sess.request_id).maybeSingle();
          if (hata8) logError("ekranlar_yalin.js:2573", hata8);
        if (ch?.id) {
          await supabase.from("messages").insert({
            channel_id: ch.id, from_id: uid, body: myStatus,
          });
        }
      } catch (e) {}
    }
    setBusy(false);
    if (!error) setShared(true);
  }
  return (
    <View>
      <View style={{ backgroundColor: C.greenBg, paddingVertical: SP[2], paddingHorizontal: ARA[14], borderBottomWidth: 1, borderBottomColor: C.green + "25" }}>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          <View style={{ width: 7, height: 7, borderRadius: R.full, backgroundColor: C.green, marginRight: SP[2] }} />
          <Text style={{ fontSize: FS.xs, color: C.greenInk, fontWeight: "600" }}>{t.sessActiveWord}</Text>
        </View>
      </View>
      <View style={{ padding: ARA[14] }}>
        {savedOther ? (
          <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "30", borderRadius: R.sm, padding: SP[3], marginBottom: SP[3] }}>
            <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.tealInk, letterSpacing: 1, marginBottom: SP[1] }}>{t.otherPartySays}</Text>
            <View style={{ flexDirection: "row", alignItems: "center" }}><Ikon ad="konum" boy={15} renk={C.mutedAA} stil={{ marginRight: SP[1] }} /><Text style={{ fontSize: FS.sm, color: C.ink, fontWeight: "600" }}>{savedOther}</Text></View>
          </View>
        ) : null}
        <View style={[S.card, { marginBottom: 0 }]}>
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mut, letterSpacing: 1, marginBottom: ARA[10] }}>{t.yourStatus}</Text>
          {opts.map(o => {
            const sel = myStatus === o;
            return (
              <Secim key={o} bicim="radyo" ton="teal" zemin="alt" secili={sel} etiket={o}
                stil={{ marginBottom: SP[2] }}
                onPress={() => { setMyStatus(o); setShared(false); }} />
            );
          })}
          {shared ? (
            /* 🔴 12 Eylül · gece — "✓" METNİN İÇİNDEYDİ VE YAPIŞIK ÇIKIYORDU.
               Sahnede "✓Paylaşıldı" diye okunuyor: onay işareti gövde
               fontunda yok, geri düşülen aile onu dar bir ilerlemeyle
               çiziyor ve sözlükteki boşluk yutuluyor. v2.87'de plan
               ayrıcalıklarında aynı kusuru düzeltmişim (işareti ayrı
               sütuna almıştım); burada tekrarlamışım. Aynı çözüm: glif
               metnin akışından çıkıyor, `Ikon` sütunu oluyor. */
            <View style={{ backgroundColor: C.greenBg, borderRadius: R.xs, padding: ARA[10],
                           flexDirection: "row", alignItems: "center", justifyContent: "center" }}>
              <Ikon ad="tamam" boy={FS.sm} renk={C.greenInk} stil={{ marginRight: ARA[6] }} />
              <Text style={{ fontSize: FS.xs, color: C.greenInk, fontWeight: "600" }}>
                {t.statusShared}
              </Text>
            </View>
          ) : (
            <Btn v="teal" sm onPress={share} disabled={!myStatus || busy} busy={busy}
              label={t.shareStatus} sagAd="sag" a11yLabel={t.shareStatus} />
          )}
        </View>
        <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], margintop: 10, marginTop: ARA[10] }}>
          <IkonMetin ad="uyari" renk={C.amberInk} stilMetin={{ fontSize: FS.xs, color: C.amberInk, lineHeight: 16 }} metin={t.locationNotShared} />
        </View>
      </View>
    </View>
  );
}
export function LiveStatus({ t, session, onBack, onGoSession }) {
  const uid = session?.user?.id;
  const [d, setD] = useState(null);

  useEffect(() => {
    (async () => {
      const today = yerelGun();
      const [{ data: trip }, { data: avail }, { data: sess }] = await Promise.all([
        supabase.from("visits").select("*").eq("user_id", uid).gte("visit_date", today).order("visit_date").limit(1).maybeSingle(),
        // #19: host'un aktif ilani da "canli durum"un parcasi
        supabase.from("availabilities").select("id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, active").eq("host_id", uid).eq("active", true).gte("avail_date", today).order("avail_date").limit(1).maybeSingle(),
        supabase.from("sessions").select("id, status, started_at, host_status, host_status_ts, guest_status, guest_status_ts, requests!inner(id, guest_id, host_id, availabilities(lounge_name, airport_code, time_from, time_to))")
          .eq("status", "active").limit(5),
      ]);
      const mine = (sess || []).find(s => s.requests?.guest_id === uid || s.requests?.host_id === uid);
      setD({ trip, avail, session: mine, isHost: mine ? mine.requests?.host_id === uid : false });
    })();
  }, [uid]);

  if (!d) return <Load t={t} title={t.liveTitle} onBack={onBack} />;
  const { trip, avail, session: act, isHost } = d;

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneLive} title={act ? t.liveSessionTitle : t.liveTitle} onBack={onBack} />
      {act && <LiveStatusPicker t={t} sess={act} isHost={isHost} uid={session?.user?.id} />}
      {/* MVP: durum kutusunun altinda "Oturuma Git" — sohbete/oturuma doner */}
      {act && onGoSession && (
        /* 🔴 12 EYLÜL · GECE — DÜĞME SAĞ KENARDAN 14pt TAŞIYORDU.
           `Btn` tam genişlikte `width: "100%"` alıyor; buna YATAY KENAR
           BOŞLUĞU eklenince genişlik ebeveynin tamamı + 14pt sol boşluk
           oluyor ve düğme sağdan ekran dışına çıkıyor. Kusur `LiveStatus`
           sahnesi ilk kez ÇEKİLDİĞİNDE göründü — yani ekran iki turdur
           "mount kapsamında" yeşil yanıyordu ve mount taşmayı görmüyor.
           Doğrusu boşluğu düğmeye değil KABINA vermek.
           🆕 SINIF: "YÜZDE GENİŞLİK VE KENAR BOŞLUĞU AYNI ÖĞEDE
           BULUŞURSA TOPLAMLARI EBEVEYNİ AŞAR — BİRİ ÖĞENİN, ÖTEKİ
           KABIN İŞİDİR." */
        <View style={{ paddingHorizontal: ARA[14], marginBottom: ARA[6] }}>
          <Btn v="gold" sm label={t.goToSession} onPress={() => onGoSession(act.requests, isHost)} />
        </View>
      )}
      {/* 🔴 v1.82 (Gokberk 3.x — İKİNCİ KEZ): "uçuşunu ve aktif oturumunu takip
          et" bölümü KALDIRILDI. (v1.81'de silmiştim ama dosyaya yazılmamış;
          bu kez silindiği doğrulandı.) Gerekçe: uçuş durumu UYDURMAYDI —
          hiçbir uçuş verisi sağlayıcımız yok, ekranda "Zamanında" yazıyordu.
          Lounge/oturum kartları da Ana Sayfa ve Seyahatlerim'de zaten var. */}
    </Sayfa>
  );
}

// ============ ACTION NEEDED kartı (§7.3, §18) ============
export function HaberVer({ t, lang, airport, date }) {
  const [ap, setAp] = useState(airport || "");
  // 19 Eylül (md.9) — katalog: seçici kod/ad/şehirde arama yapıyor.
  const [havalimanlari, setHavalimanlari] = useState([]);
  const [d1, setD1] = useState(date || "");
  const [d2, setD2] = useState(date || "");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState(null);
  const [liste, setListe] = useState(null);

  const yukle = async () => {
    const { data, error } = await supabase.rpc("taleplerim");
    if (error) { setErr(mapErr(t, error.message)); return; }
    setListe(data || []);
  };
  useEffect(() => { yukle(); }, []);
  useEffect(() => {
    havalimanlariniGetir()
      .then((d) => setHavalimanlari(d || []))
      .catch((e) => logError("HaberVer:havalimanlari", e));
  }, []);

  const gonder = async () => {
    setErr(""); setOk(null);
    const a = String(ap || "").trim().toUpperCase();
    if (a.length !== 3) return setErr(t.errAirport);
    if (!dateOk(d1)) return setErr(t.errDate);
    setBusy(true);
    const { data, error } = await supabase.rpc("talep_birak", {
      p_airport: a, p_bas: d1, p_bit: dateOk(d2) ? d2 : d1,
    });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    setOk(data);
    yukle();
  };

  const kaldir = async (id) => {
    const { error } = await supabase.rpc("talebi_kaldir", { p_id: id });
    if (error) { setErr(mapErr(t, error.message)); return; }
    yukle();
  };

  return (
    <View style={{ width: "100%", marginTop: ARA[18], borderTopWidth: 1, borderTopColor: C.line, paddingTop: SP[4] }}>
      <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base, textAlign: "center" }}>{t.notifyTitle}</Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", marginTop: SP[1], lineHeight: 18 }}>
        {t.notifyBody}
      </Text>

      {/* ══════════════════════════════════════════════════════════
          🔴 19 EYLÜL (Gökberk md.9 · ONAYLANDI) — SERBEST METİN GİTTİ.
          "haber ver alanında havalimanları droplist ile gelmeli"
          Eski hâl üç harflik serbest bir kutuydu: "Istanbul", "ist",
          "İST" üçü de FARKLI kayda gidiyor ve `taleplerim` eşleşmesi
          tutmuyordu — yani kullanıcı talebini yazıyor, hiçbir ilanla
          eşleşmiyor ve sebebini asla öğrenmiyor.
          Aynı bileşen (`AirportPicker`, `ortak.js`) md.17'de ÇOKLU
          kipte çalışıyor; burada tekli. Tek seçici, iki ekran.
          🆕 SINIF: "BİR ALANI SERBEST METİN BIRAKMAK, KULLANICIYA
          DEĞİL VERİTABANINA SORU SORDURMAKTIR."
          ══════════════════════════════════════════════════════════ */}
      <View style={{ marginTop: SP[3] }}>
        <AirportPicker t={t} label={t.notifyAirport}
          airports={havalimanlari}
          value={ap}
          onSelect={(kod) => setAp(kod || "")} />
      </View>
      <TextInput value={d1} onChangeText={setD1} placeholder="YYYY-AA-GG" placeholderTextColor={C.dim}
        style={[S.input, { minHeight: TAP.minHeight }]} />
      <TextInput value={d2} onChangeText={setD2} placeholder={t.notifyUntil} placeholderTextColor={C.dim}
        style={[S.input, { marginTop: SP[2], minHeight: TAP.minHeight }]} />

      {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}

      {ok && (
        <View style={{ backgroundColor: C.tealTint, borderWidth: 1, borderColor: C.green,
                       borderRadius: R.sm, padding: SP[3], marginTop: ARA[10] }}>
          <Text style={{ color: C.greenInk, fontSize: FS.sm, fontWeight: "700" }}>{t.notifySaved}</Text>
          <Text style={{ color: C.ink, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>
            {String(t.notifyWaiting || "").replace("{n}", String(ok.bekleyen_kisi ?? 1))}
          </Text>
        </View>
      )}

      <Btn label={t.notifyCta} onPress={gonder} disabled={busy} busy={busy}
           style={{ marginTop: ARA[10] }} />

      {Array.isArray(liste) && liste.length > 0 && (
        <View style={{ marginTop: ARA[14] }}>
          <Text style={{ color: C.mut, fontSize: FS.xs, letterSpacing: 1.1, fontWeight: "600" }}>
            {t.notifyMine}
          </Text>
          {liste.map((r) => (
            <View key={r.id} style={{ flexDirection: "row", alignItems: "center",
                                      justifyContent: "space-between", backgroundColor: C.card,
                                      borderWidth: 1, borderColor: C.line, borderRadius: R.sm,
                                      padding: SP[3], marginTop: SP[2] , ...ELEV.card }}>
              <View style={{ flex: 1 }}>
                <Text style={{ color: C.ink, fontSize: FS.sm, fontWeight: "700" }}>
                  {r.airport_code} · {fmtLongDate(r.tarih_bas, lang)}
                  {r.tarih_bit !== r.tarih_bas ? " – " + fmtLongDate(r.tarih_bit, lang) : ""}
                </Text>
                <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>
                  {String(t.notifyRow || "")
                    .replace("{k}", String(r.bekleyen_kisi ?? 0))
                    .replace("{i}", String(r.eslesen_ilan ?? 0))}
                </Text>
              </View>
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => kaldir(r.id)}
                style={{ minHeight: TAP.minHeight, justifyContent: "center", paddingHorizontal: ARA[10] }}>
                <Text style={{ color: C.red, fontSize: FS.sm, fontWeight: "700" }}>{t.remove}</Text>
              </TouchableOpacity>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}
// 🔴 v3.4 — BU BİLEŞEN YAZILMIŞ AMA HİÇ ÇİZİLMEMİŞTİ.
// `App.js` onu import ediyordu, `sorularim()` RPC'si canlıda çalışıyordu,
// içindeki 100 satır tamamdı — ve HİÇBİR YERDE `<MyQuestions ...>` yoktu.
// Üstündeki `ActionNeeded` yorumu "bu veriyi ana sayfaya getiriyoruz"
// diyordu; getirilmemişti.
//
// 🆕 SINIF: "IMPORT EDİLİP HİÇ ÇİZİLMEYEN BİR EKRAN, YAZILMIŞ AMA TESLİM
// EDİLMEMİŞTİR — VE KİMSE ONU ARAMADIĞI İÇİN KAYIP DA SAYILMAZ."
//
// İKİ MOD, TEK GÖVDE:
//   · `onBack` YOKSA  → eski davranış: gömülü kart, boşken `null`.
//     (Bir kartın boşken kaybolması doğrudur.)
//   · `onBack` VARSA  → tam ekran: başlık, geri oku ve BOŞ DURUM metni.
//     (Bir EKRANIN boşken kaybolması yanlıştır: kullanıcı oraya bilerek
//      gitti, karşısına hiçlik değil bir cevap çıkmalı.)
//
// 🆕 SINIF: "BOŞKEN KAYBOLMAK BİR KART İÇİN DOĞRU, BİR HEDEF EKRAN İÇİN
// YANLIŞTIR — FARK, KULLANICININ ORAYA BİLEREK GİDİP GİTMEDİĞİDİR."
export function MyQuestions({ t, lang, onOpenProfile, onOpenCompanion, onIlanaGit, onBack }) {
  const [rows, setRows] = useState(null);
  const [acik, setAcik] = useState(false);

  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("sorularim");
      if (error) { logError("sorularim", error); return; }
      if (!iptal) setRows(Array.isArray(data) ? data : []);
    })();
    return () => { iptal = true; };
  }, []);

  const tamEkran = !!onBack;

  if (!rows) return tamEkran ? <Load t={t} title={t.flowQuestions} onBack={onBack} /> : null;
  if (rows.length === 0) {
    if (!tamEkran) return null;
    return (
      <Sayfa>
        <Hdr t={t} ustBilgi={t.sceneMeet} title={t.flowQuestions} onBack={onBack} />
        <View style={S.empty}>
          <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", lineHeight: 19 }}>
            {t.questionsEmpty}
          </Text>
        </View>
      </Sayfa>
    );
  }

  const acilan = rows.filter(r => r.ilan_acildi).length;

  const govde = (
    <View style={[S.card, { marginBottom: SP[3], borderColor: acilan ? C.green : C.line }]}>
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => setAcik(v => !v)}
        accessibilityRole="button" accessibilityLabel={t.myQuestions}
        style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", minHeight: TAP.minHeight }}>
        <View style={{ flex: 1, paddingRight: SP[2] }}>
          <Text style={{ color: C.mut, fontSize: FS.xs, letterSpacing: 1, fontWeight: "600" }}>
            {BUYUK(t.myQuestions)}  ·  {rows.length}
          </Text>
          <Text numberOfLines={2} style={{ color: C.mut, fontSize: FS.sm, lineHeight: 17, marginTop: SP[1] }}>
            {acilan > 0 ? t.mqOpened : t.myQuestionsSub}
          </Text>
        </View>
        <Ikon ad={acik ? "yukari" : "asagi"} boy={14} renk={C.mut} />
      </TouchableOpacity>

      {/* ════════════════════════════════════════════════════════════════
          🔴 v2.95 — "SORDUKLARIM" (Gökberk madde 15)
          "hiçbir detay yok. X yanıtladıya tıklanınca chat açılmıyor ve o
           kişinin profil sayfası açılıyor. Sorum cevaplandıysa tıkladığımda
           chatte görebilmeliyim."

          İKİ AYRI EKSİK, İKİSİ DE VERİ TARAFINDA:
          (a) Kart "host2 / Host yanıtladı" diyordu. NEYİ sorduğum, HANGİ
              ilan, HANGİ tarih — hiçbiri yok. `sorularim()` bunların
              hiçbirini döndürmüyordu; ekran elindeki iki alanı basıyordu.
          (b) Dokununca profil açılıyordu çünkü ekranın elindeki TEK kimlik
              `host_id`'ydi. Sohbet kanalı `respond_connection` tarafından
              kabul anında ZATEN açılıyor — `sorularim()` onu okumuyordu.
          🆕 SINIF: "BİR EKRAN YANLIŞ YERE GİDİYORSA, ÖNCE DOĞRU YERİN
          KİMLİĞİNİ ELİNDE TUTUP TUTMADIĞINA BAK."
          SQL 248 `channel_id` + `soru` + tarih/saat ekledi; ekran artık
          yanıtlanmış soruda SOHBETE gidiyor, yanıtlanmamışta profile.
          ════════════════════════════════════════════════════════════════ */}
      {acik && rows.map(r => {
        const yanitlandi = r.cevap_durumu === "yanitlandi";
        const ctx = [r.airport_code, r.avail_date ? fmtLongDate(r.avail_date, lang) : null,
                     (r.time_from && r.time_to)
                       ? `${String(r.time_from).slice(0,5)}–${String(r.time_to).slice(0,5)}` : null,
                    ].filter(Boolean).join(" · ");
        return (
        <TouchableOpacity key={r.id} hitSlop={TAP.slop}
          onPress={async () => {
            // ══════════════════════════════════════════════════════════
            // 🔴 19 EYLÜL (Gökberk md.16 · ONAYLANDI) — "İLAN BAŞVURUYA
            // AÇILDI" ARTIK İLANA GİDİYOR.
            // "soru kısmında 'ilan başvuruya açıldı' durumunda ilgili
            //  soruya tıklandığında beni o kişinin profiline götürüyor…
            //  Sen ne düşünüyorsun?"
            // Bildirimin ÖZNESİ ilan, kişi değil. Profilde başvuru düğmesi
            // YOK — yani dokunuş seni tam da aksiyonun olduğu yerden
            // uzaklaştırıyordu. `sorularim()` `avail_id`yi zaten
            // döndürüyor (SQL 248); eksik olan tek şey onu KULLANMAKTI.
            // Kişiye gitmek isteyen kartın içindeki isimden gider.
            // 🆕 SINIF: "BİR BİLDİRİMİN VARIŞ NOKTASI, HABERİ DEĞİL
            // YAPILACAK İŞİ TAŞIYAN EKRANDIR."
            // ══════════════════════════════════════════════════════════
            if (r.ilan_acildi && r.avail_id && onIlanaGit) {
              onIlanaGit(r.avail_id, r.airport_code);
              return;
            }
            // Yanıtlandıysa SOHBET. Kanal yoksa sunucu açar (baglanti_sohbeti_ac).
            if (yanitlandi && onOpenCompanion) {
              if (r.channel_id) { onOpenCompanion(r.channel_id, r.host_name); return; }
              const { data, error } = await supabase.rpc("baglanti_sohbeti_ac", { p_conn_id: r.id });
              if (error) { logError("baglanti_sohbeti_ac", error); return; }
              if (data && data.channel_id) { onOpenCompanion(data.channel_id, r.host_name); return; }
            }
            // Henüz yanıt yoksa gidilecek bir sohbet de yok — profil doğru yer.
            if (onOpenProfile && r.host_id) onOpenProfile(r.host_id);
          }}
          accessibilityRole="button"
          accessibilityLabel={`${r.host_name} — ${yanitlandi ? t.mqAnswered : t.mqPending}`}
          style={{ marginTop: SP[2], backgroundColor: C.bgAlt, borderRadius: R.xs, padding: SP[3], minHeight: TAP.minHeight,
                   borderWidth: 1, borderColor: yanitlandi ? C.green + "45" : C.line }}>
          <View style={{ flexDirection: "row", alignItems: "center" }}>
            <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, marginRight: SP[2], fontSize: FS.sm, fontWeight: "700", color: C.ink }}>
              {shortName(r.host_name)}{r.salon ? " · " + r.salon : ""}
            </Text>
            <Text style={{ flexShrink: 0, fontSize: FS.xs, fontWeight: "600",
                           color: r.ilan_acildi ? C.green
                                : r.cevap_durumu === "reddedildi" ? C.red
                                : yanitlandi ? C.green : C.mut }}>
              {r.ilan_acildi ? t.mqOpened
                : yanitlandi ? t.mqAnswered
                : r.cevap_durumu === "reddedildi" ? t.mqDeclined
                : t.mqPending}
            </Text>
          </View>
          {!!ctx && <Text numberOfLines={1} style={{ fontSize: FS.xs, color: C.mut, marginTop: SP[1] }}>{ctx}</Text>}
          {/* NE SORDUM — kullanıcının kendi cümlesi. Bir listede en iyi
              hatırlatıcı, kişinin kendi yazdığıdır. */}
          {!!r.soru && (
            <Text numberOfLines={2} style={{ fontSize: FS.sm, color: C.body, marginTop: SP[1], fontStyle: "italic", lineHeight: 17 }}>
              "{r.soru}"
            </Text>
          )}
          {/* md.16 — dokunuşun NEREYE gittiğini satır söylüyor. Bir
              kısayolun hedefi tahmin ettirilmez. */}
          {r.ilan_acildi && r.avail_id ? (
            <IkonMetin sag ad="sag" renk={C.green} stilMetin={{ fontSize: FS.xs, color: C.greenInk, fontWeight: "600", marginTop: ARA[6] }} metin={t.mqGoListing} />
          ) : yanitlandi ? (
            <IkonMetin sag ad="sag" renk={C.gold} stilMetin={{ fontSize: FS.xs, color: C.gold, fontWeight: "600", marginTop: ARA[6] }} metin={t.openChat} />
          ) : null}
        </TouchableOpacity>
        );
      })}
    </View>
  );

  // Gömülü kart olarak çağrıldıysa gövde yeter; tam ekran olarak
  // çağrıldıysa başlık + geri oku sarmalıyor.
  if (!tamEkran) return govde;
  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneMeet} title={t.flowQuestions} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {govde}
      </ScrollView>
    </Sayfa>
  );
}
export function HikayeDaveti({ t, lang, onDone, hepAcik = false }) {
  const [davet, setDavet] = useState(null);
  const [metin, setMetin] = useState("");
  const [riza, setRiza] = useState(false);
  const [ad, setAd] = useState("");
  const [busy, setBusy] = useState(false);
  const [bitti, setBitti] = useState(false);
  const [gonderHatasi, setGonderHatasi] = useState("");   // 19 Eylül · derin denetim

  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("bekleyen_hikaye_daveti");
      if (error) { logError("hikaye_daveti", error); return; }
      if (!iptal && Array.isArray(data) && data.length) setDavet(data[0]);
    })();
    return () => { iptal = true; };
  }, []);

  if (!davet || bitti) return null;

  const yeter = metin.trim().length >= 20 && ad.trim().length > 0;

  async function gonder(izin) {
    if (busy) return;
    setBusy(true);
    const { error } = await supabase.rpc("host_hikaye_yaz", {
      p_session: davet.session_id,
      p_metin: metin.trim(),
      p_gorunen_ad: ad.trim(),
      p_gorunen_not: null,
      p_riza: izin,
    });
    setBusy(false);
    // 🔴 19 EYLÜL · DERİN DENETİM — YAZILAN METİN SESSİZCE KAYBOLUYORDU.
    // Eski hâl: hata → `return`. Panel açık kalıyor, spinner sönüyor,
    // "kaydedildi" de "hata" da yazmıyor. Host uzun bir hikâye yazıp
    // Gönder'e basıyor ve HİÇBİR ŞEY oluyor gibi görünüyor. Hemen
    // altındaki `ertele()` aynı sınıfı bilinçli olarak çözmüş — yazar
    // orada düşünmüş, burada düşünmemiş.
    // Metin state'te duruyor; kullanıcı sebebi görüp tekrar deneyebilir.
    // 🆕 SINIF: "BİR GÖNDERİM DÜŞTÜĞÜNDE KULLANICININ YAZDIĞI ŞEY
    // DURUYORSA HATA DÜZELTİLEBİLİR, DURMUYORSA KAYIPTIR — İKİSİNİN
    // ARASINDAKİ FARK TEK BİR HATA SATIRIDIR."
    if (error) { logError("host_hikaye_yaz", error); setGonderHatasi(mapErr(t, error.message)); return; }
    setGonderHatasi("");
    setBitti(true);
    if (onDone) onDone();
  }

  async function ertele() {
    if (!davet || busy) return;
    setBusy(true);
    const { error } = await supabase.rpc("hikaye_davetini_ertele", { p_session: davet.session_id });
    setBusy(false);
    // Sunucu düşerse paneli YİNE kapatıyoruz — kullanıcıyı ağı yüzünden
    // bir panelin içine hapsetmek, ertelemenin amacını çürütür. Hata
    // günlüğe düşer; davet bir dahaki açılışta geri gelir.
    if (error) logError("hikaye_davetini_ertele", error);
    setBitti(true);
    if (onDone) onDone();
  }

  // ════════════════════════════════════════════════════════════════════
  // 🔴 v2.95 (Gökberk madde 11) — BU PANEL ARTIK KATLANIYOR.
  // "ana sayfadaki ağırlaman nasıl geçti alanı daraltılıp genişletilemiyor
  //  bu sebeple çok yer kaplıyor."
  // Ölçtüm: panel iki metin kutusu, bir onay kutusu ve iki düğme taşıyor —
  // ana sayfanın neredeyse tam bir ekranı. Katlanır DEĞİLDİ çünkü ben
  // v2.88'de onu "ana sayfanın en önemli kartı" varsayıp katlanmaz
  // yapmıştım. Yanlış varsayım: ÖNEMLİ olmak, HER ZAMAN AÇIK olmayı
  // gerektirmez — önemli olan şey KAYBOLMAMALIDIR, kaplamak zorunda değil.
  // Kapalıyken bile başlıkta salon ve tarih duruyor.
  //
  // `hepAcik`: Değerlendirmeler ekranında panel zaten o iş için açılmış
  // bir sayfada duruyor; orada katlamak saçma olurdu.
  // ════════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL (Gökberk md.1) — "üstünde bir cümle başlığı olmamalı".
  // `storyBody` gövdenin BAŞINDAN alındı; `Katlanir`ın `not`u olarak
  // gövdenin ALTINA indi (bkz. aşağıdaki iki dönüş). Silinmedi.
  const govde = (
    <>
      <TextInput
        value={metin}
        onChangeText={(x) => setMetin(x.slice(0, 240))}
        placeholder={t.storyPlaceholder}
        placeholderTextColor={C.dim}
        multiline
        accessibilityLabel={t.storyTitle}
        style={{ marginTop: ARA[10], minHeight: 72, borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
                 padding: ARA[10], color: C.ink, fontSize: FS.sm, textAlignVertical: "top" }}
      />
      {/* ══════════════════════════════════════════════════════════════
          🔴 18 EYLÜL (Gökberk md.14) — "gönder ve şimdi değil butonları
          çalışmıyor."
          Ölçtüm: "Gönder" BOZUK DEĞİL, `disabled`. Koşul:
              yeter = metin.trim().length >= 20 && ad.trim().length > 0
          İki gizli şart ve ekranda ikisini de söyleyen tek kelime yok:
          sayaç sadece "n/240" diyor, adın zorunlu olduğunu hiçbir şey
          söylemiyor. Kullanıcı bir cümle yazıyor, düğme ölü kalıyor.
          Bir düğmeyi kapatmak bir karardır; o kararın SEBEBİNİ
          söylemezsen kullanıcı için ayırt edilemez biçimde bozuktur.
          🆕 SINIF: "SESSİZCE DEVRE DIŞI BIRAKILMIŞ BİR DÜĞME, BOZUK BİR
          DÜĞMEDEN AYIRT EDİLEMEZ — KOŞULU YAZMIYORSAN KAPATMA."
          ══════════════════════════════════════════════════════════════ */}
      <Text style={{ color: metin.trim().length >= 20 ? C.dim : C.mutedAA, fontSize: FS.xs, marginTop: SP[1] }}>
        {metin.trim().length}/240
        {metin.trim().length < 20 ? " · " + String(t.storyMinChars || "").replace("{n}", String(20 - metin.trim().length)) : ""}
      </Text>

      <TextInput
        value={ad}
        onChangeText={(x) => setAd(x.slice(0, 40))}
        placeholder={t.storyNamePlaceholder}
        placeholderTextColor={C.dim}
        accessibilityLabel={t.storyNamePlaceholder}
        style={{ marginTop: SP[2], minHeight: TAP.minHeight, borderWidth: 1, borderColor: C.line,
                 borderRadius: R.xs, paddingHorizontal: ARA[10], color: C.ink, fontSize: FS.sm }}
      />

      {/* 🔴 RIZA AYRI VE VARSAYILANI KAPALI. Yazmak ile yayına izin
          vermek aynı şey değil; tek kutuda birleştirmek "sessiz onay"
          olurdu. Veritabanı kısıtı da bunu ayrıca zorluyor (230). */}
      <TouchableOpacity onPress={() => setRiza(!riza)} accessibilityRole="checkbox"
        accessibilityState={{ checked: riza }} accessibilityLabel={t.storyConsent}
        style={{ flexDirection: "row", alignItems: "center", gap: SP[2], marginTop: ARA[10], minHeight: TAP.minHeight }}>
        <View style={{ width: 20, height: 20, borderRadius: R.onay, borderWidth: 1.5,
                       borderColor: riza ? C.gold : C.line, backgroundColor: riza ? C.gold : "transparent",
                       alignItems: "center", justifyContent: "center" }}>
          {riza ? <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} /> : null}
        </View>
        <Text style={{ flex: 1, color: C.mut, fontSize: FS.sm, lineHeight: 17 }}>{t.storyConsent}</Text>
      </TouchableOpacity>

      <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
        <TouchableOpacity onPress={() => gonder(riza)} disabled={!yeter || busy}
          accessibilityRole="button" accessibilityLabel={t.storySend}
          style={{ flex: 2, height: TAP.minHeight, backgroundColor: yeter ? C.goldBtn : C.line,
                   borderRadius: R.xs, alignItems: "center", justifyContent: "center" }}>
          {/* ══════════════════════════════════════════════════════════
              🔴 13 EYLÜL (Gökberk md.9) — "buradaki butonların textleri
              üst yapışık gibi."
              Ölçtüm: metinde `flex: 1` vardı ve düğmenin kabı SÜTUN
              (RN'de varsayılan `flexDirection: "column"`). Sütun kapta
              `flex: 1` metni DİKEY olarak gerdiriyor; gerilmiş kutunun
              içinde yazı üste yapışıyor ve kabın `justifyContent:
              "center"`i hiçbir şey yapmıyor — çünkü ortalayacak boşluk
              kalmıyor.
              Bu sınıfı 24 Ağustos'ta bir kez teşhis etmiştim
              ("ortalayan kap, içindeki kendi yüksekliğini dolduruyorsa
              ortalama görünmez") — aynı kusur başka bir ekranda geri
              gelmiş. Bu yüzden yalnız düzeltmedim, nöbetçisini de
              yazdım (`check.js` · dikey ortalama denetimi).
              🆕 SINIF: "BİR KUSURU DÜZELTİP NÖBETÇİSİNİ YAZMAZSAN,
              TEŞHİSİ DEĞİL YALNIZ O ÖRNEĞİ ÇÖZMÜŞ OLURSUN." */}
          <Text numberOfLines={1} style={{ minWidth: 0, textAlign: "center", color: C.onAccent, fontWeight: "700", fontSize: FS.sm }}>
            {busy ? "…" : t.storySend}
          </Text>
        </TouchableOpacity>
        {/* 🔴 18 EYLÜL (md.14) — "ŞİMDİ DEĞİL" ARTIK BİR YERE YAZILIYOR.
            Eski hâl yalnız `setBitti(true)` idi: panel kayboluyor, sunucu
            hiçbir şey bilmiyor, `bekleyen_hikaye_daveti` bir sonraki
            açılışta aynı daveti geri döndürüyordu. Kodun kendi yorumu
            "kalıcıdır, bir daha sorulmaz" diyordu — ama o yol sunucuda
            hiç açılmamıştı (SQL 296 açtı). Erteleme 30 gün tutuyor;
            silmiyor, çünkü host üç ay sonra yazmak isteyebilir. */}
        <TouchableOpacity onPress={ertele} disabled={busy}
          accessibilityRole="button" accessibilityLabel={t.storyLater}
          style={{ flex: 1, height: TAP.minHeight, backgroundColor: C.card, borderWidth: 1,
                   borderColor: C.line, borderRadius: R.md, alignItems: "center", justifyContent: "center" }}>
          <Text numberOfLines={1} style={{ minWidth: 0, textAlign: "center", color: C.mutedAA, fontSize: FS.sm }}>
            {t.storyLater}
          </Text>
        </TouchableOpacity>
      </View>
      {/* 19 Eylül — gönderim düştüyse sebebi burada; metin kutusu dolu kalıyor. */}
      {!!gonderHatasi && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{gonderHatasi}</Text></View>}
      {/* Düğme kapalıysa TAM OLARAK neyin eksik olduğunu yaz (md.14). */}
      {!yeter && (
        <Text style={{ color: C.mutedAA, fontSize: FS.xs, marginTop: SP[2], lineHeight: 15 }}>
          {metin.trim().length < 20 ? t.storyWhyDisabledText : t.storyWhyDisabledName}
        </Text>
      )}
      <Text style={{ color: C.dim, fontSize: FS.xs, marginTop: SP[2], lineHeight: 15 }}>{t.storyNote}</Text>
    </>
  );

  // 25 Eyl — tarih ham ISO ("2026-09-25") basılıyordu; ürünün geri kalanı
  // "25 Eylül" diyor. Aynı ekranda iki biçim, iki ayrı ürün gibi okunur.
  const altBaslik = [davet.salon, davet.tarih && fmtLongDate(davet.tarih, lang)].filter(Boolean).join(" · ");

  // 🔴 12 EYLÜL (Gökberk md.1) — "ağırlaman nasıl geçti alanı daraltılıp
  // genişletilebilir olmalı."
  // v2.95'te ana sayfadaki panel katlanır yapılmıştı ama Değerlendirmeler
  // ekranındaki `hepAcik` dalı KATLANMIYORDU; onu ben "zaten o iş için
  // açılmış sayfa" diyerek sabitlemiştim. Ölçtüm: 23_degerlendirme'de panel
  // 452 pt — ekranın %53'ü; altındaki "Şimdi puanla" kartları katlamanın
  // altında kalıyor. Artık iki dal da `Katlanir`; tek fark BAŞLANGIÇ HÂLİ:
  // Değerlendirmeler'de AÇIK (kullanıcı oraya bunun için gitti),
  // ana sayfada KAPALI (kullanıcı oraya başka bir iş için geldi).
  // 🆕 SINIF: "AYNI BİLEŞENİN İKİ YERDE FARKLI OLMASI GEREKEN ŞEYİ
  // 'KATLANIR MI' DEĞİL 'KATLI MI BAŞLAR'DIR."
  return (
    /* 🔴 18 EYLÜL (Gökberk md.14) — "'Bir cümle' başlığını kaldıralım
       demiştik."
       Haklı ve ikinci kez söylüyor. 12 Eylül'de `storyBody` gövdeden
       alınmıştı ama BAŞLIK (`storyEyebrow` = "BİR CÜMLE") yerinde
       kalmıştı — yani istenen şey kaldırılmamış, komşusu kaldırılmıştı.
       Başlık artık ekranın asıl sorusu: "Ağırlaman nasıl geçti?".
       Özet satırı salon ve tarihi taşıyor; `storyTitle` başlığa çıkınca
       özette tekrar etmesi gerekmiyor.
       🆕 SINIF: "BİR ŞEYİN KALDIRILMASI İSTENDİĞİNDE YANINDAKİNİ
       KALDIRIRSAN, İSTEK BİR TUR DAHA GERİ GELİR." */
    <Katlanir baslik={t.storyTitle} ozet={altBaslik || undefined}
      acikBasla={hepAcik} not={t.storyBody}
      tint={hepAcik ? C.surface : C.goldBg} cizgi={hepAcik ? C.gold : C.goldLine}>
      {govde}
    </Katlanir>
  );
}
export function RateReminder({ t, lang, onRate }) {   // v2.65: ölü `session` kaldırıldı
  const [items, setItems] = useState([]);
  const [erteleHatasi, setErteleHatasi] = useState("");
  const load = useCallback(async () => {
    const { data, error: hata9 } = await supabase.rpc("pending_ratings");
    if (hata9) logError("ekranlar_yalin.js:3056", hata9);
    setItems(data || []);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function defer(sid) {
    // v2.78: "Sonra puanlarım" sessizce hiçbir şey yapmayabiliyordu.
    // 🔴 19 EYLÜL · DERİN DENETİM — O DÜZELTME YARIM KALMIŞ. RPC eklendi
    // ama HATA YOLU sessiz bırakıldı: kullanıcı "Sonra"ya basıyor, kart
    // ekranda kalıyor, bir daha basıyor, yine kalıyor. Ana sayfanın en
    // üstünde inatçı bir kart. Bir kusuru düzeltirken mutlu yolu
    // düzeltmek, kusurun yarısını düzeltmektir.
    const { error } = await supabase.rpc("defer_rating", { p_session: sid });
    if (error) { logError("defer_rating", error); setErteleHatasi(mapErr(t, error.message)); return; }
    setErteleHatasi("");
    load();
  }
  if (!items.length) return null;
  const it = items[0];
  return (
    <View style={[S.card, { borderColor: C.gold, borderWidth: 1.5, marginBottom: SP[3] }]}>
      {/* 19 Eylül — "Sonra" düşerse kullanıcı sebebi görüyor. */}
      {!!erteleHatasi && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{erteleHatasi}</Text></View>}
      {/* 🔴 v2.66 (Gökberk madde 12, ikinci tur) — BAŞLIK ARTIK OLAYI SÖYLER.
          v2.65 havalimanı/tarih/uçuşu ayrı bir alt satır olarak eklemişti
          ama başlık hâlâ "Son oturunu puanla" idi ve asıl bağlam üçüncü
          satırda kalıyordu. Kullanıcı üç gün sonra bakınca önce "hangi
          oturum?" diye soruyor. Sıra tersine çevrildi:
            başlık   → salon · tarih   (hangi ilan)
            alt satır → "X ile · TK1234"  (kiminle, hangi uçuş)
          Veriler pending_ratings'te zaten vardı; okumamak tercih değil hataydı. */}
      <Text style={{ color: C.mut, fontSize: FS.xs, letterSpacing: 1, fontWeight: "600" }}>{t.pendingRate}</Text>
      <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base, marginTop: SP[1] }}>
        {[it.lounge || it.airport_code, it.avail_date ? fmtLongDate(String(it.avail_date).slice(0, 10), lang) : null].filter(Boolean).join(" · ") || t.pendingRate}
      </Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[2] }}>
        {[it.other_name ? String(t.rateWithWho).replace("{name}", it.other_name) : null,
          it.flight_number || it.carrier || null,
          (it.time_from && it.time_to)
            ? `${String(it.time_from).slice(0,5)}–${String(it.time_to).slice(0,5)}` : null,
        ].filter(Boolean).join(" · ")}
      </Text>
      {/* v1.82 (Gokberk): "sonra puanla"ya basınca oturumun nereye gittiği
          belli değildi. Artık nerede bulunacağı yazılı. */}
      <Text style={{ color: C.dim, fontSize: FS.xs, marginTop: ARA[2] }}>{t.rateLaterWhere}</Text>
      {/* 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: butonlar "aşağı doğru geniş" duruyordu.
          Sebep dolgu değil METİN SARMASIYDI: "Sonra puanla (24s)" dar
          sütuna sığmayıp iki satıra iniyor, satır yüksekliği İKİ butonu
          birden büyütüyordu (row'da yükseklik en uzun öğeye göre).
          Çözüm: metni kısalt + tek satıra kilitle + sabit yükseklik. */}
      <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
        <Btn v="gold" sm label={t.rateNow} onPress={() => onRate && onRate(it)} a11yLabel={t.rateNow} style={{ flex: 2 }} />
        <Btn v="muted" sm label={t.rateLaterShort} onPress={() => defer(it.session_id)}
          style={{ flex: 1 }} />
      </View>
    </View>
  );
}


// ============ WALLET (§20) — beta modunda kredi paketleri ============
// Gercek odeme (Play Billing) yok. Beta'da paketler "yakinda" gosterilir,
// kullanici kredi talep edebilir; admin BO'dan tanimlar.
export function HediyeBolumu({ t, onDone }) {
  const [hak, setHak] = useState(null);
  const [kisiler, setKisiler] = useState([]);
  const [secili, setSecili] = useState(null);
  const [not, setNot] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const yukle = useCallback(async () => {
    const [{ data: h, error: eh }, { data: c, error: ec }] = await Promise.all([
      supabase.rpc("hediye_edilebilir_hakkim"),
      supabase.rpc("my_connections"),
    ]);
    if (eh) logError("hediye_edilebilir_hakkim", eh);
    if (ec) logError("my_connections", ec);
    setHak(h || { adet: 0 });
    setKisiler(Array.isArray(c) ? c : []);
  }, []);
  useEffect(() => { yukle(); }, [yukle]);

  if (!hak) return null;

  async function gonder() {
    if (busy || !secili) return;
    setBusy(true); setErr(""); setMsg("");
    const { error } = await supabase.rpc("misafir_hakki_hediye_et", {
      p_to: secili, p_adet: 1, p_not: not.trim() || null,
    });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    setMsg(t.giftDone); setSecili(null); setNot("");
    yukle(); if (onDone) onDone();
  }

  return (
    <View style={{ marginTop: ARA[18] }}>
      <Text style={S.label}>{t.giftTitle}</Text>
      <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: SP[2] }}>{t.giftBody}</Text>
      <Text style={{ color: hak.adet > 0 ? C.teal : C.mut, fontSize: FS.sm, fontWeight: "700", marginBottom: SP[2] }}>
        {String(t.giftMine).replace("{n}", String(hak.adet || 0))}
      </Text>

      {/* Hakkın yoksa liste çizmiyoruz: seçilemeyecek bir liste, kırık bir
          düğmeden farksızdır. Ne zaman birikeceğini söylüyoruz. */}
      {(hak.adet || 0) < 1 ? (
        <View style={S.card}><Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18 }}>{t.giftNone}</Text></View>
      ) : kisiler.length === 0 ? (
        <View style={S.card}><Text style={{ color: C.mut, fontSize: FS.sm }}>{t.connEmpty}</Text></View>
      ) : (
        <>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: SP[2] }}>
            {kisiler.slice(0, 12).map(k => {
              const on = secili === k.user_id;
              return (
                <TouchableOpacity key={k.user_id} onPress={() => setSecili(on ? null : k.user_id)}
                  accessibilityRole="button" accessibilityState={{ selected: on }}
                  style={[S.chip, { minHeight: TAP.minHeight, justifyContent: "center" },
                          on && { borderColor: C.teal, backgroundColor: C.tealBg }]}>
                  <Text style={{ fontSize: FS.sm, color: on ? C.teal : C.ink, fontWeight: on ? "700" : "400" }}>
                    {shortName(k.name)}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
          <TextInput value={not} onChangeText={x => setNot(x.slice(0, 120))}
            placeholder={t.giftNote} placeholderTextColor={C.dim}
            accessibilityLabel={t.giftNote} style={S.input} />
          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
          {!!msg && <Text style={{ color: C.green, fontSize: FS.sm, marginTop: SP[2] }}>{msg}</Text>}
          <Btn v="teal" sm label={busy ? "…" : t.giftSend} onPress={gonder} disabled={busy || !secili} a11yLabel={t.giftSend} style={{ marginTop: SP[2] }} />
        </>
      )}
    </View>
  );
}
export function Wallet({ t, session, onBack }) {
  const [bal, setBal] = useState(null);
  // 🔴 v2.65 — useState([]) "defter boş" demekti; oysa henüz okunmamıştı.
  // null = yükleniyor, [] = gerçekten boş, loadErr = gelmedi.
  const [led, setLed] = useState(null);
  const [loadErr, setLoadErr] = useState(false);
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const uid = session?.user?.id; if (!uid) return;
    const { data, error } = await supabase.from("credit_ledger")
      .select("delta, reason, created_at, note").eq("user_id", uid)
      .order("created_at", { ascending: false }).limit(30);
    if (error) { setLoadErr(true); return; }
    setLoadErr(false);
    setLed(data || []);
    // Bakiye = defterin EN SON satirindaki balance_after (tek kaynak: credit_ledger).
    // Ayri bir RPC yok; olmayan fonksiyonu cagirmak yerine defterden okuyoruz.
    const { data: last, error: hata10 } = await supabase.from("credit_ledger")
      .select("balance_after").eq("user_id", uid)
      .order("created_at", { ascending: false }).limit(1);
      if (hata10) logError("ekranlar_yalin.js:3208", hata10);
    setBal(last?.[0]?.balance_after ?? 0);
  }, [session]);
  useEffect(() => { load(); }, [load]);

  // ══════════════════════════════════════════════════════════════════
  // 🔴 12 EYLÜL · GECE — KARTIN KİMLİĞİ. İKİ ALAN, TEK EK SORGU.
  // Bir "geçiş kartı"nda ad ve seviye yoksa o bir kart değil bir
  // etikettir. `profiles` + `trust_scores` zaten Profil ekranında
  // okunan iki tablo; burada yalnız iki sütun istiyoruz.
  // ⚠️ Hata hâlinde kart YOK OLMUYOR, yalnız adsız kalıyor: cüzdanın
  // asıl işi bakiye göstermek ve o bakiye ayrı bir sorgudan geliyor.
  // ══════════════════════════════════════════════════════════════════
  const [kimlik, setKimlik] = useState(null);
  useEffect(() => {
    const uid = session?.user?.id; if (!uid) return;
    let iptal = false;
    (async () => {
      const [{ data: pr }, { data: ts }] = await Promise.all([
        supabase.from("profiles").select("name").eq("user_id", uid).maybeSingle(),
        supabase.from("trust_scores").select("badge").eq("user_id", uid).maybeSingle(),
      ]);
      if (!iptal) setKimlik({ ad: pr?.name || "", rozet: badgeLabel(t, ts?.badge) });
    })();
    return () => { iptal = true; };
  }, [session]);

  // Üyelik numarası KULLANICI KİMLİĞİNDEN türüyor: yeni bir sütun
  // açmıyoruz, ama numara kullanıcı için SABİT — her açılışta aynı.
  // UUID'nin ilk 8 onaltılığı; kimliğin kendisini sızdırmıyor çünkü
  // 10'luk tabana indirgenip 8 haneye kırpılıyor.
  const uyeNo = (() => {
    const h = String(session?.user?.id || "").replace(/-/g, "").slice(0, 8);
    if (h.length < 8) return null;
    const n = String(parseInt(h, 16) % 100000000).padStart(8, "0");
    return `LL ${n.slice(0, 4)} ${n.slice(4)}`;
  })();

  // ════════════════════════════════════════════════════════════════════
  // 🔴 v2.95 — KREDİ PAKETLERİ (Gökberk madde 1)
  // "cüzdan sayfasında kredi paketleri dolarla satılıyor ve 20000 kredi vs
  //  satıyoruz. Bunu doğru şekilde düzenle... üyelik planı dışında ek bir
  //  satın alma gibi konumlandırılmalı."
  //
  // Eski hâli KODA GÖMÜLÜ bir sabitti:
  //     3000 / 8000 / 20000 kredi · $4.99 / $11.99 / $24.99
  // Üç ayrı kusur bir aradaydı:
  //  (a) PARA BİRİMİ yanlış — ürün Türkiye'de, planlar ₺ ile satılıyor.
  //  (b) BÜYÜKLÜK anlamsız — bu üründe 1 istek = 1 kredi. 20.000 kredi,
  //      20.000 lounge isteği demek. Rakamlar bir oyun para biriminden
  //      kopyalanmış gibiydi; ürünün kendi ekonomisiyle ilgisi yoktu.
  //  (c) KODDA duruyordu — fiyat değişince yeni bir APK gerekiyordu.
  //
  // 🆕 SINIF: "FİYAT KODA GÖMÜLÜYSE, FİYAT DEĞİŞTİRİLEBİLİR DEĞİLDİR;
  // BİR SÜRÜM NUMARASIDIR."
  // Artık SQL 248'deki `kredi_paketleri` tablosundan geliyor ve sunucuda
  // bir kapı var: paket kredisi abonelikten UCUZ olamaz (aksi hâlde
  // tekrar eden geliri kendi elimizle bozardık).
  // ════════════════════════════════════════════════════════════════════
  const [paket, setPaket] = useState(null);
  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("kredi_paketleri");
      if (error) { logError("kredi_paketleri", error); return; }
      if (!iptal) setPaket(data || null);
    })();
    return () => { iptal = true; };
  }, []);

  async function requestCredits() {
    setBusy(true); setMsg("");
    // 🔴 v2.74 — BU DÜĞME HİÇ ÇALIŞMIYORDU.
    // Doğrudan `notifications` tablosuna insert ediyordu ve
    // `authenticated` rolünün o tabloda INSERT hakkı YOK (ölçüldü).
    // PostgREST 42501 dönüyor, kullanıcı "bir şeyler ters gitti"
    // görüyordu. Zaten çalışmamalıydı: kullanıcının kendi kendine
    // bildirim yazabilmesi, istediği metni kaydedebilmesi demekti.
    // SQL 208 doğru yolu açtı: talep yöneticinin göreceği
    // `credit_requests` tablosuna düşüyor ve 24 saat hız sınırı var.
    const { data: cr, error } = await supabase.rpc("request_credit_topup", { p_note: null });
    setBusy(false);
    // 🔴 v2.65 — ham Postgres/Supabase metni kullanıcıya basılıyordu.
    // Cüzdan ürünün para konuştuğu yer; orada "duplicate key value violates
    // unique constraint" görmek güveni bitirir. mapErr sözlüğü zaten var.
    // RPC kendi mesajını döndürüyor ("zaten bekliyor" gibi) — motorun
    // cümlesi ekranın cümlesinden önce gelir (marka ilkesi §3).
    setMsg(error ? mapErr(t, error.message) : (cr && cr.mesaj) || t.walletRequested);
  }

  // 🔴 v2.50 — CİHAZDA GÖRÜLDÜ: hareketler ham veritabanı metniyle
  // basılıyordu ("session_settled", "paid_guest_thanks:da070c3a-8104-…",
  // "seed_test"). Sözlükte olmayan her sebep kullanıcıya OLDUĞU GİBİ
  // gösteriliyordu — üstelik bir de UUID'siyle. Cüzdan, ürünün para
  // konuştuğu tek yer; orada mühendis diliyle konuşmak güveni götürür.
  //
  // Üç kural: (1) sebep ekindeki ":<uuid>" atılır (2) sözlük tüm gerçek
  // sebepleri kapsar (3) sözlükte olmayan sebep ham basılmaz, "Kredi
  // düzeltmesi/işlemi" diye nötr ve doğru bir ada döner.
  const REASON = {
    beta_signup: t.ledBetaSignup, request_hold: t.ledHold, request_refund: t.ledRefund,
    request_capture: t.ledCapture, request_cancel_refund: t.ledCancelRefund,
    dispute_refund: t.ledDisputeRefund, admin_adjust: t.ledAdminAdjust, invite_hold: t.ledHold,
    session_settled: t.ledSessionSettled, paid_guest_thanks: t.ledPaidThanks,
    session_reward: t.ledSessionReward, referral_bonus: t.ledReferral,
    seed_test: t.ledSeed, purchase: t.ledPurchase, refund: t.ledRefund,
    // v2.100 — SQL 256: satın alma ve kapıda iade. Sözlükte olmayan bir
    // sebep "Kredi işlemi" diye nötrleşiyordu; para konuşan ekranda
    // "neden değişti?" sorusunun cevabı NÖTR OLAMAZ.
    kredi_satin_alma: t.ledSatinAlma, kapida_ret_iade: t.ledKapidaIade,
    request_stale_refund: t.ledStaleRefund, late_cancel_forfeit: t.ledLateCancel,
  };
  const reasonLabel = (raw) => {
    const base = String(raw || "").split(":")[0].trim();
    return REASON[base] || t.ledOther;
  };

  return (
    <Sayfa>
    <Hdr t={t} scene="CÜZDAN" title={t.walletTitle} sub={t.walletSub} onBack={onBack} />
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
      {/* 🔴 12 Eylül · gece — ETİKET GİTTİ, KART GELDİ.
          Eskisi: ortalanmış üç satır, `goldBg` dolgu, 12pt köşe.
          Yenisi: `GecisKarti` — eğime tepki veren tek yüzey. Bakiye
          kartın içinde ve HÂLÂ en büyük sayı; değişen konumu değil,
          etrafındaki nesne. */}
      {/* 🔴 12 EYLÜL — BAKİYE GELMEDİĞİNDE KART SESSİZCE "—" GÖSTERİYORDU.
          `44_cuzdan_ariza` sahnesi (defter çağrısı ağ hatası veriyor)
          ölçüldü: ekranın EN BÜYÜK sayısı bir tire, hiçbir açıklama yok.
          Hata mesajı vardı ama sayfanın çok altında, geçmiş bölümünde —
          yani kullanıcı "kredim sıfırlandı mı?" diye düşünüp çıkıyordu.
          Artık kart da söylüyor ve yeniden denemenin yolu orada.
          🆕 SINIF: "BİR HATA MESAJI, HATANIN GÖRÜNDÜĞÜ YERDE DEĞİLSE
          KULLANICI İÇİN YOK DEMEKTİR." */}
      <GecisKarti stil={{ marginBottom: loadErr ? ARA[10] : ARA[18] }}
        rozet={kimlik?.rozet} ad={kimlik?.ad} no={uyeNo}
        etiket={t.walletBalance} deger={loadErr ? "—" : (bal ?? "—")} birim={t.walletCredits}
        aciklama={loadErr ? t.walletBalanceFail
          : bal == null ? null
          : String(t.walletCreditsMeans).replace("{n}", String(bal))} />
      {loadErr && <LoadFail t={t} onRetry={load} style={{ marginBottom: ARA[18] }} />}

      <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: ARA[14], marginBottom: ARA[18] }}>
        <Text style={{ fontSize: FS.sm, color: C.goldInk, lineHeight: 19 }}>{t.walletBetaNote}</Text>
        <Btn label={busy ? "…" : t.walletRequestBtn} onPress={requestCredits} disabled={busy} style={{ marginTop: SP[3], opacity: busy ? 0.6 : 1 }} />
        {!!msg && <Text style={{ color: C.tealInk, fontSize: FS.sm, marginTop: SP[2], textAlign: "center" }}>{msg}</Text>}
      </View>

      <Text style={S.label}>{t.walletPacks}</Text>
      {/* Paketin NE OLDUĞUNU önce söylüyoruz: bir abonelik değil, takviye. */}
      <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: ARA[10] }}>{t.walletPacksIntro}</Text>
      {(paket?.paketler || []).map(p => (
        <View key={p.kod} style={[S.card, { flexDirection: "row", alignItems: "center", opacity: 0.75 },
                                  p.one_cikan && { borderColor: C.gold, borderWidth: 1.5 }]}>
          <View style={{ flex: 1, minWidth: 0, marginRight: ARA[10] }}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.lg }}>
              {p.ad}
            </Text>
            {/* 🔴 SAYININ BİRİMİ. "3 kredi" tek başına bilgi değil; bu üründe
                1 kredi = 1 lounge isteği ve bunu hiçbir yerde yazmıyorduk. */}
            <Text style={{ color: C.body, fontSize: FS.sm, marginTop: ARA[2] }}>
              {String(t.walletPackCredits).replace("{n}", String(p.kredi))}
            </Text>
            {!!p.aciklama && <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[2] }}>{p.aciklama}</Text>}
          </View>
          <View style={{ alignItems: "flex-end", flexShrink: 0 }}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.lg }}>{p.fiyat_try} ₺</Text>
            <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[2] }}>
              {String(t.walletPerCredit).replace("{n}", String(p.kredi_basina))}
            </Text>
            <Text style={{ fontSize: FS.xs, color: C.gold, marginTop: ARA[2], fontWeight: "600" }}>{t.walletSoon}</Text>
          </View>
        </View>
      ))}
      {/* 🔴 DÜRÜSTLÜK ŞERİDİ. Paket bilerek abonelikten pahalı. Bunu
          kullanıcı hesaplayıp bulmasın diye BİZ söylüyoruz. Gizlenen bir
          fiyat farkı, bulunduğu gün güveni bitirir. */}
      {!!paket?.abonelik_ipucu && (
        <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "35", borderRadius: R.sm, padding: SP[3], marginTop: SP[1] }}>
          <Text style={{ color: C.tealInk, fontSize: FS.sm, lineHeight: 18, fontWeight: "600" }}>
            {String(t.walletSubHint)
              .replace("{plan}", String(paket.abonelik_ipucu.plan || ""))
              .replace("{fiyat}", String(paket.abonelik_ipucu.fiyat_try))
              .replace("{kredi}", String(paket.abonelik_ipucu.aylik_kredi))
              .replace("{birim}", String(paket.abonelik_ipucu.kredi_basina))}
          </Text>
        </View>
      )}

      {/* ════════════════════════════════════════════════════════════
          MİSAFİR HAKKI HEDİYESİ (v2.96 · eleştiri A1 — yeni fikir)

          Gökberk: "başka ve ilgi çekici önerilerin varsa öner."

          GEREKÇE: bu kitlenin gerçekten değer verdiği şey KREDİ DEĞİL,
          CÖMERT GÖRÜNEBİLMEK. Zaten lounge'a girebilen bir insana "sana
          bir giriş hakkı verdik" demek zayıf; "arkadaşına bir giriş hakkı
          verebilirsin" demek güçlü. Statü, harcanabildiğinde statüdür.

          BİZE MALİYETİ SIFIR: hediye edilen şey host'un ZATEN ağırlayarak
          kazandığı kredi. Yeni kredi basmıyoruz, var olanı devredilebilir
          kılıyoruz.

          ÜÇ KAPI SUNUCUDA (SQL 249): yalnız AĞIRLAYARAK kazanılan hak
          devredilebilir (satın alınan kredi devredilemez → kredi ticareti
          doğmaz), alıcı kabul edilmiş bir bağlantı olmalı, günde 3 tavan.
          ════════════════════════════════════════════════════════════ */}
      <HediyeBolumu t={t} onDone={load} />

      <Text style={[S.label, { marginTop: ARA[18] }]}>{t.walletHistory}</Text>
      {loadErr ? <LoadFail t={t} onRetry={load} />
      : led === null ? <Load />
      : !led.length ? (
        <View style={S.card}><Text style={{ color: C.mutedAA, fontSize: FS.sm }}>{t.walletNoHistory}</Text></View>
      ) : led.map((r, i) => (
        <View key={i} style={[S.card, { flexDirection: "row", alignItems: "center", paddingVertical: SP[3] }]}>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: FS.sm, color: C.ink }}>{reasonLabel(r.reason)}</Text>
            {!!r.note && <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: 0 }}>{r.note}</Text>}
            <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[2] }}>
              {new Date(r.created_at).toLocaleDateString("tr-TR")}
            </Text>
          </View>
          <Text style={{ fontWeight: "700", fontSize: FS.lg, color: r.delta > 0 ? C.teal : r.delta < 0 ? C.red : C.mut }}>
            {r.delta > 0 ? "+" : ""}{r.delta || "0"}
          </Text>
        </View>
      ))}
    </ScrollView>
    </Sayfa>
  );
}


// ============ LOUNGE RADAR (033/034) ============
// NEDEN: Host'un tek motivasyonu "iyilik" olamaz. Dokuman §17 networking
// vaat ediyor ama uygulamada somut degildi. Radar bunu ANIN ICINDE somutlastirir.
// Kart yalnizca su anda bir lounge/havalimani baglami varsa gorunur.
export function LoungeRadarCard({ t, session, onOpen }) {
  const [r, setR] = useState(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("lounge_radar_count");
    if (error) return setR(null);
    // 3 durum: aktif+kisi var · konum kapali (acilabilir) · baglam yok
    if (data?.active && (data.count || 0) > 0) setR(data);
    else if (data?.can_enable) setR({ ...data, _enable: true });
    else setR(null);
  }, []);
  useEffect(() => {
    load();
    const id = setInterval(load, 120000); // 2 dk'da bir tazele
    return () => clearInterval(id);
  }, [load]);

  // Konum paylasimi kapali -> bilincli acma karti (opt-in, varsayilan false)
  async function enableRadar() {
    setBusy(true);
    const uid = session?.user?.id;
    if (uid) await supabase.from("profiles").update({ location_sharing: true }).eq("user_id", uid);
    setBusy(false);
    load();
  }

  if (!r) return null;

  if (r._enable) {
    return (
      <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: SP[4], marginBottom: SP[3] }}>
        {/* 🔴 19 EYLÜL — İKON METNE YAPIŞIKTI (ölçüm: 0 pt, 9 sahnede).
            `flexDirection: "row"` iki çocuğu yan yana koyuyor ama
            ARALARINA hiçbir şey koymuyor; ikonun sağ kenarı ile başlığın
            sol kenarı birbirine değiyordu. `kutu_tasma_check.py` eşiği
            4 pt; tasarımın satır içi ikon boşluğu ARA[10].
            🆕 SINIF: "YAN YANA DİZMEK ARALARINDA BOŞLUK BIRAKMAK DEĞİLDİR
            — `row` BİR HİZALAMA KARARIDIR, BİR RİTİM KARARI DEĞİL." */}
        <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[10] }}>
          <Ikon ad="radar" boy={22} renk={C.mutedAA} />
          <View style={{ flex: 1 }}>
            <Text style={{ color: C.goldInk, fontWeight: "700", fontSize: FS.base }}>{t.radarOffTitle}</Text>
            <Text style={{ color: C.goldInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 17 }}>{t.radarOffBody}</Text>
          </View>
        </View>
        <Btn label={busy ? "…" : t.radarEnable} onPress={enableRadar} disabled={busy} style={{ marginTop: SP[3], opacity: busy ? 0.6 : 1 }} />
      </View>
    );
  }

  return (
    <TouchableOpacity hitSlop={TAP.slop} onPress={() => onOpen(r)} activeOpacity={0.85}
      style={{ backgroundColor: C.gece, borderRadius: R.sm, padding: SP[4], marginBottom: SP[3], flexDirection: "row", alignItems: "center" }}>
      <Ikon ad="radar" boy={22} renk={C.mutedAA} />
      <View style={{ flex: 1 }}>
        <Text style={{ color: C.gold, fontWeight: "700", fontSize: FS.base }}>
          {(t.radarTitle || "Şu an {n} kişi daha burada").replace("{n}", r.count)}
        </Text>
        <Text style={{ color: C.warmGray, fontSize: FS.sm, marginTop: SP[1], lineHeight: 17 }}>
          {t.radarBody}
        </Text>
      </View>
      <Ikon ad="sag" boy={FS.title} renk={C.gold} />
    </TouchableOpacity>
  );
}


// ============ HOST BAŞVURUSU (036) — guest'ler için ============
// NEDEN: Guest olarak kaydolan biri sonradan lounge hakki edinebilir
// (kart yukseltmesi, yeni is, statu). Su ana kadar rol degistirmenin
// hicbir yolu yoktu -> arz tarafini buyutmenin en ucuz kanali kapaliydi:
// zaten uygulamada olan, guvenini kurmus, urunu anlamis insanlar.
export function HostApply({ t, session, onBack, onDone }) {
  const [app, setApp] = useState(null);
  const [src, setSrc] = useState(null);
  const [cap, setCap] = useState(null);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [phoneOk, setPhoneOk] = useState(true);

  // 🔴 v3.6 — AYNI SORU ÜÇ EKRANDA ÜÇ KEZ SORULUYORDU.
  //   1) HostAccessSource  → `save_host_access` ile YAZIYOR
  //   2) HostApply         → hiç okumuyor, sıfırdan soruyor  ← burası
  //   3) HostAvailability.publish() → yine soruyor
  // Kullanıcı cevabı zaten vermişti; ürün onu hatırlamıyor gibi
  // davranıyordu. Bir soruyu ikinci kez sormak, ilk cevabı kaydetmediğini
  // itiraf etmektir.
  //
  // 🆕 SINIF: "KULLANICIYA BİR ŞEYİ İKİNCİ KEZ SORMADAN ÖNCE, İLK CEVABI
  // NEREYE YAZDIĞINI SOR — GENELDE ORADA DURUYORDUR."
  //
  // Cevap varsa çip ÖN SEÇİLİ gelir; kullanıcı yine değiştirebilir
  // (kart yükseltmiş olabilir) — hatırlıyoruz, kilitlemiyoruz.
  // ⚠️ Üç sorgu tek dalgada: soru sayısını azaltırken tur sayısını
  // artırmıyoruz.
  const load = useCallback(async () => {
    const uid = session?.user?.id;
    const [bas, eri, dog] = await Promise.all([
      supabase.rpc("my_host_application"),
      supabase.rpc("my_host_access"),
      uid ? supabase.from("verifications").select("phone_verified").eq("user_id", uid).maybeSingle()
          : Promise.resolve({ data: null }),
    ]);
    setApp(bas.data || { status: "none" });
    if (uid) setPhoneOk(!!dog?.data?.phone_verified);
    const beyan = String(eri?.data?.access_source || "").split(", ").map(x => x.trim()).filter(Boolean);
    const eslesen = beyan.find(x => ACCESS_SOURCES.indexOf(x) >= 0);
    if (eslesen) setSrc(prev => prev || eslesen);
    const k = eri?.data?.guest_capacity;
    if (k > 0) setCap(prev => prev || Math.min(3, k));
  }, [session]);
  useEffect(() => { load(); }, [load]);

  async function submit() {
    setErr("");
    if (!src) return setErr(t.hostApplyErrSource);
    if (!cap) return setErr(t.hostApplyErrCap);
    setBusy(true);
    const { error } = await supabase.rpc("apply_for_host", {
      p_access_source: src, p_guest_capacity: cap, p_note: note.trim() || null,
    });
    setBusy(false);
    if (error) {
      const m = error.message || "";
      if (m.includes("phone_not_verified")) return setErr(t.e_phone_not_verified);
      if (m.includes("application_pending")) return setErr(t.hostApplyPending);
      if (m.includes("already_host")) return setErr(t.hostApplyAlready);
      return setErr(m);
    }
    load();
    onDone && onDone();
  }

  if (!app) return <View style={{ flex: 1, backgroundColor: C.paper, paddingTop: ARA[40] * 2, alignItems: "center" }}><ActivityIndicator color={C.gold} /></View>;

  return (
    <Sayfa>
    <Hdr t={t} ustBilgi={t.sceneHost} title={t.hostApplyTitle} sub={t.hostApplySub} onBack={onBack} />
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
      {app.status === "pending" ? (
        <View style={[S.card, { backgroundColor: C.goldSoft, borderColor: C.goldLine }]}>
          <IkonMetin ad="bekliyor" renk={C.goldInk} stilMetin={{ fontWeight: "700", color: C.goldInk, fontSize: FS.base }} metin={t.hostApplyPendingTitle} />
          <Text style={{ color: C.goldInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{t.hostApplyPendingBody}</Text>
          <Text style={{ color: C.goldInk, fontSize: FS.sm, marginTop: SP[2] }}>
            {app.access_source} · {app.guest_capacity} {t.hostApplyGuestUnit}
          </Text>
        </View>
      ) : app.status === "rejected" ? (
        <>
          <View style={[S.card, { backgroundColor: C.hataBg, borderColor: C.red }]}>
            <Text style={{ fontWeight: "700", color: C.redInk, fontSize: FS.base }}>{t.hostApplyRejTitle}</Text>
            {!!app.review_note && (
              <Text style={{ color: C.redInk, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{app.review_note}</Text>
            )}
            <Text style={{ color: C.redInk, fontSize: FS.sm, marginTop: SP[2] }}>{t.hostApplyRejAgain}</Text>
          </View>
          <HostApplyForm {...{ t, src, setSrc, cap, setCap, note, setNote, submit, busy, err, phoneOk }} />
        </>
      ) : (
        <HostApplyForm {...{ t, src, setSrc, cap, setCap, note, setNote, submit, busy, err, phoneOk }} />
      )}
    </ScrollView>
    </Sayfa>
  );
}
export function HostApplyForm({ t, src, setSrc, cap, setCap, note, setNote, submit, busy, err, phoneOk }) {
  return (
    <>
      {!phoneOk && (
        <View style={[S.card, { backgroundColor: C.hataBg, borderColor: C.red }]}>
          <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>{t.hostApplyNeedPhone}</Text>
        </View>
      )}

      <View style={{ backgroundColor: C.goldSoft, borderWidth: 1, borderColor: C.goldLine, borderRadius: R.sm, padding: SP[3], marginBottom: SP[4] }}>
        <Text style={{ color: C.goldInk, fontSize: FS.sm, lineHeight: 18 }}>{t.hostApplyWhy}</Text>
      </View>

      <Text style={S.label}>{t.accessSrcQ}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: ARA[6] }}>
        {ACCESS_SOURCES.map(a => (
          <TouchableOpacity key={a} onPress={() => setSrc(a)}
            style={[S.chip, src === a && S.chipOn, { marginBottom: SP[2] }]}>
            <Text style={{ color: src === a ? C.gold : C.ink, fontSize: FS.sm }}>{a}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <Text style={[S.label, { marginTop: SP[3] }]}>{t.capQ}</Text>
      <View style={{ flexDirection: "row", marginBottom: ARA[6] }}>
        {[1, 2, 3].map(n => (
          <TouchableOpacity key={n} onPress={() => setCap(n)}
            style={[S.chip, cap === n && S.chipOn]}>
            <Text style={{ color: cap === n ? C.gold : C.ink, fontSize: FS.sm }}>
              {n === 3 ? "3+" : n} {t.hostApplyGuestUnit}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <Text style={[S.label, { marginTop: SP[3] }]}>{t.hostApplyNote}</Text>
      <TextInput style={[S.input, { height: 76, textAlignVertical: "top" }]}
        value={note} onChangeText={v => setNote(v.slice(0, 140))} multiline
        placeholder={t.hostApplyNotePh} placeholderTextColor={C.mut} />
      <Text style={{ color: C.mut, fontSize: FS.xs, textAlign: "right" }}>{note.length}/140</Text>

      <Btn label={t.hostApplySend} onPress={submit} disabled={busy || !phoneOk} busy={busy} style={{ marginTop: ARA[18], opacity: (busy || !phoneOk) ? 0.5 : 1 }} />
      {!!err && <View style={S.errBox}><Text style={S.errText}>{err}</Text></View>}

      <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[14], lineHeight: 17 }}>{t.hostApplyDisclaimer}</Text>
    </>
  );
}

// ============================================================
// ProfileCompletionWidget — MVP v15 satir 3498-3538'in birebir portu.
// MVP mantigi: 6 alan, her biri esit agirlik (100/6 = ~17 puan).
//   Photo · Bio(20+ kar.) · Profession · LinkedIn · Languages · Access source
// Renk esigi MVP'den: >=80 yesil, >=50 altin, alti kirmizi. >=95 ise KART GIZLENIR.
// v1.21'e kadar bu kart hic yoktu — kullanicinin profilini neden
// tamamlamasi gerektigini soyleyen tek yer bu.
// ============================================================
export function ProfileCompletionWidget({ profile, onEdit, t }) {
  const { pct, missing } = getProfileCompletion(profile);
  if (pct >= 95) return null;
  // 5 Eylül — tasarım 09b: tek kompakt kart, altın iz kenar.
  //   "%17 · Profilini tamamla"
  //   "5 eksik: fotoğraf, biyografi, meslek"   (ilk üçü, gerisi "…")
  const adlar = missing.map(m => String(m.label).toLocaleLowerCase("tr-TR"));
  const liste = adlar.slice(0, 3).join(", ") + (adlar.length > 3 ? "…" : "");
  return (
    <TouchableOpacity hitSlop={TAP.slop} onPress={onEdit} accessibilityRole="button"
      accessibilityLabel={`%${pct} · ${t ? t.pcTitle : "Profilini tamamla"}`}
      style={{ flexDirection: "row", alignItems: "center", backgroundColor: C.surface || C.card,
               borderWidth: 1, borderColor: C.goldTrace || C.goldLine, borderRadius: R.lg,
               paddingVertical: ARA[14], paddingHorizontal: SP[4], marginBottom: ARA[14], minHeight: 64, ...ELEV.card }}>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={{ fontSize: FS.sm + 1, fontWeight: "700", color: C.ink }}>
          %{pct} · {t ? t.pcTitle : "Profilini tamamla"}
        </Text>
        <Text numberOfLines={1} style={{ fontSize: FS.xs + 1, color: C.mutedAA, marginTop: ARA[4] }}>
          {missing.length} {t ? String(t.pcMissingSuffix || "").split(" · ")[0] : "eksik"}: {liste}
        </Text>
      </View>
      <Ikon ad="sag" boy={16} renk={C.dim} />
    </TouchableOpacity>
  );
}

export const profOpts = (t) => PROF_KEYS.map(k => t[k]);
export function Amenities({ data, max = 6, size = "sm" }) {
  if (!data) return null;
  const keys = Object.keys(AMENITY_ICONS).filter(k => data[k] === true);
  if (!keys.length) return null;
  const shown = keys.slice(0, max);
  const rest = keys.length - shown.length + ((data.extra || []).length || 0);
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: SP[1] }}>
      {shown.map(k => (
        <View key={k} style={{ flexDirection: "row", alignItems: "center",
                               backgroundColor: C.bgAlt, borderRadius: R.xs,
                               paddingHorizontal: SP[2], paddingVertical: SP[1] }}>
          <Ikon ad={AMENITY_ICONS[k]} boy={size === "sm" ? 13 : 15} renk={C.mutedAA} />
          {size !== "sm" && (
            <Text style={{ fontSize: FS.xs, color: C.mutedAA, marginLeft: SP[1] }}>{AMENITY_TR[k]}</Text>
          )}
        </View>
      ))}
      {rest > 0 && (
        <Text style={{ fontSize: FS.xs, color: C.dimAA }}>+{rest}</Text>
      )}
    </View>
  );
}

// ============================================================
// SALON REHBERI (v2.43)
//
// 🔴 URUNUN EN BUYUK YAPISAL SORUNUNU COZUYOR: bugune kadar hicbir
// ekran BASKA KULLANICI OLMADAN degerli degildi. Uygulamayi ilk acan
// kisi bos bir kesif listesi goruyor ve gidiyordu.
//
// Bu ekran tek basina calisir: kart sec, cevabi al. Eslesme SONRA
// gelir. Iki tarafli pazarin klasik olumunun klasik cozumu budur —
// tek tarafli bir aracla basla.
//
// Giris GEREKTIRMEZ: guide_* fonksiyonlari anon'a acik.
// ============================================================
// ══════════════════════════════════════════════════════════════════════════
// 🔴 v3.6 — BU EKRAN ÜRÜNÜN EN İYİ SATIŞ ARACIYDI VE DUVARIN ARKASINDAYDI.
//
// Kendi alt metni şunu söylüyor (i18n `guideSub`):
//     "...hangi salona girebileceğini ve misafir götürüp götüremeyeceğini
//      söyleyelim. KAYIT GEREKMEZ."
// Ama ekrana ulaşmanın tek yolu `onGuide` propuydu ve o da yalnız
// `trips` sekmesinden geçiyordu — yani KAYIT OLMUŞ, sekme 2'ye gitmiş ve
// aşağı kaydırmış birinden. Alt metin yalan söylüyordu.
//
// Ve sunucu tarafı BAŞTAN doğru kurulmuş: `guide_airports`,
// `guide_lounges`, `guide_programs` üçü de `grant execute ... to anon`
// (SQL 143/147/154). Yani "kayıt gerekmez" bir niyet değil, ÖLÇÜLMÜŞ bir
// gerçekti — yalnız arayüz o kapıyı hiç açmamıştı.
//
// Bu boş bir pazaryerinde en değerli ekran: arz sıfırken bile bir SORUYA
// CEVAP veriyor. Ve cevabın sonunda `guideHostsCta` duruyor:
//     "{ap}'te seni içeri alabilecek {n} kişi var"
// — yani değer önce, kayıt sonra.
//
// 🆕 SINIF: "KAYIT DUVARINI DEĞERİN ÖNÜNE KOYARSAN, DEĞERİ GÖRMEYEN
// KİMSE DUVARI AŞMAZ — ÖNCE CEVABI VER, SONRA HESABI İSTE."
//
// `girisYok`: Splash'ten açıldığında kapanış CTA'sı Keşfet yerine KAYIT'a
// gider (giriş yapmamış kullanıcı Keşfet'i göremez).
export function LoungeGuide({ t, onBack, onDiscover, girisYok, onKayit }) {
  const [airports, setAirports] = useState([]);
  const [progs, setProgs] = useState([]);
  const [ap, setAp] = useState(null);
  const [prog, setProg] = useState(null);
  const [tier, setTier] = useState(null);
  const [rows, setRows] = useState(null);
  const [guideErr, setGuideErr] = useState(false);   // v2.65 — sessiz yutma bitti
  const [hosts, setHosts] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    supabase.rpc("guide_airports")
      .then(({ data, error }) => { if (error) return setGuideErr(true); setAirports(data || []); })
      .catch(() => setGuideErr(true));
    supabase.rpc("guide_programs")
      .then(({ data, error }) => { if (error) return setGuideErr(true); setProgs(data || []); })
      .catch(() => setGuideErr(true));
  }, []);

  useEffect(() => {
    if (!ap) { setRows(null); return; }
    setBusy(true);
    // 🔴 v2.65 — `.catch(() => setRows([]))` rehberi "bu havalimanında salon
    // yok" gibi gösteriyordu. Hata artık kendi durumu.
    setGuideErr(false);
    supabase.rpc("guide_lounges", {
      p_airport: ap.code, p_program_code: prog?.code || null, p_tier: tier?.code || null })
      .then(({ data, error }) => { if (error) { setGuideErr(true); setRows(null); return; } setRows(data || []); })
      .catch(() => { setGuideErr(true); setRows(null); })
      .finally(() => setBusy(false));
    // 🔴 KOPRU: rehber bir SONUC degil BASLANGIC olmali. "Misafir
    // goturemezsin" cevabinin hemen altinda "ama seni iceri alabilecek
    // N kisi var" yazmali.
    supabase.rpc("guide_hosts_today", { p_airport: ap.code })
      .then(({ data, error }) => setHosts(error ? null : data))
      .catch(() => setHosts(null));
  }, [ap, prog, tier]);

  const V = { yes: C.green, paid: C.amber, self_only: C.mut, no: C.red, info: C.teal };

  return (
    <ScrollView contentContainerStyle={{ padding: ARA[20], paddingBottom: ARA[40] }}>
      <TouchableOpacity hitSlop={TAP.slop} onPress={onBack}><IkonMetin ad="sol" renk={C.gold} stilMetin={{ color: C.gold, fontSize: FS.base }} metin={t.back} /></TouchableOpacity>
      <Text style={{ ...S.h1, color: C.ink, marginTop: SP[3] }}>{t.guideTitle}</Text>
      <Text style={{ fontSize: FS.sm, color: C.mut, lineHeight: 19, marginBottom: SP[4] }}>{t.guideSub}</Text>

      <Text style={S.label}>{t.guideAirport}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: ARA[14] }}>
        {airports.slice(0, 10).map(a => (
          <TouchableOpacity key={a.code} onPress={() => setAp(a)}
            style={[S.chip, { borderColor: ap?.code === a.code ? C.gold : C.line,
                              backgroundColor: ap?.code === a.code ? C.goldSoft : C.card }]}>
            <Text style={{ fontSize: FS.sm, color: ap?.code === a.code ? C.gold : C.ink,
                           fontWeight: ap?.code === a.code ? "700" : "400" }}>
              {a.code} · {a.lounges}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {!!ap && (
        <>
          <Text style={S.label}>{t.guideCard}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: ARA[10] }}>
            {progs.filter(p => p.popular).map(p => (
              <TouchableOpacity key={p.code} onPress={() => { setProg(p); setTier(null); }}
                style={[S.chip, { borderColor: prog?.code === p.code ? C.gold : C.line,
                                  backgroundColor: prog?.code === p.code ? C.goldSoft : C.card }]}>
                <Text style={{ fontSize: FS.sm, color: prog?.code === p.code ? C.gold : C.ink }}>{p.name}</Text>
              </TouchableOpacity>
            ))}
          </View>
          {!!prog && (prog.tiers || []).length > 0 && (
            <>
              <Text style={S.label}>{t.guideTier}</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: ARA[14] }}>
                {(prog.tiers || []).map(tr => (
                  <TouchableOpacity key={tr.code} onPress={() => setTier(tr)}
                    style={[S.chip, { borderColor: tier?.code === tr.code ? C.gold : C.line,
                                      backgroundColor: tier?.code === tr.code ? C.goldSoft : C.card }]}>
                    <Text style={{ fontSize: FS.sm, color: tier?.code === tr.code ? C.gold : C.ink }}>{tr.label}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            </>
          )}
        </>
      )}

      {busy && <Text style={{ color: C.mutedAA, fontSize: FS.sm }}>{t.loading}</Text>}

      {/* 🔴 v2.65 — hata boş sonuçtan ÖNCE. Rehber bir CEVAP ekranı;
          cevap gelmediyse bunu söylemek, yanlış cevap vermekten iyidir. */}
      {!busy && guideErr && <LoadFail t={t} onRetry={() => { if (ap) setAp({ ...ap }); }} />}

      {!guideErr && !!rows && rows.map((r, i) => (
        <View key={i} style={{ backgroundColor: C.card, borderWidth: 1,
                               borderColor: r.verdict === "yes" ? C.green + "45" : C.line,
                               borderRadius: R.sm, padding: SP[3], marginBottom: SP[2] , ...ELEV.card }}>
          <Text style={{ fontSize: FS.base, fontWeight: "700", color: C.ink }}>{r.lounge_name}</Text>
          {!!r.headline && (
            <Text style={{ fontSize: FS.sm, color: V[r.verdict] || C.mut, marginTop: SP[1], fontWeight: "600" }}>
              {r.headline}
            </Text>
          )}
          {!!r.detail && (
            <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[1], lineHeight: 18 }}>{r.detail}</Text>
          )}
          {!!r.amenities && <View style={{ marginTop: SP[2] }}><Amenities data={r.amenities} max={6} /></View>}
          {r.confidence === "unknown" && (
            <IkonMetin ad="uyari" renk={C.amber} stilMetin={{ fontSize: FS.xs, color: C.amber, marginTop: SP[1] }} metin={t.guideUnverified} />
          )}
        </View>
      ))}

      {!!hosts && hosts.count > 0 && (
        <TouchableOpacity hitSlop={TAP.slop}
          onPress={() => (girisYok ? (onKayit && onKayit()) : (onDiscover && onDiscover({ airport: ap.code })))}
          style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "40",
                   borderRadius: R.sm, padding: ARA[14], marginTop: ARA[6] }}>
          <Text style={{ fontSize: FS.base, fontWeight: "700", color: C.tealInk }}>
            {t.guideHostsCta.replace("{n}", String(hosts.count)).replace("{ap}", ap.code)}
          </Text>
          {/* Giriş yapmamış kullanıcı için kapanış: sayıyı GÖRDÜ, şimdi
              hesabı istiyoruz. Kayıt duvarı artık değerin ARKASINDA. */}
          {girisYok && (
            <Text style={{ fontSize: FS.sm, color: C.body, marginTop: ARA[6], lineHeight: 18 }}>
              {t.guideJoinCta}
            </Text>
          )}
        </TouchableOpacity>
      )}
    </ScrollView>
  );
}


// ============================================================
// v2.69 · VenuePrices — salonun kendi fiyat listesi
//
// 🔴 NEDEN AYRI BİLEŞEN: fiyat listesi salonların ÇOĞUNDA yok. Ana
// bileşene gömülü bir sorgu, her salon seçiminde boş dönen bir istek
// demekti. Kendi yaşam döngüsü olan küçük bir bileşen yalnız gerektiği
// yerde çalışır ve veri yoksa HİÇBİR ŞEY çizmez — boş bir başlık
// göstermek, bilgi vermemekten kötüdür.
// ============================================================
export function humanDate(iso) {
  if (!iso || iso.length !== 10) return null;
  const d = new Date(iso + "T12:00:00");
  if (isNaN(d)) return null;
  return `${TR_DAYS[d.getDay()]}, ${d.getDate()} ${TR_MONTHS[d.getMonth()]}`;
}
export function addDays(n) {
  const d = new Date(); d.setDate(d.getDate() + n); return isoOf(d);
}
export function DateInput({ label = "TARİH", value, onChange }) {
  const [open, setOpen] = useState(false);
  const human = humanDate(value);
  // Hızlı seçim: bugün, yarın ve sonraki iki gün. Havalimanı planları
  // ezici çoğunlukla bu pencerede — uzak tarih için seçici var.
  const quick = [
    [addDays(0), "Bugün"],
    [addDays(1), "Yarın"],
    [addDays(2), humanDate(addDays(2))?.split(",")[0] || "+2"],
    [addDays(3), humanDate(addDays(3))?.split(",")[0] || "+3"],
  ];
  return (
    <View style={{ marginBottom: ARA[14] }}>
      <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, marginBottom: SP[1], letterSpacing: 1 }}>{label}</Text>

      <View style={{ flexDirection: "row", flexWrap: "wrap", marginBottom: SP[2] }}>
        {quick.map(([iso, lb]) => {
          const sel = value === iso;
          return (
            <Secim key={iso} ton="teal" secili={sel} etiket={lb} onPress={() => onChange(iso)}
              stil={{ marginRight: ARA[6], marginBottom: ARA[6] }} />
          );
        })}
      </View>

      {_DTP ? (
        <>
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setOpen(true)}
            style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: human ? C.teal : C.line,
                     borderRadius: R.xs, padding: SP[3], flexDirection: "row",
                     justifyContent: "space-between", alignItems: "center" }}>
            <Text style={{ color: human ? C.ink : C.dim, fontSize: FS.base, fontWeight: human ? "600" : "400" }}>
              {human || "Tarih seç"}
            </Text>
            <Ikon ad="takvim" boy={22} renk={C.mutedAA} />
          </TouchableOpacity>
          {open && (
            <_DTP
              value={value && value.length === 10 ? new Date(value + "T12:00:00") : new Date()}
              mode="date" display="default" minimumDate={new Date()}
              onChange={(ev, d) => {
                setOpen(false);
                if (d && ev?.type !== "dismissed") onChange(isoOf(d));
              }} />
          )}
        </>
      ) : (
        <TextInput value={value}
          onChangeText={v => {
            const dg = v.replace(/\D/g, "").slice(0, 8);
            let out = dg.slice(0, 4);
            if (dg.length > 4) out += "-" + dg.slice(4, 6);
            if (dg.length > 6) out += "-" + dg.slice(6, 8);
            onChange(out);
          }}
          keyboardType="number-pad" placeholder="2026-07-20" placeholderTextColor={C.dim} maxLength={10}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: value?.length === 10 ? C.teal : C.line,
                   borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.sm }} />
      )}
      {!!human && (
        <Text style={{ fontSize: FS.xs, color: C.mutedAA, marginTop: SP[1] }}>{value}</Text>
      )}
    </View>
  );
}
export function ReportUser({ t, session, targetId, targetName, sessionId, onBack, onDone }) {
  const uid = session?.user?.id;
  const [type, setType] = useState(null);
  const [desc, setDesc] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [done, setDone] = useState(false);
  // Guvenlik Merkezi'nden gelindiginde hedef BELLI DEGIL — kisi secilmeli.
  // create_report bir hedef ister; "kimseyi" bildiremezsin. Bu yuzden
  // gecmiste temas ettigin kisileri listeliyoruz (oturum veya baglanti).
  const [pick, setPick] = useState({ id: targetId || null, name: targetName || null });
  const [contacts, setContacts] = useState(null);

  useEffect(() => {
    if (targetId) return;                       // hedef zaten belli
    (async () => {
      const { data: reqs, error: hata11 } = await supabase.from("requests")
        .select("guest_id, host_id, availabilities(host_id)")
        .or(`guest_id.eq.${uid},host_id.eq.${uid}`).limit(50);
        if (hata11) logError("ekranlar_yalin.js:3957", hata11);
      const ids = new Set();
      (reqs || []).forEach(r => {
        if (r.guest_id && r.guest_id !== uid) ids.add(r.guest_id);
        if (r.host_id && r.host_id !== uid) ids.add(r.host_id);
      });
      const { data: conns, error: hata12 } = await supabase.from("connection_requests")
        .select("from_id, to_id").eq("status", "accepted")
        .or(`from_id.eq.${uid},to_id.eq.${uid}`).limit(50);
        if (hata12) logError("ekranlar_yalin.js:3966", hata12);
      (conns || []).forEach(c => {
        if (c.from_id !== uid) ids.add(c.from_id);
        if (c.to_id !== uid) ids.add(c.to_id);
      });
      if (ids.size === 0) { setContacts([]); return; }
      const { data: ppl, error: hata13 } = await supabase.from("profiles")
        .select("user_id, name, photo_url").in("user_id", [...ids]);
        if (hata13) logError("ekranlar_yalin.js:3975", hata13);
      setContacts(ppl || []);
    })();
  }, [uid, targetId]);

  async function submit() {
    if (!pick.id) { setErr(t.repPickWho); return; }
    if (!type) { setErr(t.repPickType); return; }
    if (desc.trim().length < 10) { setErr(t.repNeedDesc); return; }
    setBusy(true); setErr("");
    const { error } = await supabase.rpc("create_report", {
      p_target: pick.id, p_type: type, p_description: desc.trim(),
      p_session: sessionId || null,
    });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    setDone(true);
    if (onDone) onDone();
  }

  if (done) return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneTrust} title={t.safetyReport} onBack={onBack} />
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", padding: ARA[22] }}>
        <Ikon ad="tamam" boy={FS.bant} renk={C.mut} />
        <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginTop: SP[3], textAlign: "center" }}>{t.repSent}</Text>
        <Text style={{ fontSize: FS.sm, color: C.mut, marginTop: SP[2], textAlign: "center", lineHeight: 20 }}>{t.repSentBody}</Text>
        <Btn label={t.close} onPress={onBack} style={{ marginTop: ARA[22], paddingHorizontal: ARA[40] }} />
      </View>
    </Sayfa>
  );

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneTrust} title={t.safetyReport} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {pick.id ? (
          <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14],
                         flexDirection: "row", alignItems: "center" }}>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: FS.sm, color: C.mutedAA }}>{t.repAbout}</Text>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginTop: ARA[2] }}>{pick.name || "—"}</Text>
            </View>
            {!targetId && (
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => setPick({ id: null, name: null })}>
                <Text style={{ color: C.goldInk, fontSize: FS.sm, fontWeight: "600" }}>{t.repChange}</Text>
              </TouchableOpacity>
            )}
          </View>
        ) : (
          <View style={{ marginBottom: ARA[14] }}>
            <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[2] }}>{t.repPickWho}</Text>
            {contacts === null ? <ActivityIndicator color={C.gold} />
              : contacts.length === 0 ? (
                <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, padding: ARA[14] }}>
                  <Text style={{ fontSize: FS.sm, color: C.mutedAA, lineHeight: 18 }}>{t.repNoContacts}</Text>
                </View>
              ) : contacts.map(c => (
                <TouchableOpacity hitSlop={TAP.slop} key={c.user_id} onPress={() => setPick({ id: c.user_id, name: c.name })}
                  style={{ flexDirection: "row", alignItems: "center", backgroundColor: C.card, borderWidth: 1,
                           borderColor: C.line, borderRadius: R.xs, padding: SP[3], marginBottom: SP[2] , ...ELEV.card }}>
                  <View style={{ width: 32, height: 32, borderRadius: R.full, backgroundColor: C.bgAlt,
                                 alignItems: "center", justifyContent: "center", marginRight: ARA[10] }}>
                    <Text style={{ fontWeight: "700", color: C.goldInk }}>{(c.name || "?").charAt(0).toUpperCase()}</Text>
                  </View>
                  <Text style={{ fontSize: FS.base, color: C.ink, flex: 1 }}>{c.name || "—"}</Text>
                  <Ikon ad="sag" boy={FS.base} renk={C.dimAA} />
                </TouchableOpacity>
              ))}
          </View>
        )}

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, letterSpacing: 1, marginBottom: SP[2] }}>{t.repType}</Text>
        {REPORT_TYPES.map(([k, lb, ic]) => {
          const sel = type === k;
          return (
            <Secim key={k} bicim="radyo" ton="amber" secili={sel} onPress={() => setType(k)}
              stil={{ marginBottom: SP[2] }}
              ikon={<Ikon ad={ic} boy={15} renk={sel ? C.amberInk : C.mutedAA} />}
              etiket={lb} />
          );
        })}

        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1, marginTop: SP[2], marginBottom: SP[1] }}>{t.repWhat}</Text>
        <TextInput value={desc} onChangeText={setDesc} multiline placeholder={t.repPlaceholder} placeholderTextColor={C.dim}
          style={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: desc.length >= 10 ? C.amber : C.line, borderRadius: R.xs,
                   padding: SP[3], height: 110, textAlignVertical: "top", color: C.body, fontSize: FS.sm }} />
        <Text style={{ fontSize: FS.xs, color: C.dimAA, textAlign: "right", marginTop: ARA[2] }}>{desc.length} / 10+</Text>

        <View style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, padding: SP[3], marginTop: ARA[14] }}>
          <Text style={{ fontSize: FS.sm, color: C.mutedAA, lineHeight: 17 }}>{t.repPrivacy}</Text>
        </View>

        {!!err && <View style={[S.err, { marginTop: SP[3] }]}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}

        <Btn v="gold" sm label={t.repSubmit} onPress={submit} disabled={busy} busy={busy} style={{ marginTop: SP[4] }} />
      </ScrollView>
    </Sayfa>
  );
}


// Kucuk rozet — RequestsPanel'in guven sinyalleri icin.
// 🔴 v3.4 — `onAddAvail` PROP'U KALDIRILDI (imzadan da).
// Prop imzada kalsaydı ileride biri onu yeniden geçer ve düğme geri
// gelirdi; `check.js`'in prop-drop nöbetçisi de bunu YAKALAYAMAZDI
// çünkü prop imzada VARDI. Kapıyı kapatmanın bir parçası, kapının
// kolunu da sökmektir.
//
// `onBack`: bu ekran artık ilan formunun yerine de çizilebiliyor
// (App.js · addAvail overlay'i, host olmayan için), o yüzden kendi
// çıkışına ihtiyacı var.
export function HostDaveti({ t, onBecomeHost, onBack }) {
  const [d, setD] = useState(null);
  const [hata, setHata] = useState(false);
  // 🔴 v3.6 — İKİ İKNA UNSURU YAZILMIŞ, ÇEVRİLMİŞ VE HİÇ ÇİZİLMEMİŞTİ.
  //
  // (a) `foundingLeft` ("İlk 100 host'tan {n} yer kaldı") YALNIZ profil
  //     düzenleme ekranının içinde çiziliyordu. Yani kıtlık cümlesi,
  //     kararı ÇOKTAN vermiş bir kullanıcıya gösteriliyordu. Kıtlığın
  //     işi kararı DÖNDÜRMEKTİR; karardan sonrası bir tebriktir.
  // (b) `waitingDemand` ("{ap} havalimanında seni bekleyen {n} yolcu var")
  //     i18n'de iki dilde duruyordu, HİÇBİR dosyada geçmiyordu.
  //
  // Bu ekran host kararının verildiği tek ekran; ikisinin de yeri burası.
  //
  // ⚠️ SAYIYI UYDURMUYORUM: `havalimani_nabzi(14)` zaten `talep_kaydi` ve
  // `aktif_seyahat` döndürüyor ve `authenticated`a açık. Gösterilen sayı
  // gerçek kayıtlardan geliyor; sıfırsa satır HİÇ çizilmiyor.
  //
  // 🆕 SINIF: "KITLIK CÜMLESİ KARARDAN SONRA GÖSTERİLİRSE PAZARLAMA
  // DEĞİL SÜSTÜR — İKNA, KARARIN VERİLDİĞİ EKRANDA DURUR."
  const [kurucu, setKurucu] = useState(null);
  const [talep, setTalep] = useState(null);

  // 🔴 v3.4 — "YENİDEN DENE" HİÇBİR ŞEYİ YENİDEN DENEMİYORDU.
  // Eski hâlde yükleme `useEffect(..., [])` içindeydi ve `onRetry` yalnız
  // `setHata(false)` yapıyordu: bayrak siliniyor, istek TEKRAR ATILMIYOR,
  // `d` hâlâ null → ekran kalıcı bir spinner'a düşüyordu. Yani düğme
  // kullanıcıyı hatadan çıkarıyor gibi yapıp sonsuz beklemeye sokuyordu.
  //
  // 🆕 SINIF: "'YENİDEN DENE' DÜĞMESİ İSTEĞİ YENİDEN ATMIYORSA, HATAYI
  // GİZLEYEN BİR DÜĞMEDİR — VE GİZLENEN HATA, GÖSTERİLENDEN KÖTÜDÜR."
  // ⚠️ ÜÇ SORGU TEK DALGADA. Sıraya dizseydim bu ekran üç Supabase turu
  // (ölçüldü: ~345 ms/tur) öderdi — bir ikna unsuru eklerken açılışı
  // yavaşlatmak, kazandığından fazlasını kaybetmektir.
  const yukle = useCallback(async () => {
    setHata(false); setD(null);
    const [ana, kur, nab] = await Promise.all([
      supabase.rpc("host_daveti"),
      supabase.rpc("founding_host_status"),
      supabase.rpc("havalimani_nabzi", { p_gun: 14 }),
    ]);
    if (ana.error) { logError("host_daveti", ana.error); setHata(true); return; }
    setD(ana.data || null);
    // Yan sorgular ikincil: düşerlerse ekran çizilmeye devam eder,
    // yalnız o satır görünmez. Ana akışı yan bilgiye rehin vermiyoruz.
    setKurucu(kur.error ? null : (kur.data || null));
    if (!nab.error && Array.isArray(nab.data)) {
      // Host'un en çok işe yarayacağı yer: talebi olan ama arzı olmayan
      // havalimanı. "Seni bekleyen" cümlesi ancak orada doğrudur.
      const aday = nab.data
        .map(x => ({ ...x, bekleyen: (x.talep_kaydi || 0) + (x.aktif_seyahat || 0) }))
        .filter(x => x.bekleyen > 0 && (x.acik_slot || 0) === 0)
        .sort((a, b) => b.bekleyen - a.bekleyen)[0];
      setTalep(aday || null);
    }
  }, []);
  useEffect(() => { yukle(); }, [yukle]);

  // 🔴 VE BU DAL ÇIKIŞSIZDI. Bu ekran tam ekran bir katman olarak da
  // çiziliyor (App.js · addAvail, host olmayan dal); hata hâlinde ne
  // başlık ne geri oku vardı. iOS'ta hiçbir çıkış yolu yok.
  if (hata) return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneHost} title={t.hdTitle || t.subTabListings} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4] }}>
        <LoadFail t={t} onRetry={yukle} />
      </ScrollView>
    </Sayfa>
  );
  if (!d) return <Load t={t} title={t.hdTitle || t.subTabListings} onBack={onBack} />;

  const ph = d.plan_hediyesi || {};
  const basamaklar = Array.isArray(d.basamaklar) ? d.basamaklar : [];

  return (
    <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
      {/* EN ÜSTTE ÇERÇEVE — ödül değil, KARAR. */}
      <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "35",
                     borderRadius: R.sm, padding: SP[4], marginBottom: ARA[14] }}>
        <Text style={{ color: C.tealInk, fontSize: FS.micro, letterSpacing: 1.6, fontWeight: "700" }}>
          {BUYUK(t.hdEyebrow || "")}
        </Text>
        <Text style={{ color: C.ink, fontSize: FS.lg, fontWeight: "700", marginTop: SP[2], lineHeight: 22 }}>
          {t.hdTitle}
        </Text>
        <Text style={{ color: C.body, fontSize: FS.sm, marginTop: SP[2], lineHeight: 18 }}>
          {d.cerceve}
        </Text>
      </View>

      {/* EN SOMUT KARŞILIK EN ÜSTTE: 30 gün ücretsiz üst plan. */}
      {!!ph.esik && (
        <View style={{ backgroundColor: C.goldBg, borderWidth: 1.5, borderColor: C.gold,
                       borderRadius: R.sm, padding: SP[4], marginBottom: ARA[14] }}>
          <Text style={{ color: C.goldText, fontSize: FS.micro, letterSpacing: 1.6, fontWeight: "700" }}>
            {BUYUK(t.hdGiftEyebrow || "")}
          </Text>
          <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "700", marginTop: SP[2], lineHeight: 20 }}>
            {String(t.hdGiftLine || "")
              .replace("{n}", String(ph.esik))
              .replace("{plan}", String(ph.plan_adi || ph.plan || ""))
              .replace("{gun}", String(ph.gun))}
          </Text>
          {!!ph.aylik_try && (
            <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: ARA[6], lineHeight: 18 }}>
              {String(t.hdGiftWorth || "").replace("{try}", String(ph.aylik_try))}
            </Text>
          )}
          {ph.kalan_agirlama > 0 && d.agirlamam > 0 && (
            <Text style={{ color: C.gold, fontSize: FS.sm, marginTop: ARA[6], fontWeight: "700" }}>
              {String(t.hdGiftLeft || "").replace("{n}", String(ph.kalan_agirlama))}
            </Text>
          )}
        </View>
      )}

      {/* MERDİVEN — katalogdan geliyor, burada sabit metin yok. */}
      <Text style={S.label}>{t.hdLadder}</Text>
      {basamaklar.map((b) => {
        const ayricaliklar = [
          b.siralama_ek > 0 ? String(t.hdRank).replace("{n}", String(b.siralama_ek)) : null,
          b.one_cikar_saat > 0 ? String(t.hdFeature).replace("{n}", String(b.one_cikar_saat)) : null,
          b.istek_bedava ? t.hdFreeReq : null,
        ].filter(Boolean);
        return (
          <View key={b.code} style={[S.card, b.ulasildi && { borderColor: C.teal, borderWidth: 1.5 }]}>
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              <View style={{ width: 34, height: 34, borderRadius: R.full, marginRight: ARA[10],
                             alignItems: "center", justifyContent: "center",
                             backgroundColor: b.ulasildi ? C.tealBg : C.bgAlt }}>
                <Text style={{ fontSize: FS.sm, fontWeight: "700", color: b.ulasildi ? C.teal : C.mut }}>
                  {b.ulasildi ? "" : b.agirlama}
                </Text>
              </View>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text numberOfLines={1} style={{ fontSize: FS.base, fontWeight: "700", color: C.ink }}>{b.ad}</Text>
                <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: 0 }}>
                  {b.agirlama === 0 ? t.hdStart : String(t.hdAfterN).replace("{n}", String(b.agirlama))}
                </Text>
              </View>
            </View>
            {ayricaliklar.length > 0 && (
              <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[2] }}>
                {ayricaliklar.map((a, i) => <Pill key={i} c={b.ulasildi ? C.teal : C.muted}>{a}</Pill>)}
              </View>
            )}
          </View>
        );
      })}

      {/* EYLEM — erişim kaynağı beyan edilmemişse önce o sorulur. */}
      {/* 🔴 v3.4 — SAHİP OLDUĞUMUZ CÜMLE ARTIK ÜRÜNÜN İÇİNDE.
          "Kartında bir kişilik yer var." pazarlama tarafında bizim
          cümlemiz; uygulamada hiç geçmiyordu. Reklamda duyduğu cümleyi
          üründe bulamayan kullanıcı iki ayrı şey görür. */}
      {/* GERÇEK TALEP — sayı sıfırsa satır yok. Boş bir söz vermiyoruz. */}
      {!!talep && (
        <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.teal + "35",
                       borderRadius: R.sm, padding: SP[3], marginTop: ARA[20] }}>
          <Text style={{ color: C.tealInk, fontSize: FS.sm, lineHeight: 18, textAlign: "center" }}>
            {String(t.waitingDemand || "")
              .replace("{ap}", String(talep.airport_code))
              .replace("{n}", String(talep.bekleyen))}
          </Text>
        </View>
      )}

      <Text style={{ fontSize: FS.lg, fontWeight: "700",
                     color: C.ink, textAlign: "center", marginTop: ARA[20] }}>
        {t.hdHook}
      </Text>

      {/* KITLIK — kararın hemen üstünde, kararın kendisinden sonra değil. */}
      {!!kurucu && !kurucu.mine && kurucu.left > 0 && (
        <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "700",
                       textAlign: "center", marginTop: SP[2], lineHeight: 18 }}>
          {String(t.foundingLeft || "").replace("{n}", String(kurucu.left))}
        </Text>
      )}
      {!!kurucu && !!kurucu.mine && (
        <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "700",
                       textAlign: "center", marginTop: SP[2] }}>
          {String(t.foundingMine || "").replace("{n}", String(kurucu.mine))}
        </Text>
      )}

      <Btn v="gold" sm label={t.hdCta} onPress={onBecomeHost} a11yLabel={t.hdCta} style={{ marginTop: SP[4] }} />
      {/* `onBack` yalnız bu ekran TAM EKRAN çizildiğinde geliyor
          (App.js · addAvail overlay'inin host olmayan dalı). Seyahatlerim
          içine gömülüyken zaten sayfanın kendi geri yolu var. */}
      {!!onBack && (
        <TouchableOpacity onPress={onBack} accessibilityRole="button"
          style={{ minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center", marginTop: SP[2] }}>
          <Text style={{ color: C.mut, fontSize: 13, fontWeight: "600" }}>{t.back || "Geri"}</Text>
        </TouchableOpacity>
      )}
      {/* ═══════════════════════════════════════════════════════════════
          🔴 v3.4 — "+ MÜSAİTLİK EKLE" BURADAN KALDIRILDI.

          Bu ekran HOST OLMAYAN kişiye gösteriliyor (merdiven/davet).
          Buradaki düğme doğrudan ilan formunu açıyordu ve formda rol
          kontrolü YOKTU. Yani misafir iki dokunuşla ilan açabiliyordu —
          ve sunucu (SQL 055) onu SESSİZCE host yapıyordu.

          Gökberk: "Guest ilan açamamalı... Bu madde çok kritik." Sızıntı
          tam olarak bu düğmeydi.

          🆕 SINIF: "BİR DAVET EKRANINA DAVET ETTİĞİN ŞEYİN KENDİSİNİ
          KOYARSAN, O ARTIK DAVET DEĞİL AÇIK KAPIDIR."

          Host olmanın yolu kapanmadı: yukarıdaki "Host ol" düğmesi
          erişim kaynağını sorup `rolumu_sec('host')` çağırıyor. İlan
          formu ondan SONRA açılıyor. Sunucu kapısı: SQL 261.
          ═══════════════════════════════════════════════════════════ */}
      <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[10], lineHeight: 15, textAlign: "center" }}>
        {t.hdNote}
      </Text>
    </ScrollView>
  );
}

// ════════════════════════════════════════════════════════════════════════
// SAKİN GÜN (v2.96 · eleştiri E1 + E5)
//
// Ana sayfa artık yalnız aksiyon taşıyor. Peki bekleyen iş YOKSA?
//
// 🔴 Eski davranış: boş ekran. Ve eleştiri raporundaki E5 tam da buydu —
// "boş durumlar ağın boş olduğunu gizliyor". Ekranlar "veri yok" diyordu;
// dürüst cümle "bu havalimanında henüz host yok — ilk sen ol" idi.
//
// 🆕 SINIF: "BOŞ DURUM BİR HATA MESAJI DEĞİL, EN UCUZ DÖNÜŞÜM ALANIDIR."
//
// Bu kart üç şeyi birden yapıyor:
//   · ağın gerçek hâlini SÖYLÜYOR (havalimani_nabzi — gizlemiyor)
//   · o hâle uygun TEK bir sonraki adımı öneriyor
//   · host olmayan kişiye merdiveni hatırlatıyor
// ════════════════════════════════════════════════════════════════════════
export function BaglantiIstekleri({ t, lang, embedded = false, yalnizGelen = false, onOpenChat, onOpenProfile }) {
  const [rows, setRows] = useState(null);
  const [busy, setBusy] = useState(null);
  const [err, setErr] = useState("");

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("baglanti_istekleri");
    if (error) { logError("baglanti_istekleri", error); setRows([]); return; }
    setRows(Array.isArray(data) ? data : []);
  }, []);
  useEffect(() => { load(); const iv = setInterval(load, 30000); return () => clearInterval(iv); }, [load]);

  async function yanitla(id, kabul) {
    setBusy(id); setErr("");
    const { data, error } = await supabase.rpc("respond_connection", { p_id: id, p_accept: kabul });
    setBusy(null);
    if (error) { setErr(mapErr(t, error.message)); return; }
    load();
    if (kabul && data && data.channel_id && onOpenChat) {
      const r = (rows || []).find(x => x.id === id);
      onOpenChat(data.channel_id, r ? r.peer_name : "");
    }
  }

  const liste = rows || [];
  const gelen = liste.filter(r => r.yon === "gelen" && r.durum === "pending");
  const giden = liste.filter(r => r.yon === "giden");

  const kart = (r) => {
    const baglam = [r.salon, r.airport_code,
      r.avail_date ? fmtLongDate(r.avail_date, lang) : null].filter(Boolean).join(" · ");
    return (
      <View key={r.id} style={[S.card, { padding: SP[3] }]}>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          <TouchableOpacity hitSlop={TAP.slop} disabled={!onOpenProfile}
            onPress={() => onOpenProfile && onOpenProfile(r.peer_id)} activeOpacity={0.7}
            style={{ flexDirection: "row", alignItems: "center", flex: 1, minWidth: 0 }}>
            <View style={{ width: 40, height: 40, borderRadius: R.md, backgroundColor: C.purpleBg,
                           alignItems: "center", justifyContent: "center", marginRight: ARA[10], overflow: "hidden" }}>
              {r.peer_photo
                ? <Image source={{ uri: r.peer_photo }} style={{ width: 40, height: 40 }} />
                : <Text style={{ fontWeight: "700", color: C.purpleInk, fontSize: FS.lg }}>{(r.peer_name || "?").charAt(0).toUpperCase()}</Text>}
            </View>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text numberOfLines={1} style={{ fontSize: FS.base, fontWeight: "700", color: C.ink }}>{shortName(r.peer_name)}</Text>
              {!!r.peer_profession && <Text numberOfLines={1} style={{ fontSize: FS.xs, color: C.mut, marginTop: 0 }}>{r.peer_profession}</Text>}
            </View>
          </TouchableOpacity>
          {/* YÖN, kartın en önemli tek bilgisi: ben mi gönderdim, bana mı geldi.
              Rengi de ayrı — mor giden, yeşil gelen. */}
          <View style={{ flexShrink: 0, backgroundColor: r.yon === "gelen" ? C.greenBg : C.purpleBg,
                         borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2], marginLeft: SP[2] }}>
            <Text style={{ fontSize: FS.xs, fontWeight: "600", color: r.yon === "gelen" ? C.green : C.purple }}>
              {r.yon === "gelen" ? t.connIncoming : t.connOutgoing}
            </Text>
          </View>
        </View>

        <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", marginTop: SP[2] }}>
          {!!r.peer_badge && <Pill c={C.teal}>• {badgeLabel(t, r.peer_badge)}</Pill>}
          {r.peer_score != null && <Pill c={r.peer_score >= 70 ? C.green : r.peer_score >= 50 ? C.gold : C.muted}>{t.trust} {r.peer_score}</Pill>}
          {!!r.intent && <Pill c={C.purple}>{intentLabel(t, r.intent)}</Pill>}
        </View>

        {!!baglam && <Text numberOfLines={1} style={{ fontSize: FS.xs, color: C.mut, marginTop: SP[1] }}>{baglam}</Text>}
        {!!r.intro && (
          <Text numberOfLines={3} style={{ fontSize: FS.sm, color: C.body, marginTop: ARA[6], fontStyle: "italic", lineHeight: 17 }}>
            "{r.intro}"
          </Text>
        )}

        {r.durum === "pending" && r.yon === "gelen" ? (
          <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
            <Btn v="purple" sm label={t.connAccept} onPress={() => yanitla(r.id, true)}
              disabled={busy === r.id} busy={busy === r.id} style={{ flex: 1 }} />
            <Btn v="muted" sm label={t.decline} onPress={() => yanitla(r.id, false)}
              disabled={busy === r.id} style={{ flex: 1 }} />
          </View>
        ) : r.durum === "accepted" ? (
          <TouchableOpacity hitSlop={TAP.slop}
            onPress={async () => {
              if (r.channel_id && onOpenChat) { onOpenChat(r.channel_id, r.peer_name); return; }
              const { data, error } = await supabase.rpc("baglanti_sohbeti_ac", { p_conn_id: r.id });
              if (error) { setErr(mapErr(t, error.message)); return; }
              if (data && data.channel_id && onOpenChat) onOpenChat(data.channel_id, r.peer_name);
            }}
            accessibilityRole="button" accessibilityLabel={t.openChat}
            style={{ marginTop: ARA[10], minHeight: TAP.minHeight, justifyContent: "center" }}>
            <IkonMetin sag ad="sag" renk={C.purple} stilMetin={{ color: C.purple, fontSize: FS.sm, fontWeight: "700" }} metin={t.openChat} />
          </TouchableOpacity>
        ) : (
          /* GÖNDERDİĞİN VE HENÜZ YANITLANMAYAN İSTEK — madde 9'un özü.
             "Yanıt bekliyor" demek, hiçbir şey dememekten iyidir. */
          <Text style={{ fontSize: FS.sm, color: r.durum === "declined" ? C.red : C.mut, marginTop: SP[2] }}>
            {r.durum === "pending" ? t.connAwaiting
              : r.durum === "declined" ? t.connDeclinedNote : ""}
          </Text>
        )}
      </View>
    );
  };

  if (embedded) {
    if (rows === null) return <Load t={t} title={t.connReqTitle} />;
    if (!liste.length) return (
      <BosDurum ikon="kisiler" metin={t.connReqEmpty} />
    );
    return (
      <View>
        {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
        {gelen.length > 0 && <Text style={S.label}>{t.connIncomingTitle}</Text>}
        {gelen.map(kart)}
        {giden.length > 0 && <Text style={S.label}>{t.connOutgoingTitle}</Text>}
        {giden.map(kart)}
      </View>
    );
  }

  // 🔴 v2.96 (E1) — ANA SAYFADA YALNIZ GELEN İSTEKLER.
  // Gönderdiğin istek bir BEKLEYİŞTİR, aksiyon değil; onun yeri Tanış >
  // İstekler sekmesi. Ana sayfa artık yalnız "senden bir şey bekleniyor"
  // diyen kartları taşıyor. Aynı kartı iki yerde göstermek, kullanıcıya
  // ikisinin farklı şeyler olduğunu düşündürür.
  if (yalnizGelen && !gelen.length) return null;
  if (!liste.length) return null;
  const ozet = [
    gelen.length ? String(t.connIncomingN).replace("{n}", String(gelen.length)) : null,
    (!yalnizGelen && giden.length) ? String(t.connOutgoingN).replace("{n}", String(giden.length)) : null,
  ].filter(Boolean).join(" · ");
  return (
    <Katlanir baslik={t.connReqPanelTitle} ozet={ozet} acikBasla={gelen.length > 0}
      tint={gelen.length ? C.purpleBg : undefined}>
      {!!err && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
      {gelen.map(kart)}
      {!yalnizGelen && giden.map(kart)}
    </Katlanir>
  );
}
