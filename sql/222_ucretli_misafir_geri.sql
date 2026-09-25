-- ============================================================================
-- LoungeLink · 222_ucretli_misafir_geri.sql               (19 Ağustos 2026)
--
-- 🔴 KARTININ KADEMESİNİ DOĞRU BEYAN EDEN HOST'UN İLANI KAPANIYORDU
--
-- ── ÖLÇÜM (izole, tekrar üretilebilir, geri döndürülebilir) ─────────
-- Aynı host, aynı ilan, aynı salon. Tek değişiklik: kartın kademesini
-- yazmak.
--     tier NULL        → guest_policy = paid          ✓
--     tier PP_PRESTIGE → guest_policy = not_allowed   🔴
--     tier NULL (geri) → guest_policy = paid          ✓
--
-- 60 aday salon tarandı; kademesi yazılı bir host için HİÇBİRİNDE `paid`
-- çıkmadı. Yani ücretli misafir dalı, kademesini beyan eden herkes için
-- tamamen erişilemezdi.
--
-- ── KÖK NEDEN — 157_decision_uses_resolver.sql:296-299 ──────────────
--     if (v_rj ->> 'tier_code') is not null and (v_rj ->> 'tier_code') = v_tier then
--       v_policy := case when guest_allowance > 0 then 'included' else 'not_allowed' end;
--
-- Kademe eşleştiğinde politika İKİ değere zorlanıyor; `paid` bu yolda
-- üretilemiyor. Ve bir satır yukarıda (157:250) salonun kabul satırından
-- gelen `v_policy := v_acc.guest_policy` — yani 'paid' — SESSİZCE eziliyor.
--
-- Oradaki yorum iki ayrı kavramı karıştırmış:
--   · `paid_entry_allowed` = HOST'un kendi ücretli girişi  → dışarıda
--     tutulması DOĞRU
--   · kabul satırının `guest_policy = 'paid'` = MİSAFİRİN ücretli girişi
--     → yok edilmemeli
--
-- Kural zaten misafir ücretini biliyor: Priority Pass için
-- `resolve_guest_rule` `"guest_fee": "30 EUR / misafir"` döndürüyor.
-- `guest_allowance = 0` "ÜCRETSİZ misafir yok" demek; "misafir yok"
-- demek değil.
--
-- ── ETKİSİ ──────────────────────────────────────────────────────────
-- Priority Pass / DragonPass / LoungeKey hostları en büyük arz havuzu.
-- 219 ile kapıyı hizaladığımız için `create_request` de reddediyordu.
-- Yani DOĞRU DAVRANAN kullanıcı (kartını eksiksiz beyan eden host)
-- cezalandırılıyordu — ve bunu kimse göremiyordu, çünkü hata değil
-- sessiz bir "hayır" üretiyordu.
--
-- ── NEDEN SARMALAYICI, NEDEN 157'YE DOKUNMUYORUM ────────────────────
-- Taban fonksiyon 192a tarafından zaten sarmalanmış
-- (`lounge_access_decision_prebase`). 157'nin gövdesini yeniden yazmak
-- 500+ satırı elle kopyalamak demek; kopyalarken bir satırı kaçırmak bu
-- turda iki kez başıma geldi. Düzeltme SAF BİR SON İŞLEM olarak
-- yazılabiliyor: kararın kendi çıktısı + salonun kabul satırı yeterli.
--
-- Zincir: lounge_access_decision (222, ücret onarımı)
--           → lounge_access_decision_prefee (192a, charter)
--             → lounge_access_decision_prebase (157, taban)
--
-- ── AÇIKÇA DOKUNMADIKLARIM ──────────────────────────────────────────
-- · charter engeli (192a) — `charter=true` ise ONARIM YAPILMIYOR
-- · taşıyıcı uyuşmazlığı — `carrier_ok=false` ise yapılmıyor
-- · salonun programı hiç kabul etmediği durum (`source='venue'` + block)
-- · kabul satırı `not_allowed` diyen salonlar — orada politika GERÇEKTEN
--   "misafir yok"; onarım YALNIZCA kabul satırı 'paid' diyorsa çalışır.
-- ============================================================================


do $sarmala$
declare
  v_oid oid; v_args text; v_res text; v_cagri text;
