-- ============================================================
-- LoungeLink · 080_session_lifecycle.sql
--
-- ÜRÜN KARARI (Gokberk, 4 Ağu) — ve NEDEN doğru:
--
-- 077'de "host kabul ederse oturum otomatik başlar" demiştik. Gokberk haklı
-- olarak şunu gördü: kabul, buluşmadan GÜNLER ÖNCE olabilir. O zaman
-- "oturum süresi 137:42" gibi anlamsız bir sayaç akar, escrow günlerce
-- kilitli kalır ve "aktif oturum" kavramı anlamını yitirir (has_active_session
-- çıkışı bile engelliyor!).
--
-- YENİ YAŞAM DÖNGÜSÜ — üç ayrı an, üç ayrı anlam:
--   1) KABUL    → anlaşma kuruldu. Sohbet açılır, slot dolar, kredi escrow'da.
--                 OTURUM YOK. (Bu aşamada iptal serbest ve cezasız.)
--   2) BAŞLATMA → iki taraf da fiziksel olarak buluştuğunu beyan eder.
--                 "Oturumu Başlat"a İKİ TARAF da basınca oturum 'active'
--                 olur ve süre O AN başlar. Tek taraflı başlatma, karşı
--                 tarafı gelmiş göstermek anlamına geleceği için kabul
--                 edilmez — güvenin temeli bu simetri.
--   3) TAMAMLAMA→ yine iki taraflı (mevcut confirm_session).
--
-- İPTAL KURALLARI (ceza merdiveni):
--   · Başlamadan önce, buluşma penceresi BİTMEDEN: serbest iptal.
--     Kredi anında iade, güven puanına etki YOK. (Plan değişir; ceza
--     vermek insanları uygulamayı kullanmaktan caydırır.)
--   · Başladıktan sonra İLK 5 DAKİKA: serbest iptal. "Geldim ama olmadı"
--     durumu gerçek — yanlış eşleşme, lounge doluluğu, uçuş değişikliği.
--     Kredi iade, ceza yok.
--   · 5 dakikadan SONRA iptal: GEÇ İPTAL sayılır. Misafirin kredisi
--     yanar, iptal EDENİN güven puanı düşer, karşı taraf etkilenmez.
--   · Buluşma penceresi geçtiği hâlde HİÇ başlatılmayan oturum:
--     kimin gelmediği bilinemez → iki tarafa da ceza YOK, kredi iade
--     edilir, kayıt 'expired' olarak kapanır. (Tek taraf başlat'a bastıysa
--     o taraf "geldim" beyanındadır; karşı taraf no-show işaretlenir.)
--
-- GÜVEN ETKİSİ: recompute_trust'a yeni bileşen — son 90 gündeki geç iptal
-- ve no-show başına -12 puan (taban 0). Tek yazıcı kuralı korunur.
-- ============================================================


-- ---------- 1) Şema: başlatma beyanları + iptal penceresi ----------
alter table sessions add column if not exists host_started_at  timestamptz;
alter table sessions add column if not exists guest_started_at timestamptz;
alter table sessions add column if not exists cancel_grace_until timestamptz;
alter table sessions add column if not exists no_show_user_id uuid references users(id);

-- 'pending' durumu: iki taraftan biri başlattı, diğeri bekleniyor.
do $$ begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
                  where t.typname='session_status' and e.enumlabel='pending') then
    alter type session_status add value 'pending' before 'active';
  end if;
end $$;
do $$ begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
                  where t.typname='session_status' and e.enumlabel='expired') then
    alter type session_status add value 'expired';
  end if;
end $$;


