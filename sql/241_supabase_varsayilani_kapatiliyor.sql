-- ============================================================================
-- LoungeLink · 241_supabase_varsayilani_kapatiliyor.sql   (22 Ağustos 2026)
--
-- HERKESE AÇIK ANAHTARLA SİLİNEBİLEN ALTI TABLO
--
-- ════════════════════════════════════════════════════════════════════════
-- BU DOSYA 232'NİN CANLIDA PATLAMASI SAYESİNDE VAR
-- ════════════════════════════════════════════════════════════════════════
-- 232 harness'te YEŞİL yandı, senin veritabanında KIRMIZI. Sebebi
-- sözdizimi değil BAŞLANGIÇ DURUMUydu:
--
--   Boş Postgres → `anon` ve `authenticated` hiçbir hakka sahip değil
--   Supabase     → proje `alter default privileges in schema public
--                   grant all on tables to anon, authenticated,
--                   service_role` ile gelir
--
-- Yani Supabase'de **her yeni tablo bu üç role SONUNA KADAR AÇIK doğar.**
-- Benim bütün grant nöbetçilerim, kapanacak bir grant'ın hiç olmadığı
-- bir dünyada ölçüm yapıyordu.
--
-- 🆕 SINIF: **"BİR NÖBETÇİ, GERÇEK ORTAMIN BAŞLANGIÇ DURUMUNU TAKLİT
-- ETMİYORSA, ÖLÇTÜĞÜ ŞEY ÜRÜN DEĞİL KENDİ LABORATUVARIDIR."**
--
-- pg_run.py'yi Supabase'in başlangıç grant'larını kuracak şekilde
-- değiştirdim. Harness aynı anda İKİ dosyayı kırmızıya çevirdi (232 ve
-- 238) ve ardından aşağıdaki asıl bulguyu ortaya çıkardı.
--
-- ════════════════════════════════════════════════════════════════════════
-- BULGU — ÖLÇÜLDÜ
-- ════════════════════════════════════════════════════════════════════════
-- Altı tabloda RLS KAPALI ve `anon` + `authenticated` rollerinde
-- DELETE, INSERT, UPDATE, TRUNCATE hakkı var:
--
--   card_network_source · country_aliases · host_tiers
--   rpc_client_surface  · rule_test_cases · rule_venue_cases
--
-- `anon` anahtarı gizli değildir — APK'nın içinden çıkarılabilir. Yani
-- bugün, uygulamayı indiren herkes şunu yapabilir:
--
--   truncate rule_test_cases;      → kural motorunun sınav takımı gider
--   delete from host_tiers;        → mertebe kataloğu boşalır
--   update rpc_client_surface ...; → hangi fonksiyonun istemciye açık
--                                    olduğunu belirleyen defter
--
-- Bunların hiçbirini app okumuyor bile (ölçüldü: app'te ve BO'da
-- `from("...")` araması — app 0, BO yalnız `host_tiers` ve service_role
-- ile). Yani bu haklar KİMSEYE lazım değil; yalnız duruyorlar.
--
-- ⚠️ `audit_log` bu listede DEĞİL. Onda da grant var ama RLS AÇIK ve
-- politikası yok — RLS açık + politika yok = herkese kapalı. Yani
-- oradaki grant zararsız. Farkı yazıyorum çünkü harness ikisini aynı
-- uyarı satırında gösteriyor ve bu, gerçek olmayan bir alarma benziyor.
--
-- ════════════════════════════════════════════════════════════════════════
-- BU DOSYA NE YAPIYOR
-- ════════════════════════════════════════════════════════════════════════
-- Elle liste tutmuyorum — liste tutmak bu projede defalarca eksik kaldı.
-- Üç tarama, üçü de VERİDEN türetiliyor:
--   A) İstemcinin YAZMA hakkı: ölçülmüş beyaz liste dışında her tablodan
--      alınır.
--   B) RLS kapalı her tabloda RLS açılır ve okuma AYNEN korunur
--      (`using (true)`) — yani hiçbir okuma bozulmaz, yalnız yazma kapanır.
--   C) Tetikleyici fonksiyonları istemciden gizlenir.
-- Ve D) gelecekte doğacak tablolar için varsayılan kapatılır.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) BEYAZ LİSTE — İSTEMCİNİN GERÇEKTEN YAZDIĞI YERLER
-- ----------------------------------------------------------------------------
-- Her satır ÖLÇÜLDÜ: app kaynağında `.from("<tablo>").insert/update/delete`
-- araması yapıldı. Ölçülmemiş hiçbir tablo bu listede değil.
create table if not exists client_write_allowlist (
  table_name text primary key,
  privs      text[] not null,
  gerekce    text not null
);

