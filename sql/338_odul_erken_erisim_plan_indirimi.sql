-- ============================================================================
-- 338 · ÖDÜL MAĞAZASI: PLANA GÖRE İNDİRİM · ERKEN ERİŞİM · VİTRİN SÜRESİ   (20 Ekim 2026)
--
-- Gökberk'in kararları (20 Ekim):
--   · Plana göre ödül indirimi: oran BO'dan plan başına girilir (plan_catalog.odul_indirim_yuzde).
--     0 ya da boş = indirim yok → uygulamada şerit, üstü çizili fiyat, "Jetset'te …" satırı ÇIKMAZ.
--     Fiyat HER ZAMAN sunucuda hesaplanır; ekranda görünen = düşen = deftere yazılan.
--   · Erken erişim: BO'da ödülün "Erken erişim" kutusu + açılış anı + kaç gün. Süre boyunca yalnız
--     ÜCRETLİ etkin plan (Sık Uçan, Jetset; hediye ayı dahil) alabilir — host/misafir fark etmez.
--     Süre bitince herkese açılır; sayaç ve rozet kalkar (zaman sunucudan gelir).
--   · Vitrin: "Vitrinde göster" + kaç gün. Süre bitince ödül listeye iner; aynı ödül iki yerde çıkmaz.
--     Vitrinde tek ödül (mevcut kısmi benzersiz indeks).
--
-- Supabase SQL Editor'de tek parça koşar; temp tablo yok. Tekrar koşulabilir.
-- Doğrulama: en altta on bir satır tamam = true.
-- ============================================================================

-- §1 · kolonlar
alter table rewards add column if not exists erken_erisim boolean not null default false;
alter table rewards add column if not exists acilis_at timestamptz;
alter table rewards add column if not exists erken_erisim_gun int;
alter table rewards add column if not exists vitrin_bitis timestamptz;
alter table rewards add column if not exists plan_indirimi_yok boolean not null default false;

do $c338$ begin
  if not exists (select 1 from pg_constraint where conname = 'rewards_erken_erisim_chk') then
    alter table rewards add constraint rewards_erken_erisim_chk check (
      not erken_erisim or (acilis_at is not null and erken_erisim_gun between 1 and 30));
  end if;
end $c338$;

alter table plan_catalog add column if not exists odul_indirim_yuzde int not null default 0;
do $c338b$ begin
  if not exists (select 1 from pg_constraint where conname = 'plan_catalog_odul_indirim_chk') then
    alter table plan_catalog add constraint plan_catalog_odul_indirim_chk check (odul_indirim_yuzde between 0 and 50);
  end if;
end $c338b$;

-- Başlangıç oranları (Gökberk'in örneği). BO › Planlar'dan değişir.
update plan_catalog set odul_indirim_yuzde = 5  where plan = 'sik_ucan' and odul_indirim_yuzde = 0;
update plan_catalog set odul_indirim_yuzde = 10 where plan = 'kahya'    and odul_indirim_yuzde = 0;

-- Plan ödülü plan sahibine bir şey katmaz → indirimsiz.
update rewards set plan_indirimi_yok = true where title like 'Sık Uçan Planı%';

-- Ödenen tutarın liste fiyatı (BO raporu: indirimin puan maliyeti).
alter table redemptions add column if not exists liste_puani int;

-- Açılış anı gelmemiş ödül kimseye görünmez (eski uygulama doğrudan tablodan okur).
drop policy if exists rewards_read on rewards;
create policy rewards_read on rewards for select to authenticated
  using (active = true and (acilis_at is null or acilis_at <= now()));

-- §2 · yardımcılar
create or replace function public.plan_ucretli(p_plan text)
returns boolean language sql stable security definer set search_path = public as $f338$
  select coalesce((select price_try > 0 from plan_catalog where plan::text = p_plan), false);
$f338$;

-- İndirimli fiyat: 10'un katına AŞAĞI yuvarlanır (kullanıcı lehine; %5 bile 300'lük ödülde görünür).
create or replace function public.odul_fiyati_ic(p_cost int, p_indirimsiz boolean, p_plan text)
returns int language plpgsql stable security definer set search_path = public as $f338b$
declare v_pct int;
begin
  if p_cost is null then return null; end if;
  if coalesce(p_indirimsiz, false) then return p_cost; end if;
  select coalesce(odul_indirim_yuzde, 0) into v_pct from plan_catalog where plan::text = p_plan;
  if coalesce(v_pct, 0) <= 0 then return p_cost; end if;
  return least(p_cost, greatest(0, (floor(p_cost * (100 - v_pct) / 100.0 / 10) * 10)::int));
