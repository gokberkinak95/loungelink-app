import React from "react";
import { View, Text, TouchableOpacity, ScrollView } from "react-native";
import { ARA, C, FS, R, S, SP, T, TAP } from "./theme";
import { logError } from "./supabase";

/**
 * ============================================================
 * HATA SINIRI (v2.39)
 *
 * ⚠️ BU DOSYA `Btn` KULLANMIYOR VE BU BİLİNÇLİ BİR İSTİSNA.
 * 24 düz düğmeyi onaylanan sisteme çevirirken buradaki de çevrildi;
 * geri aldım. `Btn` → `ui.js` → `atmosfer.js` + `i18n.js` + görsel
 * varlıklar zincirini getiriyor. Hata ekranının, ÇÖKEBİLECEK bir
 * zincire bağlanması bu dosyanın ilk kuralının ihlalidir: çökmeyi
 * gösteren ekran, çökmeye sebep olan şeye bağlı olamaz.
 *
 * 🆕 SINIF: "TASARIM SİSTEMİNİ HER YERE UYGULAMAK BİR HEDEFTİR, KURAL
 * DEĞİL — SON ÇARE EKRANLARI BAĞIMSIZ KALMALIDIR."
 *
 * 🔴 NEDEN: bugüne kadar hiç yoktu. React ağacında bir bileşen
 * fırlatırsa React TÜM ağacı söküyor — kullanıcı BEYAZ EKRAN
 * görüyor, uygulamayı kapatmaktan başka seçeneği kalmıyor, ve
 * biz hiçbir şey öğrenmiyoruz.
 *
 * Beyaz ekran, kullanıcının bize hiçbir şey söylemeden gittiği
 * andır. Elimizde `app_errors` tablosu ve `logError` zaten vardı;
 * eksik olan onları çöküş anına bağlamaktı.
 *
 * İKİ İŞ YAPAR:
 *  1. Hatayı sunucuya yazar (kişisel veri YOK: ekran + mesaj + sürüm)
 *  2. Kullanıcıya ÇIKIŞI OLAN bir ekran gösterir — "tekrar dene"
 *
 * Neden "tekrar dene" yeterli: React hatası genelde tek bir
 * render'ın bozuk state'inden gelir; ağacı sıfırlamak çoğu durumda
 * çözer. Uygulamayı kapattırmak son çare olmalı, ilk teklif değil.
 * ============================================================
 */
export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { err: null, count: 0 };
  }

  static getDerivedStateFromError(err) {
    return { err };
  }

  componentDidCatch(err, info) {
    // Sessiz ve akışı bozmayan kayıt — logError asla throw etmez.
    logError(
      "crash",
      (err && err.message) || String(err),
      (info && info.componentStack || "").split("\n")[1]?.trim().slice(0, 60)
    );
  }

  reset = () => {
    // 🔴 SAYAÇ ARTIYOR: aynı hata üst üste geliyorsa "tekrar dene"
    // işe yaramıyor demektir ve kullanıcıyı sonsuz döngüde tutmak
    // yardım değil, işkencedir. İkinci denemeden sonra dürüst ol.
    this.setState(s => ({ err: null, count: s.count + 1 }));
  };

  render() {
    if (!this.state.err) return this.props.children;

    const t = this.props.t || {};
    const stuck = this.state.count >= 2;

    return (
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", padding: ARA[26] }}>
        {/* 🔴 30 AĞUSTOS · 3. TUR — EMOJİ GİTTİ, AMA `Ikon` DA GELMEDİ.
            `⚠️` emojisi bu ekranda da yanlıştı (çizimi cihaza ait). Ama
            yerine `<Ikon>` koymak bu dosyanın İLK KURALINI çiğnerdi:
            "çökmeyi gösteren ekran, çökmeye sebep olabilecek şeye
            bağlı olamaz." `Ikon` bir font yüklüyor ve tam bu turda o
            fontun yüklenememesinin bütün ikonları sildiğini gördük.

            🆕 SINIF: "SON ÇARE EKRANI, SİSTEMİN EN AZ BAĞIMLI PARÇASI
            OLMALIDIR — ORADA TASARIM TUTARLILIĞI, ÇALIŞMA GARANTİSİNİN
            ARKASINDA GELİR."

            Üçgen üç `View` ile çiziliyor: font yok, paket yok. */}
        <View style={{ width: 34, height: 30, marginBottom: ARA[10] }}>
          <View style={{ position: "absolute", left: 0, top: 0, width: 0, height: 0,
                         borderLeftWidth: 17, borderRightWidth: 17, borderBottomWidth: 30,
                         borderLeftColor: "transparent", borderRightColor: "transparent",
                         borderBottomColor: C.amber }} />
          <View style={{ position: "absolute", left: 16, top: 11, width: 2, height: 10,
                         backgroundColor: C.bg }} />
          <View style={{ position: "absolute", left: 16, top: 24, width: 2, height: 2,
                         backgroundColor: C.bg }} />
        </View>
        {/* 🔴 30 Ağustos — `T.h1` DİYE BİR TİPOGRAFİ YOK, HİÇ OLMADI.
            `{...undefined}` bir hata değil: hiçbir şey yaymaz. Yani
            ÇÖKME EKRANININ BAŞLIĞI, uygulamanın en kritik metni,
            gövde punto ve normal kalınlıkta çiziliyordu — bunu gören
            kullanıcı zaten bir hatanın içinde, üstelik başlığı
            gövdeden ayıramıyor. Doğru anahtar `T.title`. */}
        <Text style={{ ...T.title, color: C.ink, marginBottom: SP[2] }}>
          {t.crashTitle || "Bir şeyler ters gitti"}
        </Text>
        <Text style={{ fontSize: FS.base, lineHeight: 21, color: C.body, marginBottom: ARA[20] }}>
          {stuck
            ? (t.crashStuck ||
               "Sorun devam ediyor. Uygulamayı tamamen kapatıp yeniden açmayı dene. Bu hatayı biz de gördük ve üzerinde çalışıyoruz.")
            : (t.crashBody ||
               "Beklenmeyen bir hata oldu. Hatayı kaydettik. Tekrar denemek genelde çözer.")}
        </Text>

        {!stuck && (
          <TouchableOpacity hitSlop={TAP.slop} onPress={this.reset}
            style={{ backgroundColor: C.goldBtn, borderRadius: R.md, paddingVertical: ARA[14], alignItems: "center" }}>
            <Text style={{ color: C.onAccent, fontWeight: "700", fontSize: FS.base }}>
              {t.crashRetry || "Tekrar dene"}
            </Text>
          </TouchableOpacity>
        )}

        {/* Hata metnini kullanıcıya GÖSTERMİYORUZ: teknik yığın izi
            kimseye yardım etmez, yalnız kaygı yaratır. Sunucuda var. */}
      </ScrollView>
    );
  }
}
