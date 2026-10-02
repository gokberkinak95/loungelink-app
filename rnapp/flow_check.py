#!/usr/bin/env python3
# LoungeLink · flow_check.py — İŞ MANTIĞI AKIŞ DENETİMİ
# ----------------------------------------------------------------------------
# check.js import/export'u, contract_check.py RPC imzalarını doğrular.
# Bu betik ÜÇÜNCÜ katman: happy-path zincirinin (ilan→başvuru→kabul→oturum→
# çift-onay→çift-puan→bağlan) MANTIK değişmezlerini doğrular. Yani "imza doğru"
# değil, "davranış doğru mu" sorusunu sorar — iki-hesap canlı testinin mantık
# kısmını otomatikleştirir. Regresyon (rol promosyonu düştü, yanlış kolon,
# host-only kapısı kalktı gibi) insan gözü olmadan burada yakalanır.
#
# Her SQL fonksiyonunun ETKİN (son tanımlı) gövdesini alır, içinde beklenen
# davranış imzalarını arar. Eksikse FAIL.
# ----------------------------------------------------------------------------
import re, os, glob, sys

# v1.94 — taşınabilir yol + boşsa gürültülü ölüm (ll_paths.py)
import ll_paths
SQL_DIR = ll_paths.sql_dir()
ll_paths.require_sql('flow_check')

def sql_files():
# 🔴 v2.0 — DESEN DUZELTMESI: eskiden '0*.sql' idi ve migration 100'den
# itibaren HICBIR DOSYAYI GORMUYORDU. Uc haneli numaralara gecince
# denetimler sessizce eksik calisiyordu — contract_check bunu
# "fonksiyon SQL'de yok" diye bildirdi ve tuzak boyle yakalandi.
    fs = glob.glob(os.path.join(SQL_DIR, '[0-9]*.sql'))
    def key(p):
        m = re.match(r'(\d+)([a-z]?)', os.path.basename(p))
        return (int(m.group(1)), m.group(2) or '')
    return sorted(fs, key=key)

# Her fonksiyonun ETKİN gövdesini topla (son tanım kazanır)
bodies = {}   # name -> body text
for f in sql_files():
    src = open(f, encoding='utf-8', errors='replace').read()

    # 🔴 YENİDEN ADLANDIRMA ÖNCE İŞLENİR (v2.77).
    # SQL 212 şunu yapıyor:
    #     alter function public.create_request_impl(...) rename to create_request_impl_preflag;
    #     create or replace function public.create_request_impl(...)  -- yeni, ince sarmalayıcı
    # Bu denetim yalnız "create or replace" satırlarını topluyordu ve
    # SON tanım kazanıyordu. Sonuç: `create_request_impl` anahtarı
    # 207'nin 80 satırlık iş mantığından, 212'nin 12 satırlık
    # sarmalayıcısına döndü — dört değişmez birden "KAYIP" göründü.
    # Oysa mantık silinmedi, ADI DEĞİŞTİ.
    #
    # Yeniden adlandırma, gövdeyi ESKİ ADIN O ANKİ HÂLİYLE yeni ada
    # taşır. Dosyalar sıralı işlendiği için bu anlık kopya doğrudur —
    # ve bütün gövdeleri geçmişiyle biriktirmekten çok daha güvenli:
    # öyle yapsaydım, GERÇEKTEN silinmiş bir kontrol de eski gövdede
    # bulunup denetim sahte yeşil yanardı.
    for rn in re.finditer(r'rename\s+to\s+(\w+)', src, re.I):
        yeni_ad = rn.group(1)
        onceki = re.search(r'alter function\s+(?:public\.)?(\w+)\s*\(',
                           src[max(0, rn.start() - 400): rn.start()], re.I)
        if onceki and onceki.group(1) in bodies:
            bodies.setdefault(yeni_ad, bodies[onceki.group(1)])

    for m in re.finditer(r'create or replace function\s+(?:public\.)?(\w+)\s*\(', src, re.I):
        name = m.group(1)
        start = m.start()
        # gövde sonunu bul: bir sonraki "create or replace" ya da dosya sonu
        nxt = src.find('create or replace function', m.end())
        body = src[start: nxt if nxt != -1 else len(src)]
        bodies[name] = body   # son dosya kazanır (sql_files sıralı)

