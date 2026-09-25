-- ============================================================
-- LoungeLink · 095_close_the_loop.sql
-- APP'E YANSIMAYAN ÜÇ KATMANI BAĞLAMAK
--
-- ⚠️ Uygulamayı ETKİLER (v1.95 ile).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN: Gokberk sordu — "086'dan sonra 'app'i etkilemez' dediğin
-- şeyler artık yansıyor mu?" Ölçtüm, cevabın bir kısmı HAYIR.
--
-- YANSIYOR:  086 kural modeli (090'ın üç RPC'siyle) · 087'nin kota ve
--            güven derecesi (karar fonksiyonunun içinden) · 089 ·
--            092 host beyanı · 093 öne çıkan ödül
--
-- YANSIMIYOR (bu dosya bunları açar):
--   1. SAHA RAPORU DÖNGÜSÜ — `lounge_field_reports` tablosu ve
--      `pending_field_report()` var ama uygulamada TEK BİR ÇAĞRI YOK.
--      Yani kural verisini kendi kullanımıyla büyüten mekanizma hiç
--      çalışmıyordu. Tabloyu yazıp soruyu sormamak, kutuyu kurup fişini
--      takmamaktır.
--   2. KART ÜRÜNÜ — host "kredi kartı avantajı" diyor ama HANGİ KART
--      olduğu hiç sorulmuyor. `host_entitlements.card_product_id` bugüne
--      kadar hep NULL. Sonuç: 087/088'de modellediğimiz kota, karekod
--      şartı, "yalnız asıl kart" kuralı HİÇBİR ZAMAN devreye girmiyor.
--   3. UÇUŞ BİLGİSİ — `flight_info()` ve `src/flight.js` yazıldı ama
--      hiçbir ekran çağırmıyor (v1.95'te bağlanıyor, SQL değişikliği
--      gerekmiyor).
-- ============================================================


-- ============================================================
-- 1) SAHA RAPORU — app'in çağıracağı tek fonksiyon
--
-- Doğrudan insert yerine RPC: (a) venue/program'ı SUNUCU çözer, istemci
-- yanlış salon gönderemez (b) oturumun tarafı olmayan rapor yazamaz
-- (c) ücret bilgisi mantık kontrolünden geçer.
-- ============================================================
create or replace function public.submit_field_report(
  p_session_id uuid,
  p_outcome    text,
  p_fee_paid   numeric default null,
  p_fee_currency text  default null,
  p_note       text    default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_av    availabilities%rowtype;
  v_venue uuid;
  v_prog  uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_outcome not in ('admitted_free','admitted_paid','refused','not_attempted') then
    raise exception 'invalid_outcome';
  end if;

  -- Yalnız oturumun TARAFI rapor yazabilir
  select a.* into v_av
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
   where s.id = p_session_id
     and (r.guest_id = v_uid or r.host_id = v_uid);
  if not found then raise exception 'not_party'; end if;

  v_venue := public.resolve_venue_for_availability(v_av.id);
  v_prog  := v_av.program_id;

  -- "Ücret ödedik" diyorsa tutar anlamlı olmalı; değilse tutarı yok say.
  if p_outcome <> 'admitted_paid' then
    p_fee_paid := null; p_fee_currency := null;
  end if;

  insert into lounge_field_reports
    (reporter_id, session_id, venue_id, program_id, outcome, fee_paid, fee_currency, note)
  values (v_uid, p_session_id, v_venue, v_prog, p_outcome,
          p_fee_paid, nullif(trim(coalesce(p_fee_currency,'')),''), nullif(trim(coalesce(p_note,'')),''))
  on conflict (session_id, reporter_id) do nothing;

  return jsonb_build_object('ok', true, 'venue_id', v_venue);
end $$;
grant execute on function public.submit_field_report(uuid, text, numeric, text, text) to authenticated;


-- ============================================================
-- 2) KART ÜRÜNÜ — host'a "hangi kart?" sorulabilsin
-- ============================================================

-- Uygulamanın göstereceği liste. Doğrudan tablo okumak yerine RPC:
-- pasif/kampanyası bitmiş kartlar listede çıkmasın ve banka adı tek
-- sorguda gelsin.
create or replace function public.card_product_options()
returns table (id uuid, issuer text, name text, label text, program_code text)
language sql stable security definer set search_path = public as $$
  select cp.id, i.name, cp.name,
         i.name || ' · ' || cp.name ||
           case when cp.segment is not null then ' (' || cp.segment || ')' else '' end,
         p.code
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    left join lounge_programs p on p.id = cp.program_id
   where cp.active
     and (cp.valid_from is null or cp.valid_from <= current_date)
     and (cp.valid_to   is null or cp.valid_to   >= current_date)
   order by i.name, cp.name;
$$;
grant execute on function public.card_product_options() to authenticated;

