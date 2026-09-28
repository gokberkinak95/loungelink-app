#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · pg_run.py   (v2.07'de doğdu)

🔴 NEDEN VAR — SEKİZ HATA SONRA:
  Bu oturumda Gokberk sekiz ayrı SQL hatası aldı ve HEPSİNİ ancak
  çalıştırdıktan sonra öğrendik:
    22P02 enum · 22P02 array literal · 23505 unique · 23514 check ×2
    42P13 return type ×2 · 42P01 temp table · 42702 ambiguous column
  Hepsi SÖZDİZİMİ AÇISINDAN GEÇERLİ; ayrıştırıcı göremez, yalnız
  ÇALIŞTIRINCA ortaya çıkar. Her seferinde "kalıcı denetim yazdım"
  dedim ama denetimler hep BİR ADIM GERİDEN geliyordu: önce o hata
  yaşanıyor, sonra kural yazılıyor.

  Bu betik o sıralamayı tersine çevirir. `pgserver` ile gerçek bir
  PostgreSQL 16 ayağa kaldırıp migration'ları BAŞTAN SONA çalıştırır.
  Artık hata sınıfını tahmin etmeye gerek yok — hepsi burada patlar.

KULLANIM:
    python pg_run.py            # 001..son + SEED
    python pg_run.py 083        # yalnız 083'ten itibaren
    python pg_run.py --keep     # veritabanını silme (sonra sorgu atmak için)

NOT: Supabase'e ÖZGÜ şeyler burada yok — `auth` şeması, `auth.uid()`,
RLS'in Supabase tarafı. Onları taklit ediyoruz (aşağıda). Yani bu
harness "Supabase'de de çalışır" garantisi VERMEZ; verdiği garanti
"PostgreSQL sözdizimi, kısıtlar, tipler ve fonksiyon imzaları doğru".
Bu bile şimdiye kadarki sekiz hatanın sekizini de yakalardı.
"""
import csv
import glob
import io
import os
import re
import shutil
import subprocess
import sys
import pathlib

import pgserver

# 🔴 `__file__` BURADA GARANTI DEGIL: uc E2E betigi bu dosyayi
# `exec(open(...).read())` ile yukluyor ve o baglamda __file__ TANIMSIZ.
# Ilk denememde duz `os.path.abspath(__file__)` yazdim ve UC E2E DE
# NameError ile coktu — pg_run tek basina calisirken sorunsuzdu.
# Ders: bir modul baskasi tarafindan exec ediliyorsa, __file__ bir
# varsayimdir, veri degil.
_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)
import ll_paths
import sozlesme_check
import canli_cagri
import tip_derin

# 🔴 TEKRAR KURULUM DENETIMININ KAPSAMI.
# Tum 255 dosyayi iki kez kosmak ~3 dakika daha surer ve eski dosyalarin
# cogu zaten idempotent degil (tarihsel veri goc dosyalari). Olcum SON
# TURA odaklanir: canlida yeniden kosulacak olan dosyalar bunlar.
# Deger dusurulurse kapsam genisler — ama once eski dosyalarin
# idempotent olmadigini bilerek kabul ettigimizi soylemek gerekir.
TEKRAR_ESIK = 219

DATA = pathlib.Path('/tmp/ll_pg')
BIN = pathlib.Path(pgserver.__file__).parent / 'pginstall' / 'bin'
ENV = {'PATH': f'{BIN}:/usr/bin:/bin', 'HOME': '/tmp'}
# 28 Eylül — Windows'ta yalın ortamla psql ağ katmanını açamıyor
# (SYSTEMROOT yok → winsock yok) ve boş bir "psql: error:" ile düşüyordu.
if os.name == 'nt':
    ENV = {**os.environ, 'PATH': f'{BIN};' + os.environ.get('PATH', '')}


def psql(uri, sql=None, file=None, quiet=True, tuples=False):
    # 28 Eylül — adres `-d` ile: Windows psql'i konumsal argümandan SONRAKİ
    # seçenekleri yok sayıyordu ("extra command-line argument ignored").
    cmd = [str(BIN / 'psql'), '-d', uri, '-v', 'ON_ERROR_STOP=1', '-X']
    if tuples:
        cmd += ['-t', '-A']
    if quiet:
        cmd += ['-q']
    if file:
        # 🔴 `-1` = DOSYANIN TAMAMI TEK ISLEMDE (18 Agustos 2026).
        # Gokberk kurulumu Supabase SQL Editor'den yapiyor ve editor
        # betigi TEK ISLEM olarak sariyor. psql ise varsayilan olarak her
        # ifadeyi AYRI islemde calistirir. Bu fark iki kez canliya hata
        # gonderdi ve ikisi de bende YESIL yandi:
        #
        #   202 → 42P01 relation "_tz_src" does not exist
        #   210 → 55P04 unsafe use of new value "yolcu" of enum plan_type
        #         HINT: New enum values must be committed before use.
        #
        # Ikisi de "islem sinirlari" sinifindan. `-1` olmadan harness,
        # kullanicinin KULLANMADIGI bir ortami olcuyordu. Artik ayni
        # ortami olcuyor: bir dosya burada gecerse editorde de gecer.
        #
        # Olctum: 244 dosyanin 244'u bu modda temiz. Yani maliyeti yok,
        # kazanci bir hata sinifinin tamami.
        cmd += ['-1', '-f', str(file)]
        return subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8',
                              errors='replace', env=ENV)
    # 28 Eylül — SQL komut satırından (-c) değil STDIN'den: Windows'ta çok
    # satırlı, Türkçe karakterli argüman sistem kod sayfasında (cp1254)
    # bozuluyor ve psql boş bir "error:" ile düşüyordu. Çıktı da UTF-8.
    cmd += ['-f', '-']
    return subprocess.run(cmd, input=sql, capture_output=True, text=True, encoding='utf-8',
                          errors='replace', env={**ENV, 'PGCLIENTENCODING': 'UTF8'})


def kopyalayici(uri):
    """`sozlesme_check` için satır okuyucu üretir.

    🔴 NEDEN `copy ... to stdout (format csv)` VE DÜZ `-t -A` DEĞİL:
    okunan şey `pg_proc.prosrc`, yani İÇİNDE SATIR SONU, VİRGÜL VE TIRNAK
    olan fonksiyon gövdeleri. Ayraçla bölen bir okuyucu gövdenin
    ortasında satırı ikiye böler ve denetim SESSİZCE eksik veri üzerinde
    çalışır — yani yeşil yanar. CSV, kaçışı PostgreSQL'e yaptırır."""
    def kopyala(sql):
        r = psql(uri, f'copy ({sql}) to stdout with (format csv)', tuples=True)
        if r.returncode != 0:
            # Hatayı ASLA yutma: boş liste dönmek "ihlal yok" demektir ve
            # bu, denetimi yeşil yakan bir yalandır.
            raise RuntimeError((r.stderr or '').strip()[:400])
        return [row for row in csv.reader(io.StringIO(r.stdout)) if row]
    return kopyala


def app_kaynak_dosyalari():
    """App'in DOĞRUDAN tablo sorgusu içeren kaynakları (App.js + src/*.js).

    Yalnız MOBİL UYGULAMA taranır: app her zaman anon anahtarı + kullanıcı
    oturumuyla, yani `authenticated` rolüyle konuşur. Backoffice'in bir
    kısmı `sbAdmin()` (service_role) kullanır ve service_role GRANT'ları
    da RLS'i de aşar; onu bu ölçüme katmak yanlış alarm üretirdi."""
    a = ll_paths.app_dir()
    return ([f for f in [os.path.join(a, 'App.js')] if os.path.isfile(f)]
            + sorted(glob.glob(os.path.join(a, 'src', '*.js'))))


