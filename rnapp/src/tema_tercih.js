import { Appearance } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { temaUygula, temaModu } from "./theme";

// ============================================================================
// TEMA TERCİHİ — SİSTEM · AÇIK · KOYU
//
// 🔴 NEDEN ÜÇ SEÇENEK, İKİ DEĞİL
// İki durumlu bir anahtar ("Koyu tema: açık/kapalı") kullanıcının cihaz
// ayarını GÖRMEZDEN GELİR. Telefonu akşam 20:00'de otomatik koyuya
// geçen biri, bizim uygulamamızı her akşam elle çevirmek zorunda kalır.
// Üçüncü seçenek bir konfor değil, VARSAYILAN: "Sistem".
//
// 🆕 SINIF: "BİR TERCİHİ AÇIK/KAPALI YAPMAK, KULLANICININ ZATEN VERDİĞİ
// BİR KARARI YOK SAYMAKTIR — ÜÇÜNCÜ SEÇENEK 'SİSTEMİ DİNLE'DİR."
//
// Kalıcılık `atmosfer.js`teki desenle birebir aynı: modül düzeyinde
// durum + AsyncStorage + dinleyici kümesi. İkinci bir desen kurmak,
// ikinci bir hata kaynağı kurmaktır.
// ============================================================================

const ANAHTAR = "ll_tema";
// ══════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS · 6. TUR — TEK TEMA. AÇIK TEMA ARŞİVE ALINDI.
//
// Gökberk: "keşfet yine beyaz temada. Onu da yeni temadaki genel yapıya
// uydur mutlaka. Bu tarz eski temadan kalma şeyler varsa da düzenle."
//
// Haklıydı ve sorun önizlemeden büyüktü: AÇIK TEMA HİÇ YENİDEN
// TASARLANMADI. "Gece Sistemi" beş ekranı koyu zeminde, tek altın
// vurguyla, mono sayılarla kurdu; açık palet o sistemden ÖNCEKİ
// üründü. Yani telefonu açık modda olan ya da ayarlardan "Açık"
// seçen kullanıcı, hiç tasarlanmamış bir uygulamayı görüyordu.
//
// Bir tema bir renk tercihi değil, bir TASARIM SİSTEMİDİR. İkincisini
// sürdürmek, iki ürünü bakmak demek — ve ikincisinin bakımı hiç
// yapılmıyordu.
//
// 🆕 SINIF: "İKİ TEMA SUNMAK İKİ RENK PALETİ SUNMAK DEĞİL, İKİ TASARIM
// SİSTEMİNİ AYNI ANDA CANLI TUTMAKTIR — BİRİNİ TASARLAYIP ÖBÜRÜNÜ
// MİRAS BIRAKIRSAN, KULLANICININ YARISI TASARLANMAMIŞ ÜRÜNÜ GÖRÜR."
//
// ⚠️ SİLİNMEDİ: `theme.js`teki `ACIK` paleti duruyor, üç seçenekli
// eski dosya `_yedek_acik_tema/`de. Geri getirmek isteyen, açık paleti
// gece sistemine göre YENİDEN TASARLADIKTAN sonra getirir.
// ══════════════════════════════════════════════════════════════════
// v7 (2 Ekim): tek tema AVIATION LIGHT. Koyu tema kodda duruyor (geri dönüş için), seçilemez.
export const SECENEKLER = ["v7"];

// ══════════════════════════════════════════════════════════════════
// 🔴 30 AĞUSTOS — VARSAYILAN ARTIK KOYU.
//
// "Gece sistemi" bir seçenek değil, ürünün kimliği. Sebep referans
// sistemin ilk maddesiyle aynı ve doğru: bu uygulama alacakaranlık bir
// terminalde, çoğu zaman gece uçuşundan önce açılıyor. Parlak beyaz bir
// ekran orada hem gözü yorar hem ucuz durur.
//
// ⚠️ AÇIK TEMA SİLİNMEDİ. Ayarlardan seçilebiliyor ve `ACIK` paleti
// olduğu gibi duruyor. Değişen VARSAYILAN — yani hiçbir şey seçmemiş
// kullanıcının gördüğü.
//
// 🆕 SINIF: "BİR TEMAYI VARSAYILAN YAPMAK ONU ZORUNLU YAPMAK DEĞİLDİR —
// SEÇİM YOLUNU KAPATAN HER 'KİMLİK' KARARI, KULLANICIYI DIŞARIDA BIRAKIR."
let TERCIH = "v7";
const dinleyiciler = new Set();
let _abone = null;

function sistemModu() {
  try {
    // Sistem ne derse desin KOYU. Açık tema arşivde (yukarı bak);
    // sisteme uymak, olmayan bir tasarıma uymak olurdu.
    return "v7";
  } catch (e) {
    return "v7";
  }
}

function etkinMod() {
  return TERCIH === "sistem" ? sistemModu() : TERCIH;
}

function uygula() {
  const m = etkinMod();
  if (m !== temaModu()) temaUygula(m);
  dinleyiciler.forEach(f => { try { f(m); } catch (e) {} });
}

/**
 * Uygulama açılışında BİR KEZ çağrılır — ilk kareden ÖNCE.
 *
 * 🔴 Sıra önemli: tema uygulanmadan önce bir kare çizilirse kullanıcı
 * açık temanın bir flaşını görür ve koyuya "atlar". Bu, koyu tema
 * eklemenin en sık görülen kusurudur ve ölçülebilir bir şey değil,
 * SIRA meselesidir.
 */
export async function temaTercihYukle() {
  try {
    const v = await AsyncStorage.getItem(ANAHTAR);
    if (SECENEKLER.indexOf(v) >= 0) TERCIH = v;
  } catch (e) {
    TERCIH = "sistem";
  }
  // Sistem teması çalışırken değişebilir (otomatik gece modu, kullanıcı
  // ayarı). "Sistem" seçiliyken bunu dinlemezsek tercih yalnız açılışta
  // doğru olur — yani yarı çalışan bir özellik.
  if (!_abone) {
    try {
      _abone = Appearance.addChangeListener(() => {
        if (TERCIH === "sistem") uygula();
      });
    } catch (e) { _abone = null; }
  }
  uygula();
  return TERCIH;
}

export async function temaTercihYaz(v) {
  TERCIH = SECENEKLER.indexOf(v) >= 0 ? v : "sistem";
  try { await AsyncStorage.setItem(ANAHTAR, TERCIH); } catch (e) {}
  uygula();
}

export function temaTercihi() { return TERCIH; }
export function temaDinleTercih(fn) {
  dinleyiciler.add(fn);
  return () => dinleyiciler.delete(fn);
}
