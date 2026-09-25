-- ============================================================
-- LoungeLink · 077_session_autostart_intro_slots.sql
--
-- Gokberk'in "son düzenlemeler" turundaki DÖRT sunucu-tarafı bulgusu:
--
-- 1) SLOT SAYACI SAPIYOR ("açık slot olmasına rağmen 0 slot açık")
--    filled elle +1/-1 ile yönetiliyordu: 007, 009, 030 (davet), 061
--    (istek) ve SEED hepsi ayrı ayrı yazıyor. Bir yol bile atlarsa ya da
--    iki yol aynı kabulü sayarsa sayaç kalıcı olarak bozuluyor ve ilan
--    "dolu" görünüp keşiften düşüyor. Artık filled TÜRETİLMİŞ değer:
--    requests tablosundaki gerçek kabullerden trigger ile hesaplanır.
--
-- 2) "HOSTUN OTURUM BAŞLATMASINA GEREK YOK" (ürün kararı — Gokberk)
--    İki taraf da anlaştıysa (host kabul etti) oturum ZATEN başlamıştır.
--    Ayrı bir "Oturumu Başlat" adımı ölü bir adımdı ve host tarafında
--    görünmediği için akış tamamen kilitleniyordu. Kabulde oturum
--    otomatik 'active' açılır; iki taraf da doğrudan "Oturumu Tamamla"
--    görür. start_session GERİYE DÖNÜK ÇALIŞMAYA DEVAM EDER (eski
--    sürümdeki app'ler kırılmasın) ama artık host şartı aramaz.
--
-- 3) "İLK MESAJ SOHBETE YANSIMIYOR"
--    İstek/davet/bağlantı gönderirken yazılan tanıtım metni yalnızca
--    requests.intro_message / invites.note / connection_requests.intro
--    kolonunda duruyordu; sohbet BOŞ açılıyordu. Artık kabulde ilk mesaj
--    olarak kanala yazılır (gönderen = metni yazan kişi).
--
-- 4) "LOUNGE HAKKI BEYANI PUANI İLK OTURUMDAN SONRA VERİLMELİ" (Gokberk)
--    recompute_trust, guest_capacity DOLU diye 8 puan veriyordu — beyan
--    ederek kazanılan güven. Artık en az 1 TAMAMLANMIŞ oturum şartı var.
--
-- Sıra bağımlılığı yok, tek seferde çalıştırılabilir, idempotent.
-- ============================================================


-- ============================================================
-- 1) FILLED = TÜRETİLMİŞ DEĞER (trigger ile korunur)
-- ============================================================
create or replace function public.sync_availability_filled()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_av uuid;
begin
  v_av := coalesce(new.avail_id, old.avail_id);
  if v_av is null then return coalesce(new, old); end if;
  -- ⚠️ TAVAN ŞART: availabilities tablosunda `check (filled <= slots)`
  -- kısıtı var. Geçmişte sayaç bozulduğu için bazı ilanlarda slots=2 iken
  -- ÜÇ kabul edilmiş/tamamlanmış istek birikmiş olabiliyor (canlıda oldu:
  -- slots=2, hesaplanan 3 → kısıt ihlali, migration patladı). Hesaplanan
  -- değer slot sayısıyla SINIRLANIR; aşım BO'da anomali olarak görülebilir
  -- (aşağıdaki doğrulama sorgusu listeler).
  update availabilities a
     set filled = least(
           a.slots,
           (select count(*) from requests r
             where r.avail_id = v_av
               and r.status in ('accepted','completed'))
         ),
         updated_at = now()
   where a.id = v_av;
  return coalesce(new, old);
end $$;

drop trigger if exists trg_requests_sync_filled on requests;
create trigger trg_requests_sync_filled
after insert or update of status or delete on requests
for each row execute function public.sync_availability_filled();

-- Mevcut veriyi bir kez onar (birikmiş sapma varsa temizlenir)
update availabilities a
   set filled = least(a.slots, coalesce(x.n, 0)), updated_at = now()
  from (
    select av.id,
           count(r.id) filter (where r.status in ('accepted','completed')) as n
      from availabilities av
      left join requests r on r.avail_id = av.id
     group by av.id
  ) x
 where x.id = a.id
   and coalesce(a.filled,0) <> least(a.slots, coalesce(x.n,0));