# ============================================================
# SUPABASE TAKLİDİ
# Migration'lar `auth.users`, `auth.uid()`, `auth.identities` ve
# `service_role` gibi Supabase parçalarına dayanıyor. Bunlar olmadan
# dosyalar daha ilk satırda düşer ve asıl hataları göremeyiz.
# ============================================================
SHIM = """
create schema if not exists auth;
create schema if not exists extensions;

-- 🔴 Bu PostgreSQL derlemesinde pgcrypto ve uuid-ossp YOK.
-- Ikisi de yalniz DEGER uretiyor; migration'larin DOGRULUGUNU etkilemiyor.
-- PG16'da gen_random_uuid() cekirdekte var, onu sarmaliyoruz. crypt/gen_salt
-- ise sadece SEED sifresinde kullaniliyor — burada gercek hash gerekmiyor,
-- sozdiziminin ve imzanin dogrulanmasi yeterli.
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pgcrypto with schema extensions;
-- public'ten de erisilebilsin (bazi migration'lar semasiz cagiriyor)
create or replace function public.uuid_generate_v4() returns uuid
  language sql volatile as $fn$ select gen_random_uuid() $fn$;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  instance_id uuid, aud text, role text, email text unique,
  encrypted_password text, email_confirmed_at timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  phone text, banned_until timestamptz,
  confirmation_token text, recovery_token text, email_change text,
  email_change_token_new text, email_change_token_current text,
  phone_change text, phone_change_token text, reauthentication_token text,
  is_sso_user boolean default false
);
create table if not exists auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  provider_id text, identity_data jsonb, provider text,
  last_sign_in_at timestamptz, created_at timestamptz, updated_at timestamptz
);
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade
);

-- auth.uid(): Supabase JWT'den okur. Burada oturum degiskeninden.
-- 🔴 v2.75 — BOŞ DİZGİ, "OTURUM YOK" DEMEKTİR.
-- Eski taklit `current_setting(...)::jsonb` yazıyordu ve nöbetçiler
-- oturumu kapatmak için `set_config('request.jwt.claims','',true)`
-- kullandığında `''::jsonb` patlıyordu:
--     ERROR: invalid input syntax for type json
-- Hata ANLAŞILMAZDI — json'la ilgisi olmayan bir fonksiyonun içinde
-- çıkıyordu ve saatlerce yanlış yerde arattı.
-- Gerçek Supabase'de claim hiç ayarlanmamışsa `current_setting`
-- NULL döner ve sorun çıkmaz; boş dizgi yalnız BİZİM test
-- kurgumuzun ürettiği bir durum. Taklit artık ikisini de aynı
-- şekilde ele alıyor: boş dizgi = oturum yok.
create or replace function auth.uid() returns uuid language sql stable as $fn$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid;
$fn$;
create or replace function auth.role() returns text language sql stable as $fn$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', 'authenticated');
$fn$;

-- Supabase platform parcalari: realtime yayini, storage semasi, pg_net.
-- Bunlar migration'larin DOGRULUGUYLA ilgili degil; olmayinca dosya
-- basindan duser ve asil hatalari goremeyiz.
do $do$ begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $do$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key, name text, public boolean default false,
  created_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text, owner uuid, created_at timestamptz default now(),
  updated_at timestamptz default now(), last_accessed_at timestamptz,
  metadata jsonb, path_tokens text[]
);
alter table storage.objects enable row level security;

-- 🔴 `storage.foldername()` — 024'un TEK eksik parcasi buydu ve alti tur
-- boyunca "Supabase'e ozgu, atlaniyor" diye gecistirdim. Oysa fonksiyon
-- iki satir: yol dizesini '/' ile bolup SON parcayi (dosya adi) atiyor.
-- Supabase'in kendi tanimi da bundan ibaret. "Taklit edilemez" dedigim
-- sey, taklit etmeye usenmis oldugum seymis.
create or replace function storage.foldername(name text)
returns text[] language plpgsql immutable as $fn$
declare parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[1 : array_length(parts, 1) - 1];
end $fn$;

create or replace function storage.filename(name text)
returns text language plpgsql immutable as $fn$
declare parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[array_length(parts, 1)];
end $fn$;

create or replace function storage.extension(name text)
returns text language plpgsql immutable as $fn$
declare p text[];
begin
  p := string_to_array(storage.filename(name), '.');
  return p[array_length(p, 1)];
end $fn$;

create schema if not exists net;
create or replace function net.http_post(url text, body jsonb default '{}'::jsonb,
                                         params jsonb default '{}'::jsonb,
                                         headers jsonb default '{}'::jsonb,
                                         timeout_milliseconds integer default 5000)
  returns bigint language sql volatile as $fn$ select 0::bigint $fn$;

do $do$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role;
  end if;
end $do$;

-- 🔴 22 AGUSTOS: HARNESS SUPABASE'IN BASLANGIC NOKTASINI TAKLIT ETMIYORDU.
-- SQL 232 burada YESIL yandi, canlida KIRMIZI: "profiles kapi kolonlari
-- hala yazilabilir (3 grant)". Sebep sozdizimi degil, BASLANGIC DURUMU:
--
--   Bos Postgres  → anon/authenticated'in HICBIR hakki yok
--   Supabase      → `alter default privileges ... grant all on tables to
--                    anon, authenticated, service_role` acik gelir, yani
--                    her YENI TABLO otomatik olarak bu rollere ACIK dogar.
--
-- Yani "grant kapandi mi?" diye soran her nobetci, kapanacak bir grant'in
-- HIC OLMADIGI bir dunyada olcum yapiyordu. Yesil isik, kurulumun degil
-- ortamin yesiliydi.
--
-- 🆕 SINIF: "BIR NOBETCI, GERCEK ORTAMIN BASLANGIC DURUMUNU TAKLIT
-- ETMIYORSA, OLCTUGU SEY URUN DEGIL KENDI LABORATUVARIDIR."
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

-- 🔴 26 AGUSTOS: AYNI DERSIN IKINCI KATI — TAKLIT YETERINCE DERIN DEGILDI.
-- SQL 253 burada YESIL yandi, Gokberk'in veritabaninda KIRMIZI:
-- "yeni tablolar hala anon'a OKUNUR doguyor".
--
-- Ustteki satirlar Supabase'in baslangic durumunu taklit ediyordu ama
-- BIR AYRINTIYI atliyordu: `alter default privileges` GLOBAL bir ayar
-- degil, HER VEREN ROL ICIN AYRI bir kayittir. Burada kayitlarin sahibi
-- hep `postgres`ti. Supabase'de ise kayitlar BASKA rollerin altinda ve
-- bir kismi SEMASIZ (global) duruyor.
--
-- Sonuc: `alter default privileges in schema public revoke ... from anon`
-- yazan bir migration burada dogru kaydi tesadufen buluyordu. Yesil isik
-- yine kurulumun degil ortamin yesiliydi — bu sefer bir kat daha derinde.
--
-- 🆕 SINIF: "BIR ORTAMI TAKLIT ETMEK, ONUN DEGERLERINI KOPYALAMAK DEGIL
-- YAPISINI KOPYALAMAKTIR — AYNI IZIN, FARKLI SAHIBIN ALTINDA FARKLI
-- DAVRANIR."
do $sb$
begin
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    create role supabase_admin superuser;
  end if;
end $sb$;
alter default privileges for role supabase_admin in schema public
  grant all on tables to anon, authenticated, service_role;
-- ve semasiz (global) bir kayit: Supabase'de bunun karsiligi var ve
-- `in schema public` yazan bir revoke ona HIC dokunmaz.
alter default privileges for role postgres
  grant select on tables to anon, authenticated;
"""


