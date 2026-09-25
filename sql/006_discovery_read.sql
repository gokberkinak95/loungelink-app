-- LoungeLink · 006_discovery_read.sql
-- Keşif ekranı: host profilleri ve güven puanları girişli kullanıcılara okunabilir olmalı.
-- (users tablosu AÇILMIYOR — e-postalar gizli kalır. Kadın güvenlik modu görünürlük
--  filtreleri Faz 1'in ilerleyen adımında uygulama+policy katmanına eklenecek.)
drop policy if exists "profiles_read_auth" on profiles;
create policy "profiles_read_auth" on profiles
  for select to authenticated using (true);

drop policy if exists "trust_read_auth" on trust_scores;
create policy "trust_read_auth" on trust_scores
  for select to authenticated using (true);

select 'OK' as sonuc;
