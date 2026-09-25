// ============================================================================
// LoungeLink · src/Pickers.js                       (v2.79 — 19 Ağustos 2026)
//
// ARANABİLİR SEÇİCİLER — TEK YERDE, DÖRT EKRANDA
//
// 🔴 NEDEN DOĞDU — GÖKBERK CİHAZDA İKİ ŞEY GÖRDÜ, İKİSİ DE AYNI KÖKTEN:
//
// 1. "hem seyahat ekleme hem de ilan ekleme sayfasında 2 defa havayolu
//    firması seçim alanı var." Ölçtüm, doğru:
//        Trips              → çip satırı (468) + droplist (479)
//        HostAvailability   → droplist (9021) + çip satırı (9220)
//        AddVisit           → SADECE çip satırı (8625)   ← üçüncüsü
//    Yani "çipi kaldır" talimatını harfiyen uygulasaydım AddVisit
//    seçicisiz kalırdı. Aynı alanın üç ekranda üç farklı hâli olması
//    zaten asıl sorun; çift görünmesi onun belirtisi.
//
// 2. "havalimanı ve havayolu droplistlerine search alanı ekle çünkü çok
//    fazla veri var." Ölçtüm: katalogda 222 havalimanı var. Ekran
//    görüntüsünde LED/LGW/LHE yan yana görünüyor — IST'e ulaşmak için
//    onlarca satır kaydırmak gerekiyor.
//
// ── TÜRKÇE ARAMA AYRI BİR İŞ ────────────────────────────────────────
// JavaScript'in `toLowerCase()`'i Türkçe bilmez: "İSTANBUL".toLowerCase()
// → "i̇stanbul" (i + birleşen nokta), yani kullanıcının yazdığı "istanbul"
// ile EŞLEŞMEZ. Aynı sınıf: "IĞDIR" → "ığdır" beklenirken "iğdır" çıkar.
// Bu yüzden aramada hem Türkçe küçültme hem de aksan sadeleştirme var:
// "Çanakkale" yazan da "canakkale" yazan da bulur.
//
// Aramayı KODA da uyguluyoruz: kullanıcıların çoğu "IST" yazıyor,
// şehir adı yazmıyor.
// ============================================================================
import React, { useMemo, useState } from "react";
import { Ikon } from "./ikon";
import { View, Text, TextInput, TouchableOpacity, ScrollView } from "react-native";
import { ARA, ELEV, C, FS, R, SP, T, TAP } from "./theme";

// 🔴 TEK NORMALLEŞTİRME FONKSİYONU. İki yerde iki farklı normalleştirme
// yazsaydım, bir liste "Çanakkale"yi bulur öbürü bulmazdı ve bu fark
// aylarca görünmezdi — arama kutusu boş sonuç döndürünce kullanıcı
// "yok galiba" der, hata bildirmez.
export function norm(s) {
  return String(s == null ? "" : s)
    .replace(/İ/g, "i").replace(/I/g, "ı")          // Türkçe büyük→küçük
    .toLocaleLowerCase("tr")
    .replace(/ı/g, "i").replace(/ğ/g, "g").replace(/ü/g, "u")
    .replace(/ş/g, "s").replace(/ö/g, "o").replace(/ç/g, "c")
    .trim();
}

// Bir kaydın aranabilir metinlerinin HERHANGİ BİRİ sorguyu içeriyorsa eşleşir.
export function eslesir(q, ...parcalar) {
  const n = norm(q);
  if (!n) return true;
  return parcalar.some(p => norm(p).includes(n));
}

// ---------------------------------------------------------------------------
// ARAMA KUTUSU — açılır listelerin başında duran ortak alan
// ---------------------------------------------------------------------------
export function AramaKutusu({ value, onChange, placeholder, sonuc, t }) {
  return (
    <View style={{ borderBottomWidth: 1, borderBottomColor: C.line, padding: SP[2] }}>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor={C.dim}
        autoCorrect={false}
        autoCapitalize="none"
        // 🔴 Klavye açıkken listeye dokunuş yutulmasın diye üst
        // ScrollView'larda keyboardShouldPersistTaps="handled" var.
        style={{
          backgroundColor: C.bgAlt, borderWidth: 1, borderColor: C.line,
          borderRadius: R.xs, paddingHorizontal: ARA[10],
          // 🔴 44px dokunma hedefi (Apple HIG). Website ölçümünde
          // 22px'lik hedefler çıkmıştı; aynı hatayı burada yapmayalım.
          minHeight: 44, color: C.body, fontSize: FS.base,
        }}
      />
      {/* Sonuç sayısını YAZIYORUZ. "Bulamadım" ile "hiç yok" arasındaki
          farkı kullanıcı görsün; sessiz boş liste en can sıkıcı hâl. */}
      {typeof sonuc === "number" && (
        <Text style={{ fontSize: FS.xs, color: sonuc ? C.dim : C.red, marginTop: SP[1], marginLeft: ARA[2] }}>
          {sonuc
            ? String(t?.searchCount || "{n} sonuç").replace("{n}", String(sonuc))
            : (t?.searchNoMatch || "Eşleşme yok")}
        </Text>
      )}
    </View>
  );
}

