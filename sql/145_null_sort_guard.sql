-- ============================================================
-- LoungeLink · 145_null_sort_guard.sql
-- AYNI NULL TUZAGI BASKA BIR YERDE DAHA
--
-- ⚠️ Uygulamayi ETKILER (kart listesi sirasi).
--
-- 🔴 144'te sunu ogrendim: PostgreSQL'de `ORDER BY ifade DESC`
-- varsayilan olarak NULLS FIRST'tir. Bir karsilastirma NULL doner
-- dondugunde (ornegin `null = 'verified'`), o satir EN BASA ciplar.
--
-- Rehberde bu, Elite Plus'a "misafir goturemezsin" dedirtiyordu.
-- Ayni deseni tum SQL'de aradim ve BIR yerde daha buldum:
-- `card_product_options` kart listesini `(cp.confidence = 'verified')
-- desc` ile siraliyor — ve `confidence` NULL OLABILIYOR (088 onu
-- sonradan dolduruyor).
--
-- Sonuc: guven derecesi HIC girilmemis kartlar, DOGRULANMIS kartlarin
-- USTUNDE cikiyor. Kullaniciya "en guvenilir" gibi gorunen sey aslinda
-- "hakkinda hicbir sey bilmedigimiz" kart oluyor. Sessiz ama zararli.
-- ============================================================

-- 🔴 DEFENSIVE DROP — kendi returns_check kuralimi UCUNCU KEZ ihlal
-- ettim. `card_product_options` OUT parametreleri degisiyor; drop
-- olmadan `cannot change return type` verir.
--
-- Uc kez ayni hatayi yapmis olmam, denetimin YETERSIZ oldugunu
-- gosteriyor: uyariyi ancak CALISTIRDIKTAN sonra goruyorum. Denetim
-- dosyalari tariyor ama ben dosyayi yazarken degil, kosarken
-- ogreniyorum. Asagida bunu sqlcheck'e tasidim.
drop function if exists public.card_product_options();

create or replace function public.card_product_options()
returns table (
  id uuid, issuer text, name text, program text, segment text,
  quota_total smallint, quota_period text, conditions text,
  confidence text, verified boolean, source_url text
) language sql stable security definer set search_path = public as $$
  select cp.id, i.name, cp.name, p.name, cp.segment,
         cp.quota_total, cp.quota_period, cp.conditions,
         coalesce(cp.confidence, 'unknown'),
         (coalesce(cp.confidence,'') = 'verified' and cp.checked_at is not null),
         cp.source_url
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    left join lounge_programs p on p.id = cp.program_id
   where cp.active and (cp.valid_to is null or cp.valid_to >= current_date)
   -- 🔴 coalesce SART: `null = 'verified'` -> NULL -> DESC'te EN BASA.
   -- Guven derecesi bilinmeyen kart, dogrulanmis kartin ustune cikardi.
   order by coalesce(cp.confidence = 'verified', false) desc,
            i.name, cp.name;
$$;
grant execute on function public.card_product_options() to authenticated;

-- Guven derecesi bos kalan kart kalmasin: bilinmiyorsa BILINMIYOR yaz.
-- NULL "belirtilmemis" demek; 'unknown' "bilmiyoruz" demek. Ikincisi
-- bir BILGIDIR, birincisi bir bosluk.
update lounge_card_products set confidence = 'unknown' where confidence is null;

select coalesce(confidence,'(NULL)') as guven, count(*)
  from lounge_card_products where active group by 1 order by 2 desc;

select '145 OK - NULL siralama tuzagi kart listesinde de kapatildi' as sonuc;
