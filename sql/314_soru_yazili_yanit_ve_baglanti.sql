-- ============================================================================
-- 314 · SORU: YAZILI YANIT + BAĞLANTI İSTEĞİ (Gökberk, 2 Ekim akşam) — tekrar koşulabilir
--
-- Gökberk: "Not girersem nasıl göndereceğim? Evet/hayır yerine Gönder olmalı; yazıp göndersin,
-- chat'e yansısın. Soru gönderirken bağlantı daveti de gönderiyorduk — bu akış bozulmasın.
-- Cevaptan sonra bağlantı kabul edilirse chat'e oradan devam edilir. Zaten bağlantımsa tekrar
-- bağlantı isteği gitmemeli, soru o kişiyle olan chat'e düşmeli."
--
-- KURGU (313'ün Evet/Hayır'ının yerine):
--   · Soru = ilan bağlamlı soru + BAĞLANTI İSTEĞİ (connection_requests, intent='kural_sorusu').
--   · Host YAZILI yanıt verir (soruya_cevap_yaz) → soran kişiye bildirim + Sorduklarım'da görünür.
--     Bağlantı kararı AYRI: host "Kabul et" derse sohbet açılır ve soru + yanıt sohbetin ilk iki
--     mesajı olur; yazışma oradan sürer. Kabul etmezse yanıt yine gider, sohbet/bağlantı açılmaz.
--   · Zaten bağlantılılarsa: yeni istek YOK — soru doğrudan aradaki sohbete mesaj olarak düşer.
--   · Sorular Davet ekranında değil, Soru ekranında (313'ten kalan karar korunuyor).
-- ============================================================================

-- ── 0) 313'ün Evet/Hayır yanıtları: yazılı yanıta çevir, bağlantı kararı AÇIK kalsın ──
update connection_requests
   set cevap_notu = coalesce(nullif(btrim(cevap_notu), ''),
                             case when cevap = 'evet' then 'Evet, misafir alabiliyorum.'
                                  else 'Bu ilanda misafir alamıyorum.' end),
       status = 'pending', cevap = null
 where intent = 'kural_sorusu' and cevap is not null and status = 'declined';

-- ── 1) HOST'UN YAZILI YANITI ─────────────────────────────────────────────────
create or replace function public.soruya_cevap_yaz(p_id uuid, p_metin text)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_metin text; v_ch uuid; v_ad text; v_salon text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if coalesce(v_cr.intent,'') <> 'kural_sorusu' then raise exception 'not_a_question'; end if;
  if v_cr.cevap_at is not null then raise exception 'already_answered'; end if;
  if public.is_blocked_pair(v_cr.from_id, v_cr.to_id) then raise exception 'blocked_pair'; end if;
  v_metin := left(btrim(coalesce(p_metin, '')), 500);
  if char_length(v_metin) < 2 then raise exception 'answer_empty'; end if;

  update connection_requests set cevap_notu = v_metin, cevap_at = now(), cevap = null where id = p_id;

  -- Bağlantı zaten kabul edildiyse yanıt sohbete de düşer.
  if v_cr.status = 'accepted' then
    select id into v_ch from chat_channels where connection_id = p_id;
    if v_ch is null then
      insert into chat_channels (connection_id, kind, created_at) values (p_id, 'companion', now()) returning id into v_ch;
    end if;
    insert into messages (channel_id, from_id, body) values (v_ch, v_uid, v_metin);
  end if;

  v_ad := public.kisa_ad(v_uid);
  v_salon := coalesce(public.salon_etiketi(v_cr.avail_id), 'İlan');
  perform public.bildir(v_cr.from_id, 'requests',
    v_ad || ' sorunu yanıtladı',
    v_salon || ' — “' || left(v_metin, 90) || case when char_length(v_metin) > 90 then '…' else '' end || '”',
    v_ad || ' answered your question',
    v_salon || ' — “' || left(v_metin, 90) || case when char_length(v_metin) > 90 then '…' else '' end || '”',
    'question', p_id);
  return jsonb_build_object('ok', true, 'channel_id', v_ch, 'baglanti', v_cr.status::text);
end $function$;
revoke all on function public.soruya_cevap_yaz(uuid, text) from public, anon;
grant execute on function public.soruya_cevap_yaz(uuid, text) to authenticated, service_role;

-- 313 API'si (yayınlanmadı ama SQL'i koşulmuş olabilir): aynı yola.
create or replace function public.soruyu_yanitla(p_id uuid, p_cevap text, p_not text default null)
returns jsonb language plpgsql security definer set search_path = public as $function$
begin
  return public.soruya_cevap_yaz(p_id, coalesce(nullif(btrim(coalesce(p_not,'')), ''),
    case when p_cevap = 'evet' then 'Evet, misafir alabiliyorum.' else 'Bu ilanda misafir alamıyorum.' end));
end $function$;

