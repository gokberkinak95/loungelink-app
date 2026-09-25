-- ============================================================================
-- LoungeLink · 246_ekonomi_ayari.sql                      (23 Ağustos 2026)
--
-- KREDİ EKONOMİSİ YENİDEN AYARLANIYOR — VE BİR FİKRİMİ DEĞİŞTİRİYORUM
--
-- ════════════════════════════════════════════════════════════════════════
-- GÖKBERK'İN KARARI VE BENİM İTİRAZ EDİP SONRA VAZGEÇMEM
-- ════════════════════════════════════════════════════════════════════════
-- "Ücretsiz planda ayda 2 değil 1 kredi verelim. Ağırlayan tarafa neden
--  hâlâ 3 kredi hediye ettiğimizi anlamıyorum. Maks 1 kredi hediye
--  etmeliyiz. Yanlış mı düşünüyorum?"
--
-- İlk tepkim itirazdı: "arz kıtken talebi de kısmak çifte fren olur;
-- erken pazaryeri DAHA ÇOK deneme ister, daha az değil."
--
-- Sonra kendi ölçtüğüm bir şeyi hatırladım ve fikrim değişti:
-- **REDDEDİLEN İSTEK KREDİYİ İADE EDİYOR** (`respond_request` →
-- `request_refund`). Yani 1 kredi "ayda 1 deneme" DEĞİL; "aynı anda 1
-- açık istek, reddedilirse tekrar kullanılabilir" demek. Bağlayıcı kısıt
-- deneme sayısı değil, PARALEL BAHİS sayısı. Ve paralel bahsi kısmak
-- doğru: bir misafirin aynı anda beş host'a istek atıp dördünü
-- oyalaması, arz tarafını yorar.
--
-- 🆕 SINIF: **"BİR SINIRIN SERT MI YUMUŞAK MI OLDUĞU, SINIRIN
-- KENDİSİNDEN DEĞİL, YANINDAKİ İADE KURALINDAN ANLAŞILIR."**
--
-- Yani hayır, yanlış düşünmüyorsun. Benim itirazım iade kuralını hesaba
-- katmıyordu.
--
-- ── HOST KREDİSİ 3 → 1: KATILIYORUM, VE SEBEBİ DAHA DERİN ────────────
-- Host'a "misafir isteği hakkı" ödemek, iki farklı rolü tek para
-- biriminde karıştırıyor. Host'un istediği şey misafir olma hakkı
-- olmayabilir; puan ve basamak zaten onun karşılığı. 1:1 oran ayrıca
-- ürünün cümlesini de netleştiriyor:
--
--     ESKİ: "Bir kez ağırla — üç kez misafir ol."   (cömert ama ödünç)
--     YENİ: "Bir kez ağırla — bir kez misafir ol."  (karşılıklılık)
--
-- İkincisi bence daha güçlü: açtığın kapı, sana BİR kapı açar. Site
-- metni bu turda buna göre güncellendi.
--
-- ⚠️ AMA BİR RİSK VAR VE SÖYLÜYORUM: aylık kredi 2→1 inince ücretsiz
-- kullanıcı ayda yalnız BİR başarılı ziyaret yapabilir. Erken dönemde
-- asıl sorun kıtlık değil BOŞLUK (ilan yok). Kıtlığı artırmak, boşluğu
-- daha çok hissettirebilir. Bu yüzden ayarları SABİT yazmıyorum;
-- `beta_settings`ten değiştirilebilir ve aşağıdaki `kredi_akis_raporu()`
-- ile etkisini ölçebilirsin.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) SAYILAR
-- ----------------------------------------------------------------------------
update beta_settings set value = to_jsonb(1) where key = 'host_credit_per_session';
update beta_settings set value = to_jsonb(3) where key = 'host_credit_daily_cap';
insert into beta_settings (key, value) values
  ('host_credit_per_session', to_jsonb(1)),
  ('host_credit_daily_cap',   to_jsonb(3))
on conflict (key) do nothing;

-- Ücretsiz plan: 2 → 1
update plan_catalog set monthly_credits = 1 where plan = 'yolcu';

-- ----------------------------------------------------------------------------
-- 2) AÇIK İSTEK TAVANI — ASIL YAPISAL KALDIRAÇ
-- ----------------------------------------------------------------------------
-- 🔴 Kredi sayısını kısmak, iade kuralı yüzünden zaten "paralel bahis"
-- sınırı gibi çalışıyor. Ama bu ÖRTÜK bir sınır: kullanıcı neden
-- durdurulduğunu anlamaz, "kredim var mı yok mu" diye bakar.
--
-- Sınırı AÇIK hâle getiriyorum: plana bağlı "aynı anda kaç açık isteğin
-- olabilir" tavanı. Böylece mesaj net olur ve kredi sayısı ayrı bir
-- kaldıraç olarak kalır.
alter table plan_catalog add column if not exists acik_istek_tavani int;
update plan_catalog set acik_istek_tavani = case plan
  when 'yolcu'    then 1
  when 'sik_ucan' then 3
  when 'kahya'    then 6
  else coalesce(acik_istek_tavani, 2) end;
