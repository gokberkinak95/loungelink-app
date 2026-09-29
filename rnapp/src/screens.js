import FlightField from "./FlightField";
import { HostPanel, useReciprocityMoment } from "./HostWallet";
import MomentScreen from "./MomentScreen";
import { CarrierPicker, Katlanir } from "./Pickers";
import { badgeLabel, fmtLongDate, mapErr, shortName, sinirMetni, BUYUK, gorunur, etkinDil } from "./i18n";
import { LEGAL_DOCS, LEGAL_ORDER } from "./legal";
import { bayrak } from "./runtime";
import { sadeGorunumMu, sadeGorunumYaz } from "./atmosfer";
import { temaTercihi, temaTercihYaz } from "./tema_tercih";
import { logError, supabase } from "./supabase";
import { havalimanlariniGetir, carrierlariGetir } from "./katalog";
import { MONO } from "./typography";
import { ARA, ELEV, C, F, FS, R, SATIR, SP, T, TAP } from "./theme";
import { BosDurum, ChipIcon, Hdr, LoadFail, Toggle, ToneBadge, Sayfa, Btn, Secim, Cip, CuzdanSeridi, useDaralanBant, Kaydirma, PerdeBulanik, POPUP_YUZEY } from "./ui";
import { Ikon, IkonMetin, BilgiRozeti } from "./ikon";
import React, { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, BackHandler, Image, Modal, ScrollView, Share, StyleSheet, Text, TextInput, TouchableOpacity, View } from "react-native";
import { Amenities, BaglantiIstekleri, Chat, DateInput, HaberVer, LiveStatus, Picker, Plans, ProfileCompletionWidget, ReportUser, RequestsPanel, VerifyPhone, profOpts, timeOk } from "./ekranlar_yalin";
import { ustIsik, ACCESS_SOURCES, AirportPicker, CarrierChip, FieldReportPrompt, LANG_OPTS, LegalDoc, Load, PURPOSES, Pill, PromiseBox, RefCodeEntry, ReqStateBadge, S, SECTOR_OPTS, TrustRing, VenuePrices, _DTP, abbrevName, dateOk, geriSayim, getProfileCompletion, greeting, intentLabel, pickAndUploadPhoto } from "./ortak";

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
export * from "./ekranlar_ana";
import { ActionNeeded, Campaigns, CompanionChat, ConfirmModal, Discovery, EditProfile, FindHostCard, HomeConnections, HostAccessSource, LoungePicker, Meet, PhoneGate, PublicProfile, Referral, Safety, SakinGun, SessionHistory, SeyahatFormu, SihirbazBasi, SihirbazAlti, KisiSayisi, TimeInput, TrustVisual, visOpts } from "./ekranlar_ana";
import { yerelGun } from "./zaman";
import { OnayDamgasi } from "./hareket";

export function Trips({ t, session, onDiscover, onAddTrip, onEditTrip, lang, bnt }) {
  const uid = session?.user?.id;
  const [rows, setRows] = useState(null);
  // 🔴 v2.65 — HATA BAYRAĞI. Öncesinde `const { data } = await ...` yazılıyor,
  // error hiç okunmuyordu: ağ koptuğunda `data` null gelip boş listeye
  // dönüşüyor ve kullanıcı "hiç seyahatin yok" görüyordu. Boş durum DAVET
  // eder, hata durumu YENİDEN DENEMEYE çağırır — ikisi aynı ekran olamaz.
  const [loadErr, setLoadErr] = useState(false);
  const [adding, setAdding] = useState(false);
  const [airports, setAirports] = useState([]);
  const [ap, setAp] = useState(null);
  const [dest, setDest] = useState(null);
  // 🔴 v2.23 — SEYAHATTE DE HAVAYOLU VE CHARTER.
  // Ilanda soruyoruz ama misafirin tarafinda sormuyorduk; oysa kural
  // IKI TARAFI birden ilgilendiriyor: "misafir ayni havayolunda mi",
  // "misafirin seferi charter mi". Tek tarafi bilmek, kurali yarim
  // uygulamaktir — ve yarim uygulanan kural kapida cozulur.
  const [carriers, setCarriers] = useState([]);
  const [carrier, setCarrier] = useState(null);
  const [carrierOpen, setCarrierOpen] = useState(false);
  const [vCharter, setVCharter] = useState(false);
  const [kisi, setKisi] = useState(1);          // SQL 283
  const [cocuk, setCocuk] = useState([]);
  // v2.68: fInfo/fBusy state'i FlightField'a taşındı — burada ölü kalmıştı.
  const [date, setDate] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [flight, setFlight] = useState("");
  // 🔴 v2.79 — SATIR-İÇİ FORM SEYAHAT AMACINI HİÇ SORMUYORDU.
  // Ölçüm (sağlayıcı Ö9 ekranı): `visits.purpose` 0/8 dolu. Sebep tek bir
  // eksik alan değil, İKİ FARKLI YAZMA YOLU: `AddVisit` ekranı amacı
  // yazıyor, buradaki satır-içi form yazmıyordu. Bu form ölü de değil —
  // boş durumdaki "Seyahat ekle" düğmeleri (aşağıda `setAdding(true)`)
  // doğrudan buraya getiriyor. Yani İLK seyahatini boş ekrandan ekleyen
  // kullanıcıya amaç hiç sorulmuyordu; ikinci seyahatini ekleyene
  // soruluyordu. Aynı veri, iki kullanıcıya iki farklı davranış.
  const [purpose, setPurpose] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  // Var olan bir seyahate sonradan amaç yazarken hangi kartın beklediği
  const [purpBusy, setPurpBusy] = useState(null);

  const load = useCallback(async () => {
    // 🔴 Süresi GEÇMİŞ seyahatler listede kalmamalı — "30 Temmuz 14-16"
    // biter bitmez o kartın ve ona bağlı host-bul bağlamının düşmesi gerekir.
    const today = yerelGun();
    const { data, error } = await supabase.from("visits").select("*")
      .eq("user_id", uid).gte("visit_date", today).order("visit_date");
    if (error) { setLoadErr(true); return; }
    setLoadErr(false);
    setRows(data || []);
  }, [uid]);

  useEffect(() => {
    load();
    havalimanlariniGetir()
      .then((data) => setAirports((data || []).map(a => ({ key: a.code, label: `${a.code} — ${a.city}`, sub: a.name }))));
    // Havayolu listesi İKİNCİL bir seçici: gelmezse form çalışır (uçuş
    // isteğe bağlı). Yine de error açıkça okunuyor — sessizce yutulmuyor.
    carrierlariGetir().then((data) => setCarriers(data || []));
  }, [load]);

  async function save() {
    setErr("");
    if (!ap) return setErr(t.errAirport);
    if (!dateOk(date)) return setErr(t.errDate);
    if (!timeOk(from) || !timeOk(to) || from >= to) return setErr(t.errTime);
    setBusy(true);
    // 🔴 v2.96 (eleştiri C3) — DOĞRUDAN TABLO YAZIMI KALDIRILDI.
    // Bu satır `visits`e doğrudan insert ediyordu; yani "geçmiş tarih",
    // "bitiş başlangıçtan önce", "bilinmeyen havalimanı" ve "aynı saatte
    // ikinci seyahat" kurallarının HİÇBİRİ sunucuda uygulanmıyordu —
    // yalnız ekranın kendi kontrolleri vardı ve onları atlamak bir HTTP
    // isteği kadar kolaydı.
    // 🆕 SINIF: "HER DOĞRUDAN YAZMA BİR AÇIK DEĞİLDİR — AÇIK OLAN, KURALI
    // OLAN BİR TABLOYA KURALSIZ YAZMAKTIR."
    const { error } = await supabase.rpc("seyahat_ekle", {
      p_airport: ap.key, p_destination: dest?.key || null,
      p_date: date, p_from: from, p_to: to,
      p_flight: flight.trim() || null,
      p_purpose: purpose || null,
      p_carrier: carrier || null,
      p_kisi: Number(kisi) || 1,
      p_cocuk_yas: cocuk.length ? cocuk : null,
    });
    setBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    setAdding(false); setAp(null); setDest(null); setDate(""); setFrom(""); setTo(""); setFlight("");
    setCarrier(null); setVCharter(false); setPurpose(""); setKisi(1); setCocuk([]);
    load();
  }

  const dateChips = [...new Set((rows || []).map(r => r.avail_date))].sort().slice(0, 8);

  // 🔴 v2.87 (madde 11) — "BU SEYAHATLE UYUMLU KAÇ İLAN VAR?"
  // Gökberk: "bu seyahat ile uyumlu x ilan var gibi bir şey göstersek iyi
  // olmaz mı."
  // Seyahat kartı bugüne kadar yalnız kullanıcının KENDİ girdisini geri
  // okuyordu; karşı tarafta bir şey olup olmadığını söylemiyordu. Bir
  // seyahat kaydetmenin işe yarayıp yaramadığı ancak Keşfet'e girip
  // aranarak anlaşılıyordu.
  //
  // YENİ RPC YAZMADIM. `discover_availabilities` filtresiz çağrılıyor
  // (FindHostCard aynı çağrıyı aynı sebeple yapıyor: sayılar tek kaynaktan
  // gelsin, kart bir şey derken liste başka bir şey göstermesin) ve sayım
  // İSTEMCİDE yapılıyor — seyahat başına ayrı sorgu yok, tek çağrı.
  const [ilanSayaci, setIlanSayaci] = useState(null);   // null = henüz sayılmadı
  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("discover_availabilities", {
        p_airport: null, p_sector: null, p_flight: null, p_date: null });
      if (iptal) return;
      // Hata YUTULMUYOR: sayaç `null` kalır ve kart "sayılıyor…" yerine
      // hiçbir sayı göstermez. Yanlış sayı, sayı olmamasından kötüdür.
      if (error) { setIlanSayaci(null); return; }
      // 🔴 29 EYLÜL (Gökberk md.6) — "4 uyumlu ilan"a basınca içeride sona ermiş
      // ilan çıkıyordu. Sunucu `active` + `tarih >= bugün` süzüyor; BUGÜN saati
      // geçmiş ilan geliyor. Başvurulamayan ilan uyumlu sayılmaz (Keşfet
      // kartının "sona erdi" kararıyla aynı: geriSayim).
      setIlanSayaci((data || []).filter(a => a.host_id !== uid && !a.fully_booked && a.active !== false
        && Math.max(0, (a.slots || 0) - (a.filled || 0)) > 0
        && (geriSayim(a.avail_date, a.time_from, a.time_to, t) || {}).tur !== "bitti"));
    })();
    return () => { iptal = true; };
  }, [uid]);
  // Bir seyahate "uyumlu" ilan: AYNI havalimanı + AYNI gün. Saat çakışması
  // sunucudaki `has_trip` mantığının işi; burada kartın vaadi dar tutuluyor
  // ki tıklayınca açılan listeyle aynı sayı çıksın.
  const uyumluSayi = (r) => ilanSayaci === null ? null
    : ilanSayaci.filter(a => a.airport_code === r.airport_code
        && String(a.avail_date).slice(0, 10) === String(r.visit_date).slice(0, 10)).length;

  // 4 Eylül — gönderilen istekler listesi bu ekrandan KALKTI (tasarım 14'te
  // yok); tam listesi Ana Sayfa → Akışım → İstek (İstekler ekranı).
  // v1.71 (Gokberk): seyahat kartındaki 3'lü mini-istatistik KALDIRILDI.
  // Kutulara dokunulunca hiçbir yere gitmiyordu ve üstteki "Misafir olarak
  // host bul" kartıyla FARKLI sayı gösteriyordu (kart: tüm havalimanlarının
  // toplamı, kutu: yalnız o seyahatin havalimanı) — iki ayrı doğruluk
  // kaynağı. Tek kaynak olarak üstteki kart bırakıldı; seyahat başına 3 RPC
  // çağrısı da ortadan kalktı.

  // 🔴 v2.65 — SIRA ÖNEMLİ: hata boş/yükleniyor durumundan ÖNCE gelir.
  // Yoksa ağ koptuğunda kullanıcı sonsuza kadar yükleyici veya "hiç yok"
  // görür ve neyin bozuk olduğunu asla öğrenemez.
  if (loadErr) return <LoadFail t={t} onRetry={load} />;
  if (rows === null) return <Load icerik />;  // 29 Eylul md.8: bandin altinda, ikinci sayfa cizme

  return (
    <Kaydirma {...(bnt ? bnt.scrollProps : null)} contentContainerStyle={{ padding: ARA[20], paddingTop: (bnt ? bnt.ustBosluk : 0) + SP[4], paddingBottom: ARA[40] }}>
      {/* ============================================================
          KAHRAMAN ALAN (v2.31)

          🔴 v2.30'DA HATA YAPTIM: lacivert zemin + altin buton kurdum.
          Gokberk "bizim ana temamizda bu yok" dedi ve haklıydı — o renk
          app'te BASKA HICBIR YERDE gecmiyordu. Tek ekran icin palete
          yeni zemin rengi sokmak, temayi o ekranda catallar; kullanici
          "baska bir uygulamaya girdim" hissi yasar.

          Rakipten alinan sey DUZEN olmali, PALET degil. Duzen: tam
          genislik alan + tek birincil eylem + duruma gore degisen
          baslik. Palet: bizim krem/altin/murekkep.
          ============================================================ */}
      {/* ══════════════════════════════════════════════════════════════
          🔴 3 EYLÜL — TASARIM 14: bandın altında çip satırı
          [Seyahatlerim (seçili)] [İlanlarım (yalnız host)], sonra seyahat
          kartları, en altta altın "Seyahat ekle" ve tek satır not. Altın
          zeminli "kahraman" blok (selam + cümle + CTA) tasarımda yok;
          onun CTA'sı en alttaki altın düğme, cümlesi liste boşken metin. */}
      {!adding && (
        <>
          {rows.length === 0 ? (
            <BosDurum ikon="ucus" metin={t.tripsEmpty} />
          ) : rows.map(r => (
            /* tasarım 14 kartı 146 yüksek: başlık 18 · tarih 42 · ayraç 72 ·
               uyum 88 · "seni içeri alacak" 114 (üstten). */
            /* ══ v6.3 · PANO H2 (Gökberk onayı) — SEYAHAT KARTI BİR BİNİŞ KARTI ══
               gün · amaç | uçuş · IST ‒‒‒› varış (iri mono) · delikli kesim ·
               SALON / KALKIŞ / KİŞİ (yalnız veri varsa) · uyumlu ilan · düzenle · Host bul.
               Davranış değişmedi: sayaç `uyumluSayi`, düzenle `onEditTrip`, git `onDiscover`. */
            (() => {
              const n = uyumluSayi(r);
              const varMi = n != null && n > 0;
              const git = () => onDiscover && onDiscover({
                airport: r.airport_code, date: r.visit_date,
                sortTrip: { airport: r.airport_code, date: r.visit_date },
              });
              const bugun = String(r.visit_date || "").slice(0, 10) === yerelGun();
              const amac = r.purpose ? gorunur((PURPOSES.find(x => x[0] === r.purpose) || [])[1] || "") : "";
              const kas = [bugun ? t.calmEyebrow : fmtLongDate(r.visit_date, lang), amac].filter(Boolean).join(" · ");
              let kalkis = null;
              if (r.scheduled_departure) {
                const d = new Date(r.scheduled_departure);
                if (!isNaN(d.getTime())) kalkis = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
              }
              const cocuk = (r.child_ages || []).filter(y => y != null).length;
              const kisi = Number(r.party_size) > 1 ? (cocuk ? `${Number(r.party_size) - cocuk} + ${cocuk}` : String(r.party_size)) : null;
              const hucreler = [
                [t.bkCellLounge, `${String(r.time_from).slice(0, 5)}–${String(r.time_to).slice(0, 5)}`],
                kalkis ? [t.bkCellDep, kalkis] : null,
                kisi ? [t.bkCellParty, kisi] : null,
              ].filter(Boolean);
              const varis = r.destination ? String(r.destination).trim() : "";
              return (
              <View key={r.id} style={[S.card, { padding: 0, borderRadius: R.xl + 2 }]}>
                <View style={{ paddingHorizontal: ARA[18], paddingTop: SP[4], paddingBottom: ARA[12] }}>
                  <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                    <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, color: C.goldText, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(kas)}</Text>
                    {!!r.flight_number && <Text style={{ color: C.mut, fontFamily: MONO[500], fontSize: FS.xs, letterSpacing: 0.6, marginLeft: SP[2] }}>{BUYUK(r.flight_number)}</Text>}
                  </View>
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => onEditTrip && onEditTrip(r)}
                    accessibilityRole="button" accessibilityLabel={t.editTrip}
                    style={{ flexDirection: "row", alignItems: "center", marginTop: ARA[8] }}>
                    <Text style={{ color: C.ink, fontFamily: MONO[500], fontSize: FS.display + 4, letterSpacing: 0.6 }}>{r.airport_code}</Text>
                    {!!varis && (<>
                      <View style={{ flex: 1, flexDirection: "row", alignItems: "center", marginHorizontal: ARA[12], overflow: "hidden" }}>
                        {Array.from({ length: 14 }).map((_, k) => (
                          <View key={k} style={{ width: 3, height: 1, backgroundColor: C.goldText, marginRight: ARA[4], opacity: 0.7 }} />
                        ))}
                      </View>
                      <Text style={{ color: C.mut, fontFamily: MONO[500], fontSize: FS.display + 4, letterSpacing: 0.6 }}>{varis}</Text>
                    </>)}
                  </TouchableOpacity>
                </View>
                <View style={{ flexDirection: "row", marginHorizontal: SP[4], overflow: "hidden" }}>
                  {Array.from({ length: 44 }).map((_, k) => (
                    <View key={k} style={{ width: 4, height: 1, marginRight: ARA[4], backgroundColor: C.kenarIsik || C.line }} />
                  ))}
                </View>
                <View style={{ paddingHorizontal: ARA[18], paddingTop: ARA[12], paddingBottom: SP[4] }}>
                  <View style={{ flexDirection: "row" }}>
                    {hucreler.map(([et, d]) => (
                      <View key={et} style={{ marginRight: ARA[20] }}>
                        <Text style={{ color: C.mut, fontSize: FS.micro, letterSpacing: 1.2 }}>{BUYUK(et)}</Text>
                        <Text style={{ color: C.ink, fontFamily: MONO[500], fontSize: FS.sm, marginTop: ARA[2] }}>{d}</Text>
                      </View>
                    ))}
                  </View>
                  <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: ARA[14] }}>
                    <TouchableOpacity disabled={n === 0} onPress={git} hitSlop={TAP.slop} style={{ flex: 1, minWidth: 0, minHeight: TAP.minHeight, justifyContent: "center" }}
                      accessibilityRole="button" accessibilityLabel={varMi ? t.tripMatchCta : t.tripMatchNone}>
                      <Text numberOfLines={1} style={{ color: varMi ? C.goldText : C.mut, fontSize: FS.sm, fontWeight: "600" }}>
                        {n == null ? t.tripMatchCounting
                          : n > 0 ? String(t.tripMatchCta).replace("{n}", String(n))
                          : t.tripMatchNone}
                      </Text>
                    </TouchableOpacity>
                    <Btn v="ghost" daire a11yLabel={t.editTrip} onPress={() => onEditTrip && onEditTrip(r)}
                      sol={<Ikon ad="duzenle" boy={15} renk={C.ink} />} style={{ marginRight: SP[2] }} />
                    <Btn v="gold" cip label={t.bkFindHost} a11yLabel={t.findHost} onPress={git} />
                  </View>
                </View>
              </View>
              );
            })()
          ))}
          {/* Tasarım 14: altta altın "Seyahat ekle" + tek satır not */}
          {/* ══════════════════════════════════════════════════════════
              🔴 18 EYLÜL (Gökberk md.12) — "'seyahati kaydet' yerine
              'seyahat ekle' olmalı."
              Haklıydı ve iki yerde birden yanlıştı. Bu düğme YENİ bir
              seyahat açıyor (`onAddTrip`) ama etiketi `avSaveTrip`
              ("Seyahati Kaydet →") idi. Ekran okuyucu etiketi ise zaten
              `heroCtaAddTrip` ("Seyahat ekle") diyordu — yani gören
              kullanıcı ile duyan kullanıcı AYNI düğmede FARKLI iki şey
              okuyordu. `addTrip` anahtarı ("Seyahat Ekle") zaten vardı.
              🆕 SINIF: "GÖRSEL ETİKET İLE ERİŞİLEBİLİRLİK ETİKETİ
              AYRIŞMIŞSA, BİRİ MUTLAKA YANLIŞTIR — VE HANGİSİNİN YANLIŞ
              OLDUĞUNU DÜĞMENİN NE YAPTIĞI SÖYLER."
              ══════════════════════════════════════════════════════════ */}
          <Btn v="gold" label={t.addTrip} a11yLabel={t.addTrip}
            onPress={() => (onAddTrip ? onAddTrip() : setAdding(true))} style={{ marginTop: ARA[8] }} />
          {rows.length > 0 ? (
            <Text style={{ color: C.mut, fontSize: FS.xs, textAlign: "center", marginTop: ARA[10], lineHeight: 16 }}>
              {t.tripsEmpty}
            </Text>
          ) : null}
          {/* 4 Eylül — ONAYLANAN TASARIM 14 BİREBİR: notun altında başka bir
              şey yok. Salon rehberi kartı, "Host bul" kartı, host daveti,
              gönderilen istekler ve kesikli "+ seyahat ekle" bu ekrandan
              kalktı. Kapıları: rehber → Ana Sayfa (seyahat yokken) ve
              karşılama ekranı; host olma → "İlanlarım" çipi; istekler →
              Akışım → İstek; seyahat ekleme → üstteki altın düğme. */}
        </>
      )}
      {/* 🔴 v3.4 — HATA SATIRI `{adding && …}` BLOĞUNUN İÇİNDEYDİ.
          Yani seyahat SİLME ve AMAÇ değiştirme hataları (`setErr`, :571
          ve :322) hiçbir zaman çizilmiyordu: o iki eylem `adding === false`
          iken oluyor. `seyahat_sil` gerçekten reddedilebilir (bağlı
          başvuru varsa) — kullanıcı siliyor, satır duruyor, ekranda tek
          kelime yok.
          🆕 SINIF: "BİR HATA SATIRINI KOŞULLU BİR BLOĞUN İÇİNE KOYARSAN,
          O KOŞUL DIŞINDAKİ HER HATA SESSİZ OLUR — HATA MESAJI, HATAYI
          ÜRETEN HER DURUMDA GÖRÜNÜR OLMALIDIR." */}
      {!!err && !adding && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
      {adding && (
        <>
          <Picker label={t.airport} value={ap} options={airports} onPick={setAp} t={t} />
          <Picker label={t.destination} value={dest} options={airports} onPick={setDest} t={t} />
          <DateInput label={t.date} value={date} onChange={setDate} />
          <View style={{ flexDirection: "row", gap: ARA[10], marginBottom: SP[3] }}>
            <TimeInput label={t.timeFrom} value={from} onChange={setFrom} />
            <TimeInput label={t.timeTo} value={to} onChange={setTo} />
          </View>
          {/* 🔴 v2.68 — BU BLOK TEK BİLEŞENE TAŞINDI: src/FlightField.js
              Sebep ölçüldü: buradaki eski kod flight_info()'nun DÖNDÜRMEDİĞİ
              beş alanı (airline / dep_iata / arr_iata / dep_time /
              airline_iata) okuyordu. Kutu açılıyor, satırların yarısı boş
              kalıyordu; çökme olmadığı için görünmemişti. SQL 195 alanları
              ekledi, FlightField onları okuyor ve aynı davranış artık
              seyahat ekleme / ilan açma / seyahat modalı ekranlarının
              ÜÇÜNDE de aynı. Uçuş numarası hepsinde İSTEĞE BAĞLI. */}
          {/* 🔴 v2.79 — `onCarrier` KALDIRILDI, yani FlightField artık çip
              satırını ÇİZMİYOR. Aynı ekranda hemen altta zaten tam bir
              havayolu listesi vardı: kullanıcı aynı soruyu iki kez
              görüyordu ve hangisinin geçerli olduğunu bilmiyordu. */}
          <FlightField t={t} value={flight} onChange={setFlight} date={date}
            carrier={carrier} showChips={false} labelStyle={S.label} inputStyle={S.input} />

          {/* 🔴 v2.23 — HAVAYOLU + CHARTER, MISAFIR TARAFINDA DA.
              Kural iki tarafi birden ilgilendiriyor: "misafir ayni
              havayolunda mi", "misafirin seferi charter mi". Tek tarafi
              bilmek kurali yarim uygular — yarim uygulanan kural kapida
              cozulur.
              v2.79: elle yazılmış droplist yerine ortak CarrierPicker —
              arama var, sık kullanılanlar başta, seçim geri alınabiliyor. */}
          <CarrierPicker t={t} carriers={carriers} value={carrier}
            onSelect={setCarrier} label={t.carrierQ} hint={t.carrierWhy} />

          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setVCharter(v => !v)}
            style={{ flexDirection: "row", alignItems: "center", marginTop: SP[3] }}>
            <View style={{ width: 19, height: 19, borderRadius: R.onay, borderWidth: 1.5,
                           borderColor: vCharter ? C.amber : C.line, marginRight: SP[2],
                           alignItems: "center", justifyContent: "center",
                           backgroundColor: vCharter ? C.amber : "transparent" }}>
              {vCharter && <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} />}
            </View>
            <Text style={{ fontSize: FS.sm, color: C.body, flex: 1 }}>{t.charterQ}</Text>
          </TouchableOpacity>
          {vCharter && (
            <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginTop: SP[2] }}>
              <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.charterGuestWarn}</Text>
            </View>
          )}

          {/* 🔴 v2.79 — SEYAHAT AMACI, AddVisit ekranıyla AYNI ÇİPLER.
              Hiçbiri ÖN SEÇİLİ DEĞİL ve bu bilinçli: ön seçili bir çip,
              kullanıcının hiç vermediği bir beyanı veri gibi kaydeder.
              Sağlayıcı ekranı (Ö9) "beyan eden: %N" cümlesini tam da bu
              alanın İSTEĞE BAĞLI olduğu için basıyor; ön seçim o oranı
              anlamsız kılardı. Seçili çipe tekrar dokunmak seçimi kaldırır. */}
          <Text style={[S.label, { marginTop: ARA[14] }]}>{t.intentLabel}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[6] }}>
            {PURPOSES.map(([k, lb, ic]) => {
              const on = purpose === k;
              return (
                <Secim key={k} ton="teal" secili={on} etiket={gorunur(lb)}
                  onPress={() => setPurpose(on ? "" : k)}
                  ikon={<Ikon ad={ic} boy={14} renk={C.mutedAA} />} />
              );
            })}
          </View>
          <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 16, marginBottom: SP[1] }}>
            {t.purposeOptional}
          </Text>
          <KisiSayisi t={t} kisi={kisi} cocuk={cocuk} onKisi={setKisi} onCocuk={setCocuk}
            stil={{ marginTop: ARA[10] }} />

          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
          <Btn label={t.saveTrip} onPress={save} disabled={busy} busy={busy} />
          <TouchableOpacity hitSlop={TAP.slop} style={{ alignItems: "center", marginTop: SP[3] }} onPress={() => setAdding(false)}>
            <Text style={{ color: C.mut }}>{t.cancel}</Text>
          </TouchableOpacity>
        </>
      )}
    </Kaydirma>
  );
}

