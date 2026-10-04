-- ============================================================================
-- 317 · KEŞFET ÖLÇEK DÜZELTMESİ  (4 Ekim 2026)
--
-- ÖLÇÜM (yük testi · ll_yuk: 50.076 üye · 30.088 ilan · 145.743 istek ·
-- 600.256 bildirim; fonksiyon başı süre pg_stat_xact_user_functions ile):
--
--   discover_availabilities (filtresiz)  39.650 ms   → 317 sonrası ~1.270 ms
--   kesfet_ozeti(14)                     37.270 ms   → 317 sonrası   ~430 ms
--   eşzamanlı 50 kullanıcıda kesfet_ozeti p50 10.700 ms idi (317 ilk hali) → sayım kipi
--
--   Kök: discover_availabilities_base her ilan için is_visible() →
--   test_hesabi_gizli_mi() çağırıyordu (30.071 çağrı · 26,5 sn). İkisi de
--   SECURITY DEFINER + SET search_path → planlayıcı satır içine alamıyor,
--   çağrı başı sabit maliyet. Ayrıca host başına tamamlanan oturum sayımı
--   ilan başına host'un TÜM isteklerini tarıyordu; engel filtresi VEYA'lı
--   tek koşul olduğu için hash'lenemiyordu.
--
-- 🔴 DOĞRULUK HATASI DA VAR: kesfet_ozeti havalimanı sayılarını
-- discover_availabilities'ten (LIMIT 100 + ilan başına erişim kararı) türetiyordu.
-- 100'den fazla görünür ilan olduğunda sayılar EKSİK çıkardı (ölçek dünyasında
-- 14 havalimanı görünüyordu, gerçekte 40).
--
-- DÜZELTME (gövdeler CANLI tanımın üstüne eklendi, yeniden yazılmadı):
--  1) base: izleyici tarafı (bayrak · test/personel · test_gorunurlugu) bir kez;
--     host tarafı satır içinde AYNI kuralla. is_visible() DEĞİŞİRSE BURASI DA.
--  2) base: oturum sayımı 3'te durur (puan yalnız >= 3'e bakıyor), indeksli.
--  3) base: engel filtresi iki ayrı NOT EXISTS (blocks_pkey).
--  4) base: LIMIT 100 varsayılan; kesfet_ozeti işlem-yerel 'll.kesif_limit' ile
--     sınırı kaldırır ve doğrudan base'i sayar (erişim kararı katmanı yok).
--  5) SAYIM KİPİ: kesfet_ozeti çağırınca kişiye özel pahalı sütunlar (eşleşme
--     puanı girdileri) hesaplanmaz, tarih 'll.kesif_son_gun' ile sınırlanır.
--     Görünürlük kuralları AYNI WHERE'den geçer (kural kopyası yok).
-- EŞDEĞERLİK (yerel dünya, 82 izleyici): normal kip eski gövdeyle 246+164
--     karşılaştırma 0 fark; kesfet_ozeti tam hesaplı referansla 164 karşılaştırma 0 fark.
-- Supabase SQL Editor: iki CREATE OR REPLACE + doğrulama; tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.discover_availabilities_base(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text, host_gender text, host_langs text[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_langs text[]; v_prof text; v_sessions int; v_rated int; v_my_trust int;
  v_test_gorur boolean; v_staff boolean; v_limit int; v_sayim boolean; v_son date;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false), pr.languages, pr.profession
    into v_female, v_safe, v_langs, v_prof
    from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status='completed' and (r.guest_id=v_uid or r.host_id=v_uid);
  select count(*) into v_rated from ratings where rater_id = v_uid;
  select coalesce(score,0) into v_my_trust from trust_scores where user_id = v_uid;
  v_my_trust := coalesce(v_my_trust, 0);

  -- 317 · İZLEYİCİ TARAFI BİR KEZ. `is_visible(a.host_id)` her ilan için
  -- test_hesabi_gizli_mi'yi çağırıyordu (SECURITY DEFINER + SET → satır içine
  -- alınamaz, çağrı başı ~0,9 ms). Ölçek dünyasında (30.000 ilan) Keşfet 39,6 sn;
  -- bunun 26,5 sn'si bu çağrıydı. İzleyiciye ait yarısı (bayrak · test/personel ·
  -- test_gorunurlugu) satırdan bağımsız: burada bir kez hesaplanır, host tarafı
  -- satır içinde aynı kuralla okunur. is_visible DEĞİŞİRSE BURASI DA DEĞİŞİR
  -- (drift_check: 'is_visible ile eş').
  select coalesce(x.is_staff, false), public.seed_test_hesabi(x.email)
    into v_staff, v_test_gorur from users x where x.id = v_uid;
  v_staff := coalesce(v_staff, false);
  v_test_gorur := coalesce(v_test_gorur, false) or v_staff
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = v_uid);
  -- 317 · Keşfet listesi 100 ilanla sınırlı; kesfet_ozeti TÜM görünür ilanları
  -- saymak zorunda (yoksa 100'ü aşınca havalimanı sayıları eksik çıkar).
  v_limit := coalesce(nullif(current_setting('ll.kesif_limit', true), '')::int, 100);
  -- 317 · SAYIM KİPİ (yalnız kesfet_ozeti açar): görünürlük kuralları AYNI WHERE'den geçer,
  -- ama kişiye özel pahalı sütunlar (eşleşme puanı girdileri) hesaplanmaz ve tarih aralığı
  -- sınırlanır. Yük testi: 50 eşzamanlı kullanıcıda kesfet_ozeti p50 10,7 sn idi.
  v_sayim := v_limit > 100000;
  v_son := nullif(current_setting('ll.kesif_son_gun', true), '')::date;

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, coalesce(ts.score,0) as hs, p.profession as hp,
      p.languages as hlangs, hu.gender as hgender,
      case when v_sayim then null when p.photo_url is not null and (
             coalesce(p.photo_connections_only,false) = false
             or exists (select 1 from connection_requests cr where cr.status='accepted'
                        and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
           ) then p.photo_url else null end as photo,
      coalesce(v.id_verified,false) as hid,
      (p.linkedin_url is not null and p.linkedin_url <> '') as hlinked,   -- 040 düzeltmesi
      -- 317 · Puan yalnız `>= 3`e bakıyor: üçüncüyü bulunca dur. Tamamlanan oturumun
      -- isteği de 'completed' (oturum kapanınca istek kapanır) → (host_id, status)
      -- indeksiyle host'un TÜM isteklerini taramadan sayılır. Ölçek: 30.000 ilan.
      case when v_sayim then 0 else (select count(*) from (select 1 from requests r2 join sessions s2 on s2.request_id = r2.id
                               where r2.host_id = a.host_id and r2.status = 'completed'
                                 and s2.status = 'completed' limit 3) z3) end as hsessions,
      -- v158: ayni tarihli ayni ucus, tanimi geregi seyahat eslesmesidir —
      -- saat penceresi kesismese bile.
      case when v_sayim then false else (exists (select 1 from visits vs where vs.user_id=v_uid and vs.airport_code=a.airport_code
              and vs.visit_date=a.avail_date and vs.time_from < a.time_to and a.time_from < vs.time_to)
       or exists (select 1 from visits vs2 where vs2.user_id=v_uid and vs2.flight_number is not null
              and a.flight_number is not null and upper(vs2.flight_number)=upper(a.flight_number)
              and vs2.visit_date = a.avail_date)) end as has_trip,
      -- v158: AYNI UCUS artik TARIHLE birlikte (tarihsiz hali "Seyahatinin
      -- disinda" rozetiyle celisiyordu — cihazda goruldu).
      case when v_sayim then false else exists (select 1 from visits vs where vs.user_id=v_uid and vs.flight_number is not null
              and a.flight_number is not null and upper(vs.flight_number)=upper(a.flight_number)
              and vs.visit_date = a.avail_date) end as same_flight,
      (a.featured_until is not null and a.featured_until > now()) as featured
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    left join verifications v on v.user_id=a.host_id
    where a.active and not exists (select 1 from users bu where bu.id = a.host_id and (bu.banned_at is not null or bu.deleted_at is not null)) /* 282/B1 */=true
      and (hu.role = 'host'
           or exists (select 1 from host_applications ha           -- 049/#2: onayli
                      where ha.user_id = a.host_id and ha.status = 'approved'))
      and (coalesce(hu.is_staff,false) = false or v_staff)                -- YENİ (041)
      and a.avail_date >= current_date
      and (v_son is null or a.avail_date <= v_son)   -- 317 · sayım kipi tarih sınırı
      and coalesce(p.show_on_discovery,true)=true
      -- 317 · is_visible(a.host_id) ile EŞ, satır içinde (bkz. yukarı):
      and (v_test_gorur or not public.seed_test_hesabi(hu.email))
      and not coalesce(hu.shadow_limited and (hu.restricted_until is null or hu.restricted_until > now()), false)
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified))
           -- 049/#20: kadin KENDISI etkilesim baslattiysa o erkek onu gorebilir:
           -- (a) izleyiciye baglanti istegi gonderdiyse, (b) izleyicinin ilanina
           -- basvurduysa, (c) izleyiciyi slotuna davet ettiyse
           or exists (select 1 from connection_requests c9 where c9.from_id = a.host_id and c9.to_id = v_uid)
           or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                      where r9.guest_id = a.host_id and a9.host_id = v_uid)
           or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = v_uid))
      -- 040: görünürlük — host ne seçtiyse o geçerli
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
         coalesce(b.visibility,'Public')::text as visibility,
         b.hgender::text as host_gender,
         b.hlangs as host_langs
  from base b
  -- 🔴 112: ENGELLEME FILTRESI. Bu satir YOKTU. `blocks` tablosu 034'ten
  -- beri var ve engelleme kaydi olusuyordu, ama kesif ona HIC bakmiyordu:
  -- engellenen kullanici host'un ilanini gormeye ve BASVURMAYA devam
  -- ediyordu. Guvenlik ozelliginin en tehlikeli bozulma bicimi budur —
  -- kullanici korunduguna INANIR ama korunmaz.
  -- Iki yonlu: kim kimi engellemis olursa olsun, o cift birbirini gormez.
  -- 317 · is_blocked_pair(b.host_id, auth.uid()) satır içinde (çağrı başı maliyet yok):
  -- İki ayrı NOT EXISTS: VEYA'lı tek koşul hash'lenemiyor, her ilan × her engel satırı
  -- karşılaştırılıyordu; ayrı ayrı ikisi de blocks_pkey (blocker, blocked) ile tek arama.
  where not exists (select 1 from blocks bl where bl.blocker = b.host_id and bl.blocked = v_uid)
    and not exists (select 1 from blocks bl where bl.blocker = v_uid and bl.blocked = b.host_id)
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit v_limit;
end $function$;

