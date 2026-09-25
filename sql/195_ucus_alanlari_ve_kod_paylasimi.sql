-- ============================================================
-- 195 · UÇUŞ ALANLARI, KOD PAYLAŞIMLI UÇUŞ ve AYNI SEKTÖR
-- 17 Ağustos 2026
--
-- ⚠️ UYGULAMAYI ETKİLER: flight_info() jsonb'sine YENİ ALANLAR eklenir
-- (mevcut alanlar aynen kalır) ve discover_availabilities BİR KOLON
-- kazanır. İkisi de geriye dönük uyumlu — eski sürüm yeni alanı
-- görmezden gelir.
--
-- ------------------------------------------------------------
-- 🔴 TEŞHİS — ÖLÇÜLDÜ, TAHMİN EDİLMEDİ
-- ------------------------------------------------------------
-- Gökberk "app'teki kart alanlarını doğrula" dedi. Yerel pgserver
-- harness'ında 216 dosyayı çalıştırıp HER RPC'nin GERÇEK dönüş
-- imzasını çıkardım ve src/screens.js'in okuduğu her snake_case alan
-- adıyla karşılaştırdım. 146 alan okunuyor; 910 alan üretiliyor.
-- ALTI TANESİ VERİTABANINDA YOK:
--
--   screens.js:396  fInfo.dep_iata        → flight_info() döndürmüyor
--   screens.js:396  fInfo.arr_iata        → flight_info() döndürmüyor
--   screens.js:397  fInfo.dep_time        → flight_info() döndürmüyor
--   screens.js:400  fInfo.airline_iata    → flight_cache'te KOLON BİLE YOK
--   screens.js:394  fInfo.airline         → flight_cache'te KOLON BİLE YOK
--   screens.js:1457 target.same_sector    → discover_availabilities yok
--   screens.js:7404 sel.access_type       → RPC `access_types` (dizi) veriyor
--
-- Sonuç ekranda şuydu: seyahat eklerken uçuş numarasını yazınca açılan
-- teal kutu ÜÇ SATIRININ İKİSİNİ BOŞ gösteriyordu (kalkış→varış yok,
-- saat yok), başlıkta havayolu adı yerine kullanıcının kendi yazdığı
-- uçuş numarası duruyordu ve "bu havayolunu kullan" kısayolu HİÇ
-- görünmüyordu. Çökme yok — bu yüzden fark edilmemiş. En pahalı hata
-- türü: sessiz olan.
--
-- 🔴 DERS (yeni sınıf): "OKUNAN ALAN, YAZILAN ALAN DEĞİLDİR."
-- jsonb bir sözleşme değil bir torbadır; olmayan anahtarı okumak
-- undefined verir, hata vermez. Bu yüzden bu turda kalıcı denetim de
-- yazıldı: rnapp/rpc_field_check.py — veritabanının ÜRETMEDİĞİ bir
-- alan adını okuyan her satırı yakalar.
--
-- ------------------------------------------------------------
-- 🔴 KOD PAYLAŞIMLI UÇUŞ — 191'in `veri_bekliyor` maddesi
-- ------------------------------------------------------------
-- Kod paylaşımı: bileti SATAN havayolu ile uçağı GERÇEKTEN UÇURAN
-- havayolu farklı olabilir. Bilette "TK8901" yazar ama uçağı
-- Lufthansa uçurur. Lounge açısından bu kritik: salon kapısında
-- kimin salonu olduğu ve hangi havayolunun yolcusu olduğunuz,
-- İŞLETEN taşıyıcıya göre değerlendirilir; pazarlayanın koduna göre
-- değil.
--
-- 191'de kural YAZILMAMIŞTI çünkü motorun elinde yalnız kullanıcının
-- yazdığı uçuş numarasının ÖNEKİ vardı. Şimdi AviationStack önbelleği
-- işleten taşıyıcıyı da taşıyor (`codeshared` alanı), dolayısıyla
-- motor artık TAHMİN etmek zorunda değil: veri varsa işleteni kullanır,
-- yoksa öneke düşer ve bunu SÖYLER.
-- ============================================================

