-- ============================================================
-- 208 · DÖNEM DEVRİ · KREDİ TALEBİ · KALİBRASYON VERİSİ
-- 17 Ağustos 2026
--
-- Üç iş:
--   (1) Cüzdanda DÖNEM DEVRİ hatası — yeni yıl geldiğinde hak
--       sıfırlanmıyordu.
--   (2) Uygulamanın `notifications` tablosuna DOĞRUDAN yazdığı tek
--       yer — yetkisi yok, sessizce düşüyor.
--   (3) Kredi oranını (3) TAHMİNLE değil ÖLÇÜMLE ayarlayabilmek için
--       BO'ya veri.
-- ============================================================


-- ============================================================
-- 1) DÖNEM DEVRİ — "yeni yıl, yeni hak"
-- ============================================================
-- 🔴 Gokberk sordu: "136 gün sonra yanıyor diyorsun da yarın 135'e
-- düşecek mi? Yılbaşında sayaç 364'e dönecek mi?"
--
-- ÖLÇTÜM — geri sayım DOĞRU:
--   bugun=2026-08-17 · yanma=2026-12-31 · kalan_bugun=136
--   kalan_yarin=135 · 2027-01-01'de kalan=364
-- Çünkü `yanma` her çağrıda `date_trunc('year', current_date)`ten
-- yeniden hesaplanıyor; saklanan bir sayı değil.
--
-- 🔴 AMA SORUSU DAHA BÜYÜK BİR KUSURU AÇTI. Gün sayacı doğru, ama
-- HAK SAYACI devretmiyordu:
--     kalan = quota_total - quota_used
-- `quota_used` yıl bitince sıfırlanmıyor. Yani 4 hakkını kullanmış
-- bir host, 1 Ocak'ta yeni yılın 4 hakkı elindeyken ekranda hâlâ
-- "0 hakkın kaldı" görecekti. Ürün, kullanıcının hakkını YOK sayardı.
--
-- Doğru mantık zaten `entitlement_remaining()` içinde vardı ve
-- `host_wallet`e taşımayı unutmuşum: dönem başlangıcı geçmişse sayaç
-- MANTIKEN sıfırlanmış sayılır (tabloya yazmıyoruz, okurken
-- düzeltiyoruz — yazma, bir cron gerektirirdi ve cron yok).
create or replace function public.host_wallet(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_kart jsonb;
  v_top_kalan int;
  v_top_deger numeric;
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
             'kullanilan', q.kullanilan,
             'kalan', q.kalan,
             'donem', he.quota_period,
             'donem_devretti', q.devretti,
             'yanma_tarihi', q.yanma,
             'kalan_gun', case when q.yanma is null then null
                               else greatest(0, (q.yanma - current_date)) end,
             'misafir_ucreti', pl.guest_visit_fee,
             'para_birimi', coalesce(pl.currency, p.guest_fee_currency, 'EUR'),
             'deger', q.deger,
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
        select *,
          -- Bilinmeyen SIFIR DEĞİLDİR (206'nın dersi korunuyor).
          case when he.quota_period = 'unlimited' or he.quota_total is null then null
               else greatest(he.quota_total - k.kullanilan, 0) end as kalan,
          case when he.quota_period = 'unlimited' or he.quota_total is null then null
               else greatest(he.quota_total - k.kullanilan, 0)
                    * coalesce(pl.guest_visit_fee, p.typical_guest_fee, 0) end as deger
        from (
          select
            -- 🔴 DÖNEM DEVRİ: kaydın dönem başlangıcı GEÇMİŞ bir döneme
            -- aitse sayaç sıfırdan başlar.
            (coalesce(he.quota_period_start,
                      case when he.quota_period = 'month' then date_trunc('month', current_date)::date
                           else date_trunc('year', current_date)::date end)
             < case when he.quota_period = 'month' then date_trunc('month', current_date)::date
                    else date_trunc('year', current_date)::date end) as devretti
        ) d
        cross join lateral (
          select case when d.devretti then 0 else coalesce(he.quota_used, 0) end as kullanilan
        ) k
        cross join lateral (
          select case when he.quota_period = 'month'
                        then (date_trunc('month', current_date) + interval '1 month - 1 day')::date
                      when he.quota_period = 'year'
                        then (date_trunc('year', current_date) + interval '1 year - 1 day')::date
                      else null end as yanma
        ) y
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
    'toplam_kalan', v_top_kalan,
    'toplam_deger', round(coalesce(v_top_deger,0)),
    'para_birimi', coalesce(v_para,'EUR'),
    'ilk_yanma', v_son,
    'kalan_gun', case when v_son is null then null else greatest(0, v_son - current_date) end,
    'baslik', case
      when v_top_kalan is null then 'Kaç misafir hakkın olduğunu henüz bilmiyoruz.'
      when v_top_kalan <= 0 then 'Bu dönemki misafir hakkını kullandın.'
      when v_son is null then format('%s misafir hakkın kullanılmadan duruyor.', v_top_kalan)
      else format('%s misafir hakkın %s gün sonra yanıyor.',
                  v_top_kalan, greatest(0, v_son - current_date)) end,
    'alt', case
      when v_top_kalan is null then
        'Kartının yıllık misafir hakkını gir; ne kadarının yanmak üzere olduğunu hesaplayalım.'
      when v_top_kalan > 0 and coalesce(v_top_deger,0) > 0 then
        format('Yaklaşık %s %s değerinde. Bankaya yatmıyor, devretmiyor — kullanılmazsa siliniyor.',
               round(v_top_deger), coalesce(v_para,'EUR'))
      when v_top_kalan > 0 then
        'Bankaya yatmıyor, devretmiyor — kullanılmazsa siliniyor.' end,
    'not', 'Bu sayılar senin beyanına dayanır; kartını veren kurumdan teyit et.');
end $fn$;


-- ============================================================
-- 2) KREDİ TALEBİ — uygulamanın tek YETKİSİZ yazması
-- ============================================================
-- 🔴 `screens.js:6464` doğrudan `notifications` tablosuna insert
-- ediyordu. `authenticated`ın o tabloda INSERT hakkı YOK (ölçüldü:
-- `has_table_privilege(...,'notifications','INSERT') → false`).
-- Yani "Kredi talep et" düğmesi hiç çalışmıyordu.
--
-- Zaten çalışmamalıydı: kullanıcının kendi kendine bildirim yazması,
-- istediği metni istediği kişiye yazabilmesi demekti (RLS satırı
-- kısıtlar ama `user_id`yi kendisi veriyordu). Doğru yol bir RPC:
-- talebi YÖNETİCİNİN GÖRECEĞİ bir yere düşürür ve hız sınırı uygular.
create table if not exists credit_requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  note        text,
  status      text not null default 'pending' check (status in ('pending','granted','rejected')),
  handled_by  uuid,
  handled_at  timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists idx_credit_requests_status on credit_requests (status, created_at desc);
