-- ============================================================
-- LoungeLink · 021_moderation_tools.sql — P2/P3 moderasyon araçları
-- ============================================================

-- Şikayet çözümle (open -> resolved/dismissed)
create or replace function public.resolve_report(p_report_id uuid, p_status text, p_resolution text, p_resolver uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update reports set status = p_status::report_status, resolution = p_resolution,
    resolved_by = p_resolver, updated_at = now()
  where id = p_report_id;
  return jsonb_build_object('ok', true);
end $$;

-- Puanlama kaldır (uygunsuz yorum) — trust score'u yeniden hesaplamaz, sadece gizler
create or replace function public.remove_rating(p_rating_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  delete from ratings where id = p_rating_id;
  return jsonb_build_object('ok', true);
end $$;

-- Trust score manuel düzelt (hatalı/haksız düşükse)
create or replace function public.admin_set_trust(p_user uuid, p_score int, p_badge text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update trust_scores set score = greatest(0, least(100, p_score)),
    badge = coalesce(p_badge, badge), updated_at = now()
  where user_id = p_user;
  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.resolve_report(uuid, text, text, uuid) to authenticated;
grant execute on function public.remove_rating(uuid) to authenticated;
grant execute on function public.admin_set_trust(uuid, int, text) to authenticated;

select 'MODERATION TOOLS OK' as sonuc;
