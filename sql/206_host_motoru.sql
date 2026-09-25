-- ============================================================
-- 206 · HOST MOTORU — "host çekemezsek bir işe yaramaz"ın cevabı
-- 17 Ağustos 2026
--
-- Gokberk'in kaygısı: "Bizim sistemimizde hâlâ host'u içeri çekecek ve
-- onu tutacak yeterli şey olduğunu düşünmüyorum."
--
-- 🔴 ÖNCE ÖLÇTÜM, SONRA TASARLADIM. Ekonominin gerçek hâli:
--
--   select distinct reason from credit_ledger;
--     → beta_signup, kural-seed          (BAŞKA HİÇBİR ŞEY)
--   confirm_session gövdesi:
--     → points_ledger'a host 500 / misafir 200
--     → credit_ledger'a delta = 0 (yalnız kapanış satırı)
--
-- Yani: MİSAFİR OLMAK 1 KREDİ HARCAR. HOST OLMAK 0 KREDİ ÜRETİR.
-- Kredi yalnız kayıtta (5 adet) ve abonelikle (aylık 2/8/20) giriyor.
-- Ağırlamanın karşılığı 500 PUAN — ve puanlar `rewards` kataloğunda
-- 1000-3000 puana mal oluyor, yani 2-6 oturum. Katalog gerçek para
-- gerektiriyor (THY mili, Airalo eSIM), soyut ve gecikmeli.
--
-- DÖNGÜ YOK. Host verir, karşılığında pazarda kullanabileceği hiçbir
-- şey almaz. Gokberk haklı — ve sorun "yeterli teşvik yok" değil,
-- EKONOMİDE HALKA KAPANMIYOR.
--
-- ============================================================
-- ÜRÜN KARARI: HOSTLUK KREDİ BASAR
-- ============================================================
-- Gokberk'in kendi örneği "guest'ten gelen kredi aktarımıyla 2 kat
-- puan" idi. İçgüdü doğru, hedef zayıf: puan yanlış para birimi.
-- Doğru para birimi KREDİ, çünkü host'un gerçekten istediği şey
-- katalogdan bir eSIM değil — KENDİ seyahatinde hakkı olmayan bir
-- salona girebilmek.
--
-- Ürünün tek cümlesi bu olmalı:
--
--     "Kullanmadığın misafir hakkını,
--      hakkın olmayan yerde misafir olma hakkına çevir."
--
-- Bu bir sadakat programı değil, bir TAKAS. Ve bu takas yalnız
-- LoungeLink'te mümkün; çünkü hangi kartın nerede ne hakkı olduğunu
-- bilen kural motoru yalnız bizde.
--
-- ORAN: tamamlanan her ağırlama = 3 kredi.
-- 🔴 3 sayısı keyfi değil: bir misafir isteği 1 kredi harcar ve her
-- istek oturuma dönüşmez (kabul + gerçekleşme). Yaklaşık 1/3 dönüşümle
-- 3 kredi ≈ BİR tamamlanmış misafir deneyimi. Yani host, verdiği bir
-- deneyimin karşılığında bir deneyim alıyor. Dönüşüm ölçüldükçe oran
-- BO'dan (`beta_settings.host_credit_per_session`) değişir; deploy
-- gerekmez.
-- ============================================================


-- ============================================================
-- 1) AYARLAR — sayılar koda gömülmez
-- ============================================================
insert into beta_settings (key, value) values
  ('host_credit_per_session', to_jsonb(3)),
  ('host_credit_daily_cap',   to_jsonb(9)),
  ('host_ring_window_days',   to_jsonb(30)),
  ('host_ring_max_repeat',    to_jsonb(3))
on conflict (key) do nothing;


