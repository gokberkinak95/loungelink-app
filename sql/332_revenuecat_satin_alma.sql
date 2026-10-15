-- ============================================================================
-- 332 · REVENUECAT İLE SATIN ALMA (15 Ekim 2026 · Gökberk: "revenuecat entegrasyonu yapacağız")
--
-- AKIŞ
--   Uygulama → App Store / Google Play (RevenueCat SDK) → ödeme
--   RevenueCat → webhook → Backoffice /api/revenuecat (gizli anahtar doğrulanır)
--             → public.rc_olay_isle(olay)  ← YALNIZ service_role
--
-- 🔒 İSTEMCİ HİÇBİR ŞEYİ KENDİSİ YAZAMAZ (256 · change_plan dersi): kredi ve plan
-- yalnız mağazanın onayladığı ve RevenueCat'in imzalı bildirdiği olayla değişir.
--
-- ÜRÜN KİMLİKLERİ (App Store Connect + Google Play Console'da AYNEN bu adlarla açılır)
--   Tek seferlik (consumable / "yönetilen ürün"):
--     ll_kredi_1  → kredi_paketleri.tek    (1 kredi)
--     ll_kredi_3  → kredi_paketleri.uclu   (3 kredi)
--     ll_kredi_6  → kredi_paketleri.altili (6 kredi)
--   Abonelik (otomatik yenilenen):
--     Apple : ll_sik_ucan_aylik · ll_sik_ucan_yillik · ll_kahya_aylik · ll_kahya_yillik
--     Google: abonelik ll_sik_ucan (temel planlar: aylik, yillik) · ll_kahya (aylik, yillik)
--             RevenueCat Google kimliğini "ll_sik_ucan:aylik" diye bildirir →
--             ':' → '_' çevrilince Apple kimliğiyle AYNI kod olur. Tek eşleme tablosu.
--
-- OLAYLAR (RevenueCat webhook `event.type`)
--   NON_RENEWING_PURCHASE (kredi)           → kredi_paketi_isle (makbuz tekil; tekrar = "zaten işlendi")
--   INITIAL_PURCHASE · RENEWAL · PRODUCT_CHANGE · UNCANCELLATION (abonelik)
--                                           → abonelikler + users.plan + o ayın plan kredisi
--   CANCELLATION (abonelik)                 → yenileme kapandı; plan DÖNEM SONUNA kadar sürer
--   CANCELLATION (kredi, mağaza iadesi)     → satış 'iade', kredi en fazla bakiye kadar geri alınır
--   EXPIRATION                              → plan 'yolcu'ya döner
--   BILLING_ISSUE · SUBSCRIPTION_PAUSED · TRANSFER · TEST · diğer → yalnız kayıt
--
-- Her olay `rc_olaylari`na olay kimliğiyle TEKİL yazılır: RevenueCat aynı olayı yeniden
-- gönderirse ikinci kez işlenmez. Tekrar koşulabilir.
-- ============================================================================

-- ── 1 · Ürün eşlemesi ──────────────────────────────────────────────────────
create table if not exists public.iap_urunleri (
  urun_kodu  text primary key,               -- normalize kimlik (':' → '_')
  tur        text not null check (tur in ('kredi', 'abonelik')),
  paket_kod  text references public.kredi_paketleri(kod),
  plan       plan_type,
  donem      text check (donem in ('aylik', 'yillik')),
  aktif      boolean not null default true,
  check ((tur = 'kredi' and paket_kod is not null and plan is null)
      or (tur = 'abonelik' and plan is not null and paket_kod is null))
);
alter table public.iap_urunleri enable row level security;
drop policy if exists iap_urunleri_oku on public.iap_urunleri;
create policy iap_urunleri_oku on public.iap_urunleri for select to authenticated using (true);
revoke insert, update, delete on public.iap_urunleri from anon, authenticated;
grant select on public.iap_urunleri to authenticated;

insert into public.iap_urunleri (urun_kodu, tur, paket_kod, plan, donem) values
  ('ll_kredi_1',         'kredi',    'tek',    null,       null),
  ('ll_kredi_3',         'kredi',    'uclu',   null,       null),
  ('ll_kredi_6',         'kredi',    'altili', null,       null),
  ('ll_sik_ucan_aylik',  'abonelik', null,     'sik_ucan', 'aylik'),
  ('ll_sik_ucan_yillik', 'abonelik', null,     'sik_ucan', 'yillik'),
  ('ll_kahya_aylik',     'abonelik', null,     'kahya',    'aylik'),
  ('ll_kahya_yillik',    'abonelik', null,     'kahya',    'yillik')
on conflict (urun_kodu) do update
  set tur = excluded.tur, paket_kod = excluded.paket_kod, plan = excluded.plan, donem = excluded.donem;

-- ── 2 · Abonelik durumu (kullanıcı başına tek satır) ───────────────────────
create table if not exists public.abonelikler (
  user_id       uuid primary key references public.users(id) on delete cascade,
  plan          plan_type not null,
  urun_kodu     text not null,
  magaza        text not null check (magaza in ('apple', 'google', 'diger')),
  durum         text not null check (durum in ('aktif', 'yenileme_kapali', 'odeme_sorunu', 'bitti')),
  bitis         timestamptz,
  son_olay      text,
  guncellendi   timestamptz not null default now()
);
alter table public.abonelikler enable row level security;
drop policy if exists abonelik_kendi on public.abonelikler;
create policy abonelik_kendi on public.abonelikler for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.abonelikler from anon, authenticated;
grant select on public.abonelikler to authenticated;

-- ── 3 · Olay defteri (tekil) ───────────────────────────────────────────────
create table if not exists public.rc_olaylari (
  olay_kimlik  text primary key,
  tur          text not null,
  user_id      uuid,
  urun_kodu    text,
  magaza       text,
  islem_kimlik text,
  sonuc        text,
  ham          jsonb not null,
  created_at   timestamptz not null default now()
);
create index if not exists ix_rc_olaylari_user on public.rc_olaylari (user_id, created_at desc);
alter table public.rc_olaylari enable row level security;          -- politika yok: yalnız fonksiyon + servis rolü
revoke all on public.rc_olaylari from public, anon, authenticated;

-- ── 4 · Tek kapı ───────────────────────────────────────────────────────────
create or replace function public.rc_olay_isle(p_olay jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $rc332$
declare
  e        jsonb := coalesce(p_olay -> 'event', p_olay);
  v_id     text  := e ->> 'id';
  v_tur    text  := upper(coalesce(e ->> 'type', ''));
  v_magaza text  := case upper(coalesce(e ->> 'store', ''))
                      when 'APP_STORE' then 'apple' when 'MAC_APP_STORE' then 'apple'
                      when 'PLAY_STORE' then 'google' else 'diger' end;
  v_urun   text;
  v_islem  text  := coalesce(e ->> 'transaction_id', e ->> 'original_transaction_id');
  v_uid    uuid;
  v_aday   text;
  v_u      iap_urunleri%rowtype;
  v_bitis  timestamptz;
  v_sonuc  text;
  v_r      jsonb;
  v_bal    int;
  v_satis  kredi_satislari%rowtype;
  v_geri   int;
begin
  -- 🔴 İSTEMCİ BURAYA GELEMEZ: auth.uid() doluysa çağıran bir kullanıcıdır.
  if auth.uid() is not null then raise exception 'not_admin'; end if;
  if coalesce(v_id, '') = '' then raise exception 'olay_kimligi_bos'; end if;

  -- Aynı olay ikinci kez gelirse: hata değil, "zaten işlendi" (RevenueCat yeniden dener).
  if exists (select 1 from rc_olaylari where olay_kimlik = v_id) then
    return jsonb_build_object('ok', true, 'zaten_islendi', true);
  end if;

  -- Ürün: PRODUCT_CHANGE'de yeni ürün `new_product_id`. Google "urun:temelplan" → "urun_temelplan".
  v_urun := replace(coalesce(nullif(e ->> 'new_product_id', ''), e ->> 'product_id', ''), ':', '_');
  select * into v_u from iap_urunleri where urun_kodu = v_urun;

  -- Kullanıcı: uygulama RevenueCat'e Supabase kimliğiyle giriş yapar (Purchases.logIn(uid)).
  -- Anonim kimlikle gelen olayda takma adlar (aliases) taranır.
  for v_aday in
    select x from (
      select e ->> 'app_user_id' as x
      union all select e ->> 'original_app_user_id'
      union all select jsonb_array_elements_text(coalesce(e -> 'aliases', '[]'::jsonb))
    ) a where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  loop
    select id into v_uid from users where id = v_aday::uuid;
    exit when v_uid is not null;
  end loop;

  if e ? 'expiration_at_ms' and nullif(e ->> 'expiration_at_ms', '') is not null then
    v_bitis := to_timestamp((e ->> 'expiration_at_ms')::numeric / 1000.0);
  end if;

  if v_tur = 'TEST' then
    v_sonuc := 'test';
  elsif v_uid is null then
    v_sonuc := 'kullanici_yok';
  elsif v_u.urun_kodu is null then
    v_sonuc := 'urun_tanimsiz';

  -- ── KREDİ ──────────────────────────────────────────────────────────────
  elsif v_u.tur = 'kredi' and v_tur in ('NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE') then
    if v_magaza = 'diger' then
      v_sonuc := 'magaza_tanimsiz';
    else
      v_r := public.kredi_paketi_isle(v_uid, v_magaza, coalesce(v_islem, v_id), v_u.paket_kod, e);
      v_sonuc := case when coalesce((v_r ->> 'zaten_islendi')::boolean, false) then 'kredi_zaten_islendi'
                      else 'kredi_yuklendi' end;
    end if;

  elsif v_u.tur = 'kredi' and v_tur = 'CANCELLATION' then
    -- Mağaza iadesi: satış 'iade'; verilen kredi en fazla mevcut bakiye kadar geri alınır
    -- (bakiye negatife düşemez — 299/B1 kilidi).
    select * into v_satis from kredi_satislari
     where saglayici = v_magaza and makbuz_kimlik = coalesce(v_islem, v_id) and durum = 'dogrulandi';
    if v_satis.id is null then
      v_sonuc := 'iade_satis_bulunamadi';
    else
      update kredi_satislari set durum = 'iade' where id = v_satis.id;
      select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;
      v_geri := least(v_satis.kredi, greatest(v_bal, 0));
      if v_geri > 0 then
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (v_uid, -v_geri, 'kredi_magaza_iadesi', v_satis.id, v_bal - v_geri,
                format('Mağaza iadesi · %s kredi geri alındı', v_geri));
      end if;
      v_sonuc := 'kredi_iade_' || v_geri;
    end if;

  -- ── ABONELİK ───────────────────────────────────────────────────────────
  elsif v_u.tur = 'abonelik' and v_tur in ('INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION') then
    insert into abonelikler (user_id, plan, urun_kodu, magaza, durum, bitis, son_olay, guncellendi)
    values (v_uid, v_u.plan, v_u.urun_kodu, v_magaza, 'aktif', v_bitis, v_tur, now())
    on conflict (user_id) do update
      set plan = excluded.plan, urun_kodu = excluded.urun_kodu, magaza = excluded.magaza,
          durum = 'aktif', bitis = excluded.bitis, son_olay = excluded.son_olay, guncellendi = now();
    update users set plan = v_u.plan where id = v_uid;
    -- Bu ayın plan kredisi hemen (aylık yerleştirme zaten verilmişse farkı verir).
    perform public.plan_kredisi_yerlestir(v_uid);
    v_sonuc := 'plan_' || v_u.plan::text;

  elsif v_u.tur = 'abonelik' and v_tur = 'CANCELLATION' then
    update abonelikler set durum = 'yenileme_kapali', bitis = coalesce(v_bitis, bitis),
                           son_olay = v_tur, guncellendi = now()
     where user_id = v_uid;
    v_sonuc := 'yenileme_kapali';

  elsif v_u.tur = 'abonelik' and v_tur = 'BILLING_ISSUE' then
    update abonelikler set durum = 'odeme_sorunu', son_olay = v_tur, guncellendi = now() where user_id = v_uid;
    v_sonuc := 'odeme_sorunu';

  elsif v_u.tur = 'abonelik' and v_tur = 'EXPIRATION' then
    -- Yalnız SÜRESİ BİTEN ürün hâlâ kayıtlı abonelikse düşür (yükseltme sonrası eski ürünün
    -- bitişi yeni planı düşürmesin).
    if exists (select 1 from abonelikler where user_id = v_uid and urun_kodu = v_u.urun_kodu) then
      update abonelikler set durum = 'bitti', son_olay = v_tur, guncellendi = now() where user_id = v_uid;
      update users set plan = 'yolcu' where id = v_uid;
      v_sonuc := 'plan_bitti';
    else
      v_sonuc := 'eski_urun_bitti';
    end if;

  else
    v_sonuc := 'kayit';
  end if;

  insert into rc_olaylari (olay_kimlik, tur, user_id, urun_kodu, magaza, islem_kimlik, sonuc, ham)
  values (v_id, v_tur, v_uid, nullif(v_urun, ''), v_magaza, v_islem, v_sonuc, p_olay);

  return jsonb_build_object('ok', true, 'sonuc', v_sonuc);
end $rc332$;

revoke all on function public.rc_olay_isle(jsonb) from public, anon, authenticated;
grant execute on function public.rc_olay_isle(jsonb) to service_role;

-- ── 5 · Uygulama: aboneliğim (salt okunur) ─────────────────────────────────
create or replace function public.aboneligim()
returns jsonb
language sql stable security definer set search_path = public as $ab332$
  select coalesce((
    select jsonb_build_object('plan', a.plan, 'urun', a.urun_kodu, 'magaza', a.magaza,
                              'durum', a.durum, 'bitis', a.bitis)
      from abonelikler a where a.user_id = auth.uid()), '{}'::jsonb);
$ab332$;
revoke all on function public.aboneligim() from public, anon;
grant execute on function public.aboneligim() to authenticated;

-- ── 6 · BO: son satın alma olayları ────────────────────────────────────────
create or replace function public.bo_rc_olaylari(p_gun int default 30)
returns table(olay_kimlik text, tur text, user_id uuid, ad text, urun_kodu text, magaza text, sonuc text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $bo332$
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
    select o.olay_kimlik, o.tur, o.user_id, p.name, o.urun_kodu, o.magaza, o.sonuc, o.created_at
      from rc_olaylari o left join profiles p on p.user_id = o.user_id
     where o.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_gun, 30), 365)))
     order by o.created_at desc limit 500;
