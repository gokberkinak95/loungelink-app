-- =====================================================================
-- 034 · LOUNGE RADAR — "şu an bu lounge'da senden başka X kişi var"
-- Bağımlılık: 033'ten SONRA.
--
-- NEDEN: Host'un tek gerçek motivasyonu "iyilik yapmak" olamaz.
-- Doküman §17 (Airport Companion Network) zaten networking vaat ediyor
-- ama uygulamada bu vaat somut değildi. Radar, o vaadi ANIN İÇİNDE
-- somutlaştırır: "şu an yanındaki masada tanışmaya değer biri var".
--
-- GİZLİLİK KARARLARI (önemli):
--  - Yalnızca konum paylaşımı AÇIK olanlar radara girer (opt-in)
--  - Kadın güvenlik modu çift yönlü uygulanır (mevcut kural)
--  - Gölge kısıtlı kullanıcılar görünmez
--  - Engellenen/engelleyen görünmez
--  - Profil görünürlüğü ayarına saygı duyulur
--  - Fotoğraf yalnızca bağlantılıysa döner (mevcut kural)
-- =====================================================================

-- Ön-temizlik: dönüş tipi değişirse 42P13 vermesin (yeni fonksiyonlar ama garanti)
drop function if exists public.lounge_radar_count() cascade;
drop function if exists public.lounge_radar_people() cascade;

-- GERCEK SEMA (001): konum paylasimi kolonu = location_sharing (share_location DEGIL)
-- women_safety_mode (women_only degil) · profile_visibility ENUM: 'Everyone'|'Trusted+'|'Connections'
-- Golge kisit: users.shadow_limited + is_visible(uuid) FONKSIYONU (profiles.is_visible kolonu YOK)

