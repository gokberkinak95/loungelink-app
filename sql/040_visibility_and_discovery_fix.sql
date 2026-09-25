-- ============================================================
-- 040 — GÖRÜNÜRLÜK, UÇUŞ NUMARASI ve 030'DAKİ CANLI BUG
--
-- ÖNCE 040a_PRE_drop.sql ÇALIŞTIR.
--
-- Üç ayrı sorunu kapatıyor:
--
-- 1) create_availability GÖRÜNÜRLÜĞÜ ve UÇUŞU YAZMIYORDU
--    availabilities tablosunda 001'den beri `visibility` ve
--    `flight_number` kolonları VAR, ama 033'teki create_availability
--    insert'inde ikisi de yok. Yani host ne seçerse seçsin, ilan
--    her zaman visibility='Public' (kolon varsayılanı) ve
--    flight_number=null olarak kaydediliyordu.
--
-- 2) discover_availabilities GÖRÜNÜRLÜĞÜ HİÇ OKUMUYORDU
--    030'daki sorguda `visibility` kelimesi bir kez bile geçmiyor.
--    Yani (1) düzeltilip görünürlük yazılsa bile, keşif ekranı
--    onu umursamadan HER ilanı gösterecekti. İkisi birlikte
--    düzeltilmeli — yalnız biri anlamsız.
--
-- 3) 🔴 030'DA CANLI BİR KOLON HATASI VAR
--    Satır 198:  (p.linkedin is not null and p.linkedin <> '')
--    Gerçek kolon adı `linkedin_url`. `p.linkedin` diye bir kolon
--    yok (001: linkedin_url + linkedin_verified). Bu, keşif
--    sorgusunu 42703 ile düşürür → "açık slot yok".
--    Müsaitlik açtığın halde Keşfet'in boş görünmesinin
--    muhtemel sebebi budur.
--
-- MVP EŞLEMESİ (MVP v15 HostAvailability, satır 726-779):
--   MVP'nin üç seçeneği: all / trusted / hidden
--   Bizim enum'umuz:     Public / Connections / Hidden
--   Bunlar AYNI ŞEY DEĞİL — MVP'nin "trusted"ı bir GÜVEN EŞİĞİ,
--   enum'un "Connections"ı ise BAĞLANTI LİSTESİ. Enum'a yeni değer
--   eklemek yerine (Supabase editöründe alter type add value tek
--   transaction içinde riskli) `min_trust` kolonu ekliyoruz:
--
--     "Tüm doğrulanmış misafirler"  -> Public,  min_trust=0
--     "Yalnızca güvenilir misafirler"-> Public, min_trust=55
--     "Eşleşmedikçe gizli"          -> Hidden,  min_trust=0
--
--   Böylece enum'un 'Connections' değeri ileride (MVP'de olmayan
--   "yalnızca bağlantılarım" seçeneği için) el değmeden duruyor.
--
--   55 eşiği keyfi değil: recompute_badge'de 70 = "High Trust Guest",
--   discover'ın skorunda 55 ara kademe. 70 seçseydik bir host'un
--   ilanı neredeyse kimseye görünmezdi (yeni kullanıcı email+telefon
--   ile 20 puanda başlıyor; 55 için kimlik VEYA linkedin+profil
--   gerekiyor) — yani "güvenilir" demek ama ürünü kilitlememek.
-- ============================================================

-- ---- 1. min_trust kolonu (idempotent) ----
alter table availabilities
  add column if not exists min_trust smallint not null default 0
  check (min_trust >= 0 and min_trust <= 100);

comment on column availabilities.min_trust is
  'MVP "trusted guests only" karşılığı. 0 = eşik yok. Sunucu tarafında zorlanır.';


-- ============================================================
-- 2. create_availability — 033'ün gövdesi BİREBİR korunuyor,
--    yalnızca iki parametre ve iki kolon EKLENİYOR.
--    (033'ün tüm kuralları duruyor: telefon doğrulaması,
--     kapasite, geçmiş tarih, guest_same_slot çakışması.)
-- ============================================================
create or replace function public.create_availability(
  p_lounge_id uuid, p_airport text, p_date date, p_from time, p_to time, p_slots int,
  p_flight text default null, p_visibility text default 'all'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_cap int; v_ok boolean; v_id uuid; v_conflict boolean;
  v_vis availability_visibility; v_min_trust smallint := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if p_slots > v_cap then raise exception 'slots_exceed_capacity'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;

  -- 033: örtüşen saatte bekleyen/kabul edilmiş guest isteğin varsa ilan açamazsın
  select exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = p_date
       and a.time_from < p_to and p_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'guest_same_slot'; end if;

  -- YENİ (040): MVP'nin all/trusted/hidden -> enum + eşik
  case lower(coalesce(p_visibility,'all'))
    when 'all'         then v_vis := 'Public';      v_min_trust := 0;
    when 'trusted'     then v_vis := 'Public';      v_min_trust := 55;
    when 'hidden'      then v_vis := 'Hidden';      v_min_trust := 0;
    when 'connections' then v_vis := 'Connections'; v_min_trust := 0;
    else raise exception 'bad_visibility';
  end case;

  insert into availabilities (
    host_id, lounge_id, airport_code, avail_date, time_from, time_to,
    slots, filled, active, visibility, flight_number, min_trust
  )
  values (
    v_uid, p_lounge_id, p_airport, p_date, p_from, p_to,
    p_slots, 0, true, v_vis, nullif(trim(p_flight),''), v_min_trust
  )
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'visibility', v_vis, 'min_trust', v_min_trust);
end $$;


