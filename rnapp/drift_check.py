#!/usr/bin/env python3
# LoungeLink · drift_check.py — "DÜŞEN ADIM" DENETİMİ
# ----------------------------------------------------------------------------
# NEDEN VAR:
# Bu projede en pahalı iki hata da aynı kökten geldi: bir fonksiyon SONRAKİ bir
# SQL dosyasında yeniden yazıldı ve ESKİ sürümdeki bir adım sessizce düştü.
#   • create_request 026'da yeniden yazıldı → `filled = filled + 1` düştü
#     → slot sayacı aylarca çalışmadı, "N açık" hep yanlış gösterdi
#   • respond_request 007'de kaldı, 026/027 diğerlerini düzeltirken atlandı
#     → geçersiz enum ile host hiçbir isteği kabul edemedi
#
# Ne check.js ne contract_check ne flow_check bunu görebilirdi: fonksiyon
# sözdizimsel olarak doğru, imzası doğru, sadece BİR ADIM EKSİK.
#
# BU BETİK NE YAPAR:
# Aynı fonksiyonun tüm sürümlerini sırayla çıkarır, ESKİ sürümlerde olup ETKİN
# (son) sürümde OLMAYAN "anlamlı etki"leri listeler. Anlamlı etki = yan etkisi
# olan ifadeler: update/insert/delete hedefleri, perform çağrıları, raise
# exception kodları.
#
# Çıktı bir SUÇLAMA değil, bir SORU listesidir: "bu adım bilerek mi kaldırıldı?"
# Bilerekse ALLOWLIST'e eklenir ve bir daha sorulmaz.
# ----------------------------------------------------------------------------
import re, os, glob, sys

# v1.94 — taşınabilir yol + boşsa gürültülü ölüm (ll_paths.py)
import ll_paths
SQL_DIR = ll_paths.sql_dir()
ll_paths.require_sql('drift_check')

