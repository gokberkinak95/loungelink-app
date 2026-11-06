-- ============================================================================
-- 342 · OTURUM BAŞLATMA PENCERESİ   (6 Kasım 2026)
--
-- Gökberk: sohbette durum "Sona erdi" yazarken "Oturumu Başlat" çalıştı ve oturum başladı.
-- Ölçüm: start_session_request hiçbir zaman sınırı uygulamıyordu; ilan saati geçen kabuller
-- yalnız süpürge (ll-supurge, 5 dk) koşunca iptal ediliyordu. Arada ya da cron kapalıyken
-- düğme çalışıyordu.
--   1) start_session_request: ilan bitişi + 2 sa (havalimanı saatiyle) geçtiyse
--      'session_window_closed'. Kural süpürgeyle aynı sayı. Aktif oturum etkilenmez.
--   2) tek_tarafli_oturumlari_kapat: havalimanı saat dilimi; ek sürede başlayan oturum
--      başlangıçtan itibaren en az 2 saat açık kalır.
-- Gövdeler ETKIN_TANIMLAR'daki canlı halin aynısı + kapı (yeniden yazılmadı).
-- Supabase SQL Editor'de tek parça; tekrar koşulabilir. Doğrulama: üç satır tamam = true.
-- ============================================================================

create or replace function public.start_session_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid(); v_req requests%rowtype; v_s sessions%rowtype;
  v_is_host boolean; v_both boolean; v_ad text; v_diger text; v_salon text;
  v_bitis timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_req from requests where id = p_request_id;
  if not found then raise exception 'request_not_found'; end if;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_req.status <> 'accepted' then raise exception 'request_not_accepted'; end if;
  -- 342: ilan saati + 2 sa ek süre geçtiyse başlatılamaz (süpürgenin isteği iptal ettiği an).
  -- Önce yalnız süpürge kapatıyordu; süpürge koşana kadar (5 dk) ya da cron kapalıyken
  -- düğme çalışıyordu ve ekran "Sona erdi" derken oturum başlıyordu. Zaten AKTİF oturum etkilenmez.
  select public.yerel_an(a.avail_date, a.time_to, a.airport_code) into v_bitis
    from availabilities a where a.id = v_req.avail_id;
  if v_bitis is not null and v_bitis < now() - interval '2 hours'
     and not exists (select 1 from sessions where request_id = p_request_id and status = 'active') then
    raise exception 'session_window_closed';
  end if;
  v_is_host := (v_uid = v_req.host_id);
  v_ad := public.kisa_ad(v_uid);
  v_salon := public.salon_etiketi(v_req.avail_id);

  select * into v_s from sessions where request_id = p_request_id for update;
  if not found then
    insert into sessions (request_id, status, host_started_at, guest_started_at)
    values (p_request_id, 'pending',
            case when v_is_host then now() end,
            case when not v_is_host then now() end)
    returning * into v_s;
    perform public.bildir(case when v_is_host then v_req.guest_id else v_req.host_id end, 'sessions',
      v_ad || ' oturumu başlattı',
      v_salon || ' — buluştuysanız sen de "Oturumu Başlat"a bas; ikiniz de basınca oturum başlar.',
      v_ad || ' started the session',
      v_salon || ' — if you have met, tap "Start session" too; it begins when you both tap.',
      'session', v_s.id);
    return jsonb_build_object('ok', true, 'id', v_s.id, 'status', 'pending', 'both', false);
  end if;

  if v_s.status = 'active' then
    return jsonb_build_object('ok', true, 'id', v_s.id, 'status', 'active', 'both', true);
  end if;
  if v_s.status <> 'pending' then raise exception 'session_closed'; end if;

  -- Karşı taraf henüz basmadıysa ve ben ilk kez basıyorsam ona haber ver.
  if (v_is_host and v_s.host_started_at is null and v_s.guest_started_at is null)
     or (not v_is_host and v_s.guest_started_at is null and v_s.host_started_at is null) then
    perform public.bildir(case when v_is_host then v_req.guest_id else v_req.host_id end, 'sessions',
      v_ad || ' oturumu başlattı',
      v_salon || ' — buluştuysanız sen de "Oturumu Başlat"a bas; ikiniz de basınca oturum başlar.',
      v_ad || ' started the session',
      v_salon || ' — if you have met, tap "Start session" too; it begins when you both tap.',
      'session', v_s.id);
  end if;

  update sessions
     set host_started_at  = case when v_is_host then coalesce(host_started_at, now()) else host_started_at end,
         guest_started_at = case when not v_is_host then coalesce(guest_started_at, now()) else guest_started_at end
   where id = v_s.id
   returning * into v_s;

  v_both := v_s.host_started_at is not null and v_s.guest_started_at is not null;
  if v_both then
    update sessions
       set status = 'active', started_at = now(),
           cancel_grace_until = now() + interval '5 minutes'
     where id = v_s.id;
    v_diger := public.kisa_ad(case when v_is_host then v_req.guest_id else v_req.host_id end);
    perform public.bildir(v_req.host_id, 'sessions', 'Oturum başladı ⏱',
      public.kisa_ad(v_req.guest_id) || ' ile · ' || v_salon || '. İlk 5 dakika içinde iptal edersen kredi iade edilir.',
      'Session started ⏱',
      'With ' || public.kisa_ad(v_req.guest_id) || ' · ' || v_salon || '. Cancel within 5 minutes for a refund.',
      'session', v_s.id);
    perform public.bildir(v_req.guest_id, 'sessions', 'Oturum başladı ⏱',
      public.kisa_ad(v_req.host_id) || ' ile · ' || v_salon || '. İlk 5 dakika içinde iptal edersen kredin iade edilir.',
      'Session started ⏱',
      'With ' || public.kisa_ad(v_req.host_id) || ' · ' || v_salon || '. Cancel within 5 minutes for a refund.',
      'session', v_s.id);
  end if;

  return jsonb_build_object('ok', true, 'id', v_s.id,
                            'status', case when v_both then 'active' else 'pending' end,
                            'both', v_both);