-- ============================================================
-- 3. discover_availabilities — 030'un gövdesi BİREBİR korunuyor.
--    DEĞİŞEN YALNIZCA:
--      a) p.linkedin -> p.linkedin_url        (canlı bug — bkz. başlık)
--      b) görünürlük filtresi EKLENDİ         (Hidden / Connections / min_trust)
--      c) dönüş tablosuna visibility kolonu eklendi (app rozet gösterebilsin)
--    Match score formülü, kadın güvenlik kuralı, gölge kısıt,
--    fotoğraf gizliliği, featured sıralaması — hepsi 030'daki gibi.
-- ============================================================
create or replace function public.discover_availabilities(
  p_airport text default null, p_sector text default null, p_flight text default null,
  p_date date default null
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, host_photo text, match_score int,
  same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean,
  visibility text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_langs text[]; v_prof text; v_sessions int; v_rated int; v_my_trust int;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false), pr.languages, pr.profession
    into v_female, v_safe, v_langs, v_prof
    from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status='completed' and (r.guest_id=v_uid or r.host_id=v_uid);
  select count(*) into v_rated from ratings where rater_id = v_uid;

  -- YENİ (040): kendi güven puanım — min_trust eşiğiyle karşılaştırmak için
  select coalesce(score,0) into v_my_trust from trust_scores where user_id = v_uid;
  v_my_trust := coalesce(v_my_trust, 0);

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, coalesce(ts.score,0) as hs, p.profession as hp,
      p.languages as hlangs, hu.gender as hgender,
      case when p.photo_url is not null and (
             coalesce(p.photo_connections_only,false) = false
             or exists (select 1 from connection_requests cr where cr.status='accepted'
                        and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
           ) then p.photo_url else null end as photo,
      coalesce(v.id_verified,false) as hid,
      -- 🔴 040 DÜZELTMESİ: 030'da `p.linkedin` yazıyordu — öyle bir kolon yok.
      (p.linkedin_url is not null and p.linkedin_url <> '') as hlinked,
      (select count(*) from sessions s2 join requests r2 on r2.id=s2.request_id
        where s2.status='completed' and r2.host_id=a.host_id) as hsessions,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.airport_code=a.airport_code
              and vs.visit_date=a.avail_date and vs.time_from < a.time_to and a.time_from < vs.time_to) as has_trip,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.flight_number is not null
              and a.flight_number is not null and upper(vs.flight_number)=upper(a.flight_number)) as same_flight,
      (a.featured_until is not null and a.featured_until > now()) as featured
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    left join verifications v on v.user_id=a.host_id
    where a.active=true
      and hu.role = 'host'
      and a.avail_date >= current_date
      and coalesce(p.show_on_discovery,true)=true
      and public.is_visible(a.host_id)
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))
      -- ============================================================
      -- YENİ (040): GÖRÜNÜRLÜK — host ne seçtiyse o geçerli.
      --   Hidden      : keşifte hiç görünmez (yalnız davetle ulaşılır,
      --                 bkz. 030 send_invite / respond_invite)
      --   Connections : yalnız kabul edilmiş bağlantısı olanlar görür
      --   min_trust>0 : güven puanım eşiğin altındaysa görünmez
      -- Kendi ilanın her zaman sana görünür (host kendi ilanını görmeli).
      -- ============================================================
      and (
        a.host_id = v_uid
        or (
          coalesce(a.visibility,'Public') <> 'Hidden'
          and (
            coalesce(a.visibility,'Public') <> 'Connections'
            or exists (select 1 from connection_requests cr where cr.status='accepted'
                       and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
          )
          and v_my_trust >= coalesce(a.min_trust,0)
        )
      )
  )
  -- 🔴 CAST'LER SART (18 Agu 2026, hata sinifi 24).
  -- `availabilities.airport_code` CHAR(3), `slots`/`filled` SMALLINT;
  -- ust tarafta `returns table (... airport_code text, slots int,
  -- filled int ...)` yaziyor. PostgreSQL `returns table` sozlesmesinde
  -- GENISLETME YAPMAZ (olculdu: integer<-smallint bile 42804 verir) ve
  -- bu hata SATIR YOKKEN CIKMAZ — bos veritabaninda migration temiz
  -- gorunur, veri varken ILK SATIRDA patlar. Gokberk canlida bunu
  -- 186'da iki kez yasadi; ayni kusur bu dosyada da duruyordu.
  select b.id, b.host_id, b.airport_code::text, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots::int, b.filled::int, b.hn, b.hb, b.hs, b.hp, b.photo,
         least(99,
           40
           + (case when b.hs >= 70 then 18 when b.hs >= 55 then 10 else 0 end)
           + (case when b.hid then 14 else 0 end)
           + (case when b.same_flight then 14 else 0 end)
           + (case when v_prof is not null and b.hp is not null
                    and (b.hp ilike '%'||v_prof||'%' or v_prof ilike '%'||b.hp||'%') then 12 else 0 end)
           + (case when v_female and b.hgender = 'female' then 10 else 0 end)
           + (case when b.hsessions >= 3 then 8 else 0 end)
           + (case when b.hlinked then 6 else 0 end)
           + (case when v_langs is not null and b.hlangs is not null and (v_langs && b.hlangs) then 5 else 0 end)
           + (case when v_rated > 0 then 4 else 0 end)
           + (case when b.has_trip then 10 else 0 end)
         )::int as match_score,
         b.same_flight, b.has_trip, b.featured, (b.filled >= b.slots) as fully_booked,
         coalesce(b.visibility,'Public')::text as visibility
  from base b
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $$;


