-- =====================================================================
-- 037 · BO'dan doğrulama işaretleme (kalem ikonu akışı)
-- Bağımlılık: 036'dan SONRA. Önce 037a_PRE_drop çalıştır.
--
-- NEDEN: Doğrulamalar (telefon/kimlik/LinkedIn) BO'da salt okunurdu.
-- Gerçek hayatta: kullanıcı kimliğini WhatsApp'tan yolluyor, sen bakıp
-- onaylıyorsun — ama işaretleyecek yer yok. KYC kuyruğu yalnızca
-- uygulama içi belge yüklemesini kapsıyor; elle doğrulama boşluktaydı.
--
-- Güven puanına ETKİSİ VAR: telefon +10, kimlik +18, linkedin +8.
-- O yüzden her değişiklikte recompute_trust çağrılır ve APP ANINDA görür
-- (app trust_scores'u okuyor — ayrı bir kopya yok).
-- =====================================================================

create or replace function public.admin_set_verification(
  p_user uuid, p_field text, p_value boolean
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_score int;
begin
  if p_field not in ('phone_verified','id_verified','linkedin_verified','email_verified') then
    raise exception 'invalid_field';
  end if;

  -- satır yoksa aç
  insert into verifications (user_id) values (p_user) on conflict (user_id) do nothing;

  if p_field = 'phone_verified' then
    update verifications set phone_verified = p_value,
      phone_verified_at = case when p_value then now() else null end,
      updated_at = now() where user_id = p_user;

  elsif p_field = 'id_verified' then
    update verifications set id_verified = p_value,
      id_verified_at = case when p_value then now() else null end,
      id_provider = case when p_value then coalesce(id_provider, 'manual') else id_provider end,
      updated_at = now() where user_id = p_user;

  elsif p_field = 'linkedin_verified' then
    update verifications set linkedin_verified = p_value, updated_at = now() where user_id = p_user;
    -- profiles'ta da ayrı bir linkedin_verified var (trust bunu okuyor) — ikisini eşle
    update profiles set linkedin_verified = p_value, updated_at = now() where user_id = p_user;

  elsif p_field = 'email_verified' then
    update verifications set email_verified = p_value,
      email_verified_at = case when p_value then now() else null end,
      updated_at = now() where user_id = p_user;
  end if;

  -- Güven puanı ANINDA yeniden hesaplanır (033'teki recompute_trust)
  select recompute_trust(p_user) into v_score;
  perform recompute_badge(p_user);

  return jsonb_build_object('ok', true, 'score', v_score);
end $$;
grant execute on function public.admin_set_verification(uuid, text, boolean) to authenticated;

select 'ADMIN VERIFICATIONS OK' as sonuc;
