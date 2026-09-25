-- ============================================================
-- LoungeLink · 067_fix_confirm_session_enum.sql
--
-- 🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu.
--
-- confirm_session, oturum tamamlaninca iki tarafa da bildirim yaziyor ama
-- notif_category'ye TEKIL 'session' veriyor. Gecerli deger COGUL 'sessions'.
--
-- SONUC: 066 ile enum sorunu asildiktan sonra bile oturum TAMAMLANAMIYOR;
-- son adimda "invalid input value for enum notif_category" hatasi aliniyor.
-- Yani escrow cozulmuyor, puanlama ekrani hic acilmiyor.
--
-- NOT: Bu, respond_request'te (SQL 061) duzeltilen hatanin AYNISI.
-- Denetim aracimiz (flow_check.py) bunu kacirmisti cunku buradaki INSERT
-- COK SATIRLI VALUES kullaniyor:  values (satir1), (satir2);
-- Ayristirici yalnizca ilk satiri okuyordu. Arac bu turda duzeltildi.
-- ============================================================

CREATE OR REPLACE FUNCTION public.confirm_session(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      (v_req.guest_id, 'sessions', 'Oturum tamamlandı! 🎉', 'Şimdi puan verebilirsin.', p_session_id, 'session'),
      (v_req.host_id,  'sessions', 'Oturum tamamlandı! 🎉', 'Şimdi puan verebilirsin.', p_session_id, 'session');
  end if;
  return jsonb_build_object('ok', true, 'completed', v_done);
end $function$;

grant execute on function public.confirm_session(uuid) to authenticated;

-- DOGRULAMA (true donmeli)
select (prosrc ilike '%''sessions'', ''Oturum tamamland%') as "cogul_kullanilmis"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='confirm_session';

select '067 OK - confirm_session dogru enum degerini kullaniyor' as sonuc;