-- ============================================================
-- 4. my_availabilities — host kendi ilanlarını görsün.
--
-- "Müsaitlik açtım, hiçbir yere yansımadı" şikayetinin ikinci yarısı:
-- ilan kaydedilse bile host'un onu göreceği bir ekran/sorgu yoktu.
-- Trips/Hosting sekmesi bunu çağıracak.
-- ============================================================
create or replace function public.my_availabilities()
returns table (
  id uuid, airport_code text, lounge_id uuid, lounge_name text,
  avail_date date, time_from time, time_to time,
  slots int, filled int, flight_number text, visibility text, min_trust int,
  active boolean, is_featured boolean, pending_count int
)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return query
  select a.id, a.airport_code::text,
         a.lounge_id,
         coalesce(l.name, a.lounge_name) as lounge_name,
         a.avail_date, a.time_from, a.time_to,
         a.slots::int, a.filled::int, a.flight_number,
         coalesce(a.visibility,'Public')::text, coalesce(a.min_trust,0)::int,
         a.active,
         (a.featured_until is not null and a.featured_until > now()) as is_featured,
         (select count(*) from requests r where r.avail_id = a.id and r.status='pending')::int as pending_count
  from availabilities a
  left join lounges l on l.id = a.lounge_id
  where a.host_id = v_uid
  order by a.avail_date desc, a.time_from desc;
end $$;


-- ============================================================
-- 5. cancel_availability — açtığın ilanı kapatabilmelisin.
--    Kabul edilmiş isteği varsa engellenir (misafir mağdur olmasın).
-- ============================================================
create or replace function public.cancel_availability(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_accepted int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from availabilities where id=p_id and host_id=v_uid) then
    raise exception 'not_your_availability';
  end if;

  select count(*) into v_accepted from requests
   where avail_id = p_id and status = 'accepted';
  if v_accepted > 0 then raise exception 'has_accepted_requests'; end if;

  update availabilities set active=false, updated_at=now() where id=p_id;
  return jsonb_build_object('ok', true);
end $$;


grant execute on function public.create_availability(uuid,text,date,time,time,int,text,text) to authenticated;
grant execute on function public.discover_availabilities(text,text,text,date) to authenticated;
grant execute on function public.my_availabilities() to authenticated;
grant execute on function public.cancel_availability(uuid) to authenticated;


-- ============================================================
-- DOĞRULAMA — çalıştırdıktan sonra bunu da çalıştır.
-- Her fonksiyon TEK sürüm göstermeli (surum_sayisi = 1).
-- ============================================================
select p.proname as fonksiyon, count(*) as surum_sayisi
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public'
  and p.proname in ('create_availability','discover_availabilities','my_availabilities','cancel_availability')
group by p.proname
order by p.proname;
