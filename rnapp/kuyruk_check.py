# -*- coding: utf-8 -*-
"""
LoungeLink · kuyruk_check.py  —  61. DENETİM
ÇEVRİMDIŞI MESAJ KUYRUĞU — MÜKERRER YOK, SESSİZ KAYIP YOK

🔴 NEDEN VAR — GÖKBERK (offline brief) + "doğru bir kararla tamamla"
Bir mesaj kuyruğunun iki ölümcül hatası vardır ve ikisi de SESSİZDİR:
  1. MÜKERRER TESLİM — ağ yarıda koparsa istek sunucuya ulaşmış ama
     cevap dönmemiş olabilir; körü körüne tekrar gönderim sohbette iki
     kopya bırakır ve kullanıcı "ben iki kez mi yazdım?" der.
  2. SESSİZ KAYIP — kalıcı bir hata (RLS reddi) alan mesaj kuyruktan
     atılırsa, kullanıcı gönderdiğini sanır. Hiç göndermemekten kötüdür.

Bu denetim `src/cevrimdisi.js`i node ile GERÇEKTEN koşturur: sahte bir
AsyncStorage ve sahte bir Supabase ile 8 senaryo oynar.

🆕 SINIF: "BİR KUYRUĞUN DOĞRULUĞU MUTLU YOLDA DEĞİL, AĞIN YARIDA
KOPTUĞU YERDE ÖLÇÜLÜR."
"""
import os, sys, json, subprocess, tempfile

KOK = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(KOK, "src", "cevrimdisi.js")

BETIK = r"""
// ── Sahte AsyncStorage (bellekte) ───────────────────────────────────
const depo = new Map();
const sahteDepo = {
  getItem: async (k) => (depo.has(k) ? depo.get(k) : null),
  setItem: async (k, v) => { depo.set(k, v); },
  removeItem: async (k) => { depo.delete(k); },
};

// ── Sahte Supabase ──────────────────────────────────────────────────
// `senaryo` her insert'te ne olacağını söyler.
const gonderilen = [];
let senaryo = () => ({ error: null });
const sahteSupabase = {
  from: () => ({
    insert: async (row) => {
      const r = senaryo(row);
      if (!r.error) gonderilen.push(row);
      return r;
    },
  }),
};
const kayitlar = [];
const sahteLogError = (ad, e) => kayitlar.push(ad);

// ── Modülü sahte bağımlılıklarla yükle ──────────────────────────────
import { readFileSync, writeFileSync, unlinkSync } from "fs";
const kaynak = readFileSync(process.argv[2], "utf8")
  .replace('import AsyncStorage from "@react-native-async-storage/async-storage";',
           "const AsyncStorage = globalThis.__DEPO;")
  .replace('import { logError, supabase } from "./supabase";',
           "const logError = globalThis.__LOG, supabase = globalThis.__SB;");
globalThis.__DEPO = sahteDepo; globalThis.__SB = sahteSupabase; globalThis.__LOG = sahteLogError;
const gecici = process.argv[2].replace(/\.js$/, ".__sinama.mjs");
writeFileSync(gecici, kaynak);
const M = await import("file://" + gecici);
unlinkSync(gecici);

const sonuc = {};
const msj = (b) => ({ channel_id: "kanal-1", from_id: "ben", body: b });

// 1 · ÇEVRİMDIŞI: gönderim düşer, mesaj KUYRUKTA KALIR
senaryo = () => ({ error: { message: "Network request failed" } });
await M.mesajKuyruga(msj("bir"));
let r = await M.kuyrugaAkit();
sonuc.cevrimdisi_kalan = r.kalan;
sonuc.cevrimdisi_gonderildi = r.gonderildi;

// 2 · AĞ DÖNDÜ: kuyruk kendiliğinden boşalır
senaryo = () => ({ error: null });
r = await M.kuyrugaAkit();
sonuc.donunce_gonderildi = r.gonderildi;
sonuc.donunce_kalan = r.kalan;

// 3 · SIRA KORUNUR
depo.clear(); gonderilen.length = 0;
senaryo = () => ({ error: { message: "network" } });
for (const b of ["a", "b", "c"]) await M.mesajKuyruga(msj(b));
senaryo = () => ({ error: null });
await M.kuyrugaAkit();
sonuc.sira = gonderilen.map((x) => x.body).join("");

// 4 · İDEMPOTANS: her kayıt kendi `id`siyle gidiyor mu
sonuc.idli = gonderilen.every((x) => typeof x.id === "string" && x.id.length >= 32);
sonuc.idler_tekil = new Set(gonderilen.map((x) => x.id)).size === gonderilen.length;

// 5 · 23505 = ZATEN TESLİM = BAŞARI (mükerrer bırakmaz)
depo.clear(); gonderilen.length = 0;
senaryo = () => ({ error: { code: "23505", message: "duplicate key" } });
await M.mesajKuyruga(msj("tekrar"));
r = await M.kuyrugaAkit();
sonuc.dup_kalan = r.kalan;
sonuc.dup_gonderildi = r.gonderildi;

// 6 · KALICI HATA: SESSİZCE SİLİNMEZ, "dustu" olarak durur
depo.clear();
senaryo = () => ({ error: { code: "42501", message: "new row violates row-level security policy" } });
await M.mesajKuyruga(msj("yasak"));
await M.kuyrugaAkit();
let l = await M.kuyrugaBak();
sonuc.kalici_kayit_sayisi = l.length;
sonuc.kalici_durum = l[0] && l[0].durum;

// 7 · TAVAN: dolunca YENİYİ reddeder ve SÖYLER (eskiyi atmaz)
depo.clear();
senaryo = () => ({ error: { message: "network" } });
for (let i = 0; i < 205; i++) await M.mesajKuyruga(msj("m" + i));
l = await M.kuyrugaBak();
sonuc.tavan = l.length;
const son = await M.mesajKuyruga(msj("tasan"));
sonuc.tavan_reddi = son.ok === false && son.kod === "kuyruk_dolu";
sonuc.tavan_ilk_korundu = l[0].body === "m0";

// 8 · ÖNBELLEK: yaş taşınıyor, bayat işaretleniyor
depo.clear();
await M.onbellegeYaz("sohbet:x", [{ id: 1 }]);
const onb = await M.onbellektenOku("sohbet:x");
sonuc.onbellek_var = !!(onb && Array.isArray(onb.veri) && onb.veri.length === 1);
sonuc.onbellek_yas_var = !!(onb && typeof onb.yasMs === "number");
sonuc.onbellek_taze = onb && onb.bayat === false;

console.log(JSON.stringify(sonuc));
"""

