-- ============================================================
-- 209 · SAĞLAYICI MODÜLÜ — panel önce ÇALIŞSIN, sonra büyüsün
-- 17 Ağustos 2026
--
-- 🔴 DENETİM ŞUNU BULDU VE ÖLÇÜMLE DOĞRULADIM: sağlayıcı paneli
-- bugüne kadar HİÇ ÇALIŞMADI.
--
-- Sebep, panelin kendisinde değil çağrı biçiminde:
--   `app/partner/page.jsx:8` → `sb = sbAdmin()` (service_role)
--   `partner_demand` gövdesi → `where user_id = auth.uid()`
-- service_role ile `auth.uid()` NULL'dır ⇒ fonksiyon her seferinde
-- `not_partner` fırlatır ⇒ sağlayıcı kırmızı hata görür.
--
-- 207'de `partner_demand`e `p_user` eklemiştim; bu dosya işi
-- tamamlıyor: `partner_payout` da aynı hâle geliyor, k-anonimite
-- eşiği veriye taşınıyor, komisyon oranı ayara çıkıyor ve
-- işletmeciye satılabilir İKİ ekranın verisi açılıyor.
--
-- SIRA BİLİNÇLİ: "önce çalışsın, sonra büyüsün". Yeni ekran
-- eklemeden önce panelin açılması gerekiyordu.
-- ============================================================


-- ============================================================
-- 0) ESKİ İMZALARI DÜŞÜR — YOKSA ÇAĞRI BELİRSİZ KALIYOR
-- ============================================================
-- 🔴 NÖBETÇİM BENİ YAKALADI VE İYİ Kİ YAKALADI:
--     ERROR: function public.partner_demand(uuid) is not unique
--
-- Sebep: `create or replace function partner_demand(p_lounge_id uuid,
-- p_user uuid default null)` yazmak, VAR OLAN tek argümanlı
-- `partner_demand(uuid)` fonksiyonunu DEĞİŞTİRMEZ — farklı arite,
-- yeni bir fonksiyon demektir. İkisi yan yana durunca tek argümanla
-- yapılan her çağrı belirsizleşir ve 42725 döner.
--
-- Bu hatayı 207'de `partner_demand` için yaptım, burada `partner_payout`
-- için tekrarlayacaktım. Üstelik `partner_payout`'un dönüş TİPİ de
-- değişiyor (TABLE → jsonb), yani `create or replace` zaten
-- çalışmazdı; eskisi öylece kalıp yanlış şekil döndürmeye devam
-- ederdi.
--
-- YENİ HATA SINIFI (20.): VARSAYILAN PARAMETRE EKLEMEK, İMZAYI
-- DEĞİŞTİRMEZ — YENİ BİR FONKSİYON YARATIR. Eskisi açıkça
-- düşürülmeli.
drop function if exists public.partner_demand(uuid);
drop function if exists public.partner_payout(uuid, date, date);


-- ============================================================
-- 1) AYARLAR — sayılar koda gömülü kalmasın
-- ============================================================
-- 🔴 k-ANONİMİTE EŞİĞİ NEDEN AYAR OLMALI: bugün 5 kodda sabit ve
-- YALNIZ host sayısına uygulanıyor. Ekran ise "en az 5 farklı
-- kullanıcı" diyor. Beyan ile kod ayrışmış durumda — bir KVKK
-- tartışmasında savunması en zor hâl budur. Tek yerden okunacak.
insert into beta_settings (key, value) values
  ('partner_k_threshold', to_jsonb(5)),
  ('partner_commission_pct', to_jsonb(15))
on conflict (key) do nothing;

