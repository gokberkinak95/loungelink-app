#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LoungeLink · canli_cagri.py   (18 Agustos 2026'da dogdu)

🔴 NEDEN VAR — GOKBERK CANLIDA AYNI HATAYI IKI KEZ ALDI:

    186 → ERROR 42804: Returned type character(3) does not match
                       expected type text in column 9
    186 → ERROR 42804: Returned type smallint does not match
                       expected type integer in column 16

Ikisi de pg_run.py'de YESIL yandi. Sebebi tek cumle:

    PostgreSQL `returns table` tip sozlesmesini yalniz BIR SATIR
    DONDUGUNDE dogrular. Sifir satirda hicbir donusum denenmez,
    hicbir hata cikmaz.

186'nin kendi nobetcisi `select count(*) from my_sent_requests()` diyor
ve YESIL yaniyor — cunku o an `requests` tablosunda o kullaniciya ait
pending/accepted satir YOK. Gokberk'in veritabaninda VARDI.

────────────────────────────────────────────────────────────────────
ONCE YANLIS BIR SEY YAPTIM — VE OLCUP GERI ALDIM
────────────────────────────────────────────────────────────────────
Ilk cozumum "butun migration'lari bir kez daha calistir, bu sefer veri
tabloda dururken" idi. 17 dosya patladi ve hepsini "canlida da cikardi"
diye raporladim. YANLISTI. Olctum:

  · 030 `invitable_guests` → 075a onu DUSURUYOR, 030 eski imzayla
    yeniden kuruyor. Yani hata "veri var" diye degil, "ESKI migration
    YENI semanin uzerine tekrar kosuldu" diye cikti.
  · Ayni sinif: 095/145 · 143/154 · 193/201 · 209/213 · 144/187.
  · Daha kotusu: filtrem 087a'yi (v2'yi DROP eden) tekrar calistirip
    087'yi (v2'yi CREATE eden) atliyordu. Sonuc: `lounge_access_decision_v2`
    veritabanindan siliniyor ve 4 dosya "v2 does not exist" diyordu.
    Bu hatayi TAMAMEN BEN URETTIM.
  · Ve ikinci gecis, ardindan kosan 26 degismezin durumunu da bozdu:
    temiz kosuda 26/26 yesil olan denetim, ikinci gecisten sonra 6 uyari
    veriyordu. Yani enstruman olcecegi seyi bozuyordu.

Kimse 217'yi kurduktan sonra 030'u tekrar calistirmaz. Olcum, olcumu
yapan aletin uydurdugu bir dunyayi olcuyordu.

────────────────────────────────────────────────────────────────────
DOGRU ENSTRUMAN
────────────────────────────────────────────────────────────────────
Hedef DDL'i tekrar kosmak degil; hedef, nobetcilerin GERCEK SATIRLARLA
calismasi. O yuzden bu modul:

  1. Butun migration'lar + SEED'ler bittikten SONRA calisir (sema son hali).
  2. Satir donduren her public fonksiyonu SIRAYLA CAGIRIR.
  3. Her cagriyi kendi islemine alir ve ROLLBACK eder — yazan fonksiyonlar
     (create_request, respond_request...) veriyi kirletmez, ama tip
     sozlesmeleri yine de dogrulanir.
  4. `auth.uid()` icin gercek bir SEED kullanicisi takar; arguman
     degerlerini veritabanindaki GERCEK id'lerden uretir.
  5. 🔴 EN ONEMLISI — KAPSAMI YAZAR. Bir fonksiyon 0 satir donduyse
     tip sozlesmesi DOGRULANMAMISTIR ve bu modul bunu "✓" diye
     GOSTERMEZ. "dogrulandi" sayisi ile "cagrildi" sayisi ayri basilir.
     186 tam olarak bu ayrimin yoklugundan gecti.

