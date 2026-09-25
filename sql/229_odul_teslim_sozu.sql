-- ============================================================================
-- LoungeLink · 229_odul_teslim_sozu.sql                    (21 Ağustos 2026)
--
-- MAĞAZA, TUTAMAYACAĞI BİR SÖZ VERİYORDU
--
-- 🔴 KUSURUN TAM HÂLİ. Bugünkü `redeem_reward()` şunu yapıyor:
--     v_code := 'LL-' || upper(substr(md5(random()::text), 1, 6));
--     ... 'Ödül alındı 🎁' · 'Kupon: LL-A1B2C3'
--
-- Yani host 3.500 puanını harcıyor, ekranda **kullanılabilir görünen bir
-- kupon kodu** çıkıyor — ama o kodun arkasında SafetyWing yok. Kod
-- uydurma; hiçbir tedarikçiye sorulmuyor, hiçbir yere iletilmiyor,
-- kimseye görev düşmüyor. Host onu SafetyWing sitesine yazacak,
-- tutmayacak.
--
-- Bu, ürünün tek cümlesinin ("kapıda ne olacağını biliyoruz") tam
-- tersi. Puan ekonomisini siteye yeni yazdım; ilk kuponu kullanan
-- host'ta o ekonominin güveni biter.
--
-- 🆕 SINIF: **"BİR ŞEYİ ÇALIŞIYOR GİBİ GÖSTERMEK, ÇALIŞMIYOR DEMEKTEN
-- DAHA PAHALIYA MAL OLUR."** ("Kupon: LL-A1B2C3" bir söz; "48 saat
-- içinde e-postana gelecek" başka bir söz. İkincisi tutulabilir.)
--
-- ⚠️ NE YAPMIYORUM: Airalo/SafetyWing entegrasyonu. O bir ticari
-- anlaşma, SQL değil. Yaptığım şey, entegrasyon gelene kadar sistemin
-- DOĞRUYU söylemesi ve teslimin bir kuyruğa düşüp izlenmesi.
--
-- DÖRT PARÇA:
--   1) Ödül kaydı teslim şeklini ve süresini BEYAN ETMEK ZORUNDA
--   2) Kullanım (redemption) bir DURUM ve bir VADE taşır
--   3) redeem_reward() kodu "kupon" diye sunmaz; ne olacağını söyler
--   4) BO için kuyruk + geciken teslim sayacı + nöbetçi
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) ÖDÜL: teslim şekli beyan edilmek zorunda
-- ----------------------------------------------------------------------------
alter table rewards add column if not exists teslim_sekli text;      -- 'manuel' | 'otomatik'
alter table rewards add column if not exists teslim_saat  int;       -- söz verilen süre (saat)

comment on column rewards.teslim_sekli is
  'manuel = bir insan tedarikciden alip iletir · otomatik = tedarikci API kupon uretir. '
  'Bugun HEPSI manuel; otomatik olan ilk odul entegrasyon bittiginde isaretlenir.';
comment on column rewards.teslim_saat is
  'Kullaniciya VERILEN SOZ. redeem_reward bu sayiyi ekrana yazar ve due_at bundan hesaplanir.';

-- Bugünkü gerçek: hepsi manuel, 48 saat. Uydurma değil — beta'da
-- teslimi Gökberk elle yapacak ve 48 saat tutulabilir bir söz.
update rewards
   set teslim_sekli = coalesce(teslim_sekli, 'manuel'),
       teslim_saat  = coalesce(teslim_saat, 48),
       supplier     = coalesce(supplier, case
                        when title ilike 'Airalo%'    then 'Airalo'
                        when title ilike 'Booking%'   then 'Booking.com'
                        when title ilike 'SafetyWing%'then 'SafetyWing'
                        when title ilike 'Marriott%'  then 'Marriott Bonvoy'
                        when title ilike 'Emirates%'  then 'Emirates Skywards'
                        when title ilike 'Türk Hava%' then 'Miles&Smiles'
                        else null end);

-- 🔴 KISIT: aktif bir ödül teslim sözü olmadan mağazada duramaz.
-- Yorum yazmak yetmiyor (228'de öğrenildi) — kapı veritabanında.
alter table rewards drop constraint if exists rewards_teslim_sozu_chk;
alter table rewards add constraint rewards_teslim_sozu_chk
  check (
    coalesce(active, true) = false
    or (teslim_sekli in ('manuel','otomatik')
        and teslim_saat is not null and teslim_saat between 1 and 720
        and supplier is not null)
  );

-- ----------------------------------------------------------------------------
-- 2) KULLANIM: durum + vade + izlenebilirlik
-- ----------------------------------------------------------------------------
alter table redemptions add column if not exists durum        text;
alter table redemptions add column if not exists due_at       timestamptz;
alter table redemptions add column if not exists fulfilled_at timestamptz;
alter table redemptions add column if not exists tedarikci_ref text;
alter table redemptions add column if not exists iptal_notu   text;