insert into client_write_allowlist (table_name, privs, gerekce) values
  ('visits',              array['INSERT','DELETE'], 'Seyahat ekleme/silme — silme 240 tetikleyicisiyle korumali'),
  ('messages',            array['INSERT'],          'Sohbet mesaji — RLS with_check ile from_id=auth.uid() zorunlu'),
  ('chat_channels',       array['INSERT'],          'Kanal acma — RLS with_check taraf kontrolu yapiyor'),
  ('connection_requests', array['INSERT'],          'Baglanti istegi — blok kapisi tetikleyicisi var'),
  ('notifications',       array['UPDATE'],          'Yalniz read/read_at kolonlari (240)'),
  ('waitlist',            array['INSERT'],          'Herkese acik bekleme listesi formu'),
  ('profiles',            array['UPDATE'],          'Kolon duzeyinde sinirli (232)'),
  ('users',               array['UPDATE'],          'Yalniz gender kolonu (232)')
on conflict (table_name) do update
  set privs = excluded.privs, gerekce = excluded.gerekce;

-- ----------------------------------------------------------------------------
-- A) YAZMA HAKKI TARAMASI
-- ----------------------------------------------------------------------------
do $a$
declare
  r        record;
  v_kesik  int := 0;
  v_liste  text[] := '{}';
begin
  for r in
    select tp.table_name, tp.grantee, tp.privilege_type
      from information_schema.table_privileges tp
      join pg_class c on c.relname = tp.table_name
      join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
     where tp.table_schema = 'public'
       and tp.grantee in ('anon','authenticated')
       and tp.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
       -- 🔴 22 AGUSTOS DUZELTMESI: burada 'r' yaziyordu, yani yalniz
       -- TABLOLAR. Gorunumler taranmadi ve `user_balances` gorunumu
       -- uzerinden `users` tablosunun her satirina yazilabiliyordu
       -- (242'de olculdu: 45 satir). Ayrinti 242'de.
       and c.relkind in ('r','v','m','p','f')
       and not exists (
             select 1 from client_write_allowlist w
              where w.table_name = tp.table_name
                and tp.privilege_type = any (w.privs))
  loop
    execute format('revoke %s on public.%I from %I', r.privilege_type, r.table_name, r.grantee);
    v_kesik := v_kesik + 1;
    if r.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE') then
      v_liste := v_liste || (r.grantee || '→' || r.table_name || '.' || r.privilege_type);
    end if;
  end loop;

  raise notice '241/A: % yazma hakki kesildi. Onemlileri: %',
    v_kesik,
    coalesce(nullif(array_to_string(v_liste[1:12], ', '), ''), 'yok');
end $a$;

-- ----------------------------------------------------------------------------
-- B) RLS TARAMASI — OKUMA AYNEN KALIR, YAZMA KAPANIR
-- ----------------------------------------------------------------------------
-- ⚠️ BURADA BİLEREK CESUR DEĞİLİM. RLS'i açıp politika koymazsam tablo
-- herkese kapanır ve bugün okuyan biri varsa SESSİZCE boş liste görür —
-- bu, bu projedeki en pahalı hata türü (kullanıcı hata görmez, veri
-- yoktur). Bu yüzden RLS'i açarken okuma politikasını `using (true)`
-- koyuyorum: okuma AYNEN bugünküyle aynı kalıyor. Kapanan tek şey yazma
-- ve o zaten (A)'da kesildi.
do $b$
declare
  r       record;
  v_acik  int := 0;
begin
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
     where c.relkind = 'r'
       and c.relrowsecurity = false
       and exists (select 1 from information_schema.table_privileges tp
                    where tp.table_schema='public' and tp.table_name=c.relname
                      and tp.grantee in ('anon','authenticated'))
  loop
    execute format('alter table public.%I enable row level security', r.relname);
    if not exists (select 1 from pg_policies
                    where schemaname='public' and tablename=r.relname and cmd='SELECT') then
      execute format(
        'create policy %I on public.%I for select using (true)',
        r.relname || '_okuma_korundu', r.relname);
    end if;
    v_acik := v_acik + 1;
  end loop;
  raise notice '241/B: % tabloda RLS acildi (okuma aynen korundu)', v_acik;
end $b$;

-- ----------------------------------------------------------------------------
-- C) TETİKLEYİCİ FONKSİYONLARI İSTEMCİDEN GİZLENİR
-- ----------------------------------------------------------------------------
-- Harness uyarısı: `trg_soru_metni`, `trg_soru_bildirimi_host`,
-- `trg_seyahat_sozlesme_kapisi` → "yuzeyde yok ama istemciye acik".
-- Bir tetikleyici fonksiyonunu istemcinin ÇAĞIRMASI hiçbir zaman doğru
-- değildir; `new`/`old` olmadan çağrıldıklarında ne yapacakları da
-- tanımsızdır.
do $c$
declare r record; v_n int := 0;
begin
  for r in
    select p.oid::regprocedure as imza
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace and n.nspname='public'
     where p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.imza);
    v_n := v_n + 1;
  end loop;
  raise notice '241/C: % tetikleyici fonksiyonu istemciden gizlendi', v_n;
end $c$;