-- ── 2) BAĞLANTI KABULÜ: soru da artık bir bağlantı isteği; kabulde sohbet SORU + YANIT ile başlar ──
create or replace function public.respond_connection(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_chan uuid; v_ad text; v_soru boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_cr.status <> 'pending' then raise exception 'already_responded'; end if;
  v_soru := coalesce(v_cr.intent,'') = 'kural_sorusu';

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

    if v_chan is not null and not exists (select 1 from messages m where m.channel_id = v_chan) then
      if coalesce(nullif(trim(v_cr.intro),''),'') <> '' then
        insert into messages (channel_id, from_id, body, created_at)
        values (v_chan, v_cr.from_id, trim(v_cr.intro), coalesce(v_cr.created_at, now()));
      end if;
      -- 314: soruya yazılmış yanıt sohbetin ikinci mesajı
      if v_soru and coalesce(nullif(trim(v_cr.cevap_notu),''),'') <> '' then
        insert into messages (channel_id, from_id, body, created_at)
        values (v_chan, v_cr.to_id, trim(v_cr.cevap_notu), coalesce(v_cr.cevap_at, now()));
      end if;
    end if;

    perform public.bildir(v_cr.from_id, 'connections',
      v_ad || ' bağlantını kabul etti ✓',
      case when v_soru then 'Sorun ve yanıtı sohbette — yazışmaya oradan devam edebilirsin.'
           else 'Sohbet açıldı — Oturumlar ve sohbetler › Bağlantılar.' end,
      v_ad || ' accepted your connection ✓',
      case when v_soru then 'Your question and the answer are in the chat — continue from there.'
           else 'The chat is open — Sessions and chats › Connections.' end,
      'connection', p_id);
  else
    perform public.bildir(v_cr.from_id, 'connections',
      'Bağlantı isteğin yanıtlandı', v_ad || ' şu an bağlantı kurmuyor.',
      'Your connection request was answered', v_ad || ' isn''t connecting right now.',
      'connection', p_id);
  end if;

  return jsonb_build_object('ok', true, 'channel_id', v_chan);
end $function$;

-- ── 3) SORU SORARKEN: zaten bağlantılıysa yeni istek YOK, soru sohbete düşer ──
create or replace function public._314_yama(p_fn regprocedure, p_desen text, p_yeni text, p_isaret text)
returns text language plpgsql security definer set search_path = public as $y$
declare g text; y text;
begin
  g := pg_get_functiondef(p_fn);
  if position(p_isaret in g) > 0 then return 'zaten'; end if;
  y := regexp_replace(g, p_desen, p_yeni);
  if y = g then raise exception '314: % icinde beklenen desen yok', p_fn; end if;
  execute y;
  return 'yamalandi';
end $y$;
revoke all on function public._314_yama(regprocedure, text, text, text) from public, anon, authenticated;

