// ============================================================================
// push.js — BİLDİRİM İZNİ (v2.98 · eleştiri G7)
//
// 🔴 ÖNCEKİ HÂLİ NEYDİ VE NEDEN YETMİYORDU — ÖLÇEREK:
//
//   (1) `registerPush()` ÜÇ yerden çağrılıyordu (App.js:100, App.js:144,
//       App.js:564) ve ÜÇÜ DE işletim sisteminin izin penceresini AÇIYORDU.
//       İlki kayıttan hemen sonra: kullanıcı tek bir salon bile görmeden
//       "LoungeLink bildirim göndermek istiyor" penceresiyle karşılaşıyordu.
//       iOS bu pencereyi ÖMÜR BOYU BİR KEZ gösterir. Yani ürünün en değerli
//       tek seferlik kartını, kullanıcının ürünü hiç görmediği anda oynuyorduk.
//
//   (2) Fonksiyondaki HER çıkış yolu çıplak `return` ve hepsi tek bir
//       `try { } catch (e) { }` içindeydi. Dört sonucun — verildi ·
//       reddedildi · cihaz desteklemiyor · token alınamadı — HİÇBİRİ
//       hiçbir yere yazılmıyordu. "Kaç kullanıcıya ulaşabiliyoruz?"
//       sorusunun cevabı bilinmiyordu; bilinmemesinin sebebi de kullanıcı
//       değil, ÖLÇÜM NOKTASININ OLMAMASIYDI.
//
//   (3) `canAskAgain` hiç okunmuyordu. iOS'ta bir kez "İzin Verme" denince
//       `requestPermissionsAsync` ömür boyu anında reddedilmiş döner. App
//       bunu her girişte tekrar çağırıyordu: hiçbir şey olmuyor, kimse
//       Ayarlar'a yönlendirilmiyordu. Yani reddin bir GERİ DÖNÜŞÜ yoktu.
//
// ----------------------------------------------------------------------------
// BU DOSYANIN TAŞIDIĞI TEK KURAL
// ----------------------------------------------------------------------------
// 🔵 İZİN PENCERESİNİ AÇABİLEN TEK FONKSİYON `pushIzniIste()`DİR ve o da
//    YALNIZCA kullanıcı bir düğmeye bastığında çağrılır. Açılışta çağrılan
//    `pushDurumOku()` pencereyi ASLA açmaz; yalnız mevcut durumu okur ve
//    sunucuya bildirir.
//
// 🆕 SINIF: "ÖMÜR BOYU BİR KEZ SORULABİLEN BİR SORUYU, CEVABIN DEĞERİNİN
// HENÜZ ANLAŞILMADIĞI ANDA SORMAK, SORUYU HARCAMAKTIR."
// ============================================================================
import * as Notifications from "expo-notifications";
import * as Device from "expo-device";
import { Linking, Platform } from "react-native";
import Constants from "expo-constants";
import { logError, supabase } from "./supabase";
import { C } from "./theme";   // bildirim kanalı ışık rengi paletten

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true, shouldPlaySound: true, shouldSetBadge: true,
  }),
});

// İşletim sisteminin durumu → bizim kaydettiğimiz durum.
// 'undetermined' HENÜZ SORULMADI demektir; bunu 'reddedildi' saymak
// kullanıcıya yapmadığı bir tercihi atfetmek olurdu.
function durumCevir(status) {
  if (status === "granted") return "verildi";
  if (status === "denied") return "reddedildi";
  return "sorulmadi";
}

async function sunucuyaBildir(durum, tekrar, soruldu) {
  try {
    const { error } = await supabase.rpc("push_izni_bildir", {
      p_durum: durum,
      p_tekrar_sorulabilir: tekrar !== false,
      p_platform: Platform.OS,
      p_soruldu: !!soruldu,
    });
    // 🔴 YUTMUYORUZ. Bu çağrı düşerse ölçüm körleşir; sessizce körleşen
    // bir ölçüm, yanlış ölçümden daha tehlikelidir.
    if (error) logError("push_izni_bildir", error);
  } catch (e) { logError("push_izni_bildir", e); }
}

// Son token denemesinin nedeni: null (başarılı) | "fcm_yok" | "ag" | "sunucu" | "bilinmiyor"
let _tokenNeden = null;

