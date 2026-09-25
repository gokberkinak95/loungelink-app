-- ============================================================
-- 210 · ABONELİK KURGUSU · HAFTALIK HATIRLATMA · KAPSAM BOŞLUĞU
-- 17 Ağustos 2026
--
-- Üç iş:
--   (1) Abonelik planları yeniden kurgulandı — kredi SATILMIYOR,
--       zaman ve görünürlük satılıyor.
--   (2) Host'u geri getiren haftalık hatırlatma: "geçen hafta X kişi
--       seni bulamadı". Kart uygulamayı AÇANI yakalar; asıl kayıp
--       açmayanlar.
--   (3) Kart ağı kapsamındaki boşluk ÖLÇÜLEBİLİR hâle getirildi.
--       ⚠️ Kapsam UYDURULMADI — sebebi aşağıda.
-- ============================================================


-- ============================================================
-- 1) ABONELİK — kredi para birimi olmaktan çıkıyor
-- ============================================================
-- 🔴 ESKİ KURGUNUN ÜÇ SORUNU (ölçümle):
--   plan_catalog → explorer 2 kredi/0 TL · traveler 8/149 · frequent 20/349
--   Üç planın da vaadi "daha çok istek gönder" — yani ÜÇÜ DE MİSAFİRE
--   satıyor. Host için hiçbir şey yok, oysa darboğaz arz tarafı.
--
--   Daha önemlisi: KREDİ SATMAK ÜRÜNÜN KENDİ CÜMLESİYLE ÇELİŞİYOR.
--   206'dan beri ürünün tek cümlesi "kullanmadığın hakkı, hakkın
--   olmayan yerde misafir olma hakkına çevir". Krediyi parayla
--   satmak "ağırlamana gerek yok, satın al" demektir ve arz tarafını
--   kendi elimizle kurutur.
--
-- YENİ KURGU: abonelik krediyi değil ZAMAN ve GÖRÜNÜRLÜK satar.
-- Kredi yalnız üç yoldan girer: kayıt hediyesi, planın aylık payı,
-- AĞIRLAMA.
-- 🔴 `plan_catalog.plan` DÜZ METİN DEĞİL, `plan_type` ENUM'U.
-- İlk yazımda 'yolcu' yazdım ve harness 22P02 verdi. Enum'a yeni
-- değer eklemek `alter type ... add value` ister ve o değer AYNI
-- işlemde kullanılamaz — psql her ifadeyi ayrı işlemde çalıştırdığı
-- için burada sorun çıkmıyor, ama BEGIN/COMMIT içine alınırsa çıkar.
-- Bu yüzden ekleme, kullanımdan AYRI ifadeler hâlinde duruyor.
--
-- Bu, "şemayı okumadan değer uydurma" sınıfının kaçıncı tekrarı
-- olduğunu artık saymıyorum; her seferinde harness yakalıyor ve
-- Gokberk'in eline hatalı SQL gitmiyor — asıl kazanç bu.
-- 🔴 ENUM EKLEMELERİ BU DOSYADAN ÇIKARILDI → `210a_PRE_plan_enum.sql`
-- Gökberk canlıda:
--     ERROR 55P04: unsafe use of new value "yolcu" of enum type plan_type
--     HINT: New enum values must be committed before they can be used.
-- Yukarıdaki yorumda bu riski ZATEN yazmıştım ("...BEGIN/COMMIT içine
-- alınırsa çıkar") ama aynı dosyada bıraktım, çünkü psql her ifadeyi
-- ayrı işlemde çalıştırıyor ve harness'ta hiç kırmızı yanmıyordu.
-- Supabase SQL Editor betiği tek işlem olarak sarıyor.
--
-- Ekleme artık 210a'da ve KENDİ İŞLEMİNDE kapanıyor.

-- NÖBETÇİ: 210a çalıştırılmadan buraya gelinmişse SESSİZCE devam etme.
-- (Eksik enum değeri aşağıdaki insert'te 22P02 verirdi ve sebebi
--  anlaşılmazdı; burada adıyla söylüyoruz.)
do $enum_kontrol$
declare v_eksik text := '';
begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                  where t.typname = 'plan_type' and e.enumlabel = 'yolcu')
    then v_eksik := v_eksik || 'yolcu '; end if;
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                  where t.typname = 'plan_type' and e.enumlabel = 'sik_ucan')
    then v_eksik := v_eksik || 'sik_ucan '; end if;
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                  where t.typname = 'plan_type' and e.enumlabel = 'kahya')
    then v_eksik := v_eksik || 'kahya '; end if;
  if v_eksik <> '' then
    raise exception '210: plan_type enum degerleri EKSIK: %— once 210a_PRE_plan_enum.sql calistir', v_eksik;
  end if;