alter table plan_catalog alter column acik_istek_tavani set default 1;

create or replace function public.acik_istek_tavanim()
returns jsonb language sql stable security definer set search_path = public as $f$
  select jsonb_build_object(
    'tavan', coalesce((select p.acik_istek_tavani from users u
                        left join plan_catalog p on p.plan = u.plan and p.aktif
                       where u.id = auth.uid()), 1),
    'acik',  (select count(*) from requests
               where guest_id = auth.uid() and status = 'pending'));
$f$;
grant execute on function public.acik_istek_tavanim() to authenticated;

create or replace function public.trg_acik_istek_tavani()
returns trigger language plpgsql security definer set search_path = public as $f$
declare v_tavan int; v_acik int;
begin
  if new.status <> 'pending' then return new; end if;
  select coalesce(p.acik_istek_tavani, 1) into v_tavan
    from users u left join plan_catalog p on p.plan = u.plan and p.aktif
   where u.id = new.guest_id;
  v_tavan := coalesce(v_tavan, 1);

  select count(*) into v_acik from requests
   where guest_id = new.guest_id and status = 'pending' and id <> new.id;

  if v_acik >= v_tavan then
    raise exception 'acik_istek_tavani'
      using detail = format('%s/%s acik istek', v_acik, v_tavan),
            hint   = 'Bekleyen isteklerinden biri sonuclanmadan yenisini gonderemezsin. '
                  || 'Ust plana gecersen ayni anda daha fazla istek acabilirsin.';
  end if;
  return new;
end $f$;

drop trigger if exists trg_istek_tavani on public.requests;
create trigger trg_istek_tavani
  before insert on public.requests
  for each row execute function public.trg_acik_istek_tavani();

-- ----------------------------------------------------------------------------
-- 3) KÂHYA "DAHA ÇOK" DEĞİL "DAHA İYİ" SATSIN
-- ----------------------------------------------------------------------------
-- 🔴 `one_cikarma_ayda = 99` fiyatlama değil, SINIR KALDIRMAYDI. Bir
-- kullanıcı olarak "99 neden?" diye sorar ve cevabı olmadığını
-- hissederdim. 243 zaten "aynı anda tek ilan öne çıkabilir" tavanını
-- koydu; aylık hak da savunulabilir bir sayıya iniyor.
update plan_catalog set one_cikarma_ayda = 8 where plan = 'kahya';
update plan_catalog set one_cikarma_ayda = 3 where plan = 'sik_ucan';
update plan_catalog set oncelikli_destek = true where plan = 'kahya';

-- ⚠️ GÜVENLİK PAYWALL'A KONMAZ. Kâhya'nın ayırt edici özelliği olarak
-- "misafir güven eşiği" (min_trust) koymayı düşündüm ve VAZGEÇTİM:
-- host'un kendini güvende hissetmesi bir ayrıcalık değil, ürünün
-- asgari şartı. min_trust bu turda BÜTÜN hostlara açılıyor (app 2.93).
--
-- 🆕 SINIF: **"GÜVENLİK ÖZELLİĞİNİ ÜST PLANA KOYMAK, GÜVENLİĞİ DEĞİL
-- GÜVENSİZLİĞİ SATMAKTIR."**

update plan_catalog set perks = to_jsonb(array[
  'Aylık 1 misafir isteği',
  'Aynı anda 1 açık istek',
  'Kural motoru ve güven skoru — tam erişim'
]) where plan = 'yolcu';

update plan_catalog set perks = to_jsonb(array[
  'Aylık 6 misafir isteği',
  'Aynı anda 3 açık istek',
  'Ayda 3 kez ilan öne çıkarma'
]) where plan = 'sik_ucan';

update plan_catalog set perks = to_jsonb(array[
  'Aylık 12 misafir isteği',
  'Aynı anda 6 açık istek',
  'Ayda 8 kez ilan öne çıkarma',
  'Öncelikli destek'
]) where plan = 'kahya';

-- 🔴 İLK YAZDIĞIMDA YALNIZ TÜRKÇESİNİ GÜNCELLEDİM. 220'nin nöbetçisi
-- yakaladı: "ayricalik madde sayilari TUTMUYOR → sik_ucan (tr=3 en=5)".
-- İki dilin madde sayısı ayrışınca İngilizce ekran eski sözü vermeye
-- devam eder — yani ürün iki dilde iki farklı şey vaat eder.
update plan_catalog set perks_en = to_jsonb(array[
  '1 guest request per month',
  '1 open request at a time',
  'Rule engine and trust score — full access'
]) where plan = 'yolcu';

