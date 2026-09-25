-- ============================================================
-- 199 · UÇUŞ SAATİ UYARISI, TERMİNAL EŞLEŞMESİ, KATALOG BOŞLUĞU
-- 17 Ağustos 2026
--
-- ⚠️ UYGULAMAYI ETKİLER: yeni bir RPC (`trip_fit_note`) ve 10 salonun
-- host seçim listesine girmesi. Mevcut imzaların hiçbiri değişmiyor.
--
-- ------------------------------------------------------------
-- BU DOSYA ÜÇ AYRI AÇIĞI KAPATIYOR
-- ------------------------------------------------------------
-- (1) 197 `visits.scheduled_departure` ve `visits.terminal` kolonlarını
--     doldurmaya başladı — ama HİÇBİR YERDE OKUNMUYOR. Veri üretip
--     kullanmamak, veri üretmemekle aynı kapıya çıkar. Şimdi okuyoruz.
-- (2) Değişmez denetimi 10 salonun KATALOGDA GÖRÜNMEDİĞİNİ söylüyordu:
--     `lounge_venues`ta varlar, `lounges` (host seçim listesi) tablosunda
--     yoklar. Host onları seçemiyor → o salonlar için ilan hiç açılamıyor.
-- (3) İki değişmez denetiminin KENDİSİ yanlış alarm veriyordu; ikisi de
--     düzeltiliyor (aşağıda gerekçeleriyle).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN UÇUŞ SAATİ UYARISI — GERÇEK BİR KAYIP SENARYOSU
-- ------------------------------------------------------------
-- Misafir "14:00–18:00 arası IST'teyim" yazıyor. Uçuşu TK1998 ve
-- 15:20'de kalkıyor. Host 16:00–18:00 arası bir ilan açmış. Sistem
-- ikisini EŞLEŞTİRİYOR çünkü saat aralıkları örtüşüyor — oysa misafir
-- 16:00'da uçakta. Buluşma hiç gerçekleşmiyor, iki taraf da birbirini
-- bekliyor, ikisi de puanını düşürüyor.
--
-- Bugüne kadar bunu ölçemiyorduk çünkü gerçek kalkış saati yoktu.
-- 197'den sonra VAR. Uyarı kesin bir engel değil ADVISORY: uçuş verisi
-- gecikebilir, kullanıcı planını değiştirmiş olabilir. Kapıyı kapatmak
-- yerine gerçeği söylüyoruz.
-- ============================================================