end
$enum_kontrol$;

alter table plan_catalog add column if not exists ad text;
alter table plan_catalog add column if not exists yillik_try int;
alter table plan_catalog add column if not exists kacirilan_sikligi text
  check (kacirilan_sikligi in ('aylik','haftalik','anlik'));
alter table plan_catalog add column if not exists one_cikarma_ayda int not null default 0;
alter table plan_catalog add column if not exists yanma_uyarilari int[] not null default '{30}';
alter table plan_catalog add column if not exists ucus_dogrulama_ayda int not null default 3;
alter table plan_catalog add column if not exists kart_siniri int not null default 1;
alter table plan_catalog add column if not exists oncelikli_destek boolean not null default false;
alter table plan_catalog add column if not exists aktif boolean not null default true;

-- 🔴 ESKİ SATIRLARI SİLMİYORUM, PASİFE ALIYORUM. Bir kullanıcı
-- `users.plan = 'traveler'` taşıyor olabilir; satırı silmek o
-- kullanıcının planını çözümsüz bırakırdı.
update plan_catalog set aktif = false where plan in ('explorer','traveler','frequent');

insert into plan_catalog
  (plan, ad, monthly_credits, price_try, yillik_try, perks, sort_order,
   kacirilan_sikligi, one_cikarma_ayda, yanma_uyarilari, ucus_dogrulama_ayda,
   kart_siniri, oncelikli_destek, aktif)
values
  ('yolcu', 'Yolcu', 2, 0, 0,
   '["Cüzdan: hak takibi, yanma sayacı, değer hesabı","Kural motoru: kartın nerede geçer","Ağırlayarak kredi kazanma","Aylık kaçırılan değer özeti"]'::jsonb,
   1, 'aylik', 0, '{30}', 3, 1, false, true),

  ('sik_ucan', 'Sık Uçan', 6, 99, 890,
   '["Yolcu''daki her şey","Haftalık kaçırılan değer bildirimi","Ayda 2 ilan öne çıkarma","Yanma uyarısı: 90 · 30 · 7 gün","3 karta kadar cüzdan","Ayda 20 uçuş doğrulama"]'::jsonb,
   2, 'haftalik', 2, '{90,30,7}', 20, 3, false, true),

  ('kahya', 'Kâhya', 12, 249, 2290,
   '["Sık Uçan''daki her şey","Anlık kaçırılan değer bildirimi","Sınırsız ilan öne çıkarma","Takvim daveti ile yanma hatırlatması","Sınırsız kart","Sınırsız uçuş doğrulama","Öncelikli destek"]'::jsonb,
   3, 'anlik', 99, '{90,30,7}', 9999, 999, true, true)
on conflict (plan) do update set
  ad = excluded.ad, monthly_credits = excluded.monthly_credits,
  price_try = excluded.price_try, yillik_try = excluded.yillik_try,
  perks = excluded.perks, sort_order = excluded.sort_order,
  kacirilan_sikligi = excluded.kacirilan_sikligi,
  one_cikarma_ayda = excluded.one_cikarma_ayda,
  yanma_uyarilari = excluded.yanma_uyarilari,
  ucus_dogrulama_ayda = excluded.ucus_dogrulama_ayda,
  kart_siniri = excluded.kart_siniri,
  oncelikli_destek = excluded.oncelikli_destek, aktif = true;


-- ============================================================
-- 2) AĞIRLAYAN KİŞİ PARA ÖDEMEZ
-- ============================================================
-- 🔴 BU TEK KURAL, ABONELİĞİ BİR MALİYET OLMAKTAN ÇIKARIP ARZ
-- TARAFINA BİR TEŞVİKE ÇEVİRİYOR. Ayda 2+ ağırlama yapan host, o ay
-- "Sık Uçan" ayrıcalıklarını ücretsiz alır. Hesabı basit: o host
-- bize zaten para değerinde bir şey verdi.
--
-- ⚠️ Ödeme sistemi henüz yok; bu fonksiyon "hangi planın HAKLARINA
-- sahipsin" sorusunu cevaplıyor — ödeme kaydına DEĞİL, gerçek
-- davranışa bakarak. Ödeme bağlandığında satın alınan plan da
-- buraya girer.
insert into beta_settings (key, value) values
  ('host_free_upgrade_sessions', to_jsonb(2)),
  ('host_free_upgrade_plan', to_jsonb('sik_ucan'::text))