create or replace function public.partner_k()
returns int language sql stable security definer set search_path = public as $fn$
  select coalesce((select (value #>> '{}')::int from beta_settings where key='partner_k_threshold'), 5);
$fn$;


-- ============================================================
-- 2) ORTAK KAPI — tek yerde, üç ekranda aynı
-- ============================================================
-- Her sağlayıcı fonksiyonuna aynı `if not exists ... raise` bloğunu
-- kopyalamak, 204'te öğrendiğimiz hatanın aynısı: dördüncü fonksiyon
-- yazıldığında unutulur.
create or replace function public.partner_gate(p_user uuid, p_lounge uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_uid uuid := coalesce(p_user, auth.uid());
begin
  if v_uid is null then raise exception 'not_partner'; end if;
  if not exists (select 1 from lounge_partners where user_id = v_uid and lounge_id = p_lounge)
     and not exists (select 1 from admin_roles where user_id = v_uid) then
    raise exception 'not_partner';
  end if;
  return v_uid;
end $fn$;


-- ============================================================
-- 3) partner_payout — 207'de demand'e yaptığımı buna da yap
-- ============================================================
-- ⚠️ Denetim ayrıca şunu buldu: `lounge_offers.sold` HİÇBİR YERDE
-- yazılmıyor (SQL, BO, uygulama — üçünde de yok). Yani hakediş
-- ekranı YAPISAL OLARAK daima 0 gösteriyor. Bunu gizlemek yerine
-- cevabın içinde SÖYLÜYORUM: `satis_akisi_var` bayrağı false
-- dönüyor ve ekran "bu sayı henüz anlamlı değil" diyebiliyor.
-- Sıfırı sessizce göstermek, veri yokluğunu başarısızlık gibi
-- sunmaktır.
create or replace function public.partner_payout(
  p_lounge_id uuid, p_from date, p_to date, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid;
  v_k   int := public.partner_k();
  v_satis int; v_ciro numeric; v_kisi int; v_akis boolean;
  v_kom int := coalesce((select (value #>> '{}')::int from beta_settings where key='partner_commission_pct'), 15);
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);

  select coalesce(sum(o.sold),0),
         coalesce(sum(o.sold * o.price_try),0),
         count(distinct o.id)
    into v_satis, v_ciro, v_kisi
    from lounge_offers o
   where o.lounge_id = p_lounge_id
     and o.offer_date between p_from and p_to
     and o.status = 'approved';

  -- Satış akışı hiç yazılmadıysa bunu SÖYLE.
  v_akis := exists (select 1 from lounge_offers where coalesce(sold,0) > 0);

  return jsonb_build_object(
    'from', p_from, 'to', p_to,
    'satis', v_satis,
    'ciro_try', v_ciro,
    'komisyon_yuzde', v_kom,
    'komisyon_try', round(v_ciro * v_kom / 100.0),
    'net_try', round(v_ciro * (100 - v_kom) / 100.0),
    'satis_akisi_var', v_akis,
    -- k-eşiği: az sayıda satış tek bir kişiyi saat aralığıyla ifşa
    -- edebilir. Eşik altındaysa TUTAR gösterilmez.
    'k_esigi', v_k,
    'k_altinda', v_satis > 0 and v_satis < v_k,
    'not', case
      when not v_akis then 'Satın alma akışı henüz açılmadı; bu sayı yapısal olarak 0. Ekranda "veri yok" olarak gösterilmeli.'
      when v_satis > 0 and v_satis < v_k then format('Bu dönemde %s satış var; %s eşiğinin altında olduğu için tutar gizlendi.', v_satis, v_k)
      end);
end $fn$;


-- ============================================================
-- 4) Ö1 · KAPI RAPORU — işletmecinin başka yerden alamayacağı veri
-- ============================================================
-- 🔴 EN DEĞERLİ EKRAN VE SEBEBİ ŞU: bir işletmeci, kapıdan GERİ
-- ÇEVİRDİĞİ kişinin hangi programla geldiğini bilmiyor — kendi kapı
-- kaydında o kişi hiç yok. Bizde `outcome = 'refused'` diye bir
-- satır var. Bu, banka/program sözleşmesi pazarlığının verisi.
--
-- ⚠️ k-eşiği HER SATIRA uygulanıyor, yalnız toplama değil. Beş
-- kişiden az veri taşıyan bir program satırı, o beş kişiyi
-- tanımlanabilir kılar.
create or replace function public.venue_gate_report(
  p_lounge_id uuid, p_gun int default 90, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid; v_ven uuid; v_k int := public.partner_k();
  v_satir jsonb; v_toplam int;
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);
  select venue_id into v_ven from lounges where id = p_lounge_id;
  if v_ven is null then
    return jsonb_build_object('known', false, 'neden', 'salon bir venue kaydina bagli degil');
  end if;

  select jsonb_agg(x order by (x ->> 'toplam')::int desc), sum((x ->> 'toplam')::int)
    into v_satir, v_toplam
  from (
    select jsonb_build_object(
             'program', coalesce(p.name, 'Bilinmiyor'),
             'program_kodu', p.code,
             'tier', r.card_tier,
             'toplam', count(*)::int,
             'girdi', count(*) filter (where r.entered)::int,
             'geri_cevrildi', count(*) filter (where not coalesce(r.entered,true))::int,
             'misafir_kabul', count(*) filter (where r.guest_accepted)::int,
             'ucret_alindi', count(*) filter (where r.fee_charged)::int,
             -- ⚠️ `fee_amount` TEXT (ölçüldü: information_schema).
             -- `avg(text)` yok — nöbetçi 42883 verdi. Sayıya çevrilebilen
             -- değerleri süzüyoruz; "30 EUR" gibi serbest metin girilmiş
             -- olabilir ve onu sayı sanmak, uydurmanın en sinsi hâli.
             'ortalama_ucret', round(avg(
                 case when r.fee_amount ~ '^[0-9]+([.,][0-9]+)?$'
                      then replace(r.fee_amount, ',', '.')::numeric end)
               filter (where r.fee_charged))
           ) as x
      from lounge_field_reports r
      left join lounge_programs p on p.id = r.program_id
     where r.venue_id = v_ven
       and r.created_at >= now() - make_interval(days => p_gun)
     group by p.name, p.code, r.card_tier
    having count(*) >= v_k          -- k-anonimite, SATIR düzeyinde
  ) q;

  return jsonb_build_object(
    'known', true,
    'gun', p_gun,
    'k_esigi', v_k,
    'toplam', coalesce(v_toplam, 0),
    'satirlar', coalesce(v_satir, '[]'::jsonb),
    'not', case when v_satir is null
      then format('Son %s günde %s kişiden az veri taşıyan satırlar gizlendi; gösterilecek satır kalmadı.', p_gun, v_k)
      else 'Her satır en az ' || v_k || ' kayıt taşıyor. Daha az veri taşıyan programlar gizlendi.' end);
end $fn$;


-- ============================================================
-- 5) Ö2 · KAÇAN TALEP — "girmek isteyip giremeyen kaç kişi vardı?"
-- ============================================================
-- Panel bugün yalnız GERÇEKLEŞENİ gösteriyor. İşletmecinin sorduğu
-- soru gerçekleşmeyen. Yeni veri gerekmiyor: `visits` × `availabilities`.
create or replace function public.venue_lost_demand(
  p_lounge_id uuid, p_gun int default 30, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid; v_ap text; v_k int := public.partner_k();
  v_satir jsonb; v_kacan int; v_karsilanan int;
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);
  select airport_code into v_ap from lounges where id = p_lounge_id;
  if v_ap is null then return jsonb_build_object('known', false); end if;

  select jsonb_agg(x order by (x ->> 'tarih')), sum((x ->> 'kacan')::int), sum((x ->> 'karsilanan')::int)
    into v_satir, v_kacan, v_karsilanan
  from (
    select jsonb_build_object(
             'tarih', v.visit_date,
             'yolcu', count(distinct v.user_id)::int,
             'karsilanan', count(distinct v.user_id) filter (where exists (
                 select 1 from requests r join sessions s on s.request_id = r.id
                  where r.guest_id = v.user_id and s.status = 'completed'
                    and s.completed_at::date = v.visit_date))::int,
             'kacan', count(distinct v.user_id) filter (where not exists (
                 select 1 from requests r join sessions s on s.request_id = r.id
                  where r.guest_id = v.user_id and s.status = 'completed'
                    and s.completed_at::date = v.visit_date))::int,
             'bos_slot', coalesce((
                 select sum(greatest(a.slots - coalesce(a.filled,0), 0))::int
                   from availabilities a
                  where a.lounge_id = p_lounge_id and a.avail_date = v.visit_date and a.active), 0)
           ) as x
      from visits v
      join users u on u.id = v.user_id
     where v.airport_code = v_ap
       and v.visit_date between current_date - p_gun and current_date
       and coalesce(u.is_staff,false) = false
       and u.deleted_at is null
     group by v.visit_date
    having count(distinct v.user_id) >= v_k     -- k-anonimite, GÜN düzeyinde
  ) q;

  return jsonb_build_object(
    'known', true, 'havalimani', v_ap, 'gun', p_gun, 'k_esigi', v_k,
    'kacan', coalesce(v_kacan,0), 'karsilanan', coalesce(v_karsilanan,0),
    'gunler', coalesce(v_satir, '[]'::jsonb),
    'baslik', case when coalesce(v_kacan,0) = 0
      then 'Bu dönemde kaçan talep görünmüyor.'
      else format('Son %s günde %s yolcu %s''te salon bulamadı.', p_gun, v_kacan, v_ap) end);
end $fn$;


-- ============================================================
-- 6) Ö3 · 72 SAATLİK GELEN DALGA — tek ileriye dönük ekran
-- ============================================================
-- Vardiya planlayan müdürün abonelik ödeme sebebi. `visits` +
-- `flight_cache` zaten dolu; yeni veri yok.
create or replace function public.venue_inbound_wave(
  p_lounge_id uuid, p_saat int default 72, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid; v_ap text; v_k int := public.partner_k(); v_satir jsonb;
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);
  select airport_code into v_ap from lounges where id = p_lounge_id;
  if v_ap is null then return jsonb_build_object('known', false); end if;

  select jsonb_agg(x order by (x ->> 'saat'))
    into v_satir
  from (
    -- 🔴 `group by 1` YAZMIŞTIM VE NÖBETÇİ YAKALADI:
    --     ERROR: aggregate functions are not allowed in GROUP BY
    -- Çünkü 1. seçim öğesi, İÇİNDE toplama fonksiyonu barındıran
    -- `jsonb_build_object(...)`. Konum numarasıyla gruplamak kısa
    -- yoldur ama ifadenin ne olduğunu gizler; ifadeyi AÇIKÇA yazmak
    -- hem çalışır hem okunur.
    select jsonb_build_object(
             'saat', to_char(date_trunc('hour',
                 coalesce(v.scheduled_departure, (v.visit_date + v.time_from)::timestamptz)),
               'YYYY-MM-DD HH24:00'),
             'yolcu', count(distinct v.user_id)::int,
             'terminal', coalesce(mode() within group (order by v.terminal), '—')
           ) as x
      from visits v
      join users u on u.id = v.user_id
     where v.airport_code = v_ap
       and coalesce(v.scheduled_departure, (v.visit_date + v.time_from)::timestamptz)
           between now() and now() + make_interval(hours => p_saat)
       and coalesce(u.is_staff,false) = false
       and u.deleted_at is null
     group by date_trunc('hour',
         coalesce(v.scheduled_departure, (v.visit_date + v.time_from)::timestamptz))
    having count(distinct v.user_id) >= v_k
  ) q;

  return jsonb_build_object(
    'known', true, 'havalimani', v_ap, 'saat', p_saat, 'k_esigi', v_k,
    'saatler', coalesce(v_satir, '[]'::jsonb),
    'not', 'Yalnız uygulamaya seyahat girmiş yolcular sayılır — havalimanının toplam trafiği DEĞİLDİR.');
end $fn$;


-- ============================================================
-- 7) Ö4 · KURAL UYUM DENETİMİ — resmî kural vs kapıda olan
-- ============================================================
-- İşletmeciye personel eğitimi çıktısı, bize kural motoru düzeltmesi.
-- İki taraf da kazanıyor; veri zaten elimizde.
create or replace function public.venue_rule_compliance(
  p_lounge_id uuid, p_gun int default 180, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare v_uid uuid; v_ven uuid; v_k int := public.partner_k(); v_satir jsonb;
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);
  select venue_id into v_ven from lounges where id = p_lounge_id;
  if v_ven is null then return jsonb_build_object('known', false); end if;

  select jsonb_agg(x order by (x ->> 'sapma')::int desc)
    into v_satir
  from (
    select jsonb_build_object(
             'program', p.name,
             'resmi_kabul', a.accepted,
             'kapida_giren', count(*) filter (where r.entered)::int,
             'kapida_cevrilen', count(*) filter (where not coalesce(r.entered,true))::int,
             -- SAPMA: resmî kural "kabul" diyor ama kapıda çevrilmiş,
             -- ya da tersi. İki yön de bizim için bilgi.
             'sapma', case when a.accepted
                           then count(*) filter (where not coalesce(r.entered,true))::int
                           else count(*) filter (where r.entered)::int end,
             'yon', case when a.accepted then 'kabul deniyor ama cevriliyor'
                                          else 'kabul edilmiyor deniyor ama giriliyor' end
           ) as x
      from lounge_field_reports r
      join lounge_programs p on p.id = r.program_id
      left join lounge_venue_acceptance a on a.venue_id = r.venue_id and a.program_id = r.program_id
     where r.venue_id = v_ven
       and r.created_at >= now() - make_interval(days => p_gun)
     group by p.name, a.accepted
    having count(*) >= v_k
  ) q;

  return jsonb_build_object(
    'known', true, 'gun', p_gun, 'k_esigi', v_k,
    'satirlar', coalesce(v_satir, '[]'::jsonb),
    'not', 'Sapma iki yönlü okunur: resmî kural yanlış olabilir ya da kapıda uygulama farklı olabilir. İkisi de düzeltilmeye değer.');
end $fn$;


-- ============================================================
-- 8) OPERATÖR ROLL-UP — çok salonlu işletmeci bugün dışarıda
-- ============================================================
-- IGA / TAV / Çelebi gibi işletmeciler hedef müşteri ama panel
-- `links[0]` diyerek yalnız BİRİNCİ salonu gösteriyordu.
create or replace function public.partner_lounges(p_user uuid default null)
returns table (lounge_id uuid, ad text, havalimani text, terminal text, isletmeci text, rol text)
language sql stable security definer set search_path = public as $fn$
  select l.id, l.name::text, l.airport_code::text, l.terminal::text,
         coalesce(v.operator, '—')::text, lp.role::text
    from lounge_partners lp
    join lounges l on l.id = lp.lounge_id
    left join lounge_venues v on v.id = l.venue_id
   where lp.user_id = coalesce(p_user, auth.uid())
   order by l.airport_code, l.name;
