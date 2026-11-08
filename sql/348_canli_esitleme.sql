-- ============================================================================
-- 348 · CANLI VERİTABANI DOSYALARLA EŞİTLENİR   (9 Kasım 2026)
--
-- DENETIM_TAM (001-347 parmak izi) canlıda şu farkları buldu:
--   · 9 fonksiyonun GÖVDESİ dosyaların kurduğu hâlden farklı (DO-bloğu yamaları canlıda
--     tutmamış ya da eski tanım kalmış). Burada her birinin dosyalardan kurulan son hâli
--     birebir yazılıyor (sql/esitle_uret.py, yerel 001-347 kurulumundan).
--   · 36 fonksiyonun YETKİSİ farklı: bazıları canlıda gereğinden AÇIK (girişsiz kullanıcı
--     çalıştırabiliyordu), bazıları gereğinden KAPALI (uygulamanın çağırdığı plan_kredisi_kalan,
--     plan_ucretli, profil_dogrulandi_hesapla kullanıcıya kapalıydı).
--   · connection_test tablosu (hiçbir dosyada/kodda yok, elle açılmış bir bağlantı denemesi)
--     her giriş yapmış kullanıcıya YAZMA izni veriyordu → istemci yazması kapatılır, tablo durur.
--   · kurulum_imzasi_var (KURULUM_TABLOSU yardımcısı) istemciye açıktı → kapatılır.
-- Bilerek EŞİTLENMEYENLER (zararsız / canlıdaki daha doğru):
--   · *_okuma_korundu politikaları (card_network_source, country_aliases, host_tiers,
--     rule_test_cases, rule_venue_cases): canlıda yok = istemci bu tabloları okuyamıyor; hiçbir
--     istemci okumuyor (host_tiers'ı yalnız BO yönetici bağlantısıyla okuyor). Daha sıkı, kalsın.
--   · schema_migrations.kaynak null olabilir (yalnız kayıt tablosu).
--   · sql_migration_durumu, test_hesabi_kaydi: RLS açık, politika yok → istemciye kapalı.
-- Tekrar koşulabilir. Sonra DENETIM_TAM.sql'i yeniden çalıştır: yalnız yukarıdaki bilinçli
-- farklar (5 politika, 1 kolon ve FAZLA satırları) kalmalı.
-- ============================================================================

-- ── 1 · GÖVDELER ────────────────────────────────────────────────────────────
-- host_requests canlıda ESKİ dönüş tipiyle duruyor (050): create or replace 42P13 verir → önce düşür.
-- Yetkisi aşağıdaki 2. bölümde yeniden veriliyor.
drop function if exists public.host_requests();

-- bo_plan_hediyeleri(p_durum text)
create or replace function public.bo_plan_hediyeleri(p_durum text DEFAULT 'aktif'::text)
 RETURNS TABLE(id uuid, user_id uuid, eposta text, ad text, plan text, plan_adi text, kaynak text, not_metni text, basladi_at timestamp with time zone, biter_at timestamp with time zone, bitti_at timestamp with time zone, iptal_at timestamp with time zone, iptal_notu text, gun_kaldi integer, satin_alinan text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- 🔴 248'DE DÜZELTİLDİ (42702). Burada `where user_id = auth.uid()`
  -- yazıyordu. Bu fonksiyon `returns table (... user_id uuid ...)` ilan
  -- ediyor ve plpgsql'de OUT parametreleri gövdede birer DEĞİŞKENDİR.
  -- Niteliksiz `user_id`, hem `admin_roles.user_id` kolonuna hem o
  -- değişkene işaret ediyordu: "column reference user_id is ambiguous".
  -- Bir PLANLAMA hatası olduğu için deyim her çalıştığında patlıyordu —
  -- yani auth.uid() dolu olan HER admin bu ekranı hiç açamadı.
  -- 🆕 SINIF: "returns table İLE İLAN EDİLEN HER KOLON ADI, GÖVDEDE BİR
  -- DEĞİŞKEN ADIDIR."
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select g.id, g.user_id, u.email, p.name,
         g.plan::text, c.ad, g.kaynak, g.not_metni,
         g.basladi_at, g.biter_at, g.bitti_at, g.iptal_at, g.iptal_notu,
         greatest(0, ceil(extract(epoch from (g.biter_at - now()))/86400)::int),
         u.plan::text
    from plan_grants g
    left join users u on u.id = g.user_id
    left join profiles p on p.user_id = g.user_id
    left join plan_catalog c on c.plan = g.plan
   where case coalesce(p_durum,'aktif')
           when 'aktif' then (g.bitti_at is null and g.iptal_at is null and g.biter_at > now())
           when 'gecmis' then (g.bitti_at is not null or g.iptal_at is not null or g.biter_at <= now())
           else true end
   order by g.biter_at desc
   limit 200;
end $function$;

-- card_advice_for_airport(p_airport text)
create or replace function public.card_advice_for_airport(p_airport text)
 RETURNS TABLE(issuer text, card text, program text, lounges integer, confidence text, source_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select i.name, cp.name, p.name,
         count(distinct a.venue_id)::int,
         coalesce(cp.confidence,'unknown'), cp.source_url
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    join lounge_programs p on p.id = cp.program_id
    join lounge_venue_acceptance a on a.program_id = cp.program_id and a.active and a.accepted
    join lounge_venues v on v.id = a.venue_id and v.active
   where cp.active and v.airport_code = upper(p_airport)
   group by i.name, cp.name, p.name, cp.confidence, cp.source_url
   -- Kac SALONA girdigi belirleyici: bir kart o havalimaninda tek
   -- salona giriyorsa "burada ise yarar" demek yaniltici olur.
   order by count(distinct a.venue_id) desc,
            coalesce(cp.confidence = 'verified', false) desc, i.name
   limit 5;
$function$;

-- charter_note(p_avail_id uuid)
create or replace function public.charter_note(p_avail_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a availabilities%rowtype; v_model text; v_guest_charter boolean;
begin
  select * into a from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('blocked', false, 'note', null); end if;

  select p.entitlement_model into v_model
    from lounge_venue_acceptance lva
    join lounge_programs p on p.id = lva.program_id
    join lounge_venues v on v.id = lva.venue_id
    left join lounges l on l.venue_id = v.id
   where l.id = a.lounge_id and lva.active
   order by coalesce(p.entitlement_model = 'airline_status', false) desc limit 1;

  select v.is_charter into v_guest_charter
    from visits v where v.user_id = auth.uid()
      and v.airport_code = a.airport_code and v.visit_date = a.avail_date
    order by v.created_at desc limit 1;

  -- 🔴 KART AGI / ISLETMECI SALONU: charter ONEMSIZ.
  -- Uyelik KISIYE baglidir, ucusa degil. Havayolunun charter yasagini
  -- buraya uygulamak, yanlis kaynaktan kural cikarmak olurdu.
  if v_model is not null and v_model <> 'airline_status' then
    if coalesce(a.is_charter,false) or coalesce(v_guest_charter,false) then
      return jsonb_build_object('blocked', false,
        'note', 'Seferlerden biri charter. Bu salona giriş havayolu statüsüne değil '
             || 'üyeliğe bağlı olduğu için charter olması sorun değildir; geçerli '
             || 'biniş kartı yeterlidir.');
    end if;
    return jsonb_build_object('blocked', false, 'note', null);
  end if;

  -- Havayolu salonu: charter HAK VERMEZ (iki taraf icin de)
  if coalesce(a.is_charter,false) then
    return jsonb_build_object('blocked', true,
      'note', 'Host''un seferi charter. Havayolu salonlarında charter seferde bilet '
           || 'sınıfı ya da statü kartı ne olursa olsun salon kullanım hakkı yoktur. '
           || 'İstisna: charter anlaşması yapan acente yolcularına salon hakkı satın '
           || 'almışsa geçerlidir.');
  end if;
  if coalesce(v_guest_charter,false) then
    return jsonb_build_object('blocked', true,
      'note', 'Senin seferin charter. Havayolu salonlarında charter yolcusu misafir '
           || 'olarak da kabul edilmez. Kart ağı (Priority Pass / LoungeKey / '
           || 'DragonPass) kaynaklı bir ilan ararsan giriş mümkün olabilir.');
  end if;
  if a.is_charter is null then
    return jsonb_build_object('blocked', false,
      'note', 'Seferin tarifeli mi charter mi belirtilmemiş. Charter seferde havayolu '
           || 'salonu hakkı olmaz; emin değilsen biletini kontrol et.');
  end if;
  return jsonb_build_object('blocked', false, 'note', null);
end $function$;

-- create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)
create or replace function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text, p_carrier text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_cap int; v_ok boolean; v_id uuid; v_conflict boolean;
  v_vis availability_visibility; v_min_trust smallint := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

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

  -- 040: MVP'nin all/trusted/hidden -> enum + eşik
  case lower(coalesce(p_visibility,'all'))
    when 'all'         then v_vis := 'Public';      v_min_trust := 0;
    when 'trusted'     then v_vis := 'Public';      v_min_trust := 55;
    when 'hidden'      then v_vis := 'Hidden';      v_min_trust := 0;
    when 'connections' then v_vis := 'Connections'; v_min_trust := 0;
    else raise exception 'bad_visibility';
  end case;

  insert into availabilities (
    host_id, lounge_id, airport_code, avail_date, time_from, time_to,
    slots, filled, active, visibility, flight_number, min_trust, carrier
  )
  values (
    v_uid, p_lounge_id, p_airport, p_date, p_from, p_to,
    p_slots, 0, true, v_vis, nullif(trim(p_flight),''), v_min_trust,
    -- v158: tasiyici artik ACIK veri — secilmediyse ucus no onekinden turetilir.
    nullif(upper(coalesce(nullif(trim(p_carrier),''), substring(trim(coalesce(p_flight,'')) from '^[A-Za-z]+'))),'')
  )
  returning id into v_id;

  -- 055: ilan açmak = host olmak (rol)
  update users set role = 'host' where id = v_uid and role <> 'host';

  -- YENİ (074): ilan açmak = APP HOST'U olmak (görünürlük).
  -- Sıra önemli: is_staff hâlâ true iken profil düzeltilir (işaret olarak
  -- kullanılıyor), SONRA bayrak temizlenir. Kullanıcının kendi kapattığı
  -- show_on_discovery'ye (staff değilse) dokunulmaz.
  update profiles p set show_on_discovery = true
   where p.user_id = v_uid
     and p.show_on_discovery = false
     and exists (select 1 from users u where u.id = v_uid and u.is_staff = true);
  update users set is_staff = false where id = v_uid and is_staff = true;

  -- 056: ARZ-TALEP EŞLEŞTİRME — eşleşen misafirlere "host geldi" bildirimi
  -- (SELECT içindeki literal enum'a OTOMATİK çevrilmez -> 071 cast'i korunur)
  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  select distinct vs.user_id, 'requests'::notif_category,
         'Havalimanında host var! ✦',
         'Seni bekleyen bir host ' || p_airport || ' için ilan açtı. Hemen başvur.',
         v_id, 'availability'
    from visits vs
    join users gu on gu.id = vs.user_id
   where vs.airport_code = p_airport
     and vs.visit_date = p_date
     and vs.time_from < p_to and p_from < vs.time_to
     and vs.user_id <> v_uid
     and coalesce(gu.is_staff,false) = false
     and gu.deleted_at is null;

  return jsonb_build_object('ok', true, 'id', v_id, 'visibility', v_vis, 'min_trust', v_min_trust);
end $function$;

-- discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date)
create or replace function public.discover_availabilities_ham(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text, host_gender text, host_langs text[], guest_policy text, guest_allowance integer, family_allowed boolean, decision_note text, blocks_request boolean, block_reason text, carrier_note text, same_sector boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
      select q.* from public.discover_availabilities_prerank(p_airport, p_sector, p_flight, p_date) q
       order by (coalesce(q.match_score,0) + public.host_rank_bonus(q.host_id)) desc,
                q.avail_date, q.time_from
    $function$;

-- host_requests()
create or replace function public.host_requests()
 RETURNS TABLE(id uuid, guest_id uuid, avail_id uuid, status text, intro_message text, created_at timestamp with time zone, guest_name text, guest_photo text, guest_profession text, guest_score integer, guest_badge text, guest_id_verified boolean, guest_phone_verified boolean, guest_linkedin boolean, guest_sessions integer, guest_rating numeric, guest_rating_count integer, same_flight boolean, same_purpose boolean, guest_fit integer, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with base as (
    select r.id, r.guest_id, r.avail_id, r.status::text as st, r.intro_message, r.created_at,
           a.lounge_name, a.avail_date, a.time_from, a.time_to,
           a.flight_number as host_flight, a.airport_code,
           p.name as gname, p.profession as gprof, p.bio as gbio,
           p.photo_url, coalesce(p.photo_connections_only,false) as photo_priv,
           p.linkedin_url, p.linkedin_verified,
           coalesce(ts.score,0) as gscore, ts.badge as gbadge,
           coalesce(v.id_verified,false) as gid,
           coalesce(v.phone_verified,false) as gphone,
           (select count(*)::int from sessions s2 join requests r2 on r2.id = s2.request_id
             where s2.status='completed' and (r2.guest_id = r.guest_id or r2.host_id = r.guest_id)) as gsessions,
           (select avg(score)::numeric from ratings where rated_id = r.guest_id) as grating,
           (select count(*)::int from ratings where rated_id = r.guest_id) as grating_n,
           -- misafirin ayni havalimani/zamandaki seyahati
           (select vs.flight_number from visits vs
             where vs.user_id = r.guest_id and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date
               and vs.time_from < a.time_to and a.time_from < vs.time_to
             limit 1) as gflight,
           (select vs.purpose from visits vs
             where vs.user_id = r.guest_id and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date
               and vs.time_from < a.time_to and a.time_from < vs.time_to
             limit 1) as gpurpose,
           -- host'un kendi seyahat amaci (ayni amac karsilastirmasi icin)
           (select vs.purpose from visits vs
             where vs.user_id = v_uid and vs.airport_code = a.airport_code
               and vs.visit_date = a.avail_date limit 1) as hpurpose,
           (select p2.profession from profiles p2 where p2.user_id = v_uid) as hprof
      from requests r
      join availabilities a on a.id = r.avail_id
      join profiles p on p.user_id = r.guest_id
      left join trust_scores ts on ts.user_id = r.guest_id
      left join verifications v on v.user_id = r.guest_id
     where r.host_id = v_uid
       and r.status in ('pending','accepted')
  )
  select b.id, b.guest_id, b.avail_id, b.st, b.intro_message, b.created_at,
         b.gname,
         case when b.photo_url is not null and (
                b.photo_priv = false
                or exists (select 1 from connection_requests cr where cr.status='accepted'
                           and ((cr.from_id=v_uid and cr.to_id=b.guest_id)
                             or (cr.from_id=b.guest_id and cr.to_id=v_uid)))
              ) then b.photo_url else null end,
         b.gprof, b.gscore, b.gbadge, b.gid, b.gphone,
         (b.linkedin_url is not null and b.linkedin_url <> ''),
         b.gsessions, b.grating, b.grating_n,
         (b.gflight is not null and b.host_flight is not null
          and upper(b.gflight) = upper(b.host_flight)) as same_flight,
         (b.gpurpose is not null and b.hpurpose is not null
          and b.gpurpose = b.hpurpose) as same_purpose,
         -- guest_fit: MISAFIRIN BU ILANA uyumu (30-99)
         least(99, greatest(30,
           30
           + (case when b.gscore >= 70 then 18 when b.gscore >= 50 then 10 else 0 end)
           + (case when b.gid then 14 else 0 end)
           + (case when b.gphone then 6 else 0 end)
           + (case when b.gflight is not null and b.host_flight is not null
                    and upper(b.gflight) = upper(b.host_flight) then 12 else 0 end)
           + (case when b.gpurpose is not null and b.hpurpose is not null
                    and b.gpurpose = b.hpurpose then 8 else 0 end)
           + (case when b.hprof is not null and b.gprof is not null
                    and (b.gprof ilike '%'||b.hprof||'%' or b.hprof ilike '%'||b.gprof||'%') then 8 else 0 end)
           + (case when b.gsessions >= 3 then 8 when b.gsessions >= 1 then 4 else 0 end)
           + (case when coalesce(b.grating_n,0) >= 3 and b.grating >= 4.5 then 8
                   when coalesce(b.grating_n,0) >= 3 and b.grating >= 4.0 then 4 else 0 end)
           + (case when length(coalesce(b.gbio,'')) >= 40 then 4 else 0 end)
         ))::int as guest_fit,
         b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.gflight as flight_number                                     -- 050/#26: misafirin uçuşu
  from base b
  order by coalesce(b.st = 'pending', false) desc, guest_fit desc, b.created_at desc;
end $function$;

-- request_credit_cost(p_user uuid, p_avail uuid)
create or replace function public.request_credit_cost(p_user uuid, p_avail uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_ham int;
begin
  -- Önce eski kural aynen çalışır: Konsiyerj ayrıcalığı + soğuk ağ indirimi.
  v_ham := public.request_credit_cost_ham(p_user, p_avail);
  if coalesce(v_ham, 1) = 0 then return 0; end if;

  -- Sonra 252: ilan belliyse ve o ilanın sahibine ANLIK ulaşamıyorsak,
  -- zamana bağlı bir eşleşmeyi satmıyoruz — bedel almıyoruz.
  -- 🔴 `ilan_ulasilabilir_mi` DEĞİL. Para kararı kanıt ister: yalnız host'un
  -- kendi cihazı bize "bildirim kapalı" dediyse bedeli düşürüyoruz.
  -- (Gerekçesi §2b'de; hatayı e2e nöbetçisi buldu.)
  if p_avail is not null and exists (
       select 1 from availabilities a
        where a.id = p_avail and public.kesin_ulasilamaz(a.host_id)) then
    return 0;
  end if;
  return v_ham;
end $function$;

-- trg_soru_bildirimi_host()
create or replace function public.trg_soru_bildirimi_host()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_salon text; v_b text; v_g text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.id = new.avail_id;

  select value #>> '{}' into v_b from beta_settings where key='soru_bildirim_baslik_tr';
  select value #>> '{}' into v_g from beta_settings where key='soru_bildirim_govde_tr';
  if v_b is null or v_g is null then return new; end if;

  update notifications
     set title = v_b,
         body  = replace(v_g, '{salon}', coalesce(v_salon, 'bu'))
   where user_id = new.to_id and ref_type = 'connection' and ref_id = new.id;

  return new;
end $function$;

-- trg_soru_metni()
create or replace function public.trg_soru_metni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_salon text; v_metin text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.id = new.avail_id;

  select value #>> '{}' into v_metin from beta_settings where key = 'soru_intro_tr';
  if v_metin is null then return new; end if;

  new.intro := left(replace(v_metin, '{salon}', coalesce(v_salon, 'bu')), 400);
  return new;
end $function$;

-- ── 2 · YETKİLER ────────────────────────────────────────────────────────────
-- bo_plan_hediyeleri(p_durum text) → anon kapalı · authenticated kapalı
revoke execute on function public.bo_plan_hediyeleri(p_durum text) from public, anon, authenticated;
grant execute on function public.bo_plan_hediyeleri(p_durum text) to service_role;

-- card_advice_for_airport(p_airport text) → anon kapalı · authenticated açık
revoke execute on function public.card_advice_for_airport(p_airport text) from public, anon, authenticated;
grant execute on function public.card_advice_for_airport(p_airport text) to service_role;
grant execute on function public.card_advice_for_airport(p_airport text) to authenticated;

-- charter_note(p_avail_id uuid) → anon kapalı · authenticated açık
revoke execute on function public.charter_note(p_avail_id uuid) from public, anon, authenticated;
grant execute on function public.charter_note(p_avail_id uuid) to service_role;
grant execute on function public.charter_note(p_avail_id uuid) to authenticated;

-- create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) → anon kapalı · authenticated açık
revoke execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) from public, anon, authenticated;
grant execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) to service_role;
grant execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) to authenticated;

-- discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date) → anon kapalı · authenticated açık
revoke execute on function public.discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date) from public, anon, authenticated;
grant execute on function public.discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date) to service_role;
grant execute on function public.discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date) to authenticated;

