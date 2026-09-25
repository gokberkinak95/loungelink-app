-- ============================================================
-- 202 · SAAT DİLİMİ VERİSİ · AJet DIŞ HAT ANAHTARI · PENCERE İLGİSİ
-- 17 Ağustos 2026
--
-- ⚠️ UYGULAMAYI ETKİLER: uçuş saati uyarısı artık 222 havalimanının
-- HEPSİNDE doğru dilimde hesaplanıyor ve giriş penceresi uyarısı
-- yalnız ÜCRETLİ girecek kişiye gösteriliyor.
--
-- Üç açık madde bu dosyada kapanıyor:
--   (8) Giriş penceresi uyarısı ücretli/ücretsiz ayrılmıyordu
--   (9) AJet dış hat kapsamı SQL değişikliği gerektiriyordu
--  (10) 222 havalimanının yalnız 23'ünde saat dilimi kayıtlıydı
-- ============================================================


-- ============================================================
-- 1) SAAT DİLİMİ — 23/222'den 222/222'ye
-- ============================================================
-- 🔴 KAYNAK: IANA tz veritabanının IATA eşlemesi (`airportsdata`
-- paketi, 7.884 havalimanı). Uydurma yok — 220 havalimanı doğrudan
-- eşleşti ve MEVCUT 23 kayıtla ÇELİŞEN TEK SATIR ÇIKMADI. Bu, hem
-- yeni verinin hem eski verinin doğrulanması demek.
--
-- Kalan 2 havalimanı (FRU Bişkek, PNH Phnom Penh) pakette IATA
-- anahtarıyla yoktu; ikisi de tek dilimli ülkelerin başkent
-- havalimanı ve dilimleri tartışmasız (Asia/Bishkek, Asia/Phnom_Penh).
-- Bunları da yazıyorum ama AYRI bir blokta, çünkü kaynağı farklı.
--
-- NEDEN ÖNEMLİ: `availabilities.time_from` havalimanının YEREL duvar
-- saati, `flight_cache.scheduled_departure` MUTLAK zaman. Dilim
-- bilinmeden ikisi karşılaştırılamaz. 199 eksik dilimde Türkiye'ye
-- düşüyordu ve bunu söylüyordu — dürüst ama yanlış: Londra'daki bir
-- ilanda 3 saat, New York'ta 7 saat sapma demek.
-- 🔴 GEÇİCİ TABLO YOK — 099'UN DERSİ BURADA DA GEÇERLİ.
-- Gökberk canlıda şunu aldı:
--     ERROR 42P01: relation "_tz_src" does not exist
-- Sebep: Supabase SQL Editor ifadeleri AYRI BAĞLANTILARDA
-- çalıştırabiliyor. `create temporary table` bir ifadede yaratılıp
-- diğerinde okunuyorsa, ikinci ifade tabloyu göremiyor. psql tek
-- oturumda çalıştığı için harness'ta hiç görünmedi.
--
-- 099 bu tuzağa ÇOKTAN düşmüş ve dosyasına yazmış:
--   "Once `create temp table` denedim ... 42P01 verdi. Sonra GERCEK
--    tabloya cevirdim; ayni hatayi verdi. Kok cozum: ifadeler arasi
--    bagimliligi TAMAMEN kaldirmak."
-- Ben o dersi 202'ye taşımamışım. Liste artık UPDATE'in KENDİ içinde
-- bir CTE; hiçbir ifade bir öncekinin yan etkisine bağlı değil ve
-- dosya baştan sona tekrar çalıştırılabilir.
--
-- `distinct on (code)`: eski `on conflict (code) do nothing` yinelenen
-- kodları eliyordu; CTE'de o güvenlik ağı yok, yerine bu kondu.
with _tz_src(code, tz) as (
  select distinct on (code) code, tz
    from (values
('ABJ','Africa/Abidjan'),
  ('ABV','Africa/Lagos'),
  ('ACC','Africa/Accra'),
  ('ADA','Europe/Istanbul'),
  ('ADB','Europe/Istanbul'),
  ('ADD','Africa/Addis_Ababa'),
  ('AGP','Europe/Madrid'),
  ('ALA','Asia/Almaty'),
  ('ALG','Africa/Algiers'),
  ('AMM','Asia/Amman'),
  ('AMS','Europe/Amsterdam'),
  ('AQJ','Asia/Amman'),
  ('ASR','Europe/Istanbul'),
  ('ATH','Europe/Athens'),
  ('ATL','America/New_York'),
  ('AUH','Asia/Dubai'),
  ('AYT','Europe/Istanbul'),
  ('BAH','Asia/Bahrain'),
  ('BCN','Europe/Madrid'),
  ('BEG','Europe/Belgrade'),
  ('BER','Europe/Berlin'),
  ('BEY','Asia/Beirut'),
  ('BGW','Asia/Baghdad'),
  ('BHX','Europe/London'),
  ('BIO','Europe/Madrid'),
  ('BJL','Africa/Banjul'),
  ('BJV','Europe/Istanbul'),
  ('BKK','Asia/Bangkok'),
  ('BKO','Africa/Bamako'),
  ('BLL','Europe/Copenhagen'),
  ('BLQ','Europe/Rome'),
  ('BOD','Europe/Paris'),
  ('BOG','America/Bogota'),
  ('BOM','Asia/Kolkata'),
  ('BOS','America/New_York'),
  ('BRE','Europe/Berlin'),
  ('BRI','Europe/Rome'),
  ('BRU','Europe/Brussels'),
  ('BSL','Europe/Paris'),
  ('BSR','Asia/Baghdad'),
  ('BUD','Europe/Budapest'),
  ('BUS','Asia/Tbilisi'),
  ('CAI','Africa/Cairo'),
  ('CAN','Asia/Shanghai'),
  ('CCS','America/Caracas'),
  ('CDG','Europe/Paris'),
  ('CEB','Asia/Manila'),
  ('CGK','Asia/Jakarta'),
  ('CGN','Europe/Berlin'),
  ('CKY','Africa/Conakry'),
  ('CLJ','Europe/Bucharest'),
  ('CMB','Asia/Colombo'),
  ('CMN','Africa/Casablanca'),
  ('COO','Africa/Porto-Novo'),
  ('COV','Europe/Istanbul'),
  ('CPH','Europe/Copenhagen'),
  ('CPT','Africa/Johannesburg'),
  ('CTA','Europe/Rome'),
  ('CUN','America/Cancun'),
  ('DAC','Asia/Dhaka'),
  ('DAR','Africa/Dar_es_Salaam'),
  ('DBV','Europe/Zagreb'),
  ('DEL','Asia/Kolkata'),
  ('DEN','America/Denver'),
  ('DFW','America/Chicago'),
  ('DIY','Europe/Istanbul'),
  ('DLA','Africa/Douala'),
  ('DLM','Europe/Istanbul'),
  ('DMM','Asia/Riyadh'),
  ('DOH','Asia/Qatar'),
  ('DPS','Asia/Makassar'),
  ('DSS','Africa/Dakar'),
  ('DTW','America/New_York'),
  ('DUR','Africa/Johannesburg'),
  ('DUS','Europe/Berlin'),
  ('DXB','Asia/Dubai'),
  ('EBB','Africa/Kampala'),
  ('EBL','Asia/Baghdad'),
  ('ECN','Asia/Nicosia'),
  ('EDI','Europe/London'),
  ('ESB','Europe/Istanbul'),
  ('EWR','America/New_York'),
  ('EZE','America/Argentina/Buenos_Aires'),
  ('FCO','Europe/Rome'),
  ('FIH','Africa/Kinshasa'),
  ('FNA','Africa/Freetown'),
  ('FRA','Europe/Berlin'),
  ('GOT','Europe/Stockholm'),
  ('GRU','America/Sao_Paulo'),
  ('GVA','Europe/Zurich'),
  ('GYD','Asia/Baku'),
  ('GZT','Europe/Istanbul'),
  ('HAJ','Europe/Berlin'),
  ('HAM','Europe/Berlin'),
  ('HAN','Asia/Ho_Chi_Minh'),
  ('HAV','America/Havana'),
  ('HBE','Africa/Cairo'),
  ('HEL','Europe/Helsinki'),
  ('HKG','Asia/Hong_Kong'),
  ('HKT','Asia/Bangkok'),
  ('HND','Asia/Tokyo'),
  ('HRG','Africa/Cairo'),
  ('HTY','Europe/Istanbul'),
  ('IAD','America/New_York'),
  ('IAH','America/Chicago'),
  ('ICN','Asia/Seoul'),
  ('ISB','Asia/Karachi'),
  ('IST','Europe/Istanbul'),
  ('JFK','America/New_York'),
  ('JIB','Africa/Djibouti'),
  ('JNB','Africa/Johannesburg'),
  ('JRO','Africa/Dar_es_Salaam'),
  ('KBL','Asia/Kabul'),
  ('KGL','Africa/Kigali'),
  ('KHI','Asia/Karachi'),
  ('KIX','Asia/Tokyo'),
  ('KRK','Europe/Warsaw'),
  ('KRT','Africa/Khartoum'),
  ('KTM','Asia/Kathmandu'),
  ('KUL','Asia/Kuala_Lumpur'),
  ('KWI','Asia/Kuwait'),
  ('KZN','Europe/Moscow'),
  ('LAD','Africa/Luanda'),
  ('LAX','America/Los_Angeles'),
  ('LBV','Africa/Libreville'),
  ('LED','Europe/Moscow'),
  ('LGW','Europe/London'),
  ('LHE','Asia/Karachi'),
  ('LHR','Europe/London'),
  ('LIS','Europe/Lisbon'),
  ('LJU','Europe/Ljubljana'),
  ('LOS','Africa/Lagos'),
  ('LUN','Africa/Lusaka'),
  ('LUX','Europe/Luxembourg'),
  ('LYS','Europe/Paris'),
  ('MAD','Europe/Madrid'),
  ('MAN','Europe/London'),
  ('MCT','Asia/Muscat'),
  ('MED','Asia/Riyadh'),
  ('MEL','Australia/Melbourne'),
  ('MEX','America/Mexico_City'),
  ('MIA','America/New_York'),
  ('MLA','Europe/Malta'),
  ('MLE','Indian/Maldives'),
  ('MNL','Asia/Manila'),
  ('MPM','Africa/Maputo'),
  ('MRA','Africa/Tripoli'),
  ('MRS','Europe/Paris'),
  ('MRU','Indian/Mauritius'),
  ('MUC','Europe/Berlin'),
  ('MXP','Europe/Rome'),
  ('NAP','Europe/Rome'),
  ('NBO','Africa/Nairobi'),
  ('NCE','Europe/Paris'),
  ('NDJ','Africa/Ndjamena'),
  ('NIM','Africa/Niamey'),
  ('NKC','Africa/Nouakchott'),
  ('NRT','Asia/Tokyo'),
  ('NSI','Africa/Douala'),
  ('NUE','Europe/Berlin'),
  ('OHD','Europe/Skopje'),
  ('OPO','Europe/Lisbon'),
  ('ORD','America/Chicago'),
  ('ORN','Africa/Algiers'),
  ('OSL','Europe/Oslo'),
  ('OTP','Europe/Bucharest'),
  ('OUA','Africa/Ouagadougou'),
  ('PEK','Asia/Shanghai'),
  ('PMO','Europe/Rome'),
  ('PNR','Africa/Brazzaville'),
  ('PRG','Europe/Prague'),
  ('PRN','Europe/Belgrade'),
  ('PTY','America/Panama'),
  ('PVG','Asia/Shanghai'),
  ('RAK','Africa/Casablanca'),
  ('RIX','Europe/Riga'),
  ('RUH','Asia/Riyadh'),
  ('RZV','Europe/Istanbul'),
  ('SAW','Europe/Istanbul'),
  ('SCL','America/Santiago'),
  ('SEA','America/Los_Angeles'),
  ('SEZ','Indian/Mahe'),
  ('SFO','America/Los_Angeles'),
  ('SGN','Asia/Ho_Chi_Minh'),
  ('SHJ','Asia/Dubai'),
  ('SIN','Asia/Singapore'),
  ('SJJ','Europe/Sarajevo'),
  ('SKG','Europe/Athens'),
  ('SKP','Europe/Skopje'),
  ('SOF','Europe/Sofia'),
  ('SSH','Africa/Cairo'),
  ('STR','Europe/Berlin'),
  ('SZG','Europe/Vienna'),
  ('TAS','Asia/Samarkand'),
  ('TBS','Asia/Tbilisi'),
  ('TBZ','Asia/Tehran'),
  ('TIA','Europe/Tirane'),
  ('TIF','Asia/Riyadh'),
  ('TLL','Europe/Tallinn'),
  ('TLS','Europe/Paris'),
  ('TNR','Indian/Antananarivo'),
  ('TPE','Asia/Taipei'),
  ('TRN','Europe/Rome'),
  ('TSR','Europe/Bucharest'),
  ('TUN','Africa/Tunis'),
  ('TZX','Europe/Istanbul'),
  ('UBN','Asia/Ulaanbaatar'),
  ('VAR','Europe/Sofia'),
  ('VCE','Europe/Rome'),
  ('VIE','Europe/Vienna'),
  ('VKO','Europe/Moscow'),
  ('VLC','Europe/Madrid'),
  ('VNO','Europe/Vilnius'),
  ('WAW','Europe/Warsaw'),
  ('YUL','America/Toronto'),
  ('YVR','America/Vancouver'),
  ('YYZ','America/Toronto'),
  ('ZAG','Europe/Zagreb'),
  ('ZNZ','Africa/Dar_es_Salaam'),
  ('ZRH','Europe/Zurich')
    ) v(code, tz)
   order by code
)
update airports a set timezone = s.tz
  from _tz_src s
 where a.code = s.code
   and coalesce(a.timezone,'') is distinct from s.tz;