// 🔴 v2.65 · PROP-DROP DÜZELTMESİ
// İmzada `onAddAvail` YOKTU; App.js onu geçiyordu ve JS sessizce yutuyordu.
// Sonuç: "Müsaitlik ekle" düğmesi her zaman satır-içi eski formu açıyordu,
// oysa aynı iş için ayrı bir HostAvailability ekranı var.
//
// `onBroadcast` / `onAccess` imzada VARDI ama gövdede HİÇ okunmuyordu.
// KARAR: App.js'ten kaldırıldı, imzadan da çıkarıldı — yeni düğme
// EKLENMEDİ. Gerekçe: her iki eylem de Profil ekranında zaten canlı bir
// satıra bağlı (App.js Profile: onBroadcast + onAccess). Aynı eylemi
// ikinci bir yere koymak keşfedilebilirliği artırmaz, "hangisi doğru
// giriş?" sorusunu doğurur. Ölü prop ise bir sonraki geliştiriciye
// "burada bir şey var" diye yalan söyler — iki yalandan sessiz olanı
// daha pahalı.
// ════════════════════════════════════════════════════════════════════════
// İLAN DURUMU — TEK KAYNAK
//
// Üç durum var ve üçü FARKLI şeyler söyler:
//   canli  → yayında, başvuru alabilir
//   pasif  → host kapattı, tarihi HENÜZ GEÇMEDİ (geri açılabilir)
//   gecmis → tarihi geçti, artık geri açılamaz
//
// 🔴 `pasif` ile `gecmis` AYNI ROZETLE gösterilemez: birincisi bir KARAR,
// ikincisi bir OLGU. Host "neden yayında değil?" diye sorduğunda cevap
// "sen kapattın" ile "günü geçti" arasında ayrılmalı.
// 🆕 SINIF: "İKİ FARKLI SEBEPLE AYNI SONUCA VARAN DURUMLAR TEK ETİKETLE
// GÖSTERİLİRSE, KULLANICI DÜZELTEBİLECEĞİ ŞEYLE DÜZELTEMEYECEĞİNİ AYIRT
// EDEMEZ."
export function ilanDurumu(r) {
  const bugun = yerelGun();
  const gun = String(r?.avail_date || "").slice(0, 10);
  // 🔴 29 EYLÜL — BUGÜN ama BİTİŞ SAATİ GEÇMİŞ ilan "canlı" sayılıyordu (Keşfet
  // kartı onu "sona erdi" diye gösterirken host'un kendi listesinde canlıydı;
  // Gökberk md.2/md.6 ile aynı kök). Bitiş saati geçtiyse o da geçmiş.
  const simdi = new Date();
  const saat = `${String(simdi.getHours()).padStart(2, "0")}:${String(simdi.getMinutes()).padStart(2, "0")}`;
  const gecti = gun < bugun || (gun === bugun && r?.time_to && String(r.time_to).slice(0, 5) <= saat);
  if (gecti) return "gecmis";
  return r?.active ? "canli" : "pasif";
}

// Sıralama: CANLI en üstte (yakın tarih önce), sonra PASİF (yakın tarih
// önce), en altta GEÇMİŞ (EN YENİ önce — çünkü geçmişte en son olan en
// ilgili olandır; en eski ilanı en üstte görmek işe yaramaz).
export function ilanlariSirala(liste) {
  const agirlik = { canli: 0, pasif: 1, gecmis: 2 };
  return [...(liste || [])].sort((a, b) => {
    const da = ilanDurumu(a), db = ilanDurumu(b);
    if (agirlik[da] !== agirlik[db]) return agirlik[da] - agirlik[db];
    const ta = String(a.avail_date || ""), tb = String(b.avail_date || "");
    // Geçmişte sıra TERS: en yeni üstte.
    return da === "gecmis" ? tb.localeCompare(ta) : ta.localeCompare(tb);
  });
}

