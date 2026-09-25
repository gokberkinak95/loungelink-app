-- ============================================================
-- LoungeLink · 153_host_motivation.sql
-- HOST'UN GERCEK MOTIVASYONU KREDI DEGIL
--
-- ⚠️ Uygulamayi ETKILER (yeni RPC + rozet).
--
-- ------------------------------------------------------------
-- 🔴 URUN TESHISI
-- ------------------------------------------------------------
-- Elite Plus karti olan bir is insani ayda 3 kredi icin yabanci
-- biriyle salona girmez. Kredi bir TESEKKUR olarak dogru ama bir
-- MOTIVASYON olarak zayif.
--
-- Uc gercek motivasyon var ve ucu de bugun urunde YOK:
--
--   1. HAKKI COPE GIDIYOR. THY Elite Plus'ta yilda onlarca misafir
--      hakki var ve cogu kullanilmiyor. "Bu yil 14 misafir hakkini
--      kullanmadin" cumlesi krediden guclu — kayip, kazanctan daha
--      cok harekete gecirir.
--
--   2. STATU GORUNURLUGU. Bu segment taninmayi sever. "Kurucu Host"
--      rozeti ilk 100 kisiye KALICI bir isaret; sonradan alinamaz.
--
--   3. AG. Yanindaki koltuktaki kisiyle tanismak.
--
-- 🔴 AMA BIR SINIR: hacmi odullendirmeyecegiz. Rakip liderlik tablosu
-- ve "Top Surfer 400" puani kullaniyor — bu, karti bir ISLETMEYE
-- cevirmeyi tesvik eder ve kart aglarinin kurallari tam da bunu
-- yasaklar. Uyeligi iptal olan host, kaybedilmis host'tur.
-- Bu yuzden sayac DEGIL, KULLANILMAYAN HAK gosteriyoruz.
-- ============================================================

alter table profiles add column if not exists founding_host_no int;
comment on column profiles.founding_host_no is
  'Kurucu Host sirasi (1-100). Bir kez verilir, GERI ALINMAZ. '
  'Sonradan katilan alamaz — degerini kitliktan alir.';

create unique index if not exists uq_founding_host on profiles(founding_host_no)
  where founding_host_no is not null;

-- 🔴 Ilk 100 host: ilk ilanini acan kisi sirayi alir.
create or replace function public.claim_founding_host()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_no int; v_has int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select founding_host_no into v_has from profiles where user_id = v_uid;
  if v_has is not null then
    return jsonb_build_object('ok', true, 'no', v_has, 'already', true);
  end if;
  -- Ilan acmamis birine verilmez: rozet NIYETI degil EYLEMI odullendirir.
  if not exists (select 1 from availabilities where host_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'no_listing');
  end if;

  select coalesce(max(founding_host_no), 0) + 1 into v_no from profiles;
  if v_no > 100 then
    return jsonb_build_object('ok', false, 'reason', 'closed',
      'note', 'Kurucu Host kontenjanı doldu.');
  end if;
  update profiles set founding_host_no = v_no where user_id = v_uid;
  return jsonb_build_object('ok', true, 'no', v_no,
    'note', 'Kurucu Host #' || v_no || ' — bu rozet kalıcıdır.');
end $$;
grant execute on function public.claim_founding_host() to authenticated;

-- ============================================================
-- KULLANILMAYAN HAK — "KAYIP" CERCEVESI
-- 🔴 Sayiyi UYDURMUYORUZ. Host'un BEYAN ettigi kota ve bizim
-- saydigimiz gerceklesen oturum arasindaki fark. Beyan yoksa
-- hicbir sey demiyoruz — "14 hakkin bosa gitti" demek icin once
-- 14 hakkin oldugunu BILMEK gerekir.
-- ============================================================
create or replace function public.host_unused_rights(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := coalesce(p_user, auth.uid()); he record; v_used int; v_year int;
begin
  select * into he from host_entitlements where user_id = v_uid
   order by coalesce(verified,false) desc limit 1;
  if not found or he.quota_total is null then
    return jsonb_build_object('known', false);
  end if;

  v_year := extract(year from current_date);
  select count(*) into v_used from sessions s
    join availabilities a on a.id = s.avail_id
   where a.host_id = v_uid and s.status = 'completed'
     and extract(year from s.created_at) = v_year;

  return jsonb_build_object(
    'known', true,
    'total', he.quota_total,
    'used', v_used,
    'left', greatest(he.quota_total - v_used, 0),
    -- 🔴 KAYIP CERCEVESI: "8 hakkin kaldi" degil "8 hakkin bosa gidecek".
    -- Ayni sayi, farkli cumle — ve kayip, kazanctan cok harekete gecirir.
    'headline', case
      when he.quota_total - v_used <= 0 then 'Bu yılki misafir hakkını kullandın.'
      else format('Bu yıl %s misafir hakkın kullanılmadan duruyor.', he.quota_total - v_used) end,
    'sub', case when he.quota_total - v_used > 0
      then 'Kullanılmayan haklar yıl sonunda siliniyor. Bir yolcuyu içeri alarak değerlendirebilirsin.' end,
    'note', 'Bu sayı SENİN beyanına dayanır; kartını veren kurumdan teyit et.');
end $$;
grant execute on function public.host_unused_rights(uuid) to authenticated;

-- Kurucu Host sayaci (kitlik gorunur olmali)
create or replace function public.founding_host_status()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'taken', (select count(*) from profiles where founding_host_no is not null),
    'left', greatest(100 - (select count(*) from profiles where founding_host_no is not null), 0),
    'mine', (select founding_host_no from profiles where user_id = auth.uid()));
$$;
grant execute on function public.founding_host_status() to authenticated;

insert into beta_settings (key, value) values
 ('founding_host_pitch', to_jsonb(
   'İlk 100 host''tan biri ol. Bu rozet kalıcıdır ve sonradan alınamaz.'::text))
on conflict (key) do update set value = excluded.value;

select '153 OK - host motivasyonu: kullanilmayan hak + kurucu rozet' as sonuc;
