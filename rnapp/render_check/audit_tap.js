#!/usr/bin/env node
/**
 * render_check/audit_tap.js — DOKUNMA HEDEFİ DENETİMİ (yalnız okur)
 *
 * NE ÖLÇER: Her `<TouchableOpacity>` / `<Pressable>` / `<TouchableWithoutFeedback>`
 * için dokunma alanının en az 44pt olmasını sağlayan BİR şey var mı:
 *   · hitSlop  (açıkça büyütülmüş alan)
 *   · minHeight: TAP.minHeight ya da >= 44
 *   · paddingVertical >= 12  (12+12+~14 metin ≈ 38-44, sınırda sayılır)
 *   · height >= 44
 * Hiçbiri yoksa "ölçülemedi" der — 44pt'nin ALTINDA OLABİLİR demektir.
 *
 * SINIR: stil ayrı bir sabitten geliyorsa (`style={S.chip}`) buradan
 * göremeyiz; o durumlar "sabitten" olarak AYRI sayılır, ihlal sayılmaz
 * ama kanıtlanmış da sayılmaz. Bunu gizlemiyorum: ölçemediğim şeye
 * "temiz" demem.
 */
const fs = require("fs");
const path = require("path");
const parser = require("@babel/parser");

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const TOUCH = new Set(["TouchableOpacity", "Pressable", "TouchableWithoutFeedback",
                       "TouchableHighlight", "TouchableNativeFeedback"]);

function num(node) {
  if (!node) return null;
  if (node.type === "NumericLiteral") return node.value;
  if (node.type === "UnaryExpression" && node.operator === "-" && node.argument.type === "NumericLiteral")
    return -node.argument.value;
  return null;
}

// Bir stil ifadesinden (obje / dizi / member) ölçü ipuçlarını çıkar
function styleEvidence(node, ev) {
  if (!node || typeof node !== "object") return;
  if (Array.isArray(node)) { node.forEach(n => styleEvidence(n, ev)); return; }
  if (node.type === "ObjectExpression") {
    for (const p of node.properties) {
      if (p.type !== "ObjectProperty") continue;
      const key = p.key.name || p.key.value;
      const v = num(p.value);
      if (key === "minHeight") {
        if (v !== null && v >= 44) ev.minHeight = v;
        // TAP.minHeight gibi member ifadesi
        else if (p.value.type === "MemberExpression" &&
                 p.value.object.name === "TAP") ev.minHeight = "TAP";
      }
      // 🔴 İLK YAZIMDA `height: TAP.minHeight` KAÇIYORDU (screens.js:6598/6603
      // sahte ihlal olarak çıktı). minHeight'te TAP üyesini tanıyıp height'te
      // tanımamak, aynı kuralı iki yerde farklı yazmaktı.
      if (key === "height") {
        if (v !== null && v >= 44) ev.height = v;
        else if (p.value.type === "MemberExpression" && p.value.object.name === "TAP") ev.height = "TAP";
      }
      if (key === "paddingVertical" && v !== null) ev.padV = Math.max(ev.padV || 0, v);
      if (key === "padding" && v !== null) ev.padV = Math.max(ev.padV || 0, v);
      if (key === "flex" && v === 1) ev.flex1 = true;
    }
    return;
  }
  if (node.type === "ArrayExpression") { node.elements.forEach(e => styleEvidence(e, ev)); return; }
  if (node.type === "MemberExpression" || node.type === "Identifier") { ev.fromConst = true; return; }
  for (const k of Object.keys(node)) {
    if (k === "loc" || k === "start" || k === "end") continue;
    styleEvidence(node[k], ev);
  }
}

const rows = [];
const files = [path.join(APP, "App.js"),
  ...fs.readdirSync(path.join(APP, "src")).filter(f => f.endsWith(".js")).map(f => path.join(APP, "src", f))];

for (const file of files) {
  const code = fs.readFileSync(file, "utf8");
  let ast;
  try { ast = parser.parse(code, { sourceType: "module", plugins: ["jsx"] }); }
  catch (e) { console.log(`PARSE HATASI ${file}: ${e.message}`); continue; }
  (function walk(n) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { n.forEach(walk); return; }
    if (!n.type) return;
    if (n.type === "JSXOpeningElement" && n.name.type === "JSXIdentifier" && TOUCH.has(n.name.name)) {
      const ev = { padV: 0 };
      let hitSlop = false, hasPress = false, disabled = false;
      for (const a of n.attributes) {
        if (a.type !== "JSXAttribute") continue;
        const an = a.name.name;
        if (an === "hitSlop") hitSlop = true;
        if (an === "onPress") hasPress = true;
        if (an === "disabled") disabled = true;
        if (an === "style" && a.value && a.value.type === "JSXExpressionContainer")
          styleEvidence(a.value.expression, ev);
      }
      const big = hitSlop || ev.minHeight || ev.height || ev.padV >= 12;
      rows.push({
        file: path.relative(APP, file), line: n.loc.start.line,
        tag: n.name.name, hitSlop, hasPress,
        why: hitSlop ? "hitSlop" : ev.minHeight ? "minHeight=" + ev.minHeight
             : ev.height ? "height=" + ev.height : ev.padV >= 12 ? "padding=" + ev.padV
             : ev.fromConst ? "SABİTTEN(ölçülemedi)" : ev.padV ? "padding=" + ev.padV : "KANIT YOK",
        ok: !!big, fromConst: !!ev.fromConst,
      });
    }
    for (const k of Object.keys(n)) { if (k === "loc" || k === "start" || k === "end") continue; walk(n[k]); }
  })(ast);
}

console.log("=".repeat(72));
console.log("DOKUNMA HEDEFİ DENETİMİ — her dokunulabilir öğe 44pt'ye ulaşıyor mu?");
console.log("=".repeat(72));
const withPress = rows.filter(r => r.hasPress);
const ok = withPress.filter(r => r.ok);
const constOnly = withPress.filter(r => !r.ok && r.fromConst);
const bad = withPress.filter(r => !r.ok && !r.fromConst);
console.log(`Toplam dokunulabilir öğe: ${rows.length} · onPress'i olan: ${withPress.length}`);
console.log(`  ✓ 44pt kanıtlı        : ${ok.length}   (hitSlop / minHeight / height / padding≥12)`);
console.log(`  ~ sabitten (ölçülemedi): ${constOnly.length}`);
console.log(`  🔴 KANIT YOK          : ${bad.length}`);

const byFile = {};
for (const r of bad) (byFile[r.file] = byFile[r.file] || []).push(r.line);
console.log("\nKanıt bulunamayan dosya dağılımı:");
for (const f of Object.keys(byFile).sort())
  console.log(`  ${f}: ${byFile[f].length} adet — satır ${byFile[f].slice(0, 24).join(", ")}${byFile[f].length > 24 ? " …" : ""}`);

console.log("\nSabitten gelen (stil ayrı dosyada, buradan ölçülemez):");
const byFile2 = {};
for (const r of constOnly) (byFile2[r.file] = byFile2[r.file] || []).push(r.line);
for (const f of Object.keys(byFile2).sort())
  console.log(`  ${f}: ${byFile2[f].length} adet — satır ${byFile2[f].slice(0, 20).join(", ")}${byFile2[f].length > 20 ? " …" : ""}`);
