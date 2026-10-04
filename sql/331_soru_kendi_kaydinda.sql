-- ============================================================================
-- 331 · SORU KENDİ KAYDINDA: bekleyen bağlantıda da · bağlıyken de · başka ilan için de
--       (5 Ekim 2026 · Gökberk md.4 · md.5)
--
-- ÖLÇÜM: soru bir BAĞLANTI İSTEĞİ satırıydı (connection_requests.intent='kural_sorusu') ve
-- iki kişi arasında yalnız BİR bağlantı satırı olabiliyor (unique from_id,to_id). Sonuç:
--   · aralarında BEKLEYEN bir bağlantı isteği varsa soru HİÇ gitmiyordu
--     ("kabul edilince sohbetten sorabilirsin")
--   · aynı host'a daha önce (BAŞKA bir ilan için bile) soru sorulduysa yeni soru gitmiyordu
--     ("zaten soruldu") → "sorduğum soru Gönderdiğim'e yansımadı"
--   · bağlıyken soru yalnız sohbete düşüyor, Gönderdiğim/Gelen listelerinde görünmüyordu
-- KARAR (Gökberk): ilk temas → bağlantı isteği + soru; bekleyen istek varsa → yalnız soru;
-- zaten bağlıysa → yalnız soru (yeni istek yok). Soru her durumda iki listede de görünür.
-- DÜZELTME: her soru `kural_sorulari`nda kendi satırı. Eski sorular AYNI kimlikle taşınır
-- (bildirim bağlantıları bozulmaz). İlk temasta soru kimliği = bağlantı isteği kimliği
-- (kabulde sohbet soru + yanıtla açılır — 314 davranışı korunur).
-- Liste/yanıt/sayaç fonksiyonları yeni tablodan okur; DÖNÜŞ ALANLARI AYNI (uygulama değişmez).
-- Tekrar koşulabilir.
-- ============================================================================

