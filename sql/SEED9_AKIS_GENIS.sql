-- ============================================================================
-- LoungeLink · SEED9_AKIS_GENIS.sql                                 (1 Ekim 2026)
--
-- "Test dataları ile dolu bir hesaba ihtiyacım var — akis.host ve akis.misafir.
--  Ana sayfadaki sohbet · istek · davet · soru alanlarında veri olsun; gelen,
--  gönderdiğim, kabul/ret edebileceğim istekler, oturumun her aşaması, doğrudan
--  davet, sorular (cevaplı/cevapsız), Keşfet'te başvurabileceğim / başvuramayacağım /
--  ücretli / kuralı bilinmeyen ilanlar…"                         — Gökberk, 1 Ekim
--
-- ÖNKOŞUL: SEED8_AKIS_TEZGAHI.sql HEMEN ÖNCE koşulmuş olmalı (akış dünyasını sıfırdan
-- kurar). Sıra: SEED8 → SEED9. İkisi birlikte tekrar koşulabilir.
-- GÜVENLİK: yalnız seed_test_hesabi() hesaplarına yazar — her satır akis.* hesaplarının
-- kendi aralarındaki gerçek fonksiyon çağrılarıyla üretilir; temizlik yalnız İKİ tarafı da
-- akis.* olan satırları siler. Sonda ana sayfa sayılarını açılan listelerle karşılaştırır.
-- ŞİFRE: bütün akis.* hesapları `Seed1234!`
--
-- SEED8'İN ÜSTÜNE EKLENENLER (hepsi gerçek fonksiyonlarla, o kişi adına):
--   · Nehir (akis.host) artık MİSAFİR de: gönderdiği bekleyen istek + kabul edilmiş
--     istek + ona gelen DOĞRUDAN DAVET (Tuna'dan)
--   · Nehir'in ilanlarında "karşı taraf başlattı, sen başlatmadın" ve
--     "karşı taraf tamamladı, senin onayın bekleniyor" (ikisi de Duru)
--   · Bağlantılar: Arda ↔ Cem kabul + sohbet mesajları · Bora → Arda bekleyen ·
--     Arda → Duru gönderilen · Duru → Nehir bekleyen
--   · Sorular: Arda → Tuna BEKLEYEN · Arda → Selen CEVAPLANMIŞ (sohbet açık) ·
--     Bora → Nehir (Nehir'e GELEN soru)
--   · Keşfet (Arda'nın gözünden): FARKLI HAVAYOLU (başvuramaz) · ÜCRETLİ misafir girişi ·
--     KURALI DOĞRULANMAMIŞ ("Host'a sor") · SEED8'in açık / dolu / seyahatsiz / eşikli ilanları
--   · Yeni test host'u: akis.host3@seed.loungelink.test (Selen Ö.)
-- ============================================================================

-- ── §0 · SEED8 koşulmuş mu? + yeni hesap ────────────────────────────────────
do $on$
begin
  if not exists (select 1 from information_schema.tables where table_schema = 'tezgah' and table_name = 'seed8_hesap')
     or not exists (select 1 from tezgah.seed8_hesap) then
    raise exception 'SEED9: önce SEED8_AKIS_TEZGAHI.sql koşulmalı';
  end if;
end $on$;

create table if not exists tezgah.seed9_hesap (id uuid, email text primary key, ad text, meslek text);
revoke all on tezgah.seed9_hesap from public;
truncate tezgah.seed9_hesap;
insert into tezgah.seed9_hesap values
  ('88880000-0000-4000-8000-000000000003', 'akis.host3@seed.loungelink.test', 'Selen Ö.', 'Pazarlama Direktörü');

do $hesap$
declare r record; v_var uuid;
begin
  if exists (select 1 from tezgah.seed9_hesap h where not public.seed_test_hesabi(h.email)) then
    raise exception 'SEED9: test kümesi dışında e-posta — DURDU';
  end if;
  for r in select * from tezgah.seed9_hesap loop
    select id into v_var from auth.users where email = r.email;
    if v_var is null then insert into auth.users (id, email) values (r.id, r.email);
    elsif v_var <> r.id then update tezgah.seed9_hesap set id = v_var where email = r.email; end if;
  end loop;
end $hesap$;

update auth.users u set encrypted_password = extensions.crypt('Seed1234!', extensions.gen_salt('bf'))
 where u.email in (select email from tezgah.seed9_hesap) and (u.encrypted_password is null or u.encrypted_password = '');

do $gotrue$
declare v_set text := ''; v_kolon text;
  v_bos text[] := array['confirmation_token','recovery_token','email_change','email_change_token_new',
    'email_change_token_current','phone_change','phone_change_token','reauthentication_token'];
begin
  foreach v_kolon in array v_bos loop
    if exists (select 1 from information_schema.columns where table_schema='auth' and table_name='users' and column_name=v_kolon) then
      v_set := v_set || format('%I = coalesce(%I, %L), ', v_kolon, v_kolon, '');
    end if;
  end loop;
  if exists (select 1 from information_schema.columns where table_schema='auth' and table_name='users' and column_name='instance_id') then
    v_set := v_set || 'instance_id = coalesce(instance_id, ''00000000-0000-0000-0000-000000000000''::uuid), ';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='auth' and table_name='users' and column_name='is_sso_user') then
    v_set := v_set || 'is_sso_user = coalesce(is_sso_user, false), ';
  end if;
  v_set := v_set || 'aud = coalesce(aud, ''authenticated''), role = coalesce(role, ''authenticated''), '
        || 'email_confirmed_at = coalesce(email_confirmed_at, now()), created_at = coalesce(created_at, now()), updated_at = now(), '
        || 'raw_app_meta_data = coalesce(raw_app_meta_data, ''{"provider":"email","providers":["email"]}''::jsonb)';
  execute 'update auth.users set ' || v_set || ' where email in (select email from tezgah.seed9_hesap)';
end $gotrue$;

do $kimlik$
begin
  if exists (select 1 from information_schema.tables where table_schema='auth' and table_name='identities') then
    insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    select u.id, u.id::text, jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true,'phone_verified',false),
           'email', now(), now(), now()
      from auth.users u where u.email in (select email from tezgah.seed9_hesap)
       and not exists (select 1 from auth.identities i where i.user_id=u.id and i.provider='email');
  end if;
end $kimlik$;

insert into users (id, email, password_hash, role, plan)
select h.id, h.email, 'supabase-auth', 'host'::user_role, 'explorer'::plan_type from tezgah.seed9_hesap h
on conflict (id) do update set role = excluded.role, deleted_at = null, banned_at = null, shadow_limited = false, restricted_until = null;
update users u set gender = 'female'::user_gender from tezgah.seed9_hesap h where u.id = h.id and u.gender is null;
insert into profiles (user_id, name, profession, bio, languages, show_on_discovery, access_source, guest_capacity)
select h.id, h.ad, h.meslek, 'İş seyahatlerinde salonda tanışmayı seviyorum.', array['Türkçe','İngilizce'], true, 'Business bilet', 1
  from tezgah.seed9_hesap h
on conflict (user_id) do update set name = excluded.name, profession = excluded.profession, show_on_discovery = true;
insert into trust_scores (user_id, score, badge) select h.id, 78, 'verified' from tezgah.seed9_hesap h
on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;
insert into verifications (user_id, email_verified, email_verified_at, phone_verified, phone_verified_at, id_verified)
select h.id, true, now(), true, now(), true from tezgah.seed9_hesap h
on conflict (user_id) do update set email_verified = true, phone_verified = true, id_verified = true;
insert into consents (user_id, type, version)
select h.id, ty, 'v16' from tezgah.seed9_hesap h,
       unnest(array['no_lounge_sale','no_offplatform_payment','community_rules','venue_rules','terms_privacy','age_18']) ty
on conflict do nothing;

-- ── §1 · GENİŞ AKIŞ DÜNYASI ────────────────────────────────────────────────
do $akis$
declare
  nehir uuid; tuna uuid; selen uuid; arda uuid; bora uuid; cem uuid; duru uuid;
  hepsi uuid[];
  yarin date := current_date + 1;
  g2 date := current_date + 2; g3 date := current_date + 3; g4 date := current_date + 4; g5 date := current_date + 5;
  l_esb uuid; ad_esb text; l_adb_ic uuid; ad_adb_ic text; l_adb_thy uuid; ad_adb_thy text;
  l_ayt_thy uuid; ad_ayt_thy text; l_ist uuid; ad_ist text;
  p_tk uuid; p_pp uuid; p_bt uuid;
  te1 uuid; te2 uuid; tu1 uuid; tp uuid; nu uuid; ns uuid; su uuid;
  r_n1 uuid; r_n2 uuid; r4 uuid; r_s uuid; s_s uuid;
  c1 uuid; ch uuid; j jsonb; v_n int;
begin
  perform set_config('ll.test_mode', 'on', true);
  select id into nehir from tezgah.seed8_hesap where email = 'akis.host@seed.loungelink.test';
  select id into tuna  from tezgah.seed8_hesap where email = 'akis.host2@seed.loungelink.test';
  select id into arda  from tezgah.seed8_hesap where email = 'akis.misafir@seed.loungelink.test';
  select id into bora  from tezgah.seed8_hesap where email = 'akis.misafir2@seed.loungelink.test';
  select id into cem   from tezgah.seed8_hesap where email = 'akis.misafir3@seed.loungelink.test';
  select id into duru  from tezgah.seed8_hesap where email = 'akis.misafir4@seed.loungelink.test';
  select id into selen from tezgah.seed9_hesap where email = 'akis.host3@seed.loungelink.test';
  hepsi := array[nehir, tuna, selen, arda, bora, cem, duru]
        || array(select id from tezgah.seed8_hesap);

  -- ── Temizlik: YALNIZ iki tarafı da akis.* olan bağlantı/soru satırları ve Selen'in dünyası
  delete from messages where channel_id in (select c.id from chat_channels c join connection_requests cr on cr.id = c.connection_id
                                             where cr.from_id = any(hepsi) and cr.to_id = any(hepsi));
  delete from chat_channels where connection_id in (select id from connection_requests where from_id = any(hepsi) and to_id = any(hepsi));
  delete from connection_requests where from_id = any(hepsi) and to_id = any(hepsi);
  delete from availabilities a where a.host_id = selen
     and not exists (select 1 from requests r where r.avail_id = a.id);
  delete from visits where user_id = selen and not exists (select 1 from requests r where r.visit_id = visits.id);
  delete from rate_limits where user_id = any(hepsi);

  -- ── Programlar + kart hakları (SEED8 host'lara yalnız TK_MS ELPL veriyor)
  select id into p_tk from lounge_programs where code = 'TK_MS';
  select id into p_pp from lounge_programs where code = 'PRIORITY_PASS';
  select id into p_bt from lounge_programs where code = 'BUSINESS_TICKET';
  insert into host_entitlements (user_id, program_id, tier, verified)
  select x.u, x.p, null, true from (values (tuna, p_pp), (tuna, p_bt), (nehir, p_bt), (selen, p_bt), (nehir, p_pp), (selen, p_pp)) x(u, p)
   where not exists (select 1 from host_entitlements e where e.user_id = x.u and e.program_id = x.p);

  -- ── Salonlar (ad + havalimanıyla; uuid yok)
  select l.id, l.name into l_esb, ad_esb from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and v.active and l.airport_code = 'ESB' and v.name = 'Turkish Airlines Lounge' limit 1;
  select l.id, l.name into l_adb_ic, ad_adb_ic from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and v.active and l.airport_code = 'ADB' and v.name = 'Primeclass Lounge — İç Hat' limit 1;
  select l.id, l.name into l_adb_thy, ad_adb_thy from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and v.active and l.airport_code = 'ADB' and v.name = 'Turkish Airlines Lounge' limit 1;
  select l.id, l.name into l_ayt_thy, ad_ayt_thy from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and v.active and l.airport_code = 'AYT' and v.name = 'Turkish Airlines Lounge' limit 1;
  select a.lounge_id, a.lounge_name into l_ist, ad_ist from availabilities a where a.host_id = nehir and a.airport_code = 'IST' limit 1;
  if l_esb is null or l_adb_ic is null or l_adb_thy is null or l_ayt_thy is null or l_ist is null then
    raise exception 'SEED9: salon bulunamadı (ESB THY % · ADB Primeclass iç % · ADB THY % · AYT THY % · IST %)',
      l_esb, l_adb_ic, l_adb_thy, l_ayt_thy, l_ist;
  end if;

  -- ── İlanlar
  -- Tuna · ESB THY · g2 10–12 · TK_MS  → Arda AJet'le uçuyor: FARKLI HAVAYOLU (başvuramaz)
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (tuna, l_esb, 'ESB', ad_esb, g2, '10:00', '12:00', 2, 0, 'TK', 'Public', true, p_tk, 'beyan') returning id into te1;
  -- Tuna · ESB THY · g2 14–16 · TK_MS  → Nehir'e DOĞRUDAN DAVET
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (tuna, l_esb, 'ESB', ad_esb, g2, '14:00', '16:00', 2, 0, 'TK', 'Public', true, p_tk, 'beyan') returning id into te2;
  -- Tuna · ADB THY · g4 08–10 · Priority Pass → KURAL DOĞRULANMAMIŞ ("Host'a sor") · Arda soruyor
  -- (313: ESB THY + Business bileti resmî kaynaktan DOĞRULANMIŞ "misafir yok" → orada soru sorulamaz;
  --  bu senaryo artık "Bu kuralı doğruladık" rozetini gösteren ilan olarak ESB'de de duruyor: te3)
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (tuna, l_adb_thy, 'ADB', ad_adb_thy, g4, '08:00', '10:00', 1, 0, 'TK', 'Public', true, p_pp, 'beyan') returning id into tu1;
  -- Tuna · ESB THY · g3 10–12 · Business bileti → DOĞRULANMIŞ "misafir alınmıyor" (soru düğmesi YOK)
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (tuna, l_esb, 'ESB', ad_esb, g3, '10:00', '12:00', 1, 0, 'TK', 'Public', true, p_bt, 'beyan');
  -- Tuna · ADB Primeclass iç · g4 10–12 · Priority Pass → ÜCRETLİ misafir girişi
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, visibility, active, program_id, program_source)
  values (tuna, l_adb_ic, 'ADB', ad_adb_ic, g4, '10:00', '12:00', 2, 0, 'Public', true, p_pp, 'beyan') returning id into tp;
  -- Nehir · ADB THY · g4 14–16 · Priority Pass → doğrulanmamış; Bora soruyor, Arda'da "Host'a sor" açık
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (nehir, l_adb_thy, 'ADB', ad_adb_thy, g4, '14:00', '16:00', 1, 0, 'TK', 'Public', true, p_pp, 'beyan') returning id into nu;
  -- Nehir · IST · yarın 15:35–15:55 → Duru ile oturum: Duru TAMAMLADI, Nehir'in onayı bekleniyor
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '15:35', '15:55', 1, 0, 'TK', 'Public', true, p_tk, 'beyan') returning id into ns;
  -- Selen · ADB THY · g4 16–18 · Priority Pass → Arda soruyor, Selen "EVET + not" ile yanıtlıyor
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, program_id, program_source)
  values (selen, l_adb_thy, 'ADB', ad_adb_thy, g4, '16:00', '18:00', 1, 0, 'TK', 'Public', true, p_pp, 'beyan') returning id into su;

  -- ── Seyahatler
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code, purpose, party_size) values
    (arda,  'ESB', 'AYT', g2, '08:00', '18:00', 'VF3011', 'VF', 'business', 1),   -- AJet → THY salonunda farklı havayolu
    (arda,  'ESB', 'IST', g3, '08:00', '18:00', 'TK2123', 'TK', 'business', 1),
    (arda,  'ADB', 'IST', g4, '08:00', '18:00', 'TK2331', 'TK', 'business', 1),   -- ücretli ilan + doğrulanmamış ilan
    (arda,  'AYT', 'IST', g5, '08:00', '18:00', 'TK2413', 'TK', 'leisure',  1),
    (nehir, 'ESB', 'IST', g2, '09:00', '17:00', 'TK2125', 'TK', 'business', 1),
    (nehir, 'ADB', 'IST', g4, '09:00', '13:00', 'TK2333', 'TK', 'business', 1),
    (bora,  'ADB', 'AMS', g4, '12:00', '18:00', 'TK1951', 'TK', 'business', 1);

  -- ── Nehir MİSAFİR olarak
  perform tezgah.olarak(nehir);
  j := public.create_request(te1, 'lounge', 'Ankara''dayım, toplantı öncesi kahve?', null); r_n1 := (j->>'id')::uuid;
  j := public.create_request(tp, 'lounge', 'İzmir''de sabah vaktim var.', null); r_n2 := (j->>'id')::uuid;   -- BEKLİYOR
  perform tezgah.olarak(tuna);
  j := public.respond_request(r_n1, 'accept'); ch := (j->>'channel_id')::uuid;           -- KABUL
  insert into messages (channel_id, from_id, body, created_at) values (ch, tuna, 'Merhaba Nehir! Salonun girişinde buluşalım.', now() - interval '40 minutes');
  perform public.send_invite(nehir, te2, 'Öğleden sonra da ESB''deyim — gelmek ister misin?');  -- DOĞRUDAN DAVET

  -- ── Nehir'in ilanlarında karşı tarafın adımları
  select r.id into r4 from requests r join availabilities a on a.id = r.avail_id
   where r.guest_id = duru and a.host_id = nehir and r.status = 'accepted' limit 1;
  if r4 is null then raise exception 'SEED9: SEED8''in Duru isteği yok — SEED8 önce koşulmalı'; end if;
  perform tezgah.olarak(duru);
  j := public.start_session_request(r4);                                                  -- Duru BAŞLATTI, Nehir başlatmadı
  if j->>'status' <> 'pending' then raise exception 'SEED9: Duru yarım başlama bekleniyordu: %', j; end if;

  -- (Bora'nın SEED8'de 2 bekleyen isteği var = açık istek tavanı; bu adımı Duru atıyor)
  perform tezgah.olarak(duru);
  j := public.create_request(ns, 'lounge', 'Uçuş öncesi 20 dakika — hızlı bir kahve?', null); r_s := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.respond_request(r_s, 'accept'); ch := (j->>'channel_id')::uuid;
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Tamam, 15:35''te girişteyim.', now() - interval '10 minutes');
  perform public.start_session_request(r_s);
  perform tezgah.olarak(duru);
  j := public.start_session_request(r_s); s_s := (j->>'id')::uuid;
  j := public.confirm_session(s_s);                                                       -- Duru TAMAMLADI, Nehir onaylamadı
  if (j->>'completed')::boolean then raise exception 'SEED9: tek onayla tamamlanmamalıydı'; end if;

  -- ── Bağlantılar
  perform tezgah.olarak(cem);
  j := public.send_connection(arda, 'coffee', 'Aynı rotadayız, salonda kahve?'); c1 := (j->>'id')::uuid;
  if c1 is null then select id into c1 from connection_requests where from_id = cem and to_id = arda order by created_at desc limit 1; end if;
  perform tezgah.olarak(arda);
  perform public.respond_connection(c1, true);                                            -- Arda ↔ Cem KABUL
  j := public.baglanti_sohbeti_ac(c1); ch := coalesce((j->>'channel_id')::uuid, (j->>'id')::uuid,
        (select id from chat_channels where connection_id = c1 limit 1));
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, cem,  'Selam Arda! Frankfurt''a mı gidiyordun?', now() - interval '3 hours'),
    (ch, arda, 'Evet, konferans var. Sen?', now() - interval '2 hours 50 minutes'),
    (ch, cem,  'Ben de oradayım — orada da görüşürüz.', now() - interval '2 hours 45 minutes');
  perform tezgah.olarak(bora);
  perform public.send_connection(arda, 'networking', 'Finans tarafında çalışıyorum, tanışalım mı?');   -- Arda'ya GELEN
  perform tezgah.olarak(arda);
  perform public.send_connection(duru, 'hello', 'Merhaba, aynı gün CDG''ye uçuyoruz sanırım.');       -- Arda'nın GÖNDERDİĞİ
  perform tezgah.olarak(duru);
  perform public.send_connection(nehir, 'coffee', 'Tasarım tarafında çalışıyorsun, tanışmak isterim.'); -- Nehir'e GELEN

  -- ── Sorular (kural doğrulanmamış ilanlar)
  perform tezgah.olarak(arda);
  j := public.ilan_kurali_sor(tu1);                                                       -- Arda → Tuna BEKLİYOR
  if j->>'durum' <> 'soruldu' then raise exception 'SEED9: Arda→Tuna sorusu: %', j; end if;
  j := public.ilan_kurali_sor(su);                                                        -- Arda → Selen …
  if j->>'durum' <> 'soruldu' then raise exception 'SEED9: Arda→Selen sorusu: %', j; end if;
  perform tezgah.olarak(selen);
  -- 314: host YAZILI yanıt verir; bağlantıyı kabul edince sohbet SORU + YANIT ile başlar.
  perform public.soruya_cevap_yaz((j->>'baglanti_id')::uuid,
    'O gün First uçuyorum; First''te 1 misafir hakkım var, ilanıma ekliyorum.');           -- … YANITLADI
  perform public.respond_connection((j->>'baglanti_id')::uuid, true);                     -- … ve BAĞLANDI
  perform tezgah.olarak(bora);
  j := public.ilan_kurali_sor(nu);                                                        -- Bora → Nehir (Nehir'e GELEN soru)
  if j->>'durum' <> 'soruldu' then raise exception 'SEED9: Bora→Nehir sorusu: %', j; end if;

  perform tezgah.olarak(null);
  delete from rate_limits where user_id = any(hepsi);
  perform set_config('ll.test_mode', '', true);
  raise notice 'SEED9: geniş akış dünyası kuruldu';
end $akis$;

-- ── §2 · SAYILAR TUTUYOR MU? (ana sayfa kutuları = açılan listeler) ──────────
create table if not exists tezgah.seed9_sayim (hesap text, alan text, kutu int, liste int, primary key (hesap, alan));
revoke all on tezgah.seed9_sayim from public;
truncate tezgah.seed9_sayim;
do $sayim$
declare r record; a jsonb; v_istek int; v_sohbet int; v_davet int; v_soru int; v_bag int; v_otr int;
begin
  for r in select id, email from tezgah.seed8_hesap where email in ('akis.host@seed.loungelink.test','akis.misafir@seed.loungelink.test') loop
    perform tezgah.olarak(r.id);
    a := public.ana_sayfa_akisi();
    select count(*) into v_istek from (
      select id from public.host_requests() where status = 'pending'
      union all select id from public.my_sent_requests() where status = 'pending') x;
    select count(*) into v_otr from (
      select id from public.host_requests() where status = 'accepted'
      union all select id from public.my_sent_requests() where status = 'accepted') x;
    select count(*) into v_bag from connection_requests cr
     where cr.status = 'accepted' and (cr.from_id = r.id or cr.to_id = r.id)
       and not public.is_blocked_pair(r.id, case when cr.from_id = r.id then cr.to_id else cr.from_id end);
    -- Davet kutusu (app) = lounge daveti + bana gelen bağlantı isteği = Davet ekranı (pending_actions)
    select count(*) into v_davet from public.pending_actions();
    -- Soru kutusu (313) = bana gelen yanıt bekleyen + benim yanıt beklediğim = Soru ekranı (iki sekme)
    select (select count(*) from public.bana_gelen_sorular() where cevap_at is null and durum <> 'declined')
         + (select count(*) from public.sorularim() where cevap_durumu = 'bekliyor') into v_soru;
    insert into tezgah.seed9_sayim values
      (r.email, 'İstek (bekleyen)', (a->>'istek')::int, v_istek),
      (r.email, 'Sohbet (oturum + bağlantı)', (a->>'sohbet')::int, v_otr + v_bag),
      (r.email, 'Davet (davet + bağlantı isteği)', (a->>'davet')::int + (a->>'baglanti')::int, v_davet),
      (r.email, 'Soru (gelen + gönderdiğim, yanıt bekleyen)', (a->>'soru')::int, v_soru);
  end loop;
  perform tezgah.olarak(null);
  if exists (select 1 from tezgah.seed9_sayim where kutu <> liste) then
    raise exception 'SEED9: ana sayfa sayısı listeyle tutmuyor: %',
      (select string_agg(hesap || ' ' || alan || ' ' || kutu || '≠' || liste, '; ') from tezgah.seed9_sayim where kutu <> liste);
  end if;
  raise notice 'SEED9: ana sayfa kutuları açılan listelerle BİREBİR';
end $sayim$;

select hesap, alan, kutu as "ana sayfa", liste as "açılan liste" from tezgah.seed9_sayim order by 1, 2;