update airports set timezone = 'Asia/Bishkek'     where code = 'FRU' and coalesce(timezone,'') = '';
update airports set timezone = 'Asia/Phnom_Penh'  where code = 'PNH' and coalesce(timezone,'') = '';


-- ============================================================
-- 2) AJet DIŞ HAT — SQL DEĞİL, BO ANAHTARI
-- ============================================================
-- 🔴 Tur 5'te "AJet'e sorulup netleşirse tek satırlık iş" yazmıştım.
-- Ama o tek satır bir SQL dosyası, bir migration, bir deploy demek —
-- yani cevabı öğrenen kişi (Gökberk) onu tek başına uygulayamıyor.
-- Bilinmezliğin çözümünü koda gömmek, çözümü kilitlemektir.
--
-- Artık cevap bir AYAR: BO'dan üç değerden biri seçilir ve motor
-- kendini ona göre kurar. Kaynak öğrenildiğinde deploy gerekmez.
--
--   unknown → bugünkü davranış: 0 misafir + "hakkın var, salon
--             kapsamı kaynakta yazmıyor, teyit ettir"
--   yes     → 1 misafir + aile (iç hattaki gibi)
--   no      → 0 misafir + "AJet dış hat salonlarında misafir hakkı yok"
insert into beta_settings (key, value)
values ('ajet_intl_guest_right', to_jsonb('unknown'::text))
on conflict (key) do nothing;

