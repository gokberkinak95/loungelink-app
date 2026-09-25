#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ekran_kapsam_check.py — HER EKRAN GÖRÜLDÜ MÜ?

🔴 NEDEN VAR — 12 EYLÜL, GÖKBERK SORDU: "attığın son tasarımı birebir,
%100 ve eksiksiz şekilde uyguladın di mi?"

Cevap veremedim, çünkü ÖLÇMEMİŞTİM. Elle saydım: 72 dışa aktarılmış
bileşenin 23'ünün sahnesi vardı. Yani ekranların üçte ikisine premium
turu boyunca hiç BAKMADIM — jetonlar üzerinden otomatik değiştiler ve
"herhalde doğrudur" dedim.

"Herhalde doğrudur" bir ölçüm değildir. Bu dosya o cümleyi bir sayıya
çeviriyor ve sayı tavanın üstündeyse denetimi kırmızı yakıyor.

İKİ AYRI KAPSAM, İKİ AYRI SORU:
  1. MOUNT  — "bu ekran boş veriyle çöküyor mu, taşıyor mu, iki temada
     da çiziliyor mu?"  (`render_check/mount_test.js`)
     Bu kapsam ZORUNLU: her ekran burada olmalı.
  2. SAHNE  — "bu ekran GERÇEK veriyle, gerçek RLS ile nasıl görünüyor?"
     (`web_sahne/cek.py`)  Bu kapsam ANA AKIŞ için zorunlu: kullanıcının
     kaydolduktan sonra göreceği sekmeler ve onların alt sayfaları.