alter table credit_requests enable row level security;
drop policy if exists credit_req_own on credit_requests;
create policy credit_req_own on credit_requests for select to authenticated
  using (user_id = auth.uid());

create or replace function public.request_credit_topup(p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_uid uuid := auth.uid(); v_son timestamptz; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select max(created_at) into v_son from credit_requests
   where user_id = v_uid and status = 'pending';
  if v_son is not null and v_son > now() - interval '24 hours' then
    return jsonb_build_object('ok', false, 'neden', 'zaten_bekliyor',
      'mesaj', 'Bekleyen bir kredi talebin zaten var. Sonuçlanınca haber vereceğiz.');
  end if;

  insert into credit_requests (user_id, note) values (v_uid, left(coalesce(p_note,''), 280))
  returning id into v_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_uid, 'system', 'Kredi talebin alındı',
          'Beta döneminde talepler elle değerlendiriliyor. Sonuçlanınca burada göreceksin.',
          'credit_request', v_id);

  return jsonb_build_object('ok', true, 'id', v_id,
    'mesaj', 'Talebin alındı. Beta döneminde elle değerlendiriliyor.');
end $fn$;

insert into rpc_client_surface (fn_name, client, note)
values ('request_credit_topup','app','Kredi talebi — dogrudan notifications insert''in yerine')
on conflict (fn_name) do nothing;


