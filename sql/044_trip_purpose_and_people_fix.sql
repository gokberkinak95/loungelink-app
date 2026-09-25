-- ============================================================
-- 044 — SEYAHAT AMACI + discover_people'ın ÜÇ CANLI HATASI
--
-- ÖNCE 044a_PRE_drop.sql ÇALIŞTIR. 043'ten sonra gelir.
--
-- ============================================================
-- 1) SEYAHAT AMACI (Gokberk'in kararı)
-- ============================================================
-- MVP'nin AddVisit ekranında "Travel purpose" çipleri vardı
-- (Business/Conference/Leisure/Connecting/Event). v1.22'de çipleri
-- porttuk ama `visits` tablosunda karşılığı yoktu — kullanıcı
-- seçtiğini sanıyor, hiçbir yere yazılmıyordu. Dekoratifti.
--
-- NEDEN text + CHECK, enum DEĞİL:
-- Şema genelde enum kullanıyor ama yeni bir amaç eklemek gerekirse
-- (`alter type ... add value`) Supabase editöründe tek transaction
-- içinde riskli. CHECK kısıtı ise drop/add ile kolayca genişler.
-- Enum'un kazandırdığı tip güvenliğini CHECK zaten veriyor.
--
-- ============================================================
-- 2) 🔴 discover_people p_airport'u KULLANMIYORDU
-- ============================================================
-- 024'teki imza `discover_people(p_airport text default null)` ama
-- gövdede p_airport bir kez bile geçmiyor. Yani Tanış sekmesi
-- HANGİ HAVALİMANINDA olursan ol AYNI listeyi gösteriyordu —
-- Ankara'daki biri İstanbul'daki yolcuları görüyordu. Ürünün
-- "aynı lounge'daki insanlarla tanış" vaadi çalışmıyordu.
--
-- ============================================================
-- 3) 🔴 discover_people is_visible()'ı ÇAĞIRMIYORDU
-- ============================================================
-- 041'de is_visible()'a is_staff koşulunu ekleyip "tek noktadan
-- kapandı" demiştim. YANLIŞTI: discover_people onu hiç çağırmıyor
-- (lounge_radar_people çağırıyor, discover_availabilities çağırıyor).
-- Yani BO admin hesabı Tanış listesinde HÂLÂ görünüyordu.
-- Gölge kısıtlı (shadow_limited) kullanıcılar da görünüyordu —
-- moderasyon aracı orada da delikti.
-- ============================================================


-- ---- 1. purpose kolonu ----
alter table visits add column if not exists purpose text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'visits_purpose_check') then
    alter table visits add constraint visits_purpose_check
      check (purpose is null or purpose in
        ('business','conference','leisure','connecting','event'));
  end if;
end $$;

comment on column visits.purpose is
  'MVP v15 AddVisit seyahat amacı. business|conference|leisure|connecting|event. Meet eşleşmesinde sinyal (044).';

create index if not exists idx_visits_purpose on visits(airport_code, visit_date, purpose)
  where purpose is not null;


