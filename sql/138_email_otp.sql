-- ============================================================
-- LoungeLink · 138_email_otp.sql
-- E-POSTA OTP: NE DOGRULADIGIMIZI DOGRU ADLANDIR
--
-- ⚠️ Uygulamayi ETKILER (dogrulama akisi + rozet dili).
--
-- ------------------------------------------------------------
-- 🔴 KRITIK AYRIM
-- ------------------------------------------------------------
-- SMTP kuruldu, artik e-postayla kod gonderebiliyoruz. Ama sunu
-- karistirmamak gerek:
--
--   E-postaya kod gonderip dogrulamak = HESAP SAHIBI BURADA
--   Telefona kod gonderip dogrulamak  = BU NUMARA ONUN
--
-- Ikisi FARKLI seyler. E-posta koduyla telefon numarasini
-- "dogrulanmis" saymak, 136'da temizledigimiz hatanin daha kibar
-- bir surumu olur: kullanicinin girdigi numara hala dogrulanmamis,
-- ama rozet dogrulanmis diyor.
--
-- Dogru kurgu:
--   · E-posta dogrulanir  -> guven sinyali: "E-posta dogrulandi ✓"
--   · Telefon BEYAN edilir -> "Telefon eklendi" (dogrulanmadi)
--   · SMS saglayicisi gelince telefon da gercekten dogrulanir
--
-- Kullanici acisindan kayip yok: e-posta dogrulamasi da gercek bir
-- guven sinyali — hesabin sahibi oldugunu kanitliyor. Yalnizca
-- DOGRU ADLA anlatiyoruz.
-- ============================================================

alter table verifications add column if not exists email_verified boolean not null default false;
alter table verifications add column if not exists email_verified_at timestamptz;
comment on column verifications.email_verified is
  'Hesap e-postasi kod ile dogrulandi mi. TELEFON dogrulamasi DEGILDIR — '
  'ikisi ayri guven sinyali, ayri kolon.';

-- Kanal artik e-posta
update beta_settings set value = to_jsonb('email'::text) where key = 'otp_channel';

insert into beta_settings (key, value) values
 ('otp_notice_email', to_jsonb(
   'E-postana bir kod gönderdik. Bu, hesabın sana ait olduğunu doğrular.'::text)),
 ('otp_notice_phone_declared', to_jsonb(
   'Numaran kayıtlı ama doğrulanmadı — SMS doğrulaması henüz aktif değil.'::text))
on conflict (key) do update set value = excluded.value;

-- 🔴 Supabase Auth kodu KENDI dogruluyor (verifyOtp). Bize dusen,
-- sonucu kaydetmek. Fonksiyon yalniz auth.uid() icin calisir —
-- baskasinin adina dogrulama yapilamaz.
create or replace function public.mark_email_verified()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into verifications (user_id, email_verified, email_verified_at)
  values (v_uid, true, now())
  on conflict (user_id) do update
    set email_verified = true, email_verified_at = now();
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.mark_email_verified() to authenticated;

-- Telefon: BEYAN, dogrulama degil
create or replace function public.declare_phone(p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(p_phone,'') = '' then raise exception 'empty_phone'; end if;
  update users set phone = p_phone where id = v_uid;
  -- 🔴 phone_verified'a DOKUNMUYORUZ. Numarayi girmek dogrulamak degil.
  insert into verifications (user_id, phone_verified_method)
  values (v_uid, null)
  on conflict (user_id) do nothing;
  return jsonb_build_object('ok', true, 'verified', false,
    'note', (select value #>> '{}' from beta_settings where key = 'otp_notice_phone_declared'));
end $$;
grant execute on function public.declare_phone(text) to authenticated;

-- Guven durumu: hangi sinyal gercekten var
create or replace function public.verification_state(p_user uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'email_verified', coalesce(v.email_verified, false),
    'phone_declared', coalesce(u.phone,'') <> '',
    'phone_verified', coalesce(v.phone_verified, false)
                      and coalesce(v.phone_verified_method,'bypass') <> 'bypass',
    'id_verified', coalesce(v.id_verified, false),
    'channel', coalesce((select value #>> '{}' from beta_settings where key = 'otp_channel'), 'none'),
    -- Rozette YAZACAK metin: ne dogrulandiysa o.
    'badge', case
      when coalesce(v.email_verified, false) then 'E-posta doğrulandı'
      when coalesce(u.phone,'') <> '' then 'Telefon eklendi (doğrulanmadı)'
      else null end)
    from users u
    left join verifications v on v.user_id = u.id
   where u.id = coalesce(p_user, auth.uid());
$$;
grant execute on function public.verification_state(uuid) to authenticated;

select 'otp_channel' as ayar, value #>> '{}' as deger from beta_settings where key='otp_channel';
select '138 OK - e-posta dogrulamasi kuruldu, telefon BEYAN olarak ayrildi' as sonuc;