# Bilerek kaldırıldığı doğrulanmış adımlar — bir daha uyarma.
# Biçim: (fonksiyon, düşen etkinin içerdiği metin)
ALLOWLIST = {
    # --- 4 Ekim 2026 · uçtan uca test turu (SQL 316 · 320 · 322) ---
    # 316: bayat istek bildirimi `insert notifications` yerine `bildir()` (TR+EN, doğru sebep).
    ('bayat_istekleri_iade_et', 'insert notifications'),
    # 320: preflag gövdesi CANLI tanımdan (313 yaması `bildir()` zaten içeride); dosyadaki
    #      eski `insert notifications` canlıda 313'ten beri yok — kayıp değil.
    ('create_request_impl_preflag', 'insert notifications'),
    # 322: ilan kapatma `hesap_acik_islerini_kapat` yardımcısına taşındı (silme + yasak ortak).
    ('delete_my_account', 'update availabilities'),
    # --- SQL 280 (1 Eylül) · İADE TEK KAPIDAN ---
    # `respond_request` (decline) ve `cancel_request` içindeki elle
    # `insert into credit_ledger` BİLEREK kaldırıldı: iade artık
    # `istek_kredisi_iade(p_req, p_reason)` yardımcısından yazılıyor
    # (idempotent; tutulan kadar; `request_free_tier` ile K1 kapandı).
    # Ölçüldü: iki fonksiyonun canlı gövdesinde `istek_kredisi_iade` geçiyor.
    ('respond_request', 'insert credit_ledger'),
    ('cancel_request', 'insert credit_ledger'),
    # SQL 284: `resolve_dispute` de aynı tek kapıdan iade ediyor
    # (`istek_kredisi_iade(p_req, 'dispute_refund')`); elle insert kalktı.
    ('resolve_dispute', 'insert credit_ledger'),

    # --- v2.77 · CANLI GÖVDE OKUMASINA GEÇİLİNCE GÖRÜNEN ÜÇ KARAR ---
    # (Metin taraması bunları göremiyordu; üçü de ÖLÇÜLDÜ.)

    # SQL 213: sağlayıcı fonksiyonları yetkisizde ARTIK FIRLATMIYOR.
    # `raise not_partner` yerine
    #   {"known": false, "yetki": false, "not": "...yetkiniz yok..."}
    # dönüyor. Neden: bir panel ekranının "yetkin yok" hâli çökme değil,
    # boş tablo + açıklama olmalı. Kural `partner_gate_preflag`
    # gövdesinde duruyor; değişen sunum katmanı.
    ('partner_payout', 'raise not_partner'),

    # SQL 166: `cancel_request` içindeki elle `update availabilities`
    # BİLEREK kaldırıldı ve gerekçesi gövdede yazılı:
    #   "filled türetilmiş bir değerdir ve trg_requests_sync_filled
    #    zaten accepted+completed SAYARAK yeniden hesaplıyor. Buradaki
    #    elle azaltma ikinci kez düşürüp ilanı boş gösteriyordu
    #    (2 slot, 1 kabul → 0 görünüyordu)."
    # Yani bu adımı geri koymak, düzeltilen hatayı geri getirirdi.
    ('cancel_request', 'update availabilities'),

    # SQL 180: `flow_gate_test` temizliği kendi içinde `delete from`
    # yazmıyor, `flow_test_cleanup` yardımcısına devrediyor (ölçtüm:
    # gövdede `flow_test_cleanup` geçiyor). Temizlik kaybolmadı, tek
    # yere toplandı — iki test iki farklı temizlik yazmasın diye.
    ('flow_gate_test', 'delete requests'),

    # --- v2.77 / SQL 207 KARARI: client_errors → app_errors ---
    # 206 `trg_host_credit` içinde `insert into client_errors` yazıyordu.
    # Ölçtüm: `client_errors` diye bir tablo YOK; doğru ad `app_errors`.
    # 206 canlıda çalışsaydı, kredi basımı hata verdiğinde tetikleyici
    # 42P01 alır ve OTURUM TAMAMLANAMAZDI — yani hata kaydı tutmaya
    # çalışırken asıl işi bozardı. 207 adı düzeltti.
    # Kural silinmedi, doğru tabloya yazılıyor.
    ('trg_host_credit', 'insert client_errors'),

    # --- v2.77 / SQL 213 KARARI: partner_gate artık boolean ---
    # 209'un `partner_gate`i uuid döndürüyor ve yetkisizde
    # `raise not_partner` atıyordu. 213 kapıyı bayrağa bağlarken
    # BOOLEAN sarmalayıcı koydu: `not_partner` istisnası yakalanıp
    # `false`a çevriliyor, başka her hata GÖRÜNÜR kalıyor.
    #
    # Neden bilerek: bir sağlayıcı ekranının "yetkin yok" durumu bir
    # ÇÖKME değil, boş bir tablo + açıklama olmalı. İstisna fırlatmak,
    # altı ekranın altısında da ham 500 gösterirdi.
    # `raise not_partner` hâlâ `partner_gate_preflag` gövdesinde duruyor;
    # kural silinmedi, sunum katmanı değişti.
    ('partner_gate', 'raise not_partner'),

    # 🔴 BILEREK KALDIRILDI — 078_trust_single_writer.sql
    # rate_session eskiden puan yaziyordu (008 ve 068). 078 bunu KASITLI
    # kaldirdi: puan artik OTURUM TAMAMLANINCA veriliyor, puanlama
    # gonullu ve ayri kaldi. Gerekce dosyada yazili: eskiden kullanici
    # HENUZ KAZANMADIGI puani ekranda goruyordu.
    #
    # Bu bulgu bugune kadar gorunmuyordu cunku ayristirici `$function$`
    # sinirlayicisini tanimiyordu. Denetim yeni bir SORUN bulmadi,
    # ESKI bir dogru karari gorunur kildi.
    ("rate_session", "insert points_ledger"),
    # --- v1.75 / SQL 080 KARARI: oturum yaşam döngüsü yeniden kuruldu ---
    # Kabul artık oturum AÇMAZ (kabul, buluşmadan günler önce olabilir);
    # oturum iki taraf da "Başlat" deyince açılır. Bu yüzden respond_request'te
    # sessions/notifications yazımı bilinçli olarak yok; start_session ise
    # ince bir sarmalayıcı (gövde start_session_request'te).
    ('respond_request', 'insert sessions'),
    ('start_session', 'insert sessions'),
    ('start_session', 'insert notifications'),
    ('start_session', 'insert credit_ledger'),
    ('start_session', 'raise not_authenticated'),
    ('start_session', 'raise request_not_accepted'),
    ('start_session', 'raise not_participant'),
    ('start_session', 'raise session_not_found'),
    ('start_session', 'raise request_not_found'),
    ('start_session', 'update sessions'),
    # YANLIŞ POZİTİF: 001'de compute_trust_badge tanımının HEMEN ARDINDAN
    # gelen "insert into airports" seed bloğu, gövde ayrıştırıcısı tarafından
    # fonksiyonun içi sanılıyor. 078'de fonksiyon tek başına tanımlandığı için
    # "düşen adım" görünüyor — gerçekte kayıp yok (airports seed'i 002'de).
    ('compute_trust_badge', 'insert airports'),
    # --- v1.73 / SQL 079 KARARI ---
    # Doğrulama kapısı "telefon" değil "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA
    # e-posta) oldu: SMS maliyetli, e-posta ücretsiz. raise phone_not_verified
    # yerine is_contact_verified()/contact_not_verified geldi — bilinçli.
    ('create_request', 'raise phone_not_verified'),
    ('create_availability', 'raise phone_not_verified'),
    ('send_invite', 'raise phone_not_verified'),
    ('send_connection', 'raise phone_not_verified'),
    # --- v1.73 / SQL 078 KARARLARI ---
    # Ödül artık confirm_session'da (oturum bitti = hak edildi); rate_session
    # puan VERMEZ. Güven skorunu elle yazan bloklar kaldırıldı — tek yazıcı
    # recompute_trust.
    ('rate_session', 'insert into points_ledger'),
    ('rate_session', 'update trust_scores'),
    ('verify_otp', 'update trust_scores'),
    ('change_phone', 'update trust_scores'),
    # --- v1.71 / SQL 077 KARARLARI ---
    # filled artık TÜRETİLMİŞ değer: requests üzerindeki trigger hesaplıyor.
    # Fonksiyonların içindeki elle "update availabilities set filled" adımları
    # bilerek kaldırıldı (çift sayım kaynağıydı — "0 slot açık" hatası).
    ('respond_request', 'update availabilities'),
    ('respond_invite', 'update availabilities'),
    # ÜRÜN KARARI (Gokberk): kabul = anlaşma. Ayrı "oturumu başlat" adımı ve
    # onun "yalnız host" kısıtı kaldırıldı; oturum kabulde otomatik açılır.
    ('start_session', 'raise only_host_can_start'),
    # 026+ create_request: slot artışı KASITLI olarak respond_request'e taşındı
    # (SQL 061 kararı: slot istekte değil KABULDE dolar).
    ('create_request', 'update availabilities'),
    ('create_request', 'update trust_scores'),
    # --- Aşağıdakiler DOĞRULANMIŞ AD DEĞİŞİKLİKLERİ (mantık duruyor) ---
    # duplicate_request → idempotency_key benzersizliği
    ('create_request', 'raise duplicate_request'),
    # no_slots_available → fully_booked
    ('create_request', 'raise no_slots_available'),
    # own_listing → self_request_blocked
    ('create_request', 'raise own_listing'),
    # not_accepted → request_not_accepted
    ('start_session', 'raise not_accepted'),
    # not_party → only_host_can_start (daha da sıkı: yalnız host)
    ('start_session', 'raise not_party'),
    # already_exists → connection_exists
    ('send_connection', 'raise already_exists'),
    # self_connection → self_connect_blocked
    ('send_connection', 'raise self_connection'),
    # not_pending → already_responded
    ('respond_connection', 'raise not_pending'),
    # reward_not_found → reward_unavailable
    ('redeem_reward', 'raise reward_not_found'),
    # 062 sonrası verify_otp bunları GERİ GETİRİYOR; adlar değişti:
    # code_expired_or_missing → invalid_code, wrong_code → invalid_code
    ('verify_otp', 'raise code_expired_or_missing'),
    ('verify_otp', 'raise wrong_code'),
    # 062: `update verifications` yerine `insert ... on conflict do update`
    # (upsert) kullanıldı. Eski UPDATE, verifications satırı henüz yoksa
    # SESSİZCE hiçbir şey yapmıyordu → phone_verified hiç işaretlenmiyordu.
    # Upsert her durumda doğru sonuç verir; bilinçli iyileştirme.
    ('verify_otp', 'update verifications'),
}

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

