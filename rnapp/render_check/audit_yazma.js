#!/usr/bin/env node
/**
 * render_check/audit_yazma.js — YAZMA YOLLARINDA YUTULAN HATA (yalnız okur)
 *
 * check.js zaten OKUMA yollarındaki yutulan hatayı sayıyor (`const { data }
 * = await supabase...`) ve bir tavanla tutuyor. Bu dosya DAHA PAHALI olan
 * sınıfı ayırıyor: KULLANICI BİR ŞEY YAPTI, sunucu reddetti, kullanıcıya
 * HİÇBİR ŞEY SÖYLENMEDİ.
 *
 * Okuma hatası → ekran boş görünür (kötü).
 * Yazma hatası → kullanıcı işini yaptığını SANIR (çok daha kötü).
 *
 * ÖLÇÜM: her `supabase.rpc(...)` / `.insert/.update/.upsert/.delete`
 * çağrısı için sonucun ne yapıldığına bakılır:
 *   TAM YUTULAN : sonuç hiç alınmıyor (`await supabase.rpc(...)` tek başına)
 *   YARIM       : `{ data }` alınıyor, `error` alınmıyor
 *   SESSİZ LOG  : `error` alınıyor ama yalnız console'a yazılıyor
 *   GÖSTERİLİYOR: `error` alınıyor ve setErr/mapErr/setХ ile ekrana gidiyor
 */
const fs = require("fs");
const path = require("path");
const parser = require("@babel/parser");

const APP = require("./ll_paths").APP;   // v2.84: sabit yol kaldirildi
const FILES = ["App.js", ...fs.readdirSync(path.join(APP, "src"))
  .filter(f => f.endsWith(".js")).map(f => "src/" + f)];

// Yazma sayılan RPC adları: adı bir EYLEM olan her şey.
const YAZMA_RPC = /^(create_|respond_|start_|confirm_|cancel_|rate_|send_|save_|set_|apply_|grant_|redeem_|join_|claim_|delete_|remove_|change_|submit_|defer_|verify_|mark_|request_credit|sos_alert|block_|report_)/;

const bulgular = [];

