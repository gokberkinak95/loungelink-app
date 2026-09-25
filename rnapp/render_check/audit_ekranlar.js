#!/usr/bin/env node
/**
 * render_check/audit_ekranlar.js — EKRAN ENVANTERİ (yalnız okur)
 *
 * Her dışa aktarılan ekran/bileşen için ÖLÇER:
 *   · çağırdığı RPC'ler          (supabase.rpc("..."))
 *   · okuduğu/yazdığı tablolar   (supabase.from("...").select/insert/update/delete)
 *   · YÜKLENİYOR hali var mı     (ActivityIndicator / Skeleton / t.*Loading / busy)
 *   · BOŞ hali var mı            (length === 0 / !length / t.*Empty / Empty bileşeni)
 *   · HATA hali var mı           (err state + ekrana basılması / LoadFail / mapErr)
 *   · yutulan hata sayısı        (`const { data } = await supabase...` — error yok)
 *
 * SINIR: bunlar KALIP eşleşmesidir. "Hata hali var" demek, hatanın
 * DOĞRU metinle gösterildiğini kanıtlamaz — yalnız bir dalın var
 * olduğunu gösterir. Yokluğu ise kesindir: hiç `err` yoksa kullanıcı
 * hiçbir zaman hata görmez.
 */
const fs = require("fs");
const path = require("path");
const parser = require("@babel/parser");

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const FILES = ["App.js", ...fs.readdirSync(path.join(APP, "src"))
  .filter(f => f.endsWith(".js") && !["i18n.js", "theme.js", "typography.js"].includes(f))
  .map(f => "src/" + f)];

const OKUMA = new Set(["select"]);
const YAZMA = { insert: "INSERT", update: "UPDATE", upsert: "UPSERT", delete: "DELETE" };

