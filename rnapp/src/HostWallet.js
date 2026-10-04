// ============================================================
// LoungeLink · src/HostWallet.js  (v2.72)
//
// SALON HAKKI CÜZDANI — ürünün tek kişilik oyunu
//
// 🔴 NEDEN AYRI DOSYA VE NEDEN ÜRÜNÜN MERKEZİ:
//
// Gokberk'in kaygısı: "host çekemezsek bir işe yaramaz". Doğru kaygı,
// ama pazar yeri diliyle çözülmez. Pazar yerinin tavuk-yumurta problemi
// vardır ve tek kişilik bir kurucu onu parayla çözemez.
//
// Bizim elimizde rakipte OLMAYAN bir şey var: kural motoru. "Bu kartla,
// bu salonda, bu uçuşta ne olur?" sorusunun cevabı. Bu cevap, karşı
// tarafta HİÇ KİMSE YOKKEN DE değerli.
//
// Bu yüzden ürünün cümlesi değişiyor:
//     LoungeLink bir pazar yeri değil — bir SALON HAKKI CÜZDANI.
//     İçinde bir pazar yeri var.
//
// Cüzdan üç şey söyler ve üçünü de dünyada başka kimse söyleyemez:
//   1. Kaç hakkın var           (host_entitlements + kural motoru)
//   2. Ne zaman yanacak         (quota_period → dönem sonu)
//   3. Ne kadar ediyor          (program_plans.guest_visit_fee)
//
// Üçüncüsü kritik: kimse bugüne kadar bu kişiye "elinde 90 €'luk,
// 136 gün sonra silinecek bir varlık var" dememiş. Söyleyen ilk yer
// biz olacağız — ve o an kişi "ben host'muşum" diye öğreniyor.
//
// HOST'U İKNA ETMİYORUZ. HOST OLDUĞUNU HABER VERİYORUZ.
// ============================================================
import React, { useCallback, useEffect, useState } from "react";
import { View, Text, TouchableOpacity, ActivityIndicator, StyleSheet } from "react-native";
import { supabase } from "./supabase";
import { ARA, ELEV, C, F, FS, R, SP, T, TAP } from "./theme";
// 🔴 v2.87 — KATLANIR PANELLER. Gökberk: "Yayın > İlanlarım sayfasındaki
// cüzdan, kaçırılan ve mertebe alanları çok büyük ve yer kaplıyor."
// Ölçtüm: üç panel açılışta ~520pt yer kaplıyor, yani ilk ekran dolusunun
// tamamı — host kendi ilanını görmek için kaydırmak zorunda. İKİNCİ bir
// katlanır bileşen YAZMADIM; Pickers.js'teki Katlanir zaten bu iş için
// vardı (salon kurumları listesinde kullanılıyor). Tek fark: başlıkta
// tek satırlık özet gerekiyordu, o da oraya eklendi.
import { Katlanir } from "./Pickers";
import { MONO } from "./typography";
import { ustIsik } from "./ortak";
import { Ikon } from "./ikon";

// ------------------------------------------------------------
// Ortak kabuk — üç kartın da aynı ritmi tutması için tek yerde.
// Ritim: ETİKET (küçük, aralıklı, büyük harf) → BAŞLIK (serif) →
// ALT (gövde) → ayrıntı. Bu sıra hiçbir kartta değişmez; kimlik
// dediğimiz şey büyük ölçüde bu tekrardır.
// ------------------------------------------------------------
function Kabuk({ etiket, tint = C.goldBg, cizgi = C.goldLine, children, onPress }) {
  const Govde = onPress ? TouchableOpacity : View;
  return (
    <Govde
      onPress={onPress}
      activeOpacity={0.85}
      accessibilityRole={onPress ? "button" : undefined}
      style={{
        backgroundColor: tint,
        borderWidth: 1,
        borderColor: cizgi,
        borderRadius: R.sm,
        padding: SP[4],
        marginBottom: SP[3],
        minHeight: onPress ? TAP.minHeight : undefined,
      }}
    >
      {!!etiket && (
        <Text style={[T.label, { color: C.gold, marginBottom: SP[2] }]}>{etiket}</Text>
      )}
      {children}
    </Govde>
  );
}

