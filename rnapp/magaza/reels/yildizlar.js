// Puanlama sahnesi (88_oturum_puanla): bes yildiz tek tek dokunulup altin dolar (12 Kasim 2026 istegi).
// Koordinatlar 528 px genislikteki ekran goruntusune gore OLCULDU (620 px kaynakta yildiz merkezleri x 0.8516).
// h: sayfa yerlestikten sonra gecen sn; bas: ilk dokunus; ara: yildizlar arasi (0.12 sn).
const YILDIZ_MERKEZ = [[134, 526], [199, 504], [264, 518], [329, 499], [393, 515]];
function yildizYolu(R, r) {
  let d = "";
  for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r : R; d += (i ? "L" : "M") + (Math.cos(a) * rr).toFixed(2) + "," + (Math.sin(a) * rr).toFixed(2); }
  return d + "Z";
}
function yildizlar(h, bas, ara = 0.12) {
  const c = (x) => Math.max(0, Math.min(1, x)), a = (x, p, q) => c((x - p) / (q - p));
  const gr = (x) => { const k = 1.7; return 1 + (k + 1) * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
  if (h < bas) return "";
  const yol = yildizYolu(25, 10.5);
  let s = "";
  YILDIZ_MERKEZ.forEach(([x, y], i) => {
    const t0 = bas + i * ara, p = a(h, t0, t0 + 0.22);
    if (p <= 0) return;
    const k = gr(p), kivilcim = a(h, t0 + 0.05, t0 + 0.45);
    // dokunma halkası
    if (kivilcim > 0 && kivilcim < 1) s += `<circle cx="${x}" cy="${y}" r="${14 + kivilcim * 26}" fill="none" stroke="rgba(255,236,190,${0.8 * (1 - kivilcim)})" stroke-width="2.5"/>`;
    // kıvılcımlar (4 kısa ışın)
    if (kivilcim > 0 && kivilcim < 1) [0, 1, 2, 3].forEach(j => {
      const an = (-60 + j * 90 + i * 17) * Math.PI / 180, r1 = 30 + kivilcim * 10, r2 = r1 + 9 * (1 - kivilcim);
      s += `<line x1="${x + Math.cos(an) * r1}" y1="${y + Math.sin(an) * r1}" x2="${x + Math.cos(an) * r2}" y2="${y + Math.sin(an) * r2}" stroke="rgba(255,226,160,${1 - kivilcim})" stroke-width="3" stroke-linecap="round"/>`;
    });
    s += `<g transform="translate(${x},${y}) scale(${k})"><path d="${yol}" fill="#E2B867" stroke="#F6DFA8" stroke-width="2" stroke-linejoin="round"/>
      <path d="${yol}" fill="url(#yParilti)" opacity=".55"/></g>`;
  });
  return `<svg style="position:absolute;left:0;top:0" width="528" height="1180"><defs><radialGradient id="yParilti" cx=".35" cy=".3" r=".7"><stop offset="0" stop-color="#FFF6DC"/><stop offset="1" stop-color="#FFF6DC" stop-opacity="0"/></radialGradient></defs>${s}</svg>`;
}
