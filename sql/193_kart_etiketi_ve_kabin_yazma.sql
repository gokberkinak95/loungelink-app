-- ============================================================
-- 193 · KART ETİKETİ VE KABİN YAZMA YOLLARI
-- 17 Ağustos 2026
--
-- 🔴 NEDEN VAR: 191 iki mimari boşluğu KABLOLADI ama YAZMA YOLUNU
-- açmadı. App tarafı v2.67'de arayüzü kurdu ve şu iki duvara çarptı:
--
--   1. `card_label` kolonu var, benzersizlik anahtarında da var —
--      ama `save_host_access` (100:76) imzasında YOK ve dahası aynı
--      programda FARKLI TIER'ı SİLİP tek satır upsert ediyor.
--      Yani ikinci hak satırı app'ten HİÇ yaratılamıyor.
--      Doğrudan tablo yazımı da kapalı: 159'un GRANT envanterinde
--      `host_entitlements` HİÇ GEÇMİYOR (ne select ne update).
--
--   2. `availabilities.cabin_class` kolonu var ve karar zincirine
--      bağlı — ama `create_availability` (158:249) imzasında
--      `p_cabin_class` YOK ve tablo GRANT'i yalnız `select`.
--      Sonuç: 15 kabin kuralı hâlâ devre dışı; cabin_rule_reach()
--      "hiçbir ilanda kabin girilmemiş" diyor.
--
-- 🔴 DERS (yeni sınıf): BİR KOLON EKLEMEK, ONU YAZMANIN YOLUNU
-- AÇMAK DEĞİLDİR. 191'de "kabloladık" dedim; kablo tek uçtan
-- bağlıydı. Bir alanı okuyan motor + gösteren ekran + YAZAN RPC —
-- üçü birden olmadan özellik yoktur. Bunu app ekibi arayüzü
-- yazarken keşfetti, ben değil.
--
-- 🔴 VE `save_host_access` DEĞİŞTİRİLMİYOR: imzası app'in üç
-- sürümünde çağrılıyor ve 156'nın "imza sabit kalır" kararı burada
-- da geçerli. Yeni yetenek YENİ FONKSİYONLA gelir.
-- ============================================================


-- ============================================================
-- 1 · save_host_card — aynı programdan İKİNCİ kartı ekler
-- ============================================================
-- Gökberk: "bende 2 tane Miles&Smiles kartı var, birinde kendim
-- diğerinde misafirim gelebiliyor."
--
-- `save_host_access` "kullanıcının erişim kaynaklarını TOPTAN
-- yeniden yazar" semantiğine sahip (eski tier'ı siler). Bu, tek
-- kartlı kullanıcı için doğru; çok kartlı için yıkıcı.
-- `save_host_card` TEK KARTA dokunur, diğerlerine dokunmaz.

