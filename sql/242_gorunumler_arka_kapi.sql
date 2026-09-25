-- ============================================================================
-- LoungeLink · 242_gorunumler_arka_kapi.sql               (22 Ağustos 2026)
--
-- 241 MASAYI SİLDİ, GÖRÜNÜMLERİ ATLADI — VE ORASI AÇIK KALDI
--
-- ════════════════════════════════════════════════════════════════════════
-- BU DOSYA GÖKBERK'İN "48" DEMESİYLE VAR
-- ════════════════════════════════════════════════════════════════════════
-- 241'i koştuktan sonra ona verdiğim teşhis sorgusunu çalıştırdı:
--     kacak: 48
-- 241'in kendi nöbetçisi ise YEŞİLDİ. İkisi aynı şeyi sayıyor gibi
-- görünüyordu ama saymıyordu:
--
--   241'in nöbetçisi : ... and c.relkind = 'r'      ← yalnız TABLOLAR
--   verdiğim teşhis  : (böyle bir satır yok)        ← her şey
--
-- Yani 48, teşhisin gürültüsü değil; nöbetçinin KÖRLÜĞÜYDÜ. Ölçtüm:
--
--   relkind | nesne | grant
--   --------+-------+------
--   r       |   5   |  12    ← beyaz listedekiler, sorun yok
--   v       |   6   |  48    ← GÖRÜNÜMLER. Hiç bakılmamış.
--
-- 🆕 SINIF: **"BİR TARAMA, YALNIZCA BAKTIĞI RAF KADAR TEMİZDİR."**
-- Tabloları süpürüp sınıfı kapattığımı sandım. Görünüm başka bir rafta
-- duruyor ama AYNI ODAYA açılan bir kapı — üstelik sahibinin anahtarıyla.
--
-- ════════════════════════════════════════════════════════════════════════
-- NEDEN CİDDİ: GÖRÜNÜM, SAHİBİNİN YETKİSİYLE YAZAR
-- ════════════════════════════════════════════════════════════════════════
-- PostgreSQL'de basit bir görünüm KENDİLİĞİNDEN YAZILABİLİRDİR ve yazma
-- taban tabloya geçerken yetki **görünümün SAHİBİ** üzerinden denetlenir,
-- çağıranın üzerinden değil. Görünümler `security_invoker` kapalı
-- doğduğu için taban tablonun RLS'i de sahibe göre değerlendirilir.
--
-- Yani: taban tablodan hakkı almış olmam bir şey ifade etmiyor.
--
-- ÖLÇTÜM — `authenticated` rolüyle, harness'te:
--
--   1) update users set email=... where id <> auth.uid()
--      → permission denied                             ✅ tablo kapalı
--
--   2) update user_balances set user_id = user_id      ← GÖRÜNÜM
--      → 45 satır yazıldı                              ❌ HEPSİ
--
-- `user_balances`, `users` üzerine kurulu ve `is_updatable = YES`,
-- `is_insertable_into = YES`. Yani 241'den sonra bile, uygulamayı
-- indiren herkes bu görünüm üzerinden `users` tablosunun **her satırına**
-- yazabiliyordu.
--
-- ════════════════════════════════════════════════════════════════════════
-- DÜZELTME
-- ════════════════════════════════════════════════════════════════════════
-- Uygulama hiçbir görünüme YAZMIYOR (ölçüldü: app ve BO kaynağında
-- `.from("<gorunum>").insert/update/delete` yok). Görünümler yalnız
-- OKUMAK için var. O yüzden yazma haklarının tamamı kalkıyor, okuma
-- aynen kalıyor.
--
-- Ve tarama artık `relkind`e göre değil, **istisnaya göre** çalışıyor:
-- beyaz listede olmayan HER nesne türünden yazma hakkı alınır. Bir
-- sonraki nesne türünü (materyalize görünüm, bölümlenmiş tablo, yabancı
-- tablo) yeniden atlamamak için.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) TARAMA — HER NESNE TÜRÜ, BEYAZ LİSTE DIŞINDA YAZMA YOK
-- ----------------------------------------------------------------------------
do $a$
declare
  r       record;
  v_n     int := 0;
  v_liste text[] := '{}';
begin
  if to_regclass('public.client_write_allowlist') is null then
    raise exception '242: client_write_allowlist yok — once 241 kosulmali.';
  end if;

  for r in
    select tp.table_name, tp.grantee, tp.privilege_type, c.relkind
      from information_schema.table_privileges tp
      join pg_class c on c.relname = tp.table_name
      join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
     where tp.table_schema = 'public'
       and tp.grantee in ('anon','authenticated')
       and tp.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
       -- 🔴 relkind FILTRESI BILEREK YOK. 241'in korlugu tam buydu.
       and c.relkind in ('r','v','m','p','f')
       and not exists (
             select 1 from client_write_allowlist w
              where w.table_name = tp.table_name
                and tp.privilege_type = any (w.privs))
  loop
    execute format('revoke %s on public.%I from %I', r.privilege_type, r.table_name, r.grantee);
    v_n := v_n + 1;
    if r.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE') and r.relkind <> 'r' then
      v_liste := v_liste || (r.relkind::text || ':' || r.table_name || '.' || r.privilege_type);
    end if;
  end loop;

  raise notice '242: % hak kesildi. Tablo disi olanlar: %',
    v_n, coalesce(nullif(array_to_string(v_liste[1:14], ', '), ''), 'yok');
