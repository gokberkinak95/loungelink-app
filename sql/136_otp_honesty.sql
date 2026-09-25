-- ============================================================
-- LoungeLink · 136_otp_honesty.sql
-- OTP: DOGRULANMAMIS SEYE "DOGRULANDI" DEMEYELIM
--
-- ⚠️ Uygulamayi ETKILER (dogrulama durumu gorunur olur).
--
-- ------------------------------------------------------------
-- DURUM
-- ------------------------------------------------------------
-- `verify_otp` var, `otp_demo_bypass = true` ve gercek bir SMS
-- saglayicisi YOK. Yani bugun "telefon dogrulandi" rozeti,
-- dogrulanmamis bir telefonu dogrulanmis gosteriyor.
--
-- Gokberk hakli olarak "OTP gondermiyoruz galiba" dedi ve e-posta
-- uzerinden yapmayi onerdi. Dogru yol bu — ama SMTP (Brevo) HENUZ
-- KURULMADI. Kurulmadan e-posta OTP'si yazmak, calismayan ikinci
-- bir yol daha eklemek olur.
--
-- 🔴 O YUZDEN ONCE DURUSTLUK: bypass acikken rozet "dogrulandi"
-- DEMEZ, "beta modunda atlandi" der. Guven sinyali, gercekten
-- guven veren bir seye dayanmali; aksi halde guven sinyali degil
-- guven TUZAGIDIR.
--
-- SMTP kurulunca `otp_channel` = 'email' yapilir ve akis gercek
-- calisir; app tarafi hazir bekliyor.
-- ============================================================

insert into beta_settings (key, value) values
  ('otp_channel', to_jsonb('none'::text)),   -- none | email | sms
  ('otp_notice_bypass', to_jsonb(
    'Beta: telefon doğrulaması henüz aktif değil. Numaran kayıtlı ama '
 || 'doğrulanmadı — profilinde bu şekilde görünüyor.'::text))
on conflict (key) do nothing;

-- Dogrulama durumu: "gercekten dogrulandi mi" ayri bir soru
alter table verifications add column if not exists phone_verified_method text
  check (phone_verified_method is null or phone_verified_method in ('sms','email','manual','bypass'));
comment on column verifications.phone_verified_method is
  'Telefon NASIL dogrulandi. bypass = beta modunda atlandi, GERCEK '
  'dogrulama DEGILDIR. Rozet bu alana bakarak konusur.';

-- Bypass ile "dogrulanmis" sayilanlari isaretle
update verifications v set phone_verified_method = 'bypass'
 where v.phone_verified and v.phone_verified_method is null
   and coalesce((select (value #>> '{}')::boolean from beta_settings
                  where key = 'otp_demo_bypass'), false);

create or replace function public.verification_state(p_user uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'phone_verified', coalesce(v.phone_verified, false),
    -- 🔴 GERCEKTEN dogrulanmis mi: bypass sayilmaz.
    'phone_truly_verified',
      coalesce(v.phone_verified, false)
      and coalesce(v.phone_verified_method,'bypass') <> 'bypass',
    'method', v.phone_verified_method,
    'id_verified', coalesce(v.id_verified, false),
    'channel', coalesce((select value #>> '{}' from beta_settings where key = 'otp_channel'), 'none'),
    'notice', case when coalesce(v.phone_verified_method,'') = 'bypass'
                   then (select value #>> '{}' from beta_settings where key = 'otp_notice_bypass') end)
    from verifications v
   where v.user_id = coalesce(p_user, auth.uid());
$$;
grant execute on function public.verification_state(uuid) to authenticated;

select v.phone_verified, v.phone_verified_method, count(*)
  from verifications v group by 1,2 order by 3 desc limit 5;

select '136 OK - bypass artik dogrulanmis gibi gorunmuyor' as sonuc;
