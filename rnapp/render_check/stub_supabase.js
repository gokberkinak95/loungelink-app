// Supabase istemcisinin taklidi. Ekranlar veriyi buradan çeker; her senaryo
// için farklı yanıt seti verilebilir (globalThis.__DATA).
function tableResult(name) {
  const D = globalThis.__DATA || {};
  return D.tables && D.tables[name] !== undefined ? D.tables[name] : [];
}

function makeQuery(table) {
  const chain = {};
  const methods = ["select", "eq", "neq", "in", "gte", "lte", "gt", "lt", "or", "is",
                   "order", "limit", "range", "not", "filter", "contains", "ilike", "like", "update",
                   "insert", "upsert", "delete", "match"];
  methods.forEach(m => { chain[m] = () => chain; });
  chain.single = async () => ({ data: (tableResult(table)[0] ?? null), error: null });
  chain.maybeSingle = async () => ({ data: (tableResult(table)[0] ?? null), error: null });
  chain.then = (res) => Promise.resolve({ data: tableResult(table), error: null, count: tableResult(table).length }).then(res);
  return chain;
}

const supabase = {
  from: (t) => makeQuery(t),
  // 🔴 GERÇEK DAVRANIŞ TAKLİDİ: supabase-js'in rpc() dönüşü Promise DEĞİL,
  // PostgrestFilterBuilder'dır — "thenable"dır (then var) ama .catch/.finally
  // YOKTUR. Stub bunu async fonksiyonla taklit ettiği için ".catch is not a
  // function" hatası testlerden kaçmıştı (v1.79'da beyaz ekrana sebep oldu).
  // Artık stub da aynı sınırı taşıyor; .catch çağıran kod testte patlar.
  rpc: (fn) => {
    const D = globalThis.__DATA || {};
    const v = D.rpc && D.rpc[fn];
    const result = (v === undefined) ? { data: null, error: null }
      : (v && v.__error) ? { data: null, error: { message: v.__error } }
      : { data: v, error: null };
    return {
      then: (res, rej) => Promise.resolve(result).then(res, rej),
      select: function () { return this; },
      single: async () => result,
      maybeSingle: async () => result,
    };
  },
  channel: () => ({ on: function () { return this; }, subscribe: function () { return this; }, unsubscribe: () => {} }),
  removeChannel: () => {},
  auth: {
    getSession: async () => ({ data: { session: (globalThis.__DATA || {}).session || null } }),
    getUser: async () => ({ data: { user: ((globalThis.__DATA || {}).session || {}).user || null } }),
    onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
    signInWithPassword: async () => ({ error: null }),
    signInWithOtp: async () => ({ error: null }),
    verifyOtp: async () => ({ error: null }),
    signInWithOAuth: async () => ({ data: { url: "https://example.test/oauth" }, error: null }),
    signInWithIdToken: async () => ({ error: null }),
    exchangeCodeForSession: async () => ({ error: null }),
    setSession: async () => ({ error: null }),
    signUp: async () => ({ error: null }),
    signOut: async () => ({ error: null }),
    resetPasswordForEmail: async () => ({ error: null }),
  },
};

module.exports = {
  supabase,
  setAppVersion: () => {},
  logError: () => {},
  pickAndUploadPhoto: async () => null,
};
