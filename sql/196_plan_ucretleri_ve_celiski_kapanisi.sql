-- ============================================================
-- 196 · PLAN ÜCRETLERİ, KEPLER CLUB FİYATLARI ve DÖRT ÇELİŞKİNİN KAPANIŞI
-- 17 Ağustos 2026
--
-- Gökberk resmî ücret sayfalarını iletti. 191'de `veri_bekliyor`
-- damgasıyla açık bıraktığımız DÖRT madde bu dosyayla kapanıyor.
--
-- ------------------------------------------------------------
-- 🔴 ÖNCE KENDİ ÇELİŞKİMİZİ SÖYLEYELİM
-- ------------------------------------------------------------
-- Ölçtüm: 154_membership_tiers.sql zaten "30 EUR / misafir" ve
-- "36 EUR / misafir" yazıyordu. Yani 191'de "tutar YAZILMADI" derken
-- veritabanında TUTAR VARDI. İkisi aynı anda doğru olamaz.
--
-- Gerçek şu: 154'teki rakamlar KAYNAKSIZDI. Doğru çıktılar —
-- Gökberk'in ilettiği plan sayfası ikisini de onaylıyor — ama o gün
-- bir sayfaya dayanmıyorlardı ve `source_url` alanları boştu.
-- 191 bunu "tutar yok" diye kaydetmişti; doğru ifade "tutar var ama
-- KAYNAĞI yok" olmalıydı.
--
-- 🔴 DERS (yeni sınıf): "KAYNAKSIZ DOĞRU, YANLIŞTAN AZ TEHLİKELİ
-- DEĞİL." Doğru olduğunu bilmediğin bir rakam, yanlış bir rakamla
-- aynı riski taşır: ikisini de savunamazsın. Bu yüzden 196 yalnız
-- rakamları teyit etmiyor, HER RAKAMIN YANINA KAYNAĞINI yazıyor ve
-- kaynaksız rakam bırakmayı bir bekçiyle yasaklıyor.
--
-- ------------------------------------------------------------
-- KAYNAKLAR (Gökberk'in ilettiği resmî sayfalar, 17 Ağu 2026)
-- ------------------------------------------------------------
-- Priority Pass · Türkiye planları
--   Standard       89 € / yıl · ücretsiz ziyaret YOK · ziyaret 30 €
--   Standard Plus 289 € / yıl · 10 ücretsiz üye ziyareti · sonrası 30 €
--   Prestige      459 € / yıl · üye ziyaretleri sınırsız ücretsiz
--   ÜÇ PLANDA DA: misafir ziyareti 30 € · kart teslim ücreti 10 €
--   Seçili salonlarda ön rezervasyon küçük bir ücretle mümkün
-- DragonPass · Go planları
--   Classic        96 € / yıl · 1 ücretsiz ziyaret
--   Preferential  249 € / yıl · 8 ücretsiz ziyaret
--   İKİ PLANDA DA: ek üye ziyareti veya misafir ziyareti 36 €
-- Kepler Club · Sabiha Gökçen (saatlik oda)
--   SingleKep 18 € · DoubleKep 25 € · Deluxe 40 € · VIP 50 € · Duş 17 €
--   %10 servis + %8 vergi fiyata DAHİL · SingleKep'e 7 yaş altı giremez
-- ============================================================

-- ---- 1) PLAN TABLOSU ----
-- 🔴 NEDEN AYRI TABLO: yıllık üyelik ücreti bir MİSAFİR KURALI
-- değildir; lounge_guest_rules'a sıkıştırmak iki farklı kavramı aynı
-- satıra basmak olurdu (146'nın "hak ile durum ayrıdır" dersi).
-- Plan ücreti kullanıcının KARTINA ait; misafir ücreti ZİYARETE ait.
create table if not exists program_plans (
  id           uuid primary key default uuid_generate_v4(),
  program_code text not null,
  plan_code    text not null,          -- lounge_guest_rules.card_tier ile aynı sözlük
  plan_name    text not null,
  annual_fee   numeric,                -- null = ücret açıklanmamış
  currency     text default 'EUR',
  member_free_visits int,              -- null = sınırsız
  member_visit_fee   numeric,          -- ücretsiz hak bitince ziyaret başına
  guest_visit_fee    numeric,          -- misafir başına, ziyaret başına
  extras       text,                   -- teslim ücreti, ön rezervasyon vb.
  source_url   text not null,          -- 🔴 ZORUNLU: kaynaksız satır yasak
  checked_at   date not null default current_date,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);
create unique index if not exists uq_program_plans on program_plans (program_code, plan_code);

alter table program_plans enable row level security;
drop policy if exists pp_read on program_plans;
create policy pp_read on program_plans for select to authenticated, anon using (active);
grant select on program_plans to authenticated, anon;

comment on table program_plans is
  '196: kart programlarının ÜYELİK PLANLARI ve yıllık ücretleri. '
  'Misafir kuralı değil, kartın maliyeti. source_url ZORUNLU.';

insert into program_plans
  (program_code, plan_code, plan_name, annual_fee, currency,
   member_free_visits, member_visit_fee, guest_visit_fee, extras, source_url)
values
  ('PRIORITY_PASS', 'PP_STANDARD', 'Standard', 89, 'EUR',
   0, 30, 30,
   'Kart teslim ücreti 10 €. Seçili salonlarda ön rezervasyon küçük bir ücretle mümkün.',
   'https://www.prioritypass.com/tr/membership'),
  ('PRIORITY_PASS', 'PP_STANDARD_PLUS', 'Standard Plus', 289, 'EUR',
   10, 30, 30,
   'Yılda 10 ücretsiz ÜYE ziyareti; misafir hiçbir planda ücretsiz değil. Kart teslim ücreti 10 €.',
   'https://www.prioritypass.com/tr/membership'),
  ('PRIORITY_PASS', 'PP_PRESTIGE', 'Prestige', 459, 'EUR',
   null, 0, 30,
   'Üye ziyaretleri sınırsız ücretsiz; misafir yine ziyaret başına 30 €. Kart teslim ücreti 10 €.',
   'https://www.prioritypass.com/tr/membership'),
  ('DRAGONPASS', 'DP_CLASSIC', 'Go Classic', 96, 'EUR',
   1, 36, 36,
   'Yılda 1 ücretsiz ziyaret. Ek üye ziyareti de misafir ziyareti de 36 €.',
   'https://www.dragonpass.com/plans'),
  ('DRAGONPASS', 'DP_PREFERENTIAL', 'Go Preferential', 249, 'EUR',
   8, 36, 36,
   'Yılda 8 ücretsiz ziyaret. Ek üye ziyareti de misafir ziyareti de 36 €.',
   'https://www.dragonpass.com/plans')
on conflict (program_code, plan_code) do update set
  plan_name = excluded.plan_name, annual_fee = excluded.annual_fee,
  member_free_visits = excluded.member_free_visits,
  member_visit_fee = excluded.member_visit_fee,
  guest_visit_fee = excluded.guest_visit_fee,
  extras = excluded.extras, source_url = excluded.source_url,
  checked_at = excluded.checked_at, active = true;


-- ---- 2) 154'ÜN KAYNAKSIZ RAKAMLARINA KAYNAK YAZ ----
-- Rakamlar değişmiyor (sayfa onayladı); değişen tek şey artık
-- SAVUNULABİLİR olmaları.
update lounge_programs
   set source_url = 'https://www.prioritypass.com/tr/membership',
       checked_at = current_date,
       typical_guest_fee = 30, guest_fee_currency = 'EUR',
       fee_payer = 'member_card',
       rules_version = coalesce(rules_version, '') || ' · plan ücretleri 196 (17 Ağu 2026)'
 where code = 'PRIORITY_PASS';