function analiz(file) {
  const code = fs.readFileSync(path.join(APP, file), "utf8");
  const ast = parser.parse(code, { sourceType: "module", plugins: ["jsx"] });
  const lines = code.split("\n");
  const out = [];

  function scan(node, name, exported, startLine, endLine) {
    const rpcs = new Set(), tablo = {};
    let loading = null, empty = null, hata = null, yutulan = 0, hooks = 0;
    const govde = lines.slice(startLine - 1, endLine).join("\n");

    // --- RPC ve tablo çağrıları (AST: yanlış eşleşme olmasın) ---
    (function walk(n) {
      if (!n || typeof n !== "object") return;
      if (Array.isArray(n)) { n.forEach(walk); return; }
      if (!n.type) return;
      if (n.type === "CallExpression" && n.callee.type === "MemberExpression") {
        const prop = n.callee.property.name;
        const arg0 = n.arguments[0];
        if (prop === "rpc" && arg0 && arg0.type === "StringLiteral") rpcs.add(arg0.value);
        if (prop === "from" && arg0 && arg0.type === "StringLiteral") {
          // `.from(x)` sonrası zincirde hangi işlem var? Üst düğümlere bakmak
          // yerine kaynak metnini kullanıyoruz: zincir tek ifadede yazılı.
          const seg = code.slice(n.start, Math.min(code.length, n.start + 400));
          const t = arg0.value;
          tablo[t] = tablo[t] || new Set();
          let bulundu = false;
          for (const [m, lbl] of Object.entries(YAZMA))
            if (new RegExp("\\.\\s*" + m + "\\s*\\(").test(seg)) { tablo[t].add(lbl); bulundu = true; }
          if (/\.\s*select\s*\(/.test(seg) || !bulundu) tablo[t].add("SELECT");
        }
        if (/^use[A-Z]/.test(n.callee.property.name || "")) hooks++;
      }
      if (n.type === "CallExpression" && n.callee.type === "Identifier" && /^use[A-Z]/.test(n.callee.name)) hooks++;
      for (const k of Object.keys(n)) { if (k === "loc" || k === "start" || k === "end") continue; walk(n[k]); }
    })(node);

    // --- durum kalıpları (gövde metni üstünden) ---
    if (/ActivityIndicator|Skeleton|BrandLoader|\bbusy\b|\bloading\b|yukleniyor|Loading|\bsaving\b/.test(govde))
      loading = /ActivityIndicator/.test(govde) ? "ActivityIndicator"
              : /Skeleton|BrandLoader/.test(govde) ? "Skeleton/BrandLoader"
              : /\bloading\b/.test(govde) ? "loading bayrağı" : "busy bayrağı";
    if (/\.length\s*===\s*0|!\w+\.length|\.length\s*>\s*0\s*\?|Empty|empty|\bbos\b|emptyNote/.test(govde))
      empty = /Empty\b|t\.\w*[Ee]mpty/.test(govde) ? "t.*Empty metni" : "length kontrolü";
    if (/setErr\(|<LoadFail|mapErr\(|\berr\b\s*&&|!!err|\bfailed\b|setFailed\(/.test(govde))
      hata = /<LoadFail/.test(govde) ? "LoadFail bileşeni"
           : /mapErr\(/.test(govde) ? "mapErr + err kutusu"
           : /setFailed\(/.test(govde) ? "failed bayrağı" : "err kutusu";

    // --- yutulan hata: `const { data ... } = await supabase` (error yok) ---
    const re = /const\s*\{\s*data[^}]*\}\s*=\s*await\s+supabase/g;
    let mm;
    while ((mm = re.exec(govde)) !== null) if (!/error/.test(mm[0])) yutulan++;

    out.push({ file, name, exported, startLine, endLine, hooks,
               rpcs: [...rpcs].sort(),
               tablo: Object.fromEntries(Object.entries(tablo).map(([k, v]) => [k, [...v].sort()])),
               loading, empty, hata, yutulan });
  }

  (function walk(node, exported) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) { node.forEach(n => walk(n, exported)); return; }
    if (!node.type) return;
    if (node.type === "ExportNamedDeclaration" || node.type === "ExportDefaultDeclaration") {
      walk(node.declaration, true);
      return;
    }
    if (node.type === "FunctionDeclaration" && node.id && /^[A-Z]|^use[A-Z]/.test(node.id.name))
      scan(node, node.id.name, !!exported, node.loc.start.line, node.loc.end.line);
    for (const k of Object.keys(node)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(node[k], exported);
    }
  })(ast, false);

  return out;
}

const hepsi = [];
for (const f of FILES) {
  try { hepsi.push(...analiz(f)); }
  catch (e) { console.log(`PARSE HATASI ${f}: ${e.message}`); }
}

console.log("=".repeat(112));
console.log("EKRAN ENVANTERİ — her ekranın veri kaynağı ve durum kapsaması");
console.log("=".repeat(112));
console.log(`Bulunan bileşen: ${hepsi.length} (dışa aktarılan: ${hepsi.filter(x => x.exported).length})\n`);

const H = ["EKRAN", "DOSYA:SATIR", "YÜK", "BOŞ", "HATA", "RPC", "TABLO", "YUTULAN"];
console.log(H[0].padEnd(24) + H[1].padEnd(22) + H[2].padEnd(5) + H[3].padEnd(5) + H[4].padEnd(6) +
            H[5].padEnd(5) + H[6].padEnd(7) + H[7]);
console.log("-".repeat(112));
const eksik = [];
for (const s of hepsi.sort((a, b) => (a.file + a.startLine).localeCompare(b.file + b.startLine))) {
  const nRpc = s.rpcs.length, nTb = Object.keys(s.tablo).length;
  const dokunur = nRpc + nTb > 0;
  console.log(
    (s.name + (s.exported ? "" : " ·iç")).slice(0, 23).padEnd(24) +
    (s.file.replace("src/", "") + ":" + s.startLine).padEnd(22) +
    (s.loading ? " ✓ " : dokunur ? " ✗ " : " – ").padEnd(5) +
    (s.empty ? " ✓ " : dokunur ? " ✗ " : " – ").padEnd(5) +
    (s.hata ? " ✓ " : dokunur ? " ✗ " : " – ").padEnd(6) +
    String(nRpc).padEnd(5) + String(nTb).padEnd(7) + (s.yutulan || ""));
  if (dokunur && (!s.loading || !s.empty || !s.hata))
    eksik.push({ s, yok: [!s.loading && "yükleniyor", !s.empty && "boş", !s.hata && "hata"].filter(Boolean) });
}

console.log("\n" + "=".repeat(112));
console.log("VERİ ÇEKEN AMA DURUMU EKSİK OLAN EKRANLAR");
console.log("=".repeat(112));
if (!eksik.length) console.log("✓ Veri çeken her ekranda üç durum da var.");
for (const e of eksik)
  console.log(`  ${e.s.file}:${e.s.startLine}  ${e.s.name.padEnd(22)} EKSİK: ${e.yok.join(" + ")}` +
              `   (rpc:${e.s.rpcs.length} tablo:${Object.keys(e.s.tablo).length})`);

console.log("\n" + "=".repeat(112));
console.log("HATA YUTULAN OKUMALAR — `const { data } = await supabase…` (error destructure edilmiyor)");
console.log("=".repeat(112));
const yut = hepsi.filter(s => s.yutulan > 0).sort((a, b) => b.yutulan - a.yutulan);
let toplamYut = 0;
for (const s of yut) { toplamYut += s.yutulan; console.log(`  ${s.file}:${s.startLine}  ${s.name.padEnd(24)} ${s.yutulan} adet`); }
console.log(`  TOPLAM: ${toplamYut}`);

console.log("\n" + "=".repeat(112));
console.log("EKRAN → RPC / TABLO DÖKÜMÜ");
console.log("=".repeat(112));
for (const s of hepsi) {
  if (!s.rpcs.length && !Object.keys(s.tablo).length) continue;
  console.log(`\n▸ ${s.name}   (${s.file}:${s.startLine}-${s.endLine})`);
  if (s.rpcs.length) console.log(`    RPC   : ${s.rpcs.join(", ")}`);
  for (const [t, ops] of Object.entries(s.tablo)) console.log(`    TABLO : ${t} [${ops.join(",")}]`);
  console.log(`    DURUM : yükleniyor=${s.loading || "YOK"} · boş=${s.empty || "YOK"} · hata=${s.hata || "YOK"}`);
}
