-- ============================================================================
-- 341 · "LOUNGE GİRİŞİ" → "İLAN BAŞVURUSU"   (25 Ekim 2026)
--
-- Gökberk: "Ayda 7 lounge girişi" kullanıcıya doğrudan lounge'a girme hakkı satılıyormuş gibi okunuyor.
-- Kredi bir host'un ilanına BAŞVURMA hakkıdır; içeri girmek host'un kararı ve salonun kuralıdır.
-- Plan maddeleri (plan_catalog.perks / perks_en) ve 1'lik kredi paketinin açıklaması güncellenir.
-- Uygulama, panel ve site metinleri aynı turda (app i18n, site PlanKartlari, BO kredi paketleri notu).
-- Supabase SQL Editor'de tek parça; tekrar koşulabilir. Doğrulama: dört satır tamam = true.
-- ============================================================================
update public.plan_catalog set
  perks = replace(replace(replace(perks::text,
            'Kayıtta 1 kredi: ilk lounge girişin bizden', 'Kayıtta 1 kredi: ilk ilan başvurun bizden'),
            'Her ay 3 lounge girişi', 'Her ay 3 ilan başvurusu'),
            'Her ay 7 lounge girişi', 'Her ay 7 ilan başvurusu')::jsonb,
  perks_en = replace(replace(replace(perks_en::text,
            '1 credit on sign-up: your first lounge visit is on us', '1 credit on sign-up: your first listing request is on us'),
            '3 lounge visits every month', '3 listing requests every month'),
            '7 lounge visits every month', '7 listing requests every month')::jsonb
where perks::text like '%lounge giriş%' or perks_en::text like '%lounge visit%';

update public.kredi_paketleri set aciklama = 'Tek bir ilan başvurusu için.'
 where kod = 'tek' and aciklama = 'Tek bir lounge isteği için.';

select 'plan maddelerinde "lounge girişi" kalmadı' as kontrol,
       not exists (select 1 from plan_catalog where perks::text like '%lounge giriş%') as tamam
union all select 'İngilizce maddelerde "lounge visit" kalmadı',
       not exists (select 1 from plan_catalog where perks_en::text like '%lounge visit%')
union all select 'Sık Uçan: her ay 3 ilan başvurusu',
       exists (select 1 from plan_catalog where plan = 'sik_ucan' and perks::text like '%Her ay 3 ilan başvurusu%')
union all select '1 kredi paketi açıklaması',
       not exists (select 1 from kredi_paketleri where aciklama like '%lounge isteği%');
-- Beklenen: dört satır tamam = true.
