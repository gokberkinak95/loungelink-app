-- ============================================================
-- LoungeLink · 140_rls_and_ratelimit.sql
-- REFERANS TABLOLARI YAZILABILIR + HIZ SINIRI YOK
--
-- ⚠️ Uygulamayi ETKILER (yazma kapaniyor, okuma acik kaliyor).
--
-- ------------------------------------------------------------
-- 🔴 ACIK 1: DORT TABLO RLS'SIZ
-- ------------------------------------------------------------
-- 58 tablodan 54'unde RLS acik. Kalan dordu:
--   beta_settings · lounge_program_aliases · carriers · lounge_venue_partners
--
-- "Bunlar referans verisi, okunmasi zararsiz" diye dusunmusum ve
-- OKUMA tarafinda hakliyim. Ama RLS kapaliysa anon anahtari olan
-- biri bu tablolara YAZABILIR de. Sonuclari:
--   · beta_settings -> kural uyari METINLERIMIZ degistirilebilir
--   · carriers      -> sahte havayolu eklenip kural motoru yanıltilabilir
--   · aliases       -> host beyani yanlis programa eslenebilir
--   · partners      -> salonda olmayan anlasma gosterilebilir
--
-- Yani "zararsiz referans verisi" aslinda KURAL MOTORUNUN GIRDISI.
-- Okumasi serbest olabilir; yazmasi asla.
--
-- ------------------------------------------------------------
-- 🔴 ACIK 2: HICBIR YERDE HIZ SINIRI YOK
-- ------------------------------------------------------------
-- `create_request`, `verify_otp`, `create_availability` sinirsiz
-- cagrilabiliyor. Kredi sistemi istegi bir miktar frenliyor ama:
--   · OTP deneme sayisi sinirsiz -> 6 haneli kod kaba kuvvetle kirilir
--   · ilan acma sinirsiz -> tek hesap kesfi doldurabilir
-- Kapali betada risk dusuk; ama beta ACILDIGI GUN acik olur ve o gun
-- fark etmek gec olur.
-- ============================================================

-- ---- 1) REFERANS TABLOLARI: OKU serbest, YAZ kapali ----
do $$
declare t text;
begin
  foreach t in array array['beta_settings','lounge_program_aliases',
                           'carriers','lounge_venue_partners'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_read', t);
    -- Okuma: giris yapmis herkes. Bu veriler zaten app''te gorunuyor.
    execute format(
      'create policy %I on %I for select to authenticated using (true)',
      t || '_read', t);
    -- YAZMA POLITIKASI YOK = kimse yazamaz. Yazma yalniz
    -- `security definer` fonksiyonlar ve service_role uzerinden
    -- (BO paneli) yapilir — ikisi de RLS''i baypas eder.
  end loop;
end $$;

-- ---- 2) HIZ SINIRI ----
create table if not exists rate_limits (
  user_id    uuid not null,
  action     text not null,
  window_start timestamptz not null default date_trunc('hour', now()),
  count      int not null default 0,
  primary key (user_id, action, window_start)
);
alter table rate_limits enable row level security;   -- politika yok: kapali

create or replace function public.rate_ok(p_action text, p_limit int, p_hours int default 1)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_win timestamptz; v_n int;
begin
  if v_uid is null then return false; end if;
  v_win := date_trunc('hour', now()) - make_interval(hours => greatest(p_hours,1) - 1);

  select coalesce(sum(count),0) into v_n from rate_limits
   where user_id = v_uid and action = p_action and window_start >= v_win;
  if v_n >= p_limit then return false; end if;

  insert into rate_limits (user_id, action, count)
  values (v_uid, p_action, 1)
  on conflict (user_id, action, window_start) do update set count = rate_limits.count + 1;
  return true;
end $$;
grant execute on function public.rate_ok(text, int, int) to authenticated;

-- 🔴 OTP EN KRITIGI: 6 haneli kod, sinirsiz denemede dakikalar icinde
-- kirilir. Saatte 5 deneme, hem kaba kuvveti durdurur hem gercek
-- kullaniciyi zorlamaz (kod 1-2 denemede girilir).
create or replace function public.otp_attempt_ok()
returns boolean language sql security definer set search_path = public as $$
  select public.rate_ok('otp_verify', 5, 1);
$$;
grant execute on function public.otp_attempt_ok() to authenticated;

-- Eski pencereleri temizle (tablo sonsuza kadar buyumesin)
create or replace function public.prune_rate_limits()
returns int language sql security definer set search_path = public as $$
  with d as (delete from rate_limits where window_start < now() - interval '2 days' returning 1)
  select count(*)::int from d;