-- ============================================================
-- 2+3) respond_request — kabulde OTOMATİK OTURUM + İLK MESAJ
--      (061'in gövdesi korunur; filled yazımı artık trigger'da)
-- ============================================================
create or replace function public.respond_request(
  p_request_id uuid,
  p_action     text  -- 'accept' | 'decline' | 'cancel'
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_av   availabilities%rowtype;
  v_bal  integer;
  v_chan uuid;
  v_sess uuid;
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
    -- filled: trg_requests_sync_filled hallediyor (elle +1 YOK — çift sayım kaynağıydı)

    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;

    -- YENİ (077-3): misafirin istekte yazdığı tanıtım metni sohbetin İLK
    -- MESAJI olur. Yoksa sohbet bomboş açılıyor ve host neye "evet"
    -- dediğini sohbet ekranında göremiyordu.
    if v_chan is not null and coalesce(nullif(trim(v_req.intro_message),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_req.guest_id, trim(v_req.intro_message), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- YENİ (077-2): OTOMATİK OTURUM. Host kabul ettiyse iki taraf da
    -- anlaşmıştır; ayrı "başlat" adımı yok.
    select id into v_sess from sessions where request_id = v_req.id;
    if v_sess is null then
      insert into sessions (request_id, status, started_at)
      values (v_req.id, 'active', now()) returning id into v_sess;
      -- escrow capture: tutulan kredi onaylanır (defterde kapama satırı)
      select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_req.guest_id, 0, 'request_capture', v_req.id, v_bal);
    end if;

    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_req.guest_id, 'requests', 'İstek kabul edildi! 🎉',
            'Sohbet açıldı, oturum başladı.', v_req.id, 'request');

    return jsonb_build_object('ok', true, 'channel_id', v_chan, 'session_id', v_sess);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id  <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;
    -- slot iadesi: trigger otomatik (accepted sayısı düştü)

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


-- ============================================================
-- 2b) start_session — geriye dönük uyumluluk
-- Eski APK'lar hâlâ çağırabilir. Artık yalnız host şartı YOK (iki taraf
-- da başlatabilir) ve oturum zaten varsa onu döndürür.
-- ============================================================
create or replace function public.start_session(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_req requests%rowtype; v_sess_id uuid; v_bal int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_req from requests where id = p_request_id;
  if not found then raise exception 'request_not_found'; end if;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_participant'; end if;
  if v_req.status <> 'accepted' then raise exception 'request_not_accepted'; end if;

  select id into v_sess_id from sessions where request_id = p_request_id;
  if v_sess_id is not null then return jsonb_build_object('ok', true, 'id', v_sess_id, 'existing', true); end if;

  insert into sessions (request_id, status, started_at)
  values (p_request_id, 'active', now()) returning id into v_sess_id;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_req.guest_id, 0, 'request_capture', p_request_id, v_bal);

  -- 008/026'daki bildirim korunur (karşı tarafa haber)
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (case when v_uid = v_req.host_id then v_req.guest_id else v_req.host_id end,
          'sessions', 'Oturum açıldı ✓', 'Oturum aktif.', 'session', v_sess_id);

  return jsonb_build_object('ok', true, 'id', v_sess_id);
end $$;
grant execute on function public.start_session(uuid) to authenticated;


