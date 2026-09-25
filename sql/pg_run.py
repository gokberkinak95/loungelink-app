#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · pg_run.py

Yerel Postgres replikasinda 001..NNN dosyalarini SIRAYLA calistirir.
Supabase'in `auth`, `storage` semalarini ve `auth.uid()` gibi
fonksiyonlarini taklit eden bir on-yukleme (bootstrap) uygular.

Kullanim:
  python3 pg_run.py --reset            → veritabanini sifirdan kurar
  python3 pg_run.py 248                → tek dosyayi yeniden calistirir
  python3 pg_run.py --from 240         → 240'tan sonuna kadar
"""
import argparse
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
DB = "ll"

BOOTSTRAP = r"""
create schema if not exists auth;
create schema if not exists storage;
create schema if not exists extensions;
-- 🔴 pgcrypto SUPABASE'TE `extensions` SEMASINDA DURUR, public'te DEGIL.
-- public'e kurarsak 187a gibi "asiri yukleme temizligi" dosyalari
-- pgcrypto'nun overload'larini BIZIM fonksiyonumuz sanar. Taklidin
-- yeri, taklidin kendisi kadar onemli.
create extension if not exists pgcrypto schema extensions;
create extension if not exists "uuid-ossp" schema extensions;

do $$ begin
  create role anon nologin;
exception when duplicate_object then null; end $$;
do $$ begin
  create role authenticated nologin;
exception when duplicate_object then null; end $$;
do $$ begin
  create role service_role nologin bypassrls;
exception when duplicate_object then null; end $$;
do $$ begin
  create role supabase_auth_admin nologin;
exception when duplicate_object then null; end $$;

-- 25 EYLÜL — bu satır rollerden ÖNCE duruyordu; temiz bir kümede
-- `role "anon" does not exist` ile bootstrap düşüyordu.
grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;

-- Supabase auth.users'in GERCEK kolon kumesi. Eksik kolon = sahte yesil:
-- 073 gibi dosyalar bu kolonlara yaziyor; taklidi dar tutarsak dosya
-- yerelde patlar, canlida gecerdi (ya da tersi).
create table if not exists auth.users (
  instance_id uuid default '00000000-0000-0000-0000-000000000000',
  id uuid primary key default gen_random_uuid(),
  aud varchar(255) default 'authenticated',
  role varchar(255) default 'authenticated',
  email varchar(255),
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  invited_at timestamptz,
  confirmation_token varchar(255) default '',
  confirmation_sent_at timestamptz,
  recovery_token varchar(255) default '',
  recovery_sent_at timestamptz,
  email_change_token_new varchar(255) default '',
  email_change varchar(255) default '',
  email_change_sent_at timestamptz,
  last_sign_in_at timestamptz,
  raw_app_meta_data jsonb default '{}'::jsonb,
  raw_user_meta_data jsonb default '{}'::jsonb,
  is_super_admin boolean,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  phone varchar(255) unique,
  phone_confirmed_at timestamptz,
  phone_change varchar(255) default '',
  phone_change_token varchar(255) default '',
  phone_change_sent_at timestamptz,
  confirmed_at timestamptz,
  email_change_token_current varchar(255) default '',
  email_change_confirm_status smallint default 0,
  banned_until timestamptz,
  reauthentication_token varchar(255) default '',
  reauthentication_sent_at timestamptz,
  is_sso_user boolean default false,
  deleted_at timestamptz,
  is_anonymous boolean default false
);
create table if not exists auth.identities (
  provider_id text, user_id uuid references auth.users(id) on delete cascade,
  identity_data jsonb, provider text, last_sign_in_at timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  email text, id uuid primary key default gen_random_uuid()
);
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    ), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    current_setting('request.jwt.claim.role', true),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    'anon')
$$;

create or replace function auth.email() returns text
language sql stable as $$
  select coalesce(
    current_setting('request.jwt.claim.email', true),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email'))
$$;

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb,
                  '{}'::jsonb)
$$;

grant execute on all functions in schema auth to anon, authenticated, service_role;

create publication supabase_realtime;

alter database ll set search_path to "$user", public, extensions;

-- 🔴 SUPABASE'IN VARSAYILANI. 241 ve 253 bunlari KISITLIYOR; kisitlamayi
-- olcebilmek icin once ACIK hallerinin var olmasi gerekiyor. Taklidi
-- "guvenli" kurmak, guvenlik dosyalarini olcusuz birakir.
alter default privileges in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to postgres, anon, authenticated, service_role;

create table if not exists storage.buckets (
  id text primary key, name text, public boolean default false,
  created_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text, owner uuid, owner_id text,
  metadata jsonb, path_tokens text[],
  created_at timestamptz default now(), updated_at timestamptz default now()
);
alter table storage.objects enable row level security;
create or replace function storage.foldername(p text) returns text[]
language sql immutable as $fn$
  select (string_to_array(p, '/'))[1:array_length(string_to_array(p,'/'),1)-1]
$fn$;
grant usage on schema storage to anon, authenticated, service_role;
grant all on storage.objects, storage.buckets to service_role;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated, anon;

create schema if not exists net;
create schema if not exists cron;
grant usage on schema net, cron to service_role;