-- ---- 1) ÖNBELLEK ŞEMASI: havayolu ve kod paylaşımı ----
alter table flight_cache add column if not exists airline       text;
alter table flight_cache add column if not exists airline_iata   text;
alter table flight_cache add column if not exists codeshared     jsonb;
alter table flight_cache add column if not exists operating_iata text;

comment on column flight_cache.airline_iata is
  '195: PAZARLAYAN havayolunun IATA kodu (uçuş numarasının öneki).';
comment on column flight_cache.operating_iata is
  '195: İŞLETEN havayolunun IATA kodu. Kod paylaşımlı uçuşta '
  'airline_iata''dan FARKLIDIR ve salon kapısında geçerli olan budur.';

-- Eski satırlarda kolonlar boş; ham yanıttan doldurulabildiği kadarını
-- doldur. `raw` AviationStack'in tam cevabı — veri zaten elimizdeydi,
-- yalnız okumuyorduk.
update flight_cache set
  airline       = coalesce(airline,       raw #>> '{airline,name}'),
  airline_iata  = coalesce(airline_iata,  raw #>> '{airline,iata}'),
  codeshared    = coalesce(codeshared,    raw #> '{flight,codeshared}')
 where raw is not null;

update flight_cache set
  operating_iata = coalesce(operating_iata,
                            codeshared ->> 'airline_iata',
                            airline_iata)
 where operating_iata is null;


-- ---- 2) İŞLETEN TAŞIYICI — tek kaynak ----
-- 🔴 SIRALAMA ÖNEMLİ: önbellekteki işleten > önbellekteki pazarlayan >
-- numaranın öneki. Öneke düşülen durumda çağıran taraf bunu bilmeli;
-- ikinci alan `kaynak` tam da bunun için var. "Bilmiyorum"u
-- gizlemiyoruz.
create or replace function public.flight_carrier_resolve(p_flight_no text, p_date date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_no   text := upper(replace(trim(coalesce(p_flight_no,'')), ' ', ''));
  v_pref text;
  v      flight_cache%rowtype;
begin
  if v_no = '' then
    return jsonb_build_object('carrier', null, 'kaynak', 'yok', 'codeshare', false);
  end if;
  v_pref := upper(substring(regexp_replace(v_no, '[^A-Za-z]', '', 'g') from 1 for 2));

  select * into v from flight_cache
   where upper(replace(flight_no,' ','')) = v_no
     and (p_date is null or flight_date = p_date)
   order by flight_date desc nulls last
   limit 1;

  if found and coalesce(v.operating_iata, '') <> '' then
    return jsonb_build_object(
      'carrier',    v.operating_iata,
      'marketing',  coalesce(v.airline_iata, v_pref),
      'kaynak',     'onbellek',
      'codeshare',  (v.codeshared is not null
                     and coalesce(v.codeshared ->> 'airline_iata','') <> ''
                     and coalesce(v.codeshared ->> 'airline_iata','') is distinct from coalesce(v.airline_iata,'')),
      'not',        case when v.codeshared is not null
                          and coalesce(v.codeshared ->> 'airline_iata','') is distinct from coalesce(v.airline_iata,'')
                    then 'Bu bir kod paylaşımlı uçuş: bileti '
                         || coalesce(v.airline_iata, v_pref)
                         || ' satıyor, uçağı '
                         || coalesce(v.codeshared ->> 'airline_name', v.codeshared ->> 'airline_iata')
                         || ' uçuruyor. Salon hakkı UÇURAN havayoluna göre değerlendirilir.'
                    else null end);
  end if;

  -- Önbellek yok: önek. Bu bir VARSAYIMDIR ve öyle etiketlenir.
  return jsonb_build_object(
    'carrier',   nullif(v_pref, ''),
    'marketing', nullif(v_pref, ''),
    'kaynak',    'onek',
    'codeshare', false,
    'not',       'Uçuş numarasının önekine bakıldı. Kod paylaşımlı bir '
                 || 'uçuşsa uçağı başka bir havayolu uçuruyor olabilir; '
                 || 'biniş kartında "operated by" ibaresi varsa oradaki '
                 || 'havayolu geçerlidir.');
end $$;
grant execute on function public.flight_carrier_resolve(text, date) to authenticated, anon;


-- ---- 3) flight_info() — APP'İN OKUDUĞU HER ALAN ----
-- 🔴 ALAN EKLEMEK GÜVENLİ, ALAN ADI DEĞİŞTİRMEK DEĞİL. Eski üç anahtar
-- (scheduled_departure, terminal, status …) AYNEN duruyor: flightSummary()
-- onları okuyor. Yeni adlar app'in zaten okuduğu adlar.
create or replace function public.flight_info(p_flight_no text, p_date date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v flight_cache%rowtype; v_car jsonb;
begin
  if coalesce(p_flight_no,'') = '' or p_date is null then
    return jsonb_build_object('hit', false, 'reason', 'eksik_parametre');
  end if;
  select * into v from flight_cache
   where upper(replace(flight_no,' ','')) = upper(replace(trim(p_flight_no),' ',''))
     and flight_date = p_date;
  if not found then
    return jsonb_build_object('hit', false,
      'autofetch', coalesce((select (value #>> '{}')::boolean from beta_settings where key='flight_autofetch'), true));
  end if;

  v_car := public.flight_carrier_resolve(v.flight_no, v.flight_date);

  return jsonb_build_object('hit', true,
    -- --- ESKİ SÖZLEŞME (dokunulmadı) ---
    'scheduled_departure', v.scheduled_departure,
    'terminal', v.terminal, 'gate', v.gate,
    'status', v.status, 'source', v.source, 'fetched_at', v.fetched_at,
    'stale', v.fetched_at < now() - interval '12 hours',
    -- --- 195: APP'İN OKUDUĞU AMA GELMEYEN ALANLAR ---
    'flight_no',   v.flight_no,
    'flight_date', v.flight_date,
    'dep_iata',    v.departure_iata,
    'arr_iata',    v.arrival_iata,
    'dep_time',    v.scheduled_departure,
    'arr_time',    v.scheduled_arrival,
    'airline',     v.airline,
    'airline_iata', coalesce(v.airline_iata,
                             upper(substring(regexp_replace(v.flight_no, '[^A-Za-z]', '', 'g') from 1 for 2))),
    -- --- 195: KOD PAYLAŞIMI ---
    'operating_iata', v_car ->> 'carrier',
    'codeshare',      coalesce((v_car ->> 'codeshare')::boolean, false),
    'carrier_note',   v_car ->> 'not');
end $$;
grant execute on function public.flight_info(text, date) to authenticated;


-- ---- 4) discover_availabilities · same_sector ----
-- 🔴 `p_sector` bu üründe MESLEK SEKTÖRÜ demek (havacılıktaki "iç
-- hat/dış hat" değil — o `scope`). discover_availabilities_base zaten
-- p_sector'ü profession üzerinden FİLTRELİYOR ama "ikimiz de aynı
-- sektördeniz" ROZETİ için gereken alanı DÖNDÜRMÜYORDU. App
-- `target.same_sector` okuyor (screens.js:1457, t.advSameSector) ve
-- her zaman undefined alıyordu: avantaj satırı HİÇ görünmedi.
drop function if exists public.discover_availabilities(text, text, text, date);

create or replace function public.discover_availabilities(
  p_airport text default null,
  p_sector  text default null,
  p_flight  text default null,
  p_date    date default null
) returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int,
  host_name text, host_badge text, host_score int, host_profession text,
  host_photo text, match_score int, same_flight boolean, has_trip boolean,
  is_featured boolean, fully_booked boolean, visibility text,
  host_gender text, host_langs text[],
  guest_policy text, guest_allowance int, family_allowed boolean,
  decision_note text, blocks_request boolean, block_reason text,
  carrier_note text,
  -- 🔴 195
  same_sector boolean
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_prof text;
begin
  select lower(btrim(p.profession)) into v_prof
    from profiles p where p.user_id = v_uid;

  return query
  with base as (
    select d.* from public.discover_availabilities_base(p_airport, p_sector, p_flight, p_date) d
  ), enriched as (
    select b.*,
           public.lounge_access_decision(b.id, b.flight_number) as dec,
           (select a.carrier from availabilities a where a.id = b.id) as av_carrier,
           -- 🔴 195: TAŞIYICI ARTIK ÖNBELLEKTEN. Eskiden yalnız uçuş
           -- numarasının öneki okunuyordu; kod paylaşımlı uçuşta bu
           -- YANLIŞ havayolunu verir ve kullanıcı "aynı havayolundayız"
           -- sanıp kapıda geri çevrilir.
           (select public.flight_carrier_resolve(v.flight_number, v.visit_date) ->> 'carrier'
              from visits v
             where v.user_id = v_uid and v.airport_code = b.airport_code
               and v.visit_date = b.avail_date
               and coalesce(v.flight_number,'') <> ''
             limit 1) as my_carrier
      from base b
  )
  select e.id, e.host_id, e.airport_code, e.lounge_name, e.avail_date,
         e.time_from, e.time_to, e.flight_number, e.slots, e.filled,
         e.host_name, e.host_badge, e.host_score, e.host_profession,
         e.host_photo, e.match_score, e.same_flight, e.has_trip,
         e.is_featured, e.fully_booked, e.visibility,
         e.host_gender, e.host_langs,
         coalesce(e.dec ->> 'guest_policy', 'unknown'),
         coalesce((e.dec ->> 'guest_allowance')::int, 0),
         coalesce((e.dec ->> 'family_allowed')::boolean, false),
         nullif(e.dec ->> 'headline', ''),
         coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots)
           or (coalesce(e.dec ->> 'guest_policy','') = 'not_allowed')
           or (coalesce(e.dec ->> 'severity','') = 'block'),
         case
           when coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots) then 'fully_booked'
           when coalesce(e.dec ->> 'guest_policy','') = 'not_allowed' then 'guests_not_allowed'
           when coalesce(e.dec ->> 'severity','') = 'block' then 'blocked_by_rule'
           else null end,
         case
           when e.av_carrier is null or e.my_carrier is null then null
           when e.av_carrier = e.my_carrier then null
           when e.av_carrier in ('TK') and e.my_carrier in ('VF','AJ')
             then 'Bu ilan THY seferinde; senin biletin AJet. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           when e.av_carrier in ('VF','AJ') and e.my_carrier = 'TK'
             then 'Bu ilan AJet seferinde; senin biletin THY. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           else null end,
         -- 🔴 195: AYNI SEKTÖR. "Bilmiyorum" ile "hayır" ayrılır:
         -- iki taraftan biri mesleğini yazmamışsa NULL döner (rozet
         -- gösterilmez), false demek "farklı sektör" demektir.
         case
           when v_prof is null or v_prof = '' then null
           when e.host_profession is null or btrim(e.host_profession) = '' then null
           else lower(btrim(e.host_profession)) = v_prof
                or lower(btrim(e.host_profession)) like '%' || v_prof || '%'
                or v_prof like '%' || lower(btrim(e.host_profession)) || '%'
         end
    from enriched e;
end $$;

grant execute on function public.discover_availabilities(text, text, text, date) to authenticated, anon;


-- ============================================================
-- BEKÇİLER — "app'in okuduğu her alan gerçekten dönüyor mu"
-- ============================================================

-- 1) flight_info() APP'İN OKUDUĞU HER ANAHTARI DÖNDÜRMELİ.
-- 🔴 Bu liste src/screens.js'ten ELLE değil, ÖLÇÜMLE çıkarıldı ve
-- artık DONDURULMUŞ bir sözleşmedir. Biri silinirse burası patlar.
do $$
declare
  v_keys text[] := array['hit','scheduled_departure','terminal','gate','status',
                         'source','fetched_at','stale','flight_no','flight_date',
                         'dep_iata','arr_iata','dep_time','arr_time','airline',
                         'airline_iata','operating_iata','codeshare','carrier_note'];
  v_out jsonb; k text; v_eksik text[] := '{}';
begin
  insert into flight_cache (flight_no, flight_date, departure_iata, arrival_iata,
                            scheduled_departure, scheduled_arrival, terminal, gate,
                            status, source, fetched_at, airline, airline_iata,
                            codeshared, operating_iata)
  values ('TK195B', current_date, 'IST', 'FRA',
          now(), now() + interval '3 hours', '1', 'A5',
          'scheduled', 'bekci', now(), 'Turkish Airlines', 'TK',
          jsonb_build_object('airline_iata','LH','airline_name','Lufthansa','flight_iata','LH1305'),
          'LH')
  on conflict (flight_no, flight_date) do nothing;

  v_out := public.flight_info('TK195B', current_date);
  if not coalesce((v_out ->> 'hit')::boolean, false) then
    delete from flight_cache where source = 'bekci';
    raise exception '195: flight_info onbellekteki satiri BULAMADI';
  end if;
  foreach k in array v_keys loop
    if not (v_out ? k) then v_eksik := v_eksik || k; end if;
  end loop;
  if array_length(v_eksik, 1) is not null then
    delete from flight_cache where source = 'bekci';
    raise exception '195: flight_info EKSIK anahtar donduruyor: %', array_to_string(v_eksik, ', ');
  end if;
  raise notice '195: flight_info % anahtarin hepsini donduruyor', array_length(v_keys,1);
end $$;

-- 2) KOD PAYLAŞIMI GERÇEKTEN ÇÖZÜLÜYOR MU
do $$
declare v jsonb;
begin
  v := public.flight_carrier_resolve('TK195B', current_date);
  if coalesce(v ->> 'carrier','') <> 'LH' then
    delete from flight_cache where source = 'bekci';
    raise exception '195: kod paylasimli ucusta ISLETEN tasiyici cozulmedi (beklenen LH, gelen %)', v ->> 'carrier';
  end if;
  if not coalesce((v ->> 'codeshare')::boolean, false) then
    delete from flight_cache where source = 'bekci';
    raise exception '195: codeshare bayragi FALSE — kod paylasimi tespit edilmiyor';
  end if;
  if coalesce(v ->> 'not','') = '' then
    delete from flight_cache where source = 'bekci';
    raise exception '195: kod paylasimi notu BOS — kullanici uyarilmiyor';
  end if;
  raise notice '195: kod paylasimi cozuldu — pazarlayan TK, isleten LH, not yazildi';
end $$;

-- 3) ÖNBELLEK YOKSA ÖNEKE DÜŞMELİ ve BUNU SÖYLEMELİ
do $$
declare v jsonb;
begin
  v := public.flight_carrier_resolve('XQ4242', current_date);
  if coalesce(v ->> 'carrier','') <> 'XQ' then
    raise exception '195: onbelleksiz ucusta onek okunmadi (gelen %)', v ->> 'carrier';
  end if;
  if coalesce(v ->> 'kaynak','') <> 'onek' then
    raise exception '195: varsayim VARSAYIM olarak etiketlenmiyor — kaynak %', v ->> 'kaynak';
  end if;
  raise notice '195: onbellek yoksa onege dusuyor ve bunu soyluyor';
end $$;

-- 4) same_sector KOLONU GERÇEKTEN VAR ve DEĞER ÜRETİYOR
do $$
declare v_n int;
begin
  -- Fonksiyon dönüş imzasından oku (information_schema fonksiyonu göstermez)
  if position('same_sector' in
       (select pg_get_function_result(oid) from pg_proc
         where proname = 'discover_availabilities'
           and pronamespace = 'public'::regnamespace limit 1)) = 0 then
    raise exception '195: discover_availabilities same_sector DONDURMUYOR';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from users where email like 'kmisafir1%' limit 1),
                      'role', 'authenticated')::text, true);
  select count(*) into v_n from public.discover_availabilities(null, null, null, null);
  perform set_config('request.jwt.claims', '{}', true);
  raise notice '195: same_sector kolonu imzada var, kesif % satir dondu', v_n;
end $$;

-- 5) ESKİ SÖZLEŞME BOZULMADI — flightSummary()'nin okuduğu iki alan
do $$
declare v jsonb;
begin
  v := public.flight_info('TK195B', current_date);
  if (v ->> 'scheduled_departure') is null or (v ->> 'terminal') is null then
    delete from flight_cache where source = 'bekci';
    raise exception '195: ESKI alanlar (scheduled_departure/terminal) kayboldu — flightSummary kirilir';
  end if;
  delete from flight_cache where source = 'bekci';
  raise notice '195: eski sozlesme korundu';
end $$;

select '195 OK - ucus alanlari tamamlandi, kod paylasimi cozuluyor, same_sector doniyor' as sonuc;
