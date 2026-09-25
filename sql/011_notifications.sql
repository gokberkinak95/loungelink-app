-- ============================================================
-- LoungeLink · 011_notifications.sql — Bildirim okuma + okundu işaretleme
-- ============================================================
alter table notifications enable row level security;

drop policy if exists "notif_own_read" on notifications;
create policy "notif_own_read" on notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notif_own_update" on notifications;
create policy "notif_own_update" on notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Realtime: yeni bildirim anında düşsün (zil rozeti canlı güncellensin)
alter publication supabase_realtime add table notifications;

select 'NOTIFICATIONS OK' as sonuc;
