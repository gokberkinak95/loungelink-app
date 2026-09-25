-- ============================================================================
-- LoungeLink · 223_sinirlar_dogruyu_soylesin.sql          (19 Ağustos 2026)
--
-- SINIRA TAKILAN KULLANICI ÜÇ ŞEYİ BİLMELİ:
--   1) durduruldu       2) NEDEN durduruldu       3) NE ZAMAN açılacak
--
-- Gökberk: "kullanıcı bir noktada bir konu hakkında sınıra eriştiyse
-- artık neden yapamayacağına dair bilgilendirme metni görmeli. Ayrıca
-- günde 5 soru sınırı diyorsun, gece 00:00 sonrası hak yenileniyor mu?"
--
-- Sorusu tam yerine denk geldi ve cevap RAHATSIZ EDİCİ: hayır, yenilenmiyor.
-- Ve bunu ben yanlış yazmışım.
--
-- ── ÖNCE ENVANTER ÇIKARDIM: 26 SINIR, 4'Ü KULLANICIYA HİÇBİR ŞEY DEMİYOR
--
--   251 SQL dosyası · 1.134 `raise exception` · 131 benzersiz hata kodu
--   oran/kota sınıfına giren: 21 kod + 5 sessiz sınır = 26
--   i18n karşılığı olan: 20/21
--   "ne zaman tekrar deneyebilirim" sorusuna cevap veren: 4/26
--
-- Bu dosya dört sınıfı düzeltiyor.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 1) 🔴 KENDİ YAZDIĞIM METİN YALANDI — "YARIN TEKRAR DENE"
--
-- 221'de şunu yazmışım:
--     "Günde en fazla 5 host'a soru gönderebilirsin. Yarın tekrar dene."
-- Koddaki pencere ise:
--     created_at > now() - interval '24 hours'      ← KAYAN pencere
--
-- Kayan pencerede "yarın" diye bir an yoktur. Bugün 22:00'de beşinci
-- soruyu soran kullanıcı gece yarısı beklerse YİNE takılır; hakkı yarın
-- 22:00'de damla damla geri gelir. Yani metin hem çok erken umut veriyor
-- (00:01'de deneyip yine yiyor) hem de gerçek anı söylemiyor.
--
-- İKİ SEÇENEK VARDI:
--   (a) metni pencereye uydur: "en eski sorunun üstünden 24 saat geçince"
--   (b) pencereyi metne uydur: takvim gününe çevir, gece yarısı yenilensin
--
-- (b)'yi seçtim. Sebep ürünle ilgili: "günde 5" bir kullanıcı için TAKVİM
-- günü demektir. Kayan pencere teknik olarak daha adil ama açıklanamaz;
-- açıklanamayan bir sınır, keyfî bir sınır gibi hissedilir.
--
-- 🔴 VE SAAT DİLİMİ ÖNEMLİ. `date_trunc('day', now())` sunucu saatine
-- göre çalışır; Supabase UTC'dir ve bu Türkiye'de gece 03:00 demek olur.
-- Kullanıcıya "gece yarısı" deyip 03:00'te açmak, yalanın daha incesi.
-- Bu yüzden pencere AÇIKÇA Europe/Istanbul'a bağlandı.
-- ════════════════════════════════════════════════════════════════════════

-- Ortak yardımcı: bir eylemin takvim-günü penceresinde durumu.
-- Hem kapıyı hem de "ne zaman yenilenir" cevabını TEK yerden üretir —
-- iki yerde iki hesap olsaydı biri bayatlardı (219'un dersi).
create or replace function public.gunluk_sinir_durumu(
  p_kullanilan int, p_tavan int, p_tz text default 'Europe/Istanbul')
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'kullanilan', p_kullanilan,
    'tavan',      p_tavan,
    'kalan',      greatest(0, p_tavan - p_kullanilan),
    'asildi',     p_kullanilan >= p_tavan,
    -- Yerel gün başlangıcının BİR SONRAKİSİ = hakkın yenileneceği an
    'yenilenme',  ((date_trunc('day', timezone(p_tz, now())) + interval '1 day')
                    at time zone p_tz),
    'tz',         p_tz);
$$;
grant execute on function public.gunluk_sinir_durumu(int, int, text) to authenticated;

-- Kullanıcının kendi sınır durumunu SORABİLMESİ — hata beklemeden.
-- 🔴 Kullanıcı "neden yapamıyorum" sorusunu ancak DENEYİNCE sorabiliyordu.
-- Ekran artık kalan hakkı önceden gösterebilsin diye açık bir RPC.
create or replace function public.kural_sorusu_hakkim()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_n int; v_tavan int := 5;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;
  select count(*) into v_n from connection_requests
   where from_id = v_uid and intent = 'kural_sorusu'
     and created_at >= (date_trunc('day', timezone('Europe/Istanbul', now()))
                          at time zone 'Europe/Istanbul');
  return public.gunluk_sinir_durumu(v_n, v_tavan) || jsonb_build_object('known', true);
end $$;
grant execute on function public.kural_sorusu_hakkim() to authenticated;

-- ilan_kurali_sor: pencere TAKVİM GÜNÜNE çevriliyor ve hata artık
-- yenilenme anını TAŞIYOR (PostgREST `hint` alanı olarak istemciye gider).
create or replace function public.ilan_kurali_sor(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_av availabilities%rowtype;
  v_salon text; v_konu text; v_intro text;
  v_ok boolean; v_id uuid; v_mevcut connection_requests%rowtype;
  v_hak jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_av from availabilities where id = p_avail_id;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_connect_blocked'; end if;

  if not public.kural_sorusu_uygun_mu(p_avail_id) then
    raise exception 'rule_ask_not_applicable';
  end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  -- 🔴 TAKVİM GÜNÜ (Europe/Istanbul), kayan 24 saat DEĞİL.
  v_hak := public.kural_sorusu_hakkim();
  if coalesce((v_hak ->> 'asildi')::boolean, false) then
    raise exception 'rule_ask_daily_limit'
      using detail = format('%s/%s soru kullanildi', v_hak ->> 'kullanilan', v_hak ->> 'tavan'),
            hint   = 'yenilenme=' || (v_hak ->> 'yenilenme');
  end if;

  v_salon := coalesce(v_av.lounge_name, v_av.airport_code);

  select * into v_mevcut from connection_requests
   where (from_id = v_uid and to_id = v_av.host_id)
      or (from_id = v_av.host_id and to_id = v_uid)
   order by created_at desc limit 1;

  if found then
    return jsonb_build_object(
      'ok', true,
      'durum', case when v_mevcut.status::text = 'accepted' then 'baglanti_var' else 'zaten_soruldu' end,
      'baglanti_id', v_mevcut.id,
      'salon', v_salon);
  end if;

  v_intro := left('“' || v_salon || '” ilanında misafir hakkı görünmüyor ama bunu '
             || 'doğrulayamadık. Kartında misafir hakkın var mı?', 140);

  insert into connection_requests (from_id, to_id, intent, intro, status)
  values (v_uid, v_av.host_id, 'kural_sorusu', v_intro, 'pending')
  returning id into v_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'connections',
          'Misafir hakkın soruluyor ◈',
          'Bir yolcu “' || v_salon || '” ilanında misafir götürüp götüremediğini '
          || 'soruyor. Elimizdeki bilgi “hayır” diyor ama doğrulayamadık. '
          || 'Kart hakkını Profil → Lounge hakkı kaynağı ekranından '
          || 'güncellersen ilanın başvuruya açılır.',
          'connection', v_id);

  v_konu := 'hosta_sorulan_misafir_hakki:' || coalesce(v_av.lounge_id::text, v_av.airport_code);
  insert into rule_source_conflicts (konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki)
  values (v_konu,
          'Misafir “' || v_salon || '” ilanında misafir hakkı olup olmadığını host''a sordu. '
          || 'Karar motoru not_allowed diyor ama kesinlik verified değil.',
          'LoungeLink karar motoru: misafir hakki yok (dogrulanmadi)',
          'Kullanici sorusu (' || to_char(now(),'YYYY-MM-DD') || ')',
          'kaynak_sessiz',
          'Kaynak taramasi bekliyor — bu salonun resmi misafir kurali bulunmali.',
          'veri_bekliyor',
          'Misafir basvuramiyor; host beyan etmezse ilan olu kaliyor.')
  on conflict (konu) do update set
    kaynak_b = 'Kullanici sorusu (son: ' || to_char(now(),'YYYY-MM-DD') || ')',
    updated_at = now();

  return jsonb_build_object('ok', true, 'durum', 'soruldu',
                            'baglanti_id', v_id, 'salon', v_salon,
                            'kalan_hak', (public.kural_sorusu_hakkim() ->> 'kalan')::int);
end $$;
grant execute on function public.ilan_kurali_sor(uuid) to authenticated;

insert into beta_settings (key, value) values
 ('err_rule_ask_daily_limit', to_jsonb(
   'Bugün 5 host''a soru gönderdin — günlük hakkın doldu. Hakkın gece '
   'yarısı (Türkiye saati) yenilenir.'::text))
on conflict (key) do update set value = excluded.value;


-- ════════════════════════════════════════════════════════════════════════
-- 2) 🔴 BO'NUN "İSTEK SINIRLARI" SAYFASI HİÇBİR ŞEY YAPMIYORDU
--
-- Sayfa yedi ayrı sınırı ayrı ayrı ayarlatıyor ve şunu vaat ediyor:
-- "Etki anındadır, sürüm çıkmaya gerek yok." Ölçüm bunu yalanladı.
--
-- ZİNCİR NASIL KOPTU:
--   082  rl_guard() TG_ARGV'den anahtar/limit/pencere okuyor, rl_limit()
--        ile beta_settings'e bakıyor. 7 tetikleyici 7 ayrı parametreyle.
--   166  boş JWT claims çökmesini düzeltmek için rl_guard BAŞTAN YAZILMIŞ
--        ve bu sırada TG_ARGV + rl_limit() çağrısı TAMAMEN DÜŞMÜŞ.
--        Yerine sabit `rate_ok('requests_insert', 20, 1)` gelmiş.
--   176  aynı gövde korunmuş, üstüne test muafiyeti eklenmiş.
--
-- SONUÇ: yedi tablo (messages, requests, connection_requests, invites,
-- availabilities, visits, reports) TEK ortak sayaca yazıyordu, ortak
-- tavan 20/saat. Yani `messages_per_min: 20` artık "dakikada 20" değil
-- "saatte 20" ve üstelik diğer altı işlemle AYNI havuzda.
-- Normal bir sohbet (BO'nun kendi notu: "normal yazışma ~5-10/dk") bu
-- tavanı dakikalar içinde yakıyordu.
--
-- Ve `beta_settings.rate_limits` yazılıyor ama OKUYAN KALMAMIŞ:
-- rl_limit()'in tek çağıranı silinen gövdeydi. BO'daki "0 = sınırsız"
-- seçeneği de bu yüzden işlevsiz.
--
-- 🔴 DERS: bir hata düzeltilirken gövdenin tamamı yeniden yazılırsa,
-- gövdenin ÖBÜR İŞLERİ sessizce düşer. 166 doğru bir çökmeyi düzeltti ve
-- yanında yedi ayarı öldürdü. Bunu yakalayan bir denetim yoktu; şimdi var
-- (aşağıdaki nöbetçi).
-- ════════════════════════════════════════════════════════════════════════

-- Tumbling (yuvarlanan değil, SABİT) pencere: "hakkın 14:35'te yenilenir"
-- diyebilmek için. Kayan pencerede söylenebilecek tek dürüst cümle
-- "en eski işleminin üstünden N dakika geçince" — kullanıcı için anlamsız.
create or replace function public.oran_kapisi(
  p_action text, p_limit int, p_minutes int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_pencere int := greatest(coalesce(p_minutes,60), 1);
  v_bas timestamptz; v_bit timestamptz; v_n int;
begin
  if v_uid is null then
    -- Oturumsuz çağrı sınırlanmaz (tetikleyici zaten atlıyor).
    return jsonb_build_object('ok', true, 'kalan', p_limit);
  end if;
  if coalesce(p_limit, 0) <= 0 then
    -- 0 = SINIRSIZ. BO'nun sayfasında yazan söz buydu; artık gerçek.
    return jsonb_build_object('ok', true, 'kalan', null, 'sinirsiz', true);
  end if;

  -- Sabit pencere: epoch'u pencere boyuna böl.
  v_bas := to_timestamp(floor(extract(epoch from now()) / (v_pencere * 60)) * (v_pencere * 60));
  v_bit := v_bas + make_interval(mins => v_pencere);

  select coalesce(sum(count), 0) into v_n from rate_limits
   where user_id = v_uid and action = p_action and window_start = v_bas;

  if v_n >= p_limit then
    return jsonb_build_object('ok', false, 'kullanilan', v_n, 'tavan', p_limit,
                              'kalan', 0, 'yenilenme', v_bit, 'pencere_dk', v_pencere);
  end if;

  insert into rate_limits (user_id, action, window_start, count)
  values (v_uid, p_action, v_bas, 1)
  on conflict (user_id, action, window_start) do update set count = rate_limits.count + 1;

  return jsonb_build_object('ok', true, 'kullanilan', v_n + 1, 'tavan', p_limit,
                            'kalan', p_limit - v_n - 1, 'yenilenme', v_bit,
                            'pencere_dk', v_pencere);
end $$;
grant execute on function public.oran_kapisi(text, int, int) to authenticated;

-- rl_guard: 082'nin PARAMETRELİ hâli geri geliyor + 166'nın boş-claims
-- düzeltmesi + 176'nın test muafiyeti KORUNUYOR. Üçü birden.
create or replace function public.rl_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid; v_claims text;
  v_key text; v_def int; v_dk int; v_limit int; v_durum jsonb;
begin
  -- 176: test muafiyeti (ll.test_mode yalnız oturum ömürlü; PostgREST
  -- üzerinden yerleştirilemez, canlı kullanıcı bununla sınırı aşamaz).
  if coalesce(current_setting('ll.test_mode', true), '') = 'on' then
    return new;
  end if;

  -- 166: boş/bozuk JWT claims'te ÇÖKME. Sınır uygulanamıyorsa yazmayı
  -- engellemiyoruz — kimliksiz bir isteği zaten RLS durduruyor.
  v_claims := nullif(current_setting('request.jwt.claims', true), '');
  if v_claims is null then return new; end if;
  begin
    v_uid := nullif(v_claims::json ->> 'sub', '')::uuid;
  exception when others then
    return new;
  end;
  if v_uid is null then return new; end if;

  -- 🔴 082'DEN GERİ GELEN KISIM: her tetikleyici KENDİ anahtarını,
  -- KENDİ varsayılanını ve KENDİ pencere boyunu taşıyor.
  v_key := coalesce(TG_ARGV[0], 'genel');
  v_def := coalesce(nullif(TG_ARGV[1],'')::int, 20);
  v_dk  := coalesce(nullif(TG_ARGV[2],'')::int, 60);
  v_limit := public.rl_limit(v_key, v_def);

  v_durum := public.oran_kapisi(v_key, v_limit, v_dk);
  if not coalesce((v_durum ->> 'ok')::boolean, true) then
    raise exception 'rate_limited'
      using detail = format('%s: %s/%s', v_key, v_durum ->> 'kullanilan', v_durum ->> 'tavan'),
            hint   = 'yenilenme=' || (v_durum ->> 'yenilenme') || ';islem=' || v_key;
  end if;
  return new;
end $$;

-- Tetikleyicileri 082'deki parametrelerle YENİDEN kur (166 gövdeyi
-- değiştirdi ama tetikleyiciler parametreleri hâlâ taşıyordu — yani
-- parametreler üç sürümdür boşa geçiyordu).
drop trigger if exists trg_rl_messages on messages;
create trigger trg_rl_messages before insert on messages
for each row execute function public.rl_guard('messages_per_min', '20', '1');

drop trigger if exists trg_rl_requests on requests;
create trigger trg_rl_requests before insert on requests
for each row execute function public.rl_guard('requests_per_hour', '10', '60');

drop trigger if exists trg_rl_connections on connection_requests;
create trigger trg_rl_connections before insert on connection_requests
for each row execute function public.rl_guard('connections_per_hour', '15', '60');

drop trigger if exists trg_rl_invites on invites;
create trigger trg_rl_invites before insert on invites
for each row execute function public.rl_guard('invites_per_hour', '20', '60');

drop trigger if exists trg_rl_availabilities on availabilities;
create trigger trg_rl_availabilities before insert on availabilities
for each row execute function public.rl_guard('availabilities_per_day', '10', '1440');

drop trigger if exists trg_rl_visits on visits;
create trigger trg_rl_visits before insert on visits
for each row execute function public.rl_guard('visits_per_day', '15', '1440');

drop trigger if exists trg_rl_reports on reports;
create trigger trg_rl_reports before insert on reports
for each row execute function public.rl_guard('reports_per_day', '10', '1440');


-- ════════════════════════════════════════════════════════════════════════
-- 3) SESSİZ SINIRLAR KONUŞSUN
--
-- Envanterde dört sınır kullanıcıya HİÇBİR ŞEY söylemiyordu. En
-- tehlikelileri bunlar: kullanıcı şikâyet bile edemiyor, çünkü bir şeyin
-- durdurulduğunu bilmiyor.
-- ════════════════════════════════════════════════════════════════════════

