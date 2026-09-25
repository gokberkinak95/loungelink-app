-- ============================================================
-- 041 — EKİP/PARTNER HESAPLARI TÜKETİCİ YÜZEYİNDEN ÇIKSIN
--
-- SORUN (Gokberk sordu, haklıydı):
-- Backoffice'ten bir ekip üyesi davet ettiğinde ya da bir lounge
-- partnerine hesap açtığında, o hesap app'te normal kullanıcı gibi
-- "Tanış" listesinde görünüyor.
--
-- NEDEN:
-- BO daveti auth.admin.createUser() ile GERÇEK bir auth.users satırı
-- açıyor (başka türlü giriş yapamazlar). handle_new_user trigger'ı ise
-- HER auth.users satırına profil + verifications + trust_scores +
-- açılış kredisi veriyor. Trigger, hesabın bir ekip hesabı mı yoksa
-- gerçek bir yolcu mu olduğunu ayırt etmiyor.
--
-- İYİ HABER: BO zaten doğru metadata'yı gönderiyormuş —
--   team/actions.js    -> user_metadata: { ..., is_staff: true }
--   partners/actions.js-> user_metadata: { ..., is_partner: true }
-- Yani veri hep oradaydı, trigger bakmıyordu. Eklemek yeterli.
--
-- NE YAPIYORUZ:
--   1. users.is_staff kolonu (kalıcı işaret — metadata sonradan silinse
--      bile kaybolmaz, ve RLS/sorgular tek yerden okur)
--   2. handle_new_user metadata'daki is_staff/is_partner'ı okur ve
--      işaretler; ekip hesabına açılış kredisi VERMEZ ve
--      show_on_discovery=false yapar
--   3. Tüketici keşif fonksiyonları staff'ı hariç tutar:
--      discover_people · discover_availabilities · lounge_radar_people
--   4. Zaten açılmış ekip/partner hesapları geriye dönük işaretlenir
--
-- NOT: Ekip üyesi ürünü kendi telefonundan denemek isterse AYRI bir
-- e-posta ile normal kayıt olur. Bu doğrusu: test hesabı ile yönetim
-- hesabı ayrı olmalı.
-- ============================================================

-- ---- 1. Kalıcı işaret ----
alter table users add column if not exists is_staff boolean not null default false;

comment on column users.is_staff is
  'true = BO ekip üyesi veya lounge partneri. Tüketici keşif yüzeylerinden hariç tutulur (041).';

create index if not exists idx_users_is_staff on users(is_staff) where is_staff = true;


-- ---- 2. handle_new_user — 033''ün gövdesi BİREBİR korunuyor ----
-- DEĞİŞEN: v_staff okunuyor, users.is_staff yazılıyor, staff ise
-- show_on_discovery=false ve açılış kredisi atlanıyor.
-- 033''ün her kuralı duruyor: password_hash='supabase-auth' (NOT NULL),
-- role::user_role cast''i, gender, ve kredi çağrısının
-- begin/exception/null sargısı (trigger ASLA patlamamalı).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare g user_gender; n text; r user_role; v_staff boolean;
begin
  begin g := (new.raw_user_meta_data->>'gender')::user_gender; exception when others then g := null; end;
  begin r := coalesce((new.raw_user_meta_data->>'role')::user_role, 'guest'); exception when others then r := 'guest'; end;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  -- YENİ (041): BO daveti bu bayrakları zaten gönderiyor
  begin
    v_staff := coalesce((new.raw_user_meta_data->>'is_staff')::boolean, false)
            or coalesce((new.raw_user_meta_data->>'is_partner')::boolean, false);
  exception when others then v_staff := false;
  end;

  insert into public.users (id, email, role, gender, password_hash, is_staff)
  values (new.id, new.email, r, g, 'supabase-auth', v_staff) on conflict (id) do nothing;

  -- staff ise keşifte görünme
  insert into public.profiles (user_id, name, show_on_discovery)
  values (new.id, n, not v_staff) on conflict (user_id) do nothing;

  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now()) on conflict (user_id) do nothing;
  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New') on conflict (user_id) do nothing;

  -- BETA (033): açılış kredisi — ama ekip hesabına DEĞİL.
  -- Kendi hatasını yutar: kredi verilemezse KAYIT YİNE DE TAMAMLANIR.
  if not v_staff then
    begin
      perform grant_signup_credits(new.id);
    exception when others then
      null;
    end;
  end if;

  return new;
end $$;


-- ---- 3. Geriye dönük: zaten açılmış ekip/partner hesapları ----
-- (a) admin_roles'ta olan herkes
update users u set is_staff = true
where exists (select 1 from admin_roles ar where ar.user_id = u.id)
  and u.is_staff = false;

-- (b) lounge_partners'ta olan herkes
update users u set is_staff = true
where exists (select 1 from lounge_partners lp where lp.user_id = u.id)
  and u.is_staff = false;