update plan_catalog set perks_en = to_jsonb(array[
  '6 guest requests per month',
  '3 open requests at a time',
  'Feature a listing 3× a month'
]) where plan = 'sik_ucan';

update plan_catalog set perks_en = to_jsonb(array[
  '12 guest requests per month',
  '6 open requests at a time',
  'Feature a listing 8× a month',
  'Priority support'
]) where plan = 'kahya';

-- ----------------------------------------------------------------------------
-- 3b) GÜVEN EŞİĞİ: VARDI AMA HOST'UN ELİNDE DEĞİLDİ
-- ----------------------------------------------------------------------------
-- Gökberk: "Yanımda gelen kişiyi tanımıyorum, ya sorun çıkarırsa?"
--
-- Ölçtüm: `availabilities.min_trust` kolonu VAR ve keşifte uygulanıyor
-- (`discover_availabilities_base`: `v_my_trust >= coalesce(a.min_trust,0)`).
-- Yani mekanizma çalışıyor — ama host'un onu AYARLAYACAK hiçbir yolu yok.
-- `create_availability` bu parametreyi almıyor.
--
-- 🆕 SINIF: **"KULLANICININ AYARLAYAMADIĞI BİR KORUMA, KORUMA DEĞİL
-- VARSAYIMDIR."**
--
-- Ve ikinci bir boşluk: eşik yalnız KEŞİFTE süzüyor. İlan kimliğini
-- başka yoldan öğrenen biri (eski bir bildirim, paylaşılan bir bağlantı)
-- yine de istek gönderebiliyordu. Eşik artık isteğin kendisinde de var.
create or replace function public.ilan_guven_esigi_yaz(p_avail_id uuid, p_esik int)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare v_uid uuid := auth.uid(); v_host uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_esik is null or p_esik < 0 or p_esik > 100 then
    raise exception 'gecersiz_deger' using hint = 'Guven esigi 0 ile 100 arasinda olmali.';
  end if;
  select host_id into v_host from availabilities where id = p_avail_id;
  if v_host is null then raise exception 'availability_not_found'; end if;
  if v_host <> v_uid then raise exception 'not_owner'; end if;

  perform public.motor_yazimi_ac();   -- 243: min_trust motor kolonlari arasinda
  update availabilities set min_trust = p_esik where id = p_avail_id;

  return jsonb_build_object('ok', true, 'min_trust', p_esik,
    'su_an_gorebilen', (select count(*) from profiles pr
                         where coalesce(pr.trust_score, 0) >= p_esik));
end $f$;
grant execute on function public.ilan_guven_esigi_yaz(uuid, int) to authenticated;

create or replace function public.trg_istek_guven_esigi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare v_esik int; v_puan int;
begin
  select coalesce(a.min_trust, 0) into v_esik from availabilities a where a.id = new.avail_id;
  if coalesce(v_esik, 0) = 0 then return new; end if;
  select coalesce(pr.trust_score, 0) into v_puan from profiles pr where pr.user_id = new.guest_id;
  if coalesce(v_puan, 0) < v_esik then
    raise exception 'guven_esigi_altinda'
      using detail = format('guven skoru %s, esik %s', coalesce(v_puan,0), v_esik),
            hint   = 'Bu ilan icin gereken guven skoruna henuz ulasmadin. '
                  || 'Kimligini dogrulayarak ve oturum tamamlayarak yukseltebilirsin.';
  end if;
  return new;
end $f$;

drop trigger if exists trg_istek_guven on public.requests;
create trigger trg_istek_guven
  before insert on public.requests
  for each row execute function public.trg_istek_guven_esigi();

insert into rpc_client_surface (fn_name, client, note) values
  ('ilan_guven_esigi_yaz','app','Ilan icin asgari misafir guven skoru (246)')
on conflict (fn_name) do update set note = excluded.note;

