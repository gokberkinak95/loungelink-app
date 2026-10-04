-- ============================================================================
-- 319 · TANIŞ / KİŞİ ARAMA / RADAR: is_visible SATIR İÇİNDE  (4 Ekim 2026)
--
-- ÖLÇÜM (ll_yuk · 50.076 üye): discover_people('IST') 15.500 ms. Kök 317 ile
-- aynı: discover_people_prebfilter her profil için is_visible() →
-- test_hesabi_gizli_mi() çağırıyordu (50.075 çağrı · 12,6 sn). kisi_ara ve
-- lounge_radar_people aynı kalıbı taşıyor (üye sayısıyla doğrusal büyür).
--
-- DÜZELTME: izleyici tarafı (bayrak · test/personel · test_gorunurlugu) bir kez
-- hesaplanır; kişi tarafı satır içinde AYNI kuralla. is_visible() DEĞİŞİRSE
-- 317 ve 319'daki satır içi kopyalar da değişir.
-- EŞDEĞERLİK: 82 izleyici × 8 sorgu = 656 karşılaştırma, 17.031 satır, 0 fark.
-- havalimani_nabzi (aynı kalıp, test_hesabi_gizli_mi doğrudan): 246 karşılaştırma, 0 fark;
-- ölçek dünyasında 945 ms → aşağıda ölçülen.
-- Gövdeler CANLI tanımın üstüne eklendi. Supabase SQL Editor: tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.discover_people_prebfilter(p_airport text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(user_id uuid, name text, profession text, bio text, badge text, score integer, rel text, photo text, purpose text, same_purpose boolean, airport text, is_hosting boolean, host_avail_id uuid, host_slots_left integer, host_airport text, can_request boolean, req_reason text, visit_date date, flight_number text, same_flight boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v319_staff boolean; v319_test_gorur boolean;
 
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_phone_ok boolean;
begin
  -- 319 · is_visible() İLE EŞ — izleyici tarafı BİR KEZ (bkz. 317 · discover_availabilities_base).
  -- Satır başına is_visible → test_hesabi_gizli_mi çağrısı (SECURITY DEFINER + SET, satır içine
  -- alınamaz) ölçek dünyasında discover_people'ı 15,5 sn'ye çıkarıyordu. is_visible DEĞİŞİRSE BURASI DA.
  select coalesce(x.is_staff, false), public.seed_test_hesabi(x.email)
    into v319_staff, v319_test_gorur from users x where x.id = auth.uid();
  v319_staff := coalesce(v319_staff, false);
  v319_test_gorur := coalesce(v319_test_gorur, false) or v319_staff
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
  select (u.gender='female'), coalesce(pr.women_safety_mode,false)
    into v_female, v_safe from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select coalesce(bool_or(v.phone_verified), false) into v_phone_ok
    from verifications v where v.user_id = v_uid;

  return query
  with
  -- Karşı tarafın en yakın aktif+açık-slotlu ilanı (İstek butonu bilgisi)
  hosting as (
    select distinct on (a.host_id)
           a.host_id, a.id as avail_id, a.airport_code::text as ap,
           a.avail_date, a.time_from, a.time_to,
           greatest(0, a.slots - coalesce(a.filled,0)) as slots_left
      from availabilities a
     where a.active = true
       and a.avail_date >= current_date
       and a.visibility <> 'Hidden'
       and coalesce(a.min_trust,0) = 0
       and greatest(0, a.slots - coalesce(a.filled,0)) > 0
       and (p_airport is null or a.airport_code = p_airport)
       and (p_date is null or a.avail_date = p_date)
     order by a.host_id, a.avail_date, a.time_from
  ),
  -- Karşı tarafın en yakın seyahati — MVP kartında "✈ IST · 15 Haziran" ve
  -- "AYNI UÇUŞ · TK712" bunun üzerinden gösterilir. ESKİ SÜRÜMDE YOKTU:
  -- airport yalnız hosting CTE'sinden geliyordu, dolayısıyla ilanı olmayan
  -- misafirlerde tüm bu alanlar BOŞ kalıyordu (Canlı APP 3).
  trip as (
    select distinct on (v.user_id)
           v.user_id, v.airport_code::text as ap, v.visit_date,
           v.flight_number, v.purpose
      from visits v
     where v.visit_date >= current_date
       and (p_airport is null or v.airport_code = p_airport)
       and (p_date is null or v.visit_date = p_date)
     order by v.user_id, v.visit_date, v.time_from
  ),
  -- Benim seyahatlerim — İstek kapısı için (aynı yer/tarih/±1s örtüşme)
  mine as (
    select v.airport_code::text as ap, v.visit_date, v.time_from, v.time_to,
           v.flight_number, v.purpose
      from visits v
     where v.user_id = v_uid and v.visit_date >= current_date
  )
  select p.user_id, p.name, p.profession, p.bio, ts.badge, ts.score,
         coalesce(cr.status::text, 'none') as rel,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false) = false
                or coalesce(cr.status::text,'') = 'accepted'
              ) then p.photo_url else null end as photo,
         tr.purpose,
         (tr.purpose is not null and exists (
            select 1 from mine m where m.purpose = tr.purpose)) as same_purpose,
         coalesce(tr.ap, ho.ap) as airport,
         (ho.host_id is not null) as is_hosting,
         ho.avail_id as host_avail_id,
         ho.slots_left as host_slots_left,
         ho.ap as host_airport,
         -- can_request: üç şart birden
         (ho.host_id is not null
          and v_phone_ok
          and exists (
            select 1 from mine m
             where m.ap = ho.ap
               and m.visit_date = ho.avail_date
               -- saat penceresi ±1 saat (ilan from-1s .. to+1s ile örtüşme)
               and m.time_from < (ho.time_to + interval '1 hour')
               and (ho.time_from - interval '1 hour') < m.time_to
          )) as can_request,
         -- req_reason: neden pasif (öncelik: ilan yok > telefon > seyahat)
         case
           when ho.host_id is null then 'noslot'
           when not v_phone_ok then 'phone'
           when not exists (
             select 1 from mine m
              where m.ap = ho.ap and m.visit_date = ho.avail_date
                and m.time_from < (ho.time_to + interval '1 hour')
                and (ho.time_from - interval '1 hour') < m.time_to
           ) then 'trip'
           else null
         end as req_reason,
         tr.visit_date,
         tr.flight_number,
         -- AYNI UÇUŞ: benim uçuş numaramla eşleşiyor mu
         (tr.flight_number is not null and exists (
            select 1 from mine m
             where m.flight_number is not null
               and upper(m.flight_number) = upper(tr.flight_number))) as same_flight
    from profiles p
    join users hu on hu.id = p.user_id
    left join trust_scores ts on ts.user_id = p.user_id
    -- 286: iki yönde de kayıt olabilir (bağlantı isteği + kural sorusu) →
    -- eski LEFT JOIN kişiyi İKİ KEZ listeliyordu. En anlamlı TEK satır seçilir.
    left join lateral (
      select c.status from connection_requests c
       where (c.from_id = v_uid and c.to_id = p.user_id)
          or (c.from_id = p.user_id and c.to_id = v_uid)
       order by (c.status::text = 'accepted') desc,
                (coalesce(c.intent,'') <> 'kural_sorusu') desc,
                c.created_at desc
       limit 1
    ) cr on true
    left join hosting ho on ho.host_id = p.user_id
    left join trip tr on tr.user_id = p.user_id
   where p.user_id <> v_uid
     and coalesce(p.show_on_discovery, true) = true
     and (/* 319 · is_visible ile eş */ (v319_test_gorur or not public.seed_test_hesabi(hu.email))
         and not coalesce(hu.shadow_limited and (hu.restricted_until is null or hu.restricted_until > now()), false)
         and (not coalesce(hu.is_staff, false) or v319_staff))
     -- KADIN GÜVENLİK — 049 kuralı AYNEN korunur:
     and (not (v_female and v_safe) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode,false)
          or (v_female and v_phone_ok)
          or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid)
          or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                     where r9.guest_id = p.user_id and a9.host_id = v_uid)
          or exists (select 1 from invites i9 where i9.host_id = p.user_id and i9.guest_id = v_uid))
   order by (ho.host_id is not null) desc,          -- ilanı olanlar üstte
            ts.score desc nulls last
   limit 100;
