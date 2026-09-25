-- ============================================================
-- LoungeLink · 159_grants_home_flows_request_gate.sql
-- İKİNCİ CİHAZ TURUNUN BULGULARI (13 Ağu 2026)
--
-- ⚠️ Uygulamayı ETKİLER. Her madde yerel PG'de jwt taklidiyle
-- ÖLÇÜLDÜ; tahmin yok.
--
-- ------------------------------------------------------------
-- 🔴 YENİ SESSİZ HATA SINIFI: "POLİTİKA VAR, GRANT YOK"
-- ------------------------------------------------------------
-- RLS politikaları 59/59 tamdı; ama authenticated rolünde requests,
-- connection_requests, chat_channels, messages gibi tabloların
-- TABLO GRANT'ı hiç yoktu. RPC'ler security definer olduğu için
-- E2E'ler yemyeşildi — app'in DOĞRUDAN tablo sorguları ise canlıda
-- "permission denied" alıp sessizce boş dönüyordu:
--   · Ana sayfa "Bekleyen" sayacı hep 0 (requests'e doğrudan sorgu)
--   · RequestsPanel: Promise.all'da tablo sorgusu reject olunca
--     RPC'den gelen GELEN İSTEKLER de düşüyordu → "başvuruyu hiçbir
--     yerde göremiyorum" (Gökberk, madde 1)
--   · HomeConnections: chat_channels'a dokunur dokunmaz patlıyordu →
--     ana sayfada bağlantı hiç görünmüyordu (madde 2)
-- RLS denetimimiz politikaları sayıyordu, grant'ları değil. Ders:
-- güvenlik iki katman — RLS karar verir, GRANT kapıyı açar.
-- ============================================================

-- ---- 1) GRANT ENVANTERİ ----
-- App'in DOĞRUDAN sorguladığı tablolar (screens.js from() taraması,
-- 13 Ağu). Güvenlik RLS'te kalır; burada yalnız kapı açılır.
do $$
declare tb text;
begin
  foreach tb in array array[
    'profiles','users','connection_requests','verifications','sessions',
    'chat_channels','trust_scores','visits','airports','requests',
    'messages','notifications','availabilities','user_balances',
    'credit_ledger','ratings','points_ledger','lounges','avatars','rewards',
    'invites','beta_settings','lounge_programs','lounge_venues'
  ] loop
    if to_regclass('public.'||tb) is not null then
      execute format('grant select on public.%I to authenticated', tb);
    end if;
  end loop;
end $$;

-- Doğrudan YAZILAN tablolar (app insert/update noktaları):
grant insert on public.visits to authenticated;
grant update, delete on public.visits to authenticated;
grant insert on public.chat_channels to authenticated;   -- HomeConnections kanal açar
grant insert on public.messages to authenticated;        -- sohbet mesajı
grant update on public.notifications to authenticated;   -- okundu işareti
grant update on public.profiles to authenticated;        -- profil düzenleme
grant insert on public.connection_requests to authenticated; -- bağlantı isteği

-- 🔴 BEKÇİ: bu listedeki her tabloda select grant'ı yoksa migration
-- DURUR — "politika var, grant yok" sınıfı bir daha sessiz kalamaz.
do $$
declare tb text; n int := 0;
begin
  foreach tb in array array[
    'profiles','users','connection_requests','sessions','chat_channels',
    'trust_scores','visits','requests','messages','notifications',
    'availabilities','credit_ledger'
  ] loop
    if not exists (
      select 1 from information_schema.role_table_grants
       where grantee='authenticated' and table_schema='public'
         and table_name=tb and privilege_type='SELECT') then
      raise notice '159 bekçi: % tablosunda authenticated SELECT yok', tb;
      n := n + 1;
    end if;
  end loop;
  if n > 0 then raise exception '159: % tabloda grant eksik kaldı', n; end if;
end $$;

