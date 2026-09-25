-- ============================================================================
-- LoungeLink · 247_haber_ver.sql                          (23 Ağustos 2026)
--
-- BOŞ EKRANI BİR SÖZLEŞMEYE ÇEVİRMEK
--
-- ════════════════════════════════════════════════════════════════════════
-- NEDEN BU, ÜRÜNÜN EN YÜKSEK GETİRİLİ TEK İŞİ
-- ════════════════════════════════════════════════════════════════════════
-- Misafir uygulamayı açar, havalimanında ilan yoktur, kapatır ve BİR DAHA
-- AÇMAZ. Erken dönem pazaryerlerinin çoğu bu tek ekranda ölür.
--
-- Bugün o ekran hiçbir şey yapmıyor: boş liste gösteriyor. Oysa o anda
-- kullanıcı ürüne en yakın olduğu noktada — bir ihtiyacı var ve onu
-- yazmaya hazır.
--
-- "Haber ver" akışı iki şeyi aynı anda çözüyor:
--   1. MİSAFİR TARAFI: boş ekran, bir söze dönüşüyor. Kullanıcı gitmiyor.
--   2. HOST TARAFI: "12 Eylül'de IST'te 14 kişi bekliyor" diyebiliyoruz.
--      Yani arz tarafına gösterecek bir TALEP KANITI oluşuyor.
--
-- 🆕 SINIF: **"BİR PAZARYERİNDE KARŞILANMAMIŞ TALEP, KAYIP DEĞİL
-- ENVANTERDİR — YETER Kİ KAYDEDİLSİN."**
--
-- ⚠️ DÜZELTME: geçen turda "waitlist tablosu var ama bu akış yok"
-- demiştim. Baktım: `waitlist` lansman öncesi E-POSTA listesi
-- (email/role/consent/invited_at) — bu işle hiç ilgisi yok. Yeni tablo
-- gerekiyordu. Varsayıp yazmışım; düzeltiyorum.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) TALEP KAYDI
-- ----------------------------------------------------------------------------
create table if not exists talep_kayitlari (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  airport_code  char(3) not null,
  tarih_bas     date not null,
  tarih_bit     date not null,
  created_at    timestamptz not null default now(),
  son_bildirim_at timestamptz,
  aktif         boolean not null default true,
  constraint talep_tarih_chk check (tarih_bit >= tarih_bas),
  -- Bir talep en fazla 60 gün geleceğe bakabilir. Sınırsız aralık,
  -- "her ilan bu kişiyi ilgilendirir" demektir — yani bildirim çöpü.
  constraint talep_aralik_chk check (tarih_bit - tarih_bas <= 60)
);

create index if not exists talep_kayit_arama
  on talep_kayitlari (airport_code, tarih_bas, tarih_bit) where aktif;
create index if not exists talep_kayit_kullanici
  on talep_kayitlari (user_id) where aktif;

-- Aynı kişi aynı havalimanı+aralık için iki kayıt bırakamaz.
create unique index if not exists talep_kayit_tekil
  on talep_kayitlari (user_id, airport_code, tarih_bas, tarih_bit) where aktif;

alter table talep_kayitlari enable row level security;
revoke all on public.talep_kayitlari from anon, authenticated;
grant select on public.talep_kayitlari to authenticated;
drop policy if exists talep_kendi on public.talep_kayitlari;
create policy talep_kendi on public.talep_kayitlari
  for select using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2) İSTEMCİ YÜZEYİ
-- ----------------------------------------------------------------------------
insert into beta_settings (key, value) values
  ('talep_kayit_tavani', to_jsonb(5)),
  ('talep_bildirim_ara_saat', to_jsonb(12))
on conflict (key) do nothing;

