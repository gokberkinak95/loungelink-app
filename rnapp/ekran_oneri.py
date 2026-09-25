#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ekran_oneri.py — 5 EYLÜL ÖNERİ EKRANLARI (onay bekliyor).

Gökberk'in cihaz bulguları (2 · 4 · 5 · 7) için tasarım önerileri. Onaylanan
`ekranlar_render/` setine DOKUNMAZ; çıktı `ekranlar_oneri/`. Onaylanınca
ilgili fonksiyonlar `ekran_uret.py`ye taşınır (09 · 12 · 12b).

  09b_profil     — kimlik + istatistik BANDIN İÇİNDE (ana sayfa cüzdan
                   şeridi gibi: OTURUM · YILDIZ · LOUNGEPUAN · KREDİ);
                   eksik profil tek kompakt kartta bandın hemen altında.
  12b_ana_host   — host ana sayfası misafirle AYNI iskelet: selam + isim +
                   cüzdan şeridi → Akışım (4 kutu) → BU AY (katlanır) →
                   çipler → ilanlar.
  12c_ilanlarim  — düğüm kısaldı ("İLAN VE İSTEKLERİNİ YÖNET"); Cüzdan /
                   Kaçırılan / Mertebe üç kart yerine tek satır (3 kutu,
                   dokununca açılır); "İLANLARIM · 26 · [+ İlan Ekle]".
