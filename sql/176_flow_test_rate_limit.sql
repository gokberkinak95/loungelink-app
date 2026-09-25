-- ============================================================
-- LoungeLink · 176_flow_test_rate_limit.sql
-- AKIŞ TESTİ KENDİ HIZ LİMİTİNE TAKILIYOR
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yalnız test yolu).
--
-- ------------------------------------------------------------
-- 🔴 NE OLDU
-- ------------------------------------------------------------
--   ERROR: rate_limited
--   CONTEXT: rl_guard() ... flow_gate_test() ... rule_full_report()
--
-- rule_full_report(), flow_gate_test()'i İKİ KEZ çağırıyor (biri
-- toplam biri kalan için). Her çağrı aynı seed misafiri adına 4-5
-- istek yazıyor. `requests` tablosundaki hız limiti tetikleyicisi
-- saatte 20 yazma sayıyor; birkaç koşuda eşik doluyor ve rapor
-- hiç çalışmaz oluyor.
--
-- Yani hız limiti DOĞRU çalışıyor — sorun testin gerçek bir
-- kullanıcıymış gibi davranması. Test bir kullanıcı değildir:
-- ölçüm yapar, sonra izini siler.
--
-- İKİ DÜZELTME:
--   1. Test, yazmalarını hız limitinden MUAF bir bayrakla yapar.
--      Muafiyet yalnız bu oturum içinde geçerlidir (set_config
--      is_local=true → işlem bitince kendiliğinden düşer), yani
--      canlı bir kullanıcı bunu kullanamaz.
--   2. rule_full_report artık flow_gate_test'i BİR kez çağırır ve
--      sonucu geçici tabloda tutar. İki kez çağırmak hem gereksiz
--      yazma hem gereksiz süre demekti.
-- ============================================================

-- ---- 1) rl_guard'a test muafiyeti ----
create or replace function public.rl_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_uid uuid; v_claims text;
begin
  -- 🔴 176: TEST MUAFİYETİ. `ll.test_mode` yalnız işlem/oturum
  -- ömürlüdür (set_config is_local=true) ve PostgREST üzerinden
  -- gelen bir isteğe yerleştirilemez — dolayısıyla canlı kullanıcı
  -- hız limitini bu yolla aşamaz. Yalnız SQL konsolundan koşan
  -- denetim fonksiyonları için vardır.
  if coalesce(current_setting('ll.test_mode', true), '') = 'on' then
    return new;
  end if;

  v_claims := nullif(current_setting('request.jwt.claims', true), '');
  if v_claims is null then return new; end if;
  begin
    v_uid := nullif(v_claims::json ->> 'sub', '')::uuid;
  exception when others then
    return new;
  end;
  if v_uid is null then return new; end if;

  if not public.rate_ok('requests_insert', 20, 1) then
    raise exception 'rate_limited';
  end if;
  return new;
end $$;

-- ---- 2) flow_gate_test muafiyeti açar ----
-- sqlcheck: allow-replace flow_gate_test  (dönüş tipi AYNI — dinamik yeniden tanım)
do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'flow_gate_test' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '176: flow_gate_test yok'; end if;
  if position('ll.test_mode' in v_src) > 0 then
    raise notice '176: flow_gate_test zaten muaf'; return;
  end if;

  v_new := replace(v_src,
    '  perform set_config(''request.jwt.claims'',
    json_build_object(''sub'', v_guest, ''role'', ''authenticated'')::text, true);',
    '  -- 176: ölçüm yazmaları hız limitine sayılmaz (bkz. rl_guard).
  perform set_config(''ll.test_mode'', ''on'', true);
  perform set_config(''request.jwt.claims'',
    json_build_object(''sub'', v_guest, ''role'', ''authenticated'')::text, true);');

  if v_new = v_src then
    raise exception '176: muafiyet eklenemedi — gövde kalıbı değişmiş';
  end if;

  -- Çıkışta muafiyet kapatılır (is_local zaten düşürür; açıkça da yazıyoruz)
  v_new := replace(v_new,
    '  perform set_config(''request.jwt.claims'', ''{}'', true);',
    '  perform set_config(''request.jwt.claims'', ''{}'', true);
  perform set_config(''ll.test_mode'', ''off'', true);');

  execute 'create or replace function public.flow_gate_test() returns table '
       || '(senaryo text, beklenen text, gercek text, sonuc text) '
       || 'language plpgsql security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '176: flow_gate_test hız limitinden muaf';
end $$;

-- ---- 3) rapor testi TEK KEZ çağırır ----
-- sqlcheck: allow-replace rule_full_report  (üstte drop var, dönüş tipi genişledi)
drop function if exists public.rule_full_report();
create or replace function public.rule_full_report()
returns table (bolum text, kalem text, toplam int, gecen int, kalan int, durum text)
language plpgsql security definer set search_path = public as $$
declare r record; v_akis_top int; v_akis_kalan int;
        v_venue_top int; v_venue_kalan int;
