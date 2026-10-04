-- ============================================================================
-- yuk_veri_uret.sql — PERFORMANS / YÜK TESTİ İÇİN ÖLÇEKLİ DÜNYA (4 Ekim 2026)
-- YALNIZ yerel ll_yuk (ll'in kopyası) üzerinde koşar — Supabase'e ve test dünyasına GİTMEZ.
-- (Yerel araç olduğu için temp tablo kullanır; Supabase Editor kuralı burada geçerli değil.)
--
-- Senaryo "büyüme yılı": 50.000 üye (10.000 host · 40.000 misafir), 30 gün ileriye
-- 30.000 ilan, 60.000 seyahat, 150.000 istek, 60.000 oturum, 90.000 puan,
-- 600.000 bildirim, 50.000 sohbet kanalı + 300.000 mesaj, 100.000 bağlantı,
-- 250.000 kredi + 150.000 puan hareketi. Tetikleyiciler kapalı (replica).
-- ============================================================================
set session_replication_role = replica;
set synchronous_commit = off;
set work_mem = '256MB';

insert into users (id, email, role, gender, password_hash, created_at)
select gen_random_uuid(), 'yuk.' || g || '@yuk.loungelink.test',
       case when g % 5 = 0 then 'host'::user_role else 'guest'::user_role end,
       (array['female','male','other','prefer_not_to_say'])[1 + g % 4]::user_gender,
       'supabase-auth', now() - (g % 400) * interval '1 day'
  from generate_series(1, 50000) g;

create temp table yh as select row_number() over () - 1 as rn, id from users where email like 'yuk.%' and role = 'host';
create temp table yg as select row_number() over () - 1 as rn, id from users where email like 'yuk.%' and role = 'guest';
create temp table yl as select row_number() over () - 1 as rn, id, airport_code, name from lounges where active;
create index on yh(rn); create index on yg(rn); create index on yl(rn);
select (select count(*) from yh) hostlar, (select count(*) from yg) misafirler, (select count(*) from yl) salonlar;

insert into profiles (user_id, name, profession, show_on_discovery)
select u.id, 'Yük ' || substr(u.email, 5, 6),
       (array['Yazılım','Finans','Hukuk','Sağlık','Danışmanlık','Medya','Akademi'])[1 + abs(hashtext(u.email)) % 7], true
  from users u where u.email like 'yuk.%';
insert into verifications (user_id, email_verified, phone_verified)
select id, true, (abs(hashtext(email)) % 3 <> 0) from users where email like 'yuk.%';
insert into trust_scores (user_id, score, badge)
select id, 10 + abs(hashtext(email)) % 80, 'New' from users where email like 'yuk.%';

-- 30.000 ilan
insert into availabilities (id, host_id, airport_code, lounge_id, lounge_name, avail_date, time_from, time_to, slots, filled, visibility, active, created_at)
select gen_random_uuid(), h.id, l.airport_code, l.id, l.name,
       current_date + (g % 30), time '06:00' + ((g % 14) * interval '1 hour'),
       time '08:00' + ((g % 14) * interval '1 hour'), 1 + g % 2, 0, 'Public'::availability_visibility, true,
       now() - (g % 20) * interval '1 hour'
  from generate_series(1, 30000) g
  join yh h on h.rn = g % (select count(*) from yh)
  join yl l on l.rn = (g * 7) % (select count(*) from yl);
create temp table ya as select row_number() over () - 1 as rn, id, host_id from availabilities where host_id in (select id from yh);
create index on ya(rn);

-- 60.000 seyahat
insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number, party_size)
select m.id, (array['IST','SAW','ESB','ADB','AYT','DLM','BJV'])[1 + g % 7], current_date + (g % 30),
       time '07:00' + ((g % 12) * interval '1 hour'), time '09:00' + ((g % 12) * interval '1 hour'),
       'TK' || (1000 + g % 900), 1
  from generate_series(1, 60000) g
  join yg m on m.rn = g % (select count(*) from yg);

-- 150.000 istek (durum karışımı)
insert into requests (id, guest_id, host_id, avail_id, status, type, created_at, responded_at)
select gen_random_uuid(), m.id, a.host_id, a.id,
       (array['pending','accepted','declined','completed','completed','cancelled','expired'])[1 + g % 7]::request_status,
       'standard'::request_type, now() - (g % 60) * interval '1 day', now() - (g % 60) * interval '1 day' + interval '2 hour'
  from generate_series(1, 150000) g
  join yg m on m.rn = (g * 13) % (select count(*) from yg)
  join ya a on a.rn = (g * 7) % (select count(*) from ya)
