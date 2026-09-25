-- ============================================================================
-- 264 — PUSH ZİNCİRİ VE API/TOKEN SAĞLIK RAPORU  (28 Ağustos 2026)
--
-- ⚠️ BU DOSYA HİÇBİR ŞEYİ DEĞİŞTİRMEZ. Yalnız okur ve rapor yazar.
-- Güvenle, istediğin kadar çalıştırabilirsin.
--
-- ----------------------------------------------------------------------------
-- 🔴 NEDEN VAR
-- ----------------------------------------------------------------------------
-- Gökberk (28 Ağustos): "telefona bildirim gönderdiğimizi varsayarak
-- konuşuyorum ama yapmadıysak onu da yapalım."
--
-- Doğru soru. Çünkü zincir KURULU ama **iki yerinde, bir uzantıya bağlı
-- ve sessizce kopabilen** halka var:
--
--     bildirim yazılır  →  trg on_notification_created  →  notify_push()
--                       →  net.http_post(...)  →  Expo  →  telefon
--                            ▲
--                            └── `pg_net` uzantısı KURULU DEĞİLSE
--                                fonksiyon WARNING yazar ve SESSİZCE geçer
--
-- 18 Ağustos'ta canlıda tam bu oldu:
--     ERROR 3F000: schema "net" does not exist
-- 210b bunu dayanıklı hâle getirdi (artık bildirim kaydını düşürmüyor) —
-- ama dayanıklı olmak ÇALIŞMAK demek değil. Push o günden beri sessizce
-- hiç gitmiyor olabilir ve hiçbir ekran bunu söylemiyor.
--
-- 🆕 SINIF: "BİR ZİNCİRİ HATAYA DAYANIKLI YAPMAK ONU ÇALIŞIR YAPMAZ —
-- DAYANIKLILIK, ARIZAYI GÖRÜNMEZ KILAR; O YÜZDEN YANINA BİR ÖLÇÜM
-- KOYMADAN DAYANIKLILIK EKLENMEZ."
--
-- Aynı sınıf `pg_cron` için de geçerli: kurulu değilse haftalık özet,
-- oran-sınır temizliği ve aylık plan kredisi HİÇ koşmaz.
--
-- ----------------------------------------------------------------------------
-- NE RAPORLUYOR
-- ----------------------------------------------------------------------------
--   §1  Uzantılar: pg_net · pg_cron  (push ve zamanlanmış işlerin ön şartı)
--   §2  Tetikleyici: on_notification_created yerinde mi
--   §3  Token havuzu: kaç kullanıcıya ULAŞABİLİYORUZ
--   §4  İzin durumu dağılımı (verildi / reddedildi / sorulmadı)
--   §5  Son 7 günde yazılan bildirim × kategori — ve kaçı ulaşılabilir
--        bir kullanıcıya gitti
--   §6  Zamanlanmış işler
--   §7  API yüzeyi: anon'a açık fonksiyonlar ve tablo hakları
--   §8  RLS kapalı tablo var mı
--   §9  SECURITY DEFINER + search_path denetimi
--   §10 ÖZET — tek bakışta "sıkıntı var mı"
-- ============================================================================

do $rapor264$
declare
  v_net       boolean;
  v_cron      boolean;
  v_trg       boolean;
  v_tok_top   int;
  v_tok_akt   int;
  v_kul_ulas  int;
  v_kul_top   int;
  v_bild7     int;
  v_bild7_ul  int;
  v_anon_fn   int;
  v_anon_tbl  int;
  v_rls_yok   int;
  v_sp_yok    int;
  r           record;
  v_sorun     int := 0;
  v_uyari     int := 0;
