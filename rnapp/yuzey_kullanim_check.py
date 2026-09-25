#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""yuzey_kullanim_check.py — YUZEYE YAZILDI AMA HIC CAGRILMADI

🔴 NEDEN VAR (23 Agustos 2026, Gokberk sordu):
   "yaptigin diger seyleri website app bo'da gerekli yerlere uyguladin di mi?"

Olctum ve HAYIR cikti. Ayni turda yazdigim iki RPC'yi hicbir yerden
cagirmamistim:

    acik_istek_tavanim   → kullanici "1/1 acik istek"i hic gormuyordu
    talep_yogunlugu      → host "bu tarihte 14 kisi bekliyor"u hic gormuyordu

Ikincisi ozellikle aci: "haber ver" akisinin BUTUN AMACI arz tarafina
talep kaniti gostermekti; fonksiyonu yazdim, ekrana koymadim.

Var olan nobetciler bunu goremiyordu:
  · 224'un nobetcisi  → "yuzeyde yazili ama GRANT yok" (yetki sorar)
  · contract_check    → "cagrilan RPC'nin PARAMETRELERI dogru mu"
Ikisi de CAGRILAN fonksiyonlara bakiyor. Hic cagrilmayan bir fonksiyon
her ikisinin de kor noktasi.

🆕 SINIF: "BIR FONKSIYONU YAZIP CAGIRMAMAK, YAZMAMAKTAN DAHA KOTUDUR —
CUNKU YAZILMIS OLMASI, YAPILMIS SANILMASINA YETER."

