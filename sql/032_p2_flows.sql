-- ============================================================
-- LoungeLink · 032_p2_flows.sql — P2 doküman kalemleri
-- 1) Chat Cancel → onaylı iptal + kredi iadesi (§23 v7)
-- 2) Host kademe: Verified → Trusted → Elite (§16)
-- 3) Rate later (24h penceresi) (§7.6)
-- 4) Logout block için aktif oturum kontrolü (§15, §27)
-- 5) BO: şüpheli ilan tespiti · bekleyen istek yaşı · SLA sayacı
-- ============================================================

-- ---------- 1) İPTAL AKIŞI (kredi iadesi + slot serbest) ----------
create or replace function public.cancel_request(p_request_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_r requests%rowtype; v_bal int; v_other uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_r from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;
  if v_r.guest_id <> v_uid and v_r.host_id <> v_uid then raise exception 'not_participant'; end if;
  if v_r.status not in ('pending','accepted') then raise exception 'cannot_cancel'; end if;

  -- Aktif oturum varsa iptal edilemez
  if exists (select 1 from sessions where request_id = p_request_id and status = 'active') then
    raise exception 'session_active';
  end if;

  update requests set status = 'cancelled' where id = p_request_id;

  -- §27: kabul edilmiş request iptal → slot serbest (av.filled - 1)
  if v_r.status = 'accepted' then
    update availabilities set filled = greatest(0, filled - 1) where id = v_r.avail_id;
  end if;

  -- Escrow iade (hold edilmiş kredi geri)
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_r.guest_id, 1, 'request_cancel_refund', p_request_id, v_bal + 1);

  v_other := case when v_uid = v_r.guest_id then v_r.host_id else v_r.guest_id end;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_other, 'requests', 'İstek iptal edildi',
          coalesce(left(p_reason,80), 'Karşı taraf isteği iptal etti.'), 'request', p_request_id);
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_r.guest_id, 'system', 'Kredin iade edildi', 'İptal nedeniyle 1 kredi iade edildi.', 'request', p_request_id);

  return jsonb_build_object('ok', true, 'refunded', true);
end $$;
grant execute on function public.cancel_request(uuid, text) to authenticated;

-- ---------- 2) HOST KADEME (§16) ----------
-- Basic Verified → Verified Host (1 oturum) → Trusted Host (5+) → Elite Host (20+)
-- High Trust Guest (score >= 70)
create or replace function public.recompute_badge(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_sessions int; v_score int; v_badge text;
begin
  select role into v_role from users where id = p_user;
  select coalesce(score,0) into v_score from trust_scores where user_id = p_user;
  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status = 'completed' and (case when v_role = 'host' then r.host_id else r.guest_id end) = p_user;

  if v_role = 'host' then
    v_badge := case
      when v_sessions >= 20 then 'Elite Host'
      when v_sessions >= 5  then 'Trusted Host'
      when v_sessions >= 1  then 'Verified Host'
      else 'Basic Verified' end;
  else
    v_badge := case
      when v_score >= 70 then 'High Trust Guest'
      when v_sessions >= 1 then 'Verified Guest'
      else 'Basic Verified' end;
  end if;

  update trust_scores set badge = v_badge, updated_at = now() where user_id = p_user;
  return v_badge;
end $$;
grant execute on function public.recompute_badge(uuid) to authenticated;

-- Oturum tamamlanınca kademeyi yeniden hesapla
create or replace function public.trg_session_completed()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_r requests%rowtype;
begin
  if new.status = 'completed' and (old.status is distinct from 'completed') then
    select * into v_r from requests where id = new.request_id;
    perform public.recompute_badge(v_r.host_id);
    perform public.recompute_badge(v_r.guest_id);
  end if;
  return new;
end $$;
drop trigger if exists session_completed_badge on sessions;
create trigger session_completed_badge after update on sessions
  for each row execute function public.trg_session_completed();

-- ---------- 3) RATE LATER (24h penceresi) ----------
alter table sessions add column if not exists rate_deferred_by uuid[];

create or replace function public.defer_rating(p_session uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update sessions
     set rate_deferred_by = array_append(coalesce(rate_deferred_by, '{}'), v_uid)
   where id = p_session and not (coalesce(rate_deferred_by,'{}') @> array[v_uid]);
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.defer_rating(uuid) to authenticated;

-- Puanlanmamış oturumlar (24h içinde hatırlatma)
create or replace function public.pending_ratings()
returns table (session_id uuid, other_name text, lounge text, completed_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select s.id,
         p.name,
         coalesce(a.lounge_name, a.airport_code),
         s.completed_at
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

-- ---------- 4) LOGOUT BLOCK: aktif oturum var mı? ----------
create or replace function public.has_active_session()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from sessions s join requests r on r.id = s.request_id
     where s.status = 'active' and (r.guest_id = auth.uid() or r.host_id = auth.uid())
  );
$$;
grant execute on function public.has_active_session() to authenticated;

-- ---------- 5) BO: ŞÜPHELİ İLAN · BEKLEYEN YAŞI · SLA ----------
-- Şüpheli ilan: aynı host, aynı tarih, FARKLI havalimanlarında ilan (fiziksel imkânsız)
-- (create or replace view, kolon seti degisirse hata verir -> once dusur)
drop view if exists suspicious_availabilities;
drop view if exists stale_requests;
drop view if exists report_sla;

create or replace view suspicious_availabilities as
  select a.host_id, p.name as host_name, a.avail_date,
         count(distinct a.airport_code) as airport_count,
         string_agg(distinct a.airport_code, ', ') as airports,
         count(*) as listing_count
    from availabilities a
    join profiles p on p.user_id = a.host_id
   where a.active = true
   group by a.host_id, p.name, a.avail_date
  having count(distinct a.airport_code) > 1;

-- Bekleyen istekler + yaş (12 saat eşiği — EK-2 §2.3)
create or replace view stale_requests as
  select r.id, r.created_at,
         round(extract(epoch from (now() - r.created_at)) / 3600, 1) as hours_waiting,
         gp.name as guest_name, hp.name as host_name,
         a.airport_code, a.avail_date
    from requests r
    join profiles gp on gp.user_id = r.guest_id
    join profiles hp on hp.user_id = r.host_id
    join availabilities a on a.id = r.avail_id
   where r.status = 'pending'
     and r.created_at < now() - interval '12 hours'
   order by r.created_at;

-- Şikayet SLA sayacı (24 saat hedef — EK-2 §2.4)
-- NOT: reports tablosunda kolon adi 'type' (report_type enum), 'category' DEGIL.
create or replace view report_sla as
  select rp.id,
         rp.type::text as category,          -- BO 'category' bekliyor; type'i takma adla veriyoruz
         rp.status::text as status,
         rp.created_at,
         rp.description,
         round(extract(epoch from (now() - rp.created_at)) / 3600, 1) as hours_open,
         (now() - rp.created_at > interval '24 hours') as sla_breached,
         rep.name as reporter_name, tgt.name as target_name,
         coalesce(tu.gender::text = 'female' and tp.women_safety_mode, false) as priority_women_safety
    from reports rp
    left join profiles rep on rep.user_id = rp.reporter_id
    left join profiles tgt on tgt.user_id = rp.target_id
    left join users tu on tu.id = rp.target_id
    left join profiles tp on tp.user_id = rp.target_id
   where rp.status = 'open'
   order by priority_women_safety desc, rp.created_at;

select 'P2 FLOWS OK' as sonuc;
