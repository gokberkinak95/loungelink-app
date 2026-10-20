-- ============================================================================
-- 337 · JETSET · PLANA GÖRE PUAN VE HOST KREDİSİ · ÖDÜL FİYATLARI · KURULUŞ FİYATI
--       · HOST İÇİN PREMIUM (yalnız kimliği doğrulanmış misafir, ilan görüntülenmesi)
--       (19 Ekim 2026 · Gökberk onayı)
--
-- 1) "Kâhya" → JETSET (görünen ad; plan kodu `kahya` ve mağaza ürün kimlikleri DEĞİŞMEZ).
-- 2) Tamamlanan her buluşmada HERKES KENDİ PLANINA göre puan alır (host da misafir de):
--      Yolcu 100 · Sık Uçan 250 · Jetset 500. (Önceden plana bakmadan host 500 / misafir 200.)
--    Plan = buluşmanın tamamlandığı andaki ETKİN plan (hediye ay dahil).
-- 3) Host'a ağırlama kredisi: Sık Uçan 1 · Jetset 1. Yolcu: yalnız İLK ağırlamada bir kez 1.
--    Mevcut korumalar aynen: çift ödeme yok · günlük tavan · aynı çift tekrarı.
-- 4) Ücretsiz Sık Uçan ayı: 2 → 3 ağırlama. Hediye ayı bitişi/uyarısı bildirimleri o ay
--    kazanılanı söyler ve planlara yönlendirir (deneme köprüsü).
-- 5) Ödül fiyatları (nakit maliyetli ödüller ≈ 0,25 TL/puan; ilk hedef ulaşılabilir kalsın).
-- 6) Kuruluş fiyatı: 31 Mart 2027'ye kadar abone olanlar, abonelikleri kesintisiz sürdükçe
--    bu fiyattan yenilenir (fiyat artışında mağazada "mevcut aboneler eski fiyatı korur" seçilir).
-- 7) Host premium: ücretli plandaki host ilanını "yalnız kimliği doğrulanmış misafirler"e
--    açabilir; ilanını kaç kişinin gördüğünü görür (ücretsiz planda kilitli, ipucu gösterilir).
-- Supabase SQL Editor: tek dosya; geçici tablo / psql komutu yok. Tekrar koşulabilir.
-- ============================================================================

-- §1 · plan kataloğu: yeni kolonlar + değerler + Jetset
alter table plan_catalog add column if not exists agirlama_puani int;
alter table plan_catalog add column if not exists agirlama_kredisi int;
update plan_catalog set agirlama_puani = 100, agirlama_kredisi = 0 where plan::text not in ('sik_ucan','kahya');
update plan_catalog set agirlama_puani = 250, agirlama_kredisi = 1 where plan = 'sik_ucan';
update plan_catalog set agirlama_puani = 500, agirlama_kredisi = 1, ad = 'Jetset', ad_en = 'Jetset' where plan = 'kahya';

update plan_catalog set
  perks = '["Kayıtta 1 kredi: ilk lounge girişin bizden", "Bir seferde 1 host''a başvuru", "Haftada 3 bağlantı isteği", "Her buluşmada 100 LoungePuan", "Host isen: ilk ağırlamanda 1 kredi, 30 günde 3 ağırlamada Sık Uçan 1 ay bizden", "Kural motoru, sohbet ve güvenlik araçları"]'::jsonb,
  perks_en = '["1 credit on sign-up: your first lounge visit is on us", "Apply to 1 host at a time", "3 connection requests a week", "100 LoungePoints per meetup", "If you host: 1 credit on your first hosting, host 3 times within 30 days and Frequent Flyer is free for a month", "Rule engine, chat and safety tools"]'::jsonb
 where plan = 'yolcu';
