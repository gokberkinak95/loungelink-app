// Lansman sonrasi kapanis CTA'si (10 Kasim 2026). Yalniz ?durum=lansman ile devreye girer; bayraksiz cikti degismez.
// Onayli lansman dili: altin "SIMDI APP STORE'DA" satiri, altin isiltili App Store hap (kahraman), ikincil "GOOGLE PLAY · YAKINDA", loungelink.co.
const LANSMAN_SONRA = new URLSearchParams(location.search).get("durum") === "lansman";
function lansmanCTA(t, bas, koyu) {
  const c = (x) => Math.max(0, Math.min(1, x)), a = (x, p, q) => c((x - p) / (q - p));
  const eo = (x) => 1 - Math.pow(1 - x, 3);
  const gr = (x) => { const k = 1.4; return 1 + (k + 1) * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
  const p1 = eo(a(t, bas, bas + 0.4)), p2 = gr(a(t, bas + 0.25, bas + 0.75)), p3 = eo(a(t, bas + 0.5, bas + 0.9)), p4 = eo(a(t, bas + 0.9, bas + 1.4));
  const isik = a(t, bas + 0.6, bas + 1.1), halka = a(t, bas + 0.65, bas + 1.65);
  const nefes = t > bas + 1.1 ? 0.5 + 0.5 * Math.sin((t - bas - 1.1) * 3) : 0;
  const glow = isik * (0.75 + 0.25 * nefes);
  const altin = koyu ? "#E7C98F" : "#A87B32", cizgi = koyu ? "rgba(231,201,143,.7)" : "rgba(168,123,50,.6)";
  const roYazi = koyu ? "#1A2B4C" : "#FFFFFF", roZem = koyu ? "linear-gradient(180deg,#FFFFFF,#F4EEE2)" : "linear-gradient(180deg,#22365F,#1A2B4C)";
  const sonuk = koyu ? "rgba(247,244,238,.78)" : "#5A6A8A", site = koyu ? "#F2D59A" : "#A87B32";
  const isikRgb = koyu ? "231,201,143" : "226,184,103";
  return `<div style="display:flex;align-items:center;justify-content:center;gap:20px;font-size:28px;letter-spacing:.3em;color:${altin};opacity:${p1};transform:translateY(${(1 - p1) * 16}px)">
      <span style="width:${100 * p1}px;height:2px;background:linear-gradient(90deg,transparent,${cizgi})"></span>
      <svg width="46" height="22" viewBox="76 117.5 62 29"><path d="${VERI.kanat}" fill="${altin}"/></svg>ŞİMDİ APP STORE'DA
      <span style="width:${100 * p1}px;height:2px;background:linear-gradient(90deg,${cizgi},transparent)"></span></div>
    <div style="position:relative;display:flex;justify-content:center;margin-top:20px">
      ${halka > 0 && halka < 1 ? `<div style="position:absolute;left:50%;top:50%;width:470px;height:92px;margin:-46px 0 0 -235px;border-radius:46px;border:3px solid rgba(${isikRgb},${0.8 * (1 - halka)});transform:scale(${1 + halka * 0.22},${1 + halka * 0.7})"></div>` : ""}
      <div style="display:inline-flex;align-items:center;gap:14px;height:92px;padding:0 44px;border-radius:46px;font-size:34px;white-space:nowrap;color:${roYazi};background:${roZem};
        border:2px solid rgba(${isikRgb},${0.35 + 0.65 * isik});opacity:${c(p2)};transform:scale(${p2});
        box-shadow:0 0 0 ${7 * glow}px rgba(${isikRgb},.24),0 0 ${56 * glow}px rgba(${isikRgb},${0.6 * glow}),0 18px 36px rgba(${koyu ? "0,0,0,.45" : "26,43,76,.3"})">
        <svg viewBox="0 0 24 24" style="width:40px;height:40px"><path d="${VERI.apple}" fill="${roYazi}"/></svg>App Store'dan indir</div></div>
    <div style="margin-top:20px;display:flex;align-items:center;justify-content:center;gap:10px;font-size:24px;letter-spacing:.14em;color:${sonuk};opacity:${p3}">
      <svg viewBox="0 0 24 24" style="width:24px;height:24px;opacity:.8"><path d="${VERI.gplay}" fill="${sonuk}"/></svg>GOOGLE PLAY · YAKINDA</div>
    <div style="margin-top:14px;font-size:32px;opacity:${p4}"><b style="color:${site}">loungelink.co</b></div>`;
}
