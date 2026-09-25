-- ============================================================================
-- LoungeLink · 244_odul_ekonomisi.sql                     (23 Ağustos 2026)
--
-- "3 UÇUŞA 30 DOLARLIK HEDİYE VERİRSEK BATARIZ" — HAKLI, ÖLÇTÜM
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE SAYILAR
-- ════════════════════════════════════════════════════════════════════════
-- Bir ağırlama kaç puan basıyor?
--   host 500 + misafir 200 = 700 puan   (beta_settings)
--
-- Katalogda bugün ne var?
--   Türk Hava Yolları 500 mil ....... 1000 puan  = 1,4 ağırlama
--   Emirates Skywards 750 mil ....... 1200 puan  = 1,7 ağırlama
--   Airalo eSIM 3GB ................. 1000 puan  = 1,4 ağırlama
--
-- Gökberk'in verdiği piyasa çıpası: 1000 THY mili ≈ 30 USD.
-- Yani 500 mil ≈ 15 USD ≈ ₺600 (kur ayarı aşağıda, sen değiştirebilirsin).
-- 1,4 ağırlamaya ₺600 ödüyoruz.
--
-- ⚠️ VE KATALOGDA `supplier_cost_try` KOLONU ZATEN VARDI — ON ÖDÜLÜN
-- ONUNDA DA **NULL**. Yani bugüne kadar hiçbir ödülün bize kaça mal
-- olduğu HİÇ YAZILMADI. Fiyatlar maliyete değil, hisse göre konmuş.
--
-- 🆕 SINIF: **"MALİYETİ YAZILMAYAN BİR FİYAT, FİYAT DEĞİL TEMENNİDİR."**
--
-- ════════════════════════════════════════════════════════════════════════
-- TAVANI NEREDEN TÜRETİYORUM (uydurmuyorum, senin fiyatlarından)
-- ════════════════════════════════════════════════════════════════════════
-- Sık Uçan planı ₺99/ay (plan_catalog). Ayda 2 kez ağırlayan bir host
-- 1000 puan basar. Ödül maliyeti aboneliğin %20'sini geçerse — ödeme
-- komisyonu, altyapı ve destek payından sonra — plan kendini ödemez.
--
--   ₺99 × %20 = ₺19,8  /  1000 puan  ≈  **2 kuruş/puan**
--
-- Yani bir ağırlama, bize en fazla ~₺10'luk ödül değeri üretebilir.
-- Bu sayı `beta_settings.puan_basina_kurus`ta duruyor; iş modelin
-- değişirse TEK YERDEN değiştirirsin, bütün katalog yeniden fiyatlanır.
--
-- ════════════════════════════════════════════════════════════════════════
-- İKİ TÜR ÖDÜL — VE İKİSİNİ AYIRMAK HER ŞEYİ DEĞİŞTİRİYOR
-- ════════════════════════════════════════════════════════════════════════
-- **nakit**    : cebimizden çıkıyor (mil, eSIM, sigorta). Tavana TABİ.
-- **ortaklik** : ortağın finanse ettiği kupon/indirim (affiliate, promo
--                kodu). Bize maliyeti ~0. Tavana TABİ DEĞİL — burada
--                cömert olabiliriz ve olmalıyız.
--
-- Bugünkü katalogda hepsi "nakit" varsayılıyordu; oysa Booking.com ve
-- Marriott kredileri ortaklık programlarıyla finanse edilebilir. Ayrımı
-- yapınca "ulaşılabilir ödül" ile "batırıcı ödül" aynı listeden çıkıyor.
--
-- ⚠️ EMIRATES → THY. Hedef pazar Türkiye. Emirates Skywards'ı vitrinin
-- başına koymak hem alakasız hem pahalı. Sıralama THY öncelikli.
--
-- ⚠️ AŞAĞIDAKİ MALİYETLER **TAHMİN** (`maliyet_kaynagi='tahmin'`).
-- Uydurmuyorum, tahmin olduğunu YAZIYORUM ve BO'da teyit edilene kadar
-- öyle görünecek. Gerçek rakamı girdiğinde puan fiyatı KENDİLİĞİNDEN
-- yeniden hesaplanır.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) MALİYETİN YAZILACAĞI YER
-- ----------------------------------------------------------------------------
alter table rewards add column if not exists maliyet_turu     text;
alter table rewards add column if not exists maliyet_kaynagi  text;
alter table rewards add column if not exists maliyet_guncel_at timestamptz;