-- (a) Gölge kısıt — kullanıcı keşiften siliniyor ve haberi olmuyor.
--     `is_visible()` onu listelerden çıkarıyor, 7 gün boyunca kimse
--     görmüyor. `rnapp/` içinde `shadow_limited` geçen SIFIR satır var.
--     Kısıtı KALDIRMIYORUM (moderasyon aracı) ama kullanıcı öğrensin.
create or replace function public.kisit_durumum()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_u users%rowtype;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;
  select * into v_u from users where id = v_uid;
  if not found then return jsonb_build_object('known', false); end if;

  if coalesce(v_u.shadow_limited, false)
     or (v_u.restricted_until is not null and v_u.restricted_until > now()) then
    return jsonb_build_object(
      'known', true, 'kisitli', true,
      'bitis', v_u.restricted_until,
      'baslik', 'Hesabın geçici olarak kısıtlı',
      'metin',  case
        when v_u.restricted_until is not null then
          'Hakkındaki bildirimler nedeniyle ilanların ve profilin keşfette '
          'geçici olarak görünmüyor. Kısıt ' ||
          to_char(timezone('Europe/Istanbul', v_u.restricted_until), 'DD.MM.YYYY HH24:MI') ||
          ' (Türkiye saati) itibarıyla kalkar. İtirazın varsa İtiraz Merkezi''nden yazabilirsin.'
        else
          'Hakkındaki bildirimler nedeniyle ilanların ve profilin keşfette '
          'geçici olarak görünmüyor. İtirazın varsa İtiraz Merkezi''nden yazabilirsin.'
        end);
  end if;
  return jsonb_build_object('known', true, 'kisitli', false);