-- ============================================================
-- 2+3. discover_people — 024'ün gövdesi BİREBİR korunuyor.
--
-- DEĞİŞENLER (yalnız bunlar):
--   a) p_airport artık GERÇEKTEN filtreliyor: aynı havalimanında,
--      örtüşen zaman aralığında seyahati olan kişiler
--   b) is_visible(p.user_id) eklendi -> staff + gölge kısıt kapandı
--   c) purpose + same_purpose + airport dönüyor
--   d) sıralama: aynı amaç önce, sonra güven puanı
--
-- KORUNANLAR: kadın güvenlik modu çift yönlü kuralı, fotoğraf
-- gizliliği (photo_connections_only), rel (bağlantı durumu),
-- show_on_discovery, limit 60.
-- ============================================================
create or replace function public.discover_people(
  p_airport text default null, p_date date default null
)
returns table (
  user_id uuid, name text, profession text, bio text, badge text, score int,
  rel text, photo text, purpose text, same_purpose boolean, airport text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_my_purpose text; v_my_airport text; v_my_date date;
  v_from time; v_to time;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  -- Kendi aktif seyahatim: amaç + havalimanı + zaman aralığı
  select v.purpose, v.airport_code::text, v.visit_date, v.time_from, v.time_to
    into v_my_purpose, v_my_airport, v_my_date, v_from, v_to
    from visits v
   where v.user_id = v_uid
     and (p_airport is null or v.airport_code = p_airport)
     and (p_date is null or v.visit_date = p_date)
     and v.visit_date >= current_date
   order by v.visit_date, v.time_from
   limit 1;

  -- Filtrelenecek havalimanı: parametre > kendi seyahatim
  v_my_airport := coalesce(p_airport, v_my_airport);
  v_my_date := coalesce(p_date, v_my_date);

  return query
  with theirs as (
    select distinct on (v.user_id)
           v.user_id, v.purpose, v.airport_code::text as ap, v.visit_date, v.time_from, v.time_to
      from visits v
     where v.visit_date >= current_date
       and (v_my_airport is null or v.airport_code = v_my_airport)
       and (v_my_date is null or v.visit_date = v_my_date)
       -- zaman örtüşmesi: ikimiz de oradayken
       and (v_from is null or (v.time_from < v_to and v_from < v.time_to))
     order by v.user_id, v.visit_date, v.time_from
  )
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false) = false
                or coalesce(cr.status::text,'') = 'accepted'
              ) then p.photo_url else null end as photo,
         th.purpose,
         (v_my_purpose is not null and th.purpose is not null
          and th.purpose = v_my_purpose) as same_purpose,
         th.ap as airport
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    left join connection_requests cr on
      (cr.from_id = v_uid and cr.to_id = p.user_id) or (cr.from_id = p.user_id and cr.to_id = v_uid)
    -- YENİ (044): havalimanı filtresi GERÇEKTEN uygulanıyor.
    -- v_my_airport null ise (seyahatim yok, filtre de yok) herkesi göster —
    -- 024'teki eski davranış korunur, yoksa liste bomboş kalırdı.
    left join theirs th on th.user_id = p.user_id
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and public.is_visible(p.user_id)                  -- YENİ (044): staff + gölge kısıt
     and (v_my_airport is null or th.user_id is not null)
     and (not (v_female and v_safe) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode,false)
          or (v_female and exists (select 1 from verifications v where v.user_id=v_uid and v.phone_verified)))
   order by (v_my_purpose is not null and th.purpose = v_my_purpose) desc nulls last,
            ts.score desc nulls last
   limit 60;
end $$;


-- ============================================================
-- 3. my_visits — app'in Trips ekrani icin (amac dahil)
-- ============================================================
create or replace function public.my_visits()
returns table (
  id uuid, airport_code text, destination text, visit_date date,
  time_from time, time_to time, flight_number text, purpose text,
  open_hosts int, people_here int
)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return query
  select v.id, v.airport_code::text, v.destination::text, v.visit_date,
         v.time_from, v.time_to, v.flight_number, v.purpose,
         -- bu seyahate uyan acik ilan sayisi
         (select count(*)::int from availabilities a
           where a.active and a.airport_code = v.airport_code
             and a.avail_date = v.visit_date
             and a.time_from < v.time_to and v.time_from < a.time_to
             and a.filled < a.slots
             and a.host_id <> v_uid
             and coalesce(a.visibility,'Public') <> 'Hidden') as open_hosts,
         -- ayni yerde/zamanda kac kisi var (kendim haric)
         (select count(distinct v2.user_id)::int from visits v2
            join users u2 on u2.id = v2.user_id
           where v2.airport_code = v.airport_code
             and v2.visit_date = v.visit_date
             and v2.time_from < v.time_to and v.time_from < v2.time_to
             and v2.user_id <> v_uid
             and coalesce(u2.is_staff,false) = false) as people_here
  from visits v
  where v.user_id = v_uid
  order by v.visit_date desc, v.time_from desc;
end $$;


grant execute on function public.discover_people(text, date) to authenticated;
grant execute on function public.my_visits() to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select 'visits.purpose kolonu' as kontrol,
  case when exists (select 1 from information_schema.columns
    where table_name='visits' and column_name='purpose') then '✓ OK' else '🔴 YOK' end as sonuc
union all
select 'discover_people p_airport kullaniyor',
  case when (select prosrc from pg_proc where proname='discover_people' limit 1) like '%v_my_airport%'
  then '✓ OK' else '🔴 HAYIR' end
union all
select 'discover_people is_visible cagiriyor',
  case when (select prosrc from pg_proc where proname='discover_people' limit 1) like '%is_visible%'
  then '✓ OK' else '🔴 HAYIR' end
union all
select 'discover_people surum sayisi (1 olmali)',
  (select count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='discover_people')
union all
select 'amac girilmis seyahat sayisi', (select count(*)::text from visits where purpose is not null);
