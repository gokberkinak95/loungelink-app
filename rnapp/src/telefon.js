// ============================================================
// telefon.js — 18 Ekim · TELEFON DOĞRULAMA SAYFASI (Gökberk onayı: "Telefon Doğrulama Akışı")
//
// SMS'i Firebase Telefon Doğrulama gönderir (günde ilk 10 SMS ücretsiz, yalnız Türkiye).
// Akış: [numara] → [onay: "Kodu gönder"] → [6 haneli kod] → [başarı: güven 16 → 26]
//   1. Sunucu izni:  telefon_gonderim_izni(numara)  — TR cep, numara tek hesapta,
//      kullanıcı/numara başına günde 3, 60 sn kilit (SQL 335). Firebase'e ondan SONRA gidilir.
//   2. Firebase SMS + kod doğrulaması (Android'de kod çoğu zaman kendiliğinden okunur).
//   3. Panel /api/telefon-dogrula: Supabase oturumu + Google imzalı Firebase jetonu doğrulanır,
//      puanı YALNIZ sunucu yazar. Uygulama "doğruladım" diyerek puan alamaz.
// Kod kullanıcı istemeden gönderilmez (ücretsiz kota yarıda bırakılan ekranlara harcanmasın).
// Firebase modülü yoksa (eski build / web) ya da kanal kapalıysa `telefonHazir()` false döner
// ve çağıran eski e-posta yoluna düşer.
// ============================================================
import React, { useEffect, useRef, useState } from "react";
import { ActivityIndicator, KeyboardAvoidingView, Modal, Platform, Pressable, Text, TextInput, TouchableOpacity, View } from "react-native";
import { ARA, C, F, FS, R, SP, TAP } from "./theme";
import { Btn, POPUP_YUZEY } from "./ui";
import { Ikon } from "./ikon";
import { logError, supabase } from "./supabase";
import { backofficeUrl } from "./flight";
import { mapErr } from "./i18n";

let _auth = undefined;   // undefined = denenmedi · null = yok
function firebaseAuth() {
  if (_auth !== undefined) return _auth;
  if (Platform.OS === "web") { _auth = null; return null; }
  try {
    const m = require("@react-native-firebase/auth");
    const a = m && (m.default || m);
    a();                       // yerel modül yoksa burada fırlatır
    _auth = a;
  } catch (e) {
    _auth = null;
  }
  return _auth;
}

// Kanal açık mı ve bu build Firebase taşıyor mu? (ikisi birden)
export async function telefonHazir() {
  if (Platform.OS === "web" && globalThis.__TV_SAHNE) return true;   // yalnız sahne çekimi
  if (!firebaseAuth()) return false;
  try {
    const { data, error } = await supabase.rpc("dogrulama_kanali");
    if (error) { logError("dogrulama_kanali", error); return false; }
    return !!(data && data.firebase_hazir);
  } catch (e) { return false; }
}

// +90 5XX XXX XX XX → +905XXXXXXXXX (sunucu yine de kendisi kanonikleştirir)
export function e164(tel) {
  let d = String(tel || "").replace(/\D/g, "");
  if (d.startsWith("90")) d = d.slice(2);
  if (d.startsWith("0")) d = d.slice(1);
  return d.length === 10 ? "+90" + d : "";
}
function maskeli(tel) {
  const d = e164(tel).slice(3);
  return d.length === 10 ? `+90 ${d.slice(0, 3)} ••• •• ${d.slice(8)}` : tel;
}
function gruplu(d) {
  const x = String(d || "").replace(/\D/g, "").slice(0, 10);
  return [x.slice(0, 3), x.slice(3, 6), x.slice(6, 8), x.slice(8, 10)].filter(Boolean).join(" ");
}

const HAK = 5;            // yanlış kod hakkı
const KILIT_DK = 15;
const YENIDEN_SN = 60;