-- ----------------------------------------------------------------------------
-- D) GELECEKTE DOĞACAK TABLOLAR
-- ----------------------------------------------------------------------------
-- Yukarıdaki taramalar BUGÜNÜ temizler. Ama Supabase'in varsayılanı
-- yerinde durduğu sürece, yarın yazılacak bir migration'ın oluşturduğu
-- tablo yine sonuna kadar açık doğar ve bu dosyayı yeniden koşmam
-- gerekir. Bir temizliği tekrarlamak zorunda kalmak, temizliğin değil
-- KAYNAĞIN sorunudur.
--
-- Okuma varsayılanına DOKUNMUYORUM — PostgREST'in çalışması için
-- `select` gerekiyor ve onu kesmek yeni tablo ekleyen herkesi sessiz
-- boş listeye düşürür. Yalnız YAZMA varsayılanı kapanıyor; yazmaya
-- ihtiyacı olan tablo bunu açıkça istesin.
alter default privileges in schema public
  revoke insert, update, delete, truncate on tables from anon, authenticated;

-- ----------------------------------------------------------------------------
-- E) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n241$
declare
  v_kalan   int;
  v_ayrinti text;
  v_rlssiz  int;
  v_beyaz   int;
begin
  -- (1) Beyaz liste dışında yazma hakkı kalmamalı
  select count(*), string_agg(tp.grantee || '→' || tp.table_name || '.' || tp.privilege_type, ', ')
    into v_kalan, v_ayrinti
    from information_schema.table_privileges tp
    join pg_class c on c.relname = tp.table_name
    join pg_namespace n on n.oid = c.relnamespace and n.nspname='public'
   where tp.table_schema='public'
     and tp.grantee in ('anon','authenticated')
     and tp.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
     and c.relkind in ('r','v','m','p','f')
     and not exists (select 1 from client_write_allowlist w
                      where w.table_name = tp.table_name
                        and tp.privilege_type = any (w.privs));
  if v_kalan > 0 then
    raise exception '241 NOBETCI: beyaz liste disinda % yazma hakki DURUYOR → %', v_kalan, v_ayrinti;
  end if;

  -- (2) 🔴 TERSTEN ÖLÇÜM: beyaz listedeki haklar KESİLMEMİŞ olmalı.
  -- Her şeyi kesen bir tarama da birinci kontrolden yeşil geçer; app'i
  -- kırar. "Kesti mi" sorusunun yanına "fazla kesti mi" sorusu şart.
  select count(*) into v_beyaz
    from client_write_allowlist w
    join lateral unnest(w.privs) pv on true
   where exists (select 1 from information_schema.table_privileges tp
                  where tp.table_schema='public' and tp.table_name=w.table_name
                    and tp.grantee='authenticated'
                    and (tp.privilege_type = pv
                         or (pv='UPDATE' and tp.privilege_type='UPDATE')))
      or exists (select 1 from information_schema.column_privileges cp
                  where cp.table_schema='public' and cp.table_name=w.table_name
                    and cp.grantee='authenticated' and cp.privilege_type = pv);
  if v_beyaz < (select count(*) from client_write_allowlist) then
    raise exception '241 NOBETCI: beyaz listedeki % tablodan yalniz %si yazilabilir kaldi — FAZLA KESTIM.',
      (select count(*) from client_write_allowlist), v_beyaz;
  end if;

  -- (3) İstemciye açık ve RLS'siz tablo kalmamalı
  select count(*) into v_rlssiz
    from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
   where c.relkind='r' and c.relrowsecurity=false
     and exists (select 1 from information_schema.table_privileges tp
                  where tp.table_schema='public' and tp.table_name=c.relname
                    and tp.grantee in ('anon','authenticated'));
  if v_rlssiz > 0 then
    raise exception '241 NOBETCI: istemciye acik ama RLS kapali % tablo var.', v_rlssiz;
  end if;

  -- (4) Somut örnek: anon artık kural motorunun sınav takımını silemez
  if exists (select 1 from information_schema.table_privileges
              where table_schema='public' and table_name='rule_test_cases'
                and grantee in ('anon','authenticated')
                and privilege_type in ('DELETE','TRUNCATE','UPDATE','INSERT')) then
    raise exception '241 NOBETCI: rule_test_cases hala istemciden silinebilir.';
  end if;

  raise notice '241 OK · istemci yazmasi beyaz listeyle sinirli · RLS her yerde acik · '
               'tetikleyici fonksiyonlari gizli · gelecekteki tablolar kapali dogacak';
end $n241$;

select '241 SUPABASE VARSAYILANI KAPANDI' as sonuc,
       (select count(*) from information_schema.table_privileges tp
          join pg_class c on c.relname=tp.table_name
          join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
        where tp.table_schema='public'
          and tp.grantee in ('anon','authenticated')
          and c.relkind in ('r','v','m','p','f')
          and tp.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
          and not exists (select 1 from client_write_allowlist w
                           where w.table_name=tp.table_name
                             and tp.privilege_type = any (w.privs)))      as kacak_yazma_hakki,
       (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false
           and exists (select 1 from information_schema.table_privileges tp
                        where tp.table_schema='public' and tp.table_name=c.relname
                          and tp.grantee in ('anon','authenticated')))     as rlssiz_acik_tablo;
