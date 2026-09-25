#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kolon_check.py — SQL FONKSİYON GÖVDELERİNDEKİ OLMAYAN KOLONLARI BULUR.

════════════════════════════════════════════════════════════════════════
🔴 NEDEN VAR — PL/pgSQL'İN EN SESSİZ TUZAĞI
════════════════════════════════════════════════════════════════════════
Gökberk 249'u çalıştırdı ve şunu aldı:

    ERROR: 249 NOBETCI: olcum coktu: column "decision_note" does not exist

Ölçtüm: `requests` tablosunda `decision_note` diye bir kolon YOK — ve
288 migration'ın hiçbiri onu EKLEMİYOR. Yani `bayat_istekleri_iade_et()`
fonksiyonu, var olmayan bir kolona yazmaya çalışıyordu.

Peki neden benim harness'imde (pg_run.py, 288 dosya baştan sona) hiç
patlamadı? Çünkü o `update` satırı bir DÖNGÜNÜN İÇİNDE ve döngü benim
veritabanımda HİÇ DÖNMEDİ (bayat istek yoktu). PL/pgSQL bir SQL
ifadesini ancak İLK ÇALIŞTIRDIĞINDA çözümler. Çalışmayan bir dal,
denetlenmemiş bir daldır.

Yani fonksiyon "kuruldu, test edildi, yeşil" diye kayda geçti ve
canlıda ilk bayat istek oluştuğu an patlayacaktı. Bu bir test kusuru
değil, TEST EDİLEBİLİRLİK kusuru: çalıştırarak doğrulanan bir sistemde
çalışmayan kod hiçbir zaman doğrulanmaz.

🆕 SINIF: "ÇALIŞTIRARAK DOĞRULAYAN BİR HARNESS, ÇALIŞMAYAN DALI ASLA
DOĞRULAMAZ — O DALLARI ANCAK KAYNAĞA BAKAN BİR DENETİM GÖREBİLİR."

════════════════════════════════════════════════════════════════════════
NE ÖLÇER
  · `update <tablo> set kolon = ...`      → her atanan kolon var mı
  · `insert into <tablo> (k1, k2, ...)`   → her kolon var mı
Şema, migration'ların TAMAMI koşulduktan sonra gerçek veritabanından
alınıyor (`--sema-yaz`), yani "dosyada şu ALTER var mı" tahmini değil.

NE ÖLÇMEZ — ve bunu böyle söylemek testin kendisi kadar önemli:
  · `select` listesindeki kolonlar (takma adlar, fonksiyon dönüşleri,
    `record` alanları — ayrıştırıcı bunları güvenilir ayıramaz)
  · `where` koşulundaki kolonlar
  · dinamik SQL (`execute format(...)`)
Yani "hepsi temiz" DEMEZ, "yazma yolundaki her kolon gerçek" der.
Yazma yolu, canlıda veri bozan yol olduğu için önce o kapatıldı.

