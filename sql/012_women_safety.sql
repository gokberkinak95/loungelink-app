-- ============================================================
-- LoungeLink · 012_women_safety.sql — Kadın Güvenlik Modu
-- Çift yönlü kural (DB seviyesinde, sadece UI değil):
--  (A) Modu açan kadın, keşifte YALNIZCA doğrulanmış kadınlara görünür.
--  (B) Modu açan kadın, keşifte YALNIZCA kadın host'ların ilanlarını görür.
-- Güvenlik: gender bilgisi users tablosunda; istemciye açılmaz.
--           Keşif artık güvenli bir RPC üzerinden döner.
-- ============================================================

-- 1) Keşif fonksiyonu: çağıranın cinsiyet/güvenlik durumuna göre filtreler
create or replace function public.discover_availabilities(p_airport text default null)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_female boolean;
  v_safe boolean;
begin
  select (u.gender = 'female'), coalesce(pr.women_safety_mode, false)
    into v_female, v_safe
    from users u left join profiles pr on pr.user_id = u.id
   where u.id = v_uid;

  return query
  -- 🔴 18 Ağustos: `availabilities.airport_code` CHAR(3), burada `text`
  -- diye ilan ediliyor. Cast olmadan, fonksiyon BİR SATIR DÖNDÜĞÜ ANDA
  -- 42804 verir. 186'da aynı hata canlıda patladı; bu ikinci vakayı
  -- `tip_check.py` buldu — kimse çağırmadığı için henüz patlamamıştı.
  -- Sonraki bir migration `discover_availabilities`i cast'li yeniden
  -- tanımlıyor, o yüzden bugün zararsız; ama 012'yi tek başına çalıştıran
  -- biri (ya da o sürümde veri olan biri) patlardı.
  select a.id, a.host_id, a.airport_code::text, a.lounge_name,
         a.avail_date, a.time_from, a.time_to, a.flight_number,
         a.slots::int, a.filled::int, p.name, ts.badge, ts.score
    from availabilities a
    join users hu on hu.id = a.host_id
    join profiles p on p.user_id = a.host_id
    left join trust_scores ts on ts.user_id = a.host_id
   where a.active = true
     and a.visibility = 'Public'
     and (p_airport is null or a.airport_code = p_airport)
     -- Host'un kendi görünürlük tercihi
     and coalesce(p.show_on_discovery, true) = true
     -- (B) Çağıran kadın+güvenlik modundaysa: yalnız kadın host'lar
     and (not (v_female and v_safe) or hu.gender = 'female')
     -- (A) Host kadın+güvenlik modundaysa: yalnız doğrulanmış kadınlara görünür
     and (
       not coalesce(p.women_safety_mode, false)
       or (v_female and exists (select 1 from verifications v where v.user_id = v_uid and v.phone_verified))
     )
   order by a.avail_date, a.time_from
   limit 100;
end $$;

grant execute on function public.discover_availabilities(text) to authenticated;

select 'WOMEN SAFETY OK' as sonuc;