Bu denetim yuzeydeki her `client='app'` kaydinin app kaynaginda gercekten
cagrildigini dogrular. Cagrilmayanlar icin ya EKRAN yazilir ya da asagidaki
listeye GEREKCESIYLE eklenir. Sessizce unutulmaz.
"""
import json, os, re, subprocess, sys, pathlib

# ── SUNUCU ICI / BASKA FONKSIYONDAN CAGRILANLAR ─────────────────────────
# Her satirin bir GEREKCESI var. Gerekce yazmadan buraya ekleme yapilmaz;
# aksi halde bu liste "unuttuklarimin cop kutusu" olur.
BEYAZ_LISTE = {
    'kural_sorusu_uygun_mu':
        'Rozet fonksiyonunun ICINDEN cagriliyor (221) — app dogrudan cagirmaz.',
    'etkin_plan':
        'my_plan() ve plan_kredisi_yerlestir() icinden cagriliyor (236).',
    'i18n_version':
        'Metin katmani surum damgasi — app metinleri paketten okuyor.',
    'amenity_key_options':
        'BO olanak sozlugu ekrani icin (O9); app tarafi olanaklari ilandan okuyor.',
    'set_visit_purpose':
        'Seyahat amaci 3 Eylul\'den beri EditTrip → update_visit(p_purpose) ile yaziliyor (tasarim 14: kart bir liste satiri, form degil).',
    'misafir_hakki_satin_alinabilir_mi':
        'Plan sayfasi metni SQL 217 ile sabitlendi; RPC olcum/dogrulama icin duruyor.',
}

# ── EKRANI OLMASI GEREKENLER ────────────────────────────────────────────
# Bu ikisi bilerek beyaz listede DEGIL: kullaniciya gosterilmeleri gerek.
# Gosterilmiyorlarsa bu denetim kirmizi yanar.
ZORUNLU_EKRAN = {
    'acik_istek_tavanim': 'Kullanici "kac acik istegi kaldi"yi gormeli (246).',
    'talep_yogunlugu':    'Host "bu tarihte kac kisi bekliyor"u gormeli (247).',
    'kural_sorusu_hakkim': 'Kullanici gunluk soru hakkini gormeli (223).',
    'ucus_kotam':          'Kullanici gunluk ucus sorgu kotasini gormeli (223).',
}

# ── BO TARAFI: `bo_*` fonksiyonlari ve yonetim raporlari ────────────────
# 🔴 Ayni sinif BO'da da vardi: `kredi_akis_raporu` SQL 246'da yazildi,
# hicbir ekran cagirmadi. Ayari degistirdik ama etkisini gosteren rapor
# kimsenin goremedigi yerde durdu.
# `bo_` on eki tasimayan ama EKRANI OLMASI GEREKEN yonetim islevleri.
BO_ZORUNLU = {
    'kredi_akis_raporu',        # 246 — ayar degisikliginin etkisi
    'odul_surdurulebilirlik',   # 245 — vitrin ne yakiyor
    'bekleyen_host_hikayeleri', # 230 — onaylanmayi bekleyen hikayeler
    'host_hikaye_onayla',       # 230 — onay eylemi
    'bekleyen_teslimler',       # 229 — odul teslim kuyrugu
}

BO_BEYAZ_LISTE = {
    'bo_ilan_degisiklikleri':
        'Genel /audit ekrani ayni kayitlari zaten gosteriyor (availability.update, '
        'visit.update). Ayri ekran ikinci bir dogruluk kaynagi olurdu.',
    'bo_register_url':
        'Kayit baglantisi ureten yardimci — sunucu tarafinda kullaniliyor, ekran istemez.',
}

HERE = pathlib.Path(__file__).resolve().parent


def app_kaynagi() -> str:
    parcalar = []
    for p in sorted((HERE / 'src').glob('*.js')):
        parcalar.append(p.read_text(encoding='utf-8'))
    ana = HERE / 'App.js'
    if ana.exists():
        parcalar.append(ana.read_text(encoding='utf-8'))
    return '\n'.join(parcalar)


def yuzey_listesi():
    """ETKIN_TANIMLAR.sql yerine SQL dosyalarindan okur: harness'siz de calissin."""
    kayitlar = {}
    sql_dir = None
    for aday in (HERE.parent / 'sql', HERE / 'sql', pathlib.Path('sql')):
        if aday.is_dir():
            sql_dir = aday
            break
    if sql_dir is None:
        print('✗ sql klasoru bulunamadi — denetim KOSMADI (sessiz gecmiyor).')
        return None
    kalip = re.compile(
        r"\(\s*'([a-z0-9_]+)'\s*,\s*'app'\s*,\s*'([^']*)'\s*\)", re.I)
    # 🔴 v3.9.1 — SİLME SATIRI GÖRÜLMÜYORDU.
    # Bu denetim yalnız `insert into rpc_client_surface` satırlarını
    # topluyordu. 269 bir ucu yüzeyden ÇIKARINCA (`delete from
    # rpc_client_surface where fn_name = …`) denetim onu hâlâ yüzeyde
    # sandı ve "app çağırmıyor" diye kırmızı yandı — yani DÜZELTMEYİ
    # BULGU OLARAK RAPORLADI.
    #
    # 🆕 SINIF: "BİR LİSTEYİ SQL DOSYALARINDAN KURAN DENETİM, EKLEMEYİ
    # OKUYUP SİLMEYİ OKUMUYORSA, LİSTE ZAMANLA GERÇEKTEN SAPAR — VE İLK
    # YANLIŞ ALARM, DOĞRU YAPILMIŞ BİR TEMİZLİĞE VERİLİR."
    #
    # Dosyalar ada göre sıralı okunuyor (001 → 269), yani sonraki dosya
    # öncekini geçersiz kılar — çalıştırma sırasıyla aynı.
    sil_kalip = re.compile(
        r"delete\s+from\s+rpc_client_surface[^;]*?fn_name\s*=\s*'([a-z0-9_]+)'",
        re.I | re.S)
    for f in sorted(sql_dir.glob('*.sql')):
        metin = f.read_text(encoding='utf-8', errors='ignore')
        if 'rpc_client_surface' not in metin:
            continue
        for ad, not_ in kalip.findall(metin):
            kayitlar[ad] = not_
        for ad in sil_kalip.findall(metin):
            kayitlar.pop(ad, None)
    return kayitlar


