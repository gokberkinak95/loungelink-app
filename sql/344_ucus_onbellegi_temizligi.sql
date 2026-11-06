-- ============================================================================
-- 344 · UÇUŞ ÖNBELLEĞİ TEMİZLİĞİ   (6 Kasım 2026)
--
-- Ölçüm (aviationstack, TK1, 3 canlı çağrı): sağlayıcı tarihsiz sorguda 2 gün × 7 kayıt
-- döndürüyor (6 kod paylaşımı kopyası + 1 gerçek uçuş). BO rotası data[0]'ı yazıyordu:
-- TK1 için "Thai Airways / TG"; ayrıca dünün kaydı istenen tarihe yazılabiliyordu ve
-- işleten kodu küçük harfti ("tk"). Rota düzeltildi (BO 1.101.4); bu dosya eski kayıtları siler:
--   · ham kayıttaki sefer numarası satırın flight_no'su değilse,
--   · ham kayıttaki tarih satırın flight_date'i değilse.
-- Kalanlarda havayolu kodları büyük harfe çekilir. Silinen satır uygulama tarafından
-- gerektiğinde yeniden (doğru) çekilir.
-- Supabase SQL Editor'de tek parça; tekrar koşulabilir. Doğrulama: iki satır tamam = true.
-- ============================================================================
delete from public.flight_cache
 where source = 'aviationstack'
   and raw is not null
   and (upper(coalesce(raw->'flight'->>'iata', '')) <> upper(flight_no)
        or coalesce(raw->>'flight_date', '') <> flight_date::text);

update public.flight_cache
   set operating_iata = upper(operating_iata),
       airline_iata   = upper(airline_iata)
 where operating_iata <> upper(operating_iata) or airline_iata <> upper(airline_iata);

select 'önbellekte başka uçuşun / başka günün kaydı kalmadı' as kontrol,
       not exists (select 1 from public.flight_cache
                    where source = 'aviationstack' and raw is not null
                      and (upper(coalesce(raw->'flight'->>'iata','')) <> upper(flight_no)
                           or coalesce(raw->>'flight_date','') <> flight_date::text)) as tamam
union all select 'havayolu kodları büyük harf',
       not exists (select 1 from public.flight_cache
                    where operating_iata <> upper(operating_iata) or airline_iata <> upper(airline_iata));
