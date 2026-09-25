-- ============================================================================
-- 265 — API YÜZEYİ KAPANIŞI  (28 Ağustos 2026)
--
-- ⚠️ CANLIDA DURAN BİR AÇIĞI KAPATIYOR. 264'ü ÖNCE çalıştır (rapor),
--    sonra bunu. Bu dosya SONUNDA kendi kendini doğruluyor.
--
-- ----------------------------------------------------------------------------
-- 🔴 BULGU — ÖLÇÜLDÜ VE SÖMÜRÜLDÜ
-- ----------------------------------------------------------------------------
-- Gökberk (28 Ağustos): "api yapıları, token kontrolleri konusunda emin
-- olmanı istiyorum. Bi sıkıntı yaşamayalım."
--
-- Ölçtüm. Yerel replikada `set role anon` ile:
--
--     anon (GİRİŞ YAPMAMIŞ HERKES) 184 fonksiyonu çağırabiliyor.
--     Bunların 64'ünde `auth.uid()` kontrolü HİÇ YOK.
--
-- Ve bu bir teori değil; çalıştırdım:
--
--     set role anon;
--     select public.zamanli_is_kos('bayat_istekleri_iade_et');
--     → {"ok": true, "esik_saat": 72, "iade_edilen": 0}
--
--     select public.zamanli_is_kos('push_makbuzlarini_isle');
--     → {"ok": true, "islenen": 0, ...}
--
-- Yani **internetteki herkes**, uygulamanın içine gömülü olan (ve gömülmek
-- ZORUNDA olan) publishable anahtarla, tablo geneli bakım işlerini istediği
-- kadar tetikleyebiliyordu. Bir döngüde çağrıldığında bu bir hizmet
-- kesintisi saldırısıdır ve fatura bize gelir.
--
-- Aynı kapıdan `bo_finance_ozet` (platformun para özeti),
-- `bo_carrier_kullanim`, `bo_lounge_kullanim` de geçiyordu — üçünde de
-- yönetici kontrolü yok. Sonuncu ikisini ve finans özetini BU PROJEDE BEN
-- yazdım (BO performans turu) ve `service_role`a kısıtlamayı unuttum.
--
-- ----------------------------------------------------------------------------
-- 🔴 SEBEP: POSTGRES'İN VARSAYILANI
-- ----------------------------------------------------------------------------
-- Postgres yeni bir fonksiyon oluşturulduğunda `EXECUTE` hakkını
-- **PUBLIC**'e verir. Supabase'in `anon` ve `authenticated` rolleri
-- PUBLIC'ten miras alır. Yani:
--
--     "grant execute ... to authenticated" YAZMASAN DA erişilebilir.
--
-- SQL 241 ve 253 bu projede tablo YAZMA haklarını kapattı ve doğru yaptı.
-- Ama ikisi de FONKSİYON EXECUTE varsayılanına dokunmadı. `grant` satırı
-- yazdığımız 15 fonksiyonu düşünüp, yazmadığımız 424'ünü hiç düşünmedik.
--
-- 🆕 SINIF: "BİR HAKKI AÇIKÇA VERDİĞİN YERLERİ SAYMAK, O HAKKIN
-- VARSAYILAN OLARAK ZATEN VERİLDİĞİ YERLERİ SAYMAZ — GÜVENLİK
-- DENETİMİ 'NE VERDİM' DEĞİL 'KİM ERİŞEBİLİYOR' SORUSUYLA YAPILIR."
--
-- ----------------------------------------------------------------------------
-- YAKLAŞIM: BEYAZ LİSTE
-- ----------------------------------------------------------------------------
-- Tek tek 64 fonksiyona `auth.uid()` kontrolü eklemek yanlış olurdu:
-- (a) 64 ayrı davranış değişikliği = 64 ayrı regresyon riski,
-- (b) 65'inciyi yazdığımız gün aynı delik geri gelir.
--
-- Onun yerine kapıyı kapatıyoruz ve AÇIKÇA açtıklarımızı listeliyoruz.
-- Yeni yazılan her fonksiyon varsayılan olarak KAPALI doğar.
--
-- ⚠️ UYGULAMA BOZULMAZ: app'in çağırdığı 145 RPC'nin tamamı ölçüldü;
-- hepsi `authenticated`a veriliyor. Rehber ekranı giriş yapmadan
-- çalışmaya devam ediyor (anon beyaz listesi).
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — KAPIYI KAPAT
-- ════════════════════════════════════════════════════════════════════════
revoke execute on all functions in schema public from public;
revoke execute on all functions in schema public from anon;

