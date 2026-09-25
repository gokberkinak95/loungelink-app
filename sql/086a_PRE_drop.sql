-- ============================================================
-- LoungeLink · 086a_PRE_drop.sql        (086'DAN HEMEN ÖNCE ÇALIŞTIR)
--
-- NEDEN VAR: 086 aşağıdaki fonksiyonların DÖNÜŞ İÇERİĞİNİ ve bazılarının
-- İMZASINI değiştiriyor. `create or replace` dönüş tipi değişince
-- 42P13 verir, imza değişince de ESKİ SÜRÜMÜ SİLMEZ — iki aşırı yükleme
-- birden kalır ve PostgREST "Could not choose the best candidate function"
-- der. Bu dosya eskileri temizler.
--
-- GÜVENLİ: bu fonksiyonların HİÇBİRİ uygulama tarafından çağrılmıyor
-- (app yalnız 44 RPC çağırıyor, hiçbiri bu listede değil). Backoffice
-- lounge-rules ekranı 086 ile birlikte güncelleniyor.
-- ============================================================

drop function if exists public.availability_rule_snapshot(uuid);
drop function if exists public.apply_rule_snapshot(uuid);
drop function if exists public.guest_flight_fits(uuid, text);
drop function if exists public.lounge_rule_check(text, uuid, text, text, text, text);
drop function if exists public.lounge_rules_health();

select '086a OK - eski kural fonksiyonlari dusuruldu, simdi 086 calistirilabilir' as sonuc;
