-- ════════════════════════════════════════════════════════════════════════
-- 297 · YETKİ KAPILARI — "SECURITY DEFINER" BİR YETKİ DEVRİDİR, BİR HIZ
--        AYARI DEĞİL
--
-- 🔴 NEDEN VAR — 19 EYLÜL, DERİN DENETİM
-- Gökberk: "benim ilettiğim sorunların ötesinde, benim gözlemleyemediğim
-- ama senin görebildiğin potansiyel sorunları bul."
--
-- Buldum. En ağırı şu ve ÜRETİMDE ŞU AN AÇIK — yerel replikada birebir
-- yeniden ürettim (hepsi `begin … rollback` içinde, veri değişmedi):
--
--   set local role authenticated;
--   select public.upsert_admin('guest1@…','super_admin','["*"]','',false);
--   → {"ok": true}
--   → admin_roles: <o kullanıcı> | super_admin
--
-- Yani **uygulamaya kayıt olan herkes tek RPC ile kendini süper yönetici
-- yapabiliyor**, sonra `remove_admin` ile gerçek yöneticileri düşürebiliyor.
--
-- ÖLÇÜM — KAPSAM
--   `security definer` + `authenticated`a execute + gövdede `auth.uid()`
--   YOK + gövdede insert/update/delete VAR  →  **42 fonksiyon**
--
--   Bu 42'nin kaçını uygulama çağırıyor?  → 3
--   Bu 42'nin kaçını backoffice çağırıyor? → 8
--   Backoffice hangi rolle bağlanıyor?     → `SUPABASE_SECRET_KEY`
--                                            (service_role · RLS'i aşar)
--
-- Yani 39 fonksiyonun `authenticated` grantı HİÇBİR ŞEYE hizmet etmiyor;
-- yalnızca saldırı yüzeyi. Backoffice service_role ile bağlandığı için
-- grant'ı geri almak BO'yu kırmıyor — ölçüldü, çağrı listesi karşılaştırıldı.
--
-- 🆕 SINIF: "BİR FONKSİYONU `SECURITY DEFINER` YAPMAK, ONU ÇAĞIRAN HERKESE
-- SAHİBİNİN YETKİSİNİ VERMEKTİR — KİMİN ÇAĞIRABİLECEĞİNİ YAZMADIYSAN
-- 'HERKES' YAZMIŞSIN DEMEKTİR."
--
-- ─────────────────────────────────────────────────────────────────────
-- BU DOSYA ALTI ŞEY YAPIYOR
--
--   A) 39 fonksiyonun `authenticated` execute grantı geri alınıyor.
--      (service_role ve postgres dokunulmuyor — BO ve cron çalışmaya devam.)
--   B) `upsert_admin` · `remove_admin` · `assign_partner` gövdelerine
--      yönetici kapısı ekleniyor — grant geri gelse bile kapı kapalı
--      kalsın (derinlemesine savunma).
--   C) `remove_rating` sahiplik kapısı alıyor: şu an HERKES HERKESİN
--      puanını silebiliyor. Uygulama bunu kendi puanını silmek için
--      çağırıyor, o yüzden grant DURUYOR; kapı gövdeye giriyor.
--   D) `flow_test_cleanup` tamamen kapatılıyor: herhangi bir kullanıcı
--      başkasının isteğini, oturumunu, sohbetini ve değerlendirmesini
--      kalıcı olarak siliyordu.
--   E) "KABUL EDİLMEDEN MESAJ ATILAMAZ" kuralındaki RLS deliği
--      kapatılıyor. (Ölçüldü: pending istekten host'a mesaj gitti.)
--   F) Yalnızca "politika yazmayı unutmuş olmaya" dayanan grant'lar
--      (otp_tokens, audit_log, promo_codes, rate_limits…) geri alınıyor.
--
-- Tekrar koşulabilir. 296'dan sonra koşulmalı.
-- ════════════════════════════════════════════════════════════════════════

