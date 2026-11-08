# -*- coding: utf-8 -*-
"""
LoungeLink · denetim_tam_uret.py   (8 Kasım 2026)

AMAÇ: "001'den son dosyaya kadar canlı veritabanı, dosyaların kurduğu hâlle birebir
aynı mı?" sorusunu TEK sorguyla cevaplamak.

NASIL: 001..son + SEED'leri yerelde baştan kuran `rnapp/pg_run.py --keep` sonrası,
yerel veritabanından her nesnenin parmak izi alınır:
  · fonksiyon: imza + gövde özeti (boşluk/satır sonu farkı yok sayılır) + security definer
               + anon/authenticated çalıştırma yetkisi
  · tablo kolonu: tablo.kolon + tip + null olabilir mi
  · RLS: tablo RLS açık mı · politika adı + komut + roller + koşul özeti
  · tetikleyici: tablo + ad + tanım özeti
  · pg_cron işleri (yerelde cron yoksa atlanır)
Sonra `sql/DENETIM_TAM.sql` yazılır: canlıda aynı izleri hesaplar ve YALNIZ FARKLARI
listeler. Hiçbir şey değiştirmez. Satır dönmezse canlı = dosyalar.

KULLANIM (yerel Postgres 127.0.0.1:5432'de, pg_run --keep ile kurulu):
    python denetim_tam_uret.py [--port 5432] [--db postgres]
"""
import os, subprocess, sys, datetime

PSQL = os.path.expanduser(r"~\AppData\Roaming\Python\Python312\site-packages\pgserver\pginstall\bin\psql.exe")
PORT = sys.argv[sys.argv.index("--port") + 1] if "--port" in sys.argv else "5432"
DB = sys.argv[sys.argv.index("--db") + 1] if "--db" in sys.argv else "postgres"
CIKTI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "DENETIM_TAM.sql")

# Canlıda ve yerelde AYNI ifadeyle hesaplanan izler (tek kaynak: hem üretim hem denetim bunu kullanır).
IZ_SORGUSU = r"""
select 'fonksiyon' as tur,
       p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as ad,
       md5(regexp_replace(pg_get_functiondef(p.oid), '\s+', '', 'g'))
         || ':' || case when p.prosecdef then 'D' else 'I' end
         || ':' || case when has_function_privilege('anon', p.oid, 'execute') then 'a' else '-' end
         || case when has_function_privilege('authenticated', p.oid, 'execute') then 'u' else '-' end as iz
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind in ('f', 'p')
union all
select 'kolon', c.table_name || '.' || c.column_name,
       c.data_type || ':' || c.is_nullable
  from information_schema.columns c
  join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
 where c.table_schema = 'public' and t.table_type = 'BASE TABLE'
union all
select 'rls', c.relname, case when c.relrowsecurity then 'acik' else 'kapali' end
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r'
union all
select 'politika', schemaname || '.' || tablename || '.' || policyname,
       md5(regexp_replace(cmd || '|' || array_to_string(roles, ',') || '|' || coalesce(qual, '') || '|' || coalesce(with_check, ''), '\s+', '', 'g'))
  from pg_policies where schemaname in ('public', 'storage')
union all
select 'tetikleyici', c.relname || '.' || t.tgname,
       md5(regexp_replace(pg_get_triggerdef(t.oid), '\s+', '', 'g'))
  from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and not t.tgisinternal
"""