-- ============================================================
-- 3) KALİBRASYON — kredi oranı TAHMİNLE değil ÖLÇÜMLE ayarlansın
-- ============================================================
-- 206'da "ağırlama = 3 kredi" dedim ve gerekçesi şuydu: bir istek 1
-- kredi harcar, her istek oturuma dönüşmez, ~1/3 dönüşümle 3 kredi ≈
-- bir tamamlanmış misafir deneyimi.
--
-- ⚠️ O "1/3" BİR TAHMİNDİ. Gerçek dönüşümü ölçmeden oranı sabitlemek,
-- bu ürünün en sık hatasının (ölçmeden karar) ekonomiye taşınmış hâli
-- olurdu. Bu fonksiyon gerçek sayıyı verir; BO onu gösterir ve oran
-- deploy'suz değişir.
create or replace function public.host_credit_stats(p_gun int default 90)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_istek int; v_kabul int; v_oturum int;
  v_basilan int; v_harcanan int; v_oran numeric; v_onerilen int;
  v_mevcut int := coalesce((select (value #>> '{}')::int from beta_settings
                             where key='host_credit_per_session'), 3);
begin
  select count(*) into v_istek from requests where created_at >= now() - make_interval(days => p_gun);
  select count(*) into v_kabul from requests
   where created_at >= now() - make_interval(days => p_gun) and status in ('accepted','completed');
  select count(*) into v_oturum from sessions s
   where s.status = 'completed' and s.completed_at >= now() - make_interval(days => p_gun);

  select coalesce(sum(delta),0) into v_basilan from credit_ledger
   where reason = 'hosted_session' and created_at >= now() - make_interval(days => p_gun);
  select coalesce(-sum(delta),0) into v_harcanan from credit_ledger
   where reason = 'request_hold' and created_at >= now() - make_interval(days => p_gun);

  -- Dönüşüm: kaç istek bir tamamlanmış oturuma dönüştü?
  v_oran := case when v_istek > 0 then v_oturum::numeric / v_istek else null end;

  -- Önerilen oran = 1 / dönüşüm (yani "bir deneyim için kaç istek gerekir").
  -- Veri yoksa ÖNERİ YOK — uydurulmuş bir sayı, mevcut tahminden kötüdür.
  v_onerilen := case when v_oran is null or v_oran = 0 then null
                     else greatest(1, least(10, round(1 / v_oran)::int)) end;

  return jsonb_build_object(
    'gun', p_gun,
    'istek', v_istek, 'kabul', v_kabul, 'oturum', v_oturum,
    'donusum', v_oran,
    'basilan_kredi', v_basilan, 'harcanan_kredi', v_harcanan,
    'net', v_basilan - v_harcanan,
    'mevcut_oran', v_mevcut,
    'onerilen_oran', v_onerilen,
    'yeterli_veri', v_istek >= 30,
    'yorum', case
      when v_istek < 30 then format('Henüz %s istek var; oran değiştirmek için en az 30 gerekir.', v_istek)
      when v_onerilen is null then 'Hiç tamamlanmış oturum yok; dönüşüm hesaplanamıyor.'
      when v_onerilen = v_mevcut then format('Ölçülen dönüşüm mevcut oranı (%s) doğruluyor.', v_mevcut)
      else format('Ölçülen dönüşüm %s%%. Bir deneyim ≈ %s istek; oranı %s → %s yapmayı düşün.',
                  round(v_oran * 100), v_onerilen, v_mevcut, v_onerilen) end);
end $fn$;


-- ============================================================
-- 4) SINIR
-- ============================================================
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '208: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) GERİ SAYIM GERÇEKTEN AZALIYOR MU (Gokberk'in sorusu)
do $$
declare v_bugun int; v_yarin int; v_yilbasi int;
begin
  select ((date_trunc('year', current_date) + interval '1 year - 1 day')::date - current_date)
    into v_bugun;
  select ((date_trunc('year', current_date + 1) + interval '1 year - 1 day')::date - (current_date + 1))
    into v_yarin;
  select ((date_trunc('year', date '2027-01-01') + interval '1 year - 1 day')::date - date '2027-01-01')
    into v_yilbasi;

  if v_yarin <> v_bugun - 1 and v_yarin <= v_bugun then
    raise exception '208: geri sayim yarin AZALMIYOR (% → %)', v_bugun, v_yarin;
  end if;
  if v_yilbasi < 360 then
    raise exception '208: yilbasinda sayac sifirlanmiyor (%)', v_yilbasi;
  end if;
  raise notice '208: geri sayim bugun % · yarin % · yilbasi % (dogru)', v_bugun, v_yarin, v_yilbasi;
end $$;