update rewards set maliyet_turu = coalesce(maliyet_turu, 'nakit');
alter table rewards alter column maliyet_turu set default 'nakit';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='rewards_maliyet_turu_chk') then
    alter table rewards add constraint rewards_maliyet_turu_chk
      check (maliyet_turu in ('nakit','ortaklik'));
  end if;
  if not exists (select 1 from pg_constraint where conname='rewards_maliyet_kaynagi_chk') then
    alter table rewards add constraint rewards_maliyet_kaynagi_chk
      check (maliyet_kaynagi is null or maliyet_kaynagi in ('tahmin','teyitli'));
  end if;
end $$;

insert into beta_settings (key, value) values
  ('puan_basina_kurus', to_jsonb(2)),
  ('odul_kur_usd_try',  to_jsonb(41))
on conflict (key) do nothing;

-- 🔴 BİR AĞIRLAMANIN KAÇ PUAN BASTIĞI HİÇBİR AYARDA YAZMIYORDU.
-- 500 ve 200 sayıları `confirm_session()` gövdesine GÖMÜLÜ (satır 35-36).
-- Site onu i18n'den, BO'nun yeni ekranı buradan okuyacaktı — üç ayrı
-- yerde üç ayrı kopya. Ekonomi hesabının paydası, kimsenin
-- değiştiremediği bir sabit olamaz.
--
-- 🆕 SINIF: **"BİR HESABIN PAYDASINI KODA GÖMERSEN, O HESABI KİMSE
-- DEĞİŞTİREMEZ — YALNIZCA YANLIŞLAYABİLİR."**
--
-- Değerleri UYDURMUYORUM; canlı gövdedeki sayıları okuyup ayara
-- taşıyorum. `confirm_session`ı bu turda DEĞİŞTİRMİYORUM (ayrı bir
-- sözleşme); ayar bugün raporlama paydası, yarın tek kaynak olur.
insert into beta_settings (key, value)
select 'host_session_points',
       to_jsonb(coalesce((substring(p.prosrc from 'v_r\.host_id,\s*(\d+),\s*''session_reward'''))::int, 500))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='confirm_session' limit 1
on conflict (key) do nothing;

insert into beta_settings (key, value)
select 'guest_session_points',
       to_jsonb(coalesce((substring(p.prosrc from 'v_r\.guest_id,\s*(\d+),\s*''session_reward'''))::int, 200))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='confirm_session' limit 1
on conflict (key) do nothing;

