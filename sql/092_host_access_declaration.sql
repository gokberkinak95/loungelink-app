-- ============================================================
-- LoungeLink · 092_host_access_declaration.sql
-- HOST'A DOĞRU SORULARI SORMAK
--
-- ⚠️ UYGULAMAYI ETKİLER (v1.88 ile). Yeni kolon + yeni RPC; eski yol
-- (profiles'a doğrudan update) çalışmaya devam eder, kırılma yok.
--
-- ------------------------------------------------------------
-- 🔴 İKİ BOŞLUK, İKİSİ DE AYNI KÖKTEN
-- ------------------------------------------------------------
-- 087'de kotayı, 088'de kart ürünlerini modelledik. Ama veritabanı
-- "host'un kaç hakkı kaldı"yı TUTABİLİYOR olsa da uygulama bunu HOST'A
-- HİÇ SORMUYOR. Sormadığımız bir şeyi bilemeyiz; bilmediğimiz şey
-- üzerine kurduğumuz uyarı da tahminden ibaret kalır.
--
-- BOŞLUK 1 — "MİSAFİR ÜCRET ÖDER" SEÇENEĞİ YOK.
--   Ekran şunu soruyor: "Yanında misafir alabiliyor musun?"
--     · Evet — 1 misafir dahil
--     · Evet — 2+ misafir dahil
--     · Misafir hakkı yok
--   Priority Pass / LoungeKey / DragonPass'li bir host burada "Evet —
--   1 misafir dahil" seçer, çünkü misafir GERÇEKTEN girebiliyor. Ama o
--   programlarda misafir ÜCRETLİDİR. Yani uygulamanın kendi onboarding'i,
--   kapıda ödenecek parayı gizleyen bir cevap üretiyor. Dördüncü seçenek
--   bu turun en yüksek getirili tek değişikliği.
--
-- BOŞLUK 2 — KALAN HAK SORULMUYOR.
--   QNB Private 15/yıl, TEB 4/ay, Ziraat Plus Elite 30/yıl... Kotası
--   bitmiş host misafir kabul ederse misafir kapıda fatura görür.
--   Kotayı DOĞRULAYAMAYIZ (banka API'si yok) ama SORABİLİRİZ. Beyan,
--   hiç bilmemekten iyidir — yeter ki beyan olduğu açıkça yazılsın.
-- ============================================================

alter table profiles add column if not exists guest_fee_expected boolean;
comment on column profiles.guest_fee_expected is
  'Host beyanı: misafir kapıda ücret öder mi? true=öder (PP/LoungeKey/DragonPass tipi), '
  'false=ücretsiz dahil, null=bilinmiyor/sorulmadı.';

-- Ekranın tek çağrısı. Üç tabloya birden yazar ki app iki ayrı istek
-- yapıp yarıda kalma riski taşımasın.
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.save_host_access(text[], smallint, boolean, smallint, text, smallint);
create or replace function public.save_host_access(
  p_sources           text[]   default null,
  p_guest_capacity    smallint default null,
  p_guest_fee_expected boolean default null,
  p_quota_total       smallint default null,
  p_quota_period      text     default null,
  p_quota_used        smallint default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_txt  text;
  v_prog uuid;
  v_ent  uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_quota_period is not null and p_quota_period not in ('year','month','unlimited') then
    raise exception 'invalid_quota_period';
  end if;
  -- Kullanılan, toplamı aşamaz: beyan hatası sessizce yanlış uyarı üretmesin
  if p_quota_total is not null and p_quota_used is not null and p_quota_used > p_quota_total then
    raise exception 'quota_used_exceeds_total';
  end if;

  v_txt := nullif(array_to_string(coalesce(p_sources, '{}'::text[]), ', '), '');

  update profiles
     set access_source      = coalesce(v_txt, access_source),
         guest_capacity     = coalesce(p_guest_capacity, guest_capacity),
         guest_fee_expected = coalesce(p_guest_fee_expected, guest_fee_expected),
         updated_at         = now()
   where user_id = v_uid;

  -- Beyandan programı çöz (086'nın takma ad sözlüğü)
  v_prog := public.match_program_by_text(coalesce(v_txt,
              (select access_source from profiles where user_id = v_uid)));

  if v_prog is not null then
    insert into host_entitlements
      (user_id, program_id, guest_capacity, origin, note,
       quota_total, quota_period, quota_used, self_reported_at)
    values
      (v_uid, v_prog, p_guest_capacity, 'declared', 'save_host_access',
       p_quota_total, p_quota_period, coalesce(p_quota_used, 0), now())
    on conflict (user_id, program_id, coalesce(tier,''))
    do update set
      guest_capacity   = coalesce(excluded.guest_capacity, host_entitlements.guest_capacity),
      quota_total      = coalesce(excluded.quota_total, host_entitlements.quota_total),
      quota_period     = coalesce(excluded.quota_period, host_entitlements.quota_period),
      quota_used       = coalesce(excluded.quota_used, host_entitlements.quota_used),
      self_reported_at = now(),
      origin           = 'declared'
    returning id into v_ent;
  end if;

  return jsonb_build_object(
    'ok', true,
    'program_id', v_prog,
    'entitlement_id', v_ent,
    'quota', case when v_ent is null then null else public.entitlement_remaining(v_ent) end);
end $$;
grant execute on function public.save_host_access(text[], smallint, boolean, smallint, text, smallint) to authenticated;

-- Ekran açılırken mevcut beyanı geri okur (kota dahil).
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.my_host_access();
create or replace function public.my_host_access()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); p profiles%rowtype; e host_entitlements%rowtype;
begin
  select * into p from profiles where user_id = v_uid;
  select * into e from host_entitlements where user_id = v_uid
   order by self_reported_at desc nulls last, created_at desc limit 1;
  return jsonb_build_object(
    'access_source', p.access_source,
    'guest_capacity', p.guest_capacity,
    'guest_fee_expected', p.guest_fee_expected,
    'quota_total', e.quota_total,
    'quota_period', e.quota_period,
    'quota_used', e.quota_used,
    'quota', case when e.id is null then null else public.entitlement_remaining(e.id) end);
end $$;
grant execute on function public.my_host_access() to authenticated;

-- Karar motoru artık host'un BEYANINI da dikkate alsın:
-- "misafir ücret öder" diyen host'un ilanında, kural verisi ne derse desin
-- misafire ücret uyarısı gösterilir. Host kendi programını bizden iyi bilir.
create or replace function public.host_declares_paid_guest(p_host uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select guest_fee_expected from profiles where user_id = p_host), false);
$$;
grant execute on function public.host_declares_paid_guest(uuid) to authenticated;

select count(*) filter (where guest_fee_expected is not null) as beyan_veren,
       count(*) as toplam_profil from profiles;

select '092 OK - host beyani genisletildi (ucretli misafir + kalan hak)' as sonuc;
