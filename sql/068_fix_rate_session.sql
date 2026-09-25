-- ============================================================
-- LoungeLink · 068_fix_rate_session.sql
--
-- 🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu.
--
-- rate_session, points_ledger'a `balance_after` kolonuna yaziyor ama
-- o kolon points_ledger'da YOK (credit_ledger'da var, points_ledger'da yok).
--
-- SONUC: OTURUM SONRASI PUANLAMA HIC CALISMIYOR. Iki taraf oturumu
-- tamamlasa bile puan verilemiyor, LoungePuan hic dagitilmiyor,
-- guven puani davranis bileseni hic guncellenmiyor.
--
-- NOT: Ayni hata daha once uygulama tarafinda da cikmisti (Home ekrani
-- points_ledger.balance_after okuyordu, user_balances view'ine gecilmisti).
-- Ama FONKSIYON tarafi duzeltilmemis, o yuzden yazma tarafi hala kirikti.
--
-- COZUM: balance_after yazilmaz. Bakiye zaten delta toplamindan turetiliyor
-- (user_balances view). Tek dogruluk kaynagi korunur.
-- ============================================================

CREATE OR REPLACE FUNCTION public.rate_session(p_session_id uuid, p_score integer, p_comment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, v_pts, 'session_reward', p_session_id);

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
end $function$;

grant execute on function public.rate_session(uuid, integer, text) to authenticated;

-- DOGRULAMA (true donmeli)
select (prosrc not ilike '%points_ledger (user_id, delta, reason, ref_id, balance_after)%')
       as "balance_after_yazilmiyor"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='rate_session';

select '068 OK - rate_session artik var olan kolonlara yaziyor, puanlama calisiyor' as sonuc;
