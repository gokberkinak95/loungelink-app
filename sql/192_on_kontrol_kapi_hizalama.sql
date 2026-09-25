-- ============================================================
-- 192 · ÖN KONTROL İLE SUNUCU KAPISI HİZALAMASI
-- 17 Ağustos 2026
--
-- 🔴 BU DOSYA YENİ BİR TESTİN İLK GÜNÜNDE BULDUĞU İKİ HATAYI KAPATIYOR.
--
-- Tur 2'de `render_check/flow_matrix_e2e.py` yazıldı: mevcut üç E2E
-- her adımı YAPAN TARAFTAN doğruluyordu, hiçbiri KARŞI TARAFIN ne
-- gördüğünü ve YÜZEYLERİN BİRBİRİYLE TUTARLI olup olmadığını
-- ölçmüyordu. İlk koşuda iki gerçek kusur çıktı:
--
--   ✗ 11. Ön kontrol ve karar AYNI politikayı söylüyor
--          keşif = not_allowed   ·   precheck = (guest_policy YOK)
--   ✗ 13. Ekran kapısı ile sunucu kapısı AYNI karar veriyor
--          ekran can_request=true   ·   sunucu no_matching_trip
--
-- ============================================================
-- KUSUR 1 — ERKEN DÖNÜŞ DALLARI KARARI TAŞIMIYOR
-- ============================================================
-- ÖLÇÜM: kredi kartı kaynaklı bir ilanda request_precheck şunu döndü:
--   { "kind": "card_generic", "can_request": true, "credit_cost": 0,
--     "headline": "Bu ilandaki hak kredi kartından geliyor", ... }
-- `guest_policy` ANAHTARI YOK. Oysa aynı ilan için
--   lounge_access_decision → guest_policy = 'not_allowed'
--   discover_availabilities → guest_policy = 'not_allowed'
--
-- 142:114 satırındaki erken dönüş, kararı hesapladıktan SONRA onu
-- taşımadan çıkıyor. Sonuç: keşif kartında "Yalnız kart sahibini
-- alıyor" rozeti görünürken istek ekranı hiçbir şey demiyor ve
-- gönderme butonu AÇIK kalıyor — Gökberk'in 9. maddesi tam bu.
--
-- 🔴 SINIF: "erken dönüş, sözleşmenin yarısını düşürür". Fonksiyonun
-- ana dönüşü zenginleştirilirken erken dönüş dalları unutuluyor.
-- Bu, 157'de guide_lounges'ta, 174'te karar zincirinde, 186'da
-- bağlam alanlarında aynen yaşandı. Ders: bir fonksiyona alan
-- eklerken TÜM return noktaları sayılmalı.