end $function$;

CREATE OR REPLACE FUNCTION public.kisi_ara(p_q text)
 RETURNS TABLE(user_id uuid, ad text, meslek text, foto text, iliski text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v319_staff boolean; v319_test_gorur boolean;
  v_uid uuid := auth.uid(); v_q text; v_female boolean; v_safe boolean; v_phone_ok boolean;
begin
  -- 319 · is_visible() İLE EŞ — izleyici tarafı BİR KEZ (bkz. 317 · discover_availabilities_base).
  -- Satır başına is_visible → test_hesabi_gizli_mi çağrısı (SECURITY DEFINER + SET, satır içine
  -- alınamaz) ölçek dünyasında discover_people'ı 15,5 sn'ye çıkarıyordu. is_visible DEĞİŞİRSE BURASI DA.
  select coalesce(x.is_staff, false), public.seed_test_hesabi(x.email)
    into v319_staff, v319_test_gorur from users x where x.id = auth.uid();
  v319_staff := coalesce(v319_staff, false);
  v319_test_gorur := coalesce(v319_test_gorur, false) or v319_staff
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_q := btrim(coalesce(p_q, ''));
  if char_length(v_q) < 2 then return; end if;
  v_q := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_');

  select (u.gender = 'female'), coalesce(pr.women_safety_mode, false)
    into v_female, v_safe
    from users u left join profiles pr on pr.user_id = u.id where u.id = v_uid;
  select coalesce(phone_verified, false) into v_phone_ok from verifications where verifications.user_id = v_uid;

  return query
  select p.user_id, public.kisa_ad(p.user_id),
         nullif(btrim(coalesce(p.profession, '')), ''),
         case when p.photo_url is not null and not coalesce(p.photo_connections_only, false) then p.photo_url end,
         coalesce((select c.status::text from connection_requests c
                    where ((c.from_id = v_uid and c.to_id = p.user_id) or (c.from_id = p.user_id and c.to_id = v_uid))
                      and coalesce(c.intent, '') <> 'kural_sorusu'
                    order by (c.status::text = 'accepted') desc, c.created_at desc limit 1), 'none')
    from profiles p
    join users hu on hu.id = p.user_id
   where p.user_id <> v_uid
     and hu.deleted_at is null and hu.banned_at is null
     and (p.name ilike v_q || '%' or p.name ilike '% ' || v_q || '%')   -- kelime başı
     and coalesce(p.show_on_discovery, true)
     and (/* 319 · is_visible ile eş */ (v319_test_gorur or not public.seed_test_hesabi(hu.email))
         and not coalesce(hu.shadow_limited and (hu.restricted_until is null or hu.restricted_until > now()), false)
         and (not coalesce(hu.is_staff, false) or v319_staff))
     and public.profil_gorunur_mu(p.user_id)
     and not public.is_blocked_pair(v_uid, p.user_id)
     and (not (coalesce(v_female, false) and coalesce(v_safe, false)) or hu.gender = 'female')
     and (not coalesce(p.women_safety_mode, false)
          or (coalesce(v_female, false) and coalesce(v_phone_ok, false))
          or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid))
   order by (p.name ilike v_q || '%') desc, p.name
   limit 20;
