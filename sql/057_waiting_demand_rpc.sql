-- ============================================================
-- LoungeLink · 057_waiting_demand_rpc.sql
--
-- BÜYÜME MOTORU (#3, TALEP→ARZ yönü): host ilan açarken, o havalimanında
-- kendisini bekleyen guest sayısını görsün → "IST'te seni bekleyen 4 guest var,
-- hemen ilan aç" motivasyonu. İlk host'u ilk ilana çeviren sinyal.
--
-- waiting_demand(p_airport, p_date): verilen havalimanı/tarihte (tarih ops.)
-- aktif seyahati olan, staff/silinmemiş guest sayısı. Kendi seyahatini saymaz.
-- ============================================================
create or replace function public.waiting_demand(p_airport text, p_date date default null)
returns int language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_n int;
begin
  select count(distinct vs.user_id) into v_n
    from visits vs
    join users gu on gu.id = vs.user_id
   where vs.airport_code = p_airport
     and vs.visit_date >= current_date
     and (p_date is null or vs.visit_date = p_date)
     and vs.user_id <> v_uid
     and coalesce(gu.is_staff,false) = false
     and gu.deleted_at is null;
  return coalesce(v_n, 0);
end $$;

grant execute on function public.waiting_demand(text, date) to authenticated;

select '057 OK — waiting_demand(p_airport,p_date) hazır' as sonuc;