-- ----------------------------------------------------------------------------
-- 4) ETKİYİ ÖLÇEBİLMEK İÇİN
-- ----------------------------------------------------------------------------
-- Bu ayarları değiştirdik; değiştirmenin işe yarayıp yaramadığını
-- görmenin bir yolu olmalı. Yoksa altı ay sonra "1 mi 2 mi iyiydi"
-- sorusunun cevabı yine his olur.
create or replace function public.kredi_akis_raporu(p_gun int default 30)
returns jsonb language sql stable security definer set search_path = public as $f$
  select jsonb_build_object(
    'gun', p_gun,
    'basilan_kredi', coalesce((select sum(delta) from credit_ledger
                                where delta > 0 and created_at >= now() - make_interval(days => p_gun)), 0),
    'harcanan_kredi', coalesce((select -sum(delta) from credit_ledger
                                 where delta < 0 and created_at >= now() - make_interval(days => p_gun)), 0),
    'iade_edilen', coalesce((select sum(delta) from credit_ledger
                              where reason = 'request_refund' and created_at >= now() - make_interval(days => p_gun)), 0),
    'istek', (select count(*) from requests where created_at >= now() - make_interval(days => p_gun)),
    'kabul', (select count(*) from requests where status in ('accepted','completed')
                and created_at >= now() - make_interval(days => p_gun)),
    'tavana_takilan_kullanici',
      (select count(distinct guest_id) from requests r
        where r.status = 'pending'
          and (select count(*) from requests r2
                where r2.guest_id = r.guest_id and r2.status='pending')
              >= coalesce((select p.acik_istek_tavani from users u
                            left join plan_catalog p on p.plan=u.plan and p.aktif
                           where u.id = r.guest_id), 1)),
    'ayar', jsonb_build_object(
      'host_kredi', (select (value #>> '{}')::int from beta_settings where key='host_credit_per_session'),
      'ucretsiz_aylik', (select monthly_credits from plan_catalog where plan='yolcu')));
$f$;
revoke execute on function public.kredi_akis_raporu(int) from public, anon, authenticated;
grant execute on function public.kredi_akis_raporu(int) to service_role;

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n246$
declare v_h text[] := '{}'; v_gecti boolean; v_g uuid; v_a uuid; v_n int;
begin
  if (select (value #>> '{}')::int from beta_settings where key='host_credit_per_session') <> 1 then
    v_h := v_h || 'host kredisi 1 e inmedi'::text;
  end if;
  if (select monthly_credits from plan_catalog where plan='yolcu') <> 1 then
    v_h := v_h || 'ucretsiz plan aylik kredisi 1 e inmedi'::text;
  end if;
  if (select one_cikarma_ayda from plan_catalog where plan='kahya') > 12 then
    v_h := v_h || 'kahya one cikarma hakki hala sinirsiza yakin'::text;
  end if;
  -- TERS YÖN: ucretli planlar SIFIRLANMAMALI
  if (select monthly_credits from plan_catalog where plan='sik_ucan') < 3
     or (select monthly_credits from plan_catalog where plan='kahya') < 6 then
    v_h := v_h || 'ucretli planlarin kredisi de dustu — fazla kestim'::text;
  end if;
  if (select count(*) from plan_catalog where aktif and acik_istek_tavani is null) > 0 then
    v_h := v_h || 'bazi aktif planlarda acik istek tavani YOK'::text;
  end if;

  -- Tavan gercekten calisiyor mu
  begin
    select r.guest_id into v_g from requests r where r.status='pending' group by r.guest_id
     order by count(*) desc limit 1;
    if v_g is not null then
      select a.id into v_a from availabilities a where a.active
        and not exists (select 1 from requests q where q.avail_id=a.id and q.guest_id=v_g)
       limit 1;
      select count(*) into v_n from requests where guest_id=v_g and status='pending';
      if v_a is not null and v_n >= 1 then
        -- Tavani 1 e cekip ikinci istegi denemeliyim
        update plan_catalog set acik_istek_tavani = 1 where plan = (select plan from users where id=v_g);
        v_gecti := false;
        begin
          -- 🔴 `'lounge'` yazmistim; `request_type` enum'unun degerleri
          -- `standard` ve `direct_invite`. Bu turda ucuncu kez enum
          -- degerini EZBERDEN yazdim — katalogdan okumak zorunda degilim
          -- ama en azindan bakmaliyim.
          insert into requests (guest_id, host_id, avail_id, status, type)
          select v_g, a.host_id, a.id, 'pending', 'standard' from availabilities a where a.id=v_a;
          v_gecti := true;
        exception when others then
          if sqlerrm not like '%acik_istek_tavani%' then
            v_h := v_h || ('beklenmeyen hata (tavan): ' || sqlerrm);
          end if;
        end;
        if v_gecti then v_h := v_h || 'acik istek tavani ASILDI — tetikleyici calismiyor'::text; end if;
      end if;
    end if;
    raise exception 'GERI_AL_246';
  exception when others then
    if sqlerrm <> 'GERI_AL_246' then v_h := v_h || ('olcum coktu: ' || sqlerrm); end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '246 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '246 OK · host kredisi 1 · ucretsiz aylik 1 · acik istek tavani plana bagli';
end $n246$;

select '246 EKONOMI AYARLANDI' as sonuc,
       (select (value #>> '{}')::int from beta_settings where key='host_credit_per_session') as host_kredi,
       (select monthly_credits from plan_catalog where plan='yolcu')    as ucretsiz_aylik,
       (select acik_istek_tavani from plan_catalog where plan='yolcu')  as ucretsiz_acik_tavan,
       (select one_cikarma_ayda from plan_catalog where plan='kahya')   as kahya_one_cikarma;