$fn$;


-- ============================================================
-- 9) YÜZEY — sağlayıcı fonksiyonları BO oturumundan çağrılacak
-- ============================================================
-- 🔴 Bunlar `service_role` ile DEĞİL, sağlayıcının KENDİ oturumuyla
-- çağrılmalı — ancak o zaman `auth.uid()` dolar ve RLS arka duvar
-- görevi görür. BO tarafı `sbSession()`'a çevrildi.
insert into rpc_client_surface (fn_name, client, note) values
  ('partner_demand','backoffice_session','Saglayici paneli — sbSession ile'),
  ('partner_payout','backoffice_session','Hakedis'),
  ('partner_lounges','backoffice_session','Cok salonlu isletmeci secici'),
  ('venue_gate_report','backoffice_session','Kapi raporu'),
  ('venue_lost_demand','backoffice_session','Kacan talep'),
  ('venue_inbound_wave','backoffice_session','72 saatlik gelen dalga'),
  ('venue_rule_compliance','backoffice_session','Kural uyum denetimi')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '209: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;

-- Yüzeydeki bu adlar `authenticated`a AÇIK olmalı (BO oturumu o rolde).
do $$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      join rpc_client_surface s on s.fn_name = p.proname
     where n.nspname='public' and p.prokind='f' and s.client = 'backoffice_session'
  loop
    execute format('grant execute on function public.%I(%s) to authenticated, anon', r.proname, r.args);
  end loop;
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) PANEL AÇILIYOR MU — sağlayıcı kendi oturumuyla veri alabiliyor mu
-- 🔴 Bu nöbetçi bugüne kadar OLMADIĞI için panel aylarca ölü kaldı.
do $$
declare v_u uuid; v_l uuid; v_n int;
begin
  select id into v_l from lounges limit 1;
  select id into v_u from auth.users limit 1;
  if v_l is null or v_u is null then raise notice '209: sahne yok — atlandi'; return; end if;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  insert into lounge_partners (user_id, lounge_id, role) values (v_u, v_l, 'manager');

  -- p_user ile: service_role'den de çalışmalı
  begin
    select count(*) into v_n from public.partner_demand(v_l, v_u);
  exception when others then
    delete from lounge_partners where user_id = v_u and lounge_id = v_l;
    raise exception '209: partner_demand p_user ile CALISMIYOR → %', sqlerrm;
  end;

  -- auth.uid() ile: uygulama/oturum yolundan da çalışmalı
  perform set_config('request.jwt.claims', json_build_object('sub', v_u, 'role','authenticated')::text, true);
  begin
    select count(*) into v_n from public.partner_demand(v_l);
  exception when others then
    perform set_config('request.jwt.claims','',true);
    delete from lounge_partners where user_id = v_u and lounge_id = v_l;
    raise exception '209: partner_demand oturum yolundan CALISMIYOR → %', sqlerrm;
  end;
  perform set_config('request.jwt.claims','',true);
  raise notice '209: partner_demand her iki yoldan da calisiyor';