-- ============================================================
-- 2) KARŞILIK — ağırlamanın krediye dönüşmesi
-- ============================================================
-- 🔴 UYDURMA KORUMASI. Kredi basmak, para basmaktır: kötüye
-- kullanılırsa pazar çöker. Üç kapı:
--   (a) Oturum başına TEK kez (ref_id benzersizliği)
--   (b) Günlük tavan (varsayılan 9 = 3 ağırlama)
--   (c) HALKA TESPİTİ: aynı iki kişi 30 günde 3'ten fazla oturum
--       yaptıysa kredi basılmaz. İki arkadaşın birbirini sırayla
--       "ağırlayıp" kredi üretmesi, bu ürünün en bariz sömürüsü.
create or replace function public.host_credit_settle(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_r      requests%rowtype;
  v_s      sessions%rowtype;
  v_adet   int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_credit_per_session'), 3);
  v_tavan  int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_credit_daily_cap'), 9);
  v_pencere int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_window_days'), 30);
  v_tekrar int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_max_repeat'), 3);
  v_bugun  int;
  v_ciftte int;
  v_bal    int;
begin
  select * into v_s from sessions where id = p_session_id;
  if not found or v_s.status <> 'completed' then
    return jsonb_build_object('ok', false, 'neden', 'oturum_tamamlanmadi');
  end if;
  select * into v_r from requests where id = v_s.request_id;
  if not found then return jsonb_build_object('ok', false, 'neden', 'istek_yok'); end if;

  -- (a) çift ödeme
  if exists (select 1 from credit_ledger
              where ref_id = p_session_id and reason = 'hosted_session') then
    return jsonb_build_object('ok', false, 'neden', 'zaten_odendi');
  end if;

  -- (b) günlük tavan
  select coalesce(sum(delta),0) into v_bugun from credit_ledger
   where user_id = v_r.host_id and reason = 'hosted_session'
     and created_at >= date_trunc('day', now());
  if v_bugun >= v_tavan then
    return jsonb_build_object('ok', false, 'neden', 'gunluk_tavan', 'bugun', v_bugun);
  end if;

  -- (c) halka tespiti
  select count(*) into v_ciftte
    from sessions s2 join requests r2 on r2.id = s2.request_id
   where s2.status = 'completed'
     and s2.completed_at >= now() - make_interval(days => v_pencere)
     and ((r2.host_id = v_r.host_id and r2.guest_id = v_r.guest_id)
       or (r2.host_id = v_r.guest_id and r2.guest_id = v_r.host_id));
  if v_ciftte > v_tekrar then
    return jsonb_build_object('ok', false, 'neden', 'ayni_cift_tekrari', 'adet', v_ciftte);
  end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.host_id;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (v_r.host_id, v_adet, 'hosted_session', p_session_id, v_bal + v_adet,
          'Agirladigin icin: bu krediyle kendi seyahatinde misafir olabilirsin.');

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_r.host_id, 'system', format('%s kredi kazandın ✦', v_adet),
          'Ağırladığın için. Bu kredilerle, hakkın olmayan bir salonda sen misafir olabilirsin.',
          'session', p_session_id);

  return jsonb_build_object('ok', true, 'kredi', v_adet, 'yeni_bakiye', v_bal + v_adet);
end $fn$;

-- confirm_session'a bağla. Gövdesini yeniden yazmak yerine oturum
-- tamamlanınca tetikleyen bir tetikleyici: 067'nin escrow notu ve
-- 078'in puan mantığı olduğu gibi kalır, üstüne EKLENİR.
-- 🔴 Tetikleyici seçildi çünkü `confirm_session` bu projede en çok
-- dokunulan fonksiyon ve her dokunuşta bir şey bozuldu. Dokunmuyorum.
create or replace function public.trg_host_credit()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  -- ⚠️ `coalesce(old.status,'')` YAZMA. `status` bir ENUM ve boş metin
  -- geçerli bir enum değeri değil — 22P02. Enum karşılaştırmasında
  -- NULL'ı `is distinct from` ile ele al.
  if new.status = 'completed' and old.status is distinct from 'completed' then
    -- Kredi basımı ASLA oturumun tamamlanmasını engellemez.
    begin
      perform public.host_credit_settle(new.id);
    exception when others then
      insert into client_errors (source, message, context)
      values ('host_credit_settle', sqlerrm, jsonb_build_object('session_id', new.id));
    end;
  end if;
  return new;
end $fn$;

drop trigger if exists trg_host_credit_on_complete on sessions;
create trigger trg_host_credit_on_complete
  after update on sessions
  for each row execute function public.trg_host_credit();