async function tokenKaydet() {
  try {
    if (Platform.OS === "android") {
      // ══════════════════════════════════════════════════════════
      // 🔴 30 AĞUSTOS · 6. TUR — TEK KANAL, ÜÇ KANAL OLDU.
      //
      // Tek bir "default" kanal vardı. Android'de kanal, kullanıcının
      // SUSTURMA BİRİMİDİR: tek kanalda kullanıcı "kampanya gelmesin"
      // diyemez — ya hepsini kapatır ya hepsini açar. Ölçüldü:
      // ürün 8 kategoride bildirim gönderiyor (requests · sessions ·
      // safety · connections · invites · credits · ratings · system)
      // ve hepsi aynı sesle çalıyordu.
      //
      // Üçe ayrıldı, önem sırasına göre:
      //   guvenlik → oturum ve güvenlik (susturulamaz olmalı)
      //   akis     → istek/bağlantı/davet (ürünün kalbi)
      //   diger    → kredi/puan/duyuru (sessiz)
      //
      // 🆕 SINIF: "TEK KANAL, KULLANICIYA 'HEPSİ YA DA HİÇBİRİ'
      // DEMEKTİR — VE İNSANLAR O SORUYA HEP 'HİÇBİRİ' DER."
      //
      // ⚠️ `default` KANAL SİLİNMİYOR: eski sürümlerin gönderdiği
      // bildirimler ona düşüyor ve Android bir kanalı silince o
      // kanalın kullanıcı ayarı da gider.
      const KANALLAR = [
        ["default",  "LoungeLink",        Notifications.AndroidImportance.HIGH],
        ["guvenlik", "Oturum ve güvenlik", Notifications.AndroidImportance.HIGH],
        ["akis",     "İstek ve bağlantı",  Notifications.AndroidImportance.HIGH],
        ["diger",    "Kredi ve duyuru",    Notifications.AndroidImportance.DEFAULT],
      ];
      for (const [id, ad, onem] of KANALLAR) {
        await Notifications.setNotificationChannelAsync(id, {
          name: ad,
          importance: onem,
          // Gece sisteminin altını (#E0BE7A). Eskiden AÇIK temanın
          // altını (#B8943A) yazıyordu — koyu bildirim gölgesinde
          // çamurlu okunuyordu ve ürünün hiçbir yerinde o renk yok.
          lightColor: C.gold,
        });
      }
    }
    // ══════════════════════════════════════════════════════════════════
    // 🔴 v3.8 — `projectId` AÇIKÇA VERİLİYOR.
    //
    // `getExpoPushTokenAsync()` argümansız çağrıldığında kütüphane
    // proje kimliğini `Constants.expoConfig.extra.eas.projectId`den
    // ÇÖZMEYE ÇALIŞIR. Expo Go'da ve `expo start`ta bu çözüm çalışır;
    // EAS ile üretilen bir pakette ise yapılandırmanın nasıl gömüldüğüne
    // bağlıdır ve çözülemezse fonksiyon
    //     "No 'projectId' found. ..."
    // diye FIRLATIR. Bizde o hata `catch`e düşüp `logError` ile
    // yazılıyor ve `false` dönüyordu: yani izin VERİLMİŞ ama TOKEN YOK.
    // Sunucu tarafında bu "izin verdi ama ulaşamıyoruz" olarak görünür
    // ve sebebi hiçbir yerde yazmaz.
    //
    // Kimlik zaten `app.json → expo.extra.eas.projectId` içinde duruyor;
    // okumak bedava, tahmin ettirmek riskli.
    //
    // 🆕 SINIF: "BİR KÜTÜPHANEYE DEĞERİ KENDİ BULDURMAK, GELİŞTİRMEDE
    // ÇALIŞIP ÜRETİMDE DÜŞEN BİR BAĞIMLILIKTIR — ELİNDE OLANI VER."
    const projectId =
      Constants?.expoConfig?.extra?.eas?.projectId ||
      Constants?.easConfig?.projectId ||
      Constants?.manifest?.extra?.eas?.projectId ||
      undefined;
    const token = (await Notifications.getExpoPushTokenAsync(
      projectId ? { projectId } : undefined,
    )).data;
    if (!token) { _tokenNeden = "bilinmiyor"; return false; }
    const { error } = await supabase.rpc("save_push_token", {
      p_token: token, p_platform: Platform.OS,
    });
    if (error) { logError("save_push_token", error); _tokenNeden = "sunucu"; return false; }
    _tokenNeden = null;
    return true;
  } catch (e) {
    // 🔴 3 EYLÜL — NEDEN AYRIŞTIRILIYOR. Cihazda "İzin verildi ama cihazın
    // kaydedilemedi. İnterneti kontrol et" yazıyordu; internet AÇIKTI.
    // Gerçek sebep Android'de `google-services.json` olmadan derlenen
    // APK: `getExpoPushTokenAsync` "Default FirebaseApp is not
    // initialized" ile düşer. Kullanıcıya interneti kontrol ettirmek
    // yanlış teşhisti. Mesaj artık sebebe göre; sebep BO Hata Kaydı'na
    // da ham metniyle düşüyor (`push_token_al`, kod = neden).
    const m = String(e && e.message ? e.message : e);
    _tokenNeden = /FirebaseApp|google-services|FCM|Firebase/i.test(m) ? "fcm_yok"
      : /network|fetch|timeout|ECONN/i.test(m) ? "ag"
      : "bilinmiyor";
    logError("push_token_al", e, _tokenNeden);
    return false;
  }
}
export function pushTokenNedeni() { return _tokenNeden; }