do $d$
declare s text;
begin
  s := public._314_yama('public.ilan_kurali_sor(uuid)'::regprocedure,
    'select \* into v_mevcut from connection_requests\s*where \(from_id = v_uid and to_id = v_av\.host_id\)\s*or \(from_id = v_av\.host_id and to_id = v_uid\)\s*order by created_at desc limit 1;\s*if found then\s*return jsonb_build_object\(\s*''ok'', true,\s*''durum'', case when v_mevcut\.status::text = ''accepted'' then ''baglanti_var'' else ''zaten_soruldu'' end,\s*''baglanti_id'', v_mevcut\.id,\s*''salon'', v_salon\);\s*end if;',
    $r$-- 314_sohbete: önce KABUL EDİLMİŞ bağlantı aranır
  select * into v_mevcut from connection_requests
   where (from_id = v_uid and to_id = v_av.host_id)
      or (from_id = v_av.host_id and to_id = v_uid)
   order by (status = 'accepted') desc, created_at desc limit 1;

  if found and v_mevcut.status::text = 'accepted' then
    -- Zaten bağlantılılar: yeni istek YOK, soru aradaki sohbete mesaj olarak düşer.
    if public.is_blocked_pair(v_uid, v_av.host_id) then raise exception 'blocked_pair'; end if;
    select id into v_id from chat_channels where connection_id = v_mevcut.id;
    if v_id is null then
      insert into chat_channels (connection_id, kind, created_at)
      values (v_mevcut.id, 'companion', now()) returning id into v_id;
    end if;
    insert into messages (channel_id, from_id, body)
    values (v_id, v_uid, left(coalesce(
      replace((select value #>> '{}' from beta_settings where key = 'soru_intro_tr'), '{salon}', v_salon),
      '“' || v_salon || '” ilanında misafir hakkın var mı?'), 400));
    return jsonb_build_object('ok', true, 'durum', 'sohbete_eklendi', 'channel_id', v_id,
                              'baglanti_id', v_mevcut.id, 'salon', v_salon);
  elsif found then
    return jsonb_build_object(
      'ok', true,
      'durum', case when coalesce(v_mevcut.intent,'') = 'kural_sorusu' then 'zaten_soruldu' else 'baglanti_bekliyor' end,
      'baglanti_id', v_mevcut.id,
      'salon', v_salon);
  end if;$r$,
    '314_sohbete');
  raise notice '314 ilan_kurali_sor: %', s;
end $d$;
drop function if exists public._314_yama(regprocedure, text, text, text);

-- ── 4) LİSTELER: yanıt = cevap_at; bağlantı durumu ayrı; host için sohbet kimliği ──
-- 42P13 koruması: dönüş tipi 313 ile aynı, ama denetim önceki sürümlere göre bakıyor → drop + create
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
           when cr.cevap_at is not null then 'yanitlandi'
           when cr.status::text = 'accepted' then 'yanitlandi'
           when cr.status::text = 'declined' then 'reddedildi'
           when cr.avail_id is not null
                and public.kural_sorusu_durumu(cr.avail_id) = 'gerek_yok' then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         cr.created_at, coalesce(cr.cevap_at, cr.responded_at),
         case when cr.avail_id is null then false
              else public.kural_sorusu_durumu(cr.avail_id) = 'gerek_yok' end,
         case when cr.status = 'accepted' then ch.id end,
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

drop function if exists public.bana_gelen_sorular();
create function public.bana_gelen_sorular()
returns table(id uuid, soran_id uuid, soran_adi text, soran_foto text, soran_meslek text,
              avail_id uuid, salon text, airport_code text, avail_date date, time_from time, time_to time,
              soru text, durum text, cevap text, cevap_notu text, soruldu_at timestamptz, cevap_at timestamptz,
              ilan_acik boolean, channel_id uuid)
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
         cr.status::text, cr.cevap, cr.cevap_notu, cr.created_at, cr.cevap_at,
         case when cr.avail_id is null then false
              else coalesce((public.lounge_access_decision(cr.avail_id, null) ->> 'guest_policy'), '') <> 'not_allowed' end,
         case when cr.status = 'accepted' then ch.id end
    from connection_requests cr
    left join profiles p on p.user_id = cr.from_id
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where cr.to_id = v_uid
     and cr.intent = 'kural_sorusu'
     and not public.is_blocked_pair(v_uid, cr.from_id)
     and (cr.cevap_at is null or cr.status = 'pending' or cr.created_at > now() - interval '60 days')
   order by coalesce(cr.cevap_at is null and cr.status <> 'declined', false) desc, cr.created_at desc
   limit 50;
end $function$;
revoke all on function public.bana_gelen_sorular() from public, anon;
grant execute on function public.bana_gelen_sorular() to authenticated, service_role;

-- ── 5) ANA SAYFA: SORU = yanıt bekleyen (bana gelen + benim sorduğum) ──
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
           or exists (select 1 from messages m
                        join chat_channels c on c.id = m.channel_id
                        left join requests r on r.id = c.request_id
                        left join connection_requests cr on cr.id = c.connection_id
                       where m.from_id <> v_uid and m.read_at is null and m.created_at > g_sohbet
                         and ((r.id is not null and v_uid in (r.host_id, r.guest_id) and r.status in ('accepted','completed'))
                           or (cr.id is not null and v_uid in (cr.from_id, cr.to_id) and cr.status = 'accepted')));

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0), 'istek', coalesce(v_istek, 0), 'davet', coalesce(v_davet, 0),
    'soru', coalesce(v_soru, 0), 'baglanti', coalesce(v_baglanti, 0), 'ilan', coalesce(v_ilan, 0),
    'yeni', jsonb_build_object('sohbet', y_sohbet, 'istek', y_istek, 'davet', y_davet, 'soru', y_soru));
end $function$;

-- ── 6) BİLDİRİME DOKUNUŞ: kabul edilmiş soru-bağlantısı → sohbet (Bağlantılar) ──
do $$
declare g text; y text;
begin
  g := pg_get_functiondef('public.bildirim_hedefi(uuid)'::regprocedure);
  if position('314_hedef' in g) > 0 then raise notice '314 bildirim_hedefi: zaten'; return; end if;
  y := replace(g,
    $a$    if v_cr.id is not null and coalesce(v_cr.intent,'') = 'kural_sorusu' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'accepted' then$a$,
    $b$    if v_cr.id is not null and v_cr.status = 'accepted' then  -- 314_hedef: kabul edilen soru da bir bağlantı
      return jsonb_build_object('ekran', 'akis', 'alt', 'baglanti', 'ref', n.ref_id);
    elsif v_cr.id is not null and coalesce(v_cr.intent,'') = 'kural_sorusu' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'accepted' then$b$);
  if y = g then raise exception '314: bildirim_hedefi deseni bulunamadi'; end if;
  execute y;
  raise notice '314 bildirim_hedefi: yamalandi';
end $$;

insert into rpc_client_surface (fn_name, client, note) values
  ('soruya_cevap_yaz', 'app', 'Soru › Gelen: host yazılı yanıt (314); bağlantı kararı ayrı')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

do $$
begin
  if position('314_sohbete' in pg_get_functiondef('public.ilan_kurali_sor(uuid)'::regprocedure)) = 0 then
    raise exception '314: ilan_kurali_sor yamalanmamis';
  end if;
  raise notice '314: tamam — yazili yanit · baglanti istegi korunuyor · bagliysa soru sohbete';
end $$;