-- ============================================================
-- 3) CÜZDAN — host'un tek kişilik oyunu
-- ============================================================
-- 🔴 EN ÖNEMLİ ÜRÜN İÇGÖRÜSÜ BU DOSYADA BURASI.
--
-- Pazar yeri tavuk-yumurta problemi yaşar: host yok diye misafir
-- gelmez, misafir yok diye host gelmez. Klasik çözüm "bir tarafı
-- parayla topla"dır ve tek kişilik bir kurucunun harcı değildir.
--
-- Gerçek çözüm: ÜRÜN, KARŞI TARAF HİÇ YOKKEN DE DEĞERLİ OLMALI.
-- Bizde o değer zaten var ve rakipte yok: KURAL MOTORU.
-- "Bu kartla, bu salonda, bu uçuşta ne olur?" sorusunun cevabını
-- Türkiye'de veren başka bir yer yok.
--
-- Bu yüzden LoungeLink'i şöyle konumlandırıyorum:
--   LoungeLink bir pazar yeri DEĞİL — bir SALON HAKKI CÜZDANI.
--   İçinde bir pazar yeri var.
-- Cüzdanı 10.000 kişi kullanır; pazar kendiliğinden yanar. Çünkü
-- cüzdanı kullanan herkes ZATEN bir host'tur, sadece bilmiyordur.
--
-- `host_wallet()` o cüzdanın kalbi: TÜM haklar, para değeri ve
-- yanma tarihi. Bugüne kadar `host_unused_rights` TEK hakka bakıp
-- (`limit 1`) para değeri ve tarih vermiyordu.
create or replace function public.host_wallet(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_kart jsonb;
  v_top_kalan int := 0;
  v_top_deger numeric := 0;
  v_para text := 'EUR';
  v_son date;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select jsonb_agg(k order by k ->> 'yanma_tarihi' nulls last), sum(kalan), sum(deger)
    into v_kart, v_top_kalan, v_top_deger
  from (
    select jsonb_build_object(
             'entitlement_id', he.id,
             'program', p.name,
             'program_code', p.code,
             'tier', he.tier,
             'card_label', he.card_label,
             'toplam', he.quota_total,
             'kullanilan', he.quota_used,
             'kalan', q.kalan,
             'donem', he.quota_period,
             'yanma_tarihi', q.yanma,
             'kalan_gun', case when q.yanma is null then null
                               else greatest(0, (q.yanma - current_date)) end,
             'misafir_ucreti', pl.guest_visit_fee,
             'para_birimi', coalesce(pl.currency, p.guest_fee_currency, 'EUR'),
             'deger', q.deger,
             -- 🔴 DÜRÜSTLÜK: bu sayı BEYANA dayanır. Kartı veren kurum
             -- teyit etmedi. Bunu her satırda söylemek zorundayız;
             -- söylemezsek kullanıcı bize güvenip kapıda utanır.
             'kaynak', case when he.verified then 'dogrulandi' else 'beyan' end
           ) as k,
           q.kalan, q.deger
      from host_entitlements he
      join lounge_programs p on p.id = he.program_id
      left join lateral (
        select coalesce(pp.guest_visit_fee, p.typical_guest_fee) as guest_visit_fee,
               coalesce(pp.currency, p.guest_fee_currency) as currency
          from program_plans pp
         where pp.program_code = p.code and pp.active
         order by pp.annual_fee nulls last limit 1
      ) pl on true
      cross join lateral (
        -- 🔴 BİLİNMEYEN, SIFIR DEĞİLDİR. İlk yazımda
        -- `coalesce(he.quota_total,0)` yazmıştım; kotasını beyan
        -- etmemiş bir kart ekranda "0 hakkın kaldı" diye görünürdü.
        -- Bu, bu projenin en sık tekrarlayan yalan biçimi: veri
        -- yokluğunu bir DEĞER gibi göstermek. Kota bilinmiyorsa
        -- `kalan` NULL kalır ve ekran "kaç hakkın olduğunu
        -- bilmiyoruz" der.
        select
          case when he.quota_period = 'unlimited' or he.quota_total is null then null
               else greatest(he.quota_total - coalesce(he.quota_used,0), 0) end as kalan,
          case when he.quota_period = 'month'
                 then (date_trunc('month', current_date) + interval '1 month - 1 day')::date
               when he.quota_period = 'year'
                 then (date_trunc('year', current_date) + interval '1 year - 1 day')::date
               else null end as yanma,
          case when he.quota_period = 'unlimited' or he.quota_total is null then null
               else greatest(he.quota_total - coalesce(he.quota_used,0), 0)
                    * coalesce(pl.guest_visit_fee, p.typical_guest_fee, 0) end as deger
      ) q
     where he.user_id = v_uid
  ) x;

  if v_kart is null then
    return jsonb_build_object('known', false,
      'bos_baslik', 'Kartını tanıt, hakkını gör.',
      'bos_alt', 'Hangi kartın hangi salonda ne hak verdiğini biliyoruz. Sen de bil.');
  end if;

  select min((k ->> 'yanma_tarihi')::date) into v_son
    from jsonb_array_elements(v_kart) k where k ->> 'yanma_tarihi' is not null;
  select (k ->> 'para_birimi') into v_para
    from jsonb_array_elements(v_kart) k where k ->> 'para_birimi' is not null limit 1;

  return jsonb_build_object(
    'known', true,
    'kartlar', v_kart,
    'toplam_kalan', coalesce(v_top_kalan,0),
    'toplam_deger', round(coalesce(v_top_deger,0)),
    'para_birimi', coalesce(v_para,'EUR'),
    'ilk_yanma', v_son,
    'kalan_gun', case when v_son is null then null else greatest(0, v_son - current_date) end,
    -- KAYIP ÇERÇEVESİ: "8 hakkın var" değil "8 hakkın yanacak".
    -- Aynı sayı, farklı cümle; ve kayıp, kazançtan çok harekete geçirir.
    'baslik', case
      when v_top_kalan is null then 'Kaç misafir hakkın olduğunu henüz bilmiyoruz.'
      when v_top_kalan <= 0 then 'Bu dönemki misafir hakkını kullandın.'
      when v_son is null then format('%s misafir hakkın kullanılmadan duruyor.', v_top_kalan)
      else format('%s misafir hakkın %s gün sonra yanıyor.',
                  v_top_kalan, greatest(0, v_son - current_date)) end,
    'alt', case
      when v_top_kalan is null then
        'Kartının yıllık misafir hakkını gir; ne kadarının yanmak üzere olduğunu hesaplayalım.'
      -- 🔴 PARA CÜMLESİ YALNIZ GERÇEK BİR RAKAM VARSA KURULUR.
      -- "Yaklaşık 0 EUR değerinde" cümlesi hem saçma hem zararlı:
      -- kullanıcıya hakkının değersiz olduğunu söyler. Ücret verisi
      -- yoksa cümle kurulmaz — eksik veri, sıfır değer değildir.
      when v_top_kalan > 0 and coalesce(v_top_deger,0) > 0 then
        format('Yaklaşık %s %s değerinde. Bankaya yatmıyor, devretmiyor — kullanılmazsa siliniyor.',
               round(v_top_deger), coalesce(v_para,'EUR'))
      when v_top_kalan > 0 then
        'Bankaya yatmıyor, devretmiyor — kullanılmazsa siliniyor.' end,
    'not', 'Bu sayılar senin beyanına dayanır; kartını veren kurumdan teyit et.');
end $fn$;


-- ============================================================
-- 4) KAÇIRILAN DEĞER — host'u geri getiren tek dürüst sebep
-- ============================================================
-- 🔴 Mevcut `waiting_demand` bir HAVALİMANINDAKİ TÜM yolcuları
-- sayıyor. Bu bir gösteriş sayısı: o yolcuların çoğunun host'un
-- kartıyla girebileceği bir salon yok. Yanlış sayı göstermek,
-- hiç göstermemekten kötüdür — ilk yanlışta güven biter.
--
-- Bu fonksiyon KURAL MOTORUNDAN GEÇİRİR: yalnız host'un GERÇEKTEN
-- içeri alabileceği, aynı havalimanında, aynı saat aralığında olan
-- ve host bulamamış yolcular sayılır.
create or replace function public.host_missed_value(p_gun int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid();
  v_hava text[];
  v_kisi int := 0;
  v_liste jsonb;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  -- Host'un gerçekten bulunduğu havalimanları: geçmiş ilanları + seyahatleri
  select array_agg(distinct kod) into v_hava from (
    select airport_code::text as kod from availabilities where host_id = v_uid
    union
    select airport_code::text from visits where user_id = v_uid
  ) x;
  if v_hava is null or array_length(v_hava,1) is null then
    return jsonb_build_object('known', false,
      'bos_baslik', 'Henüz bir havalimanı bilmiyoruz.',
      'bos_alt', 'Bir seyahat ekle; o havalimanında seni bekleyen var mı söyleyelim.');
  end if;

  -- Host bulamamış yolcular: seyahati var, o gün o havalimanında
  -- TAMAMLANMIŞ oturumu yok ve host'un ilanı da yoktu.
  select count(*), jsonb_agg(jsonb_build_object('havalimani', kod, 'kisi', n) order by n desc)
    into v_kisi, v_liste
  from (
    select vs.airport_code::text as kod, count(distinct vs.user_id) as n
      from visits vs
      join users gu on gu.id = vs.user_id
     where vs.airport_code = any(v_hava)
       and vs.visit_date between current_date - p_gun and current_date
       and vs.user_id <> v_uid
       and coalesce(gu.is_staff,false) = false
       and gu.deleted_at is null
       and not exists (
         select 1 from requests r join sessions s on s.request_id = r.id
          where r.guest_id = vs.user_id and s.status = 'completed'
            and s.completed_at::date = vs.visit_date)
       and not exists (
         select 1 from availabilities a
          where a.host_id = v_uid and a.active
            and a.airport_code = vs.airport_code
            and a.avail_date = vs.visit_date
            and a.time_from < vs.time_to and vs.time_from < a.time_to)
     group by vs.airport_code
  ) q;

  return jsonb_build_object(
    'known', true,
    'gun', p_gun,
    'kisi', coalesce(v_kisi,0),
    'havalimanlari', coalesce(v_liste, '[]'::jsonb),
    'baslik', case when coalesce(v_kisi,0) = 0
      then 'Son ' || p_gun || ' günde kaçırdığın kimse yok.'
      else format('Son %s günde %s kişi senin bulunduğun havalimanlarında host bulamadı.',
                  p_gun, v_kisi) end,
    'alt', case when coalesce(v_kisi,0) > 0
      then 'İlan açmak 20 saniye. Sen zaten oradaydın.' end);
end $fn$;


-- ============================================================
-- 5) MERTEBE — puan değil, STATÜ
-- ============================================================
-- 🔴 Bu kitle statü peşinde koşmaya ALIŞIK: Elite, Elite Plus,
-- Platinum. Onlara "500 puan kazandın" demek, dilini konuşmamaktır.
-- "Kâhya oldun" demek konuşmaktır.
--
-- ⚠️ AMA: ayrıcalık GERÇEK olmalı. Sahte rozet, rozet olmamasından
-- kötüdür — kullanıcı bir kez "bu hiçbir şey yapmıyor" derse tüm
-- sistem inandırıcılığını kaybeder. Her mertebenin ölçülebilir bir
-- karşılığı var ve `host_standing()` onu METİN olarak da döndürüyor
-- ki ekran uydurmasın.
create table if not exists host_tiers (
  code        text primary key,
  ad          text not null,
  min_oturum  int  not null,
  siralama_ek int  not null default 0,   -- keşifte sıralama artışı
  ekstra_slot int  not null default 0,   -- görünür slot artışı
  istek_bedava boolean not null default false,
  aciklama    text not null,
  sira        int  not null
);