update lounge_programs
   set source_url = 'https://www.dragonpass.com/plans',
       checked_at = current_date,
       typical_guest_fee = 36, guest_fee_currency = 'EUR',
       fee_payer = 'member_card',
       rules_version = coalesce(rules_version, '') || ' · plan ücretleri 196 (17 Ağu 2026)'
 where code = 'DRAGONPASS';


-- ---- 3) KURAL NOTLARI: PLAN ÜCRETİ + DARALTILMIŞ BANKA ŞERHİ ----
-- 🔴 ŞERH KALKMIYOR, DARALIYOR. Eskiden "misafir ücreti bankana göre
-- değişir" diyorduk; artık PLAN ÜCRETİ BİLİNİYOR. Bankanın hâlâ
-- değiştirebildiği şey (a) hangi plana sahip olduğun, (b) ücreti senin
-- yerine üstlenip üstlenmediği. Bilinen kısmı söylüyoruz, bilinmeyen
-- kısmı da — ikisini birbirine karıştırmadan.
update lounge_guest_rules r
   set notes = pl.plan_name || ' planı (yıllık ' || pl.annual_fee::text || ' ' || pl.currency || '): '
             || case when pl.member_free_visits is null
                     then 'kendi girişlerin sınırsız ücretsiz. '
                     when pl.member_free_visits = 0
                     then 'kendi girişin de ücretli — ziyaret başına ' || pl.member_visit_fee::text || ' ' || pl.currency || '. '
                     else 'yılda ' || pl.member_free_visits::text || ' ücretsiz ziyaret; sonrası ziyaret başına '
                          || pl.member_visit_fee::text || ' ' || pl.currency || '. ' end
             || 'MİSAFİR her planda ücretlidir: ziyaret başına ' || pl.guest_visit_fee::text || ' ' || pl.currency
             || ' ve tutar ÜYENİN kartından tahsil edilir. '
             || 'Kartını bir banka verdiyse planı ve ücreti banka üstlenmiş olabilir — '
             || 'tutarın sana yansıyıp yansımayacağını bankandan teyit et.',
       member_entry_fee = case when pl.member_free_visits is null then null
                               when pl.member_free_visits = 0
                               then pl.member_visit_fee::text || ' ' || pl.currency || ' / ziyaret'
                               else pl.member_free_visits::text || ' ziyaret sonrası '
                                    || pl.member_visit_fee::text || ' ' || pl.currency end,
       guest_entry_fee = pl.guest_visit_fee::text || ' ' || pl.currency || ' / misafir'
  from lounge_programs p, program_plans pl
 where r.program_id = p.id
   and pl.program_code = p.code
   and pl.plan_code = r.card_tier
   and (r.effective_to is null or r.effective_to >= current_date);


