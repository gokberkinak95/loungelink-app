-- ============================================================================
-- 318 · ANA SAYFA AKIŞI: OKUNMAMIŞ MESAJ KONTROLÜ ÖLÇEKTE  (4 Ekim 2026)
--
-- ÖLÇÜM (ll_yuk · 300.047 mesaj · 50.076 üye): ana_sayfa_akisi() 340-420 ms,
-- bunun ~145 ms'si tek bir EXISTS: 'yeni sohbet' noktası için bütün okunmamış
-- mesajlar taranıyor, kullanıcının kanalı olup olmadığına SONRA bakılıyordu.
-- Mesaj sayısıyla doğrusal büyür; ana sayfa her açılışta bunu çağırıyor.
-- DÜZELTME: kullanıcının kanallarından başla (aynı koşullar). 358 kullanıcıda
-- eski/yeni sonuç karşılaştırıldı: 0 fark.
-- Gövde CANLI tanımın üstüne eklendi. Supabase SQL Editor: tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.ana_sayfa_akisi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
   where cr.to_id = v_uid and cr.intent = 'kural_sorusu' and cr.status <> 'declined' and cr.cevap_at is null
     and not public.is_blocked_pair(v_uid, cr.from_id);
  v_soru := v_soru + (select count(*)::int from public.sorularim() s where s.cevap_durumu = 'bekliyor');

  select count(*)::int into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date >= current_date;

  select count(*)::int into v_baglanti
    from connection_requests cr
   where cr.to_id = v_uid and cr.status = 'pending'
     and coalesce(cr.intent,'') <> 'kural_sorusu';

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
                       and ((cr.to_id = v_uid and cr.cevap_at is null and cr.status <> 'declined' and cr.created_at > g_soru)
                         or (cr.from_id = v_uid and coalesce(cr.cevap_at, cr.responded_at) > g_soru)));
  y_sohbet := exists (select 1 from requests r
                       where r.guest_id = v_uid and r.status = 'accepted' and r.responded_at > g_sohbet)
           or exists (select 1 from sessions s join requests r on r.id = s.request_id
                       where s.status in ('pending','active')
                         and ((r.host_id = v_uid and (s.guest_started_at > g_sohbet or s.started_at > g_sohbet))
                           or (r.guest_id = v_uid and (s.host_started_at > g_sohbet or s.started_at > g_sohbet))))
           -- 318 · Okunmamış mesaj: önce KULLANICININ kanalları (istek / bağlantı
           -- indeksleri), sonra o kanalların mesajları (idx_messages_channel).
           -- Eskisi bütün okunmamış mesajları tarayıp kanala sonradan bakıyordu:
           -- 300.000 mesajda 95-145 ms → 0,15 ms. 358 kullanıcıda sonuç birebir.
           or exists (select 1 from messages m
                       where m.channel_id in (
                               select c1.id from chat_channels c1 join requests r on r.id = c1.request_id
                                where (r.host_id = v_uid or r.guest_id = v_uid) and r.status in ('accepted','completed')
                               union all
                               select c2.id from chat_channels c2 join connection_requests cr on cr.id = c2.connection_id
                                where (cr.from_id = v_uid or cr.to_id = v_uid) and cr.status = 'accepted')
                         and m.from_id <> v_uid and m.read_at is null and m.created_at > g_sohbet);

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0), 'istek', coalesce(v_istek, 0), 'davet', coalesce(v_davet, 0),
    'soru', coalesce(v_soru, 0), 'baglanti', coalesce(v_baglanti, 0), 'ilan', coalesce(v_ilan, 0),
    'yeni', jsonb_build_object('sohbet', y_sohbet, 'istek', y_istek, 'davet', y_davet, 'soru', y_soru));
end $function$;

select 'ana_sayfa_akisi kanal-oncelikli' as kontrol,
       position('318 · Okunmamış mesaj' in pg_get_functiondef('public.ana_sayfa_akisi()'::regprocedure)) > 0 as tamam;
-- Beklenen: tamam = true.