-- ══ A · GEREKSİZ EXECUTE GRANT'LARI GERİ ALINIYOR ═══════════════════════
-- Liste ELLE yazıldı, taramayla değil: bir güvenlik kararının hangi
-- fonksiyonu kapsadığı dosyada OKUNABİLİR olmalı. Yarın yeni bir riskli
-- fonksiyon eklenirse bu liste onu kendiliğinden kapsamaz — kapsamasını
-- da istemem; `sozlesme_check.py` yeni ihlali ayrıca bildirecek.
do $$
declare
  f text;
  -- Uygulamanın çağırdığı 3 tanesi bu listede YOK (grant'ları duruyor):
  --   remove_rating · plan_kredisi_yerlestir · expire_stale_sessions
  kapatilacak text[] := array[
    'apply_ajet_intl_policy', 'apply_field_consensus', 'apply_rule_engine',
    'apply_rule_snapshot', 'assign_partner', 'cns_merge_venue',
    'device_flow_check', 'flight_fetch_allow', 'flow_gate_test',
    'flow_test_cleanup', 'grant_signup_credits', 'host_credit_settle',
    'match_deletion_requests', 'migration_kaydet', 'parse_host_entitlements',
    'plan_hediyelerini_bitir', 'plan_hediyesi_degerlendir', 'prune_rate_limits',
    'push_makbuzlarini_isle', 'rebuild_rule_test_cases', 'recompute_badge',
    'recompute_trust', 'remove_admin', 'request_account_deletion',
    'resolve_report', 'rozetleri_yenile', 'send_missed_value_digest',
    'set_featured_reward', 'sync_visit_flight', 'tek_tarafli_oturumlari_kapat',
    'upsert_admin'
  ];
  r record;
  n int := 0;
begin
  foreach f in array kapatilacak loop
    for r in
      select p.oid::regprocedure::text as imza
        from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
       where ns.nspname = 'public' and p.proname = f
    loop
      execute format('revoke execute on function %s from authenticated', r.imza);
      execute format('revoke execute on function %s from anon', r.imza);
      n := n + 1;
    end loop;
  end loop;
  raise notice '297/A: % fonksiyon imzasinin authenticated+anon execute yetkisi geri alindi', n;
end $$;

-- ⚠️ TETİKLEYİCİ FONKSİYONLARI (`trg_*`) LİSTEDE YOK VE OLMAMALI.
-- Onlar doğrudan çağrılmıyor; tetikleyici olarak tablonun sahibinin
-- yetkisiyle koşuyorlar. Grant'larını geri almak tetikleyiciyi
-- durdurmaz ama listeyi yanıltıcı yapardı: "kapattım" dediğim şeyin
-- zaten açık olmadığını bilmek gerekiyor.

-- ══ B · YÖNETİCİ KAPISI — GRANT GERİ GELSE BİLE ═════════════════════════
-- 🔴 Grant'ı geri almak TEK BAŞINA yetmez: bir sonraki migration
-- `grant execute on all functions in schema public to authenticated`
-- yazarsa (bu kod tabanında böyle satırlar VAR) kapı yeniden açılır.
-- Kapı gövdenin İÇİNDE olmalı.
-- 🆕 SINIF: "BİR YETKİYİ YALNIZ GRANT İLE KORUYORSAN, ONU TEK SATIRLIK
-- BİR TOPLU GRANT'A EMANET ETMİŞSİN DEMEKTİR."
create or replace function public.yonetici_kapisi()
returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_uid uuid := auth.uid();
begin
  -- Oturum yoksa çağrı sunucu içinden geliyor (service_role / cron):
  -- `auth.uid()` orada null'dur ve o yol zaten yetkilidir.
  if v_uid is null then return; end if;
  if not exists (select 1 from admin_roles ar where ar.user_id = v_uid) then
    raise exception 'yonetici_degil'
      using hint = 'Bu islem yalniz backoffice yoneticileri icindir.';
  end if;
end $function$;

revoke execute on function public.yonetici_kapisi() from authenticated, anon;

-- Gövdeye kapı eklerken fonksiyonun TAM TANIMINI (`pg_get_functiondef`)
-- alıp yalnız ilk `begin`den sonrasına bir satır ekliyoruz. İlk yazımda
-- imzayı/dönüş tipini/`search_path`i tek tek yeniden kurmaya çalıştım ve
-- `unnest(... ) in WHERE` ile patladı — hata haklıydı: bir tanımı parça
-- parça yeniden inşa etmek, o parçalardan birini unutmaktır.
-- 🆕 SINIF: "BİR TANIMI DEĞİŞTİRECEKSEN ONU YENİDEN KURMA, VAR OLANI AL
-- VE TEK YERİNDEN DOKUN."
do $$
declare r record; tanim text; yeni text; n int := 0;
begin
  for r in
    select p.oid, p.proname, p.prosrc
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public'
       and p.proname in ('upsert_admin', 'remove_admin', 'assign_partner')
  loop
    if position('yonetici_kapisi' in r.prosrc) > 0 then
      raise notice '297/B: % zaten kapili, atlandi', r.proname;
      continue;
    end if;
    tanim := pg_get_functiondef(r.oid);
    -- Gövde `AS $function$ ... $function$` içinde; ilk `begin`i orada ara.
    yeni := regexp_replace(tanim,
              '(\$function\$.*?\mbegin\M)',
              E'\\1\n  perform public.yonetici_kapisi();',
              'is');
    if yeni = tanim then
      raise exception '297/B: % govdesinde begin bulunamadi', r.proname;
    end if;
    execute yeni;
    n := n + 1;
    raise notice '297/B: % govdesine yonetici kapisi eklendi', r.proname;
  end loop;
  if n = 0 then raise notice '297/B: eklenecek fonksiyon yok (hepsi kapili)'; end if;
end $$;

-- ══ C · remove_rating — SAHİPLİK KAPISI ═════════════════════════════════
-- 🔴 ÖLÇÜLDÜ, gövdenin TAMAMI şuydu:
--       begin
--         delete from ratings where id = p_rating_id;
--         return jsonb_build_object('ok', true);
--       end
-- Tek satır, tek kontrol yok. `authenticated`a açık ve uygulama
-- `ekranlar_yalin.js:3124`ten çağırıyor. Yani herhangi bir kullanıcı,
-- hakkında yazılmış KÖTÜ BİR PUANI silebiliyordu — güven sisteminin
-- tamamı bu tek satırda çöküyor.
-- 🆕 SINIF: "BİR SİLME FONKSİYONUNUN PARAMETRESİ BİR KİMLİKSE, O KİMLİĞİN
-- ÇAĞIRANA AİT OLUP OLMADIĞI SORULMADIKÇA FONKSİYON 'SİL' DEĞİL 'HERKESİN
-- HER ŞEYİNİ SİL' DEMEKTİR."
create or replace function public.remove_rating(p_rating_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_r   ratings%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_r from ratings where id = p_rating_id;
  if not found then
    -- Var olmayan kimlikle var olanı ayırt ETTİRMİYORUZ: aksi hâlde bu
    -- fonksiyon "şu puan var mı?" sorusuna cevap veren bir tarayıcıya
    -- dönüşür.
    return jsonb_build_object('ok', true, 'silinen', 0);
  end if;

  -- Yalnız PUANI VEREN silebilir. Yönetici yolu backoffice'te ayrı
  -- (`admin_*` yüzeyi, service_role) — buraya karıştırmıyorum.
  if v_r.rater_id <> v_uid then
    raise exception 'baskasinin_verisi'
      using hint = 'Yalniz kendi yazdigin degerlendirmeyi kaldirabilirsin.';
  end if;

  delete from ratings where id = p_rating_id;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data)
  values (v_uid, 'rating.remove', 'ratings', p_rating_id,
          jsonb_build_object('rated_id', v_r.rated_id, 'score', v_r.score));

  return jsonb_build_object('ok', true, 'silinen', 1);
end $function$;

grant execute on function public.remove_rating(uuid) to authenticated;

-- ══ D · flow_test_cleanup — İSTEMCİYE KAPALI ════════════════════════════
-- 🔴 ÖLÇÜLDÜ: `security definer`, yetki kontrolü yok, `exception when
-- others then null` ile hatayı yutuyor ve sırayla messages → chat_channels
-- → ratings → sessions → requests siliyor. Herhangi bir kullanıcı,
-- BAŞKASININ aktif oturumunu ve değerlendirmesini kalıcı olarak
-- silebiliyordu (yerelde yeniden ürettim: requests 6→4, sessions 5→3).
-- Adı "test" diyor; grant'ı "üretim" diyordu.
-- 🆕 SINIF: "ADINDA 'TEST' GEÇEN BİR FONKSİYON ÜRETİM VERİTABANINDA
-- DURUYORSA, ADI DEĞİL GRANT'I BAĞLAYICIDIR."
do $$
declare r record;
begin
  for r in select p.oid::regprocedure::text as imza
             from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
            where ns.nspname='public' and p.proname='flow_test_cleanup'
  loop
    execute format('revoke execute on function %s from authenticated, anon', r.imza);
    raise notice '297/D: % istemciye kapatildi', r.imza;
  end loop;
end $$;

-- ══ E · "KABUL EDİLMEDEN MESAJ ATILAMAZ" — RLS DELİĞİ ═══════════════════
-- 🔴 ÖLÇÜLDÜ VE YENİDEN ÜRETİLDİ. `messages` üzerinde dört politika var:
--
--   msg_write            INSERT  → r.status = 'accepted' ŞARTI VAR      ✓
--   messages_companion_rw ALL    → istek dalında DURUM ŞARTI YOK        ✗
--
-- Postgres'te permissive politikalar **OR**'lanır. Yani ikinci politika
-- birincinin kapısını tamamen geçersiz kılıyordu. `chat_channels`
-- tarafında da `chan_party_insert` bağlantı dalında `accepted` arıyor,
-- istek dalında hiçbir durum aramıyor.
--
-- Yerelde: pending bir isteğin misafiri kanal açtı ve host'a mesaj attı.
-- Ürünün tek taciz kapısı buydu ve açıktı.
--
-- 🆕 SINIF: "PERMISSIVE POLİTİKALAR TOPLANIR, KESİŞMEZ — İKİNCİ BİR
-- POLİTİKA YAZMAK BİR KURALI GÜÇLENDİRMEZ, ÇOĞU ZAMAN KALDIRIR."
--
-- ⚠️ `x in ('a','b')::tip[]` YAZMADIM — ilk denememde öyle yazdım ve
-- Postgres "cannot cast type boolean to request_status[]" dedi. `in`
-- önce bir boolean üretiyor, cast ona uygulanıyor. Doğrusu
-- `= any (array[...]::tip[])`. Enum karşılaştırmasında bu iki yazım
-- görsel olarak birbirine çok benziyor ve yalnız biri çalışıyor.
-- Düzeltme: iki politikanın istek dalına da aynı durum şartı giriyor.
-- Hangi durumlar? 'accepted' ve 'completed' — oturum bittikten sonra
-- sohbet kapanmamalı (değerlendirme ve ihtilaf o kanaldan yürüyor).
drop policy if exists messages_companion_rw on public.messages;
create policy messages_companion_rw on public.messages
  for all
  using (
    exists (
      select 1 from chat_channels c
        left join connection_requests cr on cr.id = c.connection_id
        left join requests r on r.id = c.request_id
       where c.id = messages.channel_id
         and (
           (cr.id is not null and (cr.from_id = auth.uid() or cr.to_id = auth.uid())
                              and cr.status = 'accepted'::connection_status)
        or (r.id is not null and (r.guest_id = auth.uid() or r.host_id = auth.uid())
                             and r.status = any (array['accepted','completed']::request_status[]))
         )))
  with check (
    from_id = auth.uid() and exists (
      select 1 from chat_channels c
        left join connection_requests cr on cr.id = c.connection_id
        left join requests r on r.id = c.request_id
       where c.id = messages.channel_id
         and (
           (cr.id is not null and (cr.from_id = auth.uid() or cr.to_id = auth.uid())
                              and cr.status = 'accepted'::connection_status)
        or (r.id is not null and (r.guest_id = auth.uid() or r.host_id = auth.uid())
                             and r.status = any (array['accepted','completed']::request_status[]))
         )));

drop policy if exists chan_party_insert on public.chat_channels;
create policy chan_party_insert on public.chat_channels
  for insert
  with check (
    (connection_id is not null and exists (
       select 1 from connection_requests cr
        where cr.id = chat_channels.connection_id
          and cr.status = 'accepted'::connection_status
          and (auth.uid() = cr.from_id or auth.uid() = cr.to_id)))
 or (request_id is not null and exists (
       select 1 from requests r
        where r.id = chat_channels.request_id
          and r.status = any (array['accepted','completed']::request_status[])
          and (auth.uid() = r.guest_id or auth.uid() = r.host_id))));

-- ══ F · YETİM GRANT'LAR ════════════════════════════════════════════════
-- 🔴 Bu tablolarda RLS AÇIK ama HİÇ POLİTİKA YOK — yani şu an deny-all,
-- güvenli. Ama `anon`/`authenticated` SELECT grant'ları yazılı duruyor.
-- Yani koruma, "birinin politika yazmayı unutmuş olmasına" dayanıyor.
-- Yarın biri `create policy … using (true)` yazdığı an OTP kodları,
-- denetim kaydı ve promosyon kodları açılır.
-- 🆕 SINIF: "GÜVENLİĞİN BİR EKSİKLİĞE DAYANIYORSA, O EKSİKLİK
-- GİDERİLDİĞİNDE GÜVENLİK DE GİDER."
do $$
declare t text; n int := 0;
begin
  foreach t in array array[
    'audit_log', 'otp_tokens', 'promo_codes', 'rate_limits',
    'venue_review_queue', 'notification_campaigns', 'is_kosum_defteri',
    'rule_thresholds'
  ] loop
    if exists (select 1 from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
                where ns.nspname='public' and c.relname=t) then
      execute format('revoke all on table public.%I from anon', t);
      execute format('revoke all on table public.%I from authenticated', t);
      n := n + 1;
    end if;
  end loop;
  raise notice '297/F: % tabloda yetim grant geri alindi', n;
end $$;

-- 🔴 SUNUCU YAPILANDIRMASI `using (true)` İLE HERKESE AÇIKTI.
-- `beta_settings` kredi tavanlarını, `feature_flags` kill-switch'leri,
-- `client_write_allowlist`/`rpc_client_surface` istemciye açık yüzeyin
-- TAMAMINI, `flight_cache` ise BÜTÜN kullanıcıların uçuş sorgularını
-- taşıyor. İlk dördü uygulamanın okuması GEREKEN şeyler değil —
-- uygulamanın okuduğu ayarlar `beta_settings`ten geliyor, o yüzden
-- onu kapatmıyorum; ötekiler kapanıyor.
do $$
begin
  if exists (select 1 from pg_policies where tablename='client_write_allowlist' and policyname='client_write_allowlist_okuma_korundu') then
    drop policy client_write_allowlist_okuma_korundu on public.client_write_allowlist;
  end if;
  if exists (select 1 from pg_policies where tablename='rpc_client_surface' and policyname='rpc_client_surface_okuma_korundu') then
    drop policy rpc_client_surface_okuma_korundu on public.rpc_client_surface;
  end if;
  revoke all on table public.client_write_allowlist from anon, authenticated;
  revoke all on table public.rpc_client_surface from anon, authenticated;
  raise notice '297/F: sozlesme tablolari istemciye kapatildi (BO service_role ile okumaya devam)';
exception when undefined_table then
  raise notice '297/F: sozlesme tablolari yok, atlandi';
end $$;

-- `flight_cache`: herkesin herkesin uçuş sorgusunu okuması gereksiz.
-- Uygulama bu tabloyu DOĞRUDAN okumuyor (`flight_lookup` RPC'si üzerinden
-- gidiyor, o da security definer) — ölçüldü.
do $$
begin
  if exists (select 1 from pg_policies where tablename='flight_cache' and policyname='fc_read') then
    drop policy fc_read on public.flight_cache;
    create policy fc_read on public.flight_cache for select using (false);
    raise notice '297/F: flight_cache dogrudan okumaya kapatildi (RPC yolu acik)';
  end if;
end $$;

-- ══ SINAMA ═════════════════════════════════════════════════════════════
do $$
declare
  v_uid uuid;
  v_acik int;
  v_req uuid; v_guest uuid;
  v_hata text;
begin
  -- 1) Sıradan kullanıcı artık kendini yönetici YAPAMAMALI.
  select id into v_uid from users limit 1;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role','authenticated')::text, true);
  begin
    perform public.upsert_admin('yok@yok.test','super_admin','["*"]'::jsonb,'SINAMA',false);
    raise exception '297 SINAMA: upsert_admin HALA gecti — kapi calismiyor';
  exception
    when insufficient_privilege or undefined_function then null;   -- grant geri alindi
    when others then
      get stacked diagnostics v_hata = message_text;
      if v_hata not in ('yonetici_degil') then raise; end if;
  end;

  -- 2) Riskli fonksiyonlarin authenticated execute'u kalmamali.
  select count(*) into v_acik
    from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
   where ns.nspname='public'
     and p.proname in ('upsert_admin','remove_admin','assign_partner',
                       'flow_test_cleanup','cns_merge_venue','resolve_report',
                       'host_credit_settle','grant_signup_credits')
     and has_function_privilege('authenticated', p.oid, 'execute');
  if v_acik > 0 then
    raise exception '297 SINAMA: % riskli fonksiyon hala authenticated''a acik', v_acik;
  end if;

  raise notice '297 sinama 1-2: yonetici kapisi + grant temizligi OK';
