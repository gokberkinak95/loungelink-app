-- ============================================================================
-- LoungeLink · canli_fikstur.sql        (18 Agustos 2026)
--
-- 🔴 BU DOSYA BIR MIGRATION DEGILDIR VE KURULUMA GIRMEZ.
--    Yalniz pg_run.py'nin CANLI CAGRI GECISI icin veri uretir.
--    Sema klasorunde degil, harness klasorunde durmasinin sebebi budur.
--
-- NEDEN VAR:
--   Gokberk canlida iki kez 42804 aldi (186 · my_sent_requests). Harness
--   yesil yaniyordu cunku `returns table` sozlesmesi ancak BIR SATIR
--   dondugunde dogrulaniyor ve SEED'lerin urettigi TEK request `completed`
--   durumundaydi. `my_sent_requests()` ise yalniz pending/accepted okuyor.
--   Yani fonksiyonun okudugu durum veritabaninda HIC OLUSMAMISTI.
--
--   OLCUM (18 Agu, temiz kosu): requests 1 satir · hepsi 'completed'.
--   Sonuc: 79 fonksiyondan 46'si satir donduruyordu; my_sent_requests,
--   host_requests, pending_actions, my_visits... 0 satirla "gecti".
--
-- KURAL: burasi SENARYO uretmez, DURUM uretir. Amac "gercekci bir kullanici
-- yolculugu" degil; amac uygulamanin okudugu HER DURUMDA en az bir satir
-- bulunmasi. Bir durum burada eksikse, o fonksiyonun tip sozlesmesi
-- dogrulanmamis demektir ve gecis bunu SAYIYLA yazar.
-- ============================================================================

do $fikstur$
declare
  v_host    uuid;
  v_guest   uuid;
  v_guest2  uuid;
  v_av      uuid;
  v_av2     uuid;
  v_av3     uuid;
  v_req     uuid;
begin
  -- Host: en cok ilani olan. Guest: host'tan FARKLI olmali (requests_check).
  select a.host_id into v_host
  from availabilities a
  group by a.host_id order by count(*) desc limit 1;

  select u.id into v_guest from users u
   where u.id <> v_host and u.email like 'kmisafir%@seed.loungelink.test'
   order by u.email limit 1;
  select u.id into v_guest2 from users u
   where u.id <> v_host and u.id <> v_guest
     and u.email like 'kmisafir%@seed.loungelink.test'
   order by u.email offset 1 limit 1;

  if v_host is null or v_guest is null then
    -- 🔴 SESSIZ GECME YOK. Fikstur veri uretemediyse bunu BILMEK gerekir,
    --    yoksa gecis "46 dogrulandi" deyip ayni korlugu surdurur.
    raise exception 'fikstur: host/guest bulunamadi (host=% guest=%)', v_host, v_guest;
  end if;

  -- Gelecek tarihli, dolu olmayan uc ilan sec. Gecmis tarihli ilan
  -- discover'dan duser; pending/accepted talep GELECEK ilana baglanir.
  select a.id into v_av from availabilities a
   where a.host_id = v_host and a.avail_date >= current_date
     and coalesce(a.filled,0) < coalesce(a.slots,1)
   order by a.avail_date limit 1;
  -- 🔴 `offset 1` YAZMISTIM VE BIR ILANI ATLIYORDU: `a.id <> v_av` zaten
  --    ilkini eliyor, ustune offset koyunca ikinci ilan da atlaniyordu ve
  --    `accepted` durumu HIC OLUSMUYORDU. Olctum: requests'te yalniz
  --    pending vardi. Offset kaldirildi.
  select a.id into v_av2 from availabilities a
   where a.host_id = v_host and a.avail_date >= current_date and a.id <> v_av
   order by a.avail_date limit 1;
  select a.id into v_av3 from availabilities a
   where a.host_id = v_host and a.avail_date >= current_date
     and a.id not in (coalesce(v_av, '00000000-0000-0000-0000-000000000000'::uuid),
                      coalesce(v_av2,'00000000-0000-0000-0000-000000000000'::uuid))
   order by a.avail_date limit 1;

  if v_av is null then
    raise exception 'fikstur: host % icin GELECEK tarihli ilan yok', v_host;
  end if;

  -- ── DURUM 1 · PENDING ─────────────────────────────────────────────
  -- my_sent_requests · host_requests · pending_actions bunu okur.
  insert into requests (guest_id, host_id, avail_id, status, intro_message,
                        idempotency_key)
  values (v_guest, v_host, v_av, 'pending',
          'fikstur: bekleyen talep', 'fikstur-pending-1')
  on conflict do nothing;

  -- ── DURUM 2 · ACCEPTED ────────────────────────────────────────────
  -- Sohbet, bulusma karti ve "kabul edilmis talep" yollari bunu okur.
  if v_av2 is not null and v_guest2 is not null then
    insert into requests (guest_id, host_id, avail_id, status, intro_message,
                          responded_at, idempotency_key)
    values (v_guest2, v_host, v_av2, 'accepted',
            'fikstur: kabul edilmis talep', now(), 'fikstur-accepted-1')
    on conflict do nothing;
  end if;

  -- ── DURUM 3 · DECLINED ────────────────────────────────────────────
  if v_av3 is not null then
    insert into requests (guest_id, host_id, avail_id, status, intro_message,
                          responded_at, idempotency_key)
    values (v_guest, v_host, v_av3, 'declined',
            'fikstur: reddedilmis talep', now(), 'fikstur-declined-1')
    on conflict do nothing;
  end if;

  raise notice 'fikstur: host=% guest=% pending/accepted/declined kuruldu',
    v_host, v_guest;