do $$
declare v_src text; v_new text; v_oid oid; v_n int;
begin
  select oid into v_oid from pg_proc
   where proname = 'request_precheck' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise exception '192: request_precheck yok'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('192-karar' in v_src) > 0 then
    raise notice '192: precheck zaten karari tasiyor'; return;
  end if;

  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 26 AĞUSTOS 2026 — TEKRAR ÇALIŞTIRMA GÜVENLİĞİ
  --
  -- Bu blok `request_precheck`in GÖVDESİNİ yamalar ve yamayı
  -- `192-karar` imzasıyla işaretler. Ama SONRAKİ dosyalar (250, 252)
  -- gerçek gövdeyi `request_precheck_pregate`e taşıdı; `request_precheck`
  -- artık yalnızca ince bir kapı sarmalayıcısı.
  --
  -- Sonuç: 192'yi TEKRAR çalıştırınca imzayı sarmalayıcıda arıyor,
  -- bulamıyor, deseni de bulamıyor ve "yama UYGULANMADI" diye
  -- DURUYORDU — oysa yama yerli yerinde duruyor. Ölçüldü:
  --   request_precheck_pregate.prosrc içinde '192-karar' → poz. 5169
  --   'guest_allowance' → 5408 · 'severity_src' → 5483
  --
  -- Yani dosya, kendi işini yapmış olmasına rağmen kırmızı yanıyordu.
  -- Bir nöbetçinin en kötü hâli budur: DOĞRU DURUMU HATA SAYMAK.
  -- Kullanıcı böyle bir hatayı "bir şey bozuldu" diye okur ve
  -- olmayan bir sorunu kovalar.
  --
  -- 🆕 SINIF: "GÖVDEYİ ADIYLA ARAYAN BİR YAMA, GÖVDE BAŞKA BİR ADA
  -- TAŞINDIĞINDA KENDİ İŞİNİ YOK SAYAR."
  -- ══════════════════════════════════════════════════════════════════
  if exists (select 1 from pg_proc
              where proname = 'request_precheck_pregate'
                and pronamespace = 'public'::regnamespace
                and position('192-karar' in prosrc) > 0) then
    raise notice '192: yama zaten uygulanmis (gövde request_precheck_pregate icine tasinmis) — atlaniyor';
    return;
  end if;

  -- Her erken dönüşe kararın üç anahtarını ekle. jsonb'ye alan
  -- eklemek geriye uyumludur (157'nin dersi) — eski app sürümleri
  -- bilmedikleri anahtarı görmezden gelir.
  v_new := replace(v_src,
    '''can_request'', true, ''needs_ack'', true, ''kind'',''card_generic''',
    '''can_request'', true, ''needs_ack'', true, ''kind'',''card_generic'',
      /* 192-karar: erken donus de kararin politikasini TASIR.
         Eskiden bu dal guest_policy''yi hic dondurmuyordu ve
         kesif "misafir kabul etmiyor" derken istek ekrani susuyordu. */
      ''guest_policy'', d ->> ''guest_policy'',
      ''guest_allowance'', coalesce((d ->> ''guest_included_count'')::int, 0),
      ''severity_src'', d ->> ''severity''');

  if v_new = v_src then
    -- 🔴 SESSIZ ATLAMA KAPATILDI (18 Agu). Bu blok precheck'in GOVDESINI
    -- regex ile yeniden yaziyor. Desen tutmazsa eskiden `notice` deyip
    -- CIKIYORDU; Supabase notice gostermedigi icin yama uygulanmamis
    -- olmasina ragmen dosya 'gecti' gorunuyor, sonra ASAGIDAKI BEKCILER
    -- anlasilmaz sekilde patliyordu. Gokberk'te tam bu oldu.
    raise exception '192: card_generic kalibi BULUNAMADI — precheck govdesi '
      'beklenenden farkli. Yama UYGULANMADI, dosya durduruldu.';
  end if;

  execute 'create or replace function public.request_precheck('
       || pg_get_function_arguments(v_oid) || ') returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '192: precheck erken donusleri karari tasiyor';
end $$;


-- ============================================================
-- KUSUR 2 — EKRAN KAPISI SUNUCU KAPISINDAN GEVŞEK
-- ============================================================
-- ÖLÇÜM: precheck `can_request: true` dedi; hemen ardından
--   create_request → ERROR: no_matching_trip
-- Sebep: misafirin ADB'de seyahati VAR ama 19 Ağustos'ta; ilan
-- 18 Ağustos'ta. create_request TARİH EŞLEŞMESİ arıyor (007:41),
-- precheck ise seyahat kapısını HİÇ SORMUYOR.
--
-- 🔴 NEDEN ÖNEMLİ: kullanıcı butona basar, ham bir hata alır ve
-- NE YAPACAĞINI BİLMEZ. Oysa doğru cevap elimizde: "o tarihte
-- seyahatin yok — 18 Ağustos için bir seyahat ekle".
--
-- 🔴 VE TERSİ DAHA TEHLİKELİ OLURDU: ekran kilitli, sunucu açık.
-- O zaman eski bir APK ya da doğrudan RPC kapıdan geçerdi. Bu
-- yüzden kapıların EŞİT değil, EKRANIN SUNUCUDAN GEVŞEK OLMAMASI
-- gerekir. 187 madde 12'de aynı ilkeyi sunucu tarafında uygulamıştık.

do $$
declare v_src text; v_new text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'request_precheck' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('192-seyahat' in v_src) > 0 then
    raise notice '192: seyahat kapisi zaten var'; return;
  end if;

  -- Seyahat kontrolünü fonksiyonun BAŞINA koy: hiçbir dal onu
  -- atlayamasın. Erken dönüşlerin sözleşmeyi düşürdüğünü yeni
  -- öğrendik; aynı tuzağa ikinci kez düşmüyoruz.
  v_new := regexp_replace(v_src,
    '(\mbegin\M)',
    E'begin\n'
    '  -- 🔴 192-seyahat: SUNUCU KAPISININ AYNISI. create_request\n'
    '  -- (007:41) ayni havalimani + AYNI TARIH icin seyahat arar.\n'
    '  -- Precheck bunu hic sormuyordu; ekran "gonderebilirsin" deyip\n'
    '  -- sunucu ham "no_matching_trip" firlatiyordu.\n'
    '  if not exists (\n'
    '       select 1 from visits v\n'
    '        join availabilities a2 on a2.id = p_avail_id\n'
    '       where v.user_id = auth.uid()\n'
    '         and v.airport_code = a2.airport_code\n'
    '         and v.visit_date  = a2.avail_date)\n'
    '  then\n'
    '    return jsonb_build_object(\n'
    '      ''can_request'', false, ''kind'', ''trip_gate'', ''severity'', ''block'',\n'
    '      ''headline'', ''Bu tarihte o havalimanında seyahatin yok'',\n'
    '      ''detail'', ''Bu ilan '' || (select to_char(a3.avail_date, ''DD.MM.YYYY'')\n'
    '                    || '' tarihinde '' || a3.airport_code\n'
    '                    from availabilities a3 where a3.id = p_avail_id)\n'
    '                 || ''. O gün için bir seyahat ekle, ilan hemen başvurulabilir olsun.'',\n'
    '      ''fix_action'', ''add_trip'',\n'
    '      ''credit_cost'', 0, ''credit_hold'', 0, ''credit_total'', 0);\n'
    '  end if;\n',
    'n');

  if v_new = v_src then
    raise exception '192: begin kalibi BULUNAMADI — seyahat kapisi EKLENMEDI. '
      'precheck govdesi beklenenden farkli; sessizce gecmek yerine duruyorum.';
  end if;

  execute 'create or replace function public.request_precheck('
       || pg_get_function_arguments(v_oid) || ') returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '192: precheck artik seyahat kapisini de soruyor';
end $$;


-- ============================================================
-- BEKÇİLER — ikisi de GERÇEKTEN çağırarak ölçer (186 dersi)
-- ============================================================

-- 1) Her ilanda precheck ve karar AYNI politikayı söylemeli
do $$
declare r record; v_uid uuid; v_bad int := 0; j jsonb; v_pol text; v_liste text := '';
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '192: bekci atlandi (misafir yok)'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  -- 🔴 `limit 25` KALDIRILDI (18 Agu). Bende 27 aktif ilan vardi ve
  -- ayrisan ilan siralamada 25'ten sonraya dusuyordu: bekci alti tur
  -- boyunca YESIL yandi, Gokberk'te KIRMIZI. Kapsami satir sirasina
  -- birakan bir bekci olcmuyor, kura cekiyor.
  for r in select id from availabilities where active loop
    j := public.request_precheck(r.id);
    -- trip_gate dalı kararı taşımaz, taşımasına gerek yok: kullanıcı
    -- o ilana zaten başvuramaz ve neden başvuramadığını biliyor.
    if coalesce(j ->> 'kind','') = 'trip_gate' then continue; end if;
    v_pol := public.lounge_access_decision(r.id, null) ->> 'guest_policy';
    if (j ->> 'guest_policy') is distinct from v_pol then
      raise warning '192: ilan % — precheck=% karar=%',
        left(r.id::text,8), coalesce(j ->> 'guest_policy','(YOK)'), v_pol;
      v_liste := v_liste || format(' || %s precheck=%s karar=%s',
        left(r.id::text,8), coalesce(j ->> 'guest_policy','(YOK)'), coalesce(v_pol,'(YOK)'));
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then
    -- 🔴 AYRISAN ILANLARI HATA MESAJININ ICINE YAZ. Yukaridaki
    -- `raise warning` satirlarini Supabase SQL Editor GOSTERMIYOR;
    -- Gokberk hatayi aldi ama hangi ilan oldugunu goremedi ve teshis
    -- icin ayri bir sorgu yazmak zorunda kaldik. Exception gorunuyor.
    raise exception '192: % ilanda on kontrol ile karar AYRISIYOR:%', v_bad, v_liste;
  end if;
  raise notice '192: on kontrol ile karar her ilanda ayni politikayi soyluyor';
