-- ============================================================================
-- TEMIZLIK ENVANTERİ · YAYIN ÖNCESİ "KİM GERÇEK, KİM TEST?"   (10 Kasım 2026, SALT OKUNUR)
--
-- Yayından önce test verisi silinecek (351). Silmeden önce canlıdaki her hesabın hangi
-- sınıfa düştüğünü ve neye sahip olduğunu listeler. Hiçbir şey DEĞİŞTİRMEZ.
-- Fikstür hesapları (vitrin / seed / e2e) tek satırda toplam olarak, diğer her hesap
-- satır satır gelir. Sonucu olduğu gibi Claude'a ilet.
-- ============================================================================
with hesap as (
  select u.id, u.email, u.is_staff, u.created_at, u.deleted_at,
         case
           when u.email like '%@vitrin.loungelink.test' or u.email like '%@seed.loungelink.test'
             or u.email like '%@e2e.test' then '0 fikstur'
           when u.email like '%.test'                     then '1 diger .test'
           when u.email like '%@example.com'              then '2 example.com'
           when lower(u.email) = 'inceleme@loungelink.co' then '3 magaza inceleme'
           when u.email like '%@loungelink.co' or u.email like '%@loungelink.com' then '4 loungelink alan adi'
           else '5 diger (gercek olabilir)'
         end as sinif
    from users u
), sayim as (
  select h.*,
         coalesce((select p.name from profiles p where p.user_id = h.id), '-') as ad,
         (select count(*) from availabilities a where a.host_id = h.id) as ilan,
         (select count(*) from visits v where v.user_id = h.id) as seyahat,
         (select count(*) from requests r where r.guest_id = h.id or r.host_id = h.id) as istek,
         (select count(*) from connection_requests c where c.from_id = h.id or c.to_id = h.id) as baglanti,
         (select coalesce(sum(l.delta), 0) from credit_ledger l where l.user_id = h.id) as kredi
    from hesap h
)
select sinif, email, ad, coalesce(is_staff, false) as ekip, created_at::date as kayit,
       deleted_at is not null as silinmis, ilan, seyahat, istek, baglanti, kredi
  from sayim
 where sinif <> '0 fikstur'
union all
select '0 fikstur', count(*) || ' hesap', '-', null, null, null,
       sum(ilan), sum(seyahat), sum(istek), sum(baglanti), sum(kredi)
  from sayim
 where sinif = '0 fikstur'
 order by 1, 5;