# fonksiyon -> [(dosya, gövde), ...] sırayla
versions = {}
for f in sql_files():
    src = open(f, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'create or replace function\s+(?:public\.)?(\w+)\s*\(',
                         src, re.I):
        name = m.group(1)
        # Gövde `end $$;` ile biter. Bir sonraki fonksiyona kadar almak,
        # aradaki bağımsız `do $$ ... $$;` backfill bloklarını da içeri alır
        # ve sahte "düşen adım" üretir (host_requests bu yüzden yanlış çıkmıştı).
        # 🔴 v2.02 DUZELTME: eskiden yalniz `end $$;` araniyordu — bu
        # PLPGSQL govdesinin sonu. `language sql` fonksiyonlarinda `end`
        # YOKTUR, govde dogrudan `$$;` ile biter. Boyle bir fonksiyon
        # dosyanin SONUNDAYSA (lounge_rules_health, 086) govde dosyanin
        # geri kalanini yutuyordu ve sonraki SEED insert'leri o fonksiyonun
        # "adimi" sanilip 4 sahte "dusen adim" uretiyordu.
        # Dogru yontem: acilis $$ ile KAPANIS $$ arasi.
        # 🔴 v2.37: `$function$` SINIRLAYICISI GORULMUYORDU.
        # 079 fonksiyonlarini `$function$ ... $function$` ile yaziyor
        # (pg_dump bicimi). Yalniz `$$` arayan kod o govdeyi bulamiyor,
        # cok ileriye kayiyor ve BASKA fonksiyonlarin etkilerini
        # create_request'e yaziyordu. On sahte "dusen adim" bundandi.
        #
        # Daha kotusu: BEN de ayni tuzaga dustum. 140'ta sarmalayici
        # yazarken "en guncel tanim" diye 065'i sectim, cunku 079'daki
        # tanimi ararken ayni dar deseni kullandim. Yani bu ayristirici
        # hatasi benim de dort hatali sarmalayici yazmama yol acti.
        dm = re.compile(r'\$(\w*)\$').search(src, m.end())
        if dm:
            tag = dm.group(0)
            c = src.find(tag, dm.end())
            stop = (c + len(tag)) if c != -1 else len(src)
        else:
            stop = len(src)
        nxt = src.find('create or replace function', m.end())
        if nxt != -1:
            stop = min(stop, nxt)
        body = src[m.start(): stop]

        # 🔴 KASITLI SABOTAJ SÜRÜMÜ ETKİN SÜRÜM DEĞİLDİR (v2.77).
        # 207 bir MUTASYON KANITI yapıyor: `host_credit_settle`i
        # `raise exception 'KASTEN_BOZULDU'` diyen tek satırlık bir
        # gövdeyle değiştiriyor, oturumun yine de tamamlandığını
        # kanıtlıyor, sonra `execute v_dogru` ile geri koyuyor.
        #
        # Bu denetim "son tanım kazanır" dediği için o TEK SATIRLIK
        # sabotaj gövdesini etkin sandı ve 207'nin gerçek gövdesindeki
        versions.setdefault(name, []).append((os.path.basename(f), body))