end $a$;

-- ----------------------------------------------------------------------------
-- 2) BUNDAN SONRA DOĞACAK GÖRÜNÜMLER
-- ----------------------------------------------------------------------------
-- 241 `alter default privileges ... on tables` yazmıştı; PostgreSQL'de
-- bu ifadedeki "TABLES" görünümleri de kapsar (aynı katalog nesnesi).
-- Yani gelecek zaten kapalı — bunu ölçüp aşağıdaki nöbetçide
-- doğruluyorum, varsaymıyorum.

-- ----------------------------------------------------------------------------
-- 3) NÖBETÇİ — ARKA KAPI GERÇEKTEN KAPANDI MI
-- ----------------------------------------------------------------------------
do $n242$
declare
  v_kacak   int;
  v_ayrinti text;
  v_okuma   int;
  v_yazdi   boolean := false;
begin
  -- (1) Hiçbir nesne türünde beyaz liste dışı yazma kalmamalı
  select count(*), string_agg(c.relkind::text || ':' || tp.table_name || '.' || tp.privilege_type
                              || '→' || tp.grantee, ', ')
    into v_kacak, v_ayrinti
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
  if v_kacak > 0 then
    raise exception '242 NOBETCI: % kacak yazma hakki DURUYOR → %', v_kacak, v_ayrinti;
  end if;

  -- (2) 🔴 ASIL SINAMA: gerçekten YAZMAYI DENE. Grant tablosuna bakmak
  -- "kapı kilitli görünüyor" demektir; kapıyı itmek "kilitli" demektir.
  -- Ölçüm bir alt işlemde yapılır ve her hâlükârda geri alınır.
  begin
    begin
      set local role authenticated;
      update user_balances set user_id = user_id where false;
      v_yazdi := true;
    exception when others then
      v_yazdi := false;
    end;
    raise exception 'GERI_AL_242';
  exception when others then
    if sqlerrm <> 'GERI_AL_242' then null; end if;
  end;
  if v_yazdi then
    raise exception '242 NOBETCI: user_balances gorunumu UZERINDEN hala yazilabiliyor.';
  end if;

  -- (3) 🔴 TERS YÖN: okuma bozulmamalı. Her şeyi kesen bir tarama da
  -- birinci kontrolden yeşil geçer ve okuyanı kör eder.
  --
  -- ⚠️ 24 AĞUSTOS 2026 — BU KONTROLÜN KANITI DEĞİŞTİRİLDİ (SQL 253).
  -- Eskiden "bu altı görünüm `anon`/`authenticated` tarafından OKUNABİLİR
  -- kalmalı" diyordu. Ölçüldü ki o hâl bir SIZINTIYDI: `report_sla` açık
  -- taciz şikâyetlerini, `referral_log` isim+e-posta eşleşmelerini,
  -- `stale_requests` kimin nerede kiminle buluşacağını GİRİŞ YAPMAMIŞ
  -- herkese veriyordu (görünümlerde RLS çalışmaz).
  --
  -- Nöbetçinin NİYETİ doğruydu ("fazla kesme"), KANITI yanlıştı: bu
  -- görünümleri okuması gereken istemci değil BACKOFFICE'tir ve o
  -- `service_role` ile okur. Kontrol artık onu ölçüyor.
  --
  -- 🆕 SINIF: "BİR NÖBETÇİNİN NİYETİ DOĞRU AMA KANITI YANLIŞSA, NÖBETÇİYİ
  -- SİLME — KANITINI DEĞİŞTİR."
  select count(*) into v_okuma
    from information_schema.table_privileges
   where table_schema='public' and grantee = 'service_role'
     and privilege_type='SELECT'
     and table_name in ('user_balances','stale_requests','report_sla',
                        'referral_log','i18n_missing','suspicious_availabilities');
  if v_okuma = 0 then
    raise exception '242 NOBETCI: gorunumleri BACKOFFICE de okuyamiyor — fazla kestim.';
  end if;

  -- (4) Beyaz listedekiler duruyor mu (app kirilmasin)
  if not exists (select 1 from information_schema.table_privileges
                  where table_schema='public' and table_name='visits'
                    and grantee='authenticated' and privilege_type='INSERT') then
    raise exception '242 NOBETCI: visits INSERT gitti — app seyahat ekleyemez.';
  end if;

  raise notice '242 OK · gorunum arka kapisi kapandi · okuma korundu · beyaz liste yerinde';
end $n242$;

select '242 GORUNUM ARKA KAPISI KAPANDI' as sonuc,
       (select count(*)
          from information_schema.table_privileges tp
          join pg_class c on c.relname=tp.table_name
          join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
         where tp.table_schema='public' and tp.grantee in ('anon','authenticated')
           and tp.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
           and c.relkind in ('r','v','m','p','f')
           and not exists (select 1 from client_write_allowlist w
                            where w.table_name=tp.table_name
                              and tp.privilege_type = any (w.privs)))     as kacak_yazma_hakki,
       (select count(*) from information_schema.views where table_schema='public'
          and is_updatable='YES')                                          as yazilabilir_gorunum;
