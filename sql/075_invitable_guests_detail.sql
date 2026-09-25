-- ============================================================
-- LoungeLink · 075_invitable_guests_detail.sql   (ÖNCE 075a ÇALIŞTIR)
--
-- MVP "Yayın & Davet" ekranında davet edilebilir misafir satırı
-- "Elif K. / Fintech · 6 oturum" formatında — yani MESLEK ve
-- TAMAMLANMIŞ OTURUM SAYISI gösteriliyor. invitable_guests bu iki
-- bilgiyi döndürmüyordu; app satırda yalnız isim gösterebiliyordu.
--
-- İki kolon eklendi: profession (profiles.profession),
-- sessions_count (misafirin tamamlanmış oturum sayısı).
-- 030'daki tüm davranış (soğuk-davet kaynağı: yalnız geçmiş
-- accepted/completed misafirler; foto gizlilik kuralı; davet durumu)
-- AYNEN korunur. BU DOSYA KENDİ KENDİNE YETER.
-- ============================================================

CREATE OR REPLACE FUNCTION public.invitable_guests(p_avail_id uuid)
RETURNS TABLE (guest_id uuid, name text, photo text, last_seen date, invite_status text,
               profession text, sessions_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return query
  select distinct r.guest_id, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false
              then p.photo_url else null end,
         max(a.avail_date) over (partition by r.guest_id),
         coalesce((select i.status::text from invites i
                    where i.guest_id = r.guest_id and i.avail_id = p_avail_id limit 1), 'none'),
         p.profession,
         -- misafirin tamamlanmış oturum sayısı (MVP: "· 6 oturum")
         (select count(*)::int from sessions s
           join requests r2 on r2.id = s.request_id
          where s.status = 'completed' and r2.guest_id = r.guest_id)
    from requests r
    join availabilities a on a.id = r.avail_id
    join profiles p on p.user_id = r.guest_id
   where a.host_id = v_uid and r.status in ('accepted','completed');
end $$;

grant execute on function public.invitable_guests(uuid) to authenticated;

-- DOĞRULAMA (ikisi de true dönmeli)
select (pg_get_function_result(p.oid) ilike '%profession%')    as "meslek_donuyor",
       (pg_get_function_result(p.oid) ilike '%sessions_count%') as "oturum_donuyor"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='invitable_guests';

select '075 OK - invitable_guests meslek + oturum sayisi donduruyor' as sonuc;
