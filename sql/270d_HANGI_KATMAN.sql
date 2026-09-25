-- ============================================================================
-- 270d — SIZINTI ZİNCİRİN HANGİ KATMANINDA BAŞLIYOR?   (SALT OKUNUR)
--
-- 🔴 DURUM: 270c kanıtladı — gerçek bir kullanıcı (gzmdmz@gmail.com),
-- `active = false` ve tarihi GEÇMİŞ 4 ilanı Keşfet'te görüyor.
--
-- `discover_availabilities_base` içinde şu iki koşul var:
--     and a.active = true
--     and a.avail_date >= current_date
-- Bu ilanlar ikisini de sağlamıyor. Yani ya o fonksiyondan gelmiyorlar,
-- ya da BENDEKİ `_base` ile SENDEKİ farklı.
--
-- Zincir dört katmanlı:
--     discover_availabilities        (sıralama sarmalayıcısı)
--       └ discover_availabilities_ham       (sıralama)
--           └ discover_availabilities_prerank (zenginleştirme)
--               └ discover_availabilities_base   (KAPILAR BURADA)
--
-- Bu dosya HER KATMANDA aynı 4 ilanı arıyor. İlk kez hangi katmanda
-- görünüyorlarsa, kusur O KATMANDA ya da ALTINDA.
--
-- 🆕 SINIF: "ÇOK KATMANLI BİR ZİNCİRDE HATAYI TAHMİN ETME — HER
-- KATMANI AYRI AYRI ÖLÇ, GİRİŞ NOKTASI KENDİNİ GÖSTERİR."
-- ============================================================================

do $d270d$
declare
  v_normal uuid; v_eski text; n int;
begin
  drop table if exists _270d;
  create temp table _270d(sira int, katman text, bulunan int, kapilar text);

  v_eski := current_setting('request.jwt.claims', true);
  select id into v_normal from users u
   where u.deleted_at is null and not coalesce(u.is_staff,false)
     and not exists (select 1 from availabilities a where a.host_id=u.id and a.active)
   limit 1;
  perform set_config('request.jwt.claims',
    json_build_object('sub', coalesce(v_normal::text,''))::text, true);

  select count(*) into n from public.discover_availabilities_base() d
   where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b','d770cc1a-e652-4fed-a967-a413bbbd6629',
                  '8bf70984-0368-4236-b230-a4d3e2b72d05','197a86aa-6c31-4b46-883b-cd9c6f6a3536');
  insert into _270d values (1, 'discover_availabilities_base', n, '');

  select count(*) into n from public.discover_availabilities_prerank() d
   where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b','d770cc1a-e652-4fed-a967-a413bbbd6629',
                  '8bf70984-0368-4236-b230-a4d3e2b72d05','197a86aa-6c31-4b46-883b-cd9c6f6a3536');
  insert into _270d values (2, 'discover_availabilities_prerank', n, '');

  select count(*) into n from public.discover_availabilities_ham() d
   where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b','d770cc1a-e652-4fed-a967-a413bbbd6629',
                  '8bf70984-0368-4236-b230-a4d3e2b72d05','197a86aa-6c31-4b46-883b-cd9c6f6a3536');
  insert into _270d values (3, 'discover_availabilities_ham', n, '');

  select count(*) into n from public.discover_availabilities() d
   where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b','d770cc1a-e652-4fed-a967-a413bbbd6629',
                  '8bf70984-0368-4236-b230-a4d3e2b72d05','197a86aa-6c31-4b46-883b-cd9c6f6a3536');
  insert into _270d values (4, 'discover_availabilities', n, '');

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);
exception when others then
  insert into _270d values (99, 'HATA: ' || sqlerrm, -1, '');
end $d270d$;

select
  d.sira                                   as "#",
  d.katman                                 as "katman",
  d.bulunan                                as "4 ilandan kaçı geçiyor",
  case when d.bulunan = 0 then '✅ eliyor' else '🔴 GEÇİRİYOR' end as "karar",
  coalesce((select string_agg(x, ' · ') from (
     select case when pg_get_functiondef(p.oid) like '%a.active = true%'
                   or pg_get_functiondef(p.oid) like '%a.active=true%' then 'aktif kapısı' end
     union all
     select case when pg_get_functiondef(p.oid) like '%avail_date >= current_date%' then 'tarih kapısı' end
     union all
     select case when pg_get_functiondef(p.oid) like '%is_staff%' then 'staff kapısı' end
   ) y(x) where x is not null), '— hiç kapı yok')  as "taşıdığı kapılar",
  (select count(*) from pg_proc p2 join pg_namespace n2 on n2.oid=p2.pronamespace
    where n2.nspname='public' and p2.proname = d.katman)          as "aynı adda kaç fonksiyon"
from _270d d
left join pg_proc p on p.oid = (
  select p3.oid from pg_proc p3 join pg_namespace n3 on n3.oid=p3.pronamespace
   where n3.nspname='public' and p3.proname = d.katman limit 1)
order by d.sira;
