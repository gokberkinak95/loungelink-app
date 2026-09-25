-- ============================================================================
-- LoungeLink · 220_plan_katalogu_ve_dil.sql                (19 Ağustos 2026)
--
-- ÜÇ İŞ:
--   1) `users.plan` varsayılanı ölü bir plana bakıyordu — düzeltiliyor
--   2) Plan adı ve ayrıcalıkları İngilizce'ye çevrilebilir hale geliyor
--   3) Plan adı BO'dan düzenlenebilsin diye katalog hazırlanıyor
--
-- Gökberk'in sorusu: "plan adları app İngilizce dile çevrildiğinde otomatik
-- dönüyor mu yoksa BO'ya ing başlık alanı da mı eklemeliyiz?"
-- Ölçülmüş cevap: HAYIR, dönmüyor. Karar: BO'ya alan ekliyoruz.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 1) 🔴 SESSİZ KUSUR — HERKES ÖLÜ BİR PLANDA
--
-- Gökberk bunu SORMADI; plan editörü ekran görüntüsünü incelerken çıktı.
--
-- ÖLÇÜM (temiz kurulum + SEED):
--     select plan, count(*) from users group by 1;
--     →  explorer | 37          ← 37 kullanıcının 37'si
--
--     select column_default from information_schema.columns
--      where table_name='users' and column_name='plan';
--     →  'explorer'::plan_type  ← bugün kaydolan da buraya düşüyor
--
-- 210 eski üç planı SİLMEDİ, `aktif = false` yaptı — bu doğruydu, çünkü
-- silseydi o planı taşıyan kullanıcı çözümsüz kalırdı. Ama VARSAYILANI
-- taşımayı unuttu. Sonuç: herkes var olan ama PASİF bir plana bağlı.
--
-- 🔴 NEDEN GÖRÜNMEDİ — MASKE HER YERDE ÇALIŞMIYOR.
-- 210:160-163 bir yerde maskeliyor:
--     if not exists (select 1 from plan_catalog where plan::text=v_satin and aktif)
--       then v_satin := 'yolcu'; end if;
-- yani ekranda "Yolcu" görünüyor. Ama 210:257'de maske YOK:
--     left join plan_catalog p on p.plan = u.plan and p.aktif
-- `explorer` aktif olmadığı için join boş dönüyor, `kacirilan_sikligi`
-- NULL kalıyor ve bir satır sonra `coalesce(...,'aylik')` sessizce bir
-- değer üretiyor.
--
-- GERÇEK ETKİ: plan sıklığı hiç uygulanmıyor. Sık Uçan haftalık,
-- Kâhya anlık bildirim almalıydı; ÜÇÜ DE aylık alıyor. Yani ödenen
-- planın vaadi sessizce çalışmıyor ve hata da vermiyor.
--
-- `coalesce`, eksik veriyi hataya çevirmek yerine ortalama bir değere
-- çeviriyor. Ortalama değer, eksikliği görünmez yapar.
-- ════════════════════════════════════════════════════════════════════════

alter table users alter column plan set default 'yolcu'::plan_type;

-- Mevcut kullanıcıları taşı. YALNIZCA pasif plandakiler taşınır —
-- bilerek bir plan seçmiş kimseye dokunulmaz.
do $$
declare n int;
begin
  update users u set plan = 'yolcu'::plan_type
   where exists (select 1 from plan_catalog p
                  where p.plan = u.plan and coalesce(p.aktif,false) = false);
  get diagnostics n = row_count;
  raise notice '220: % kullanici pasif plandan yolcu planina tasindi', n;
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 2) İNGİLİZCE ALANLAR
--
-- ÖLÇÜM — app plan adını ve ayrıcalıkları HAM veritabanından basıyor:
--     rnapp/src/screens.js:4395  <Text>{p.ad}</Text>
--     rnapp/src/screens.js:4415  ✓ {perk}
-- i18n'de `planExplorer/planTraveler/planFrequent` anahtarları var ama
-- ÜÇÜ DE ÖLÜ — hiçbir yerde kullanılmıyor. Yani EN diline geçen kullanıcı
-- plan adını da altındaki maddeleri de Türkçe görüyor.
--
-- 🔴 NEDEN i18n'E DEĞİL BO'YA: `perks` serbest metin listesi ve BO'dan
-- düzenlenebiliyor. i18n'e taşısaydım Gökberk her yeni ayrıcalık maddesi
-- için kod değişikliği beklemek zorunda kalırdı — yani ürünü yönetmek
-- için geliştirici gerekirdi. Metnin sahibi metni yazan olmalı.
--
-- Karşılık yoksa Türkçesi gösterilir. Boş ekran, yanlış dilden kötüdür.
-- ════════════════════════════════════════════════════════════════════════

