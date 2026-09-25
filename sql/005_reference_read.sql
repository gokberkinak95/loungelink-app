-- LoungeLink · 005_reference_read.sql
-- Havalimanı/lounge kataloğunu girişli kullanıcılara okumaya aç
alter table airports enable row level security;
alter table lounges enable row level security;
drop policy if exists "airports_read" on airports;
create policy "airports_read" on airports for select to authenticated using (true);
drop policy if exists "lounges_read" on lounges;
create policy "lounges_read" on lounges for select to authenticated using (active = true);
select 'OK' as sonuc;