-- ---- 2) BAĞLANTI YANIT ZAMANI (24 saat kuralının temeli) ----
alter table connection_requests add column if not exists responded_at timestamptz;
-- Backfill: eski accepted kayıtlarda kabul anı bilinmiyor — kuruluş
-- anını kullan (en kötü durumda erken düşer, asla yanlış uzun kalmaz).
update connection_requests set responded_at = created_at
 where responded_at is null and status <> 'pending';


-- ---- 3) respond_connection: responded_at doldurur ----
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

  -- v159: yanıt ZAMANI artık kayıtlı — ana sayfadaki 24 saat kuralı buna dayanır.
  update connection_requests
     set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status,
         responded_at = now()
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

-- ---- 4) home_connections(): ana sayfa bağlantı kartının TEK kaynağı ----
-- 🔴 Kural (Gökberk, madde 2): kabulden sonra 24 SAAT ana sayfada;
-- aktif sohbet varsa (son 24 saatte mesaj) sohbet sürdükçe kalır;
-- ikisi de yoksa düşer — Tanış > Bağlantılar'da her zaman durur.
-- RPC olması bilinçli: grant/RLS bağımsız tek çağrı + kural sunucuda
-- (istemcide saat hesabı = her istemcide ayrı davranış).
drop function if exists public.home_connections();
create or replace function public.home_connections()
returns table (conn_id uuid, peer_id uuid, peer_name text, peer_photo text,
               channel_id uuid, last_msg_at timestamptz)
language sql stable security definer set search_path = public as $$
  select cr.id, 
         case when cr.from_id = auth.uid() then cr.to_id else cr.from_id end,
         p.name, p.photo_url, ch.id,
         (select max(m.created_at) from messages m where m.channel_id = ch.id)
    from connection_requests cr
    left join chat_channels ch on ch.connection_id = cr.id
    left join profiles p
      on p.user_id = case when cr.from_id = auth.uid() then cr.to_id else cr.from_id end
   where cr.status = 'accepted'
     and (cr.from_id = auth.uid() or cr.to_id = auth.uid())
     and (
       coalesce(cr.responded_at, cr.created_at) > now() - interval '24 hours'
       or exists (select 1 from messages m
                   where m.channel_id = ch.id
                     and m.created_at > now() - interval '24 hours')
     )
   order by coalesce((select max(m.created_at) from messages m where m.channel_id = ch.id),
                     cr.responded_at, cr.created_at) desc
   limit 10
$$;
grant execute on function public.home_connections() to authenticated;

-- ---- 5) create_request_impl: SUNUCU TARAFI KARAR KAPISI ----
CREATE OR REPLACE FUNCTION public.create_request_impl(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if p_idem is not null then
    select id into v_req_id from requests where idempotency_key = p_idem;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;
  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  -- YENİ (033): aynı gün + örtüşen saatte kendi AKTİF host ilanın varsa başvuramazsın
  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  -- REQUEST KAPISI: trip zorunlu (rolden bağımsız — host da trip eklemeli)
  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  -- 🔴 v159 (cihazda görüldü): misafir kabul ETMEYEN ilana istek
  -- GÖNDERİLEBİLİYORDU — app rozeti "kabul etmiyor" derken sunucu kapıyı
  -- açık tutuyordu. Karar motoru tek gerçek: politika not_allowed veya
  -- kural engeli (charter vb.) varsa istek burada durur; kredi hiç
  -- düşmez, kullanıcı nedenini net görür.
  declare v_dec jsonb;
  begin
    v_dec := public.lounge_access_decision(p_avail_id, null);
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
  end;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'), left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $function$;

-- ---- DOĞRULAMA ----
do $$
declare r record; n int;
begin
  -- home_connections en az derlenebilir olmalı (çağrı auth'suz boş döner)
  select count(*) into n from public.home_connections();
  -- responded_at kolonu backfill edildi mi
  select count(*) into n from connection_requests where status='accepted' and responded_at is null;
  if n > 0 then raise exception '159: % accepted bağlantıda responded_at boş', n; end if;
end $$;

select '159 OK - grantlar + ana sayfa akislari + istek karar kapisi' as sonuc;