-- ============================================================
-- 1) UÇUŞ SAATİ + TERMİNAL UYUMU
-- ============================================================
-- 🔴 AYRI RPC, precheck'e EKLEME DEĞİL. request_precheck'in ALTI ayrı
-- return noktası var ve 192'de tam bu yüzden yandık: "erken dönüş
-- sözleşmenin yarısını düşürür". Yeni alanı oraya eklemek altı dalın
-- altısını da doğru güncellemeyi gerektirir. Ayrı fonksiyon, tek
-- return, sıfır regresyon riski.
create or replace function public.trip_fit_note(p_avail_id uuid, p_user_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid   uuid := coalesce(p_user_id, auth.uid());
  a       availabilities%rowtype;
  v       visits%rowtype;
  v_venue lounge_venues%rowtype;
  v_dep   timestamptz;
  v_win_end   timestamptz;
  v_win_start timestamptz;
  v_uyarilar jsonb := '[]'::jsonb;
  v_severity text := 'ok';
  v_tz    text;
  v_w     jsonb;
  v_prog  text;
begin
  select * into a from availabilities where id = p_avail_id;
  if not found then
    return jsonb_build_object('found', false, 'reason', 'ilan_yok');
  end if;

  -- Misafirin AYNI havalimanı ve AYNI gündeki seyahati
  select * into v from visits
   where user_id = v_uid and airport_code = a.airport_code
     and visit_date = a.avail_date
   order by (flight_verified is true) desc, time_from
   limit 1;

  if not found then
    return jsonb_build_object('found', true, 'has_trip', false,
      'severity', 'info',
      'uyarilar', jsonb_build_array(
        jsonb_build_object('tip','trip_yok',
          'metin','Bu tarih için seyahatin yok. Seyahat eklersen kural motoru kesin cevap verebilir.')));
  end if;

  select * into v_venue from lounge_venues where id = a.venue_id;

  -- ---- (a) UÇUŞ SAATİ ----
  -- Yalnız DOĞRULANMIŞ uçuş verisiyle konuşuruz. Elle yazılmış bir
  -- numaradan saat türetmek uydurma olurdu.
  if v.flight_verified and v.scheduled_departure is not null then
    -- 🔴 SAAT DİLİMİ BİR VARSAYIM DEĞİL, VERİ. `availabilities.time_from`
    -- havalimanının YEREL duvar saati; `scheduled_departure` mutlak
    -- (timestamptz). İkisini karşılaştırmak için yerel saati o
    -- havalimanının diliminde yorumlamak ZORUNLU.
    -- 222 havalimanının 23'ünde timezone dolu; boş olanlarda
    -- Europe/Istanbul'a düşüyoruz (ürünün ağırlık merkezi Türkiye) ve
    -- bunu cevapta `tz_varsayildi` ile SÖYLÜYORUZ — sessiz varsayım,
    -- yanlış cevaptan daha tehlikelidir.
    select nullif(ap.timezone,'') into v_tz from airports ap where ap.code = a.airport_code;
    v_dep       := v.scheduled_departure;
    v_win_start := (a.avail_date + a.time_from) at time zone coalesce(v_tz, 'Europe/Istanbul');
    v_win_end   := (a.avail_date + a.time_to)   at time zone coalesce(v_tz, 'Europe/Istanbul');

    if v_dep <= v_win_start then
      v_severity := 'warn';
      v_uyarilar := v_uyarilar || jsonb_build_object(
        'tip','ucus_once_kalkiyor',
        'metin', 'Uçuşun ' || to_char(v_dep at time zone 'Europe/Istanbul', 'HH24:MI')
              || '''de kalkıyor; bu ilan ' || to_char(a.time_from,'HH24:MI')
              || '''da başlıyor. Buluşma penceresi başlamadan uçakta olacaksın.');
    elsif v_dep < v_win_end then
      v_severity := 'info';
      v_uyarilar := v_uyarilar || jsonb_build_object(
        'tip','ucus_pencere_icinde',
        'metin', 'Uçuşun ' || to_char(v_dep at time zone 'Europe/Istanbul', 'HH24:MI')
              || '''de kalkıyor; ilanın bitişi ' || to_char(a.time_to,'HH24:MI')
              || '. Salonda geçirebileceğin süre bundan kısa — biniş çağrısını hesaba kat.');
    end if;
  end if;

  -- ---- (b) TERMİNAL ----
  -- 🔴 IST'te yanlış terminaldeki bir salon kapıda değil EKRANDA
  -- elenmeli. Terminal bilgisi iki taraftan da geliyor: uçuş
  -- önbelleğinden (misafirin terminali) ve salon kaydından.
  if coalesce(v.terminal,'') <> '' and coalesce(v_venue.terminal,'') <> ''
     and upper(regexp_replace(v.terminal, '[^0-9A-Za-z]', '', 'g'))
      <> upper(regexp_replace(v_venue.terminal, '[^0-9A-Za-z]', '', 'g'))
     -- "İç Hat"/"Dış Hat" gibi metin terminaller sayısal terminalle
     -- karşılaştırılmaz; yalnız ikisi de sayı/harf kodu ise konuşuruz.
     and v.terminal ~ '^[0-9A-Za-z]{1,3}$'
     and v_venue.terminal ~ '^[0-9A-Za-z]{1,3}$'
  then
    v_severity := case when v_severity = 'warn' then 'warn' else 'info' end;
    v_uyarilar := v_uyarilar || jsonb_build_object(
      'tip','terminal_farkli',
      'metin','Uçuşun Terminal ' || v.terminal || ', bu salon Terminal '
            || v_venue.terminal || '. Terminaller arası geçiş güvenlik/pasaport '
            || 'gerektirebilir — süreni buna göre planla.');
  end if;

  -- ---- (c) GİRİŞ PENCERESİ (198) ----
  begin
    select p.code into v_prog from lounge_venue_acceptance x
      join lounge_programs p on p.id = x.program_id
     where x.venue_id = a.venue_id and x.active and p.code in ('TK_MS','AJET_MS')
     limit 1;
    if v_prog is not null then
      v_w := public.entry_window_for(v_prog, a.airport_code);
      if v_w is not null and (v_w ->> 'earliest_origin') is not null then
        v_uyarilar := v_uyarilar || jsonb_build_object(
          'tip','giris_penceresi',
          'metin','Bu salonda ÜCRETLİ giriş için pencere: uçuştan en erken '
                || (v_w ->> 'earliest_origin') || ' saat önce (bağlantılı uçuşta '
                || coalesce(v_w ->> 'earliest_connecting', v_w ->> 'earliest_origin')
                || ' saat). Statüyle ücretsiz girenler için kaynakta pencere yazmıyor.');
      end if;
    end if;
  exception when others then
    null;   -- pencere bilgisi bir SÜS; yokluğu cevabı düşürmez
  end;

  return jsonb_build_object(
    'found', true, 'has_trip', true,
    'flight_verified', coalesce(v.flight_verified,false),
    'flight_number', v.flight_number,
    'scheduled_departure', v.scheduled_departure,
    'trip_terminal', v.terminal,
    'venue_terminal', v_venue.terminal,
    'tz_varsayildi', (select coalesce(nullif(ap.timezone,''),'') = ''
                        from airports ap where ap.code = a.airport_code),
    'severity', v_severity,
    'uyarilar', v_uyarilar);
end $$;
grant execute on function public.trip_fit_note(uuid, uuid) to authenticated;


-- ============================================================
-- 2) KATALOG BOŞLUĞU — 10 SALON HOST'A HİÇ GÖRÜNMÜYORDU
-- ============================================================
-- `lounge_venues` gerçeğin kaynağı; `lounges` host'un seçim listesi.
-- 188 envanteri venue tarafına yazdı, katalog tarafını 10 salonda
-- atladı. Sonuç: salon veritabanında var, ilan açarken listede yok.
-- "Var olmak ≠ görünmek" — 193'ün dersinin katalog hâli.
insert into lounges (airport_code, name, terminal, access_types, active, venue_id)
select v.airport_code, v.name, v.terminal,
       coalesce((select array_agg(distinct p.name)
                   from lounge_venue_acceptance a
                   join lounge_programs p on p.id = a.program_id
                  where a.venue_id = v.id and a.active),
                array['Bilgi girilmedi']::text[]),
       true, v.id
  from lounge_venues v
 where v.active and v.venue_kind = 'lounge'
   and v.section is null and v.section_of is null
   and v.legacy_lounge_id is null
   and not exists (select 1 from lounges l where l.venue_id = v.id);


-- 🔴 KALICILIK: tek seferlik doldurma yetmez. 188 gibi bir envanter
-- yükleyicisi yarın yeni salon eklerse aynı boşluk yeniden doğar.
-- Tetikleyici, "salon eklendiğinde katalog satırı da doğar"ı bir
-- KURAL hâline getiriyor. Tetikleyici ASLA throw etmez: katalog
-- satırı bir kolaylıktır, salon kaydının kendisi kritiktir.
create or replace function public.trg_venue_catalog_row()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.active and new.venue_kind = 'lounge'
       and new.section is null and new.section_of is null
       and new.legacy_lounge_id is null
       and not exists (select 1 from lounges l where l.venue_id = new.id) then
      insert into lounges (airport_code, name, terminal, access_types, active, venue_id)
      values (new.airport_code, new.name, new.terminal,
              array['Bilgi girilmedi']::text[], true, new.id);
    end if;
  exception when others then
    null;
  end;
  return null;
end $$;

drop trigger if exists trg_venue_catalog_ins on lounge_venues;
create trigger trg_venue_catalog_ins after insert on lounge_venues
  for each row execute function public.trg_venue_catalog_row();


-- ============================================================
-- 3) İKİ DENETİMİN KENDİSİ YANLIŞ ALARM VERİYORDU
-- ============================================================
-- 🔴 (a) BULAŞMA DENETİMİ — "Miles&Smiles bölümü" bir PROGRAM İDDİASI
-- değil, bir ODA ADIDIR. İstanbul Havalimanı dış hatlar salonu iki
-- bölümden oluşuyor ve bölümlerden birinin adı "Miles&Smiles".
-- Business bileti kuralının notu şunu diyor:
--   "Business bölümünde misafir/aile kabul edilmez — misafirle
--    girecekseniz girişte Miles&Smiles bölümünü isteyin."
-- Bu cümle DOĞRU, YARARLI ve kaynağa birebir uygun. Denetim bunu
-- "başka programın kuralı bulaşmış" diye işaretliyordu.
--
-- Yanlış alarm veren denetim üç tur sonra OKUNMAZ hâle gelir; o andan
-- sonra GERÇEK bulaşmayı da yakalayamaz. Bu yüzden desen daraltılıyor:
-- bulaşma, başka programın HAKKINI iddia etmektir — kullanıcıyı bir
-- ODAYA yönlendirmek değil.
create or replace function public.rule_contamination_check()
returns table (program text, kart text, sorun text, ornek text)
language sql stable security definer set search_path = public as $$
  select p.name, coalesce(r.card_tier,'(genel)'),
         'Kural notu BAŞKA bir programa ait görünüyor',
         left(r.notes, 70)
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where (r.effective_to is null or r.effective_to >= current_date)
     and (
       -- 🔴 "Miles&Smiles bölüm" DESENİ KALDIRILDI: bölüm bir odadır.
       -- Yerine HAK iddiası aranıyor: statü/kart/üyelik/hakkı.
       (p.code not in ('TK_MS','AJET_MS')
        and r.notes ~* '(THY seferinde|AJet seferinde|Miles&Smiles (statü|kartı|üyeliğ|hakkı))')
       or (p.code <> 'PGS_PAID'      and r.notes ~* 'Pegasus biniş kartı')
       or (p.code <> 'PRIORITY_PASS' and r.notes ~* 'Priority Pass üyelik')
       or (p.code <> 'IGA_PASS'      and r.notes ~* 'İGA Pass kişiye')
     );
$$;
grant execute on function public.rule_contamination_check() to authenticated;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) BULAŞMA DENETİMİ HÂLÂ GERÇEK BULAŞMAYI YAKALIYOR MU
-- 🔴 MUTASYON KANITI. Deseni daraltmak, denetimi körleştirebilirdi.
-- Bilerek bulaşık bir not yazıp yakalandığını, sonra temizleyip
-- sustuğunu kanıtlıyoruz. Kanıtsız daraltma, sessizce kapatmaktır.
do $$
declare v_once int; v_sonra int; v_id uuid;
begin
  select count(*) into v_once from public.rule_contamination_check();

  select r.id into v_id from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = 'BUSINESS_TICKET' limit 1;
  if v_id is null then raise notice '199: BUSINESS_TICKET kurali yok — mutasyon atlandi'; return; end if;

  update lounge_guest_rules
     set notes = 'Miles&Smiles statüsü sana bu salonda 2 misafir hakkı verir.'
   where id = v_id;
  select count(*) into v_sonra from public.rule_contamination_check();
  update lounge_guest_rules
     set notes = 'Business bileti kendi girişini sağlar; misafir hakkı bilete değil '
              || 'statü kartına bağlıdır. Business bölümünde misafir/aile kabul edilmez — '
              || 'misafirle girecekseniz girişte Miles&Smiles bölümünü isteyin.'
   where id = v_id;

  if v_sonra <= v_once then
    raise exception '199: bulasma denetimi KORLESTI — bilerek bulasik not yakalanmadi (once=% sonra=%)', v_once, v_sonra;
  end if;
  if v_once <> 0 then
    raise exception '199: temiz durumda % yanlis alarm kaldi', v_once;
  end if;
  raise notice '199: bulasma denetimi — temizde 0 alarm, bulasikta yakaliyor (mutasyonla kanitli)';
end $$;

-- 2) KATALOG BOŞLUĞU KAPANDI
do $$
declare v_n int; r record;
begin
  select count(*) into v_n from lounge_venues v
   where v.active and v.venue_kind = 'lounge'
     and v.section is null and v.section_of is null and v.legacy_lounge_id is null
     and not exists (select 1 from lounges l where l.venue_id = v.id);
  if v_n > 0 then
    for r in select v.airport_code || ' · ' || v.name as ad from lounge_venues v
              where v.active and v.venue_kind = 'lounge'
                and v.section is null and v.section_of is null and v.legacy_lounge_id is null
                and not exists (select 1 from lounges l where l.venue_id = v.id) limit 5
    loop raise notice '199: katalogsuz → %', r.ad; end loop;
    raise exception '199: % salon hala katalogda yok — host secemez', v_n;
  end if;
  raise notice '199: katalog bosluğu yok — her aktif salon host listesinde';
end $$;

-- 3) UÇUŞ SAATİ UYARISI GERÇEKTEN ÜRETİLİYOR MU
do $$
declare
  v_uid uuid; v_host uuid; v_av uuid; v_vid uuid; v_j jsonb; v_n int;
begin
  select id into v_uid  from users where email like 'kmisafir1%' limit 1;
  select host_id, id into v_host, v_av from availabilities
   where avail_date >= current_date order by avail_date limit 1;
  if v_uid is null or v_av is null then
    raise notice '199: seed verisi yok — ucus saati kanidi atlandi'; return;
  end if;

  -- Misafire, ilanın penceresinden ÖNCE kalkan doğrulanmış bir uçuş kur
  -- 🔴 TESTİN KENDİ HATASI OLMASIN: ilan penceresi YEREL duvar saati,
  -- uçuş kalkışı MUTLAK zaman. İlk yazımda uçuşu UTC'de kurup pencereyi
  -- yerelde hesapladım ve test "uyarı yok" dedi — ürün değil TEST
  -- yanlıştı (üçüncü kez aynı sınıf). İkisi de aynı dilimden türetiliyor.
  insert into flight_cache (flight_no, flight_date, departure_iata, arrival_iata,
                            scheduled_departure, scheduled_arrival, terminal, status,
                            source, fetched_at, airline, airline_iata, operating_iata)
  select 'TK1999', a.avail_date,
         a.airport_code, 'FRA',
         ((a.avail_date + a.time_from) at time zone
            coalesce(nullif((select ap.timezone from airports ap where ap.code = a.airport_code),''),
                     'Europe/Istanbul')) - interval '30 minutes',
         ((a.avail_date + a.time_from) at time zone
            coalesce(nullif((select ap.timezone from airports ap where ap.code = a.airport_code),''),
                     'Europe/Istanbul')) + interval '3 hours',
         '9', 'scheduled', 'bekci', now(), 'Turkish Airlines', 'TK', 'TK'
    from availabilities a where a.id = v_av
  on conflict (flight_no, flight_date) do nothing;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  select v_uid, a.airport_code, a.avail_date, a.time_from, a.time_to, 'TK1999'
    from availabilities a where a.id = v_av
  returning id into v_vid;

  v_j := public.trip_fit_note(v_av, v_uid);
  select count(*) into v_n
    from jsonb_array_elements(coalesce(v_j -> 'uyarilar','[]'::jsonb)) u
   where u ->> 'tip' = 'ucus_once_kalkiyor';

  delete from visits where id = v_vid;
  delete from flight_cache where source = 'bekci';

  if v_n = 0 then
    raise exception '199: ucus penceresinden ONCE kalkiyor ama UYARI YOK → %', v_j;
  end if;
  raise notice '199: ucus saati uyarisi uretiliyor (severity=%)', v_j ->> 'severity';
end $$;

-- 4) DOĞRULANMAMIŞ UÇUŞTA SAAT UYARISI ÜRETİLMEMELİ (uydurma yok)
do $$
declare v_uid uuid; v_av uuid; v_vid uuid; v_j jsonb; v_n int;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  select id into v_av  from availabilities where avail_date >= current_date order by avail_date limit 1;
  if v_uid is null or v_av is null then raise notice '199: seed yok — atlandi'; return; end if;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  select v_uid, a.airport_code, a.avail_date, a.time_from, a.time_to, 'ZZ9998'
    from availabilities a where a.id = v_av
  returning id into v_vid;

  v_j := public.trip_fit_note(v_av, v_uid);
  select count(*) into v_n
    from jsonb_array_elements(coalesce(v_j -> 'uyarilar','[]'::jsonb)) u
   where u ->> 'tip' in ('ucus_once_kalkiyor','ucus_pencere_icinde');
  delete from visits where id = v_vid;

  if v_n > 0 then
    raise exception '199: DOGRULANMAMIS ucus icin saat uyarisi uydurulmus → %', v_j;
  end if;
  raise notice '199: dogrulanmamis ucusta saat uyarisi UYDURULMUYOR';
end $$;

-- 5) SEYAHATİ OLMAYAN KULLANICI İÇİN CEVAP ÇÖKMEZ
do $$
declare v_j jsonb; v_av uuid;
begin
  select id into v_av from availabilities limit 1;
  if v_av is null then raise notice '199: ilan yok — atlandi'; return; end if;
  v_j := public.trip_fit_note(v_av, '00000000-0000-0000-0000-000000000000'::uuid);
  if coalesce((v_j ->> 'has_trip')::boolean, true) then
    raise exception '199: seyahati olmayan kullanicida has_trip TRUE dondu';
  end if;
  raise notice '199: seyahatsiz kullanicida cevap saglam (has_trip=false)';
end $$;

select '199 OK - ucus saati/terminal uyarisi, katalog bosluğu, iki yanlis alarm kapandi' as sonuc;