-- Bundan SONRA oluşturulacak fonksiyonlar için de varsayılanı kapat.
-- 🔴 BU SATIR OLMADAN düzeltme YARIM kalır: bugün kapatırız, yarın
-- yazılan `266_x.sql` deliği geri açar ve kimse fark etmez.
alter default privileges in schema public revoke execute on functions from public;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — GİRİŞ YAPMIŞ KULLANICI: HER ŞEY (bo_ ve iç işler HARİÇ)
--
-- Neden hepsi: bu fonksiyonların tamamı zaten ya `auth.uid()` kontrolü
-- yapıyor ya da RLS'in arkasında okuma yapıyor. Amaç davranışı
-- DEĞİŞTİRMEK değil, giriş yapmamış kişiyi dışarıda bırakmak.
-- ════════════════════════════════════════════════════════════════════════
do $g265$
declare r record; n int := 0;
begin
  for r in
    select p.oid::regprocedure as imza, p.proname
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public'
       and p.prokind = 'f'
       -- Backoffice: yalnız service_role.
       and p.proname not like 'bo\_%'
       -- Zamanlanmış iş koşucusu: yalnız cron/service_role (bkz. §4).
       and p.proname <> 'zamanli_is_kos'
       -- Tetikleyici fonksiyonları: EXECUTE hakkı gerektirmezler.
       and p.prorettype <> 'trigger'::regtype
  loop
    execute format('grant execute on function %s to authenticated', r.imza);
    n := n + 1;
  end loop;
  raise notice '265 §2: % fonksiyon authenticated''a verildi.', n;
end $g265$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — BACKOFFICE: YALNIZ service_role
--
-- 🔴 `bo_finance_ozet` platformun para özetini döndürüyor ve giriş yapmış
-- HERKESE açıktı. Onu bu projede ben yazdım (BO performans turu, 260) ve
-- kısıtlamayı unuttum. `bo_carrier_kullanim` / `bo_lounge_kullanim` de aynı.
--
-- 🆕 SINIF: "BİR FONKSİYONU 'BACKOFFICE İÇİN' YAZMAK ONU BACKOFFICE'E
-- KISITLAMAZ — ADLANDIRMA BİR YETKİ DEĞİLDİR."
-- ════════════════════════════════════════════════════════════════════════
do $bo265$
declare r record; n int := 0;
begin
  for r in
    select p.oid::regprocedure as imza
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public' and p.proname like 'bo\_%' and p.prokind = 'f'
  loop
    execute format('revoke execute on function %s from authenticated, anon, public', r.imza);
    execute format('grant  execute on function %s to service_role', r.imza);
    n := n + 1;
  end loop;
  raise notice '265 §3: % bo_ fonksiyonu service_role''a kilitlendi.', n;
end $bo265$;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — ZAMANLANMIŞ İŞ KOŞUCUSU
--
-- Sömürülen fonksiyon buydu. Artık yalnız `service_role` (ve postgres
-- kullanıcısı olarak koşan pg_cron) çağırabilir.
-- ════════════════════════════════════════════════════════════════════════
do $z265$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='zamanli_is_kos') then
    revoke execute on function public.zamanli_is_kos(text) from public, anon, authenticated;
    grant  execute on function public.zamanli_is_kos(text) to service_role;
    raise notice '265 §4: zamanli_is_kos service_role''a kilitlendi.';
  end if;
