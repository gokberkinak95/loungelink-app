-- ============================================================
-- LoungeLink · 073_fix_seed_login.sql
--
-- 🔴 SEED HESAPLARINA GİRİLEMİYOR — kesin teşhis:
-- SEED, auth.users'a yalnızca (id, email, raw_user_meta_data) yazıp
-- sonra şifreyi güncelliyordu. Supabase'in auth servisi (GoTrue) için
-- bu satırlar KULLANILAMAZ durumda:
--
--   1) instance_id NULL  -> GoTrue kullanıcıyı e-postayla ararken
--      "where instance_id = ..." kullanır; satır HİÇ BULUNMAZ.
--      Sonuç: "Invalid login credentials" (şifre doğru olsa bile).
--   2) aud / role NULL   -> token üretimi bozulur.
--   3) email_confirmed_at NULL -> bulunsa bile "Email not confirmed".
--   4) confirmation_token, recovery_token, email_change... gibi metin
--      kolonları NULL -> GoTrue (Go) NULL'u string'e tarayamaz,
--      500 "Database error querying schema" döner.
--   5) auth.identities satırı YOK -> 'email' sağlayıcı kimliği eksik.
--
-- Yani app'te "mail+şifre doğru ama login ekranına geri dönüyorum"
-- davranışının sebebi app DEĞİL; auth satırlarının kendisi.
-- (SEED'deki "e-posta doğrulaması otomatik onaylandı" notu YANLIŞTI —
-- benim hatam: doğrulama hiç yazılmamıştı.)
--
-- BU DOSYA: yalnızca @seed.loungelink.test hesaplarını onarır.
-- Gerçek kullanıcılara DOKUNMAZ. Tekrar çalıştırılabilir (idempotent).
-- Şifre değişmez: Seed1234!
-- ============================================================

-- ---- 1) auth.users satırlarını GoTrue'nun beklediği hale getir ----
update auth.users set
  instance_id                = coalesce(instance_id, '00000000-0000-0000-0000-000000000000'::uuid),
  aud                        = coalesce(aud, 'authenticated'),
  role                       = coalesce(role, 'authenticated'),
  email_confirmed_at         = coalesce(email_confirmed_at, now()),
  created_at                 = coalesce(created_at, now()),
  updated_at                 = coalesce(updated_at, now()),
  raw_app_meta_data          = coalesce(raw_app_meta_data,
                                 '{"provider":"email","providers":["email"]}'::jsonb),
  confirmation_token         = coalesce(confirmation_token, ''),
  recovery_token             = coalesce(recovery_token, ''),
  email_change               = coalesce(email_change, ''),
  email_change_token_new     = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change               = coalesce(phone_change, ''),
  phone_change_token         = coalesce(phone_change_token, ''),
  reauthentication_token     = coalesce(reauthentication_token, ''),
  is_sso_user                = coalesce(is_sso_user, false)
where email like '%@seed.loungelink.test';

-- ---- 2) 'email' sağlayıcı kimliği (auth.identities) ----
-- Yeni şemada provider_id kolonu var; eski şemada yok. İkisini de destekle.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='identities'
                and column_name='provider_id') then
    insert into auth.identities (user_id, provider_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    select u.id, u.id::text,
           jsonb_build_object('sub', u.id::text, 'email', u.email,
                              'email_verified', true, 'phone_verified', false),
           'email', now(), now(), now()
      from auth.users u
     where u.email like '%@seed.loungelink.test'
       and not exists (select 1 from auth.identities i
                        where i.user_id = u.id and i.provider = 'email');
  else
    insert into auth.identities (id, user_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    select u.id::text, u.id,
           jsonb_build_object('sub', u.id::text, 'email', u.email,
                              'email_verified', true),
           'email', now(), now(), now()
      from auth.users u
     where u.email like '%@seed.loungelink.test'
       and not exists (select 1 from auth.identities i
                        where i.user_id = u.id and i.provider = 'email');
  end if;
end $$;

-- ---- DOĞRULAMA ----
-- Her satır: onarildi=true ve kimlik_var=true dönmeli (8 satır)
select u.email,
       (u.instance_id is not null
        and u.aud = 'authenticated'
        and u.email_confirmed_at is not null
        and u.confirmation_token is not null) as onarildi,
       exists (select 1 from auth.identities i
                where i.user_id = u.id and i.provider = 'email') as kimlik_var
  from auth.users u
 where u.email like '%@seed.loungelink.test'
 order by u.email;

select '073 OK - seed hesaplari onarildi, Seed1234! ile giris yapilabilir' as sonuc;