create or replace function public.apply_ajet_intl_policy()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_pol text := coalesce((select value #>> '{}' from beta_settings where key='ajet_intl_guest_right'), 'unknown');
  v_g int; v_f boolean; v_note text; v_n int;
begin
  if v_pol not in ('unknown','yes','no') then
    raise exception 'gecersiz_politika';
  end if;

  if v_pol = 'yes' then
    v_g := 1; v_f := true;
    v_note := 'AJet dış hat / yurt dışı salonlarında da aile veya bir misafir hakkın var '
           || '(AJet''ten teyit alındı — BO ayarı: ajet_intl_guest_right=yes). '
           || 'Misafirin de AJet seferinde seyahat etmesi gerekir.';
  elsif v_pol = 'no' then
    v_g := 0; v_f := false;
    v_note := 'AJet dış hat / yurt dışı salonlarında misafir hakkı YOKTUR '
           || '(AJet''ten teyit alındı — BO ayarı: ajet_intl_guest_right=no). '
           || 'Kendi girişin etkilenmez.';
  else
    v_g := 0; v_f := false;
    v_note := 'Miles&Smiles statü sayfası "AJet uçuşlarında eş ile çocuklar veya bir '
           || 'misafirle özel yolcu salonlarından yararlanabilme" diyor ve kapsam '
           || 'koymuyor — yani HAKKIN VAR. Ancak AJet''in salon listesi yalnız İÇ HAT '
           || 'salonlarını sayıyor; bu salonun listede olup olmadığı kaynakta YAZMIYOR. '
           || 'Bu yüzden burada söz vermiyoruz: misafirle girmeyi planlıyorsan kapıda '
           || 'ya da AJet''e teyit ettir.';
  end if;

  update lounge_guest_rules r
     set guest_allowance = v_g, family_allowed = v_f, notes = v_note
    from lounge_programs p
   where r.program_id = p.id and p.code = 'AJET_MS'
     and r.card_tier in ('ELITE','ELPL','MS_EC')
     and coalesce(r.venue_scope,'') in ('international','abroad')
     and (r.effective_to is null or r.effective_to >= current_date);
  get diagnostics v_n = row_count;

  return jsonb_build_object('politika', v_pol, 'guncellenen_kural', v_n,
                            'guest_allowance', v_g, 'family_allowed', v_f);
end $$;
grant execute on function public.apply_ajet_intl_policy() to authenticated;

-- Ayar değişince kuralı KENDİLİĞİNDEN uygula. 🔴 Aksi hâlde BO'da
-- ayar değişir, kural eski kalır ve kimse fark etmez — "ayar var ama
-- bağlı değil" tam da bu turlarda dört kez yaşadığımız sınıf.
create or replace function public.trg_ajet_intl_setting()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.key = 'ajet_intl_guest_right' then
      perform public.apply_ajet_intl_policy();
    end if;
  exception when others then
    null;   -- ayar yazımı ASLA düşmez
  end;
  return null;
end $$;

drop trigger if exists trg_ajet_intl on beta_settings;
create trigger trg_ajet_intl after insert or update on beta_settings
  for each row execute function public.trg_ajet_intl_setting();

-- Mevcut ayarı bir kez uygula (kurulumdan sonraki ilk hizalama)
select public.apply_ajet_intl_policy();


-- ============================================================
-- 3) GİRİŞ PENCERESİ — YALNIZ ÜCRETLİ GİRECEK KİŞİYE
-- ============================================================
-- 🔴 Kaynak pencereyi "salon kullanım hizmetini SATIN ALAN yolcular"
-- için yazıyor. 199 bunu doğru anlamıştı ama YANLIŞ KİŞİYE
-- gösteriyordu: statüsüyle ücretsiz girecek bir Elite Plus host'a da
-- "ücretli giriş için pencere şudur" diyordu. Doğru bilgi, yanlış
-- kişi — ve okunmayan bir uyarıya dönüşüyor.
--
-- Artık pencere, kişinin O SALONDAKİ kararına bakıyor:
--   guest_policy = 'paid' ya da hiç hakkı yok  → pencere GÖSTERİLİR
--   statüyle ücretsiz giriyor                  → pencere GİZLENİR
create or replace function public.entry_window_relevant(p_avail_id uuid, p_user_id uuid default null)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := coalesce(p_user_id, auth.uid());
  a     availabilities%rowtype;
  v_dec jsonb;
  v_best jsonb;
begin
  select * into a from availabilities where id = p_avail_id;
  if not found then return false; end if;

  -- Kişinin bu salonda GEÇERLİ bir hakkı var mı ve ücretsiz mi?
  begin
    v_best := public.best_access_for_user(v_uid, a.venue_id, a.carrier, a.flight_number);
    if coalesce(v_best ->> 'guest_policy','') = 'included' then
      return false;   -- statüyle ücretsiz giriyor → ücretli pencere ONU İLGİLENDİRMİYOR
    end if;
  exception when others then
    v_best := null;   -- çözülemezse aşağıdaki genel karara düş
  end;

  begin
    v_dec := public.lounge_access_decision(p_avail_id, a.flight_number);
    if coalesce(v_dec ->> 'guest_policy','') = 'included' then
      return false;
    end if;
  exception when others then
    null;
  end;

  return true;   -- ücretli ya da bilinmiyor → pencere BİLGİSİ İŞE YARAR
end $$;
grant execute on function public.entry_window_relevant(uuid, uuid) to authenticated;

-- 199'un trip_fit_note'unu bu kapıya bağla. 🔴 Fonksiyonun geri kalanı
-- AYNEN duruyor; yalnız pencere bloğu koşullu hâle geliyor.
do $$
declare v_src text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'trip_fit_note' and pronamespace = 'public'::regnamespace;
  if v_src is null then raise exception '202: trip_fit_note yok'; end if;

  v_src := replace(v_src,
    'if v_prog is not null then',
    'if v_prog is not null and public.entry_window_relevant(p_avail_id, v_uid) then');

  if position('entry_window_relevant' in v_src) = 0 then
    raise exception '202: pencere kapisi trip_fit_note''a BAGLANAMADI (desen bulunamadi)';
  end if;

  execute 'create or replace function public.trip_fit_note(p_avail_id uuid, p_user_id uuid default null) '
       || 'returns jsonb language plpgsql stable security definer set search_path = public as $BODY$'
       || v_src || '$BODY$';
  raise notice '202: giris penceresi artik yalniz UCRETLI girecek kisiye gosteriliyor';
end $$;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) SALONU OLAN HER HAVALİMANINDA SAAT DİLİMİ OLMALI
do $$
declare v_n int; r record;
begin
  select count(distinct ap.code) into v_n
    from airports ap
    join lounge_venues v on v.airport_code = ap.code and v.active
   where coalesce(ap.timezone,'') = '';
  if v_n > 0 then
    for r in select distinct ap.code, ap.city from airports ap
              join lounge_venues v on v.airport_code = ap.code and v.active
             where coalesce(ap.timezone,'') = '' limit 8
    loop raise notice '202: dilimsiz → % (%)', r.code, r.city; end loop;
    raise exception '202: salonu olan % havalimaninda saat dilimi YOK', v_n;
  end if;
  select count(*) into v_n from airports where coalesce(timezone,'') <> '';
  raise notice '202: % havalimaninda saat dilimi dolu (222 bekleniyor)', v_n;