end $f338b$;

revoke all on function public.plan_ucretli(text) from public, anon;
revoke all on function public.odul_fiyati_ic(int, boolean, text) from public, anon, authenticated;

-- §3 · mağaza: kullanıcıya kendi fiyatı + erken erişim + vitrin durumu, hepsi sunucu saatiyle
create or replace function public.odul_magazasi()
returns jsonb language plpgsql stable security definer set search_path = public as $m338$
declare
  v_uid uuid := auth.uid();
  v_plan text;
  v_ucretli boolean;
  v_now timestamptz := now();
  v_oduller jsonb;
  v_indirim jsonb;
  v_sonraki timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_plan := public.etkin_plan_ic(v_uid);
  v_ucretli := public.plan_ucretli(v_plan);

  -- İndirimi olan ücretli planlar (Yolcu'daki "Jetset'te …" satırı ve şerit buradan).
  select coalesce(jsonb_agg(jsonb_build_object('plan', p.plan, 'ad', p.ad, 'ad_en', coalesce(nullif(p.ad_en,''), p.ad),
                                               'yuzde', p.odul_indirim_yuzde) order by p.sort_order), '[]'::jsonb)
    into v_indirim
    from plan_catalog p where p.aktif and p.price_try > 0 and p.odul_indirim_yuzde > 0;

  with r as (
    select w.*,
           (w.erken_erisim and w.acilis_at <= v_now
              and v_now < w.acilis_at + make_interval(days => w.erken_erisim_gun)) as erken_aktif,
           case when w.erken_erisim then w.acilis_at + make_interval(days => w.erken_erisim_gun) end as erken_bitis,
           (w.is_featured and (w.vitrin_bitis is null or w.vitrin_bitis > v_now)) as vitrin_aktif
      from rewards w
     where w.active and (w.acilis_at is null or w.acilis_at <= v_now)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', r.id, 'title', r.title, 'subtitle', r.subtitle, 'category', r.category,
           'stock', r.stock, 'featured_note', r.featured_note, 'sort_order', r.sort_order,
           'cost_points', r.cost_points,
           'fiyat', public.odul_fiyati_ic(r.cost_points, r.plan_indirimi_yok, v_plan),
           'plan_fiyatlari', (select coalesce(jsonb_agg(jsonb_build_object(
                                 'plan', p.plan, 'ad', p.ad, 'ad_en', coalesce(nullif(p.ad_en,''), p.ad),
                                 'fiyat', public.odul_fiyati_ic(r.cost_points, r.plan_indirimi_yok, p.plan::text))
                                 order by p.sort_order), '[]'::jsonb)
                                from plan_catalog p
                               where p.aktif and p.price_try > 0 and p.odul_indirim_yuzde > 0
                                 and not r.plan_indirimi_yok),
           'erken', r.erken_aktif,
           'erken_bitis', case when r.erken_aktif then r.erken_bitis end,
           'alabilir', (not r.erken_aktif) or v_ucretli,
           'vitrin', r.vitrin_aktif,
           'is_featured', r.vitrin_aktif)
         order by r.sort_order), '[]'::jsonb)
    into v_oduller from r;

  -- İstemci tam bu anda yenilesin diye: en yakın erken-erişim bitişi / vitrin bitişi / açılış.
  select min(t) into v_sonraki from (
    select acilis_at + make_interval(days => erken_erisim_gun) as t from rewards
     where active and erken_erisim and acilis_at + make_interval(days => erken_erisim_gun) > v_now
    union all select vitrin_bitis from rewards where active and is_featured and vitrin_bitis > v_now
    union all select acilis_at from rewards where active and acilis_at > v_now
  ) x;

  return jsonb_build_object(
    'simdi', v_now, 'sonraki_degisim', v_sonraki,
    'plan', v_plan, 'ucretli', v_ucretli,
    'benim_yuzde', case when v_ucretli then coalesce((select odul_indirim_yuzde from plan_catalog where plan::text = v_plan), 0) else 0 end,
    'indirimli_planlar', v_indirim,
    'ucretli_planlar', (select coalesce(jsonb_agg(jsonb_build_object('plan', p.plan, 'ad', p.ad,
                          'ad_en', coalesce(nullif(p.ad_en,''), p.ad)) order by p.sort_order), '[]'::jsonb)
                          from plan_catalog p where p.aktif and p.price_try > 0),
    'oduller', v_oduller);