update redemptions set durum = coalesce(durum, 'bekliyor');

alter table redemptions drop constraint if exists redemptions_durum_chk;
alter table redemptions add constraint redemptions_durum_chk
  check (durum in ('bekliyor','teslim','iptal'));

-- Teslim edilmiş bir kayıt zamanını taşımak ZORUNDA: "teslim ettim"
-- diyen ama ne zaman ettiğini söylemeyen kayıt, denetlenemez.
alter table redemptions drop constraint if exists redemptions_teslim_zamani_chk;
alter table redemptions add constraint redemptions_teslim_zamani_chk
  check (durum <> 'teslim' or fulfilled_at is not null);

create index if not exists ix_redemptions_bekleyen
  on redemptions (due_at) where durum = 'bekliyor';

-- ----------------------------------------------------------------------------
-- 3) redeem_reward — DOĞRUYU söyleyen sürüm
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace redeem_reward  (returns jsonb — 017 ve 029 ile AYNI tip;
--            029 zaten replace ediyordu, dönüş tipi değişmiyor, yalnız gövde)
create or replace function public.redeem_reward(p_reward_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $rr$
declare
  v_uid  uuid := auth.uid();
  v_r    rewards%rowtype;
  v_pts  int;
  v_ref  text;
  v_due  timestamptz;
  v_id   uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_r from rewards where id = p_reward_id for update;
  if not found or not coalesce(v_r.active,false) then raise exception 'reward_unavailable'; end if;
  if v_r.stock is not null and v_r.stock <= 0 then raise exception 'out_of_stock'; end if;

  -- 🔴 Teslim sözü olmayan ödül SATILMAZ. Kısıt zaten engelliyor ama
  -- eski bir satır kısıttan önce girmişse burada da duruyoruz:
  -- "iki kapı" bilerek — biri veriye, biri akışa.
  if v_r.teslim_sekli is null or v_r.teslim_saat is null or v_r.supplier is null then
    raise exception 'reward_fulfillment_undefined';
  end if;

  select coalesce(sum(delta),0) into v_pts from points_ledger where user_id = v_uid;
  if v_pts < v_r.cost_points then raise exception 'insufficient_points'; end if;

  -- 🔴 ARTIK "KUPON" DEĞİL, "TALEP NUMARASI".
  -- Eski kod LL-XXXXXX üretiyordu ve ekranda kupon gibi duruyordu.
  -- Bu numara bir TAKİP numarası: kullanıcı bununla bize sorar, biz
  -- bununla kuyrukta buluruz. Kimse onu tedarikçiye yazmaya kalkmaz.
  v_ref := 'TAL-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(md5(random()::text), 1, 5));
  v_due := now() + make_interval(hours => v_r.teslim_saat);

  insert into redemptions (user_id, reward_id, cost_points, voucher_code, durum, due_at)
  values (v_uid, p_reward_id, v_r.cost_points, v_ref, 'bekliyor', v_due)
  returning id into v_id;

  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -v_r.cost_points, 'reward_redeem', p_reward_id);

  if v_r.stock is not null then
    update rewards set stock = stock - 1 where id = p_reward_id;
  end if;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_uid, 'system', 'Talebin alındı ✦',
          v_r.title || ' · takip no ' || v_ref || E'\n'
       || v_r.supplier || ' tarafından hazırlanıyor. En geç '
       || to_char(v_due, 'DD.MM HH24:MI') || ' itibarıyla hesabındaki e-posta adresine gelecek. '
       || 'Gelmezse bu takip numarasıyla bize yaz — puanın iade edilir.',
          'reward', v_id);

  return jsonb_build_object(
    'ok', true,
    'takip_no', v_ref,
    'durum', 'bekliyor',
    'teslim_sekli', v_r.teslim_sekli,
    'son_tarih', v_due,
    'tedarikci', v_r.supplier,
    'bakiye', v_pts - v_r.cost_points,
    -- Eski alan adları geriye dönük bırakılıyor: app'in eski sürümü
    -- `code`/`voucher` okuyorsa ekran boş kalmasın. Ama içerik artık
    -- takip numarası ve bildirim metni ne olduğunu söylüyor.
    'code', v_ref,
    'voucher', v_ref
  );