"""
import os, sys
KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from PIL import Image  # noqa: E402
from mockup import (buyuk, SERIF_SEMI, BOLD, K, KENAR, MONO_MED, MONO_SEMI, REG, SEMI,  # noqa: E402
                    Ekran, f, rgb, sozluk)
import ekran_uret as eu  # noqa: E402

CIKTI = os.path.join(KOK, "ekranlar_oneri")
T = sozluk("tr")
t = eu.t


def serit(e, cy, hucreler):
    """Cüzdan şeridi (62 yüksek · %3.5 cam). 5 Eylül — hücreler ŞERİDİN
    TAMAMINA eşit dağılır (Gökberk: "sola dayalı, sağda çok boşluk")."""
    cg = e.g - 2 * KENAR
    e.im.alpha_composite(
        e.yuvarlak((cg, 62 * K), 14, (255, 255, 255, 9),
                   rgb(e.P.get("line", "#333")) + (255,)), (KENAR, cy))
    nf = f(MONO_SEMI, 19)
    lf = f(SEMI, 9.5)
    n = len(hucreler)
    hg = cg / n
    for i, (deger, etiket) in enumerate(hucreler):
        et = buyuk(etiket)
        cx = KENAR + i * hg
        if i:
            e.im.alpha_composite(Image.new("RGBA", (K, 26 * K), (232, 214, 182, 44)),
                                 (int(cx), int(cy + 18 * K)))
        w = e.genislik(deger, nf)
        e.metin((cx + (hg - w) / 2, cy + 12 * K), deger, nf, e.P["gold"])
        w = e.genislik(et, lf, aralik=1.3)
        e.metin((cx + (hg - w) / 2, cy + 40 * K), et, lf, e.P["dim"], aralik=1.3,
                enfazla=hg - 6 * K, kaynak="şerit etiketi")
    return cy + 62 * K


def sy_sira(e, y, kutular):
    """Akışım 4 kutu (ana sayfa ile aynı)."""
    sg = (e.g - 2 * KENAR - 3 * 9 * K) / 4
    for i, (n, lb) in enumerate(kutular):
        bx = KENAR + i * (sg + 9 * K)
        dolu = n != "0"
        e.im.alpha_composite(
            e.yuvarlak((int(sg), 62 * K), 12, rgb(e.P["surface"]) + (255,),
                       rgb(e.P["gold"] if dolu else e.P.get("line", "#333")) + (90 if dolu else 255,)),
            (int(bx), int(y)))
        nf = f(MONO_MED, 20)
        w = e.genislik(n, nf)
        e.metin((bx + (sg - w) / 2, y + 13 * K), n, nf, e.P["gold"] if dolu else e.P["dim"])
        lf = e.sigdir(buyuk(lb), SEMI, 9, sg - 12 * K, alt=6)
        w = e.genislik(buyuk(lb), lf, aralik=1.1)
        e.metin((bx + (sg - w) / 2, y + 42 * K), buyuk(lb), lf,
                e.P["mutedAA"] if dolu else e.P["dim"], aralik=1.1,
                enfazla=sg - 8 * K, kaynak="sy-sira etiketi")
    return y + 62 * K


def satir(e, x, y0, g, ikon_ad, etiket):
    x, y0, g = e.kart(46 * K, y=y0, r=12)
    e.ikon(x + 14 * K, y0 + 14 * K, ikon_ad, 18, e.P["mutedAA"])
    e.metin((x + 44 * K, y0 + 14 * K), etiket, f(SEMI, 14), e.P["ink"])
    e.ikon(x + g - 26 * K, y0 + 14 * K, "sag", 16, e.P["dim"])
    return y0 + 46 * K + 8 * K


# ── 09b · PROFİL — kimlik ve istatistik bandın içinde ──────────────────
def profil_v2():
    e = Ekran()
    e.doku()
    # bant: marka · dişli · düğüm · başlık · [avatar 60 + isim + meslek + çip] · şerit 62
    # 5 Eylül — düğüm yok (isim zaten avatarın yanında); şehir mesleğin yanında
    YB = e.bant(t("ppProfile"), None, sag_ikon="ayarlar",
                ek_yuk=(14 + 60 + 16 + 62) * K)
    y = 20 * K + 38 * K + 34 * K + 42 * K + 14 * K                   # başlığın altı
    av = 60 * K
    e.avatar(KENAR, y, "S", boy=60)
    e.metin((KENAR + av + 14 * K, y + 2 * K), "Selin B.", f(BOLD, 18), "#FFFDF9")
    e.metin((KENAR + av + 14 * K, y + 26 * K), "Ürün Yönetimi · İstanbul", f(REG, 12), e.P.get("meshAlt", "#B4A997"))
    e.cip(KENAR + av + 14 * K, y + 42 * K, "• Güvenilir Host · 88", ton="ok")
    y += av + 16 * K
    serit(e, y, (("9", t("statSessions")), ("4.9", t("ratingShort", "Yıldız")),
                 ("1.240", t("loungePointsLabel")), ("12", t("walletCredits", "kredi"))))
    y = max(YB, y + 62 * K + 22 * K) + 14 * K
    # eksik profil — TEK kompakt kart (yalnız eksik varsa)
    x, y0, g = e.kart(64 * K, y=y, vurgu=True)
    e.metin((x + 16 * K, y0 + 14 * K), "%17 · " + t("profileCompleteTitle", "Profilini tamamla"),
            f(BOLD, 13.5), e.P["ink"])
    e.metin((x + 16 * K, y0 + 36 * K), "5 eksik: fotoğraf, biyografi, uçuş programı",
            f(REG, 11.5), e.P["mutedAA"])
    e.ikon(x + g - 26 * K, y0 + 22 * K, "sag", 16, e.P["dim"])
    y = y0 + 64 * K + 14 * K
    for ik, et in (("yayin", t("bcTitle")), ("gecmis", t("histTitle")),
                   ("degerlendirme", t("ratingsTitle")), ("bildirim", t("notifTitle"))):
        y = satir(e, KENAR, y, e.g - 2 * KENAR, ik, et)
    y += 6 * K
    e.metin((KENAR, y), buyuk(t("menuGroupTrust")), f(BOLD, 9.5), e.P["goldText"], aralik=1.2)
    y += 20 * K
    for ik, et in (("guvenPuan", t("trustTitle")), ("guvenlik", t("safetyTitle"))):
        y = satir(e, KENAR, y, e.g - 2 * KENAR, ik, et)
    e.alt_bar(4)
    return e


# ── 12b · ANA SAYFA (host) — misafirle aynı iskelet ─────────────────────
def ana_host_v2():
    e = Ekran()
    e.doku()
    YB = e.bant(None, None, marka="LOUNGELINK", sag_ikon="profil",
                ek_yuk=(10 + 8 + 54 + 22) * K + 62 * K)
    # 5 Eylül — düğüm misafirdeki gibi selam; isim "Selin B." serif, yanında rozet çipi
    e.metin((KENAR, 92 * K), buyuk(t("greetDay", "İyi günler")), f(BOLD, 10.5), e.P["gold"], aralik=2.4)
    e.metin((KENAR, 106 * K), "Selin B.", f(SERIF_SEMI, 52), "#FFFDF9")
    _w = e.genislik("Selin B.", f(SERIF_SEMI, 52))
    e.cip(int(KENAR + _w + 12 * K), int(106 * K + 26 * K), "• Güvenilir Host", ton="ok")
    serit(e, 182 * K, (("6", t("walletCredits", "kredi")), ("1.240", t("marketTitle")),
                       ("88", t("trust", "Güven"))))
    y = max(182 * K + 62 * K + 20 * K, e.imlec)
    y = sy_sira(e, y, (("2", t("flowChats")), ("1", t("flowRequests")),
                       ("1", t("flowInvites")), ("0", t("flowQuestions")))) + 14 * K
    # BU AY — katlanır (kapalı hâli: tek satır + ▾)
    x, y0, g = e.kart(56 * K, y=y, zemin=e.P["goldBg"])
    e.metin((x + 16 * K, y0 + 12 * K), t("hostMonthTitle"), f(BOLD, 9.5), e.P["goldText"])
    e.metin((x + 16 * K, y0 + 28 * K), "3 misafir · +360 LoungePuan · kademeye 3 oturum",
            f(SEMI, 12.5), e.P["ink"], enfazla=g - 60 * K, kaynak="bu ay özet")
    e.ikon(x + g - 30 * K, y0 + 19 * K, "asagi", 18, e.P["goldText"])
    y = y0 + 56 * K + 14 * K
    cx = e.cip(KENAR, y, t("subTabListings"), secili=True)
    e.cip(cx, y, t("subTabTrips"))
    y += 42 * K
    for salon, saat, ton, rz in (("TAV Primeclass · IST", "14:20 – 16:40", "ok", t("badgeGuestFree")),
                                 ("Comfort Lounge · SAW", "09:00 – 11:30", "cost", t("badgeGuestPaid"))):
        if y + 130 * K > e.y - 90 * K:
            break
        x, y0, g = e.kart(130 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 18 * K), salon, f(BOLD, 14), e.P["ink"])
        e.metin((ix, y0 + 42 * K), saat, f(REG, 12), e.P["mutedAA"])
        e.cip(ix, y0 + 68 * K, rz, ton=ton)
        s = t("discTitle"); ft = f(SEMI, 11.5); w = e.genislik(s, ft)
        e.metin((x + g - 16 * K - w, y0 + 72 * K), s, ft, e.P["goldText"])
        y = y0 + 130 * K + 12 * K
    e.alt_bar(0)
    return e


# ── 12c · İLANLARIM — kısa düğüm, tek satır cüzdan/kaçırılan/mertebe ───
def ilanlarim_v2():
    e = Ekran()
    e.doku()
    # 5 Eylül — çipler bandın İÇİNDE (başlığın altında), gövdede değil
    YB = e.bant(t("subTabListings"), "İlan ve isteklerini yönet", ek_yuk=(12 + 26) * K)
    cy = 20 * K + 38 * K + 34 * K + 18 * K + 42 * K + 12 * K
    cx = e.cip(KENAR, int(cy), t("subTabTrips"))
    e.cip(cx, int(cy), t("subTabListings"), secili=True)
    y = e.imlec
    # üç kart → tek satır (Akışım kutularıyla aynı dil; dokununca ayrıntı açılır)
    sg = (e.g - 2 * KENAR - 2 * 9 * K) / 3
    for i, (n, lb, alt) in enumerate((("9", t("hwWallet", "CÜZDAN"), "2 hak · 117 gün"),
                                      ("1", t("hwMissed", "KAÇIRILAN"), "son 30 gün"),
                                      ("Ev Sahibi", t("hwRank", "MERTEBE"), "1 ağırlama"))):
        bx = KENAR + i * (sg + 9 * K)
        e.im.alpha_composite(
            e.yuvarlak((int(sg), 74 * K), 12, rgb(e.P["surface"]) + (255,),
                       rgb(e.P.get("line", "#333")) + (255,)), (int(bx), int(y)))
        nf = f(MONO_MED, 18) if n[0].isdigit() else f(BOLD, 13)
        w = e.genislik(n, nf)
        e.metin((bx + (sg - w) / 2, y + 12 * K), n, nf, e.P["gold"])
        lf = f(SEMI, 9); w = e.genislik(buyuk(lb), lf, aralik=1.1)
        e.metin((bx + (sg - w) / 2, y + 38 * K), buyuk(lb), lf, e.P["mutedAA"], aralik=1.1)
        af = f(REG, 10); w = e.genislik(alt, af)
        e.metin((bx + (sg - w) / 2, y + 54 * K), alt, af, e.P["dim"])
    y += 74 * K + 18 * K
    e.metin((KENAR, y + 8 * K), buyuk(t("subTabListings")) + " · 26", f(BOLD, 9.5), e.P["goldText"], aralik=1.2)
    # sağda küçük altın düğme "+ İlan Ekle"
    bw = 118 * K
    e.dugme(y - 6 * K, t("addAvail"), "gold", x=e.g - KENAR - bw, g=bw, yuk=36, ft=f(BOLD, 12.5))
    y += 44 * K
    for salon, tarih, ton, rz in (("IST · Primeclass", "5 Eylül · 10:00–16:00", "ok", t("live")),
                                  ("IST · Primeclass", "6 Eylül · 10:00–16:00", "ok", t("live"))):
        if y + 118 * K > e.y - 90 * K:
            break
        x, y0, g = e.kart(118 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 18 * K), salon, f(BOLD, 14), e.P["ink"])
        e.cip(int(x + g - 16 * K - e.genislik(rz, f(SEMI, 10.5)) - 24 * K), int(y0 + 14 * K), rz, ton=ton)
        e.metin((ix, y0 + 42 * K), tarih, f(REG, 12), e.P["mutedAA"])
        e.metin((ix, y0 + 66 * K), "TK1979 · 2 slot · 1 dolu", f(REG, 11.5), e.P["dim"])
        s = t("edit", "Düzenle"); ft = f(SEMI, 11.5); w = e.genislik(s, ft)
        e.metin((x + g - 16 * K - w, y0 + 90 * K), s, ft, e.P["goldText"])
        y = y0 + 118 * K + 12 * K
    e.alt_bar(2)
    return e


# ── 14b · SEYAHATLERİM (host görünümü) — çipler bandın içinde ─────────
def seyahatler_v2():
    e = Ekran()
    e.doku()
    YB = e.bant(t("tripsTitle"), t("tripsSub"), ek_yuk=(12 + 26) * K)
    cy = 20 * K + 38 * K + 34 * K + 18 * K + 42 * K + 12 * K
    cx = e.cip(KENAR, int(cy), t("subTabTrips"), secili=True)
    e.cip(cx, int(cy), t("subTabListings"))
    y = e.imlec
    for ap, tarih, es, ton in (("IST · Aktarma", "16 Ekim · 14:00 – 18:00",
                                t("tripMatchCta").replace("{n}", "6"), "ok"),
                               ("SAW · Varış", "24 Ekim · 09:00 – 11:00",
                                t("tripMatchNone"), "unknown")):
        x, y0, g = e.kart(146 * K, y=y)
        ix = x + 16 * K
        e.metin((ix, y0 + 18 * K), ap, f(BOLD, 15), e.P["ink"])
        e.metin((ix, y0 + 42 * K), tarih, f(REG, 12), e.P["mutedAA"])
        if ap.startswith("IST"):
            e.cip(int(x + g - 16 * K - e.genislik("2 kişi · 4 yaş", f(SEMI, 10.5)) - 22 * K),
                  int(y0 + 14 * K), "2 kişi · 4 yaş")
        eu.ayirac(e, ix, y0 + 72 * K, g - 32 * K)
        ft = e.sigdir(es, SEMI, 12, g - 32 * K)
        e.metin((ix, y0 + 88 * K), es, ft, e.R[ton])
        s2 = t("findHost"); ft2 = f(SEMI, 11.5); w = e.genislik(s2, ft2)
        e.metin((x + g - 16 * K - w, y0 + 114 * K), s2, ft2, e.P["goldText"])
        y = y0 + 146 * K + 12 * K
    y = e.dugme(y + 6 * K, t("avSaveTrip"), "gold", yuk=52)
    ft = e.sigdir(t("tripsEmpty"), REG, 11.5, e.g - 2 * KENAR)
    e.metin((KENAR, y + 20 * K), t("tripsEmpty"), ft, e.P["dimAA"])
    e.alt_bar(2)
    return e


EKRANLAR = (("09b_profil", profil_v2), ("12b_ana_host", ana_host_v2),
            ("12c_ilanlarim", ilanlarim_v2), ("14b_seyahatler", seyahatler_v2))

if __name__ == "__main__":
    os.makedirs(CIKTI, exist_ok=True)
    for ad, fn in EKRANLAR:
        im = fn().im.convert("RGB")
        im.save(os.path.join(CIKTI, ad + ".png"))
        print("✓", ad)
