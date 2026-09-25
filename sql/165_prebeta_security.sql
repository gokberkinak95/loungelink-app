-- ============================================================
-- LoungeLink · 165_prebeta_security.sql
-- BETA ÖNCESİ GÜVENLİK KALEMİ #1: OTP DEMO BYPASS'I KAPANIR
--
-- ⚠️ Güvenlik. Beta'ya kullanıcı almadan ÖNCE koşulmalı.
--
-- ------------------------------------------------------------
-- 🔴 SORUN
-- ------------------------------------------------------------
-- verify_otp içinde bir demo kısayolu var: `beta_settings` içindeki
-- `otp_demo_bypass` açıksa '0000' kodu HER telefonu doğrulanmış
-- sayıyor. Geliştirme boyunca doğru bir karardı (SMS maliyeti +
-- test hızı) ama beta'ya kullanıcı alınırken AÇIK KALIRSA:
--   · Herkes başkasının telefon numarasını "doğrulayabilir"
--   · Telefon doğrulaması güven puanına +10 veriyor → sahte güven
--   · İstek gönderme kapısı doğrulanmış iletişim istiyor → kapı düşer
-- Yani tek satırlık bir ayar, güven mimarisinin tamamını taşıyor.
--
-- ------------------------------------------------------------
-- ÇÖZÜM: AYARI KAPATMAK YETMEZ — GERİ AÇILABİLMEMELİ
-- ------------------------------------------------------------
-- Ayarı 'false' yapmak tek başına kırılgandır: biri BO'dan ya da
-- SQL konsolundan tekrar 'true' yapabilir ve kimse fark etmez.
-- Üç katman:
--   1. Ayar kapatılır ve NEDEN kapatıldığı kayda yazılır
--   2. Bir TRIGGER ayarın tekrar açılmasını ENGELLER (yalnız
--      açıkça izin verilen bir ortam bayrağıyla açılabilir)
--   3. Bekçi: dosya sonunda ayar hâlâ açıksa migration DURUR
-- ============================================================

-- ---- 1) KAPAT + GEREKÇEYİ KAYDA GEÇ ----
-- 🔴 beta_settings'te `note` kolonu YOK (key/value/updated_at/updated_by).
-- Şemayı okumadan yazmanın bedelini yine ödedim; gerekçe value'nun
-- yanına değil, bu dosyanın başlığına ve ayrı bir kayıt anahtarına yazılır.
insert into beta_settings (key, value)
values ('otp_demo_bypass', 'false'::jsonb)
on conflict (key) do update set value = 'false'::jsonb;

insert into beta_settings (key, value)
values ('otp_demo_bypass_note',
        to_jsonb('Beta öncesi kapatıldı (165): 0000 kısayolu herkesin başkasının telefonunu doğrulamasına izin veriyordu; telefon doğrulaması güven puanına +10 katkı verdiği ve istek kapısı doğrulanmış iletişim istediği için güven mimarisinin tamamını taşıyordu.'::text))
on conflict (key) do update set value = excluded.value;

-- ---- 2) GERİ AÇILMASINI ENGELLE ----
-- Kural: 'otp_demo_bypass' yalnızca `otp_bypass_unlock` ayarı da
-- aynı anda 'true' ise açılabilir. İki ayar birden değiştirmek
-- kazara olmaz; bilinçli bir eylem gerektirir.
create or replace function public.guard_otp_bypass() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_unlock boolean;
begin
  if new.key = 'otp_demo_bypass' and coalesce(new.value::text,'') = 'true' then
    select coalesce((value)::text = 'true', false) into v_unlock
      from beta_settings where key = 'otp_bypass_unlock';
    if not coalesce(v_unlock, false) then
      raise exception 'otp_bypass_locked';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_otp_bypass on beta_settings;
create trigger trg_guard_otp_bypass
  before insert or update on beta_settings
  for each row execute function public.guard_otp_bypass();

-- ---- 3) BEKÇİ + KİLİDİN GERÇEKTEN ÇALIŞTIĞININ KANITI ----
do $$
declare v_on boolean; v_blocked boolean := false;
begin
  select coalesce((value)::text = 'true', false) into v_on
    from beta_settings where key = 'otp_demo_bypass';
  if coalesce(v_on, false) then
    raise exception '165: OTP demo bypass HÂLÂ AÇIK — beta güvenliği yok';
  end if;

  -- Kilidi sına: açmayı dene, engellenmeli (mutasyon testinin SQL hali)
  begin
    update beta_settings set value = 'true' where key = 'otp_demo_bypass';
    v_blocked := false;
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception '165: kilit ÇALIŞMIYOR — bypass yeniden açılabildi';
  end if;

  -- Kapalı kaldığını teyit et (exception sonrası satır değişmemiş olmalı)
  select coalesce((value)::text = 'true', false) into v_on
    from beta_settings where key = 'otp_demo_bypass';
  if coalesce(v_on, false) then
    raise exception '165: kilit çalıştı ama değer yine de değişti';
  end if;
end $$;

select '165 OK - otp bypass kapali ve kilitli' as sonuc;
