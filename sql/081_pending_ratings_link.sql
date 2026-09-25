-- ============================================================
-- LoungeLink · 081_pending_ratings_link.sql   (ÖNCE 081a ÇALIŞTIR)
--
-- 🔴 Gokberk (5 Ağu): "Ana sayfaya düşen ŞİMDİ PUANLA butonu çalışmıyor.
--    SONRA PUANLA'ya basınca oturum kayboluyor, sonra nereden bulacağım?"
--
-- İKİ AYRI KUSUR:
--  (1) pending_ratings yalnızca session_id döndürüyordu. Uygulama puanlama
--      ekranını sohbet üzerinden açıyor ve bunun için REQUEST kimliğine
--      ihtiyacı var — elinde olmadığı için buton hiçbir şey yapamıyordu.
--      Artık request_id + other_id + rolü de dönüyor.
--  (2) "Sonra puanla" (defer_rating) oturumu ana sayfadan kaldırıyor ama
--      onu tekrar bulmanın HİÇBİR YOLU yoktu. Yeni fonksiyon
--      unrated_sessions(): 24 saatlik itiraz penceresi içindeki, henüz
--      puanlanmamış TÜM oturumları döndürür — ertelenmiş olanlar DAHİL.
--      Uygulama bunu Oturum Geçmişi'nde "★ Puanla" rozeti olarak gösterir.
--      Böylece erteleme "kaybetme" değil, "sonra listeden bulma" olur.
-- ============================================================

create or replace function public.pending_ratings()
returns table (session_id uuid, request_id uuid, other_id uuid, other_name text,
               lounge text, completed_at timestamptz, i_am_host boolean)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select s.id, r.id,
         (case when r.guest_id = v_uid then r.host_id else r.guest_id end),
         p.name,
         coalesce(a.lounge_name, a.airport_code),
         s.completed_at,
         (r.host_id = v_uid)
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
    join profiles p on p.user_id = (case when r.guest_id = v_uid then r.host_id else r.guest_id end)
   where s.status = 'completed'
     and (r.guest_id = v_uid or r.host_id = v_uid)
     and s.completed_at > now() - interval '24 hours'
     and not exists (select 1 from ratings rt where rt.session_id = s.id and rt.rater_id = v_uid)
     and not (coalesce(s.rate_deferred_by,'{}') @> array[v_uid])
   order by s.completed_at desc;
end $$;
grant execute on function public.pending_ratings() to authenticated;


-- ERTELENMİŞLER DAHİL: "hâlâ puanlayabileceğim oturumlar"
create or replace function public.unrated_sessions()
returns table (session_id uuid, request_id uuid, other_id uuid, other_name text,
               lounge text, completed_at timestamptz, deferred boolean, hours_left numeric)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select s.id, r.id,
         (case when r.guest_id = v_uid then r.host_id else r.guest_id end),
         p.name,
         coalesce(a.lounge_name, a.airport_code),
         s.completed_at,
         (coalesce(s.rate_deferred_by,'{}') @> array[v_uid]),
         round(extract(epoch from (s.completed_at + interval '24 hours' - now())) / 3600.0, 1)
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
    join profiles p on p.user_id = (case when r.guest_id = v_uid then r.host_id else r.guest_id end)
   where s.status = 'completed'
     and (r.guest_id = v_uid or r.host_id = v_uid)
     and s.completed_at > now() - interval '24 hours'
     and not exists (select 1 from ratings rt where rt.session_id = s.id and rt.rater_id = v_uid)
   order by s.completed_at desc;
end $$;
grant execute on function public.unrated_sessions() to authenticated;


-- DOĞRULAMA (ikisi de true dönmeli)
select (pg_get_function_result(p.oid) ilike '%request_id%') as "puanlama_isteğe_bagli"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='pending_ratings';
select exists (select 1 from pg_proc where proname='unrated_sessions') as "ertelenmisler_bulunabilir";

select '081 OK - puanlama bekleyen oturumlar sohbete baglanabilir, ertelenenler bulunabilir' as sonuc;
