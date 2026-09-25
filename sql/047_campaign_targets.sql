-- ============================================================
-- LoungeLink · 047_campaign_targets.sql   (ÖNCE 047a çalıştır)
--
-- 1) send_campaign'e KİŞİ BAZLI hedefleme: p_user_ids uuid[] verilirse
--    segment yerine tam o kullanıcılara gider (BO'da e-posta ile seçim).
-- 2) 🔴 DÜZELTME: 029'un gövdesi is_staff'ı hiç filtrelemiyordu —
--    041 staff hesaplarını üründen dışladı ama kampanyalar BO
--    adminlerine de gidiyordu. Artık her iki yolda da staff hariç.
-- Gövde bunun dışında 029 ile BİREBİR aynı (okunarak korundu).
-- ============================================================

create or replace function public.send_campaign(
  p_title text, p_body text, p_segment jsonb, p_admin uuid,
  p_user_ids uuid[] default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_n int := 0;
begin
  insert into notification_campaigns (title, body, segment, created_by)
  values (p_title, p_body, coalesce(p_segment,'{}'::jsonb), p_admin) returning id into v_cid;

  if p_user_ids is not null and array_length(p_user_ids, 1) > 0 then
    -- KİŞİ BAZLI: seçilen kullanıcılar (silinmiş ve staff hariç)
    with target as (
      select u.id from users u
      where u.id = any(p_user_ids)
        and u.deleted_at is null
        and coalesce(u.is_staff, false) = false
    ), ins as (
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      select id, 'system'::notif_category, p_title, p_body, 'campaign', v_cid from target
      returning 1
    )
    select count(*) into v_n from ins;
  else
    -- SEGMENT BAZLI: 029 gövdesi + staff filtresi
    with target as (
      select u.id from users u
      left join profiles p on p.user_id = u.id
      left join trust_scores ts on ts.user_id = u.id
      where u.deleted_at is null
        and coalesce(u.is_staff, false) = false
        and (p_segment->>'role' is null or u.role::text = p_segment->>'role')
        and (p_segment->>'plan' is null or u.plan::text = p_segment->>'plan')
        and (p_segment->>'min_trust' is null or coalesce(ts.score,0) >= (p_segment->>'min_trust')::int)
        and (p_segment->>'airport' is null or exists (
              select 1 from visits v where v.user_id = u.id and v.airport_code = p_segment->>'airport'
            ))
    ), ins as (
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      select id, 'system'::notif_category, p_title, p_body, 'campaign', v_cid from target
      returning 1
    )
    select count(*) into v_n from ins;
  end if;

  update notification_campaigns set sent_count = v_n where id = v_cid;
  return jsonb_build_object('ok', true, 'sent', v_n, 'campaign_id', v_cid);
end $$;

revoke execute on function public.send_campaign(text, text, jsonb, uuid, uuid[]) from public, anon, authenticated;

select '047 OK — kişi bazlı kampanya + staff filtresi' as sonuc;
