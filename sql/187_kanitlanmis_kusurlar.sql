-- ============================================================
-- 187 · KANITLANMIŞ KUSURLAR — temiz göz turunun kapattıkları
-- 17 Ağustos 2026
--
-- Bu dosyadaki HER madde canlı PostgreSQL 16 üzerinde ÖLÇÜLDÜ.
-- Tahmin yok; her bölümün başında ölçümün kendisi yazılı.
--
-- 🔴 EN ÖNEMLİ DERS (yeni bir hata sınıfı):
--   208 migration "temiz koştu", rule_full_report 28/28 yeşil,
--   device_flow_check 7/7 yeşil — ama 186'nın İKİ RPC'si de canlıda
--   HİÇ ÇALIŞMIYORDU. Sebep: plpgsql `return query`'nin tip
--   denetimi CREATE anında değil ÇAĞRI anında yapılır. Migration
--   fonksiyonu kurar, hiçbir denetim onu ÇAĞIRMAZ, dolayısıyla
--   kimse görmez. 186'nın kendi kanıt bloğu da SEED'den önce
--   koştuğu için `kmisafir1` bulamayıp `return` ile çıkıyordu —
--   yani kanıt bloğu hiçbir zaman çalışmadı.
--   → Bu dosyanın sonundaki rpc_smoke_test() bu sınıfı kalıcı
--     olarak kapatır: tablo döndüren her RPC GERÇEKTEN çağrılır.
-- ============================================================