on conflict (key) do nothing;

create or replace function public.my_plan(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_satin text; v_bu_ay int; v_esik int; v_yukselt text;
  v_etkin text; v_p plan_catalog%rowtype; v_neden text;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  -- ⚠️ `plan` bir ENUM; metin değişkeniyle doğrudan karşılaştırılamaz
  -- (`operator does not exist: plan_type = text`). Fonksiyon boyunca
  -- metinle çalışıp karşılaştırmalarda AÇIKÇA `::text` yazıyorum —
  -- örtük çevrime güvenmek, bu tipte sessiz hatanın kaynağı.
  select coalesce(u.plan::text, 'yolcu') into v_satin from users u where u.id = v_uid;
  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_yukselt := coalesce((select value #>> '{}' from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');

  select count(*) into v_bu_ay
    from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status = 'completed'
     and s.completed_at >= date_trunc('month', now());

  -- Eski plan adları hâlâ kullanıcıda olabilir; pasif satırı çözemezsek
  -- 'yolcu'ya düşeriz — ekran boş kalmaz.
  if not exists (select 1 from plan_catalog where plan::text = v_satin and aktif) then
    v_satin := 'yolcu';
  end if;

  if v_bu_ay >= v_esik
     and (select sort_order from plan_catalog where plan::text = v_yukselt)
       > (select sort_order from plan_catalog where plan::text = v_satin) then
    v_etkin := v_yukselt;
    v_neden := format('Bu ay %s kişi ağırladın — %s ayrıcalıkları bu ay senin, ücretsiz.',
                      v_bu_ay, (select ad from plan_catalog where plan::text = v_yukselt));
  else
    v_etkin := v_satin;
    v_neden := case when v_bu_ay > 0
      then format('Bu ay %s kişi ağırladın. %s ağırlamada üst plan ücretsiz açılıyor.', v_bu_ay, v_esik)
      else format('Bu ay birini ağırlarsan, %s ağırlamada üst plan ücretsiz açılır.', v_esik) end;
  end if;

  select * into v_p from plan_catalog where plan::text = v_etkin;

  return jsonb_build_object(
    'known', true,
    'satin_alinan', v_satin,
    'etkin', v_etkin,
    'ad', v_p.ad,
    'aylik_kredi', v_p.monthly_credits,
    'fiyat_try', v_p.price_try,
    'yillik_try', v_p.yillik_try,
    'haklar', v_p.perks,
    'kacirilan_sikligi', v_p.kacirilan_sikligi,
    'one_cikarma_ayda', v_p.one_cikarma_ayda,
    'yanma_uyarilari', to_jsonb(v_p.yanma_uyarilari),
    'ucus_dogrulama_ayda', v_p.ucus_dogrulama_ayda,
    'kart_siniri', v_p.kart_siniri,
    'oncelikli_destek', v_p.oncelikli_destek,
    'bu_ay_agirlama', v_bu_ay,
    'ucretsiz_yukseltme', v_etkin <> v_satin,
    'neden', v_neden);
end $fn$;

-- 🔴 ADI `plan_options` DEĞİL. O ad ZATEN VAR (196, program ücret
-- planları için, `p_program_code text` parametreli). Aynı adı sıfır
-- parametreyle eklemek tam da bu dosyada iki kez ısırılan tuzağı
-- kurardı: iki aşırı yükleme yan yana durur, çağrı belirsizleşir.
-- Aynı hatayı üçüncü kez yapmıyorum — ad farklı.
create or replace function public.subscription_plans()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_agg(jsonb_build_object(
           'plan', p.plan, 'ad', p.ad,
           'aylik_kredi', p.monthly_credits,
           'fiyat_try', p.price_try, 'yillik_try', p.yillik_try,
           -- Yıllık indirim ORANI hesaplanıyor, elle yazılmıyor:
           -- fiyat değişince metin de değişsin.
           'yillik_indirim_yuzde', case when p.price_try > 0 and p.yillik_try > 0
             then round(100 - (p.yillik_try::numeric / (p.price_try * 12) * 100)) end,
           'haklar', p.perks, 'sira', p.sort_order,
           'kacirilan_sikligi', p.kacirilan_sikligi,
           'oncelikli_destek', p.oncelikli_destek)
         order by p.sort_order)
    from plan_catalog p where p.aktif;
$fn$;


-- ============================================================
-- 3) HAFTALIK HATIRLATMA — host'u geri getiren tek dürüst sebep
-- ============================================================
-- 🔴 `host_missed_value()` kartı ürünün içinde duruyor ve
-- UYGULAMAYI AÇANI yakalıyor. Asıl kayıp AÇMAYANLAR. Bu fonksiyon
-- onlara gider.
--
-- Bildirim `notifications` tablosuna yazılıyor; `on_notification_created`
-- tetikleyicisi zaten push'a çeviriyor (sessiz saat ve kategori
-- tercihi orada uygulanıyor). Yani yeni bir push altyapısı KURMUYORUM
-- — var olanı kullanıyorum.
--
-- ⚠️ ÜÇ KAPI:
--   (a) Aynı kişiye haftada bir kez (ref_type ile idempotent).
--   (b) Sayı SIFIRSA bildirim GİTMEZ. "0 kişi kaçırdın" bildirimi,
--       bildirimleri kapattırmanın en kısa yolu.
--   (c) Planın sıklığı: Yolcu aylık, Sık Uçan haftalık, Kâhya anlık.
create or replace function public.send_missed_value_digest(p_zorla boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  r record;
  v_gonderilen int := 0;
  v_atlanan int := 0;
  v_v jsonb;
  v_sik text;
begin
  for r in
    select distinct u.id as uid
      from users u
     where u.deleted_at is null
       and coalesce(u.is_staff, false) = false
       and exists (select 1 from availabilities a where a.host_id = u.id)
  loop
    -- Plan sıklığı
    select coalesce(p.kacirilan_sikligi, 'aylik') into v_sik
      from users u left join plan_catalog p on p.plan = u.plan and p.aktif
     where u.id = r.uid;

    if not p_zorla then
      -- (a) tekrar kapısı — sıklığa göre
      if exists (
        select 1 from notifications n
         where n.user_id = r.uid and n.ref_type = 'missed_digest'
           and n.created_at > now() - case v_sik
                 when 'anlik'    then interval '1 day'
                 when 'haftalik' then interval '7 days'
                 else                 interval '30 days' end
      ) then
        v_atlanan := v_atlanan + 1;
        continue;
      end if;
    end if;

    -- Kişinin kendi gözünden hesapla
    perform set_config('request.jwt.claims',
      json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
    v_v := public.host_missed_value(case v_sik when 'anlik' then 3 when 'haftalik' then 7 else 30 end);
    perform set_config('request.jwt.claims', '', true);

    -- (b) sıfırsa gönderme
    if coalesce((v_v ->> 'kisi')::int, 0) = 0 then
      v_atlanan := v_atlanan + 1;
      continue;
    end if;

    insert into notifications (user_id, category, title, body, ref_type)
    values (r.uid, 'system',
            format('%s kişi seni bulamadı', v_v ->> 'kisi'),
            coalesce(v_v ->> 'baslik', '') || ' İlan açmak 20 saniye.',
            'missed_digest');
    v_gonderilen := v_gonderilen + 1;
  end loop;

  return jsonb_build_object('gonderilen', v_gonderilen, 'atlanan', v_atlanan);
end $fn$;

comment on function public.send_missed_value_digest(boolean) is
  'Haftalik "kacirdiklarin" hatirlatmasi. BO cron ya da pg_cron ile gunde bir kez cagrilir; sıklık kapısı fonksiyonun kendi icinde. Yalniz service_role.';


-- ============================================================
-- 4) KAPSAM BOŞLUĞU — ÖLÇÜLÜYOR, UYDURULMUYOR
-- ============================================================
-- 🔴 "Kart ağları kapsamını 9 havalimanından 20'ye çıkar" maddesi
-- listede vardı. YAPMADIM VE SEBEBİ ÖNEMLİ:
--
-- Priority Pass'in belirli bir salonu kabul edip etmediği, KAYNAĞI
-- olan bir olgudur. Elimde o kaynak yok. 11 havalimanı için kabul
-- satırı yazmak, ürünün tek cümlesini ("kapıda ne olacağını
-- biliyoruz") bir yalana çevirirdi — ve bunu kullanıcı kapıda,
-- reddedilerek öğrenirdi. Bu ürün için yapılabilecek en pahalı hata
-- budur.
--
-- YAPTIĞIM ŞEY: boşluğu GÖRÜNÜR ve ÖLÇÜLEBİLİR kılmak. Hangi salonun
-- hangi kart ağı için verisi eksik — liste burada. Kaynak bulundukça
-- BO'dan girilir ve bu fonksiyonun çıktısı kendiliğinden küçülür.
create or replace function public.coverage_gaps(p_ulke text default 'Türkiye')
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_hava int; v_kapsanan int; v_bosluk jsonb; v_eksik int;
begin
  select count(distinct v.airport_code) into v_hava
    from lounge_venues v join airports a on a.code = v.airport_code
   where v.active and (p_ulke is null or a.country = p_ulke);

  select count(distinct v.airport_code) into v_kapsanan
    from lounge_venue_acceptance ac
    join lounge_venues v on v.id = ac.venue_id
    join lounge_programs p on p.id = ac.program_id
    join airports a on a.code = v.airport_code
   where ac.active and ac.accepted and p.kind = 'card_program'
     and v.active and (p_ulke is null or a.country = p_ulke);

  select jsonb_agg(x order by (x ->> 'salon')::int desc), sum((x ->> 'salon')::int)
    into v_bosluk, v_eksik
  from (
    select jsonb_build_object(
             'havalimani', v.airport_code,
             'sehir', max(a.city),
             'salon', count(*)::int,
             'ornek', max(v.name)
           ) as x
      from lounge_venues v
      join airports a on a.code = v.airport_code
     where v.active and (p_ulke is null or a.country = p_ulke)
       and not exists (
         select 1 from lounge_venue_acceptance ac
         join lounge_programs p on p.id = ac.program_id
          where ac.venue_id = v.id and ac.active and p.kind = 'card_program')
     group by v.airport_code
  ) q;

  return jsonb_build_object(
    'ulke', p_ulke,
    'havalimani', v_hava,
    'kart_agi_kapsanan', v_kapsanan,
    'kapsama_yuzde', case when v_hava > 0 then round(v_kapsanan::numeric / v_hava * 100) end,
    'eksik_salon', coalesce(v_eksik, 0),
    'bosluklar', coalesce(v_bosluk, '[]'::jsonb),
    'not', 'Bu liste EKSİK VERİYİ gösterir, "kabul edilmiyor"u DEĞİL. Kaynak bulunmadan kabul satırı yazılmaz.');
end $fn$;


-- ============================================================
-- 5) YÜZEY
-- ============================================================
insert into rpc_client_surface (fn_name, client, note) values
  ('my_plan','app','Etkin plan + ucretsiz yukseltme durumu'),
  ('subscription_plans','app','Abonelik planlari — plan_catalog yerine')
on conflict (fn_name) do nothing;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '210: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) ÜÇ PLAN VAR VE ESKİLERİ ÇÖZÜLEBİLİR DURUMDA
do $$
declare v_n int; v_eski int;
begin
  select count(*) into v_n from plan_catalog where aktif;
  if v_n <> 3 then raise exception '210: aktif plan sayisi 3 degil (%)', v_n; end if;
  select count(*) into v_eski from plan_catalog where plan in ('explorer','traveler','frequent') and not aktif;
  if v_eski <> 3 then
    raise exception '210: eski planlar SILINMIS ya da hala aktif — mevcut kullanicilarin plani cozumsuz kalir';
  end if;
  raise notice '210: 3 aktif plan · 3 eski plan pasif ama duruyor';
end $$;

-- 2) YILLIK İNDİRİM ELLE YAZILMIYOR, HESAPLANIYOR
do $$
declare v jsonb; k jsonb; v_ind int;
begin
  v := public.subscription_plans();
  select k1 into k from jsonb_array_elements(v) k1 where k1 ->> 'plan' = 'sik_ucan';
  v_ind := (k ->> 'yillik_indirim_yuzde')::int;
  if v_ind is null or v_ind < 10 or v_ind > 50 then
    raise exception '210: yillik indirim orani mantiksiz (%)', v_ind;
  end if;
  raise notice '210: yillik indirim veriden hesaplaniyor (%%%)', v_ind;
end $$;

-- 3) AĞIRLAYAN KİŞİ ÜST PLANA ÜCRETSİZ GEÇİYOR MU (mutasyon)
-- 🔴 Bu, aboneliğin arz tarafına teşvike dönüştüğü tek yer. Sözü
-- verip uygulamamak, 206'da yaptığım hatanın aynısı olurdu.
do $$
declare v_h uuid; v jsonb; v_once text; v_sonra text; v_esik int;
begin
  select r.host_id into v_h from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' limit 1;
  if v_h is null then raise notice '210: tamamlanmis oturum yok — atlandi'; return; end if;

  select (value #>> '{}')::int into v_esik from beta_settings where key='host_free_upgrade_sessions';

  -- Eşiği ulaşılamaz yap → yükseltme OLMAMALI
  update beta_settings set value = to_jsonb(9999) where key='host_free_upgrade_sessions';
  v := public.my_plan(v_h); v_once := v ->> 'etkin';
  if (v ->> 'ucretsiz_yukseltme')::boolean then
    update beta_settings set value = to_jsonb(coalesce(v_esik,2)) where key='host_free_upgrade_sessions';
    raise exception '210: esik 9999 iken bile ucretsiz yukseltme verildi';
  end if;

  -- Eşiği 0 yap → yükseltme OLMALI
  update beta_settings set value = to_jsonb(0) where key='host_free_upgrade_sessions';
  v := public.my_plan(v_h); v_sonra := v ->> 'etkin';
  update beta_settings set value = to_jsonb(coalesce(v_esik,2)) where key='host_free_upgrade_sessions';

  if v_sonra = v_once then
    raise exception '210: esik 0 yapildi ama plan DEGISMEDI (% → %) — soz uygulanmiyor', v_once, v_sonra;
  end if;
  raise notice '210: agirlayan kisi ust plana ucretsiz geciyor (% → %)', v_once, v_sonra;
end $$;

-- 4) HATIRLATMA SIFIRDA GÖNDERMİYOR
-- 🔴 "0 kişi kaçırdın" bildirimi, bildirimleri kapattırmanın en kısa
-- yolu. Bunu kanıtlamadan salıveremem.
do $$
declare v jsonb; v_once int; v_sonra int;
begin
  select count(*) into v_once from notifications where ref_type = 'missed_digest';
  v := public.send_missed_value_digest(true);
  select count(*) into v_sonra from notifications where ref_type = 'missed_digest';

  if (v ->> 'gonderilen')::int <> v_sonra - v_once then
    raise exception '210: rapor ile gercek bildirim sayisi tutmuyor (% vs %)',
      v ->> 'gonderilen', v_sonra - v_once;
  end if;
  -- Sıfır kaçırma olan kişiye gitmemeli
  if exists (
    select 1 from notifications n
     where n.ref_type = 'missed_digest' and n.title like '0 kişi%') then
    raise exception '210: "0 kisi seni bulamadi" bildirimi gonderildi';
  end if;
  delete from notifications where ref_type = 'missed_digest';
  raise notice '210: hatirlatma calisiyor (% gonderildi, % atlandi) ve sifirda susuyor',
    v ->> 'gonderilen', v ->> 'atlanan';
