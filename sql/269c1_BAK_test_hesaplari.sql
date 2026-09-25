-- ============================================================================
-- 269c-1 — BAK: canlıdaki test hesapları   (SALT OKUNUR · HİÇBİR ŞEYİ DEĞİŞTİRMEZ)
--
-- Bu dosyayı çalıştırmak GÜVENLİDİR. Tek yaptığı bir tablo döndürmek.
-- Kapatmak için ikinci dosya var: 269c2_KAPAT_test_hesaplari.sql
--
-- ----------------------------------------------------------------------------
-- 🔴 NEDEN İKİ DOSYA
-- İlk sürümde üç bölümü (§A bak · §A2 temas · §B kapat) TEK dosyaya
-- koymuştum, üçüncüsü de yorumlu. Gökberk haklı olarak "§B ne A ne?" diye
-- sordu. Supabase yalnız SON sorgunun tablosunu gösterdiği için ortadaki
-- bölüm de hiç görünmedi.
--
-- Doğru olan: dosyanın ADI ne yaptığını söylesin ve çalıştırmak tek bir
-- karar olsun. "Şu bloğu yorumdan çıkar" bir kullanım talimatı değil,
-- kullanıcıya devredilmiş bir tasarım borcudur.
--
-- 🆕 SINIF: "BİR ARACIN GÜVENLİ KULLANIMI, KULLANICININ DOĞRU BÖLÜMÜ
-- SEÇMESİNE BAĞLIYSA ARAÇ GÜVENLİ DEĞİLDİR — TEHLİKELİ OLANI AYRI BİR
-- DOSYAYA KOY."
-- ============================================================================

with test as (
  select id, email from users
   where deleted_at is null
     and (email like '%@vitrin.loungelink.test'
       or email like '%@seed.loungelink.test'
       or email like '%@e2e.test')
),
gorunen as (
  select coalesce(sum((select count(*) from public.discover_availabilities() d
                        where d.host_id = t.id)), 0) as n
    from test t
),
temas as (
  select count(*) as n
    from requests r
    left join test gt on gt.id = r.guest_id
    left join test ht on ht.id = r.host_id
   where (gt.id is null) <> (ht.id is null)
),
ozet as (
  select 0 as sira,
         '► KEŞFET''TE GÖRÜNEN SAHTE İLAN'                as e_posta,
         (select n from gorunen)::text                     as rol,
         case when (select n from gorunen) = 0 then '✅ yok'
              else '🔴 gerçek kullanıcılar bunları görüyor' end as karar,
         null::int as aktif_ilan, null::int as kesfette, null::int as talep,
         null::boolean as ep_isaret, null::boolean as auth_var,
         null::boolean as auth_onay, null::int as puan
  union all
  select 1,
         '► GERÇEK KULLANICI ↔ TEST HESABI TEMASI',
         (select n from temas)::text,
         case when (select n from temas) = 0
              then '✅ temas yok — KAPAT dosyasını çalıştırabilirsin'
              else '🔴 önce bu taleplere ne olacağına karar ver' end,
         null, null, null, null, null, null, null
)
select sira as "#", e_posta as "hesap / ölçüm", rol as "rol / değer",
       karar as "durum", aktif_ilan as "aktif ilan", kesfette as "KEŞFETTE",
       talep as "talep", ep_isaret as "e-posta ✓", auth_var as "auth var",
       auth_onay as "auth onay", puan as "puan"
  from ozet
union all
select 2, u.email, u.role::text,
       case when u.is_staff then 'staff (zaten gizli)' else 'görünür' end,
       (select count(*) from availabilities a where a.host_id=u.id and a.active),
       (select count(*) from public.discover_availabilities() d where d.host_id=u.id),
       (select count(*) from requests r where r.guest_id=u.id or r.host_id=u.id),
       coalesce(v.email_verified,false), (au.id is not null),
       (au.email_confirmed_at is not null), t2.score
  from users u
  left join auth.users    au on au.id = u.id
  left join verifications v  on v.user_id = u.id
  left join trust_scores  t2 on t2.user_id = u.id
 where u.deleted_at is null
   and (u.email like '%@vitrin.loungelink.test'
     or u.email like '%@seed.loungelink.test'
     or u.email like '%@e2e.test')
order by 1,
         5 desc nulls last,
         2;