end $$;
grant execute on function public.kisit_durumum() to authenticated;

-- (b) Uçuş verisi kotası — sessizce "veri yok" görünüyordu.
--     Kullanıcı uçuşunun bulunamadığını sanıyor; aslında günlük kotası
--     dolmuş. İkisi çok farklı: biri "yanlış numara yazdım" dedirtir,
--     öbürü "yarın deneyeyim".
create or replace function public.ucus_kotam()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_gun int; v_tavan int;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;
  select coalesce((value)::text::int, 3) into v_tavan
    from beta_settings where key = 'flight_user_daily';
  v_tavan := coalesce(v_tavan, 3);

  select count(*) into v_gun from flight_fetch_log
   where user_id = v_uid
     and created_at >= (date_trunc('day', timezone('Europe/Istanbul', now()))
                          at time zone 'Europe/Istanbul');

  return public.gunluk_sinir_durumu(coalesce(v_gun,0), v_tavan) || jsonb_build_object('known', true);
exception when others then
  -- Tablo/kolon adı değişmişse kullanıcıyı yanıltmaktansa "bilmiyorum" de.
  return jsonb_build_object('known', false);
end $$;
grant execute on function public.ucus_kotam() to authenticated;

-- (c) Hatalı metin düzeltmesi: kod ('year','month','unlimited') kabul
--     ediyor, metin "yıllık veya ziyaret başına" diyordu. Var olmayan bir
--     seçeneği söyleyip var olan ikisini gizliyordu.
insert into beta_settings (key, value) values
 ('err_invalid_quota_period', to_jsonb(
   'Hak dönemi geçersiz — yıllık, aylık ya da sınırsız seç.'::text)),
 ('err_rate_limited', to_jsonb(
   'Çok sık denedin. Hakkın kısa süre içinde yenilenecek — ekranda yazan '
   'saati bekle.'::text)),
 ('err_rate_limited_waitlist', to_jsonb(
   'Şu an çok fazla kayıt geliyor. Bir dakika sonra tekrar dene.'::text))