begin
  select p.oid into v_oid
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'lounge_access_decision'
   limit 1;
  if v_oid is null then
    raise exception '222: lounge_access_decision bulunamadi';
  end if;

  -- Dosya iki kez çalıştırılırsa zararsız olmalı (192a'nın deseni).
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'lounge_access_decision_prefee') then
    raise notice '222: ucret onarimi zaten kurulu — atlandi';
    return;
  end if;

  v_args := pg_get_function_arguments(v_oid);        -- DEFAULT'lari korur
  v_res  := pg_get_function_result(v_oid);
  select string_agg(split_part(btrim(x), ' ', 1), ', ')
    into v_cagri
    from unnest(string_to_array(pg_get_function_identity_arguments(v_oid), ',')) x;

  execute format('alter function public.lounge_access_decision(%s) '
                 'rename to lounge_access_decision_prefee',
                 pg_get_function_identity_arguments(v_oid));

  execute format($f$
    create function public.lounge_access_decision(%s) returns %s
    language plpgsql stable security definer set search_path = public as $BODY$
    declare
      d        jsonb;
      v_acc    lounge_venue_acceptance%%rowtype;
      v_venue  uuid;
      v_prog   uuid;
    begin
      d := public.lounge_access_decision_prefee(%s);
      if d is null then return d; end if;

      -- Onarım YALNIZCA şu dar durumda: kural dalı "misafir yok" dedi,
      -- ücretsiz misafir sayısı 0 ve salonun KABUL SATIRI misafirin
      -- ücretle girebildiğini söylüyor.
      if coalesce(d ->> 'guest_policy','') <> 'not_allowed' then return d; end if;
      if coalesce(d ->> 'source','') <> 'rule' then return d; end if;
      if coalesce((d ->> 'guest_included_count')::int, 0) > 0 then return d; end if;

      -- Gerçek engelleri ASLA ezme.
      if coalesce((d ->> 'charter')::boolean, false) then return d; end if;
      if coalesce(d ->> 'carrier_ok','') = 'false' then return d; end if;

      v_venue := nullif(d ->> 'venue_id','')::uuid;
      v_prog  := nullif(d ->> 'program_id','')::uuid;
      if v_venue is null or v_prog is null then return d; end if;

      select * into v_acc from lounge_venue_acceptance a
       where a.venue_id = v_venue and a.program_id = v_prog and a.active
       order by a.is_placeholder, a.checked_at desc nulls last
       limit 1;

      if not found or not v_acc.accepted then return d; end if;
      if coalesce(v_acc.guest_policy,'') <> 'paid' then return d; end if;

      -- Buraya geldiysek: salon misafiri ÜCRETLE alıyor, kural yalnız
      -- "ücretsiz hakkın yok" diyor. İkisi çelişmiyor — birleşiyor.
      return d || jsonb_build_object(
        'guest_policy',        'paid',
        'severity',            case when coalesce(d ->> 'severity','') = 'block'
                                    then 'warn' else coalesce(d ->> 'severity','info') end,
        'guest_included_count', 0,
        'guest_fee_amount',    coalesce((d ->> 'guest_fee_amount')::numeric, v_acc.guest_fee_amount),
        'guest_fee_currency',  coalesce(nullif(d ->> 'guest_fee_currency',''), v_acc.guest_fee_currency),
        'guest_fee_note',      coalesce(nullif(d ->> 'guest_fee_note',''), v_acc.guest_fee_note),
        'fee_repaired',        true,
        'headline',            'Misafir girişi ücretli',
        'detail',              trim(both ' ' from
                                 coalesce(d ->> 'detail','') || ' ' ||
                                 'Kartın ücretsiz misafir hakkı vermiyor ama bu salon misafiri '
                                 'ücretle alıyor. Tutarı ve ödeme şeklini host ile sohbette '
                                 'kararlaştırın.'));
    end $BODY$$f$, v_args, v_res, v_cagri);

  raise notice '222: ucretli misafir dali onarildi (kademe beyan eden hostlar icin)';
end
$sarmala$;


-- ── NÖBETÇİ 1 · SARMALAYICI SÖZLEŞMESİ ──────────────────────────────
-- İmza ve dönüş tipi delegeyle BİREBİR aynı olmalı. (192a'nın nöbetçisi
-- ile aynı sınıf: bir sarmalayıcı imzayı kaydırırsa çağıranlar 22P02 alır.)
do $n1$
declare a1 text; a2 text; r1 text; r2 text;
begin
  select pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
    into a1, r1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='lounge_access_decision' limit 1;
  select pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
    into a2, r2 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='lounge_access_decision_prefee' limit 1;
  if a2 is null then
    raise exception '222: delege (prefee) yok — sarmalama yapilmamis';
  end if;
  if a1 is distinct from a2 or r1 is distinct from r2 then
    raise exception '222: sarmalayici sozlesmesi AYRISIYOR → arg[%|%] ret[%|%]', a1, a2, r1, r2;
  end if;
  raise notice '222: sarmalayici sozlesmesi delegeyle ayni';
end $n1$;