on conflict do nothing;   -- (misafir, ilan) etkin çifti benzersiz (requests_guest_avail_active_uniq)

-- Oturumlar: kabul/tamamlanan isteklerden 60.000
insert into sessions (id, request_id, status, started_at, completed_at, host_confirmed, guest_confirmed)
select gen_random_uuid(), r.id,
       case when r.status = 'completed' then 'completed'::session_status else 'active'::session_status end,
       r.created_at + interval '1 day', case when r.status = 'completed' then r.created_at + interval '1 day 2 hour' end,
       r.status = 'completed', r.status = 'completed'
  from (select id, status, created_at from requests where status in ('accepted','completed') and guest_id in (select id from yg) limit 60000) r;

-- 90.000 puan (tamamlanan oturumlarda iki yönlü)
insert into ratings (session_id, rater_id, rated_id, score, comment)
select s.id, r.guest_id, r.host_id, 3 + (abs(hashtext(s.id::text)) % 3), null
  from sessions s join requests r on r.id = s.request_id where s.status = 'completed' and r.guest_id in (select id from yg);
insert into ratings (session_id, rater_id, rated_id, score, comment)
select s.id, r.host_id, r.guest_id, 4 + (abs(hashtext(s.id::text)) % 2), null
  from sessions s join requests r on r.id = s.request_id where s.status = 'completed' and r.guest_id in (select id from yg)
 limit 45000;

-- 600.000 bildirim (ortalama 12 / üye; okunmuş/okunmamış karışık)
insert into notifications (user_id, category, title, body, read, created_at)
select u.id, (array['requests','sessions','invites','connections','system','credits','ratings'])[1 + g % 7]::notif_category,
       'Yük bildirimi ' || g, 'Gövde', (g % 3 <> 0), now() - (g % 90) * interval '1 day'
  from generate_series(1, 600000) g
  join (select row_number() over () - 1 rn, id from users where email like 'yuk.%') u on u.rn = g % 50000;

-- 100.000 bağlantı
insert into connection_requests (from_id, to_id, status, created_at, responded_at)
select a.id, b.id, (array['pending','accepted','accepted','declined'])[1 + g % 4]::connection_status,
       now() - (g % 120) * interval '1 day', now() - (g % 120) * interval '1 day' + interval '1 hour'
  from generate_series(1, 100000) g
  join yg a on a.rn = g % (select count(*) from yg)
  join yg b on b.rn = (g * 31 + 7) % (select count(*) from yg)
 where a.id <> b.id
on conflict do nothing;

-- 50.000 sohbet kanalı (oturum + bağlantı) · 300.000 mesaj
insert into chat_channels (id, request_id, kind, active, created_at)
select gen_random_uuid(), s.request_id, 'lounge', true, s.started_at from sessions s
  join requests r on r.id = s.request_id where r.guest_id in (select id from yg) limit 50000;
create temp table yc as select row_number() over () - 1 rn, c.id, r.guest_id, r.host_id
  from chat_channels c join requests r on r.id = c.request_id where r.guest_id in (select id from yg);
create index on yc(rn);
insert into messages (channel_id, from_id, body, created_at)
select c.id, case when g % 2 = 0 then c.guest_id else c.host_id end, 'Yük mesajı ' || g, now() - (g % 30) * interval '1 hour'
  from generate_series(1, 300000) g
  join yc c on c.rn = g % (select count(*) from yc);

-- 250.000 kredi · 150.000 puan hareketi
insert into credit_ledger (user_id, delta, reason, balance_after, created_at)
select u.id, (array[5, -1, -1, 1, 2])[1 + g % 5], (array['signup','request_hold','request_hold','refund','plan_monthly'])[1 + g % 5], 5,
       now() - (g % 200) * interval '1 day'
  from generate_series(1, 250000) g
  join (select row_number() over () - 1 rn, id from users where email like 'yuk.%') u on u.rn = g % 50000;
insert into points_ledger (user_id, delta, reason, balance_after, created_at)
select u.id, 100 + g % 400, 'session_complete', 500, now() - (g % 200) * interval '1 day'
  from generate_series(1, 150000) g
  join (select row_number() over () - 1 rn, id from users where email like 'yuk.%') u on u.rn = g % 50000;

set session_replication_role = origin;
analyze;
select 'users' t, count(*) from users union all select 'availabilities', count(*) from availabilities
union all select 'requests', count(*) from requests union all select 'sessions', count(*) from sessions
union all select 'notifications', count(*) from notifications union all select 'messages', count(*) from messages
union all select 'connection_requests', count(*) from connection_requests union all select 'visits', count(*) from visits;