end $$;

-- 5) TEKRAR KAPISI — aynı kişiye üst üste gitmiyor
do $$
declare v1 jsonb; v2 jsonb;
begin
  delete from notifications where ref_type = 'missed_digest';
  v1 := public.send_missed_value_digest(true);
  v2 := public.send_missed_value_digest(false);   -- kapı devrede
  delete from notifications where ref_type = 'missed_digest';
  if (v1 ->> 'gonderilen')::int > 0 and (v2 ->> 'gonderilen')::int > 0 then
    raise exception '210: ayni kisiye ust uste hatirlatma gonderildi';
  end if;
  raise notice '210: tekrar kapisi calisiyor (ilk % · ikinci %)',
    v1 ->> 'gonderilen', v2 ->> 'gonderilen';
end $$;

-- 6) KAPSAM BOŞLUĞU DÜRÜST Mİ
do $$
declare v jsonb;
begin
  v := public.coverage_gaps('Türkiye');
  if v is null or (v ->> 'not') is null then
    raise exception '210: kapsam raporu aciklamasiz';
  end if;
  if (v ->> 'not') not like '%kabul edilmiyor%' then
    raise exception '210: kapsam raporu "eksik veri" ile "kabul edilmiyor"u ayirmiyor';
  end if;
  raise notice '210: kapsam → % / % havalimani kart agi verisi var (eksik % salon)',
    v ->> 'kart_agi_kapsanan', v ->> 'havalimani', v ->> 'eksik_salon';
end $$;

select '210 OK - abonelik kredi satmiyor, hatirlatma calisiyor, kapsam bosluğu olculuyor' as sonuc;
