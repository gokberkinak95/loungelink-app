-- ============================================================
-- LoungeLink · 052_session_live_status.sql
-- MVP "Session · Live Status" ekranı için: oturum sırasında iki taraf
-- birbirine durum paylaşır ("Lounge'dayım", "Güvenlikteyim" gibi).
-- KONUM PAYLAŞILMAZ — yalnız serbest-metin durum + zaman damgası.
-- sessions tablosuna 4 kolon (host/guest × durum + ts) + tek RPC.
-- ============================================================

alter table sessions add column if not exists host_status text;
alter table sessions add column if not exists host_status_ts timestamptz;
alter table sessions add column if not exists guest_status text;
alter table sessions add column if not exists guest_status_ts timestamptz;

-- Durumu paylaş: çağıran kişi oturumun host'u mu guest'i mi, ona göre
-- kendi alanını yazar. Yalnız AKTİF oturumda ve yalnız taraflar yazabilir.
create or replace function public.share_session_status(p_session_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid; v_guest uuid; v_active boolean;
begin
  select r.host_id, r.guest_id, (s.status = 'active')
    into v_host, v_guest, v_active
  from sessions s join requests r on r.id = s.request_id
  where s.id = p_session_id;

  if v_host is null then raise exception 'session_not_found'; end if;
  if not v_active then raise exception 'session_not_active'; end if;
  if v_uid not in (v_host, v_guest) then raise exception 'not_a_participant'; end if;
  if coalesce(trim(p_status), '') = '' then raise exception 'empty_status'; end if;

  if v_uid = v_host then
    update sessions set host_status = p_status, host_status_ts = now() where id = p_session_id;
  else
    update sessions set guest_status = p_status, guest_status_ts = now() where id = p_session_id;
  end if;

  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.share_session_status(uuid, text) to authenticated;

select '052 OK — session live-status kolonları + share_session_status RPC' as sonuc;