-- ---------- 2) respond_request: KABULDE ARTIK OTURUM AÇILMAZ ----------
-- 077'nin diğer tüm etkileri (ilk mesaj, bildirim, escrow, trigger'lı slot)
-- korunur; yalnız otomatik 'active' oturum kaldırılır.
create or replace function public.respond_request(
  p_request_id uuid,
  p_action     text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_av   availabilities%rowtype;
  v_bal  integer;
  v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;

  if p_action = 'accept' then
    if v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if v_req.status <> 'pending' then raise exception 'not_pending'; end if;

    select * into v_av from availabilities where id = v_req.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    update requests set status='accepted', responded_at=now() where id = v_req.id;

    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;

    -- 077-3: misafirin tanıtım metni sohbetin ilk mesajı
    if v_chan is not null and coalesce(nullif(trim(v_req.intro_message),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_req.guest_id, trim(v_req.intro_message), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- 080: OTURUM BURADA AÇILMAZ. Kabul, buluşma günlerce sonra olabileceği
    -- için "aktif oturum" değildir; iki taraf buluşunca start_session_request
    -- ile başlatılır.
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_req.guest_id, 'requests', 'İstek kabul edildi! 🎉',
            'Sohbet açıldı. Buluştuğunuzda iki taraf da "Oturumu Başlat"a basacak.',
            v_req.id, 'request');

    return jsonb_build_object('ok', true, 'channel_id', v_chan, 'session_id', null);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id  <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;
    -- 080: oturum başladıysa istek üzerinden iptal edilemez (cancel_session yolu)
    if exists (select 1 from sessions s where s.request_id = v_req.id and s.status in ('pending','active')) then
      raise exception 'session_started';
    end if;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;

    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'request_refund', v_req.id, v_bal + 1);

    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (case when p_action='decline' then v_req.guest_id else v_req.host_id end,
            'requests',
            case when p_action='decline' then 'İstek reddedildi' else 'İstek iptal edildi' end,
            'Kredi anında iade edildi.', v_req.id, 'request');
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown_action';
end $$;
grant execute on function public.respond_request(uuid, text) to authenticated;


-- ---------- 3) ÇİFT ONAYLI BAŞLATMA ----------
-- Her iki taraf da çağırır. İlk çağıran 'pending' oturumu açar, ikincisi
-- 'active' yapar ve süre O AN başlar + 5 dakikalık iptal penceresi kurulur.
create or replace function public.start_session_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_req requests%rowtype; v_s sessions%rowtype;
  v_is_host boolean; v_both boolean; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_req from requests where id = p_request_id;
  if not found then raise exception 'request_not_found'; end if;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_req.status <> 'accepted' then raise exception 'request_not_accepted'; end if;
  v_is_host := (v_uid = v_req.host_id);

  select * into v_s from sessions where request_id = p_request_id for update;
  if not found then
    insert into sessions (request_id, status,
                          host_started_at, guest_started_at)
    values (p_request_id, 'pending',
            case when v_is_host then now() end,
            case when not v_is_host then now() end)
    returning * into v_s;
    -- karşı tarafa "seni bekliyor" bildirimi
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (case when v_is_host then v_req.guest_id else v_req.host_id end,
            'sessions', 'Oturum başlatılmayı bekliyor',
            'Karşı taraf buluştuğunuzu işaretledi. Sen de onaylayınca oturum başlar.',
            'session', v_s.id);
    return jsonb_build_object('ok', true, 'id', v_s.id, 'status', 'pending', 'both', false);
  end if;

  if v_s.status = 'active' then
    return jsonb_build_object('ok', true, 'id', v_s.id, 'status', 'active', 'both', true);
  end if;
  if v_s.status <> 'pending' then raise exception 'session_closed'; end if;

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
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    select u, 'sessions', 'Oturum başladı ⏱',
           'İlk 5 dakika içinde iptal edersen kredin iade edilir.', 'session', v_s.id
      from unnest(array[v_req.host_id, v_req.guest_id]) u;
  end if;

  return jsonb_build_object('ok', true, 'id', v_s.id,
                            'status', case when v_both then 'active' else 'pending' end,
                            'both', v_both);
end $$;
grant execute on function public.start_session_request(uuid) to authenticated;

-- Eski adı da çalışır tutalım (eski APK'lar): tek taraflı başlatmaz, aynı
-- çift onay kuralına girer.
create or replace function public.start_session(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  return public.start_session_request(p_request_id);
end $$;
grant execute on function public.start_session(uuid) to authenticated;


-- ---------- 4) İPTAL — ceza merdiveni ----------
create or replace function public.cancel_session(p_session_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype;
  v_late boolean; v_bal int; v_other uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_req from requests where id = v_s.request_id;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_s.status not in ('pending','active') then raise exception 'session_closed'; end if;
  v_other := case when v_uid = v_req.host_id then v_req.guest_id else v_req.host_id end;

  -- GEÇ İPTAL: oturum aktif VE 5 dakikalık pencere kapandıysa
  v_late := (v_s.status = 'active'
             and v_s.cancel_grace_until is not null
             and now() > v_s.cancel_grace_until);

  update sessions
     set status = 'cancelled', cancelled_by = v_uid,
         cancel_reason = coalesce(nullif(trim(p_reason),''), case when v_late then 'late_cancel' else 'cancelled' end),
         completed_at = now()
   where id = p_session_id;
  update requests set status = 'cancelled' where id = v_s.request_id;
  -- slot iadesi: trg_requests_sync_filled otomatik

  if v_late then
    -- Kredi YANAR (misafirin escrow'u kullanılmış sayılır) ve iptal EDENİN
    -- güveni düşer. Karşı taraf hiçbir şey kaybetmez.
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_req.guest_id, 0, 'late_cancel_forfeit', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_req.guest_id;
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_other, 'sessions', 'Oturum iptal edildi',
            'Karşı taraf oturumu geç iptal etti. Bu durum güven puanına yansıdı; sen etkilenmedin.',
            'session', p_session_id);
  else
    -- Serbest iptal: kredi iade, ceza yok.
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'session_cancel_refund', p_session_id, v_bal + 1);
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_other, 'sessions', 'Oturum iptal edildi',
            'Plan değişmiş. Kredi iade edildi, kimsenin puanı etkilenmedi.',
            'session', p_session_id);
  end if;

  perform public.recompute_trust(v_uid);
  perform public.recompute_trust(v_other);
  return jsonb_build_object('ok', true, 'late', v_late);