# ============================================================
# 🔴 ETKİN GÖVDE METİNDEN DEĞİL, CANLI VERİTABANINDAN (v2.77)
#
# Bu denetimin sorusu şu: "sonraki bir dosya, önceki bir fonksiyonun
# adımını SESSİZCE düşürdü mü?" Cevabı verebilmek için ETKİN gövdeyi
# doğru bilmek gerekiyor — ve metin taraması onu bilemiyor.
#
# ÜÇ YANLIŞ POZİTİF ÖLÇTÜM, üçü de aynı kökten:
#   host_credit_settle → 207 fonksiyonu KASTEN bozup geri koyuyor
#                        (mutasyon kanıtı). Metin taraması sabotaj
#                        kuklasını "son sürüm" sandı.
#   sync_visit_flight  → 197 aynı şeyi yapıyor; üstelik GERİ KOYMA
#                        satırı `|| v_src ||` ile kuruluyor, yani
#                        gövde kaynak dosyada hiç YAZMIYOR.
#   rpc_smoke_test     → aynı desen.
# Üçünde de canlıda ölçtüm: adımlar `pg_proc.prosrc` içinde DURUYOR.
#
# Metne yama üstüne yama yazmak yerine doğru kaynağa gidiyorum:
# `pg_run.py --keep` bir veritabanı bırakıyor; etkin gövde ORADA.
# Veritabanı yoksa metin sezgisine düşüyor ve bunu AÇIKÇA yazıyor —
# sessizce zayıflamak, bu denetimin engellemeye çalıştığı şeyin ta
# kendisi olurdu.
# ============================================================
CANLI = {}
CANLI_VAR = False
try:
    import subprocess, pathlib
    _data = pathlib.Path('/tmp/ll_pg')
    if _data.exists():
        import pgserver
        _bin = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
        _uri = pgserver.get_server(_data).get_uri()
        _r = subprocess.run(
            [str(_bin / 'psql'), _uri, '-X', '-A', '-t', '-F', '\x1f', '-c',
             "select p.proname, replace(coalesce(p.prosrc,''), chr(10), ' ') "
             "from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
             "where n.nspname='public'"],
            capture_output=True, text=True, timeout=180)
        for satir in _r.stdout.splitlines():
            if '\x1f' in satir:
                ad, govde = satir.split('\x1f', 1)
                CANLI[ad.strip()] = govde
        CANLI_VAR = len(CANLI) > 0