begin
  raise notice '';
  raise notice '════════════════════════════════════════════════════════════════';
  raise notice ' LOUNGELINK · PUSH ve API SAĞLIK RAPORU';
  raise notice ' %', now();
  raise notice '════════════════════════════════════════════════════════════════';

  -- ══ §1 UZANTILAR ═══════════════════════════════════════════════════
  select exists (select 1 from pg_extension where extname = 'pg_net')  into v_net;
  select exists (select 1 from pg_extension where extname = 'pg_cron') into v_cron;

  raise notice '';
  raise notice '§1 UZANTILAR';
  if v_net then
    raise notice '   ✓ pg_net KURULU — push telefona çıkabilir.';
  else
    raise notice '   ✗ pg_net KURULU DEĞİL.';
    raise notice '     → TELEFONA HİÇBİR BİLDİRİM GİTMİYOR.';
    raise notice '     → App içi bildirim listesi çalışmaya devam ediyor;';
    raise notice '       yalnız telefonun kilit ekranına düşen kısım yok.';
    raise notice '     ÇÖZÜM: Supabase → Database → Extensions → pg_net → Enable';
    v_sorun := v_sorun + 1;
  end if;
  if v_cron then
    raise notice '   ✓ pg_cron KURULU — zamanlanmış işler koşabilir.';
  else
    raise notice '   ⚠ pg_cron KURULU DEĞİL — haftalık özet, oran-sınır';
    raise notice '     temizliği ve aylık plan kredisi ZAMANINDA koşmaz.';
    raise notice '     (Aylık kredi app açılışında da yerine oturuyor;';
    raise notice '      diğer ikisi hiç koşmaz.)';
    v_uyari := v_uyari + 1;
  end if;

  -- ══ §2 TETİKLEYİCİ ════════════════════════════════════════════════
  select exists (
    select 1 from pg_trigger tg
      join pg_class c on c.oid = tg.tgrelid
     where c.relname = 'notifications'
       and tg.tgname = 'on_notification_created'
       and not tg.tgisinternal) into v_trg;
  raise notice '';
  raise notice '§2 TETİKLEYİCİ';
  if v_trg then
    raise notice '   ✓ on_notification_created yerinde.';
  else
    raise notice '   ✗ on_notification_created YOK — bildirim yazılıyor ama';
    raise notice '     push gönderimi hiç tetiklenmiyor. 111 çalıştırılmamış.';
    v_sorun := v_sorun + 1;
  end if;

  -- ══ §3 TOKEN HAVUZU ═══════════════════════════════════════════════
  select count(*),
         count(*) filter (where coalesce(active, true)
                            and coalesce(token,'') like 'ExponentPushToken%')
    into v_tok_top, v_tok_akt from push_tokens;
  select count(distinct user_id) into v_kul_ulas from push_tokens
   where coalesce(active, true) and coalesce(token,'') like 'ExponentPushToken%';
  select count(*) into v_kul_top from users where deleted_at is null;

  raise notice '';
  raise notice '§3 ULAŞILABİLİRLİK';
  raise notice '   token kaydı        : % (aktif ve geçerli: %)', v_tok_top, v_tok_akt;
  raise notice '   ULAŞILABİLEN kişi  : % / %', v_kul_ulas, v_kul_top;
  if v_kul_top > 0 and v_kul_ulas = 0 then
    raise notice '   ✗ HİÇ KİMSEYE ULAŞAMIYORUZ. Ya kimse izin vermedi ya da';
    raise notice '     token kaydı çalışmıyor (save_push_token).';
    v_sorun := v_sorun + 1;
  elsif v_kul_top > 0 and v_kul_ulas::numeric / v_kul_top < 0.35 then
    raise notice '   ⚠ Ulaşılabilirlik %%%s — düşük. İzin isteme anını gözden geçir.',
      round(100.0 * v_kul_ulas / v_kul_top);
    v_uyari := v_uyari + 1;
  end if;

  -- ══ §4 İZİN DAĞILIMI ══════════════════════════════════════════════
  raise notice '';
  raise notice '§4 İZİN DURUMU';
  begin
    for r in
      select coalesce(durum,'(kayıt yok)') as durum, count(*) as n
        from push_permissions group by 1 order by 2 desc
    loop
      raise notice '   % %', rpad(r.durum, 16), r.n;
    end loop;
  exception when undefined_table then
    raise notice '   ⚠ push_permissions tablosu yok — izin ölçümü kapalı.';
    v_uyari := v_uyari + 1;
  end;

  -- ══ §5 SON 7 GÜN ══════════════════════════════════════════════════
  select count(*) into v_bild7 from notifications where created_at > now() - interval '7 days';
  select count(*) into v_bild7_ul
    from notifications n
   where n.created_at > now() - interval '7 days'
     and exists (select 1 from push_tokens t
                  where t.user_id = n.user_id and coalesce(t.active,true)
                    and coalesce(t.token,'') like 'ExponentPushToken%');
  raise notice '';
  raise notice '§5 SON 7 GÜN';
  raise notice '   yazılan bildirim              : %', v_bild7;
  raise notice '   telefona ÇIKABİLECEK olan     : %', v_bild7_ul;
  if v_bild7 > 0 and v_bild7_ul = 0 then
    raise notice '   ✗ Hiçbiri telefona çıkamadı (alıcıların token''ı yok).';
    v_sorun := v_sorun + 1;
  end if;
  for r in
    select category::text as k, count(*) as n
      from notifications where created_at > now() - interval '7 days'
     group by 1 order by 2 desc
  loop
    raise notice '     % %', rpad(r.k, 14), r.n;
  end loop;

  -- ══ §6 ZAMANLANMIŞ İŞLER ══════════════════════════════════════════
  raise notice '';
  raise notice '§6 ZAMANLANMIŞ İŞLER';
  if v_cron then
    begin
      for r in select jobname, schedule, active from cron.job order by jobname loop
        raise notice '   % % aktif=%', rpad(r.jobname,32), rpad(r.schedule,14), r.active;
      end loop;
    exception when others then
      raise notice '   ⚠ cron.job okunamadı (%).', sqlerrm;
    end;
  else
    raise notice '   — pg_cron yok, iş listesi boş.';
  end if;

  -- ══ §7 API YÜZEYİ ═════════════════════════════════════════════════
  -- 🔴 "anon" = giriş YAPMAMIŞ herkes. Buradaki her satır, internetteki
  -- herkesin çağırabileceği bir uç demektir. Sayının kendisi kötü değil
  -- (rehber ekranı bilerek açık) — GÖRÜNMEZ olması kötü.
  select count(*) into v_anon_fn
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and has_function_privilege('anon', p.oid, 'execute');
  select count(*) into v_anon_tbl
    from information_schema.role_table_grants
   where grantee = 'anon' and table_schema = 'public'
     and privilege_type in ('INSERT','UPDATE','DELETE');

  raise notice '';
  raise notice '§7 API YÜZEYİ (giriş yapmamış "anon")';
  raise notice '   anon çağırabildiği fonksiyon  : %', v_anon_fn;
  raise notice '   anon YAZABİLDİĞİ tablo hakkı  : %', v_anon_tbl;
  for r in
    select table_name, string_agg(privilege_type, ',' order by privilege_type) as h
      from information_schema.role_table_grants
     where grantee = 'anon' and table_schema = 'public'
       and privilege_type in ('INSERT','UPDATE','DELETE')
     group by table_name order by table_name
  loop
    raise notice '     ⚠ YAZMA: % %', rpad(r.table_name,24), r.h;
    v_uyari := v_uyari + 1;
  end loop;

  -- ══ §7b ANON GERÇEKTEN NE OKUYABİLİYOR ═══════════════════════════
  -- 🔴 §7 YETMEDİ VE BUNU ZOR YOLDAN ÖĞRENDİM. `anon`ın SELECT hakkı
  -- neredeyse her tabloda var; RLS açık olduğu için çoğunda 0 satır
  -- döner. Ama `availabilities` üzerinde `to public` yazılmış bir
  -- politika vardı ve anon **kim · hangi havalimanı · hangi saat ·
  -- hangi uçuş** bilgisini okuyabiliyordu.
  --
  -- Hak tablosuna bakmak yetmiyor; POLİTİKANIN KİME AÇIK olduğuna
  -- bakmak gerekiyor.
  --
  -- 🆕 SINIF: "RLS AÇIK OLMASI VERİNİN KORUNDUĞU ANLAMINA GELMEZ —
  -- KORUYAN ŞEY POLİTİKANIN KENDİSİDİR VE BİR POLİTİKA 'HERKESE AÇIK'
  -- OLARAK DA YAZILABİLİR."
  raise notice '';
  raise notice '§7b ANON OKUMA POLİTİKALARI';
  declare v_sizinti int := 0;
  begin
    for r in
      select tablename, policyname
        from pg_policies
       where schemaname = 'public' and 'public' = any(roles)
         and cmd in ('SELECT','ALL')
         and coalesce(qual,'') not like '%auth.uid()%'
       order by 1
    loop
      raise notice '   · %  (%)', rpad(r.tablename, 24), r.policyname;
      v_sizinti := v_sizinti + 1;
    end loop;
    if v_sizinti = 0 then
      raise notice '   ✓ Giriş yapmadan okunabilen tablo yok.';
    else
      raise notice '   ⚠ % tablo giriş yapmadan okunabiliyor.', v_sizinti;
      raise notice '     Katalog/sözlük ise sorun değil; KİŞİ taşıyorsa sızıntıdır.';
      raise notice '     (267 `availabilities` sızıntısını kapattı.)';
      v_uyari := v_uyari + 1;
    end if;
  end;

  -- ══ §8 RLS ════════════════════════════════════════════════════════
  select count(*) into v_rls_yok
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and not c.relrowsecurity
     and c.relname not like 'pg_%'
     and c.relname not like '\_\_%';
  raise notice '';
  raise notice '§8 RLS';
  if v_rls_yok = 0 then
    raise notice '   ✓ public şemasındaki her tabloda RLS açık.';
  else
    raise notice '   ✗ RLS KAPALI TABLO: %', v_rls_yok;
    for r in
      select c.relname
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
         and c.relname not like 'pg_%' and c.relname not like '\_\_%'
       order by 1
    loop
      raise notice '     - %', r.relname;
    end loop;
    v_sorun := v_sorun + 1;
  end if;

  -- ══ §9 SECURITY DEFINER + search_path ═════════════════════════════
  -- 🔴 `search_path` sabitlenmemiş bir SECURITY DEFINER fonksiyonu,
  -- arayan kişinin şema yolunu kullanır: saldırgan kendi şemasında sahte
  -- bir `users` tablosu tanımlayıp fonksiyonu kandırabilir.
  select count(*) into v_sp_yok
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}'))  cfg
                      where cfg like 'search_path=%');
  raise notice '';
  raise notice '§9 SECURITY DEFINER';
  if v_sp_yok = 0 then
    raise notice '   ✓ Hepsinde search_path sabitlenmiş.';
  else
    raise notice '   ✗ search_path SABİTLENMEMİŞ % fonksiyon:', v_sp_yok;
    for r in
      select p.proname
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname='public' and p.prosecdef
         and not exists (select 1 from unnest(coalesce(p.proconfig,'{}')) cfg
                          where cfg like 'search_path=%')
       order by 1 limit 20
    loop
      raise notice '     - %', r.proname;
    end loop;
    v_sorun := v_sorun + 1;
  end if;

  -- ══ §10 ÖZET ══════════════════════════════════════════════════════
  raise notice '';
  raise notice '════════════════════════════════════════════════════════════════';
  if v_sorun = 0 and v_uyari = 0 then
    raise notice ' ✓ SIKINTI YOK — push zinciri ve API yüzeyi temiz.';
  else
    raise notice ' SONUÇ: % kritik · % uyarı', v_sorun, v_uyari;
    if not v_net then
      raise notice '';
      raise notice ' ⚠️ EN ÖNEMLİSİ: pg_net kapalı. Bu açılmadan telefona';
      raise notice '    HİÇBİR bildirim gitmez — kodda ne yaparsak yapalım.';
      raise notice '    Supabase → Database → Extensions → pg_net → Enable';
    end if;
  end if;
  raise notice '════════════════════════════════════════════════════════════════';
  raise notice '';