-- host_requests() → anon kapalı · authenticated açık
revoke execute on function public.host_requests() from public, anon, authenticated;
grant execute on function public.host_requests() to service_role;
grant execute on function public.host_requests() to authenticated;

-- request_credit_cost(p_user uuid, p_avail uuid) → anon kapalı · authenticated kapalı
revoke execute on function public.request_credit_cost(p_user uuid, p_avail uuid) from public, anon, authenticated;
grant execute on function public.request_credit_cost(p_user uuid, p_avail uuid) to service_role;

-- trg_soru_bildirimi_host() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_soru_bildirimi_host() from public, anon, authenticated;
grant execute on function public.trg_soru_bildirimi_host() to service_role;

-- trg_soru_metni() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_soru_metni() from public, anon, authenticated;
grant execute on function public.trg_soru_metni() to service_role;

-- istegin_acik_oturumu_var_mi(p_req uuid) → anon kapalı · authenticated açık
revoke execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) from public, anon, authenticated;
grant execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) to service_role;
grant execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) to authenticated;

-- plan_kredisi_kalan(p_user uuid) → anon kapalı · authenticated açık
revoke execute on function public.plan_kredisi_kalan(p_user uuid) from public, anon, authenticated;
grant execute on function public.plan_kredisi_kalan(p_user uuid) to service_role;
grant execute on function public.plan_kredisi_kalan(p_user uuid) to authenticated;