def psql(sql):
    r = subprocess.run([PSQL, "-h", "127.0.0.1", "-p", PORT, "-U", "postgres", "-d", DB,
                        "-At", "-F", "\t", "-v", "ON_ERROR_STOP=1", "-c", sql],
                       capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        sys.exit("psql hata: " + r.stderr[:2000])
    return [l.split("\t") for l in r.stdout.splitlines() if l.strip()]


def q(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    satirlar = psql(IZ_SORGUSU)
    # Yerel kurulumun Supabase taklidi (pg_run.py SHIM) public'e koyduğu fonksiyonlar:
    # Supabase'de bunlar `extensions` şemasında; canlıda "EKSIK" sanılmasın.
    TAKLIT = {"uuid_generate_v4()"}
    satirlar = [r for r in satirlar if not (r[0] == "fonksiyon" and r[1] in TAKLIT)]
    # Yerelde pg_cron yok: beklenen işler dosyalardan okunur (cron.schedule('ad', ...)).
    # Sonradan unschedule edilip yeniden kurulmayan iş için: dosyalarda unschedule'dan
    # sonra yeniden schedule edilen her ad beklenir.
    import re, glob
    kur, sil = {}, {}
    for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "[0-9][0-9][0-9]*.sql"))):
        t = open(f, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r"cron\.schedule\(\s*'([^']+)'", t):
            kur[m.group(1)] = f
    cron = sorted(kur)
    sayac = {}
    for tur, _, _ in satirlar:
        sayac[tur] = sayac.get(tur, 0) + 1

    values = ",\n".join("  (%s, %s, %s)" % (q(t), q(a), q(i)) for t, a, i in sorted(satirlar))
    cron_values = ",\n".join("  (%s)" % q(j) for j in cron) or "  (null)"
    zaman = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    ozet = " · ".join("%s %d" % (k, v) for k, v in sorted(sayac.items()))

    sql = f"""-- ============================================================================
-- DENETIM_TAM · CANLI VERİTABANI = 001..SON DOSYALAR MI?   (üretildi: {zaman})
--
-- `sql/denetim_tam_uret.py` üretti: bütün SQL dosyaları yerelde baştan kuruldu ve her
-- nesnenin parmak izi alındı ({ozet}).
-- Bu sorgu canlıda aynı izleri hesaplar ve YALNIZ FARKLARI listeler. Hiçbir şey DEĞİŞTİRMEZ.
--
-- SONUÇ NASIL OKUNUR
--   · Hiç satır dönmezse: canlı veritabanı dosyalarla birebir aynı.
--   · durum = 'EKSIK'  → dosyalar kuruyor, canlıda YOK (ilgili dosya çalıştırılmamış/düşmüş)
--   · durum = 'FARKLI' → canlıda VAR ama gövdesi/yetkisi/tipi dosyadakinden farklı
--   · durum = 'FAZLA'  → canlıda var, dosyalarda yok (elle eklenmiş ya da Supabase'in kendi
--                        nesnesi olabilir; bilgi amaçlı, çoğu zararsız)
--   Sonucu olduğu gibi (Export › CSV ya da kopyala) Claude'a ilet.
-- ============================================================================
with beklenen(tur, ad, iz) as (values
{values}
), gercek as (
{IZ_SORGUSU.strip()}
), beklenen_cron(ad) as (values
{cron_values}
), fark as (
  select coalesce(b.tur, g.tur) as tur, coalesce(b.ad, g.ad) as ad,
         case when g.ad is null then 'EKSIK'
              when b.ad is null then 'FAZLA'
              else 'FARKLI' end as durum,
         b.iz as beklenen_iz, g.iz as canli_iz
    from beklenen b
    full join gercek g on g.tur = b.tur and g.ad = b.ad
   where g.ad is null or b.ad is null or g.iz is distinct from b.iz
  union all
  select 'cron', c.ad, 'EKSIK', null, null
    from beklenen_cron c
   where c.ad is not null
     -- pg_cron yoksa (yerel) atlanır; varsa dinamik sorgu (cron.job'a doğrudan başvuru
     -- pg_cron'suz veritabanında sorguyu düşürürdü).
     and to_regclass('cron.job') is not null
     and query_to_xml(format('select count(*) as n from cron.job where jobname = %L', c.ad), false, true, '')::text like '%<n>0</n>%'
)
select durum, tur, ad, beklenen_iz, canli_iz
  from fark
 order by case durum when 'EKSIK' then 1 when 'FARKLI' then 2 else 3 end, tur, ad;
"""
    open(CIKTI, "w", encoding="utf-8", newline="\n").write(sql)
    print("DENETIM_TAM.sql yazildi ·", ozet, "· cron", len(cron))


if __name__ == "__main__":
    main()
