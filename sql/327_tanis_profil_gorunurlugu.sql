-- ============================================================================
-- 327 · TANIŞ PROFİL GÖRÜNÜRLÜĞÜNÜ OKUR  (4 Ekim 2026)
--
-- BULGU (B21 · Tanış "Tümü" incelemesi): discover_people profiles.profile_visibility
-- tercihini HİÇ okumuyordu. "Yalnız bağlantılarım" ya da "Güvendiklerim" seçen kişi
-- herkesin Tanış listesinde görünüyordu; kisi_ara (profil_gorunur_mu) ise okuyordu.
-- DÜZELTME: aynı kural satır içinde (izleyici eşiği bir kez; satırda indeksli ilişki
-- kontrolü — 319'un hızı korunur). ÖNKOŞUL: 319 + 324. Tekrar koşulabilir.
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
  v327_guvenilir boolean;
begin
  -- 327 · PROFİL GÖRÜNÜRLÜĞÜ (profil_gorunur_mu İLE EŞ, satır içinde). Tanış bu tercihi hiç
  -- okumuyordu: "Yalnız bağlantılarım" seçen kişi herkesin Tanış listesinde çıkıyordu (kisi_ara
  -- okuyordu). İzleyicinin güven eşiği BİR KEZ; satırda yalnız ilişki kontrolü (indeksli).
  -- profil_gorunur_mu DEĞİŞİRSE BURASI DA.
  v327_guvenilir := coalesce((select t7.score from trust_scores t7 where t7.user_id = auth.uid()), 0)
                    >= coalesce((select (b7.value #>> '{}')::int from beta_settings b7 where b7.key = 'profil_trusted_esik'), 40);
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
     -- 324 · SİLİNMİŞ ve YASAKLI hesap Tanış'ta görünüyordu (Keşfet ve kişi arama
     -- ikisini de süzüyor; burası süzmüyordu). Ölçüldü: banlanan kullanıcı Keşfet'ten
     -- ve aramadan düşüyor, Tanış'ta kalıyor → ona bağlantı isteği gönderilebiliyordu.
     and hu.deleted_at is null and hu.banned_at is null
     and coalesce(p.show_on_discovery, true) = true
     -- 327 · profil görünürlüğü (Everyone · Trusted+ · Connections) — aramızda istek/bağlantı varsa tercih devreye girmez
     and (coalesce(p.profile_visibility::text, 'Everyone') = 'Everyone'
          or (p.profile_visibility::text = 'Trusted+' and v327_guvenilir)
          -- ilişkili kişiler kümesi BİR KEZ (ilişkisiz alt sorgu → karma küme), satırda yalnız üyelik
          or p.user_id in (select case when c7.from_id = v_uid then c7.to_id else c7.from_id end
                             from connection_requests c7
                            where (c7.from_id = v_uid or c7.to_id = v_uid) and c7.status in ('pending','accepted')
                           union
                           select case when r7.guest_id = v_uid then r7.host_id else r7.guest_id end
                             from requests r7 where r7.guest_id = v_uid or r7.host_id = v_uid))
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

select 'tanis profil gorunurlugu' as kontrol,
       position('327 · PROFİL GÖRÜNÜRLÜĞÜ' in pg_get_functiondef('public.discover_people_prebfilter(text,date)'::regprocedure)) > 0 as tamam;
-- Beklenen: tamam = true.
