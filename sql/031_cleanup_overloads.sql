-- ============================================================
-- LoungeLink · 031_cleanup_overloads.sql   ← 030'DAN SONRA ÇALIŞTIR
--
-- SORUN: "create or replace function" yalnızca AYNI imzayı değiştirir.
-- Parametre sayısı/tipi/adı değişince Postgres ESKİYİ SİLMEZ; yeni bir
-- aşırı yükleme (overload) yaratır. Bizde şunlar birikti:
--   discover_availabilities → 1, 3 ve 4 parametreli 3 sürüm
--   create_request          → 3 ve 4 parametreli 2 sürüm
--   send_connection         → aynı imza (sorun yok, replace oldu)
--   respond_connection      → (uuid,text) ESKİ + (uuid,boolean) YENİ
--
-- PostgREST hangisini çağıracağını seçemez:
--   "Could not choose the best candidate function"
-- → Keşfet ve Tanış ekranları çöker.
--
-- ÇÖZÜM: eski imzaları düşür. Aşağıdakiler idempotent (yoksa hata vermez).
-- ============================================================

-- ---- discover_availabilities: yalnız 030'daki (text,text,text,date) kalsın
drop function if exists public.discover_availabilities(text);
drop function if exists public.discover_availabilities(text, text, text);

-- ---- create_request: yalnız 026'daki (uuid,text,text,text) kalsın
drop function if exists public.create_request(uuid, text, text);

-- ---- respond_connection: ESKİ (uuid,text) sürümü düşür, 027'deki (uuid,boolean) kalsın
drop function if exists public.respond_connection(uuid, text);

-- ---- Diğer olası eskiler (varsa temizlensin; yoksa sessiz geçer)
drop function if exists public.send_connection(uuid, text);
drop function if exists public.partner_demand(uuid, date, date);

-- ============================================================
-- DOĞRULAMA — her fonksiyondan kaç sürüm kaldı?
-- Beklenen: hepsi 1
-- ============================================================
select p.proname as fonksiyon,
       count(*)  as surum_sayisi,
       string_agg(pg_get_function_identity_arguments(p.oid), '   |   ') as imzalar
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in (
     'discover_availabilities','discover_people','create_request','respond_request',
     'start_session','complete_session','send_connection','respond_connection',
     'redeem_reward','partner_demand','verify_otp','send_otp','change_plan',
     'send_invite','respond_invite','pending_actions','my_connections'
   )
 group by p.proname
 order by surum_sayisi desc, p.proname;

-- surum_sayisi > 1 olan varsa: yukarıdaki 'imzalar' sütunundan ESKİ olanı seçip
--   drop function public.<ad>(<imza>);
-- ile düşür. Örn: drop function public.discover_availabilities(text, text, text);