function Baslik({ children }) {
  return (
    <Text style={{ fontSize: FS.lg, lineHeight: 24, color: C.ink, fontWeight: "700" }}>
      {children}
    </Text>
  );
}

function Alt({ children, color = C.body }) {
  return <Text style={[T.sm, { color, marginTop: SP[1] }]}>{children}</Text>;
}

// 🔴 KANCA, BİLEŞENLERDEN ÖNCE. İlk yazımda bunu dosyanın sonuna,
// `HostMissed`in ardına koymuştum ve check.js "HOOK SIRASI ... erken
// return SONRASINDA hook cagriliyor -> BEYAZ EKRAN riski" dedi.
// Denetim teknik olarak yanılıyordu (ayrı bir fonksiyon), ama
// söylediği düzen DOĞRU: kancalar bileşenlerden önce durur.
// Denetimi gevşetmek yerine dosyayı düzelttim — bir denetimi
// kendi rahatım için köreltmek, o denetimi bir daha asla
// güvenilir kılmamak demektir.
// ------------------------------------------------------------
// 4) KARŞILIK ANI — döngünün kapandığı yer
// ------------------------------------------------------------
// 🔴 Ürünün üç "an"ı vardı ve ÜÇÜ DE misafirin anıydı. Host hiçbir
// zaman tam ekran bir şey yaşamıyordu; arka planda çalışan bir
// altyapı gibi davranılıyordu.
//
// Bu kanca, host'un ağırlama karşılığı kredi kazandığı ilk anı
// yakalar ve bir kez gösterir. Cümle bilinçli olarak KREDİ değil,
// KARŞILIK anlatır: "3 kredi kazandın" değil, "artık sen de misafir
// olabilirsin". Aynı olay, farklı anlam.
export function useReciprocityMoment(uid) {
  const [an, setAn] = useState(null);

  useEffect(() => {
    if (!uid) return;
    let iptal = false;
    (async () => {
      const { data, error } = await supabase
        .from("credit_ledger")
        .select("id, delta, created_at")
        .eq("user_id", uid)
        .eq("reason", "hosted_session")
        .order("created_at", { ascending: false })
        .limit(1);
      if (error || iptal || !data || !data.length) return;
      const son = data[0];
      let gorulen = null;
      try {
        const AS = (await import("@react-native-async-storage/async-storage")).default;
        gorulen = await AS.getItem("ll_karsilik_son");
        if (gorulen === String(son.id)) return;
        await AS.setItem("ll_karsilik_son", String(son.id));
      } catch (e) {
        // Depolama okunamazsa anı GÖSTERME. Her açılışta tekrar eden
        // bir kutlama, kutlama olmaktan çıkıp rahatsızlığa döner.
        return;
      }
      if (gorulen === null) return;   // ilk kurulum: geçmişi kutlamayız
      if (!iptal) {
        // 5 Ekim (Gökberk md.2) — metinler TR'ye sabit yazılmıştı (EN kullanıcı Türkçe görüyordu) ve
        // altta tek başına "KARŞILIK" etiketi duruyordu (altında hiçbir şey yok → anlamsız).
        // Metin artık çağıran yerde i18n'den kuruluyor; etiket kalktı.
        setAn({ kind: "reciprocity", kredi: son.delta });
      }
    })();
    return () => { iptal = true; };
  }, [uid]);

  return [an, () => setAn(null)];
}