create or replace function public.save_host_card(
  p_program_code   text,
  p_tier           text default null,
  p_card_label     text default null,
  p_guest_capacity smallint default null,
  p_bank_code      text default null,
  p_card_product   text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_prog uuid;
  v_id   uuid;
  v_n    int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select id into v_prog from lounge_programs
   where active and upper(btrim(code)) = upper(btrim(coalesce(p_program_code,'')));
  if v_prog is null then raise exception 'unknown_program'; end if;

  -- Kapasite makul olmalı; kural motoru zaten üst sınırı belirler ama
  -- saçma bir sayı veriye girmemeli.
  if p_guest_capacity is not null and (p_guest_capacity < 0 or p_guest_capacity > 6) then
    raise exception 'invalid_guest_capacity';
  end if;

  -- 🔴 Aynı kişide sınırsız kart olmamalı: beyan bir güven kaynağı,
  -- sınırsız beyan güveni değersizleştirir. Program başına 4 kart.
  select count(*) into v_n from host_entitlements
   where user_id = v_uid and program_id = v_prog
     and coalesce(card_label,'') is distinct from coalesce(nullif(btrim(p_card_label),''),'');
  if v_n >= 4 then raise exception 'too_many_cards'; end if;

  insert into host_entitlements
    (user_id, program_id, tier, card_label, guest_capacity,
     bank_code, card_product, origin, self_reported_at)
  values
    (v_uid, v_prog, nullif(btrim(coalesce(p_tier,'')),''),
     nullif(btrim(coalesce(p_card_label,'')),''),
     p_guest_capacity,
     nullif(btrim(upper(coalesce(p_bank_code,''))),''),
     nullif(btrim(coalesce(p_card_product,'')),''),
     'declared', now())
  on conflict (user_id, program_id, coalesce(tier,''), coalesce(card_label,''))
  do update set
    guest_capacity   = coalesce(excluded.guest_capacity, host_entitlements.guest_capacity),
    bank_code        = coalesce(excluded.bank_code, host_entitlements.bank_code),
    card_product     = coalesce(excluded.card_product, host_entitlements.card_product),
    origin           = 'declared',
    self_reported_at = now()
  returning id into v_id;

  select count(*) into v_n from host_entitlements
   where user_id = v_uid and program_id = v_prog;

  return jsonb_build_object(
    'ok', true, 'entitlement_id', v_id, 'cards_for_program', v_n,
    'note', case when v_n > 1
      then 'Bu programdan ' || v_n || ' kartın kayıtlı. Kural motoru her salonda '
           'en çok hak vereni seçer ve kapıda hangisini uzatacağını söyler.'
      else null end);
end $$;
grant execute on function public.save_host_card(text, text, text, smallint, text, text) to authenticated;

-- Kartı kaldırma yolu da olmalı — ekleyip silememek kullanıcıyı kilitler
create or replace function public.remove_host_card(p_entitlement_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_n int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  delete from host_entitlements
   where id = p_entitlement_id and user_id = v_uid;   -- 🔴 sahiplik şartı
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'not_found_or_not_yours'; end if;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.remove_host_card(uuid) to authenticated;

-- App'in kart listesini okuyabilmesi için (tablo GRANT'i yok — 159'un
-- envanterinde host_entitlements hiç geçmiyor; RPC ile veriyoruz)
create or replace function public.my_access_cards()
returns table (
  id uuid, program_code text, program_name text, tier text,
  card_label text, guest_capacity smallint, bank_code text,
  card_product text, verified boolean, bank_dependent boolean
) language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select he.id, p.code, p.name, he.tier, he.card_label, he.guest_capacity,
         he.bank_code, he.card_product, coalesce(he.verified, false),
         (p.entitlement_model in ('card_network','bank_card')
          or p.code in ('PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','DREAMFOLKS',
                        'EVERYLOUNGE','ONPASS','AMEX_GLOBAL','BANK_CARD'))
    from host_entitlements he
    join lounge_programs p on p.id = he.program_id
   where he.user_id = v_uid
   order by p.name, coalesce(he.card_label, ''), he.tier;
end $$;
grant execute on function public.my_access_cards() to authenticated;


-- ============================================================
-- 2 · set_availability_cabin — kabin bilgisini ilana yazar
-- ============================================================
-- 🔴 create_availability İMZASI DEĞİŞTİRİLMİYOR. 158'in dersi:
-- imza değiştirmek eski app sürümlerini kırar ya da aşırı yükleme
-- bırakır. Charter ve carrier için de aynı desen kullanılmıştı
-- (`set_availability_charter`); bu onun kardeşi.
create or replace function public.set_availability_cabin(
  p_avail_id uuid,
  p_cabin    text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_host uuid; v_c text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select host_id into v_host from availabilities where id = p_avail_id;
  if v_host is null then raise exception 'not_found'; end if;
  if v_host <> v_uid then raise exception 'not_host'; end if;

  v_c := nullif(btrim(lower(coalesce(p_cabin,''))), '');
  if v_c is not null and v_c not in ('economy','business','first') then
    raise exception 'invalid_cabin';
  end if;

  update availabilities set cabin_class = v_c, updated_at = now()
   where id = p_avail_id;

  return jsonb_build_object(
    'ok', true, 'cabin_class', v_c,
    -- Resmî kural: misafir hakkı BİLETE değil STATÜ kartına bağlı
    -- (Tablo-4 Business bölümü notu). Business seçen host'a bunu
    -- söylemek, kapıda sürprizi önler.
    'note', case when v_c = 'business'
      then 'Business bileti seni içeri alır ama misafir hakkı kart tipinden gelir.'
                 when v_c = 'first'
      then 'First Class bileti Business bölümünde bir misafir hakkı verir.'
      else null end);
end $$;
grant execute on function public.set_availability_cabin(uuid, text) to authenticated;


-- ============================================================
-- 3 · BEKÇİLER — hepsi GERÇEKTEN çağırır (186 dersi)
-- ============================================================

-- 3a) İki kart eklenebiliyor mu, RPC ile?
do $$
declare v_uid uuid; j1 jsonb; j2 jsonb; v_n int;
begin
  select id into v_uid from users where email like 'kural%' limit 1;
  if v_uid is null then select id into v_uid from users order by created_at limit 1; end if;
  if v_uid is null then raise notice '193: kart bekcisi atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  delete from host_entitlements where user_id = v_uid and card_label like '193-%';
  j1 := public.save_host_card('TK_MS', 'ELPL', '193-amex', 1::smallint, 'GARANTI', 'Bonus');
  j2 := public.save_host_card('TK_MS', 'ELPL', '193-garanti', 2::smallint, 'GARANTI', 'Miles');

  select count(*) into v_n from host_entitlements
   where user_id = v_uid and card_label like '193-%';
  if v_n <> 2 then
    raise exception '193: save_host_card iki kart yaratamadi (% kart)', v_n;
  end if;

  -- Okuma yolu da çalışmalı — yazıp okuyamamak yarım özelliktir
  select count(*) into v_n from public.my_access_cards() where card_label like '193-%';
  if v_n <> 2 then raise exception '193: my_access_cards kartlari gostermiyor (%)', v_n; end if;

  -- Silme yolu
  perform public.remove_host_card((j1 ->> 'entitlement_id')::uuid);
  select count(*) into v_n from host_entitlements
   where user_id = v_uid and card_label like '193-%';
  if v_n <> 1 then raise exception '193: remove_host_card calismadi (%)', v_n; end if;

  delete from host_entitlements where user_id = v_uid and card_label like '193-%';
  raise notice '193: kart ekle/oku/sil zinciri kanitlandi';
end $$;

-- 3b) Başkasının kartını silemesin (sahiplik şartı gerçekten var mı)
do $$
declare v_a uuid; v_b uuid; v_id uuid; v_ok boolean := false;
begin
  select id into v_a from users order by created_at limit 1;
  select id into v_b from users where id <> v_a order by created_at limit 1;
  if v_a is null or v_b is null then raise notice '193: sahiplik bekcisi atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a::text, 'role', 'authenticated')::text, true);
  v_id := (public.save_host_card('TK_MS', 'ELITE', '193-sahiplik', 1::smallint) ->> 'entitlement_id')::uuid;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_b::text, 'role', 'authenticated')::text, true);
  begin
    perform public.remove_host_card(v_id);
  exception when others then v_ok := true;
  end;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a::text, 'role', 'authenticated')::text, true);
  delete from host_entitlements where card_label = '193-sahiplik';

  if not v_ok then raise exception '193: BASKASININ karti silinebiliyor — sahiplik kapisi yok'; end if;
  raise notice '193: baskasinin karti silinemiyor';