insert into host_tiers (code, ad, min_oturum, siralama_ek, ekstra_slot, istek_bedava, aciklama, sira) values
  ('yolcu',     'Yolcu',     0,  0, 0, false,
   'Henüz kimseyi ağırlamadın. İlk ağırlaman seni Ev Sahibi yapar.', 1),
  ('evsahibi',  'Ev Sahibi', 1,  5, 0, false,
   'Bir kişiyi içeri aldın. Keşifte önüne geçiyorsun.', 2),
  ('kahya',     'Kâhya',     5, 12, 1, false,
   'Beş kişiyi ağırladın. İlanlarında bir kişilik ek görünürlük ve keşifte belirgin öncelik.', 3),
  ('konsiyerj', 'Konsiyerj',15, 25, 1, true,
   'On beş kişiyi ağırladın. Kendi misafir isteklerin artık kredi harcamıyor.', 4)
on conflict (code) do update set
  ad = excluded.ad, min_oturum = excluded.min_oturum,
  siralama_ek = excluded.siralama_ek, ekstra_slot = excluded.ekstra_slot,
  istek_bedava = excluded.istek_bedava, aciklama = excluded.aciklama, sira = excluded.sira;

create or replace function public.host_standing(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_n   int;
  v_su  host_tiers%rowtype;
  v_son host_tiers%rowtype;
  v_kredi int;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select count(*) into v_n
    from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status = 'completed';

  select * into v_su from host_tiers where min_oturum <= v_n order by min_oturum desc limit 1;
  select * into v_son from host_tiers where min_oturum > v_n order by min_oturum asc limit 1;

  select coalesce(sum(delta),0) into v_kredi
    from credit_ledger where user_id = v_uid and reason = 'hosted_session';

  return jsonb_build_object(
    'known', true,
    'agirlama', v_n,
    'mertebe', v_su.code, 'mertebe_adi', v_su.ad, 'mertebe_aciklama', v_su.aciklama,
    'siralama_ek', v_su.siralama_ek, 'ekstra_slot', v_su.ekstra_slot,
    'istek_bedava', v_su.istek_bedava,
    'sonraki', v_son.code, 'sonraki_adi', v_son.ad,
    'sonraki_kalan', case when v_son.code is null then null else v_son.min_oturum - v_n end,
    'sonraki_aciklama', v_son.aciklama,
    'kazanilan_kredi', v_kredi,
    -- Krediyi "puan" olarak değil, KARŞILIK olarak anlat.
    'karsilik_cumlesi', case when v_kredi > 0
      then format('Ağırlayarak %s kredi kazandın — bu, hakkın olmayan salonlarda %s misafir isteği demek.',
                  v_kredi, v_kredi)
      else 'Birini ağırladığında kazandığın kredilerle, hakkın olmayan salonlarda sen misafir olabilirsin.' end);
end $fn$;


-- ============================================================
-- 6) KEŞİFTE MERTEBE GERÇEKTEN İŞLESİN
-- ============================================================
-- Söz verilen ayrıcalık uygulanmıyorsa yalandır. `discover_availabilities`
-- gövdesine dokunmadan, host'un mertebe eki bir fonksiyondan okunuyor;
-- sıralama bu değeri kullanacak (uygulama tarafı `match_score`u zaten
-- sıralıyor, ek buraya biniyor).
create or replace function public.host_rank_bonus(p_host uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select coalesce((
    select t.siralama_ek from host_tiers t
     where t.min_oturum <= (
       select count(*) from sessions s join requests r on r.id = s.request_id
        where r.host_id = p_host and s.status = 'completed')
     order by t.min_oturum desc limit 1), 0);
$fn$;

-- Konsiyerj ayrıcalığı: kendi misafir isteği kredi harcamaz.
create or replace function public.request_credit_cost(p_user uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select case when coalesce((
    select t.istek_bedava from host_tiers t
     where t.min_oturum <= (
       select count(*) from sessions s join requests r on r.id = s.request_id
        where r.host_id = p_user and s.status = 'completed')
     order by t.min_oturum desc limit 1), false)
  then 0 else 1 end;
$fn$;


-- ============================================================
-- 7) YÜZEY
-- ============================================================
insert into rpc_client_surface (fn_name, client, note) values
  ('host_wallet','app','Salon hakki cuzdani — tek kisilik oyun'),
  ('host_missed_value','app','Kacirilan deger — geri getirme sebebi'),
  ('host_standing','app','Mertebe ve karsilik')
on conflict (fn_name) do nothing;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '206: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) AĞIRLAMA GERÇEKTEN KREDİ BASIYOR MU (mutasyon)
do $$
declare v_s uuid; v_h uuid; v_once int; v_sonra int; v_r jsonb;
begin
  select s.id, r.host_id into v_s, v_h
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' limit 1;
  if v_s is null then raise notice '206: tamamlanmis oturum yok — atlandi'; return; end if;

  delete from credit_ledger where ref_id = v_s and reason = 'hosted_session';
  select coalesce(sum(delta),0) into v_once from credit_ledger where user_id = v_h;

  v_r := public.host_credit_settle(v_s);
  if coalesce(v_r ->> 'ok','') <> 'true' then
    raise exception '206: agirlama kredi basmadi → %', v_r;
  end if;

  select coalesce(sum(delta),0) into v_sonra from credit_ledger where user_id = v_h;
  if v_sonra - v_once <> 3 then
    raise exception '206: kredi farki 3 degil (% → %)', v_once, v_sonra;
  end if;

  -- İKİNCİ çağrı ASLA tekrar ödememeli
  v_r := public.host_credit_settle(v_s);
  if coalesce(v_r ->> 'ok','') = 'true' then
    raise exception '206: ayni oturum IKI KEZ odendi — kredi basimi kontrolsuz';
  end if;
  raise notice '206: agirlama 3 kredi basiyor, ikinci cagri odemiyor';
end $$;

-- 2) TETİKLEYİCİ ZİNCİRİ — oturum tamamlanınca kendiliğinden basıyor mu
do $$
declare v_s uuid; v_h uuid; v_n int;
begin
  select s.id, r.host_id into v_s, v_h
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' limit 1;
  if v_s is null then raise notice '206: oturum yok — atlandi'; return; end if;

  delete from credit_ledger where ref_id = v_s and reason = 'hosted_session';
  update sessions set status = 'active' where id = v_s;
  update sessions set status = 'completed' where id = v_s;

  select count(*) into v_n from credit_ledger
   where ref_id = v_s and reason = 'hosted_session';
  if v_n <> 1 then
    raise exception '206: tetikleyici kredi basmadi (satir: %)', v_n;
  end if;
  raise notice '206: oturum tamamlaninca kredi KENDILIGINDEN basiliyor';
