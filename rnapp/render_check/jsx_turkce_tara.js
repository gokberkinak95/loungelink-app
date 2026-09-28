#!/usr/bin/env node
// render_check/jsx_turkce_tara.js — ham_kod_check.py (G · H) için kaynak taraması.
// JSX içinde duran Türkçe harfli dizeleri bulur ve ÇEVRİLMEYEN olanları
// döndürür. Çevrilmiş sayılanlar:
//   · gorunur("…") çağrısı (i18n.js · EN_KARSILIK)
//   · `t ? t.x : "…"` (t yoksa yedek)
//   · `t.x || "…"` yedeği — anahtar EN sözlükte VARSA (H ayrıca ölçer)
//   · `scene="…"` — Hdr gorunur() ile çevirir; değer EN_KARSILIK'ta olmalı
//   · dil düğmesinin "Türkçeye geç" etiketi (bilerek Türkçe)
const fs = require("fs"), path = require("path");
const ROOT = path.join(__dirname, "..");
const parser = require(path.join(ROOT, "node_modules/@babel/parser"));
const traverse = require(path.join(ROOT, "node_modules/@babel/traverse")).default;
const i18n = fs.readFileSync(path.join(ROOT, "src/i18n.js"), "utf8");
const karsilikBlok = (i18n.match(/const EN_KARSILIK = \{([\s\S]*?)\n\};/) || [])[1] || "";
const KARSILIK = new Set([...karsilikBlok.matchAll(/"([^"]+)"\s*:/g)].map(m => m[1]));
const enKeys = new Set(JSON.parse(process.argv[2] || "[]"));
const files = ["App.js", ...fs.readdirSync(path.join(ROOT, "src"))
  .filter(f => f.endsWith(".js") && !["i18n.js", "legal.js"].includes(f)).map(f => "src/" + f)];
const TR = /[çğıöşüÇĞİÖŞÜ]/;
const IZIN = new Set(["Türkçeye geç"]);
const G = [], H = [];
for (const f of files) {
  const src = fs.readFileSync(path.join(ROOT, f), "utf8");
  let ast;
  try { ast = parser.parse(src, { sourceType: "module", plugins: ["jsx"] }); }
  catch (e) { G.push([f, 0, "AYRIŞTIRILAMADI " + e.message]); continue; }
  traverse(ast, {
    JSXText(p) { const v = p.node.value.trim(); if (v && TR.test(v)) G.push([f, p.node.loc.start.line, v.slice(0, 60)]); },
    StringLiteral(p) {
      const v = p.node.value;
      if (!TR.test(v) || IZIN.has(v)) return;
      if (!p.findParent(q => q.isJSXAttribute() || q.isJSXExpressionContainer())) return;
      const par = p.parent;
      if (par.type === "CallExpression") {
        const c = par.callee, ad = (c.property && c.property.name) || c.name || "";
        if (ad === "gorunur") { if (!KARSILIK.has(v)) G.push([f, p.node.loc.start.line, "gorunur karşılığı yok: " + v]); return; }
        if (/^(logError|warn|log|rpc|from|eq|select|test|match|replace|includes|indexOf|startsWith|setItem|getItem|split|join)$/.test(ad)) return;
      }
      if (par.type === "LogicalExpression" && par.operator === "||" && par.right === p.node) {
        const l = par.left;
        if (l.type === "MemberExpression" || l.type === "OptionalMemberExpression") {
          const k = l.property && (l.property.name || l.property.value);
          if (l.object && l.object.name === "t") { if (!enKeys.has(k)) H.push([f, p.node.loc.start.line, "t." + k]); return; }
        }
      }
      if (par.type === "ConditionalExpression" && par.test.type === "Identifier" && par.test.name === "t") return;
      if (par.type === "JSXAttribute" && par.name.name === "scene") { if (!KARSILIK.has(v)) G.push([f, p.node.loc.start.line, "scene karşılığı yok: " + v]); return; }
      if (par.type === "LogicalExpression") return;   // `x || "…"` (t dışı yedek) — içerik yedeği
      G.push([f, p.node.loc.start.line, v.slice(0, 60)]);
    },
    TemplateLiteral(p) {
      const v = p.node.quasis.map(q => q.value.cooked).join("${}");
      if (!TR.test(v) || !p.findParent(q => q.isJSXAttribute() || q.isJSXExpressionContainer())) return;
      G.push([f, p.node.loc.start.line, v.slice(0, 60)]);
    },
  });
}
process.stdout.write(JSON.stringify({ G, H }));