do $ayar$
declare v_h int; v_g int;
begin
  select (value #>> '{}')::int into v_h from beta_settings where key='host_session_points';
  select (value #>> '{}')::int into v_g from beta_settings where key='guest_session_points';
  if v_h is null or v_g is null or v_h < 1 or v_g < 1 then
    raise exception '244: oturum puanlari okunamadi (host=%, misafir=%) — confirm_session govdesi degismis olabilir.', v_h, v_g;
  end if;
  raise notice '244: bir agirlama % puan basiyor (host % + misafir %)', v_h + v_g, v_h, v_g;
end $ayar$;

comment on column rewards.supplier_cost_try is
  'Bu odul bize kaca mal oluyor (TRY). NULL = bilinmiyor; nakit odul NULL maliyetle YAYINLANAMAZ (244).';

-- ----------------------------------------------------------------------------
-- 2) FİYAT ARTIK TÜRETİLİYOR
-- ----------------------------------------------------------------------------
create or replace function public.odul_puan_onerisi(p_maliyet_try numeric, p_tur text default 'nakit')
returns int language sql stable set search_path = public as $f$
  -- Ortaklik odullerinde maliyet ~0 oldugu icin tavan uygulanmaz; orada
  -- fiyat bir ERISILEBILIRLIK kararidir, maliyet karari degil.
  select case
    when p_maliyet_try is null then null
    when p_tur = 'ortaklik' then greatest(500, (ceil(p_maliyet_try * 10 / 100.0) * 100)::int)
    else greatest(500, (ceil(
           p_maliyet_try * 100.0
           / nullif(coalesce((select (value #>> '{}')::numeric from beta_settings
                               where key='puan_basina_kurus'), 2), 0)
           / 100) * 100)::int)
  end;
$f$;

-- ----------------------------------------------------------------------------
-- 3) NÖBETÇİ TETİKLEYİCİ — BATIRAN ÖDÜL YAYINLANAMAZ
-- ----------------------------------------------------------------------------
-- Bu kural BO'nun ekranında değil, VERİNİN KENDİSİNDE duruyor. Ekrana
-- koysaydım, ekranı atlayan her yol (SQL Editor, ileride bir betik) onu
-- atlardı — 240'ın dersi.
create or replace function public.trg_odul_ekonomi_kapisi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare v_asgari int; v_tavan numeric;
begin
  if not coalesce(new.active, false) then
    return new;                       -- pasif ödül kimseye söz vermiyor
  end if;

  if coalesce(new.maliyet_turu,'nakit') = 'ortaklik' then
    return new;                       -- maliyeti ortak taşıyor
  end if;

  if new.supplier_cost_try is null then
    raise exception 'odul_maliyeti_yazilmamis'
      using detail = format('"%s" nakit odulu, maliyeti bilinmeden yayinlanamaz', new.title),
            hint   = 'BO > Odul Ekonomisi ekranindan maliyeti gir, ya da odulu ortaklik olarak isaretle.';
  end if;

  v_asgari := public.odul_puan_onerisi(new.supplier_cost_try, 'nakit');
  if new.cost_points < v_asgari then
    v_tavan := coalesce((select (value #>> '{}')::numeric from beta_settings
                          where key='puan_basina_kurus'), 2);
    raise exception 'odul_fiyati_maliyetin_altinda'
      using detail = format('"%s": %s puan istiyorsun, maliyeti ₺%s → asgari %s puan',
                            new.title, new.cost_points, new.supplier_cost_try, v_asgari),
            hint   = format('Tavan %s kurus/puan. Fiyati yukselt, maliyeti duzelt '
                         || 'ya da odulu ortaklik olarak isaretle.', v_tavan);
  end if;
  return new;
end $f$;

drop trigger if exists trg_odul_ekonomi on public.rewards;
create trigger trg_odul_ekonomi
  before insert or update on public.rewards
  for each row execute function public.trg_odul_ekonomi_kapisi();

-- ----------------------------------------------------------------------------
-- 4) KATALOĞU YENİDEN FİYATLA
-- ----------------------------------------------------------------------------
-- Önce hepsini pasife alıyorum ki tetikleyici eski fiyatlara takılmasın;
-- sonra maliyet + tür + türetilmiş fiyatla geri açıyorum.
update rewards set active = false;

-- ORTAKLIK ödülleri: konaklama ve otel kredileri affiliate ile finanse
-- edilebilir. Bunlar vitrinin ULAŞILABİLİR yüzü.
update rewards set maliyet_turu='ortaklik', maliyet_kaynagi='tahmin',
                   maliyet_guncel_at = now()
 where title ilike 'Booking.com%' or title ilike 'Marriott%';

-- NAKİT ödüller: maliyet tahminleri (USD → TRY, kur ayarından).
do $fiyat$
declare
  v_kur numeric := coalesce((select (value #>> '{}')::numeric from beta_settings
                              where key='odul_kur_usd_try'), 41);
  r record;
begin
  -- USD tahminleri. Çıpalar: THY mili 30 USD/1000 (Gökberk'in verdiği
  -- piyasa rakamı), Airalo ve SafetyWing herkese açık liste fiyatları.
  for r in select * from (values
      ('Türk Hava Yolları 500 Mil',  15.0),
      ('Emirates Skywards 750 Mil',  22.0),
      ('Airalo eSIM 3GB',             8.5),
      ('Airalo eSIM 10GB',           18.0),
      ('SafetyWing 1 Ay',            45.0)
    ) as t(baslik, usd)
  loop
    update rewards
       set supplier_cost_try = round((r.usd * v_kur)::numeric, 0),
           maliyet_turu      = 'nakit',
           maliyet_kaynagi   = 'tahmin',
           maliyet_guncel_at = now()
     where title = r.baslik;
  end loop;
end $fiyat$;

-- Şimdi fiyatları maliyetten TÜRET ve geri aç.
update rewards
   set cost_points = public.odul_puan_onerisi(supplier_cost_try, maliyet_turu)
 where supplier_cost_try is not null;

-- ULAŞILABİLİR UÇ: bugün katalogda en ucuz ödül 1,4 ağırlama, en pahalısı
-- 7 ağırlamaydı — yani "hepsi yakın" bir vitrin. Doğru vitrin BASAMAKLI
-- olmalı: ilk ödül birkaç ağırlamada, büyük ödül aylarca sonra. Aşağıdaki
-- iki satır o ilk basamağı kuruyor ve ortaklıkla finanse ediliyor.
insert into rewards (title, subtitle, category, cost_points, active, sort_order,
                     supplier, teslim_sekli, teslim_saat, maliyet_turu, maliyet_kaynagi,
                     supplier_cost_try, maliyet_guncel_at)
select t.baslik, t.alt, t.kat, t.puan, false, t.sira, t.saglayici, t.teslim, t.saat,
       'ortaklik', t.kaynak, t.maliyet, now()
  from (values
    -- 🔴 `teslim_saat = 0` yazmistim; 229'un `rewards_teslim_sozu_chk`
    -- kisiti reddetti (1..720 saat). Iyi ki reddetti: "0 saatte teslim"
    -- olcusuz bir sozdur. Rozet aninda verilse bile SOZ 1 saat olmali.
    ('LoungeLink Rozeti · Kâşif', 'Profilinde görünür', 'rozet',  500, 0,
     'LoungeLink', 'otomatik', 1, 'teyitli', 0::numeric),
    ('Havalimanı Kahvesi',        'Ortak kafelerde',    'yeme',  1000, 1,
     'Ortak kafe', 'manuel',   48, 'tahmin',  0::numeric)
  ) as t(baslik, alt, kat, puan, sira, saglayici, teslim, saat, kaynak, maliyet)
 where not exists (select 1 from rewards r where r.title = t.baslik);

-- ----------------------------------------------------------------------------
-- 4b) ULAŞILAMAYAN ÖDÜL, ÖDÜL DEĞİLDİR
-- ----------------------------------------------------------------------------
-- 🔴 Fiyatları maliyete oturtunca ortaya çıkan gerçek şu: nakit maliyetli
-- ödüllerin çoğu bu iş modelinde ULAŞILAMAZ. SafetyWing 1 ay ₺1845 →
-- 92.300 puan → **132 ağırlama**. Vitrine koyduğun an, kimsenin
-- ulaşamayacağı bir söz vermiş olursun.
--
-- 🆕 SINIF: **"ULAŞILAMAYAN BİR ÖDÜL, MOTİVASYON DEĞİL KANITTIR —
-- BU MAĞAZANIN CİDDİ OLMADIĞININ KANITI."**
--
-- Bu yüzden ulaşılabilirlik tavanı: 20.000 puan ≈ 28 ağırlama. Üstündeki
-- nakit ödüller mağazadan ÇIKAR (silinmez — BO'da sebebiyle durur).
-- Kararı sen değiştirmek istersen `odul_ulasilabilir_tavan` ayarı.
insert into beta_settings (key, value) values ('odul_ulasilabilir_tavan', to_jsonb(20000))
on conflict (key) do nothing;

-- Geri aç: yalnız maliyeti yazılmış ya da ortaklık olanlar.
update rewards set active = true
 where (maliyet_turu = 'ortaklik' or supplier_cost_try is not null)
   and category is distinct from 'lounge'    -- 228: takas döngüsü
   and cost_points <= coalesce((select (value #>> '{}')::int from beta_settings
                                 where key='odul_ulasilabilir_tavan'), 20000);

-- THY, Emirates'in ÖNÜNE. Hedef pazar Türkiye.
update rewards set sort_order = 3  where title = 'Türk Hava Yolları 500 Mil';
update rewards set sort_order = 20 where title = 'Emirates Skywards 750 Mil';

-- ----------------------------------------------------------------------------
-- 5) BO İÇİN: EKONOMİ TABLOSU
-- ----------------------------------------------------------------------------
create or replace function public.bo_odul_ekonomisi()
returns table(
  id uuid, baslik text, aktif boolean, tur text, kaynak text,
  maliyet_try numeric, puan int, asgari_puan int,
  kurus_basina_puan numeric, agirlama_sayisi numeric, durum text)
language sql stable security definer set search_path = public as $f$
  -- 🔴 `supplier_cost_try` INTEGER; burada `numeric` ilan ettim ve tip
  -- nobetcisi yakaladi. Ilan ile kaynak arasindaki her sessiz cevrim,
  -- bir gun 22P02 olarak canliya cikar. Acik cast yaziyorum.
  select r.id, r.title, r.active, coalesce(r.maliyet_turu,'nakit'), r.maliyet_kaynagi,
         r.supplier_cost_try::numeric, r.cost_points,
         public.odul_puan_onerisi(r.supplier_cost_try, coalesce(r.maliyet_turu,'nakit')),
         case when r.cost_points > 0 and r.supplier_cost_try is not null
              then round(r.supplier_cost_try::numeric * 100.0 / r.cost_points, 2) end,
         round(r.cost_points / nullif(
           coalesce((select (value #>> '{}')::numeric from beta_settings where key='host_session_points'), 500)
           + coalesce((select (value #>> '{}')::numeric from beta_settings where key='guest_session_points'), 200), 0), 1),
         case
           when coalesce(r.maliyet_turu,'nakit') = 'ortaklik' then 'ortaklik — tavan disi'
           when r.supplier_cost_try is null then 'MALIYET YAZILMAMIS'
           when r.cost_points < public.odul_puan_onerisi(r.supplier_cost_try,'nakit') then 'ZARARINA'
           when r.maliyet_kaynagi = 'tahmin' then 'tahmini maliyet — teyit bekliyor'
           else 'saglikli'
         end
    from rewards r
   order by r.active desc, r.sort_order, r.cost_points;
$f$;
revoke execute on function public.bo_odul_ekonomisi() from public, anon, authenticated;
grant execute on function public.bo_odul_ekonomisi() to service_role;

create or replace function public.bo_odul_maliyet_yaz(
  p_id uuid, p_maliyet numeric, p_tur text default null, p_teyitli boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare v_r rewards%rowtype; v_yeni int;
begin
  select * into v_r from rewards where id = p_id;
  if not found then raise exception 'odul_yok'; end if;
  if p_maliyet < 0 then raise exception 'gecersiz_maliyet'; end if;

  v_yeni := public.odul_puan_onerisi(p_maliyet, coalesce(p_tur, v_r.maliyet_turu, 'nakit'));

  update rewards
     set supplier_cost_try = round(p_maliyet)::int,
         maliyet_turu      = coalesce(p_tur, maliyet_turu, 'nakit'),
         maliyet_kaynagi   = case when p_teyitli then 'teyitli' else 'tahmin' end,
         maliyet_guncel_at = now(),
         -- Fiyat maliyetin altındaysa OTOMATİK yükseltiyorum. Aksi hâlde
         -- tetikleyici kaydı reddeder ve admin "neden kaydolmadı"
         -- diye kalırdı; sebebi anlaşılmayan bir ret, ret değil duvardır.
         cost_points       = greatest(cost_points, coalesce(v_yeni, cost_points))
   where id = p_id;

  return jsonb_build_object('ok', true, 'asgari_puan', v_yeni,
                            'yeni_puan', (select cost_points from rewards where id=p_id));
end $f$;
revoke execute on function public.bo_odul_maliyet_yaz(uuid, numeric, text, boolean)
  from public, anon, authenticated;
grant execute on function public.bo_odul_maliyet_yaz(uuid, numeric, text, boolean) to service_role;

-- ----------------------------------------------------------------------------
-- 6) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n244$
declare
  v_hatalar text[] := '{}';
  v_gecti   boolean;
  v_aktif   int;
  v_zarar   int;
  v_id      uuid;
begin
  -- (1) Aktif hiçbir NAKİT ödül zararına olmamalı
  select count(*) into v_zarar from rewards r
   where r.active and coalesce(r.maliyet_turu,'nakit')='nakit'
     and (r.supplier_cost_try is null
          or r.cost_points < public.odul_puan_onerisi(r.supplier_cost_try,'nakit'));
  if v_zarar > 0 then
    v_hatalar := v_hatalar || format('%s aktif nakit odul zararina', v_zarar);
  end if;

  -- (2) 🔴 TERS YÖN: vitrin BOŞALMAMALI. Her şeyi pasife alan bir
  -- düzeltme de birinci kontrolden yeşil geçer ve mağazayı öldürür.
  select count(*) into v_aktif from rewards where active;
  if v_aktif < 5 then
    v_hatalar := v_hatalar || format('vitrinde yalniz %s aktif odul kaldi — fazla kestim', v_aktif);
  end if;

  -- (3) Kapı gerçekten kapıyor mu: zararına bir ödülü aktif etmeyi dene
  begin
    select id into v_id from rewards where coalesce(maliyet_turu,'nakit')='nakit'
       and supplier_cost_try is not null limit 1;
    if v_id is not null then
      v_gecti := false;
      begin
        update rewards set cost_points = 1, active = true where id = v_id;
        v_gecti := true;
      exception when others then
        if sqlerrm not like '%odul_fiyati_maliyetin_altinda%' then
          v_hatalar := v_hatalar || ('beklenmeyen hata (ekonomi kapisi): ' || sqlerrm);
        end if;
      end;
      if v_gecti then
        v_hatalar := v_hatalar || 'zararina odul AKTIF EDILEBILDI — kapi calismiyor'::text;
      end if;
    end if;
    raise exception 'GERI_AL_244';
  exception when others then
    if sqlerrm <> 'GERI_AL_244' then
      v_hatalar := v_hatalar || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  -- (4) En ucuz ödül gerçekten ULAŞILABİLİR olmalı (ilk basamak)
  if (select min(cost_points) from rewards where active) > 1500 then
    v_hatalar := v_hatalar || 'en ucuz odul 1500 puandan pahali — ilk basamak yok, kimse baslamaz'::text;
  end if;

  if array_length(v_hatalar,1) is not null then
    raise exception '244 NOBETCI: %', array_to_string(v_hatalar, ' | ');
  end if;
  raise notice '244 OK · % aktif odul · zararina 0 · en ucuz % puan',
    v_aktif, (select min(cost_points) from rewards where active);
end $n244$;

select '244 ODUL EKONOMISI KURULDU' as sonuc,
       (select count(*) from rewards where active)                        as aktif_odul,
       (select count(*) from rewards where active and maliyet_turu='nakit') as nakit_odul,
       (select count(*) from rewards where active and supplier_cost_try is null
          and coalesce(maliyet_turu,'nakit')='nakit')                     as maliyetsiz_nakit,
       (select min(cost_points) from rewards where active)                as en_ucuz_puan,
       (select max(cost_points) from rewards where active)                as en_pahali_puan;