except Exception as _e:
    CANLI_VAR = False

# ══════════════════════════════════════════════════════════════════════════
# 🔴 v3.7 — BAYAT ANLIK GÖRÜNTÜ, YANLIŞ CEVABI GÜVENLE VERİYORDU.
#
# `/tmp/ll_pg`deki canlı kopya bir kez kurulup bir daha yenilenmiyordu
# (`pg_run.py --keep` diye anılan bayrak aslında YOK). Bugün ölçtüm:
# oradaki `notify_push` gövdesinde `perform net` yoktu — yani 111 ve
# 210b'den ÖNCEKİ hâli. Denetim de doğal olarak "düşen adım" dedi.
#
# Yani nöbetçi yanlış söylemiyordu; YANLIŞ KAYNAĞA bakıyordu. Ve bunu
# hiç belli etmiyordu: "CANLI veritabanı (435 fonksiyon)" yazıp geçiyordu.
#
# 🆕 SINIF: "BİR DENETİM 'CANLI KAYNAK' KULLANIYORSA, O KAYNAĞIN GÜNCEL
# OLDUĞUNU DA ÖLÇMELİDİR — BAYAT BİR GERÇEK, METİN TAHMİNİNDEN DAHA
# İKNA EDİCİ VE DAHA YANILTICIDIR."
#
# Tazelik ölçütü: en yeni migration dosyalarında tanımlanan fonksiyonların
# canlı kopyada BULUNMASI. Bulunmuyorsa kopya bayattır ve metin taramasına
# düşüyoruz — sessizce değil, AÇIKÇA.
if CANLI_VAR:
    _yeni_fn = set()
    for _f in sql_files()[-6:]:
        _s = open(_f, encoding='utf-8', errors='replace').read()
        _yeni_fn |= set(re.findall(
            r'create or replace function\s+(?:public\.)?(\w+)\s*\(', _s, re.I))
    _eksik = sorted(a for a in _yeni_fn if a not in CANLI)
    if _eksik:
        # ⚠️ METİN TARAMASINA DÜŞMEK ÇÖZÜM DEĞİL: ölçtüm, o kip 201 bulgu
        # üretiyor ve neredeyse hepsi sarmalayıcı deseninden kaynaklanan
        # sahte alarm. 201 sahte alarm, 3 sahte alarmdan KÖTÜDÜR — kimse
        # okumaz. Önce `pg_run.py`nin baktığı SİSTEM veritabanını
        # (`ll`) deniyoruz; o güncelse ondan okuyoruz.
        _tazelendi = False
        try:
            _r2 = subprocess.run(
                ['su', 'postgres', '-c',
                 "psql -X -A -t -F $'\\x1f' -d ll -c \"select p.proname, "
                 "replace(coalesce(p.prosrc,''), chr(10), ' ') from pg_proc p "
                 "join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'\""],
                capture_output=True, text=True, timeout=180)
            _yeni = {}
            for _sat in _r2.stdout.splitlines():
                if '\x1f' in _sat:
                    _ad, _gv = _sat.split('\x1f', 1)
                    _yeni[_ad.strip()] = _gv
            if _yeni and not [a for a in _yeni_fn if a not in _yeni]:
                CANLI = _yeni
                CANLI_VAR = True
                _tazelendi = True
                print('  · /tmp/ll_pg bayattı — güncel `ll` veritabanı kullanıldı.')
        except Exception:
            pass
        if not _tazelendi:
            print('  ⚠ CANLI kopya BAYAT — son migrationların %d fonksiyonu yok '
                  '(%s%s). Metin taramasına düşülüyor; bu kip SAHTE ALARM '
                  'üretir, listeyi ona göre oku.'
                  % (len(_eksik), ', '.join(_eksik[:3]),
                     '…' if len(_eksik) > 3 else ''))
            print('    Tazelemek için: cd ../sql && python3 pg_run.py --reset')
            CANLI_VAR = False
            CANLI = {}

