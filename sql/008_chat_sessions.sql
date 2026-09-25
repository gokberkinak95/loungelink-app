-- ============================================================
-- LoungeLink · 008_chat_sessions.sql — Chat + Oturum + Puanlama
-- ============================================================

-- 1) MESAJLAR: taraflar okur/yazar; Realtime yayınına ekle
alter table messages enable row level security;
drop policy if exists "msg_read" on messages;
create policy "msg_read" on messages for select using (
  exists (select 1 from chat_channels c join requests r on r.id = c.request_id
          where c.id = channel_id and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
);
drop policy if exists "msg_write" on messages;
create policy "msg_write" on messages for insert with check (
  from_id = auth.uid() and exists (
    select 1 from chat_channels c join requests r on r.id = c.request_id
    where c.id = channel_id and r.status = 'accepted'
      and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
);
alter publication supabase_realtime add table messages;

-- 2) OTURUM BAŞLAT (iki taraftan biri, accepted istekte)
create or replace function public.start_session(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_req requests%rowtype; v_s sessions%rowtype;
begin
  select * into v_req from requests where id = p_request_id for update;
  if not found or (v_req.guest_id <> v_uid and v_req.host_id <> v_uid) then raise exception 'not_party'; end if;
  if v_req.status <> 'accepted' then raise exception 'not_accepted'; end if;
  insert into sessions (request_id) values (p_request_id)
    on conflict (request_id) do nothing;
  select * into v_s from sessions where request_id = p_request_id;
  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  values (case when v_uid = v_req.guest_id then v_req.host_id else v_req.guest_id end,
          'session', 'Oturum başladı', 'Buluşma aktif olarak işaretlendi.', v_s.id, 'session');
  return jsonb_build_object('ok', true, 'session_id', v_s.id);
end $$;

-- 3) OTURUM ONAYLA (çift onay; ikincisi tamamlar + escrow kapanır + puan hakkı)
create or replace function public.confirm_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype; v_done boolean;
begin
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_req from requests where id = v_s.request_id;
  if v_req.guest_id <> v_uid and v_req.host_id <> v_uid then raise exception 'not_party'; end if;
  if v_s.status <> 'active' then raise exception 'not_active'; end if;

  if v_uid = v_req.host_id then
    update sessions set host_confirmed = true where id = p_session_id;
  else
    update sessions set guest_confirmed = true where id = p_session_id;
  end if;

  select host_confirmed and guest_confirmed into v_done from sessions where id = p_session_id;
  if v_done then
    update sessions set status = 'completed', completed_at = now() where id = p_session_id;
    update requests set status = 'completed' where id = v_s.request_id;
    -- Escrow kapanışı: hold edilmiş kredi host'a işlenmez (kredi = hak, para değil);
    -- guest'in kredisi harcandı olarak kalır. Ledger'a kapanış notu düş:
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_req.guest_id, 0, 'session_settled', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_req.guest_id;
    insert into notifications (user_id, category, title, body, ref_id, ref_type) values
      (v_req.guest_id, 'session', 'Oturum tamamlandı! 🎉', 'Şimdi puan verebilirsin.', p_session_id, 'session'),
      (v_req.host_id,  'session', 'Oturum tamamlandı! 🎉', 'Şimdi puan verebilirsin.', p_session_id, 'session');
  end if;
  return jsonb_build_object('ok', true, 'completed', v_done);
end $$;

-- 4) PUANLA (session başına 1; ödül puanları yalnız ilk kez; güven skoru güncelle)
create or replace function public.rate_session(p_session_id uuid, p_score int, p_comment text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype;
        v_other uuid; v_role text; v_pts int; v_bal int;
begin
  if p_score < 1 or p_score > 5 then raise exception 'bad_score'; end if;
  select * into v_s from sessions where id = p_session_id;
  if not found or v_s.status <> 'completed' then raise exception 'not_completed'; end if;
  select * into v_req from requests where id = v_s.request_id;
  if v_uid = v_req.host_id then v_other := v_req.guest_id; v_role := 'host';
  elsif v_uid = v_req.guest_id then v_other := v_req.host_id; v_role := 'guest';
  else raise exception 'not_party'; end if;

  insert into ratings (session_id, rater_id, rated_id, score, comment)
  values (p_session_id, v_uid, v_other, p_score, left(p_comment, 300));
  -- unique(session_id, rater_id) çift puanı DB seviyesinde engeller

  -- Ödül: host +500, guest +200 LoungePuan (ilk puanlamada — unique zaten garantiliyor)
  v_pts := case when v_role = 'host' then 500 else 200 end;
  select coalesce(sum(delta),0) into v_bal from points_ledger where user_id = v_uid;
  insert into points_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, v_pts, 'session_reward', p_session_id, v_bal + v_pts);

  -- Karşı tarafın güven skorunu güncelle (basit v1: ort. puan * 15 + oturum sayısı * 2, tavan 100)
  update trust_scores t set
    score = least(100, greatest(10, (
      select round(avg(score)::numeric * 15 + count(*) * 2)
      from ratings where rated_id = v_other
    )::int)),
    badge = case
      when (select count(*) from ratings where rated_id = v_other) >= 20 then 'Elite'
      when (select count(*) from ratings where rated_id = v_other) >= 5 then 'Trusted'
      else 'Verified' end,
    updated_at = now()
  where t.user_id = v_other;

  return jsonb_build_object('ok', true, 'points_earned', v_pts);
end $$;

grant execute on function public.start_session(uuid) to authenticated;
grant execute on function public.confirm_session(uuid) to authenticated;
grant execute on function public.rate_session(uuid, int, text) to authenticated;

-- 5) Sessions + ratings okuma politikaları
alter table sessions enable row level security;
drop policy if exists "sess_parties" on sessions;
create policy "sess_parties" on sessions for select using (
  exists (select 1 from requests r where r.id = request_id
          and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
);
alter table ratings enable row level security;
drop policy if exists "ratings_visible" on ratings;
create policy "ratings_visible" on ratings for select using (
  rater_id = auth.uid() or rated_id = auth.uid()
);

select 'CHAT+SESSION ENGINE OK' as sonuc;