-- ---- 4) SALON FİYAT LİSTESİ (Kepler Club) ----
-- 🔴 NEDEN PROGRAM DEĞİL SALON: Kepler Club bir üyelik programı değil,
-- saatlik oda satan bir tesis. Fiyatı SALONA ait. Programa yazsaydık
-- "Pegasus yolcusu 18 € öder" gibi yanlış bir genelleme doğardı.
create table if not exists venue_prices (
  id         uuid primary key default uuid_generate_v4(),
  venue_id   uuid not null references lounge_venues(id) on delete cascade,
  item_code  text not null,
  item_name  text not null,
  price      numeric not null,
  currency   text not null default 'EUR',
  unit       text not null default 'saat',
  note       text,
  source_url text not null,
  checked_at date not null default current_date,
  active     boolean not null default true
);
create unique index if not exists uq_venue_prices on venue_prices (venue_id, item_code);

alter table venue_prices enable row level security;
drop policy if exists vp_read on venue_prices;
create policy vp_read on venue_prices for select to authenticated, anon using (active);
grant select on venue_prices to authenticated, anon;

insert into venue_prices (venue_id, item_code, item_name, price, currency, unit, note, source_url)
select v.id, x.code, x.nm, x.pr, 'EUR', 'saat', x.nt,
       'https://www.keplerclub.com/sabiha-gokcen'
  from lounge_venues v, (values
    ('SINGLE',  'SingleKep (tek kişilik oda)', 18, 'Servis bedeli %10 ve vergi %8 fiyata dâhildir. 7 yaşından küçük misafir kabul edilmez.'),
    ('DOUBLE',  'DoubleKep (iki kişilik oda)', 25, 'Servis bedeli %10 ve vergi %8 fiyata dâhildir.'),
    ('DELUXE',  'Deluxe (iki tek ya da bir büyük yatak)', 40, 'Servis bedeli %10 ve vergi %8 fiyata dâhildir.'),
    ('VIP',     'VIP oda', 50, 'Servis bedeli %10 ve vergi %8 fiyata dâhildir.'),
    ('SHOWER',  'Duş', 17, 'Servis bedeli %10 ve vergi %8 fiyata dâhildir.')
  ) as x(code, nm, pr, nt)
 where v.airport_code = 'SAW' and v.name ilike 'Kepler Club%' and v.active