with tempfile.NamedTemporaryFile("w", suffix=".mjs", delete=False, encoding="utf-8") as f:
    f.write(BETIK)
    yol = f.name
cev = subprocess.run(["node", yol, MOD], capture_output=True, text=True, cwd=KOK)
os.unlink(yol)

if cev.returncode != 0:
    print("kuyruk_check · ✗ kuyruk KOŞTURULAMADI")
    print(cev.stderr.strip()[:900])
    sys.exit(1)

r = json.loads(cev.stdout)
hata = []


def bekle(ad, anahtar, beklenen):
    # ⚠️ İLK SÜRÜM `r["anahtar"]` ile doğrudan okuyordu ve MUTASYON
    # SINAMASINDA ÇÖKTÜ (KeyError): kuyruk boşalınca `sonuc.kalici_durum`
    # undefined oluyor, JSON'a hiç yazılmıyor. Çöken bir nöbetçi rapor
    # vermez — yani tam da bulması gereken anda susar.
    # 🆕 SINIF: "BİR DENETİM, DENETLEDİĞİ ŞEY BOZUKKEN ÇÖKÜYORSA, O
    # DENETİM YALNIZ SAĞLAM KODU DENETLİYOR DEMEKTİR."
    gercek = r.get(anahtar, "<ALAN YOK>")
    if gercek != beklenen:
        hata.append(f"{ad}: {gercek!r} — {beklenen!r} bekleniyordu")


bekle("çevrimdışı mesaj kuyrukta kalmalı", "cevrimdisi_kalan", 1)
bekle("çevrimdışı hiç gönderilmemeli", "cevrimdisi_gonderildi", 0)
bekle("ağ dönünce gitmeli", "donunce_gonderildi", 1)
bekle("ağ dönünce kuyruk boşalmalı", "donunce_kalan", 0)
bekle("sıra korunmalı", "sira", "abc")
bekle("her mesaj kendi id'siyle gitmeli", "idli", True)
bekle("id'ler tekil olmalı", "idler_tekil", True)
bekle("23505 başarı sayılmalı (mükerrer yok)", "dup_gonderildi", 1)
bekle("23505 sonrası kuyruk boşalmalı", "dup_kalan", 0)
bekle("kalıcı hata SİLİNMEMELİ", "kalici_kayit_sayisi", 1)
bekle("kalıcı hata 'dustu' işaretlenmeli", "kalici_durum", "dustu")
bekle("tavan uygulanmalı", "tavan", 200)
bekle("tavan dolunca yeni REDDEDİLMELİ", "tavan_reddi", True)
bekle("tavanda EN ESKİ korunmalı", "tavan_ilk_korundu", True)
bekle("önbellek okunmalı", "onbellek_var", True)
bekle("önbellek yaşı taşınmalı", "onbellek_yas_var", True)
bekle("taze önbellek bayat olmamalı", "onbellek_taze", True)

# ── Kaynak değişmezleri ───────────────────────────────────────────────
kaynak = open(MOD, encoding="utf-8").read()
if "NetInfo" in kaynak.replace("`NetInfo`", "").replace("NetInfo\"", ""):
    pass   # yorumda geçmesi serbest; asıl kural aşağıda
try:
    pkg = json.load(open(os.path.join(KOK, "package.json"), encoding="utf-8"))
    if "@react-native-community/netinfo" in pkg.get("dependencies", {}):
        hata.append("NetInfo bağımlılık olarak eklenmiş — KARAR 2 (havalimanı "
                    "giriş portalı) gerekçesi hâlâ geçerliyse kaldırılmalı, "
                    "değilse gerekçe güncellenmeli")
except Exception:
    pass

print(f"kuyruk_check · 17 davranış sınaması · bulgu: {len(hata)}")
for h in hata[:10]:
    print(f"   ✗ {h}")
if hata:
    print("\n✗ Kuyruk beklenen davranışı vermiyor.")
    print("  İki değişmez: MÜKERRER TESLİM YOK · SESSİZ KAYIP YOK.")
    sys.exit(1)
print("✓ mükerrer teslim yok · sessiz kayıp yok · sıra korunuyor · tavan çalışıyor")