end $m338$;
revoke all on function public.odul_magazasi() from public, anon;
grant execute on function public.odul_magazasi() to authenticated;

-- §4 · ödül al: fiyat SUNUCUDA, erken erişim SUNUCUDA, ekrandaki fiyatla karşılaştırma
--      p_beklenen: uygulamanın gösterdiği fiyat. Farklıysa (plan/oran değişti) 'odul_fiyati_degisti'
--      — sessizce başka bir puan düşmez. Eski uygulama p_beklenen göndermez → sunucu fiyatı geçerli.
drop function if exists public.redeem_reward(uuid);
create or replace function public.redeem_reward(p_reward_id uuid, p_beklenen int default null)
returns jsonb language plpgsql security definer set search_path = public as $rr338$
declare
  v_uid  uuid := auth.uid();
  v_r    rewards%rowtype;
  v_plan text;
  v_fiyat int;
  v_pts  int;
  v_ref  text;
  v_due  timestamptz;
  v_id   uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  -- Kilit ÖNCE, bakiye SONRA (aynı anda iki alım bakiyeyi iki kez harcayamaz).
  perform pg_advisory_xact_lock(hashtextextended('puan:' || v_uid::text, 0));
  select * into v_r from rewards where id = p_reward_id for update;
  if not found or not coalesce(v_r.active,false) then raise exception 'reward_unavailable'; end if;
  if v_r.acilis_at is not null and v_r.acilis_at > now() then raise exception 'reward_unavailable'; end if;
  if v_r.stock is not null and v_r.stock <= 0 then raise exception 'out_of_stock'; end if;
  if v_r.teslim_sekli is null or v_r.teslim_saat is null or v_r.supplier is null then
    raise exception 'reward_fulfillment_undefined';
  end if;

  v_plan := public.etkin_plan_ic(v_uid);
  if v_r.erken_erisim and now() < v_r.acilis_at + make_interval(days => v_r.erken_erisim_gun)
     and not public.plan_ucretli(v_plan) then
    raise exception 'odul_erken_erisimde';
  end if;

  v_fiyat := public.odul_fiyati_ic(v_r.cost_points, v_r.plan_indirimi_yok, v_plan);
  if p_beklenen is not null and p_beklenen <> v_fiyat then raise exception 'odul_fiyati_degisti'; end if;

  select coalesce(sum(delta),0) into v_pts from points_ledger where user_id = v_uid;
  if v_pts < v_fiyat then raise exception 'insufficient_points'; end if;

  v_ref := 'TAL-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(md5(random()::text), 1, 5));
  v_due := now() + make_interval(hours => v_r.teslim_saat);

  -- redemptions.cost_points = ÖDENEN (iade bu sayıyı geri yükler) · liste_puani = indirimsiz fiyat
  insert into redemptions (user_id, reward_id, cost_points, liste_puani, voucher_code, durum, due_at)
  values (v_uid, p_reward_id, v_fiyat, v_r.cost_points, v_ref, 'bekliyor', v_due)
  returning id into v_id;

  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -v_fiyat, 'reward_redeem', p_reward_id);

  if v_r.stock is not null then
    update rewards set stock = stock - 1 where id = p_reward_id;
  end if;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_uid, 'system', 'Talebin alındı ✦',
          v_r.title || ' · ' || v_fiyat || ' LoungePuan · takip no ' || v_ref || E'\n'
       || v_r.supplier || ' tarafından hazırlanıyor. En geç '
       || to_char(v_due, 'DD.MM HH24:MI') || ' itibarıyla hesabındaki e-posta adresine gelecek. '
       || 'Gelmezse bu takip numarasıyla bize yaz — puanın iade edilir.',
          'reward', v_id);

  return jsonb_build_object(
    'ok', true, 'takip_no', v_ref, 'durum', 'bekliyor', 'teslim_sekli', v_r.teslim_sekli,
    'son_tarih', v_due, 'tedarikci', v_r.supplier,
    'puan', v_fiyat, 'liste_puani', v_r.cost_points,
    'bakiye', v_pts - v_fiyat, 'code', v_ref, 'voucher', v_ref);