alter table plan_catalog add column if not exists ad_en text;
alter table plan_catalog add column if not exists perks_en jsonb;

comment on column plan_catalog.ad_en is
  'Plan adinin Ingilizcesi. Bos ise app `ad` (Turkce) gosterir.';
comment on column plan_catalog.perks_en is
  'Ayricalik maddelerinin Ingilizcesi (jsonb dizi). Bos ise app `perks` gosterir.';

-- 🔴 23 AGUSTOS DUZELTMESI — BU DOSYA KENDINDEN SONRAKI KARARLARI
-- EZIYORDU. 246 plan ayricaliklarini yeniden yazdi (TR 3 madde); bu
-- dosya tekrar kosunca EN'i eski 5 maddeye geri cekti ve kendi
-- nobetcisi "madde sayilari TUTMUYOR" diye kirmizi yandi.
--
-- Kok neden: eski bir migration'in her kosusta ayni degeri YENIDEN
-- DAYATMASI. Bir migration TOHUM atmali, her acilista fikrini tekrar
-- soylememeli.
--
-- 🆕 SINIF: "ESKI BIR MIGRATION HER KOSUSTA KENDI DEGERINI YENIDEN
-- DAYATIYORSA, KENDINDEN SONRAKI HER KARARI SESSIZCE GERI ALIR."
--
-- Artik `perks_en` yalnizca BOSSA yazilir. Ilk kurulumda aynen calisir;
-- sonraki turlarda daha yeni karari ezmez.
update plan_catalog set
  ad_en = case plan::text
            when 'yolcu'    then 'Traveler'
            when 'sik_ucan' then 'Frequent Flyer'
            when 'kahya'    then 'Concierge'
            else ad_en end,
  perks_en = case plan::text
    when 'yolcu' then '[
      "Wallet: track your entitlements, burn countdown, value calculator",
      "Rule engine: where your card actually works",
      "Earn credits by hosting",
      "Monthly missed-value summary"]'::jsonb
    when 'sik_ucan' then '[
      "Everything in Traveler",
      "Weekly missed-value alerts",
      "2 listing boosts per month",
      "Burn alerts at 90 · 30 · 7 days",
      "Up to 3 cards in your wallet",
      "20 flight lookups per month"]'::jsonb
    when 'kahya' then '[
      "Everything in Frequent Flyer",
      "Real-time missed-value alerts",
      "Unlimited listing boosts",
      "Calendar invites for burn reminders",
      "Unlimited cards",
      "Unlimited flight lookups",
      "Priority support"]'::jsonb
    else perks_en end
where plan::text in ('yolcu','sik_ucan','kahya')
  and (perks_en is null
       or jsonb_array_length(coalesce(perks_en,'[]'::jsonb)) = 0
       or ad_en is null);

-- 🔴 MADDE SAYILARI TUTMALI. Türkçe listede 6 madde varken İngilizcesinde
-- 4 madde olsaydı, dil değiştiren kullanıcı iki ayrıcalığını kaybetmiş
-- gibi görürdü ve bunu kimse fark etmezdi — iki liste iki ayrı ekranda.
--
-- ════════════════════════════════════════════════════════════════════
-- 🔴 19 AĞUSTOS — BU NÖBETÇİ TEKRAR KURULUMDA YANLIŞ YERE YANIYORDU.
-- Ölçüldü: tur bir kez kurulmuş bir veritabanında 219→226 yeniden
-- koşunca burası patlıyor:
--     220: ayricalik madde sayilari TUTMUYOR →
--          yolcu (tr=3 en=4) sik_ucan (tr=5 en=6) kahya (tr=6 en=7)
--
-- Sebep bir ÇEVİRİ EKSİĞİ DEĞİL, SIRA: 225 "kart sınırı vaadi" satırını
-- iki listeden de siliyor. Tekrar kurulumda 220 İngilizce listeyi
-- ham hâline geri yazıyor (kart satırı geri geliyor), Türkçe liste ise
-- önceki turun 225'i tarafından zaten silinmiş durumda. Yani üç planın
-- üçünde de tam BİR madde fark ediyor — hep aynı madde.
--
-- Nöbetçi doğru şeyi ölçmek istiyordu ama YANLIŞ ANI ölçüyordu.
-- Çözüm: karşılaştırma, 225'in sileceği kart satırları HARİÇ yapılır.
-- Böylece ölçüm sıradan bağımsız olur ve asıl aradığı şeyi — gerçekten
-- çevrilmemiş bir madde — aynen yakalamaya devam eder.
-- ════════════════════════════════════════════════════════════════════
do $$
declare r record; v_bozuk text := '';
begin
  for r in select plan::text as p,
                  (select count(*) from jsonb_array_elements_text(coalesce(perks,'[]'::jsonb)) x
                    where x !~* 'kart')                              as n_tr,
                  (select count(*) from jsonb_array_elements_text(coalesce(perks_en,'[]'::jsonb)) x
                    where x !~* 'card')                              as n_en,
                  jsonb_array_length(coalesce(perks_en,'[]'::jsonb))  as ham_en
             from plan_catalog where aktif
  loop
    -- ham_en = 0 ise çeviri hiç yok; aşağıdaki `n_en > 0` kapısı bunu
    -- zaten geçiriyor (çeviri yokluğu bu nöbetçinin konusu değil).
    if r.ham_en = 0 then continue; end if;
    if r.n_en > 0 and r.n_tr <> r.n_en then
      v_bozuk := v_bozuk || r.p || ' (tr=' || r.n_tr || ' en=' || r.n_en || ') ';
    end if;
  end loop;
  if v_bozuk <> '' then
    raise exception '220: ayricalik madde sayilari TUTMUYOR → %', v_bozuk;
  end if;
  raise notice '220: tr/en ayricalik madde sayilari esit';