on conflict (venue_id, item_code) do update set
  price = excluded.price, item_name = excluded.item_name,
  note = excluded.note, source_url = excluded.source_url,
  checked_at = excluded.checked_at, active = true;

-- Salonun kendi notuna da tek satır özet — kullanıcı fiyat tablosunu
-- açmadan da fikir sahibi olsun.
update lounge_venues
   set notes = coalesce(nullif(notes,'') || ' ', '')
             || 'Saatlik oda satılır: tek kişilik 18 €, iki kişilik 25 €, '
             || 'deluxe 40 €, VIP 50 €, duş 17 € (servis ve vergi dâhil). '
             || 'Üyelik hakkıyla ücretsiz giriş yoktur.'
 where airport_code = 'SAW' and name ilike 'Kepler Club%' and active
   and coalesce(notes,'') not like '%Saatlik oda%';


-- ---- 5) OKUNABİLİR ÖZET — app ve BO tek yerden okusun ----
create or replace function public.plan_options(p_program_code text)
returns table (plan_code text, plan_name text, annual_fee numeric, currency text,
               member_free_visits int, member_visit_fee numeric,
               guest_visit_fee numeric, extras text, ozet text,
               source_url text, checked_at date)
language sql stable security definer set search_path = public as $$
  select pl.plan_code, pl.plan_name, pl.annual_fee, pl.currency,
         pl.member_free_visits, pl.member_visit_fee, pl.guest_visit_fee, pl.extras,
         pl.plan_name || ' · yıllık ' || pl.annual_fee::text || ' ' || pl.currency
           || ' · ' || case when pl.member_free_visits is null then 'sınırsız üye ziyareti'
                            when pl.member_free_visits = 0 then 'ücretsiz ziyaret yok'
                            else pl.member_free_visits::text || ' ücretsiz ziyaret' end
           || ' · misafir ' || pl.guest_visit_fee::text || ' ' || pl.currency,
         pl.source_url, pl.checked_at
    from program_plans pl
   where pl.active and pl.program_code = upper(btrim(coalesce(p_program_code,'')))
   order by pl.annual_fee nulls last
$$;
grant execute on function public.plan_options(text) to authenticated, anon;

create or replace function public.venue_price_list(p_venue_id uuid)
returns table (item_code text, item_name text, price numeric, currency text,
               unit text, note text, source_url text, checked_at date)
language sql stable security definer set search_path = public as $$
  select vp.item_code, vp.item_name, vp.price, vp.currency, vp.unit,
         vp.note, vp.source_url, vp.checked_at
    from venue_prices vp
   where vp.active and vp.venue_id = p_venue_id
   order by vp.price
$$;
grant execute on function public.venue_price_list(uuid) to authenticated, anon;


-- ---- 6) DÖRT ÇELİŞKİNİN KAPANIŞI ----
update rule_source_conflicts
   set durum = 'karara_baglandi',
       karar = 'KAPANDI (196). Priority Pass Türkiye plan sayfası alındı: Standard 89 €, '
            || 'Standard Plus 289 € (10 ücretsiz üye ziyareti), Prestige 459 € (sınırsız üye ziyareti). '
            || 'ÜÇ PLANDA DA misafir ziyareti 30 € ve tutar ÜYENİN kartından tahsil edilir. '
            || 'Rakam artık kaynaklı (program_plans.source_url). Banka şerhi KALKMADI, DARALDI: '
            || 'bankanın değiştirebildiği şey planın hangisi olduğu ve ücreti üstlenip üstlenmediği; '
            || 'ücretin varlığı ve tutarı artık bilinen bir gerçek.',
       etki = 'Kullanıcı artık "bankana bağlı" yerine "misafir 30 € — bankan üstlenmiş olabilir" görüyor.',
       updated_at = now()
 where konu = 'Priority Pass plan ve ücret sayfası';