end $z265$;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — ANON BEYAZ LİSTESİ
--
-- Giriş YAPMADAN çalışması GEREKEN yüzeyler. Her satırın bir gerekçesi
-- var; gerekçesi olmayan satır buraya girmez.
--
--   guide_*            → Salon Rehberi: kayıt olmadan denenebilen tek
--                        ekran (app v3.6'da splash'ten açılıyor). Ürünün
--                        ilk izlenimi ve SEO yüzeyi.
--   resolve_guest_rule → Rehberin kural cevabı; rehber onsuz susar.
--   best_entitlement   → Aynı zincir.
--   entry_cost_note / guide_cost → Rehberde giriş bedeli cümlesi.
--   lounges_for_airport/ amenities_for / amenity_key_options → Rehber katalog.
--   phone_in_use       → Kayıt formunda "bu numara zaten kayıtlı" kontrolü;
--                        yalnız BOOLEAN döner, kimlik sızdırmaz.
--   request_account_deletion → Google Play ZORUNLU tutuyor ve kullanıcı
--                        giriş yapamıyor olabilir. Silmiyor, TALEP kaydediyor.
--   kurucu_cember / yayindaki_host_hikayeleri → Web sitesindeki vitrin.
--   i18n_overrides / i18n_version → Metin paketleri; giriş öncesi ekranlar da
--                        okuyor.
--   client_flags / service_endpoints → Açılış yapılandırması.
-- ════════════════════════════════════════════════════════════════════════
do $a265$
declare
  v_ad text;
  v_liste text[] := array[
    'guide_airports', 'guide_lounges', 'guide_programs', 'guide_hosts_today',
    'guide_cost', 'entry_cost_note', 'resolve_guest_rule', 'best_entitlement',
    'lounges_for_airport', 'amenities_for', 'amenity_key_options',
    'phone_in_use', 'request_account_deletion',
    'kurucu_cember', 'yayindaki_host_hikayeleri',
    'i18n_overrides', 'i18n_version', 'client_flags', 'service_endpoints'
  ];
  r record; n int := 0;
begin
  foreach v_ad in array v_liste loop
    for r in
      select p.oid::regprocedure as imza
        from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
       where ns.nspname = 'public' and p.proname = v_ad and p.prokind = 'f'
    loop
      execute format('grant execute on function %s to anon, authenticated', r.imza);
      n := n + 1;
    end loop;
  end loop;
  raise notice '265 §5: % anon ucu beyaz listede.', n;
end $a265$;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — RLS AÇIK OLMAYAN TABLOLAR
--
-- 264 iki tane buldu. İkisi de iç tablo ama "iç" bir yetki değildir:
-- PostgREST şemadaki her tabloyu bir uç noktaya çevirir.
-- ════════════════════════════════════════════════════════════════════════
do $rls265$
declare r record; n int := 0;
begin
  for r in
    select c.relname
      from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
     where ns.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
       and c.relname not like 'pg\_%'
  loop
    execute format('alter table public.%I enable row level security', r.relname);
    -- Politika YOK = yalnız service_role ve security definer erişir.
    execute format('revoke all on public.%I from anon, authenticated', r.relname);
    n := n + 1;
    raise notice '265 §6: RLS açıldı → %', r.relname;
  end loop;
  if n = 0 then raise notice '265 §6: RLS zaten her tabloda açık.'; end if;
end $rls265$;

-- ════════════════════════════════════════════════════════════════════════
-- §7 — ANONİM YAZMANIN SINIRI
--
-- `waitlist` ve `deletion_requests` anonim INSERT kabul ediyor (ikisi de
-- gerekli). Ama sınırsız: aynı anonim çağrı milyonlarca satır yazabilir.
--
-- Postgres tarafında IP göremiyoruz (PostgREST iletmiyor), o yüzden
-- oran sınırı kuramıyoruz. Kurabileceğimiz şey TEKİLLİK: aynı e-posta
-- ikinci kez sıraya giremez. Bu, saldırıyı "sonsuz satır"dan "sahip
-- olduğun farklı e-posta sayısı"na indirir.
--
-- 🆕 SINIF: "ORAN SINIRI KURAMADIĞIN YERDE TEKİLLİK KUR — SINIRSIZI
-- SAYILABİLİR YAPMAK, SINIRLAMANIN İLK ADIMIDIR."
-- ════════════════════════════════════════════════════════════════════════
do $w265$
begin
  if to_regclass('public.waitlist') is not null then
    begin
      create unique index if not exists uq_waitlist_email
        on waitlist ((lower(email)));
      raise notice '265 §7: waitlist e-posta tekilleştirildi.';
    exception when others then
      raise notice '265 §7: waitlist tekilleştirilemedi (% ) — mükerrer kayıt var olabilir.', sqlerrm;
    end;
  end if;
  if to_regclass('public.deletion_requests') is not null then
    begin
      create unique index if not exists uq_delreq_bekleyen
        on deletion_requests ((lower(email))) where status = 'pending';
      raise notice '265 §7: bekleyen silme talebi e-posta başına tekil.';
    exception when others then
      raise notice '265 §7: silme talebi tekilleştirilemedi (%).', sqlerrm;
    end;
  end if;