end $$;

-- 2) SAAT DİLİMLERİ GERÇEK Mİ (PostgreSQL tanıyor mu)
-- 🔴 "Doldurdum" demek yetmez: geçersiz bir dilim adı `at time zone`
-- çağrısında ÇALIŞMA ANINDA patlar ve uyarıyı sessizce öldürür.
do $$
declare r record; v_kotu text := '';
begin
  for r in select distinct timezone from airports where coalesce(timezone,'') <> '' loop
    begin
      perform now() at time zone r.timezone;
    exception when others then
      v_kotu := v_kotu || r.timezone || ' ';
    end;
  end loop;
  if v_kotu <> '' then
    raise exception '202: PostgreSQL su dilimleri TANIMIYOR → %', v_kotu;
  end if;
  raise notice '202: butun saat dilimleri PostgreSQL tarafindan taniniyor';
end $$;

-- 3) DİLİM GERÇEKTEN HESABI DEĞİŞTİRİYOR MU (mutasyon)
do $$
declare v_ist timestamptz; v_lon timestamptz;
begin
  v_ist := (current_date + time '13:00') at time zone
           (select timezone from airports where code = 'IST');
  v_lon := (current_date + time '13:00') at time zone
           (select timezone from airports where code = 'LHR');
  if v_ist = v_lon then
    raise exception '202: IST ve LHR ayni mutlak zamana cozuluyor — dilim uygulanmiyor';
  end if;
  raise notice '202: dilim hesabi calisiyor (IST ile LHR arasi % saat)',
    extract(epoch from (v_lon - v_ist)) / 3600;