on conflict (key) do update set value = excluded.value;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ 1 · TETİKLEYİCİLER GERÇEKTEN KENDİ AYARLARINI OKUYOR MU
--
-- 166'nın sessiz kaybı üç sürüm boyunca görünmedi çünkü kimse "bu
-- tetikleyici kendi parametresini kullanıyor mu" diye sormamıştı.
-- Şimdi soruyoruz.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare v_n int; v_src text; v_eksik text := '';
begin
  select count(*) into v_n from pg_trigger
   where tgname like 'trg_rl_%' and not tgisinternal;
  if v_n <> 7 then
    raise exception '223: rate limit tetikleyicisi % (7 bekleniyor)', v_n;
  end if;

  select prosrc into v_src from pg_proc
   where proname = 'rl_guard' and pronamespace = 'public'::regnamespace;
  if position('TG_ARGV' in coalesce(v_src,'')) = 0 then
    raise exception '223: rl_guard TG_ARGV OKUMUYOR — tetikleyici parametreleri yine bosa gidiyor';
  end if;
  if position('rl_limit' in coalesce(v_src,'')) = 0 then
    raise exception '223: rl_guard rl_limit() CAGIRMIYOR — BO ayarlari yine okunmuyor';
  end if;

  raise notice '223: 7 tetikleyici kendi anahtarini ve BO ayarini okuyor';