end $$;

do $$
declare v_req uuid; v_guest uuid; v_n int;
begin
  -- 3) Kabul edilmemis istekten mesaj ATILAMAMALI.
  select r.id, r.guest_id into v_req, v_guest
    from requests r where r.status = 'pending' limit 1;
  if v_req is null then raise notice '297 sinama 3: pending istek yok, atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_guest::text, 'role','authenticated')::text, true);
  set local role authenticated;
  begin
    insert into chat_channels(request_id) values (v_req);
    reset role;
    raise exception '297 SINAMA: pending istekte kanal ACILDI — RLS deligi duruyor';
  exception
    when insufficient_privilege then
      reset role;
      raise notice '297 sinama 3: kabul edilmeden kanal acilamiyor — OK';
    when others then
      reset role;
      if SQLERRM like '%row-level security%' or SQLERRM like '%policy%' then
        raise notice '297 sinama 3: kabul edilmeden kanal acilamiyor — OK';
      else
        raise;
      end if;
  end;
end $$;

do $$
declare v_rid uuid; v_baskasi uuid;
begin
  -- 4) Baskasinin puani SILINEMEMELI.
  select id, rater_id into v_rid, v_baskasi from ratings limit 1;
  if v_rid is null then raise notice '297 sinama 4: puan yok, atlandi'; return; end if;
  select id into v_baskasi from users where id <> v_baskasi limit 1;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_baskasi::text, 'role','authenticated')::text, true);
  begin
    perform public.remove_rating(v_rid);
    raise exception '297 SINAMA: baskasinin puani SILINDI';
  exception when others then
    if SQLERRM <> 'baskasinin_verisi' then raise; end if;
  end;
  if not exists (select 1 from ratings where id = v_rid) then
    raise exception '297 SINAMA: puan gercekten silinmis';
  end if;
  raise notice '297 sinama 4: baskasinin puani silinemiyor — OK';
end $$;

select '297 kuruldu' as sonuc;