end $$;

-- 4) AJet ANAHTARI GERÇEKTEN KURALI DEĞİŞTİRİYOR MU (mutasyon)
do $$
declare v_g int; v_eski text;
begin
  select value #>> '{}' into v_eski from beta_settings where key = 'ajet_intl_guest_right';

  update beta_settings set value = to_jsonb('yes'::text) where key = 'ajet_intl_guest_right';
  select max(coalesce(r.guest_allowance,0)) into v_g
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where p.code = 'AJET_MS' and r.card_tier in ('ELITE','ELPL','MS_EC')
     and coalesce(r.venue_scope,'') in ('international','abroad');
  if coalesce(v_g,0) <> 1 then
    update beta_settings set value = to_jsonb(v_eski) where key = 'ajet_intl_guest_right';
    raise exception '202: ayar "yes" yapildi ama kural degismedi (misafir %)', v_g;
  end if;

  update beta_settings set value = to_jsonb(v_eski) where key = 'ajet_intl_guest_right';
  select max(coalesce(r.guest_allowance,0)) into v_g
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where p.code = 'AJET_MS' and r.card_tier in ('ELITE','ELPL','MS_EC')
     and coalesce(r.venue_scope,'') in ('international','abroad');
  if coalesce(v_g,0) <> 0 then
    raise exception '202: ayar geri alindi ama kural "yes" hali kaldi (misafir %)', v_g;
  end if;
  raise notice '202: AJet dis hat anahtari kurali GERCEKTEN degistiriyor (deploy gerekmez)';