// ------------------------------------------------------------
// TANINMA ANI — "sen bir host'sun"
// ------------------------------------------------------------
// 🔴 Gokberk'in itirazı doğruydu: "Host olduğunu haber veriyoruz"
// güzel bir cümle ama ÖNCE onları bize gelmeye ikna etmemiz lazım.
// Haklı — bu bileşen tam o boşluğu dolduruyor.
//
// Kişi kartını YENİ tanıttı. Tam o an elindeki hakkı ilk kez bir
// SAYI olarak görüyor: "3 misafir hakkın 136 gün sonra yanıyor,
// ≈90 EUR." Bu, ikna ile haber vermenin kesiştiği tek an. Kimse
// bugüne kadar ona bunu söylemedi; söyleyen ilk yer biz oluyoruz.
//
// ⚠️ BİR KEZ gösterilir ve YALNIZ gerçek bir sayı varsa. Kota
// bilinmiyorsa an KURULMAZ — "bilmiyoruz" bir kutlama sebebi değil.
// Sahte bir kutlama, hiç kutlamamaktan kötüdür.
export function useRecognitionMoment(uid, tetik, t = {}) {
  const [an, setAn] = useState(null);

  useEffect(() => {
    if (!uid) return;
    let iptal = false;
    (async () => {
      const { data, error } = await supabase.rpc("host_wallet");
      if (error || iptal || !data || data.known !== true) return;
      if (data.toplam_kalan == null || data.toplam_kalan <= 0) return;
      try {
        const AS = (await import("@react-native-async-storage/async-storage")).default;
        if (await AS.getItem("ll_taninma")) return;
        await AS.setItem("ll_taninma", "1");
      } catch (e) { return; }
      if (iptal) return;
      // 🔴 v2.87 — BAŞLIK ARTIK KİŞİYİ ETİKETLEMİYOR, DEĞERİ SÖYLÜYOR.
      // Eski hâli "Sen bir host'sun." idi. Gökberk: "sen bir hostsun diye
      // girmek biraz marketinge uymuyor gibi." Haklı ve sebebi net: o cümle
      // kişiye YENİ BİR KİMLİK dayatıyor ("artık şusun"), oysa elimizdeki
      // gerçek bundan güçlü — cüzdanında duran ve yanmak üzere olan bir
      // varlık var. Ürünün vaadi kimlik değil, envanter.
      // Ayrıca başlık artık İKİ DİLDE: eski hâli sabit Türkçe'ydi, EN'e
      // geçen kullanıcı ürünün en önemli tek ekranını Türkçe görüyordu.
      setAn({
        kind: "recognized",
        title: String(t.momentRecognizedTitle || "Cüzdanında {n} misafir hakkı duruyor.")
          .replace("{n}", String(data.toplam_kalan)),
        subtitle: data.baslik + (data.alt ? " " + data.alt : ""),
        meta: t.momentRecognizedMeta || "CÜZDANIN AÇILDI",
      });
    })();
    return () => { iptal = true; };
  }, [uid, tetik, t.momentRecognizedTitle, t.momentRecognizedMeta]);

  return [an, () => setAn(null)];
}