end $function$;

create or replace function public.tek_tarafli_oturumlari_kapat()
returns int language plpgsql security definer set search_path = public as $$
declare v_n int := 0; v_s record;
begin
  for v_s in
    select s.id, s.request_id, s.host_confirmed, s.guest_confirmed, r.host_id, r.guest_id
      from sessions s
      join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
     where s.status = 'active'
       -- 342: (1) saat dilimi havalimanınınki (yerel_an) — İstanbul sabiti LHR/FRA'da 2-3 saat kayıyordu;
       --      (2) ek sürede (ilan bittikten sonra) başlayan oturum da en az 2 saat yaşar.
       --      Önce: 1 sa 50 dk gecikmeyle başlayan oturum 10 dk sonra "süresi doldu" diye kapanıyordu.
       and greatest(public.yerel_an(a.avail_date, a.time_to, a.airport_code),
                    coalesce(s.started_at, '-infinity'::timestamptz)) < now() - interval '2 hours'
  loop
    if coalesce(v_s.host_confirmed,false) or coalesce(v_s.guest_confirmed,false) then
      update sessions set status = 'completed', completed_at = now(),
             cancel_reason = 'auto_completed_one_sided' where id = v_s.id;
      update requests set status = 'completed' where id = v_s.request_id;
    else
      update sessions set status = 'expired', completed_at = now(),
             cancel_reason = 'expired' where id = v_s.id;
      update requests set status = 'cancelled' where id = v_s.request_id;
      perform public.istek_kredisi_iade(v_s.request_id, 'expired_refund', v_s.id);
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

select 'başlatma kapısı var' as kontrol,
       position('session_window_closed' in pg_get_functiondef('public.start_session_request(uuid)'::regprocedure)) > 0 as tamam
union all select 'aktif oturum kapanışı havalimanı saatiyle',
       position('yerel_an' in pg_get_functiondef('public.tek_tarafli_oturumlari_kapat()'::regprocedure)) > 0
union all select 'ek sürede başlayan oturum en az 2 saat',
       position('started_at' in pg_get_functiondef('public.tek_tarafli_oturumlari_kapat()'::regprocedure)) > 0;
