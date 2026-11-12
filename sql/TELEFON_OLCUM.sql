-- ============================================================================
-- TELEFON DOĞRULAMA ÖLÇÜMÜ (SALT OKUNUR · 13 Kasım 2026)
-- Hiçbir şey yazmaz. Telefon doğrulamasının canlıda çalışıp çalışmadığını ölçer:
--   SMS isteyen (telefon_gonderim_izni geçen) kaç kişi · doğrulayan kaç kişi · yarıda kalan.
-- Gerçek kullanıcılar: test kalıbı, ekip ve inceleme hesabı hariç.
-- Tek sorgu, tek satır. Sonucu Claude'a ilet.
-- ============================================================================
with gercek as (
  select u.id from users u
   where not public.seed_test_hesabi(u.email)
     and not coalesce(u.is_staff, false)
     and lower(coalesce(u.email, '')) <> 'inceleme@loungelink.co'
     and u.deleted_at is null
), sms as (
  select g.user_id, count(*) as adet, max(g.created_at) as son
    from telefon_gonderimleri g join gercek r on r.id = g.user_id
   group by g.user_id
)
select
  (select value #>> '{}' from beta_settings where key = 'telefon_kanali')                 as kanal,
  (select coalesce(nullif(value #>> '{}', ''), '(BOS)') from beta_settings where key = 'firebase_proje_id') as firebase_proje,
  (select count(*) from gercek)                                                            as gercek_kullanici,
  (select count(*) from sms)                                                               as sms_isteyen,
  (select coalesce(sum(adet), 0) from sms)                                                 as toplam_sms_istegi,
  (select count(*) from verifications v join gercek r on r.id = v.user_id
    where v.phone_verified and v.phone_verified_method = 'sms')                            as sms_ile_dogrulayan,
  (select count(*) from verifications v join gercek r on r.id = v.user_id
    where v.phone_verified)                                                                as telefonu_dogrulu_toplam,
  (select count(*) from sms s
    where not exists (select 1 from verifications v where v.user_id = s.user_id and v.phone_verified)) as sms_isteyip_dogrulayamayan,
  (select max(son) from sms)                                                               as son_sms_istegi,
  (select max(v.phone_verified_at) from verifications v join gercek r on r.id = v.user_id
    where v.phone_verified_method = 'sms')                                                 as son_basarili_dogrulama;
