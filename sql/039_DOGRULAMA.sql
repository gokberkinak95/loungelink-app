-- =====================================================================
-- 037 · DOĞRULAMA — 033'ü çalıştırdıktan SONRA çalıştır
-- Hiçbir şeyi değiştirmez, sadece OKUR. Her satır "✓ OK" demeli.
-- =====================================================================

-- 1) Trigger düzeldi mi? handle_new_user artık password_hash yazıyor mu?
select
  '1) handle_new_user' as kontrol,
  case
    when p.prosrc like '%password_hash%'
     and p.prosrc like '%::user_role%'
     and p.prosrc like '%grant_signup_credits%'
    then '✓ OK — password_hash + enum cast + beta kredisi var'
    when p.prosrc not like '%password_hash%'
    then '❌ HALA KIRIK — password_hash yok, 033ü calistir'
    else '⚠ eksik bir sey var'
  end as sonuc
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'handle_new_user';

-- 2) Trigger auth.users'a bağlı mı?
select
  '2) on_auth_user_created' as kontrol,
  case when count(*) = 1 then '✓ OK — trigger bagli'
       else '❌ trigger YOK (' || count(*) || ' adet)' end as sonuc
from pg_trigger where tgname = 'on_auth_user_created' and not tgisinternal;

-- 3) YETİM KAYIT var mı? (auth'ta var ama public.users'ta yok)
--    Kırık trigger döneminde yarım kalmış hesap olabilir.
select
  '3) yetim kayit' as kontrol,
  case when count(*) = 0 then '✓ OK — yetim yok'
       else '⚠ ' || count(*) || ' yetim hesap var → asagidaki 3b sorgusuna bak' end as sonuc
from auth.users au
left join public.users pu on pu.id = au.id
where pu.id is null;

-- 3b) Yetim varsa kimler? (listele — sonra elle silebilir veya duzeltebiliriz)
select '3b) yetim liste' as kontrol, au.email, au.created_at
from auth.users au
left join public.users pu on pu.id = au.id
where pu.id is null
order by au.created_at desc;

-- 4) Fonksiyonların TEK sürümü mü var? (overload birikmiş mi?)
select
  '4) ' || p.proname as kontrol,
  case when count(*) = 1 then '✓ OK'
       else '❌ ' || count(*) || ' SURUM VAR — PostgREST karisir, PRE_drop calistir' end as sonuc
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'handle_new_user','grant_signup_credits','admin_credit_adjust','admin_bulk_credit',
    'create_request','create_availability','recompute_badge','recompute_trust',
    'lounge_radar_count','lounge_radar_people',
    'upsert_admin','needs_password_change','mark_password_changed',
    'apply_for_host','my_host_application','review_host_application','admin_update_profile'
  )
group by p.proname
order by p.proname;

-- 5) Yeni tablolar geldi mi?
select '5) ' || t as kontrol,
       case when to_regclass('public.' || t) is not null then '✓ OK' else '❌ TABLO YOK' end as sonuc
from unnest(array['beta_settings','host_applications','blocks','credit_ledger','admin_roles']) as t;

-- 6) Beta kredi ayarı açık mı, kaç kredi?
select '6) beta kredisi' as kontrol,
       coalesce((select value::text from beta_settings where key='signup_credits'),
                '❌ beta_settings satiri YOK') as sonuc;

-- 7) upsert_admin doğru imzada mı? (p_must_change var mı?)
select
  '7) upsert_admin imza' as kontrol,
  case when pg_get_function_arguments(p.oid) like '%p_must_change%'
       then '✓ OK — ' || pg_get_function_arguments(p.oid)
       else '❌ p_must_change YOK → 035i calistir · su an: ' || pg_get_function_arguments(p.oid) end as sonuc
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='upsert_admin';

-- 8) must_change_password kolonu geldi mi?
select '8) must_change_password' as kontrol,
  case when exists (
    select 1 from information_schema.columns
    where table_name='admin_roles' and column_name='must_change_password'
  ) then '✓ OK' else '❌ KOLON YOK → 035i calistir' end as sonuc;
