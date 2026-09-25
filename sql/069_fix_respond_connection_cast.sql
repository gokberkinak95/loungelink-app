-- ============================================================
-- LoungeLink · 069_fix_respond_connection_cast.sql
--
-- 🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu.
--
-- respond_connection sunu yapiyor:
--     set status = case when p_accept then 'accepted' else 'declined' end
-- Ama connection_requests.status bir ENUM (connection_status).
-- CASE ifadesinin sonucu `text` olarak turetiliyor ve Postgres bunu
-- otomatik cast ETMIYOR:
--     "column status is of type connection_status but expression is of type text"
--
-- SONUC: BAGLANTI ISTEGI HIC KABUL EDILEMIYOR (ne kabul ne red).
--
-- EK BULGU: ayni fonksiyon `responded_at = now()` yaziyordu ama
-- connection_requests tablosunda BOYLE BIR KOLON YOK
-- (kolonlar: id, from_id, to_id, intent, intro, status, created_at).
-- O yazma da kaldirildi.
--
-- EK BULGU 2: `on conflict (connection_id) do nothing` calismiyordu.
-- chat_channels'daki benzersiz indeks KISMI (partial):
--     unique (connection_id) WHERE connection_id IS NOT NULL
-- Postgres kismi indeksi ON CONFLICT'te ancak AYNI kosul yazilirsa kullanir.
-- Duzeltme: `on conflict (connection_id) where connection_id is not null`.
-- Aksi halde "there is no unique or exclusion constraint matching" hatasi.
-- Oturum sonrasi "Baglantida kal" akisi son adimda kiriliyordu.
--
-- NOT: Bu, ayni enum-cast ailesinin 4. uyesi (056 createAvailability,
-- 061 respond_request, 067 confirm_session, 069 respond_connection).
-- Ortak sebep: literal/CASE sonucu enum kolona yazilirken ::enum cast'i
-- unutuluyor. VALUES icinde Postgres otomatik cast eder, SELECT/CASE
-- icinde ETMEZ - fark burada.
-- ============================================================

CREATE OR REPLACE FUNCTION public.respond_connection(p_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
    -- §17: bağlantı kurulunca CompanionChat açılır
    insert into chat_channels (connection_id, kind, created_at)
    values (p_id, 'companion', now())
    on conflict (connection_id) where connection_id is not null do nothing
    returning id into v_chan;
    if v_chan is null then select id into v_chan from chat_channels where connection_id = p_id; end if;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı kabul edildi ✓',
            'Sohbet açıldı.', 'connection', p_id);
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_uid, 'connections', 'Bağlantı kuruldu ✓', 'Sohbet açıldı.', 'connection', p_id);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı isteği yanıtlandı', 'İstek reddedildi.', 'connection', p_id);
  end if;

  return jsonb_build_object('ok', true, 'accepted', p_accept, 'channel_id', v_chan);
end $function$;

grant execute on function public.respond_connection(uuid, boolean) to authenticated;

-- DOGRULAMA (true donmeli)
select (prosrc ilike '%::connection_status%') as "cast_eklendi"
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='respond_connection';

select '069 OK - respond_connection enum cast eklendi, baglanti kabul edilebiliyor' as sonuc;
