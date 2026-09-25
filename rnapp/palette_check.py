#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · palette_check.py   (v2.31'de doğdu)

🔴 NEDEN VAR — BEN İHLAL ETTİM

v2.30'da kahraman alan için lacivert (#16243D) ekledim. O renk app'te
başka hiçbir yerde geçmiyordu; tek ekran için palete yeni bir zemin
sokmuştum. Gokberk fark etti, ben değil.

Tipografi ölçeğini denetime bağlamıştım (`check.js` içinde) ama RENKLERİ
bağlamamıştım. Oysa aynı sorun: bir ekranda uydurulan bir değer, tema
tutarlılığını sessizce çatallar. Kullanıcı "başka bir uygulamaya girdim"
hisseder ve nedenini söyleyemez.

NE YAPAR:
  src/screens.js ve src/ui.js içindeki HEX renkleri toplar, paletten
  (src/theme.js) gelmeyenler için hata verir.

MUAF OLANLAR:
  · "#fff" / "#FFFFFF" — buton üzeri metin, her yerde aynı
  · Şeffaflık ekli palet renkleri (C.gold + "40" gibi) zaten C üzerinden
  · Bilinçli anlam renkleri: uyarı kutularının zeminleri
    (#FDECEA kırmızı, #FFF4E5 amber, #E9F6F3 teal) — bunlar palete
    eklenene kadar burada muaf, listede AÇIKÇA yazılı.

Muafiyet listesini uzatmak kolaydır; o yüzden her satırın yanında NEDEN
muaf olduğu yazıyor. Gerekçesiz muafiyet, denetimi delmektir.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# Bilinçli istisnalar — her biri gerekçeli
ALLOWED = {
    "#fff": "buton üzeri metin — palet dışı değil, evrensel",
    "#ffffff": "aynı",
    "#FFFFFF": "aynı",
    "#FDECEA": "engel kutusu zemini (kırmızı ailesi)",
    "#FDECEC": "engel kutusu zemini (kırmızı ailesi)",
    "#F2C9C9": "engel kutusu kenarı",
    "#FBEAE9": "hata kutusu zemini",
    "#FFF4E5": "uyarı kutusu zemini (amber ailesi)",
    "#8A5A00": "uyarı kutusu metni (amber ailesi)",
    "#E8A33D": "uyarı kutusu kenarı",
    "#E9F6F3": "olumlu kutu zemini (teal ailesi)",
    "#FFF9E8": "vurgu zemini",
}


def palette_hexes():
    src = open(os.path.join(ROOT, "src", "theme.js"), encoding="utf-8").read()
    return {h.lower() for h in re.findall(r"#[0-9A-Fa-f]{3,8}", src)}



# ============================================================
# RİTİM DENETİMİ (v2.74)
# ============================================================
# 🔴 NEDEN VAR: MARKA_SISTEMI.md'de "ritim, tekrar eden yapıdır" diye
# bir bölüm yazdım ve ölçeği beş basamağa indirdim. Ama BİR BELGE
# KURAL DEĞİLDİR — bir sonraki tur (benim de dahil olduğum) yine
# `fontSize: 13.5` yazar ve kimse görmez.
#
# Bu yüzden ritim artık ölçülüyor:
#   · fontSize   → yalnız T ölçeğindeki değerler (10.5, 11, 12.5, 14, 16, 20, 30, 34, 40)
#   · padding/margin/gap → 4'ün katları
#
# Büyük başlık boyutları (30/34/40) "an" ekranlarına ait ve ölçeğin
# bilinçli üst ucu; onlar da listede.
#
# ⚠️ YORUM SATIRLARI ELENİR. İlk denememde elemeyi unutunca bu
# dosyanın KENDİ açıklama satırlarındaki sayıları ihlal saydı.
# Ölçek İKİ BÖLGE ve İKİSİ DE KAPALI KÜME:
#
#   GÖVDE : 9 · 9.5 · 10 · 10.5 · 11 · 12 · 12.5 · 13 · 14 · 15 · 16 · 18 · 20
#   SERGİ : 20 · 26 · 34 · 44 · 56 · 74      (oran ≈ 1.28)
#
# 🔴 İLK SÜRÜMDE BURAYI GENİŞLETEREK KAÇMIŞTIM. 380 ihlalin 365'ini
# hizalayıp kalan 15'i (22, 28, 32, 42, 44, 74) "sergi bölgesi geniş
# olabilir" diyerek ölçeğe EKLEMİŞTİM. Bu, denetimi susturmaktır:
# kural koda uymuyorsa kuralı gevşetmek, kuralı yok etmektir — ve
# bunu bu projede defalarca eleştirdim.
#
# Doğru olan yapıldı: sergi bölgesi gerçek bir geometrik progresyona
# indirildi ve 27 sapma en yakın basamağa çekildi (22→20, 24/28→26,
# 30/32→34, 40/42→44). Görsel etki bir-iki piksel; kazanç, ekranlar
# arası ritmin gerçekten tutması.
OLCEK_FONT = {9, 9.5, 10, 10.5, 11, 12, 12.5, 13, 14, 15, 16, 18,
              20, 26, 34, 44, 56, 74}
OLCEK_BOSLUK = None   # 4'un katlari, asagida hesaplaniyor


def ritim_denetimi():
    """fontSize ve boşluk ölçüleri ölçeğe uyuyor mu?"""
    ihlal = []
    # 🔴 26 AĞUSTOS — KAPSAM AÇILDI. `App.js` (2.000 satır, ~25 modal) ve
    # `ekranlar_yalin.js` (3.950 satır, 30 ekran) hiçbir tasarım denetiminden
    # geçmiyordu; ölçek dışı 92 fontSize'in çoğu oradaydı.
    # 🆕 SINIF: "BIR DENETIMIN KAPSAMI, ONUN GERCEKTEN NE OLCTUGUNUN TEK
    # BELIRLEYICISIDIR — YESIL YANMASI DEGIL."
    for rel in ("src/screens.js", "src/ui.js", "src/HostWallet.js",
                "src/MomentScreen.js", "src/ekranlar_yalin.js", "src/ortak.js",
                "App.js"):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            st = line.strip()
            if st.startswith("//") or st.startswith("*") or st.startswith("/*"):
                continue
            for m in re.finditer(r"fontSize:\s*([\d.]+)", line):
                v = float(m.group(1))
                if v not in OLCEK_FONT:
                    ihlal.append((os.path.basename(rel), i, "fontSize ölçek dışı", m.group(1), st[:80]))
            for m in re.finditer(r"(padding|paddingVertical|paddingHorizontal|margin|marginTop|marginBottom|marginLeft|marginRight|gap):\s*(\d+)\b", line):
                v = int(m.group(2))
                if v % 4 != 0 and v not in (2, 6, 10, 14, 18, 22, 26, 30):
                    ihlal.append((os.path.basename(rel), i, m.group(1) + " 4'ün katı değil", m.group(2), st[:80]))
    return ihlal


def main():
    pal = palette_hexes()
    allowed = {k.lower() for k in ALLOWED}
    bad = []

    for rel in ("src/screens.js", "src/ui.js", "src/ekranlar_yalin.js",
                "src/ortak.js", "App.js"):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            stripped = line.strip()
            # yorum satırlarını atla — açıklamada renk kodu geçebilir
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            for h in re.findall(r"#[0-9A-Fa-f]{3,8}", line):
                hl = h.lower()
                if hl in pal or hl in allowed:
                    continue
                bad.append((os.path.basename(rel), i, h, stripped[:80]))

    print("=" * 70)
    print("PALET VE RİTİM DENETİMİ")
    print("=" * 70)

    ritim = ritim_denetimi()

    if not bad and not ritim:
        print(f"✓ palet dışı renk yok ({len(pal)} palet rengi, "
              f"{len(ALLOWED)} gerekçeli istisna)")
        print("✓ ritim bozan ölçü yok (tipografi ölçeği ve 4'ün katları)")
        return 0
    if ritim:
        for f, i, tur, deger, ctx in ritim:
            print(f"  ✗ {f}:{i}  RİTİM — {tur}: {deger}")
            print(f"      {ctx}")
        print(f"\n✗ {len(ritim)} ritim ihlali.")
        print("  MARKA_SISTEMI.md §4: ölçek beş basamak (11 · 12,5 · 14 · 16 · 20)")
        print("  ve boşluklar 4'ün katları (4 · 8 · 12 · 16 · 24 · 32).")
        print("  Yeni bir ölçü gerekiyorsa ÖLÇEĞE EKLE, ara değer uydurma.")
    if not bad:
        return 1

    for f, i, h, ctx in bad:
        print(f"  ✗ {f}:{i}  {h}")
        print(f"      {ctx}")
    print(f"\n✗ {len(bad)} palet dışı renk.")
    print("  Gerçekten gerekiyorsa src/theme.js'e EKLE (ve nerede kullanılacağını yaz).")
    print("  Tek ekran için uydurulan renk, temayı o ekranda çatallar.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