// ------------------------------------------------------------
// 1) CÜZDAN
// ------------------------------------------------------------
export function HostWallet({ onAddCard, t = {} }) {
  const [w, setW] = useState(null);
  // v2.87: yerel `ac` akordeon durumu KALDIRILDI — açık/kapalı artık
  // Katlanir'ın işi. İki yerde iki "açık" bayrağı tutmak, birinin
  // diğerini sessizce ezmesi demekti.
  // 🔴 v2.78 — ÜÇ DURUMUN ÜÇÜ DE YOKTU.
  // `if (!w) return null;` — RPC düşerse kart SESSİZCE ekrandan kayboluyordu:
  // yükleniyor yok, hata yok, boş hâl yok. Host'un "tanınma anı"nın taşıyıcısı
  // bu panel; kaybolduğunda kullanıcı hiçbir şey olmadığını sanıyor.
  const [yuk, setYuk] = useState(true);
  const [hata, setHata] = useState(false);

  const yukle = useCallback(async () => {
    setYuk(true); setHata(false);
    const { data, error } = await supabase.rpc("host_wallet");
    setYuk(false);
    if (error) { setHata(true); return; }
    setW(data || null);
  }, []);
  useEffect(() => { yukle(); }, [yukle]);

  if (yuk && !w) return (
    <Kabuk etiket={t.hwWallet || "CÜZDAN"}>
      <Alt>{t.hwLoading || "Cüzdanın okunuyor…"}</Alt>
    </Kabuk>
  );
  if (hata && !w) return (
    <Kabuk etiket={t.hwWallet || "CÜZDAN"} onPress={yukle}>
      <Alt>{t.hwLoadFail || "Cüzdanın şu an okunamadı. Verilerin duruyor."}</Alt>
      <Text style={[T.sm, { color: C.gold, fontWeight: "700", marginTop: SP[3] }]}>
        {t.hwRetry || "Tekrar dene"}
      </Text>
    </Kabuk>
  );
  if (!w) return null;

  // Kart hiç yoksa: boş durum bir HATA değil, bir DAVET.
  // 🔴 Boş durumu "veri yok" diye geçmek bu üründe en pahalı hata olurdu:
  // kartını tanıtmamış kişi tam da ikna edilmesi gereken kişi.
  if (w.known !== true) {
    return (
      <Kabuk etiket={t.hwWallet || "CÜZDAN"} onPress={onAddCard}>
        <Baslik>{w.bos_baslik || t.hwEmptyTitle || "Kartını tanıt, hakkını gör."}</Baslik>
        <Alt>{w.bos_alt}</Alt>
        <Text style={[T.sm, { color: C.gold, fontWeight: "700", marginTop: SP[3] }]}>
          {t.hwAddCard || "Kartımı tanıt"}
        </Text>
      </Kabuk>
    );
  }

  const kartlar = Array.isArray(w.kartlar) ? w.kartlar : [];
  // Yanmaya en yakın hak öne çıkar; aciliyet gerçek, uydurma değil.
  const acil = w.kalan_gun != null && w.kalan_gun <= 60;

  // 🔴 v2.79 — BAŞLIK DURUMA GÖRE DEĞİŞİYOR.
  // Gökberk: "kaç misafir hakkın olduğunu bilmiyoruz alanındaki başlık
  // neden cüzdan." Haklı: o kutuda bir cüzdan ÖZETİ yok, bir EKSİK BEYAN
  // uyarısı var. "CÜZDAN" yazan bir başlık, altında "bilmiyoruz" yazan
  // bir metin — başlık içeriğe yalan söylüyor.
  // Ayrım veriden geliyor, metinden değil: her kartın kotası NULL ise
  // (yani hiçbirinde beyan yoksa) bu bir cüzdan değil, bir soru.
  const hicBeyanYok = kartlar.length > 0 && kartlar.every(k => k.kalan == null);
  const etiketMetni = hicBeyanYok
    ? (t.hwWalletUnknown || "KART HAKKIN")
    : (t.hwWallet || "CÜZDAN");

  // 🔴 v2.87 — PANEL ARTIK KATLANIR VE KAPALI BAŞLIYOR.
  // Kapanan panelin özeti `w.baslik` — sunucunun kurduğu tek cümle
  // ("12 misafir hakkın kullanılmadan duruyor" gibi). Yani kapalıyken de
  // panelin SÖYLEDİĞİ ŞEY ekranda; saklanan yalnız kart dökümü.
  // `ac` durumu artık Katlanir'ın kendi açık/kapalı durumu; ikinci bir
  // akordeon tutmak iki ayrı "açık" kavramı doğururdu.
  return (
    <Katlanir
      baslik={etiketMetni}
      bilgi={t.hwWalletInfo}
      ozet={w.baslik}
      sayi={kartlar.length || undefined}
      tint={acil ? C.amberBg : C.goldBg}
      cizgi={acil ? C.amberLine : C.goldLine}
    >
      {!!w.alt && <Alt>{w.alt}</Alt>}

      {kartlar.length > 0 && (
        <View style={{ marginTop: SP[3] }}>
          {kartlar.map((k, i) => (
            <View
              key={k.entitlement_id || i}
              style={{
                borderTopWidth: 1, borderTopColor: C.line,
                paddingTop: SP[3], marginTop: i === 0 ? 0 : SP[3],
              }}
            >
              <Text style={[T.base, { color: C.ink, fontWeight: "700" }]}>
                {k.card_label || k.program}
                {k.tier ? ` · ${k.tier}` : ""}
              </Text>
              <Text style={[T.sm, { color: C.body, marginTop: SP[1] }]}>
                {/* 🔴 BİLİNMEYEN, SIFIR DEĞİLDİR. SQL tarafında `kalan`
                    kota beyan edilmemişse NULL döner; burada da "0 hak"
                    değil "bilinmiyor" yazıyoruz. Bir sayı uydurmak,
                    kullanıcıyı kapıda utandırmanın en kısa yoludur. */}
                {k.kalan == null
                  ? (t.hwQuotaUnknown || "")
                  : String(t.hwQuotaLeft || "").replace("{k}", String(k.kalan))
                      .replace("{u}", String(k.kullanilan ?? 0)).replace("{n}", String(k.toplam))}
              </Text>
              {k.kalan_gun != null && (
                <Text style={[T.xs, { color: acil ? C.amber : C.mut, marginTop: ARA[2] }]}>
                  {String(t.hwExpiresIn || "{n} gün sonra yanıyor").replace("{n}", String(k.kalan_gun))}
                  {k.deger ? ` · ≈ ${Math.round(k.deger)} ${k.para_birimi}` : ""}
                </Text>
              )}
              <Text style={[T.xs, { color: C.dim, marginTop: ARA[2] }]}>
                {k.kaynak === "dogrulandi" ? (t.hwVerified || "Doğrulandı") : (t.hwSelfDeclared || "Senin beyanın")}
              </Text>
            </View>
          ))}
          <Text style={[T.xs, { color: C.dim, marginTop: SP[3] }]}>{w.not}</Text>

          {/* 🔴 v2.79 — GERÇEK BİR YÖNLENDİRME.
              Gökberk: "1 kartı gör'e tıklayınca ilgili sayfaya
              yönlendirmesi daha tatlı olabilir."
              Eski hâlde "→" oku vardı ama hiçbir yere gitmiyordu; aynı
              kartın içinde akordeon açılıyordu. Ok işareti bir SÖZDÜR:
              "buraya basınca bir yere gideceksin". Tutulmayan söz, ufak
              da olsa güven aşındırır — hele "doğruladık/doğrulayamadık"
              ayrımını satan bir üründe.
              Şimdi: kutuya dokunmak hızlı bakış için açıp kapatıyor,
              buradaki bağlantı ise kart ekranına GİDİYOR. */}
          {!!onAddCard && (
            <TouchableOpacity accessibilityRole="button" hitSlop={TAP.slop} onPress={onAddCard}
              style={{ marginTop: SP[3], minHeight: 44, justifyContent: "center" }}>
              <Text style={[T.sm, { color: C.gold, fontWeight: "700" }]}>
                {t.hwEditCards || "Kart hakkımı düzenle"}
              </Text>
            </TouchableOpacity>
          )}
        </View>
      )}

      {/* 🔴 v2.87 — ESKİ "{n} kartı gör ▾" SATIRI KALDIRILDI.
          Katlanir'ın kendi ▲/▼ işareti ve başlıktaki kart sayısı aynı
          şeyi söylüyordu; iki ayrı açma göstergesi kullanıcıya "hangisi
          gerçek?" sorusunu sordurur. */}
    </Katlanir>
  );
}