export function TelefonDogrulamaSayfasi({ t, session, acik, onKapat, onBitti, ilkNumara = "", kaynak = "profil" }) {
  const [asama, setAsama] = useState("onay");          // numara | onay | kod | basari
  const [numara, setNumara] = useState("");             // 10 hane (5XXXXXXXXX)
  const [kod, setKod] = useState("");
  const [hata, setHata] = useState("");
  const [mesgul, setMesgul] = useState(false);
  const [sayac, setSayac] = useState(0);
  const [kalanHak, setKalanHak] = useState(HAK);
  const [kilitBitis, setKilitBitis] = useState(0);
  const [sonuc, setSonuc] = useState(null);
  const onayRef = useRef(null);
  const bittiRef = useRef(false);
  const kodRef = useRef(null);

  useEffect(() => {
    if (!acik) return;
    const d = e164(ilkNumara).slice(3);
    setNumara(d); setAsama(d ? "onay" : "numara"); setKod(""); setHata(""); setSonuc(null);
    // yalnız web sahne çekimi: aşamayı doğrudan aç (gerçek cihazda bu dal yok)
    const sahne = Platform.OS === "web" ? globalThis.__TV_SAHNE : "";
    if (sahne === "kod") { setAsama("kod"); setKod("481"); setSayac(42); }
    else if (sahne === "basari") { setAsama("basari"); setSonuc({ ok: true, puan_once: 16, puan_sonra: 26, esik: 25 }); }
    else if (sahne === "numara") { setAsama("numara"); setNumara(""); }
    setKalanHak(HAK); bittiRef.current = false; onayRef.current = null;
  }, [acik]);

  useEffect(() => {
    if (sayac <= 0) return undefined;
    const z = setTimeout(() => setSayac(s => s - 1), 1000);
    return () => clearTimeout(z);
  }, [sayac]);

  // Android anlık doğrulama: Firebase kodu kendisi okuyup oturum açarsa beklemeden bitir.
  useEffect(() => {
    if (!acik || asama !== "kod") return undefined;
    const a = firebaseAuth();
    if (!a) return undefined;
    let abone = null;
    try {
      abone = a().onAuthStateChanged((u) => { if (u && u.phoneNumber && !bittiRef.current) sunucuyaYaz(u); });
    } catch (e) { /* yoksay */ }
    return () => { try { abone && abone(); } catch (e) {} };
  }, [acik, asama]);

  const hataYaz = (m) => setHata(mapErr(t, m));

  async function kodGonder() {
    if (mesgul) return;
    setHata("");
    if (Date.now() < kilitBitis) return setHata(t.tvKilit);
    const tel = e164(numara);
    if (!tel) return setHata(mapErr(t, "telefon_yalniz_tr_cep"));
    const a = firebaseAuth();
    if (!a) return setHata(t.tvKapali);
    setMesgul(true);
    try {
      const { error } = await supabase.rpc("telefon_gonderim_izni", { p_phone: tel });
      if (error) { setMesgul(false); return hataYaz(error.message); }
      onayRef.current = await a().signInWithPhoneNumber(tel);
      setAsama("kod"); setKod(""); setSayac(YENIDEN_SN);
      setTimeout(() => { try { kodRef.current && kodRef.current.focus(); } catch (e) {} }, 350);
    } catch (e) {
      logError("telefon_sms_gonder", e);
      hataYaz(firebaseHataKodu(e));
    }
    setMesgul(false);
  }

  async function kodDogrula(k) {
    if (mesgul || !onayRef.current) return;
    if (Date.now() < kilitBitis) return setHata(t.tvKilit);
    setMesgul(true); setHata("");
    try {
      const sonuc = await onayRef.current.confirm(k);
      await sunucuyaYaz(sonuc && sonuc.user);
    } catch (e) {
      const kod0 = firebaseHataKodu(e);
      if (kod0 === "auth/invalid-verification-code") {
        const kalan = kalanHak - 1;
        setKalanHak(kalan); setKod("");
        if (kalan <= 0) { setKilitBitis(Date.now() + KILIT_DK * 60000); setHata(t.tvKilit); }
        else setHata(String(t.tvYanlis).replace("{n}", String(kalan)));
        setTimeout(() => { try { kodRef.current && kodRef.current.focus(); } catch (e2) {} }, 50);
      } else {
        logError("telefon_kod_dogrula", e);
        hataYaz(kod0);
      }
      setMesgul(false);
    }
  }

  async function sunucuyaYaz(fbUser) {
    if (bittiRef.current) return;
    bittiRef.current = true;
    setMesgul(true);
    try {
      const a = firebaseAuth();
      const u = fbUser || (a && a().currentUser);
      if (!u) throw new Error("gecersiz_dogrulama");
      const jeton = await u.getIdToken(true);
      const taban = await backofficeUrl();
      if (!taban) throw new Error("telefon_kurulmadi");
      const yanit = await fetch(taban + "/api/telefon-dogrula", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + (session?.access_token || "") },
        body: JSON.stringify({ firebaseIdToken: jeton }),
      });
      const j = await yanit.json().catch(() => ({}));
      if (!yanit.ok || !j.ok) throw new Error(j.hata || "sunucu_hatasi");
      setSonuc(j); setAsama("basari");
    } catch (e) {
      bittiRef.current = false;
      logError("telefon_sunucu_yaz", e);
      hataYaz(String(e && e.message || e));
    } finally {
      // Firebase oturumu yalnız doğrulama için açıldı; bizim oturumumuz Supabase.
      try { const a = firebaseAuth(); a && a().currentUser && (await a().signOut()); } catch (e) {}
      setMesgul(false);
    }
  }

  function kapat() {
    if (asama === "basari") { onBitti && onBitti(sonuc); }
    onKapat && onKapat();
  }

  const etiket = { color: C.goldText, fontSize: FS.micro, fontWeight: "700", letterSpacing: 1.6 };
  const baslik = { fontFamily: F.serifGosterim, fontSize: 26, color: C.ink, marginTop: ARA[4], marginBottom: ARA[6] };
  const govde = { color: C.body, fontSize: FS.sm, lineHeight: 20 };

  return (
    <Modal visible={!!acik} transparent animationType="slide" onRequestClose={kapat} statusBarTranslucent>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
        <Pressable accessibilityRole="button" accessibilityLabel={t.close || "Kapat"} onPress={kapat}
          style={{ flex: 1, backgroundColor: "rgba(14,12,10,0.48)" }} />
        <View style={{ ...POPUP_YUZEY(), borderTopLeftRadius: 18, borderTopRightRadius: 18,
                       paddingHorizontal: ARA[22], paddingTop: ARA[10], paddingBottom: ARA[26] }}>
          <View style={{ width: 36, height: 4, borderRadius: R.full, backgroundColor: C.line, alignSelf: "center", marginBottom: ARA[14] }} />

          {asama === "numara" && (
            <>
              <Text style={etiket}>{t.tvTelEtiket}</Text>
              <Text style={baslik}>{t.tvNumaraBaslik}</Text>
              <View style={{ flexDirection: "row", gap: SP[2], marginTop: ARA[6] }}>
                <View style={{ borderWidth: 1, borderColor: C.line, borderRadius: R.sm, paddingHorizontal: ARA[12], justifyContent: "center", backgroundColor: C.card }}>
                  <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base }}>+90</Text>
                </View>
                <TextInput value={gruplu(numara)} onChangeText={(x) => { setHata(""); setNumara(String(x).replace(/\D/g, "").replace(/^0/, "").slice(0, 10)); }}
                  placeholder="5XX XXX XX XX" placeholderTextColor={C.mut} keyboardType="phone-pad" autoComplete="tel" textContentType="telephoneNumber"
                  accessibilityLabel={t.tvNumaraBaslik}
                  style={{ flex: 1, borderWidth: 1, borderColor: C.line, borderRadius: R.sm, paddingHorizontal: ARA[12], paddingVertical: ARA[12],
                           fontSize: FS.base, color: C.ink, backgroundColor: C.card, fontWeight: "600" }} />
              </View>
              <Text style={[govde, { fontSize: FS.xs, marginTop: ARA[10] }]}>{t.tvNumaraNot}</Text>
              {!!hata && <Text style={{ color: C.redInk, fontSize: FS.sm, marginTop: ARA[10] }} accessibilityLiveRegion="polite">{hata}</Text>}
              <Btn label={t.tvGonder} onPress={kodGonder} busy={mesgul} disabled={mesgul || numara.length !== 10} style={{ marginTop: ARA[14] }} />
              <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={kapat} style={{ alignItems: "center", paddingVertical: ARA[12] }}>
                <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.tvVazgec}</Text>
              </TouchableOpacity>
            </>
          )}

          {asama === "onay" && (
            <>
              <Text style={etiket}>{kaynak === "kayit" ? t.tvKayitEtiket : t.tvTelEtiket}</Text>
              <Text style={baslik}>{t.tvBaslik}</Text>
              <Text style={govde}>{t.tvGovde}</Text>
              <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", backgroundColor: C.bg,
                             borderWidth: 1, borderColor: C.line, borderRadius: R.sm, paddingHorizontal: ARA[14], paddingVertical: ARA[12], marginTop: ARA[12] }}>
                <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.base }}>{maskeli(numara)}</Text>
                <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={() => { setHata(""); setAsama("numara"); }}>
                  <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm }}>{t.tvDegistir}</Text>
                </TouchableOpacity>
              </View>
              <View style={{ marginTop: ARA[12], gap: ARA[6] }}>
                {[["+10", t.tvKazanc1], [null, t.tvKazanc2], [null, t.tvKazanc3]].map(([i, m]) => (
                  <View key={m} style={{ flexDirection: "row", gap: ARA[8], alignItems: "center" }}>
                    <View style={{ minWidth: 26 }}>
                      {i ? <Text style={{ color: C.greenInk || C.green, fontWeight: "700", fontSize: FS.sm }}>{i}</Text>
                         : <Ikon ad="tamam" boy={15} renk={C.greenInk || C.green} />}
                    </View>
                    <Text style={[govde, { flex: 1 }]}>{m}</Text>
                  </View>
                ))}
              </View>
              {!!hata && <Text style={{ color: C.redInk, fontSize: FS.sm, marginTop: ARA[10] }} accessibilityLiveRegion="polite">{hata}</Text>}
              <Btn label={t.tvGonder} onPress={kodGonder} busy={mesgul} disabled={mesgul} style={{ marginTop: ARA[14] }} />
              <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={kapat} style={{ alignItems: "center", paddingVertical: ARA[12] }}>
                <Text style={{ color: C.mut, fontSize: FS.sm, fontWeight: "600" }}>{t.tvSonra}</Text>
              </TouchableOpacity>
            </>
          )}

          {asama === "kod" && (
            <>
              <Text style={etiket}>{t.tvKodEtiket}</Text>
              <Text style={baslik}>{t.tvKodBaslik}</Text>
              <Text style={govde}>{String(t.tvKodGovde).replace("{n}", maskeli(numara))}</Text>
              {/* Görünen 6 kutu, tek gerçek alanın yansıması: iOS "Mesajlardan" önerisi ve Android
                  otomatik doldurma tek alanla çalışır. */}
              <Pressable accessibilityRole="none" onPress={() => { try { kodRef.current && kodRef.current.focus(); } catch (e) {} }}
                style={{ flexDirection: "row", justifyContent: "center", gap: ARA[8], marginTop: ARA[14], marginBottom: ARA[8] }}>
                {Array.from({ length: 6 }).map((_, i) => {
                  const dolu = i < kod.length, imlec = i === kod.length && !mesgul;
                  return (
                    <View key={i} style={{ width: 42, height: 52, borderRadius: R.sm, alignItems: "center", justifyContent: "center",
                                           backgroundColor: hata && !kod ? C.hataBg : C.card,
                                           borderWidth: imlec || dolu ? 1.5 : 1,
                                           borderColor: hata && !kod ? C.hataLine : imlec || dolu ? C.gold : C.line }}>
                      <Text style={{ color: C.ink, fontSize: 22, fontWeight: "700" }}>{kod[i] || ""}</Text>
                    </View>
                  );
                })}
              </Pressable>
              <TextInput ref={kodRef} value={kod} autoFocus
                onChangeText={(x) => { const k = String(x).replace(/\D/g, "").slice(0, 6); setKod(k); if (hata) setHata(""); if (k.length === 6) kodDogrula(k); }}
                keyboardType="number-pad" maxLength={6} textContentType="oneTimeCode" autoComplete="sms-otp"
                accessibilityLabel={t.tvKodBaslik}
                style={{ position: "absolute", opacity: 0, width: 1, height: 1 }} />
              {mesgul ? <ActivityIndicator color={C.gold} style={{ marginVertical: ARA[6] }} />
                : !!hata ? <Text style={{ color: C.redInk, fontSize: FS.sm, textAlign: "center", marginVertical: ARA[4] }} accessibilityLiveRegion="polite">{hata}</Text>
                : <Text style={{ color: C.mut, fontSize: FS.xs, textAlign: "center" }}>{t.tvKodOto} · {t.tvSure}</Text>}
              <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: ARA[14] }}>
                <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} disabled={sayac > 0 || mesgul} onPress={kodGonder}>
                  <Text style={{ color: sayac > 0 ? C.mut : C.goldText, fontWeight: "700", fontSize: FS.sm }}>
                    {sayac > 0 ? String(t.tvYenidenSayac).replace("{s}", `0:${String(sayac).padStart(2, "0")}`) : t.tvYeniden}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={() => { setHata(""); setKod(""); setAsama("numara"); }}>
                  <Text style={{ color: C.mut, fontWeight: "600", fontSize: FS.sm }}>{t.tvNumaraDegistir}</Text>
                </TouchableOpacity>
              </View>
            </>
          )}

          {asama === "basari" && (
            <>
              <View style={{ width: 56, height: 56, borderRadius: R.full, backgroundColor: C.greenBg, alignItems: "center", justifyContent: "center", alignSelf: "center", marginTop: ARA[4] }}>
                <Ikon ad="tamam" boy={26} renk={C.greenInk || C.green} />
              </View>
              <Text style={[baslik, { textAlign: "center" }]} accessibilityLiveRegion="polite">{t.tvBasari}</Text>
              {sonuc && typeof sonuc.puan_sonra === "number" && (
                <View style={{ backgroundColor: C.bg, borderRadius: R.sm, padding: ARA[12], marginTop: ARA[8] }}>
                  <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                    <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.sm }}>{t.tvPuan}</Text>
                    <View style={{ flexDirection: "row", alignItems: "center", gap: ARA[4] }}>
                      <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.sm }}>{sonuc.puan_once}</Text>
                      <Ikon ad="ileri" boy={13} renk={C.mut} />
                      <Text style={{ color: C.ink, fontWeight: "700", fontSize: FS.sm }}>{sonuc.puan_sonra}</Text>
                    </View>
                  </View>
                  <View style={{ height: 7, borderRadius: R.full, backgroundColor: C.line, marginTop: ARA[8], overflow: "hidden" }}>
                    <View style={{ width: `${Math.max(2, Math.min(100, sonuc.puan_sonra))}%`, height: 7, borderRadius: R.full, backgroundColor: C.gold }} />
                  </View>
                  {typeof sonuc.esik === "number" && (
                    <Text style={{ color: C.mut, fontSize: FS.xs, marginTop: ARA[6] }}>{String(t.tvEsik).replace("{e}", String(sonuc.esik))}</Text>
                  )}
                </View>
              )}
              <View style={{ marginTop: ARA[12], gap: ARA[6] }}>
                {sonuc && sonuc.puan_sonra >= (sonuc.esik || 999) && (
                  <View style={{ flexDirection: "row", gap: ARA[8], alignItems: "center" }}>
                    <View style={{ minWidth: 26 }}><Ikon ad="tamam" boy={15} renk={C.greenInk || C.green} /></View>
                    <Text style={[govde, { flex: 1 }]}>{t.tvAcildi}</Text>
                  </View>
                )}
                <View style={{ flexDirection: "row", gap: ARA[8] }}>
                  <Text style={{ color: C.goldText, fontWeight: "700", fontSize: FS.sm, minWidth: 26 }}>+18</Text>
                  <Text style={[govde, { flex: 1 }]}>{t.tvSonraki}</Text>
                </View>
              </View>
              <Btn label={t.tvTamam} onPress={kapat} style={{ marginTop: ARA[18] }} />
            </>
          )}
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// Firebase hata kodları errMap'te; bilinmeyen kod ham gösterilmez (mapErr genel cümleye düşer).
function firebaseHataKodu(e) {
  const k = (e && (e.code || (e.message || "").match(/auth\/[a-z-]+/)?.[0])) || "";
  if (k === "auth/too-many-requests" || k === "auth/quota-exceeded") return "telefon_gunluk_sinir";
  if (k === "auth/invalid-phone-number") return "telefon_yalniz_tr_cep";
  if (k === "auth/session-expired" || k === "auth/code-expired") return "telefon_kod_suresi";
  if (k === "auth/network-request-failed") return "Network request failed";
  return k || String(e && e.message || "");
}
