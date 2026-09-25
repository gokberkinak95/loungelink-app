-- ============================================================================
-- 269b — 47 İLE 58 ARASINDAKİ FARK KİM?   (SALT OKUNUR)
--
-- 🔴 NEDEN
-- 269a şunu döndü:
--     satır 1 · Supabase'in onayladığı hesap        → 47
--     satır 3 · e-posta puanı alan hesap            → 58
--     satır 8 · doğrulanmamış hesap                 →  0
--
-- Yani 11 hesap, `auth.users.email_confirmed_at` BOŞ olduğu hâlde
-- `verifications.email_verified = true` taşıyor ve +10 puan alıyor.
--
-- 269'un tamamı "tek kaynak" kuralı üzerine kuruluydu:
--   `auth.users.email_confirmed_at` GERÇEK, bizim tablomuz AYNA.
-- Bu 11 hesap aynanın gerçekten ayrıldığı yer.
--
-- ⚠️ AMA ÜÇÜ AYRI ŞEY OLABİLİR VE ÜÇÜNÜN CEVABI FARKLI:
--   (a) `auth.users` satırı HİÇ YOK       → tohum/BO ile açılmış test hesabı
--   (b) satır var, onay YOK               → GERÇEK SORUN: hak edilmemiş puan
--   (c) satır var, onay var ama silinmiş  → beklenmez, bakılmalı
--
-- 269a bunları ayırmıyordu — benim denetimimin kör noktası. "Hepsi
-- doğrulanmış" derken YALNIZ kendi tablomuza bakıyordu; o tablonun
-- doğruyu söyleyip söylemediğini sormuyordu.
--
-- 🆕 SINIF: "BİR AYNAYI DENETLERKEN AYNAYA BAKARSAN, AYNA HEP DOĞRU
-- ÇIKAR — DENETİM AYNAYI DEĞİL, AYNA İLE GERÇEĞİN FARKINI ÖLÇMELİDİR."
-- ============================================================================

select
  case
    when au.id is null                     then '(a) auth.users satırı YOK — tohum/BO hesabı'
    when au.email_confirmed_at is null     then '(b) ⚠️ onaylanmamış ama doğrulanmış işaretli'
    else                                        '(c) beklenmeyen durum'
  end                                                as "sınıf",
  u.email                                            as "e-posta",
  u.role                                             as "rol",
  u.created_at::date                                 as "kayıt",
  v.email_verified_at::date                          as "doğrulandı yazılan",
  au.created_at::date                                as "auth kaydı",
  coalesce(au.raw_app_meta_data->>'provider','—')    as "sağlayıcı",
  t.score                                            as "puan",
  (t.components ? 'email')                           as "email puanı alıyor",
  u.id                                               as "hesap id"
from users u
left join auth.users au on au.id = u.id
left join verifications v on v.user_id = u.id
left join trust_scores  t on t.user_id = u.id
where u.deleted_at is null
  and coalesce(v.email_verified, false)
  and (au.id is null or au.email_confirmed_at is null)
order by 1, u.created_at;