create table if not exists cron.job (
  jobid bigserial primary key, schedule text, command text,
  nodename text default 'localhost', nodeport int default 5432,
  database text default current_database(), username text default current_user,
  active boolean default true, jobname text unique
);
create or replace function cron.schedule(p_name text, p_sched text, p_cmd text)
returns bigint language plpgsql as $fn$
declare v bigint;
begin
  insert into cron.job (jobname, schedule, command) values (p_name, p_sched, p_cmd)
    on conflict (jobname) do update set schedule = excluded.schedule,
                                        command = excluded.command
    returning jobid into v;
  return v;
end $fn$;
create or replace function cron.unschedule(p_name text)
returns boolean language plpgsql as $fn$
begin delete from cron.job where jobname = p_name; return true; end $fn$;

"""


def psql(sql=None, f=None, db=DB, quiet=False):
    cmd = ["psql", "-v", "ON_ERROR_STOP=1", "-X", "-q", "-d", db]
    if f:
        cmd += ["-f", f]
    else:
        cmd += ["-c", sql]
    p = subprocess.run(["su", "postgres", "-c", " ".join(_q(c) for c in cmd)],
                       capture_output=True, text=True)
    return p


def _q(s):
    return "'" + s.replace("'", "'\\''") + "'"


# 🔴 31 AGUSTOS — `--reset` HER SEFERINDE ILK DOSYADA PATLIYORDU.
# `000_HANGI_SQL_KURULU.sql` bir MIGRATION DEGIL, bir RAPOR: semayi
# sorgulayip "hangi dosyalar kurulu" tablosunu dondurur. Numara sirasi
# onu EN BASA koyuyordu; bos bir veritabaninda `beta_settings` daha
# yaratilmamis oluyor ve kosu ilk adimda duruyordu.
#
# Sonucu sessiz degildi ama YANLIS YERE dusuyordu: canli kopya hicbir
# zaman tazelenemedigi icin `drift_check` "205 olasi DUSEN ADIM" diye
# kirmizi yaniyor ve kendi ciktisinda "bu kip SAHTE ALARM uretir"
# diyordu. Yani bir dosya adlandirma kurali, bir denetimi haftalarca
# yalanci yapmis.
#
# 🆕 SINIF: "CALISTIRMA SIRASI DOSYA ADINDAN TURUYORSA, SIRAYA
# GIRMEMESI GEREKEN HER DOSYA ER GEC SIRANIN BASINA GECER."
#
# 268a AYNI SINIFIN IKINCI ORNEGI, ustelik ters yonden: harfli dosyalar
# "PRE" sayilip ANA dosyadan ONCE kosuyor (024a kurali), ama 268a bir PRE
# degil — 268 "durdu" derse ELDE calistirilacak bir OPERATOR ARACI. Sirada
# 268'den once yer aldigi icin, 268'in yeni yarattigi `phone_kanonik`
# kolonunu arayip patliyordu. Yani iki ayri adlandirma kurali (000 = ilk,
# harfli = once) ayni tuzagi iki farkli yerde kurmus.
RAPOR = {
    "000_HANGI_SQL_KURULU.sql",     # salt okunur rapor
    "268a_telefon_cakismasi.sql",   # elde calistirilan operator araci (§A/§B)
}


def files():
    out = []
    for p in sorted(glob.glob(os.path.join(ROOT, "*.sql"))):
        b = os.path.basename(p)
        if b in RAPOR:
            continue
        # 024a_PRE_drop... ANA dosyadan ONCE calisir (KURULUM_SIRASI.md)
        m = re.match(r"^(\d{3})([a-z]?)_", b)
        if m:
            harf = m.group(2)
            oncelik = 0 if harf else 1          # harfli = PRE, once
            out.append((int(m.group(1)), oncelik, harf, b, p))
    out.sort()
    return [(n, b, p) for n, _o, _h, b, p in out]


def reset():
    subprocess.run(["su", "postgres", "-c", f"dropdb --if-exists {DB}"],
                   capture_output=True, text=True)
    r = subprocess.run(["su", "postgres", "-c", f"createdb {DB}"],
                       capture_output=True, text=True)
    if r.returncode:
        print(r.stderr)
        sys.exit(1)
    bp = "/var/lib/postgresql/logs/_bootstrap.sql"
    open(bp, "w").write(BOOTSTRAP)
    os.chmod(bp, 0o644)
    r = psql(f=bp)
    if r.returncode:
        print("BOOTSTRAP HATASI:\n" + r.stderr)
        sys.exit(1)
    print("· bootstrap tamam (auth semasi, roller)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*", help="yalniz bu numaralar")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--from", dest="frm", type=int, default=0)
    a = ap.parse_args()

    if a.reset:
        reset()

    want = {int(x) for x in a.only} if a.only else None
    ok = 0
    fail = []
    for n, b, p in files():
        if want is not None and n not in want:
            continue
        if n < a.frm:
            continue
        r = psql(f=p)
        if r.returncode:
            err = (r.stderr or "").strip().splitlines()
            print(f"✗ {b}")
            for line in [l for l in err if "ERROR" in l or "DETAIL" in l or "CONTEXT" in l][:8] or err[:8]:
                print("   " + line)
            fail.append(b)
            if want is None:
                break
        else:
            ok += 1
            notices = [l for l in (r.stderr or "").splitlines() if "NOTICE" in l]
            tag = ("  " + notices[-1][:90]) if notices else ""
            print(f"✓ {b}{tag}")
    print("=" * 60)
    print(f"{ok} dosya temiz, {len(fail)} hata")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
