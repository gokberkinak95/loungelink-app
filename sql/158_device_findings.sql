-- ============================================================
-- LoungeLink · 158_device_findings.sql
-- İLK GERÇEK CİHAZ TESTİNİN BULGULARI (12 Ağu 2026, akşam)
--
-- ⚠️ Uygulamayı ETKİLER. Kaynak: Gökberk'in cihaz ekran görüntüleri.
-- Her madde ölçülerek doğrulandı, tahmin yok.
--
-- 1. "AYNI UÇUŞ" + "Seyahatinin dışında" AYNI KARTTA (çelişki).
--    Kök: discover_availabilities.same_flight TARİHSİZ karşılaştırıyordu
--    (has_trip'te tarih koşulu var, same_flight'ta yoktu). Geçen ayki
--    TK1980 seyahatin bile rozeti yakıyordu. Ayrıca ayni tarihli ayni
--    uçuş, saat penceresi kesişmese de tanımı gereği seyahat
--    eşleşmesidir — has_trip buna göre genişletildi.
--
-- 2. REHBERDE "GİRİLMİYOR" DUVARI. guide_lounges alfabetik sıralıyordu;
--    Elite Plus seçen kullanıcının gördüğü ilk 5 kart kırmızıydı.
--    Kabul edilenler artık ÖNCE gelir.
--
-- 3. KATALOG UZLAŞTIRMA. Cihazdaki ilan formunda XpresSpa ve iGA Shower
--    "salon" olarak listelendi ve iç hat hiç görünmedi. Kökler: (a) app
--    pasif kayıtları da çekiyordu (app tarafında düzeltildi, v2.47)
--    (b) canlı katalogda imla mükerrerleri ve salon-olmayan kayıtlar
--    var. Bu blok kataloğu venue'larla UZLAŞTIRIR: venue başına tek
--    aktif kayıt, bağsızlar pasif, aktif venue'su olan her salona kayıt.
--
-- 4. İKİ CARRIER KOLONU YAŞIYORDU: availabilities.carrier (base karar
--    okur) + availabilities.carrier_code (v5 sarmalayıcı okur). Biri
--    doluyken diğeri boş kalabiliyordu — iki katman FARKLI taşıyıcı
--    görebilirdi. Backfill + tek öncelik sırası.
--
-- 5. create_availability artık p_carrier alır (İMZA DEĞİŞİYOR → önce
--    ESKİ imza drop edilir; tek fonksiyon kaldığı için p_carrier'sız
--    eski app çağrıları da PostgREST'te sorunsuz çalışır).
-- ============================================================

-- ---- 4a) CARRIER İKİLİĞİ: backfill (iki yönlü, veri kaybı yok) ----
update availabilities set carrier = upper(carrier_code)
 where carrier is null and carrier_code is not null;
update availabilities set carrier_code = carrier
 where carrier_code is null and carrier is not null;

-- ---- 5a) ESKİ İMZA DÜŞÜRÜLÜR (imza değişikliği = yeni aşırı yükleme
-- riski; guide_lounges dersi bir daha yaşanmayacak) ----
drop function if exists public.create_availability(uuid, text, date, time, time, integer, text, text);