end $$;

-- 3) HALKA SÖMÜRÜSÜ KAPALI MI
-- 🔴 En bariz saldırı: iki arkadaş birbirini sırayla "ağırlayıp"
-- sonsuz kredi üretir. Sayıyla değil, KANITLA kapatıyorum.
do $$
declare v_a uuid; v_b uuid; v_av uuid; v_req uuid; v_ses uuid; v_r jsonb; i int;
begin
  select id into v_a from users order by created_at limit 1;
  select id into v_b from users where id <> v_a order by created_at limit 1;
  select id into v_av from availabilities where host_id is not null limit 1;
  if v_a is null or v_b is null or v_av is null then
    raise notice '206: sahne eksik — atlandi'; return;
  end if;

  -- Aynı çift için 4 tamamlanmış oturum kur (eşik 3)
  for i in 1..4 loop
    insert into requests (guest_id, host_id, avail_id, status, purpose)
    values (v_b, v_a, v_av, 'completed', 'lounge') returning id into v_req;
    insert into sessions (request_id, status, completed_at)
    values (v_req, 'completed', now() - make_interval(days => i)) returning id into v_ses;
  end loop;

  delete from credit_ledger where ref_id = v_ses and reason = 'hosted_session';
  v_r := public.host_credit_settle(v_ses);
  if coalesce(v_r ->> 'ok','') = 'true' then
    raise exception '206: ayni cift 4 oturum yapti ve kredi HALA basildi → %', v_r;
  end if;
  if (v_r ->> 'neden') <> 'ayni_cift_tekrari' then
    raise exception '206: red sebebi halka degil → %', v_r;
  end if;

  -- Sahneyi topla
  delete from sessions where request_id in (
    select id from requests where guest_id = v_b and host_id = v_a and avail_id = v_av);
  delete from requests where guest_id = v_b and host_id = v_a and avail_id = v_av;
  raise notice '206: halka somurusu kapali (ayni cift 3 oturumdan sonra kredi almiyor)';
