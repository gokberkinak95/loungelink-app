-- ============================================================
-- LoungeLink · 002_seed_reference.sql
-- Havalimanı + lounge referans verileri (MVP kataloğu + genişletme)
-- ============================================================

insert into airports (code, name, city, country, timezone) values
  ('IST', 'Istanbul Airport',            'Istanbul',  'Türkiye', 'Europe/Istanbul'),
  ('SAW', 'Sabiha Gökçen Airport',       'Istanbul',  'Türkiye', 'Europe/Istanbul'),
  ('ESB', 'Esenboğa Airport',            'Ankara',    'Türkiye', 'Europe/Istanbul'),
  ('ADB', 'Adnan Menderes Airport',      'Izmir',     'Türkiye', 'Europe/Istanbul'),
  ('AYT', 'Antalya Airport',             'Antalya',   'Türkiye', 'Europe/Istanbul'),
  ('LHR', 'Heathrow Airport',            'London',    'United Kingdom', 'Europe/London'),
  ('FRA', 'Frankfurt Airport',           'Frankfurt', 'Germany', 'Europe/Berlin'),
  ('CDG', 'Charles de Gaulle Airport',   'Paris',     'France',  'Europe/Paris'),
  ('AMS', 'Schiphol Airport',            'Amsterdam', 'Netherlands', 'Europe/Amsterdam'),
  ('DXB', 'Dubai International Airport', 'Dubai',     'UAE',     'Asia/Dubai'),
  ('DOH', 'Hamad International Airport', 'Doha',      'Qatar',   'Asia/Qatar'),
  ('JFK', 'John F. Kennedy Airport',     'New York',  'USA',     'America/New_York')
on conflict (code) do nothing;

insert into lounges (airport_code, name, terminal, access_types) values
  -- IST
  ('IST', 'Primeclass Lounge',            'Main T - Gate A',  array['Priority Pass','LoungeKey','Day Pass']),
  ('IST', 'IGA Lounge',                   'Main T - Gate E',  array['Priority Pass','Business Class','Day Pass']),
  ('IST', 'Turkish Airlines Lounge Business', 'Main T - Gate D', array['Business Class','Miles&Smiles Elite']),
  ('IST', 'Turkish Airlines Lounge Miles&Smiles', 'Main T - Gate F', array['Miles&Smiles Elite','Credit Card']),
  -- SAW
  ('SAW', 'Primeclass Lounge',            'Int. Terminal',    array['Priority Pass','LoungeKey','Day Pass']),
  ('SAW', 'Aeroport Lounge',              'Dom. Terminal',    array['Priority Pass','Credit Card']),
  -- ESB
  ('ESB', 'Primeclass CIP Lounge',        'Int. Terminal',    array['Priority Pass','Business Class']),
  ('ESB', 'Anatolia Lounge',              'Dom. Terminal',    array['Priority Pass','Credit Card']),
  -- ADB
  ('ADB', 'Primeclass Lounge',            'Int. Terminal',    array['Priority Pass','Day Pass']),
  -- AYT
  ('AYT', 'Antalya Airport CIP Lounge',   'T1 International', array['Priority Pass','Day Pass']),
  -- LHR
  ('LHR', 'Plaza Premium Lounge',         'T2',               array['Priority Pass','Day Pass']),
  ('LHR', 'No1 Lounge',                   'T3',               array['Priority Pass','LoungeKey','Day Pass']),
  ('LHR', 'Turkish Airlines Lounge',      'T2',               array['Business Class','Miles&Smiles Elite']),
  -- FRA
  ('FRA', 'LuxxLounge',                   'T1 - A',           array['Priority Pass','Day Pass']),
  ('FRA', 'Sky Lounge',                   'T2 - D/E',         array['Priority Pass','LoungeKey']),
  -- CDG
  ('CDG', 'Extime Lounge',                'T2E',              array['Priority Pass','Day Pass']),
  -- AMS
  ('AMS', 'Aspire Lounge 26',             'Lounge 26 (Non-Schengen)', array['Priority Pass','LoungeKey','Day Pass']),
  -- DXB
  ('DXB', 'Marhaba Lounge',               'T3 - B',           array['Priority Pass','LoungeKey','Day Pass']),
  ('DXB', 'Ahlan Lounge',                 'T1 - C',           array['Priority Pass','Day Pass']),
  -- DOH
  ('DOH', 'Oryx Lounge',                  'North Node',       array['Priority Pass','Day Pass']),
  -- JFK
  ('JFK', 'Primeclass Lounge',            'T1',               array['Priority Pass','LoungeKey','Day Pass'])
on conflict do nothing;

-- Doğrulama
select a.code, a.city, count(l.id) as lounge_sayisi
from airports a
left join lounges l on l.airport_code = a.code
group by a.code, a.city
order by a.code;