end $$;


-- ── NÖBETÇİ 2 · PENCERE İLE METİN AYNI ŞEYİ SÖYLÜYOR MU ─────────────
-- Bu dosyanın varlık sebebi bir metin/pencere uyuşmazlığıydı. Aynı
-- sınıf bir daha sessizce girmesin.
do $$
declare v_metin text; v_src text;
begin
  select (value #>> '{}') into v_metin from beta_settings where key = 'err_rule_ask_daily_limit';
  select prosrc into v_src from pg_proc
   where proname = 'kural_sorusu_hakkim' and pronamespace = 'public'::regnamespace;

  -- Metin "gece yarısı" diyorsa pencere TAKVİM günü olmalı.
  if v_metin ilike '%gece yar%' and position('date_trunc(''day''' in coalesce(v_src,'')) = 0 then
    raise exception '223: metin "gece yarisi" diyor ama pencere takvim gunu DEGIL';
  end if;
  -- Pencere kayansa metin "yarın/gece yarısı" DEMEMELİ.
  if position('now() - interval' in coalesce(v_src,'')) > 0
     and (v_metin ilike '%yarin%' or v_metin ilike '%yarın%' or v_metin ilike '%gece yar%') then
    raise exception '223: pencere KAYAN ama metin takvim gunu vaat ediyor';
  end if;
  raise notice '223: sinir metni ile pencere tipi uyusuyor';
end $$;


-- ── NÖBETÇİ 3 · SINIR HATALARININ KARŞILIĞI VAR MI ──────────────────
-- Karşılığı olmayan bir hata kodu = kullanıcının ham İngilizce/kod
-- görmesi demek. 26 sınırın 1'i tam olarak bu durumdaydı.
do $$
declare v_eksik text := ''; k text;
begin
  foreach k in array array[
    'err_rule_ask_daily_limit','err_rule_ask_not_applicable',
    'err_rate_limited','err_rate_limited_waitlist','err_invalid_quota_period']
  loop
    if not exists (select 1 from beta_settings where key = k
                    and coalesce(value #>> '{}','') <> '') then
      v_eksik := v_eksik || k || ' ';
    end if;
  end loop;
  if v_eksik <> '' then
    raise exception '223: sinir metni EKSIK → %', v_eksik;
  end if;
  raise notice '223: sinir metinlerinin hepsi yazili';
end $$;

select '223 OK — sinirlar neden ve ne zaman sorularina cevap veriyor' as sonuc;