-- 092'nin save_host_access'i kart ürününü de alsın.
-- 🔴 İMZA DEĞİŞİYOR → önce eski sürümü düşürüyoruz. (086'da bu adım ayrı
-- dosyadaydı, atlandı ve 42P13 hatası alındı — bu kez aynı dosyada.)
drop function if exists public.save_host_access(text[], smallint, boolean, smallint, text, smallint);

create or replace function public.save_host_access(
  p_sources            text[]   default null,
  p_guest_capacity     smallint default null,
  p_guest_fee_expected boolean  default null,
  p_quota_total        smallint default null,
  p_quota_period       text     default null,
  p_quota_used         smallint default null,
  p_card_product_id    uuid     default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_txt  text;
  v_prog uuid;
  v_card lounge_card_products%rowtype;
  v_ent  uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_quota_period is not null and p_quota_period not in ('year','month','unlimited') then
    raise exception 'invalid_quota_period';
  end if;
  if p_quota_total is not null and p_quota_used is not null and p_quota_used > p_quota_total then
    raise exception 'quota_used_exceeds_total';
  end if;

  v_txt := nullif(array_to_string(coalesce(p_sources, '{}'::text[]), ', '), '');

  update profiles
     set access_source      = coalesce(v_txt, access_source),
         guest_capacity     = coalesce(p_guest_capacity, guest_capacity),
         guest_fee_expected = coalesce(p_guest_fee_expected, guest_fee_expected),
         updated_at         = now()
   where user_id = v_uid;

  -- Kart seçildiyse program ONDAN gelir; serbest metin tahmini devreye
  -- girmez. Host'un seçtiği kart, bizim metinden çıkardığımız tahminden
  -- her zaman daha güvenilirdir.
  if p_card_product_id is not null then
    select * into v_card from lounge_card_products where id = p_card_product_id and active;
    if found then v_prog := v_card.program_id; end if;
  end if;
  if v_prog is null then
    v_prog := public.match_program_by_text(coalesce(v_txt,
                (select access_source from profiles where user_id = v_uid)));
  end if;

  if v_prog is not null then
    insert into host_entitlements
      (user_id, program_id, card_product_id, guest_capacity, origin, note,
       quota_total, quota_period, quota_used, self_reported_at)
    values
      (v_uid, v_prog, p_card_product_id, p_guest_capacity, 'declared', 'save_host_access',
       -- Kart seçildiyse ve host kota girmediyse, katalogdaki kotayı
       -- VARSAYILAN olarak kullan. Beyan her zaman üstündedir.
       coalesce(p_quota_total, v_card.quota_total),
       coalesce(p_quota_period, v_card.quota_period),
       coalesce(p_quota_used, 0), now())
    on conflict (user_id, program_id, coalesce(tier,''))
    do update set
      card_product_id  = coalesce(excluded.card_product_id, host_entitlements.card_product_id),
      guest_capacity   = coalesce(excluded.guest_capacity, host_entitlements.guest_capacity),
      quota_total      = coalesce(excluded.quota_total, host_entitlements.quota_total),
      quota_period     = coalesce(excluded.quota_period, host_entitlements.quota_period),
      quota_used       = coalesce(excluded.quota_used, host_entitlements.quota_used),
      self_reported_at = now(),
      origin           = 'declared'
    returning id into v_ent;
  end if;

  return jsonb_build_object(
    'ok', true, 'program_id', v_prog, 'card_product_id', p_card_product_id,
    'entitlement_id', v_ent,
    'quota', case when v_ent is null then null else public.entitlement_remaining(v_ent) end);
end $$;
grant execute on function public.save_host_access(text[], smallint, boolean, smallint, text, smallint, uuid) to authenticated;

-- my_host_access da kartı geri versin
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.my_host_access();
create or replace function public.my_host_access()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); p profiles%rowtype; e host_entitlements%rowtype; c lounge_card_products%rowtype;
begin
  select * into p from profiles where user_id = v_uid;
  select * into e from host_entitlements where user_id = v_uid
   order by self_reported_at desc nulls last, created_at desc limit 1;
  if e.card_product_id is not null then
    select * into c from lounge_card_products where id = e.card_product_id;
  end if;
  return jsonb_build_object(
    'access_source', p.access_source,
    'guest_capacity', p.guest_capacity,
    'guest_fee_expected', p.guest_fee_expected,
    'card_product_id', e.card_product_id,
    'card_name', c.name,
    'quota_total', e.quota_total,
    'quota_period', e.quota_period,
    'quota_used', e.quota_used,
    'quota', case when e.id is null then null else public.entitlement_remaining(e.id) end);
end $$;
grant execute on function public.my_host_access() to authenticated;


-- ============================================================
-- 3) DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_card_products where active) as secilebilir_kart,
       (select count(*) from host_entitlements where card_product_id is not null) as kart_secen_host,
       (select count(*) from lounge_field_reports) as saha_raporu;

select '095 OK - saha raporu ve kart urunu app''e acildi' as sonuc;