-- plan_ucretli(p_plan text) → anon kapalı · authenticated açık
revoke execute on function public.plan_ucretli(p_plan text) from public, anon, authenticated;
grant execute on function public.plan_ucretli(p_plan text) to service_role;
grant execute on function public.plan_ucretli(p_plan text) to authenticated;

-- profil_dogrulandi_hesapla(p_user uuid) → anon kapalı · authenticated açık
revoke execute on function public.profil_dogrulandi_hesapla(p_user uuid) from public, anon, authenticated;
grant execute on function public.profil_dogrulandi_hesapla(p_user uuid) to service_role;
grant execute on function public.profil_dogrulandi_hesapla(p_user uuid) to authenticated;

-- push_kanali(p_category notif_category) → anon kapalı · authenticated açık
revoke execute on function public.push_kanali(p_category notif_category) from public, anon, authenticated;
grant execute on function public.push_kanali(p_category notif_category) to service_role;
grant execute on function public.push_kanali(p_category notif_category) to authenticated;

-- push_kanali(p_category text) → anon kapalı · authenticated açık
revoke execute on function public.push_kanali(p_category text) from public, anon, authenticated;
grant execute on function public.push_kanali(p_category text) to service_role;
grant execute on function public.push_kanali(p_category text) to authenticated;