for (const f of FILES) {
  const code = fs.readFileSync(path.join(APP, f), "utf8");
  let ast;
  try { ast = parser.parse(code, { sourceType: "module", plugins: ["jsx"] }); }
  catch (e) { console.log(`PARSE HATASI ${f}: ${e.message}`); continue; }

  (function walk(n, parents) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { n.forEach(x => walk(x, parents)); return; }
    if (!n.type) return;

    // 🔴 BURADA BİR `return` VARDI VE DENETİMİ SESSİZCE KÖRLEŞTİRİYORDU.
    // `.from("availabilities").update({...}).eq("id", r.id)` ifadesinde EN
    // DIŞTAKİ çağrı `.eq()`tir. `.eq` yazma listesinde olmadığı için
    // `if (!etiket) return;` satırı ÇALIŞIYOR ve alt ağaca hiç inilmiyordu —
    // yani içerideki `.update()` HİÇ GÖRÜLMÜYORDU. screens.js:835'teki
    // "İlanı sil" düğmesi tam olarak bu yüzden listede yoktu.
    // Ders: bir düğümü elemek, ÇOCUKLARINI da elemek demek değildir.
    if (n.type === "CallExpression" && n.callee.type === "MemberExpression") { incele(n); }
    for (const k of Object.keys(n)) {
      if (k === "loc" || k === "start" || k === "end") continue;
      walk(n[k], parents);
    }
    return;

    function incele(n) {
      const prop = n.callee.property.name;
      const a0 = n.arguments[0];
      let etiket = null;
      if (prop === "rpc" && a0 && a0.type === "StringLiteral" && YAZMA_RPC.test(a0.value))
        etiket = "rpc:" + a0.value;
      if (["insert", "update", "upsert", "delete"].includes(prop)) {
        // hangi tabloda? zincirde geriye doğru `.from("x")` ara
        const seg = code.slice(Math.max(0, n.start - 260), n.end);
        const m = [...seg.matchAll(/\.from\(\s*"([a-z_]+)"/g)].pop();
        // 🔴 YANLIŞ ALARM DÜZELTİLDİ (ölçümle): ilk koşuda
        //   src/runtime.js:66  tablo:?.delete
        // çıktı. Oysa oradaki `_dinleyiciler.delete(fn)` bir JS Set
        // işlemi — Supabase ile ilgisi yok. `.from("tablo")` bulunamayan
        // bir `.delete()` zincirini "tablo yazması" saymak, denetimi
        // gürültüye boğar ve gerçek 11 bulguyu 12'de gizler.
        if (!m) return;
        etiket = "tablo:" + m[1] + "." + prop;
      }
      if (!etiket) return;   // yalnız BU düğümü ele; çocuklara yukarıda inildi

      // Bu çağrının sonucuyla ne yapılıyor? Kaynaktan çağrı satırının
      // BULUNDUĞU ifadeyi (statement) alıp inceliyoruz.
      const line = n.loc.start.line;
      const parca = code.slice(Math.max(0, n.start - 300), Math.min(code.length, n.end + 420));
      const oncesi = code.slice(Math.max(0, n.start - 300), n.start);

      // atama kalıbı: `const { error } = await supabase.rpc(...)`
      const atama = /(?:const|let|var)\s*\{([^}]*)\}\s*=\s*(?:await\s+)?$/.exec(oncesi.replace(/\s+$/, "") + " ")
        || /(?:const|let|var)\s*\{([^}]*)\}\s*=\s*await\s*$/.exec(oncesi);
      const destr = atama ? atama[1] : null;
      const thenli = /\)\s*\n?\s*\.then\s*\(\s*\(\s*\{([^}]*)\}/.exec(parca);

      let durum, kanit;
      const errAdi = (destr && /(^|[\s,:])error(\s*:\s*(\w+))?/.exec(destr)) ||
                     (thenli && /(^|[\s,:])error(\s*:\s*(\w+))?/.exec(thenli[1]));
      if (!destr && !thenli) {
        durum = "TAM YUTULAN"; kanit = "sonuç hiç alınmıyor";
      } else if (!errAdi) {
        durum = "YARIM"; kanit = "{ " + (destr || thenli[1]).trim() + " } — error yok";
      } else {
        const v = (errAdi[3] || "error");
        const sonrasi = code.slice(n.end, Math.min(code.length, n.end + 700));
        const gosterilir = new RegExp("(setErr|setError|mapErr|setMsg|setUyari|setFail|setFailed|setHata)\\s*\\(").test(sonrasi) &&
                           new RegExp("\\b" + v + "\\b").test(sonrasi);
        const loglanir = new RegExp("console\\.(warn|error|log)").test(sonrasi) &&
                         new RegExp("\\b" + v + "\\b").test(sonrasi);
        const kullanilir = new RegExp("\\b" + v + "\\b").test(sonrasi);
        durum = gosterilir ? "GÖSTERİLİYOR" : loglanir ? "SESSİZ LOG"
              : kullanilir ? "DALLANIYOR (ekrana yok)" : "ALINDI AMA KULLANILMIYOR";
        kanit = "error → " + v;
      }
      bulgular.push({ f, line, etiket, durum, kanit });
    }
  })(ast, []);
}

console.log("=".repeat(100));
console.log("YAZMA YOLLARI — kullanıcı bir şey yaptı; sunucu reddederse HABERİ OLUYOR MU?");
console.log("=".repeat(100));

const sira = ["TAM YUTULAN", "YARIM", "ALINDI AMA KULLANILMIYOR", "SESSİZ LOG", "DALLANIYOR (ekrana yok)", "GÖSTERİLİYOR"];
const grup = {};
bulgular.forEach(b => (grup[b.durum] = grup[b.durum] || []).push(b));
console.log(`Toplam yazma çağrısı: ${bulgular.length}\n`);
for (const d of sira) {
  const g = grup[d] || [];
  console.log(`${d.padEnd(26)} ${String(g.length).padStart(3)}`);
}

console.log("\n" + "=".repeat(100));
console.log("🔴 KULLANICIYA HİÇBİR ŞEY SÖYLENMEYENLER (dosya:satır)");
console.log("=".repeat(100));
for (const d of ["TAM YUTULAN", "YARIM", "ALINDI AMA KULLANILMIYOR"]) {
  const g = grup[d] || [];
  if (!g.length) continue;
  console.log(`\n--- ${d} (${g.length}) ---`);
  g.forEach(b => console.log(`  ${b.f}:${b.line}  ${b.etiket.padEnd(34)} ${b.kanit}`));
}

const g2 = grup["SESSİZ LOG"] || [];
if (g2.length) {
  console.log(`\n--- SESSİZ LOG: yalnız console'a yazılıyor, kullanıcı görmez (${g2.length}) ---`);
  g2.forEach(b => console.log(`  ${b.f}:${b.line}  ${b.etiket.padEnd(34)} ${b.kanit}`));
}
