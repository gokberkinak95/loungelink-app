-- ============================================================
-- LoungeLink · 062_fix_verify_otp.sql
--
-- "DÜŞEN ADIM" denetimi (drift_check.py) ile bulundu. Üç ayrı sorun:
--
-- 1) 🔴 YANLIŞ KOLON ADLARI — gerçek OTP doğrulaması ÇALIŞMIYOR.
--    send_otp (009) kodu `otp_tokens.phone_e164` + `used_at` ile yazıyor,
--    ama verify_otp (026) `phone` + `consumed_at` ile OKUMAYA çalışıyor.
--    Bu kolonlar yok → "column does not exist" hatası.
--    Şu ana kadar fark edilmedi çünkü '0000' demo kısayolu SELECT'i hiç
--    çalıştırmadan geçiyor; yani telefon doğrulaması yalnızca demo kodla
--    çalışıyormuş.
--
-- 2) 🔴 KABA-KUVVET KORUMASI DÜŞMÜŞ.
--    009'daki sürümde `attempts >= 5 → too_many_attempts` ve her yanlış
--    denemede `attempts + 1` vardı. 026'da fonksiyon yeniden yazılırken
--    ikisi de kayboldu. 6 haneli kod + sınırsız deneme = kırılabilir.
--
-- 3) ⚠ '0000' DEMO KISAYOLU KODA GÖMÜLÜ.
--    Canlıya çıkarken bunu unutmak, HERKESİN HERHANGİ BİR TELEFONU
--    doğrulayabilmesi demek. Kod değişikliği gerektirmeden kapatılabilsin
--    diye beta_settings'e taşındı:
--        update beta_settings set value='false' where key='otp_demo_bypass';
--    Beta boyunca açık kalabilir; LANSMAN ÖNCESİ KAPATILMALI.
-- ============================================================

-- Demo kısayolu ayarı (yoksa oluştur — beta için açık başlar)
insert into beta_settings (key, value)
values ('otp_demo_bypass', 'true'::jsonb)
on conflict (key) do nothing;


create or replace function public.verify_otp(p_phone text, p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_row    otp_tokens%rowtype;
  v_ok     boolean := false;
  v_demo   boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- Demo kısayolu yalnızca ayar açıkken geçerli (lansmanda kapatılacak)
  select coalesce((value)::text = 'true', false) into v_demo
    from beta_settings where key = 'otp_demo_bypass';

  if v_demo and p_code = '0000' then
    v_ok := true;
  else
    -- DOĞRU KOLONLAR: phone_e164 + used_at (send_otp ile aynı)
    select * into v_row from otp_tokens
     where user_id = v_uid
       and phone_e164 = p_phone
       and used_at is null
       and expires_at > now()
     order by created_at desc
     limit 1
     for update;

    if not found then
      raise exception 'invalid_code';       -- süresi dolmuş ya da hiç yok
    end if;

    -- KABA-KUVVET KORUMASI (009'dan geri getirildi)
    if coalesce(v_row.attempts, 0) >= 5 then
      raise exception 'too_many_attempts';
    end if;

    if v_row.code_hash = crypt(p_code, v_row.code_hash) then
      v_ok := true;
      update otp_tokens set used_at = now() where id = v_row.id;
    else
      -- Yanlış kod → deneme sayacını artır, sonra hata ver
      update otp_tokens set attempts = coalesce(attempts,0) + 1 where id = v_row.id;
      raise exception 'invalid_code';
    end if;
  end if;

  if not v_ok then raise exception 'invalid_code'; end if;

  -- Telefonu kullanıcıya yaz — HER İKİ kolon da (phone_in_use phone_e164 okuyor)
  update users set phone = p_phone, phone_e164 = p_phone where id = v_uid;

  insert into verifications (user_id, phone_verified, phone_verified_at)
  values (v_uid, true, now())
  on conflict (user_id) do update
    set phone_verified = true, phone_verified_at = now();

  -- §16: telefon doğrulama +10 (yalnızca bir kez)
  update trust_scores
     set score = least(100, score + 10),
         components = coalesce(components,'{}'::jsonb) || '{"phone":10}'::jsonb,
         updated_at = now()
   where user_id = v_uid
     and not (coalesce(components,'{}'::jsonb) ? 'phone');

  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.verify_otp(text, text) to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================

-- 1) Artık doğru kolonları mı kullanıyor? (üçü de true dönmeli)
select
  (prosrc ilike '%phone_e164 = p_phone%')  as "dogru_kolon_phone_e164",
  (prosrc ilike '%used_at is null%')       as "dogru_kolon_used_at",
  (prosrc ilike '%too_many_attempts%')     as "kaba_kuvvet_korumasi_var"
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='verify_otp';

-- 2) Demo kısayolunun durumu — LANSMAN ÖNCESİ 'false' olmalı
select key, value as "otp_demo_bypass (lansmanda false yap)"
from beta_settings where key = 'otp_demo_bypass';

select '062 OK — verify_otp dogru kolonlarla calisiyor, kaba-kuvvet korumasi geri geldi, demo kisayolu ayara bagli' as sonuc;
