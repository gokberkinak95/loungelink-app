-- ════════════════════════════════════════════════════════════════════════
-- 307 · ZARAFET PROTOKOLÜ — AYLIK ATLAMA SINIRI (Gökberk onayı, 29 Eylül)
--
-- 🔴 NEDEN VAR
-- Biniş kartı doğrulamasını "atla" (SQL 294 · method = 'bypass') SINIRSIZDI:
-- biri her oturumda atlayabiliyor, doğrulama anlamsızlaşıyordu.
-- Karar (Gökberk: "önerin ok"):
--   · 30 günde 2 atlama SESSİZ geçer (kullanıcı kapıda bırakılmaz — 294'ün sözü).
--   · 3. atlamadan itibaren: atlama YİNE mümkün (kilit yok) ama
--       - karşı tarafa giden uyarı "son 30 gündeki N. atlama" cümlesini taşır,
--       - güven puanına `bp_atlama` bileşeni: sınırı aşan her atlama −3, en çok −9.
--   · Ceza 30 günlük pencereyle kendiliğinden düşer (080'in 90 günlük
--     güvenilirlik cezasıyla aynı mantık: kalıcı ceza toparlanmayı öldürür).
--
-- Tekrar koşulabilir (yalnız `create or replace` + `grant`). Veri değiştirmez;
-- son satırda herkesin puanı yeniden hesaplanmaz (gerek yok: bileşen yalnız
-- sınırı aşan kullanıcıda sıfırdan farklı, o da bir sonraki atlamada yazılır).
-- ════════════════════════════════════════════════════════════════════════

-- ── 1 · SAYAÇ ─────────────────────────────────────────────────────────
create or replace function public.binis_atlama_sayisi(p_user uuid)
returns int
language sql stable security definer set search_path = public as $fn$
  select count(*)::int from session_verifications
   where user_id = p_user and method = 'bypass'
     and created_at > now() - interval '30 days';
$fn$;

revoke all on function public.binis_atlama_sayisi(uuid) from public, anon, authenticated;

-- ── 2 · UYGULAMA İÇİN: kalan sessiz atlama ──────────────────────────────
create or replace function public.binis_karti_atlama_hakki()
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid(); v_n int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_n := public.binis_atlama_sayisi(v_uid);
  return jsonb_build_object('kullanilan', v_n, 'sessiz', 2, 'kalan', greatest(0, 2 - v_n));
end $fn$;

grant execute on function public.binis_karti_atlama_hakki() to authenticated;

-- ── 3 · GÜVEN PUANI (080'in gövdesi + `bp_atlama` bileşeni) ─────────────
create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
  v_sessions int; v_rating numeric; v_rating_n int; v_badge text;
  v_bad int; v_penalty int := 0; v_atla int;
begin
  select * into v_p from profiles where user_id = p_user;
  select * into v_v from verifications where user_id = p_user;

  select count(*) into v_sessions
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and (r.guest_id = p_user or r.host_id = p_user);

  v_c := v_c || '{"email":10}'::jsonb;
  if coalesce(v_v.phone_verified,false) then v_c := v_c || '{"phone":10}'::jsonb; end if;
  if coalesce(v_v.id_verified,false)    then v_c := v_c || '{"id":18}'::jsonb; end if;

  if coalesce(v_p.linkedin_verified, false) then
    v_c := v_c || '{"linkedin":8}'::jsonb;
  elsif coalesce(nullif(trim(v_p.linkedin_url),''), '') <> '' then
    v_c := v_c || '{"linkedin":4}'::jsonb;
  end if;

  if coalesce(nullif(trim(v_p.profession),''), '') <> '' then
    v_c := v_c || '{"profession":6}'::jsonb;
  end if;
  if length(coalesce(trim(v_p.bio),'')) >= 40 then
    v_c := v_c || '{"bio":6}'::jsonb;
  end if;

  if v_p.guest_capacity is not null and v_sessions >= 1 then
    v_c := v_c || '{"host_access":8}'::jsonb;
  end if;

  if v_sessions >= 10 then v_c := v_c || '{"sessions":14}'::jsonb;
  elsif v_sessions >= 3 then v_c := v_c || '{"sessions":10}'::jsonb;
  elsif v_sessions >= 1 then v_c := v_c || '{"sessions":6}'::jsonb;
  end if;

  select avg(score)::numeric, count(*) into v_rating, v_rating_n
    from ratings where rated_id = p_user;

  if coalesce(v_rating_n,0) >= 3 then
    if v_rating >= 4.5 then v_c := v_c || '{"rating":10}'::jsonb;
    elsif v_rating >= 4.0 then v_c := v_c || '{"rating":6}'::jsonb;
    elsif v_rating >= 3.0 then v_c := v_c || '{"rating":2}'::jsonb;
    end if;
  end if;

  -- 080: son 90 gündeki geç iptal + no-show cezası (her biri -12).
  select count(*) into v_bad from sessions s
   where s.completed_at > now() - interval '90 days'
     and ((s.cancel_reason = 'late_cancel' and s.cancelled_by = p_user)
       or (s.cancel_reason = 'no_show' and s.no_show_user_id = p_user));
  v_penalty := least(36, coalesce(v_bad,0) * 12);
  if v_penalty > 0 then
    v_c := v_c || jsonb_build_object('reliability', -v_penalty);
  end if;

  -- 307: 30 günde 2'yi aşan biniş kartı atlaması, her biri -3 (en çok -9).
  v_atla := greatest(0, public.binis_atlama_sayisi(p_user) - 2);
  if v_atla > 0 then
    v_c := v_c || jsonb_build_object('bp_atlama', -least(9, v_atla * 3));
  end if;

  select coalesce(sum(value::int),0) into v_score from jsonb_each_text(v_c);
  v_score := least(100, greatest(0, v_score));

  v_badge := public.compute_trust_badge(v_score);

  insert into trust_scores (user_id, score, badge, components, updated_at)
  values (p_user, v_score, v_badge, v_c, now())
  on conflict (user_id) do update
    set score = excluded.score, badge = excluded.badge,
        components = excluded.components, updated_at = now();

  return v_score;
end $$;

-- ── 4 · KAYIT (294'ün gövdesi + sınır) ─────────────────────────────────
create or replace function public.binis_karti_kaydet(
  p_request_id uuid,
  p_method text,
  p_passed boolean,
  p_reason_code text default null,
  p_airport text default null,
  p_flight_date date default null,
  p_carrier_flight text default null,
  p_cabin text default null,
  p_pnr_girdi text default null,
  p_duration_ms int default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid();
  v_tuz text; v_hash text; v_id uuid; v_diger uuid; v_ad text;
  v_q record; v_atla int := 0; v_govde text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);

  select * into v_q from requests where id = p_request_id;
  if v_q.id is null then raise exception 'request_not_found'; end if;
  if v_uid not in (v_q.host_id, v_q.guest_id) then raise exception 'not_participant'; end if;

  if p_method not in ('scan', 'gallery', 'file', 'bypass') then
    raise exception 'gecersiz_yontem';
  end if;

  if p_passed and coalesce(p_pnr_girdi, '') <> '' then
    select deger into v_tuz from sunucu_sirlari where anahtar = 'bp_tuz';
    v_hash := encode(sha256(convert_to(p_pnr_girdi || '|' || coalesce(v_tuz, ''), 'UTF8')), 'hex');
    if exists (select 1 from session_verifications sv
                where sv.bp_hash = v_hash and sv.passed and sv.user_id <> v_uid) then
      raise exception 'zaten_dogrulandi';
    end if;
  end if;

  insert into session_verifications
    (request_id, user_id, method, passed, reason_code, airport_code,
     flight_date, carrier_flight, cabin_code, bp_hash, duration_ms)
  values (p_request_id, v_uid, p_method::public.bp_yontem, p_passed, p_reason_code,
          nullif(upper(trim(coalesce(p_airport, ''))), '')::char(3),
          p_flight_date, p_carrier_flight,
          nullif(upper(trim(coalesce(p_cabin, ''))), '')::char(1),
          v_hash, p_duration_ms)
  returning id into v_id;

  if p_method = 'bypass' then
    v_atla := public.binis_atlama_sayisi(v_uid);
  end if;

  -- ESNEK GÜVENCE: karşı tarafa editoryal uyarı (294 metni kelimesi kelimesine).
  -- 307: sessiz hak (2) aşıldıysa sayı da söylenir.
  if p_method = 'bypass' or not p_passed then
    v_diger := case when v_uid = v_q.host_id then v_q.guest_id else v_q.host_id end;
    select coalesce(p.name, 'Yolcu') into v_ad from profiles p where p.user_id = v_uid;
    v_govde := 'Dijital biniş kartı doğrulaması sistem şartlarından dolayı tamamlanamadı. '
            || 'Lütfen turnike geçişi esnasında salon kurallarına manuel olarak '
            || 'uyduğunuzdan emin olun.';
    if v_atla > 2 then
      v_govde := v_govde || ' Bu, son 30 gündeki ' || v_atla || '. atlama.';
    end if;
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_diger, 'requests', 'Biniş kartı doğrulanamadı', v_govde, p_request_id, 'request');
  end if;

  if v_atla > 2 then
    perform public.recompute_trust(v_uid);
  end if;

  return jsonb_build_object('ok', true, 'id', v_id, 'method', p_method, 'passed', p_passed,
                            'atlama_30g', v_atla);
end $fn$;

grant execute on function public.binis_karti_kaydet(uuid, text, boolean, text, text, date, text, text, text, int)
  to authenticated;

-- ── 5 · DURUM (294 + taraf başına 30 günlük atlama sayısı) ──────────────
create or replace function public.binis_karti_durumu(p_request_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid(); v_q record; v_out jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_q from requests where id = p_request_id;
  if v_q.id is null then raise exception 'request_not_found'; end if;
  if v_uid not in (v_q.host_id, v_q.guest_id) then raise exception 'not_participant'; end if;

  select jsonb_object_agg(k, v) into v_out from (
    select case when sv.user_id = v_q.host_id then 'host' else 'guest' end as k,
           jsonb_build_object('method', sv.method, 'passed', sv.passed,
                              'reason', sv.reason_code, 'at', sv.created_at,
                              'atlama_30g', public.binis_atlama_sayisi(sv.user_id)) as v
      from session_verifications sv
     where sv.request_id = p_request_id
       and sv.id = (select sv2.id from session_verifications sv2
                     where sv2.request_id = p_request_id and sv2.user_id = sv.user_id
                     order by sv2.created_at desc limit 1)
  ) x;
  return coalesce(v_out, '{}'::jsonb);
end $fn$;

grant execute on function public.binis_karti_durumu(uuid) to authenticated;

select '307 kuruldu' as sonuc;