end $w265$;

-- ════════════════════════════════════════════════════════════════════════
-- §8 — NÖBETÇİ: KAPI GERÇEKTEN KAPANDI MI
--
-- 🔴 "grant/revoke yazdım" ile "erişim kapandı" aynı şey değildir.
-- Nöbetçi hak tablosunu değil ERİŞİMİ soruyor: `has_function_privilege`.
-- ════════════════════════════════════════════════════════════════════════
do $nb265$
declare
  v_anon_toplam int;
  v_anon_korumasiz int;
  v_bo_auth int;
  v_app_eksik int;
  v_rls_yok int;
  r record;
  v_izinli text[] := array[
    'guide_airports','guide_lounges','guide_programs','guide_hosts_today',
    'guide_cost','entry_cost_note','resolve_guest_rule','best_entitlement',
    'lounges_for_airport','amenities_for','amenity_key_options',
    'phone_in_use','request_account_deletion','kurucu_cember',
    'yayindaki_host_hikayeleri','i18n_overrides','i18n_version',
    'client_flags','service_endpoints'];
begin
  select count(*) into v_anon_toplam
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.prokind='f'
     and has_function_privilege('anon', p.oid, 'execute');

  select count(*) into v_anon_korumasiz
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.prokind='f'
     and has_function_privilege('anon', p.oid, 'execute')
     and not (p.proname = any(v_izinli));

  select count(*) into v_bo_auth
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname like 'bo\_%'
     and has_function_privilege('authenticated', p.oid, 'execute');

  select count(*) into v_rls_yok
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
     and c.relname not like 'pg\_%';

  if v_anon_korumasiz > 0 then
    for r in
      select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.prokind='f'
         and has_function_privilege('anon', p.oid,'execute')
         and not (p.proname = any(v_izinli))
       order by 1 limit 15
    loop
      raise notice '   ✗ anon hâlâ çağırabiliyor: %', r.proname;
    end loop;
    raise exception '265 NOBETCI: beyaz liste disinda % fonksiyon anon''a acik.', v_anon_korumasiz;
  end if;

  if v_bo_auth > 0 then
    raise exception '265 NOBETCI: % adet bo_ fonksiyonu hala authenticated''a acik.', v_bo_auth;
  end if;

  if has_function_privilege('anon', 'public.zamanli_is_kos(text)', 'execute') then
    raise exception '265 NOBETCI: zamanli_is_kos hala anon''a acik — somurulen kapi.';
  end if;

  if v_rls_yok > 0 then
    raise exception '265 NOBETCI: % tabloda RLS kapali.', v_rls_yok;
  end if;

  -- 🔴 VE TERS YÖN: kapıyı kapatırken uygulamayı kilitledik mi?
  -- `authenticated` app'in çağırdığı her RPC'yi çağırabilmeli. Burada
  -- örnek olarak en kritik 12'si sorgulanıyor; biri bile düşerse
  -- migration geri alınır.
  select count(*) into v_app_eksik
    from unnest(array[
      'create_request','respond_request','discover_availabilities',
      'ana_sayfa_akisi','request_precheck','my_host_access',
      'save_push_token','push_izni_bildir','sorularim',
      'home_connections','pending_actions','havalimani_nabzi']) as f(ad)
   where not exists (
     select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname = f.ad
        and has_function_privilege('authenticated', p.oid, 'execute'));
  if v_app_eksik > 0 then
    raise exception '265 NOBETCI: % kritik RPC authenticated icin KAPALI — app kirilir.', v_app_eksik;
  end if;

  raise notice '265 NOBETCI OK: anon yuzeyi % fonksiyon (beyaz liste), bo_ kapali, zamanli_is_kos kapali, RLS tam, app RPC''leri acik.',
    v_anon_toplam;
end $nb265$;

commit;
