#!/usr/bin/env node
/**
 * render_check/audit_hooks.js — DENETİM ARACI (yalnız okur, hiçbir şey değiştirmez)
 *
 * NE ÖLÇER: Bir React bileşeninin gövdesinde, KOŞULLU ya da KOŞULSUZ bir
 * `return`DAN SONRA çağrılan hook var mı? React'in kuralı: hook sayısı ve
 * sırası her render'da AYNI olmalı. Erken dönüşten sonra bir hook varsa,
 * o dal çalıştığında hook sayısı değişir → "Rendered fewer hooks than
 * expected" → BEYAZ EKRAN.
 *
 * NASIL: Babel parser ile GERÇEK AST. Regex ile değil — regex `if (x) return;`
 * ile `return (<View/>)` arasındaki farkı bilemez.
 *
 * Kapsam: fonksiyon gövdesinin ÜST düzeyi (bileşen gövdesi). İç içe
 * fonksiyonlar (callback, effect gövdesi) ayrı hook kapsamıdır, sayılmaz.
 */
const fs = require("fs");
const path = require("path");
const parser = require("@babel/parser");

const HOOKS = /^(use[A-Z]|useState$|useEffect$|useMemo$|useCallback$|useRef$|useReducer$|useContext$|useLayoutEffect$)/;

function parseFile(file) {
  const code = fs.readFileSync(file, "utf8");
  return {
    code,
    ast: parser.parse(code, {
      sourceType: "module",
      plugins: ["jsx", "classProperties", "optionalChaining", "nullishCoalescingOperator", "objectRestSpread"],
      errorRecovery: false,
    }),
  };
}

function isHookCall(node) {
  if (!node || node.type !== "CallExpression") return null;
  const c = node.callee;
  if (c.type === "Identifier" && HOOKS.test(c.name)) return c.name;
  return null;
}

const FN = new Set(["FunctionDeclaration", "FunctionExpression", "ArrowFunctionExpression",
                    "ObjectMethod", "ClassMethod"]);

// 🔴 İLK YAZIMDA YANLIŞTI VE ÖLÇÜMLE YAKALANDI: `depth > 0` koşuluyla
// fonksiyonları atlıyordum, ama bileşen gövdesindeki bir statement'ın
// KENDİSİ bir fonksiyon tanımı olduğunda (örn. `async function handleLogout()
// { ... return true; }`) o depth 0'da geliyor ve İÇİNE İNİYORDUM. Sonuç:
// App.js Main() için 15 sahte ihlal — "satır 499'de return var" dediği şey
// handleLogout'un kendi return'üydü. Her fonksiyon düğümü, hangi derinlikte
// olursa olsun, AYRI bir hook/return kapsamıdır.
// Bir ifade ağacında hook çağrısı var mı (iç fonksiyonlara İNMEDEN)
function findHooksShallow(node, out) {
  if (!node || typeof node !== "object") return;
  if (Array.isArray(node)) { node.forEach(n => findHooksShallow(n, out)); return; }
  if (!node.type) return;
  if (FN.has(node.type)) return;          // yeni kapsam — inme
  const h = isHookCall(node);
  if (h) out.push({ name: h, line: node.loc.start.line });
  for (const k of Object.keys(node)) {
    if (k === "loc" || k === "start" || k === "end" || k === "leadingComments" ||
        k === "trailingComments" || k === "innerComments") continue;
    findHooksShallow(node[k], out);
  }
}

// Bir statement içinde (iç fonksiyona inmeden) `return` var mı
function hasReturn(node) {
  let found = null;
  (function walk(n) {
    if (!n || typeof n !== "object" || found) return;
    if (Array.isArray(n)) { n.forEach(walk); return; }
    if (!n.type) return;
    if (FN.has(n.type)) return;
    if (n.type === "ReturnStatement") { found = n.loc.start.line; return; }
    for (const k of Object.keys(n)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(n[k]);
    }
  })(node);
  return found;
}

function isComponent(name) { return /^[A-Z]/.test(name || "") || /^use[A-Z]/.test(name || ""); }

// İKİNCİ SINIF: KOŞUL/DÖNGÜ İÇİNDE HOOK.
// `if (x) { useEffect(...) }` erken dönüş olmadan da hook sayısını
// değiştirir — aynı beyaz ekran, farklı kapı.
const BRANCH = new Set(["IfStatement", "ForStatement", "ForOfStatement", "ForInStatement",
                        "WhileStatement", "DoWhileStatement", "SwitchStatement",
                        "ConditionalExpression", "LogicalExpression", "TryStatement"]);
