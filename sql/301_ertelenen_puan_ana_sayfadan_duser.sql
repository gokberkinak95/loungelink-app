-- ============================================================================
-- 301 · ERTELENEN PUAN ANA SAYFADAN DÜŞER                         (26 Eylül)
--
-- 🔴 NEDEN: Ana sayfadaki "Son oturumunu puanla" kartında "Sonra"ya basınca
-- `defer_rating` oturumu `sessions.rate_deferred_by`e yazıyordu — ama kartı
-- besleyen `pending_ratings()` bu kolona HİÇ bakmıyordu. Kart yeniden
-- yükleniyor, aynı oturum geri geliyordu: kullanıcı için "Sonra çalışmıyor".
-- (Gökberk md.2 · cihazda görüldü.)
--
-- `pending_ratings()`in tek istemcisi ana sayfa kartı (RateReminder).
-- Değerlendirmeler > Bekleyen kendi sorgusunu kullanıyor ve ertelenen
-- oturumu göstermeye DEVAM EDİYOR — istenen tam olarak bu: "ana sayfadan
-- gitmeli ama bekleyen sekmesinde kalmalı".
-- İmza değişmiyor (aşırı yükleme yok, izinler ve rpc_client_surface aynen).
-- ============================================================================
create or replace function public.pending_ratings()
returns table (
  session_id uuid, request_id uuid, other_id uuid, other_name text,
  lounge text, completed_at timestamptz, i_am_host boolean,
  airport_code text, avail_date date, time_from time, time_to time,
  flight_number text, carrier text
)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare v_uid uuid := auth.uid();
begin
  return query
  select s.id, r.id,
         case when r.host_id = v_uid then r.guest_id else r.host_id end,
         coalesce(p.name, 'Yolcu'),
         coalesce(a.lounge_name, a.airport_code::text),
         s.completed_at,
         (r.host_id = v_uid),
         a.airport_code::text,
         a.avail_date, a.time_from, a.time_to,
         a.flight_number, a.carrier
    from sessions s
    join requests r on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join profiles p
      on p.user_id = case when r.host_id = v_uid then r.guest_id else r.host_id end
   where s.status = 'completed'
     and (r.host_id = v_uid or r.guest_id = v_uid)
     and not (coalesce(s.rate_deferred_by, '{}') @> array[v_uid])   -- 301
     and not exists (select 1 from ratings rt
                      where rt.session_id = s.id and rt.rater_id = v_uid)
   order by s.completed_at desc nulls last
   limit 20;
end $function$;