create table if not exists public.kural_sorulari (
  id          uuid primary key default gen_random_uuid(),
  soran_id    uuid not null references public.users(id) on delete cascade,
  host_id     uuid not null references public.users(id) on delete cascade,
  avail_id    uuid references public.availabilities(id) on delete set null,
  baglanti_id uuid references public.connection_requests(id) on delete set null,
  soru        text,
  cevap       text,
  cevap_notu  text,
  cevap_at    timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists ix_kural_sorulari_soran on public.kural_sorulari (soran_id, created_at desc);
create index if not exists ix_kural_sorulari_host on public.kural_sorulari (host_id, created_at desc);
create index if not exists ix_kural_sorulari_ilan on public.kural_sorulari (avail_id, soran_id);
alter table public.kural_sorulari enable row level security;          -- politika yok: yalnız fonksiyonlar
revoke all on public.kural_sorulari from public, anon, authenticated;

-- Eski sorular (bağlantı satırındakiler) AYNI kimlikle taşınır
insert into public.kural_sorulari (id, soran_id, host_id, avail_id, baglanti_id, soru, cevap, cevap_notu, cevap_at, created_at)
select cr.id, cr.from_id, cr.to_id, cr.avail_id, cr.id, nullif(btrim(coalesce(cr.intro, '')), ''),
       cr.cevap, cr.cevap_notu, cr.cevap_at, cr.created_at
  from public.connection_requests cr
 where cr.intent = 'kural_sorusu'
on conflict (id) do nothing;

-- ── soru metni (tek yerde) ───────────────────────────────────────────────────
create or replace function public.kural_sorusu_metni(p_salon text)
 returns text language sql stable security definer set search_path to 'public' as $f$
  select left(coalesce(
           replace((select value #>> '{}' from beta_settings where key = 'soru_intro_tr'), '{salon}', coalesce(p_salon, 'bu')),
           '“' || coalesce(p_salon, 'bu') || '” ilanında misafir hakkın var mı?'), 400);
$f$;
revoke execute on function public.kural_sorusu_metni(text) from public, anon, authenticated;

-- ── soru sor ────────────────────────────────────────────────────────────────
create or replace function public.ilan_kurali_sor(p_avail_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_av availabilities%rowtype;
  v_salon text; v_konu text; v_soru text; v_ad text;
  v_ok boolean; v_id uuid; v_q uuid; v_ch uuid; v_mevcut connection_requests%rowtype;
  v_hak jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_av from availabilities where id = p_avail_id;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_connect_blocked'; end if;

  if public.kural_sorusu_durumu(p_avail_id) <> 'uygun' then  -- 313_sebep
    raise exception '%', 'rule_ask_' || public.kural_sorusu_durumu(p_avail_id);
  end if;
  if public.is_blocked_pair(v_uid, v_av.host_id) then raise exception 'blocked_pair'; end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  -- 331 · AYNI İLAN için yanıt bekleyen sorun varsa ikinci soru açılmaz (başka ilan için açılır)
  select q.id into v_q from kural_sorulari q
    left join connection_requests c on c.id = q.baglanti_id
   where q.soran_id = v_uid and q.avail_id = p_avail_id and q.cevap_at is null
     and not coalesce(c.id = q.id and c.status::text in ('accepted', 'declined'), false)
   order by q.created_at desc limit 1;
  if v_q is not null then
    return jsonb_build_object('ok', true, 'durum', 'zaten_soruldu', 'soru_id', v_q,
                              'salon', coalesce(v_av.lounge_name, v_av.airport_code));
  end if;

  v_hak := public.kural_sorusu_hakkim();
  if coalesce((v_hak ->> 'asildi')::boolean, false) then
    raise exception 'rule_ask_daily_limit'
      using detail = format('%s/%s soru kullanildi', v_hak ->> 'kullanilan', v_hak ->> 'tavan'),
            hint   = 'yenilenme=' || (v_hak ->> 'yenilenme');
  end if;

  v_salon := coalesce(v_av.lounge_name, v_av.airport_code);
  v_soru  := public.kural_sorusu_metni(v_salon);
  v_ad    := public.kisa_ad(v_uid);

  select * into v_mevcut from connection_requests
   where (from_id = v_uid and to_id = v_av.host_id)
      or (from_id = v_av.host_id and to_id = v_uid)
   order by (status = 'accepted') desc, (status = 'pending') desc, created_at desc limit 1;

  if found then
    -- 331 · aralarında bağlantı ya da bağlantı isteği VAR: yeni istek yok, YALNIZ SORU
    insert into kural_sorulari (soran_id, host_id, avail_id, baglanti_id, soru)
    values (v_uid, v_av.host_id, p_avail_id, v_mevcut.id, v_soru) returning id into v_q;

    if v_mevcut.status::text = 'accepted' then
      select id into v_ch from chat_channels where connection_id = v_mevcut.id;
      if v_ch is null then
        insert into chat_channels (connection_id, kind, created_at)
        values (v_mevcut.id, 'companion', now()) returning id into v_ch;
      end if;
      insert into messages (channel_id, from_id, body) values (v_ch, v_uid, v_soru);
    end if;

    perform public.bildir(v_av.host_id, 'connections',
      v_ad || ' misafir hakkını soruyor ◈',
      '“' || v_salon || '” ilanında misafir götürüp götüremediğini soruyor. Sorular › Gelen''den yanıtlayabilirsin.',
      v_ad || ' is asking about your guest right ◈',
      'They''re asking whether you can bring a guest on your “' || v_salon || '” listing. Answer from Questions › Incoming.',
      'question', v_q);
    perform public.bildir(v_uid, 'connections',
      'Soru iletildi ✦',
      public.kisa_ad(v_av.host_id) || ' kişisine “' || v_salon || '” ilanı için misafir hakkını sorduk. Yanıtını Sorular › Gönderdiğim''de göreceksin.',
      'Question sent ✦',
      'We asked ' || public.kisa_ad(v_av.host_id) || ' about the guest right on “' || v_salon || '”. You''ll see the answer under Questions › Sent.',
      'question', v_q);

    return jsonb_build_object('ok', true,
      'durum', case when v_mevcut.status::text = 'accepted' then 'sohbete_eklendi' else 'soruldu' end,
      'soru_id', v_q, 'baglanti_id', v_mevcut.id, 'channel_id', v_ch, 'salon', v_salon,
      'kalan_hak', (public.kural_sorusu_hakkim() ->> 'kalan')::int);
  end if;

  -- İLK TEMAS: bağlantı isteği + soru (soru kimliği = istek kimliği; tetikleyiciler bildirimleri yazar)
  insert into connection_requests (from_id, to_id, intent, intro, status, avail_id)
  values (v_uid, v_av.host_id, 'kural_sorusu', v_soru, 'pending', p_avail_id)
  returning id into v_id;

  insert into kural_sorulari (id, soran_id, host_id, avail_id, baglanti_id, soru)
  select v_id, v_uid, v_av.host_id, p_avail_id, v_id, coalesce(nullif(btrim(cr.intro), ''), v_soru)
    from connection_requests cr where cr.id = v_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'connections',
          'Misafir hakkın soruluyor ◈',
          'Bir yolcu “' || v_salon || '” ilanında misafir götürüp götüremediğini '
          || 'soruyor. Elimizdeki bilgi “hayır” diyor ama doğrulayamadık. '
          || 'Kart hakkını Profil → Lounge hakkı kaynağı ekranından '
          || 'güncellersen ilanın başvuruya açılır.',
          'connection', v_id);

  v_konu := 'hosta_sorulan_misafir_hakki:' || coalesce(v_av.lounge_id::text, v_av.airport_code);
  insert into rule_source_conflicts (konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki)
  values (v_konu,
          'Misafir “' || v_salon || '” ilanında misafir hakkı olup olmadığını host''a sordu. '
          || 'Karar motoru not_allowed diyor ama kesinlik verified değil.',
          'LoungeLink karar motoru: misafir hakki yok (dogrulanmadi)',
          'Kullanici sorusu (' || to_char(now(),'YYYY-MM-DD') || ')',
          'kaynak_sessiz',
          'Kaynak taramasi bekliyor — bu salonun resmi misafir kurali bulunmali.',
          'veri_bekliyor',
          'Misafir basvuramiyor; host beyan etmezse ilan olu kaliyor.')
  on conflict (konu) do update set
    kaynak_b = 'Kullanici sorusu (son: ' || to_char(now(),'YYYY-MM-DD') || ')',
    updated_at = now();

  return jsonb_build_object('ok', true, 'durum', 'soruldu', 'soru_id', v_id,
                            'baglanti_id', v_id, 'salon', v_salon,
                            'kalan_hak', (public.kural_sorusu_hakkim() ->> 'kalan')::int);
end $function$;

-- ── günlük soru hakkı: yeni tablodan say ─────────────────────────────────────
create or replace function public.kural_sorusu_hakkim_ham()
 returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
declare v_uid uuid := auth.uid(); v_n int; v_tavan int := 5;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;
  select count(*) into v_n from kural_sorulari
   where soran_id = v_uid
     and created_at >= (date_trunc('day', timezone('Europe/Istanbul', now())) at time zone 'Europe/Istanbul');
  return public.gunluk_sinir_durumu(v_n, v_tavan) || jsonb_build_object('known', true);
end $function$;

-- ── Gönderdiğim sorular ─────────────────────────────────────────────────────
-- sqlcheck: allow-replace sorularim  (dönüş tipi 314 ile AYNI; yalnız yazım farkı)
create or replace function public.sorularim()
 returns table(id uuid, host_id uuid, host_name text, salon text, airport_code text, avail_id uuid, durum text,
               cevap_durumu text, soruldu_at timestamp with time zone, yanit_at timestamp with time zone,
               ilan_acildi boolean, channel_id uuid, soru text, avail_date date, time_from time without time zone,
               time_to time without time zone, cevap text, cevap_notu text)
 language plpgsql stable security definer set search_path to 'public' as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select q.id, q.host_id,
         public.kisa_ad(q.host_id),
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text,
         q.avail_id,
         coalesce(cr.status::text, 'pending'),
         case
           when q.cevap_at is not null then 'yanitlandi'
           when cr.id = q.id and cr.status::text = 'accepted' then 'yanitlandi'   -- 314: soruyla açılan bağlantı kabul edildi
           when cr.id = q.id and cr.status::text = 'declined' then 'reddedildi'
           when q.avail_id is not null and public.kural_sorusu_durumu(q.avail_id) = 'gerek_yok' then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         q.created_at,
         coalesce(q.cevap_at, case when cr.id = q.id then cr.responded_at end),
         case when q.avail_id is null then false else public.kural_sorusu_durumu(q.avail_id) = 'gerek_yok' end,
         case when cr.status = 'accepted' then ch.id end,
         q.soru,
         a.avail_date, a.time_from, a.time_to,
         q.cevap, q.cevap_notu
    from kural_sorulari q
    left join connection_requests cr on cr.id = q.baglanti_id
    left join availabilities a on a.id = q.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where q.soran_id = v_uid
   order by q.created_at desc
   limit 30;
end $function$;

-- ── Gelen sorular ────────────────────────────────────────────────────────────
-- sqlcheck: allow-replace bana_gelen_sorular  (dönüş tipi 314 ile AYNI; yalnız yazım farkı)
create or replace function public.bana_gelen_sorular()
 returns table(id uuid, soran_id uuid, soran_adi text, soran_foto text, soran_meslek text, avail_id uuid, salon text,
               airport_code text, avail_date date, time_from time without time zone, time_to time without time zone,
               soru text, durum text, cevap text, cevap_notu text, soruldu_at timestamp with time zone,
               cevap_at timestamp with time zone, ilan_acik boolean, channel_id uuid)
 language plpgsql stable security definer set search_path to 'public' as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select q.id, q.soran_id, public.kisa_ad(q.soran_id),
         case when p.photo_url is not null and not coalesce(p.photo_connections_only, false) then p.photo_url end,
         nullif(btrim(coalesce(p.profession,'')), ''),
         q.avail_id,
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text, a.avail_date, a.time_from, a.time_to,
         q.soru,
         coalesce(cr.status::text, 'pending'), q.cevap, q.cevap_notu, q.created_at, q.cevap_at,
         case when q.avail_id is null then false
              else coalesce((public.lounge_access_decision(q.avail_id, null) ->> 'guest_policy'), '') <> 'not_allowed' end,
         case when cr.status = 'accepted' then ch.id end
    from kural_sorulari q
    left join connection_requests cr on cr.id = q.baglanti_id
    left join profiles p on p.user_id = q.soran_id
    left join availabilities a on a.id = q.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where q.host_id = v_uid
     and not public.is_blocked_pair(v_uid, q.soran_id)
     and (q.cevap_at is null or q.created_at > now() - interval '60 days')
   order by coalesce(q.cevap_at is null and coalesce(cr.status::text, 'pending') <> 'declined', false) desc, q.created_at desc
   limit 50;
end $function$;

-- ── Yanıt yaz ────────────────────────────────────────────────────────────────
create or replace function public.soruya_cevap_yaz(p_id uuid, p_metin text)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_uid uuid := auth.uid(); v_q kural_sorulari%rowtype; v_cr connection_requests%rowtype;
        v_metin text; v_ch uuid; v_ad text; v_salon text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_q from kural_sorulari where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_q.host_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_q.cevap_at is not null then raise exception 'already_answered'; end if;
  if public.is_blocked_pair(v_q.soran_id, v_q.host_id) then raise exception 'blocked_pair'; end if;
  v_metin := left(btrim(coalesce(p_metin, '')), 500);
  if char_length(v_metin) < 2 then raise exception 'answer_empty'; end if;

  update kural_sorulari set cevap_notu = v_metin, cevap_at = now(), cevap = null where id = p_id;
  select * into v_cr from connection_requests where id = v_q.baglanti_id;
  -- 314 uyumu: soruyla açılan bağlantı satırı da yanıtı taşır (kabulde sohbet soru + yanıtla açılır)
  if found and v_cr.id = p_id then
    update connection_requests set cevap_notu = v_metin, cevap_at = now(), cevap = null where id = p_id;
  end if;

  if v_cr.id is not null and v_cr.status = 'accepted' then
    select id into v_ch from chat_channels where connection_id = v_cr.id;
    if v_ch is null then
      insert into chat_channels (connection_id, kind, created_at) values (v_cr.id, 'companion', now()) returning id into v_ch;
    end if;
    insert into messages (channel_id, from_id, body) values (v_ch, v_uid, v_metin);
  end if;

  v_ad := public.kisa_ad(v_uid);
  v_salon := coalesce(public.salon_etiketi(v_q.avail_id), 'İlan');
  perform public.bildir(v_q.soran_id, 'requests',
    v_ad || ' sorunu yanıtladı',
    v_salon || ' — “' || left(v_metin, 90) || case when char_length(v_metin) > 90 then '…' else '' end || '”',
    v_ad || ' answered your question',
    v_salon || ' — “' || left(v_metin, 90) || case when char_length(v_metin) > 90 then '…' else '' end || '”',
    'question', p_id);
  return jsonb_build_object('ok', true, 'channel_id', v_ch, 'baglanti', coalesce(v_cr.status::text, 'yok'));
end $function$;

-- ── host hakkını beyan edince soranlara haber (yeni tablodan) ────────────────
create or replace function public.trg_hak_beyani_soranlara()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare r record;
begin
  if coalesce(new.guest_capacity,0) <= 0 then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.guest_capacity,0) > 0 then return new; end if;
  for r in
    select distinct on (q.soran_id) q.id, q.soran_id
      from kural_sorulari q
     where q.host_id = new.user_id and q.cevap_at is null
     order by q.soran_id, q.created_at desc
  loop
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (r.soran_id, 'connections',
            'Sorduğun host hakkını güncelledi ✦',
            'Sorduğun ilanın host''u kart hakkını beyan etti. Keşfet''te o ilana '
         || 'yeniden bak — başvuruya açılmış olabilir.',
            'question', r.id);
  end loop;
  return new;
end $function$;

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

  -- 331 · sorular kendi tablosunda (bekleyen bağlantıda / bağlıyken sorulanlar da sayılır)
  select count(*)::int into v_soru
    from kural_sorulari q
    left join connection_requests cr on cr.id = q.baglanti_id
   where q.host_id = v_uid and q.cevap_at is null
     and not coalesce(cr.id = q.id and cr.status::text = 'declined', false)
     and not public.is_blocked_pair(v_uid, q.soran_id);
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
  y_soru := exists (select 1 from kural_sorulari q
                     left join connection_requests cr on cr.id = q.baglanti_id
                     where (q.host_id = v_uid and q.cevap_at is null and q.created_at > g_soru
                            and not coalesce(cr.id = q.id and cr.status::text = 'declined', false))
                        or (q.soran_id = v_uid and coalesce(q.cevap_at, case when cr.id = q.id then cr.responded_at end) > g_soru));
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

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'sorular kendi tablosunda' as kontrol,
       position('kural_sorulari' in pg_get_functiondef('public.ilan_kurali_sor(uuid)'::regprocedure)) > 0
   and position('kural_sorulari' in pg_get_functiondef('public.sorularim()'::regprocedure)) > 0
   and position('kural_sorulari' in pg_get_functiondef('public.bana_gelen_sorular()'::regprocedure)) > 0
   and position('kural_sorulari' in pg_get_functiondef('public.ana_sayfa_akisi()'::regprocedure)) > 0 as tamam
union all
select 'eski sorular tasindi',
       (select count(*) from connection_requests where intent = 'kural_sorusu')
       <= (select count(*) from kural_sorulari);
-- Beklenen: iki satır tamam = true.