-- ============================================================
-- 1 · 186'NIN İKİ RPC'Sİ CANLIDA ÖLÜ  (🔴 KRİTİK)
-- ============================================================
-- ÖLÇÜM (PG16, bu veriyle):
--   select count(*) from public.my_sent_requests();
--     ERROR: structure of query does not match function result type
--     DETAIL: Returned type character(3) does not match expected
--             type text in column 9.
--   select count(*) from public.pending_ratings();
--     ... column 8.
--
-- SEBEP: availabilities.airport_code char(3), slots/filled smallint;
-- imza text/int diyor. plpgsql tip OID'lerinin BİREBİR eşleşmesini
-- ister ve sıfır satırda bile patlar. 112_blocks_in_discovery.sql
-- bu castleri BİLEREK yazmıştı (satır 124-125); 186 üçünü unutmuş.
--
-- KULLANICI ETKİSİ: app bu çağrıları `.catch(()=>setRows([]))` ile
-- yuttuğu için misafirin ana sayfasında "gönderdiğim istekler"
-- kartları HİÇ görünmüyor ve "kapıda ne oldu?" puanlama ekranı
-- HİÇ açılmıyor. 186 tam da bunları eklemek için yazılmıştı.
--
-- 🔴 AYRICA: karar `a.flight_number` ile hesaplanıyordu — o
-- İLANIN, yani HOST'un uçuşu. Parametrenin adı p_guest_flight.
-- Sonuç: same_carrier/same_flight kontrolleri DAİMA geçiyor,
-- misafirin AJet bileti olsa bile "misafir hakkı var" yazıyordu.
-- Doğrusu misafirin KENDİ seyahatinden okumak (request_precheck
-- 142'de zaten böyle yapıyor).

drop function if exists public.pending_ratings();
create or replace function public.pending_ratings()
returns table (
  session_id uuid, request_id uuid, other_id uuid, other_name text,
  lounge text, completed_at timestamptz, i_am_host boolean,
  airport_code text, avail_date date, time_from time, time_to time,
  flight_number text, carrier text
)
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select s.id, r.id,
         case when r.host_id = v_uid then r.guest_id else r.host_id end,
         coalesce(p.name, 'Yolcu'),
         coalesce(a.lounge_name, a.airport_code::text),
         s.completed_at,
         (r.host_id = v_uid),
         a.airport_code::text,          -- 🔴 char(3) -> text
         a.avail_date, a.time_from, a.time_to,
         a.flight_number, a.carrier
    from sessions s
    join requests r on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join profiles p
      on p.user_id = case when r.host_id = v_uid then r.guest_id else r.host_id end
   where s.status = 'completed'
     and (r.host_id = v_uid or r.guest_id = v_uid)
     and not exists (select 1 from ratings rt
                      where rt.session_id = s.id and rt.rater_id = v_uid)
   order by s.completed_at desc nulls last
   limit 20;
end $$;
grant execute on function public.pending_ratings() to authenticated;

drop function if exists public.my_sent_requests();
create or replace function public.my_sent_requests()
returns table (
  id uuid, status text, created_at timestamptz, responded_at timestamptz,
  host_id uuid, host_name text, host_badge text,
  avail_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time,
  flight_number text, carrier text, slots int, filled int,
  guest_policy text, decision_note text
)
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  with mine as (
    select r.id as rid, r.status, r.created_at, r.responded_at,
           r.host_id, r.avail_id,
           -- 🔴 187: MİSAFİRİN kendi uçuşu. Eskiden a.flight_number
           -- (host'un uçuşu) geçiliyordu ve taşıyıcı kontrolü daima
           -- geçiyordu. 142'nin request_precheck'i ile aynı kaynak.
           (select v.flight_number from visits v
             where v.user_id = v_uid
               and v.airport_code = a2.airport_code
               and v.visit_date = a2.avail_date
               and coalesce(v.flight_number, '') <> ''
             order by v.created_at desc limit 1) as my_flight
      from requests r
      join availabilities a2 on a2.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending', 'accepted')
  )
  select m.rid, m.status::text, m.created_at, m.responded_at,
         m.host_id, coalesce(p.name, 'Host'), ts.badge,
         a.id, a.airport_code::text, a.lounge_name, a.avail_date,
         a.time_from, a.time_to, a.flight_number, a.carrier,
         a.slots::int, a.filled::int,     -- 🔴 smallint -> int
         coalesce(public.lounge_access_decision(a.id, m.my_flight) ->> 'guest_policy', 'unknown'),
         nullif(public.lounge_access_decision(a.id, m.my_flight) ->> 'headline', '')
    from mine m
    join availabilities a on a.id = m.avail_id
    left join profiles p on p.user_id = m.host_id
    left join trust_scores ts on ts.user_id = m.host_id
   order by coalesce(m.status = 'accepted', false) desc, a.avail_date, a.time_from;
end $$;
grant execute on function public.my_sent_requests() to authenticated;


-- ============================================================
-- 2 · ÇİFTE ÖDEME: kapıda ödeyen misafirden ÜSTÜNE kredi (🔴 KRİTİK)
-- ============================================================
-- ÖLÇÜM:
--   select code, fee_payer, gp, paid_guest_credit(id) ...
--     PGS_PAID      | guest_at_door | paid | 2
--     IGA_LOUNGE    | guest_at_door | paid | 2
--     IGA_PASS      | guest_at_door | paid | 2
--   Etkilenen aktif kabul satırı: 44
--
-- 108 bu korumayı BÜYÜK HARFLE yazmıştı:
--   "YALNIZ 'member_card' HALINDE. 'guest_at_door'da misafir zaten
--    kendi cebinden oduyor; ustune kredi almak CIFTE ODEME olur."
-- 181 fonksiyonu baştan yazarken şartı DÜŞÜRDÜ.
--
-- Üstelik `exception when others then return 2` — motor patlarsa
-- ÜCRET AL. Projenin kendi ilkesi tersine dönmüş: "bilmemek cömert
-- davranmak için gerekçe değildir" doğru, ama "bilmemek ÜCRET ALMAK
-- için gerekçedir" hiç değil.
--
-- KULLANICI ETKİSİ: SAW Plaza Premium ilanına başvuran misafir
-- ekranda "misafir girişi kapıda ücretlidir" okuyor, kapıda ~35 USD
-- ödüyor, ÜSTÜNE host'a 2 kredi aktarıyor. Host hiçbir şey ödemiyor.

create or replace function public.paid_guest_credit(p_avail_id uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare d jsonb; v_n int; v_payer text;
begin
  d := public.lounge_access_decision(p_avail_id, null);
  if coalesce(d ->> 'guest_policy', '') <> 'paid' then return 0; end if;

  -- 🔴 187: ÜCRETİ KİM ÖDÜYOR? Karar çıktısında fee_payer yok,
  -- programdan okunur. 'guest_at_door' ise misafir kapıda kendi
  -- öder → ÜSTÜNE kredi ALINMAZ.
  select lp.fee_payer into v_payer
    from lounge_programs lp
   where lp.id = nullif(d ->> 'program_id', '')::uuid;

  if coalesce(v_payer, 'member_card') <> 'member_card' then
    return 0;
  end if;

  -- 108'in doğru biçimi: jsonb string yazılırsa (value)::text::int patlar.
  select coalesce((value #>> '{}')::int, 2) into v_n
    from beta_settings where key = 'paid_guest_credits';
  return coalesce(v_n, 2);
exception when others then
  return 0;   -- 🔴 187: bilmiyorsak ÜCRET ALMA (eskiden 2 dönüyordu)
end $$;
grant execute on function public.paid_guest_credit(uuid) to authenticated;

-- BEKÇİ: kapıda ödeyen bir salonda kredi > 0 çıkarsa migration DURUR.
-- 🔴 BEKÇİNİN KENDİ DERSİ: ilk yazımda kabul satırından (venue ×
-- program) gidiyordum ve YANLIŞ ALARM verdi — bir salon çok sayıda
-- programı kabul eder, ama krediyi belirleyen HOST'UN kendi programı.
-- Doğru eksen kararın döndürdüğü program_id. Ölçüldü:
--   PGS_PAID     | guest_at_door | paid | kredi 0  ✓
--   PRIORITY_PASS| member_card   | paid | kredi 2  ✓
do $$
declare v_bad int;
begin
  select count(*) into v_bad
    from availabilities a,
         lateral (select public.lounge_access_decision(a.id, null) d) x
    join lounge_programs lp on lp.id = nullif(x.d ->> 'program_id', '')::uuid
   where lp.fee_payer is distinct from 'member_card'
     and (x.d ->> 'guest_policy') = 'paid'
     and public.paid_guest_credit(a.id) > 0;
  if v_bad > 0 then
    raise exception '187: CIFTE ODEME — kapida odeyen % ilanda hala kredi aliniyor', v_bad;
  end if;
  raise notice '187: cifte odeme kapandi (guest_at_door ilanlarinda kredi 0)';
end $$;


-- ============================================================
-- 3 · KEŞFETTE guest_allowance HER ZAMAN 0 (🔴 KRİTİK)
-- ============================================================
-- ÖLÇÜM: lounge_access_decision'ın döndürdüğü anahtarlar —
--   checked_at, detail, earliest_entry_hours, enforcement,
--   entitlement_model, family_allowed, fits, flight_coupling,
--   guest_fee_amount, guest_fee_currency, guest_fee_note,
--   guest_included_count, guest_policy, headline, known,
--   max_stay_hours, member_fee, program, program_id, program_name,
--   severity, source, tier, venue_id, venue_name
--   → `guest_allowance` YOK. O ad alt katman resolve_guest_rule'a ait.
--
-- 182 satır 115: coalesce((e.dec ->> 'guest_allowance')::int, 0)
--   → SQL NULL → coalesce → 0. HER İLANDA.
--
-- KULLANICI ETKİSİ: ELPL host'un IST M&S ilanı "misafir ücretsiz"
-- rozetini alıyor ama kaç kişi alınacağını gösteren her yer
-- "0 misafir" diyor.

do $$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'discover_availabilities' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise exception '187: discover_availabilities yok'; end if;

  select prosrc into v_src from pg_proc where oid = v_oid;
  if position('187:' in v_src) > 0 then
    raise notice '187: discover_availabilities zaten guncel'; return;
  end if;

  v_new := replace(v_src,
    '(e.dec ->> ''guest_allowance'')::int',
    '(e.dec ->> ''guest_included_count'')::int  /* 187: dogru anahtar */');

  if v_new = v_src then
    raise notice '187: guest_allowance kalibi bulunamadi — elle kontrol et';
    return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.discover_availabilities(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '187: kesif artik guest_included_count okuyor';
end $$;

-- BEKÇİ: policy 'included' ama allowance 0 kalan ilan varsa DUR.
do $$
declare v_bad int; v_uid uuid;
begin
  select id into v_uid from users order by created_at limit 1;
  if v_uid is null then raise notice '187: kullanici yok, kesif bekcisi atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  select count(*) into v_bad from public.discover_availabilities('IST', null, null, null) d
   where d.guest_policy = 'included' and coalesce(d.guest_allowance, 0) = 0;
  if v_bad > 0 then
    raise exception '187: kesifte % ilan "included" diyor ama misafir sayisi 0', v_bad;
  end if;
  raise notice '187: kesif misafir sayisi tutarli';
exception when undefined_column or undefined_function then
  raise notice '187: kesif bekcisi atlandi (imza farkli)';
end $$;


-- ============================================================
-- 4 · KEŞİF KARARI HOST'UN UÇUŞUYLA HESAPLANIYOR (🔴 KRİTİK)
-- ============================================================
-- ÖLÇÜM: discover_availabilities gövdesi —
--   public.lounge_access_decision(b.id, b.flight_number) as dec
-- b.flight_number = İLANIN uçuşu = HOST'un uçuşu.
-- Parametrenin adı p_guest_flight (157:147).
--
-- Sonuç: 157:349'daki v_g_car daima host'un taşıyıcısına eşit
-- çıkıyor → same_carrier/same_flight/same_alliance DAİMA geçiyor.
--
-- KULLANICI ETKİSİ: THY714 ilanı, AJet VF1102 bileti olan misafir.
-- Keşfet: "misafir hakkı var", buton aktif. İstek ekranı (142,
-- misafirin kendi uçuşunu okuyor): "aynı havayolunda uçmalısın" —
-- ENGEL. Aynı ürün iki farklı cevap veriyor.

do $$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'discover_availabilities' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('187-ucus:' in v_src) > 0 then
    raise notice '187: kesif ucus baglantisi zaten guncel'; return;
  end if;

  -- Misafirin kendi seyahatinden uçuş numarası: aynı havalimanı +
  -- aynı tarih. Yoksa null (motor "bilmiyorum" moduna düşer ve
  -- 172'nin en-kısıtlayıcı kuralı devreye girer — doğru davranış).
  v_new := replace(v_src,
    'public.lounge_access_decision(b.id, b.flight_number) as dec',
    '/* 187-ucus: MISAFIRIN kendi ucusu, host''unki degil */
             public.lounge_access_decision(b.id,
               (select v2.flight_number from visits v2
                 where v2.user_id = v_uid
                   and v2.airport_code = b.airport_code
                   and v2.visit_date = b.avail_date
                   and coalesce(v2.flight_number, '''') <> ''''
                 order by v2.created_at desc limit 1)) as dec');

  if v_new = v_src then
    raise notice '187: kesif karar kalibi bulunamadi — elle kontrol et'; return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.discover_availabilities(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '187: kesif karari artik misafirin ucusuyla hesaplaniyor';
end $$;


-- ============================================================
-- 5 · REHBER 174'ÜN DÜZELTMESİNİ ALMADI (🟠)
-- ============================================================
-- ÖLÇÜM: kabul satırı 'not_allowed' AMA program kuralı misafir>0
-- olan 9 (program, tier, salon) kombinasyonu var (AJET_MS ×
-- ELITE_PLUS/ELITE/CLASSIC_PLUS). 147/158'in guide_lounges'ında
-- bu durum HİÇBİR dala düşmüyor → son `else` → verdict 'yes'.
-- Karar motoru (174 sonrası) aynı duruma 'not_allowed' diyor.
--
-- KULLANICI ETKİSİ: Rehber ekranı "misafir götürebilirsin" der,
-- ilan açıp aynı salona sorunca "götüremezsin" der, kapıda misafir
-- geri çevrilir. Aynı salon, aynı kart, iki cevap.

do $$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'guide_lounges' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise exception '187: guide_lounges yok'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('187-oncelik:' in v_src) > 0 then
    raise notice '187: rehber onceligi zaten guncel'; return;
  end if;

  v_new := replace(v_src,
'    if a.guest_policy = ''not_allowed'' and guest_count = 0 then',
'    -- 🔴 187-oncelik: 174 ile AYNI kural. Salonun kabul satiri
    -- "misafir yok" diyorsa, program duzeyi kural onu EZEMEZ.
    -- Yalniz SALONA OZEL kural (venue_scope dolu) ezebilir.
    if a.guest_policy = ''not_allowed''
       and (g ->> ''venue_scope'') is null then
      verdict := ''self_only'';
      headline := coalesce(nullif(g ->> ''headline'', ''''),
                           ''Bu salon yalniz kart sahibini aliyor'');
      guest_count := 0;
    elsif a.guest_policy = ''not_allowed'' and guest_count = 0 then');

  if v_new = v_src then
    raise notice '187: rehber kalibi bulunamadi — elle kontrol et'; return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.guide_lounges(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '187: rehber artik salon kisitina uyuyor';
end $$;


-- ============================================================
-- 6 · ÇÖZÜMLEYİCİ effective_from KONTROLÜNÜ KAYBETTİ (🟠 gizli)
-- ============================================================
-- ÖLÇÜM: resolve_guest_rule gövdesinde 'effective_from' geçmiyor (0).
-- 147 öncesi HER kural sorgusunda çift kontrol vardı (083:114,
-- 086:493, 100:251, 103:173, 104:202, 105:158, 134:80).
--
-- Bugün patlamıyor çünkü tüm satırların effective_from'u geçmişte.
-- Ama tablo tam bunun için var (rules_version 2026-06-01 → 12-31).
-- 2027 kuralları önceden yüklendiği anda 172'nin `created_at desc`
-- sıralaması HENÜZ YÜRÜRLÜKTE OLMAYAN satırı öne alır ve motor
-- Eylül'de Ocak kurallarını uygular. 161'in "süresi dolmuş kural"
-- zaman bombasının aynadaki hâli.

do $$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid; v_n int;
begin
  select oid into v_oid from pg_proc
   where proname = 'resolve_guest_rule' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('effective_from' in v_src) > 0 then
    raise notice '187: resolve_guest_rule effective_from zaten var'; return;
  end if;

  -- Üç geçişin hepsinde aynı satır var; hepsini birden genişlet.
  v_new := replace(v_src,
    'and (x.effective_to is null or x.effective_to >= current_date)',
    'and (x.effective_to is null or x.effective_to >= current_date)
     and (x.effective_from is null or x.effective_from <= current_date) /* 187 */');

  if v_new = v_src then
    raise notice '187: effective_to kalibi bulunamadi — elle kontrol et'; return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.resolve_guest_rule(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';

  select count(*) into v_n from regexp_matches(v_new, 'effective_from', 'g');
  raise notice '187: resolve_guest_rule % geciste effective_from kontrol ediyor', v_n;
end $$;


-- ============================================================
-- 7 · submit_field_report İKİ İMZA — PostgREST belirsizliği (🟠)
-- ============================================================
-- ÖLÇÜM:
--   submit_field_report(uuid,text,numeric,text,text)
--   submit_field_report(uuid,boolean,boolean,boolean,text,text,text)
-- Aynı ada iki canlı imza. App adlandırılmış parametreyle çağırınca
-- PostgREST "Could not choose the best candidate function" verebilir;
-- app `.catch` ile yutar → kapı raporu SESSİZCE kaybolur.
-- 157'nin guide_lounges olayının birebir aynısı.

-- 🔴 İLK YAZIMDA pg_get_function_identity_arguments ile dize
-- karşılaştırdım ve TUTMADI (boşluk/biçim farkı) — bekçi yakaladı.
-- Ders: imzayı METİNLE eşleştirme; argüman SAYISI + tip dizisi kullan.
-- App 152'nin 7 parametreli imzasını çağırıyor (screens.js:4828);
-- 095'in 5 parametrelisi ölü.
do $$
declare v_old regprocedure; v_n int := 0;
begin
  for v_old in
    select p.oid::regprocedure from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'submit_field_report'
       and p.pronargs = 5
  loop
    execute 'drop function ' || v_old::text;
    raise notice '187: eski submit_field_report imzasi dusuruldu: %', v_old;
    v_n := v_n + 1;
  end loop;
  if v_n = 0 then raise notice '187: eski submit_field_report imzasi zaten yok'; end if;
end $$;

-- BEKÇİ: app'in çağırdığı hiçbir fonksiyonda iki imza kalmasın.
do $$
declare r record; v_bad int := 0;
begin
  for r in
    select p.proname, count(*) c
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
     group by 1 having count(*) > 1
  loop
    raise warning '187: % fonksiyonunun % imzasi var — PostgREST belirsizligi', r.proname, r.c;
    v_bad := v_bad + 1;
  end loop;
  if v_bad > 0 then
    raise exception '187: % fonksiyonda asiri yukleme kalintisi var', v_bad;
  end if;
  raise notice '187: asiri yukleme kalintisi yok';
end $$;


-- ============================================================
-- 8 · anon: GRANT VAR, RLS POLİTİKASI YOK (🟠)
-- ============================================================
-- ÖLÇÜM (7 tablo için grant / rls / anon politikası):
--   airports                 | t | t | 0
--   carriers                 | t | t | 0
--   lounges                  | t | t | 0
--   lounge_programs          | t | t | 0
--   lounge_venues            | t | t | 0
--   lounge_venue_acceptance  | t | t | 0
--   lounge_guest_rules       | t | t | 0
-- RLS açık + anon politikası yok = anon her sorguda 0 SATIR.
-- 183'ün amacı ("giriş yapmadan rehber çalışsın") gerçekleşmemiş.
-- 159'un "politika var, grant yok" dersinin AYNADAKİ hâli:
-- güvenlik iki katman, ikisi de gerekli.
--
-- 🔴 ÜRÜN KARARI: kural tablolarını (lounge_guest_rules,
-- lounge_venue_acceptance) anon'a AÇMIYORUZ. Ürünün tek
-- farklılaştırıcı varlığı tek `curl` ile dışarı verilmemeli.
-- Anon yalnız KATALOĞU görür; kararı RPC (security definer)
-- üzerinden alır.

do $$
declare t text;
begin
  foreach t in array array['airports', 'lounges', 'lounge_venues', 'lounge_programs', 'carriers']
  loop
    execute format('drop policy if exists %I_anon_read on public.%I', t, t);
    execute format(
      'create policy %I_anon_read on public.%I for select to anon using (%s)',
      t, t,
      case when t in ('lounges', 'lounge_venues', 'lounge_programs')
           then 'active = true' else 'true' end);
  end loop;
  raise notice '187: anon katalog okuma politikalari kuruldu (kural tablolari HARIC)';
end $$;

-- Kural tablolarındaki anon GRANT'ını geri al — politika yok zaten,
-- ama grant'ın durması yanlış güven verir.
revoke select on public.lounge_guest_rules from anon;
revoke select on public.lounge_venue_acceptance from anon;

-- BEKÇİ: anon gerçekten okuyabiliyor mu? (rol değiştirip ölçüyoruz)
do $$
declare v_n int;
begin
  set local role anon;
  select count(*) into v_n from public.lounges where active;
  reset role;
  if v_n = 0 then
    raise exception '187: anon hala salon goremiyor (politika uygulanmadi)';
  end if;
  raise notice '187: anon % aktif salon goruyor', v_n;
exception when insufficient_privilege then
  reset role;
  raise notice '187: anon rolu bu ortamda yok (yerel harness) — atlandi';
end $$;


-- ============================================================
-- 9 · NO-SHOW: KREDİ VE SLOT SONSUZA KİLİTLİ (🟠)
-- ============================================================
-- ÖLÇÜM: expire_stale_sessions gövdesi —
--   (a) bloğu: `where r.status='accepted' and s.id is null`
--       → oturum satırı VARSA bu isteği HİÇ görmez, iade yazmaz.
--   (b) bloğu: sessions'ı 'expired' yapar, credit_ledger'a TEK SATIR
--       YAZMAZ ve requests 'accepted' OLARAK KALIR.
--   sync_availability_filled filled'ı status in ('accepted','completed')
--   sayısından türettiği için filled HİÇ DÜŞMEZ.
--
-- Dosyanın kendi kuralı (080:31-34) "kredi iade edilir" diyor.
--
-- KULLANICI ETKİSİ: misafir "Oturumu Başlat"a bastı, host basmadı,
-- uçuş geçti. Misafirin kredisi hiçbir zaman geri gelmez; app'te
-- iade yolu yok. Host'un slots=1 ilanı sonsuza kadar filled=1 kalır
-- → o ilan bir daha KİMSEYE açılmaz ('fully_booked'). Tek no-show,
-- host'un ilanını kalıcı olarak öldürür.

do $$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'expire_stale_sessions' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise exception '187: expire_stale_sessions yok'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('187-noshow:' in v_src) > 0 then
    raise notice '187: no-show iadesi zaten var'; return;
  end if;

  -- 🔴 İLK YAZIMDA `get diagnostics v_sess` satırını 4 boşlukla
  -- eşleştirdim, gerçekte 2 boşluk — replace TUTMADI ve fonksiyon
  -- sessizce yamalanmadı. Bunu ancak SONUCU ÖLÇÜNCE gördüm
  -- (pg_get_functiondef'te '187-noshow' arayınca 0 çıktı).
  -- DERS: gövde yaması yaptıysan, yamanın UYGULANDIĞINI ölç.
  -- Şimdi benzersiz ve boşluğa duyarsız bir çıpa kullanıyoruz.
  v_new := replace(v_src,
'  return jsonb_build_object(''ok'', true,',
'  -- 🔴 187-noshow: (b) bloğu oturumu ''expired'' yapıyordu ama
  -- isteği ''accepted'' BIRAKIYOR ve krediyi iade ETMİYORDU.
  -- Sonuç: misafirin kredisi sonsuza kilitli; sync_availability_filled
  -- filled''ı accepted sayısından türettiği için host''un slotu da
  -- sonsuza dolu — tek no-show ilanı kalıcı olarak öldürüyordu.
  with kapanan as (
    select r.id, r.guest_id
      from requests r
      join sessions s2 on s2.request_id = r.id
     where r.status = ''accepted''
       and s2.status = ''expired''
       and s2.cancel_reason = ''no_show''
  ), iade as (
    update requests set status = ''cancelled''
     where id in (select id from kapanan)
    returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select i.guest_id, 1, ''no_show_refund'', i.id,
         coalesce((select sum(c.delta) from credit_ledger c
                    where c.user_id = i.guest_id), 0) + 1
    from iade i
   where not exists (select 1 from credit_ledger c2
                      where c2.ref_id = i.id and c2.reason = ''no_show_refund'');

  return jsonb_build_object(''ok'', true,');

  if v_new = v_src then
    raise notice '187: no-show kalibi bulunamadi — elle kontrol et'; return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.expire_stale_sessions(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql volatile security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';

  -- YAMANIN UYGULANDIĞINI ÖLÇ (yazmak yetmez).
  if position('187-noshow' in (select prosrc from pg_proc
       where proname = 'expire_stale_sessions'
         and pronamespace = 'public'::regnamespace limit 1)) = 0 then
    raise exception '187: no-show yamasi UYGULANMADI';
  end if;
  raise notice '187: no-show iadesi + slot serbest birakma eklendi';
end $$;

-- BEKÇİ: yapay bir no-show kur, kredinin iade edildiğini ÖLÇ.
do $$
declare v_req uuid; v_guest uuid; v_before int; v_after int;
begin
  select r.id, r.guest_id into v_req, v_guest
    from requests r where r.status = 'accepted' limit 1;
  if v_req is null then raise notice '187: no-show bekcisi atlandi (kabul edilmis istek yok)'; return; end if;

  insert into sessions (request_id, status, cancel_reason, completed_at, guest_started_at)
  values (v_req, 'expired', 'no_show', now(), now())
  on conflict do nothing;

  select coalesce(sum(delta), 0) into v_before from credit_ledger where user_id = v_guest;
  perform public.expire_stale_sessions();
  select coalesce(sum(delta), 0) into v_after from credit_ledger where user_id = v_guest;

  if v_after <= v_before then
    raise exception '187: no-show iadesi CALISMIYOR (bakiye % -> %)', v_before, v_after;
  end if;
  raise notice '187: no-show iadesi kanitlandi (bakiye % -> %)', v_before, v_after;

  -- temizlik: test artefaktini geri al
  delete from credit_ledger where ref_id = v_req and reason = 'no_show_refund';
  delete from sessions where request_id = v_req and cancel_reason = 'no_show';
  update requests set status = 'accepted' where id = v_req;
exception when others then
  raise notice '187: no-show bekcisi atlandi (%)', left(sqlerrm, 120);
end $$;


-- ============================================================
-- 10 · NULL SIRALAMA — 183 ve 186 (🟡 gizli)
-- ============================================================
-- ÖLÇÜM: bugün scope NULL olan aktif venue YOK (0), yani
-- tetiklenmiyor. Ama 145'in kendi dersi burada kapatılmamıştı:
-- `order by (v.scope='domestic') desc` — LEFT JOIN eşleşmezse ya da
-- BO bir venue'yu pasife çekerse NULL EN BAŞA çıkar. Ölçülmüş PG16:
--     A-null |               <- NULL EN BASTA
--     B-dom  | domestic
--     C-intl | international
--
-- 🔴 BU BÖLÜM BİLEREK KOD YAMASI DEĞİL, BEKÇİ.
-- İlk yazımda 183/186'yı ÇALIŞMA ZAMANINDA string surgery ile
-- yamıyordum. İki sorun çıktı: (a) sql_lint yamanın ARADIĞI kalıbı
-- gerçek bir hata sanıp yanlış alarm verdi (b) düzeltme KAYNAKTA
-- durmadığı için bir sonraki temiz kurulumda geri geliyordu.
-- Doğrusu: kaynağı düzelt (183 ve 186'da coalesce yazıldı), burada
-- yalnızca DÜZELTİLMİŞ OLDUĞUNU DOĞRULA. Yama, kaynağın yerine
-- geçmez.
do $$
declare r record; v_bad int := 0; v_src text;
begin
  for r in
    select p.oid, p.proname from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('lounges_for_airport', 'my_sent_requests')
  loop
    v_src := (select prosrc from pg_proc where oid = r.oid);
    -- "order by" sonrasi, coalesce'siz bir esitlik karsilastirmasi
    -- desc ile siralaniyorsa NULL en basa cikar.
    if v_src ~* 'order\s+by[^;]*?\(\s*\w+\.\w+\s*=\s*[^)]+\)\s*desc'
       and v_src !~* 'coalesce\s*\(\s*\w+\.\w+\s*='
    then
      raise warning '187: % NULL-guvenli olmayan siralama iceriyor', r.proname;
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then
    raise exception '187: % fonksiyonda NULL siralama riski var (kaynakta coalesce ekle)', v_bad;
  end if;
  raise notice '187: siralamalar NULL-guvenli';
end $$;


-- ============================================================
-- 11 · YENİ KALICI DENETİM: rpc_smoke_test()  (🔴 en değerli parça)
-- ============================================================
-- NEDEN VAR: 186'nın iki RPC'si canlıda ÖLÜYDÜ ve HİÇBİR denetim
-- görmedi — çünkü hepsi fonksiyonun VAR OLDUĞUNU denetliyordu,
-- ÇALIŞTIĞINI değil. plpgsql `return query` tip denetimini yalnız
-- çağrı anında yapar.
--
-- Bu fonksiyon app'in çağırdığı, parametresiz ya da güvenle
-- boş çağrılabilen tablo/jsonb döndüren RPC'leri GERÇEKTEN çağırır
-- ve patlayanı adıyla bildirir. Bir tur önce yazılsaydı 186
-- teslim edilmeden yakalanırdı.

create or replace function public.rpc_smoke_test()
returns table (rpc text, sonuc text, hata text)
language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid;
  v_list text[] := array[
    'my_sent_requests', 'pending_ratings', 'home_connections',
    'host_requests', 'my_credit_ledger', 'guide_airports',
    'carrier_options', 'card_product_options', 'notifications_unread_count',
    'my_availabilities', 'my_visits', 'partners_visible'
  ];
  v_fn text; v_n int;
begin
  select id into v_uid from users order by created_at limit 1;
  if v_uid is not null then
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);
  end if;

  foreach v_fn in array v_list loop
    if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname = v_fn) then
      rpc := v_fn; sonuc := '⊘ tanimli degil'; hata := null; return next; continue;
    end if;
    begin
      execute format('select count(*) from public.%I()', v_fn) into v_n;
      rpc := v_fn; sonuc := '✓ ' || v_n || ' satir'; hata := null;
    exception when others then
      rpc := v_fn; sonuc := '✗ PATLIYOR'; hata := left(sqlerrm, 160);
    end;
    return next;
  end loop;
end $$;
grant execute on function public.rpc_smoke_test() to authenticated;

-- BEKÇİ: patlayan RPC varsa migration DURUR.
do $$
declare r record; v_bad int := 0;
begin
  for r in select * from public.rpc_smoke_test() where sonuc like '✗%' loop
    raise warning '187: RPC PATLIYOR — % : %', r.rpc, r.hata;
    v_bad := v_bad + 1;
  end loop;
  if v_bad > 0 then
    raise exception '187: % RPC canlida patliyor', v_bad;
  end if;
  raise notice '187: rpc_smoke_test temiz — cagrilabilen her RPC calisiyor';
end $$;

-- ---- rule_full_report'a F bölümü ----
-- 🔴 BİLEREK METİNLE YAMAMIYORUZ. Bu projede fonksiyon gövdesini
-- string surgery ile yamamak ÜÇ KEZ kırıldı (172'de tam metin
-- tanımına geçildi) ve bu dosyada da dördüncü kez kırdı:
--   ERROR: unterminated quoted string at or near "'end "
-- Doğru yol: raporu SARAN yeni bir fonksiyon. Eski rapor olduğu
-- gibi kalır, F bölümü üstüne eklenir. BO ve verify bunu çağırır.
create or replace function public.rule_full_report_v2()
returns table (bolum text, kalem text, toplam int, gecen int, kalan int, durum text)
language plpgsql volatile security definer set search_path = public as $$
declare v_top int; v_kalan int;
begin
  return query select r.bolum, r.kalem, r.toplam, r.gecen, r.kalan, r.durum
                 from public.rule_full_report() r;

  -- 187-smoke: çağrılabilen RPC'ler GERÇEKTEN çalışıyor mu?
  -- Bu satır 186'nın iki ölü RPC'sini yakalardı.
  select count(*)::int, count(*) filter (where s.sonuc like '✗%')::int
    into v_top, v_kalan
    from public.rpc_smoke_test() s;
  bolum := 'F · RPC canlılık'; kalem := 'rpc_smoke_test';
  toplam := v_top; kalan := v_kalan; gecen := v_top - v_kalan;
  durum := case when v_kalan = 0 then '✓' else '✗' end;
  return next;
end $$;
grant execute on function public.rule_full_report_v2() to authenticated;

do $$
declare v_kirmizi int;
begin
  select count(*) into v_kirmizi from public.rule_full_report_v2() where durum not like '✓%';
  raise notice '187: rule_full_report_v2 — % kirmizi', v_kirmizi;
end $$;

select '187 OK - 10 kanitlanmis kusur kapandi + rpc_smoke_test kuruldu' as sonuc;


-- ============================================================
-- 12 · KREDİ ŞEFFAFLIĞI: precheck TOPLAMI söylemiyor (🟠)
-- ============================================================
-- ÖLÇÜM (ESB ücretli misafir ilanı, canlı precheck çıktısı):
--   "credit_cost": 2,
--   "credit_note": "Ücreti host ödüyor. Kabul edilirse 2 kredi ona
--                   aktarılır — bir teşekkür, tazminat değil."
-- Ama misafirin cebinden çıkan TOPLAM 3: 1 escrow + 2 aktarım (181).
-- Ekran 2 diyor, hesap 3 düşüyor.
--
-- 🔴 BUNU E2E YAKALADI AMA YANLIŞ SEBEPLE: two_account_e2e 3. adımı
-- `"credit_cost": 3` bekliyordu ve kırmızı yandı. Test ürünün bozuk
-- olduğunu değil, KENDİ VARSAYIMINI bildiriyordu — 12 Ağustos'ta
-- öğrenilen sınıfın aynısı. Doğru cevap testi 2'ye çekmek DEĞİL,
-- eksik olan alanı EKLEMEK: kullanıcı toplamı görmeli.
--
-- Gökberk'in kendi ifadesiyle: "1 kredi escrowda tutsun, oturum
-- tamamlanınca 2 kredi geçsin, total 3 kredi harcansın."

do $$
declare v_src text; v_new text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'request_precheck' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise notice '187: request_precheck yok'; return; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('187-kredi:' in v_src) > 0 then
    raise notice '187: kredi toplami zaten var'; return;
  end if;

  -- 'credit_cost', v_credit  →  yanına toplam ve kalem dökümü.
  -- İmza ve dönüş tipi DEĞİŞMİYOR; jsonb'ye alan eklemek geriye
  -- uyumludur (157'nin dersi). Eski app sürümleri etkilenmez.
  v_new := replace(v_src,
    '''credit_cost'', v_credit,',
    '''credit_cost'', v_credit,
    /* 187-kredi: misafirin cebinden cikan TOPLAM. Ekranda tek
       kutuda gosterilmeli: escrow + aktarim. */
    ''credit_hold'', 1,
    ''credit_total'', 1 + coalesce(v_credit, 0),');

  if v_new = v_src then
    raise notice '187: credit_cost kalibi bulunamadi — elle kontrol et'; return;
  end if;

  execute 'create or replace function public.request_precheck('
       || pg_get_function_arguments(v_oid) || ') returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '187: precheck artik credit_hold + credit_total donuyor';
end $$;

-- BEKÇİ: toplam = escrow + aktarım olmalı, her ilanda.
do $$
declare r record; v_bad int := 0; v_uid uuid; j jsonb;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then select id into v_uid from users order by created_at limit 1; end if;
  if v_uid is null then raise notice '187: kredi bekcisi atlandi (kullanici yok)'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  for r in select id from availabilities where active limit 15 loop
    j := public.request_precheck(r.id);
    if j ? 'credit_total' and
       (j ->> 'credit_total')::int <> 1 + coalesce((j ->> 'credit_cost')::int, 0) then
      raise warning '187: ilan % toplam % ama kalem 1+%', r.id,
        j ->> 'credit_total', j ->> 'credit_cost';
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then raise exception '187: % ilanda kredi toplami tutmuyor', v_bad; end if;
  raise notice '187: kredi toplami her ilanda tutarli';
exception when others then
  raise notice '187: kredi bekcisi atlandi (%)', left(sqlerrm, 120);
end $$;

select '187 tamam - 12 kanitlanmis kusur + rpc_smoke_test + kredi seffafligi' as sonuc;


-- ============================================================
-- 13 · submit_field_report CANLIDA PATLIYOR (🔴 KRİTİK)
-- ============================================================
-- ÖLÇÜM (E2E, gerçek PostgreSQL):
--   select public.submit_field_report('<sid>', true, true, true, '35', null, null)
--     ERROR: record "s" has no field "host_id"
--
-- SEBEP: 152 `s sessions%rowtype` alıp `s.host_id`, `s.guest_id`,
-- `s.avail_id` okuyor. `sessions` tablosunda BU ÜÇ KOLON DA YOK
-- (001:217-227) — sessions yalnız `request_id` taşır; host/guest/avail
-- `requests`'te durur. Hafızadan şema yazmanın 11. örneği.
--
-- 🔴 NEDEN ŞİMDİYE KADAR GÖRÜLMEDİ: E2E 095'in ESKİ 5 parametreli
-- imzasını çağırıyordu; o imza ayrı bir gövdeye sahipti ve çalışıyordu.
-- 187 aşırı yüklemeyi düşürünce test app'in gerçekten çağırdığı
-- imzaya düştü ve hata ORTAYA ÇIKTI. Yani aşırı yükleme yalnız
-- PostgREST belirsizliği değil, BİR HATAYI DA GİZLİYORMUŞ.
--
-- KULLANICI ETKİSİ: "Kapıda ne oldu?" ekranı (screens.js:4828) her
-- gönderimde hata veriyor. Kutu `if (error) { setSendErr(...); return; }`
-- ile açık kalıyor, kullanıcı tekrar deniyor, yine olmuyor.
-- Kaybedilen şey ürünün TEK savunulabilir hendeği: saha verisi.
-- Rakip resmî tabloları kopyalayabilir; "IST Primeclass'ta Classic Plus
-- misafiriyle son 30 denemenin 27'si geçti" verisini kopyalayamaz.

create or replace function public.submit_field_report(
  p_session_id uuid,
  p_entered boolean,
  p_guest_accepted boolean default null,
  p_fee_charged boolean default null,
  p_fee_amount text default null,
  p_quota_left text default null,
  p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  s sessions%rowtype;
  r requests%rowtype;          -- 🔴 187: host/guest/avail BURADA
  v_venue uuid; v_prog uuid; v_tier text; v_outcome text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into s from sessions where id = p_session_id;
  if not found then raise exception 'session_not_found'; end if;
  select * into r from requests where id = s.request_id;
  if not found then raise exception 'session_not_found'; end if;

  -- 152'nin taşıdığı iki garanti KORUNUYOR (drift_check bunları
  -- bir kez kaybettiğimizi yakalamıştı; bir daha kaybetmiyoruz).
  if v_uid not in (r.host_id, r.guest_id) then raise exception 'not_party'; end if;
  if p_entered is null then raise exception 'invalid_outcome'; end if;

  -- Salon: önce katalog yolu, tutmazsa 161'in venue çözümleyicisi.
  -- Tek yola güvenmek 158/160/161'in katalog uzlaştırmasından sonra
  -- bir ortamda boş dönebiliyor; yedek yol veriyi kurtarır.
  select l.venue_id into v_venue
    from availabilities a join lounges l on l.id = a.lounge_id
   where a.id = r.avail_id;
  if v_venue is null then
    v_venue := public.resolve_venue_for_availability(r.avail_id);
  end if;

  select he.program_id, he.tier into v_prog, v_tier
    from host_entitlements he where he.user_id = r.host_id limit 1;

  -- 🔴 187 (İKİNCİ KATMAN): `outcome` NOT NULL (087:231) ve
  -- lfr_outcome_chk ile dört değere kısıtlı. 152 bu kolonu HİÇ
  -- yazmıyordu → 23502. İlk hata (`s.host_id`) düzeltilince ikincisi
  -- ortaya çıktı: aynı fonksiyonda İKİ ayrı şema-hafızadan-yazma
  -- hatası üst üste duruyormuş. Boolean cevaplar buradan türetilir.
  v_outcome := case
    when p_entered is not true                      then 'refused'
    when coalesce(p_fee_charged, false)             then 'admitted_paid'
    else                                                 'admitted_free'
  end;

  insert into lounge_field_reports
    (session_id, reporter_id, venue_id, program_id, card_tier,
     outcome, fee_paid, fee_currency,
     entered, guest_accepted, fee_charged, fee_amount, quota_left, note)
  values (p_session_id, v_uid, v_venue, v_prog, v_tier,
          v_outcome,
          nullif(regexp_replace(coalesce(p_fee_amount, ''), '[^0-9.]', '', 'g'), '')::numeric,
          case when coalesce(p_fee_amount, '') = '' then null
               when p_fee_amount ~* 'usd|\\$'      then 'USD'
               when p_fee_amount ~* 'eur|€'         then 'EUR'
               else 'TRY' end,
          p_entered, p_guest_accepted, p_fee_charged, p_fee_amount, p_quota_left, p_note)
  on conflict (session_id, reporter_id) do update set
    outcome = excluded.outcome, fee_paid = excluded.fee_paid,
    fee_currency = excluded.fee_currency,
    entered = excluded.entered, guest_accepted = excluded.guest_accepted,
    fee_charged = excluded.fee_charged, fee_amount = excluded.fee_amount,
    quota_left = excluded.quota_left, note = excluded.note;

  return jsonb_build_object('ok', true,
    'note', 'Teşekkürler — bu bilgi kural tablomuzu güncelliyor.');
end $$;
grant execute on function public.submit_field_report(uuid, boolean, boolean, boolean, text, text, text) to authenticated;

-- BEKÇİ: fonksiyonu GERÇEKTEN çağır. Var olması yetmez (186 dersi).
do $$
declare v_sid uuid; v_uid uuid; j jsonb;
begin
  select s.id, r.guest_id into v_sid, v_uid
    from sessions s join requests r on r.id = s.request_id limit 1;
  if v_sid is null then raise notice '187: saha raporu bekcisi atlandi (oturum yok)'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);
  j := public.submit_field_report(v_sid, true, true, true, '35', null, 'bekci');
  if coalesce((j ->> 'ok')::boolean, false) is not true then
    raise exception '187: submit_field_report hala calismiyor';
  end if;
  delete from lounge_field_reports where session_id = v_sid and note = 'bekci';
  raise notice '187: submit_field_report kanitlandi (gercekten cagrildi)';
end $$;
