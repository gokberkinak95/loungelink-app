const R = require("../runner");
const { React } = R;
const renderer = require("react-test-renderer");
const ui = require("../../src/ui.js");
const tema = require("../../src/theme.js");

function duz(s){ return Array.isArray(s) ? Object.assign({}, ...s.filter(Boolean).map(x=>duz(x))) : (s||{}); }

for (const mod of ["acik","koyu"]) {
  tema.temaUygula(mod);
  const tr = renderer.create(React.createElement(ui.Btn, { v: "gold", label: "Basla" }));
  const j = tr.toJSON();
  const kok = duz(j.props.style);
  let grad=null, metin=null;
  (function gez(n){ if(!n||typeof n!=="object")return;
    if(n.type==="Image" && !grad) grad=n;
    if(n.type==="Text" && !metin) metin=n;
    (n.children||[]).forEach(gez); })(j);
  console.log("-- tema:", mod);
  console.log("   dugme zemini :", kok.backgroundColor);
  console.log("   metin rengi  :", duz(metin && metin.props.style).color);
  console.log("   gradyan kaynak:", JSON.stringify(grad && grad.props.source));
  tr.unmount();
}