end $rr$;
grant execute on function public.redeem_reward(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 4) TESLİM KUYRUĞU — BO'nun tek ekranı + geciken sayacı
-- ----------------------------------------------------------------------------
drop function if exists public.bekleyen_teslimler();
create or replace function public.bekleyen_teslimler()
returns table (
  id uuid, takip_no text, odul text, tedarikci text,
  kullanici uuid, eposta text, puan int,
  alindi timestamptz, son_tarih timestamptz, gecikti boolean, kalan_saat int
) language plpgsql stable security definer set search_path = public as $bt$
begin
  -- 🔴 YETKİ İKİ KATMANLI, ama KATMANLAR FARKLI ŞEYLERE BAKAR:
  --  (1) Bu fonksiyon istemci rollerine HİÇ verilmiyor (aşağıda yalnız
  --      service_role'a grant var + apply_rpc_surface() sınırı uyguluyor).
  --      BO `sbAdmin()` yani service_role ile çağırıyor.
  --  (2) Yine de biri bir gün authenticated'a grant verirse, aşağıdaki
  --      kontrol devreye girer. auth.uid() null ise service_role
  --      bağlamındayız (BO); doluysa gerçek bir kullanıcıdır ve
  --      admin_roles'ta olmak ZORUNDA.
  -- 205'in kalıbı yalnız (1)'e güveniyordu; bir grant hatası orada
  -- sessiz bir açık bırakırdı.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select d.id, d.voucher_code, r.title, r.supplier,
         d.user_id, u.email, d.cost_points,
         d.created_at, d.due_at,
         (d.due_at < now()),
         greatest(0, extract(epoch from (d.due_at - now()))/3600)::int
    from redemptions d
    join rewards r on r.id = d.reward_id
    left join users u on u.id = d.user_id
   where d.durum = 'bekliyor'
   order by d.due_at asc;
end $bt$;
grant execute on function public.bekleyen_teslimler() to service_role;   -- BO sbAdmin() ile cagirir

drop function if exists public.teslim_isaretle(uuid, text);
create or replace function public.teslim_isaretle(p_redemption uuid, p_ref text)
returns jsonb language plpgsql security definer set search_path = public as $ti$
declare v_d redemptions%rowtype; v_baslik text;
begin
  -- 🔴 YETKİ İKİ KATMANLI, ama KATMANLAR FARKLI ŞEYLERE BAKAR:
  --  (1) Bu fonksiyon istemci rollerine HİÇ verilmiyor (aşağıda yalnız
  --      service_role'a grant var + apply_rpc_surface() sınırı uyguluyor).
  --      BO `sbAdmin()` yani service_role ile çağırıyor.
  --  (2) Yine de biri bir gün authenticated'a grant verirse, aşağıdaki
  --      kontrol devreye girer. auth.uid() null ise service_role
  --      bağlamındayız (BO); doluysa gerçek bir kullanıcıdır ve
  --      admin_roles'ta olmak ZORUNDA.
  -- 205'in kalıbı yalnız (1)'e güveniyordu; bir grant hatası orada
  -- sessiz bir açık bırakırdı.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_d from redemptions where id = p_redemption for update;
  if not found then raise exception 'redemption_not_found'; end if;
  if v_d.durum <> 'bekliyor' then raise exception 'already_settled'; end if;
  if coalesce(btrim(p_ref),'') = '' then raise exception 'ref_required'; end if;

  update redemptions
     set durum = 'teslim', fulfilled_at = now(), tedarikci_ref = btrim(p_ref)
   where id = p_redemption;

  select title into v_baslik from rewards where id = v_d.reward_id;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_d.user_id, 'system', 'Ödülün gönderildi 🎁',
          v_baslik || ' · e-posta adresine gönderildi. Kod: ' || btrim(p_ref),
          'reward', v_d.id);
  return jsonb_build_object('ok', true);
end $ti$;
grant execute on function public.teslim_isaretle(uuid, text) to service_role;   -- BO sbAdmin() ile cagirir

-- İptal = puan İADE. Teslim edemediğimiz bir ödül için puanı tutmak,
-- kullanıcıdan bedelsiz almak demektir.
drop function if exists public.teslim_iptal(uuid, text);
create or replace function public.teslim_iptal(p_redemption uuid, p_neden text)
returns jsonb language plpgsql security definer set search_path = public as $tp$
declare v_d redemptions%rowtype; v_baslik text;
begin
  -- 🔴 YETKİ İKİ KATMANLI, ama KATMANLAR FARKLI ŞEYLERE BAKAR:
  --  (1) Bu fonksiyon istemci rollerine HİÇ verilmiyor (aşağıda yalnız
  --      service_role'a grant var + apply_rpc_surface() sınırı uyguluyor).
  --      BO `sbAdmin()` yani service_role ile çağırıyor.
  --  (2) Yine de biri bir gün authenticated'a grant verirse, aşağıdaki
  --      kontrol devreye girer. auth.uid() null ise service_role
  --      bağlamındayız (BO); doluysa gerçek bir kullanıcıdır ve
  --      admin_roles'ta olmak ZORUNDA.
  -- 205'in kalıbı yalnız (1)'e güveniyordu; bir grant hatası orada
  -- sessiz bir açık bırakırdı.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_d from redemptions where id = p_redemption for update;
  if not found then raise exception 'redemption_not_found'; end if;
  if v_d.durum <> 'bekliyor' then raise exception 'already_settled'; end if;

  update redemptions
     set durum = 'iptal', iptal_notu = left(coalesce(p_neden,''), 300)
   where id = p_redemption;

  insert into points_ledger (user_id, delta, reason, ref_id)
  values (v_d.user_id, v_d.cost_points, 'reward_refund', v_d.reward_id);

  update rewards set stock = stock + 1
   where id = v_d.reward_id and stock is not null;

  select title into v_baslik from rewards where id = v_d.reward_id;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_d.user_id, 'system', 'Puanın iade edildi',
          v_baslik || ' teslim edilemedi (' || left(coalesce(p_neden,'sebep belirtilmedi'),120)
       || '). ' || v_d.cost_points || ' LoungePuan hesabına geri yüklendi.',
          'reward', v_d.id);
  return jsonb_build_object('ok', true, 'iade', v_d.cost_points);
end $tp$;
grant execute on function public.teslim_iptal(uuid, text) to service_role;   -- BO sbAdmin() ile cagirir

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n229$
declare
  v_sozsuz  int;
  v_kisit   int;
  v_geciken int;
  v_aktif   int;
begin
  select count(*) into v_sozsuz from rewards
   where coalesce(active,true)
     and (teslim_sekli is null or teslim_saat is null or supplier is null);
  if v_sozsuz <> 0 then
    raise exception '229 NOBETCI: % aktif odul teslim sozu olmadan magazada duruyor.', v_sozsuz;
  end if;

  select count(*) into v_kisit from pg_constraint
   where conname in ('rewards_teslim_sozu_chk','redemptions_durum_chk','redemptions_teslim_zamani_chk');
  if v_kisit <> 3 then
    raise exception '229 NOBETCI: 3 kisit bekleniyordu, % kuruldu.', v_kisit;
  end if;

  -- Kupon kelimesi artık kodda kalmamalı: eski metin geri sızarsa
  -- kullanıcı yine kullanılabilir bir kod sanır.
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='redeem_reward'
                and p.prosrc like '%Kupon: %') then
    raise exception '229 NOBETCI: redeem_reward hala "Kupon:" diye sunuyor.';
  end if;

  select count(*) into v_aktif from rewards where coalesce(active,true);
  select count(*) into v_geciken from redemptions
   where durum='bekliyor' and due_at < now();

  raise notice '229 OK · aktif odul: % (hepsi teslim sozlu) · bekleyen gecikmis teslim: %',
    v_aktif, v_geciken;
  raise notice '229 OLCULMEDI: tedarikci entegrasyonu YOK. Bugun teslim MANUEL — '
               'bekleyen_teslimler() kuyrugunu birinin acmasi gerekiyor. '
               'Kuyruk bos kalmazsa soz tutulmuyor demektir.';
end $n229$;

-- ----------------------------------------------------------------------------
-- 6) RPC YÜZEYİ — 203'ün kuralı: fonksiyon üreten her dosya SONUNDA çağırır
-- ----------------------------------------------------------------------------
-- 🔴 Bu bölümü İLK YAZIMDA UNUTTUM ve harness yakaladı:
--     ⚠ RPC yuzeyi ihlali: teslim_isaretle -> yuzeyde yok ama istemciye acik
-- `redeem_reward` zaten yüzeydeydi (017'den beri). Yeni BO fonksiyonları
-- yüzeye GİRMEZ — onlar yalnız service_role. apply_rpc_surface() bunu
-- zorluyor; aşağıdaki çağrı olmasaydı grant'lar açık kalırdı.
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '229: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select 'ODUL TESLIM SOZU KURULDU' as sonuc,
       (select count(*) from rewards where coalesce(active,true)) as aktif_odul,
       (select count(*) from rewards where coalesce(active,true) and teslim_sekli='manuel') as manuel_teslim,
       (select count(*) from redemptions where durum='bekliyor') as bekleyen_teslim;
