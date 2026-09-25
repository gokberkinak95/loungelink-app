#!/usr/bin/env python3
# MVP ekran görüntüsü (OCR) ↔ canlı app (headless render) METİN KARŞILAŞTIRMASI
# Her ekran çifti için: MVP'de olup canlı app'te BULUNMAYAN anlamlı ifadeler.
import os, re, unicodedata

PAIRS = [
    ("host_bul_ekranı", "kesfet", "Host Bul / Keşfet"),
    ("MVp_Tanış_ekranı_1", "tanis", "Tanış"),
    ("guest_seyahatlerim_sayfası_sayfa_içerisindeki_host_bul_ve_diğer_ekranlar", "seyahatlerim", "Seyahatlerim"),
    ("mvp_profil_tabı_genel_görünüm_1", "profil", "Profil"),
    ("mvp_güven_puanı_ekranı", "guven", "Güven Puanım"),
    ("mvp_güvenlik_merkezi_ekranı", "guvenlik", "Güvenlik Merkezi"),
    ("mvp_mağaza_ekranı", "magaza", "Mağaza"),
    ("mvp_davet_et_kazan_ekranı", "davet", "Davet Et"),
    ("mvp_bildirimler_ekranı", "bildirimler", "Bildirimler"),
    ("mvp_oturum_geçmişi_ekranı_oturum_tabı", "gecmis", "Oturum Geçmişi"),
    ("mvp_Lounge_erişimi_kurulumu_adımı_sonrası_müsaitlik_ekle_ekranı_1", "musaitlik", "Müsaitlik Ekle"),
    ("MVP_Yayın_tabı_ve_yayın_Davet_sayfası_detayı", "yayin_davet", "Yayın & Davet"),
    ("mvp_profil_düzenle_1", "duzenle", "Profili Düzenle"),
    ("mvp_Oturum._Canlı_durum_ekranı", "canli_durum", "Canlı Durum"),
    ("Mvp_başka_kullanıcının_profil_görünümü_Bağlantılı_ise", "baska_profil", "Başka Kullanıcı Profili"),
    ("mvp_chat_ekranı", "sohbet_bekliyor", "Sohbet"),
    ("mvp_oturumu_tamamla_ekranı", "sohbet_aktif", "Oturum Devam Ediyor"),
    ("mvp_oturum_tamamlandı_ekranı_1", "sohbet_tamam", "Oturum Tamamlandı"),
]

def norm(s):
    s = unicodedata.normalize("NFKC", s).lower()
    s = s.replace("i̇", "i").replace("ı", "i").replace("ş", "s").replace("ğ", "g")
    s = s.replace("ü", "u").replace("ö", "o").replace("ç", "c").replace("â", "a")
    return re.sub(r"[^a-z0-9 ]+", " ", s)

# OCR gürültüsü ve ekrandan bağımsız satırlar
NOISE = re.compile(r"^(9:41|loungelink|[<>‹›\|\(\)\[\]{}]+|[0-9:%.\-–—·•●○★✓✦✈◈⊞⚠🔒🆘]+|"
                   r"ana sayfa|yayin|tanis|profil|seyahat|en|tr)$")

def words(txt):
    out = []
    for line in txt.splitlines():
        n = norm(line).strip()
        if not n or NOISE.match(n):
            continue
        # 3+ harfli kelimeleri al (OCR tek harfleri bozuyor)
        for w in n.split():
            if len(w) >= 4:
                out.append(w)
    return out

def phrases(txt):
    out = []
    for line in txt.splitlines():
        n = " ".join(w for w in norm(line).split() if len(w) >= 3).strip()
        if len(n) >= 8 and not NOISE.match(n):
            out.append((line.strip(), n))
    return out

print("MVP ↔ CANLI APP METİN KARŞILAŞTIRMASI")
print("=" * 62)
total_missing = 0
for mvp_file, live_file, label in PAIRS:
    mvp_path = f"/tmp/mvp_txt/{mvp_file}.txt"
    live_path = f"/tmp/live_texts/{live_file}.txt"
    if not os.path.exists(mvp_path) or not os.path.exists(live_path):
        print(f"\n[ATLANDI] {label} (dosya yok)")
        continue
    mvp = open(mvp_path, encoding="utf-8", errors="ignore").read()
    live = open(live_path, encoding="utf-8", errors="ignore").read()
    live_words = set(words(live))
    missing = []
    for raw, n in phrases(mvp):
        toks = [w for w in n.split() if len(w) >= 4]
        if not toks:
            continue
        hit = sum(1 for w in toks if w in live_words)
        if hit / len(toks) < 0.5:          # ifadenin yarısından azı canlıda var
            missing.append(raw)
    total_missing += len(missing)
    print(f"\n### {label}   (MVP: {mvp_file}.jpg ↔ canlı: {live_file}.txt)")
    if not missing:
        print("   ✓ MVP'deki tüm anlamlı ifadeler canlı ekranda karşılanıyor")
    else:
        for m in missing[:14]:
            print("   ✗ MVP'de var, canlıda yok →", m[:90])
        if len(missing) > 14:
            print(f"   … ve {len(missing)-14} satır daha")
print("\n" + "=" * 62)
print("Toplam eşleşmeyen ifade:", total_missing)