update plan_catalog set
  perks = '["Her ay 3 lounge girişi (aylık kredi devretmez)", "Aynı anda 3 host''a başvur: kabul şansın artar", "Haftada 15 bağlantı isteği", "Her buluşmada 250 LoungePuan", "Host isen: her ağırlamada 1 kredi", "Host isen: ilanını kaç kişinin gördüğünü gör, yalnız kimliği doğrulanmış misafir kabul et", "Ayda 3 ilan öne çıkarma: daha çok misafir", "Haftalık kaçırılan fırsat bildirimi", "Kart hakkı dolma uyarısı: 90 · 30 · 7 gün önce"]'::jsonb,
  perks_en = '["3 lounge visits every month (monthly credits do not roll over)", "Apply to 3 hosts at once: better odds", "15 connection requests a week", "250 LoungePoints per meetup", "If you host: 1 credit per hosting", "If you host: see how many people viewed your listing, accept ID-verified guests only", "Feature a listing 3× a month: more guests", "Weekly missed-opportunity alerts", "Card benefit expiry alerts: 90 · 30 · 7 days ahead"]'::jsonb
 where plan = 'sik_ucan';
update plan_catalog set
  perks = '["Her ay 7 lounge girişi (aylık kredi devretmez)", "Aynı anda 6 host''a başvur", "Sınırsız bağlantı isteği", "Her buluşmada 500 LoungePuan", "Host isen: her ağırlamada 1 kredi", "Host isen: ilanını kaç kişinin gördüğünü gör, yalnız kimliği doğrulanmış misafir kabul et", "Ayda 8 ilan öne çıkarma: daha çok misafir", "Anlık kaçırılan fırsat bildirimi", "Kart hakkı dolma uyarısı: 90 · 30 · 7 gün önce", "Öncelikli destek"]'::jsonb,
  perks_en = '["7 lounge visits every month (monthly credits do not roll over)", "Apply to 6 hosts at once", "Unlimited connection requests", "500 LoungePoints per meetup", "If you host: 1 credit per hosting", "If you host: see how many people viewed your listing, accept ID-verified guests only", "Feature a listing 8× a month: more guests", "Instant missed-opportunity alerts", "Card benefit expiry alerts: 90 · 30 · 7 days ahead", "Priority support"]'::jsonb
 where plan = 'kahya';

-- §1b · host basamağı "Kâhya" → "Kaptan" (plan adı Jetset oldu; aynı kelime iki şeyi göstermesin)
update host_tiers set ad = 'Kaptan' where code = 'kahya';

-- §1c · Konsiyerj basamağı KALDIRILDI (Gökberk, 20 Ekim): 15 ağırlamada host'un kendi
--      isteklerini kredisiz yapıyordu → ücretli plana geçme sebebini eritiyordu.
--      En üst basamak artık Kaptan (5 ağırlama). request_credit_cost istek_bedava'yı
--      host_tiers'tan okur; satır yoksa bedel normal (1).
delete from host_tiers where code = 'konsiyerj';
update host_tiers set aciklama = 'Beş kişiyi ağırladın. En üst basamak: keşifte belirgin öncelik ve her yeni ilanın 24 saat öne çıkıyor.'
 where code = 'kahya';

-- §2 · etkin planı SUNUCU İÇİNDE okuyan yardımcı (kimlik kontrolü yok: confirm_session karşı
--      tarafın planını okumak zorunda; `etkin_plan` başkasının planında 'baskasinin_verisi' atar).
create or replace function public.etkin_plan_ic(p_user uuid)
returns text language plpgsql stable security definer set search_path = public as $ep337$
declare v_satin text; v_hed text;
begin
  select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = p_user;
  if v_satin is null then return 'yolcu'; end if;
  if not exists (select 1 from plan_catalog where plan::text = v_satin and aktif) then v_satin := 'yolcu'; end if;
  select g.plan::text into v_hed from plan_grants g join plan_catalog c on c.plan = g.plan and c.aktif
   where g.user_id = p_user and g.bitti_at is null and g.iptal_at is null and g.biter_at > now() limit 1;
  if v_hed is not null and (select sort_order from plan_catalog where plan::text = v_hed)
                         > (select sort_order from plan_catalog where plan::text = v_satin) then
    return v_hed;
  end if;
  return v_satin;
end $ep337$;
revoke all on function public.etkin_plan_ic(uuid) from public, anon, authenticated;
grant execute on function public.etkin_plan_ic(uuid) to service_role;

