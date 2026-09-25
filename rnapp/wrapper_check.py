#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · wrapper_check.py   (v2.37'de doğdu)

🔴 NEDEN VAR

140'ta `create_request`'i hız sınırı eklemek için sarmaladım ve DÖRT
hata birden yaptım:
  1. parametre sırası yanlış (p_intro / p_type yer değiştirmiş)
  2. `p_idem` DÜŞTÜ — çift gönderim koruması!
  3. dönüş tipi yanlış (uuid yazdım, gerçeği jsonb)
  4. gövde eski sürümden alınmış (`request_type` kolonu artık yok)

Hepsinin tek sebebi vardı: gövdeyi grep sonucunun ORTASINDAN aldım,
SONUNDAN değil. `p_idem` düşseydi kullanıcı iki kez dokununca iki
istek oluşur, kredi iki kez inerdi.

NEDEN AYRI DOSYA: bu denetimi returns_check.py içine üç kez eklemeye
çalıştım, üçünde de başka bir yerde takıldı (regex geri izleme, sözlük
ezilmesi, tuple çözümlemesi). Karmaşık bir dosyaya dördüncü kez
dokunmak yerine kendi dosyasını yazmak, hem doğrulanabilir hem okunur.

KURAL: bir fonksiyonun `_impl` sürümü varsa, sarmalayıcının imzası
ve dönüş tipi `_impl` ile AYNI olmalı.