Bu modulun verdigi garanti: "asagida sayilan N fonksiyon en az bir
satir dondurdu ve tip sozlesmeleri PostgreSQL tarafindan dogrulandi."
Vermedigi garanti: geri kalanlar hakkinda HICBIR SEY.
"""
import json
import re

# Cagirmadigimiz fonksiyonlar. Sebep her satirda YAZILI olmali —
# gerekcesiz atlama, sessiz kapsam kaybidir.
ATLA = {
    # Zamana/dis dunyaya bagli, kosuyu kilitler ya da anlamsiz yan etki
    'pg_stat_statements_reset': 'sistem',
    'delete_my_account': 'hesabi siler — rollback icinde bile auth semasini kirletir',
    'purge_expired_data': 'toplu silme; rollback disi dosya/queue etkisi olabilir',
}

# 🔴 BU FONKSIYONLARDA 0 SATIR DOGRU CEVAPTIR.
# Hepsi "ihlal listesi" donduruyor: bos liste = sistem saglikli.
# Onlari "dogrulanmadi" yiginina atip sayiyi sisirmek, kalan gercek
# bosluklari GIZLER. Ayri sayiliyorlar ama YINE DE "dogrulandi"
# sayilmiyorlar — tip sozlesmeleri gercekten olculmedi ve bunu
# yuvarlamak, bu turda iki kez canliya hata gonderen aliskanligin ta
# kendisi olurdu.
NOBETCI = {
    'blok_kapsam_denetimi', 'card_self_check', 'cns_bekleyenler',
    'determinism_check', 'rpc_surface_violations', 'rule_contamination_check',
    'rule_matrix_test', 'tier_promise_check',
}

# Bu on ekler PostgreSQL/uzanti fonksiyonlaridir, bizim degil.
SISTEM_ON_EK = ('pg_', 'uuid_', 'gen_', 'crypt', 'digest', 'armor', 'dearmor',
                'hmac', 'set_limit', 'show_limit', 'show_trgm', 'similarity',
                'word_similarity', 'strict_word_similarity', 'unaccent')


def _tek(psql, uri, sql):
    r = psql(uri, sql, tuples=True)
    if r.returncode != 0:
        return None
    v = (r.stdout or '').strip().splitlines()
    return v[0].strip() if v and v[0].strip() else None


def demirbas(psql, uri):
    """Argumanlar icin veritabanindaki GERCEK id'leri topla.

    Uydurma uuid uretmek ise yaramaz: fonksiyon `where venue_id = $1`
    diyorsa uydurma id 0 satir dondurur ve tip sozlesmesi yine
    dogrulanmaz. Aradigimiz sey tam olarak SATIR."""
    d = {}
    sor = lambda k, s: d.__setitem__(k, _tek(psql, uri, s))

    # 🔴 HOST SECIMI DE AKTIF TALEBE GORE — OLCTUM.
    # "En cok ilani olan host" diyordum; fikstur de ayni sorguyu yaziyor
    # ama BERABERLIK bozulmasi farkli olabiliyor ve iki taraf FARKLI
    # host seciyordu. Sonuc: `host_requests()` (filtresi
    # `r.host_id = v_uid and r.status in (pending,accepted)`) 0 satir
    # donuyordu — yani host tarafinin ana ekrani hic dogrulanmiyordu.
    sor('host', """
        select h.id from users h
        where exists (select 1 from requests r
                      where r.host_id = h.id
                        and r.status in ('pending','accepted'))
        limit 1""")
    if not d.get('host'):
        sor('host', """
            select h.id from users h
            where exists (select 1 from availabilities a where a.host_id = h.id)
            order by (select count(*) from availabilities a where a.host_id = h.id) desc
            limit 1""")
    # 🔴 "TALEBI OLAN KULLANICI" YETMIYOR — OLCTUM.
    # Ilk surum "en cok talebi olan" diyordu ve `completed` talebi olan
    # kullaniciyi secti. `my_sent_requests()` ise yalniz pending/accepted
    # okuyor → 0 satir → sozlesme yine dogrulanmadi. Yani enstruman,
    # yakalamak icin yazildigi fonksiyonun ustunden bir kez daha gecti.
    # Artik AKTIF talebi olan kullanici oncelikli.
    sor('guest', """
        select g.id from users g
        where exists (select 1 from requests r
                      where r.guest_id = g.id
                        and r.status in ('pending','accepted'))
        limit 1""")
    if not d.get('guest'):
        sor('guest', """
            select g.id from users g
            where exists (select 1 from requests r where r.guest_id = g.id)
            limit 1""")
    # Ikinci misafir: BASKA durumdaki talebi olan (kabul edilmis gibi).
    sor('guest2', """
        select g.id from users g
        where exists (select 1 from requests r where r.guest_id = g.id)
          and g.id is distinct from (
            select g2.id from users g2
            where exists (select 1 from requests r2
                          where r2.guest_id = g2.id
                            and r2.status in ('pending','accepted'))
            limit 1)
        limit 1""")
    sor('user', "select id from users order by created_at limit 1")
    # Venue: FIYAT LISTESI de olan bir venue sec — `venue_price_list`
    # aksi halde bos donuyordu (venue_prices'ta 34 satir VAR, sadece
    # sectigim venue'de yoktu).
    sor('venue', """
        select v.id from lounge_venues v
        where exists (select 1 from lounge_venue_acceptance x
                      where x.venue_id = v.id and x.active)
          and exists (select 1 from venue_prices p
                      where p.venue_id = v.id and p.active)
        limit 1""")
    if not d.get('venue'):
        sor('venue', """
            select v.id from lounge_venues v
            where exists (select 1 from lounge_venue_acceptance x
                          where x.venue_id = v.id and x.active)
            limit 1""")
    # 🔴 "HERHANGI BIR AKTIF SALON" YETMIYOR — OLCTUM.
    # `venue_partners(p_lounge_id)` salonun venue'sunde AKTIF ORTAK,
    # `card_advice_for_lounge(p_lounge_id)` ise AKTIF KABUL satiri ariyor.
    # Rastgele secilen salonda ikisi de yoktu ve iki fonksiyon da 0 satir
    # donup "dogrulanmadi" yiginina dusuyordu — veri eksikligi degil,
    # BENIM ARGUMAN SECIMIM yuzunden. Ikisini birden karsilayan salon var
    # (olctum: 2 tane), onu seciyoruz.
    sor('lounge', """
        select l.id from lounges l
        join lounge_venues v on v.id = l.venue_id
        where l.active
          and exists (select 1 from lounge_venue_partners vp
                       where vp.venue_id = v.id and vp.active)
          and exists (select 1 from lounge_venue_acceptance a
                       where a.venue_id = v.id and a.active and a.accepted)
        limit 1""")
    if not d.get('lounge'):
        sor('lounge', "select id from lounges where active limit 1")
    sor('availability', "select id from availabilities order by avail_date desc limit 1")
    sor('request', "select id from requests limit 1")
    sor('program', "select id from lounge_programs where active limit 1")
    sor('card', "select id from user_cards limit 1")
    sor('partner', "select id from users where role = 'host' limit 1")
    sor('thread', "select id from requests where status = 'accepted' limit 1")
    # Yonetici kimligi: RLS'i asan yollarin da satir dondurmesi icin.
    sor('staff', "select id from users where coalesce(is_staff,false) limit 1")
    # Metin argumanlari icin GERCEK degerler — null vermek 0 satir demek.
    # 🔴 PROGRAM KODU: alfabetik ilk kodu aliyordum (BANK_CARD) ama
    # `plan_options(p_program_code)` yalniz `program_plans`ta karsiligi
    # olan kodlarda satir donduruyor (PRIORITY_PASS · DRAGONPASS).
    # Once PLANI OLAN kodu deniyoruz.
    sor('program_code', """
        select p.code from lounge_programs p
        where p.active and exists (select 1 from program_plans pl
                                   where pl.active and pl.program_code = p.code)
        order by p.code limit 1""")
    if not d.get('program_code'):
        sor('program_code', "select code from lounge_programs where active order by code limit 1")
    sor('airport_code', """
        select a.airport_code::text from availabilities a
        group by 1 order by count(*) desc limit 1""")
    # Tarife tablosu AYRI bir kod kumesi tutuyor; plan kodu ile ayni
    # olmak zorunda degil. `entry_tariff_for` bu yuzden bos donuyordu.
    sor('program_code_tarife', """
        select t.program_code from program_entry_tariff t
        where t.active and (t.valid_to is null or t.valid_to >= current_date)
        limit 1""")
    sor('lang', "select 'tr'")
    if not d.get('staff'):
        d['staff'] = d.get('host')
    return d


def _uuid_degeri(ad, d):
    a = ad.lower()
    # Sira ONEMLI: 'p_host_id' hem 'host' hem 'id' iceriyor.
    for anahtar in ('venue', 'lounge', 'avail', 'request', 'program',
                    'card', 'partner', 'thread', 'host', 'guest', 'user',
                    'actor', 'target', 'other', 'peer'):
        if anahtar in a:
            esle = {'avail': 'availability', 'actor': 'user', 'target': 'user',
                    'other': 'guest', 'peer': 'guest'}.get(anahtar, anahtar)
            if d.get(esle):
                return f"'{d[esle]}'::uuid"
    if d.get('user'):
        return f"'{d['user']}'::uuid"
    return 'null::uuid'


def _metin_degeri(ad, tip, d=None):
    a = ad.lower()
    d = d or {}
    # 🔴 PROGRAM KODU UYDURULAMAZ. `card_tier_options('PRIORITY_PASS')`
    # dogru kodu almazsa 0 satir doner ve sozlesme dogrulanmaz; uydurma
    # bir kod da ayni sonucu verir. Katalogdan OKUYORUZ.
    if 'program' in a and d.get('program_code'):
        return f"'{d['program_code']}'"
    if 'airport' in a or a.endswith('_code') or a == 'p_code':
        return f"'{d.get('airport_code') or 'IST'}'"
    if 'lang' in a or 'locale' in a:
        return "'tr'"
    if 'scope' in a:
        return "'international'"
    if 'carrier' in a:
        return "'TK'"
    if 'cabin' in a:
        return "'economy'"
    if 'tier' in a:
        return "'PP_STANDARD'"
    if 'flight' in a:
        return "'TK1980'"
    if 'phone' in a:
        return "'+905550000000'"
    if 'email' in a:
        return "'seed@loungelink.test'"
    return f'null::{tip}'


def arguman_ifadesi(imza, d):
    """`pg_get_function_identity_arguments` ciktisini deger listesine cevir.

    Ornek girdi: "p_venue uuid, p_user uuid, p_scope text"
    Cikti:       "'..'::uuid, '..'::uuid, 'international'"
    Cozemezsek None doner ve fonksiyon ATLANMIS sayilir (ve YAZILIR)."""
    imza = (imza or '').strip()
    if not imza:
        return ''
    parcalar, derinlik, tampon = [], 0, ''
    for ch in imza:
        if ch in '([':
            derinlik += 1
        elif ch in ')]':
            derinlik -= 1
        if ch == ',' and derinlik == 0:
            parcalar.append(tampon); tampon = ''
        else:
            tampon += ch
    if tampon.strip():
        parcalar.append(tampon)

    degerler = []
    for p in parcalar:
        p = p.strip()
        p = re.sub(r'^(in|out|inout|variadic)\s+', '', p, flags=re.I)
        m = re.match(r'^([a-z_][a-z0-9_]*)\s+(.+)$', p, re.I)
        if m:
            ad, tip = m.group(1), m.group(2).strip()
        else:
            ad, tip = '', p.strip()
        tl = tip.lower()
        if tl.endswith('[]'):
            # 🔴 `null::uuid[]` = 0 satir. `amenities_for(p_ids)` ve
            # `discovery_rule_badges(p_ids)` tam da boyle sessizce
            # dogrulanmadan geciyordu. Gercek id'lerden dizi kuruyoruz.
            if tl == 'uuid[]':
                aday = [d.get(k) for k in ('lounge', 'venue', 'availability') if d.get(k)]
                if aday:
                    ic = ', '.join(f"'{x}'::uuid" for x in aday)
                    degerler.append(f'array[{ic}]')
                else:
                    degerler.append(f'null::{tip}')
            else:
                degerler.append(f'null::{tip}')
        elif tl == 'uuid':
            degerler.append(_uuid_degeri(ad, d))
        elif tl in ('text', 'character varying', 'varchar', 'name'):
            degerler.append(_metin_degeri(ad, tip, d))
        elif tl.startswith('character'):
            degerler.append(_metin_degeri(ad, 'text', d) + f'::{tip}')
        elif tl in ('integer', 'int', 'int4', 'bigint', 'int8', 'smallint', 'numeric', 'real',
                    'double precision'):
            # Limit/offset gibi argumanlar 0 verilirse SATIR GELMEZ.
            al = ad.lower()
            if 'limit' in al or 'count' in al or al == 'lim':
                degerler.append('50')
            elif 'offset' in al:
                degerler.append('0')
            elif 'day' in al or 'gun' in al or 'hour' in al or 'window' in al:
                # `rules_expiring(p_days)` null ile 0 satir donuyordu.
                # 3650 = "onumuzdeki on yil"; amac satir uretmek.
                degerler.append('3650')
            else:
                degerler.append(f'null::{tip}')
        elif tl == 'boolean':
            degerler.append('null::boolean')
        elif tl in ('date',):
            degerler.append('current_date')
        elif tl.startswith('timestamp'):
            degerler.append('now()')
        elif tl == 'jsonb' or tl == 'json':
            degerler.append(f"'{{}}'::{tip}")
        else:
            # Enum ya da bilinmeyen tip: null verilebilir ama enum'da
            # null cogu zaman 0 satir demek. Yine de cagiriyoruz —
            # 0 satir "dogrulanmadi" olarak YAZILACAK.
            degerler.append(f'null::{tip}')
    return ', '.join(degerler)


def bos_arguman(imza):
    """Butun argumanlari `null::tip` yapan bir cagri listesi.

    🔴 NEDEN GEREKLI: `partner_lounges(p_user uuid)` govdesinde
    `where lp.user_id = coalesce(p_user, auth.uid())` yaziyor. Ben
    p_user'a "bir kullanici" veriyordum ve o kullanicinin salon yetkisi
    olmadigi icin 0 satir donuyordu. NULL versem fonksiyon auth.uid()'e
    dusecek ve DOGRU kullaniciyi kendisi bulacakti. Yani bazi
    fonksiyonlarda EN IYI ARGUMAN, argumani hic vermemektir."""
    imza = (imza or '').strip()
    if not imza:
        return ''
    parcalar, derinlik, tampon = [], 0, ''
    for ch in imza:
        if ch in '([':
            derinlik += 1
        elif ch in ')]':
            derinlik -= 1
        if ch == ',' and derinlik == 0:
            parcalar.append(tampon); tampon = ''
        else:
            tampon += ch
    if tampon.strip():
        parcalar.append(tampon)
    out = []
    for p in parcalar:
        p = re.sub(r'^\s*(in|out|inout|variadic)\s+', '', p.strip(), flags=re.I)
        m = re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*\s+(.+)$', p)
        out.append(f'null::{(m.group(1) if m else p).strip()}')
    return ', '.join(out)


def envanter(psql, uri):
    """Satir/kompozit donduren public fonksiyonlar."""
    sql = """
      select p.oid::text,
             p.proname,
             coalesce(pg_get_function_identity_arguments(p.oid), ''),
             pg_get_function_result(p.oid),
             p.provolatile
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      join pg_type t on t.oid = p.prorettype
      where n.nspname = 'public'
        and p.prokind = 'f'
        and (p.proretset or t.typtype = 'c')
      order by p.proname, p.oid"""
    r = psql(uri, f'copy ({sql}) to stdout with (format csv)', tuples=True)
    if r.returncode != 0:
        raise RuntimeError('envanter sorgusu calismadi: ' + (r.stderr or '')[:300])
    import csv, io
    out = []
    for satir in csv.reader(io.StringIO(r.stdout)):
        if len(satir) >= 5:
            out.append(dict(oid=satir[0], ad=satir[1], imza=satir[2],
                            sonuc=satir[3], oynak=satir[4]))
    return out


def gecis(psql, uri, yaz=print):
    """Canli cagri gecisi. (dogrulanan, satirsiz, hatalar) doner."""
    d = demirbas(psql, uri)
    eksik = [k for k, v in d.items() if not v]
    if eksik:
        yaz(f'  ⚠ SEED bu demirbaslari uretmedi: {", ".join(sorted(eksik))}')
        yaz('     (o tipteki argumanlara null gidecek → o fonksiyonlar 0 satir donebilir)')

    fns = envanter(psql, uri)
    dogrulanan, satirsiz, hatalar, atlanan = [], [], [], []

    for f in fns:
        ad = f['ad']
        if ad in ATLA:
            atlanan.append((ad, ATLA[ad])); continue
        if ad.startswith(SISTEM_ON_EK):
            continue
        if ad.startswith('trg_') or ad.startswith('_'):
            continue

        # 🔴 TEK ARGUMAN VEKTORU YETMIYOR — OLCTUM.
        # Uc fonksiyon (entry_tariff_for · partner_lounges · ...) veri
        # OLDUGU HALDE 0 satir donduruyordu, cunku SECTIGIM deger yanlisti:
        # tarifesi olmayan program kodu, yetkisi olmayan kullanici. Bu bir
        # veri boslugu degil, ARGUMAN boslugu — ve ikisini birbirine
        # karistirmak "SEED bu yolu doldurmuyor" diye YANLIS bir teshis
        # yazdiriyordu. Simdi sirayla birkac vektor deneniyor.
        d2 = dict(d)
        if d.get('program_code_tarife'):
            d2['program_code'] = d['program_code_tarife']
        adaylar = []
        for aday in (arguman_ifadesi(f['imza'], d),
                     arguman_ifadesi(f['imza'], d2),
                     bos_arguman(f['imza'])):
            if aday is not None and aday not in adaylar:
                adaylar.append(aday)
        if not adaylar:
            atlanan.append((ad, 'arguman uretilemedi')); continue
        # 🔴 TEK KIMLIKLE VE TEK ARGUMAN VEKTORUYLE CAGIRMAK YETMIYOR.
        # Iki ayri korluk olctum:
        #  (1) Herkesi `host` kimligiyle cagirdim → tam da canlida patlayan
        #      `my_sent_requests` 0 satir dondu; o fonksiyon
        #      `where guest_id = auth.uid()` diyor. Yani enstruman,
        #      yakalamak icin yazildigi fonksiyonu gormeden geciyordu.
        #  (2) Arguman degerini bir kez secip biraktim → `entry_tariff_for`
        #      tarifesi olmayan bir program koduyla, `partner_lounges` ise
        #      yetkisi olmayan bir kullaniciyla cagrildi ve ikisi de 0 satir
        #      dondu. Bunlari "SEED bu yolu doldurmuyor" diye yazmistim;
        #      YANLIS TESHIS — veri vardi, argumanim yanlisti.
        # Simdi: her arguman vektoru x her kimlik, ilk satir donen kazanir.
        en_iyi, en_iyi_kim, ilk_hata = 0, None, None
        for args in adaylar:
            cagri = f'public."{ad}"({args})'
            for kim in ('guest', 'guest2', 'host', 'staff'):
                kimlik = d.get(kim)
                if not kimlik:
                    continue
                rol = 'service_role' if kim == 'staff' else 'authenticated'
                jwt = json.dumps({'sub': kimlik, 'role': rol})
                # 🔴 HER CAGRI KENDI ISLEMINDE VE ROLLBACK'LI.
                # Yazan fonksiyonlar da cagriliyor — onlarin da `returns
                # table` sozlesmesi var ve canlida patlayan tam olarak o
                # sinif. Rollback olmasa bu gecis, ardindan kosan 26
                # degismezi bozardi (ilk denememde bozdu).
                sql = (
                    "begin;\n"
                    "set local statement_timeout = '20s';\n"
                    f"select set_config('request.jwt.claims', {_lit(jwt)}, true);\n"
                    f"select count(*)::text from {cagri};\n"
                    "rollback;"
                )
                r = psql(uri, sql, tuples=True)
                if r.returncode != 0:
                    hata = next((l.strip() for l in (r.stderr or '').splitlines()
                                 if 'ERROR' in l), '')
                    detay = next((l.strip() for l in (r.stderr or '').splitlines()
                                  if l.strip().startswith('DETAIL')), '')
                    kod = ''
                    m = re.search(r'ERROR:\s+([0-9A-Z]{5}):', hata)
                    if m:
                        kod = m.group(1)
                    if kod == '42804':
                        # Tip uyusmazligi arguman/kimlikten BAGIMSIZDIR —
                        # aramayi surdurmenin anlami yok, hemen bildir.
                        ilk_hata = dict(ad=ad, imza=f['imza'], kod=kod,
                                        hata=hata, detay=detay, kim=kim)
                        en_iyi = 0
                        break
                    if ilk_hata is None:
                        ilk_hata = dict(ad=ad, imza=f['imza'], kod=kod,
                                        hata=hata, detay=detay, kim=kim)
                    continue
                sayi = 0
                for l in (r.stdout or '').splitlines():
                    l = l.strip()
                    if l.isdigit():
                        sayi = int(l); break
                if sayi > en_iyi:
                    en_iyi, en_iyi_kim = sayi, kim
                if en_iyi > 0:
                    break
            if en_iyi > 0 or (ilk_hata and ilk_hata.get('kod') == '42804'):
                break

        if en_iyi > 0:
            dogrulanan.append((ad, en_iyi))
        elif ilk_hata is not None:
            hatalar.append(ilk_hata)
        else:
            satirsiz.append(ad)

    # ── RAPOR ────────────────────────────────────────────────────────
    tip_hatasi = [h for h in hatalar if h['kod'] == '42804']
    diger = [h for h in hatalar if h['kod'] != '42804']

    if tip_hatasi:
        yaz('')
        yaz(f'  🔴 {len(tip_hatasi)} FONKSIYONDA TIP SOZLESMESI TUTMUYOR (42804).')
        yaz('     Gokberk canlida tam olarak bu hatayi aldi. Kurulum DURUR.')
        for h in tip_hatasi:
            yaz(f'     ✗ {h["ad"]}({h["imza"]})')
            yaz(f'         {h["hata"][:180]}')
            if h['detay']:
                yaz(f'         {h["detay"][:180]}')

    if diger:
        yaz('')
        yaz(f'  ⚠ {len(diger)} fonksiyon cagrilirken baska hata verdi')
        yaz('     (cogu "argumani uyduramadim" demektir — tip hatasi DEGIL,')
        yaz('      ama bu fonksiyonlarin sozlesmesi de DOGRULANMADI):')
        for h in diger[:12]:
            yaz(f'     · {h["ad"]}  [{h["kod"]}] {h["hata"][:110]}')
        if len(diger) > 12:
            yaz(f'     · ... {len(diger) - 12} tane daha')

    yaz('')
    toplam = len(dogrulanan) + len(satirsiz) + len(hatalar)
    yaz(f'  OLCUM (canli cagri): cagrilan {toplam} · '
        f'SATIR DONEN {len(dogrulanan)} · satir donmeyen {len(satirsiz)} · '
        f'hata {len(hatalar)} · atlanan {len(atlanan)}')
    yaz(f'  → Tip sozlesmesi GERCEKTEN dogrulanan fonksiyon sayisi: {len(dogrulanan)}')
    yaz(f'  → Geri kalan {toplam - len(dogrulanan)} fonksiyon hakkinda bu gecis '
        f'HICBIR SEY soylemiyor.')
    nob = sorted(x for x in satirsiz if x in NOBETCI)
    ack = sorted(x for x in satirsiz if x not in NOBETCI)
    if nob:
        yaz(f'  Bunlarin {len(nob)} tanesi NOBETCI fonksiyonu — 0 satir DOGRU cevap')
        yaz('  (ihlal listesi donduruyorlar; bos liste = sistem saglikli):')
        for i in range(0, len(nob), 4):
            yaz('     ' + ' · '.join(nob[i:i + 4]))
    if ack:
        yaz(f'  GERCEK BOSLUK — {len(ack)} fonksiyon: veri yok, sozlesme dogrulanmadi:')
        for i in range(0, len(ack), 4):
            yaz('     ' + ' · '.join(ack[i:i + 4]))
    for ad, sebep in atlanan:
        yaz(f'  atlandi: {ad} — {sebep}')

    return dogrulanan, satirsiz, hatalar


def _lit(s):
    return "'" + s.replace("'", "''") + "'"