-- 2) DÖNEM DEVRİ — geçmiş dönemin kullanımı YENİ dönemi yemesin
-- 🔴 Bu, 1. nöbetçinin ortaya çıkardığı ASIL kusurun nöbetçisi.
do $$
declare v_e uuid; v_u uuid; v jsonb; k jsonb;
        v_t int; v_k int; v_p text; v_ps date;
begin
  select id, user_id, quota_total, quota_used, quota_period, quota_period_start
    into v_e, v_u, v_t, v_k, v_p, v_ps from host_entitlements limit 1;
  if v_e is null then raise notice '208: hak yok — atlandi'; return; end if;

  -- GEÇEN YILIN dönemi, hakkın tamamı kullanılmış
  update host_entitlements
     set quota_total = 4, quota_used = 4, quota_period = 'year',
         quota_period_start = (date_trunc('year', current_date) - interval '1 year')::date
   where id = v_e;

  v := public.host_wallet(v_u);
  select k1 into k from jsonb_array_elements(v -> 'kartlar') k1
   where (k1 ->> 'entitlement_id')::uuid = v_e;

  if (k ->> 'kalan')::int <> 4 then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p,
           quota_period_start=v_ps where id=v_e;
    raise exception '208: donem DEVRETTI ama kalan hak % (4 olmali) — kullanici hakkini kaybediyor', k ->> 'kalan';
  end if;
  if coalesce((k ->> 'donem_devretti')::boolean, false) <> true then
    update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p,
           quota_period_start=v_ps where id=v_e;
    raise exception '208: devir bayragi yazilmadi → %', k;
  end if;

  -- BU dönemin kaydı: kullanım SAYILMALI
  update host_entitlements
     set quota_period_start = date_trunc('year', current_date)::date where id = v_e;
  v := public.host_wallet(v_u);
  select k1 into k from jsonb_array_elements(v -> 'kartlar') k1
   where (k1 ->> 'entitlement_id')::uuid = v_e;

  update host_entitlements set quota_total=v_t, quota_used=v_k, quota_period=v_p,
         quota_period_start=v_ps where id=v_e;

  if (k ->> 'kalan')::int <> 0 then
    raise exception '208: AYNI donemde kullanim sayilmadi (kalan %)', k ->> 'kalan';
  end if;
  raise notice '208: donem devri dogru — gecen yilin kullanimi yeni yili YEMIYOR';
end $$;

-- 3) KREDİ TALEBİ ÇALIŞIYOR VE TEKRARLANMIYOR
do $$
declare v_u uuid; v1 jsonb; v2 jsonb;
begin
  select id into v_u from auth.users limit 1;
  if v_u is null then raise notice '208: kullanici yok — atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u, 'role','authenticated')::text, true);

  delete from credit_requests where user_id = v_u;
  v1 := public.request_credit_topup('test');
  v2 := public.request_credit_topup('test');
  delete from credit_requests where user_id = v_u;
  perform set_config('request.jwt.claims','',true);

  if coalesce(v1 ->> 'ok','') <> 'true' then
    raise exception '208: kredi talebi olusturulamadi → %', v1;
  end if;
  if coalesce(v2 ->> 'ok','') = 'true' then
    raise exception '208: ayni kullanici 24 saatte IKI talep acabildi';
  end if;
  raise notice '208: kredi talebi calisiyor, tekrari engelleniyor';
end $$;

-- 4) KALİBRASYON VERİ YOKKEN SAYI UYDURMUYOR
-- 🔴 En kolay hata: az veriyle "oranı 7 yap" demek. Yeterli veri
-- yoksa öneri NULL kalmalı — uydurulmuş bir sayı, dürüst bir
-- tahminden kötüdür.
do $$
declare v jsonb;
begin
  v := public.host_credit_stats(90);
  if v is null or (v ->> 'yorum') is null then
    raise exception '208: kalibrasyon yorumsuz dondu';
  end if;
  if coalesce((v ->> 'yeterli_veri')::boolean, false) = false
     and (v ->> 'onerilen_oran') is not null
     and (v ->> 'yorum') not like '%en az 30%' then
    raise exception '208: veri YETERSIZKEN oran onerisi yapiliyor → %', v;
  end if;
  raise notice '208: kalibrasyon → %', v ->> 'yorum';
end $$;

select '208 OK - donem devri duzeldi, kredi talebi RPC oldu, kalibrasyon olculebilir' as sonuc;
