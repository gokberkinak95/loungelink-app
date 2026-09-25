-- ============================================================
-- LoungeLink · 010_profile_write.sql — Profil sahibi kendi profilini düzenler
-- ============================================================
drop policy if exists "profiles_self_update" on profiles;
create policy "profiles_self_update" on profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

select 'PROFILE WRITE OK' as sonuc;