end
$fikstur$;

-- ── BAGLANTI (connection_requests) ──────────────────────────────────
-- my_connections · home_connections bunu okur.
do $fikstur2$
declare v_a uuid; v_b uuid; v_kolon text;
begin
  select id into v_a from users where email = 'kural10@seed.loungelink.test';
  select id into v_b from users where email = 'kmisafir1@seed.loungelink.test';
  if v_a is null or v_b is null then
    raise notice 'fikstur: baglanti icin kullanici yok, atlandi';
    return;
  end if;
  -- Kolon adlarini VARSAYMIYORUM — semadan okuyorum. (Bu depoda
  -- "kolon adini varsaydim" hatasi bu turda uc kez cikti.)
  select string_agg(column_name, ',' order by ordinal_position) into v_kolon
  from information_schema.columns
  where table_schema='public' and table_name='connection_requests';
  raise notice 'connection_requests kolonlari: %', v_kolon;

  -- Olculen duzen (18 Agu): id,from_id,to_id,intent,intro,status,created_at,responded_at
  if v_kolon like '%from_id%' and v_kolon like '%to_id%' then
    execute format(
      'insert into connection_requests (from_id, to_id, status)
       values (%L, %L, %L) on conflict do nothing', v_a, v_b, 'accepted');
  elsif v_kolon like '%requester_id%' and v_kolon like '%target_id%' then
    execute format(
      'insert into connection_requests (requester_id, target_id, status)
       values (%L, %L, %L) on conflict do nothing', v_a, v_b, 'accepted');
  elsif v_kolon like '%from_user%' and v_kolon like '%to_user%' then
    execute format(
      'insert into connection_requests (from_user, to_user, status)
       values (%L, %L, %L) on conflict do nothing', v_a, v_b, 'accepted');
  else
    raise notice 'fikstur: connection_requests kolon duzeni taninmadi, atlandi';
  end if;
exception when others then
  -- Baglanti fiksturu ZORUNLU degil; ama sessizce gecmesin.
  raise notice 'fikstur: baglanti kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur2$;

-- ── DURUM 4 · PUANLANMAMIS TAMAMLANMIS OTURUM ────────────────────────
-- `pending_ratings()` (186'da tanimli) ve `unrated_sessions()` bunu okur.
-- Olctum: SEED tek bir tamamlanmis oturum uretiyor ve IKI TARAF DA
-- puanlamis (ratings=2). Yani puan bekleyen ekranin dondurdugu satir
-- HIC OLUSMUYOR ve 186'nin ikinci fonksiyonunun tip sozlesmesi
-- dogrulanmadan geciyordu — my_sent_requests ile TAM AYNI korluk.
do $fikstur3$
declare v_host uuid; v_guest uuid; v_av uuid; v_req uuid; v_ses uuid;
begin
  select r.host_id into v_host from requests r
   where r.status in ('pending','accepted') limit 1;
  select u.id into v_guest from users u
   where u.id <> v_host and u.email like 'kmisafir%@seed.loungelink.test'
   order by u.email desc limit 1;
  -- 🔴 "TALEBI OLMAYAN ILAN" SARTI FAZLA DARDI: yukaridaki uc durum o
  --    host'un ilanlarini zaten tuketiyordu ve bu blok her kosuda
  --    "uygun ilan yok" deyip atlaniyordu. `completed` talep, benzersiz
  --    indeksin kapsamina (pending/accepted) girmiyor; ayni ilana
  --    baglanmasinda sakinca yok. Tek sart: ayni misafirin o ilanda
  --    AKTIF talebi olmamasi.
  select a.id into v_av from availabilities a
   where a.host_id = v_host
     and not exists (select 1 from requests r
                     where r.avail_id = a.id and r.guest_id = v_guest
                       and r.status in ('pending','accepted'))
   limit 1;
  if v_host is null or v_guest is null or v_av is null then
    raise notice 'fikstur: puanlanmamis oturum icin uygun ilan yok, atlandi';
    return;
  end if;

  insert into requests (guest_id, host_id, avail_id, status, responded_at,
                        idempotency_key)
  values (v_guest, v_host, v_av, 'completed', now(), 'fikstur-completed-1')
  returning id into v_req;

  insert into sessions (request_id, status, started_at, completed_at,
                        host_confirmed, guest_confirmed)
  values (v_req, 'completed', now() - interval '2 hours', now() - interval '1 hour',
          true, true)
  returning id into v_ses;

  update requests set visit_id = null where id = v_req;
  raise notice 'fikstur: puanlanmamis tamamlanmis oturum kuruldu (%)', v_ses;
exception when others then
  raise notice 'fikstur: puanlanmamis oturum kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur3$;

-- ── DURUM 5 · SIKAYET + I18N GECERSIZ KILMA ──────────────────────────
-- `my_reports()` ve `i18n_overrides('tr')` bu iki tabloyu okuyor; ikisi
-- de SEED'de BOS oldugu icin sozlesmeleri hic dogrulanmiyordu.
do $fikstur4$
declare v_a uuid; v_b uuid; v_tip text;
begin
  select id into v_a from users where email = 'kmisafir1@seed.loungelink.test';
  select id into v_b from users where email = 'kural10@seed.loungelink.test';
  select e.enumlabel into v_tip from pg_enum e
    join pg_type t on t.oid = e.enumtypid where t.typname = 'report_type'
   order by e.enumsortorder limit 1;
  if v_a is not null and v_b is not null and v_tip is not null then
    execute format(
      'insert into reports (reporter_id, target_id, type, description)
       values (%L, %L, %L, %L)', v_a, v_b, v_tip, 'fikstur: ornek sikayet');
  else
    raise notice 'fikstur: sikayet kurulamadi (kullanici/enum yok)';
  end if;
exception when others then
  raise notice 'fikstur: sikayet kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur4$;

insert into i18n_strings (key, lang, value, note)
values ('fikstur.ornek', 'tr', 'Fikstur ornegi', 'canli cagri gecisi icin')
on conflict (key, lang) do nothing;

-- ── DURUM 6 · BUGUN TARIHLI ILAN (lounge_radar_people) ───────────────
-- `lounge_radar_people()` filtresi: `a.host_id = v_uid and a.active and
-- a.avail_date = current_date`. SEED'in ilanlari GELECEK tarihli oldugu
-- icin radar hicbir zaman satir dondurmuyordu.
do $fikstur5$
declare v_host uuid; v_ornek availabilities%rowtype;
begin
  select r.host_id into v_host from requests r
   where r.status in ('pending','accepted') limit 1;
  if v_host is null then
    select a.host_id into v_host from availabilities a limit 1;
  end if;
  select * into v_ornek from availabilities a where a.host_id = v_host limit 1;
  if v_ornek.id is null then
    raise notice 'fikstur: radar icin ornek ilan yok, atlandi'; return;
  end if;
  -- Var olan bir ilani KOPYALAYIP tarihini bugune cekiyoruz: kolonlari
  -- tek tek yazsaydim, sema degistiginde bu fikstur sessizce eskirdi.
  insert into availabilities (host_id, airport_code, lounge_id, lounge_name,
                              avail_date, time_from, time_to, slots, filled,
                              visibility, flight_number, active, min_trust,
                              program_id, venue_id, carrier)
  values (v_ornek.host_id, v_ornek.airport_code, v_ornek.lounge_id,
          -- 🔴 SAAT PENCERESI GUN BOYU OLMALI. Once '08:00'-'20:00' yazdim
          --    ve radar YINE 0 satir dondu: `lounge_radar_people` filtresi
          --    `a.time_from <= current_time and current_time <= a.time_to`
          --    diyor, kosu ise 06:47 UTC'de yapiliyordu. Yani fiksturum
          --    gunun saatine gore BAZEN calisan bir test uretmisti —
          --    kirilgan testin en kotu turu, cunku yesil yandiginda
          --    "duzeldi" sanirsin.
          v_ornek.lounge_name, current_date, '00:00', '23:59', 2, 0,
          v_ornek.visibility, v_ornek.flight_number, true, 0,
          v_ornek.program_id, v_ornek.venue_id, v_ornek.carrier);
  raise notice 'fikstur: BUGUN tarihli ilan kuruldu (radar)';
exception when others then
  raise notice 'fikstur: bugunku ilan kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur5$;

-- ── DURUM 7 · DAVET · UCUS SORGU KAYDI · SALON YETKILISI ─────────────
-- pending_actions (invites) · flight_quota_report (flight_fetch_log) ·
-- partner_lounges (lounge_partners). Ucu de SEED'de BOS tablo.
do $fikstur6$
declare v_host uuid; v_guest uuid; v_av uuid; v_lounge uuid;
begin
  select r.host_id into v_host from requests r where r.status='pending' limit 1;
  select r.guest_id into v_guest from requests r where r.status='pending' limit 1;
  select a.id into v_av from availabilities a where a.host_id = v_host limit 1;

  if v_host is not null and v_guest is not null then
    insert into invites (host_id, guest_id, avail_id, note, status)
    values (v_host, v_guest, v_av, 'fikstur: davet', 'pending');
    raise notice 'fikstur: davet kuruldu (pending_actions)';

    insert into flight_fetch_log (user_id, flight_no, flight_day, outcome)
    values (v_guest, 'TK1980', current_date, 'provider'),
           (v_guest, 'TK1980', current_date, 'cache');
    raise notice 'fikstur: ucus sorgu kaydi kuruldu (flight_quota_report)';
  end if;

  -- Salon yetkilisi: HEM ortagi HEM kabul satiri olan bir salon sec ki
  -- venue_partners ve card_advice_for_lounge da ayni salondan beslensin.
  select l.id into v_lounge
    from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active
     and exists (select 1 from lounge_venue_partners vp
                  where vp.venue_id = v.id and vp.active)
     and exists (select 1 from lounge_venue_acceptance a
                  where a.venue_id = v.id and a.active and a.accepted)
   limit 1;
  if v_lounge is not null and v_host is not null then
    insert into lounge_partners (user_id, lounge_id, role)
    values (v_host, v_lounge, 'manager')
    on conflict do nothing;
    raise notice 'fikstur: salon yetkilisi kuruldu (partner_lounges) salon=%', v_lounge;
  else
    raise notice 'fikstur: uygun salon bulunamadi (partner_lounges atlandi)';
  end if;
exception when others then
  raise notice 'fikstur: davet/ucus/yetkili kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur6$;

-- ── DURUM 8 · ANONIMLESTIRILMIS KULLANICI ────────────────────────────
-- `anonymized_users()` filtresi `anonymized_at is not null`. Var olan bir
-- SEED kullanicisini bozmuyorum — AYRI bir kullanici aciyorum, cunku bu
-- fikstur degismezlerden SONRA kossa bile veri butunlugunu kirletmemeli.
do $fikstur7$
declare v_id uuid := '00000000-0000-4000-8000-0000000f1c50';
begin
  insert into auth.users (id, email, role, aud)
  values (v_id, 'fikstur-anonim@seed.loungelink.test', 'authenticated', 'authenticated')
  on conflict (id) do nothing;
  insert into users (id, email, role, anonymized_at)
  values (v_id, 'fikstur-anonim@seed.loungelink.test', 'guest', now())
  on conflict (id) do update set anonymized_at = now();
  raise notice 'fikstur: anonimlestirilmis kullanici kuruldu';
exception when others then
  raise notice 'fikstur: anonim kullanici kurulamadi → % (%)', sqlerrm, sqlstate;
end
$fikstur7$;

-- ── DURUM 9 · KONUM PAYLASIMI ACIK ───────────────────────────────────
-- `lounge_radar_people()` ilk satirda `profiles.location_sharing` bakiyor;
-- kapaliysa hemen bos donuyor. SEED'de kimsede acik degildi.
update profiles set location_sharing = true
 where user_id in (select r.host_id from requests r where r.status = 'pending');

-- ── DURUM 10 · RADARDA GÖRÜNECEK İKİNCİ KİŞİ ─────────────────────────
-- `lounge_radar_people()` "aynı havalimanında, bugün, örtüşen saatte
-- olan BAŞKA kişiler"i döndürüyor. Fikstür bugüne ilan koyunca fonksiyon
-- ÇALIŞTI (ve 218'e yol açan üç kusur ortaya çıktı) ama 0 satır döndü:
-- ortada tek kişi vardı. Sözleşmenin doğrulanması için KARŞIDA BİRİ
-- olmalı — o yüzden aynı havalimanına bugün bir ziyaret ekliyoruz.
do $fikstur8$
declare v_host uuid; v_air char(3); v_baska uuid;
begin
  select a.host_id, a.airport_code into v_host, v_air
    from availabilities a
   where a.active and a.avail_date = current_date
   order by a.created_at desc nulls last limit 1;
  if v_host is null then
    raise notice 'fikstur: bugunku ilan yok, radar ikinci kisi atlandi'; return;
  end if;
  select u.id into v_baska from users u
   where u.id <> v_host and u.email like 'k%@seed.loungelink.test'
   order by u.email limit 1;
  if v_baska is null then
    raise notice 'fikstur: radar icin ikinci kullanici yok'; return;
  end if;

  update profiles set location_sharing = true where user_id = v_baska;
  insert into visits (user_id, airport_code, visit_date, time_from, time_to,
                      flight_number)
  values (v_baska, v_air, current_date, '00:00', '23:59', 'TK1980');
  raise notice 'fikstur: radara ikinci kisi eklendi (%, %)', v_air, v_baska;
exception when others then
  raise notice 'fikstur: radar ikinci kisi eklenemedi → % (%)', sqlerrm, sqlstate;
end
$fikstur8$;