export function Hosting({ t, session, lang, onOpenChat, onAddAvail, onAddCard, onEditAvail, focusAvailId, onFocusDone, bnt }) {
  const uid = session?.user?.id;
  // Eşleşme anındaki sol avatarın baş harfi. Kayıt sırasında ad
  // `signUp(..., { data: { name } })` ile yazılıyor, yani oturumun
  // kendisinde duruyor — bunun için ayrı bir sorgu atmak, tek bir harf
  // uğruna bir ağ gidiş-dönüşü harcamak olurdu. Ad yoksa e-postanın ilk
  // harfi, o da yoksa `AnAvatar` "?" çiziyor.
  const hostAdi = session?.user?.user_metadata?.name || session?.user?.email || "";
  const [rows, setRows] = useState(null);
  const [loadErr, setLoadErr] = useState(false);   // v2.65 — bkz. Trips
  const [adding, setAdding] = useState(false);
  const [bolumAcik, setBolumAcik] = useState({});   // v6.3 · H3 katlı bölümler (yayında ilan yoksa açık başlar)
  const bolumAcikMi = (d) => (bolumAcik[d] !== undefined ? bolumAcik[d] : !(rows || []).some(x => ilanDurumu(x) === "canli"));
  const [silAdayi, setSilAdayi] = useState(null);  // v2.78: ilan silme onayi
  const [acBusy, setAcBusy] = useState(null);      // md.11: yeniden yayinlama kilidi
  const [bilgi, setBilgi] = useState("");          // 13 Eyl md.2: sonuç bildirimi
  const [airports, setAirports] = useState([]);
  const [lounges, setLounges] = useState([]);
  const [ap, setAp] = useState(null);
  const [lg, setLg] = useState(null);
  const [date, setDate] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [flight, setFlight] = useState("");
  const [slots, setSlots] = useState(1);
  const [srcs, setSrcs] = useState([]);
  // 🔴 v2.69 — KABİN SINIFI. SQL 191 `availabilities.cabin_class`
  // kolonunu ekleyip karar zincirine bağlamıştı; 193 `set_availability_cabin`
  // yazma yolunu açmıştı. AMA EKRANDA SEÇİM YOKTU — hiçbir ilanda kabin
  // dolmadı ve "Business bileti misafir hakkı vermez" resmî kuralı ürüne
  // hiç yansımadı. Üç turdur "kablolandı" dediğim özellik, son 20 satır
  // eksik olduğu için ölüydü. Motor + yazma yolu + EKRAN — üçü olmadan
  // özellik yoktur.
  const [cabin, setCabin] = useState(null);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  // 🔴 v2.65 — useState(0) BAŞLANGIÇTA "0 kişi bekliyor" DEMEKTİ; oysa
  // henüz sayım yapılmamıştı. Render'daki `waiting === null` dalı
  // (demandPickFirst) bu yüzden ULAŞILAMAZ ölü koddu. null = "henüz bilmiyoruz".
  const [waiting, setWaiting] = useState(null);   // #3: bu havalimanında bekleyen misafir sayısı
  // 🔴 v2.95 (Gökberk madde 7) — "İLANIMA GİT".
  // Ana sayfadaki "Canlı ilanlarım" panelinde her satırda "+ İlan ekle"
  // düğmesi vardı. Üç ilanı olan host'a üç kez "yeni ilan aç" demek,
  // listenin kendisiyle çelişiyordu: host oraya bakarken YENİ ilan
  // aramıyor, VAR OLAN ilanının başvurularını arıyor.
  // Artık düğme o ilana götürüyor ve ilan ekranda İŞARETLENİYOR —
  // "seni buraya getirdim" demeden yönlendirme, kullanıcıyı listenin
  // ortasına bırakıp kaybetmektir.
  const [odakId, setOdakId] = useState(focusAvailId || null);
  const kaydirmaRef = useRef(null);
  const kartY = useRef({});
  // v2.87: havayolu kodu → ad sözlüğü (madde 5). İkincil veri: gelmezse
  // çip kodu gösterir, ekran çalışır.
  const [hostCarrierMap, setHostCarrierMap] = useState({});
  // v2.49 (Gökberk): ilan kartında BAŞVURULAR — sayı + tıklayınca liste.
  const [reqs, setReqs] = useState([]);              // host_requests dökümü
  const [openReqs, setOpenReqs] = useState({});      // {availId: true} açık kartlar
  // v2.53 — 3. AN: host bir isteği kabul ettiğinde. Ürünün en olumlu
  // geri bildirimi bir liste satırının rengi değil, tam ekran bir andır.
  const [moment, setMoment] = useState(null);
  // v3.4 — kabul/ret düğmelerinin bekleme kilidi ve ret onayı
  const [reqBusy, setReqBusy] = useState(null);
  const [redKart, setRedKart] = useState(null);
  // v2.72 — KARŞILIK ANI: host ağırlamasının karşılığını aldığında
  // bir kez, tam ekran. Ürünün host tarafındaki tek duygusal ödülü.
  const [karsilik, karsilikKapat] = useReciprocityMoment(uid);

  // 🔴 18 EYLÜL (md.11) — SQL 295'in açtığı geri dönüş yolu.
  // `cancel_availability` tek yönlüydü: host kapattığı ilanı bir daha
  // açamıyordu, tek çıkış yeni ilan açmaktı — yani başvuru geçmişi ve
  // kural anlık görüntüsü çöpe gidiyordu. Sunucu artık `create`in
  // kapılarını (kapasite, geçmiş tarih, kendi çakışman) yeniden soruyor;
  // reddederse SEBEBİ ekranda yazıyor, sessizce yutulmuyor.
  async function yenidenYayinla(id) {
    if (!id || acBusy) return;
    setAcBusy(id); setErr(""); setBilgi("");
    const { error } = await supabase.rpc("ilani_yeniden_yayinla", { p_id: id });
    setAcBusy(null);
    if (error) { setErr(mapErr(t, error.message)); return; }
    setBilgi(t.availRepublishDone);
    load();
  }

  const load = useCallback(async () => {
    // ══════════════════════════════════════════════════════════════════
    // 🔴 v3.9.2 — İLANLARIM SAYFASI SAHİBİNDEN BİLGİ SAKLIYORDU.
    //
    // 29 Ağustos, Gökberk: "İlanı açan kişi ilanlarını İlanlarım sayfasında
    // aktif/pasif durumu ile görebilir (aktif ilanlar üstte sıralanmalı,
    // ilan pasife geçince aşağıya inmeli)."
    //
    // Eski sorgu: `.eq("active", true)`. Yani bir ilan pasife alındığı ya da
    // tarihi geçtiği anda EKRANDAN TAMAMEN SİLİNİYORDU. Host "ben o ilanı
    // açmış mıydım, ne olmuştu?" sorusunun cevabını hiçbir yerde bulamıyordu.
    //
    // Bir kaydı gizlemek onu silmekle aynı şey değildir — ama SAHİBİNDEN
    // gizlemek, ikisi arasındaki farkı ortadan kaldırır.
    //
    // 🆕 SINIF: "BİR KAYDI LİSTEDEN ÇIKARMAK, KULLANICI İÇİN O KAYDIN HİÇ
    // VAR OLMAMASIYLA AYNI ŞEYDİR — DURUMU DEĞİŞEN ŞEY KAYBOLMAMALI,
    // SIRASI DEĞİŞMELİDİR."
    //
    // Artık hepsi geliyor; ayrım SIRALAMA ve DURUM ROZETİYLE yapılıyor.
    // ══════════════════════════════════════════════════════════════════
    const { data, error } = await supabase.from("availabilities")
      .select("*").eq("host_id", uid).order("avail_date");
    if (error) { setLoadErr(true); return; }
    setLoadErr(false);
    setRows(ilanlariSirala(data || []));
    // v2.49: başvurular ilanla birlikte gelir (host_requests avail_id döndürür)
    try {
      const { data: rq, error: hata3 } = await supabase.rpc("host_requests");
      if (hata3) logError("screens.js:733", hata3);
      setReqs(rq || []);
    } catch (e) { setReqs([]); }
  }, [uid]);

  useEffect(() => {
    load();
    havalimanlariniGetir()
      .then((data) => setAirports((data || []).map(a => ({ key: a.code, label: `${a.code} — ${a.city}` }))));
    carrierlariGetir().then((data) => {
      const cm = {};
      (data || []).forEach(c => { if (c && c.code) cm[c.code] = c.name || c.code; });
      setHostCarrierMap(cm);
    });
  }, [load]);

  const prevApKey = useRef(null);
  // 🔴 v2.95 (madde 7) — ODAKLANMA. Hook'lar erken `return`DAN ÖNCE:
  // `if (rows === null) return <Load/>` satırının altına yazsaydım kanca
  // koşullu hâle gelirdi ve BEYAZ EKRAN riski doğardı (v2.94'te app'in
  // kendi nöbetçisi beni tam da bunda yakalamıştı).
  useEffect(() => { setOdakId(focusAvailId || null); }, [focusAvailId]);
  useEffect(() => {
    if (!odakId || !rows || !rows.length) return;
    const y = kartY.current[odakId];
    if (y == null) return;                     // kart henüz ölçülmedi
    const z = setTimeout(() => {
      if (kaydirmaRef.current && kaydirmaRef.current.scrollTo) {
        kaydirmaRef.current.scrollTo({ y: Math.max(0, y - 12), animated: true });
      }
    }, 120);
    // Vurgu 4 saniye sonra söner: kalıcı bir vurgu, vurgu olmaktan çıkar.
    const z2 = setTimeout(() => { setOdakId(null); if (onFocusDone) onFocusDone(); }, 4000);
    return () => { clearTimeout(z); clearTimeout(z2); };
  }, [odakId, rows, onFocusDone]);

  useEffect(() => {
    if (!ap) { setLounges([]); setWaiting(0); setLg(null); prevApKey.current = null; return; }
    // 🔴 Lounge seçimi YALNIZCA havalimanı GERÇEKTEN değiştiğinde sıfırlanır.
    // Eski hâlinde effect [ap, date] ile tetikleniyor ve her seferinde
    // setLg(null) çalışıyordu → tarih/saat alanına dokunur dokunmaz seçili
    // lounge siliniyordu (Canlı APP 6).
    if (prevApKey.current !== ap.key) {
      setLg(null);
      // 🔴 SALON LİSTESİ BOŞ GELİYORDU (Gökberk madde 11). Doğrudan tablo
      // sorgusu üç sebeple sessizce boş dönebiliyor: RLS/grant eksikliği,
      // havalimanı kodunda büyük/küçük harf farkı, katalog satırının
      // venue'ya bağlı olmaması. RPC üçünü de kapatır ve katalog boşsa
      // venue tablosundan yedekler — kullanıcı asla boş liste görmez.
      supabase.rpc("lounges_for_airport", { p_airport: ap.key })
        .then(({ data, error }) => {
          if (error) { setLounges([]); return; }
          // 🔴 190 — RPC ALANLARI KORUNUR. Eski eslesme yalniz key/label
          // biraktigi icin LoungePicker'in okudugu id/name/scope/section/
          // display_name kayboluyordu: sekmeler "other"a dusuyor, secim
          // (onSelect(l.id)) undefined donuyordu. Satiri OLDUGU GIBI tasi,
          // eski key/label alanlarini uzerine ekle.
          setLounges((data || []).map(l => ({
            ...l,
            // 🔴 v2.70 — `l.venue_scope` HAYALETTİ: lounges_for_airport
            // `scope` döndürüyor. `venue_scope` veritabanında GERÇEK bir
            // kolon (lounge_guest_rules) olduğu için genel hayalet
            // taraması susuyordu; değişken düzeyinde izleme yakaladı.
            // Sonuç: terminali olmayan salonlarda alt satır boş kalıyordu.
            key: l.id, label: l.display_name || l.name, sub: l.terminal || l.scope || null,
            guests: l.accepts_guests,
          })));
        });
      prevApKey.current = ap.key;
    }
    // bu havalimanında (ve seçiliyse tarihte) kaç guest bekliyor
    // 🔴 v2.02 — TALEP SAYISI ARTIK ARALIĞA BAĞLI.
    // Eskiden havalimanı seçilir seçilmez "şu kadar yolcu bekliyor"
    // diyorduk. Ama o yolcuların saati host'unkiyle örtüşmüyorsa sayı
    // yanlış vaat oluyordu. Tarih girilmeden hiç sormuyoruz.
    (dateOk(date) ? supabase.rpc("waiting_demand", { p_airport: ap.key, p_date: date })
                  : Promise.resolve({ data: null }))
      .then(({ data }) => setWaiting(data || 0));
  }, [ap, date]);

  async function publish() {
    setErr("");
    if (!ap) return setErr(t.errAirport);
    if (!dateOk(date)) return setErr(t.errDate);
    if (!timeOk(from) || !timeOk(to) || from >= to) return setErr(t.errTime);
    if (srcs.length === 0) return setErr(t.errSlots);
    setBusy(true);
    // 🔴 KOK NEDEN (Canlı APP 5): form "ERİŞİM KAYNAĞI" seçimini yalnızca
    // yerel state'te (srcs) tutuyor, profile HİÇ yazmıyordu. Oysa
    // create_availability profiles.guest_capacity dolu değilse
    // 'no_access_source' fırlatıyor → kullanıcı "Bir şeyler ters gitti"
    // görüyordu ve ilan hiç açılamıyordu. Önce profili güncelle.
    // 🔴 v2.89 — DOĞRUDAN TABLO YAZIMI KALDIRILDI (SQL 232).
    // `guest_capacity` ve `access_source`, `create_availability`nin TEK
    // gerçek ön koşulu (055: `no_access_source`). O kolonlar istemciden
    // doğrudan yazılabildiği sürece ön koşul bir kapı değil, formaliteydi:
    // hiç kart beyan etmemiş bir misafir tek satırla ilan açabiliyordu.
    // 232 kolon düzeyinde grant'ı kapattı; tek yol `save_host_access`,
    // ve o fonksiyon kotayı/statüyü/kart ürününü BİRLİKTE tutarlı yazıyor.
    const { error: profErr } = await supabase.rpc("save_host_access", {
      p_sources: srcs,
      p_guest_capacity: slots,
    });
    if (profErr) { setBusy(false); return setErr(mapErr(t, profErr.message)); }
    // 🔴 KOK NEDEN DUZELTMESI: dogrudan insert RLS/korumalari atliyordu ve
    // reddediliyordu — ilan HIC olusmuyordu. Tek dogru yol: create_availability RPC
    // (cakisma kontrolu, telefon kapisi, gorunurluk esigi hep orada).
    const loungeId = lg ? lg.key : null;
    const airportCode = ap.key;
    const flightNo = flight.trim() ? flight.trim() : null;
    // 🔴 v2.69 — DÖNEN `id` ARTIK OKUNUYOR. create_availability
    // 'ok/id/visibility/min_trust' döndürüyor ve biz yalnız error'a
    // bakıyorduk; id çöpe gidiyordu. Kabini yazmak için o id gerekiyor.
    const { data: created, error } = await supabase.rpc("create_availability", {
      p_lounge_id: loungeId, p_airport: airportCode, p_date: date,
      p_from: from, p_to: to, p_slots: slots,
      p_flight: flightNo, p_visibility: "all",
    });
    // 🔴 v2.89 — BU SATIR GEREKSİZDİ VE TEHLİKELİYDİ.
    // `create_availability` zaten sunucuda `update users set role='host'`
    // yapıyor (055:60). Buradaki istemci yazımı aynı işi ikinci kez
    // yapıyordu — ama `users.role`u istemciye AÇIK tutmayı zorunlu
    // kılıyordu. O grant yüzünden herhangi bir misafir tek satırla host
    // olabiliyordu ve app'teki `role === "host"` kapılarının HEPSİ
    // istemcinin kendi yazdığı değere bakıyordu (SQL 232).
    // 🆕 SINIF: "KENDİ YAZDIĞI DEĞERE BAKAN KAPI, KAPI DEĞİLDİR." 
    setBusy(false);
    if (error) return setErr(mapErr(t, error.message));
    // Kabin seçildiyse ilana yaz. Düşerse ilan YİNE AÇILIR — kabin bir
    // zenginleştirmedir, kapı değil. (Hata yutulmuyor: konsola düşer.)
    if (cabin && created && created.id) {
      try { await supabase.rpc("set_availability_cabin", { p_avail_id: created.id, p_cabin: cabin }); }
      catch (e) { /* ilan açıldı; kabin bir sonraki düzenlemede yazılabilir */ }
    }
    setAdding(false); setAp(null); setLg(null); setDate(""); setFrom(""); setTo(""); setFlight(""); setSlots(1); setSrcs([]); setCabin(null);
    load();
  }

  // 🔴 v2.65 — SIRA ÖNEMLİ: hata boş/yükleniyor durumundan ÖNCE gelir.
  // Yoksa ağ koptuğunda kullanıcı sonsuza kadar yükleyici veya "hiç yok"
  // görür ve neyin bozuk olduğunu asla öğrenemez.
  if (loadErr) return <LoadFail t={t} onRetry={load} />;
  if (rows === null) return <Load icerik />;  // 29 Eylul md.8

  return (
    <>
    {/* v6.1 (md.5) — anlar TAM EKRAN katmanda: sekme içinde mutlak konumlu
        çizildiklerinde alt çubuk üstlerinde kalıyordu ("Eşleştiniz" ekranında
        sekmeler görünüyordu). Modal, kabuğun tamamını örter. */}
    {!!karsilik && (
      <Modal visible transparent={false} animationType="fade" statusBarTranslucent onRequestClose={karsilikKapat}>
      <View style={{ flex: 1 }}>
        <MomentScreen t={t}
          kind={karsilik.kind}
          title={karsilik.title}
          subtitle={karsilik.subtitle}
          meta={karsilik.meta}
          primary={{ label: t.momentReciprocityCta, onPress: karsilikKapat }}
          /* v2.87 — madde 1 ile aynı sınıf hata: bu an Yayın sekmesinde
             yaşanıyor, bir sohbetten gelmiyor. "Sohbete dön" var olmayan
             bir yeri işaret ediyordu. */
          secondary={{ label: t.close, onPress: karsilikKapat }}
        />
      </View>
      </Modal>
    )}
    {!!moment && (
      <Modal visible transparent={false} animationType="fade" statusBarTranslucent onRequestClose={() => setMoment(null)}>
      <View style={{ flex: 1 }}>
        <MomentScreen t={t}
          kind="matched"
          dugum={t.momentMatchEyebrow}
          /* Tasarımdaki iki avatar: solda host (bu ekranı gören kişi),
             sağda misafir — teal, yani "kapıdan geçecek olan". Sıra
             tesadüf değil: cümlenin öznesi solda duruyor. */
          ikiz={[hostAdi, moment.name]}
          title={t.momentMatchTitle.replace("{name}", shortName(moment.name))}
          subtitle={t.momentMatchBody.replace("{name}", shortName(moment.name))}
          primary={{ label: t.momentMatchCta, onPress: () => { const m = moment; setMoment(null);
                     onOpenChat && onOpenChat({ req: { id: m.id }, name: m.name }); } }}
          /* 🔴 v2.95 (Gökberk madde 13) — "hem sohbeti aç hem sohbete dön var".
             `t.momentClose` = "Sohbete dön". O metin Chat ekranındaki aynı
             bileşen için DOĞRU (oradan gelindi, oraya dönülür); burada YANLIŞ:
             bu an İlanlarım'da yaşanıyor, ortada dönülecek bir sohbet yok ve
             yan yana iki düğme aynı yeri işaret ediyormuş gibi okunuyor.
             Aynı sınıf v2.87'de karşılık anında düzeltilmiş, bu dala
             uygulanmamıştı. Tek bir sözlük anahtarını iki bağlamda kullanmak,
             bağlamlardan birinde her zaman yalan söyler. */
          secondary={{ label: t.momentLater, onPress: () => setMoment(null) }}
        >
          {/* v6.3 · PANO M1 (Gökberk onayı) — MİSAFİR KARTI fişi: kimle, nerede, ne zaman. */}
          {!!moment.q && (
            <View style={{ marginTop: ARA[22], alignSelf: "stretch", borderRadius: R.lg + 2, padding: SP[4],
                           backgroundColor: "rgba(20,18,17,0.55)", borderTopWidth: 1, borderTopColor: "rgba(247,243,236,0.10)" }}>
              <Text style={{ color: C.gold, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(t.momentGuestSlip)}</Text>
              <Text numberOfLines={1} style={{ color: C.paper, fontFamily: F.serifGosterim, fontSize: FS.title + 2, marginTop: ARA[6] }}>{moment.name}</Text>
              <Text style={{ color: C.paper, opacity: 0.72, fontFamily: MONO[500], fontSize: FS.xs + 0.5, letterSpacing: 0.4, marginTop: ARA[6] }}>
                {BUYUK([moment.q.lounge_name, moment.q.avail_date ? fmtLongDate(moment.q.avail_date, etkinDil()) : null,
                        moment.q.time_from && moment.q.time_to ? `${String(moment.q.time_from).slice(0, 5)}–${String(moment.q.time_to).slice(0, 5)}` : null]
                       .filter(Boolean).join(" · "))}
              </Text>
            </View>
          )}
        </MomentScreen>
      </View>
      </Modal>
    )}
    <Kaydirma {...(bnt ? bnt.scrollProps : null)} ref={kaydirmaRef} contentContainerStyle={{ padding: ARA[20], paddingTop: (bnt ? bnt.ustBosluk : 0) + SP[4], paddingBottom: ARA[40] }}>
      {!adding && (
        <>
          {/* 🔴 v2.72 — HOST PANELİ EN ÜSTTE, İLAN LİSTESİNDEN ÖNCE.
              Sıra bir tercih değil, bir tez: ilan listesi PAZAR YERİdir
              ve karşı taraf boşken hiçbir şey söylemez. Cüzdan ise
              karşı taraf hiç yokken de değerli — "3 hakkın 136 gün
              sonra yanıyor, ≈90 € ediyor" cümlesini dünyada başka
              kimse kuramıyor.

              Host'u ikna etmiyoruz; host OLDUĞUNU haber veriyoruz.
              Bu yüzden ekranın ilk ekran dolusu pazar değil, cüzdan. */}
          {/* 🔴 v2.78 — İKİ AYRI İLAN AÇMA YOLU VARDI.
              "İlan aç →" (HostMissed kartı) `setAdding(true)` ile ESKİ
              satır-içi formu açıyordu: kural kutusu YOK, "hangi kartımı
              kullanayım" YOK, yayın öncesi kural onayı YOK, taşıyıcı/charter
              sorusu YOK. "+ İlan ekle" ise HostAvailability'ye gidiyor ve
              hepsi var. Aynı ekranda iki düğme, iki farklı ürün — ve bu
              turun ana özelliği yolların BİRİNDE görünmüyordu.
              İkisi de aynı yere gidiyor artık. */}
          <HostPanel t={t} onAddCard={onAddCard} onAdd={() => (onAddAvail ? onAddAvail() : setAdding(true))} />
          {/* 🔴 v2.95 (Gökberk madde 16) — "Müsaitlik ekle butonu İlanlarım'ın
              en altında; çok ilan varken aşağı inmek gerekiyor."
              Ölçtüm: düğme listenin ALTINDAYDI, yani listenin uzunluğu
              düğmeye ulaşma maliyetini belirliyordu. Bu ters bir bağ:
              en aktif host (en çok ilanı olan) yeni ilan açmak için en çok
              kaydırmak zorunda kalıyordu.
              🆕 SINIF: "BİR EYLEMİN MALİYETİ, O EYLEMİ EN ÇOK YAPACAK
              KULLANICIDA ARTIYORSA, YERLEŞİM YANLIŞTIR."
              Düğme artık listenin BAŞINDA (birincil) — alttaki kopyası
              ikincil biçime indi ki iki birincil düğme olmasın. */}
          {rows.length > 0 && (
            <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: SP[1], marginTop: SP[1] }}>
              <Text style={{ fontSize: FS.xs, fontWeight: "700", color: C.mut, letterSpacing: 1.4 }}>
                {/* 29 Eylül (Gökberk md.1) — sayı yalnız AKTİF ilanlar; pasif/geçmiş kendi bölümünde */}
                {BUYUK(t.subTabListings)} · {String(t.availActiveN || "{n}").replace("{n}", String(rows.filter(x => ilanDurumu(x) === "canli").length))}
              </Text>
              {/* 5 Eylül — mockup 12c: küçük altın düğme (36pt, 12.5). `sm` 44pt'ti. */}
              <Btn v="gold" cip full={false} label={t.addAvail} onPress={() => (onAddAvail ? onAddAvail() : setAdding(true))} a11yLabel={t.addAvail} />
            </View>
          )}
          {/* Katlı bölüm: kullanıcı seçtiyse o; seçmediyse yayında ilan YOKKEN açık (boş ekran olmasın). */}
          {rows.length === 0 ? (
            <BosDurum ikon="salon" metin={t.hostEmpty} />
          ) : rows.map((r, i) => {
            const durum = ilanDurumu(r);
            const yayindaDegil = durum !== "canli";
            // Bölüm başlığı: durum DEĞİŞTİĞİ ilk kartın üstüne.
            // 🔴 Yalnız sıralamak yetmez — kullanıcı listenin neden
            // ikiye ayrıldığını GÖRMELİ. Sessiz bir sıralama, sıralamayı
            // fark etmeyen için rastgele bir düzendir.
            const oncekiDurum = i > 0 ? ilanDurumu(rows[i - 1]) : null;
            // 29 Eylül (md.1) — aktifler de kendi başlığını alır: üç bölüm, üç başlık.
            const basliktaAyir = durum !== oncekiDurum
              && (durum !== "canli" || rows.some(x => ilanDurumu(x) !== "canli"));
            return (
            <React.Fragment key={r.id}>
            {basliktaAyir && (durum === "canli" ? (
              <Text style={{ marginTop: SP[2], marginBottom: SP[2], marginHorizontal: ARA[4], fontSize: FS.micro + 0.5, fontWeight: "600",
                             color: C.mut, letterSpacing: 1.4 }}>{BUYUK(t.availActiveTitle)}</Text>
            ) : (
              /* v6.3 · PANO H3 — yayında olmayanlar / geçmiş KATLI satır (varsayılan kapalı). */
              <TouchableOpacity hitSlop={TAP.slop} onPress={() => setBolumAcik(o => ({ ...o, [durum]: !bolumAcikMi(durum) }))}
                accessibilityRole="button" accessibilityState={{ expanded: bolumAcikMi(durum) }}
                accessibilityLabel={durum === "pasif" ? t.availPassiveTitle : t.availPastTitle}
                style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", minHeight: TAP.minHeight,
                         marginTop: SP[2], paddingHorizontal: ARA[4], borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: C.kenarIsik || C.line }}>
                <Text style={{ fontSize: FS.micro + 0.5, fontWeight: "600", color: C.mut, letterSpacing: 1.4 }}>
                  {BUYUK(`${durum === "pasif" ? t.availPassiveTitle : t.availPastTitle} · ${rows.filter(x => ilanDurumu(x) === durum).length}`)}
                </Text>
                <Ikon ad={bolumAcikMi(durum) ? "yukari" : "asagi"} boy={14} renk={C.mut} />
              </TouchableOpacity>
            ))}
            {(durum === "canli" || bolumAcikMi(durum) || odakId === r.id) && (
            <View
              onLayout={(e) => { kartY.current[r.id] = e.nativeEvent.layout.y; }}
              style={[S.card, { borderRadius: R.xl + 2, padding: SP[4] + 2 },
                      yayindaDegil && { opacity: 0.62 },
                      odakId === r.id && { backgroundColor: C.altinIz03 || C.goldSoft }]}>
              {/* ══ v6.3 · PANO H3 (Gökberk onayı) — kartın üstü: durum satırı ·
                  serif salon · mono tarih/saat. Taşma dersi (v2.95) geçerli:
                  ad esner (flex:1 + numberOfLines), kod asla kısalmaz. */}
              {(() => {
                const acik = Math.max(0, (r.slots || 0) - (r.filled || 0));
                const durumYazi = durum === "canli"
                  ? (acik > 0 ? `${t.live} · ${acik} ${t.slotsOpen}` : `${t.live} · ${t.fullyBooked}`)
                  : [durum === "pasif" ? t.availPassive : t.availPastLine,
                     (r.filled || 0) > 0 ? String(t.availHostedN || "").replace("{n}", String(r.filled)) : null].filter(Boolean).join(" · ");
                return (
                  <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                    <Text numberOfLines={1} style={{ flex: 1, minWidth: 0, marginRight: ARA[10], fontSize: FS.micro + 0.5, fontWeight: "600",
                                                     letterSpacing: 1.3, color: durum === "canli" ? (acik > 0 ? C.ink : C.goldText) : C.mut }}>
                      {BUYUK(String(durumYazi).replace(/^•\s*/, ""))}
                    </Text>
                    <Text style={{ flexShrink: 0, fontFamily: MONO[500], fontSize: FS.xs, color: C.mut, letterSpacing: 0.6 }}>{r.airport_code}</Text>
                  </View>
                );
              })()}
              <Text numberOfLines={2} style={{ marginTop: ARA[8], fontSize: FS.title + 3, fontFamily: F.serifGosterim, letterSpacing: -0.6,
                                               color: C.ink, lineHeight: SATIR(FS.title + 3, "serif") }}>
                {r.lounge_name || r.airport_code}
              </Text>
              <Text style={{ color: C.mut, fontFamily: MONO[500], fontSize: FS.xs + 0.5, letterSpacing: 0.4, marginTop: ARA[4] }}>
                {BUYUK(fmtLongDate(r.avail_date, lang))} · {String(r.time_from).slice(0,5)}–{String(r.time_to).slice(0,5)}
              </Text>
              {durum === "pasif" && (
                <Text style={{ color: C.mut, fontSize: FS.xs + 0.5, marginTop: ARA[4] }}>{t.availPassiveLine}</Text>
              )}
              {/* v2.87 (madde 5): host kendi ilanının taşıyıcısını da görür. */}
              {!!r.carrier && (
                <View style={{ marginTop: ARA[8] }}>
                  <CarrierChip code={r.carrier} map={hostCarrierMap} t={t} />
                </View>
              )}
              {/* v2.49 — İLANIN BAŞVURULARI: sayı her zaman görünür,
                  dokununca başvuranlar açılır; kabul/red buradan verilir. */}
              {(() => {
                const mine = reqs.filter(q => q.avail_id === r.id);
                const pend = mine.filter(q => q.status === "pending");
                // ══════════════════════════════════════════════════════
                // 🔴 13 EYLÜL (Gökberk md.16) — "bunu kabul edememe sebebim
                // o lounge için başka birini kabul etmiş olmam ise kabul et
                // butonunu aktif göstermemeliyiz."
                // Ölçtüm: sunucu `fully_booked` diyor ve karta yazıyorduk,
                // AMA düğme açık kalıyordu. Host basıyor, kırmızı satır
                // çıkıyor, tekrar basıyor. Artık kapasite dolduğunda düğme
                // KİLİTLİ ve yerinde sebep yazıyor; "Reddet" açık kalıyor —
                // host bekletebilir ya da misafirin kredisini serbest
                // bırakabilir (Gökberk'in istediği ikinci yol).
                // 🆕 SINIF: "SUNUCUNUN REDDEDECEĞİ BİR EYLEMİ AÇIK BIRAKMAK,
                // KULLANICIYA HATA ÜRETTİRMEKTİR."
                // ══════════════════════════════════════════════════════
                const kabulSayisi = mine.filter(q => q.status === "accepted").length;
                const dolu = Math.max(Number(r.filled) || 0, kabulSayisi) >= (Number(r.slots) || 1);
                if (!mine.length) return null;
                const openThis = !!openReqs[r.id];
                return (
                  <View style={{ marginTop: SP[2] }}>
                    <TouchableOpacity hitSlop={TAP.slop}
                      onPress={() => setOpenReqs(o => ({ ...o, [r.id]: !o[r.id] }))}
                      style={{ alignSelf: "flex-start", backgroundColor: pend.length ? C.goldSoft : C.bgAlt,
                               borderWidth: 1, borderColor: pend.length ? C.gold + "50" : C.line,
                               borderRadius: R.xs, paddingVertical: ARA[6], paddingHorizontal: SP[3] }}>
                      <Text style={{ fontSize: FS.sm, fontWeight: "700", color: pend.length ? C.gold : C.mut }}>
                        {t.nApplicants.replace("{n}", String(mine.length))}{pend.length ? ` · ${pend.length} ${t.pendingWord}` : ""}
                      </Text>
                    </TouchableOpacity>
                    {/* 🔴 v2.95 (Gökberk madde 4) — "58 güven pu…"
                        Eski düzen TEK SATIRDI: [ad + puan + durum] | [Kabul] [Reddet].
                        İki düğme sabit genişlikte olduğu için sol sütuna ~%35
                        kalıyordu ve host'un karar vermek için baktığı TEK SAYI
                        ("58 güven puanı") üç nokta ile kesiliyordu. Yani ekran,
                        kararın dayanağını kesip kararın düğmesini büyütüyordu.
                        🆕 SINIF: "BİR SATIRDA HEM KANIT HEM KARAR VARSA, YER
                        DARALDIĞINDA KISALAN HEP KANIT OLUR."
                        Yeni düzen İKİ SATIR: üstte kimlik + güven rozeti
                        (tam genişlik, kesilmez), altta iki düğme (tam genişlik,
                        eşit). Kart yükseldi; kesilen hiçbir şey kalmadı. */}
                    {openThis && mine.map(q => (
                      <View key={q.id} style={{ marginTop: SP[2],
                                                backgroundColor: C.bgAlt, borderRadius: R.xs, padding: ARA[10] }}>
                        <View style={{ flex: 1 }}>
                          {/* 🔴 v2.89 (Gökberk md.3) — "guest1 · 44" yazıyordu ve
                              44'ün NE OLDUĞU hiçbir yerde yazmıyordu. Sayı tek
                              başına bilgi değil; birimi olmayan sayı gürültüdür.
                              Etiket eklendi ve rozet varsa o da gösteriliyor. */}
                          <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                            <Text style={{ flex: 1, minWidth: 0, marginRight: SP[2], fontSize: FS.base, fontWeight: "700", color: C.ink }} numberOfLines={1}>
                              {q.guest_name || "—"}
                            </Text>
                            <Text style={{ flexShrink: 0, fontSize: FS.xs, fontWeight: "600",
                                           color: q.status === "pending" ? C.gold : q.status === "accepted" ? C.green : C.mut }}>
                              {q.status === "pending" ? t.statPending : q.status === "accepted" ? t.reqAcc : q.status}
                            </Text>
                          </View>
                          {/* Güven puanı ARTIK KESİLMİYOR: kendi satırında,
                              birimiyle ve renkli — 70+ yeşil, 50+ altın. */}
                          <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: ARA[6], marginTop: ARA[6] }}>
                            {q.guest_score != null && (
                              <View style={{ backgroundColor: C.card, borderWidth: 1, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2],
                                             borderColor: q.guest_score >= 70 ? C.green : q.guest_score >= 50 ? C.gold : C.line , ...ELEV.card }}>
                                <Text style={{ fontSize: FS.xs, fontWeight: "600",
                                               color: q.guest_score >= 70 ? C.green : q.guest_score >= 50 ? C.gold : C.mut }}>
                                  {q.guest_score} {t.trustLabel}
                                </Text>
                              </View>
                            )}
                            {!!q.guest_badge && (
                              <View style={{ backgroundColor: C.tealBg, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: SP[2] }}>
                                <Text style={{ fontSize: FS.xs, color: C.tealInk, fontWeight: "600" }}>• {badgeLabel(t, q.guest_badge)}</Text>
                              </View>
                            )}
                          </View>
                        </View>
                        {q.status === "pending" && dolu && (
                          <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs,
                                         paddingVertical: ARA[6], paddingHorizontal: ARA[10], marginTop: ARA[10] }}>
                            <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.slotsFullWhy}</Text>
                          </View>
                        )}
                        {q.status === "pending" && (
                          <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
                            {/* 🔴 v3.4 — İKİ DÜĞMENİN DE BEKLEME DURUMU YOKTU.
                                `async` bir işleyici, `disabled` yok: çift
                                dokunuş SLOT SINIRLI bir ilana İKİ kabul
                                gönderiyordu. Host'un en pahalı iki düğmesi.
                                🆕 SINIF: "AĞA GİDEN BİR DÜĞMEYİ KİLİTLEMEZSEN,
                                KULLANICININ SABIRSIZLIĞI BİR VERİ HATASINA
                                DÖNÜŞÜR." */}
                            <TouchableOpacity hitSlop={TAP.slop}
                              disabled={reqBusy === q.id || dolu}
                              onPress={async () => {
                                if (reqBusy || dolu) return;
                                setReqBusy(q.id);
                                try {
                                // 🔴 v2.78 — HATA EKRANA. Önceki hâli `error`ü
                                // okuyor ama YAZMIYORDU: `if (!error) setMoment(...)`.
                                // Host'un en kritik iki düğmesi; yazma düşerse
                                // hiçbir şey olmuyor ve host tekrar tekrar basıyor.
                                const { error } = await supabase.rpc("respond_request", { p_request_id: q.id, p_action: "accept" });
                                if (error) { setErr(mapErr(t, error.message)); return; }
                                setErr(""); setMoment({ name: q.guest_name, id: q.id, q });
                                load();
                                } finally { setReqBusy(null); }
                              }}
                              accessibilityRole="button" accessibilityLabel={t.acceptGuest}
                              style={{ flex: 1, backgroundColor: C.goldBtn, borderRadius: R.md, paddingVertical: ARA[10], minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center", opacity: (reqBusy === q.id || dolu) ? 0.45 : 1 }}>
                              <Text numberOfLines={1} style={{ color: C.onAccent, fontSize: FS.sm, fontWeight: "700" }}>{reqBusy === q.id ? "…" : dolu ? t.slotsFullShort : t.acceptGuest}</Text>
                            </TouchableOpacity>
                            {/* 🔴 RET ARTIK ONAY İSTİYOR. Aynı kartta ilan
                                SİLME onay istiyordu ama bir İNSANI reddetmek
                                tek dokunuşluktu — ikisinden hangisinin daha
                                geri alınamaz olduğu açık.
                                🆕 SINIF: "GERİ ALINAMAZ EYLEMLERİ ÖNEMİNE
                                GÖRE DEĞİL ALIŞKANLIĞA GÖRE ONAYLATIRSAN, EN
                                AĞIRINI ONAYSIZ BIRAKIRSIN." */}
                            <TouchableOpacity hitSlop={TAP.slop}
                              disabled={reqBusy === q.id}
                              onPress={() => setRedKart({ id: q.id, ad: q.guest_name })}
                              accessibilityRole="button" accessibilityLabel={t.decline}
                              style={{ flex: 1, backgroundColor: C.card, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, paddingVertical: ARA[10], minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center" }}>
                              <Text numberOfLines={1} style={{ color: C.ink, fontSize: FS.sm, fontWeight: "600" }}>{t.decline}</Text>
                            </TouchableOpacity>
                          </View>
                        )}
                        {/* ══════════════════════════════════════════════
                            🔴 13 EYLÜL (Gökberk Not 1) — "Host bir ilan
                            davetini kabul ettikten sonra bunu iptal etmek
                            isterse nasıl aksiyon alabilir? Nereden
                            yapabilir?"
                            Ölçtüm: sunucu ZATEN izin veriyor —
                            `respond_request(decline)` 'accepted' durumunu
                            da kabul ediyor ve krediyi iade ediyor. Eksik
                            olan tek şey DÜĞMEYDİ: kabul ettikten sonra
                            kartta hiçbir eylem kalmıyordu.
                            🆕 SINIF: "SUNUCUDA VAR OLAN BİR YETKİ, EKRANDA
                            DÜĞMESİ YOKSA KULLANICI İÇİN YOKTUR."
                            (Oturum başlamışsa sunucu 'session_started'
                            der; o yol sohbetteki oturum panelinden.) */}
                        {/* 🔴 İLK YAZIMDA İKİSİNİ DE ELLE YAZMIŞTIM VE
                            `dugme_check.py` SAYDI (screens.js 7 → 9).
                            Haklıydı: bu iki düğmenin taşıdığı her şey
                            (yükseklik, köşe, 44pt dokunma tabanı, bekleme
                            durumu, dokunuşta kenar ışığı) `Btn`in İŞİ.
                            Elle yazmak, o ekranı ürünün geri kalanından
                            sessizce ayırmaktı.
                            🆕 SINIF: "BİR DÜĞMEYİ ELLE YAZDIĞINDA YALNIZ
                            GÖRÜNÜŞÜNÜ KOPYALARSIN — DAVRANIŞINI DEĞİL." */}
                        {q.status === "accepted" && (
                          <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[10] }}>
                            <View style={{ flex: 1 }}>
                              <Btn sm v="gold" label={t.openChat} a11yLabel={t.openChat}
                                onPress={() => onOpenChat && onOpenChat({ req: { id: q.id }, name: q.guest_name })} />
                            </View>
                            <View style={{ flex: 1 }}>
                              <Btn sm v="ghost" label={t.hostCancelAccepted} a11yLabel={t.hostCancelAccepted}
                                disabled={reqBusy === q.id}
                                onPress={() => setRedKart({ id: q.id, ad: q.guest_name, kabul: true })} />
                            </View>
                          </View>
                        )}
                      </View>
                    ))}
                  </View>
                );
              })()}
              {/* 🔴 v2.78 — TEK DOKUNUŞLUK YIKICI EYLEM, ONAYSIZDI.
                  Üç kusur bir aradaydı: (a) `ConfirmModal` yok — bu kod
                  tabanında altı yerde var, burada yoktu; (b) dokunma alanı
                  ~16pt, kaydırırken yanlışlıkla basılabiliyordu; (c) `error`
                  tamamen atılıyordu, RLS reddederse ilan ekranda kalıyor ve
                  kullanıcı tekrar basıyordu. Aynı satırdaki "Kabul et"
                  düğmesi `minHeight: TAP.minHeight` taşıyor — sil düğmesi
                  unutulmuş. */}
              {/* 🔴 v2.87 — DOKUNMA ALANI KARTIN TÜM GENİŞLİĞİYDİ.
                  Gökberk: "boş alana tıklayınca bile ilanı kaldır butonuna
                  tıklamışım gibi yapıyor." Ölçtüm ve haklı: TouchableOpacity
                  varsayılan `alignSelf: "stretch"` ile kartın sağ kenarına
                  kadar uzuyordu, `minHeight: 44` ile birlikte metnin
                  sağındaki BOŞLUĞUN TAMAMI yıkıcı bir düğmeydi.
                  `alignSelf: "flex-start"` alanı metnin kendisine indiriyor;
                  44pt yüksekliği ve hitSlop koruyor. Onay adımı (ConfirmModal)
                  zaten vardı ve duruyor — yani yanlış dokunuş artık hem daha
                  zor hem hâlâ geri alınabilir. */}
              {/* 🔴 v2.89 (Gökberk md.13) — İLAN ARTIK DÜZENLENEBİLİYOR.
                  Bugüne kadar tek seçenek silip yeniden açmaktı; bu
                  bekleyen başvuruları çöpe atıyor, sicili sıfırlıyor ve
                  kabul edilmiş misafiri kapıda bırakıyordu. */}
              {/* 5 Eylül (Gökberk: "sağ altta güzel bir konumlandırma") — mockup 12c
                  "Düzenle"yi sağ alta koyar; seyahat kartındaki "Seni içeri alacak
                  birini bul" da sağda. Yıkıcı olan solda ve sessiz, birincil olan
                  en sağda ve altın: göz sağ alt köşede ilerler. */}
              {/* ══════════════════════════════════════════════════════════
                  🔴 18 EYLÜL (Gökberk md.10 · md.11) — EYLEMLER ARTIK
                  İLANIN DURUMUNA GÖRE.
                  md.10 "ilanı kaldır tıklamama rağmen ilanı kaldırmıyor"
                  md.11 "ilanı düzenlemek istediğimde ilan artık yayında
                        değil dönüyor"
                  Ölçtüm, ikisi de AYNI kökten: `cancel_availability`
                  ilanı SİLMİYOR, `active=false` yapıyor (291 · doğru
                  karar, başvuru geçmişi silinmemeli). Liste de v3.9.2'den
                  beri pasif ilanları GÖSTERİYOR (yine doğru: sahibinden
                  kaydını saklamak onu silmekle aynı şey). Yanlış olan tek
                  şey EYLEM SATIRIYDI: kaldırılmış bir ilanın altında hâlâ
                  "Kaldır" duruyordu — Gökberk basıyor, satır yerinde
                  kalıyor, "kaldırmadı" diye okuyor. Yanındaki "Düzenle"
                  ise sunucudan 'availability_inactive' yiyordu.
                  Artık:
                     CANLI  → Kaldır · Düzenle
                     PASİF  → Yeniden yayınla · Düzenle   (SQL 295)
                     GEÇMİŞ → eylem yok (geri açılamaz)
                  🆕 SINIF: "BİR EYLEMİ, ARTIK GEÇERSİZ OLDUĞU DURUMDA DA
                  ÇİZMEYE DEVAM EDERSEN, KULLANICI ONU DENER VE SONUCUNU
                  'ÇALIŞMIYOR' DİYE OKUR."
                  ══════════════════════════════════════════════════════════ */}
              {/* 🔴 23 Eylül (Gökberk onayı) — "İlanı kaldır" "İlanı düzenle" ile
                  AYNI ağırlıkta, yan yanaydı ve kırmızıydı: göz önce yıkıcı eyleme
                  gidiyordu. Artık SOLDA, sessiz metin; kırmızı yalnız onay
                  penceresinde (geri dönüşü olan yer orası). Düzenle sağda kalıyor. */}
              {durum !== "gecmis" && (
              <View style={{ flexDirection: "row", gap: SP[4], marginTop: SP[2], alignItems: "center", justifyContent: "space-between" }}>
                {durum === "canli" ? (
                  <TouchableOpacity hitSlop={TAP.slop} onPress={() => setSilAdayi({ id: r.id, acik: reqs.filter(q => q.avail_id === r.id && (q.status === "pending" || q.status === "accepted")).length })}
                    accessibilityRole="button" accessibilityLabel={t.delete}
                    style={{ alignSelf: "flex-start", minHeight: TAP.minHeight, justifyContent: "center" }}>
                    <Text style={{ color: C.mutedAA, fontSize: FS.sm, textDecorationLine: "underline" }}>{t.delete}</Text>
                  </TouchableOpacity>
                ) : (
                  <TouchableOpacity hitSlop={TAP.slop} disabled={acBusy === r.id}
                    onPress={() => yenidenYayinla(r.id)}
                    accessibilityRole="button" accessibilityLabel={t.availRepublish}
                    style={{ alignSelf: "flex-start", minHeight: TAP.minHeight, justifyContent: "center" }}>
                    <Text style={{ color: C.teal, fontSize: FS.sm, fontWeight: "700" }}>
                      {acBusy === r.id ? "…" : t.availRepublish}
                    </Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity hitSlop={TAP.slop} onPress={() => onEditAvail && onEditAvail(r)}
                  accessibilityRole="button" accessibilityLabel={t.editAvail}
                  style={{ minHeight: TAP.minHeight, justifyContent: "center" }}>
                  <Text style={{ color: C.goldText, fontSize: FS.sm, fontWeight: "700" }}>{t.editAvail}</Text>
                </TouchableOpacity>
              </View>
              )}
            </View>
            )}
            </React.Fragment>
            );
          })}
          {/* 🔴 v3.4 — RET ONAYI. Aynı kartta ilan silme onay istiyordu,
              bir insanı reddetmek istemiyordu. */}
          <ConfirmModal
            visible={!!redKart}
            title={redKart?.kabul ? t.hostCancelAccepted : t.declineConfirmTitle}
            body={String((redKart?.kabul ? t.hostCancelBody : t.declineConfirmBody) || "")
              .replace("{ad}", redKart?.ad || "")}
            confirmLabel={redKart?.kabul ? t.hostCancelAccepted : t.decline}
            cancelLabel={t.confirmNo}
            danger
            busy={reqBusy === redKart?.id}
            onCancel={() => setRedKart(null)}
            onConfirm={async () => {
              const id = redKart?.id;
              if (!id || reqBusy) return;
              setReqBusy(id);
              try {
                const { error } = await supabase.rpc("respond_request", { p_request_id: id, p_action: "decline" });
                if (error) { setErr(mapErr(t, error.message)); return; }
                setErr(""); setRedKart(null); load();
              } finally { setReqBusy(null); }
            }}
          />
          {/* ══════════════════════════════════════════════════════════
              🔴 13 EYLÜL (Gökberk md.2) — "İlanı kaldır dediğimde forced
              şekilde kaldırmalı ve başvurular iptal dönmeli."
              Eski akış: kabul edilmiş istek varsa sunucu reddediyordu ve
              ekranda tek satır hata çıkıyordu — host gelemeyeceği günü
              kapatamıyordu. Şimdi SQL 291 `p_force` ile açık istekleri
              reddedip kredileri iade ediyor; bu kutu da KAÇ isteğin
              etkileneceğini SAYIYLA söylüyor.
              🆕 SINIF: "YIKICI BİR EYLEMİ ONAYLATIRKEN 'EMİN MİSİN' DEĞİL
              'NE OLACAK' SORULUR — VE CEVABI SAYIYLA VERİLİR."
              ══════════════════════════════════════════════════════════ */}
          <ConfirmModal
            visible={!!silAdayi}
            title={t.delAvailTitle}
            body={silAdayi && silAdayi.acik > 0
              ? String(t.delAvailBodyN || "").replace("{n}", String(silAdayi.acik))
              : t.delAvailBody}
            confirmLabel={t.delete}
            cancelLabel={t.confirmNo}
            danger
            onCancel={() => setSilAdayi(null)}
            onConfirm={async () => {
              // 🔴 v2.89 — DOĞRUDAN TABLO YAZIMI KALDIRILDI.
              // Bu satır `cancel_availability`nin (040:283) "kabul edilmiş
              // başvuru varsa silemezsin" korumasını ATLIYORDU: host, kabul
              // ettiği misafiri kapıda bırakabiliyordu ve sistem hiçbir şey
              // demiyordu. RPC repoda HİÇ çağrılmıyordu — kural bir
              // fonksiyonda duruyor ama kimse o kapıdan geçmiyordu.
              // 🆕 SINIF: "BİR KURAL, ÇAĞIRILMASI GEREKEN YERDE DURUYORSA
              // KURAL DEĞİL, RİCADIR." (SQL 237 ayrıca tetikleyiciyle de
              // kapattı: hangi yoldan gelinirse gelinsin.)
              const id = silAdayi && silAdayi.id; setSilAdayi(null);
              if (!id) return;
              // `p_force`: açık istekler reddedilir, kredileri iade edilir.
              // Oturum başlamışsa sunucu yine reddeder ('session_started') —
              // o kapı bilerek açık bırakılmadı.
              const { data, error } = await supabase.rpc("cancel_availability",
                { p_id: id, p_force: true });
              if (error) { setErr(mapErr(t, error.message)); return; }
              const n = (data && data.iptal_edilen) || 0;
              // md.10 — "kaldırıldı" demek yetmiyor: ilan listede
              // DURUYOR (pasif rozetiyle). Nereye gittiğini söylemezsek
              // kullanıcı "kaldırmadı" diye okuyor.
              setErr(""); setBilgi((n > 0
                ? String(t.delAvailDoneN || "").replace("{n}", String(n))
                : t.delAvailDone) + " " + t.delAvailWhere);
              load();
            }}
          />
          <TouchableOpacity accessibilityRole="button" accessibilityLabel={t.addAvail}
            onPress={() => (onAddAvail ? onAddAvail() : setAdding(true))}
            style={{ marginTop: ARA[14], borderWidth: 1.5, borderColor: C.gold, borderRadius: R.sm,
                     minHeight: TAP.minHeight, alignItems: "center", justifyContent: "center" }}>
            <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.base }}>{t.addAvail}</Text>
          </TouchableOpacity>
        </>
      )}
      {/* 🔴 v3.4 — HATA SATIRI `{adding && …}` BLOĞUNUN İÇİNDEYDİ.
          Yani seyahat SİLME ve AMAÇ değiştirme hataları (`setErr`, :571
          ve :322) hiçbir zaman çizilmiyordu: o iki eylem `adding === false`
          iken oluyor. `seyahat_sil` gerçekten reddedilebilir (bağlı
          başvuru varsa) — kullanıcı siliyor, satır duruyor, ekranda tek
          kelime yok.
          🆕 SINIF: "BİR HATA SATIRINI KOŞULLU BİR BLOĞUN İÇİNE KOYARSAN,
          O KOŞUL DIŞINDAKİ HER HATA SESSİZ OLUR — HATA MESAJI, HATAYI
          ÜRETEN HER DURUMDA GÖRÜNÜR OLMALIDIR." */}
      {!!err && !adding && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}
      {!!bilgi && !adding && (
        <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: C.tealLine,
                       borderRadius: R.xs, padding: ARA[10], marginTop: SP[2] }}>
          <Text style={{ color: C.tealInk, fontSize: FS.sm }}>{bilgi}</Text>
        </View>
      )}
      {adding && (
        <>
          <Picker label={t.airport} value={ap} options={airports} onPick={setAp} t={t} />
          {/* 🔴 v2.49 — İKİ AYRI SEÇİCİ VARDI ve sekmeleri yalnız birine
              koymuştum: HostAvailability sekmeli LoungePicker kullanırken
              Yayın'daki bu form düz Picker'da kalmıştı (Gökberk'in
              gördüğü sekmesiz modal buydu). Artık burada da iç/dış
              sekmeli LoungePicker var. */}
          {lounges.length > 0 && (
            <LoungePicker t={t} lounges={lounges}
              value={lg ? lg.key : null}
              onSelect={(v) => setLg({ key: v })} />
          )}
          <DateInput label={t.date} value={date} onChange={setDate} />
          <View style={{ flexDirection: "row", gap: ARA[10], marginBottom: SP[3] }}>
            <TimeInput label={t.timeFrom} value={from} onChange={setFrom} />
            <TimeInput label={t.timeTo} value={to} onChange={setTo} />
          </View>

          {/* 🔴 v2.02 — TALEP BİLGİSİ ARTIK ARALIĞA BAĞLI VE SIFIRDA SUSMUYOR.
              Eskiden havalimanı seçilir seçilmez "şu kadar yolcu bekliyor"
              diyorduk; o yolcuların saati host'unkiyle örtüşmüyorsa sayı
              yanlış bir vaatti. Ayrıca 0 gelince rozet HİÇ çizilmiyordu —
              host "sistem çalışmıyor mu?" diye düşünüyordu. Üç durum da
              konuşuyor: tarih yok / bekleyen var / bekleyen yok. */}
          {ap && (
            <View style={{ flexDirection: "row", alignItems: "center",
                           backgroundColor: (waiting > 0) ? C.tealBg : C.bgAlt,
                           borderWidth: 1, borderColor: (waiting > 0) ? C.teal + "35" : C.line,
                           borderRadius: R.sm, padding: SP[3], marginBottom: SP[3] }}>
              <Ikon ad={(waiting > 0) ? "kutlama" : "bilgi"} boy={18} renk={C.gold} stil={{ marginRight: ARA[10] }} />
              <Text style={{ flex: 1, fontSize: FS.sm, lineHeight: 18,
                             color: (waiting > 0) ? C.teal : C.mut,
                             fontWeight: (waiting > 0) ? "600" : "400" }}>
                {(waiting === null || waiting === undefined)
                  ? t.demandPickFirst
                  : waiting > 0
                  ? t.demandInRange.replace("{n}", waiting)
                  : t.demandNoneYet}
              </Text>
            </View>
          )}
          {/* 🔴 v2.68 — İLAN AÇARKEN DE UÇUŞ DOĞRULAMASI.
              Eskiden yalnız düz bir metin kutusuydu: host "TK712" yerine
              PNR yazsa ya da olmayan bir sefer girse hiçbir uyarı yoktu,
              ve o ilan misafire "aynı uçuştayız" rozetini YANLIŞ
              gösterebiliyordu. Alan hâlâ İSTEĞE BAĞLI — boş bırakan host
              hiçbir şey kaybetmez; yazan host doğrulama ve kod paylaşımı
              uyarısı kazanır. Taşıyıcı çipleri burada yok (ilanın
              taşıyıcısı ayrı bir alanda seçiliyor), o yüzden onCarrier
              geçmiyoruz. */}
          <FlightField t={t} value={flight} onChange={setFlight} date={date}
            showChips={false} labelStyle={S.label} inputStyle={S.input} />
          {/* 🔴 v2.69 — KABİN SINIFI SEÇİMİ (isteğe bağlı).
              THY Tablo-1/2/3: Business kabin YOLCUSUNUN misafir hakkı
              YOKTUR; İstanbul dış hatlarda Business bölümüne kart
              tipinden bağımsız girilir ama o bölümde misafir kabul
              edilmez — misafirle girecek yolcu Miles&Smiles bölümüne
              gitmelidir. Kabin girilmezse davranış AYNEN eskisi gibi;
              girilirse motor bu kuralı da uygular. */}
          <Text style={S.label}>{t.cabinLabelOpt}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: SP[3] }}>
            {[["economy", t.cabinEconomy], ["business", t.cabinBusiness], ["first", t.cabinFirst]].map(([k, lb]) => (
              <TouchableOpacity key={k} accessibilityRole="button" accessibilityLabel={lb}
                onPress={() => setCabin(cabin === k ? null : k)}
                style={{ minHeight: TAP.minHeight, minWidth: TAP.minWidth, justifyContent: "center", paddingHorizontal: ARA[14], borderRadius: R.full,
                         borderWidth: 1, borderColor: cabin === k ? C.gold : C.line,
                         backgroundColor: cabin === k ? C.goldSoft : C.card }}>
                <Text style={{ fontSize: FS.sm, color: cabin === k ? C.gold : C.ink,
                               fontWeight: cabin === k ? "700" : "400" }}>{lb}</Text>
              </TouchableOpacity>
            ))}
          </View>
          <Text style={S.label}>{t.slots}</Text>
          <View style={{ flexDirection: "row" }}>
            {[1, 2, 3].map(n => (
              <TouchableOpacity key={n} style={[S.chip, slots === n && S.chipOn]} onPress={() => setSlots(n)}>
                <Text style={{ color: slots === n ? C.gold : C.ink, fontWeight: slots === n ? "700" : "400" }}>{n}</Text>
              </TouchableOpacity>
            ))}
          </View>
          <Text style={S.label}>{t.accessSrc}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
            {t.accessOpts.map(o => {
              const on = srcs.includes(o);
              return (
                <TouchableOpacity key={o} style={[S.chip, on && S.chipOn]}
                  onPress={() => setSrcs(on ? srcs.filter(x => x !== o) : [...srcs, o])}>
                  <Text style={{ color: on ? C.gold : C.ink, fontSize: FS.sm, fontWeight: on ? "600" : "400" }}>{o}</Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
          <Btn label={t.publish} onPress={publish} disabled={busy} busy={busy} />
          <TouchableOpacity hitSlop={TAP.slop} style={{ alignItems: "center", marginTop: SP[3] }} onPress={() => setAdding(false)}>
            <Text style={{ color: C.mut }}>{t.cancel}</Text>
          </TouchableOpacity>
        </>
      )}
    </Kaydirma>
    </>
  );
}
export function Profile({ t, refresh, session, onManagePlan, onSafety, onTrust, onHistory, onReferral, onRatings, onLogout, onWallet, onShop, onSettings, onEditProfile, onCampaigns, onBell, onBroadcast }) {
  // 🔴 12 EYLÜL — DARALAN BANT. Gökberk bu ekranda fark etmişti:
  // "profil tabında… scroll yapınca aşağıda görmem gereken asıl alanları
  // daha zor görüyorum." Ölçüm bantta: sabit 198.7pt → 84pt.
  const bnt = useDaralanBant();
  const [myRole, setMyRole] = useState(null);
  const [credits, setCredits] = useState(null);
  const [err, setErr] = useState("");            // v2.78: gizlilik anahtari hatasi GORUNSUN
  const [logoutMsg, setLogoutMsg] = useState("");
  const [confirmOut, setConfirmOut] = useState(false);
  const uid = session?.user?.id;
  const [p, setP] = useState(null);
  const [v, setV] = useState({});
  const [ts, setTs] = useState({});
  const [name, setName] = useState("");
  const [prof, setProf] = useState("");
  const [bio, setBio] = useState("");
  // 🔴 v2.30 — SEYAHAT TARZI. Kayit akisina DEGIL profile koyuyoruz:
  // kaydolurken bir soru daha sormak, kaydolmayi zorlastirmaktan baska
  // ise yaramaz. Bos birakan cezalandirilmaz — eslesme puani etkilenmez,
  // yalniz uyum sinyali cikmaz.
  const [unused, setUnused] = useState(null);
  const [langs, setLangs] = useState([]);
  const [showDisc, setShowDisc] = useState(true);
  const [photo, setPhoto] = useState(null);
  const [upBusy, setUpBusy] = useState(false);
  const [gender, setGender] = useState(null);
  const [points, setPoints] = useState(0);       // #34: MVP istatistik uclusu
  const [sesCount, setSesCount] = useState(0);
  const [ratingAvg, setRatingAvg] = useState(null);
  const [sehir, setSehir] = useState("");          // 5 Eylül — banttaki "meslek · şehir"
  const [busy, setBusy] = useState(false);
  // 🔴 v2.80 — GÖLGE KISIT ARTIK SESSİZ DEĞİL.
  // Ölçüm: `rnapp/` içinde `shadow_limited` geçen SIFIR satır vardı.
  // Yani 3 açık şikâyet ya da 2 no-show sonrası kullanıcı keşiften
  // siliniyor, 7 gün kimse onu görmüyor ve kendisine TEK KELİME
  // söylenmiyordu. İnsan "kimse bana başvurmuyor" diye düşünüp
  // uygulamayı bırakır — ve nedenini asla öğrenmez.
  // Kısıtı kaldırmıyoruz (moderasyon aracı); görünür yapıyoruz.
  // İtiraz yolu da aynı kutuda: cezanın yanında itiraz olmalı.
  const [kisit, setKisit] = useState(null);

  const load = useCallback(async () => {
    const uidC = session?.user?.id;
    // ══════════════════════════════════════════════════════════════════
    // 🔴 v3.9 — PROFİL EKRANI BEŞ TUR ATIYORDU, HİÇBİRİ DİĞERİNİ
    // BEKLEMİYORDU.
    //
    // Ölçüldü: kredi defteri → (4'lü dalga) → oturumlar → puanlar →
    // kullanıcı satırı. Beş sıralı tur. Supabase turu bu projede
    // ölçüldü: 345 ms (BO tarafı, sabit hat). Telefonda mobil şebekede
    // daha yüksek. Yani ekran, HİÇBİR MANTIKSAL SEBEP OLMADAN dört
    // fazladan tur bekletiyordu.
    //
    // Hepsi `uid` ile parametrelendi; hiçbiri diğerinin sonucunu
    // kullanmıyor. Tek dalga.
    //
    // ⚠️ `allSettled` DEĞİL `all`: burada tek tek düşmeyi tolere eden
    // iki sorgu vardı (`sessions`, `ratings` kendi `try`lerindeydi).
    // O toleransı KAYBETMEMEK için ikisi `.then(…).catch(…)` ile
    // kendi düşüşünü kendi yutuyor — yani dalga bütün olarak reddedilmiyor,
    // davranış birebir korunuyor.
    // 🆕 SINIF: "SIRALI ÇAĞRILARI TEK DALGAYA ALIRKEN, HER ÇAĞRININ
    // KENDİ HATA TOLERANSI DA TAŞINMALI — YOKSA HIZLANDIRDIĞIN EKRAN
    // İLK BOZUK SORGUDA TAMAMEN BOŞALIR."
    // ══════════════════════════════════════════════════════════════════
    const [{ data: pr }, { data: ve }, { data: tsc }, { data: bal },
           cl, ss, rr, { data: u }, vs0, av0] = await Promise.all([
      supabase.from("profiles").select("*").eq("user_id", uid).maybeSingle(),
      supabase.from("verifications").select("*").eq("user_id", uid).maybeSingle(),
      supabase.from("trust_scores").select("*").eq("user_id", uid).maybeSingle(),
      supabase.from("user_balances").select("points").eq("user_id", uid).maybeSingle(),
      uidC ? supabase.from("credit_ledger")
        .select("balance_after").eq("user_id", uidC)
        .order("created_at", { ascending: false }).limit(1)
        .then(r => r.data).catch(() => null) : Promise.resolve(null),
      // #34: tamamlanan oturum sayim (guest veya host olarak)
      supabase.from("sessions")
        .select("id, requests!inner(guest_id, host_id)").eq("status", "completed").limit(200)
        .then(r => r.data).catch(() => null),
      // Puanlama ortalamam (MVP orta istatistik: 5.0★) — okunamazsa "—"
      supabase.from("ratings").select("score").eq("rated_id", uid)
        .then(r => r.data).catch(() => null),
      supabase.from("users").select("gender, role").eq("id", uid).maybeSingle(),
      // 5 Eylül — banttaki "meslek · şehir": sıradaki seyahatin, yoksa sıradaki
      // ilanın havalimanı şehri (airports.city). İkisi de yoksa şehir yazılmaz.
      supabase.from("visits").select("airport_code, airports(city)").eq("user_id", uid)
        .gte("visit_date", yerelGun()).order("visit_date").limit(1)
        .then(r => r.data).catch(() => null),
      supabase.from("availabilities").select("airport_code, airports(city)").eq("host_id", uid).eq("active", true)
        .gte("avail_date", yerelGun()).order("avail_date").limit(1)
        .then(r => r.data).catch(() => null),
    ]);
    {
      const v0 = (vs0 && vs0[0]) || (av0 && av0[0]);
      setSehir(v0 ? ((v0.airports && v0.airports.city) || v0.airport_code || "") : "");
    }
    if (uidC) setCredits(cl?.[0]?.balance_after ?? 0);
    const sesN = (ss || []).filter(x => x.requests?.guest_id === uid || x.requests?.host_id === uid).length;
    const rAvg = rr?.length
      ? (rr.reduce((a, x) => a + (x.score || 0), 0) / rr.length).toFixed(1)
      : null;
    setP(pr); setV(ve || {}); setTs(tsc || {});
    setPoints(bal?.points ?? 0); setSesCount(sesN); setRatingAvg(rAvg);
    setName(pr?.name || ""); setProf(pr?.profession || ""); setBio(pr?.bio || "");
    supabase.rpc("host_unused_rights").then(({ data }) => setUnused(data)).catch(() => {});
    // v2.80: gölge kısıt durumu. Hata olursa banner çıkmaz (yanlış
    // "kısıtlısın" göstermektense hiç göstermemek doğru bozulma yönü).
    supabase.rpc("kisit_durumum")
      .then(({ data, error }) => { if (error) { logError("kisit_durumum", error); return; } setKisit(data || null); })
      .catch(() => {});
    setLangs(pr?.languages || []); setShowDisc(pr?.show_on_discovery ?? true);
    setPhoto(pr?.photo_url || null);
    setGender(u?.gender || null);
    setMyRole(u?.role || null);
    // v2.66: kalan hak / kapasite / erişim kaynağı üçlüsü Profili Düzenle
    // ekranına taşındı (madde 4) — orada my_host_access okunuyor.
  }, [uid]);
  useEffect(() => { load(); }, [load, refresh]);   // v2.47: duzenlemeden donunce taze veri

  // 🔴 v2.99 — BURADA BİR `save()` VARDI VE HİÇBİR YERDEN ÇAĞRILMIYORDU.
  //
  // Ölçüm: Profile gövdesinde (435 satır) `save` adı TEK KEZ geçiyordu —
  // yani kendi bildirimi. Profil düzenleme `EditProfile` ekranına taşındığında
  // buradaki satır içi düzenleme kaldırılmış, fonksiyon unutulmuştu.
  //
  // Silinmesinin sebebi "kullanılmıyor" değil, TUZAK OLMASI: gövdesi
  // `profiles` tablosuna `name/profession/bio/languages` YAZIYORDU. Bir gün
  // birisi bir düğmeyi buna bağlasa, `EditProfile`ın kaydettiğini SESSİZCE
  // ezerdi — üstelik burada `travel_style` bilerek yazılmıyor olduğu için
  // fark ancak o alan kaybolunca anlaşılırdı.
  //
  // 🆕 SINIF: "ÇAĞRILMAYAN AMA YAZAN BİR FONKSİYON, ÖLÜ KOD DEĞİL KURULMUŞ
  // BİR TUZAKTIR."
  async function toggleDisc(val) {
    // 🔴 v2.78 — GİZLİLİK ANAHTARI SESSİZDİ.
    // Anahtar önce EKRANDA değişiyor, sonra yazma yapılıyordu ve `error`
    // hiç okunmuyordu. Yazma düşerse kullanıcı "keşifte gizlendim" sanar,
    // sunucu hâlâ "görünür" der. Bir gizlilik anahtarının yalan söylemesi,
    // hiç olmamasından kötüdür. Artık hata olursa anahtar GERİ alınıyor.
    const onceki = showDisc;
    setShowDisc(val);
    // 🔴 23 Eylül — kolon 253 §5'ten beri istemciye KAPALI; doğrudan
    // `update` her seferinde "permission denied" alıyordu. Tek amaçlı kapı: SQL 300 §A4.
    const { error } = await supabase.rpc("kesifte_gorun", { p_acik: val });
    if (error) { setShowDisc(onceki); setErr(mapErr(t, error.message)); return; }
    setErr("");
  }

  if (!p) return <Load t={t} title={t.navProfile} />;
  const initial = (p.name || "?").charAt(0).toUpperCase();

  /* ══════════════════════════════════════════════════════════════════
     🔴 5 EYLÜL — PROFİL BANDI (Gökberk madde 2 + 7, onaylı 09b):
       bant: LOUNGELINK · dişli · "Profil" · [avatar 60 · isim 18/700 ·
             "meslek · şehir" 12 · rozet çipi] · cüzdan şeridi
             (OTURUM · YILDIZ · LOUNGEPUAN · KREDİ→Cüzdan)
       düğüm ("SELİN B. · İSTANBUL") YOK — isim zaten avatarın yanında.
       Gövde: [kısıt] → eksik profil (tek kompakt kart, yalnız eksik varsa)
              → satırlar → … ; "Bakiye" kartı kalktı (kredi şeritte).
     ══════════════════════════════════════════════════════════════════ */
  const bant = (
    <Hdr t={t} title={t.ppProfile} kaydir={bnt.kaydir}
      right={<Btn v="ust" daire a11yLabel={t.settings || "Ayarlar"} onPress={onSettings}
                  sol={<Ikon ad="ayarlar" boy={18} renk={C.foto.baslik} />} />}
      foto={{ olc: bnt.olc, tam: bnt.tam, altIcerik: (
        <View>
          {/* 5 Eylül — ÖLÇÜLDÜ: satır 80pt çıkıyordu (mockup 60+8): üstten hizalı,
              ad 22 · meslek 16 · çip 26, aralar 2 — sütun 69; şerit 8 sonra. */}
          <View style={{ flexDirection: "row", alignItems: "flex-start", marginTop: ARA[14] }}>
            <TouchableOpacity hitSlop={TAP.slop} disabled={upBusy}
              accessibilityRole="button"
              accessibilityLabel={photo ? t.photoChange : t.photoUpload}
              onPress={async () => {
                setUpBusy(true);
                const url = await pickAndUploadPhoto(uid);
                setUpBusy(false);
                if (url) { setPhoto(url); load(); }
              }}>
              <View style={{ width: 60, height: 60, borderRadius: R.full, backgroundColor: C.avatarBg || C.goldSoft,
                             borderWidth: 1, borderColor: C.line2 || (C.gold + "35"),
                             alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
                {upBusy ? <ActivityIndicator color={C.gold} />
                  : photo ? <Image source={{ uri: photo }} style={{ width: 60, height: 60 }} />
                  : <Text style={{ fontSize: FS.display, fontWeight: "600", color: C.goldText, fontFamily: F.serif }}>{initial}</Text>}
              </View>
            </TouchableOpacity>
            <View style={{ flex: 1, minWidth: 0, marginLeft: ARA[14] }}>
              <Text numberOfLines={1} style={{ fontSize: FS.lg + 2, lineHeight: SATIR(FS.lg + 2), fontWeight: "700", color: C.foto.baslik }}>{p.name}</Text>
              {(p.profession || sehir) ? (
                <Text numberOfLines={1} style={{ color: C.meshAlt, fontSize: FS.sm, lineHeight: SATIR(FS.sm), marginTop: ARA[2] }}>
                  {[p.profession, sehir].filter(Boolean).join(" · ")}
                </Text>
              ) : null}
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginTop: ARA[2] }}>
                <Cip ton={myRole === "host" ? "ok" : "gold"} etiket={`• ${badgeLabel(t, ts.badge)} · ${ts.score ?? 0}`} />
                {/* v6.1 (Gökberk md.35) — kurucu rozeti kendi profilinde de görünür. */}
                {p.founding_host_no ? (
                  <Cip ton="gold" etiket={String(t.foundingBadge || "Kurucu Host #{n}").replace("{n}", String(p.founding_host_no))} />
                ) : null}
              </View>
            </View>
          </View>
          <CuzdanSeridi stil={{ marginTop: ARA[8] }} hucreler={[
            { deger: sesCount, etiket: t.statSessions },
            { deger: ratingAvg ? String(ratingAvg) : "—", etiket: t.ratingShort || t.ratingLabel },
            { deger: points, etiket: t.loungePointsLabel },
            { deger: credits ?? "—", etiket: t.walletCredits || "kredi", onPress: onWallet, a11y: t.walletTitle },
          ]} />
        </View>
      ) }} />
  );

  return (
    <>
    {bant}
    <Kaydirma {...bnt.scrollProps}
      contentContainerStyle={{ padding: ARA[20], paddingTop: bnt.ustBosluk + SP[4],
                               paddingBottom: ARA[40] }}>
      {!!err && (
        <View style={{ backgroundColor: C.redBg, borderWidth: 1, borderColor: "transparent",
                       borderRadius: R.xs, padding: SP[3], marginBottom: SP[3] }}>
          <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>{err}</Text>
        </View>
      )}
          {/* 5 Eylül — kısıt bildirimi ve eksik-profil kartı bandın HEMEN
              altında (Gökberk: "en altta kalmış"); biyografi eksikliği de bu
              kartın içinde sayılıyor. */}
          {kisit && kisit.kisitli && (
            <View style={{ backgroundColor: C.redBg || C.hataBg, borderWidth: 1,
                           borderColor: "transparent", borderRadius: R.sm, padding: SP[3], marginBottom: SP[3] }}>
              <Text style={{ color: C.redInk, fontWeight: "700", fontSize: FS.sm }}>
                {kisit.baslik || t.restrictedTitle}
              </Text>
              <Text style={{ color: C.body, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>
                {kisit.metin}
              </Text>
            </View>
          )}
          <ProfileCompletionWidget t={t} profile={p} onEdit={onEditProfile} />
          {/* Profil tamamlanma — MVP'de Profil'in en ustunde, menuden ONCE */}
          {/* 🔴 PROFİL SEKMESİ ÇOK KALABALIKTI (Gökberk madde 4).
              Profil tamamlama, kurucu host, kullanılmayan hak, seyahat
              tarzı, kadın güvenlik modu gibi bloklar asıl içeriği
              (bağlantılar, oturumlar, cüzdan) ekranın çok altına
              itiyordu.
              Blokları BAŞKA EKRANA TAŞIMAK yerine KATLADIK: taşımak
              prop zincirini ve geri dönüş akışını değiştirir (bu
              projede iki kez ekran kaybına yol açtı); katlamak aynı
              sonucu risksiz verir. Varsayılan KAPALI: kullanıcı önce
              asıl içeriği görür, hazırlık işlerini isterse açar. */}
          {/* 🔴 v2.66 (Gökberk madde 4, ikinci tur): KATLAMAK YETMEDİ.
              v2.65 blokları katlamıştı ama katlı blok da bir bloktur:
              başlık + alt metin + ok, ekranın üstünde yine duruyor ve
              asıl içerik (güven puanı, oturum geçmişi, rozetler) hâlâ
              aşağıda kalıyordu. Bu tur GERÇEKTEN TAŞINDI:
                · Profili tamamla     → tek satır kısayol (aşağıda)
                · Kurucu Host / Host olmak istiyorum → Profili Düzenle
                · Seyahat tarzın      → Profili Düzenle (zaten oradaydı)
                · Durum bilgisi (hak/kapasite/kaynak) → Profili Düzenle
                · Kadın güvenlik modu → Profili Düzenle (zaten oradaydı)
              Profil bir VİTRİNDİR, hazırlık listesi değil. Geriye tek
              satır kalır ve o satır düzenleme ekranını açar. */}
          {/* 🔴 v2.80 — KISIT BİLDİRİMİ. Profilin en üstünde, çünkü
              kullanıcı buraya "neden bir şey olmuyor" diye bakar. */}
          {/* ============================================================
              MENU — MVP v15 GuestProfile (satir 2280-2290) BIREBIR sirasi:
                ◈ Baglantilarim · 📅 Seyahatlerim · 📅 Oturum Gecmisi
                🏆 LoungePuan (=Magaza) · 🎁 Davet Et & Kazan · 🔔 Bildirimler
                🌟 Guven Puani · 🛡 Guvenlik Merkezi · ⚙ Ayarlar · 🚪 Cikis

              v1.21'e kadar: Magaza AYRI TAB'di, Ayarlar bu sayfanin dibinde
              acikta duruyordu, Cikis hem burada hem Ana Sayfa'daydi.
              MVP'de Magaza LoungePuan'in altinda, Ayarlar ayri EKRAN,
              Cikis yalniz burada (en altta, kirmizi).

              MVP'de OLMAYAN ama bizim ekledigimiz (silinmedi, dogru yere kondu):
                💳 Plan · 👛 Cuzdan · 🏷 Lounge hakki · 📡 Canli Durum
                ✦ Host olmak istiyorum  -> hepsi bu listede, tab degil.
              ============================================================ */}
          {/* 🔴 v6.1 (Gökberk md.8) — durum/biyografi "Çıkış Yap"ın hemen
              üstündeydi: kimlik bilgisi, hesap kapatma eyleminin yanında.
              Ayarlara da ait değil (ayar değil, vitrin). Yeri menünün
              BAŞI: kimlik şeridinin hemen altında, kim olduğunu söyleyen
              ilk cümle. */}
          {/* biyografi kartı yalnız biyografi VARSA (yoksa eksik kartı söylüyor) */}
          {!!p.bio && (
          <TouchableOpacity hitSlop={TAP.slop} activeOpacity={0.8} onPress={onEditProfile}
            style={[S.card, { marginBottom: ARA[10] }]}>
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start" }}>
              <Text style={{ color: C.ink, fontSize: FS.base, lineHeight: 20, flex: 1, marginRight: SP[2] }}>
                {p.bio}
              </Text>
              <Ikon ad="duzenle" boy={22} renk={C.mutedAA} />
            </View>
            {langs.length > 0 && (
              <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[2] }}>
                {langs.map(l => (
                  <View key={l} style={{ backgroundColor: C.bgAlt, borderRadius: R.xs, paddingVertical: SP[1], paddingHorizontal: ARA[10], marginRight: ARA[6], marginBottom: ARA[6] }}>
                    <Text style={{ fontSize: FS.sm, color: C.mutedAA }}>{l}</Text>
                  </View>
                ))}
              </View>
            )}
          </TouchableOpacity>
          )}
          {[
            // ============================================================
            // MVP PROFİL MENÜSÜ — kaynak birebir (host vs guest ayrı).
            // Host ilk iki: Host Kademesi + Yayın & Davet.
            // Guest ilk iki: Bağlantılarım + Seyahatlerim.
            // Ortak çekirdek: Oturum Geçmişi · LoungePuan · Davet Et · Bildirimler
            //                 · Güven Puanı · Güvenlik Merkezi · Ayarlar.
            // ============================================================
            // 🔴 v1.75 (Gokberk): "{rozet} Seviyesi" satırı KALDIRILDI —
            // menüde zaten "Güven Puanım" var ve ikisi AYNI ekranı açıyordu.
            ...(myRole === "host"
              ? [["yayin", t.bcTitle, onBroadcast, C.teal]]      // → Yayın & Davet (HostBroadcast)
              : []),   // Guest: Bağlantılarım/Seyahatlerim ALT MENÜDE zaten var —
                       // burada tekrar göstermek gereksiz tekrar yaratıyordu (Gokberk'in kararı).
                       // MVP'de bu satırlar profilde de vardı ama MVP'de de tekrardı.
            ["gecmis", t.histTitle, onHistory, null],
            // 🔴 v2.95 (Gökberk madde 11) — DEĞERLENDİRMELER.
            // "ana sayfadaki 'ağırlaman nasıl geçti' alanı daraltılıp
            //  genişletilemiyor... 'Şimdi değil'e tıklanınca da bir daha
            //  bulunamıyor. Profil tabında Oturum geçmişi ile Bildirimler
            //  arasına Değerlendirmeler diye bir alan koyalım."
            // Haklıydı ve tehlikeli olan kısım şuydu: `defer_rating` kaydı
            // KALICI olarak erteliyordu ve ertelenen puanlamaya geri
            // dönmenin HİÇBİR yolu yoktu. Yani ürün, güven döngüsünün tek
            // girdisini tek dokunuşla kalıcı olarak çöpe atıyordu.
            // 🆕 SINIF: "BİR ŞEYİ ERTELEYEN DÜĞMEYE, O ŞEYİ GERİ BULMANIN
            // YOLUNU EKLEMEZSEN 'ERTELE' DEĞİL 'SİL' YAZMIŞ OLURSUN."
            ["degerlendirme", t.ratingsTitle, onRatings, C.gold],
            ["bildirim", t.notifTitle, onBell, null],
            // v1.86 — MENÜ ÜÇ GRUBA AYRILDI. 12 maddelik düz liste
            // "burada ne yapabilirim?" sorusunu görünmez kılıyordu; ayrıca
            // AYARLAR tek büyük harfle yazılıp diğerlerinden ayrışıyordu.
            // Gruplama, tıklama sayısını değiştirmez ama TARAMA maliyetini düşürür.
            [null, t.menuGroupTrust],
            ["guvenPuan", t.trustTitle, onTrust, null],
            ["guvenlik", t.safetyTitle, onSafety, null],
            [null, t.menuGroupRewards],
            ["puan", t.shopTitle || "LoungePuan", onShop, C.gold],
            ["davet", t.refTitle, onReferral, null],
            // v1.86 — 🔴 MÜKERRER "CÜZDAN" KALDIRILDI.
            // Bakiye kartında zaten "BAKİYE · Cüzdan ›" satırı var ve aynı
            // ekrana gidiyordu. Aynı hedefe iki ayrı giriş, menüyü uzatıp
            // kullanıcıya "ikisi farklı mı?" diye sordurur. Tek giriş kaldı:
            // bakiyeyi gördüğün yer.
            ["kampanya", t.campaignsTitle, onCampaigns, C.gold],
            [null, t.menuGroupAccount],
            // 🔴 v2.65 — bu iki satır GERİ GELDİ. Yukarıdaki yorum ikisini
            // de "hepsi bu listede" diye sayıyordu ama listede yoklardı:
            // Plans ekranı hiçbir yerden açılamıyor, Canlı Durum yalnız
            // aktif bir sohbetin içinden açılabiliyordu.
            ["planKart", t.plansTitle, onManagePlan, null],
            // 🔴 v2.95 (Gökberk madde 5) — "CANLI DURUM" PROFİLDEN KALDIRILDI.
            // "profil tabında Canlı durum alanı oluşmuş. Bu alanın oluşmasına
            //  gerek yok. Canlı durum oturum tamamlama ekranında olmalı."
            // Doğru. v2.65'te bu satırı "ulaşılamaz ekran" gerekçesiyle BEN
            // eklemiştim ve o gerekçe o gün doğruydu. Ama ekran artık
            // oturum panelinden açılıyor (madde 6'daki "Canlı durum" düğmesi).
            // Canlı durum, AKTİF BİR OTURUMU olmayan kullanıcı için anlamsız
            // bir menü satırıdır: girer, boş bir ekran görür, "bu ne?" der.
            // 🆕 SINIF: "ULAŞILAMAZ BİR EKRANI MENÜYE KOYARAK ÇÖZMEK, EKRANI
            // BAĞLAMINDAN KOPARMAKTIR — DOĞRU ÇÖZÜM ONU AİT OLDUĞU AKIŞA
            // BAĞLAMAKTIR."
            ["ayarlar", t.settings || "Ayarlar", onSettings, null],
          ].filter(Boolean).reduce((gruplar, oge) => {
            // v6.3 · PANO H4 (Gökberk onayı) — düz liste GRUPLARA ayrılır: başlık
            // satırı (ic === null) yeni grup açar; her grup TEK cam kutu, satırlar
            // 1 px ışık çizgisiyle ayrılır. İkonlar ve renkleri aynen korunur.
            if (oge[0] === null) gruplar.push({ baslik: oge[1], satir: [] });
            else { if (!gruplar.length) gruplar.push({ baslik: null, satir: [] }); gruplar[gruplar.length - 1].satir.push(oge); }
            return gruplar;
          }, []).map((g, gi) => (
            <View key={"g-" + gi + (g.baslik || "")} style={{ marginTop: gi === 0 ? 0 : ARA[10] }}>
              {!!g.baslik && (
                /* tasarım 09 bölüm başlığı: 9.5/700 · aralık 1.2 · altın */
                <Text style={{ fontSize: FS.micro + 0.5, letterSpacing: 1.4, fontWeight: "600",
                               color: C.goldText, marginBottom: ARA[8], marginHorizontal: ARA[6] }}>
                  {BUYUK(g.baslik || "")}
                </Text>
              )}
              <View style={{ backgroundColor: C.camYuzey || C.card, borderRadius: R.lg + 2, paddingHorizontal: SP[4],
                             ...ustIsik(C.parlama || C.line) }}>
                {g.satir.map(([ic, lb, fn, accent], si) => (
                  <TouchableOpacity hitSlop={TAP.slop} key={lb} onPress={fn} accessibilityRole="button" accessibilityLabel={lb}
                    style={{ minHeight: 52, flexDirection: "row", justifyContent: "space-between", alignItems: "center",
                             borderTopWidth: si === 0 ? 0 : StyleSheet.hairlineWidth, borderTopColor: C.kenarIsik || C.line }}>
                    <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                      {/* Eskisi `<Text>⚙</Text>` idi (U+2699 metin sunumlu, cihaz siyah çizer); Ikon vektör. */}
                      <Ikon ad={ic} boy={19} renk={accent || C.goldText} stil={{ marginRight: ARA[14] }} kutu={22} />
                      <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "500" }}>{lb}</Text>
                    </View>
                    <Ikon ad="sag" boy={16} renk={C.dim} />
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          ))}


          {/* ============================================================
              HOST MOTIVASYONU (v2.43)

              🔴 KREDI BIR TESEKKURDUR, MOTIVASYON DEGIL. Elite Plus
              karti olan bir is insani ayda 3 kredi icin yabanci biriyle
              salona girmez.
              Gercek motivasyon: HAKKI COPE GIDIYOR. "8 hakkin kaldi"
              degil "8 hakkin bosa gidecek" — ayni sayi, farkli cumle,
              ve kayip kazanctan cok harekete gecirir.

              🔴 HACMI ODULLENDIRMIYORUZ. Rakip liderlik tablosu
              kullaniyor; bu, karti bir isletmeye cevirmeyi tesvik eder
              ve kart aglarinin kurallari tam bunu yasaklar. Uyeligi
              iptal olan host, kaybedilmis host'tur.
              ============================================================ */}
          {!!unused && unused.known && unused.left > 0 && (
            <View style={{ backgroundColor: C.goldBg, borderWidth: 1, borderColor: C.warmLine,
                           borderRadius: R.sm, padding: SP[3], marginBottom: ARA[10] }}>
              <Text style={{ fontSize: FS.base, fontWeight: "700", color: C.goldInk }}>
                {unused.headline}
              </Text>
              {!!unused.sub && (
                <Text style={{ fontSize: FS.sm, color: C.body, marginTop: SP[1], lineHeight: 18 }}>
                  {unused.sub}
                </Text>
              )}
              <Text style={{ fontSize: FS.xs, color: C.dim, marginTop: ARA[6] }}>{unused.note}</Text>
            </View>
          )}

          {/* v1.71 (Gokberk): büyük "Profili Düzenle" butonu KALDIRILDI —
              profil tamamlanma kartında zaten "Profili Tamamla →" var ve iki
              buton aynı yere gidiyordu. Diller ise BUTON GİBİ görünüp hiçbir
              şey yapmıyordu. Artık bio + diller TEK dokunulabilir blok ve
              sağ üstte ✎ var (Gokberk'in tercihi: düzenlenebilir alanda ✎). */}


          {/* 5 Eylül — "Bakiye" kartı kalktı: kredi banttaki şeritte (dokununca Cüzdan). */}

          {/* 🔴 v1.75 (Gokberk: "işaretlediğim alanlar fazlalık"): DOĞRULAMALAR
              listesi profilden KALDIRILDI — aynı bilgi hem "Güven Puanım"
              ekranında (puan dökümü olarak) hem de Profili Düzenle'nin
              "Doğrulama Durumu" bölümünde zaten var. Profil sayfası üç kez
              aynı şeyi anlatıyordu. Host'a olma yolu (misafir için) korunur;
              telefon doğrulama girişi Güven Puanım ekranından yapılır. */}
          {/* 🔴 v1.81 (Gokberk 1. madde: "host olmak istiyorum alanı hizasız"):
              v1.79'da DOĞRULAMALAR listesini kaldırırken kartın dış kabuğu
              yerinde kalmıştı — "host olmak istiyorum" kartı, boş bir kartın
              İÇİNDE kalıp diğer bloklardan içeride görünüyordu. Kabuk silindi. */}
          {/* 🔴 v2.66 (madde 4): "Host olmak istiyorum" kartı Profili
              Düzenle ekranına taşındı ve orada kurucu çember bilgilendirmesiyle
              birlikte yaşıyor. Profil vitrindir; başvuru bir form işidir. */}

          {/* Cikis — MVP'de menunun EN ALTINDA, kirmizi, tek yerde */}
          <TouchableOpacity hitSlop={TAP.slop}
            /* v6.3 · PANO H4 — çıkış KUTUSUZ, kiremit tonlu satır (yıkıcı eylem sessiz ama belli). */
            style={{ paddingVertical: ARA[14], paddingHorizontal: SP[4], marginTop: ARA[10], marginBottom: SP[2],
                     minHeight: TAP.minHeight, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}
            onPress={() => { setLogoutMsg(""); setConfirmOut(true); }}>
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              <Ikon ad="cikis" boy={19} renk={C.redInk} stil={{ marginRight: SP[3] }} kutu={22} />
              <Text style={{ color: C.redInk, fontWeight: "600", fontSize: FS.base }}>{t.logout2}</Text>
            </View>
            <Ikon ad="sag" boy={16} renk={C.redInk} />
          </TouchableOpacity>
          {!!logoutMsg && <View style={S.err}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{logoutMsg}</Text></View>}

          {/* Issue 6: çıkış onay popup'ı — evet/iptal */}
          <ConfirmModal
            visible={confirmOut}
            title={t.confirmLogout}
            body={t.logoutConfirmBody}
            confirmLabel={t.logout2}
            cancelLabel={t.confirmNo}
            danger
            onCancel={() => setConfirmOut(false)}
            onConfirm={async () => {
              setConfirmOut(false);
              // v2.50: onLogout artık zaman aşımlı ve her koşulda yerel
              // oturumu düşürüyor; buradaki ikinci signOut yalnız
              // onLogout hiç verilmediyse (Settings dışı kullanım) çalışır.
              if (onLogout) { const ok = await onLogout(); if (!ok) setLogoutMsg(t.logoutBlocked); return; }
              try {
                await Promise.race([supabase.auth.signOut(),
                  new Promise(res => setTimeout(res, 2500))]);
              } catch (e) {}
            }}
          />
    </Kaydirma>
    </>
  );
}
export function HostBroadcast({ t, session, onBack, onVerify, embedded, lang }) {
  const uid = session?.user?.id;
  const [avails, setAvails] = useState(null);
  const [sel, setSel] = useState(null);
  // 19 Eylül — `[]` değil `null`: "henüz okunmadı" ile "gerçekten boş"
  // aynı değer olamaz. Bu ayrım olmadan hata "kimse yok" diye okunuyordu.
  const [guests, setGuests] = useState(null);
  const [guestErr, setGuestErr] = useState(false);
  const [note, setNote] = useState("");
  const [verified, setVerified] = useState(true);
  const [busy, setBusy] = useState(null);
  const [err, setErr] = useState("");

  const load = useCallback(async () => {
    const [{ data: av }, { data: v }] = await Promise.all([
      supabase.from("availabilities").select("id, lounge_name, airport_code, avail_date, time_from, time_to, slots, filled, featured_until")
        .eq("host_id", uid).eq("active", true).gte("avail_date", yerelGun()).order("avail_date"),
      supabase.from("verifications").select("phone_verified").eq("user_id", uid).maybeSingle(),
    ]);
    setAvails(av || []);
    setVerified(v?.phone_verified ?? false);
    if (av?.length && !sel) setSel(av[0].id);
  }, [uid, sel]);
  useEffect(() => { load(); }, [load]);

  // ══════════════════════════════════════════════════════════════════
  // 🔴 19 EYLÜL · DERİN DENETİM — HATA, "KİMSE YOK"A DÖNÜŞÜYORDU.
  // Eski hâl: `setGuests(data || [])`. RPC patlayınca `data` null,
  // liste boş dizi oluyor ve ekran (aşağıda) `guests.length === 0`
  // görüp `t.bcNoGuests` — "davet edilebilecek misafir yok" — yazıyordu.
  // Host bunu okuyup ilanını kapatabilir; oysa yalnız bir ağ hatası var.
  // Aynı bileşende `avails` bunu DOĞRU yapıyor (`useState(null)` + Load).
  // 🆕 SINIF: "BİR HATAYI BOŞ LİSTEYE ÇEVİRİRSEN, KULLANICIYA 'HATA'
  // DEĞİL 'YOK' DERSİN — VE 'YOK' ÜZERİNE KARAR VERİLİR."
  // ══════════════════════════════════════════════════════════════════
  const misafirleriYukle = useCallback(async () => {
    if (!sel) return;
    const { data, error: hata4 } = await supabase.rpc("invitable_guests", { p_avail_id: sel });
    if (hata4) { logError("screens.js:invitable_guests", hata4); setGuestErr(true); setGuests(null); return; }
    setGuestErr(false);
    setGuests(data || []);
  }, [sel]);
  useEffect(() => { misafirleriYukle(); }, [misafirleriYukle]);

  async function feature() {
    setErr(""); setBusy("feat");
    const { error } = await supabase.rpc("set_featured", { p_avail_id: sel });
    setBusy(null);
    if (error) { const k = "e_" + (error.message || "").split(" ")[0].replace(/[^a-z_]/g, ""); return setErr(t[k] || mapErr(t, error.message)); }
    load();
  }

  async function invite(gid) {
    setErr(""); setBusy(gid);
    const { error } = await supabase.rpc("send_invite", { p_guest: gid, p_avail_id: sel, p_note: note });
    setBusy(null);
    if (error) { const k = "e_" + (error.message || "").split(" ")[0].replace(/[^a-z_]/g, ""); return setErr(t[k] || mapErr(t, error.message)); }
    misafirleriYukle();
  }

  if (avails === null) return <Load t={t} title={t.bcTitle} onBack={onBack} />;
  const cur = avails.find(a => a.id === sel);
  const isFeat = cur?.featured_until && new Date(cur.featured_until) > new Date();

  return (
    <Sayfa>
      {!embedded && <Hdr t={t} ustBilgi={t.sceneHost} title={t.bcTitle} onBack={onBack} />}
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[3] }}>{t.bcSub}</Text>

        {!verified && <PhoneGate t={t} onVerify={onVerify} />}

        {/* Öne Çıkan Yerleşim — MVP'de ilan olmasa da yapı görünür */}
        <View style={[S.card, { borderColor: isFeat ? C.gold : C.line, borderWidth: isFeat ? 1.5 : 1 }]}>
          <IkonMetin ad="degerlendirme" renk={C.ink} stilMetin={{ fontWeight: "700", color: C.ink, fontSize: FS.base }} metin={isFeat ? t.bcFeaturedOn : t.bcFeatured} />
          <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[1] }}>{t.bcFeaturedBody}</Text>
          {avails.length === 0 ? (
            <Text style={{ color: C.dim, fontSize: FS.sm, marginTop: SP[2], fontStyle: "italic" }}>{t.bcNeedAvail}</Text>
          ) : !isFeat ? (
            <Btn label={t.bcActivate} onPress={feature} disabled={!verified || busy === "feat"} busy={busy === "feat"} style={{ marginTop: ARA[10], opacity: verified ? 1 : 0.45 }} />
          ) : null}
        </View>

        {/* DOĞRUDAN DAVET — başlık her zaman görünür */}
        <Text style={S.label}>{t.bcInviteTitle}</Text>
        <Text style={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[2], lineHeight: 17 }}>{t.bcInviteBody}</Text>

        {avails.length === 0 ? (
          <View style={[S.card, { alignItems: "center", paddingVertical: ARA[22] }]}>
            <Ikon ad="kutlama" boy={FS.title} renk={C.mut} />
            <Text style={{ color: C.mut, fontSize: FS.sm, textAlign: "center", lineHeight: 18 }}>{t.bcNeedAvailInvite}</Text>
          </View>
        ) : (
          <>
            <Text style={S.label}>{t.bcSelectAv}</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[6] }}>
              {/* v1.71 (Gokberk: "hangi ilan için kısmı detaylandırılmalı —
                  birden fazla ilanım olabilir"): chip artık lounge adı, uzun
                  tarih, SAAT ARALIĞI ve KALAN SLOT gösteriyor. Dolu ilan
                  seçilemez (davet zaten sunucuda 'fully_booked' ile reddedilir;
                  kullanıcı bunu göndermeden ÖNCE görsün). */}
              {avails.map(a => {
                const left = Math.max(0, (a.slots || 0) - (a.filled || 0));
                const full = left === 0;
                const on = sel === a.id;
                return (
                <TouchableOpacity key={a.id} disabled={full} onPress={() => setSel(a.id)}
                  accessibilityRole="radio" accessibilityState={{ selected: on, disabled: full }}
                  style={[S.chip, { width: "100%", marginBottom: SP[2], opacity: full ? 0.5 : 1,
                    borderTopColor: on ? C.parlamaGuc : C.parlama, backgroundColor: on ? C.goldSoft : C.card }]}>
                  {/* v6 — seçim çizgiyle değil: altın nokta (konum kanalı) + aydınlık kadife (ışık kanalı) */}
                  <View style={{ flexDirection: "row", alignItems: "center" }}>
                    <View style={{ width: 6, height: 6, borderRadius: R.full, marginRight: ARA[8],
                                   backgroundColor: on ? C.gold : "transparent" }} />
                    <Text style={{ color: on ? C.gold : C.ink, fontSize: FS.sm, fontWeight: "600", letterSpacing: 0.2 }}>
                      {a.lounge_name || a.airport_code} · {a.airport_code}
                    </Text>
                  </View>
                  <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[2] }}>
                    {fmtLongDate(a.avail_date, lang)}
                    {a.time_from ? ` · ${String(a.time_from).slice(0,5)}–${String(a.time_to).slice(0,5)}` : ""}
                  </Text>
                  <Text style={{ color: full ? C.red : C.green, fontSize: FS.xs, fontWeight: "600", marginTop: ARA[2] }}>
                    {full ? t.slotFull : `${left} ${t.slotsOpen}`} · {a.filled}/{a.slots}
                  </Text>
                </TouchableOpacity>
                );
              })}
            </View>

            {/* MVP: "DAVET NOTU" etiketi + not girisi + secili slot satiri */}
            <Text style={S.label}>{t.bcNoteLabel}</Text>
            <TextInput style={S.input} value={note} onChangeText={x => setNote(x.slice(0, 140))}
              placeholder={t.bcNote} placeholderTextColor={C.mut} maxLength={140} multiline />
            <Text style={{ color: C.mut, fontSize: FS.xs, textAlign: "right", marginTop: -6, marginBottom: SP[1] }}>{note.length}/140</Text>
            {!!cur && (
              <IkonMetin ad="ucus" renk={C.mut} stilMetin={{ color: C.mut, fontSize: FS.sm, marginBottom: SP[2] }} metin={`${t.bcSlotLine}: ${cur.lounge_name || cur.airport_code} · ${cur.airport_code} · ${fmtLongDate(cur.avail_date, lang)}`} />
            )}

            {/* Üç durum, üç ayrı cevap (19 Eylül · derin denetim): */}
            {guestErr ? (
              <LoadFail t={t} onRetry={misafirleriYukle} />
            ) : guests === null ? (
              <View style={[S.card, { alignItems: "center", paddingVertical: ARA[20] }]}>
                <ActivityIndicator color={C.gold} />
              </View>
            ) : guests.length === 0 ? (
              <View style={[S.card, { alignItems: "center", paddingVertical: ARA[20] }]}>
                <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.bcNoGuests}</Text>
              </View>
            ) : guests.map(g => {
              const st = g.invite_status;
              return (
                <View key={g.guest_id} style={[S.card, { flexDirection: "row", alignItems: "center", justifyContent: "space-between" }]}>
                  <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                    <View style={{ width: 34, height: 34, borderRadius: R.full, backgroundColor: C.goldSoft, alignItems: "center", justifyContent: "center", overflow: "hidden", marginRight: SP[2] }}>
                      {g.photo ? <Image source={{ uri: g.photo }} style={{ width: 34, height: 34 }} />
                        : <Text style={{ fontWeight: "700", color: C.goldText }}>{(g.name || "?").charAt(0).toUpperCase()}</Text>}
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "600" }}>{g.name}</Text>
                      {/* MVP: "Fintech · 6 oturum" (SQL 075: profession + sessions_count) */}
                      {(g.profession || g.sessions_count != null) && (
                        <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: 0 }}>
                          {[g.profession, g.sessions_count != null ? `${g.sessions_count} ${t.sessionsWord}` : null].filter(Boolean).join(" · ")}
                        </Text>
                      )}
                    </View>
                  </View>
                  {st === "pending" ? <Text style={{ color: C.gold, fontSize: FS.sm, fontWeight: "700" }}>{t.bcInvited}</Text>
                    : st === "accepted" ? <Text style={{ color: C.green, fontSize: FS.sm, fontWeight: "700" }}>{t.bcAccepted}</Text>
                    : st === "declined" ? <Text style={{ color: C.mut, fontSize: FS.sm }}>{t.bcDeclined}</Text>
                    : <TouchableOpacity hitSlop={TAP.slop} disabled={!verified || busy === g.guest_id} onPress={() => invite(g.guest_id)}
                        style={{ backgroundColor: verified ? C.gold : C.line, borderRadius: R.xs, paddingHorizontal: ARA[14], paddingVertical: SP[2] }}>
                        {busy === g.guest_id ? <ActivityIndicator color="#fff" size="small" />
                          : <Text style={{ color: C.onAccent, fontWeight: "700", fontSize: FS.sm }}>{t.bcInvite}</Text>}
                      </TouchableOpacity>}
                </View>
              );
            })}
          </>
        )}
        {!!err && <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View>}
      </ScrollView>
    </Sayfa>
  );
}
export function Settings({ t, lang, setLang, session, onBack, onEditProfile, onVerify }) {
  // Görünüm tercihleri modül düzeyinde yaşıyor (tema `theme.js`te, sade
  // görünüm `atmosfer.js`te); ekran yalnız onların AYNASI.
  const [temaSec, setTemaSec] = React.useState(temaTercihi());
  const [sade, setSade] = React.useState(sadeGorunumMu());
  const [legalDoc, setLegalDoc] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);
  const [delBusy, setDelBusy] = useState(false);
  const [delErr, setDelErr] = useState("");   // v2.78: silme basarisizsa GORUNSUN
  const [me, setMe] = useState(null);
  const [prof, setProf] = useState(null);
  const [editor, setEditor] = useState(null);   // password | phone | email | visibility
  const [draft, setDraft] = useState("");
  const [draft2, setDraft2] = useState("");
  const [toast, setToast] = useState("");
  // 🔴 v2.99 — BU DÖRT ANAHTAR HİÇBİR YERE YAZMIYORDU.
  // Ölçüm: `notifs` yalnız iki yerde geçiyordu — bildirimi ve çizimi.
  // Ne sunucuya ne `AsyncStorage`a yazma vardı. Kullanıcı "Pazarlama
  // bildirimleri"ni kapatıyor, Ayarlar'dan çıkıp giriyor, TEKRAR AÇIK.
  // Üstelik `notify_push` (SQL 111) `notification_prefs` tablosunu okumaya
  // ÇALIŞIYOR ve tablo hiç oluşturulmadığı için "izin var" sayıyordu.
  // Yani kapatan kullanıcı bildirim almaya devam ediyordu.
  //
  // 🆕 SINIF: "YALAN SÖYLEYEN BİR VAZGEÇME ANAHTARI, OLMAYAN BİR
  // ANAHTARDAN KÖTÜDÜR — VE PAZARLAMA İZNİYSE HUKUKİ BİR MESELEDİR."
  //
  // SQL 254 tabloyu ve iki RPC'yi kurdu. Kapatılamaz kategoriler sunucudan
  // geliyor; istemci artık hangi anahtarın gerçek olduğunu UYDURMUYOR.
  const [notifPrefs, setNotifPrefs] = useState(null);
  const [notifKapat, setNotifKapat] = useState([]);
  const [notifNot, setNotifNot] = useState("");
  const [iletisimEposta, setIletisimEposta] = useState("");
  const [busy, setBusy] = useState(false);

  function flash(m) { setToast(m); setTimeout(() => setToast(""), 1800); }

  async function load() {
    const uid = session?.user?.id;
    if (!uid) return;
    // ══════════════════════════════════════════════════════════════════
    // 🔴 v3.4 — BU EKRAN BEŞ AĞ TURUNU SIRAYLA ATIYORDU.
    //
    // Gökberk: "APP tarafında da performans artışı yapmamız lazım."
    //
    // Beşi de birbirinden BAĞIMSIZDI: kullanıcı · profil · doğrulama ·
    // iletişim e-postası · bildirim tercihleri. Hiçbiri diğerinin
    // sonucunu kullanmıyor. Yani Ayarlar ekranı, bir turun beş katı
    // kadar bekliyordu — sebepsiz.
    //
    // 🆕 SINIF: "SIRALI YAZILMIŞ HER BAĞIMSIZ SORGU, KULLANICIYA
    // KENDİ SÜRESİNİ AYRICA ÖDETİR — BAĞIMLILIK YOKSA SIRA DA OLMAMALI."
    //
    // Beşi tek dalgada. `Promise.all` biri düşerse hepsini düşürür;
    // burada bu DOĞRU davranış — hata zaten aşağıda tek tek okunuyor
    // ve ekran eksik veriyle çizilmemeli.
    // 🔵 `contact_email` ARTIK `profiles` ÜZERİNDE DEĞİL (SQL 253 §5b):
    // `profiles` tasarımı gereği başkaları tarafından okunuyor; bir e-posta
    // adresi orada duramazdı. Kendi tablosunda, yalnız sahibine açık.
    const [
      { data: u },
      { data: p },
      { data: v },
      { data: ep, error: epErr },
      { data: np, error: npErr },
    ] = await Promise.all([
      supabase.from("users").select("email, phone, gender").eq("id", uid).maybeSingle(),
      supabase.from("profiles")
        .select("profile_visibility, show_on_discovery, location_sharing, women_safety_mode, photo_connections_only")
        .eq("user_id", uid).maybeSingle(),
      supabase.from("verifications").select("phone_verified").eq("user_id", uid).maybeSingle(),
      supabase.rpc("iletisim_epostam"),
      supabase.rpc("bildirim_tercihlerim"),
    ]);
    setMe({ ...u, phone_verified: v?.phone_verified });
    setProf(p || {});
    if (epErr) logError("iletisim_epostam", epErr); else setIletisimEposta(ep || "");
    if (npErr) { logError("bildirim_tercihlerim", npErr); }
    else if (np) {
      setNotifPrefs(np.tercihler || {});
      setNotifKapat(Array.isArray(np.kapatilabilir) ? np.kapatilabilir : []);
      setNotifNot(np.kapatilamaz_not || "");
    }
  }

  // Tek yazma yolu RPC: istemcinin doğrudan yazabildiği bir tercih,
  // tercih değil beyandır (SQL 254 `notification_prefs` yazmaya kapalı).
  async function notifYaz(kategori, acik) {
    setNotifPrefs(x => ({ ...(x || {}), [kategori]: { push: acik } }));   // iyimser
    const { data, error } = await supabase.rpc("bildirim_tercihi_yaz",
      { p_kategori: kategori, p_push: acik });
    if (error || (data && data.ok === false)) {
      logError("bildirim_tercihi_yaz", error || data);
      flash(t.stSaveFail); load();
    }
  }
  useEffect(() => { load(); }, [session]);

  async function patch(fields) {
    const uid = session?.user?.id;
    setProf(p => ({ ...p, ...fields }));   // iyimser
    // 🔴 23 Eylül — "Keşifte görün" anahtarı her dokunuşta "kaydedilemedi"
    // deyip geri zıplıyordu: `show_on_discovery` 253 §5'ten beri istemciye
    // kapalı (ölçüldü: has_column_privilege → f). O alan kendi kapısından
    // (SQL 300 §A4) gider; kalan alanlar eskisi gibi doğrudan.
    const { show_on_discovery, ...kalan } = fields;
    const isler = [];
    if (show_on_discovery !== undefined) isler.push(supabase.rpc("kesifte_gorun", { p_acik: !!show_on_discovery }));
    if (Object.keys(kalan).length) isler.push(supabase.from("profiles").update(kalan).eq("user_id", uid));
    const sonuc = await Promise.all(isler);
    if (sonuc.some(r => r && r.error)) { flash(t.stSaveFail); load(); }
  }

  async function savePassword() {
    if (draft.length < 8) { flash(t.stPwTooShort); return; }
    if (draft !== draft2) { flash(t.stPwMismatch); return; }
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: draft });
    setBusy(false);
    // 🔴 23 Eylül — Supabase'in İngilizce metni ("New password should be
    // different from the old password.") doğrudan ekrana basılıyordu.
    if (error) {
      const m = String(error.message || "");
      flash(/different from the old password|same_password/i.test(m) ? t.stPwSame
        : /at least|weak_password|too short/i.test(m) ? t.stPwTooShort
        : mapErr(t, m));
      return;
    }
    setEditor(null); flash(t.stPwDone);
  }

  async function savePhone() {
    if (!draft.trim()) return;
    setBusy(true);
    const { error } = await supabase.rpc("change_phone", { p_phone: draft.trim() });
    setBusy(false);
    if (error) { flash(mapErr(t, error.message)); return; }
    setEditor(null); flash(t.stPhoneDone);
    load();
  }

  async function saveEmailField() {
    if (!/.+@.+\..+/.test(draft)) { flash(t.stEmailBad); return; }
    // 🔵 `profiles`a değil kendi tablosuna (SQL 253 §5b).
    // Ad kaynağını söylüyor: `r` deseydim nöbetçi dosyadaki BÜTÜN `r.` 
    // erişimlerini bu RPC'ye bağlardı (nitekim bağladı, üç yanlış alarm).
    const { data: epYaz, error: epHata } = await supabase.rpc("iletisim_epostam_yaz", { p_eposta: draft.trim() });
    if (epHata || (epYaz && epYaz.ok === false)) { logError("iletisim_epostam_yaz", epHata || epYaz); flash(t.stSaveFail); return; }
    setIletisimEposta(draft.trim());
    setEditor(null); flash(t.stEmailDone);
  }

  const VIS = ["Everyone", "Trusted+", "Connections"];
  // Anahtarlar SUNUCU değerleri (değişmez); etiketler i18n'den gelir.
  // 23 Eylül — "Trusted+" veritabanı değeri; ekranda Türkçe karşılığı yazılır.
  const VIS_TR = { Everyone: t.stVisEveryone, "Trusted+": t.stVisTrusted, Connections: t.stVisConnections };

  // 🔴 v2.65 · İKİZ BİLEŞEN KALDIRILDI.
  // Burada Toggle ve Row'un YEREL kopyaları vardı (ui.js'te de var,
  // screens.js:3301/3287'de de). Üç kopya, üç ayrı API. Sonuç: ui.js'e
  // yazılan erişilebilirlik ve dokunma-hedefi düzeltmeleri bu ekrana
  // HİÇ ULAŞMIYORDU. Yerel Toggle silindi; ui.js'inki (Toggle) sarmalayıcı
  // ile kullanılıyor. Row yerel kaldı ÇÜNKÜ farklı bir sözleşmesi var
  // (sub + right), ama artık 44px dokunma hedefi ve a11y rolü taşıyor.
  function SwitchCell({ on, onPress, color = C.teal, disabled, a11yLabel }) {
    return <Toggle val={on} onChange={onPress} disabled={disabled} a11yLabel={a11yLabel} />;
  }

  function Row({ label, sub, right, onPress }) {
    return (
      <TouchableOpacity disabled={!onPress} onPress={onPress} activeOpacity={onPress ? 0.6 : 1}
        accessibilityRole={onPress ? "button" : undefined}
        accessibilityLabel={onPress && typeof label === "string" ? label : undefined}
        style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: TAP.minHeight,
                 borderBottomWidth: 1, borderBottomColor: C.line,
                 flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: FS.sm, color: C.body }}>{label}</Text>
          {sub ? <Text style={{ fontSize: FS.micro, color: C.dimAA, marginTop: 0 }}>{sub}</Text> : null}
        </View>
        <View style={{ flexDirection: "row", alignItems: "center" }}>{right}</View>
      </TouchableOpacity>
    );
  }

  const Head = ({ children }) => (
    <Text style={{ fontSize: FS.micro, fontWeight: "600", color: C.mutedAA, letterSpacing: 2, marginBottom: SP[2], marginTop: SP[1] }}>{children}</Text>
  );

  if (!me) return <View style={{ flex: 1, backgroundColor: C.bg, alignItems: "center", justifyContent: "center" }}><ActivityIndicator color={C.gold} /></View>;

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneAccount} title={t.settingsTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: ARA[14], paddingBottom: ARA[40] }}>
        <Head>{t.stAccount}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          <Row label={t.stEditProfile} right={<Ikon ad="sag" boy={FS.sm} renk={C.tealInk} />} onPress={onEditProfile} />
          <Row label={t.stChangePw} right={<Text style={{ color: C.tealInk, fontSize: FS.sm }}>••••••••</Text>}
            onPress={() => { setEditor("password"); setDraft(""); setDraft2(""); }} />
          {/* 🔴 v2.65 — "DOĞRULANMADI" bir YARGIYDI (ve fontSize: FS.micro ile ölçek
              dışıydı). Rozet yargılamaz, bilgi verir: "Doğrulamayı bekliyor".
              Üstelik artık ÇALIŞIYOR — dokununca doğrulama akışı açılıyor
              (onVerify buraya kadar geliyordu ama hiç okunmuyordu). */}
          <Row label={t.stPhone}
            right={<>
              {/* 23 Eylül — "Ayarlanmadı ✓": eksik bir alan başarı rengi ve onay
                  işaretiyle çiziliyordu (numara yokken bile doğrulama bayrağı
                  işareti basıyordu). Numara yoksa nötr metin, işaret yok.
                  v6.x birleştirme: numara yok ama doğrulanmışsa "Doğrulandı". */}
              <Text style={{ fontSize: FS.sm, color: (me.phone || me.phone_verified) ? C.tealInk : C.mut, fontWeight: "600" }}>{me.phone || (me.phone_verified ? t.hwVerified : t.stPhoneUnset)}</Text>
              {!me.phone && !me.phone_verified ? null
                : me.phone_verified
                ? <Ikon ad="tamam" boy={FS.xs} renk={C.greenInk} />
                : <ToneBadge tone="unknown" style={{ marginLeft: ARA[6] }}>{t.phoneNotYetVerified}</ToneBadge>}
            </>}
            onPress={() => { if (!me.phone_verified && onVerify) return onVerify();
                             setEditor("phone"); setDraft(me.phone || ""); }} />
          <Row label={t.stContactEmail} right={<Text style={{ fontSize: FS.sm, color: C.teal, fontWeight: "600" }} numberOfLines={1}>{iletisimEposta || me.email}</Text>}
            onPress={() => { setEditor("email"); setDraft(iletisimEposta || me.email); }} />
        </View>

        <Head>{t.stPrivacy}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          <Row label={t.stVisibility} right={<Text style={{ fontSize: FS.sm, color: C.tealInk, fontWeight: "600" }}>{VIS_TR[prof?.profile_visibility] || t.stVisTrusted}</Text>}
            onPress={() => setEditor("visibility")} />
          <Row label={t.stShowDiscovery} right={<SwitchCell a11yLabel={t.stShowDiscovery} on={prof?.show_on_discovery !== false} onPress={() => patch({ show_on_discovery: !(prof?.show_on_discovery !== false) })} />} />
          <Row label={t.stLocation} sub={t.stLocationSub}
            right={<SwitchCell a11yLabel={t.stLocation} on={!!prof?.location_sharing} onPress={() => patch({ location_sharing: !prof?.location_sharing })} />} />
          <Row label={t.stPhotoConns}
            right={<SwitchCell a11yLabel={t.stPhotoConns} on={!!prof?.photo_connections_only} onPress={() => patch({ photo_connections_only: !prof?.photo_connections_only })} />} />
          {me.gender === "female" && (
            <Row label={t.stWomenMode} sub={t.stWomenModeSub}
              right={<SwitchCell a11yLabel={t.stWomenMode} on={!!prof?.women_safety_mode} color={C.purple} onPress={() => patch({ women_safety_mode: !prof?.women_safety_mode })} />} />
          )}
        </View>

        <Head>{t.stNotifs}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          {/* Kategoriler ve hangisinin kapatılabildiği SUNUCUDAN geliyor.
              İstemcide sabit bir liste tutmak, sunucunun gerçekten
              uyguladığı kuralla ayrışmaya açık bir ikinci gerçek olurdu. */}
          {[["requests", t.stNotifRequests], ["sessions", t.stNotifSessions],
            ["credits", t.stNotifPoints], ["system", t.stNotifMarketing],
            ["connections", t.stNotifConnections], ["ratings", t.stNotifRatings]].map(([k, l]) => {
            const kapatilabilir = notifKapat.indexOf(k) >= 0;
            const acik = !(notifPrefs && notifPrefs[k] && notifPrefs[k].push === false);
            return (
              <Row key={k} label={l} sub={kapatilabilir ? null : t.stNotifLocked}
                right={<SwitchCell a11yLabel={l} on={acik} color={C.gold} disabled={!kapatilabilir}
                  onPress={() => notifYaz(k, !acik)} />} />
            );
          })}
          {!!notifNot && (
            <View style={{ padding: SP[3], borderTopWidth: 1, borderTopColor: C.line }}>
              <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 16 }}>{notifNot}</Text>
            </View>
          )}
        </View>

        <Head>{t.stApp}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          <Row label={t.stAppLang} right={
            <View style={{ flexDirection: "row", borderWidth: 1, borderColor: C.gold, borderRadius: R.md, overflow: "hidden" }}>
              {["tr", "en"].map(l => (
                <TouchableOpacity key={l} onPress={() => setLang(l)}
                  accessibilityRole="button" accessibilityLabel={BUYUK(l)}
                  accessibilityState={{ selected: lang === l }}
                  style={{ paddingHorizontal: ARA[14], minHeight: TAP.minHeight, justifyContent: "center",
                           backgroundColor: lang === l ? C.goldBtn : "transparent" }}>
                  <Text style={{ fontSize: FS.xs, fontWeight: "600", color: lang === l ? "#fff" : C.goldText }}>{l.toUpperCase()}</Text>
                </TouchableOpacity>
              ))}
            </View>
          } />
        </View>

        {/* ── GÖRÜNÜM ────────────────────────────────────────────────
            🔴 İKİ TERCİH DE VARDI, İKİSİNİN DE ARAYÜZÜ YOKTU.
            `sadeGorunumYaz` (sade görünüm) `atmosfer.js`te yazılıydı ve
            HİÇBİR ekrandan çağrılmıyordu — yani kod vardı, özellik yoktu.
            Koyu tema da aynı durumdaydı: palet hazır, anahtar yok.
            Bir tercihi saklamak, kullanıcıya sunmakla aynı şey değil.

            🆕 SINIF: "BİR AYARI OKUYAN VE YAZAN KOD YAZDIYSAN AMA ONU
            DEĞİŞTİRECEK BİR YÜZEY KOYMADIYSAN, O AYAR YOK." */}
        <Head>{t.stGorunum}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          {/* 🔴 6. tur — TEMA SEÇİCİ KALDIRILDI (arşiv: _yedek_acik_tema/).
              Üç seçenek vardı: Sistem · Açık · Koyu. Ama açık tema gece
              sistemine göre hiç yeniden tasarlanmadı — yani iki seçenek
              kullanıcıyı TASARLANMAMIŞ bir ürüne götürüyordu.
              Bir ayarı sunmak, arkasındaki şeyin hazır olduğunu VAAT
              ETMEKTİR. Hazır değilse ayar bir seçenek değil bir tuzaktır.
              (`tema_tercih.js` artık tek tema döndürüyor.) */}
          <Row label={t.stSade} sub={t.stSadeSub}
            right={<SwitchCell a11yLabel={t.stSade} on={sade}
              onPress={() => { const y = !sade; setSade(y); sadeGorunumYaz(y); }} />} />
        </View>

        {/* v1.72: sözleşmeler Ayarlar'dan da erişilebilir (giriş sonrası
            kullanıcı bunları tekrar okuyabilmeli — KVKK şeffaflık ilkesi) */}
        <Head>{BUYUK(t.legalTitle)}</Head>
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          {LEGAL_ORDER.map(k => (
            <TouchableOpacity key={k} onPress={() => setLegalDoc(k)}
              accessibilityRole="button" accessibilityLabel={LEGAL_DOCS[k].title}
              style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: TAP.minHeight, flexDirection: "row", justifyContent: "space-between", alignItems: "center", borderTopWidth: k === LEGAL_ORDER[0] ? 0 : 1, borderColor: C.line }}>
              <Text style={{ fontSize: FS.sm, color: C.ink }}>{LEGAL_DOCS[k].title}</Text>
              <Ikon ad="sag" boy={FS.base} renk={C.dimAA} />
            </TouchableOpacity>
          ))}
        </View>

        <Head>{t.stDanger}</Head>
        {/* #22: Cikis Yap KALDIRILDI (Profil'de zaten var); Hesabi Sil onay ister */}
        {!!delErr && (
          <View style={{ backgroundColor: C.redBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.xs, padding: SP[3], marginBottom: ARA[10] }}>
            <Text style={{ color: C.redInk, fontSize: FS.sm, lineHeight: 18 }}>
              {t.deleteFailed} {delErr}
            </Text>
          </View>
        )}
        <View style={{ backgroundColor: C.card, borderRadius: R.sm, borderWidth: 1, borderColor: C.line, marginBottom: SP[4], overflow: "hidden" , ...ELEV.card }}>
          <TouchableOpacity onPress={() => { setDelErr(""); setConfirmDel(true); }}
            accessibilityRole="button" accessibilityLabel={t.stDeleteAccount}
            style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: TAP.minHeight, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
            <Text style={{ fontSize: FS.sm, color: C.redInk }}>{t.stDeleteAccount}</Text>
            <Ikon ad="sag" boy={FS.base} renk={C.redInk} />
          </TouchableOpacity>
        </View>
        <ConfirmModal
          visible={confirmDel}
          title={t.confirmDelete}
          body={t.deleteAccountBody}
          confirmLabel={t.confirmYes}
          cancelLabel={t.confirmNo}
          danger
          busy={delBusy}
          onCancel={() => setConfirmDel(false)}
          onConfirm={async () => {
            setDelBusy(true);
            // 🔴 v2.78 — SESSİZ SİLME. Önceki hâli:
            //     try { await supabase.rpc("delete_my_account"); } catch (e) {}
            //     await supabase.auth.signOut();
            // İki ayrı kusur vardı. (1) `supabase.rpc()` Postgres hatasında
            // REJECT ETMEZ — `{data, error}` ile resolve eder. Yani bu
            // `try/catch` Postgres hatasını HİÇ görmüyordu, yalnız ağ
            // istisnasını. (2) Sonuç ne olursa olsun koşulsuz `signOut`:
            // kullanıcı "hesabım silindi" sanıyor, `users.deleted_at`
            // yazılmamış oluyor. Silme hakkı (KVKK) açısından da yanlış.
            const { error: silErr } = await supabase.rpc("delete_my_account");
            setDelBusy(false);
            if (silErr) { setDelErr(mapErr(t, silErr.message)); return; }
            await supabase.auth.signOut();
          }}
        />
      </ScrollView>

      {/* v1.72: Ayarlar'dan açılan sözleşme metni */}
      {!!legalDoc && (
        <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: C.paper }}>
          <LegalDoc t={t} docKey={legalDoc} onBack={() => setLegalDoc(null)} onOpen={setLegalDoc} />
        </View>
      )}

      {/* Editor modal — MVP'deki gibi */}
      {editor && (
        <TouchableOpacity activeOpacity={1} onPress={() => setEditor(null)}
          style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, alignItems: "center", justifyContent: "center", padding: ARA[20] }}>
          {/* v6.1 (md.4) — Ayarlar editörü de bulanık perde + ışık kenarlı popup. */}
          <PerdeBulanik />
          <TouchableOpacity activeOpacity={1} onPress={() => {}}
            style={{ ...POPUP_YUZEY(), borderRadius: R.md, padding: ARA[18], width: "100%", maxWidth: 340 }}>
            {editor === "password" && <>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[3] }}>{t.stChangePw}</Text>
              <TextInput secureTextEntry placeholder={t.stPwPlaceholder} value={draft} onChangeText={setDraft} placeholderTextColor={C.dimAA}
                style={[S.input, { marginBottom: SP[2] }]} />
              <TextInput secureTextEntry placeholder={t.stPwRepeat} value={draft2} onChangeText={setDraft2} placeholderTextColor={C.dimAA}
                style={[S.input, { marginBottom: SP[3] }]} />
              <Btn v="gold" sm label={busy ? "…" : t.stPwSave} onPress={savePassword} disabled={busy} a11yLabel={t.stPwSave} />
            </>}
            {editor === "phone" && <>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[1] }}>{t.stPhoneEdit}</Text>
              <Text style={{ fontSize: FS.xs, color: C.mutedAA, marginBottom: SP[3] }}>{t.stPhoneEditSub}</Text>
              <TextInput keyboardType="phone-pad" placeholder="+90 5xx xxx xx xx" value={draft} onChangeText={setDraft} placeholderTextColor={C.dimAA}
                style={[S.input, { marginBottom: SP[3] }]} />
              <Btn v="gold" sm label={busy ? "…" : t.stPhoneSave} onPress={savePhone} disabled={busy} a11yLabel={t.stPhoneSave} />
            </>}
            {editor === "email" && <>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[1] }}>{t.stContactEmail}</Text>
              <Text style={{ fontSize: FS.xs, color: C.mutedAA, marginBottom: SP[3] }}>{t.stEmailSub}</Text>
              <TextInput keyboardType="email-address" autoCapitalize="none" placeholder="email@example.com" value={draft} onChangeText={setDraft} placeholderTextColor={C.dimAA}
                style={[S.input, { marginBottom: SP[3] }]} />
              <Btn v="gold" sm label={t.stEmailSave} onPress={saveEmailField} a11yLabel={t.stEmailSave} />
            </>}
            {editor === "visibility" && <>
              <Text style={{ fontSize: FS.lg, fontWeight: "700", color: C.ink, marginBottom: SP[3] }}>{t.stVisibility}</Text>
              {VIS.map(o => {
                const sel = (prof?.profile_visibility || "Trusted+") === o;
                return (
                  <Secim key={o} bicim="radyo" ton="teal" zemin="alt" secili={sel} etiket={VIS_TR[o]}
                    stil={{ marginBottom: SP[2] }}
                    onPress={() => { patch({ profile_visibility: o }); setEditor(null); flash(t.stVisFlash + VIS_TR[o]); }} />
                );
              })}
            </>}
            <TouchableOpacity onPress={() => setEditor(null)} accessibilityRole="button" accessibilityLabel={t.cancel}
              style={{ marginTop: ARA[6], padding: ARA[6], minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center" }}>
              <Text style={{ color: C.mutedAA, fontSize: FS.sm }}>{t.cancel}</Text>
            </TouchableOpacity>
          </TouchableOpacity>
        </TouchableOpacity>
      )}

      {toast ? (
        <View style={{ position: "absolute", bottom: 30, alignSelf: "center", backgroundColor: C.gece, paddingHorizontal: SP[4], paddingVertical: SP[2], borderRadius: R.md }}>
          <Text style={{ color: C.onAccent, fontSize: FS.sm }}>{toast}</Text>
        </View>
      ) : null}
    </Sayfa>
  );
}
export function AddVisit({ t, session, onBack, onDone, suggest }) {
  const uid = session?.user?.id;
  const [airports, setAirports] = useState([]);
  // v2.48 — Keşfet'ten bir İLAN için gelindiyse form ilana UYGUN başlar
  // (havalimanı/tarih/saat penceresi); uçuş no kullanıcının kendi uçuşudur.
  const [f, setF] = useState({
    airport: suggest?.airport_code || "", destination: "",
    date: suggest?.avail_date || "",
    from: String(suggest?.time_from || "14:00").slice(0, 5),
    to: String(suggest?.time_to || "18:00").slice(0, 5),
    // 🔴 v2.79 — `purpose: "business"` İDİ VE BU BİR BEYAN UYDURMASIYDI.
    // Çipe hiç dokunmayan kullanıcının seyahati "iş amaçlı" olarak
    // kaydediliyordu. Sağlayıcı ekranı (Ö9) bu kolonu "beyan eden: %N"
    // diye yayımlıyor — ön seçili bir varsayılan, o oranı olduğundan
    // yüksek ve YANLIŞ gösterirdi. Amaç isteğe bağlı (SQL 132); boş
    // başlar, dokunulursa beyan olur.
    flight: "", carrier: "", purpose: "", kisi: 1, cocuk: [] });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [adim, setAdim] = useState(1);   // v6.3 · seyahat sihirbazı (1 uçuş · 2 zaman · 3 amaç)
  // 🔴 v2.89 (Gökberk md.11) — `suggest` YALNIZ İLK MOUNT'TA okunuyordu.
  // Ekran overlay olarak açık kalıp `suggest` sonradan değişirse (başka
  // bir ilandan "Seyahat ekle") form ESKİ ilanın verisiyle kalıyordu —
  // yani kullanıcı yanlış tarihe başvuruyordu. Şimdi senkronize.
  useEffect(() => {
    if (!suggest) return;
    setF(prev => ({
      ...prev,
      airport: suggest.airport_code || prev.airport,
      date: suggest.avail_date || prev.date,
      from: String(suggest.time_from || prev.from || "14:00").slice(0, 5),
      to: String(suggest.time_to || prev.to || "18:00").slice(0, 5),
    }));
  }, [suggest?.id, suggest?.airport_code, suggest?.avail_date, suggest?.time_from, suggest?.time_to]);

  // 🔴 v2.79 — HAVAYOLU LİSTESİ BU EKRANDA HİÇ YOKTU.
  // Gökberk "iki havayolu alanı var, çipi kaldır" dedi. Ölçtüğümde bu
  // ÜÇÜNCÜ ekranda yalnız ÇİP olduğu çıktı — talimatı harfiyen
  // uygulasaydım seyahat ekleme ekranı havayolu seçicisiz kalırdı.
  // Yani dört çipin dışındaki hiçbir havayolu seçilemiyordu; "Diğer"e
  // basan kullanıcı taşıyıcıyı BOŞ bırakıyordu ve kural motoru
  // "misafir aynı havayolunda mı" sorusunu yanıtsız alıyordu.
  const [carriers, setCarriers] = useState([]);

  useEffect(() => {
    (async () => {
      // 🔴 v3.4 — ÖNBELLEKTEN. `katalog.js` hatayı yutmuyor: ağ düşerse
      // ESKİ listeyi döndürüyor, boş liste değil — boş liste kullanıcıya
      // "havalimanı yok" der ve bu yanlış bilgidir.
      setAirports(await havalimanlariniGetir());
      // 🔴 HATA YUTULMUYOR. İlk yazımda `const { data: cs }` yazdım ve
      // `node check.js` beni yakaladı: "errorSwallow — 79 bulgu, tavan 78".
      // Havayolu listesi düşerse seçici BOŞ görünür ve kullanıcı
      // "havayolum yok" sanır; sessiz boş liste bu projede en pahalı
      // hata sınıfı. Tavanı ben yükseltmiyorum, ihlali kaldırıyorum.
      setCarriers(await carrierlariGetir());
    })();
  }, []);

  const set = (k, v) => setF(x => ({ ...x, [k]: v }));

  async function save() {
    if (!f.airport) { setErr(t.avPickAirport); return; }
    if (f.date.length !== 10) { setErr(t.avFixDate); return; }
    setBusy(true); setErr("");
    // GERCEK SEMA (001): tablo `visits` — `trips` diye bir tablo YOK.
    // purpose kolonu 044'te eklendi; artik cip secimi GERCEKTEN kaydediliyor
    // ve Tanis'ta "ikimiz de is icin buradayiz" eslesmesinde kullaniliyor.
    // v2.96 (C3): doğrudan tablo yazımı yerine `seyahat_ekle` — doğrulama
    // ve çakışma kuralı artık sunucuda, istemcinin iyi niyetinde değil.
    const { error } = await supabase.rpc("seyahat_ekle", {
      p_airport: f.airport,
      p_destination: f.destination || null,
      p_date: f.date, p_from: f.from + ":00", p_to: f.to + ":00",
      p_flight: f.flight.trim() || null,
      p_carrier: f.carrier || null,
      p_purpose: f.purpose || null,
      p_kisi: Number(f.kisi) || 1,
      p_cocuk_yas: (f.cocuk || []).length ? f.cocuk : null,
    });
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    if (onDone) onDone();
    onBack();
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.scenePlan} title={t.addVisitTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        <Text style={{ fontSize: FS.sm, color: C.mutedAA, marginBottom: SP[4], lineHeight: 19 }}>
          {t.avIntro}
        </Text>
        {/* 🔴 v2.89 (Gökberk md.11) — ÖN DOLDURMA SESSİZ OLMAMALI.
            Form kendiliğinden dolmuşsa kullanıcı ya fark etmez ya da
            "bu nereden geldi?" der. İkisi de kötü: ilki yanlış veriyi
            onaylatır, ikincisi güveni sarsar. */}
        {suggest ? (
          <View style={{ backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent",
                         borderRadius: R.xs, padding: ARA[10], marginTop: SP[2] }}>
            <Text style={{ color: C.tealInk, fontSize: FS.sm, lineHeight: 18 }}>{t.tripPrefilled}</Text>
          </View>
        ) : null}

        <SihirbazBasi t={t} adim={adim} setAdim={setAdim} />
        <SeyahatFormu t={t} f={f} set={set} airports={airports} carriers={carriers} kilitli={false} mod="ekle" adim={adim} />

        {!!err && <View style={{ backgroundColor: C.redBg, borderRadius: R.xs, padding: SP[3], marginBottom: SP[3] }}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}

        {/* md.12 — bu ekranın işi YENİ seyahat oluşturmak (`mod="ekle"`);
            "Kaydet" bir düzenlemeyi çağrıştırıyor. */}
        <SihirbazAlti t={t} adim={adim} setAdim={setAdim} setErr={setErr} f={f} busy={busy}
          sonEtiket={busy ? t.avSaving : t.wzSaveTrip} onSon={save} />
      </ScrollView>
    </Sayfa>
  );
}
export function EditAvailability({ t, avail, onBack, onDone }) {
  const [kabul, setKabul] = useState(null);      // null = sayılıyor
  const [f, setF] = useState({
    date: String(avail?.avail_date || ""),
    from: String(avail?.time_from || "").slice(0, 5),
    to: String(avail?.time_to || "").slice(0, 5),
    slots: Number(avail?.slots ?? 1),
    flight: String(avail?.flight_number || ""),
    lounge_id: String(avail?.lounge_id || ""),
    visibility: avail?.visibility === "Hidden" ? "hidden"
              : avail?.visibility === "Connections" ? "connections"
              : (Number(avail?.min_trust || 0) >= 55 ? "trusted" : "all"),
  });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [adim, setAdim] = useState(1);   // v6.3 · ilan düzenleme de sihirbaz (adımlar serbest)
  const [esik, setEsik] = useState(Number(avail?.min_trust ?? 0));
  const [yogunluk, setYogunluk] = useState(null);
  const [lounges, setLounges] = useState([]);
  const [loungeErr, setLoungeErr] = useState("");
  const [carriers, setCarriers] = useState([]);
  const [carrier, setCarrier] = useState(avail?.carrier || null);
  const [cabin, setCabin] = useState(avail?.cabin_class || null);
  const [charter, setCharter] = useState(!!avail?.is_charter);
  const [cap, setCap] = useState(null);
  // 🔴 v2.96 (eleştiri B2) — KABİN SORUSU ARTIK KOŞULLU.
  // Gökberk sordu: "kabin dediğin ne?" Kabin = HOST'UN KENDİ BİLETİNİN
  // SINIFI (Ekonomi/Business/First). THY'nin resmî kuralı: Business
  // BİLETİ salona sokar ama MİSAFİR HAKKI VERMEZ (o hak kart tipinden
  // gelir); First ise Business bölümünde bir misafir hakkı verir.
  // Yani Business'ta uçan bir host "misafir götürebilirim" diye ilan
  // açarsa misafir kapıda kalır. Soru tam olarak bunu önlüyor.
  //
  // AMA ölçtüm: 329 salonun yalnız 13'ünde kabin kuralı var ve 15
  // kuralın 14'ü aynı kuralın salon salon tekrarı. Soruyu her ilanda
  // sormak %96 gürültü; silmek ise kalan %4'te misafiri kapıda bırakmak.
  // 🆕 SINIF: "BİR SORUYU HERKESE SORMAK İLE HİÇ SORMAMAK ARASINDA ÜÇÜNCÜ
  // BİR SEÇENEK VAR: CEVABIN BİR ŞEYİ DEĞİŞTİRDİĞİ YERDE SORMAK."
  const [kabinSor, setKabinSor] = useState(null);   // null = henüz ölçülmedi

  // Salon değişince kabin sorusunun gerekip gerekmediğini SUNUCUYA sor.
  useEffect(() => {
    let iptal = false;
    (async () => {
      const lid = f.lounge_id;
      if (!lid) { if (!iptal) setKabinSor(null); return; }
      const { data, error } = await supabase.rpc("kabin_sorulmali_mi", { p_lounge_id: lid });
      if (error) { logError("kabin_sorulmali_mi", error); if (!iptal) setKabinSor(true); return; }
      // 🔴 HATA DURUMUNDA SORUYU GÖSTERİYORUZ, GİZLEMİYORUZ. Ölçemediğimiz
      // bir durumda soruyu saklamak, kuralı sessizce devre dışı bırakmak
      // olurdu; fazladan bir soru sormak ise yalnız bir soru.
      if (!iptal) setKabinSor(!!(data && data.sor));
    })();
    return () => { iptal = true; };
  }, [f.lounge_id]);

  // Salon listesi + havayolu kataloğu + beyan edilen kapasite.
  // "Müsaitlik ekle" ekranı bunların üçünü de çekiyor; düzenleme ekranı
  // hiçbirini çekmiyordu — alanların olmamasının sebebi de buydu.
  useEffect(() => {
    let iptal = false;
    (async () => {
      const ap = avail?.airport_code;
      if (ap) {
        // 🔴 DEĞİŞKEN ADI `lg` YAZMIŞTIM — `rpc_field_e2e` NÖBETÇİSİ YAKALADI.
        // Aynı dosyada HostAvailability içinde `lg` adı DÜZ TABLO
        // sorgusundan (`lounges.venue_id`) geliyor. Nöbetçi RPC sonucunu
        // değişken ADIYLA izlediği için ikisini karıştırdı ve doğru bir
        // satırı hatalı bildirdi.
        // 🆕 SINIF: "BİR DEĞİŞKEN ADI YALNIZ İNSANA DEĞİL, KAYNAĞI ADLA
        // İZLEYEN NÖBETÇİYE DE BİLDİRİMDİR — AYNI ADI İKİ FARKLI KAYNAĞA
        // VERMEK ÖLÇÜMÜ BOZAR."
        const { data: salonlar, error: e1 } = await supabase.rpc("lounges_for_airport", { p_airport: ap });
        if (e1) { logError("lounges_for_airport", e1); if (!iptal) setLoungeErr(String(e1.message || "")); }
        else if (!iptal) setLounges(salonlar || []);
      }
      const cs = await carrierlariGetir();
      if (!iptal) setCarriers(cs || []);
      const { data: pr, error: e3 } = await supabase.from("profiles").select("guest_capacity")
        .eq("user_id", (await supabase.auth.getUser()).data?.user?.id || "").maybeSingle();
      if (e3) logError("edit_avail_capacity", e3);
      if (!iptal) setCap(pr?.guest_capacity ?? null);
    })();
    return () => { iptal = true; };
  }, [avail?.airport_code]);

  // Tarih değişince yeniden ölç: host hangi güne bakıyorsa o günün
  // talebini görmeli.
  useEffect(() => {
    let iptal = false;
    (async () => {
      if (!avail?.airport_code || !f.date) return;
      const { data, error } = await supabase.rpc("talep_yogunlugu", {
        p_airport: avail.airport_code, p_date: f.date,
      });
      if (error) { logError("talep_yogunlugu", error); return; }
      if (!iptal) setYogunluk(data || null);
    })();
    return () => { iptal = true; };
  }, [avail?.airport_code, f.date]);

  useEffect(() => {
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.from("requests")
        .select("id, status").eq("avail_id", avail?.id).eq("status", "accepted");
      if (error) { logError("edit_avail_reqs", error); if (!iptal) setKabul(0); return; }
      if (!iptal) setKabul((data || []).length);
    })();
    return () => { iptal = true; };
  }, [avail?.id]);

  const kilitli = (kabul || 0) > 0;
  const set = (k, v) => setF(prev => ({ ...prev, [k]: v }));
  // "Müsaitlik ekle" ile AYNI kural: beyan edilen kapasiteyi aşamaz.
  const maxSlots = cap && cap > 0 ? Math.min(cap, 3) : 3;

  async function kaydet() {
    if (busy) return;
    setBusy(true); setErr(""); setOk("");
    // 🔴 TEK ÇAĞRI. Eskiden güven eşiği AYRI bir RPC ile yazılıyordu ve
    // ikisi arasında bir pencere vardı: ilk yazma geçip ikincisi düşerse
    // host "kaydettim" görüp korumasız kalıyordu. SQL 248 `p_min_trust`ı
    // `update_availability` sözleşmesine ekledi — tek işlem, tek sonuç.
    const { data, error } = await supabase.rpc("update_availability", {
      p_id: avail.id,
      p_date: f.date || null,
      p_from: f.from ? f.from + ":00" : null,
      p_to: f.to ? f.to + ":00" : null,
      p_slots: f.slots ? Number(f.slots) : null,
      p_lounge_id: f.lounge_id || null,
      p_flight: f.flight,
      p_visibility: f.visibility || null,
      p_carrier: carrier || null,
      p_cabin: cabin || null,
      p_charter: charter,
      p_min_trust: Number(esik),
    });
    if (error) { setBusy(false); setErr(mapErr(t, error.message)); return; }
    setBusy(false);
    setOk(t.editDone + ((data && data.bildirilen > 0) ? " " + t.editNotified : ""));
    if (onDone) onDone();
  }

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneListing} title={t.editAvail} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {kilitli ? (
          <View style={[S.card, { borderColor: "transparent", borderWidth: 1.5, marginBottom: SP[3] }]}>
            <Text style={{ fontWeight: "700", color: C.ink, fontSize: FS.base }}>{t.editLockedTitle}</Text>
            <Text style={{ color: C.mut, fontSize: FS.sm, marginTop: SP[1], lineHeight: 18 }}>{t.editLockedBody}</Text>
          </View>
        ) : null}

        <SihirbazBasi t={t} adim={adim} setAdim={setAdim} serbest sorular={[t.wzHQ1, t.wzHQ2, t.wzHQ3]} />
        {adim === 1 && (<>
          {/* HAVALİMANI — görünür ve kilitli, sebebiyle birlikte. */}
          <Text style={S.label}>{t.airport}</Text>
          <View style={[S.input, { justifyContent: "center", opacity: 0.6, minHeight: TAP.minHeight }]}>
            <Text style={{ color: C.ink, fontSize: FS.base, fontWeight: "700" }}>{avail?.airport_code || "—"}</Text>
          </View>
          <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: -6, marginBottom: ARA[10], lineHeight: 16 }}>
            {t.editAirportLocked}
          </Text>

          <LoungePicker t={t} lounges={lounges} value={f.lounge_id}
            onSelect={v => !kilitli && set("lounge_id", v)}
            emptyNote={loungeErr ? t.loungeLoadFail : undefined} />

        </>)}
        {adim === 2 && (<>
          <CarrierPicker t={t} carriers={carriers} value={carrier}
            onSelect={setCarrier} label={t.carrierQ} hint={t.carrierWhy} />

          {/* KOŞULLU: yalnız bu salonda kabin kuralı varsa (SQL 249). */}
          {kabinSor === true && (<>
          <Text style={S.label}>{t.cabinTitle}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[6] }}>
            {[["economy", t.cabinEconomy], ["business", t.cabinBusiness],
              ["first", t.cabinFirst], [null, t.cabinSkip]].map(([v, lb]) => (
              <TouchableOpacity key={String(v)} onPress={() => setCabin(v)}
                accessibilityRole="button" accessibilityState={{ selected: cabin === v }}
                style={[S.chip, { minHeight: TAP.minHeight, justifyContent: "center",
                                  borderColor: cabin === v ? C.gold : C.line,
                                  backgroundColor: cabin === v ? C.goldSoft : C.card }]}>
                <Text style={{ fontSize: FS.sm, color: cabin === v ? C.gold : C.ink,
                               fontWeight: cabin === v ? "700" : "400" }}>{lb}</Text>
              </TouchableOpacity>
            ))}
          </View>
          {cabin === "business" && (
            <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent",
                           borderRadius: R.xs, padding: SP[3], marginBottom: SP[3] }}>
              <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.cabinBizNote}</Text>
            </View>
          )}
          </>)}

          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setCharter(v => !v)}
            accessibilityRole="checkbox" accessibilityState={{ checked: charter }}
            accessibilityLabel={t.charterQ}
            style={{ flexDirection: "row", alignItems: "center", marginBottom: ARA[14], minHeight: TAP.minHeight }}>
            <View style={{ width: 19, height: 19, borderRadius: R.onay, borderWidth: 1.5,
                           borderColor: charter ? C.amber : C.line, marginRight: SP[2],
                           alignItems: "center", justifyContent: "center",
                           backgroundColor: charter ? C.amber : "transparent" }}>
              {charter && <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} />}
            </View>
            <Text style={{ fontSize: FS.sm, color: C.body, flex: 1 }}>{t.charterQ}</Text>
          </TouchableOpacity>
          {charter && (
            <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14] }}>
              <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.charterWarn}</Text>
            </View>
          )}

          {/* TARİH ve SAAT artık düz metin kutusu DEĞİL — açma ekranındaki
              seçicilerin aynısı. Eskiden host "2026-09-04" biçimini elle
              yazmak zorundaydı; bir harf yanlışında sunucu hatası alıyordu. */}
          <DateInput value={f.date} onChange={v => !kilitli && set("date", v)} />
          <View style={{ flexDirection: "row", marginBottom: ARA[14] }}>
            <TimeInput label={t.avStart} value={f.from} onChange={v => !kilitli && set("from", v)} />
            <View style={{ width: 8 }} />
            <TimeInput label={t.avEnd} value={f.to} onChange={v => !kilitli && set("to", v)} />
          </View>

          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[1], letterSpacing: 1 }}>{t.avFlightLabel}</Text>
          <FlightField t={t} value={f.flight} onChange={v => set("flight", v)}
            date={f.date} carrier={carrier} showChips={false} hideLabel
            manualWarn={t.flightManualWarn}
            inputStyle={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.sm }} />
          <View style={{ height: 14 }} />

          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.haGuestSlots}</Text>
          <View style={{ flexDirection: "row", marginBottom: SP[3] }}>
            {[1, 2, 3].map(n => {
              const sel = Number(f.slots) === n;
              // Kabul edilmiş misafir varken kontenjan DÜŞÜRÜLEMEZ (sunucu da
              // reddediyor); düğmeyi pasif göstermek, hatayı yemeden önce
              // söylemektir.
              const dis = n > maxSlots || (kilitli && n < Number(avail?.slots || 1));
              return (
                <TouchableOpacity key={n} disabled={dis} onPress={() => set("slots", n)}
                  accessibilityRole="radio" accessibilityState={{ checked: sel, disabled: dis }}
                  accessibilityLabel={n + " " + String(t.haGuestSlots).toLowerCase()}
                  style={{ flex: 1, backgroundColor: sel ? C.goldBg : C.card, borderWidth: 1.5, borderColor: sel ? C.gold : C.line,
                           borderRadius: R.xs, paddingVertical: ARA[10], minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center", marginRight: n < 3 ? 8 : 0, opacity: dis ? 0.35 : 1 }}>
                  <Text style={{ fontSize: FS.lg, fontWeight: "700", color: sel ? C.goldText : C.ink }}>{n}</Text>
                  <Text style={{ fontSize: FS.micro, color: C.dimAA }}>slot</Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {cap && cap < 3 ? (
            <Text style={{ fontSize: FS.xs, color: C.dimAA, marginTop: -6, marginBottom: ARA[14] }}>
              {t.haCapDeclared} {cap}{t.haCapMore}
            </Text>
          ) : null}

        </>)}
        {adim === 3 && (<>
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.haVisibility}</Text>
          {visOpts(t).map(([v, l]) => {
            const sel = f.visibility === v;
            return (
              <Secim key={v} bicim="radyo" ton="gold" zemin="alt" secili={sel} etiket={l}
                a11yRol="radio" stil={{ marginBottom: SP[2] }}
                onPress={() => set("visibility", v)} />
            );
          })}

          {/* GÜVEN EŞİĞİ — v2.93'te burada doğdu, v2.95'te "Müsaitlik ekle"
              ekranına da kondu. İki ekran artık aynı soruları soruyor. */}
          <Text style={S.label}>{t.minTrustLabel}</Text>
          <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: ARA[6] }}>
            {t.minTrustBody}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: SP[1] }}>
            {[0, 40, 60, 75].map((v) => {
              const on = Number(esik) === v;
              return (
                <Secim key={v} ton="teal" secili={on} onPress={() => setEsik(v)}
                  etiket={v === 0 ? t.minTrustAny : String(t.minTrustAtLeast || "").replace("{n}", String(v))} />
              );
            })}
          </View>

          <PromiseBox t={t} lounge={avail?.lounge_name || avail?.airport_code} f={f} esik={esik} yogunluk={yogunluk} />

        </>)}
        {err ? <View style={S.err}><Text style={{ color: C.red, fontSize: FS.sm }}>{err}</Text></View> : null}
        {ok ? <Text style={{ color: C.green, fontSize: FS.sm, marginTop: ARA[10] }}>{ok}</Text> : null}

        <SihirbazAlti t={t} adim={adim} setAdim={setAdim} setErr={setErr} f={f} busy={busy}
          sonEtiket={busy ? "…" : t.editSave} onSon={kaydet}
          dogrula={(n) => n === 2 && String(f.date || "").length !== 10 ? t.avFixDate : ""} />
      </ScrollView>
    </Sayfa>
  );
}