def body(fn):
    # 🔴 SARMALAMA MANTIGI TASIR (v2.37).
    # 140'ta create_request'e hiz siniri eklerken govdeyi
    # create_request_impl'e tasidim. Bu denetim yalniz sarmalayiciya
    # baktigi icin "is mantigi kayboldu" dedi — ve teknik olarak
    # HAKLIYDI: sarmalayicida gercekten yok.
    #
    # Ama mantik SILINMEDI, TASINDI. Denetim ikisini birlikte
    # okumali; yoksa her sarmalama sahte bir alarm uretir ve sahte
    # alarm, denetimi gormezden gelmeyi ogretir.
    # 🔴 SARMALAMA ARTIK ZİNCİR (v2.77).
    # Yukarıdaki ders bir kez daha geldi: SQL 212 `create_request_impl`i
    # `create_request_impl_preflag` diye yeniden adlandırıp üstüne yeni
    # bir sarmalayıcı koydu (acil kapatma düğmesi + aktif istek tavanı).
    # Bu denetim yalnız `fn` ve `fn_impl`e baktığı için dört değişmezin
    # DÖRDÜNÜ birden "kayıp" ilan etti — oysa hepsi `_preflag` gövdesinde
    # duruyordu, hiçbiri silinmemişti.
    #
    # Bu depoda sarmalama artık bir istisna değil, KALIP: `_impl`,
    # `_base`, `_preflag`, `_prebfilter`, `_prerank`. Denetim kalıbı
    # tanımalı; yoksa her doğru sarmalama sahte alarm üretir ve sahte
    # alarm denetimi görmezden gelmeyi öğretir.
    #
    # Zinciri sabit listeyle değil, ADIN KENDİSİNDEN türetiyorum:
    # `X` → `X_impl` → `X_impl_preflag` → ... Böylece yarın yeni bir
    # sarmalayıcı sonekі eklendiğinde de kendiliğinden yakalanır.
    SONEKLER = ('_impl', '_base', '_preflag', '_prebfilter', '_prerank', '_prek')
    gorulen, kuyruk, parcalar = set(), [fn], []
    while kuyruk:
        ad = kuyruk.pop(0)
        if ad in gorulen:
            continue
        gorulen.add(ad)
        g = bodies.get(ad, '')
        if g:
            parcalar.append(g)
        for sonek in SONEKLER:
            if ad + sonek in bodies:
                kuyruk.append(ad + sonek)
        # Gövdede açıkça çağrılan sarmalanmış hedefi de izle.
        for hedef in re.findall(r'public\.(\w+_(?:impl|base|preflag|prebfilter|prerank|prek))\s*\(', g):
            kuyruk.append(hedef)
    return '\n'.join(parcalar).strip()

# ---- Değişmezler: (fonksiyon, açıklama, regex-listesi[hepsi bulunmalı]) ----
CHECKS = [
    # 1) create_request: guest kredisi kontrol + escrow hold, self-request engeli
    ("create_request", "guest kendine istek atamaz + escrow/kredi + telefon + uyumlu seyahat",
     [r'self_request_blocked', r'insufficient_credits|credit_ledger', r'contact_not_verified|is_contact_verified|phone_not_verified', r'no_matching_trip']),

    # 2) respond_request: yalnız host aksiyon alır, accept/decline/cancel
    ("respond_request", "host-only yanıt + accept/decline/cancel",
     [r"'accept'", r"'decline'", r"'cancel'", r'host_id\s*=\s*v?_?uid|host_id\s*<>']),

    # 3) start_session: SADECE host başlatır
    # v1.71 / SQL 077 (ÜRÜN KARARI): kabul = iki tarafın anlaşması. Oturum
    # respond_request içinde OTOMATİK açılır; start_session yalnız eski
    # kayıtlar için duran yardımcı yol. Değişmez artık "yalnız host
    # başlatır" değil, "oturumu yalnızca oturumun TARAFLARI açabilir".
    # v1.75 / SQL 080: oturum artık KABULDE değil, İKİ TARAF DA "başlat"
    # dediğinde açılır (kabul buluşmadan günler önce olabiliyor). Değişmez
    # bu yüzden start_session_request'e taşındı.
    ("start_session_request", "oturumu yalnız taraflar başlatabilir",
     [r'not_party|v_uid not in \(v_req\.host_id, v_req\.guest_id\)']),
    ("start_session_request", "çift onaylı başlatma (iki taraf da basmalı)",
     [r"host_started_at", r"guest_started_at"]),
    ("cancel_session", "5 dakikalık cezasız iptal penceresi",
     [r"cancel_grace_until"]),

    # 4) confirm_session: ÇİFT onay — her iki taraf true olunca tamamlanır
    ("confirm_session", "karşılıklı çift-onay + tamamlanınca settle+bildirim",
     [r'host_confirmed', r'guest_confirmed',
      r'host_confirmed\s+and\s+guest_confirmed|guest_confirmed\s+and\s+host_confirmed',
      # 313: bildirim artık public.bildir() ile (alıcının dilinde) — o da notifications'a yazar.
      r"status\s*=\s*'completed'", r'insert into notifications|public\.bildir\(']),

    # 5) rate_session: KARŞILIKLI — rater karşısını puanlar, tek puan, ödül
    ("rate_session", "reciprocal puanlama + tek-puan + host/guest ödül",
     [r'rated_id', r'rater', r'host.*500|500.*host', r'guest.*200|200.*guest']),

    # 6) create_availability: ilan açan HOST rolüne yükselir + eşleşen guest'e bildirim
    ("create_availability", "ilan→role='host' promo + arz-talep eşleşme bildirimi",
     [r"role\s*=\s*'host'", r'insert into notifications', r'visits']),

    # 7) send_connection / respond_connection: bağlantı çift-onaylı
    ("respond_connection", "bağlantı kabul/ret",
     [r'accept|p_accept', r'accepted|status']),

    # 8) waiting_demand: talep sayacı, staff hariç
    ("waiting_demand", "bekleyen talep sayısı, staff/silinmiş hariç",
     [r'count', r'is_staff', r'deleted_at']),
]

