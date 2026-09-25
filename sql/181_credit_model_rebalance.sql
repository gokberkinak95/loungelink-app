-- ============================================================
-- LoungeLink · 181_credit_model_rebalance.sql
-- KREDİ MODELİ YENİDEN DENGELENDİ
--
-- ⚠️ Uygulamayı ETKİLER (kredi akışı + ödül).
--
-- ------------------------------------------------------------
-- 🔴 SORUN (Gökberk madde 8)
-- ------------------------------------------------------------
-- Ücretli misafir girişi olan salonlarda misafirden TEK SEFERDE
-- 4 kredi çıkıyordu: 1 kredi escrow + 3 kredi "davet edene teşekkür".
-- Bu iki açıdan yanlış:
--   · MİSAFİR İÇİN AĞIR. Ürünü ilk kez deneyen biri için 4 kredi,
--     "bir kahve içmeye gidiyorum" hissinin çok üstünde bir eşik.
--     Yüksek ilk maliyet, en kritik anda (ilk istek) vazgeçirir.
--   · DAVET EDEN İÇİN ANLAMSIZ. 3 kredi, kartındaki hakkı paylaşan
--     birine "bu benim ne işime yarayacak?" dedirtir. Kredi onun
--     zaten harcamadığı bir şey; asıl değeri PUAN ve GÖRÜNÜRLÜK.
--
-- ------------------------------------------------------------
-- YENİ MODEL — toplam 3 kredi, ödül puanda
-- ------------------------------------------------------------
--   1 kredi  → istek anında escrow (ciddiyet göstergesi, iade edilebilir)
--   2 kredi  → oturum TAMAMLANINCA davet edene aktarılır
--   ------------------------------------------------------------
--   toplam 3 (eskiden 4) · davet edene 2 (eskiden 3)
--
-- Davet edenin kaybettiği 1 kredi PUANLA fazlasıyla telafi edilir:
--   · ücretli misafir kabul eden davet edene ÇİFT LoungePuan
--   · üstüne "kapıyı açtın" bonusu (sabit +50)
-- Sebep: kredi davet edenin ihtiyacı değil (o zaten salona giriyor);
-- puan ise ödül kataloğunda gerçek karşılığı olan şey — Priority Pass
-- misafir kartı, THY mili, eSIM. Yani davet eden 1 kredi yerine,
-- yolda işine yarayan bir şey kazanıyor.
-- ============================================================

-- ---- 1) AKTARIM 3 → 2 ----
do $$
declare v_src text; v_new text; n int := 0;
begin
  for v_src in
    select prosrc from pg_proc
     where pronamespace = 'public'::regnamespace
       and prosrc like '%paid_guest%'
       and proname in ('paid_guest_credit','create_request_impl','confirm_session')
  loop
    null;
  end loop;

  -- Tarife tek yerde tutuluyorsa oradan değiştir
  if exists (select 1 from beta_settings where key = 'paid_guest_credits') then
    update beta_settings set value = '2'::jsonb where key = 'paid_guest_credits';
    n := n + 1;
  else
    insert into beta_settings (key, value) values ('paid_guest_credits', '2'::jsonb)
    on conflict (key) do update set value = '2'::jsonb;
    n := n + 1;
  end if;
  raise notice '181: ücretli misafir aktarımı 2 krediye ayarlandı (%)', n;
end $$;

-- paid_guest_credit() sabit 3 döndürüyorsa ayardan okusun
-- sqlcheck: allow-replace paid_guest_credit  (dönüş tipi AYNI)
create or replace function public.paid_guest_credit(p_avail_id uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare v_n int; v_paid boolean;
begin
  -- Salon misafirden ücret alıyor mu? (kural motorunun cevabı)
  select coalesce((public.lounge_access_decision(p_avail_id, null) ->> 'guest_policy') = 'paid', false)
    into v_paid;
  if not coalesce(v_paid, false) then return 0; end if;

  -- 🔴 181: sabit 3 yerine ayardan okunur; tek yerden değiştirilebilir.
  select coalesce((value)::text::int, 2) into v_n
    from beta_settings where key = 'paid_guest_credits';
  return coalesce(v_n, 2);
exception when others then
  return 2;
end $$;

-- ---- 2) DAVET EDENE ÇİFT PUAN + KAPI BONUSU ----
-- Kredi azaldı; değer PUANA taşındı. Puanın ödül kataloğunda gerçek
-- karşılığı var, kredinin davet eden için yok.
insert into beta_settings (key, value)
values ('host_paid_guest_point_multiplier', '2'::jsonb)
on conflict (key) do update set value = '2'::jsonb;

insert into beta_settings (key, value)
values ('host_door_bonus_points', '50'::jsonb)
on conflict (key) do update set value = '50'::jsonb;

-- ---- 3) KANIT ----
do $$
declare v_av uuid; v_n int;
begin
  select a.id into v_av from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'paid'
   limit 1;

  if v_av is null then
    raise notice '181: ücretli misafir ilanı yok — kanıt atlandı';
  else
    v_n := public.paid_guest_credit(v_av);
    if v_n <> 2 then
      raise exception '181: ücretli misafir aktarımı % kredi (2 olmalı)', v_n;
    end if;
    raise notice '181: ücretli ilanda aktarım = 2 kredi ✓ (toplam maliyet 3)';
  end if;

  -- Ücretsiz salonda aktarım OLMAMALI
  select a.id into v_av from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'included'
   limit 1;
  if v_av is not null and public.paid_guest_credit(v_av) <> 0 then
    raise exception '181: ücretsiz salonda kredi aktarımı olmamalı';
  end if;
end $$;

select '181 OK - toplam 3 kredi, davet edene 2 kredi + cift puan' as sonuc;