end $bo332$;
revoke all on function public.bo_rc_olaylari(int) from public, anon;
grant execute on function public.bo_rc_olaylari(int) to authenticated, service_role;

-- ── 7 · AYLIK PLAN KREDİSİ HİÇ VERİLMİYORDU (ölçüldü, 332 testinde) ────────
-- `plan_kredisi_yerlestir` içinde `v_plan` plan_type, karşılaştırma `p.plan::text = v_plan`
-- → 42883 "operator does not exist: text = plan_type". Fonksiyon hatayı `exception when
-- others` ile yutup {"ok":false} dönüyordu: Sık Uçan / Kâhya'nın aylık kredisi kimseye
-- yüklenmiyordu. 253 §9 aynı deseni yalnız `v_etkin` adıyla (my_plan) düzeltmişti.
do $pk332$
declare r record;
begin
  for r in
    select p.oid, pg_get_functiondef(p.oid) as tanim
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'plan_kredisi_yerlestir'
       and (pg_get_functiondef(p.oid) like '%p.plan::text = v_plan%'
            or pg_get_functiondef(p.oid) like '%values (v_uid, ''system'', ''Aylık kredin yüklendi%')
  loop
    -- Bildirim kategorisi 'system' → 'credits': dokununca Cüzdan açılsın (bildirim_hedefi
    -- 'system' için hedef döndürmüyor; kredi artık gerçekten verildiği için görünür oldu).
    execute replace(replace(r.tanim, 'p.plan::text = v_plan', 'p.plan = v_plan'),
                    'values (v_uid, ''system'', ''Aylık kredin yüklendi', 'values (v_uid, ''credits'', ''Aylık kredin yüklendi');
    raise notice '332 §7: plan_kredisi_yerlestir duzeltildi (tip + bildirim kategorisi).';
  end loop;
end $pk332$;

-- ── DOĞRULAMA ──────────────────────────────────────────────────────────────
select 'revenuecat tek kapisi' as kontrol,
       exists (select 1 from pg_proc where proname = 'rc_olay_isle')
   and not has_function_privilege('authenticated', 'public.rc_olay_isle(jsonb)', 'execute')
   and (select count(*) from iap_urunleri) >= 7 as tamam
union all
select 'aylik plan kredisi calisir',
       position('p.plan::text = v_plan' in pg_get_functiondef('public.plan_kredisi_yerlestir(uuid)'::regprocedure)) = 0
   and position('''credits'', ''Aylık kredin' in pg_get_functiondef('public.plan_kredisi_yerlestir(uuid)'::regprocedure)) > 0;
-- Beklenen: iki satır tamam = true.