end $$;

-- 2) Ekran kapısı sunucu kapısından GEVŞEK olmamalı
-- (eşit olması şart değil; ekranın DAHA SIKI olması güvenlidir)
do $$
declare r record; v_uid uuid; v_bad int := 0; j jsonb; v_ok boolean;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '192: kapi bekcisi atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  for r in select id, airport_code, avail_date from availabilities where active limit 15 loop
    j := public.request_precheck(r.id);
    if coalesce((j ->> 'can_request')::boolean, false) is not true then continue; end if;
    -- Ekran "gönderebilirsin" diyor. Sunucunun ÖN KOŞULLARI tutuyor mu?
    select exists (select 1 from visits v
                    where v.user_id = v_uid and v.airport_code = r.airport_code
                      and v.visit_date = r.avail_date) into v_ok;
    if not v_ok then
      raise warning '192: ilan % — ekran ACIK ama seyahat kapisi KAPALI', left(r.id::text,8);
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then
    raise exception '192: % ilanda ekran kapisi sunucudan GEVSEK', v_bad;
  end if;
  raise notice '192: ekran kapisi sunucu kapisindan gevsek degil';
end $$;

select '192 OK - on kontrol ile sunucu kapisi hizalandi' as sonuc;


-- ============================================================
-- KUSUR 3 — `card_generic` DALI POLİTİKAYA BAKMADAN "GÖNDEREBİLİRSİN" DİYOR
-- ============================================================
-- ÖLÇÜM (flow_matrix, seyahat kapısı kurulduktan SONRA):
--   ekran can_request = true
--   sunucu            = ERROR: guests_not_allowed
--   karar             = guest_policy 'not_allowed'
--
-- 142:115'teki erken dönüş `'can_request', true` SABİT yazıyor. Yani
-- hak bir kredi kartından geliyorsa, salon misafiri kabul etmese bile
-- buton AÇIK kalıyor. Kullanıcı basıyor, ham `guests_not_allowed`
-- hatası alıyor.
--
-- 🔴 GÖKBERK'İN 9. MADDESİ TAM BUYDU: "misafir hakkı görünmüyor ancak
-- hâlâ istek gönderebiliyorum. Butonun inactive olması gerekmiyor mu."
-- 159 SUNUCU kapısını kapatmıştı; EKRAN kapısı açık kalmış.
--
-- İlke: ekran kapısı sunucu kapısından GEVŞEK OLAMAZ. Sıkı olması
-- sorun değil (kullanıcı deneyemez ama zarar görmez); gevşek olması
-- kullanıcıyı hataya sürer.