-- seed_test_hesabi(p_email text) → anon kapalı · authenticated açık
revoke execute on function public.seed_test_hesabi(p_email text) from public, anon, authenticated;
grant execute on function public.seed_test_hesabi(p_email text) to service_role;
grant execute on function public.seed_test_hesabi(p_email text) to authenticated;

-- sogu_baslangic_ozeti(p_airport text) → anon kapalı · authenticated açık
revoke execute on function public.sogu_baslangic_ozeti(p_airport text) from public, anon, authenticated;
grant execute on function public.sogu_baslangic_ozeti(p_airport text) to service_role;
grant execute on function public.sogu_baslangic_ozeti(p_airport text) to authenticated;

-- telefon_kanonik(p_phone text) → anon kapalı · authenticated açık
revoke execute on function public.telefon_kanonik(p_phone text) from public, anon, authenticated;
grant execute on function public.telefon_kanonik(p_phone text) to service_role;
grant execute on function public.telefon_kanonik(p_phone text) to authenticated;

-- trg_bakiye_negatife_dusemez() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_bakiye_negatife_dusemez() from public, anon, authenticated;
grant execute on function public.trg_bakiye_negatife_dusemez() to service_role;

-- trg_cinsiyet_kilidi() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_cinsiyet_kilidi() from public, anon, authenticated;
grant execute on function public.trg_cinsiyet_kilidi() to service_role;

