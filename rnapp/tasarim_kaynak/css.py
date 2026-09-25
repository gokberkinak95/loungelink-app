# -*- coding: utf-8 -*-
CSS = """
:root{
  --gece:#100E12; --gece2:#171419; --yuzey:#1C1820; --yuzey2:#241F28;
  --cizgi:rgba(232,214,182,.10); --cizgi2:rgba(232,214,182,.17);
  --altin:#E0BE7A; --altinD:#C39B4C; --altinIz:rgba(224,190,122,.13);
  --bulut:#F6F1E8; --sessiz:#A79B8A; --dim:#6F6558;
  --guven:#3BD4B4; --uyari:#E8A33D; --uyari2:#F0736A; --bilgi:#7FA8E8;
  --sayfa:#0A090C;
}
*{box-sizing:border-box}
body{margin:0;background:var(--sayfa);color:var(--bulut);
  font-family:"Plus Jakarta Sans",-apple-system,"Segoe UI",sans-serif;
  -webkit-font-smoothing:antialiased}
h1,h2,h3,p,ul,figure{margin:0}
button{font:inherit;border:0;background:none;color:inherit;cursor:pointer}
::selection{background:var(--altinD);color:#100E12}

/* ── sayfa iskeleti ─────────────────────────────────── */
.sf{max-width:1320px;margin:0 auto;padding:72px 28px 110px}
.bas{max-width:660px;margin-bottom:14px}
.kicik{font-size:11px;font-weight:600;letter-spacing:.22em;text-transform:uppercase;color:var(--altin)}
.bas h1{font-family:"Cormorant Garamond",Georgia,serif;font-weight:300;
  font-size:clamp(44px,6.4vw,74px);line-height:1.02;letter-spacing:-.02em;margin:18px 0 0;
  text-wrap:balance}
.bas h1 em{font-style:italic;color:var(--altin)}
.bas p{margin-top:20px;font-size:16px;line-height:1.66;color:var(--sessiz);max-width:56ch}
.ayrac{height:1px;margin:52px 0 44px;
  background:linear-gradient(90deg,var(--altinD) 0%,rgba(195,155,76,.22) 34%,rgba(195,155,76,0) 100%)}

.blm-bas{display:flex;align-items:baseline;gap:16px;margin-bottom:26px;flex-wrap:wrap}
.blm-bas h2{font-family:"Cormorant Garamond",Georgia,serif;font-weight:400;font-size:34px;letter-spacing:-.01em}
.blm-bas p{font-size:14px;color:var(--sessiz);max-width:52ch;line-height:1.6}

/* ── telefon ────────────────────────────────────────── */
.galeri{display:flex;gap:30px;overflow-x:auto;padding:6px 0 26px;scroll-snap-type:x mandatory}
.galeri::-webkit-scrollbar{height:8px}
.galeri::-webkit-scrollbar-thumb{background:var(--yuzey2);border-radius:8px}
.tel{flex:0 0 auto;scroll-snap-align:center}
.cerceve{width:390px;height:844px;border-radius:44px;padding:10px;background:#000;
  border:1px solid var(--cizgi2);
  box-shadow:0 0 0 1px rgba(0,0,0,.9), 0 44px 90px -22px rgba(0,0,0,.9),
             0 0 90px -30px rgba(224,190,122,.18)}
.ekran{width:100%;height:100%;border-radius:35px;overflow:hidden;background:var(--gece);
  position:relative;display:flex;flex-direction:column}
figcaption{margin-top:20px;max-width:390px}
.tel-ad{font-size:13px;font-weight:600;letter-spacing:.1em;text-transform:uppercase;color:var(--altin)}
.tel-not{margin-top:8px;font-size:13px;line-height:1.62;color:var(--sessiz)}

/* ── ekran içi: üst ─────────────────────────────────── */
.ust{padding:20px 22px 22px;position:relative;flex:0 0 auto}
.ust.mesh{background:
  radial-gradient(120% 92% at 82% -14%, rgba(224,190,122,.30) 0%, rgba(224,190,122,0) 62%),
  radial-gradient(112% 88% at 8% 6%, rgba(127,168,232,.20) 0%, rgba(127,168,232,0) 60%),
  linear-gradient(180deg, #1A1620 0%, var(--gece) 100%)}
.ust.mesh::after{content:"";position:absolute;inset:0;pointer-events:none;
  background:url("FOTO") center 42%/cover;opacity:.16;mix-blend-mode:screen}
.ust.sade,.ust.ince-ust{background:linear-gradient(180deg,#191520 0%,var(--gece) 100%)}
.ust-sira{display:flex;align-items:center;justify-content:space-between;position:relative;z-index:2}
.marka{font-size:11px;font-weight:700;letter-spacing:.42em;color:var(--bulut);opacity:.92}
.ust-eylem{width:38px;height:38px;border-radius:999px;border:1px solid var(--cizgi2);
  display:flex;align-items:center;justify-content:center;color:var(--bulut);
  background:rgba(255,255,255,.04)}
.dugum{position:relative;z-index:2;margin-top:34px;font-size:10px;font-weight:700;
  letter-spacing:.24em;text-transform:uppercase;color:var(--altin)}
.ust-h1{position:relative;z-index:2;font-size:40px;font-weight:700;letter-spacing:-.028em;
  line-height:1.04;margin-top:9px;color:var(--bulut)}
.ust-h1.serif{font-family:"Cormorant Garamond",Georgia,serif;font-weight:300;font-size:52px;letter-spacing:-.01em}
.ust-alt{position:relative;z-index:2;margin-top:11px;font-size:13px;color:var(--sessiz);
  letter-spacing:.005em}

.cuzdan{position:relative;z-index:2;display:flex;align-items:center;gap:16px;margin-top:22px;
  padding:14px 16px;border:1px solid var(--cizgi);border-radius:14px;background:rgba(255,255,255,.035)}
.cuzdan>div{display:flex;flex-direction:column;gap:3px}
.cuzdan b{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:19px;font-weight:600;
  color:var(--altin);font-variant-numeric:tabular-nums}
.cuzdan span{font-size:9.5px;font-weight:600;letter-spacing:.14em;text-transform:uppercase;color:var(--dim)}
.cuzdan i{width:1px;height:26px;background:var(--cizgi2)}

/* ── gövde ──────────────────────────────────────────── */
.govde{flex:1;overflow:hidden;padding:18px 22px 0}
.kutu{border:1px solid var(--cizgi);border-radius:14px;background:var(--yuzey);padding:18px}
.kutu-bas{font-size:10px;font-weight:700;letter-spacing:.2em;text-transform:uppercase;color:var(--dim)}
.sartlar{list-style:none;padding:0;margin:16px 0 0;display:flex;flex-direction:column;gap:13px}
.sartlar li{display:flex;align-items:center;gap:11px;font-size:14px;line-height:1.3}
.sartlar li.ok{color:var(--bulut)} .sartlar li.ok svg{color:var(--guven)}
.sartlar li.yok{color:var(--sessiz)} .sartlar li.yok svg{color:var(--uyari)}
.not{margin-top:16px;font-size:12px;line-height:1.62;color:var(--dim)}
.eylem-yig{margin-top:20px;display:flex;flex-direction:column;gap:11px}

/* ── kart ───────────────────────────────────────────── */
.kart{border:1px solid var(--cizgi);border-radius:16px;background:var(--yuzey);padding:17px;
  margin-bottom:13px}
.kart.one{border-color:var(--altinIz);
  background:linear-gradient(180deg,rgba(224,190,122,.055) 0%,var(--yuzey) 46%);
  box-shadow:0 0 0 1px rgba(224,190,122,.05), 0 18px 40px -26px rgba(224,190,122,.4)}
.kart-ust{display:flex;align-items:flex-start;gap:12px}
.avatar{width:44px;height:44px;border-radius:999px;flex:0 0 auto;position:relative;
  display:flex;align-items:center;justify-content:center;
  font-family:"Cormorant Garamond",Georgia,serif;font-size:20px;font-weight:600;color:var(--altin);
  background:linear-gradient(145deg,#2B2430,#1E1A22);border:1px solid var(--cizgi2)}
.avatar.sm{width:36px;height:36px;font-size:17px}
.kalkan{position:absolute;right:-3px;bottom:-3px;width:17px;height:17px;border-radius:999px;
  background:var(--guven);color:#0B1A16;display:flex;align-items:center;justify-content:center;
  border:2px solid var(--yuzey)}
.kart-kim{flex:1;min-width:0}
.kart-ad{font-size:16px;font-weight:600;letter-spacing:-.01em}
.kart-mert{font-size:11.5px;color:var(--sessiz);margin-top:3px;letter-spacing:.01em}
.uyum{text-align:right;flex:0 0 auto}
.uyum b{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:22px;
  font-weight:600;color:var(--guven);line-height:1;font-variant-numeric:tabular-nums}
.uyum span{display:block;font-size:8.5px;font-weight:600;letter-spacing:.16em;
  text-transform:uppercase;color:var(--dim);margin-top:4px}
.kart-salon{margin-top:15px;font-size:19px;font-weight:600;letter-spacing:-.015em}
.kart-term{margin-top:4px;font-size:12px;color:var(--sessiz)}
.kart-metin{margin-top:9px;font-size:13.5px;line-height:1.58;color:var(--sessiz)}
.kart-metin b{color:var(--bulut);font-weight:600}
.roz-sira{display:flex;flex-wrap:wrap;gap:6px;margin-top:13px}
.roz{font-size:10.5px;font-weight:600;letter-spacing:.03em;padding:5px 10px;border-radius:999px;
  border:1px solid var(--cizgi2);color:var(--sessiz)}
.roz.iyi{color:var(--guven);border-color:rgba(59,212,180,.34);background:rgba(59,212,180,.09)}
.roz.uyari{color:var(--uyari);border-color:rgba(232,163,61,.34);background:rgba(232,163,61,.09)}
.roz.bilgi{color:var(--bilgi);border-color:rgba(127,168,232,.3)}
.kart-alt{display:flex;align-items:center;gap:12px;margin-top:17px}
.kart-alt.tek{margin-top:16px}
.sayac{display:inline-flex;align-items:center;gap:6px;color:var(--sessiz);flex:0 0 auto}
.sayac b{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;font-weight:500;
  color:var(--bulut);font-variant-numeric:tabular-nums}

/* ── düğmeler ───────────────────────────────────────── */
.btn-altin{flex:1;min-height:48px;border-radius:12px;display:flex;align-items:center;
  justify-content:center;gap:8px;font-size:14px;font-weight:700;letter-spacing:-.005em;
  color:#171009;background:linear-gradient(180deg,#EBCD92 0%,var(--altinD) 100%);
  box-shadow:0 0 26px -6px rgba(224,190,122,.55), inset 0 1px 0 rgba(255,255,255,.4)}
.btn-cizgi{min-height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;
  font-size:14px;font-weight:600;color:var(--bulut);border:1.5px solid var(--cizgi2);
  background:rgba(255,255,255,.03)}
.btn-sessiz{min-height:44px;font-size:13.5px;font-weight:500;color:var(--sessiz)}

/* ── eşleşme anı ────────────────────────────────────── */
.an{flex:1;display:flex;flex-direction:column;justify-content:space-between;
  padding:64px 26px 34px;position:relative;text-align:center}
.mesh-yogun{background:
  radial-gradient(96% 62% at 50% 8%, rgba(224,190,122,.42) 0%, rgba(224,190,122,0) 66%),
  radial-gradient(88% 58% at 22% 44%, rgba(127,168,232,.26) 0%, rgba(127,168,232,0) 62%),
  linear-gradient(180deg,#241D26 0%, var(--gece) 62%)}
.an::after{content:"";position:absolute;inset:0;pointer-events:none;
  background:url("FOTO") center 46%/cover;opacity:.20;mix-blend-mode:screen}
.an-ic{position:relative;z-index:2}
.an-ikiz{display:flex;align-items:center;justify-content:center}
.an-av{width:66px;height:66px;border-radius:999px;display:flex;align-items:center;justify-content:center;
  font-family:"Cormorant Garamond",Georgia,serif;font-size:28px;font-weight:600;color:var(--altin);
  background:linear-gradient(145deg,#2F2734,#201B26);border:1px solid var(--cizgi2)}
.an-av.alt{color:var(--guven)}
.an-cizgi{width:52px;height:1px;background:linear-gradient(90deg,var(--altin),var(--guven));opacity:.7}
.an-h1{font-family:"Cormorant Garamond",Georgia,serif;font-weight:300;font-size:46px;
  line-height:1.06;letter-spacing:-.015em;margin-top:12px}
.an-alt{margin-top:16px;font-size:13.5px;line-height:1.66;color:var(--sessiz)}
.an-sayac{margin-top:26px;display:inline-flex;align-items:center;gap:8px;padding:10px 16px;
  border:1px solid var(--cizgi2);border-radius:999px;color:var(--sessiz)}
.an-sayac b{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:15px;font-weight:600;
  color:var(--bulut);font-variant-numeric:tabular-nums}
.an-sayac span{font-size:10px;font-weight:600;letter-spacing:.14em;text-transform:uppercase;color:var(--dim)}
.an-eylem{position:relative;z-index:2;display:flex;flex-direction:column;gap:6px}

/* ── sohbet ─────────────────────────────────────────── */
.sohbet-kim{display:flex;align-items:center;gap:11px;flex:1;margin-left:12px}
.sabit-serit{display:flex;align-items:center;gap:8px;margin-top:16px;padding:11px 14px;
  border:1px solid var(--cizgi);border-radius:12px;background:rgba(255,255,255,.035);
  font-size:11.5px;color:var(--sessiz)}
.sabit-serit b{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12.5px;color:var(--bulut);
  font-variant-numeric:tabular-nums}
.sabit-serit i{width:1px;height:14px;background:var(--cizgi2);margin:0 3px}
.govde.sohbet{display:flex;flex-direction:column;gap:11px;padding-top:20px}
.bal{max-width:78%;padding:13px 15px;border-radius:16px;background:var(--yuzey);
  border:1px solid var(--cizgi);border-bottom-left-radius:5px}
.bal p{font-size:14px;line-height:1.52}
.bal time{display:block;margin-top:7px;font-size:10px;color:var(--dim);
  font-family:"JetBrains Mono",ui-monospace,monospace}
.bal.ben{align-self:flex-end;border-bottom-left-radius:16px;border-bottom-right-radius:5px;
  background:linear-gradient(180deg,rgba(224,190,122,.17),rgba(224,190,122,.09));
  border-color:var(--altinIz)}
.cipler{display:flex;gap:8px;padding:12px 22px 0;overflow:hidden;flex:0 0 auto}
.cip{flex:0 0 auto;padding:9px 14px;border-radius:999px;border:1px solid var(--cizgi2);
  font-size:12px;font-weight:500;color:var(--sessiz);background:rgba(255,255,255,.03)}
.yazma{display:flex;align-items:center;gap:10px;margin:12px 22px 22px;padding:13px 14px;
  border:1px solid var(--cizgi2);border-radius:14px;background:var(--yuzey);flex:0 0 auto}
.yazma>span{flex:1;font-size:14px;color:var(--dim)}
.gonder{width:36px;height:36px;border-radius:999px;display:flex;align-items:center;justify-content:center;
  color:#171009;background:linear-gradient(180deg,#EBCD92,var(--altinD))}

/* ── sayı şeridi ────────────────────────────────────── */
.sy-sira{display:flex;gap:9px}
.sy{flex:1;border:1px solid var(--cizgi);border-radius:12px;background:var(--yuzey);
  padding:13px 5px;text-align:center}
.sy b{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:20px;
  font-weight:500;color:var(--dim);line-height:1;font-variant-numeric:tabular-nums}
.sy span{display:block;font-size:9px;font-weight:600;letter-spacing:.12em;text-transform:uppercase;
  color:var(--dim);margin-top:7px}
.sy.on{border-color:var(--altinIz)} .sy.on b{color:var(--altin)} .sy.on span{color:var(--sessiz)}

/* ── tabbar ─────────────────────────────────────────── */
.tabbar{display:flex;padding:11px 8px 22px;background:rgba(16,14,18,.94);
  border-top:1px solid var(--cizgi);flex:0 0 auto;backdrop-filter:blur(12px)}
.tb{flex:1;display:flex;flex-direction:column;align-items:center;gap:5px;color:var(--dim);
  min-height:48px;justify-content:center;position:relative}
.tb span{font-size:9.5px;font-weight:600;letter-spacing:.03em}
.tb-ind{width:22px;height:3px;border-radius:999px;background:transparent;
  position:absolute;top:-7px}
.tb.on{color:var(--altin)} .tb.on .tb-ind{background:var(--altin)}

/* ── jeton tablosu ──────────────────────────────────── */
.jeton{display:grid;grid-template-columns:repeat(auto-fit,minmax(188px,1fr));gap:1px;
  background:var(--cizgi);border:1px solid var(--cizgi);border-radius:14px;overflow:hidden}
.jeton>div{background:var(--gece2);padding:20px}
.jeton .swatch{height:46px;border-radius:9px;border:1px solid rgba(255,255,255,.07);margin-bottom:14px}
.jeton code{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11.5px;
  color:var(--altin);letter-spacing:.02em}
.jeton .ad{margin-top:7px;font-size:13px;font-weight:600}
.jeton .aciklama{margin-top:5px;font-size:12px;line-height:1.55;color:var(--sessiz)}

/* ── karar kartları ─────────────────────────────────── */
.kararlar{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}
.karar{border:1px solid var(--cizgi);border-radius:16px;background:var(--gece2);padding:24px}
.karar h3{font-size:15px;font-weight:700;letter-spacing:-.01em;margin-bottom:10px}
.karar p{font-size:13.5px;line-height:1.68;color:var(--sessiz)}
.karar .no{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11px;color:var(--altinD);
  letter-spacing:.1em;display:block;margin-bottom:12px}

@media (max-width:760px){
  .sf{padding:44px 18px 80px}
  .cerceve{width:340px;height:736px;border-radius:38px}
  .ekran{border-radius:30px}
  figcaption{max-width:340px}
}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
"""
