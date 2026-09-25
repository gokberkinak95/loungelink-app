-- ============================================================
-- 040a — 040'TAN ÖNCE ÇALIŞTIR
--
-- 040 iki fonksiyonun İMZASINI değiştiriyor. Postgres'te
-- "create or replace function" parametre eklenince ESKİYİ SİLMEZ,
-- yeni bir aşırı yükleme (overload) yaratır → PostgREST
-- "Could not choose the best candidate function" ile patlar.
--
-- Bu yüzden önce eskileri düşürüyoruz.
-- Bu dosya geri dönüşsüz bir şey yapmaz: 040 hepsini yeniden yaratır.
-- ============================================================

-- create_availability: (uuid,text,date,time,time,int) -> 040'ta 8 parametre
drop function if exists public.create_availability(uuid, text, date, time, time, int);
drop function if exists public.create_availability(uuid, text, date, time, time, int, text, text);

-- discover_availabilities: 030'daki (text,text,text,date) — 040 aynı imzayla
-- yeniden tanımlıyor ama dönüş tablosuna kolon eklendiği için 42P13
-- ("cannot change return type") verir. Düşürmek şart.
drop function if exists public.discover_availabilities(text, text, text, date);