⚠️ BU DENETİMİN ÖLÇÜLMÜŞ KÖR NOKTASI (v2.78'de öğrenildi):
Burada anahtar (fonksiyon, DOSYA) çiftidir — yani sarmalayıcı ile
delegesi AYNI dosyada değilse bu denetim onları HİÇ eşleştirmez.
212 turunda tam bu oldu: `partner_gate` 209'da, sarmalayıcısı 212'de
yazıldı; iki dosya da tek tek yeşildi, çalışma zamanı ise
    22P02 invalid input syntax for type uuid: "f"
verdi ve sağlayıcı panelinin beş ekranı düştü. Dosya okuyan hiçbir
denetim bunu göremez, çünkü soru "bu dosya kendi içinde tutarlı mı"
değil, "SONRAKİ dosya ÖNCEKİNİN çağırıcılarını bozdu mu".
O soruyu `sozlesme_check.py` soruyor: migration'ların TAMAMI
çalıştıktan sonra, gerçek `pg_proc` kataloğu üzerinden (pg_run.py
onu iki değişmez olarak çağırır). Bu dosya kaldırılmadı — statik
denetim ucuz ve erken uyarır; ikisi ayrı anları ölçer.
"""
import os
import re
import sys

# 🔴 v2.46 — BU DOSYA ll_paths GÖÇÜNDEN ATLANMIŞTI.
# Dokuz denetimin sekizi ll_paths üzerinden yol çözüyordu; yalnız bu
# dosya `ROOT/sql` sabitini koruyordu. SQL klasörü rnapp'in içinde
# değilse `npm run verify` sekizinci adımda FileNotFoundError ile
# çöküyordu — üstelik önceki yedi denetim yeşil yandıktan sonra.
# Daha kötü ihtimal: rnapp/sql VAR ama BAYAT olsaydı, denetim hiç
# şikâyet etmeden YANLIŞ dosyaları okurdu.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ll_paths

ROOT = os.path.dirname(os.path.abspath(__file__))
SQL, _ = ll_paths.require_sql("wrapper_check")

FUNC = re.compile(
    r"create\s+or\s+replace\s+function\s+(?:public\.)?(\w+)\s*\(([^)]*)\)"
    r"\s*returns\s+(\w+)",
    re.I | re.S,
)


def arg_types(argstr):
    """Parametre listesinden yalnız TİPLERİ çıkarır (ad ve varsayılan atılır)."""
    out = []
    for part in argstr.split(","):
        toks = part.strip().split()
        if len(toks) >= 2:
            out.append(toks[1].lower().rstrip("[]").split("(")[0])
    return out


def main():
    pairs = {}
    for fn in sorted(os.listdir(SQL)):
        if not fn.endswith(".sql"):
            continue
        src = open(os.path.join(SQL, fn), encoding="utf-8", errors="replace").read()
        for m in FUNC.finditer(src):
            full, args, ret = m.group(1), m.group(2), m.group(3)
            if full.endswith("_impl"):
                base, kind = full[:-5], "impl"
            else:
                base, kind = full, "main"
            # Anahtar DOSYAYI da içerir: sarmalayıcı ve _impl aynı dosyada
            # yaşar. Yalnız adla anahtarlarsam başka dosyadaki eski tanım
            # karşılaştırmayı bozar.
            pairs.setdefault((base, fn), {})[kind] = (arg_types(args), ret.lower())

    bad = []
    atlanan = []      # imzasi metinden okunamayanlar (dinamik yaratim)
    checked = 0
    for (name, fn), v in sorted(pairs.items()):
        if "impl" not in v or "main" not in v:
            continue
        checked += 1
        (ia, iret), (ma, mret) = v["impl"], v["main"]

        # 🔴 19 Agu 2026 — YANLIS ALARM. ETKIN_TANIMLAR.sql yeniden
        # uretilince (200 → 319 fonksiyon) bu denetim su hatayi verdi:
        #     create_request — imza farkli — sarmalayici('uuid','text',
        #     'text','text') vs impl()
        # Gercek veritabaninda olctum, UCU DE AYNI imzada:
        #     create_request(p_avail_id uuid, p_type text, p_intro text, p_idem text)
        #     create_request_impl(ayni)
        #     create_request_impl_preflag(ayni)
        #
        # Sebep: bazi _impl fonksiyonlari `execute format(...)` ile
        # DINAMIK olarak yaratiliyor (212'nin bayrak sarmalayicisi gibi).
        # Metinde parametre listesi gorunmuyor, bu denetim de "impl()"
        # okuyup bos sanip farkli sayiyor.
        #
        # Bir denetimin yanlis alarm vermesi, hic denetim olmamasindan
        # kotudur: insan kirmiziyi gormezden gelmeyi ogrenir. Parametre
        # listesi BOS okunduysa "farkli" demiyoruz, OLCEMEDIK diyoruz.
        if not ia and ma:
            atlanan.append((fn, name))
            continue
        if ia != ma:
            bad.append((fn, name, f"imza farklı — sarmalayıcı{tuple(ma)} vs impl{tuple(ia)}",
                        "Parametre düşüyor ya da sırası kaymış olabilir."))
        if iret != mret:
            bad.append((fn, name, f"dönüş tipi farklı — sarmalayıcı→{mret}, impl→{iret}",
                        "Çağıran taraf beklemediği bir şey alır."))

    print("=" * 70)
    print("SARMALAYICI DENETİMİ — wrapper ile _impl aynı imzada mı?")
    print("=" * 70)

    # Atlananlar SESSIZ GECMIYOR: kac cift olculemedi, ekranda yazsin.
    # "0 sorun" ile "3 sey olcemedim, kalaninda 0 sorun" ayni cumle degil.
    if atlanan:
        print(f"  ℹ {len(atlanan)} çift ÖLÇÜLEMEDİ (impl dinamik yaratılıyor, "
              f"imza metinde yok): " + ", ".join(sorted({n for _, n in atlanan})))
        print("      Bunları doğrulamak için canlı imzaya bakmak gerekir:")
        print("      select pg_get_function_identity_arguments(oid) from pg_proc ...")

    if not bad:
        print(f"✓ {checked - len(atlanan)} sarmalayıcı/impl çifti uyumlu"
              + (f" · {len(atlanan)} çift ölçülemedi" if atlanan else ""))
        return 0

    for fn, name, msg, hint in bad:
        print(f"  ✗ {fn}: {name} — {msg}")
        print(f"      {hint}")
    print(f"\n✗ {len(bad)} uyumsuz sarmalayıcı.")
    print("  Sarmalarken imzayı HATIRLAMA, en güncel tanımı OKU.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
