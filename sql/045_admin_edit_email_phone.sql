-- ============================================================
-- 045 — BO'DAN E-POSTA / TELEFON DÜZENLEME
--
-- 044'ten sonra. PRE_drop gerekmiyor (hepsi yeni).
--
-- GEREKÇE (Gokberk):
-- "Kullanıcı editte de tel nosunu, e-postasını editleyebilsin.
--  Bunu doğrulamaların solundaki Hesap başlığı altındaki
--  bölümden yapabiliriz sanırım."
-- Doğru yer orası: E-posta ve Telefon zaten Hesap kutusunda
-- salt okunur duruyor. Doğrulamalar kutusu bir şeyin DOĞRULANMIŞ
-- olup olmadığını yönetir; değerin KENDİSİ hesaba aittir.
--
-- ============================================================
-- 🔴 E-POSTA NEDEN ÖZEL: İKİ YERDE DURUYOR
-- ============================================================
-- `public.users.email`  -> bizim tablomuz, her yerde okunur
-- `auth.users.email`    -> Supabase Auth, GİRİŞ bunu kullanır
--
-- Yalnız birini güncellersen:
--   · sadece public.users -> BO doğru görünür ama kullanıcı ESKİ
--     e-postasıyla giriş yapmaya devam eder; yenisiyle giremez.
--     Sessiz ve çok kafa karıştırıcı bir hata.
--   · sadece auth.users   -> kullanıcı yeni e-postayla girer ama
--     BO/app her yerde eskisini gösterir.
-- Bu yüzden İKİSİ TEK FONKSİYONDA, tek transaction'da güncellenir.
--
-- ============================================================
-- TELEFON: 026'daki change_phone'un kuralı KORUNUYOR
-- ============================================================
-- Kullanıcı kendi telefonunu değiştirdiğinde (026):
--   · verifications.phone_verified = false
--   · trust_scores.score -= 10, components'tan 'phone' silinir
-- Admin değiştirdiğinde de AYNISI olmalı. Yoksa admin telefonu
-- değiştirir, doğrulama olduğu gibi kalır ve güven puanı
-- DOĞRULANMAMIŞ bir numarayı doğrulanmış sayar — puan yalan söyler.
-- Numaranın sahibi değiştiyse eski doğrulama geçersizdir.
-- ============================================================


create or replace function public.admin_set_email(p_user uuid, p_email text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_old text; v_new text := lower(trim(p_email));
begin
  if v_new is null or v_new = '' then raise exception 'email_required'; end if;
  if v_new !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalid'; end if;

  select email into v_old from users where id = p_user;
  if not found then raise exception 'user_not_found'; end if;
  if v_old = v_new then return jsonb_build_object('ok', true, 'unchanged', true); end if;

  if exists (select 1 from users where lower(email) = v_new and id <> p_user) then
    raise exception 'email_taken';
  end if;

  -- 1) bizim tablo
  update users set email = v_new, updated_at = now() where id = p_user;

  -- 2) 🔴 Auth tablosu — bu satır olmazsa kullanıcı yeni e-postayla GİREMEZ
  update auth.users
     set email = v_new,
         raw_user_meta_data = coalesce(raw_user_meta_data,'{}'::jsonb) || jsonb_build_object('email', v_new),
         updated_at = now()
   where id = p_user;

  -- E-posta değişti: eski adresin doğrulaması artık yeni adresi kanıtlamaz.
  -- (026'daki telefon mantığının e-posta karşılığı.)
  update verifications
     set email_verified = false, email_verified_at = null
   where user_id = p_user;
  update trust_scores
     set score = greatest(0, score - 10),
         components = coalesce(components,'{}'::jsonb) - 'email',
         updated_at = now()
   where user_id = p_user and (coalesce(components,'{}'::jsonb) ? 'email');

  begin
    insert into notifications (user_id, category, icon, title, body)
    values (p_user, 'system', '✉', 'E-posta adresin güncellendi',
            'Hesabının e-postası ' || v_new || ' olarak değiştirildi. Bundan sonra bu adresle giriş yapacaksın.');
  exception when others then null;
  end;

  return jsonb_build_object('ok', true, 'old', v_old, 'new', v_new, 'reverify_required', true);
end $$;


create or replace function public.admin_set_phone(p_user uuid, p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_old text; v_new text := nullif(trim(p_phone), ''); v_e164 text;
begin
  if not exists (select 1 from users where id = p_user) then raise exception 'user_not_found'; end if;
  select phone into v_old from users where id = p_user;

  -- E.164'e kaba normalize: yalnız rakam + baştaki +
  if v_new is not null then
    v_e164 := regexp_replace(v_new, '[^0-9+]', '', 'g');
    if v_e164 !~ '^\+?[0-9]{7,15}$' then raise exception 'phone_invalid'; end if;
    if left(v_e164,1) <> '+' then v_e164 := '+' || v_e164; end if;
    if exists (select 1 from users where phone_e164 = v_e164 and id <> p_user) then
      raise exception 'phone_taken';
    end if;
  end if;

  update users set phone = v_new, phone_e164 = v_e164, updated_at = now() where id = p_user;

  -- 026 change_phone ile AYNI kural: numara değişti -> doğrulama düşer, -10 güven
  update verifications
     set phone_verified = false, phone_verified_at = null
   where user_id = p_user;
  update trust_scores
     set score = greatest(0, score - 10),
         components = coalesce(components,'{}'::jsonb) - 'phone',
         updated_at = now()
   where user_id = p_user and (coalesce(components,'{}'::jsonb) ? 'phone');

  begin
    insert into notifications (user_id, category, icon, title, body)
    values (p_user, 'system', '📱', 'Telefon numaran güncellendi',
            'Numaran değiştiği için tekrar doğrulaman gerekiyor.');
  exception when others then null;
  end;

  return jsonb_build_object('ok', true, 'old', v_old, 'new', v_new,
                            'e164', v_e164, 'reverify_required', true);
end $$;


-- YALNIZ service_role (BO). Bir kullanıcı başkasının e-postasını değiştiremez.
revoke all on function public.admin_set_email(uuid, text) from public, authenticated;
revoke all on function public.admin_set_phone(uuid, text) from public, authenticated;
grant execute on function public.admin_set_email(uuid, text) to service_role;
grant execute on function public.admin_set_phone(uuid, text) to service_role;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select 'admin_set_email' as fonksiyon,
  case when exists (select 1 from pg_proc where proname='admin_set_email') then '✓' else '🔴 YOK' end as durum
union all select 'admin_set_phone',
  case when exists (select 1 from pg_proc where proname='admin_set_phone') then '✓' else '🔴 YOK' end
union all select 'admin_set_email auth.users yaziyor',
  case when (select prosrc from pg_proc where proname='admin_set_email' limit 1) like '%auth.users%'
  then '✓ OK' else '🔴 HAYIR — kullanici giremez!' end
union all
-- public.users ile auth.users e-postalari UYUMLU mu? (0 olmali)
select 'uyumsuz e-posta (0 OLMALI)',
  (select count(*)::text from users u join auth.users au on au.id = u.id
    where lower(u.email) <> lower(au.email));