CREATE OR REPLACE FUNCTION public.kesfet_ozeti(p_gun integer DEFAULT 14)
 RETURNS TABLE(airport_code text, canli_ilan integer, host_sayisi integer, acik_slot integer, durum text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  perform set_config('ll.kesif_limit', '1000000', true);
  perform set_config('ll.kesif_son_gun', (current_date + greatest(1, coalesce(p_gun, 14)))::text, true);
  return query
  with d as (
    select k.id, k.host_id, k.airport_code::text as ap, k.slots, k.filled, k.fully_booked
      -- 317 · Eskiden discover_availabilities (100 ilan sınırı + ilan başına erişim
      -- kararı) üstünden sayıyordu: ölçekte 37 sn VE 100'ü aşınca eksik sayı.
      -- Görünürlük kuralları aynı (base), sınır yok.
      from public.discover_availabilities_base(null, null, null, null) k
  ), canli as (
    select d.*
      from d
      join availabilities a on a.id = d.id
      left join airports ap on ap.code = a.airport_code
     where d.host_id <> v_uid
       and not coalesce(d.fully_booked, false)
       and greatest(0, coalesce(d.slots,0) - coalesce(d.filled,0)) > 0
       and a.avail_date <= current_date + greatest(1, coalesce(p_gun, 14))
       and (a.avail_date + a.time_to) > (now() at time zone coalesce(ap.timezone, 'Europe/Istanbul'))
  )
  select c.ap,
         count(*)::int,
         count(distinct c.host_id)::int,
         coalesce(sum(greatest(0, coalesce(c.slots,0) - coalesce(c.filled,0))), 0)::int,
         case when count(distinct c.host_id) >= 3 then 'canli'
              when count(distinct c.host_id) >= 1 then 'isiniyor' else 'soguk' end
    from canli c
   group by c.ap
   order by count(distinct c.host_id) desc, c.ap;
  perform set_config('ll.kesif_limit', '', true);
  perform set_config('ll.kesif_son_gun', '', true);
end $function$;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'base: is_visible satir icinde' as kontrol,
       position('public.is_visible(a.host_id)' in pg_get_functiondef('public.discover_availabilities_base(text,text,text,date)'::regprocedure)) = 0
   and position('v_test_gorur' in pg_get_functiondef('public.discover_availabilities_base(text,text,text,date)'::regprocedure)) > 0 as tamam
union all
select 'kesfet_ozeti: sinirsiz base',
       position('discover_availabilities_base' in pg_get_functiondef('public.kesfet_ozeti(integer)'::regprocedure)) > 0;
-- Beklenen: iki satır da tamam = true.
