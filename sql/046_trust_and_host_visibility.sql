-- ============================================================
-- 046 — GÜVEN PUANI TAVANI, ULAŞILAMAZ ROZET, ve HOST'UN KÖR NOKTASI
--
-- 045'ten sonra. ÖNCE 046a_PRE_drop.sql.
--
-- Gokberk sordu: "Trust score benim profil doluluğum, lounge points
-- app'i kullandıkça kazandığım puan mı? Beni bir ilana başvurduğumda
-- öne çıkartan faktörler neler?"
--
-- Kodu okuyunca ÜÇ CİDDİ SORUN çıktı.
--
-- ============================================================
-- 🔴 1. HOST, MİSAFİR HAKKINDA HİÇBİR ŞEY GÖRMÜYOR
-- ============================================================
-- RequestsPanel'in sorgusu:
--   requests.select("*").eq("host_id", uid).order("created_at" desc)
--   + profiles.select("user_id, name")
--
-- Host bir isteği kabul/red ederken gördüğü TEK ŞEY:
--   · misafirin ADI
--   · tanıtım mesajı
--   · sıra: kim önce başvurduysa üstte
--
-- GÖRMEDİĞİ: güven puanı · rozet · kimlik doğrulanmış mı ·
-- meslek · fotoğraf · kaç oturum tamamlamış · puanı kaç.
--
-- Yani "trust-first" mimarisinin TAMAMI — escrow, doğrulama,
-- güven puanı — kabul/red kararını veren kişiye ULAŞMIYOR.
-- Bir yabancıyı lounge'una alacak insan, elindeki tek bilgiyle
-- (bir isim ve iki cümle) karar veriyor.
--
-- Bu, ürünün en pahalı boşluğu: güven altyapısını kurduk ama
-- güvenin kullanılacağı TEK ANDA göstermiyoruz.
--
-- ============================================================
-- 🔴 2. requests.match_score TERS ANLAMDA
-- ============================================================
-- create_request (026) şunu yazıyor:
--   select match_score from discover_availabilities(...) where id = p_avail_id
-- Bu, MİSAFİRİN İLANI ne kadar beğendiği. Host'un misafiri
-- değerlendirmesi DEĞİL. Host'a gösterilseydi yanlış şeyi
-- gösterirdi. Bu yüzden host_requests AYRI bir "guest_fit"
-- hesaplıyor: misafirin bu ilana ne kadar uyduğu.
--
-- ============================================================
-- 🔴 3. "High Trust Guest" ROZETİ KAZANILAMAZ
-- ============================================================
-- recompute_trust'ın (033) verebileceği tüm puanlar:
--   email 10 · phone 10 · id 18 · linkedin 8 · profession 6 · bio 6
--   · host_access 8 (yalnız host)
-- GUEST tavanı = 58 · HOST tavanı = 66. Tavan 100 yazıyor ama
-- kimse 66'nın üstüne çıkamaz.
-- recompute_badge ise: v_score >= 70 -> 'High Trust Guest'
-- 🔴 70'e ULAŞMAK MATEMATİKSEL OLARAK İMKANSIZ. O rozet ölü kod.
-- Ayrıca 040'ın min_trust=55 eşiği, guest tavanının (58) hemen
-- altında — yani "yalnız güvenilir misafirler" pratikte
-- "kimliğini doğrulamış VE profilini tamamen doldurmuş" demek.
--
-- DAHA DERİN SORUN: güven puanı DAVRANIŞI HİÇ ÖLÇMÜYOR.
-- 10 oturumu 5 yıldızla tamamlamış biri ile hiç oturumu olmayan
-- birinin puanı AYNI. "Güven" formu doldurmakla kazanılıyor,
-- güvenilir davranmakla değil. Bir güven puanı için bu yanlış.
--
-- ÇÖZÜM: davranış bileşenleri ekleniyor (oturum + puan ortalaması).
-- Böylece hem 70 ulaşılabilir oluyor hem de puan gerçekten
-- "bu kişi güvenilir mi" sorusunu cevaplıyor.
--   GUEST yeni tavan: 58 + 14 + 10 = 82
--   HOST  yeni tavan: 66 + 14 + 10 = 90
-- 100'e çıkarmıyoruz: 100 "kusursuz" demek olurdu ve güven
-- hiçbir zaman kusursuz değildir — üst uçta yer bırakmak dürüst.
-- ============================================================