-- ── NÖBETÇİ 2 · ONARIM GERÇEKTEN ÇALIŞIYOR MU ───────────────────────
--
-- 🔴 SIFIR SATIR ÖLÇEN BİR DENETİM "0 HATA" DİYE YEŞİL YANAR.
-- Bu turda tam olarak o tuzağa bir kez düştüm. Burada önce ÖRNEK VAR MI
-- diye bakıyorum; yoksa geçici bir örnek KURUYORUM ve sonunda geri
-- alıyorum. Yani denetim veri yokluğunda susmuyor.
do $n2$
declare
  v_h uuid; v_l record; v_id uuid; d jsonb; v_kuruldu boolean := false;
  v_onarilan int := 0; v_toplam int := 0; r record;
begin
  -- (a) Mevcut ilanlarda onarımın etkisini say
  for r in select id from availabilities where active loop
    d := public.lounge_access_decision(r.id, null);
    v_toplam := v_toplam + 1;
    if coalesce((d ->> 'fee_repaired')::boolean, false) then
      v_onarilan := v_onarilan + 1;
    end if;
  end loop;

  -- (b) Hiç örnek yoksa YAPAY bir tane kur: kademesi yazılı bir host +
  --     misafiri ücretli kabul eden bir salon.
  if v_onarilan = 0 then
    select he.user_id into v_h
      from host_entitlements he
      join lounge_programs p on p.id = he.program_id
     where he.tier is not null and p.entitlement_model <> 'bank_card'
     limit 1;

    if v_h is not null then
      select l.id lid, l.airport_code ap into v_l
        from lounges l
        join host_entitlements he on he.user_id = v_h
        join lounge_venue_acceptance ac
          on ac.venue_id = l.venue_id and ac.program_id = he.program_id
         and ac.active and ac.accepted and ac.guest_policy = 'paid'
       where l.active and l.venue_id is not null
       limit 1;

      if v_l.lid is not null then
        insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                    time_from, time_to, slots, filled, visibility)
        values (v_h, v_l.lid, v_l.ap, current_date + 30, '10:00', '12:00', 1, 0, 'Public')
        returning id into v_id;
        v_kuruldu := true;
        d := public.lounge_access_decision(v_id, null);
        if coalesce(d ->> 'guest_policy','') = 'paid' then
          v_onarilan := 1;
        end if;
        delete from availabilities where id = v_id;
      end if;
    end if;
  end if;

  if v_toplam = 0 then
    raise notice '222: aktif ilan yok — onarim OLCULEMEDI';
  elsif v_onarilan = 0 then
    -- Uyarı, hata değil: katalogda "misafiri ücretli kabul eden salon +
    -- kademesi yazılı host" birleşimi hiç olmayabilir. Ama sessiz geçmiyoruz.
    raise warning '222: onarimin etkisi OLCULEMEDI — % aktif ilanda ve yapay ornekte de ucretli dal cikmadi', v_toplam;
  else
    raise notice '222: ucretli dal ERISILEBILIR (% / % ilan%)',
      v_onarilan, v_toplam, case when v_kuruldu then ' · yapay ornekle dogrulandi' else '' end;
  end if;
end $n2$;


-- ── NÖBETÇİ 3 · GERÇEK ENGELLER EZİLMEDİ ────────────────────────────
-- Onarım yalnızca dar bir durumda çalışmalı. Charter ya da taşıyıcı
-- engeli olan bir ilanda `paid` çıkarsa, kullanıcıyı giremeyeceği bir
-- salona göndermiş oluruz — bu düzeltmenin en pahalı yan etkisi bu olurdu.
do $n3$
declare v_ihlal int := 0; v_ornek text := ''; r record; d jsonb;
begin
  for r in select id from availabilities where active loop
    d := public.lounge_access_decision(r.id, null);
    if coalesce(d ->> 'guest_policy','') = 'paid'
       and (coalesce((d ->> 'charter')::boolean,false)
            or coalesce(d ->> 'carrier_ok','') = 'false') then
      v_ihlal := v_ihlal + 1;
      if v_ornek = '' then
        v_ornek := left(r.id::text,8) || ' charter=' || coalesce(d ->> 'charter','-')
                || ' carrier_ok=' || coalesce(d ->> 'carrier_ok','-');
      end if;
    end if;
  end loop;
  if v_ihlal > 0 then
    raise exception '222: onarim GERCEK ENGELI ezdi → % ilan, ornek %', v_ihlal, v_ornek;
  end if;
  raise notice '222: charter/tasiyici engelleri korundu';
end $n3$;

select '222 OK — ucretli misafir dali kademe beyan eden hostlar icin geri geldi' as sonuc;
