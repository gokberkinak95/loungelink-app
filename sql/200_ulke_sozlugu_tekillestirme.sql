-- ============================================================
-- 200 · ÜLKE SÖZLÜĞÜ TEKİLLEŞTİRME
-- 17 Ağustos 2026
--
-- ⚠️ Uygulamayı ETKİLEMEZ (kural motoru zaten iki yazımı da tanıyor);
-- SİTE KAPSAMINI ve her ülke bazlı raporu etkiler.
--
-- ------------------------------------------------------------
-- 🔴 ÖLÇÜM: TÜRKİYE İKİ KEZ VAR
-- ------------------------------------------------------------
-- `airports.country` içinde aynı ülke İKİ FARKLI yazımla duruyordu:
--     'Türkiye' × 12   ·   'TR' × 3   (ADA, DIY, DLM)
-- Kural motoru bundan zarar görmüyor çünkü resolve_guest_rule dört
-- yazımı birden tanıyor ('', TR, Türkiye, Turkiye, Turkey). Ama ülkeye
-- göre GRUPLAYAN her şey bozuluyor:
--   · site "119 ülke" diyor — gerçekte 118, Türkiye iki kez sayılmış
--   · site "Türkiye: 12 havalimanı" diyor — gerçekte 15
--   · Adana, Diyarbakır ve Dalaman YURT DIŞI listesine düşüyor
--
-- Bu, projedeki en sık tekrarlayan sınıfın yeni bir örneği:
-- 🔴 "BİR KOD SÖZLÜĞÜNE İKİNCİ BİR YAZIM GİRDİĞİ AN, O SÖZLÜK BOZULUR."
-- (ELITE_PLUS↔ELPL · AJ↔VF · carrier↔carrier_code · şimdi TR↔Türkiye.)
-- Motorun "ikisini de tanıması" çözüm değil, semptomu gizlemek: tanıyan
-- yer bir tane, gruplayan yer beş tane.
-- ============================================================

-- ---- 1) TEKİLLEŞTİR ----
update airports set country = 'Türkiye'
 where country in ('TR', 'Turkiye', 'Turkey', 'TUR');

-- Yaygın ikinci yazımlar (ileride girerse diye kanonik listeye çekiliyor)
update airports set country = 'ABD'      where country in ('US', 'USA', 'United States');
update airports set country = 'Almanya'  where country in ('DE', 'Germany');
update airports set country = 'Fransa'   where country in ('FR', 'France');

-- ---- 2) KANONİK SÖZLÜK ----
-- 🔴 Tekilleştirmek yetmez: yarın yine iki yazım girebilir. Sözlüğü
-- tabloya yazıp bir kısıtla bağlıyoruz ki "ikinci yazım" bir daha
-- sessizce içeri giremesin.
create table if not exists country_aliases (
  alias     text primary key,
  canonical text not null
);

insert into country_aliases (alias, canonical) values
  ('TR','Türkiye'), ('Turkiye','Türkiye'), ('Turkey','Türkiye'), ('TUR','Türkiye'),
  ('US','ABD'), ('USA','ABD'), ('United States','ABD'),
  ('DE','Almanya'), ('Germany','Almanya'),
  ('FR','Fransa'), ('France','Fransa'),
  ('GB','Birleşik Krallık (İngiltere)'), ('UK','Birleşik Krallık (İngiltere)')
on conflict (alias) do update set canonical = excluded.canonical;

-- Yazma anında kanona çeken tetikleyici. 🔴 THROW ETMEZ: havalimanı
-- kaydı kritik, ülke yazımı bir düzeltme. Bilinmeyen bir ülke adı
-- olduğu gibi kabul edilir (dünyada bilmediğimiz ülke yok değil).
create or replace function public.trg_airport_country_canon()
returns trigger language plpgsql as $$
declare v_c text;
begin
  begin
    select ca.canonical into v_c from country_aliases ca
     where lower(btrim(ca.alias)) = lower(btrim(coalesce(new.country,'')));
    if v_c is not null then new.country := v_c; end if;
  exception when others then
    null;
  end;
  return new;
end $$;

drop trigger if exists trg_airport_country on airports;
create trigger trg_airport_country before insert or update of country on airports
  for each row execute function public.trg_airport_country_canon();


-- ---- 3) SİTE/BO İÇİN KAPSAM ÖZETİ (tek kaynak) ----
-- Site bugüne kadar sayıları CSV'den türetiyordu ve CSV donmuştu.
-- Artık aynı soruyu veritabanına soran tek bir fonksiyon var; site
-- üreteci de BO da bunu okuyabilir.
create or replace function public.coverage_summary()
returns table (havalimani int, salon int, ulke int, tr_havalimani int, tr_salon int)
language sql stable security definer set search_path = public as $$
  with v as (
    select vv.airport_code, ap.country
      from lounge_venues vv
      join airports ap on ap.code = vv.airport_code
     where vv.active and vv.venue_kind = 'lounge' and vv.section_of is null
  )
  select count(distinct airport_code)::int,
         count(*)::int,
         count(distinct country)::int,
         count(distinct airport_code) filter (where country = 'Türkiye')::int,
         count(*) filter (where country = 'Türkiye')::int
    from v
$$;
grant execute on function public.coverage_summary() to authenticated, anon;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) AYNI ÜLKE İKİ YAZIMLA DURMAMALI
do $$
declare v_n int; r record;
begin
  select count(*) into v_n
    from airports a
    join country_aliases ca on lower(btrim(ca.alias)) = lower(btrim(a.country));
  if v_n > 0 then
    for r in select distinct a.country from airports a
              join country_aliases ca on lower(btrim(ca.alias)) = lower(btrim(a.country))
    loop raise notice '198: kanonik olmayan ulke → %', r.country; end loop;
    raise exception '200: % havalimaninda ulke adi KANONIK DEGIL', v_n;
  end if;
  raise notice '200: ulke sozlugu tekil — takma ad kullanan havalimani yok';
end $$;

-- 2) TETİKLEYİCİ GERÇEKTEN ÇEVİRİYOR MU (mutasyon)
do $$
declare v_c text;
begin
  update airports set country = 'TR' where code = 'ADA';
  select country into v_c from airports where code = 'ADA';
  if v_c <> 'Türkiye' then
    raise exception '200: tetikleyici TR→Türkiye cevirmedi (gelen %)', v_c;
  end if;
  raise notice '200: yazma aninda kanona cekiliyor (TR → Türkiye)';
end $$;

-- 3) TÜRKİYE KAPSAMI GERÇEK SAYIYI SÖYLÜYOR
do $$
declare r record;
begin
  select * into r from public.coverage_summary();
  if r.tr_havalimani < 15 then
    raise exception '200: Turkiye kapsami % havalimani (en az 15 bekleniyor)', r.tr_havalimani;
  end if;
  raise notice '200: kapsam — % havalimani / % salon / % ulke · Turkiye %/%',
    r.havalimani, r.salon, r.ulke, r.tr_havalimani, r.tr_salon;
end $$;

select '200 OK - ulke sozlugu tekillestirildi, kapsam ozeti tek kaynaktan' as sonuc;