-- trg_huni_istek() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_huni_istek() from public, anon, authenticated;
grant execute on function public.trg_huni_istek() to service_role;

-- trg_huni_oturum() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_huni_oturum() from public, anon, authenticated;
grant execute on function public.trg_huni_oturum() to service_role;

-- trg_iade_tutulani_asamaz() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_iade_tutulani_asamaz() from public, anon, authenticated;
grant execute on function public.trg_iade_tutulani_asamaz() to service_role;

-- trg_kisit_gozden_gecir() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_kisit_gozden_gecir() from public, anon, authenticated;
grant execute on function public.trg_kisit_gozden_gecir() to service_role;

-- trg_kredi_paketi_kapisi() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_kredi_paketi_kapisi() from public, anon, authenticated;
grant execute on function public.trg_kredi_paketi_kapisi() to service_role;

-- trg_mesaj_bildirimi() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_mesaj_bildirimi() from public, anon, authenticated;
grant execute on function public.trg_mesaj_bildirimi() to service_role;

-- trg_puan_negatife_dusemez() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_puan_negatife_dusemez() from public, anon, authenticated;
grant execute on function public.trg_puan_negatife_dusemez() to service_role;

-- trg_sohbet_suzgeci() → anon kapalı · authenticated kapalı
revoke execute on function public.trg_sohbet_suzgeci() from public, anon, authenticated;
grant execute on function public.trg_sohbet_suzgeci() to service_role;

