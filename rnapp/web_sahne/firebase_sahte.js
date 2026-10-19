// 18 Ekim — web'de (sahne çekimi, e2e) Firebase yerel modülü yok. src/telefon.js bu taklidi
// çağırınca fırlatır ve `telefonHazir()` false döner → ekran eski e-posta yoluna düşer.
function auth() { throw new Error("firebase_web_yok"); }
export default auth;