end $rr338$;
revoke all on function public.redeem_reward(uuid, int) from public, anon;
grant execute on function public.redeem_reward(uuid, int) to authenticated, service_role;

-- §5 · BO: yayın ayarları tek işlemde (vitrin tekliği + erken erişim + indirimsizlik)
create or replace function public.odul_yayin_ayarla(
  p_reward uuid, p_erken boolean, p_acilis timestamptz, p_erken_gun int,
  p_vitrin boolean, p_vitrin_gun int, p_indirimsiz boolean)
returns jsonb language plpgsql security definer set search_path = public as $y338$
declare v_r rewards%rowtype; v_bas timestamptz; v_eski uuid;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_r from rewards where id = p_reward for update;
  if not found then raise exception 'reward_not_found'; end if;
  if coalesce(p_erken,false) and (p_acilis is null or p_erken_gun is null or p_erken_gun not between 1 and 30) then
    raise exception 'erken_erisim_eksik';
  end if;
  if coalesce(p_vitrin,false) and not coalesce(v_r.active,true) then raise exception 'reward_inactive'; end if;
  if coalesce(p_vitrin,false) and p_vitrin_gun is not null and p_vitrin_gun not between 1 and 60 then
    raise exception 'vitrin_suresi_gecersiz';
  end if;

  update rewards set
    erken_erisim = coalesce(p_erken,false),
    -- Kutu kalkarsa erken erişim alanları sıfırlanır; açılış anı da (ödül hemen görünür olur).
    acilis_at = case when coalesce(p_erken,false) then p_acilis else null end,
    erken_erisim_gun = case when coalesce(p_erken,false) then p_erken_gun else null end,
    plan_indirimi_yok = coalesce(p_indirimsiz, false)
  where id = p_reward;

  if coalesce(p_vitrin,false) then
    select id into v_eski from rewards where is_featured and id <> p_reward;
    update rewards set is_featured = false, vitrin_bitis = null where is_featured and id <> p_reward;
    v_bas := greatest(now(), coalesce(case when coalesce(p_erken,false) then p_acilis end, now()));
    update rewards set is_featured = true,
           vitrin_bitis = case when p_vitrin_gun is null then null else v_bas + make_interval(days => p_vitrin_gun) end
     where id = p_reward;
  else
    update rewards set is_featured = false, vitrin_bitis = null where id = p_reward;
  end if;

  return jsonb_build_object('ok', true, 'vitrinden_inen', v_eski);
end $y338$;
revoke all on function public.odul_yayin_ayarla(uuid, boolean, timestamptz, int, boolean, int, boolean) from public, anon, authenticated;
grant execute on function public.odul_yayin_ayarla(uuid, boolean, timestamptz, int, boolean, int, boolean) to service_role;

-- BO tablosu için: her ödülün plan başına fiyatı (aynı hesap: odul_fiyati_ic). Yalnız service_role.
create or replace function public.bo_odul_fiyatlari()
returns jsonb language sql stable security definer set search_path = public as $bf338$
  select coalesce(jsonb_object_agg(r.id, (
           select jsonb_object_agg(p.plan, public.odul_fiyati_ic(r.cost_points, r.plan_indirimi_yok, p.plan::text))
             from plan_catalog p where p.aktif)), '{}'::jsonb)
    from rewards r;
$bf338$;
revoke all on function public.bo_odul_fiyatlari() from public, anon, authenticated;
grant execute on function public.bo_odul_fiyatlari() to service_role;