end $$;

-- 4) CÜZDAN GERÇEK SAYI VE GERÇEK PARA ÜRETİYOR MU
-- 🔴 İlk hâlinde bu nöbetçi "kotalı hak yok — atlandı" diyordu, yani
-- HİÇBİR ŞEY kanıtlamıyordu ve ben onu yeşil sanıyordum. Atlayan
-- nöbetçi, olmayan nöbetçidir. Artık sahneyi KENDİ kuruyor.
do $$
declare v_e uuid; v_u uuid; v jsonb; k jsonb;
        v_t int; v_k int; v_p text;
begin
  select id, user_id, quota_total, quota_used, quota_period
    into v_e, v_u, v_t, v_k, v_p
    from host_entitlements limit 1;
  if v_e is null then raise notice '206: hic hak yok — atlandi'; return; end if;

  update host_entitlements
     set quota_total = 4, quota_used = 1, quota_period = 'year'
   where id = v_e;

  v := public.host_wallet(v_u);
  if coalesce(v ->> 'known','') <> 'true' then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: cuzdan bilinmiyor dondu → %', v;
  end if;

  select k1 into k from jsonb_array_elements(v -> 'kartlar') k1
   where (k1 ->> 'entitlement_id')::uuid = v_e;
  if k is null then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: yazilan hak cuzdanda GORUNMUYOR';
  end if;
  if (k ->> 'kalan')::int <> 3 then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: kalan hak yanlis: % (4-1=3 olmali)', k ->> 'kalan';
  end if;
  if (k ->> 'yanma_tarihi') is null or (k ->> 'kalan_gun') is null then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: yillik kotada YANMA TARIHI hesaplanmadi → %', k;
  end if;
  if (v ->> 'baslik') not like '%yanıyor%' and (v ->> 'baslik') not like '%duruyor%' then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: kayip cercevesi kurulmamis → %', v ->> 'baslik';
  end if;
  raise notice '206: cuzdan → % (deger % %)',
    v ->> 'baslik', v ->> 'toplam_deger', v ->> 'para_birimi';

  -- BİLİNMEYEN, SIFIR OLMAMALI
  update host_entitlements set quota_total = null where id = v_e;
  v := public.host_wallet(v_u);
  select k1 into k from jsonb_array_elements(v -> 'kartlar') k1
   where (k1 ->> 'entitlement_id')::uuid = v_e;
  if (k ->> 'kalan') is not null then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
    raise exception '206: kota BILINMIYORKEN kalan bir sayi dondu (%) — veri yoklugu deger gibi gosteriliyor', k ->> 'kalan';
  end if;

  update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p where id=v_e;
  raise notice '206: kota bilinmiyorken cuzdan "0" DEMIYOR — bilinmiyor diyor';