// ----------------------------------------------------------------------------
// AÇILIŞTA ÇAĞRILIR — PENCERE AÇMAZ.
// Her açılışta çağrılması BİLEREKTİR: kullanıcı izni sonradan telefon
// ayarlarından kapatabilir ve o an bize hiçbir şey gelmez. Her açılışta
// durum bildirmek, o deliği kapatan tek ucuz yoldur (sunucu izin yoksa
// token'ı pasife alır).
// ----------------------------------------------------------------------------
export async function pushDurumOku() {
  try {
    if (!Device.isDevice) {
      await sunucuyaBildir("desteklenmiyor", false, false);
      return { durum: "desteklenmiyor", tekrar: false, token: false };
    }
    const p = await Notifications.getPermissionsAsync();
    const durum = durumCevir(p && p.status);
    const tekrar = p && p.canAskAgain !== false;
    let token = false;
    if (durum === "verildi") token = await tokenKaydet();
    await sunucuyaBildir(durum, tekrar, false);
    return { durum, tekrar, token, tokenNeden: token ? null : _tokenNeden };
  } catch (e) {
    logError("push_durum_oku", e);
    return { durum: "bilinmiyor", tekrar: true, token: false };
  }
}

// ----------------------------------------------------------------------------
// YALNIZCA KULLANICI BİR DÜĞMEYE BASTIĞINDA ÇAĞRILIR.
// Dönüşteki `ayarlarGerekli`, "düğme hiçbir şey yapmadı" hâlini ortadan
// kaldırır: sistem artık soramıyorsa arayüz Ayarlar'a yönlendirir.
// ----------------------------------------------------------------------------
export async function pushIzniIste() {
  try {
    if (!Device.isDevice) {
      await sunucuyaBildir("desteklenmiyor", false, false);
      return { durum: "desteklenmiyor", ayarlarGerekli: false, token: false };
    }
    const mevcut = await Notifications.getPermissionsAsync();
    let status = mevcut && mevcut.status;
    let tekrar = mevcut && mevcut.canAskAgain !== false;

    if (status !== "granted" && tekrar) {
      const r = await Notifications.requestPermissionsAsync();
      status = r && r.status;
      tekrar = r && r.canAskAgain !== false;
    }

    const durum = durumCevir(status);
    let token = false;
    if (durum === "verildi") token = await tokenKaydet();
    await sunucuyaBildir(durum, tekrar, true);
    return { durum, ayarlarGerekli: durum !== "verildi" && !tekrar, token, tokenNeden: token ? null : _tokenNeden };
  } catch (e) {
    logError("push_izni_iste", e);
    return { durum: "bilinmiyor", ayarlarGerekli: false, token: false };
  }
}

export async function bildirimAyarlariniAc() {
  // 🔴 3 EYLÜL — Android'de DOĞRUDAN "LoungeLink → Bildirimler" sayfası
  // (APP_NOTIFICATION_SETTINGS). `openSettings` uygulamanın genel ayar
  // sayfasını açıyordu; kullanıcı oradan bildirimleri kendisi bulmak
  // zorundaydı (Gökberk: "telefonumun ayarlarından loungelinkin bildirim
  // ayarlarına yönlenmeliyim"). iOS'ta tek yol `openSettings` (uygulamanın
  // sayfasını açar; bildirim anahtarı ilk satırdadır).
  try {
    if (Platform.OS === "android" && Linking && typeof Linking.sendIntent === "function") {
      const paket = (Constants?.expoConfig?.android?.package) || "com.loungelink.app";
      try {
        await Linking.sendIntent("android.settings.APP_NOTIFICATION_SETTINGS", [
          { key: "android.provider.extra.APP_PACKAGE", value: paket },
          { key: "app_package", value: paket },
        ]);
        return true;
      } catch (e) { /* eski Android: genel sayfaya düş */ }
    }
    if (Linking && typeof Linking.openSettings === "function") {
      await Linking.openSettings();
      return true;
    }
  } catch (e) { logError("push_ayarlar_ac", e); }
  return false;
}

// 🔵 GERİYE DÖNÜK AD — ama davranışı DEĞİŞTİ: artık pencere AÇMAZ.
// Eski çağrı yerlerinden biri gözden kaçarsa, en kötü ihtimalle durum
// okunur; kullanıcıya izinsiz pencere AÇILAMAZ.
export const registerPush = pushDurumOku;