-- (c) metadata'sında bayrak olan ama tabloya yansımamış olanlar
update users u set is_staff = true
from auth.users au
where au.id = u.id
  and u.is_staff = false
  and (coalesce((au.raw_user_meta_data->>'is_staff')::text, 'false') = 'true'
    or coalesce((au.raw_user_meta_data->>'is_partner')::text, 'false') = 'true');

-- (d) işaretlenmiş hesapları keşiften çıkar
update profiles p set show_on_discovery = false
from users u
where u.id = p.user_id and u.is_staff = true and p.show_on_discovery = true;


-- ============================================================
-- 4. KEŞİF FONKSİYONLARI — staff hariç
--
-- show_on_discovery=false zaten çoğunu kapatıyor ama o kullanıcının
-- kendi değiştirebileceği bir ayar. is_staff sunucu tarafı gerçeği;
-- sorgularda AYRICA kontrol ediyoruz ki bir ekip üyesi ayarı açsa
-- bile tüketici listesine düşmesin.
-- ============================================================

-- ---- discover_availabilities: 040'ın gövdesi BİREBİR + staff filtresi ----
-- (040'ta eklenen görünürlük filtresi ve p.linkedin_url düzeltmesi korunuyor)
create or replace function public.discover_availabilities(
  p_airport text default null, p_sector text default null, p_flight text default null,
  p_date date default null
)
returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int, host_name text, host_badge text, host_score int,
  host_profession text, host_photo text, match_score int,
  same_flight boolean, has_trip boolean, is_featured boolean, fully_booked boolean,
  visibility text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_female boolean; v_safe boolean;
  v_langs text[]; v_prof text; v_sessions int; v_rated int; v_my_trust int;
begin
  select (u.gender='female'), coalesce(pr.women_safety_mode,false), pr.languages, pr.profession
    into v_female, v_safe, v_langs, v_prof
    from users u left join profiles pr on pr.user_id=u.id where u.id=v_uid;

  select count(*) into v_sessions from sessions s
    join requests r on r.id = s.request_id
   where s.status='completed' and (r.guest_id=v_uid or r.host_id=v_uid);
  select count(*) into v_rated from ratings where rater_id = v_uid;
  select coalesce(score,0) into v_my_trust from trust_scores where user_id = v_uid;
  v_my_trust := coalesce(v_my_trust, 0);

  return query
  with base as (
    select a.*, p.name as hn, ts.badge as hb, coalesce(ts.score,0) as hs, p.profession as hp,
      p.languages as hlangs, hu.gender as hgender,
      case when p.photo_url is not null and (
             coalesce(p.photo_connections_only,false) = false
             or exists (select 1 from connection_requests cr where cr.status='accepted'
                        and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
           ) then p.photo_url else null end as photo,
      coalesce(v.id_verified,false) as hid,
      (p.linkedin_url is not null and p.linkedin_url <> '') as hlinked,   -- 040 düzeltmesi
      (select count(*) from sessions s2 join requests r2 on r2.id=s2.request_id
        where s2.status='completed' and r2.host_id=a.host_id) as hsessions,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.airport_code=a.airport_code
              and vs.visit_date=a.avail_date and vs.time_from < a.time_to and a.time_from < vs.time_to) as has_trip,
      exists (select 1 from visits vs where vs.user_id=v_uid and vs.flight_number is not null
              and a.flight_number is not null and upper(vs.flight_number)=upper(a.flight_number)) as same_flight,
      (a.featured_until is not null and a.featured_until > now()) as featured
    from availabilities a
    join users hu on hu.id=a.host_id
    join profiles p on p.user_id=a.host_id
    left join trust_scores ts on ts.user_id=a.host_id
    left join verifications v on v.user_id=a.host_id
    where a.active=true
      and hu.role = 'host'
      and coalesce(hu.is_staff,false) = false                -- YENİ (041)
      and a.avail_date >= current_date
      and coalesce(p.show_on_discovery,true)=true
      and public.is_visible(a.host_id)
      and (p_airport is null or a.airport_code=p_airport)
      and (p_date is null or a.avail_date = p_date)
      and (p_flight is null or upper(a.flight_number)=upper(p_flight))
      and (p_sector is null or p.profession ilike '%'||p_sector||'%')
      and (not coalesce(p.women_safety_mode,false)
           or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))
      -- 040: görünürlük — host ne seçtiyse o geçerli
      and (
        a.host_id = v_uid
        or (
          coalesce(a.visibility,'Public') <> 'Hidden'
          and (
            coalesce(a.visibility,'Public') <> 'Connections'
            or exists (select 1 from connection_requests cr where cr.status='accepted'
                       and ((cr.from_id=v_uid and cr.to_id=a.host_id) or (cr.from_id=a.host_id and cr.to_id=v_uid)))
          )
          and v_my_trust >= coalesce(a.min_trust,0)
        )
      )
  )
  -- 🔴 CAST'LER SART (18 Agu 2026, hata sinifi 24).
  -- `availabilities.airport_code` CHAR(3), `slots`/`filled` SMALLINT;
  -- ust tarafta `returns table (... airport_code text, slots int,
  -- filled int ...)` yaziyor. PostgreSQL `returns table` sozlesmesinde
  -- GENISLETME YAPMAZ (olculdu: integer<-smallint bile 42804 verir) ve
  -- bu hata SATIR YOKKEN CIKMAZ — bos veritabaninda migration temiz
  -- gorunur, veri varken ILK SATIRDA patlar. Gokberk canlida bunu
  -- 186'da iki kez yasadi; ayni kusur bu dosyada da duruyordu.
  select b.id, b.host_id, b.airport_code::text, b.lounge_name, b.avail_date, b.time_from, b.time_to,
         b.flight_number, b.slots::int, b.filled::int, b.hn, b.hb, b.hs, b.hp, b.photo,
         least(99,
           40
           + (case when b.hs >= 70 then 18 when b.hs >= 55 then 10 else 0 end)
           + (case when b.hid then 14 else 0 end)
           + (case when b.same_flight then 14 else 0 end)
           + (case when v_prof is not null and b.hp is not null
                    and (b.hp ilike '%'||v_prof||'%' or v_prof ilike '%'||b.hp||'%') then 12 else 0 end)
           + (case when v_female and b.hgender = 'female' then 10 else 0 end)
           + (case when b.hsessions >= 3 then 8 else 0 end)
           + (case when b.hlinked then 6 else 0 end)
           + (case when v_langs is not null and b.hlangs is not null and (v_langs && b.hlangs) then 5 else 0 end)
           + (case when v_rated > 0 then 4 else 0 end)
           + (case when b.has_trip then 10 else 0 end)
         )::int as match_score,
         b.same_flight, b.has_trip, b.featured, (b.filled >= b.slots) as fully_booked,
         coalesce(b.visibility,'Public')::text as visibility
  from base b
  order by b.featured desc, match_score desc, b.avail_date, b.time_from
  limit 100;