end $$;

-- 2) KAPI GERÇEKTEN KAPALI MI (mutasyon)
-- Yetkisi olmayan biri veri alabiliyorsa kapı yoktur.
do $$
declare v_l uuid; v_y uuid; v_gecti boolean := false;
begin
  select id into v_l from lounges limit 1;
  select u.id into v_y from auth.users u
   where not exists (select 1 from lounge_partners lp where lp.user_id = u.id)
     and not exists (select 1 from admin_roles a where a.user_id = u.id)
   limit 1;
  if v_l is null or v_y is null then raise notice '209: yabanci kullanici yok — atlandi'; return; end if;

  begin perform public.partner_demand(v_l, v_y); v_gecti := true; exception when others then null; end;
  if v_gecti then raise exception '209: YABANCI biri partner_demand cagirabildi'; end if;

  v_gecti := false;
  begin perform public.venue_gate_report(v_l, 90, v_y); v_gecti := true; exception when others then null; end;
  if v_gecti then raise exception '209: YABANCI biri kapi raporunu okuyabildi'; end if;
  raise notice '209: sagalyici kapisi yabanciya kapali (iki fonksiyonda da)';
end $$;

-- 3) k-EŞİĞİ GERÇEKTEN UYGULANIYOR MU (mutasyon)
-- 🔴 Eşiği ayara taşımanın tek anlamı, DEĞİŞTİRİLEBİLİR olması.
-- Değiştirip sonucun değiştiğini kanıtlamazsam ayar sahtedir.
do $$
declare v_u uuid; v_l uuid; v_dusuk int; v_yuksek int; v_eski int;
begin
  select lp.user_id, lp.lounge_id into v_u, v_l from lounge_partners lp limit 1;
  if v_u is null then raise notice '209: partner yok — atlandi'; return; end if;
  select (value #>> '{}')::int into v_eski from beta_settings where key='partner_k_threshold';

  update beta_settings set value = to_jsonb(1) where key='partner_k_threshold';
  select count(*) into v_dusuk from public.partner_demand(v_l, v_u);
  update beta_settings set value = to_jsonb(9999) where key='partner_k_threshold';
  select count(*) into v_yuksek from public.partner_demand(v_l, v_u);
  update beta_settings set value = to_jsonb(coalesce(v_eski,5)) where key='partner_k_threshold';

  if v_yuksek > 0 then
    raise exception '209: k esigi 9999 iken bile % satir dondu — esik uygulanmiyor', v_yuksek;
  end if;
  -- 🔴 VERİ YOKKEN BU NÖBETÇİ HİÇBİR ŞEY KANITLAMAZ. İlk yazımda
  -- ikisi de 0 dönüyordu ve nöbetçi yeşil geçiyordu — yani "eşik
  -- çalışıyor" diyen bir satır, aslında hiç ölçüm yapmamıştı.
  -- Atlayan nöbetçi, olmayan nöbetçidir; artık ATLADIĞINI SÖYLÜYOR.
  if v_dusuk = 0 then
    raise notice '209: ⚠ k-esigi kanidi ATLANDI — bu salonda hic ilan verisi yok';
    return;
  end if;
  raise notice '209: k-anonimite esigi gercekten uygulaniyor (1 → % satir · 9999 → 0)', v_dusuk;
end $$;

-- 4) HAKEDİŞ, SIFIRI "BAŞARISIZLIK" GİBİ GÖSTERMİYOR
do $$
declare v_u uuid; v_l uuid; v jsonb;
begin
  select lp.user_id, lp.lounge_id into v_u, v_l from lounge_partners lp limit 1;
  if v_u is null then raise notice '209: partner yok — atlandi'; return; end if;
  v := public.partner_payout(v_l, current_date - 30, current_date, v_u);
  if (v ->> 'satis_akisi_var') = 'false' and (v ->> 'not') is null then
    raise exception '209: satis akisi yokken hicbir aciklama yok — ekran sifiri gercek sanir';
  end if;
  raise notice '209: hakedis durumu aciklaniyor → %', coalesce(v ->> 'not', 'akis var');
