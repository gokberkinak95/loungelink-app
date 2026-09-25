-- ============================================================================
-- SEED6_TEST_DUNYASI.sql — host1 / guest1 TEST HESAPLARININ ETRAFINDA BİR DÜNYA
--
-- Amaç (Gökberk, 5 Eylül): seyahat, ilan, Tanış, Bağlantılarım, sohbet, istek,
-- davet ve soru ekranlarını İKİ ROLDE de DOLU görmek. Bu dosya:
--   · host1@seed.loungelink.test  ve  guest1@seed.loungelink.test hesaplarını
--     (SEED3'ün açtığı; şifre Seed1234!) bulur — yoksa açar,
--   · etraflarına 7 KURGU kişi kurar (e-posta `@sahne.loungelink.test`):
--       Deniz K. (host · IST Primeclass bugün · TK1979) · Mert A. (host · SAW yarın)
--       Kaan T. · Ece Y. · Ayşegül D. · Burak S. · Elif K. (misafir yolcular)
--   · YENİDEN KOŞULABİLİR: önce kurgu kişilere bağlı satırları temizler.
--   · host1/guest1'in kendi bakiye · puan · rozet · kart hakkına DOKUNMAZ
--     (yalnız yoksa ekler).
--
-- NEREDE KOŞULUR: Supabase → SQL Editor → bu dosyanın tamamı → Run.
-- Canlı KULLANICI verisi değişmez; yalnız bu iki test hesabı ve kurgu kişiler.
--
-- guest1 ile açınca:  Ana sayfa Sohbet 1 · İstek 1 · Davet 1 · Soru 1 · Bağlantı 2
--   Planım: IST bugün (TK1979 → LHR · 2 kişi) + SAW (+8 gün)
--   Keşfet: Deniz (kabul edildi) · Mert (istek gönder) · host1
--   Tanış (Uçuş): Burak S. (aynı uçuş) · Elif K. (aynı rota) · …
--   Bağlantılarım: SANA GELENLER Deniz K. · Ayşegül D. — GÖNDERDİKLERİN Kaan T. (bekliyor) · Ece Y. (bağlısınız)
--   Sohbet: Deniz K. (kabul edilmiş istek, oturum bekliyor, "Kapı A12 önü")
-- host1 ile açınca:   Ana sayfa Sohbet 1 · İstek 1 · Bağlantı 1 · Aksiyon: Ece'nin kural sorusu
--   İlanlarım: IST Primeclass bugün 14:20–16:40 (1 dolu / 2) · SAW Comfort yarın
--   İstekler: Ece Y. bekliyor · Burak S. kabul edildi (sohbet + oturum) · Kaan T. tamamlandı
--   Bağlantılarım: Burak S. (bağlısınız · sohbet) · Ayşegül D. (gelen istek)
--   Tanış: aynı havalimanındaki yolcular (Kaan, Ece, Ayşegül, Burak, Elif)
-- ============================================================================
begin;

do $$
declare
  v_host_email  text := 'host1@seed.loungelink.test';
  v_guest_email text := 'guest1@seed.loungelink.test';
  hs uuid; g uuid;
  hd uuid := 'a1b2c3d4-0000-4000-8000-00000000000d';  -- Deniz K.
  hm uuid := 'a1b2c3d4-0000-4000-8000-00000000000e';  -- Mert A.
  kt uuid := 'a1b2c3d4-0000-4000-8000-000000000010';  -- Kaan T.
  ey uuid := 'a1b2c3d4-0000-4000-8000-000000000011';  -- Ece Y.
  ad uuid := 'a1b2c3d4-0000-4000-8000-000000000012';  -- Ayşegül D.
  bs uuid := 'a1b2c3d4-0000-4000-8000-000000000013';  -- Burak S.
  ek uuid := 'a1b2c3d4-0000-4000-8000-000000000014';  -- Elif K.
  l_prime uuid; l_comfort uuid; v_ic uuid; p_tk uuid; p_pp uuid;
  av_d uuid; av_m uuid; av_h1 uuid; av_h2 uuid;
  rq uuid; ch uuid; rq2 uuid; cr_id uuid;
  r record;
begin
  -- ── 0) test hesapları ───────────────────────────────────────────────
  select id into hs from auth.users where email = v_host_email;
  select id into g  from auth.users where email = v_guest_email;
  if hs is null then
    hs := '33330001-0000-4000-8000-000000000001';
    insert into auth.users (id, email) values (hs, v_host_email) on conflict (id) do nothing;
  end if;
  if g is null then
    g := '33330003-0000-4000-8000-000000000003';
    insert into auth.users (id, email) values (g, v_guest_email) on conflict (id) do nothing;
  end if;
  -- handle_new_user tetiklenmemiş olabilir: satırlar yoksa aç
  insert into users (id, email, password_hash, role, plan) values
    (hs, v_host_email, 'supabase-auth', 'host'::user_role, 'explorer'::plan_type),
    (g,  v_guest_email, 'supabase-auth', 'guest'::user_role, 'explorer'::plan_type)
    on conflict (id) do nothing;
  update users set role = 'host'::user_role where id = hs and role <> 'host'::user_role;
  insert into profiles (user_id, name, profession, show_on_discovery) values
    (hs, 'Selin B.', 'Ürün Yönetimi', true), (g, 'Gökberk İ.', 'Ürün Yönetimi', true)
    on conflict (user_id) do update set show_on_discovery = true,
      profession = coalesce(profiles.profession, excluded.profession),
      -- ad boşsa ya da SEED3'ün 'host1'/'guest1' yer tutucusuysa tasarımdaki ad
      name = case when coalesce(btrim(profiles.name),'') in ('', 'host1', 'guest1')
                  then excluded.name else profiles.name end;
  insert into trust_scores (user_id, score, badge) values (hs, 88, 'trusted'), (g, 44, 'basic')
    on conflict (user_id) do nothing;
  insert into verifications (user_id, email_verified, phone_verified) values (hs, true, true), (g, true, true)
    on conflict (user_id) do update set phone_verified = true;

  select id into l_prime   from lounges where airport_code = 'IST' and name ilike 'Primeclass%' limit 1;
  select id into l_comfort from lounges where airport_code = 'SAW' and name ilike 'Plaza Premium Lounge%' limit 1;
  select id into v_ic from lounge_venues where airport_code = 'SAW' and name = 'Plaza Premium Lounge — İç Hat' limit 1;
  select id into p_tk from lounge_programs where code = 'TK_MS';
  select id into p_pp from lounge_programs where code = 'PRIORITY_PASS';

  -- ── 1) kurgu kişiler ────────────────────────────────────────────────
  for r in select * from (values
      (hd, 'deniz@sahne.loungelink.test',   'host',  'Deniz K.',   'Yazılım Mühendisi', 84, 'trusted'),
      (hm, 'mert@sahne.loungelink.test',    'host',  'Mert A.',    'Girişim Kurucusu',  71, 'verified'),
      (kt, 'kaan@sahne.loungelink.test',    'guest', 'Kaan T.',    'Mimar',             64, 'basic'),
      (ey, 'ece@sahne.loungelink.test',     'guest', 'Ece Y.',     'Akademisyen',       69, 'verified'),
      (ad, 'aysegul@sahne.loungelink.test', 'guest', 'Ayşegül D.', 'Doktor',            75, 'verified'),
      (bs, 'burak@sahne.loungelink.test',   'guest', 'Burak S.',   'Pilot',             61, 'basic'),
      (ek, 'elif@sahne.loungelink.test',    'guest', 'Elif K.',    'Avukat',            72, 'verified')
    ) as x(uid, email, rol, adi, meslek, guven, rozet)
  loop
    insert into auth.users (id, email) values (r.uid, r.email) on conflict (id) do nothing;
    insert into users (id, email, password_hash, role, plan)
      values (r.uid, r.email, 'supabase-auth', r.rol::user_role, 'explorer'::plan_type)
      on conflict (id) do update set role = excluded.role;
    insert into profiles (user_id, name, profession, bio, languages, show_on_discovery)
      values (r.uid, r.adi, r.meslek, 'Aktarmalarda iyi bir sohbet uçuşu kısaltır.', array['Türkçe','İngilizce'], true)
      on conflict (user_id) do update set name = excluded.name, profession = excluded.profession, show_on_discovery = true;
    insert into trust_scores (user_id, score, badge) values (r.uid, r.guven, r.rozet)
      on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;
    insert into verifications (user_id, email_verified, phone_verified, id_verified)
      values (r.uid, true, true, r.guven >= 70)
      on conflict (user_id) do update set email_verified = true, phone_verified = true, id_verified = excluded.id_verified;
  end loop;

  -- onaylar: ilk-açılış kapıları (yaş kartı, sözleşmeler) görünmesin
  insert into consents (user_id, type, version)
    select u, ty, '1' from unnest(array[g, hs, hd, hm, kt, ey, ad, bs, ek]) u,
           unnest(array['age_18','terms','privacy','community','no_resale','rules']) ty
    on conflict do nothing;
  update profiles set access_source = 'priority_pass', guest_capacity = 2 where user_id in (hd, hm);
  update profiles set access_source = coalesce(access_source, 'priority_pass'),
                      guest_capacity = coalesce(guest_capacity, 2) where user_id = hs;

  -- kart hakları (host1'inki varsa dokunma)
  delete from host_entitlements where user_id in (hd, hm);
  insert into host_entitlements (user_id, program_id, tier, verified) values
    (hd, p_tk, 'ELPL', true), (hm, p_pp, 'PP_STANDARD', true);
  insert into host_entitlements (user_id, program_id, tier, verified)
    select hs, p_tk, 'ELPL', true where not exists (select 1 from host_entitlements where user_id = hs);

  -- cüzdan: yalnız hiç kayıt yoksa (test hesabının gerçek hareketleri korunur)
  insert into credit_ledger (user_id, delta, reason, balance_after)
    select g, 14, 'seed6', 14 where not exists (select 1 from credit_ledger where user_id = g);
  insert into points_ledger (user_id, delta, reason, balance_after)
    select g, 200, 'seed6', 200 where not exists (select 1 from points_ledger where user_id = g);
  insert into credit_ledger (user_id, delta, reason, balance_after)
    select hs, 6, 'seed6', 6 where not exists (select 1 from credit_ledger where user_id = hs);
  insert into points_ledger (user_id, delta, reason, balance_after)
    select hs, 360, 'seed6', 360 where not exists (select 1 from points_ledger where user_id = hs);

  -- ── 2) temizlik (yeniden koşulabilirlik) ────────────────────────────
  -- YALNIZ kurgu kişilere (hd hm kt ey ad bs ek) dokunan satırlar silinir.
  -- host1/guest1'in kurgu dışı istek · oturum · puanı olduğu gibi kalır
  -- (ilk sürüm host1'in TÜM isteklerini siliyordu → ratings FK'sı düştü).
  create temp table if not exists seed6_rq on commit drop as
    select id from requests
     where guest_id in (kt, ey, ad, bs, ek)                              -- kurgu misafirlerin her başvurusu
        or host_id in (hd, hm)                                           -- kurgu hostlara her başvuru
        or (guest_id = g and host_id in (hd, hm, hs))                    -- guest1'in kurgu dünyadaki başvuruları
        or avail_id in (select id from availabilities where host_id in (hd, hm)
                          or (host_id = hs and flight_number in ('TK1979','PC2210')));
  create temp table if not exists seed6_cr on commit drop as
    select id from connection_requests
     where from_id in (hd, hm, kt, ey, ad, bs, ek) or to_id in (hd, hm, kt, ey, ad, bs, ek);
  create temp table if not exists seed6_ss on commit drop as
    select id from sessions where request_id in (select id from seed6_rq);
  delete from ratings  where session_id in (select id from seed6_ss);
  delete from reports  where session_id in (select id from seed6_ss);
  delete from messages where channel_id in (
    select id from chat_channels where request_id in (select id from seed6_rq)
                                    or connection_id in (select id from seed6_cr));
  delete from chat_channels where request_id in (select id from seed6_rq)
                               or connection_id in (select id from seed6_cr);
  delete from sessions where id in (select id from seed6_ss);
  delete from invites where (host_id in (hd, hm, hs) and guest_id in (kt, ey, ad, bs, ek, g)
                        and (host_id in (hd, hm) or guest_id in (kt, ey, ad, bs, ek)))
     or avail_id in (select id from availabilities where host_id in (hd, hm)
                                                     or (host_id = hs and flight_number in ('TK1979','PC2210')));
  delete from requests where id in (select id from seed6_rq);
  delete from availabilities where host_id in (hd, hm) or (host_id = hs and flight_number in ('TK1979','PC2210'));
  delete from visits where user_id in (kt, ey, ad, bs, ek) or (user_id = g and flight_number in ('TK1979','PC2210'));
  delete from connection_requests where id in (select id from seed6_cr);
  delete from notifications where user_id in (g, hs) and ref_type = 'seed6';
  drop table seed6_ss; drop table seed6_rq; drop table seed6_cr;

  -- ── 3) ilanlar ───────────────────────────────────────────────────────
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active, program_id)
    values (hd, l_prime, 'IST', 'TAV Primeclass', current_date, '14:20', '16:40', 2, 0, 'TK1979', 'TK', 'Public', true, p_tk) returning id into av_d;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active, program_id, venue_id)
    values (hm, l_comfort, 'SAW', 'Comfort Lounge', current_date + 1, '09:00', '11:30', 1, 0, 'PC2210', 'PC', 'Public', true, p_pp, v_ic) returning id into av_m;
  -- host1'in iki ilanı (tasarım 12/12c)
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active, program_id)
    values (hs, l_prime, 'IST', 'TAV Primeclass', current_date, '14:20', '16:40', 2, 1, 'TK1979', 'TK', 'Public', true, p_tk) returning id into av_h1;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active, program_id, venue_id)
    values (hs, l_comfort, 'SAW', 'Comfort Lounge', current_date + 1, '09:00', '11:30', 1, 0, 'PC2210', 'PC', 'Public', true, p_pp, v_ic) returning id into av_h2;

  -- ── 4) seyahatler ────────────────────────────────────────────────────
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code, purpose, party_size, child_ages)
    values (g,  'IST', 'LHR', current_date,     '14:00', '18:00', 'TK1979', 'TK', 'connecting', 2, array[4]),
           (g,  'SAW', null,  current_date + 8, '09:00', '11:00', 'PC2210', 'PC', 'leisure', 1, null),
           (kt, 'IST', 'AMS', current_date,     '13:00', '17:00', 'TK1979', 'TK', 'business', 1, null),
           (kt, 'SAW', null,  current_date + 1, '08:30', '11:00', 'PC2210', 'PC', null, 1, null),
           (ey, 'IST', 'LHR', current_date,     '15:00', '18:05', 'TK1979', 'TK', 'connecting', 1, null),
           (ad, 'IST', 'FRA', current_date,     '12:00', '16:00', 'TK1590', 'TK', 'business', 1, null),
           (bs, 'IST', 'AMS', current_date,     '13:30', '17:30', 'TK1979', 'TK', 'business', 1, null),
           (ek, 'IST', 'LHR', current_date,     '14:30', '18:00', 'TK1983', 'TK', 'connecting', 1, null);

  -- ── 5) istekler · sohbetler · oturumlar ─────────────────────────────
  -- guest1 → Deniz: KABUL (sohbet + bekleyen oturum, buluşma "Kapı A12 önü")
  insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
    values (g, hd, av_d, 'accepted', 'Aynı uçuştayız, kahve içelim mi?', now() - interval '20 minutes', now() - interval '40 minutes')
    returning id into rq;
  insert into chat_channels (request_id, kind, active) values (rq, 'request', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, hd, 'Merhaba! Primeclass girişinde buluşalım mı?', now() - interval '18 minutes'),
    (ch, g,  'Olur, güvenlikten yeni geçtim — 5 dakikaya oradayım.', now() - interval '16 minutes'),
    (ch, g,  'Lounge girişindeyim', now() - interval '11 minutes');
  insert into sessions (request_id, status, host_confirmed, guest_confirmed, host_status, host_status_ts)
    values (rq, 'pending', false, false, 'Kapı A12 önü', now() - interval '12 minutes');
  -- guest1 → Mert: BEKLİYOR (İstek 1)
  insert into requests (guest_id, host_id, avail_id, status, intro_message, created_at)
    values (g, hm, av_m, 'pending', 'Yarın SAW''dayım, uyar mı?', now() - interval '2 hours');

  -- host1'e gelenler: Ece bekliyor · Burak kabul (sohbet + oturum) · Kaan tamamlandı
  insert into requests (guest_id, host_id, avail_id, status, intro_message, created_at)
    values (ey, hs, av_h1, 'pending', 'Uçuştan önce kahve?', now() - interval '25 minutes');
  insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
    values (bs, hs, av_h1, 'accepted', 'Aynı uçuştayız.', now() - interval '50 minutes', now() - interval '70 minutes')
    returning id into rq2;
  insert into chat_channels (request_id, kind, active) values (rq2, 'request', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, bs, 'Merhaba, D kapısı tarafındayım. Nerede buluşalım?', now() - interval '30 minutes'),
    (ch, hs, 'Primeclass girişinde, 14:10 gibi orada olurum.', now() - interval '28 minutes');
  insert into sessions (request_id, status, host_confirmed, guest_confirmed, guest_status, guest_status_ts)
    values (rq2, 'pending', false, false, 'D kapısı yanı', now() - interval '25 minutes');
  insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
    values (kt, hs, av_h1, 'completed', 'Aktarmada kahve.', now() - interval '3 hours', now() - interval '4 hours')
    returning id into rq2;
  insert into sessions (request_id, status, started_at, completed_at, host_confirmed, guest_confirmed)
    values (rq2, 'completed', now() - interval '2 hours', now() - interval '1 hour', true, true);

  -- ── 6) davetler (host → misafir) ──────────────────────────────────────
  insert into invites (host_id, guest_id, avail_id, note, status, created_at)
    values (hd, g,  av_d,  'Aynı uçuştayız, yanımda yer var.', 'pending', now() - interval '35 minutes'),
           (hs, ek, av_h1, 'Yanımda bir yer var, ister misin?', 'pending', now() - interval '15 minutes');

  -- ── 7) bağlantılar + kural soruları ──────────────────────────────────
  insert into connection_requests (from_id, to_id, status, intro, intent) values
    (hd, g,  'pending',  'Uçuşun aynı, güzel.',          'coffee'),
    (g,  kt, 'pending',  'Aynı uçuştayız.',              'coffee'),
    (ad, g,  'pending',  'Seninle tanışmak istiyor.',     'hello'),
    (ad, hs, 'pending',  'Salonda görüşelim mi?',         'coffee');  -- (from,to) tekil: Ece→host1 çifti kural sorusuna ayrıldı
  insert into connection_requests (from_id, to_id, status, intro, intent, responded_at)
    values (g, ey, 'accepted', 'Aynı rota.', 'route', now() - interval '1 day') returning id into cr_id;
  insert into chat_channels (connection_id, kind, active) values (cr_id, 'connection', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, ey, 'Selam! Sen de LHR''ye mi uçuyorsun?', now() - interval '3 hours'),
    (ch, g,  'Evet, 18:00 TK1979. Salonda görüşürüz belki.', now() - interval '2 hours');
  -- host1'in de bir bağlantısı olsun (ana sayfa "Sohbet" rozeti = kabul edilmiş bağlantılar)
  insert into connection_requests (from_id, to_id, status, intro, intent, responded_at)
    values (bs, hs, 'accepted', 'Kapıda görüşürüz.', 'coffee', now() - interval '2 hours') returning id into cr_id;
  insert into chat_channels (connection_id, kind, active) values (cr_id, 'connection', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, bs, 'Selam, D kapısına yakınım.', now() - interval '90 minutes'),
    (ch, hs, 'Geliyorum, 5 dakika.',       now() - interval '80 minutes');
  -- kural sorusu (Soru kutusu): guest1 → Deniz'in ilanı · Ece → host1'in ilanı
  insert into connection_requests (from_id, to_id, status, intro, intent, avail_id) values
    (g,  hd, 'pending', 'Elite Plus ile 2 kişi giriyor muyuz?', 'kural_sorusu', av_d),
    (ey, hs, 'pending', 'Kartın bugün misafir alıyor mu?',      'kural_sorusu', av_h1);

  -- ── 8) bildirimler ────────────────────────────────────────────────────
  insert into notifications (user_id, category, title, body, read, ref_type, created_at) values
    (g,  'requests',    'İstek kabul edildi',   'Deniz K. seni Primeclass''a alıyor.',   false, 'seed6', now() - interval '2 minutes'),
    (g,  'connections', 'Yeni bağlantı isteği', 'Ayşegül D. seninle tanışmak istiyor.', false, 'seed6', now() - interval '18 minutes'),
    (g,  'sessions',    'Oturum Devam Ediyor',  'TAV Primeclass · Kapı A12 önü.',        true,  'seed6', now() - interval '1 hour'),
    (g,  'ratings',     'Oturumu değerlendir',  'Deniz K. ile geçen oturum tamamlandı.', true,  'seed6', now() - interval '3 hours'),
    (g,  'credits',     'Kredin yenilendi',     'Bu ay 2 kredi eklendi.',                 true,  'seed6', now() - interval '1 day'),
    (hs, 'requests',    'Yeni istek',           'Ece Y. Primeclass ilanına başvurdu.',    false, 'seed6', now() - interval '25 minutes'),
    (hs, 'sessions',    'Buluşma bekliyor',     'Burak S. D kapısı yanında.',             false, 'seed6', now() - interval '20 minutes'),
    (hs, 'connections', 'Yeni bağlantı isteği', 'Ayşegül D. seninle tanışmak istiyor.',   true,  'seed6', now() - interval '2 hours');

  -- oturum tetikleyicileri güven puanını yeniden hesaplamış olabilir: kurgu kişiler
  update trust_scores set score = 84, badge = 'trusted' where user_id = hd;
end $$;

commit;
select 'SEED6 OK — host1 / guest1 dünyası kuruldu' as sonuc;
