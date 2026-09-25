-- =====================================================================
-- 033 · Beta kredi · Host'un başvurabilmesi · Trust bileşenleri · Lounge Radar
-- Bağımlılık: 032'den SONRA çalıştır.
-- Idempotent: tekrar çalıştırmak güvenli.
-- =====================================================================

-- ============================================================
-- 1) BETA KREDİ SİSTEMİ
-- Neden: gerçek ödeme (Play Billing) yok. Beta boyunca kredi
-- elle/otomatik verilecek. Tek kaynak credit_ledger — bakiye
-- her zaman satırlardan türetilir, hiçbir yerde ayrı tutulmaz.
-- Bu yüzden BO'da ne yazarsak app'te anında görünür.
-- ============================================================

-- Beta ayarları (BO'dan yönetilir)
create table if not exists beta_settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  text
);

insert into beta_settings (key, value) values
  ('signup_credits', '{"enabled": true, "amount": 5}'::jsonb),
  ('monthly_topup',  '{"enabled": false, "amount": 3}'::jsonb)
on conflict (key) do nothing;

-- Kayıt olan herkese otomatik beta kredisi
create or replace function public.grant_signup_credits(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_cfg jsonb; v_amt int; v_bal int;
begin
  select value into v_cfg from beta_settings where key = 'signup_credits';
  if not coalesce((v_cfg->>'enabled')::boolean, false) then return; end if;
  v_amt := coalesce((v_cfg->>'amount')::int, 0);
  if v_amt <= 0 then return; end if;

  -- zaten verilmişse tekrar verme
  if exists (select 1 from credit_ledger where user_id = p_user and reason = 'beta_signup') then
    return;
  end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = p_user;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (p_user, v_amt, 'beta_signup', v_bal + v_amt);

  insert into notifications (user_id, category, title, body)
  values (p_user, 'system', 'Hoş geldin ✦',
          v_amt || ' beta kredin hesabına tanımlandı. Her lounge isteği 1 kredi.');
end $$;

-- handle_new_user — 025'in ÇALIŞAN sürümü KORUNUR, üstüne beta kredisi eklenir.
--
-- 🔴 BURADA HATA YAPTIM (033'ün ilk sürümü): 025'i okumadan yeniden yazdım ve
-- üç şeyi birden bozdum. Sonuç: auth.users trigger'ı patladı → Supabase auth
-- API'si HTTP 500 döndü → HİÇ KİMSE KAYIT OLAMADI (ne app'ten ne BO davetinden).
--   1) password_hash NOT NULL — 025 'supabase-auth' yazıyordu, ben satırı düşürdüm
--   2) role: text değişkeni user_role ENUM kolonuna yazılamaz (025 ::user_role cast'liyor)
--   3) gender kayboluyordu — 025 raw_user_meta_data'dan okuyup yazıyor
-- Ayrıca 025 badge='New' ve email_verified_at yazıyordu; onlar da geri geldi.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare g user_gender; n text; r user_role;
begin
  begin g := (new.raw_user_meta_data->>'gender')::user_gender; exception when others then g := null; end;
  begin r := coalesce((new.raw_user_meta_data->>'role')::user_role, 'guest'); exception when others then r := 'guest'; end;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  insert into public.users (id, email, role, gender, password_hash)
  values (new.id, new.email, r, g, 'supabase-auth') on conflict (id) do nothing;
  insert into public.profiles (user_id, name) values (new.id, n) on conflict (user_id) do nothing;
  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now()) on conflict (user_id) do nothing;
  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New') on conflict (user_id) do nothing;

  -- BETA (033): açılış kredisi. 025'teki sabit "2 kredi / signup_grant" yerine
  -- beta_settings'ten okunan ayarlanabilir miktar. Kendi hatasını yutar —
  -- kredi verilemezse KAYIT YİNE DE TAMAMLANIR (trigger'ı asla patlatma).
  begin
    perform grant_signup_credits(new.id);
  exception when others then
    null;  -- kredi başarısız olsa da kullanıcı kaydı bozulmamalı
  end;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- BO: elle kredi ver/al (mevcut admin_adjust_credits'i beta için genişletir)
create or replace function public.admin_credit_adjust(
  p_user uuid, p_delta int, p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_bal int;
begin
  if p_delta = 0 then raise exception 'delta_zero'; end if;
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = p_user;
  if v_bal + p_delta < 0 then raise exception 'would_go_negative'; end if;

  insert into credit_ledger (user_id, delta, reason, balance_after, note)
  values (p_user, p_delta, 'admin_adjust', v_bal + p_delta, p_note);

  insert into notifications (user_id, category, title, body)
  values (p_user, 'system',
          case when p_delta > 0 then 'Kredi tanımlandı ✦' else 'Kredi düzeltmesi' end,
          case when p_delta > 0 then '+' || p_delta || ' kredi hesabına eklendi.'
               else p_delta || ' kredi düzeltmesi yapıldı.' end ||
          coalesce(' · ' || p_note, ''));

  return jsonb_build_object('ok', true, 'balance', v_bal + p_delta);
end $$;
grant execute on function public.admin_credit_adjust(uuid, int, text) to authenticated;

-- BO: toplu kredi (beta kullanıcılarının hepsine)
create or replace function public.admin_bulk_credit(
  p_delta int, p_note text default null, p_role text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_count int := 0; v_u record; v_bal int;
begin
  if p_delta <= 0 then raise exception 'delta_must_be_positive'; end if;
  for v_u in
    select id from users
     where deleted_at is null
       and (p_role is null or role = p_role)
  loop
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_u.id;
    insert into credit_ledger (user_id, delta, reason, balance_after, note)
    values (v_u.id, p_delta, 'admin_adjust', v_bal + p_delta, coalesce(p_note,'Toplu beta kredisi'));
    insert into notifications (user_id, category, title, body)
    values (v_u.id, 'system', 'Kredi tanımlandı ✦', '+' || p_delta || ' kredi hesabına eklendi.');
    v_count := v_count + 1;
  end loop;
  return jsonb_build_object('ok', true, 'affected', v_count);
end $$;
grant execute on function public.admin_bulk_credit(int, text, text) to authenticated;

-- note kolonu (yoksa)
alter table credit_ledger add column if not exists note text;


-- ============================================================
-- 2) HOST DA BAŞVURABİLİR (çift rol, bağlam bazlı)
--
-- KARAR: Doküman §4 "her iki rol kaldırıldı" diyor ama kodda
-- zaten engel yoktu. Bilinçli olarak AÇIK bırakıyoruz çünkü:
--  - Gerçek hayatta host her uçuşta hakkını kullanmıyor
--  - Arz sorununu hafifletir (aynı kişi iki yönde de ağda)
--  - Karşılıklılık host için en güçlü motivasyon
--
-- TEK YENİ KURAL: aynı gün + örtüşen saatte hem host ilanı
-- hem guest isteği OLAMAZ. Yoksa "kendi misafirini başkasına
-- yolluyor" absürtlüğü çıkar.
-- ============================================================

create or replace function public.create_request(
  p_avail_id uuid, p_type text default 'lounge', p_intro text default null,
  p_idem text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
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

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

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

  insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', p_type, left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $$;
grant execute on function public.create_request(uuid, text, text, text) to authenticated;

-- Aynı kural ters yönde: örtüşen saatte aktif isteğin varsa ilan AÇAMAZSIN
create or replace function public.create_availability(
  p_lounge_id uuid, p_airport text, p_date date, p_from time, p_to time, p_slots int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cap int; v_ok boolean; v_id uuid; v_conflict boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if p_slots > v_cap then raise exception 'slots_exceed_capacity'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;

  -- YENİ (033): örtüşen saatte bekleyen/kabul edilmiş guest isteğin varsa ilan açamazsın
  select exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = p_date
       and a.time_from < p_to and p_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'guest_same_slot'; end if;

  insert into availabilities (host_id, lounge_id, airport_code, avail_date, time_from, time_to, slots, filled, active)
  values (v_uid, p_lounge_id, p_airport, p_date, p_from, p_to, p_slots, 0, true)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
grant execute on function public.create_availability(uuid, text, date, time, time, int) to authenticated;

-- Host kademesi YALNIZCA host oturumlarından hesaplanır (rozet değersizleşmesin).
-- 032'nin sözleşmesi KORUNUR: returns text, aynı rozet metinleri, guest rozetleri dahil.
-- TEK DEĞİŞİKLİK: çift rol geldiği için (033) artık rol'e göre değil, HER İKİ sayım
-- ayrı yapılır — host rozeti yalnız host oturumlarından, guest rozeti guest'lerden.
create or replace function public.recompute_badge(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_host_sessions int; v_guest_sessions int; v_score int; v_badge text;
begin
  select role into v_role from users where id = p_user;
  select coalesce(score,0) into v_score from trust_scores where user_id = p_user;

  -- 033: iki sayım AYRI. Host olarak ağırladığın oturum host rozetini,
  -- guest olarak katıldığın oturum guest rozetini besler. Karışmaz.
  select count(*) into v_host_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status = 'completed' and r.host_id = p_user;

  select count(*) into v_guest_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status = 'completed' and r.guest_id = p_user;

  if v_role = 'host' then
    v_badge := case
      when v_host_sessions >= 20 then 'Elite Host'
      when v_host_sessions >= 5  then 'Trusted Host'
      when v_host_sessions >= 1  then 'Verified Host'
      else 'Basic Verified' end;
  else
    v_badge := case
      when v_score >= 70 then 'High Trust Guest'
      when v_guest_sessions >= 1 then 'Verified Guest'
      else 'Basic Verified' end;
  end if;

  update trust_scores set badge = v_badge, updated_at = now() where user_id = p_user;
  return v_badge;
end $$;
grant execute on function public.recompute_badge(uuid) to authenticated;


-- ============================================================
-- 3) TRUST SCORE — meslek & bio bileşenleri (TG §16)
-- Doküman: e-posta/telefon/ID/LinkedIn/meslek/bio/host erişimi
-- ============================================================

create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
begin
  select * into v_p from profiles where user_id = p_user;
  select * into v_v from verifications where user_id = p_user;

  -- e-posta (kayıtla birlikte)
  v_c := v_c || '{"email":10}'::jsonb;

  if coalesce(v_v.phone_verified,false) then v_c := v_c || '{"phone":10}'::jsonb; end if;
  if coalesce(v_v.id_verified,false)    then v_c := v_c || '{"id":18}'::jsonb; end if;

  -- GERCEK SEMA: kolon adi linkedin_url (linkedin degil)
  -- linkedin_verified true ise tam puan, sadece URL girilmisse yarim
  if coalesce(v_p.linkedin_verified, false) then
    v_c := v_c || '{"linkedin":8}'::jsonb;
  elsif coalesce(nullif(trim(v_p.linkedin_url),''), '') <> '' then
    v_c := v_c || '{"linkedin":4}'::jsonb;
  end if;

  -- YENİ (033): meslek beyanı
  if coalesce(nullif(trim(v_p.profession),''), '') <> '' then
    v_c := v_c || '{"profession":6}'::jsonb;
  end if;

  -- YENİ (033): anlamlı bio (en az 40 karakter — tek kelime sayılmaz)
  if length(coalesce(trim(v_p.bio),'')) >= 40 then
    v_c := v_c || '{"bio":6}'::jsonb;
  end if;

  -- host erişim kaynağı beyanı
  if v_p.guest_capacity is not null then
    v_c := v_c || '{"host_access":8}'::jsonb;
  end if;

  select coalesce(sum(value::int),0) into v_score
    from jsonb_each_text(v_c);

  v_score := least(100, greatest(0, v_score));

  insert into trust_scores (user_id, score, components, updated_at)
  values (p_user, v_score, v_c, now())
  on conflict (user_id) do update
    set score = excluded.score, components = excluded.components, updated_at = now();

  return v_score;
end $$;
grant execute on function public.recompute_trust(uuid) to authenticated;

-- Profil güncellenince trust yeniden hesapla
create or replace function public.trg_profile_trust()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform recompute_trust(new.user_id);
  return new;
end $$;

drop trigger if exists on_profile_trust on profiles;
create trigger on_profile_trust
  after insert or update of profession, bio, linkedin_url, linkedin_verified, guest_capacity on profiles
  for each row execute function trg_profile_trust();

create or replace function public.trg_profile_trust_v()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform recompute_trust(new.user_id);
  return new;
end $$;

drop trigger if exists on_verif_trust on verifications;
create trigger on_verif_trust
  after insert or update of phone_verified, id_verified on verifications
  for each row execute function trg_profile_trust_v();

select 'BETA CREDITS + DUAL ROLE + TRUST OK' as sonuc;