print('  · etkin gövde kaynağı: '
      + ('CANLI veritabanı (%d fonksiyon)' % len(CANLI) if CANLI_VAR
         else 'metin taraması (dosyalardan)'))


def canli_zincir(ad, gorulen=None):
    """Sarmalayıcı zincirini izleyerek TÜM gövdeyi döndür.

    🔴 NEDEN: bu depoda mantık taşıma kalıbı sabittir — özgün fonksiyon
    `X_impl`/`X_base`/`X_preflag` diye yeniden adlandırılır, üstüne aynı
    imzalı ince bir sarmalayıcı konur. SQL 212 tam bunu yaptı:
    `create_request_impl` → `create_request_impl_preflag`, üstüne acil
    kapatma düğmesi + aktif istek tavanı.

    Zincir izlenmezse denetim dört değişmezi birden "düştü" ilan eder
    (self_request_blocked, insufficient_credits, contact_not_verified,
    no_matching_trip) — oysa dördü de `_preflag` gövdesinde duruyor.
    Doğru sarmalama sahte alarm üretmemeli; yoksa listeye bakmamayı
    öğreniriz ve GERÇEK bir düşen adım aramızda kaybolur.
    """
    gorulen = gorulen or set()
    if ad in gorulen or ad not in CANLI:
        return ''
    gorulen.add(ad)
    govde = CANLI[ad]
    parcalar = [govde]
    for hedef in set(re.findall(r'\b(\w+_(?:impl|base|preflag|prebfilter|prerank|prek))\s*\(', govde)):
        parcalar.append(canli_zincir(hedef, gorulen))
    for sonek in ('_impl', '_base', '_preflag', '_prebfilter', '_prerank', '_prek'):
        if ad + sonek in CANLI:
            parcalar.append(canli_zincir(ad + sonek, gorulen))
    return '\n'.join(p for p in parcalar if p)