def install_fake_extensions():
    """🔴 Migration'lar `create extension "uuid-ossp"` / `pgcrypto` cagiriyor.
    Bu derlemede ikisi de YOK; ilk dosya duser ve geri kalan 120 dosya
    "relation does not exist" diye ardi ardina cokerdi — asil hatalari
    goremezdik.

    Cozum: uzantilari SAHTE olarak kur. Urettikleri degerler (uuid, hash)
    migration'larin DOGRULUGUNU etkilemiyor; onemli olan `create extension`
    cagrisinin gecmesi ve fonksiyon adlarinin var olmasi."""
    ext = BIN.parent / 'share' / 'postgresql' / 'extension'
    ext.mkdir(parents=True, exist_ok=True)

    (ext / 'uuid-ossp.control').write_text(
        "comment = 'stub'\ndefault_version = '1.1'\nrelocatable = true\n")
    (ext / 'uuid-ossp--1.1.sql').write_text(
        "create function uuid_generate_v4() returns uuid "
        "language sql volatile as $$ select gen_random_uuid() $$;\n"
        "create function uuid_generate_v1() returns uuid "
        "language sql volatile as $$ select gen_random_uuid() $$;\n")

    (ext / 'pg_net.control').write_text(
        "comment = 'stub'\ndefault_version = '0.1'\nrelocatable = false\nschema = 'net'\n")
    (ext / 'pg_net--0.1.sql').write_text("select 1;\n")

    (ext / 'pgcrypto.control').write_text(
        "comment = 'stub'\ndefault_version = '1.3'\nrelocatable = true\n")
    (ext / 'pgcrypto--1.3.sql').write_text(
        # 🔴 v2.71 — ESKİ TAKLİT YUVARLAK GİTMİYORDU.
        # gen_salt sabit 'stub-salt', crypt ise md5($1||$2) döndürüyordu.
        # Gerçek pgcrypto'nun sözleşmesi şudur:
        #     h := crypt(pw, gen_salt('bf'))   -- kaydet
        #     crypt(pw, h) = h                 -- doğrula
        # Eski taklitte ikinci satır ASLA tutmuyordu; yani verify_otp'u
        # harness'te test etmek İMKÂNSIZDI ve bu yüzden telefon
        # doğrulama yolu bugüne kadar hiç sınanmadı.
        # Yeni taklit tuzu hash'in başına gömer, böylece yuvarlak gider.
        "create function gen_salt(text) returns text "
        "language sql volatile as $$ select '$s$' || substr(md5(random()::text), 1, 10) $$;\n"
        "create function gen_salt(text, integer) returns text "
        "language sql volatile as $$ select '$s$' || substr(md5(random()::text), 1, 10) $$;\n"
        "create function crypt(text, text) returns text "
        "language sql immutable as $$ "
        "select substr($2, 1, 13) || md5($1 || substr($2, 1, 13)) $$;\n"
        "create function digest(text, text) returns bytea "
        "language sql immutable as $$ select decode(md5($1), 'hex') $$;\n"
        "create function gen_random_bytes(integer) returns bytea "
        "language sql volatile as $$ select decode(md5(random()::text), 'hex') $$;\n")