-- ============================================================
-- 1. recompute_trust — 033'ün gövdesi BİREBİR korunuyor,
--    SONUNA iki davranış bileşeni ekleniyor.
-- ============================================================
create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
  v_sessions int; v_rating numeric; v_rating_n int;
begin
  select * into v_p from profiles where user_id = p_user;
  select * into v_v from verifications where user_id = p_user;

  -- ---- 033'ten birebir: KİMLİK bileşenleri ----
  v_c := v_c || '{"email":10}'::jsonb;
  if coalesce(v_v.phone_verified,false) then v_c := v_c || '{"phone":10}'::jsonb; end if;
  if coalesce(v_v.id_verified,false)    then v_c := v_c || '{"id":18}'::jsonb; end if;

  if coalesce(v_p.linkedin_verified, false) then
    v_c := v_c || '{"linkedin":8}'::jsonb;
  elsif coalesce(nullif(trim(v_p.linkedin_url),''), '') <> '' then
    v_c := v_c || '{"linkedin":4}'::jsonb;
  end if;

  if coalesce(nullif(trim(v_p.profession),''), '') <> '' then
    v_c := v_c || '{"profession":6}'::jsonb;
  end if;
  if length(coalesce(trim(v_p.bio),'')) >= 40 then
    v_c := v_c || '{"bio":6}'::jsonb;
  end if;
  if v_p.guest_capacity is not null then
    v_c := v_c || '{"host_access":8}'::jsonb;
  end if;

  -- ============================================================
  -- YENİ (046): DAVRANIŞ bileşenleri
  --
  -- Neden: güven puanı bugüne kadar yalnızca FORM DOLDURMAYI
  -- ölçüyordu. 10 oturumu kusursuz tamamlamış biri ile hiç
  -- oturumu olmayan birinin puanı aynıydı. Bir güven puanı için
  -- bu yanlış — güven, davranışla kazanılır.
  -- ============================================================
  select count(*) into v_sessions
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and (r.guest_id = p_user or r.host_id = p_user);

  if v_sessions >= 10 then v_c := v_c || '{"sessions":14}'::jsonb;
  elsif v_sessions >= 3 then v_c := v_c || '{"sessions":10}'::jsonb;
  elsif v_sessions >= 1 then v_c := v_c || '{"sessions":6}'::jsonb;
  end if;

  -- Aldığı puanların ortalaması (en az 3 puan — 1 kişinin 5 yıldızı kanıt değil)
  select avg(score)::numeric, count(*) into v_rating, v_rating_n
    from ratings where rated_id = p_user;

  if coalesce(v_rating_n,0) >= 3 then
    if v_rating >= 4.5 then v_c := v_c || '{"rating":10}'::jsonb;
    elsif v_rating >= 4.0 then v_c := v_c || '{"rating":6}'::jsonb;
    elsif v_rating >= 3.0 then v_c := v_c || '{"rating":2}'::jsonb;
    -- 3.0 altı: puan YOK (ceza da yok — düşük puan zaten rozeti düşürür)
    end if;
  end if;

  select coalesce(sum(value::int),0) into v_score from jsonb_each_text(v_c);
  v_score := least(100, greatest(0, v_score));

  insert into trust_scores (user_id, score, components, updated_at)
  values (p_user, v_score, v_c, now())
  on conflict (user_id) do update
    set score = excluded.score, components = excluded.components, updated_at = now();

  return v_score;
end $$;