-- ---- 1) discover_availabilities: AYNI UÇUŞ tarihli + has_trip genişletildi ----
--
-- ════════════════════════════════════════════════════════════════════
-- 🔴 20 AĞUSTOS · İKİ HATA ÜST ÜSTE — İKİNCİSİ BENİM "DÜZELTMEM"
--
-- (1) Dün burada `allow-replace discover_availabilities` yazıyordu ve
--     bu dosya bugün yeniden çalıştırılınca 42P13 veriyordu.
-- (2) Ben de önüne `drop function if exists` koydum. Hata sustu —
--     ama YERİNE DAHA KÖTÜSÜ GELDİ: dosya artık başarıyla çalışıyor ve
--     fonksiyonu 12 dosya ÖNCEKİ hâline GERİ DÜŞÜRÜYOR.
--
--     Ölçüldü (canlı şemada, aynı veritabanında):
--       158 ÖNCESİ : 31 kolon · guest_policy VAR
--       158 SONRASI: 23 kolon · guest_policy YOK
--
--     Sonuç: keşif artık kural kararını taşımıyor → rozetler kayboluyor,
--     "dolu ilana istek" kapısı açılıyor (182'nin kapattığı kusurlar).
--     Gökberk SEED4'ü çalıştırınca `column d.guest_policy does not exist`
--     aldı; sebebi buydu.
--
-- 🆕 SINIF: **BİR HATAYI SUSTURMAK, ONU ÇÖZMEK DEĞİLDİR.**
-- Gürültülü bir arıza, sessiz bir gerilemeden iyidir. `drop` eklemek
-- hatayı kaldırdı ama arızayı görünmezleştirdi.
--
-- 🆕 KURAL: **ESKİ BİR MIGRATION, KENDİNDEN YENİ BİR HÂLİ EZEMEZ.**
-- Bu blok artık canlıdaki tanımı ÖLÇÜYOR: fonksiyon zaten daha geniş
-- bir sözleşmeyle (>= 30 kolon) duruyorsa DOKUNMUYOR ve bunu söylüyor.
-- Boş veritabanına kurulumda (kolon yok / 23 kolon) eskisi gibi kurar.
-- ════════════════════════════════════════════════════════════════════
do $da158$
declare
  v_kolon int;
begin
  select coalesce(array_length(p.proallargtypes,1), 0) into v_kolon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='discover_availabilities'
   limit 1;

  if coalesce(v_kolon,0) >= 30 then
    raise notice '158: discover_availabilities zaten daha yeni bir surumde '
                 '(% cikti kolonu) — DOKUNULMADI. 182/195 gecerli kalir.', v_kolon;
    return;
  end if;

  drop function if exists public.discover_availabilities(text, text, text, date);
  execute $da_govde$
CREATE OR REPLACE FUNCTION public.discover_availabilities(p_airport text DEFAULT NULL::text, p_sector text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_date date DEFAULT NULL::date)
 RETURNS TABLE(id uuid, host_id uuid, airport_code text, lounge_name text, avail_date date, time_from time without time zone, time_to time without time zone, flight_number text, slots integer, filled integer, host_name text, host_badge text, host_score integer, host_profession text, host_photo text, match_score integer, same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean, visibility text, host_gender text, host_langs text[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $da_inner$
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
      (p.linkedin_url is not null and p.linkedin_url <> '') as hlinked,   -- 040 düzeltmesi
      (select count(*) from sessions s2 join requests r2 on r2.id=s2.request_id
        where s2.status='completed' and r2.host_id=a.host_id) as hsessions,
      -- v158: ayni tarihli ayni ucus, tanimi geregi seyahat eslesmesidir —
      -- saat penceresi kesismese bile.
      (exists (select 1 from visits vs where vs.user_id=v_uid and vs.airport_code=a.airport_code
              and vs.visit_date=a.avail_date and vs.time_from < a.time_to and a.time_from < vs.time_to)
       or exists (select 1 from visits vs2 where vs2.user_id=v_uid and vs2.flight_number is not null
              and a.flight_number is not null and upper(vs2.flight_number)=upper(a.flight_number)
              and vs2.visit_date = a.avail_date)) as has_trip,
      -- v158: AYNI UCUS artik TARIHLE birlikte (tarihsiz hali "Seyahatinin
      -- disinda" rozetiyle celisiyordu — cihazda goruldu).
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.flight_number is not null
              and a.flight_number is not null and upper(vs.flight_number)=upper(a.flight_number)
              and vs.visit_date = a.avail_date) as same_flight,
      (a.featured_until is not null and a.featured_until > now()) as featured
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    left join verifications v on v.user_id=a.host_id
    where a.active=true
      and (hu.role = 'host'
           or exists (select 1 from host_applications ha           -- 049/#2: onayli
                      where ha.user_id = a.host_id and ha.status = 'approved'))
      and coalesce(hu.is_staff,false) = false                -- YENİ (041)
      and a.avail_date >= current_date
      and coalesce(p.show_on_discovery,true)=true
      and public.is_visible(a.host_id)
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))
           -- 049/#20: kadin KENDISI etkilesim baslattiysa o erkek onu gorebilir:
           -- (a) izleyiciye baglanti istegi gonderdiyse, (b) izleyicinin ilanina
           -- basvurduysa, (c) izleyiciyi slotuna davet ettiyse
           or exists (select 1 from connection_requests c9 where c9.from_id = a.host_id and c9.to_id = v_uid)
           or exists (select 1 from requests r9 join availabilities a9 on a9.id = r9.avail_id
                      where r9.guest_id = a.host_id and a9.host_id = v_uid)
           or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = v_uid)
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
  where not public.is_blocked_pair(b.host_id, auth.uid())
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $da_inner$;
  $da_govde$;
  raise notice '158: discover_availabilities kuruldu (23 kolonlu ozgun hali)';
end $da158$;