end $function$;

CREATE OR REPLACE FUNCTION public.lounge_radar_people()
 RETURNS TABLE(user_id uuid, name text, profession text, bio text, badge text, score integer, photo_url text, same_flight boolean, rel text, lounge_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v319_staff boolean; v319_test_gorur boolean;
 
  v_uid uuid := auth.uid();
  v_air text; v_from time; v_to time; v_flight text;
  v_me_women boolean; v_me_gender text; v_me_share boolean;
begin
  -- 319 · is_visible() İLE EŞ — izleyici tarafı BİR KEZ (bkz. 317 · discover_availabilities_base).
  -- Satır başına is_visible → test_hesabi_gizli_mi çağrısı (SECURITY DEFINER + SET, satır içine
  -- alınamaz) ölçek dünyasında discover_people'ı 15,5 sn'ye çıkarıyordu. is_visible DEĞİŞİRSE BURASI DA.
  select coalesce(x.is_staff, false), public.seed_test_hesabi(x.email)
    into v319_staff, v319_test_gorur from users x where x.id = auth.uid();
  v319_staff := coalesce(v319_staff, false);
  v319_test_gorur := coalesce(v319_test_gorur, false) or v319_staff
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select coalesce(p.location_sharing, false) into v_me_share from profiles p where p.user_id = v_uid;
  if not v_me_share then return; end if;

  -- bağlam: bugün, şu anı kapsayan ilan veya trip
  select a.airport_code, a.time_from, a.time_to into v_air, v_from, v_to
    from availabilities a
   where a.host_id = v_uid and a.active
     and a.avail_date = public.yerel_gun(a.airport_code)
     and a.time_from <= public.yerel_saat(a.airport_code)
     and public.yerel_saat(a.airport_code) <= a.time_to
   limit 1;

  if v_air is null then
    select v.airport_code, v.time_from, v.time_to, v.flight_number into v_air, v_from, v_to, v_flight
      from visits v
     where v.user_id = v_uid
       and v.visit_date = public.yerel_gun(v.airport_code)
       and v.time_from <= public.yerel_saat(v.airport_code)
       and public.yerel_saat(v.airport_code) <= v.time_to
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
     where v.visit_date = public.yerel_gun(v_air)
       and v.airport_code = v_air
       and v.time_from < v_to and v_from < v.time_to
       and v.user_id <> v_uid
    union
    select a.host_id as uid, null::text as flight, a.lounge_id as lid
      from availabilities a
     where a.active and a.avail_date = public.yerel_gun(v_air)
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
    and (/* 319 · is_visible ile eş */ (v319_test_gorur or not public.seed_test_hesabi(u.email))
         and not coalesce(u.shadow_limited and (u.restricted_until is null or u.restricted_until > now()), false)
         and (not coalesce(u.is_staff, false) or v319_staff))
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
end $function$;

-- havalimani_nabzi: test_hesabi_gizli_mi ilan/seyahat başına (45.109 çağrı) → satır içi
CREATE OR REPLACE FUNCTION public.havalimani_nabzi(p_gun integer DEFAULT 14)
 RETURNS TABLE(airport_code text, sehir text, canli_ilan integer, acik_slot integer, host_sayisi integer, bekleyen_istek integer, talep_kaydi integer, aktif_seyahat integer, tamamlanan_oturum integer, doluluk numeric, karsilanma numeric, durum text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_son date := current_date + greatest(1, coalesce(p_gun,14));
  v319_test_gorur boolean;
begin
  -- 319 · not test_hesabi_gizli_mi(x) İLE EŞ — izleyici tarafı bir kez; ilan ve seyahat
  -- başına çağrı (45.109 çağrı · ~0,8 sn ölçek dünyasında) yerine satır içi e-posta kontrolü.
  select public.seed_test_hesabi(x.email) or coalesce(x.is_staff, false)
    into v319_test_gorur from users x where x.id = auth.uid();
  v319_test_gorur := coalesce(v319_test_gorur, false)
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
  return query
  with arz as (
    select a.airport_code::text as ap,
           count(*)::int                                   as ilan,
           coalesce(sum(greatest(0, a.slots - coalesce(a.filled,0))),0)::int as slot,
           coalesce(sum(a.slots),0)::int                    as toplam_slot,
           coalesce(sum(coalesce(a.filled,0)),0)::int       as dolu,
           count(distinct a.host_id)::int                   as hostlar
      from availabilities a
     where a.active and a.avail_date between current_date and v_son
       and a.visibility <> 'Hidden'
       and (v319_test_gorur or not exists (select 1 from users tu where tu.id = a.host_id and public.seed_test_hesabi(tu.email)))   -- 301/§3 · 319
     group by a.airport_code
  ), talep as (
    select a.airport_code::text as ap, count(*)::int as bekleyen
      from requests r join availabilities a on a.id = r.avail_id
     where r.status = 'pending' and a.avail_date between current_date and v_son
     group by a.airport_code
  ), haber as (
    select t.airport_code::text as ap, count(*)::int as kayit
      from talep_kayitlari t
     where t.aktif and t.tarih_bit >= current_date and t.tarih_bas <= v_son
     group by t.airport_code
  ), seyahat as (
    select v.airport_code::text as ap, count(*)::int as gezi
      from visits v
     where v.visit_date between current_date and v_son
       and (v319_test_gorur or not exists (select 1 from users tu where tu.id = v.user_id and public.seed_test_hesabi(tu.email)))   -- 301/§3 · 319
     group by v.airport_code
  ), oturum as (
    select a.airport_code::text as ap, count(*)::int as bitmis
      from sessions s join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
     where s.status = 'completed'
     group by a.airport_code
  )
  select ap.code::text,
         coalesce(ap.city, ap.name),
         coalesce(arz.ilan,0), coalesce(arz.slot,0), coalesce(arz.hostlar,0),
         coalesce(talep.bekleyen,0), coalesce(haber.kayit,0), coalesce(seyahat.gezi,0),
         coalesce(oturum.bitmis,0),
         case when coalesce(arz.toplam_slot,0) = 0 then null
              else round(arz.dolu::numeric / arz.toplam_slot, 2) end,
         -- 🔴 SIFIRA BÖLME DEĞİL, ANLAMSIZ ORAN KORUMASI:
         -- talep yoksa "karşılanma" diye bir şey yoktur; 0 yazmak
         -- "hiç karşılamıyoruz" gibi okunurdu. null = ölçülemedi.
         case when (coalesce(talep.bekleyen,0) + coalesce(haber.kayit,0)) = 0 then null
              else round(coalesce(arz.slot,0)::numeric
                         / (coalesce(talep.bekleyen,0) + coalesce(haber.kayit,0)), 2) end,
         case when coalesce(arz.hostlar,0) = 0 then 'soguk'
              when coalesce(arz.hostlar,0) < 3 then 'isiniyor'
              else 'canli' end
    from airports ap
    left join arz     on arz.ap     = ap.code::text
    left join talep   on talep.ap   = ap.code::text
    left join haber   on haber.ap   = ap.code::text
    left join seyahat on seyahat.ap = ap.code::text
    left join oturum  on oturum.ap  = ap.code::text
   where coalesce(arz.ilan,0) > 0 or coalesce(talep.bekleyen,0) > 0
      or coalesce(haber.kayit,0) > 0 or coalesce(seyahat.gezi,0) > 0
   order by coalesce(arz.hostlar,0) desc, coalesce(haber.kayit,0) desc, ap.code;
end $function$;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select p.proname as fonksiyon,
       position('is_visible(p.user_id)' in p.prosrc) = 0
         and position('is_visible(pe.uid)' in p.prosrc) = 0
         and position('not public.test_hesabi_gizli_mi(' in p.prosrc) = 0
         and position('v319_test_gorur' in p.prosrc) > 0 as tamam
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('discover_people_prebfilter', 'kisi_ara', 'lounge_radar_people', 'havalimani_nabzi')
 order by 1;
-- Beklenen: dört satır, tamam = true.