end $$;

-- 3c) Kabin yazma çalışıyor mu ve kural motoruna ULAŞIYOR mu?
do $$
declare v_av uuid; v_host uuid; j jsonb; v_c text; r record;
begin
  select id, host_id into v_av, v_host from availabilities where active limit 1;
  if v_av is null then raise notice '193: kabin bekcisi atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_host::text, 'role', 'authenticated')::text, true);
  j := public.set_availability_cabin(v_av, 'business');
  select cabin_class into v_c from availabilities where id = v_av;
  if v_c is distinct from 'business' then
    raise exception '193: kabin yazilmadi (% okundu)', coalesce(v_c,'null');
  end if;

  -- 🔴 ASIL SORU: yazdık da MOTOR OKUYOR MU? 191 kabini karar
  -- zincirine bağlamıştı; buraya kadar geldiğini ölçmezsek
  -- "kabloladık" demek yine yarım kalır.
  select * into r from public.cabin_rule_reach();
  if r.erisilebilir < 1 then
    raise exception '193: kabin yazildi ama cabin_rule_reach hala 0 goruyor';
  end if;

  -- Karar fonksiyonu kabinle çağrılınca patlamamalı
  perform public.lounge_access_decision(v_av, null);

  update availabilities set cabin_class = null where id = v_av;   -- temizlik
  raise notice '193: kabin yazma yolu acildi ve motora ulasiyor';
end $$;

-- 3d) Başkasının ilanına kabin yazılamasın
do $$
declare v_av uuid; v_host uuid; v_other uuid; v_ok boolean := false;
begin
  select id, host_id into v_av, v_host from availabilities where active limit 1;
  select id into v_other from users where id <> v_host order by created_at limit 1;
  if v_av is null or v_other is null then raise notice '193: kabin sahiplik bekcisi atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other::text, 'role', 'authenticated')::text, true);
  begin
    perform public.set_availability_cabin(v_av, 'first');
  exception when others then v_ok := true;
  end;
  if not v_ok then
    update availabilities set cabin_class = null where id = v_av;
    raise exception '193: BASKASININ ilanina kabin yazilabiliyor';
  end if;
  raise notice '193: baskasinin ilanina kabin yazilamiyor';
end $$;

-- 3e) Yeni RPC'ler canlılık testine girsin (186 dersi)
do $$
declare v_src text; v_new text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'rpc_smoke_test' and pronamespace = 'public'::regnamespace limit 1;
  if v_oid is null then raise notice '193: rpc_smoke_test yok'; return; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if position('my_access_cards' in v_src) > 0 then
    raise notice '193: smoke listesi zaten guncel'; return;
  end if;
  v_new := replace(v_src,
    '''my_availabilities'', ''my_visits'', ''partners_visible''',
    '''my_availabilities'', ''my_visits'', ''partners_visible'', ''my_access_cards''');
  if v_new = v_src then raise notice '193: smoke listesi kalibi bulunamadi'; return; end if;
  execute 'create or replace function public.rpc_smoke_test() returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql volatile security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '193: my_access_cards canlilik testine eklendi';
end $$;

do $$
declare r record; v_bad int := 0;
begin
  for r in select * from public.rpc_smoke_test() where sonuc like '✗%' loop
    raise warning '193: RPC PATLIYOR — % : %', r.rpc, r.hata;
    v_bad := v_bad + 1;
  end loop;
  if v_bad > 0 then raise exception '193: % RPC canlida patliyor', v_bad; end if;
  raise notice '193: rpc_smoke_test temiz';
end $$;

select '193 OK - kart etiketi ve kabin yazma yollari acildi' as sonuc;