end $$;

-- 5) DÖRT YENİ EKRANIN HEPSİ ÇAĞRILABİLİYOR MU
do $$
declare v_u uuid; v_l uuid; v jsonb;
begin
  select lp.user_id, lp.lounge_id into v_u, v_l from lounge_partners lp limit 1;
  if v_u is null then raise notice '209: partner yok — atlandi'; return; end if;
  v := public.venue_gate_report(v_l, 90, v_u);
  if v is null then raise exception '209: kapi raporu NULL'; end if;
  v := public.venue_lost_demand(v_l, 30, v_u);
  if v is null or (v ->> 'baslik') is null then raise exception '209: kacan talep basliksiz'; end if;
  v := public.venue_inbound_wave(v_l, 72, v_u);
  if v is null then raise exception '209: gelen dalga NULL'; end if;
  v := public.venue_rule_compliance(v_l, 180, v_u);
  if v is null then raise exception '209: kural uyumu NULL'; end if;
  raise notice '209: dort yeni saglayici ekraninin verisi de uretiliyor';
end $$;

-- 6) OPERATÖR SEÇİCİ — çok salonlu işletmeci artık görünüyor
do $$
declare v_u uuid; v_n int;
begin
  select user_id into v_u from lounge_partners limit 1;
  if v_u is null then raise notice '209: partner yok — atlandi'; return; end if;
  select count(*) into v_n from public.partner_lounges(v_u);
  if v_n < 1 then raise exception '209: partner_lounges bos dondu'; end if;
  raise notice '209: partner_lounges % salon dondurdu (coklu salon destegi acik)', v_n;
end $$;

-- 7) SAHNEYİ TOPLA
do $$
begin
  delete from lounge_partners
   where role = 'manager'
     and user_id in (select id from auth.users limit 1)
     and created_at > now() - interval '5 minutes';
  raise notice '209: test partner kaydi temizlendi';
end $$;

select '209 OK - saglayici paneli calisiyor, k-esigi veride, dort yeni ekran acildi' as sonuc;
