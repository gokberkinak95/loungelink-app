-- ============================================================
-- LoungeLink · sql/281_kural_motoru_kapida_dogru.sql
-- 1 Eylül 2026
--
-- 🔴 KURAL MOTORU — KAPIDA YANLIŞ KARAR VEREN DÖRT HATA
--
-- Kural motoru ürünün tek farklılaştırıcısı ve "kapıda öğrenme" vaadi
-- onun üstünde duruyor. Alan uzmanı denetimi (canlı DB'de izlerle)
-- dört yerde motorun kapıda REDDEDİLECEK bir misafire "uygun" dediğini
-- gösterdi:
--
--   R1 · MİSAFİR UÇUŞU BİLİNMİYORKEN "UYGUN".
--        `_prebase`: v_g_car := upper(substring('' from '^[A-Za-z]+'))
--        → NULL. Sonraki `if v_g_car = ''` NULL olduğu için FALSE ve
--        v_fits TRUE kalıyor. İz: THY Elite Plus host, misafir uçuşu
--        girilmemiş → "Misafir hakkı var (1 kişi), ek ücret yok." Kapıda
--        misafir Pegasus'la uçuyorsa reddedilir.
--        (`select upper(substring('' from '^[A-Za-z]+')) is null` → t)
--
--   R2 · SUNUCU KAPISI v5'İ DEĞİL TABAN KARARI ÇAĞIRIYOR, MİSAFİR
--        UÇUŞU OLMADAN. `create_request_impl_preflag:52`
--        `lounge_access_decision(p_avail_id, null)` — havayolu
--        katmanı (v5) sunucuda HİÇ yok. Ekran "uçuşun uymuyor" dese
--        bile istek geçer.
--
--   R3 · HAVAYOLUNA BAĞLI PROGRAMLAR "UYARI" SEVİYESİNDE.
--        20 programın 20'si enforcement=warn. THY md.17 ("misafir THY
--        ile uçmalı") bir uyarı değil, KESİN yasak. İz: Elite Plus +
--        Pegasus misafir → warn, can_request=true, needs_ack=true.
--        Misafir kutuyu işaretleyip kapıya gidiyor.
--
--   R4 · "SÜRESİ DOLDU" YANLIŞ ALARMI. v4 `max(effective_to)` alıyor;
--        PP/DP'de eski satır 30 Ağustos'ta bitti, yeni satır
--        effective_to=null → HER PP kararı "kural dönemi sona erdi".
--        Doğru ölçüt: CANLI kural yok mu.
--
--   R5 · "Birlikte varış şartı sağlanıyor" KOŞULSUZ 'ok'.
--        `kural_kosullari` 3. satır same_flight dışı her bağda bunu
--        yazıyor — hiçbir şey kontrol etmeden. PP md.: "üyeyle aynı
--        anda kaydolmalı". Kontrol edilmeyen şart 'ok' değil,
--        'bilinmiyor'dur.
--
-- 🆕 SINIF: "BİR KURAL MOTORUNUN EN TEHLİKELİ ÇIKTISI 'HAYIR' DEĞİL,
-- BİLMEDİĞİ BİR ŞEYE VERDİĞİ 'EVET'TİR."
-- ============================================================

-- ── R1 · NULL taşıyıcı ────────────────────────────────────────────
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.lounge_access_decision_prebase'::regproc) into v_def;
  if v_def like '%281/R1%' then
    raise notice '281: prebase zaten yamali';
  else
    v_yeni := replace(v_def,
$S$  v_g_car    := upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+'));$S$,
$S$  -- 281/R1: substring eşleşmezse NULL döner ve `= ''` karşılaştırması
  -- FALSE olur → "bilinmiyor" dalı hiç çalışmaz, fits TRUE kalırdı.
  v_g_car    := coalesce(upper(substring(coalesce(p_guest_flight,'') from '^[A-Za-z]+')), '');$S$);
    if v_yeni = v_def then raise exception '281: prebase v_g_car snippeti bulunamadi'; end if;
    v_def := v_yeni;
    v_yeni := replace(v_def,
$S$  v_host_car := upper(coalesce(v_av.carrier,
                    substring(coalesce(v_av.flight_number,'') from '^[A-Za-z]+')));$S$,
$S$  v_host_car := coalesce(upper(coalesce(v_av.carrier,
                    substring(coalesce(v_av.flight_number,'') from '^[A-Za-z]+'))), '');$S$);
    if v_yeni = v_def then raise exception '281: prebase v_host_car snippeti bulunamadi'; end if;
    execute v_yeni;
    raise notice '281: R1 uygulandi';
  end if;
end $$;

-- ── R3 · Havayoluna bağlı programlar KESİN ────────────────────────
-- Yalnız taşıyıcı/ittifak/uçuş bağı olan programlar. `any` olanlar
-- (PP, LoungeKey…) uyarı kalır — orada havayolu şartı yok.
update lounge_programs
   set enforcement = 'block'
 where guest_flight_coupling in ('same_carrier','same_alliance','same_flight')
   and enforcement <> 'block';

-- ── R2 · Sunucu kapısı v5 + misafirin gerçek uçuşu ────────────────
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.create_request_impl_preflag'::regproc) into v_def;
  if v_def like '%281/R2%' then
    raise notice '281: preflag zaten yamali';
  else
    v_yeni := replace(v_def,
$S$    v_dec := public.lounge_access_decision(p_avail_id, null);
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;$S$,
$S$    -- 281/R2: karar ARTIK v5 ve MİSAFİRİN KENDİ UÇUŞUYLA veriliyor.
    -- Uçuş, ilanla çakışan seyahat kaydından okunuyor (v_has_trip zaten
    -- birinin varlığını kanıtladı). Ekranın gördüğü kararla sunucunun
    -- uyguladığı karar aynı fonksiyondan çıkıyor — iki motor değil, bir.
    declare v_gf text; v_gc text;
    begin
      select v.flight_number, v.carrier_code into v_gf, v_gc
        from visits v
       where v.user_id = v_uid
         and v.airport_code = v_av.airport_code
         and v.visit_date = v_av.avail_date
         and v.time_from < v_av.time_to and v_av.time_from < v.time_to
       order by (v.flight_number is not null) desc, v.created_at desc
       limit 1;
      v_dec := public.lounge_access_decision_v5(p_avail_id, v_gf, v_gc);
    end;
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
    -- Havayolu şartı KESİN (enforcement=block) ve misafirin uçuşu
    -- uymuyorsa istek SUNUCUDA durur — onay kutusuyla geçilemez.
    if (v_dec ->> 'carrier_ok') = 'false' and (v_dec ->> 'enforcement') = 'block' then
      raise exception 'guest_carrier_mismatch';
    end if;$S$);
    if v_yeni = v_def then raise exception '281: preflag karar snippeti bulunamadi'; end if;
    execute v_yeni;
    raise notice '281: R2 uygulandi';
  end if;
end $$;

-- ── R4 · "Süresi doldu" yalnız CANLI kural yoksa ──────────────────
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.lounge_access_decision_v4'::regproc) into v_def;
  if v_def like '%281/R4%' then
    raise notice '281: v4 zaten yamali';
  else
    v_yeni := replace(v_def,
$S$  select max(r.effective_to) into v_exp
    from lounge_guest_rules r where r.program_id = v_prog_id and r.effective_to is not null;
  if v_exp is not null and v_exp < current_date then$S$,
$S$  -- 281/R4: max(effective_to) eski satırın bitişini görüp yeni (açık
  -- uçlu) satırı görmüyordu → her PP/DP kararı "süresi doldu" diyordu.
  -- Ölçüt: bugün geçerli TEK BİR kural bile yoksa dolmuştur.
  select max(r.effective_to) into v_exp
    from lounge_guest_rules r where r.program_id = v_prog_id and r.effective_to is not null;
  if v_exp is not null and v_exp < current_date
     and not exists (select 1 from lounge_guest_rules r2
                      where r2.program_id = v_prog_id
                        and (r2.effective_from is null or r2.effective_from <= current_date)
                        and (r2.effective_to   is null or r2.effective_to   >= current_date)) then$S$);
    if v_yeni = v_def then raise exception '281: v4 effective_to snippeti bulunamadi'; end if;
    v_def := v_yeni;
    v_yeni := replace(v_def,
$S$    'rules_expired', (v_exp is not null and v_exp < current_date),$S$,
$S$    'rules_expired', (v_exp is not null and v_exp < current_date
                        and not exists (select 1 from lounge_guest_rules r3
                                         where r3.program_id = v_prog_id
                                           and (r3.effective_from is null or r3.effective_from <= current_date)
                                           and (r3.effective_to   is null or r3.effective_to   >= current_date))),$S$);
    if v_yeni = v_def then raise exception '281: v4 rules_expired snippeti bulunamadi'; end if;
    execute v_yeni;
    raise notice '281: R4 uygulandi';
  end if;
end $$;

-- ── R5 · Kontrol edilmeyen şart 'ok' değil ─────────────────────────
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.kural_kosullari'::regproc) into v_def;
  if v_def like '%281/R5%' then
    raise notice '281: kural_kosullari zaten yamali';
  else
    v_yeni := replace(v_def,
$S$      durum := 'ok';
      metin := 'Birlikte varış şartı sağlanıyor';$S$,
$S$      -- 281/R5: bu satır hiçbir şey ölçmeden 'ok' yazıyordu. "Birlikte
      -- varış" bir kapı kuralıdır (PP: üyeyle aynı anda kayıt) ve biz
      -- iki kişinin aynı anda kapıda olacağını BİLEMEYİZ — söyleyebiliriz.
      durum := 'bilinmiyor';
      metin := 'Birlikte varış gerekir · kapıda beraber olun';$S$);
    if v_yeni = v_def then raise exception '281: kural_kosullari snippeti bulunamadi'; end if;
    execute v_yeni;
    raise notice '281: R5 uygulandi';
  end if;
end $$;

-- ── NÖBETÇİLER — DENETİMİN İZLERİYLE AYNI ─────────────────────────
do $$
declare d jsonb; v_av uuid; v int;
begin
  -- R1: misafir uçuşu boşken fits TRUE DÖNMEMELİ (null olmalı)
  select a.id into v_av
    from availabilities a
    join host_entitlements he on he.user_id = a.host_id
    join lounge_programs p on p.id = he.program_id
   where p.guest_flight_coupling = 'same_carrier' and a.active
   order by a.created_at desc limit 1;
  if v_av is not null then
    d := public.lounge_access_decision_prebase(v_av, null);
    if (d ->> 'fits') = 'true' then
      raise exception '281/R1: misafir ucusu bosken fits=true — NULL tasiyici hatasi duruyor';
    end if;
    raise notice '281 NOBETCI OK: ucus bilinmiyorken fits=%', coalesce(d->>'fits','null');
  else
    raise notice '281 NOBETCI (R1): same_carrier ilan yok, iz atlandi';
  end if;

  -- R3: taşıyıcıya bağlı program warn kalmamalı
  select count(*) into v from lounge_programs
   where guest_flight_coupling in ('same_carrier','same_alliance','same_flight')
     and enforcement <> 'block';
  if v > 0 then raise exception '281/R3: % program hala warn', v; end if;

  -- R4: Priority Pass'ta canlı kural varken rules_expired FALSE olmalı
  select a.id into v_av
    from availabilities a
    join host_entitlements he on he.user_id = a.host_id
    join lounge_programs p on p.id = he.program_id
   where p.code = 'PRIORITY_PASS' and a.active
   order by a.created_at desc limit 1;
  if v_av is not null then
    d := public.lounge_access_decision_v4(v_av, null);
    if (d ->> 'rules_expired') = 'true'
       and exists (select 1 from lounge_guest_rules r join lounge_programs p on p.id=r.program_id
                    where p.code='PRIORITY_PASS'
                      and (r.effective_to is null or r.effective_to >= current_date)) then
      raise exception '281/R4: PP canli kural varken rules_expired=true';
    end if;
    raise notice '281 NOBETCI OK: PP rules_expired=%', d->>'rules_expired';
  end if;

  -- R5: kural_kosullari artık koşulsuz 'ok' yazmıyor
  if pg_get_functiondef('public.kural_kosullari'::regproc) like '%Birlikte varış şartı sağlanıyor%' then
    raise exception '281/R5: kosulsuz ok satiri duruyor';
  end if;

  -- R2: preflag v5 çağırıyor ve sızıntı yolu kapalı
  if pg_get_functiondef('public.create_request_impl_preflag'::regproc) not like '%lounge_access_decision_v5%' then
    raise exception '281/R2: preflag hala taban karari cagiriyor';
  end if;
  raise notice '281 NOBETCI OK: kural motoru kapida dogru';
end $$;