// "VAAT ETTİĞİN ŞEY BU" — v2.93'te İlan Düzenle'de doğdu, v2.95'te
// Müsaitlik Ekle'ye de kondu. TEK bileşen: iki ekranda iki kopya
// yazsaydım biri ötekinden ayrılırdı (madde 14'ün ta kendisi).
export function HostAvailability({ t, session, onBack, onDone, onVerify }) {
  const uid = session?.user?.id;
  const [airports, setAirports] = useState([]);
  const [lounges, setLounges] = useState([]);
  const [loungeErr, setLoungeErr] = useState("");
  // v1.86 — host salonu seçer seçmez kural kutusu (lounge_hint_for_host).
  // Host'a kart tipi/kabin SORULMAZ; karmaşıklık sunucuda kalır, ekrana
  // TEK CÜMLE düşer.
  const [hint, setHint] = useState(null);
  // 🔴 v2.78 — "HANGİ KARTIMI KULLANAYIM?" (SQL 216)
  // Gökberk'in cümlesi: aynı salona hem THY statüsüyle hem Priority Pass
  // hem LoungeKey hem DragonPass ile girilebiliyor olabilir, ama MİSAFİR
  // HAKKI kaynağa göre DEĞİŞİYOR. `lounge_hint_for_host` tek bir cümle
  // veriyordu; hangi kartla girileceğini SÖYLEMİYORDU.
  // Örnek (ölçüldü, IST iGA Dış Hat): DragonPass "misafirin AYNI UÇUŞTA
  // olmalı" diyor, Priority Pass demiyor. Host yanlış kartı seçerse
  // misafir kapıda kalır.
  const [kartOneri, setKartOneri] = useState(null);
  const [kartTablo, setKartTablo] = useState(null);   // null = kapalı
  // v2.01 — CHARTER. THY: "Charter seferde salon kullanim hakki YOKTUR,
  // business bileti ya da statu karti olsa bile." Ucus numarasindan
  // guvenilir tespit MUMKUN DEGIL, o yuzden UYDURMAK yerine SORUYORUZ.
  const [charter, setCharter] = useState(false);
  // 🔴 v2.23 — HAVAYOLU ARTIK SORULUYOR.
  // Kural motorunun en kritik iki maddesi tasiyiciya bagli (THY md.17 ve
  // AJet''in capraz misafir yasagi) ama biz tasiyiciyi UCUS NUMARASINDAN
  // TAHMIN ediyorduk. "712" yazan kullanicida tahmin yok; "AJ1876" yazanda
  // yanlis (AJet''in IATA kodu VF). En kritik kurali tahmine dayandirmak,
  // sormaktan her zaman pahalidir.
  const [carriers, setCarriers] = useState([]);
  const [carrier, setCarrier] = useState(null);
  const [carrierOpen, setCarrierOpen] = useState(false);
  // 🔴 v2.67 (A2) — KABİN. SQL 191 kolonu açtı ve karar zincirine bağladı,
  // 193 yazma yolunu (`set_availability_cabin`) verdi.
  // null = "Belirtme" → kabin kuralı aday olmaz, davranış bugünküyle aynı.
  const [cabin, setCabin] = useState(null);
  // Sunucunun döndürdüğü kabin notu (Business/First). Kendi metnimizi
  // yazmıyoruz: kural değişince ekran kendiliğinden düzelsin.
  const [cabinNote, setCabinNote] = useState("");
  const [partners, setPartners] = useState([]);
  const [confirmRule, setConfirmRule] = useState(false);
  const [ruleOk, setRuleOk] = useState(false);
  const [phoneOk, setPhoneOk] = useState(true);
  const [cap, setCap] = useState(null);
  const [adim, setAdim] = useState(1);   // v6.3 · ilan sihirbazı
  const [f, setF] = useState({ airport: "", lounge_id: "", date: "", from: "14:00", to: "18:00", slots: 2, flight: "", carrier: "", visibility: "all" });  // beta: bos-ag doneminde varsayilan herkes
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  // v1.64 (SQL 074 kurali): ILAN ACMAK = GORUNUR OLMAK. Ekip hesabi bile
  // olsa yayinla'ya basinca sunucu is_staff'i temizleyip kesfi acar; o
  // yuzden staff uyarisina gerek kalmadi. TEK istisna: kullanicinin
  // Ayarlar'dan KENDI kapattigi "Kesifte Goster" (sunucu buna dokunmaz —
  // bilincli tercih). Yalnizca bu durumda onceden uyaririz.
  const [hiddenWhy, setHiddenWhy] = useState(null);
  // 🔴 v2.95 (madde 14) — GÜVEN EŞİĞİ ARTIK BURADA DA SORULUYOR.
  // v2.93'te bu alanı yalnız "İlan düzenle"ye koymuştum. Sonuç: host
  // ilanı açarken kimin gelebileceğine karar veremiyor, ancak SONRADAN
  // düzenlemeye girip ayarlıyordu. Yani ürünün güvenlik ayarı, akışın
  // yanlış ucundaydı — ilan yayına eşiksiz çıkıyor, host fark ederse
  // düzeltiyordu.
  const [esik, setEsik] = useState(0);
  // 🔴 v2.96 (eleştiri B2) — KABİN SORUSU ARTIK KOŞULLU.
  // Gökberk sordu: "kabin dediğin ne?" Kabin = HOST'UN KENDİ BİLETİNİN
  // SINIFI (Ekonomi/Business/First). THY'nin resmî kuralı: Business
  // BİLETİ salona sokar ama MİSAFİR HAKKI VERMEZ (o hak kart tipinden
  // gelir); First ise Business bölümünde bir misafir hakkı verir.
  // Yani Business'ta uçan bir host "misafir götürebilirim" diye ilan
  // açarsa misafir kapıda kalır. Soru tam olarak bunu önlüyor.
  //
  // AMA ölçtüm: 329 salonun yalnız 13'ünde kabin kuralı var ve 15
  // kuralın 14'ü aynı kuralın salon salon tekrarı. Soruyu her ilanda
  // sormak %96 gürültü; silmek ise kalan %4'te misafiri kapıda bırakmak.
  // 🆕 SINIF: "BİR SORUYU HERKESE SORMAK İLE HİÇ SORMAMAK ARASINDA ÜÇÜNCÜ
  // BİR SEÇENEK VAR: CEVABIN BİR ŞEYİ DEĞİŞTİRDİĞİ YERDE SORMAK."
  const [kabinSor, setKabinSor] = useState(null);   // null = henüz ölçülmedi

  // Salon değişince kabin sorusunun gerekip gerekmediğini SUNUCUYA sor.
  useEffect(() => {
    let iptal = false;
    (async () => {
      const lid = f.lounge_id;
      if (!lid) { if (!iptal) setKabinSor(null); return; }
      const { data, error } = await supabase.rpc("kabin_sorulmali_mi", { p_lounge_id: lid });
      if (error) { logError("kabin_sorulmali_mi", error); if (!iptal) setKabinSor(true); return; }
      // 🔴 HATA DURUMUNDA SORUYU GÖSTERİYORUZ, GİZLEMİYORUZ. Ölçemediğimiz
      // bir durumda soruyu saklamak, kuralı sessizce devre dışı bırakmak
      // olurdu; fazladan bir soru sormak ise yalnız bir soru.
      if (!iptal) setKabinSor(!!(data && data.sor));
    })();
    return () => { iptal = true; };
  }, [f.lounge_id]);


  useEffect(() => {
    (async () => {
      // 🔴 v3.4 — İLAN FORMU DA BEŞ TURU SIRAYLA ATIYORDU (Ayarlar gibi).
      // Havalimanları · havayolları · doğrulama · staff bayrağı · profil.
      // Beşi bağımsız; tek dalgaya indi.
      //
      // Havalimanı ve havayolu katalogları ayrıca ÖNBELLEKLİ (bkz.
      // `src/katalog.js`): 222 satırlık havalimanı listesi uygulamada BEŞ
      // ayrı ekrandan, her açılışta yeniden çekiliyordu. Değişmeyen bir
      // listeyi her seferinde indirmek, ağ değil TASARIM sorunudur.
      const [apL, csL, { data: v }, { data: me }, { data: p }] = await Promise.all([
        havalimanlariniGetir(),
        carrierlariGetir(),
        supabase.from("verifications").select("phone_verified").eq("user_id", uid).maybeSingle(),
        supabase.from("users").select("is_staff").eq("id", uid).maybeSingle(),
        supabase.from("profiles").select("guest_capacity, show_on_discovery").eq("user_id", uid).maybeSingle(),
      ]);
      setAirports(apL);
      setCarriers(csL);
      setPhoneOk(!!v?.phone_verified);
      if (!me?.is_staff && p && p.show_on_discovery === false) setHiddenWhy("disc");
      else setHiddenWhy(null);
      setCap(p?.guest_capacity ?? null);
      // #18: kayitli misafir kapasitesi formda ON-SECILI gelir (MVP: Adim 2/2 akisi)
      if (p?.guest_capacity) setF(prev => ({ ...prev, slots: Math.max(1, Math.min(3, p.guest_capacity)) }));
    })();
  }, [uid]);

  const prevAirport = useRef(null);
  useEffect(() => {
    if (!f.airport) { setLounges([]); return; }
    (async () => {
      // 🔴 v1.85 P0 DUZELTME: kolon adi "access_type" yazilmisti, semada
      // "access_types" (text[]). PostgREST bilinmeyen kolonda 400 doner,
      // data null olur ve setLounges([]) calisir. Yani lounge listesi
      // HER HAVALIMANINDA, HER ZAMAN bostu. LoungePicker bos listede null
      // donduugu icin alan ekrandan tamamen kayboluyordu; publish() ise
      // lounge_id sart kosuyordu -> HICBIR HOST ILAN YAYINLAYAMIYORDU.
      // Hata yutuldugu icin de sessizdi.
      // 🔴 İKİNCİ SORGU DA RPC'YE GEÇTİ. Aynı hatanın iki yerde yaşaması
      // bu projede tekrar eden bir kalıp (contract_check kopyası, BO'nun
      // ölü denetimi): biri düzelir, öteki bayatlar. İkisi de tek yoldan.
      const { data, error: lErr } = await supabase
        .rpc("lounges_for_airport", { p_airport: f.airport });
      // (eski doğrudan tablo sorgusu kaldırıldı — ölü kod bırakmıyoruz)
      if (lErr) { console.warn("lounges rpc basarisiz:", lErr.message); }
      setLounges(data || []);
      setLoungeErr(lErr ? String(lErr.message || "") : "");
      // Lounge seçimini YALNIZCA havalimanı gerçekten değiştiyse sıfırla.
      // Aksi halde (aynı havalimanıyla effect yeniden koşarsa) seçili lounge kaybolurdu.
      if (prevAirport.current !== null && prevAirport.current !== f.airport) {
        setF(x => ({ ...x, lounge_id: "" }));
      }
      prevAirport.current = f.airport;
    })();
  }, [f.airport]);

  useEffect(() => {
    if (!f.lounge_id) { setHint(null); setRuleOk(false); setPartners([]); return; }
    // Salonun anlasmali kurumlari — havalimaninin kendi listesi.
    supabase.rpc("venue_partners", { p_lounge_id: f.lounge_id })
      .then(({ data, error }) => setPartners(error ? [] : (data || [])))
      .catch(() => setPartners([]));
    setRuleOk(false);   // salon değişti → önceki onay geçersiz
    setKartOneri(null); setKartTablo(null);
    let alive = true;
    (async () => {
      try {
        const { data, error: hata6 } = await supabase.rpc("lounge_hint_for_host", { p_lounge_id: f.lounge_id });
        if (hata6) logError("screens.js:2966", hata6);
        if (alive) setHint(data || null);
        // Salonun venue kimliği katalog satırında; öneri onun üzerinden gelir.
        // ⚠️ `error` DESTRUCTURE EDİLİYOR. Bu depoda kural: hatayı
        // yakalamayan bir okuma, hatayı BOŞ VERİYE çevirir ve ekran
        // "veri yok" gibi görünür. `check.js` bunu tavanla sayıyor ve
        // benim iki yeni satırım tavanı 78'den 80'e çıkardı — nöbetçi
        // haklıydı, satırları düzelttim.
        const { data: lg, error: lgErr } = await supabase.from("lounges")
          .select("venue_id").eq("id", f.lounge_id).maybeSingle();
        if (lgErr) { logError("kart_oneri_venue", lgErr); }
        if (lg?.venue_id) {
          const { data: on, error: onErr } = await supabase.rpc("hangi_kartimi_kullanayim", { p_venue: lg.venue_id });
          if (alive) setKartOneri(onErr ? null : (on || null));
        } else if (alive) setKartOneri(null);
      } catch (e) { if (alive) { setHint(null); setKartOneri(null); } }
    })();
    return () => { alive = false; };
  }, [f.lounge_id]);

  const set = (k, v) => setF(x => ({ ...x, [k]: v }));

  // 🔴 30 AĞUSTOS — "ANLADIM, YAYINLA" YAYINLAMIYORDU.
  //
  // Gökberk: "kullanıcı Anladım,yayınla butonuna tıkladığında ilan
  // yayınlanmıyor. Bunun yerine sadece popup kapanıyor."
  //
  // Sebep: modalın `onConfirm`i yalnız `setConfirmRule(false)` ve
  // `setRuleOk(true)` çağırıyordu. `ruleOk`u izleyen bir `useEffect`
  // yok, yani state değişimi HİÇBİR ŞEY tetiklemiyordu. Düğmenin
  // etiketi "yayınla" diyordu ama yaptığı iş "kapat"tı.
  //
  // 🆕 SINIF: **"BİR DÜĞMENİN ETİKETİ BİR VAATTİR; O VAADİ YERİNE
  // GETİRMEYEN HER İŞLEYİCİ, ETİKETİ YALANLAR."**
  //
  // ⚠️ `setRuleOk(true)` sonrası aynı turda `publish()` çağırmak
  // YETMEZ — React state'i asenkrondur, `publish` hâlâ eski `ruleOk`u
  // (false) okur ve modalı yeniden açar. Bu yüzden karar bir ARGÜMAN
  // olarak geçiyor; state'e değil çağrıya bağlı.
  async function publish(kuralOnaylandi = false) {
    if (!phoneOk) { onVerify(); return; }
    if (!f.airport) { setErr(t.avPickAirport); return; }
    if (lounges.length > 0 && !f.lounge_id) { setErr(t.pickLounge || "Lounge seç"); return; }

    // 🔴 v1.97 — YAYINLAMADAN ÖNCE KURAL ONAYI.
    // Kural kutusu salon seçilince zaten görünüyor ama host formu
    // doldururken aşağı kaydırıp onu geride bırakabiliyor. En kritik
    // bilgi (misafir ücret öder mi, uçuş şartı var mı) tam da "Yayınla"
    // anında hatırlatılmalı — kapıda öğrenmek yerine burada öğrensin.
    if (hint && (hint.severity === "warn" || hint.severity === "block")
        && !ruleOk && kuralOnaylandi !== true) {
      setConfirmRule(true);
      return;
    }
    if (f.date.length !== 10) { setErr(t.avFixDate); return; }
    setBusy(true); setErr("");
    // Motorun kabin notu — publish sonunda okunur (state asenkrondur,
    // aynı turda geri okunamaz; bu yüzden yerel değişken).
    let note = "";
    // İmza (040): create_availability(p_lounge_id, p_airport, p_date, p_from,
    // p_to, p_slots, p_flight, p_visibility). contract_check.py bu çağrıyı
    // p_lounge/p_airport eksikken yakaladı — imzayı okumadan yazmıştım.
    // 🔴 v2.71 — ÜÇ AYARIN SESSİZCE KAYBOLDUĞU YER BURASIYDI.
    // `create_availability` bir UUID DEĞİL, jsonb döndürüyor:
    //   {"ok":true, "id":"...", "visibility":"Public", "min_trust":0}
    // Değişkene `newId` adını verip aşağıda üç yere `p_avail_id: newId`
    // diye geçmiştim. PostgREST bir NESNEYİ uuid parametresine
    // yazamaz — üç çağrı da 22P02 ile düşüyordu ve ikisinin catch'i
    // hatayı YUTUYORDU. Sonuç: host charter'ı işaretliyor, taşıyıcıyı
    // seçiyor, kabini seçiyor — hiçbiri ilana yazılmıyordu. Kural
    // motoru da tam bu üç alana bakarak karar veriyor.
    // Ders: dönüş tipini OKUMADAN isim verme. Değişken adı bir iddiadır.
    const { data: created, error } = await supabase.rpc("create_availability", {
      p_lounge_id: f.lounge_id, p_airport: f.airport, p_date: f.date,
      p_from: f.from + ":00", p_to: f.to + ":00", p_slots: f.slots,
      p_flight: f.flight.trim() || null, p_visibility: f.visibility,
      // 🔴 v2.79 — `f.carrier` DEĞİL `carrier`. Ekranda iki ayrı havayolu
      // alanı vardı ve ikisi AYRI değişkene yazıyordu — çipler `f.carrier`,
      // droplist `carrier`. Burası birinciyi gönderiyor, aşağıdaki
      // `set_availability_carrier` ikinciyle üzerine yazıyordu. Çip
      // satırı kaldırıldı; tek kaynak `carrier`.
      p_carrier: carrier || null,
    });
    // v2.47 — p_carrier (158): kural motoru tasiyiciya gore karar verir;
    // secim bos birakilirsa SQL tarafi ucus no onekinden turetir.
    // Charter beyanı ilan oluştuktan SONRA işaretlenir: create_availability
    // imzasına dokunmak 10+ çağrı noktasını etkilerdi. Başarısız olursa
    // akış BOZULMAZ — ilan yayınlanır, yalnız charter notu düşmez.
    // Hem nesne hem düz uuid gelen sürümlere dayanıklı okuma.
    const newId = created && typeof created === "object" ? created.id : created;
    if (!error && newId) {
      // 🔴 catch ARTIK SESSİZ DEĞİL. Bu üç çağrı yutulan hatalar
      // yüzünden aylarca bozuk kaldı; hata en azından konsola düşsün.
      // 🔴 v2.78 — KONSOL KULLANICIYA GÖRÜNMEZ.
      // Bu üç çağrı `console.warn`a düşüyordu. Ama bunlar KURAL MOTORUNUN
      // GİRDİSİ: charter işaretlenmezse "charter'da salon hakkı yoktur"
      // kuralı devreye girmez; taşıyıcı yazılmazsa "misafir aynı havayolunda
      // olmalı" kuralı yanlış çalışır. Host bunu ASLA öğrenmiyordu ve
      // misafir kapıda öğreniyordu.
      // İlan AÇILDI (geri almıyoruz) ama eksik yazıldığını SÖYLÜYORUZ.
      const eksikAlanlar = [];
      // 🔴 v3.6 — DÖRT YAZIM SIRAYLA KOŞUYORDU, HİÇBİRİ DİĞERİNİ BEKLEMİYOR.
      //
      // Dördü de aynı `newId`ye yazıyor ve hiçbiri ötekinin cevabını
      // kullanmıyordu. Yine de sırayla: 4 × ~345 ms ≈ 1.4 sn — ve tam
      // olarak host'un "Yayınla"ya bastıktan sonra beklediği yerde.
      // Yayın akışı ürünün ARZ tarafındaki tek dönüşüm anı; orada
      // beklemek en pahalı beklemedir.
      //
      // ⚠️ HATA RAPORLAMASI AYNEN KORUNDU: her biri kendi adıyla
      // `eksikAlanlar`a giriyor. `allSettled` kullanılıyor ki biri
      // düşünce diğerlerinin sonucu da okunabilsin — "hangi alan
      // yazılamadı" cümlesi eksiksiz kalsın.
      //
      // 🆕 SINIF: "AYNI KAYDA YAPILAN BAĞIMSIZ YAZIMLARI SIRAYA DİZMEK,
      // OKUMALARI SIRAYA DİZMEKTEN DAHA PAHALIDIR — ÇÜNKÜ KULLANICI
      // YAZMA ANINDA EKRANIN BAŞINDA BEKLİYORDUR."
      const yazimlar = [
        { ad: t.fieldCharter, log: "set_availability_charter",
          p: supabase.rpc("set_availability_charter", { p_avail_id: newId, p_is_charter: charter }) },
      ];
      if (carrier) {
        yazimlar.push({ ad: t.fieldCarrier, log: "set_availability_carrier",
          p: supabase.rpc("set_availability_carrier", { p_avail_id: newId, p_carrier: carrier }) });
      }
      // 🔴 v2.95 (madde 14) — GÜVEN EŞİĞİ YAYINDA DA YAZILIYOR.
      // Aynı kalıp: hata YUTULMUYOR. Eşik yazılmadıysa host korunduğunu
      // sanıp korunmasız kalırdı — bu alan bir güvenlik ayarı.
      if (Number(esik) > 0) {
        yazimlar.push({ ad: t.fieldMinTrust, log: "ilan_guven_esigi_yaz",
          p: supabase.rpc("ilan_guven_esigi_yaz", { p_avail_id: newId, p_esik: Number(esik) }) });
      }
      const sonuclar = await Promise.allSettled(yazimlar.map(x => x.p));
      sonuclar.forEach((r, i) => {
        const hata = r.status === "rejected" ? r.reason : (r.value && r.value.error);
        if (hata) { logError(yazimlar[i].log, hata); eksikAlanlar.push(yazimlar[i].ad); }
      });
      // 🔴 v2.67 (A2) — KABİNİ İLANA YAZ, GERÇEK YOLDAN.
      // SQL 193 `set_availability_cabin`'i açtı (charter/carrier
      // setter'larının kardeşi): sahiplik şartlı, doğrulamalı ve
      // GRANT'li. Bir önceki turdaki doğrudan tablo update'i 42501
      // dönüyordu — kaldırıldı.
      // Dönen `note` MOTORUN cümlesidir; kendi metnimizi yazmıyoruz:
      // kural bir yerde değişince ekran kendiliğinden düzelir.
      if (cabin) {
        const { data: cRes, error: cErr } = await supabase.rpc("set_availability_cabin", {
          p_avail_id: newId, p_cabin: cabin,
        });
        if (cErr) { logError("set_availability_cabin", cErr); eksikAlanlar.push(t.fieldCabin); }
        else if (cRes && cRes.note) note = String(cRes.note);
      }
      // İlan açıldı ama kural motorunun girdilerinden biri yazılamadıysa,
      // host'un bunu YAYIN ANINDA bilmesi gerekir — kapıda değil.
      if (eksikAlanlar.length) {
        setCabinNote(t.fieldsNotSaved.replace("{alanlar}", eksikAlanlar.join(", ")));
        setBusy(false);
        return;
      }
    }
    setBusy(false);
    if (error) { setErr(mapErr(t, error.message)); return; }
    // Motorun son sözü ekrandan KAÇMASIN: ilan yayınlandı, host kapıda
    // ne olacağını okuyup kapatıyor. Not yoksa hiç durmayız.
    if (note) { setCabinNote(note); return; }
    if (onDone) onDone();
    onBack();
  }

  // MVP'de kapasite beyani yoktu; bizde HostAccessSource'ta beyan ediliyor.
  // Beyan edilen kapasiteyi ASAMAZ — sunucuda da kontrol var.
  const maxSlots = cap && cap > 0 ? Math.min(cap, 3) : 3;

  return (
    <Sayfa>
      <Hdr t={t} ustBilgi={t.sceneListing} title={t.addAvailTitle} onBack={onBack} />
      <ScrollView contentContainerStyle={{ padding: SP[4], paddingBottom: ARA[40] }}>
        {/* v6.3 · PANO İ1–İ3 (Gökberk onayı) — İLAN SİHİRBAZI: 1 salon + kural ·
            2 zaman, uçuş, misafir · 3 kimler görür + önizleme + yayınla. Yayın
            kapısı (telefon, kural onayı, tarih) publish() içinde AYNEN duruyor. */}
        <SihirbazBasi t={t} adim={adim} setAdim={setAdim} sorular={[t.wzHQ1, t.wzHQ2, t.wzHQ3]} />
        {!!hiddenWhy && (
          <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14] }}>
            <IkonMetin ad="uyari" renk={C.amberInk} stilMetin={{ color: C.amberInk, fontWeight: "700", fontSize: FS.sm }} metin={t.availHiddenDisc} />
          </View>
        )}
        {/* 🔴 v1.97 — YAYINLAMA ONAYI.
            Gokberk'in istediği: kural bilgisini "Yayınla"ya basınca da
            göster. Uyarı ya da engel varsa yayın DURUR, host ne olacağını
            okuyup onaylar. Engel (block) durumunda onay düğmesi YOK —
            okuyup salonu değiştirmesi gerekir. */}
        <ConfirmModal
          visible={confirmRule}
          title={hint?.severity === "block" ? (t.ruleBlockTitle || "") : (t.ruleWarnTitle || "")}
          body={[hint?.headline, hint?.detail].filter(Boolean).join("\n\n")}
          confirmLabel={hint?.severity === "block" ? null : (t.ruleUnderstood || "")}
          cancelLabel={hint?.severity === "block" ? (t.ruleChangeLounge || "") : (t.confirmNo || "")}
          danger={hint?.severity === "block"}
          onCancel={() => setConfirmRule(false)}
          onConfirm={hint?.severity === "block" ? undefined : () => {
            setConfirmRule(false); setRuleOk(true);
            // Kararı ARGÜMANLA taşıyoruz: `ruleOk` bu turda henüz
            // güncellenmemiş olur.
            publish(true);
          }}
        />
        {/* 🔴 v2.67 — KABİN NOTU, MOTORUN AĞZINDAN.
            İlan yayınlandı; kapanmadan önce host kabinin ne anlama
            geldiğini okuyor (Business: misafir hakkı karttan gelir /
            First: Business bölümünde bir misafir hakkı). Metin
            `set_availability_cabin`'den gelir — tek kaynak. */}
        <ConfirmModal
          visible={!!cabinNote}
          title={t.cabinTitle}
          body={cabinNote}
          confirmLabel={t.ruleUnderstood || ""}
          cancelLabel={null}
          onCancel={() => { setCabinNote(""); if (onDone) onDone(); onBack(); }}
          onConfirm={() => { setCabinNote(""); if (onDone) onDone(); onBack(); }}
        />
        {adim === 1 && (<>
          <AirportPicker t={t} airports={airports} value={f.airport} onSelect={v => set("airport", v)} />
          <LoungePicker t={t} lounges={lounges} value={f.lounge_id} onSelect={v => set("lounge_id", v)}
            emptyNote={loungeErr ? t.loungeLoadFail : undefined} />
          {/* ============================================================
              "ERISIMIN VAR" ROZETI (v2.30)

              Rakipte en iyi tek gorsel oge buydu: salonun tepesinde tek,
              kacirilmaz durum — acik kilit + yesil.

              🔴 AMA ONLARDA BU BIR TAHMIN, BIZDE GERCEK OLABILIR.
              Onlar "Star Alliance Gold" yaziyor ve altina "kurallar
              degisebilir, salonla teyit edin" diyor. Biz kart tipini,
              bolumu, tasiyiciyi ve charter durumunu BILIYORUZ. Ayni
              gorsel dil, cok daha dogru icerik.

              Uc durum: girebilirsin · kosullu · giremezsin. Ucu de acikca
              soylenir; "belki" diye bir sey yok.
              ============================================================ */}
          {!!hint && !!f.lounge_id && (() => {
            // v6.3 · PANO İ1 — kural sonucu CAM KART; tam erişimde K4 mini damga.
            const ok = hint.severity !== "block";
            const cond = hint.severity === "warn" || hint.confidence === "unknown";
            const fg = !ok ? C.red : cond ? C.amberInk : C.goldText;
            return (
              <View style={[S.card, { flexDirection: "row", alignItems: "center", paddingVertical: SP[3] }]}>
                <Ikon ad={ok ? "kilitAcik" : "kilit"} boy={17} renk={fg} stil={{ marginRight: ARA[10] }} />
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text style={{ color: C.mut, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(t.hostRuleTitle || "")}</Text>
                  <Text style={{ fontSize: FS.base, fontWeight: "600", color: fg, marginTop: ARA[2] }}>
                    {!ok ? t.accessNo : cond ? t.accessMaybe : t.accessYes}
                  </Text>
                </View>
                {ok && !cond && (
                  <View style={{ width: 56, height: 56, alignItems: "center", justifyContent: "center" }}>
                    <View style={{ transform: [{ scale: 0.64 }] }}><OnayDamgasi t={t} /></View>
                  </View>
                )}
              </View>
            );
          })()}
          {!!hint && (hint.headline || hint.detail) && (
            <View style={{ marginTop: -6, marginBottom: ARA[14], borderRadius: R.xs, padding: SP[3], borderWidth: 1,
                           backgroundColor: hint.severity === "block" ? C.hataBg
                                          : hint.severity === "warn" ? C.amberBg : C.tealBg,
                           borderColor: hint.severity === "block" ? C.hataLine
                                      : hint.severity === "warn" ? C.amber : C.teal }}>
              <Text style={{ fontSize: FS.xs, letterSpacing: 0.8, fontWeight: "700", color: C.muted, marginBottom: SP[1] }}>
                {BUYUK(t.hostRuleTitle || "")}
              </Text>
              <Text style={{ fontSize: FS.sm, fontWeight: "700",
                             color: hint.severity === "block" ? C.redInk
                                  : hint.severity === "warn" ? C.amberInk : C.teal }}>
                {hint.headline}
              </Text>
              {!!hint.detail && (
                <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body, marginTop: SP[1] }}>{hint.detail}</Text>
              )}
            </View>
          )}

          {/* 🔴 v2.78 — HANGİ KARTIMI KULLANAYIM (SQL 216)
              Kural kutusu "ne olacağını" söylüyor; bu kutu "HANGİ KARTINLA"
              söylüyor. İkisi farklı sorular ve host'un cebinde birden çok
              kart olabiliyor. Öneri sıralaması sunucuda: ücretsiz > aile
              hakkı > uçuş şartsız > ücretli. */}
          {!!kartOneri && (
            <View style={{ marginTop: -2, marginBottom: ARA[14], borderRadius: R.xs, padding: SP[3],
                           borderWidth: 1, borderColor: "transparent", backgroundColor: C.goldBg }}>
              <Text style={{ ...T.label, color: C.muted, marginBottom: SP[1] }}>
                {BUYUK(t.whichCardTitle || "")}
              </Text>
              {kartOneri.oneri ? (
                <>
                  <Text style={{ fontSize: FS.sm, fontWeight: "700", color: C.goldInk }}>
                    {kartOneri.oneri.program_adi}
                    {kartOneri.oneri.kart_tipi ? " · " + kartOneri.oneri.kart_tipi : ""}
                  </Text>
                  <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body, marginTop: SP[1] }}>
                    {kartOneri.oneri.misafir_hakki}
                    {kartOneri.oneri.aile_dahil ? " (aile de dahil)" : ""}
                    {kartOneri.oneri.ucusa_bagli && kartOneri.oneri.ucusa_bagli !== "Ucus sarti yok"
                      ? " — " + kartOneri.oneri.ucusa_bagli : ""}
                  </Text>
                </>
              ) : (
                <Text style={{ fontSize: FS.sm, lineHeight: 18, color: C.body }}>{kartOneri.neden}</Text>
              )}
              <TouchableOpacity
                hitSlop={TAP.slop}
                onPress={async () => {
                  if (kartTablo) { setKartTablo(null); return; }
                  const { data: lg, error: lgErr } = await supabase.from("lounges")
                    .select("venue_id").eq("id", f.lounge_id).maybeSingle();
                  if (lgErr) { logError("kart_tablo_venue", lgErr); return; }
                  if (!lg?.venue_id) return;
                  const { data, error } = await supabase.rpc("salon_misafir_karsilastirmasi", { p_venue: lg.venue_id });
                  setKartTablo(error ? [] : (data || []));
                }}>
                <Text style={{ fontSize: FS.sm, color: C.goldInk, fontWeight: "700", marginTop: SP[2] }}>
                  {kartTablo ? (t.whichCardHide || "") : (t.whichCardAll || "").replace("{n}", String(kartOneri.salondaki_kaynak || 0))}
                </Text>
              </TouchableOpacity>
              {!!kartTablo && kartTablo.length > 0 && (
                <View style={{ marginTop: SP[2], borderTopWidth: 1, borderTopColor: C.line, paddingTop: SP[2] }}>
                  {kartTablo.slice(0, 30).map((k, i) => (
                    <View key={i} style={{ flexDirection: "row", justifyContent: "space-between",
                                           paddingVertical: SP[1], gap: SP[2] }}>
                      <Text style={{ fontSize: FS.sm, color: k.bende_var ? C.goldInk : C.body, flex: 1,
                                     fontWeight: k.bende_var ? "700" : "400" }}>
                        {k.program_adi}{k.kart_tipi ? " · " + k.kart_tipi : ""}
                      </Text>
                      <Text style={{ fontSize: FS.sm, color: C.muted, flex: 1, textAlign: "right" }}>
                        {k.misafir_hakki}
                      </Text>
                    </View>
                  ))}
                </View>
              )}
            </View>
          )}
          {!!partners && partners.length > 0 && (
            <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
                           borderRadius: R.xs, padding: SP[3], marginBottom: ARA[10] , ...ELEV.card }}>
              {/* 🔴 v2.27 — SALONUN ANLASMALI KURUMLARI.
                  Havalimaninin kendi sayfasindan alindi. Host "benim kartimla
                  girer miyim" diye soruyor; cevabi salonun kendi listesinde.
                  ⚠ isareti: anlasmanin VARLIGI dogrulandi, KOSULLARI degil —
                  ikisini karistirmak, bilmedigimizi biliyormus gibi gostermek. */}
              {/* 🔴 v2.79 — KATLANDI. Gökberk: "bu salona hangi kurumlarla
                  giriliyor ekranı küçültülebilir olmalı çünkü alttaki
                  alanlara inmesi zor oluyor."
                  Cihazda 16 kurum çipi alt alta duruyordu; altındaki
                  havayolu / misafir slotu / görünürlük alanlarına ulaşmak
                  uzun kaydırma istiyordu. Bilgi KAYBOLMUYOR: kapalıyken
                  bile başlıkta sayı duruyor ("20 kurum"), yani "burada bir
                  şey var" görünüyor. Paneli saklamak sorun değil, sayıyı
                  saklamak sorun olurdu.
                  🔴 Ayrıca `slice(0,14)` kaldırıldı: 20 kurumun 14'ünü
                  gösterip 6'sını sessizce düşürüyorduk ve bunu hiçbir yerde
                  yazmıyorduk. Katlanır panelde yer sorunu yok, hepsi var. */}
              <Katlanir baslik={t.partnersTitle} sayi={partners.length} not={t.partnersNote}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6] }}>
                  {partners.map((p, i) => (
                    <View key={i} style={[S.chip, { paddingVertical: SP[1] }]}>
                      <Text style={{ fontSize: FS.xs, color: C.body }}>
                        {p.partner_name}
                      </Text>
                    </View>
                  ))}
                </View>
              </Katlanir>
            </View>
          )}
        </>)}
        {adim === 2 && (<>
          {/* 🔴 v2.23 — HAVAYOLU SECIMI. Ucus numarasi kadar onemli:
              kural motoru "misafir ayni havayolunda mi" sorusunu buna
              bakarak yanitliyor. Turk havayollari listenin BASINDA —
              kullanicilarimizin neredeyse tamami oradan seciyor. */}
          {/* v2.79: elle yazılmış droplist → ortak CarrierPicker. Bu ekranda
              AYRICA aşağıda (eski satır 9220) bir çip satırı daha vardı;
              aynı soruyu iki kez soruyordu. Çip satırı kaldırıldı. */}
          <CarrierPicker t={t} carriers={carriers} value={carrier}
            onSelect={setCarrier} label={t.carrierQ} hint={t.carrierWhy} />

          {/* 🔴 v2.67 (A2) — KABİN SINIFI. Mimari eksik #3'ün son halkası.
              SQL 191 `availabilities.cabin_class`'ı açtı ve karar zincirine
              bağladı; 15 kabin kuralı TANIMLI ama hiçbir ilanda kabin
              girilmediği için hâlâ devre dışıydı — `cabin_rule_reach()`
              bunu her turda raporluyordu. Kabloyu app ucundan bağlıyoruz.
              "Belirtme" birinci sınıf cevap: boş bırakılırsa motor kabin
              kuralını aday yapmaz, davranış bugünkü ile AYNI kalır. */}
          {/* KOŞULLU: yalnız bu salonda kabin kuralı varsa (SQL 249). */}
          {kabinSor === true && (<>
          <Text style={S.label}>{t.cabinTitle}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: ARA[6] }}>
            {[["economy", t.cabinEconomy], ["business", t.cabinBusiness],
              ["first", t.cabinFirst], [null, t.cabinSkip]].map(([v, lb]) => (
              <TouchableOpacity key={String(v)} onPress={() => setCabin(v)}
                style={[S.chip, { minHeight: TAP.minHeight, justifyContent: "center",
                                  borderColor: cabin === v ? C.gold : C.line,
                                  backgroundColor: cabin === v ? C.goldSoft : C.card }]}>
                <Text style={{ fontSize: FS.sm, color: cabin === v ? C.gold : C.ink,
                               fontWeight: cabin === v ? "700" : "400" }}>{lb}</Text>
              </TouchableOpacity>
            ))}
          </View>
          {cabin === "business" && (
            /* Resmî kural: Business bileti misafir hakkı VERMEZ. Yumuşak
               not — engellemiyoruz, yanlış beklentiyi baştan düzeltiyoruz. */
            <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent",
                           borderRadius: R.xs, padding: SP[3], marginBottom: SP[3] }}>
              <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.cabinBizNote}</Text>
            </View>
          )}
          </>)}

          {/* v2.01 — CHARTER SORUSU. Tek kutu, varsayılan "tarifeli". */}
          <TouchableOpacity hitSlop={TAP.slop} onPress={() => setCharter(v => !v)}
            style={{ flexDirection: "row", alignItems: "center", marginBottom: ARA[14] }}>
            <View style={{ width: 19, height: 19, borderRadius: R.onay, borderWidth: 1.5,
                           borderColor: charter ? C.amber : C.line, marginRight: SP[2],
                           alignItems: "center", justifyContent: "center",
                           backgroundColor: charter ? C.amber : "transparent" }}>
              {charter && <Ikon ad="tamam" boy={FS.sm} renk={C.onAccent} />}
            </View>
            <Text style={{ fontSize: FS.sm, color: C.body, flex: 1 }}>{t.charterQ}</Text>
          </TouchableOpacity>
          {charter && (
            <View style={{ backgroundColor: C.amberBg, borderRadius: R.xs, padding: SP[3], marginBottom: ARA[14] }}>
              <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 18 }}>{t.charterWarn}</Text>
            </View>
          )}
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
          {/* 🔴 v2.79 — BU ÇİP SATIRI KALDIRILDI VE SEBEBİ GÖRÜNTÜDEN
              DAHA CİDDİYDİ.
              Gökberk "aynı sayfada iki havayolu seçimi var" dedi; ölçünce
              ikisinin AYRI DEĞİŞKENLERE yazdığı çıktı:
                  çip satırı  → `f.carrier`  → create_availability(p_carrier)
                  droplist    → `carrier`    → set_availability_carrier()
              Yani iki alan da sunucuya gidiyordu ve İKİNCİSİ BİRİNCİYİ
              EZİYORDU. Host çipten THY, listeden Pegasus seçseydi ilan
              sessizce Pegasus olarak açılırdı — ve kural motoru "misafir
              aynı havayolunda mı" sorusunu YANLIŞ taşıyıcıyla yanıtlardı.
              Çift görünen alan bir görüntü sorunu değil, bir veri sorunuydu.
              Artık tek kaynak var: yukarıdaki CarrierPicker → `carrier`.
              Uçuş numarası öneki de oradan türetiliyor. */}
          {/* 🔴 v2.68 — AYNI BİLEŞEN BURADA DA. Uyarı artık KOŞULLU:
              numara doğrulanabildiyse "elle girildi" demiyoruz (doğrulanmış
              bir uçuşa öyle demek yalan olurdu), doğrulanamadıysa aynen
              duruyor. Uçuş numarası burada da İSTEĞE BAĞLI. */}
          <FlightField t={t} value={f.flight} onChange={v => set("flight", v)}
            date={f.date} carrier={carrier} showChips={false} hideLabel
            manualWarn={t.flightManualWarn}
            inputStyle={{ backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line, borderRadius: R.xs, padding: SP[3], color: C.body, fontSize: FS.sm }} />
          <View style={{ height: 14 }} />

          {/* MVP: MISAFIR SLOTU — 1/2/3 buyuk kutu */}
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.haGuestSlots}</Text>
          <View style={{ flexDirection: "row", marginBottom: SP[3] }}>
            {[1, 2, 3].map(n => {
              const sel = f.slots === n;
              const dis = n > maxSlots;
              return (
                <TouchableOpacity key={n} disabled={dis} onPress={() => set("slots", n)}
                  accessibilityRole="radio" accessibilityState={{ checked: sel, disabled: dis }}
                  accessibilityLabel={n + " " + String(t.haGuestSlots).toLowerCase()}
                  style={{ flex: 1, backgroundColor: sel ? C.goldBg : C.card, borderWidth: 1.5, borderColor: sel ? C.gold : C.line,
                           borderRadius: R.xs, paddingVertical: ARA[10], minHeight: TAP.minHeight, justifyContent: "center", alignItems: "center", marginRight: n < 3 ? 8 : 0, opacity: dis ? 0.35 : 1 }}>
                  <Text style={{ fontSize: FS.lg, fontWeight: "700", color: sel ? C.goldText : C.ink }}>{n}</Text>
                  <Text style={{ fontSize: FS.micro, color: C.dimAA }}>slot</Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {cap && cap < 3 ? (
            <Text style={{ fontSize: FS.xs, color: C.dimAA, marginTop: -6, marginBottom: ARA[14] }}>
              {t.haCapDeclared} {cap}{t.haCapMore}
            </Text>
          ) : null}

        </>)}
        {adim === 3 && (<>
          {!!hint && !!f.lounge_id && (() => {
            // v6.3 · PANO İ1 — kural sonucu CAM KART; tam erişimde K4 mini damga.
            const ok = hint.severity !== "block";
            const cond = hint.severity === "warn" || hint.confidence === "unknown";
            const fg = !ok ? C.red : cond ? C.amberInk : C.goldText;
            return (
              <View style={[S.card, { flexDirection: "row", alignItems: "center", paddingVertical: SP[3] }]}>
                <Ikon ad={ok ? "kilitAcik" : "kilit"} boy={17} renk={fg} stil={{ marginRight: ARA[10] }} />
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text style={{ color: C.mut, fontSize: FS.micro + 0.5, fontWeight: "600", letterSpacing: 1.4 }}>{BUYUK(t.hostRuleTitle || "")}</Text>
                  <Text style={{ fontSize: FS.base, fontWeight: "600", color: fg, marginTop: ARA[2] }}>
                    {!ok ? t.accessNo : cond ? t.accessMaybe : t.accessYes}
                  </Text>
                </View>
                {ok && !cond && (
                  <View style={{ width: 56, height: 56, alignItems: "center", justifyContent: "center" }}>
                    <View style={{ transform: [{ scale: 0.64 }] }}><OnayDamgasi t={t} /></View>
                  </View>
                )}
              </View>
            );
          })()}
          {/* MVP: GORUNURLUK radio */}
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.mutedAA, marginBottom: SP[2], letterSpacing: 1 }}>{t.haVisibility}</Text>
          {visOpts(t).map(([v, l]) => {
            const sel = f.visibility === v;
            return (
              <Secim key={v} bicim="radyo" ton="gold" zemin="alt" secili={sel} etiket={l}
                a11yRol="radio" stil={{ marginBottom: SP[2] }}
                onPress={() => set("visibility", v)} />
            );
          })}

          <Text style={S.label}>{t.minTrustLabel}</Text>
          <Text style={{ color: C.mut, fontSize: FS.sm, lineHeight: 18, marginBottom: ARA[6] }}>
            {t.minTrustBody}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: SP[2], marginBottom: SP[1] }}>
            {[0, 40, 60, 75].map((v) => {
              const on = Number(esik) === v;
              return (
                <Secim key={v} ton="teal" secili={on} onPress={() => setEsik(v)}
                  etiket={v === 0 ? t.minTrustAny : String(t.minTrustAtLeast || "").replace("{n}", String(v))} />
              );
            })}
          </View>

          {/* "VAAT ETTİĞİN ŞEY BU" — yayınlamadan ÖNCE okunması, düzenlerken
              okunmasından daha değerli. Aynı bileşen, iki ekran. */}
          <PromiseBox t={t} lounge={(lounges.find(l => l.id === f.lounge_id) || {}).name || f.airport}
            f={f} esik={esik} yogunluk={null} />

        </>)}
        {!!err && <View style={{ backgroundColor: C.redBg, borderRadius: R.xs, padding: SP[3], marginTop: SP[2], marginBottom: SP[3] }}><Text style={{ color: C.redInk, fontSize: FS.sm }}>{err}</Text></View>}

        <SihirbazAlti t={t} adim={adim} setAdim={setAdim} setErr={setErr} f={f} busy={busy}
          sonEtiket={busy ? t.epSaving : t.publish} onSon={() => publish()}
          dogrula={(n) => n === 1 ? (!f.airport ? t.avPickAirport : (lounges.length > 0 && !f.lounge_id) ? (t.pickLounge || "") : "")
                          : n === 2 ? (String(f.date || "").length !== 10 ? t.avFixDate : "") : ""} />
        {/* MVP: telefon dogrulanmamissa PhoneGate */}
        {!phoneOk && (
          <TouchableOpacity onPress={onVerify}
            accessibilityRole="button" accessibilityLabel={t.haPhoneCta}
            style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent", borderRadius: R.sm, padding: SP[3], minHeight: TAP.minHeight, justifyContent: "center", marginTop: SP[3] }}>
            <Text style={{ color: C.amberInk, fontSize: FS.sm, lineHeight: 19 }}>
              {t.haPhoneNeeded}{" "}
              <Text style={{ fontWeight: "700" }}>{t.haPhoneCta}</Text>
            </Text>
          </TouchableOpacity>
        )}
      </ScrollView>
    </Sayfa>
  );
}
