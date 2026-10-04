#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
durum_kapsam_check.py — EKRANIN DEĞİL, DURUMUNUN KAPSAMI.

🔴 NEDEN VAR — BU BOŞLUĞU KENDİM YAZDIM, SONRA KAPATTIM.

`ekran_kapsam_check.py` "her ekran görüldü mü" diye soruyor ve 36/36
yeşil. Ama bir ekranın çekilmiş olması, o ekranın GÖRÜLDÜĞÜ anlamına
gelmiyor: Keşfet kartının eylem alanının BEŞ hâli var ve sahnelerde
yalnız ikisi yaşanıyordu.

    engelli                  → "Başvuru kapalı · Neden?"      ✓ çekiliyordu
    uygun                    → "İstek gönder"                 ✓ çekiliyordu
    telefon doğrulanmamış    → "Telefonu doğrula"             ✗ hiç görülmedi
    seyahati yok             → "Seyahat ekle"                 ✗ hiç görülmedi
    kendi ilanı              → düğme yok, "Senin ilanın"      ✗ hiç görülmedi

Üçü de kullanıcının GERÇEKTEN karşılaştığı hâller — hatta yeni bir
kullanıcının ilk gördüğü hâl "telefonu doğrula". Yani en çok bakılan
durum, hiç bakmadığımız durumdu.

Çözüm ekranı taklit etmek değil, o durumu YAŞAYAN kullanıcıyı tohuma
eklemekti (`sahne_seed.sql`: Yeni Üye · Hazır Üye). Bu nöbetçi de
ekranda o cümlelerin GERÇEKTEN çizildiğini sahne çıktısından okuyor —
kaynaktan değil, `metin` alanından.

🆕 SINIF: "BİR EKRANI ÇEKMEK O EKRANI GÖRMEK DEĞİLDİR — EKRAN BİR
DEĞİL, DURUMLARI KADAR ÇOKTUR; VE EN ÇOK GÖRÜLEN DURUM ÇOĞU ZAMAN EN AZ
BAKILANDIR."

NE ÖLÇÜYOR: `web_sahne/out/*.json` içindeki `metin` (ekranın gerçek
innerText'i). Aranan her durumun imzası en az bir sahnede geçmeli.

⚠️ LİSTEDE OLMAYAN İKİ DURUM VE GEREKÇELERİ — ölçtüm, uyduramadım:

  · "Keşfet · kendi ilanın"  — `discover_availabilities` kullanıcının
    KENDİ ilanını listeden zaten çıkarıyor (ölçüldü: Selin Keşfet'i
    açınca 4 host görüyor, kendisi yok). Koddaki `mine` dalı savunma
    amaçlı; ekranda üretilemiyor.

  · "Keşfet · başvuru kapalı" — iki yol denendi, ikisi de elendi:
    `min_trust` eşiği ilanı listeden düşürüyor (engelli göstermiyor);
    kural motorunun gerçek "misafir kabul edilmiyor" hükmüyle ilan
    açmak ise `availabilities` tetikleyicisini patlattı — ve orada
    GERÇEK BİR HATA bulundu (sql/288: `profiles.trust_score` diye bir
    kolon yok). Tetikleyici düzeldi; bu durum bir sonraki turda
    çekilecek.

🆕 SINIF: "BİR DURUMU ÜRETEMEDİĞİNDE UYDURMA — ÜRETEMEME SEBEBİNİ YAZ;
O SEBEP ÇOĞU ZAMAN ÜRÜNÜN KENDİSİ HAKKINDA BİR BULGUDUR."
"""
import glob
import json
import os
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(KOK, "web_sahne", "out")

# durum adı → ekranda GÖRÜNMESİ gereken metin (i18n'deki tr karşılığı)
DURUMLAR = [
    ("Keşfet · uygun",                 "İstek gönder"),
    ("Keşfet · telefon doğrulanmamış", "Telefonu doğrula"),
    ("Keşfet · seyahati yok",          "Seyahat Ekle"),
    # 🔴 18 EYLÜL (Gökberk md.12) — ARANAN METİN DEĞİŞTİ, KAPI DEĞİL.
    # Düğmenin etiketi "Seyahati Kaydet →" idi ama düğme YENİ seyahat
    # açıyordu; `addTrip` ("Seyahat Ekle") ile değiştirildi. Kapı aynı
    # durumu arıyor, yalnız imzası güncellendi. (İmzayı güncellemeyip
    # kapıyı kırmızı bırakmak da, kapıyı silmek de yanlış olurdu:
    # birincisi gürültü, ikincisi kapsam kaybı.)
    ("İlk gün · seyahat formu",        "Seyahat Ekle"),
    ("Boş dünya · Bildirimler",        "Sessizlik iyi haber"),
    # 🔴 18 EYLÜL (md.10 · md.11) — YENİ DURUM: KALDIRILMIŞ İLAN.
    # Gökberk "ilanı kaldır tıklamama rağmen kaldırmıyor" dedi; ilan
    # aslında pasife düşüyordu ve o hâl hiçbir sahnede yoktu. Pasif
    # ilan artık `sahne_seed.sql`de ve satırında "Yeniden yayınla"
    # düğmesi duruyor (SQL 295). Bu satır o hâlin bir daha sessizce
    # kaybolmamasını sağlıyor.
    ("İlanlarım · kaldırılmış ilan",   "Yeniden yayınla"),
]


def sahne_metinleri():
    d = {}
    for p in sorted(glob.glob(os.path.join(OUT, "*.json"))):
        try:
            j = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(j, dict):   # akis_e2e.json (sonuç listesi) sahne değil
            continue
        d[os.path.basename(p)[:-5]] = "\n".join(j.get("metin", []))
    return d


def main():
    print("=" * 74)
    print("DURUM KAPSAMI — ekranın her hâli en az bir sahnede görüldü mü?")
    print("=" * 74)
    metin = sahne_metinleri()
    if not metin:
        print("  ✗ Sahne çıktısı yok. Önce `python3 web_sahne/cek.py`.")
        return 1
    print("  taranan sahne: %d\n" % len(metin))

    eksik = []
    for ad, imza in DURUMLAR:
        nerede = [s for s, m in metin.items() if imza in m]
        if nerede:
            print("  ✓ %-32s %s" % (ad, ", ".join(sorted(nerede))[:44]))
        else:
            print("  ✗ %-32s HİÇBİR SAHNEDE GÖRÜNMÜYOR  (aranan: %r)" % (ad, imza))
            eksik.append(ad)

    if eksik:
        print("\n🔴 Bu durumlar yalnız mount testinde ölçülüyor — yani")
        print("   'çöküyor mu' biliniyor, 'doğru görünüyor mu' bilinmiyor.")
        print("   Çözüm: o durumu yaşayan bir kullanıcıyı tohuma ekle.")
        return 1
    print("\n✓ Aranan durumların hepsi gerçek veriyle çekilmiş bir sahnede.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