-- tutma_sebepleri() → anon kapalı · authenticated açık
revoke execute on function public.tutma_sebepleri() from public, anon, authenticated;
grant execute on function public.tutma_sebepleri() to service_role;
grant execute on function public.tutma_sebepleri() to authenticated;

-- tutma_varsayim_esigi() → anon kapalı · authenticated açık
revoke execute on function public.tutma_varsayim_esigi() from public, anon, authenticated;
grant execute on function public.tutma_varsayim_esigi() to service_role;
grant execute on function public.tutma_varsayim_esigi() to authenticated;

-- tutulan_kredi(p_req uuid) → anon kapalı · authenticated açık
revoke execute on function public.tutulan_kredi(p_req uuid) from public, anon, authenticated;
grant execute on function public.tutulan_kredi(p_req uuid) to service_role;
grant execute on function public.tutulan_kredi(p_req uuid) to authenticated;

-- ucus_hatti(p_origin text, p_dest text) → anon kapalı · authenticated açık
revoke execute on function public.ucus_hatti(p_origin text, p_dest text) from public, anon, authenticated;
grant execute on function public.ucus_hatti(p_origin text, p_dest text) to service_role;
grant execute on function public.ucus_hatti(p_origin text, p_dest text) to authenticated;

-- yerel_an(p_date date, p_time time without time zone, p_airport text) → anon açık · authenticated açık
revoke execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) to service_role;
grant execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) to anon;
grant execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) to authenticated;

