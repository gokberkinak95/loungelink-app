-- ============================================================
-- LoungeLink · 026a_PRE_drop.sql
-- ⚠ 026'DAN **ÖNCE** ÇALIŞTIR
--
-- NEDEN: 026, bazı fonksiyonları yeniden tanımlıyor ama parametre
-- varsayılanları / dönüş tipleri değişmiş. Postgres bunlara izin vermez:
--   ERROR 42P13: cannot remove parameter defaults from existing function
--   ERROR 42P13: cannot change return type of existing function
--
-- Örnek: 015'te send_connection(uuid, text DEFAULT null, text DEFAULT null)
--        026'da send_connection(uuid, text, text default null)  ← default kalktı
--
-- ÇÖZÜM: eski sürümleri düşür, 026 temiz kursun.
-- Bu dosya idempotenttir (fonksiyon yoksa sessizce geçer).
-- Düşürülenlerin HEPSİ 026 içinde yeniden yaratılıyor — veri kaybı yok.
-- ============================================================

drop function if exists public.send_connection(uuid, text, text);
drop function if exists public.send_connection(uuid, text);
drop function if exists public.start_session(uuid);
drop function if exists public.verify_otp(text, text);
drop function if exists public.change_phone(text);
drop function if exists public.grant_consents(text[], text);
drop function if exists public.publish_availability(text, uuid, text, date, time, time, int, text, text);

-- Eski create_request sürümleri (007/009). 026 yeni 4-parametreli sürümü kurar.
drop function if exists public.create_request(uuid, text, text);
drop function if exists public.create_request(uuid, text);
drop function if exists public.create_request(uuid);

-- Doğrulama: bu fonksiyonlardan geriye HİÇBİRİ kalmamalı (boş sonuç = doğru)
select p.proname, pg_get_function_identity_arguments(p.oid) as imza
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('send_connection','start_session','verify_otp','create_request',
                     'change_phone','grant_consents','publish_availability');

-- Bos dondu mu? Simdi 026'yi calistir.
