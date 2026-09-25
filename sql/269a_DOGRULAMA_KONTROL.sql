-- ============================================================================
-- 269a — 269 İŞİNİ YAPTI MI?   (SALT OKUNUR · TABLO DÖNDÜRÜR)
--
-- 🔴 NEDEN
-- 269'un son satırı `select public.recompute_trust(id) from users` — yani
-- ekranda bir sürü sayı görünür. O sayılar "dosya commit oldu" demektir,
-- "dosya işini yaptı" DEMEZ. İkisi ayrı sorulardır.
--
-- 🆕 SINIF: "BİR GÖÇÜN ÇALIŞTIĞINI ÇIKTISININ VARLIĞINDAN DEĞİL,
-- DEĞİŞTİRMEYİ VAAT ETTİĞİ ŞEYİN DEĞİŞMİŞ OLMASINDAN ANLARSIN."
--
-- Bu dosya hiçbir şeyi değiştirmez. Altı soruyu tek tabloda cevaplar.
-- Hepsi ✅ ise 269 gerçekten yerine oturmuştur.
-- ============================================================================

with
-- 1) AYNA: Supabase'in gerçeği ile bizim tablomuz eşleşiyor mu?
ayna as (
  select
    count(*) filter (where au.email_confirmed_at is not null)                      as onayli,
    count(*) filter (where au.email_confirmed_at is not null
                       and coalesce(v.email_verified,false))                       as aynada_var,
    count(*) filter (where au.email_confirmed_at is not null
                       and not coalesce(v.email_verified,false))                   as aynada_yok
  from users u
  join auth.users au on au.id = u.id
  left join verifications v on v.user_id = u.id
  where u.deleted_at is null
),
-- 🔴 TERS YÖN — DENETİMİMİN KÖR NOKTASIYDI.
-- İlk sürüm "doğrulanmış işaretli hesapların hepsi doğrulanmış mı" diye
-- soruyordu; yani AYNAYA bakıp aynaya soruyordu ve hep ✅ çıkıyordu.
-- Sorulması gereken: ayna, GERÇEKTEN OLMAYAN bir şeyi gösteriyor mu?
-- Gökberk'in çıktısında 47 onaylı hesap vardı ama 58 hesap e-posta puanı
-- alıyordu — 11 hesap aynada var, gerçekte yok. Denetim bunu görmedi.
-- 🆕 SINIF: "BİR AYNAYI KENDİ İÇİNDEN DENETLERSEN HEP TUTARLI ÇIKAR —
-- ÖLÇÜLECEK ŞEY AYNA DEĞİL, AYNA İLE GERÇEĞİN FARKIDIR."
sahte as (
  select
    count(*) filter (where au.id is null)                    as auth_satiri_yok,
    count(*) filter (where au.id is not null
                       and au.email_confirmed_at is null)    as onaysiz_ama_isaretli
  from users u
  left join auth.users au on au.id = u.id
  left join verifications v on v.user_id = u.id
  where u.deleted_at is null and coalesce(v.email_verified, false)
),
-- 2) PUAN: e-posta bileşeni yalnız DOĞRULANMIŞ hesaplarda mı?
puan as (
  select
    count(*) filter (where t.components ? 'email')                                 as email_puani_alan,
    count(*) filter (where t.components ? 'email'
                       and not coalesce(v.email_verified,false))                   as hak_etmeden_alan,
    count(*) filter (where not (t.components ? 'email')
                       and coalesce(v.email_verified,false))                       as hak_edip_alamayan
  from trust_scores t
  join users u on u.id = t.user_id and u.deleted_at is null
  left join verifications v on v.user_id = t.user_id
),
-- 3) TETİKLEYİCİ: onay YARIN gelirse ayna kendini güncelleyecek mi?
tetik as (
  select exists (select 1 from pg_trigger
                  where tgname = 'on_auth_email_confirmed' and not tgisinternal) as var
),
-- 4) KANAL: uygulama SMS'in açık olup olmadığını sunucudan sorabiliyor mu?
kanal as (
  select exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='dogrulama_kanali')      as fn_var,
         (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='send_otp'
             and pg_get_functiondef(p.oid) like '%sms_not_configured%')           as send_otp_duruyor
),
-- 5) ETKİ: kaç hesap e-posta puanını KAYBETTİ (doğrulanmamış olanlar)
etki as (
  select count(*) as dogrulanmamis
    from users u
    left join verifications v on v.user_id = u.id
   where u.deleted_at is null and not coalesce(v.email_verified,false)
)
select * from (
  select 1::numeric as s, 'AYNA · e-postası onaylı hesap'                as "kontrol",
         a.onayli::text                                          as "değer",
         '—'                                                     as "durum"
    from ayna a
  union all
  select 2, 'AYNA · bunlardan verifications''a yazılmış olan',
         a.aynada_var::text,
         case when a.aynada_yok = 0 then '✅ hepsi'
              else '❌ ' || a.aynada_yok || ' hesap eksik — 269 §1 çalışmamış' end
    from ayna a
  union all
  select 3, 'PUAN · e-posta bileşeni alan hesap',
         p.email_puani_alan::text,
         case when p.hak_etmeden_alan = 0 then '✅ hepsi doğrulanmış'
              else '❌ ' || p.hak_etmeden_alan || ' hesap doğrulamadan alıyor' end
    from puan p
  union all
  select 3.5, 'AYNA · işaretli ama auth.users satırı YOK (tohum/BO hesabı)',
         k2.auth_satiri_yok::text,
         case when k2.auth_satiri_yok = 0 then '✅ yok'
              else '⚠️ ' || k2.auth_satiri_yok || ' hesap — kimler: 269b_AYNA_FARKI.sql' end
    from sahte k2
  union all
  select 3.6, 'AYNA · auth satırı VAR ama e-postası onaysız (işaretli)',
         k3.onaysiz_ama_isaretli::text,
         case when k3.onaysiz_ama_isaretli = 0 then '✅ yok'
              else '❌ ' || k3.onaysiz_ama_isaretli || ' hesap HAK ETMEDEN +10 alıyor' end
    from sahte k3
  union all
  select 4, 'PUAN · doğrulanmış ama puanı alamayan',
         p.hak_edip_alamayan::text,
         case when p.hak_edip_alamayan = 0 then '✅ yok'
              else '❌ recompute_trust yeniden koşturulmalı' end
    from puan p
  union all
  select 5, 'TETİKLEYİCİ · on_auth_email_confirmed',
         case when t.var then 'var' else 'YOK' end,
         case when t.var then '✅ sonraki onaylar da yazılacak'
              else '❌ 269 §2 kurulmamış' end
    from tetik t
  union all
  select 6, 'KANAL · dogrulama_kanali() fonksiyonu',
         case when k.fn_var then 'var' else 'YOK' end,
         case when k.fn_var then '✅ app SMS''i sunucudan soruyor'
              else '❌ 269 §4 kurulmamış' end
    from kanal k
  union all
  select 7, 'SMS · send_otp sağlayıcı yokken duruyor mu',
         case when k.send_otp_duruyor > 0 then 'evet' else 'HAYIR' end,
         case when k.send_otp_duruyor > 0 then '✅ sessizce ok dönmüyor'
              else '❌ 269 §5 kurulmamış' end
    from kanal k
  union all
  select 8, 'ETKİ · e-postası doğrulanmamış hesap (10 puan almaz)',
         e.dogrulanmamis::text,
         case when e.dogrulanmamis = 0 then '✅ yok'
              else '⚠️ bu hesaplar 10 puan kaybetti — beklenen' end
    from etki e
) x order by s;

-- ----------------------------------------------------------------------------
-- İKİNCİ TABLO: puanların bileşen dağılımı.
-- (Supabase yalnız SON sorgunun tablosunu gösterir; ikisini birden görmek
--  istersen bu sorguyu AYRI çalıştır.)
-- ----------------------------------------------------------------------------
-- select t.score as "puan", count(*) as "hesap",
--        min(t.components::text) as "örnek bileşenler"
--   from trust_scores t join users u on u.id=t.user_id and u.deleted_at is null
--  group by 1 order by 1;