function findConditionalHooks(bodyNode, name, file, out) {
  if (!bodyNode || bodyNode.type !== "BlockStatement") return;
  (function walk(n, inBranch) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { n.forEach(x => walk(x, inBranch)); return; }
    if (!n.type) return;
    if (FN.has(n.type)) return;                       // ayrı kapsam
    const h = isHookCall(n);
    if (h && inBranch) out.push({ file, comp: name, hook: h, line: n.loc.start.line, kind: inBranch });
    const nowBranch = BRANCH.has(n.type) ? (inBranch || n.type) : inBranch;
    for (const k of Object.keys(n)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(n[k], nowBranch);
    }
  })(bodyNode, null);
}

function auditFunctionBody(name, bodyNode, file, findings) {
  if (!bodyNode || bodyNode.type !== "BlockStatement") return;
  let firstReturnLine = null;
  for (const stmt of bodyNode.body) {
    // Bu statement bir return içeriyor mu (üst düzeyde ya da if içinde)?
    const r = hasReturn(stmt);
    if (r && firstReturnLine === null) firstReturnLine = r;
    if (firstReturnLine !== null) {
      const hooks = [];
      findHooksShallow(stmt, hooks);
      // aynı statement içindeki return'den ÖNCEKİ hook'lar sorun değil
      for (const hk of hooks) {
        if (hk.line > firstReturnLine) {
          findings.push({ file, comp: name, hook: hk.name, hookLine: hk.line, returnLine: firstReturnLine });
        }
      }
    }
  }
}

function run(files) {
  const findings = [];
  const condFindings = [];
  const comps = [];
  for (const file of files) {
    let parsed;
    try { parsed = parseFile(file); }
    catch (e) { console.log(`  ✗ PARSE HATASI ${file}: ${e.message}`); continue; }
    const { ast } = parsed;
    (function walk(node, parentName) {
      if (!node || typeof node !== "object") return;
      if (Array.isArray(node)) { node.forEach(n => walk(n, parentName)); return; }
      if (!node.type) return;
      let nm = null, body = null;
      if (node.type === "FunctionDeclaration" && node.id) { nm = node.id.name; body = node.body; }
      else if (node.type === "VariableDeclarator" && node.id && node.id.type === "Identifier" &&
               node.init && (node.init.type === "ArrowFunctionExpression" || node.init.type === "FunctionExpression")) {
        nm = node.id.name; body = node.init.body;
      }
      if (nm && isComponent(nm) && body) {
        comps.push({ file, nm, line: node.loc.start.line });
        auditFunctionBody(nm, body, file, findings);
        findConditionalHooks(body, nm, file, condFindings);
      }
      for (const k of Object.keys(node)) {
        if (k === "loc" || k === "start" || k === "end") continue;
        walk(node[k], nm || parentName);
      }
    })(ast, null);
  }
  return { findings, condFindings, comps };
}

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const files = [
  path.join(APP, "App.js"),
  ...fs.readdirSync(path.join(APP, "src")).filter(f => f.endsWith(".js")).map(f => path.join(APP, "src", f)),
];

console.log("=".repeat(72));
console.log("HOOK SIRASI DENETİMİ — erken dönüşten SONRA hook var mı? (beyaz ekran riski)");
console.log("=".repeat(72));
const { findings, condFindings, comps } = run(files);
console.log(`Taranan dosya: ${files.length} · bulunan bileşen/hook fonksiyonu: ${comps.length}`);
if (!findings.length) {
  console.log("\n✓ Erken dönüşten sonra hook çağıran bileşen YOK.");
} else {
  console.log(`\n🔴 ${findings.length} ihlal:`);
  for (const f of findings) {
    console.log(`  ${path.relative(APP, f.file)}:${f.hookLine} — ${f.comp}(): ${f.hook}() satır ${f.hookLine}, ` +
                `ama satır ${f.returnLine}'de zaten return var`);
  }
}

console.log("\n" + "-".repeat(72));
console.log("KOŞUL/DÖNGÜ İÇİNDE HOOK — hook sayısı render'lar arasında değişir mi?");
console.log("-".repeat(72));
if (!condFindings.length) {
  console.log("✓ Koşullu/döngüsel hook çağrısı YOK.");
} else {
  console.log(`🔴 ${condFindings.length} ihlal:`);
  for (const f of condFindings)
    console.log(`  ${path.relative(APP, f.file)}:${f.line} — ${f.comp}(): ${f.hook}() bir ${f.kind} içinde`);
}
process.exit((findings.length + condFindings.length) ? 1 : 0);