-- ---- 2) guide_lounges: kabul edilenler önce ----
-- sqlcheck: allow-replace guide_lounges  (dönüş tipi AYNI)
create or replace function public.guide_lounges(
  p_airport text, p_program_code text default null, p_tier text default null,
  p_carrier text default null, p_cabin text default null
) returns table (
  venue_id uuid, lounge_name text, scope text, terminal text,
  amenities jsonb, verdict text, headline text, detail text,
  guest_count int, confidence text, source_url text
) language plpgsql stable security definer set search_path = public as $$
declare r record; a lounge_venue_acceptance%rowtype; g jsonb; v_pid uuid;
begin
  v_pid := case when p_program_code is null then null
                else (select id from lounge_programs where code = p_program_code) end;

  for r in
    select v.*,
           case when v.section = 'business' and v.name !~* 'business' then v.name || ' — Business'
                when v.section = 'miles_smiles' and v.name !~* 'miles' then v.name || ' — Miles&Smiles'
                else v.name end as disp_name
      from lounge_venues v
     where v.airport_code = upper(p_airport) and v.active and v.venue_kind = 'lounge'
       and not exists (select 1 from lounge_venues c where c.section_of = v.id and c.active)
     order by
       -- v158: KABUL EDILENLER ONCE — ilk izlenim "girilmiyor" duvari olmasin.
       (exists (select 1 from lounge_venue_acceptance ac
                 where ac.venue_id = v.id and ac.active and ac.accepted
                   and (v_pid is null or ac.program_id = v_pid))) desc,
       (v.section is null) desc, v.name
  loop
    venue_id := r.id; lounge_name := r.disp_name;
    scope := coalesce(r.scope,''); terminal := coalesce(r.terminal,'');
    amenities := coalesce(r.amenities, '{}'::jsonb);

    select * into a from lounge_venue_acceptance x
     where x.venue_id = r.id and x.active
       and (v_pid is null or x.program_id = v_pid)
     order by coalesce(x.program_id = v_pid, false) desc, x.is_placeholder,
              x.checked_at desc nulls last
     limit 1;

    if v_pid is null then
      verdict := 'info'; headline := null;
      detail := (select string_agg(distinct p.name, ' · ')
                   from lounge_venue_acceptance x join lounge_programs p on p.id = x.program_id
                  where x.venue_id = r.id and x.active);
      guest_count := null; confidence := null; source_url := null;
      return next; continue;
    end if;

    if not found then
      verdict := 'no'; headline := 'Bu kartla girilmiyor';
      detail := 'Bu salon seçtiğin programı kabul etmiyor.';
      guest_count := 0; confidence := 'verified'; source_url := null;
      return next; continue;
    end if;

    g := public.resolve_guest_rule(a.program_id, r.id, p_tier, p_carrier, p_cabin);
    guest_count := (g ->> 'guest_allowance')::int;
    confidence := case when a.is_placeholder then 'unknown'
                       when a.checked_at is not null then 'verified' else 'assumed' end;
    source_url := a.source_url;

    if a.guest_policy = 'not_allowed' and guest_count = 0 then
      verdict := 'self_only'; headline := g ->> 'headline';
    elsif guest_count = 0 and (g ->> 'paid_entry_allowed')::boolean then
      verdict := 'paid'; headline := g ->> 'headline';
    elsif guest_count = 0 then
      verdict := 'self_only'; headline := g ->> 'headline';
    elsif a.guest_policy = 'paid' then
      verdict := 'paid'; headline := 'Misafir ücretli';
    else
      verdict := 'yes'; headline := g ->> 'headline';
    end if;
    detail := public.clip_text(coalesce(g ->> 'note', a.conditions, ''), 130);
    return next;
  end loop;
end $$;


-- ---- 5b) create_availability: p_carrier (yeni imza) ----
CREATE OR REPLACE FUNCTION public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text, p_carrier text DEFAULT NULL::text)
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

-- ---- 3) KATALOG UZLAŞTIRMA ----
do $$
declare n1 int; n2 int; n3 int;
begin
  -- (a) venue başına BİRDEN ÇOK aktif katalog kaydı → en yenisi kalır.
  with ranked as (
    select l.id, row_number() over (partition by l.venue_id order by l.id desc) rn
      from lounges l where l.active and l.venue_id is not null)
  update lounges set active = false
   where id in (select id from ranked where rn > 1);
  get diagnostics n1 = row_count;

  -- (b) venue bağı OLMAYAN aktif kayıtlar → pasif (salon-olmayanlar —
  -- XpresSpa, iGA Shower — ve bağsız imla mükerrerleri burada temizlenir;
  -- kayıt SİLİNMEZ, geçmiş ilan referansları kırılmaz).
  update lounges set active = false where active and venue_id is null;
  get diagnostics n2 = row_count;

  -- (c) aktif venue'su olup aktif katalog kaydı OLMAYAN salon → kayıt
  -- açılır (host seçebilsin diye).
  insert into lounges (airport_code, name, terminal, active, venue_id)
  select v.airport_code, v.name,
         coalesce(v.terminal, case v.scope when 'domestic' then 'İç Hat'
                                           when 'international' then 'Dış Hat' end),
         true, v.id
    from lounge_venues v
   where v.active
     and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);
  get diagnostics n3 = row_count;

  raise notice '158 katalog uzlaştırma: % mükerrer pasif, % bağsız pasif, % eksik kayıt açıldı', n1, n2, n3;
end $$;

-- ---- DOĞRULAMA: uzlaştırma sonrası değişmezler ----
do $$
declare n int;
begin
  select count(*) into n from (
    select venue_id from lounges where active and venue_id is not null
     group by venue_id having count(*) > 1) x;
  if n > 0 then raise exception '158: % venue hala birden çok aktif katalog kaydına sahip', n; end if;

  select count(*) into n from lounges where active and venue_id is null;
  if n > 0 then raise exception '158: % aktif katalog kaydı venue bağsız', n; end if;

  select count(*) into n from lounge_venues v
   where v.active and not exists (select 1 from lounges l where l.venue_id=v.id and l.active);
  if n > 0 then raise exception '158: % aktif venue katalogda görünmüyor', n; end if;
end $$;

select '158 OK - cihaz bulgulari: ayni-ucus tarihli, rehber kabul-once, katalog uzlasti, carrier tek' as sonuc;
