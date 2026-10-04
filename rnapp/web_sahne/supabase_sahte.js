// web_sahne/supabase_sahte.js — GERÇEK EKRANLARI YEREL POSTGRES'E BAĞLAYAN TAKLİT.
//
// İki mod:
//   · KÖPRÜ (globalThis.__KOPRU = "http://127.0.0.1:8765"): her rpc()/from()
//     çağrısı `pg_kopru.py`ye gider ve yerel `ll` veritabanında GERÇEK
//     fonksiyon gövdesi + GERÇEK RLS ile koşar. Oturum = globalThis.__SESSION.
//   · FİKSTÜR (köprü yoksa): render_check/harness.js sözleşmesi
//     (globalThis.__CFG.rpc / .tables).
// `rpc()` gerçek supabase-js gibi `then` taşır, `catch` taşımaz.
globalThis.__CFG = globalThis.__CFG || { rpc: {}, tables: {} };
globalThis.__CALLS = globalThis.__CALLS || [];

function uid() { return (globalThis.__SESSION && globalThis.__SESSION.user && globalThis.__SESSION.user.id) || null; }

// ══════════════════════════════════════════════════════════════════
// 🔴 12 EYLÜL · GECE — ARIZA ENJEKSİYONU.
// Gökberk: "ürünü hep iyi gününde ölçüyoruz." Doğru: 45 sahnenin
// hepsinde sunucu çalışıyor, veri geliyor, hiçbir şey düşmüyor.
// Oysa `LoadFail` bileşeni tam da bunun için var ve bugüne kadar
// HİÇ ÇEKİLMEDİ — yani "veri gelmezse ekran ne diyor" sorusunun
// cevabını kimse görmedi.
// `?bozuk=tablo1,fn2` ile o çağrılar ağ hatası döndürüyor; gerisi
// ürünün kendi kodu. Taklit değil: gerçek `error` nesnesi, gerçek
// `catch` yolu, gerçek `mapErr`.
// 🆕 SINIF: "BİR ÜRÜNÜ YALNIZ İYİ GÜNÜNDE ÖLÇERSEN, KÖTÜ GÜNÜNÜ
// KULLANICI KEŞFEDER."
// ══════════════════════════════════════════════════════════════════
function bozukMu(istek) {
  const liste = globalThis.__BOZUK;
  if (!liste || !liste.length) return false;
  const ad = istek.fn || istek.table || "";
  return liste.indexOf(ad) >= 0 || liste.indexOf("*") >= 0;
}

async function kopru(istek) {
  if (bozukMu(istek)) {
    const hata = { message: "Network request failed", code: "ARIZA" };
    globalThis.__CALLS.push({ kind: istek.kind, fn: istek.fn, table: istek.table, error: hata.message });
    return { data: null, error: hata, count: null };
  }
  const r = await fetch(globalThis.__KOPRU, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ ...istek, uid: uid() }),
  });
  const out = await r.json();
  globalThis.__CALLS.push({ kind: istek.kind, fn: istek.fn, table: istek.table, error: out.error ? out.error.message : null });
  return out;
}

// ── FİKSTÜR modu ───────────────────────────────────────────────────
function cfgTable(name) { const c = globalThis.__CFG.tables || {}; return name in c ? c[name] : []; }
function tableResult(name, filt) {
  let v = cfgTable(name);
  if (v && v.__error) return { data: null, error: { message: v.__error, code: v.__code || "42501" }, count: null };
  if (Array.isArray(v) && filt.length) v = v.filter((row) => filt.every((f) => f.op !== "eq" || !(f.col in row) || row[f.col] === f.val));
  return { data: v, error: null, count: Array.isArray(v) ? v.length : null };
}

function makeQuery(table) {
  const d = { kind: "from", table, op: "select", select: "*", filters: [], order: [] };
  const q = {};
  q.select = (s, opts) => { d.select = s || "*"; if (opts && opts.count) d.count = opts.count; if (opts && opts.head) d.head = true; return q; };
  ["eq", "neq", "gt", "gte", "lt", "lte", "in", "is", "ilike", "like"].forEach((op) => {
    q[op] = (col, val) => { d.filters.push({ op, col, val }); return q; };
  });
  q.not = (col, iop, val) => { d.filters.push({ op: "not", iop, col, val }); return q; };
  q.or = (s) => { d.filters.push({ op: "or", col: "", val: s }); return q; };
  q.filter = (col, op, val) => { d.filters.push({ op, col, val }); return q; };
  q.match = (o) => { Object.keys(o).forEach((k) => d.filters.push({ op: "eq", col: k, val: o[k] })); return q; };
  q.contains = () => q;
  q.order = (col, o) => { d.order.push({ col, asc: !(o && o.ascending === false) }); return q; };
  q.limit = (n) => { d.limit = n; return q; };
  q.range = (a, b) => { d.range = [a, b]; return q; };
  q.insert = (v) => { d.op = "insert"; d.values = v; return q; };
  q.upsert = (v) => { d.op = "upsert"; d.values = v; return q; };
  q.update = (v) => { d.op = "update"; d.values = v; return q; };
  q.delete = () => { d.op = "delete"; return q; };
  const kos = async () => {
    if (globalThis.__KOPRU) return kopru(d);
    globalThis.__CALLS.push({ kind: "from", table });
    const r = tableResult(table, d.filters);
    if (d.single) return { data: r.error ? null : (Array.isArray(r.data) ? (r.data[0] ?? null) : r.data), error: r.error };
    return r;
  };
  q.maybeSingle = () => { d.single = "maybeSingle"; return kos(); };
  q.single = () => { d.single = "single"; return kos(); };
  q.then = (res, rej) => kos().then(res, rej);
  return q;
}

