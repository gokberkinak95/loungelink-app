// ============================================================
// LoungeLink · src/FlightField.js   (v2.68 — 17 Ağustos 2026)
//
// UÇUŞ NUMARASI ALANI — TEK YERDE, ÜÇ EKRANDA
//
// 🔴 NEDEN DOĞDU — ÜÇ AYRI SEBEP AYNI YERE ÇIKTI:
//
// 1. ALAN ADLARI TUTMUYORDU. Yerel pgserver harness'ında ölçtüm:
//    flight_info() `scheduled_departure/terminal/status/source` döndürüyor,
//    screens.js ise `dep_iata/arr_iata/dep_time/airline/airline_iata`
//    okuyordu. Beşinin BEŞİ de yoktu. jsonb'de olmayan anahtarı okumak
//    hata vermez, `undefined` verir: kutu açılıyor ama satırların yarısı
//    BOŞ görünüyordu. Çökme olmadığı için kimse fark etmemişti.
//    SQL 195 eksik alanları ekledi; burası artık onları okuyor.
//
// 2. ÜÇ EKRANDAN YALNIZ BİRİNDE VARDI. Uçuş numarası dört yerde
//    giriliyor (seyahat ekleme, seyahat modalı, ilan açma, düzenleme)
//    ama doğrulama+önizleme YALNIZCA seyahat ekleme ekranında bağlıydı.
//    Aynı davranışı dört yere kopyalamak yerine tek bileşen.
//
// 3. KOD PAYLAŞIMLI UÇUŞ. Bilette yazan havayolu ile uçağı uçuran
//    havayolu farklı olabilir ve salon hakkı UÇURANA bağlıdır.
//    flight_info() artık bunu söylüyor; kullanıcı kapıda değil burada
//    öğrenmeli.
//
// 🔴 UÇUŞ NUMARASI HER YERDE İSTEĞE BAĞLIDIR. Etiket bunu yazar
// ("UÇUŞ (İSTEĞE BAĞLI)"), boş bırakılınca hiçbir kapı kapanmaz, hiçbir
// uyarı çıkmaz. Yazan kullanıcı ekstra bilgi kazanır; yazmayan hiçbir
// şey kaybetmez. Kural motoru zaten uçuş numarası olmadan da çalışır ve
// "uçuşunu eklersen kesin cevabı veririz" der.
//
// 🔴 VERİ YOKSA HİÇBİR ŞEY UYDURULMAZ (v1.81 dersi). Kutu ya gerçek
// veriyle ya da hiç açılmaz. "Zamanında" yazan sahte blok yüzünden
// Canlı Durum bir kez tamamen kaldırılmıştı.
// ============================================================
import React, { useState } from "react";
import { View, Text, TextInput, TouchableOpacity } from "react-native";
import { ARA, ELEV, C, FS, R, SP, T, TAP } from "./theme";
import { flightInfo } from "./flight";
import { IkonMetin } from "./ikon";

const CARRIERS = [["TK", "THY"], ["VF", "AJet"], ["PC", "Pegasus"], ["XQ", "SunExpress"]];

// YYYY-AA-GG tam mı — yarım tarihle sağlayıcıya gitmenin anlamı yok
// (ve kota yakar). BO rotası da aynı biçimi bekliyor.
const dateReady = (d) => typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d);