// ------------------------------------------------------------
// 2) MERTEBE VE KARŞILIK
// ------------------------------------------------------------
// 🔴 "500 puan kazandın" demek bu kitlenin dilini konuşmamaktır.
// Bu insanlar zaten Elite, Elite Plus, Platinum peşinde koşuyor;
// statü dilini herkesten iyi biliyorlar. "Kâhya oldun" demek
// konuşmaktır.
//
// ⚠️ AMA ayrıcalık GERÇEK olmalı. Sahte rozet, rozet olmamasından
// kötüdür. SQL 206'daki `host_tiers` her mertebeye ölçülebilir bir
// karşılık bağlıyor ve nöbetçi mutasyonla bunu kanıtlıyor.
export function HostStanding({ t = {} }) {
  const [s, setS] = useState(null);
  const [hata, setHata] = useState(false);
  useEffect(() => {
    supabase.rpc("host_standing").then(({ data, error }) => {
      if (error) { setHata(true); return; }
      setS(data || null);
    });
  }, []);
  // v2.78: hata sessiz kaybolmuyor. `known !== true` ise gerçekten veri
  // yoktur (host henüz ağırlamamış) — o hâlde kart gösterilmez, doğru.
  if (hata) return (
    <Kabuk etiket={t.hwRank || "MERTEBE"} tint={C.tealBg} cizgi={C.tealLine}>
      <Alt>{t.hwRankFail || "Mertebe bilgin şu an okunamadı."}</Alt>
    </Kabuk>
  );
  if (!s || s.known !== true) return null;

  // v2.87: kapalıyken de mertebe ADI ve ağırlama sayısı görünür —
  // bu panelin bütün kimliği o iki veri.
  const ozet = `${s.mertebe_adi} · ${s.agirlama} ${t.hwHostings || "ağırlama"}`;
  return (
    <Katlanir baslik={t.hwRank || "MERTEBE"} bilgi={t.hwRankInfo} ozet={ozet} tint={C.tealBg} cizgi={C.tealLine}>
      <Text style={{ fontSize: FS.lg, lineHeight: 24, color: C.tealInk, fontWeight: "700" }}>
        {s.mertebe_adi}
      </Text>
      <Alt>{s.mertebe_aciklama}</Alt>

      {/* KARŞILIK — ürünün asıl vaadi burada tek cümle. */}
      <View style={{ borderTopWidth: 1, borderTopColor: C.line, marginTop: SP[3], paddingTop: SP[3] }}>
        <Text style={[T.sm, { color: C.body }]}>{s.karsilik_cumlesi}</Text>
      </View>

      {s.sonraki_kalan != null && (
        <Text style={[T.xs, { color: C.mut, marginTop: SP[2] }]}>
          {String(t.hwNextTier || "{ad} olmana {n} ağırlama kaldı")
            .replace("{ad}", String(s.sonraki_adi)).replace("{n}", String(s.sonraki_kalan))}
          {s.sonraki_aciklama ? ` — ${s.sonraki_aciklama}` : ""}
        </Text>
      )}
    </Katlanir>
  );
}