-- ============================================================
-- 3b) respond_connection — kabulde tanıtım metni ilk mesaj olur
--     (069'un gövdesi korunur; yalnız mesaj ekleme geldi)
-- ============================================================
CREATE OR REPLACE FUNCTION public.respond_connection(p_id uuid, p_accept boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_cr.status <> 'pending' then raise exception 'already_responded'; end if;

  update connection_requests set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status
   where id = p_id;

  if p_accept then
    insert into chat_channels (connection_id, kind, created_at)
    values (p_id, 'companion', now())
    on conflict (connection_id) where connection_id is not null do nothing
    returning id into v_chan;
    if v_chan is null then select id into v_chan from chat_channels where connection_id = p_id; end if;

    -- YENİ (077-3): "Bağlan" ekranında yazılan tanıtım sohbetin ilk mesajı
    if v_chan is not null and coalesce(nullif(trim(v_cr.intro),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_cr.from_id, trim(v_cr.intro), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı kabul edildi ✓', 'Sohbet açıldı.', 'connection', p_id);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı yanıtlandı', 'İstek reddedildi.', 'connection', p_id);
  end if;

  return jsonb_build_object('ok', true, 'channel_id', v_chan);
end $function$;
grant execute on function public.respond_connection(uuid, boolean) to authenticated;


-- ============================================================
-- 3c) respond_invite — davet notu ilk mesaj + otomatik oturum
--     (030'un gövdesi korunur; filled yazımı trigger'a devredildi)
-- ============================================================
CREATE OR REPLACE FUNCTION public.respond_invite(p_id uuid, p_accept boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_i invites%rowtype; v_req uuid; v_chan uuid;
  v_bal int; v_sess uuid; v_av availabilities%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_i from invites where id = p_id for update;
  if not found then raise exception 'invite_not_found'; end if;
  if v_i.guest_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_i.status <> 'pending' then raise exception 'already_responded'; end if;

  update invites set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status
   where id = p_id;

  if p_accept then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
    if v_bal < 1 then raise exception 'insufficient_credits'; end if;

    -- 030'daki KAPASİTE KONTROLÜ korunur: dolu ilana davet kabul edilemez.
    -- (drift_check bunu düşen adım olarak yakaladı — gerçek kayıptı.)
    select * into v_av from availabilities where id = v_i.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    -- NOT: request_type enum'unda 'invite' YOK ('standard' | 'direct_invite').
    -- 030'daki gövde 'invite' yazıyordu — davet kabulü bu yüzden de
    -- kırılabilirdi. Doğru değer: 'direct_invite'.
    insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score)
    values (v_uid, v_i.host_id, v_i.avail_id, 'accepted', 'direct_invite', v_i.note, 60)
    returning id into v_req;

    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_uid, -1, 'invite_hold', v_req, v_bal - 1);
    -- filled: trigger

    insert into chat_channels (request_id, kind) values (v_req, 'lounge')
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req;

    -- Davet notu ilk mesaj (gönderen: HOST — daveti o yazdı)
    if v_chan is not null and coalesce(nullif(trim(v_i.note),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_i.host_id, trim(v_i.note), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- Otomatik oturum (kabul = anlaşma)
    insert into sessions (request_id, status, started_at)
    values (v_req, 'active', now()) returning id into v_sess;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin kabul edildi ✓', 'Sohbet açıldı, oturum başladı.', 'request', v_req);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin yanıtlandı', 'Davet reddedildi.', 'invite', p_id);
  end if;

  return jsonb_build_object('ok', true, 'request_id', v_req, 'channel_id', v_chan);
end $function$;
grant execute on function public.respond_invite(uuid, boolean) to authenticated;


-- ============================================================
-- 4) recompute_trust — "Lounge hakkı beyanı" puanı ARTIK KAZANILIR
--    (046'nın gövdesi birebir; yalnız host_access koşulu değişti)
-- ============================================================
create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
  v_sessions int; v_rating numeric; v_rating_n int; v_badge text;
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

  -- 🔴 077-4 (Gokberk): beyan tek başına güven getirmez. Lounge hakkı puanı
  -- yalnızca EN AZ 1 TAMAMLANMIŞ OTURUM sonrası verilir — yani beyanın
  -- gerçekten karşılığı olduğu bir kez görüldükten sonra.
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

  select coalesce(sum(value::int),0) into v_score from jsonb_each_text(v_c);
  v_score := least(100, greatest(0, v_score));

  v_badge := case when v_score >= 88 then 'trusted_plus'
                  when v_score >= 72 then 'trusted'
                  when v_score >= 56 then 'verified'
                  else 'basic' end;

  insert into trust_scores (user_id, score, badge, components, updated_at)
  values (p_user, v_score, v_badge, v_c, now())
  on conflict (user_id) do update
    set score = excluded.score, badge = excluded.badge,
        components = excluded.components, updated_at = now();

  return v_score;
end $$;
grant execute on function public.recompute_trust(uuid) to authenticated;

-- Herkesin puanını yeni kurala göre tazele
do $$ declare u uuid; begin
  for u in select user_id from profiles loop perform public.recompute_trust(u); end loop;
end $$;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
-- (1) 0 dönmeli: filled sayacı gerçek kabullerle (slot tavanı dahil) tutmalı
select count(*) as "filled_sapmasi_kaldi"
  from availabilities a
  left join (
    select avail_id, count(*) filter (where status in ('accepted','completed')) n
      from requests group by avail_id
  ) r on r.avail_id = a.id
 where coalesce(a.filled,0) <> least(a.slots, coalesce(r.n,0));

-- (1b) BİLGİ: kapasitesinden FAZLA kabul birikmiş ilanlar (geçmiş veri
-- bozukluğu). Boş dönmesi beklenir; satır varsa o ilanlarda bir dönem
-- fazladan kabul yapılmış demektir — kayıt olarak burada görünür.
select a.id, a.airport_code, a.avail_date, a.slots,
       count(r.id) filter (where r.status in ('accepted','completed')) as kabul_sayisi
  from availabilities a join requests r on r.avail_id = a.id
 group by a.id, a.airport_code, a.avail_date, a.slots
having count(r.id) filter (where r.status in ('accepted','completed')) > a.slots;

-- (2) true dönmeli: kabulde oturum + ilk mesaj + trigger
select (prosrc ilike '%sessions (request_id, status, started_at)%') as "otomatik_oturum",
       (prosrc ilike '%intro_message%')                              as "ilk_mesaj"
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname='public' and p.proname='respond_request';

select exists (select 1 from pg_trigger where tgname = 'trg_requests_sync_filled') as "slot_trigger_var";

-- (3) true dönmeli: lounge hakkı puanı artık oturum şartlı
select (prosrc ilike '%v_sessions >= 1 then%' and prosrc ilike '%host_access%') as "beyan_puani_kazanilir"
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname='public' and p.proname='recompute_trust';

select '077 OK - slot sayaci trigger ile korunuyor, kabulde oturum otomatik, ilk mesaj sohbete dusuyor, beyan puani kazanilir' as sonuc;
