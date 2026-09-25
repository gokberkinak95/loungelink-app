-- ============================================================
-- LoungeLink · 117_carrier_field.sql
-- HAVAYOLU ARTIK SORULUYOR — KURAL MOTORUNUN EN BUYUK KOR NOKTASI
--
-- ⚠️ Uygulamayi ETKILER. Yeni katalog + RPC imzalari genisliyor.
--
-- ------------------------------------------------------------
-- 🔴 SORUN: KURALLARIMIZ HAVAYOLUNA DAYANIYOR AMA SORMUYORUZ
-- ------------------------------------------------------------
-- Kural motorunun en kritik iki maddesi tasiyiciya bagli:
--   · THY md.17: "THY yolcusu SADECE THY yolcusunu misafir edebilir;
--     AJet yolcusunu EDEMEZ."
--   · AJet: "misafirin de AJet seferinde olmasi gerekir."
--
-- Bugune kadar tasiyiciyi UCUS NUMARASINDAN TAHMIN ediyorduk:
-- "TK712" -> TK. Ama bu tahmin uc yerde kiriliyor:
--   1. Kullanici "712" yazarsa tasiyici BILINMIYOR.
--   2. AJet'in kodu VF; "AJ1876" yazan kullanici (ki cogu boyle yazar)
--      hicbir tasiyiciya eslesmiyor.
--   3. Ortak sefer (codeshare): TK ile satilan bir ucus baska bir
--      havayolu tarafindan islenebiliyor.
--
-- Yani en kritik kuralimizi TAHMINE dayandirmisiz. Sormak, tahmin
-- etmekten her zaman ucuzdur — ozellikle cevabi kullanici zaten biliyorsa.
-- ============================================================

create table if not exists carriers (
  code        text primary key,          -- IATA
  name        text not null,
  icao        text,
  country     text,
  alliance    text,                      -- star_alliance | oneworld | skyteam | null
  is_lowcost  boolean default false,
  sort_order  int default 100,
  active      boolean default true,
  created_at  timestamptz default now()
);
comment on table carriers is
  'Ucus tasiyicilari. Kural motoru "misafir ayni havayolunda mi" sorusunu '
  'BUNA bakarak yanitlar; ucus numarasindan tahmin etmez.';

insert into carriers (code, name, icao, country, alliance, is_lowcost, sort_order) values
  -- 🔴 TURK HAVAYOLLARI ONCE. Kullanicilarimizin neredeyse tamami bu
  -- listeden secer; alfabetik siralama onlari asagi iterdi.
  ('TK','Türk Hava Yolları','THY','TR','star_alliance', false, 1),
  ('VF','AJet','AJT','TR', null, true, 2),
  ('PC','Pegasus','PGT','TR', null, true, 3),
  ('XQ','SunExpress','SXS','TR', null, true, 4),
  ('XC','Corendon Airlines','CAI','TR', null, true, 5),
  ('8Q','Onur Air','OHY','TR', null, true, 6),
  ('KK','AtlasGlobal','KKK','TR', null, true, 7),
  -- Turkiye''ye en cok ucan yabanci havayollari
  ('LH','Lufthansa','DLH','DE','star_alliance', false, 20),
  ('LX','SWISS','SWR','CH','star_alliance', false, 21),
  ('OS','Austrian Airlines','AUA','AT','star_alliance', false, 22),
  ('SN','Brussels Airlines','BEL','BE','star_alliance', false, 23),
  ('A3','Aegean','AEE','GR','star_alliance', false, 24),
  ('BA','British Airways','BAW','GB','oneworld', false, 30),
  ('QR','Qatar Airways','QTR','QA','oneworld', false, 31),
  ('AA','American Airlines','AAL','US','oneworld', false, 32),
  ('IB','Iberia','IBE','ES','oneworld', false, 33),
  ('AF','Air France','AFR','FR','skyteam', false, 40),
  ('KL','KLM','KLM','NL','skyteam', false, 41),
  ('SU','Aeroflot','AFL','RU','skyteam', false, 42),
  ('EK','Emirates','UAE','AE', null, false, 50),
  ('EY','Etihad','ETD','AE', null, false, 51),
  ('W6','Wizz Air','WZZ','HU', null, true, 60),
  ('FR','Ryanair','RYR','IE', null, true, 61),
  ('U2','easyJet','EZY','GB', null, true, 62),
  ('OTHER','Diğer havayolu', null, null, null, false, 999)
on conflict (code) do update set
  name = excluded.name, alliance = excluded.alliance,
  is_lowcost = excluded.is_lowcost, sort_order = excluded.sort_order;

-- Ucus numarasindan tasiyici cikarimi — ARTIK YALNIZ YARDIMCI
create or replace function public.carrier_from_flight(p_flight text)
returns text language sql stable as $$
  -- 🔴 Bu fonksiyon artik TEK KAYNAK DEGIL, yalniz bir ONERI.
  -- Kullanici tasiyiciyi secmediyse tahminde bulunuruz ama kararin
  -- dayanagi olmaz. "AJ" gibi yaygin ama YANLIS yazimlar da eslenir:
  -- AJet'in gercek IATA kodu VF, ama kullanicilar AJ yaziyor.
  select case
    when coalesce(p_flight,'') = '' then null
    when upper(p_flight) like 'AJ%' then 'VF'
    else (select c.code from carriers c
           where c.active and c.code <> 'OTHER'
             and upper(replace(p_flight,' ','')) like c.code || '%'
           order by length(c.code) desc limit 1)
  end;
$$;
grant execute on function public.carrier_from_flight(text) to authenticated;

alter table availabilities add column if not exists carrier_code text references carriers(code);
alter table visits         add column if not exists carrier_code text references carriers(code);

-- Mevcut kayitlar icin tahminle doldur (bir kez)
update availabilities set carrier_code = public.carrier_from_flight(flight_number)
 where carrier_code is null and coalesce(flight_number,'') <> '';
update visits set carrier_code = public.carrier_from_flight(flight_number)
 where carrier_code is null and coalesce(flight_number,'') <> '';

create or replace function public.carrier_options()
returns table (code text, name text, alliance text, is_lowcost boolean)
language sql stable security definer set search_path = public as $$
  select c.code, c.name, c.alliance, c.is_lowcost
    from carriers c where c.active
   order by c.sort_order, c.name;
$$;
grant execute on function public.carrier_options() to authenticated;

-- Ilan ve seyahat kaydinda tasiyiciyi isaretle (imzalara dokunmadan)
create or replace function public.set_availability_carrier(p_avail_id uuid, p_carrier text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if (select host_id from availabilities where id = p_avail_id) <> auth.uid() then
    raise exception 'not_owner';
  end if;
  update availabilities set carrier_code = nullif(p_carrier,'') where id = p_avail_id;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.set_availability_carrier(uuid, text) to authenticated;

create or replace function public.set_visit_carrier(p_visit_id uuid, p_carrier text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if (select user_id from visits where id = p_visit_id) <> auth.uid() then
    raise exception 'not_owner';
  end if;
  update visits set carrier_code = nullif(p_carrier,'') where id = p_visit_id;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.set_visit_carrier(uuid, text) to authenticated;

select code, name, alliance from carriers where active order by sort_order limit 8;
select '117 OK - havayolu katalogu kuruldu' as sonuc;
