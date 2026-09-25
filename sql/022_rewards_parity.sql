-- LoungeLink · 022_rewards_parity.sql — MVP'deki 8 ödüle tamamla
insert into rewards (title, subtitle, category, cost_points, sort_order) values
  ('Emirates Skywards 750 Mil', 'Mil transferi', 'miles', 1200, 7),
  ('Marriott Bonvoy 20$ Kredi', 'Bonvoy otelleri', 'hotel', 1200, 8)
on conflict do nothing;
select 'REWARDS PARITY OK' as sonuc;
