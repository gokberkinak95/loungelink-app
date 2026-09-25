-- ============================================================================
-- LoungeLink · 218_radar_olu_kolonlar.sql          (18 Agustos 2026)
--
-- 🔴 `lounge_radar_people()` 034'TEN BERI ÖLÜ. BUGÜN ÖLÇTÜM.
--
-- Fonksiyon çağrıldığında şunu veriyor:
--     ERROR 42703: column v.flight_no does not exist
-- Çünkü `visits` tablosundaki kolonun adı `flight_number`. Aynı gövdede
-- ikinci bir sınıf daha var: `connection_requests.from_user / to_user`
-- diye yazıyor, tablonun kolonları ise `from_id / to_id`.
--
-- NEDEN BUGÜNE KADAR GÖRÜLMEDİ — ve bu kısmı önemli buluyorum:
-- PL/pgSQL gövdeyi TANIMLARKEN doğrulamaz; kolon adları ancak sorgu
-- PLANLANDIĞINDA çözülür. Fonksiyonun başında ise şu var:
--     if v_air is null then return; end if;
-- Yani "bugün, şu saati kapsayan bir ilanın ya da seyahatin yok" ise
-- fonksiyon hatalı sorguya HİÇ ULAŞMADAN sessizce boş dönüyor. Test
-- verisinde o koşul hiç oluşmadığı için altı tur boyunca yeşil yandı.
-- `lounge_radar_count()` de bu fonksiyonu çağırdığı için o da ölüydü.
--
-- Bulunma biçimi: canlı çağrı geçişine "bugün tarihli ilan + konum
-- paylaşımı açık" durumu eklendim; fonksiyon ilk kez gerçekten çalıştı
-- ve ilk satırda patladı. Yani kusuru bulan şey daha iyi bir okuma
-- değil, fonksiyonun ÇALIŞABİLDİĞİ bir durum üretmekti.
--
-- ÜÇÜNCÜ KUSUR — ve bunu bu dosyanın KENDİ nöbetçisi buldu:
--     ERROR 22P02: invalid input value for enum connection_status: "none"
-- Gövdede `coalesce(c.status, 'none')` yazıyor; `status` bir enum ve
-- 'none' o enumun değeri değil. Yani ilk iki kolonu düzelttikten SONRA
-- fonksiyon hâlâ patlıyordu. `c.status::text` yapıldı.
--
-- Üç kusurun üçü de aynı sebeple saklanmıştı: fonksiyon hiç
-- çalıştırılmamıştı. Nöbetçi "çağır ve say" demek yerine "çağrılabilir
-- durumu KUR, sonra çağır" dediği anda üçü de arka arkaya çıktı.
--
-- Kullanıcıya etkisi: konum paylaşımı açık olan ve o gün aktif ilanı
-- olan biri Radar ekranını açtığında kırmızı hata görüyordu.
-- ============================================================================

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
    select v.airport_code, v.time_from, v.time_to, v.flight_number into v_air, v_from, v_to, v_flight
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
    select v.user_id as uid, v.flight_number as flight, null::uuid as lid
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
                                 and ((c.from_id=v_uid and c.to_id=pe.uid)
                                   or (c.to_id=v_uid and c.from_id=pe.uid)))
         then null else pr.bio end as bio,
    ts.badge,
    ts.score,
    -- foto yalnızca bağlantılıysa (mevcut gizlilik kuralı)
    case when pr.photo_connections_only
              and not exists (select 1 from connection_requests c
                               where c.status='accepted'
                                 and ((c.from_id=v_uid and c.to_id=pe.uid)
                                   or (c.to_id=v_uid and c.from_id=pe.uid)))
         then null else pr.photo_url end as photo_url,
    (v_flight is not null and pe.flight = v_flight) as same_flight,
    coalesce((select c.status::text from connection_requests c
               where (c.from_id=v_uid and c.to_id=pe.uid)
                  or (c.to_id=v_uid and c.from_id=pe.uid)
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

-- ── NÖBETÇİ: fonksiyon GERÇEKTEN ÇALIŞABİLİR DURUMDA mı ──────────────
-- 🔴 `select count(*) from lounge_radar_people()` YETMEZ — erken çıkış
-- yüzünden bozukken de 0 döner ve yeşil yanar. Bu tam olarak kusuru
-- altı tur saklayan desendir. O yüzden nöbetçi, hatalı sorgunun
-- ULAŞILDIĞI durumu KURAR, fonksiyonu çağırır, sonra geri alır.
do $nobetci$
declare
  v_uid uuid; v_av uuid; v_n int;
begin
  select a.host_id into v_uid from availabilities a where a.active limit 1;
  if v_uid is null then
    raise notice '218: ilan yok — nobetci calistirilamadi (KAPSAM YOK)';
    return;
  end if;

  -- Durumu kur: konum paylasimi acik + BUGUN, SU ANI kapsayan ilan
  create temp table _218_geri as
    select v_uid as uid,
           (select coalesce(location_sharing,false) from profiles where user_id = v_uid) as eski;
  update profiles set location_sharing = true where user_id = v_uid;

  insert into availabilities (host_id, airport_code, lounge_id, lounge_name,
                              avail_date, time_from, time_to, slots, filled,
                              active, min_trust)
  select a.host_id, a.airport_code, a.lounge_id, a.lounge_name,
         current_date, '00:00'::time, '23:59'::time, 1, 0, true, 0
    from availabilities a where a.host_id = v_uid limit 1
  returning id into v_av;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- ISTE ASIL SINAV: bu cagri 42703 verirse migration DURUR.
  select count(*) into v_n from public.lounge_radar_people();
  raise notice '218: radar gercekten calisti (% satir) ✓', v_n;

  -- Geri al
  delete from availabilities where id = v_av;
  update profiles set location_sharing = (select eski from _218_geri)
   where user_id = v_uid;
  drop table _218_geri;
  perform set_config('request.jwt.claims', '', true);
end
$nobetci$;