🆕 SINIF: "BİR DEĞİŞİKLİĞİ 'HER YERE UYGULADIM' DİYEBİLMEK İÇİN 'HER
YER'İN KAÇ TANE OLDUĞUNU BİLMEK GEREKİR — KAPSAMI ÖLÇMEYEN HER İDDİA
BİR TAHMİNDİR."
"""
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
KAYNAK = ["src/screens.js", "src/ekranlar_ana.js", "src/ekranlar_yalin.js", "App.js"]

TAVAN_MOUNT = 0
TAVAN_SAHNE = 0

# ── EKRAN SAYILMAYANLAR — her biri gerekçeli ────────────────────────
# Bir adı buraya koymak onu denetimden çıkarmaktır; o yüzden gerekçesiz
# satır yok. "Şimdilik" diye eklenen her istisna kalıcı olur.
MUAF = {
    "AppInner": "yönlendirici — kendi çizmiyor, hangi ekranın çizileceğine karar veriyor",
    "Main":     "sekme kabuğu — içeriği Home/Discovery/Meet/Trips/Profile çiziyor",
    "Auth":     "yönlendirici — Splash/Onboarding/Giriş/Kayıt arasında seçim yapıyor",
    "Row":      "liste satırı bileşeni — `Hdr` içermiyor, eşleştirici yanlış saydı",
    "SwitchCell": "ayar satırı bileşeni — aynı sebep",
}

# ── GERÇEK VERİYLE SAHNESİ ZORUNLU OLANLAR ──────────────────────────
# Kullanıcının kaydolduktan sonra parmağıyla ulaşabildiği her yüzey.
# Form/alt sayfa olanlar mount kapsamında kalıyor: oraya veri girmeden
# gerçek bir sahne üretmek testi değil kurguyu ölçer.
SAHNE_ZORUNLU = {
    "Splash", "Onboarding", "Home", "Discovery", "Meet", "Trips",
    "Profile", "Notifications", "Chat", "KuralKarari", "Settings",
    "Wallet", "Marketplace", "Degerlendirmeler", "Safety", "SessionHistory",
    "PublicProfile", "MyQuestions", "Plans", "Referral", "Campaigns",
    "HostApply", "TrustVisual", "EditProfile", "HostBroadcast",
    # 12 Eylül · gece — artık zorunlu: tohuma aktif oturum eklendi.
    "LiveStatus",
}
# ── SAHNESİ OLMAYAN AMA GEREKÇELİ ───────────────────────────────────
# (12 Eylül · gece itibarıyla BU LİSTE BOŞ.)
#
# Bir tur önce burada `LiveStatus` yazıyordu: "yalnız BAŞLAMIŞ bir
# oturumun sohbetinden açılıyor; tohum dünyasında aktif oturum yok."
# Gerekçe doğruydu ve o turda doğru karardı — sahte bir oturum uydurup
# çekmek ekranı değil kurguyu ölçerdi.
#
# Ama bir gerekçe İKİNCİ turda da duruyorsa artık gerekçe değil
# alışkanlıktır. Doğru çözüm ekranı sahtelemek değil, DÜNYAYA eksik
# durumu eklemekti: `sahne_seed.sql` artık Gökberk↔Deniz oturumunu
# `active` kuruyor (mesajlar zaten "Lounge girişindeyim" diyordu —
# veri, kendi hikâyesiyle çelişiyormuş).
#
# 🆕 SINIF: "ÖLÇEMEDİĞİN ŞEYİ ÖLÇÜYORMUŞ GİBİ YAPMAKTANSA ÖLÇMEDİĞİNİ
# YAZ — AMA YAZDIĞIN GEREKÇEYE BİR SON TARİH KOY: İKİNCİ TURDA HÂLÂ
# ORADAYSA, O BİR GEREKÇE DEĞİL BİR MAZERETTİR."


def ekranlar():
    """Tam sayfa çizen bileşenler: Sayfa / Hdr / FotoSahne / FotoBant kullananlar."""
    bulunan = {}
    for f in KAYNAK:
        s = open(os.path.join(KOK, f), encoding="utf-8").read()
        yerler = [(m.start(), m.group(1)) for m in
                  re.finditer(r"(?:export )?function ([A-Z][A-Za-z0-9]*)\s*\(", s)]
        for i, (poz, ad) in enumerate(yerler):
            son = yerler[i + 1][0] if i + 1 < len(yerler) else len(s)
            govde = s[poz:son]
            if any(x in govde for x in ("<Sayfa", "<Hdr", "<FotoSahne", "<FotoBant")):
                bulunan[ad] = f
    return bulunan


def mount_kapsami():
    """`S.Ad` (screens.js) ve `A.Ad` (App.js) — İKİ kaynak.
    İlk yazımda yalnız `S.` arıyordum ve App.js'teki beş ekran kapsam
    dışı sayılıyordu; oysa mount testine eklenmişlerdi. Yani nöbetçinin
    kendisi yanlış ölçüyordu — düzeltilmeseydi bir daha eklenmeyecek
    beş ekran için sonsuza kadar kırmızı yanardı ve bir süre sonra
    kimse ona bakmazdı."""
    s = open(os.path.join(KOK, "render_check", "mount_test.js"), encoding="utf-8").read()
    return set(re.findall(r'\b[SA]\.([A-Z][A-Za-z0-9]*)\s*,', s))


def sahne_kapsami():
    s = open(os.path.join(KOK, "web_sahne", "cek.py"), encoding="utf-8").read()
    # Sahne adları tasarım numarasıyla; hangi ekranı çektiği `# ekran:` notunda.
    return set(re.findall(r"#\s*ekran:\s*([A-Za-z0-9_ ,]+)", s)), \
        len(re.findall(r'^\s{4}"[0-9]', s, re.M))


def daralan_bant():
    """Fotoğraflı her başlık daralıyor mu?

    🔴 12 Eylül: altı fotoğraflı bandın yalnız üçü daralıyordu ve bunu
    Gökberk sekmeler arası gezerken fark etti — "tam olarak senin
    'farklı yerleşim' dediğin şey". Sayı burada tutuluyor ki bir
    sonraki fotoğraflı ekran eklendiğinde sessizce geride kalmasın."""
    foto = kay = 0
    for f in KAYNAK:
        s = open(os.path.join(KOK, f), encoding="utf-8").read()
        foto += len(re.findall(r"foto=\{", s))
        kay += len(re.findall(r"kaydir=\{", s))
    return foto, kay


def main():
    ek = ekranlar()
    gercek = {a: f for a, f in ek.items() if a not in MUAF}
    mnt = mount_kapsami()
    shn_ad, shn_say = sahne_kapsami()
    shn = set()
    for grup in shn_ad:
        for parca in grup.replace(" ", "").split(","):
            if parca:
                shn.add(parca)

    print("=" * 74)
    print("EKRAN KAPSAM DENETİMİ — her ekran görüldü mü?")
    print("=" * 74)
    print("  tam sayfa çizen bileşen : %d" % len(ek))
    print("  muaf (gerekçeli)        : %d" % len(MUAF))
    print("  DENETLENEN EKRAN        : %d" % len(gercek))
    print("  mount kapsamı           : %d" % len(mnt & set(gercek)))
    print("  çekilen sahne           : %d" % shn_say)
    print("  sahnesi olan ekran      : %d" % len(shn & set(gercek)))

    eksik_m = sorted(set(gercek) - mnt)
    eksik_s = sorted((SAHNE_ZORUNLU & set(gercek)) - shn)

    if eksik_m:
        print("\n  🔴 MOUNT KAPSAMI DIŞINDA (%d):" % len(eksik_m))
        for a in eksik_m:
            print("     %-24s %s" % (a, gercek[a]))
        print("     → render_check/mount_test.js içindeki CASES'e ekle.")
    else:
        print("\n  ✓ her ekran mount testinde — boş veriyle çökme ve taşma ölçülüyor")

    if eksik_s:
        print("\n  🔴 GERÇEK SAHNESİ OLMAYAN ANA AKIŞ EKRANI (%d):" % len(eksik_s))
        for a in eksik_s:
            print("     %-24s %s" % (a, gercek[a]))
        print("     → web_sahne/cek.py SAHNELER'e ekle ve satırına `# ekran: <Ad>` yaz.")
    else:
        print("  ✓ ana akıştaki her ekranın gerçek veriyle çekilmiş sahnesi var")

    foto, kay = daralan_bant()
    print("\n  fotoğraflı başlık        : %d" % foto)
    print("  daralan bant bağlı       : %d" % kay)
    if foto != kay:
        print("  🔴 %d fotoğraflı başlık daralmıyor — sekmeler arası yerleşim tutarsız." % (foto - kay))
    else:
        print("  ✓ fotoğraflı başlıkların hepsi kaydırınca daralıyor")

    kotu = (len(eksik_m) > TAVAN_MOUNT) + (len(eksik_s) > TAVAN_SAHNE) + (foto != kay)
    if kotu:
        print("\n🔴 Kapsam eksik. 'Her yere uyguladım' demek için 'her yer'in")
        print("   kaç tane olduğunu bilmek gerekir.")
        return 1
    print("\n✓ Kapsam tam — görülmemiş ekran yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