create or replace function public.plan_agirlama_puani(p_user uuid)
returns int language sql stable security definer set search_path = public as $pp337$
  select coalesce((select agirlama_puani from plan_catalog where plan::text = public.etkin_plan_ic(p_user)), 100)
$pp337$;
revoke all on function public.plan_agirlama_puani(uuid) from public, anon, authenticated;
grant execute on function public.plan_agirlama_puani(uuid) to service_role;

-- §3 · confirm_session: herkes kendi planına göre puan
do $cs337$
declare v_tanim text;
  v_eski text := 'values (v_r.host_id, 500, ''session_reward'', p_session_id),
             (v_r.guest_id, 200, ''session_reward'', p_session_id);';
begin
  select pg_get_functiondef(p.oid) into v_tanim from pg_proc p
   where p.proname = 'confirm_session' and p.pronamespace = 'public'::regnamespace limit 1;
  if v_tanim like '%plan_agirlama_puani%' then raise notice '337: confirm_session zaten guncel.'; return; end if;
  if position(v_eski in v_tanim) = 0 then raise exception '337: confirm_session govdesi beklenenden farkli — elle bak.'; end if;
  v_tanim := replace(v_tanim, v_eski,
    'values (v_r.host_id, public.plan_agirlama_puani(v_r.host_id), ''session_reward'', p_session_id),
             (v_r.guest_id, public.plan_agirlama_puani(v_r.guest_id), ''session_reward'', p_session_id);');
  execute v_tanim;
end $cs337$;

-- §4 · host ağırlama kredisi: plana göre (Yolcu yalnız ilk ağırlamada bir kez)
create or replace function public.host_credit_settle(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $hc337$
declare
  v_r requests%rowtype; v_s sessions%rowtype;
  v_tavan  int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_credit_daily_cap'), 3);
  v_pencere int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_window_days'), 30);
  v_tekrar int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_max_repeat'), 3);
  v_plan text; v_adet int; v_ilk boolean := false; v_bugun int; v_ciftte int; v_bal int;
begin
  select * into v_s from sessions where id = p_session_id;
  if not found or v_s.status <> 'completed' then return jsonb_build_object('ok', false, 'neden', 'oturum_tamamlanmadi'); end if;
  select * into v_r from requests where id = v_s.request_id;
  if not found then return jsonb_build_object('ok', false, 'neden', 'istek_yok'); end if;
  if exists (select 1 from credit_ledger where ref_id = p_session_id and reason = 'hosted_session') then
    return jsonb_build_object('ok', false, 'neden', 'zaten_odendi');
  end if;

  v_plan := public.etkin_plan_ic(v_r.host_id);
  v_adet := coalesce((select agirlama_kredisi from plan_catalog where plan::text = v_plan), 0);
  if v_adet <= 0 then
    -- Yolcu: yalnız İLK ağırlamada bir kez (alışsın); sonrası puan + ayda 3 ağırlamada Sık Uçan hediyesi.
    if not exists (select 1 from credit_ledger where user_id = v_r.host_id and reason = 'hosted_session') then
      v_adet := 1; v_ilk := true;
    else
      return jsonb_build_object('ok', true, 'kredi', 0, 'neden', 'plan_kredi_vermiyor', 'plan', v_plan);
    end if;
  end if;

  select coalesce(sum(delta),0) into v_bugun from credit_ledger
   where user_id = v_r.host_id and reason = 'hosted_session' and created_at >= date_trunc('day', now());
  if v_bugun >= v_tavan then return jsonb_build_object('ok', false, 'neden', 'gunluk_tavan', 'bugun', v_bugun); end if;

  select count(*) into v_ciftte from sessions s2 join requests r2 on r2.id = s2.request_id
   where s2.status = 'completed' and s2.completed_at >= now() - make_interval(days => v_pencere)
     and ((r2.host_id = v_r.host_id and r2.guest_id = v_r.guest_id) or (r2.host_id = v_r.guest_id and r2.guest_id = v_r.host_id));
  if v_ciftte > v_tekrar then return jsonb_build_object('ok', false, 'neden', 'ayni_cift_tekrari', 'adet', v_ciftte); end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.host_id;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (v_r.host_id, v_adet, 'hosted_session', p_session_id, v_bal + v_adet,
          case when v_ilk then 'Ilk agirlama hediyesi (Yolcu).' else 'Agirladigin icin (' || v_plan || ').' end);

  perform public.bildir(v_r.host_id, 'system',
    case when v_ilk then 'İlk ağırlaman: 1 kredi hediye ✦' else format('%s kredi kazandın ✦', v_adet) end,
    case when v_ilk then 'Bu krediyle kendi seyahatinde misafir olabilirsin. Sık Uçan ve Jetset''te her ağırlama 1 kredi kazandırır.'
         else 'Ağırladığın için. Bu krediyle, hakkın olmayan bir salonda sen misafir olabilirsin.' end,
    case when v_ilk then 'Your first hosting: 1 credit on us ✦' else format('You earned %s credit ✦', v_adet) end,
    case when v_ilk then 'Use it to be a guest on your own trip. On Frequent Flyer and Jetset every hosting earns 1 credit.'
         else 'For hosting. Use it to be a guest in a lounge you can''t enter yourself.' end,
    'session', p_session_id);
  return jsonb_build_object('ok', true, 'kredi', v_adet, 'ilk', v_ilk, 'yeni_bakiye', v_bal + v_adet);
end $hc337$;

-- §5 · ücretsiz Sık Uçan ayı: 3 ağırlama · ekonomi ayarları
update beta_settings set value = to_jsonb(3) where key = 'host_free_upgrade_sessions';
insert into beta_settings (key, value) values ('host_free_upgrade_sessions', to_jsonb(3)) on conflict (key) do nothing;
-- Sürdürülebilirlik hesabı en kötü durumu (iki taraf da Jetset) varsaysın:
update beta_settings set value = to_jsonb(500) where key = 'host_session_points';
update beta_settings set value = to_jsonb(500) where key = 'guest_session_points';

-- §5a · hediye eşiği "AYDA 3": son hediyeden bu yana VE son 30 gün içindeki ağırlamalar sayılır
--        (önceden yalnız "son hediyeden bu yana" sayılıyordu; 3 ağırlama aylara yayılsa da açılıyordu).
do $ph337$
declare v_tanim text;
  v_eski text := 'and s.completed_at > v_son;';
begin
  select pg_get_functiondef('public.plan_hediyesi_degerlendir(uuid)'::regprocedure) into v_tanim;
  if v_tanim like '%interval ''30 days''%' then raise notice '337: plan_hediyesi_degerlendir zaten guncel.'; return; end if;
  if position(v_eski in v_tanim) = 0 then raise exception '337: plan_hediyesi_degerlendir govdesi beklenenden farkli — elle bak.'; end if;
  v_tanim := replace(v_tanim, v_eski, 'and s.completed_at > greatest(v_son, now() - interval ''30 days'');');
  execute v_tanim;
end $ph337$;

-- §5b · hediye ayı bitişi/uyarısı: kazanılanı söyle, planlara yönlendir (deneme köprüsü)
create or replace function public.plan_hediyelerini_bitir()
returns jsonb language plpgsql security definer set search_path = public as $hb337$
declare
  r record; v_bitti int := 0; v_uyari int := 0; v_kredi int; v_puan int; v_esik int;
  v_warn int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_warn_days'), 3);
begin
  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 3);
  for r in
    select g.*, c.ad from plan_grants g left join plan_catalog c on c.plan = g.plan
     where g.bitti_at is null and g.iptal_at is null and g.biter_at <= now()
  loop
    update plan_grants set bitti_at = now() where id = r.id;
    select coalesce(sum(delta),0) into v_kredi from credit_ledger
     where user_id = r.user_id and reason = 'hosted_session' and created_at >= r.basladi_at;
    select coalesce(sum(delta),0) into v_puan from points_ledger
     where user_id = r.user_id and reason = 'session_reward' and created_at >= r.basladi_at;
    perform public.bildir(r.user_id, 'system',
      'Ücretsiz ayın doldu',
      format('%s ayında %s kredi ve %s LoungePuan kazandın. Planını korumak için %s''a geç; ya da ayda %s kişi ağırla, yeniden açılsın.',
             coalesce(r.ad,'Üst plan'), v_kredi, v_puan, coalesce(r.ad,'üst plan'), v_esik),
      'Your free month is over',
      format('During your %s month you earned %s credits and %s LoungePoints. Keep the plan by subscribing, or host %s people in a month to unlock it again.',
             coalesce(r.ad,'upgraded'), v_kredi, v_puan, v_esik),
      'plan', null);
    v_bitti := v_bitti + 1;
  end loop;
  for r in
    select g.*, c.ad from plan_grants g left join plan_catalog c on c.plan = g.plan
     where g.bitti_at is null and g.iptal_at is null and g.uyarildi_at is null
       and g.biter_at <= now() + make_interval(days => v_warn) and g.biter_at > now()
  loop
    update plan_grants set uyarildi_at = now() where id = r.id;
    perform public.bildir(r.user_id, 'system',
      coalesce(r.ad,'Üst plan') || ' hediyenin bitişine az kaldı',
      format('%s tarihinde eski planına döneceksin. Kredi ve puan avantajlarını korumak için planlara göz at.',
             to_char(timezone('Europe/Istanbul', r.biter_at), 'DD.MM.YYYY')),
      'Your ' || coalesce(r.ad,'upgraded') || ' gift ends soon',
      format('You go back to your previous plan on %s. See the plans to keep the credit and point perks.',
             to_char(timezone('Europe/Istanbul', r.biter_at), 'DD.MM.YYYY')),
      'plan', null);
    v_uyari := v_uyari + 1;
  end loop;
  return jsonb_build_object('ok', true, 'bitirilen', v_bitti, 'uyarilan', v_uyari);
end $hb337$;

-- §6 · ödül fiyatları (nakit maliyetli ≈ 0,25 TL/puan; ilk hedef ulaşılabilir)
update rewards set cost_points = 300  where title = 'Havalimanı Kahvesi';
update rewards set cost_points = 800  where title = '+2 Misafir İsteği Kredisi';
update rewards set cost_points = 2000 where title = 'Amazon Hediye Kartı ₺500';
update rewards set cost_points = 1500 where title in ('Airalo eSIM 3 GB', 'Airalo eSIM 3GB');
update rewards set cost_points = 3000 where title = 'Airalo eSIM 10GB';
update rewards set cost_points = 3500 where title in ('Marriott Bonvoy 20 $ Kredi', 'Marriott Bonvoy 20$ Kredi');
update rewards set cost_points = 4500 where title in ('Booking.com 25 $ Kredi', 'Booking.com 25$ Kredi');
update rewards set cost_points = 9000 where title = 'Booking.com 50$ Kredi';
update rewards set cost_points = 8000 where title = 'Türk Hava Yolları 1000 Mil';
update rewards set cost_points = 4000 where title = 'Türk Hava Yolları 500 Mil';
update rewards set cost_points = 6000 where title in ('Emirates Skywards 750 Mil', 'Priority Pass Misafir Kartı', 'DragonPass Günlük Kart');
update rewards set cost_points = 7500 where title = 'SafetyWing 1 Ay';
update rewards set subtitle = 'Aylık 3 kredi' where title = 'Sık Uçan Planı · 1 ay';

-- §7 · kuruluş fiyatı
insert into beta_settings (key, value) values ('kurulus_fiyat_bitis', to_jsonb('2027-03-31'::text))
  on conflict (key) do nothing;
create or replace function public.kurulus_fiyati()
returns jsonb language sql stable security definer set search_path = public as $kf337$
  select jsonb_build_object(
    'bitis', b.v,
    'aktif', b.v is not null and b.v <> '' and current_date <= b.v::date)
  from (select (select value #>> '{}' from beta_settings where key = 'kurulus_fiyat_bitis') as v) b
$kf337$;
revoke all on function public.kurulus_fiyati() from public;
grant execute on function public.kurulus_fiyati() to anon, authenticated, service_role;

create or replace function public.subscription_plans(p_lang text default 'tr')
returns jsonb language sql stable security definer set search_path = public as $sp337$
  select jsonb_agg(jsonb_build_object(
           'plan', p.plan, 'ad',
             case when lower(coalesce(p_lang,'tr')) = 'en' then coalesce(nullif(p.ad_en,''), p.ad) else p.ad end,
           'aylik_kredi', p.monthly_credits,
           'aylik_fiyat', p.price_try, 'yillik_fiyat', p.yillik_try,
           'yillik_indirim_yuzde', case when p.price_try > 0 and p.yillik_try > 0
             then round(100 - (p.yillik_try::numeric / (p.price_try * 12) * 100)) end,
           'haklar',
             case when lower(coalesce(p_lang,'tr')) = 'en' and jsonb_array_length(coalesce(p.perks_en,'[]'::jsonb)) > 0
                  then p.perks_en else p.perks end,
           'sira', p.sort_order,
           'kacirilan_sikligi', p.kacirilan_sikligi,
           'oncelikli_destek', p.oncelikli_destek,
           'acik_istek', p.acik_istek_tavani,
           'baglanti_haftalik', p.baglanti_haftalik,
           'agirlama_puani', p.agirlama_puani,
           'agirlama_kredisi', p.agirlama_kredisi,
           'kurulus', (public.kurulus_fiyati() ->> 'aktif')::boolean and p.price_try > 0,
           'kurulus_bitis', public.kurulus_fiyati() ->> 'bitis')
         order by p.sort_order)
    from plan_catalog p where p.aktif;
$sp337$;
grant execute on function public.subscription_plans(text) to anon, authenticated;

-- §8 · host premium A: yalnız kimliği doğrulanmış misafir
alter table availabilities add column if not exists yalniz_kimlikli boolean not null default false;

create or replace function public.trg_ilan_yalniz_kimlikli_plan()
returns trigger language plpgsql security definer set search_path = public as $yk337$
begin
  -- Ücretli plan özelliği: Yolcu'da sessizce kapanır (eski uygulama da yazamasın).
  if new.yalniz_kimlikli and public.etkin_plan_ic(new.host_id) not in ('sik_ucan','kahya') then
    new.yalniz_kimlikli := false;
  end if;
  return new;
end $yk337$;
drop trigger if exists ilan_yalniz_kimlikli_plan on availabilities;
create trigger ilan_yalniz_kimlikli_plan before insert or update of yalniz_kimlikli on availabilities
  for each row execute function public.trg_ilan_yalniz_kimlikli_plan();

create or replace function public.trg_istek_yalniz_kimlikli()
returns trigger language plpgsql security definer set search_path = public as $iy337$
begin
  if exists (select 1 from availabilities a where a.id = new.avail_id and a.yalniz_kimlikli)
     and not coalesce((select id_verified from verifications where user_id = new.guest_id), false) then
    raise exception 'ilan_yalniz_kimlikli';
  end if;
  return new;
end $iy337$;
drop trigger if exists istek_yalniz_kimlikli on requests;
create trigger istek_yalniz_kimlikli before insert on requests
  for each row execute function public.trg_istek_yalniz_kimlikli();

create or replace function public.ilan_yalniz_kimlikli_ayarla(p_avail uuid, p_acik boolean)
returns jsonb language plpgsql security definer set search_path = public as $ya337$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from availabilities where id = p_avail and host_id = v_uid) then raise exception 'not_host'; end if;
  if p_acik and public.etkin_plan_ic(v_uid) not in ('sik_ucan','kahya') then raise exception 'plan_gerekli'; end if;
  update availabilities set yalniz_kimlikli = coalesce(p_acik, false), updated_at = now() where id = p_avail;
  return jsonb_build_object('ok', true, 'yalniz_kimlikli', coalesce(p_acik, false));
end $ya337$;
revoke all on function public.ilan_yalniz_kimlikli_ayarla(uuid, boolean) from public, anon;
grant execute on function public.ilan_yalniz_kimlikli_ayarla(uuid, boolean) to authenticated;

-- §9 · host premium B: ilan görüntülenmesi (kişi başına günde bir kez sayılır)
create table if not exists public.ilan_gorunumleri (
  avail_id uuid not null references public.availabilities(id) on delete cascade,
  izleyen  uuid not null references public.users(id) on delete cascade,
  gun      date not null default current_date,
  primary key (avail_id, izleyen, gun)
);
alter table public.ilan_gorunumleri enable row level security;

create or replace function public.ilan_gorunum_yaz(p_ids uuid[])
returns int language plpgsql security definer set search_path = public as $gy337$
declare v_uid uuid := auth.uid(); v_n int;
begin
  if v_uid is null or p_ids is null then return 0; end if;
  insert into ilan_gorunumleri (avail_id, izleyen)
  select a.id, v_uid from availabilities a
   where a.id = any (p_ids[1:60]) and a.host_id <> v_uid
  on conflict do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $gy337$;
revoke all on function public.ilan_gorunum_yaz(uuid[]) from public, anon;
grant execute on function public.ilan_gorunum_yaz(uuid[]) to authenticated;

create or replace function public.ilan_gorunum_istatistigi()
returns jsonb language plpgsql stable security definer set search_path = public as $gi337$
declare v_uid uuid := auth.uid(); v_acik boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_acik := public.etkin_plan_ic(v_uid) in ('sik_ucan','kahya');
  if not v_acik then return jsonb_build_object('acik', false); end if;
  return jsonb_build_object('acik', true, 'ilanlar', coalesce((
    select jsonb_object_agg(a.id, jsonb_build_object(
             'toplam', (select count(distinct g.izleyen) from ilan_gorunumleri g where g.avail_id = a.id),
             'hafta',  (select count(distinct g.izleyen) from ilan_gorunumleri g where g.avail_id = a.id and g.gun > current_date - 7)))
      from availabilities a where a.host_id = v_uid and a.avail_date >= current_date - 30), '{}'::jsonb));
end $gi337$;
revoke all on function public.ilan_gorunum_istatistigi() from public, anon;
grant execute on function public.ilan_gorunum_istatistigi() to authenticated;

-- §10 · doğrulama
select 'jetset adi' as kontrol, (select ad from plan_catalog where plan = 'kahya') = 'Jetset' as tamam
union all select 'plan puanlari 100/250/500', (select array_agg(agirlama_puani order by sort_order) from plan_catalog where plan in ('yolcu','sik_ucan','kahya')) = array[100,250,500]
union all select 'host kredisi 0/1/1', (select array_agg(agirlama_kredisi order by sort_order) from plan_catalog where plan in ('yolcu','sik_ucan','kahya')) = array[0,1,1]
union all select 'confirm_session plana gore', (select bool_or(prosrc like '%plan_agirlama_puani%') from pg_proc where proname = 'confirm_session')
union all select 'hediye esigi 3', (select (value #>> '{}')::int from beta_settings where key = 'host_free_upgrade_sessions') = 3
union all select 'amazon 2000', (select cost_points from rewards where title = 'Amazon Hediye Kartı ₺500') = 2000
union all select 'kurulus fiyati aktif', (public.kurulus_fiyati() ->> 'aktif')::boolean
union all select 'yalniz kimlikli tetikleyici', exists (select 1 from pg_trigger where tgname = 'istek_yalniz_kimlikli')
union all select 'gorunum tablosu', to_regclass('public.ilan_gorunumleri') is not null
union all select 'host basamagi kaptan', (select ad from host_tiers where code = 'kahya') = 'Kaptan'
union all select 'hediye 30 gun penceresi', pg_get_functiondef('public.plan_hediyesi_degerlendir(uuid)'::regprocedure) like '%30 days%'
union all select 'konsiyerj kaldirildi', not exists (select 1 from host_tiers where istek_bedava or code = 'konsiyerj');
-- Beklenen: on iki satır tamam = true.