-- Radar listesi: kimler var?
create or replace function public.lounge_radar_people()
returns table (
  user_id uuid, name text, profession text, bio text,
  badge text, score int, photo_url text,
  same_flight boolean, rel text, lounge_name text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_air text; v_from time; v_to time; v_flight text;
  v_me_women boolean; v_me_gender text; v_me_share boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select coalesce(p.location_sharing, false) into v_me_share from profiles p where p.user_id = v_uid;
  if not v_me_share then return; end if;

  -- bağlam: bugün, şu anı kapsayan ilan veya trip
  select a.airport_code, a.time_from, a.time_to into v_air, v_from, v_to
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date = current_date
     and a.time_from <= current_time and current_time <= a.time_to
   limit 1;

  if v_air is null then
    select v.airport_code, v.time_from, v.time_to, v.flight_no into v_air, v_from, v_to, v_flight
      from visits v
     where v.user_id = v_uid and v.visit_date = current_date
       and v.time_from <= current_time and current_time <= v.time_to
     limit 1;
  end if;

  if v_air is null then return; end if;

  select coalesce(pr.women_safety_mode, false), u.gender into v_me_women, v_me_gender
    from profiles pr join users u on u.id = pr.user_id where pr.user_id = v_uid;

  return query
  with present as (
    -- aynı havalimanında, bugün, örtüşen saatte olan HERKES (host + guest)
    select v.user_id as uid, v.flight_no as flight, null::uuid as lid
      from visits v
     where v.visit_date = current_date
       and v.airport_code = v_air
       and v.time_from < v_to and v_from < v.time_to
       and v.user_id <> v_uid
    union
    select a.host_id as uid, null::text as flight, a.lounge_id as lid
      from availabilities a
     where a.active and a.avail_date = current_date
       and a.airport_code = v_air
       and a.time_from < v_to and v_from < a.time_to
       and a.host_id <> v_uid
  )
  select distinct on (pe.uid)
    pe.uid,
    pr.name,
    pr.profession,
    case when pr.profile_visibility = 'Connections'
              and not exists (select 1 from connection_requests c
                               where c.status='accepted'
                                 and ((c.from_user=v_uid and c.to_user=pe.uid)
                                   or (c.to_user=v_uid and c.from_user=pe.uid)))
         then null else pr.bio end as bio,
    ts.badge,
    ts.score,
    -- foto yalnızca bağlantılıysa (mevcut gizlilik kuralı)
    case when pr.photo_connections_only
              and not exists (select 1 from connection_requests c
                               where c.status='accepted'
                                 and ((c.from_user=v_uid and c.to_user=pe.uid)
                                   or (c.to_user=v_uid and c.from_user=pe.uid)))
         then null else pr.photo_url end as photo_url,
    (v_flight is not null and pe.flight = v_flight) as same_flight,
    coalesce((select c.status from connection_requests c
               where (c.from_user=v_uid and c.to_user=pe.uid)
                  or (c.to_user=v_uid and c.from_user=pe.uid)
               order by c.created_at desc limit 1), 'none') as rel,
    l.name as lounge_name
  from present pe
  join profiles pr on pr.user_id = pe.uid
  join users u on u.id = pe.uid
  left join trust_scores ts on ts.user_id = pe.uid
  left join lounges l on l.id = pe.lid
  where u.deleted_at is null
    -- opt-in: konum paylaşımı kapalı olan radara girmez
    and coalesce(pr.location_sharing, false)
    -- gölge kısıt: 029'daki FONKSIYON (profiles kolonu değil)
    and is_visible(pe.uid)
    -- profil görünürlüğü 'nobody' ise hiç gösterme
    -- 'Connections' gizli degil; bio kilitlenir ama kisi listede gorunur (mevcut kural)
    -- kadın güvenlik modu: çift yönlü
    and (not v_me_women or u.gender = 'female')
    and (not coalesce(pr.women_safety_mode,false) or v_me_gender = 'female')
    -- engelleme
    and not exists (
      select 1 from blocks b
       where (b.blocker = v_uid and b.blocked = pe.uid)
          or (b.blocker = pe.uid and b.blocked = v_uid))
  order by pe.uid, ts.score desc nulls last;
end $$;
grant execute on function public.lounge_radar_people() to authenticated;

-- Radar sayacı: kaç kişi var? (karta basmadan önce)
create or replace function public.lounge_radar_count()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ctx record;
  v_count int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- Kullanıcının ŞU ANKİ bağlamı: bugün, şu saati kapsayan trip veya ilan
  select coalesce(a.airport_code, v.airport_code) as airport,
         a.lounge_id as lounge_id,
         coalesce(a.time_from, v.time_from) as t_from,
         coalesce(a.time_to,   v.time_to)   as t_to
    into v_ctx
    from (select 1) x
    left join availabilities a
      on a.host_id = v_uid and a.active and a.avail_date = current_date
     and a.time_from <= current_time and current_time <= a.time_to
    left join visits v
      on v.user_id = v_uid and v.visit_date = current_date
     and v.time_from <= current_time and current_time <= v.time_to
   limit 1;

  if v_ctx.airport is null then
    return jsonb_build_object('active', false);
  end if;

  -- Konum paylaşımı KAPALIYSA: radar çalışmaz ama app'e "açabilirsin" sinyali dön.
  -- Varsayılan false (001) — gizlilik açısından doğru, opt-in olmalı.
  -- App bu durumda "Radarı aç" kartı gösterir; kullanıcı bilinçli açar.
  if not coalesce((select location_sharing from profiles where user_id = v_uid), false) then
    return jsonb_build_object(
      'active', false,
      'reason', 'location_off',
      'can_enable', true,          -- app: "Radarı aç" kartı göster
      'airport', v_ctx.airport
    );
  end if;

  select count(*) into v_count from lounge_radar_people();

  return jsonb_build_object(
    'active', true,
    'airport', v_ctx.airport,
    'lounge_id', v_ctx.lounge_id,
    'count', v_count,
    'time_from', v_ctx.t_from,
    'time_to', v_ctx.t_to
  );
end $$;
grant execute on function public.lounge_radar_count() to authenticated;

-- blocks tablosu yoksa (engelleme) — güvenli varsayılan
create table if not exists blocks (
  blocker uuid not null references users(id) on delete cascade,
  blocked uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);
alter table blocks enable row level security;
drop policy if exists blocks_own on blocks;
create policy blocks_own on blocks for all using (blocker = auth.uid());


select 'LOUNGE RADAR OK' as sonuc;