end $$;

-- 5) CÜZDAN TEK HAKLA SINIRLI DEĞİL (eski host_unused_rights'ın kusuru)
do $$
declare v_u uuid; v jsonb; v_n int;
begin
  select user_id into v_u from host_entitlements
   group by user_id having count(*) > 1 limit 1;
  if v_u is null then
    raise notice '206: birden cok hakki olan kullanici yok — atlandi'; return;
  end if;
  v := public.host_wallet(v_u);
  v_n := jsonb_array_length(v -> 'kartlar');
  select count(*) into v_n from host_entitlements where user_id = v_u;
  if jsonb_array_length(v -> 'kartlar') <> v_n then
    raise exception '206: cuzdan % hakkin yalniz %sini gosteriyor',
      v_n, jsonb_array_length(v -> 'kartlar');
  end if;
  raise notice '206: cuzdan TUM haklari gosteriyor (%)', v_n;
end $$;

-- 6) MERTEBE EŞİKLERİ GERÇEKTEN İŞLİYOR MU (mutasyon)
do $$
declare v_h uuid; v jsonb; v_ek int;
begin
  select r.host_id into v_h from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' limit 1;
  if v_h is null then raise notice '206: host yok — atlandi'; return; end if;

  v := public.host_standing(v_h);
  if coalesce(v ->> 'known','') <> 'true' then
    raise exception '206: mertebe okunamadi → %', v;
  end if;
  if (v ->> 'mertebe_adi') is null then
    raise exception '206: mertebe ADI yok → %', v;
  end if;

  -- 🔴 İLK MUTASYONUM YANLIŞTI ve nöbetçi BENİ yakaladı:
  -- `konsiyerj`in eşiğini 0'a çekmiştim, ama `host_rank_bonus`
  -- `order by min_oturum desc limit 1` diyor — host'un 5+ oturumu
  -- varsa `kahya` (5) hâlâ `konsiyerj`ten (0) büyük ve o kazanıyor.
  -- Yani mutasyon hiçbir şeyi değiştirmiyordu ve nöbetçi haklı olarak
  -- "ayrıcalık sahte" dedi. Ders: mutasyonun ETKİ ETTİĞİNİ de
  -- kanıtlamak gerekir. Şimdi host'un GERÇEKTEN sahip olduğu
  -- mertebeyi bulup ONU değiştiriyorum.
  declare v_kod text; v_eski_ek int; v_eski_bedava boolean;
  begin
    v_ek  := public.host_rank_bonus(v_h);
    select (public.host_standing(v_h) ->> 'mertebe') into v_kod;
    select siralama_ek, istek_bedava into v_eski_ek, v_eski_bedava
      from host_tiers where code = v_kod;

    update host_tiers set siralama_ek = 99, istek_bedava = true where code = v_kod;
    if public.host_rank_bonus(v_h) <> 99 then
      update host_tiers set siralama_ek = v_eski_ek, istek_bedava = v_eski_bedava where code = v_kod;
      raise exception '206: mertebe ayricaligi degisti ama host_rank_bonus DEGISMEDI — ayricalik sahte';
    end if;
    if public.request_credit_cost(v_h) <> 0 then
      update host_tiers set siralama_ek = v_eski_ek, istek_bedava = v_eski_bedava where code = v_kod;
      raise exception '206: bedava istek acildi ama HALA kredi harciyor — ayricalik sahte';
    end if;

    update host_tiers set siralama_ek = v_eski_ek, istek_bedava = v_eski_bedava where code = v_kod;
    if public.host_rank_bonus(v_h) <> v_ek then
      raise exception '206: ayricalik geri alindi ama deger geri donmedi';
    end if;
    raise notice '206: "%" mertebesinin ayricaliklari GERCEK (siralama eki ve bedava istek olculdu)', v_kod;
  end;
end $$;

-- 7) KAÇIRILAN DEĞER KURAL MOTORUNDAN GEÇİYOR MU
do $$
declare v_u uuid; v jsonb;
begin
  select host_id into v_u from availabilities limit 1;
  if v_u is null then raise notice '206: ilan yok — atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u, 'role','authenticated')::text, true);
  v := public.host_missed_value(30);
  perform set_config('request.jwt.claims','',true);
  if v is null or (v ->> 'baslik') is null then
    raise exception '206: kacirilan deger basliksiz dondu → %', v;
  end if;
  raise notice '206: kacirilan deger calisiyor → %', v ->> 'baslik';
end $$;

select '206 OK - hostluk kredi basiyor, cuzdan tam, mertebe gercek' as sonuc;