end $$;

-- 5) PENCERE İLGİSİ: ücretsiz girene GÖSTERİLMEMELİ
do $$
declare v_av uuid; v_uid uuid; v_ilgili boolean;
begin
  select id into v_av from availabilities where venue_id is not null limit 1;
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_av is null or v_uid is null then
    raise notice '202: seed yok — pencere ilgisi kanidi atlandi'; return;
  end if;
  v_ilgili := public.entry_window_relevant(v_av, v_uid);
  -- Hakkı olmayan/ücretli olan kullanıcıda TRUE beklenir; kural
  -- verisine göre değişebileceği için sonucu YARGILAMIYORUZ, yalnız
  -- fonksiyonun ÇAĞRILABİLDİĞİNİ ve boolean döndürdüğünü kanıtlıyoruz.
  if v_ilgili is null then
    raise exception '202: entry_window_relevant NULL dondu';
  end if;
  raise notice '202: pencere ilgisi cagrilabiliyor (bu ornekte %)', v_ilgili;
end $$;

-- 6) trip_fit_note HÂLÂ ÇALIŞIYOR (gövde yeniden yazıldı — kanıt şart)
do $$
declare v_av uuid; v jsonb;
begin
  select id into v_av from availabilities limit 1;
  if v_av is null then raise notice '202: ilan yok — atlandi'; return; end if;
  v := public.trip_fit_note(v_av, '00000000-0000-0000-0000-000000000000'::uuid);
  if coalesce(v ->> 'found','') <> 'true' then
    raise exception '202: trip_fit_note govdesi yeniden yazildiktan sonra BOZULDU → %', v;
  end if;
  raise notice '202: trip_fit_note govdesi saglam';
end $$;

select '202 OK - saat dilimi tam, AJet anahtari BO''da, pencere yalniz ilgiliye' as sonuc;
