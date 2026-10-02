-- ============================================================================
-- 313 · AKIŞ DÜZELTMELERİ (Gökberk, 2 Ekim) — tekrar koşulabilir
--
--  A. Yardımcılar: kısa ad, salon etiketi, alıcının dilinde bildirim (bildir)
--  B. OTURUM DURUM MAKİNESİ — "başladı" = İKİ TARAF DA BAŞLAT'a bastı (status='active').
--     ÖLÇÜLDÜ (md.5): misafir tek taraflı "Başlat"a basınca host "Kabulü geri al"
--     diyemiyordu ("oturum başladı"). Kapı dört fonksiyonda dört ayrı biçimde
--     yazılmıştı. Artık tek tanım: istegin_acik_oturumu_var_mi = yalnız 'active'.
--     Geri alma / iptal / ilan kaldırma: kredi iadesi + slot açılır + karşı tarafa
--     isimli bildirim; tek taraflı başlatılmış oturum satırı da kapanır.
--  C. BİLDİRİMLER (md.4) — isimli ve doğru metinler; "kabulü geri aldı" ayrı;
--     davet kabulünde "oturum başladı" yanlışı düzeldi; hatırlatmalar zamanlandı
--     (yazılmıştı ama hiçbir zamanlayıcı çağırmıyordu) + "buluşmana 1 saat var".
--  D. SORU AKIŞI (md.2, 3, 10) — soru artık BAĞLANTI DEĞİL:
--     · host Evet/Hayır + kısa notla yanıtlar; sohbet/bağlantı AÇILMAZ
--       (eskiden yanıt = bağlantı kabulü → soranı "yalnız bağlantılarım" ilanlarına
--        ve profile erişebilir kılıyordu).
--     · Davet ekranından çıkar (pending_actions), Soru ekranında Gelen/Gönderdiğim.
--     · Rozet metni, "Host'a sor" düğmesi ve sunucu kapısı AYNI karardan
--       (kural_sorusu_durumu); ret sebebi ayrı kodla döner.
--  E. "YENİ" İŞARETİ (ana sayfa öneri 1) — akis_goruldu: alan başına son bakış.
--  F. Tanış araması — kisi_ara (Tanış'ın gizlilik kurallarının aynısı).
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- A. YARDIMCILAR
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.kisa_ad(p_uid uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
           when n is null then 'Bir yolcu'
           when array_length(w, 1) is null or array_length(w, 1) = 1 then n
           when w[array_length(w, 1)] ~ '^.\.$' then n
           else w[1] || ' ' || upper(left(w[array_length(w, 1)], 1)) || '.'
         end
    from (select nullif(btrim(p.name), '') as n,
                 regexp_split_to_array(btrim(coalesce(p.name, '')), '\s+') as w
            from (select 1) x left join profiles p on p.user_id = p_uid) s;
$$;

create or replace function public.salon_etiketi(p_avail uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(btrim(a.lounge_name), ''), l.name, a.airport_code::text, 'Lounge')
    from availabilities a left join lounges l on l.id = a.lounge_id
   where a.id = p_avail;
$$;

-- Alıcının dilinde bildirim. push tetikleyicisi (notify_push) metni olduğu gibi gönderir;
-- push_ceviri yalnız sabit metinleri çevirebiliyordu, isimli metinler İngilizce
-- kullanıcıya Türkçe gidiyordu.
create or replace function public.bildir(p_user uuid, p_cat text, p_tr_baslik text, p_tr_govde text,
                                         p_en_baslik text, p_en_govde text, p_ref_type text, p_ref_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_dil text;
begin
  if p_user is null then return; end if;
  select lower(coalesce(dil, 'tr')) into v_dil from profiles where user_id = p_user;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_user, p_cat::notif_category,
          case when v_dil = 'en' then coalesce(p_en_baslik, p_tr_baslik) else p_tr_baslik end,
          case when v_dil = 'en' then coalesce(p_en_govde, p_tr_govde) else p_tr_govde end,
          p_ref_type, p_ref_id);
end $$;

revoke all on function public.kisa_ad(uuid) from public, anon, authenticated;
revoke all on function public.salon_etiketi(uuid) from public, anon, authenticated;
revoke all on function public.bildir(uuid, text, text, text, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.kisa_ad(uuid) to service_role;
grant execute on function public.salon_etiketi(uuid) to service_role;
grant execute on function public.bildir(uuid, text, text, text, text, text, text, uuid) to service_role;

-- ════════════════════════════════════════════════════════════════════════════
-- B. OTURUM DURUM MAKİNESİ
-- ════════════════════════════════════════════════════════════════════════════
-- TEK TANIM: oturum yalnız İKİ TARAF DA başlattığında başlamıştır.
create or replace function public.istegin_acik_oturumu_var_mi(p_req uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from sessions s where s.request_id = p_req and s.status = 'active')
$$;

create or replace function public.respond_request(p_request_id uuid, p_action text)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_av   availabilities%rowtype;
  v_chan uuid;
  v_onceki text;
  v_salon text; v_gun text; v_host text; v_guest text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);

  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;
  v_salon := public.salon_etiketi(v_req.avail_id);
  select to_char(avail_date, 'DD.MM') into v_gun from availabilities where id = v_req.avail_id;
  v_host  := public.kisa_ad(v_req.host_id);
  v_guest := public.kisa_ad(v_req.guest_id);

  if p_action = 'accept' then
    if v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if v_req.status <> 'pending' then raise exception 'not_pending'; end if;

    select * into v_av from availabilities where id = v_req.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    if not coalesce(v_av.active, true)
       or public.yerel_an(v_av.avail_date, v_av.time_to, v_av.airport_code) < now() then
      raise exception 'availability_expired';
    end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    update requests set status='accepted', responded_at=now() where id = v_req.id;

    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;

    if v_chan is not null and coalesce(nullif(trim(v_req.intro_message),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_req.guest_id, trim(v_req.intro_message), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    perform public.bildir(v_req.guest_id, 'requests',
      v_host || ' isteğini kabul etti 🎉',
      v_salon || ' · ' || coalesce(v_gun,'') || ' — sohbet açıldı. Buluşunca ikiniz de "Oturumu Başlat"a basın.',
      v_host || ' accepted your request 🎉',
      v_salon || ' · ' || coalesce(v_gun,'') || ' — the chat is open. When you meet, both tap "Start session".',
      'request', v_req.id);

    return jsonb_build_object('ok', true, 'channel_id', v_chan, 'session_id', null);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id  <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;
    -- 313: yalnız GERÇEKTEN başlamış (iki taraf da bastı) oturum engeldir.
    if public.istegin_acik_oturumu_var_mi(v_req.id) then
      raise exception 'session_started';
    end if;
    v_onceki := v_req.status::text;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;

    -- Bekleyen oturum satırı (tek taraf başlatmış olsa bile) kapanır.
    update sessions set status = 'cancelled', completed_at = now(),
           cancelled_by = v_uid,
           cancel_reason = case when host_started_at is null and guest_started_at is null
                                then 'not_started' else 'cancelled_before_both_started' end
     where request_id = v_req.id and status = 'pending';

    perform public.istek_kredisi_iade(v_req.id, 'request_refund');

    if p_action = 'decline' and v_onceki = 'accepted' then
      perform public.bildir(v_req.guest_id, 'requests',
        v_host || ' kabulü geri aldı',
        v_salon || ' · ' || coalesce(v_gun,'') || ' buluşması iptal oldu. Kredin iade edildi; başka bir ilana başvurabilirsin.',
        v_host || ' withdrew the acceptance',
        v_salon || ' · ' || coalesce(v_gun,'') || ' is cancelled. Your credit was refunded; you can apply to another listing.',
        'request', v_req.id);
    elsif p_action = 'decline' then
      perform public.bildir(v_req.guest_id, 'requests',
        v_host || ' bu kez misafir alamıyor',
        v_salon || ' · ' || coalesce(v_gun,'') || ' — kredin iade edildi. Keşfet''te başka ilanlar var.',
        v_host || ' can''t host this time',
        v_salon || ' · ' || coalesce(v_gun,'') || ' — your credit was refunded. There are other listings in Discover.',
        'request', v_req.id);
    else
      perform public.bildir(v_req.host_id, 'requests',
        v_guest || case when v_onceki = 'accepted' then ' buluşmayı iptal etti' else ' isteğini geri çekti' end,
        v_salon || ' · ' || coalesce(v_gun,'') || ' — yerin yeniden açıldı.',
        v_guest || case when v_onceki = 'accepted' then ' cancelled the meetup' else ' withdrew the request' end,
        v_salon || ' · ' || coalesce(v_gun,'') || ' — your spot is open again.',
        'request', v_req.id);
    end if;
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown_action';
end $function$;

create or replace function public.cancel_request(p_request_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_r requests%rowtype; v_other uuid; v_iade int;
        v_salon text; v_ad text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_r from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;
  if v_r.guest_id <> v_uid and v_r.host_id <> v_uid then raise exception 'not_participant'; end if;
  if v_r.status not in ('pending','accepted') then raise exception 'cannot_cancel'; end if;
  if public.istegin_acik_oturumu_var_mi(p_request_id) then
    raise exception 'session_active';
  end if;

  update requests set status = 'cancelled', responded_at = now() where id = p_request_id;
  update sessions set status = 'cancelled', completed_at = now(), cancelled_by = v_uid,
         cancel_reason = 'cancelled_before_both_started'
   where request_id = p_request_id and status = 'pending';

  v_iade := public.istek_kredisi_iade(p_request_id, 'request_cancel_refund');

  v_other := case when v_uid = v_r.guest_id then v_r.host_id else v_r.guest_id end;
  v_salon := public.salon_etiketi(v_r.avail_id);
  v_ad    := public.kisa_ad(v_uid);
  perform public.bildir(v_other, 'requests',
    v_ad || ' buluşmayı iptal etti',
    v_salon || coalesce(' — ' || nullif(left(btrim(p_reason), 80), ''), '') || '. Kredi iade edildi.',
    v_ad || ' cancelled the meetup',
    v_salon || coalesce(' — ' || nullif(left(btrim(p_reason), 80), ''), '') || '. Credit refunded.',
    'request', p_request_id);
  return jsonb_build_object('ok', true, 'refunded', v_iade > 0, 'amount', v_iade);
end $function$;

create or replace function public.cancel_session(p_session_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype;
  v_late boolean; v_other uuid; v_ad text; v_salon text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_req from requests where id = v_s.request_id for update;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_s.status not in ('pending','active') then raise exception 'session_closed'; end if;
  v_other := case when v_uid = v_req.host_id then v_req.guest_id else v_req.host_id end;
  v_ad := public.kisa_ad(v_uid);
  v_salon := public.salon_etiketi(v_req.avail_id);

  v_late := (v_s.status = 'active'
             and v_s.cancel_grace_until is not null
             and now() > v_s.cancel_grace_until);

  update sessions
     set status = 'cancelled', cancelled_by = v_uid,
         cancel_reason = case when v_late then 'late_cancel' else 'cancelled' end,
         cancel_note   = nullif(left(trim(coalesce(p_reason,'')), 200), ''),
         completed_at = now()
   where id = p_session_id;
  -- slot iadesi: trg_requests_sync_filled (accepted → cancelled)
  update requests set status = 'cancelled', responded_at = coalesce(responded_at, now())
   where id = v_s.request_id and status in ('pending','accepted');

  if v_late then
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_req.guest_id, 0, 'late_cancel_forfeit', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_req.guest_id;
    perform public.bildir(v_other, 'sessions',
      v_ad || ' oturumu iptal etti',
      v_salon || ' — geç iptal güven puanına yansıdı; sen etkilenmedin.',
      v_ad || ' cancelled the session',
      v_salon || ' — the late cancellation affected their trust score; you are not affected.',
      'session', p_session_id);
  else
    perform public.istek_kredisi_iade(v_req.id, 'session_cancel_refund', p_session_id);
    perform public.bildir(v_other, 'sessions',
      v_ad || ' oturumu iptal etti',
      v_salon || ' — kredi iade edildi, kimsenin puanı etkilenmedi.',
      v_ad || ' cancelled the session',
      v_salon || ' — credit refunded, nobody''s score was affected.',
      'session', p_session_id);
  end if;

  perform public.recompute_trust(v_uid);
  perform public.recompute_trust(v_other);
  return jsonb_build_object('ok', true, 'late', v_late);
end $function$;

create or replace function public.start_session_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid(); v_req requests%rowtype; v_s sessions%rowtype;
  v_is_host boolean; v_both boolean; v_ad text; v_diger text; v_salon text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_req from requests where id = p_request_id;
  if not found then raise exception 'request_not_found'; end if;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_req.status <> 'accepted' then raise exception 'request_not_accepted'; end if;
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

create or replace function public.confirm_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
  v_done boolean; v_ad text; v_salon text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if v_uid not in (v_r.host_id, v_r.guest_id) then raise exception 'not_party'; end if;
  if v_s.status <> 'active' then raise exception 'not_active'; end if;
  v_ad := public.kisa_ad(v_uid);
  v_salon := public.salon_etiketi(v_r.avail_id);

  if v_uid = v_r.host_id then
    update sessions set host_confirmed = true where id = p_session_id;
  else
    update sessions set guest_confirmed = true where id = p_session_id;
  end if;

  select host_confirmed and guest_confirmed into v_done from sessions where id = p_session_id;

  if v_done then
    update sessions set status = 'completed', completed_at = now() where id = p_session_id;
    update requests set status = 'completed' where id = v_s.request_id;

    if not exists (select 1 from points_ledger
                    where ref_id = p_session_id and reason = 'session_reward') then
      insert into points_ledger (user_id, delta, reason, ref_id)
      values (v_r.host_id, 500, 'session_reward', p_session_id),
             (v_r.guest_id, 200, 'session_reward', p_session_id);
    end if;

    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_r.guest_id, 0, 'session_settled', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_r.guest_id;

    perform public.recompute_trust(v_r.host_id);
    perform public.recompute_trust(v_r.guest_id);

    perform public.bildir(v_r.host_id, 'sessions', 'Oturum tamamlandı ✓',
      public.kisa_ad(v_r.guest_id) || ' ile oturumun bitti. Puanların eklendi — şimdi puanla, güven puanı buna dayanıyor.',
      'Session completed ✓',
      'Your session with ' || public.kisa_ad(v_r.guest_id) || ' is done. Points added — rate now; trust scores rely on it.',
      'session', p_session_id);
    perform public.bildir(v_r.guest_id, 'sessions', 'Oturum tamamlandı ✓',
      public.kisa_ad(v_r.host_id) || ' ile oturumun bitti. Puanların eklendi — şimdi puanla, güven puanı buna dayanıyor.',
      'Session completed ✓',
      'Your session with ' || public.kisa_ad(v_r.host_id) || ' is done. Points added — rate now; trust scores rely on it.',
      'session', p_session_id);
  else
    perform public.bildir(case when v_uid = v_r.host_id then v_r.guest_id else v_r.host_id end, 'sessions',
      v_ad || ' oturumu tamamladı',
      v_salon || ' — sen de "Oturumu Tamamla"ya bas; ikiniz de onaylayınca oturum kapanır ve puanlar yazılır.',
      v_ad || ' completed the session',
      v_salon || ' — tap "Complete session" too; it closes and points are added when you both confirm.',
      'session', p_session_id);
  end if;

  return jsonb_build_object('ok', true, 'completed', coalesce(v_done,false));
end $function$;

create or replace function public.cancel_availability(p_id uuid, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid();
  v_accepted int; v_pending int; v_iptal int := 0;
  r record; v_salon text; v_gun text; v_host text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  if not exists (select 1 from availabilities where id = p_id and host_id = v_uid) then
    raise exception 'not_your_availability';
  end if;
  v_salon := public.salon_etiketi(p_id);
  select to_char(avail_date, 'DD.MM') into v_gun from availabilities where id = p_id;
  v_host := public.kisa_ad(v_uid);

  -- 313: tek tanım — yalnız İKİ TARAFIN DA başlattığı (active) oturum engeldir.
  if exists (select 1 from sessions s join requests q on q.id = s.request_id
              where q.avail_id = p_id and s.status = 'active') then
    raise exception 'session_started';
  end if;

  select count(*) filter (where status = 'accepted'),
         count(*) filter (where status = 'pending')
    into v_accepted, v_pending
    from requests where avail_id = p_id;

  if v_accepted > 0 and not p_force then
    raise exception 'has_accepted_requests';
  end if;

  for r in select id, guest_id, status from requests
            where avail_id = p_id
              and status in ('pending','accepted')
              and (p_force or status = 'pending')
            for update
  loop
    update requests set status = 'declined', responded_at = now() where id = r.id;
    perform public.istek_kredisi_iade(r.id, 'request_refund');
    perform public.bildir(r.guest_id, 'requests',
      v_host || ' ilanını kaldırdı',
      v_salon || ' · ' || coalesce(v_gun,'') ||
        case when r.status = 'accepted' then ' buluşması iptal oldu. ' else ' — ' end ||
        'Kredin iade edildi; başka bir ilana başvurabilirsin.',
      v_host || ' removed the listing',
      v_salon || ' · ' || coalesce(v_gun,'') ||
        case when r.status = 'accepted' then ' meetup is cancelled. ' else ' — ' end ||
        'Your credit was refunded; you can apply elsewhere.',
      'request', r.id);
    v_iptal := v_iptal + 1;
  end loop;

  update invites set status = 'declined'::connection_status, responded_at = now()
   where avail_id = p_id and status = 'pending';

  -- Başlamamış (iki taraf da basmamış YA DA yalnız biri basmış) oturumlar ilanla kapanır.
  update sessions s set status = 'cancelled', completed_at = now(), cancelled_by = v_uid,
         cancel_reason = coalesce(s.cancel_reason, 'ilan_geri_cekildi')
    from requests q
   where q.id = s.request_id and q.avail_id = p_id and s.status = 'pending';

  update availabilities set active = false, updated_at = now() where id = p_id;
  return jsonb_build_object('ok', true, 'iptal_edilen', v_iptal,
                            'bekleyen', v_pending, 'kabul_edilen', v_accepted);
end $function$;

-- ════════════════════════════════════════════════════════════════════════════
-- C. BİLDİRİM METİNLERİ — canlı gövdeye EN KÜÇÜK yama (desen bulunmazsa HATA;
--    zaten yamalıysa dokunmaz). Yardımcı dosya sonunda silinir.
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public._313_yama(p_fn regprocedure, p_desen text, p_yeni text, p_isaret text)
returns text language plpgsql security definer set search_path = public as $y$
declare g text; y text;
begin
  g := pg_get_functiondef(p_fn);
  if position(p_isaret in g) > 0 then return 'zaten'; end if;
  y := regexp_replace(g, p_desen, p_yeni);
  if y = g then raise exception '313: % icinde beklenen desen yok', p_fn; end if;
  execute y;
  return 'yamalandi';
end $y$;
revoke all on function public._313_yama(regprocedure, text, text, text) from public, anon, authenticated;

do $c$
declare s text;
begin
  -- Yeni istek → host'a: kim, hangi ilan, hangi gün
  s := public._313_yama('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure,
    'insert into notifications \(user_id, category, title, body, ref_type, ref_id\)\s*values \(v_av\.host_id, ''requests'', ''Yeni istek ✦'',\s*''Bir misafir lounge isteği gönderdi\.'', ''request'', v_req_id\);',
    $r$perform public.bildir(v_av.host_id, 'requests',
    public.kisa_ad(v_uid) || ' ilanına başvurdu ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || ' — kabul ya da reddet; yanıt bekleyen istekler İstek ekranında.',
    public.kisa_ad(v_uid) || ' applied to your listing ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || ' — accept or decline in Requests.',
    'request', v_req_id); -- 313_bildirim$r$,
    '313_bildirim');
  raise notice '313 create_request: %', s;

  s := public._313_yama('public.send_invite(uuid,uuid,text)'::regprocedure,
    'insert into notifications \(user_id, category, title, body, ref_type, ref_id\)\s*values \(p_guest, ''requests'', ''Lounge daveti ✦'',\s*coalesce\(v_av\.lounge_name, v_av\.airport_code\) \|\| '' · '' \|\| left\(coalesce\(p_note,''''\),80\), ''invite'', v_id\);',
    $r$perform public.bildir(p_guest, 'requests',
    public.kisa_ad(v_uid) || ' seni lounge''a davet etti ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || coalesce(' — ' || nullif(left(btrim(p_note), 80), ''), ''),
    public.kisa_ad(v_uid) || ' invited you to the lounge ✦',
    public.salon_etiketi(v_av.id) || ' · ' || to_char(v_av.avail_date, 'DD.MM') || coalesce(' — ' || nullif(left(btrim(p_note), 80), ''), ''),
    'invite', v_id); -- 313_bildirim$r$,
    '313_bildirim');
  raise notice '313 send_invite: %', s;

  s := public._313_yama('public.respond_invite(uuid,boolean)'::regprocedure,
    'insert into notifications \(user_id, category, title, body, ref_type, ref_id\)\s*values \(v_i\.host_id, ''requests'', ''Davetin kabul edildi ✓'', ''Sohbet açıldı, oturum başladı\.'', ''request'', v_req\);',
    $r$perform public.bildir(v_i.host_id, 'requests',
    public.kisa_ad(v_uid) || ' davetini kabul etti ✓',
    public.salon_etiketi(v_i.avail_id) || ' — sohbet açıldı. Buluşunca ikiniz de "Oturumu Başlat"a basın.',
    public.kisa_ad(v_uid) || ' accepted your invite ✓',
    public.salon_etiketi(v_i.avail_id) || ' — the chat is open. When you meet, both tap "Start session".',
    'request', v_req); -- 313_bildirim$r$,
    '313_bildirim');
  raise notice '313 respond_invite kabul: %', s;

  s := public._313_yama('public.respond_invite(uuid,boolean)'::regprocedure,
    'insert into notifications \(user_id, category, title, body, ref_type, ref_id\)\s*values \(v_i\.host_id, ''requests'', ''Davetin yanıtlandı'', ''Davet reddedildi\.'', ''invite'', p_id\);',
    $r$perform public.bildir(v_i.host_id, 'requests',
    public.kisa_ad(v_uid) || ' bu kez gelemiyor',
    public.salon_etiketi(v_i.avail_id) || ' davetin için teşekkür etti; yerin açık kaldı.',
    public.kisa_ad(v_uid) || ' can''t make it this time',
    'Thanks for the invite to ' || public.salon_etiketi(v_i.avail_id) || '; your spot stays open.',
    'invite', p_id); -- 313_bildirim_ret$r$,
    '313_bildirim_ret');
  raise notice '313 respond_invite ret: %', s;

  s := public._313_yama('public.send_connection(uuid,text,text)'::regprocedure,
    'insert into notifications \(user_id, category, title, body, ref_type, ref_id\)\s*values \(p_to, ''connections'', ''Yeni bağlantı isteği ◈'',\s*''Bir yolcu seninle bağlantı kurmak istiyor\.'', ''connection'', v_id\);',
    $r$perform public.bildir(p_to, 'connections',
    public.kisa_ad(v_uid) || ' seninle bağlantı kurmak istiyor ◈',
    coalesce(nullif(left(btrim(p_intro), 90), ''), 'Kabul edersen sohbet açılır.'),
    public.kisa_ad(v_uid) || ' wants to connect ◈',
    coalesce(nullif(left(btrim(p_intro), 90), ''), 'Accept to open a chat.'),
    'connection', v_id); -- 313_bildirim$r$,
    '313_bildirim');
  raise notice '313 send_connection: %', s;

  -- Mesaj bildirimi: tam ad yerine kısa ad (kilit ekranı)
  s := public._313_yama('public.trg_mesaj_bildirimi()'::regprocedure,
    'select coalesce\(nullif\(btrim\(p\.name\), ''''\), ''Bir kullanıcı''\)\s*into v_gonderen_ad from profiles p where p\.user_id = NEW\.from_id;',
    $r$v_gonderen_ad := public.kisa_ad(NEW.from_id); -- 313_kisa_ad$r$,
    '313_kisa_ad');
  raise notice '313 mesaj bildirimi: %', s;
end $c$;

-- ════════════════════════════════════════════════════════════════════════════
-- D. SORU AKIŞI — soru bir bağlantı değildir
-- ════════════════════════════════════════════════════════════════════════════
alter table connection_requests add column if not exists cevap text;
alter table connection_requests add column if not exists cevap_notu text;
alter table connection_requests add column if not exists cevap_at timestamptz;
do $$ begin
  alter table connection_requests add constraint connection_requests_cevap_chk
    check (cevap is null or cevap in ('evet','hayir'));
exception when duplicate_object then null; end $$;
comment on column connection_requests.cevap is
  '313: kural sorusunun yanıtı (evet = misafir alabiliyorum, hayir). Yanıtlanan soru status=declined olur: soru bir bağlantı kurmaz (accepted bağlantı sayılırdı → görünürlük sızıntısı).';

-- Rozet, düğme ve sunucu kapısı için TEK karar: rozetle AYNI hesap
-- (misafirin o günkü uçuşu + taşıyıcısı ile lounge_access_decision_v5).
create or replace function public.kural_sorusu_durumu(p_avail_id uuid)
returns text language plpgsql stable security definer set search_path = public as $function$
declare r availabilities%rowtype; v_flight text; d jsonb; v_prog lounge_programs%rowtype; v_bagli boolean;
begin
  select * into r from availabilities where id = p_avail_id;
  if not found or not coalesce(r.active, true) then return 'bilinmiyor'; end if;

  select v.flight_number into v_flight from visits v
   where v.user_id = auth.uid() and v.airport_code = r.airport_code
     and v.visit_date = r.avail_date and coalesce(v.flight_number,'') <> ''
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v5(p_avail_id, v_flight, public.guest_carrier_for(p_avail_id));
  if d is null then return 'bilinmiyor'; end if;
  if d ? 'known' and not coalesce((d ->> 'known')::boolean, false) then return 'bilinmiyor'; end if;

  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;
  v_bagli := v_prog.id is not null and coalesce(v_prog.entitlement_model, '') <> 'bank_card';
  if v_bagli and coalesce(d ->> 'carrier_ok','') = 'false' then return 'tasiyici'; end if;
  if v_bagli and coalesce((d ->> 'charter')::boolean, false) then return 'charter'; end if;

  if coalesce(d ->> 'guest_policy','') <> 'not_allowed' then return 'gerek_yok'; end if;
  if coalesce(d ->> 'confidence','') = 'verified' then return 'dogrulanmis'; end if;
  return 'uygun';
exception when others then
  return 'bilinmiyor';
end $function$;

create or replace function public.kural_sorusu_uygun_mu(p_avail_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.kural_sorusu_durumu(p_avail_id) = 'uygun'
$$;
revoke all on function public.kural_sorusu_durumu(uuid) from public, anon, authenticated;
grant execute on function public.kural_sorusu_durumu(uuid) to service_role;

-- Sunucu kapısı: ret SEBEBİYLE (rule_ask_dogrulanmis / _tasiyici / _charter / _gerek_yok / _bilinmiyor)
do $d$
declare s text;
begin
  s := public._313_yama('public.ilan_kurali_sor(uuid)'::regprocedure,
    'if not public\.kural_sorusu_uygun_mu\(p_avail_id\) then\s*raise exception ''rule_ask_not_applicable'';\s*end if;',
    $r$if public.kural_sorusu_durumu(p_avail_id) <> 'uygun' then  -- 313_sebep
    raise exception '%', 'rule_ask_' || public.kural_sorusu_durumu(p_avail_id);
  end if;$r$,
    '313_sebep');
  raise notice '313 ilan_kurali_sor: %', s;

  -- Rozet metni düğmeyle AYNI karardan: "sorabilirsin" yalnız sorulabiliyorsa.
  s := public._313_yama('public.discovery_rule_badges(uuid[])'::regprocedure,
    '(\n\s*)b := case when v_key is null then null else public\.badge_text\(v_key\) end;',
    $r$\1-- 313_soru_kapisi: "misafir hakkı yok" metni soru kapısıyla aynı karardan
\1if (d ->> 'guest_policy') = 'not_allowed' and v_key in ('guest_none','guest_none_soft') then
\1  v_key := case public.kural_sorusu_durumu(avail_id)
\1             when 'uygun' then 'guest_none_soft'
\1             when 'dogrulanmis' then 'guest_none'
\1             else 'guest_none_noask' end;
\1end if;
\1b := case when v_key is null then null else public.badge_text(v_key) end;$r$,
    '313_soru_kapisi');
  raise notice '313 discovery_rule_badges: %', s;
end $d$;

update beta_settings
   set value = value
     || jsonb_build_object('guest_none_soft', jsonb_build_object(
          'label', 'Misafir hakkı görünmüyor',
          'info', 'Elimizdeki bilgiye göre bu ilanda misafir hakkı yok, ama bunu resmî kaynaktan doğrulayamadık. '
               || 'Doğrulayamadığımız bir hakla seni kapıya göndermeyiz; o yüzden başvuru şimdilik kapalı. '
               || 'Aşağıdan host''a sorabilirsin: hakkını teyit edip ilanına eklerse başvuru açılır ve sana haber veririz.'))
     || jsonb_build_object('guest_none_noask', jsonb_build_object(
          'label', 'Misafir hakkı görünmüyor',
          'info', 'Elimizdeki bilgiye göre bu ilanda misafir hakkı yok. Doğrulayamadığımız bir hakla seni kapıya '
               || 'göndermeyiz; başvuru kapalı. Keşfet''te misafir alan başka ilanlara göz atabilirsin.'))
 where key = 'badge_labels';

-- Host'un yanıtı: Evet / Hayır + kısa not. Bağlantı ve sohbet AÇILMAZ.
create or replace function public.soruyu_yanitla(p_id uuid, p_cevap text, p_not text default null)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_ad text; v_salon text; v_not text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if coalesce(v_cr.intent,'') <> 'kural_sorusu' then raise exception 'not_a_question'; end if;
  if v_cr.status <> 'pending' then raise exception 'already_responded'; end if;
  if p_cevap is null or p_cevap not in ('evet','hayir') then raise exception 'invalid_answer'; end if;

  v_not := nullif(left(btrim(coalesce(p_not,'')), 200), '');
  update connection_requests
     set status = 'declined', cevap = p_cevap, cevap_notu = v_not,
         cevap_at = now(), responded_at = now()
   where id = p_id;

  v_ad := public.kisa_ad(v_uid);
  v_salon := coalesce(public.salon_etiketi(v_cr.avail_id), 'İlan');
  if p_cevap = 'evet' then
    perform public.bildir(v_cr.from_id, 'requests',
      v_ad || ' misafir alabildiğini söyledi',
      v_salon || ' — hakkını ilanına eklediğinde başvuru açılır, sana haber veririz.' || coalesce(' Not: “' || v_not || '”', ''),
      v_ad || ' says they can bring a guest',
      v_salon || ' — once they add the right to the listing, applications open and we''ll tell you.' || coalesce(' Note: “' || v_not || '”', ''),
      'question', p_id);
  else
    perform public.bildir(v_cr.from_id, 'requests',
      v_ad || ' sorunu yanıtladı',
      v_salon || ' — bu ilanda misafir alamıyor.' || coalesce(' Not: “' || v_not || '”', '') || ' Keşfet''te başka ilanlar var.',
      v_ad || ' answered your question',
      v_salon || ' — they can''t bring a guest on this listing.' || coalesce(' Note: “' || v_not || '”', '') || ' There are other listings in Discover.',
      'question', p_id);
  end if;
  return jsonb_build_object('ok', true, 'avail_id', v_cr.avail_id, 'cevap', p_cevap);
end $function$;
revoke all on function public.soruyu_yanitla(uuid, text, text) from public, anon;
grant execute on function public.soruyu_yanitla(uuid, text, text) to authenticated, service_role;

-- Eski istemci (6.2.6) soruyu respond_connection ile yanıtlıyordu: aynı yola yönlendir.
create or replace function public.respond_connection(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_chan uuid; v_ad text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_cr.status <> 'pending' then raise exception 'already_responded'; end if;

  if coalesce(v_cr.intent,'') = 'kural_sorusu' then
    return public.soruyu_yanitla(p_id, case when p_accept then 'evet' else 'hayir' end, null);
  end if;

  update connection_requests
     set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status,
         responded_at = now()
   where id = p_id;
  v_ad := public.kisa_ad(v_uid);

  if p_accept then
    insert into chat_channels (connection_id, kind, created_at)
    values (p_id, 'companion', now())
    on conflict (connection_id) where connection_id is not null do nothing
    returning id into v_chan;
    if v_chan is null then select id into v_chan from chat_channels where connection_id = p_id; end if;

    if v_chan is not null and coalesce(nullif(trim(v_cr.intro),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_cr.from_id, trim(v_cr.intro), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    perform public.bildir(v_cr.from_id, 'connections',
      v_ad || ' bağlantını kabul etti ✓', 'Sohbet açıldı — Oturumlar ve sohbetler › Bağlantılar.',
      v_ad || ' accepted your connection ✓', 'The chat is open — Sessions and chats › Connections.',
      'connection', p_id);
  else
    perform public.bildir(v_cr.from_id, 'connections',
      'Bağlantı isteğin yanıtlandı', v_ad || ' şu an bağlantı kurmuyor.',
      'Your connection request was answered', v_ad || ' isn''t connecting right now.',
      'connection', p_id);
  end if;

  return jsonb_build_object('ok', true, 'channel_id', v_chan);
end $function$;

-- Sorduklarım: yanıt alanları eklendi (dönüş tipi değişti → drop)
drop function if exists public.sorularim();
create function public.sorularim()
returns table(id uuid, host_id uuid, host_name text, salon text, airport_code text, avail_id uuid,
              durum text, cevap_durumu text, soruldu_at timestamptz, yanit_at timestamptz,
              ilan_acildi boolean, channel_id uuid, soru text, avail_date date,
              time_from time, time_to time, cevap text, cevap_notu text)
language plpgsql stable security definer set search_path = public as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select cr.id, cr.to_id,
         public.kisa_ad(cr.to_id),
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text,
         cr.avail_id,
         cr.status::text,
         case
           when cr.cevap = 'evet' then 'evet'
           when cr.cevap = 'hayir' then 'hayir'
           when cr.status::text = 'accepted' then 'yanitlandi'
           when cr.status::text = 'declined' then 'reddedildi'
           when cr.avail_id is not null
                and public.kural_sorusu_durumu(cr.avail_id) = 'gerek_yok' then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         cr.created_at, coalesce(cr.cevap_at, cr.responded_at),
         case when cr.avail_id is null then false
              else public.kural_sorusu_durumu(cr.avail_id) = 'gerek_yok' end,
         ch.id,
         nullif(btrim(coalesce(cr.intro,'')),''),
         a.avail_date, a.time_from, a.time_to,
         cr.cevap, cr.cevap_notu
    from connection_requests cr
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where cr.from_id = v_uid
     and cr.intent = 'kural_sorusu'
   order by cr.created_at desc
   limit 30;
end $function$;
revoke all on function public.sorularim() from public, anon;
grant execute on function public.sorularim() to authenticated, service_role;

-- Bana gelen sorular (host). Soranın fotoğrafı yalnız "herkese açık" ise.
create or replace function public.bana_gelen_sorular()
returns table(id uuid, soran_id uuid, soran_adi text, soran_foto text, soran_meslek text,
              avail_id uuid, salon text, airport_code text, avail_date date, time_from time, time_to time,
              soru text, durum text, cevap text, cevap_notu text, soruldu_at timestamptz, cevap_at timestamptz,
              ilan_acik boolean)
language plpgsql stable security definer set search_path = public as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select cr.id, cr.from_id, public.kisa_ad(cr.from_id),
         case when p.photo_url is not null and not coalesce(p.photo_connections_only, false) then p.photo_url end,
         nullif(btrim(coalesce(p.profession,'')), ''),
         cr.avail_id,
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text, a.avail_date, a.time_from, a.time_to,
         nullif(btrim(coalesce(cr.intro,'')),''),
         cr.status::text, cr.cevap, cr.cevap_notu, cr.created_at, coalesce(cr.cevap_at, cr.responded_at),
         case when cr.avail_id is null then false
              else coalesce((public.lounge_access_decision(cr.avail_id, null) ->> 'guest_policy'), '') <> 'not_allowed' end
    from connection_requests cr
    left join profiles p on p.user_id = cr.from_id
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
   where cr.to_id = v_uid
     and cr.intent = 'kural_sorusu'
     and not public.is_blocked_pair(v_uid, cr.from_id)
     and (cr.status = 'pending' or cr.created_at > now() - interval '60 days')
   order by coalesce(cr.status = 'pending', false) desc, cr.created_at desc
   limit 50;
end $function$;
revoke all on function public.bana_gelen_sorular() from public, anon;
grant execute on function public.bana_gelen_sorular() to authenticated, service_role;

-- Davetler ve istekler: SORULAR ÇIKTI (Soru ekranına taşındı); created_at eklendi (dönüş tipi → drop)
drop function if exists public.pending_actions();
create function public.pending_actions()
returns table(kind text, id uuid, title text, subtitle text, note text, from_name text, from_photo text,
              created_at timestamptz)
language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid();
begin
  return query
  select 'invite'::text, i.id,
         coalesce(a.lounge_name, a.airport_code),
         a.airport_code || ' · ' || a.avail_date::text,
         i.note, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false then p.photo_url else null end,
         i.created_at
    from invites i
    join availabilities a on a.id = i.avail_id
    join profiles p on p.user_id = i.host_id
   where i.guest_id = v_uid and i.status = 'pending'
  union all
  select 'connection'::text, cr.id, p.name, coalesce(cr.intent,'connect'), cr.intro, p.name,
         case when p.photo_url is not null and coalesce(p.photo_connections_only,false)=false then p.photo_url else null end,
         cr.created_at
    from connection_requests cr
    join profiles p on p.user_id = cr.from_id
   where cr.to_id = v_uid and cr.status = 'pending'
     and coalesce(cr.intent,'') <> 'kural_sorusu';
end $function$;
revoke all on function public.pending_actions() from public, anon;
grant execute on function public.pending_actions() to authenticated, service_role;

-- Eski (bağlantı olarak kabul edilmiş) sorulara yanıt etiketi: Soru ekranında "Evet" görünsün.
update connection_requests
   set cevap = 'evet', cevap_at = coalesce(responded_at, now())
 where intent = 'kural_sorusu' and status = 'accepted' and cevap is null;

-- ════════════════════════════════════════════════════════════════════════════
-- E. "YENİ" İŞARETİ — alan başına son bakış zamanı
--    Kural: bir alanda SON BAKIŞINDAN SONRA gelen/değişen bir şey varsa ana sayfa
--    kutusunda nokta yanar. Alana girince nokta söner (son bakış = şimdi); o
--    ziyaret boyunca yeni gelenler ince altın çerçeve + YENİ etiketi taşır,
--    bir sonraki ziyarette taşımaz. Sayı ("kaç bekliyor") ayrı bilgidir, değişmez.
-- ════════════════════════════════════════════════════════════════════════════
create table if not exists public.akis_goruldu (
  user_id    uuid not null,
  alan       text not null check (alan in ('sohbet','istek','davet','soru')),
  goruldu_at timestamptz not null default now(),
  primary key (user_id, alan)
);
alter table public.akis_goruldu enable row level security;
drop policy if exists akis_goruldu_kendi on public.akis_goruldu;
create policy akis_goruldu_kendi on public.akis_goruldu for select using (user_id = auth.uid());

-- Döner: ÖNCEKİ bakış zamanı (ilk kez: son 24 saat "yeni" sayılır).
create or replace function public.akis_goruldu_isaretle(p_alan text)
returns timestamptz language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_once timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_alan not in ('sohbet','istek','davet','soru') then raise exception 'invalid_area'; end if;
  select goruldu_at into v_once from akis_goruldu where user_id = v_uid and alan = p_alan;
  insert into akis_goruldu (user_id, alan, goruldu_at) values (v_uid, p_alan, now())
  on conflict (user_id, alan) do update set goruldu_at = excluded.goruldu_at;
  return coalesce(v_once, now() - interval '24 hours');
end $function$;
revoke all on function public.akis_goruldu_isaretle(text) from public, anon;
grant execute on function public.akis_goruldu_isaretle(text) to authenticated, service_role;

-- ana_sayfa_akisi: SORU = bana gelen yanıt bekleyen + benim yanıt bekleyen sorularım;
-- BAĞLANTI soruları saymaz (sorular Davet'ten çıktı); YENİ bayrakları eklendi.
create or replace function public.ana_sayfa_akisi()
returns jsonb language plpgsql stable security definer set search_path = public as $function$
declare
  v_uid uuid := auth.uid();
  v_sohbet int := 0; v_istek int := 0; v_davet int := 0; v_soru int := 0;
  v_baglanti int := 0; v_ilan int := 0;
  g_sohbet timestamptz; g_istek timestamptz; g_davet timestamptz; g_soru timestamptz;
  y_sohbet boolean; y_istek boolean; y_davet boolean; y_soru boolean;
begin
  if v_uid is null then
    return jsonb_build_object('sohbet',0,'istek',0,'davet',0,'soru',0,'baglanti',0,'ilan',0,
                              'yeni', jsonb_build_object('sohbet',false,'istek',false,'davet',false,'soru',false));
  end if;

  select count(*)::int into v_sohbet
    from connection_requests cr
   where cr.status = 'accepted'
     and (cr.from_id = v_uid or cr.to_id = v_uid)
     and not public.is_blocked_pair(v_uid,
           case when cr.from_id = v_uid then cr.to_id else cr.from_id end);
  v_sohbet := coalesce(v_sohbet, 0) + (select count(*)::int from requests r
                where r.status = 'accepted' and (r.host_id = v_uid or r.guest_id = v_uid));

  select count(*)::int into v_istek
    from requests r
   where r.status = 'pending' and (r.host_id = v_uid or r.guest_id = v_uid);

  select count(*) filter (where pa.kind = 'invite')::int into v_davet from public.pending_actions() pa;

  select count(*)::int into v_soru
    from connection_requests cr
   where cr.to_id = v_uid and cr.intent = 'kural_sorusu' and cr.status = 'pending'
     and not public.is_blocked_pair(v_uid, cr.from_id);
  v_soru := v_soru + (select count(*)::int from public.sorularim() s where s.cevap_durumu = 'bekliyor');

  select count(*)::int into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date >= current_date;

  select count(*)::int into v_baglanti
    from connection_requests cr
   where cr.to_id = v_uid and cr.status = 'pending'
     and coalesce(cr.intent,'') <> 'kural_sorusu';

  -- YENİ bayrakları
  select coalesce(max(goruldu_at) filter (where alan='sohbet'), now() - interval '24 hours'),
         coalesce(max(goruldu_at) filter (where alan='istek'),  now() - interval '24 hours'),
         coalesce(max(goruldu_at) filter (where alan='davet'),  now() - interval '24 hours'),
         coalesce(max(goruldu_at) filter (where alan='soru'),   now() - interval '24 hours')
    into g_sohbet, g_istek, g_davet, g_soru
    from akis_goruldu where user_id = v_uid;

  y_istek := exists (select 1 from requests r
                      where (r.host_id = v_uid and r.status = 'pending' and r.created_at > g_istek)
                         or (r.guest_id = v_uid and r.status = 'declined' and r.responded_at > g_istek));
  y_davet := exists (select 1 from invites i where i.guest_id = v_uid and i.status = 'pending' and i.created_at > g_davet)
          or exists (select 1 from connection_requests cr
                      where cr.to_id = v_uid and cr.status = 'pending'
                        and coalesce(cr.intent,'') <> 'kural_sorusu' and cr.created_at > g_davet);
  y_soru := exists (select 1 from connection_requests cr
                     where cr.intent = 'kural_sorusu'
                       and ((cr.to_id = v_uid and cr.status = 'pending' and cr.created_at > g_soru)
                         or (cr.from_id = v_uid and coalesce(cr.cevap_at, cr.responded_at) > g_soru)));
  y_sohbet := exists (select 1 from requests r
                       where r.guest_id = v_uid and r.status = 'accepted' and r.responded_at > g_sohbet)
           or exists (select 1 from sessions s join requests r on r.id = s.request_id
                       where s.status in ('pending','active')
                         and ((r.host_id = v_uid and (s.guest_started_at > g_sohbet or s.started_at > g_sohbet))
                           or (r.guest_id = v_uid and (s.host_started_at > g_sohbet or s.started_at > g_sohbet))))
           or exists (select 1 from messages m
                        join chat_channels c on c.id = m.channel_id
                        left join requests r on r.id = c.request_id
                        left join connection_requests cr on cr.id = c.connection_id
                       where m.from_id <> v_uid and m.read_at is null and m.created_at > g_sohbet
                         and ((r.id is not null and v_uid in (r.host_id, r.guest_id) and r.status in ('accepted','completed'))
                           or (cr.id is not null and v_uid in (cr.from_id, cr.to_id) and cr.status = 'accepted')));

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0),
    'istek',  coalesce(v_istek, 0),
    'davet',  coalesce(v_davet, 0),
    'soru',   coalesce(v_soru, 0),
    'baglanti', coalesce(v_baglanti, 0),
    'ilan', coalesce(v_ilan, 0),
    'yeni', jsonb_build_object('sohbet', y_sohbet, 'istek', y_istek, 'davet', y_davet, 'soru', y_soru)
  );
end $function$;

-- ════════════════════════════════════════════════════════════════════════════
-- C2. HATIRLATMALAR — yazılmıştı ama hiçbir zamanlayıcı çağırmıyordu.
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.yaklasan_bulusma_hatirlat()
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_n int := 0; r record;
begin
  for r in
    select q.id as req_id, q.host_id, q.guest_id, a.id as avail_id, a.time_from
      from requests q
      join availabilities a on a.id = q.avail_id
     where q.status = 'accepted'
       and public.yerel_an(a.avail_date, a.time_from, a.airport_code)
           between now() + interval '45 minutes' and now() + interval '75 minutes'
       and not exists (select 1 from sessions s where s.request_id = q.id and s.status in ('active','completed','cancelled'))
       and not exists (select 1 from notifications n where n.ref_type = 'meet_soon' and n.ref_id = q.id)
  loop
    perform public.bildir(r.host_id, 'sessions', 'Buluşmana 1 saat var ⏰',
      public.salon_etiketi(r.avail_id) || ' · ' || to_char(r.time_from, 'HH24:MI') || ' — ' || public.kisa_ad(r.guest_id)
        || ' ile. Buluşunca ikiniz de "Oturumu Başlat"a basın.',
      'Your meetup is in 1 hour ⏰',
      public.salon_etiketi(r.avail_id) || ' · ' || to_char(r.time_from, 'HH24:MI') || ' — with ' || public.kisa_ad(r.guest_id)
        || '. When you meet, both tap "Start session".',
      'meet_soon', r.req_id);
    perform public.bildir(r.guest_id, 'sessions', 'Buluşmana 1 saat var ⏰',
      public.salon_etiketi(r.avail_id) || ' · ' || to_char(r.time_from, 'HH24:MI') || ' — ' || public.kisa_ad(r.host_id)
        || ' ile. Biniş kartın yanında olsun; buluşunca ikiniz de "Oturumu Başlat"a basın.',
      'Your meetup is in 1 hour ⏰',
      public.salon_etiketi(r.avail_id) || ' · ' || to_char(r.time_from, 'HH24:MI') || ' — with ' || public.kisa_ad(r.host_id)
        || '. Keep your boarding pass handy; when you meet, both tap "Start session".',
      'meet_soon', r.req_id);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'hatirlatilan', v_n);
end $function$;
revoke all on function public.yaklasan_bulusma_hatirlat() from public, anon, authenticated;
grant execute on function public.yaklasan_bulusma_hatirlat() to service_role;

insert into zamanli_isler (is_adi, beklenen_saat, aciklama)
values ('yaklasan_bulusma_hatirlat', 1, 'Kabul edilmiş buluşmaya 1 saat kala iki tarafa hatırlatma (313)')
on conflict (is_adi) do nothing;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('ll-yaklasan-bulusma', '*/10 * * * *', $c$select public.zamanli_is_kos('yaklasan_bulusma_hatirlat')$c$);
    perform cron.schedule('ll-yarinki-lounge',   '0 16 * * *',   $c$select public.zamanli_is_kos('yarinki_lounge_hatirlat')$c$);
    perform cron.schedule('ll-puanlama',         '20 * * * *',   $c$select public.zamanli_is_kos('puanlama_hatirlat')$c$);
    raise notice '313: hatirlatma isleri zamanlandi (1 saat kala · yarin · puanlama)';
  else
    raise notice '313: pg_cron yok — hatirlatma isleri zamanlanamadi (yerel ortam)';
  end if;
exception when others then
  raise notice '313: cron zamanlanamadi (%)', sqlerrm;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- F. TANIŞ ARAMASI — Tanış listesinin gizlilik kurallarının aynısı
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.kisi_ara(p_q text)
returns table(user_id uuid, ad text, meslek text, foto text, iliski text)
language plpgsql stable security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_q text; v_female boolean; v_safe boolean; v_phone_ok boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_q := btrim(coalesce(p_q, ''));
  if char_length(v_q) < 2 then return; end if;
  v_q := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_');

  select (u.gender = 'female'), coalesce(pr.women_safety_mode, false)
    into v_female, v_safe
    from users u left join profiles pr on pr.user_id = u.id where u.id = v_uid;
  select coalesce(phone_verified, false) into v_phone_ok from verifications where verifications.user_id = v_uid;

  return query
  select p.user_id, public.kisa_ad(p.user_id),
         nullif(btrim(coalesce(p.profession, '')), ''),
         case when p.photo_url is not null and not coalesce(p.photo_connections_only, false) then p.photo_url end,
         coalesce((select c.status::text from connection_requests c
                    where ((c.from_id = v_uid and c.to_id = p.user_id) or (c.from_id = p.user_id and c.to_id = v_uid))
                      and coalesce(c.intent, '') <> 'kural_sorusu'
                    order by (c.status::text = 'accepted') desc, c.created_at desc limit 1), 'none')
    from profiles p
    join users hu on hu.id = p.user_id
   where p.user_id <> v_uid
     and hu.deleted_at is null and hu.banned_at is null
     and (p.name ilike v_q || '%' or p.name ilike '% ' || v_q || '%')   -- kelime başı
     and coalesce(p.show_on_discovery, true)
     and public.is_visible(p.user_id)
     and public.profil_gorunur_mu(p.user_id)
     and not public.is_blocked_pair(v_uid, p.user_id)
     and (not (coalesce(v_female, false) and coalesce(v_safe, false)) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode, false)
          or (coalesce(v_female, false) and coalesce(v_phone_ok, false))
          or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid))
   order by (p.name ilike v_q || '%') desc, p.name
   limit 20;
end $function$;
revoke all on function public.kisi_ara(text) from public, anon;
grant execute on function public.kisi_ara(text) to authenticated, service_role;

insert into rpc_client_surface (fn_name, client, note) values
  ('soruyu_yanitla', 'app', 'Soru › Gelen: host Evet/Hayır + not (313; bağlantı açmaz)'),
  ('bana_gelen_sorular', 'app', 'Soru › Gelen sekmesi (313)'),
  ('akis_goruldu_isaretle', 'app', 'Akış alanına girince YENİ işaretini söndürür (313)'),
  ('kisi_ara', 'app', 'Tanış araması (313)')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

-- ════════════════════════════════════════════════════════════════════════════
-- SONUÇ DENETİMİ — canlı gövdeler yeniden okunur
-- ════════════════════════════════════════════════════════════════════════════
do $$
declare v_eksik text[] := '{}';
begin
  if position('313_bildirim' in pg_get_functiondef('public.create_request_impl_preflag(uuid,text,text,text)'::regprocedure)) = 0 then v_eksik := v_eksik || 'create_request'::text; end if;
  if position('313_sebep' in pg_get_functiondef('public.ilan_kurali_sor(uuid)'::regprocedure)) = 0 then v_eksik := v_eksik || 'ilan_kurali_sor'::text; end if;
  if position('313_soru_kapisi' in pg_get_functiondef('public.discovery_rule_badges(uuid[])'::regprocedure)) = 0 then v_eksik := v_eksik || 'rozet'::text; end if;
  if position('313_kisa_ad' in pg_get_functiondef('public.trg_mesaj_bildirimi()'::regprocedure)) = 0 then v_eksik := v_eksik || 'mesaj'::text; end if;
  if position('status = ''active''' in pg_get_functiondef('public.istegin_acik_oturumu_var_mi(uuid)'::regprocedure)) = 0 then v_eksik := v_eksik || 'oturum_kapisi'::text; end if;
  if array_length(v_eksik, 1) is not null then
    raise exception '313: yamalanmamis: %', v_eksik;
  end if;
  raise notice '313: tamam — oturum kapisi tek tanim · isimli bildirimler · soru baglanti degil · yeni isareti · kisi_ara';
end $$;

drop function if exists public._313_yama(regprocedure, text, text, text);

-- ════════════════════════════════════════════════════════════════════════════
-- G. BİLDİRİME DOKUNUNCA DOĞRU YER (yeni bilgi mimarisi)
--    Eskiden istek ve oturum bildirimlerinin HEPSİ İlanlarım'a gidiyordu — misafir
--    için yanlış ekran. Artık: istek → İstek · kabul/oturum/1 saat kala → o buluşmanın
--    SOHBETİ · davet/bağlantı isteği → Davet · kabul edilen bağlantı → Bağlantılar ·
--    soru/yanıt → Soru. Tanımayan eski istemci (6.2.6) 'akis'/'istek_sohbet' hedefinde
--    hiçbir yere gitmez (zararsız).
-- ════════════════════════════════════════════════════════════════════════════
create or replace function public.bildirim_hedefi(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); n record; v_req requests%rowtype; v_cr connection_requests%rowtype; v_rid uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into n from notifications where id = p_id and user_id = v_uid;
  if n.id is null then return jsonb_build_object('ekran', null); end if;

  if n.ref_type = 'message' then
    return jsonb_build_object('ekran', 'sohbet', 'ref', n.ref_id);
  elsif n.ref_type = 'rate_reminder' then
    return jsonb_build_object('ekran', 'degerlendirmeler', 'ref', n.ref_id);
  elsif n.ref_type = 'trip_reminder' or n.ref_type = 'meet_soon' then
    return jsonb_build_object('ekran', 'istek_sohbet', 'ref', n.ref_id);
  elsif n.ref_type = 'question' then
    return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
  elsif n.ref_type = 'invite' then
    return jsonb_build_object('ekran', 'akis', 'alt', 'davet', 'ref', n.ref_id);
  elsif n.ref_type = 'session' then
    select request_id into v_rid from sessions where id = n.ref_id;
    if v_rid is not null then
      return jsonb_build_object('ekran', 'istek_sohbet', 'ref', v_rid);
    end if;
    return jsonb_build_object('ekran', 'akis', 'alt', 'sohbet');
  elsif n.ref_type = 'request' then
    select * into v_req from requests where id = n.ref_id;
    if v_req.id is not null and v_req.status in ('accepted','completed') then
      return jsonb_build_object('ekran', 'istek_sohbet', 'ref', v_req.id);
    end if;
    return jsonb_build_object('ekran', 'akis', 'alt', 'istek', 'ref', n.ref_id);
  elsif n.ref_type = 'connection' then
    select * into v_cr from connection_requests where id = n.ref_id;
    if v_cr.id is not null and coalesce(v_cr.intent,'') = 'kural_sorusu' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'accepted' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'baglanti', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'pending' and v_cr.to_id = v_uid then
      return jsonb_build_object('ekran', 'akis', 'alt', 'davet', 'ref', n.ref_id);
    end if;
    return jsonb_build_object('ekran', 'tanis', 'ref', n.ref_id);
  end if;

  return case n.category::text
    when 'requests'    then jsonb_build_object('ekran','akis','alt','istek','ref', n.ref_id)
    when 'sessions'    then jsonb_build_object('ekran','akis','alt','sohbet','ref', n.ref_id)
    when 'invites'     then jsonb_build_object('ekran','akis','alt','davet','ref', n.ref_id)
    when 'connections' then jsonb_build_object('ekran','tanis','ref', n.ref_id)
    when 'credits'     then jsonb_build_object('ekran','cuzdan')
    when 'ratings'     then jsonb_build_object('ekran','degerlendirmeler','ref', n.ref_id)
    when 'safety'      then jsonb_build_object('ekran','guvenlik')
    else jsonb_build_object('ekran', null) end;
end $function$;