// ------------------------------------------------------------
// 3) KAÇIRILAN DEĞER
// ------------------------------------------------------------
// 🔴 Bu kart host'u GERİ GETİREN tek dürüst sebep: "sen zaten
// oradaydın ve biri seni bulamadı."
//
// ⚠️ Eski `waiting_demand` havalimanındaki TÜM yolcuları sayıyordu —
// bir gösteriş sayısı. `host_missed_value` yalnız host'un gerçekten
// içeri alabileceği ve host bulamamış kişileri sayıyor. Yanlış sayı
// göstermek hiç göstermemekten kötüdür: ilk yanlışta güven biter ve
// kullanıcı bir daha hiçbir sayımıza inanmaz.
export function HostMissed({ onAdd, t = {} }) {
  const [m, setM] = useState(null);
  const [hata, setHata] = useState(false);
  useEffect(() => {
    supabase.rpc("host_missed_value", { p_gun: 30 })
      .then(({ data, error }) => {
        if (error) { setHata(true); return; }
        setM(data || null);
      });
  }, []);
  if (hata) return (
    <Kabuk etiket={t.hwMissed || "KAÇIRILAN"} tint={C.bgAlt} cizgi={C.line}>
      <Alt>{t.hwMissedFail || "Kaçırılan değer şu an hesaplanamadı."}</Alt>
    </Kabuk>
  );
  if (!m || m.known !== true || !m.kisi) return null;

  // v2.87: kapalıyken özet = sunucunun kurduğu tek cümle ("son 30 günde
  // N kişi seni bulamadı"). Panelin bütün ikna gücü o cümlede; onu
  // saklamak paneli silmekle aynı şey olurdu.
  return (
    <Katlanir baslik={t.hwMissed || "KAÇIRILAN"} bilgi={t.hwMissedInfo} ozet={m.baslik} tint={C.bgAlt} cizgi={C.line}>
      {!!m.alt && <Alt>{m.alt}</Alt>}
      <View style={{ flexDirection: "row", flexWrap: "wrap", marginTop: SP[3] }}>
        {(m.havalimanlari || []).slice(0, 4).map(h => (
          <View
            key={h.havalimani}
            style={{
              backgroundColor: C.card, borderWidth: 1, borderColor: C.line,
              borderRadius: R.full, paddingVertical: SP[1], paddingHorizontal: SP[3],
              marginRight: SP[2], marginBottom: SP[2],
             ...ELEV.card }}
          >
            <Text style={[T.xs, { color: C.body, fontWeight: "600" }]}>
              {h.havalimani} · {h.kisi}
            </Text>
          </View>
        ))}
      </View>
      {/* v2.87: eylem artık kartın TAMAMI değil kendi düğmesi. Kabuk'ta
          `onPress` kartın her yerini basılabilir yapıyordu; katlanır
          başlığın işi açıp kapatmak, gövdedeki işi ilan açmak. */}
      {!!onAdd && (
        <TouchableOpacity hitSlop={TAP.slop} onPress={onAdd}
          accessibilityRole="button"
          style={{ alignSelf: "flex-start", minHeight: TAP.minHeight, justifyContent: "center" }}>
          <Text style={[T.sm, { color: C.goldText, fontWeight: "700" }]}>{t.hwOpenAvail || "İlan aç"}</Text>
        </TouchableOpacity>
      )}
    </Katlanir>
  );
}