TAVAN 0.
"""
import glob
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(os.path.dirname(KOK), "sql")
SEMA = os.path.join(KOK, "sema_kolonlari.txt")
TAVAN = 0

# `update`/`insert` hedefi olabilen ama TABLO OLMAYAN adlar.
MUAF_TABLO = {"pg_temp", "temp"}


def sema_yukle():
    if not os.path.exists(SEMA):
        return None
    d = {}
    for satir in open(SEMA, encoding="utf-8"):
        satir = satir.strip()
        if not satir or "|" not in satir:
            continue
        t, k = satir.split("|", 1)
        d.setdefault(t, set()).add(k)

    # ══════════════════════════════════════════════════════════════
    # 🔴 30 AĞUSTOS · 7. TUR — ŞEMA HARİTASI CANLIDAN ALINIYOR,
    # AMA HENÜZ ÇALIŞMAMIŞ MIGRATION'LAR DA ŞEMANIN PARÇASI.
    #
    # `277_baglanti_kaldir.sql` önce `chat_channels.active` kolonunu
    # EKLİYOR, sonra ona yazıyor. Denetim yalnız canlı şemaya baktığı
    # için "bu kolon yok" dedi — yani DOĞRU yazılmış bir migration'ı
    # kusur olarak raporladı.
    #
    # Bu tür bir yanlış alarm, denetimin en pahalı hâlidir: her yeni
    # kolonda kırmızı yanan bir kapı, bir süre sonra "zaten yanar"
    # diye görmezden gelinir — ve o gün gerçek bir kusuru da kaçırır.
    #
    # 🆕 SINIF: "BİR DENETİM DOĞRU İŞİ CEZALANDIRIYORSA, BİR SÜRE
    # SONRA HİÇBİR İŞİ DENETLEMEZ — YANLIŞ ALARM, KAÇIRILAN HATADAN
    # DAHA HIZLI ÖLDÜRÜR."
    #
    # Kaynak yine ÜRÜN: migration dosyalarındaki `add column` satırları
    # taranıyor, elle bir istisna listesi tutulmuyor.
    # ══════════════════════════════════════════════════════════════
    eklenen = 0
    for f in sorted(os.listdir(SQL)):
        if not f.endswith(".sql") or f.startswith("ETKIN"):
            continue
        g = open(os.path.join(SQL, f), encoding="utf-8", errors="replace").read()
        for m in re.finditer(
                r"alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?(\w+)\s+"
                r"add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)", g, re.I):
            t, k = m.group(1), m.group(2)
            if k not in d.get(t, set()):
                d.setdefault(t, set()).add(k)
                eklenen += 1

        # ══════════════════════════════════════════════════════════════
        # 🔴 19 EYLÜL · `create table` DA OKUNUYOR — KÖR NOKTA KAPANDI.
        #
        # Yukarıdaki tarama yalnız `add column` görüyordu. 298
        # `supurge_damgasi` tablosunu `create table if not exists` ile
        # AÇTI; 299 ona `add column` ile kolon EKLEDİ. Sonuç absürttü:
        # denetim tablonun SONRADAN eklenen kolonlarını biliyor ama
        # DOĞDUĞU ANDAKİ kolonlarını (`ad`, `son_kosum`) bilmiyordu —
        # ve kendi migration'ımı 8 kez "bu kolon yok" diye raporladı.
        #
        # 🆕 SINIF: "BİR ŞEMA HARİTASINI `alter` SATIRLARINDAN
        # KURUYORSAN, TABLONUN DOĞDUĞU SATIRI DA OKU — YOKSA HARİTA
        # YALNIZ SONRADAN EKLENENLERİ BİLİR."
        # ══════════════════════════════════════════════════════════════
        for m in re.finditer(
                r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)\s*\((.*?)\n\s*\)\s*;",
                g, re.I | re.S):
            t, govde = m.group(1), m.group(2)
            derinlik = 0
            for ham in govde.split("\n"):
                s = re.sub(r"--.*$", "", ham).strip()
                if not s:
                    continue
                # Kısıt satırları kolon değildir.
                if re.match(r"(primary|foreign|unique|check|constraint|exclude)\b", s, re.I):
                    derinlik += s.count("(") - s.count(")")
                    continue
                # Çok satırlı bir ifadenin ortasındaysak (parantez açık) atla.
                if derinlik > 0:
                    derinlik += s.count("(") - s.count(")")
                    continue
                km = re.match(r"(\w+)\s+\w", s)
                if km:
                    k = km.group(1)
                    if k not in d.get(t, set()):
                        d.setdefault(t, set()).add(k)
                        eklenen += 1
                derinlik += s.count("(") - s.count(")")
    if eklenen:
        print("  ⓘ %d kolon migration dosyalarından okundu (canlıda henüz yok)." % eklenen)
    return d


def kod(g):
    """Yorumları BOŞLUKLA değiştir — satır numaraları korunsun."""
    g = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), g, flags=re.S)
    return "\n".join(re.sub(r"--.*$", "", s) for s in g.split("\n"))


def update_kolonlari(govde):
    """
    `update t set a = 1, b = 2 where ...` → [(t, a), (t, b)]

    🔴 `set` listesinin sonunu bulmak naif olamaz: değerin içinde
    `where` geçen bir alt sorgu olabilir. Parantez derinliği sayılıyor;
    derinlik 0'da gelen `where`/`from`/`returning` listeyi bitirir.
    """
    for m in re.finditer(r"\bupdate\s+(?:only\s+)?(?:public\.)?(\w+)\s+set\b",
                         govde, re.I):
        tablo = m.group(1).lower()
        i, d = m.end(), 0
        while i < len(govde):
            c = govde[i]
            if c == "(":
                d += 1
            elif c == ")":
                if d == 0:
                    break
                d -= 1
            elif d == 0 and re.match(r"(?i)\b(where|from|returning)\b", govde[i:i + 10]):
                break
            elif d == 0 and c == ";":
                break
            i += 1
        liste = govde[m.end():i]
        # `set` listesinde yalnız EN DIŞ virgüllerdeki soldaki adlar kolon
        d, parca, son = 0, [], 0
        for k, c in enumerate(liste):
            if c == "(":
                d += 1
            elif c == ")":
                d -= 1
            elif c == "," and d == 0:
                parca.append(liste[son:k])
                son = k + 1
        parca.append(liste[son:])
        for p in parca:
            mm = re.match(r"\s*(\w+)\s*=", p)
            if mm:
                yield tablo, mm.group(1).lower(), govde[:m.start()].count("\n") + 1


def insert_kolonlari(govde):
    for m in re.finditer(r"\binsert\s+into\s+(?:public\.)?(\w+)\s*\(([^;]*?)\)\s*"
                         r"(?:values|select|overriding|default)", govde, re.I | re.S):
        tablo = m.group(1).lower()
        ic = m.group(2)
        if "(" in ic:            # iç içe parantez → güvenilir ayıramayız
            continue
        for k in ic.split(","):
            k = k.strip().strip('"').lower()
            if re.fullmatch(r"\w+", k or ""):
                yield tablo, k, govde[:m.start()].count("\n") + 1


def main():
    if "--sema-yaz" in sys.argv:
        print("Şemayı yazmak için:")
        print('  python pg_sor.py -c "copy (select table_name || chr(124) || column_name '
              "from information_schema.columns where table_schema='public') to stdout\" "
              "> sema_kolonlari.txt")
        return 0

    sema = sema_yukle()
    print("=" * 76)
    print("KOLON DENETİMİ — fonksiyon gövdelerinde olmayan kolona yazılıyor mu?")
    print("=" * 76)
    if not sema:
        print("  ⚠ %s yok — şema haritası olmadan bu denetim ÖLÇEMEZ." % os.path.basename(SEMA))
        print("    `python pg_run.py --keep` sonra `python kolon_check.py --sema-yaz`")
        print("    Ölçemediğini söylemek, ölçmüş gibi yapmaktan iyidir.")
        return 0

    kotu = []
    bakilan = 0
    for p in sorted(glob.glob(os.path.join(SQL, "*.sql"))):
        ad = os.path.basename(p)
        if ad == "ETKIN_TANIMLAR.sql":
            continue          # üretilmiş döküm, kaynak değil
        g = kod(open(p, encoding="utf-8").read())
        for uret in (update_kolonlari, insert_kolonlari):
            for tablo, kol, satir in uret(g):
                if tablo in MUAF_TABLO or tablo not in sema:
                    continue      # tablo şemada yok → başka denetimin işi
                bakilan += 1
                if kol not in sema[tablo]:
                    kotu.append((ad, satir, tablo, kol))

    print("  incelenen yazma kolonu : %d" % bakilan)
    print("  ŞEMADA OLMAYAN         : %d  (tavan %d)" % (len(kotu), TAVAN))
    for ad, satir, tablo, kol in kotu:
        print("    ✗ %s:%d  %s.%s — bu kolon yok" % (ad, satir, tablo, kol))
        yakin = [k for k in sema[tablo] if k[:4] == kol[:4]]
        if yakin:
            print("        benzer kolonlar: %s" % " · ".join(sorted(yakin)[:5]))
    print()
    if len(kotu) > TAVAN:
        print("🔴 Bu satırlar CANLIDA, o kod yolu ilk çalıştığında patlar.")
        print("   PL/pgSQL ifadeyi ancak çalıştırınca çözümler; harness")
        print("   çalışmayan dalı hiç görmez.")
        return 1
    print("✓ Yazma yolundaki her kolon şemada var.")
    print("  ⚠ Bu denetim `select`/`where` kolonlarını ve dinamik SQL'i ÖLÇMEZ.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