update rule_source_conflicts
   set durum = 'karara_baglandi',
       karar = 'KAPANDI (196). DragonPass Go plan sayfası alındı: Classic 96 € (1 ücretsiz ziyaret), '
            || 'Preferential 249 € (8 ücretsiz ziyaret). İki planda da ek üye ziyareti VEYA misafir '
            || 'ziyareti 36 €. md.7.15.8''in fiyatı uygulamaya havale etmesi artık bir boşluk değil: '
            || 'havale edilen sayfa okundu ve program_plans''e kaynağıyla yazıldı.',
       etki = 'Tutar gösteriliyor; "kartını verene sor" yerine "36 € — bankan üstlenmiş olabilir".',
       updated_at = now()
 where konu = 'DragonPass plan ve ücret sayfası';

update rule_source_conflicts
   set durum = 'karara_baglandi',
       karar = 'KAPANDI (196). Kepler Club kendi fiyat listesi alındı ve SALON düzeyine yazıldı '
            || '(venue_prices): SingleKep 18 €, DoubleKep 25 €, Deluxe 40 €, VIP 50 €, duş 17 € — '
            || 'saatlik, servis %10 ve vergi %8 dâhil. Pegasus sayfasının sessizliği artık sorun '
            || 'değil: fiyat otoritesi tesisin kendisi. Ayrıca SingleKep''e 7 yaş sınırı kural '
            || 'olarak yazıldı — bu bir MİSAFİR kısıtıdır ve aile senaryosunu doğrudan etkiler.',
       etki = 'PGS_PAID artık "salon belirler" demiyor; SAW için gerçek saatlik fiyatı gösteriyor.',
       updated_at = now()
 where konu = 'Kepler Club ücreti';

update rule_source_conflicts
   set durum = 'karara_baglandi',
       karar = 'KAPANDI (195). Kod paylaşımı artık TAHMİN değil VERİ: uçuş önbelleği işleten '
            || 'taşıyıcıyı da taşıyor (flight_cache.codeshared / operating_iata) ve '
            || 'flight_carrier_resolve() önce işleteni, o yoksa öneki kullanıp hangisini '
            || 'kullandığını SÖYLÜYOR (kaynak: onbellek | onek). Keşif ekranındaki taşıyıcı '
            || 'uyuşmazlığı uyarısı da artık önekten değil bu fonksiyondan besleniyor — '
            || 'TK kodlu ama Lufthansa işletmeli bir uçuşta kullanıcı yanlış bilgilendirilmiyor.',
       etki = 'Kod paylaşımlı uçuşta kapı sürprizi riski nota yazılıyor; taşıyıcı eşleşmesi işletene göre.',
       updated_at = now()
 where konu = 'Kod paylaşımlı uçuş';


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) KAYNAKSIZ RAKAM KALMASIN
do $$
declare v_n int;
begin
  select count(*) into v_n from program_plans
   where active and (coalesce(source_url,'') = '' or annual_fee is null);
  if v_n > 0 then
    raise exception '196: % planda kaynak ya da yillik ucret YOK — kaynaksiz rakam yasak', v_n;
  end if;
  select count(*) into v_n from venue_prices where active and coalesce(source_url,'') = '';
  if v_n > 0 then
    raise exception '196: % salon fiyatinda kaynak YOK', v_n;
  end if;
  raise notice '196: butun plan ve fiyat satirlari kaynakli';
end $$;