end $$;


-- ---- discover_people + lounge_radar_people: staff filtresi ----
-- Bu ikisinin gövdesini burada yeniden yazmıyoruz (029/034'te tanımlı ve
-- uzunlar). Bunun yerine is_visible() fonksiyonunu güçlendiriyoruz:
-- ikisi de zaten onu çağırıyor, dolayısıyla tek noktadan kapanıyor.
--
-- is_visible (029) gölge kısıtı kontrol ediyordu; şimdi staff'ı da
-- kapsıyor. Gövdesi okunup korundu — yalnız is_staff koşulu eklendi.
-- 🔴 029'un gövdesi BİREBİR korunuyor. Claude bunu ilk yazışında okumadan
-- yeniden yazmış ve iki şeyi birden bozmuştu:
--   · `restricted_until` kontrolü DÜŞMÜŞTÜ — gölge kısıt SÜRELİDİR;
--     süresi dolan kullanıcı yeniden görünür olmalı. Onsuz kısıtlama
--     kalıcı hale gelir ve kimse fark etmez.
--   · `deleted_at is null` UYDURULMUŞTU — 029'da öyle bir koşul yok.
-- Bu dosyada EKLENEN tek şey: is_staff.
create or replace function public.is_visible(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not coalesce((select shadow_limited and (restricted_until is null or restricted_until > now())
                       from users where id = p_user), false)
     and not coalesce((select is_staff from users where id = p_user), false);   -- YENİ (041)
$$;


grant execute on function public.discover_availabilities(text,text,text,date) to authenticated;
grant execute on function public.is_visible(uuid) to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
-- 1) Kaç ekip/partner hesabı işaretlendi?
select 'isaretli ekip/partner hesabi' as kontrol, count(*)::text as sonuc
from users where is_staff = true
union all
-- 2) Hiçbiri keşifte görünmemeli
select 'kesifte gorunen staff (0 OLMALI)', count(*)::text
from users u join profiles p on p.user_id = u.id
where u.is_staff = true and coalesce(p.show_on_discovery,true) = true
union all
-- 3) Trigger is_staff okuyor mu?
select 'trigger is_staff okuyor',
  case when exists (
    select 1 from pg_proc where proname='handle_new_user'
      and prosrc like '%is_staff%'
  ) then 'EVET' else '🔴 HAYIR' end
union all
-- 4) is_visible staff'ı kapsıyor mu?
select 'is_visible staff kapsiyor',
  case when exists (
    select 1 from pg_proc where proname='is_visible' and prosrc like '%is_staff%'
  ) then 'EVET' else '🔴 HAYIR' end;
