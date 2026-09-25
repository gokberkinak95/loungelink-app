// ============================================================================
// KATALOG ÖNBELLEĞİ  (v3.4)
//
// 🔴 NEDEN VAR — ÖLÇÜLDÜ
// Gökberk (28 Ağu): "APP tarafında da performans artışı yapmamız lazım.
// Bir tık yavaş şu an."
//
// Kodu taradım. `airports` tablosu (222 satır) BEŞ ayrı ekrandan
// çekiliyordu ve her biri ekran her açıldığında yeniden:
//     ekranlar_ana.js:414 · ekranlar_ana.js:1639 · screens.js:92
//     screens.js:656      · screens.js:2752
// `carrier_options` RPC'si de ÜÇ yerden.
//
// Bu listeler AYDA BİR değişir — havalimanı eklemek bizim yaptığımız bir
// iştir, kullanıcının değil. Yani uygulama, bir yıldır aynı olan bir
// listeyi kullanıcı her sekme değiştirdiğinde yeniden indiriyordu.
//
// Ve sekme değiştirmek gerçekten yeniden indirmek demek: uygulamada
// `{tab === "meet" && <Meet/>}` deseni var, yani sekme değişince ekran
// SÖKÜLÜP yeniden kuruluyor ve her `useEffect(..., [])` yeniden koşuyor.
//
// 🆕 SINIF: "DEĞİŞMEYEN BİR LİSTEYİ HER EKRAN AÇILIŞINDA ÇEKMEK BİR AĞ
// SORUNU DEĞİL, 'BU VERİ NE KADAR SÜRE DOĞRU KALIR' SORUSUNUN HİÇ
// SORULMAMASIDIR."
//
// ⚠️ TAZELİK BEDELİ AÇIKÇA YAZILI: bir havalimanı/havayolu BO'dan
// eklendiğinde uygulamada en geç `TTL` kadar sonra görünür — ya da
// uygulama yeniden açıldığında hemen. Katalog eklemek nadir ve acil
// olmayan bir iştir; bedel bilerek kabul edildi.
//
// ⚠️ AYNI ANDA İKİ ÇAĞRI GELİRSE TEK İSTEK ATILIR. Uçuşta olan bir istek
// varsa yeni çağıran ONU bekliyor. Bu olmasaydı, beş ekran aynı anda
// açıldığında beş istek giderdi — yani önbellek, çözdüğü sorunu ilk
// saniyede geri getirirdi.
//
// 🆕 SINIF: "BİR ÖNBELLEK 'UÇUŞTAKİ İSTEĞİ' PAYLAŞMIYORSA, SOĞUK BAŞLANGIÇTA
// ÖNBELLEKSİZ HÂLDEN FARKI YOKTUR."
// ============================================================================
import { logError, supabase } from "./supabase";

const TTL_MS = 30 * 60 * 1000;   // 30 dakika

const kutu = {};   // ad → { deger, zaman, ucusta }

async function getir(ad, uret) {
  const k = kutu[ad];
  const simdi = Date.now();
  if (k && k.deger && simdi - k.zaman < TTL_MS) return k.deger;
  if (k && k.ucusta) return k.ucusta;          // aynı isteği paylaş

  const sozu = (async () => {
    try {
      const d = await uret();
      kutu[ad] = { deger: d, zaman: Date.now(), ucusta: null };
      return d;
    } catch (e) {
      logError("katalog:" + ad, e);
      kutu[ad] = { deger: null, zaman: 0, ucusta: null };
      // 🔴 HATA DURUMUNDA ESKİ DEĞERİ DÖNÜYORUZ (varsa). Ağ koptuğunda
      // kullanıcıya BOŞ bir havalimanı listesi göstermek, ona "hiç
      // havalimanı yok" demektir — yanlış bilgi, eksik bilgiden kötüdür.
      return (k && k.deger) || [];
    }
  })();

  kutu[ad] = { ...(k || { deger: null, zaman: 0 }), ucusta: sozu };
  return sozu;
}

export function havalimanlariniGetir() {
  return getir("airports", async () => {
    const { data, error } = await supabase
      .from("airports").select("code, name, city").order("code");
    if (error) throw error;
    return data || [];
  });
}

export function carrierlariGetir() {
  return getir("carriers", async () => {
    const { data, error } = await supabase.rpc("carrier_options");
    if (error) throw error;
    return data || [];
  });
}

// Katalog BO'dan değiştiğinde (ya da kullanıcı elle yenilediğinde)
// kutuyu boşaltmanın tek yolu. Test ve "aşağı çekip yenile" için.
export function katalogUnut() {
  Object.keys(kutu).forEach((k) => delete kutu[k]);
}