function makeRpc(fn, args) {
  let soz;
  if (globalThis.__KOPRU) {
    soz = kopru({ kind: "rpc", fn, args: args || {} });
  } else {
    globalThis.__CALLS.push({ kind: "rpc", fn, args });
    const c = globalThis.__CFG.rpc || {};
    let v = (fn in c) ? c[fn] : undefined;
    if (typeof v === "function") v = v(args);
    soz = Promise.resolve((v === undefined) ? { data: null, error: null }
      : (v && v.__error) ? { data: null, error: { message: v.__error, code: v.__code || "42501" } }
      : { data: v, error: null });
  }
  return {
    then: (res, rej) => soz.then(res, rej),
    select: function () { return this; },
    single: () => soz,
    maybeSingle: () => soz,
  };
}

function authOlay(tur, oturum) {
  (globalThis.__AUTH_CB || []).forEach((cb) => { try { cb(tur, oturum); } catch (e) {} });
}

export const supabase = {
  from: makeQuery,
  rpc: makeRpc,
  storage: { from: () => ({
    upload: async () => ({ error: null }),
    getPublicUrl: () => ({ data: { publicUrl: "" } }),
    createSignedUrl: async () => ({ data: { signedUrl: "" }, error: null }),
  }) },
  auth: {
    getSession: async () => ({ data: { session: globalThis.__SESSION || null }, error: null }),
    getUser: async () => ({ data: { user: (globalThis.__SESSION || {}).user || null }, error: null }),
    // 4 Ekim 2026 — köprü varken kimlik GERÇEK (pg_kopru `kind: auth`): kayıt
    // auth.users'a yazar, tetikleyici çalışır; giriş şifreyi doğrular; oturum
    // olayları uygulamanın dinleyicisine gerçekten gider. `?onay=acik` →
    // e-posta doğrulaması açık davranışı (kayıt oturum döndürmez).
    onAuthStateChange: (cb) => {
      (globalThis.__AUTH_CB = globalThis.__AUTH_CB || []).push(cb);
      return { data: { subscription: { unsubscribe() {} } } };
    },
    signOut: async () => { globalThis.__SESSION = null; authOlay("SIGNED_OUT", null); return { error: null }; },
    setSession: async () => ({ data: {}, error: null }),
    signInWithPassword: async ({ email, password } = {}) => {
      if (!globalThis.__KOPRU) return { data: { session: globalThis.__SESSION }, error: null };
      const r = await kopru({ kind: "auth", op: "signin", email, password });
      if (r.error) return { data: { session: null, user: null }, error: r.error };
      globalThis.__SESSION = r.data.session; authOlay("SIGNED_IN", r.data.session);
      return { data: r.data, error: null };
    },
    signUp: async ({ email, password, options } = {}) => {
      if (!globalThis.__KOPRU) return { data: {}, error: null };
      const r = await kopru({ kind: "auth", op: "signup", email, password, data: (options || {}).data || {},
                              onay_kapali: globalThis.__ONAY_ACIK ? false : true });
      if (r.error) return { data: { user: null, session: null }, error: r.error };
      if (r.data.session) { globalThis.__SESSION = r.data.session; authOlay("SIGNED_IN", r.data.session); }
      return { data: r.data, error: null };
    },
    resetPasswordForEmail: async (email) => {
      if (!globalThis.__KOPRU) return { data: {}, error: null };
      const r = await kopru({ kind: "auth", op: "reset", email });
      return { data: r.data || {}, error: r.error };
    },
    resend: async () => ({ data: {}, error: null }),
    updateUser: async () => ({ data: {}, error: null }),
    verifyOtp: async () => ({ data: {}, error: null }),
    exchangeCodeForSession: async () => ({ data: {}, error: null }),
    signInWithOAuth: async () => ({ data: {}, error: null }),
    signInWithIdToken: async () => ({ data: {}, error: null }),
  },
  channel: () => ({ on: function () { return this; }, subscribe: function () { return this; } }),
  removeChannel: () => {},
};
export function setAppVersion() {}
export function logError(screen, err, code) {
  globalThis.__CALLS.push({ kind: "logError", screen, err: String(err && err.message || err), code });
  try { console.warn("[sahne logError]", screen, String(err && err.message || err), code || ""); } catch (e) {}
}
export const SUPABASE_URL = "https://sahne.invalid";