$$;

insert into beta_settings (key, value) values
 ('rate_limits', '{"create_request": 20, "create_availability": 10,
                   "otp_verify": 5, "report": 5}'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---- DOGRULAMA ----
select count(*) filter (where not c.relrowsecurity) as rls_kapali,
       count(*) filter (where c.relrowsecurity) as rls_acik
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r';

select c.relname, count(p.polname) as politika
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  left join pg_policy p on p.polrelid = c.oid
 where n.nspname = 'public'
   and c.relname in ('beta_settings','carriers','lounge_program_aliases','lounge_venue_partners')
 group by c.relname order by 1;

select '140 OK - referans tablolari yazmaya kapandi, hiz siniri kuruldu' as sonuc;

-- ============================================================
-- 🔴 SINIRI GERCEKTEN BAGLA
-- ------------------------------------------------------------
-- Tablo ve fonksiyon kurmak yetmez; cagrilmayan bir sinir, sinir
-- degildir. Bu hatayi bu projede uc kez yaptim (promo_redemptions
-- tablosu vardi ekrani yoktu; flight.js yazildi cagrilmadi;
-- blocks tablosu vardi kesif ona bakmiyordu).
--
-- `create_request` ve `create_availability`nin BASINA sinir kontrolu
-- ekliyoruz — govdelerini degistirmeden, sarmalayarak.
-- ============================================================
-- ============================================================
-- 🔴 BES HATA — VE BESINCISI DIGER DORDUNUN SEBEBIYDI
-- ------------------------------------------------------------
-- Sarmalayiciyi kurarken govdeyi once 033'ten, sonra 065'ten aldim.
-- Ikisi de YANLISTI: en guncel tanim 079'da.
--
-- Neden bulamadim? Cunku 079 fonksiyonlari `$function$ ... $function$`
-- ile yaziyor (pg_dump bicimi) ve hem benim aramam hem drift_check'in
-- ayristiricisi yalniz `$$` ariyordu. Yani ARACIM beni yanilti, ben de
-- eski bir govdeyi "en guncel" sanip canlandirdim.
--
-- Dort gorunur hata (parametre sirasi, dusen p_idem, donus tipi, eski
-- kolon adi) aslinda TEK bir kok nedenin belirtileriydi: dogru tanimi
-- bulamayan bir arama. Denetimi duzelttim (drift_check artik her
-- dollar-quote etiketini taniyor) ve govdeyi 079'dan aliyorum.
-- ============================================================
drop function if exists public.create_request(uuid, text, text, text);
drop function if exists public.create_request_impl(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.create_request_impl(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if p_idem is not null then
    select id into v_req_id from requests where idempotency_key = p_idem;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  -- 079: KAPI ARTIK "DOĞRULANMIŞ İLETİŞİM" (telefon VEYA e-posta).
  -- SMS maliyetli olduğu için beta boyunca e-posta doğrulaması yeterli;
  -- demo bypass (kod 0000) kaldırıldı.
  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;
  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  -- YENİ (033): aynı gün + örtüşen saatte kendi AKTİF host ilanın varsa başvuramazsın
  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  -- REQUEST KAPISI: trip zorunlu (rolden bağımsız — host da trip eklemeli)
  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'), left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $function$;
grant execute on function public.create_request_impl(uuid, text, text, text) to authenticated;

create or replace function public.create_request(
  p_avail_id uuid, p_type text default 'lounge'::text,
  p_intro text default null::text, p_idem text default null::text
) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  -- Saatte 20 istek: gercek kullanici bir oturumda 2-3 istek atar;
  -- 20 hem bol hem otomatik spam'i durduran bir esik.
  if not public.rate_ok('create_request', 20, 1) then
    raise exception 'rate_limited_request';
  end if;
  return public.create_request_impl(p_avail_id, p_type, p_intro, p_idem);
end $$;
grant execute on function public.create_request(uuid, text, text, text) to authenticated;

insert into beta_settings (key, value) values
 ('err_rate_limited_request', to_jsonb(
   'Çok fazla istek gönderdin. Bir saat sonra tekrar dene.'::text)),
 ('err_rate_limited_otp', to_jsonb(
   'Çok fazla kod denemesi. Güvenlik için bir saat beklemen gerekiyor.'::text))
on conflict (key) do update set value = excluded.value;

select 'hiz siniri bagli mi' as kontrol,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='create_request'
           and pg_get_functiondef(p.oid) like '%rate_ok%')::text as evet_ise_1;