-- Eski "öne çıkar" düğmesi vitrin_bitis'i de temizlesin (süresiz vitrin).
create or replace function public.set_featured_reward(p_reward_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $sf338$
declare v_title text; v_active boolean;
begin
  if p_reward_id is null then
    update rewards set is_featured = false, vitrin_bitis = null where is_featured;
    return jsonb_build_object('ok', true, 'featured', null);
  end if;
  select title, coalesce(active, true) into v_title, v_active from rewards where id = p_reward_id;
  if not found then raise exception 'reward_not_found'; end if;
  if not v_active then raise exception 'reward_inactive'; end if;
  update rewards set is_featured = false, vitrin_bitis = null where is_featured and id <> p_reward_id;
  update rewards set is_featured = true, vitrin_bitis = null where id = p_reward_id;
  return jsonb_build_object('ok', true, 'featured', p_reward_id, 'title', v_title);
end $sf338$;

-- §6 · plan kartları: indirim ve erken erişim satırları ORANDAN üretilir (app + site aynı kaynaktan)
create or replace function public.subscription_plans(p_lang text default 'tr')
returns jsonb language sql stable security definer set search_path = public as $sp338$
  select jsonb_agg(jsonb_build_object(
           'plan', p.plan, 'ad',
             case when lower(coalesce(p_lang,'tr')) = 'en' then coalesce(nullif(p.ad_en,''), p.ad) else p.ad end,
           'aylik_kredi', p.monthly_credits,
           'aylik_fiyat', p.price_try, 'yillik_fiyat', p.yillik_try,
           'yillik_indirim_yuzde', case when p.price_try > 0 and p.yillik_try > 0
             then round(100 - (p.yillik_try::numeric / (p.price_try * 12) * 100)) end,
           'haklar',
             (case when lower(coalesce(p_lang,'tr')) = 'en' and jsonb_array_length(coalesce(p.perks_en,'[]'::jsonb)) > 0
                   then p.perks_en else p.perks end)
             || case when p.odul_indirim_yuzde > 0 then jsonb_build_array(
                  case when lower(coalesce(p_lang,'tr')) = 'en'
                       then format('%s%% off rewards', p.odul_indirim_yuzde)
                       else format('Ödüllerde %%%s indirim', p.odul_indirim_yuzde) end) else '[]'::jsonb end
             || case when p.price_try > 0 then jsonb_build_array(
                  case when lower(coalesce(p_lang,'tr')) = 'en' then 'Early access to new rewards'
                       else 'Yeni ödüllere erken erişim' end) else '[]'::jsonb end,
           'sira', p.sort_order,
           'kacirilan_sikligi', p.kacirilan_sikligi,
           'oncelikli_destek', p.oncelikli_destek,
           'acik_istek', p.acik_istek_tavani,
           'baglanti_haftalik', p.baglanti_haftalik,
           'agirlama_puani', p.agirlama_puani,
           'agirlama_kredisi', p.agirlama_kredisi,
           'odul_indirim_yuzde', p.odul_indirim_yuzde,
           'erken_erisim', p.price_try > 0,
           'kurulus', (public.kurulus_fiyati() ->> 'aktif')::boolean and p.price_try > 0,
           'kurulus_bitis', public.kurulus_fiyati() ->> 'bitis')
         order by p.sort_order)
    from plan_catalog p where p.aktif;
$sp338$;
grant execute on function public.subscription_plans(text) to anon, authenticated;

-- §6b · Plan ekranındaki hediye sayacı 337'nin kuralıyla aynı: SON 30 GÜN (son hediyeden sonrası).
--      Önceki sayaç tüm zamanları sayıyordu: "3 kişi ağırladın. 3 ağırlamada üst plan açılıyor" diyordu
--      ama hediye 30 gün penceresinde değerlendirildiği için açılmıyordu.
do $mp338$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
   where p.proname = 'my_plan' and p.pronamespace = 'public'::regnamespace limit 1;
  if v_def is null then raise exception '338: my_plan bulunamadi'; end if;
  if v_def like '%338 · 30 gün%' then return; end if;
  v_yeni := replace(v_def,
    'where r.host_id = v_uid and s.status=''completed'' and s.completed_at > v_son;',
    'where r.host_id = v_uid and s.status=''completed'' and s.completed_at > greatest(v_son, now() - interval ''30 days''); -- 338 · 30 gün');
  v_yeni := replace(v_yeni,
    'when v_agir > 0 then format(''%s kişi ağırladın. %s ağırlamada üst plan 1 ay ücretsiz açılıyor.'', v_agir, v_esik)',
    'when v_agir > 0 then format(''Son 30 günde %s kişi ağırladın. %s ağırlama daha yaparsan %s 1 ay ücretsiz açılır.'', v_agir, greatest(1, v_esik - v_agir), coalesce((select ad from plan_catalog where plan::text = v_plan_hediye), ''üst plan''))');
  v_yeni := replace(v_yeni,
    'else format(''Birini ağırla — %s ağırlamada üst plan %s gün boyunca ücretsiz açılır.'', v_esik, v_gun) end;',
    'else format(''Birini ağırla — 30 gün içinde %s ağırlamada %s %s gün boyunca ücretsiz açılır.'', v_esik, coalesce((select ad from plan_catalog where plan::text = v_plan_hediye), ''üst plan''), v_gun) end;');
  -- Zaten hediye planında ya da üstünde olan (Sık Uçan, Jetset) "X ağırlama daha yaparsan Sık Uçan açılır"
  -- cümlesini görmesin: ona kendi planının ağırlama kazancı yazılır.
  v_yeni := replace(v_yeni,
    'select * into v_p from plan_catalog where plan = v_etkin;',
    'if v_g.id is null and (select sort_order from plan_catalog where plan::text = v_plan_hediye)
        <= coalesce((select sort_order from plan_catalog where plan::text = v_satin), -1) then
    v_neden := (select format(''Her buluşmada %s LoungePuan, her ağırlamada %s kredi kazanırsın.'',
                              coalesce(pc.agirlama_puani, 0), coalesce(pc.agirlama_kredisi, 0))
                  from plan_catalog pc where pc.plan::text = v_satin);
  end if; -- 338 · ücretli plan cümlesi

  select * into v_p from plan_catalog where plan = v_etkin;');
  if v_yeni = v_def or v_yeni not like '%338 · 30 gün%' or v_yeni not like '%338 · ücretli plan cümlesi%' or v_yeni like '%üst plan 1 ay ücretsiz açılıyor%' then
    raise exception '338: my_plan metni beklenen bicimde degil, yama uygulanamadi';
  end if;
  execute v_yeni;
end $mp338$;

-- §7 · doğrulama
select 'erken erisim kolonlari' as kontrol, (select count(*) from information_schema.columns where table_name = 'rewards'
         and column_name in ('erken_erisim','acilis_at','erken_erisim_gun','vitrin_bitis','plan_indirimi_yok')) = 5 as tamam
union all select 'plan indirim kolonu', exists (select 1 from information_schema.columns where table_name = 'plan_catalog' and column_name = 'odul_indirim_yuzde')
union all select 'indirim 0/5/10', (select array_agg(odul_indirim_yuzde order by sort_order) from plan_catalog where plan in ('yolcu','sik_ucan','kahya')) = array[0,5,10]
union all select 'fiyat hesabi 3000 -> 2700', public.odul_fiyati_ic(3000, false, 'kahya') = 2700
union all select 'indirimsiz odul', public.odul_fiyati_ic(2000, true, 'kahya') = 2000
union all select 'yolcu indirimsiz', public.odul_fiyati_ic(3000, false, 'yolcu') = 3000
union all select 'redeem_reward yeni imza', exists (select 1 from pg_proc where proname = 'redeem_reward' and pronargs = 2)
union all select 'eski redeem_reward yok', not exists (select 1 from pg_proc where proname = 'redeem_reward' and pronargs = 1)
union all select 'magaza rpc', exists (select 1 from pg_proc where proname = 'odul_magazasi')
union all select 'plan kartlari indirim satiri', (public.subscription_plans('tr') -> 2 -> 'haklar')::text like '%indirim%'
union all select 'plan sayaci 30 gun', (select bool_or(prosrc like '%338 · 30 gün%') from pg_proc where proname = 'my_plan');
-- Beklenen: on bir satır tamam = true.