-- yerel_gun(p_airport text) → anon açık · authenticated açık
revoke execute on function public.yerel_gun(p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_gun(p_airport text) to service_role;
grant execute on function public.yerel_gun(p_airport text) to anon;
grant execute on function public.yerel_gun(p_airport text) to authenticated;

-- yerel_saat(p_airport text) → anon açık · authenticated açık
revoke execute on function public.yerel_saat(p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_saat(p_airport text) to service_role;
grant execute on function public.yerel_saat(p_airport text) to anon;
grant execute on function public.yerel_saat(p_airport text) to authenticated;

-- yonetici_kapisi() → anon kapalı · authenticated kapalı
revoke execute on function public.yonetici_kapisi() from public, anon, authenticated;
grant execute on function public.yonetici_kapisi() to service_role;

-- ── 3 · connection_test: istemci yazması kapalı ──────────────────────────────
do $ct348$
begin
  if to_regclass('public.connection_test') is not null then
    execute 'revoke insert, update, delete on public.connection_test from anon, authenticated';
    execute 'drop policy if exists "authenticated users can write" on public.connection_test';
    raise notice '348: connection_test istemci yazmasi kapatildi (tablo duruyor).';
  end if;
end $ct348$;

-- ── 4 · kurulum_imzasi_var istemciye kapalı ──────────────────────────────────
do $ki348$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'kurulum_imzasi_var' loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.f);
  end loop;
end $ki348$;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'plan_kredisi_kalan kullaniciya acik' as kontrol,
       has_function_privilege('authenticated', 'public.plan_kredisi_kalan(uuid)', 'execute') as tamam
union all select 'tetikleyici fonksiyonlari istemciye kapali',
       not has_function_privilege('anon', 'public.trg_bakiye_negatife_dusemez()', 'execute')
   and not has_function_privilege('authenticated', 'public.trg_mesaj_bildirimi()', 'execute')
union all select 'seed_test_hesabi girissize kapali',
       not has_function_privilege('anon', 'public.seed_test_hesabi(text)', 'execute')
union all select 'connection_test istemci yazamaz',
       to_regclass('public.connection_test') is null
       or not has_table_privilege('authenticated', 'public.connection_test', 'insert')
union all select 'dokuz govde dosyalarla ayni', (select count(*) from (values ('bo_plan_hediyeleri','p_durum text','5b1cb6016416d0283caa27d469e271e6'), ('card_advice_for_airport','p_airport text','be48466bf6645b283901ddc6a37f0671'), ('charter_note','p_avail_id uuid','41c6553407d7e2764b12514d03f03ee1'), ('create_availability','p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text','423b4191c603523939f8cff4b6b92329'), ('discover_availabilities_ham','p_airport text, p_sector text, p_flight text, p_date date','5bdac4e371b191c2bc780bd3707a08d2'), ('host_requests','','fe23603a880d2eb1f9934b37d854ba21'), ('request_credit_cost','p_user uuid, p_avail uuid','cf212b4ec7ecc582e53ea35b6480284b'), ('trg_soru_bildirimi_host','','7be8dad318e40dfe2fd602007e6e5195'), ('trg_soru_metni','','36d7578ec8e63da5fad0302725bcb798')) b(ad, arg, iz) join pg_proc p on p.proname = b.ad and pg_get_function_identity_arguments(p.oid) = b.arg join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public' where md5(regexp_replace(pg_get_functiondef(p.oid), '\s+', '', 'g')) = b.iz) = 9;
-- Beklenen: 5 satır, hepsi tamam = true.
