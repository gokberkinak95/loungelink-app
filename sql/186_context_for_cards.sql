-- ============================================================
-- LoungeLink · 186_context_for_cards.sql
-- KARTLAR BAĞLAMSIZDI — HATIRLAMAK KULLANICININ İŞİ DEĞİL
--
-- ⚠️ Uygulamayı ETKİLER (iki RPC'nin dönüşü genişliyor).
--
-- ------------------------------------------------------------
-- 🔴 SORUN (Gökberk madde 12 ve 13)
-- ------------------------------------------------------------
-- pending_ratings yalnız şunu döndürüyordu:
--   session_id · other_id · other_name · lounge · completed_at
-- "Kapıda ne oldu?" sorusu birkaç gün sonra ekrana düşünce kullanıcı
-- HANGİ uçuş, HANGİ tarih, HANGİ ilan olduğunu hatırlamak zorunda
-- kalıyor. Hatırlamak bizim işimiz: veri zaten availabilities'te.
--
-- Aynısı ana sayfadaki misafir istek kartları için de geçerliydi:
-- host tarafı zengin, misafir tarafı çıplaktı (v2.52'de kart
-- zenginleştirildi ama kaynak RPC hâlâ dar).
--
-- Kural: bir kart kullanıcıdan HATIRLAMASINI istiyorsa, o kart eksik.
-- ============================================================

-- sqlcheck: allow-replace pending_ratings  (üstte drop var)
drop function if exists public.pending_ratings();
create or replace function public.pending_ratings()
returns table (
  session_id uuid, request_id uuid, other_id uuid, other_name text,
  lounge text, completed_at timestamptz, i_am_host boolean,
  -- 🔴 186: bağlam alanları
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
         -- 🔴 char(3) → text CAST'I ŞART. `availabilities.airport_code`
         -- CHAR(3); `returns table(... airport_code text ...)` diyorsak
         -- PostgreSQL satır döndüğü ANDA 42804 verir:
         --   "Returned type character(3) does not match expected type text"
         -- Bu hata SATIR YOKKEN ÇIKMAZ — sıfır satırda coercion hiç
         -- yapılmaz. Bu yüzden kurulum sırasına göre bazı veritabanında
         -- sessiz geçip bazısında patlar. (Bkz. bu dosyanın altındaki not.)
         coalesce(a.lounge_name, a.airport_code::text),
         s.completed_at,
         (r.host_id = v_uid),
         a.airport_code::text, a.avail_date, a.time_from, a.time_to,
         a.flight_number, a.carrier
    from sessions s
    join requests r on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join profiles p
      on p.user_id = case when r.host_id = v_uid then r.guest_id else r.host_id end
   where s.status = 'completed'
     and (r.host_id = v_uid or r.guest_id = v_uid)
     and not exists (
       select 1 from ratings rt
        where rt.session_id = s.id and rt.rater_id = v_uid)
     and coalesce(s.completed_at, now()) > now() - interval '30 days'
   order by s.completed_at desc nulls last;
end $$;
grant execute on function public.pending_ratings() to authenticated;

-- ---- MİSAFİR İSTEK KARTLARI ----
-- Ana sayfada misafirin gönderdiği istekler; host tarafındaki kadar
-- bilgi taşımalı ki kullanıcı "hangi ilandı bu?" diye sormasın.
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
  select r.id, r.status::text, r.created_at, r.responded_at,
         r.host_id, coalesce(p.name, 'Host'), ts.badge,
         a.id, a.airport_code::text, a.lounge_name, a.avail_date,
         a.time_from, a.time_to, a.flight_number, a.carrier,
         -- 🔴 smallint → int CAST'I DA ŞART. `availabilities.slots` ve
         -- `filled` SMALLINT; burada `int` diye ilan ediliyor.
         -- PostgreSQL RETURNS TABLE'da TAM TİP EŞİTLİĞİ ister — sayısal
         -- genişletme bile yapmaz (ölçtüm: ilan=integer/kolon=smallint → 42804).
         a.slots::int, a.filled::int,
         coalesce(public.lounge_access_decision(a.id, a.flight_number) ->> 'guest_policy', 'unknown'),
         nullif(public.lounge_access_decision(a.id, a.flight_number) ->> 'headline', '')
    from requests r
    join availabilities a on a.id = r.avail_id
    left join profiles p on p.user_id = r.host_id
    left join trust_scores ts on ts.user_id = r.host_id
   where r.guest_id = v_uid
     and r.status in ('pending', 'accepted')
   order by coalesce(r.status = 'accepted', false) desc, a.avail_date, a.time_from;
end $$;
grant execute on function public.my_sent_requests() to authenticated;

-- ============================================================
-- 🔴 18 AĞUSTOS DÜZELTMESİ — CANLIDA PATLADI, HARNESS'TA PATLAMADI
-- ============================================================
-- Gökberk bu dosyayı canlı Supabase'de çalıştırdı ve şunu aldı:
--
--   ERROR: 42804 structure of query does not match function result type
--   DETAIL: Returned type character(3) does not match expected type text
--           in column 9.
--   CONTEXT: PL/pgSQL function my_sent_requests() line 4 at RETURN QUERY
--            SQL statement "select count(*) from public.my_sent_requests()"
--
-- Yani dosyanın KENDİ nöbetçisi patlattı. Sebep: `availabilities.airport_code`
-- CHAR(3), fonksiyon onu `text` diye ilan ediyor, cast yok.
--
-- ⚠️ PEKİ BENİM HARNESS'IM NEDEN YAKALAMADI — ÖLÇTÜM:
-- PostgreSQL bu uyuşmazlığı yalnız BİR SATIR DÖNDÜĞÜNDE kontrol eder.
-- Sıfır satırda hiç coercion yapmaz, hata da vermez. Harness'ta 186
-- çalışırken `requests` tablosunda `pending`/`accepted` durumunda
-- HİÇBİR SATIR YOK (senaryo verisi en sonda geliyor):
--     select count(*) from requests where status in ('pending','accepted') → 0
-- Gökberk'in veritabanında ise gerçek bir istek vardı ve anında patladı.
--
-- Üstelik iki dosya sonra `187` aynı fonksiyonu `a.airport_code::text`
-- ile YENİDEN tanımlıyor — yani hata benim harness'ımda hem görünmez
-- hem de kendiliğinden "düzelmiş" oluyordu. İki ayrı körlük üst üste.
--
-- 🔴 HATA SINIFI 24 — "TİP UYUŞMAZLIĞI VERİ OLMADAN GÖRÜNMEZ."
-- `returns table` sözleşmesi, boş sonuçta DOĞRULANMAZ. Bir migration'ın
-- "temiz çalıştı" demesi, döndürdüğü satırın tipinin doğru olduğunu
-- göstermez. Bunu artık `tip_check.py` statik olarak denetliyor: her
-- `returns table` sütununun ilan edilen tipi ile kaynak kolonun gerçek
-- tipi karşılaştırılıyor — veriye ihtiyaç duymadan.
-- ============================================================

-- ---- KANIT ----
do $$
declare v_uid uuid; n int; v_ctx int := 0; r record;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '186: seed misafiri yok'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  select count(*) into n from public.my_sent_requests();
  for r in select * from public.my_sent_requests() loop
    if r.airport_code is not null and r.avail_date is not null then
      v_ctx := v_ctx + 1;
    end if;
  end loop;
  raise notice '186: gönderilen istek % (bağlamlı %)', n, v_ctx;

  if n > 0 and v_ctx = 0 then
    raise exception '186: istek kartlarında bağlam yok';
  end if;

  perform (select count(*) from public.pending_ratings());
  perform set_config('request.jwt.claims', '{}', true);
  raise notice '186: pending_ratings bağlam alanlarıyla çalışıyor ✓';
end $$;

select '186 OK - kartlar baglam tasiyor' as sonuc;