end $$;
grant execute on function public.cancel_session(uuid, text) to authenticated;


-- ---------- 5) OTOMATİK SÜRE AŞIMI (no-show / unutulmuş kabul) ----------
-- Ücretsiz katmanda zamanlanmış görev yok; bu fonksiyon uygulama açılışında
-- çağrılır (ucuz, idempotent). Buluşma penceresi + 2 saat geçmiş ve hâlâ
-- başlamamış işleri kapatır.
create or replace function public.expire_stale_sessions()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_req int := 0; v_sess int := 0;
begin
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu → cezasız
  --     kapanış + kredi iadesi.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted' and s.id is null
       and (a.avail_date + a.time_to) < (now() at time zone 'utc') - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, 1, 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0) + 1
    from upd u;
  get diagnostics v_req = row_count;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  --     Başlatan taraf "geldim" beyanındadır; gelmeyen no_show işaretlenir.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and (a.avail_date + a.time_to) < (now() at time zone 'utc') - interval '2 hours';
  get diagnostics v_sess = row_count;

  -- Etkilenenlerin güvenini tazele
  perform public.recompute_trust(u) from (
    select distinct no_show_user_id as u from sessions
     where cancel_reason = 'no_show' and no_show_user_id is not null
       and completed_at > now() - interval '1 day'
  ) x where u is not null;

  return jsonb_build_object('ok', true, 'expired_requests', v_req, 'expired_sessions', v_sess);
end $$;
grant execute on function public.expire_stale_sessions() to authenticated;


-- ---------- 6) GÜVEN: geç iptal / no-show cezası ----------
-- 078'in TEK YAZICI kuralı korunur; ceza recompute_trust'ın İÇİNDE.
create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
  v_sessions int; v_rating numeric; v_rating_n int; v_badge text;
  v_bad int; v_penalty int := 0;
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

  -- 🔴 080: SON 90 GÜNDEKİ GEÇ İPTAL + NO-SHOW CEZASI (her biri -12).
  -- Neden 90 gün: ceza kalıcı olursa kullanıcı asla toparlanamaz; unutulan
  -- ceza da caydırıcı olmaz. 90 gün ikisinin dengesi.
  select count(*) into v_bad from sessions s
   where s.completed_at > now() - interval '90 days'
     and ((s.cancel_reason = 'late_cancel' and s.cancelled_by = p_user)
       or (s.cancel_reason = 'no_show' and s.no_show_user_id = p_user));
  v_penalty := least(36, coalesce(v_bad,0) * 12);
  if v_penalty > 0 then
    v_c := v_c || jsonb_build_object('reliability', -v_penalty);
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
grant execute on function public.recompute_trust(uuid) to authenticated;

do $$ declare u uuid; begin
  for u in select user_id from profiles loop perform public.recompute_trust(u); end loop;
end $$;


-- ---------- 7) has_active_session: 'pending' oturum çıkışı engellemesin ----------
-- 🔴 080 (Gokberk): ÇIKIŞ ARTIK HİÇBİR ŞEKİLDE ENGELLENMEZ.
-- Eski kural "aktif oturumun varken çıkamazsın" diyordu; kullanıcı tek
-- taraflı başlattığı bir oturum yüzünden uygulamada KİLİTLİ kalıyordu.
-- Çıkışı engellemek zaten güvenlik sağlamıyor (uygulamayı silmek serbest);
-- yalnızca öfke üretiyor. Fonksiyon geriye dönük duruyor ama uygulama
-- artık çıkışı buna bağlamıyor; oturum kaydı kullanıcı geri döndüğünde
-- olduğu yerden devam eder.
create or replace function public.has_active_session()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from sessions s join requests r on r.id = s.request_id
     where s.status = 'active' and (r.host_id = auth.uid() or r.guest_id = auth.uid())
  )
$$;
grant execute on function public.has_active_session() to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select (prosrc not ilike '%insert into sessions (request_id, status, started_at)%') as "kabulde_oturum_acilmiyor"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='respond_request';

select exists (select 1 from pg_proc where proname='start_session_request') as "cift_onayli_baslatma_var",
       exists (select 1 from pg_proc where proname='cancel_session')        as "iptal_fonksiyonu_var",
       exists (select 1 from pg_proc where proname='expire_stale_sessions') as "sure_asimi_var";

select (prosrc ilike '%reliability%') as "guvende_ceza_bileseni"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='recompute_trust';

select '080 OK - oturum cift onayla baslar, 5 dk iptal penceresi, gec iptal/no-show cezasi, otomatik sure asimi' as sonuc;