fails = []
passed = 0

# ---- EK DENETİM: notifications.category enum geçerliliği ----------------
# notif_category ÇOĞUL değerler alır. 'request'/'session'/'connection' gibi
# TEKİL bir literal yazılırsa INSERT çalışma anında patlar ve o akış tamamen
# kırılır (respond_request 007'den beri böyleydi: host isteği kabul edemiyordu).
# Statik denetim bunu yakalayamıyordu; artık yakalıyor.
VALID_CATS = {'requests','sessions','invites','connections',
              'system','safety','credits','ratings'}
def _values_rows(seg):
    """`values (a,b),(c,d);` -> her satiri ayri dondur.
    ESKI SURUM COK SATIRLI VALUES'i goremiyordu; confirm_session'daki
    gercek hata (tekil 'session') bu yuzden kacmisti. Artik parantez
    dengeli tarama yapiliyor."""
    out = []; i = 0; n = len(seg)
    while i < n:
        if seg[i] == '(':
            d = 0; j = i; instr = False
            while j < n:
                c = seg[j]
                if c == "'":
                    instr = not instr
                elif not instr:
                    if c == '(':
                        d += 1
                    elif c == ')':
                        d -= 1
                        if d == 0:
                            out.append(seg[i + 1:j]); i = j; break
                j += 1
        elif seg[i] == ';':
            break
        i += 1
    return out

def check_notif_enums():
    bad = []
    for fn, b in bodies.items():
        for m in re.finditer(r'insert\s+into\s+notifications\s*\(([^)]*)\)\s*values',
                             b, re.I):
            cols = [c.strip().lower() for c in m.group(1).split(',')]
            if 'category' not in cols:
                continue
            idx = cols.index('category')
            for row in _values_rows(b[m.end(): m.end() + 3000]):
                vals = re.split(r",(?![^()]*\))", row)
                if idx >= len(vals):
                    continue
                lit = re.match(r"^\s*'([a-z_]+)'", vals[idx])
                if lit and lit.group(1) not in VALID_CATS:
                    bad.append(f"{fn}: category '{lit.group(1)}' gecersiz "
                               f"(gecerli: {', '.join(sorted(VALID_CATS))})")
    return bad

enum_bad = check_notif_enums()
for fn, desc, pats in CHECKS:
    b = body(fn)
    if not b:
        fails.append(f"✗ {fn}: fonksiyon SQL'de BULUNAMADI ({desc})")
        continue
    low = b.lower()
    missing = [p for p in pats if not re.search(p, low, re.I)]
    if missing:
        fails.append(f"✗ {fn}: eksik değişmez → {desc}\n     bulunamayan desen: {missing}")
    else:
        passed += 1

print(f"İş-mantığı akış denetimi: {passed}/{len(CHECKS)} zincir değişmezi doğrulandı")
if enum_bad:
    print("\n🔴 GEÇERSİZ notifications.category enum değeri (INSERT çalışma anında patlar):")
    for e in enum_bad:
        print(f"   ✗ {e}")
    fails.append("notif_category enum hatasi")
if fails:
    print("\n".join(fails))
    print("\n🔴 Akış mantığında regresyon riski — yukarıdaki değişmezler sağlanmıyor.")
    sys.exit(1)
print("✓ happy-path zinciri mantık olarak tutarlı (ilan→başvuru→kabul→oturum→çift-onay→çift-puan→bağlan)")
