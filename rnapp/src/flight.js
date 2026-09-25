// ============================================================
// LoungeLink · src/flight.js  (v1.87)
//
// UÇUŞ BİLGİSİ — ÖNCE ÖNBELLEK, GEREKİRSE TEK SEFERLİK ÇEKİM
//
// 🔴 TASARIM KARARI: uygulama sağlayıcıya ASLA doğrudan gitmez.
// AviationStack anahtarı yalnız backoffice sunucusunda durur; uygulama
// yalnızca (a) Supabase önbelleğini okur, (b) gerekirse BO rotasını
// KENDİ oturum jetonuyla çağırır. Rota kimliği doğrular ve kotayı
// uygular (SQL 091). Böylece anahtar istemciye inmez ve ayda 100
// isteklik ücretsiz kota tek bir kullanıcı tarafından yakılamaz.
//
// 🔴 VERİ YOKSA HİÇBİR ŞEY UYDURULMAZ. v1.81'de "Zamanında" yazan
// sahte bir blok yüzünden Canlı Durum tamamen kaldırılmıştı. Bu modül
// ya gerçek veriyi ya da "bilinmiyor"u döndürür; arası yok.
// ============================================================
import Constants from "expo-constants";
import { supabase, logError } from "./supabase";

const extra = (Constants?.expoConfig?.extra) || (Constants?.manifest?.extra) || {};
// Backoffice adresi. Alan adı ALMAK ZORUNDA DEĞİLİZ — Vercel'in verdiği
// *.vercel.app adresi API çağrıları için yeterlidir. Alan adı yalnızca
// e-posta bağlantıları (Supabase Site URL) için gerekli.
//
// 🔴 v2.68 — ÖLÇÜM: app.json'da `backofficeUrl: ""`. Yani BO_URL boş ve
// uçuş doğrulaması BUGÜNE KADAR HİÇ ÇALIŞMADI. Kod doğruydu, adres
// yoktu; her çağrı ilk satırda sessizce dönüyordu. "Yazılmış ama
// bağlanmamış kod, olmayan koddan kötüdür" dersinin ikinci hâli:
// bağlanmış ama YAPILANDIRILMAMIŞ kod.
//
// İki kaynak destekleniyor ki hem `eas build` hem yerel çalıştırma
// çözebilsin; ikisi de boşsa özellik SESSİZCE kapalıdır (hata yok,
// uyarı yok — uçuş numarası zaten isteğe bağlı).
// 🔴 v2.71 — ELLE ADIM KALKTI. Artık adres ÜÇ kaynaktan gelebiliyor ve
// birincisi hiçbir insan müdahalesi gerektirmiyor:
//   1. Supabase `service_endpoints()` — BO açıldığında kendini yazar (SQL 205)
//   2. `app.json → expo.extra.backofficeUrl` — geçersiz kılma
//   3. `EXPO_PUBLIC_BACKOFFICE_URL` — yerel geliştirme
// Sıralama bilinçli: 2 ve 3 DOLUYSA onlar kazanır (geliştirici kendi
// sunucusuna bakmak isteyebilir); boşsa 1 devreye girer.
const YEREL_URL = String(
  extra.backofficeUrl || process.env.EXPO_PUBLIC_BACKOFFICE_URL || ""
).replace(/\/+$/, "");

let _uzakUrl = null;          // Supabase'den okunan adres (bir kez)
let _uzakOkundu = false;

export let BO_URL = YEREL_URL;                 // geriye dönük uyum
export let FLIGHT_LOOKUP_READY = YEREL_URL.length > 0;

// Adresi çöz. İlk çağrıda Supabase'e tek bir istek atar, sonrasında
// bellekten döner. Başarısız olursa YEREL_URL'e düşer — özellik sessizce
// kapalı kalır, akış bozulmaz.
export async function backofficeUrl() {
  if (YEREL_URL) return YEREL_URL;
  if (_uzakOkundu) return _uzakUrl || "";
  try {
    const { data, error } = await supabase.rpc("service_endpoints");
    if (error) throw error;
    _uzakUrl = String(data?.backoffice_url || "").replace(/\/+$/, "");
  } catch (e) {
    _uzakUrl = "";
  }
  _uzakOkundu = true;
  BO_URL = _uzakUrl;
  FLIGHT_LOOKUP_READY = _uzakUrl.length > 0;
  return _uzakUrl;
}

export async function flightInfo(flightNo, date, { allowFetch = true } = {}) {
  const no = String(flightNo || "").trim().toUpperCase();
  if (!no || !date) return { hit: false };

  try {
    const { data, error: eFi } = await supabase.rpc("flight_info", { p_flight_no: no, p_date: date });
  if (eFi) logError("flight_info", eFi);
    if (data && data.hit) return data;

    // Önbellekte yok. Otomatik çekim kapalıysa burada dururuz.
    if (!allowFetch || !data || data.autofetch === false) return { hit: false };

    // Adres artık ÇALIŞMA ZAMANINDA çözülüyor (BO kendini kaydetmiş olabilir).
    const base = await backofficeUrl();
    if (!base) return { hit: false };

    const { data: sess, error: hata1 } = await supabase.auth.getSession();
    if (hata1) logError("flight.js:86", hata1);
    const token = sess?.session?.access_token;
    if (!token) return { hit: false };

    const res = await fetch(
      `${base}/api/flight?no=${encodeURIComponent(no)}&date=${encodeURIComponent(date)}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    if (!res.ok) return { hit: false };
    const j = await res.json();
    if (!j || !j.data) {
      // 🔴 v2.80 — KOTA REDDİ SESSİZCE "VERİ YOK" OLUYORDU.
      // Sunucu rotası kota dolduğunda 200 + {source:"quota"} dönüyor ve
      // burası onu `{hit:false}` yapıyordu. Kullanıcı açısından bu
      // "uçuşumu bulamadı" demek — yanlış numara yazdığını sanıp tekrar
      // tekrar deniyor. Oysa doğru cevap "bugünlük hakkın doldu".
      // İki durum çok farklı: biri "numarayı düzelt", öbürü "yarın dene".
      // Sınırı KALDIRMIYORUZ; yalnız görünür yapıyoruz.
      if (j && (j.source === "quota" || j.reason === "quota")) {
        return { hit: false, kota_doldu: true };
      }
      return { hit: false };
    }

    // Rota önbelleğe yazdı; kanonik biçimi almak için tekrar oku.
    const { data: again, error: eFi2 } = await supabase.rpc("flight_info", { p_flight_no: no, p_date: date });
    return (again && again.hit) ? again : { hit: false };
  } catch (e) {
    return { hit: false };   // uçuş verisi ASLA akışı bozmaz
  }
}

// "14:25 · Terminal 1 · AviationStack, 3 sa önce" — kaynak ve tazelik
// HER ZAMAN yazılır. Kaynaksız saat göstermek, uydurmakla aynı şeydir.
export function flightSummary(info, t) {
  if (!info || !info.hit) return null;
  const parts = [];
  if (info.scheduled_departure) {
    const d = new Date(info.scheduled_departure);
    if (!isNaN(d)) parts.push(d.toISOString().slice(11, 16));
  }
  if (info.terminal) parts.push(`Terminal ${info.terminal}`);
  const src = [];
  if (info.source) src.push(info.source);
  if (info.stale) src.push((t && t.flightStale) || "güncel olmayabilir");
  return {
    line: parts.join(" · "),
    source: src.join(" · "),
    stale: !!info.stale,
  };
}