// ---------------------------------------------------------------------------
// HAVAYOLU SEÇİCİ — üç ekranın TEK seçicisi
//
// Çip satırı buradan çıkarıldı. Çipler hızlıydı ama:
//   · aynı alanı iki kez soruyorlardı (kullanıcı hangisi geçerli bilmiyor)
//   · listede olmayan havayolunu seçtirmiyorlardı ("Diğer" boş bırakıyordu)
//   · üç ekranda üç farklı hâlleri vardı
// Yerine: sık kullanılanlar listenin BAŞINDA (aynı hız), gerisi aramada.
// ---------------------------------------------------------------------------
const SIK = ["TK", "VF", "PC", "XQ"];   // THY · AJet · Pegasus · SunExpress

export function CarrierPicker({
  t, carriers, value, onSelect, label, hint,
}) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");

  // Sık kullanılanlar başa alınır — sıralama VERİDEN değil üründen gelir.
  const sirali = useMemo(() => {
    const liste = Array.isArray(carriers) ? carriers.slice() : [];
    liste.sort((a, b) => {
      const ia = SIK.indexOf(a.code), ib = SIK.indexOf(b.code);
      if (ia !== -1 || ib !== -1) return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
      return String(a.name || "").localeCompare(String(b.name || ""), "tr");
    });
    return liste;
  }, [carriers]);

  const gorunen = useMemo(
    () => sirali.filter(c => eslesir(q, c.name, c.code, c.alliance)),
    [sirali, q]
  );

  const sec = sirali.find(c => c.code === value);

  return (
    <View style={{ marginBottom: SP[3] }}>
      {!!label && (
        <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, marginBottom: SP[1], letterSpacing: 1 }}>
          {label}
        </Text>
      )}
      <TouchableOpacity
        hitSlop={TAP.slop}
        onPress={() => { setOpen(v => !v); setQ(""); }}
        style={{
          backgroundColor: C.bgAlt, borderWidth: 1, borderColor: open ? C.teal : C.line,
          borderRadius: R.xs, paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: 46,
          flexDirection: "row", justifyContent: "space-between", alignItems: "center",
        }}>
        <Text style={{ fontSize: FS.base, color: sec ? C.body : C.dim, flex: 1 }} numberOfLines={1}>
          {sec ? sec.name : (t?.carrierPick || "Havayolu seç…")}
        </Text>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          {/* Seçimi geri almak da bir yol olmalı; çiplerde "tekrar dokun"
              vardı, droplistte hiç yoktu. */}
          {!!sec && (
            // 🔴 30 AĞUSTOS — "APP GENELİ ÇARPI İKONLARI GENİŞLİĞİ FAZLA,
            // YAYIK DURUYOR." Sebebi burada görünüyor: bu bir İKON değil,
            // `<Text>` içinde bir U+2715 KARAKTERİ. Gövde fontu (Archivo)
            // onu kendi harf genişliğine yayıyor ve dokunma alanı yokken
            // `hitSlop` da onu görsel olarak geniş bir dikdörtgen gibi
            // gösteriyor.
            //
            // `src/ikon.js` bu dersi zaten yazmıştı: "emoji/sembol bir ikon
            // değildir — çizimini sen yapmıyorsan görüntüsünü de garanti
            // edemezsin." 505 karakter `<Ikon>`a çevrilmiş, bu biri
            // atlanmış.
            //
            // 🆕 SINIF: "BİR TARAMAYI 'HEPSİNİ ÇEVİRDİM' DİYE KAPATIRKEN,
            // TARAMANIN GÖREMEDİĞİ YERİ SOR — BU KARAKTER BİR DEĞİŞKENİN
            // İÇİNDE DEĞİL, BİR DALIN İÇİNDE SAKLIYDI."
            <TouchableOpacity hitSlop={TAP.slop} onPress={() => { onSelect(""); setOpen(false); }}
              accessibilityRole="button" accessibilityLabel={t?.clear || "Temizle"}
              style={{ width: 28, height: 28, alignItems: "center", justifyContent: "center",
                       marginRight: ARA[4] }}>
              <Ikon ad="kapat" boy={16} renk={C.mutedAA} />
            </TouchableOpacity>
          )}
          <Ikon ad={open ? "yukari" : "asagi"} boy={14} renk={C.muted} />
        </View>
      </TouchableOpacity>

      {open && (
        <View style={{ backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
                       borderRadius: R.xs, marginTop: SP[1], maxHeight: 300, overflow: "hidden" , ...ELEV.card }}>
          <AramaKutusu value={q} onChange={setQ} sonuc={gorunen.length} t={t}
            placeholder={t?.searchCarrier || "Havayolu ara…"} />
          <ScrollView nestedScrollEnabled keyboardShouldPersistTaps="handled">
            {gorunen.map((c, i) => (
              <TouchableOpacity hitSlop={TAP.slop} key={c.code || i}
                onPress={() => { onSelect(c.code); setOpen(false); setQ(""); }}
                style={{ paddingVertical: SP[3], paddingHorizontal: SP[3], minHeight: 46,
                         borderBottomWidth: 1, borderBottomColor: C.line,
                         backgroundColor: c.code === value ? C.goldSoft : "transparent" }}>
                <Text style={{ fontSize: FS.base, color: c.code === value ? C.gold : C.body,
                               fontWeight: c.code === value ? "600" : "400" }}>
                  {c.name}{c.code ? `  ·  ${c.code}` : ""}
                </Text>
                {!!c.alliance && (
                  <Text style={{ fontSize: FS.xs, color: C.dim, marginTop: ARA[2] }}>{c.alliance}</Text>
                )}
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}

      {/* 🔴 30 AĞUSTOS — AÇIKLAMA METNİ KUTUYA YAPIŞIKTI.
          Gökberk: "havalimanı alanının altındaki text, havalimanı
          kutucuğu ile bitişik halde." 6 piksel, bir alanın kenarı ile onu
          açıklayan cümle arasında ayrım kurmuyor; metin kutunun bir
          parçası gibi okunuyor. 12'ye çıkarıldı (4'ün katı, ritme uygun)
          ve satır yüksekliği de açıldı. */}
      {!!hint && (
        <Text style={{ color: C.mut, fontSize: FS.xs, lineHeight: 18, marginTop: ARA[12] }}>{hint}</Text>
      )}
    </View>
  );
}

// ---------------------------------------------------------------------------
// KATLANABİLİR BÖLÜM
//
// 🔴 Gökberk: "bu salona hangi kurumlarla giriliyor ekranı küçültülebilir
// olmalı çünkü alttaki alanlara inmesi zor oluyor."
// Ekranda 16 kurum çipi alt alta duruyordu ve altındaki alanlara
// (havayolu, misafir slotları, görünürlük) ulaşmak için uzun kaydırma
// gerekiyordu. Bilgi kaybolmuyor — istendiğinde açılıyor.
//
// Varsayılan KAPALI ama başlıkta SAYI var: kapalıyken de "burada 20 kurum
// var" bilgisi görünüyor. Sayıyı saklamak, paneli saklamaktan kötü olurdu.
// ---------------------------------------------------------------------------
// 🔴 v2.87 — ÜÇ EK: `ozet`, `tint`, `cizgi`.
// Gökberk: "cüzdan, kaçırılan ve mertebe alanları çok büyük ve yer kaplıyor.
// Bunu açılan daralan bir yapı yapamıyor muyuz."
// Katlamak tek başına yetmez: kapanan panel BİLGİ KAYBEDERSE kullanıcı onu
// bir daha hiç açmaz ve panel fiilen silinmiş olur. Bu yüzden başlığın
// altında TEK SATIRLIK özet duruyor — kapalıyken de panelin söylediği asıl
// cümle görünür. `tint`/`cizgi` ise panellerin marka rengini (altın cüzdan,
// teal mertebe) katlanır hâle geçerken kaybetmemesi için.
export function Katlanir({ baslik, sayi, ozet, tint, cizgi, children, acikBasla = false, not }) {
  const [acik, setAcik] = useState(!!acikBasla);
  return (
    <View style={{ borderWidth: 1, borderColor: cizgi || C.line, borderRadius: R.sm,
                   marginBottom: ARA[14], overflow: "hidden", backgroundColor: tint || C.card }}>
      <TouchableOpacity hitSlop={TAP.slop} onPress={() => setAcik(v => !v)}
        style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between",
                 paddingVertical: ARA[14], paddingHorizontal: SP[3], minHeight: 46 }}>
        <View style={{ flex: 1, paddingRight: SP[2] }}>
          <Text style={{ fontSize: FS.xs, fontWeight: "600", color: C.muted, letterSpacing: 1 }}>
            {baslik}{typeof sayi === "number" ? `  ·  ${sayi}` : ""}
          </Text>
          {/* Kapalıyken bilgi kaybolmasın diye özet HER ZAMAN çizilir. */}
          {!!ozet && (
            <Text numberOfLines={acik ? 3 : 2}
              style={{ fontSize: FS.sm, lineHeight: 18, color: C.body, marginTop: ARA[2] }}>
              {ozet}
            </Text>
          )}
        </View>
        <Ikon ad={acik ? "yukari" : "asagi"} boy={14} renk={C.muted} />
      </TouchableOpacity>
      {acik && (
        <View style={{ paddingHorizontal: SP[3], paddingBottom: SP[3] }}>
          {children}
          {!!not && (
            <Text style={{ fontSize: FS.xs, color: C.mut, marginTop: SP[2], lineHeight: 16 }}>{not}</Text>
          )}
        </View>
      )}
    </View>
  );
}