begin
  -- A · Program bazlı beklenti matrisi
  for r in
    select split_part(m.vaka, ' · ', 1) as prog,
           count(*)::int as toplam,
           count(*) filter (where m.sonuc like '✓%')::int as gecen
      from (select vaka, sonuc from public.rule_matrix_test(false)) m
     group by 1
  loop
    bolum := 'A · Beklenti matrisi (program × tier × kapsam × taşıyıcı)';
    kalem := r.prog; toplam := r.toplam; gecen := r.gecen; kalan := r.toplam - r.gecen;
    durum := case when kalan = 0 then '✓' else '✗ ' || kalan || ' uyuşmazlık' end;
    return next;
  end loop;

  -- B · Salon bazlı tutarlılık
  select count(*)::int into v_venue_top from rule_venue_cases;
  select count(*)::int into v_venue_kalan from public.rule_venue_test(true);
  bolum := 'B · Salon bazlı tutarlılık (salon × program × tier × taşıyıcı)';
  kalem := 'tüm aktif salonlar'; toplam := v_venue_top;
  kalan := v_venue_kalan; gecen := v_venue_top - v_venue_kalan;
  durum := case when kalan = 0 then '✓' else '✗ ' || kalan || ' tutarsızlık' end;
  return next;

  -- C · Kapsam denetimi
  for r in select kontrol, sinif, deger, esik, sonuc from public.rule_coverage_audit() loop
    bolum := 'C · Kapsam denetimi'; kalem := r.kontrol || ' [' || r.sinif || ']';
    toplam := r.deger; gecen := r.esik; kalan := greatest(0, r.deger - r.esik);
    durum := r.sonuc; return next;
  end loop;

  -- D · Senaryo testleri
  bolum := 'D · Karar zinciri senaryoları'; kalem := 'decision_chain_check';
  toplam := (select count(*)::int from public.decision_chain_check());
  kalan := (select count(*)::int from public.decision_chain_check() where sonuc not like '✓%');
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;

  bolum := 'D · Karışık senaryolar'; kalem := 'mixed_case_check';
  toplam := (select count(*)::int from public.mixed_case_check());
  kalan := (select count(*)::int from public.mixed_case_check() where sonuc like '✗%');
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;

  -- E · Akış kapıları — 🔴 176: TEK ÇAĞRI. Eskiden toplam ve kalan
  -- için iki kez çağrılıyordu; her çağrı gerçek kayıt yazdığı için
  -- hem hız limitini dolduruyor hem işi ikiye katlıyordu.
  create temp table if not exists _akis_tmp on commit drop as
    select * from public.flow_gate_test();
  select count(*)::int into v_akis_top from _akis_tmp;
  select count(*)::int into v_akis_kalan from _akis_tmp where sonuc like '✗%';
  bolum := 'E · Akış kapıları'; kalem := 'flow_gate_test';
  toplam := v_akis_top; kalan := v_akis_kalan; gecen := v_akis_top - v_akis_kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;
end $$;
grant execute on function public.rule_full_report() to authenticated;

do $$
declare n int;
begin
  select count(*) into n from public.rule_full_report() where durum not like '✓%';
  raise notice '176: raporda % kırmızı kaldı', n;
end $$;

select '176 OK - test hiz limitinden muaf, rapor tek cagri' as sonuc;