create or replace function public.talep_birak(
  p_airport text, p_bas date, p_bit date default null)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare
  v_uid uuid := auth.uid();
  v_ap  text := upper(btrim(p_airport));
  v_bit date := coalesce(p_bit, p_bas);
  v_tavan int := coalesce((select (value #>> '{}')::int from beta_settings
                            where key='talep_kayit_tavani'), 5);
  v_n int; v_id uuid; v_bekleyen int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_bas is null then raise exception 'tarih_zorunlu'; end if;
  if p_bas < current_date then raise exception 'date_in_past'; end if;
  if v_bit < p_bas then raise exception 'invalid_time_range'; end if;
  if v_bit - p_bas > 60 then
    raise exception 'talep_araligi_uzun'
      using hint = 'En fazla 60 gunluk bir aralik birakabilirsin.';
  end if;
  if not exists (select 1 from airports where code = v_ap) then
    raise exception 'unknown_airport';
  end if;

  select count(*) into v_n from talep_kayitlari where user_id = v_uid and aktif;
  if v_n >= v_tavan then
    raise exception 'talep_kayit_tavani'
      using detail = format('%s/%s kayit', v_n, v_tavan),
            hint   = 'Once eski kayitlarindan birini kaldir.';
  end if;

  insert into talep_kayitlari (user_id, airport_code, tarih_bas, tarih_bit)
  values (v_uid, v_ap::char(3), p_bas, v_bit)
  on conflict (user_id, airport_code, tarih_bas, tarih_bit) where aktif
  do update set aktif = true
  returning id into v_id;

  -- 🔴 KULLANICIYA YALNIZ "kaydettim" DEMEK YETMEZ. O anda merak ettiği
  -- şey "ben kaçıncı kişiyim, umut var mı". Aynı aralıkta kaç kişinin
  -- beklediğini geri döndürüyoruz — bu hem dürüst hem motive edici.
  select count(*) into v_bekleyen from talep_kayitlari t
   where t.aktif and t.airport_code = v_ap::char(3)
     and t.tarih_bas <= v_bit and t.tarih_bit >= p_bas;

  return jsonb_build_object('ok', true, 'id', v_id,
                            'bekleyen_kisi', v_bekleyen,
                            'havalimani', v_ap, 'bas', p_bas, 'bit', v_bit);
end $f$;
grant execute on function public.talep_birak(text, date, date) to authenticated;

create or replace function public.taleplerim()
returns table(id uuid, airport_code text, tarih_bas date, tarih_bit date,
              bekleyen_kisi int, eslesen_ilan int, created_at timestamptz)
language sql stable security definer set search_path = public as $f$
  select t.id, t.airport_code::text, t.tarih_bas, t.tarih_bit,
         (select count(*)::int from talep_kayitlari o
           where o.aktif and o.airport_code = t.airport_code
             and o.tarih_bas <= t.tarih_bit and o.tarih_bit >= t.tarih_bas),
         (select count(*)::int from availabilities a
           where a.active and a.airport_code = t.airport_code
             and a.avail_date between t.tarih_bas and t.tarih_bit),
         t.created_at
    from talep_kayitlari t
   where t.user_id = auth.uid() and t.aktif
   order by t.tarih_bas;
$f$;
grant execute on function public.taleplerim() to authenticated;

create or replace function public.talebi_kaldir(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare v_n int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update talep_kayitlari set aktif = false
   where id = p_id and user_id = auth.uid() and aktif;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'talep_bulunamadi'; end if;
  return jsonb_build_object('ok', true);
end $f$;
grant execute on function public.talebi_kaldir(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 3) İLAN AÇILINCA BEKLEYENE HABER GİT
-- ----------------------------------------------------------------------------
-- ⚠️ Bildirim çöpü üretmemek için iki fren var: aynı kayda en fazla
-- `talep_bildirim_ara_saat` saatte bir, ve yalnız GÖRÜNÜR (Public)
-- ilanlar için. Bir söz verip onu spam'e çevirmek, hiç söz vermemekten
-- kötüdür.
create or replace function public.trg_talep_haber_ver()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_ara int := coalesce((select (value #>> '{}')::int from beta_settings
                          where key='talep_bildirim_ara_saat'), 12);
  v_n int := 0;
  r record;
begin
  if not coalesce(new.active, true) then return new; end if;
  if coalesce(new.visibility::text, 'Public') <> 'Public' then return new; end if;

  for r in
    select t.id, t.user_id from talep_kayitlari t
     where t.aktif
       and t.airport_code = new.airport_code
       and new.avail_date between t.tarih_bas and t.tarih_bit
       and t.user_id <> new.host_id
       and (t.son_bildirim_at is null
            or t.son_bildirim_at < now() - make_interval(hours => v_ara))
  loop
    -- 🔴 `'discovery'` yazmistim; `notif_category` enum'unda yok
    -- (requests/sessions/invites/connections/system/safety/credits/ratings).
    -- Bu turda DORDUNCU kez bir enum degerini ezberden yazdim. Katalogdan
    -- okumak zorunda degilim ama BAKMAK zorundayim.
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (r.user_id, 'system',
            'Beklediğin gün için ilan açıldı',
            format('%s · %s — haber ver dediğin aralıkta yeni bir ilan var.',
                   new.airport_code, to_char(new.avail_date, 'DD.MM.YYYY')),
            'availability', new.id);
    update talep_kayitlari set son_bildirim_at = now() where id = r.id;
    v_n := v_n + 1;
  end loop;

  if v_n > 0 then
    raise notice 'talep haberi: % kisiye gonderildi', v_n;
  end if;
  return new;
end $f$;

drop trigger if exists trg_talep_haber on public.availabilities;
create trigger trg_talep_haber
  after insert on public.availabilities
  for each row execute function public.trg_talep_haber_ver();

-- ----------------------------------------------------------------------------
-- 4) ARZ TARAFINA GÖSTERİLECEK KANIT
-- ----------------------------------------------------------------------------
-- Host'a "bu tarihte 14 kişi bekliyor" demek, ilan açma sebebinin
-- kendisi. Bu fonksiyon o cümleyi üretiyor.
create or replace function public.talep_yogunlugu(p_airport text, p_date date)
returns jsonb language sql stable security definer set search_path = public as $f$
  select jsonb_build_object(
    'havalimani', upper(btrim(p_airport)),
    'tarih', p_date,
    'bekleyen', (select count(*) from talep_kayitlari t
                  where t.aktif and t.airport_code = upper(btrim(p_airport))::char(3)
                    and p_date between t.tarih_bas and t.tarih_bit),
    'acik_ilan', (select count(*) from availabilities a
                   where a.active and a.airport_code = upper(btrim(p_airport))::char(3)
                     and a.avail_date = p_date));
$f$;
grant execute on function public.talep_yogunlugu(text, date) to authenticated;

create or replace function public.bo_talep_yogunlugu(p_gun int default 45)
returns table(airport_code text, tarih date, bekleyen int, acik_ilan int, aciklik int)
language sql stable security definer set search_path = public as $f$
  with gunler as (
    select t.airport_code, g::date as tarih
      from talep_kayitlari t,
           lateral generate_series(greatest(t.tarih_bas, current_date),
                                   least(t.tarih_bit, current_date + p_gun),
                                   interval '1 day') g
     where t.aktif
  )
  select gu.airport_code::text, gu.tarih, count(*)::int as bekleyen,
         (select count(*)::int from availabilities a
           where a.active and a.airport_code = gu.airport_code and a.avail_date = gu.tarih),
         count(*)::int - (select count(*)::int from availabilities a
                           where a.active and a.airport_code = gu.airport_code
                             and a.avail_date = gu.tarih)
    from gunler gu
   group by gu.airport_code, gu.tarih
   order by 5 desc, 3 desc, 2;
$f$;
revoke execute on function public.bo_talep_yogunlugu(int) from public, anon, authenticated;
grant execute on function public.bo_talep_yogunlugu(int) to service_role;

-- ----------------------------------------------------------------------------
-- 5) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('talep_birak','app','Bos kesif ekraninda "haber ver" (247)'),
  ('taleplerim','app','Kullanicinin birakti talep kayitlari (247)'),
  ('talebi_kaldir','app','Talep kaydini kaldir (247)'),
  ('talep_yogunlugu','app','Ilan acarken "bu tarihte kac kisi bekliyor" (247)'),
  ('acik_istek_tavanim','app','Ayni anda kac acik istegin olabilir (246)')
on conflict (fn_name) do update set note = excluded.note;

do $$ declare v jsonb; begin
  v := public.apply_rpc_surface();
  raise notice '247: rpc yuzeyi uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

-- ----------------------------------------------------------------------------
-- 6) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n247$
declare
  v_h text[] := '{}';
  v_u uuid; v_ap text; v_d date; v_r jsonb; v_bildirim_once int; v_bildirim_sonra int;