export default function FlightField({
  t,
  value,                 // uçuş numarası (string)
  onChange,              // (yeniDeğer) => void
  date,                  // "YYYY-AA-GG" — yoksa sorgu yapılmaz
  carrier,               // seçili havayolu kodu (opsiyonel)
  onCarrier,             // (kod) => void — verilmezse çipler gizlenir
  showChips = true,
  labelStyle,
  inputStyle,
  hideLabel = false,
  // 🔴 "Elle girildi — uçuşla eşleştirmedik" uyarısı. YALNIZCA numara
  // yazılmış AMA doğrulanmamışsa çıkar. Doğrulanınca çıkmaz: doğrulanmış
  // bir uçuşa "eşleştirmedik" demek yalan olurdu.
  manualWarn = null,
  // v6.3 · seyahat sihirbazı — sorgu sonucu dışarı verilir (kalkış/varış/havayolu
  // otomatik dolsun diye). Sonuç yoksa null. Verilmezse davranış değişmez.
  onInfo = null,
}) {
  const [info, setInfo] = useState(null);
  const [busy, setBusy] = useState(false);
  const [kota, setKota] = useState(false);

  const txt = String(value || "");

  async function lookup() {
    // 🔴 v2.71 — BO ADRESİ KONTROLÜ BURADAN KALKTI, ÇÜNKÜ FAZLA SIKIYDI.
    // `flightInfo` ÖNCE Supabase önbelleğini okur; o okuma BO adresi
    // olmadan da çalışır ve başka bir kullanıcı aynı uçuşu sorduysa
    // veri ZATEN oradadır. Eski hâlde adres boşken önbellek bile
    // okunmuyordu — elimizdeki veriyi kendi kapımızda durduruyorduk.
    // Adres kontrolü artık doğru yerde: yalnız uzak çekim anında.
    //
    // İKİ SESSİZ ÇIKIŞ kaldı: numara boşsa, tarih yarımsa. İkisi de
    // hata DEĞİL — uçuş numarası her yerde isteğe bağlı.
    if (!txt.trim() || !dateReady(date)) { setInfo(null); return; }
    setBusy(true);
    try {
      const r = await flightInfo(txt.trim(), date);
      setInfo(r && r.hit ? r : null);
      if (onInfo) onInfo(r && r.hit ? r : null);
      // 🔴 v2.80 — GÜNLÜK SORGU KOTASI ARTIK GÖRÜNÜR.
      // Kota dolduğunda kullanıcı "uçuşum bulunamadı" görüyordu ve
      // numarayı yanlış yazdığını sanıp tekrar tekrar deniyordu. Sessiz
      // bir sınır, kullanıcıyı kendinden şüphe ettirir.
      // Sınır KALKMIYOR — uçuş numarası zaten isteğe bağlı, akış bozulmuyor.
      setKota(!!(r && r.kota_doldu));
    } catch (e) {
      setInfo(null);           // uçuş verisi ASLA akışı bozmaz
      setKota(false);
    }
    setBusy(false);
  }

  const depArr = info ? [info.dep_iata, info.arr_iata].filter(Boolean).join(" → ") : "";
  const depClock = info && info.dep_time ? String(info.dep_time).slice(11, 16) : "";
  // İkinci satır: kalkış→varış · saat · durum. Hiçbiri yoksa satır hiç basılmaz.
  const line2 = [depArr, depClock, info && info.status].filter(Boolean).join(" · ");
  // 🔴 Kod paylaşımında GÖSTERİLECEK taşıyıcı işletendir, pazarlayan değil.
  const suggested = info ? (info.operating_iata || info.airline_iata || null) : null;

  return (
    <View>
      {showChips && !!onCarrier && (
        <>
          <Text style={[{ ...T.label, color: C.mut, marginBottom: ARA[6] }, labelStyle]}>
            {t.carrierLabel}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: ARA[6], marginBottom: ARA[10] }}>
            {CARRIERS.map(([cd, lb]) => {
              const on = txt.toUpperCase().startsWith(cd) || carrier === cd;
              return (
                <TouchableOpacity hitSlop={TAP.slop}
                  key={cd}
                  accessibilityRole="button"
                  accessibilityLabel={lb}
                  onPress={() => {
                    onChange(cd + txt.replace(/^[A-Za-z]+/, ""));
                    onCarrier(cd);
                  }}
                  style={{
                    ...TAP, justifyContent: "center",
                    paddingHorizontal: ARA[14], borderRadius: R.full, borderWidth: 1,
                    borderColor: on ? C.gold : C.line,
                    backgroundColor: on ? C.goldSoft : C.card,
                  }}>
                  <Text style={{ fontSize: FS.sm, color: on ? C.gold : C.ink, fontWeight: on ? "700" : "400" }}>
                    {lb}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </>
      )}

      {!hideLabel && (
        <Text style={[{ ...T.label, color: C.mut, marginBottom: ARA[6] }, labelStyle]}>{t.flight}</Text>
      )}
      <TextInput
        style={[{
          borderWidth: 1, borderColor: C.line, borderRadius: R.xs,
          paddingHorizontal: SP[3], paddingVertical: ARA[10], fontSize: FS.base,
          color: C.ink, backgroundColor: C.card, minHeight: TAP.minHeight,
         ...ELEV.card }, inputStyle]}
        value={txt}
        onChangeText={(x) => onChange(x.toUpperCase())}
        onBlur={lookup}
        onSubmitEditing={lookup}
        returnKeyType="search"
        placeholder="TK712"
        placeholderTextColor={C.dim}
        autoCapitalize="characters"
        accessibilityLabel={t.flight}
      />

      {busy && (
        <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: SP[1] }}>{t.flightChecking}</Text>
      )}

      {/* 🔴 v2.80 — KOTA UYARISI. Kullanıcı "bulamadım" ile "hakkın
          doldu" arasındaki farkı görsün; ikisinde yapacağı şey farklı. */}
      {kota && !busy && (
        <View style={{ backgroundColor: C.amberBg, borderWidth: 1, borderColor: "transparent",
                       borderRadius: R.xs, padding: ARA[10], marginTop: ARA[6] }}>
          <Text style={{ fontSize: FS.sm, color: C.amberInk, fontWeight: "700" }}>
            {t?.flightQuotaTitle || "Günlük uçuş sorgu hakkın doldu"}
          </Text>
          <Text style={{ fontSize: FS.xs, color: C.body, marginTop: SP[1], lineHeight: 16 }}>
            {String(t?.flightQuotaBody || "").replace("{n}", "")}
          </Text>
        </View>
      )}
      {!!manualWarn && !busy && !info && !kota && !!txt.trim() && (
        <IkonMetin ad="uyari" renk={C.amberInk} stilMetin={{ fontSize: FS.xs, color: C.amberInk, marginTop: SP[1] }} metin={manualWarn} />
      )}

      {!!info && (
        <View style={{
          backgroundColor: C.tealBg, borderWidth: 1, borderColor: "transparent",
          borderRadius: R.xs, padding: ARA[10], marginTop: ARA[6],
        }}>
          <Text style={{ ...T.label, color: C.tealInk, marginBottom: ARA[2] }}>
            {info.airline || txt.trim().toUpperCase()}
          </Text>
          {!!line2 && (
            <Text style={{ fontSize: FS.sm, color: C.body, lineHeight: 18 }}>{line2}</Text>
          )}
          {/* 🔴 KOD PAYLAŞIMI: kapıda değil burada öğrensin */}
          {!!info.codeshare && !!info.carrier_note && (
            <IkonMetin ad="uyari" renk={C.amber} stilMetin={{ fontSize: FS.sm, color: C.amber, lineHeight: 17, marginTop: ARA[6] }} metin={info.carrier_note} />
          )}
          {!!suggested && !!onCarrier && suggested !== carrier && (
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => onCarrier(suggested)}
              style={{ ...TAP, justifyContent: "center", marginTop: SP[1] }}
              accessibilityRole="button">
              <Text style={{ color: C.teal, fontWeight: "700", fontSize: FS.sm }}>
                {t.useThisCarrier} ({suggested})
              </Text>
            </TouchableOpacity>
          )}
          {/* Kaynak ve tazelik HER ZAMAN yazılır — kaynaksız saat, uydurma saattir */}
          <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: ARA[6] }}>
            {[info.source, info.stale ? t.flightStale : null].filter(Boolean).join(" · ")}
          </Text>
        </View>
      )}
    </View>
  );
}