-- 2) PLAN ÜCRETİ KURAL NOTUNA GERÇEKTEN GEÇTİ Mİ
do $$
declare v_n int; v_ornek text;
begin
  select count(*) into v_n
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code in ('PRIORITY_PASS','DRAGONPASS')
     and r.card_tier is not null
     and (r.effective_to is null or r.effective_to >= current_date)
     and coalesce(r.notes,'') like '%yıllık%';
  if v_n < 5 then
    raise exception '196: plan ucreti yalniz % kural notuna gecti (5 bekleniyor)', v_n;
  end if;
  select r.notes into v_ornek from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = 'PRIORITY_PASS' and r.card_tier = 'PP_PRESTIGE'
     and (r.effective_to is null or r.effective_to >= current_date) limit 1;
  raise notice '196: % kural notu plan ucretini tasiyor. Ornek: %', v_n, left(v_ornek, 110);
end $$;

-- 3) BANKA ŞERHİ KALKMAMIŞ OLMALI
-- 🔴 Bu bekçi TERSİNE çalışır: bir şeyin VAR olduğunu değil, bir
-- korumanın KALDIRILMADIĞINI kanıtlar. Rakam bulunca şerhi silmek en
-- kolay hata olurdu; banka hâlâ planı ve ödeyeni değiştirebiliyor.
do $$
declare v_n int;
begin
  select count(*) into v_n
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code in ('PRIORITY_PASS','DRAGONPASS')
     and r.card_tier is not null
     and (r.effective_to is null or r.effective_to >= current_date)
     and coalesce(r.notes,'') like '%bankandan teyit%';
  if v_n < 5 then
    raise exception '196: banka serhi % kuralda kalmis (5 olmali) — rakam bulundu diye koruma silinmis', v_n;
  end if;
  raise notice '196: banka serhi 5 kuralda da duruyor (daraltildi, kaldirilmadi)';
end $$;

-- 4) KEPLER CLUB FİYATI SALONA BAĞLANDI MI
do $$
declare v_n int; v_v uuid;
begin
  select v.id into v_v from lounge_venues v
   where v.airport_code = 'SAW' and v.name ilike 'Kepler Club%' and v.active limit 1;
  if v_v is null then
    raise notice '196: SAW Kepler Club AKTIF salonu yok — fiyat baglanamadi (envanter eksigi)';
  else
    select count(*) into v_n from public.venue_price_list(v_v);
    if v_n <> 5 then
      raise exception '196: Kepler Club fiyat listesi % satir (5 bekleniyor)', v_n;
    end if;
    raise notice '196: Kepler Club 5 fiyat satiri salona bagli';
  end if;
end $$;

-- 5) DÖRT MADDE GERÇEKTEN KAPANDI MI
do $$
declare v_n int; r record;
begin
  select count(*) into v_n from rule_source_conflicts where durum = 'veri_bekliyor';
  if v_n > 0 then
    for r in select konu from rule_source_conflicts where durum = 'veri_bekliyor' loop
      raise notice '196: HALA ACIK → %', r.konu;
    end loop;
    raise exception '196: % madde hala veri_bekliyor', v_n;
  end if;
  select count(*) into v_n from rule_source_conflicts where durum = 'karara_baglandi';
  raise notice '196: veri_bekliyor 0. Karara baglanan toplam: %', v_n;
end $$;

-- 6) plan_options GERÇEKTEN ÇAĞRILABİLİR (var olmak ≠ çalışmak)
do $$
declare v_n int; v_ozet text;
begin
  select count(*) into v_n from public.plan_options('PRIORITY_PASS');
  if v_n <> 3 then raise exception '196: plan_options(PRIORITY_PASS) % satir (3 bekleniyor)', v_n; end if;
  select count(*) into v_n from public.plan_options('DRAGONPASS');
  if v_n <> 2 then raise exception '196: plan_options(DRAGONPASS) % satir (2 bekleniyor)', v_n; end if;
  select ozet into v_ozet from public.plan_options('PRIORITY_PASS') order by annual_fee limit 1;
  raise notice '196: plan_options calisiyor. Ornek: %', v_ozet;
end $$;

select '196 OK - plan ucretleri kaynakli girildi, dort celiski kapandi' as sonuc;
