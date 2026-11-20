-- ============================================================================
-- KURUCU_APPLE_OLCUM · SALT OKUNUR (hiçbir şeyi değiştirmez) · 13 Kasım 2026
--
-- 1) Kurucu hesap: test görünürlüğü listesinde mi, personel (is_staff) mi?
--    (personel de test hesaplarını görür — listeden çıkmak tek başına yetmeyebilir)
-- 2) Adı e-postanın @ öncesinden yazılmış gerçek hesaplar (357'nin saydığı 2 Apple + 1 e-posta)
--
-- KOŞMA: SQL Editor → tamamı → Run. Tek tablo döner.
-- ============================================================================
select 'kurucu' as tur,
       u.email,
       p.name as ad,
       coalesce(au.raw_app_meta_data ->> 'provider', '?') as giris,
       to_char(u.created_at, 'DD.MM.YYYY HH24:MI') as kayit,
       'test_gorunurlugu=' || exists (select 1 from test_gorunurlugu g where g.user_id = u.id)::text
         || ' · is_staff=' || coalesce(u.is_staff, false)::text as durum
  from users u
  left join profiles p on p.user_id = u.id
  left join auth.users au on au.id = u.id
 where lower(u.email) = 'gokberkinak95@gmail.com'
union all
select 'eposta_adli',
       u.email,
       p.name,
       coalesce(au.raw_app_meta_data ->> 'provider', '?'),
       to_char(u.created_at, 'DD.MM.YYYY HH24:MI'),
       'son giris ' || coalesce(to_char(au.last_sign_in_at, 'DD.MM.YYYY'), '-')
         || ' · ilan ' || (select count(*) from availabilities a where a.host_id = u.id)
         || ' · seyahat ' || (select count(*) from visits v where v.user_id = u.id)
  from profiles p
  join users u on u.id = p.user_id
  join auth.users au on au.id = u.id
 where p.name = split_part(u.email, '@', 1)
   and not public.seed_test_hesabi(u.email)
   and not coalesce(u.is_staff, false)
   and u.deleted_at is null
 order by 1, 5;