def main():
    install_fake_extensions()
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    keep = '--keep' in sys.argv
    start = args[0] if args else '000'

    # 🔴 v2.46 — ESKİ HALİ ÜÇ LINUX YOLU DENİYORDU:
    #   /home/claude/rnapp/sql · /home/claude/sql · ./sql
    # İlk ikisi yalnız Claude'un kabında var. Gokberk'in makinesinde
    # C:\rnapp'ten çalıştırılmadıkça hiçbiri tutmuyordu ve betik
    # "sql klasörü yok" deyip duruyordu. ll_paths tek kaynak.
    sql_dir, _ = ll_paths.require_sql('pg_run')

    if DATA.exists():
        shutil.rmtree(DATA, ignore_errors=True)
    DATA.mkdir(parents=True)
    # 🔴 28 Eylül — WINDOWS'TA initdb DÜŞÜYORDU: sistem yerel ayarı
    # "Turkish_Türkiye.1254", pgserver'ın istediği UTF8 ile birleşmiyor
    # (LC_ALL/LANG ortam değişkenleri Windows'ta dikkate alınmıyor).
    # Kümeyi C yerel ayarıyla biz kurarız; pgserver kurulu küme görünce
    # initdb'yi atlar. Linux'ta (bulut kabı) hiçbir şey değişmez.
    if os.name == 'nt':
        subprocess.run([str(BIN / 'initdb.exe'), '-D', str(DATA), '--auth=trust',
                        '--encoding=UTF8', '--locale=C', '-U', 'postgres'],
                       check=True, capture_output=True, text=True)
    srv = pgserver.get_server(DATA)
    uri = srv.get_uri()

    r = psql(uri, SHIM)
    if r.returncode != 0:
        print('✗ Supabase taklidi kurulamadı:\n', r.stderr[:1500]); return 1
    print('✓ PostgreSQL 16 + Supabase taklidi hazır\n')

    # 🔴 SIRALAMA: "087_" ile "087a_" karsilastirilinca '_' (0x5F) < 'a' (0x61)
    # oldugu icin ANA DOSYA once, PRE_drop SONRA calisiyordu — yani 087
    # fonksiyonlari kuruyor, 087a hemen ardindan dusuruyordu ve 088
    # "entitlement_health does not exist" diyordu. Gercekte PRE_drop
    # HER ZAMAN ana dosyadan ONCE calisir. Sirali anahtar bunu zorunlu kilar.
    def order(f):
        m = re.match(r'^(\d{3})([a-z]?)_', f)
        return (m.group(1), 0 if m.group(2) else 1, f)

    files = sorted((f for f in os.listdir(sql_dir)
                    if re.match(r'^\d{3}[a-z]?_.*\.sql$', f) and f[:3] >= start),
                   key=order)
    seeds = sorted(f for f in os.listdir(sql_dir) if f.startswith('SEED'))

    fails = []
    # 🔴 TIP SOZLESMESI DENETIMI HER DOSYADAN SONRA, O ANKI SEMAYA KARSI.
    # Gokberk 186'yi SQL Editor'e yapistirdiginda 42804 aldi. O hatayi
    # gorebilmenin tek yolu, 186 uygulandiktan HEMEN SONRA, 187 gelmeden
    # once bakmaktir — cunku 187 ayni fonksiyonu cast'lerle yeniden
    # tanimliyor ve son semada hata KALMIYOR. (Olctum: 186'yi bozdum,
    # tam kosu yesil kaldi.) `prepare` veri istemez, calistirmaz.
    tip_bulgu, tip_hazir, tip_hazirsiz = [], 0, []
    for f in files + seeds:
        r = psql(uri, file=os.path.join(sql_dir, f))
        if r.returncode == 0:
            print(f'  ✓ {f}')
            if not os.environ.get('LL_TIP_ATLA'):
                try:
                    b, hz, hs = tip_derin.dosya_denetle(psql, uri,
                                                        os.path.join(sql_dir, f))
                    tip_hazir += hz
                    tip_hazirsiz += [(f, a, s) for a, s in hs]
                    for x in b:
                        tip_bulgu.append(f'{f} · {x}')
                        print(f'      🔴 TIP: {x}')
                except Exception as e:                      # noqa: BLE001
                    print(f'      ⚠ tip denetimi calismadi: {e}')
        else:
            err = [l for l in r.stderr.splitlines() if l.strip()]
            head = next((l for l in err if 'ERROR' in l), err[0] if err else '?')
            print(f'  ✗ {f}\n      {head.strip()[:200]}')
            for l in err:
                if l.strip().startswith(('DETAIL', 'HINT', 'CONTEXT', 'LINE')):
                    print(f'      {l.strip()[:200]}')
            fails.append((f, head.strip()))

    # ── TIP SOZLESMESI KAPSAM RAPORU ────────────────────────────
    # 🔴 SAYIYI BASMAK ZORUNLU. "0 bulgu" cumlesi, KAC TANIMIN
    # olculdugu yazilmadan bir sey ifade etmez — bu depoda iki kez
    # tam olarak boyle bir cumleyle canliya hata gitti.
    if not os.environ.get('LL_TIP_ATLA'):
        print()
        print('-' * 72)
        print('TIP SOZLESMESI (her dosya, uygulandigi ANDAKI semaya karsi)')
        print('-' * 72)
        toplam_t = tip_hazir + len(tip_hazirsiz)
        print(f'  OLCUM (tip): tanim {toplam_t} · PostgreSQL ile OLCULEN {tip_hazir} '
              f'· olculemeyen {len(tip_hazirsiz)} · bulgu {len(tip_bulgu)}')
        if tip_bulgu:
            # 🔴 BULGULARI AYIR: "sonradan ezilen tanimda" olan bir kusur
            # canliya ULASMIYOR. Ikisini ayni kefeye koymak, gercek
            # kusuru dort olu kusurun arasinda kaybediyordu — olctum:
            # bes bulgunun yalnizca BIRI (lounge_radar_people) etkin
            # tanimda duruyordu, digerleri 030/049/054'un sonradan
            # ustune yazilan surumlerindeydi.
            # Kural: bulgunun dosyasi, o fonksiyonu TANIMLAYAN SON dosya
            # degilse, etkin surum baskadir.
            son_tanim = {}
            for _f in files:
                _t = open(os.path.join(sql_dir, _f), encoding='utf-8',
                          errors='replace').read()
                for _m in re.finditer(
                        r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?'
                        r'"?([a-z_][a-z0-9_]*)"?\s*\(', _t, re.I):
                    son_tanim[_m.group(1).lower()] = _f
            canli, eski_tanim = [], []
            for x in tip_bulgu:
                _dosya = x.split(' · ')[0].strip()
                _fn = x.split(' · ')[-1].split('(')[0].strip().lower()
                if son_tanim.get(_fn) == _dosya:
                    canli.append(x)
                else:
                    eski_tanim.append(x)
            if canli:
                print(f'\n  🔴 {len(canli)} BULGU — ETKIN TANIMDA, CANLIYA ULASIYOR:')
                for x in canli:
                    print(f'      {x}')
                fails.extend([('TIP: ' + x, x) for x in canli])
            if eski_tanim:
                print(f'\n  ⚠ {len(eski_tanim)} bulgu SONRADAN EZILEN tanimda '
                      f'(canliya ulasmiyor, yine de kaynakta yanlis):')
                for x in eski_tanim:
                    print(f'      {x}')
        if tip_hazirsiz:
            grup = {}
            for f, ad, sebep in tip_hazirsiz:
                grup.setdefault(sebep[:60], []).append(ad)
            print(f'  Olculemeyen {len(tip_hazirsiz)} tanim hakkinda GARANTI YOK:')
            for sebep, adlar in sorted(grup.items(), key=lambda x: -len(x[1]))[:8]:
                print(f'      [{len(adlar)}] {sebep}')

    # ── KATALOG TIP DENETIMI (dinamik kurulanlar dahil) ──────────
    # Dosya taramasi 45 tanimi olcemiyordu: govdeleri `execute format(...)`
    # ile CALISMA ANINDA olusuyor, dosyada duran sey sablon. Ama
    # calistiktan sonra katalogda gercek govdeleriyle duruyorlar.
    if not os.environ.get('LL_TIP_ATLA'):
        print()
        print('-' * 72)
        print('KATALOG TIP DENETIMI — ETKIN tanimlar (dinamik kurulanlar dahil)')
        print('-' * 72)
        try:
            kb, ko, kx = tip_derin.katalog_denetle(psql, uri)
            print(f'  OLCUM (katalog): PostgreSQL ile OLCULEN {ko} · '
                  f'olculemeyen {len(kx)} · bulgu {len(kb)}')
            if kb:
                print(f'\n  🔴 {len(kb)} BULGU — ETKIN TANIMDA:')
                for x in kb:
                    print(f'      {x}')
                fails.extend([('KATALOG: ' + x, x) for x in kb])
            if kx:
                grp = {}
                for ad, sebep in kx:
                    grp.setdefault(sebep[:60], []).append(ad)
                print(f'  Olculemeyen {len(kx)} tanim hakkinda GARANTI YOK:')
                for sebep, adlar in sorted(grp.items(), key=lambda x: -len(x[1]))[:6]:
                    print(f'      [{len(adlar)}] {sebep}')
        except Exception as e:                       # noqa: BLE001
            print(f'  ⚠ katalog denetimi calismadi: {e}')

    # ============================================================
    # 🔴 SESSIZ ATLAMA DENETIMI
    # 107'de sunu yasadik: 097/099'daki salon eklemeleri
    #     where exists (select 1 from airports where code = ...)
    # diyordu. Havalimani tabloda yoksa satir SESSIZCE atlaniyordu —
    # hata yok, uyari yok, sadece EKSIK VERI. AJet'in 12 havalimanindan
    # 9'unun salonu hic olusmadi ve bunu ALTI TUR fark etmedik.
    #
    # Migration'lar "temiz calisti" demek yeterli degil; sonucun
    # TUTARLI olmasi da gerekiyor. Asagidaki degismezler tam da
    # bu sinifi yakalar: her biri "bir sey sessizce atlandi"nin izi.
    #
    # 🔴 v2.78 — BIR DEGISMEZ ARTIK PYTHON DA OLABILIR.
    # Liste (etiket, SQL) ciftlerinden olusuyordu. Sozlesme denetimleri
    # (hata sinifi 21) fonksiyon GOVDESI ayristirmak zorunda — DECLARE
    # bolumu, atama baglami — ve bunu SQL'e gomsem okunmaz, sinanmaz bir
    # regexp yiginina donerdi. Ikinci eleman artik cagrilabilir de
    # olabilir: ihlal DIZELERININ listesini dondurur.
    # ============================================================
    kopyala = kopyalayici(uri)
    INVARIANTS = [
        # BANK_CARD bilerek kabul satirsizdir: banka kartlari icin salon
        # bazli kural TUTMUYORUZ, genel uyari gosteriyoruz (urun karari).
        # Onu da uyarmak, dogru calisan bir tasarimi hata gibi gosterir.
        ("Kabul satiri OLMAYAN aktif program",
         """select p.code from lounge_programs p where p.active
             and p.entitlement_model is distinct from 'bank_card'
             and not exists (select 1 from lounge_venue_acceptance a
                              where a.program_id = p.id and a.active)"""),
        # 🔴 v2.68 — BU SORGUNUN YARISI EKSIKTI. Adi "katalogda
        # gorunmeyen salon" ama KATALOGA HIC BAKMIYORDU: `lounges`
        # tablosuna join/exists yok. Yani her aktif salonu listeliyor
        # ve HER KOSUDA aliyordu. Bes turdur ekranda duran bu uyari
        # bir veri eksigi degil, eksik yazilmis bir sorguydu.
        # Ders (ucuncu kez): bir denetimin ADI ne olcTUGUNU garanti
        # etmez; denetimi de mutasyonla sinamak gerekir.
        ("Katalogda gorunmeyen aktif salon (host secemez)",
         """select v.airport_code || ' · ' || v.name from lounge_venues v
             where v.active and v.section is null and v.section_of is null
               and v.venue_kind = 'lounge' and v.legacy_lounge_id is null
               and not exists (select 1 from lounges l where l.venue_id = v.id)"""),
        # Yalniz ILAN ACILMIS havalimanlarini sor. Katalogda dunyanin her
        # yerinden havalimani var; hepsinde salon beklemek anlamsiz.
        # Onemli olan: kullanicinin GERCEKTEN gittigi yerde secenek var mi?
        ("Ilan acilmis ama salonu OLMAYAN havalimani",
         """select distinct av.airport_code from availabilities av
             where not exists (select 1 from lounge_venues v
                                where v.airport_code = av.airport_code and v.active)"""),
        ("Venue baglantisi kopuk katalog kaydi",
         "select l.airport_code || ' · ' || l.name from lounges l where l.active and l.venue_id is null"),
        ("Pasif salona bagli AKTIF kabul satiri",
         """select v.name from lounge_venue_acceptance a join lounge_venues v on v.id = a.venue_id
             where a.active and not v.active"""),
        # 🔴 BEKLENEN SAYI DENETIMI.
        # Mutasyon testinde ogrendim: 107'yi cikarinca "ilan acilmis ama
        # salon yok" denetimi SUSTU — cunku SEED de ayni sessiz-atlama
        # desenini kullaniyor (havalimani yoksa ilan da acilmiyor).
        # Yani eksiklik kendini gizliyordu. Tek care BEKLENEN SAYIYI
        # yazmak: kaynak "12 havalimani" diyorsa 12'yi ara.
        # 🔴 v2.68 — SAYI DEGIL KUME. Eski hali "en az 12" diyordu ve
        # 14 sayip SUSMUSTU: iki FAZLA (LHR, ADA) bir EKSIGI (BJV)
        # gizlemisti. AJet'in resmi tablosu 13 havalimani sayiyor;
        # dogru soru "kac tane" degil "HANGILERI".
        ("AJet kabul kumesi kaynakla AYNI degil (13 havalimani)",
         """with bekl(ap) as (values ('SAW'),('AYT'),('ADB'),('BJV'),('DLM'),('ESB'),
                                     ('COV'),('ASR'),('GZT'),('HTY'),('TZX'),('RZV'),('DIY')),
                  var(ap) as (select distinct v.airport_code
                                from lounge_venue_acceptance a
                                join lounge_venues v on v.id = a.venue_id
                                join lounge_programs p on p.id = a.program_id
                               where p.code = 'AJET_MS' and a.active
                                 and a.guest_policy = 'included')
             select 'EKSIK: ' || string_agg(ap, ',') from (select ap from bekl except select ap from var) e
              having count(*) > 0
             union all
             select 'FAZLA: ' || string_agg(ap, ',') from (select ap from var except select ap from bekl) f
              having count(*) > 0"""),
        # 🔴 ORTAMA GORE KALIBRE EDILMIS SAYININ YERI BURASI.
        # 211'de "en fazla 2 kaynak satiri eslesmeyebilir" diye SABIT bir
        # esik vardi ve o 2 sayisi benim verimden geliyordu; Gokberk'te
        # 12 cikti ve KURULUM DURDU. Ayni kusur bugun `limit 25` ve
        # `limit 30` olarak da cikti (192).
        # Migration artik NITELIGE bakiyor (adayi hic olmayan satir varsa
        # durur, belirsizler karara kalir). Sayisal regresyon sinyali ise
        # burada: benim verimde bu sayi degisirse GORURUM, Gokberk'in
        # kurulumu ise bir baskasinin ortamina gore ayarlanmis bir esige
        # takilmaz.
        ("Kart agi kaynak satiri eslesmeden kaldi (karara bagli)",
         """select 'bekleyen: ' || count(*)::text || ' → ' ||
                   coalesce(string_agg(network || '/' || airport || '/' || venue_name, ' · '), '')
              from card_network_source where venue_id is null
             having count(*) > 2"""),
        ("Kart aglari 9 havalimaninda — kapsama EKSIK",
         """select p.code || ': ' || count(distinct v.airport_code) || ' havalimani (9 bekleniyor)'
              from lounge_venue_acceptance a
              join lounge_venues v on v.id = a.venue_id
              join lounge_programs p on p.id = a.program_id
             where p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
               and a.guest_policy = 'paid' and a.active
             group by p.code
            having count(distinct v.airport_code) < 9"""),
        # 🔴 "HIC YOK" ile "EKSIK" AYNI SEY DEGIL.
        # Ilk degismezim "hic kabul satiri olmayan salon" diye ariyordu ve
        # kural11'in bagli oldugu salonu KACIRDI: o salonun baska
        # programlarin satiri vardi, eksik olan KENDI HAVAYOLUNUN kuraliydi.
        # Dogru soru "bir sey var mi" degil, "OLMASI GEREKEN sey var mi".
        ("Havayolu salonu ama o havayolunun kurali YOK",
         """select v.airport_code || ' · ' || v.name from lounge_venues v
             where v.active and v.venue_kind = 'lounge'
               and lower(v.name) like '%turkish airlines%'
               and not exists (
                 select 1 from lounge_venue_acceptance a
                   join lounge_programs p on p.id = a.program_id
                  where a.venue_id = v.id and a.active and p.code = 'TK_MS')"""),
        # 🔴 MUKERRER DENETIMLERI (v2.32)
        # 133'te ogrendim: `lounge_venues` tarafi tertemizken KATALOG
        # tarafinda ayni salonun 2-3 kaydi duruyordu ve denetimlerim
        # "mukerrer yok" diyordu. Yanlis yere baktigim surece dogru
        # cevap alamam — o yuzden mukerrer sorusunu HER anahtar icin
        # ayri ayri soruyorum, ad uzerinden degil KIMLIK uzerinden.
        ("Bir salona bagli BIRDEN COK aktif katalog kaydi",
         """select l.venue_id::text || ' × ' || count(*) from lounges l
             where l.active and l.venue_id is not null
             group by l.venue_id having count(*) > 1"""),
        ("Ayni (salon, program) icin birden cok AKTIF kabul",
         """select a.venue_id::text from lounge_venue_acceptance a where a.active
             group by a.venue_id, a.program_id having count(*) > 1"""),
        # 🔴 v2.68 — BU DENETIM DORT TURDUR YANLIS ALARM VERIYORDU.
        # Gruplama anahtarinda `venue_scope` YOKTU. Ayni kart tipinin
        # domestic / international / abroad icin AYRI kurallari olmasi
        # NORMALDIR (kaynak zaten uc ayri tablo veriyor: Tablo-1/2/5).
        # Denetim bunlari "mukerrer" sayip her kosuda 15 sahte ihlal
        # bildiriyordu. Anahtara scope eklenince: 0 ihlal — yani
        # gercekte hic mukerrer yokmus. Yanlis alarm veren denetim,
        # olmayan denetimden kotudur: okunmaz hale gelir ve o andan
        # sonra GERCEK mukerreri de kacirir (sql_lint ile ayni ders).
        ("Ayni (program, tip, TASIYICI, kabin, KAPSAM, salon) icin birden cok GECERLI kural",
         """select r.program_id::text from lounge_guest_rules r
             where (r.effective_to is null or r.effective_to >= current_date)
             group by r.program_id, coalesce(r.card_tier,''), coalesce(r.carrier,''),
                      coalesce(r.cabin_class,''), coalesce(r.venue_scope,''),
                      coalesce(r.venue_id::text,'')
            having count(*) > 1"""),
        ("Ayni havalimaninda ayni normalize adli AKTIF salon",
         """select v.airport_code from lounge_venues v where v.active
             group by v.airport_code, public.venue_norm(v.name), coalesce(v.section,'')
            having count(*) > 1"""),
        ("Ilan PASIF katalog kaydina bagli (kesiften duser)",
         """select a.id::text from availabilities a
              join lounges l on l.id = a.lounge_id where not l.active"""),
        ("Ayni takma ad IKI programda (host beyani yanlis eslesir)",
         """select a.alias from lounge_program_aliases a
             group by a.alias having count(distinct a.program_id) > 1"""),
        # 🔴 ICERIK DENETIMI — 146'da kartezyen carpim yapip THY
        # kurallarini TUM programlara yazdim. Sayim denetimleri
        # kacirdi cunku sayi DOGRUYDU: her program icin tek satir,
        # ama yanlis programa ait. Dogru sayida yanlis veri,
        # sayim denetiminden gecer.
        ("Kural notu BASKA programa ait gorunuyor (bulasma)",
         "select program || ' · ' || kart from public.rule_contamination_check()"),
        ("Kart tipi kurali olan ama tier'i SORULMAYAN program",
         """select p.code from lounge_programs p
             where p.active and public.program_needs_tier(p.id)
               and not exists (select 1 from lounge_guest_rules r
                                where r.program_id = p.id and r.venue_id is null
                                  and r.card_tier is not null)"""),

        # 🔴 v2.71 — GUVENLIK SINIRI ARTIK BIR DEGISMEZ.
        # Bu satir olmadan asagidaki delik ay boyunca acik durdu:
        #   set role authenticated;
        #   select upsert_admin('...','super_admin','["all"]');  -> {"ok": true}
        # Yani kayit olan herkes super yonetici olabiliyordu. Hicbir test
        # kirmizi olmadi, cunku hicbir test "kim cagirabilir" diye
        # sormuyordu. Sinir 203'te VERI oldu (rpc_client_surface);
        # burasi o verinin bir daha sessizce esnememesini saglar.
        ("RPC yuzeyi ihlali (istemciye acik olmamasi gereken fonksiyon)",
         "select fn_name || ' -> ' || neden from public.rpc_surface_violations()"),

        # 🔴 v2.77 — TERS YON: "ACIK OLMASI GEREKEN KAPALI MI?"
        # Yukaridaki degismez yalniz BIR YONU olcuyordu: "acik olmamasi
        # gereken acik mi?". Bu turda SQL 212 uc yeni istemci
        # fonksiyonu yazdi (client_flags, i18n_overrides, i18n_version)
        # ve `rpc_client_surface` beyaz listesine eklemeyi UNUTTUM.
        # `apply_rpc_surface()` uculu de kapatti; olcum:
        #     client_flags → authenticated EXECUTE = f
        # Sonuc: uygulama acilista 42501 alirdi, bayraklar hic gelmezdi,
        # yani "acil kapatma dugmesi" kablosu kesik bir dugme olurdu.
        # Butun degismezler YESIL yanarken.
        #
        # Bir sinir denetimi tek yonlu ise, yarim denetimdir. Bu satir
        # obur yarisi: beyaz listede olup da CAGRILAMAYAN fonksiyon.
        ("Yuzeyde YAZILI ama istemciye KAPALI fonksiyon (uygulama 42501 alir)",
         """select s.fn_name || ' -> ' || s.client || ' istemcisi icin acik degil'
              from rpc_client_surface s
              join pg_proc p on p.proname = s.fn_name
              join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
             where not has_function_privilege(
                     case s.client when 'public_web' then 'anon' else 'authenticated' end,
                     p.oid, 'EXECUTE')"""),

        # 🔴 v2.71 — ENGELLEME KOZMETIK OLMASIN.
        # `blocks` tablosu vardi ama SADECE uc listeleme yuzeyi okuyordu;
        # istek/baglanti/davet yazma yollarinin HICBIRI bakmiyordu.
        # 204 bunu tetikleyiciye tasidi; bu satir tetikleyicinin
        # silinmedigini ve listeleme sarmalayicilarinin durdugunu kontrol
        # eder.
        ("Engelleme uygulanmayan yazma/okuma yolu",
         "select tablo || ': ' || neden from public.blok_kapsam_denetimi()"),

        # 🔴 v2.74 — TUTULMAYAN SOZ DENETIMI.
        # 206'da `host_tiers`e uc ayricalik yazdim (siralama, bedava
        # istek, ekstra slot) ve UCUNU DE baglamadan biraktim. Ustelik
        # o ayricaliklarin METNI `host_standing()` uzerinden kullaniciya
        # gosteriliyordu: urun yapmadigi seyi soyluyordu.
        # Kendi nobetcim beni yakalayamadi cunku fonksiyonun DEGER
        # URETTIGINI kanitliyordu, o degerin KULLANILDIGINI degil.
        ("Host mertebesinde TUTULMAYAN soz (tanimli ama uygulanmiyor)",
         "select mertebe || '.' || soz || ': ' || neden from public.tier_promise_check()"),

        # ============================================================
        # 🔴 v2.78 — HATA SINIFI 21: "SONRAKI DOSYA, ONCEKININ
        # CAGIRICILARINI BOZDU."
        # ============================================================
        # OLCULEN OLAY: 209 `partner_gate(uuid,uuid) returns UUID` yazdi
        # ve ayni dosyadaki BES fonksiyon `v_uid := partner_gate(...)`
        # dedi (`v_uid uuid`). 212 ayni kapiyi sarmaladi ve sarmalayiciyi
        # `returns BOOLEAN` yazdi. Calisma zamani:
        #     22P02  invalid input syntax for type uuid: "f"
        # Saglayici panelinin BES ekrani birden dustu.
        #
        # HICBIR NOBETCI YAKALAMADI cunku her dosya KENDI ANINDA
        # dogruydu: 209'un nobetcileri 209 calisirken gecti (212 daha
        # yoktu), 212'ninkiler de gecti (209'un cagiricilarina kimse
        # bakmadi). returns_check.py ve wrapper_check.py DOSYA okur; bu
        # soru ancak MIGRATIONLARIN TAMAMI CALISTIKTAN SONRA, gercek
        # katalog uzerinden sorulabilir. Dogru yer tam olarak burasi.
        #
        # Bu iki degismez `sozlesme_check.py`ye devrediyor: SQL ile
        # yazilabilirdi ama govde ayristirmasi (DECLARE bolumu, atama
        # baglami) Python'da okunur ve mutasyonla sinanabilir kaliyor.
        ("Cagirici sozlesmesi BOZULMUS (v_x := f() donus tipiyle uyusmuyor)",
         lambda: sozlesme_check.cagirici_sozlesmesi(kopyala)),

        # Sarmalayicinin OBUR YARISI: 212 ayrica `return
        # partner_gate_preflag(...)` diyordu ve preflag UUID donuyordu.
        # plpgsql govdeleri OLUSTURMA aninda tip denetiminden GECMEZ —
        # migration yesil yanar, hata ancak CAGRILINCA cikar.
        # ⚠️ Duz "prorettype esit mi" DEGIL: bugun partner_gate boolean,
        # partner_gate_preflag uuid ve bu DOGRU (213 farki bilerek
        # uyarliyor). Olcut "tip farkli mi" degil, "fark CEVRILMEDEN
        # kullaniliyor mu".
        ("Sarmalayici delegeyi DOGRUDAN donduruyor ama donus tipi FARKLI",
         lambda: sozlesme_check.sarmalayici_delege(kopyala)),

        # ============================================================
        # 🔴 v2.78 — HATA SINIFI 22: "SINIR DENETIMI TEK YONLUYSE
        # YARIM DENETIMDIR." Asagidaki dortu, var olan denetimlerin
        # OLCULMUS eksik yarilaridir.
        # ============================================================
        # (1) 159 su sinifi olcmustu: "politika var, GRANT yok". RPC'ler
        # security definer oldugu icin E2E'ler yesildi; app'in DOGRUDAN
        # tablo sorgulari canlida permission denied alip SESSIZCE bos
        # donuyordu (ana sayfa "Bekleyen" sayaci hep 0). 159 bunu 24
        # tablo adini ELLE yazarak kapatti ve kendi bekcisi de yalniz O
        # LISTEYI kontrol ediyor — yani yazildigi gunun fotografi.
        # App'e bugun yeni bir `.from("x")` eklenirse hicbir sey kirmizi
        # yanmaz. Bu satir listeyi HER KOSUDA kaynaktan yeniden uretir.
        # NOT: ters yonu ("politika var ama GRANT yok") ham haliyle
        # EKLEMEDIM: 29 tablo doner ve neredeyse hepsi bilerek yalniz
        # RPC uzerinden okunuyor (security definer GRANT istemez).
        # Yanlis alarm veren denetim, olmayan denetimden kotudur.
        ("App'in DOGRUDAN sorguladigi tabloda GRANT YOK (canlida 42501)",
         lambda: sozlesme_check.app_tablo_haklari(kopyala, app_kaynak_dosyalari())),

        # (2) RLS denetiminin OBUR YONU. 060/140 "RLS acik mi, politika
        # var mi" diye soruyor; kimse "istemciye ACILMIS ama satir
        # filtresi YOK" diye sormuyordu. Bu durumda politika sayisi
        # dogru, RLS raporu yesil, ama o tabloda authenticated HERKESIN
        # satirini okur/yazar. Guvenlik iki katman: RLS karar verir,
        # GRANT kapiyi acar — ikisini de AYNI anda sormak gerekir.
        # 🔴 22 AGUSTOS DUZELTMESI — BU NOBETCI EN GUVENLI AYARI SUCLUYORDU.
        # Kosul "RLS kapali VEYA politika yok" idi. Ikinci sik YANLIS:
        # RLS ACIK + politika YOK, Postgres'te "herkese kapali" demektir —
        # yani mumkun olan EN SIKI filtre. Nobetci bunu "filtre yok" diye
        # raporlayinca promo_codes, audit_log ve otp_tokens her kosuda
        # sahte alarm veriyordu; uc sahte alarmin yanindaki GERCEK alti
        # bulgu (RLS gercekten KAPALI olan tablolar) gurultude kayboldu.
        #
        # 🆕 SINIF: "BIR NOBETCI, EN GUVENLI AYARI KUSUR SAYIYORSA,
        # GERCEK KUSURU KENDI GURULTUSUNE GOMER."
        ("Istemciye ACIK ama satir filtresi OLMAYAN tablo (RLS KAPALI)",
         """select c.relname || ' · ' || r.rol || ' ' || a.act || ' verilmis, RLS KAPALI'
              from pg_class c
              join pg_namespace n on n.oid = c.relnamespace,
                   (values ('anon'),('authenticated')) r(rol),
                   (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) a(act)
             where n.nspname = 'public' and c.relkind = 'r'
               and not c.relrowsecurity
               and case when a.act = 'DELETE'
                        then has_table_privilege(r.rol, c.oid, a.act)
                        else has_any_column_privilege(r.rol, c.oid, a.act) end"""),

        # (3) TETIKLEYICI DENETIMININ OBUR YONU. "Tetikleyici duruyor
        # mu" diye soran denetimler var (204, 212, 169); "yazilmis ama
        # HIC BAGLANMAMIS tetikleyici fonksiyonu" diye soran yoktu.
        # 162'de tam bu oldu: `founding_badge_sync()` yazildi, baglama
        # blogu `if to_regclass('public.founding_hosts') is not null`
        # kosuluna sarilmisti, tablo hic var olmadi ve tetikleyici
        # SESSIZCE kurulmadi. Ayni sessiz-atlama sinifi (107 dersi),
        # bu sefer DDL'de.
        ("Tetikleyici fonksiyonu YAZILMIS ama hicbir tetikleyiciye BAGLI degil",
         # 🔴 KARARA BAGLANMIS OLU KOD, BULGU DEGILDIR (v2.78).
         # `founding_badge_sync` bu denetimin ilk kurbaniydi ve
         # ARASTIRILDI: `founding_hosts` tablosu hic olusmadi, kurucu
         # rozet numarasini `claim_founding_host` zaten kendisi yaziyor,
         # yani fonksiyon zararsiz olu kod. SQL 214 bunu `comment on
         # function` ile YAZILI olarak isaretledi.
         #
         # Denetimin sordugu sey "unutulmus mu" — "biliniyor mu" degil.
         # Bu yuzden olcut fonksiyonun COMMENT'i: karari yazili olan
         # atlanir, yazili olmayan kirmizi yanar. Boylece denetim
         # susturulmuyor, KARAR TALEP EDIYOR. Allowlist'e ad yazmak
         # olsaydi bir dahakine ad eklemek yeterdi; burada gerekce
         # kod tabanina yazilmak zorunda.
         """select p.proname || ' — trigger donuyor, hicbir tabloya bagli degil'
              from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
               and not exists (select 1 from pg_trigger g
                                where g.tgfoid = p.oid and not g.tgisinternal)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not ilike '%KULLANILMIYOR%'"""),

        # (4) VARLIK denetiminin OBUR YONU: tetikleyici VAR ama DEVRE
        # DISI. `alter table ... disable trigger` katalogda tetikleyiciyi
        # BIRAKIR; "var mi" diye soran her denetim yesil yanar, oysa
        # tetikleyici hic calismaz. Sessiz kapatma en pahali kapatmadir.
        ("Tanimli ama DEVRE DISI tetikleyici (hic calismaz)",
         """select c.relname || '.' || g.tgname || ' devre disi ('
                 || g.tgenabled::text || ')'
              from pg_trigger g
              join pg_class c on c.oid = g.tgrelid
              join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and not g.tgisinternal
               and g.tgenabled::text <> 'O'"""),
    ]
    print()
    print('-' * 72)
    print('SESSIZ ATLAMA DENETIMI — migration temiz calisti ama veri tutarli mi?')
    print('-' * 72)
    warn = 0
    for label, kaynak in INVARIANTS:
        hit = ''
        if callable(kaynak):
            # 🔴 v2.78 — PYTHON DEGISMEZI. Cokerse SUSMAK YASAK: bir
            # istisnayi yutup bos liste dondurmek, denetimi yesil yakan
            # bir yalandir. Cokme de bir ihlaldir.
            try:
                satirlar = kaynak()
            except Exception as e:
                satirlar = [f'DENETIM COKTU: {type(e).__name__}: {e}']
            hit = ', '.join(str(s) for s in satirlar)
        else:
            # -t (tuples only) olmadan psql BASLIK satirini da basiyordu ve
            # 'string_agg' kelimesini sonuc saniyordu — denetim her seferinde
            # 6 ihlal uyduruyordu. Kendi ciktisini okuyamayan bir denetim,
            # olmayan bir denetimden kotudur: yanlis alarm uretir.
            r = psql(uri, f"select coalesce(string_agg(x::text, ', '), '') from ({kaynak}) t(x);",
                     tuples=True)
            # 🔴 v2.78 — SESSIZ YESIL DELIGI KAPANDI.
            # Sorgunun KENDISI hata verirse (yazim hatasi, silinmis
            # tablo, degismis kolon adi) stdout BOS gelir ve eski dongu
            # bunu "ihlal yok" sayip ✓ basiyordu. Yani bozulan bir
            # degismez, bozuldugu andan itibaren SONSUZA KADAR yesil
            # yanardi. Cikis kodu artik okunuyor.
            if r.returncode != 0:
                err = [l for l in (r.stderr or '').splitlines() if 'ERROR' in l]
                hit = 'DENETIM SORGUSU CALISMADI: ' + (err[0].strip() if err
                                                       else (r.stderr or '?').strip()[:160])
            else:
                for line in (r.stdout or '').splitlines():
                    line = line.strip()
                    if not line or line.startswith('(') or set(line) <= set('-+'):
                        continue
                    if line == 'coalesce' or line == 'string_agg':
                        continue
                    hit = line
                    break
        if hit:
            warn += 1
            print(f'  ⚠ {label}:')
            print(f'      {hit[:220]}')
        else:
            print(f'  ✓ {label}')
    # Kac sey OLCULDUGUNU yaz. Sifir satir olcup "temiz" demek bu
    # depodaki en pahali hata sinifi (bkz. ll_paths.py basligi); sayilar
    # gorunmezse bir denetimin bosalttigi anlasilmaz.
    print(f'\n  OLCUM (sozlesme): {sozlesme_check.OLCUM}')

    # 🔴 SIRALAMA BILINCLI: canli cagri gecisi DEGISMEZLERDEN SONRA.
    # Fikstur veri UYDURUYOR (bekleyen talep, puanlanmamis oturum,
    # anonimlestirilmis kullanici...). O veri, 'sessiz atlama'
    # degismezlerinin olctugu tabloya karisirsa denetim kendi
    # uydurdugu satiri gercek veri sanip yanlis alarm — ya da daha
    # kotusu, yanlis SESSIZLIK — uretir. Once gercek seed olculur,
    # sonra fikstur kurulur.
    # ============================================================
    # 🔴 CANLI CAGRI GECISI — "SATIR VARKEN DE TUTUYOR MU"
    # ============================================================
    # 18 Agustos 2026, Gokberk canlida IKI KEZ ayni hatayi aldi (186:
    # character(3) vs text, sonra smallint vs integer). Ikisi de burada
    # YESIL yandi, cunku `returns table` tip sozlesmesini PostgreSQL
    # yalniz BIR SATIR DONDUGUNDE dogruluyor ve nobetciler bos tabloda
    # kosuyordu.
    #
    # ⚠️ ILK COZUMUM YANLISTI VE GERI ALDIM: butun migration'lari bir kez
    # daha calistirmayi denedim. 17 dosya patladi, hicbiri gercek degildi
    # (eski migration yeni semanin uzerine kosuluyordu; dahasi filtrem
    # 087a'yi calistirip 087'yi atlayarak lounge_access_decision_v2'yi
    # veritabanindan SILIYORDU). Ustelik ardindan gelen 26 degismezin
    # 6'sini bozdu. Gerekce ve olcum: canli_cagri.py dosya basligi.
    #
    # Dogru enstruman DDL'i tekrarlamak degil, NOBETCILERE SATIR VERMEK.
    if not fails and not os.environ.get('LL_TEK_GECIS'):
        print()
        print('-' * 72)
        print('CANLI CAGRI GECISI — her fonksiyon GERCEK SATIRLA cagriliyor')
        print('-' * 72)
        # 🔴 ONCE DURUM URET. Olctum: SEED'ler tek `request` uretiyor ve o
        # da `completed`. `my_sent_requests()` yalniz pending/accepted
        # okuyor — yani canlida patlayan fonksiyonun okudugu durum bu
        # veritabaninda HIC OLUSMAMISTI. Fikstur bir MIGRATION DEGILDIR,
        # kuruluma girmez; sadece nobetcilere satir verir.
        fx = os.path.join(_HERE, 'canli_fikstur.sql')
        if os.path.exists(fx):
            rf = psql(uri, file=fx)
            if rf.returncode != 0:
                hd = next((l.strip() for l in rf.stderr.splitlines()
                           if 'ERROR' in l), rf.stderr[:160])
                print(f'  ⚠ fikstur kurulamadi → {hd[:200]}')
                print('     (gecis yine kosacak ama kapsam DAR olacak)')
            else:
                for l in (rf.stderr or '').splitlines():
                    if 'NOTICE' in l and 'fikstur' in l:
                        print(f'  {l.strip()[:200]}')
        else:
            print('  ⚠ canli_fikstur.sql bulunamadi — kapsam dar')
        try:
            _, _, cagri_hatalari = canli_cagri.gecis(psql, uri)
        except Exception as e:              # noqa: BLE001
            print(f'  ⚠ canli cagri gecisi calistirilamadi: {e}')
            cagri_hatalari = []
        tip = [h for h in cagri_hatalari if h['kod'] == '42804']
        if tip:
            fails.extend([(f"{h['ad']}() · 42804", h['hata']) for h in tip])

    if warn:
        print(f'\n  {warn} degismez ihlali. Bunlar HATA vermez ama VERI EKSIKTIR:')
        print('  kullanici bos liste gorur, kural motoru hic devreye girmez.')
        print('  (sozlesme/sinir ihlallerinde ise: uygulama 22P02 ya da 42501 alir.)')

    # ════════════════════════════════════════════════════════════════
    # 🔴 19 AGUSTOS — TEKRAR KURULUM DENETIMI
    #
    # BU HARNESS'IN KOR NOKTASI: her zaman BOS bir veritabanina, dosya
    # sirasiyla kuruyor. Canli veritabani ise bir SIRA degil bir DURUM —
    # Gokberk turu bir kez kurdu, sonra 219'dan yeniden basladi ve
    # 42P13 aldi. Burada 255 dosya "temiz" diyordu.
    #
    # Yakalanan iki gercek kusur:
    #   219 · discovery_rule_badges `create or replace` (221 onu 9
    #         kolona cikariyor) → 42P13
    #   220 · tr/en madde sayisi nobetcisi, 225 kart satirini sildikten
    #         SONRA yeniden kosulunca yanlis yere yaniyordu
    #
    # Olcum: temiz kurulum bittikten sonra SON TUR dosyalari AYNI
    # veritabaninda bir kez daha kosulur. Patlarsa migration tekrar
    # kurulabilir degildir ve bunu Gokberk'in ogrenmesine gerek yok.
    # ════════════════════════════════════════════════════════════════
    tekrar_hatalari = []
    if not fails:
        son_tur = [f for f in files if f[:3].isdigit() and int(f[:3]) >= TEKRAR_ESIK]
        son_tur += list(seeds)
        if son_tur:
            def _kolon_snapshot():
                r = psql(uri, "select p.proname || ':' || "
                              "coalesce(array_length(p.proallargtypes,1),0) "
                              "from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
                              "where n.nspname='public'", tuples=True)
                d = {}
                for satir in (r.stdout or '').splitlines():
                    if ':' in satir:
                        ad, _, n = satir.rpartition(':')
                        try: d[ad.strip()] = int(n)
                        except ValueError: pass
                return d
            _once_kolon = _kolon_snapshot()
            print(f'\n  TEKRAR KURULUM: son {len(son_tur)} dosya ayni veritabaninda '
                  f'bir kez daha kosuluyor ({TEKRAR_ESIK}+)...')
            for f in son_tur:
                # 🔴 Kurulumla AYNI yol kullanilir: psql(uri, file=...) — o
                # helper `-1` ile tek islem sariyor, yani Supabase SQL
                # Editor'un ortami. Ilk yazimda `srv.psql()` cagirdim ve 11
                # dosyanin 11'i "cikis 3" verdi; hata metnini de tasimiyordu.
                # Yani nobetci bir sey OLCMUYOR, sadece kirmizi yaniyordu —
                # bu projede tam olarak kacindigimiz sey.
                r = psql(uri, file=os.path.join(sql_dir, f), quiet=True)
                if r.returncode != 0:
                    ilk = next((l.strip() for l in (r.stderr or '').splitlines()
                                if 'ERROR' in l), (r.stderr or '').strip()[:160])
                    tekrar_hatalari.append((os.path.basename(f), ilk))
            # 🔴 20 AGUSTOS · GERILEME OLCUMU
            # 158'e `drop` ekleyince 42P13 sustu ama dosya fonksiyonu
            # 12 dosya ONCEKI haline GERI DUSURDU (31 kolon -> 23) ve
            # bunu kimse gormedi: dosya "basarili" donuyordu.
            # Artik tekrar kurulumdan ONCE ve SONRA her fonksiyonun
            # cikti kolonu sayilir; AZALAN varsa gerileme vardir.
            # Bir hatayi susturmak, onu cozmek degildir.
            gerileme = []
            _sonra_kolon = _kolon_snapshot()
            for ad, once in _once_kolon.items():
                simdi = _sonra_kolon.get(ad)
                if simdi is not None and simdi < once:
                    gerileme.append(f'{ad}() {once} -> {simdi} kolon')
            if gerileme:
                print(f'  ✗ GERILEME — tekrar kurulum {len(gerileme)} fonksiyonu '
                      f'ESKI haline dusurdu:')
                for g in gerileme:
                    print(f'     {g}')
                print('     Eski bir migration, kendinden YENI bir hali EZEMEZ.')
                tekrar_hatalari.append(('GERILEME', ', '.join(gerileme)))

            if tekrar_hatalari:
                print(f'  ✗ TEKRAR KURULUMDA {len(tekrar_hatalari)} dosya patladi:')
                for ad, hata in tekrar_hatalari:
                    print(f'     {ad}  {hata}')
                print('     Bu dosyalar YALNIZ bos veritabaninda calisiyor.')
                print('     Canlida tur ikinci kez kurulunca ayni hatayi verecekler.')
            else:
                print(f'  ✓ tekrar kurulum temiz — {len(son_tur)} dosya iki kez kosulabiliyor')

            # ============================================================
            # 🔴 ESKI MIGRATION KORUMASI — 21 Agustos
            #
            # Yukaridaki gerileme olcumu YALNIZ 219+ dosyalari icin
            # kosuyor. Oysa bu projede iki kez canliyi bozan sey ESKI bir
            # dosyanin tek basina calistirilmasiydi:
            #   158 -> discover_availabilities 31 kolondan 23'e dustu
            #          (guest_policy kayboldu, SEED4 patladi, uygulamada
            #           kural rozetleri kayboldu)
            #   183 -> lounges_for_airport 10'dan 8'e dusuyordu
            #          (section/display_name kayboluyordu)
            # Ikisine de "canlidaki tanim daha genisse DOKUNMA" korumasi
            # kondu. Ama koruma yazmak, korumanin CALISTIGINI kanitlamaz.
            #
            # 🆕 SINIF: "BIR KORUMA, CALISTIGI OLCULMEDIKCE BIR NIYETTIR."
            # Bu gecis o dosyalari kurulu veritabaninda TEK BASINA
            # kosturur ve tek bir kolonun bile azalmadigini olcer.
            KORUMALI_ESKILER = ['158_device_findings.sql',
                                '183_lounges_rpc_and_grants.sql']
            _k_once = _kolon_snapshot()
            print(f'\n  ESKI MIGRATION KORUMASI: {len(KORUMALI_ESKILER)} korumali eski '
                  f'dosya kurulu veritabaninda tek basina kosuluyor...')
            _k_hata = []
            for f in KORUMALI_ESKILER:
                yol = os.path.join(sql_dir, f)
                if not os.path.exists(yol):
                    _k_hata.append((f, 'DOSYA YOK'))
                    continue
                r = psql(uri, file=yol, quiet=True)
                if r.returncode != 0:
                    ilk = next((l.strip() for l in (r.stderr or '').splitlines()
                                if 'ERROR' in l), (r.stderr or '').strip()[:160])
                    _k_hata.append((f, ilk))
            _k_sonra = _kolon_snapshot()
            _k_ger = []
            for ad, once in _k_once.items():
                simdi = _k_sonra.get(ad)
                if simdi is not None and simdi < once:
                    _k_ger.append(f'{ad}() {once} -> {simdi} kolon')
            if _k_ger or _k_hata:
                for ad, hata in _k_hata:
                    print(f'  ✗ {ad}  {hata}')
                for g in _k_ger:
                    print(f'  ✗ KORUMA DELINDI — {g}')
                if _k_ger:
                    print('     Eski bir migration, kendinden YENI bir hali EZEMEZ.')
                fails.append(('ESKI_MIGRATION_KORUMASI',
                              ', '.join(_k_ger) or ', '.join(a for a, _ in _k_hata)))
            else:
                print(f'  ✓ koruma calisiyor — {len(KORUMALI_ESKILER)} eski dosya kosuldu, '
                      f'HICBIR fonksiyon kolon kaybetmedi')

    print()
    print('=' * 72)
    if fails:
        print(f'✗ {len(fails)} dosya hata verdi:')
        for f, e in fails:
            print(f'   {f}')
        print('\nBu hatalar CANLIDA da aynen cikardi. Burada yakalandi.')
    elif tekrar_hatalari:
        print(f'✗ {len(tekrar_hatalari)} dosya TEKRAR kurulumda hata verdi '
              f'(ilk kurulum temizdi).')
    else:
        print(f'✓ {len(files) + len(seeds)} dosya BASTAN SONA temiz calisti '
              f'(tekrar kurulum dahil).')
    print('=' * 72)

    if keep:
        open('/tmp/ll_pguri', 'w').write(uri)
        print(f'\nVeritabani duruyor. Sorgu icin:\n  {BIN}/psql "{uri}" -c "select ..."')
    else:
        srv.cleanup()
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