end $rapor264$;


-- ============================================================================
-- ⚠️ SONUÇ TABLOSU  (29 Ağustos'ta EKLENDİ — ve neden gerekti)
--
-- 🔴 Bu dosyanın tamamı `raise notice` ile yazılmıştı. Supabase SQL Editor
-- notice'ları ayrı bir "Messages" panelinde gösterir; sonuç sekmesinde
-- HİÇBİR ŞEY görünmez. Yani en son çalıştırılması gereken sağlık raporu,
-- ekrana bakan biri için BOŞ bir sonuçtu.
--
-- Aynı hatayı bu turda üç dosyada birden yaptım. `sql_lint.py`e kural
-- olarak yazıldı: adında BAK/KONTROL/KARAR/RAPOR geçen ve hiçbir şeyi
-- DEĞİŞTİRMEYEN her dosya, cevabını SELECT ile vermek zorunda.
--
-- 🆕 SINIF: "BİR RAPOR, OKUNDUĞU YERDE GÖRÜNMÜYORSA RAPOR DEĞİLDİR."
-- ============================================================================
select
  (select count(*) from pg_extension where extname='pg_net')                    as "pg_net",
  (select count(*) from pg_extension where extname='pg_cron')                   as "pg_cron",
  (select count(*) from push_tokens)                                            as "kayıtlı push token",
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and has_function_privilege('anon', p.oid,'execute')) as "anon fonksiyon",
  (select count(*) from pg_policies
    where schemaname='public' and 'public'=any(roles)
      and coalesce(qual,'') not like '%auth.uid()%')                            as "anon okuma politikası",
  (select count(*) from pg_tables t where t.schemaname='public'
     and not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                      where n.nspname='public' and c.relname=t.tablename and c.relrowsecurity)) as "RLS kapalı tablo",
  (select count(*) from pg_indexes
    where schemaname='public' and indexname='uq_users_phone_kanonik')           as "telefon tekillik",
  (select count(*) from notifications where created_at > now() - interval '7 days') as "son 7 gün bildirim";

-- BEKLENEN (269/270 sonrası):
--   pg_net · pg_cron          → 1 / 1
--   kayıtlı push token        → v3.9.1 kurulup izin verilince > 0
--   anon fonksiyon            → ~19
--   anon okuma politikası     → yalnız gerekçeli sözlük tabloları (~5)
--   RLS kapalı tablo          → 0
--   telefon tekillik          → 1
