-- ============================================================
-- LoungeLink · 160_catalog_name_dedupe.sql
-- CİHAZDA GÖRÜLDÜ (13 Ağu): Yayın'daki salon seçicide
-- "Turkish Airlines Lounge — İç Hat" İKİ KEZ listelendi.
--
-- 158'in uzlaştırması VENUE bazlıydı: venue başına tek aktif
-- kayıt bırakır. Ama iki AYRI venue aynı görünen adı taşıyorsa
-- (ya da eski imla varyantı ayrı venue'ya bağlıysa) kullanıcı
-- yine çift kayıt görür — teknik olarak tekil, gözle mükerrer.
-- Kullanıcının gördüğü liste İSİMLERDEN oluşur; tekillik de
-- İSİM DÜZEYİNDE sağlanmalı.
--
-- Kural: aynı havalimanında aynı normalize edilmiş ada sahip
-- birden çok AKTİF kayıttan yalnız biri kalır (venue bağlı olan
-- ve en yenisi tercih edilir). Kayıt SİLİNMEZ (geçmiş ilan
-- referansları kırılmaz), pasife çekilir.
-- ============================================================

do $$
declare n int;
begin
  with ranked as (
    select l.id,
           row_number() over (
             partition by l.airport_code,
                          lower(regexp_replace(translate(l.name,
                            'İıŞşĞğÜüÖöÇç', 'IiSsGgUuOoCc'), '\s+', ' ', 'g'))
             order by (l.venue_id is not null) desc, l.id desc
           ) rn
      from lounges l
     where l.active)
  update lounges set active = false
   where id in (select id from ranked where rn > 1);
  get diagnostics n = row_count;
  raise notice '160: % isim mükerreri pasife çekildi', n;
end $$;

-- BEKÇİ: aktif katalogda isim düzeyinde mükerrer kalamaz.
do $$
declare n int;
begin
  select count(*) into n from (
    select 1 from lounges
     where active
     group by airport_code,
              lower(regexp_replace(translate(name,
                'İıŞşĞğÜüÖöÇç', 'IiSsGgUuOoCc'), '\s+', ' ', 'g'))
     having count(*) > 1) x;
  if n > 0 then
    raise exception '160: % havalimanı+isim çiftinde hâlâ birden çok aktif kayıt var', n;
  end if;
end $$;

select '160 OK - katalog isim duzeyinde tekil' as sonuc;