end $$;


-- ---- App bu alanları görsün: subscription_plans dile duyarlı ----
--
-- 🔴 DİLİ PARAMETRE OLARAK ALIYOR, `auth` içinden TAHMİN ETMİYORUM.
-- Kullanıcının dil tercihi cihazda; sunucu onu bilmiyor. Sunucuya
-- sormak yerine app kendi dilini söylüyor. Varsayılan 'tr' — parametre
-- verilmezse bugünkü davranış birebir korunur (eski app sürümleri
-- kırılmaz).
--
-- sqlcheck: allow-replace subscription_plans  (yeni DEFAULT'lu parametre)
drop function if exists public.subscription_plans();
create or replace function public.subscription_plans(p_lang text default 'tr')
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_agg(jsonb_build_object(
           'plan', p.plan, 'ad',
             case when lower(coalesce(p_lang,'tr')) = 'en'
                  then coalesce(nullif(p.ad_en,''), p.ad)
                  else p.ad end,
           'aylik_kredi', p.monthly_credits,
           'aylik_fiyat', p.price_try, 'yillik_fiyat', p.yillik_try,
           'yillik_indirim_yuzde', case when p.price_try > 0 and p.yillik_try > 0
             then round(100 - (p.yillik_try::numeric / (p.price_try * 12) * 100)) end,
           'haklar',
             case when lower(coalesce(p_lang,'tr')) = 'en'
                       and jsonb_array_length(coalesce(p.perks_en,'[]'::jsonb)) > 0
                  then p.perks_en else p.perks end,
           'sira', p.sort_order,
           'kacirilan_sikligi', p.kacirilan_sikligi,
           'oncelikli_destek', p.oncelikli_destek)
         order by p.sort_order)
    from plan_catalog p where p.aktif;
$fn$;
grant execute on function public.subscription_plans(text) to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ — varsayılan bir daha ölü plana bakmasın
--
-- Bu kusur "sil değil pasife al" kararının yan etkisiydi ve iki sürüm
-- boyunca kimse görmedi. Bir daha görünmez kalmasın.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare v_def text; v_olu int; v_aktif_plan int;
begin
  select column_default into v_def from information_schema.columns
   where table_schema='public' and table_name='users' and column_name='plan';

  if v_def is null or not exists (
       select 1 from plan_catalog p
        where p.aktif and v_def like '%''' || p.plan::text || '''%') then
    raise exception '220: users.plan varsayilani (%) AKTIF bir plana bakmiyor', coalesce(v_def,'(yok)');
  end if;

  select count(*) into v_olu from users u
   where exists (select 1 from plan_catalog p
                  where p.plan = u.plan and coalesce(p.aktif,false) = false);
  if v_olu > 0 then
    raise exception '220: % kullanici hala PASIF planda', v_olu;
  end if;

  select count(*) into v_aktif_plan from plan_catalog where aktif;
  if v_aktif_plan = 0 then
    raise exception '220: aktif plan YOK — katalog bos';
  end if;

  raise notice '220: varsayilan % · pasif planda kullanici 0 · aktif plan %', v_def, v_aktif_plan;
end $$;

select '220 OK — plan varsayilani duzeldi, en alanlari eklendi' as sonuc;