// ------------------------------------------------------------
// Üçü birlikte — Hosting sekmesinin başında tek satırda kullanılır.
// ------------------------------------------------------------
/* ════════════════════════════════════════════════════════════════════
   🔴 5 EYLÜL — ÜÇ KART YERİNE TEK SATIR (Gökberk madde 4, onaylı 12c):
   "Cüzdan / Kaçırılan / Mertebe boş durumda bile çok alan kaplıyor,
   ilanlarım kısmını görmek zor." Üç kutu (Akışım diliyle: mono sayı +
   versal etiket + bir satır alt bilgi), dokununca ilgili ayrıntı kartı
   altında açılır; bir daha dokununca kapanır. Ayrıntı kartları ESKİ
   bileşenlerin kendisi — davranış ve metin değişmedi, yalnız kapıları.
   Sayılar tek dalgada okunur; ayrıntı açılınca bileşen kendi okur.
   ════════════════════════════════════════════════════════════════════ */
export function HostPanel({ onAddCard, onAdd, t = {} }) {
  const [acik, setAcik] = useState(null);           // "cuzdan" | "kacirilan" | "mertebe" | null
  const [oz, setOz] = useState(null);
  useEffect(() => {
    let canli = true;
    Promise.all([
      Promise.resolve(supabase.rpc("host_wallet")).then(r => r.data, () => null),
      Promise.resolve(supabase.rpc("host_missed_value", { p_gun: 30 })).then(r => r.data, () => null),
      Promise.resolve(supabase.rpc("host_standing")).then(r => r.data, () => null),
    ]).then(([w, m, st]) => { if (canli) setOz({ w, m, st }); });
    return () => { canli = false; };
  }, []);
  const w = oz && oz.w, m = oz && oz.m, st = oz && oz.st;
  const kalan = w && w.known === true ? w.toplam_kalan : null;
  const kutular = [
    { k: "cuzdan", deger: kalan == null ? "—" : String(kalan), etiket: t.hwWallet || "CÜZDAN",
      alt: w && w.known !== true ? (t.hwAddCard || "Kartımı tanıt")
         : (w && w.kalan_gun != null ? String(t.hwExpiresIn || "{n} gün sonra yanıyor").replace("{n}", String(w.kalan_gun))
                                     : (t.hwWalletUnknown || "KART HAKKIN")) },
    { k: "kacirilan", deger: m && m.known ? String(m.kisi ?? 0) : "—", etiket: t.hwMissed || "KAÇIRILAN",
      alt: String(t.hwMissedSub || "son {n} gün").replace("{n}", String((m && m.gun) || 30)) },
    { k: "mertebe", deger: st && st.known ? (st.mertebe_adi || "—") : "—", etiket: t.hwRank || "MERTEBE",
      alt: st && st.known ? `${st.agirlama ?? 0} ${t.hwHostings || "ağırlama"}` : "" },
  ];
  return (
    <View style={{ marginBottom: SP[3] }}>
      {/* v6.3 · PANO H3 (Gökberk onayı) — ÜÇ KUTU TEK CAM ŞERİT. Hücreler sola
          hizalı: etiket + (i) · mono değer · alt satır; 1 px ışık çizgisiyle ayrılır.
          Değer TEK SATIR (Gökberk: "mertebede alta kayma ekranı büyütüyor"). */}
      <View style={{ flexDirection: "row", borderRadius: R.lg + 2, overflow: "hidden",
                     backgroundColor: C.camYuzey || C.surface || C.card, ...ustIsik(C.parlama || C.line) }}>
        {kutular.map((k, i) => {
          const sec = acik === k.k;
          const sayi = /^[0-9—]/.test(k.deger);
          return (
            <TouchableOpacity key={k.k} onPress={() => setAcik(sec ? null : k.k)} hitSlop={TAP.slop}
              accessibilityRole="button" accessibilityLabel={`${k.etiket}: ${k.deger}`}
              accessibilityState={{ expanded: sec }}
              style={{ flex: 1, minWidth: 0, minHeight: 78, paddingVertical: ARA[12], paddingHorizontal: ARA[10],
                       backgroundColor: sec ? (C.altinIz03 || "transparent") : "transparent",
                       borderLeftWidth: i === 0 ? 0 : StyleSheet.hairlineWidth, borderLeftColor: C.kenarIsik || C.line }}>
              <View style={{ flexDirection: "row", alignItems: "center" }}>
                <Text numberOfLines={1} style={{ flexShrink: 1, fontSize: FS.micro, fontWeight: "600", letterSpacing: 1.1, color: sec ? C.goldText : C.mutedAA }}>
                  {k.etiket}
                </Text>
                <Ikon ad="bilgi" boy={11} renk={C.mut} stil={{ marginLeft: ARA[4] }} />
              </View>
              <Text numberOfLines={1} style={sayi
                ? { fontFamily: MONO[500], fontSize: FS.lg + 1, lineHeight: Math.round((FS.lg + 1) * 1.3), color: C.ink, marginTop: ARA[4] }
                : { fontFamily: MONO[500], fontSize: FS.sm + 1, lineHeight: Math.round((FS.lg + 1) * 1.3), color: C.ink, marginTop: ARA[4] }}>
                {k.deger}
              </Text>
              {!!k.alt && (
                <Text numberOfLines={1} style={{ fontSize: FS.micro + 1, color: C.dim, marginTop: ARA[2] }}>{k.alt}</Text>
              )}
            </TouchableOpacity>
          );
        })}
      </View>
      {acik ? <View style={{ marginTop: SP[3] }}>
        {acik === "cuzdan" && <HostWallet onAddCard={onAddCard} t={t} />}
        {acik === "kacirilan" && <HostMissed onAdd={onAdd} t={t} />}
        {acik === "mertebe" && <HostStanding t={t} />}
      </View> : null}
    </View>
  );
}