-- ============================================================
-- 2. recompute_badge — 033'ün gövdesi korunuyor, guest eşiği
--    ULAŞILABİLİR hale getiriliyor.
--
-- Eski: v_score >= 70 (guest tavanı 58'ken — imkansız)
-- Yeni: 046 sonrası guest tavanı 82, yani 70 gerçekten
--       "kimliğini doğrulamış + profili tam + oturum geçmişi
--        olan + iyi puan almış" demek. Rozet artık bir şey ifade
--       ediyor ve kazanılabiliyor.
-- ============================================================
create or replace function public.recompute_badge(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_host_sessions int; v_guest_sessions int; v_score int; v_badge text;
begin
  select role into v_role from users where id = p_user;
  select coalesce(score,0) into v_score from trust_scores where user_id = p_user;

  select count(*) into v_host_sessions
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and r.host_id = p_user;
  select count(*) into v_guest_sessions
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and r.guest_id = p_user;

  if v_role = 'host' then
    v_badge := case
      when v_host_sessions >= 20 then 'Elite Host'
      when v_host_sessions >= 5  then 'Trusted Host'
      when v_host_sessions >= 1  then 'Verified Host'
      else 'Basic Verified' end;
  else
    v_badge := case
      when v_score >= 70 then 'High Trust Guest'      -- artik ULASILABILIR (tavan 82)
      when v_guest_sessions >= 1 then 'Verified Guest'
      else 'Basic Verified' end;
  end if;

  update trust_scores set badge = v_badge, updated_at = now() where user_id = p_user;
  return v_badge;
end $$;


-- ============================================================
-- 3. host_requests — HOST'UN KÖR NOKTASINI KAPATIR
--
-- Host artık kabul/red kararını verirken misafir hakkında
-- gerçek bilgi görüyor. guest_fit = misafirin BU ilana uyumu
-- (requests.match_score'un tersi değil, TAMAMEN farklı bir şey).
--
-- guest_fit bileşenleri — hepsi host'un umursadığı şeyler:
--   güven puanı · kimlik · aynı uçuş · aynı seyahat amacı ·
--   meslek yakınlığı · oturum geçmişi · aldığı puan · profil doluluğu
--
-- GİZLİLİK: fotoğraf yalnız photo_connections_only kapalıysa veya
-- bağlantıysanız gösterilir (discover_availabilities ile aynı kural).
-- ============================================================
create or replace function public.host_requests()
returns table (
  id uuid, guest_id uuid, avail_id uuid, status text, intro_message text,
  created_at timestamptz,
  guest_name text, guest_photo text, guest_profession text,
  guest_score int, guest_badge text, guest_id_verified boolean,
  guest_phone_verified boolean, guest_linkedin boolean,
  guest_sessions int, guest_rating numeric, guest_rating_count int,
  same_flight boolean, same_purpose boolean, guest_fit int,
  lounge_name text, avail_date date, time_from time, time_to time
)
language plpgsql security definer set search_path = public as $$
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
         b.lounge_name, b.avail_date, b.time_from, b.time_to
  from base b
  order by coalesce(b.st = 'pending', false) desc, guest_fit desc, b.created_at desc;
end $$;


-- ============================================================
-- 4. Mevcut kullanıcıların puanlarını yeniden hesapla
--    (davranış bileşenleri eklendiği için herkesinki değişebilir)
-- ============================================================
do $$
declare r record;
begin
  for r in select user_id from trust_scores loop
    begin
      perform recompute_trust(r.user_id);
      perform recompute_badge(r.user_id);
    exception when others then null;   -- biri patlarsa digerleri devam etsin
    end;
  end loop;
end $$;


grant execute on function public.host_requests() to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select 'host_requests var mi' as kontrol,
  case when exists (select 1 from pg_proc where proname='host_requests') then '✓ OK' else '🔴 YOK' end as sonuc
union all
select 'trust davranisi olcuyor mu',
  case when (select prosrc from pg_proc where proname='recompute_trust' limit 1) like '%sessions%'
  then '✓ OK' else '🔴 HAYIR' end
union all
select 'en yuksek guven puani',
  coalesce((select max(score)::text from trust_scores), '0')
union all
select 'High Trust Guest rozetli kisi',
  (select count(*)::text from trust_scores where badge = 'High Trust Guest');