def effects(body):
    """Gövdedeki yan etkili ifadeleri normalize edilmiş küme olarak döndür.

    🔴 v3.7 — YORUMLAR AYIKLANIYOR. Kalan iki "düşen adım" şuydu:
    111 ve 210b'nin AÇIKLAMA metninde `... insert into notifications ...`
    geçiyor (hatanın nasıl oluştuğunu anlatan satır). 266 aynı açıklamayı
    tekrarlamadığı için "adım düşmüş" sanıldı.

    Bu, bu projede belgelediğim sınıfın dördüncü örneği: kaynağı düz metin
    olarak tarayan denetim, iyi yorumlanmış dosyayı cezalandırır. Burada
    bedeli daha da sinsiydi — açıklamayı SİLMEK denetimi yeşile döndürürdü.

    🆕 SINIF: "BİR DENETİMİ YEŞİLE DÖNDÜRMENİN YOLU AÇIKLAMAYI SİLMEKSE,
    DÜZELTİLMESİ GEREKEN KOD DEĞİL DENETİMDİR."
    """
    # ⚠️ İLK DENEMEM ÇOK GENİŞTİ ve bulgu 2'den 284'e fırladı:
    # `/*...*/` deseni gövdedeki bölme+yıldız dizilimlerini yakalayıp
    # koca blokları yutuyordu, satır-içi `--` kuralı da öyle. Yani
    # yorumları ayıklarken KODU ayıkladım.
    #
    # 🆕 SINIF: "BİR AYIKLAYICIYI GENİŞLETİRKEN ÖLÇÜMÜ İZLEMEZSEN,
    # GÜRÜLTÜYÜ TEMİZLEDİĞİNİ SANARKEN SİNYALİ SİLERSİN."
    #
    # Dar ve ispatlı kural: YALNIZ satır başındaki `--` yorumları.
    # SQL'de yan etkili ifadeler satır başında durur; satır sonundaki
    # açıklamalar zaten `insert into` gibi bir kalıp içermez.
    body = re.sub(r'^\s*--[^\n]*$', ' ', body, flags=re.M)
    low = body.lower()
    out = set()
    for m in re.finditer(r'\bupdate\s+(\w+)\s+set\b', low):
        out.add(f"update {m.group(1)}")
    for m in re.finditer(r'\binsert\s+into\s+(\w+)', low):
        out.add(f"insert {m.group(1)}")
    for m in re.finditer(r'\bdelete\s+from\s+(\w+)', low):
        out.add(f"delete {m.group(1)}")
    for m in re.finditer(r'\bperform\s+(\w+)', low):
        out.add(f"perform {m.group(1)}")
    for m in re.finditer(r"raise\s+exception\s+'(\w+)'", low):
        out.add(f"raise {m.group(1)}")
    return out

findings = []
for name, vs in versions.items():
    if len(vs) < 2:
        continue
    eff_file, eff_body = vs[-1]           # etkin sürüm = son tanım (metin)
    if CANLI_VAR:
        if name not in CANLI:
            continue                       # canlıda yok: bu bir tetikleyici/kukla adı olabilir
        eff_body = canli_zincir(name)      # ETKİN GÖVDE = veritabanındaki (sarmalayıcı zinciriyle)
    # 🔴 SARMALAMA MANTIGI TASIR (v2.37).
    # 140'ta create_request'in gövdesini create_request_impl'e taşıdım.
    # Bu denetim yalnız sarmalayıcıya baktığı için ON etkinin düştüğünü
    # sandı — teknik olarak haklı, ama mantık SİLİNMEDİ, TAŞINDI.
    #
    # Sahte alarm en tehlikeli denetim hatasıdır: gerçek bir düşen adımı
    # bu on satırın arasında kaybederdik ve zamanla listeye hiç
    # bakmamayı öğrenirdik.
    impl_vs = versions.get(name + '_impl')
    if impl_vs:
        eff_body = eff_body + '\n' + impl_vs[-1][1]
    eff = effects(eff_body)
    for old_file, old_body in vs[:-1]:
        lost = effects(old_body) - eff
        for l in sorted(lost):
            if any(l.startswith(a[1]) and a[0] == name for a in ALLOWLIST):
                continue
            findings.append((name, old_file, eff_file, l))

if not findings:
    print("✓ düşen adım yok — çok kez tanımlanan fonksiyonların etkin "
          "sürümleri eski sürümlerdeki tüm etkileri koruyor")
    sys.exit(0)

print(f"⚠ {len(findings)} olası DÜŞEN ADIM "
      f"(eski sürümde vardı, etkin sürümde yok):\n")
cur = None
for name, oldf, efff, lost in findings:
    if name != cur:
        print(f"  {name}  (etkin: {efff})")
        cur = name
    print(f"      ✗ {lost:34} — {oldf}'de vardı")
print("\nHer biri için karar ver: bilerek mi kaldırıldı (ALLOWLIST'e ekle) "
      "yoksa KAYIP mı (geri koy)?")
# Bu betik build'i DURDURMAZ — inceleme listesidir.
sys.exit(0)