def main() -> int:
    print('=' * 72)
    print('YUZEY KULLANIM DENETIMI — yazildi ama cagrildi mi?')
    print('=' * 72)

    yuzey = yuzey_listesi()
    if yuzey is None:
        return 2
    if not yuzey:
        # 🔴 BOS KOSMA = SESSIZ YESIL. Hic kayit bulamadiysak bu bir
        # bulgu degil, denetimin kendi arizasidir.
        print('✗ rpc_client_surface kaydi HIC bulunamadi — denetim kendi kendine bos kostu.')
        return 2

    src = app_kaynagi()
    cagrilan = set(re.findall(r'rpc\(\s*["\']([a-z0-9_]+)["\']', src))

    eksik, izinli = [], []
    for ad in sorted(yuzey):
        if ad in cagrilan:
            continue
        if ad in BEYAZ_LISTE:
            izinli.append((ad, BEYAZ_LISTE[ad]))
        else:
            eksik.append((ad, ZORUNLU_EKRAN.get(ad, yuzey[ad] or '(gerekce yok)')))

    # ⚠️ KAPSAM DURUSTLUGU: bu denetim SQL DOSYALARINDAN okuyor ve yalniz
    # `('ad','app','not')` bicimindeki kayitlari goruyor. Canli veritabaninda
    # daha fazlasi olabilir (eski dosyalar baska bicimde yazmis olabilir).
    # Kapsami yazdiriyorum ki "36 taradim"i "hepsini taradim" sanmayalim.
    print(f'  yuzeyde app icin yazili: {len(yuzey)}  (SQL dosyalarindan okunan kayit)')
    print(f'  app kaynaginda cagrilan: {len(cagrilan)}')
    if izinli:
        print(f'  gerekceli istisna      : {len(izinli)}')
        for ad, gerekce in izinli:
            print(f'      · {ad} — {gerekce}')

    if eksik:
        print()
        print(f'  ✗ {len(eksik)} RPC yuzeye yazilmis ama APP HIC CAGIRMIYOR:')
        for ad, gerekce in eksik:
            print(f'      {ad}')
            print(f'         {gerekce}')
        print()
        print('  Her biri icin karar ver: EKRAN yaz, ya da')
        print('  yuzey_kullanim_check.py > BEYAZ_LISTE icine GEREKCESIYLE ekle.')
        return 1

    print('  ✓ yuzeye yazilan her RPC app tarafindan gercekten cagriliyor')

    # ── BO ────────────────────────────────────────────────────────────
    bo_dizin = None
    for aday in (HERE.parent / 'backoffice', pathlib.Path('backoffice')):
        if aday.is_dir():
            bo_dizin = aday
            break
    if bo_dizin is None:
        print('  ⚠ backoffice klasoru bulunamadi — BO tarafi OLCULMEDI.')
        return 0

    sql_dir = HERE.parent / 'sql'
    bo_fn = set()
    for f in sorted(sql_dir.glob('*.sql')):
        metin = f.read_text(encoding='utf-8', errors='ignore')
        # 🔴 ONCE "service_role'e grant verilen HER fonksiyon" diye
        # taradim ve 12 sonuc dondu — cogu cron isi, ic yardimci ya da
        # nobetci. Yani dogru kullanimi cezalandiran genis bir yasak.
        # (Ayni hatayi site check.js §9'da da yapmistim.)
        #
        # Kapsam artik iki net kural: `bo_` on eki (ADLANDIRMA ZATEN
        # "bunun ekrani olacak" demek) + asagidaki ELLE secilmis liste.
        bo_fn |= set(re.findall(r'create or replace function public\.(bo_[a-z0-9_]+)', metin))
    bo_fn |= BO_ZORUNLU

    bo_src = ''
    for p2 in (bo_dizin / 'app').rglob('*.js*'):
        bo_src += p2.read_text(encoding='utf-8', errors='ignore')
    bo_cag = set(re.findall(r'rpc\(\s*["\']([a-z0-9_]+)["\']', bo_src))

    bo_eksik = [a for a in sorted(bo_fn)
                if a not in bo_cag and a not in BO_BEYAZ_LISTE]
    print(f'  BO yonetim fonksiyonu   : {len(bo_fn)}')
    if bo_eksik:
        print(f'  ✗ {len(bo_eksik)} BO fonksiyonunun EKRANI YOK:')
        for a in bo_eksik:
            print(f'      {a}')
        print('  Ekran yaz ya da BO_BEYAZ_LISTE icine gerekcesiyle ekle.')
        return 1
    print('  ✓ her BO yonetim fonksiyonunun bir ekrani var')
    return 0


if __name__ == '__main__':
    sys.exit(main())
