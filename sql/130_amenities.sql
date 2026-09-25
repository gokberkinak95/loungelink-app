-- ============================================================
-- LoungeLink · 130_amenities.sql
-- SALON OLANAKLARI — "ICERIDE DUS VAR MI?"
--
-- ⚠️ Uygulamayi ETKILER (yeni kolon + RPC).
--
-- ------------------------------------------------------------
-- NEDEN
-- ------------------------------------------------------------
-- Rakip incelemesinde en carpici eksigimiz buydu: kurali kusursuz
-- biliyoruz ama misafirin GERCEKTEN merak ettigi seyi bilmiyoruz.
-- "Girebilir miyim" sorusunun cevabini veriyoruz; "girince ne var"
-- sorusuna susuyoruz.
--
-- Ustelik veriyi ZATEN TOPLADIK: havalimani sayfalarindan aldigimiz
-- ekran goruntulerinde olanaklar tek tek yaziyordu (dus, mescit,
-- cocuk oyun alani, sinema, bilardo, pide istasyonu...). Onlari
-- gecerken okuyup atmisim.
--
-- 🔴 KOLON DEGIL JSONB: yeni bir olanak cikinca (ornegin "pide
-- istasyonu") sema degistirmek gerekmesin. Standart anahtarlar
-- app'te ikonla, digerleri metin olarak gosterilir.
-- ============================================================

alter table lounge_venues add column if not exists amenities jsonb default '{}'::jsonb;
comment on column lounge_venues.amenities is
  'Salon olanaklari. Standart anahtarlar app''te ikonla gosterilir: '
  'wifi, food, bar, shower, sleep, kids, prayer, work, tv, terrace, '
  'buffet, cinema, games, luggage, nursery. Ekstralar `extra` dizisinde.';

-- ---- IST (istairport.com ekran goruntulerinden) ----
update lounge_venues set amenities = '{
  "wifi": true, "food": true, "buffet": true, "bar": true, "shower": true,
  "sleep": true, "kids": true, "prayer": true, "work": true, "cinema": true,
  "games": true, "extra": ["Kütüphane", "PressReader", "Özel suite odalar", "Toplantı odaları"]
}'::jsonb
 where airport_code = 'IST' and lower(name) like '%turkish airlines%'
   and coalesce(scope,'') = 'international';

update lounge_venues set amenities = '{
  "wifi": true, "food": true, "buffet": true, "bar": true, "kids": true,
  "work": true, "games": true,
  "extra": ["Toplantı odaları", "PressReader", "Apron otobüsüyle doğrudan uçağa biniş"]
}'::jsonb
 where airport_code = 'IST' and lower(name) like '%turkish airlines%'
   and coalesce(scope,'') = 'domestic';

-- iGA Dis Hat: en zengin liste
update lounge_venues set amenities = '{
  "wifi": true, "food": true, "buffet": true, "bar": true, "shower": true,
  "kids": true, "prayer": true, "work": true, "tv": true, "terrace": true,
  "luggage": true, "nursery": true, "games": true,
  "extra": ["Duty free alanı", "Bilardo", "Şefli pişirme istasyonu", "Pide istasyonu",
            "Alkolsüz alan", "Çocuklara özel tuvalet", "Abdest alanları"]
}'::jsonb
 where airport_code = 'IST' and lower(name) like '%iga lounge%'
   and coalesce(scope,'') = 'international';

update lounge_venues set amenities = '{
  "wifi": true, "food": true, "buffet": true, "bar": true, "work": true, "tv": true,
  "extra": ["Bilgisayar ve yazıcı imkânı sunan çalışma köşesi"]
}'::jsonb
 where airport_code = 'IST' and lower(name) like '%iga lounge%'
   and coalesce(scope,'') = 'domestic';

-- ---- SAW Plaza Premium (sabihagokcen.aero) ----
update lounge_venues set amenities = '{
  "wifi": true, "food": true, "bar": true, "tv": true, "kids": true, "terrace": true,
  "work": true,
  "extra": ["AeroBar", "Şarj istasyonu", "Uçuş bilgi ekranı", "Vejetaryen ikramlar"]
}'::jsonb
 where airport_code = 'SAW' and lower(name) like '%plaza premium%';

-- ---- Kalanlar icin makul taban ----
-- 🔴 UYDURMUYORUZ: yalniz her salonda fiilen bulunan iki sey.
-- Bilmedigimiz olanagi "var" diye yazmak, kuralda yapmadigimiz
-- hatayi olanakta yapmak olurdu.
update lounge_venues
   set amenities = '{"wifi": true, "food": true}'::jsonb
 where venue_kind = 'lounge' and coalesce(amenities, '{}'::jsonb) = '{}'::jsonb;

create or replace function public.venue_amenities(p_lounge_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(v.amenities, '{}'::jsonb)
    from lounges l join lounge_venues v on v.id = l.venue_id
   where l.id = p_lounge_id;
$$;
grant execute on function public.venue_amenities(uuid) to authenticated;

-- Kesif listesine olanaklari da tasi (tek sorguda)
create or replace function public.amenities_for(p_ids uuid[])
returns table (avail_id uuid, amenities jsonb)
language sql stable security definer set search_path = public as $$
  select a.id, coalesce(v.amenities, '{}'::jsonb)
    from availabilities a
    left join lounges l on l.id = a.lounge_id
    left join lounge_venues v on v.id = l.venue_id
   where a.id = any (coalesce(p_ids, '{}'::uuid[]));
$$;
grant execute on function public.amenities_for(uuid[]) to authenticated;

select v.airport_code, left(v.name,32) salon,
       (select count(*) from jsonb_each(v.amenities) where jsonb_typeof(value) = 'boolean') as olanak
  from lounge_venues v where v.active and v.venue_kind = 'lounge'
 order by olanak desc limit 8;

select '130 OK - olanaklar girildi' as sonuc;
