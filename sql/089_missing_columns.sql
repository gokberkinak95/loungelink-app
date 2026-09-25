-- ============================================================
-- LoungeLink · 089_missing_columns.sql
-- KODUN KULLANDIĞI AMA VERİTABANINDA HİÇ OLMAYAN KOLON
--
-- 🔴 NASIL BULUNDU: bu turda yazılan `schema_check.py` (kodun okuduğu her
-- kolonu şemayla karşılaştırır) ilk çalıştırmasında iki sessiz hata buldu.
-- Biri `lounges.access_type` yazım hatasıydı (v1.85'te kodda düzeltildi),
-- diğeri BU: `profiles.contact_email` kolonu HİÇ VAR OLMAMIŞ.
--
-- ETKİSİ (sessiz, bu yüzden aylarca fark edilmedi):
--   Gizlilik/Güvenlik ekranı şunu çağırıyor:
--     .from("profiles").select("...,contact_email").eq("user_id",uid)
--   PostgREST bilinmeyen kolonda 400 döner → supabase-js `data: null` verir
--   → `prof` null kalır → EKRANDAKİ TÜM GİZLİLİK AYARLARI boş/varsayılan
--   görünür. Üstelik `patch({contact_email})` yazması da sessizce başarısız.
--   Yani "İletişim E-postası" özelliği hiç çalışmamış ve kullanıcı
--   ayarlarını kaydettiğini SANMIŞ.
--
-- Kolonu SİLMEK yerine EKLİYORUZ: özellik gerçek ve mantıklı (giriş
-- e-postasından ayrı, host'a görünen iletişim adresi). Kolon eklenince
-- sahadaki v1.83/v1.84 kurulumları da UYGULAMA GÜNCELLEMESİ OLMADAN
-- düzelir — asıl tercih sebebi bu.
-- ============================================================

alter table profiles add column if not exists contact_email text;

-- Basit biçim kontrolü. Katı bir doğrulama DEĞİL (RFC 5322'yi CHECK ile
-- kovalamak hatalıdır); yalnız kabaca bozuk veriyi engeller.
alter table profiles drop constraint if exists profiles_contact_email_chk;
alter table profiles add constraint profiles_contact_email_chk
  check (contact_email is null or contact_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

comment on column profiles.contact_email is
  'Kullanicinin gosterdigi iletisim e-postasi (auth e-postasindan AYRI). '
  'v1.83''ten beri app okuyup yaziyordu ama kolon yoktu — 089 ile eklendi.';

-- ============================================================
-- DOĞRULAMA
-- ============================================================
select count(*) filter (where contact_email is not null) as dolu_iletisim_epostasi,
       count(*) as toplam_profil
  from profiles;

select '089 OK - profiles.contact_email eklendi (app guncellemesi GEREKMEZ)' as sonuc;
