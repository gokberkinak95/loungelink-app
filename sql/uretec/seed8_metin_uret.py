#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
seed8_metin_uret.py — SEED8 raporunun "uygulamada görünen" sütununu
UYGULAMANIN KENDİ SÖZLÜĞÜNDEN üretir.

🔴 NEDEN VAR — 23 Eylül. Gökberk raporda `fully_booked`,
`contact_not_verified` gibi kodları gördü ve "kullanıcı bunları mı
görüyor?" diye sordu. Hayır — ama rapor bunu söylemiyordu. Artık her kodun
yanında kullanıcının TR ekranda gördüğü cümle var. Cümleyi elle yazmıyoruz:
`rnapp/src/i18n.js` → `mapErr(D.tr, kod)` gerçekten koşturuluyor; sözlük
değişince bu betik yeniden koşulur ve rapor kendiliğinden düzelir.

KULLANIM:  python3 uretec/seed8_metin_uret.py   (sql/ klasöründen)
"""
import os, re, sys
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(os.path.dirname(KOK), "rnapp")
os.environ.setdefault("LL_SQL_DIR", KOK)
sys.path.insert(0, APP)
import ham_kod_check as h  # noqa: E402

SEED = os.path.join(KOK, "SEED8_AKIS_TEZGAHI.sql")
BAS, SON = "-- >>> kod_metni (üretildi: uretec/seed8_metin_uret.py — ELLE DEĞİŞTİRME)", "-- <<< kod_metni"

kodlar = h.kodlar()
o = h.node_olc(kodlar)
satirlar = []
for k in kodlar:
    m = o["harita"]["tr:" + k][0]
    satirlar.append("    when '%s' then '%s'" % (k, m.replace("'", "''")))
blok = "\n".join([
    BAS,
    "-- Kullanıcının TÜRKÇE ekranda gördüğü cümle (mapErr · src/i18n.js). %d kod." % len(kodlar),
    "create or replace function tezgah.kod_metni(p text) returns text language sql immutable as $$",
    "  select case p",
    *satirlar,
    "    else '%s' end" % o["harita"]["tr:__genel"].replace("'", "''"),
    "$$;",
    SON,
])
s = open(SEED, encoding="utf-8").read()
if BAS in s:
    s = re.sub(re.escape(BAS) + r".*?" + re.escape(SON), lambda _: blok, s, flags=re.S)
else:
    a = "create table if not exists tezgah.rapor ("
    assert s.count(a) == 1
    s = s.replace(a, blok + "\n\n" + a, 1)
open(SEED, "w", encoding="utf-8").write(s)
print("SEED8 · tezgah.kod_metni üretildi · %d kod" % len(kodlar))