do $$
declare v_src text; v_new text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'request_precheck' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('192-kapi' in v_src) > 0 then
    raise notice '192: card_generic kapisi zaten hizali'; return;
  end if;

  -- 🔴 26 AĞUSTOS — yukarıdaki blokla aynı sebep: gövde 250/252'de
  -- `request_precheck_pregate`e taşındı. İmza orada duruyorsa iş
  -- görülmüştür; yeniden yamalamaya çalışmak yanlış alarmdır.
  if exists (select 1 from pg_proc
              where proname = 'request_precheck_pregate'
                and pronamespace = 'public'::regnamespace
                and position('192-kapi' in prosrc) > 0) then
    raise notice '192: kapi yamasi zaten uygulanmis (gövde pregate icinde) — atlaniyor';
    return;
  end if;

  v_new := replace(v_src,
    '''can_request'', true, ''needs_ack'', true, ''kind'',''card_generic''',
    '/* 192-kapi: kredi karti dali da SUNUCU KAPISINA uyar.
        159''un create_request_impl''i guest_policy=''not_allowed'' ya da
        severity=block olan ilanda ''guests_not_allowed'' firlatiyor;
        ekran bunu bilmeden ''gonderebilirsin'' diyordu. */
      ''can_request'',
        not (coalesce(d ->> ''guest_policy'','''') = ''not_allowed''
             or (coalesce(d ->> ''severity'','''') = ''block''
                 and coalesce(d ->> ''fits'','''') <> ''false'')),
      ''needs_ack'', true, ''kind'',''card_generic''');

  if v_new = v_src then
    raise exception '192: card_generic KAPI kalibi BULUNAMADI — yama uygulanmadi.';
  end if;

  execute 'create or replace function public.request_precheck('
       || pg_get_function_arguments(v_oid) || ') returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '192: kredi karti dali sunucu kapisiyla hizalandi';
end $$;

-- ============================================================
-- 🔴 EKRAN KAPISI ARTIK SUNUCU KAPISININ BİREBİR AYNISI
-- ============================================================
-- 18 Ağustos 2026 · Gökberk'te aşağıdaki bekçi 6 ilanda konuştu:
--   192: 6 ilanda ekran kapisi kural kapisindan GEVSEK:
--     || ff9d976a IST pre.kind=rule pre.can=true
--        karar.policy=not_allowed karar.sev=block fits=true charter=false
--   (altısı da aynı şekilde)
--
-- ÖLÇÜM — sunucu kapısı (`create_request_impl`) şunu diyor:
--     v_dec := public.lounge_access_decision(p_avail_id, null);
--     if (v_dec ->> 'guest_policy') = 'not_allowed'
--        or ((v_dec ->> 'severity') = 'block'
--            and coalesce(v_dec ->> 'fits','') <> 'false') then
--       raise exception 'guests_not_allowed';
--
-- Yani sunucu `enforcement`a BAKMADAN reddediyor. `request_precheck` ise
-- şöyle diyordu:
--     if (d ->> 'severity') = 'block' then
--       if enforcement='block' or carrier_ok='false' or charter then
--         v_can := false;
--       else v_ack := true;        -- ← "onaylat, göndersin"
--
-- `guest_policy = 'not_allowed'` bu dalda HİÇ SORULMUYOR. Sonuç:
-- kuralı `enforcement='warn'` olan (kaynağı belirsiz) bir ilanda ekran
-- **"gönderebilirsin"** diyor, kullanıcı dokunuyor, sunucu
-- `guests_not_allowed` fırlatıyor. Boşa dokunuş — ve ürünün
-- "kapıda ne olacağını biliyoruz" sözünün tam tersi.
--
-- KENDİ VERİMDE DE VAR: post-217 durumda 3 ilan aynı halde
-- (policy=not_allowed · enforcement=warn · pre_can=true). Bekçi bunu
-- görmedi çünkü 192'de, yani 214'ün kuralları yazılmadan ÖNCE koşuyor.
-- Yani hata bende de vardı, bekçim yalnız erken bakıyordu.
--
-- ⚠️ SIRALAMA: bu blok dosyadaki BÜTÜN regex yamalarından SONRA durmalı.
-- Önce buraya, birinci bekçinin üstüne koymuştum ve alttaki üçüncü yama
-- SARMALAYICININ gövdesinde kalıbını arayıp bulamadı:
--     ERROR: 192: card_generic KAPI kalibi BULUNAMADI
-- Yani sarmalayıcı, kendisinden sonra gelen bir yamayı kör etti. Sessiz
-- atlamayı exception'a çevirmemiş olsam bunu göremeyecektim.
--
-- DÜZELTME — gövdeyi regex ile yeniden yazmıyorum, SARMALIYORUM:
-- yamalar gövde kalıbına bağlı ve kalıp tutmazsa sessizce atlanıyor
-- (bugün tam bunu yaşadık). Sarmalayıcı gövdeden bağımsız çalışır ve
-- kapıyı TEK KAYNAKTAN okur: sunucunun kendi koşulu. İki yerde iki
-- kural yazmak, ikisinin ayrışması için davetiyedir.
do $hiza$
declare
  v_oid oid; v_args text; v_res text; v_cagri text; v_ilk text;
begin
  select p.oid into v_oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'request_precheck' limit 1;
  if v_oid is null then
    raise exception '192: request_precheck bulunamadi';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname='public' and p.proname='request_precheck_pregate') then
    raise notice '192: ekran/sunucu hizasi zaten kurulu';
    return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  select string_agg(split_part(btrim(x), ' ', 1), ', '),
         min(split_part(btrim(x), ' ', 1))
    into v_cagri, v_ilk
    from unnest(string_to_array(pg_get_function_identity_arguments(v_oid), ',')) x;
  -- ilk parametre = ilan kimligi (imzayi VARSAYMIYORUM, okuyorum)
  v_ilk := split_part(btrim(split_part(pg_get_function_identity_arguments(v_oid), ',', 1)), ' ', 1);

  execute format('alter function public.request_precheck(%s) rename to request_precheck_pregate',
                 pg_get_function_identity_arguments(v_oid));

  execute format($f$
    create function public.request_precheck(%s) returns %s
    language plpgsql stable security definer set search_path = public as $BODY$
    declare j jsonb; d jsonb;
    begin
      j := public.request_precheck_pregate(%s);
      -- Ekran zaten "gonderemezsin" diyorsa dokunma.
      if coalesce((j ->> 'can_request')::boolean, false) is not true then
        return j;
      end if;
      d := public.lounge_access_decision(%s, null);
      -- SUNUCUNUN KOSULUNUN BIREBIR AYNISI (create_request_impl)
      if (d ->> 'guest_policy') = 'not_allowed'
         or ((d ->> 'severity') = 'block'
             and coalesce(d ->> 'fits','') <> 'false') then
        return j || jsonb_build_object(
          'can_request', false,
          'needs_ack',   false,
          'severity',    'block',
          'gate',        'server',
          'headline',    coalesce(nullif(d ->> 'headline',''),
                                  'Bu ilana misafir alınamıyor'),
          'detail',      coalesce(nullif(j ->> 'detail',''), d ->> 'detail'));
      end if;
      return j;
    end $BODY$$f$, v_args, v_res, v_cagri, v_ilk);

  raise notice '192: ekran kapisi sunucu kapisiyla BIREBIR hizalandi';
end
$hiza$;

-- BEKÇİ: ekran "gönderebilirsin" diyorsa SUNUCU DA kabul etmeli.
-- 🔴 Bu bekçi ilkini genişletiyor: yalnız seyahat kapısına değil,
-- KURAL kapısına da bakar. Gerçekten create_request çağırmıyoruz
-- (yan etkisi var); sunucunun ÖN KOŞULLARINI aynen sınıyoruz.
do $$
declare r record; v_uid uuid; v_bad int := 0; j jsonb; d jsonb; v_liste text := '';
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '192: kural kapisi bekcisi atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  -- 🔴 `limit 30` KALDIRILDI — birinci bekcideki `limit 25` ile ayni
  -- kusur: kapsami satir sirasina birakiyordu.
  for r in select id, airport_code, lounge_name from availabilities where active loop
    j := public.request_precheck(r.id);
    if coalesce((j ->> 'can_request')::boolean, false) is not true then continue; end if;
    d := public.lounge_access_decision(r.id, null);
    if coalesce(d ->> 'guest_policy','') = 'not_allowed'
       or (coalesce(d ->> 'severity','') = 'block'
           and coalesce(d ->> 'fits','') <> 'false') then
      raise warning '192: ilan % — ekran ACIK ama kural kapisi KAPALI (%)',
        left(r.id::text,8), d ->> 'guest_policy';
      -- Ayrintiyi HATA MESAJINA yaz: Supabase warning gostermiyor.
      v_liste := v_liste || format(
        ' || %s %s "%s" pre.kind=%s pre.can=%s karar.policy=%s karar.sev=%s fits=%s charter=%s',
        left(r.id::text,8), r.airport_code, coalesce(r.lounge_name,'-'),
        coalesce(j ->> 'kind','(YOK)'), coalesce(j ->> 'can_request','(YOK)'),
        coalesce(d ->> 'guest_policy','(YOK)'), coalesce(d ->> 'severity','(YOK)'),
        coalesce(d ->> 'fits','(YOK)'), coalesce(d ->> 'charter','(YOK)'));
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then
    raise exception '192: % ilanda ekran kapisi kural kapisindan GEVSEK:%', v_bad, v_liste;
  end if;
  raise notice '192: ekran kapisi kural kapisiyla hizali';
end $$;