begin
  begin
    select id into v_u from users where email like 'guest1@seed%' limit 1;
    if v_u is null then select id into v_u from users limit 1; end if;
    select code into v_ap from airports order by code limit 1;
    v_d := current_date + 10;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_u, 'role','authenticated')::text, true);

    -- (1) Talep birakilabiliyor mu
    v_r := public.talep_birak(v_ap, v_d, v_d + 3);
    if coalesce(v_r ->> 'ok','') <> 'true' then
      v_h := v_h || 'talep_birak basarisiz'::text;
    end if;
    if (v_r ->> 'bekleyen_kisi')::int < 1 then
      v_h := v_h || 'talep_birak bekleyen kisi sayisini dondurmedi'::text;
    end if;

    -- (2) 🔴 ASIL SINAMA: ilan acilinca HABER GIDIYOR MU
    select count(*) into v_bildirim_once from notifications
     where user_id = v_u and title = 'Beklediğin gün için ilan açıldı';

    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, active, visibility)
    select (select id from users where id <> v_u limit 1),
           (select l.id from lounges l where l.airport_code = v_ap::char(3) and l.active limit 1),
           v_ap::char(3), v_d + 1, time '09:00', time '13:00', 2, 0, true,
           'Public'::availability_visibility;

    select count(*) into v_bildirim_sonra from notifications
     where user_id = v_u and title = 'Beklediğin gün için ilan açıldı';

    if v_bildirim_sonra <= v_bildirim_once then
      v_h := v_h || 'ilan acildi ama BEKLEYENE HABER GITMEDI — akisin tek isi buydu'::text;
    end if;

    -- (3) TERS YÖN: aralik DISINDAKI ilan haber URETMEMELI
    v_bildirim_once := v_bildirim_sonra;
    update talep_kayitlari set son_bildirim_at = null where user_id = v_u;
    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, active, visibility)
    select (select id from users where id <> v_u limit 1),
           (select l.id from lounges l where l.airport_code = v_ap::char(3) and l.active limit 1),
           v_ap::char(3), v_d + 40, time '09:00', time '13:00', 2, 0, true,
           'Public'::availability_visibility;
    select count(*) into v_bildirim_sonra from notifications
     where user_id = v_u and title = 'Beklediğin gün için ilan açıldı';
    if v_bildirim_sonra > v_bildirim_once then
      v_h := v_h || 'ARALIK DISINDAKI ilan da haber uretti — bildirim copu'::text;
    end if;

    -- (4) Arz tarafi kaniti
    if (public.talep_yogunlugu(v_ap, v_d) ->> 'bekleyen')::int < 1 then
      v_h := v_h || 'talep_yogunlugu bekleyeni saymiyor'::text;
    end if;

    raise exception 'GERI_AL_247';
  exception when others then
    if sqlerrm <> 'GERI_AL_247' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '247 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '247 OK · talep birakilabiliyor · ilan acilinca haber gidiyor · aralik disi haber yok';
end $n247$;

select '247 HABER VER KURULDU' as sonuc,
       (select count(*) from talep_kayitlari where aktif)                        as aktif_talep,
       (select count(*) from pg_trigger where tgname='trg_talep_haber' and not tgisinternal) as tetikleyici,
       (select count(*) from rpc_client_surface where fn_name like 'talep%')      as yeni_rpc;
